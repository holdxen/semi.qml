#!/usr/bin/env python3
"""从 Semi 的 scss 解析出 gallery Tokens 页用的 tokens.json。

形状照官网那份 designToken.json（semi-design/scripts/designToken.js）来，
这样页面可以按同样的方式渲染：一份扁平清单 + 每个小节一条正则，
小节顺序与表格内容都由 scss 的**声明顺序**决定，不再自己排序、自己分组。

    data = { "global": { "global": {"light": [T], "dark": [T]},
                         "palette": {"light": [T], "dark": [T]},
                         "normal": [T], "animation": [T] } }

    T = { key, value, comment, category, raw, accessor, color }

    key      带前缀的原名：`--semi-color-primary` / `$spacing-base-tight`
             （global.scss 那两块里还有 `font-family` 与 `-webkit-font-smoothing`
              两行不是自定义属性，官网也照样当令牌收，这里跟着收）
    value    等号右边的原文，例如 `rgba(var(--semi-blue-5), 1)` —— 官网「默认值」列显示的就是它
    comment  行尾 `//` 之后的说明 —— 官网「用法」列
    category 首个词（`$color-x` → color），官网按它分档
    raw      整行原文
    accessor 端口新增：`Theme.current.` 后面那截，点复制用的
             色阶给成 `blue[5]`；端口没有对应属性的（font-family 等）给 null
    color    端口新增：把 var() 与 `R,G,B` 三元组解成可画的 CSS 色，解不出来给 null

用法：
    python3 gen-tokens.py                       # 写 ../data/tokens.json
    python3 gen-tokens.py --check               # 只与现有文件对账，不写
    python3 gen-tokens.py --scss <dir> --out <file>
"""

import argparse
import importlib.util
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_SCSS = pathlib.Path.home() / "Documents/Code/Html/semi-design/packages/semi-theme-default/scss"
DEFAULT_OUT = HERE.parent / "data" / "tokens.json"
REPO_ROOT = HERE.parents[2]
DEFAULT_HEADER = REPO_ROOT / "src" / "SemiThemeValues.h"

# 端口自己的顺序偏好：官网把 animation.scss 的 34 条平铺在「动画」一节里，
# 页面按 `--semi_transition_(x)-` 分档页签；顺序仍取文件声明序。
CATEGORY_WORDS = {"color", "width", "height", "spacing", "radius", "font",
                  "motion", "animation", "transition"}


def qml_mapping():
    """复用 scripts/gen-theme-tokens.py 里的名字映射，避免两处各写一遍规则。"""
    path = REPO_ROOT / "scripts" / "gen-theme-tokens.py"
    spec = importlib.util.spec_from_file_location("gen_theme_tokens", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def is_comment(line):
    return line.startswith("//") or line.startswith("/*")


def split_token(line):
    """官网 codeLineSplit：按 : 与注释切，key 保留 $ / --semi- 前缀。"""
    parts = [p.strip() for p in re.split(r":|//|/\*", line)]
    parts = [p for p in parts if p]
    if len(parts) < 2:
        return None
    key, value = parts[0], parts[1]
    comment = parts[2] if len(parts) > 2 else ""
    m = re.match(r"\$([\w\W]+?)[-_]", key)
    first = (m.group(1).lower() if m else None)
    category = (first if first in CATEGORY_WORDS else "other") if first else "other"
    if category == "transition":
        category = "animation"
    return {"key": key, "value": value.rstrip(";").strip(), "comment": comment,
            "category": category, "raw": line}


def parse_modes(path):
    """按 `body` 行切 light / dark 两块（带 semi-always-dark 的那块是 dark）。"""
    lines = [l.strip() for l in path.read_text(encoding="utf-8").split("\n")]
    lines = [l for l in lines if l and not is_comment(l)
             and not l.startswith("}") and not l.startswith("@")]
    out = {"light": [], "dark": []}
    mode = "light"
    for line in lines:
        if "body" in line:
            if "semi-always-dark" in line:
                mode = "dark"
            continue
        token = split_token(line)
        if token is not None:
            out[mode].append(token)
    return out


def merge_comments(content):
    """dark 行常常不带注释，官网把 light 的注释补过去，这里同口径。"""
    by_key = {t["key"]: t for t in content["light"]}
    for t in content["dark"]:
        src = by_key.get(t["key"])
        if src is not None and not t["comment"]:
            t["comment"] = src["comment"]
    return content


def parse_flat(path):
    """variables.scss 与 animation.scss：不分明暗。"""
    lines = [l.strip() for l in path.read_text(encoding="utf-8").split("\n")]
    lines = [l for l in lines if l and not is_comment(l)
             and not l.startswith("}") and not l.startswith("@") and not l.startswith("body")]
    return [t for t in (split_token(l) for l in lines) if t is not None]


# --------------------------------------------------------------------------
# 端口字段：accessor 与 color
# --------------------------------------------------------------------------

def bare_key(key):
    """去掉 --semi- / $ 前缀，得到 gen-theme-tokens.py 那套名字。"""
    if key.startswith("--semi-"):
        return key[len("--semi-"):]
    if key.startswith("$"):
        return key[1:]
    return None


def make_accessor(key, mod):
    name = bare_key(key)
    if name is None:
        return None                     # font-family 这类没有前缀的行，端口无对应属性
    m = re.match(r"^([a-z]+(?:-[a-z]+)*)-(\d+)$", name)
    if m and m.group(1) in mod.SCALE_HUES:
        return f"{mod.camel(m.group(1))}[{m.group(2)}]"
    return mod.qml_field(name)


def resolve_color(value, palette_map):
    """把 var(--semi-x) 与 `R,G,B` 解成能直接画的颜色串；解不出来给 None。"""
    text = value.strip()
    expanded = re.sub(r"var\(--semi-([\w-]+)\)",
                      lambda m: palette_map.get(m.group(1), m.group(0)), text)
    if expanded.startswith("linear-gradient"):
        return expanded
    m = re.match(r"^(\d+)\s*,\s*(\d+)\s*,\s*(\d+)$", expanded)
    if m:
        return "#{:02X}{:02X}{:02X}".format(*(int(g) for g in m.groups()))
    m = re.match(r"^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+))?\s*\)$", expanded)
    if m:
        r, g, b = (int(m.group(i)) for i in (1, 2, 3))
        a = float(m.group(4)) if m.group(4) else 1.0
        # **不能给 rgba(...) 串**：QML 的字符串隐式转 color 只认 #RGB / #ARGB /
        # #RRGGBB / #AARRGGBB 与颜色名，收到 "rgba(26, 29, 33, 0.05)" 会得到纯黑
        # （fill-0/1/2、color-shadow、overlay-bg 这些带 alpha 的令牌整列画黑）。
        # Qt 的八位档是 **AARRGGBB**，alpha 在前。
        if a >= 1:
            return f"#{r:02X}{g:02X}{b:02X}"
        return f"#{round(max(0.0, min(1.0, a)) * 255):02X}{r:02X}{g:02X}{b:02X}"
    if re.match(r"^#[0-9a-fA-F]{3,8}$", expanded):
        return expanded
    return None


def decorate(tokens, palette_map, mod, props):
    for t in tokens:
        candidate = make_accessor(t["key"], mod)
        # 端口没有对应属性的就留空（font-family 一族、ai-general 的 40 个色标、
        # 以及 variables.scss 那条多行声明被按行切出来的残片）—— 页面上这些行不给复制
        t["accessor"] = candidate if candidate and candidate.split("[")[0] in props else None
        t["color"] = resolve_color(t["value"], palette_map)
    return tokens


# --------------------------------------------------------------------------
# 自检
# --------------------------------------------------------------------------

def header_properties(path):
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r"Q_PROPERTY\([A-Za-z_<> ]+ (\w+) READ", text))


def self_check(data, header_path):
    props = header_properties(header_path)
    ok = True

    def chk(label, got, want):
        nonlocal ok
        hit = got == want
        ok = ok and hit
        print(f"  [{'OK ' if hit else 'FAIL'}] {label}: {got}" + ("" if hit else f"  期望 {want}"))

    g = data["global"]
    # 条数是实测值。global 每档 121 行里有 119 条 `--semi-*`，另外两行
    # （`font-family` 与 `-webkit-font-smoothing`）是块里的普通 CSS 声明 ——
    # 官网那份 designToken.json 也照收（scripts/designToken.js 是按行切的），这里跟着收。
    chk("global.scss light 条数", len(g["global"]["light"]), 121)
    chk("global.scss dark 条数", len(g["global"]["dark"]), 121)
    chk("_palette.scss light 条数", len(g["palette"]["light"]), 222)
    chk("animation 条数", len(g["animation"]), 34)
    chk("variables 条数", len(g["normal"]), 52)

    def find(tokens, key):
        for t in tokens:
            if t["key"] == key:
                return t
        return None

    blue5 = find(g["palette"]["light"], "--semi-blue-5")
    chk("blue-5 light", (blue5 or {}).get("color"), "#0064FA")
    chk("blue-5 accessor", (blue5 or {}).get("accessor"), "blue[5]")
    primary = find(g["global"]["light"], "--semi-color-primary")
    chk("color-primary 原文", (primary or {}).get("value"), "rgba(var(--semi-blue-5), 1)")
    chk("color-primary 解析", (primary or {}).get("color"), "#0064FA")
    chk("color-primary accessor", (primary or {}).get("accessor"), "colorPrimary")
    chk("color-primary 用法", (primary or {}).get("comment"), "主要颜色。仅在需要非常强调的情况下使用。")
    radius = find(g["global"]["light"], "--semi-border-radius-medium")
    chk("border-radius-medium accessor", (radius or {}).get("accessor"), "radiusMedium")
    duration = find(g["animation"], "--semi-transition_duration-fast")
    chk("transition_duration-fast accessor", (duration or {}).get("accessor"), "durationFast")
    zmodal = find(g["normal"], "$z-modal")
    chk("$z-modal accessor", (zmodal or {}).get("accessor"), "zModal")
    chk("font-family 无 accessor", find(g["global"]["light"], "font-family")["accessor"], None)
    fill0 = find(g["global"]["light"], "--semi-color-fill-0")
    chk("fill-0 落成 #AARRGGBB", (fill0 or {}).get("color"), "#0D2E3238")   # grey-8 = 46,50,56，alpha .05 → 0x0D
    bad_alpha = sorted({t["key"] for grp in (g["global"]["light"], g["global"]["dark"],
                                             g["palette"]["light"], g["palette"]["dark"])
                        for t in grp if t["color"] and t["color"].startswith("rgba(")})
    chk("color 里不留 rgba( 串", bad_alpha, [])

    # 声明顺序：primary 一族必须紧跟在 color-white/black 之后、secondary 之前
    names = [t["key"] for t in g["global"]["light"]]
    chk("声明顺序（primary 在 secondary 前）",
        names.index("--semi-color-primary") < names.index("--semi-color-secondary"), True)

    all_tokens = g["global"]["light"] + g["global"]["dark"] + g["palette"]["light"] \
        + g["palette"]["dark"] + g["normal"] + g["animation"]
    chk("accessor 全部落在 SemiThemeValues 的属性上",
        sorted({t["accessor"].split("[")[0] for t in all_tokens
                if t["accessor"] and t["accessor"].split("[")[0] not in props}), [])

    # 端口没有对应属性的那几类，逐条登记；新增一条就说明 scss 变了而端口没跟上
    no_accessor = sorted({t["key"] for t in all_tokens if t["accessor"] is None})
    expected_no = sorted({"font-family", "-webkit-font-smoothing", "$prefix",
                          "Helvetica, Arial, sans-serif;", "$font-family-regular"}
                         | {f"--semi-ai-general-{i}-{j}" for i in range(10) for j in range(4)})
    chk("无 accessor 的键集合", no_accessor, expected_no)
    return ok


# --------------------------------------------------------------------------
# 主流程
# --------------------------------------------------------------------------

def build(scss_dir, header_path=DEFAULT_HEADER):
    mod = qml_mapping()
    props = header_properties(pathlib.Path(header_path))
    for f in ("global.scss", "_palette.scss", "variables.scss", "animation.scss"):
        if not (scss_dir / f).exists():
            sys.exit(f"找不到 {scss_dir / f}")

    palette = merge_comments(parse_modes(scss_dir / "_palette.scss"))
    # 三元组与渐变色标都要能当 var() 的解引用目标
    palette_map = {}
    for mode in ("light", "dark"):
        for t in palette[mode]:
            name = bare_key(t["key"])
            if name:
                palette_map.setdefault(name, t["value"])

    data = {
        "global": {
            "global": {mode: decorate(merge_comments(parse_modes(scss_dir / "global.scss"))[mode],
                                      palette_map, mod, props) for mode in ("light", "dark")},
            "palette": {mode: decorate(palette[mode], palette_map, mod, props) for mode in ("light", "dark")},
            "normal": decorate(parse_flat(scss_dir / "variables.scss"), palette_map, mod, props),
            "animation": decorate(parse_flat(scss_dir / "animation.scss"), palette_map, mod, props),
        }
    }
    return data


def summarize(data):
    g = data["global"]
    print(f"  global.scss light/dark {len(g['global']['light'])} / {len(g['global']['dark'])}")
    print(f"  _palette.scss light/dark {len(g['palette']['light'])} / {len(g['palette']['dark'])}")
    print(f"  variables.scss {len(g['normal'])}  animation.scss {len(g['animation'])}")
    total = sum(len(v) if isinstance(v, list) else len(v["light"]) + len(v["dark"])
                for v in (g["global"], g["palette"], g["normal"], g["animation"]))
    print(f"  合计 {total} 条")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scss", type=pathlib.Path, default=DEFAULT_SCSS)
    ap.add_argument("--out", type=pathlib.Path, default=DEFAULT_OUT)
    ap.add_argument("--header", type=pathlib.Path, default=DEFAULT_HEADER)
    ap.add_argument("--check", action="store_true", help="只与现有文件对账，不写出")
    args = ap.parse_args()

    if not args.scss.is_dir():
        sys.exit(f"找不到 scss 目录：{args.scss}")

    data = build(args.scss)

    print("自检：")
    if not self_check(data, args.header):
        sys.exit("自检失败，已中止生成")

    print("\n产出：")
    summarize(data)

    text = json.dumps(data, ensure_ascii=False, indent=1)
    if args.check:
        old = args.out.read_text(encoding="utf-8") if args.out.exists() else ""
        print(f"\n--check：{'与现有文件一致' if old.strip() == text.strip() else '与现有文件不一致（未写出）'}")
        return

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text, encoding="utf-8")
    print(f"-> {args.out}")


if __name__ == "__main__":
    main()
