#!/usr/bin/env python3
"""变异扫描的通用引擎：切片到 N 个**独立构建树**并行跑。

为什么必须独立树：锚点是就地改 `src/*.qml`，而 src 的 QML 被 qmlcachegen 编进
`libsemi.dylib`（磁盘上的 .qml 不参与运行）⇒ 每条锚点都要重编一次，共享一棵树会互相踩。
试过用 `QML_IMPORT_PATH` 指影子模块目录覆盖 qrc 那份，**不成立**（`:/qt/qml/Semi/` 是
注册进二进制的资源，优先级压过 import path）⇒ 只能每 worker 一份树。

一份 spec 模块（各组件自己的 `tmp_<comp>_mutate.py`）要给出：
    FILES       被扫的源文件（相对仓库根）
    TEST        测试文件（相对仓库根或仓库根下的绝对路径）
    MUTATIONS   [(文件, 名字, 锚点, 改后), …]（三元视同改后为空串 = 整条删掉）
    SLOW        带真实 wait() 的测试函数名集合（可省）
    CLUSTERS    [(文件, 锚点名正则, 函数名正则), …] 第一段先跑的猜测（可省）
    EQUIVALENTS [(名字, 理由), …] 已知等价、不参与判分（可省）

用法：python3 tests/mutation_lab.py --spec tests/tmp_carousel_mutate.py -j 4 [名字片段…]
"""
import argparse
import importlib.util
import json
import os
import queue
import re
import shutil
import subprocess
import sys
import threading
import time

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True,
                      cwd=os.path.dirname(os.path.abspath(__file__))
                      ).stdout.strip() or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLATFORM = os.environ.get("PROBE_PLATFORM", "offscreen")
BUILD_JOBS = os.environ.get("MUTATE_BUILD_JOBS", "2")     # 每 worker 的编译并行度
CARRY = ("src", "tests", "cmake", "CMakeLists.txt", "README.md")


def load_spec(path):
    spec = importlib.util.spec_from_file_location("spec", path)
    mod = importlib.util.module_from_spec(spec)
    argv, sys.argv = sys.argv[:], ["spec"]
    spec.loader.exec_module(mod)
    sys.argv = argv
    test = mod.TEST
    if os.path.isabs(test) and test.startswith(ROOT):
        test = os.path.relpath(test, ROOT)
    muts = [m if len(m) == 4 else (m[0], m[1], m[2], "") for m in mod.MUTATIONS]
    return {"files": list(mod.FILES), "test": test, "mutations": muts,
            "slow": set(getattr(mod, "SLOW", set())),
            "clusters": list(getattr(mod, "CLUSTERS", [])),
            "equivalents": list(getattr(mod, "EQUIVALENTS", []))}


def matches(pattern, text):
    """CLUSTERS 里可能给的是已编译的 re 对象。"""
    return pattern.search(text) if hasattr(pattern, "search") else re.search(pattern, text)


def build(home):
    return subprocess.run(["cmake", "--build", f"{home}/build", "--target", "tst_semi",
                           "-j", BUILD_JOBS], capture_output=True, text=True)


def make_worker(idx, files):
    home = f"/tmp/semimut_w{idx}"
    shutil.rmtree(home, ignore_errors=True)
    os.makedirs(home)
    originals = {}
    for item in CARRY:
        s = f"{ROOT}/{item}"
        if os.path.isdir(s):
            shutil.copytree(s, f"{home}/{item}", ignore=shutil.ignore_patterns("__pycache__"))
        elif os.path.exists(s):
            shutil.copyfile(s, f"{home}/{item}")
    for f in files:
        originals[f] = open(f"{home}/{f}", encoding="utf-8").read()
    cfg = subprocess.run(["cmake", "-S", home, "-B", f"{home}/build", "-DCMAKE_BUILD_TYPE=Debug",
                          "-DSEMI_BUILD_EXAMPLES=OFF", "-G", "Ninja"], capture_output=True, text=True)
    if cfg.returncode != 0:
        raise RuntimeError(f"w{idx} configure 失败：{cfg.stderr[-400:]}")
    bld = build(home)
    if bld.returncode != 0:
        raise RuntimeError(f"w{idx} 建树失败：{bld.stderr[-400:]}")
    return {"home": home, "bin": f"{home}/build/tests/tst_semi", "originals": originals}


def funcs_of(worker, test):
    """`-functions` 的名单走 **stderr**（结果行才在 stdout）—— 踩过一次。"""
    r = subprocess.run([worker["bin"], "-functions", "-input", test], capture_output=True,
                       text=True, cwd=worker["home"],
                       env={**os.environ, "QT_QPA_PLATFORM": PLATFORM})
    # 名单每行形如 `Carousel::test_x()` —— **要去掉尾部括号**，否则当参数传回去就是
    # 「Could not find the following test functions」，一轮空跑。
    return [l.strip().rstrip("()") for l in (r.stdout + r.stderr).splitlines() if "::test_" in l]


def run_phase(worker, test, funcs):
    if not funcs:
        return "skip", ""
    p = subprocess.run([worker["bin"], "-input", test] + list(funcs), capture_output=True,
                       text=True, cwd=worker["home"], timeout=900,
                       env={**os.environ, "QT_QPA_PLATFORM": PLATFORM})
    fails = [l for l in p.stdout.splitlines() if l.startswith("FAIL!")]
    if fails:
        return "red", "\n".join(fails)[:400]
    totals = [l for l in p.stdout.splitlines() if l.startswith("Totals:")]
    if not totals:
        # 没有 Totals 就是这一轮压根没跑（函数名没对上 / 崩了），绝不能当成绿
        return "broken", (p.stdout + p.stderr)[-300:]
    return "green", totals[-1]


def classify(worker, spec, fname, name, funcs):
    """三段：猜中的快函数 → 其余快函数 → 慢函数。快 + 慢 = 整份文件 ⇒ 判绿等价于整份跑一遍。"""
    fast = [f for f in funcs if f.split("::")[-1] not in spec["slow"]]
    slow = [f for f in funcs if f.split("::")[-1] in spec["slow"]]
    guess = []
    for cfile, pat, fnpat in spec["clusters"]:
        if cfile == fname and matches(pat, name):
            guess = [f for f in fast if matches(fnpat, f)]
            break
    ok = build(worker["home"])
    if ok.returncode != 0:
        return "build-failed", ok.stderr[-400:], ""
    detail = ""
    for label, subset in (("猜测段", guess), ("快函数段", [f for f in fast if f not in guess]),
                          ("慢函数段", slow)):
        state, detail = run_phase(worker, spec["test"], subset)
        if state == "red":
            return "red", detail, label
        if state == "broken":
            return "broken", detail, label
    return "alive", detail, ""


def worker_loop(idx, spec, jobs, out, snapshots):
    try:
        worker = make_worker(idx, spec["files"])
        funcs = funcs_of(worker, spec["test"])
        out.put(("ready", idx, len(funcs)))
    except Exception as exc:                                   # noqa: BLE001
        out.put(("ready", idx, f"建树失败：{exc}"))
        out.put(("bye", idx, None))
        raise
    print(f"[w{idx}] 树就绪（{len(funcs)} 个函数）", flush=True)
    while True:
        job = jobs.get()
        try:
            if job is None:
                out.put(("bye", idx, None))
                return
            seq, fname, name, anchor, patched = job
            text = snapshots[fname]
            if text.count(anchor) != 1:
                out.put((seq, name, "anchor-not-unique", f"{text.count(anchor)} 处 @ {fname}", ""))
                continue
            with open(f'{worker["home"]}/{fname}', "w", encoding="utf-8") as f:
                f.write(text.replace(anchor, patched, 1))
            state, detail, label = classify(worker, spec, fname, name, funcs)
            out.put((seq, name, state, detail, label))
        finally:
            jobs.task_done()
    out.put(("bye", idx, None))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", required=True)
    ap.add_argument("-j", "--workers", type=int, default=4)
    ap.add_argument("only", nargs="*")
    args = ap.parse_args()

    spec = load_spec(os.path.abspath(args.spec))
    base = os.path.basename(spec["test"]).replace(".qml", "").replace("tst_", "")
    snapshots = {f: open(f"{ROOT}/{f}", encoding="utf-8").read() for f in spec["files"]}

    picked = [(i, m) for i, m in enumerate(spec["mutations"])
              if not args.only or any(o in m[1] for o in args.only)]
    if not picked:
        print("没有匹配的锚点")
        return 1
    n = max(1, min(args.workers, len(picked)))
    jobs, out = queue.Queue(), queue.Queue()
    for i, (seq, (fname, name, anchor, patched)) in enumerate(picked):
        jobs.put((seq, fname, name, anchor, patched))
    for _ in range(n):
        jobs.put(None)

    t0 = time.time()
    threads = [threading.Thread(target=worker_loop, args=(i, spec, jobs, out, snapshots))
               for i in range(n)]
    for t in threads:
        t.start()
    results, seen_ready, seen_bye = [], 0, 0
    while seen_bye < n:
        try:
            msg = out.get(timeout=10)
        except queue.Empty:
            if not any(t.is_alive() for t in threads):
                print("所有 worker 线程已退出，但没收齐 bye —— 判为异常结束")
                break
            continue
        if msg[0] == "ready":
            seen_ready += 1
            continue
        if msg[0] == "bye":
            seen_bye += 1
            continue
        results.append(msg)
        _, name, state, detail, label = msg
        print(f"[{state:16}] {name}{'  [' + label + ']' if label else ''}"
              f"  ({time.time() - t0:.0f}s / {len(results)}/{len(picked)})", flush=True)
    for t in threads:
        t.join()

    results.sort(key=lambda r: r[0])
    report = f"/tmp/mutation_report_{base}_parallel.json"
    with open(report, "w", encoding="utf-8") as f:
        json.dump([{"m": r[1], "s": r[2], "d": r[3], "phase": r[4]} for r in results],
                  f, ensure_ascii=False, indent=1)
    eq = {e[0] for e in spec["equivalents"]}
    alive = [r for r in results if r[2] != "red"]
    unexplained = [r for r in alive if r[1] not in eq]
    print(f"\n共 {len(results)} 条（{n} 个 worker，{time.time() - t0:.0f}s）："
          f"见血 {len(results) - len(alive)} / 存活 {len(alive)}"
          f"（等价登记 {len(alive) - len(unexplained)}、未解释 {len(unexplained)}）")
    for r in alive:
        print(f"  [{'等价' if r[1] in eq else '未解释'}] {r[1]} —— {r[3][:150]}")
    print(f"报告：{report}")
    return 1 if unexplained else 0


if __name__ == "__main__":
    sys.exit(main())
