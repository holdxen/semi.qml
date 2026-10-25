import QtQuick
import QtTest
import Semi

// OverflowList 折叠列表：折叠档的累计算术、collapseFrom 两端、minVisibleItems 硬下限、
// onOverflow 的通知契约、滚动档的露出比例与两份收起列表。
// 规格出处：semi-ui/overflowList/index.tsx、semi-foundation/overflowList/{foundation,constants}.ts、
// overflowList.scss；算法逐句对照写在 src/OverflowList.qml 的头注里。
//
// 跑法：QT_QPA_PLATFORM=offscreen ./build/debug/tests/tst_semi -input tests/tst_overflowlist.qml
TestCase {
    id: tc
    name: "OverflowList"
    when: windowShown
    width: 900
    height: 600
    visible: true

    // 项节点：宽高都从数据里取（w/h 没写的就是 60×24），这样「逐项累加」和「按各自宽排布」
    // 才有东西可断 —— 全等宽的话，把累加写成「第一项宽 × 项数」那种变异是杀不掉的。
    property Component sizedItem: Component {
        Item {
            id: cell

            objectName: "olvItem"
            property var item: null
            property int index: -1

            implicitWidth: cell.item !== null && cell.item.w !== undefined ? cell.item.w : 60
            implicitHeight: cell.item !== null && cell.item.h !== undefined ? cell.item.h : 24
        }
    }

    // 「+N」节点：照官方 demo 的形状 —— 没有收起项时宽就是 0（官方那一份是 renderer 返回 null）
    property Component plusNode: Component {
        Item {
            id: plus

            objectName: "olvPlus"
            property var overflowItems: []

            implicitWidth: plus.overflowItems.length > 0 ? 40 : 0
            implicitHeight: 24
        }
    }

    // 滚动档用的定宽节点（宽不跟着收起项数变，见组件头注那条「视口宽 ↔ 可见集互相追」）
    property Component fixedNode: Component {
        Item {
            id: side

            objectName: "olvFixedPlus"
            property var overflowItems: []
            property string overflowSide: ""

            implicitWidth: 40
            implicitHeight: 24
        }
    }

    readonly property var fiveItems: ["A", "B", "C", "D", "E"]

    function init() {
        tc.visible = true
        Theme.reset()
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, tc, "olv")
    }

    function keysOf(list) {
        const out = []
        for (let i = 0; i < list.length; ++i)
            out.push(list[i] !== null && typeof list[i] === "object" ? list[i].key : list[i])
        return out
    }

    function walk(node, name, out) {
        if (node.objectName === name)
            out.push(node)
        const kids = node.children
        for (let i = 0; i < kids.length; ++i)
            walk(kids[i], name, out)
        return out
    }

    // 实例顺序就是 Repeater 的条目顺序（隐藏项也照样实例化，只是不参与排布）
    function cellsOf(o) {
        return walk(o, "olvItem", [])
    }

    // 两侧的「+N」只能按几何认（Item.childItems 在 QML 里读不回来）
    function sidesByX(o, name) {
        return walk(o, name, []).sort(function (a, b) {
            return a.mapToItem(tc, 0, 0).x - b.mapToItem(tc, 0, 0).x
        })
    }

    function mappedX(node) {
        return Math.round(node.mapToItem(tc, 0, 0).x)
    }

    function visibleKeys(o) {
        const keys = keysOf(o.items)
        const out = []
        for (let i = 0; i < keys.length; ++i)
            if (o.isItemVisible(i))
                out.push(keys[i])
        return out
    }

    // ---------------------------------------------------------------- 折叠档：算术

    // 官方 foundation.ts:133 `let itemWidths = overflowWidth` —— 累计宽从「+N」自己的宽起步，
    // 它那 40 得先从可用宽里扣掉。
    function test_collapseReservesOverflowNodeWidth() {
        const o = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        // 40 + 60 + 60 = 160 ≤ 200 < 160 + 60 ⇒ 只留两项（不扣那 40 就会留三项）
        compare(o.overflowStatus, "overflowed")
        compare(o.pivot, 2)
        compare(o.visibleCount, 2)
        compare(o.hiddenCount, 3)
        compare(o.hasOverflow, true)
        compare(JSON.stringify(keysOf(o.overflowItems)), JSON.stringify(["C", "D", "E"]))
        compare(JSON.stringify(visibleKeys(o)), JSON.stringify(["A", "B"]))
        o.destroy()
    }

    // 逐项累加用的是每项自己的宽，不是「第一项宽 × 项数」
    function test_collapseAccumulatesPerItemWidth() {
        const o = make("OverflowList {"
            + " width: 180;"
            + " items: [{key:'A', w: 30}, {key:'B', w: 90}, {key:'C', w: 50},"
            + "         {key:'D', w: 20}, {key:'E', w: 70}];"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        // 40+30=70 ✓，70+90=160 ✓，160+50=210 ✗ ⇒ 留 A、B
        compare(o.pivot, 2)
        compare(o.visibleCount, 2)
        compare(JSON.stringify(keysOf(o.overflowItems)), JSON.stringify(["C", "D", "E"]))
        const cells = cellsOf(o)
        compare(cells.length, 5)
        compare(cells[0].item.key, "A")
        compare(cells[1].item.key, "B")
        // 摆在容器里的这两项按各自宽推进：0 和 30（当成等宽就会排到 60）
        compare(mappedX(cells[0]), 0)
        compare(mappedX(cells[1]), 30)
        compare(cells[2].visible, false)
        o.destroy()
    }

    // 全程放得下：normal、visible 就是整份、overflow 空 —— 并且官方把 pivot 记成 length-1
    // （foundation.ts:146-147，不是 length），端口照抄，所以这里该是 4 不是 5
    function test_collapseFitsAllKeepsOfficialPivot() {
        const o = make("OverflowList {"
            + " width: 600; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        compare(o.overflowStatus, "normal")
        compare(o.pivot, 4)
        compare(o.visibleCount, 5)
        compare(o.hiddenCount, 0)
        compare(o.hasOverflow, false)
        compare(o.overflowItems.length, 0)
        // 没有收起项时「+N」自己把宽收到 0（官方那一份是 null）
        const plus = walk(o, "olvPlus", [])
        compare(plus.length, 1)
        compare(Math.round(plus[0].implicitWidth), 0)
        o.destroy()
    }

    // 一项都放不下 ⇒ pivot 0（不是 1），整份都收进「+N」
    function test_collapseNothingFits() {
        const o = make("OverflowList {"
            + " width: 50; items: ['A'];"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        compare(o.overflowStatus, "overflowed")
        compare(o.pivot, 0)
        compare(o.visibleCount, 0)
        compare(o.hiddenCount, 1)
        compare(o.isItemVisible(0), false)
        compare(JSON.stringify(keysOf(o.overflowItems)), JSON.stringify(["A"]))
        o.destroy()
    }

    // collapseFrom 'start'：收的是开头，留的是末尾 pivot 项，
    // 而 overflowItems 还是原序（官方 getReversedItems().slice(pivot).reverse() 又翻回来了）
    function test_collapseFromStartKeepsTailAndOriginalOrder() {
        const o = make("OverflowList {"
            + " width: 200; collapseFrom: 'start'; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        compare(o.pivot, 2)
        compare(o.visibleCount, 2)
        compare(JSON.stringify(visibleKeys(o)), JSON.stringify(["D", "E"]))
        compare(o.isItemVisible(0), false)
        compare(o.isItemVisible(2), false)
        compare(o.isItemVisible(3), true)
        compare(o.isItemVisible(4), true)
        compare(JSON.stringify(keysOf(o.overflowItems)), JSON.stringify(["A", "B", "C"]))
        o.destroy()
    }

    // 「+N」跟着 collapseFrom 换边（官方 renderItemList 那两条 ternary），同一时刻只有一份；
    // 没收进来的项不参与排布
    function test_overflowNodeSitsOnTheActiveSide() {
        const end = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)
        const endPlus = walk(end, "olvPlus", [])
        compare(endPlus.length, 1)
        const endCells = cellsOf(end)
        // 留 A、B：0、60，然后才是「+N」（120）
        compare(mappedX(endCells[0]), 0)
        compare(mappedX(endCells[1]), 60)
        compare(mappedX(endPlus[0]), 120)
        end.destroy()

        const start = make("OverflowList {"
            + " width: 200; collapseFrom: 'start'; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)
        const startPlus = walk(start, "olvPlus", [])
        compare(startPlus.length, 1)
        const startCells = cellsOf(start)
        // 「+N」在最前占 40，留下的 D、E 从 40 开始排
        compare(mappedX(startPlus[0]), 0)
        compare(mappedX(startCells[3]), 40)
        compare(mappedX(startCells[4]), 100)
        start.destroy()
    }

    // minVisibleItems 是硬下限：宽度不够也挤出来，代价是整体超出容器
    function test_minVisibleItemsIsHardFloor() {
        const o = make("OverflowList {"
            + " width: 10; minVisibleItems: 3; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        compare(o.overflowStatus, "overflowed")
        compare(o.pivot, 3)
        compare(o.visibleCount, 3)
        compare(o.hiddenCount, 2)
        compare(JSON.stringify(keysOf(o.overflowItems)), JSON.stringify(["D", "E"]))
        // 三项加「+N」= 3*60+40 = 220，早就超出 10 的容器 —— 官方那条说明就是这个
        const cells = cellsOf(o)
        compare(mappedX(cells[0]), 0)
        compare(mappedX(cells[2]), 120)
        o.destroy()
    }

    // 下限不能凭空造项：一共只有两项时 minVisibleItems: 3 不该把 visibleCount 抬到 3
    function test_minVisibleItemsCannotInventItems() {
        const o = make("OverflowList {"
            + " width: 600; minVisibleItems: 3; items: ['A', 'B'];"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        compare(o.overflowStatus, "normal")
        compare(o.visibleCount, 2)
        compare(o.hiddenCount, 0)
        o.destroy()
    }

    // 官方 overflowRenderer 缺省「返回 null」⇒ 没有 overflowWidth 要扣，也没有那份节点
    function test_noOverflowRendererMeansNoReservation() {
        const o = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem }")
        wait(150)

        compare(walk(o, "olvPlus", []).length, 0)
        compare(Math.round(o.overflowWidth), 0)
        // 不扣那 40 ⇒ 放得下三项
        compare(o.pivot, 3)
        compare(o.visibleCount, 3)
        compare(JSON.stringify(keysOf(o.overflowItems)), JSON.stringify(["D", "E"]))
        o.destroy()
    }

    // 空表：官方停在 calculating（那个 for 一次都不进），端口把空表判成 normal —— 见组件头注
    function test_emptyItemsIsNormal() {
        const o = make("OverflowList {"
            + " width: 200; visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        compare(o.itemCount, 0)
        compare(o.overflowStatus, "normal")
        compare(o.visibleCount, 0)
        compare(o.hiddenCount, 0)
        compare(o.hasOverflow, false)
        compare(o.overflowItems.length, 0)
        o.destroy()
    }

    // 隐式高跟「摆出来的那些项」里最高的那个，隐藏项不算
    function test_implicitHeightFollowsVisibleCells() {
        const wide = make("OverflowList {"
            + " width: 600; items: [{key:'A', h: 24}, {key:'B', h: 40}];"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)
        compare(Math.round(wide.implicitHeight), 40)
        wide.destroy()

        // 只留 A（24 高），那个 40 高的 B 收起来了 ⇒ 整行就只有 24
        const narrow = make("OverflowList {"
            + " width: 110; items: [{key:'A', h: 24}, {key:'B', h: 40}];"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)
        compare(narrow.visibleCount, 1)
        compare(Math.round(narrow.implicitHeight), 24)
        narrow.destroy()
    }

    // 不写 width 就铺满父项（官方外层是 block-level flex）
    function test_widthFillsParentByDefault() {
        const o = make("OverflowList {"
            + " items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        compare(Math.round(o.width), Math.round(tc.width))
        // 900 的宽足够放五项 ⇒ normal、无 overflow（顺带证明默认宽真生效了）
        compare(o.overflowStatus, "normal")
        compare(o.visibleCount, 5)
        o.destroy()
    }

    // 每个项节点都拿到自己那份数据和下标（端口的 render* 通道就靠这两枚属性）
    function test_cellsReceiveTheirItemAndIndex() {
        const o = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)

        const cells = cellsOf(o)
        compare(cells.length, 5)
        for (let i = 0; i < cells.length; ++i) {
            compare(cells[i].item, tc.fiveItems[i])
            compare(cells[i].index, i)
        }
        o.destroy()
    }

    // 项节点自己变宽（没有改 items、没有改容器宽）⇒ 只能靠项报回来的宽重算
    property real flexWidth: 60
    property Component flexItem: Component {
        Item {
            id: flex

            objectName: "olvItem"
            property var item: null
            property int index: -1

            implicitWidth: tc.flexWidth
            implicitHeight: 24
        }
    }

    function test_reactsToItemWidthChange() {
        const o = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.flexItem; overflowRenderer: tc.plusNode }")
        wait(150)
        compare(o.visibleCount, 2)

        // 40 + 45*3 = 175 ≤ 200 < 220 ⇒ 换成 45 的项能多塞一项
        tc.flexWidth = 45
        wait(150)
        compare(o.visibleCount, 3)

        tc.flexWidth = 60
        wait(150)
        compare(o.visibleCount, 2)
        o.destroy()
    }

    // ---------------------------------------------------------------- 折叠档：跟着外部变

    function test_reactsToWidthChange() {
        const o = make("OverflowList {"
            + " width: 600; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)
        compare(o.visibleCount, 5)
        compare(Math.round(walk(o, "olvPlus", [])[0].implicitWidth), 0)

        o.width = 200
        wait(150)
        compare(o.visibleCount, 2)
        compare(Math.round(walk(o, "olvPlus", [])[0].implicitWidth), 40)

        o.width = 600
        wait(150)
        compare(o.overflowStatus, "normal")
        compare(o.visibleCount, 5)
        compare(Math.round(walk(o, "olvPlus", [])[0].implicitWidth), 0)
        o.destroy()
    }

    function test_reactsToItemsChange() {
        const o = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)
        compare(o.visibleCount, 2)

        o.items = [{ key: "A", w: 60 }, { key: "B", w: 60 }]
        wait(150)
        compare(o.overflowStatus, "normal")
        compare(o.visibleCount, 2)
        compare(o.hiddenCount, 0)
        compare(cellsOf(o).length, 2)

        o.items = [{ key: "A", w: 100 }, { key: "B", w: 100 }, { key: "C", w: 100 }]
        wait(150)
        // 40 + 100 = 140 ✓，140 + 100 = 240 ✗ ⇒ 只留一项
        compare(o.visibleCount, 1)
        compare(JSON.stringify(keysOf(o.overflowItems)), JSON.stringify(["B", "C"]))
        o.destroy()
    }

    function test_reactsToCollapseFromChange() {
        const o = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)
        compare(JSON.stringify(visibleKeys(o)), JSON.stringify(["A", "B"]))

        o.collapseFrom = "start"
        wait(150)
        compare(JSON.stringify(visibleKeys(o)), JSON.stringify(["D", "E"]))
        o.destroy()
    }

    function test_reactsToMinVisibleItemsChange() {
        const o = make("OverflowList {"
            + " width: 10; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode }")
        wait(150)
        compare(o.visibleCount, 0)

        o.minVisibleItems = 2
        wait(150)
        compare(o.pivot, 2)
        compare(o.visibleCount, 2)
        compare(o.hiddenCount, 3)
        o.destroy()
    }

    // ---------------------------------------------------------------- onOverflow 契约

    // 收敛要跑两轮：第一轮不扣「+N」的宽算出三项，第二轮才知道「+N」要占 40 ⇒ 两项。
    // 两轮 pivot 都在变 ⇒ 恰好两次通知（官方 ResizeObserver 那轮同样是两次回调）。
    function test_overflowNotifiesOncePerPivotChange() {
        const o = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode;"
            + " property int hits: 0; property var last: null;"
            + " onOverflow: function (its) { hits++; last = its } }")
        wait(150)

        compare(o.hits, 2)
        compare(o.pivot, 2)
        compare(JSON.stringify(keysOf(o.last)), JSON.stringify(["C", "D", "E"]))
        // 发的那份就是当时算出来的那份
        compare(JSON.stringify(keysOf(o.last)), JSON.stringify(keysOf(o.overflowItems)))
        o.destroy()
    }

    // 宽度变了但算出来还是两项 ⇒ 一次都不发（官方 :166-168 的 statePivot !== pivot）
    function test_overflowSilentWhenPivotUnchanged() {
        const o = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode;"
            + " property int hits: 0; onOverflow: function (its) { hits++ } }")
        wait(150)
        const base = o.hits

        // 190 和 200 算出来都是两项（40+60+60=160 ≤ 190 < 220）
        o.width = 190
        wait(150)
        compare(o.pivot, 2)
        compare(o.hits, base)
        o.destroy()
    }

    // normal 那一支官方根本不发 onOverflow（foundation.ts 的 normal 分支只 updateStates）
    function test_normalBranchDoesNotNotify() {
        const o = make("OverflowList {"
            + " width: 200; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode;"
            + " property int hits: 0; onOverflow: function (its) { hits++ } }")
        wait(150)
        const base = o.hits

        o.width = 600
        wait(150)
        compare(o.overflowStatus, "normal")
        compare(o.pivot, 4)
        compare(o.hits, base)
        o.destroy()
    }

    // 从 normal 挤回 overflowed：这条要发（pivot 4 → 3 → 2）
    function test_notifiesWhenOverflowingAgain() {
        const o = make("OverflowList {"
            + " width: 600; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.plusNode;"
            + " property int hits: 0; onOverflow: function (its) { hits++ } }")
        wait(150)
        compare(o.hits, 0)

        o.width = 200
        wait(150)
        compare(o.overflowStatus, "overflowed")
        compare(o.hits, 2)
        o.destroy()
    }

    // ---------------------------------------------------------------- 滚动档

    // 官方：root 是滚动容器、threshold 0.75 ⇒ 露出宽 / 项宽 ≥ 0.75 才算看得见。
    // 两侧各一份定宽节点（40+40），150 的容器里视口只剩 70 ⇒ 只有第一项算露出。
    function test_scrollThresholdGeometry() {
        const o = make("OverflowList {"
            + " width: 150; renderMode: 'scroll'; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)

        compare(Math.round(o.scrollViewport.width), 70)
        compare(Math.round(o.scrollViewport.contentWidth), 300)
        compare(JSON.stringify(o.visibleState), JSON.stringify(
            { "0": true, "1": false, "2": false, "3": false, "4": false }))
        compare(o.visibleCount, 1)
        compare(o.hiddenCount, 4)
        compare(o.isItemVisible(0), true)
        compare(o.isItemVisible(1), false)
        // 这一档 overflowItems 是两份数组（官方 getOverflowItem 的两形）
        compare(o.overflowItems.length, 2)
        compare(o.overflowItems[0].length, 0)
        compare(JSON.stringify(keysOf(o.overflowItems[1])), JSON.stringify(["B", "C", "D", "E"]))
        compare(JSON.stringify(keysOf(o.hiddenAfter)), JSON.stringify(["B", "C", "D", "E"]))
        o.destroy()
    }

    // 两侧那两份节点：左边拿「滚过头」的那批，右边拿「还没滚到」的那批
    function test_scrollFeedsBothSideNodes() {
        const o = make("OverflowList {"
            + " width: 150; renderMode: 'scroll'; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)

        const sides = sidesByX(o, "olvFixedPlus")
        compare(sides.length, 2)
        compare(sides[0].overflowItems.length, 0)
        compare(keysOf(sides[1].overflowItems).join(","), "B,C,D,E")
        // 端口给的两份节点分得出左右（官方是 renderer 直接返回两组）
        compare(sides[0].overflowSide, "before")
        compare(sides[1].overflowSide, "after")
        // 两侧都占位：第一项从左边那份节点之后开始排
        const cells = cellsOf(o)
        compare(mappedX(cells[0]), 40)
        compare(mappedX(cells[4]), 280)
        o.destroy()
    }

    // 滚动之后可见集跟着搬：contentX 120 ⇒ 窗口 [120, 190]，只有 C 满露
    function test_scrollContentMoveUpdatesHiddenSets() {
        const o = make("OverflowList {"
            + " width: 150; renderMode: 'scroll'; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)

        o.scrollViewport.contentX = 120
        wait(150)

        compare(o.visibleCount, 1)
        compare(o.isItemVisible(2), true)
        compare(o.isItemVisible(1), false)
        compare(o.isItemVisible(3), false)
        compare(keysOf(o.hiddenBefore).join(","), "A,B")
        compare(keysOf(o.hiddenAfter).join(","), "D,E")
        const sides = sidesByX(o, "olvFixedPlus")
        compare(keysOf(sides[0].overflowItems).join(","), "A,B")
        compare(keysOf(sides[1].overflowItems).join(","), "D,E")
        o.destroy()
    }

    // threshold 真的参与判定（把 0.75 写死的变异要能红）：0.1 时只露 10/60 的第二项也算可见
    function test_scrollThresholdPropIsHonoured() {
        const o = make("OverflowList {"
            + " width: 150; renderMode: 'scroll'; threshold: 0.1; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)

        compare(o.visibleCount, 2)
        compare(o.isItemVisible(1), true)
        compare(JSON.stringify(keysOf(o.hiddenAfter)), JSON.stringify(["C", "D", "E"]))
        o.destroy()
    }

    // 缺省 threshold 真是 0.75：这一档刻意不用「露出 1/6」那种怎么都算不出的比，
    // 而用 0.6 —— 落在 (0.5, 0.75) 之间，把缺省值改成 0.5 的变异就会把它算成可见
    function test_scrollDefaultThresholdIs075() {
        const o = make("OverflowList {"
            + " width: 160; renderMode: 'scroll';"
            + " items: [{key:'a', w: 100}, {key:'b', w: 100}, {key:'c', w: 100}];"
            + " visibleItemRenderer: tc.sizedItem;"
            + " property var lastRes: null; onIntersect: function (r) { lastRes = r } }")
        wait(150)

        // 没有 overflowRenderer ⇒ 两侧都不占位，视口就是 160：a 满露、b 露 60/100、c 一点不露
        fuzzyCompare(o.lastRes["a"].ratio, 1, 0.0001)
        fuzzyCompare(o.lastRes["b"].ratio, 0.6, 0.0001)
        compare(o.lastRes["b"].visible, false)
        compare(o.visibleCount, 1)
        compare(o.hiddenCount, 2)
        compare(JSON.stringify(keysOf(o.hiddenAfter)), JSON.stringify(["b", "c"]))
        o.destroy()
    }

    // 滚动档不折叠：五项全都实例化、全都排在内容行里（视口外的也排着，只是看不见）
    function test_scrollModeRendersEveryItem() {
        const o = make("OverflowList {"
            + " width: 150; renderMode: 'scroll'; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)

        compare(cellsOf(o).length, 5)
        compare(o.overflowStatus, "overflowed")
        // 滚动档的隐式高来自那条滚动行（不是折叠档那一条）
        compare(Math.round(o.implicitHeight), 24)
        const cells = cellsOf(o)
        compare(mappedX(cells[1]), 100)
        compare(mappedX(cells[2]), 160)
        o.destroy()
    }

    // threshold 高到没有项能达标 ⇒ 这一轮的判定不可信：官方在这一格「沿用上一次结果、继续标
    // calculating」（getOverflowItem :52-57），端口按同一条口径走 —— 一份收起列表都不给。
    function test_scrollNothingMeetsThreshold() {
        const o = make("OverflowList {"
            + " width: 150; renderMode: 'scroll'; threshold: 1.1; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)

        compare(o.overflowStatus, "calculating")
        compare(o.visibleCount, 0)
        compare(o.hiddenBefore.length, 0)
        compare(o.hiddenAfter.length, 0)
        compare(o.overflowItems[0].length, 0)
        compare(o.overflowItems[1].length, 0)
        compare(o.isItemVisible(0), false)
        o.destroy()
    }

    // 两份回调：visibleStateChange 给 {key: bool}，intersect 给 {key: {visible, ratio}}
    function test_scrollSignalsCarryStateAndRatios() {
        const o = make("OverflowList {"
            + " width: 150; renderMode: 'scroll'; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode;"
            + " property int stateHits: 0; property int interHits: 0;"
            + " property var lastState: null; property var lastRes: null;"
            + " onVisibleStateChange: function (st) { stateHits++; lastState = st }"
            + " onIntersect: function (r) { interHits++; lastRes = r } }")
        wait(150)

        verify(o.stateHits > 0)
        verify(o.interHits > 0)
        compare(o.lastState["0"], true)
        compare(o.lastState["1"], false)
        compare(o.lastRes["0"].visible, true)
        fuzzyCompare(o.lastRes["0"].ratio, 1, 0.0001)
        // 第二项在 70 的视口里只露出 10 ⇒ 10/60
        fuzzyCompare(o.lastRes["1"].ratio, 10 / 60, 0.0001)
        compare(o.lastRes["1"].visible, false)
        o.destroy()
    }

    // key 的三条取法：缺省字段名 key、指定字段、函数；取不到就按 index 兜底
    function test_itemKeyChannels() {
        const byIndex = make("OverflowList {"
            + " width: 150; renderMode: 'scroll'; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)
        compare(byIndex.keyOf(2), "2")
        compare(JSON.stringify(Object.keys(byIndex.visibleState)),
            JSON.stringify(["0", "1", "2", "3", "4"]))
        byIndex.destroy()

        // 缺省 itemKey 就是官方那条 `get(item, itemKey || 'key', index)` ⇒ 取的是 key 字段
        const byDefault = make("OverflowList {"
            + " width: 150; renderMode: 'scroll';"
            + " items: [{id:'x1', key:'A'}, {id:'x2', key:'B'}, {id:'x3', key:'C'}];"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)
        compare(byDefault.keyOf(1), "B")
        compare(JSON.stringify(Object.keys(byDefault.visibleState)), JSON.stringify(["A", "B", "C"]))
        byDefault.destroy()

        const byField = make("OverflowList {"
            + " width: 150; renderMode: 'scroll'; itemKey: 'id';"
            + " items: [{id:'x1', key:'A'}, {id:'x2', key:'B'}, {id:'x3', key:'C'}];"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)
        compare(byField.keyOf(1), "x2")
        compare(JSON.stringify(Object.keys(byField.visibleState)),
            JSON.stringify(["x1", "x2", "x3"]))
        byField.destroy()

        const byFn = make("OverflowList {"
            + " width: 150; renderMode: 'scroll';"
            + " itemKey: function (it) { return 'k' + it.key };"
            + " items: [{key:'A'}, {key:'B'}];"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)
        compare(byFn.keyOf(0), "kA")
        compare(JSON.stringify(Object.keys(byFn.visibleState)), JSON.stringify(["kA", "kB"]))
        byFn.destroy()
    }

    function test_renderModeSwitchAtRuntime() {
        const o = make("OverflowList {"
            + " width: 280; items: tc.fiveItems;"
            + " visibleItemRenderer: tc.sizedItem; overflowRenderer: tc.fixedNode }")
        wait(150)
        // 折叠档：先扣定宽节点的 40 ⇒ 40+60*4=280 恰好放四项，第五项超 ⇒ 收一项，
        // 而且 overflowItems 是一份扁数组
        compare(o.visibleCount, 4)
        compare(JSON.stringify(keysOf(o.overflowItems)), JSON.stringify(["E"]))
        compare(walk(o, "olvFixedPlus", []).length, 1)

        o.renderMode = "scroll"
        wait(150)
        // 滚动档：两侧各占 40 ⇒ 视口 200，前三项满露；overflowItems 变成两份数组
        compare(o.visibleCount, 3)
        compare(o.overflowItems.length, 2)
        compare(o.overflowItems[0].length, 0)
        compare(JSON.stringify(keysOf(o.overflowItems[1])), JSON.stringify(["D", "E"]))
        compare(walk(o, "olvFixedPlus", []).length, 2)
        o.destroy()
    }
}
