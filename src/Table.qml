pragma ComponentBehavior: Bound

import QtQuick
import "TableEngine.js" as Engine

// 数据表格。照 semi-ui/table/{Table,TableCell,TableHeader,TableHeaderRow,ColumnFilter,
// ColumnSorter,CustomExpandIcon,HeadTable,TablePagination}.tsx +
// semi-foundation/table/{foundation,utils}.ts + table/{table,variables,animation}.scss 逐条移植。
//
//     Table {
//         columns: [
//             { title: "标题", dataIndex: "name", width: 400 },
//             { title: "大小", dataIndex: "size", sorter: (a, b) => a.size - b.size }
//         ]
//         dataSource: [{ key: "1", name: "设计文档", size: 34 }]
//     }
//
// 与官方的差异（React / CSS 在 QML 侧无处落地，逐条）：
//   · `style` / `headerStyle` 的其余 CSS 键、`className` / `prefixCls` / `direction`（RTL）
//     / `keepDOM` / `shouldCellUpdate` / `getVirtualizedListRef` / `cached` 都不落 QML：
//     headerStyle 只取 backgroundColor，其余是 DOM 或 React 渲染期的东西。
//   · `components` 只认 `body.row`（整行包装，拖拽排序那一档用的）与 `body.cell`（整格包装）；
//     header 那一层的 wrapper/row/cell 由端口自己的表头网格顶着。
//   · 没有 `hoverable` / `striped` 这类端口自造的开关：官方的整行悬浮就是两层底色，
//     斑马纹是官方 demo 用 `onRow` 的 style.background 做出来的，选择中的行官方本来就没有底色。
//   · 列宽模型：官方交给 <colgroup> + 浏览器自动分配；端口必须自己算，所以没给 width 的列
//     按「剩余宽度平分」（见 TableEngine.js:layoutColumns），`sticky`（表头贴着窗口滚）因此不落地。
//   · `virtualized` 就是 ListView 自己的条目回收，官方 react-window 的 overscanCount 等参数
//     没有对应物；`virtualized.itemSize` 缺省取本尺寸的 53/45/37（constants.ts 那三个量），
//     而不是文档表里写的 56 —— 那是官方文档自己没跟上。
//   · `renderFilterDropdown` / `filterDropdown` / `renderFilterDropdownItem` 的入参对象照官方给，
//     但节点里的「回填」只能靠调用方自己声明 `property var args`（QML 没有 children 注入）。
//   · `ellipsis` 只落地缩略本身；`showTitle` 那层是浏览器原生 title 提示，QML 没有原生 tooltip，
//     要提示就用官方 demo 自己的路子：`ellipsis:{showTitle:false}` + render 里放 Typography。
//   · 格子恒裁：官方虚拟化那一档的 `-row-cell` 写 `overflow: hidden`（table.scss:393-400），
//     端口表体是 ListView 回收 ⇒ 恒走这一档。没这道裁，`elide: ElideNone` 的 Text 会整行画到邻列
//    （QQuickText 在 NoWrap + ElideNone 下不把自己裁进 width），而邻列那层不透明底色只在悬浮时亮着
//     ⇒ 症状是「默认超出、悬浮那一行才像被裁了」。表头那一格不裁：官方 `-row-head` 只有
//     `overflow-wrap: break-word`，端口靠 `elide: ElideRight` 收住。
//   · `filterDropdownProps` 只取 `position`；Dropdown 的其余透传属性（showTick / trigger /
//     getPopupContainer）没有对应物。
//   · `rowSelection.renderCell` 官方给的 originNode 是那个 Checkbox 元素本身，端口给的是
//     originNode:"checkbox" 这个标记，状态与动作在同一份参数对象里。
Item {
    id: control

    // ============================================================ 官方 TableProps

    property bool bordered: false
    property string childrenRecordName: "children"
    property string className: ""
    property bool clickGroupedRowToExpand: false
    property var columns: []
    property var components: null
    property var dataSource: []
    property bool defaultExpandAllGroupRows: false
    property bool defaultExpandAllRows: false
    property var defaultExpandedRowKeys: []
    property var empty: undefined
    property bool expandAllGroupRows: false
    property bool expandAllRows: false
    property var expandCellFixed: false
    property var expandIcon: undefined
    property var expandedRowKeys: undefined
    property var expandedRowRender: undefined
    property bool expandRowByClick: false
    property var footer: undefined
    property var groupBy: undefined
    property var headerStyle: undefined
    property bool hideExpandedColumn: true
    property int indentSize: 20
    property bool loading: false
    property var pagination: true
    property string prefixCls: "semi-table"
    property var renderGroupSection: undefined
    property var renderPagination: undefined
    property var resizable: false
    property var rowExpandable: undefined
    property var rowKey: "key"
    property var rowSelection: null
    property var scroll: null
    property bool showHeader: true
    property string size: "default"          // "small" | "middle" | "default"
    property var sticky: false
    property var title: undefined
    property var virtualized: false
    property var onRow: undefined
    property var onHeaderRow: undefined
    property var onGroupedRow: undefined

    // JSX 写法：Table 的子项就是列声明；与 columns 同时给时只认 columns，不做聚合。
    default property list<TableColumn> columnNodes

    // 官方回调同名（去掉 on 前缀，QML 里写成 onXxx 就是它）：
    //   onChange(changeInfo)、onExpand(expanded, record, e)、onExpandedRowsChange(expandedRows)
    signal changed(var changeInfo)
    signal expand(bool expanded, var record)
    signal expandedRowsChange(var records)

    // ============================================================ 度量
    // 行高 = 上下内边距 + 20（.semi-table-wrapper 的 font-size-regular 带的 line-height）
    // + 底部 1px 分割线 ⇒ small 37 / middle 45 / default 53，和 constants.ts:65-92 那三个
    // DEFAULT_VIRTUALIZED_ROW_*_HEIGHT 一模一样。表头 8 + 20 + 8 + 2 = 38。

    readonly property real cellPaddingX: Theme.current.spacingBase
    readonly property real cellPaddingY: control.size === "small" ? Theme.current.spacingTight
        : (control.size === "middle" ? Theme.current.spacingBaseTight : Theme.current.spacingBase)
    readonly property real lineHeight: 20
    readonly property real headerPaddingY: Theme.current.spacingTight
    readonly property real headerPaddingX: Theme.current.spacingBase
    readonly property real cellBorder: 1
    readonly property real headerBorder: 2
    readonly property real rowHeight: control.cellPaddingY * 2 + control.lineHeight + control.cellBorder
    readonly property real headerRowHeight: control.headerPaddingY * 2 + control.lineHeight + control.headerBorder
    readonly property real sectionRowHeight: 20 + control.lineHeight + control.cellBorder
    readonly property real controlColumnWidth: 48          // $width-table_column_selection
    readonly property real iconSize: 16
    readonly property real treeIconSize: 12
    readonly property real iconGap: Theme.current.spacingExtraTight
    readonly property real expandIconMargin: 8
    readonly property real borderWidth: control.bordered ? 1 : 0
    readonly property real placeholderHeight: 2 * Theme.current.spacingBase + control.lineHeight
        + control.cellBorder

    // ============================================================ 列结构

    readonly property var userColumns: {
        if (Array.isArray(control.columns) && control.columns.length > 0)
            return control.columns;
        if (control.columnNodes.length > 0)
            return control.columnNodesOf(control.columnNodes);
        return [];
    }

    // 调用方写 rowSelection: ({}) 才是对象；写 {} 会被 QML 当空语句块解析成 undefined，
    // 所以这里统一走一个永不为空的取口，属性读写都从它走。
    readonly property var rs: control.rowSelection !== null && control.rowSelection !== undefined
        ? control.rowSelection : ({})

    readonly property bool expandPresent: control.expandedRowRender !== undefined
        && control.expandedRowRender !== null

    readonly property bool selectionPresent: control.rowSelection !== null
        && control.rowSelection !== undefined && control.rs.hidden !== true

    // 顶层列 = 选择列 + 展开列 + 用户列（官方两次 prepend，选择列最终在最左）。
    readonly property var topColumns: {
        const list = [];
        if (control.selectionPresent)
            list.push(control.selectionColumn());
        if (!control.hideExpandedColumn && control.expandPresent)
            list.push(control.expandColumn());
        const user = control.userColumns;
        for (let i = 0; i < user.length; ++i)
            list.push(user[i]);
        return Engine.assignColumnKeys(list, control.childrenRecordName, 0);
    }

    readonly property var headerGrid: Engine.buildHeaderRows(control.topColumns,
        control.childrenRecordName)
    readonly property var leafColumns: Engine.flattenColumns(control.topColumns,
        control.childrenRecordName)

    // ============================================================ 数据流水线

    // 官方在 init() 里 initQueries 一次，之后 props 变化走 mergeQueries：
    // 调用方点出来的排序/筛选结果得活过 columns 重建（否则表头一点就丢态）。
    property var queries: []

    onLeafColumnsChanged: control.syncQueries()

    function syncQueries() {
        control.queries = Engine.mergeQueries(control.leafColumns, control.queries);
    }

    readonly property var ctx: ({ rowKey: control.rowKey, childrenName: control.childrenRecordName })

    readonly property var filteredSorted: {
        const source = Array.isArray(control.dataSource) ? control.dataSource : [];
        const active = control.queries.filter(control.isActiveFilter);
        const filtered = Engine.filterDataSource(source, active, control.ctx);
        return Engine.sortDataSource(filtered, control.queries, control.ctx);
    }

    readonly property var grouped: Engine.groupDataSource(control.filteredSorted,
        control.groupBy, control.ctx)

    readonly property bool paginationControlled: control.pagination !== false
        && typeof control.pagination === "object" && control.pagination.currentPage !== undefined

    property var innerPagination: ({})

    readonly property var paginationInput: {
        if (control.pagination === false || control.pagination === undefined
            || control.pagination === null)
            return false;
        const base = typeof control.pagination === "object"
            ? Engine.shallowCopy(control.pagination) : {};
        const over = Engine.shallowCopy(control.innerPagination);
        for (const k in over)
            base[k] = over[k];
        return base;
    }

    readonly property var paginationState: Engine.normalizePagination(control.paginationInput,
        control.grouped.dataSource.length, control.paginationControlled)

    readonly property var pageRecords: Engine.limitPageDataSource(control.grouped.dataSource,
        control.paginationState, control.paginationControlled)

    readonly property var pageRowKeys: control.keysOfRecords(control.pageRecords)

    readonly property var disabledRowKeys: control.selectionPresent
        && typeof control.rs.getCheckboxProps === "function"
        ? Engine.allDisabledRowKeys(control.pageRecords, control.rs.getCheckboxProps,
            control.rowKey) : []

    // ============================================================ 展开与选择状态

    property var innerExpandedRowKeys: []
    property var innerSelectedRowKeys: []

    readonly property var expandedKeys: control.expandedRowKeys !== undefined
        && control.expandedRowKeys !== null ? control.expandedRowKeys
        : control.innerExpandedRowKeys

    readonly property bool selectionControlled: control.selectionPresent
        && control.rs.selectedRowKeys !== undefined

    readonly property var selectedRowKeys: control.selectionControlled
        ? control.rs.selectedRowKeys : control.innerSelectedRowKeys

    readonly property bool relatedMode: control.selectionPresent
        && control.rs.checkRelation === "related"

    readonly property var checkedTree: control.relatedMode
        ? Engine.conductCheck(control.pageRecords, control.selectedRowKeys, control.ctx)
        : ({ checked: control.selectedRowKeys, half: [] })

    // ============================================================ 行流

    readonly property var rowStream: Engine.buildRowStream(control.pageRecords,
        control.grouped.groups, {
            rowKey: control.rowKey,
            childrenName: control.childrenRecordName,
            expandedRowKeys: control.expandedKeys,
            expandedRowRenderPresent: control.expandPresent,
            rowExpandable: control.rowExpandable
        })

    readonly property bool isEmpty: control.rowStream.length === 0

    readonly property var itemSizeValue: control.virtualizedItemSize()

    // 展开行的高度由内容决定（官方 td 是 content-driven），量不到就退默认行高。
    property var expandHeights: ({})

    readonly property real contentBodyHeight: {
        if (control.isEmpty)
            return control.placeholderHeight;
        let total = 0;
        for (let i = 0; i < control.rowStream.length; ++i)
            total += control.rowHeightAt(control.rowStream[i]);
        return total;
    }

    readonly property real headerHeight: control.showHeader
        ? control.headerGrid.depth * control.headerRowHeight : 0

    readonly property bool paginationShown: control.paginationState !== null
    readonly property real paginationHeight: 60            // $height-table_pagination_outer_min
    readonly property bool paginationTop: control.paginationShown
        && (control.paginationState.position === "top" || control.paginationState.position === "both")
    readonly property bool paginationBottom: control.paginationShown
        && (control.paginationState.position === undefined
            || control.paginationState.position === "bottom"
            || control.paginationState.position === "both")

    readonly property bool titlePresent: control.title !== undefined && control.title !== null
    readonly property bool footerPresent: control.footer !== undefined && control.footer !== null
    readonly property real titleHeight: control.titlePresent
        ? 2 * Theme.current.spacingBase + control.lineHeight : 0
    readonly property real footerHeight: control.footerPresent
        ? 2 * Theme.current.spacingBase + control.lineHeight : 0

    readonly property real chromeHeight: control.borderWidth * 2 + (control.paginationTop
        ? control.paginationHeight : 0) + control.titleHeight + control.headerHeight
        + control.footerHeight + (control.paginationBottom ? control.paginationHeight : 0)

    // 这两个必须留 var：real 会把 null 静默转成 0，「有没有给 scroll.y」就分不出来了。
    readonly property var scrollY: control.scroll !== undefined && control.scroll !== null
        ? Engine.toPixels(control.scroll.y) : null
    readonly property var scrollX: control.scroll !== undefined && control.scroll !== null
        ? Engine.toPixels(control.scroll.x) : null

    readonly property real viewportWidth: Math.max(0, control.width - control.borderWidth * 2)

    // 官方没有 scroll.y 时表格就是内容多高画多高（.semi-table-body 只有 overflow: auto，
    // 没有 max-height），所以这里不能反过来读 control.height —— 那是 implicitHeight
    // 先算出小值、Item 的 height 跟着回落、body 再被夹成 0 的反馈环。
    readonly property real bodyHeight: control.scrollY !== null
        ? Math.max(0, control.scrollY) : control.contentBodyHeight

    readonly property real layoutWidth: control.scrollX !== null
        ? Math.max(control.scrollX, control.viewportWidth) : control.viewportWidth

    // resizable 拖宽后记在 innerWidths 里（按列 key 存），排在配置宽之前。
    property var innerWidths: ({})

    readonly property var columnWidths: {
        const list = Engine.layoutColumns(control.leafColumns, control.layoutWidth);
        for (let i = 0; i < control.leafColumns.length; ++i) {
            const key = String(control.leafColumns[i].key);
            if (control.innerWidths[key] !== undefined)
                list[i] = control.innerWidths[key];
        }
        return list;
    }

    readonly property var columnXs: {
        const xs = [];
        let acc = 0;
        for (let i = 0; i < control.columnWidths.length; ++i) {
            xs.push(acc);
            acc += control.columnWidths[i];
        }
        return xs;
    }

    readonly property real contentWidth: {
        let total = 0;
        for (let i = 0; i < control.columnWidths.length; ++i)
            total += control.columnWidths[i];
        return Math.max(total, control.viewportWidth);
    }

    readonly property var fixedInfo: control.computeFixed()
    readonly property bool scrolledFromLeft: viewport.contentX > 0.5
    readonly property bool scrolledFromRight: viewport.contentX < control.contentWidth
        - control.viewportWidth - 0.5

    readonly property real sorterBlockWidth: control.iconSize
    readonly property real filterBlockWidth: control.iconGap + control.iconSize

    implicitWidth: 600
    implicitHeight: control.chromeHeight + control.bodyHeight

    // ============================================================ 列结构函数

    function columnNodesOf(nodes) {
        const out = [];
        for (let i = 0; i < nodes.length; ++i)
            out.push(control.columnObjectOf(nodes[i]));
        return out;
    }

    function columnObjectOf(n) {
        const col = {};
        const keys = ["title", "dataIndex", "width", "align", "fixed", "ellipsis", "render",
            "sorter", "sortOrder", "defaultSortOrder", "filters", "onFilter", "filteredValue",
            "defaultFilteredValue", "filterMultiple", "filterConfirmMode", "renderFilterDropdown",
            "renderFilterDropdownItem", "filterDropdown", "filterDropdownProps",
            "filterDropdownVisible", "filterIcon", "sortIcon", "onCell", "onHeaderCell",
            "colSpan", "rowSpan", "className", "resize", "showSortTip", "useFullRender",
            "filterChildrenRecord", "sortChildrenRecord"];
        for (let k = 0; k < keys.length; ++k) {
            const name = keys[k];
            if (n[name] !== undefined)
                col[name] = n[name];
        }
        if (n.columnKey !== undefined)
            col.key = n.columnKey;
        if (n.subColumns.length > 0)
            col[control.childrenRecordName] = control.columnNodesOf(n.subColumns);
        return col;
    }

    // 官方 normalizeSelectionColumn（Table.tsx:1115-1133）：把 rowSelection 上的键
    // 原样铺到这一列上（只挖掉 selectedRowKeys / selectedRowKeysSet），然后 title 与 render
    // 由组件内部接管 —— 也就是 rowSelection.width/fixed/onCell/onHeaderCell/className 都当列属性用。
    function selectionColumn() {
        const rs = control.rs;
        const col = Engine.shallowCopy(rs);
        col.key = Engine.KEY_SELECTION;
        delete col.selectedRowKeys;
        delete col.renderCell;
        delete col.onSelect;
        delete col.onSelectAll;
        delete col.onChange;
        delete col.getCheckboxProps;
        delete col.checkRelation;
        delete col.clickRow;
        delete col.hidden;
        // 官方在这一列上把 title 覆盖成「全选框」，所以 rowSelection.title 其实不渲染。
        delete col.title;
        // 选择列与展开列的 48 是 CSS 给的（$width-table_column_selection），
        // 端口把它落到列宽上，rowSelection.width 传了才覆盖。
        col.width = rs.width !== undefined ? rs.width : control.controlColumnWidth;
        if (rs.fixed !== undefined && rs.fixed !== false)
            col.fixed = rs.fixed === true ? "left" : rs.fixed;
        return col;
    }

    function expandColumn() {
        const col = { key: Engine.KEY_EXPAND };
        col.width = control.controlColumnWidth;
        if (control.expandCellFixed !== undefined && control.expandCellFixed !== false)
            col.fixed = control.expandCellFixed === true ? "left" : control.expandCellFixed;
        return col;
    }

    function isDataColumn(col) {
        return !control.isSelectionCell(col) && !control.isExpandCell(col);
    }

    function isSelectionCell(col) {
        return col !== undefined && col.key === Engine.KEY_SELECTION;
    }

    function isExpandCell(col) {
        return col !== undefined && col.key === Engine.KEY_EXPAND;
    }

    function isActiveFilter(query) {
        const values = Array.isArray(query.filteredValue) ? query.filteredValue
            : (Array.isArray(query.defaultFilteredValue) ? query.defaultFilteredValue : []);
        return typeof query.onFilter === "function" && values.length > 0;
    }

    function keysOfRecords(records) {
        const out = [];
        if (!Array.isArray(records))
            return out;
        for (let i = 0; i < records.length; ++i) {
            out.push(Engine.recordKey(records[i], control.rowKey));
            const kids = Engine.recordChildren(records[i], control.childrenRecordName);
            for (let k = 0; k < kids.length; ++k)
                out.push(Engine.recordKey(kids[k], control.rowKey));
        }
        return out;
    }

    // ============================================================ 行高

    function virtualizedItemSize() {
        if (control.virtualized === false || control.virtualized === undefined
            || control.virtualized === null)
            return null;
        if (typeof control.virtualized === "object" && control.virtualized.itemSize !== undefined)
            return control.virtualized.itemSize;
        return control.rowHeight;
    }

    function rowHeightAt(row) {
        if (control.itemSizeValue !== null) {
            if (typeof control.itemSizeValue === "function") {
                return control.itemSizeValue(row.seq, {
                    sectionRow: row.kind === "section",
                    expandedRow: row.kind === "expand"
                });
            }
            return control.itemSizeValue;
        }
        if (row.kind === "section")
            return control.sectionRowHeight;
        if (row.kind === "expand")
            return control.expandHeightOf(row);
        return control.rowHeight;
    }

    function expandHeightOf(row) {
        const h = control.expandHeights[String(row.seq)];
        if (h === undefined || h <= 0)
            return control.rowHeight;
        return h + 2 * control.cellPaddingY + control.cellBorder;
    }

    function setExpandHeight(seq, value) {
        if (value <= 0)
            return;
        const map = Engine.shallowCopy(control.expandHeights);
        if (map[String(seq)] === value)
            return;
        map[String(seq)] = value;
        control.expandHeights = map;
    }

    // ============================================================ 横向布局

    function fixedOf(col) {
        if (col === undefined || col === null || col.fixed === undefined || col.fixed === false)
            return "";
        if (col.fixed === true)
            return "left";
        return String(col.fixed);
    }

    function computeFixed() {
        const res = { leftLast: -1, rightFirst: -1 };
        const cols = control.leafColumns;
        for (let j = 0; j < cols.length; ++j) {
            if (control.fixedOf(cols[j]) !== "left")
                continue;
            let last = true;
            for (let k = j + 1; k < cols.length; ++k)
                if (control.fixedOf(cols[k]) === "left")
                    last = false;
            if (last)
                res.leftLast = j;
        }
        for (let j = 0; j < cols.length; ++j) {
            if (control.fixedOf(cols[j]) !== "right")
                continue;
            let first = true;
            for (let k = 0; k < j; ++k)
                if (control.fixedOf(cols[k]) === "right")
                    first = false;
            if (first)
                res.rightFirst = j;
        }
        return res;
    }

    function isFixed(index) {
        return control.fixedOf(control.leafColumns[index]) !== "";
    }

    // 表体钉在视口上，所以单元格的 x 就是它在视口里的位置：
    // 跟着滚的自然位要减滚动量，贴左 / 贴右的再按 sticky 夹紧。
    function cellX(index, scrollLeft) {
        const natural = control.columnXs[index] - scrollLeft;
        const kind = control.fixedOf(control.leafColumns[index]);
        if (kind === "left") {
            let acc = 0;
            for (let i = 0; i < index; ++i)
                if (control.fixedOf(control.leafColumns[i]) === "left")
                    acc += control.columnWidths[i];
            return Math.max(natural, acc);
        }
        if (kind === "right") {
            let acc = 0;
            for (let j = index + 1; j < control.leafColumns.length; ++j)
                if (control.fixedOf(control.leafColumns[j]) === "right")
                    acc += control.columnWidths[j];
            return Math.min(natural, control.viewportWidth - control.columnWidths[index] - acc);
        }
        return natural;
    }

    function spanWidthFrom(index, count) {
        let total = 0;
        for (let i = 0; i < count; ++i)
            if (index + i < control.columnWidths.length)
                total += control.columnWidths[index + i];
        return total;
    }

    function spanWidth(cell) {
        return control.spanWidthFrom(cell.leafStart, cell.leafSpan);
    }

    function leftFixedLastAt(index) {
        return control.fixedInfo.leftLast === index;
    }

    function rightFixedFirstAt(index) {
        return control.fixedInfo.rightFirst === index;
    }

    // 一格内容区的横向起点与宽度。官方把缩进与展开按钮都只加在**第一个数据格**上
    // （BaseRow.tsx:237-264），其余列不再跟层级走。
    //   · 可展开的行：缩进 = depth 档，后面再排一颗图标（宽 16 / 树形 12 + 右距 8）；
    //   · 不可展开但同级有可展开行（expandBtnShouldInRow）：缩进多留一档，让文字与兄弟对齐
    //     —— 官方留的是 indentSize（20），不是图标宽（24）；
    //   · expandIcon:false 关掉默认图标 ⇒ 既不画图标也不留位。
    function contentLeft(row, leafIndex, column) {
        let x = control.cellPaddingX;
        // useFullRender 那一格整个交给调用方排版：官方 renderInner 此时只放 text，
        // 缩进与展开按钮都由调用方拿 options 里的标记自己画。
        if (column !== undefined && column !== null && column.useFullRender === true)
            return x;
        if (leafIndex !== control.firstDataLeaf() || row === undefined)
            return x;
        const depth = row.depth !== undefined ? row.depth : 0;
        if (control.drawExpandInRow(row))
            return x + depth * control.indentSize + control.expandIconSide(row)
                + control.expandIconMargin;
        if (control.expandBtnShouldInRow && control.expandIconOn)
            return x + (depth + 1) * control.indentSize;
        return x + depth * control.indentSize;
    }

    function cellContentWidth(width, left) {
        return Math.max(0, width - left - control.cellPaddingX);
    }

    // 官方行/列合并靠 <td rowSpan>；端口按绝对定位画，所以要给「向下占位」的那一行
    // 抬 z，让它压在后面那行的底色之上（被它占住的那一格本来就不渲染）。
    function rowHasSpanDown(row) {
        if (row === undefined || row === null || row.kind !== "data")
            return false;
        const cols = control.leafColumns;
        for (let i = 0; i < cols.length; ++i) {
            const r = control.renderCell(cols[i], row.record, row.index, {});
            if (r.rowSpan > 1)
                return true;
        }
        return false;
    }

    // 官方 resizable：每列必须给 width，column.resize 为 false 的列不参与。
    readonly property bool resizableOn: control.resizable !== false && control.resizable !== undefined
        && control.resizable !== null

    function columnResizable(col) {
        if (!control.resizableOn || !control.isDataColumn(col))
            return false;
        if (col.resize === false)
            return false;
        return Engine.toPixels(col.width) !== null;
    }

    function resizeHook(name, column) {
        if (typeof control.resizable !== "object" || control.resizable === null)
            return null;
        const fn = control.resizable[name];
        return typeof fn === "function" ? fn(column) : null;
    }

    function applyColumnWidth(index, width) {
        if (width <= 0)
            return;
        const map = Engine.shallowCopy(control.innerWidths);
        map[String(control.leafColumns[index].key)] = width;
        control.innerWidths = map;
    }

    function draggingColumn() {
        return control.resizeDragging;
    }

    property var resizeDragging: null
    property real resizeStartWidth: 0

    function firstDataLeaf() {
        for (let i = 0; i < control.leafColumns.length; ++i)
            if (control.isDataColumn(control.leafColumns[i]))
                return i;
        return 0;
    }

    // expandIcon 传 false 是「关掉默认渲染」，官方 TableCell 只在 expandIcon 为真时画它；
    // 没给（undefined/null）走默认图标，给节点/函数也用默认那一格的位子。
    readonly property bool expandIconOn: control.expandIcon === undefined
        || control.expandIcon === null ? true : Boolean(control.expandIcon)

    function drawExpandInRow(row) {
        return control.hideExpandedColumn && control.expandIconOn
            && row !== undefined && row.expandable === true;
    }

    // 官方 expandBtnShouldInRow：决定不可展开的行要不要多留一档缩进。
    readonly property bool expandBtnShouldInRow: Engine.expandBtnShouldInRow(
        control.pageRecords, {
            rowKey: control.rowKey,
            childrenName: control.childrenRecordName,
            expandedRowRenderPresent: control.expandPresent,
            hideExpandedColumn: control.hideExpandedColumn,
            rowExpandable: control.rowExpandable
        })

    // ============================================================ 取值与渲染

    function cellValue(record, column) {
        const dataIndex = column.dataIndex;
        if (dataIndex === undefined || dataIndex === null || dataIndex === "")
            return record;
        return record[dataIndex];
    }

    function plainText(value) {
        if (value === undefined || value === null)
            return "";
        if (typeof value === "object")
            return "";
        return String(value);
    }

    // 官方 render 返回值的三态：文本 / Component / { children, props: { colSpan, rowSpan } }。
    function renderCell(column, record, index, options) {
        const out = {
            text: control.plainText(control.cellValue(record, column)),
            node: null,
            colSpan: 1,
            rowSpan: 1,
            isNode: false
        };
        if (typeof column.render !== "function")
            return out;
        const r = column.render(control.cellValue(record, column), record, index, options);
        if (r instanceof Component) {
            out.isNode = true;
            out.node = r;
        } else if (r !== undefined && r !== null && typeof r === "object" && !Array.isArray(r)
            && r.children !== undefined) {
            if (r.children instanceof Component) {
                out.isNode = true;
                out.node = r.children;
            } else {
                out.text = control.plainText(r.children);
            }
            const props = r.props !== undefined && r.props !== null ? r.props : {};
            if (props.colSpan !== undefined)
                out.colSpan = props.colSpan;
            if (props.rowSpan !== undefined)
                out.rowSpan = props.rowSpan;
        } else {
            out.text = control.plainText(r);
        }
        return out;
    }

    // 传给 render 第 4 个参数 options 的那几个字段（官方 TableCell.tsx:257-274：
    // expandIcon / isHovering 一直给，selection 与 indentText 只在 useFullRender 时给）。
    // 端口把 expandIcon / selection / indentText 做成标记而不是节点：官方能往 options 里塞
    // React 节点，是因为 useFullRender 那一格整个交给调用方排版；QML 没有「把组件内部的
    // 一块 delegate 当子项交给外部」的对应物，所以这里给的是「这一格有没有那个东西」，
    // 外加这一格的状态与两个动作，让调用方能自己把勾选框/展开按钮画出来。
    function renderOptions(row, hovered, column) {
        const fullRender = column !== undefined && column.useFullRender === true;
        const out = {
            expandIcon: control.drawExpandInRow(row)
                && control.firstDataLeaf() === control.leafIndexOf(column) ? "icon" : undefined,
            isHovering: hovered === true
        };
        if (fullRender) {
            const state = control.selectionPresent
                ? control.checkState(row.key) : { checked: false, indeterminate: false };
            out.selection = control.selectionPresent ? "selection" : undefined;
            out.indentText = row.depth > 0 ? "indent" : undefined;
            out.checked = state.checked;
            out.indeterminate = state.indeterminate;
            out.disabled = control.rowDisabled(row.key);
            out.expanded = row.treeExpanded === true || row.rowExpanded === true;
            out.expandable = row.expandable === true;
            out.toggleSelection = function (selected) {
                control.toggleRow(row.key, Boolean(selected));
            };
            out.toggleExpand = function () {
                control.toggleExpand(row.key);
            };
        }
        return out;
    }

    function textAlignOf(align) {
        if (align === "center")
            return Text.AlignHCenter;
        if (align === "right")
            return Text.AlignRight;
        return Text.AlignLeft;
    }

    function ellipsisOn(column) {
        const e = column.ellipsis;
        if (e === undefined || e === null)
            return false;
        if (typeof e === "object")
            return true;
        return Boolean(e);
    }

    // ============================================================ 表头

    function headerCellsAt(rowIndex) {
        return rowIndex < control.headerGrid.rows.length ? control.headerGrid.rows[rowIndex] : [];
    }

    function headerTitleText(column) {
        const t = column.title;
        if (t === undefined || t === null || t instanceof Component)
            return "";
        if (typeof t === "function")
            return control.plainText(t(control.headerTitleArgs(column)));
        return control.plainText(t);
    }

    // 官方 addFnsInColumn（Table.tsx:1198-1294）：title 是函数时收的 titleMap 只有在
    // useFullRender 时才有 sorter / filter / selection 这三项，否则是空对象。
    function headerTitleArgs(column) {
        const args = control.selectionCellArgs(true, undefined, undefined);
        if (column !== undefined && column.useFullRender === true) {
            args.sorter = control.columnSortable(column) ? "sorter" : undefined;
            args.filter = control.columnFilterable(column) ? "filter" : undefined;
            args.selection = control.selectionPresent ? "selection" : undefined;
        }
        return args;
    }

    function headerTitleNode(column) {
        if (column.title instanceof Component)
            return column.title;
        if (typeof column.title === "function") {
            const r = column.title(control.headerTitleArgs(column));
            return r instanceof Component ? r : null;
        }
        return null;
    }

    function columnSortable(column) {
        return control.isDataColumn(column) && column.sorter !== undefined
            && column.sorter !== null && column.sorter !== false;
    }

    function columnFilterable(column) {
        if (!control.isDataColumn(column))
            return false;
        const hasFilters = Array.isArray(column.filters) && column.filters.length > 0;
        return hasFilters || typeof column.renderFilterDropdown === "function"
            || column.filterDropdown instanceof Component;
    }

    function leafIndexOf(column) {
        return control.leafColumns.indexOf(column);
    }

    function queryAt(index) {
        return index >= 0 && index < control.queries.length ? control.queries[index] : null;
    }

    function sortOrderAt(index) {
        const q = control.queryAt(index);
        if (q === null || q.sorter === undefined)
            return false;
        return q.sortOrder;
    }

    function filteredValueAt(index) {
        const q = control.queryAt(index);
        if (q === null)
            return [];
        return Array.isArray(q.filteredValue) ? q.filteredValue : [];
    }

    function isSortControlled(index) {
        const q = control.queryAt(index);
        return q !== null && q.sortOrderControlled;
    }

    function isFilterControlled(index) {
        const q = control.queryAt(index);
        return q !== null && q.filteredValueControlled;
    }

    function titleTailWidth(column) {
        let w = 0;
        if (control.columnSortable(column))
            w += control.sorterBlockWidth + control.iconGap;
        if (control.columnFilterable(column))
            w += control.iconSize + control.iconGap;
        return w;
    }

    // column.sortIcon：官方只接受函数 (props:{sortOrder}) => ReactNode（interface.ts SortIcon），
    // 端口同时收 Component。给了就把默认那对 caretup/caretdown 整个换掉，且提示不再出现。
    function columnSortIcon(column) {
        const s = column.sortIcon;
        if (s === undefined || s === null)
            return null;
        if (s instanceof Component)
            return s;
        if (typeof s === "function") {
            const r = s({ sortOrder: control.sortOrderAt(control.leafIndexOf(column)) });
            return r instanceof Component ? r : null;
        }
        return null;
    }

    // column.filterIcon：boolean | ReactNode | (filtered) => ReactNode。
    function columnFilterIcon(column) {
        const f = column.filterIcon;
        if (f === undefined || f === null || typeof f === "boolean")
            return null;
        if (f instanceof Component)
            return f;
        if (typeof f === "function") {
            const r = f(control.filteredValueAt(control.leafIndexOf(column)).length > 0);
            return r instanceof Component ? r : null;
        }
        return null;
    }

    // showSortTip（Table.tsx:1206-1242 + TableHeaderRow.tsx:232-244）：
    // 只有非受控排序、column.showSortTip===true、且没用自定义 sortIcon 时才有提示；
    // 「这一列只有排序」⇒ 提示挂整格（点击热区也是整格），否则只挂排序图标。
    function sortTipReady(column) {
        if (!control.columnSortable(column) || column.showSortTip !== true)
            return false;
        if (control.columnSortIcon(column) !== null)
            return false;
        return !control.isSortControlled(control.leafIndexOf(column));
    }

    function sortTipOnIcon(column) {
        return control.sortTipReady(column)
            && (control.columnFilterable(column) || column.useFullRender === true);
    }

    function sortTipOnCell(column) {
        return control.sortTipReady(column)
            && !control.columnFilterable(column) && column.useFullRender !== true;
    }

    // 官方提示文案 = locale[getNextSortOrder(当前序)]（utils.ts:150-159 + locale/source/zh_CN.ts:106-108）
    function nextSortTipText(column) {
        const order = control.sortOrderAt(control.leafIndexOf(column));
        if (order === "ascend")
            return qsTr("点击降序");
        if (order === "descend")
            return qsTr("取消排序");
        return qsTr("点击升序");
    }

    // headerStyle 是官方糊在 <thead> 上的 CSS；QML 侧只有背景色这一件事落得下来。
    function headerCellBg() {
        const s = control.headerStyle;
        if (s !== undefined && s !== null && typeof s === "object") {
            const c = s.backgroundColor !== undefined ? s.backgroundColor : s.background;
            if (c !== undefined && c !== null)
                return c;
        }
        return Theme.current.colorBg1;
    }

    // ============================================================ 排序 / 筛选

    function handleSort(column) {
        const index = control.leafIndexOf(column);
        if (!control.isSortControlled(index))
            control.queries = Engine.nextSortQueries(control.queries, column.dataIndex).queries;
        control.notifyChange("sorter");
        control.scrollToFirstRowIfNeeded();
    }

    function handleFilter(column, values) {
        const index = control.leafIndexOf(column);
        if (!control.isFilterControlled(index)) {
            const next = [];
            for (let i = 0; i < control.queries.length; ++i) {
                const copy = Engine.shallowCopy(control.queries[i]);
                if (i === index)
                    copy.filteredValue = values;
                next.push(copy);
            }
            control.queries = next;
        }
        control.notifyChange("filter");
        control.scrollToFirstRowIfNeeded();
    }

    function notifyChange(changeType) {
        control.changed({
            pagination: control.paginationState,
            filters: control.activeFilterInfo(),
            sorter: control.activeSorterInfo(),
            extra: { changeType: changeType }
        });
    }

    function activeFilterInfo() {
        const out = [];
        for (let i = 0; i < control.queries.length; ++i) {
            const q = control.queries[i];
            if (control.isActiveFilter(q))
                out.push({ dataIndex: q.dataIndex, filteredValue: q.filteredValue });
        }
        return out;
    }

    function activeSorterInfo() {
        for (let i = 0; i < control.queries.length; ++i) {
            const q = control.queries[i];
            if (q.sorter !== undefined && q.sortOrder)
                return { dataIndex: q.dataIndex, sortOrder: q.sortOrder };
        }
        return {};
    }

    function scrollToFirstRowIfNeeded() {
        if (!control.scroll || control.scroll.scrollToFirstRowOnChange !== true)
            return;
        if (control.scrollY !== null) {
            control.scrollWasRequested = true;
            body.contentY = 0;
            control.scrollWasRequested = false;
        }
    }

    property bool scrollWasRequested: false

    // virtualized.onScroll（VirtualizedOnScrollArgs）：只在 virtualized 传的是对象
    // 且给了 onScroll 时发；scrollUpdateWasRequested 表示这次滚动是组件自己调进来的
    // （切页/排序回到首行那一类），而不是用户滚的。
    function notifyVirtualScroll(offset, previous) {
        const v = control.virtualized;
        if (v === undefined || v === null || typeof v !== "object")
            return;
        const fn = v.onScroll;
        if (typeof fn !== "function")
            return;
        fn({
            scrollDirection: offset > previous ? "forward" : "backward",
            scrollOffset: offset,
            scrollUpdateWasRequested: control.scrollWasRequested
        });
    }

    function clearFilteredValue() {
        const next = [];
        for (let i = 0; i < control.queries.length; ++i) {
            const copy = Engine.shallowCopy(control.queries[i]);
            copy.filteredValue = [];
            next.push(copy);
        }
        control.queries = next;
    }

    function clearAll() {
        const next = [];
        for (let i = 0; i < control.queries.length; ++i) {
            const copy = Engine.shallowCopy(control.queries[i]);
            copy.filteredValue = [];
            copy.sortOrder = false;
            next.push(copy);
        }
        control.queries = next;
        control.innerSelectedRowKeys = [];
        control.innerExpandedRowKeys = [];
    }

    // ============================================================ 选择

    function rowDisabled(key) {
        return Engine.indexOfKey(control.disabledRowKeys, key) >= 0;
    }

    function checkState(key) {
        if (control.relatedMode) {
            return {
                checked: Engine.indexOfKey(control.checkedTree.checked, key) >= 0,
                indeterminate: Engine.indexOfKey(control.checkedTree.half, key) >= 0
            };
        }
        return {
            checked: Engine.indexOfKey(control.selectedRowKeys, key) >= 0,
            indeterminate: false
        };
    }

    function headerCheckState() {
        const keys = control.relatedMode ? control.checkedTree.checked : control.selectedRowKeys;
        let selectable = 0;
        let count = 0;
        for (let i = 0; i < control.pageRowKeys.length; ++i) {
            if (control.rowDisabled(control.pageRowKeys[i]))
                continue;
            selectable += 1;
            if (Engine.indexOfKey(keys, control.pageRowKeys[i]) >= 0)
                count += 1;
        }
        if (selectable <= 0)
            return { checked: false, indeterminate: false };
        return {
            checked: count === selectable,
            indeterminate: count > 0 && count < selectable
        };
    }

    // rowSelection.renderCell（Table.tsx:1028-1110）：官方把默认那个 Checkbox 当 originNode
    // 交给调用方包一层。QML 没有「把组件内部的一块 delegate 当子项塞进外部节点」的写法，
    // 所以端口传的是 originNode:"checkbox" 这个标记 + 官方那一份参数对象，调用方在自己的
    // Component 里声明 `property var args` 就能拿到全套（selected / indeterminate / record /
    // index / disabled / inHeader / selectRow(selected) / selectAll(selected)）。
    function selectionCellArgs(inHeader, record, index) {
        const key = inHeader ? undefined : Engine.recordKey(record, control.rowKey);
        const state = inHeader ? control.headerCheckState() : control.checkState(key);
        const args = {
            selected: state.checked,
            indeterminate: state.indeterminate,
            record: inHeader ? undefined : record,
            index: index,
            originNode: "checkbox",
            inHeader: inHeader,
            disabled: control.rs.disabled === true
        };
        if (inHeader) {
            args.selectAll = function (selected) {
                control.toggleAll(Boolean(selected));
            };
        } else {
            args.selectRow = function (selected) {
                control.toggleRow(key, Boolean(selected));
            };
        }
        return args;
    }

    function selectionCellNode(inHeader, record, index) {
        const fn = control.rs.renderCell;
        if (typeof fn !== "function")
            return null;
        const r = fn(control.selectionCellArgs(inHeader, record, index));
        return r instanceof Component ? r : null;
    }

    function selectionCellIsNode(inHeader, record, index) {
        return control.selectionCellNode(inHeader, record, index) !== null;
    }

    function rowsOfKeys(keys) {
        const out = [];
        for (let i = 0; i < keys.length; ++i) {
            const rec = Engine.findRecord(control.filteredSorted, keys[i], control.rowKey);
            if (rec !== undefined)
                out.push(rec);
        }
        return out;
    }

    function toggleRow(key, selected) {
        if (!control.selectionPresent || control.rowDisabled(key))
            return;
        const rs = control.rs;
        let next;
        if (control.relatedMode) {
            next = Engine.cascadeKeys(control.pageRecords, control.selectedRowKeys, key,
                selected, control.ctx).checked;
        } else {
            next = Engine.selectRow(control.selectedRowKeys, key, selected);
        }
        const before = control.selectedRowKeys;
        if (!control.selectionControlled)
            control.innerSelectedRowKeys = next;
        const record = Engine.findRecord(control.pageRecords, key, control.rowKey);
        if (typeof rs.onSelect === "function")
            rs.onSelect(record, selected, control.rowsOfKeys(next));
        if (typeof rs.onChange === "function")
            rs.onChange(next, control.rowsOfKeys(next));
        control.notifyChange("selection");
    }

    function toggleAll(selected) {
        if (!control.selectionPresent || control.rs.disabled === true)
            return;
        const rs = control.rs;
        const before = control.selectedRowKeys;
        let next;
        if (control.relatedMode) {
            const keys = [];
            if (selected) {
                for (let i = 0; i < control.pageRowKeys.length; ++i) {
                    if (!control.rowDisabled(control.pageRowKeys[i]))
                        keys.push(control.pageRowKeys[i]);
                }
            }
            next = Engine.conductCheck(control.pageRecords, keys, control.ctx).checked;
        } else {
            next = Engine.selectAllRows(before, control.pageRowKeys, control.disabledRowKeys, selected);
        }
        if (!control.selectionControlled)
            control.innerSelectedRowKeys = next;
        const changed = selected ? control.pageRowKeys.filter(control.notInKeys.bind(control, next))
            : before.slice();
        if (typeof rs.onSelectAll === "function")
            rs.onSelectAll(selected, control.rowsOfKeys(next), control.rowsOfKeys(changed));
        if (typeof rs.onChange === "function")
            rs.onChange(next, control.rowsOfKeys(next));
    }

    function notInKeys(next, key) {
        return Engine.indexOfKey(next, key) < 0;
    }

    // ============================================================ 展开

    function initExpandedKeys() {
        const source = Array.isArray(control.dataSource) ? control.dataSource : [];
        if (control.defaultExpandAllRows || control.expandAllRows)
            return control.keysOfRecords(source);
        if (control.defaultExpandAllGroupRows || control.expandAllGroupRows) {
            const keys = [];
            for (let g = 0; g < control.grouped.groups.length; ++g)
                keys.push(control.grouped.groups[g].key);
            return keys;
        }
        if (Array.isArray(control.defaultExpandedRowKeys) && control.defaultExpandedRowKeys.length)
            return control.defaultExpandedRowKeys.slice();
        return [];
    }

    function toggleExpand(key) {
        const record = Engine.findRecord(control.filteredSorted, key, control.rowKey);
        const wasExpanded = Engine.indexOfKey(control.expandedKeys, key) >= 0;
        if (control.expandedRowKeys !== undefined && control.expandedRowKeys !== null) {
            // 受控：端口不改状态，只把官方那两个回调发出去（官方同样如此）。
            control.expand(!wasExpanded, record)
            control.expandedRowsChange(control.rowsOfExpandedKeys(
                Engine.selectRow(control.expandedKeys, key, !wasExpanded)))
            return;
        }
        const next = control.innerExpandedRowKeys.slice();
        const at = Engine.indexOfKey(next, key)
        if (at >= 0)
            next.splice(at, 1);
        else
            next.push(key)
        control.innerExpandedRowKeys = next;
        control.expand(!wasExpanded, record)
        control.expandedRowsChange(control.rowsOfExpandedKeys(next))
    }

    // 官方 onExpandedRowsChange 传的是**记录**（按 dataSource 顺序），不是 key。
    function rowsOfExpandedKeys(keys) {
        const out = [];
        const source = Array.isArray(control.dataSource) ? control.dataSource : [];
        for (let i = 0; i < source.length; ++i) {
            const k = Engine.recordKey(source[i], control.rowKey);
            if (Engine.indexOfKey(keys, k) >= 0)
                out.push(source[i]);
        }
        return out;
    }

    // 官方实例方法：拿当前这一页过滤/排序之后的数据。
    function getCurrentPageData() {
        return control.pageRecords;
    }

    function expandSlot(row) {
        if (row === undefined || row.kind !== "expand"
            || typeof control.expandedRowRender !== "function")
            return null;
        const r = control.expandedRowRender(row.record, row.index, true);
        return r instanceof Component ? r : null;
    }

    function expandText(row) {
        if (row === undefined || row.kind !== "expand"
            || typeof control.expandedRowRender !== "function")
            return "";
        return control.plainText(control.expandedRowRender(row.record, row.index, true));
    }

    function groupSlot(row) {
        if (row === undefined || row.kind !== "section"
            || typeof control.renderGroupSection !== "function")
            return null;
        const r = control.renderGroupSection(row.groupKey, row.recordKeys);
        if (r instanceof Component)
            return r;
        return null;
    }

    function groupText(row) {
        if (row === undefined || row.kind !== "section")
            return "";
        if (typeof control.renderGroupSection !== "function")
            return String(row.groupKey);
        const r = control.renderGroupSection(row.groupKey, row.recordKeys);
        return r instanceof Component ? "" : control.plainText(r);
    }

    // ============================================================ 分页

    readonly property int pageCount: control.paginationState !== null
        && control.paginationState.pageSize > 0
        ? Math.max(1, Math.ceil(control.paginationState.total / control.paginationState.pageSize)) : 1

    function handlePageChange(current) {
        const input = control.paginationInput;
        if (!control.paginationControlled) {
            const copy = Engine.shallowCopy(input);
            copy.currentPage = current;
            control.innerPagination = copy;
        }
        if (typeof input.onChange === "function") {
            input.onChange({ pagination: { currentPage: current } });
            return;
        }
        if (typeof input.onPageChange === "function")
            input.onPageChange(current);
        control.notifyChange("pagination");
        control.scrollToFirstRowIfNeeded();
    }

    function handlePageSizeChange(size) {
        const input = control.paginationInput;
        if (!control.paginationControlled) {
            const copy = Engine.shallowCopy(input);
            const state = control.paginationState;
            copy.pageSize = size;
            if (input.preventPageChangeOnPageSizeChange !== true && state !== null) {
                const start = (state.currentPage - 1) * state.pageSize;
                copy.currentPage = Math.floor(start / size) + 1;
            }
            control.innerPagination = copy;
        }
        if (typeof input.onPageSizeChange === "function")
            input.onPageSizeChange(size);
    }

    // renderPagination(paginationProps)（TablePagination.tsx:34）：也直接收 Component。
    function renderPaginationNode() {
        const fn = control.renderPagination;
        if (fn instanceof Component)
            return fn;
        if (typeof fn !== "function")
            return null;
        const r = fn(control.paginationState);
        return r instanceof Component ? r : null;
    }

    function paginationText() {
        const state = control.paginationState;
        if (state === null || state.formatPageText === false)
            return "";
        const info = Engine.paginationInfo(state, control.pageRecords);
        if (typeof state.formatPageText === "function")
            return control.plainText(state.formatPageText(info));
        // 官方默认走 locale.Table.pageText 这条模板（foundation.ts:1175-1194 +
        // locale/source/zh_CN.ts:105），并且 total 为 0 时整条不发。
        if (!(info.total > 0))
            return "";
        return qsTr("显示第 %1 条-第 %2 条，共 %3 条").arg(info.currentStart)
            .arg(info.currentEnd).arg(info.total);
    }

    // ============================================================ 行 / 格自定义

    function rowProps(row) {
        if (row.kind === "section")
            return typeof control.onGroupedRow === "function"
                ? control.onGroupedRow({ groupKey: row.groupKey, recordKeys: row.recordKeys }, row.index)
                : null;
        if (typeof control.onRow !== "function" || row.record === undefined)
            return null;
        return control.onRow(row.record, row.index, control.checkState(row.key));
    }

    function headerRowProps(rowIndex) {
        if (typeof control.onHeaderRow !== "function")
            return null;
        return control.onHeaderRow(control.headerGrid.rows[rowIndex], rowIndex);
    }

    function styleColor(props, names) {
        if (props === null || props === undefined)
            return null;
        const style = props.style;
        if (style === undefined || style === null)
            return null;
        for (let i = 0; i < names.length; ++i) {
            if (style[names[i]] !== undefined)
                return style[names[i]];
        }
        return null;
    }

    function rowBackground(props) {
        return control.styleColor(props, ["background", "backgroundColor"]);
    }

    function cellPropsOf(column, row) {
        if (typeof column.onCell !== "function" || row === undefined || row.record === undefined)
            return null;
        return column.onCell(row.record, row.index);
    }

    function headerCellPropsOf(column) {
        if (typeof column.onHeaderCell !== "function")
            return null;
        return column.onHeaderCell(column, control.leafIndexOf(column));
    }

    function slotOf(value) {
        if (value === undefined || value === null)
            return null;
        if (value instanceof Component)
            return value;
        if (typeof value === "function") {
            const r = value(control.pageRecords);
            return r instanceof Component ? r : null;
        }
        return null;
    }

    function slotText(value) {
        if (value === undefined || value === null || value instanceof Component)
            return "";
        if (typeof value === "function")
            return control.plainText(value(control.pageRecords));
        return control.plainText(value);
    }

    function rowOverrideComponent() {
        const c = control.components;
        if (c === null || c === undefined)
            return null;
        const body = c.body;
        if (body === undefined || body === null || !(body.row instanceof Component))
            return null;
        return body.row;
    }

    // components.body.cell：官方用它换掉 <td> 本身（BaseRow.tsx:229）。
    // QML 没法把我们的 inner 当子项交给外部节点，所以端口让调用方的节点铺满整个格子，
    // 再把 text / record / index / column / hovered / selected / expanded / options 绑上去。
    function cellOverrideComponent() {
        const c = control.components;
        if (c === null || c === undefined)
            return null;
        const body = c.body;
        if (body === undefined || body === null || !(body.cell instanceof Component))
            return null;
        return body.cell;
    }

    function hasChildren(row) {
        return row !== undefined && row.hasChildren === true;
    }

    // 官方 motion 档固定用「右指」那颗，靠旋转表达展开态（CustomExpandIcon.tsx:44-48）。
    function expandIconBaseName(row) {
        return row.hasChildren ? "small_triangle_right" : "chevron_right";
    }

    // expandIcon：Component 直接用；函数按官方签名收 expanded 返回节点；
    // true / undefined 走默认那颗；false 已经在 expandIconOn 里整个关掉。
    function expandIconCustom(row) {
        const e = control.expandIcon;
        if (e === undefined || e === null || typeof e === "boolean")
            return null;
        if (e instanceof Component)
            return e;
        if (typeof e === "function") {
            const r = e(row.treeExpanded === true || row.rowExpanded === true);
            return r instanceof Component ? r : null;
        }
        return null;
    }

    function expandIconSide(row) {
        return row.hasChildren ? control.treeIconSize : control.iconSize;
    }

    // ============================================================ 视觉

    Rectangle {
        objectName: "tableFrame"

        anchors.fill: parent
        visible: control.bordered
        color: "transparent"
        border.width: 1
        border.color: Theme.current.colorBorder
    }

    Column {
        id: stack

        objectName: "tableStack"

        x: control.borderWidth
        y: control.borderWidth
        width: control.viewportWidth
        spacing: 0

        Loader {
            objectName: "tablePaginationTopHost"

            active: control.paginationTop
            visible: active
            width: stack.width
            height: control.paginationHeight
            sourceComponent: paginationBlock
        }

        Loader {
            objectName: "tableTitleHost"

            active: control.titlePresent
            visible: active
            width: stack.width
            height: control.titleHeight
            sourceComponent: titleBlock
        }

        Item {
            id: container

            objectName: "tableContainer"

            width: stack.width
            height: control.headerHeight + control.bodyHeight
            clip: true

            Flickable {
                id: viewport

                objectName: "tableViewport"

                anchors.fill: parent
                clip: true
                contentWidth: control.contentWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                // 撑出可横向滚动的内容宽（让 Flickable 自己按子项算会算歪）
                Item {
                    width: viewport.contentWidth
                    height: 1
                }

                Repeater {
                    model: control.showHeader ? control.headerGrid.rows.length : 0

                    delegate: Item {
                        id: headerRowItem

                        objectName: "tableHeaderRow"

                        required property int index

                        x: 0
                        y: index * control.headerRowHeight + (control.scrollY !== null ? 0 : 0)
                        width: control.contentWidth
                        height: control.headerRowHeight

                        Repeater {
                            model: control.headerCellsAt(headerRowItem.index)

                            delegate: Item {
                                id: headerCell

                                objectName: "tableHeaderCell"

                                required property int index

                                // modelData 到手已经是 QVariantMap 拷贝（JS 数组喂 Repeater 的代价），
                                // 拿它去 leafIndexOf 只会得到 -1，排序 / 筛选的图标态就永远对不上。
                                // 所以列对象一律按位置回查原物。
                                readonly property var cell: control.headerCellsAt(
                                    headerRowItem.index)[index]
                                readonly property var column: cell.column
                                readonly property int leafStart: cell.leafStart
                                readonly property var custom: control.headerCellPropsOf(column)
                                readonly property bool sortable: control.columnSortable(column)

                                x: control.cellX(leafStart, viewport.contentX)
                                y: 0
                                width: control.spanWidth(cell)
                                height: control.headerRowHeight * (cell.rowSpan > 1 ? cell.rowSpan : 1)
                                z: control.isFixed(leafStart) ? 6 : 2

                                Rectangle {
                                    objectName: "tableHeaderBackground"

                                    anchors.fill: parent
                                    color: control.headerCellBg()
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: headerHover.hovered && headerCell.sortable
                                    color: Theme.current.colorFill0
                                }

                                Rectangle {
                                    visible: headerCell.custom !== null
                                        && control.rowBackground(headerCell.custom) !== null
                                    anchors.fill: parent
                                    color: control.rowBackground(headerCell.custom)
                                }

                                Loader {
                                    id: headerTitleLoader

                                    objectName: "tableHeaderTitleNode"

                                    anchors.left: parent.left
                                    anchors.leftMargin: control.headerPaddingX
                                    anchors.right: parent.right
                                    anchors.rightMargin: control.headerPaddingX
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, parent.width - 2 * control.headerPaddingX)
                                    height: (item as Item) ? (item as Item).implicitHeight : 0
                                    visible: control.headerTitleNode(headerCell.column) !== null
                                    sourceComponent: control.headerTitleNode(headerCell.column)

                                    // useFullRender 时官方把全选框当作 title 的入参透出来，
                                    // 端口同样把这份状态 + selectAll 动作绑给调用方的节点。
                                    Binding {
                                        target: headerTitleLoader.item
                                        when: headerTitleLoader.item !== null
                                            && headerCell.column.useFullRender === true
                                        property: "args"
                                        value: control.headerTitleArgs(headerCell.column)
                                    }
                                }

                                Item {
                                    id: headerTitleBox

                                    objectName: "tableHeaderTitleRow"

                                    anchors.left: parent.left
                                    anchors.leftMargin: control.headerPaddingX
                                    anchors.right: parent.right
                                    anchors.rightMargin: control.headerPaddingX
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: control.lineHeight
                                    visible: control.headerTitleNode(headerCell.column) === null

                                    readonly property real tail: control.titleTailWidth(headerCell.column)

                                    Text {
                                        objectName: "tableHeaderTitle"

                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.rightMargin: headerTitleBox.tail
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: control.headerTitleText(headerCell.column)
                                        color: Theme.current.colorText2
                                        font.pixelSize: Theme.current.fontSizeRegular
                                        font.weight: Theme.current.fontWeightBold
                                        elide: Text.ElideRight
                                        horizontalAlignment: control.textAlignOf(headerCell.column.align)
                                    }

                                    Item {
                                        id: sorterBox

                                        objectName: "tableColumnSorter"

                                        anchors.right: parent.right
                                        anchors.rightMargin: control.columnFilterable(headerCell.column)
                                            ? control.iconGap + control.filterBlockWidth : 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: control.iconSize
                                        height: control.iconSize
                                        visible: control.columnSortable(headerCell.column)

                                        Loader {
                                            id: sortIconNode

                                            objectName: "tableSorterNode"

                                            anchors.centerIn: parent
                                            visible: control.columnSortIcon(headerCell.column) !== null
                                            sourceComponent: control.columnSortIcon(
                                                headerCell.column)

                                            Binding {
                                                target: sortIconNode.item
                                                when: sortIconNode.item !== null
                                                property: "sortOrder"
                                                value: control.sortOrderAt(
                                                    control.leafIndexOf(headerCell.column))
                                            }
                                        }

                                        Icon {
                                            objectName: "tableSorterUp"

                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.verticalCenter
                                            visible: control.columnSortIcon(headerCell.column) === null
                                            name: "caretup"
                                            size: control.iconSize
                                            color: control.sortOrderAt(
                                                control.leafIndexOf(headerCell.column)) === "ascend"
                                                ? Theme.current.colorPrimary : Theme.current.colorText2
                                        }

                                        Icon {
                                            objectName: "tableSorterDown"

                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.verticalCenter
                                            visible: control.columnSortIcon(headerCell.column) === null
                                            name: "caretdown"
                                            size: control.iconSize
                                            color: control.sortOrderAt(
                                                control.leafIndexOf(headerCell.column)) === "descend"
                                                ? Theme.current.colorPrimary : Theme.current.colorText2
                                        }

                                        // showSortTip：这一列还有筛选器时，官方把提示只挂在排序图标上
                                        // （ColumnSorter.tsx:77-88）。
                                        Tooltip {
                                            objectName: "tableSorterTip"

                                            target: sorterBox
                                            condition: control.sortTipOnIcon(headerCell.column)
                                            text: control.nextSortTipText(headerCell.column)
                                        }
                                    }

                                    Item {
                                        id: filterBox

                                        objectName: "tableColumnFilter"

                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: control.iconSize
                                        height: control.iconSize
                                        visible: control.columnFilterable(headerCell.column)

                                        Loader {
                                            id: filterIconNode

                                            objectName: "tableFilterIconNode"

                                            anchors.centerIn: parent
                                            visible: control.columnFilterIcon(headerCell.column) !== null
                                            sourceComponent: control.columnFilterIcon(
                                                headerCell.column)

                                            Binding {
                                                target: filterIconNode.item
                                                when: filterIconNode.item !== null
                                                property: "filtered"
                                                value: control.filteredValueAt(
                                                    control.leafIndexOf(headerCell.column)).length > 0
                                            }
                                        }

                                        Icon {
                                            objectName: "tableFilterIcon"

                                            anchors.fill: parent
                                            visible: control.columnFilterIcon(headerCell.column) === null
                                            name: "filter"
                                            size: control.iconSize
                                            color: control.filteredValueAt(
                                                control.leafIndexOf(headerCell.column)).length > 0
                                                ? Theme.current.colorPrimary : Theme.current.colorText2
                                        }

                                        TapHandler {
                                            objectName: "tableFilterTap"

                                            acceptedButtons: Qt.LeftButton
                                            onTapped: control.openFilterPanel(headerCell.column, headerCell)
                                        }
                                    }
                                }

                                // 选择列表头：全选框在整格居中
                                Checkbox {
                                    objectName: "tableSelectAllCheckbox"

                                    anchors.centerIn: parent
                                    visible: control.isSelectionCell(headerCell.column)
                                        && !control.selectionCellIsNode(true, undefined, undefined)
                                    checked: control.headerCheckState().checked
                                        indeterminate: control.headerCheckState().indeterminate
                                    disabled: control.rs.disabled === true
                                    onToggled: control.toggleAll(!control.headerCheckState().checked)
                                }

                                Loader {
                                    id: selectAllNode

                                    objectName: "tableSelectAllCellNode"

                                    anchors.centerIn: parent
                                    visible: control.isSelectionCell(headerCell.column)
                                    active: visible
                                    sourceComponent: control.selectionCellNode(true, undefined, undefined)

                                    // 官方 renderCell 收的就是这一个参数对象，端口原样递过去
                                    // （函数只能挂在对象里：直接往属性上绑函数会报
                                    //  「Unable to assign a function to a property of any type other than var」）。
                                    Binding {
                                        target: selectAllNode.item
                                        when: selectAllNode.item !== null
                                        property: "args"
                                        value: control.selectionCellArgs(true, undefined, undefined)
                                    }
                                }

                                Rectangle {
                                    visible: control.bordered
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 1
                                    color: Theme.current.colorBorder
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: control.headerBorder
                                    color: Theme.current.colorBorder
                                }

                                Rectangle {
                                    visible: control.leftFixedLastAt(headerCell.leafStart)
                                        && control.scrolledFromLeft
                                    anchors.left: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    color: Theme.current.colorShadow
                                }

                                Rectangle {
                                    visible: control.rightFixedFirstAt(headerCell.leafStart)
                                        && control.scrolledFromRight
                                    anchors.right: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    color: Theme.current.colorShadow
                                }

                                Item {
                                    objectName: "tableResizerHandle"

                                    visible: control.columnResizable(headerCell.column)
                                    anchors.right: parent.right
                                    anchors.rightMargin: -1
                                    anchors.top: parent.top
                                    anchors.topMargin: 4
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    width: 9

                                    Rectangle {
                                        anchors.fill: parent
                                        color: resizeHover.hovered || control.resizeDragging === headerCell
                                            ? Theme.current.colorPrimary : Theme.current.colorBorder
                                    }

                                    HoverHandler {
                                        id: resizeHover
                                    }

                                    DragHandler {
                                        objectName: "tableResizerDrag"

                                        target: null
                                        onActiveChanged: {
                                            if (active) {
                                                control.resizeDragging = headerCell;
                                                control.resizeStartWidth = control.spanWidth(headerCell.cell);
                                                control.resizeHook("onResizeStart", headerCell.column);
                                            } else {
                                                control.resizeDragging = null;
                                                control.resizeHook("onResizeStop", headerCell.column);
                                            }
                                        }
                                        onTranslationChanged: {
                                            if (!active)
                                                return;
                                            control.applyColumnWidth(headerCell.leafStart,
                                                control.resizeStartWidth + translation.x);
                                            control.resizeHook("onResize", headerCell.column);
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: headerHover
                                }

                                // showSortTip 的另一档：这一列只有排序时，官方把提示包在整格上
                                // （TableHeaderRow.tsx:232-244），点击热区也是整格。
                                Tooltip {
                                    objectName: "tableHeaderCellTip"

                                    target: headerCell
                                    condition: control.sortTipOnCell(headerCell.column)
                                    text: control.nextSortTipText(headerCell.column)
                                }

                                TapHandler {
                                    objectName: "tableHeaderCellTap"

                                    acceptedButtons: Qt.LeftButton
                                    enabled: headerCell.sortable
                                        && !control.isSortControlled(headerCell.leafStart)
                                    cursorShape: headerCell.sortable
                                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onTapped: control.handleSort(headerCell.column)
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: body

                    objectName: "tableBody"

                    x: viewport.contentX
                    y: control.headerHeight
                    width: viewport.width
                    height: control.bodyHeight
                    clip: true
                    model: control.rowStream
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds

                    // 官方 virtualized.onScroll 是 react-window 的滚动回调
                    // （scrollDirection / scrollOffset / scrollUpdateWasRequested）。
                    property real lastOffset: 0
                    onContentYChanged: {
                        control.notifyVirtualScroll(contentY, body.lastOffset);
                        body.lastOffset = contentY;
                    }

                    delegate: Item {
                        id: rowItem

                        objectName: "tableRow"

                        required property int index

                        // 与表头 / 格子同理：JS 数组喂进 view 的 model 之后 modelData 是拷贝，
                        // onRow 返回的 onClick 这类函数字段在拷贝里就没了，一律按位置回查原物。
                        readonly property var row: control.rowStream[index]
                        readonly property string kind: row !== undefined ? row.kind : ""
                        readonly property var custom: control.rowProps(row)
                        readonly property bool isSection: rowItem.kind === "section"
                        readonly property var overrideComponent: control.rowOverrideComponent()
                        readonly property bool isExpandRow: rowItem.kind === "expand"

                        width: body.width
                        height: control.rowHeightAt(row)
                        z: rowItem.isExpandRow ? 0 : (rowItem.spanDown ? 2 : 1)
                        readonly property bool spanDown: control.rowHasSpanDown(rowItem.row)

                        // components.body.row 传了 Component 时，行本体被搬进那个包装项里
                        // （官方 SortableRow 就是接住 tr 的 children 再自己加拖拽），
                        // 没传就正常挂在行上。
                        Item {
                            id: cellsHost

                            objectName: "tableRowContent"

                            anchors.fill: parent

                            Rectangle {
                                objectName: "tableRowBackground"

                                anchors.fill: parent
                                color: rowItem.custom !== null
                                    && control.rowBackground(rowItem.custom) !== null
                                    ? control.rowBackground(rowItem.custom)
                                    : (rowItem.isSection ? Theme.current.colorDefault : Theme.current.colorBg1)
                            }

                            // ------------------------------------ 数据行
                            Repeater {
                                model: rowItem.kind === "data" ? control.leafColumns : []

                                delegate: Item {
                                    id: cell

                                    objectName: "tableCell"

                                    required property int index

                                    // 同表头那一格：modelData 是 QVariantMap 拷贝，
                                    // leafIndexOf / filters 判定都只对原物成立。
                                    readonly property var column: control.leafColumns[index]
                                    readonly property int leafIndex: index
                                    readonly property bool fullRender: cell.column.useFullRender === true
                                    readonly property bool iconInCell: control.drawExpandInRow(rowItem.row)
                                        && cell.leafIndex === control.firstDataLeaf()
                                        && !cell.fullRender
                                    readonly property var rendered: control.renderCell(column,
                                        rowItem.row.record, rowItem.row.index,
                                        control.renderOptions(rowItem.row, rowHover.hovered, column))
                                    readonly property var custom: control.cellPropsOf(column, rowItem.row)
                                    readonly property bool hidden: cell.rendered.colSpan === 0
                                        || cell.rendered.rowSpan === 0
                                    readonly property bool isSelection: control.isSelectionCell(cell.column)
                                    readonly property bool isExpandCol: control.isExpandCell(cell.column)
                                    readonly property bool isData: control.isDataColumn(cell.column)
                                    readonly property var cellOverride: control.cellOverrideComponent()

                                    visible: !cell.hidden
                                    x: control.cellX(cell.leafIndex, viewport.contentX)
                                    y: 0
                                    width: control.spanWidthFrom(cell.leafIndex,
                                        cell.rendered.colSpan > 0 ? cell.rendered.colSpan : 1)
                                    height: control.rowHeight * (cell.rendered.rowSpan > 1
                                        ? cell.rendered.rowSpan : 1)
                                    z: control.isFixed(cell.leafIndex) ? 6 : 0
                                    // 官方虚拟化那一档的格子是 `overflow: hidden`
                                    // （`.semi-table-virtualized …-row > …-row-cell`，table.scss:393-400）；
                                    // 端口的表体本来就是 ListView 回收，永远走这一档。
                                    // 不裁的话 `elide: ElideNone` 的 Text 会整行画到邻列去
                                    //（邻列那层不透明底色只在悬浮时亮着 ⇒ 悬浮才「看起来被裁了」）。
                                    clip: true

                                    // 官方整行悬浮给格子换两层底色：贴住的列仍用 bg-1，
                                    // 普通列换 bg-0，两层之上再叠半透明 fill-0（table.scss:279-291）。
                                    Rectangle {
                                        objectName: "tableCellHoverBase"

                                        anchors.fill: parent
                                        visible: rowHover.hovered && !rowItem.isSection
                                        color: control.isFixed(cell.leafIndex)
                                            ? Theme.current.colorBg1 : Theme.current.colorBg0
                                    }

                                    Rectangle {
                                        objectName: "tableCellHoverFill"

                                        anchors.fill: parent
                                        visible: rowHover.hovered && !rowItem.isSection
                                        color: Theme.current.colorFill0
                                    }

                                    Rectangle {
                                        objectName: "tableCellBackground"

                                        visible: cell.custom !== null
                                            && control.rowBackground(cell.custom) !== null
                                        anchors.fill: parent
                                        color: control.rowBackground(cell.custom)
                                    }

                                    // components.body.cell 传了节点 ⇒ 整格交给调用方铺
                                    Loader {
                                        id: cellOverrideLoader

                                        objectName: "tableCellOverride"

                                        anchors.fill: parent
                                        active: cell.cellOverride !== null
                                        visible: active
                                        sourceComponent: cell.cellOverride

                                        Binding {
                                            target: cellOverrideLoader.item
                                            when: cellOverrideLoader.item !== null
                                            property: "text"
                                            value: cell.rendered.text
                                        }

                                        Binding {
                                            target: cellOverrideLoader.item
                                            when: cellOverrideLoader.item !== null
                                            property: "record"
                                            value: rowItem.row.record
                                        }

                                        Binding {
                                            target: cellOverrideLoader.item
                                            when: cellOverrideLoader.item !== null
                                            property: "index"
                                            value: rowItem.row.index
                                        }

                                        Binding {
                                            target: cellOverrideLoader.item
                                            when: cellOverrideLoader.item !== null
                                            property: "column"
                                            value: cell.column
                                        }

                                        Binding {
                                            target: cellOverrideLoader.item
                                            when: cellOverrideLoader.item !== null
                                            property: "hovered"
                                            value: rowHover.hovered
                                        }

                                        Binding {
                                            target: cellOverrideLoader.item
                                            when: cellOverrideLoader.item !== null
                                            property: "selected"
                                            value: control.checkState(rowItem.row.key).checked
                                        }

                                        Binding {
                                            target: cellOverrideLoader.item
                                            when: cellOverrideLoader.item !== null
                                            property: "expanded"
                                            value: rowItem.row.treeExpanded === true
                                                || rowItem.row.rowExpanded === true
                                        }

                                        Binding {
                                            target: cellOverrideLoader.item
                                            when: cellOverrideLoader.item !== null
                                            property: "options"
                                            value: control.renderOptions(rowItem.row,
                                                rowHover.hovered, cell.column)
                                        }
                                    }

                                    Item {
                                        id: cellContent

                                        objectName: "tableCellContent"

                                        x: control.contentLeft(rowItem.row, cell.leafIndex, cell.column)
                                        width: control.cellContentWidth(cell.width, cellContent.x)
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: control.lineHeight
                                        visible: !cell.isSelection && !cell.isExpandCol
                                            && cell.cellOverride === null

                                        // 展开按钮画在第一格里（hideExpandedColumn 默认 true）。
                                        // 官方 motion 那一档不换图标：一直用 right 那颗，展开时转 90°
                                        // （table.scss:710-720 expandedIcon-show/hide，
                                        //  150ms cubic-bezier(.62,.05,.36,.95)）。
                                        Item {
                                            objectName: "tableExpandIconBox"

                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: cell.iconInCell
                                            width: control.expandIconSide(rowItem.row)
                                            height: control.expandIconSide(rowItem.row)
                                            rotation: rowItem.row.treeExpanded === true
                                                || rowItem.row.rowExpanded === true ? 90 : 0

                                            Behavior on rotation {
                                                NumberAnimation {
                                                    duration: 150
                                                    easing.bezierCurve: [0.62, 0.05, 0.36, 0.95]
                                                }
                                            }

                                            Loader {
                                                id: rowExpandIconNode

                                                objectName: "tableExpandIconNode"

                                                anchors.centerIn: parent
                                                visible: control.expandIconCustom(rowItem.row) !== null
                                                sourceComponent: control.expandIconCustom(rowItem.row)

                                                Binding {
                                                    target: rowExpandIconNode.item
                                                    when: rowExpandIconNode.item !== null
                                                    property: "expanded"
                                                    value: rowItem.row.treeExpanded === true
                                                        || rowItem.row.rowExpanded === true
                                                }
                                            }

                                            Icon {
                                                objectName: "tableExpandIcon"

                                                anchors.centerIn: parent
                                                visible: control.expandIconCustom(rowItem.row) === null
                                                name: control.expandIconBaseName(rowItem.row)
                                                size: control.expandIconSide(rowItem.row)
                                                color: Theme.current.colorText2
                                            }

                                            TapHandler {
                                                objectName: "tableExpandIconTap"

                                                acceptedButtons: Qt.LeftButton
                                                onTapped: control.toggleExpand(rowItem.row.key)
                                            }
                                        }

                                        Loader {
                                            id: cellNode

                                            objectName: "tableCellNode"

                                            anchors.left: parent.left
                                            anchors.leftMargin: cell.iconInCell
                                                ? control.expandIconSide(rowItem.row)
                                                + control.expandIconMargin : 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: cell.isData && cell.rendered.isNode
                                            sourceComponent: cell.rendered.node

                                            // 官方 render 返回节点时，节点自己知道 text 与 record；
                                            // 端口的注入契约就这两个（多绑的属性调用方没声明会报警告）。
                                            Binding {
                                                target: cellNode.item
                                                when: cellNode.item !== null
                                                property: "text"
                                                value: cell.rendered.text
                                            }

                                            Binding {
                                                target: cellNode.item
                                                when: cellNode.item !== null
                                                property: "record"
                                                value: rowItem.row.record
                                            }

                                            // useFullRender 那一档调用方要自己画勾选框与展开按钮，
                                            // 端口把官方那份 options（含标记）连同状态与动作一起递过去。
                                            Binding {
                                                target: cellNode.item
                                                when: cellNode.item !== null && cell.fullRender
                                                property: "options"
                                                value: control.renderOptions(rowItem.row,
                                                    rowHover.hovered, cell.column)
                                            }
                                        }

                                        Text {
                                            id: cellText

                                            objectName: "tableCellText"

                                            anchors.left: parent.left
                                            anchors.leftMargin: cell.iconInCell
                                                ? control.expandIconSide(rowItem.row)
                                                + control.expandIconMargin : 0
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: cell.isData && !cell.rendered.isNode
                                            text: cell.rendered.text
                                            color: Theme.current.colorText0
                                            font.pixelSize: Theme.current.fontSizeRegular
                                            elide: control.ellipsisOn(cell.column)
                                                ? Text.ElideRight : Text.ElideNone
                                            horizontalAlignment: control.textAlignOf(cell.column.align)
                                        }
                                    }

                                    // 选择列的勾选框（整列宽里居中）
                                    Checkbox {
                                        objectName: "tableRowCheckbox"

                                        anchors.centerIn: parent
                                        visible: cell.isSelection && cell.cellOverride === null
                                            && !control.selectionCellIsNode(false, rowItem.row.record,
                                                rowItem.row.index)
                                        checked: control.checkState(rowItem.row.key).checked
                                        indeterminate: control.checkState(rowItem.row.key).indeterminate
                                        disabled: control.rowDisabled(rowItem.row.key)
                                        onToggled: control.toggleRow(rowItem.row.key,
                                            !control.checkState(rowItem.row.key).checked)
                                    }

                                    Loader {
                                        id: rowCheckboxNode

                                        objectName: "tableRowCheckboxNode"

                                        anchors.centerIn: parent
                                        visible: cell.isSelection
                                        active: visible
                                        sourceComponent: control.selectionCellNode(false,
                                            rowItem.row.record, rowItem.row.index)

                                        Binding {
                                            target: rowCheckboxNode.item
                                            when: rowCheckboxNode.item !== null
                                            property: "args"
                                            value: control.selectionCellArgs(false,
                                                rowItem.row.record, rowItem.row.index)
                                        }
                                    }

                                    // 展开单独成列时的那颗图标。官方 BaseRow.tsx:266：
                                    // 这一列遇到不可展开的记录时渲染的是**空格子**，不是淡掉的图标。
                                    Item {
                                        objectName: "tableExpandColumnCell"

                                        anchors.centerIn: parent
                                        width: control.expandIconSide(rowItem.row)
                                        height: control.expandIconSide(rowItem.row)
                                        visible: cell.isExpandCol && rowItem.row.expandable === true
                                        rotation: rowItem.row.treeExpanded === true
                                            || rowItem.row.rowExpanded === true ? 90 : 0

                                        Behavior on rotation {
                                            NumberAnimation {
                                                duration: 150
                                                easing.bezierCurve: [0.62, 0.05, 0.36, 0.95]
                                            }
                                        }

                                        Loader {
                                            id: expandColIconNode

                                            objectName: "tableExpandColumnNode"

                                            anchors.centerIn: parent
                                            visible: control.expandIconCustom(rowItem.row) !== null
                                            sourceComponent: control.expandIconCustom(rowItem.row)

                                            Binding {
                                                target: expandColIconNode.item
                                                when: expandColIconNode.item !== null
                                                property: "expanded"
                                                value: rowItem.row.treeExpanded === true
                                                    || rowItem.row.rowExpanded === true
                                            }
                                        }

                                        Icon {
                                            objectName: "tableExpandIconAlone"

                                            anchors.centerIn: parent
                                            visible: control.expandIconCustom(rowItem.row) === null
                                            name: control.expandIconBaseName(rowItem.row)
                                            size: control.expandIconSide(rowItem.row)
                                            color: Theme.current.colorText2
                                        }

                                        TapHandler {
                                            objectName: "tableExpandAloneTap"

                                            acceptedButtons: Qt.LeftButton
                                            onTapped: control.toggleExpand(rowItem.row.key)
                                        }
                                    }

                                    Rectangle {
                                        visible: control.bordered
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 1
                                        color: Theme.current.colorBorder
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: control.cellBorder
                                        color: Theme.current.colorBorder
                                    }

                                    Rectangle {
                                        visible: control.leftFixedLastAt(cell.leafIndex)
                                            && control.scrolledFromLeft
                                        anchors.left: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 3
                                        color: Theme.current.colorShadow
                                    }

                                    Rectangle {
                                        visible: control.rightFixedFirstAt(cell.leafIndex)
                                            && control.scrolledFromRight
                                        anchors.right: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 3
                                        color: Theme.current.colorShadow
                                    }
                                }
                            }

                            // ------------------------------------ 分组表头行
                            Item {
                                objectName: "tableSectionCell"

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: control.lineHeight
                                visible: rowItem.isSection

                                Text {
                                    objectName: "tableSectionText"

                                    anchors.left: parent.left
                                    anchors.leftMargin: control.controlColumnWidth
                                        + Theme.current.spacingBase
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: control.groupText(rowItem.row)
                                    color: Theme.current.colorText0
                                    font.pixelSize: Theme.current.fontSizeRegular
                                    font.weight: Theme.current.fontWeightBold
                                }

                                Loader {
                                    id: sectionNode

                                    objectName: "tableSectionNode"

                                    anchors.left: parent.left
                                    anchors.leftMargin: control.controlColumnWidth
                                        + Theme.current.spacingBase
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: control.groupSlot(rowItem.row) !== null
                                    sourceComponent: control.groupSlot(rowItem.row)

                                    // 官方 renderGroupSection(groupKey, group) 返回的是已经带好数据的
                                    // 元素；端口的节点是 Component，只能把组键回灌进去（节点要声明
                                    // property var groupKey，没声明会报「属性不存在」警告 —— 与格子的
                                    // text / record 契约同一套）。
                                    Binding {
                                        target: sectionNode.item
                                        when: sectionNode.item !== null
                                        property: "groupKey"
                                        value: rowItem.row.groupKey
                                    }
                                }
                            }

                            // ------------------------------------ 展开行
                            Item {
                                id: expandBox

                                objectName: "tableExpandRowCell"

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                visible: rowItem.isExpandRow

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.current.colorFill0
                                }

                                Loader {
                                    id: expandNode

                                    objectName: "tableExpandRowNode"

                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.current.spacingBase
                                    anchors.top: parent.top
                                    anchors.topMargin: Theme.current.spacingBase
                                    visible: control.expandSlot(rowItem.row) !== null
                                    sourceComponent: control.expandSlot(rowItem.row)
                                    onImplicitHeightChanged: control.setExpandHeight(rowItem.row.seq,
                                        expandNode.implicitHeight)
                                }

                                Text {
                                    objectName: "tableExpandRowText"

                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.current.spacingBase
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.current.spacingBase
                                    anchors.top: parent.top
                                    anchors.topMargin: Theme.current.spacingBase
                                    visible: control.expandSlot(rowItem.row) === null
                                    text: control.expandText(rowItem.row)
                                    color: Theme.current.colorText0
                                    font.pixelSize: Theme.current.fontSizeRegular
                                    wrapMode: Text.WordWrap
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: control.cellBorder
                                    color: Theme.current.colorBorder
                                }
                            }
                        }

                        Loader {
                            id: rowOverride

                            objectName: "tableRowOverride"

                            anchors.fill: parent
                            active: rowItem.overrideComponent !== null
                            visible: active
                            sourceComponent: rowItem.overrideComponent
                            onLoaded: {
                                cellsHost.parent = rowOverride.item;
                                cellsHost.anchors.fill = rowOverride.item;
                            }

                            Binding {
                                target: rowOverride.item
                                when: rowOverride.item !== null
                                property: "record"
                                value: rowItem.row.record
                            }

                            Binding {
                                target: rowOverride.item
                                when: rowOverride.item !== null
                                property: "index"
                                value: rowItem.index
                            }

                            Binding {
                                target: rowOverride.item
                                when: rowOverride.item !== null
                                property: "rowKey"
                                value: rowItem.row.key
                            }

                            Binding {
                                target: rowOverride.item
                                when: rowOverride.item !== null
                                property: "hovered"
                                value: rowHover.hovered
                            }
                        }

                        HoverHandler {
                            id: rowHover
                            onHoveredChanged: {
                                if (rowItem.custom === null)
                                    return;
                                if (rowHover.hovered
                                    && typeof rowItem.custom.onMouseEnter === "function")
                                    rowItem.custom.onMouseEnter({});
                                if (!rowHover.hovered
                                    && typeof rowItem.custom.onMouseLeave === "function")
                                    rowItem.custom.onMouseLeave({});
                            }
                        }

                        TapHandler {
                            objectName: "tableRowTap"

                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                control.rowTapped(rowItem.row);
                                if (rowItem.custom !== null
                                    && typeof rowItem.custom.onClick === "function")
                                    rowItem.custom.onClick({});
                            }
                        }

                        onHeightChanged: {
                            if (rowItem.isExpandRow)
                                control.setExpandHeight(rowItem.row.seq, expandBox.height
                                    - 2 * Theme.current.spacingBase - control.cellBorder);
                        }
                    }
                }

                Item {
                    objectName: "tablePlaceholder"

                    x: viewport.contentX
                    y: control.headerHeight
                    width: viewport.width
                    height: control.placeholderHeight
                    visible: control.isEmpty

                    Loader {
                        objectName: "tableEmptyNode"

                        anchors.centerIn: parent
                        visible: control.slotOf(control.empty) !== null
                        sourceComponent: control.slotOf(control.empty)
                    }

                    Text {
                        objectName: "tableEmptyText"

                        anchors.centerIn: parent
                        visible: control.slotOf(control.empty) === null
                        text: control.slotText(control.empty) !== ""
                            ? control.slotText(control.empty) : qsTr("暂无数据")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }

            SemiScrollBar {
                flickable: body
                orientation: Qt.Vertical
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: control.headerHeight
                anchors.bottom: parent.bottom
            }

            Rectangle {
                objectName: "tableLoadingMask"

                anchors.fill: parent
                visible: control.loading
                color: Theme.current.colorFill0

                Spin {
                    anchors.centerIn: parent
                    size: "middle"
                }
            }
        }

        Loader {
            objectName: "tableFooterHost"

            active: control.footerPresent
            visible: active
            width: stack.width
            height: control.footerHeight
            sourceComponent: footerBlock
        }

        Loader {
            objectName: "tablePaginationBottomHost"

            active: control.paginationBottom
            visible: active
            width: stack.width
            height: control.paginationHeight
            sourceComponent: paginationBlock
        }
    }

    // 列筛选面板：anchor 用表头那一格。
    TableFilterPanel {
        id: filterPanel

        objectName: "tableFilterPanel"

        table: control
    }

    // Popup 不是 Item，按子项走一遍是摸不到它的；与 TreeSelect._popup 同形给测试留口子。
    readonly property var _filterPanel: filterPanel

    // ============================================================ 槽位

    Component {
        id: titleBlock

        Rectangle {
            objectName: "tableTitleArea"

            color: control.bordered ? Theme.current.colorBg1 : "transparent"
            implicitHeight: control.titleHeight

            Loader {
                objectName: "tableTitleNode"

                anchors.left: parent.left
                anchors.leftMargin: control.bordered ? Theme.current.spacingBase : 0
                anchors.verticalCenter: parent.verticalCenter
                visible: control.slotOf(control.title) !== null
                sourceComponent: control.slotOf(control.title)
            }

            Text {
                objectName: "tableTitleText"

                anchors.left: parent.left
                anchors.leftMargin: control.bordered ? Theme.current.spacingBase : 0
                anchors.verticalCenter: parent.verticalCenter
                visible: control.slotOf(control.title) === null
                text: control.slotText(control.title)
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
            }
        }
    }

    Component {
        id: footerBlock

        Rectangle {
            objectName: "tableFooterArea"

            color: Theme.current.colorFill0
            implicitHeight: control.footerHeight

            Loader {
                objectName: "tableFooterNode"

                anchors.left: parent.left
                anchors.leftMargin: Theme.current.spacingBase
                anchors.verticalCenter: parent.verticalCenter
                visible: control.slotOf(control.footer) !== null
                sourceComponent: control.slotOf(control.footer)
            }

            Text {
                objectName: "tableFooterText"

                anchors.left: parent.left
                anchors.leftMargin: Theme.current.spacingBase
                anchors.verticalCenter: parent.verticalCenter
                visible: control.slotOf(control.footer) === null
                text: control.slotText(control.footer)
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
            }
        }
    }

    Component {
        id: paginationBlock

        Item {
            objectName: "tablePaginationOuter"

            implicitHeight: control.paginationHeight

            // 官方 TablePagination.tsx:31-51：renderPagination 返回节点时，
            // info 与 Pagination 都不画，整块换成调用方那个节点。
            Loader {
                id: customPagination

                objectName: "tablePaginationCustom"

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                active: control.renderPaginationNode() !== null
                visible: active
                sourceComponent: control.renderPaginationNode()

                Binding {
                    target: customPagination.item
                    when: customPagination.item !== null
                    property: "pagination"
                    value: control.paginationState
                }

                Binding {
                    target: customPagination.item
                    when: customPagination.item !== null
                    property: "info"
                    value: control.paginationText()
                }
            }

            Text {
                objectName: "tablePaginationInfo"

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: control.paginationText()
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeRegular
                visible: control.paginationText() !== "" && !customPagination.active
            }

            Pagination {
                objectName: "tablePagination"

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: customPagination.sourceComponent === null
                currentPage: control.paginationState !== null ? control.paginationState.currentPage : 1
                pageSize: control.paginationState !== null ? control.paginationState.pageSize : 10
                total: control.paginationState !== null ? control.paginationState.total : 0
                size: control.paginationState !== null && control.paginationState.size === "small"
                    ? Enums.Small : Enums.Default
                onChange: function (page) {
                    control.handlePageChange(page);
                }
            }
        }
    }

    // 行被点：官方 expandRowByClick 与 rowSelection.clickRow 两条路都挂在 tr 的点击上。
    function rowTapped(row) {
        if (row === undefined || row === null)
            return;
        if (row.kind === "section") {
            if (control.clickGroupedRowToExpand)
                control.toggleExpand(row.groupKey);
            return;
        }
        if (row.kind !== "data")
            return;
        const rs = control.rs;
        if (control.expandRowByClick && row.expandable === true)
            control.toggleExpand(row.key);
        else if (rs && rs.clickRow === true)
            control.toggleRow(row.key, !control.checkState(row.key).checked);
    }

    function openFilterPanel(column, anchor) {
        filterPanel.openFor(column, anchor);
    }

    // 初始化一次展开态：官方在 init() 里按 defaultExpandAllRows / expandAllRows /
    // defaultExpandedRowKeys 灌一次，之后不再随 dataSource 变化重算。
    Component.onCompleted: control.innerExpandedRowKeys = control.initExpandedKeys()
}
