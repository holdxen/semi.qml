import QtQuick
import QtQuick.Effects

// Semi 图标。SVG 里是黑色实心形状，用 MultiEffect 的 colorization 着色，
// 于是图标能跟着主题走（文字色、各色调色）。
//
//     Icon { name: "plus"; size: 16; color: Theme.current.colorText0 }
//
// **color 的 alpha 不生效**：colorization 着色器只改 RGB、输出 alpha 恒等于源 alpha
// （multieffect.frag:84，colorizationColor.a 只是灰度与目标色的混合比）⇒ 传
// Qt.rgba(r,g,b,0.4) 会被画成实心。要半透明就把 alpha 放到这个 Item 的 `opacity` 上
// （Carousel 箭头就是这么落的，坑 135）。
//
// 图标名就是 semi-icons 的文件名（去掉 .svg），523 个，清单见 src/icons/icons.txt。
Item {
    id: root

    property string name: ""
    property color color: Theme.current.colorText0
    property int size: Theme.current.widthIconMedium
    // 少数图标自带品牌色/渐变（AI 系列），置 false 跳过着色、按原样显示
    property bool tinted: true

    readonly property url source: root.name
        ? "qrc:/qt/qml/Semi/icons/" + root.name + ".svg"
        : ""

    implicitWidth: size
    implicitHeight: size
    visible: root.name !== ""

    Image {
        id: image

        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.size, root.size)
        fillMode: Image.PreserveAspectFit
        smooth: true
        // 源保持可见即可：MultiEffect 会自己把它隐掉，不会重复画一遍。
        // （官方写法是源设 visible: false / opacity: 0，实测两种都行）
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        visible: root.tinted
        colorization: 1
        colorizationColor: root.color
    }
}
