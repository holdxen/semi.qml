#!/usr/bin/env python3
"""并行跑全量单元测试（offscreen），把 61 个 `tst_*.qml` 的 Totals 汇总。

为什么要并行：一份文件平均 3~10s，串行跑十几分钟；这些进程之间不共享任何状态
（各自建自己的窗口、各读自己的 .qml），压满 CPU 就能压到三分多钟。

为什么要留一批串行：有些文件里的断言依赖**真实毫秒余量**（400ms 防抖、
计时相位只能用 `triggered` 的到达时刻反推 —— Qt 6.11 的 `Timer` 没有 `elapsed`），
机器被压满时那 200~400ms 的余量会飘。所以下面 `SERIAL` 里那份名单不参与并行。

用法：
    python3 scripts/run-tests.py                 # 全部，-j 4
    python3 scripts/run-tests.py -j 2            # 控并行度
    python3 scripts/run-tests.py tst_card tst_carousel   # 只跑这几个（按文件名前缀）
    python3 scripts/run-tests.py --platform cocoa
"""
import argparse
import concurrent.futures
import os
import re
import subprocess
import sys

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                      text=True, cwd=os.path.dirname(os.path.abspath(__file__)),
                      ).stdout.strip() or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 带真实时序余量的文件，单独串行跑（判绿才可信）
# tst_treeselect 里那两条「动画得真的在走」的断言要一帧一帧采中间态，
# 机器压满时那 200ms 会被一次推过去 ⇒ 采不到就假红（见 PROGRESS 坑 52 / 坑 127）。
SERIAL = {"tst_carousel.qml", "tst_avatar.qml", "tst_treeselect.qml"}


def test_files():
    src = open(f"{ROOT}/tests/CMakeLists.txt", encoding="utf-8").read()
    block = src.split("set(SEMI_TEST_FILES")[1].split(")")[0]
    return [l.strip() for l in block.split() if l.endswith(".qml")]


def run_one(binary, f, platform):
    try:
        p = subprocess.run([binary, "-input", f"tests/{f}"], capture_output=True, text=True,
                           cwd=ROOT, timeout=1800, env={**os.environ, "QT_QPA_PLATFORM": platform})
    except subprocess.TimeoutExpired:
        return f, "TIMEOUT", []
    totals = [l for l in p.stdout.splitlines() if l.startswith("Totals:")]
    fails = [l for l in p.stdout.splitlines() if l.startswith("FAIL!")]
    return f, (totals[-1] if totals else "NO TOTALS"), fails


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-j", "--workers", type=int, default=4)
    ap.add_argument("--platform", default=os.environ.get("QT_QPA_PLATFORM", "offscreen"))
    ap.add_argument("--build", default=f"{ROOT}/cmake-build-debug")
    ap.add_argument("only", nargs="*")
    args = ap.parse_args()

    binary = f"{args.build}/tests/tst_semi"
    if not os.path.exists(binary):
        print(f"找不到 {binary}，先 cmake --build {args.build} --target tst_semi")
        return 1

    files = test_files()
    if args.only:
        files = [f for f in files if any(o in f for o in args.only)]
    par = [f for f in files if f not in SERIAL]
    ser = [f for f in files if f in SERIAL]
    print(f"{len(files)} 个文件：并行 {len(par)}（-j {args.workers}）+ 串行 {len(ser)}，"
          f"平台 {args.platform}")

    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.workers)) as ex:
        for f, line, fails in ex.map(lambda x: run_one(binary, x, args.platform), par):
            results[f] = (line, fails)
    for f in ser:
        _, line, fails = run_one(binary, f, args.platform)
        results[f] = (line, fails)

    tp = tf = 0
    bad = 0
    for f in files:
        line, fails = results[f]
        m = re.search(r"(\d+) passed, (\d+) failed", line)
        if not m:
            print("!!", f, line)
            bad += 1
            continue
        tp += int(m.group(1))
        tf += int(m.group(2))
        if int(m.group(2)):
            bad += 1
            print(f"FAIL {f}  {line}")
            for x in fails[:6]:
                print("   ", x[:200])
    print(f"\n汇总：{len(files)} 个文件，{tp} 通过 / {tf} 失败（红文件的有：{bad}）")
    return 1 if tf or bad else 0


if __name__ == "__main__":
    sys.exit(main())
