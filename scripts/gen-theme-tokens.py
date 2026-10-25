#!/usr/bin/env python3
"""从 Semi Design 源码提取设计令牌，生成 QML 侧的 C++ 令牌类与文档数据。

用法:
    python3 scripts/gen-theme-tokens.py [--semi-root <path>]

产物:
    src/SemiThemeValues.h     令牌类声明（色阶 / 语义色 / 圆角 / 阴影 / 动效 / 尺寸）
    src/SemiThemeValues.cpp   默认值、setter、派生重算

令牌清单在 gallery 的 Tokens 页里看（examples/gallery/TokensPage.qml），
数据由 examples/gallery/build/gen-tokens.py 产出，这一份只管 C++ 令牌层。

设计要点
--------
语义色不存死值，而是「色阶派生 + 可选覆盖」：
    未覆盖 -> 从色阶按引用关系取（colorPrimary 取 blue[5]）
    已覆盖 -> 用用户设的值
所以用户改一整条色阶时，底下引用它的语义色会自动跟上；单独改某个语义色也能生效。
"""
import argparse
import collections
import pathlib
import re
import sys

HUES = ["amber", "blue", "cyan", "green", "grey", "indigo", "light-blue", "light-green",
        "lime", "orange", "pink", "purple", "red", "teal", "violet", "yellow"]
AI_HUES = ["ai-purple"]
SCALE_HUES = set(HUES + AI_HUES)

# 引用关系只在 light / dark 一致时才用于派生，否则按固定值处理
DEFAULT_SEMI_ROOT = pathlib.Path.home() / "Documents/Code/Html/semi-design"


# --------------------------------------------------------------------------
# 提取
# --------------------------------------------------------------------------

def _lines(path):
    for line in path.read_text().split("\n"):
        s = line.strip()
        if not s or s.startswith(("//", "/*", "*", "*/", "@", "}", "body", ":host", ".")):
            continue
        yield s


def block_vars(path):
    """--semi-x: value; // 注释"""
    out = collections.OrderedDict()
    for s in _lines(path):
        m = re.match(r"--semi-([A-Za-z0-9_-]+)\s*:\s*([^;]+);\s*(?://\s*(.*))?$", s)
        if m:
            out[m.group(1)] = {"raw": m.group(2).strip(), "desc": (m.group(3) or "").strip()}
    return out


def split_modes(path):
    parts = re.split(r'^body\[theme-mode="dark"\][^{]*\{', path.read_text(), flags=re.M)
    return block_vars_text(parts[0]), (block_vars_text(parts[1]) if len(parts) > 1 else {})


def block_vars_text(text):
    out = collections.OrderedDict()
    for line in text.split("\n"):
        s = line.strip()
        if not s or s.startswith(("//", "/*", "*", "*/", "@", "}", "body", ":host", ".")):
            continue
        m = re.match(r"--semi-([A-Za-z0-9_-]+)\s*:\s*([^;]+);\s*(?://\s*(.*))?$", s)
        if m:
            out[m.group(1)] = {"raw": m.group(2).strip(), "desc": (m.group(3) or "").strip()}
    return out


def sass_vars(path):
    out = collections.OrderedDict()
    for line in path.read_text().split("\n"):
        s = line.strip()
        if not s or s.startswith(("//", "/*", "*")):
            continue
        m = re.match(r"\$([A-Za-z0-9_-]+)\s*:\s*([^;]+);\s*(?://\s*(.*))?$", s)
        if m:
            out[m.group(1)] = {"raw": m.group(2).strip(), "desc": (m.group(3) or "").strip()}
    return out


def css_rgb_to_hex(v):
    m = re.match(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)\s*$", v.strip())
    if not m:
        return None
    r, g, b = (int(m.group(i)) for i in (1, 2, 3))
    a = float(m.group(4)) if m.group(4) is not None else 1.0
    return f"#{r:02x}{g:02x}{b:02x}" if a >= 1 else f"rgba({r}, {g}, {b}, {a})"


def scale_hex(raw):
    m = re.match(r"^(\d+)\s*,\s*(\d+)\s*,\s*(\d+)$", raw.strip())
    return f"#{int(m.group(1)):02x}{int(m.group(2)):02x}{int(m.group(3)):02x}" if m else None


def resolve_color(raw, palette):
    val = re.sub(
        r"var\(--semi-([A-Za-z0-9_-]+)\)",
        lambda m: palette.get(m.group(1), {}).get("raw", m.group(0)),
        raw,
    )
    return css_rgb_to_hex(val)


def expand_gradient(raw, palette):
    """把渐变里的 var(--semi-ai-general-N-M) 子色替换成真实 rgb 三元组"""
    return re.sub(
        r"var\(--semi-([A-Za-z0-9_-]+)\)",
        lambda m: palette.get(m.group(1), {}).get("raw", m.group(0)),
        raw,
    )


def ref_alpha(raw):
    """rgba(var(--semi-grey-9), .35) -> 0.35；没有 alpha 时返回 1"""
    m = re.search(r"var\(--semi-[a-z-]+-\d+\)\s*,\s*([\d.]+)\s*\)", raw)
    return float(m.group(1)) if m else 1.0


def scale_ref(raw):
    """rgba(var(--semi-blue-5), 1) -> ('blue', 5)"""
    m = re.search(r"var\(--semi-([a-z]+(?:-[a-z]+)*)-(\d+)\)", raw)
    return (m.group(1), int(m.group(2))) if m else None


# --------------------------------------------------------------------------
# 类型与取值
# --------------------------------------------------------------------------

def camel(name):
    parts = [p for p in re.split(r"[-_]", name) if p and p != "semi"]
    if not parts:
        return name
    return parts[0] + "".join(w[:1].upper() + w[1:] for w in parts[1:])


def qml_field(name):
    if name.startswith("border-radius-"):
        return camel("radius-" + name[len("border-radius-"):])
    if name.startswith("transition_duration-"):
        return camel("duration-" + name[len("transition_duration-"):])
    if name.startswith("transition_delay-"):
        return camel("delay-" + name[len("transition_delay-"):])
    if name.startswith("transition_function-"):
        return camel("easing-" + name[len("transition_function-"):])
    if name.startswith("transform_scale-"):
        return camel("scale-" + name[len("transform_scale-"):])
    if name.startswith("transform_rotate-"):
        return camel("rotate-" + name[len("transform_rotate-"):])
    if name == "transform-rotate-none":
        return "rotateNone"
    return camel(name)


def value_kind(name):
    """返回值类别: scale | color | int | real | string"""
    if re.match(r"^(?:" + "|".join(HUES + AI_HUES) + r")-\d+$", name):
        return "scale"
    if name.startswith("color-") or name in ("black", "white"):
        return "color"
    if name.startswith("shadow"):
        return "string"
    if name.startswith("transition_function-"):
        return "string"
    if name.startswith("transform_scale-"):
        return "real"
    if name.startswith("transform"):
        return "int"
    if name == "font-family-regular":
        return "string"
    return "int"          # 尺寸 / 间距 / z-index / 圆角 / 时长 / 字重 / 描边


def px_int(raw):
    m = re.match(r"^(-?\d+(?:\.\d+)?)(px|ms)?$", raw.strip())
    if m:
        f = float(m.group(1))
        return int(f) if f == int(f) else f
    return 0


def px_real(raw):
    m = re.match(r"^scale\(\s*([\d.]+)", raw.strip())
    return float(m.group(1)) if m else 1.0


def deg_int(raw):
    m = re.match(r"^rotate\(\s*(-?[\d.]+)deg", raw.strip())
    return int(float(m.group(1))) if m else 0


# --------------------------------------------------------------------------
# 数据装配
# --------------------------------------------------------------------------

def build(semi_root):
    scss = semi_root / "packages/semi-theme-default/scss"
    g_light, g_dark = split_modes(scss / "global.scss")
    p_light, p_dark = split_modes(scss / "_palette.scss")
    anim = block_vars(scss / "animation.scss")
    sass = sass_vars(scss / "variables.scss")

    scales, semantics, others = [], [], []

    # 色阶
    for hue in HUES + AI_HUES:
        key = camel(hue)
        scales.append({
            "name": hue, "field": key,
            "light": [scale_hex(p_light[f"{hue}-{i}"]["raw"]) for i in range(10)],
            "dark": [scale_hex(p_dark[f"{hue}-{i}"]["raw"]) for i in range(10)],
        })

    # 语义色（只收颜色；圆角与阴影归到 others，避免重复）
    for name, lm in g_light.items():
        if not name.startswith("color-"):
            continue
        dm = g_dark.get(name, lm)
        l_ref, d_ref = scale_ref(lm["raw"]), scale_ref(dm["raw"])
        # 只有真正的色阶（16 色系 + AI 紫）才参与派生；
        # ai-general-N 是一组独立的渐变色标，不是 10 级色阶。
        # 另外引用带了透明度（rgba(var(--semi-grey-9), .35)）时也不能派生 ——
        # 色阶里存的是不透明色，派生会把 alpha 丢掉。
        derive = (l_ref
                  if (l_ref and l_ref == d_ref and l_ref[0] in SCALE_HUES
                      and ref_alpha(lm["raw"]) >= 1.0 and ref_alpha(dm["raw"]) >= 1.0)
                  else None)
        semantics.append({
            "name": name, "field": qml_field(name),
            "desc": lm["desc"] or dm["desc"],
            "light": resolve_color(lm["raw"], p_light),
            "dark": resolve_color(dm["raw"], p_dark),
            "rawLight": lm["raw"], "rawDark": dm["raw"],
            "derive": derive,                       # (hue, level) 或 None
            "ref": f"{l_ref[0]}-{l_ref[1]}" if l_ref else None,
        })

    # 其余（圆角 / 阴影 / 动效 / 尺寸）
    for name, m in g_light.items():
        if name.startswith("color-") or name in ("black", "white"):
            continue
        kind = value_kind(name)
        others.append({"name": name, "field": qml_field(name), "kind": kind,
                       "desc": m["desc"], "value": m["raw"], "source": "global"})

    for name, m in anim.items():
        kind = value_kind(name)
        others.append({"name": name, "field": qml_field(name), "kind": kind,
                       "desc": m["desc"], "value": m["raw"], "source": "animation"})

    for name, m in sass.items():
        if name == "prefix":
            continue
        kind = value_kind(name)
        others.append({"name": name, "field": qml_field(name), "kind": kind,
                       "desc": m["desc"], "value": m["raw"], "source": "variables"})

    # 中性色（在 _palette.scss 里，不属于色阶也不属于语义色）
    for name in ("black", "white"):
        if name not in p_light:
            continue
        others.append({
            "name": name, "field": camel(name), "kind": "color",
            "desc": f"中性色 {name}", "value": p_light[name]["raw"], "source": "palette",
            "light": scale_hex(p_light[name]["raw"]),
            "dark": scale_hex(p_dark.get(name, p_light[name])["raw"]),
        })

    # AI 渐变（10 条，值是 linear-gradient；展示时展开成真实色标）
    for i in range(10):
        key = f"ai-general-{i}"
        if key not in p_light:
            continue
        others.append({
            "name": key, "field": camel(key), "kind": "gradient",
            "desc": f"AI 渐变色 {i}", "value": p_light[key]["raw"], "source": "palette",
            "light": expand_gradient(p_light[key]["raw"], p_light),
            "dark": expand_gradient(p_dark.get(key, p_light[key])["raw"], p_dark),
        })

    return {"scales": scales, "semantics": semantics, "others": others,
            "palette_light": p_light, "palette_dark": p_dark}


# --------------------------------------------------------------------------
# C++ 生成
# --------------------------------------------------------------------------

TYPE_MAP = {"color": "QColor", "gradient": "QString", "string": "QString",
            "real": "qreal", "int": "int"}


def cap(s):
    return s[0].upper() + s[1:]


def cpp_color(value):
    if not value:
        return "QColor()"
    m = re.match(r"^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$", value)
    if m:
        r, g, b, a = int(m.group(1)), int(m.group(2)), int(m.group(3)), float(m.group(4))
        return f"QColor({r}, {g}, {b}, {round(a * 255)})"
    return f'QColor(QStringLiteral("{value}"))'


def cpp_scalar(kind, raw):
    if kind == "real":
        return str(px_real(raw))
    if kind == "int":
        return str(px_int(raw))
    s = str(raw).replace("\\", "\\\\").replace('"', '\\"')
    return f'QStringLiteral("{s}")'


def semantic_group(name):
    for g in ("primary", "secondary", "tertiary", "info", "success", "warning", "danger", "default"):
        if name.startswith("color-" + g + "-") or name == "color-" + g:
            return g
    if name.startswith("color-bg"):          return "背景 bg"
    if name.startswith("color-text"):        return "文本 text"
    if name.startswith("color-fill"):        return "填充 fill"
    if name.startswith("color-border"):      return "描边 border"
    if name.startswith("color-disabled"):    return "禁用 disabled"
    if name.startswith("color-focus"):       return "焦点 focus"
    if name.startswith("color-link"):        return "链接 link"
    if name.startswith("color-data-"):       return "数据可视化 data"
    if name.startswith("color-ai-"):         return "AI"
    if name in ("color-black", "color-white"): return "中性 black/white"
    return "其他"


def is_per_mode(entry):
    """圆角 / 动效 / 尺寸不分明暗；色阶派生的颜色与 AI 渐变分明暗"""
    return entry["source"] in ("palette",) or entry["kind"] == "gradient"


def gen_header(data):
    L = []
    A = L.append
    A("// 本文件由 scripts/gen-theme-tokens.py 从 Semi Design 源码生成，请勿手改。")
    A("// 数据源：packages/semi-theme-default/scss")
    A("")
    A("#pragma once")
    A("")
    A("#include <QColor>")
    A("#include <QList>")
    A("#include <QObject>")
    A("#include <QString>")
    A("#include <QtQmlIntegration/qqmlintegration.h>")
    A("")
    A("namespace semi {")
    A("")
    A("// 一套完整的 Semi 设计令牌。语义色的值由色阶派生，也可被单独覆盖。")
    A("class SemiThemeValues : public QObject")
    A("{")
    A("    Q_OBJECT")
    A("    QML_ANONYMOUS")
    A("")
    A("public:")
    A("    enum Mode { Light, Dark };")
    A("    Q_ENUM(Mode)")
    A("")
    A("    explicit SemiThemeValues(Mode mode, QObject *parent = nullptr);")
    A("")
    A("    Mode mode() const { return m_mode; }")
    A("")

    A("    // ---- 色阶（16 色系 + AI 紫，各 10 级）----")
    for s in data["scales"]:
        f = s["field"]
        A(f"    Q_PROPERTY(QList<QColor> {f} READ {f} WRITE set{cap(f)} NOTIFY changed FINAL)")
    A("")
    A("    // ---- 语义色 ----")
    for s in data["semantics"]:
        f = s["field"]
        A(f"    Q_PROPERTY(QColor {f} READ {f} WRITE set{cap(f)} NOTIFY changed FINAL)")
    A("")
    A("    // ---- 圆角 / 阴影 / AI 渐变 / 动效 / 尺寸 ----")
    for o in data["others"]:
        f = o["field"]
        A(f"    Q_PROPERTY({TYPE_MAP[o['kind']]} {f} READ {f} WRITE set{cap(f)} NOTIFY changed FINAL)")
    A("")

    A("    // ---- 读取 ----")
    for s in data["scales"]:
        f = s["field"]
        A(f"    QList<QColor> {f}() const {{ return m_{f}; }}")
    for s in data["semantics"]:
        f = s["field"]
        if s["derive"]:
            hue, level = s["derive"]
            A(f"    QColor {f}() const {{ return m_{f}Overridden ? m_{f} : m_{camel(hue)}.value({level}); }}")
        else:
            A(f"    QColor {f}() const {{ return m_{f}; }}")
    for o in data["others"]:
        f = o["field"]
        A(f"    {TYPE_MAP[o['kind']]} {f}() const {{ return m_{f}; }}")
    A("")

    A("    // ---- 写入 ----")
    for s in data["scales"]:
        f = s["field"]
        A(f"    void set{cap(f)}(const QList<QColor> &v);")
    for s in data["semantics"]:
        f = s["field"]
        A(f"    void set{cap(f)}(const QColor &v);")
    for o in data["others"]:
        f, t = o["field"], TYPE_MAP[o["kind"]]
        if t in ("int", "qreal"):
            A(f"    void set{cap(f)}({t} v);")
        else:
            A(f"    void set{cap(f)}(const {t} &v);")
    A("")
    A("    // 恢复为 Semi 默认值")
    A("    Q_INVOKABLE void reset();")
    A("")
    A("Q_SIGNALS:")
    A("    void changed();")
    A("")
    A("private:")
    A("    void applyDefaults();")
    A("")
    A("    Mode m_mode;")
    for s in data["scales"]:
        A(f"    QList<QColor> m_{s['field']};")
    for s in data["semantics"]:
        f = s["field"]
        A(f"    QColor m_{f};")
        if s["derive"]:
            A(f"    bool m_{f}Overridden = false;")
    for o in data["others"]:
        f, t = o["field"], TYPE_MAP[o["kind"]]
        if is_per_mode(o):
            A(f"    {t} m_{f};")
        else:
            A(f"    {t} m_{f} = {cpp_scalar(o['kind'], o['value'])};")
    A("};")
    A("")
    A("} // namespace semi")
    A("")
    return "\n".join(L)


def gen_source(data):
    L = []
    A = L.append
    A('#include "SemiThemeValues.h"')
    A("")
    A("namespace semi {")
    A("")
    A("namespace {")
    A("")
    for s in data["scales"]:
        for mode in ("light", "dark"):
            items = ", ".join(cpp_color(v) for v in s[mode])
            A(f"QList<QColor> {s['field']}{cap(mode)}() {{ return {{ {items} }}; }}")
    A("")
    # 无派生的语义色（引用的是 white / black 这类非色阶值）需要各自模式的固定默认值
    for s in data["semantics"]:
        if s["derive"]:
            continue
        for mode in ("light", "dark"):
            A(f"const QColor {s['field']}{cap(mode)} = {cpp_color(s[mode])};")
    A("")
    for o in data["others"]:
        if not is_per_mode(o) or o["kind"] == "gradient":
            continue
        for mode in ("light", "dark"):
            A(f"const QColor {o['field']}{cap(mode)} = {cpp_color(o[mode])};")
    A("")
    for o in data["others"]:
        if o["kind"] != "gradient":
            continue
        for mode in ("light", "dark"):
            s = str(o[mode]).replace("\\", "\\\\").replace('"', '\\"')
            A(f'const QString {o["field"]}{cap(mode)} = QStringLiteral("{s}");')
    A("")
    A("} // namespace")
    A("")
    A("SemiThemeValues::SemiThemeValues(Mode mode, QObject *parent)")
    A("    : QObject(parent)")
    A("    , m_mode(mode)")
    A("{")
    A("    applyDefaults();")
    A("}")
    A("")
    A("void SemiThemeValues::applyDefaults()")
    A("{")
    A("    if (m_mode == Dark) {")
    for s in data["scales"]:
        A(f"        m_{s['field']} = {s['field']}Dark();")
    for s in data["semantics"]:
        if not s["derive"]:
            A(f"        m_{s['field']} = {s['field']}Dark;")
    for o in data["others"]:
        if o["kind"] == "color" and is_per_mode(o):
            A(f"        m_{o['field']} = {o['field']}Dark;")
        elif o["kind"] == "gradient":
            A(f"        m_{o['field']} = {o['field']}Dark;")
    A("    } else {")
    for s in data["scales"]:
        A(f"        m_{s['field']} = {s['field']}Light();")
    for s in data["semantics"]:
        if not s["derive"]:
            A(f"        m_{s['field']} = {s['field']}Light;")
    for o in data["others"]:
        if o["kind"] == "color" and is_per_mode(o):
            A(f"        m_{o['field']} = {o['field']}Light;")
        elif o["kind"] == "gradient":
            A(f"        m_{o['field']} = {o['field']}Light;")
    A("    }")
    A("}")
    A("")
    A("void SemiThemeValues::reset()")
    A("{")
    for s in data["semantics"]:
        if s["derive"]:
            A(f"    m_{s['field']}Overridden = false;")
    for o in data["others"]:
        if not is_per_mode(o):
            A(f"    m_{o['field']} = {cpp_scalar(o['kind'], o['value'])};")
    A("    applyDefaults();")
    A("    Q_EMIT changed();")
    A("}")
    A("")
    for s in data["scales"]:
        f = s["field"]
        A(f"void SemiThemeValues::set{cap(f)}(const QList<QColor> &v)")
        A("{")
        A(f"    if (m_{f} == v)")
        A("        return;")
        A(f"    m_{f} = v;")
        A("    Q_EMIT changed();")
        A("}")
        A("")
    for s in data["semantics"]:
        f = s["field"]
        A(f"void SemiThemeValues::set{cap(f)}(const QColor &v)")
        A("{")
        if s["derive"]:
            A(f"    if (m_{f}Overridden && m_{f} == v)")
            A("        return;")
            A(f"    m_{f} = v;")
            A(f"    m_{f}Overridden = true;")
        else:
            A(f"    if (m_{f} == v)")
            A("        return;")
            A(f"    m_{f} = v;")
        A("    Q_EMIT changed();")
        A("}")
        A("")
    for o in data["others"]:
        f, t = o["field"], TYPE_MAP[o["kind"]]
        arg = f"{t} v" if t in ("int", "qreal") else f"const {t} &v"
        A(f"void SemiThemeValues::set{cap(f)}({arg})")
        A("{")
        A(f"    if (m_{f} == v)")
        A("        return;")
        A(f"    m_{f} = v;")
        A("    Q_EMIT changed();")
        A("}")
        A("")
    A("} // namespace semi")
    A("")
    return "\n".join(L)


# --------------------------------------------------------------------------
# 自检
# --------------------------------------------------------------------------

def self_check(data):
    ok = True

    def chk(label, got, want):
        nonlocal ok
        hit = got == want
        ok = ok and hit
        print(f"  [{'OK ' if hit else 'FAIL'}] {label}: {got}" + ("" if hit else f"  期望 {want}"))

    sc = {s["name"]: s for s in data["scales"]}
    se = {s["name"]: s for s in data["semantics"]}
    chk("blue-5 light", sc["blue"]["light"][5], "#0064fa")
    chk("blue-5 dark", sc["blue"]["dark"][5], "#54a9ff")
    chk("grey-0 light", sc["grey"]["light"][0], "#f9f9f9")
    chk("grey-0 dark", sc["grey"]["dark"][0], "#1c1f23")
    chk("color-primary light", se["color-primary"]["light"], "#0064fa")
    chk("color-primary dark", se["color-primary"]["dark"], "#54a9ff")
    chk("color-primary 派生自", se["color-primary"]["derive"], ("blue", 5))
    chk("color-danger 派生自", se["color-danger"]["derive"], ("red", 5))
    chk("color-white 无派生(明暗引用不同)", se["color-white"]["derive"], None)

    names = {o["name"] for o in data["others"]}
    chk("含中性色 black / white", ("black" in names, "white" in names), (True, True))
    chk("AI 渐变条数", sum(1 for o in data["others"] if o["kind"] == "gradient"), 10)
    chk("圆角令牌数", sum(1 for o in data["others"] if o["name"].startswith("border-radius")), 6)
    chk("动效令牌数", sum(1 for o in data["others"] if o["source"] == "animation"), 34)
    chk("尺寸令牌数", sum(1 for o in data["others"] if o["source"] == "variables"), 49)

    total = len(data["semantics"]) + sum(len(s["light"]) for s in data["scales"]) + len(data["others"])
    chk("令牌总数", total, 383)
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--semi-root", default=str(DEFAULT_SEMI_ROOT))
    ap.add_argument("--out-src", default="src")
    args = ap.parse_args()

    semi_root = pathlib.Path(args.semi_root).expanduser()
    if not (semi_root / "packages/semi-theme-default/scss/_palette.scss").exists():
        sys.exit(f"找不到 Semi 源码: {semi_root}")

    data = build(semi_root)

    print("自检：")
    if not self_check(data):
        sys.exit("自检失败，已中止生成")

    print(f"\n色阶 {len(data['scales'])} 组 / 语义色 {len(data['semantics'])} 个 / 其他 {len(data['others'])} 个")

    out_src = pathlib.Path(args.out_src)
    out_src.mkdir(parents=True, exist_ok=True)

    (out_src / "SemiThemeValues.h").write_text(gen_header(data))
    (out_src / "SemiThemeValues.cpp").write_text(gen_source(data))

    print(f"-> {out_src}/SemiThemeValues.h")
    print(f"-> {out_src}/SemiThemeValues.cpp")


if __name__ == "__main__":
    main()
