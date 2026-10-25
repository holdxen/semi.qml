pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Card 卡片。官方 `content/show/card/index.md` 的「代码演示」一共 14 节，加「如何引入」
// 这里一共 15 个小节，逐节摆齐：基础卡片 / 简洁卡片 / 封面 / 边线和外边框 / 阴影 /
// 更灵活的内容展示 / 内部卡片 / 栅格卡片 / 内置预加载 / 更丰富的预加载效果 /
// 带页签的卡片 / 卡片操作区 / 卡片组 / 网格型卡片组。
//
// 端口与官方的口径差（完整清单在 src/Card.qml、src/CardMeta.qml、src/CardGroup.qml 文件头）：
//   · 官方 `Card.Meta` 在 QML 里写成不了静态属性 ⇒ 独立类型 `CardMeta`；`CardGroup` 同名。
//   · ReactNode 档（title / header / headerExtraContent / cover / footer / actions 的每一项、
//     Meta 的三格）这里是「字符串或 Component」；`Component {}` 不能写在数组字面量里，
//     所以要先声明成页面属性再引用（见 page.ratingAction）。
//   · `bodyStyle` / `headerStyle` / `footerStyle` / `style` / `className` 是死 prop。官方 demo 拿
//     `style={{ maxWidth: 360 }}` 收窄、拿 `bodyStyle` 的 flex 排 Meta 与图标，端口一律在调用点
//     自己写 `width:` 与自己摆两端对齐的那一层。
//   · 封面的图官方用远端地址，端口换成仓库里的 sample1.png（离线也要能画）。
//   · 官方 loading 的占位是 `Skeleton.Title` + `<br/>` + `Skeleton.Paragraph rows={3}`，
//     卡片本体没有内间距那条规则同样照抄 ⇒ 正文之间要自己包 Column。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 相对 URL：在 gallery 里落在模块的 qrc 前缀下，用探针直接装这个文件时落在磁盘上
    readonly property string photo: "data/img/sample1.png"

    // actions 收的是 ReactNode 数组 ⇒ 节点先声明成 Component 再交出去
    readonly property Component ratingAction: Component {
        Rating {
            size: "small"
            defaultValue: 4
        }
    }

    readonly property Component docAvatar: Component {
        Avatar {
            text: "S"
            backgroundColor: "#0064fa"
        }
    }

    // 官方「更灵活的内容展示」那节的 title 就是一张 Meta
    readonly property Component metaTitle: Component {
        CardMeta {
            title: "Semi Doc"
            description: "全面、易用、优质"
            avatar: page.docAvatar
        }
    }

    readonly property Component coverPhoto: Component {
        Image {
            source: page.photo
            // Loader 会把封面的宽强制成整幅（官方 `> * { width: 100% }`），高等比跟着算
            height: Math.round(width * 270 / 480)
            fillMode: Image.PreserveAspectCrop
        }
    }

    readonly property Component footerActions: Component {
        Row {
            spacing: Theme.current.spacingTight

            Button {
                text: qsTr("精选案例")
                variant: Enums.Borderless
            }

            Button {
                text: qsTr("开始使用")
                variant: Enums.Solid
                tone: Enums.Primary
            }
        }
    }

    property bool preloading: true
    property bool richLoading: true
    property int groupSpacing: 12
    property int tabIndex: 0

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
                    text: "import { Card } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("Card 官方一共 17 条：`actions` / `bodyStyle` / `bordered` / `className` /"
                        + " `cover` / `headerExtraContent` / `footer` / `footerLine` / `footerStyle` /"
                        + " `header` / `headerLine` / `headerStyle` / `loading` / `shadows` / `style` /"
                        + " `title`，外加 a11y 的 `aria-label`。缺省是 `bordered: true`、"
                        + "`headerLine: true`、`footerLine: false`、`loading: false`；`shadows` 没有缺省值，"
                        + "只有 `hover` 与 `always` 两档。")
                }

                Note {
                    text: qsTr("本体 `padding: 0` —— 那 20 的内边距在 header / body / footer 三段各自身上，"
                        + "封面则整幅铺到底。而且 body 那个 div 是**无条件渲染**的，"
                        + "所以一张空卡也占 40 高。")
                }
            }
        }

        GallerySection {
            title: "基础卡片"

            Card {
                width: 360
                title: "Semi Design"

                headerExtraContent: Component {
                    Text {
                        text: qsTr("更多")
                        color: Theme.current.colorLink
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                Text {
                    width: parent.width
                    text: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统。"
                        + "设计系统包含设计语言以及一整套可复用的前端组件，帮助设计师与开发者更容易地"
                        + "打造高质量的、用户体验一致的、符合设计规范的 Web 应用。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: 20
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }
            }

            Note {
                text: qsTr("标题给的是字符串时，官方把它包进 `Typography.Title heading={6}`"
                    + "（index.tsx:131）⇒ 16 / 22 / 600、单行截尾、真截到了才出 Tooltip。"
                    + "标题右侧那格是 16 / **700** / text-0；demo 里放的 `<Text link>` 自带 14 的字号，"
                    + "所以看到的是「链接小字挂在 16 的格子里」。")
            }
        }

        GallerySection {
            title: "简洁卡片"

            Column {
                spacing: 16

                Card {
                    width: 360

                    Text {
                        width: parent.width
                        text: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                        lineHeight: 20
                        lineHeightMode: Text.FixedHeight
                        wrapMode: Text.WordWrap
                    }
                }

                Card {
                    width: 360

                    Item {
                        width: parent.width
                        height: Math.max(metaLeft.height, infoRight.height)

                        CardMeta {
                            id: metaLeft

                            title: "Semi Doc"
                            avatar: page.docAvatar
                        }

                        Icon {
                            id: infoRight

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            name: "info_circle"
                            color: Theme.current.colorPrimary
                        }

                        Popover {
                            target: infoRight
                            text: qsTr("这是一个 Card")
                        }
                    }
                }
            }

            Note {
                text: qsTr("官方这一节把 Meta 与图标挤在两端靠的是 "
                    + "`bodyStyle={{ display: 'flex', justifyContent: 'space-between' }}`；"
                    + "那几条 `*Style` 在端口是死 prop ⇒ 改成调用点自己摆一层「左 Meta + 右图标」的 Item。")
            }
        }

        GallerySection {
            title: "封面"

            Card {
                width: 300
                cover: page.coverPhoto

                CardMeta {
                    title: "卡片封面"
                }
            }

            Note {
                text: qsTr("cover 那条 CSS 是 `-cover > * { display: block; width: 100% }` ⇒ 封面的直接"
                    + "子节点一律铺满整幅，端口用「Loader 有显式宽就把宽转嫁给载入项」顶替。"
                    + "图片的高官方靠 `height: auto` 等比，端口得自己按原图比例写 "
                    + "`height: width * 270 / 480`。卡片那 6px 圆角这一轮还没切到封面顶角 —— "
                    + "做法是有的（隐藏源 + 分层圆角遮罩 + MultiEffect，Avatar 那枚圆就是这么裁的），"
                    + "只是要连封面像素一起重做一轮复核（详见 src/Card.qml 文件头与 PROGRESS.md 坑 117）。")
            }
        }

        GallerySection {
            title: "边线和外边框"

            Rectangle {
                width: 420
                height: inner.height + 40
                color: Theme.current.colorFill0

                Column {
                    id: inner

                    x: 20
                    y: 20
                    width: parent.width - 40

                    Card {
                        width: parent.width
                        bordered: false
                        headerLine: true
                        title: "Semi Design"

                        Text {
                            width: parent.width
                            text: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统。"
                                + "设计系统包含设计语言以及一整套可复用的前端组件。")
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                            lineHeight: 20
                            lineHeightMode: Text.FixedHeight
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Note {
                text: qsTr("`bordered` 只管本体那一圈 1px color-border；`headerLine` / `footerLine` "
                    + "各管自己那条线，三条互不相干。缺省 `bordered: true` + `headerLine: true` + "
                    + "`footerLine: false`。")
            }
        }

        GallerySection {
            title: "阴影"

            Column {
                spacing: 16

                Card {
                    width: 360
                    shadows: "hover"

                    Item {
                        width: parent.width
                        height: Math.max(hoverMeta.height, hoverInfo.height)

                        CardMeta {
                            id: hoverMeta

                            title: "Semi Doc"
                            avatar: page.docAvatar
                        }

                        Icon {
                            id: hoverInfo

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            name: "info_circle"
                            color: Theme.current.colorPrimary
                        }

                        Popover {
                            target: hoverInfo
                            text: qsTr("这是一个 Card")
                        }
                    }
                }

                Card {
                    width: 360
                    shadows: "always"

                    Item {
                        width: parent.width
                        height: Math.max(alwaysMeta.height, alwaysInfo.height)

                        CardMeta {
                            id: alwaysMeta

                            title: "Semi Doc"
                            avatar: page.docAvatar
                        }

                        Icon {
                            id: alwaysInfo

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            name: "info_circle"
                            color: Theme.current.colorPrimary
                        }

                        Popover {
                            target: alwaysInfo
                            text: qsTr("这是一个 Card")
                        }
                    }
                }
            }

            Note {
                text: qsTr("`shadows` 只有 hover / always：过渡 300ms（$motion-card-transition_duration "
                    + "是写死的，没走 duration 令牌），而且给了 shadows 就有 `cursor: pointer`。"
                    + "hover 那档官方还有一条 `z-index: 1`，端口落在卡片自己的 `z` 上，只在悬浮期间为 1。")
            }
        }

        GallerySection {
            title: "更灵活的内容展示"

            Card {
                width: 340
                title: page.metaTitle
                headerExtraContent: Component {
                    Text {
                        text: "More"
                        color: Theme.current.colorLink
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
                cover: page.coverPhoto
                footer: page.footerActions
                footerLine: true

                Text {
                    width: parent.width
                    text: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: 20
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }
            }

            Note {
                text: qsTr("官方给 footerStyle 写了 `display: flex; justify-content: flex-end` 把两个按钮"
                    + "推到右边；端口 `footerStyle` 是死 prop，改成 Component 里自己摆 Row。"
                    + "Meta 的标题是 card 自己的令牌 16 / 22 / **700**，比 header 那个 600 重一档。")
            }
        }

        GallerySection {
            title: "内部卡片"

            Card {
                width: 560
                title: "Card title"

                Column {
                    width: parent.width
                    spacing: 20

                    Card {
                        width: parent.width
                        title: "Inner Card title"

                        headerExtraContent: Component {
                            Text {
                                text: "More"
                                color: Theme.current.colorLink
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }

                        Text {
                            text: "Inner Card content"
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }
                    }

                    Card {
                        width: parent.width
                        title: "Inner Card title"

                        headerExtraContent: Component {
                            Text {
                                text: "More"
                                color: Theme.current.colorLink
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }

                        Text {
                            text: "Inner Card content"
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }
                    }
                }
            }

            Note {
                text: qsTr("官方那两张内层卡之间的距离是第一条卡 `style={{ marginBottom: 20 }}` 给的，"
                    + "卡片本身没有任何外边距。")
            }
        }

        GallerySection {
            title: "栅格卡片"

            Rectangle {
                width: 720
                height: gridArea.height + 40
                color: Theme.current.colorFill0

                Column {
                    id: gridArea

                    x: 20
                    y: 20
                    width: parent.width - 40
                    spacing: 16

                    Row {
                        width: parent.width
                                                
                        spacing: 16

                        Column {
                            width: (parent.width - 32) * 8 / 24

                                                        Card {
                                width: parent.width
                                title: "Card Title"
                                bordered: false

                                Text {
                                    text: "Card Content"
                                    color: Theme.current.colorText1
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }
                        }

                        Column {
                            width: (parent.width - 32) * 8 / 24

                                                        Card {
                                width: parent.width
                                title: "Card Title"
                                bordered: false

                                Text {
                                    text: "Card Content"
                                    color: Theme.current.colorText1
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }
                        }

                        Column {
                            width: (parent.width - 32) * 8 / 24

                                                        Card {
                                width: parent.width
                                title: "Card Title"
                                bordered: false

                                Text {
                                    text: "Card Content"
                                    color: Theme.current.colorText1
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                                                
                        spacing: 16

                        Column {
                            width: (parent.width - 16) * 16 / 24

                                                        Card {
                                width: parent.width
                                title: "Card Title"
                                bordered: false

                                Text {
                                    text: "Card Content"
                                    color: Theme.current.colorText1
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }
                        }

                        Column {
                            width: (parent.width - 16) * 8 / 24

                                                        Card {
                                width: parent.width
                                title: "Card Title"
                                bordered: false

                                Text {
                                    text: "Card Content"
                                    color: Theme.current.colorText1
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "内置预加载"

            Column {
                spacing: 16

                Switch {
                    checked: !page.preloading
                    onCheckedChanged: page.preloading = !checked
                }

                Card {
                    width: 360
                    loading: page.preloading

                    CardMeta {
                        title: "Semi Doc"
                        description: "全面、易用、优质"
                    }
                }
            }

            Note {
                text: qsTr("loading 只换内容区：占位是 `Skeleton.Title` + 一个 `<br/>` +"
                    + " `Skeleton.Paragraph rows={3}` ⇒ 24 + 20 + 68 = 112 高（那个空行盒吃的是卡片的 20 行高）。"
                    + "而且官方写的是 `{children && <Skeleton …>}` —— 一张**没有 children 的卡**"
                    + "`loading: true` 什么占位都不出，只剩那 40 的内边距。")
            }
        }

        GallerySection {
            title: "更丰富的预加载效果"

            Column {
                spacing: 16

                Switch {
                    checked: !page.richLoading
                    onCheckedChanged: page.richLoading = !checked
                }

                Card {
                    width: 300

                    title: Component {
                        CardMeta {
                            title: Component {
                                Skeleton {
                                    width: 80
                                    loading: page.richLoading
                                    active: true

                                    placeholder: Component {
                                        SkeletonTitle {}
                                    }

                                    Text {
                                        text: "Semi Doc"
                                        color: Theme.current.colorText0
                                        font.pixelSize: Theme.current.fontSizeHeader5
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            description: Component {
                                Skeleton {
                                    width: 150
                                    loading: page.richLoading
                                    active: true

                                    placeholder: Component {
                                        SkeletonParagraph {
                                            rows: 1
                                        }
                                    }

                                    Text {
                                        text: qsTr("全面、易用、优质")
                                        color: Theme.current.colorText2
                                        font.pixelSize: Theme.current.fontSizeRegular
                                    }
                                }
                            }

                            avatar: Component {
                                Skeleton {
                                    width: 40
                                    height: 40
                                    loading: page.richLoading
                                    active: true

                                    placeholder: Component {
                                        SkeletonAvatar {}
                                    }

                                    Avatar {
                                        text: "S"
                                        backgroundColor: "#0064fa"
                                    }
                                }
                            }
                        }
                    }

                    headerExtraContent: Component {
                        Skeleton {
                            width: 50
                            loading: page.richLoading
                            active: true

                            placeholder: Component {
                                SkeletonParagraph {
                                    rows: 1
                                }
                            }

                            Text {
                                text: "More"
                                color: Theme.current.colorLink
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }
                    }

                    cover: Component {
                        Skeleton {
                            width: 300
                            height: 220
                            loading: page.richLoading
                            active: true

                            placeholder: Component {
                                SkeletonImage {}
                            }
                        }
                    }
                }
            }

            Note {
                text: qsTr("卡片自带的 loading 只管内容区；要连标题、附加、封面一起占位，就按官方那样"
                    + "往各个 ReactNode 里塞 `Skeleton`。端口 `Skeleton` 没有 style ⇒ 尺寸直接写"
                    + " `width` / `height`；`Skeleton.Image` 自己不带尺寸，宽高全靠容器。")
            }
        }

        GallerySection {
            title: "带页签的卡片"

            Card {
                width: 560
                title: "Card title"

                Column {
                    width: parent.width
                    spacing: 0

                    Tabs {
                        width: parent.width
                        activeKey: String(page.tabIndex)
                        tabList: [
                            { itemKey: "0", tab: "Tab 1" },
                            { itemKey: "1", tab: "Tab 2" }
                        ]
                        onTabClick: key => page.tabIndex = Number(key)
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.current.spacingBaseTight
                        visible: page.tabIndex === 0

                        Text {
                            text: "content1"
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }

                        Text {
                            text: "content1"
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }

                        Text {
                            text: "content1"
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.current.spacingBaseTight
                        visible: page.tabIndex === 1

                        Text {
                            text: "content2"
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }

                        Text {
                            text: "content2"
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }

                        Text {
                            text: "content2"
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }
                    }
                }
            }

            Note {
                text: qsTr("官方那节给 Tabs 写了 `style={{ marginTop: -20, marginBottom: -20 }}` 去抵掉"
                    + "卡片正文的 20 内边距 —— 端口那条负 margin 无处落地，页签就老老实实缩在正文里。")
            }
        }

        GallerySection {
            title: "卡片操作区"

            Card {
                width: 300
                actions: [page.ratingAction]
                headerLine: false
                cover: page.coverPhoto

                CardMeta {
                    title: "Semi Doc"
                    description: "全面、易用、优质"
                }
            }

            Note {
                text: qsTr("`actions` 的判据是 `Array.isArray`，不是「有没有内容」⇒ "
                    + "`actions: []` 也会画那条 41 高的空操作区（margin-top 20 + 1px 线 + padding-top 20）。"
                    + "条目之间 12 是 index.tsx 里写死的 `spacing={12}`，不是令牌。")
            }
        }

        GallerySection {
            title: "卡片组"

            Column {
                spacing: 16

                Text {
                    text: qsTr("滑动调节 Card 间距：%1").arg(page.groupSpacing)
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Slider {
                    width: 360
                    min: 10
                    max: 40
                    value: page.groupSpacing
                    // 属性变化处理器的 value 注入是 QML 正式支持的形态（不是被弃用的信号参数注入）
                    onValueChanged: page.groupSpacing = value
                }

                CardGroup {
                    width: 880
                    spacing: page.groupSpacing

                    Repeater {
                        model: 8

                        delegate: Card {
                            required property int index

                            width: 260
                            shadows: "hover"
                            title: "Card title"
                            headerLine: false

                            headerExtraContent: Component {
                                Text {
                                    text: "More"
                                    color: Theme.current.colorLink
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }

                            Text {
                                text: "Card content"
                                color: Theme.current.colorText1
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }
                    }
                }
            }

            Note {
                text: qsTr("CardGroup 本体就是一层 `Space`：`wrap` 打开、缺省 `align-items: center`"
                    + "（所以一行里矮的卡片是垂直居中的，不是贴顶也不是拉伸）。"
                    + "`spacing` 的缺省，**代码里是 16**，API 表写的是 12px —— 端口取代码那条。")
            }
        }

        GallerySection {
            title: "网格型卡片组"

            CardGroup {
                width: 780
                type: "grid"

                Repeater {
                    model: 7

                    delegate: Card {
                        required property int index

                        width: 260
                        shadows: "hover"
                        title: "Card title"
                        headerLine: false

                        headerExtraContent: Component {
                            Text {
                                text: "More"
                                color: Theme.current.colorLink
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }

                        Text {
                            text: "Card content"
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }
                    }
                }
            }

            Note {
                text: qsTr("`type: 'grid'` 会把 `spacing` 强制清 0，另外 card.scss 还有两条后代规则："
                    + "成员卡圆角清 0、每张 `margin-left / margin-top: -1px` ⇒ 相邻两张重叠 1 像素、"
                    + "两条描边合成一条。端口没有 CSS，圆角那条由 CardGroup 逐张下发 `cardGroupGrid`。")
            }
        }
    }

    // 说明里会出现 `{ text: ... }`、`rows={3}` 这类尖括号与花括号 ⇒ 钉 PlainText
    component Note: Text {
        width: 700
        textFormat: Text.PlainText
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
