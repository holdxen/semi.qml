pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/input/radio/index.md 的 11 个演示小节。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方「禁用」一节用 useState 控制 disabled
    property bool demoDisabled: true
    // 官方「单选组合」一节的受控 value
    property var comboValue: 1
    // 官方「配置 options」一节的三个受控值
    property var optionValue1: "Guest"
    property var optionValue2: "Developer"
    property var optionValue3: "Maintainer"

    readonly property string extraText:
        "Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统"

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 420
                text: "import Semi\n\nRadio { }\nRadioGroup { }"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "基本用法"

            Radio { text: "Radio" }
        }

        GallerySection {
            title: "带辅助文本"

            Radio {
                width: 360
                text: "Semi Design"
                extra: page.extraText
            }
        }

        GallerySection {
            title: "禁用"

            Column {
                spacing: 12

                Column {
                    spacing: 8

                    Radio { text: "Disabled"; disabled: page.demoDisabled }
                    Radio { text: "Disabled"; defaultChecked: true; disabled: page.demoDisabled }
                }

                Button {
                    text: qsTr("Toggle disabled")
                    onClicked: page.demoDisabled = !page.demoDisabled
                }
            }
        }

        GallerySection {
            title: "高级模式"

            Column {
                spacing: 8

                // 官方这一节是 checked + onChange 的受控写法；本库的 Radio 自己写 checked，
                // 外部绑定点一次就断（见 PROGRESS.md 已知坑 53），所以这里让组件自己持有状态，
                // 只把当前值显示出来 —— 要真受控就别写 checked，改接 onToggled。
                Radio {
                    id: advancedRadio

                    text: "允许取消选择"
                    mode: "advanced"
                    checked: true
                }

                Text {
                    text: qsTr("checked：%1").arg(advancedRadio.checked ? "true" : "false")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "单选组合"

            RadioGroup {
                value: page.comboValue
                onChanged: (v) => page.comboValue = v

                Radio { value: 1; text: "A" }
                Radio { value: 2; text: "B" }
                Radio { value: 3; text: "C" }
                Radio { value: 4; text: "D" }
            }
        }

        GallerySection {
            title: "垂直排列"

            RadioGroup {
                direction: Enums.DirectionVertical

                Radio { value: 1; text: "A" }
                Radio { value: 2; text: "B" }
                Radio { value: 3; text: "C" }
                Radio { value: 4; text: "D" }
            }
        }

        GallerySection {
            title: "按钮样式"

            Column {
                spacing: 20

                RadioGroup {
                    type: Enums.ChoiceButton
                    buttonSize: Enums.RadioButtonSmall
                    defaultValue: 1

                    Radio { value: 1; text: "即时推送" }
                    Radio { value: 2; text: "定时推送" }
                    Radio { value: 3; text: "动态推送" }
                }

                RadioGroup {
                    type: Enums.ChoiceButton
                    buttonSize: Enums.RadioButtonMiddle
                    defaultValue: 1

                    Radio { value: 1; text: "即时推送" }
                    Radio { value: 2; text: "定时推送" }
                    Radio { value: 3; text: "动态推送" }
                }

                RadioGroup {
                    type: Enums.ChoiceButton
                    buttonSize: Enums.RadioButtonLarge
                    defaultValue: 1

                    Radio { value: 1; text: "即时推送" }
                    Radio { value: 2; text: "定时推送" }
                    Radio { value: 3; text: "动态推送" }
                }

                Text {
                    width: 520
                    wrapMode: Text.WordWrap
                    text: qsTr("按钮式单选不支持辅助文本（extra）与竖排（direction='vertical'）。")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "卡片样式"

            RadioGroup {
                type: Enums.ChoiceCard
                direction: Enums.DirectionVertical
                defaultValue: 2

                Radio { value: 1; text: "单选框标题"; disabled: true; extra: page.extraText; width: 280 }
                Radio { value: 2; text: "单选框标题"; extra: page.extraText; width: 280 }
                Radio { value: 3; text: "单选框标题"; extra: page.extraText; width: 280 }
            }
        }

        GallerySection {
            title: "无 radio 的纯卡片样式"

            RadioGroup {
                type: Enums.ChoicePureCard
                direction: Enums.DirectionVertical
                defaultValue: 2

                Radio { value: 1; text: "单选框标题"; disabled: true; extra: page.extraText; width: 280 }
                Radio { value: 2; text: "单选框标题"; extra: page.extraText; width: 280 }
                Radio { value: 3; text: "单选框标题"; extra: page.extraText; width: 280 }
            }
        }

        GallerySection {
            title: "配置 options"

            Column {
                spacing: 20

                // 字符串数组：value 与文案都是它本身
                RadioGroup {
                    objectName: "plainOptionsGroup"
                    options: ["Guest", "Developer", "Maintainer"]
                    value: page.optionValue1
                    onChanged: (v) => page.optionValue1 = v
                }

                // 对象数组，最后一项禁用
                RadioGroup {
                    objectName: "disabledOptionsGroup"
                    options: [
                        { label: "Guest", value: "Guest" },
                        { label: "Developer", value: "Developer" },
                        { label: "Maintainer", value: "Maintainer", disabled: true }
                    ]
                    value: page.optionValue2
                    onChanged: (v) => page.optionValue2 = v
                }

                // 对象数组带 extra 与宽度
                RadioGroup {
                    objectName: "extraOptionsGroup"
                    options: [
                        { label: "Guest", value: "Guest", extra: "Semi Design", width: 120 },
                        { label: "Developer", value: "Developer", extra: "Semi Design", width: 120 },
                        { label: "Maintainer", value: "Maintainer", extra: "Semi Design", width: 120 }
                    ]
                    value: page.optionValue3
                    onChanged: (v) => page.optionValue3 = v
                }
            }
        }
    }
}
