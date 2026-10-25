pragma ComponentBehavior: Bound

import QtQuick

// 描述列表。官方 `packages/semi-ui/descriptions/{index.tsx,item.tsx}` +
// `semi-foundation/descriptions/{foundation.ts,descriptions.scss,variables.scss,constants.ts}`。
//
//     // data 档
//     Descriptions {
//         data: [{ key: "实际用户数量", value: "1,480,000" },
//                { key: "垂类标签", value: tagComponent }]
//     }
//
//     // 子项档（官方 Descriptions.Item）
//     Descriptions {
//         DescriptionsItem { itemKey: "安全等级"; Text { text: "3级" } }
//     }
//
// ------------------------------------------------------------------ 官方 DescriptionsProps
// 逐条对着 index.tsx:23-33（接口）与 :61-68（defaultProps）：
//   · `align` 缺省 **center**，四档 left / justify / plain / center（constants.ts:8）；
//     `row` 缺省 false；`size` 缺省 medium（只在 row 下有意义）；`data` 缺省 **空数组**；
//     `layout` 缺省 **vertical**；`column` 缺省 3。
//   · **`column` 与 `span` 只在 `layout: 'horizontal'` 那一路被读到** —— vertical 档走
//     `renderChildrenList()` 的 else 分支（:108-114），一个条目一个 `<tr>`，压根不看 column。
//     所以官方缺省形态是「一行一组、上下排开」，要多列得显式给 `layout: 'horizontal'`。
//   · `data` 与子项同时给时 data 赢（`getColumns()` :80-93 先判 data?.length）；
//     vertical 档更直接：data 非空就 map data，否则把 children 原样塞进 tbody。
//   · data 里不是 plain object 的那一项渲染成 null（:111 的 `isPlainObject`）；
//     子项档里不是元素的那一项在 horizontal 下也变 null（:86-89 给了个 `[]`）。
//
// ------------------------------------------------------------------ 分组算法（foundation.getHorizontalList :12-42）
//   · 先按 `!hidden` 过一遍；然后累加 `span || 1`，**累到 >= column 才断行** ——
//     断点是「加上当前这条之后」，所以一条 span=3 排在 column=5 的行尾时，那一行总 span 是 6。
//   · 最后那截残行如果**末项没给 span**（`isNaN(lastSpan.span)`），把末项 span 改成
//     `column - 已占 + 1` 补满；末项显式给了 span（含给 0）就不补 ⇒ 末行可以短一截。
//   · 官方这一改是**直接写进使用方传进来的那个 data 对象**（`lastSpan.span = …`）。
//     端口只改自己那份 entry，不碰使用方的数组（差异记在坑 113）。
//
// ------------------------------------------------------------------ 皮肤（descriptions.scss）
// `.semi-descriptions` 是 `line-height: 20` 的一层 div，里面一个 `<table>`：
//   · 普通档（`row: false`）：`th` 右内边距 24（$spacing-loose）、`-item` 下内边距 12
//     （$spacing-base-tight）、key 色 text-2、value 色 text-0、key nowrap。
//   · 四档 align 只差 th / td 的 text-align（center⇒th 右 td 左、left⇒都左、justify⇒th 左 td 右），
//     plain 档则是**换 DOM**：一个 td 里 `-key` 带冒号 + `-value` 左内边距 8。
//   · 双行档（`row: true`）：tbody 变 flex + wrap、tr 变 inline-flex column ⇒ 条目横着排、
//     一行放得下几条排几条；`-item` 的 padding 被重赋成 **0**（$…item_double-padding: 0），
//     于是那 12 的行距没了，改吃 item 右内边距 48 / 60 / 80 与 key 的 padding-bottom 0 / 4 / 4；
//     value 字重 600、字号 16 / 20 / 28。**align 那四条对齐规则整块不套**（:120 那个类名带 `!row`），
//     但 `align: 'plain'` 仍然换 DOM ⇒ 双行 + plain 是「key: value 挤在同一行、中间不留 8」。
//   · horizontal 档另有 `table { table-layout: fixed }` + `width: 100%`（:155-162）。
//
// ------------------------------------------------------------------ 与官方的差异（QML 侧没有 table）
//   · 列宽按「槽数」算：`gridUnits = 各行里最大的 Σspan`，条目宽 = `span / gridUnits × 容器宽`；
//     align≠plain 时 th 那一格恒占 `1 / (2 × gridUnits)`（CSS fixed layout 就是这个等分结果）。
//     行总 span 超出 column 时（那条 `>=` 断行造成的）该行会画到容器外，与浏览器多出一列同源，
//     端口不额外夹。
//   · vertical 档的 th 列宽取「所有可见条目里最宽的那把 key + 24」（CSS auto table 的结果）；
//     没给宽时整块按内容收缩（implicitWidth = th 列 + 最宽 value）。
//   · `-key { white-space: nowrap }` 端口同样不换行，但宽度不够时截尾省略号（浏览器是直接溢出）。
//   · **官方那条 `data` 在 QML 里占不了** —— `Item.data` 是子项列表（默认属性），端口声明同名
//     属性并不会盖住它（实测 `d.data` 拿到的还是那条链表，`JSON.stringify` 直接 circular）。
//     所以这一档改叫 `dataList`，形状与官方 `Data[]` 一致
//     （`{ key, value, hidden, span, keyStyle }`）；与 Empty 那轮 `children`→`footer` 同一口径。
//   · `style` / `className` 官方写在外层 div 上，端口收了不产出可见差异；`keyStyle` 的落地范围
//     见 src/DescriptionsItem.qml 文件头；`getDataAttr(rest)`（data-* 透传）与 React 的 key /
//     fragment 那一族不落 QML。
Item {
    id: control

    // ---- 官方 DescriptionsProps（index.tsx:23-33、defaultProps :61-68）----
    property string align: "center"
    property bool row: false
    property string size: "medium"
    property var style: undefined
    property string className: ""
    property var dataList: []
    property string layout: "vertical"
    property int column: 3

    /// 排完版之后的总高
    property real contentHeight: 0

    implicitWidth: control.row ? control.doubleNaturalWidth : control.naturalWidth
    implicitHeight: control.contentHeight

    /// 双行档的整块自然宽：tbody 是 flex，shrink-to-fit 出来的就是「全排成一行」的总宽
    readonly property real doubleNaturalWidth: {
        let w = 0;
        for (let i = 0; i < control.entries.length; ++i) {
            const e = control.entries[i];
            if (e.hidden)
                continue;
            w += Math.max(e.keyNatural, e.valueNatural) + control.doubleGap;
        }
        return w;
    }

    // ---- 令牌 ----
    /// 普通档 th 的右内边距（$spacing-descriptions_th-paddingRight = $spacing-loose）
    readonly property real thPaddingRight: Theme.current.spacingLoose
    /// 双行档 item 的右内边距（48 / 60 / 80）
    readonly property real doubleGap: control.size === "small" ? 48
        : (control.size === "large" ? 80 : 60)
    /// 普通档 `-item` 的下内边距（双行档被 -double 重赋成 0）
    readonly property real itemPaddingBottom: Theme.current.spacingBaseTight

    // ---- 名单 ----
    /// [{ item, units, spanGiven, hidden, keyNatural, valueNatural }]，普通数组、没有 NOTIFY
    property var entries: []
    readonly property bool useData: control.dataList !== undefined && control.dataList !== null
        && control.dataList.length > 0

    function isPlainEntry(v) {
        return v !== undefined && v !== null && typeof v === "object" && !Array.isArray(v);
    }

    /// data 非空时子项整条不读（官方 getColumns 先判 data）
    readonly property bool plainMode: control.align === "plain"

    // ---- 收集 ----
    function collect() {
        const out = [];
        if (control.useData) {
            for (let i = 0; i < dataRepeater.count; ++i) {
                const it = dataRepeater.itemAt(i);
                if (it === null || !control.isPlainEntry(control.dataList[i]))
                    continue;
                out.push(control.entryFor(it));
            }
        } else {
            for (let i = 0; i < control.children.length; ++i) {
                const k = control.children[i];
                if (k.isDescriptionsItem !== true || k.fromRepeater === true)
                    continue;
                k.descriptionsHost = control;
                out.push(control.entryFor(k));
            }
        }
        // data 非空时子项整条不读（官方 getColumns :80-84 先判 data?.length）⇒ 不显示、不收养
        for (let i = 0; i < control.children.length; ++i) {
            const k = control.children[i];
            if (k.isDescriptionsItem !== true || k.fromRepeater === true)
                continue;
            if (control.useData) {
                k.descriptionsHost = null;
                k.visible = false;
            }
        }
        control.entries = out;
        control.measure();
    }

    function entryFor(item) {
        for (let i = 0; i < control.entries.length; ++i)
            if (control.entries[i].item === item)
                return control.entries[i];
        return { item: item, units: item.span || 1, spanGiven: item.spanExplicit,
            hidden: item.hidden, keyNatural: item.keyNaturalWidth,
            valueNatural: item.valueNaturalWidth };
    }

    function measure() {
        for (let i = 0; i < control.entries.length; ++i) {
            const e = control.entries[i];
            e.keyNatural = e.item.keyNaturalWidth;
            e.valueNatural = e.item.valueNaturalWidth;
            e.hidden = e.item.hidden;
            e.units = e.item.span || 1;
            e.spanGiven = e.item.spanExplicit;
            // 官方是 `if (hidden) return null`（item.tsx:38）—— 不渲染。端口留着实例，
            // 但既不显示也不参与排版，两条口径一致。
            e.item.visible = !e.hidden;
        }
    }

    /// 条目自身的自然宽是异步到位的（Component 档等 Loader、子项档等 Row 排布），回敲这条
    function itemNaturalChanged() {
        control.measure();
        control.relayout();
    }

    function refresh() {
        control.collect();
        control.relayout();
    }

    // ---- 分组 ----
    function visibleEntries() {
        const out = [];
        for (let i = 0; i < control.entries.length; ++i)
            if (!control.entries[i].hidden)
                out.push(control.entries[i]);
        return out;
    }

    /// getHorizontalList 的端口版：累到 >= column 断行；残行末项没给 span 才补满
    function horizontalRows() {
        const list = control.visibleEntries();
        const rows = [];
        let total = 0;
        let cur = [];
        for (let i = 0; i < list.length; ++i) {
            const e = list[i];
            total += e.units;
            cur.push(e);
            if (total >= control.column) {
                rows.push(cur);
                cur = [];
                total = 0;
            }
        }
        if (cur.length !== 0) {
            const last = cur[cur.length - 1];
            if (!last.spanGiven) {
                let t = 0;
                for (let j = 0; j < cur.length; ++j)
                    t += cur[j].units;
                if (t < control.column)
                    last.units = control.column - t + 1;
            }
            rows.push(cur);
        }
        return rows;
    }

    /// 双行档：tbody 是 flex + wrap ⇒ 按「自然宽 + 那条右内边距」往容器里塞，塞不下另起一行
    function doubleRows() {
        const list = control.visibleEntries();
        const rows = [];
        let cur = [];
        let used = 0;
        for (let i = 0; i < list.length; ++i) {
            const need = Math.max(list[i].keyNatural, list[i].valueNatural) + control.doubleGap;
            if (cur.length !== 0 && used + need > control.width) {
                rows.push(cur);
                cur = [];
                used = 0;
            }
            cur.push(list[i]);
            used += need;
        }
        if (cur.length !== 0)
            rows.push(cur);
        return rows;
    }

    function rowsNow() {
        if (control.row)
            return control.doubleRows();
        const list = control.visibleEntries();
        if (control.layout === "horizontal")
            return control.horizontalRows();
        const rows = [];
        for (let i = 0; i < list.length; ++i)
            rows.push([list[i]]);
        return rows;
    }

    /// 槽数：CSS fixed layout 的列数 = 各行里最大的 Σspan
    function gridUnitsOf(rows) {
        let g = 1;
        for (let r = 0; r < rows.length; ++r) {
            let s = 0;
            for (let i = 0; i < rows[r].length; ++i)
                s += rows[r][i].units;
            g = Math.max(g, s);
        }
        return g;
    }

    /// vertical 档那一列 th 的宽：所有可见条目里最宽的 key + 24（auto table 的结果）
    function thColumnOf(list) {
        let w = 0;
        for (let i = 0; i < list.length; ++i)
            w = Math.max(w, list[i].keyNatural + control.thPaddingRight);
        return w;
    }

    // ---- 排版 ----
    function relayout() {
        // 直接读 align，不走那条 `plainMode` 派生绑定 —— Changed 处理器与绑定同周期时
        // 下游绑定还没重算，读到的会是上一拍的值（本项目老坑，Cropper 那轮也踩过一次）
        const plain = control.align === "plain";
        const rows = control.rowsNow();
        const grid = control.layout === "horizontal" && !control.row
            ? control.gridUnitsOf(rows) : 1;
        const thCol = !control.row && !plain && control.layout !== "horizontal"
            ? control.thColumnOf(control.visibleEntries()) : 0;
        const total = control.width;
        let y = 0;

        for (let r = 0; r < rows.length; ++r) {
            const line = rows[r];
            let rowHeight = 0;
            let offset = 0;
            for (let i = 0; i < line.length; ++i) {
                const e = line[i];
                const it = e.item;
                let cell = total;
                let x = 0;
                let th = thCol;
                if (control.row) {
                    cell = line.length > 0 ? total / line.length : total;
                    x = cell * i;
                    th = 0;
                } else if (control.layout === "horizontal") {
                    cell = total * e.units / grid;
                    x = offset;
                    th = plain ? 0 : total / (2 * grid);
                }
                offset += cell;
                it.descriptionsHost = control;
                it.hostAlign = control.align;
                it.hostRow = control.row;
                it.hostSize = control.size;
                it.cellWidth = cell;
                it.keyColumnWidth = th;
                it.x = x;
                it.y = y;
                rowHeight = Math.max(rowHeight, it.implicitHeight);
            }
            y += rowHeight;
        }
        control.contentHeight = y;
    }

    /// vertical 档没给宽时整块按内容收缩
    readonly property real naturalWidth: {
        let w = 0;
        const list = control.visibleEntries();
        const th = control.thColumnOf(list);
        for (let i = 0; i < list.length; ++i) {
            // plain 那条 8 只有一份定义：条目自己的 plainGap（宿主这里只拿来算整块收缩宽）
            const body = control.plainMode
                ? list[i].keyNatural + list[i].item.plainGap + list[i].valueNatural
                : th + list[i].valueNatural;
            w = Math.max(w, body);
        }
        return w;
    }

    // ---- data 档的条目实例 ----
    Repeater {
        id: dataRepeater

        model: control.useData ? control.dataList : []

        delegate: DescriptionsItem {
            id: dataItem

            required property var modelData
            required property int index

            fromRepeater: true
            itemKey: dataItem.modelData ? dataItem.modelData.key : undefined
            value: dataItem.modelData ? dataItem.modelData.value : undefined
            hidden: dataItem.modelData ? dataItem.modelData.hidden === true : false
            span: dataItem.modelData && dataItem.modelData.span !== undefined
                && dataItem.modelData.span !== null ? Number(dataItem.modelData.span) : 0
            spanExplicit: dataItem.modelData
                ? dataItem.modelData.span !== undefined && dataItem.modelData.span !== null
                    && !isNaN(Number(dataItem.modelData.span))
                : false
            keyStyle: dataItem.modelData ? dataItem.modelData.keyStyle : undefined
        }
    }

    // ---- 触发 ----
    // 没有 onDataListChanged：换 data 数组必然让 Repeater 增删委托，那一下会走
    // onChildrenChanged → collect()，名单已经重建过了（变异扫描摘掉这条触发零红）。
    onLayoutChanged: control.relayout()
    onAlignChanged: control.relayout()
    onRowChanged: control.relayout()
    // 没有 onSizeChanged：size 只通过条目自己的字号/行高进几何，而那三项一变条目会回敲
    // itemNaturalChanged（measure + relayout）⇒ 这一条触发是冗余的（变异扫描摘掉它零红）。
    onColumnChanged: control.relayout()
    onWidthChanged: control.relayout()
    // 子项档：声明式条目是异步挂上来的，名单要重收一次
    onChildrenChanged: {
        control.collect();
        control.relayout();
    }

    Component.onCompleted: {
        control.collect();
        control.relayout();
    }
}
