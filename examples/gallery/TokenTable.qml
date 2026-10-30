pragma ComponentBehavior: Bound

import QtQuick
import Semi
// 静态检查认不出这条跨模块的绝对路径 import（运行时是好的），用到的那一行单独放行
// qmllint disable missing-property
import "qrc:/qt/qml/Semi/CssGradient.js" as CssGradient
// qmllint enable missing-property

// 令牌表，照官网 src/components/DesignToken/index.tsx 的 TokenTable：
// 三列「变量 / 默认值 / 用法」，用 semi-ui 的 Table 渲染（官方也是 Table），
// 不分页（官方那份没给 pagination）。
//
//   · 变量列：`--semi-color*` 开头的那些前面挂一枚 16×16、圆角 3 的色片
//     （index.tsx:78-89 —— 判据是 key 而不是「能不能解析成颜色」，所以色板档位、
//      $spacing-* 这些都不挂色片），名字整格加粗 600
//   · 默认值列：值以 `var(` 开头时渲染成站内链接（JumpLink，:48-62），
//     点它 = 跳去 `?token=<名字>`，也就是滚到那一行并闪一下黄底
//   · 用法列：注释，空的话给「暂无」（:105）
//
// 端口加的一件事：整行可点，复制 `Theme.current.<accessor>`（官网表格没有复制，
// 只有色板有；这一条是用户要的「点复制要复制 Theme.current.xxx，不要复制色值」）。
Item {
    id: control

    /// 令牌数组，元素是 tokens.json 里那种 { key, value, comment, accessor, color }
    property var rows: []
    /// 当前被跳转命中的键，那一行闪黄底
    property string flashKey: ""
    /// 点了行：复制 `Theme.current.<accessor>`
    signal copied(string text)
    /// 点了「默认值」里的 var 引用
    signal jumped(string key)
    /// 某一行的黄底被点亮了 —— 把那个节点交回页面，由它滚到视口中间
    /// （官网 JumpToToken 干的是 `scrollIntoView({block:'center'})`）
    signal flashed(var item, string key)

    width: parent ? parent.width : 0
    implicitHeight: table.implicitHeight

    // 把「回调」塞进行对象里带给单元格：Table 只把 record 与 text 注入节点，
    // 而内联组件按 ComponentBehavior: Bound 拿不到外层 id ⇒ 闭包随行走。
    readonly property var tableRows: {
        const out = [];
        const list = control.rows === undefined || control.rows === null ? [] : control.rows;
        for (let i = 0; i < list.length; ++i) {
            const t = list[i];
            out.push({
                key: t.key,
                value: t.value,
                comment: t.comment === undefined ? "" : t.comment,
                swatch: control.isColorToken(t.key) && control.isPaintable(t.color) ? t.color : "",
                // qmllint disable missing-property
                swatchStops: control.isColorToken(t.key) && control.isGradient(t.color)
                    ? CssGradient.horizontalStops(t.color) : null,
                // qmllint enable missing-property
                copyText: t.accessor === undefined || t.accessor === null
                    ? "" : "Theme.current." + t.accessor,
                refKey: control.refKeyOf(t.value),
                flash: String(t.key) === control.flashKey,
                wrapWidth: Math.max(160, Math.floor(control.width / 3) - 32),
                onFlash: function (item) { control.flashed(item, t.key); },
                onCopy: function (text) { control.copied(text); },
                onJump: function (key) { control.jumped(key); }
            });
        }
        return out;
    }

    // 官网的判据：key 以 --semi-color 开头才挂色片
    function isColorToken(key) {
        return String(key).indexOf("--semi-color") === 0;
    }

    // AI 那几条语义色的值是整段 linear-gradient(...)：给 Rectangle.color 会得到纯黑，
    // 必须走 gradient 那一档（拆法与 Button / Tag 共用 CssGradient.js）
    function isGradient(color) {
        return color !== undefined && color !== null
            && String(color).indexOf("linear-gradient") === 0;
    }

    function isPaintable(color) {
        return color !== undefined && color !== null && !control.isGradient(color);
    }

    // JumpLink:51-56 —— 只有**整串以 var( 开头**才算链接：`rgba(var(--semi-blue-5), 1)`
    // 不是（那是绝大多数颜色行），`var(--semi-ai-general-5)` 才是
    // （global.scss:127-130 那四条 AI 色，端口一共 8 条含深色档）。
    function refKeyOf(value) {
        const v = String(value);
        if (v.indexOf("var(") !== 0)
            return "";
        const end = v.indexOf(")");
        return end < 0 ? "" : v.slice(4, end);
    }

    // render 要返回一个 Component（内联 component 是类型名，不是值）
    Component {
        id: keyCellComp

        KeyCell {}
    }

    Component {
        id: valueCellComp

        ValueCell {}
    }

    Component {
        id: usageCellComp

        UsageCell {}
    }

    Table {
        id: table

        width: parent.width
        pagination: false
        columns: [
            {
                title: qsTr("变量"),
                dataIndex: "key",
                render: (text, record, index) => keyCellComp
            },
            {
                title: qsTr("默认值"),
                dataIndex: "value",
                render: (text, record, index) => valueCellComp
            },
            {
                title: qsTr("用法"),
                dataIndex: "comment",
                render: (text, record, index) => usageCellComp
            }
        ]
        dataSource: control.tableRows
    }

    // 根必须是 Item 而不是 Row：位置器不接受带 fill / left+right 锚点的子项
    // （黄底那一块要铺满整格，Row 会直接罢工并报 "Row will not function"）
    component KeyCell: Item {
        id: keyCell

        property var record: null
        property string text: ""

        implicitWidth: row.width
        implicitHeight: Math.max(row.height, 20)

        // 被跳转命中时闪一下黄底（JumpToToken/index.tsx:31 的 backgroundColor='yellow'）
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: "yellow"
            opacity: 0.6
            visible: keyCell.record !== null && keyCell.record.flash === true
        }

        Row {
            id: row

            spacing: Theme.current.spacingTight

            Rectangle {
                id: chip

                readonly property var stops: keyCell.record !== null ? keyCell.record.swatchStops : null
                // Rectangle 本身就有 gradient 属性，这里别重名
                readonly property bool gradientChip: stops !== null && stops !== undefined

                function stopColor(i) {
                    return i < stops.length ? stops[i].color : "transparent";
                }

                function stopPosition(i) {
                    return i < stops.length ? stops[i].position : 1;
                }

                visible: keyCell.record !== null
                    && (keyCell.record.swatch !== "" || chip.gradientChip)
                anchors.verticalCenter: row.verticalCenter
                width: 16
                height: 16
                radius: 3
                // 色片画的是**这一档自己那套值**，不受站点主题影响
                // （官网给那枚片子挂了 semi-always-light / semi-always-dark）
                color: chip.gradientChip ? "transparent"
                    : (keyCell.record === null ? "transparent" : keyCell.record.swatch)
                gradient: chip.gradientChip ? chipGradient : null
                border.width: 1
                border.color: Theme.current.colorBorder

                Gradient {
                    id: chipGradient

                    orientation: Gradient.Horizontal

                    GradientStop { position: chip.stopPosition(0); color: chip.stopColor(0) }
                    GradientStop { position: chip.stopPosition(1); color: chip.stopColor(1) }
                    GradientStop { position: chip.stopPosition(2); color: chip.stopColor(2) }
                    GradientStop { position: chip.stopPosition(3); color: chip.stopColor(3) }
                }
            }

            Text {
                anchors.verticalCenter: row.verticalCenter
                // 官方那一格是 `--semi-color-primary-light-active` 这种长名字，
                // 折行而不是截断（不给宽度的话 Row 会把整格撑出去、被表格裁掉半截）
                width: keyCell.record === null ? 120 : Math.max(60, keyCell.record.wrapWidth - 24)
                text: keyCell.text
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: keyCell.record !== null && keyCell.record.copyText !== ""
                ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            onTapped: {
                if (keyCell.record === null)
                    return;
                if (keyCell.record.copyText !== "")
                    keyCell.record.onCopy(keyCell.record.copyText);
            }
        }

        // 被跳转命中 ⇒ 把自己交回页面去滚（Loader 换 record 时两次都要走一遍）
        onRecordChanged: pageTell()
        Component.onCompleted: pageTell()

        function pageTell() {
            if (keyCell.record === null || keyCell.record.flash !== true)
                return;
            keyCell.record.onFlash(keyCell, keyCell.record.key);
        }
    }

    component ValueCell: Item {
        id: valueCell

        property var record: null
        property string text: ""

        implicitWidth: link.implicitWidth
        implicitHeight: link.implicitHeight

        // 是 var 引用 ⇒ 站内链接（官网 Link 的观感：primary 色）；否则纯文本
        readonly property bool isLink: valueCell.record !== null
            && valueCell.record.refKey !== ""

        Text {
            id: link

            text: valueCell.text
            color: valueCell.isLink ? Theme.current.colorPrimary : Theme.current.colorText1
            font.pixelSize: Theme.current.fontSizeRegular
        }

        TapHandler {
            enabled: valueCell.isLink
            onTapped: valueCell.record.onJump(valueCell.record.refKey)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: valueCell.isLink ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }

    // 「用法」那一列是整页最长的一段字，得按列宽折行。
    // Table 只把节点贴在格子左边，不给宽度 ⇒ 折行宽由行对象带进来（wrapWidth）。
    component UsageCell: Item {
        id: usageCell

        property var record: null
        property string text: ""

        implicitWidth: body.implicitWidth
        implicitHeight: body.height

        Text {
            id: body

            width: usageCell.record === null ? 240 : usageCell.record.wrapWidth
            // 空注释给「暂无」（index.tsx:105 的 designToken.WIP）
            text: usageCell.text === "" || usageCell.text === undefined ? qsTr("暂无") : usageCell.text
            color: Theme.current.colorText1
            font.pixelSize: Theme.current.fontSizeRegular
            wrapMode: Text.WordWrap
        }
    }
}
