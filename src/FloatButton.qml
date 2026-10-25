pragma ComponentBehavior: Bound

import QtQuick

// 悬浮按钮。默认贴在容器右下角，也可以自己改 x / y。
//
//     FloatButton { icon: "plus"; onClicked: ... }
//     FloatButton { icon: "arrow_up"; size: Enums.Large; rightMargin: 24; bottomMargin: 24 }
//
// 规格（packages/semi-foundation/floatButton/variables.scss）：
//   尺寸 小 24 / 默认 32 / 大 40；距右距底默认 24px；
//   底色 fill-0、图标 primary；悬浮 fill-1、按下 fill-2；禁用 disabled-bg。
Item {
    id: control

    property string icon: ""
    property string text: ""
    property int size: Enums.Default
    property bool disabled: false
    property bool circle: true
    property int rightMargin: 24
    property int bottomMargin: 24
    property int iconSize: Theme.current.widthIconMedium

    signal clicked

    readonly property int side: control.size === Enums.Small ? 24
        : (control.size === Enums.Large ? 40 : 32)
    readonly property bool hovered: floatHover.hovered

    x: control.parent ? control.parent.width - width - control.rightMargin : 0
    y: control.parent ? control.parent.height - height - control.bottomMargin : 0
    width: control.text !== "" ? Math.max(control.side, contentRow.implicitWidth + 24) : control.side
    height: control.side
    z: 10

    Rectangle {
        anchors.fill: parent
        radius: control.circle ? height / 2 : Theme.current.radiusSmall
        color: {
            if (control.disabled)
                return Theme.current.colorDisabledBg;
            if (floatTap.pressed)
                return Theme.current.colorFill2;
            if (control.hovered)
                return Theme.current.colorFill1;
            return Theme.current.colorFill0;
        }

        Row {
            id: contentRow

            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.icon !== ""
                name: control.icon
                size: control.iconSize
                color: control.disabled
                    ? Theme.current.colorDisabledText : Theme.current.colorPrimary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.text !== ""
                text: control.text
                color: control.disabled
                    ? Theme.current.colorDisabledText : Theme.current.colorPrimary
                font.pixelSize: Theme.current.fontSizeRegular
            }
        }
    }

    HoverHandler {
        id: floatHover
        enabled: !control.disabled
    }

    TapHandler {
        id: floatTap
        enabled: !control.disabled
        onTapped: control.clicked()
    }
}
