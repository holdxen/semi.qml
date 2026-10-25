import QtQuick
import QtTest
import Semi

// ScrollList / ScrollItem。规格照 semi-ui/scrollList/{index.tsx,scrollItem.tsx} +
// semi-foundation/scrollList/{constants.ts,itemFoundation.ts,scrollList.scss,variables.scss}：
//   · 外壳只有 header / body / footer 三段（index.tsx:12-18 的 ScrollListProps）：本体 bg-3 +
//     圆角 6 + --semi-shadow-elevated 投影、**没有描边**；头部 padding 0 16，标题再套 16 0
//     且 600/text-0/14，底下一条 1px color-border 的 -line；body 高 $height-scrollList=300、
//     padding 0 16、flex 横排；列间一条 1px color-border；footer border-top 1px + padding 10。
//   · 滚轮逻辑全在列上（scrollItem.tsx）：mode 缺省 "wheel"、行高 36、滚动动画 120ms、
//     wheel 的滚动容器右侧留 18、中间选择带是 content-box 36 + 上下各 1px = 38 高、
//     上下遮罩各 50% 高再外扩 19（bg-3 + opacity .5）；normal 选中底 primary-light-default、
//     悬浮 fill-1、按下 fill-2；wheel 选中加粗换主色；cycled 只对 wheel 生效。
//   · 行项的 content 坐标 = i * 36（header/footer 那两块留白被 ListView 当钉死的项处理），
//     所以「第 i 项居中」等价于 contentY = i * 36 - 留白高，indexAtCenter 是它的逆运算。
// 用例跑在 705×1200 的窗口里；外壳默认会铺满父项，所以断言宽度的地方都显式写了 width。
TestCase {
    id: testCase

    name: "ScrollList"
    when: windowShown
    width: 705
    height: 1200

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "scrolllist");
    }

    function part(root, name) {
        return testCase.findChild(root, name);
    }

    // 单独一列：官方列是被外壳 flex 出来的，脱离外壳时自己给宽高（300 = $height-scrollList）
    function makeCol(qml) {
        return make("ScrollItem { width: 200; height: 300; " + qml + " }");
    }

    function scroller(col) {
        return part(col, "scrollItemScroller");
    }

    function rowText(col, modelIndex) {
        const row = scroller(col).itemAtIndex(modelIndex);
        return row === null ? null : part(row, "scrollItemRowText");
    }

    function rowBg(col, modelIndex) {
        const row = scroller(col).itemAtIndex(modelIndex);
        return row === null ? null : part(row, "scrollItemRowBg");
    }

    function spyFor(target, signalName) {
        const spy = Qt.createQmlObject("import QtTest; SignalSpy { signalName: '" + signalName
            + "' }", testCase, "spy");
        spy.target = target;
        return spy;
    }

    function makeRangeList(count, from) {
        const start = from === undefined ? 0 : from;
        const out = [];
        for (let i = 0; i < count; ++i)
            out.push({ "value": i + start });
        return out;
    }

    // 奇数项禁用，用来验吸附会跳过 disabled（官方 demo 用 Math.random，这里固定住）
    function makeOddDisabledList(count) {
        const out = [];
        for (let i = 0; i < count; ++i)
            out.push({ "value": i, "disabled": i % 2 === 1 });
        return out;
    }

    function pad(value, text) {
        return String(value === undefined ? text : value) + "点";
    }

    property Component headerNode: Item {
        objectName: "customHeaderNode"

        implicitWidth: 120
        implicitHeight: 40
    }

    property Component footerNode: Item {
        objectName: "customFooterNode"

        implicitWidth: 60
        implicitHeight: 24
    }

    property var ownTransform: function (value, text) {
        return "一";
    }

    property var apList: [{ "value": "上午" }, { "value": "下午" }]
    property var hourList: []
    property var minuteList: []

    // ---------------- 外壳：属性面与默认值 ----------------

    function test_shellDefaults() {
        const s = make("ScrollList { width: 400 }");
        compare(s.header, "", "官方 header 默认空 ReactNode");
        compare(s.footer, "");
        compare(s.bodyHeight, "", "bodyHeight 不传就走 CSS 的 300");
        compare(s.bodyHeightValue, 300);
        compare(s.className, "");
        compare(s.columnCount, 0);
        compare(s.headerTaken, false);
        compare(s.footerTaken, false);
        compare(s.headerHeight, 0);
        compare(s.footerHeight, 0);
        compare(s.implicitHeight, 300);
        s.destroy();
    }

    function test_shellFillsParentWidthLikeCss() {
        // 官方 .semi-scrolllist 是 width:100%，宽度由宿主给
        const host = Qt.createQmlObject("import QtQuick; Item { width: 320; height: 400 }",
            testCase, "host");
        const s = Qt.createQmlObject("import QtQuick; import Semi; ScrollList { }", host, "child");
        wait(60);
        compare(s.width, 320);
        compare(s.height, s.implicitHeight, "高度按内容三段算，官方 height:100% 在这里没基准");
        const bare = make("ScrollList { }");
        compare(bare.width, testCase.width, "父项是 705 宽的窗口时就铺满");
        bare.destroy();
        s.destroy();
        host.destroy();
    }

    function test_shellHasNoBorderButHasElevatedShadow() {
        const s = make("ScrollList { width: 400 }");
        const surface = part(s, "scrollListSurface");
        verify(surface !== null);
        // 「没有描边」这条只能在像素上验（QML 未赋值的 Rectangle 读 border.width 会给出
        // 1 这种假值，同组属性在 JS 侧不可信），这里只断言底面本身
        compare(surface.radius, Theme.current.radiusMedium);
        compare(part(s, "scrollListShadow").visible, true);
        s.destroy();
        // 浅色档 bg-0..bg-3 全是 #ffffff，底色断言必须换到深色档才有判别力（同坑 98）
        Theme.mode = Theme.Dark;
        verify(Theme.current.colorBg2 !== Theme.current.colorBg3,
            "深色档这两个令牌要分得开，否则下面那条是空的");
        const dark = make("ScrollList { width: 400 }");
        compare(part(dark, "scrollListSurface").color, Theme.current.colorBg3,
            "官方 .semi-scroll-list 底面是 bg-3");
        dark.destroy();
        Theme.mode = Theme.Light;
    }

    function test_shadowOffByStyle() {
        const a = make("ScrollList { width: 400; style: ({boxShadow: 'unset'}) }");
        compare(part(a, "scrollListShadow").visible, false, "官方 demo 就是靠这条关掉投影");
        const b = make("ScrollList { width: 400; style: ({boxShadow: 'none'}) }");
        compare(part(b, "scrollListShadow").visible, false);
        const c = make("ScrollList { width: 400; style: ({boxShadow: '0 0 4px red'}) }");
        compare(part(c, "scrollListShadow").visible, true, "只有 unset/none 才算关掉");
        a.destroy();
        b.destroy();
        c.destroy();
    }

    function test_surfaceColorFromStyle() {
        const s = make("ScrollList { width: 400; style: ({backgroundColor: '#ff0000'}) }");
        compare(part(s, "scrollListSurface").color, "#ff0000");
        const alt = make("ScrollList { width: 400; style: ({background: '#00ff00'}) }");
        compare(part(alt, "scrollListSurface").color, "#00ff00");
        const plain = make("ScrollList { width: 400; style: ({}) }");
        compare(part(plain, "scrollListSurface").color, Theme.current.colorBg3);
        s.destroy();
        alt.destroy();
        plain.destroy();
    }

    function test_bodyHeightAcceptsNumberAndCssString() {
        const a = make("ScrollList { width: 400; bodyHeight: 220 }");
        compare(a.bodyHeightValue, 220);
        compare(part(a, "scrollListBody").height, 220);
        const b = make("ScrollList { width: 400; bodyHeight: '180px' }");
        compare(b.bodyHeightValue, 180);
        const c = make("ScrollList { width: 400; bodyHeight: 0 }");
        compare(c.bodyHeightValue, 300, "0 / 空串都不给值，落回 $height-scrollList");
        const d = make("ScrollList { width: 400; bodyHeight: '50%' }");
        compare(d.bodyHeightValue, 300, "百分比没有确定基准，落回默认");
        a.destroy();
        b.destroy();
        c.destroy();
        d.destroy();
    }

    // ---------------- 外壳：header ----------------

    function test_headerTextMetrics() {
        const s = make("ScrollList { width: 400; header: '无限滚动列表' }");
        compare(s.headerTaken, true);
        compare(s.headerIsText, true);
        // 标题 14/20 + 上下各 16 + 那条 1px 的 -line
        compare(s.headerHeight, 20 + 32 + 1);
        const block = part(s, "scrollListHeader");
        compare(block.y, 0);
        compare(block.height, s.headerHeight);
        const padBox = part(s, "scrollListHeaderPaddingBox");
        compare(padBox.x, 16, "$spacing-scrollList_header-paddingX");
        compare(padBox.width, 400 - 32);
        const text = part(s, "scrollListHeaderText");
        compare(text.x, 0, "-header 的 16 内边距由外层 paddingBox 承担");
        compare(text.y, 16, "$spacing-scrollList_header_title-paddingY");
        compare(text.font.pixelSize, Theme.current.fontSizeRegular);
        compare(text.font.weight, Font.DemiBold, "$font-scrollList_header_title-fontWeight = 600");
        compare(text.color, Theme.current.colorText0);
        compare(text.horizontalAlignment, Text.AlignHCenter, "-header { text-align: center }");
        const line = part(s, "scrollListHeaderLine");
        compare(line.height, 1, "$height-scrollList_line");
        compare(line.color, Theme.current.colorBorder);
        compare(line.y, s.headerHeight - 1);
        s.destroy();
    }

    function test_headerAbsentKeepsBodyAtTop() {
        const s = make("ScrollList { width: 400 }");
        compare(part(s, "scrollListHeader").visible, false);
        compare(part(s, "scrollListBody").y, 0);
        s.destroy();
    }

    function test_headerTruthinessMatchesReact() {
        const empty = make("ScrollList { width: 400; header: '' }");
        compare(empty.headerTaken, false, "官方 {header ? <div> : null} 走真值判断");
        const zero = make("ScrollList { width: 400; header: 0 }");
        compare(zero.headerTaken, false, "数字 0 在 JS 里也是假值");
        const one = make("ScrollList { width: 400; header: 1 }");
        compare(one.headerTaken, true);
        compare(one.headerIsText, true);
        compare(part(one, "scrollListHeaderText").text, "1");
        empty.destroy();
        zero.destroy();
        one.destroy();
    }

    function test_headerNodeVariant() {
        const s = make("ScrollList { width: 400; header: testCase.headerNode }");
        compare(s.headerIsText, false);
        const host = part(s, "scrollListHeaderNode");
        verify(host !== null);
        compare(host.y, 16);
        verify(part(s, "customHeaderNode") !== null);
        compare(s.headerHeight, 40 + 32 + 1, "节点档：内容高 + 上下 16 + 那条线");
        compare(part(s, "scrollListBody").y, s.headerHeight);
        compare(part(s, "scrollListHeaderText").visible, false);
        s.destroy();
    }

    // ---------------- 外壳：body 与列排版 ----------------

    function test_bodyPaddingBox() {
        const s = make("ScrollList { width: 400; bodyHeight: 200; ScrollItem { } }");
        const host = part(s, "scrollListColumnHost");
        compare(host.x, 16, "$spacing-scrollList_body-paddingX");
        compare(host.width, 400 - 32);
        compare(host.height, 200);
        compare(part(s, "scrollListBody").height, 200);
        s.destroy();
    }

    function test_oneColumnFillsBody() {
        // 带头部与页脚：整壳高就不再等于 body 高，列高跟着壳走会看不出来
        const s = make("ScrollList { width: 400; header: '标题'; footer: '页脚';"
            + " ScrollItem { objectName: 'only' } }");
        compare(s.columnCount, 1);
        compare(s.columnWidth, 368);
        const col = part(s, "only");
        compare(col.x, 0);
        compare(Math.round(col.width), 368);
        compare(part(s, "scrollListBody").height, 300);
        verify(s.height > 300, "头部 53 + 页脚 41 都在壳高里，列高不能拿它当基准");
        compare(col.height, 300, "flex 交叉轴默认 stretch，列高 = body 高，不是整壳高");
        s.destroy();
    }

    function test_threeColumnsShareWidthAndSeam() {
        const s = make("ScrollList { width: 600; bodyHeight: 200; header: '标题';"
            + " ScrollItem { objectName: 'c1' } ScrollItem { objectName: 'c2' }"
            + " ScrollItem { objectName: 'c3' } }");
        compare(s.columnCount, 3);
        const expected = (568 - 2) / 3;
        verify(Math.abs(s.columnWidth - expected) < 0.01, "(600-32-2 条 1px) / 3");
        const first = part(s, "c1");
        const second = part(s, "c2");
        const third = part(s, "c3");
        compare(first.x, 0);
        compare(Math.round(second.x - first.x - first.width), 1, "列间正好一条 1px");
        compare(Math.round(third.x - second.x - second.width), 1);
        const seam = part(part(s, "scrollListColumnHost").parent, "scrollListColumnSeam");
        verify(seam !== null);
        compare(seam.width, 1, "$width-scrollList_item-border");
        verify(s.height > 200, "壳高含头部 53，缝不该跟着整壳长");
        compare(seam.height, 200, "border-right 通高一整列（body 高），不是壳高");
        compare(seam.height, part(s, "scrollListBody").height);
        compare(seam.color, Theme.current.colorBorder);
        compare(Math.round(seam.x), Math.round(16 + s.columnWidth));
        s.destroy();
    }

    function test_seamCountIsColumnsMinusOne() {
        const one = make("ScrollList { width: 400; ScrollItem { } }");
        compare(part(one, "scrollListSeams").count, 0, "官方是 :not(:last-child)，最后一列没有右边框");
        compare(testCase.findChild(one, "scrollListColumnSeam"), null);
        const two = make("ScrollList { width: 400; ScrollItem { } ScrollItem { } }");
        compare(part(two, "scrollListSeams").count, 1);
        const three = make("ScrollList { width: 400; ScrollItem { } ScrollItem { } ScrollItem { } }");
        compare(part(three, "scrollListSeams").count, 2);
        one.destroy();
        two.destroy();
        three.destroy();
    }

    function test_columnDeclaredWidthIsIgnored() {
        // 官方 flex: 1 即 flex-basis: 0%，声明的宽度被忽略
        const s = make("ScrollList { width: 400; ScrollItem { objectName: 'wide'; width: 900 }"
            + " ScrollItem { objectName: 'narrow'; width: 10 } }");
        compare(Math.round(part(s, "wide").width), Math.round(s.columnWidth));
        compare(Math.round(part(s, "narrow").width), Math.round(s.columnWidth));
        s.destroy();
    }

    function test_shellRelayoutsWhenAColumnIsAdded() {
        const s = make("ScrollList { width: 400; ScrollItem { objectName: 'a' } }");
        wait(60);
        const before = s.columnWidth;
        compare(before, 368);
        compare(s.columnCount, 1);
        Qt.createQmlObject("import QtQuick; import Semi; ScrollItem { objectName: 'b' }",
            part(s, "scrollListColumnHost"), "dyn");
        wait(60);
        compare(s.columnCount, 2);
        // 两条时宽度要让出那 1px 的缝：(368 - 1) / 2
        verify(Math.abs(s.columnWidth - (before - 1) / 2) < 0.01, "多一列就少一半，缝宽不变");
        verify(Math.abs(part(s, "b").x - (s.columnWidth + 1)) < 0.01, "第二列顶到缝的右边");
        s.destroy();
    }

    function test_shellWidthDrivesColumnWidth() {
        const s = make("ScrollList { width: 400; ScrollItem { objectName: 'w' } ScrollItem { } }");
        wait(60);
        const before = part(s, "w").width;
        s.width = 500;
        wait(60);
        verify(Math.abs(part(s, "w").width - before - 50) < 0.01,
            "(500-32-1)/2 比 (400-32-1)/2 正好多 50");
        s.destroy();
    }

    // ---------------- 外壳：footer ----------------

    function test_footerTextMetrics() {
        const s = make("ScrollList { width: 400; footer: '已选 3 项' }");
        compare(s.footerTaken, true);
        // border-top 1 + 上下 padding 10 + 一行 20
        compare(s.footerHeight, 1 + 20 + 20);
        const block = part(s, "scrollListFooter");
        compare(block.y, 300);
        compare(block.height, s.footerHeight);
        const border = part(s, "scrollListFooterBorder");
        compare(border.height, 1, "$width-scrollList_footer-border");
        compare(border.color, Theme.current.colorBorder);
        compare(border.y, 0);
        const text = part(s, "scrollListFooterText");
        compare(text.x, 10, "$spacing-scrollList_footer-padding");
        compare(text.y, 11);
        compare(text.horizontalAlignment, Text.AlignLeft, "text-align:center 只在 header，footer 靠左");
        s.destroy();
    }

    function test_footerNodeVariant() {
        const s = make("ScrollList { width: 400; footer: testCase.footerNode }");
        compare(s.footerIsText, false);
        const host = part(s, "scrollListFooterNode");
        compare(host.x, 10);
        compare(host.y, 11);
        verify(part(s, "customFooterNode") !== null);
        compare(s.footerHeight, 24 + 20 + 1);
        compare(part(s, "scrollListFooterText").visible, false);
        s.destroy();
    }

    function test_footerAbsentWhenFalsy() {
        const s = make("ScrollList { width: 400; footer: '' }");
        compare(s.footerTaken, false);
        compare(s.footerHeight, 0);
        compare(part(s, "scrollListFooter").visible, false);
        s.destroy();
    }

    function test_implicitHeightStacksThreeBlocks() {
        const s = make("ScrollList { width: 400; header: 'H'; bodyHeight: 200; footer: 'F' }");
        compare(s.headerHeight, 53);
        compare(s.footerHeight, 41);
        compare(s.implicitHeight, 53 + 200 + 41);
        compare(part(s, "scrollListFooter").y, 53 + 200);
        s.destroy();
    }

    // ---------------- 列：属性面与默认值 ----------------

    function test_columnDefaults() {
        const c = makeCol("");
        compare(c.mode, "wheel", "statics.defaultProps.mode = 'wheel'");
        compare(c.isWheel, true);
        compare(c.cycled, false);
        compare(c.selectedIndex, 0);
        compare(c.motion, true);
        compare(c.textTransform, null, "官方 transform 缺省不传");
        compare(c.list.length, 0);
        compare(c.dataCount, 0);
        compare(c.itemHeight, 36, "$height-scrollList_item");
        compare(c.duration, 120, "numbers.DEFAULT_SCROLL_DURATION");
        compare(c.wheelPadRight, 18, "$spacing-...-list_outer-paddingRight = 行高/2");
        compare(c.type, undefined);
        compare(c.implicitHeight, 300, "$height-scrollList：脱离外壳时按 CSS 默认高一档");
        c.destroy();
    }

    function test_normalModeColumn() {
        const c = makeCol("mode: 'normal'; list: [{value: 'a'},{value: 'b'}]");
        compare(c.isWheel, false);
        compare(scroller(c).width, c.width, "normal 是 .semi-scrolllist-item，右侧不留 18");
        compare(scroller(c).snapMode, ListView.NoSnap, "官方没有 scroll-snap，吸附靠 JS");
        compare(part(c, "scrollItemScrollBar").visible, true);
        compare(part(c, "scrollItemSelector").visible, false);
        compare(part(c, "scrollItemShadeBefore").visible, false);
        c.destroy();
    }

    function test_wheelColumnLeavesScrollbarGutter() {
        const c = makeCol("list: [{value: 'a'}]");
        compare(scroller(c).width, c.width - 18);
        compare(part(c, "scrollItemScrollBar").visible, false, "wheel 把滚动条藏进那 18px");
        compare(part(c, "scrollItemSelector").visible, true);
        c.destroy();
    }

    function test_rowsAreThirtySixAndCentered() {
        const c = makeCol("list: [{value: 1},{value: 2},{value: 3},{value: 4}]");
        wait(60);
        const view = scroller(c);
        compare(view.count, 4);
        for (let i = 0; i < 4; ++i)
            compare(view.itemAtIndex(i).height, 36);
        compare(part(c, "scrollItemPadBefore").height, (300 - 36) / 2,
            "ul::before + padding-bottom 那两块留白");
        compare(part(c, "scrollItemPadAfter").height, 132);
        compare(Math.round(view.contentY), -132, "selectedIndex 0 落在正中");
        compare(Math.round(view.itemAtIndex(0).mapToItem(c, 0, 0).y), 132);
        c.destroy();
    }

    function test_selectorBandGeometry() {
        const c = makeCol("list: [{value: 'a'}]");
        const band = part(c, "scrollItemSelector");
        // content-box：高 36 + 上下各 1px 描边 = 38；translateY(-50%) 后中心压住视口中线
        compare(band.height, 38);
        compare(Math.round(band.y), 150 - 19);
        const top = part(c, "scrollItemSelectorTop");
        const bottom = part(c, "scrollItemSelectorBottom");
        compare(top.height, 1);
        compare(bottom.height, 1);
        compare(top.color, Theme.current.colorBorder);
        compare(bottom.color, Theme.current.colorBorder);
        compare(Math.round(band.y + bottom.y), 150 + 18, "带子内沿正好是那 36px 的行位");
        c.destroy();
    }

    function test_shadeGeometryAndStacking() {
        const c = makeCol("list: [{value: 'a'}]");
        const before = part(c, "scrollItemShadeBefore");
        const after = part(c, "scrollItemShadeAfter");
        compare(before.height, 150, "height: 50%");
        compare(Math.round(before.y), -(18 + 1), "margin-top: -(行高/2 + 描边宽)");
        compare(Math.round(after.y), 150 + 18 + 1);
        compare(before.color, Theme.current.colorBg3);
        compare(after.color, Theme.current.colorBg3);
        compare(before.opacity, 0.5);
        compare(after.opacity, 0.5);
        // DOM 顺序 pre → selector → post → list-outer，定位项压住列表
        compare(before.z, 1);
        compare(part(c, "scrollItemSelector").z, 2);
        compare(after.z, 3);
        compare(scroller(c).z, 0);
        c.destroy();
    }

    // ---------------- 列：选中样式 ----------------

    function test_wheelSelectedRowIsBoldPrimary() {
        const c = makeCol("selectedIndex: 2; list: [{value: 0},{value: 1},{value: 2},{value: 3}]");
        wait(60);
        compare(c.selectedModel, 2);
        compare(rowText(c, 2).color, Theme.current.colorPrimary,
            "-item-selected { color: var(--semi-color-primary) !important }");
        compare(rowText(c, 2).font.weight, Font.DemiBold,
            "$font-scrollList_item_wheel_item_selected-fontWeight = 600");
        compare(rowText(c, 1).color, Theme.current.colorText0);
        compare(rowText(c, 1).font.weight, Font.Normal);
        compare(rowBg(c, 2).visible, false, "wheel 不给选中底色，-item-sel 只在 normal 挂");
        c.destroy();
    }

    function test_normalSelectedRowUsesLightDefault() {
        const c = makeCol("mode: 'normal'; selectedIndex: 1; list: [{value: 'a'},{value: 'b'},{value: 'c'}]");
        wait(60);
        compare(rowBg(c, 1).visible, true);
        compare(rowBg(c, 1).color, Theme.current.colorPrimaryLightDefault);
        compare(rowText(c, 1).color, Theme.current.colorText0, "normal 选中文字仍是 text-0");
        compare(rowText(c, 1).font.weight, Font.Normal, "只有 wheel 选中才加粗");
        compare(rowBg(c, 0).visible, false);
        c.destroy();
    }

    function test_normalHoverAndPressFill() {
        const c = makeCol("mode: 'normal'; selectedIndex: 2; list: [{value: 'a'},{value: 'b'},{value: 'c'}]");
        wait(60);
        const row1 = scroller(c).itemAtIndex(1);
        mouseMove(row1, 60, 18);
        wait(40);
        compare(rowBg(c, 1).visible, true, "$color-scrollList_item-text-hover = fill-1");
        compare(rowBg(c, 1).color, Theme.current.colorFill1);
        mousePress(row1, 60, 18);
        wait(40);
        compare(rowBg(c, 1).color, Theme.current.colorFill2, "$color-scrollList_item-bg-active");
        mouseRelease(row1, 60, 18);
        wait(40);
        // 官方那串 :not() 把选中项排除在悬浮/按下之外
        mouseMove(scroller(c).itemAtIndex(2), 60, 18);
        wait(40);
        compare(rowBg(c, 2).color, Theme.current.colorPrimaryLightDefault);
        c.destroy();
    }

    function test_wheelHoverAlsoFillsButSelectedRowDoesNot() {
        const c = makeCol("selectedIndex: 1; list: [{value: 0},{value: 1},{value: 2}]");
        wait(60);
        const sel = scroller(c).itemAtIndex(1);
        const plain = scroller(c).itemAtIndex(2);
        compare(c.selectedModel, 1, "选中项就是第 1 行，下面两段都按这个前提量");
        // 未选那一行先亮 —— 这是「指针真的进得来」的判别力哨兵
        mouseMove(plain, 60, 18);
        wait(40);
        mouseMove(plain, 62, 18);
        wait(40);
        compare(part(plain, "scrollItemRowWheelBg").visible, true, "li:hover 的规则对 wheel 也生效");
        compare(part(plain, "scrollItemRowWheelBg").color, Theme.current.colorFill1);
        // 然后把指针真的挪到选中那一行上（只在原地断「没悬浮」的话，任何一档都是绿的）
        mouseMove(sel, 60, 18);
        wait(40);
        mouseMove(sel, 62, 18);
        wait(40);
        compare(part(plain, "scrollItemRowWheelBg").visible, false, "指针确实离开了未选那一行");
        compare(part(sel, "scrollItemRowWheelBg").visible, false,
            ":not(.semi-scrolllist-item-selected) 把选中那行排除在悬浮之外");
        mousePress(sel, 60, 18);
        wait(40);
        compare(part(sel, "scrollItemRowWheelBg").visible, false, "选中那行连按下也不染");
        mouseRelease(sel, 60, 18);
        wait(60);
        compare(c.selectedModel, 1, "点的就是选中那一行，落位不变");
        // 未选那行的按下档 = fill-2
        mousePress(plain, 60, 18);
        wait(40);
        compare(part(plain, "scrollItemRowWheelBg").color, Theme.current.colorFill2);
        mouseRelease(plain, 60, 18);
        wait(40);
        c.destroy();
    }

    function test_disabledRowStylingAndNoHover() {
        const c = makeCol("mode: 'normal'; list: [{value: 'a'},{value: 'b', disabled: true}]");
        wait(60);
        compare(rowText(c, 1).color, Theme.current.colorDisabledText);
        mouseMove(scroller(c).itemAtIndex(1), 60, 18);
        wait(40);
        mouseMove(scroller(c).itemAtIndex(1), 62, 18);
        wait(40);
        compare(rowBg(c, 1).visible, false, ":not(.disabled) 才给悬浮底");
        // 官方 .disabled 给 cursor: not-allowed，未禁用的给 pointer —— 悬浮 handler 常开，
        // 这条是唯一能观察「指针真的在这行上」的量
        const off = part(scroller(c).itemAtIndex(1), "scrollItemRowHover");
        const on = part(scroller(c).itemAtIndex(0), "scrollItemRowHover");
        compare(off.cursorShape, Qt.ForbiddenCursor);
        compare(on.cursorShape, Qt.PointingHandCursor);
        c.destroy();

        // wheel 档同一条：禁用行即便被悬浮也不染 fill-1
        const w = makeCol("list: [{value: 0},{value: 1, disabled: true},{value: 2}]");
        wait(60);
        mouseMove(scroller(w).itemAtIndex(1), 60, 18);
        wait(40);
        mouseMove(scroller(w).itemAtIndex(1), 62, 18);
        wait(40);
        compare(part(scroller(w).itemAtIndex(1), "scrollItemRowWheelBg").visible, false,
            "wheel 的悬浮底也排除禁用项");
        w.destroy();
    }

    // ---------------- 列：文案与 transform ----------------

    function test_textFallsBackToValue() {
        const c = makeCol("list: [{value: 7}, {text: '八', value: 8}]");
        wait(60);
        compare(rowText(c, 0).text, "7", "item.text == null ? item.value : item.text");
        compare(rowText(c, 1).text, "八");
        c.destroy();
    }

    function test_plainStringItemRendersEmptyLikeReact() {
        // 官方 ItemData 是对象；直接塞字符串时 item.text 与 item.value 都是 undefined
        const c = makeCol("list: ['甲']");
        wait(60);
        compare(rowText(c, 0).text, "", "照抄 scrollItem.tsx:431 的取值，不做字符串兼容");
        c.destroy();
    }

    function test_transformAppliesToSelectedRowOnly() {
        const c = makeCol("selectedIndex: 1; textTransform: testCase.pad;"
            + " list: [{value: 1},{value: 2},{value: 3}]");
        wait(60);
        compare(rowText(c, 1).text, "2点", "官方只对选中那一项跑 transform");
        compare(rowText(c, 0).text, "1");
        compare(rowText(c, 2).text, "3");
        c.destroy();
    }

    function test_itemTransformWinsOverColumnTransform() {
        const c = makeCol("selectedIndex: 0; textTransform: testCase.pad;"
            + " list: [{value: 1, transform: testCase.ownTransform},{value: 2}]");
        wait(60);
        compare(rowText(c, 0).text, "一", "ItemData.transform 优先于整列的");
        c.destroy();
    }

    // ---------------- 列：选择与信号 ----------------

    function test_normalClickNotifiesWithoutScrolling() {
        const c = makeCol("mode: 'normal'; list: [{value: 'a'},{value: 'b'},{value: 'c'}]");
        wait(60);
        const spy = spyFor(c, "select");
        const before = scroller(c).contentY;
        // 第一下就点「当前 selectedIndex 那一行」：官方 selectIndex 不看缓存，
        // 这一发也在把 __lastNotified 里那个初值当挡箭牌的做法会当场少一条
        mouseClick(scroller(c).itemAtIndex(0), 60, 18);
        wait(60);
        compare(spy.count, 1, "官方 normal 的 li onClick → foundation.selectIndex");
        compare(scroller(c).contentY, before, "selectIndex 不滚，只有 selectNode 才滚");
        mouseClick(scroller(c).itemAtIndex(1), 60, 18);
        wait(60);
        compare(spy.count, 2);
        // 回到第一行：官方 selectIndex 每次点击都通知，没有 selectNode 那套去重。
        // （连点同一位置会被 TapHandler 当双击吞掉，所以这里靠「换一行再点回来」证明没去重）
        mouseClick(scroller(c).itemAtIndex(0), 60, 18);
        wait(60);
        compare(spy.count, 3, "normal 点选不去重，回到同一行照样再发一次");
        compare(spy.signalArguments[2][0].index, 0);
        c.destroy();
    }

    function test_selectPayloadCarriesItemDataPlusTypeAndIndex() {
        const c = makeCol("mode: 'normal'; type: 7; list: [{value: 'a'},{value: 'b', extra: 5}]");
        wait(60);
        const spy = spyFor(c, "select");
        mouseClick(scroller(c).itemAtIndex(1), 60, 18);
        wait(60);
        compare(spy.count, 1);
        const data = spy.signalArguments[0][0];
        compare(data.value, "b");
        compare(data.extra, 5, "官方载荷是 {...item, value, type, index}");
        compare(data.type, 7);
        compare(data.index, 1);
        c.destroy();
    }

    function test_disabledRowIgnoresClickInBothModes() {
        const normal = makeCol("mode: 'normal'; list: [{value: 'a'},{value: 'b', disabled: true}]");
        const spyN = spyFor(normal, "select");
        mouseClick(scroller(normal).itemAtIndex(1), 60, 18);
        wait(60);
        compare(spyN.count, 0, "normal 只给未禁用的 li 挂 onClick");
        normal.destroy();

        const wheel = makeCol("list: [{value: 'a'},{value: 'b', disabled: true}]");
        const spyW = spyFor(wheel, "select");
        mouseClick(scroller(wheel).itemAtIndex(1), 60, 18);
        wait(60);
        compare(spyW.count, 0, "wheel 的 clickToSelectItem 也要过 disabled");
        compare(wheel.selectedModel, 0);
        wheel.destroy();
    }

    function test_wheelClickScrollsRowToCenterAndNotifies() {
        const c = makeCol("list: [{value: 0},{value: 1},{value: 2},{value: 3}]");
        wait(60);
        const spy = spyFor(c, "select");
        mouseClick(scroller(c).itemAtIndex(3), 60, 18);
        wait(240);
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0].index, 3);
        compare(c.selectedModel, 3);
        compare(Math.round(scroller(c).contentY), 3 * 36 - 132, "官方 selectNode 里 scrollToCenter");
        c.destroy();
    }

    function test_wheelClickOnAlreadySelectedDoesNotNotifyTwice() {
        const c = makeCol("selectedIndex: 1; list: [{value: 0},{value: 1},{value: 2}]");
        wait(60);
        const spy = spyFor(c, "select");
        mouseClick(scroller(c).itemAtIndex(1), 60, 18);
        wait(220);
        compare(spy.count, 0, "_cachedSelectedNode / cachedIndexData 去重，同项不重发");
        c.destroy();
    }

    function test_selectedIndexPropRecenters() {
        const c = makeCol("list: [{value: 0},{value: 1},{value: 2},{value: 3},{value: 4}]");
        wait(60);
        compare(Math.round(scroller(c).contentY), -132);
        c.selectedIndex = 4;
        wait(260);
        compare(Math.round(scroller(c).contentY), 4 * 36 - 132);
        compare(c.selectedModel, 4);
        c.destroy();
    }

    function test_motionFalseJumpsInsteadOfGlide() {
        const withMotion = makeCol("motion: true; list: [{value: 0},{value: 1},{value: 2}]");
        const noMotion = makeCol("motion: false; list: [{value: 0},{value: 1},{value: 2}]");
        wait(60);
        withMotion.selectedIndex = 2;
        noMotion.selectedIndex = 2;
        // 动画档这一帧还在半路，motion=false 那档必须已经到位
        compare(Math.round(scroller(noMotion).contentY), 2 * 36 - 132,
            "scrollToPos 里 duration && motion 为假时直接 setScrollTop");
        verify(Math.abs(scroller(withMotion).contentY - (2 * 36 - 132)) > 1, "另一档应该还在动");
        wait(260);
        compare(Math.round(scroller(withMotion).contentY), 2 * 36 - 132);
        withMotion.destroy();
        noMotion.destroy();
    }

    function test_snapAfterDragLandsOnARow() {
        const c = makeCol("");
        c.list = testCase.makeRangeList(12);
        wait(80);
        const view = scroller(c);
        const spy = spyFor(c, "select");
        mousePress(view, 80, 200);
        mouseMove(view, 80, 150, -1, Qt.LeftButton);
        mouseMove(view, 80, 100, -1, Qt.LeftButton);
        mouseRelease(view, 80, 100);
        wait(420);
        const offset = Math.round(view.contentY + (300 - 36) / 2);
        compare(offset % 36, 0, "落位必须正好对齐一行");
        compare(c.indexAtCenter(), c.selectedModel);
        verify(spy.count >= 1, "停下来的那一下要发 select");
        c.destroy();
    }

    function test_snapSkipsDisabledRows() {
        const c = makeCol("");
        c.list = testCase.makeOddDisabledList(10);
        wait(80);
        const view = scroller(c);
        view.contentY = c.contentYOfCentered(5);
        wait(60);
        compare(c.nearestEnabledIndex(5), 4, "getNearestNodeInfo 用 isDisabledIndex 跳过禁用项");
        const spy = spyFor(c, "select");
        c.settleAfterScroll();
        wait(260);
        compare(c.selectedModel, 4);
        compare(Math.round(view.contentY), c.contentYOfCentered(4));
        compare(spy.signalArguments[0][0].index, 4);
        c.destroy();
    }

    function test_allDisabledYieldsNoTarget() {
        const c = makeCol("list: [{value: 'a', disabled: true},{value: 'b', disabled: true}]");
        wait(60);
        compare(c.nearestEnabledIndex(0), -1);
        const spy = spyFor(c, "select");
        c.settleAfterScroll();
        wait(60);
        compare(spy.count, 0, "全是禁用项时官方 nearestNode 为 null，什么都不做");
        compare(c.selectedModel, 0, "落位仍是首帧那个，不被脏数据改掉");
        c.destroy();
    }

    function test_emptyListIsHarmless() {
        const c = makeCol("");
        wait(60);
        compare(scroller(c).count, 0);
        compare(c.indexAtCenter(), -1);
        compare(c.nearestEnabledIndex(0), -1);
        compare(c.clampIndex(3), 0);
        const spy = spyFor(c, "select");
        c.settleAfterScroll();
        c.selectNode(0);
        c.pickRow(0);
        wait(60);
        compare(spy.count, 0);
        c.destroy();
    }

    function test_indexAtCenterRoundsToTheNearerRow() {
        const c = makeCol("list: [{value: 0},{value: 1},{value: 2},{value: 3}]");
        wait(60);
        c.scrollToSelector(2, false);
        wait(40);
        scroller(c).contentY = c.contentYOfCentered(2) + 26;
        wait(40);
        compare(c.indexAtCenter(), 3, "偏 26 已经过半行，该算到下一行（官方取 rect.top 距选择带最近的）");
        scroller(c).contentY = c.contentYOfCentered(2) + 10;
        wait(40);
        compare(c.indexAtCenter(), 2);
        c.destroy();
    }

    function test_nearestEnabledAlsoSearchesDownwards() {
        const c = makeCol("list: [{value: 0, disabled: true},{value: 1, disabled: true},"
            + "{value: 2, disabled: true},{value: 3},{value: 4}]");
        wait(60);
        compare(c.nearestEnabledIndex(2), 3, "上面全是禁用时得往下找");
        compare(c.nearestEnabledIndex(4), 4);
        c.destroy();
    }

    function test_listAssignedAfterCreationRecenters() {
        const c = makeCol("selectedIndex: 2");
        wait(60);
        compare(scroller(c).count, 0);
        c.list = testCase.makeRangeList(5);
        wait(80);
        compare(scroller(c).count, 5);
        compare(Math.round(scroller(c).contentY), 2 * 36 - 132, "换 list 后按 selectedIndex 重新落位");
        compare(c.selectedModel, 2);
        c.destroy();
    }

    function test_normalModeScrollEmitsNothing() {
        const c = makeCol("mode: 'normal'; list: [{value: 0},{value: 1},{value: 2},{value: 3},"
            + "{value: 4},{value: 5},{value: 6},{value: 7},{value: 8},{value: 9}]");
        wait(60);
        const spy = spyFor(c, "select");
        const view = scroller(c);
        mousePress(view, 80, 200);
        mouseMove(view, 80, 120, -1, Qt.LeftButton);
        mouseMove(view, 80, 60, -1, Qt.LeftButton);
        mouseRelease(view, 80, 60);
        wait(420);
        verify(view.contentY !== 0, "normal 该被拖着走");
        compare(spy.count, 0, "normal 不因滚动选中，官方只有 li onClick 会通知");
        c.destroy();
    }

    function test_scrollerIsClippedAndStopsAtBounds() {
        const c = makeCol("list: [{value: 'a'}]");
        compare(scroller(c).clip, true, "滚出可视区的行不能盖到外壳其它段上（像素档见 cocoa 探针）");
        compare(scroller(c).boundsBehavior, Flickable.StopAtBounds);
        c.destroy();
    }

    function test_ariaLabelGoesOnTheListbox() {
        const c = makeCol("ariaLabel: '小时'; list: [{value: 'a'}]");
        compare(scroller(c).Accessible.name, "小时", "官方 aria-label 挂在 ul（role=listbox）上");
        compare(scroller(c).Accessible.role, Accessible.List);
        c.destroy();
    }

    // ---------------- 列：cycled ----------------

    function test_cycledIsWheelOnly() {
        const c = makeCol("mode: 'normal'; cycled: true; selectedIndex: 1;"
            + " list: [{value: 0},{value: 1},{value: 2}]");
        wait(60);
        compare(c.copies, 1, "官方 cycled 只在 mode==='wheel' 时生效");
        compare(scroller(c).count, 3);
        compare(c.modelIndexOf(1), 1);
        c.destroy();
    }

    function test_cycledMiddleCopyHasRoomOnBothSides() {
        const c = makeCol("cycled: true; list: [{value: 'x'},{value: 'y'}]");
        wait(80);
        const view = scroller(c);
        const maxY = Math.round(view.originY + view.contentHeight - view.height);
        const low = c.middleCopy * 2;
        // 中间那一份必须真的滚得到，而且两边各还能再走半屏，否则「无限」会顶到边界
        verify(c.contentYOfCentered(low) >= view.originY, "中段起点在滚动范围内");
        verify(c.contentYOfCentered(low + 1) <= maxY, "中段终点在滚动范围内");
        verify(c.contentYOfCentered(low) - view.originY >= c.height / 2, "上方留够半屏余量");
        verify(maxY - c.contentYOfCentered(low + 1) >= c.height / 2, "下方留够半屏余量");
        c.destroy();
    }

    function test_cycledRepeatsModelAndParksInTheMiddleCopy() {
        const c = makeCol("cycled: true; selectedIndex: 1; list: [{value: 'x'},{value: 'y'}]");
        wait(80);
        verify(c.copies >= 3, "两三项的列铺三份还不满一屏，份数要按视口算");
        compare(scroller(c).count, 2 * c.copies);
        compare(c.middleCopy, Math.floor(c.copies / 2));
        compare(c.modelIndexOf(1), c.middleCopy * 2 + 1);
        compare(c.realIndexOf(c.modelIndexOf(1)), 1);
        compare(c.selectedModel, c.middleCopy * 2 + 1);
        c.destroy();
    }

    function test_cycledWrapMapsBackIntoMiddleCopy() {        const c = makeCol("cycled: true; list: [{value: 0},{value: 1},{value: 2}]");
        wait(80);
        const low = c.middleCopy * 3;
        compare(c.wrapToMiddleCopy(low), low);
        compare(c.wrapToMiddleCopy(low + 2), low + 2);
        compare(c.realIndexOf(c.wrapToMiddleCopy(low - 1)), c.realIndexOf(low - 1));
        compare(c.wrapToMiddleCopy(low - 1), low + 2);
        compare(c.wrapToMiddleCopy(low + 3), low);
        compare(c.wrapToMiddleCopy(low + 7), low + 1);
        c.destroy();
    }

    function test_cycledSettleKeepsMiddleCopy() {
        const c = makeCol("cycled: true; list: [{value: 0},{value: 1},{value: 2}]");
        wait(80);
        const view = scroller(c);
        // 滚到最前面那一份的第 1 项
        view.contentY = c.contentYOfCentered(1);
        wait(60);
        compare(c.indexAtCenter(), 1);
        c.settleAfterScroll();
        wait(260);
        verify(c.selectedModel >= c.middleCopy * 3
            && c.selectedModel < (c.middleCopy + 1) * 3, "落位后被静默挪回中间那一份");
        compare(c.realIndexOf(c.selectedModel), 1);
        compare(Math.round(view.contentY), c.contentYOfCentered(c.selectedModel));
        c.destroy();
    }

    function test_cycledSilentJumpHappensBeforeTheGlide() {
        const c = makeCol("cycled: true; motion: true; list: [{value: 0},{value: 1},{value: 2}]");
        wait(80);
        const view = scroller(c);
        // 停在最前面那一份的第 1 项，然后落位：wrapToMiddleCopy 先把 contentY 静默跳到
        // 中间那一份（内容逐字相同，看不出来），动画就没有「跨两份飞过去」的距离可走
        view.contentY = c.contentYOfCentered(1);
        wait(60);
        const target = c.wrapToMiddleCopy(c.middleCopy * 3 + 1);
        c.settleAfterScroll();
        wait(50);
        compare(Math.round(view.contentY), c.contentYOfCentered(target),
            "静默跳完就在中段那一份，120ms 的动画不该还带着跨份的行程");
        wait(200);
        compare(c.selectedModel, target);
        compare(Math.round(view.contentY), c.contentYOfCentered(target));
        c.destroy();
    }

    function test_cycledTextUsesRealIndex() {
        const c = makeCol("cycled: true; selectedIndex: 1; textTransform: testCase.pad;"
            + " list: [{value: 10},{value: 20}]");
        wait(80);
        compare(rowText(c, c.modelIndexOf(1)).text, "20点");
        compare(rowText(c, c.modelIndexOf(1) + 2).text, "20点", "同一份里的同名项也按真下标算");
        compare(rowText(c, c.modelIndexOf(0)).text, "10");
        c.destroy();
    }

    // ---------------- 索引换算 ----------------

    function test_clampIndexForNonCycled() {
        const c = makeCol("list: [{value: 0},{value: 1},{value: 2}]");
        compare(c.clampIndex(-3), 0);
        compare(c.clampIndex(1), 1);
        compare(c.clampIndex(9), 2);
        c.destroy();
    }

    function test_clampIndexWrapsOnlyForCycledWheel() {
        const c = makeCol("cycled: true; list: [{value: 0},{value: 1},{value: 2}]");
        compare(c.clampIndex(-1), 2);
        compare(c.clampIndex(3), 0);
        compare(c.clampIndex(7), 1);
        c.mode = "normal";
        compare(c.clampIndex(7), 2, "normal 不循环，越界就夹住");
        compare(c.clampIndex(-1), 0);
        c.destroy();
    }

    function test_contentYOfCenteredRoundTrip() {
        const c = makeCol("list: [{value: 0},{value: 1},{value: 2},{value: 3}]");
        wait(60);
        for (let i = 0; i < 4; ++i) {
            c.scrollToSelector(i, false);
            wait(40);
            compare(Math.round(scroller(c).contentY), c.contentYOfCentered(i));
            compare(c.indexAtCenter(), i);
        }
        c.destroy();
    }

    function test_centeredItemSitsInsideSelectorBand() {
        const c = makeCol("selectedIndex: 2; list: [{value: 0},{value: 1},{value: 2},{value: 3}]");
        wait(80);
        const row = scroller(c).itemAtIndex(2);
        const band = part(c, "scrollItemSelector");
        const rowTop = row.mapToItem(c, 0, 0).y;
        compare(Math.round(rowTop), Math.round(band.y + 1), "行上沿贴选择带上描边");
        compare(Math.round(rowTop + row.height), Math.round(band.y + band.height - 1));
        c.destroy();
    }

    // ---------------- 外壳 + 列：合起来的行为 ----------------

    function test_columnHeightFollowsBodyHeight() {
        const s = make("ScrollList { width: 300; bodyHeight: 200; ScrollItem { objectName: 'inShell';"
            + " selectedIndex: 1; list: [{value: 0},{value: 1},{value: 2}] } }");
        wait(80);
        const col = part(s, "inShell");
        compare(col.height, 200);
        compare(col.padHeight, (200 - 36) / 2);
        compare(Math.round(scroller(col).contentY), 36 - 82, "留白跟着视口高走，第一项也能居中");
        compare(Math.round(scroller(col).itemAtIndex(1).mapToItem(col, 0, 0).y),
            Math.round(part(col, "scrollItemSelector").y + 1));
        s.destroy();
    }

    function test_officialDemoThreeWheels() {
        testCase.hourList = testCase.makeRangeList(12, 1);
        testCase.minuteList = testCase.makeOddDisabledList(20);
        const s = make("ScrollList { width: 600; header: '无限滚动列表'; footer: testCase.footerNode;"
            + " ScrollItem { objectName: 'ap'; cycled: false; type: 1; selectedIndex: 1; list: testCase.apList }"
            + " ScrollItem { objectName: 'hh'; cycled: true; type: 2; selectedIndex: 3; list: testCase.hourList }"
            + " ScrollItem { objectName: 'mm'; cycled: true; type: 3; selectedIndex: 4; list: testCase.minuteList } }");
        wait(140);
        compare(s.columnCount, 3);
        compare(s.headerHeight, 53);
        compare(s.footerHeight, 45);
        const ap = part(s, "ap");
        const hh = part(s, "hh");
        const mm = part(s, "mm");
        compare(ap.copies, 1, "cycled=false 的两项列不铺份");
        verify(hh.copies >= 3);
        compare(ap.selectedModel, 1);
        compare(hh.selectedModel, hh.modelIndexOf(3));
        compare(mm.selectedModel, mm.modelIndexOf(4));
        const spy = spyFor(mm, "select");
        mouseClick(scroller(mm).itemAtIndex(mm.modelIndexOf(6)), 60, 18);
        wait(260);
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0].type, 3, "type 要原样带回，官方靠它分发三列");
        compare(spy.signalArguments[0][0].index, 6);
        compare(spy.signalArguments[0][0].value, 6);
        s.destroy();
        testCase.hourList = [];
        testCase.minuteList = [];
    }

    function test_shellBackgroundHidesColumnBackground() {
        // 列的 style.backgroundColor 画在列自己那层，滚动容器在其上
        const c = makeCol("style: ({backgroundColor: '#123456'}); list: [{value: 'a'}]");
        wait(60);
        const bg = part(c, "scrollItemBackground");
        compare(bg.visible, true);
        compare(bg.color, "#123456");
        compare(bg.height, c.height);
        const plain = makeCol("list: [{value: 'a'}]");
        compare(part(plain, "scrollItemBackground").visible, false);
        c.destroy();
        plain.destroy();
    }
}
