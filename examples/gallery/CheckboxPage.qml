pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 受控小节用
    property bool isChecked: true
    property bool isDisabled: false
    // 全选小节用
    property var plainOptions: ["Photography", "Movies", "Running"]
    property var picked: ["Photography", "Running"]

    readonly property bool allChecked: page.picked.length === page.plainOptions.length

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本用法"

            Column {
                spacing: 12

                Checkbox { text: "Semi Design" }

                Checkbox { text: "Semi Design"; defaultChecked: true }

                Column {
                    spacing: 12

                    Checkbox {
                        text: "Semi Design"
                        extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                    }

                    // 官方这一条给了 style={{ width: 280 }}，副文本会在 256 宽处折行
                    Checkbox {
                        width: 280
                        text: "Semi Design"
                        extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                    }
                }
            }
        }

        GallerySection {
            title: "禁用"

            Column {
                spacing: 12

                Checkbox { text: "Unchecked Disabled"; disabled: true }
                Checkbox { text: "Checked Disabled"; defaultChecked: true; disabled: true }
            }
        }

        GallerySection {
            title: "JSX方式声明Checkbox组"

            // 声明式：组里的每一项都要写 value，否则不算组内项（checkbox.tsx:181）
            CheckboxGroup {
                defaultValue: ["A", "B"]

                Checkbox { value: "A"; text: "A" }
                Checkbox { value: "B"; text: "B" }
                Checkbox { value: "C"; text: "C" }
                Checkbox { value: "D"; text: "D" }
                Checkbox { value: "E"; text: "E" }
            }
        }

        GallerySection {
            title: "数组方式声明 Checkbox 组"

            Column {
                spacing: 24

                CheckboxGroup {
                    options: ["Semi UI", "Semi DSM", "Semi D2C"]
                    defaultValue: ["Semi D2C"]
                }

                CheckboxGroup {
                    options: [
                        {
                            label: "Semi DSM",
                            value: "dsm",
                            extra: qsTr("从 Semi Design，到 Any Design 快速定制你的设计系统，并应用在设计稿和代码中")
                        },
                        {
                            label: "Semi D2C",
                            value: "d2c",
                            extra: qsTr("高效的 Design To Code 设计稿转代码")
                        }
                    ]
                }

                CheckboxGroup {
                    options: [
                        { label: "Photography", value: "Photography" },
                        { label: "Movies", value: "Movies" },
                        { label: "Running", value: "Running", disabled: false }
                    ]
                    defaultValue: ["Photography"]
                    disabled: true
                }
            }
        }

        GallerySection {
            title: "水平排列"

            CheckboxGroup {
                direction: Enums.DirectionHorizontal
                options: [{ label: "抖音", value: "abc" }, { label: "今日头条", value: "toutiao" }]
            }
        }

        GallerySection {
            title: "受控"

            Column {
                spacing: 20

                Checkbox {
                    id: controlled

                    text: (controlled.checked ? "Checked " : "Unchecked ")
                        + (page.isDisabled ? "Disabled" : "Enabled")
                    checked: page.isChecked
                    disabled: page.isDisabled
                    // 点一下时组件自己会写一次 checked，那一下就把上面的绑定冲掉了，
                    // 之后按钮改 page.isChecked 也传不进来，所以回调里把绑定装回去
                    // （与 SwitchPage 的受控小节同一处理）。
                    onToggled: {
                        page.isChecked = controlled.checked;
                        controlled.checked = Qt.binding(function () { return page.isChecked; });
                    }
                }

                Row {
                    spacing: 10

                    Button {
                        text: page.isChecked ? "Uncheck" : "Check"
                        size: Enums.Small
                        onClicked: page.isChecked = !page.isChecked
                    }

                    Button {
                        text: page.isDisabled ? "Enable" : "Disable"
                        size: Enums.Small
                        onClicked: page.isDisabled = !page.isDisabled
                    }
                }
            }
        }

        GallerySection {
            title: "全选"

            Column {
                spacing: 0

                // 官方这里是 paddingBottom 8 + 1px 下边框
                Column {
                    spacing: 8

                    Checkbox {
                        id: checkAll

                        text: "Check all"
                        checked: page.allChecked
                        indeterminate: page.picked.length > 0 && page.picked.length < page.plainOptions.length
                        onToggled: {
                            checkAll.checked = Qt.binding(function () { return page.allChecked; });
                            page.picked = page.allChecked ? [] : page.plainOptions.slice();
                        }
                    }
                }

                Rectangle {
                    width: 280
                    height: 1
                    color: Theme.current.colorBorder
                }

                // 官方组这里是 margin-top 6
                Item {
                    width: 1
                    height: 6
                }

                CheckboxGroup {
                    options: page.plainOptions
                    value: page.picked
                    onChanged: (checkedValue) => page.picked = checkedValue
                }
            }
        }

        GallerySection {
            title: "卡片样式"

            CheckboxGroup {
                type: Enums.ChoiceCard
                direction: Enums.DirectionVertical
                defaultValue: ["1", "3"]

                Checkbox {
                    width: 280
                    value: "1"
                    text: "单选框标题"
                    disabled: true
                    extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                }
                Checkbox {
                    width: 280
                    value: "2"
                    text: "单选框标题"
                    disabled: true
                    extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                }
                Checkbox {
                    width: 280
                    value: "3"
                    text: "单选框标题"
                    extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                }
                Checkbox {
                    width: 280
                    value: "4"
                    text: "单选框标题"
                    extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                }
            }
        }

        GallerySection {
            title: "无 checkbox 的纯卡片样式"

            CheckboxGroup {
                type: Enums.ChoicePureCard
                direction: Enums.DirectionVertical
                defaultValue: ["1", "3"]

                Checkbox {
                    width: 280
                    value: "1"
                    text: "单选框标题"
                    disabled: true
                    extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                }
                Checkbox {
                    width: 280
                    value: "2"
                    text: "单选框标题"
                    disabled: true
                    extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                }
                Checkbox {
                    width: 280
                    value: "3"
                    text: "单选框标题"
                    extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                }
                Checkbox {
                    width: 280
                    value: "4"
                    text: "单选框标题"
                    extra: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统")
                }
            }
        }

        GallerySection {
            title: "配合grid布局"

            CheckboxGroup {
                defaultValue: ["B", "D"]

                // 官方是 Row + 五个 span 8 的 Col（24 栏放不下第五个就换到第二行）。
                // Grid 家族已按「布局组件不复刻」的决定删除，这里用 QML 的 Row 等分栏、
                // 按官方的换行结果手动拆成 3 + 2。
                Row {
                    spacing: 0

                    Column { width: 160; Checkbox { value: "A"; text: "A" } }
                    Column { width: 160; Checkbox { value: "B"; text: "B" } }
                    Column { width: 160; Checkbox { value: "C"; text: "C" } }
                }

                Row {
                    spacing: 0

                    Column { width: 160; Checkbox { value: "D"; text: "D" } }
                    Column { width: 160; Checkbox { value: "E"; text: "E" } }
                }
            }
        }
    }
}
