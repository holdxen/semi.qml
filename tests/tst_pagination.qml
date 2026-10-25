import QtQuick
import QtTest
import Semi

// Pagination / PaginationRestList 翻页器。规格照
// packages/semi-ui/pagination/index.tsx + packages/semi-foundation/pagination/
// {foundation.ts,constants.ts,pagination.scss,variables.scss,animation.scss}，
// 数值对着编译产物 semi.css 17230-17406 那一段。
//
// 端口口径（完整清单在 src/Pagination.qml / src/PaginationRestList.qml 头注释）：
//   · 22 条官方 prop 全收；`currentPage` 给了就是受控档（只发信号不改状态）。
//   · 截断是 foundation._updatePageList 的四支 switch，节点总数恒为 7（省略号算一个）；
//     currentPage 越过总页数时走 default 分支 ⇒ 一张**空**页码表。
//   · 官方那几条重置行为照抄：非受控档改 total / pageSize 这两个 prop 就把当前页打回 1；
//     小档的全页码表在没传 pageSize 时会因此被清空。
//   · 三条回调是三个信号：pageChange / pageSizeChange / change，发出顺序也照官方
//     （goPage 先 pageChange 后 change；changePageSize 先 pageSizeChange）。
//   · 皮肤只有 32 高这一档：官方 size 只有 small 与 default，small 变的不是高度而是
//     「页码那一格换成 min-width 44、margin 0 的 c/t 格」。
//
// 断言一律走端口自己算出来的几何，不写死字体度量；颜色断言用浅色档下互不相同的那几枚令牌。
TestCase {
    id: testCase

    name: "Pagination"
    when: windowShown
    width: 900
    height: 700

    readonly property var win: Window.window

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
        away();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "pagination");
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 0.01,
            (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    function sameArray(actual, expected, message) {
        compare(JSON.stringify(actual), JSON.stringify(expected), message || "");
    }

    // 页码格按布局序（x）取，省略号也是其中一格
    function cells(p) {
        const out = [];
        const kids = p.children;
        for (let i = 0; i < kids.length; ++i)
            if (kids[i].objectName === "paginationCell")
                out.push(kids[i]);
        out.sort(function (a, b) { return a.x - b.x; });
        return out;
    }

    function boxOf(cell) {
        return testCase.findChild(cell, "paginationCellBox");
    }

    // 位置器要下一帧才把 delegate 排好（offscreen 尤其明显）：没排好的时候所有格子都叠在
    // x=0，一次合成点击会同时打到好几格 ⇒ 要点/要量之前先轮询「真的排开了」
    function settled(p) {
        tryVerify(function () {
            const list = testCase.cells(p);
            if (list.length === 0)
                return p.width > 0;
            for (let i = 1; i < list.length; ++i)
                if (list[i].x <= list[i - 1].x)
                    return false;
            return true;
        }, 1500, "位置器把格子排开");
    }

    function labelOf(cell) {
        return testCase.findChild(cell, "paginationCellText");
    }

    // Popover（C.Popup）不是 Item，进不去 children，只在宿主项的 data 里
    function popIn(host, name) {
        for (let i = 0; i < host.data.length; ++i)
            if (host.data[i].objectName === name)
                return host.data[i];
        return null;
    }

    function restListOf(pop) {
        return testCase.findChild(pop.contentItem, "paginationRestList");
    }

    // ListView 的 contentItem 里除 delegate 之外还有别的挂项，按 objectName 筛
    function restRows(pop) {
        const out = [];
        const kids = restListOf(pop).contentItem.children;
        for (let i = 0; i < kids.length; ++i)
            if (kids[i].objectName === "paginationRestItem")
                out.push(kids[i]);
        return out;
    }

    function collectNamed(item, name, out, depth) {
        if (item.objectName === name)
            out.push(item);
        if (depth > 6 || !item.children)
            return out;
        for (let i = 0; i < item.children.length; ++i)
            collectNamed(item.children[i], name, out, depth + 1);
        return out;
    }

    function hoverOver(item, x, y) {
        const p = item.mapToItem(testCase.win.contentItem, x, y);
        mouseMove(testCase.win.contentItem, p.x, p.y);
    }

    function clickOn(item, x, y) {
        const p = item.mapToItem(testCase.win.contentItem, x, y);
        mouseClick(testCase.win.contentItem, p.x, p.y, Qt.LeftButton);
    }

    function clickInCard(pop, dx, dy) {
        const p = pop.parent.mapToItem(testCase.win.contentItem, pop.x + dx, pop.y + dy);
        mouseClick(testCase.win.contentItem, p.x, p.y, Qt.LeftButton);
    }

    function hoverInCard(pop, dx, dy) {
        const p = pop.parent.mapToItem(testCase.win.contentItem, pop.x + dx, pop.y + dy);
        mouseMove(testCase.win.contentItem, p.x, p.y);
    }

    // 指针挪到窗口右下角：所有格子和卡片都碰不到
    function away() {
        mouseMove(testCase.win.contentItem, 880, 690);
    }

    property var signalLog: []

    function spyOn(p) {
        testCase.signalLog = [];
        p.pageChange.connect(function (page) { testCase.signalLog.push("pageChange:" + page); });
        p.pageSizeChange.connect(function (size) { testCase.signalLog.push("pageSizeChange:" + size); });
        p.change.connect(function (page, size) { testCase.signalLog.push("change:" + page + "," + size); });
    }

    // ---------------- 属性面与缺省 ----------------

    function test_defaultPropSurface() {
        const p = make("Pagination { }");
        compare(p.total, 1, "total 缺省 1（defaultProps:109）");
        compare(p.showTotal, false, "showTotal 缺省 false");
        compare(p.pageSize === undefined, true, "pageSize 缺省是 null/未给");
        compare(p._pageSize, 10, "没给 pageSize 时落回 pageSizeOpts[0]");
        sameArray(p.pageSizeOpts, [10, 20, 40, 100], "PAGE_SIZE_OPTION");
        compare(p.size, Enums.Default, "size 缺省 default");
        compare(p.isSmall, false);
        compare(p.currentPage === undefined, true, "currentPage 不给就是非受控");
        compare(p.isControlled, false);
        compare(p.defaultCurrentPage, 1);
        compare(p._current, 1);
        compare(p.showSizeChanger, false);
        compare(p.showQuickJumper, false);
        compare(p.popoverZIndex, 1030, "popoverNumbers.DEFAULT_Z_INDEX");
        compare(p.popoverPosition === undefined, true);
        compare(p.hideOnSinglePage, false);
        compare(p.hoverShowPageSelect, false, "defaultProps 里没这条，等价 false");
        compare(p.disabled, false);
        compare(p.preventPageChangeOnPageSizeChange, false);
        compare(p.visible, true);
        // 四段可选内容默认都不占位（官方是「不渲染」，端口用 visible=false 表达同一件事）
        compare(testCase.findChild(p, "paginationTotalSlot").visible, false, "showTotal 没开就不画");
        compare(testCase.findChild(p, "paginationQuickJump").visible, false, "showQuickJumper 没开就不画");
        compare(testCase.findChild(p, "paginationSizeSwitch").visible, false, "showSizeChanger 没开就不画");
        compare(testCase.findChild(p, "paginationSmallSlot").visible, false, "默认档不画 c/t 那一格");
        compare(testCase.findChild(p, "paginationPrevIcon").name, "chevron_left");
        compare(testCase.findChild(p, "paginationNextIcon").name, "chevron_right");
        p.destroy();
    }

    function test_pageSizeResolutionChain() {
        // 官方 constructor:132 的 `props.pageSize || props.pageSizeOpts[0] || 10`
        const a = make("Pagination { pageSize: 25; total: 200 }");
        compare(a._pageSize, 25);
        compare(a.totalPageNum, 8, "200/25 向上取整");
        a.destroy();

        const b = make("Pagination { pageSize: 0; total: 200 }");
        compare(b._pageSize, 10, "0 是假值 ⇒ 落回 pageSizeOpts[0]");
        b.destroy();

        const c = make("Pagination { pageSizeOpts: [8, 16]; total: 200 }");
        compare(c._pageSize, 8, "opts[0] 顶上前两档");
        c.destroy();

        const d = make("Pagination { pageSizeOpts: []; total: 200 }");
        compare(d._pageSize, 10, "opts 空 ⇒ DEFAULT_PAGE_SIZE");
        d.destroy();
    }

    function test_totalPageNumberCeils() {
        const p = make("Pagination { total: 205; pageSize: 10 }");
        compare(p.totalPageNum, 21, "Math.ceil 向上取整");
        p.destroy();

        const q = make("Pagination { total: 0; pageSize: 10 }");
        compare(q.totalPageNum, 0, "官方不夹最小 1 页");
        sameArray(q.pageList, [], "0 页 ⇒ 一张空表");
        q.destroy();
    }

    function test_currentPageSeeds() {
        const a = make("Pagination { total: 200; defaultCurrentPage: 5 }");
        compare(a._current, 5, "defaultCurrentPage 是初始页");
        compare(a.isControlled, false);
        a.destroy();

        const b = make("Pagination { total: 200; currentPage: 7 }");
        compare(b._current, 7);
        compare(b.isControlled, true, "给了 currentPage 就是受控档");
        b.destroy();

        const c = make("Pagination { total: 200; currentPage: 7; defaultCurrentPage: 3 }");
        compare(c._current, 7, "currentPage 优先于 defaultCurrentPage");
        c.destroy();
    }

    // ---------------- 截断算法：四支 ----------------

    function renderedCells(p) {
        return testCase.cells(p).length;
    }

    function test_truncAllPagesWhenSevenOrLess() {
        const p = make("Pagination { total: 70; pageSize: 10 }");
        compare(p.totalPageNum, 7);
        sameArray(p.pageList, [1, 2, 3, 4, 5, 6, 7], "t<=7 不截断");
        sameArray(p.restLeftPageList, []);
        sameArray(p.restRightPageList, []);
        p.destroy();
    }

    function test_truncBranchOneBeforeFourthPage() {
        // t=20、c=1..3 ⇒ [1,2,3,4,'...',19,20]，右侧剩余 5..18
        for (let c = 1; c <= 3; ++c) {
            const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: " + c + " }");
            sameArray(p.pageList, [1, 2, 3, 4, "...", 19, 20], "c=" + c + " 那一支");
            sameArray(p.restRightPageList, [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]);
            sameArray(p.restLeftPageList, []);
            compare(p.pageList.length, 7, "截断符 + 数字恒 7 个节点");
            p.destroy();
        }
    }

    function test_truncBranchTwoOnFourthPage() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 4 }");
        sameArray(p.pageList, [1, 2, 3, 4, 5, "...", 20]);
        sameArray(p.restRightPageList, [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]);
        sameArray(p.restLeftPageList, []);
        p.destroy();
    }

    function test_truncBranchThreeMiddle() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 10 }");
        sameArray(p.pageList, [1, "...", 9, 10, 11, "...", 20]);
        sameArray(p.restLeftPageList, [2, 3, 4, 5, 6, 7, 8], "2..c-2");
        sameArray(p.restRightPageList, [12, 13, 14, 15, 16, 17, 18, 19], "c+2..t-1");
        p.destroy();

        // 门槛是 `4 < c && c < t-3`：t=20 时 c=17 已经不算中间支
        const q = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 16 }");
        sameArray(q.pageList, [1, "...", 15, 16, 17, "...", 20]);
        compare(q.restRightPageList.length, 2, "18,19");
        q.destroy();
    }

    function test_truncBranchFourTail() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 18 }");
        sameArray(p.pageList, [1, "...", 16, 17, 18, 19, 20], "尾巴那五页");
        sameArray(p.restLeftPageList, [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], "2..t-5");
        sameArray(p.restRightPageList, []);
        p.destroy();

        const q = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 17 }");
        sameArray(q.pageList, [1, "...", 16, 17, 18, 19, 20], "c=t-3 就进尾巴支");
        q.destroy();

        const r = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 20 }");
        sameArray(r.pageList, [1, "...", 16, 17, 18, 19, 20], "最后一页也在尾巴支");
        sameArray(r.restLeftPageList, [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
        r.destroy();
    }

    function test_truncEightPagesBoundaries() {
        // t=8 是最小的「要截断」规模，逐支都走一遍边界
        const a = make("Pagination { total: 80; pageSize: 10 }");
        sameArray(a.pageList, [1, 2, 3, 4, "...", 7, 8]);
        sameArray(a.restRightPageList, [5, 6]);
        a.destroy();

        const b = make("Pagination { total: 80; pageSize: 10; defaultCurrentPage: 4 }");
        sameArray(b.pageList, [1, 2, 3, 4, 5, "...", 8]);
        sameArray(b.restRightPageList, [6, 7]);
        b.destroy();

        const c = make("Pagination { total: 80; pageSize: 10; defaultCurrentPage: 5 }");
        sameArray(c.pageList, [1, "...", 4, 5, 6, 7, 8], "4<5 但 5<8-3 不成立 ⇒ 走尾巴支");
        sameArray(c.restLeftPageList, [2, 3]);
        sameArray(c.restRightPageList, []);
        c.destroy();
    }

    function test_truncDefaultBranchWhenCurrentBeyondPages() {
        // 官方 default 分支什么都不 set ⇒ 空表
        const p = make("Pagination { total: 200; pageSize: 10; currentPage: 30 }");
        compare(p._current, 30);
        sameArray(p.pageList, [], "currentPage > 总页数 ⇒ 没有一支匹配");
        sameArray(p.restLeftPageList, []);
        sameArray(p.restRightPageList, []);
        compare(renderedCells(p), 0, "一张空表 ⇒ 页码格里一格都不该有");
        compare(p.prevDisabled, false, "30 既不是 1 也不是 t ⇒ 两边都不禁用");
        compare(p.nextDisabled, false);
        p.destroy();
    }

    // ---------------- prev / next 禁用态 ----------------

    function test_prevNextDisabledStates() {
        const first = make("Pagination { total: 200; pageSize: 10 }");
        compare(first.prevDisabled, true, "第 1 页 ⇒ prev 禁用");
        compare(first.nextDisabled, false);
        first.destroy();

        const mid = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 9 }");
        compare(mid.prevDisabled, false);
        compare(mid.nextDisabled, false);
        mid.destroy();

        const last = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 20 }");
        compare(last.prevDisabled, false);
        compare(last.nextDisabled, true, "最后一页 ⇒ next 禁用");
        last.destroy();

        const only = make("Pagination { total: 5; pageSize: 10 }");
        compare(only.totalPageNum, 1);
        compare(only.prevDisabled, true);
        compare(only.nextDisabled, true, "currentPage===1 那一支里 nextIsDisabled = t<2");
        only.destroy();

        const zero = make("Pagination { total: 0; pageSize: 10 }");
        compare(zero.totalPageNum, 0);
        compare(zero.prevDisabled, true);
        compare(zero.nextDisabled, true, "0 页也走 c===1 那一支（不是 c===t 那一支）");
        zero.destroy();

        // 中间页即便只剩一页可翻也不禁用：官方只在 c===1 / c===t 两处赋值
        const two = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 19 }");
        compare(two.prevDisabled, false);
        compare(two.nextDisabled, false);
        two.destroy();
    }

    function test_blockedMergesDisabledProp() {
        const p = make("Pagination { total: 200; pageSize: 10; disabled: true }");
        compare(p.prevDisabled, true);
        compare(p.nextDisabled, false, "算法本身没被 disabled 改");
        compare(p.prevBlocked, true);
        compare(p.nextBlocked, true, "isDisabled = xxxDisabled || disabled");
        p.destroy();

        const q = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 9; disabled: true }");
        compare(q.prevBlocked, true);
        compare(q.nextBlocked, true);
        q.destroy();
    }

    // ---------------- goPage 与信号 ----------------

    function test_goPageUncontrolled() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        testCase.spyOn(p);
        p.goPage(5);
        compare(p._current, 5, "非受控档自己写状态");
        sameArray(testCase.signalLog, ["pageChange:5", "change:5,10"],
            "先 pageChange 后 change，pageSize 是当前 state 的那只");
        p.destroy();
    }

    function test_goPageControlled() {
        const p = make("Pagination { total: 200; pageSize: 10; currentPage: 1 }");
        testCase.spyOn(p);
        p.goPage(5);
        compare(p._current, 1, "受控档不写状态，等使用方回灌");
        sameArray(testCase.signalLog, ["pageChange:5", "change:5,10"]);
        p.currentPage = 5;
        compare(p._current, 5, "回灌后靠 componentDidUpdate 那条路同步");
        compare(testCase.signalLog.length, 2, "prop 变化不再发信号");
        p.destroy();
    }

    function test_goPageIgnoresSamePageAndEllipsis() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 3 }");
        testCase.spyOn(p);
        p.goPage(3);
        compare(testCase.signalLog.length, 0, "点自己直接 return");
        p.goPage("...");
        compare(testCase.signalLog.length, 0, "省略号不是页码");
        compare(p._current, 3);
        p.destroy();
    }

    function test_goPageDoesNotClamp() {
        // 官方没有钳位：越界就是越界（这也是「空页码表」那一支的来源）
        const p = make("Pagination { total: 200; pageSize: 10 }");
        testCase.spyOn(p);
        p.goPage(99);
        compare(p._current, 99);
        sameArray(testCase.signalLog, ["pageChange:99", "change:99,10"]);
        sameArray(p.pageList, []);
        p.destroy();
    }

    function test_goPrevGoNextBounds() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        testCase.spyOn(p);
        p.goPrev();
        compare(testCase.signalLog.length, 0, "第 1 页再往前没了");
        p.goNext();
        sameArray(testCase.signalLog, ["pageChange:2", "change:2,10"]);
        p.destroy();

        const q = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 20 }");
        testCase.spyOn(q);
        q.goNext();
        compare(testCase.signalLog.length, 0, "最后一页判据是 c <= t-1");
        q.goPrev();
        sameArray(testCase.signalLog, ["pageChange:19", "change:19,10"]);
        q.destroy();
    }

    function test_clickCellThroughRealHitTest() {
        const p = make("Pagination { total: 70; pageSize: 10 }");
        settled(p);
        testCase.spyOn(p);
        const list = testCase.cells(p);
        compare(list.length, 7, "t=7 ⇒ 七格全出");
        clickOn(list[3], 16, 16);
        compare(p._current, 4, "点到第 4 格就翻到第 4 页");
        sameArray(testCase.signalLog, ["pageChange:4", "change:4,10"]);
        p.destroy();
    }

    // destroy() 是延后删除：同一只函数里换新建的另一只实例会被旧实例的格子挡住点击，
    // 所以省略号那一档单独开一只用例。
    function test_clickEllipsisCellDoesNothing() {
        const q = make("Pagination { total: 200; pageSize: 10 }");
        settled(q);
        testCase.spyOn(q);
        const dots = testCase.cells(q)[4];
        compare(testCase.labelOf(dots).text, "...");
        compare(popIn(dots, "paginationRestPop").visible, false);
        clickOn(dots, 16, 16);
        compare(q._current, 1, "省略号那格的点击被 goPage 那句 early return 吞掉");
        compare(testCase.signalLog.length, 0);
        q.destroy();
    }

    function test_clickDisabledCellDoesNothing() {
        const p = make("Pagination { total: 200; pageSize: 10; disabled: true }");
        settled(p);
        testCase.spyOn(p);
        clickOn(testCase.cells(p)[2], 16, 16);
        compare(p._current, 1);
        compare(testCase.signalLog.length, 0, "tsx 里 `!disabled && goPage(...)`");

        const prev = testCase.findChild(p, "paginationPrev");
        clickOn(prev, 20, 16);
        const next = testCase.findChild(p, "paginationNext");
        clickOn(next, 20, 16);
        compare(testCase.signalLog.length, 0, "禁用档前后翻页也不发信号");
        p.destroy();
    }

    function test_clickPrevNextArrows() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 5 }");
        settled(p);
        testCase.spyOn(p);
        clickOn(testCase.findChild(p, "paginationPrev"), 20, 16);
        sameArray(testCase.signalLog, ["pageChange:4", "change:4,10"]);
        away();
        testCase.signalLog = [];
        clickOn(testCase.findChild(p, "paginationNext"), 20, 16);
        sameArray(testCase.signalLog, ["pageChange:5", "change:5,10"], "从第 4 页再往前一格");
        p.destroy();
    }

    // ---------------- changePageSize ----------------

    function test_changePageSizeRecomputesWithOldSize() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 3 }");
        testCase.spyOn(p);
        p.changePageSize(20);
        compare(p._pageSize, 20);
        // (3-1)*10+1 = 21 ⇒ ceil(21/20) = 2
        compare(p._current, 2, "换算用的是**旧** pageSize");
        sameArray(testCase.signalLog, ["pageSizeChange:20", "pageChange:2", "change:2,20"],
            "官方第一句就是 notifyPageSizeChange");
        p.destroy();
    }

    function test_changePageSizeSamePageSkipsPageChange() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        testCase.spyOn(p);
        p.changePageSize(100);
        compare(p._current, 1, "第 1 页开头是第 1 条 ⇒ 还是第 1 页");
        sameArray(testCase.signalLog, ["pageSizeChange:100", "change:1,100"],
            "页码没变就不发 pageChange，但 change 照发");
        p.destroy();
    }

    function test_changePageSizePrevented() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 3;"
            + " preventPageChangeOnPageSizeChange: true }");
        testCase.spyOn(p);
        p.changePageSize(20);
        compare(p._current, 3, "开关打开就不动页码");
        sameArray(testCase.signalLog, ["pageSizeChange:20", "change:3,20"]);
        p.destroy();
    }

    function test_pageSizeInOptsInsertion() {
        const a = make("Pagination { total: 200; pageSize: 10 }");
        sameArray(a.pageSizeInOpts(), [10, 20, 40, 100], "本来就在表里就不插");
        a.destroy();

        const b = make("Pagination { total: 200; pageSize: 10 }");
        b.changePageSize(25);
        sameArray(b.pageSizeInOpts(), [10, 20, 25, 40, 100], "25 插到 40 之前");
        sameArray(b.pageSizeOpts, [10, 20, 40, 100], "插的是拷贝，使用方那张表不动");
        b.destroy();

        // 上游 bug：比所有可选项都大时 findIndex 给 -1 ⇒ splice(-1,0,x) 插到倒数第二个位置
        const c = make("Pagination { total: 200; pageSize: 10 }");
        c.changePageSize(200);
        sameArray(c.pageSizeInOpts(), [10, 20, 40, 200, 100], "200 排在 100 前面");
        c.destroy();

        const d = make("Pagination { total: 200; pageSize: 8; pageSizeOpts: [8, 16] }");
        sameArray(d.pageSizeInOpts(), [8, 16]);
        compare(d.sizeChangerOptions().length, 2);
        d.destroy();
    }

    function test_sizeChangerOptionLabels() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        const opts = p.sizeChangerOptions();
        compare(opts.length, 4);
        compare(opts[0].label, qsTr("每页条数：10"), "locale.pageSize 的 ${pageSize} 档");
        compare(opts[0].value, 10);
        compare(opts[3].label, qsTr("每页条数：100"));
        p.destroy();
    }

    function test_sizeSwitchOnlyInDefaultMode() {
        const p = make("Pagination { total: 200; pageSize: 10; showSizeChanger: true }");
        const sw = testCase.findChild(p, "paginationSizeSwitch");
        compare(sw.visible, true);
        compare(sw.value, 10, "Select 的 value 跟着 state.pageSize");
        compare(sw.options.length, 4);
        p.destroy();

        // 官方 renderSmallPage 压根不调 renderPageSizeSwitch ⇒ 小档给了也白给
        const q = make("Pagination { total: 200; pageSize: 10; showSizeChanger: true; size: Enums.Small }");
        compare(testCase.findChild(q, "paginationSizeSwitch").visible, false,
            "小档不渲染每页容量切换器");
        q.destroy();
    }

    function test_sizeSwitchClickChangesSize() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 3; showSizeChanger: true }");
        settled(p);
        const sw = testCase.findChild(p, "paginationSizeSwitch");
        testCase.spyOn(p);
        const trigger = sw.mapToItem(testCase.win.contentItem, sw.width / 2, 16);
        mouseClick(testCase.win.contentItem, trigger.x, trigger.y, Qt.LeftButton);
        tryVerify(function () { return sw._popup.isOpen === true; }, 1500, "点切换器要开下拉");
        const rows = [];
        collectNamed(sw._popup.contentItem, "selectOptionRow", rows, 0);
        compare(rows.length, 4, "四个可选项");
        const target = rows[1].mapToItem(testCase.win.contentItem, 40, 18);
        mouseClick(testCase.win.contentItem, target.x, target.y, Qt.LeftButton);
        tryVerify(function () { return p._pageSize === 20; }, 1200, "选第二项 = 20 条/页");
        sameArray(testCase.signalLog, ["pageSizeChange:20", "pageChange:2", "change:2,20"],
            "页码按**旧** pageSize 换算：(3-1)*10+1 = 21 ⇒ 第 2 页");
        compare(p._current, 2);
        compare(testCase.findChild(p, "paginationSizeSwitch").value, 20,
            "官方那句 key={pageSize+文案} 的重建效果：选择器显示的仍是 state");
        p.destroy();
    }

    // ---------------- prop 同步（componentDidUpdate） ----------------

    function test_uncontrolledResetsOnTotalChange() {
        // 上游 bug：updatePage(props.currentPage === undefined) 的缺省参数把页码打回 1
        const p = make("Pagination { total: 200; pageSize: 10 }");
        p.goPage(9);
        compare(p._current, 9);
        p.total = 500;
        compare(p._current, 1, "改 total ⇒ 非受控档当前页回到 1");
        compare(p.totalPageNum, 50);
        p.destroy();
    }

    function test_uncontrolledResetsOnPageSizePropChange() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        p.goPage(9);
        p.pageSize = 20;
        compare(p._pageSize, 20, "state.pageSize 跟随 prop");
        compare(p._current, 1, "改 pageSize prop 同样把当前页打回 1");
        compare(p.totalPageNum, 10);
        // props.pageSize 为 undefined 时沿用 state（官方 updatePage 里那句判空）
        p.pageSize = undefined;
        compare(p._pageSize, 20, "prop 收回 undefined ⇒ 沿用 state");
        p.destroy();
    }

    function test_controlledFollowsCurrentPageProp() {
        const p = make("Pagination { total: 200; pageSize: 10; currentPage: 2 }");
        testCase.spyOn(p);
        p.currentPage = 15;
        compare(p._current, 15);
        compare(testCase.signalLog.length, 0, "prop 回灌不发信号");
        sameArray(p.pageList, [1, "...", 14, 15, 16, "...", 20], "页码表随受控值重算");
        p.destroy();
    }

    function test_defaultCurrentPageChangeIsIgnored() {
        const p = make("Pagination { total: 200; defaultCurrentPage: 2 }");
        p.goPage(6);
        p.defaultCurrentPage = 12;
        compare(p._current, 6, "官方只在 constructor 读 defaultCurrentPage");
        p.destroy();
    }

    // ---------------- 小档：c/t 与全页码表 ----------------

    function test_smallModeShape() {
        const p = make("Pagination { total: 200; pageSize: 10; size: Enums.Small }");
        compare(p.isSmall, true);
        compare(p._current, 1);
        compare(p.smallLabel, qsTr("1/20 "), "官方 JSX 末尾那个空格也在");
        compare(testCase.cells(p).length, 0, "小档没有页码格");
        const box = testCase.findChild(p, "paginationSmallBox");
        compare(box.width, 44, "$width-pagination_item_small-minWidth");
        compare(box.height, 32, "小档的高度也是 32，官方只有默认档那一格变宽");
        const slot = testCase.findChild(p, "paginationSmallSlot");
        compare(slot.x, 40, "-item-small 的 margin 是 0：prev 那一格 32+4+4=40 之后紧接着它");
        const next = testCase.findChild(p, "paginationNext");
        compare(next.x, 84, "44 之后就是 next");
        compare(p.hiddenOnSinglePage, false);
        p.destroy();
    }

    function test_smallModeHidesTotalAndSwitch() {
        const p = make("Pagination { total: 200; pageSize: 10; size: Enums.Small;"
            + " showTotal: true; showSizeChanger: true }");
        compare(testCase.findChild(p, "paginationTotalSlot").visible, false, "小档不画总页数");
        compare(testCase.findChild(p, "paginationSizeSwitch").visible, false, "小档不画切换器");
        compare(p.visible, true, "但 hideOnSinglePage 的豁免照样吃 showSizeChanger");
        p.destroy();
    }

    function test_hoverShowPageSelectFillsAllPageNumbers() {
        const p = make("Pagination { total: 200; pageSize: 10; size: Enums.Small;"
            + " hoverShowPageSelect: true }");
        compare(p._allPageNumbers.length, 20, "constructor 里按 state.pageSize 算满");
        sameArray(p._allPageNumbers.slice(0, 3), [1, 2, 3]);
        p.destroy();

        const noSwitch = make("Pagination { total: 200; pageSize: 10; size: Enums.Small }");
        sameArray(noSwitch._allPageNumbers, [], "hoverShowPageSelect 不开就不算这张表");
        noSwitch.destroy();

        // 默认档也不算（updateAllPageNumbers 第一句就 size 门槛）；改 total 也不算
        const normal = make("Pagination { total: 200; pageSize: 10; hoverShowPageSelect: true }");
        sameArray(normal._allPageNumbers, []);
        normal.total = 300;
        sameArray(normal._allPageNumbers, [], "size 不是 small ⇒ 这道门槛先把住");
        normal.destroy();

        const noHover = make("Pagination { total: 200; pageSize: 10; size: Enums.Small }");
        noHover.total = 300;
        sameArray(noHover._allPageNumbers, [], "hoverShowPageSelect 没开 ⇒ 永远不算这张表");
        noHover.destroy();

        const dis = make("Pagination { total: 200; pageSize: 10; size: Enums.Small;"
            + " hoverShowPageSelect: true; disabled: true }");
        sameArray(dis._allPageNumbers, [], "禁用档 constructor 那条 shouldFillAllNumber 不成立");
        dis.total = 300;
        sameArray(dis._allPageNumbers, [], "禁用档 prop 变化也不重算");
        dis.destroy();
    }

    function test_allPageNumbersClearedByPropSync() {
        // 上游 bug：updateAllPageNumbers 收到的是 props.pageSize（没传 ⇒ undefined）
        const p = make("Pagination { total: 200; size: Enums.Small; hoverShowPageSelect: true }");
        compare(p._pageSize, 10, "constructor 用的是解析后的 state.pageSize");
        compare(p._allPageNumbers.length, 20);
        p.total = 300;
        sameArray(p._allPageNumbers, [], "改了 total 之后这张表被 NaN 清空");
        p.destroy();

        // 传了 pageSize prop 就正常重算
        const q = make("Pagination { total: 200; pageSize: 10; size: Enums.Small;"
            + " hoverShowPageSelect: true }");
        compare(q._allPageNumbers.length, 20);
        q.total = 300;
        compare(q._allPageNumbers.length, 30, "props.pageSize 有值时按它重算");
        q.destroy();
    }

    function test_smallCellClickDoesNotJump() {
        const p = make("Pagination { total: 200; pageSize: 10; size: Enums.Small; defaultCurrentPage: 3 }");
        settled(p);
        testCase.spyOn(p);
        const box = testCase.findChild(p, "paginationSmallBox");
        clickOn(box, 22, 16);
        compare(p._current, 3, "官方这一格没有 onClick ⇒ 点它不跳页");
        compare(testCase.signalLog.length, 0);
        p.destroy();
    }

    function test_smallPrevNextStillWork() {
        const p = make("Pagination { total: 200; pageSize: 10; size: Enums.Small; defaultCurrentPage: 3 }");
        settled(p);
        clickOn(testCase.findChild(p, "paginationNext"), 20, 16);
        compare(p._current, 4);
        compare(testCase.findChild(p, "paginationSmallLabel").text, qsTr("4/20 "));
        p.destroy();
    }

    // ---------------- hideOnSinglePage ----------------

    function test_hideOnSinglePage() {
        const one = make("Pagination { total: 5; pageSize: 10; hideOnSinglePage: true }");
        compare(one.totalPageNum, 1);
        compare(one.hiddenOnSinglePage, true);
        compare(one.visible, false, "官方整块 return null");
        one.destroy();

        const two = make("Pagination { total: 15; pageSize: 10; hideOnSinglePage: true }");
        compare(two.hiddenOnSinglePage, false, "判据是 t < 2");
        compare(two.visible, true);
        two.destroy();

        const zero = make("Pagination { total: 0; pageSize: 10; hideOnSinglePage: true }");
        compare(zero.hiddenOnSinglePage, true, "0 页也 < 2 ⇒ 一样藏");
        zero.destroy();

        // showSizeChanger 把这条豁免掉（官方那句 && !showSizeChanger + constructor 的 warning）
        const exempt = make("Pagination { total: 5; pageSize: 10; hideOnSinglePage: true; showSizeChanger: true }");
        compare(exempt.hiddenOnSinglePage, false, "两个开关同时开时 hideOnSinglePage 失效");
        compare(exempt.visible, true);
        exempt.destroy();

        const smallOne = make("Pagination { total: 5; pageSize: 10; size: Enums.Small; hideOnSinglePage: true }");
        compare(smallOne.visible, false, "小档同一判据");
        smallOne.destroy();
    }

    // ---------------- 总页数与快速跳转的显隐、文案 ----------------

    function test_totalTextUsesPageCount() {
        const p = make("Pagination { total: 205; pageSize: 10; showTotal: true }");
        const label = testCase.findChild(p, "paginationTotal");
        compare(label.visible, true);
        compare(label.text, qsTr("总页数：21"), "填的是页数不是条数");
        compare(label.color, Theme.current.colorText2);
        p.destroy();

        const off = make("Pagination { total: 200; showTotal: false }");
        compare(testCase.findChild(off, "paginationTotalSlot").visible, false);
        off.destroy();

        const dis = make("Pagination { total: 200; showTotal: true; disabled: true }");
        compare(testCase.findChild(dis, "paginationTotal").color, Theme.current.colorDisabledText,
            "-disabled .semi-page-total");
        dis.destroy();
    }

    function test_quickJumpLayout() {
        const p = make("Pagination { total: 500; pageSize: 10; showQuickJumper: true }");
        const slot = testCase.findChild(p, "paginationQuickJump");
        compare(slot.visible, true);
        const row = testCase.findChild(p, "paginationQuickRow");
        compare(row.x, 24, "$spacing-pagination_quickjump_marginLeft");
        const input = testCase.findChild(p, "paginationQuickInput");
        compare(input.width, 50, "max-width 50");
        compare(input.x, 4, "左右各 4 的 margin");
        compare(testCase.findChild(p, "paginationJumpToLabel").text, qsTr("跳至"));
        compare(testCase.findChild(p, "paginationPageLabel").text, qsTr("页"));
        compare(p.quickJumpBlocked, false);
        p.destroy();

        const single = make("Pagination { total: 5; pageSize: 10; showQuickJumper: true }");
        compare(single.quickJumpBlocked, true, "totalPageNum === 1 就禁用快速跳转");
        compare(testCase.findChild(single, "paginationJumpToLabel").color,
            Theme.current.colorDisabledText, "-quickjump-disabled 连带两个 span");
        single.destroy();

        const dis = make("Pagination { total: 200; pageSize: 10; showQuickJumper: true; disabled: true }");
        compare(dis.quickJumpBlocked, true, "isDisabled = totalPageNum === 1 || disabled");
        compare(testCase.findChild(dis, "paginationJumpToLabel").color,
            Theme.current.colorDisabledText);
        dis.destroy();
    }

    function test_quickJumpLogic() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 2 }");
        p.handleQuickJumpNumberChange("7");
        compare(p._quickJumpPage, "7");
        p.handleQuickJump("7");
        compare(p._current, 7);
        compare(p._quickJumpPage, "", "跳完清空输入框");

        p.handleQuickJump(999);
        compare(p._current, 20, "大于总页数就夹到总页数");
        testCase.spyOn(p);
        p.handleQuickJump(21);
        compare(p._current, 20, "正好越界一格也夹（判据是 > t，不是 > t+1）");
        compare(testCase.signalLog.length, 0, "夹完就是同一页 ⇒ goPage 那句 same-page return 接住");
        p.handleQuickJump(-3);
        compare(p._current, 1, "<=0 夹到第 1 页");

        testCase.spyOn(p);
        p.handleQuickJump("abc");
        compare(testCase.signalLog.length, 0, "NaN 直接 return");
        p._quickJumpPage = "x";
        p.handleQuickJump("abc");
        compare(p._quickJumpPage, "x", "return 在清空之前 ⇒ 非法输入不会被抹掉");
        p.destroy();
    }

    function test_quickJumpBlurRules() {
        const empty = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 5 }");
        testCase.spyOn(empty);
        empty.handleQuickJumpBlur();
        compare(testCase.signalLog.length, 0, "初值就是空串 ⇒ 不处理");
        empty._quickJumpPage = "";
        empty.handleQuickJumpBlur();
        compare(testCase.signalLog.length, 0, "官方那句 typeof string && value 的双条件");
        compare(empty._current, 5, "空串被当成「有值」跳的话就会掉到第 1 页");
        empty.destroy();

        const str = make("Pagination { total: 200; pageSize: 10 }");
        str._quickJumpPage = "6";
        testCase.spyOn(str);
        str.handleQuickJumpBlur();
        compare(str._current, 6, "失焦即跳");
        str.destroy();

        const num = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 8 }");
        num._quickJumpPage = 0;
        testCase.spyOn(num);
        num.handleQuickJumpBlur();
        compare(num._current, 1, "数字 0 也走（typeof number 就够）⇒ 夹到第 1 页");
        num.destroy();
    }

    function test_quickJumpTypingAndEnter() {
        const p = make("Pagination { total: 200; pageSize: 10; showQuickJumper: true; width: 600 }");
        settled(p);
        const input = testCase.findChild(p, "paginationQuickInput");
        input.field.forceActiveFocus();
        wait(60);
        keyClick(Qt.Key_7);
        tryVerify(function () { return String(p._quickJumpPage) === "7"; }, 1200,
            "打字走 onChange → handleQuickJumpNumberChange");
        compare(p._current, 1, "打字本身不翻页");
        testCase.spyOn(p);
        keyClick(Qt.Key_Return);
        tryVerify(function () { return p._current === 7; }, 1200, "Enter 走官方 onEnterPress 那条路");
        sameArray(testCase.signalLog, ["pageChange:7", "change:7,10"]);
        compare(p._quickJumpPage, "", "跳完把 state 清掉");
        compare(input.field.text, "", "输入框也跟着空");
        p.destroy();
    }

    // ---------------- 省略号浮层（rest list） ----------------

    function test_restPopoverOpensOnHover() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        settled(p);
        const dots = testCase.cells(p)[4];
        compare(testCase.labelOf(dots).text, "...");
        const pop = popIn(dots, "paginationRestPop");
        verify(pop !== null, "省略号格里要有一只 Popover");
        compare(pop.visible, false);
        compare(pop.trigger, "hover", "官方 trigger=\"hover\"");
        compare(pop.zIndex, 1030);
        compare(pop.position, Enums.Bottom, "没传 popoverPosition ⇒ Popover 自己的 bottom");
        hoverOver(dots, 16, 16);
        tryVerify(function () { return pop.visible === true; }, 1500, "hover 50ms 后弹层");
        const list = restListOf(pop);
        compare(list.width, 78, "index.tsx:432 写死的宽");
        compare(list.y, 4, "-rest-list 的上内边距 4（$spacing-pagination_reset_list-paddingTop）");
        compare(list.count, 14, "restRightPageList");
        compare(list.height, 160, "count>=5 ⇒ 5 行高");
        compare(list.contentHeight, 448, "14 行");
        const card = pop.contentItem.children[0];
        near(card.height, 168, "可视 160 + 上下各 4 的内边距");
        away();
        p.destroy();
    }

    function test_restPopoverShortSideHeight() {
        const p = make("Pagination { total: 80; pageSize: 10 }");
        settled(p);
        const pop = popIn(testCase.cells(p)[4], "paginationRestPop");
        hoverOver(testCase.cells(p)[4], 16, 16);
        tryVerify(function () { return pop.visible === true; }, 1500);
        const list = restListOf(pop);
        compare(list.count, 2, "t=8 ⇒ 右侧只剩 5,6");
        compare(list.height, 64, "count<5 ⇒ 32 * count");
        away();
        p.destroy();
    }

    function test_restRowClickJumps() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        settled(p);
        const dots = testCase.cells(p)[4];
        const pop = popIn(dots, "paginationRestPop");
        hoverOver(dots, 16, 16);
        tryVerify(function () { return pop.visible === true; }, 1500);
        testCase.spyOn(p);
        clickInCard(pop, 39, 4 + 16);
        compare(p._current, 5, "点浮层第一行（页码 5）");
        sameArray(testCase.signalLog, ["pageChange:5", "change:5,10"]);
        sameArray(p.pageList, [1, "...", 4, 5, 6, "...", 20], "页码表按中间支重算");
        p.destroy();
    }

    function test_restLeftSideUsedWhenIndexUnderThree() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 10 }");
        settled(p);
        const list = testCase.cells(p);
        compare(list.length, 7, "中间支七个节点：1 ... 9 10 11 ... 20");
        const leftPop = popIn(list[1], "paginationRestPop");
        const rightPop = popIn(list[5], "paginationRestPop");
        verify(leftPop !== null && rightPop !== null, "中间支左右各一只省略号");
        hoverOver(list[1], 16, 16);
        tryVerify(function () { return leftPop.visible === true; }, 1500);
        compare(restListOf(leftPop).count, 7, "i<3 ⇒ restLeftPageList = 2..8");
        away();
        p.destroy();
    }

    function test_restItemColors() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        settled(p);
        const dots = testCase.cells(p)[4];
        const pop = popIn(dots, "paginationRestPop");
        hoverOver(dots, 16, 16);
        tryVerify(function () { return pop.visible === true; }, 1500);
        const rows = restRows(pop);
        compare(restListOf(pop).count, 14, "model 就是 restRightPageList");
        verify(rows.length >= 1, "视口里至少 realization 出一行");
        near(rows[0].height, 32, "-rest-item 高 32");
        near(rows[0].width, 78);
        verify(rows[0].color === Qt.rgba(0, 0, 0, 0), "浮层行常态无底");
        hoverInCard(pop, 39, 4 + 16);
        tryVerify(function () { return restRows(pop)[0].color === Theme.current.colorFill0; }, 1200,
            "悬浮 fill-0");
        const w = pop.parent.mapToItem(testCase.win.contentItem, pop.x + 39, pop.y + 4 + 16);
        mousePress(testCase.win.contentItem, w.x, w.y, Qt.LeftButton);
        verify(restRows(pop)[0].color === Theme.current.colorFill1,
            "按下 fill-1（实得 " + restRows(pop)[0].color + "）");
        mouseRelease(testCase.win.contentItem, w.x, w.y, Qt.LeftButton);
        away();
        p.destroy();
    }

    function test_ellipsisNoPopoverWhenDisabled() {
        const p = make("Pagination { total: 200; pageSize: 10; disabled: true }");
        settled(p);
        const dots = testCase.cells(p)[4];
        const pop = popIn(dots, "paginationRestPop");
        compare(pop.enabled, false, "官方 `page === '...' && !disabled` 才包 Popover");
        hoverOver(dots, 16, 16);
        wait(120);
        compare(pop.visible, false, "禁用档 hover 省略号不弹层");
        p.destroy();
    }

    function test_numberCellHasNoPopover() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        settled(p);
        const first = testCase.cells(p)[0];
        compare(popIn(first, "paginationRestPop").enabled, false, "数字格那只 Popover 关着");
        hoverOver(first, 16, 16);
        wait(120);
        compare(popIn(first, "paginationRestPop").visible, false);
        p.destroy();
    }

    function test_smallPopoverShowsAllPages() {
        const p = make("Pagination { total: 200; pageSize: 10; size: Enums.Small;"
            + " hoverShowPageSelect: true }");
        settled(p);
        const slot = testCase.findChild(p, "paginationSmallSlot");
        const pop = popIn(slot, "paginationSmallPop");
        verify(pop !== null, "小档格子的 data 里要有那只 Popover");
        compare(pop.enabled, true);
        hoverOver(slot, 22, 16);
        tryVerify(function () { return pop.visible === true; }, 1500, "小档 hover 弹全页码表");
        const list = restListOf(pop);
        compare(list.count, 20, "内容是 allPageNumbers");
        compare(list.height, 160);
        away();
        p.destroy();
    }

    function test_smallPopoverDisabled() {
        const p = make("Pagination { total: 200; pageSize: 10; size: Enums.Small;"
            + " hoverShowPageSelect: true; disabled: true }");
        const slot = testCase.findChild(p, "paginationSmallSlot");
        compare(popIn(slot, "paginationSmallPop").enabled, false,
            "官方 `(hoverShowPageSelect && !disabled)` 才包");
        p.destroy();

        const q = make("Pagination { total: 200; pageSize: 10; size: Enums.Small; disabled: true }");
        compare(popIn(testCase.findChild(q, "paginationSmallSlot"), "paginationSmallPop").enabled, false);
        q.destroy();

        const r = make("Pagination { total: 200; pageSize: 10; size: Enums.Small }");
        compare(popIn(testCase.findChild(r, "paginationSmallSlot"), "paginationSmallPop").enabled, false,
            "hoverShowPageSelect 没开 ⇒ 那张全页码表根本不包 Popover");
        r.destroy();
    }

    // ---------------- 皮肤：几何与颜色 ----------------

    function test_itemMetricsAndMargins() {
        const p = make("Pagination { total: 70; pageSize: 10 }");
        settled(p);
        compare(p.itemHeight, 32, "$height-pagination_item");
        compare(p.itemMinWidth, 32);
        compare(p.height, 32, "整行高度就是格子高");
        const list = testCase.cells(p);
        compare(list.length, 7);
        near(list[0].x, 40, "prev 那一格 4+32+4 = 40 宽");
        near(list[1].x - list[0].x, 40, "格子间距 8 = 两条 4 的 margin");
        near(boxOf(list[0]).x, 4, "每格左右各 4");
        near(boxOf(list[0]).width, 32, "min-width 32 且内容更窄");
        near(list[0].width, 40, "slot 宽 = 32 + 4 + 4");
        near(testCase.findChild(p, "paginationNext").x, 320);
        p.destroy();
    }

    function test_rowStartsWithNoOuterInsetOfItsOwn() {
        // 总页数那一格没有 margin：后面的 prev 直接从它的右边缘起算
        const p = make("Pagination { total: 200; pageSize: 10; showTotal: true }");
        settled(p);
        const total = testCase.findChild(p, "paginationTotalSlot");
        near(total.x, 0);
        near(total.width, testCase.findChild(p, "paginationTotal").implicitWidth,
            "span 宽就是文本宽");
        near(testCase.findChild(p, "paginationPrev").x, total.width, "prev 的 4 是它自己的 margin");
        p.destroy();
    }

    function test_selectedCellSkin() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 2 }");
        settled(p);
        away();
        const second = testCase.cells(p)[1];
        compare(labelOf(second).text, "2");
        compare(boxOf(second).color, Theme.current.colorPrimaryLightDefault,
            "$color-pagination_item-bg-selected");
        compare(labelOf(second).color, Theme.current.colorPrimary,
            "$color-pagination_item-text-selected");
        compare(labelOf(second).font.weight, 600, "选中字重 600");
        const other = testCase.cells(p)[0];
        compare(labelOf(other).font.weight, 400);
        compare(labelOf(other).color, Theme.current.colorText0);
        p.destroy();
    }

    function test_hoverAndPressOnPlainCell() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        settled(p);
        away();
        const third = testCase.cells(p)[2];
        verify(boxOf(third).color === Qt.rgba(0, 0, 0, 0), "常态透明底（实得 " + boxOf(third).color + "）");
        hoverOver(third, 16, 16);
        tryVerify(function () { return boxOf(third).color === Theme.current.colorFill0; }, 1200,
            "悬浮 fill-0");
        // 用「按住不放」这一段来读 :active 那一档：release 会把它抹掉，所以自己发 press
        mousePress(boxOf(third), 16, 16, Qt.LeftButton);
        verify(boxOf(third).color === Theme.current.colorFill1,
            "按下 fill-1（实得 " + boxOf(third).color + "）");
        compare(labelOf(third).color, Theme.current.colorText0);
        mouseRelease(boxOf(third), 16, 16, Qt.LeftButton);
        compare(p._current, 3, "松手就翻页");
        compare(boxOf(third).color, Theme.current.colorPrimaryLightDefault,
            "翻页后这一格就是选中态（指针还在上面，-item-active:hover 守住 primary-light-default）");
        away();
        p.destroy();
    }

    function test_pressBeatsSelectedColor() {
        // CSS 层叠：`.semi-page-item:active`(0,2,0) 压过 `-item-active`(0,1,0)
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 2 }");
        settled(p);
        away();
        const second = testCase.cells(p)[1];
        hoverOver(second, 16, 16);
        tryVerify(function () { return boxOf(second).color === Theme.current.colorPrimaryLightDefault; },
            1200, "-item-active:hover 把选中底保住了");
        compare(labelOf(second).color, Theme.current.colorPrimary);
        mousePress(second, 16, 16, Qt.LeftButton);
        verify(boxOf(testCase.cells(p)[1]).color === Theme.current.colorFill1
            && labelOf(testCase.cells(p)[1]).color === Theme.current.colorText0,
            "按下的那一格（就是当前页）回 fill-1 + text-0");
        compare(labelOf(testCase.cells(p)[1]).font.weight, 600, "字重不归 400，只有颜色与底变");
        mouseRelease(testCase.cells(p)[1], 16, 16, Qt.LeftButton);
        compare(p._current, 2, "点自己也走 goPage 那句 same-page return");
        away();
        p.destroy();
    }

    function test_disabledCellSkin() {
        const p = make("Pagination { total: 200; pageSize: 10; disabled: true }");
        settled(p);
        const list = testCase.cells(p);
        compare(labelOf(list[1]).color, Theme.current.colorDisabledText);
        verify(boxOf(list[1]).color === Qt.rgba(0, 0, 0, 0), "禁用格透明底");
        compare(boxOf(list[0]).color, Theme.current.colorDisabledFill,
            "-all-disabled-active 那一支是 disabled-fill");
        compare(labelOf(list[0]).color, Theme.current.colorDisabledText,
            "禁用+选中的字色仍是 disabled-text，只有底换掉");
        hoverOver(list[1], 16, 16);
        wait(120);
        verify(boxOf(list[1]).color === Qt.rgba(0, 0, 0, 0), "禁用档悬浮不变底");
        compare(boxOf(list[0]).color, Theme.current.colorDisabledFill, "选中那格悬浮也守住");
        away();
        p.destroy();
    }

    function test_arrowIconSkin() {
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 5 }");
        settled(p);
        away();
        const prevIcon = testCase.findChild(p, "paginationPrevIcon");
        compare(prevIcon.visible, true);
        compare(prevIcon.size, 20, "IconChevronLeft size=\"large\" = 20");
        compare(prevIcon.color, Theme.current.colorTertiary,
            "$color-pagination_item-icon-default 是 tertiary，不是 text-2");
        const prev = testCase.findChild(p, "paginationPrev");
        hoverOver(prev, 20, 16);
        tryVerify(function () { return testCase.findChild(p, "paginationPrevIcon").color
            === Theme.current.colorText0; }, 1200, "悬浮回 text-0");
        compare(testCase.findChild(p, "paginationPrevBox").color, Theme.current.colorFill0);
        away();
        const nextIcon = testCase.findChild(p, "paginationNextIcon");
        compare(nextIcon.color, Theme.current.colorTertiary, "next 图标缺省也是 tertiary");
        hoverOver(testCase.findChild(p, "paginationNext"), 20, 16);
        tryVerify(function () { return testCase.findChild(p, "paginationNextIcon").color
            === Theme.current.colorText0; }, 1200, "next 悬浮也回 text-0");
        compare(testCase.findChild(p, "paginationNextBox").color, Theme.current.colorFill0);
        away();
        p.destroy();

        const first = make("Pagination { total: 200; pageSize: 10; disabled: false }");
        settled(first);
        away();
        const disabledIcon = testCase.findChild(first, "paginationPrevIcon");
        compare(disabledIcon.color, Theme.current.colorDisabledText, "第 1 页的 prev 图标变禁用色");
        hoverOver(testCase.findChild(first, "paginationPrev"), 20, 16);
        wait(120);
        compare(testCase.findChild(first, "paginationPrevIcon").color, Theme.current.colorDisabledText,
            "-prev.item-disabled 写在 :hover 之后 ⇒ 禁用档悬浮不变色");
        verify(testCase.findChild(first, "paginationPrevBox").color === Qt.rgba(0, 0, 0, 0),
            "禁用档悬浮不变底");
        first.destroy();
    }

    function test_smallCellSkin() {
        const p = make("Pagination { total: 200; pageSize: 10; size: Enums.Small; defaultCurrentPage: 3 }");
        settled(p);
        away();
        const box = testCase.findChild(p, "paginationSmallBox");
        const label = testCase.findChild(p, "paginationSmallLabel");
        compare(label.color, Theme.current.colorText0, "小档那格也带 -item ⇒ text-0");
        verify(box.color === Qt.rgba(0, 0, 0, 0), "小档格常态透明底");
        hoverOver(testCase.findChild(p, "paginationSmallSlot"), 22, 16);
        tryVerify(function () { return box.color === Theme.current.colorFill0; }, 1200);
        mousePress(box, 22, 16, Qt.LeftButton);
        verify(box.color === Theme.current.colorFill1, "按下 fill-1");
        mouseRelease(box, 22, 16, Qt.LeftButton);
        compare(p._current, 3, "松手也不跳页：这一格压根没有点击处理");
        away();
        p.destroy();

        const d = make("Pagination { total: 200; pageSize: 10; size: Enums.Small; disabled: true }");
        const dBox = testCase.findChild(d, "paginationSmallBox");
        verify(dBox.color === Qt.rgba(0, 0, 0, 0), "小档禁用只挂 -all-disabled，不出 disabled-fill");
        compare(testCase.findChild(d, "paginationSmallLabel").color, Theme.current.colorDisabledText);
        d.destroy();
    }

    function test_cellGrowsBeyondMinWidth() {
        // min-width 32 只是下限：五位数那格要按内容长宽（`.semi-page-item` 是 flex + min-width）
        const p = make("Pagination { total: 100000; pageSize: 10 }");
        settled(p);
        compare(p.totalPageNum, 10000);
        sameArray(p.pageList, [1, 2, 3, 4, "...", 9999, 10000]);
        const list = testCase.cells(p);
        compare(labelOf(list[6]).text, "10000");
        verify(labelOf(list[6]).implicitWidth > 32,
            "五位数要比 min-width 宽（实得 " + labelOf(list[6]).implicitWidth + "）");
        near(boxOf(list[6]).width, labelOf(list[6]).implicitWidth, "格子宽 = 内容宽");
        near(list[6].x - list[5].x, boxOf(list[5]).width + 8,
            "长宽的那格把后面的格子一起往右推（间距恒为两条 4 的 margin）");
        p.destroy();
    }

    function test_radiusAndNoBorder() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        const box = boxOf(testCase.cells(p)[0]);
        compare(box.radius, Theme.current.radiusSmall, "$radius-pagination_item = 3");
        compare(box.border.width, 0, "border 宽度令牌是 0px，整组件没有环");
        p.destroy();
    }

    // ---------------- prevText / nextText ----------------

    function test_arrowTextOverriding() {
        const p = make("Pagination { total: 200; pageSize: 10; prevText: \"上一页\"; nextText: \"下一页\" }");
        settled(p);
        const label = testCase.findChild(p, "paginationPrevText");
        compare(label.visible, true);
        compare(label.text, "上一页");
        compare(testCase.findChild(p, "paginationPrevIcon").visible, false, "给了文本就不画 chevron");
        const box = testCase.findChild(p, "paginationPrevBox");
        verify(box.width > 32, "min-width 32，文本更宽就长宽（实得 " + box.width + "）");
        near(box.width, label.implicitWidth, "格子宽 = 文本宽");
        compare(testCase.findChild(p, "paginationNextText").text, "下一页");
        p.destroy();
    }

    function test_emptyArrowTextFallsBackToIcon() {
        const p = make("Pagination { total: 200; pageSize: 10; prevText: \"\" }");
        compare(testCase.findChild(p, "paginationPrevText").visible, false);
        compare(testCase.findChild(p, "paginationPrevIcon").visible, true,
            "官方 `prevText || <Icon/>` 的假值档");
        near(testCase.findChild(p, "paginationPrevBox").width, 32);
        p.destroy();
    }

    function test_componentArrowNode() {
        const p = make("Pagination { total: 200; pageSize: 10; prevText: comp;"
            + " Component { id: comp; Rectangle { width: 12; height: 12; color: '#ff0000' } } }");
        settled(p);
        const loader = testCase.findChild(p, "paginationPrevLoader");
        compare(loader.active, true, "Component 档走 Loader");
        compare(loader.width, 12);
        compare(testCase.findChild(p, "paginationPrevIcon").visible, false);
        near(testCase.findChild(p, "paginationPrevBox").width, 32, "12 比 min-width 窄 ⇒ 取 32");
        p.destroy();
    }

    // ---------------- size 档与位置映射 ----------------

    function test_sizePropOnlySmallChanges() {
        const a = make("Pagination { total: 200; pageSize: 10 }");
        compare(a.isSmall, false);
        a.destroy();

        const b = make("Pagination { total: 200; pageSize: 10; size: Enums.Large }");
        compare(b.isSmall, false, "官方只认 'small'，其余一律默认档");
        compare(testCase.cells(b).length, 7);
        near(testCase.findChild(b, "paginationCellBox").height, 32);
        b.destroy();

        const c = make("Pagination { total: 200; pageSize: 10; size: Enums.Small }");
        compare(c.isSmall, true);
        c.destroy();
    }

    function test_popoverPositionMapping() {
        const p = make("Pagination { total: 200; pageSize: 10; popoverPosition: \"topRight\" }");
        compare(p.positionOf(), Enums.TopRight);
        const dots = testCase.cells(p)[4];
        compare(popIn(dots, "paginationRestPop").position, Enums.TopRight,
            "省略号浮层吃 popoverPosition");
        p.destroy();

        const q = make("Pagination { total: 200; pageSize: 10 }");
        compare(q.positionOf(), Enums.Bottom, "没传 ⇒ Popover 自己的缺省 bottom");
        q.destroy();

        const r = make("Pagination { total: 200; pageSize: 10; popoverPosition: \"bottomLeft\" }");
        compare(r.positionOf(), Enums.BottomLeft);
        r.destroy();

        const s = make("Pagination { total: 200; pageSize: 10; popoverPosition: \"nonsense\" }");
        compare(s.positionOf(), Enums.Bottom, "未知值落回 bottom（官方由 Tooltip 的档位表兜）");
        s.destroy();
    }

    function test_popoverZIndexPropagates() {
        const p = make("Pagination { total: 200; pageSize: 10; popoverZIndex: 1200 }");
        settled(p);
        const pop = popIn(testCase.cells(p)[4], "paginationRestPop");
        compare(pop.zIndex, 1200);
        p.destroy();
    }

    // ---------------- 端到端：翻页 + 换容量 + 跳页 ----------------

    function test_endToEndFlow() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        settled(p);
        testCase.spyOn(p);
        clickOn(testCase.cells(p)[2], 16, 16);
        compare(p._current, 3);
        clickOn(testCase.findChild(p, "paginationNext"), 20, 16);
        compare(p._current, 4);
        sameArray(p.pageList, [1, 2, 3, 4, 5, "...", 20], "c=4 那一支");
        p.changePageSize(40);
        // (4-1)*10+1 = 31 ⇒ ceil(31/40) = 1
        compare(p._current, 1);
        compare(p._pageSize, 40);
        compare(p.totalPageNum, 5);
        sameArray(p.pageList, [1, 2, 3, 4, 5], "5 页 ⇒ 全出");
        sameArray(testCase.signalLog, [
            "pageChange:3", "change:3,10",
            "pageChange:4", "change:4,10",
            "pageSizeChange:40", "pageChange:1", "change:1,40"]);
        p.destroy();
    }

    function test_signalsCarryPageSizeState() {
        // change 的第二个参数永远是**当时**的 state.pageSize（官方 notifyChange 的来源）
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 2 }");
        testCase.spyOn(p);
        p.goPage(3);
        p.changePageSize(100);
        p.goPage(2);
        sameArray(testCase.signalLog, [
            "pageChange:3", "change:3,10",
            "pageSizeChange:100", "pageChange:1", "change:1,100",
            "pageChange:2", "change:2,100"],
            "换容量之后 change 带的是新的 100");
        compare(p._pageSize, 100);
        p.destroy();
    }

    function test_renderedCellsMatchPageList() {
        // 断言「画出来的格子」与算法一致，而不是只查数组
        const p = make("Pagination { total: 200; pageSize: 10; defaultCurrentPage: 18 }");
        settled(p);
        const list = testCase.cells(p);
        compare(list.length, p.pageList.length, "七格");
        const texts = [];
        for (let i = 0; i < list.length; ++i)
            texts.push(labelOf(list[i]).text);
        sameArray(texts, ["1", "...", "16", "17", "18", "19", "20"]);
        compare(labelOf(list[4]).color, Theme.current.colorPrimary, "第 18 页是那格的字色");
        p.destroy();
    }

    function test_cellsFollowCurrentAfterClick() {
        const p = make("Pagination { total: 200; pageSize: 10 }");
        settled(p);
        clickOn(testCase.cells(p)[1], 16, 16);
        tryVerify(function () { return testCase.cells(p).length === 7
            && labelOf(testCase.cells(p)[1]).text === "2"; });
        const boxes = [];
        const list = testCase.cells(p);
        for (let i = 0; i < list.length; ++i)
            boxes.push(labelOf(list[i]).text);
        sameArray(boxes, ["1", "2", "3", "4", "...", "19", "20"], "c=2 仍在第一支");
        away();
        p.destroy();
    }
}
