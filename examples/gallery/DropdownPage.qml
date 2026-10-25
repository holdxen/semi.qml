pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Dropdown 下拉菜单。官方 `content/show/dropdown/index.md` 的「代码演示」一共 7 个小节，
// 这里逐节摆齐：如何引入 / 基本用法 / 嵌套使用 / 弹出位置 / 触发方式 / 触发事件 / Json 用法
// （`###` 一共 12 个，余下 5 个是 Dropdown / Dropdown.Menu / Dropdown.Item / Dropdown.Title /
// DropdownMenuItem 那几张 API 表，不进 demo；ARIA 那节也不摆）。
//
// 端口与官方的三处口径差（各自写在节内说明里）：
//   · 官方 `render` 收的是 `<Dropdown.Menu>…</Dropdown.Menu>` 这棵 React 树；QML 没有这个位置，
//     端口的「render 档」就是**声明式子项**（与 Popover 的 content 同一口径），
//     `Dropdown.Menu` 那一层由组件自己的内容列顶替（`.semi-dropdown-menu` 的 padding 已经吃在
//     卡片上）。
//   · 官方 trigger 是 children（它替被包裹的那件合并事件与 ref）；端口和 Tooltip / Popover 一样
//     改成显式 `target`。
//   · 基本用法那节右侧的快捷键提示官方用 `<HotKeys hotKeys={[Control, B]} content={['Ctrl','B']}>`，
//     端口的 HotKeys 只渲染键帽，位置自己用 marginLeft 顶。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // custom 档：显隐归调用方，官方那节也是自己拿一个 state 控
    property bool customOpen: false

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Column {
                width: 700
                spacing: 10

                Text {
                    text: "import { Dropdown } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("组件挂在 Tooltip 上（官方 render 就是把一切转交 Tooltip），所以 trigger 五档、"
                        + "position 十二档、点外关闭、Esc、进出场这些语义和 Tooltip / Popover 完全一致。"
                        + "Dropdown 这一档改掉的是：position 缺省 bottom、zIndex 1050、mouseLeaveDelay 100、"
                        + "closeOnEsc true、showArrow 恒 false、间距外层 4 嵌套 2，另外多了 menu / showTick 两条。")
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 700
                spacing: 12

                Row {
                    spacing: 16

                    Button {
                        id: basicTrigger

                        objectName: "basicTrigger"

                        text: qsTr("Hover Me")
                        icon: "box"
                        variant: Enums.Outline
                        tone: Enums.Tertiary
                    }

                    Dropdown {
                        target: basicTrigger
                        position: Enums.BottomLeft

                        DropdownTitle { text: qsTr("分组1") }

                        DropdownItem {
                            text: "Menu Item 1"
                            icon: "box"

                            // 官方 children 是 flex 的最后一格、行内排在文字后（marginLeft 20）
                            HotKeys {
                                keys: ["Ctrl", "B"]
                            }
                        }

                        DropdownItem {
                            text: "Menu Item 2"
                            icon: "setting"

                            // 官方 children 是 flex 的最后一格、行内排在文字后（marginLeft 20）
                            HotKeys {
                                keys: ["Ctrl", "V"]
                            }
                        }

                        DropdownItem {
                            text: "Menu Item 3"
                            icon: "forward"
                            disabled: true

                            // 官方 children 是 flex 的最后一格、行内排在文字后（marginLeft 20）
                            HotKeys {
                                keys: ["Ctrl", "F3"]
                            }
                        }

                        DropdownDivider {}

                        DropdownTitle { text: qsTr("分组2") }

                        DropdownItem { text: "tertiary"; type: "tertiary"; icon: "refresh" }

                        DropdownItem { text: "warning"; type: "warning"; icon: "search" }

                        DropdownItem { text: "danger"; type: "danger"; icon: "alert_circle" }
                    }
                }

                Note {
                    text: qsTr("一条菜单项高 36（上下内边距各 8 + 行高 20），条目之间没有间距。"
                        + "`type` 五档只换字色；API 表里写它缺省 `tertiary` 是官网写错的 —— 官方 "
                        + "defaultProps 里没有这一条，不传就是 text-0。`disabled` 那条不仅变灰，"
                        + "四个鼠标回调也都不挂（官方 :85-96）。")
                }
            }
        }

        GallerySection {
            title: "嵌套使用"

            Column {
                width: 700
                spacing: 12

                Row {
                    spacing: 16

                    Button {
                        id: nestedTrigger

                        text: qsTr("Hover Me")
                        icon: "box"
                        variant: Enums.Outline
                        tone: Enums.Tertiary
                    }

                    Dropdown {
                        id: outerMenu

                        target: nestedTrigger
                        position: Enums.BottomLeft

                        DropdownItem {
                            id: subA

                            text: "Menu Item 1"
                        }

                        Dropdown {
                            target: subA
                            position: Enums.RightTop

                            DropdownItem { text: "Nested Menu Item 1" }
                            DropdownItem { text: "Nested Menu Item 2" }
                        }

                        DropdownItem {
                            id: subB

                            text: "Menu Item 2"
                        }

                        Dropdown {
                            target: subB
                            position: Enums.LeftTop

                            DropdownItem { text: "Nested Menu Item 1" }
                            DropdownItem { text: "Nested Menu Item 2" }
                        }

                        DropdownItem { text: "Menu Item 3" }
                    }
                }

                Note {
                    text: qsTr("内层的 trigger 就是外层的一条菜单项 ⇒ 它认得出自己多了一层："
                        + "spacing 从 4 变 2（官方 numbers.NESTED_SPACING），而且这一层的条目"
                        + "官方把 `onClick` 换成了 `onMouseDown`（只认左键，:86-93）—— 端口照抄。"
                        + "内层弹层是独立的一层，不和外层共用键盘名单。")
                }
            }
        }

        GallerySection {
            title: "弹出位置"

            Column {
                width: 700
                spacing: 20

                Row {
                    spacing: 24

                    Repeater {
                        model: [
                            { pos: Enums.Bottom, label: "Bottom" },
                            { pos: Enums.BottomLeft, label: "BottomLeft" },
                            { pos: Enums.BottomRight, label: "BottomRight" }
                        ]

                        delegate: Row {
                            id: cell

                            required property var modelData

                            spacing: 12

                            Tag {
                                id: cellTag

                                text: cell.modelData.label
                            }

                            Dropdown {
                                target: cellTag
                                position: cell.modelData.pos

                                DropdownItem { text: "Menu Item 1" }
                                DropdownItem { text: "Menu Item 2" }
                                DropdownItem { text: "Menu Item 3" }
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("可选的十二档同 Tooltip（官方那句「支持的位置同 Tooltip」）。"
                        + "常用的是 bottom / bottomLeft / bottomRight 这三档，缺省就是 bottom。")
                }
            }
        }

        GallerySection {
            title: "触发方式"

            Column {
                width: 700
                spacing: 20

                Row {
                    spacing: 24

                    Tag {
                        id: hoverTag

                        text: qsTr("Hover me")
                    }

                    Dropdown {
                        target: hoverTag
                        trigger: "hover"
                        position: Enums.BottomLeft

                        DropdownItem { text: "Menu Item 1" }
                        DropdownItem { text: "Menu Item 2" }
                    }

                    Rectangle {
                        id: focusBox

                        width: 220
                        height: 36
                        radius: 4
                        color: Theme.current.colorBg0
                        border.width: 1
                        border.color: Theme.current.colorBorder
                        focusPolicy: Qt.StrongFocus

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("用 Tab 把焦点移进来")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }
                    }

                    Dropdown {
                        target: focusBox
                        trigger: "focus"
                        position: Enums.BottomLeft

                        DropdownItem { text: "Menu Item 1" }
                        DropdownItem { text: "Menu Item 2" }
                    }
                }

                Row {
                    spacing: 24

                    Button {
                        id: clickTag

                        text: qsTr("Click me")
                        variant: Enums.Outline
                        tone: Enums.Tertiary
                    }

                    Dropdown {
                        target: clickTag
                        trigger: "click"
                        position: Enums.BottomLeft

                        DropdownItem { text: "Menu Item 1" }
                        DropdownItem { text: "Menu Item 2" }
                    }

                    Button {
                        id: customTag

                        text: qsTr("Custom")
                        variant: Enums.Outline
                        tone: Enums.Tertiary
                    }

                    Dropdown {
                        id: customMenu

                        target: customTag
                        trigger: "custom"
                        visible: page.customOpen
                        position: Enums.BottomLeft

                        DropdownItem { text: "Menu Item 1" }
                        DropdownItem { text: "Menu Item 2" }
                    }

                    Button {
                        id: customSwitch

                        text: qsTr("受控开合")
                        variant: Enums.Outline
                        tone: Enums.Tertiary
                        onClicked: page.customOpen = !page.customOpen
                    }
                }

                Row {
                    spacing: 24

                    Rectangle {
                        id: ctxBox

                        width: 220
                        height: 36
                        radius: 4
                        color: Theme.current.colorBg0
                        border.width: 1
                        border.color: Theme.current.colorBorder

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("在我这里点右键")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }
                    }

                    Dropdown {
                        target: ctxBox
                        trigger: "contextMenu"
                        position: Enums.BottomLeft

                        DropdownItem { text: "Menu Item 1" }
                        DropdownItem { text: "Menu Item 2" }
                    }
                }

                Note {
                    text: qsTr("五档：hover（缺省）/ focus / click / custom / contextMenu（v2.42 起）。"
                        + "custom 档显隐完全归调用方 —— 这里挂在一枚 Switch 上；那一档下 Esc 只发信号不关层。"
                        + "click 档打开时官方会把焦点送进第一条菜单项（foundation.ts:18-21），"
                        + "于是紧接着就能用上下键、回车、首字母跳。")
                }
            }
        }

        GallerySection {
            title: "触发事件"

            Column {
                width: 700
                spacing: 12

                Toast { id: toasts }

                Row {
                    spacing: 16

                    Button {
                        id: eventTrigger

                        text: qsTr("Click Me")
                        icon: "box"
                        variant: Enums.Outline
                        tone: Enums.Tertiary
                    }

                    Dropdown {
                        target: eventTrigger
                        trigger: "click"
                        position: Enums.BottomLeft

                        DropdownItem {
                            text: "1: click me!"
                            onClicked: toasts.info({ content: "You clicked me!" })
                        }

                        DropdownItem {
                            text: "2: mouse enter"
                            onMouseEntered: toasts.info({ content: "Nice to meet you!" })
                        }

                        DropdownItem {
                            text: "3: mouse leave"
                            onMouseLeft: toasts.info({ content: "See ya!" })
                        }

                        DropdownItem {
                            text: "4: right click"
                            onContextMenu: toasts.info({ content: "Right clicked!" })
                        }
                    }
                }

                Note {
                    text: qsTr("四个回调都只在非禁用时挂。端口把官方 `onContextMenu` 那条信号叫 "
                        + "`contextMenu`（`onContextMenu` 这个名字在 Item 上没被占，但端口的信号一律不带 on 前缀）。")
                }
            }
        }

        GallerySection {
            title: "Json 用法"

            Column {
                width: 700
                spacing: 12

                Row {
                    spacing: 16

                    Button {
                        id: jsonTrigger

                        text: qsTr("Hover Me")
                        icon: "box"
                        variant: Enums.Outline
                        tone: Enums.Tertiary
                    }

                    Dropdown {
                        target: jsonTrigger
                        position: Enums.BottomLeft
                        menu: [
                            { node: "title", name: "分组1" },
                            { node: "item", name: "primary1", type: "primary" },
                            { node: "item", name: "secondary", type: "secondary" },
                            { node: "divider" },
                            { node: "title", name: "分组2" },
                            { node: "item", name: "tertiary", type: "tertiary" },
                            { node: "item", name: "warning", type: "warning", active: true },
                            { node: "item", name: "danger", type: "danger", disabled: true }
                        ]
                    }
                }

                Note {
                    text: qsTr("`menu` 收 `{ node, name, ...条目 props }` 数组，node 三档 item / title / divider，"
                        + "认不出来那一档官方返回 null ⇒ 什么都不画。判据是「先 render 再 menu」："
                        + "端口就是「有声明式子项就不看 menu」。")
                }
            }
        }
    }

    // 说明里会出现 `<Dropdown.Menu>` / `{...}` 这类尖括号，AutoText 会把它们当标签吃掉 ⇒ 钉 PlainText
    component Note: Text {
        width: 700
        textFormat: Text.PlainText
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
