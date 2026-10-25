pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Table 表格。小节顺序与标题对齐官方文档页 content/show/table/index.md
// （docs.json 里的那 28 个小节），每一节给的 props 组合照官方那一份 demo 抄。
//
// 官方 demo 里有三件事是浏览器 / React 专有的，端口按下面这样落地
// （完整清单见 src/Table.qml 头注释的「与官方的差异」）：
//   · 「实现单元格 Hover 样式定制」官方写的是 CSS 覆盖 .semi-table-row-cell:hover；
//     QML 没有级联样式表，这一节改用官方自己的 components.body.cell 交出整格，
//     在节点里挂 HoverHandler —— 效果与那段 CSS 一致（整格变色、别的格不动）。
//   · 「固定列或表头」的第二份 demo 是 sticky（表头贴着窗口滚），QML 侧没有窗口滚动容器，
//     这一节只做官方第一份 demo（scroll.x + scroll.y + 固定列）。
//   · 「拖拽排序」官方用 dnd-kit 实时换位，端口在行节点里用 DragHandler 按行高算目标位置，
//     拖动过程中即时交换。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property real dayMs: 24 * 60 * 60 * 1000
    readonly property real baseTime: 1706112000000      // 2024-01-25，官方 demo 的那一天

    // ---------------------------------------------------------------- 每一节的「useState」
    property var basicRows: []
    property var customRows: []
    property var remoteRows: []
    property int remotePage: 1
    property bool remoteLoading: false
    property var selectedKeys: []
    property string lastLog: ""
    property string nameKeyword: ""
    property var expandKeys: ["1"]
    property var treeKeys: [1]
    property var treeSelected: []
    property var relatedKeys: []
    property var hoverCellKey: ""
    property var dragRows: []
    property int dragPage: 1
    property var groupLog: ""
    property var infiniteRows: []
    property bool infiniteLoading: false
    property var dynamicKeys: []
    property bool dShowHeader: true
    property bool dBordered: true
    property bool dLoading: false
    property bool dSelection: true
    property bool dExpandRender: true
    property bool dTitle: true
    property bool dFooter: true
    property bool dScrollY: true
    property bool dFixed: true
    property bool dSorter: true
    property bool dFilters: true
    property bool dResizable: false
    property string dPosition: "bottom"
    property var dExpandedKeys: []
    property string dPageSize: "8"

    readonly property var statusMap: ({
        "success": { color: "green", glyph: "tick_circle", label: "已交付" },
        "pending": { color: "pink", glyph: "clear", label: "已延期" },
        "wait": { color: "cyan", glyph: "comment", label: "待评审" }
    })

    function formatDate(ts) {
        return Qt.formatDate(new Date(ts), "yyyy-MM-dd");
    }

    // 官方生成数据那一份：偶数行是 Semi Design 稿，size 用 (i*1000)%199
    function genRows(total, from) {
        const start = from !== undefined ? from : 0;
        const out = [];
        for (let i = start; i < start + total; ++i) {
            const isSemi = i % 2 === 0;
            const rnd = (i * 1000) % 199;
            out.push({
                key: "" + i,
                name: (isSemi ? "Semi Design 设计稿" : "Semi D2C 设计稿") + i + ".fig",
                owner: isSemi ? "姜鹏志" : "郝宣",
                size: rnd,
                updateTime: page.baseTime + rnd * page.dayMs,
                avatarBg: isSemi ? "grey" : "red"
            });
        }
        return out;
    }

    // 官方 #1 / #3 那几份手写数据（updateTime 是字符串、带 status / nameIconSrc）
    readonly property var handRows: [
        { key: "1", name: "Semi Design 设计稿.fig", size: "2M", owner: "姜鹏志",
            status: "success", updateTime: "2020-02-02 05:13", avatarBg: "grey" },
        { key: "2", name: "Semi Design 分享演示文稿", size: "2M", owner: "郝宣",
            status: "pending", updateTime: "2020-01-17 05:13", avatarBg: "red" },
        { key: "3", name: "设计文档", size: "34KB", owner: "Zoey Edwards",
            status: "wait", updateTime: "2020-01-26 11:01", avatarBg: "light-blue" }
    ]

    readonly property var selectRows: [
        { key: "1", name: "Semi Design 设计稿.fig", size: "2M", owner: "姜鹏志",
            status: "success", updateTime: "2020-02-02 05:13", avatarBg: "grey" },
        { key: "2", name: "Semi Design 分享演示文稿", size: "2M", owner: "郝宣",
            status: "pending", updateTime: "2020-01-17 05:31", avatarBg: "red" },
        { key: "3", name: "设计文档", size: "34KB", owner: "Zoey Edwards",
            status: "wait", updateTime: "2020-01-26 11:01", avatarBg: "light-blue" },
        { key: "4", name: "Semi D2C 设计稿.fig", size: "2M", owner: "姜鹏志",
            status: "wait", updateTime: "2020-02-02 05:13", avatarBg: "grey" },
        { key: "5", name: "Semi D2C 分享演示文稿", size: "2M", owner: "郝宣",
            status: "pending", updateTime: "2020-01-17 05:31", avatarBg: "red" },
        { key: "6", name: "Semi D2C 设计文档", size: "34KB", owner: "Zoey Edwards",
            status: "success", updateTime: "2020-01-26 11:01", avatarBg: "light-blue" }
    ]

    // 官方 #13 的展开行内容（Descriptions 的那份 data）
    readonly property var expandData: [
        [{ key: "实际用户数量", value: "1,480,000" }, { key: "7 天留存", value: "98%" },
            { key: "安全等级", value: "3 级" }, { key: "垂类标签", value: "设计" },
            { key: "认证状态", value: "未认证" }],
        [{ key: "实际用户数量", value: "2,480,000" }, { key: "7 天留存", value: "90%" },
            { key: "安全等级", value: "1 级" }, { key: "垂类标签", value: "模板" },
            { key: "认证状态", value: "已认证" }],
        [{ key: "实际用户数量", value: "2,920,000" }, { key: "7 天留存", value: "98%" },
            { key: "安全等级", value: "2 级" }, { key: "垂类标签", value: "文档" },
            { key: "认证状态", value: "已认证" }]
    ]

    // 官方 #14 的树形数据
    readonly property var treeRows: [
        { key: 1, dataKey: "videos_info", name: "视频信息", type: "Object 对象",
            description: "视频的元信息", default: "无", children: [
                { key: 11, dataKey: "status", name: "视频状态", type: "Enum <Integer> 枚举",
                    description: "视频的可见、推荐状态", default: "1" },
                { key: 12, dataKey: "weight", name: "权重", type: "Integer 整数",
                    description: "权重大小影响排序", default: "1" }
            ] },
        { key: 2, dataKey: "upload_id", name: "上传 id", type: "String 字符串",
            description: "上传文件的标识", default: "空", children: [
                { key: 21, dataKey: "name", name: "文件名", type: "String 字符串",
                    description: "文件名称", default: "空" },
                { key: 22, dataKey: "size", name: "文件大小", type: "Integer 整数",
                    description: "以字节为单位", default: "0" }
            ] }
    ]

    // 官方 #14「行可交换」那一档用的扁平树（带 operation 列）
    readonly property var swapRows: [
        { key: "1", dataKey: "videos_info", name: "视频信息", type: "Object 对象",
            description: "视频的元信息", default: "无", children: [
                { key: "1-1", dataKey: "status", name: "视频状态", type: "Enum 枚举",
                    description: "视频的可见、推荐状态", default: "1" },
                { key: "1-2", dataKey: "weight", name: "权重", type: "Integer 整数",
                    description: "权重大小影响排序", default: "1" },
                { key: "1-3", dataKey: "vid", name: "视频 id", type: "String 字符串",
                    description: "视频唯一标识", default: "空" }
            ] },
        { key: "2", dataKey: "upload_id", name: "上传 id", type: "String 字符串",
            description: "上传文件的标识", default: "空" }
    ]

    // 官方 #19 单元格缩略用的长文案
    readonly property var longRows: [
        { key: "1", name: "Semi Design 设计稿 Semi Design 是一个由抖音视频团队设计与前端共同合作的设计系统",
            owner: "姜鹏志 Zoey Edwards Michael James Sarah Miller", size: 34,
            updateTime: 1706112000000 },
        { key: "2", name: "Semi D2C 可以把设计稿直接转成可用组件",
            owner: "郝宣", size: 199, updateTime: 1706212000000 },
        { key: "3", name: "设计文档", owner: "Zoey Edwards Michael James", size: 2,
            updateTime: 1706312000000 },
        { key: "4", name: "一份名字特别长的演示文稿，用来把这一格挤到缩略为止",
            owner: "Sarah Miller", size: 88, updateTime: 1706412000000 }
    ]

    function removeRow(key) {
        const next = [];
        for (let i = 0; i < page.customRows.length; ++i)
            if (String(page.customRows[i].key) !== String(key))
                next.push(page.customRows[i]);
        page.customRows = next;
    }

    function resetCustomRows() {
        page.customRows = [
            { key: "1", name: "Semi Design 设计稿.fig", size: 24, owner: "姜鹏志",
                status: "success", updateTime: 1706112000000, avatarBg: "grey" },
            { key: "2", name: "Semi Design 分享演示文稿", size: 34, owner: "郝宣",
                status: "pending", updateTime: 1706212000000, avatarBg: "red" },
            { key: "3", name: "设计文档", size: 12, owner: "Zoey Edwards",
                status: "wait", updateTime: 1706312000000, avatarBg: "light-blue" },
            { key: "4", name: "Semi D2C 设计稿.fig", size: 88, owner: "Michael James",
                status: "success", updateTime: 1706412000000, avatarBg: "grey" }
        ];
    }

    function moveRow(fromIndex, toIndex) {
        if (fromIndex === toIndex)
            return;
        const base = (page.dragPage - 1) * 10;
        const next = page.dragRows.slice();
        const from = base + fromIndex;
        const to = base + toIndex;
        if (from < 0 || from >= next.length || to < 0 || to >= next.length)
            return;
        const moved = next.splice(from, 1)[0];
        next.splice(to, 0, moved);
        page.dragRows = next;
    }

    function appendInfinite() {
        if (page.infiniteLoading)
            return;
        page.infiniteLoading = true;
        loadMore.restart();
    }

    // 远程数据那一档：翻页时先进 loading，一帧后再把当页切出来
    function fetchRemote(pageNo) {
        page.remoteLoading = true;
        page.remotePage = pageNo;
        loadRemote.restart();
    }

    Timer {
        id: loadRemote

        interval: 400
        repeat: false
        onTriggered: {
            const all = page.genRows(46);
            page.remoteRows = all.slice((page.remotePage - 1) * 5, page.remotePage * 5);
            page.remoteTotal = all.length;
            page.remoteLoading = false;
        }
    }

    Timer {
        id: loadMore

        interval: 300
        repeat: false
        onTriggered: {
            page.infiniteRows = page.infiniteRows.concat(
                page.genRows(20, page.infiniteRows.length));
            page.infiniteLoading = false;
        }
    }

    property int remoteTotal: 46

    // ---------------------------------------------------------------- 单元格节点
    component NameCell: Row {
        id: nameCell

        property var record: null
        property string text: ""

        spacing: Theme.current.spacingBase
        Avatar {
            size: "small"
            shape: "square"
        }
        Text {
            text: nameCell.text
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    component OwnerCell: Row {
        id: ownerCell

        property var record: null
        property string text: ""

        spacing: Theme.current.spacingExtraTight
        Avatar {
            size: "small"
            text: ownerCell.text
        }
        Text {
            text: ownerCell.text
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    component StatusCell: Item {
        id: statusCell

        property var record: null
        property string text: ""

        readonly property var cfg: page.statusMap[statusCell.text] !== undefined
            ? page.statusMap[statusCell.text] : page.statusMap["wait"]
        implicitWidth: statusTag.implicitWidth
        implicitHeight: statusTag.implicitHeight

        Tag {
            id: statusTag

            anchors.verticalCenter: parent.verticalCenter
            text: statusCell.cfg.label
            color: statusCell.cfg.color
            prefixIcon: statusCell.cfg.glyph
            shape: "circle"
        }
    }

    component MoreCell: Item {
        id: moreCell

        property var record: null
        property string text: ""

        implicitWidth: moreIcon.implicitWidth
        implicitHeight: moreIcon.implicitHeight

        Icon {
            id: moreIcon

            anchors.verticalCenter: parent.verticalCenter
            name: "more"
            size: 16
            color: Theme.current.colorText2
        }
    }

    component DeleteCell: Item {
        id: deleteCell

        property var record: null
        property string text: ""

        implicitWidth: deleteButton.implicitWidth
        implicitHeight: deleteButton.implicitHeight

        Button {
            id: deleteButton

            anchors.verticalCenter: parent.verticalCenter
            size: Enums.Small
            tone: Enums.Tertiary
            variant: Enums.Borderless
            icon: "delete"
            onClicked: page.removeRow(deleteCell.record !== null ? deleteCell.record.key : "")
        }
    }

    Component {
        id: nameCellComp

        NameCell {}
    }

    Component {
        id: ownerCellComp

        OwnerCell {}
    }

    Component {
        id: statusCellComp

        StatusCell {}
    }

    Component {
        id: moreCellComp

        MoreCell {}
    }

    Component {
        id: deleteCellComp

        DeleteCell {}
    }

    // 自定义筛选器（官方 #10）：面板里一个输入框 + 取消 / 确定，全程只吃 args 给的那几个钩子
    component SearchFilterPanel: Column {
        id: searchPanel

        property var args: null
        property string keyword: ""

        topPadding: Theme.current.spacingTight
        bottomPadding: Theme.current.spacingTight
        leftPadding: Theme.current.spacingBase
        rightPadding: Theme.current.spacingBase
        spacing: Theme.current.spacingTight

        Input {
            width: 168
            size: Enums.Small
            placeholderText: qsTr("请输入筛选条件")
            text: searchPanel.args !== null && searchPanel.args.tempFilteredValue.length > 0
                ? String(searchPanel.args.tempFilteredValue[0]) : ""
            onTextChanged: {
                if (searchPanel.args === null)
                    return;
                searchPanel.keyword = text;
                searchPanel.args.setTempFilteredValue(text === "" ? [] : [text]);
            }
        }

        Row {
            spacing: Theme.current.spacingTight

            Button {
                text: qsTr("取消")
                size: Enums.Small
                tone: Enums.Tertiary
                onClicked: {
                    if (searchPanel.args !== null)
                        searchPanel.args.clear({ closeDropdown: true });
                }
            }

            Button {
                text: qsTr("确定")
                size: Enums.Small
                tone: Enums.Primary
                variant: Enums.Solid
                onClicked: {
                    if (searchPanel.args !== null)
                        searchPanel.args.confirm({ closeDropdown: true });
                }
            }
        }
    }

    Component {
        id: searchFilterComp

        SearchFilterPanel {}
    }

    // 自定义筛选项（官方 #12）：一整条 Dropdown.Item 的样子，选中态自己画
    component TickFilterItem: Item {
        id: tickItem

        property var args: null

        readonly property bool checkedItem: args !== null && args.checked === true

        Rectangle {
            anchors.fill: parent
            color: Theme.current.colorPrimaryLightDefault
            visible: tickItem.checkedItem
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.current.spacingBase
            anchors.verticalCenter: parent.verticalCenter
            text: tickItem.args !== null ? String(tickItem.args.text) : ""
            color: tickItem.checkedItem ? Theme.current.colorPrimary : Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }

        Icon {
            anchors.right: parent.right
            anchors.rightMargin: Theme.current.spacingBase
            anchors.verticalCenter: parent.verticalCenter
            visible: tickItem.checkedItem
            name: "tick"
            size: 16
            color: Theme.current.colorPrimary
        }
    }

    Component {
        id: tickFilterItemComp

        TickFilterItem {}
    }

    // 表头里塞一个输入框（官方 #9「自定义表头筛选」）
    component SearchTitle: Row {
        id: searchTitle

        spacing: Theme.current.spacingTight

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("标题")
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Theme.current.fontWeightBold
        }

        Input {
            anchors.verticalCenter: parent.verticalCenter
            width: 180
            size: Enums.Small
            showClear: true
            placeholderText: qsTr("搜索标题")
            onTextChanged: page.nameKeyword = text
        }
    }

    Component {
        id: searchTitleComp

        SearchTitle {}
    }

    // 完全自定义渲染（官方 #26）：勾选框、展开按钮、缩进都由这一格自己排
    component FullCell: Row {
        id: fullCell

        property var record: null
        property string text: ""
        property var options: null
        property var args: null

        spacing: Theme.current.spacingTight

        Checkbox {
            visible: fullCell.options !== null && fullCell.options.selection !== undefined
            checked: fullCell.options !== null && fullCell.options.checked === true
            indeterminate: fullCell.options !== null && fullCell.options.indeterminate === true
            disabled: fullCell.options !== null && fullCell.options.disabled === true
            onToggled: {
                if (fullCell.options !== null)
                    fullCell.options.toggleSelection(checked);
            }
        }

        Item {
            visible: fullCell.options !== null && fullCell.options.expandIcon !== undefined
            width: 16
            height: 16

            Icon {
                anchors.centerIn: parent
                name: "chevron_right"
                size: 16
                color: Theme.current.colorText2
                rotation: fullCell.options !== null && fullCell.options.expanded === true ? 90 : 0
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: {
                    if (fullCell.options !== null)
                        fullCell.options.toggleExpand();
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: fullCell.text
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    Component {
        id: fullCellComp

        FullCell {}
    }

    // 整格接管（官方 #18 用 CSS，端口用 components.body.cell）
    component HoverCell: Item {
        id: hoverCell

        property var record: null
        property string text: ""
        property int index: 0
        property var column: null
        property bool hovered: false
        property bool selected: false
        property bool expanded: false
        property var options: null

        Rectangle {
            anchors.fill: parent
            color: hoverCell.hovered ? Theme.current.lightGreen[1] : "transparent"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.current.spacingBase
            anchors.verticalCenter: parent.verticalCenter
            text: hoverCell.text
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            elide: Text.ElideRight
        }

        HoverHandler {
            id: cellHover

            onHoveredChanged: page.hoverCellKey = cellHover.hovered
                ? String(hoverCell.record !== null ? hoverCell.record.key : "") : ""
        }
    }

    Component {
        id: hoverCellComp

        HoverCell {}
    }

    // 行可交换（官方 #14 第二档）的那一列按钮
    component SwapCell: Row {
        id: swapCell

        property var record: null
        property string text: ""

        spacing: Theme.current.spacingTight

        Button {
            text: qsTr("上移")
            size: Enums.Small
            tone: Enums.Tertiary
            onClicked: page.lastLog = qsTr("上移 %1").arg(swapCell.text)
        }

        Button {
            text: qsTr("下移")
            size: Enums.Small
            tone: Enums.Tertiary
            onClicked: page.lastLog = qsTr("下移 %1").arg(swapCell.text)
        }
    }

    Component {
        id: swapCellComp

        SwapCell {}
    }

    // 拖拽排序（官方 #21）：整行被这个节点包住，格子由端口搬进来
    component DragRow: Item {
        id: dragRow

        property var record: null
        property int index: 0
        property string rowKey: ""
        property bool hovered: false

        Item {
            id: dragSlot

            anchors.fill: parent
        }

        DragHandler {
            id: dragHandle

            // 官方 SortableRow 每挪一格就把累计位移清零；QML 的 translation 只读，
            // 只能自己记住「已经吃掉的那几格」。
            property real consumedY: 0

            target: null
            onActiveChanged: {
                if (!active)
                    dragHandle.consumedY = 0;
            }
            onTranslationChanged: {
                if (!active)
                    return;
                const step = Math.round((translation.y - dragHandle.consumedY) / 53);
                if (step === 0)
                    return;
                dragHandle.consumedY += step * 53;
                page.moveRow(dragRow.index, dragRow.index + step);
            }
        }
    }

    Component {
        id: dragRowComp

        DragRow {}
    }

    // 空数据时官方那份 Empty
    Component {
        id: emptyComp

        Empty {
            description: qsTr("搜索无结果")
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        // ============================================================ 1
        GallerySection {
            title: "基本表格"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name",
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size" },
                    { title: qsTr("交付状态"), dataIndex: "status",
                        render: (text) => statusCellComp },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime" },
                    { title: "", dataIndex: "operate", render: () => moreCellComp }
                ]
                dataSource: page.handRows
                pagination: false
            }
        }

        // ============================================================ 2
        GallerySection {
            title: "JSX 写法"

            Table {
                width: 700
                dataSource: page.handRows
                pagination: false

                TableColumn {
                    title: qsTr("标题")
                    dataIndex: "name"
                    columnKey: "name"
                    render: (text, record, index) => nameCellComp
                }
                TableColumn {
                    title: qsTr("大小")
                    dataIndex: "size"
                    columnKey: "size"
                }
                TableColumn {
                    title: qsTr("所有者")
                    dataIndex: "owner"
                    columnKey: "owner"
                    render: (text, record, index) => ownerCellComp
                }
                TableColumn {
                    title: qsTr("更新时间")
                    dataIndex: "updateTime"
                    columnKey: "updateTime"
                }
                TableColumn {
                    title: ""
                    dataIndex: "operate"
                    columnKey: "operate"
                    render: () => moreCellComp
                }
            }
        }

        // ============================================================ 3
        GallerySection {
            title: "行选择操作"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size" },
                    { title: qsTr("交付状态"), dataIndex: "status",
                        render: (text) => statusCellComp },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime" },
                    { title: "", dataIndex: "operate", render: () => moreCellComp }
                ]
                dataSource: page.selectRows
                pagination: ({ pageSize: 3 })
                rowSelection: ({
                    getCheckboxProps: record => ({ disabled: record.name === "设计文档" }),
                    onSelect: (record, selected) => {
                        page.lastLog = qsTr("onSelect %1 → %2")
                            .arg(record.name).arg(selected);
                    },
                    onSelectAll: (selected, selectedRows) => {
                        page.lastLog = qsTr("onSelectAll %1，共 %2 行")
                            .arg(selected).arg(selectedRows.length);
                    },
                    onChange: (selectedRowKeys, selectedRows) => {
                        page.selectedKeys = selectedRowKeys;
                        page.lastLog = qsTr("onChange → %1 行").arg(selectedRowKeys.length);
                    }
                })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("已选 %1 行：%2").arg(page.selectedKeys.length)
                    .arg(page.selectedKeys.join("、")) + (page.lastLog === "" ? "" : "｜" + page.lastLog)
            }
        }

        // ============================================================ 4
        GallerySection {
            title: "自定义渲染"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size", width: 150 },
                    { title: qsTr("交付状态"), dataIndex: "status",
                        render: (text) => statusCellComp },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 300,
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime", width: 200,
                        render: (text) => page.formatDate(text) },
                    { title: "", dataIndex: "operate", render: () => deleteCellComp }
                ]
                dataSource: page.customRows
                pagination: false
                empty: emptyComp
            }

            Row {
                spacing: Theme.current.spacingTight

                Button {
                    text: qsTr("恢复数据")
                    size: Enums.Small
                    onClicked: page.resetCustomRows()
                }
            }
        }

        // ============================================================ 5
        GallerySection {
            title: "带分页组件的表格"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" },
                            { text: "Semi D2C 设计稿", value: "Semi D2C 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0 },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(46)
                scroll: ({ y: 300 })
                rowSelection: ({
                    getCheckboxProps: record => ({ disabled: record.name === "设计文档" }),
                    onChange: keys => { page.selectedKeys = keys; }
                })
            }
        }

        // ============================================================ 6
        GallerySection {
            title: "拉取远程数据"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" },
                            { text: "Semi D2C 设计稿", value: "Semi D2C 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0 },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.remoteRows
                loading: page.remoteLoading
                pagination: ({
                    currentPage: page.remotePage,
                    pageSize: 5,
                    total: page.remoteTotal,
                    onPageChange: pageNo => page.fetchRemote(pageNo)
                })
            }
        }

        // ============================================================ 7
        GallerySection {
            title: "固定列或表头"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 250, fixed: true,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" },
                            { text: "Semi D2C 设计稿", value: "Semi D2C 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0 },
                    { title: qsTr("大小"), dataIndex: "size", width: 200,
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 200,
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime", width: 200,
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) },
                    { title: qsTr("操作"), dataIndex: "operate", width: 100, fixed: "right",
                        align: "center", render: () => moreCellComp }
                ]
                dataSource: page.genRows(46)
                scroll: ({ y: 300, x: 1200 })
                rowSelection: ({
                    fixed: true,
                    getCheckboxProps: record => ({ disabled: record.name === "设计文档" }),
                    onChange: keys => { page.selectedKeys = keys; }
                })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("官方这一节还有第二份 demo 用 sticky={{top:60}} 把表头钉在窗口上；"
                    + "QML 侧没有「贴着窗口滚」的那层滚动容器，所以这一档不落地（见 src/Table.qml 头注释）。")
            }
        }

        // ============================================================ 8
        GallerySection {
            title: "带排序和过滤功能的表头"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" },
                            { text: "Semi D2C 设计稿", value: "Semi D2C 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0,
                        sorter: (a, b) => String(a.name).localeCompare(String(b.name)) },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(46)
                scroll: ({ y: 300 })
                rowSelection: ({
                    getCheckboxProps: record => ({ disabled: record.name === "设计文档" }),
                    onChange: keys => { page.selectedKeys = keys; }
                })
            }

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 300,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (r1, r2, sortOrder) => {
                            page.lastLog = qsTr("sorter 收到第三参数 sortOrder=%1")
                                .arg(String(sortOrder));
                            return r1.size - r2.size;
                        },
                        showSortTip: true,
                        render: (text) => text !== undefined ? text + " KB" : qsTr("未知") },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: [
                    { key: "1", name: "Semi Design 设计稿.fig", size: 24, owner: "姜鹏志",
                        updateTime: 1706112000000 },
                    { key: "2", name: "Semi Design 分享演示文稿", size: undefined, owner: "郝宣",
                        updateTime: 1706212000000 },
                    { key: "3", name: "设计文档", size: 12, owner: "Zoey Edwards",
                        updateTime: 1706312000000 }
                ]
                pagination: false
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("showSortTip:true 时，鼠标移到排序图标（本列还有筛选器时）或整格上会出官方那三条提示："
                    + "点击升序 / 点击降序 / 取消排序。sortOrder 受控时官方不显示提示，端口同一口径。")
                    + (page.lastLog === "" ? "" : "｜" + page.lastLog)
            }
        }

        // ============================================================ 9
        GallerySection {
            title: "自定义表头筛选"

            Table {
                width: 700
                columns: [
                    { title: searchTitleComp, dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0,
                        filteredValue: page.nameKeyword === "" ? [] : [page.nameKeyword] },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(46)
                pagination: ({ pageSize: 5 })
            }
        }

        // ============================================================ 10
        GallerySection {
            title: "自定义筛选器"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0,
                        renderFilterDropdown: args => searchFilterComp,
                        onFilterDropdownVisibleChange: visible => {
                            page.lastLog = qsTr("筛选面板 visible=%1").arg(visible);
                        } },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 200,
                        render: (text, record, index) => ownerCellComp,
                        onFilter: (value, record) => String(record.owner).indexOf(value) >= 0,
                        defaultFilteredValue: ["姜鹏志"],
                        renderFilterDropdown: args => searchFilterComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(46)
                pagination: ({ pageSize: 5 })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("renderFilterDropdown(props) 收的是官方那 6 个键："
                    + "tempFilteredValue / setTempFilteredValue / confirm / clear / close / filters。"
                    + "端口把这一份原样绑给节点（节点里声明 property var args）。")
                    + (page.lastLog === "" ? "" : "｜" + page.lastLog)
            }
        }

        // ============================================================ 11
        GallerySection {
            title: "筛选确认模式"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 300,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design", value: "Semi Design" },
                            { text: "Semi Pro", value: "Semi Pro" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0,
                        filterMultiple: true,
                        filterConfirmMode: "confirm" },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 200,
                        render: (text, record, index) => ownerCellComp,
                        filters: [{ text: "姜鹏志", value: "姜鹏志" }, { text: "郝宣", value: "郝宣" }],
                        onFilter: (value, record) => String(record.owner).indexOf(value) >= 0,
                        filterMultiple: true,
                        filterConfirmMode: "confirm" },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(20)
                pagination: ({ pageSize: 5 })
            }
        }

        // ============================================================ 12
        GallerySection {
            title: "自定义筛选项渲染"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" },
                            { text: "Semi D2C 设计稿", value: "Semi D2C 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0,
                        renderFilterDropdownItem: item => tickFilterItemComp,
                        filterDropdownProps: ({ showTick: true }),
                        sorter: (a, b) => String(a.name).localeCompare(String(b.name)) },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(46)
                scroll: ({ y: 300 })
                rowSelection: ({
                    getCheckboxProps: record => ({ disabled: record.name === "设计文档" }),
                    onChange: keys => { page.selectedKeys = keys; }
                })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("renderFilterDropdownItem 收官方那 7 个字段（onChange / filterMultiple / value /"
                    + " text / checked / filteredValue / level），节点里声明 property var args 就能拿到。"
                    + "filterDropdownProps 官方是透传 Dropdown 的全部属性，端口只取 position，"
                    + "showTick 这类 DOM 侧开关没有对应物。")
            }
        }

        // ============================================================ 13
        GallerySection {
            title: "可以展开的表格"

            Table {
                width: 700
                rowKey: "name"
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 500,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime" },
                    { title: "", dataIndex: "operate", render: () => moreCellComp }
                ]
                dataSource: page.handRows
                pagination: false
                expandedRowRender: (record, index) => expandDescHolder
                rowSelection: ({
                    getCheckboxProps: record => ({ disabled: record.name === "设计文档" }),
                    onSelect: (record, selected) => {
                        page.lastLog = qsTr("select row: %1").arg(selected);
                    },
                    onChange: keys => { page.selectedKeys = keys; }
                })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("rowKey 默认是 key，这里改成 name。")
            }

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 500,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime" },
                    { title: "", dataIndex: "operate", render: () => moreCellComp }
                ]
                dataSource: page.handRows
                pagination: false
                hideExpandedColumn: false
                expandedRowRender: (record, index) => expandDescHolder
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("hideExpandedColumn:false ⇒ 展开按钮单独成一列（宽 48，$width-table_column_selection）。")
            }

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 500,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime" },
                    { title: "", dataIndex: "operate", render: () => moreCellComp }
                ]
                dataSource: page.handRows
                pagination: false
                hideExpandedColumn: false
                rowExpandable: record => record.name !== "设计文档"
                expandedRowRender: (record, index) => expandDescHolder
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("rowExpandable(record) 返回假的行，那一格整个是空的（官方 BaseRow.tsx:266），不是灰掉的图标。")
            }
        }

        Component {
            id: expandDescHolder

            Descriptions {
                property int which: 0
                dataList: page.expandData[which % page.expandData.length]
            }
        }

        // ============================================================ 14
        GallerySection {
            title: "树形数据展示"

            Table {
                width: 700
                columns: [
                    { title: "Key", dataIndex: "dataKey" },
                    { title: qsTr("名称"), dataIndex: "name", width: 200 },
                    { title: qsTr("数据类型"), dataIndex: "type", width: 180 },
                    { title: qsTr("描述"), dataIndex: "description" },
                    { title: qsTr("默认值"), dataIndex: "default", width: 100 }
                ]
                dataSource: page.treeRows
                defaultExpandAllRows: true
                pagination: false
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("childrenRecordName 默认 children；indentSize 默认 20（$spacing-table_tree_indent）。"
                    + "没有 key 的行会退成它的下标。")
            }

            Table {
                width: 700
                columns: [
                    { title: "Key", dataIndex: "dataKey" },
                    { title: qsTr("名称"), dataIndex: "name", width: 180 },
                    { title: qsTr("数据类型"), dataIndex: "type", width: 160 },
                    { title: qsTr("描述"), dataIndex: "description" },
                    { title: "", dataIndex: "operation", width: 160,
                        render: (text, record, index) => swapCellComp }
                ]
                dataSource: page.swapRows
                rowKey: "key"
                childrenRecordName: "children"
                expandedRowKeys: page.treeKeys
                onExpandedRowsChange: rows => {
                    page.treeKeys = rows.map(r => r.key);
                }
                pagination: false
            }

            Table {
                width: 700
                columns: [
                    { title: "Key", dataIndex: "dataKey" },
                    { title: qsTr("名称"), dataIndex: "name", width: 180 },
                    { title: qsTr("数据类型"), dataIndex: "type", width: 160 },
                    { title: qsTr("描述"), dataIndex: "description" },
                    { title: qsTr("默认值"), dataIndex: "default", width: 100 }
                ]
                dataSource: page.treeRows
                rowKey: "key"
                childrenRecordName: "children"
                pagination: false
                rowSelection: ({
                    selectedRowKeys: page.treeSelected,
                    onSelect: (record, selected) => {
                        page.lastLog = qsTr("onSelect %1 → %2").arg(record.dataKey).arg(selected);
                    },
                    onChange: keys => { page.treeSelected = keys; }
                })
            }

            Table {
                width: 700
                columns: [
                    { title: "Key", dataIndex: "dataKey" },
                    { title: qsTr("名称"), dataIndex: "name", width: 180 },
                    { title: qsTr("数据类型"), dataIndex: "type", width: 160 },
                    { title: qsTr("描述"), dataIndex: "description" },
                    { title: qsTr("默认值"), dataIndex: "default", width: 100 }
                ]
                dataSource: page.treeRows
                pagination: false
                rowSelection: ({
                    selectedRowKeys: page.relatedKeys,
                    checkRelation: "related",
                    onChange: keys => {
                        page.relatedKeys = keys;
                        page.lastLog = qsTr("related → %1 个 key").arg(keys.length);
                    }
                })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("checkRelation:'related' 时勾选父子互相传导（官方走 rc-tree 的 conductCheck）："
                    + "勾父带子、勾子到齐才勾父、不齐则父半选。")
                    + (page.lastLog === "" ? "" : "｜" + page.lastLog)
            }
        }

        // ============================================================ 15
        GallerySection {
            title: "自定义行或单元格事件以及属性"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0,
                        onCell: (record, index) => ({
                            style: index === 1 ? ({ background: Theme.current.colorFill0 }) : ({})
                        }) },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(10)
                pagination: ({ pageSize: 5 })
                onRow: (record, index) => ({
                    onClick: () => { page.lastLog = qsTr("点了第 %1 行").arg(index); },
                    style: index === 2 ? ({ background: Theme.current.colorPrimaryLightDefault }) : ({})
                })
                onHeaderRow: (columns, index) => ({
                    onMouseEnter: () => { page.lastLog = qsTr("进入表头第 %1 行").arg(index); },
                    onMouseLeave: () => { page.lastLog = qsTr("离开表头第 %1 行").arg(index); }
                })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("onRow(record, index, rowStatus) 返回的 style / onClick / onMouseEnter / onMouseLeave"
                    + " 端口都接；onHeaderRow(columns, index) 同一套。")
                    + (page.lastLog === "" ? "" : "｜" + page.lastLog)
            }
        }

        // ============================================================ 16
        GallerySection {
            title: "实现斑马纹样式"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime" },
                    { title: "", dataIndex: "operate", render: () => moreCellComp }
                ]
                dataSource: page.selectRows
                pagination: false
                onRow: (record, index) => index % 2 === 0
                    ? ({ style: ({ background: Theme.current.colorFill0 }) }) : ({})
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("官方本身没有斑马纹开关，就是 onRow 给偶数行铺 fill-0；有固定列时改用 onCell 铺。")
            }
        }

        // ============================================================ 17
        GallerySection {
            title: "实现表头样式定制"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 280,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size", width: 100 },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 200,
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime", width: 300 },
                    { title: "", dataIndex: "operate", render: () => moreCellComp }
                ]
                dataSource: page.handRows
                pagination: false
                onHeaderRow: () => ({ style: ({ background: Theme.current.colorFill0 }) })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("官方这一节是每列挂 onHeaderCell 返回 style.backgroundColor；端口两条都接："
                    + "onHeaderCell 按列、onHeaderRow 按行、Table.headerStyle 整表头。")
            }
        }

        // ============================================================ 18
        GallerySection {
            title: "实现单元格 Hover 样式定制"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 280,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size", width: 100 },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 200,
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime", width: 300 },
                    { title: "", dataIndex: "operate", render: () => moreCellComp }
                ]
                dataSource: page.handRows
                pagination: false
                components: ({ body: ({ cell: hoverCellComp }) })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("官方用一段 CSS 把 .semi-table-row-cell:hover 改色；QML 没有级联样式表，"
                    + "这一节改走 components.body.cell：整格交给调用方铺，格子里自己挂 HoverHandler，"
                    + "于是只有被指的那一格变色。（整行 hover 的两层底色是默认行为，见 src/Table.qml）")
            }
        }

        // ============================================================ 19
        GallerySection {
            title: "单元格缩略"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 250, fixed: true,
                        ellipsis: true,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0,
                        sorter: (a, b) => String(a.name).localeCompare(String(b.name)) },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 200, ellipsis: true,
                        filters: [{ text: "姜鹏志", value: "姜鹏志" }],
                        onFilter: (value, record) => String(record.owner).indexOf(value) >= 0,
                        sorter: (a, b) => String(a.owner).localeCompare(String(b.owner)) },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("更新日期"), dataIndex: "updateTime", width: 200,
                        ellipsis: true,
                        render: (text) => page.formatDate(text) },
                    { title: qsTr("操作"), dataIndex: "operate", fixed: "right",
                        align: "center", width: 100, render: () => moreCellComp }
                ]
                dataSource: page.longRows
                scroll: ({ x: 1200 })
                pagination: false
            }

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 250, fixed: true,
                        ellipsis: ({ showTitle: false }),
                        render: () => tipCellHolder },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 200,
                        ellipsis: ({ showTitle: false }),
                        render: () => tipCellHolder },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("更新日期"), dataIndex: "updateTime", width: 200,
                        ellipsis: true,
                        render: (text) => page.formatDate(text) },
                    { title: qsTr("操作"), dataIndex: "operate", fixed: "right",
                        align: "center", width: 100, render: () => moreCellComp }
                ]
                dataSource: page.longRows
                scroll: ({ x: 1200 })
                pagination: false
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("官方 demo 的第二份把原生 title 关掉、改用 Typography.Text 的 showTooltip 出提示 —— "
                    + "下面这两列就是这么写的。ellipsis.showTitle 管的是浏览器原生 title，QML 没有那一层，"
                    + "所以端口接了这个字段但没有可见效果。")
            }
        }

        Component {
            id: tipCellHolder

            TextLabel {
                property var record: null
                width: 200
                ellipsis: ({ showTooltip: true })
            }
        }

        // ============================================================ 20
        GallerySection {
            title: "可伸缩列"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 300, resize: false,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0 },
                    { title: qsTr("大小"), dataIndex: "size", width: 200,
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 200,
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) },
                    { title: qsTr("操作列"), dataIndex: "operate", fixed: "right", width: 100,
                        resize: false, render: () => moreCellComp }
                ]
                dataSource: page.genRows(10)
                pagination: ({ pageSize: 5 })
                resizable: true
                bordered: true
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("resizable 时每一列都要给 width；column.resize:false 把那列排除在外。拖的就是表头那格右边那条 9px 宽的把手。")
            }

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0 },
                    { title: qsTr("大小"), dataIndex: "size", width: 200,
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner", width: 200,
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(46)
                pagination: ({ pageSize: 5 })
                bordered: true
                resizable: ({
                    onResizeStart: column => { page.lastLog = qsTr("开始拖 %1").arg(String(column.dataIndex)); },
                    onResizeStop: column => { page.lastLog = qsTr("松手 %1").arg(String(column.dataIndex)); },
                    onResize: column => { page.lastLog = qsTr("拖动中 %1").arg(String(column.dataIndex)); }
                })
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("resizable 传对象时可以挂 onResizeStart / onResize / onResizeStop，官方拿它加减 className。")
                    + (page.lastLog === "" ? "" : "｜" + page.lastLog)
            }
        }

        // ============================================================ 21
        GallerySection {
            title: "拖拽排序"

            Table {
                width: 700
                rowKey: "key"
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0 },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.dragRows.slice((page.dragPage - 1) * 10, page.dragPage * 10)
                pagination: ({
                    currentPage: page.dragPage,
                    pageSize: 10,
                    total: page.dragRows.length
                })
                components: ({ body: ({ row: dragRowComp }) })
                onChanged: info => {
                    page.dragPage = info.pagination.currentPage;
                }
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("官方用 dnd-kit 的 SortableRow 顶替 <tr>（components.body.row）；端口的行节点用 DragHandler，"
                    + "按 53px 行高算目标位置、拖动中即时换位。")
            }
        }

        // ============================================================ 22
        GallerySection {
            title: "表格分组"

            Table {
                width: 700
                rowKey: record => String(record.owner) + "-" + String(record.name)
                groupBy: "size"
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0 },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(20)
                renderGroupSection: (groupKey, group) => groupSectionHolder
                onGroupedRow: (group, index) => ({
                    onClick: () => { page.groupLog = qsTr("点了第 %1 个组头").arg(index); }
                })
                clickGroupedRowToExpand: true
                scroll: ({ y: 480 })
                pagination: false
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("groupBy 也可以是函数；renderGroupSection(groupKey, group) 的第二个参数是这一组的 key 数组；"
                    + "clickGroupedRowToExpand 让组头整行可点展开。")
                    + (page.groupLog === "" ? "" : "｜" + page.groupLog)
            }
        }

        Component {
            id: groupSectionHolder

            Text {
                property var groupKey: undefined
                property var group: null
                text: qsTr("根据文件大小分组 ") + String(groupKey) + " KB"
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: Theme.current.fontWeightBold
            }
        }

        // ============================================================ 23
        GallerySection {
            title: "虚拟化表格"

            Table {
                width: 750
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 200, fixed: true,
                        render: (text, record, index) => nameCellComp,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0 },
                    { title: qsTr("大小"), dataIndex: "size", width: 150,
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime", width: 150, fixed: "right",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(1000)
                scroll: ({ y: 400, x: 900 })
                virtualized: true
                pagination: false
            }

            Paragraph {
                width: 750
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("官方虚拟化底层是 react-window 的 VariableSizeList；QML 侧 ListView 本来就只回收可见条目，"
                    + "所以 virtualized 在这一档只决定 itemSize（文档写默认 56，端口取 constants.ts 的 53/45/37）。"
                    + "getVirtualizedListRef / overscanCount 没有对应物。")
            }
        }

        // ============================================================ 24
        GallerySection {
            title: "无限滚动"

            Table {
                width: 750
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 200, fixed: true,
                        render: (text, record, index) => nameCellComp },
                    { title: qsTr("大小"), dataIndex: "size", width: 150,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime", width: 150, fixed: "right",
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.infiniteRows
                scroll: ({ y: 600, x: 1000 })
                pagination: false
                virtualized: ({
                    itemSize: 53,
                    onScroll: args => {
                        if (args.scrollDirection !== "forward")
                            return;
                        if (args.scrollUpdateWasRequested === true)
                            return;
                        if (args.scrollOffset + 600 >= page.infiniteRows.length * 53 - 600)
                            page.appendInfinite();
                    }
                })
            }

            Paragraph {
                width: 750
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("官方这一节靠 virtualized.onScroll 的 scrollDirection / scrollOffset /"
                    + " scrollUpdateWasRequested 三个量判断「快到底了就补 20 条」；端口同一份入参。")
                    + (page.infiniteLoading ? qsTr("（正在补…）") : "（当前 " + page.infiniteRows.length + " 条）")
            }
        }

        // ============================================================ 25
        GallerySection {
            title: "受控的动态表格"

        }

        // ============================================================ 26
        GallerySection {
            title: "完全自定义渲染"

            Table {
                width: 700
                columns: [
                    { title: (args) => fullCellComp, dataIndex: "name", width: 400,
                        useFullRender: true,
                        filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" },
                            { text: "Semi D2C 设计稿", value: "Semi D2C 设计稿" }],
                        onFilter: (value, record) => String(record.name).indexOf(value) >= 0,
                        render: (text, record, index, options) => fullCellComp },
                    { title: qsTr("大小"), dataIndex: "size",
                        sorter: (a, b) => a.size - b.size,
                        render: (text) => text + " KB" },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text) => page.formatDate(text) }
                ]
                dataSource: page.genRows(46)
                pagination: ({ pageSize: 12 })
                rowSelection: ({ hidden: true, fixed: "left",
                    onChange: keys => { page.selectedKeys = keys; } })
                expandedRowRender: record => moreCellComp
                onChanged: info => { page.lastLog = qsTr("onChange changeType=%1")
                    .arg(info.extra.changeType); }
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("useFullRender:true 时官方不再自己排勾选框 / 展开按钮 / 缩进，而是把它们塞进"
                    + " title({sorter, filter, selection}) 与 render(text, record, index, {expandIcon, selection, indentText})。"
                    + "QML 没有「把组件内部一块 delegate 当子项交出去」的写法，端口给的是标记 + 同一份状态与动作"
                    + "（节点里声明 property var options，用 options.toggleSelection / toggleExpand 发事件）。")
                    + (page.lastLog === "" ? "" : "｜" + page.lastLog)
            }
        }

        // ============================================================ 27
        GallerySection {
            title: "表头合并"

            Table {
                width: 700
                columns: [
                    { title: qsTr("基本信息"), fixed: "left",
                        children: [
                            { title: qsTr("标题"), dataIndex: "name", width: 300, fixed: true,
                                render: (text, record, index) => nameCellComp,
                                filters: [{ text: "Semi Design 设计稿", value: "Semi Design 设计稿" }],
                                onFilter: (value, record) => String(record.name).indexOf(value) >= 0 },
                            { title: qsTr("大小"), dataIndex: "size", width: 100, fixed: true,
                                sorter: (a, b) => a.size - b.size,
                                render: (text) => text + " KB" }
                        ] },
                    { title: qsTr("其他"),
                        children: [
                            { title: qsTr("所有者"), dataIndex: "owner",
                                render: (text, record, index) => ownerCellComp },
                            { title: qsTr("大小2"), dataIndex: "size",
                                render: (text) => text + " KB" }
                        ] },
                    { title: qsTr("更多"), fixed: "right", width: 100, align: "center",
                        dataIndex: "operate", rowSpan: 2, render: () => moreCellComp }
                ]
                dataSource: page.genRows(20)
                scroll: ({ y: 400 })
                rowSelection: ({ fixed: true })
                expandedRowRender: record => moreCellComp
            }

            Table {
                width: 700
                dataSource: page.genRows(20)
                scroll: ({ y: 400 })
                rowSelection: ({ fixed: true })
                expandedRowRender: record => moreCellComp

                TableColumn {
                    title: qsTr("基本信息")
                    fixed: "left"

                    TableColumn {
                        title: qsTr("标题")
                        dataIndex: "name"
                        width: 300
                        fixed: true
                        render: (text, record, index) => nameCellComp
                    }

                    TableColumn {
                        title: qsTr("大小")
                        dataIndex: "size"
                        width: 100
                        fixed: true
                        render: (text) => text + " KB"
                    }
                }

                TableColumn {
                    title: qsTr("更多")
                    fixed: "right"
                    width: 100
                    align: "center"
                    dataIndex: "operate"
                    rowSpan: 2
                    render: () => moreCellComp
                }
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("配置写法用 column.children（JSX 写法就是嵌套 TableColumn），"
                    + "colSpan 取子列之和、没有子列的列 rowSpan 自动到最后一行 —— 官方 parseHeaderRows 那套。")
            }
        }

        // ============================================================ 28
        GallerySection {
            title: "行列合并"

            Table {
                width: 700
                columns: [
                    { title: qsTr("标题"), dataIndex: "name", width: 400,
                        render: (text, record, index) => page.spanNameComp(index) },
                    { title: qsTr("大小"), dataIndex: "size",
                        render: (text, record, index) => page.spanSizeComp(text, index) },
                    { title: qsTr("所有者"), dataIndex: "owner",
                        render: (text, record, index) => ownerCellComp },
                    { title: qsTr("更新日期"), dataIndex: "updateTime",
                        sorter: (a, b) => a.updateTime - b.updateTime,
                        render: (text, record, index) => page.spanTimeComp(text, index) }
                ]
                dataSource: page.genRows(5)
                pagination: false
            }

            Paragraph {
                width: 700
                size: Enums.Small
                tone: Enums.Tertiary
                text: qsTr("官方合并走 render 的返回值：{ children, props: { colSpan, rowSpan } }，"
                    + "被占掉的那些格把自己那格的 colSpan / rowSpan 设成 0 就不画了（TableCell.tsx:289-291）。")
            }
        }
    }

    // ---------------------------------------------------------------- 合并 / 分组用的小节点
    Component {
        id: spanNameHolder

        Text {
            property var record: null
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    function spanNameComp(index) {
        return spanNameHolder;
    }

    function spanSizeComp(text, index) {
        if (index === 0)
            return { children: text + " KB", props: ({ colSpan: 0 }) };
        if (index === 1)
            return { children: text + " KB", props: ({ rowSpan: 2 }) };
        if (index === 2)
            return { children: text + " KB", props: ({ rowSpan: 0 }) };
        return text + " KB";
    }

    function spanTimeComp(text, index) {
        const label = page.formatDate(text);
        if (index === 0)
            return { children: label, props: ({ colSpan: 0 }) };
        if (index === 1)
            return { children: label, props: ({ rowSpan: 2 }) };
        if (index === 2)
            return { children: label, props: ({ rowSpan: 0 }) };
        return label;
    }

    Component {
        id: groupSectionNode

        Text {
            property var groupKey: undefined
            text: qsTr("根据文件大小分组 ") + String(groupKey) + " KB"
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Theme.current.fontWeightBold
        }
    }

    // 名称列那一格的合并写法（第 0 行横跨 4 列）
    function spanNameProps(index) {
        if (index === 0)
            return ({ colSpan: 4 });
        if (index === 1)
            return ({ rowSpan: 2 });
        if (index === 2)
            return ({ rowSpan: 0 });
        return ({});
    }

    Component {
        id: emptyTextHolder

        Text {
            text: qsTr("暂无数据")
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    Component.onCompleted: {
        page.basicRows = page.handRows;
        page.resetCustomRows();
        page.remoteRows = page.genRows(46).slice(0, 5);
        page.dragRows = page.genRows(46);
        page.infiniteRows = page.genRows(20);
    }
}
