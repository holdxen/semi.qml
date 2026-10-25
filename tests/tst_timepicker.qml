import QtQuick
import QtTest
import Semi
import "../src/DateFormat.js" as DF

// 时间选择器：格式引擎 + 面板列的生成 + 点选 / 敲字 / 受控开合。
//
// 断言尽量落在渲染出来的东西上（弹层里实际有几列、哪一格文字带「时」后缀、
// 灰掉的那格是什么颜色），而不是组件内部的中间属性。
TestCase {
    id: testCase

    name: "TimePicker"
    when: windowShown
    width: 900
    height: 900

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    function walk(root, name, out) {
        out = out === undefined ? [] : out
        const kids = root.children
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].objectName === name)
                out.push(kids[i])
            walk(kids[i], name, out)
        }
        return out
    }

    // 弹层打开后会被重 parent 到窗口的 overlay 上，只能从 _popup 往下找
    function findAll(tp, name) {
        return walk(tp._popup.contentItem, name)
    }

    function one(tp, name) {
        const found = findAll(tp, name)
        return found.length > 0 ? found[0] : null
    }

    function panel(tp, index) {
        return one(tp, "timePickerPanel" + index)
    }

    function column(tp, kind, index) {
        const p = panel(tp, index === undefined ? 0 : index)
        if (p === null)
            return null
        const found = walk(p, "column-" + kind)
        return found.length > 0 ? found[0] : null
    }

    function cell(tp, text, kind, index) {
        const col = column(tp, kind, index)
        const found = col === null ? [] : walk(col, "scrollCell-" + text)
        return found.length > 0 ? found[0] : null
    }

    // 只数「真的画出来了」的文字：隐藏掉的节点还在树上，光看 text 会把
    // visible: false 的分支也算成渲染成功
    function texts(root) {
        const out = []
        const kids = root.children
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].text !== undefined && kids[i].visible)
                out.push(String(kids[i].text))
            const inner = texts(kids[i])
            for (let j = 0; j < inner.length; ++j)
                out.push(inner[j])
        }
        return out
    }

    function openAndGet(tp) {
        tp.openPanel()
        // 入场动画 opacity 50ms、scale 100ms：等满再点，否则落点会偏 1-2px 点空
        tryVerify(function () {
            return tp._popup.isOpen && tp._popup.opacity > 0.99 && Math.abs(tp._popup.scale - 1) < 1e-4
        })
        return tp._popup
    }

    function inputOf(tp) {
        // 只在本组件的子树里找：destroy() 是异步的，从 testCase 往下扫会先扫到
        // 上一个用例还没回收干净的那个输入框
        const found = walk(tp, "timePickerInput")
        return found.length > 0 ? found[0] : null
    }

    function focusField(tp) {
        const input = inputOf(tp)
        verify(input !== null)
        input.input.forceActiveFocus()
        tryVerify(function () { return input.input.activeFocus; })
        return input
    }

    // QML 的 TestCase 没有 keyClicks(text)，逐字符 keyClick；
    // 先全选再敲就是「替换整串」的真实路径
    function typeOver(input, text) {
        input.input.selectAll()
        for (let i = 0; i < String(text).length; ++i)
            keyClick(String(text).charAt(i))
    }

    // 把焦点从时间输入框上抢走（activeFocus 只读，只能靠别的可获得焦点的项接管）。
    // 抢焦点的 TextInput 建一次反复用：局部变量会在函数返回后被回收，
    // 焦点会跟着一起丢。
    property Item focusThief: null

    function stealFocus(tp) {
        if (testCase.focusThief === null)
            testCase.focusThief = make("TextInput { objectName: \"focusThief\"; width: 20; height: 20 }")
        const input = inputOf(tp)
        testCase.focusThief.forceActiveFocus()
        tryVerify(function () { return !input.input.activeFocus; })
    }

    // ---- 格式引擎 ----

    function test_defaultTimeFormatFollows12Hours() {
        compare(DF.defaultTimeFormat(false), "HH:mm:ss")
        compare(DF.defaultTimeFormat(true), "a h:mm:ss")
    }

    function test_formatRendersMeridiemAndClockHour() {
        // 0 点在 12 小时制里是「上午 12」，13 点是「下午 1」（date-fns 的 h 不带前导零）
        compare(DF.format(new Date(1970, 0, 1, 0, 5, 9), "a h:mm:ss"), "上午 12:05:09")
        compare(DF.format(new Date(1970, 0, 1, 12, 0, 0), "a h:mm:ss"), "下午 12:00:00")
        compare(DF.format(new Date(1970, 0, 1, 13, 4, 9), "a h:mm:ss"), "下午 1:04:09")
        compare(DF.format(new Date(1970, 0, 1, 9, 30, 0), "HH:mm"), "09:30")
    }

    function test_parseAcceptsMeridiemInBothLanguages() {
        compare(DF.parse("下午 11:21", "a h:mm").getHours(), 23)
        compare(DF.parse("上午 12:00", "a h:mm").getHours(), 0)
        compare(DF.parse("PM 1:04", "a h:mm").getHours(), 13)
        compare(DF.parse("10:24", "HH:mm").getMinutes(), 24)
    }

    function test_parseIsStrictAgainstFormat() {
        // 短了一截、或者分隔符 / 空格对不上都解不出来（date-fns parse 的语义）
        compare(DF.parse("10:24", "HH:mm:ss"), null)
        compare(DF.parse("10/24", "HH:mm"), null)
        compare(DF.parse("上午10:24", "a HH:mm"), null)
        compare(DF.parse("13:24", "a HH:mm"), null)
    }

    // ---- 属性面 ----

    function test_placeholderFollowsType() {
        const tp = make("TimePicker { }")
        const range = make('TimePicker { type: "timeRange" }')
        const custom = make('TimePicker { placeholder: "挑一个点" }')
        compare(tp.placeholderText, "请选择时间")
        compare(range.placeholderText, "请选择时间范围")
        compare(custom.placeholderText, "挑一个点")
        tp.destroy(); range.destroy(); custom.destroy()
    }

    function test_formatOverrideWins() {
        const plain = make("TimePicker { }")
        const clock12 = make("TimePicker { use12Hours: true }")
        const given = make('TimePicker { use12Hours: true; format: "HH:mm" }')
        compare(plain.fmt, "HH:mm:ss")
        compare(clock12.fmt, "a h:mm:ss")
        compare(given.fmt, "HH:mm")
        plain.destroy(); clock12.destroy(); given.destroy()
    }

    function test_sizeHeights() {
        const small = make("TimePicker { size: Enums.Small }")
        const normal = make("TimePicker { }")
        const large = make("TimePicker { size: Enums.Large }")
        compare(small.implicitHeight, 24)
        compare(normal.implicitHeight, 32)
        compare(large.implicitHeight, 40)
        small.destroy(); normal.destroy(); large.destroy()
    }

    // ---- 值 ----

    function test_stringValueMustMatchFormat() {
        const mismatch = make('TimePicker { value: "10:24" }')
        const match = make('TimePicker { value: "10:24"; format: "HH:mm" }')
        compare(mismatch.displayText, "")
        compare(match.displayText, "10:24")
        mismatch.destroy(); match.destroy()
    }

    function test_defaultValueRangeIsJoinedWithSeparator() {
        const tp = make('TimePicker { type: "timeRange"; defaultValue: ["10:23:15", "12:38:32"] }')
        compare(tp.displayText, "10:23:15 ~ 12:38:32")
        compare(tp.hasValue, true)
        tp.destroy()
    }

    function test_rangeWithOneEmptyHalfKeepsTheOther() {
        // formatValue:412-435 是 dates.join(sep)，只有一段时连分隔符都不出现
        const tp = make('TimePicker { type: "timeRange"; defaultValue: ["10:23:15"] }')
        compare(tp.displayText, "10:23:15")
        tp.destroy()
    }

    function test_dateAndTimestampValues() {
        const tp = make('TimePicker { value: new Date(1970, 0, 1, 8, 5, 1) }')
        compare(tp.displayText, "08:05:01")
        tp.destroy()
        const stamp = new Date(1970, 0, 1, 23, 59, 58).getTime()
        const tp2 = make("TimePicker { value: " + stamp + " }")
        compare(tp2.displayText, "23:59:58")
        tp2.destroy()
    }

    function test_oneBadHalfDropsTheWholeValue() {
        // initDataFromDefaultValue:155-160：只要有一段解不出来，整个值作废
        const tp = make('TimePicker { type: "timeRange"; defaultValue: ["坏", "12:38:32"] }')
        compare(tp.displayText, "")
        compare(tp.hasValue, false)
        const none = make('TimePicker { defaultValue: ["坏"] }')
        compare(none.displayText, "")
        compare(none.hasValue, false)
        tp.destroy(); none.destroy()
    }

    // ---- 面板的列 ----

    function test_panelColumnSetFollowsFormat() {
        const full = make('TimePicker { defaultOpen: true; format: "HH:mm:ss" }')
        openAndGet(full)
        verify(one(full, "column-hour") !== null)
        verify(one(full, "column-minute") !== null)
        verify(one(full, "column-second") !== null)
        verify(one(full, "column-ampm") === null)
        // 没值时选中的就是 00 那格，所以带后缀的是它，邻居保持光秃秃的数字
        compare(texts(column(full, "hour")).indexOf("00时") >= 0, true)
        compare(texts(column(full, "hour")).indexOf("01") >= 0, true)
        full.destroy()

        const short = make('TimePicker { defaultOpen: true; format: "HH:mm" }')
        openAndGet(short)
        verify(one(short, "column-second") === null)
        short.destroy()
    }

    function test_ampmColumnOnlyIn12HourMode() {
        const tp = make("TimePicker { defaultOpen: true; use12Hours: true }")
        openAndGet(tp)
        const ampm = one(tp, "column-ampm")
        verify(ampm !== null)
        compare(ampm.items.length, 2)
        compare(ampm.items[0].text, "上午")
        compare(ampm.items[1].text, "下午")
        tp.destroy()
    }

    function test_columnWidthsAndPopupSize() {
        const tp = make("TimePicker { defaultOpen: true; format: \"HH:mm:ss\" }")
        openAndGet(tp)
        // $width-timePicker_panel_list_* = 64，body 左右内边距 16
        compare(one(tp, "column-hour").width, 64)
        compare(panel(tp, 0).bodyPaddingX, 16)
        compare(tp._popup.width, 16 * 2 + 64 * 3)
        compare(tp._popup.height, 252)
        tp.destroy()
    }

    function test_ampmColumnIsWiderThanTheOthers() {
        const tp = make("TimePicker { defaultOpen: true; use12Hours: true; format: \"a h:mm\" }")
        openAndGet(tp)
        compare(one(tp, "column-ampm").width, 72)
        compare(one(tp, "column-hour").width, 64)
        compare(tp._popup.width, 16 * 2 + 72 + 64 + 64)
        tp.destroy()
    }

    function test_rangeHasTwoPanelsAndNoBodyPadding() {
        const tp = make('TimePicker { defaultOpen: true; type: "timeRange"; defaultValue: ["10:23:15", "12:38:32"] }')
        openAndGet(tp)
        verify(panel(tp, 0) !== null)
        verify(panel(tp, 1) !== null)
        compare(panel(tp, 0).rangePanel, true)
        compare(panel(tp, 0).bodyPaddingX, 0)
        // 两块面板各 3×64，中间 2px 分割线
        compare(tp._popup.width, 64 * 3 * 2 + 2)
        tp.destroy()
    }

    function test_stepShrinksGeneratedItems() {
        const tp = make("TimePicker { defaultOpen: true; minuteStep: 15; secondStep: 10 }")
        openAndGet(tp)
        const p = panel(tp, 0)
        compare(p.minuteItems.length, 4)
        compare(p.minuteItems.map(function (o) { return o.text; }), ["00", "15", "30", "45"])
        compare(p.secondItems.length, 6)
        compare(p.hourItems.length, 24)
        tp.destroy()
    }

    function test_hourStepSkipsIn24HourMode() {
        const tp = make("TimePicker { defaultOpen: true; hourStep: 6 }")
        openAndGet(tp)
        compare(panel(tp, 0).hourItems.map(function (o) { return o.value; }), [0, 6, 12, 18])
        tp.destroy()
    }

    function test_12HourColumnStartsWithTwelve() {
        const tp = make("TimePicker { defaultOpen: true; use12Hours: true }")
        openAndGet(tp)
        const hours = panel(tp, 0).hourItems.map(function (o) { return o.text; })
        compare(hours[0], "12")
        compare(hours[1], "01")
        compare(hours.length, 12)
        tp.destroy()
    }

    // 只有选中那一格铺底色（.semi-scrolllist-item-sel）。曾经因为读了一个
    // 不存在的 TapHandler.held，绑定求成 undefined，visible 停在默认值 true，
    // 结果整列全灰。
    function test_onlySelectedRowPaintsBackground() {
        const tp = make('TimePicker { defaultOpen: true; format: "HH:mm:ss"; defaultValue: "10:24:00" }')
        openAndGet(tp)
        const on = cell(tp, "10", "hour")
        verify(on !== null)
        const onRect = on.children.filter(function (c) { return c.color !== undefined })[0]
        compare(onRect.visible, true)
        compare(onRect.color, Theme.current.colorPrimaryLightDefault)
        const off = cell(tp, "11", "hour")
        verify(off !== null)
        const offRect = off.children.filter(function (c) { return c.color !== undefined })[0]
        compare(offRect.visible, false)
        tp.destroy()
    }

    function test_wheelBandOnlyShowsInWheelMode() {
        const wheel = make('TimePicker { defaultOpen: true; scrollItemProps: ({ mode: "wheel" }) }')
        openAndGet(wheel)
        const bands = findAll(wheel, "wheelBand")
        verify(bands.length > 0)
        compare(bands[0].visible, true)
        wheel.destroy()

        const normal = make("TimePicker { defaultOpen: true }")
        openAndGet(normal)
        const hidden = findAll(normal, "wheelBand")
        verify(hidden.length > 0)
        compare(hidden[0].visible, false)
        normal.destroy()
    }

    function test_disabledHoursMarkRowsGrey() {
        const tp = make("TimePicker { defaultOpen: true; format: \"HH:mm\"; defaultValue: \"09:30\"; disabledHours: function(){ return [10, 11]; } }")
        openAndGet(tp)
        const items = panel(tp, 0).hourItems
        compare(items.filter(function (o) { return o.disabled; }).length, 2)
        const off = cell(tp, "10", "hour")
        verify(off !== null)
        const label = off.children.filter(function (c) { return c.text !== undefined; })[0]
        compare(label.color, Theme.current.colorDisabledText)
        tp.destroy()
    }

    function test_hideDisabledOptionsDropsRows() {
        // 禁用 03 / 04 并整列隐藏：这两格根本不存在，但同屏的 05 还在，
        // 免得「找不到」是因为它本来就滚出视口了
        const tp = make('TimePicker { defaultOpen: true; format: "HH:mm"; hideDisabledOptions: true;'
            + ' defaultValue: "05:00"; disabledHours: function(){ return [3, 4]; } }')
        openAndGet(tp)
        compare(panel(tp, 0).hourItems.length, 22)
        compare(cell(tp, "03", "hour"), null)
        compare(cell(tp, "04", "hour"), null)
        verify(cell(tp, "05", "hour") !== null)
        tp.destroy()
    }

    function test_unitSuffixOnlyOnSelectedRow() {
        const tp = make("TimePicker { defaultOpen: true; format: \"HH:mm:ss\"; defaultValue: \"10:24:00\" }")
        openAndGet(tp)
        compare(texts(cell(tp, "10", "hour")), ["10时"])
        compare(texts(cell(tp, "24", "minute")), ["24分"])
        compare(texts(cell(tp, "00", "second")), ["00秒"])
        // 没选中的那几格不带后缀
        compare(texts(cell(tp, "11", "hour")), ["11"])
        tp.destroy()
    }

    function test_panelHeaderAndFooterText() {
        const tp = make("TimePicker { defaultOpen: true; panelHeader: \"Time Select\"; panelFooter: \"底部\" }")
        openAndGet(tp)
        const p = panel(tp, 0)
        compare(texts(p).indexOf("Time Select") >= 0, true)
        compare(texts(p).indexOf("底部") >= 0, true)
        compare(p.height, 252 + p.headerHeight + p.footerHeight)
        tp.destroy()
    }

    function test_rangeHeaderArraysPerPanel() {
        const tp = make('TimePicker { defaultOpen: true; type: "timeRange"; panelHeader: ["start header", "end header"] }')
        openAndGet(tp)
        compare(texts(panel(tp, 0)).indexOf("start header") >= 0, true)
        compare(texts(panel(tp, 0)).indexOf("end header") >= 0, false)
        compare(texts(panel(tp, 1)).indexOf("end header") >= 0, true)
        tp.destroy()
    }

    // ---- 点选 ----

    function test_clickMinuteCellCommitsAndEmits() {
        const tp = make('TimePicker { format: "HH:mm:ss"; defaultValue: "10:24:00" }')
        const seen = []
        tp.changed.connect(function (date, text) { seen.push([date, text]); })
        openAndGet(tp)
        mouseClick(cell(tp, "26", "minute"), 32, 18)
        tryVerify(function () { return seen.length === 1; })
        compare(seen[0][1], "10:26:00")
        compare(seen[0][0].getHours(), 10)
        compare(seen[0][0].getMinutes(), 26)
        compare(tp.displayText, "10:26:00")
        tp.destroy()
    }

    function test_clickDoesNotCloseThePanel() {
        // 官方选完不收弹层，点外面 / Esc 才关
        const tp = make('TimePicker { format: "HH:mm"; defaultValue: "10:24" }')
        openAndGet(tp)
        mouseClick(cell(tp, "26", "minute"), 32, 18)
        tryCompare(tp, "displayText", "10:26")
        compare(tp._popup.isOpen, true)
        tp.destroy()
    }

    function test_clickHourCellIn12HourModeMapsTo24() {
        const tp = make('TimePicker { use12Hours: true; defaultValue: "下午 1:00:00" }')
        openAndGet(tp)
        mouseClick(cell(tp, "03", "hour"), 32, 18)
        tryCompare(tp, "displayText", "下午 3:00:00")
        compare(tp.dateAt(0).getHours(), 15)
        tp.destroy()
    }

    function test_clickMeridiemShiftsNoon() {
        const tp = make('TimePicker { use12Hours: true; defaultValue: "下午 1:00:00" }')
        openAndGet(tp)
        mouseClick(cell(tp, "上午", "ampm"), 36, 18)
        tryCompare(tp, "displayText", "上午 1:00:00")
        compare(tp.dateAt(0).getHours(), 1)
        tp.destroy()
    }

    function test_clickDisabledCellDoesNothing() {
        const tp = make('TimePicker { format: "HH:mm"; defaultValue: "09:30";'
            + ' disabledHours: function(){ return [10, 11]; } }')
        const seen = []
        tp.changed.connect(function (date, text) { seen.push(text); })
        openAndGet(tp)
        const off = cell(tp, "10", "hour")
        verify(off !== null)
        mouseClick(off, 32, 18)
        wait(120)
        compare(seen.length, 0)
        compare(tp.displayText, "09:30")
        tp.destroy()
    }

    function test_clickRightRangePanelOnlyMovesThatHalf() {
        const tp = make('TimePicker { type: "timeRange"; defaultValue: ["10:23:15", "12:38:32"] }')
        openAndGet(tp)
        mouseClick(cell(tp, "40", "minute", 1), 32, 18)
        tryCompare(tp, "displayText", "10:23:15 ~ 12:40:32")
        tp.destroy()
    }

    function test_rangeDisabledTimeAppliesPerPanel() {
        const tp = make('TimePicker { type: "timeRange"; defaultValue: ["08:00:00", "16:00:00"];'
            + ' disabledTime: function (value, panelType) {'
            + '     return panelType === "right"'
            + '         ? ({ disabledHours: function () { return [16, 17]; } })'
            + '         : ({ disabledHours: function () { return [8]; } }); } }')
        openAndGet(tp)
        compare(panel(tp, 1).disabledHoursFn().length, 2)
        compare(panel(tp, 0).disabledHoursFn().length, 1)
        compare(panel(tp, 1).hourItems.filter(function (o) { return o.disabled; }).length, 2)
        compare(panel(tp, 0).hourItems.filter(function (o) { return o.disabled; }).length, 1)
        tp.destroy()
    }

    // ---- wheel / cycled ----

    function test_wheelModeIgnoresClicksAndShowsBand() {
        const tp = make('TimePicker { scrollItemProps: ({ mode: "wheel", cycled: true });'
            + ' defaultValue: "10:24:00" }')
        const seen = []
        tp.changed.connect(function (date, text) { seen.push(text); })
        openAndGet(tp)
        const col = column(tp, "hour")
        verify(one(tp, "wheelBand") !== null)
        compare(col.wheel, true)
        // wheel 模式官方不给点选（scrollItem.tsx:438），点了也不提交
        mouseClick(cell(tp, "12", "hour"), 32, 18)
        wait(120)
        compare(seen.length, 0)
        compare(tp.displayText, "10:24:00")
        tp.destroy()
    }

    function test_cycledModelRepeatsThreeTimes() {
        const tp = make('TimePicker { defaultOpen: true; defaultValue: "10:24:00";'
            + ' scrollItemProps: ({ mode: "wheel", cycled: true }) }')
        openAndGet(tp)
        const col = column(tp, "hour")
        compare(col.cycled, true)
        compare(col.listModel.length, 24 * 3)
        compare(col.selectedIndex, 10)
        compare(col.realIndexOf(24 + 3), 3)
        tp.destroy()
    }

    function test_normalModeIsNotCycled() {
        const tp = make("TimePicker { defaultOpen: true }")
        openAndGet(tp)
        const col = column(tp, "hour")
        compare(col.cycled, false)
        compare(col.listModel.length, 24)
        tp.destroy()
    }

    // ---- 清除 ----

    function test_clearButtonEmitsEmpty() {
        const tp = make('TimePicker { defaultValue: "10:24:00" }')
        const seen = []
        tp.changed.connect(function (date, text) { seen.push(text); })
        const input = focusField(tp)
        const clearBtn = walk(input, "clearBtn")[0]
        verify(clearBtn !== null)
        compare(clearBtn.visible, true)
        // RowLayout 的排布是异步 polish 的，高度还没算出来就点会点空
        tryVerify(function () { return clearBtn.height > 0; })
        mouseClick(clearBtn, clearBtn.width / 2, clearBtn.height / 2)
        tryVerify(function () { return seen.length === 1; })
        compare(seen[0], "")
        compare(tp.displayText, "")
        compare(tp.hasValue, false)
        tp.destroy()
    }

    function test_showClearFalseHidesTheButton() {
        const tp = make('TimePicker { defaultValue: "10:24:00"; showClear: false }')
        const input = focusField(tp)
        compare(walk(input, "clearBtn")[0].visible, false)
        tp.destroy()
    }

    function test_disabledPickerHasNoClearButton() {
        const tp = make('TimePicker { defaultValue: "10:24:00"; disabled: true }')
        const input = inputOf(tp)
        compare(walk(input, "clearBtn")[0].visible, false)
        tp.destroy()
    }

    // ---- 敲字 ----

    function test_validTypedTextCommitsLive() {
        const tp = make('TimePicker { format: "HH:mm" }')
        const seen = []
        tp.changed.connect(function (date, text) { seen.push(text); })
        const input = focusField(tp)
        typeOver(input, "10:24")
        tryVerify(function () { return seen.length === 1; })
        compare(seen[0], "10:24")
        compare(input.text, "10:24")
        compare(tp.dateAt(0).getHours(), 10)
        tp.destroy()
    }

    function test_partialTypedTextDoesNotCommitYet() {
        const tp = make('TimePicker { format: "HH:mm"; defaultValue: "09:30" }')
        const seen = []
        tp.changed.connect(function (date, text) { seen.push(text); })
        const input = focusField(tp)
        typeOver(input, "10:2")
        tryCompare(tp, "displayText", "10:2")
        wait(200)
        // 位数没敲够 → isTimeFormatLike 挡在 parse 之前，既不提交也不报错
        compare(seen.length, 0)
        compare(tp._invalid, false)
        compare(input.validateStatus, Enums.StatusDefault)
        compare(tp.dateAt(0).getMinutes(), 30)
        tp.destroy()
    }

    function test_unparseableTypedTextShowsError() {
        const tp = make('TimePicker { format: "HH:mm"; defaultValue: "09:30" }')
        const seen = []
        tp.changed.connect(function (date, text) { seen.push(text); })
        const input = focusField(tp)
        typeOver(input, "99:99")
        wait(200)
        compare(seen.length, 0)
        // 位数够了但解不出来 → TimeInput.tsx:166 的 mergeValidateStatus 标成 error
        compare(tp._invalid, true)
        compare(input.validateStatus, Enums.StatusDanger)
        compare(tp.dateAt(0).getHours(), 9)
        tp.destroy()
    }

    function test_blurDiscardsUnparsedText() {
        const tp = make('TimePicker { format: "HH:mm"; defaultValue: "09:30" }')
        const input = focusField(tp)
        typeOver(input, "10:2")
        tryCompare(tp, "displayText", "10:2")
        stealFocus(tp)
        tryCompare(tp, "displayText", "09:30")
        compare(tp.dateAt(0).getHours(), 9)
        compare(tp._invalid, false)
        tp.destroy()
    }

    function test_blurWithEmptyTextClearsValue() {
        const tp = make('TimePicker { format: "HH:mm"; defaultValue: "09:30" }')
        const seen = []
        tp.changed.connect(function (date, text) { seen.push(text); })
        const input = focusField(tp)
        input.input.selectAll()
        keyClick(Qt.Key_Backspace)
        tryCompare(tp, "displayText", "")
        stealFocus(tp)
        tryVerify(function () { return seen.length === 1; })
        compare(seen[0], "")
        compare(tp.hasValue, false)
        tp.destroy()
    }

    function test_typedDisabledTimeIsRejected() {
        const tp = make('TimePicker { format: "HH:mm"; defaultValue: "09:30";'
            + ' disabledHours: function(){ return [10]; } }')
        const seen = []
        tp.changed.connect(function (date, text) { seen.push(text); })
        const input = focusField(tp)
        typeOver(input, "10:30")
        wait(150)
        compare(seen.length, 0)
        compare(tp._invalid, true)
        tp.destroy()
    }

    // ---- 开合 ----

    function test_disabledPickerDoesNotOpen() {
        const tp = make("TimePicker { disabled: true }")
        tp.openPanel()
        wait(150)
        compare(tp._popup.isOpen, false)
        tp.destroy()
    }

    function test_openChangeEmittedWhenUncontrolledOpens() {
        const tp = make("TimePicker { }")
        const seen = []
        tp.openChange.connect(function (isOpen) { seen.push(isOpen); })
        openAndGet(tp)
        compare(seen, [true])
        tp.closePanel()
        tryCompare(tp._popup, "isOpen", false)
        compare(seen, [true, false])
        tp.destroy()
    }

    function test_controlledOpenStaysOpenOnOutsidePress() {
        const tp = make("TimePicker { open: true }")
        tryVerify(function () { return tp._popup.isOpen; })
        // 受控时弹层不能自己关（官方 visible 完全由外部决定），点外面只发 openChange
        const seen = []
        tp.openChange.connect(function (isOpen) { seen.push(isOpen); })
        mouseClick(testCase, 860, 860)
        wait(200)
        compare(tp._popup.isOpen, true)
        compare(seen.length, 0)
        tp.destroy()
    }

    function test_controlledOpenFalseKeepsItShut() {
        const tp = make("TimePicker { open: false }")
        tp.openPanel()
        wait(150)
        compare(tp._popup.isOpen, false)
        tp.destroy()
    }

    function test_focusOpensThePanel() {
        const tp = make("TimePicker { }")
        focusField(tp)
        tryVerify(function () { return tp._popup.isOpen; })
        tp.destroy()
    }

    function test_triggerRenderReceivesPlaceholderAndOpens() {
        const tp = make('TimePicker {\n'
            + '    triggerRender: Component {\n'
            + '        Item {\n'
            + '            objectName: "customTrigger"\n'
            + '            property var placeholder: ""\n'
            + '            Text { objectName: "triggerText"; text: String(parent.placeholder) }\n'
            + '        }\n'
            + '    }\n'
            + '}')
        const label = walk(tp, "triggerText")[0]
        verify(label !== null)
        compare(label.text, "请选择时间")
        mouseClick(label, 4, 4)
        tryVerify(function () { return tp._popup.isOpen; })
        tp.destroy()
    }

    function test_defaultOpenShowsThePanel() {
        const tp = make("TimePicker { defaultOpen: true }")
        openAndGet(tp)
        compare(tp._popup.isOpen, true)
        verify(one(tp, "column-hour") !== null)
        tp.destroy()
    }
}
