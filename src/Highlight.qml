import QtQuick

// 关键词高亮。把 `sourceString` 里命中 `searchWords` 的片段铺上底色与字重，其余文本沿用继承来的样式。
//
//     Highlight {
//         sourceString: "从 Semi Design 到 Any Design"
//         searchWords: ["Semi Design", { text: "Design", style: { backgroundColor: "#ffe0c2" } }]
//         highlightStyle: ({ color: "#0077fa" })
//     }
//
// ------------------------------------------------------------------ 官方 HighlightProps
// 逐条对着 packages/semi-ui/highlight/index.tsx:26-34 与 :52-57 的 defaultProps：
//   · `component` 缺省 **"mark"**、`autoEscape` **true**、`caseSensitive` **false**、
//     `sourceString` **''**；`searchWords` 没缺省（propTypes 写的是 arrayOf(string)，
//     但 foundation 从 v2.71 起也收 `{text, className, style}` 对象，:78-80 还允许整条给
//     一个字符串并归一成 `[str]`）。
//   · `highlightStyle` 是 CSSProperties ⇒ 端口只落地 Qt 行内富文本认的那几条：
//     `color` / `backgroundColor` / `fontWeight` / `fontStyle` / `textDecoration` /
//     `fontSize` / `fontFamily`。官方 demo 里的 `borderRadius` / `padding` / `marginLeft`
//     这类几何 **收了不生效**（Qt 的 span 不吃盒模型）。
//   · `highlightClassName` 与对象档的 `className` 不收（没有 CSS）；`component` 收了也不生效
//     —— 官方那条 `.semi-highlight-tag` 类是**恒加**在每个高亮标签上的（index.tsx:98-100），
//     换 `span` / `strong` 观感一模一样（UA 样式打不过作者样式），差的只是 DOM 语义。
//   · `style` / `className` 官方 propTypes 里声明了却**从不使用**（render 直接返回一个数组，
//     连外层元素都没有，index.tsx:110-112）⇒ 端口不提供这两条。
//
// ------------------------------------------------------------------ 算法（semi-foundation/highlight/foundation.ts）
// 端口逐条照抄那条四步流水线，而不是「把词拼成一个 big-alternation 正则」—— 两者在重叠时结果不同：
//   1. `findChunks`：**每个词各自扫一遍**源文本（`autoEscape` 时先转义正则元字符，
//      `caseSensitive` 决定 `g` / `gi`），命中就记一条 `{start, end, className, style}`；
//      `end > start` 才收，且 `match.index === regex.lastIndex` 时把 `lastIndex` 往前推一格
//      （:130-132，防 `autoEscape: false` 配零宽正则时死循环）。空词先被 `filter(sw => sw.text)` 丢掉。
//   2. `combineChunks`：按 `start` 排序后**一趟线性合并**，判据是 `next.start <= prev.end`
//      —— 注意是「小于等于」，**首尾相接的两段也会并成一段**；并完 `end` 取两者较大，
//      `className` 是 `prev || next`，`style` 是 `{...prev, ...next}`（后者逐键覆盖）。
//   3. `fillInChunks`：在高亮段之间补出非高亮段，`end - start > 0` 才收。
//   4. 渲染：高亮段套标签、非高亮段是裸文本；样式顺序是「类上的默认 → highlightStyle →
//      该段自己的 style」，后写的键盖掉前写的。
//
// 例（foundation.ts:43-68 注释里给的就是这两条）：
//   · `'aaa do dollar aaa'` + `['do', 'dollar']` ⇒ `'do'` 命中 (7,9)、`'dollar'` 命中 (7,13)，
//     相接 ⇒ 并成 (7,13)，整段 "dollar" 高亮，而不是只亮前两个字母。
//   · `'aaazaaazaaa'` + `['z']` ⇒ 三段式：非高亮 (0,3)、高亮 (3,4)、非高亮 (4,7)、高亮 (7,8)、非高亮 (8,11)。
//
// ------------------------------------------------------------------ 规格
// `.semi-highlight-tag`（highlight.scss:7-11 + variables.scss）：文字 `--semi-color-highlight`、
// 背景 `--semi-color-highlight-bg`、字重 600。浅色是黄底黑字（yellow-4），暗色是 yellow-2 + 白字。
Text {
    id: control

    // ---- 官方 HighlightProps（index.tsx:26-34，缺省 :52-57）----
    property string sourceString: ""
    property var searchWords: []
    property bool caseSensitive: false
    property bool autoEscape: true
    property var highlightStyle: undefined
    property string component: "mark"

    textFormat: Text.RichText
    text: control.compose()

    // 官方那条恒加的类：`.semi-highlight-tag { color; background-color; font-weight: 600 }`
    readonly property string tagCss: "color:" + Theme.current.colorHighlight
        + ";background-color:" + Theme.current.colorHighlightBg + ";font-weight:600;"

    // ---- 第 1 步：归一 + 逐词扫描 ----
    function wordList() {
        const out = [];
        let raw = control.searchWords;
        if (raw === undefined || raw === null)
            return out;
        // foundation.ts:78-80：整条给一个字符串也认
        if (typeof raw === "string")
            raw = [raw];
        if (raw.length === undefined)
            return out;
        for (let i = 0; i < raw.length; ++i) {
            const word = raw[i];
            if (word === undefined || word === null)
                continue;
            // :108 的归一：字符串当 {text}，对象取它自己那份；数字之流既不是字符串也没 text，
            // 会被下一行的 filter（`sw.text` 真值）丢掉 —— 端口不替它 String()
            const entry = typeof word === "string" ? { text: word } : word;
            if (!entry.text)
                continue;
            out.push(entry);
        }
        return out;
    }

    function findChunks(list) {
        const chunks = [];
        const source = control.sourceString === undefined ? "" : control.sourceString;
        for (let i = 0; i < list.length; ++i) {
            const entry = list[i];
            let text = String(entry.text);
            if (control.autoEscape)
                text = control.escapeRegExp(text);
            let regex;
            try {
                regex = new RegExp(text, control.caseSensitive ? "g" : "gi");
            } catch (error) {
                // autoEscape 为假时用户给的就是正则，写坏了就跳过这一个词
                continue;
            }
            let match = regex.exec(source);
            while (match !== null) {
                const start = match.index;
                const end = regex.lastIndex;
                if (end > start) {
                    chunks.push({ start: start, end: end, highlight: true,
                        className: entry.className, style: entry.style });
                }
                // 零宽匹配往前推一格，否则 while 出不来（:130-132）
                if (match.index === regex.lastIndex)
                    regex.lastIndex = regex.lastIndex + 1;
                match = regex.exec(source);
            }
        }
        return chunks;
    }

    // ---- 第 2 步：排序 + 一趟合并（相接也算重叠）----
    function combineChunks(chunks) {
        const sorted = chunks.slice(0);
        sorted.sort(function (first, second) { return first.start - second.start; });
        const out = [];
        for (let i = 0; i < sorted.length; ++i) {
            const next = sorted[i];
            if (out.length === 0) {
                out.push(next);
                continue;
            }
            const prev = out[out.length - 1];
            if (next.start <= prev.end) {
                out.pop();
                out.push({
                    highlight: true,
                    start: prev.start,
                    end: Math.max(prev.end, next.end),
                    className: prev.className === undefined || prev.className === null
                        ? next.className : prev.className,
                    style: control.mergeStyle(prev.style, next.style)
                });
            } else {
                out.push(next);
            }
        }
        return out;
    }

    // `{...prev, ...next}`：next 逐键盖掉 prev
    function mergeStyle(prev, next) {
        const out = {};
        const a = prev === undefined || prev === null ? ({}) : prev;
        const b = next === undefined || next === null ? ({}) : next;
        for (const key in a)
            out[key] = a[key];
        for (const key in b)
            out[key] = b[key];
        return out;
    }

    // ---- 第 3 步：补出非高亮段 ----
    function fillInChunks(toHighlight, totalLength) {
        const out = [];
        const append = function (start, end, highlight, className, style) {
            if (end - start > 0)
                out.push({ start: start, end: end, highlight: highlight,
                    className: className, style: style });
        };
        if (toHighlight.length === 0) {
            append(0, totalLength, false, undefined, undefined);
        } else {
            let lastIndex = 0;
            for (let i = 0; i < toHighlight.length; ++i) {
                const chunk = toHighlight[i];
                append(lastIndex, chunk.start, false, undefined, undefined);
                append(chunk.start, chunk.end, true, chunk.className, chunk.style);
                lastIndex = chunk.end;
            }
            append(lastIndex, totalLength, false, undefined, undefined);
        }
        return out;
    }

    // ---- 第 4 步：拼富文本 ----
    function compose() {
        const source = control.sourceString === undefined ? "" : control.sourceString;
        if (source === "")
            return "";
        const chunks = control.fillInChunks(
            control.combineChunks(control.findChunks(control.wordList())), source.length);
        let html = "";
        for (let i = 0; i < chunks.length; ++i) {
            const text = source.substr(chunks[i].start, chunks[i].end - chunks[i].start);
            if (!chunks[i].highlight) {
                html += control.escapeHtml(text);
                continue;
            }
            // 样式顺序 = 类上的默认 → highlightStyle → 这一段自己的 style，后写的键盖掉前面的
            html += "<span style=\"" + control.tagCss + control.cssOf(control.highlightStyle)
                + control.cssOf(chunks[i].style) + "\">" + control.escapeHtml(text) + "</span>";
        }
        return html;
    }

    // 官方那几条能落到 Qt 行内富文本上的样式；几何类（borderRadius / padding / margin）
    // Qt 的 span 不吃，收了也不生效
    function cssOf(style) {
        if (style === undefined || style === null)
            return "";
        const map = {
            color: "color",
            backgroundColor: "background-color",
            background: "background-color",
            fontWeight: "font-weight",
            fontStyle: "font-style",
            textDecoration: "text-decoration",
            fontSize: "font-size",
            fontFamily: "font-family"
        };
        let css = "";
        for (const key in map) {
            if (style[key] === undefined || style[key] === null)
                continue;
            css += map[key] + ":" + style[key] + ";";
        }
        return css;
    }

    function escapeHtml(value) {
        return String(value)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
    }

    // foundation.ts:30 那个字符集，逐字照抄（含 `/` 与 `-`）
    function escapeRegExp(value) {
        return String(value).replace(/[\-\[\]\/{}()*+?.\\^$|]/g, "\\$&");
    }
}
