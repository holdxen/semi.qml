pragma ComponentBehavior: Bound

import QtQuick

// 列表。官方 `List`（packages/semi-ui/list/index.tsx）是一个「壳 + 数据」的组件：
// 壳管 header / items / footer / loadMore 四段，items 由 `dataSource` + `renderItem`
// 生成，也可以直接声明 children；栅格、横向、加载态都由这几个开关决定。
//
//     List {
//         width: 420
//         header: "成员"
//         footer: Component { Text { text: "共 6 人" } }
//         bordered: true
//         dataSource: ["甲", "乙"]
//         renderItem: Component { ListItem { main: modelData } }
//     }
//
// ------------------------------------------------------------------ 官方 ListProps
// 逐条对着 index.tsx:17-35 的 ListProps 与 :61-69 的 defaultProps：
//   · `bordered` 缺省 **false**、`split` 缺省 **true**、`loading` false、`layout` "vertical"、
//     `size` "default"（small / default / large）。官方**没有** emptyText / spacing / itemSize
//     这几条，本库早期自造的已并回官方面。
//   · `header` / `footer` / `loadMore` / `emptyContent` 官方都是 ReactNode，本库统一口径：
//     字符串或 `Component`；四段都按 `{x ? <div> : null}` 的真值判断决定占不占位
//     （`header: ""`、`header: 0` 都是「没有头部」）。
//   · `dataSource` + `renderItem`：官方 renderItem 是 `(item, ind) => ReactNode`，端口用
//     Repeater 顶替，注入名走本库惯例 `modelData` / `index`（同 AutoComplete.renderItem）。
//   · `onClick` / `onRightClick` 官方挂在每个 li 上（List 通过 context 下发，条目自己的赢），
//     端口做成 `clicked` / `rightClicked`，只罩 items 那一段 —— 点 header、footer 不算，
//     和官方一样。
//   · `grid` 官方是把 items 容器换成 Grid 的 Row/Col：`align` / `gutter` / `justify` / `type`
//     给 Row，其余给 Col（index.tsx:92-114）。端口落地 `span`、`gutter`（数字、[横, 纵]、
//     或按档位的对象）、`xs|sm|md|lg|xl|xxl`（数字或对象）、`align`、`justify`，Col 那五个
//     属性 `span` / `offset` / `push` / `pull` / `order` 也都认（档位对象里同样能带）。
//     `offset` 照 margin-left（占格、影响换行与富余），`push` / `pull` 照相对位移（只挪像素、
//     不参与排版，两个都给时 push 赢）；`order` 对 List **恒无效** —— 那个对象是原样摊给
//     每一条 Col 的（item.tsx:50-58），所有 Col 拿到同一个 order ⇒ flex 等值即保持源码顺序，
//     官方也没有「单独改某一条的顺序」的入口。`-offset-0` / `-push-0` 这类规则在样式表里
//     压根不存在（mixin 的 loop 从 1 起）⇒ 给 0 或负数等于没给，端口同样按没给处理。
//   · `style` / `className` 不收（没有 CSS）。
//
// ------------------------------------------------------------------ 规格
// list.scss + variables.scss：
//   · 四段从上到下是 header → items → footer → loadMore；`loading` 只把 Spin 套在 items 外。
//   · header / footer 的内边距与条目同档（默认上下 12 左右 24、small 8/16、large 16/24）；
//     条目在栅格档内边距清 0，但 header / footer **不清**（:99-103 只选了 -item）。
//     注意 scss 写的是 `padding: $…-paddingX $…-paddingY`，CSS 简写第一格是**上下** ⇒
//     这两个令牌名读反了（paddingX 是纵向）。
//   · `split` 一处开关管三条线：条目之间 1px color-border（末条不画）、header 底 1px、
//     footer 顶 1px；`split: false` 时三条一起没。横向档条目那条改画右边（:109-122）。
//   · 空态：`padding: 12px 0`、色 text-2、`width:100%`、`text-align:center`，
//     文字取 locale（zh_CN 是「暂无数据」）。
//   · 本体没有底色也没有圆角，`bordered` 就是一条 1px color-border；字号 14 / 行高 20。
//
// ------------------------------------------------------------------ 与官方的差异 / 照抄的怪处
//   · `dataSource` 非空但 `renderItem` 没给：官方 `items = []` ⇒ 一条都不出，而且因为走了
//     `if (dataSource.length)` 这一支，**连空态占位都不画**（:144-157）。端口照抄。
//   · `dataSource` 非空时官方把生成条目和 `children` **一起**塞进同一个容器
//     （`{childrenList}{children}`，:109-112）⇒ 声明式子项跟在生成条目后面重复出现。
//     端口照抄，顺序也是「生成的在前」。
//   · 分割线的 `:last-child` 是相对**直属父节点**的：栅格档每条独占一个 Col、条目被
//     Skeleton 之类包了一层，都会让它自己成为 last-child ⇒ 整档没有线。端口只给
//     「自己摊平出来的那些节点里的非末条」写 `hasSeam`，效果同官方（见 ListItem 文件头）。
//   · 横向档官方 `.semi-list-items{display:flex}` 的交叉轴初值是 stretch ⇒ 同排条目一律
//     拉到最高那条的高；端口照抄（纵向档是 block，各自高度）。
//   · 点 items 区的空白（空态那一条、横排/栅格行里的富余段）官方不算点击 —— 处理器只挂在
//     li 上；端口把 List 级的处理器挂在 items 容器上，所以按摊平后各条的矩形挡了一下。
//   · 栅格断点官方读浏览器视口（media query），端口拿所在 Window 的宽度顶替，
//     没有 Window 时退回列表自身宽度。断点数值照抄 grid.scss：xs 那条规则没包在
//     media query 里 ⇒ 恒生效，sm≥576、md≥768、lg≥992、xl≥1200、xxl≥1600，越靠后的档赢；
//     `span: 0` 对应 `-col-0 { display:none }` ⇒ 整条不排版、也不占格。
//   · 栅格行官方是 `flex-flow: row wrap` 配 Row 的 -g/2 负外边距与 Col 的 +g/2 左右内边距，
//     两者抵掉 ⇒ 一格的内容宽是 `(容器宽 + gutter) * span/24 - gutter`，首格贴容器左边缘；
//     端口按 24 格累计换行，`type` 只认 flex（非 flex 官方是 float 排版，观感一致）。
//   · `loading` 官方永远套一层 Spin 壳（不转时是个空 div）；端口只在 loading 时摆指示符
//     + 半透明遮罩，不额外占位。
Item {
    id: control

    // ---- 官方 ListProps（index.tsx:17-35，缺省 :61-69）----
    property bool bordered: false
    property var dataSource: []
    property Component renderItem: null
    property var emptyContent: undefined
    property var footer: undefined
    property var grid: undefined
    property var header: undefined
    property string layout: "vertical"              // vertical | horizontal
    property var loadMore: undefined
    property bool loading: false
    property string size: "default"                 // small | default | large
    property bool split: true

    signal clicked
    signal rightClicked

    // 官方 children：与 dataSource 无关，永远排在生成条目之后
    default property alias content: declaredZone.data

    // ListItem 靠它认领「我的 List 是哪一层」（官方是 CSS 命中，端口要显式认父）
    readonly property bool isListHost: true

    // ---- 派生开关 ----
    readonly property bool gridOn: control.grid !== undefined && control.grid !== null
    readonly property bool horizontal: control.layout === "horizontal"
    readonly property bool headerTaken: control._taken(control.header)
    readonly property bool footerTaken: control._taken(control.footer)
    readonly property bool loadMoreTaken: control._taken(control.loadMore)
    readonly property bool useDataSource: control.dataSource !== undefined
        && control.dataSource !== null && control.dataSource.length > 0
    // 官方 :146 `renderItem ? dataSource.map(...) : []`
    readonly property int generatedCount: control.useDataSource && control.renderItem !== null
        ? control.dataSource.length : 0
    // declaredZone.children 里会混着 Repeater（Qt 6.11 起 Repeater 自己就是个 Item，
    // 而它生成的条目反而是它的兄弟），那一条不是官方的 children，不能算数。
    // children 这种 list 属性没有 NOTIFY，绑定不会自己跟新 ⇒ 由 relayout() 刷。
    property int declaredCount: 0
    // 官方 :155 `else if (!children)` —— dataSource 空、但有声明式子项时不画空态
    readonly property bool showEmpty: !control.useDataSource && control.declaredCount === 0

    // ---- 令牌 ----
    readonly property real seamWidth: 1                                 // $border-thickness-control
    readonly property real bandPadV: control.size === "small" ? Theme.current.spacingTight
        : (control.size === "large" ? Theme.current.spacingBase : Theme.current.spacingBaseTight)
    readonly property real bandPadH: control.size === "small" ? Theme.current.spacingBase
        : Theme.current.spacingLoose
    readonly property real emptyPadV: Theme.current.spacingBaseTight     // $spacing-list_empty-paddingY
    readonly property real lineHeight: 20                                // font-size-regular → 14/20

    // ---- 四段的高度 ----
    readonly property real headerNodeHeight: control.headerTaken
        ? (control._isText(control.header) ? headerText.implicitHeight : headerLoader.implicitHeight) : 0
    readonly property real footerNodeHeight: control.footerTaken
        ? (control._isText(control.footer) ? footerText.implicitHeight : footerLoader.implicitHeight) : 0
    readonly property real loadMoreHeight: control.loadMoreTaken ? loadMoreLoader.implicitHeight : 0
    readonly property real headerHeight: control.headerTaken
        ? control.headerNodeHeight + control.bandPadV * 2 + (control.split ? control.seamWidth : 0) : 0
    readonly property real footerHeight: control.footerTaken
        ? control.footerNodeHeight + control.bandPadV * 2 + (control.split ? control.seamWidth : 0) : 0
    readonly property real emptyNodeHeight: control._taken(control.emptyContent)
        ? (control._isText(control.emptyContent) ? control.lineHeight : emptyLoader.implicitHeight)
        : control.lineHeight
    readonly property real emptyHeight: control.showEmpty
        ? control.emptyNodeHeight + control.emptyPadV * 2 : 0

    property real itemsHeight: 0

    implicitHeight: control.headerHeight + control.itemsHeight + control.footerHeight
        + control.loadMoreHeight

    // 官方是块级 div：宽度由父级给，端口没有布局引擎兜着，要使用方自己写 width。
    // 栅格断点官方读浏览器视口（media query），端口拿所在 Window 的宽顶替；
    // 不在窗口里（比如刚建好、或者被塞进离屏容器）时退回列表自身宽度。
    readonly property real viewportWidth: {
        const win = Window.window;
        return win !== null && win !== undefined && win.width > 0 ? win.width : control.width;
    }

    // ------------------------------------------------------------------ 摊平与重排
    // 顺序照官方：先 renderItem 生成的，再声明式 children
    function itemNodes() {
        const nodes = [];
        for (let i = 0; i < control.generatedCount; ++i) {
            const node = generatedRepeater.itemAt(i);
            if (node !== null && node !== undefined && !(node instanceof Repeater))
                nodes.push(node);
        }
        for (let i = 0; i < declaredZone.children.length; ++i) {
            const node = declaredZone.children[i];
            if (node === null || node === undefined || node instanceof Repeater)
                continue;
            nodes.push(node);
        }
        return nodes;
    }

    // 条目自己长高／变宽（List 这边一个属性都没动）时也得重排。官方那是浏览器重排；
    // 端口的 `Item.childrenRect` 在这种情况下不变脏（探针量过：条目的 height 已经从 45
    // 涨到 89，容器的 childrenRect 还停在 89，信号都不发）⇒ 位置器那条路在这里不可依赖，
    // 改成给摊平出来的每条挂一个 Connections 盯它自己的尺寸。
    property var nodeWatchers: []
    // 横向档的交叉轴 stretch 只能靠给每条钉死 height 来模拟，而 height 一旦被写死，
    // Item 那条「高跟着隐式高走」的默认回落就永久断了：C++ 的 resetHeight() 没标
    // Q_INVOKABLE（探针：QML 侧读到的 pinned.resetHeight 是 undefined），给 height
    // 挂 Qt.binding(implicitHeight) 又会被 Qt 判成 implicitHeight 的绑定环。
    // 所以钉过的那批记在这里，之后每轮纵向／栅格重排都替它们把高对回隐式高。
    property var stretchPinned: []

    function syncStretchHeight(node) {
        if (control.stretchPinned.indexOf(node) >= 0)
            node.height = node.implicitHeight;
    }

    function syncWatchers(nodes) {
        for (let i = 0; i < nodes.length; ++i) {
            const old = control.nodeWatchers[i];
            if (old !== undefined && old !== null && old.watched === nodes[i])
                continue;
            if (old !== undefined && old !== null)
                old.destroy();
            const created = nodeWatcherProto.createObject(control);
            created.watched = nodes[i];
            control.nodeWatchers[i] = created;
        }
        for (let i = nodes.length; i < control.nodeWatchers.length; ++i) {
            const stale = control.nodeWatchers[i];
            if (stale !== undefined && stale !== null)
                stale.destroy();
        }
        control.nodeWatchers.length = nodes.length;
    }

    Component {
        id: nodeWatcherProto

        Connections {
            property var watched: null

            target: watched

            function onHeightChanged() {
                control.requestRelayout();
            }

            function onImplicitHeightChanged() {
                control.requestRelayout();
            }

            // 横向档与栅格档按内容宽排版：条目自己改文案 / 换行时宽也会变
            function onWidthChanged() {
                control.requestRelayout();
            }

            function onImplicitWidthChanged() {
                control.requestRelayout();
            }
        }
    }

    // Repeater 本身不算 children 里的那一条（见 itemNodes 的说明）
    function countDeclaredChildren() {
        let n = 0;
        for (let i = 0; i < declaredZone.children.length; ++i) {
            if (!(declaredZone.children[i] instanceof Repeater))
                ++n;
        }
        return n;
    }

    // 「声明了才写」：只有 ListItem 有 hasSeam，别的节点（Skeleton 包的那一层、空态）
    // 不会被写入，也就永远不画线 —— 官方那两条规则在它们身上同样是这个结果。
    function writeSeam(node, shown) {
        if (node !== null && node !== undefined && node.hasSeam !== undefined)
            node.hasSeam = shown;
    }

    // 排版上下文（size / layout / 栅格）由这里往下推，条目自己不回读父项（见 ListItem 的说明）。
    // 官方那是 `.semi-list-small .semi-list-item { padding }` 一类的层叠选择器 ⇒ 条目被
    // Skeleton 之类包了一层时，里面那条 li 照样被命中，所以这里递归进子树找 ListItem。
    // 递归到里面又开了一个 List 就停：那一档的 size 归它自己管（官方靠后者覆盖，端口按
    // 「内层容器说了算」处理）。分割线不参与递归 —— :last-child 看的是直属父节点。
    function pushCtx(node) {
        if (node === null || node === undefined || node.isListHost === true)
            return;
        // 三个字段**逐条判存在再写**：带 hostSize 的不止条目（DescriptionsItem / Step /
        // TabItem 也有），其中有的没有 hostLayout / hostInGrid —— 无条件写会抛
        // TypeError，把 relayout() 中途打断、layingOut 卡在 true，之后所有重排被
        // requestRelayout 的闸掉、条目宽度永远钉不下来 ⇒ polish 里「width 回落
        // implicitWidth、位置器隐式尺寸又吃子项实际宽」的环每圈 +padding 无限发散
        //（gallery ListPage 卡死那回，6 秒 24 万圈，见坑 136）。
        if (node.hostSize !== undefined)
            node.hostSize = control.size;
        if (node.hostLayout !== undefined)
            node.hostLayout = control.layout;
        if (node.hostInGrid !== undefined)
            node.hostInGrid = control.grid !== undefined && control.grid !== null;
        for (let i = 0; i < node.children.length; ++i)
            control.pushCtx(node.children[i]);
    }

    // 栅格档每条独占一个 Col（自己就是 :last-child）⇒ 整档没线
    function seamAt(index, total) {
        return control.split && !control.gridOn && index < total - 1;
    }

    // 排版自己改的那些几何会同步惊动条目上的尺寸 watcher（见 syncWatchers）：不挡就会在
    // relayout 里再进 relayout。挡掉的这一趟不用记账 —— 条目把隐式高落到 height 上是
    // polish 阶段的事，那一声 heightChanged 落在守卫之外，会把重排再叫起来一遍
    // （探针：把「收尾补一趟」的记账摘掉，71 条用例一条不红）。
    property bool layingOut: false

    function requestRelayout() {
        if (control.layingOut)
            return;
        control.relayout();
    }

    function relayout() {
        control.layingOut = true;
        // finally：pushCtx 写坏一个属性就会抛 TypeError，不兜住的话 layingOut 卡在 true、
        // 之后所有 requestRelayout 被闸死（坑 136 那次卡死的放大器）
        try {
        control.declaredCount = control.countDeclaredChildren();
        const nodes = control.itemNodes();
        // 顺序要紧：上下文与分割线都先写下去，条目那头把 padV / hasSeam 吃进隐式尺寸是
        // 同步的，写完再量才量得到新值；反过来（先量后写）就会在求值中的绑定里补算这条链，
        // Qt 判成绑定环、这一轮的数直接作废。
        for (let i = 0; i < nodes.length; ++i) {
            control.pushCtx(nodes[i]);
            control.writeSeam(nodes[i], control.seamAt(i, nodes.length));
        }
        // 分支一律读原始 prop，别读 gridOn / horizontal 那两条派生绑定：换档那一刻
        // onLayoutChanged / onGridChanged 会先进 handler、后重算同对象上的绑定，handler 里
        // 读派生值读到的是上一档（探针：layout 已经写成 horizontal，读出来的 horizontal 还是
        // false，整条 stretch 分支被跳过了）。
        const asGrid = control.grid !== undefined && control.grid !== null;
        const asHorizontal = control.layout === "horizontal";
        if (asGrid) {
            control.relayoutGrid(nodes);
        } else if (asHorizontal) {
            // .semi-list-flex .semi-list-items { display: flex }，交叉轴 stretch
            let tallest = 0;
            let x = 0;
            for (let i = 0; i < nodes.length; ++i) {
                nodes[i].width = nodes[i].implicitWidth;
                tallest = Math.max(tallest, nodes[i].implicitHeight);
            }
            for (let i = 0; i < nodes.length; ++i) {
                nodes[i].x = x;
                nodes[i].y = 0;
                nodes[i].height = tallest;
                if (control.stretchPinned.indexOf(nodes[i]) < 0)
                    control.stretchPinned.push(nodes[i]);
                x += nodes[i].width;
            }
            control.itemsHeight = nodes.length > 0 ? tallest : 0;
        } else {
            // 纵向：ul 是 block，每条铺满宽、按各自隐式高往下叠
            let cursor = 0;
            for (let i = 0; i < nodes.length; ++i) {
                control.syncStretchHeight(nodes[i]);
                nodes[i].x = 0;
                nodes[i].y = cursor;
                nodes[i].width = itemsBlock.width;
                cursor += nodes[i].height;
            }
        control.itemsHeight = nodes.length > 0 ? cursor : control.emptyHeight;
        }
        control.syncWatchers(nodes);
        } finally {
            control.layingOut = false;
        }
    }

    // ------------------------------------------------------------------ 栅格
    // 官方 span 与 xs..xxl 都落在同一个 Col 的类上，媒体查询里的那条在样式表更后面 ⇒ 赢；
    // -xs 那条规则压根没包 media query（grid.scss:88-100）⇒ 恒生效。
    //
    // Col 那一层有五个类名属性（col.tsx:63-98 配的类，规则在 grid/mixin.scss:57-80）：
    //   span   → width: span/24              offset → margin-left: n/24
    //   push   → left: n/24（position:relative 的相对位移）
    //   pull   → right: n/24                  order  → flex 的 order
    // 档位是**按属性各取各的**：col.tsx:73-84 把每一档的类名并进同一个 classnames 对象，
    // 所以 `md: { span: 8 }` 清不掉上一档 `sm: { offset: 4 }` 那条类 —— 只有真给了这一项的
    // 档才改写它。数字档（`sm: 6`）只带 span（:69-71 把数字当 { span } 用）。
    function colProp(key) {
        const g = control.grid;
        let value = control._propOf(g, key, undefined);
        const stages = [["xs", 0], ["sm", 576], ["md", 768], ["lg", 992], ["xl", 1200], ["xxl", 1600]];
        for (let i = 0; i < stages.length; ++i) {
            const name = stages[i][0];
            if (stages[i][1] > 0 && control.viewportWidth < stages[i][1])
                continue;
            if (!control._has(g, name))
                continue;
            const stage = g[name];
            if (typeof stage === "number") {
                if (key === "span")
                    value = stage;
                continue;
            }
            if (control._has(stage, key))
                value = stage[key];
        }
        return value;
    }

    function colSpan() {
        return control.colProp("span");
    }

    // mixin 的 loop 从 1 数到 24 ⇒ 只有 -offset-1..24 / -push-1..24 / -pull-1..24 这些类，
    // 给 0、给负数、给非数都落不到任何规则上 ⇒ 一律按「没给」处理。
    // （col.tsx 在响应式档上写的是 `offset || offset === 0`，会真吐出 `-offset-0` 那个类名，
    // 但样式表里没有这条规则，所以两处的结果一样。）
    function _colShift(value) {
        return typeof value === "number" && value > 0 ? value : 0;
    }

    // gutter 支持数字、[横, 纵]、或按档位的对象。
    // 数字只给横向（官方 getGutter：非数组就是 [gutter, 0]）；
    // 对象档走 Row.tsx 从 xxl 往下扫，第一个命中且给了值的档赢，
    // 那一档的 xs 是 (max-width: 575px)，所以只有视口真窄于 576 才命中。
    function gutterAt(index) {
        const raw = control._propOf(control.grid, "gutter", 0);
        const one = Array.isArray(raw) ? raw[index] : (index === 0 ? raw : 0);
        if (one === undefined || one === null)
            return 0;
        if (typeof one !== "object")
            return one;
        const order = ["xxl", "xl", "lg", "md", "sm", "xs"];
        for (let i = 0; i < order.length; ++i) {
            const key = order[i];
            if (!control._has(one, key))
                continue;
            const min = control.breakMin(key);
            if (min === 0 ? control.viewportWidth < 576 : control.viewportWidth >= min)
                return one[key];
        }
        return 0;
    }

    function breakMin(key) {
        if (key === "xs")
            return 0;                       // xs 是 max-width:575，没有下限
        if (key === "sm")
            return 576;
        if (key === "md")
            return 768;
        if (key === "lg")
            return 992;
        if (key === "xl")
            return 1200;
        return 1600;
    }

    function relayoutGrid(nodes) {
        const g = control.gutterAt(0);
        const vg = control.gutterAt(1);
        const rowWidth = itemsBlock.width;
        // Row 左右各 -g/2、Col 左右各 +g/2 ⇒ 行内容盒是 rowWidth + g
        const unit = (rowWidth + g) / 24;
        const span = control.colSpan();
        // offset 是 margin-left：它占格、影响换行，也吃掉行内富余；
        // push / pull 是 position:relative 下的位移：只在视觉上挪，不参与排版。
        // CSS 的 over-constrained 规则 —— 相对定位同时给 left 与 right 时 left 赢 ⇒ push 盖 pull。
        const offsetW = unit * control._colShift(control.colProp("offset"));
        const pushW = unit * control._colShift(control.colProp("push"));
        const pullW = unit * control._colShift(control.colProp("pull"));
        const shiftW = pushW > 0 ? pushW : -pullW;
        // order 读了也不生效：grid 那个对象是**原样摊给每一条 Col** 的（item.tsx:50-58
        // 把同一个 rest 交给每个 Col），所有 Col 拿到同一个 order ⇒ flex 里等值即保持源码顺序。
        // 官方因此没有「单独给某一条改序」的入口，端口同样不动。
        const justify = control._propOf(control.grid, "justify", "start");
        const align = control._propOf(control.grid, "align", "top");

        // 1) 按 24 格累计换行（官方 flex-flow: row wrap）
        const lines = [];
        let line = [];
        let used = 0;
        for (let i = 0; i < nodes.length; ++i) {
            const node = nodes[i];
            // 栅格档每条独占一个 Col（自己就是 :last-child）⇒ seamAt 里那道 gridOn 负责没线
            control.writeSeam(node, control.seamAt(i, nodes.length));
            if (span === 0) {                   // -col-0 { display: none }
                // 只藏，别去钉 width/height —— 钉过一次就把「高跟着内容走」这条默认绑定
                // 永久打断，档位再变回来（窗口变宽）时就再也长不起来了（cocoa 截图抓到）。
                node.visible = false;
                continue;
            }
            // 没给 span 的 Col 官方没有宽度类 ⇒ 按内容自量。offset 那截 margin 也占这一格的位
            const boxWidth = (span === undefined ? node.implicitWidth + g : unit * span) + offsetW;
            if (span !== undefined && line.length > 0 && used + boxWidth > rowWidth + g + 0.5) {
                lines.push(line);
                line = [];
                used = 0;
            }
            line.push(node);
            used += boxWidth;
        }
        if (line.length > 0)
            lines.push(line);

        // 2) 逐行摆：justify 分行内富余，align 决定这一格在行带里的纵向位置
        let top = 0;
        for (let l = 0; l < lines.length; ++l) {
            const items = lines[l];
            let band = 0;
            for (let i = 0; i < items.length; ++i) {
                items[i].width = span === undefined ? items[i].implicitWidth
                    : Math.max(0, unit * span - g);
                items[i].visible = true;
                control.syncStretchHeight(items[i]);
                band = Math.max(band, items[i].height);
            }
            const usedWidth = span === undefined ? items.reduce((acc, n) => acc + n.width + g + offsetW, 0)
                : items.length * (unit * span + offsetW);
            const free = Math.max(0, rowWidth + g - usedWidth);
            let cursor = -g / 2;
            let gap = 0;
            if (justify === "center")
                cursor += free / 2;
            else if (justify === "end")
                cursor += free;
            else if (justify === "space-between" && items.length > 1)
                gap = free / (items.length - 1);
            else if (justify === "space-around") {
                // 官方 space-around 是「每项两侧各半档」⇒ 首项也要先挪半个间隔
                gap = free / items.length;
                cursor += gap / 2;
            }
            for (let i = 0; i < items.length; ++i) {
                const node = items[i];
                const colBox = (span === undefined ? node.width + g : unit * span) + offsetW;
                // 格子的起点先加 offset（margin-left 把它从行首推开），再加 push / -pull 的相对位移
                node.x = cursor + i * (colBox + gap) + g / 2 + offsetW + shiftW;
                node.y = top + (align === "middle" ? (band - node.height) / 2
                    : (align === "bottom" ? band - node.height : 0));
            }
            top += band + vg;
        }
        control.itemsHeight = lines.length > 0 ? Math.max(0, top - vg) : control.emptyHeight;
    }

    // ------------------------------------------------------------------ 点击转发
    // 官方把 onClick / onRightClick 通过 ListContext 下发到**每个 List.Item**上
    // （index.tsx:165-175，item.tsx:75-77 `onClick ? onClick : contextOnClick`）：
    // 点条目算、点 header / footer / loadMore / 空白都不算，而条目被 Skeleton 之类
    // 包了一层时照样算（处理器本来就挂在那条 li 自己身上）。
    // 所以端口不在这边挂处理器，由 ListItem 收到点击后回头调这两个槽 ——
    // 那条「按矩形过滤坐标」的路子在这版 Qt 上不可靠：QtTest 的合成事件把事件的
    // localPos 写成「相对被点击那一项」的坐标，容器量到的数会跟着失真（探针踩过）。
    // 另外官方是「条目自己的赢、二选一」，QML 探不出信号有没有人接 ⇒ 两层都会发。
    function _itemClicked() {
        control.clicked();
    }

    function _itemRightClicked() {
        control.rightClicked();
    }

    // ------------------------------------------------------------------ 小工具
    function _taken(value) {
        return !!value;
    }

    function _isText(value) {
        return typeof value === "string" || typeof value === "number";
    }

    function _isNode(value) {
        return control._taken(value) && !control._isText(value);
    }

    function _nodeOf(value) {
        return control._isNode(value) ? value : null;
    }

    function _has(obj, key) {
        return obj !== undefined && obj !== null && typeof obj === "object" && key in obj
            && obj[key] !== undefined && obj[key] !== null;
    }

    function _propOf(obj, key, fallback) {
        return control._has(obj, key) ? obj[key] : fallback;
    }

    // ------------------------------------------------------------------ 描边
    Rectangle {
        objectName: "listBorder"

        anchors.fill: parent
        visible: control.bordered
        color: "transparent"
        // 官方 `border: 1px solid var(--semi-color-border)`：没有圆角、也没有底色
        border.width: control.seamWidth
        border.color: Theme.current.colorBorder
    }

    // ------------------------------------------------------------------ header
    Item {
        id: headerBlock

        objectName: "listHeader"

        x: 0
        y: 0
        width: control.width
        height: control.headerHeight
        visible: control.headerTaken

        Item {
            id: headerPaddingBox

            objectName: "listHeaderPaddingBox"

            x: control.bandPadH
            y: control.bandPadV
            width: headerBlock.width - control.bandPadH * 2
            height: control.headerNodeHeight

            Text {
                id: headerText

                objectName: "listHeaderText"

                visible: control.headerTaken && control._isText(control.header)
                text: control.headerTaken && control._isText(control.header) ? String(control.header) : ""
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeight: control.lineHeight
                lineHeightMode: Text.FixedHeight
            }

            Loader {
                id: headerLoader

                objectName: "listHeaderNode"

                active: control._nodeOf(control.header) !== null
                sourceComponent: control._nodeOf(control.header)
            }
        }

        // .semi-list-split .semi-list-header { border-bottom }
        Rectangle {
            objectName: "listHeaderSeam"

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: control.seamWidth
            visible: control.split
            color: Theme.current.colorBorder
        }
    }

    // ------------------------------------------------------------------ items
    Item {
        id: itemsBlock

        objectName: "listItems"

        x: 0
        y: control.headerHeight
        width: control.width
        height: control.itemsHeight
        // <Spin spinning={loading}> 的 -children { opacity: .5 }
        opacity: control.loading ? 0.5 : 1

        Item {
            id: generatedZone

            objectName: "listItemsGenerated"

            x: 0
            y: 0
            width: itemsBlock.width
            height: itemsBlock.height

            onChildrenChanged: control.requestRelayout()

            Repeater {
                id: generatedRepeater

                model: control.useDataSource && control.renderItem !== null ? control.dataSource : []
                delegate: control.renderItem
            }
        }

        // 官方把 children 与生成条目塞进同一个容器，这里给它一块同尺寸的落位区
        Item {
            id: declaredZone

            objectName: "listItemsDeclared"

            x: 0
            y: 0
            width: itemsBlock.width
            height: itemsBlock.height

            onChildrenChanged: control.requestRelayout()
        }

        // .semi-list-empty：padding 12px 0、text-2、width 100%、text-align center
        Item {
            id: emptyBlock

            objectName: "listEmpty"

            x: 0
            y: 0
            width: itemsBlock.width
            height: control.emptyHeight
            visible: control.showEmpty

            Text {
                id: emptyText

                objectName: "listEmptyText"

                anchors.horizontalCenter: parent.horizontalCenter
                y: control.emptyPadV
                visible: control.showEmpty && !control._isNode(control.emptyContent)
                text: control._isText(control.emptyContent) ? String(control.emptyContent) : qsTr("暂无数据")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeight: control.lineHeight
                lineHeightMode: Text.FixedHeight
                horizontalAlignment: Text.AlignHCenter
            }

            Loader {
                id: emptyLoader

                objectName: "listEmptyNode"

                active: control.showEmpty && control._isNode(control.emptyContent)
                sourceComponent: control._nodeOf(control.emptyContent)
                y: control.emptyPadV
            }
        }

    }

    // ------------------------------------------------------------------ footer
    Item {
        id: footerBlock

        objectName: "listFooter"

        x: 0
        y: control.headerHeight + control.itemsHeight
        width: control.width
        height: control.footerHeight
        visible: control.footerTaken

        // .semi-list-split .semi-list-footer { border-top }
        Rectangle {
            objectName: "listFooterSeam"

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: control.seamWidth
            visible: control.split
            color: Theme.current.colorBorder
        }

        Item {
            id: footerPaddingBox

            objectName: "listFooterPaddingBox"

            x: control.bandPadH
            y: control.bandPadV + (control.split ? control.seamWidth : 0)
            width: footerBlock.width - control.bandPadH * 2
            height: control.footerNodeHeight

            Text {
                id: footerText

                objectName: "listFooterText"

                visible: control.footerTaken && control._isText(control.footer)
                text: control.footerTaken && control._isText(control.footer) ? String(control.footer) : ""
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeight: control.lineHeight
                lineHeightMode: Text.FixedHeight
            }

            Loader {
                id: footerLoader

                objectName: "listFooterNode"

                active: control._nodeOf(control.footer) !== null
                sourceComponent: control._nodeOf(control.footer)
            }
        }
    }

    // ------------------------------------------------------------------ loadMore
    // 官方就是裸节点：`{loadMore ? loadMore : null}`，没有内边距也没有分隔线
    Item {
        id: loadMoreBlock

        objectName: "listLoadMore"

        x: 0
        y: control.headerHeight + control.itemsHeight + control.footerHeight
        width: control.width
        height: control.loadMoreHeight
        visible: control.loadMoreTaken

        Loader {
            id: loadMoreLoader

            objectName: "listLoadMoreNode"

            active: control._nodeOf(control.loadMore) !== null
            sourceComponent: control._nodeOf(control.loadMore)
        }
    }

    // ------------------------------------------------------------------ loading
    // 官方 -wrapper：绝对定位、整幅宽、垂直居中、text-align center（size 给 large = 32）
    Spin {
        id: spinOverlay

        objectName: "listSpin"

        size: "large"
        spinning: control.loading
        anchors.centerIn: itemsBlock
    }

    // -block::after 那层透明遮罩（z-index:1）：加载中条目点不动。
    // 注意它是 Rectangle 不是 MouseArea 就行 —— 遮罩只挡事件，不需要自己处理。
    Rectangle {
        objectName: "listSpinMask"

        anchors.fill: itemsBlock
        visible: control.loading
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
    }

    // ------------------------------------------------------------------ 重排时机
    Component.onCompleted: control.requestRelayout()
    onWidthChanged: control.requestRelayout()
    onDataSourceChanged: control.requestRelayout()
    onRenderItemChanged: control.requestRelayout()
    onGridChanged: control.requestRelayout()
    onLayoutChanged: control.requestRelayout()
    onSplitChanged: control.requestRelayout()
    onSizeChanged: control.requestRelayout()
    onShowEmptyChanged: control.requestRelayout()
    onHeaderHeightChanged: control.requestRelayout()
    onEmptyHeightChanged: control.requestRelayout()
    onViewportWidthChanged: control.requestRelayout()

}
