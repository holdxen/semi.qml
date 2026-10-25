pragma ComponentBehavior: Bound

import QtQuick
import Semi

// List 列表。官方 `content/show/list/index.md` 的「代码演示」一共 15 个小节，这里逐节摆齐：
// 如何引入 / 基本用法 / 模板用法 / 布局 / 栅格列表 / 响应式的栅格列表 / 加载更多 /
// 滚动加载 / 滚动加载无限长列表 / 拖拽排序 / 带分页器 / 带筛选器 / 添加删除项 /
// 单选或多选 / 响应键盘事件。
//
// 官方有几节本来就是「组合」而不是组件能力（分页器、筛选器、增删、选择、键盘），端口照做。
// 三节依赖前端库的换了等价物，逐节下面的说明都写清了换成什么：
//   · 滚动加载 = react-infinite-scroller → Flickable 的 atYEnd
//   · 无限长列表 = react-virtualized 的 VList → ListView（List 在这节只提供外框）
//   · 拖拽排序 = dnd-kit → DragHandler + 索引交换
//
// 「栅格列表」那节在官方那一张之外多摆了三张（offset / push / pull）—— 官方文档没有这几档
// 的 demo，但 Col 的五个属性是 List 的 `grid` 能写的，端口排了就一并演，标在节内的说明里。
// 书单的悬浮底色用官方那对回调（mouseEntered / mouseLeft），不是页面自己挂的 handler。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ---------------------------------------------------------------- 官方 demo 数据
    readonly property var poem: [
        "从明天起，做一个幸福的人",
        "喂马，劈柴，周游世界",
        "从明天起，关心粮食和蔬菜",
        "我有一所房子，面朝大海，春暖花开"
    ]

    readonly property var articles: [
        { "body": "Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统。"
                + "设计系统包含设计语言以及一整套可复用的前端组件，帮助设计师与开发者更容易地"
                + "打造高质量的、用户体验一致的、符合设计规范的 Web 应用。", "clamp": true },
        { "body": "Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统。"
                + "设计系统包含设计语言以及一整套可复用的前端组件，帮助设计师与开发者更容易地"
                + "打造高质量的、用户体验一致的、符合设计规范的 Web 应用。", "clamp": false },
        { "body": "Semi Design 以用户中心、内容优先、设计人性化的设计系统，"
                + "打造一致、好看、好用、高效的用户体验。", "clamp": false }
    ]

    readonly property var titles: [
        { "title": "Semi Design Title 1" },
        { "title": "Semi Design Title 2" },
        { "title": "Semi Design Title 3" }
    ]

    readonly property var apps: [
        { "title": "Semi UI", "rating": 4.5, "feedbacks": 124 },
        { "title": "Semi DSM", "rating": 4, "feedbacks": 108 },
        { "title": "Semi D2C", "rating": 4.5, "feedbacks": 244 }
    ]

    readonly property var platforms: [
        { "title": "审核管理平台", "rating": 4.5, "feedbacks": 124 },
        { "title": "扁鹊", "rating": 4, "feedbacks": 108 },
        { "title": "直播审核平台", "rating": 3.5, "feedbacks": 244 },
        { "title": "抖音安全测试", "rating": 0, "feedbacks": 189 },
        { "title": "内容平台", "rating": 3, "feedbacks": 128 },
        { "title": "策略平台", "rating": 4, "feedbacks": 156 }
    ]

    readonly property var books: [
        "围城", "平凡的世界（全三册）", "三体（全集）", "雪中悍刀行（全集）", "撒哈拉的故事",
        "明朝那些事", "一禅小和尚", "沙丘", "被讨厌的勇气", "罪与罚",
        "月亮与六便士", "沉默的大多数", "第一人称单数"
    ]

    function longList(n) {
        const out = [];
        for (let i = 0; i < n; ++i)
            out.push({ "title": "Semi Design Title " + i });
        return out;
    }

    // ---------------------------------------------------------------- 各节自己维护的状态
    // 加载更多：官方每页 3 条，先用 3 个 loading 的骨架顶上，1s 后换成真的
    property var feed: []
    property int feedPage: 0
    property bool feedLoading: false
    readonly property int feedPageSize: 3
    readonly property var feedAll: page.longList(40)

    // 滚动加载：官方滚到底就取，四次里的一次改摆按钮（demo 自己算 countRef % 4 === 0）
    property var scrollData: []
    property int scrollPage: 0
    property bool scrollLoading: false
    readonly property var scrollAll: page.longList(100)
    readonly property bool scrollHasMore: page.scrollData.length < page.scrollAll.length
    readonly property bool scrollShowButton: page.scrollPage % 4 === 0

    // 无限长列表：先给 20 条，滚到底再补 10 条
    property var virtualData: []
    readonly property var virtualAll: page.longList(50)

    // 拖拽排序
    property var dragItems: [
        { "id": 1, "title": "Semi Design Title 1" },
        { "id": 2, "title": "Semi Design Title 2" },
        { "id": 3, "title": "Semi Design Title 3" },
        { "id": 4, "title": "Semi Design Title 4" },
        { "id": 5, "title": "Semi Design Title 5" }
    ]
    property int dragId: -1

    // 分页 / 筛选 / 增删 / 选择 / 键盘
    property int pageNo: 1
    readonly property int pageSize: 4
    property string keyword: ""
    readonly property var filtered: page.books.filter(
        b => page.keyword === "" || b.indexOf(page.keyword) >= 0)
    property var shelf: page.books.slice(0, 8)
    property string picked: "围城"
    property var chosen: ["平凡的世界（全三册）"]
    property int hoverIndex: -1

    function fetchFeed() {
        if (page.feedLoading || page.feed.length >= page.feedAll.length)
            return;
        const placeholders = [];
        for (let i = 0; i < page.feedPageSize; ++i)
            placeholders.push({ "title": "", "loading": true });
        page.feed = page.feed.concat(placeholders);
        page.feedLoading = true;
        feedTimer.start();
    }

    function resolveFeed() {
        const start = page.feedPage * page.feedPageSize;
        const next = page.feedAll.slice(start, start + page.feedPageSize);
        page.feedPage++;
        // 把刚才那三条骨架换成正文（官方是整表重建，这里等价）
        page.feed = page.feed.slice(0, page.feed.length - page.feedPageSize).concat(next);
        page.feedLoading = false;
    }

    function fetchScroll() {
        if (page.scrollLoading || page.scrollData.length >= page.scrollAll.length)
            return;
        page.scrollLoading = true;
        scrollTimer.start();
    }

    function resolveScroll() {
        const start = page.scrollPage * 5;
        const next = page.scrollAll.slice(start, start + 5);
        page.scrollPage++;
        page.scrollData = page.scrollData.concat(next);
        page.scrollLoading = false;
    }

    function fetchVirtual(count) {
        const next = page.virtualAll.slice(page.virtualData.length, page.virtualData.length + count);
        page.virtualData = page.virtualData.concat(next);
    }

    // 官方 dnd-kit 收尾用的 arrayMove
    function moveItem(from, to) {
        if (from === to || from < 0 || to < 0)
            return;
        const next = page.dragItems.slice();
        const moved = next.splice(from, 1)[0];
        next.splice(to, 0, moved);
        page.dragItems = next;
    }

    function stepHover(offset) {
        let index = page.hoverIndex + offset;
        if (index < 0)
            index = 9;
        if (index >= 10)
            index = 0;
        page.hoverIndex = index;
    }

    function growShelf() {
        if (page.shelf.length >= page.books.length)
            return;
        page.shelf = page.shelf.concat(
            page.books.slice(page.shelf.length, page.shelf.length + 1));
    }

    Timer {
        id: feedTimer

        interval: 1000
        onTriggered: page.resolveFeed()
    }

    Timer {
        id: scrollTimer

        interval: 1000
        onTriggered: page.resolveScroll()
    }

    Component.onCompleted: {
        page.fetchFeed();
        page.fetchScroll();
        page.fetchVirtual(20);
    }

    // ---------------------------------------------------------------- 可复用节点
    component Note: Text {
        width: 700
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    // 官方好几节外面套了一层「padding 12 + 1px 描边」的 div（那是 demo 自己的 style），
    // 组件没有 style ⇒ 端口把这层壳做出来，免得每节手抄
    component Framed: Rectangle {
        default property alias content: inner.data

        // 官方那层壳的高度是跟着内容走的（div 的自动高），端口得自己把内容的隐式高抬上来
        implicitHeight: inner.implicitHeight + 24
        color: "transparent"
        border.width: 1
        border.color: Theme.current.colorBorder

        Column {
            id: inner

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 12
        }
    }

    // 书单那几节共用的条目。官方的 .list-item:hover / :active 是 demo 自带的一段 CSS
    // （index.md:1168-1188），组件本身没有悬浮态 ⇒ 底色仍然走 background 槽，
    // 但「悬没悬」用官方那对回调（item.tsx:20-21 的 onMouseEnter / onMouseLeave，
    // 端口叫 mouseEntered / mouseLeft），不再自己挂一只 HoverHandler。
    // 「响应键盘事件」给当前项铺的那层 fill-0 也走这里。
    component BookRow: ListItem {
        id: row

        required property var modelData
        required property int index

        property bool hovered: false

        implicitWidth: 280

        onMouseEntered: row.hovered = true
        onMouseLeft: row.hovered = false

        background: Component {
            Rectangle {
                anchors.fill: parent
                color: row.hovered || row.index === page.hoverIndex
                    ? Theme.current.colorFill0 : "transparent"
            }
        }

        Text {
            text: String(row.modelData)
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
        }
    }

    // 加载更多 / 滚动加载 / 无限长列表共用的「头像 + 标题 + 一段正文」
    component PostItem: ListItem {
        id: post

        property string title: ""
        property bool busy: false

        header: Component {
            Avatar {
                text: "SE"
                size: "small"
            }
        }

        main: Component {
            Column {
                spacing: 4

                Text {
                    visible: !post.busy
                    text: post.title
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                    lineHeight: 20
                    lineHeightMode: Text.FixedHeight
                }

                Text {
                    visible: !post.busy
                    width: 520
                    text: "Semi Design 设计系统包含设计语言以及一整套可复用的前端组件，"
                        + "帮助设计师与开发者更容易地打造高质量的、用户体验一致的、符合设计规范的"
                        + "Web 应用。"
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                    lineHeight: 20
                    lineHeightMode: Text.FixedHeight
                }
            }
        }
    }

    // 栅格两节的卡片正文（官方用 Descriptions + ButtonGroup，卡片描边写在 demo 的 style 里）
    component GridCard: ListItem {
        id: card

        required property var modelData

        // 官方是 `<List.Item style={{ border, bg-2, radius 3, paddingLeft: 20 }}>` —— 描边挂在
        // li 自己身上，所以标题也在框里面。端口没有 style，那圈描边走 background 槽；
        // 上下那截留白是官方 h3 自带的外边距（浏览器默认 ≈13px），也一并挪进内容那一列，
        // 让「li 的高 = 内容的高」，描边才包得住整条。
        implicitHeight: band.height

        background: Component {
            Rectangle {
                objectName: "cardShell"

                anchors.fill: parent
                color: Theme.current.colorBg2
                radius: 3
                border.width: 1
                border.color: Theme.current.colorBorder
            }
        }

        Column {
            id: band

            topPadding: 12
            bottomPadding: 12
            leftPadding: 20
            rightPadding: 12
            width: card.width
            spacing: 4

            Text {
                text: card.modelData.title
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeHeader5
                font.weight: Font.DemiBold
            }

            Descriptions {
                width: band.width - band.leftPadding - band.rightPadding
                dataList: [
                    { "key": qsTr("满意度"), "value": String(card.modelData.rating) },
                    { "key": qsTr("反馈数"), "value": String(card.modelData.feedbacks) }
                ]
            }

            ButtonGroup {
                Button {
                    text: qsTr("编辑")
                    variant: Enums.Borderless
                }

                Button {
                    text: qsTr("更多")
                    variant: Enums.Borderless
                }
            }
        }
    }

    // 拖拽排序那一行：官方把 List.Item 包在一个带描边的 div 里，dnd-kit 的 listeners
    // 也挂在那一层 ⇒ 端口的按键也收在包的一层（条目因此拿不到 hasSeam，官方同理没线）
    component DragRow: Rectangle {
        id: wrap

        required property var modelData
        required property int index

        readonly property bool dragging: page.dragId === wrap.modelData.id

        implicitHeight: row.implicitHeight + 12        // 官方 demo 给的是 marginBottom: 12
        color: dragging ? Theme.current.colorBg0 : "transparent"
        border.width: 1
        border.color: Theme.current.colorBorder

        ListItem {
            id: row

            width: parent.width

            header: Component {
                Avatar {
                    text: "SE"
                    size: "small"
                }
            }

            main: Component {
                Column {
                    spacing: 4

                    Text {
                        text: wrap.modelData.title
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: 480
                        text: "Semi Design 设计系统包含设计语言以及一整套可复用的前端组件，"
                            + "帮助设计师与开发者更容易地打造高质量的、用户体验一致的、符合设计规范的"
                            + "Web 应用。"
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeRegular
                        wrapMode: Text.WordWrap
                        lineHeight: 20
                        lineHeightMode: Text.FixedHeight
                    }
                }
            }
        }

        DragHandler {
            id: grab

            target: null
            acceptedButtons: Qt.LeftButton
            dragThreshold: 1                        // 官方 MouseSensor 的 activationConstraint.distance
            cursorShape: Qt.ClosedHandCursor

            onActiveChanged: page.dragId = active ? wrap.modelData.id : -1

            onCentroidChanged: {
                if (!active)
                    return;
                // 官方 restrictToVerticalAxis：只看纵向落点
                const local = dragList.mapFromItem(wrap, centroid.position.x, centroid.position.y);
                const nodes = dragList.itemNodes();
                let target = -1;
                for (let i = 0; i < nodes.length; ++i) {
                    if (local.y >= nodes[i].y && local.y < nodes[i].y + nodes[i].height) {
                        target = i;
                        break;
                    }
                }
                if (target < 0)
                    return;
                const from = page.dragItems.findIndex(it => it.id === wrap.modelData.id);
                if (from !== target)
                    page.moveItem(from, target);
            }
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Column {
                width: parent.width
                spacing: 12

                Text {
                    text: qsTr("List 自 0.x 就有；官方 List 的 API 表里没有给各属性标支持版本，这里也不猜。")
                    font.pixelSize: Theme.current.fontSizeRegular
                    color: Theme.current.colorText1
                }

                Text {
                    width: 700
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    color: Theme.current.colorText0
                    font.family: "Menlo"
                    font.pixelSize: 13
                    text: "import Semi\n\nList {\n    width: 520\n    header: \"Header\"\n    footer: \"Footer\"\n    bordered: true\n    dataSource: [\"甲\", \"乙\"]\n    renderItem: Component { ListItem { Text { text: String(modelData) } } }\n}"
                }

                Note {
                    text: qsTr("官方的 ReactNode 属性（header / footer / loadMore / emptyContent / main / extra）"
                        + "在本库统一写成「字符串或 Component」：`main: Column { … }` 这种内联节点接不住，"
                        + "要写 `main: Component { Column { … } }`。style / className 不收（没有 CSS）。")
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 700
                spacing: 16

                Repeater {
                    model: ["default", "small", "large"]

                    delegate: Column {
                        id: sizeBlock

                        required property var modelData

                        spacing: 16
                        width: parent ? parent.width : 0

                        Text {
                            text: sizeBlock.modelData === "default" ? qsTr("默认尺寸")
                                : (sizeBlock.modelData === "small" ? qsTr("小尺寸") : qsTr("大尺寸"))
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeHeader5
                        }

                        List {
                            width: 520
                            size: sizeBlock.modelData
                            header: "Header"
                            footer: "Footer"
                            bordered: true
                            dataSource: page.poem

                            renderItem: Component {
                                ListItem {
                                    id: poemRow

                                    required property var modelData

                                    Text {
                                        text: String(poemRow.modelData)
                                        color: Theme.current.colorText0
                                        font.pixelSize: Theme.current.fontSizeRegular
                                        lineHeight: 20
                                        lineHeightMode: Text.FixedHeight
                                    }
                                }
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("size 只作用在条目 / header / footer 的内边距上（默认上下 12 左右 24、"
                        + "small 8/16、large 16/24）；bordered 缺省 false、split 缺省 true。"
                        + "header 与 footer 官方是 ReactNode：给字符串就是一行字，给 Component 就能摆任意节点"
                        + "（「带筛选器」那一节往里塞了个 Input）。")
                }
            }
        }

        GallerySection {
            title: "模板用法"

            Column {
                width: 740
                spacing: 12

                Framed {
                    width: 740

                    List {
                        width: parent.width
                        dataSource: page.articles

                        renderItem: Component {
                            ListItem {
                                id: articleRow

                                required property var modelData

                                header: Component {
                                    Avatar {
                                        text: "SE"
                                        size: "small"
                                    }
                                }

                                main: Component {
                                    Column {
                                        spacing: 4

                                        Text {
                                            text: qsTr("示例标题")
                                            color: Theme.current.colorText0
                                            font.pixelSize: Theme.current.fontSizeRegular
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            width: articleRow.modelData.clamp ? 420 : 500
                                            text: articleRow.modelData.body
                                            color: Theme.current.colorText2
                                            font.pixelSize: Theme.current.fontSizeRegular
                                            elide: articleRow.modelData.clamp
                                                ? Text.ElideRight : Text.ElideNone
                                            wrapMode: articleRow.modelData.clamp
                                                ? Text.NoWrap : Text.Wrap
                                            lineHeight: 20
                                            lineHeightMode: Text.FixedHeight
                                        }
                                    }
                                }

                                extra: Component {
                                    ButtonGroup {
                                        Button {
                                            text: qsTr("编辑")
                                            variant: Enums.Borderless
                                        }

                                        Button {
                                            text: qsTr("更多")
                                            variant: Enums.Borderless
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Framed {
                    width: 740

                    List {
                        width: parent.width
                        dataSource: page.articles

                        renderItem: Component {
                            ListItem {
                                id: alignedRow

                                required property var modelData

                                align: "center"

                                header: Component {
                                    Avatar {
                                        text: "SE"
                                        size: "large"
                                    }
                                }

                                main: Component {
                                    Text {
                                        width: 460
                                        text: alignedRow.modelData.body
                                        color: Theme.current.colorText2
                                        font.pixelSize: Theme.current.fontSizeRegular
                                        wrapMode: Text.Wrap
                                        lineHeight: 20
                                        lineHeightMode: Text.FixedHeight
                                    }
                                }
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("List.Item 内置三段：header / main / extra。main 那一格 flex:1，富余宽度全归它；"
                        + "header 与 main 之间 20，extra 左边 40。align 只管 header 与 main 的纵向对齐"
                        + "（flex-start 默认 / flex-end / center / baseline / stretch）—— 上图是默认"
                        + "（正文顶对齐），下图把头像换大、align 给 center 就能看出差别。"
                        + "baseline 端口落回 flex-start；stretch 只把那一格拉高，不撑开塞进去的节点。")
                }
            }
        }

        GallerySection {
            title: "布局"

            Column {
                width: 740
                spacing: 12

                Framed {
                    width: 740

                    List {
                        width: parent.width
                        layout: "horizontal"
                        dataSource: page.titles

                        renderItem: Component {
                            ListItem {
                                id: titleRow

                                required property var modelData

                                implicitWidth: 220

                                header: Component {
                                    Avatar {
                                        text: "SE"
                                        size: "small"
                                    }
                                }

                                main: Component {
                                    Column {
                                        spacing: 4

                                        Text {
                                            text: titleRow.modelData.title
                                            color: Theme.current.colorText0
                                            font.pixelSize: Theme.current.fontSizeRegular
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            width: 120
                                            text: "Semi Design"
                                            color: Theme.current.colorText2
                                            font.pixelSize: Theme.current.fontSizeRegular
                                            wrapMode: Text.Wrap
                                            lineHeight: 20
                                            lineHeightMode: Text.FixedHeight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("layout 只有 vertical（默认）与 horizontal 两档，官方改的也只有一条 "
                        + "`.semi-list-items{display:flex}`：条目按内容宽横排、交叉轴 stretch 所以同排等高，"
                        + "分割线从底边换到右边（末条同样不画）。header / footer 仍是整幅的块，不跟着躺平。")
                }
            }
        }

        GallerySection {
            title: "栅格列表"

            Column {
                width: 740
                spacing: 12

                List {
                    width: 740
                    grid: ({ gutter: 12, span: 6 })
                    dataSource: page.apps

                    renderItem: Component {
                        GridCard {}
                    }
                }

                GalleryLabel {
                    text: qsTr("offset: 2 —— 每格多让出两格的 margin-left（752/24×2 ≈ 63 px），"
                        + "它占格，所以一行从四条挤成三条")
                }

                List {
                    width: 740
                    grid: ({ gutter: 12, span: 6, offset: 2 })
                    dataSource: page.platforms

                    renderItem: Component {
                        GridCard {}
                    }
                }

                GalleryLabel {
                    text: qsTr("push: 2 —— 同样的两格是相对位移：宽与换行都不变，整排被推出容器"
                        + "（官方 relative 不裁剪，端口同样不夹）")
                }

                List {
                    width: 740
                    grid: ({ gutter: 12, span: 8, push: 2 })
                    dataSource: page.apps

                    renderItem: Component {
                        GridCard {}
                    }
                }

                GalleryLabel {
                    text: qsTr("pull: 2 —— 往左，第一条探出容器的左边缘")
                }

                List {
                    width: 740
                    grid: ({ gutter: 12, span: 8, pull: 2 })
                    dataSource: page.apps

                    renderItem: Component {
                        GridCard {}
                    }
                }

                Note {
                    text: qsTr("grid 把 items 容器换成 Grid 的 Row/Col：span 6 = 一格占 6/24（一行四条），"
                        + "gutter 是格间距。这一档条目内边距被官方清成 0，卡片描边由 demo 自己画；"
                        + "又因为每条独占一个 Col（它自己就是 :last-child），split 的开线规则一条都不命中 —— "
                        + "所以上图看不到横线。Col 那五个属性都排：span（宽）、offset（margin-left，占格）、"
                        + "push / pull（left / right，只挪像素）；同时给 push 与 pull 时按 CSS 的 "
                        + "over-constrained 规则 left 赢。给 0 或负数等于没给 —— 样式表里只有 "
                        + "-offset-1..24，没有 -offset-0。order 收了也不生效：官方那个 grid 对象是原样摊给"
                        + "每一条 Col 的（item.tsx:50-58），所有 Col 拿到同一个 order，flex 里等值即保持"
                        + "源码顺序，List 压根没有「单独给某一条改序」的入口。")
                }
            }
        }

        GallerySection {
            title: "响应式的栅格列表"

            Column {
                width: 740
                spacing: 12

                List {
                    id: respList

                    width: 740
                    grid: ({ gutter: 12, xs: 0, sm: 0, md: 12, lg: 8, xl: 8, xxl: 6 })
                    dataSource: page.platforms

                    renderItem: Component {
                        GridCard {}
                    }
                }

                Note {
                    text: qsTr("档位照官方 media query：xs 那条规则没包在 media query 里所以恒生效、"
                        + "sm≥576、md≥768、lg≥992、xl≥1200、xxl≥1600，越靠后的档赢。"
                        + "官方读浏览器视口，端口没有视口，用所在 Window 的宽度顶替 —— 当前 %1 px，"
                        + "解析成 span %2。注意 demo 把 xs / sm 都写成 0，而 -col-0 是 display:none ⇒ "
                        + "窗口窄于 768 时整个栅格一条都不显示，这是官方 demo 自己的行为，端口照抄。"
                        + "档位也能写成对象带 offset / push / pull（`md: { span: 8, offset: 2 }`），"
                        + "而且是**按属性各取各的**：后一档只改写自己给了值的那几项，"
                        + "`md: { span: 6 }` 清不掉 `sm: { offset: 2 }` 那条 —— 数字档只带 span。").arg(
                        Math.round(respList.viewportWidth)).arg(respList.colSpan())
                }
            }
        }

        GallerySection {
            title: "加载更多"

            Column {
                width: 740
                spacing: 12

                List {
                    width: 740
                    loading: page.feedLoading
                    dataSource: page.feed
                    loadMore: page.feedLoading || page.feed.length >= page.feedAll.length
                        ? undefined : loadMoreNode

                    renderItem: Component {
                        Skeleton {
                            id: feedSlot

                            required property var modelData

                            loading: modelData.loading === true
                            placeholder: Component {
                                Row {
                                    spacing: 12

                                    SkeletonAvatar {}

                                    Column {
                                        spacing: 12

                                        SkeletonTitle {
                                            width: 120
                                        }

                                        SkeletonParagraph {
                                            width: 600
                                            rows: 2
                                        }
                                    }
                                }
                            }

                            PostItem {
                                title: feedSlot.modelData.title
                                busy: feedSlot.modelData.loading === true
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("loadMore 是挂在最末一段的裸节点（官方没有内置按钮，demo 自己给一个 Button，"
                        + "取完把这节点置空）。loading 只把 Spin 套在 items 那一段外面：内容压到 0.5、"
                        + "指示符居中、再盖一层透明遮罩挡住穿透点击。官方每条外面用 Skeleton 包了一层占位 —— "
                        + "包了之后条目就不是容器的最后一个孩子，而它自己永远是所在那一层的 last-child ⇒ "
                        + "这一节一条分割线都没有，端口同样。点「显示更多」看骨架 1s 后换成正文。")
                }

                Component {
                    id: loadMoreNode

                    Button {
                        text: qsTr("显示更多")
                        onClicked: page.fetchFeed()
                    }
                }
            }
        }

        GallerySection {
            title: "滚动加载"

            Column {
                width: 740
                spacing: 12

                Rectangle {
                    width: 740
                    height: 420
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.current.colorBorder

                    Flickable {
                        id: scroller

                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        contentWidth: width
                        contentHeight: scrollList.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        onAtYEndChanged: {
                            if (atYEnd && !page.scrollShowButton)
                                page.fetchScroll();
                        }

                        List {
                            id: scrollList

                            width: parent.width
                            dataSource: page.scrollData
                            loadMore: page.scrollLoading || !page.scrollShowButton
                                || !page.scrollHasMore ? undefined : scrollMoreNode

                            renderItem: Component {
                                PostItem {
                                    required property var modelData

                                    title: modelData.title
                                }
                            }
                        }
                    }

                    Spin {
                        visible: page.scrollLoading && page.scrollHasMore
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                    }
                }

                Note {
                    text: qsTr("官方这节集成 react-infinite-scroller（threshold 20、useWindow=false）："
                        + "滚到底就取下一页，四次里的一次改摆按钮（demo 自己算 countRef % 4 === 0），"
                        + "底部那只 Spin 也是 demo 摆的。端口用 Flickable 的 atYEnd 顶替 IntersectionObserver，"
                        + "List 与按钮 / Spin 的组合关系不变。")
                }

                Component {
                    id: scrollMoreNode

                    Button {
                        text: qsTr("显示更多")
                        onClicked: page.fetchScroll()
                    }
                }
            }
        }

        GallerySection {
            title: "滚动加载无限长列表"

            Column {
                width: 740
                spacing: 12

                List {
                    width: 740
                    bordered: true

                    // 官方把 react-virtualized 的 VList 当 children 塞进来（height 500、
                    // rowHeight 118）：虚拟化不是 List 的能力，这节 List 只是外框。
                    // 端口的等价物就是 ListView —— 它本来就只实例化可见项。
                    Item {
                        implicitWidth: 738
                        implicitHeight: 500

                        ListView {
                            id: virtualView

                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            model: page.virtualData
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: PostItem {
                                required property var modelData
                                required property int index

                                width: virtualView.width
                                title: modelData.title
                            }

                            onAtYEndChanged: {
                                if (atYEnd && page.virtualData.length < page.virtualAll.length)
                                    page.fetchVirtual(10);
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("这一节 List 只提供外框：它不滚动也不虚拟化，虚拟化全在 children 那一层"
                        + "（官方 react-virtualized，端口 ListView）。官方那串 style 是 1px 描边 + 内边距 10，"
                        + "端口只落得下描边（bordered），10 的内缩由里面那层 Item 承担。"
                        + "另外：dataSource 生成的条目与 children 会同时渲染（这一节没给 dataSource）—— 端口同口径。")
                }
            }
        }

        GallerySection {
            title: "拖拽排序"

            Column {
                width: 740
                spacing: 12

                Framed {
                    width: 740

                    List {
                        id: dragList

                        width: parent.width
                        dataSource: page.dragItems

                        renderItem: Component {
                            DragRow {}
                        }
                    }
                }

                Note {
                    text: qsTr("官方整节靠 dnd-kit（DndContext + useSortable + restrictToVerticalAxis），"
                        + "List 本身完全不参与拖拽，只是被 renderItem 交出条目。端口没有 dnd-kit，"
                        + "用 DragHandler + 索引交换顶替：按住一条往下拖，落点进了邻居的矩形就 arrayMove，"
                        + "拖起来那一条按官方样式给白底 + 描边。每行外面同样包了一层带描边的 div ⇒ "
                        + "和「加载更多」那节一样，这节的分割线也一条都不出现。")
                }
            }
        }

        GallerySection {
            title: "带分页器"

            Column {
                width: 760
                spacing: 12

                List {
                    width: 280
                    size: "small"
                    split: false
                    bordered: true
                    dataSource: page.books.slice((page.pageNo - 1) * page.pageSize,
                        page.pageNo * page.pageSize)

                    renderItem: Component {
                        BookRow {}
                    }
                }

                Pagination {
                    size: Enums.Small
                    total: page.books.length
                    pageSize: page.pageSize
                    currentPage: page.pageNo
                    onChange: function (p) { page.pageNo = p; }
                }

                Note {
                    text: qsTr("官方也是把 Pagination 摆在 List 外面，靠把 dataSource 换成「当前页那几条」联动；"
                        + "这一节 demo 把 split 关了（所以没有条目间的横线），外框靠 bordered。"
                        + "悬浮变灰是 demo 自己那段 CSS（组件没有悬浮态），端口把它写进了条目节点。")
                }
            }
        }

        GallerySection {
            title: "带筛选器"

            Column {
                width: 760
                spacing: 12

                List {
                    width: 280
                    size: "small"
                    split: false
                    bordered: true
                    header: searchNode
                    dataSource: page.filtered
                    emptyContent: qsTr("没有匹配的书名")

                    renderItem: Component {
                        BookRow {}
                    }
                }

                Note {
                    text: qsTr("header 是 ReactNode ⇒ 官方直接往列表头部塞了一个带放大镜图标的 Input"
                        + "（demo 里还挂 onCompositionEnd，输入法打字的中间态不触发筛选）。"
                        + "端口 header 收 Component，于是搜索框成了列表的一部分；筛空了会掉进空态，"
                        + "可以输入「不存在的书」试试（空态文案走 emptyContent，缺省是 locale 的「暂无数据」）。")
                }

                Component {
                    id: searchNode

                    Input {
                        width: 232
                        placeholderText: qsTr("搜索")
                        prefixIcon: "search"
                        onTextChanged: page.keyword = text
                    }
                }
            }
        }

        GallerySection {
            title: "添加删除项"

            Column {
                width: 760
                spacing: 12

                List {
                    width: 280
                    size: "small"
                    split: false
                    bordered: true
                    dataSource: page.shelf

                    renderItem: Component {
                        ListItem {
                            id: shelfRow

                            required property var modelData

                            implicitWidth: 280

                            Button {
                                icon: "minus_circle"
                                tone: Enums.Danger
                                variant: Enums.Borderless
                                ariaLabel: qsTr("移除")
                                onClicked: page.shelf = page.shelf.filter(b => b !== shelfRow.modelData)
                            }

                            Text {
                                text: String(shelfRow.modelData)
                                color: Theme.current.colorText0
                                font.pixelSize: Theme.current.fontSizeRegular
                                lineHeight: 20
                                lineHeightMode: Text.FixedHeight
                            }
                        }
                    }
                }

                Row {
                    spacing: 4

                    Button {
                        icon: "plus_circle"
                        tone: Enums.Info
                        variant: Enums.Borderless
                        ariaLabel: qsTr("新增")
                        onClicked: page.growShelf()
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("新增书籍")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                Note {
                    text: qsTr("官方 demo 的删除按钮不是 extra，而是和书名并排的两个 flex 孩子（走 children 那一档）。"
                        + "「新增」是 List 外面一行 div，按当前长度往后取一本，取完就没了 —— 端口同口径，"
                        + "点到《第一人称单数》就到底了。")
                }
            }
        }

        GallerySection {
            title: "单选或多选"

            Column {
                width: 760
                spacing: 12

                Row {
                    spacing: 16

                    Column {
                        width: 280
                        spacing: 8

                        Text {
                            text: qsTr("多选（Checkbox）")
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        List {
                            width: 280
                            size: "small"
                            split: false
                            bordered: true
                            dataSource: page.books.slice(0, 8)

                            renderItem: Component {
                                ListItem {
                                    id: checkRow

                                    required property var modelData

                                    Checkbox {
                                        text: String(checkRow.modelData)
                                        checked: page.chosen.indexOf(checkRow.modelData) >= 0
                                        onToggled: {
                                            const name = checkRow.modelData;
                                            const next = page.chosen.slice();
                                            const at = next.indexOf(name);
                                            if (at >= 0)
                                                next.splice(at, 1);
                                            else
                                                next.push(name);
                                            page.chosen = next;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: 280
                        spacing: 8

                        Text {
                            text: qsTr("单选（Radio）")
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        List {
                            width: 280
                            size: "small"
                            split: false
                            bordered: true
                            dataSource: page.books.slice(0, 8)

                            renderItem: Component {
                                ListItem {
                                    id: radioRow

                                    required property var modelData

                                    Radio {
                                        text: String(radioRow.modelData)
                                        checked: page.picked === radioRow.modelData
                                        onToggled: page.picked = radioRow.modelData
                                    }
                                }
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("官方一个 List 装当前页那 8 条，条目里放 <Checkbox value={item}>，"
                        + "选中态由外面的 CheckboxGroup / RadioGroup 管 —— List 自己没有任何「选中」概念。"
                        + "端口的 CheckboxGroup / RadioGroup 只认直接的子项，包不进 List 的条目里，"
                        + "所以这一节把选中数组提到页面上自己维护（观感与官方一致）。")
                }
            }
        }

        GallerySection {
            title: "响应键盘事件"

            Column {
                width: 760
                spacing: 12

                List {
                    width: 280
                    size: "small"
                    split: false
                    bordered: true
                    dataSource: page.books.slice(0, 10)

                    renderItem: Component {
                        BookRow {}
                    }
                }

                Text {
                    width: 560
                    wrapMode: Text.WordWrap
                    text: page.hoverIndex < 0 ? qsTr("按 ↑ / ↓ 开始选（当前没有选中项）")
                        : qsTr("当前第 %1 项：《%2》（↑ / ↓ 切换，到顶回到底）").arg(
                            String(page.hoverIndex + 1)).arg(String(page.books[page.hoverIndex]))
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("官方整页监听 window 的 keydown（38 / 40）改 hoverIndex，再用一个 "
                        + ".component-list-demo-booklist-active-item 类给当前项铺 fill-0 —— "
                        + "组件本身不管键盘也不管选中。端口用 Shortcut 顶替 window 监听，铺底做进了条目节点；"
                        + "这一节要先把焦点给窗口才吃得到按键。")
                }
            }

            // 官方整页 keydown 38/40 = 裸 ↑/↓ ⇒ 用字符串序列而不是 StandardKey：
            // MoveToPreviousLine 在 macOS 有两档绑定（↑ 与 Meta+P），Qt 只绑第一档并打
            // 「Only binding to one of multiple key bindings」警告（qquickshortcut.cpp:99）
            Shortcut {
                sequence: "Up"

                onActivated: page.stepHover(-1)
            }

            Shortcut {
                sequence: "Down"

                onActivated: page.stepHover(1)
            }
        }
    }
}
