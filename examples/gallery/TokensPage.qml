pragma ComponentBehavior: Bound

import QtQuick
import Semi
import "TokenColor.js" as TokenColor

// Tokens 设计变量页。结构与内容照官网那一页：
//   content/basic/tokens/index.md（245 行，13 个 H2 + 若干 H3）
//   src/components/FullPalette/index.jsx      色盘那一片色块（含 WCAG 徽标与点击复制）
//   src/components/DesignToken/index.tsx      「变量 / 默认值 / 用法」三列表 + Light/Dark 页签
//   src/components/ColorConverter/index.jsx   「颜色转换」
//   src/components/JumpToToken/index.tsx      点 var 引用 → 滚过去 + 闪黄底
//
// 三条口径上的差异，逐条记在 docs/PROGRESS.md：
//   · 复制出去的是 **`Theme.current.xxx`**（端口里官网 `var(--semi-blue-5)` 的对应物），
//     不是色值 —— 这是用户点名要的。
//   · 顶部那个搜索框是端口自加的（官网那页没有，只有右侧页内锚点）。
//   · 「常量色 - static」官方那条正则 `/((--semi-black)|(--semi-white))$/` 在它的
//     数据源里一条都匹配不到（那两个键在 palette 里，而表格只搜 global + normal）⇒
//     官方那一节是空表。端口把 palette 也纳入这一节的搜索，按这一节的本意出两行。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ---- 对外（GalleryShell 的 --search 与页内锚点会读） ----
    property string keyword: ""

    // ---- 跳转高亮：官网是「点了 var 引用 ⇒ 滚过去 + 黄底留到下一次点击」 ----
    property string flashKey: ""

    property var shell: null

    function findShell() {
        let node = page.parent;
        while (node !== null && node !== undefined) {
            // qmllint disable missing-property
            if (node.tokens !== undefined && node.currentDir !== undefined)
                return node;
            // qmllint enable missing-property
            node = node.parent;
        }
        return null;
    }

    Component.onCompleted: page.shell = page.findShell()

    readonly property var tokens: page.shell !== null ? page.shell.tokens : null
    readonly property var g: page.tokens === null ? null : page.tokens.global

    // ---------------------------------------------------------------- 文案
    //
    // H2 小节的说明由 GallerySection 自己从 docs.json 取；H3 这一层不是 GallerySection，
    // 文字从这里取。两份都来自 content/basic/tokens/index.md（parse-docs.py 的 prose）。
    function proseText(title) {
        if (page.shell === null || page.shell.currentComponent === null)
            return "";
        const prose = page.shell.currentComponent.prose;
        if (prose === undefined || prose === null)
            return "";
        for (let i = 0; i < prose.length; ++i)
            if (prose[i].title === title)
                return prose[i].description;
        return "";
    }

    // ---------------------------------------------------------------- 过滤
    function hit(text) {
        if (page.keyword === "")
            return true;
        if (text === undefined || text === null)
            return false;
        return String(text).toLowerCase().indexOf(page.keyword.toLowerCase()) >= 0;
    }

    function tokenHit(t) {
        return page.hit(t.key) || page.hit(t.value) || page.hit(t.comment);
    }

    // ---------------------------------------------------------------- 取数
    //
    // 官网每条 `<DesignToken componentName='global' reg={/color-primary/}/>` 的取数口径：
    // global[当前档] 过一遍正则 + normal（不分明暗那批 $ 变量）过一遍正则，两份拼起来。
    // scope 为 "palette" 时再叠上色板那一档（只有「常量色」用得到，见文件头那条差异）。
    function globalRows(pattern, mode, scope) {
        const out = [];
        if (page.g === null || pattern === "")
            return out;
        const re = new RegExp(pattern);
        const lists = [mode === "dark" ? page.g.global.dark : page.g.global.light];
        if (scope === "palette")
            lists.push(mode === "dark" ? page.g.palette.dark : page.g.palette.light);
        for (let l = 0; l < lists.length; ++l) {
            const list = lists[l];
            for (let i = 0; i < list.length; ++i)
                if (re.test(list[i].key) && page.tokenHit(list[i]))
                    out.push(list[i]);
        }
        return out;
    }

    function normalRows(pattern) {
        const out = [];
        if (page.g === null || pattern === "")
            return out;
        const re = new RegExp(pattern);
        const list = page.g.normal;
        for (let i = 0; i < list.length; ++i)
            if (re.test(list[i].key) && page.tokenHit(list[i]))
                out.push(list[i]);
        return out;
    }

    function rowsFor(pattern, mode, scope) {
        return page.globalRows(pattern, mode, scope).concat(page.normalRows(pattern));
    }

    // 官网 GlobalTokenTab:144 那道 hasTab 的闸：只有 global 那一档真有条目才挂 Light/Dark 页签
    function tabbedFor(pattern, scope) {
        return page.globalRows(pattern, "light", scope).length > 0;
    }

    // 点「默认值」里的 var 引用：记下键名，让对应那一行闪起来并滚进视口
    function jumpTo(key) {
        page.flashKey = key;
    }

    // ---- 命中数与「整节有没有内容」 ----
    // 都写在 page 这一层：挂在 Column 里面就成了 Column 的属性，页面上 page.matchCount 读回 undefined
    readonly property int matchCount: {
        let n = 0;
        const cols = page.paletteColumns("light");
        for (let i = 0; i < cols.length; ++i)
            n += cols[i].blocks.length;
        const groups = [page.semanticSections, page.fontSections, page.sizeSections];
        for (let gi = 0; gi < groups.length; ++gi) {
            const list = groups[gi];
            for (let i = 0; i < list.length; ++i)
                n += page.rowsFor(list[i].pattern, "light", list[i].scope).length;
        }
        const singles = ["border-radius", "--semi-shadow", "(spacing-)|(width-base)|(loose)", "z-"];
        for (let i = 0; i < singles.length; ++i)
            n += page.rowsFor(singles[i], "light", "").length;
        const tabs = page.animationTabs;
        for (let i = 0; i < tabs.length; ++i)
            n += tabs[i].items.length;
        return n;
    }

    // 一组小节里只要有一条就值得把父节留着（父节自己没内容，全指望子节）
    function anyRows(list) {
        for (let i = 0; i < list.length; ++i)
            if (page.rowsFor(list[i].pattern, "light", list[i].scope).length > 0)
                return true;
        return false;
    }

    // ---------------------------------------------------------------- 复制
    //
    // 借一条隐藏的 TextEdit 做「全选 + 复制」（QML 没有直接的剪贴板 API）。
    function copy(text) {
        clipboard.text = text;
        clipboard.selectAll();
        clipboard.copy();
        // 官网 Toast 文案：颜色 <code>{text}</code> 已复制（FullPalette/index.jsx:72-80）
        copyToast.success(qsTr("颜色 %1 已复制").arg(text));
    }

    // ---------------------------------------------------------------- 色盘
    //
    // 列顺序与列名照 FullPalette/index.jsx:25-44 那份 colors 数组（不是字典序）。
    readonly property var paletteDefs: [
        { name: "red", re: "^red-(\\d)$" },
        { name: "pink", re: "^pink-(\\d)$" },
        { name: "purple", re: "^purple-(\\d)$" },
        { name: "violet", re: "^violet-(\\d)$" },
        { name: "indigo", re: "^indigo-(\\d)$" },
        { name: "blue", re: "^blue-(\\d)$" },
        { name: "light blue", re: "^light-blue-(\\d)$" },
        { name: "cyan", re: "^cyan-(\\d)$" },
        { name: "teal", re: "^teal-(\\d)$" },
        { name: "green", re: "^green-(\\d)$" },
        { name: "light green", re: "^light-green-(\\d)$" },
        { name: "lime", re: "^lime-(\\d)$" },
        { name: "yellow", re: "^yellow-(\\d)$" },
        { name: "amber", re: "^amber-(\\d)$" },
        { name: "orange", re: "^orange-(\\d)$" },
        { name: "grey", re: "^grey-(\\d)$" },
        { name: "ai purple", re: "^ai-purple-(\\d)$" },
        // 只收那 10 条渐变本体。官方还会把 40 个色标（--semi-ai-general-0-3 那一族）
        // 也当色块画出来，而它给这些块写的 background 是一段 `239,247,255` ⇒ 无效 CSS、
        // 画出来是空的棋盘。上游的毛病，端口只登记不抄。
        { name: "ai general", re: "^ai-general-(\\d)$" }
    ]

    // FullPalette 里那个 toUpper：首字母大写，`Ai ` 开头改回 `AI `
    function prettyName(text) {
        const words = String(text).toLowerCase().split(" ");
        let out = "";
        for (let i = 0; i < words.length; ++i) {
            const w = words[i];
            if (w === "")
                continue;
            out += (out === "" ? "" : " ") + w.charAt(0).toUpperCase() + w.substring(1);
        }
        if (out.indexOf("Ai ") === 0)
            return "AI" + out.substring(2);
        return out;
    }

    function bareKey(key) {
        return String(key).replace("--semi-", "");
    }

    function paletteColumns(mode) {
        const src = page.g === null ? [] : (mode === "dark" ? page.g.palette.dark : page.g.palette.light);
        const out = [];
        for (let d = 0; d < page.paletteDefs.length; ++d) {
            const def = page.paletteDefs[d];
            const re = new RegExp(def.re);
            const blocks = [];
            for (let i = 0; i < src.length; ++i) {
                const t = src[i];
                const m = re.exec(page.bareKey(t.key));
                if (m === null)
                    continue;
                if (!page.hit(def.name) && !page.hit(t.key) && !page.hit(t.value))
                    continue;
                blocks.push(page.makeBlock(t, def.name + " " + m[1], mode === "dark", t.key.indexOf("ai-general") === 0));
            }
            if (blocks.length > 0)
                out.push({ name: def.name, blocks: blocks });
        }
        return out;
    }

    // 一块色板格子 → TokenColorBlock 要吃的那几个值
    function makeBlock(t, displayName, dark, isAiGeneral) {
        const swatch = t.color === undefined || t.color === null ? "" : String(t.color);
        const b = {
            key: t.key,
            name: page.prettyName(displayName),
            value: t.value,
            swatch: swatch,
            isGradient: isAiGeneral,
            copyText: t.accessor === undefined || t.accessor === null
                ? "" : "Theme.current." + t.accessor
        };
        if (isAiGeneral) {
            // 官方：ai general 那档不算对比度（wscore/bscore 直接给 'fail' ⇒ 两枚徽标都不画），
            // 标题字色按「第几档 + 当前明暗」翻黑白（getColorCapClassNameForAIGeneral）
            b.whiteScore = "";
            b.blackScore = "";
            const number = Number(displayName.substring(displayName.lastIndexOf(" ") + 1));
            b.captionWhite = dark ? number < 5 : number >= 5;
        } else {
            const c = TokenColor.parseColor(swatch);
            const wrate = c === null ? 0 : TokenColor.contrast(c, { r: 255, g: 255, b: 255, a: 1 });
            const brate = c === null ? 0 : TokenColor.contrast(c, { r: 0, g: 0, b: 0, a: 1 });
            const wscore = TokenColor.scoreFromRatio(wrate);
            const bscore = TokenColor.scoreFromRatio(brate);
            // 官方把 Fail 的那一档留空；标题色按「压不压得住白字」
            b.whiteScore = wscore === "Fail" ? "" : wscore;
            b.blackScore = bscore === "Fail" ? "" : bscore;
            b.captionWhite = wscore !== "Fail";
        }
        return b;
    }

    // ---------------------------------------------------------------- 颜色转换
    //
    // 官网 ColorConverter：输入一个颜色，把 cssVars（语义色）与 palette（色板）
    // 两批都按 Lab 距离排一遍，**只留与最小距离相等的那些**。
    readonly property var converterEntries: {
        const out = [];
        if (page.g === null)
            return out;
        const lists = [page.g.global.light, page.g.palette.light];
        for (let l = 0; l < lists.length; ++l) {
            const list = lists[l];
            for (let i = 0; i < list.length; ++i) {
                const t = list[i];
                if (t.color === undefined || t.color === null)
                    continue;
                out.push({ token: t, value: t.color, gradient: String(t.value).indexOf("linear-gradient") === 0 });
            }
        }
        return out;
    }

    property string converterInput: ""
    property var converterResults: []

    function runConverter() {
        const input = TokenColor.parseColor(page.converterInput);
        if (page.converterInput.trim() === "") {
            page.converterResults = [];
            return;
        }
        if (input === null)
            return;                 // 官网：无效输入时不清空、也不换算
        const hits = TokenColor.closestTokens(input, page.converterEntries);
        const out = [];
        for (let i = 0; i < hits.length; ++i) {
            const e = page.converterEntries[hits[i]];
            out.push(page.makeBlock(e.token, page.bareKey(e.token.key), false,
                String(e.token.key).indexOf("--semi-ai-general-") === 0));
        }
        page.converterResults = out;
    }

    // ---------------------------------------------------------------- 动画分档
    //
    // 官网 GlobalAnimationToken:172-179：按 `--semi-transition_(x)-` 的名字开页签，
    // 匹配不上的（transform_scale-* / transform-rotate-*）落进 "other"。
    // 过滤到空的那一档要整页签收掉（否则搜一个不存在的词，动画那节还挂着六个空页签）。
    readonly property var animationTabs: {
        const buckets = [];
        if (page.g === null)
            return buckets;
        const list = page.g.animation;
        const re = /--semi-transition_([\w\W]+)-/;
        for (let i = 0; i < list.length; ++i) {
            const t = list[i];
            if (!page.tokenHit(t))
                continue;
            const m = re.exec(t.key);
            const tab = m === null ? "other" : m[1];
            let bucket = null;
            for (let b = 0; b < buckets.length; ++b)
                if (buckets[b].name === tab)
                    bucket = buckets[b];
            if (bucket === null) {
                bucket = { name: tab, items: [] };
                buckets.push(bucket);
            }
            bucket.items.push(t);
        }
        return buckets;
    }

    // ---------------------------------------------------------------- 小节清单
    //
    // 标题与正则逐条抄 content/basic/tokens/index.md（含官方那条空着的「AI 状态色」）。
    readonly property var semanticSections: [
        { title: "主要颜色 - primary", pattern: "color-primary" },
        { title: "次要颜色 - secondary", pattern: "color-secondary" },
        { title: "第三颜色 - tertiary", pattern: "color-tertiary" },
        { title: "信息 - info", pattern: "color-info" },
        { title: "成功 - success", pattern: "color-success" },
        { title: "警示 - warning", pattern: "color-warning" },
        { title: "危险 - danger", pattern: "color-danger" },
        { title: "AI - general", pattern: "color-ai-general" },
        { title: "AI - purple", pattern: "color-ai-purple" },
        { title: "AI - background", pattern: "color-ai-background" },
        { title: "文本与图标颜色 - text", pattern: "color-text" },
        { title: "链接色 - link", pattern: "color-link" },
        { title: "背景色 - bg", pattern: "color-bg" },
        { title: "填充色 - fill", pattern: "color-fill" },
        { title: "描边色 - border", pattern: "color-border" },
        { title: "AI 状态色", pattern: "" },
        { title: "禁用态 - disabled", pattern: "color-disabled" },
        { title: "常量色 - static", pattern: "((--semi-black)|(--semi-white))$", scope: "palette" },
        { title: "拟阴影色 - shadow", pattern: "^--semi-color-shadow$" }
    ]

    readonly property var fontSections: [
        { title: "字号", pattern: "font-size" },
        { title: "字重", pattern: "font-weight" },
        { title: "字体", pattern: "font-family" }
    ]

    readonly property var sizeSections: [
        { title: "高度", pattern: "height-control" },
        { title: "描边尺寸", pattern: "\\$border-thickness" },
        { title: "图标尺寸", pattern: "\\$width-icon" }
    ]

    // ================================================================ 页面
    Column {
        id: column

        width: parent.width
        spacing: 44

        // ---- 搜索（端口自加，官网没有） ----
        Row {
            spacing: 12

            Input {
                id: searchInput

                width: 360
                size: Enums.Default
                prefixIcon: "search"
                showClear: true
                placeholderText: qsTr("搜索令牌名 / 说明 / 值")
                onTextChanged: page.keyword = text
            }

            // keyword 也可能是外面设进来的（main.cpp 的 --search），
            // 那种情况下输入框要跟上；两边值相同时不动作，免得绕成环
            Connections {
                target: page

                function onKeywordChanged() {
                    if (searchInput.text !== page.keyword)
                        searchInput.text = page.keyword;
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: page.keyword !== ""
                text: qsTr("命中 %1 项").arg(page.matchCount)
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
            }
        }

        // ---- 为什么要使用 Design Token ----
        GallerySection {
            title: "为什么要使用 Design Token"
        }

        // ---- 基础色 ----
        GallerySection {
            title: "基础色"
            visible: page.paletteColumns("light").length > 0

            Tabs {
                width: parent.width
                type: "line"

                TabPane {
                    itemKey: "light"
                    tab: "Light"
                    icon: "sun"

                    PaletteGrid {
                        mode: "light"
                    }
                }

                TabPane {
                    itemKey: "dark"
                    tab: "Dark"
                    icon: "moon"

                    PaletteGrid {
                        mode: "dark"
                    }
                }
            }

            // 官网上「颜色转换」是「基础色」底下的一个 H3
            SubHead {
                title: "颜色转换"
            }

            Text {
                width: 620
                visible: page.proseText("颜色转换") !== ""
                text: page.proseText("颜色转换")
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeRegular
                wrapMode: Text.WordWrap
            }

            Input {
                id: converterInput

                width: 300
                prefixIcon: "search"
                placeholderText: qsTr("输入颜色值")
                onTextChanged: {
                    page.converterInput = text;
                    page.runConverter();
                }
            }

            Flow {
                width: parent.width
                topPadding: 16
                spacing: 16

                Repeater {
                    model: page.converterResults

                    delegate: TokenColorBlock {
                        required property var modelData

                        bordered: true
                        name: modelData.name
                        value: modelData.value
                        swatch: modelData.swatch
                        isGradient: modelData.isGradient
                        copyText: modelData.copyText
                        captionColor: modelData.captionWhite ? "#ffffff" : "#000000"
                        whiteScore: modelData.whiteScore
                        blackScore: modelData.blackScore

                        onCopied: (text) => page.copy(text)
                    }
                }
            }
        }

        // ---- 功能色 ----
        GallerySection {
            title: "功能色"
            visible: page.anyRows(page.semanticSections)

            Repeater {
                model: page.semanticSections

                delegate: Column {
                    id: semanticSection

                    required property var modelData

                    width: parent.width
                    spacing: 12
                    visible: semanticSection.hasRows

                    readonly property bool hasRows: semanticSection.modelData.pattern === ""
                        ? false : page.rowsFor(semanticSection.modelData.pattern, "light",
                                              semanticSection.modelData.scope).length > 0

                    SubHead {
                        title: semanticSection.modelData.title
                    }

                    Text {
                        width: 700
                        visible: semanticSection.modelData.title !== "AI 状态色"
                        text: page.proseText(semanticSection.modelData.title)
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                        wrapMode: Text.WordWrap
                    }

                    ModeTables {
                        width: parent.width
                        pattern: semanticSection.modelData.pattern
                        scope: semanticSection.modelData.scope === undefined ? "" : semanticSection.modelData.scope
                    }
                }
            }
        }

        // ---- 字体排版 ----
        GallerySection {
            title: "字体排版"
            visible: page.anyRows(page.fontSections)

            Repeater {
                model: page.fontSections

                delegate: Column {
                    id: fontSection

                    required property var modelData

                    width: parent.width
                    spacing: 12
                    visible: page.rowsFor(fontSection.modelData.pattern, "light", "").length > 0

                    SubHead {
                        title: fontSection.modelData.title
                    }

                    Text {
                        width: 700
                        text: page.proseText(fontSection.modelData.title)
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                        wrapMode: Text.WordWrap
                    }

                    // 官网这一节底下贴了一段 @font-face 的 CSS。gallery 没有代码块组件
                    // （那条决定记在 docs/gallery-progress.md 的待办里），先把两行说明排出来。
                    Text {
                        visible: fontSection.modelData.title === "字体"
                        width: 700
                        text: qsTr("官网在这里给了一段 @font-face 声明（Inter Regular / Inter Bold 两个 ttf，"
                            + "由业务自己引入），gallery 暂未做代码块组件，故只登记不展示。")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }

                    ModeTables {
                        width: parent.width
                        pattern: fontSection.modelData.pattern
                    }
                }
            }
        }

        // ---- 圆角 ----
        GallerySection {
            title: "圆角"
            visible: page.rowsFor("border-radius", "light", "").length > 0

            ModeTables {
                width: parent.width
                pattern: "border-radius"
            }
        }

        // ---- 阴影 ----
        GallerySection {
            title: "阴影"
            visible: page.rowsFor("--semi-shadow", "light", "").length > 0

            ModeTables {
                width: parent.width
                pattern: "--semi-shadow"
            }
        }

        // ---- 尺寸 ----
        GallerySection {
            title: "尺寸"
            visible: page.anyRows(page.sizeSections)

            Repeater {
                model: page.sizeSections

                delegate: Column {
                    id: sizeSection

                    required property var modelData

                    width: parent.width
                    spacing: 12
                    visible: page.rowsFor(sizeSection.modelData.pattern, "light", "").length > 0

                    SubHead {
                        title: sizeSection.modelData.title
                    }

                    ModeTables {
                        width: parent.width
                        pattern: sizeSection.modelData.pattern
                    }
                }
            }
        }

        // ---- 间距 ----
        GallerySection {
            title: "间距"
            visible: page.rowsFor("(spacing-)|(width-base)|(loose)", "light", "").length > 0

            ModeTables {
                width: parent.width
                pattern: "(spacing-)|(width-base)|(loose)"
            }
        }

        // ---- z-index ----
        GallerySection {
            title: "z-index"
            visible: page.rowsFor("z-", "light", "").length > 0

            ModeTables {
                width: parent.width
                pattern: "z-"
            }
        }

        // ---- 动画 ----
        GallerySection {
            title: "动画"
            visible: page.animationTabs.length > 0

            Tabs {
                width: parent.width
                type: "line"

                Repeater {
                    model: page.animationTabs

                    TabPane {
                        id: animPane

                        required property var modelData

                        itemKey: animPane.modelData.name
                        tab: animPane.modelData.name

                        TokenTable {
                            rows: animPane.modelData.items

                            onCopied: (text) => page.copy(text)
                            onJumped: (key) => page.jumpTo(key)
                            onFlashed: (item, key) => page.scrollInto(item)
                        }
                    }
                }
            }
        }

        // ---- 尚未支持的变量 ----
        GallerySection {
            title: "尚未支持的变量"
        }

        // ---- 定制 ----
        GallerySection {
            title: "定制"

            Text {
                width: 700
                text: qsTr("官网这一节是一个指向 Semi DSM 的外链（https://semi.design/dsm）。")
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeRegular
                wrapMode: Text.WordWrap
            }
        }

        // 过滤到空时给个说法，光看空白会以为坏了
        Text {
            visible: page.keyword !== "" && page.matchCount === 0
            text: qsTr("没有匹配的令牌")
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    // ---------------------------------------------------------------- 滚动
    function scrollInto(item) {
        if (page.shell === null || item === null || item === undefined)
            return;
        // qmllint disable missing-property
        if (page.shell.scrollItemIntoView !== undefined)
            page.shell.scrollItemIntoView(item);
        // qmllint enable missing-property
    }

    // 黄底留到「下一次点击」才撤（JumpToToken 是挂 click / touchend 摘掉的）。
    // 挂在页面根上的 TapHandler 不跟子项抢：同一次点击父子两级都会发 tapped，
    // 所以色块与表格行的复制照旧走得到（见 PROGRESS 里父子 TapHandler 那条）。
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: page.flashKey = ""
    }

    // 剪贴板载体：不可见、零尺寸，不参与布局
    TextEdit {
        id: clipboard

        width: 0
        height: 0
        visible: false
    }

    Toast {
        id: copyToast

        duration: 3         // 官网 Toast.success 的 duration: 3（单位秒）
    }

    // ================================================================ 内联组件
    component SubHead: Text {
        id: subHead

        property string title: ""

        topPadding: 8
        text: subHead.title
        color: Theme.current.colorText0
        font.pixelSize: Theme.current.fontSizeHeader6
        font.weight: Font.DemiBold
    }

    // 一组令牌表：有明暗两套值就挂 Light / Dark 页签，否则单表（官网 hasTab 那条例）
    component ModeTables: Item {
        id: modeTables

        property string pattern: ""
        property string scope: ""

        implicitWidth: width
        implicitHeight: body.height

        width: parent ? parent.width : 0

        Item {
            id: body

            width: parent.width
            height: modeTables.tabbed ? modeTables.tabsHeight : singleTable.implicitHeight

            Tabs {
                id: tabsBlock

                width: parent.width
                type: "line"
                visible: modeTables.tabbed

                TabPane {
                    itemKey: "light"
                    tab: "Light"

                    TokenTable {
                        id: lightTable

                        rows: page.rowsFor(modeTables.pattern, "light", modeTables.scope)
                        flashKey: page.flashKey

                        onCopied: (text) => page.copy(text)
                        onJumped: (key) => page.jumpTo(key)
                        onFlashed: (item, key) => page.scrollInto(item)
                    }
                }

                TabPane {
                    itemKey: "dark"
                    tab: "Dark"

                    TokenTable {
                        id: darkTable

                        rows: page.rowsFor(modeTables.pattern, "dark", modeTables.scope)
                        flashKey: page.flashKey

                        onCopied: (text) => page.copy(text)
                        onJumped: (key) => page.jumpTo(key)
                        onFlashed: (item, key) => page.scrollInto(item)
                    }
                }
            }

            TokenTable {
                id: singleTable

                width: parent.width
                visible: !modeTables.tabbed
                rows: page.rowsFor(modeTables.pattern, "light", modeTables.scope)
                flashKey: page.flashKey

                onCopied: (text) => page.copy(text)
                onJumped: (key) => page.jumpTo(key)
                onFlashed: (item, key) => page.scrollInto(item)
            }
        }

        readonly property bool tabbed: page.tabbedFor(modeTables.pattern, modeTables.scope)
        readonly property real tabsHeight: tabsBlock.implicitHeight
    }

    // 色盘那一片：一列一个色相，列与列横着排、放不下换行（.color-grid 是 flex-wrap）
    component PaletteGrid: Flow {
        id: grid

        property string mode: "light"

        width: parent.width
        spacing: 16

        Repeater {
            model: page.paletteColumns(grid.mode)

            delegate: Column {
                id: hueColumn

                required property var modelData

                topPadding: 16
                bottomPadding: 16
                spacing: 0

                Repeater {
                    model: hueColumn.modelData.blocks

                    delegate: TokenColorBlock {
                        required property var modelData

                        name: modelData.name
                        value: modelData.value
                        swatch: modelData.swatch
                        isGradient: modelData.isGradient
                        copyText: modelData.copyText
                        captionColor: modelData.captionWhite ? "#ffffff" : "#000000"
                        whiteScore: modelData.whiteScore
                        blackScore: modelData.blackScore

                        onCopied: (text) => page.copy(text)
                    }
                }
            }
        }
    }
}
