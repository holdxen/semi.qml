import QtQuick
import QtTest
import Semi

// Transfer：官方属性面（semi-ui/transfer/index.tsx）+ 交互
// （semi-foundation/transfer/foundation.ts + transferUtils.ts）
// + transfer.scss / variables.scss 的几何与色令牌。
TestCase {
    id: testCase

    name: "Transfer"
    when: windowShown
    width: 900
    height: 700

    // ---- 自定义钩子用的探针组件 ----
    Component {
        id: probeSourceItem

        Item {
            property var modelData: ({})
            property bool checked: false
            property bool hovered: false
            property int index: -1
            property var toggle: null

            objectName: "probeSourceItem" + index
            height: 40
            implicitHeight: 40

            Text {
                objectName: "probeSourceText" + parent.index
                anchors.verticalCenter: parent.verticalCenter
                text: String(parent.modelData.label) + (parent.checked ? "!" : "")
            }

            TapHandler {
                onTapped: {
                    if (parent.toggle !== null)
                        parent.toggle();
                }
            }
        }
    }

    Component {
        id: probeSelectedItem

        Item {
            property var modelData: ({})
            property bool hovered: false
            property int index: -1
            property var remove: null

            objectName: "probeSelectedItem" + index
            height: 40
            implicitHeight: 40

            Text {
                objectName: "probeSelectedText" + parent.index
                anchors.verticalCenter: parent.verticalCenter
                text: String(parent.modelData.label)
            }

            TapHandler {
                onTapped: {
                    if (parent.remove !== null)
                        parent.remove();
                }
            }
        }
    }

    Component {
        id: probeSourceHeader

        Item {
            property int num: 0
            property bool showButton: false
            property bool allChecked: false
            property var allClick: null
            property var leafOnlyNum: undefined

            objectName: "probeSourceHeader"
            implicitHeight: 24

            Text {
                objectName: "probeSourceHeaderText"
                text: "N" + parent.num + "/leaf" + parent.leafOnlyNum
                    + "/b" + parent.showButton + "/a" + parent.allChecked
            }

            TapHandler {
                onTapped: {
                    if (parent.allClick !== null)
                        parent.allClick();
                }
            }
        }
    }

    Component {
        id: probeSelectedHeader

        Item {
            property int num: 0
            property bool showButton: false
            property var clear: null

            objectName: "probeSelectedHeader"
            implicitHeight: 24

            Text {
                objectName: "probeSelectedHeaderText"
                text: "S" + parent.num + "/b" + parent.showButton
            }

            TapHandler {
                onTapped: {
                    if (parent.clear !== null)
                        parent.clear();
                }
            }
        }
    }

    Component {
        id: probeSourcePanel

        Item {
            property var value: []
            property bool loading: false
            property bool noMatch: false
            property var filterData: []
            property var sourceData: []
            property var propsDataSource: []
            property bool allChecked: false
            property int showNumber: 0
            property string inputValue: ""
            property var selectedItems: []
            property var search: null
            property var allClick: null
            property var selectOrRemove: null
            property var selectValues: null

            objectName: "probeSourcePanel"
            // 官方 renderSourcePanel 给的就是那一栏本身：宽高由用户自己定
            width: 300
            height: 200
            implicitWidth: 300
            implicitHeight: 200

            Text {
                objectName: "probeSourcePanelText"
                text: "f" + parent.filterData.length + "/s" + parent.showNumber
                    + "/v" + parent.value.length + "/i" + parent.inputValue
                    + "/a" + parent.allChecked + "/n" + parent.noMatch
            }

            TapHandler {
                onTapped: {
                    if (parent.allClick !== null)
                        parent.allClick();
                }
            }
        }
    }

    Component {
        id: probeSelectedPanel

        Item {
            property int length: 0
            property var selectedData: []
            property var clear: null
            property var remove: null
            property var sortEnd: null

            objectName: "probeSelectedPanel"
            width: 200
            height: 200
            implicitWidth: 200
            implicitHeight: 200

            Text {
                objectName: "probeSelectedPanelText"
                text: "L" + parent.selectedData.length
                    + ":" + parent.selectedData.map(i => i.value).join(",")
            }

            TapHandler {
                onTapped: {
                    if (parent.sortEnd !== null)
                        parent.sortEnd({ oldIndex: 0, newIndex: 1 });
                }
            }
        }
    }

    // ---- 数据 ----
    function flat(n) {
        const out = [];
        for (let i = 0; i < n; ++i)
            out.push({ label: "选项名称 " + i, value: i, disabled: false, key: "key-" + i });
        return out;
    }

    function grouped() {
        return [
            {
                title: "类别A",
                children: [
                    { label: "A-1", value: 1, key: 1 },
                    { label: "A-2", value: 2, key: 2 }
                ]
            },
            {
                title: "类别B",
                children: [
                    { label: "B-1", value: 3, key: 3 },
                    { label: "B-2", value: 4, key: 4, disabled: true }
                ]
            }
        ];
    }

    function tree() {
        return [
            {
                label: "Asia", value: "Asia", key: "0",
                children: [
                    {
                        label: "China", value: "China", key: "0-0",
                        children: [
                            { label: "Beijing", value: "Beijing", key: "0-0-0" },
                            { label: "Shanghai", value: "Shanghai", key: "0-0-1" },
                            { label: "Chengdu", value: "Chengdu", key: "0-0-2" }
                        ]
                    },
                    {
                        label: "Japan", value: "Japan", key: "0-1",
                        children: [
                            { label: "Osaka", value: "Osaka", key: "0-1-0" }
                        ]
                    }
                ]
            },
            {
                label: "NA", value: "NA", key: "1",
                children: [
                    { label: "Cuba", value: "Cuba", key: "1-0" },
                    { label: "Mexico", value: "Mexico", key: "1-1", disabled: true }
                ]
            }
        ];
    }

    property var _live: []

    function make(qml) {
        const item = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "t")
        item.visible = true
        testCase._live = testCase._live.concat([item])
        return item
    }

    // 先写 defaultValue 再写 dataSource：播种发生在 _data 变化时
    function seeded(opts) {
        const t = make("Transfer { }")
        if (opts.width !== undefined)
            t.width = opts.width
        else
            t.width = 568
        t.height = opts.height === undefined ? 416 : opts.height
        if (opts.type !== undefined)
            t.type = opts.type
        if (opts.defaultValue !== undefined)
            t.defaultValue = opts.defaultValue
        if (opts.value !== undefined)
            t.value = opts.value
        if (opts.draggable !== undefined)
            t.draggable = opts.draggable
        if (opts.disabled !== undefined)
            t.disabled = opts.disabled
        if (opts.filter !== undefined)
            t.filter = opts.filter
        if (opts.loading !== undefined)
            t.loading = opts.loading
        if (opts.showPath !== undefined)
            t.showPath = opts.showPath
        if (opts.emptyContent !== undefined)
            t.emptyContent = opts.emptyContent
        if (opts.pagination !== undefined)
            t.pagination = opts.pagination
        if (opts.virtualize !== undefined)
            t.virtualize = opts.virtualize
        if (opts.renderSourceItem !== undefined)
            t.renderSourceItem = opts.renderSourceItem
        if (opts.renderSelectedItem !== undefined)
            t.renderSelectedItem = opts.renderSelectedItem
        if (opts.renderSourceHeader !== undefined)
            t.renderSourceHeader = opts.renderSourceHeader
        if (opts.renderSelectedHeader !== undefined)
            t.renderSelectedHeader = opts.renderSelectedHeader
        if (opts.renderSourcePanel !== undefined)
            t.renderSourcePanel = opts.renderSourcePanel
        if (opts.renderSelectedPanel !== undefined)
            t.renderSelectedPanel = opts.renderSelectedPanel
        if (opts.dataSource !== undefined)
            t.dataSource = opts.dataSource
        // 属性是同一批同步写进来的，代理和布局要再过一轮才就位。
        // 不等就发鼠标事件，打到的是还没排好的旧几何。
        wait(40)
        return t
    }

    function findAll(root, name, out) {
        out = out === undefined ? [] : out
        const kids = root.children
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i].objectName === name)
                out.push(kids[i])
            findAll(kids[i], name, out)
            // qmllint enable missing-property
        }
        return out
    }

    function one(root, name) {
        const hits = findAll(root, name)
        return hits.length > 0 ? hits[0] : null
    }

    function rowNames(t, prefix, count) {
        const out = []
        for (let i = 0; i < count; ++i) {
            const hit = one(t, prefix + i)
            if (hit !== null)
                out.push(hit)
        }
        return out
    }

    function valuesOf(t) {
        return t.selected.map(i => i.value)
    }

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(30)
    }

    // 断言失败会中止当个测试函数，末尾的 destroy 走不到；这里兜一遍，
    // 否则残留实例会盖在同一位置，把下一个测试的鼠标事件吃掉。
    function cleanup() {
        const a = testCase._live
        for (let i = 0; i < a.length; ++i) {
            try {
                a[i].destroy()
            } catch (e) {
            }
        }
        testCase._live = []
    }

    // ---------------------------------------------------------------- 尺寸与几何
    function test_officialDefaultSize() {
        const t = make("Transfer { }")
        compare(t.implicitWidth, 402, "$width-transfer-minWidth")
        compare(t.implicitHeight, 400, "$height-transfer")
        compare(t.width, 402)
        compare(t.height, 400)
        t.destroy()
    }

    function test_frameTokens() {
        const t = seeded({ dataSource: testCase.flat(4) })
        const frame = one(t, "frame")
        // 浅色下 bg-0 / bg-1 都是白，必须换深色才分得出取的是哪一个令牌
        Theme.mode = Theme.Dark
        wait(30)
        const dark = one(t, "frame").color
        compare(dark, Theme.current.colorBg1, "$color-transfer-bg = bg-1")
        verify(dark !== Theme.current.colorBg0, "不是 bg-0")
        compare(frame.border.color, Theme.current.colorBorder)
        compare(frame.border.width, 1, "$width-transfer-border")
        compare(frame.radius, Theme.current.radiusMedium, "$radius-transfer")
        Theme.mode = Theme.Light
        t.destroy()
    }

    function test_panelsAreHalfAndHalf() {
        const t = seeded({ width: 568, dataSource: testCase.flat(4) })
        const left = one(t, "leftPanel")
        const right = one(t, "rightPanel")
        const divider = one(t, "divider")
        compare(left.width, 283, "左栏 = 内容宽的一半")
        compare(right.width, 283, "右栏 = 剩下的")
        compare(right.x, 283)
        compare(divider.width, 1, "$width-transfer_left-border")
        fuzzyCompare(divider.x + divider.width, left.width, 0.6, "分隔线贴在左栏右缘")
        compare(one(t, "leftRow0").height, 36, "$height-transfer_item-minHeight")
        t.destroy()
    }

    function test_headerGeometry() {
        const t = seeded({ dataSource: testCase.flat(4) })
        const leftSlot = one(t, "leftHeaderSlot")
        const leftHeader = one(t, "leftHeader")
        const filterSlot = one(t, "filterSlot")
        // filter: margin 12 + 输入框 32；left header: margin-top 12 + 24 + margin-bottom 8
        compare(filterSlot.height, 12 + 32)
        compare(leftSlot.height, 12 + 24 + 8, "$spacing-transfer_header-margin*")
        compare(leftHeader.height, 24, "$height-transfer_header")
        compare(leftHeader.y, 12)
        compare(leftHeader.x, 12)
        const rightHeader = one(t, "rightHeader")
        compare(rightHeader.height, 32, "$height-transfer_right_header")
        compare(rightHeader.y, 12, "-right-header margin-top = $spacing-base-tight")
        compare(one(t, "rightHeaderSlot").height, 12 + 32)
        t.destroy()
    }

    function test_rowPaddingAndCheckAlignment() {
        const t = seeded({ dataSource: testCase.flat(4) })
        const row = one(t, "leftRow0")
        const box = one(t, "leftCheck0")
        fuzzyCompare(box.x, 12, 0.6, "$spacing-transfer_item-paddingLeft = 12")
        fuzzyCompare(box.y + box.height / 2, row.height / 2, 0.6, "ver-center")
        t.destroy()
    }

    // ---------------------------------------------------------------- 选区语义
    function test_leftPanelShowsAllItemsNotJustUnselected() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1] })
        compare(t.leftRows.length, 6, "官方左栏永远是全量，勾上只是复选框变亮")
        compare(t.selected.length, 1)
        verify(one(t, "leftCheck1").checked, "已选项在左栏仍是勾选态")
        t.destroy()
    }

    function test_headerCounts() {
        const t = seeded({ dataSource: testCase.flat(20), defaultValue: [2, 4] })
        compare(one(t, "leftTotal").text, "总个数：20")
        compare(one(t, "rightTotal").text, "已选个数：2")
        t.destroy()
    }

    function test_clickRowSelectsAndNotifies() {
        const t = seeded({ dataSource: testCase.flat(6) })
        let got = null
        let gotItems = null
        t.change.connect((values, items) => { got = values; gotItems = items; })
        mouseClick(one(t, "leftCheck2"))
        wait(30)
        compare(valuesOf(t).length, 1)
        compare(valuesOf(t)[0], 2)
        compare(got.length, 1)
        compare(got[0], 2)
        compare(gotItems[0].label, "选项名称 2")
        t.destroy()
    }

    function test_clickAgainDeselects() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [3] })
        let deselected = null
        t.deselect.connect(item => { deselected = item; })
        mouseClick(one(t, "leftCheck3"))
        wait(30)
        compare(t.selected.length, 0)
        compare(deselected.value, 3)
        t.destroy()
    }

    function test_selectSignalCarriesRawItem() {
        const t = seeded({ dataSource: testCase.flat(6) })
        let selected = null
        t.select.connect(item => { selected = item; })
        mouseClick(one(t, "leftCheck1"))
        wait(30)
        compare(selected.value, 1)
        compare(selected.fullPath, undefined, "官方 onSelect 给的是没注入 fullPath 的原始项")
        t.destroy()
    }

    function test_disabledTransferIgnoresClicks() {
        const t = seeded({ dataSource: testCase.flat(6), disabled: true })
        let fired = 0
        t.change.connect(() => { fired += 1; })
        mouseClick(one(t, "leftCheck0"))
        wait(30)
        compare(fired, 0)
        compare(t.selected.length, 0)
        verify(one(t, "leftCheck0").disabled, "整框禁用落到每行 Checkbox 的 disabled")
        compare(one(t, "leftTotal").color, Theme.current.colorDisabledText,
            ".semi-transfer-disabled -header 文字色")
        t.destroy()
    }

    function test_disabledItemCannotBeSelected() {
        const t = seeded({ dataSource: [{ label: "关", value: 1, key: 1, disabled: true }] })
        let fired = 0
        t.change.connect(() => { fired += 1; })
        mouseClick(one(t, "leftCheck0"))
        wait(30)
        compare(fired, 0, "禁用项点不动")
        verify(one(t, "leftCheck0").disabled)
        t.destroy()
    }

    function test_selectAllCoversEveryItem() {
        const t = seeded({ dataSource: testCase.flat(6) })
        const btn = one(t, "leftAllButton")
        compare(btn.text, "全选")
        mouseClick(btn)
        wait(30)
        compare(t.selected.length, 6)
        compare(one(t, "leftAllButton").text, "取消全选")
        mouseClick(one(t, "leftAllButton"))
        wait(30)
        compare(t.selected.length, 0)
        t.destroy()
    }

    function test_selectAllSkipsDisabled() {
        const t = seeded({ dataSource: testCase.grouped(), type: "groupList" })
        mouseClick(one(t, "leftAllButton"))
        wait(30)
        compare(valuesOf(t).join(","), "1,2,3", "禁用项不被全选带上")
        t.destroy()
    }

    function test_clearKeepsDisabledSelected() {
        const t = seeded({ dataSource: testCase.grouped(), type: "groupList",
            defaultValue: [2, 4] })
        compare(t.selected.length, 2)
        mouseClick(one(t, "rightClearButton"))
        wait(30)
        compare(valuesOf(t).join(","), "4", "官方 handleClear 只清未禁用的已选项")
        verify(!one(t, "rightClearButton").visible, "没有可清的了就不给清空按钮")
        t.destroy()
    }

    function test_clearButtonHiddenWhenNothingSelected() {
        const t = seeded({ dataSource: testCase.flat(6) })
        verify(!one(t, "rightClearButton").visible)
        compare(one(t, "rightEmpty").text, "暂无内容，可从左侧勾选")
        t.destroy()
    }

    // ---------------------------------------------------------------- 右侧行
    function test_rightRowTextAndCloseSlot() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1] })
        const row = one(t, "rightRow0")
        const text = one(t, "rightText0")
        const close = one(t, "rightClose0")
        compare(row.height, 36)
        fuzzyCompare(text.x, 12, 0.6, "没开拖拽时正文从 padding-left 12 起")
        compare(close.width, 12, "$width-transfer_item_close-icon")
        compare(close.opacity, 0, "平时 visibility: hidden")
        compare(one(t, "rightHandle0").visible, false, "没 draggable 就没有手柄")
        t.destroy()
    }

    function test_closeIconAppearsOnHoverAndRemoves() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1, 2] })
        const close = one(t, "rightClose0")
        compare(close.opacity, 0)
        mouseMove(one(t, "rightRow0"), 60, 18)
        wait(40)
        compare(one(t, "rightClose0").opacity, 1, "悬浮才出现")
        mouseClick(one(t, "rightClose0"))
        wait(30)
        compare(valuesOf(t).join(","), "2")
        t.destroy()
    }

    function test_rightRowHoverBackground() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1] })
        compare(one(t, "rightRowBg0").color, Qt.color("transparent"))
        mouseMove(one(t, "rightRow0"), 60, 18)
        wait(40)
        compare(one(t, "rightRowBg0").color, Theme.current.colorFill0,
            ".semi-transfer-item:hover = fill-0")
        t.destroy()
    }

    function test_leftRowHoverBackground() {
        const t = seeded({ dataSource: testCase.flat(6) })
        compare(one(t, "leftRowBg0").color, Qt.color("transparent"))
        mouseMove(one(t, "leftRow0"), 60, 18)
        wait(40)
        compare(one(t, "leftRowBg0").color, Theme.current.colorFill0)
        t.destroy()
    }

    // ---------------------------------------------------------------- 拖拽排序
    function test_draggableAddsHandles() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1, 2], draggable: true })
        const handle = one(t, "rightHandle0")
        verify(handle.visible)
        compare(handle.width, 16, "$width-icon-medium")
        fuzzyCompare(one(t, "rightText0").x, 12 + 16 + 4, 0.6,
            "$spacing-transfer_right_item_drag_handler-marginRight = 4")
        t.destroy()
    }

    function test_dragReordersSelected() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1, 2, 3],
            draggable: true })
        compare(valuesOf(t).join(","), "1,2,3")
        const handle = one(t, "rightHandle0")
        let last = null
        t.change.connect(values => { last = values; })
        mousePress(handle, 8, 8)
        mouseMove(handle, 8, 8 + 40)
        mouseMove(handle, 8, 8 + 80)
        wait(40)
        mouseMove(handle, 8, 8 + 80)
        wait(40)
        compare(t._dropIndex, 2, "拖到第三行附近")
        mouseRelease(handle, 8, 8 + 80)
        wait(40)
        compare(valuesOf(t).join(","), "2,3,1", "官方 handleSortEnd 是 arrayMove")
        compare(last.join(","), "2,3,1")
        t.destroy()
    }

    // ---------------------------------------------------------------- 搜索
    function test_searchBoxPlaceholderAndIcon() {
        const t = seeded({ dataSource: testCase.flat(6) })
        const input = one(t, "filterInput")
        compare(input.placeholderText, "搜索")
        compare(input.prefixIcon, "search")
        verify(input.showClear)
        t.destroy()
    }

    function test_inputPropsOverride() {
        const t = make("Transfer { inputProps: ({ placeholder: \"搜姓名\", size: Enums.Small }) }")
        t.dataSource = testCase.flat(6)
        wait(30)
        compare(one(t, "filterInput").placeholderText, "搜姓名")
        compare(one(t, "filterInput").size, Enums.Small)
        compare(t.inputHeight, 24, "$height-control-small")
        t.destroy()
    }

    function test_typingFiltersAndEmitsSearch() {
        const t = seeded({ dataSource: testCase.flat(20) })
        let searched = null
        t.search.connect(v => { searched = v; })
        const input = one(t, "filterInput")
        input.input.forceActiveFocus()
        wait(60)
        keyClick(Qt.Key_1)
        wait(40)
        compare(searched, "1")
        compare(t.showNumber, 11, "含 1 的标签：选项名称 1 与 10~19")
        t.destroy()
    }

    function test_searchNarrowsLeftListAndHeader() {
        const t = seeded({ dataSource: testCase.flat(20) })
        t.searchBy("选项名称 1")
        wait(30)
        compare(t.filterData.length, 11, "1 与 10..19")
        compare(one(t, "leftTotal").text, "总个数：11")
        compare(t.leftRows.length, 11)
        t.searchBy("")
        wait(30)
        compare(t.filterData.length, 20)
        t.destroy()
    }

    function test_searchByDoesNotEmitSearch() {
        const t = seeded({ dataSource: testCase.flat(20) })
        let fired = 0
        t.search.connect(() => { fired += 1; })
        t.searchBy("3")
        wait(30)
        compare(fired, 0, "官方 search(value) 是手动触发，不回抛 onSearch")
        compare(one(t, "filterInput").text, "3", "搜索值要写回输入框")
        t.destroy()
    }

    function test_noMatchShowsSearchEmpty() {
        const t = seeded({ dataSource: testCase.flat(6) })
        t.searchBy("zzz")
        wait(30)
        verify(one(t, "leftEmpty").visible)
        compare(one(t, "leftEmpty").text, "无搜索结果")
        verify(!one(t, "leftHeaderSlot").visible, "官方 noMatch 分支不出头部")
        verify(one(t, "filterSlot").visible, "搜索框还在")
        t.destroy()
    }

    function test_emptyDataSourceShowsEmptyLeft() {
        const t = seeded({ dataSource: [] })
        verify(one(t, "leftEmpty").visible)
        compare(one(t, "leftEmpty").text, "暂无数据")
        compare(one(t, "leftEmpty").height, 36, "$height-transfer_left_empty")
        t.destroy()
    }

    function test_emptyContentOverrides() {
        const t = seeded({ dataSource: [], emptyContent: ({ left: "没有源数据",
            search: "没搜到", right: "从左边挑" }) })
        compare(one(t, "leftEmpty").text, "没有源数据")
        compare(one(t, "rightEmpty").text, "从左边挑")
        t.destroy()
    }

    function test_filterFalseHidesSearchBox() {
        const t = seeded({ dataSource: testCase.flat(6), filter: false })
        verify(!one(t, "filterSlot").visible)
        compare(one(t, "leftHeaderSlot").y, 0, "槽位高度归 0，头部顶上去")
        compare(one(t, "leftBody").y, 44)
        t.destroy()
    }

    function test_customFilterFunction() {
        const t = make("Transfer { filter: function (input, item) { return item.value % 2 === 0; } }")
        t.dataSource = testCase.flat(10)
        wait(30)
        t.searchBy("x")
        wait(30)
        compare(t.filterData.length, 5, "自定义筛选按奇偶留一半")
        t.destroy()
    }

    // ---------------------------------------------------------------- 分组
    function test_groupListFlattensWithParentTitles() {
        const t = seeded({ dataSource: testCase.grouped(), type: "groupList" })
        const kinds = t.leftRows.map(r => r.kind)
        compare(kinds.join(","), "group,item,item,group,item,item")
        const titles = findAll(t, "groupTitleText").filter(i => i.visible)
            .map(i => i.text)
        compare(titles.join(","), "类别A,类别B")
        compare(one(t, "groupTitle").height, 28, "$height-transfer_group_title")
        t.destroy()
    }

    function test_groupListChangeOmitsParentField() {
        const t = seeded({ dataSource: testCase.grouped(), type: "groupList" })
        let items = null
        t.change.connect((values, got) => { items = got; })
        // 第 0 行是组标题（它的 Checkbox 只是不显示），第一个可点的是行 1
        mouseClick(one(t, "leftCheck1"))
        wait(30)
        compare(items[0]._parent, undefined, "官方通知时抹掉 _parent")
        compare(items[0].label, "A-1")
        t.destroy()
    }

    // ---------------------------------------------------------------- 分页
    // Pagination 端口的页码格没有编号 objectName（官方也没有），按格子里的数字认门
    function pageCell(t, n) {
        const pager = one(t, "leftPagination")
        if (pager === null)
            return null
        const kids = pager.children
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].objectName !== "paginationCell")
                continue
            const label = testCase.findChild(kids[i], "paginationCellText")
            if (label !== null && label.text === String(n))
                return kids[i]
        }
        return null
    }

    function test_paginationSlicesLeftList() {
        const t = seeded({ dataSource: testCase.flat(100), pagination: ({ pageSize: 10 }) })
        compare(t.pageSize, 10)
        compare(t.totalPage, 10)
        verify(t.paginationShown)
        compare(t.pagedData.length, 10)
        compare(t.leftRows.length, 10)
        compare(one(t, "leftRow0").height, 36)
        compare(one(t, "leftTotal").text, "总个数：100", "头部计数是全量，不是本页")
        compare(one(t, "leftPagination").currentPage, 1)
        t.destroy()
    }

    function test_paginationDefaultPageSizeIsTen() {
        const t = seeded({ dataSource: testCase.flat(30), pagination: ({}) })
        compare(t.pageSize, 10, "numbers.DEFAULT_PAGE_SIZE")
        compare(t.pagedData.length, 10)
        t.destroy()
    }

    function test_paginationHiddenForSinglePage() {
        const t = seeded({ dataSource: testCase.flat(6), pagination: ({ pageSize: 10 }) })
        verify(!t.paginationShown)
        verify(!one(t, "paginationSlot").visible)
        compare(t.pagedData.length, 6)
        t.destroy()
    }

    function test_pageChangeEmitsAndSlices() {
        const t = seeded({ dataSource: testCase.flat(100), pagination: ({ pageSize: 10 }) })
        let page = 0
        t.pageChanged.connect(p => { page = p; })
        const cell2 = pageCell(t, 2)
        verify(cell2 !== null, "Pagination 得真的画出第 2 页按钮")
        verify(cell2.x > 40, "位置器要把第 2 格排到第 1 格右边（实得 " + cell2.x + "）")
        mouseClick(cell2, 16, 16)
        wait(40)
        compare(page, 2, "点第 2 页")
        compare(t.currentPage, 2)
        compare(one(t, "leftPagination").currentPage, 2, "页码控件的显示要跟着走")
        compare(t.pagedData[0].value, 10)
        t.destroy()
    }

    function test_controlledPaginationIgnoresInternalPage() {
        const t = seeded({ dataSource: testCase.flat(100),
            pagination: ({ pageSize: 10, currentPage: 5 }) })
        compare(t.currentPage, 5)
        compare(t.pagedData[0].value, 40)
        const cell4 = pageCell(t, 4)
        verify(cell4 !== null && cell4.x > 40, "第 4 格要画出来且排好位置")
        mouseClick(cell4, 16, 16)
        wait(40)
        compare(t.currentPage, 5, "受控时内部页码不生效，显示仍跟着 currentPage")
        compare(one(t, "leftPagination").currentPage, 5, "点完第 4 页立刻被拉回第 5 页")
        t.destroy()
    }

    function test_searchResetsLeftPage() {
        const t = seeded({ dataSource: testCase.flat(100), pagination: ({ pageSize: 10 }) })
        t._page = 4
        wait(20)
        t.searchBy("选项名称 9")
        wait(30)
        compare(t._page, 1, "官方 updateInput 顺手把 leftCurrentPage 打回 1")
        compare(t.filterData.length, 11)
        t.destroy()
    }

    function test_selectAllIgnoresPagination() {
        const t = seeded({ dataSource: testCase.flat(100), pagination: ({ pageSize: 10 }) })
        mouseClick(one(t, "leftAllButton"))
        wait(40)
        compare(t.selected.length, 100, "全选作用域是筛选结果全部，不是当前页")
        t.destroy()
    }

    // ---------------------------------------------------------------- 树
    function test_treeListFlattensWithPaths() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList" })
        compare(t._data.map(i => i.label).join(","),
            "Asia,China,Beijing,Shanghai,Chengdu,Japan,Osaka,NA,Cuba,Mexico")
        compare(t.treeLeafCount(), 6)
        compare(t.treeRows.length, 10, "defaultExpandAll")
        t.destroy()
    }

    function test_treeHeaderHasNoSelectAll() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList" })
        verify(!one(t, "leftAllButton").visible,
            "官方 showButton = type !== treeList")
        compare(one(t, "leftTotal").text, "总个数：10")
        t.destroy()
    }

    function test_treeParentToggleSelectsLeafDescendants() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList" })
        let notified = 0
        t.select.connect(() => { notified += 1; })
        mouseClick(one(t, "treeCheck1"))
        wait(40)
        compare(valuesOf(t).join(","), "Beijing,Shanghai,Chengdu", "勾父带子，只收叶子")
        verify(one(t, "treeCheck1").checked)
        compare(notified, 0, "官方 handleSelect（树）只回抛 onChange，不回抛 onSelect")
        mouseClick(one(t, "treeCheck1"))
        wait(40)
        compare(t.selected.length, 0, "再点一次父节点是整支取消")
        t.destroy()
    }

    function test_treeHalfChecked() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList",
            value: ["Shanghai"] })
        const china = t.treeNodes[1]
        compare(t.nodeChecked(china), false)
        compare(t.nodeHalfChecked(china), true)
        const asia = t.treeNodes[0]
        compare(t.nodeHalfChecked(asia), true)
        verify(one(t, "treeCheck1").indeterminate, "半选态要画出来")
        t.destroy()
    }

    function test_treeDisabledLeafSkippedByParentToggle() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList" })
        mouseClick(one(t, "treeCheck7"))
        wait(40)
        compare(valuesOf(t).join(","), "Cuba", "Mexico 是禁用叶子，不参与")
        verify(one(t, "treeCheck9").disabled)
        t.destroy()
    }

    function test_treeShowPathLabel() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList",
            showPath: true, value: ["Shanghai"] })
        compare(one(t, "rightText0").text, "Asia > China > Shanghai")
        t.destroy()
    }

    function test_treeWithoutShowPathUsesLeafLabel() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList",
            value: ["Shanghai"] })
        compare(one(t, "rightText0").text, "Shanghai")
        t.destroy()
    }

    function test_treeDeselectCarriesFullPath() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList",
            showPath: true, value: ["Shanghai"] })
        let gone = null
        t.deselect.connect(item => { gone = item; })
        mouseMove(one(t, "rightRow0"), 60, 18)
        wait(40)
        mouseClick(one(t, "rightClose0"))
        wait(40)
        compare(gone.fullPath.map(i => i.label).join(","), "Asia,China,Shanghai")
        t.destroy()
    }

    function test_treeSearchHighlightsInsteadOfFiltering() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList" })
        t.searchBy("China")
        wait(40)
        compare(t.filterData.length, 10, "官方 treeList 的 searchResult 是全集")
        compare(t.showNumber, 10)
        verify(one(t, "treeMatch1").visible, "命中的那一行换成高亮文本")
        verify(!one(t, "treeLabel1").visible, "命中行不再画普通文本")
        verify(!one(t, "treeMatch0").visible && !one(t, "treeMatch2").visible,
            "没命中的行不画高亮")
        t.destroy()
    }

    function test_treeCollapseHidesDescendants() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList" })
        mouseClick(one(t, "treeCaret0"))
        wait(40)
        // 折叠 Asia：China/Japan 连同它们的叶子一起没了，NA 那一支照旧展开
        compare(t.treeRows.map(i => i.label).join(","), "Asia,NA,Cuba,Mexico")
        compare(t.treeRows.length, 4)
        mouseClick(one(t, "treeCaret0"))
        wait(40)
        compare(t.treeRows.length, 10)
        t.destroy()
    }

    function test_leafOnlyNumInjectedIntoHeader() {
        const t = seeded({ dataSource: testCase.tree(), type: "treeList",
            renderSourceHeader: probeSourceHeader })
        const text = one(t, "probeSourceHeaderText")
        compare(text.text, "N10/leaf6/bfalse/afalse")
        t.destroy()
    }

    // ---------------------------------------------------------------- 受控
    function test_controlledValueDrivesSelection() {
        const t = seeded({ dataSource: testCase.flat(6), value: [1, 3] })
        compare(valuesOf(t).join(","), "1,3")
        mouseClick(one(t, "leftCheck5"))
        wait(30)
        compare(valuesOf(t).join(","), "1,3", "官方受控时不写内部 state，显示仍跟着 value")
        t.destroy()
    }

    function test_controlledEmitsChangeWithNewValues() {
        const t = seeded({ dataSource: testCase.flat(6), value: [1] })
        let got = null
        t.change.connect(values => { got = values; })
        mouseClick(one(t, "leftCheck2"))
        wait(30)
        compare(got.join(","), "1,2", "受控时回抛的是算出来的新数组")
        t.destroy()
    }

    function test_lateDataSourceStillSeedsDefaultValue() {
        const t = make("Transfer { defaultValue: [1, 4] }")
        t.width = 568
        t.height = 416
        wait(30)
        compare(t.selected.length, 0)
        t.dataSource = testCase.flat(6)
        wait(40)
        compare(valuesOf(t).join(","), "1,4")
        t.destroy()
    }

    function test_creationTimeDefaultValueSeeds() {
        // dataSource 和 defaultValue 同一批在创建时就给好，不会触发 on_DataChanged，
        // 只有 Component.onCompleted 那次播种能处理
        const t = make("Transfer { width: 568; height: 416; defaultValue: [1, 4]; "
            + "dataSource: [{ label: \"a\", value: 0, key: 0 }, "
            + "{ label: \"b\", value: 1, key: 1 }, { label: \"c\", value: 4, key: 4 }] }")
        wait(40)
        compare(valuesOf(t).join(","), "1,4")
        t.destroy()
    }

    function test_userSelectionSurvivesDataRefresh() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1] })
        mouseClick(one(t, "leftCheck3"))
        wait(30)
        t.dataSource = testCase.flat(8)
        wait(40)
        compare(valuesOf(t).join(","), "1,3", "播过种之后不再拿 defaultValue 覆盖")
        t.destroy()
    }

    // ---------------------------------------------------------------- 钩子
    function test_renderSourceItemHook() {
        const t = seeded({ dataSource: testCase.flat(3), renderSourceItem: probeSourceItem })
        const cell = one(t, "probeSourceItem0")
        verify(cell !== null)
        compare(one(t, "probeSourceText0").text, "选项名称 0")
        verify(!one(t, "leftCheck0").visible, "自定义行不再画默认 Checkbox")
        compare(one(t, "leftRowBg0").visible, false, "默认底色也让位给用户")
        mouseClick(cell)
        wait(40)
        compare(valuesOf(t).join(","), "0")
        compare(one(t, "probeSourceText0").text, "选项名称 0!", "checked 要注入回来自定义行")
        t.destroy()
    }

    function test_renderSelectedItemHook() {
        const t = seeded({ dataSource: testCase.flat(3), defaultValue: [1],
            renderSelectedItem: probeSelectedItem })
        const cell = one(t, "probeSelectedItem0")
        verify(cell !== null)
        compare(one(t, "probeSelectedText0").text, "选项名称 1")
        verify(!one(t, "rightText0").visible, "自定义行不画默认正文")
        verify(!one(t, "rightRowBg0").visible, "自定义行的底色归用户")
        mouseClick(cell)
        wait(40)
        compare(t.selected.length, 0, "remove() 注入的是官方 onRemove")
        t.destroy()
    }

    function test_renderHeaderHooks() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1],
            renderSourceHeader: probeSourceHeader,
            renderSelectedHeader: probeSelectedHeader })
        compare(one(t, "probeSourceHeaderText").text, "N6/leafundefined/btrue/afalse")
        compare(one(t, "probeSelectedHeaderText").text, "S1/btrue")
        compare(one(t, "leftHeader").visible, false)
        mouseClick(one(t, "probeSourceHeader"))
        wait(40)
        compare(t.selected.length, 6, "allClick 走官方 handleAll")
        mouseClick(one(t, "probeSelectedHeader"))
        wait(40)
        compare(t.selected.length, 0, "clear 走官方 handleClear")
        t.destroy()
    }

    function test_customPanelModeDropsFrame() {
        const t = seeded({ width: 500, dataSource: testCase.flat(6),
            renderSourcePanel: probeSourcePanel,
            renderSelectedPanel: probeSelectedPanel })
        verify(t.customPanel)
        verify(!one(t, "frame").visible, "-custom-panel { border: none }")
        verify(!one(t, "bodyHost").visible)
        compare(t.implicitWidth, 300 + 200, "尺寸跟着两个面板")
        compare(t.implicitHeight, 200)
        // 没有外层定宽时，整框就收成分裂板的宽度（而不是 402 默认宽）
        const free = make("Transfer { }")
        free.renderSourcePanel = probeSourcePanel
        free.renderSelectedPanel = probeSelectedPanel
        free.dataSource = testCase.flat(6)
        wait(40)
        compare(free.width, 500, "$width-transfer-minWidth 不适用于 -custom-panel")
        compare(free.height, 200)
        free.destroy()
        t.destroy()
    }

    function test_customPanelReceivesContext() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1, 2],
            renderSourcePanel: probeSourcePanel,
            renderSelectedPanel: probeSelectedPanel })
        compare(one(t, "probeSourcePanelText").text, "f6/s6/v2/i/afalse/nfalse")
        compare(one(t, "probeSelectedPanelText").text, "L2:1,2")
        t.searchBy("选项名称 3")
        wait(40)
        compare(one(t, "probeSourcePanelText").text, "f1/s1/v2/i选项名称 3/afalse/nfalse")
        t.destroy()
    }

    function test_customPanelCallbacks() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1, 2, 3],
            renderSourcePanel: probeSourcePanel,
            renderSelectedPanel: probeSelectedPanel })
        mouseClick(one(t, "probeSelectedPanel"))
        wait(40)
        compare(valuesOf(t).join(","), "2,1,3", "onSortEnd({oldIndex:0,newIndex:1}) 走 arrayMove")
        mouseClick(one(t, "probeSourcePanel"))
        wait(40)
        compare(t.selected.length, 6, "onAllClick")
        t.destroy()
    }

    // ---------------------------------------------------------------- 其它状态
    function test_loadingReplacesLeftContent() {
        const t = seeded({ dataSource: testCase.flat(6), loading: true })
        verify(one(t, "leftSpin").visible)
        verify(!one(t, "leftHeaderSlot").visible, "头部槽位高度归 0")
        verify(!one(t, "leftFlick").visible)
        verify(one(t, "filterSlot").visible, "官方 loading 只换内容区，搜索框还在")
        t.destroy()
    }

    function test_virtualizeUsesListView() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1, 2, 3],
            virtualize: ({ itemSize: 40 }) })
        verify(t.useVirtualList)
        verify(!one(t, "rightFlick").visible, "虚拟化时普通列表要让位")
        const rows = rowNames(t, "virtualRow", 3)
        compare(rows.length, 3)
        compare(rows[0].height, 40, "virtualize.itemSize")
        compare(one(t, "rightVirtual").height, 416 - 2 - 44)
        t.destroy()
    }

    function test_virtualizeIgnoredWhenDraggable() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1],
            draggable: true, virtualize: ({ itemSize: 40 }) })
        verify(!t.useVirtualList, "官方：virtualize 只在 draggable 为 false 时生效")
        verify(one(t, "rightFlick").visible)
        t.destroy()
    }

    function test_leftRowActiveBackground() {
        const t = seeded({ dataSource: testCase.flat(6) })
        compare(one(t, "leftRowBg0").color, Qt.color("transparent"))
        mousePress(one(t, "leftRow0"), 60, 18)
        wait(40)
        compare(one(t, "leftRowBg0").color, Theme.current.colorFill1,
            ".semi-checkbox:active 的整行底色 = fill-1")
        mouseRelease(one(t, "leftRow0"), 60, 18)
        wait(40)
        t.destroy()
    }

    function test_rightRowActiveBackground() {
        const t = seeded({ dataSource: testCase.flat(6), defaultValue: [1] })
        mouseMove(one(t, "rightRow0"), 60, 18)
        wait(40)
        const close = one(t, "rightClose0")
        mousePress(close, close.width / 2, close.height / 2)
        wait(40)
        compare(one(t, "rightRowBg0").color, Theme.current.colorFill1,
            "关闭图标按下时整行 = fill-1")
        mouseRelease(close, close.width / 2, close.height / 2)
        wait(40)
        t.destroy()
    }
}
