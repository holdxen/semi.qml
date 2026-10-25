pragma ComponentBehavior: Bound

import QtQuick
import Semi

// SideSheet 滑动侧边栏。小节顺序与标题对齐官方文档页 content/show/sidesheet/index.md
// （如何引入 + 基本 / 自定义位置 / 自定义尺寸 / 可操作的外部区域 / 渲染在指定容器 /
// 自定义内容区域）。
//
// 与 Modal 一样完全受控：× / 遮罩 / Esc 三条关闭路径都只发 onCancel，组件自己不关，
// 由本页在回调里把 visible 收回 false。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 每一节一份「useState」
    property bool basicOpen: false
    property string placement: "right"
    property bool placementOpen: false
    property string size: "small"
    property bool sizeOpen: false
    property bool outsideOpen: false
    property string typed: ""
    property bool inBoxOpen: false
    property bool richOpen: false

    readonly property string bodyLine: "This is the content of a basic sidesheet."
    readonly property string moreLine: "Here is more content..."

    component Note: Text {
        width: 560
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    // 官方每一节的正文都是这两行（照抄文案）
    component Body: Column {
        id: body

        width: parent.width
        spacing: 0

        Text {
            width: parent.width
            text: page.bodyLine
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: page.moreLine
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.WordWrap
        }
    }

    // 自定义内容区域那一节的三样东西：标题节点、页脚节点、分隔线的颜色串
    property Component richTitle: Component {
        Title {
            heading: 4
            text: qsTr("创建资源包")
        }
    }

    // 页脚槽那个 Loader 有显式宽高 ⇒ 它会接管载入项的尺寸，Row 自己 anchors.right
    // 是无效的（Modal 那一轮同一条坑）。照官方 `<div style="display:flex;
    // justify-content:flex-end">` 的意思，垫一层满宽的 Item，把 Row 锚回右边。
    property Component richFooter: Component {
        Item {
            implicitHeight: footerRow.implicitHeight

            Row {
                id: footerRow

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Button {
                    objectName: "customFooterReset"

                    text: qsTr("重置")
                    variant: Enums.Light
                    onClicked: page.richOpen = false
                }

                Button {
                    text: qsTr("提交")
                    // sidesheet/index.md:232 页脚那支是 theme="solid"
                    variant: Enums.Solid
                    onClicked: page.richOpen = false
                }
            }
        }
    }

    readonly property string dividerCss: "1px solid " + Theme.current.colorBorder

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 620
                text: "import Semi\n\n"
                    + "// visible 是受控开关；× / 遮罩 / Esc 三条路径都只发 onCancel\n"
                    + "SideSheet {\n"
                    + "    title: \"滑动侧边栏\"\n"
                    + "    visible: page.open\n"
                    + "    onCancel: page.open = false\n"
                    + "    Text { text: \"内容\" }\n"
                    + "}"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "基本"

            Column {
                width: 560
                spacing: 12

                Text {
                    text: qsTr("默认侧边栏从右滑出，支持点击遮罩区关闭。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Button {
                    text: qsTr("Open SideSheet")
                    onClicked: page.basicOpen = true
                }
            }

            SideSheet {
                title: qsTr("滑动侧边栏")
                visible: page.basicOpen
                onCancel: page.basicOpen = false

                Body {
                }
            }
        }

        GallerySection {
            title: "自定义位置"

            Column {
                width: 560
                spacing: 12

                Text {
                    text: qsTr("通过 placement 设置滑出方位，支持 top / bottom / left / right。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                RadioGroup {
                    value: page.placement
                    onChanged: (v) => page.placement = v

                    Radio { value: "right"; text: "right" }
                    Radio { value: "left"; text: "left" }
                    Radio { value: "top"; text: "top" }
                    Radio { value: "bottom"; text: "bottom" }
                }

                Button {
                    text: qsTr("Open SideSheet")
                    onClicked: page.placementOpen = true
                }
            }

            SideSheet {
                title: qsTr("滑动侧边栏")
                visible: page.placementOpen
                onCancel: page.placementOpen = false
                placement: page.placement

                Body {
                }
            }

            Note {
                text: qsTr("上下方位下面板横过来：宽度撑满容器，主轴改成高，"
                    + "恒取官方 strings.HEIGHT 的 448（size 不参与）。")
            }
        }

        GallerySection {
            title: "自定义尺寸"

            Column {
                width: 560
                spacing: 12

                Text {
                    text: qsTr("size 支持 small(448px) / medium(684px) / large(920px)，"
                        + "仅在 placement 为 left 或 right 时生效。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }

                RadioGroup {
                    value: page.size
                    onChanged: (v) => page.size = v

                    Radio { value: "small"; text: "small" }
                    Radio { value: "medium"; text: "medium" }
                    Radio { value: "large"; text: "large" }
                }

                Button {
                    text: qsTr("Open SideSheet")
                    onClicked: page.sizeOpen = true
                }
            }

            SideSheet {
                title: qsTr("滑动侧边栏")
                visible: page.sizeOpen
                onCancel: page.sizeOpen = false
                size: page.size

                Body {
                }
            }

            Note {
                text: qsTr("官方还写了「可以通过 width 自行设置宽度」，例如 width={900} / "
                    + "width={'800px'}；本端口那条落在面板自己的 width 上，只认数字："
                    + "SideSheet { width: 900 }。")
            }
        }

        GallerySection {
            title: "可操作的外部区域"

            Column {
                width: 560
                spacing: 12

                Text {
                    text: qsTr("当 mask={false} 时允许对外部区域进行操作。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Button {
                    text: qsTr("Open SideSheet")
                    onClicked: page.outsideOpen = true
                }

                TextArea {
                    width: 560
                    placeholderText: qsTr("Please enter something")
                    onTextChanged: page.typed = text
                }
            }

            SideSheet {
                title: qsTr("可操作外部的侧边栏")
                visible: page.outsideOpen
                onCancel: page.outsideOpen = false
                mask: false
                disableScroll: false

                Column {
                    width: parent.width
                    spacing: 0

                    Text {
                        width: parent.width
                        text: qsTr("这里是输入的内容：")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        lineHeight: 20
                        lineHeightMode: Text.FixedHeight
                    }

                    Text {
                        width: parent.width
                        text: page.typed
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        lineHeight: 20
                        lineHeightMode: Text.FixedHeight
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Note {
                // 官方那一节上面的 <Notice>：SideSheet 渲染在 body 中时（即不传
                // getPopupContainer）打开会自动给 body 写 overflow: hidden 禁滚动，
                // 想保留外部滚动就把 disableScroll 设 false。端口的落点见组件头注释。
                text: qsTr("注意：默认渲染在窗口里时，disableScroll 会用一层只吃滚轮的层挡住面板之外"
                    + "（不吃鼠标，所以外面照常可点）；希望外部也能滚就把 disableScroll 设 false。"
                    + "传了 getPopupContainer 时官方不锁滚动，这里同样不锁。")
            }
        }

        GallerySection {
            title: "渲染在指定容器"

            Column {
                width: 560
                spacing: 12

                Text {
                    text: qsTr("通过 getPopupContainer 指定父级 DOM，弹层会渲染进该容器。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                // 官方那个带样式的容器 div（index.md:160-172）：height 320、
                // overflow hidden、position relative、1px 描边、padding 24、居中、fill-0 底
                Rectangle {
                    id: box

                    objectName: "sidesheetContainer"

                    width: 560
                    height: 320
                    radius: 2
                    color: Theme.current.colorFill0
                    border.width: 1
                    border.color: Theme.current.colorBorder
                    // 官方那条 Note：容器要手动设 overflow: hidden，否则动画会溢出
                    clip: true

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 24
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Render in this")
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }

                        Button {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Open SideSheet")
                            onClicked: page.inBoxOpen = true
                        }
                    }

                    SideSheet {
                        title: qsTr("渲染在指定容器内部")
                        visible: page.inBoxOpen
                        onCancel: page.inBoxOpen = false
                        width: 220
                        getPopupContainer: () => box

                        Body {
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "自定义内容区域"

            Column {
                width: 560
                spacing: 12

                Text {
                    text: qsTr("自定义 title、footer 等可以拼出更丰富的内容样式。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Button {
                    text: qsTr("More Information")
                    onClicked: page.richOpen = true
                }
            }

            SideSheet {
                title: page.richTitle
                // 官方 demo 写的是 closeIcon={null}，但 SideSheetContent.tsx:108 那句是
                // `closeIcon || <IconClose/>`，假值会回落成默认那颗 × —— 上游 bug，只记录不抄：
                // 要真的没有 × 就写 closable: false。
                closable: false
                headerStyle: ({ borderBottom: page.dividerCss })
                bodyStyle: ({ borderBottom: page.dividerCss })
                visible: page.richOpen
                onCancel: page.richOpen = false
                footer: page.richFooter

                Form {
                    width: parent.width

                    FormItem {
                        field: "date"
                        label: ({ text: qsTr("创建时间"), required: true })

                        DatePicker {
                            width: 272
                            type: Enums.TypeDateTime
                            defaultValue: new Date()
                        }
                    }

                    FormItem {
                        field: "type"
                        label: qsTr("目标操作系统")

                        RadioGroup {
                            direction: Enums.DirectionHorizontal
                            defaultValue: "all"

                            Radio { value: "all"; text: qsTr("全平台") }
                            Radio { value: "ios"; text: "iOS" }
                            Radio { value: "android"; text: "Android" }
                            Radio { value: "web"; text: "Web" }
                        }
                    }

                    FormItem {
                        field: "origin"
                        label: qsTr("资源包来源")

                        RadioGroup {
                            direction: Enums.DirectionHorizontal
                            defaultValue: "scm"

                            Radio { value: "scm"; text: qsTr("从SCM上传") }
                            Radio { value: "manual"; text: qsTr("手动上传") }
                        }
                    }

                    Banner {
                        fullMode: false
                        iconShown: false
                        tone: Enums.Warning
                        bordered: true
                        description: qsTr("当前部署环境：线上部署\n"
                            + "请选择正确的SCM构建产物，防止出现不符合预期的发布操作。")
                    }

                    FormItem {
                        field: "users"
                        label: ({ text: qsTr("创建用户"), required: true })

                        Select {
                            width: 560
                            multiple: true
                            defaultValues: ["1", "2", "3", "4"]
                            options: [
                                { label: qsTr("曲晨一"), value: "1" },
                                { label: qsTr("夏可曼"), value: "2" },
                                { label: qsTr("曲晨三"), value: "3" },
                                { label: qsTr("蔡妍"), value: "4" }
                            ]
                        }
                    }
                }
            }

            Note {
                text: qsTr("页脚那两颗按钮是调用方自己的 markup（官方 footer: null，"
                    + "没有默认页脚）；标题走 title 的节点档，端口量的是载入项的 implicitHeight。"
                    + "另外官方这一节的 Select 写死 560，比 small 档的内容区（448−48=400）还宽，"
                    + "浏览器里会出横向滚动条，本面板的 body 只滚竖不滚横，超出那截直接裁掉。")
            }
        }
    }

    // 截图模式（--shot）下把侧边栏打开，否则抓不到面板外观
    Component.onCompleted: {
        if (Qt.application.arguments.indexOf("--shot") >= 0)
            page.basicOpen = true;
    }
}
