import QtQuick

// 方形图标按钮。外观（形态 × 色调 × 状态）走和 Button 同一套解析，
// 只是宽度取控件高度、内容换成图标。
//
//     IconButton { icon: "plus"; tooltip: "新建" }
Item {
    id: control

    property alias icon: glyph.name
    property alias tooltip: hint.text
    property int tone: Enums.Primary
    property int variant: Enums.Borderless
    property int size: Enums.Default

    signal clicked

    readonly property int controlState: Appearance.state(control.enabled, hover.hovered, tap.pressed)
    readonly property color glyphColor:
        Appearance.buttonForeground(Theme.current, control.tone, control.variant, control.controlState)

    implicitWidth: Appearance.buttonHeight(Theme.current, control.size)
    implicitHeight: Appearance.buttonHeight(Theme.current, control.size)
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.7

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Theme.current.radiusSmall
        color: Appearance.buttonBackground(Theme.current, control.tone, control.variant, control.controlState)
        border.width: Appearance.buttonBorderWidth(control.variant)
        border.color: Appearance.buttonBorderColor(Theme.current, control.tone, control.variant, control.controlState)

        Behavior on color {
            ColorAnimation { duration: Theme.current.durationFast }
        }

        // focus-visible：只有键盘操作后才画轮廓
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: surface.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Appearance.buttonFocusRing(Theme.current, control.tone, control.variant)
            visible: FocusVisible.shouldShow(control.activeFocus)
        }

        Icon {
            id: glyph

            anchors.centerIn: parent
            size: Math.round(control.implicitHeight / 2)
            color: control.glyphColor
        }
    }

    Text {
        id: hint
        visible: false
    }

    HoverHandler {
        id: hover
        enabled: control.enabled
    }

    TapHandler {
        id: tap
        enabled: control.enabled
        onTapped: control.clicked()
    }
}
