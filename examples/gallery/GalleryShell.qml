pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 文档站外壳：左边侧边栏，中间内容区，右边页内锚点。
//
// 内容区的结构：面包屑 → 标题与简介 → 各小节 → API 参考表。
// 官网在简介下面还有一排「API 文档 / 设计文档」的 Tab，页尾还有 Accessibility /
// 文案规范 / FAQ 三章 —— 都不做（只有一份文档，那两样也不是组件行为）。
// 每个组件页只负责自己的 demo 区，小节的标题和说明由 GallerySection
// 从这里取，保证与官网文字一致。
Item {
    id: control

    property var docs: null
    property var tokens: null
    property string currentDir: "button"
    // 预置的搜索关键字：喂给侧边栏，也让带过滤框的页面（Tokens）跟着走
    property string searchKeyword: ""

    signal navigate(string dir, string category)

    readonly property var categories: control.docs !== null ? control.docs.categories : []
    readonly property var currentComponent: control.findComponent(control.currentDir)
    readonly property string currentCategoryName: control.findCategoryName(control.currentDir)

    // 右侧页内锚点：{ title, y }，y 是内容坐标（= contentY 该滚到的位置）
    property var anchorList: []
    property int activeAnchor: -1

    readonly property int railWidth: 184
    // 窗口不够宽就把锚点收起来，别把正文挤成一条
    readonly property int railSpace: control.width >= 1180 ? control.railWidth + 36 : 0

    function findComponent(dir) {
        // 忽略大小写：docs.json 里的 dir 有的带驼峰（dragMove / userGuide），
        // 命令行传全小写也该找得到
        const want = String(dir).toLowerCase();
        for (let i = 0; i < control.categories.length; ++i) {
            const list = control.categories[i].components;
            for (let j = 0; j < list.length; ++j)
                if (list[j].dir.toLowerCase() === want)
                    return list[j];
        }
        return null;
    }

    function findCategoryName(dir) {
        const want = String(dir).toLowerCase();
        for (let i = 0; i < control.categories.length; ++i) {
            const list = control.categories[i].components;
            for (let j = 0; j < list.length; ++j)
                if (list[j].dir.toLowerCase() === want)
                    return control.categories[i].name;
        }
        return "";
    }

    // 某个小节的说明文字（GallerySection 用它）
    function sectionDescription(title) {
        if (control.currentComponent === null)
            return "";
        const sections = control.currentComponent.sections;
        for (let i = 0; i < sections.length; ++i)
            if (sections[i].title === title)
                return sections[i].description;
        return "";
    }

    // ------------------------------------------------------------------
    // 页内锚点
    // ------------------------------------------------------------------

    // 页面根到各小节之间隔着几层 Column，靠 isGallerySection 标记把它捞出来 ——
    // 与 Navigation 用 isNavigationSub 让容器认子项是同一个套路。
    function collectSections(node, out) {
        const kids = node.children;
        if (kids === undefined || kids === null)
            return;
        for (let i = 0; i < kids.length; ++i) {
            const kid = kids[i];
            // qmllint disable missing-property
            if (kid.isGallerySection === true) {
                // 小节可能被页面自己藏起来（Tokens 页过滤到空就收掉一节），
                // 藏起来的别进锚点栏
                if (kid.visible)
                    out.push(kid);
                continue;
            }
            // qmllint enable missing-property
            control.collectSections(kid, out);
        }
    }

    function rebuildAnchors() {
        const list = [];
        const page = pageLoader.item as Item;
        const sections = [];
        if (page !== null)
            control.collectSections(page, sections);

        for (let i = 0; i < sections.length; ++i) {
            const item = sections[i];
            list.push({
                title: item.title,
                y: item.mapToItem(contentScroll.contentItem, 0, 0).y,
            });
        }

        if (control.currentComponent !== null && control.currentComponent.api.length > 0)
            list.push({
                title: qsTr("API 参考"),
                y: apiTable.mapToItem(contentScroll.contentItem, 0, 0).y,
            });

        control.anchorList = list;
        control.updateActiveAnchor();
    }

    function updateActiveAnchor() {
        // 以「内容顶部往下 24px」为基准线，最后一个越过它的就是当前节
        const line = contentScroll.contentY + 24;
        let index = -1;
        for (let i = 0; i < control.anchorList.length; ++i) {
            if (control.anchorList[i].y <= line)
                index = i;
        }
        // 但是滚到底之后，末尾那几节再也越不过基准线了（内容不够把基准线顶下去），
        // 所以到底时直接认最后一节 —— 否则内容不够长的那几节永远高亮不到。
        if (control.anchorList.length > 0
                && contentScroll.contentY
                    >= contentScroll.contentHeight - contentScroll.height - 1)
            index = control.anchorList.length - 1;
        // 停在顶部时还没有任何一节越过基准线，这时认第一节，
        // 免得进来一个高亮的都没有
        if (index < 0 && control.anchorList.length > 0)
            index = 0;
        control.activeAnchor = index;
    }

    function scrollToAnchor(index) {
        if (index < 0 || index >= control.anchorList.length)
            return;
        const limit = Math.max(0, contentScroll.contentHeight - contentScroll.height);
        scrollAnimation.to = Math.max(0, Math.min(control.anchorList[index].y - 16, limit));
        scrollAnimation.restart();
    }

    onSearchKeywordChanged: control.applyKeywordToPage()

    onCurrentDirChanged: {
        // 换页要回到顶部，否则会停在上一页的滚动位置
        contentScroll.contentY = 0;
        control.anchorList = [];
        // 页面高度在构造后还会变（小节里的 demo 撑高），所以不是只算一次
        control.scheduleAnchorRebuild();
    }

    function scheduleAnchorRebuild() {
        // 页面高度在一帧里会连着变好几次，用 callLater 合并成一次重排
        Qt.callLater(control.rebuildAnchors);
    }

    // 只有带过滤框的页面（Tokens）声明了 keyword，别的页面别硬塞 ——
    // 往不存在的属性上赋值会刷一屏 Cannot assign to non-existent property。
    function applyKeywordToPage() {
        const page = pageLoader.item;
        if (page === null || page === undefined)
            return;
        // qmllint disable missing-property
        if (page.keyword !== undefined)
            page.keyword = control.searchKeyword;
        // qmllint enable missing-property
    }

    NumberAnimation {
        id: scrollAnimation

        target: contentScroll
        property: "contentY"
        duration: 200
        easing.type: Easing.OutCubic
    }

    Row {
        anchors.fill: parent
        spacing: 0

        GallerySidebar {
            id: sidebar

            objectName: "gallerySidebar"
            width: 268
            height: parent.height
            docs: control.docs
            currentDir: control.currentDir
            keyword: control.searchKeyword
            onNavigate: function (dir, category) { control.navigate(dir, category); }
        }

        Flickable {
            id: contentScroll

            objectName: "contentScroll"
            width: parent.width - sidebar.width - control.railSpace
            height: parent.height
            contentWidth: width
            contentHeight: contentColumn.height + 80
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            onContentYChanged: control.updateActiveAnchor()
            onHeightChanged: control.scheduleAnchorRebuild()

            Column {
                id: contentColumn

                x: 48
                y: 36
                width: contentScroll.width - 96
                spacing: 0

                onHeightChanged: control.scheduleAnchorRebuild()

                // 面包屑（站壳自己的页头，不是 demo）：两档都不给链接样式，
                // 末项按官方规则天然就是「当前页」（text-0 + 字重 600）
                Breadcrumb {
                    routes: [
                        { name: control.currentCategoryName, noLink: true },
                        { name: control.currentComponent !== null
                            ? control.currentComponent.title : control.currentDir,
                            noLink: true }
                    ]
                }

                // 标题与简介
                Text {
                    topPadding: 20
                    width: parent.width
                    text: control.currentComponent !== null
                        ? control.currentComponent.title : ""
                    color: Theme.current.colorText0
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }

                Text {
                    topPadding: 12
                    width: parent.width
                    text: control.currentComponent !== null
                        ? control.currentComponent.brief : ""
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeHeader6
                    lineHeight: 28
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }

                // 简介之后直接进内容：官网这里那排「API 文档 / 设计文档」的 Tab 与它下面那条
                // 通栏分隔线都不做（只有一份文档，摆一枚 Tab 反而像缺了另一半）。
                Item { width: 1; height: 32 }

                // 组件页
                Loader {
                    id: pageLoader

                    width: parent.width
                    asynchronous: false
                    source: control.currentComponent !== null && !control.currentComponent.skipped
                        ? Qt.resolvedUrl(control.currentComponent.page + "Page.qml")
                        : Qt.resolvedUrl("GalleryPlaceholder.qml")

                    onItemChanged: {
                        control.applyKeywordToPage();
                        control.scheduleAnchorRebuild();
                    }
                }

                Item { width: 1; height: 48 }

                // API 参考表
                GalleryApiTable {
                    id: apiTable

                    width: parent.width
                    component: control.currentComponent
                }
            }
        }

        // ---- 右侧页内锚点 ----
        Flickable {
            id: rail

            visible: control.railSpace > 0
            width: control.railSpace
            height: parent.height
            contentWidth: width
            contentHeight: railColumn.height + 72
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: railColumn

                x: 12
                y: 36
                width: rail.width - 24
                spacing: 0

                Repeater {
                    model: control.anchorList

                    delegate: Item {
                        id: anchorEntry

                        required property var modelData
                        required property int index

                        readonly property bool current: anchorEntry.index === control.activeAnchor
                        readonly property bool hovered: anchorHover.hovered

                        width: railColumn.width
                        height: Math.max(28, anchorText.implicitHeight + 8)

                        // 滑轨底色，规格照本库的 Anchor：2px、color-border
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 2
                            color: Theme.current.colorBorder
                        }

                        // 当前项那一段换成主色
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            radius: 1
                            height: anchorEntry.current ? parent.height - 6 : 0
                            color: Theme.current.colorPrimary
                        }

                        Text {
                            id: anchorText

                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: anchorEntry.modelData.title
                            color: anchorEntry.current
                                ? Theme.current.colorPrimary
                                : (anchorEntry.hovered
                                    ? Theme.current.colorText1 : Theme.current.colorText2)
                            font.pixelSize: Theme.current.fontSizeSmall
                            font.weight: anchorEntry.current ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        HoverHandler {
                            id: anchorHover
                        }

                        TapHandler {
                            onTapped: control.scrollToAnchor(anchorEntry.index)
                        }
                    }
                }
            }
        }
    }
}
