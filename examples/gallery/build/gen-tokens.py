#!/usr/bin/env python3
"""从 Semi 的 scss 解析出 gallery 用的 tokens.json。

数据源（semi-design/packages/semi-theme-default/scss/）：
  _palette.scss    色板，light / dark 两块
  global.scss      语义色，值形如 rgba(var(--semi-blue-5), 1)
  variables.scss   字号 / 字重 / 圆角 / 间距 / 尺寸 / z-index / 阴影
  animation.scss   动效时长与曲线

用法：
    python3 gen-tokens.py [--scss <scss 目录>] [--out <tokens.json>]
"""

import argparse
import json
import re
from pathlib import Path

DEFAULT_SCSS = Path.home() / "Documents/Code/Html/semi-design/packages/semi-theme-default/scss"
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "data" / "tokens.json"

# 语义色的分组顺序与中文名，照官网 tokens 页
SEMANTIC_GROUPS = [
    ("primary", "主要颜色 primary"),
    ("secondary", "次要颜色 secondary"),
    ("tertiary", "第三颜色 tertiary"),
    ("info", "信息 info"),
    ("success", "成功 success"),
    ("warning", "警示 warning"),
    ("danger", "危险 danger"),
    ("ai", "AI 颜色"),
    ("text", "文本与图标 text"),
    ("link", "链接色 link"),
    ("bg", "背景色 bg"),
    ("fill", "填充色 fill"),
    ("border", "描边色 border"),
    ("disabled", "禁用态 disabled"),
    ("static", "常量色 static"),
    ("shadow", "拟阴影色 shadow"),
    ("other", "其他"),
]


def rgb_to_hex(value):
    parts = [p.strip() for p in value.split(",")]
    if len(parts) != 3:
        return None
    try:
        return "#{:02X}{:02X}{:02X}".format(*(int(p) for p in parts))
    except ValueError:
        return None


def parse_palette(path):
    """返回 (light, dark) 两个 dict，键是去掉 --semi- 前缀的名字。"""
    text = path.read_text(encoding="utf-8")
    # 按块头切分：第一块是 light，带 semi-always-dark 的那块是 dark
    blocks = re.split(r"^(?=\S.*\{$)", text, flags=re.M)
    light, dark = {}, {}
    for block in blocks:
        head = block.split("{", 1)[0]
        target = dark if "semi-always-dark" in head else light
        for m in re.finditer(r"--semi-([\w-]+):\s*([^;]+);", block):
            name, value = m.group(1), m.group(2).strip()
            if name.startswith("color-"):
                continue                      # 那是语义色，在 global.scss 里
            if value.startswith("linear-gradient"):
                target[name] = value
            else:
                hex_value = rgb_to_hex(value)
                if hex_value:
                    target[name] = hex_value
    return light, dark


def expand_semantic(value, palette):
    """把 rgba(var(--semi-blue-5), 1) 展开成十六进制；解析不了就原样返回。"""
    m = re.search(r"var\(--semi-([\w-]+)\)", value)
    if m:
        name = m.group(1)
        if name in palette:
            return palette[name]
    if value.startswith("linear-gradient"):
        return value
    if value.startswith("#") or value.startswith("rgba(") or value.startswith("rgb("):
        return value
    return value


def parse_semantic(path, light_palette, dark_palette):
    text = path.read_text(encoding="utf-8")
    blocks = re.split(r"^(?=\S.*\{$)", text, flags=re.M)
    light, dark = {}, {}
    for block in blocks:
        head = block.split("{", 1)[0]
        target = dark if "semi-always-dark" in head else light
        palette = dark_palette if target is dark else light_palette
        for m in re.finditer(r"--semi-([\w-]+):\s*([^;]+);\s*(?://\s*(.*))?", block):
            name, value, desc = m.group(1), m.group(2).strip(), (m.group(3) or "").strip()
            target[name] = {
                "value": expand_semantic(value, palette),
                "desc": desc,
            }
    return light, dark


def group_of(name):
    if not name.startswith("color-"):
        return "other"
    body = name[len("color-"):]
    for key, _ in SEMANTIC_GROUPS:
        if key == "other":
            continue
        if body == key or body.startswith(key + "-"):
            return key
    return "other"


def parse_sass_vars(path):
    """解析 $name: value; // 说明 形式的变量。"""
    text = path.read_text(encoding="utf-8")
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("//") or not line.startswith("$"):
            continue
        m = re.match(r"\$([\w-]+):\s*([^;]+);\s*(?://\s*(.*))?$", line)
        if not m:
            continue
        result[m.group(1)] = {
            "value": m.group(2).strip(),
            "desc": (m.group(3) or "").strip(),
        }
    return result


def parse_css_vars(path):
    """解析 --semi-x: value; 形式的 CSS 自定义属性，跳过注释行。

    animation.scss 里放的是 CSS 变量而不是 Sass 变量，所以不能拿
    parse_sass_vars 读它 —— 那个只认 $ 开头的行，结果是动效一直被解析成空数组。
    注释行必须整行跳过：文件里那套「has animation」的备选值是注释掉的。
    """
    result = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith(("//", "/*", "*")):
            continue
        m = re.match(r"--semi-([\w-]+)\s*:\s*([^;]+);\s*(?://\s*(.*))?$", line)
        if not m:
            continue
        result[m.group(1)] = {
            "value": m.group(2).strip(),
            "desc": (m.group(3) or "").strip(),
        }
    return result


def pick(variables, prefix, out_key=None):
    """按前缀挑变量，返回 [{name, value, desc}]。"""
    items = []
    for name, info in variables.items():
        if name.startswith(prefix):
            items.append({"name": name, "value": info["value"], "desc": info["desc"]})
    items.sort(key=lambda x: x["name"])
    return items


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scss", type=Path, default=DEFAULT_SCSS)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    if not args.scss.is_dir():
        raise SystemExit(f"找不到 scss 目录：{args.scss}")

    light_palette, dark_palette = parse_palette(args.scss / "_palette.scss")
    light_semantic, dark_semantic = parse_semantic(
        args.scss / "global.scss", light_palette, dark_palette)

    # 色板按色相分组：red / pink / ... / ai-purple，外加渐变
    hues = {}
    gradients = []
    for name in light_palette:
        # ai-general-N 是渐变本体，ai-general-N-M 是它的色标，不算独立条目
        if re.fullmatch(r"ai-general-\d+", name):
            gradients.append({
                "name": name,
                "light": light_palette.get(name, ""),
                "dark": dark_palette.get(name, ""),
            })
            continue
        if name.startswith("ai-general"):
            continue
        m = re.match(r"([a-z-]+)-(\d+)$", name)
        if m:
            hues.setdefault(m.group(1), {})[int(m.group(2))] = {
                "light": light_palette.get(name, ""),
                "dark": dark_palette.get(name, ""),
            }

    palette_groups = []
    for hue in sorted(hues):
        steps = [dict(index=i, **hues[hue][i]) for i in sorted(hues[hue])]
        palette_groups.append({"hue": hue, "steps": steps})
    gradients.sort(key=lambda x: x["name"])

    # 语义色分组
    groups = []
    for key, display in SEMANTIC_GROUPS:
        tokens = []
        for name in sorted(light_semantic):
            if not name.startswith("color-"):
                continue
            if group_of(name) != key:
                continue
            light_info = light_semantic[name]
            dark_info = dark_semantic.get(name, {})
            tokens.append({
                "name": name,
                "light": light_info["value"],
                "dark": dark_info.get("value", light_info["value"]),
                "desc": light_info["desc"],
            })
        if tokens:
            groups.append({"key": key, "name": display, "tokens": tokens})

    variables = parse_sass_vars(args.scss / "variables.scss")
    animation = parse_css_vars(args.scss / "animation.scss")

    # 圆角是 global.scss 里的 CSS 变量，不在 variables.scss
    radius_tokens = []
    seen_radius = set()
    for name, info in sorted(light_semantic.items()):
        if name.startswith("border-radius-") and name not in seen_radius:
            seen_radius.add(name)
            radius_tokens.append({
                "name": name,
                "value": info["value"],
                "desc": info["desc"],
            })

    # 阴影同理：也是 global.scss 里的 CSS 变量（variables.scss 里没有 shadow-*），
    # 而且明暗两套值不一样，所以带上 dark
    shadow_tokens = []
    for name in sorted(light_semantic):
        if not name.startswith("shadow-"):
            continue
        light_info = light_semantic[name]
        shadow_tokens.append({
            "name": name,
            "value": light_info["value"],
            "dark": dark_semantic.get(name, {}).get("value", light_info["value"]),
            "desc": light_info["desc"],
        })

    sizing = {
        "fontSize": pick(variables, "font-size-"),
        "fontWeight": pick(variables, "font-weight-"),
        "radius": radius_tokens,
        "spacing": pick(variables, "spacing-"),
        "width": pick(variables, "width-"),
        "height": pick(variables, "height-"),
        "zIndex": pick(variables, "z-"),
        "shadow": shadow_tokens,
    }
    # 动效按「时长 → 延迟 → 缓动 → 缩放 → 旋转」排，比字典序好读：
    # 字典序会把 transform-rotate-none（连字符）排到 transform_rotate-* 前面
    MOTION_ORDER = ("transition_duration-", "transition_delay-",
                    "transition_function-", "transform_scale-", "transform")
    motion = []
    for name in sorted(animation, key=lambda n: (next(
            (i for i, p in enumerate(MOTION_ORDER) if n.startswith(p)), len(MOTION_ORDER)), n)):
        motion.append({
            "name": name,
            "value": animation[name]["value"],
            "desc": animation[name]["desc"],
        })

    data = {
        "palette": {"groups": palette_groups, "gradients": gradients},
        "semantic": {"groups": groups},
        "sizing": sizing,
        "motion": motion,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"写出 {args.out}")
    print(f"  色相 {len(palette_groups)} 组 / 渐变 {len(gradients)} 条")
    print(f"  语义色 {sum(len(g['tokens']) for g in groups)} 个，分 {len(groups)} 组")
    for key, items in sizing.items():
        print(f"  {key}: {len(items)}")
    print(f"  动效: {len(motion)}")


if __name__ == "__main__":
    main()
