pragma ComponentBehavior: Bound

import QtQuick

// 卡片组。官方 `packages/semi-ui/card/cardGroup.tsx`（CardGroupProps :11-21、
// defaultProps :32-34、render :36-61）—— 本体就是一层 `Space`：
//
//     CardGroup {
//         width: 860
//         spacing: 16
//         Card { width: 260; title: "Card title" }
//         Card { width: 260; title: "Card title" }
//     }
//
// 官方那一层能拆成四条行为：
//   · `<Space spacing={isGrid ? 0 : spacing} wrap={true} …>`（:51-52）⇒ 换行排布；
//     `type === 'grid'` 时**间距被强制清 0**，`spacing` 那条同时失效（API 表里
//     「设置完该属性后将覆盖 spacing」说的就是这里）。
//   · Space 的缺省 `align: 'center'`（space/index.tsx:40）⇒ 每行里的卡片**垂直居中**对齐，
//     不是顶对齐、也不是 stretch。
//   · Space 本体 `display: inline-flex` ⇒ 容器宽是「一行放得下就按内容宽、放不下才跟着可用宽」，
//     端口把它落成：`width` 由父级给，父级没给时用「全部塞一行」的 max-content 宽。
//   · grid 档 card.scss 还有两条后代规则：`-group-grid .semi-card { border-radius: 0 }` 和
//     `.semi-card-group-grid .semi-card { margin-left: -1px; margin-top: -1px }`。端口没有 CSS，
//     前者逐张下发 `cardGroupGrid`（只认得 Card，别的子项不动它），后者按「相邻两张重叠 1px」实现
//     —— 官方那对负 margin 还会把整组往左上挪 1 像素，端口不减那一格（看不见）。
//
// 与官方文档/实现的口径差：
//   · `spacing` 的缺省，**代码是 16**（defaultProps :33），API 表里写的是 `12px` —— 端口取代码那条，
//     表里的按上游文档陈旧记录。
//   · `spacing` 官方类型是 `number | number[]`（数组形如 `[水平, 垂直]`），端口两档都收；
//     给的不是数字（空数组、`[0]` 缺第二格、字符串）时按 0 —— 和官方一致：那一格压根没写进
//     style，flex 缺省就是 0。
//   · `className` / `style` 收了不产出可见差异（官方只喂给 Space 那层 div）。
//   · `spacing` 的字符串档（`'tight' | 'medium' | 'loose'`）：**TS 类型里没有，但 Space 的
//     运行时认**（`isString(spacing)` 那一支会把 `-tight-horizontal` / `-tight-vertical` 挂上，
//     值取 `$spacing-space-*` = 8 / 16 / 20）。端口照运行时收这三档，认不出来的字符串按 0
//     —— 与官方「类名没命中 ⇒ gap 没设」同值。
Item {
    id: control

    // ---- 官方 CardGroupProps（cardGroup.tsx:11-21，缺省 :32-34）----
    property string className: ""              // 死 prop
    property var spacing: 16                   // number | [水平, 垂直]
    property var style: undefined              // 死 prop
    property string type: ""                   // '' | grid

    /// 官方 children
    default property alias content: host.data

    readonly property bool isGrid: control.type === "grid"
    // 这三条只是给用例与调用方看的读数，排版路径一律走下面那三个函数
    readonly property real horizontalGap: control.hGap()
    readonly property real verticalGap: control.vGap()
    /// grid 档那对 -1px margin ⇒ 相邻卡片重叠 1 像素（两条描边合成一条）
    readonly property real overlap: control.ov()

    property int childCount: 0

    // ---- 排出来的几何（relayout 写，测试与调用方读）----
    property real lineWidth: 0
    property real layoutHeight: 0

    /// 「全部塞一行」的 max-content 宽：只读子项自己的宽，不回读 control.width ⇒ 不成环
    readonly property real maxContentWidth: control.oneLineWidth()

    implicitWidth: control.maxContentWidth
    implicitHeight: control.layoutHeight
    width: control.parent ? control.parent.width : control.implicitWidth

    /// 排好的行：每行的首项下标 / 行高 / 右边缘，用来做行内居中与组宽
    property var lineStarts: []
    property var lineHeights: []
    property var lineExtents: []

    function gapAt(value, slot) {
        if (Array.isArray(value))
            return control.gapOne(value[slot]);
        return control.gapOne(value);
    }

    /// Space 的两档写法都照收：数字直接当像素；`'tight' | 'medium' | 'loose'` 是 CSS 类名档
    /// （space/index.tsx:57-73 + space.scss 的 `-tight-horizontal` 那一族），值取
    /// `$spacing-space-*` = spacing-tight 8 / spacing-base 16 / spacing-loose 20。
    /// 认不出来的一律 0 —— 官方那条也是「类名没命中 ⇒ gap 压根没设」。
    function gapOne(value) {
        if (typeof value === "number")
            return value;
        if (value === "tight")
            return Theme.current.spacingTight;
        if (value === "medium")
            return Theme.current.spacingBase;
        if (value === "loose")
            return Theme.current.spacingLoose;
        return 0;
    }

    /// host 的直接子项，跳过 Qt 6.11 起「自己也是个 Item」的 Repeater 空壳
    function nodes() {
        const out = [];
        for (let i = 0; i < host.children.length; ++i) {
            const node = host.children[i];
            if (node === null || node === undefined || node instanceof Repeater)
                continue;
            out.push(node);
        }
        return out;
    }

    /// relayout / oneLineWidth 一律走这三个函数，不读上面那几条派生绑定 ——
    /// `onSpacingChanged` 当场读 `control.horizontalGap` 拿到的是**上一拍**的值
    /// （同 Card 的 syncActions 那条），换 spacing 之后排出来的还是旧间距。
    function hGap() {
        return control.gridNow() ? 0 : control.gapAt(control.spacing, 0);
    }

    function vGap() {
        if (control.gridNow())
            return 0;
        return Array.isArray(control.spacing) ? control.gapAt(control.spacing, 1)
            : control.gapAt(control.spacing, 0);
    }

    function ov() {
        return control.gridNow() ? 1 : 0;
    }

    // `isGrid` 也是派生绑定， Changed 处理器里读它同样慢一拍 ⇒ 排版路径直接读 type
    function gridNow() {
        return control.type === "grid";
    }

    function step() {
        return control.hGap() - control.ov();
    }

    /// 「全部塞一行」的 max-content 宽：只读子项自己的宽，不回读 control.width ⇒ 不成环
    function oneLineWidth() {
        const items = control.nodes();
        let end = 0;
        for (let i = 0; i < items.length; ++i)
            end = (i > 0 ? end + control.step() : 0) + items[i].width;
        return end;
    }

    function applyGrid(node) {
        // qmllint disable missing-property
        if (node.cardGroupGrid !== undefined)
            node.cardGroupGrid = control.isGrid;
        // qmllint enable missing-property
    }

    // ------------------------------------------------------------------ flex-wrap 两趟排布
    function relayout() {
        const items = control.nodes();
        for (let i = 0; i < items.length; ++i)
            control.applyGrid(items[i]);
        control.lineStarts = [];
        control.lineHeights = [];
        control.lineExtents = [];
        if (items.length === 0) {
            control.lineWidth = 0;
            control.layoutHeight = 0;
            return;
        }
        // 第一趟分行（flex-wrap：放不下就换行，行首那张永不换），顺手把 x 定下来
        const limit = control.width;
        let lineStart = 0;
        let lineEnd = 0;
        let rowHeight = 0;
        for (let i = 0; i < items.length; ++i) {
            const w = items[i].width;
            const h = items[i].height;
            let left = i > lineStart ? lineEnd + control.step() : 0;
            if (i > lineStart && limit > 0 && left + w > limit) {
                control.lineStarts.push(lineStart);
                control.lineHeights.push(rowHeight);
                control.lineExtents.push(lineEnd);
                lineStart = i;
                rowHeight = 0;
                left = 0;
            }
            items[i].x = left;
            lineEnd = left + w;
            rowHeight = Math.max(rowHeight, h);
        }
        control.lineStarts.push(lineStart);
        control.lineHeights.push(rowHeight);
        control.lineExtents.push(lineEnd);
        // 第二趟行顶逐行累加，行内按 Space 的 align-items: center 居中
        let top = 0;
        let widest = 0;
        for (let li = 0; li < control.lineStarts.length; ++li) {
            if (li > 0)
                top += control.vGap() - control.ov();
            const start = control.lineStarts[li];
            const end = li + 1 < control.lineStarts.length
                ? control.lineStarts[li + 1] : items.length;
            const row = control.lineHeights[li];
            for (let i = start; i < end; ++i)
                items[i].y = top + (row - items[i].height) / 2;
            top += row;
            widest = Math.max(widest, control.lineExtents[li]);
        }
        control.lineWidth = widest;
        control.layoutHeight = top;
    }

    // ------------------------------------------------------------------ 触发重排
    onWidthChanged: control.relayout()
    onSpacingChanged: control.relayout()
    onTypeChanged: control.relayout()
    // 建成时不用特意排一次：声明式子项在 onCompleted 之前就把 childrenChanged 发过了，
    // 那一趟已经挂好监视并排过版（摘掉 onCompleted 这一趟、121 条变异跑完零红 ⇒ 按
    // 「摘掉不红就删」删了）。
    onChildCountChanged: control.refresh()

    function refresh() {
        control.watchNodes();
        control.relayout();
    }

    /// 子项自己长高／变宽时官方靠浏览器重排，端口给每个子项挂一个尺寸监视
    property var nodeWatchers: []

    function watchNodes() {
        const items = control.nodes();
        for (let i = 0; i < items.length; ++i) {
            const old = control.nodeWatchers[i];
            if (old !== undefined && old !== null && old.watched === items[i])
                continue;
            if (old !== undefined && old !== null)
                old.destroy();
            const created = nodeWatcherProto.createObject(control);
            created.watched = items[i];
            control.nodeWatchers[i] = created;
        }
        for (let i = items.length; i < control.nodeWatchers.length; ++i) {
            const stale = control.nodeWatchers[i];
            if (stale !== undefined && stale !== null)
                stale.destroy();
        }
        control.nodeWatchers.length = items.length;
    }

    Item {
        id: host

        objectName: "cardGroupHost"

        width: control.width
        height: control.layoutHeight

        onChildrenChanged: control.childCount = control.nodes().length
    }

    Component {
        id: nodeWatcherProto

        Item {
            id: watcher

            property Item watched: null

            visible: false

            Connections {
                target: watcher.watched

                function onWidthChanged() {
                    control.relayout();
                }

                function onHeightChanged() {
                    control.relayout();
                }
            }
        }
    }
}
