import QtQuick
import QtTest
import Semi

// List / ListItem。规格照 packages/semi-ui/list/{index.tsx,item.tsx,list-context.ts} +
// packages/semi-foundation/list/{list.scss,variables.scss,constants.ts}，
// demo 面照 content/show/list/index.md 的 15 个小节（其中「响应式的栅格列表」那档
// 的解析规则要对着 packages/semi-foundation/grid/{grid.scss,mixin.scss} + row.tsx/col.tsx）：
//   · ListProps（index.tsx:17-69）：bordered **false** / split **true** / loading false /
//     layout "vertical" / size "default" / dataSource / renderItem / grid / header / footer /
//     loadMore / emptyContent / onClick / onRightClick。没有 emptyText、spacing、itemSize。
//   · 四段从上到下 header → items → footer → loadMore；loading 只把 Spin 套在 items 外。
//   · 内边距（list.scss:14-97）：条目 / header / footer 同一档 —— 默认上下 12 左右 24、
//     small 8/16、large 16/24；栅格档只把**条目**清成 0，header / footer 不清。
//   · 分割线（:71-122）：`.semi-list-split .semi-list-item` 底边 1px + `:last-child` 取消；
//     header 底、footer 顶同受 split 管；横向档改成右边。
//   · :last-child 是相对直属父节点的 ⇒ 栅格档每条独占一个 Col、条目被包一层，都自己就是
//     last-child ⇒ 整档没线（端口由 List 只给摊平后的非末条写 hasSeam，其余默认 false）。
//   · 空态（:19-24）：padding 12px 0、text-2、width 100%、text-align center；
//     只有 dataSource 空**且**没有 children 才出现（:155）。dataSource 非空而 renderItem
//     没给时走 :144 那一支，一条都不出、连空态都不画（照抄）。
//   · dataSource 非空时生成条目与 children 同时渲染、生成的在前（:109-112，照抄）。
//   · List.Item（item.tsx）：[body(header+main)] [children] [extra]，body flex:1、
//     header→main 20、extra 左 40；align 只管 body 内，默认 flex-start，
//     给假值时官方那条类不加 ⇒ CSS 初值 stretch。
//   · onClick / onRightClick 官方是「条目自己的赢、二选一」（item.tsx:76-77）；QML 探不出
//     信号有没有人接 ⇒ 端口两层都发，这里把「两层都收到」钉住。
//   · 官方两个回调只挂在 li 上 ⇒ 点 header / footer / loadMore / 空白都不算；端口同样
//     只有落在条目上才发（靠条目自己的处理器回头转发，不靠容器量坐标）。
//   · onMouseEnter / onMouseLeave（item.tsx:20-21，挂在 li 自己身上 :100-101）⇒ 端口的
//     mouseEntered / mouseLeft。官方那张 List.Item API 表没列这两条，但 props 里有、也真挂上
//     了 DOM，按 TSX 的 prop 面收。用的是 enter / leave 而不是 over / out ⇒ 在同一条 li 内部
//     走动不重发，命中区含内边距。
//   · Col 那一层五个类名属性（grid/mixin.scss:57-80）：span 宽、offset = margin-left（占格、
//     影响换行与富余）、push / pull = relative 的 left / right（只挪像素，两个都给时 left 赢）、
//     order = flex 的 order。mixin 的 loop 从 1 数到 24 ⇒ 给 0 或负数落不到任何规则（等于没给）。
//     order 对 List 恒无效：那个 grid 对象是原样摊给每一条 Col 的（item.tsx:50-58），所有 Col
//     同一个 order ⇒ flex 等值即保持源码顺序，官方没有「单条改序」的入口。
//     档位是按属性各取各的（col.tsx:73-84 把各档的类名并进同一个对象）⇒ md 只给 span
//     清不掉 sm 的 offset；数字档只带 span。
// 用例跑在 900×1400 的窗口里（栅格断点读 Window 宽，900 ⇒ md 档命中、lg 不命中）。
TestCase {
    id: testCase

    name: "List"
    when: windowShown
    width: 900
    height: 1400

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    // 断言失败会跳过用例末尾的 destroy，残留的实例还会继续吃窗口事件，
    // 所以统一在 cleanup 里清（同 Calendar 那轮的教训）
    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "list");
    }

    function part(root, name) {
        return testCase.findChild(root, name);
    }

    // 递归收集某个 objectName（条目是 Repeater 生成的，一层层找不划算）
    function findAll(root, name, out) {
        const list = out === undefined ? [] : out;
        for (let i = 0; i < root.children.length; ++i) {
            const child = root.children[i];
            if (child.objectName === name)
                list.push(child);
            findAll(child, name, list);
        }
        return list;
    }

    function nodesOf(list) {
        return list.itemNodes();
    }

    function itemAt(list, i) {
        return list.itemNodes()[i];
    }

    function mainText(item) {
        return part(item, "listItemMainText");
    }

    function seamOf(item) {
        return part(item, "listItemSeam");
    }

    function makeList(extra, items) {
        const model = items === undefined ? ["甲", "乙", "丙"] : items;
        return make(`List {
            width: 400
            dataSource: ${JSON.stringify(model)}
            renderItem: Component { ListItem { main: modelData } }
            ${extra === undefined ? "" : extra}
        }`);
    }

    function spyOn(target, signalName) {
        const spy = Qt.createQmlObject("import QtTest; SignalSpy {}", testCase, "listspy");
        spy.target = target;
        spy.signalName = signalName;
        return spy;
    }

    // 等 Repeater 生成 + 两次排版（第二次是 deferred 那一趟）落定
    function settle(list) {
        testCase.wait(60);
        return list;
    }

    // ---------------- 属性面 ----------------

    function test_officialPropDefaults() {
        const list = make("List { width: 400 }");
        compare(list.bordered, false, "官方 defaultProps bordered: false");
        compare(list.split, true);
        compare(list.loading, false);
        compare(list.layout, "vertical");
        compare(list.size, "default");
        compare(list.dataSource.length, 0);
        compare(list.renderItem, null);
        compare(list.grid, undefined);
        compare(list.header, undefined);
        compare(list.footer, undefined);
        compare(list.loadMore, undefined);
        compare(list.emptyContent, undefined);
        compare(list.isListHost, true);

        const item = make("ListItem { }");
        compare(item.align, "flex-start", "item.tsx:43 defaultProps");
        compare(item.header, undefined);
        compare(item.main, undefined);
        compare(item.extra, undefined);
        compare(item.hasSeam, false);
        list.destroy();
        item.destroy();
    }

    function test_inventedSurfaceIsGone() {
        const list = make("List { width: 400 }");
        compare(list.emptyText, undefined, "官方没有 emptyText，空态文案走 emptyContent + locale");
        compare(list.isEmpty, undefined);
        compare(list.spacing, undefined, "官方没有 spacing：条目是 block，靠分割线不靠间距");
        compare(list.itemSize, undefined);
        list.destroy();

        const item = make("ListItem { }");
        compare(item.paddingY, undefined, "旧端口的 paddingY 也没了");
        compare(item.clickable, undefined);
        compare(item.showDivider, undefined);
        compare(item.paddingX, undefined, "端口改叫 padV/padH：官方那对令牌名是读反的");
        item.destroy();
    }

    function test_sizeTokens() {
        const expected = [
            { size: "small", padV: Theme.current.spacingTight, padH: Theme.current.spacingBase },
            { size: "default", padV: Theme.current.spacingBaseTight, padH: Theme.current.spacingLoose },
            { size: "large", padV: Theme.current.spacingBase, padH: Theme.current.spacingLoose },
        ];
        for (const spec of expected) {
            const list = makeList(`size: "${spec.size}"`, ["甲"]);
            const item = itemAt(list, 0);
            compare(item.padV, spec.padV, spec.size + " 条目上下内边距");
            compare(item.padH, spec.padH, spec.size + " 条目左右内边距");
            compare(item.height, 20 + spec.padV * 2, spec.size + " 单行条目高（无线）");
            // header / footer 同档
            compare(list.bandPadV, spec.padV, spec.size + " bandPadV");
            compare(list.bandPadH, spec.padH, spec.size + " bandPadH");
            list.destroy();
        }
    }

    function test_paddingTokenAxisIsSwappedInUpstreamNames() {
        // $spacing-list_item-paddingX 是 12、paddingY 是 24，而 scss 写的是
        // `padding: $paddingX $paddingY` ⇒ CSS 简写第一格是上下：上下 12、左右 24。
        // 端口按读对的值走，这一条把「照令牌名抄反」钉住。
        const list = makeList("", ["甲"]);
        const item = itemAt(list, 0);
        compare(item.padV, 12);
        compare(item.padH, 24);
        list.destroy();
    }

    function test_gridClearsOnlyItemPadding() {
        const list = makeList('size: "small"; grid: ({ span: 24 })', ["甲"]);
        list.header = "头";
        const item = itemAt(list, 0);
        compare(item.inGrid, true);
        compare(item.padV, 0, "list.scss:99-103 只选 -item");
        compare(item.padH, 0);
        compare(list.bandPadV, 8, "header / footer 不跟着清");
        compare(list.headerHeight, 20 + 8 * 2 + 1);
        list.destroy();
    }

    // ---------------- header / footer / loadMore ----------------

    function test_headerStringGeometry() {
        const list = makeList('header: "成员"');
        compare(list.headerTaken, true);
        compare(list.headerHeight, 20 + 24 + 1);
        const block = part(list, "listHeader");
        compare(block.y, 0);
        compare(block.width, 400);
        const paddingBox = part(list, "listHeaderPaddingBox");
        compare(paddingBox.x, 24, "$spacing-list_footer-paddingY（横着用）");
        compare(paddingBox.y, 12);
        const text = part(list, "listHeaderText");
        compare(text.text, "成员");
        compare(text.lineHeight, 20);
        const seam = part(list, "listHeaderSeam");
        compare(seam.y, list.headerHeight - 1, "线贴在整块底边");
        compare(seam.height, 1);
        compare(seam.width, 400, "整幅，不跟着内边距内缩");
        compare(seam.color, Theme.current.colorBorder);
        compare(part(list, "listItems").y, 45, "items 顶着 header 底下");
        list.destroy();
    }

    function test_headerTruthiness() {
        const empty = make('List { width: 400; header: "" }');
        compare(empty.headerTaken, false, "官方 {header ? <div> : null} 走真值");
        compare(empty.headerHeight, 0);
        const zero = make("List { width: 400; header: 0 }");
        compare(zero.headerTaken, false, "数字 0 在 JS 里也是假值");
        const node = make(`List {
            width: 400
            header: Component { Rectangle { width: 100; height: 30; color: "transparent" } }
        }`);
        compare(node.headerTaken, true);
        compare(node.headerHeight, 30 + 24 + 1, "节点档按隐式高 + 上下 12 + 1 线");
        compare(part(node, "listHeaderText").visible, false);
        compare(part(node, "listHeaderNode").item.width, 100);
        empty.destroy();
        zero.destroy();
        node.destroy();
    }

    function test_footerGeometry() {
        const list = makeList('footer: "共 3 人"');
        compare(list.footerTaken, true);
        compare(list.footerHeight, 20 + 24 + 1);
        const block = part(list, "listFooter");
        compare(block.y, list.headerHeight + list.itemsHeight, "footer 紧跟在 items 后面");
        compare(part(list, "listFooterSeam").y, 0, "footer 的线在顶边");
        compare(part(list, "listFooterText").text, "共 3 人");
        compare(part(list, "listFooterPaddingBox").x, 24);
        list.destroy();
    }

    function test_loadMoreIsARawNode() {
        const list = makeList(`loadMore: Component {
            Rectangle { width: 60; height: 40; color: "transparent" }
        }`);
        compare(list.loadMoreTaken, true);
        compare(list.loadMoreHeight, 40);
        const block = part(list, "listLoadMore");
        compare(block.x, 0);
        compare(block.y, list.headerHeight + list.itemsHeight + list.footerHeight,
            "官方 {loadMore} 直接跟在 footer 后面");
        compare(findAll(block, "listFooterSeam").length, 0, "loadMore 这段官方没有任何描边");
        // 空档：loadMore 没给 ⇒ 一点位置都不占
        const bare = make("List { width: 400 }");
        compare(bare.loadMoreHeight, 0);
        compare(bare.loadMoreTaken, false);
        list.destroy();
        bare.destroy();
    }

    function test_splitFalseDropsAllThreeSeams() {
        const list = makeList('split: false; header: "头"; footer: "尾"; loadMore: undefined',
            ["甲", "乙"]);
        compare(list.headerHeight, 20 + 24, "header 少掉那 1px");
        compare(list.footerHeight, 20 + 24);
        compare(part(list, "listHeaderSeam").visible, false);
        compare(part(list, "listFooterSeam").visible, false);
        const nodes = nodesOf(list);
        compare(nodes.length, 2);
        compare(nodes[0].hasSeam, false);
        compare(seamOf(nodes[0]).visible, false);
        list.destroy();
    }

    // ---------------- 条目排布 ----------------

    function test_verticalItemsStackAndLastHasNoSeam() {
        const list = makeList("");
        const nodes = nodesOf(list);
        compare(nodes.length, 3);
        compare(nodes[0].y, 0);
        compare(nodes[1].y, 45, "上一条含 1px 分割线");
        compare(nodes[2].y, 90);
        compare(nodes[0].width, 400, "block 子项铺满容器");
        compare(nodes[0].hasSeam, true);
        compare(nodes[1].hasSeam, true);
        compare(nodes[2].hasSeam, false, "官方 :last-child { border-bottom: none }");
        compare(nodes[2].height, 44);
        const seams = findAll(list, "listItemSeam");
        compare(seams.length, 3, "每条一个线节点");
        compare(seams[0].visible, true);
        compare(seams[2].visible, false);
        compare(seams[0].y, 44, "线在条目最后一像素");
        compare(seams[0].height, 1);
        compare(list.itemsHeight, 134);
        list.destroy();
    }

    function test_modelDataAndIndexAreInjected() {
        const list = make(`List {
            width: 400
            dataSource: ["甲", "乙"]
            renderItem: Component {
                ListItem {
                    id: row

                    required property var modelData
                    required property int index

                    main: String(modelData) + "-" + index
                }
            }
        }`);
        settle(list);
        compare(mainText(itemAt(list, 0)).text, "甲-0");
        compare(mainText(itemAt(list, 1)).text, "乙-1");
        list.destroy();
    }

    function test_generatedAndDeclaredBothRender() {
        // 官方 `{childrenList}{children}`（index.tsx:109-112）：两支都渲染，生成的在前
        const list = make(`List {
            width: 400
            dataSource: ["生成一", "生成二"]
            renderItem: Component { ListItem { main: modelData } }

            ListItem { objectName: "declaredOne"; main: "声明一" }
            ListItem { objectName: "declaredTwo"; main: "声明二" }
        }`);
        settle(list);
        const nodes = nodesOf(list);
        compare(nodes.length, 4);
        compare(list.generatedCount, 2);
        compare(list.declaredCount, 2);
        compare(mainText(nodes[1]).text, "生成二");
        compare(nodes[2].objectName, "declaredOne");
        compare(nodes[2].y, 90, "声明式紧跟在生成条目后面");
        compare(nodes[1].hasSeam, true, "后面还有孩子 ⇒ 它不再是 last-child");
        compare(nodes[3].hasSeam, false);
        compare(list.showEmpty, false);
        list.destroy();
    }

    function test_repeaterInContentIsNotANode() {
        // Qt 6.11 起 Repeater 自己就是个 Item；它只是产条目的宿主，不是官方 children 那一条
        const host = make(`Item {
            id: repHost

            property var rows: ["一", "二"]

            List {
                objectName: "repeaterList"
                width: 400

                Repeater {
                    model: repHost.rows
                    delegate: ListItem { main: modelData }
                }
            }
        }`);
        settle(host);
        const list = part(host, "repeaterList");
        compare(list.declaredCount, 2, "两条条目，Repeater 自己不计数");
        const nodes = nodesOf(list);
        compare(nodes.length, 2);
        compare(nodes[0].toString().indexOf("Repeater") < 0, true, "摊平出来的不该有 Repeater");
        compare(nodes[1].hasSeam, false, "末条是真正的最后那一条，不是 Repeater");
        compare(list.itemsHeight, 89);
        host.destroy();
    }

    function test_declaredOnlyRendersDeclared() {
        const list = make(`List {
            width: 400
            ListItem { main: "只声明一" }
            ListItem { main: "只声明二" }
        }`);
        settle(list);
        compare(list.showEmpty, false, "官方 else if (!children)：有 children 就不画空态");
        compare(nodesOf(list).length, 2);
        compare(list.itemsHeight, 89);
        list.destroy();
    }

    function test_dataSourceWithoutRenderItemRendersNothingAtAll() {
        // index.tsx:144-157：走 if (dataSource.length) 那一支，renderItem 没给 ⇒ items = []，
        // 而空态在 else 分支里 ⇒ 连空态都不出现
        const list = make("List { width: 400; dataSource: ['甲'] }");
        settle(list);
        compare(list.useDataSource, true);
        compare(list.generatedCount, 0);
        compare(list.showEmpty, false);
        compare(list.itemsHeight, 0);
        compare(list.implicitHeight, 0);
        compare(part(list, "listEmpty").visible, false);
        list.destroy();
    }

    function test_emptyState() {
        const list = make("List { width: 400 }");
        compare(list.showEmpty, true);
        compare(list.emptyHeight, 20 + 12 * 2);
        const text = part(list, "listEmptyText");
        compare(text.text, "暂无数据", "缺省走 locale（zh_CN List.emptyText）");
        compare(text.visible, true);
        compare(text.color, Theme.current.colorText2);
        compare(text.horizontalAlignment, Text.AlignHCenter);
        compare(text.x, (400 - text.width) / 2);
        compare(text.y, 12, "$spacing-list_empty-paddingY");
        list.destroy();
    }

    function test_emptyContentVariants() {
        const text = make('List { width: 400; emptyContent: "没有东西" }');
        compare(nodesOf(text).length, 0);
        compare(part(text, "listEmptyText").text, "没有东西");
        text.destroy();

        const node = make(`List {
            width: 400
            emptyContent: Component { Rectangle { width: 120; height: 40; color: "transparent" } }
        }`);
        compare(node.emptyNodeHeight, 40);
        compare(node.emptyHeight, 40 + 24);
        compare(part(node, "listEmptyText").visible, false);
        compare(part(node, "listEmptyNode").y, 12);
        node.destroy();
    }

    function test_borderedIsOnePxOnly() {
        const list = makeList("");
        const border = part(list, "listBorder");
        compare(border.visible, false, "缺省 bordered false ⇒ 一条线都不画");
        compare(border.radius, 0, "官方本体没有圆角");
        compare(border.color, Qt.rgba(0, 0, 0, 0), "官方本体也没有底色");
        list.bordered = true;
        wait(40);
        compare(border.visible, true);
        compare(border.border.width, 1);
        compare(border.border.color, Theme.current.colorBorder);
        list.destroy();
    }

    // ---------------- 横向档 ----------------

    function test_horizontalUsesNaturalWidthsAndStretches() {
        const list = make(`List {
            width: 300
            layout: "horizontal"
            dataSource: ["甲", "乙", "丙丙"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        const nodes = nodesOf(list);
        compare(list.horizontal, true);
        compare(nodes[0].x, 0);
        compare(nodes[1].x, nodes[0].width, "紧挨着排，官方 flex 没有 gap");
        compare(nodes[2].x, nodes[0].width + nodes[1].width);
        compare(nodes[0].width, nodes[0].implicitWidth, "flex:0 1 auto ⇒ 按内容宽");
        compare(nodes[0].width, nodes[0].naturalWidth + 2 * nodes[0].padH + 1,
            "自然宽 = 内容 + 左右内边距 + 右边那条 1px（border-box）");
        compare(nodes[2].width, nodes[2].naturalWidth + 2 * nodes[2].padH, "末条没线");
        compare(nodes[0].height, nodes[2].height, "交叉轴 stretch ⇒ 同排等高");
        compare(list.itemsHeight, nodes[0].height);
        const seam = seamOf(nodes[0]);
        compare(seam.x, nodes[0].width - 1, "横向档线在右边");
        compare(seam.width, 1);
        compare(seam.height, nodes[0].height);
        const lastSeam = seamOf(nodes[2]);
        compare(lastSeam.visible, false);
        list.destroy();
    }

    function test_itemsBlockIsStillBelowHeaderWhenHorizontal() {
        const list = makeList('layout: "horizontal"; header: "头"', ["甲"]);
        compare(part(list, "listItems").y, 45, "header 仍是整幅的块，不跟着躺平");
        compare(list.headerHeight, 45);
        list.destroy();
    }

    // ---------------- 栅格档 ----------------

    function test_gridNumericGutter() {
        const list = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6 })
            dataSource: ["甲", "乙", "丙", "丁", "戊"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        const nodes = nodesOf(list);
        // Row 左右各 -g/2、Col 左右各 +g/2 ⇒ 一格内容宽 = (600+12)*6/24 - 12
        compare(nodes[0].width, 141);
        compare(nodes[0].x, 0, "负边距与内边距抵掉 ⇒ 首格贴容器左缘");
        compare(nodes[1].x, 153);
        compare(nodes[3].x, 459);
        compare(nodes[4].y, 20, "数字 gutter 只给横向；纵向是 [gutter, 0]（row.tsx:104）");
        compare(list.itemsHeight, 40, "两行，各 20 高");
        for (const node of nodes)
            compare(node.hasSeam, false, "栅格档每条独占一个 Col ⇒ 都是 last-child");
        list.destroy();
    }

    function test_gridArrayGutterHasVerticalSpacing() {
        const list = make(`List {
            width: 600
            grid: ({ gutter: [12, 8], span: 6 })
            dataSource: ["甲", "乙", "丙", "丁", "戊"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        compare(itemAt(list, 4).y, 28, "行距 = 行高 20 + 纵向 gutter 8");
        compare(list.itemsHeight, 48);
        list.destroy();
    }

    function test_gridBreakpointsFollowWindowWidth() {
        const list = make(`List {
            width: 600
            grid: ({ xs: 24, sm: 12, md: 12, lg: 8, xl: 8, xxl: 6 })
            dataSource: ["甲", "乙"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        compare(list.viewportWidth, 900, "官方看视口，端口看所在 Window 的宽");
        compare(list.colSpan(), 12, "900 命中 xs/sm/md 三条，越靠后的赢（lg 是 ≥992）");
        compare(itemAt(list, 0).width, 300);
        compare(itemAt(list, 1).x, 300);
        list.destroy();

        const xsOnly = make(`List {
            width: 600
            grid: ({ xs: 6 })
            dataSource: ["甲"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(xsOnly);
        compare(xsOnly.colSpan(), 6, "-col-xs-* 那条规则没包 media query ⇒ 恒生效");
        xsOnly.destroy();

        const zero = make(`List {
            width: 600
            grid: ({ xs: 24, sm: 0 })
            dataSource: ["甲", "乙"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(zero);
        compare(zero.colSpan(), 0);
        compare(itemAt(zero, 0).visible, false, "-col-0 { display: none }");
        compare(zero.itemsHeight, 0);
        zero.destroy();
    }

    function test_gridResponsiveGutterObject() {
        const list = make(`List {
            width: 600
            grid: ({ gutter: ({ xs: 4, md: 20 }), xs: 6 })
            dataSource: ["甲", "乙", "丙", "丁"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        compare(list.gutterAt(0), 20, "Row.tsx 从 xxl 往下扫，第一个命中且给了值的档赢");
        compare(itemAt(list, 0).width, 135, "(600+20)*6/24 - 20");
        compare(itemAt(list, 1).x, 155);
        compare(itemAt(list, 3).x, 465);
        list.destroy();
    }

    function test_gridJustifyAndAlign() {
        const centered = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, justify: "center" })
            dataSource: ["甲", "乙", "丙"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(centered);
        // 三格占了 459，行内容盒 612 ⇒ 富余 153，居中挪 76.5，再抵消 -g/2
        compare(itemAt(centered, 0).x, 76.5);
        compare(itemAt(centered, 1).x, 76.5 + 153);
        centered.destroy();

        const spaced = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, justify: "space-between" })
            dataSource: ["甲", "乙", "丙"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(spaced);
        compare(itemAt(spaced, 0).x, 0);
        compare(itemAt(spaced, 2).x, 600 - 141, "space-between ⇒ 末格贴右缘");
        spaced.destroy();

        const bottom = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 12, align: "bottom" })
            dataSource: [{ rows: 1 }, { rows: 3 }]
            renderItem: Component {
                ListItem {
                    id: tall

                    required property var modelData

                    main: Component {
                        Column {
                            spacing: 2
                            Repeater {
                                model: tall.modelData.rows

                                Text { text: "行"; font.pixelSize: 14 }
                            }
                        }
                    }
                }
            }
        }`);
        settle(bottom);
        const short = itemAt(bottom, 0);
        const high = itemAt(bottom, 1);
        compare(short.width, 294);
        compare(high.height > short.height, true);
        compare(short.y, high.height - short.height, "align bottom ⇒ 矮的那格贴到行带下沿");
        compare(high.y, 0);
        bottom.destroy();
    }

    function test_gridHeaderFooterStayInFlow() {
        const list = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 12 })
            header: "头"
            footer: "尾"
            dataSource: ["甲", "乙"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        compare(list.headerHeight, 45);
        compare(part(list, "listItems").y, 45);
        compare(part(list, "listFooter").y, 45 + list.itemsHeight);
        compare(list.implicitHeight, 45 + list.itemsHeight + 45);
        list.destroy();
    }

    // ---------------- ListItem 三段与 align ----------------

    function test_slotTextPaintFollowsTokens() {
        // 官方只在 -empty 上显式给了色（text-2），其余三段是继承 .semi-list 的 14/20 常规字；
        // 端口把 text-0 写实到三段上，这里把「三段不是灰的」钉住。
        const row = make('ListItem { width: 400; header: "头"; main: "正文"; extra: "附加" }');
        compare(mainText(row).color, Theme.current.colorText0);
        compare(part(row, "listItemHeaderText").color, Theme.current.colorText0);
        compare(part(row, "listItemExtraText").color, Theme.current.colorText0);
        compare(mainText(row).font.pixelSize, Theme.current.fontSizeRegular);
        compare(mainText(row).lineHeight, 20);
        compare(mainText(row).lineHeightMode, Text.FixedHeight);
        row.destroy();

        const list = makeList('header: "成员"; footer: "共 3 人"', ["甲"]);
        compare(part(list, "listHeaderText").color, Theme.current.colorText0);
        compare(part(list, "listFooterText").color, Theme.current.colorText0);
        list.destroy();
    }

    function test_threeSlotsLayout() {
        const row = make(`ListItem {
            width: 500
            header: "头像位"
            main: "正文"
            extra: "附加"
        }`);
        const body = part(row, "listItemBody");
        const header = part(row, "listItemHeader");
        const main = part(row, "listItemMain");
        const extra = part(row, "listItemExtra");
        compare(body.x, 24);
        compare(header.x, 0);
        compare(main.x, header.width + 20, "$spacing-list_header-marginRight");
        compare(extra.x, body.x + body.width + row.childrenW + 40,
            "-extra { margin-left: $spacing-list_extra-marginLeft = 40 }");
        // body 是 flex:1 ⇒ 富余宽度全给它，extra 只占自己的自然宽
        compare(body.width, row.contentWidth - row.childrenW - 40 - extra.width);
        compare(row.naturalWidth, row.bodyNaturalWidth + row.childrenW + 40 + extra.width);
        row.destroy();
    }

    function test_bodyIsNotCreatedWhenHeaderAndMainAbsent() {
        const row = make('ListItem { width: 400; Text { text: "只有一排孩子" } }');
        compare(row.bodyTaken, false);
        compare(part(row, "listItemBody").visible, false);
        compare(row.childrenW > 0, true);
        row.destroy();

        const headerOnly = make('ListItem { width: 400; header: "只有头" }');
        compare(headerOnly.bodyTaken, true, "官方 if (header || main) ⇒ 单给一个也建 body");
        compare(part(headerOnly, "listItemMain").visible, false);
        headerOnly.destroy();
    }

    function test_alignPositionsInsideBody() {
        const cases = [
            { align: "flex-start", mainY: 0, resolved: "flex-start" },
            { align: "center", mainY: 20, resolved: "center" },
            { align: "flex-end", mainY: 40, resolved: "flex-end" },
            { align: "stretch", mainY: 0, resolved: "stretch" },
            { align: "baseline", mainY: 0, resolved: "baseline" },
            { align: "", mainY: 0, resolved: "stretch" },
        ];
        for (const spec of cases) {
            const row = make(`ListItem {
                width: 500
                align: "${spec.align}"
                header: Component { Rectangle { width: 40; height: 60; color: "transparent" } }
                main: "正文"
            }`);
            compare(row.alignResolved, spec.resolved,
                spec.align + "：假值时官方那条 -body-{align} 类不加 ⇒ 落 CSS 初值 stretch");
            compare(row.bodyNaturalHeight, 60);
            const main = part(row, "listItemMain");
            compare(main.y, spec.mainY, spec.align + " 下 main 的纵向位置");
            compare(part(row, "listItemHeader").y, 0);
            // stretch 把那一格拉高到行带，其余保持内容高
            compare(main.height, spec.resolved === "stretch" ? 60 : 20, spec.align + " main 高");
            row.destroy();
        }
    }

    function test_itemCentersItsThreeParts() {
        const list = make(`List {
            width: 400
            dataSource: [{ }]
            renderItem: Component {
                ListItem {
                    header: Component { Rectangle { width: 40; height: 60; color: "transparent" } }
                    extra: Component { Rectangle { width: 20; height: 20; color: "transparent" } }
                }
            }
        }`);
        settle(list);
        const item = itemAt(list, 0);
        compare(item.contentHeight, 60, "li 内容高 = 三段里最高的那条");
        compare(item.height, 60 + 24, "只有一条 ⇒ 它是 last-child ⇒ 没有那 1px");
        // li 自己 align-items:center ⇒ 矮的 extra 垂直居中
        compare(part(item, "listItemExtra").y, item.padV + (60 - 20) / 2);
        list.destroy();
    }

    function test_standaloneListItemHasNoContext() {
        const row = make('ListItem { main: "单独摆一个" }');
        compare(row.listCtx, null);
        compare(row.size, "default");
        compare(row.inGrid, false);
        compare(row.horizontal, false);
        compare(row.padV, 12);
        compare(row.hasSeam, false, "官方 -split 的线只在 .semi-list 里命中");
        compare(seamOf(row).visible, false);
        row.destroy();
    }

    function test_listCtxWalksUpThroughTheZones() {
        const list = makeList("", ["甲"]);
        const item = itemAt(list, 0);
        compare(item.listCtx === list, true, "条目穿过 zone/容器往上认到 List");
        compare(item.size, "default");
        list.size = "large";
        wait(40);
        compare(item.padV, 16, "上层 size 变了，条目跟着换内边距");
        list.destroy();
    }

    // ---------------- 分割线的三种「不命中」 ----------------

    function test_wrappedItemHasNoSeamButStillForwardsClick() {
        // 官方「加载更多」那节就是 Skeleton 包 List.Item：li 的直属父节点是包的那层，
        // 于是每条都是自己那一层的 last-child ⇒ 一条线都不画
        const list = make(`List {
            width: 400
            dataSource: ["甲", "乙"]
            renderItem: Component {
                Rectangle {
                    id: shell

                    required property var modelData

                    objectName: "shellNode"
                    color: "transparent"
                    implicitWidth: 400
                    implicitHeight: inner.implicitHeight

                    ListItem {
                        id: inner

                        objectName: "innerItem"
                        width: shell.width
                        main: shell.modelData
                    }
                }
            }
        }`);
        settle(list);
        const nodes = nodesOf(list);
        compare(nodes.length, 2);
        compare(nodes[0].hasSeam, undefined, "摊平出来的是包的那一层，它没有 hasSeam 这一说");
        const inner = part(list, "innerItem");
        compare(inner.hasSeam, false);
        compare(seamOf(inner).visible, false);
        const listSpy = spyOn(list, "clicked");
        const itemSpy = spyOn(inner, "clicked");
        mouseClick(inner, 60, 20);
        wait(40);
        compare(listSpy.count, 1, "官方 onClick 走 context 下发到那条 li ⇒ 包一层也算");
        compare(itemSpy.count, 1);
        listSpy.destroy();
        itemSpy.destroy();
        list.destroy();
    }

    function test_gridItemsDrawNoSeamEvenWithSplit() {
        const list = makeList('grid: ({ span: 12 })', ["甲", "乙"]);
        compare(list.split, true);
        const nodes = nodesOf(list);
        compare(nodes[0].hasSeam, false);
        compare(seamOf(nodes[0]).visible, false);
        compare(seamOf(nodes[1]).visible, false);
        list.destroy();
    }

    // ---------------- 点击 ----------------

    function test_clickItemFiresItemAndList() {
        const list = makeList("", ["甲", "乙"]);
        const item = itemAt(list, 0);
        const listSpy = spyOn(list, "clicked");
        const itemSpy = spyOn(item, "clicked");
        mouseClick(item, 60, 20);
        wait(40);
        compare(itemSpy.count, 1);
        compare(listSpy.count, 1, "官方二选一、端口两层都发（QML 探不出信号有没有人接）");
        listSpy.destroy();
        itemSpy.destroy();
        list.destroy();
    }

    function test_clickOnNestedButtonAlsoReachesItemAndList() {
        const list = make(`List {
            width: 400
            dataSource: ["甲"]
            renderItem: Component {
                ListItem {
                    id: row

                    required property var modelData

                    objectName: "buttonRow"
                    Button { objectName: "rowButton"; text: "点我" }
                    Text { text: String(row.modelData) }
                }
            }
        }`);
        settle(list);
        const row = part(list, "buttonRow");
        const button = part(list, "rowButton");
        const buttonSpy = spyOn(button, "clicked");
        const rowSpy = spyOn(row, "clicked");
        const listSpy = spyOn(list, "clicked");
        mouseClick(button, 10, 10);
        wait(40);
        compare(buttonSpy.count, 1);
        compare(rowSpy.count, 1, "官方是 DOM 冒泡：点条目里的按钮，li 的 onClick 也算");
        compare(listSpy.count, 1);
        buttonSpy.destroy();
        rowSpy.destroy();
        listSpy.destroy();
        list.destroy();
    }

    function test_clickOnHeaderFooterAndLoadMoreIsIgnored() {
        const list = makeList(`header: "头"
            footer: "尾"
            loadMore: Component { Rectangle { width: 100; height: 30; color: "transparent" } }`,
            ["甲"]);
        const spy = spyOn(list, "clicked");
        mouseClick(list, 100, 6);
        wait(40);
        compare(spy.count, 0, "官方 onClick 只挂在 li 上");
        mouseClick(list, 100, list.headerHeight + list.itemsHeight + 6);
        wait(40);
        compare(spy.count, 0, "footer 那一段同样不算");
        mouseClick(list, 50, list.headerHeight + list.itemsHeight + list.footerHeight + 10);
        wait(40);
        compare(spy.count, 0, "loadMore 也不算");
        mouseClick(itemAt(list, 0), 60, 20);
        wait(40);
        compare(spy.count, 1, "落到条目上才算");
        spy.destroy();
        list.destroy();
    }

    function test_clickOnBlankTailOfHorizontalIsIgnored() {
        const list = make(`List {
            width: 400
            layout: "horizontal"
            dataSource: ["甲"]
            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        const spy = spyOn(list, "clicked");
        const item = itemAt(list, 0);
        compare(item.x + item.width < 400, true, "先确认右侧真的有空段");
        mouseClick(list, item.x + item.width + 20, 10);
        wait(40);
        compare(spy.count, 0, "空白处没有 li ⇒ 官方不发，端口也不发");
        spy.destroy();
        list.destroy();
    }

    function test_clickEmptyStateIsIgnored() {
        const list = make("List { width: 400 }");
        const spy = spyOn(list, "clicked");
        mouseClick(list, 200, 20);
        wait(40);
        compare(list.showEmpty, true);
        compare(spy.count, 0, "空态那条不是 -item");
        spy.destroy();
        list.destroy();
    }

    function test_rightClickSignals() {
        const list = makeList("", ["甲"]);
        const item = itemAt(list, 0);
        const listSpy = spyOn(list, "rightClicked");
        const itemSpy = spyOn(item, "rightClicked");
        mouseClick(item, 60, 20, Qt.RightButton);
        wait(40);
        compare(itemSpy.count, 1);
        compare(listSpy.count, 1, "官方 onContextMenu 就是 onRightClick（item.tsx:99）");
        // 左键不该串到右键信号上
        mouseClick(item, 60, 20, Qt.LeftButton);
        wait(40);
        compare(listSpy.count, 1);
        listSpy.destroy();
        itemSpy.destroy();
        list.destroy();
    }

    function test_stackedListsBothReact() {
        // 官方是 DOM 命中测试：只有最上面那条 li 收到。端口的 TapHandler 是被动 grab，
        // 两个叠在一起的 List 都会发 —— 这一条钉住「已知差异」，改 grab 策略时会见血。
        const host = make(`Item {
            width: 400
            height: 120

            List {
                objectName: "backList"
                anchors.fill: parent
                z: 1
                dataSource: ["甲"]
                renderItem: Component { ListItem { main: "后面" } }
            }

            List {
                objectName: "frontList"
                anchors.fill: parent
                z: 2
                dataSource: ["甲"]
                renderItem: Component { ListItem { main: "前面" } }
            }
        }`);
        settle(host);
        const back = part(host, "backList");
        const front = part(host, "frontList");
        const backSpy = spyOn(back, "clicked");
        const frontSpy = spyOn(front, "clicked");
        mouseClick(front.itemNodes()[0], 60, 20);
        wait(40);
        compare(frontSpy.count, 1);
        compare(backSpy.count, 1, "被动 grab ⇒ 压在下面的那条也收到（与官方不同，已登记）");
        backSpy.destroy();
        frontSpy.destroy();
        host.destroy();
    }

    // ---------------- loading ----------------

    function test_loadingDimsAndBlocksItems() {
        const list = makeList("", ["甲", "乙"]);
        const spy = spyOn(list, "clicked");
        const items = part(list, "listItems");
        const mask = part(list, "listSpinMask");
        const spin = part(list, "listSpin");
        compare(items.opacity, 1);
        compare(mask.visible, false);
        compare(part(spin, "spinWrapper").visible, false,
            "不转时指示符那一格不出现（官方不转时只是个空 div）");

        list.loading = true;
        wait(40);
        compare(items.opacity, 0.5, "$opacity-spin_children");
        compare(mask.visible, true);
        compare(part(spin, "spinWrapper").visible, true);
        compare(spin.side, 32, "官方 <Spin size=\"large\">");
        compare(Math.round(spin.y + spin.height / 2), Math.round(items.y + items.height / 2),
            "指示符在 items 那一段垂直居中");
        mouseClick(itemAt(list, 0), 60, 20);
        wait(40);
        compare(spy.count, 0, "-block::after 那层遮罩挡住穿透点击");

        list.loading = false;
        wait(40);
        mouseClick(itemAt(list, 0), 60, 20);
        wait(40);
        compare(spy.count, 1, "关掉加载态就能点了");
        spy.destroy();
        list.destroy();
    }

    function test_loadingDoesNotWrapHeaderOrFooter() {
        const list = makeList('header: "头"; footer: "尾"', ["甲"]);
        list.loading = true;
        wait(40);
        compare(part(list, "listHeader").opacity, 1, "官方 Spin 只包 children 那一层");
        compare(part(list, "listFooter").opacity, 1);
        list.destroy();
    }

    // ---------------- 重排 ----------------

    function test_growsWithDataSource() {
        const list = makeList("", ["甲"]);
        compare(list.itemsHeight, 44);
        list.dataSource = ["甲", "乙", "丙"];
        wait(60);
        compare(list.generatedCount, 3);
        compare(list.itemsHeight, 134);
        compare(itemAt(list, 2).y, 90);
        list.destroy();
    }

    function test_relayoutOnNarrowerWidth() {
        const list = makeList("", ["甲", "乙"]);
        const before = itemAt(list, 0).width;
        list.width = 300;
        wait(60);
        compare(itemAt(list, 0).width, 300);
        compare(before, 400);
        list.destroy();
    }

    function test_switchLayoutAndGrid() {
        const list = makeList("", ["甲", "乙", "丙"]);
        compare(itemAt(list, 1).x, 0, "纵向档全都贴左");
        list.layout = "horizontal";
        wait(60);
        compare(itemAt(list, 1).x > 0, true, "换横向档 ⇒ 接着排");
        compare(list.itemsHeight, itemAt(list, 0).height);
        list.layout = "vertical";
        list.grid = ({ gutter: 0, span: 12 });
        wait(60);
        compare(itemAt(list, 1).x, 200, "换栅格档 ⇒ 两列");
        compare(itemAt(list, 2).y, itemAt(list, 0).height, "第三格换行");
        list.destroy();
    }

    function test_itemReflowWhenItsContentGrows() {
        const list = make(`List {
            width: 400
            dataSource: ["甲", "乙"]
            renderItem: Component {
                ListItem {
                    id: grow

                    required property var modelData

                    main: Component {
                        Column {
                            spacing: 2
                            Repeater {
                                model: grow.modelData === "甲" ? 1 : 3

                                Text { text: "行"; font.pixelSize: 14 }
                            }
                        }
                    }
                }
            }
        }`);
        settle(list);
        const first = itemAt(list, 0);
        const second = itemAt(list, 1);
        compare(second.height > first.height, true, "正文三行比一行高");
        compare(first.y, 0);
        compare(second.y, first.height, "下面那条跟着往下挪");
        compare(list.itemsHeight, first.height + second.height);
        list.destroy();
    }

    function test_declaredChildrenChangeTriggersRelayout() {
        // 声明式子项那一档也会带着重排（官方 children 变了 React 就重渲染）
        const host = make(`Item {
            id: host

            property var rows: ["一"]

            List {
                objectName: "declaredList"
                width: 400

                Repeater {
                    model: host.rows
                    delegate: ListItem { main: modelData }
                }
            }
        }`);
        settle(host);
        const list = part(host, "declaredList");
        compare(list.declaredCount, 1);
        const one = list.itemsHeight;
        host.rows = ["一", "二"];
        wait(60);
        compare(list.declaredCount, 2);
        // 加了一条之后，原来那条不再是末条 ⇒ 它自己补上 1px 的线（44 → 45）
        compare(list.itemsHeight, one + 45, "新加的那条把容器顶高");
        compare(list.itemsHeight, itemAt(list, 0).height + itemAt(list, 1).height);
        compare(itemAt(list, 0).hasSeam, true, "它不再是末条");
        host.destroy();
    }

    // ---------------- 变异复核补的洞（第一轮这 24 处改坏都没被抓住） ----------------

    function test_footerInsetAndLoadMoreOffset() {
        const list = makeList(`header: "头"
            footer: "尾"
            loadMore: Component { Rectangle { width: 60; height: 20; color: "transparent" } }`,
            ["甲"]);
        compare(part(list, "listFooterPaddingBox").y, list.bandPadV + 1,
            "footer 的内缩要让开顶边那条线");
        compare(part(list, "listLoadMore").y,
            list.headerHeight + list.itemsHeight + list.footerHeight,
            "loadMore 排在 header + items + footer 之后");
        list.split = false;
        wait(40);
        compare(part(list, "listFooterPaddingBox").y, list.bandPadV, "没有线就不用让那 1px");
        list.destroy();
    }

    function test_horizontalStretchesToTheTallest() {
        const list = make(`List {
            width: 500
            layout: "horizontal"
            dataSource: [{ rows: 1 }, { rows: 3 }]

            renderItem: Component {
                ListItem {
                    id: cell

                    required property var modelData

                    Column {
                        spacing: 2
                        Repeater {
                            model: cell.modelData.rows

                            Text { text: "行"; font.pixelSize: 14 }
                        }
                    }
                }
            }
        }`);
        settle(list);
        const short = itemAt(list, 0);
        const tall = itemAt(list, 1);
        compare(tall.height > short.implicitHeight, true, "先确认两条内容确实不一样高");
        compare(short.height, tall.height, "官方 .semi-list-items{display:flex} 交叉轴初值 stretch");
        compare(list.itemsHeight, tall.height);
        list.destroy();
    }

    function test_itemContentGrowthReflowsWithoutAnyTrigger() {
        // 条目自己长高（List 这边一个属性都没动）时，靠的是容器对 childrenRect 的钩子
        const list = make(`List {
            width: 400
            dataSource: ["甲", "乙"]

            renderItem: Component {
                ListItem {
                    id: cell

                    property int rows: 1

                    Column {
                        spacing: 2
                        Repeater {
                            model: cell.rows

                            Text { text: "行"; font.pixelSize: 14 }
                        }
                    }
                }
            }
        }`);
        settle(list);
        const first = itemAt(list, 0);
        const before = itemAt(list, 1).y;
        const firstBefore = first.height;
        first.rows = 3;
        wait(80);
        compare(first.height > firstBefore, true, "条目自己变高了");
        compare(itemAt(list, 1).y, first.height, "下面那条跟着挪");
        compare(itemAt(list, 1).y > before, true);
        compare(list.itemsHeight, first.height + itemAt(list, 1).height);
        list.destroy();
    }

    function test_gridGutterObjectPicksTheHighestMatchingStage() {
        const a = make(`List {
            width: 600
            grid: ({ gutter: ({ sm: 8, md: 20 }), xs: 6 })
            dataSource: ["甲"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(a);
        compare(a.viewportWidth, 900);
        compare(a.gutterAt(0), 20, "sm 与 md 都命中 ⇒ 从 xxl 往下扫，先中的是 md");
        a.destroy();

        const b = make(`List {
            width: 600
            grid: ({ gutter: ({ xl: 30, md: 20 }), xs: 6 })
            dataSource: ["甲"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(b);
        compare(b.gutterAt(0), 20, "xl 是 ≥1200，900 的窗口不命中 ⇒ 不能因为它排在前就用它");
        b.destroy();
    }

    function test_gridStageRules() {
        const objectForm = make(`List {
            width: 600
            grid: ({ xs: { span: 6 } })
            dataSource: ["甲"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(objectForm);
        compare(objectForm.colSpan(), 6, "档位给对象（{span}）也要认 —— 官方 Col 就允许两种写法");
        objectForm.destroy();

        // xs 那条规则官方压根没包在 media query 里 ⇒ 任何视口都生效
        const wide = make(`List {
            width: 600
            grid: ({ xs: 6, sm: 12 })
            dataSource: ["甲"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(wide);
        testCase.width = 400;
        wait(120);
        compare(wide.viewportWidth, 400, "视口读的是所在 Window 的宽");
        compare(wide.colSpan(), 6, "400 宽时 sm 不命中、xs 恒命中");
        testCase.width = 900;
        wait(120);
        compare(wide.colSpan(), 12, "回到 900 ⇒ sm 命中且排在 xs 之后 ⇒ 赢");
        wide.destroy();
    }

    function test_gridSpaceAroundKeepsHalfGaps() {
        const list = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, justify: "space-around" })
            dataSource: ["甲", "乙", "丙"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        // 行内容盒 612、三格 459 ⇒ 富余 153，每档 51，首尾各留半档
        compare(itemAt(list, 0).x, 25.5);
        compare(itemAt(list, 1).x, 229.5);
        compare(itemAt(list, 2).x, 433.5);
        compare(600 - (itemAt(list, 2).x + itemAt(list, 2).width), itemAt(list, 0).x,
            "space-around ⇒ 左右留白相等");
        list.destroy();
    }

    function test_gridAlignMiddleCentresWithinTheLine() {
        const list = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 12, align: "middle" })
            dataSource: [{ rows: 1 }, { rows: 3 }]

            renderItem: Component {
                ListItem {
                    id: cell

                    required property var modelData

                    Column {
                        spacing: 2
                        Repeater {
                            model: cell.modelData.rows

                            Text { text: "行"; font.pixelSize: 14 }
                        }
                    }
                }
            }
        }`);
        settle(list);
        const short = itemAt(list, 0);
        const tall = itemAt(list, 1);
        compare(short.y, (tall.height - short.height) / 2, "align middle ⇒ 矮格在行带里居中");
        compare(tall.y, 0);
        list.destroy();
    }

    function test_gridNullIsNotGrid() {
        const list = makeList('grid: null', ["甲"]);
        compare(list.gridOn, false, "官方 `grid: {…}` 是真值判断，null 不算开栅格");
        compare(itemAt(list, 0).inGrid, false);
        compare(itemAt(list, 0).padV, 12, "栅格没开 ⇒ 条目内边距不清零");
        compare(itemAt(list, 0).hasSeam, false, "只有一条 ⇒ 它是 last-child");
        list.destroy();
    }

    function test_bodyIsCreatedForMainOnly() {
        const row = make('ListItem { width: 400; main: "只有正文" }');
        compare(row.mainTaken, true);
        compare(row.bodyTaken, true, "官方 if (header || main) —— 单给 main 也建 body");
        compare(part(row, "listItemBody").visible, true);
        compare(part(row, "listItemMain").x, 0, "没有 header 就不该空出那 20");
        compare(row.bodyNaturalWidth, row.mainW);
        row.destroy();
    }

    function test_childrenOnlyRowStartsAtLeftPadding() {
        const row = make('ListItem { width: 400; Text { text: "贴着左边的内容" } }');
        compare(row.bodyTaken, false);
        compare(row.bodyWidth, 0, "body 那个 div 官方压根不创建 ⇒ 富余宽度谁都不吃");
        compare(part(row, "listItemChildren").x, row.padH, "内容就贴着左内边距");
        compare(row.contentWidth, 400 - row.padH * 2, "内容宽要扣掉左右内边距");
        row.extra = "附加";
        wait(40);
        compare(part(row, "listItemExtra").x,
            row.padH + row.bodyWidth + row.childrenW + row.extraGap,
            "extra 接在 children 之后，再往右 40");
        compare(row.childrenW > 0, true, "这一条真的有 children，不然上面那条断言是空转");
        row.destroy();
    }

    function test_contentHeightIsTheTallestOfTheThreeParts() {
        // children 最高：body 与 extra 都要在它中间居中
        const byChildren = make(`ListItem {
            width: 400
            main: "一行正文"
            extra: Component { Rectangle { width: 20; height: 20; color: "transparent" } }

            Column {
                spacing: 2

                Repeater {
                    model: 3

                    Text { text: "行"; font.pixelSize: 14 }
                }
            }
        }`);
        compare(byChildren.childrenH > byChildren.bodyNaturalHeight, true);
        compare(byChildren.childrenH > byChildren.extraH, true);
        compare(byChildren.contentHeight, byChildren.childrenH, "内容高要把 children 算进来");
        compare(part(byChildren, "listItemBody").y,
            byChildren.padV + (byChildren.contentHeight - byChildren.bodyNaturalHeight) / 2,
            "三段各自垂直居中（li 的 align-items:center）");
        compare(part(byChildren, "listItemChildren").y, byChildren.padV,
            "最高的那条居中后正好贴在 padV 上");
        byChildren.destroy();

        // extra 最高：body 与 children 都得在 li 的内容盒里居中（不是贴顶）
        const byExtra = make(`ListItem {
            width: 400
            main: "一行正文"
            extra: Component { Rectangle { width: 20; height: 60; color: "transparent" } }

            Text { text: "一行孩子" }
        }`);
        compare(byExtra.contentHeight, 60, "内容高也要把 extra 算进来");
        compare(byExtra.height, 60 + 24);
        compare(byExtra.childrenH < 60 && byExtra.childrenH > 0, true,
            "children 比 extra 矮 ⇒ 居中这件事才有可观测对象");
        compare(part(byExtra, "listItemBody").y,
            byExtra.padV + (60 - byExtra.bodyNaturalHeight) / 2,
            "三段各自垂直居中在 li 的内容盒里");
        compare(part(byExtra, "listItemChildren").y,
            byExtra.padV + (60 - byExtra.childrenH) / 2,
            "children 那一排也要居中，不是贴顶");
        compare(part(byExtra, "listItemMain").y, 0,
            "align 缺省 flex-start ⇒ main 在 body 那格里贴顶");
        byExtra.destroy();
    }

    function test_headerMainGapOnlyWhenBothPresent() {
        const headerOnly = make('ListItem { width: 400; header: "只有头" }');
        compare(headerOnly.headerTaken, true);
        compare(headerOnly.mainTaken, false);
        compare(headerOnly.bodyNaturalWidth, headerOnly.headerW,
            "header 右外边距是 .semi-list-item-body-header 给的，main 不在就不该占这 20");
        compare(headerOnly.naturalWidth, headerOnly.headerW);
        headerOnly.destroy();
    }

    function test_falsyReactNodeSlotsDoNotTakeSpace() {
        const empty = make('ListItem { width: 400; header: ""; main: "正文" }');
        compare(empty.headerTaken, false, "官方 {header ? <div> : null} 走 JS 真值");
        compare(empty.bodyNaturalWidth, empty.mainW, "空 header 不能占那 20");
        empty.destroy();

        const zero = make('ListItem { width: 400; extra: 0; main: "正文" }');
        compare(zero.extraTaken, false, "0 也是假值");
        compare(zero.extraBlockWidth, 0);
        zero.destroy();

        const textZero = make('ListItem { width: 400; header: "0" }');
        compare(textZero.headerTaken, true, "字符串 \"0\" 在 JS 里是真值");
        compare(part(textZero, "listItemHeaderText").text, "0");
        textZero.destroy();
    }

    function test_numberReactNodeRendersAsText() {
        const row = make("ListItem { width: 400; main: 7 }");
        compare(row._isText(7), true, "官方 ReactNode 收数字，端口按文字档渲染");
        compare(part(row, "listItemMainText").text, "7");
        compare(part(row, "listItemMainNode").item === null, true, "节点档不该实例化");
        row.destroy();
    }

    function test_backgroundSlotFillsTheWholeItem() {
        const list = make(`List {
            width: 400
            dataSource: ["甲"]

            renderItem: Component {
                ListItem {
                    id: bgRow

                    required property var modelData

                    background: Component {
                        Rectangle {
                            objectName: "bgRect"

                            anchors.fill: parent
                            color: Theme.current.colorFill0
                        }
                    }

                    Text { text: String(bgRow.modelData) }
                }
            }
        }`);
        settle(list);
        const row = itemAt(list, 0);
        const host = part(row, "listItemBackground");
        compare(host.item !== null, true, "给了 Component 就得真的装载");
        compare(host.width, row.width, "底色铺满整条 li（含内边距）");
        compare(host.height, row.height);
        const rect = part(row, "bgRect");
        compare(rect.x, 0);
        compare(rect.y, 0);
        compare(rect.color, Theme.current.colorFill0);
        list.destroy();
    }


    function test_spanZeroHidesWithoutBreakingSizing() {
        // 900 的窗口命中 sm ⇒ span 0（官方 -col-0 是 display:none）；把窗口收窄到 sm 以下，
        // 只剩恒生效的 xs ⇒ 必须能重新长回来。钉过 height 的实现回不来（cocoa 截图抓到过）。
        const list = make(`List {
            width: 600
            grid: ({ xs: 24, sm: 0 })
            dataSource: ["甲", "乙"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        compare(list.colSpan(), 0);
        compare(itemAt(list, 0).visible, false);
        compare(list.itemsHeight, 0);

        testCase.width = 500;
        wait(150);
        compare(list.viewportWidth, 500);
        compare(list.colSpan(), 24, "xs 那条规则没包 media query ⇒ 只剩它时按 24 排");
        compare(itemAt(list, 0).visible, true);
        compare(itemAt(list, 0).height, 20, "栅格档内边距为 0 ⇒ 一条就是内容高");
        compare(list.itemsHeight, 40, "两行");
        testCase.width = 900;
        wait(150);
        list.destroy();
    }

    function test_leavingHorizontalRestoresContentHeight() {
        const list = make(`List {
            width: 500
            dataSource: [{ rows: 1 }, { rows: 3 }]

            renderItem: Component {
                ListItem {
                    id: cell

                    required property var modelData

                    Column {
                        spacing: 2
                        Repeater {
                            model: cell.modelData.rows

                            Text { text: "行"; font.pixelSize: 14 }
                        }
                    }
                }
            }
        }`);
        settle(list);
        const short = itemAt(list, 0);
        const tall = itemAt(list, 1);
        const ownHeight = short.height;
        compare(tall.height > short.height, true, "两条本来就不等高");

        list.layout = "horizontal";
        wait(80);
        compare(short.height, tall.height, "横向档 stretch ⇒ 同排等高");

        list.layout = "vertical";
        wait(80);
        compare(short.height, ownHeight, "切回纵向 ⇒ 高要还给内容自己");
        compare(itemAt(list, 1).y, short.height, "下面那条也贴回上一条的下沿");
        // 还高之后必须再补一趟：那一趟要把「按各自高的位置与整段高」重算成新的数，
        // 少了补的那一趟，这里读到的还是横向档那趟留下的旧数。
        compare(list.itemsHeight, short.height + tall.height, "整段高按还回来的两条重新累加");
        list.destroy();
    }

    // 窄下来 ⇒ 条目里的文字换行 ⇒ 条目自己变高。这次变高是 List 写宽顶出来的，尺寸
    // watcher 是在排版中途收到通知的（重入守卫先记一笔、收尾再补一趟），所以位置与
    // 整段高都得跟着新高度走 —— 官方那是浏览器重排，端口没有「下一轮」可等。
    function test_narrowingWrapsItemAndReflowsStack() {
        const list = make(`List {
            width: 400
            dataSource: ["一二三四五六七八九十", "短"]

            renderItem: Component {
                ListItem {
                    id: cell

                    required property var modelData

                    Text {
                        width: cell.width - cell.padH * 2
                        wrapMode: Text.Wrap
                        text: cell.modelData
                        font.pixelSize: 14
                    }
                }
            }
        }`);
        settle(list);
        const first = itemAt(list, 0);
        const second = itemAt(list, 1);
        const wideH = first.height;
        list.width = 120;
        wait(80);
        compare(first.height > wideH, true, "窄下来 ⇒ 文字换行 ⇒ 条目变高");
        compare(second.y, first.height, "下面那条跟着挪到新下沿");
        compare(list.itemsHeight, first.height + second.height, "整段高也要跟上");
        list.destroy();
    }

    // 横向档那档钉过高的条目，内容再自己长高时 `height` 不会再跟 `implicitHeight`
    // （钉过一次就断），只有条目身上那四个尺寸信号里「隐式高」这一路能把整排重新拉平。
    function test_growingStretchedItemReraisesWholeRow() {
        const list = make(`List {
            id: lst

            width: 500
            layout: "horizontal"
            property int rows: 1

            ListItem { objectName: "rowA" }
            ListItem { objectName: "rowB" }

            Column {
                Repeater {
                    model: lst.rows

                    Text { text: "行"; font.pixelSize: 14 }
                }
            }
        }`);
        settle(list);
        const a = testCase.findChild(list, "rowA");
        const b = testCase.findChild(list, "rowB");
        const flat = a.height;
        compare(a.height, b.height, "同排等高");
        list.rows = 4;
        wait(80);
        compare(a.height > flat, true, "内容长高 ⇒ 整排重新拉平");
        compare(b.height, a.height, "另一条也要跟着到新的排高");
        compare(list.itemsHeight, a.height, "整段高跟着新排高");
        list.destroy();
    }


    function test_implicitHeightSumsFourBands() {
        const list = makeList(`header: "头"
            footer: "尾"
            loadMore: Component { Rectangle { width: 100; height: 30; color: "transparent" } }`,
            ["甲", "乙"]);
        compare(list.implicitHeight,
            list.headerHeight + list.itemsHeight + list.footerHeight + list.loadMoreHeight);
        compare(list.headerHeight, 45);
        compare(list.itemsHeight, 89);
        compare(list.footerHeight, 45);
        compare(list.loadMoreHeight, 30);
        list.destroy();
    }

    // ---------------- Col 的 offset / push / pull / order ----------------
    // 规则在 grid/mixin.scss:57-80：offset 是 margin-left（占格、影响换行），
    // push / pull 是 position:relative 下的 left / right（只挪像素、不参与排版），
    // order 是 flex 的 order。

    function test_gridOffsetTakesItsOwnColumns() {
        // unit = (600 + 12) / 24 = 25.5 ⇒ 一格 153、offset 2 那截 51
        const list = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, offset: 2 })
            dataSource: ["甲", "乙", "丙", "丁", "戊"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        const nodes = nodesOf(list);
        compare(nodes.length, 5);
        compare(nodes[0].width, 141, "格子的内容宽不含 offset 那截");
        compare(nodes[0].x, 51, "首格被 margin-left 从行首推开 51");
        compare(nodes[1].x, 255);
        compare(nodes[2].x, 459);
        compare(nodes[3].y, 20, "每格多占 51 ⇒ 一行只塞得下三条（不给 offset 时是四条）");
        compare(nodes[3].x, 51);
        compare(nodes[4].x, 255);
        compare(list.itemsHeight, 40);
        list.destroy();
    }

    function test_gridOffsetZeroAndNegativeAreNoops() {
        // mixin 的 loop 从 1 数到 24 ⇒ -offset-0 与 -offset--2 都没有规则 ⇒ 等于没给
        const zero = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, offset: 0 })
            dataSource: ["甲", "乙", "丙", "丁"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(zero);
        compare(zero.colProp("offset"), 0);
        compare(itemAt(zero, 0).x, 0, "给 0 不推开");
        compare(itemAt(zero, 3).x, 459, "四条还是一行（挤不掉）");
        zero.destroy();

        const neg = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, offset: -2 })
            dataSource: ["甲", "乙"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(neg);
        compare(itemAt(neg, 0).x, 0, "负数也落不到规则上 ⇒ 不往左挪");
        compare(itemAt(neg, 1).x, 153);
        neg.destroy();
    }

    function test_gridPushShiftsWithoutReflowing() {
        const list = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, push: 2 })
            dataSource: ["甲", "乙", "丙", "丁", "戊"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        compare(itemAt(list, 0).x, 51);
        compare(itemAt(list, 0).width, 141, "相对位移不改宽");
        compare(itemAt(list, 1).x, 204, "153 + 51");
        compare(itemAt(list, 3).x, 510, "换行照旧（四条一行），只是每条往右挪 51");
        compare(itemAt(list, 4).y, 20);
        compare(itemAt(list, 3).x + itemAt(list, 3).width, 651,
            "官方是 relative 的 left ⇒ 能把内容推出容器，端口同样不夹");
        list.destroy();
    }

    function test_gridPullShiftsLeftAndPushWinsOverPull() {
        const pull = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, pull: 1 })
            dataSource: ["甲", "乙"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(pull);
        compare(itemAt(pull, 0).x, -25.5, "pull 是 right: n/24 ⇒ 往左");
        compare(itemAt(pull, 1).x, 127.5);
        pull.destroy();

        const both = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, push: 2, pull: 4 })
            dataSource: ["甲"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(both);
        compare(itemAt(both, 0).x, 51, "同时给 left 与 right ⇒ over-constrained，left 赢");
        both.destroy();
    }

    function test_gridOrderIsInertForList() {
        // 官方那个 grid 对象是**原样摊给每一条 Col** 的（item.tsx:50-58 把同一个 rest 交给
        // 每个 Col）⇒ 所有 Col 拿到同一个 order，flex 里等值即保持源码顺序。
        // 这条钉住「收了但不挪」是官方行为，不是端口漏排。
        const list = make(`List {
            width: 600
            grid: ({ gutter: 12, span: 6, order: 3 })
            dataSource: ["甲", "乙", "丙"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        compare(list.colProp("order"), 3, "属性收得到");
        compare(itemAt(list, 0).x, 0);
        compare(itemAt(list, 1).x, 153);
        compare(itemAt(list, 2).x, 306);
        list.grid = ({ gutter: 12, span: 6, order: 17 });
        wait(60);
        compare(itemAt(list, 1).x, 153, "order 换成别的值也不改序 —— List 没有单条改序的入口");
        list.destroy();
    }

    function test_gridStageObjectCarriesEachPropertySeparately() {
        // 档位是按属性各取各的：col.tsx:73-84 把各档的类名并进同一个对象，
        // 后写的档只覆盖自己带的那几项 ⇒ md 只给 span 时，sm 那条 offset 留着。
        const list = make(`List {
            width: 600
            grid: ({ sm: { span: 12, offset: 2 }, md: { span: 6 } })
            dataSource: ["甲", "乙", "丙", "丁"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(list);
        compare(list.colSpan(), 6, "900 的窗口 md 命中 ⇒ span 被 md 改写");
        compare(list.colProp("offset"), 2, "md 没给 offset ⇒ 停在 sm 那档");
        // 没有 gutter ⇒ unit = 600/24 = 25；一格 150、offset 50 ⇒ 每格占 200
        compare(itemAt(list, 0).width, 150);
        compare(itemAt(list, 0).x, 50);
        compare(itemAt(list, 1).x, 250);
        compare(itemAt(list, 2).x, 450);
        compare(itemAt(list, 3).y, 20, "每格 200 ⇒ 一行三条");
        list.destroy();

        // 数字档（`md: 6`）只带 span，也不清别的属性
        const numeric = make(`List {
            width: 600
            grid: ({ sm: { span: 12, offset: 2 }, md: 6 })
            dataSource: ["甲", "乙", "丙"]

            renderItem: Component { ListItem { main: modelData } }
        }`);
        settle(numeric);
        compare(numeric.colSpan(), 6, "数字档按 { span } 用");
        compare(numeric.colProp("offset"), 2, "数字档不清 offset");
        compare(itemAt(numeric, 0).x, 50);
        numeric.destroy();
    }

    // ---------------- List.Item 的 hover 回调 ----------------

    function test_itemMouseEnteredAndLeft() {
        const list = make(`List {
            width: 400
            dataSource: ["甲"]

            renderItem: Component {
                ListItem {
                    id: hovItem

                    objectName: "hovItem"
                    main: "标题"

                    property bool hovered: false

                    onMouseEntered: hovItem.hovered = true
                    onMouseLeft: hovItem.hovered = false

                    background: Component {
                        Rectangle {
                            objectName: "hovShell"

                            anchors.fill: parent
                            color: hovItem.hovered ? Theme.current.colorFill0 : "transparent"
                        }
                    }
                }
            }
        }`);
        settle(list);
        const item = part(list, "hovItem");
        // 先把指针放到离这条 li 很远的地方，起点的「没悬浮」才是确定的
        // （前面几条用例会把指针留在条目上，直接读底色会读到上一台的悬浮态）
        mouseMove(testCase, 2, testCase.height - 2);
        wait(60);
        const entered = spyOn(item, "mouseEntered");
        const left = spyOn(item, "mouseLeft");
        const before = part(item, "hovShell").color.toString();
        verify(before !== Theme.current.colorFill0.toString(), "起点：还没悬浮");

        // 内边距里那一圈也算命中：官方处理器挂在 li 上，端口的 HoverHandler 挂在整条 Item 上
        mouseMove(item, 2, 2);
        wait(60);
        compare(entered.count, 1, "onMouseEnter（item.tsx:100）在 padding 里也发");
        // 底色真的跟着铺上了（断的是渲染出来的那一条，不是公式自己）
        compare(part(item, "hovShell").color.toString(), Theme.current.colorFill0.toString(),
            "mouseEntered 之后铺的是 fill-0");
        // 在同一条 li 内部走动不重发 —— 官方用的是 mouseenter / mouseleave，不是 over / out
        mouseMove(item, item.width / 2, item.height / 2);
        wait(60);
        compare(entered.count, 1, "从 padding 走到正文不该再发一次");
        mouseMove(testCase, 2, testCase.height - 2);
        wait(60);
        compare(left.count, 1, "onMouseLeave（item.tsx:101）");
        compare(entered.count, 1);
        compare(part(item, "hovShell").color.toString(), before,
            "移开之后底色收回悬浮前的那一份");
        list.destroy();
    }

    function test_pushCtxToleratesHostSizeOnlyNodes() {
        // List.pushCtx 逐字段判存在再写：带 hostSize 的不止 ListItem —— DescriptionsItem
        // 也有 hostSize 但没有 hostLayout，无条件写会抛 TypeError 把 relayout() 中途打断、
        // layingOut 卡在 true ⇒ 之后所有重排被闸死、条目宽度永远钉不下来，polish 里
        // 「width 回落 implicitWidth + 位置器隐式尺寸吃子项实际宽」的环无限发散
        //（gallery ListPage 卡死那回 6 秒 24 万圈，见坑 136）
        const list = make(`List {
            width: 300
            ListItem {
                objectName: "hostRow"
                Descriptions {
                    objectName: "hostDesc"
                    width: 200
                    dataList: [{ "key": "键", "value": "值" }]
                }
            }
        }`);
        settle(list);
        const row = part(list, "hostRow");
        compare(row.width, 300, "重排没被 TypeError 打断 ⇒ 纵向档把条目宽度钉成 itemsBlock.width");
        compare(part(list, "hostDesc").width, 200, "Descriptions 自己声明的宽度没被动过");
        list.destroy();
    }
}
