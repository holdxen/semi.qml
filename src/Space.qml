pragma ComponentBehavior: Bound

import QtQuick

// 间距容器。官方 SpaceProps（semi-ui/space/index.tsx:15-43 + space.scss +
// 编译产物 semi.css:20283-20324 逐条对）。
//
//     Space { Button {} Button {} }                      // 水平、行内居中、tight(8px)
//     Space { vertical: true; spacing: 16 }              // 垂直、列内居中、16
//     Space { align: "start"; wrap: true; width: 400 }   // 顶对齐、按可用宽换行
//     Space { spacing: [8, 16] }                         // [水平列距, 垂直行距]
//
// 官方 5 条 prop 全收（style / className 是 DOM 侧无落点）：
//   · `vertical` 缺省 false（flex-direction: row）、`wrap` 缺省 false（nowrap）；
//     index.tsx:57 的 `wrap && vertical ⇒ wrap=false`（垂直档不吃换行）照抄
//   · `align` 缺省 "center"（align-items，四档 start/center/end/baseline）：
//     水平档管**行内纵向**（start 顶 / center 中 / end 底 / baseline 按子项基线），
//     垂直档管**列内横向**（start 左 / center 中 / end 右）——
//     垂直档的 baseline 与跨轴平行、无从对齐，按 start 落（官方没有这个组合的 demo）
//   · `spacing` 缺省 "tight"：string 三档 8 / 16 / 24（semi.css:20307-20324 实值）、
//     number 两轴同值（index.tsx:62-64 的 rowGap/columnGap）、[水平, 垂直] 数组档分开吃；
//     **认不出的串与数组缺格 = 0** —— 官方「类名不命中 ⇒ gap 压根没设」（:66-77，
//     浏览器缺省 gap normal = 0）；`spacing: undefined` ⇒ React defaultProps 补 'tight'，
//     `null` ⇒ 三支判据都不命中 ⇒ 0
//   · children 走默认属性槽（官方 flatten 的等价：QML 的 data 名单本就扁平）
//
// 排版是两趟手工排布（同 CardGroup）：QML 的 Row / Column 不换行也不认 align，
// Flow 只有一个 `spacing` 撑不住 `[水平, 垂直]` 两档（PROGRESS 卡片组那条取舍同源）。
//   · 换行以 `width` 为可用宽；未显式给宽时隐式宽 = 「全塞一行」的 max-content ⇒ 不换行
//     （官方 inline-flex 的可用宽来自父级，端口不回读父宽 —— 位置器场景回读会成环，见坑 125；
//      要换行就给宽：`Space { wrap: true; width: parent.width }`）
//   · `visible: false` 的子项不入排（同 Row/Column 与官方 display:none 口径）；
//     Repeater 空壳跳过（Qt 6.11 起 Repeater 是个 Item，官方 flatten 里没有对应节点）
//   · baseline：先找子项**后代第一个可见 Text**（mapToItem + Qt 自动维护的
//     baselineOffset，qquicktext.cpp:421，即浏览器「首行文本基线」的落法），
//     找不到再看子项自己的 baselineOffset（缺省 0）。基线的重排节拍是**只在
//     baseline 档跑的 FrameAnimation**：Qt 这边没有可靠的变更信号兜住
//     「Text 排完版才写 baselineOffset、中间层挪位、后补 Text」这些时序
//     （childrenRect 追踪要第一次读才建、而且只扩不缩 —— qquickitem.cpp:3867
//      + QQuickContents::calcHeight），每帧刷一遍幂等重排是唯一稳的。
//   · 未知 align 值官方类名不命中 ⇒ 浏览器按 stretch 拉伸，端口按 start 落 ——
//     QML 分不清「没设高」，强拉会吃掉调用方的显式 height。
//   · 官方给容器显式 height 时单行会按 align-content 拉到容器高，端口不跟
//     （官方 demo 全是 auto 高，没有这个组合）。
Item {
    id: control

    /// 官方 wrap（缺省 false；垂直档禁用 —— index.tsx:57 的 isWrap 三元）
    property bool wrap: false
    /// 官方 align（缺省 center；四档 start/center/end/baseline）
    property string align: "center"
    /// 官方 vertical（缺省 false ⇒ 水平 row）
    property bool vertical: false
    /// 官方 spacing（缺省 "tight"）：string 三档 | number | [水平, 垂直]
    property var spacing: "tight"

    /// 既有调用点的别名（`space: 8` 语义等于官方 number 档）
    property alias space: control.spacing

    default property alias content: control.data

    /// 官方 isWrap：`wrap && vertical ? false : wrap`（垂直档不吃换行）
    readonly property bool effectiveWrap: control.vertical ? false : control.wrap

    /// 间距令牌（variables.scss → 编译产物 semi.css:20307-20324 = 8 / 16 / 24）
    readonly property real tightValue: Theme.current.spacingTight    // 8
    readonly property real mediumValue: Theme.current.spacingBase    // 16
    readonly property real looseValue: Theme.current.spacingLoose    // 24

    /// 派生读数（对外 / 用例读）；排版路径一律走 gapOf 直读 spacing，
    /// 同周期 Changed 处理器里读这两条派生绑定拿到的是上一拍的值
    readonly property real horizontalGap: control.gapOf(control.spacing, 0)
    readonly property real verticalGap: control.gapOf(control.spacing, 1)

    /// relayout 写出的行首下标（如 [0, 3, 7]；垂直档恒空数组 —— 换行是水平档概念）
    property var lineStarts: []
    /// 行盒总高（relayout 写；implicitHeight 绑它）
    property real layoutHeight: 0

    implicitWidth: control.vertical ? control.maxCrossWidth() : control.oneLineWidth()
    implicitHeight: control.layoutHeight

    function gapOf(spec, index) {
        // index 0 = 水平列距、1 = 垂直行距
        if (spec === undefined)
            return control.tightValue;    // React defaultProps 只补 undefined ⇒ 'tight'
        if (spec === null)
            return 0;                     // 三支判据都不命中 ⇒ 没有 gap 规则
        if (typeof spec === "number")
            return spec;                  // rowGap / columnGap 同值（index.tsx:62-64）
        if (typeof spec === "string")
            return control.tokenOf(spec);
        if (Array.isArray(spec)) {
            const part = spec.length > index ? spec[index] : undefined;
            if (typeof part === "number")
                return part;
            if (typeof part === "string")
                return control.tokenOf(part);
            return 0;                     // 缺格 / 脏值 ⇒ 该轴没有 gap 规则
        }
        return 0;
    }

    function tokenOf(name) {
        if (name === "tight")
            return control.tightValue;
        if (name === "medium")
            return control.mediumValue;
        if (name === "loose")
            return control.looseValue;
        return 0;    // 类名不命中 ⇒ 没设 gap（index.tsx:66-77 只在三档命中时挂类）
    }

    /// 「全部塞一行」的 max-content 宽：只读子项自己的宽，不回读 control.width ⇒ 不成环
    function oneLineWidth() {
        const items = control.nodes();
        const gap = control.gapOf(control.spacing, 0);
        let end = 0;
        for (let i = 0; i < items.length; ++i)
            end = (i > 0 ? end + gap : 0) + items[i].width;
        return end;
    }

    /// 垂直档的跨轴（宽）＝ 最宽子项（官方 column 的 shrink-to-fit 内容宽）
    function maxCrossWidth() {
        const items = control.nodes();
        let widest = 0;
        for (let i = 0; i < items.length; ++i)
            widest = Math.max(widest, items[i].width);
        return widest;
    }

    /// 直接子项里参与排布的：跳过 Repeater 空壳与不可见（display:none 口径）
    function nodes() {
        const out = [];
        const kids = control.children;
        for (let i = 0; i < kids.length; ++i) {
            const node = kids[i];
            if (node === null || node === undefined)
                continue;
            if (node instanceof Repeater)
                continue;
            if (node.visible === false)
                continue;
            out.push(node);
        }
        return out;
    }

    /// 后代里第一个可见 Text（浏览器基线取首行文本；找不到回落子项自己的基线声明）
    function firstText(node) {
        const kids = node.children;
        for (let i = 0; i < kids.length; ++i) {
            const k = kids[i];
            if (k === null || k === undefined || k.visible === false)
                continue;
            if (k instanceof Text)
                return k;
            const deep = control.firstText(k);
            if (deep !== null)
                return deep;
        }
        return null;
    }

    /// 子项基线（相对子项自身坐标）：Text 的 baselineOffset 由 Qt 自动维护
    function baselineOf(item) {
        const t = control.firstText(item);
        if (t !== null)
            return t.mapToItem(item, 0, 0).y + t.baselineOffset;
        return item.baselineOffset;
    }

    function alignOffset(cross, size, align) {
        if (align === "center")
            return (cross - size) / 2;
        if (align === "end")
            return cross - size;
        return 0;    // start 与未知值（未知档的端口取舍见文件头）
    }

    // ---------------------------------------------------------------- 两趟排布
    function relayout() {
        const items = control.nodes();
        if (control.vertical) {
            control.lineStarts = [];
            const gap = control.gapOf(control.spacing, 1);
            const cross = control.width;    // 未给宽时 = 最宽子项（上游只读子项 ⇒ 不成环）
            let y = 0;
            for (let i = 0; i < items.length; ++i) {
                const it = items[i];
                it.y = y;
                // 垂直档 baseline 与跨轴平行、无从对齐 ⇒ start
                it.x = control.alignOffset(cross, it.width, control.align);
                y += it.height + gap;
            }
            control.layoutHeight = items.length > 0 ? y - gap : 0;
            return;
        }
        // 第一趟：分行（flex-wrap：放不下就换行，行首项永不换）顺手定 x
        const hgap = control.gapOf(control.spacing, 0);
        const vgap = control.gapOf(control.spacing, 1);
        const limit = control.width;    // 未给宽时 = 全塞一行的 max-content ⇒ 永不换行
        const starts = [];
        const heights = [];
        let lineStart = 0;
        let lineEnd = 0;
        let rowHeight = 0;
        for (let i = 0; i < items.length; ++i) {
            const w = items[i].width;
            let left = i > lineStart ? lineEnd + hgap : 0;
            if (control.wrap && i > lineStart && left + w > limit) {
                starts.push(lineStart);
                heights.push(rowHeight);
                lineStart = i;
                rowHeight = 0;
                left = 0;
            }
            items[i].x = left;
            lineEnd = left + w;
            rowHeight = Math.max(rowHeight, items[i].height);
        }
        if (items.length > 0) {
            starts.push(lineStart);
            heights.push(rowHeight);
        }
        control.lineStarts = starts;
        // 第二趟：行顶逐行累加，行内按 align 定 y（baseline 档先算基线再摆）
        const alignNow = control.align;
        let top = 0;
        for (let li = 0; li < starts.length; ++li) {
            if (li > 0)
                top += vgap;
            const start = starts[li];
            const end = li + 1 < starts.length ? starts[li + 1] : items.length;
            let lineH = heights[li];
            if (alignNow === "baseline") {
                const bs = [];
                let maxB = 0;
                let maxDescent = 0;
                for (let i = start; i < end; ++i) {
                    const b = control.baselineOf(items[i]);
                    bs.push(b);
                    maxB = Math.max(maxB, b);
                    maxDescent = Math.max(maxDescent, items[i].height - b);
                }
                lineH = maxB + maxDescent;
                for (let i = start; i < end; ++i)
                    items[i].y = top + (maxB - bs[i - start]);
            } else {
                for (let i = start; i < end; ++i)
                    items[i].y = top + control.alignOffset(lineH, items[i].height, alignNow);
            }
            top += lineH;
        }
        control.layoutHeight = starts.length > 0 ? top : 0;
    }

    // baseline 档的重排节拍：Qt 这边没有信号能兜住「Text 排完版才写 baselineOffset /
    // 中间层挪位 / 后补 Text」这些时序（见文件头），只在 baseline 档每帧幂等刷一遍。
    // relayout 值没变就一个信号都不发 ⇒ 非 baseline 档这台不跑，零开销。
    FrameAnimation {
        running: control.align === "baseline" && !control.vertical

        onTriggered: control.relayout()
    }

    // -------------------------------------------------------------- 触发重排
    onWidthChanged: control.relayout()
    onVerticalChanged: control.relayout()
    onWrapChanged: control.relayout()
    onAlignChanged: control.relayout()
    onSpacingChanged: control.relayout()
    onChildrenChanged: control.refresh()

    function refresh() {
        control.watchNodes();
        control.relayout();
    }

    /// 子项自己长宽／显隐变化时官方靠浏览器重排，端口给每个子项挂一个尺寸监视。
    /// 监视名单收**全部**子项（含不可见的）—— 隐藏子项将来变可见时要有人喊重排。
    property var nodeWatchers: []

    function watchList() {
        const out = [];
        const kids = control.children;
        for (let i = 0; i < kids.length; ++i) {
            const node = kids[i];
            if (node === null || node === undefined || node instanceof Repeater)
                continue;
            out.push(node);
        }
        return out;
    }

    function watchNodes() {
        const items = control.watchList();
        for (let i = 0; i < items.length; ++i) {
            const old = control.nodeWatchers[i];
            if (old !== undefined && old !== null && old.watched === items[i])
                continue;
            if (old !== undefined && old !== null)
                old.destroy();
            const created = nodeWatcherProto.createObject(null);
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

                function onVisibleChanged() {
                    control.relayout();
                }
            }
        }
    }
}
