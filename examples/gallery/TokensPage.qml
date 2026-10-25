pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Tokens 页。数据由 gen-tokens.py 从 semi-theme-default 的 scss 解析而来。
//
// 顶部有一个过滤框：命中「令牌名 / 说明 / 值」任一项就留下。过滤是按组做的 ——
// 组名命中就留整组，否则只留组内命中的那几个，整组空了就连小节一起收掉。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 过滤关键字（空 = 不过滤）
    property string keyword: ""

    function shellRoot() {
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

    readonly property var tokens: {
        const shell = page.shellRoot();
        return shell !== null ? shell.tokens : null;
    }

    function isDark() {
        return Theme.mode === Theme.Dark;
    }

    // 命中判定：任一字段包含关键字即算命中（不区分大小写）
    function hit(a, b, c, d, e) {
        const needle = page.keyword.toLowerCase();
        if (needle === "")
            return true;
        const fields = [a, b, c, d, e];
        for (let i = 0; i < fields.length; ++i) {
            const f = fields[i];
            if (f !== undefined && f !== null
                    && String(f).toLowerCase().indexOf(needle) >= 0)
                return true;
        }
        return false;
    }

    // 复制色值到系统剪贴板。QML 没有直接的剪贴板 API，
    // 借一个隐藏的 TextEdit 做「全选 + 复制」。
    function copyColor(value, label) {
        clipboard.text = value;
        clipboard.selectAll();
        clipboard.copy();
        copyToast.success(label === ""
            ? qsTr("已复制 %1").arg(value)
            : qsTr("已复制 %1 · %2").arg(label).arg(value));
    }

    // ---- 过滤后的各段数据 ----
    // 注意：binding 里必须直接读到 page.keyword，否则只读绑定不会随它重算

    readonly property var paletteGroups: {
        const kw = page.keyword;
        const src = page.tokens !== null ? page.tokens.palette.groups : [];
        const out = [];
        for (let i = 0; i < src.length; ++i)
            if (page.hit(src[i].hue))
                out.push(src[i]);
        return out;
    }

    readonly property var gradientRows: {
        const kw = page.keyword;
        const src = page.tokens !== null ? page.tokens.palette.gradients : [];
        const out = [];
        for (let i = 0; i < src.length; ++i)
            if (page.hit(src[i].name))
                out.push(src[i]);
        return out;
    }

    readonly property var semanticGroups: {
        const kw = page.keyword;
        const src = page.tokens !== null ? page.tokens.semantic.groups : [];
        const out = [];
        for (let i = 0; i < src.length; ++i) {
            const group = src[i];
            const groupHit = page.hit(group.name, group.key);
            const tokens = [];
            for (let j = 0; j < group.tokens.length; ++j) {
                const token = group.tokens[j];
                if (groupHit || page.hit(token.name, token.desc, token.light, token.dark))
                    tokens.push(token);
            }
            if (tokens.length > 0)
                out.push({ key: group.key, name: group.name, tokens: tokens });
        }
        return out;
    }

    readonly property var sizingGroups: {
        const kw = page.keyword;
        const src = page.tokenRows();
        const out = [];
        for (let i = 0; i < src.length; ++i) {
            const group = src[i];
            const groupHit = page.hit(group.name);
            const items = [];
            for (let j = 0; j < group.items.length; ++j) {
                const item = group.items[j];
                if (groupHit || page.hit(item.name, item.desc, item.value, item.dark))
                    items.push(item);
            }
            if (items.length > 0)
                out.push({ name: group.name, items: items });
        }
        return out;
    }

    readonly property var motionRows: {
        const kw = page.keyword;
        const src = page.tokens !== null ? page.tokens.motion : [];
        const out = [];
        for (let i = 0; i < src.length; ++i)
            if (page.hit(src[i].name, src[i].value, src[i].desc))
                out.push(src[i]);
        return out;
    }

    readonly property int matchCount: {
        let n = page.paletteGroups.length + page.gradientRows.length + page.motionRows.length;
        for (let i = 0; i < page.semanticGroups.length; ++i)
            n += page.semanticGroups[i].tokens.length;
        for (let i = 0; i < page.sizingGroups.length; ++i)
            n += page.sizingGroups[i].items.length;
        return n;
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        // ---- 过滤 ----
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

        // ---- 基础色 ----
        GallerySection {
            title: "基础色"
            visible: page.paletteGroups.length > 0

            Text {
                width: parent.width
                topPadding: 4
                text: qsTr("基于品牌色生成的色盘，每行一个色相、从 0 到 9 共十级。"
                    + "点色块可以把当前明暗下的色值复制到剪贴板。")
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeRegular
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                topPadding: 20
                spacing: 14

                Repeater {
                    model: page.paletteGroups

                    delegate: Row {
                        id: hueRow

                        required property var modelData

                        spacing: 12

                        Text {
                            width: 92
                            anchors.verticalCenter: parent.verticalCenter
                            text: hueRow.modelData.hue
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                            elide: Text.ElideRight
                        }

                        Repeater {
                            model: hueRow.modelData.steps

                            delegate: Rectangle {
                                id: swatch

                                required property var modelData

                                width: 54
                                height: 54
                                radius: Theme.current.radiusSmall
                                border.width: 1
                                border.color: Theme.current.colorBorder
                                color: page.isDark() ? swatch.modelData.dark : swatch.modelData.light

                                Text {
                                    anchors.centerIn: parent
                                    text: swatch.modelData.index
                                    color: Theme.current.colorText2
                                    font.pixelSize: Theme.current.fontSizeSmall
                                }

                                TapHandler {
                                    onTapped: page.copyColor(
                                        page.isDark() ? swatch.modelData.dark : swatch.modelData.light,
                                        swatch.modelData.hue + "-" + swatch.modelData.index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- AI 渐变色 ----
        GallerySection {
            title: "AI 渐变色"
            visible: page.gradientRows.length > 0

            Column {
                width: parent.width
                spacing: 10

                Repeater {
                    model: page.gradientRows

                    delegate: Row {
                        id: gradientRow

                        required property var modelData

                        spacing: 12

                        Text {
                            width: 92
                            anchors.verticalCenter: parent.verticalCenter
                            text: gradientRow.modelData.name
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: 320
                            height: 32
                            radius: Theme.current.radiusSmall
                            border.width: 1
                            border.color: Theme.current.colorBorder
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: page.gradientStop(gradientRow.modelData, 0)
                                }
                                GradientStop {
                                    position: 0.33
                                    color: page.gradientStop(gradientRow.modelData, 1)
                                }
                                GradientStop {
                                    position: 0.66
                                    color: page.gradientStop(gradientRow.modelData, 2)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: page.gradientStop(gradientRow.modelData, 3)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- 功能色 ----
        GallerySection {
            title: "功能色"
            visible: page.semanticGroups.length > 0

            Text {
                width: 560
                text: qsTr("这些色块用起来和上面的色板一样：点一下就把当前明暗下的色值复制走。")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                spacing: 28

                Repeater {
                    model: page.semanticGroups

                    delegate: Column {
                        id: group

                        required property var modelData

                        width: parent.width
                        spacing: 12

                        Text {
                            text: group.modelData.name
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                            font.weight: Font.DemiBold
                        }

                        Flow {
                            width: parent.width
                            spacing: 10

                            Repeater {
                                model: group.modelData.tokens

                                delegate: Column {
                                    id: tokenCell

                                    required property var modelData

                                    spacing: 6

                                    Rectangle {
                                        width: 148
                                        height: 52
                                        radius: Theme.current.radiusSmall
                                        border.width: 1
                                        border.color: Theme.current.colorBorder
                                        color: page.isDark()
                                            ? tokenCell.modelData.dark : tokenCell.modelData.light

                                        TapHandler {
                                            onTapped: page.copyColor(
                                                page.isDark()
                                                    ? tokenCell.modelData.dark : tokenCell.modelData.light,
                                                tokenCell.modelData.name)
                                        }
                                    }

                                    Text {
                                        width: 148
                                        text: tokenCell.modelData.name
                                        color: Theme.current.colorText2
                                        font.pixelSize: Theme.current.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- 尺寸与间距 ----
        GallerySection {
            title: "尺寸与间距"
            visible: page.sizingGroups.length > 0

            Column {
                width: parent.width
                spacing: 24

                Repeater {
                    model: page.sizingGroups

                    delegate: Column {
                        id: sizingGroup

                        required property var modelData

                        width: parent.width
                        spacing: 10

                        Text {
                            text: sizingGroup.modelData.name
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                            font.weight: Font.DemiBold
                        }

                        Flow {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: sizingGroup.modelData.items

                                delegate: Row {
                                    id: tokenRow

                                    required property var modelData

                                    spacing: 8

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tokenRow.modelData.name
                                        color: Theme.current.colorText2
                                        font.pixelSize: Theme.current.fontSizeSmall
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        // 阴影是明暗两套值，取当前主题那一套
                                        text: page.isDark() && tokenRow.modelData.dark
                                            ? tokenRow.modelData.dark : tokenRow.modelData.value
                                        color: Theme.current.colorText1
                                        font.pixelSize: Theme.current.fontSizeSmall
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- 动效 ----
        GallerySection {
            title: "动效"
            visible: page.motionRows.length > 0

            Text {
                width: 620
                text: qsTr("源库里的时长与缩放全部是 0ms / scale(1,1)：Semi 的交互控件"
                    + "刻意不做过渡，反馈即时。可选项在源文件里以注释形式给出"
                    + "（最快 50ms、常用 200ms）。")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: page.motionRows

                    delegate: Row {
                        id: motionRow

                        required property var modelData

                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: motionRow.modelData.name
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: motionRow.modelData.value
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeSmall
                            font.weight: Font.DemiBold
                        }
                    }
                }
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

    // 剪贴板载体：不可见、零尺寸，不参与布局
    TextEdit {
        id: clipboard

        width: 0
        height: 0
        visible: false
    }

    Toast {
        id: copyToast

        duration: 1.6         // 官方 duration 单位是秒
    }

    function gradientStop(item, index) {
        const raw = page.isDark() ? item.dark : item.light;
        const stops = raw.match(/rgba?\([^)]*\)/g);
        if (stops === null || index >= stops.length)
            return "transparent";
        return stops[index];
    }

    function tokenRows() {
        if (page.tokens === null)
            return [];
        const sizing = page.tokens.sizing;
        return [
            { name: qsTr("字号"), items: sizing.fontSize },
            { name: qsTr("字重"), items: sizing.fontWeight },
            { name: qsTr("圆角"), items: sizing.radius },
            { name: qsTr("间距"), items: sizing.spacing },
            { name: qsTr("高度"), items: sizing.height },
            { name: qsTr("图标尺寸"), items: sizing.width },
            { name: qsTr("阴影"), items: sizing.shadow },
            { name: qsTr("z-index"), items: sizing.zIndex }
        ];
    }
}
