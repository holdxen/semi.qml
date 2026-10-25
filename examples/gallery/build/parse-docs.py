#!/usr/bin/env python3
"""把 Semi 官网的组件文档解析成 gallery 用的 docs.json。

源内容在 semi-design 仓库的 content/<分类>/<组件>/index.md，
结构是「frontmatter + ## 代码演示（多个 ### 小节）+ ## API 参考（表格）+ 若干章节」。

用法：
    python3 parse-docs.py [--content <semi-design/content>] [--out <docs.json>]
"""

import argparse
import collections
import json
import re
from pathlib import Path

DEFAULT_CONTENT = Path.home() / "Documents/Code/Html/semi-design/content"
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "data" / "docs.json"
SRC_DIR = Path(__file__).resolve().parents[3] / "src"

# 目录名与本库组件名不一致的几个，手工列
SPECIAL_PAGE = {
    "image": "ImageView",
    "layout": "LayoutBox",
    "grid": "GridRow",
    "typography": "Title",
    "tokens": "Tokens",
}

# 侧边栏的分类顺序与中文名，照官网
CATEGORIES = [
    ("basic", "基础"),
    ("input", "输入类"),
    ("navigation", "导航类"),
    ("show", "展示类"),
    ("feedback", "反馈类"),
    ("plus", "Plus 组件"),
]

# 未实现 / 已决定跳过的组件（目录名）。跳过的也进 JSON，
# 侧边栏要显示它们并标注「未实现」，而不是藏起来。
SKIPPED = {
    "aiComponent", "aiChatInput", "aiChatDialogue", "sidebar",
    "chat", "codehighlight", "markdownrender", "jsonviewer", "lottie",
    "audioPlayer", "videoPlayer", "chart",
    "configprovider", "locale",
}

# 页尾收进 JSON 的章节。官网还有「使用场景」「设计变量」「相关物料」等，
# 那些要么是设计资源索引、要么整节是指向 DSM 的链接，不做。
GUIDELINE_SECTIONS = ("Accessibility", "文案规范", "FAQ")


def strip_code_fences(text):
    """去掉围栏代码块。

    围栏必须顶格另起一行才算 —— 官网有把 ``` 当行内代码写的地方
    （FAQ 里「正确的 import 路径应该为```import { Button } from '...'```」），
    用不加锚点的 ```.*?``` 会连行内那截一起吃掉，句子就断了。
    另有一种包在引用块里的围栏（`> ```ts`），所以前缀要允许 `>`。
    """
    return re.sub(r"^[ \t]*(?:>[ \t]*)*```[^\n]*\n.*?^[ \t]*(?:>[ \t]*)*```[^\n]*$",
                  "", text, flags=re.S | re.M)


def fold_html_cards(text):
    """只折官网那两张卡壳：`<Notice title='X'>…</Notice>` ⇒「X：正文」，`<br/>` ⇒ 空格。

    QML 侧按纯文本渲染，标签壳会原样画到页面上（AutoText 还会把 `<Notice …>` 当成 HTML 起头）。
    docs.json 里的 sections / guidelines 是各轮手工补的、不能整段重生成，
    但老版本解析器留下的壳得能单独洗一遍 ⇒ 这道清洗单独成函数（`--clean-markup-only`）。
    """
    text = re.sub(r"<Notice\b[^>]*?title=['\"]([^'\"]*)['\"][^>]*>(.*?)</Notice>",
                  lambda m: "%s：%s" % (m.group(1), m.group(2).strip()),
                  text, flags=re.S)
    text = re.sub(r"</?Notice\b[^>]*>", "", text)
    return re.sub(r"<br\s*/?>", " ", text, flags=re.I)   # 换行标记：留着会把第二行画到右列上


def strip_markdown(text):
    """把说明文字里的 markdown 标记去掉，QML 侧按纯文本渲染。"""
    text = fold_html_cards(text)
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)          # 图片整个去掉
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)       # 链接留文字
    text = re.sub(r"\*\*([^*]*)\*\*", r"\1", text)             # 粗体
    text = re.sub(r"`([^`]*)`", r"\1", text)                   # 行内代码
    text = re.sub(r"^[ \t]*>[ \t]?", "", text, flags=re.M)     # 引用块标记
    text = re.sub(r"^\s*[-*]\s+", "· ", text, flags=re.M)      # 列表项
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def strip_comments(text):
    """去掉 HTML 注释。官网在页尾拿注释藏了整段「相关物料」章节。"""
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def parse_frontmatter(text):
    data = {}
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return data, text
    for line in m.group(1).splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            data[key.strip()] = value.strip()
    return data, text[m.end():]


def split_sections(body):
    """按 ### 切出小节，返回 [(标题, 说明)]，说明里不含代码块。"""
    # 只取「## 代码演示」到下一个 ## 之间的内容
    demo = re.search(r"^##\s*代码演示\s*$(.*?)(?=^##\s|\Z)", body, re.S | re.M)
    if not demo:
        return []
    chunk = demo.group(1)

    sections = []
    # 按 ### 切分
    parts = re.split(r"^###\s+(.+)$", chunk, flags=re.M)
    # parts[0] 是第一个 ### 之前的内容，之后两两一组
    for i in range(1, len(parts), 2):
        title = parts[i].strip()
        content = parts[i + 1] if i + 1 < len(parts) else ""
        # 去掉代码块
        content = strip_code_fences(content)
        # 去掉 #### 及更深的标题行（保留文字）
        content = re.sub(r"^#{4,}\s*(.+)$", r"\1", content, flags=re.M)
        description = strip_markdown(content)
        sections.append({"title": title, "description": description})
    return sections


# API 那一节的收口：官网 API 面底下常夹二级标题（table 页的 `## Table` / `## Column` /
# `## 方法`，tree 页的 `## Methods`），真正的下一节只有这几个名字。
API_STOP_HEADS = {"设计变量", "Accessibility", "文案规范", "FAQ", "FAQ:", "相关物料",
                  "RTL/LTR", "semiGlobal", "更新记录"}


def parse_api(body):
    """解析 API 那一节下的**所有**表格，返回 [{name, desc, type, default}]。

    标题层级与收口都不统一，两处踩过：
      · 起点：多数页是 `## API参考`（不带空格），也有 `## API 参考` 与 `### API`（cropper）；
      · 收口：早先按「任意二三级标题」截，于是 `## API参考` 紧跟 `### Tree` 或 `## Table`
        的页会被截成 0 行（table 那页 114 行就是这么掉的）；现在只认 API_STOP_HEADS 里那几个
        真正的下一节标题。
    小节标题（`## Table` / `### TreeNodeData` / `## Methods`）在数组里插一条
    `— 标题 —` 的分组行，且**只有真的收到行才插**（`### headerStyle 示例` 那种纯代码块不留空组）。
    列名也不统一（属性/名称/参数/方法、类型、默认值、版本…），所以**按表头那一行的列名对号**，
    认不出来的列（版本等）并进说明 —— 与站内早先手工整理过的表一致。
    """
    api = re.search(r"^#{2,3}\s*API(?:\s*参考)?\s*$", body, re.M)
    if not api:
        return []
    # API 章节里也夹围栏代码块：table 页在 `| virtualized |` 那行下面直接给了整段 TS 类型定义，
    # 里面的 `| boolean` / `| {` 是 TypeScript 联合类型的换行，不先去围栏会被当表格行吃进来。
    chunk = strip_code_fences(body[api.end():])

    NAME_COLS = ("属性", "名称", "参数", "方法", "成员", "字段", "选项", "配置",
                 "Name", "Property", "Prop", "API")
    DESC_COLS = ("说明", "描述", "Description", "含义")
    TYPE_COLS = ("类型", "Type")
    DEF_COLS = ("默认值", "缺省值", "Default")

    rows = []
    pending = None            # 还没落地的分组标题
    cols = None               # 当前表的列名（表头行）
    for raw in chunk.splitlines():
        line = raw.strip()
        head = re.match(r"^(#{2,4})\s+(.+?)\s*$", line)
        if head:
            title = head.group(2).strip()
            if len(head.group(1)) == 2 and title in API_STOP_HEADS:
                break
            if title in ("API", "API 参考", "API参考"):
                continue
            pending = {"name": "— %s —" % strip_markdown(title), "desc": "", "type": "",
                       "default": ""}
            cols = None
            continue
        cells = split_row(line)
        if cells is None:
            continue
        if is_separator(cells):
            continue
        if is_header(cells, NAME_COLS):
            cols = cells
            continue
        if pending is not None:
            rows.append(pending)
            pending = None
        row = map_row(cells, cols, NAME_COLS, DESC_COLS, TYPE_COLS, DEF_COLS)
        rows.append(row)
    return rows


def split_row(line):
    """表格行 → 单元格列表；不是表格行返回 None。

    只按**未转义**的竖线分列：官网表格里 `string[]\\|object[]` 这种是单元格内的竖线，
    直接 split("|") 会把它劈成两列，后面每一列都左移一格、单元格里还留一个反斜杠。
    """
    if not line.startswith("|"):
        return None
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", line.strip("|"))]


def is_separator(cells):
    return bool(cells) and all(set(c) <= set("-: ") for c in cells)


def is_header(cells, name_cols):
    """表头行：第一格是「属性 / Name / 参数 / 方法 …」这类列名。"""
    return bool(cells) and cells[0] in name_cols


def unwrap_api_type(cell):
    # `<ApiType detail='完整签名'>显示文本</ApiType>`：显示文本就是简写签名，
    # 全签名挂在 hover 详情上 —— 端口只留显示文本，全签名会撑爆那一列。
    return re.sub(r"<ApiType\b[^>]*>(.*?)</ApiType>", r"\1", cell, flags=re.S)


def clean_cell(text):
    """单元格收口：去标签与 markdown 残留，折成一行。

    表格的格子不换行也不裁高，单元格里带换行（官网的 `<br/>`、TS 类型定义折行）
    时第二行会直接盖到右边那一列上，所以 name/desc/type/default 四格一律走这里。
    """
    return " ".join(strip_markdown(unwrap_api_type(text)).split())


def map_row(cells, cols, name_cols, desc_cols, type_cols, def_cols):
    """按表头列名对号入座；认不出的列（版本等）并进说明末尾。"""
    if cols is None:
        # 没表头的表（少见）：按 属性 / 说明 / 类型 / 默认值 的位置吃
        idx = {"name": 0, "desc": 1, "type": 2, "default": 3}
        extra = list(range(4, len(cells)))
    else:
        idx = {}
        extra = []
        for i, c in enumerate(cols):
            key = None
            if i == 0 or c in name_cols:
                key = "name" if i == 0 and "name" not in idx else key
            if c in name_cols and "name" not in idx:
                key = "name"
            elif c in desc_cols:
                key = "desc"
            elif c in type_cols:
                key = "type"
            elif c in def_cols:
                key = "default"
            if key is None:
                extra.append(i)
            else:
                idx.setdefault(key, i)
        idx.setdefault("name", 0)

    def cell(i):
        if i is None or i >= len(cells):
            return ""
        return clean_cell(cells[i])

    def get(key):
        return cell(idx.get(key))

    row = {"name": get("name"), "desc": get("desc"), "type": get("type"),
           "default": get("default")}
    # 认不出的列（版本 / 备注）并进说明；但空列与只写了个「-」的占位列不值得带进去
    tail = [v for v in (cell(i) for i in extra) if v and v not in ("-", "—", "–", "/")]
    if tail:
        row["desc"] = (row["desc"] + " " + " ".join(tail)).strip()
    # Methods 那张表只有两列（方法 | 说明），名字写成 `search(sugInput: string)` 时
    # 拆成「方法名()」+ 签名，跟别的页对齐。
    if (cols is not None and len(cols) <= 2 and row["name"] and not row["type"]
            and not row["default"]):
        m = re.match(r"^([\w$.]+)\s*\((.*)\)\s*$", row["name"])
        if m:
            row["type"] = "(%s) => void" % m.group(2).strip()
            row["name"] = m.group(1) + "()"
            row["default"] = "-"
    return row


def parse_guidelines(body):
    """页尾章节：Accessibility / 文案规范 / FAQ。

    返回 [{title, items}]，items 每项是 {kind, indent, text}，kind 取
    heading / text，indent 是列表层级（0 起）—— QML 侧按它缩进排版。

    这几节里的对比表格整格是内嵌的 React JSX（「✅ 推荐用法」那种），
    QML 没法渲染，所以表格行整行丢掉，只留文字与列表。
    """
    out = []
    for title in GUIDELINE_SECTIONS:
        m = re.search(r"^##\s*" + re.escape(title) + r"\s*$(.*?)(?=^##\s|\Z)",
                      body, re.S | re.M)
        if not m:
            continue
        # 代码块先去掉：FAQ 的答案里常夹一段 CSS
        chunk = strip_code_fences(m.group(1))
        items = []
        for raw in chunk.splitlines():
            line = raw.rstrip()
            if not line.strip():
                continue
            stripped = line.lstrip()
            if stripped.startswith("|"):
                continue
            # FAQ 里的小标题是当列表项写的（`- #### 问题？`），所以先摘掉列表符号
            body_text = re.sub(r"^[-*]\s+", "", stripped)
            heading = re.match(r"^#{3,}\s*(.+)$", body_text)
            if heading:
                text = strip_markdown(heading.group(1))
                if text:
                    items.append({"kind": "heading", "indent": 0, "text": text})
                continue
            text = strip_markdown(stripped)
            if text:
                items.append({
                    "kind": "text",
                    "indent": (len(line) - len(stripped)) // 2,
                    "text": text,
                })
        if items:
            out.append({"title": title, "items": items})
    return out


def build_page_map():
    """扫描 src/*.qml，建立「目录名（小写）→ 页面基名」的映射。"""
    mapping = {}
    if SRC_DIR.is_dir():
        for f in SRC_DIR.glob("*.qml"):
            mapping[f.stem.lower()] = f.stem
    return mapping


def page_base(dir_name, page_map):
    """给一个 content 目录名，得出页面文件的基名。"""
    if dir_name in SPECIAL_PAGE:
        return SPECIAL_PAGE[dir_name]
    return page_map.get(dir_name.lower(), dir_name[:1].upper() + dir_name[1:])


def parse_component(md_path, dir_name, page_map):
    text = md_path.read_text(encoding="utf-8")
    front, body = parse_frontmatter(text)
    body = strip_comments(body)
    return {
        "dir": dir_name,
        "page": page_base(dir_name, page_map),
        "title": front.get("title", dir_name),
        "brief": front.get("brief", ""),
        "sections": split_sections(body),
        "api": parse_api(body),
        "guidelines": parse_guidelines(body),
        "skipped": dir_name in SKIPPED,
    }


# 表头列名里这些词是「列名」而不是属性名，旧表里当行吃进去的要挑掉
HEAD_WORDS = {"属性", "Name", "参数", "Property", "方法", "名称", "成员", "字段",
              "选项", "配置", "API", "Prop", "Props", "描述", "说明"}


def clean_row(row):
    """整行过一次单元格收口（老 docs.json 的行是从官网原样抄的，带 `<br/>`、`<ApiType>` 与折行）。"""
    return {k: clean_cell(row.get(k, "")) for k in ("name", "desc", "type", "default")}


def has_residue(text):
    """这一格还是坏的：留着标签、转义竖线，或被劈坏的引号（一头一尾挂着半个引号）。"""
    if any(m in text for m in ("<ApiType", "</", "<br", "<Notice", "\\|")):
        return True
    return text.count("'") % 2 == 1 and (text.startswith("'") or text.endswith(("'", "\\")))


def merge_api_rows(old, new):
    """按 new（解析器现算）的顺序合并一份 api 数组。

    同名行沿用**旧的那条**（老表里的说明是各轮手工润短的，不拿官网长句盖掉），
    新出现的分组头与被旧正则吞掉的子表（Methods / Column / FormApi …）按位置插进来。
    旧行一律先 clean_row：不清洗的话 `<br/>` 会被原样带回来，而第二行正是要盖到右列上；
    清洗也参与同名比对（名字里带反引号的旧行洗完才和解析器对得上）。
    某一格洗完仍带标签/劈坏痕迹的，这一格改用现算的那份（老表里那格本来就是坏的）。
    返回 (合并结果, 旧表里没配对上的行)。
    """
    old = [clean_row(r) for r in old]
    queues = collections.defaultdict(collections.deque)
    for r in old:
        if not r["name"].startswith("—"):
            queues[r["name"]].append(r)
    out = []
    for r in new:
        q = queues.get(r["name"])
        if not q:
            out.append(r)
            continue
        row = dict(q.popleft())
        for key in ("name", "desc", "type", "default"):
            if has_residue(row[key]) and not has_residue(r[key]):
                row[key] = r[key]
        out.append(row)
    # 没被同名配上的旧行 = 手工补的行（解析器产不出来的那些），调用方据此决定整页动不动
    left = [r for q in queues.values() for r in q]
    return out, left


def merge_api_only(existing_path, categories):
    """只把 api 数组并回既有的 docs.json，其余字段一个字都不动。

    docs.json 里的 sections / brief / guidelines 有多处是各轮手工补的（Form 的三条锚点、
    Feedback 的 skipped 标注…），整份覆盖会冲掉；而且官网内容目录还留着已经决定不做的
    grid / layout 两页，整份重跑会把它们加回侧边栏。
    """
    doc = json.loads(Path(existing_path).read_text(encoding="utf-8"))
    fresh = {c["page"]: c.get("api") or [] for cat in categories for c in cat["components"]}
    changed, held = [], []
    for cat in doc["categories"]:
        for comp in cat["components"]:
            page = comp["page"]
            old = comp.get("api") or []
            new = fresh.get(page) or []
            if not new:
                continue
            if not old:
                if comp.get("skipped"):
                    continue            # 未实现页不铺官网大表
                comp["api"] = new
                changed.append((page, 0, len(new), "填空表"))
                continue
            merged, left = merge_api_rows(old, new)
            real_left = [r["name"] for r in left if r["name"] not in HEAD_WORDS]
            if real_left:
                # 旧表里有解析器产不出的手工行（Table 的 `Column.align` 前缀命名、
                # Tree 手工补的 aria-label / search()…）⇒ 行一条不动，别把手工行挤掉；
                # 但每格还是过一次清洗（老表里也有 `<br/>`、`**粗体**` 这类残留）
                held.append((page, real_left[:3]))
                cleaned = [clean_row(r) for r in old]
                if cleaned != old:
                    comp["api"] = cleaned
                    changed.append((page, len(old), len(cleaned), "只清洗单元格（留着手工行）"))
                continue
            if [r["name"] for r in merged] == [r["name"] for r in old]:
                # 行序没变，但旧行可能被清洗过（去 `<br/>` / 补劈坏的格子）⇒ 仍要写回去
                if merged == old:
                    continue
                comp["api"] = merged
                changed.append((page, len(old), len(merged), "只清洗单元格"))
                continue
            comp["api"] = merged
            changed.append((page, len(old), len(merged), "补分组头/子表"))
    Path(existing_path).write_text(
        json.dumps(doc, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    for page, a, b, why in changed:
        print(f"  {page:18s}{a:4d} -> {b:4d}  {why}")
    print(f"  合计改了 {len(changed)} 页；{len(held)} 页因含手工行而不动："
          + ", ".join(p for p, _ in held))


def clean_markup_only(path):
    """只洗 sections / guidelines 里残留的 `<Notice>` 卡壳与 `<br/>`，其余字段一个字不动。"""
    doc = json.loads(Path(path).read_text(encoding="utf-8"))
    hits = []
    for cat in doc["categories"]:
        for comp in cat["components"]:
            for sec in comp.get("sections") or []:
                fixed = fold_html_cards(sec.get("description", ""))
                if fixed != sec.get("description"):
                    sec["description"] = fixed
                    hits.append("%s/%s" % (comp["page"], sec["title"][:16]))
            for guide in comp.get("guidelines") or []:
                for item in guide.get("items") or []:
                    fixed = fold_html_cards(item.get("text", ""))
                    if fixed != item.get("text"):
                        item["text"] = fixed
                        hits.append("%s§%s" % (comp["page"], guide["title"]))
    Path(path).write_text(
        json.dumps(doc, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    print("  洗掉标签壳 %d 处：%s" % (len(hits), ", ".join(hits[:12])))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--content", type=Path, default=DEFAULT_CONTENT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--merge-api-only", type=Path, default=None,
                        help="只把解析出的 api 数组并回这份 docs.json（其余字段不动）")
    parser.add_argument("--clean-markup-only", type=Path, default=None,
                        help="只洗这份 docs.json 里 sections / guidelines 残留的标签壳")
    args = parser.parse_args()

    if args.clean_markup_only:
        clean_markup_only(args.clean_markup_only)
        return

    if not args.content.is_dir():
        raise SystemExit(f"找不到源内容目录：{args.content}")

    page_map = build_page_map()
    categories = []
    total = 0
    for key, name in CATEGORIES:
        folder = args.content / key
        if not folder.is_dir():
            continue
        components = []
        for comp_dir in sorted(folder.iterdir()):
            md = comp_dir / "index.md"
            if not md.is_file():
                continue
            components.append(parse_component(md, comp_dir.name, page_map))
        if components:
            categories.append({"key": key, "name": name, "components": components})
            total += len(components)

    if args.merge_api_only:
        merge_api_only(args.merge_api_only, categories)
        return

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps({"categories": categories}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    doable = sum(1 for c in categories for x in c["components"] if not x["skipped"])
    skipped = total - doable
    sections = sum(len(x["sections"]) for c in categories
                   for x in c["components"] if not x["skipped"])
    guides = collections.Counter()
    for c in categories:
        for x in c["components"]:
            if x["skipped"]:
                continue
            for g in x["guidelines"]:
                guides[g["title"]] += 1
    print(f"写出 {args.out}")
    print(f"  组件 {total} 个（可做 {doable} / 跳过 {skipped}）")
    print(f"  可做页面的小节合计 {sections} 个")
    print("  页尾章节：" + " / ".join(f"{k} {v} 页" for k, v in guides.items()))


if __name__ == "__main__":
    main()
