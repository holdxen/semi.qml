import QtQuick
import QtTest
import Semi

// Table。规格照 packages/semi-ui/table/{Table,interface}.tsx 与
// semi-foundation/table/{foundation.ts,table.scss,variables.scss}，行高 / 表头高 /
// 选择列宽一律取编译后的 packages/semi-ui/dist/css/semi.css 字面值：
//   行高 = 单元格上下内边距*2 + 20 + 1 ⇒ default 53 / middle 45 / small 37，
//   表头行高 = 8*2 + 20 + 2 = 38，选择列 = $width-table_column_selection = 48，
//   分页外框最小高 = 60。
// 断言一律打在**渲染出来的**表头 / 格子 / 勾选框 / 图标上（objectName 见 src/Table.qml）；
// 只有官方那份状态机（排序三态、受控判定、全选半选计数）才直接读方法返回值。
// 三件摸不着的东西：Popup 系的筛选面板走 t._filterPanel（不是 Item，子项树里没有）；
// TapHandler 也不在 children 里，所以交互一律 mouseClick 到真正的可视项上，走完整事件派发。
TestCase {
    id: testCase

    name: "Table"
    when: windowShown
    width: 1200
    height: 900

    // 三行样本：size 乱序、tag 两档，够喂排序 / 筛选 / 选择；顺序一律用 key 断言
    readonly property var rows3: [
        { key: "1", name: "n1", size: 30, tag: "x" },
        { key: "2", name: "n2", size: 10, tag: "y" },
        { key: "3", name: "n3", size: 20, tag: "x" }
    ]

    readonly property var colsNameSize: [
        { title: "名称", dataIndex: "name", width: 200 },
        { title: "大小", dataIndex: "size" }
    ]

    property var events: []
    property var spies: []

    // render 用的节点：注入契约只给 text / record（多绑的属性调用方没声明会报警告）
    property Component chipNode: Component {
        Item {
            id: chip

            objectName: "chipNode"

            property var record: null
            property string text: ""

            implicitWidth: label.implicitWidth
            implicitHeight: label.implicitHeight

            Text {
                objectName: "chipText"

                text: "[" + chip.text + "]"
            }
        }
    }

    // rowSelection.renderCell 的节点：官方那一份参数对象端口放在 args 里
    property Component selCellNode: Component {
        Item {
            id: selCell

            objectName: "selCellNode"

            property var args: null

            implicitWidth: 40
            implicitHeight: 20

            Text {
                objectName: "selCellText"

                text: selCell.args !== null && selCell.args.selected === true ? "#" : "-"
            }
        }
    }

    // useFullRender 的格子：官方在这一格自己排勾选框 / 展开按钮 / 缩进，
    // 端口把状态与动作放进 options 递给节点
    property Component fullNode: Component {
        Item {
            id: full

            objectName: "fullNode"

            property var record: null
            property string text: ""
            property var options: null
            property var args: null           // 当表头 title 节点用时端口给的是 args

            implicitWidth: 120
            implicitHeight: 20

            Text {
                objectName: "fullText"

                text: String(full.text) + "|" + (full.options !== null
                    && full.options.selection !== undefined ? "S" : "-")
                    + (full.options !== null && full.options.expandIcon !== undefined ? "E" : "-")
                    + (full.options !== null && full.options.checked === true ? "C" : "-")
            }
        }
    }

    // components.body.row：整行包装，端口绑 record / index / rowKey / hovered
    property Component wrapRowNode: Component {
        Item {
            id: wrap

            property var record: null
            property int index: 0
            property string rowKey: ""
            property bool hovered: false

            objectName: "wrappedRow"

            implicitWidth: 100
            implicitHeight: 20

            Text {
                objectName: "wrapText"

                text: wrap.rowKey + "#" + wrap.index
            }
        }
    }

    // components.body.cell：整格接管，端口绑 text / record / index / column / ...
    property Component overCellNode: Component {
        Item {
            id: over

            property var record: null
            property string text: ""
            property int index: 0
            property var column: null
            property bool hovered: false
            property bool selected: false
            property bool expanded: false
            property var options: null

            objectName: "overCell"

            implicitWidth: 100
            implicitHeight: 20

            Text {
                objectName: "overText"

                text: String(over.text) + "@" + (over.column !== null ? over.column.dataIndex : "?")
            }
        }
    }

    // 自定义展开图标：官方 expandIcon 收到 {expanded, ...}
    property Component expandIconNode: Component {
        Text {
            objectName: "customExpandIcon"

            property var record: null
            property bool expanded: false

            text: expanded ? "V" : ">"
        }
    }

    property Component sortIconNode: Component {
        Text {
            objectName: "customSortIcon"

            property var sortOrder: false

            text: "S:" + String(sortOrder)
        }
    }

    property Component filterIconNode: Component {
        Text {
            objectName: "customFilterIcon"

            property bool filtered: false

            text: "F:" + String(filtered)
        }
    }

    property Component emptyNode: Component {
        Text {
            objectName: "customEmpty"

            text: "自定义空态"
        }
    }

    property Component filterDropdownNode: Component {
        Text {
            objectName: "customFilterDropdown"

            property var args: null          // 面板那一档端口的注入契约

            text: "面板节点"
        }
    }

    property Component groupSectionNode: Component {
        Text {
            objectName: "customGroupSection"

            property var groupKey: undefined

            text: "组:" + String(groupKey)
        }
    }

    property Component paginationNode: Component {
        Text {
            objectName: "customPagination"

            property var pagination: null
            property var info: null

            text: "P" + String(pagination !== null ? pagination.currentPage : "?")
        }
    }

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
        testCase.events = [];
    }

    function cleanup() {
        for (let i = 0; i < testCase.spies.length; ++i)
            testCase.spies[i].destroy();
        testCase.spies = [];
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    // 把某个信号挂上 spy（对象要 Qt.createQmlObject 建 —— 函数体里写 SignalSpy { } 不是合法 JS）
    function spill(item, names) {
        const out = {};
        for (let i = 0; i < names.length; ++i) {
            const spy = Qt.createQmlObject(
                "import QtQuick; import QtTest; SignalSpy { }", item, "spy");
            spy.target = item;
            spy.signalName = names[i];
            testCase.spies.push(spy);
            out[names[i]] = spy;
        }
        return out;
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "table");
    }

    function laid(qml, width) {
        const t = make(qml);
        t.width = width !== undefined ? width : 800;
        wait(60);
        return t;
    }

    function findAll(root, name, out) {
        if (out === undefined)
            out = [];
        const kids = root.children === undefined ? [] : root.children;
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i].objectName === name)
                out.push(kids[i]);
            // qmllint enable missing-property
            testCase.findAll(kids[i], name, out);
        }
        return out;
    }

    function one(root, name) {
        const hits = testCase.findAll(root, name);
        return hits.length > 0 ? hits[0] : null;
    }

    // 视觉顺序：QML 的 children 名单和上下顺序无关，只能按位置排
    function byPos(items) {
        return items.slice().sort((a, b) => (a.y !== b.y ? a.y - b.y : a.x - b.x));
    }

    // 每一格 / 每个图标都在每个候选项里建出来过，靠 visible 挑出真的那颗
    function shown(root, name) {
        return testCase.byPos(testCase.findAll(root, name).filter(i => i.visible));
    }

    function dataRows(t) {
        return testCase.byPos(testCase.findAll(t, "tableRow")).filter(r => r.kind === "data");
    }

    function rowKeys(t) {
        return testCase.dataRows(t).map(r => String(r.row.key));
    }

    // 每一数据行的单元格文本，按行序 -> 列序
    function gridTexts(t) {
        return testCase.dataRows(t).map(row => testCase.shown(row, "tableCellText").map(c => c.text));
    }

    function headerTexts(t) {
        return testCase.shown(t, "tableHeaderTitle").map(x => x.text);
    }

    function rowBoxes(t) {
        return testCase.shown(t, "tableRowCheckbox");
    }

    function absPos(root, items) {
        return items.slice().sort((a, b) => {
            const pa = a.mapToItem(root, 0, 0);
            const pb = b.mapToItem(root, 0, 0);
            return pa.y !== pb.y ? pa.y - pb.y : pa.x - pb.x;
        });
    }

    function columnOf(t, dataIndex) {
        const cols = t.leafColumns;
        for (let i = 0; i < cols.length; ++i)
            if (cols[i].dataIndex === dataIndex)
                return cols[i];
        return null;
    }

    function note(what) {
        testCase.events.push(what);
    }

    // ============================================================ 基本渲染

    function test_rendersHeaderAndCells() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(testCase.headerTexts(t), ["名称", "大小"]);
        compare(testCase.dataRows(t).length, 3);
        compare(testCase.gridTexts(t), [["n1", "30"], ["n2", "10"], ["n3", "20"]]);
        t.destroy();
    }

    function test_rowKeyDefaultsToKeyField() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(t.pageRowKeys, ["1", "2", "3"]);
        t.destroy();
    }

    function test_customRowKeyField() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ id: 'a', name: 'n1' }, { id: 'b', name: 'n2' }];"
            + " rowKey: 'id'; pagination: false }");
        compare(t.pageRowKeys, ["a", "b"]);
        t.destroy();
    }

    function test_rowHeightAndHeaderHeight() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(Math.round(t.rowHeight), 53);
        compare(Math.round(t.headerHeight), 38);
        const rows = testCase.dataRows(t);
        compare(rows.length, 3);
        fuzzyCompare(rows[1].y - rows[0].y, 53, 0.5);
        fuzzyCompare(rows[0].height, 53, 0.5);
        fuzzyCompare(testCase.byPos(testCase.findAll(t, "tableHeaderRow"))[0].height, 38, 0.5);
        t.destroy();
    }

    function test_sizeVariantsChangeRowHeight() {
        const small = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false; size: 'small' }");
        fuzzyCompare(small.rowHeight, 37, 0.5);     // 8*2 + 20 + 1
        const middle = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false; size: 'middle' }");
        fuzzyCompare(middle.rowHeight, 45, 0.5);    // 12*2 + 20 + 1
        small.destroy();
        middle.destroy();
    }

    function test_columnWidthsSplitRemainingSpace() {
        const t = testCase.laid("Table { columns: [{ title: 'a', dataIndex: 'name', width: 200 },"
            + " { title: 'b', dataIndex: 'size' }];"
            + " dataSource: testCase.rows3; pagination: false }", 800);
        compare(t.columnWidths, [200, 600]);
        compare(Math.round(t.contentWidth), 800);
        t.destroy();
    }

    function test_showHeaderFalseHasNoHeaderCells() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false; showHeader: false }");
        compare(testCase.shown(t, "tableHeaderCell").length, 0);
        compare(Math.round(t.headerHeight), 0);
        compare(testCase.dataRows(t).length, 3);
        t.destroy();
    }

    function test_emptyStateTextAndOverride() {
        const plain = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: []; pagination: false }");
        verify(plain.isEmpty);
        compare(testCase.one(plain, "tableEmptyText").text, "暂无数据");
        plain.destroy();

        const worded = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: []; pagination: false; empty: '没有一条' }");
        compare(testCase.one(worded, "tableEmptyText").text, "没有一条");
        worded.destroy();

        const nodal = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: []; pagination: false; empty: emptyNode }");
        // 节点档必须真的画出来（只读 text 的话，隐藏着的 Loader 项照样能读到值）
        compare(testCase.one(nodal, "customEmpty").visible, true);
        compare(testCase.one(nodal, "customEmpty").text, "自定义空态");
        compare(testCase.one(nodal, "tableEmptyText").visible, false);
        nodal.destroy();
    }

    function test_alignAndEllipsisReachTheCell() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 120,"
            + " align: 'right', ellipsis: true }];"
            + " dataSource: testCase.rows3; pagination: false }", 400);
        const cells = testCase.shown(t, "tableCellText");
        compare(cells.length, 3);
        verify((cells[0].horizontalAlignment & Text.AlignRight) !== 0);
        compare(cells[0].elide, Text.ElideRight);
        t.destroy();
    }

    function test_bodyCellsClipTheirContentByDefault() {
        // 官方虚拟化那一档的格子写的是 `overflow: hidden`（table.scss:393-400
        // `.semi-table-virtualized …-row > …-row-cell`），端口的表体是 ListView 回收 ⇒ 恒走这一档。
        // 少了这道裁，`elide: ElideNone` 的 Text 会整行画到邻列去；而邻列那层不透明底色
        // （tableCellHoverBase）只在悬浮的那一行亮 ⇒ 用户看到的就是「默认超出、悬浮才被裁」
        const t = testCase.laid("Table { columns: ["
            + "{ title: 'a', dataIndex: 'name', width: 100 },"
            + "{ title: 'b', dataIndex: 'size', width: 100 }];"
            + " dataSource: [{ id: '1', name: '一长串会超出列宽的文字内容', size: '' }];"
            + " rowKey: 'id'; pagination: false }", 400);
        const row = testCase.dataRows(t)[0];
        verify(row !== undefined, "要有一行数据");
        const cells = testCase.shown(row, "tableCell");
        compare(cells.length, 2);
        const text = testCase.shown(cells[0], "tableCellText")[0];
        // 先钉住「这一格确实装不下」，否则后面「邻列没有墨点」是空断言
        verify(text.implicitWidth > text.width,
            "文字自然宽 " + text.implicitWidth + " 要大于格子给的 " + text.width);
        compare(text.elide, Text.ElideNone, "没开 ellipsis 的格子不该带省略号");

        const dpr = Screen.devicePixelRatio;
        const img = testCase.grabImage(t);
        verify(img !== undefined && img !== null, "这一档平台读不到像素，钉不住这条");
        const rowTop = row.mapToItem(t, 0, 0).y;
        const y = Math.round((rowTop + row.height / 2) * dpr);
        const c0 = cells[0].mapToItem(t, 0, 0);
        const c1 = cells[1].mapToItem(t, 0, 0);
        // 底色参照取邻列自己的空白处（那一列的数据是空串）
        const bg = Qt.color(img.pixel(Math.round((c1.x + 80) * dpr), y));
        function inkCount(from, to) {
            let n = 0;
            for (let x = Math.round(from * dpr); x <= Math.round(to * dpr); ++x) {
                const c = Qt.color(img.pixel(x, y));
                if (Math.abs(c.r - bg.r) + Math.abs(c.g - bg.g) + Math.abs(c.b - bg.b) > 0.2)
                    n++;
            }
            return n;
        }
        // 判据按「画面上有没有」排在前，属性那两条是补充 —— 将来换成在内容层裁，
        // 报红的仍然是行为这一条
        verify(inkCount(c0.x + 4, c0.x + 90) > 0, "本列那一横条该有字，否则整条断言是空的");
        compare(inkCount(c1.x + 4, c1.x + 90), 0,
            "邻列那一横条不许出现本列溢出的字（超出部分要裁在格子边界上）");
        for (let i = 0; i < cells.length; ++i)
            compare(cells[i].clip, true, "第 " + i + " 格要裁（官方 -row-cell { overflow: hidden }）");
        t.destroy();
    }

    // ============================================================ JSX 写法

    function test_tableColumnDeclarationsBecomeColumns() {
        const t = testCase.laid("Table {"
            + " dataSource: testCase.rows3; pagination: false;"
            + " TableColumn { title: '名称'; dataIndex: 'name'; width: 200 }"
            + " TableColumn { title: '大小'; dataIndex: 'size' } }");
        compare(testCase.headerTexts(t), ["名称", "大小"]);
        compare(testCase.gridTexts(t), [["n1", "30"], ["n2", "10"], ["n3", "20"]]);
        t.destroy();
    }

    function test_configFormWinsWhenBothGiven() {
        // 官方注意事项：两种写法同时给时只认配置写法，不聚合
        const t = testCase.laid("Table { columns: [{ title: '配置', dataIndex: 'name' }];"
            + " dataSource: testCase.rows3; pagination: false;"
            + " TableColumn { title: 'JSX'; dataIndex: 'size' } }");
        compare(testCase.headerTexts(t), ["配置"]);
        compare(t.leafColumns.length, 1);
        t.destroy();
    }

    function test_nestedTableColumnMergesHeader() {
        const t = testCase.laid("Table { dataSource: testCase.rows3; pagination: false;"
            + " TableColumn { title: '基本信息';"
            + "     TableColumn { title: '名称'; dataIndex: 'name'; width: 200 }"
            + "     TableColumn { title: '大小'; dataIndex: 'size'; width: 100 } } }");
        compare(t.leafColumns.length, 2);
        compare(Math.round(t.headerHeight), 76);       // 两层表头 = 38 * 2
        compare(t.headerGrid.rows[0][0].colSpan, 2);
        compare(testCase.headerTexts(t), ["基本信息", "名称", "大小"]);
        t.destroy();
    }

    function test_childrenConfigMergesHeader() {
        const t = testCase.laid("Table { columns: ["
            + " { title: '基本信息', children: [ { title: '名称', dataIndex: 'name' },"
            + "   { title: '大小', dataIndex: 'size' } ] } ];"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(t.headerGrid.depth, 2);
        compare(t.headerGrid.rows[0][0].colSpan, 2);
        t.destroy();

        // 没有子列的那一格 rowSpan 自动补到最后一行
        const solo = testCase.laid("Table { columns: [ { title: '更多', dataIndex: 'tag' },"
            + " { title: '基本信息', children: [ { title: '名称', dataIndex: 'name' } ] } ];"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(solo.headerGrid.rows[0][0].rowSpan, 2);
        solo.destroy();
    }

    // ============================================================ 分页

    function test_paginationDefaultPageSize() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i })) }");
        compare(t.paginationState.pageSize, 10);          // DEFAULT_PAGE_SIZE
        compare(t.pageRowKeys.length, 10);
        compare(testCase.dataRows(t).length, 10);         // 只画当页
        compare(t.pageCount, 2);
        verify(testCase.one(t, "tablePagination") !== null);
        compare(testCase.one(t, "tablePaginationInfo").text, "显示第 1 条-第 10 条，共 12 条");
        t.destroy();
    }

    function test_paginationFalseDrawsEveryRow() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: false }");
        compare(t.paginationState, null);
        compare(testCase.dataRows(t).length, 12);
        compare(testCase.one(t, "tablePaginationBottomHost").active, false);
        t.destroy();
    }

    function test_handlePageChangeMovesWindowAndEmits() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: ({ pageSize: 5 });"
            + " onChanged: info => { note('chg:' + info.extra.changeType"
            + "   + ':' + info.pagination.currentPage) } }");
        compare(testCase.rowKeys(t), ["k0", "k1", "k2", "k3", "k4"]);
        t.handlePageChange(3);
        wait(20);
        compare(testCase.rowKeys(t), ["k10", "k11"]);     // 渲染的也是第三页
        compare(t.paginationState.currentPage, 3);
        compare(testCase.events, ["chg:pagination:3"]);
        t.destroy();
    }

    function test_paginationTopPosition() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: ({ pageSize: 5, position: 'top' }) }");
        compare(testCase.one(t, "tablePaginationTopHost").active, true);
        compare(testCase.one(t, "tablePaginationBottomHost").active, false);
        t.destroy();
    }

    function test_renderPaginationReplacesBlock() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: ({ pageSize: 5 }); renderPagination: paginationNode }");
        compare(testCase.one(t, "customPagination").text, "P1");
        compare(testCase.one(t, "tablePaginationInfo").visible, false);
        t.destroy();
    }

    function test_controlledPaginationKeepsWholeSource() {
        // 官方 limitPageDataSource：currentPage 受控时不按内部状态切片
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: ({ pageSize: 5, currentPage: 3 }) }");
        compare(t.paginationControlled, true);
        compare(t.pageRowKeys.length, 12);
        t.handlePageChange(2);
        wait(20);
        compare(t.pageRowKeys.length, 12);        // 内部状态不许覆盖受控入参
        t.destroy();
    }

    // ============================================================ 行选择

    function test_selectionColumnAndCheckboxes() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false; rowSelection: ({}) }");
        compare(t.leafColumns.length, 3);                 // 选择列排在最前
        compare(Math.round(t.columnWidths[0]), 48);       // $width-table_column_selection
        compare(testCase.rowBoxes(t).length, 3);
        compare(testCase.rowBoxes(t)[0].checked, false);
        compare(testCase.shown(t, "tableSelectAllCheckbox").length, 1);
        t.destroy();
    }

    function test_toggleRowSelectsAndFiresOnChange() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " rowSelection: ({ onChange: (keys) => { note('sel:' + keys.join(',')) } }) }");
        t.toggleRow("2", true);
        wait(20);
        compare(t.selectedRowKeys, ["2"]);
        compare(testCase.rowBoxes(t)[1].checked, true);
        compare(testCase.rowBoxes(t)[0].checked, false);
        compare(testCase.events, ["sel:2"]);
        t.toggleRow("2", false);
        wait(20);
        compare(t.selectedRowKeys, []);
        compare(testCase.events, ["sel:2", "sel:"]);
        t.destroy();
    }

    function test_selectAllCountsCurrentPageOnly() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: ({ pageSize: 5 }); rowSelection: ({}) }");
        t.toggleAll(true);
        wait(20);
        compare(t.selectedRowKeys, ["k0", "k1", "k2", "k3", "k4"]);
        compare(t.headerCheckState().checked, true);
        t.toggleAll(false);
        wait(20);
        compare(t.selectedRowKeys, []);
        t.destroy();
    }

    function test_headerHalfStateOnPartialSelection() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false; rowSelection: ({}) }");
        compare(t.headerCheckState(), { checked: false, indeterminate: false });
        t.toggleRow("1", true);
        wait(20);
        compare(t.headerCheckState(), { checked: false, indeterminate: true });
        const box = testCase.one(t, "tableSelectAllCheckbox");
        compare(box.indeterminate, true);
        compare(box.checked, false);
        t.toggleAll(true);
        wait(20);
        compare(t.headerCheckState(), { checked: true, indeterminate: false });
        t.destroy();
    }

    function test_getCheckboxPropsDisablesRow() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " rowSelection: ({ getCheckboxProps: record => ({ disabled: record.key === '2' }) }) }");
        compare(t.disabledRowKeys, ["2"]);
        const boxes = testCase.rowBoxes(t);
        compare(boxes[1].disabled, true);
        compare(boxes[0].disabled, false);
        t.toggleRow("2", true);
        wait(20);
        compare(t.selectedRowKeys, []);           // 禁用的行点不动
        t.toggleAll(true);
        wait(20);
        compare(t.selectedRowKeys, ["1", "3"]);   // 全选跳过禁用行
        compare(t.headerCheckState().checked, true);
        t.destroy();
    }

    function test_headerCheckboxDisabledFlag() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false; rowSelection: ({ disabled: true }) }");
        compare(testCase.one(t, "tableSelectAllCheckbox").disabled, true);
        t.destroy();
    }

    function test_selectionHiddenAndWidthAndFixed() {
        const hidden = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false; rowSelection: ({ hidden: true }) }");
        compare(hidden.leafColumns.length, 2);            // 列没了
        compare(hidden.selectionPresent, false);
        compare(testCase.shown(hidden, "tableSelectAllCheckbox").length, 0);
        hidden.destroy();

        const sized = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " rowSelection: ({ width: 80, fixed: true }) }");
        compare(Math.round(sized.columnWidths[0]), 80);
        compare(sized.fixedOf(sized.leafColumns[0]), "left");   // fixed:true 归一到 left
        verify(sized.isFixed(0));
        sized.destroy();
    }

    function test_selectionRenderCellNode() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " rowSelection: ({ renderCell: args => selCellNode }) }");
        const nodes = testCase.shown(t, "selCellNode");
        compare(nodes.length, 4);                     // 3 行 + 表头那一格
        compare(testCase.shown(t, "tableRowCheckbox").length, 0);
        const texts = () => testCase.absPos(t, testCase.findAll(t, "selCellText")).map(x => x.text);
        compare(texts(), ["-", "-", "-", "-"]);       // 第一个是表头那格
        t.toggleRow("1", true);
        wait(20);
        compare(t.selectedRowKeys, ["1"]);
        compare(texts(), ["-", "#", "-", "-"]);
        t.destroy();
    }

    function test_checkRelationRelatedCascades() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: 'p', name: 'P', children: [{ key: 'c1', name: 'C1' },"
            + "   { key: 'c2', name: 'C2' }] }];"
            + " pagination: false; defaultExpandAllRows: true;"
            + " rowSelection: ({ checkRelation: 'related' }) }");
        compare(testCase.rowKeys(t), ["p", "c1", "c2"]);
        t.toggleRow("p", true);
        wait(20);
        compare(testCase.rowBoxes(t).map(b => b.checked), [true, true, true]);
        t.toggleRow("c1", false);
        wait(20);
        compare(testCase.rowBoxes(t).map(b => b.checked), [false, false, true]);
        compare(testCase.rowBoxes(t)[0].indeterminate, true);   // 父节点剩半选
        compare(t.headerCheckState().indeterminate, true);
        t.destroy();
    }

    function test_clickRowSelectsFromAnywhereInRow() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " rowSelection: ({ clickRow: true }) }");
        mouseClick(testCase.dataRows(t)[1], 260, 10);
        wait(20);
        compare(t.selectedRowKeys, ["2"]);
        t.destroy();
    }

    function test_rowCheckboxClickTogglesSelection() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false; rowSelection: ({}) }");
        mouseClick(testCase.rowBoxes(t)[2], 8, 8);
        wait(20);
        compare(t.selectedRowKeys, ["3"]);
        t.destroy();
    }

    // ============================================================ 排序

    function test_sortClickCyclesThreeStates() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size }];"
            + " dataSource: testCase.rows3; pagination: false }");
        const col = testCase.columnOf(t, "size");
        const idx = t.leafIndexOf(col);
        compare(t.sortOrderAt(idx), false);
        t.handleSort(col);
        wait(20);
        compare(t.sortOrderAt(idx), "ascend");
        compare(testCase.rowKeys(t), ["2", "3", "1"]);
        t.handleSort(col);
        wait(20);
        compare(t.sortOrderAt(idx), "descend");
        compare(testCase.rowKeys(t), ["1", "3", "2"]);
        t.handleSort(col);
        wait(20);
        compare(t.sortOrderAt(idx), false);
        compare(testCase.rowKeys(t), ["1", "2", "3"]);   // 回到原序
        t.destroy();
    }

    function test_sortThroughHeaderCellClick() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const cells = testCase.byPos(testCase.shown(t, "tableHeaderCell"));
        compare(cells.length, 2);
        compare(testCase.shown(t, "tableColumnSorter").length, 1);   // 只有那一列有排序图标
        mouseClick(cells[1], 200, 10);
        wait(20);
        compare(t.sortOrderAt(1), "ascend");
        compare(testCase.rowKeys(t), ["2", "3", "1"]);
        t.destroy();
    }

    function test_sortResetsTheOtherColumn() {
        const t = testCase.laid("Table { columns: ["
            + " { dataIndex: 'name', sorter: (a, b) => (a.size - b.size) },"
            + " { dataIndex: 'size', sorter: (a, b) => b.size - a.size }];"
            + " dataSource: testCase.rows3; pagination: false }");
        t.handleSort(testCase.columnOf(t, "name"));
        wait(20);
        compare(t.sortOrderAt(0), "ascend");
        t.handleSort(testCase.columnOf(t, "size"));
        wait(20);
        compare(t.sortOrderAt(0), false);
        compare(t.sortOrderAt(1), "ascend");
        t.destroy();
    }

    function test_defaultSortOrderAppliesBeforeAnyClick() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size,"
            + "   defaultSortOrder: 'descend' }];"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(t.sortOrderAt(1), "descend");
        compare(testCase.rowKeys(t), ["1", "3", "2"]);
        t.destroy();
    }

    function test_controlledSortOrderIgnoresClick() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size,"
            + "   sortOrder: 'descend' }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        compare(t.isSortControlled(1), true);
        compare(testCase.rowKeys(t), ["1", "3", "2"]);
        t.handleSort(testCase.columnOf(t, "size"));
        wait(20);
        compare(t.sortOrderAt(1), "descend");               // 受控：点了不变
        const cells = testCase.byPos(testCase.shown(t, "tableHeaderCell"));
        mouseClick(cells[1], 200, 10);
        wait(20);
        compare(testCase.rowKeys(t), ["1", "3", "2"]);      // 点整格也不重排
        t.destroy();
    }

    function test_sorterIconColorsFollowState() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size }];"
            + " dataSource: testCase.rows3; pagination: false }");
        // 每一格都建了这两枚图标，只有可排序那列的 visible —— 一律按 visible 挑
        const up = () => testCase.shown(t, "tableSorterUp")[0];
        const down = () => testCase.shown(t, "tableSorterDown")[0];
        verify(up() !== undefined && down() !== undefined);
        compare(up().color, Theme.current.colorText2);
        compare(down().color, Theme.current.colorText2);
        const col = testCase.columnOf(t, "size");
        t.handleSort(col);
        wait(20);
        compare(testCase.shown(t, "tableSorterUp")[0].color, Theme.current.colorPrimary);
        t.handleSort(col);
        wait(20);
        compare(testCase.shown(t, "tableSorterDown")[0].color, Theme.current.colorPrimary);
        t.destroy();
    }

    function test_sortIconClickGoesThroughTheIconBox() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        mouseClick(testCase.shown(t, "tableColumnSorter")[0], 8, 12);
        wait(20);
        compare(t.sortOrderAt(1), "ascend");
        t.destroy();
    }

    function test_customSortIconReplacesArrows() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size,"
            + "   sortIcon: sortIconNode }];"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(testCase.shown(t, "customSortIcon")[0].text, "S:false");
        compare(testCase.shown(t, "tableSorterUp").length, 0);
        t.handleSort(testCase.columnOf(t, "size"));
        wait(20);
        compare(testCase.shown(t, "customSortIcon")[0].text, "S:ascend");
        t.destroy();
    }

    function test_showSortTipTexts() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size, showSortTip: true }];"
            + " dataSource: testCase.rows3; pagination: false }");
        const col = testCase.columnOf(t, "size");
        compare(t.nextSortTipText(col), "点击升序");
        t.handleSort(col);
        wait(20);
        compare(t.nextSortTipText(col), "点击降序");
        t.handleSort(col);
        wait(20);
        compare(t.nextSortTipText(col), "取消排序");
        t.handleSort(col);
        wait(20);
        compare(t.nextSortTipText(col), "点击升序");
        compare(t.sortTipOnCell(col), true);          // 这一列没有筛选器 ⇒ 提示挂整格
        compare(t.sortTipOnIcon(col), false);
        t.destroy();
    }

    function test_changedSignalCarriesSorterPayload() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size }];"
            + " dataSource: testCase.rows3; pagination: false;"
            + " onChanged: info => { note('chg:' + info.extra.changeType + ':'"
            + "   + info.sorter.dataIndex + ':' + info.sorter.sortOrder) } }");
        t.handleSort(testCase.columnOf(t, "size"));
        wait(20);
        compare(testCase.events, ["chg:sorter:size:ascend"]);
        t.destroy();
    }

    // ============================================================ 筛选

    function test_filterImmediateAppliesOnPick() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' },"
            + "   { text: 'y', value: 'y' }], onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }");
        const col = testCase.columnOf(t, "tag");
        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        compare(panel.visible, true);
        compare(panel.column.dataIndex, "tag");
        const rows = testCase.byPos(testCase.findAll(panel.contentItem, "tableFilterItem"));
        compare(rows.length, 2);
        mouseClick(rows[0], 20, 10);
        wait(60);
        compare(t.filteredValueAt(t.leafIndexOf(col)), ["x"]);
        compare(testCase.rowKeys(t), ["1", "3"]);
        compare(t.activeFilterInfo(), [{ dataIndex: "tag", filteredValue: ["x"] }]);
        t.destroy();
    }

    function test_filterPanelOpensFromHeaderIconClick() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(t._filterPanel.visible, false);
        mouseClick(testCase.shown(t, "tableColumnFilter")[0], 8, 8);
        wait(60);
        compare(t._filterPanel.visible, true);
        t.destroy();
    }

    function test_filterConfirmModeNeedsConfirm() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filterConfirmMode: 'confirm',"
            + "   filters: [{ text: 'x', value: 'x' }, { text: 'y', value: 'y' }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }");
        const col = testCase.columnOf(t, "tag");
        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        compare(panel.confirmMode, true);
        const rows = testCase.byPos(testCase.findAll(panel.contentItem, "tableFilterItem"));
        mouseClick(rows[0], 20, 10);
        wait(60);
        compare(t.filteredValueAt(1), []);                    // 没确认，数据不动
        compare(testCase.rowKeys(t), ["1", "2", "3"]);
        mouseClick(testCase.one(panel.contentItem, "tableFilterConfirm"), 10, 10);
        wait(60);
        compare(t.filteredValueAt(1), ["x"]);
        compare(testCase.rowKeys(t), ["1", "3"]);
        wait(320);
        compare(panel.opened, false);                          // 官方确认即收起
        t.destroy();
    }

    function test_filterResetKeepsOriginalValues() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filterConfirmMode: 'confirm',"
            + "   filters: [{ text: 'x', value: 'x' }], onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }");
        const col = testCase.columnOf(t, "tag");
        t.handleFilter(col, ["x"]);
        wait(20);
        compare(testCase.rowKeys(t), ["1", "3"]);
        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        mouseClick(testCase.one(panel.contentItem, "tableFilterReset"), 10, 10);
        wait(60);
        compare(t.filteredValueAt(1), ["x"]);        // 重置回到打开时的值，不是清空
        compare(panel.valuesOf(), ["x"], "面板里那一项的勾也得退回打开时的状态");
        compare(testCase.rowKeys(t), ["1", "3"]);
        t.destroy();
    }

    function test_filterMultipleFalsePicksOne() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filterMultiple: false,"
            + "   filters: [{ text: 'x', value: 'x' }, { text: 'y', value: 'y' }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }");
        const col = testCase.columnOf(t, "tag");
        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        compare(panel.multiple, false);
        const rows = testCase.byPos(testCase.findAll(panel.contentItem, "tableFilterItem"));
        mouseClick(rows[0], 20, 10);
        wait(60);
        compare(t.filteredValueAt(1), ["x"]);
        compare(testCase.rowKeys(t), ["1", "3"]);
        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        mouseClick(testCase.byPos(testCase.findAll(t._filterPanel.contentItem,
            "tableFilterItem"))[1], 20, 10);
        wait(60);
        compare(t.filteredValueAt(1), ["y"]);               // 单选：后者顶掉前者
        compare(testCase.rowKeys(t), ["2"]);
        t.destroy();
    }

    function test_controlledFilteredValueIsNotOverwritten() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filteredValue: ['y'],"
            + "   filters: [{ text: 'x', value: 'x' }], onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(t.isFilterControlled(1), true);
        compare(testCase.rowKeys(t), ["2"]);
        t.handleFilter(testCase.columnOf(t, "tag"), ["x"]);
        wait(20);
        compare(testCase.rowKeys(t), ["2"]);      // 受控：等调用方回灌
        t.destroy();
    }

    function test_filterChildrenRecordKeepsParents() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' }],"
            + "   onFilter: (v, r) => r.tag === v, filterChildrenRecord: true }];"
            + " dataSource: [{ key: 'p', name: 'P', tag: 'y', children: [{ key: 'c', name: 'C', tag: 'x' }] }];"
            + " pagination: false; defaultExpandAllRows: true }");
        t.handleFilter(testCase.columnOf(t, "tag"), ["x"]);
        wait(20);
        // 子级命中 ⇒ 父级带着这一条子级留下（官方 filterDataSource 的 children 分支）
        compare(testCase.rowKeys(t), ["p", "c"]);
        t.destroy();
    }

    function test_filterIconTurnsPrimaryWhenActive() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(testCase.shown(t, "tableFilterIcon")[0].color, Theme.current.colorText2);
        t.handleFilter(testCase.columnOf(t, "tag"), ["x"]);
        wait(20);
        compare(testCase.shown(t, "tableFilterIcon")[0].color, Theme.current.colorPrimary);
        t.destroy();
    }

    function test_customFilterIconReplacesFunnel() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filterIcon: filterIconNode, filters: [{ text: 'x',"
            + "   value: 'x' }], onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }");
        compare(testCase.shown(t, "customFilterIcon")[0].text, "F:false");
        compare(testCase.shown(t, "tableFilterIcon").length, 0);
        t.handleFilter(testCase.columnOf(t, "tag"), ["x"]);
        wait(20);
        compare(testCase.shown(t, "customFilterIcon")[0].text, "F:true");
        t.destroy();
    }

    function test_customFilterDropdownReplacesList() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filterDropdown: filterDropdownNode }];"
            + " dataSource: testCase.rows3; pagination: false }");
        t.openFilterPanel(testCase.columnOf(t, "tag"), testCase.one(t, "tableHeaderCell"));
        wait(60);
        compare(testCase.one(t._filterPanel.contentItem, "customFilterDropdown").text, "面板节点");
        compare(testCase.findAll(t._filterPanel.contentItem, "tableFilterItem").length, 0);
        t.destroy();
    }

    function test_renderFilterDropdownItemShapesEachRow() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' }],"
            + "   renderFilterDropdownItem: (item) => '标签' + item.value }];"
            + " dataSource: testCase.rows3; pagination: false }");
        t.openFilterPanel(testCase.columnOf(t, "tag"), testCase.one(t, "tableHeaderCell"));
        wait(60);
        const labels = testCase.byPos(testCase.findAll(t._filterPanel.contentItem,
            "tableFilterItemText"));
        compare(labels.map(i => i.text), ["标签x"]);
        t.destroy();
    }

    function test_changedSignalCarriesFilterPayload() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false;"
            + " onChanged: info => { note('chg:' + info.extra.changeType + ':'"
            + "   + info.filters[0].dataIndex + ':' + info.filters[0].filteredValue[0]) } }");
        t.handleFilter(testCase.columnOf(t, "tag"), ["x"]);
        wait(20);
        compare(testCase.events, ["chg:filter:tag:x"]);
        t.destroy();
    }

    function test_clearAllResetsSortFilterSelection() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size', sorter: (a, b) => a.size - b.size,"
            + "   filters: [{ text: 'x', value: '30' }], onFilter: (v, r) => String(r.size) === v }];"
            + " dataSource: testCase.rows3; pagination: false; rowSelection: ({}) }");
        const col = testCase.columnOf(t, "size");
        t.handleSort(col);
        t.handleFilter(col, ["30"]);
        t.toggleRow("1", true);
        wait(20);
        compare(testCase.rowKeys(t), ["1"]);
        compare(t.selectedRowKeys, ["1"]);
        t.clearAll();
        wait(20);
        compare(t.sortOrderAt(1), false);
        compare(t.filteredValueAt(1), []);
        compare(t.selectedRowKeys, []);
        compare(testCase.rowKeys(t), ["1", "2", "3"]);
        t.destroy();
    }

    // ============================================================ 展开行 / 树形

    function test_expandedRowRenderInsertsExtraRow() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " expandedRowRender: (record, index) => '详情' + record.key }");
        compare(testCase.findAll(t, "tableRow").filter(r => r.visible).length, 3);
        t.toggleExpand("2");
        wait(20);
        const kinds = testCase.byPos(testCase.findAll(t, "tableRow")).map(r => r.kind);
        compare(kinds, ["data", "data", "expand", "data"]);
        compare(testCase.shown(t, "tableExpandRowText")[0].text, "详情2");
        t.destroy();
    }

    function test_expandSignalsEmitted() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " expandedRowRender: (record) => '详情' + record.key;"
            + " onExpand: (expanded, record) => { note('exp:' + expanded + ':' + record.key) }"
            + " onExpandedRowsChange: list => { note('rows:' + list.map(r => r.key).join(',')) } }");
        t.toggleExpand("1");
        wait(20);
        compare(testCase.events, ["exp:true:1", "rows:1"]);
        t.toggleExpand("1");
        wait(20);
        compare(testCase.events, ["exp:true:1", "rows:1", "exp:false:1", "rows:"]);
        t.destroy();
    }

    function test_expandIconClickOpensRow() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " expandedRowRender: (record) => '详情' + record.key }");
        const boxes = testCase.shown(t, "tableExpandIconBox");
        compare(boxes.length, 3);
        mouseClick(boxes[0], 8, 8);
        wait(20);
        compare(t.expandedKeys, ["1"]);
        compare(testCase.shown(t, "tableExpandRowText").length, 1);
        t.destroy();
    }

    function test_expandIconRotatesNinetyDegrees() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " expandedRowRender: (record) => '详情' }");
        const box = testCase.shown(t, "tableExpandIconBox")[0];
        compare(Math.round(box.rotation), 0);
        t.toggleExpand("1");
        wait(250);
        compare(Math.round(testCase.shown(t, "tableExpandIconBox")[0].rotation), 90);
        t.destroy();
    }

    function test_expandRowByClickAndRowExpandable() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " expandedRowRender: (record) => '详情'; expandRowByClick: true;"
            + " rowExpandable: record => record.key !== '2' }");
        mouseClick(testCase.dataRows(t)[1], 260, 10);
        wait(20);
        compare(t.expandedKeys, []);                 // rowExpandable 说了不算，不展开
        mouseClick(testCase.dataRows(t)[0], 260, 10);
        wait(20);
        compare(t.expandedKeys, ["1"]);
        t.destroy();
    }

    function test_treeRowsDepthAndIndent() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 300 }];"
            + " dataSource: [{ key: 'p', name: 'P', children: [{ key: 'c', name: 'C' },"
            + "   { key: 'd', name: 'D', children: [{ key: 'g', name: 'G' }] }] }];"
            + " pagination: false; defaultExpandAllRows: true }", 600);
        const rows = testCase.byPos(testCase.findAll(t, "tableRow"));
        compare(rows.map(r => r.row.depth), [0, 1, 1, 2]);
        compare(testCase.rowKeys(t), ["p", "c", "d", "g"]);
        const lefts = rows.map(r => testCase.shown(r, "tableCellContent").map(c => c.x)[0]);
        fuzzyCompare(lefts[1] - lefts[0], 20, 0.5);      // indentSize 一档
        fuzzyCompare(lefts[3] - lefts[0], 40, 0.5);      // 两档
        t.destroy();
    }

    function test_indentSizePropMovesChildren() {
        // 三档都可展开 ⇒ 第二行相对第一行正好让出一格 indentSize
        const src = "Table { columns: [{ dataIndex: 'name', width: 300 }];"
            + " dataSource: [{ key: 'p', name: 'P', children: [{ key: 'b', name: 'B',"
            + "   children: [{ key: 'c', name: 'C' }] }] }]; pagination: false;"
            + " defaultExpandAllRows: true";
        const base = testCase.laid(src + " }", 600);
        const wide = testCase.laid(src + "; indentSize: 40 }", 600);
        const gap = (v) => {
            const rows = testCase.byPos(testCase.findAll(v, "tableRow"));
            const lefts = rows.map(r => testCase.shown(r, "tableCellContent").map(c => c.x)[0]);
            return lefts[1] - lefts[0];
        };
        fuzzyCompare(gap(base), 20, 0.5);
        fuzzyCompare(gap(wide), 40, 0.5);
        base.destroy();
        wide.destroy();
    }

    function test_hideExpandedColumnFalseAddsItsOwnColumn() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " expandedRowRender: (record) => '详情'; hideExpandedColumn: false }");
        compare(t.leafColumns.length, 3);
        compare(Math.round(t.columnWidths[0]), 48);
        compare(testCase.shown(t, "tableCellContent")[0] !== undefined, true);
        // 展开单独成列 ⇒ 格子里不再画那颗图标
        compare(testCase.shown(t, "tableExpandIconBox").length, 0);
        compare(testCase.shown(t, "tableExpandColumnCell").length, 3);
        t.destroy();
    }

    function test_customExpandIconReplacesCaret() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " expandedRowRender: (record) => '详情'; expandIcon: expandIconNode }");
        const icons = () => testCase.shown(t, "customExpandIcon").map(i => i.text);
        compare(icons(), [">", ">", ">"]);
        t.toggleExpand("1");
        wait(20);
        compare(icons()[0], "V");
        t.destroy();
    }

    function test_defaultExpandedRowKeysAndControlledKeys() {
        const opened = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " expandedRowRender: (record) => '详情'; defaultExpandedRowKeys: ['3'] }");
        compare(opened.expandedKeys, ["3"]);
        compare(testCase.byPos(testCase.findAll(opened, "tableRow")).map(r => r.kind),
            ["data", "data", "data", "expand"]);
        opened.destroy();

        const ctrl = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " expandedRowRender: (record) => '详情'; expandedRowKeys: ['2'] }");
        ctrl.toggleExpand("1");
        wait(20);
        compare(ctrl.expandedKeys, ["2"]);           // 受控：内部 toggle 不覆盖
        ctrl.destroy();
    }

    function test_expandAllRowsOpensEverything() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: '1', name: 'a' }, { key: '2', name: 'b' }];"
            + " pagination: false; expandedRowRender: (record) => '详情'; expandAllRows: true }");
        compare(testCase.byPos(testCase.findAll(t, "tableRow")).map(r => r.kind),
            ["data", "expand", "data", "expand"]);
        t.destroy();
    }

    // ============================================================ 固定列 / 横向滚动

    function test_fixedColumnsStayPutWhenScrolling() {
        const t = testCase.laid("Table { columns: ["
            + " { title: 'a', dataIndex: 'name', width: 300, fixed: 'left' },"
            + " { title: 'b', dataIndex: 'size', width: 300 },"
            + " { title: 'c', dataIndex: 'tag', width: 300, fixed: 'right' }];"
            + " dataSource: testCase.rows3; pagination: false; scroll: ({ x: 900 }) }", 700);
        compare(t.contentWidth, 900);
        const view = testCase.one(t, "tableViewport");
        compare(t.scrolledFromLeft, false);
        // 还没滚的时候右固定就已经被夹到视口右端（自然位在 600）
        const atRest = testCase.byPos(testCase.findAll(testCase.dataRows(t)[0], "tableCell"));
        compare(Math.round(atRest[2].x), 400, "min(自然位, 视口宽 − 列宽)");
        view.contentX = 200;
        wait(20);
        compare(t.scrolledFromLeft, true);
        const cells = testCase.byPos(testCase.findAll(testCase.dataRows(t)[0], "tableCell"));
        compare(Math.round(cells[0].x), 0);                  // 左固定不跟滚
        compare(Math.round(cells[1].x), 100);                // 中间那列跟着滚
        compare(Math.round(cells[2].x), 400);                // 右固定钉在视口右端
        compare(cells[0].z, 6);
        compare(cells[1].z, 0);
        // 阴影那条阈值是 0.5px，不是「滚出一整格才算」
        view.contentX = 5;
        wait(20);
        compare(t.scrolledFromLeft, true, "contentX 5 就算滚出左界");
        t.destroy();
    }

    function test_fixedShadowFlagsOnScrollFromRight() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 300 },"
            + " { dataIndex: 'size', width: 300, fixed: 'right' }];"
            + " dataSource: testCase.rows3; pagination: false; scroll: ({ x: 900 }) }", 600);
        compare(t.scrolledFromRight, true);          // 还没滚到最右
        testCase.one(t, "tableViewport").contentX = 300;
        wait(20);
        compare(t.scrolledFromRight, false);
        t.destroy();
    }

    // ============================================================ 合并单元格

    function test_cellColSpanZeroHidesTheCoveredCell() {
        const t = testCase.laid("Table { columns: ["
            + " { dataIndex: 'name', width: 200, render: (text, record, index) =>"
            + "   (index === 0 ? { children: text, props: ({ colSpan: 2 }) } : text) },"
            + " { dataIndex: 'size', width: 200, render: (text, record, index) =>"
            + "   (index === 0 ? { children: text, props: ({ colSpan: 0 }) } : text) },"
            + " { dataIndex: 'tag', width: 200 }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const cells = testCase.absPos(t, testCase.findAll(t, "tableCell"));
        compare(testCase.shown(t, "tableCell").length, 8);     // 9 - 1 被跨掉的
        compare(Math.round(cells[0].width), 400);              // 200 + 200
        compare(testCase.gridTexts(t)[0], ["n1", "x"]);        // 被跨掉的那格没字，第三列紧跟着
        t.destroy();
    }

    function test_rowSpanCellTakesTwoRowsOfHeight() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 200 },"
            + " { dataIndex: 'size', width: 200, render: (text, record, index) =>"
            + "   (index === 0 ? { children: text, props: ({ rowSpan: 2 }) }"
            + "    : (index === 1 ? { children: text, props: ({ rowSpan: 0 }) } : text)) }];"
            + " dataSource: testCase.rows3; pagination: false }", 400);
        const tall = testCase.byPos(testCase.findAll(t, "tableCell"))
            .filter(c => Math.round(c.height) === 106);
        compare(tall.length, 1);
        compare(testCase.dataRows(t).length, 3);               // 被占的那格不画，行还在
        t.destroy();
    }

    // ============================================================ 分组

    function test_groupByInsertsSectionRows() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' },"
            + " { dataIndex: 'size' }];"
            + " dataSource: [{ key: '1', name: 'n1', size: 30, tag: 'x' },"
            + "   { key: '2', name: 'n2', size: 10, tag: 'y' }];"
            + " pagination: false; groupBy: 'tag' }");
        const rows = testCase.byPos(testCase.findAll(t, "tableRow"));
        compare(rows.map(r => r.kind), ["section", "section"]);
        // 组头默认就是组键，且官方默认收起
        compare(testCase.shown(t, "tableSectionText").map(s => s.text), ["x", "y"]);
        compare(testCase.dataRows(t).length, 0);
        t.destroy();
    }

    function test_groupRowsCollapseAndExpand() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: '1', name: 'n1', tag: 'x' }, { key: '2', name: 'n2', tag: 'x' }];"
            + " pagination: false; groupBy: 'tag' }");
        compare(testCase.dataRows(t).length, 0);
        t.toggleExpand("x");
        wait(20);
        compare(testCase.rowKeys(t), ["1", "2"]);
        compare(testCase.byPos(testCase.findAll(t, "tableRow")).map(r => r.kind),
            ["section", "data", "data"]);
        t.destroy();
    }

    function test_expandAllGroupRowsOpensThem() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: '1', name: 'n1', tag: 'x' }];"
            + " pagination: false; groupBy: 'tag'; expandAllGroupRows: true }");
        compare(testCase.rowKeys(t), ["1"]);
        t.destroy();
    }

    function test_renderGroupSectionNodeGetsKey() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: '1', name: 'n1', tag: 'x' }, { key: '2', name: 'n2', tag: 'y' }];"
            + " pagination: false; groupBy: 'tag'; renderGroupSection: (key, group) =>"
            + "   groupSectionNode }");
        compare(testCase.byPos(testCase.findAll(t, "customGroupSection")).map(x => x.text),
            ["组:x", "组:y"]);
        t.destroy();
    }

    function test_clickGroupedRowToExpandTogglesGroup() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: '1', name: 'n1', tag: 'x' }];"
            + " pagination: false; groupBy: 'tag'; clickGroupedRowToExpand: true }");
        const section = testCase.byPos(testCase.findAll(t, "tableRow"))[0];
        mouseClick(section, 40, 10);
        wait(20);
        compare(t.expandedKeys, ["x"]);
        compare(testCase.rowKeys(t), ["1"]);
        t.destroy();
    }

    // ============================================================ onRow / onCell

    function test_onRowBackgroundAndClickHandler() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " onRow: record => ({ style: { background: record.key === '2' ? '#ff0000' : undefined },"
            + "   onClick: () => note('row:' + record.key) }) }", 600);
        const paints = testCase.dataRows(t).map(r => testCase.one(r, "tableRowBackground"));
        compare(paints[1].color, "#ff0000");
        compare(paints[0].color, Theme.current.colorBg1);   // 没给 style 的那行留默认底
        mouseClick(testCase.dataRows(t)[0], 260, 10);
        wait(20);
        compare(testCase.events, ["row:1"]);
        t.destroy();
    }

    function test_onCellPropsPaintThatCell() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 200,"
            + " onCell: record => ({ style: { background: record.key === '1' ? '#00ff00' : undefined } }) },"
            + " { dataIndex: 'size', width: 200 }];"
            + " dataSource: [{ key: '1', name: 'n1', size: 1 }]; pagination: false }", 400);
        const cells = testCase.byPos(testCase.findAll(t, "tableCell"));
        compare(testCase.findAll(cells[0], "tableCellBackground")[0].color, "#00ff00");
        compare(testCase.findAll(cells[0], "tableCellBackground")[0].visible, true);
        t.destroy();
    }

    function test_stripeRowsComeFromOnRow() {
        // 官方斑马纹是 demo 自己在 onRow 上挂 style，端口照官方路子给
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 4 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: false; onRow: (record, index) => ({ style: { background:"
            + "   index % 2 === 1 ? '#eeeeee' : undefined } }) }");
        const paints = testCase.dataRows(t).map(r => testCase.one(r, "tableRowBackground"));
        compare(paints[1].color, "#eeeeee");
        compare(paints[3].color, "#eeeeee");
        compare(paints[0].color, Theme.current.colorBg1);
        compare(paints[2].color, Theme.current.colorBg1);
        t.destroy();
    }

    function test_componentsBodyRowOverrideReceivesState() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: 'a', name: 'n1' }, { key: 'b', name: 'n2' }];"
            + " pagination: false; components: ({ body: ({ row: wrapRowNode }) }) }");
        compare(testCase.shown(t, "wrappedRow").length, 2);
        compare(testCase.byPos(testCase.findAll(t, "wrapText")).map(w => w.text), ["a#0", "b#1"]);
        t.destroy();
    }

    function test_componentsBodyCellOverrideReceivesFullContract() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 200 },"
            + " { dataIndex: 'size', width: 200 }];"
            + " dataSource: [{ key: 'a', name: 'n1', size: 9 }];"
            + " pagination: false; components: ({ body: ({ cell: overCellNode }) }) }", 400);
        const texts = testCase.byPos(testCase.findAll(t, "overText")).map(o => o.text);
        compare(texts, ["n1@name", "9@size"]);
        // 注入契约里 record / index / column 必须是**原物**（modelData 那一份是拷贝，
        // 函数字段与身份都会丢），这里直接按格子顺序回读
        const nodes = testCase.byPos(testCase.findAll(t, "overCell"));
        compare(String(nodes[0].record.key), "a");
        compare(nodes[0].index, 0);
        compare(nodes[0].column, testCase.columnOf(t, "name"));
        compare(nodes[1].column, testCase.columnOf(t, "size"));
        t.destroy();
    }

    function test_useFullRenderOptionsCarryMarksAndActions() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 300,"
            + " useFullRender: true, render: (text, record, index, options) => fullNode }];"
            + " dataSource: [{ key: 'a', name: 'n1' }]; pagination: false; rowSelection: ({}) }");
        const text = testCase.one(t, "fullText");
        compare(text.text, "n1|S--");                 // 有勾选框槽位、没展开槽位、未选中
        const opts = text.parent.options;
        compare(typeof opts.toggleSelection, "function");
        opts.toggleSelection(true);
        wait(20);
        compare(t.selectedRowKeys, ["a"]);
        compare(testCase.one(t, "fullText").text, "n1|S-C");
        t.destroy();
    }

    function test_useFullRenderHeaderTitleGetsSelectionMark() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 300,"
            + " useFullRender: true, title: (args) => fullNode, render: () => fullNode }];"
            + " dataSource: [{ key: 'a', name: 'n1' }]; pagination: false; rowSelection: ({}) }");
        const nodes = testCase.absPos(t, testCase.findAll(t, "fullNode"));
        compare(nodes.length, 2);                       // 表头一颗、格子一颗
        const headNode = nodes.filter(n => n.parent.objectName === "tableHeaderTitleNode")[0];
        const args = headNode.args;
        compare(args.selection, "selection");
        verify(typeof args.selectAll === "function");
        t.destroy();
    }

    // ============================================================ 拖宽 / 滚动 / 虚拟

    function test_resizableHandleAppliesWidth() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 200 },"
            + " { dataIndex: 'size', width: 200 }];"
            + " dataSource: testCase.rows3; pagination: false; resizable: true }", 400);
        compare(testCase.shown(t, "tableResizerHandle").length, 2);
        t.applyColumnWidth(0, 320);
        wait(20);
        compare(t.columnWidths[0], 320);
        compare(Math.round(testCase.byPos(testCase.findAll(t, "tableCell"))[0].width), 320);
        t.destroy();
    }

    function test_columnResizeFalseSkipsThatHandle() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 200 },"
            + " { dataIndex: 'size', width: 200, resize: false }];"
            + " dataSource: testCase.rows3; pagination: false; resizable: true }", 400);
        compare(testCase.shown(t, "tableResizerHandle").length, 1);
        t.destroy();
    }

    function test_resizableOffByDefault() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 200 }];"
            + " dataSource: testCase.rows3; pagination: false }", 400);
        compare(testCase.shown(t, "tableResizerHandle").length, 0);
        t.destroy();
    }

    function test_scrollYFixesBodyHeight() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 30 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: false; scroll: ({ y: 300 }) }", 600);
        fuzzyCompare(t.bodyHeight, 300, 0.5);
        const body = testCase.one(t, "tableBody");
        fuzzyCompare(body.height, 300, 0.5);
        fuzzyCompare(body.contentHeight, 30 * 53, 1);
        verify(body.contentHeight > body.height);
        t.destroy();
    }

    function test_withoutScrollYBodyGrowsWithContent() {
        // 官方 .semi-table-body 只有 overflow:auto，没有 max-height ⇒ 表格内容多高画多高
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 20 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: false }", 600);
        compare(t.scrollY, null);
        fuzzyCompare(t.bodyHeight, 20 * 53, 1);
        fuzzyCompare(t.implicitHeight, 38 + 20 * 53, 1);
        t.destroy();
    }

    function test_virtualizedKeepsRowsPricedPerItem() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 60 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: false; scroll: ({ y: 300 }); virtualized: true }", 600);
        fuzzyCompare(t.itemSizeValue, 53, 0.5);
        const body = testCase.one(t, "tableBody");
        fuzzyCompare(body.contentHeight, 60 * 53, 1);
        // 视口只装得下 5 行多一点 ⇒ 画出来的行远少于 60
        verify(testCase.findAll(t, "tableRow").length < 20);
        t.destroy();
    }

    // ============================================================ 外框与状态罩

    function test_titleAndFooterJoinChromeHeight() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: testCase.rows3; pagination: false;"
            + " title: 'T'; footer: 'F' }", 600);
        compare(testCase.one(t, "tableTitleText").text, "T");
        compare(testCase.one(t, "tableFooterText").text, "F");
        fuzzyCompare(t.titleHeight, 2 * 16 + 20, 0.5);
        fuzzyCompare(t.chromeHeight, t.titleHeight + t.headerHeight + t.footerHeight, 0.5);
        t.destroy();
    }

    function test_loadingMaskCoversBody() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: testCase.rows3; pagination: false; loading: false }", 600);
        compare(testCase.one(t, "tableLoadingMask").visible, false);
        t.loading = true;
        wait(20);
        compare(testCase.one(t, "tableLoadingMask").visible, true);
        t.destroy();
    }

    function test_renderNodeReceivesTextAndRecord() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 200,"
            + " render: (text, record, index) => chipNode }, { dataIndex: 'size' }];"
            + " dataSource: testCase.rows3; pagination: false }", 400);
        const nodes = testCase.shown(t, "chipNode");
        compare(nodes.length, 3);
        compare(testCase.byPos(nodes).map(n => n.text), ["n1", "n2", "n3"]);
        compare(String(testCase.byPos(nodes)[0].record.key), "1");
        compare(testCase.byPos(testCase.findAll(t, "chipText")).map(c => c.text),
            ["[n1]", "[n2]", "[n3]"]);
        t.destroy();
    }

    function test_headerTitleComponentAndFunctionForms() {
        const t = testCase.laid("Table { columns: [{ title: chipNode, dataIndex: 'name' },"
            + " { title: (args) => '函数标题', dataIndex: 'size' }];"
            + " dataSource: testCase.rows3; pagination: false }", 400);
        compare(testCase.shown(t, "chipNode").length, 1);
        verify(testCase.one(t, "tableHeaderTitleNode") !== null);
        compare(testCase.headerTexts(t), ["函数标题"]);    // 换节点那格的文字层不显示
        t.destroy();
    }

    // ============================================================ 变异复核补的断言
    // 下面这一批是 tests/tmp_table_mutate.py 第一轮「打不红」的条目逐条对出来的：
    // 每一条都对应一个原本没有落地判据的行为（等价变异另记在 PROGRESS.md 的取舍里）。

    // 分页外框最小高 60；position 缺省是 bottom（PAGINATION_POSITIONS[0]）
    function test_paginationBlockHeightAndDefaultPosition() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i })) }", 600);
        compare(t.paginationHeight, 60, "$height-table_pagination_outer_min");
        const host = testCase.one(t, "tablePaginationBottomHost");
        compare(host.active, true);
        fuzzyCompare(host.height, 60, 0.5);
        compare(testCase.one(t, "tablePaginationTopHost").active, false);
        compare(t.paginationTop, false);
        t.destroy();
    }

    // 组行高 = 20 + 20 + 1 = 41（官方 .semi-table-row-group 那条上下内边距）
    function test_groupSectionRowHeight() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: '1', name: 'n1', tag: 'x' }];"
            + " pagination: false; groupBy: 'tag' }", 600);
        fuzzyCompare(t.sectionRowHeight, 41, 0.5);
        const section = testCase.byPos(testCase.findAll(t, "tableRow"))[0];
        compare(section.kind, "section");
        fuzzyCompare(section.height, 41, 0.5);
        t.destroy();
    }

    // 固定列的表头格要压在跟着滚的那一格之上
    function test_fixedHeaderCellsLiftAboveScrolling() {
        const t = testCase.laid("Table { columns: ["
            + " { title: 'a', dataIndex: 'name', width: 300, fixed: 'left' },"
            + " { title: 'b', dataIndex: 'size', width: 300 }];"
            + " dataSource: testCase.rows3; pagination: false; scroll: ({ x: 600 }) }", 600);
        const cells = testCase.byPos(testCase.findAll(t, "tableHeaderCell"));
        compare(cells[0].z, 6, "贴住的表头格抬到 6");
        compare(cells[1].z, 2, "普通表头格留在 2");
        t.destroy();
    }

    // 官方 selectRow 里 `if (at < 0)` 那一条去重
    function test_doubleSelectSameRowDoesNotDuplicate() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: testCase.rows3; pagination: false; rowSelection: ({}) }", 600);
        t.toggleRow("1", true);
        t.toggleRow("1", true);
        wait(20);
        compare(t.selectedRowKeys, ["1"]);
        t.destroy();
    }

    // 没筛任何值时 changed 的 filters 必须是空数组（isActiveFilter 要认 values.length）
    function test_sorterChangeReportsNoActiveFilters() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', sorter: (a, b) => 0,"
            + " filters: [{ text: 'x', value: 'x' }], onFilter: (v, r) => r.name === v }];"
            + " dataSource: testCase.rows3; pagination: false;"
            + " onChanged: info => { note('f' + info.filters.length) } }", 600);
        t.handleSort(testCase.columnOf(t, "name"));
        wait(20);
        compare(testCase.events, ["f0"]);
        t.destroy();
    }

    // 排序块与筛选块都要从标题的可画宽里扣掉（图标 16 + 间距 4）
    function test_sorterBlockShrinksHeaderTitle() {
        const plain = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const plainBox = testCase.one(plain, "tableHeaderTitleRow");
        fuzzyCompare(testCase.one(plain, "tableHeaderTitle").width, plainBox.width, 0.5);
        plain.destroy();

        const sorted = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a',"
            + " sorter: (x, y) => 0 }]; dataSource: testCase.rows3; pagination: false }", 600);
        const sBox = testCase.one(sorted, "tableHeaderTitleRow");
        fuzzyCompare(testCase.one(sorted, "tableHeaderTitle").width, sBox.width - 20, 0.5);
        sorted.destroy();

        const both = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a',"
            + " sorter: (x, y) => 0, filters: [{ text: 'x', value: 'x' }],"
            + " onFilter: (v, r) => r.name === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const bBox = testCase.one(both, "tableHeaderTitleRow");
        fuzzyCompare(testCase.one(both, "tableHeaderTitle").width, bBox.width - 40, 0.5);
        both.destroy();
    }

    // 官方 filters 带 children 时端口把二级拍平、按 level 递进缩进
    function test_nestedFiltersFlattenWithIndent() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x',"
            + "   children: [{ text: 'y', value: 'y' }] }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const col = testCase.columnOf(t, "tag");
        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        compare(panel.flatList.length, 2);
        compare(panel.flatList[1].level, 1);
        compare(panel.itemMargin(0), 16);
        compare(panel.itemMargin(1), 24, "16 + level*8（$spacing-dropdown 二级递进）");
        const boxes = testCase.byPos(testCase.findAll(panel.contentItem,
            "tableFilterItemCheckbox"));
        compare(boxes.length, 2);
        compare(boxes[1].anchors.leftMargin, 24);
        t.destroy();
    }

    // 菜单最高 290（$height-table_column_filter_dropdown）、单项高 36（Dropdown 项 8/16 内边距）
    function test_filterListCapsHeightAndItemMetrics() {
        const many = [];
        for (let i = 0; i < 20; ++i)
            many.push({ text: "f" + i, value: "f" + i });
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filters: " + JSON.stringify(many)
            + ", onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        t.openFilterPanel(testCase.columnOf(t, "tag"), testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        compare(panel.flatList.length, 20);
        const list = testCase.one(panel.contentItem, "tableFilterList");
        compare(list.height, 290);
        compare(testCase.one(panel.contentItem, "tableFilterItems").height, 20 * 36);
        compare(testCase.byPos(testCase.findAll(panel.contentItem, "tableFilterItem"))[0].height, 36);
        t.destroy();
    }

    // 面板宽度：下限 140（与 Dropdown 同源）、上限 280（$width-dropdown）
    function test_filterPanelWidthClamps() {
        const shortTable = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filters: [{ text: '短', value: 'x' }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        shortTable.openFilterPanel(testCase.columnOf(shortTable, "tag"),
            testCase.one(shortTable, "tableHeaderCell"));
        wait(60);
        compare(shortTable._filterPanel.implicitWidth, 140, "内容比下限还短就走 140");
        shortTable.destroy();

        const longFilters = [{ text: "这一条筛选项的文案非常长一定会超出下拉的最大宽度限制",
            value: "x" }];
        const longTable = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filters: " + JSON.stringify(longFilters)
            + ", onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        longTable.openFilterPanel(testCase.columnOf(longTable, "tag"),
            testCase.one(longTable, "tableHeaderCell"));
        wait(60);
        compare(longTable._filterPanel.implicitWidth, 280, "$width-dropdown 上限");
        longTable.destroy();
    }

    // filterMultiple 缺省是 true（官方 ColumnFilter 的默认）
    function test_filterPanelDefaultsToMultiple() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        t.openFilterPanel(testCase.columnOf(t, "tag"), testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        compare(panel.multiple, true);
        compare(testCase.byPos(testCase.findAll(panel.contentItem,
            "tableFilterItemCheckbox"))[0].visible, true);
        compare(testCase.shown(panel.contentItem, "tableFilterItemText").length, 0);
        t.destroy();
    }

    // confirm 档：勾选先落暂存，面板的当前值读的是 tempValues，勾上的项立刻打勾
    function test_confirmModeTracksTempValues() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filterConfirmMode: 'confirm',"
            + "   filters: [{ text: 'x', value: 'x' }, { text: 'y', value: 'y' }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const col = testCase.columnOf(t, "tag");
        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        const items = testCase.byPos(testCase.findAll(panel.contentItem, "tableFilterItem"));
        mouseClick(items[1], 20, 10);
        wait(60);
        compare(panel.valuesOf(), ["y"]);
        compare(t.filteredValueAt(1), [], "没按确定之前数据不动");
        const boxes = testCase.byPos(testCase.findAll(panel.contentItem,
            "tableFilterItemCheckbox"));
        compare(boxes[1].checked, true);
        compare(boxes[0].checked, false);
        t.destroy();
    }

    // 单选档：点第二顶掉第一、再点同一个取消、选完立刻收面板、选中项文案走主色
    function test_singleSelectPanelBehaviour() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filterMultiple: false,"
            + "   filters: [{ text: 'x', value: 'x' }, { text: 'y', value: 'y' }],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const col = testCase.columnOf(t, "tag");
        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        compare(t._filterPanel.multiple, false);
        const first = testCase.byPos(testCase.findAll(t._filterPanel.contentItem,
            "tableFilterItem"));
        compare(testCase.shown(t._filterPanel.contentItem, "tableFilterItemCheckbox").length, 0,
            "单选档不画勾选框");
        mouseClick(first[0], 20, 10);
        wait(60);
        compare(t.filteredValueAt(1), ["x"]);
        wait(320);
        compare(t._filterPanel.opened, false, "官方单选选完就收下拉");

        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        const labels = testCase.byPos(testCase.findAll(t._filterPanel.contentItem,
            "tableFilterItemText"));
        compare(labels[0].color.toString(), Theme.current.colorPrimary.toString(),
            "选中那项的文案走主色");
        compare(labels[1].color.toString(), Theme.current.colorText0.toString());
        mouseClick(labels[0].parent, 20, 10);
        wait(60);
        compare(t.filteredValueAt(1), [], "再点同一个即取消（官方 toggle 语义）");
        t.destroy();
    }

    // renderFilterDropdownItem 返回节点那一档：整项换成 Loader，勾选框与文案让位
    function test_renderFilterDropdownItemNodeForm() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' }],"
            + "   renderFilterDropdownItem: (item) => chipNode,"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        t.openFilterPanel(testCase.columnOf(t, "tag"), testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        compare(testCase.shown(panel.contentItem, "tableFilterItemNode").length, 1);
        compare(testCase.shown(panel.contentItem, "tableFilterItemCheckbox").length, 0);
        compare(testCase.shown(panel.contentItem, "tableFilterItemText").length, 0);
        t.destroy();
    }

    // 官方递给 renderFilterDropdown 的那份参数里 confirm / clear 都收 opts
    function test_customDropdownArgsConfirmAndClear() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' }],"
            + "   onFilter: (v, r) => r.tag === v, filterDropdown: filterDropdownNode }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const col = testCase.columnOf(t, "tag");
        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        const node = testCase.one(t._filterPanel.contentItem, "customFilterDropdown");
        verify(node.args !== null);
        compare(node.args.filters.length, 1);
        verify(typeof node.args.confirm === "function");
        node.args.confirm(({ filteredValue: ["x"], closeDropdown: true }));
        wait(60);
        compare(t.filteredValueAt(1), ["x"], "opts.filteredValue 得盖过暂存值");
        wait(320);
        compare(t._filterPanel.opened, false, "opts.closeDropdown 得真的收面板");

        t.openFilterPanel(col, testCase.one(t, "tableHeaderCell"));
        wait(60);
        const again = testCase.one(t._filterPanel.contentItem, "customFilterDropdown");
        again.args.clear(({ closeDropdown: true }));
        wait(60);
        compare(t.filteredValueAt(1), []);
        compare(testCase.rowKeys(t), ["1", "2", "3"]);
        t.destroy();
    }

    // useFullRender 那一格整个交给调用方：端口不再加缩进与图标位
    function test_useFullRenderSkipsComponentIndent() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 300,"
            + " useFullRender: true, render: () => fullNode }];"
            + " dataSource: [{ key: 'p', name: 'P', children:"
            + "   [{ key: 'c', name: 'C' }] }];"
            + " pagination: false; defaultExpandAllRows: true }", 600);
        const rows = testCase.dataRows(t);
        compare(rows.length, 2);
        compare(rows[1].row.depth, 1, "子级那一行本来该缩进");
        const contents = rows.map(r => testCase.one(r, "tableCellContent"));
        fuzzyCompare(contents[0].x, 16, 0.5);
        fuzzyCompare(contents[1].x, 16, 0.5, "useFullRender 时缩进由调用方自己排");
        t.destroy();
    }

    // options.expandIcon 这一档标记只给「第一个数据格 + 可展开 + 图标画在行里」那一格
    function test_optionsMarkExpandIconOnFirstDataLeaf() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', width: 300,"
            + " useFullRender: true, render: (text, record, index, options) => fullNode }];"
            + " dataSource: [{ key: 'p', name: 'P', children: [{ key: 'c', name: 'C' }] }];"
            + " pagination: false; defaultExpandAllRows: true }", 600);
        const nodes = testCase.byPos(testCase.shown(t, "fullNode"));
        compare(nodes.length, 2);
        compare(nodes[0].options.expandIcon, "icon");
        compare(nodes[0].options.expanded, true);
        compare(nodes[0].options.expandable, true);
        verify(typeof nodes[0].options.toggleExpand === "function");
        t.destroy();
    }

    // 官方 mergedRowExpandable：既没子级也没 expandedRowRender 时，
    // rowExpandable 亲口说可展开才算（Table.tsx:390-403 那一支）
    function test_rowExpandableAloneMakesRowExpandable() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: testCase.rows3; pagination: false;"
            + " rowExpandable: (r) => r.key === '2' }", 600);
        const rows = testCase.dataRows(t);
        compare(rows.map(r => r.row.expandable), [false, true, false]);
        compare(testCase.shown(t, "tableExpandIconBox").length, 1, "只有那一格画图标");
        t.toggleExpand("2");
        wait(20);
        compare(t.expandedKeys, ["2"]);
        t.destroy();
    }

    // 不可展开的行就算被塞进 expandedRowKeys 也不插展开行
    function test_expandedKeyOnNonExpandableRowAddsNoRow() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: testCase.rows3; pagination: false;"
            + " rowExpandable: () => false; expandedRowRender: () => 'x';"
            + " defaultExpandedRowKeys: ['2'] }", 600);
        compare(testCase.byPos(testCase.findAll(t, "tableRow")).map(r => r.kind),
            ["data", "data", "data"]);
        t.destroy();
    }

    // renderGroupSection 返回字符串那一档就是组文案
    function test_groupSectionStringForm() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: '1', name: 'n1', tag: 'x' }];"
            + " pagination: false; groupBy: 'tag'; renderGroupSection: (key, group) =>"
            + "   '组 ' + key + ' 共 ' + group.length + ' 条' }", 600);
        compare(testCase.shown(t, "tableSectionText").map(s => s.text), ["组 x 共 1 条"]);
        t.destroy();
    }

    // column.colSpan / column.rowSpan 覆盖官方算出来的跨度
    function test_columnSpanOverrides() {
        // 视口 400、两列各 200 ⇒ 没有多余空间可分，跨度宽度就是两条叶子宽之和
        const merged = testCase.laid("Table { columns: ["
            + " { title: 'a', dataIndex: 'name', width: 200, colSpan: 2 },"
            + " { title: 'b', dataIndex: 'size', width: 200 }];"
            + " dataSource: testCase.rows3; pagination: false }", 400);
        const cell = merged.headerGrid.rows[0][0];
        compare(cell.colSpan, 2, "column.colSpan 盖掉叶子数 1");
        compare(cell.leafSpan, 2);
        fuzzyCompare(testCase.one(merged, "tableHeaderCell").width, 400, 0.5);
        // 官方游标按**最终** colSpan 前进 ⇒ 显式 colSpan 会吃掉下一列的槽位
        compare(merged.headerGrid.rows[0][1].leafStart, 2);
        merged.destroy();

        const stretched = testCase.laid("Table { columns: [{ title: 'g', children: ["
            + "   { title: 'a', dataIndex: 'name', rowSpan: 3 },"
            + "   { title: 'b', dataIndex: 'size' } ] }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const leaf = stretched.headerGrid.rows[1][0];
        compare(leaf.rowSpan, 3, "column.rowSpan 覆盖默认的 depth-level");
        const boxes = testCase.byPos(testCase.findAll(stretched, "tableHeaderCell"));
        fuzzyCompare(boxes[1].height, 3 * 38, 0.5);
        stretched.destroy();
    }

    // 官方 formatPaginationInfo 两头都夹在 total 里
    function test_paginationInfoClampsToTotal() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: ({ pageSize: 5, currentPage: 4 }) }", 600);
        compare(t.paginationControlled, true, "受控页码不自愈，交给文案那两条夹紧");
        compare(testCase.one(t, "tablePaginationInfo").text, "显示第 12 条-第 12 条，共 12 条");
        t.destroy();
    }

    // normalizePagination：非受控时页码超出总页数就回到第一页
    function test_currentPageBeyondLastWrapsToFirst() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 12 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: ({ pageSize: 5, defaultCurrentPage: 9 }) }", 600);
        compare(t.paginationState.currentPage, 1);
        compare(testCase.rowKeys(t), ["k0", "k1", "k2", "k3", "k4"]);
        t.destroy();
    }

    // virtualized 传对象时取 itemSize（数字档与函数档）
    function test_virtualizedObjectFormUsesItemSize() {
        const fixed = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 40 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: false; scroll: ({ y: 200 }); virtualized: ({ itemSize: 40 }) }", 600);
        compare(fixed.itemSizeValue, 40);
        fuzzyCompare(testCase.dataRows(fixed)[0].height, 40, 0.5);
        fuzzyCompare(testCase.one(fixed, "tableBody").contentHeight, 40 * 40, 1);
        fixed.destroy();

        const fn = testCase.laid("Table { columns: [{ dataIndex: 'size' }];"
            + " dataSource: Array.from({ length: 40 }, (_, i) => ({ key: 'k' + i, size: i }));"
            + " pagination: false; scroll: ({ y: 200 });"
            + " virtualized: ({ itemSize: (index, info) => info.sectionRow ? 41 : 20 }) }", 600);
        compare(typeof fn.itemSizeValue, "function");
        fuzzyCompare(testCase.dataRows(fn)[0].height, 20, 0.5);
        fn.destroy();
    }

    // headerStyle 是官方糊在 thead 上的 CSS，端口只落地背景色
    function test_headerStyleBackgroundApplies() {
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false;"
            + " headerStyle: ({ backgroundColor: '#123456' }) }", 600);
        compare(testCase.one(t, "tableHeaderBackground").color.toString(), "#123456");
        t.destroy();
    }

    // 整行悬浮：贴住的列仍用 bg-1，普通列换 bg-0，两层之上再叠 fill-0
    function test_hoverRowRepaintsCells() {
        // 浅色档 bg-0 / bg-1 / bg-2 / bg-3 全是 #fff，底色断言在那一档打不出差别
        // （第一轮变异里「普通列不换底色」正是这样漏网的）⇒ 这条走深色。
        Theme.mode = Theme.Dark;
        const t = testCase.laid("Table { columns: ["
            + " { title: 'a', dataIndex: 'name', width: 200, fixed: 'left' },"
            + " { title: 'b', dataIndex: 'size', width: 200 }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const view = testCase.one(t, "tableViewport");
        // 悬浮只在真的动过时重算，挪两次才拿得到；y 要落在表体那一行（表头占 38）
        testCase.mouseMove(view, 100, 60);
        wait(20);
        testCase.mouseMove(view, 120, 66);
        wait(60);
        const row = testCase.dataRows(t)[0];
        const cells = testCase.byPos(testCase.findAll(row, "tableCell"));
        const fixedBase = testCase.findAll(cells[0], "tableCellHoverBase")[0];
        const plainBase = testCase.findAll(cells[1], "tableCellHoverBase")[0];
        verify(plainBase.visible, "悬浮层得真的画出来，否则这条断言是空的");
        verify(fixedBase.visible);
        compare(plainBase.color.toString(), Theme.current.colorBg0.toString());
        compare(fixedBase.color.toString(), Theme.current.colorBg1.toString(),
            "贴住的列不换底色");
        compare(testCase.findAll(cells[1], "tableCellHoverFill")[0].color.toString(),
            Theme.current.colorFill0.toString());
        t.destroy();
    }

    // rowKey 官方还能写成函数（foundation.ts getRecordKey）
    function test_rowKeyAsFunction() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: testCase.rows3; pagination: false; rowSelection: ({});"
            + " rowKey: (record) => record.name }", 600);
        compare(testCase.rowKeys(t), ["n1", "n2", "n3"]);
        t.toggleRow("n2", true);
        wait(20);
        compare(t.selectedRowKeys, ["n2"]);
        t.destroy();
    }

    // childrenRecordName 换子级字段名，树形那一整套跟着走
    function test_customChildrenRecordName() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: 'p', name: 'P', sub: [{ key: 'c', name: 'C' }] }];"
            + " pagination: false; childrenRecordName: 'sub' }", 600);
        compare(testCase.rowKeys(t), ["p"]);
        t.toggleExpand("p");
        wait(20);
        compare(testCase.rowKeys(t), ["p", "c"]);
        compare(testCase.dataRows(t)[1].row.depth, 1);
        // 图标盒子只在那一行画出来（Icon 自己的 visible 恒真，判据在盒子上）
        compare(testCase.shown(t, "tableExpandIconBox").length, 1,
            "子级那行不该再长出一颗图标");
        t.destroy();
    }

    // 表头底色那一条令牌同样只有深色档能打出来：浅色 bg-0 / bg-1 都是 #fff
    function test_headerCellBgIsBg1Token() {
        Theme.mode = Theme.Dark;
        const t = testCase.laid("Table { columns: testCase.colsNameSize;"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        const bg = testCase.one(t, "tableHeaderBackground").color;
        verify(bg.toString() !== Theme.current.colorBg0.toString(),
            "深色档 bg-0 与 bg-1 不同值，否则这条断言没有判别力");
        compare(bg.toString(), Theme.current.colorBg1.toString());
        t.destroy();
    }

    // 面板里勾上的项来自当前筛选值，不是点出来的：勾选框随点击自己翻转，
    // 所以「点完再读 checked」打不红 `checked: false` 那一档变异（第一轮就漏在这是）。
    function test_filterItemChecksComeFromValues() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name', title: 'a' },"
            + " { dataIndex: 'tag', filters: [{ text: 'x', value: 'x' },"
            + "   { text: 'y', value: 'y' }], defaultFilteredValue: ['y'],"
            + "   onFilter: (v, r) => r.tag === v }];"
            + " dataSource: testCase.rows3; pagination: false }", 600);
        t.openFilterPanel(testCase.columnOf(t, "tag"), testCase.one(t, "tableHeaderCell"));
        wait(60);
        const panel = t._filterPanel;
        compare(panel.valuesOf(), ["y"]);
        const boxes = testCase.byPos(testCase.findAll(panel.contentItem,
            "tableFilterItemCheckbox"));
        compare(boxes.length, 2);
        verify(boxes[0].visible && boxes[1].visible);
        compare(boxes[0].checked, false);
        compare(boxes[1].checked, true, "没点过也得按 filteredValue 打上勾");
        t.destroy();
    }

    // checkRelation: 'related' 的级联读的是 ctx.childrenName ⇒ 换名那一档也得跟着走
    function test_checkRelationUsesCustomChildrenName() {
        const t = testCase.laid("Table { columns: [{ dataIndex: 'name' }];"
            + " dataSource: [{ key: 'p', name: 'P', sub: [{ key: 'c1', name: 'C1' },"
            + "   { key: 'c2', name: 'C2' }] }];"
            + " pagination: false; childrenRecordName: 'sub'; defaultExpandAllRows: true;"
            + " rowSelection: ({ checkRelation: 'related' }) }");
        compare(testCase.rowKeys(t), ["p", "c1", "c2"]);
        t.toggleRow("p", true);
        wait(20);
        compare(testCase.rowBoxes(t).map(b => b.checked), [true, true, true],
            "子级挂在 sub 上，级联不能只认 children");
        t.toggleRow("c1", false);
        wait(20);
        compare(testCase.rowBoxes(t).map(b => b.checked), [false, false, true]);
        t.destroy();
    }
}
