.pragma library

// 颜色空间换算。对应 semi-foundation/colorPicker/utils/{convert.ts,split.ts,round.ts}
// —— 那三个文件本身是从 vanilla-colorful 抄的（convert.ts:9 写了出处）。
// 纯函数、无状态，所以和 CalendarDate.js 一样用 .pragma library 让组件与测试共享同一份。

function round(number, digits) {
    const base = Math.pow(10, digits === undefined ? 0 : digits);
    return Math.round(base * number) / base;
}

const angleUnits = {
    grad: 360 / 400,
    turn: 360,
    rad: 360 / (Math.PI * 2)
};

function parseHue(value, unit) {
    return Number(value) * (angleUnits[unit] || 1);
}

function hexToPercent(str) {
    const decimal = parseInt(str, 16);
    if (!isNaN(decimal))
        return decimal / 255;
    return 1;
}

// convert.ts:19-38
function hexToRgba(hex) {
    let body = hex;
    if (body[0] === "#")
        body = body.substring(1);
    return {
        r: parseInt(body.substring(0, 2), 16),
        g: parseInt(body.substring(2, 4), 16),
        b: parseInt(body.substring(4, 6), 16),
        a: hexToPercent(body.substring(6, 8))
    };
}

function hexToHsva(hex) {
    return rgbaToHsva(hexToRgba(hex));
}

// convert.ts:104-123
function hsvaToRgba(hsva) {
    let h = (hsva.h / 360) * 6;
    const s = hsva.s / 100;
    const v = hsva.v / 100;

    const hh = Math.floor(h);
    const b = v * (1 - s);
    const c = v * (1 - (h - hh) * s);
    const d = v * (1 - (1 - h + hh) * s);
    const module = hh % 6;

    return {
        r: round([v, c, b, b, d, v][module] * 255),
        g: round([d, v, v, c, b, b][module] * 255),
        b: round([b, b, d, v, v, c][module] * 255),
        a: round(hsva.a, 2)
    };
}

// convert.ts:192-212
function rgbaToHsva(rgba) {
    const max = Math.max(rgba.r, rgba.g, rgba.b);
    const delta = max - Math.min(rgba.r, rgba.g, rgba.b);

    let hh = 0;
    if (delta) {
        if (max === rgba.r)
            hh = (rgba.g - rgba.b) / delta;
        else if (max === rgba.g)
            hh = 2 + (rgba.b - rgba.r) / delta;
        else
            hh = 4 + (rgba.r - rgba.g) / delta;
    }

    return {
        h: round(60 * (hh < 0 ? hh + 6 : hh)),
        s: round(max ? (delta / max) * 100 : 0),
        v: round((max / 255) * 100),
        a: rgba.a
    };
}

function twoDigits(number) {
    const hex = number.toString(16);
    return hex.length < 2 ? "0" + hex : hex;
}

// convert.ts:177-190：a 缺省或为 1 时是 6 位，否则把 alpha 按百分比换成两位
function rgbaToHex(rgba) {
    if (rgba.a === undefined || rgba.a === 1)
        return "#" + twoDigits(rgba.r) + twoDigits(rgba.g) + twoDigits(rgba.b);
    const intValue = Math.round(rgba.a * 255);
    return "#" + twoDigits(rgba.r) + twoDigits(rgba.g) + twoDigits(rgba.b)
        + intValue.toString(16).padStart(2, "0").toLowerCase();
}

function hsvaToHex(hsva) {
    return rgbaToHex(hsvaToRgba(hsva));
}

// convert.ts:73-82
function hsvaToHsla(hsva) {
    const hh = ((200 - hsva.s) * hsva.v) / 100;
    return {
        h: round(hsva.h),
        s: round(hh > 0 && hh < 200 ? ((hsva.s * hsva.v) / 100 / (hh <= 100 ? hh : 200 - hh)) * 100 : 0),
        l: round(hh / 2),
        a: round(hsva.a, 2)
    };
}

// 取色区底色：hsvaToHslString({h, s:100, v:100, a:1})（ColorChooseArea/index.tsx:78）
function hsvaToHslString(hsva) {
    const hsl = hsvaToHsla(hsva);
    return "hsl(" + hsl.h + ", " + hsl.s + "%, " + hsl.l + "%)";
}

function hsvaToHslaString(hsva) {
    const hsla = hsvaToHsla(hsva);
    return "hsla(" + hsla.h + ", " + hsla.s + "%, " + hsla.l + "%, " + hsla.a + ")";
}

function hsvaToRgbaString(hsva) {
    const rgba = hsvaToRgba(hsva);
    return "rgba(" + rgba.r + ", " + rgba.g + ", " + rgba.b + ", " + rgba.a + ")";
}

// convert.ts:155-167，同时吃 rgb() 与 rgba()（rgbStringToRgba 就是它别名）
function rgbaStringToRgba(text) {
    const matcher = /rgba?\(?\s*(-?\d*\.?\d+)(%)?[,\s]+(-?\d*\.?\d+)(%)?[,\s]+(-?\d*\.?\d+)(%)?,?\s*[/\s]*(-?\d*\.?\d+)?(%)?\s*\)?/i;
    const match = matcher.exec(text);
    if (!match)
        return { r: 0, g: 0, b: 0, a: 1 };
    return {
        r: Number(match[1]) / (match[2] ? 100 / 255 : 1),
        g: Number(match[3]) / (match[4] ? 100 / 255 : 1),
        b: Number(match[5]) / (match[6] ? 100 / 255 : 1),
        a: match[7] === undefined ? 1 : Number(match[7]) / (match[8] ? 100 : 1)
    };
}

function rgbaStringToHsva(text) {
    return rgbaToHsva(rgbaStringToRgba(text));
}

// convert.ts:135-147
function hsvaStringToHsva(text) {
    const matcher = /hsva?\(?\s*(-?\d*\.?\d+)(deg|rad|grad|turn)?[,\s]+(-?\d*\.?\d+)%?[,\s]+(-?\d*\.?\d+)%?,?\s*[/\s]*(-?\d*\.?\d+)?(%)?\s*\)?/i;
    const match = matcher.exec(text);
    if (!match)
        return { h: 0, s: 0, v: 0, a: 1 };
    return roundHsva({
        h: parseHue(match[1], match[2]),
        s: Number(match[3]),
        v: Number(match[4]),
        a: match[5] === undefined ? 1 : Number(match[5]) / (match[6] ? 100 : 1)
    });
}

function roundHsva(hsva) {
    return {
        h: round(hsva.h),
        s: round(hsva.s),
        v: round(hsva.v),
        a: round(hsva.a, 2)
    };
}

// split.ts：「12,32,43」或「12,32,43,0.5」。超范围或解析不出返回 false
function split(text, mode) {
    const reg = /^\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,?\s*([\d.]*)\s*$/;
    const res = text.match(reg);
    const result = [];
    result[0] = Number(res ? res[1] : NaN);
    result[1] = Number(res ? res[2] : NaN);
    result[2] = Number(res ? res[3] : NaN);
    result[3] = Number(!res || res[4] === undefined || res[4] === "" ? 1 : res[4]);

    function ok(a, max) {
        return !(isNaN(a) || a < 0 || a > max);
    }

    const passed = ok(result[0], mode === "rgba" ? 255 : 360)
        && ok(result[1], mode === "rgba" ? 255 : 100)
        && ok(result[2], mode === "rgba" ? 255 : 100)
        && ok(result[3], 1);
    if (!passed)
        return false;
    if (mode === "rgba") {
        return { r: result[0], g: result[1], b: result[2], a: result[3] };
    }
    return { h: result[0], s: result[1], v: result[2], a: result[3] };
}

// index.tsx:74-107，官方那个静态方法
function colorStringToValue(raw) {
    if (raw.startsWith("#")) {
        return { hsva: hexToHsva(raw), rgba: hexToRgba(raw), hex: raw };
    } else if (raw.startsWith("rgba")) {
        const rgba = rgbaStringToRgba(raw);
        return { hsva: rgbaStringToHsva(raw), rgba: rgba, hex: rgbaToHex(rgba) };
    } else if (raw.startsWith("rgb")) {
        const rgba = rgbaStringToRgba(raw);
        return { hsva: rgbaStringToHsva(raw), rgba: rgba, hex: rgbaToHex(rgba) };
    } else if (raw.startsWith("hsv")) {
        const hsva = hsvaStringToHsva(raw);
        return { hsva: hsva, rgba: hsvaToRgba(hsva), hex: hsvaToHex(hsva) };
    }
    throw new Error("Semi ColorPicker: error on static colorStringToValue method, input value is invalid: " + raw);
}

// DataPartFoundation.ts:37-50，输入框里显示的那一段
function inputValueOf(current, format) {
    if (format === "rgba")
        return current.rgba.r + "," + current.rgba.g + "," + current.rgba.b;
    if (format === "hsva")
        return current.hsva.h + "," + current.hsva.s + "," + current.hsva.v;
    return current.hex.slice(0, 7);
}

// DataPartFoundation.ts:52-75，解析手输的值；不合法返回 false
function valueFromInput(text, format) {
    if (format === "rgba") {
        const rgba = split(text, "rgba");
        if (rgba)
            return rgba;
    } else if (format === "hsva") {
        const hsva = split(text, "hsva");
        if (hsva)
            return hsva;
    } else if (format === "hex") {
        // 官方注释：绕 chrome 的 bug，输入框内容不带井号
        let value = text;
        if (!value.startsWith("#"))
            value = "#" + value;
        if (/#[\d\w]{6,8}/.test(value))
            return value;
    }
    return false;
}
