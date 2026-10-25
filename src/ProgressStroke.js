.pragma library

// Progress 的 stroke 档位取色 —— 官方 semi-foundation/progress/generates.ts 的移植。
//
// `stroke` 传 `[{percent, color}]` 时，官方并不是画一条空间渐变，而是**按当前 percent
// 落在哪两个档位之间，挑一个纯色**（整条进度条换一个色）；`strokeGradient: true` 才在这两档
// 之间线性插值出一个中间色。generateGradients 里那条「返回一串色标」的分支官方自己走不到
// （调用处永远传 index），所以这里不搬。
//
// 与官方逐条对齐的点：
//   · 档位先按 percent 升序排；比第一档还小 → 用默认色（官方返回 'var(--semi-color-success)'，
//     这里回 null 让调用方落到令牌上）；比最后一档还大 → 用最后一档的色；
//   · 命中判断用**原始 percent**，不是夹到 0..100 之后的值（官方 selectStroke 传的是
//     this.props.percent），所以 percent=150 拿的是最后一档、-5 拿的是默认色；
//   · 插值步长 `size = 上档.percent - 1`、`index = percent - 上档.percent - 1`，
//     通道值 `round(start - (start - end) / (size + 1) * (index + 1))`，
//     也就是按「进到了这一段的几分之几」在两个色之间取点。
//
// 有意差异：
//   · 官方 `s.sort()` 会**就地改调用方传进来的数组**，这里先拷贝一份再排；
//   · 官方透明度走 `parseInt`，`hsla(... / 0.5)` 会被解析成 0（全透明），这里按小数读；
//   · 官方输出 `#RRGGBBAA`，QML 认的是 `#AARRGGBB`，这里按 QML 的次序输出；
//   · 官方的 Semi Design Token 查表要读 `getComputedStyle`，本端口拿不到 CSS 变量，
//     由调用方（Progress.qml）注入 resolve 回调去查主题色阶。

// text → [r, g, b, a]，r/g/b 与 a 都是 0..255。解析不出来时交给 resolve（主题令牌），
// 再不行返回 null（官方这时会回落到 scss 的默认色）。
function toRgba(text, resolve) {
    if (text === undefined || text === null)
        return null;
    const raw = String(text).trim().toLowerCase();
    if (raw === "")
        return null;

    if (raw.charAt(0) === "#") {
        const body = raw.slice(1);
        let full = body;
        if (body.length === 3 || body.length === 4) {
            full = "";
            for (let i = 0; i < body.length; ++i)
                full += body.charAt(i) + body.charAt(i);
        }
        if (full.length === 6 || full.length === 8) {
            const r = parseInt(full.slice(0, 2), 16);
            const g = parseInt(full.slice(2, 4), 16);
            const b = parseInt(full.slice(4, 6), 16);
            const a = full.length === 8 ? parseInt(full.slice(6, 8), 16) : 255;
            if (r >= 0 && g >= 0 && b >= 0)
                return [r, g, b, a];
            return null;
        }
        return null;
    }

    const open = raw.indexOf("(");
    const close = raw.lastIndexOf(")");
    const fn = open > 0 && close > open ? raw.slice(0, open).trim() : "";
    if (fn === "rgb" || fn === "rgba" || fn === "hsl" || fn === "hsla") {
        const body = raw.slice(open + 1, close);
        // 逗号与「/ 透明度」两种分隔都吃：官方那三个正则实际上把逗号做成可选，
        // 示例里 hsla(125, 50%, 46% / 1) 这种混合写法要能解
        const parts = [];
        let pending = "";
        for (let i = 0; i < body.length; ++i) {
            const ch = body.charAt(i);
            if (ch === "," || ch === "/") {
                parts.push(pending);
                pending = "";
            } else {
                pending += ch;
            }
        }
        parts.push(pending);
        const num = [];
        for (let i = 0; i < parts.length; ++i) {
            const piece = parts[i].trim().replace(/%$/, "");
            if (piece === "")
                continue;
            num.push(parseFloat(piece));
        }
        let alpha = num.length > 3 ? num[3] : 1;
        if (alpha > 1)
            alpha = alpha / 255;
        if (fn === "rgb" || fn === "rgba") {
            if (num.length < 3 || isNaN(num[0]) || isNaN(num[1]) || isNaN(num[2]))
                return null;
            return [num[0], num[1], num[2], Math.round(alpha * 255)];
        }
        if (num.length < 3 || isNaN(num[0]) || isNaN(num[1]) || isNaN(num[2]))
            return null;
        const rgb = hslToRgb(num[0], num[1] / 100, num[2] / 100);
        return [rgb[0], rgb[1], rgb[2], Math.round(alpha * 255)];
    }

    // var(--semi-color-warning) / --semi-orange-9 / red 这类交给令牌解析
    // （官方那步走 getComputedStyle，本端口拿不到 CSS 变量）
    if (resolve !== undefined && resolve !== null)
        return resolve(raw);
    return null;
}

function hslToRgb(hue, sat, light) {
    const h = ((hue % 360) + 360) % 360;
    const c = (1 - Math.abs(2 * light - 1)) * sat;
    const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
    const m = light - c / 2;
    let r = 0;
    let g = 0;
    let b = 0;
    if (h < 60) {
        r = c; g = x;
    } else if (h < 120) {
        r = x; g = c;
    } else if (h < 180) {
        g = c; b = x;
    } else if (h < 240) {
        g = x; b = c;
    } else if (h < 300) {
        r = x; b = c;
    } else {
        r = c; b = x;
    }
    return [Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255)];
}

// 0..255 → 两位十六进制
function hexPair(value) {
    const clamped = Math.max(0, Math.min(255, Math.round(value)));
    const text = clamped.toString(16);
    return text.length === 1 ? "0" + text : text;
}

function hexText(rgba) {
    const body = hexPair(rgba[0]) + hexPair(rgba[1]) + hexPair(rgba[2]);
    if (rgba[3] >= 255)
        return "#" + body;
    return "#" + hexPair(rgba[3]) + body;      // QML 认 #AARRGGBB，官方那串是 #RRGGBBAA
}

// strokes: [{percent, color}]，percent 用原始值。返回 "#rrggbb[aa]"，
// null 表示「按 scss 默认色走」。
function strokeColor(strokes, percent, gradient, resolve) {
    if (strokes === undefined || strokes === null || strokes.length === 0)
        return null;

    // 拷贝而不是 slice()：调用方可能传 list-like 对象（Array.isArray 为 false 的那一种），
    // 它未必带 slice 方法；同时官方的 s.sort() 会就地改调用方数组，这里刻意不改。
    const sorted = [];
    for (let i = 0; i < strokes.length; ++i)
        sorted.push(strokes[i]);
    sorted.sort(function (a, b) {
        return a.percent - b.percent;
    });
    const first = sorted[0];
    if (first === undefined || first.percent === undefined || isNaN(first.percent))
        return null;
    if (first.percent > percent)
        return null;                            // 官方这里回 STROKE_DEFAULT
    const last = sorted[sorted.length - 1];
    if (last.percent < percent)
        return colorOf(last.color, resolve);
    for (let i = 0; i < sorted.length; ++i) {
        const item = sorted[i];
        if (item.percent === percent)
            return colorOf(item.color, resolve);
        if (percent > item.percent)
            continue;
        const prev = sorted[i - 1];
        if (prev === undefined)
            return null;
        if (!gradient)
            return colorOf(prev.color, resolve);
        const from = toRgba(colorOf(prev.color, resolve), resolve);
        const to = toRgba(colorOf(item.color, resolve), resolve);
        if (from === null || to === null)
            return null;
        return hexText(mix(from, to, percent, prev.percent, item.percent));
    }
    return null;
}

// 官方 tHex：step = (start - end) / (size + 1)，值 = round(start - step * (index + 1))，
// 其中 size + 1 = 两档之差、index + 1 = 当前 percent 越过上一档的量。
function mix(from, to, percent, fromPercent, toPercent) {
    const span = toPercent - fromPercent;
    const walked = percent - fromPercent;
    const out = [];
    for (let i = 0; i < 3; ++i)
        out.push(Math.round(from[i] - (from[i] - to[i]) / span * walked));
    // 官方对透明度用的是 floor 而不是 round，差不到 1 个色阶，照抄
    out.push(Math.floor(from[3] - (from[3] - to[3]) / span * walked));
    return out;
}

function colorOf(color, resolve) {
    const rgba = toRgba(color, resolve);
    return rgba === null ? null : hexText(rgba);
}
