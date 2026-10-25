import QtQuick
import QtQuick.Effects

// 弹层投影。规格是 Semi 的 @mixin shadow-elevated（--semi-shadow-elevated）：
//   浅色  0 0 1px rgba(0,0,0,.3), 0 4px 14px rgba(0,0,0,.1)
//   深色  inset 0 0 0 1px rgba(255,255,255,.1), 0 4px 14px rgba(0,0,0,.25)
//
// MultiEffect 一次只能出一层投影（已知坑 34），所以 Semi 拿 1px 阴影模拟描边
// 那层由宿主的 border 顶替。扩散层的参数与 PopupBase 同一套，理由也记在那边：
// alpha 用 CSS 的 .1，blurMax 取 CSS radius × 2.3 = 32（已知坑 34、55）。
//
// 用法：放进要投影的本体矩形里，`anchors.fill: parent` + `z: -1`。
// 本体不透明会把源盖住，只有溢出边界的投影可见。
// （PopupBase 自己实现了同一套，因为它的阴影源还要带上箭头。）
Item {
    id: control

    property real radius: Theme.current.radiusMedium
    property color fill: Theme.current.colorBg3
    property bool shadowEnabled: true
    property color shadowColor: Theme.mode === Theme.Dark
        ? Qt.rgba(0, 0, 0, 0.25)
        : Qt.rgba(0, 0, 0, 0.1)
    property real shadowBlurMax: 32
    property real shadowVerticalOffset: 4

    Rectangle {
        id: shadowSource

        anchors.fill: parent
        radius: control.radius
        color: control.fill
        visible: false
    }

    MultiEffect {
        source: shadowSource
        anchors.fill: shadowSource
        visible: control.shadowEnabled
        shadowEnabled: true
        shadowColor: control.shadowColor
        shadowVerticalOffset: control.shadowVerticalOffset
        shadowBlur: 1.0
        blurMax: control.shadowBlurMax
    }
}
