pragma ComponentBehavior: Bound

import QtQuick
import Semi
// CssGradient.js 住在 Semi 模块里，跨模块不能按相对路径 import（那份是端口共用的
// 渐变拆法，这里按 qrc 绝对路径取同一份，不再抄一遍算法）
import "qrc:/qt/qml/Semi/CssGradient.js" as CssGradient

// 色板里那一格色块，照官网 src/components/FullPalette/index.jsx 的 ColorBlock
// 与 index.module.scss 的 .color-block 一族来：
//   · 块 160×64、内边距 12、字号 12，上下两端对齐（上：名称，下：对比度徽标）
//   · 底是 10px 棋盘（@mixin checkerboard(10px, grey-3, grey-4) ⇒ background-size 20），
//     只有半透明的色才露得出来
//   · 悬浮：scale(1.05) + 3px 实环（浅色档环是 #fff，深色档是 rgba(10,10,10,1)）+ z 抬到 99
//   · 按下：opacity .8
//   · 值那一行平时不画，悬浮才出现，opacity .5、等宽字体
//   · 徽标：该色与纯白 / 纯黑的 WCAG 分档，Fail 的那档不画（官网 `wscore === 'Fail' ? '' : …`）
//   · 点一下把 copyText 送进剪贴板。官网送的是 `rgba(var(--semi-blue-5), 1)` 这种引用，
//     端口的对应物就是 QML 里的取法 `Theme.current.blue[5]`
Item {
    id: control

    /// 展示名（官网把色相名首字母大写：`Blue 5`）与值原文（色板那档是 `0,100,250` 三元组）
    property string name: ""
    property string value: ""
    /// 画出来的颜色：CSS 色串，或（isGradient 时）一整段 linear-gradient
    property string swatch: ""
    property bool isGradient: false
    /// 复制出去的那串（`Theme.current.xxx`）；空串 = 这一格不给复制
    property string copyText: ""
    /// 颜色转换那一节的块子多一条 1px color-border 的环（`.color-converter .color-block`）
    property bool bordered: false
    /// 标题文字颜色：官网按「压不压得住白字」给 #fff / #000
    property color captionColor: Theme.current.colorBg0
    /// 与纯白 / 纯黑的 WCAG 分档；Fail 传空串（那一枚不画）
    property string whiteScore: ""
    property string blackScore: ""

    /// 端口解色值时，带 alpha 的那批给成 `rgba(r, g, b, a)`（不透明的给成 #RRGGBB）
    readonly property bool swatchTransparent: String(control.swatch).indexOf("rgba(") === 0
        || /^#[0-9a-fA-F]{8}$/.test(String(control.swatch))

    signal copied(string text)

    width: 160
    height: 64
    // .color-block:hover { z-index: 99 }：悬浮的这块要压在邻居的阴影上
    z: blockHover.hovered ? 99 : 0
    scale: blockHover.hovered ? 1.05 : 1
    opacity: blockPress.pressed ? 0.8 : 1
    Behavior on scale {
        NumberAnimation { duration: 100 }          // transition: transform .1s
    }

    // 棋盘底。Qt 没有 repeating-linear-gradient，拿一张 20×20 的 SVG 平铺顶上：
    // 底色 grey-3，(0,0) 与 (10,10) 两块 10×10 铺 grey-4 —— 与那个 mixin 的两次
    // linear-gradient(45deg, accent 25%, transparent 0, transparent 75%, accent 0) 同形。
    // sourceSize 要按 DPR 放大：SVG 的 sourceSize 是**设备像素**，
    // 直接给 20 在 2x 屏上只铺出 10 逻辑像素的格子（见 PROGRESS 里 SVG 那条坑）。
    Image {
        id: checker

        // 棋盘只在「这块本身是半透明」的时候才看得见（官网那两层 repeating gradient
        // 也是垫在色块底下的）。放在色层之下还常开的话，平铺的 SVG 会跟色块抢叠放顺序。
        visible: control.swatchTransparent
        anchors.fill: parent
        fillMode: Image.Tile
        sourceSize: Qt.size(20 * Screen.devicePixelRatio, 20 * Screen.devicePixelRatio)
        smooth: false

        readonly property string tile: "<svg xmlns='http://www.w3.org/2000/svg' width='20' height='20'>"
            + "<rect width='20' height='20' fill='" + String(Theme.current.grey[3]) + "'/>"
            + "<rect width='10' height='10' fill='" + String(Theme.current.grey[4]) + "'/>"
            + "<rect x='10' y='10' width='10' height='10' fill='" + String(Theme.current.grey[4]) + "'/>"
            + "</svg>"
        source: "data:image/svg+xml;utf8," + encodeURIComponent(checker.tile)
    }

    // .color-rect：绝对铺满的那层颜色
    Rectangle {
        id: face

        anchors.fill: parent
        color: control.isGradient ? "transparent" : control.swatch
        gradient: control.isGradient ? faceGradient : null

        Gradient {
            id: faceGradient

            // 官方是 278deg，Qt 的 Gradient 只有水平 / 垂直两档 ⇒ 取水平，
            // 0% 放右端（拆法与 Button / Tag 同一口径，见 CssGradient.js）
            orientation: Gradient.Horizontal

            GradientStop { position: control.stopPosition(0); color: control.stopColor(0) }
            GradientStop { position: control.stopPosition(1); color: control.stopColor(1) }
            GradientStop { position: control.stopPosition(2); color: control.stopColor(2) }
            GradientStop { position: control.stopPosition(3); color: control.stopColor(3) }
        }
    }

    // 静态检查认不出这条跨模块的绝对路径 import（运行时是好的），这一行单独放行
    // qmllint disable missing-property
    readonly property var stops: control.isGradient ? CssGradient.horizontalStops(control.swatch) : []
    // qmllint enable missing-property

    function stopColor(i) {
        return i < control.stops.length ? control.stops[i].color : "transparent";
    }

    function stopPosition(i) {
        return i < control.stops.length ? control.stops[i].position : 1;
    }

    // 悬浮那 3px 实环（box-shadow: 0 0 0 3px …）画在盒子外面
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        color: "transparent"
        border.width: 3
        border.color: Theme.mode === Theme.Dark ? Qt.rgba(10 / 255, 10 / 255, 10 / 255, 1) : "#ffffff"
        visible: blockHover.hovered
    }

    // 颜色转换那档常驻的 1px 环
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Theme.current.colorBorder
        visible: control.bordered
    }

    // 名称 + 值
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 0

        Text {
            text: control.name
            color: control.captionColor
            font.pixelSize: 12
            font.weight: Font.Bold
        }

        Text {
            width: parent.width
            visible: blockHover.hovered            // display: none → block
            opacity: 0.5
            text: control.value
            color: control.captionColor
            font.family: "Menlo"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    // 对比度徽标：.ratios { width:100%; text-align:right }，两枚之间 margin-left 8
    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        spacing: 8
        layoutDirection: Qt.RightToLeft

        Text {
            visible: control.blackScore !== ""
            text: control.blackScore
            color: "#000000"
            font.pixelSize: 12
        }

        Text {
            visible: control.whiteScore !== ""
            text: control.whiteScore
            color: "#ffffff"
            font.pixelSize: 12
        }
    }

    HoverHandler {
        id: blockHover
    }

    TapHandler {
        id: blockPress

        acceptedButtons: Qt.LeftButton
        onTapped: if (control.copyText !== "")
            control.copied(control.copyText)
    }

    // .color-block { cursor: pointer }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: control.copyText === "" ? Qt.ArrowCursor : Qt.PointingHandCursor
    }
}
