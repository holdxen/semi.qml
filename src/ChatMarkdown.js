.pragma library
// Chat 的 markdown 预处理小工具。
//
// escapeHtmlInMarkdown 移植自 semi-foundation/utils/escapeHtml.ts：
// md 模式下 mdx 会把裸 HTML 节点剥掉（rehypeRemoveRaw），用户输入的
// `<AgentChat />` 这类内容会凭空消失；所以在**围栏代码块与行内代码之外**
// 把 `<` 转成 `&lt;`，让解析器把它们当纯文本。
//
// splitFences 把一段 markdown 切成 text / code 段：Qt 的 Text.MarkdownText
// 会自己画围栏代码块，但画不出官方 Code 组件那条「语言 + 复制」顶栏
// （semi-ui/chat/chatBox/code.tsx），所以端口把围栏拆出来单独渲染。

function escapeHtmlInMarkdown(text) {
    const lines = String(text).split("\n");
    const result = [];
    let fenceChar = null;
    let fenceLen = 0;

    for (let i = 0; i < lines.length; ++i) {
        const line = lines[i];
        if (fenceChar !== null) {
            result.push(line);
            const trimmed = line.replace(/\s+$/, "");   // QML V4 无 trimEnd（ES2019）
            if (trimmed.length >= fenceLen && trimmed[0] === fenceChar
                && trimmed === fenceChar.repeat(trimmed.length)) {
                fenceChar = null;
            }
        } else {
            const fenceMatch = line.match(/^(`{3,}|~{3,})/);
            if (fenceMatch) {
                fenceChar = fenceMatch[1][0];
                fenceLen = fenceMatch[1].length;
                result.push(line);
            } else {
                result.push(escapeAngleBracketsOutsideInlineCode(line));
            }
        }
    }
    return result.join("\n");
}

function escapeAngleBracketsOutsideInlineCode(line) {
    const parts = [];
    let i = 0;

    while (i < line.length) {
        if (line[i] === "`") {
            let count = 0;
            const start = i;
            while (i < line.length && line[i] === "`") {
                count++;
                i++;
            }
            const closer = "`".repeat(count);
            const closeIdx = line.indexOf(closer, i);
            if (closeIdx !== -1) {
                parts.push(line.slice(start, closeIdx + count));
                i = closeIdx + count;
            } else {
                parts.push(line.slice(start, i).replace(/</g, "&lt;"));
            }
        } else if (line[i] === "<") {
            parts.push("&lt;");
            i++;
        } else {
            const next = line.indexOf("<", i);
            const nextBt = line.indexOf("`", i);
            let end;
            if (next === -1 && nextBt === -1) {
                end = line.length;
            } else if (next === -1) {
                end = nextBt;
            } else if (nextBt === -1) {
                end = next;
            } else {
                end = Math.min(next, nextBt);
            }
            parts.push(line.slice(i, end));
            i = end;
        }
    }
    return parts.join("");
}

// markdown → [{type:'text'|'code', body, lang}]；未闭合的围栏吞到结尾
// （与 CommonMark 一致）。text 段保留原样（含空行），交给 MarkdownText。
function splitFences(raw) {
    const lines = String(raw).split("\n");
    const out = [];
    let textBuf = [];
    let codeBuf = [];
    let inFence = false;
    let fenceChar = "";
    let fenceLen = 0;
    let lang = "";

    function flushText() {
        const body = textBuf.join("\n");
        if (body.trim() !== "")
            out.push({ type: "text", body: body, lang: "" });
        textBuf = [];
    }

    for (let i = 0; i < lines.length; ++i) {
        const line = lines[i];
        if (!inFence) {
            const m = line.match(/^(`{3,}|~{3,})/);
            if (m) {
                flushText();
                inFence = true;
                fenceChar = m[1][0];
                fenceLen = m[1].length;
                lang = line.slice(fenceLen).trim();
                codeBuf = [];
            } else {
                textBuf.push(line);
            }
        } else {
            const trimmed = line.replace(/\s+$/, "");   // QML V4 无 trimEnd（ES2019）
            if (trimmed.length >= fenceLen && trimmed[0] === fenceChar
                && trimmed === fenceChar.repeat(trimmed.length)) {
                inFence = false;
                out.push({ type: "code", body: codeBuf.join("\n"), lang: lang });
                codeBuf = [];
                lang = "";
            } else {
                codeBuf.push(line);
            }
        }
    }
    if (inFence)
        out.push({ type: "code", body: codeBuf.join("\n"), lang: lang });
    else
        flushText();
    return out;
}
