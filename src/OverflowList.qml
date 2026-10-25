pragma ComponentBehavior: Bound

import QtQuick

// 溢出列表：子项排成一行，放不下的收进一个「更多」节点；也可以不折叠，改成横向滚动。
//
//     OverflowList {
//         items: [{ iconName: "alarm", key: "alarm" }, …]
//         visibleItemRenderer: Component {          // 官方 visibleItemRenderer(item, index)
//             IconTag {}                            // 节点里声明 property var item / property int index
//         }
//         overflowRenderer: Component {             // 官方 overflowRenderer(overflowItems)
//             PlusTag {}                            // 节点里声明 property var overflowItems
//         }
//         onOverflow: items => console.log(items.length)
//     }
//
// 规格出处：`semi-ui/overflowList/index.tsx`（props 与 renderItemList）、
// `semi-foundation/overflowList/{foundation,constants}.ts`、`overflowList.scss`。
//
// 缺省值（index.tsx:73-82 的 defaultProps）：renderMode 'collapse'、collapseFrom 'end'、
// minVisibleItems 0、threshold 0.75、overflowRenderer / visibleItemRenderer 都是「返回 null」、
// onOverflow 空函数、overflowRenderDirection 'both'（官方注释写了「给 Tabs 用，不对外」）。
//
// 组件自己**没有任何视觉样式**：`overflowList.scss` 全文只有三条 —— 外层
// `display:flex; flex-wrap:nowrap; min-width:0`、`-spacer{flex-shrink:1;width:1px}`（Tabs 用的）、
// `-scroll-wrapper{display:flex;flex:1;flex-wrap:nowrap;overflow-x:scroll}`。
// 官方 demo 里项与项之间那 8px 是每个 Tag 自己写的 `style={{marginRight:8}}`，不是组件的令牌
// ⇒ 端口没有 spacing 属性，要间距就写进渲染节点自己的隐式宽（gallery 页就是这么摆的）。
// 外层 `width` 取「铺满可用宽」（block-level flex 的默认），使用方给显式 width 就以它为准。
// renderer 返回 null 那一档在 QML 没有对应物（Component 总会造出一个节点）⇒ 等价写法是让节点
// 自己在没内容时把隐式宽收到 0 / `visible:false`，官方 demo 的 `items.length ? <Tag/> : null` 就是这个意思。
//
// 折叠算法照 `foundation.ts:129-171 handleCollapseOverflow` 逐句搬：
//   累计宽从「更多」节点的宽起步（`itemWidths = overflowWidth`），按项的顺序累加，
//   **第一项加进去就超过容器宽的算放不下**，此时 `_pivot` 就是它前面那些放得下的项数；
//   `pivot = Math.max(minVisibleItems, _pivot)` —— minVisibleItems 是硬下限，宽度不够也挤出来，
//   代价是整体超出容器（官方那条说明就是这个）；
//   collapseFrom 'start' 留的是**末尾** pivot 项（`getReversedItems().slice(0,pivot).reverse()`），
//   收起来的是开头几项，而且「更多」节点排在**最前**、不是最后（index.tsx:341 / :358 那两条 ternary）；
//   'end' 留开头、节点排末尾；
//   全程放得下 ⇒ overflowStatus 'normal'、visible 就是整份 items、overflow 空，
//   并且 **pivot 记成 items.length - 1**（:146-147，不是 length）；
//   官方那句「遍历到最后一项就提前收尾」（`_pivot === items.length - 1`）端口不搬 ——
//   这一版把 normal 判定放在循环外（走完一圈没溢出就是 normal），那一条 break 只是少加一次
//   随后没人读的 `count`，实测删掉与删前逐项等价（变异 O19 打的就是它，绿 ⇒ 是死代码而非用例漏）。
//   `onOverflow` 只在 `statePivot !== pivot` 时发（:166-168），而 'normal' 那一支根本不发
//   —— 于是「从 normal 挤回 overflowed、恰好落在 length-1」那一格官方不通知。
//   这两条都是上游行为，端口照抄：`pivot` 与「可见项数」分开记（`visibleCount` 在 normal 档恒等于
//   itemCount），就是为了把这条通知契约抄准。
//   这条算法有个两边共存的活锁：容器宽刚好卡在「扣掉「+N」才放不下、不扣就放得下」那一格时，
//   normal（「+N」空 ⇒ 宽 0）与 overflowed（「+N」有内容 ⇒ 定宽）会来回翻，每一翻又排一轮重算。
//   官方那条 `items.length ? <Tag/> : null` 同样会让 `-overflow` 那个 div 在 0 与定宽之间跳，
//   React 那边就是无限重渲染 ⇒ 端口不额外加阻尼，只把这条记下来：真实内容宽不是整数，撞上的概率是零头；
//   写用例时要避开正好相等的宽（比如 40+60+60 = 100 这种）。
//   上游有一处端口没抄：itemSizeMap 按 key 存宽（:381-388 只在「这个 key 还没量过」时才写），
//   重复 key 的两项会共用一份宽度；端口按 index 量，各算各的。
//
// 滚动档（renderMode 'scroll'）：官方用 IntersectionObserver（root 是那条滚动容器、threshold 0.75）
// 算每项露出的比例；端口按几何算同一件事 —— 项与视口交叠宽 / 项宽 ≥ threshold 才算可见。
// `getOverflowItem()`（:29-63）在这一档返回 **[开头收起的那批, 末尾收起的那批]** 两份，官方把
// `overflowRenderer` 返回的那一组节点摆在滚动容器两侧（`overflowRenderDirection` 默认 'both'）；
// 端口把同一个渲染节点实例化两次，前一份拿到 `hiddenBefore`、后一份拿到 `hiddenAfter`
// （`overflowItems` 这一枚属性本身在滚动档就是 `[hiddenBefore, hiddenAfter]`，与官方一致）。
// 没有任何项可见时官方「沿用上一次结果、继续标 calculating」（:52-57，异步观察器要那一手防抖）；
// 端口只在「尺寸还没量到」的第一轮落在 calculating，量到宽就出结果。
// 端口这一档另外两点：
//   · 两侧节点占的宽会吃掉视口（官方 `-scroll-wrapper{flex:1}` 同款：箭头占多少，滚动区就少多少）。
//     于是 `overflowRenderer` 在滚动档**不要**让节点宽随「这一边有没有收起来的项」变化 ——
//     官方那对箭头就是定宽的（只切 enabled）。空⇒0 宽、非空⇒定宽会「视口宽 ↔ 可见集 ↔ 节点宽」
//     互相追着改（实测：滚到中段时视口从 110 掉到 70，因为两侧都冒出 40 宽的节点）。
//   · 官方滚动档根本不跑折叠那套（`componentDidUpdate` :214 对 scroll 直接 return），
//     `overflowStatus` 会一直停在 'calculating'；端口把它改成本档的「视口里有没有露出来的项」：
//     有 ⇒ overflowed，一个都没有 ⇒ calculating。
//
// 与官方的差异（React / DOM 在 QML 侧无处落地，逐条）：
//   · `visibleItemRenderer` / `overflowRenderer` 官方是函数返回元素；QML 只给 `Component`，
//     参数靠「节点自己声明 `property var item` / `property int index` / `property var overflowItems`，
//     端口创建后写进去」这一条通道（本库 render* 类口子统一这么办）。
//   · `className` / `style` / `wrapperClassName` / `wrapperStyle` 不落（没有 CSS 可挂）；
//     `overflowRenderDirection` 官方标了不对外 ⇒ 端口不开放，滚动档两侧都摆。
//   · `onIntersect` 官方给 `{[key]: IntersectionObserverEntry}`；端口给
//     `{[key]: {visible, ratio}}`（Entry 那一套 DOM 矩形没有对应物）。
//   · `onVisibleStateChange` 官方是 `Map<string, boolean>`；端口是普通对象 `{key: bool}`（信号 `visibleStateChange`）。
//   · 官方滚动档的 `overflowRenderer` 返回的是**两组**节点（`[开头那批, 末尾那批]` 各渲染一份，
//     Tabs 那对箭头方向相反就是这么来的）；端口一份 `Component` 实例化两遍，分不出左右 ⇒
//     额外注入 `property string overflowSide`（`"before"` / `"after"`，同样是「声明了才写」），
//     节点自己按它决定画哪个方向的箭头。
//   · 端口额外给了三枚只读便利量：`visibleCount` / `hiddenCount` / `hasOverflow`。
//     官方没有这三个字段，读的是 `state.visible` / `state.overflow` 两个数组 —— 而滚动档
//     `state.visible` 是「全部已渲染」（项都在滚动容器里，只是滚出视野了），拿它当「看得见几项」
//     是错的。端口统一按「看得见」给：折叠档 = 摆出来的那几项，滚动档 = 露出够 threshold 的那几项，
//     两档都满足 `visibleCount + hiddenCount == itemCount`；`isItemVisible()` 同一口径。
//     要官方那份「已渲染」列表就读 `overflowItems` / `hiddenBefore` + `hiddenAfter`。
//   · 首帧官方在算完之前 `visibility:hidden`（:368），靠 ResizeObserver + 'calculating' 重渲染一轮才显形；
//     端口不隐藏，但同样要跑两轮：项宽与「更多」宽都是渲染节点报回来的，量到之后
//     结果才会定下来 ⇒ 断言要 `wait()` 一轮再读。
//   · 每一个触发点（尺寸回调、items / renderMode / collapseFrom / minVisibleItems / threshold 变更、
//     乃至 Component.onCompleted）一律 `Qt.callLater` 延到本轮绑定算完之后：overflow 节点的宽是从 `overflowItems`
//     这条绑定求值出来的，而重算又写这条绑定的依赖（pivot / hiddenAfter），同步回调会被 QML
//     判成 binding loop。官方的 ResizeObserver / IntersectionObserver 本来就是下一轮才回调，
//     两边时序因此一致。
//   · `-spacer` 与 `-scroll-wrapper` 那几个类名是 Tabs 内部用的，本组件没有对应需求。
//   · `items` 为空：官方停在 'calculating'（`handleCollapseOverflow` 那个 for 一次都不进，
//     没人写 overflowStatus），端口把空表直接判成 normal（「全都放得下」是空表的正确答案）。
//     上游这一格是状态机没兜住，不是契约 ⇒ 不抄。
Item {
    id: control

    // ---------------------------------------------------------------- OverflowListProps
    /// 官方 items：每项要有 key（或按 itemKey 取）；取不到 key 的（比如裸字符串）按 index 兜底
    property var items: []
    /// 官方 itemKey：字段名或 (item) => key，缺省取 item.key（`get(item, itemKey || 'key', index)`）
    property var itemKey: "key"
    property string renderMode: "collapse"            // collapse | scroll
    property string collapseFrom: "end"               // start | end
    property int minVisibleItems: 0
    property real threshold: 0.75                     // 只有滚动档用：露出多少比例算可见
    /// 官方 visibleItemRenderer(item, index)
    property Component visibleItemRenderer: null
    /// 官方 overflowRenderer(overflowItems)
    property Component overflowRenderer: null

    /// 官方 onOverflow(overflowItems)：折叠结果变了才发，且 normal 那一支不发
    signal overflow(var overflowItems)
    /// 官方 onIntersect(res)（滚动档）
    signal intersect(var res)
    /// 官方 onVisibleStateChange(visibleState)（滚动档）
    signal visibleStateChange(var visibleState)

    // ---------------------------------------------------------------- 算出来的状态
    readonly property bool collapseMode: control.renderMode === "collapse"
    /// 官方 state.pivot：overflowed 档是可见项数，normal 档官方记的是 length-1（见文件头）
    property int pivot: -1
    /// 官方 state.overflowStatus
    property string overflowStatus: "calculating"     // calculating / overflowed / normal
    readonly property int itemCount: control.items === undefined ? 0 : control.items.length
    /// 现在真的露在容器里的项数：折叠档 = 摆出来的那些（normal 档就是全部），
    /// 滚动档 = 露出够 threshold 的那些（官方 state.visible 在滚动档是「全部已渲染」，
    /// 端口这里给的是「看得见的」—— 使用方（箭头、+N）要的就是这个）
    readonly property int visibleCount: {
        if (!control.collapseMode) {
            let n = 0
            const state = control.visibleState
            for (const k in state)
                if (state[k])
                    ++n
            return n
        }
        if (control.overflowStatus !== "overflowed")
            return control.itemCount
        return Math.min(control.pivot, control.itemCount)
    }
    readonly property int hiddenCount: control.itemCount - control.visibleCount
    readonly property bool hasOverflow: control.hiddenCount > 0
    /// collapse 档是「被收起的那一批」，scroll 档是 [开头那批, 末尾那批]（官方 getOverflowItem 的两形）
    readonly property var overflowItems: control.collapseMode
        ? control.collapsedItems : [control.hiddenBefore, control.hiddenAfter]
    /// 滚动档：每个 key 露出够不够 threshold，{key: bool}
    property var visibleState: ({})
    property var hiddenBefore: []
    property var hiddenAfter: []
    /// 端口比官方多给的一枚只读把手：官方那个 `this.scroller` 是内部 ref，
    /// QML 侧要让使用方（和测试）能驱动/读横向滚动位置，就得把它露出来
    readonly property Item scrollViewport: scroller

    readonly property var collapsedItems: {
        const res = []
        if (!control.collapseMode || control.overflowStatus !== "overflowed")
            return res
        // 'start' 收的是开头，'end' 收的是末尾
        const from = control.collapseFrom === "start" ? 0 : control.visibleCount
        const to = control.collapseFrom === "start" ? control.itemCount - control.visibleCount
            : control.itemCount
        for (let i = from; i < to; ++i)
            res.push(control.items[i])
        return res
    }

    // 铺满可用宽（官方外层是 block-level flex）；使用方写显式 width 就以它为准
    width: parent ? parent.width : 0
    implicitHeight: control.collapseMode ? strip.height : scrollLine.height

    function keyOf(index) {
        const item = control.items[index]
        const k = control.itemKey
        if (typeof k === "function")
            return String(k(item))
        if (item !== null && typeof item === "object") {
            const v = item[k]
            if (v !== undefined && v !== null)
                return String(v)
        }
        return String(index)
    }

    function isItemVisible(index) {
        if (!control.collapseMode)
            return Boolean(control.visibleState[control.keyOf(index)])
        return control.collapseFrom === "start"
            ? index >= control.itemCount - control.visibleCount
            : index < control.visibleCount
    }

    function cellWidthAt(index) {
        const cell = control.collapseMode ? itemRepeater.itemAt(index)
            : scrollRepeater.itemAt(index)
        return cell !== null ? cell.implicitWidth : 0
    }

    // 每一个触发点都排在「本轮绑定算完」之后跑。同步回调会撞上求值中的绑定，QML 判成 binding loop，
    // 端口这两条链都是这样：
    //   · 「更多」节点的宽来自它读 overflowItems，而重算写的正是这条绑定的依赖（pivot / hiddenAfter）；
    //   · visibleCount 读 items ⇒ 首次求值时 items 那条绑定自己跑完 ⇒ 发 itemsChanged ⇒ 重算写 pivot
    //     ⇒ 又把还在求值中的 visibleCount 顶回来（gallery 页第一次就是这么报的）。
    // 官方的 ResizeObserver / IntersectionObserver / setState 本来就都在下一轮，时序因此一致。
    function scheduleRecompute() {
        Qt.callLater(control.recompute)
    }

    // 「更多」节点这一档摆在哪一侧、当前那份的宽（等价官方 state.overflowWidth）
    readonly property real overflowWidth: control.collapseFrom === "start"
        ? headLoader.cellWidth : tailLoader.cellWidth

    // 官方 :129-171：累计宽从 overflowWidth 起步，逐项加，加进去就超的那项放不下
    function recomputeCollapse() {
        const before = control.pivot
        const available = control.width
        let used = control.overflowWidth
        let count = 0
        let overflowed = false
        for (let i = 0; i < control.itemCount; ++i) {
            const size = cellWidthAt(i)
            if (used + size > available) {
                overflowed = true
                break
            }
            used += size
            count += 1
        }
        if (!overflowed) {
            // 全部放得下：官方记 normal + pivot = length-1，而且不发 onOverflow
            control.overflowStatus = "normal"
            control.pivot = Math.max(0, control.itemCount - 1)
            return
        }
        control.overflowStatus = "overflowed"
        control.pivot = Math.max(control.minVisibleItems, count)
        if (before !== control.pivot)                    // 官方 :166-168
            control.overflow(control.collapsedItems)
    }

    // 滚动档：按几何算露出比例（官方是 IntersectionObserver + threshold）
    function recomputeScroll() {
        const state = {}
        const res = {}
        const viewLeft = scroller.contentX
        const viewRight = scroller.contentX + scroller.width
        let firstVisible = -1
        let lastVisible = -1
        for (let i = 0; i < control.itemCount; ++i) {
            const cell = scrollRepeater.itemAt(i)
            if (cell === null)
                continue
            const overlap = Math.min(viewRight, cell.x + cell.width)
                - Math.max(viewLeft, cell.x)
            const ratio = cell.width > 0 ? Math.max(0, overlap) / cell.width : 0
            const visible = ratio >= control.threshold
            const key = control.keyOf(i)
            state[key] = visible
            res[key] = ({ visible: visible, ratio: ratio })
            if (visible) {
                if (firstVisible < 0)
                    firstVisible = i
                lastVisible = i
            }
        }
        const nextBefore = []
        const nextAfter = []
        if (firstVisible >= 0) {
            for (let i = 0; i < firstVisible; ++i)
                nextBefore.push(control.items[i])
            for (let i = lastVisible + 1; i < control.itemCount; ++i)
                nextAfter.push(control.items[i])
        }
        control.visibleState = state
        control.hiddenBefore = nextBefore
        control.hiddenAfter = nextAfter
        control.overflowStatus = firstVisible >= 0 ? "overflowed" : "calculating"
        control.visibleStateChange(state)
        control.intersect(res)
    }

    function recompute() {
        if (control.collapseMode)
            control.recomputeCollapse()
        else
            control.recomputeScroll()
    }

    // 所有触发点一律延后重算（理由见 scheduleRecompute）
    onWidthChanged: control.scheduleRecompute()
    onItemsChanged: control.scheduleRecompute()
    onRenderModeChanged: control.scheduleRecompute()
    onCollapseFromChanged: control.scheduleRecompute()
    onMinVisibleItemsChanged: control.scheduleRecompute()
    onThresholdChanged: control.scheduleRecompute()
    Component.onCompleted: control.scheduleRecompute()

    // ---------------------------------------------------------------- 折叠档
    // 项一律实例化（放不下的只是不显示 —— Row 跳过不可见子项，位置与隐式高都不受它影响），
    // 这样每项的宽度才量得出来，与官方「先按 maxCount 渲染、ResizeObserver 量到宽再重算」等价
    Row {
        id: strip

        visible: control.collapseMode
        spacing: 0

        // collapseFrom 'start' ⇒「更多」排在最前（官方 index.tsx:341）。
        // 两侧各放一个 Loader 但只有一份 active —— 官方那两条 ternary 同一次只渲染一侧，
        // 端口也必须只有一份：两份会各算一次 overflowWidth，还会让同一个渲染节点多实例化一遍。
        Item {
            id: overflowHead

            width: headLoader.cellWidth
            height: headLoader.cell !== null ? headLoader.cell.implicitHeight : 0

            Loader {
                id: headLoader

                readonly property Item cell: headLoader.item as Item
                readonly property real cellWidth: cell !== null ? cell.implicitWidth : 0

                active: control.collapseMode && control.collapseFrom === "start"
                    && control.overflowRenderer !== null
                sourceComponent: control.overflowRenderer
                onCellWidthChanged: control.scheduleRecompute()
                onLoaded: item.overflowItems = Qt.binding(function () {
                    return control.collapsedItems
                })
            }
        }

        Repeater {
            id: itemRepeater

            // 另一档的那套项也要真的不存在（不是只 visible:false）：
            // 两档都实例化会把每个渲染节点造两遍，位置也各算各的
            model: control.collapseMode ? control.items : []

            delegate: Item {
                id: itemCell

                required property var modelData
                required property int index

                implicitWidth: cellLoader.cell !== null ? cellLoader.cell.implicitWidth : 0
                implicitHeight: cellLoader.cell !== null ? cellLoader.cell.implicitHeight : 0
                width: implicitWidth
                height: implicitHeight
                visible: control.isItemVisible(itemCell.index)

                onWidthChanged: control.scheduleRecompute()

                Loader {
                    id: cellLoader

                    readonly property Item cell: cellLoader.item as Item

                    sourceComponent: control.visibleItemRenderer
                    onLoaded: {
                        item.item = itemCell.modelData
                        // qmllint disable missing-property
                        item.index = itemCell.index
                        // qmllint enable missing-property
                    }
                }
            }
        }

        // collapseFrom 'end'（缺省）⇒「更多」排在末尾（官方 :358）
        Item {
            id: overflowTail

            width: tailLoader.cellWidth
            height: tailLoader.cell !== null ? tailLoader.cell.implicitHeight : 0

            Loader {
                id: tailLoader

                readonly property Item cell: tailLoader.item as Item
                readonly property real cellWidth: cell !== null ? cell.implicitWidth : 0

                active: control.collapseMode && control.collapseFrom !== "start"
                    && control.overflowRenderer !== null
                sourceComponent: control.overflowRenderer
                onCellWidthChanged: control.scheduleRecompute()
                onLoaded: item.overflowItems = Qt.binding(function () {
                    return control.collapsedItems
                })
            }
        }
    }

    // ---------------------------------------------------------------- 滚动档
    // 两侧各一份「这一边收起的项」节点，中间那条滚动容器吃剩下的宽（官方 flex: 1）
    Row {
        id: scrollLine

        visible: !control.collapseMode
        spacing: 0

        Item {
            id: scrollHead

            visible: control.overflowRenderer !== null
            width: scrollHeadLoader.cellWidth
            height: scrollHeadLoader.cell !== null ? scrollHeadLoader.cell.implicitHeight : 0

            Loader {
                id: scrollHeadLoader

                readonly property Item cell: scrollHeadLoader.item as Item
                readonly property real cellWidth: cell !== null ? cell.implicitWidth : 0

                active: !control.collapseMode && control.overflowRenderer !== null
                sourceComponent: control.overflowRenderer
                onCellWidthChanged: control.scheduleRecompute()
                onLoaded: {
                    // 官方滚动档的 renderer 返回的是「[开头那批的节点, 末尾那批的节点]」两组，
                    // 两侧长什么样由使用方自己定（Tabs 那对箭头方向就相反）。端口的 Component 只
                    // 实例化一次一份，分不出左右 ⇒ 额外注入 `overflowSide`（同样「声明了才写」）。
                    // qmllint disable missing-property
                    if (item.overflowSide !== undefined)
                        item.overflowSide = "before"
                    // qmllint enable missing-property
                    item.overflowItems = Qt.binding(function () {
                        return control.hiddenBefore
                    })
                }
            }
        }

        Flickable {
            id: scroller

            width: control.width - scrollHead.width - scrollTail.width
            height: scrollRow.height
            contentWidth: scrollRow.width
            contentHeight: scrollRow.height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: scrollRow.width > width

            onContentXChanged: control.scheduleRecompute()

            Row {
                id: scrollRow

                spacing: 0

                Repeater {
                    id: scrollRepeater

                    model: control.collapseMode ? [] : control.items

                    delegate: Item {
                        id: scrollCell

                        required property var modelData
                        required property int index

                        implicitWidth: scrollLoader.cell !== null ? scrollLoader.cell.implicitWidth : 0
                        implicitHeight: scrollLoader.cell !== null ? scrollLoader.cell.implicitHeight : 0
                        width: implicitWidth
                        height: implicitHeight

                        // 露出比例既按项宽也按项在内容行里的位置 ⇒ 宽或 x 变了都得重算
                        // （x 是 Row 排布时才落定的，只盯宽会在刚换档那一轮把每项都算成满露）
                        onWidthChanged: control.scheduleRecompute()
                        onXChanged: control.scheduleRecompute()

                        Loader {
                            id: scrollLoader

                            readonly property Item cell: scrollLoader.item as Item

                            sourceComponent: control.visibleItemRenderer
                            onLoaded: {
                                item.item = scrollCell.modelData
                                // qmllint disable missing-property
                                item.index = scrollCell.index
                                // qmllint enable missing-property
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: scrollTail

            visible: control.overflowRenderer !== null
            width: scrollTailLoader.cellWidth
            height: scrollTailLoader.cell !== null ? scrollTailLoader.cell.implicitHeight : 0

            Loader {
                id: scrollTailLoader

                readonly property Item cell: scrollTailLoader.item as Item
                readonly property real cellWidth: cell !== null ? cell.implicitWidth : 0

                active: !control.collapseMode && control.overflowRenderer !== null
                sourceComponent: control.overflowRenderer
                onCellWidthChanged: control.scheduleRecompute()
                onLoaded: {
                    // qmllint disable missing-property
                    if (item.overflowSide !== undefined)
                        item.overflowSide = "after"
                    // qmllint enable missing-property
                    item.overflowItems = Qt.binding(function () {
                        return control.hiddenAfter
                    })
                }
            }
        }
    }
}
