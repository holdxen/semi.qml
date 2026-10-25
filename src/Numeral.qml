import QtQuick

// 数值。在 Text 的基础上把文本里的数字挑出来按规则改写。
// 逻辑是 semi-foundation/typography/formatNumeral.ts 的直译，包括那个
// 「数字 / 非数字」切分正则和 truncate → precision 的先后顺序。
//
// 原文走 source（官方是 children），text 是格式化之后的结果 ——
// Qt 的 Text 没有 Label 那种 text / display 双槽，只能占掉 text。
//
//     Numeral { source: "点赞量：1611.1" }                       // rule: text
//     Numeral { source: "好评率: 0.915"; rule: "percentages"; precision: 2 }
//     Numeral { source: "已使用: 1000"; rule: "bytes-decimal"; precision: 2; truncate: "floor" }
//     Numeral { source: "Stars:7100"; parser: myParser }         // 传了 parser 就不走 rule
TypographyBase {
    id: control

    // text | numbers | percentages | bytes-decimal | bytes-binary | exponential
    property string rule: "text"
    property int precision: 0
    property string truncate: "round"        // ceil | floor | round
    property var parser: undefined
    property string source: ""

    text: control.formatNumeral(control.source)

    function formatNumeral(content) {
        if (typeof control.parser === "function")
            return String(control.parser(content));

        const parts = extractNumbers(content);
        if (control.rule === "text") {
            let s = "";
            for (const p of parts)
                s += isNumeral(p) ? truncatePrecision(p) : p;
            return s;
        }
        if (control.rule === "numbers") {
            const hits = [];
            for (const p of parts) {
                if (isNumeral(p))
                    hits.push(truncatePrecision(p));
            }
            return hits.join(",");
        }
        let s = "";
        for (const p of parts) {
            if (!isNumeral(p)) {
                s += p;
                continue;
            }
            s += applyRule(p);
        }
        return s;
    }

    function applyRule(value) {
        const v = Number(value);
        switch (control.rule) {
        case "percentages":
            // v2.30.0 起统一是 value * 100（formatNumeral.ts:44-47）
            return truncatePrecision(v * 100) + "%";
        case "bytes-decimal":
            return bytesUnit(v, 1000, ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]);
        case "bytes-binary":
            return bytesUnit(v, 1024, ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"]);
        case "exponential": {
            const t = v.toExponential(control.precision + 2).split("e");
            return truncatePrecision(Number(t[0])) + "e" + t[1];
        }
        default:
            return truncatePrecision(v);
        }
    }

    function bytesUnit(value, base, units) {
        let i = 0;
        let v = value;
        while (v >= base) {
            v /= base;
            i++;
        }
        return truncatePrecision(v) + " " + units[i];
    }

    function truncatePrecision(content) {
        const scale = Math.pow(10, control.precision);
        const shifted = Number(content) * scale;
        const cut = control.truncate === "ceil" ? Math.ceil(shifted)
            : control.truncate === "floor" ? Math.floor(shifted) : Math.round(shifted);
        const truncated = cut / scale;
        const arr = truncated.toString().split(".");
        // 整数要把末尾的 0 补齐
        if (arr.length === 1)
            return truncated.toFixed(control.precision);
        if (arr[1].length < control.precision) {
            let zeros = "";
            for (let i = 0; i < control.precision - arr[1].length; i++)
                zeros += "0";
            return arr[0] + "." + arr[1] + zeros;
        }
        return truncated.toString();
    }

    // /(-?[0-9]*\.?[0-9]+([eE]-?[0-9]+)?)|([^-\d\.]+)/g —— 把「数字串」和
    // 「非数字片段」交替切出来；单独的 `-` 不算数字（它是前缀）。
    function extractNumbers(content) {
        const re = /(-?[0-9]*\.?[0-9]+([eE]-?[0-9]+)?)|([^-\d.]+)/g;
        const m = String(content).match(re);
        return m === null ? [] : m;
    }

    function isNumeral(str) {
        return !(isNaN(Number(str)) || String(str).replace(/\s+/g, "") === "");
    }
}
