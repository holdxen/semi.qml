pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Popover 气泡卡片。浮层的触发器用 target 指过去，内容直接写子项（官方那层 content
// 的 ReactNode / 函数两档，这里就是「子项」与「text 字符串」两条）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方「受控显示」用 RadioGroup 当触发器，选中的值直接喂 visible
    property bool controlledVisible: false

    // 官方这三节都是 tops / lefts / rights / bottoms 四个三元组 .map() 出来的，
    // 这里同一份模型交给 Repeater
    readonly property var posTops: [
        ({ label: "TL", placement: Enums.TopLeft }),
        ({ label: "Top", placement: Enums.Top }),
        ({ label: "TR", placement: Enums.TopRight })
    ]
    readonly property var posLefts: [
        ({ label: "LT", placement: Enums.LeftTop }),
        ({ label: "Left", placement: Enums.Left }),
        ({ label: "LB", placement: Enums.LeftBottom })
    ]
    readonly property var posRights: [
        ({ label: "RT", placement: Enums.RightTop }),
        ({ label: "Right", placement: Enums.Right }),
        ({ label: "RB", placement: Enums.RightBottom })
    ]
    readonly property var posBottoms: [
        ({ label: "BL", placement: Enums.BottomLeft }),
        ({ label: "Bottom", placement: Enums.Bottom }),
        ({ label: "BR", placement: Enums.BottomRight })
    ]

    component Note: Text {
        width: 560
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    // 官方「基本使用 / 弹出位置 / 注意事项」三节的浮层内容是同一张 <Empty>：
    // 标题 + 150×150 插画 + 描述，外面再套 style={{ width: 400, padding: 20 }}。
    // 这张卡是 Empty 还没 `title` / `image` 那档时手摆的，留着没换 —— 换成 `Empty` 会改动
    // 这一页所有浮层的尺寸，那属于 Popover 那页自己的复核，不在 Empty 这轮里做。
    component PopCard: Column {
        id: card

        width: 400
        padding: 20
        spacing: Theme.current.spacingTight

        property string title: ""
        property string description: ""

        Text {
            visible: card.title !== ""
            text: card.title
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Font.DemiBold
        }

        Rectangle {
            width: 150
            height: 150
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Theme.current.radiusMedium
            color: Theme.current.colorBg1

            Icon {
                anchors.centerIn: parent
                name: "image"
                size: 64
                color: Theme.current.colorText3
            }
        }

        Text {
            visible: card.description !== ""
            text: card.description
            color: Theme.current.colorText1
            font.pixelSize: Theme.current.fontSizeRegular
            wrapMode: Text.WordWrap
        }
    }

    // 「显示小三角 / 指向元素中心」那两节的内容是同一个 <article>：
    // "Hi ByteDancer, this is a popover.<br /> We have 2 lines."
    component ArticleCard: Text {
        text: qsTr("Hi ByteDancer, this is a popover.\nWe have 2 lines.")
        color: Theme.current.colorText0
        font.pixelSize: Theme.current.fontSizeRegular
        lineHeight: 20                                 // .semi-popover-wrapper 那条 line-height: 20px
        lineHeightMode: Text.FixedHeight
    }

    // 一格 = 一枚 60×60 的 Tag（官方是 padding 20 的 Tag）+ 指着它的一只 Popover。
    // 内容从外面塞进来（默认属性直接接到浮层的 content 上），两种卡片按 visible 取一：
    // Positioner 会把看不见的子项从 implicit 尺寸里整个剔掉，所以不会两头都算。
    component PosCell: Item {
        id: cell

        required property var modelData
        property bool withArrow: false
        property bool pointAtCenter: true
        property bool useArticle: false
        property var popRef: pop

        default property alias card: pop.content

        width: 60
        height: 60

        Tag {
            id: trig

            anchors.fill: parent
            size: "large"
            text: cell.modelData.label
        }

        Popover {
            id: pop

            target: trig
            position: cell.modelData.placement
            showArrow: cell.withArrow
            arrowPointAtCenter: cell.pointAtCenter

            PopCard {
                visible: !cell.useArticle
                title: qsTr("先进的设计 / 研发协作方式")
                description: qsTr("使用 Semi D2C 快速还原 Figma 设计稿，一键转代码")
            }

            ArticleCard {
                visible: cell.useArticle
            }
        }
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
                    + "// 官方把触发器当 children；这边显式指过去，浮层自己声明在页面里\n"
                    + "Tag { id: src; text: \"悬停此处\" }\n"
                    + "Popover {\n"
                    + "    target: src\n"
                    + "    position: Enums.Bottom        // 官方缺省就是 bottom\n"
                    + "    showArrow: true\n"
                    + "    Text { text: 'hi bytedance' } // 富内容写子项，字符串档留给 text\n"
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

                Popover {
                    id: firstPop

                    target: fcTarget

                    PopCard {
                        title: qsTr("先进的设计 / 研发协作方式")
                        description: qsTr("使用 Semi D2C 快速还原 Figma 设计稿，一键转代码")
                    }
                }

                Popover {
                    target: classTarget

                    PopCard {
                        title: qsTr("先进的设计 / 研发协作方式")
                        description: qsTr("使用 Semi D2C 快速还原 Figma 设计稿，一键转代码")
                    }
                }

                Popover {
                    target: domTarget

                    PopCard {
                        title: qsTr("先进的设计 / 研发协作方式")
                        description: qsTr("使用 Semi D2C 快速还原 Figma 设计稿，一键转代码")
                    }
                }
            }

            Note {
                text: qsTr("官网这一节讲的是 React 侧的前置条件：浮层要劫持 children 的事件、还要拿到 children"
                    + "的真实 DOM 节点才能算定位，所以自定义组件必须 forwardRef 并把 props 透下去。"
                    + "本库没有这一层限制：target 指向任意 Item（按钮、标签、图标都行），"
                    + "浮层内容直接写在里面，上面那三枚用的是同一张卡。"
                    + "官方 FAQ 里「有 prefix / suffix 的 Input 定位偏了」那一条在 QML 也不会出现 —— "
                    + "量的是你指给它的那颗 Item 的边界，不是它内部某段 DOM。")
            }
        }

        GallerySection {
            title: "基本使用"

            Row {
                spacing: 16

                Tag {
                    id: basicTarget

                    text: "悬停此处"
                }

                Popover {
                    id: basicPop

                    target: basicTarget

                    PopCard {
                        title: qsTr("先进的设计 / 研发协作方式")
                        description: qsTr("使用 Semi D2C 快速还原 Figma 设计稿，一键转代码")
                    }
                }
            }

            Note {
                text: qsTr("官方缺省 trigger='hover'、position='bottom'、showArrow=false。"
                    + "不带三角时卡片没有内边距（scss 里只有 `.semi-popover-with-arrow { padding: 12px }` 那一条），"
                    + "上面这块卡的 20 内边距是内容自己带的，跟官方那张 demo 同源；"
                    + "浮层与触发器的间距是 4（showArrow=false 那一档的 numbers.SPACING）。")
            }
        }

        GallerySection {
            title: "弹出位置"

            // 浮层会被夹在窗口范围内，上下都留出行高才谈得上「向上 / 向下弹出」
            Item {
                width: 1
                height: 200
            }

            Row {
                spacing: 8

                Repeater {
                    model: page.posTops

                    delegate: PosCell {}
                }
            }

            Item {
                width: 1
                height: 8
            }

            Row {
                spacing: 200

                Column {
                    spacing: 8

                    Repeater {
                        model: page.posLefts

                        delegate: PosCell {}
                    }
                }

                Column {
                    spacing: 8

                    Repeater {
                        model: page.posRights

                        delegate: PosCell {}
                    }
                }
            }

            Item {
                width: 1
                height: 200
            }

            Row {
                spacing: 8

                Repeater {
                    model: page.posBottoms

                    delegate: PosCell {}
                }
            }

            Note {
                text: qsTr("position 就是官方那 12 个值（top / topLeft / topRight / left / leftTop / leftBottom / "
                    + "right / rightTop / rightBottom / bottom / bottomLeft / bottomRight），缺省 bottom。"
                    + "这一节的卡片不带三角，所以角落方位是「卡片边与触发器边对齐」——"
                    + "arrowPointAtCenter 要 showArrow 才谈得上（pointsAtCenter = showArrow && arrowPointAtCenter，"
                    + "与官方 index.tsx 里那个 `!showArrow ? showArrow : arrowPointAtCenter` 同一口径）。"
                    + "空间放不下时会自动翻到对面，最后再夹进窗口，贴边的触发器也不会把浮层顶出去。")
            }
        }

        GallerySection {
            title: "受控显示"

            Row {
                spacing: 16

                RadioGroup {
                    id: controlledGroup

                    type: Enums.ChoiceButton
                    value: page.controlledVisible
                    onChanged: (v) => page.controlledVisible = (v === true)

                    Radio {
                        value: true
                        text: qsTr("受控显示")
                    }

                    Radio {
                        value: false
                        text: qsTr("受控隐藏")
                    }
                }

                Popover {
                    id: controlledPop

                    target: controlledGroup
                    trigger: "custom"
                    visible: page.controlledVisible

                    PopCard {
                        title: qsTr("先进的设计 / 研发协作方式")
                        description: qsTr("使用 Semi D2C 快速还原 Figma 设计稿，一键转代码")
                    }
                }
            }

            Note {
                text: qsTr("trigger='custom' 那一档官方什么都不绑，显隐完全由 visible 说了算 —— "
                    + "本库把这一档做成唯一的受控路径：另外四档（hover / focus / click / contextMenu）"
                    + "也都允许你另外绑 visible，但那时组件自己也会开合，两边会打架。"
                    + "custom 档点外面只发 clickedOutside 信号、不收起，condition 对它也无效。")
            }
        }

        GallerySection {
            title: "condition 条件触发"

            Row {
                spacing: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("condition")
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

                    anchors.verticalCenter: parent.verticalCenter
                    text: "Hover me"
                }

                Button {
                    id: condClickTarget

                    anchors.verticalCenter: parent.verticalCenter
                    text: "Click me"
                    variant: Enums.Light
                }

                Popover {
                    target: condHoverTarget
                    condition: conditionSwitch.checked
                    text: conditionSwitch.checked ? qsTr("condition is true") : qsTr("condition is false")
                }

                Popover {
                    target: condClickTarget
                    trigger: "click"
                    condition: conditionSwitch.checked
                    text: conditionSwitch.checked ? qsTr("condition is true") : qsTr("condition is false")
                }
            }

            Note {
                text: qsTr("官方这一节给的就是字符串内容（`content={'condition is ' + (enabled ? 'true' : 'false')}`），"
                    + "对应这里的 text。condition=false 只废掉 hover / focus / click / contextMenu 四种触发，"
                    + "custom 档不受影响；它也只挡「显示」—— 已经开着的那张卡照样会按 mouseLeaveDelay 自己收掉。")
            }
        }

        GallerySection {
            title: "显示小三角"

            Item {
                width: 1
                height: 120
            }

            Row {
                spacing: 8

                Repeater {
                    model: page.posTops

                    delegate: PosCell {
                        withArrow: true
                        useArticle: true
                    }
                }
            }

            Item {
                width: 1
                height: 8
            }

            Row {
                spacing: 200

                Column {
                    spacing: 8

                    Repeater {
                        model: page.posLefts

                        delegate: PosCell {
                            withArrow: true
                            useArticle: true
                        }
                    }
                }

                Column {
                    spacing: 8

                    Repeater {
                        model: page.posRights

                        delegate: PosCell {
                            withArrow: true
                            useArticle: true
                        }
                    }
                }
            }

            Item {
                width: 1
                height: 120
            }

            Row {
                spacing: 8

                Repeater {
                    model: page.posBottoms

                    delegate: PosCell {
                        withArrow: true
                        useArticle: true
                    }
                }
            }

            Note {
                text: qsTr("带三角的卡片有 12 内边距（`.semi-popover-with-arrow { padding: 12px }`），"
                    + "与触发器的间距换成 10（SPACING_WITH_ARROW），最小尺寸 36×36 —— "
                    + "竖档那条是 24 + 6*2，popover 的 adjusted_offset-y 是 6，tooltip 同一档只有 5（⇒34）。"
                    + "这颗三角是 popover/Arrow.tsx 的两条 path 叠出来的：描边色 var(--semi-color-border) 打底、"
                    + "底色 var(--semi-color-bg-3) 盖上面，所以官方默认就是「卡片只有一条阴影环、三角却有一条边」；"
                    + "自定义底色时要连 borderColor 一起给，就是文档「设置浮层背景色」那条提醒。")
            }
        }

        GallerySection {
            title: "指向元素中心"

            Item {
                width: 1
                height: 120
            }

            Row {
                spacing: 24

                Column {
                    spacing: 8

                    Text {
                        text: qsTr("arrowPointAtCenter: true（缺省）")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Row {
                        spacing: 8

                        Repeater {
                            model: page.posTops

                            delegate: PosCell {
                                withArrow: true
                                useArticle: true
                                pointAtCenter: true
                            }
                        }
                    }
                }

                Column {
                    spacing: 8

                    Text {
                        text: qsTr("arrowPointAtCenter: false")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Row {
                        spacing: 8

                        Repeater {
                            model: page.posTops

                            delegate: PosCell {
                                withArrow: true
                                useArticle: true
                                pointAtCenter: false
                            }
                        }
                    }
                }
            }

            Item {
                width: 1
                height: 120
            }

            Note {
                text: qsTr("官方这一节也是那 12 个方位、只是把 arrowPointAtCenter 显式写出来 —— 它缺省就是 true，"
                    + "所以和上一节看不出差别。真正的差别在角落方位：开着时卡片沿交叉轴平移，"
                    + "让那颗离边 18px 的三角（round(0.24×24)=6 加半个箭头宽 12）落在触发器中心；"
                    + "关掉时卡片边与触发器边对齐，三角仍待在离边 18px 那里，于是只指到触发器左边 18px。"
                    + "上面把两种取值并排画出来，中间方位（top / bottom / left / right）本来就居中，"
                    + "只有卡片被窗口边界夹过时才看得出分别。")
            }
        }

        GallerySection {
            title: "设置浮层背景色"

            Rectangle {
                id: colorHost

                width: 420
                height: 200
                radius: Theme.current.radiusMedium
                color: Theme.current.colorBg1
                border.width: 1
                border.color: Theme.current.colorBorder

                Text {
                    x: 12
                    y: 12
                    text: "#popup-parent（容器）"
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Tag {
                    id: colorfulTarget

                    x: 150
                    y: 88
                    width: 140
                    height: 24
                    text: "Colorful Popover"
                    type: "solid"
                    color: "blue"
                }

                Popover {
                    id: colorfulPop

                    target: colorfulTarget
                    container: colorHost
                    trigger: "custom"
                    visible: true
                    position: Enums.Right
                    showArrow: true
                    style: ({
                        backgroundColor: Theme.current.blue[4],
                        borderColor: Theme.current.blue[4],
                        color: Theme.current.colorWhite,
                        borderWidth: 1,
                        borderStyle: "solid"
                    })

                    Text {
                        padding: 4                            // 官方那层 <article style={{ padding: 4 }}>
                        text: qsTr("Hi, Semi UI Popover.")
                        // style.color 只上到字符串档那一层：官方是 CSS 继承，QML 里子项的文字色得自己接
                        color: colorfulPop.style.color
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }

            Note {
                text: qsTr("style 是官方的写法（弹出层的内联样式），本库只落地有颜色语义的三条："
                    + "backgroundColor → fillColor、borderColor → strokeColor、color → 字符串档那层的文字色；"
                    + "arrowStyle 那三条（borderColor / backgroundColor / borderOpacity）走同样的三级回退，"
                    + "只改三角不动卡片。borderWidth / borderStyle 在 web 上决定「真边框画不画」，"
                    + "我们那条 1px 环是 shadow-elevated 第一层的替身（与 Dropdown 同一口径），不随它们开关。"
                    + "值要写成 QML 认得的颜色，浏览器那套 `rgba(var(--semi-blue-4),1)` 字符串解析不了。"
                    + "container 换的是浮层挂在哪一层（官方 getPopupContainer + position: relative），"
                    + "翻面与被夹的范围都按这个 420×200 的框算。")
            }
        }

        GallerySection {
            title: "初始化弹出层焦点位置"

            Row {
                spacing: 16

                Button {
                    id: focusTarget

                    text: "click me"
                }

                Popover {
                    id: focusPop

                    target: focusTarget
                    trigger: "click"
                    initialFocus: focusField

                    Item {
                        width: innerRow.implicitWidth + 24
                        height: innerRow.implicitHeight + 24

                        Row {
                            id: innerRow

                            x: 12
                            y: 12
                            spacing: Theme.current.spacingTight

                            Button {
                                text: qsTr("first focusable element")
                                variant: Enums.Light
                            }

                            Input {
                                id: focusField

                                width: 140
                                placeholderText: qsTr("focus here")
                            }
                        }
                    }
                }
            }

            Note {
                text: qsTr("官方让 content 收一个函数，把入参里的 initialFocusRef 绑到想聚焦的控件上，"
                    + "浮层显示那一刻 foundation 调 setInitialFocus()（foundation.ts:390-397）。"
                    + "QML 侧没有「把 ref 塞进对方组件」这条路，改成 initialFocus 直接收那一项："
                    + "visible 变真的下一帧对它 forceActiveFocus()。"
                    + "另外两条键盘行为没落地 —— guardFocus（Tab 在浮层内循环）与方向键把焦点送进浮层"
                    + "都要先枚举 DOM 里可聚焦的节点，本库把 Tab 交给 Qt 自己的焦点链；"
                    + "returnFocusOnClose 只接了 Esc 那一路（官方 focusTrigger 也只在按 Esc 时被调）。")
            }
        }

        GallerySection {
            title: "搭配 Tooltip 或 Popconfirm 使用"

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

                Popover {
                    target: bothTarget
                    position: Enums.BottomRight
                    showArrow: true

                    Text {
                        text: qsTr("同一颗触发器上的第三份浮层")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                Popconfirm {
                    anchor: bothTarget
                    title: "确认"
                    description: "是否确认删除"
                }
            }

            Note {
                text: qsTr("官方这节的结论还是「要在中间加一层 div / span」：Tooltip、Popover、Popconfirm "
                    + "都要劫持 children 的 onMouseEnter / onClick，直接嵌套时外层那份 props 被子组件吃掉。"
                    + "QML 侧三个组件各自往 target / anchor 上挂 handler，谁也不覆盖谁，"
                    + "所以这里悬停出 tooltip、点击出 popconfirm、"
                    + "那一张 Popover 也照样挂在同一颗按钮上（这一只走 hover，跟 tooltip 一起响）。")
            }
        }
    }

    // 截图模式（--shot）下打开几档代表性外观，否则抓不到浮层本体
    Component.onCompleted: {
        if (Qt.application.arguments.indexOf("--shot") < 0)
            return;
        firstPop.open();
        colorfulPop.open();
    }
}
