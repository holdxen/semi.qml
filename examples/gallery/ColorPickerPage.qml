pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 受控小节用（官方 shape：{hsva, rgba, hex}）
    property var controlledValue: ({
        hsva: {h: 176, s: 71, v: 77, a: 1},
        rgba: {r: 57, g: 197, b: 187, a: 1},
        hex: "#39c5bb"
    })

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本用法"

            Column {
                spacing: 24

                Column {
                    spacing: 8

                    Text {
                        text: qsTr("放在弹层")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Row {
                        spacing: 16

                        ColorPicker {
                            id: popBasic

                            usePopover: true
                            alpha: true
                        }

                        // 官方是往 ColorPicker 里塞 children 当 trigger，本库用 triggerContent
                        ColorPicker {
                            id: popCustom

                            usePopover: true
                            alpha: true
                            triggerContent: Component {
                                Button { text: qsTr("Trigger") }
                            }
                        }
                    }
                }

                Column {
                    spacing: 8

                    Text {
                        text: qsTr("正常展示")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    ColorPicker {
                        id: inlinePicker

                        alpha: true
                    }
                }
            }
        }

        GallerySection {
            title: "滴管取色器"

            // 官方这里有条 Notice：要 HTTPS / localhost 且 Chromium > 95 才有取色能力。
            // Qt 侧没有 window.EyeDropper，按钮照画、点了不做任何事。
            ColorPicker {
                alpha: true
                eyeDropper: true
            }
        }

        GallerySection {
            title: "默认值"

            Column {
                spacing: 12

                // 官方写 defaultValue={ColorPicker.colorStringToValue("rgb(57,197,187)")}，
                // 本库的 defaultValue 直接收字符串（内部就是走同一个换算）
                ColorPicker {
                    defaultValue: "rgb(57,197,187)"
                    alpha: true
                }

                Text {
                    text: qsTr("当前 hex：%1").arg(String(inlinePicker.currentColor.hex))
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "受控"

            Column {
                spacing: 12

                ColorPicker {
                    id: controlled

                    value: page.controlledValue
                    alpha: true
                    onChanged: (next) => page.controlledValue = next
                }

                Row {
                    spacing: 8

                    Button {
                        text: qsTr("回到 #39c5bb")
                        variant: Enums.Light
                        size: Enums.Small
                        onClicked: page.controlledValue = controlled.colorStringToValue("#39c5bb")
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("值由外面给，拖完会被按钮覆盖回去")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }
            }
        }

        GallerySection {
            title: "顶部和底部渲染额外元素"

            ColorPicker {
                alpha: true
                topSlot: Component {
                    Text {
                        text: "TopSlot"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                        bottomPadding: Theme.current.spacingExtraTight
                    }
                }
                bottomSlot: Component {
                    Text {
                        text: "Bottom Slot"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                        topPadding: Theme.current.spacingExtraTight
                    }
                }
            }
        }
    }
}
