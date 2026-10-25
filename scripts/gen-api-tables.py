#!/usr/bin/env python3
"""从 src/*.qml 抽组件的公共属性面，生成 gallery 各页的 API 参考表（写回 docs.json）。

为什么不用官方那份：docs.json 的 api 数组是从 Semi 官网 markdown 解析出来的 React 版 props，
类型是 TS 的（bool / string / React.ReactNode）、名字也未必在 QML 侧存在。这份脚本换成**本库自己的**：
名字、类型、缺省值、信号一律从 `src/<Type>.qml` 的源码里抽（组件加了 prop 重跑一次就同步），
说明列来自 `scripts/api-notes.json`（人工维护；没写的留空，不编造）。

抽的规则：
  · 只抽根项直接声明的 `property …` / `property alias …` / `signal …`（缩进恰好 4 空格）；
    `readonly property` 是内部派生态，不进表（要列的写进 notes 的 `extra`）。
  · 名字以下划线开头的不进表（`_xxx` 是私有约定）。
  · 缺省值取声明里的字面量；没写缺省的显示 `-`。
  · 信号显示成 `onXxx`（QML 侧真正写的就是这个名字）。

用法：
    python3 scripts/gen-api-tables.py                 # 全量（有 notes 的页才会被重写）
    python3 scripts/gen-api-tables.py Button Icon     # 只重写这几页
    python3 scripts/gen-api-tables.py --check         # 只报告缺说明的行，不写文件
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "examples/gallery/data/docs.json")
NOTES = os.path.join(ROOT, "scripts/api-notes.json")

# 页面 -> 这一页要列出来的 QML 类型（顺序即表里分组的顺序）
PAGES = {
    "Button": ["Button", "ButtonGroup"],
    "Divider": ["Divider"],
    "FloatButton": ["FloatButton"],
    "Icon": ["Icon"],
    "Space": ["Space"],
    "Title": ["Title"],
    "AutoComplete": ["AutoComplete"],
    "Cascader": ["Cascader"],
    "Checkbox": ["Checkbox", "CheckboxGroup"],
    "ColorPicker": ["ColorPicker"],
    "DatePicker": ["DatePicker"],
    "Form": ["Form", "FormItem", "FormLabel"],
    "Input": ["Input"],
    "InputNumber": ["InputNumber"],
    "PinCode": ["PinCode"],
    "Radio": ["Radio", "RadioGroup"],
    "Rating": ["Rating"],
    "Select": ["Select"],
    "Slider": ["Slider"],
    "Switch": ["Switch"],
    "TagInput": ["TagInput"],
    "TimePicker": ["TimePicker"],
    "Transfer": ["Transfer"],
    "TreeSelect": ["TreeSelect"],
    "Upload": ["Upload"],
    "Anchor": ["Anchor", "AnchorLink"],
    "BackTop": ["BackTop"],
    "Breadcrumb": ["Breadcrumb", "BreadcrumbItem", "BreadcrumbMore"],
    "Navigation": ["Navigation"],
    "Pagination": ["Pagination"],
    "Steps": ["Steps"],
    "Tabs": ["Tabs"],
    "Tree": ["Tree"],
    "Avatar": ["Avatar", "AvatarGroup"],
    "Badge": ["Badge"],
    "Calendar": ["Calendar"],
    "Card": ["Card", "CardMeta", "CardGroup"],
    "Carousel": ["Carousel"],
    "Collapse": ["Collapse"],
    "Collapsible": ["Collapsible"],
    "Cropper": ["Cropper"],
    "Descriptions": ["Descriptions", "DescriptionsItem"],
    "Dropdown": ["Dropdown", "DropdownItem", "DropdownTitle", "DropdownDivider"],
    "Empty": ["Empty"],
    "Highlight": ["Highlight"],
    "ImageView": ["ImageView", "ImagePreview"],
    "List": ["List"],
    "Modal": ["Modal", "ModalConfirm"],
    "OverflowList": ["OverflowList"],
    "Popover": ["Popover"],
    "ScrollList": ["ScrollList", "ScrollItem"],
    "SideSheet": ["SideSheet"],
    "Table": ["Table", "TableColumn"],
    "Tag": ["Tag"],
    "Timeline": ["Timeline", "TimelineItem"],
    "Tooltip": ["Tooltip"],
    "UserGuide": ["UserGuide"],
    "Banner": ["Banner"],
    "Feedback": ["Feedback"],
    "Notification": ["Notification"],
    "Popconfirm": ["Popconfirm"],
    "Progress": ["Progress"],
    "Skeleton": ["Skeleton"],
    "Spin": ["Spin"],
    "Toast": ["Toast"],
    "DragMove": ["DragMove"],
    "HotKeys": ["HotKeys"],
}

ALIAS_RE = re.compile(r"^ {4}(?:(default|readonly) )?property alias (\w+):\s*(\S+)\s*$")
PROP_RE = re.compile(r"^ {4}(?:(default|readonly) )?property(?: alias)? (\S+)\s+(\w+)\s*(?::\s*(.*))?$")
SIGNAL_RE = re.compile(r"^ {4}signal (\w+)\s*(\(([^)]*)\))?\s*$")


def type_of(qml_type):
    """QML 类型原样显示；`var` 之类的由说明列交代取值（Enums.Tone 等）。"""
    return qml_type


def default_of(raw, kind=""):
    if kind == "alias":
        return "-"
    if raw is None:
        return "-"
    v = raw.strip()
    if v.startswith('"'):
        if v.endswith('"'):
            return f'"{v[1:-1]}"'
        return v                       # 带尾注释的字符串，原样保留前半段
    v = v.split(" //", 1)[0].strip()   # 声明行尾的注释不算缺省值的一部分
    if v == "undefined":
        return "-"                      # 不给时走缺省档，与官方表的写法一致
    # 默认值列不换行（120 宽）：`Theme.current.xxx` 砍掉前缀，令牌名在说明里已经点过
    if v.startswith("Theme.current."):
        return v[len("Theme.current."):]
    # 多行字面量（`({ … })` 那种）只抓到第一行，括号不闭合就当「见说明」
    if v.count("{") != v.count("}") or v.count("(") != v.count(")"):
        return "-"
    return v or "-"


def extract(type_name):
    path = os.path.join(ROOT, "src", f"{type_name}.qml")
    if not os.path.exists(path):
        return None
    props, signals = [], []
    for line in open(path, encoding="utf-8").read().splitlines():
        if line.startswith("    readonly property"):
            continue
        m = SIGNAL_RE.match(line)
        if m:
            name = m.group(1)
            args = (m.group(3) or "").strip()
            signals.append((f"on{name[0].upper()}{name[1:]}",
                            "signal" + (f" {name}({args})" if args else "")))
            continue
        m = ALIAS_RE.match(line)
        if m:
            name = m.group(2)
            if not name.startswith("_"):
                props.append((name, "alias", "-", m.group(1) or "alias"))
            continue
        m = PROP_RE.match(line)
        if m:
            kind, ptype, name, raw = m.groups()
            if name.startswith("_"):
                continue
            props.append((name, type_of(ptype),
                          default_of(raw, "alias" if ptype == "alias" else kind),
                          kind or ptype))
    return props, signals


def build_rows(page):
    all_notes = {}
    if os.path.exists(NOTES):
        all_notes = json.load(open(NOTES, encoding="utf-8"))
    rows = []
    missing = []
    for t in PAGES[page]:
        got = extract(t)
        if got is None:
            continue
        props, signals = got
        notes = all_notes.get(t, {})
        skip = set(notes.get("skip", []))
        rows.append({"name": f"— {t} —", "desc": "", "type": "", "default": ""})
        for name, ptype, default, kind in props:
            if name in skip:
                continue
            note = notes.get(name, "")
            if not note:
                missing.append(f"{page}.{name}")
            rows.append({"name": name, "desc": note, "type": ptype, "default": default})
        for name, sig in signals:
            if name in skip:
                continue
            note = notes.get(name, "")
            if not note:
                missing.append(f"{page}.{name}")
            rows.append({"name": name, "desc": note, "type": sig, "default": "-"})
    for extra in notes.get("extra", []):
        rows.append(extra)
    return rows, missing


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("only", nargs="*")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    pages = args.only or list(PAGES)
    doc = json.load(open(DOCS, encoding="utf-8"))
    targets = {}
    for cat in doc["categories"]:
        for comp in cat["components"]:
            targets[comp["page"]] = comp
    missing_all = []
    for page in pages:
        comp = targets.get(page)
        if comp is None:
            print(f"[skip] docs.json 里没有 {page}")
            continue
        rows, missing = build_rows(page)
        missing_all += missing
        if rows:
            comp["api"] = rows
        print(f"{page:14} {len(rows):3} 行   缺说明 {len(missing):2}"
              + ("  " + ", ".join(m.split(".", 1)[1] for m in missing) if missing else ""))
    if args.check:
        return
    if missing_all:
        print(f"\n共 {len(missing_all)} 行还没有说明（留空，不编造）——补到 {os.path.relpath(NOTES, ROOT)} 再跑一次")
    with open(DOCS, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=4)
        f.write("\n")
    print(f"\n已写回 {os.path.relpath(DOCS, ROOT)}（改完记得重编译，docs.json 是 Qt 资源）")


if __name__ == "__main__":
    sys.exit(main())
