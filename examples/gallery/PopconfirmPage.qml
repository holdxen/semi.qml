pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本使用"

            Column {
                width: 520
                spacing: 12

                Row {
                    spacing: 12

                    Button {
                        id: deleteButton
                        text: qsTr("删除项目")
                        tone: Enums.Danger
                        onClicked: basicConfirm.open()
                    }

                    Popconfirm {
                        id: basicConfirm

                        anchor: deleteButton
                        title: qsTr("确认删除")
                        description: qsTr("删除后不可恢复，确定继续吗？")
                    }
                }

                Text {
                    text: qsTr("点按钮，气泡确认框会贴着它弹出来，确认与取消各发一个信号。")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }
        }

        GallerySection {
            title: "类型搭配"

            Column {
                width: 520
                spacing: 12

                Row {
                    spacing: 12

                    Button {
                        id: warnButton
                        text: qsTr("警告操作")
                        variant: Enums.Light
                        onClicked: warnConfirm.open()
                    }

                    Popconfirm {
                        id: warnConfirm

                        anchor: warnButton
                        tone: Enums.Warning
                        title: qsTr("该操作会影响线上")
                        description: qsTr("确认后立即发布到生产环境。")
                    }
                }

                Row {
                    spacing: 12

                    Button {
                        id: infoButton
                        text: qsTr("普通确认")
                        variant: Enums.Light
                        onClicked: infoConfirm.open()
                    }

                    Popconfirm {
                        id: infoConfirm

                        anchor: infoButton
                        tone: Enums.Info
                        title: qsTr("确认提交")
                        description: qsTr("提交后进入审核流程。")
                    }
                }
            }
        }

        GallerySection {
            title: "自定义文案"

            Row {
                spacing: 12

                Button {
                    id: customButton
                    text: qsTr("点开看看")
                    variant: Enums.Light
                    onClicked: customConfirm.open()
                }

                Popconfirm {
                    id: customConfirm

                    anchor: customButton
                    title: qsTr("带自定义文案")
                    description: qsTr("确认与取消的按钮文字都可以改。")
                    okText: qsTr("知道了")
                    cancelText: qsTr("算了")
                }
            }
        }
    }
}
