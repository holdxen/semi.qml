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
            title: "基本"

            Row {
                spacing: 20

                Switch { checked: false }
                Switch { checked: true }
            }
        }

        GallerySection {
            title: "尺寸"

            Row {
                spacing: 20

                Switch { checked: true; size: Enums.Small }
                Switch { checked: true; size: Enums.Default }
                Switch { checked: true; size: Enums.Large }
            }
        }

        GallerySection {
            title: "不可用"

            Row {
                spacing: 20

                Switch { checked: false; enabled: false }
                Switch { checked: true; enabled: false }
            }
        }

        GallerySection {
            title: "带文本"

            Row {
                spacing: 20

                Switch {
                    checked: true
                    checkedText: "开"
                    uncheckedText: "关"
                }

                Switch {
                    checkedText: "｜"
                    uncheckedText: "〇"
                }

                Switch {
                    size: Enums.Large
                    checkedText: "开"
                    uncheckedText: "关"
                }

                Switch {
                    size: Enums.Large
                    checked: true
                    checkedText: "｜"
                    uncheckedText: "〇"
                }
            }
        }

        GallerySection {
            title: "受控组件"

            Row {
                spacing: 8

                Switch {
                    id: controlled

                    checked: page.switchOn
                    // Switch 被点时自己会写一次 checked，那一下就把上面这条绑定冲掉了，
                    // 之后按钮改 page.switchOn 也再也传不进来。所以回调里把绑定重新装回去
                    // （与 GallerySidebar 里主题开关同一处理）。
                    onToggled: {
                        page.switchOn = controlled.checked;
                        controlled.checked = Qt.binding(function () { return page.switchOn; });
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("受控开关")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("从外部打开")
                    variant: Enums.Light
                    onClicked: page.switchOn = true
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("从外部关闭")
                    variant: Enums.Light
                    onClicked: page.switchOn = false
                }
            }
        }

        GallerySection {
            title: "加载中"

            Row {
                spacing: 20

                Switch {
                    loading: true
                }

                Switch {
                    loading: true
                    checked: true
                }

                Switch {
                    loading: true
                    enabled: false
                }

                Switch {
                    loading: true
                    checked: true
                    enabled: false
                }
            }
        }
    }

    property bool switchOn: false
}
