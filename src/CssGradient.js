.pragma library

// CSS linear-gradient 字符串解析。Semi 的 AI 多彩按钮背景不是色值而是一整段
// `linear-gradient(278deg, rgba(r,g,b) 0%, rgba(...) 30%, ...)`，主题里按原样存着
// （SemiThemeValues 的 aiGeneral0..9 就是这种字符串），这里拆成 QML 能用的色标。
//
// Qt 的 Rectangle.gradient 只有 Vertical / Horizontal 两种朝向，没有任意角度：
// 278deg 的水平分量占 0.99，那点倾角在几十像素高的按钮上看不出来，所以按正水平画，
// 并把 CSS 的 0% 放到右端（278deg 指向左，起点在右侧）。
//
// background-clip: text（多彩文字）Qt Quick 侧没有对应能力，退化成取一个代表色，
// 见 representative()。

// → [{ color: "#rrggbb", position: 0..1 }]，position 已经是 QML 的水平朝向。
// 一律换成十六进制：QML 把字符串隐式转成 color 时只认 #RRGGBB / #AARRGGBB / 颜色名，
// 传 "rgb(140,105,255)" 过去会得到黑色。
function horizontalStops(gradientText) {
    const parsed = parse(gradientText);
    const out = [];
    for (let i = 0; i < parsed.stops.length; ++i) {
        out.push({
            color: toHex(parsed.stops[i].color),
            position: parsed.leftToRight ? parsed.stops[i].position
                : 1 - parsed.stops[i].position
        });
    }
    out.sort(function (a, b) { return a.position - b.position; });
    return out;
}

// 取首尾两个色标的中间值，作为「渐变铺在文字上」的单色替身
function representative(gradientText) {
    const parsed = parse(gradientText);
    if (parsed.stops.length === 0)
        return "";
    const first = toRgba(parsed.stops[0].color);
    const last = toRgba(parsed.stops[parsed.stops.length - 1].color);
    if (first === null || last === null)
        return toHex(parsed.stops[0].color);
    return hex(mixRgba(first, last, 0.5));
}

// 多彩按钮上的图标官方拿的是 fill[0] = --semi-ai-general-*-3，也就是渐变的最后一个色标
function endColor(gradientText) {
    const parsed = parse(gradientText);
    if (parsed.stops.length === 0)
        return "";
    return toHex(parsed.stops[parsed.stops.length - 1].color);
}

function parse(gradientText) {
    const empty = { angle: 0, leftToRight: true, stops: [] };
    if (gradientText === undefined || gradientText === null)
        return empty;
    const text = String(gradientText);
    const open = text.indexOf("(");
    const close = text.lastIndexOf(")");
    if (open < 0 || close <= open)
        return empty;
    const segments = splitSegments(text.slice(open + 1, close));

    let angle = 0;
    let first = 0;
    if (segments.length > 0 && segments[0].indexOf("deg") >= 0) {
        angle = parseFloat(segments[0]);
        first = 1;
    }
    const stops = [];
    for (let i = first; i < segments.length; ++i) {
        const piece = segments[i].trim();
        if (piece === "")
            continue;
        // 位置在最前面（`0% rgba(...)`）或最后面（`rgba(...) 0%`）两种写法官方都可能出现，
        // 这里按「末尾是百分比」处理，取不到就当等分
        const tail = piece.match(/(-?[0-9.]+)%\s*$/);
        let position = stops.length / Math.max(1, segments.length - first);
        let color = piece;
        if (tail !== null) {
            position = parseFloat(tail[1]) / 100;
            color = piece.slice(0, tail.index).trim();
        }
        stops.push({ color: color, position: position });
    }
    // dx = sin(angle)：CSS 角度从正上方顺时针量，90deg 指向右、270deg 指向左
    const dx = Math.sin(angle * Math.PI / 180);
    return { angle: angle, leftToRight: dx >= 0, stops: stops };
}

// 按逗号切，但 rgba(...) 内部的逗号不切
function splitSegments(body) {
    const out = [];
    let pending = "";
    let depth = 0;
    for (let i = 0; i < body.length; ++i) {
        const ch = body.charAt(i);
        if (ch === "(")
            depth += 1;
        else if (ch === ")")
            depth -= 1;
        if (ch === "," && depth === 0) {
            out.push(pending);
            pending = "";
        } else {
            pending += ch;
        }
    }
    out.push(pending);
    return out;
}

function mixRgba(a, b, ratio) {
    return [a[0] + (b[0] - a[0]) * ratio, a[1] + (b[1] - a[1]) * ratio,
        a[2] + (b[2] - a[2]) * ratio, a[3] + (b[3] - a[3]) * ratio];
}

function hex(rgba) {
    function part(value) {
        const clamped = Math.max(0, Math.min(255, Math.round(value)));
        const text = clamped.toString(16);
        return text.length === 1 ? "0" + text : text;
    }

    const body = part(rgba[0]) + part(rgba[1]) + part(rgba[2]);
    if (rgba[3] >= 1)
        return "#" + body;
    return "#" + part(rgba[3] * 255) + body;
}

function toHex(color) {
    const rgba = toRgba(color);
    return rgba === null ? color : hex(rgba);
}

// "#rrggbb" / "rgb(r,g,b)" / "rgba(r,g,b,a)" → [r, g, b, a]
function toRgba(color) {
    const text = String(color).trim();
    if (text.charAt(0) === "#") {
        const hex = text.slice(1);
        if (hex.length !== 6 && hex.length !== 3)
            return null;
        let full = hex;
        if (hex.length === 3)
            full = hex.charAt(0) + hex.charAt(0) + hex.charAt(1) + hex.charAt(1)
                + hex.charAt(2) + hex.charAt(2);
        return [parseInt(full.slice(0, 2), 16), parseInt(full.slice(2, 4), 16),
            parseInt(full.slice(4, 6), 16), 1];
    }
    const open = text.indexOf("(");
    const close = text.lastIndexOf(")");
    if (open < 0 || close <= open)
        return null;
    const parts = text.slice(open + 1, close).split(",");
    if (parts.length < 3)
        return null;
    return [parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]),
        parts.length > 3 ? parseFloat(parts[3]) : 1];
}
