.pragma library

// Tokens 页要算的两类数：WCAG 对比度与 Lab 色差。
//
// 两边都照官网用的那两个库的实现来，不自己凑公式：
//   · chroma-js  src/utils/contrast.js + src/ops/luminance.js + src/io/lab/rgb2lab.js
//   · wcag-color src/index.re 的 calculate / calculateFromRatio
// 数值对账见 examples/gallery/build/check-token-color.py（拿 node 直接跑这两个库出参考值）。
//
// 一处口径要说清楚：官网「颜色转换」用的是 chroma.distance(a, b) 的缺省档 'lab'，
// 那是 **Lab 空间的欧氏距离（ΔE76）**，不是 CIEDE2000（chroma 里另有一个 delta('ciede2000')，
// 站点没用它）。io/distance.coffee 的注释也写着 "Delta E (CIE 1976)"。

// ---------------------------------------------------------------- 解析

// 支持 #rgb / #rrggbb / #rrggbbaa、rgb()/rgba()、以及色板里那种 `R,G,B` 三元组。
// 官网走 chroma.valid()，那连 `red`、`papayawhip` 这类名字都认；端口只吃上面三种写法，
// 认不出来的返回 null，页面按「无效输入」处理（不换算、不清空结果，与官网一致）。
function parseColor(text) {
    if (text === undefined || text === null)
        return null;
    var s = String(text).trim();
    if (s === "")
        return null;

    var m = /^#([0-9a-fA-F]{3})$/.exec(s);
    if (m) {
        var h = m[1];
        return { r: parseInt(h[0] + h[0], 16), g: parseInt(h[1] + h[1], 16),
                 b: parseInt(h[2] + h[2], 16), a: 1 };
    }
    m = /^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/.exec(s);
    if (m) {
        return { r: parseInt(m[1].slice(0, 2), 16), g: parseInt(m[1].slice(2, 4), 16),
                 b: parseInt(m[1].slice(4, 6), 16),
                 a: m[2] === undefined ? 1 : parseInt(m[2], 16) / 255 };
    }
    m = /^rgba?\(([^)]*)\)$/.exec(s);
    if (m) {
        var parts = m[1].split(/[,\/ ]+/).filter(function (p) { return p !== ""; });
        if (parts.length < 3)
            return null;
        var rgb = [num(parts[0]), num(parts[1]), num(parts[2])];
        if (rgb.some(function (v) { return v === null; }))
            return null;
        return { r: clamp255(rgb[0]), g: clamp255(rgb[1]), b: clamp255(rgb[2]),
                 a: parts.length > 3 ? Number(parts[3]) : 1 };
    }
    // 色板值 `254,251,235`
    m = /^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*$/.exec(s);
    if (m) {
        return { r: clamp255(Number(m[1])), g: clamp255(Number(m[2])),
                 b: clamp255(Number(m[3])), a: 1 };
    }
    return null;
}

function num(text) {
    // 百分数按 chroma 的习惯乘满 255 之前先归一（站点没用到，这里按 CSS 语义处理）
    var t = String(text).trim();
    if (t === "")
        return null;
    var v = Number(t);
    return isNaN(v) ? null : v;
}

function clamp255(v) {
    return Math.max(0, Math.min(255, Math.round(v)));
}

// ---------------------------------------------------------------- WCAG

// chroma-js ops/luminance.js 的 rgb2luminance
function luminance(c) {
    return 0.2126 * lx(c.r) + 0.7152 * lx(c.g) + 0.0722 * lx(c.b);
}

function lx(x) {
    x /= 255;
    return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
}

// chroma-js utils/contrast.js
function contrast(a, b) {
    var l1 = luminance(a);
    var l2 = luminance(b);
    return l1 > l2 ? (l1 + 0.05) / (l2 + 0.05) : (l2 + 0.05) / (l1 + 0.05);
}

// wcag-color 的 calculate：先按 toFixed(2) 舍到两位小数，再交给分档
// （不舍就会出现 6.996 判 Fail 而官网判 AAA 的差一档）
function contrastScore(a, b) {
    var r = Number(contrast(a, b).toFixed(2));
    return scoreFromRatio(r);
}

// wcag-color 的 calculateFromRatio
function scoreFromRatio(ratio) {
    if (ratio >= 7.0)
        return "AAA";
    if (ratio >= 4.5)
        return "AA";
    if (ratio >= 3.0)
        return "AA Large";
    return "Fail";
}

var WHITE = { r: 255, g: 255, b: 255, a: 1 };
var BLACK = { r: 0, g: 0, b: 0, a: 1 };

// ---------------------------------------------------------------- Lab 色差

// chroma-js io/lab/lab-constants.js（D65）
var XN = 0.95047;
var YN = 1;
var ZN = 1.08883;
var T0 = 0.137931034;   // 4 / 29
var T2 = 0.12841855;    // 3 * t1 * t1
var T3 = 0.008856452;   // t1 * t1 * t1

function rgbXyzChannel(v) {
    v /= 255;
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

function xyzLab(t) {
    return t > T3 ? Math.pow(t, 1 / 3) : t / T2 + T0;
}

// chroma-js io/lab/rgb2lab.js
function labOf(c) {
    var r = rgbXyzChannel(c.r);
    var g = rgbXyzChannel(c.g);
    var b = rgbXyzChannel(c.b);
    var x = xyzLab((0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / XN);
    var y = xyzLab((0.2126729 * r + 0.7151522 * g + 0.072175 * b) / YN);
    var z = xyzLab((0.0193339 * r + 0.119192 * g + 0.9503041 * b) / ZN);
    var l = 116 * y - 16;
    return [l < 0 ? 0 : l, 500 * (x - y), 200 * (y - z)];
}

// chroma-js io/distance.coffee：对 get('lab') 的三分量求欧氏距离（ΔE76）
function labDistance(a, b) {
    var la = labOf(a);
    var lb = labOf(b);
    var sum = 0;
    for (var i = 0; i < 3; ++i) {
        var d = la[i] - lb[i];
        sum += d * d;
    }
    return Math.sqrt(sum);
}

// ---------------------------------------------------------------- 最近色
//
// 官网 ColorConverter 的 getClosestColors：按距离升序排完，只收**与最小值相等**的那些，
// 一旦遇到更大的就 break。所以「颜色转换」那一节通常只出一块（并列最少有两个同距离才多几块）。
// 这是上游的行为，端口照抄，见 PROGRESS 坑「颜色转换只列最小距离」。
function closestTokens(input, entries) {
    var scores = [];
    for (var i = 0; i < entries.length; ++i) {
        var e = entries[i];
        if (e.gradient)
            continue;                       // 官网跳过 linear-gradient 的条目
        var c = parseColor(e.value);
        if (c === null)
            continue;
        scores.push({ distance: labDistance(input, c), index: i });
    }
    if (scores.length === 0)
        return [];
    scores.sort(function (a, b) { return a.distance - b.distance; });
    var min = scores[0].distance;
    var out = [];
    for (var j = 0; j < scores.length; ++j) {
        if (scores[j].distance !== min)
            break;
        out.push(scores[j].index);
    }
    return out;
}
