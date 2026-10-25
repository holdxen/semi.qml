import QtQuick

// InputNumber 的步进器列，对应官方 .semi-input-number-suffix-btns
// （inputNumber.scss:14-70 + variables.scss:8-24）。InputNumber 外层用一次、
// innerButtons 时改挂到 Input 的 suffix 槽再用一次（index.tsx:499-508、587-589），
// 两种形态只差左边距、高度与圆角裁切，所以做成一个可复用组件。
//
// 官方把两个按钮挂在 span 上，onMouseDown 步进、onMouseUp 停计时器
// （index.tsx:479-494），到达上下界时挂的是 noop（index.tsx:481、489）。
Item {
    id: root

    // 列高：外层等于控件高，内层等于控件高减 2（VA:4-6）
    property real columnHeight: Theme.current.heightControlDefault
    // innerButtons 形态
    property bool inner: false
    // .semi-input-number-suffix-btns-inner-hover：悬浮但未聚焦时描边转 color-fill-2
    property bool hoverBorder: false
    property bool upAllowed: true
    property bool downAllowed: true

    signal stepUp(bool shift)
    signal stepDown(bool shift)
    signal released()

    // $width-inputNumber_button / $width-inputNumber_button-border
    readonly property real buttonWidth: 14
    readonly property real borderWidth: 1
    readonly property real gap: root.inner
        ? Theme.current.spacingTight          // $spacing-inputNumber_button_inner-marginLeft
        : Theme.current.spacingExtraTight     // $spacing-inputNumber_button-marginLeft
    readonly property real boxWidth: root.buttonWidth + root.borderWidth * 2
    // 官方列是 border-box，按钮 height:50% 相对的是内容盒（列高减上下各 1px 描边），
    // 且子节点从内容盒起点排布，所以按钮要整体内缩一个描边宽，否则会盖掉列的描边。
    readonly property real buttonHeight: (root.columnHeight - root.borderWidth * 2) / 2

    implicitWidth: root.gap + root.boxWidth
    implicitHeight: root.columnHeight

    function buttonBg(area, pressed, allowed) {
        if (!root.enabled)
            return Theme.current.colorDisabledFill;   // $color-inputNumber_button-bg-disabled
        if (pressed)
            return Theme.current.colorFill1;          // :active -> bg-active
        if (area.containsMouse && allowed)
            return Theme.current.colorFill0;          // :hover -> bg-hover
        return Theme.current.colorBg2;                // bg-default
    }

    Rectangle {
        id: box
        objectName: "stepperColumn"

        x: root.gap
        width: root.boxWidth
        height: root.columnHeight
        radius: Theme.current.radiusSmall
        // .semi-input-number-suffix-btns { background-color: bg-2 }（inputNumber.scss:20）
        color: Theme.current.colorBg2
        border.width: root.borderWidth
        border.color: root.hoverBorder
            ? Theme.current.colorFill2 : Theme.current.colorBorder
        clip: true    // 内层 overflow: hidden，按钮的方角要被子节点的圆角切掉

        Rectangle {
            id: upButton
            objectName: "stepUpButton"

            x: root.borderWidth
            y: root.borderWidth
            width: root.buttonWidth
            height: root.buttonHeight
            color: root.buttonBg(upArea, upArea.pressed, root.upAllowed)

            Icon {
                objectName: "stepUpIcon"

                anchors.centerIn: parent
                name: "chevron_up"
                size: Theme.current.widthIconExtraSmall
                color: root.enabled
                    ? Theme.current.colorText2 : Theme.current.colorDisabledText
            }

            MouseArea {
                id: upArea

                anchors.fill: parent
                enabled: root.enabled
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                cursorShape: root.upAllowed && root.enabled
                    ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                property bool shiftDown: false

                onPressed: (event) => {
                    shiftDown = event.modifiers & Qt.ShiftModifier;
                    if (root.upAllowed)
                        root.stepUp(shiftDown);
                }
                onReleased: root.released()
                onCanceled: root.released()
            }
        }

        Rectangle {
            id: downButton
            objectName: "stepDownButton"

            x: root.borderWidth
            y: root.borderWidth + upButton.height
            width: root.buttonWidth
            height: root.buttonHeight
            color: root.buttonBg(downArea, downArea.pressed, root.downAllowed)

            Icon {
                objectName: "stepDownIcon"

                anchors.centerIn: parent
                name: "chevron_down"
                size: Theme.current.widthIconExtraSmall
                color: root.enabled
                    ? Theme.current.colorText2 : Theme.current.colorDisabledText
            }

            MouseArea {
                id: downArea

                anchors.fill: parent
                enabled: root.enabled
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                cursorShape: root.downAllowed && root.enabled
                    ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                property bool shiftDown: false

                onPressed: (event) => {
                    shiftDown = event.modifiers & Qt.ShiftModifier;
                    if (root.downAllowed)
                        root.stepDown(shiftDown);
                }
                onReleased: root.released()
                onCanceled: root.released()
            }
        }
    }
}
