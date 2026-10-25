pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 官方示例：content/basic/button/index.md（11 个小节，标题与 docs.json 一致）
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ---- 加载状态那节的受控开关 ----
    property bool saveLoading: false
    property bool delLoading: true
    property bool repLoading: true

    function resetLoading(on) {
        page.saveLoading = on;
        page.delLoading = on;
        page.repLoading = on;
    }

    // 多彩按钮 demo 的四行：官方每行按 theme 换一次图标等级（IconAIFilledLevel1/2/3）
    readonly property var colorfulRows: [
        { variant: Enums.Solid, primaryIcon: "ai_filled_level_1", tertiaryIcon: "ai_filled_level_3" },
        { variant: Enums.Light, primaryIcon: "ai_filled_level_3", tertiaryIcon: "ai_filled_level_2" },
        { variant: Enums.Outline, primaryIcon: "ai_filled_level_1", tertiaryIcon: "ai_filled_level_2" },
        { variant: Enums.Borderless, primaryIcon: "ai_filled_level_3", tertiaryIcon: "ai_filled_level_2" }
    ]

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "按钮类型"

            Row {
                spacing: Theme.current.spacingBaseTight

                Button { text: qsTr("主要按钮") }
                Button { text: qsTr("次要按钮"); tone: Enums.Secondary }
                Button { text: qsTr("第三按钮"); tone: Enums.Tertiary }
                Button { text: qsTr("警告按钮"); tone: Enums.Warning }
                Button { text: qsTr("危险按钮"); tone: Enums.Danger }
            }

            // 「关于类型字体色值」那一小段：官方直接用 --semi-color-* 给五个 strong 上色
            Row {
                spacing: Theme.current.spacingBaseTight

                Repeater {
                    model: [
                        { label: qsTr("主要"), color: Theme.current.colorPrimary },
                        { label: qsTr("次要"), color: Theme.current.colorSecondary },
                        { label: qsTr("第三"), color: Theme.current.colorTertiary },
                        { label: qsTr("警告"), color: Theme.current.colorWarning },
                        { label: qsTr("危险"), color: Theme.current.colorDanger }
                    ]

                    delegate: Text {
                        required property var modelData

                        text: modelData.label
                        color: modelData.color
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.Bold
                    }
                }
            }
        }

        GallerySection {
            title: "按钮主题"

            Column {
                spacing: Theme.current.spacingBaseTight

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Repeater {
                        model: [qsTr("浅色主要"), qsTr("浅色次要"), qsTr("浅色第三"), qsTr("浅色警告"), qsTr("浅色危险")]

                        delegate: Button {
                            required property int index
                            required property var modelData

                            text: modelData
                            variant: Enums.Light
                            tone: page.toneAt(index)
                        }
                    }
                }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Repeater {
                        model: [qsTr("深色主要"), qsTr("深色次要"), qsTr("深色第三"), qsTr("深色警告"), qsTr("深色危险")]

                        delegate: Button {
                            required property int index
                            required property var modelData

                            text: modelData
                            variant: Enums.Solid
                            tone: page.toneAt(index)
                        }
                    }
                }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Repeater {
                        model: [qsTr("主要"), qsTr("次要"), qsTr("第三"), qsTr("警告"), qsTr("危险")]

                        delegate: Button {
                            required property int index
                            required property var modelData

                            text: modelData
                            variant: Enums.Borderless
                            tone: page.toneAt(index)
                        }
                    }
                }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Repeater {
                        model: [qsTr("主要"), qsTr("次要"), qsTr("第三"), qsTr("警告"), qsTr("危险")]

                        delegate: Button {
                            required property int index
                            required property var modelData

                            text: modelData
                            variant: Enums.Outline
                            tone: page.toneAt(index)
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "尺寸"

            Row {
                spacing: Theme.current.spacingBaseTight

                Button { text: qsTr("大尺寸"); size: Enums.Large }
                Button { text: qsTr("默认尺寸"); size: Enums.Default }
                Button { text: qsTr("小尺寸"); size: Enums.Small }
            }
        }

        GallerySection {
            title: "块级按钮"

            Button {
                text: qsTr("块级按钮")
                block: true
            }
        }

        GallerySection {
            title: "图标按钮"

            Column {
                spacing: Theme.current.spacingBaseTight

                TextLabel { text: qsTr("默认状态："); strong: true }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Button { icon: "camera"; ariaLabel: qsTr("截屏") }
                }

                TextLabel { text: qsTr("禁用状态："); strong: true }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Button { icon: "camera"; ariaLabel: qsTr("截屏"); enabled: false }
                }

                TextLabel { text: qsTr("复合类型："); strong: true }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Repeater {
                        model: [Enums.Primary, Enums.Secondary, Enums.Warning, Enums.Danger]

                        delegate: Button {
                            required property var modelData

                            icon: "camera"
                            ariaLabel: qsTr("截屏")
                            tone: modelData
                        }
                    }
                }

                TextLabel { text: qsTr("更改主题："); strong: true }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Button { icon: "camera"; ariaLabel: qsTr("截屏"); variant: Enums.Solid }
                    Button { icon: "camera"; ariaLabel: qsTr("截屏"); variant: Enums.Light }
                }

                TextLabel { text: qsTr("更改图标位置："); strong: true }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Button { text: qsTr("收起"); icon: "sidebar"; variant: Enums.Solid }
                    Button { text: qsTr("展开选项"); icon: "chevron_down"; variant: Enums.Solid; iconPosition: "right" }
                }
            }
        }

        GallerySection {
            title: "链接按钮"

            // 官方这一节推荐用 Typography 的 link，不是 Button
            Column {
                spacing: Theme.current.spacingBase

                TextLabel { text: qsTr("链接文本"); link: true }

                TextLabel { text: qsTr("打开网站"); link: true }

                TextLabel { text: qsTr("带下划线的网页链接"); link: true; underline: true; icon: "link" }
            }
        }

        GallerySection {
            title: "禁用状态"

            Row {
                spacing: Theme.current.spacingBaseTight

                Button { text: qsTr("禁用"); enabled: false }
                Button { text: qsTr("无背景禁用"); variant: Enums.Borderless; enabled: false }
                Button { text: qsTr("浅色禁用"); variant: Enums.Light; enabled: false }
                Button { text: qsTr("无背景主要禁用"); variant: Enums.Borderless; tone: Enums.Primary; enabled: false }
                Button { text: qsTr("深色警告禁用"); variant: Enums.Solid; tone: Enums.Warning; enabled: false }
            }
        }

        GallerySection {
            title: "加载状态"

            Column {
                spacing: Theme.current.spacingBaseTight

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Button { text: qsTr("关闭加载态"); onClicked: page.resetLoading(false) }
                    Button { text: qsTr("开启加载态"); onClicked: page.resetLoading(true) }
                }

                Divider {}

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Button {
                        text: qsTr("保存")
                        loading: page.saveLoading
                        onClicked: page.saveLoading = true
                    }

                    Button {
                        text: qsTr("删除")
                        icon: "delete"
                        tone: Enums.Danger
                        loading: page.delLoading
                        onClicked: page.delLoading = true
                    }

                    // 官方把这支放进一个 width:200 的 div 里，block 才有参照宽度
                    Item {
                        width: 200
                        height: Appearance.buttonHeight(Theme.current, Enums.Default)

                        Button {
                            text: qsTr("撤销")
                            tone: Enums.Warning
                            variant: Enums.Solid
                            block: true
                            loading: page.repLoading
                            onClicked: page.repLoading = true
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "AI 风格 - 多彩按钮"

            Column {
                spacing: Theme.current.spacingBase

                Repeater {
                    // 官方把同一张网格渲染两遍：一遍带文案，一遍 children 传 undefined
                    // （于是 primary 那三支变成只剩图标的方形按钮）
                    model: [qsTr("Colorful"), ""]

                    delegate: Column {
                        id: textBlock

                        required property var modelData

                        spacing: Theme.current.spacingBase

                        Repeater {
                            model: page.colorfulRows

                            delegate: Row {
                                id: themeRow

                                required property var modelData

                                spacing: Theme.current.spacingBase

                                Repeater {
                                    // 每行六支：primary 的「图标 / 加载 / 图标+禁用」
                                    // 再接 tertiary 的同样三支
                                    model: 6

                                    delegate: Button {
                                        required property int index

                                        readonly property bool tertiary: index >= 3
                                        readonly property bool busy: index === 1 || index === 4
                                        readonly property var row: themeRow.modelData

                                        text: textBlock.modelData
                                        colorful: true
                                        variant: row.variant
                                        tone: tertiary ? Enums.Tertiary : Enums.Primary
                                        loading: busy
                                        enabled: index !== 2 && index !== 5
                                        icon: busy ? ""
                                            : (tertiary ? row.tertiaryIcon : row.primaryIcon)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "按钮组合"

            Column {
                spacing: Theme.current.spacingBase

                TextLabel { text: qsTr("组合尺寸"); strong: true }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Repeater {
                        model: [Enums.Large, Enums.Default, Enums.Small]

                        delegate: ButtonGroup {
                            required property var modelData

                            size: modelData

                            Button { text: qsTr("拷贝") }
                            Button { text: qsTr("查询") }
                            Button { text: qsTr("剪切") }
                        }
                    }
                }

                TextLabel { text: qsTr("组合禁用"); strong: true }

                ButtonGroup {
                    disabled: true

                    Button { text: qsTr("拷贝") }
                    Button { text: qsTr("查询") }
                    Button { text: qsTr("剪切") }
                }

                TextLabel { text: qsTr("组合类型"); strong: true }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Repeater {
                        model: [Enums.Primary, Enums.Secondary, Enums.Tertiary, Enums.Warning, Enums.Danger]

                        delegate: ButtonGroup {
                            required property var modelData

                            tone: modelData

                            Button { text: qsTr("拷贝") }
                            Button { text: qsTr("查询") }
                            Button { text: qsTr("剪切") }
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "分裂按钮组合"

            Row {
                spacing: Theme.current.spacingBaseTight

                Repeater {
                    model: [Enums.Solid, Enums.Light, Enums.Borderless]

                    delegate: Item {
                        id: splitCell

                        required property int index
                        required property var modelData

                        readonly property real cellWidth: group.implicitWidth
                        readonly property real cellHeight: group.implicitHeight
                        implicitWidth: cellWidth
                        implicitHeight: cellHeight

                        SplitButtonGroup {
                            id: group

                            Button {
                                text: qsTr("分裂按钮")
                                variant: splitCell.modelData
                                tone: Enums.Primary
                            }

                            Button {
                                id: trigger

                                icon: "tree_triangle_down"
                                variant: splitCell.modelData
                                tone: Enums.Primary
                                ariaLabel: qsTr("更多操作")
                            }
                        }

                        Dropdown {
                            id: menu

                            target: trigger
                            trigger: "click"
                            position: Enums.BottomRight

                            DropdownItem { text: qsTr("编辑项目"); onClicked: menu.hideNow() }
                            DropdownItem { text: qsTr("重置项目"); onClicked: menu.hideNow() }
                            DropdownDivider {}
                            DropdownItem { text: qsTr("复制项目"); onClicked: menu.hideNow() }
                            DropdownItem { text: qsTr("从项目创建模版"); onClicked: menu.hideNow() }
                            DropdownDivider {}
                            DropdownItem { text: qsTr("删除项目"); type: "danger"
                                onClicked: menu.hideNow() }
                        }
                    }
                }
            }
        }
    }

    // Repeater 的下标转成 Enums 里的色调，省掉五行重复的 delegate
    function toneAt(index) {
        return [Enums.Primary, Enums.Secondary, Enums.Tertiary, Enums.Warning, Enums.Danger][index];
    }
}
