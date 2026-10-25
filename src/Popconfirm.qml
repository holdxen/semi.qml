import QtQuick

// 气泡确认。比 Modal 轻，适合「确定要删除吗」这类就地确认。
// 直接建在 PopupBase 上而不是 Popover —— Popover 自带 title，会和这里的标题打架。
//
//     Popconfirm {
//         id: pc
//         anchor: delBtn
//         title: "确认删除"
//         description: "删除后不可恢复"
//         onConfirmed: doDelete()
//     }
//
// 规格：警示图标 24px 且用 warning 色，最大宽 400（$width-popconfirm-*）。
PopupBase {
    id: control

    property string title: ""
    property string description: ""
    property string okText: qsTr("确定")
    property string cancelText: qsTr("取消")
    property int tone: Enums.Warning
    property string iconName: "alert_circle"

    fillColor: Theme.current.colorBg3
    strokeColor: Theme.current.colorBorder
    showArrow: true
    autoFlip: true

    signal confirmed
    signal cancelled

    implicitWidth: Math.min(400, Math.max(280, body.implicitWidth + 64))

    Column {
        id: body

        spacing: Theme.current.spacingBaseTight

        Row {
            width: parent ? parent.width : 240
            spacing: Theme.current.spacingTight

            Icon {
                anchors.top: parent.top
                anchors.topMargin: 2
                visible: control.iconName !== ""
                name: control.iconName
                size: 24                       // $width-popconfirm-icon
                color: Appearance.textColor(Theme.current, control.tone)
            }

            Column {
                width: Math.max(0, parent.width - 32)
                spacing: Theme.current.spacingExtraTight

                Text {
                    width: parent.width
                    visible: control.title !== ""
                    text: control.title
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    visible: control.description !== ""
                    text: control.description
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.current.spacingTight

            Button {
                text: control.cancelText
                tone: Enums.Tertiary
                variant: Enums.Light
                size: Enums.Small
                onClicked: {
                    control.cancelled();
                    control.close();
                }
            }

            Button {
                text: control.okText
                tone: control.tone
                // popconfirm/index.tsx:186 的确认键是 theme="solid"
                variant: Enums.Solid
                size: Enums.Small
                onClicked: {
                    control.confirmed();
                    control.close();
                }
            }
        }
    }
}
