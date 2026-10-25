pragma ComponentBehavior: Bound

import QtQuick

// 滚动列表的选项行。配合 ScrollList 使用。
//
//     ScrollList {
//         ScrollListItem { text: "选项一" }
//         ScrollListItem { text: "选项二"; selected: true }
//     }
//
// 规格（packages/semi-foundation/scrollList/variables.scss）：
//   行高 36px；文字 text-0；悬浮底 fill-1；按下底 fill-2；禁用文字 disabled-text
//   选中底 primary-light-default、文字 text-0、左侧 16px 图标（text-2，图标右侧留 12px）
Item {
    id: control

    property string text: ""
    property bool selected: false
    property bool disabled: false
    property string iconName: "checkbox_tick"
    property int iconSize: 16
    property int iconMargin: 12

    signal clicked

    readonly property bool hovered: hoverHandler.hovered
    readonly property int paddingX: 16

    implicitWidth: row.implicitWidth + control.paddingX * 2
    implicitHeight: 36

    Rectangle {
        anchors.fill: parent
        color: {
            if (control.disabled)
                return "transparent";
            if (control.selected)
                return Theme.current.colorPrimaryLightDefault;
            if (pointerHandler.pressed)
                return Theme.current.colorFill2;
            if (control.hovered)
                return Theme.current.colorFill1;
            return "transparent";
        }
    }

    Row {
        id: row

        anchors.left: parent.left
        anchors.leftMargin: control.paddingX
        anchors.right: parent.right
        anchors.rightMargin: control.paddingX
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: control.selected
            name: control.iconName
            size: control.iconSize
            color: Theme.current.colorText2
            width: control.iconSize + control.iconMargin
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            color: control.disabled
                ? Theme.current.colorDisabledText : Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: control.selected ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
    }

    HoverHandler {
        id: hoverHandler
        enabled: !control.disabled
    }

    TapHandler {
        id: pointerHandler
        enabled: !control.disabled
        onTapped: control.clicked()
    }
}
