pragma ComponentBehavior: Bound

import QtQuick

// 快捷键展示。把组合键渲染成一组小方块。
//
//     HotKeys { keys: ["Ctrl", "Shift", "S"] }
Row {
    id: control

    property var keys: []
    property int size: Enums.Default

    readonly property int keyHeight: control.size === Enums.Small ? 18 : 22
    readonly property int fontSize: control.size === Enums.Small
        ? Theme.current.fontSizeSmall - 1
        : Theme.current.fontSizeSmall

    spacing: Theme.current.spacingExtraTight

    Repeater {
        model: control.keys

        delegate: Item {
            id: wrapper

            required property var modelData
            required property int index

            readonly property bool last: wrapper.index === control.keys.length - 1
            readonly property int gap: Theme.current.spacingExtraTight

            // 宽度要把后面的加号也算进去，否则加号会贴着下一个键
            width: keyRect.width + (wrapper.last ? 0 : gap + plusText.implicitWidth + gap)
            height: control.keyHeight

            Rectangle {
                id: keyRect

                width: keyLabel.implicitWidth + 12
                height: parent.height
                radius: Theme.current.radiusSmall
                color: Theme.current.colorFill0
                border.width: 1
                border.color: Theme.current.colorBorder

                Text {
                    id: keyLabel

                    anchors.centerIn: parent
                    text: String(wrapper.modelData)
                    color: Theme.current.colorText1
                    font.pixelSize: control.fontSize
                }
            }

            Text {
                id: plusText

                anchors.left: keyRect.right
                anchors.leftMargin: wrapper.gap
                anchors.verticalCenter: parent.verticalCenter
                visible: !wrapper.last
                text: "+"
                color: Theme.current.colorText3
                font.pixelSize: control.fontSize
            }
        }
    }
}
