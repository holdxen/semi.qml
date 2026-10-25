import QtQuick
import QtTest
import Semi

// TreeSelect：官方属性面（semi-ui/treeSelect/index.tsx 的 TreeSelectProps）+ 交互
// （semi-foundation/treeSelect/foundation.ts、semi-foundation/tree/treeUtil.ts）
// + treeSelect.scss / tree.scss / 两份 variables.scss 的几何与色令牌。
//
// 三条实测出来的规矩，写测试前先记住：
//   · 弹层里的行只能用 ts.rowAt(i) 取 —— Popup 不是 Item，Repeater 代理也不在
//     contentItem 的 QObject 子树里，findChild 从弹层往下找不到它们。
//   · 模型一变（展开、勾选、搜索）代理整批重建，所以每次操作后都要重新取行，
//     并且等一行几何真的排好了再点（clickRow / clickCheck 里已经包了）。
//   · 行号会随状态漂移，一律用 key 反查行号（rowIndexOf）。
TestCase {
    id: testCase

    name: "TreeSelect"
    when: windowShown
    width: 900
    height: 700

    // 官方「多选 / 可搜索」那棵树，全展开是 10 行
    readonly property var worldTree: [
        { label: "Asia", value: "Asia", key: "0", children: [
            { label: "China", value: "China", key: "0-0", children: [
                { label: "Beijing", value: "Beijing", key: "0-0-0" },
                { label: "Shanghai", value: "Shanghai", key: "0-0-1" },
                { label: "Chengdu", value: "Chengdu", key: "0-0-2" }] },
            { label: "Japan", value: "Japan", key: "0-1", children: [
                { label: "Osaka", value: "Osaka", key: "0-1-0" }] }] },
        { label: "North America", value: "North America", key: "1", children: [
            { label: "United States", value: "United States", key: "1-0" },
            { label: "Canada", value: "Canada", key: "1-1" }] }
    ]

    // 严格禁用那棵：中国 disabled，下面两个城市可点
    readonly property var strictTree: [
        { label: "亚洲", value: "Asia", key: "0", children: [
            { label: "中国", value: "China", key: "0-0", disabled: true, children: [
                { label: "北京", value: "Beijing", key: "0-0-0" },
                { label: "上海", value: "Shanghai", key: "0-0-1" }] },
            { label: "日本", value: "Japan", key: "0-1" }] },
        { label: "北美洲", value: "North America", key: "1" }
    ]

    property var changeLog: []
    property var selectLog: []
    property var searchLog: []
    property var expandLog: []
    property int clearCount: 0
    property var visibleLog: []
    property var loadLog: []
    property int loadCount: 0

    property var _live: []
    property var pendingDone: null

    function make(qml) {
        const item = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "t")
        item.visible = true
        testCase._live = testCase._live.concat([item])
        return item
    }

    function opened(qml, tree, expandKeys) {
        const ts = make(qml)
        ts.treeData = tree
        waitForRendering(ts)
        wait(30)
        ts.open()
        wait(30)
        const keys = expandKeys === undefined ? [] : expandKeys
        for (let i = 0; i < keys.length; ++i)
            ts.toggleExpand(keys[i])
        wait(60)
        return ts
    }

    function rowIndexOf(ts, key) {
        const list = ts.visibleOptions
        for (let i = 0; i < list.length; ++i) {
            if (list[i].key === key)
                return i
        }
        return -1
    }

    // 等 Column 真的把这一列排好版再点。代理刚重建完时行的 height 已经是 28
    // （代理自己写的），但 y 还是 0 —— 只等 height 会点到叠在一起的后一行。
    // 展开动画那一组在排布上只占**一格**，组里那条行的 y 是组内坐标，
    // 所以这里按格核对，并且要求「格数 == 行数」—— 不相等就是动画还在跑，等它收完。
    function readyRow(ts, key) {
        const i = rowIndexOf(ts, key)
        verify(i >= 0, "树里找不到 key=" + key + "（可见 " + ts.visibleOptions.length + " 行）")
        verify(ts.rowAt(i) !== null, "rowAt(" + i + ") 为空")
        tryVerify(function () {
            const e = ts.entryCount
            const last = ts.entryAt(e - 1)
            return e > 0 && e === ts.rowCount() && last !== null
                && last.height > 0 && last.y === (e - 1) * 28
        })
        return ts.rowAt(i)
    }

    function clickRow(ts, key) {
        mouseClick(readyRow(ts, key), 60, 14)
        wait(30)
    }

    function clickCheck(ts, key) {
        const row = readyRow(ts, key)
        mouseClick(row._check, 8, 8)
        wait(30)
    }

    function clickCaret(ts, key) {
        const row = readyRow(ts, key)
        // 箭头槽：x = 8 + level*20 起、宽 12
        mouseClick(row._caret, 6, 6)
        wait(30)
    }

    // 等那一手展开/收起动画跑完（官方 Collapsible 那 200ms）。
    // 动画期间被收掉的那几行**还在**（它们住在动画组里），
    // 所以凡是「收完就该少几行」的断言都得先过这一道。
    function settle(ts) {
        tryVerify(function () { return Object.keys(ts.motionMapView).length === 0; }, 1500)
        compare(Object.keys(ts.motionMapView).length, 0, "动画没收干净")
    }

    function hook(ts) {
        ts.change.connect(function (value, nodes) {
            testCase.changeLog.push([value, nodes.length])
        })
        ts.select.connect(function (key, selected) {
            testCase.selectLog.push([key, selected])
        })
        ts.search.connect(function (input, expandedKeys, nodes) {
            testCase.searchLog.push([input, expandedKeys.slice().sort(), nodes.length])
        })
        ts.expand.connect(function (keys, info) {
            testCase.expandLog.push([keys.length, info.expanded])
        })
        ts.clear.connect(function () { testCase.clearCount++ })
        ts.visibleChange.connect(function (open) { testCase.visibleLog.push(open) })
        ts.load.connect(function (keys) { testCase.loadLog.push(keys.length) })
    }

    function resetLogs() {
        testCase.changeLog = []
        testCase.selectLog = []
        testCase.searchLog = []
        testCase.expandLog = []
        testCase.clearCount = 0
        testCase.visibleLog = []
        testCase.loadLog = []
        testCase.loadCount = 0
    }

    function sorted(a) {
        return a.slice().sort()
    }

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
        resetLogs()
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

    // ---------------------------------------------------------------- 默认值
    // 官方 defaultProps（treeSelect/index.tsx:280-320）。抄错一个默认值，
    // 所有没显式写这个属性的用户都会跟着变。
    function test_officialDefaults() {
        const ts = make("TreeSelect { }")
        verify(!ts.multiple, "multiple 默认 false")
        verify(!ts.disabled)
        verify(!ts.leafOnly)
        verify(!ts.disableStrictly)
        verify(!ts.remote)
        verify(!ts.expandAll)
        verify(!ts.defaultExpandAll)
        verify(!ts.autoExpandParent)
        verify(!ts.borderless)
        verify(!ts.triggerTagWrap)
        verify(!ts.searchAutoFocus)
        verify(!ts.showRestTagsPopover)
        verify(!ts.labelEllipsis)
        verify(!ts.defaultOpen)
        verify(ts.clickToHide, "clickToHide 默认 true")
        verify(ts.clickTriggerToHide, "clickTriggerToHide 默认 true")
        verify(ts.autoMergeValue, "autoMergeValue 默认 true")
        verify(ts.dropdownMatchSelectWidth, "dropdownMatchSelectWidth 默认 true")
        verify(ts.showSearchClear, "showSearchClear 默认 true")
        verify(ts.motion, "motion 默认 true（index.tsx:298）")
        verify(ts.motionExpand, "motionExpand 默认 true（index.tsx:299）")
        verify(!ts.showClear, "showClear 默认 false")
        verify(!ts.filterTreeNode, "filterTreeNode 默认 false")
        compare(ts.checkRelation, "related")
        compare(ts.searchPosition, "dropdown")
        compare(ts.treeNodeFilterProp, "label")
        compare(ts.treeNodeLabelProp, "label")
        compare(ts.size, Enums.Default)
        compare(ts.validateStatus, Enums.StatusDefault)
        compare(ts.maxTagCount, -1, "官方 undefined = 不限制")
        compare(ts.value, undefined, "官方无默认值 = 非受控")
        compare(ts.expandedKeys, undefined)
        compare(ts.loadedKeys, undefined)
        compare(ts.loadData, null)
        compare(ts.renderSelectedItem, null)
        compare(ts.triggerRender, null)
        // 官方 state 初值是 motionType='hide'（index.tsx:359），第一次建模型不许置空
        const fresh = make("TreeSelect { treeData: [{ label: '根', value: 'r', key: 'r',"
            + " children: [{ label: '子', value: 'c', key: 'c' }] }] }")
        compare(fresh.motionTypeView, "hide", "第一次建模型不动 motionType")
    }

    // ---------------------------------------------------------------- 尺寸与几何
    function test_triggerHeights() {
        compare(make("TreeSelect { }").implicitHeight, 32, "$height-control-default")
        compare(make("TreeSelect { size: Enums.Small }").implicitHeight, 24)
        compare(make("TreeSelect { size: Enums.Large }").implicitHeight, 40)
        compare(make("TreeSelect { }").implicitWidth, 240)
    }

    // 触发器令牌：$border-radius-treeSelect_trigger=3、$width-treeSelect-border=1、
    // 单选 padding-left 12（$spacing-treeSelect_selection-paddingLeft）、多选 4
    // （-multiple-paddingLeft）、箭头 / 清除盒 32
    function test_triggerTokens() {
        const single = make("TreeSelect { width: 300 }")
        compare(single._trigger.radius, 3)
        compare(single._trigger.border.width, 1)
        compare(single.padLeft, 12)
        compare(single.suffixBox, 32)
        compare(make("TreeSelect { width: 300; multiple: true }").padLeft, 4)
    }

    // 官方 rest 态描边是 transparent（$color-treeSelect_default-border-default），
    // 底色 fill-0；warning / danger 走 *-light-default；禁用走 disabled-fill
    function test_triggerSurfaceColors() {
        const plain = make("TreeSelect { width: 300 }")
        waitForRendering(plain)
        wait(30)
        compare(plain._trigger.border.color, Qt.color("transparent"), "rest 态没有描边")
        compare(plain._trigger.color, Theme.current.colorFill0)
        const warn = make("TreeSelect { width: 300; validateStatus: Enums.StatusWarning }")
        compare(warn._trigger.color, Theme.current.colorWarningLightDefault)
        const danger = make("TreeSelect { width: 300; validateStatus: Enums.StatusDanger }")
        compare(danger._trigger.color, Theme.current.colorDangerLightDefault)
        const off = make("TreeSelect { width: 300; disabled: true }")
        compare(off._trigger.color, Theme.current.colorDisabledFill)
        const bare = make("TreeSelect { width: 300; borderless: true }")
        compare(bare._trigger.color, Qt.color("transparent"))
    }

    // 聚焦才有那 1px focus 描边（.semi-treeselect-focus）
    function test_focusRingOnActiveFocus() {
        const ts = make("TreeSelect { width: 300 }")
        waitForRendering(ts)
        wait(30)
        compare(ts._trigger.border.color, Qt.color("transparent"))
        ts._trigger.forceActiveFocus()
        wait(30)
        verify(ts._hasFocus)
        compare(ts._trigger.border.color, Theme.current.colorFocusBorder)
    }

    // 弹层：$width-tree_list-min-width 230、radius 6、无内边距；
    // 行高 28（4+20+4）、列表上下各 8
    function test_popupMetrics() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        compare(ts._popup.padding, 0)
        compare(ts._popup.radius, 6)
        compare(ts.rowCount(), 2)
        compare(ts.rowAt(0).height, 28)
        compare(ts._popup.implicitHeight, 2 * 28 + 16)
        compare(ts._popup.width, 300, "dropdownMatchSelectWidth 默认 true")
        compare(opened("TreeSelect { width: 120 }", testCase.worldTree)._popup.width, 230)
        compare(opened("TreeSelect { width: 120; dropdownMatchSelectWidth: false }",
            testCase.worldTree)._popup.width, 230)
    }

    // 行内缩进：padding-left 8 + 每级 20；箭头 12 宽 + 右 margin 8；复选框 16 + 右 margin 8
    function test_rowIndent() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0", "0-0"])
        // Asia, China, Beijing, Shanghai, Chengdu, Japan, North America
        compare(ts.rowCount(), 7)
        compare(ts.rowAt(0)._caret.x, 8)
        compare(ts.rowAt(0)._label.x, 8 + 12 + 8, "单选：箭头槽之后就是正文")
        compare(ts.visibleOptions[rowIndexOf(ts, "0-0-0")].level, 2)
        const deep = ts.rowAt(rowIndexOf(ts, "0-0-0"))
        compare(deep._caret.x, 8 + 2 * 20)
        compare(deep._label.x, 8 + 2 * 20 + 12 + 8)
        const multi = opened("TreeSelect { width: 300; multiple: true }",
            testCase.worldTree, ["0", "0-0"])
        const mRow = multi.rowAt(rowIndexOf(multi, "0-0-0"))
        compare(mRow._check.x, 8 + 2 * 20 + 12 + 8)
        compare(mRow._label.x, 8 + 2 * 20 + 12 + 8 + 16 + 8)
    }

    // 官方触发器箭头不随展开旋转（treeSelect.scss 里 .semi-treeselect-arrow 没有 rotate），
    // 行内的展开箭头才转 90°
    function test_arrowDoesNotRotate() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        compare(ts._arrowBox.rotation, 0)
        ts.toggleExpand("0")
        wait(30)
        compare(ts._arrowBox.rotation, 0, "触发器箭头不转")
        compare(ts.rowAt(0)._caret.rotation, 90)
    }

    // ---------------------------------------------------------------- 数据模型
    // 官方 convertDataToEntities：内部身份是 key，没有 key 用 pos 串顶上；
    // value → key 另建一张表，认不出的值原样当 key 用
    function test_identityKeyAndValueLookup() {
        const ts = make("TreeSelect { }")
        ts.treeData = [{ label: "前端", value: "fe", children: [
            { label: "React", value: "react" }] }]
        compare(ts._m.keys.length, 2)
        compare(ts._m.roots, ["0"], "没给 key 时用 pos 串")
        compare(ts.labelOfKey("0-0"), "React")
        ts.treeData = [{ label: "A", value: "av", key: "ka", children: [
            { label: "B", value: "bv", key: "kb" }] }]
        compare(ts._m.roots, ["ka"])
        compare(ts._m.byKey["ka"].childKeys, ["kb"])
        compare(ts.keyOfValue("bv"), "kb")
        compare(ts.keyOfValue("认不出的"), "认不出的", "findKeysForValues 原样透传")
    }

    function test_keyMaps() {
        const ts = make("TreeSelect { width: 300; keyMaps: ({ key: 'id', label: 'name',"
            + " value: 'code', children: 'subs' }) }")
        ts.treeData = [{ id: "n1", name: "一", code: 1, subs: [
            { id: "n2", name: "二", code: 2 }] }]
        ts.open()
        wait(30)
        compare(ts._m.roots, ["n1"])
        compare(ts._m.byKey["n1"].childKeys, ["n2"])
        compare(ts._m.byKey["n1"].label, "一")
        compare(ts.keyOfValue(2), "n2")
        ts.toggleExpand("n1")
        wait(40)
        compare(ts.rowCount(), 2)
        compare(ts.rowAt(1)._label.text, "二")
    }

    // ---------------------------------------------------------------- 基本用法（单选）
    function test_singleSelectClickRow() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0"])
        hook(ts)
        resetLogs()
        clickRow(ts, "0-0")
        compare(ts._selectedKeys, ["0-0"])
        compare(testCase.changeLog.length, 1)
        compare(testCase.changeLog[0][0], "China")
        compare(testCase.changeLog[0][1], 1, "onChange 第二个入参是节点数组")
        compare(testCase.selectLog, [["0-0", true]])
        compare(findChild(ts, "tsSingleText").text, "China")
        verify(!ts.isOpen, "clickToHide 默认 true，选完就收")
    }

    // 官方每一级都能选，包括有子节点的父级
    function test_parentNodeSelectable() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        clickRow(ts, "0")
        compare(ts._selectedKeys, ["0"])
        compare(findChild(ts, "tsSingleText").text, "Asia")
    }

    // 官方 foundation.ts:692 恒传 selected=true，重复点同一行 onSelect 照发、onChange 不发
    function test_repeatClickEmitsSelectNotChange() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        hook(ts)
        clickRow(ts, "0")
        ts.open()
        wait(30)
        resetLogs()
        clickRow(ts, "0")
        compare(testCase.selectLog.length, 1, "onSelect 仍然回")
        compare(testCase.changeLog.length, 0, "但 onChange 不再发")
        compare(ts._selectedKeys, ["0"])
    }

    function test_clickToHideFalseKeepsOpen() {
        const ts = opened("TreeSelect { width: 300; clickToHide: false }", testCase.worldTree)
        clickRow(ts, "0")
        compare(ts._selectedKeys, ["0"])
        verify(ts.isOpen)
    }

    function test_selectedRowBackground() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        compare(ts.rowAt(0)._bg.color, Qt.color("transparent"), "没选中就不铺底色")
        clickRow(ts, "0")
        ts.open()
        wait(40)
        compare(ts.rowAt(0)._bg.color, Theme.current.colorPrimaryLightDefault,
            "$color-tree_option-bg-active")
    }

    function test_visibleChangeSignal() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        hook(ts)
        resetLogs()
        ts.close()
        wait(30)
        ts.open()
        wait(30)
        compare(testCase.visibleLog, [false, true])
    }

    // 弹层开着时，点到「触发器与弹层之外」要收起。官方那套 clickOutside 认 reference
    // （触发器算自己人），Controls Popup 的 CloseOnPressOutside 不认 —— TreeSelect 换成了
    // 自己盯落点的那层壳（outsideShell）。把壳子的 enabled 打死，这条立刻红。
    function test_clickOutsidePopupClosesIt() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        verify(ts.isOpen)
        mouseClick(testCase, testCase.width - 6, testCase.height - 6)
        wait(60)
        verify(!ts.isOpen, "点外面收起")
    }

    // ---------------------------------------------------------------- 多选
    function test_multipleCascadeDown() {
        const ts = opened("TreeSelect { width: 300; multiple: true }",
            testCase.worldTree, ["0", "0-0"])
        clickCheck(ts, "0-0-0")
        compare(ts._checkedKeys, ["0-0-0"], "只选一个子节点时父不该被带上")
        clickCheck(ts, "0")
        wait(40)
        ts.toggleExpand("0-1")
        wait(40)
        compare(sorted(ts._checkedKeys),
            ["0", "0-0", "0-0-0", "0-0-1", "0-0-2", "0-1", "0-1-0"],
            "勾父级要级联到全部子孙")
    }

    // 官方 normalizeKeyList：子全选完自动折成父，触发器只显示父（index.tsx:1123-1128）
    function test_multipleAutoMergeShowsParent() {
        const ts = opened("TreeSelect { width: 300; multiple: true }",
            testCase.worldTree, ["0", "0-0", "0-1"])
        const leaves = ["0-0-0", "0-0-1", "0-0-2", "0-1-0"]
        for (let i = 0; i < leaves.length; ++i) {
            clickCheck(ts, leaves[i])
            wait(20)
        }
        compare(sorted(ts._checkedKeys),
            ["0", "0-0", "0-0-0", "0-0-1", "0-0-2", "0-1", "0-1-0"])
        compare(ts.displayKeys, ["0"], "China 与 Japan 都齐了 → 一路折到 Asia")
        compare(ts.tagLabels, ["Asia"])
    }

    function test_autoMergeValueFalseShowsEveryKey() {
        const ts = opened("TreeSelect { width: 300; multiple: true; autoMergeValue: false }",
            testCase.worldTree, ["0", "0-0"])
        const leaves = ["0-0-0", "0-0-1", "0-0-2"]
        for (let i = 0; i < leaves.length; ++i) {
            clickCheck(ts, leaves[i])
            wait(20)
        }
        compare(sorted(ts.displayKeys), ["0-0", "0-0-0", "0-0-1", "0-0-2"],
            "关掉合并就原样列出来")
    }

    // 官方 leafOnly 只影响「投影」：选区照旧级联，但入参与标签只留叶子
    function test_leafOnlyProjection() {
        const ts = opened("TreeSelect { width: 300; multiple: true; leafOnly: true }",
            testCase.worldTree, ["0", "0-0"])
        hook(ts)
        resetLogs()
        clickCheck(ts, "0")
        verify(ts._checkedKeys.indexOf("0") >= 0, "选区里父还在")
        compare(sorted(ts.displayKeys), ["0-0-0", "0-0-1", "0-0-2", "0-1-0"],
            "标签只剩叶子")
        compare(testCase.changeLog.length, 1)
        compare(sorted(testCase.changeLog[0][0]), ["Beijing", "Chengdu", "Osaka", "Shanghai"],
            "onChange 也只回叶子")
    }

    // 官方 unRelated：只记 realCheckedKeys，不级联、不半选
    function test_unRelatedNoCascade() {
        const ts = opened("TreeSelect { width: 300; multiple: true; checkRelation: 'unRelated' }",
            testCase.worldTree, ["0", "0-0", "0-1", "1"])
        clickCheck(ts, "0")
        compare(ts._checkedKeys, ["0"], "勾父只记父，不带动子级")
        compare(Object.keys(ts._halfSet).length, 0, "unRelated 没有半选")
        verify(!readyRow(ts, "0-0-0")._check.checked, "子级不会被连着勾上")
        clickCheck(ts, "1-0")
        compare(sorted(ts._checkedKeys), ["0", "1-0"])
        compare(sorted(ts.displayKeys), ["0", "1-0"])
    }

    function test_unRelatedControlledUsesRealList() {
        const ts = make("TreeSelect { width: 300; multiple: true; checkRelation: 'unRelated' }")
        ts.treeData = testCase.worldTree
        ts.value = ["China"]
        wait(30)
        compare(ts._checkedKeys, ["0-0"])
        ts.value = ["China", "Osaka"]
        wait(30)
        compare(sorted(ts._checkedKeys), ["0-0", "0-1-0"])
    }

    function test_halfCheckedIsIndeterminate() {
        const ts = opened("TreeSelect { width: 300; multiple: true }",
            testCase.worldTree, ["0", "0-0", "0-1"])
        clickCheck(ts, "0-0-0")
        verify(ts._halfSet["0-0"] === true, "China 半选")
        verify(ts._halfSet["0"] === true, "Asia 半选")
        verify(ts._halfSet["0-0-0"] === undefined, "叶子自己不算半选")
        verify(readyRow(ts, "0")._check.indeterminate, "行上的复选框要走三态")
        verify(!readyRow(ts, "0-0-1")._check.indeterminate)
        verify(readyRow(ts, "0-0-0")._check.checked)
    }

    // ---------------------------------------------------------------- 标签
    function test_maxTagCountAndRest() {
        const ts = make("TreeSelect { width: 300; multiple: true; maxTagCount: 2;\
            defaultValue: ['Beijing', 'Chengdu', 'Canada'] }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        compare(sorted(ts.tagLabels), ["Beijing", "Canada", "Chengdu"])
        compare(ts.shownTags.length, 2)
        compare(ts.restCount, 1)
        compare(ts.restLabels.length, 1)
        const rest = findChild(ts, "tsRestTag")
        verify(rest.visible)
        compare(rest.text, "+1")
        compare(ts.tagAt(0).item.text, ts.shownTags[0])
        compare(ts.tagAt(1).item.text, ts.shownTags[1])
    }

    function test_restTagsPopoverOnHover() {
        const ts = make("TreeSelect { width: 300; multiple: true; maxTagCount: 2;\
            showRestTagsPopover: true; defaultValue: ['Beijing', 'Chengdu', 'Canada'] }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        const rest = findChild(ts, "tsRestTag")
        const at = rest.mapToItem(ts, rest.width / 2, rest.height / 2)
        mouseMove(ts, at.x, at.y)
        wait(60)
        verify(ts._restPop.isOpen, "hover +N 要开浮层")
        compare(ts.restTagAt(0).text, ts.restLabels[0])
        compare(ts.restTagAt(0).size, "large", "Tag 换成官方字符串档位之后，+N 也跟着是 \"large\"")
    }

    function test_tagCloseRemovesWholeBranch() {
        const ts = opened("TreeSelect { width: 300; multiple: true }",
            testCase.worldTree, ["0", "0-0"])
        hook(ts)
        const leaves = ["0-0-0", "0-0-1", "0-0-2"]
        for (let i = 0; i < leaves.length; ++i) {
            clickCheck(ts, leaves[i])
            wait(20)
        }
        compare(ts.displayKeys, ["0-0"])
        resetLogs()
        const tag = ts.tagAt(0).item
        // Tag 的关闭热区在最右 12+6px（Tag.qml 的 closeArea）
        mouseClick(tag, tag.width - 10, tag.height / 2)
        wait(30)
        compare(ts._checkedKeys.length, 0, "点标签 X 要把整条分支撤掉")
        compare(testCase.changeLog.length, 1)
        compare(testCase.selectLog[0], ["0-0", false])
    }

    // ---------------------------------------------------------------- 可搜索
    function test_searchFiltersAndHighlights() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true }",
            testCase.worldTree)
        ts.searchBy("hai")
        wait(40)
        // 搜索期间展开集换成「命中节点的祖先链」，其它分支收回（官方 filteredExpandedKeys）
        compare(ts.rowCount(), 7)
        const hit = readyRow(ts, "0-0-1")
        verify(hit._highlight.visible, "命中行走 Highlight")
        verify(!hit._label.visible)
        compare(hit._highlight.sourceString, "Shanghai")
        const miss = readyRow(ts, "0-0-0")
        verify(!miss._highlight.visible)
        verify(miss._label.visible)
    }

    function test_searchIsCaseInsensitiveSubstring() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true }",
            testCase.worldTree)
        ts.searchBy("ASI")
        wait(40)
        const hits = ts.visibleOptions.filter(o => o.matched)
        compare(hits.length, 1)
        compare(hits[0].key, "0")
    }

    function test_searchAutoExpandsAncestors() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true }",
            testCase.worldTree)
        hook(ts)
        resetLogs()
        ts.searchBy("osaka")
        wait(40)
        compare(ts.visibleOptions.map(o => o.key), ["0", "0-0", "0-1", "0-1-0", "1"])
        compare(testCase.searchLog.length, 1)
        compare(testCase.searchLog[0][0], "osaka")
        compare(testCase.searchLog[0][1], ["0", "0-1"], "filteredExpandedKeys = 命中的两个祖先")
        compare(testCase.searchLog[0][2], 1, "filteredNodes = 命中的那一个")
    }

    function test_showFilteredOnly() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true; showFilteredOnly: true }",
            testCase.worldTree)
        ts.searchBy("osaka")
        wait(40)
        compare(ts.visibleOptions.map(o => o.key), ["0", "0-1", "0-1-0"])
        ts.searchBy("united")
        wait(40)
        compare(ts.visibleOptions.map(o => o.key), ["1", "1-0"], "命中节点本身留着")
    }

    function test_treeNodeFilterProp() {
        const ts = make("TreeSelect { width: 300; filterTreeNode: true; treeNodeFilterProp: 'code' }")
        ts.treeData = [{ label: "亚洲", value: "a", key: "a", code: "AS" },
            { label: "欧洲", value: "b", key: "b", code: "EU" }]
        ts.open()
        wait(30)
        ts.searchBy("eu")
        wait(40)
        compare(ts.visibleOptions.filter(o => o.matched).map(o => o.key), ["b"])
    }

    function test_customFilterFunction() {
        const ts = make("TreeSelect { width: 300; filterTreeNode: true }")
        ts.treeData = [{ label: "Asia", value: "a", key: "a" },
            { label: "Europe", value: "b", key: "b" }]
        ts.filterTreeNode = function (input, target) {
            return String(target).length === Number(input)
        }
        ts.open()
        wait(30)
        ts.searchBy("4")
        wait(40)
        compare(ts.visibleOptions.filter(o => o.matched).map(o => o.key), ["a"],
            "自定义函数收 (input, 目标字段, 节点)")
    }

    // 官方 handleInputChange：清空搜索时把选中项的祖先永久并进 expandedKeys
    function test_clearSearchKeepsAncestorsOfSelected() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true }",
            testCase.worldTree)
        ts.searchBy("chengdu")
        wait(40)
        clickRow(ts, "0-0-2")
        ts.open()
        wait(30)
        compare(ts._selectedKeys, ["0-0-2"])
        ts.searchBy("")
        wait(40)
        verify(ts.isExpanded("0"), "祖先被永久展开")
        verify(ts.isExpanded("0-0"))
        compare(ts.rowCount(), 7)
    }

    // 真入口：写下拉里那个输入框，而不是直接调 handleInputChange
    function test_typingIntoDropdownInputFilters() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true }",
            testCase.worldTree)
        const input = findChild(ts._popup, "tsDropInput")
        compare(findChild(ts._popup, "tsSearchHost").height, 49,
            "搜索行 = 上下 8 + 输入框 32 + 1px 分隔")
        input.text = "japan"
        wait(40)
        compare(ts._input, "japan")
        compare(ts.visibleOptions.filter(o => o.matched).map(o => o.key), ["0-1"])
        compare(ts.rowCount(), 4)
    }

    function test_emptyContentAndNoData() {
        const ts = opened("TreeSelect { width: 300 }", [])
        verify(ts.noData, "空树没有行")
        const empty = findChild(ts._popup, "tsEmpty")
        verify(empty !== null, "空态节点要存在")
        verify(empty.visible, "默认画空态")
        compare(empty.text, "暂无数据")
        compare(ts._popup.implicitHeight, 28 + 16)
        const custom = opened("TreeSelect { width: 300; emptyContent: 'Nothing here' }", [])
        compare(findChild(custom._popup, "tsEmpty").text, "Nothing here")
        const none = opened("TreeSelect { width: 300; emptyContent: '' }", [])
        verify(!findChild(none._popup, "tsEmpty").visible, "emptyContent 给空串就不画")
    }

    // ---------------------------------------------------------------- 远程搜索
    function test_remoteSkipsLocalFilter() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true; remote: true }",
            testCase.worldTree)
        hook(ts)
        resetLogs()
        ts.searchBy("asia")
        wait(40)
        compare(testCase.searchLog.length, 1)
        compare(testCase.searchLog[0][1], [], "remote 的 filteredExpandedKeys 恒空")
        compare(testCase.searchLog[0][2], 0, "remote 的 filteredNodes 恒空")
        compare(ts.rowCount(), 2, "不做本地过滤，行还是原样")
        verify(!ts.inSearch)
        ts.treeData = [{ label: "remote-1", value: "r1", key: "r1" }]
        wait(40)
        compare(ts.rowCount(), 1, "用户自己换 treeData 就生效")
    }

    // ---------------------------------------------------------------- 搜索框位置
    function test_triggerSearchSingleOverlay() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true;\
            searchPosition: 'trigger' }", testCase.worldTree)
        verify(ts.triggerSearch)
        compare(findChild(ts._popup, "tsSearchHost").height, 0, "下拉里不再放搜索行")
        const loader = ts._singleSearch
        verify(loader.item !== null)
        const overlay = findChild(loader.item, "tsSingleSearchOverlay")
        verify(overlay.visible, "没输入时盖着 placeholder")
        compare(overlay.text, "请选择")
        const field = findChild(loader.item, "tsSingleSearchInput")
        field.text = "canada"
        wait(40)
        verify(!overlay.visible, "一旦有输入，overlay 让位")
        compare(ts._input, "canada")
        ts.open()
        wait(40)
        compare(ts.visibleOptions.filter(o => o.matched).map(o => o.key), ["1-1"])
    }

    function test_triggerSearchMultipleUsesTagInput() {
        const ts = opened("TreeSelect { width: 300; multiple: true; filterTreeNode: true;\
            searchPosition: 'trigger' }", testCase.worldTree, ["0", "0-0"])
        verify(ts._tagField.visible)
        verify(ts._tagField.borderless, "官方把内层 TagInput 的框抹平")
        verify(!findChild(ts, "tsTagRow").visible, "标签交给 TagInput 画")
        clickCheck(ts, "0-0-0")
        compare(ts._checkedKeys, ["0-0-0"])
        const inner = findChild(ts._tagField, "tsKeyTag")
        verify(inner !== null, "TagInput 里要走自定义标签节点")
        compare(inner.text, "Beijing", "标签文字按 key 现算，不是 key 本身")
    }

    // 官方 `.semi-treeselect-selection .semi-tag { margin: 1px 2px }`
    // （treeSelect.scss:155-157 + variables.scss:72）跟
    // `.semi-treeselect-multiple-tagInput-notEmpty .semi-tagInput { margin-left: -4 }`
    // （:246-257 + variables.scss:70）合起来：第一个标签的左边缘在触发器内 6
    // （4 内边距 − 4 + wrapper 4 + 标签自己 2），相邻标签之间 2+2=4，
    // +N 紧跟最后一个标签 2（-n 没有左外边距），输入区再让 -n 的 margin-right 4。
    function test_triggerSearchTagRowLayout() {
        const ts = make("TreeSelect { width: 300; multiple: true; autoMergeValue: false;\
            filterTreeNode: true; searchPosition: 'trigger'; maxTagCount: 2;\
            defaultValue: ['Beijing', 'Chengdu', 'Canada'] }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(80)
        const tf = ts._tagField
        const flow = findChild(tf, "flowArea")
        const h0 = findChild(tf, "tagHost0")
        const h1 = findChild(tf, "tagHost1")
        const rest = findChild(tf, "restHost")
        const field = findChild(tf, "fieldHost")
        compare(rest.visible, true, "3 个值折成 2 个标签 + +1")
        // 量渲染出来的标签，不量排布槽位（槽步里含标签自己那 2+2 外边距）
        const t0 = findChild(h0, "tsKeyTag")
        const t1 = findChild(h1, "tsKeyTag")
        const q0 = t0.mapToItem(ts, 0, 0)
        const q1 = t1.mapToItem(ts, 0, 0)
        const pr = flow.mapToItem(ts, rest.x, rest.y)
        const pf = flow.mapToItem(ts, field.x, field.y)
        verify(pr.x > q1.x, "+N 必须排在标签后面，不能留在行首盖住第一个标签")
        compare(q0.x, 6, "第一个标签的左边缘")
        compare(q1.x - q0.x - t0.width, 4, "相邻标签之间 2+2")
        compare(pr.x - q1.x - t1.width, 2, "+N 只隔最后一个标签的右外边距 2")
        compare(pf.x - pr.x - rest.width, 4, "输入区让 -n 的 margin-right 4")
        // 纵向：两个标签都得居中在同一行里，不能有一个掉到行下面（Loader 量高度比
        // 触发 relayout 晚一轮时，读绑定属性会把第二项按 (行高 − 0)/2 往下推）
        compare(q0.y, 4, "第一个标签垂直居中")
        compare(q1.y, q0.y, "第二个标签跟第一个同一行")
        verify(q1.y + t1.height <= ts.height, "标签不能画到触发器外面")
        compare(pr.y + rest.height / 2, q0.y + t0.height / 2, "+N 也居中在同一行")
    }

    // 官方 empty 那档的 margin-left 是 +4：没选东西时光标要跟单选回显文字同一条线
    function test_triggerSearchEmptyFieldAlignsWithSingleText() {
        const multi = make("TreeSelect { width: 300; multiple: true; filterTreeNode: true;\
            searchPosition: 'trigger'; placeholder: '多选' }")
        multi.treeData = testCase.worldTree
        const single = make("TreeSelect { width: 300; defaultValue: ['Beijing'] }")
        single.treeData = testCase.worldTree
        waitForRendering(multi)
        waitForRendering(single)
        wait(60)
        const flow = findChild(multi._tagField, "flowArea")
        const field = findChild(multi._tagField, "fieldHost")
        const text = findChild(single, "tsSingleText")
        compare(flow.mapToItem(multi, field.x, field.y).x, 12, "空值时输入区在 12")
        compare(text.mapToItem(single, text.x, 0).x, 12, "单选回显文字也在 12")
    }

    // 搜索框在下拉时官方走 TagGroup（group.tsx:41 的 +N 也是 .semi-tag），
    // 所以整行同样带 2 的左外边距、相邻 2+2=4
    function test_multipleTagRowLayout() {
        const ts = make("TreeSelect { width: 300; multiple: true; autoMergeValue: false;\
            maxTagCount: 2; defaultValue: ['Beijing', 'Chengdu', 'Canada'] }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(60)
        const row = findChild(ts, "tsTagRow")
        verify(row.visible)
        compare(row.x, 2, "整行让出标签自己的 2 左外边距")
        compare(row.spacing, 4, "相邻两项 2+2")
        const first = findChild(ts, "tsTag0")
        const rest = findChild(ts, "tsRestTag")
        compare(rest.visible, true)
        verify(rest.x > first.x, "+N 排在标签之后")
    }

    // 搜索框在触发器时，点它也要开下拉（官方靠 DOM 的 click 冒泡到 .semi-treeselect
    // 的 onClick）。QML 里父级 TapHandler 永远抢不过子 TextInput（实测 taps=0），
    // 所以触发器上垫了一层「按下即放行」的 MouseArea —— 把它的 enabled 打死这条立刻红。
    function test_triggerSearchSingleClickOpens() {
        const ts = make("TreeSelect { width: 300; filterTreeNode: true;\
            searchPosition: 'trigger'; placeholder: '单选' }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(40)
        const field = findChild(ts._singleSearch.item, "tsSingleSearchInput")
        verify(!ts.isOpen)
        mouseClick(field, field.width / 2, field.height / 2)
        wait(60)
        verify(ts.isOpen, "点触发器里的输入框要开下拉")
        verify(field.activeFocus, "同一次点击还要把光标落进输入框")
        verify(ts._hasFocus, "焦点在里层输入框也算触发器聚焦")
        compare(ts._trigger.border.color, Theme.current.colorFocusBorder)
        // 那圈 1px 只能是触发器自己的：官方把 .semi-input-wrapper 的 border 覆盖成
        // none（连 -focus 也是 none，treeSelect.scss:183-205），换成带框的 Input 就红
        verify(field.border === undefined, "内层输入框不能自己再画一圈框")
        field.text = "abcd"
        wait(30)
        mouseClick(field, 4, field.height / 2)
        wait(40)
        verify(field.cursorPosition <= 1,
            "按下放行之后点击要按位置放光标（实测 " + field.cursorPosition + "）")
    }

    function test_triggerSearchMultipleClickOpens() {
        const ts = make("TreeSelect { width: 300; multiple: true; filterTreeNode: true;\
            searchPosition: 'trigger'; placeholder: '多选' }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(40)
        verify(!ts.isOpen)
        mouseClick(ts._tagField, ts._tagField.width / 2, ts._tagField.height / 2)
        wait(60)
        verify(ts.isOpen, "多选点 TagInput 那一圈也要开下拉")
        verify(ts._hasFocus)
        compare(ts._trigger.border.color, Theme.current.colorFocusBorder)
    }

    // 官方 handleClick：开着、且「搜索框在触发器 + 已经有词」时点触发器什么都不做
    function test_triggerSearchClickWithTextKeepsOpen() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true;\
            searchPosition: 'trigger' }", testCase.worldTree)
        ts.handleInputChange("canada")
        wait(40)
        verify(ts.isOpen)
        mouseClick(ts._trigger, 150, 16)
        wait(60)
        verify(ts.isOpen, "有搜索词时点触发器不收起")
        compare(ts._input, "canada", "也不清搜索词")
    }

    // 官方 clickTriggerToHide 默认 true（index.tsx:322）：点触发器本身会收起，
    // 关掉之后不收起。注意这跟 clickToHide 是两条（那条管选完节点收不收）。
    function test_clickTriggerToHideControlsTriggerClick() {
        const off = opened("TreeSelect { width: 300; clickTriggerToHide: false }",
            testCase.worldTree)
        verify(off.isOpen)
        mouseClick(off._trigger, 20, 16)
        wait(40)
        verify(off.isOpen, "clickTriggerToHide: false 点触发器不收起")
        const on = opened("TreeSelect { width: 300 }", testCase.worldTree)
        verify(on.clickTriggerToHide, "官方默认 true")
        mouseClick(on._trigger, 20, 16)
        wait(40)
        verify(!on.isOpen, "默认点一下就收起")
    }

    // 官方 foundation.ts:753-755：搜索框在触发器时，勾选一次就把输入清掉
    function test_triggerSearchClearsInputAfterSelect() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true;\
            searchPosition: 'trigger' }", testCase.worldTree)
        ts.handleInputChange("canada")
        wait(30)
        compare(ts._input, "canada")
        ts.open()
        wait(40)
        clickRow(ts, "1-1")
        compare(ts._input, "", "选完清空搜索词")
        compare(ts._selectedKeys, ["1-1"])
    }

    // 同一个 if 的另一半：官方这条清词只在 handleMultipleSelect 末尾（foundation.ts:741-744），
    // 而且条件带 searchPosition === 'trigger'。搜索框在下拉里时勾完**不**清。
    // 守卫被打松成「无条件清」时，只有多选 + 下拉搜索这条能报红。
    function test_dropdownSearchKeepsInputAfterSelect() {
        const ts = opened("TreeSelect { width: 300; multiple: true; filterTreeNode: true }",
            testCase.worldTree)
        const input = findChild(ts._popup, "tsDropInput")
        input.text = "japan"
        wait(40)
        compare(ts._input, "japan")
        clickCheck(ts, "0-1")
        verify(ts.isOpen, "多选勾完不关弹层")
        compare(sorted(ts._checkedKeys), ["0-1", "0-1-0"], "勾日本把它的唯一子节点一起级联上")
        compare(ts._input, "japan", "搜索框不在触发器里，勾完保留搜索词")
        compare(input.text, "japan")
    }

    // 官方 showSearchClear 只管下拉里那个输入框（index.tsx:1322-1324 的
    // inputDropdownProps.showClear），触发器那个没有这个 prop
    function test_showSearchClearOnlyWiresDropdownInput() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true }",
            testCase.worldTree)
        compare(findChild(ts._popup, "tsDropInput").showClear, true, "默认 true")
        ts.close()
        wait(30)
        const off = opened("TreeSelect { width: 300; filterTreeNode: true;\
            showSearchClear: false }", testCase.worldTree)
        compare(findChild(off._popup, "tsDropInput").showClear, false)
    }

    function test_triggerTagWrapGrowsHeight() {
        // 四个不会凑成父级满选的叶子，标签才不会被合并掉
        const flat = make("TreeSelect { width: 260; multiple: true; filterTreeNode: true;\
            searchPosition: 'trigger';\
            value: ['Beijing', 'Shanghai', 'Osaka', 'United States'] }")
        flat.treeData = testCase.worldTree
        waitForRendering(flat)
        wait(40)
        compare(flat.displayKeys.length, 4)
        verify(!flat.wrapped)
        compare(flat.implicitHeight, 32, "不换行就固定 32")

        const wrapped = make("TreeSelect { width: 260; multiple: true; filterTreeNode: true;\
            searchPosition: 'trigger'; triggerTagWrap: true;\
            value: ['Beijing', 'Shanghai', 'Osaka', 'United States'] }")
        wrapped.treeData = testCase.worldTree
        waitForRendering(wrapped)
        wait(60)
        verify(wrapped.wrapped)
        tryVerify(function () { return wrapped._tagField.contentHeight > 0; })
        verify(wrapped.implicitHeight > 32,
            "换行后要按行数撑高，实测 " + wrapped.implicitHeight)
    }

    // ---------------------------------------------------------------- 展开
    function test_defaultExpandedKeys() {
        const ts = make("TreeSelect { width: 300; defaultExpandedKeys: ['0', '0-0'] }")
        ts.treeData = testCase.worldTree
        ts.open()
        wait(40)
        compare(ts.rowCount(), 7)
        compare(ts.visibleOptions.map(o => o.key),
            ["0", "0-0", "0-0-0", "0-0-1", "0-0-2", "0-1", "1"])
    }

    // 没给 defaultExpandedKeys 时，官方按选中项的祖先展开
    function test_seedsExpansionFromSelection() {
        const ts = make("TreeSelect { width: 300; defaultValue: 'Osaka' }")
        ts.treeData = testCase.worldTree
        ts.open()
        wait(40)
        compare(ts.visibleOptions.map(o => o.key), ["0", "0-0", "0-1", "0-1-0", "1"])
    }

    // expandAll 在 treeData 换掉后仍然生效，defaultExpandAll 只在初始化生效
    function test_expandAllSurvivesDataChange() {
        const a = make("TreeSelect { width: 300; expandAll: true }")
        a.treeData = testCase.worldTree
        a.open()
        wait(40)
        compare(a.rowCount(), 10)
        a.treeData = [{ label: "New", value: "n", key: "n", children: [
            { label: "Kid", value: "k", key: "k" }] }]
        wait(40)
        compare(a.rowCount(), 2, "expandAll 换数据后仍然全展开")

        const b = make("TreeSelect { width: 300; defaultExpandAll: true }")
        b.treeData = testCase.worldTree
        b.open()
        wait(40)
        compare(b.rowCount(), 10)
        b.treeData = [{ label: "New", value: "n", key: "n", children: [
            { label: "Kid", value: "k", key: "k" }] }]
        wait(40)
        compare(b.rowCount(), 1, "defaultExpandAll 只认初始化那一次")
    }

    function test_toggleExpandEmitsAndLoadsChildren() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        hook(ts)
        resetLogs()
        clickCaret(ts, "0")
        compare(testCase.expandLog.length, 1)
        compare(testCase.expandLog[0], [1, true])
        compare(ts.rowCount(), 4)
        clickCaret(ts, "0")
        compare(testCase.expandLog[1], [0, false])
        settle(ts)
        compare(ts.rowCount(), 2, "收起的那几行等动画跑完才真的没了")
    }

    // 没有子节点又不给 loadData 时，点箭头没反应（官方 foundation.ts:832）
    function test_leafCaretDoesNothing() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0", "0-0"])
        compare(ts.rowCount(), 7)
        verify(!readyRow(ts, "0-0-0")._caret.visible, "真叶子行不画箭头")
        ts.toggleExpand("0-0-0")
        wait(30)
        compare(ts.rowCount(), 7, "叶子没有可展开的子层")
    }

    // ============================================================ 展开/收起动画
    // 官方：TreeSelect 的 motion / motionExpand（缺省都 true），动画区间 = foundation
    // 用 getMotionKeys 算出的那几条（treeUtil.ts:492-507），NodeList 把它们折成一串
    // 交给 NodeCollapsible（nodeList.tsx:71-81，duration 200），收起那一手的内容取自
    // cachedFlattenNodes（改之前那份列表）。

    function test_expandWrapsShownRowsInGroup() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        compare(ts.rowCount(), 2, "起手前只有两个根")
        ts.toggleExpand("0")
        compare(ts.motionTypeView, "show")
        compare(Object.keys(ts.motionMapView).sort(), ["0-0", "0-1"],
            "getMotionKeys 给这一层新出现的键")
        verify(ts._motionRunning, "动画在跑")
        compare(ts.entryCount, 3, "亚洲 + 一个动画组 + 北美洲")
        compare(ts.rowCount(), 4, "逻辑行是 4 条")
        verify(ts.rowAt(2) !== null, "组外那行也取到")
        settle(ts)
        compare(ts.entryCount, 4, "动画收完就是普通四行")
    }

    // 「有没有动画」的正面证据分三层，全都不依赖墙钟采样（机器压满时那 200ms
    // 会被一帧推过去，采不到中间态 —— 那是渲染循环的计时问题，见坑 52）：
    //   ① 建立那一拍的**渲染值**（顺带钉住 motionBox 的 height / opacity 两条绑定
    //      吃的就是动画属性）；② 动画本体的接线（property / from / to / duration）；
    //   ③ 播完之后区间被收干净（onStopped → endMotion，由 settle 钉）。
    function test_groupBoxWiresHeightAndOpacityAnimation() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        ts.toggleExpand("0")
        const box = ts.entryAt(1)
        verify(box !== null, "第二格是动画组")
        verify(box.isGroup, "第二格确实是组")
        compare(box.boxFull, 2 * ts.listRowHeight, "满高就是组里那两行")
        compare(box.boxHeight, 0, "展开那一手从 0 高起步")
        compare(box.boxOpacity, 0, "也从全透明起步（opacity 绑的是动画属性）")
        wait(5)                      // 让 0 间隔 Timer 跑一次 start()
        compare(box.anim.property, "animHeight", "高度动画写的是 animHeight")
        compare(box.fade.property, "animOpacity")
        compare(box.anim.duration, ts.motionDuration)
        compare(box.fade.duration, ts.motionDuration)
        compare(box.anim.from, 0)
        compare(box.anim.to, box.boxFull, "终点是那一组的完整高度")
        compare(box.fade.from, 0)
        compare(box.fade.to, 1)
        settle(ts)
        compare(ts.entryCount, 4, "播完折回普通四行")
    }

    function test_collapseKeepsRowsInsideGroup() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0"])
        compare(ts.rowCount(), 4)
        ts.toggleExpand("0")
        compare(ts.motionTypeView, "hide")
        compare(ts.visibleOptions.length, 2, "flatten 已经没有它们了")
        compare(ts.entryCount, 3, "动画组还带着要消失的行")
        compare(ts.rowCount(), 4, "渲染中的还是 4 条")
        compare(ts.rowAt(1).rec.key, "0-0", "组里第一条还是中国")
        compare(ts.rowAt(2).rec.key, "0-1", "组里第二条还是日本")
        compare(ts.rowAt(3).rec.key, "1", "北美洲被推到组后面")
        compare(ts.rowAt(0).rec.expanded, false,
            "父行的箭头当场就翻了（内容跟着当前状态，官方是 renderTreeNode 现场取 props）")
        const box = ts.entryAt(1)
        compare(box.boxHeight, box.boxFull, "收起那一手从满高起步（不许先闪一帧 0）")
        compare(box.boxOpacity, 1, "也从满不透明起步")
        wait(5)
        compare(box.anim.from, box.boxFull, "hide 那一手是从满高往 0 走")
        compare(box.anim.to, 0)
        compare(box.fade.to, 0)
        settle(ts)
        compare(ts.rowCount(), 2)
        compare(ts.entryCount, 2)
    }

    // 非受控展开过之后改成受控：基线要跟「实际展开成什么样」对上
    //（官方是 prevState.expandedKeys，端口是派生视图 ⇒ 每次改动收尾记一份快照）
    function test_controlledChangeAfterUncontrolledExpandAnimates() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        ts.toggleExpand("0")
        settle(ts)
        compare(ts.rowCount(), 4, "非受控先展开亚洲")
        ts.expandedKeys = ["0", "1"]
        compare(ts.motionTypeView, "show", "相对上一拍的展开集只多了一个键 ⇒ 该有动画")
        compare(Object.keys(ts.motionMapView).sort(), ["1-0", "1-1"],
            "动画区间是北美洲那一支的孩子")
        compare(ts.rowCount(), 6)
        settle(ts)
    }

    // 下拉整块跟着动画长：官方弹层没有 max-height，列表高 = **渲染出来的**内容高。
    // 收起那一手尤其能证：可见列表当场只剩两行，块高却还得是四行的量（那一组在慢慢收）。
    function test_popupHeightFollowsAnimatedGroup() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0"])
        settle(ts)          // opened 里那一手展开动画先播完，才谈得上「四行的块高」
        const fourRows = 4 * ts.listRowHeight + ts.listPadding
        // 动画那一格是**延后删除**的：刚收完时它可能还挂在 Column 上，块高差最后一帧
        tryVerify(function () { return ts._popup.listBlockHeight === fourRows; }, 1000,
            "四行展开的块高得先量准")
        const wide = ts._popup.listBlockHeight
        ts.toggleExpand("0")
        compare(ts.visibleOptions.length, 2, "flatten 当场就剩两行")
        compare(ts._popup.listBlockHeight, wide, "块高跟着那一组走，不是一跳就到 72")
        settle(ts)
        // 代理是延后删除的：settle 刚返回时那一格可能还挂在 Column 上，
        // 先轮询到块高真的落到两行那一档
        tryVerify(function () {
            return ts._popup.listBlockHeight === wide - 2 * ts.listRowHeight;
        }, 1000, "收完就是两行")
    }

    function test_motionDurationIsTwoHundred() {
        compare(make("TreeSelect { }").motionDuration, 200, "nodeList.tsx:74 duration={200}")
    }

    // motionExpand=false：官方 _isAnimated() 就是这条（treeSelect/foundation.ts:253-255），
    // 动画键压根不算，列表直接铺好。
    function test_motionExpandFalseHasNoGroup() {
        const ts = opened("TreeSelect { width: 300; motionExpand: false }",
            testCase.worldTree)
        ts.toggleExpand("0")
        compare(Object.keys(ts.motionMapView).length, 0, "不算动画键")
        verify(!ts._motionRunning, "不起手")
        compare(ts.entryCount, 4, "关掉动画就直接铺好")
        compare(ts.rowCount(), 4)
    }

    // motion=false 只管「外部换 expandedKeys」那一支 ⇒ 点箭头照旧动（口径不一致是上游的，照抄）
    function test_motionFalseStillAnimatesClick() {
        const ts = opened("TreeSelect { width: 300; motion: false }", testCase.worldTree)
        ts.toggleExpand("0")
        compare(ts.entryCount, 3, "点箭头那一手不看 motion")
        compare(ts.rowCount(), 4)
        settle(ts)
    }

    function test_controlledExpandAnimatesWhenMotionOn() {
        const ts = make("TreeSelect { width: 300; expandedKeys: [] }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        ts.open()
        wait(30)
        compare(ts.rowCount(), 2)
        ts.expandedKeys = ["0"]
        compare(ts.motionTypeView, "show")
        compare(Object.keys(ts.motionMapView).sort(),
            ["0-0", "0-0-0", "0-0-1", "0-0-2", "0-1", "0-1-0"],
            "calcMotionKeys 走 findDescendantKeys：子孙全算进来，不管展开没展开")
        compare(ts.entryCount, 3, "列表里只会出现中国、日本那两条 ⇒ 一组两行")
        compare(ts.rowCount(), 4)
        settle(ts)
        compare(ts.entryCount, 4)
    }

    function test_controlledExpandSkippedWhenMotionFalse() {
        const ts = make("TreeSelect { width: 300; motion: false; expandedKeys: [] }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        ts.open()
        wait(30)
        ts.expandedKeys = ["0"]
        compare(Object.keys(ts.motionMapView).length, 0, "gDSFP 那一支看 motion")
        compare(ts.entryCount, 4, "没有组")
        compare(ts.rowCount(), 4)
    }

    // calcMotionKeys 要求两次展开集只差一个键（treeUtil.ts:642），一次换两个就没有动画
    function test_controlledJumpOfTwoKeysHasNoMotion() {
        const ts = make("TreeSelect { width: 300; expandedKeys: [] }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        ts.open()
        wait(30)
        ts.expandedKeys = ["0", "1"]
        compare(Object.keys(ts.motionMapView).length, 0, "差两个键：官方不给动画键")
        verify(!ts._motionRunning)
        compare(ts.rowCount(), 6, "两个根的孩子都直接铺好，没有中间态")
    }

    // 受控写回的键集在 motionExpand=false 时照样存着（官方 gDSFP 只看 motion），
    // 但 NodeList 那一层不显示 ⇒ 没有组；close() 也不清（官方 gate 在 motionExpand）
    function test_controlledKeysSurviveWhenExpandOffAndCloseKeepsThem() {
        const ts = make("TreeSelect { width: 300; motionExpand: false; expandedKeys: [] }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        ts.open()
        wait(30)
        ts.expandedKeys = ["0"]
        compare(Object.keys(ts.motionMapView).sort(),
            ["0-0", "0-0-0", "0-0-1", "0-0-2", "0-1", "0-1-0"],
            "键还是算出来存了（gDSFP 那一支不看 motionExpand）")
        verify(!ts._motionRunning, "显示闸关着就不许起手（翻回来会挂出一组没人收的动画）")
        compare(ts.entryCount, 4, "但显示那一层的闸是 motionExpand ⇒ 没有组")
        ts.close()
        wait(30)
        compare(Object.keys(ts.motionMapView).length, 6,
            "官方 close() 只在 motionExpand 为真时清空动画键")
    }

    function test_closeClearsMotionKeys() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        ts.toggleExpand("0")
        verify(Object.keys(ts.motionMapView).length > 0, "先确认动画确实挂着")
        ts.close()
        wait(30)
        compare(Object.keys(ts.motionMapView).length, 0, "官方 close():496-501 清空动画键")
    }

    // 官方 gDSFP:417-426：treeData 的 key 集合变了就把动画关掉、motionType 置空
    function test_dataKeySetChangeKillsMotion() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        ts.toggleExpand("0")
        verify(Object.keys(ts.motionMapView).length > 0, "先确认动画在跑")
        ts.treeData = [{ label: "新根", value: "z", key: "z" }]
        compare(Object.keys(ts.motionMapView).length, 0, "数据变化时官方把动画关掉")
        compare(ts.motionTypeView, "", "motionType 被置空")
    }

    // 换搜索词那一手官方 updateState 里明确写 motionKeys: new Set([])（foundation.ts:668）
    function test_searchChangeClearsMotionKeys() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        ts.toggleExpand("0")
        verify(Object.keys(ts.motionMapView).length > 0)
        ts.handleInputChange("China")
        compare(Object.keys(ts.motionMapView).length, 0, "换搜索词不留动画键")
        compare(ts.entryCount, ts.rowCount(), "没有组挂着")
    }

    // 搜索档那一支（handleNodeExpandInSearch）读的是同一条 motionExpand 闸
    function test_motionExpandFalseInSearchHasNoKeys() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true;"
            + " motionExpand: false }", testCase.worldTree, ["0"])
        ts.handleInputChange("China")
        tryVerify(function () { return ts.rowCount() > 2; }, 1000)
        ts.toggleExpand("0")
        compare(Object.keys(ts.motionMapView).length, 0, "搜索档也不算动画键")
        verify(!ts._motionRunning, "也不起手")
        compare(ts.entryCount, ts.rowCount(), "没有组")
    }

    // 显示那一层的闸（index.tsx:1464）当场生效：动画跑到一半关掉，组立刻就没
    function test_displayGateAppliesMidFlight() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        ts.toggleExpand("0")
        verify(ts._motionRunning, "先让动画挂着")
        compare(ts.entryCount, 3, "组正在")
        ts.motionExpand = false
        compare(ts.entryCount, 4, "闸一关，NodeList 那层立刻不折组")
        compare(ts.rowCount(), 4)
    }

    // 数据那一支读的是 motion（index.tsx:417-426）：motion=false 时换数据既不清键
    // 也不置空 motionType —— 与点箭头那一支（读 motionExpand）口径不一致，上游自己的，照抄。
    function test_dataChangeKeepsMotionTypeWhenMotionOff() {
        const ts = opened("TreeSelect { width: 300; motion: false }", testCase.worldTree)
        ts.toggleExpand("0")
        verify(Object.keys(ts.motionMapView).length > 0,
            "点箭头那一手照旧算键（那条闸看的是 motionExpand）")
        ts.treeData = [{ label: "换一棵", value: "z", key: "z",
            children: [{ label: "子", value: "zz", key: "zz" }] }]
        compare(ts.motionTypeView, "show", "motion=false ⇒ 官方那一支根本不进")
    }

    // 受控那一支在搜索态 + showFilteredOnly 时只留「真看得见」的键（index.tsx:524-526）
    function test_controlledMotionKeysFilteredByShownSet() {
        const ts = make("TreeSelect { width: 300; filterTreeNode: true;"
            + " showFilteredOnly: true; expandedKeys: [\"0\"] }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        ts.open()
        wait(30)
        ts.handleInputChange("Chengdu")
        compare(ts.rowCount(), 2, "受控只展开亚洲 ⇒ 搜索态里看得见的是亚洲 + 中国")
        ts.expandedKeys = ["0", "0-0"]
        compare(ts.motionTypeView, "show")
        compare(Object.keys(ts.motionMapView), ["0-0-2"],
            "中国的子孙里只有成都在搜索态看得见 ⇒ 只留它")
        compare(ts.rowCount(), 3, "成都进组也照样是一行")
        settle(ts)
    }

    // 动画组里那几行的内容也是现场按当前状态取的（官方 renderTreeNode 走 getTreeNodeProps，
    // 缓存那份只用来定位区间）
    function test_valueChangeDuringCollapseUsesLiveRecords() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0"])
        ts.toggleExpand("0")
        ts.value = "China"
        compare(ts.rowAt(1).rec.key, "0-0")
        compare(ts.rowAt(1).rec.selected, true,
            "动画期间选区变了，组里那行得跟着亮（不是缓存里那份旧记录）")
        settle(ts)
        compare(ts.rowCount(), 2)
    }

    // getMotionKeys 只往「这一手之后还展开着的子级」递归（treeUtil.ts:492-507），
    // 和 findDescendantKeys 的全集不一样 —— 换成后者这条就红了。
    function test_motionKeysRecurseOnlyIntoExpandedChildren() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0", "0-0"])
        compare(ts.rowCount(), 7, "亚洲 + 中国 + 三个城市 + 日本 + 北美洲")
        ts.toggleExpand("0")
        compare(ts.motionTypeView, "hide")
        compare(Object.keys(ts.motionMapView).sort(),
            ["0-0", "0-0-0", "0-0-1", "0-0-2", "0-1"],
            "中国还展开着 ⇒ 递归进它，日本没展开 ⇒ 只到自己")
        compare(ts.rowCount(), 7, "动画期间这五条都还在组里")
        settle(ts)
        compare(ts.rowCount(), 2, "北美洲那一支没被牵连（不在动画区间）")
    }

    // virtualize 换成 ListView 之后没有 NodeList，动画整段没有（官方 renderNodeList 的另一支）。
    // 注意 motionKeys 照算：官方 foundation 不管渲染走哪一支都往 state 里写，
    // 只是 VirtualList 那一支不消费它。
    function test_virtualizeHasNoMotion() {
        const ts = make("TreeSelect { width: 300; virtualize: ({ itemSize: 28, height: 120 }) }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        ts.open()
        wait(30)
        ts.toggleExpand("0")
        verify(!ts._motionRunning, "虚拟化档不起手")
        compare(Object.keys(ts.motionMapView).sort(), ["0-0", "0-1"],
            "键算出来了，但 VirtualList 那一支不显示动画")
        compare(ts.rowCount(), 0, "普通列表整批不建代理")
        compare(ts.virtualRowCount(), 4, "行都在 ListView 里")
    }

    function test_hoverColorSurvivesDelegateRebuild() {
        // 动画的起手与收尾各有一次 Repeater 重建（模型条目数变了）。行上的 HoverHandler
        // 要等下一个鼠标事件才认得已经在里面的指针，底色就会掉一帧 ⇒ 被点那一行看着在闪。
        // 悬浮判定改成按列表容器记下的指针位置算之后，重建与否都一样。
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0"])
        const row = ts.rowAt(0)
        mouseMove(row, 60, 14)
        wait(60)
        compare(ts.rowAt(0)._bg.color, Theme.current.colorFill0, "起手：这一行是 hover 档")
        ts.toggleExpand("0")
        compare(ts.rowAt(0)._bg.color, Theme.current.colorFill0,
            "收起这一拍没再发任何鼠标事件 ⇒ 底色还在")
        settle(ts)
        verify(ts.rowAt(0) !== row, "收尾那一拍这一行的委托确实重建了（不然这条断言是空转）")
        wait(40)            // 位置器要把新委托的 y 排好，下一拍才是最终几何
        compare(ts.rowAt(0)._bg.color, Theme.current.colorFill0, "换了委托底色照样在")
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(60)
        verify(!ts.hoverInside, "指针已经不在弹层列表里")
        compare(ts.rowAt(0)._bg.color.a, 0, "离开之后要掉回透明")
        ts.destroy()
    }

    function test_hoverRectIsTheRowUnderThePointer() {
        // 弹层里的悬浮判定同样按几何：直接喂容器的指针位置，钉住「亮的是指针下那一行」
        // 与「被动画盒裁掉的那截不算」「离开列表区要全灭」。
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0"])
        settle(ts)
        // 位置器要下一拍才把新委托的 y 排好；没排好就喂指针，喂的是「全部行都叠在 y=0」的假几何
        tryVerify(function () { return ts.rowAt(1).originInColumn === 28; }, 800)
        const r1 = ts.rowAt(1)
        verify(r1 !== null && ts.rowAt(2) !== null)
        ts.hoverInside = true
        ts.hoverPoint = Qt.point(60, r1.originInColumn + r1.height / 2)
        compare(r1._bg.color, Theme.current.colorFill0, "指针下那一行亮")
        compare(ts.rowAt(0)._bg.color.a, 0, "上面那行不亮")
        compare(ts.rowAt(2)._bg.color.a, 0, "下面那行不亮")
        ts.hoverPoint = Qt.point(r1.width + 6, r1.originInColumn + r1.height / 2)
        compare(r1._bg.color.a, 0, "行宽之外不亮")
        ts.hoverPoint = Qt.point(60, r1.originInColumn + r1.height / 2)
        r1.clipBottom = r1.originInColumn + 2
        compare(r1._bg.color.a, 0, "被裁到只剩 2px ⇒ 指针那截不亮")
        r1.clipBottom = Number.MAX_VALUE
        compare(r1._bg.color, Theme.current.colorFill0, "不裁了就回来了")
        ts.hoverInside = false
        compare(r1._bg.color.a, 0, "指针不在列表区里 ⇒ 不亮")
        // 箭头变色也吃这一份判定（官方是 .semi-tree-option:hover 里的图标变色）
        ts.hoverInside = true
        compare(ts.rowAt(0)._caret.color, Theme.current.colorText2, "没被悬停的行的箭头是默认色")
        compare(r1._caret.color, Theme.current.colorText0, "被悬停那行的箭头提亮")
        ts.destroy()
    }

    function test_disabledRowKeepsCaretColor() {
        // 禁用行：底色被 off 那一条挡掉了，箭头也别跟着提亮
        // （原来那是行上的 HoverHandler 直接 enabled: false，改按几何判定后要显式留这道闸）
        const ts = opened("TreeSelect { width: 300 }", testCase.strictTree, ["0"])
        settle(ts)
        ts.hoverInside = true
        const off = ts.rowAt(1)
        verify(off !== null && off.off, "第二行（中国）是禁用行")
        ts.hoverPoint = Qt.point(60, off.originInColumn + off.height / 2)
        compare(off._bg.color.a, 0, "禁用行不亮底色")
        compare(off._caret.color, Theme.current.colorText2, "禁用行的箭头也不提亮")
        const on = ts.rowAt(3)
        ts.hoverPoint = Qt.point(60, on.originInColumn + on.height / 2)
        compare(on._caret.color, Theme.current.colorText0, "没禁用的那行照常提亮")
        ts.destroy()
    }

    function test_motionRowsGetTheirOffsetAndClipFromTheBox() {
        // 组里的行的上沿要连着「那一格的 y + 自己的 y」、下沿要连着动画盒此刻的高度：
        // 悬浮判定就吃这两个数，接错了整块会亮错行（或该亮的没亮）。
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0"])
        settle(ts)
        compare(ts.rowAt(0).originInColumn, ts.entryAt(0).y, "普通行的上沿 = 那一格的 y")
        ts.toggleExpand("0")               // 收起：动画盒带着 China / Japan 两条
        wait(40)
        const box = ts.entryAt(1)
        verify(box !== null && box.isGroup, "第二格是动画组")
        for (let i = 0; i < 2; i++) {
            const inner = ts.rowAt(1 + i)
            verify(inner !== null, "组里第 " + i + " 行拿得到")
            compare(inner.originInColumn, box.y + inner.y, "组里第 " + i + " 行的上沿")
            compare(inner.clipBottom, box.y + box.boxHeight, "组里的行的裁剪下沿 = 盒的底")
        }
        settle(ts)
        ts.destroy()
    }

    function test_virtualOptionLightsByItsOwnOffset() {
        // virtualize 那一档的行在 ListView 里，originInColumn 得跟着自己那一格的 y
        const ts = make("TreeSelect { width: 300; virtualize: ({ itemSize: 28, height: 120 }) }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        ts.open()
        wait(60)
        ts.toggleExpand("0")
        wait(300)
        compare(ts.virtualRowCount(), 4, "四行都在 ListView 里")
        const r1 = ts.virtualRowAt(1)
        verify(r1 !== null)
        mouseMove(r1, 60, 14)
        wait(60)
        compare(ts.virtualRowAt(1)._bg.color, Theme.current.colorFill0);
        compare(ts.virtualRowAt(0)._bg.color.a, 0, "上一行没亮");
        compare(ts.virtualRowAt(2)._bg.color.a, 0, "下一行没亮");
        ts.destroy()
    }

    // ---------------------------------------------------------------- 禁用
    function test_disabledTriggerDoesNotOpen() {
        const ts = make("TreeSelect { width: 300; disabled: true }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        mouseClick(ts, 60, 16)
        wait(30)
        verify(!ts.isOpen)
        compare(findChild(ts, "tsPlaceholderText").color, Theme.current.colorDisabledText)
    }

    function test_disabledNodeNotSelectable() {
        const ts = opened("TreeSelect { width: 300 }", testCase.strictTree, ["0"])
        hook(ts)
        resetLogs()
        clickRow(ts, "0-0")
        compare(ts._selectedKeys.length, 0)
        compare(testCase.changeLog.length, 0)
        compare(readyRow(ts, "0-0")._label.color, Theme.current.colorDisabledText,
            "$color-tree_option-disabled-text")
        clickRow(ts, "0-1")
        compare(ts._selectedKeys, ["0-1"], "同级的正常节点照选")
    }

    function test_disabledNodeStillExpands() {
        const ts = opened("TreeSelect { width: 300 }", testCase.strictTree, ["0"])
        compare(ts.rowCount(), 4)
        clickCaret(ts, "0-0")
        compare(ts.rowCount(), 6, "禁用只挡选中，不挡展开")
    }

    // 严格禁用：勾父不牵连 disabled 的子，也不牵连 disabled 子的孙子
    // （官方 calcDisabledKeys 把 disabled 节点连同整条子树记进 disabledKeys，
    // 于是 China 和它下面的北京上海都不可选，Asia 只从 Japan 那条支算满选）
    function test_disableStrictlyCascade() {
        const ts = opened("TreeSelect { width: 300; multiple: true; disableStrictly: true }",
            testCase.strictTree, ["0", "0-0"])
        clickCheck(ts, "0")
        compare(sorted(ts._checkedKeys), ["0", "0-1"],
            "中国整条子树被跳过，Asia 只靠日本那条支就算满选")
        verify(!readyRow(ts, "0-0")._check.checked, "disabled 行保持未勾")
        verify(!readyRow(ts, "0-0-0")._check.checked, "disabled 的子孙也不被牵连")
        clickCheck(ts, "0-0-0")
        wait(30)
        compare(sorted(ts._checkedKeys), ["0", "0-1"], "点 disabled 的北京没有任何反应")
    }

    function test_nonStrictCascadeIncludesDisabled() {
        const ts = opened("TreeSelect { width: 300; multiple: true }",
            testCase.strictTree, ["0"])
        clickCheck(ts, "0")
        compare(sorted(ts._checkedKeys), ["0", "0-0", "0-0-0", "0-0-1", "0-1"],
            "非严格模式下 disabled 也被级联勾上")
    }

    // ---------------------------------------------------------------- 受控
    function test_controlledSingleFollowsValue() {
        const ts = make("TreeSelect { width: 300; value: 'Shanghai' }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        verify(ts.controlled)
        compare(ts._selectedKeys, ["0-0-1"])
        compare(findChild(ts, "tsSingleText").text, "Shanghai")
        ts.value = "North America"
        wait(30)
        compare(ts._selectedKeys, ["1"])
        compare(findChild(ts, "tsSingleText").text, "North America")
        ts.value = undefined
        wait(30)
        verify(!ts.controlled, "value 撤回去就回到非受控")
        compare(ts._selectedKeys, ["1"], "非受控后选区留在最后一次同步的结果上")
        ts.value = "Beijing"
        wait(30)
        compare(ts._selectedKeys, ["0-0-0"], "再受控照样跟得上")
    }

    // 受控时内部点击不改选区，只回 onChange —— 等外部写回来才变
    function test_controlledClickEmitsButDoesNotMutate() {
        const ts = opened("TreeSelect { width: 300; value: 'Shanghai' }", testCase.worldTree)
        hook(ts)
        resetLogs()
        clickRow(ts, "0")
        compare(testCase.changeLog.length, 1)
        compare(testCase.changeLog[0][0], "Asia")
        compare(ts._selectedKeys, ["0-0-1"], "value 没被外部改，选区就不动")
    }

    function test_controlledMultipleMergesParents() {
        const ts = make("TreeSelect { width: 300; multiple: true }")
        ts.treeData = testCase.worldTree
        ts.value = ["Beijing", "Shanghai", "Chengdu"]
        waitForRendering(ts)
        wait(30)
        compare(sorted(ts._checkedKeys), ["0-0", "0-0-0", "0-0-1", "0-0-2"],
            "受控也要把满选的父补齐")
        compare(ts.displayKeys, ["0-0"])
    }

    function test_multiplePlaceholderWhenEmpty() {
        const ts = make("TreeSelect { width: 300; multiple: true; placeholder: 'Pick cities' }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        const ph = findChild(ts, "tsPlaceholderText")
        verify(ph.visible, "多选没值时官方也画 placeholder")
        compare(ph.text, "Pick cities")
        verify(!findChild(ts, "tsTagRow").visible)
    }

    // ---------------------------------------------------------------- 展开受控
    function test_expandedKeysControlled() {
        const ts = make("TreeSelect { width: 300; filterTreeNode: true; expandedKeys: [] }")
        ts.treeData = testCase.worldTree
        ts.open()
        wait(40)
        hook(ts)
        resetLogs()
        clickCaret(ts, "0")
        compare(testCase.expandLog.length, 1)
        compare(ts.rowCount(), 2, "外部没写回 expandedKeys，就不该展开")
        ts.expandedKeys = ["0"]
        wait(40)
        compare(ts.rowCount(), 4)
        resetLogs()
        ts.searchBy("osaka")
        wait(40)
        compare(ts.rowCount(), 4, "展开受控时搜索不再自动展开")
        compare(testCase.searchLog[0][1], ["0", "0-1"], "filteredExpandedKeys 照样回抛")
    }

    function test_autoExpandParentOnControlledKeys() {
        const ts = make("TreeSelect { width: 300; expandedKeys: ['0-0'] }")
        ts.treeData = testCase.worldTree
        ts.open()
        wait(40)
        compare(ts.rowCount(), 2, "默认不补祖先：根没展开，子层看不见")
        ts.autoExpandParent = true
        wait(40)
        compare(ts.rowCount(), 7, "autoExpandParent 把祖先一起展开")
        compare(ts.visibleOptions.map(o => o.key),
            ["0", "0-0", "0-0-0", "0-0-1", "0-0-2", "0-1", "1"])
    }

    // ---------------------------------------------------------------- 虚拟化
    function test_virtualizeUsesListView() {
        const ts = opened("TreeSelect { width: 300; virtualize: ({ itemSize: 28, height: 200 }) }",
            testCase.worldTree, ["0", "0-0"])
        verify(ts.useVirtualList)
        compare(ts.rowCount(), 0, "普通列表不建代理")
        compare(ts.virtualRowCount(), 7)
        const row = ts.virtualRowAt(2)
        compare(row.height, 28)
        compare(row._label.text, "Beijing")
        compare(ts._popup.implicitHeight, 200)
        compare(ts.virtualItemSize, 28)
        const custom = make("TreeSelect { width: 300; virtualize: ({ itemSize: 40, height: 300 }) }")
        compare(custom.virtualItemSize, 40)
        compare(custom.virtualHeight, 300)
        compare(custom.virtualWidth, 300, "没给 width 就用弹层宽")
    }

    // ---------------------------------------------------------------- 动态数据
    function test_treeDataChangeRebuildsRows() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree)
        compare(ts.rowCount(), 2)
        ts.treeData = [{ label: "Only", value: "o", key: "o" }]
        wait(40)
        compare(ts.rowCount(), 1)
        compare(ts.rowAt(0)._label.text, "Only")
        compare(ts._m.keys, ["o"])
    }

    function test_selectionSurvivesDataRefresh() {
        const ts = make("TreeSelect { width: 300; defaultValue: 'Beijing' }")
        ts.treeData = testCase.worldTree
        wait(30)
        compare(ts._selectedKeys, ["0-0-0"])
        ts.treeData = testCase.worldTree.slice()
        wait(30)
        compare(ts._selectedKeys, ["0-0-0"], "同一份数据换个引用，选区不该被冲掉")
    }

    // ---------------------------------------------------------------- 异步加载
    function test_loadDataOnExpand() {
        const ts = opened("TreeSelect { width: 300 }", [
            { label: "Expand to load", value: "0", key: "0" },
            { label: "Leaf Node", value: "2", key: "2", isLeaf: true }])
        // done 攥在测试手里，不用定时器 —— 否则「加载中」那一拍会被 wait() 跨过去
        ts.loadData = function (node, done) { testCase.pendingDone = done }
        hook(ts)
        resetLogs()
        verify(!readyRow(ts, "2")._caret.visible, "isLeaf 的节点不画箭头")
        verify(readyRow(ts, "0")._caret.visible, "有 loadData 时空子节点也要给箭头")
        clickCaret(ts, "0")
        verify(ts._loadingSet["0"] === true, "loading=" + JSON.stringify(ts._loadingSet)
            + " expanded=" + JSON.stringify(ts._expandedSet)
            + " selected=" + JSON.stringify(ts._selectedKeys))
        verify(readyRow(ts, "0")._spin.visible, "加载中转圈替掉箭头")
        compare(testCase.loadLog.length, 0, "数据没回来前不发 onLoad")
        testCase.pendingDone()
        wait(40)
        compare(testCase.loadLog, [1], "loadedKeys 一个")
        verify(ts._loadedSet["0"] === true)
        verify(!ts._loadingSet["0"], "loading 要撤掉")
        verify(!readyRow(ts, "0")._spin.visible)
    }

    // 官方 loadedKeys 去重：加载中与已加载过的节点都不该再发一次 loadData。
    // 这里用公开方法 toggleExpand 驱动 —— 加载中箭头被 Spin 替掉、加载完没子节点则箭头消失，
    // 指针根本没有第二次点箭头的机会，只有程序化调用才走得到这条去重（变异去重被打红也靠它）。
    function test_loadDataNotRequestedAgainWhileLoadingOrLoaded() {
        const ts = opened("TreeSelect { width: 300 }", [
            { label: "Expand to load", value: "0", key: "0" },
            { label: "Leaf Node", value: "2", key: "2", isLeaf: true }])
        ts.loadData = function (node, done) {
            testCase.loadCount++
            testCase.pendingDone = done
        }
        wait(30)
        resetLogs()
        ts.toggleExpand("0")
        wait(30)
        compare(testCase.loadCount, 1)
        ts.toggleExpand("0")
        ts.toggleExpand("0")
        wait(30)
        compare(testCase.loadCount, 1, "loading 中收起再展开不重复请求")
        testCase.pendingDone()
        wait(40)
        verify(ts._loadedSet["0"] === true)
        ts.toggleExpand("0")
        ts.toggleExpand("0")
        wait(40)
        compare(testCase.loadCount, 1, "已加载过的节点不再重复 loadData")
    }

    // 官方 defaultOpen（treeSelect/index.tsx:311）：建完就是展开态
    function test_defaultOpenStartsOpened() {
        const ts = make("TreeSelect { width: 300; defaultOpen: true }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(40)
        verify(ts.isOpen, "defaultOpen 直接展开")
        compare(ts.rowCount(), 2)
        const off = make("TreeSelect { width: 300 }")
        off.treeData = testCase.worldTree
        wait(40)
        verify(!off.isOpen, "不给就关着")
    }

    // ---------------------------------------------------------------- 自定义 Trigger
    Component {
        id: probeTrigger

        Item {
            property var value: []
            property string inputValue: ""
            property string placeholder: ""
            property bool disabled: false
            property var search: null
            property var clear: null
            property var remove: null

            objectName: "probeTrigger"
            implicitHeight: 24

            Text {
                objectName: "probeTriggerText"
                text: "n" + parent.value.length + "/i" + parent.inputValue
                    + "/p" + parent.placeholder + "/d" + parent.disabled
            }
        }
    }

    function test_triggerRenderReplacesDefaultTrigger() {
        const ts = make("TreeSelect { width: 300; placeholder: 'pick';\
            triggerRender: probeTrigger }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(40)
        verify(!ts._trigger.visible, "官方接管时 .semi-treeselect 那层框整个没了")
        verify(ts._singleSearch.item === null)
        const text = findChild(ts, "probeTriggerText")
        compare(text.text, "n0/i/ppick/dfalse")
        mouseClick(ts, 60, 16)
        wait(40)
        verify(ts.isOpen, "点自定义触发器照样开下拉")
        clickRow(ts, "0")
        ts.open()
        wait(40)
        compare(findChild(ts, "probeTriggerText").text, "n1/i/ppick/dfalse",
            "value 入参是选中节点数组")
    }

    // ---------------------------------------------------------------- 自定义渲染已选项
    Component {
        id: probeSingleItem

        Text {
            property var modelData: ({})
            property int index: -1
            property var remove: null

            objectName: "probeSingleItem"
            text: "S:" + String(modelData.label === undefined ? "?" : modelData.label)
        }
    }

    Component {
        id: probeTagItem

        Text {
            property var modelData: ({})
            property int index: -1
            property var remove: null

            objectName: "probeTagItem"
            text: "#" + index + ":" + String(modelData.value === undefined
                ? "?" : modelData.value)

            TapHandler {
                onTapped: {
                    if (parent.remove !== null)
                        parent.remove()
                }
            }
        }
    }

    function test_renderSelectedItemSingle() {
        const ts = make("TreeSelect { width: 300; renderSelectedItem: probeSingleItem }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(40)
        verify(findChild(ts, "tsPlaceholderText").visible, "没选中时仍然显示 placeholder")
        // 官方 getRenderTextInSingle()（foundation.ts:877-891）没选中直接返回 null，
        // 钩子连实例都不建 —— 只断 placeholder 可见是空的，钩子叠在上面照样绿。
        compare(findChild(ts, "probeSingleItem"), null, "钩子没被实例化")
        verify(!findChild(ts, "tsSingleHook").active)
        verify(ts._singleSearch.item === null)
        ts.open()
        wait(40)
        clickRow(ts, "0")
        compare(findChild(ts, "probeSingleItem").text, "S:Asia")
        verify(findChild(ts, "tsSingleHook").active, "选中之后钩子才接管")
        verify(!findChild(ts, "tsSingleText").visible)
        verify(!findChild(ts, "tsPlaceholderText").visible)
    }

    function test_renderSelectedItemMultiple() {
        const ts = make("TreeSelect { width: 300; multiple: true;\
            defaultValue: ['Beijing', 'Canada']; renderSelectedItem: probeTagItem }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(40)
        hook(ts)
        resetLogs()
        const labels = ts.tagLabels
        compare(labels.length, 2)
        compare(ts.tagAt(0).item.text, "#0:" + labels[0])
        mouseClick(ts.tagAt(1), 4, 8)
        wait(30)
        compare(ts._checkedKeys.length, 1, "钩子里调 remove 走同一条撤选")
        compare(testCase.changeLog.length, 1)
        compare(testCase.selectLog[0][1], false)
    }

    // ---------------------------------------------------------------- 清除
    function test_showClearNeedsHoverOrOpen() {
        const ts = make("TreeSelect { width: 300; showClear: true; defaultValue: 'Osaka' }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        verify(!ts.showClearBtn, "既没 hover 也没 open")
        verify(!ts._clearBox.visible)
        verify(ts._arrowBox.visible)
        ts.open()
        wait(30)
        verify(ts.showClearBtn)
        verify(ts._clearBox.visible)
        verify(!ts._arrowBox.visible, "官方 renderArrow 在清除按钮出现时让位")
    }

    function test_clearAllEmitsAndResets() {
        const ts = make("TreeSelect { width: 300; showClear: true; defaultValue: 'Osaka' }")
        ts.treeData = testCase.worldTree
        ts.open()
        waitForRendering(ts)
        wait(30)
        hook(ts)
        resetLogs()
        mouseClick(ts._clearBox, ts._clearBox.width / 2, ts._clearBox.height / 2)
        wait(30)
        compare(ts._selectedKeys, [])
        compare(testCase.changeLog.length, 1)
        compare(testCase.changeLog[0][0], undefined)
        compare(testCase.clearCount, 1)
    }

    function test_clearDisabledDoesNothing() {
        const ts = make("TreeSelect { width: 300; showClear: true; disabled: true;\
            defaultValue: 'Osaka' }")
        ts.treeData = testCase.worldTree
        ts.open()
        wait(30)
        hook(ts)
        resetLogs()
        ts.clearAll()
        wait(30)
        compare(testCase.changeLog.length, 0)
        compare(testCase.clearCount, 0)
        compare(ts._selectedKeys, ["0-1-0"])
    }

    // ---------------------------------------------------------------- onChangeWithObject
    // 官方 onChangeWithObject=true：change 的第一个入参换成节点对象（数组），
    // 并且 value / defaultValue 也按「对象取 valueName」读
    // （foundation.ts:410-438 的 _notifyMultipleChange / _notifyChange）。
    function test_changeWithObjectEmitsNodeObject() {
        const ts = opened("TreeSelect { width: 300; onChangeWithObject: true }",
            testCase.worldTree, ["0", "0-1"])
        hook(ts)
        resetLogs()
        clickRow(ts, "0-1-0")
        compare(testCase.changeLog.length, 1)
        const arg = testCase.changeLog[0][0]
        verify(typeof arg === "object" && arg !== null && !Array.isArray(arg),
            "单选 + onChangeWithObject 发的是单个节点对象")
        compare(arg.value, "Osaka")
        compare(ts._selectedKeys, ["0-1-0"])
    }

    function test_changeWithObjectMultipleEmitsArray() {
        const ts = opened("TreeSelect { width: 300; multiple: true; onChangeWithObject: true }",
            testCase.worldTree, ["0", "0-0"])
        hook(ts)
        resetLogs()
        clickCheck(ts, "0-0-0")
        const arg = testCase.changeLog[0][0]
        verify(Array.isArray(arg), "多选发的是数组")
        compare(arg.length, 1)
        compare(arg[0].label, "Beijing", "数组元素是原始节点")
        compare(testCase.changeLog[0][1], 1)
    }

    // 关掉它就必须退回「按值」读：对象数组解不出 key，选区落不到任何一行
    function test_objectValuesOnlyResolveWhenFlagOn() {
        const ts = make("TreeSelect { width: 300; multiple: true; onChangeWithObject: true;\
            defaultValue: [{ value: 'Beijing' }, { value: 'Canada' }] }")
        ts.treeData = testCase.worldTree
        wait(40)
        compare(sorted(ts._checkedKeys), ["0-0-0", "1-1"])
        const off = make("TreeSelect { width: 300; multiple: true;\
            defaultValue: [{ value: 'Beijing' }] }")
        off.treeData = testCase.worldTree
        wait(40)
        verify(off._checkedKeys.indexOf("0-0-0") < 0,
            "flag 关时对象解不出 key（官方同款：按值查，查不到就不选）")
    }

    // 官方 handleClear → clearInput() 里的 selectedKeys 是**清空之前**那份
    // （React 的 setState 批量，同一轮 handler 里 getStates() 仍旧，foundation.ts:536+552-558），
    // 所以带搜索词点清除之后，刚被清掉那一项的祖先仍永久展开。
    function test_clearWithTriggerSearchKeepsAncestorsOfCleared() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true; showClear: true;\
            searchPosition: 'trigger'; defaultValue: 'Osaka' }", testCase.worldTree, ["0"])
        ts.handleInputChange("osaka")
        wait(40)
        ts.clearAll()
        wait(40)
        compare(ts._selectedKeys, [])
        compare(ts._input, "")
        verify(ts.isExpanded("0"), "亚洲本来就展开着")
        verify(ts.isExpanded("0-1"), "日本的祖先被永久并进 expandedKeys")
    }

    // 官方 treeNodeLabelProp 只决定触发器回显（index.tsx:885 / 1206 的
    // get(keyMaps, 'label', treeNodeLabelProp)），下拉里的行仍按 label 渲染
    function test_treeNodeLabelPropAffectsTriggerOnly() {
        const ts = make("TreeSelect { width: 300; treeNodeLabelProp: 'full';\
            defaultValue: 'a' }")
        ts.treeData = [{ label: "简称", full: "完整名称", value: "a", key: "a" }]
        wait(40)
        compare(findChild(ts, "tsSingleText").text, "完整名称")
        ts.open()
        wait(40)
        compare(readyRow(ts, "a")._label.text, "简称", "行里仍然显示 label")
        // keyMaps.label 给了就以它为准（官方那是 get(keyMaps,'label',…) 的第一选择）
        const km = make("TreeSelect { width: 300; treeNodeLabelProp: 'full';\
            keyMaps: ({ label: 'label' }); defaultValue: 'a' }")
        km.treeData = [{ label: "简称", full: "完整名称", value: "a", key: "a" }]
        wait(40)
        compare(findChild(km, "tsSingleText").text, "简称")
    }

    function test_searchPlaceholderAndRestPopoverPosition() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true }",
            testCase.worldTree)
        compare(findChild(ts._popup, "tsDropInput").placeholderText, qsTr("搜索"))
        ts.close()
        wait(30)
        const ph = opened("TreeSelect { width: 300; filterTreeNode: true;\
            searchPlaceholder: '搜城市' }", testCase.worldTree)
        compare(findChild(ph._popup, "tsDropInput").placeholderText, "搜城市")
        // restTagsPopoverProps.position 要真的改 +N 浮层的方位
        const rest = make("TreeSelect { width: 300; multiple: true; maxTagCount: 2;\
            showRestTagsPopover: true; restTagsPopoverProps: ({ position: 'bottom' });\
            defaultValue: ['Beijing', 'Chengdu', 'Canada'] }")
        rest.treeData = testCase.worldTree
        wait(40)
        compare(rest._restPop.placement, Enums.Bottom)
        const dflt = make("TreeSelect { width: 300; multiple: true; maxTagCount: 2;\
            showRestTagsPopover: true; defaultValue: ['Beijing', 'Chengdu', 'Canada'] }")
        dflt.treeData = testCase.worldTree
        wait(40)
        compare(dflt._restPop.placement, Enums.Top, "官方默认 top")
    }

    // 受控 loadedKeys 也算「已加载」（index.tsx 把 new Set(props.loadedKeys) 写回 state，
    // foundation.ts:374-378 的去重读的就是那份 state）
    function test_controlledLoadedKeysCountAsLoaded() {
        const ts = opened("TreeSelect { width: 300; loadedKeys: ['0'] }", [
            { label: "Expand to load", value: "0", key: "0" },
            { label: "Leaf Node", value: "2", key: "2", isLeaf: true }])
        ts.loadData = function (node, done) {
            testCase.loadCount++
            done()
        }
        wait(30)
        resetLogs()
        verify(!readyRow(ts, "0")._caret.visible, "外部声明已加载 → 没有子节点就是叶子")
        ts.toggleExpand("0")
        wait(40)
        compare(testCase.loadCount, 0, "受控 loadedKeys 里的节点不再请求")
        compare(testCase.loadLog.length, 0, "受控时内部不写 loadedSet")
    }

    // ---------------------------------------------------------------- 其它外观
    function test_insetLabelAndIconsRender() {
        const ts = make("TreeSelect { width: 300; insetLabel: '地区'; prefixIcon: 'search';\
            suffixIcon: 'clear' }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        const label = findChild(ts, "tsInsetLabel")
        compare(label.text, "地区")
        verify(label.visible)
        const prefix = findChild(ts, "tsPrefixIcon")
        verify(prefix.visible)
        verify(findChild(ts, "tsSuffixIcon").visible)
        verify(prefix.x > label.x + label.width, "prefix 排在 insetLabel 右边")
    }

    function test_outerSlotsAddHeight() {
        const ts = opened("TreeSelect { width: 300; outerTopSlot: probeSlot;\
            outerBottomSlot: probeSlot }", testCase.worldTree)
        compare(ts._popup.implicitHeight, 2 * 28 + 16 + 20 + 20)
        // implicitHeight 是从 Loader 算的，宿主 height 写死 0 也能满足上面那条 ——
        // 官方 .semi-tree-select-dropdown-top-slot / -bottom-slot 各自占位 20。
        compare(findChild(ts._popup, "tsTopSlotHost").height, 20)
        compare(findChild(ts._popup, "tsBottomSlotHost").height, 20)
        verify(findChild(findChild(ts._popup, "tsTopSlotHost"), "probeSlot") !== null,
            "上槽真的画出来了")
        verify(findChild(findChild(ts._popup, "tsBottomSlotHost"), "probeSlot") !== null,
            "下槽真的画出来了")
    }

    Component {
        id: probeSlot

        Item {
            objectName: "probeSlot"
            implicitHeight: 20
            implicitWidth: 100
        }
    }

    function test_labelEllipsisSwitchesElide() {
        const ts = opened("TreeSelect { width: 300 }", testCase.worldTree, ["0"])
        compare(readyRow(ts, "0-0")._label.elide, Text.ElideNone, "官方默认不截断")
        ts.labelEllipsis = true
        wait(40)
        compare(readyRow(ts, "0-0")._label.elide, Text.ElideRight)
    }

    function test_searchByMethodOpensPopup() {
        const ts = make("TreeSelect { width: 300; filterTreeNode: true }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        verify(!ts.isOpen)
        ts.searchBy("canada")
        wait(40)
        verify(ts.isOpen)
        compare(ts._input, "canada")
        compare(ts.visibleOptions.filter(o => o.matched).map(o => o.key), ["1-1"])
    }

    function test_closeMethodClearsSearchState() {
        const ts = opened("TreeSelect { width: 300; filterTreeNode: true }", testCase.worldTree)
        ts.handleInputChange("asia")
        wait(30)
        compare(ts._input, "asia")
        ts.close()
        wait(40)
        compare(ts._input, "", "官方 handleAfterClose → clearInput")
        verify(!ts.inSearch)
    }

    function test_placeholderTextWhenNothingSelected() {
        const ts = make("TreeSelect { width: 300; placeholder: 'Pick one' }")
        ts.treeData = testCase.worldTree
        waitForRendering(ts)
        wait(30)
        const ph = findChild(ts, "tsPlaceholderText")
        verify(ph.visible)
        compare(ph.text, "Pick one")
        verify(!findChild(ts, "tsSingleText").visible)
    }
}
