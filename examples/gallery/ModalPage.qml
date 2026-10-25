pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Modal 模态对话框。小节顺序与标题对齐官方文档页 content/show/modal/index.md
// （docs.json 里的 13 个小节，「如何引入」也照旧进 demo 区）。
//
// 官方那一份是**完全受控**的：onOk / onCancel 只回调，组件自己不关，
// 是 demo 在回调里 setVisible(false)。所以下面每一节都是「一个 bool + 一个 Modal」，
// 而不是早先那套 open() / close()。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 每一节一份「useState」
    property bool basicOpen: false
    property bool footerFillOpen: false
    property bool maskLockOpen: false
    property bool textOpen: false
    property bool propsOpen: false
    property bool footerOpen: false
    property bool styleOpen: false
    property bool customOpen: false
    property bool fullScreenOpen: false
    property bool dragOpen: false
    property string lastAction: ""

    readonly property string bodyLine: qsTr("This is the content of a basic modal.")
    readonly property string moreLine: qsTr("More content...")

    component Note: Text {
        width: 560
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    // 官方每一节正文的第一句各不相同（第二句基本都是 More content...），照抄
    component Body: Column {
        id: body

        width: parent.width
        spacing: 0

        property string firstLine: page.bodyLine
        property string secondLine: page.moreLine

        Text {
            width: parent.width
            text: body.firstLine
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: body.secondLine
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.WordWrap
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
                    + "// 声明式：受控开关是 visible，回调只有 ok / cancel / afterClose\n"
                    + "Modal {\n"
                    + "    title: \"基本对话框\"\n"
                    + "    visible: page.open\n"
                    + "    onOk: page.open = false\n"
                    + "    onCancel: page.open = false\n"
                    + "    Text { text: \"内容\" }\n"
                    + "}\n\n"
                    + "// 命令式：摆一个宿主，五个方法都在它身上（宿主同时就是 useModal 的 contextHolder）\n"
                    + "ModalHost { id: modalHost }\n"
                    + "modalHost.info({ title: \"Here is some info\", content: \"bla bla bla...\" })"
            }
        }

        GallerySection {
            title: "基本"

            Column {
                width: 560
                spacing: 12

                Row {
                    spacing: 16

                    Button {
                        text: qsTr("打开弹窗")
                        onClicked: page.basicOpen = true
                    }
                }

                Text {
                    text: qsTr("最近一次：%1").arg(
                        page.lastAction === "" ? qsTr("（还没有）") : page.lastAction)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }

            Modal {
                id: basicModal

                title: qsTr("基本对话框")
                visible: page.basicOpen
                closeOnEsc: true

                Body { }

                onOk: {
                    page.lastAction = qsTr("点了确定");
                    page.basicOpen = false;
                }
                onCancel: {
                    page.lastAction = qsTr("点了取消");
                    page.basicOpen = false;
                }
                onAfterClose: page.lastAction = qsTr("退场动画结束（afterClose）")
            }

            Note {
                text: qsTr("官方 demo 把 handleOk / handleCancel / handleAfterClose 三个回调都写了一遍："
                    + "onOk 与 onCancel 只负责通知，**是回调里那句 setVisible(false) 把框关掉的**，"
                    + "所以端口里也是 visible 归调用方，组件自己不关。"
                    + "afterClose 在退场动画结束时发，比 cancel 晚 120ms。")
            }
        }

        GallerySection {
            title: "底部撑满"

            Button {
                text: qsTr("打开弹窗")
                onClicked: page.footerFillOpen = true
            }

            Modal {
                title: qsTr("基本对话框")
                visible: page.footerFillOpen
                footerFill: true
                closeOnEsc: true

                Body { }

                onOk: page.footerFillOpen = false
                onCancel: page.footerFillOpen = false
            }

            Note {
                text: qsTr("footerFill 把页脚那两条按钮摊满内容区：398 宽扣掉 12 的间距，每颗 193"
                    + "（官方 .semi-modal-footerfill { display: flex } + Button 的 block）。")
            }
        }

        GallerySection {
            title: "点击遮罩层不可关闭"

            Button {
                text: qsTr("点击遮罩层不可关闭")
                onClicked: page.maskLockOpen = true
            }

            Modal {
                title: qsTr("对话框标题")
                visible: page.maskLockOpen
                maskClosable: false

                Body {
                    firstLine: qsTr("This is a modal that cannot be closed by clicking on the mask.")
                }

                onOk: page.maskLockOpen = false
                onCancel: page.maskLockOpen = false
            }

            Note {
                text: qsTr("默认 maskClosable 为 true，点遮罩走 onCancel；设成 false 就只剩"
                    + "确定 / 取消 / 右上角 × / Esc 四条。早先这一节写的是「本库默认点遮罩不关」，"
                    + "那是组件自己关层时的假象，改成受控之后默认值与官方一致了。")
            }
        }

        GallerySection {
            title: "自定义按钮文字"

            Button {
                text: qsTr("自定义按钮文字")
                onClicked: page.textOpen = true
            }

            Modal {
                title: qsTr("自定义按钮文字")
                visible: page.textOpen
                okText: "Sounds great!"
                cancelText: "No, thanks."

                Body {
                    firstLine: qsTr("This is a modal with customized button texts.")
                }

                onOk: page.textOpen = false
                onCancel: page.textOpen = false
            }

            Note {
                text: qsTr("okText / cancelText 不传就落 locale 的「确定」「取消」。"
                    + "官方特别写了：命令式调用那五支因为拿不到 Locale 的 Context，"
                    + "i18n 文案必须显式传这两个属性。")
            }
        }

        GallerySection {
            title: "自定义按钮属性"

            Button {
                text: qsTr("自定义按钮属性")
                onClicked: page.propsOpen = true
            }

            Modal {
                title: qsTr("自定义按钮属性")
                visible: page.propsOpen
                okButtonProps: ({ size: "small", type: "warning" })
                cancelButtonProps: ({ size: "small", disabled: true })

                Body {
                    firstLine: qsTr("This is a modal with customized button props.")
                }

                onOk: page.propsOpen = false
                onCancel: page.propsOpen = false
            }

            Note {
                text: qsTr("两个 props 对象官方是整份展开到 Button 上，这里只认 ButtonProps 里"
                    + "真能落地的那几项：type / theme / size / disabled / loading / autoFocus / width。"
                    + "size 换成 small 之后按钮高 24，整块面板跟着矮 8。")
            }
        }

        GallerySection {
            title: "自定义对话框头部和页脚"

            Button {
                text: qsTr("自定义页脚样式")
                onClicked: page.footerOpen = true
            }

            Modal {
                title: qsTr("自定义页脚")
                visible: page.footerOpen
                footer: Component {
                    // 官方那一条是 footer={<Button type="primary">Yes, I Understand</Button>}：
                    // 自然宽的实心主按钮，靠 .semi-modal-footer 的 text-align: right 贴右。
                    // 这里不能直接写 Button —— 页脚那个 Loader 自己有宽高绑定，会把载入项
                    // 拉成整块宽（见 src/Modal.qml 头注释那条），所以垫一层 Item 把按钮锚到右边。
                    Item {
                        implicitWidth: 398
                        implicitHeight: ackButton.implicitHeight

                        Button {
                            id: ackButton

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            tone: Enums.Primary
                            variant: Enums.Solid
                            text: "Yes, I Understand"
                            onClicked: page.footerOpen = false
                        }
                    }
                }

                Body {
                    firstLine: qsTr("This is a modal with a customized footer.")
                }

                onOk: page.footerOpen = false
                onCancel: page.footerOpen = false
            }

            Note {
                text: qsTr("footer 传节点就是页脚整块换成那个节点（默认页脚是 null 才回来），"
                    + "传 null 则整块不渲染。header 同理：设成 null 时头部连右上角的 × 一起没了 —— "
                    + "官方 renderBody 只在「没有 header 也没有 title」那一支里画关闭键。")
            }
        }

        GallerySection {
            title: "自定义对话框的样式"

            Button {
                text: qsTr("自定义对话框样式")
                onClicked: page.styleOpen = true
            }

            Modal {
                title: qsTr("自定义样式")
                visible: page.styleOpen
                centered: true
                bodyStyle: ({ overflow: "auto", height: 200 })

                Column {
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: [
                            qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统。"
                                + "设计系统包含设计语言以及一整套可复用的前端组件，帮助设计师与开发者"
                                + "更容易地打造高质量的、用户体验一致的、符合设计规范的 Web 应用。"),
                            qsTr("区别于其他的设计系统而言，Semi Design 以用户中心、内容优先、"
                                + "设计人性化为设计理念，具有以下优势：")
                        ]

                        delegate: Text {
                            required property var modelData

                            width: parent.width
                            text: modelData
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                            lineHeight: 36
                            lineHeightMode: Text.FixedHeight
                            wrapMode: Text.WordWrap
                        }
                    }

                    Repeater {
                        model: [
                            qsTr("Semi Design 以内容优先进行设计。"),
                            qsTr("更容易地自定义主题。"),
                            qsTr("适用国际化场景。"),
                            qsTr("效率场景加入人性化关怀")
                        ]

                        delegate: Text {
                            required property var modelData

                            width: parent.width
                            text: "· " + modelData
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                            lineHeight: 20
                            lineHeightMode: Text.FixedHeight
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                onOk: page.styleOpen = false
                onCancel: page.styleOpen = false
            }

            Note {
                text: qsTr("这一节官方标题里还点了 style 与 maskStyle（比如 style.top），"
                    + "本端口没有 CSS，那两条不收：面板位置能改的是 centered（不传就是距顶 80），"
                    + "内容区能改的是 bodyStyle 的 height / maxHeight / overflow。"
                    + "bodyStyle 设了 200 又开 overflow:auto，正文超出就在面板里滚。")
            }
        }

        GallerySection {
            title: "自定义的对话框"

            Button {
                text: qsTr("自定义对话框")
                onClicked: page.customOpen = true
            }

            Modal {
                header: null
                visible: page.customOpen

                Column {
                    width: parent.width
                    spacing: 0

                    Text {
                        width: parent.width
                        text: qsTr("Semi Design New Features")
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.current.colorText0
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: [
                            { icon: "semi_logo", title: qsTr("Boost new feature adoption with Integration") },
                            { icon: "bytedance_logo", title: qsTr("Introducing Dark Mode") },
                            { icon: "semi_logo", title: qsTr("New List Component") }
                        ]

                        delegate: Row {
                            id: featureRow

                            required property var modelData

                            width: parent.width
                            spacing: Theme.current.spacingBaseTight

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: featureRow.modelData.icon
                                size: 48
                                tinted: false
                            }

                            Column {
                                width: parent.width - 48 - Theme.current.spacingBaseTight
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: featureRow.modelData.title
                                    color: Theme.current.colorText0
                                    font.pixelSize: 16
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    width: parent.width
                                    text: qsTr("Sample data is prepared for you to demonstrate how "
                                        + "Integration may be useful for your team")
                                    color: Theme.current.colorText1
                                    font.pixelSize: Theme.current.fontSizeRegular
                                    lineHeight: 20
                                    lineHeightMode: Text.FixedHeight
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                footer: Component {
                    Column {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: [
                                { text: qsTr("Continue"), variant: Enums.Solid },
                                { text: qsTr("Learn more features"), variant: Enums.Borderless }
                            ]

                            delegate: Button {
                                required property var modelData

                                text: modelData.text
                                tone: Enums.Primary
                                variant: modelData.variant
                                width: 240
                                anchors.horizontalCenter: parent.horizontalCenter
                                onClicked: page.customOpen = false
                            }
                        }
                    }
                }

                onOk: page.customOpen = false
                onCancel: page.customOpen = false
            }

            Note {
                text: qsTr("官方这一节用 List / ListItem 排那三条特性，本库的 ListItem 没有"
                    + "header / main 两个槽位，所以直接拿 Row 摆；vigo_logo 不在同步进来的图标表里，"
                    + "中间那条换了 bytedance_logo。header: null 那一条是原样的。")
            }
        }

        GallerySection {
            title: "全屏 Modal"

            Button {
                text: qsTr("打开全屏弹窗")
                onClicked: page.fullScreenOpen = true
            }

            Modal {
                title: qsTr("全屏对话框标题")
                visible: page.fullScreenOpen
                fullScreen: true

                Body {
                    firstLine: qsTr("This is a full screen modal")
                }

                onOk: page.fullScreenOpen = false
                onCancel: page.fullScreenOpen = false
            }

            Note {
                text: qsTr("fullScreen 铺满整个容器：圆角 0、无描边、margin 取消，"
                    + "并且会盖掉 size / width / height（官方那条 inline style 排在最里层）。")
            }
        }

        GallerySection {
            title: "命令式调用"

            Column {
                spacing: 16

                Button {
                    text: qsTr("Info")
                    onClicked: modalHost.info({
                        title: qsTr("Here is some info"), content: qsTr("bla bla bla...") })
                }

                Button {
                    text: qsTr("Success")
                    onClicked: modalHost.success({
                        title: qsTr("This is a success message"), content: qsTr("bla bla bla...") })
                }

                Button {
                    text: qsTr("Error")
                    tone: Enums.Danger
                    onClicked: modalHost.error({
                        title: qsTr("Unfortunately, there is an error"), content: qsTr("bla bla bla...") })
                }

                Button {
                    text: qsTr("Warning")
                    tone: Enums.Warning
                    onClicked: modalHost.warning({
                        title: qsTr("Warning: be cautious ahead"), content: qsTr("bla bla bla...") })
                }

                Button {
                    text: qsTr("Confirm")
                    tone: Enums.Primary
                    onClicked: modalHost.confirm({
                        title: qsTr("Are you sure ?"), content: qsTr("bla bla bla...") })
                }

                Button {
                    text: qsTr("Custom")
                    onClicked: modalHost.info({
                        title: qsTr("This is a custom modal"),
                        content: qsTr("bla bla bla..."),
                        icon: "send",
                        cancelButtonProps: { theme: "borderless" },
                        okButtonProps: { theme: "solid" }
                    })
                }
            }

            ModalHost {
                id: modalHost
            }

            Note {
                text: qsTr("官方是 Modal.info() / success() / error() / warning() / confirm() 五个静态方法，"
                    + "QML 的类型上没有静态方法，所以整套 API 落在 ModalHost 实例上（同 Toast / Notification）。"
                    + "返回值是一对 { destroy, update }，destroy 就是官方的 close（会播退场动画，"
                    + "动画结束跑 afterClose 才真的卸载）；Modal.destroyAll() 挨个走同一条路。"
                    + "五个 type 的图标与颜色照官方：info 蓝、success 绿、error 红（且确定键换成 danger）、"
                    + "warning 橙、confirm 问号牌蓝。确定与取消**都在** —— 官方压根没传 hasCancel。")
            }
        }

        GallerySection {
            title: "Hooks 用法"

            Button {
                text: qsTr("Confirm Modal")
                onClicked: hookHost.confirm({
                    title: qsTr("This is a success message"), content: qsTr("Context consumer") })
            }

            // 官方：const [modal, contextHolder] = Modal.useModal()
            ModalHost {
                id: hookHost
            }

            Note {
                text: qsTr("官方 useModal() 返回一对 [modal, contextHolder]，为的是让弹层拿到 "
                    + "ConfigProvider / LocaleProvider 那一层的 Context。端口里 ModalHost 本身就是那一对："
                    + "config 里传的 Component 由它定义处的那份作用域实例化，这就是官方说的"
                    + "「得到 contextHolder 所在位置的所有上下文」。")
            }
        }

        GallerySection {
            title: "可拖拽 Modal"

            Button {
                text: qsTr("Open Modal")
                onClicked: page.dragOpen = true
            }

            Modal {
                title: qsTr("可拖拽Modal")
                visible: page.dragOpen
                centered: true
                modalRender: Component {
                    DragMove {
                        constrainToParent: false
                    }
                }

                // 官方这一节的正文是从 SideSheet 那一份复制来的（sidesheet / Here is more content...），
                // 照抄不改
                Body {
                    firstLine: qsTr("This is the content of a basic sidesheet.")
                    secondLine: qsTr("Here is more content...")
                }

                onOk: page.dragOpen = false
                onCancel: page.dragOpen = false
            }

            Note {
                text: qsTr("官方那一条是 modalRender={(modal) => <DragMove positionStrategy=\"relative\">"
                    + "</DragMove>}：面板被搬进 DragMove 里，遮罩不动。本库的 DragMove 还没有 "
                    + "positionStrategy / constrainer 这两个 prop（那是另一轮的活），"
                    + "demo 用 constrainToParent: false 达到同样的自由拖动。")
            }
        }
    }

    // 截图模式（--shot）下把第一个对话框打开，否则抓不到面板外观
    Component.onCompleted: {
        if (Qt.application.arguments.indexOf("--shot") >= 0)
            page.basicOpen = true;
    }
}
