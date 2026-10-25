pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Tooltip 工具提示。target 指向要挂的控件，trigger 决定它什么时候出现。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 触发时机那节的 custom 档：显隐完全由使用方说了算
    property bool customTipVisible: false
    component Note: Text {
        width: 620
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    // 官方「位置」那一节的 target 是 padding 20 的 Tag，实际就是一块 60 见方的格子
    component DemoTag: Tag {
        width: 60
        height: 60
        size: "large"
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 620
                text: "import Semi\n\n"
                    + "// 官方是拿 children 当 target；这边显式指过去，弹层自己声明在页面里\n"
                    + "Button { id: src; text: \"悬停我\" }\n"
                    + "Tooltip {\n"
                    + "    target: src\n"
                    + "    text: 'semi design'        // 富内容直接写子项，text 留空\n"
                    + "    position: Enums.TopLeft\n"
                    + "}"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "注意事项"

            Row {
                spacing: 16

                Tag {
                    id: fcTarget

                    text: "函数式组件"
                }

                Tag {
                    id: classTarget

                    text: "类组件"
                    color: "violet"
                }

                Rectangle {
                    id: domTarget

                    width: 88
                    height: 24
                    radius: 4
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.current.colorBorder

                    Text {
                        anchors.centerIn: parent
                        text: "原生节点"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }

                Tooltip {
                    id: firstTip

                    target: fcTarget
                    text: "semi design"
                }

                Tooltip {
                    target: classTarget
                    text: "semi design"
                }

                Tooltip {
                    target: domTarget
                    text: "semi design"
                }
            }

            Note {
                text: qsTr("官网这一节讲的是 React 那侧的前置条件：要把 children 的真实 DOM 节点拿到手，"
                    + "所以自定义组件必须 forwardRef 并把 props 透下去，span / div 这类原生节点才能直接包。"
                    + "本库用 target 直接指定控件，没有事件透传与 ref 这两步 —— "
                    + "任何 Item 都能当 target，包括上面那块自己画边框的原生 Rectangle。"
                    + "另外 QML 的 Item 没有 hovered 属性（那是 Controls 的 Control 才有），"
                    + "悬停是从 target 上挂的 HoverHandler 读的。")
            }
        }

        GallerySection {
            title: "位置"

            // 浮层会被夹在窗口范围内，上下都留出行高才谈得上「向上 / 向下弹出」
            Item {
                width: 1
                height: 72
            }

            Row {
                spacing: 8

                DemoTag {
                    id: posTopLeft

                    text: "TL"
                }

                DemoTag {
                    id: posTop

                    text: "Top"
                }

                DemoTag {
                    id: posTopRight

                    text: "TR"
                }
            }

            Item {
                width: 1
                height: 72
            }

            Row {
                spacing: 200

                Column {
                    spacing: 8

                    DemoTag {
                        id: posLeftTop

                        text: "LT"
                    }

                    DemoTag {
                        id: posLeft

                        text: "Left"
                    }

                    DemoTag {
                        id: posLeftBottom

                        text: "LB"
                    }
                }

                Column {
                    spacing: 8

                    DemoTag {
                        id: posRightTop

                        text: "RT"
                    }

                    DemoTag {
                        id: posRight

                        text: "Right"
                    }

                    DemoTag {
                        id: posRightBottom

                        text: "RB"
                    }
                }
            }

            Item {
                width: 1
                height: 72
            }

            Row {
                spacing: 8

                DemoTag {
                    id: posBottomLeft

                    text: "BL"
                }

                DemoTag {
                    id: posBottom

                    text: "Bottom"
                }

                DemoTag {
                    id: posBottomRight

                    text: "BR"
                }
            }

            Item {
                width: 1
                height: 72
            }

            // 官方这一节全部 arrowPointAtCenter={false}：卡片与 target 边缘对齐，
            // 小三角就偏到一边（跟下一节正好是同一组方位的两种做法）
            Tooltip {
                target: posTopLeft
                position: Enums.TopLeft
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posTop
                position: Enums.Top
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posTopRight
                position: Enums.TopRight
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posLeftTop
                position: Enums.LeftTop
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posLeft
                position: Enums.Left
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posLeftBottom
                position: Enums.LeftBottom
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posRightTop
                position: Enums.RightTop
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posRight
                position: Enums.Right
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posRightBottom
                position: Enums.RightBottom
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posBottomLeft
                position: Enums.BottomLeft
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posBottom
                position: Enums.Bottom
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Tooltip {
                target: posBottomRight
                position: Enums.BottomRight
                arrowPointAtCenter: false

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "hi bytedance"

                    color: Theme.current.colorBg0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Note {
                text: qsTr("position 就是官方那 12 个字符串值（top / topLeft / topRight / left / leftTop / "
                    + "leftBottom / right / rightTop / rightBottom / bottom / bottomLeft / bottomRight），"
                    + "缺省 top。这一节全用 arrowPointAtCenter=false：卡片与 target 边缘对齐，"
                    + "小三角因此偏到一边。官方 constants.ts 的 POSITION_SET 另有四个 *Over 值"
                    + "（leftTopOver 等），只在 story 里出现、文档 API 表没写，本库的枚举里也没有。"
                    + "内容那两行走的是 children 档（官方是 content 收 <article><p>）。")
            }
        }

        GallerySection {
            title: "指向元素中心"

            Column {
                spacing: 24

                Row {
                    spacing: 8

                    Button {
                        id: centerTarget

                        text: "指向元素中心"
                        tone: Enums.Secondary
                    }

                    Tooltip {
                        id: centerTip

                        target: centerTarget
                        text: "semi design tooltip"
                        position: Enums.TopLeft
                    }
                }

                Row {
                    spacing: 8

                    Button {
                        id: edgeTarget

                        text: "边缘对齐"
                        tone: Enums.Secondary
                        width: 120
                    }

                    Tooltip {
                        target: edgeTarget
                        text: "semi design tooltip"
                        position: Enums.TopLeft
                        arrowPointAtCenter: false
                    }
                }
            }

            Note {
                text: qsTr("默认 arrowPointAtCenter=true：角落方位时卡片会沿交叉轴平移，"
                    + "让那颗离边 18px 的小三角（$spacing-tooltip_arrow_adjusted_offset-x = "
                    + "round(0.24×24) = 6，再加半个箭头宽 12）正好落在 target 的中心上；"
                    + "设成 false 就退回边缘对齐，三角仍待在离边 18px 的位置，于是指向 target 左边 18px 那里。"
                    + "中间方位（top / bottom / left / right）卡片本来就横竖居中，两个取值一般看不出差别；"
                    + "只有卡片被容器边界夹过（target 贴着边）时才有分别：开着时三角跟着 target 中心并夹在卡片内，"
                    + "关掉时它留在几何中心。")
            }
        }

        GallerySection {
            title: "触发时机"

            Column {
                spacing: 20

                Row {
                    spacing: 16

                    Button {
                        id: hoverTarget

                        text: "悬停显示"
                        variant: Enums.Solid
                        tone: Enums.Tertiary
                    }

                    Button {
                        id: clickTarget

                        text: "点击显示"
                        variant: Enums.Light
                    }

                    Input {
                        id: focusTarget

                        width: 140
                        placeholderText: "聚焦显示"
                    }

                    Button {
                        id: menuTarget

                        text: "右键展示"
                        variant: Enums.Solid
                        tone: Enums.Secondary
                    }
                }

                Row {
                    spacing: 16

                    RadioGroup {
                        type: Enums.ChoiceButton
                        value: page.customTipVisible
                        onChanged: (v) => page.customTipVisible = (v === true)

                        Radio {
                            value: true
                            text: "受控显示"
                        }

                        Radio {
                            value: false
                            text: "受控隐藏"
                        }
                    }
                }

                Tooltip {
                    id: hoverTip

                    target: hoverTarget
                    text: "hi bytedance"
                }

                Tooltip {
                    id: clickTip

                    target: clickTarget
                    text: "hi bytedance"
                    trigger: "click"
                }

                Tooltip {
                    target: focusTarget
                    text: "hi bytedance"
                    trigger: "focus"
                }

                Tooltip {
                    target: menuTarget
                    text: "hi bytedance"
                    trigger: "contextMenu"
                }

                // custom：不绑任何动作，显隐只看 visible
                Tooltip {
                    id: customTip

                    target: hoverTarget
                    text: "hi bytedance"
                    trigger: "custom"
                    visible: page.customTipVisible
                }
            }

            Note {
                text: qsTr("trigger 五档：hover / focus / click / custom / contextMenu（缺省 hover）。"
                    + "click 与 contextMenu 只有 show()，**不是开关** —— 已开着再点 target 还是开，"
                    + "要关就点 target 与卡片之外的任意处（这一档才发 clickedOutside）。"
                    + "hover 档官方另外还绑了一对 focus/blur（无障碍用），"
                    + "disableFocusListener 只关这一对，focus 档自己不受它影响。"
                    + "custom 档什么都不绑，condition 对它也无效。"
                    + "延迟是 mouseEnterDelay / mouseLeaveDelay，官方都缺省 50ms；"
                    + "卡片本身也算「还悬停着」，鼠标从 target 挪进提示里不会消失。")
            }
        }

        GallerySection {
            title: "condition 条件触发"

            Row {
                spacing: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "condition"
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Switch {
                    id: conditionSwitch

                    anchors.verticalCenter: parent.verticalCenter
                    checked: true
                }

                Button {
                    id: condHoverTarget

                    text: "Hover me"
                }

                Button {
                    id: condClickTarget

                    text: "Click me"
                    variant: Enums.Light
                }

                Tooltip {
                    target: condHoverTarget
                    text: conditionSwitch.checked ? "condition is true" : "condition is false"
                    condition: conditionSwitch.checked
                }

                Tooltip {
                    target: condClickTarget
                    text: conditionSwitch.checked ? "condition is true" : "condition is false"
                    trigger: "click"
                    condition: conditionSwitch.checked
                }
            }

            Note {
                text: qsTr("condition=false 时 hover / focus / click / contextMenu 四种触发作废，"
                    + "custom 档不受影响（官方文档原话）。注意它只挡「显示」那几条路径："
                    + "已经弹出的那一层照样会按 mouseLeaveDelay 自己收掉，"
                    + "把 condition 关掉时正在看的那条提示不会立刻消失。")
            }
        }

        GallerySection {
            title: "覆盖特定样式"

            Row {
                spacing: 16

                Tag {
                    id: clampTarget

                    text: "Custom Style And ClassName"
                }

                Tag {
                    id: widenTarget

                    text: "maxWidth: 320"
                    color: "violet"
                }

                Tooltip {
                    target: clampTarget
                    text: "hi semi semi semi semi semi semi semi"
                }

                Tooltip {
                    id: wideTip

                    target: widenTarget
                    text: "hi semi semi semi semi semi semi semi"
                    maxWidth: 320
                    position: Enums.Bottom
                }
            }

            Note {
                text: qsTr("官方这一节是用 className / style 覆盖缺省值，举的例子就是那条 max-width: 240。"
                    + "本库把它做成一条属性：maxWidth（$width-tooltip，含左右 12 内边距的那一档），"
                    + "比它窄的内容照内容宽、比它宽的内容换行（overflow-wrap: break-word）。"
                    + "颜色没有走 style，直接给 fillColor / strokeColor；"
                    + "className / prefixCls / wrapperClassName 这些 DOM 侧的东西没有对应落点。")
            }
        }

        GallerySection {
            title: "渲染至指定 DOM"

            Rectangle {
                id: tipContainer

                width: 420
                height: 200
                radius: Theme.current.radiusMedium
                color: Theme.current.colorBg1
                border.width: 1
                border.color: Theme.current.colorBorder

                Tag {
                    id: containerTarget

                    x: 160
                    y: 88
                    width: 100
                    height: 24
                    text: "点击此处"
                }

                Text {
                    x: 12
                    y: 12
                    text: "#tooltip-wrapper（容器）"
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Tooltip {
                    id: containerTip

                    target: containerTarget
                    text: "浮层被渲染至#tooltip-wrapper元素中"
                    trigger: "click"
                    position: Enums.Right
                    container: tipContainer
                }
            }

            Note {
                text: qsTr("官方 getPopupContainer 换的是 portal 挂在哪颗 DOM 上，"
                    + "并要求自定义容器自己写 position: relative（否则绝对定位找不到参照）。"
                    + "本库 container 直接就是浮层的 parent，位置与翻面判定都按它的坐标系算 —— "
                    + "上面那颗标签的提示向右展开，被夹的范围就是这个 420×200 的框。")
            }
        }

        GallerySection {
            title: "搭配 Popover 或 Popconfirm 使用"

            Row {
                spacing: 16

                Button {
                    id: bothTarget

                    text: "删除"
                    tone: Enums.Danger
                }

                Tooltip {
                    target: bothTarget
                    text: "删除评价"
                }

                Popconfirm {
                    anchor: bothTarget
                    title: "确认"
                    description: "是否确认删除"
                }
            }

            Note {
                text: qsTr("官网这节的结论是「要在中间加一层 div / span」：React 里 Tooltip、Popover、"
                    + "Popconfirm 都要劫持 children 的 onMouseEnter / onClick，直接嵌套时外层那份 props "
                    + "被子组件吃掉，trigger 就失效了。QML 侧没有这件事：三个组件都各自往 anchor 上挂 "
                    + "handler，谁也不覆盖谁（实测同一颗 target 上的多个 TapHandler 都能收到 tapped，"
                    + "qquicktaphandler.cpp:70 的 wantsEventPoint 没有同 parent 让路那套），"
                    + "所以这里 tooltip 与 popconfirm 直接挂在同一颗按钮上，不用中间层。")
            }
        }

        GallerySection {
            title: "仅当内容宽度超出时展示 Tooltip"

            Column {
                spacing: 16

                Title {
                    heading: 5
                    width: 250
                    text: "是一个很长很长很长很长5号标题"
                    ellipsis: ({ showTooltip: true })
                }

                TextLabel {
                    width: 150
                    link: true
                    text: "是一个很长很长很长很长的链接"
                    ellipsis: ({ showTooltip: true, pos: "middle" })
                }

                Paragraph {
                    width: 300
                    text: "多行截断：Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统。"
                        + "设计系统包含设计语言以及一整套可复用的前端组件，帮助设计师与开发者更容易地"
                        + "打造高质量的、用户体验一致的、符合设计规范的 Web 应用。"
                    ellipsis: ({ rows: 3, showTooltip: true })
                }
            }

            Note {
                text: qsTr("官方这一节其实没用 Tooltip 的属性 —— 它推荐直接用 Typography 的 "
                    + "ellipsis.showTooltip，组件自己判「真的截断了没有」，只在超出时弹全文。"
                    + "本库的 Title / TextLabel / Paragraph 里已经是同一做法（TypographyBase 里那条 "
                    + "ellipsisTooltip 同时看 ellipsis 开关与 truncated 结果）。"
                    + "差别只在官方 showTooltip 还收 { type: 'popover', opts: ... } 这第二档"
                    + "（多行省略时弹一张 Popover），本库只落了 tooltip 那一档。")
            }
        }
    }

    // 截图模式（--shot）下把几档代表性外观打开，否则抓不到浮层本体
    Component.onCompleted: {
        if (Qt.application.arguments.indexOf("--shot") < 0)
            return;
        firstTip.open();
        centerTip.open();
        wideTip.open();
    }
}
