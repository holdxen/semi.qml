import QtQuick
import QtTest
import Semi
import "../src/CalendarDate.js" as CD
import "../src/DateFormat.js" as DF

// 日期选择器：格式引擎 + 面板几何 + 选择行为。
// 断言尽量落在渲染出来的东西上（面板与色带的实际宽高/颜色、信号收到的值），
// 而不是组件内部的中间属性。
TestCase {
    id: testCase

    name: "DatePicker"
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

    // 弹层打开后会被重 parent 到窗口的 overlay 上，只能从 dp._popup 往下找
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

    function findAll(dp, name) {
        return walk(dp._popup.contentItem, name)
    }

    function one(dp, name) {
        const found = findAll(dp, name)
        return found.length > 0 ? found[0] : null
    }

    // 凡是往弹层里 mouseClick 的用例都依赖「弹层已经能收事件」再返回。
    function openAndGet(dp) {
        dp.openPanel()
        // 入场动画 opacity 只走 50ms、scale 走满 100ms：只等 opacity 会在弹层还在放大时
        // 就点，落点差 1-2px 会点到按钮外，偶发点空
        tryVerify(function () {
            return dp._popup.isOpen && dp._popup.opacity > 0.99 && Math.abs(dp._popup.scale - 1) < 1e-4
        })
        return dp._popup
    }

    function grid(dp, index) {
        const grids = findAll(dp, "dateMonthGrid")
        return grids.length > index ? grids[index] : null
    }

    function band(dp, text) {
        return one(dp, "dayBand-" + text)
    }

    function day(y, m, d) {
        return new Date(y, m, d)
    }

    // ---- 格式引擎 ----

    function test_defaultFormatFollowsType() {
        compare(DF.defaultFormatToken("date"), "yyyy-MM-dd")
        compare(DF.defaultFormatToken("dateRange"), "yyyy-MM-dd")
        compare(DF.defaultFormatToken("dateTime"), "yyyy-MM-dd HH:mm:ss")
        compare(DF.defaultFormatToken("dateTimeRange"), "yyyy-MM-dd HH:mm:ss")
        compare(DF.defaultFormatToken("month"), "yyyy-MM")
        compare(DF.defaultFormatToken("monthRange"), "yyyy-MM")
    }

    function test_timeFormatPicksOnlyUsedTokens() {
        compare(DF.timeFormatOf("yyyy-MM-dd HH:mm:ss"), "HH:mm:ss")
        compare(DF.timeFormatOf("yyyy-MM-dd HH:mm"), "HH:mm")
        compare(DF.timeFormatOf("yyyy-MM-dd"), "")           // 没有时间位就没有时间列
        compare(DF.timeFormatOf(""), "HH:mm:ss")
        verify(DF.hasTimeToken("yyyy-MM-dd HH:mm"))
        verify(!DF.hasTimeToken("yyyy-MM-dd"))
    }

    function test_formatHonoursChineseAndSingleLetterTokens() {
        const d = day(2026, 9, 5)
        compare(DF.format(d, "yyyy-MM-dd"), "2026-10-05")
        compare(DF.format(d, "yyyy年MM月dd日"), "2026年10月05日")
        compare(DF.format(d, "yyyy-M-d"), "2026-10-5")
        compare(DF.format(d, "HH:mm"), "00:00")
    }

    function test_parseRejectsImpossibleDates() {
        verify(DF.parse("2026-02-30", "yyyy-MM-dd") === null)
        verify(DF.parse("2026-13-01", "yyyy-MM-dd") === null)
        verify(DF.parse("2026-10-05 25:00", "yyyy-MM-dd HH:mm") === null)
        const ok = DF.parse("2026-10-05 08:30", "yyyy-MM-dd HH:mm")
        verify(ok !== null)
        compare(ok.getHours(), 8)
        compare(ok.getMinutes(), 30)
    }

    function test_rangeAndMultipleJoining() {
        compare(DF.formatRange(day(2026, 9, 5), day(2026, 9, 9), "yyyy-MM-dd", " ~ "),
            "2026-10-05 ~ 2026-10-09")
        compare(DF.formatMultiple([day(2026, 9, 5), day(2026, 9, 9)], "yyyy-MM-dd"),
            "2026-10-05,2026-10-09")
    }

    function test_addMonthsClampsToMonthEnd() {
        // date-fns 的语义：1月31日 +1 月 = 2月28日，不滚到 3 月
        compare(CD.addMonths(day(2026, 0, 31), 1).getDate(), 28)
        compare(CD.addMonths(day(2026, 0, 31), 1).getMonth(), 1)
        compare(CD.addMonths(day(2026, 9, 15), -12).getFullYear(), 2025)
        verify(CD.isBefore(day(2026, 9, 1), day(2026, 9, 2)))
        verify(CD.isAfter(day(2026, 9, 2), day(2026, 9, 1)))
    }

    // ---- 面板几何 ----

    function test_panelSizeForSixRowMonth() {
        // 2026 年 8 月 1 日是周六 -> 6 行：导航 32+24 + 16 + 星期行 36 + 1 + 6*36 = 325
        const dp = make("DatePicker { value: '2026-08-15' }")
        const popup = openAndGet(dp)
        compare(popup.width, 284)
        compare(popup.height, 325)
        compare(grid(dp, 0).rowCount, 6)
        dp.destroy()
    }

    function test_panelSizeForFourRowMonth() {
        // 2026 年 2 月 1 日是周日、28 天 -> 4 行
        const dp = make("DatePicker { value: '2026-02-10' }")
        const popup = openAndGet(dp)
        compare(popup.width, 284)
        compare(popup.height, 253)
        compare(grid(dp, 0).rowCount, 4)
        dp.destroy()
    }

    function test_rangePanelIsTwoColumnsWideAndTallestRowWins() {
        // 左栏 2026-02（4 行）、右栏 2026-03（5 行）-> 两栏都按 5 行画
        const dp = make("DatePicker { type: Enums.TypeDateRange; value: "
            + "['2026-02-10', '2026-03-20'] }")
        const popup = openAndGet(dp)
        compare(popup.width, 568)
        compare(grid(dp, 0).rowCount, 5)
        compare(grid(dp, 1).rowCount, 5)
        compare(grid(dp, 0).height, grid(dp, 1).height)
        dp.destroy()
    }

    function test_compactDensityGeometry() {
        const dp = make("DatePicker { value: '2026-08-15'; density: Enums.DensityCompact }")
        const popup = openAndGet(dp)
        compare(grid(dp, 0).cellSize, 28)
        compare(popup.width, 236)
        dp.destroy()
    }

    function test_yamPanelWidths() {
        const month = make("DatePicker { type: Enums.TypeMonth }")
        const monthPopup = openAndGet(month)
        compare(monthPopup.width, 165)
        compare(monthPopup.height, 266)
        month.destroy()

        const range = make("DatePicker { type: Enums.TypeMonthRange; value: "
            + "['2026-03', '2026-08'] }")
        const rangePopup = openAndGet(range)
        compare(rangePopup.width, 331)
        compare(rangePopup.height, 266)
        // 右栏停在区间的第二个月，不是左栏 +1
        const panels = findAll(range, "dateYearMonthPanel")
        compare(panels.length, 2)
        compare(panels[0].pickerDate.getMonth(), 2)
        compare(panels[1].pickerDate.getMonth(), 7)
        range.destroy()
    }

    function test_timePanelColumnsFollowFormat() {
        const dp = make("DatePicker { type: Enums.TypeDateTime; value: '2026-10-05 08:30:00' }")
        openAndGet(dp)
        const hidden = one(dp, "dateTimeColumns")
        verify(hidden !== null && !hidden.visible)                // 默认停在日期视图
        dp.handleNav(0, "openTime")
        tryVerify(function () { return one(dp, "dateTimeColumns").visible })
        const time = one(dp, "dateTimeColumns")
        compare(time.columns.length, 3)                       // HH:mm:ss 三列
        compare(time.hourItems.length, 24)
        compare(time.minuteItems.length, 60)
        dp.destroy()
    }

    // ---- 选择行为 ----

    function test_dayClickEmitsAndClosesForDate() {
        const dp = make("DatePicker { }")
        let date = undefined
        let text = undefined
        dp.changed.connect(function (d, s) { date = d; text = s })
        const popup = openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 5))
        verify(date instanceof Date)
        compare(date.getDate(), 5)
        compare(text, "2026-10-05")
        tryVerify(function () { return !popup.isOpen })
        dp.destroy()
    }

    function test_dayClickKeepsPanelOpenForDateTime() {
        const dp = make("DatePicker { type: Enums.TypeDateTime }")
        const popup = openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 5))
        compare(dp.displayDates.length, 1)
        compare(dp.displayDates[0].getDate(), 5)
        wait(150)
        verify(popup.isOpen)                                  // 官方只在 date 类型选完就关
        dp.destroy()
    }

    function test_rangeNeedsTwoClicksAndSwapsOrder() {
        const dp = make("DatePicker { type: Enums.TypeDateRange }")
        const texts = []
        dp.changed.connect(function (d, s) { texts.push(s) })
        openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 20))                 // 第一下只落起点
        compare(texts.length, 0)
        verify(dp._rangeSelecting)
        dp.handleDayClicked(day(2026, 9, 5))                  // 第二下在前 -> 交换
        compare(texts.length, 1)
        compare(texts[0], "2026-10-05 ~ 2026-10-20")
        dp.destroy()
    }

    function test_rangeBandColorsOnRenderedCells() {
        // 探针日期必须是**过去的月份**：原值（2026-10-05~22，探针 10-23）在 2026-10-23
        // 这一天正好撞上「after = 今天」，cellBackground() 走 isToday 分支涂 colorFill0、
        // 透明断言只在这一天必红。过去月永不再成为今天。
        const dp = make("DatePicker { type: Enums.TypeDateRange; value: "
            + "['2025-03-05', '2025-03-22'] }")
        openAndGet(dp)
        const start = band(dp, "2025-03-05")
        const middle = band(dp, "2025-03-10")
        const after = band(dp, "2025-03-23")
        verify(start !== null && middle !== null && after !== null)
        compare(start.color, Theme.current.colorPrimary)
        compare(middle.color, Theme.current.colorPrimaryLightDefault)
        compare(after.color, Qt.color("transparent"))
        compare(middle.width, middle.parent.width)             // 色带铺满整格
        compare(band(dp, "2025-04-10").color, Qt.color("transparent"))   // 右栏不被染色
        dp.destroy()
    }

    function test_multipleAccumulatesAndMaxCaps() {
        const dp = make("DatePicker { multiple: true; max: 2 }")
        let count = 0
        dp.changed.connect(function (d, s) { count = d.length })
        openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 5))
        compare(count, 1)
        dp.handleDayClicked(day(2026, 9, 6))
        compare(count, 2)
        dp.handleDayClicked(day(2026, 9, 7))                   // 超上限：官方静默不选
        compare(count, 2)
        dp.handleDayClicked(day(2026, 9, 5))                   // 再点已选的是取消
        compare(count, 1)
        dp.destroy()
    }

    function test_disabledDateBlocksClick() {
        const dp = make("DatePicker { disabledDate: (d) => d.getDate() === 5 }")
        let fired = 0
        dp.changed.connect(function () { fired++ })
        openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 5))
        compare(fired, 0)
        dp.handleDayClicked(day(2026, 9, 6))
        compare(fired, 1)
        compare(band(dp, "2026-10-05").color, Qt.color("transparent"))
        dp.destroy()
    }

    function test_needConfirmStagesUntilConfirm() {
        const dp = make("DatePicker { type: Enums.TypeDateTime; needConfirm: true }")
        let changed = 0
        let confirmed = 0
        dp.changed.connect(function () { changed++ })
        dp.confirmed.connect(function () { confirmed++ })
        const popup = openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 5))
        compare(changed, 0)                                   // 还没确认，不外发
        verify(dp._pending !== null)
        verify(popup.isOpen)
        dp.handleConfirm()
        compare(changed, 1)
        compare(confirmed, 1)
        tryVerify(function () { return !popup.isOpen })
        dp.destroy()
    }

    function test_cancelEmitsPreviousValue() {
        const dp = make("DatePicker { type: Enums.TypeDateTime; needConfirm: true; "
            + "value: '2026-10-01 00:00:00' }")
        let seen = ""
        dp.cancelled.connect(function (d, s) { seen = s })
        dp.changed.connect(function (d, s) { seen = "changed:" + s })
        openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 5))
        dp.handleCancel()
        compare(seen, "2026-10-01 00:00:00")
        dp.destroy()
    }

    function test_clearEmitsClearedAndEmpty() {
        const dp = make("DatePicker { defaultValue: '2026-10-05' }")
        let cleared = 0
        let text = "x"
        dp.cleared.connect(function () { cleared++ })
        dp.changed.connect(function (d, s) { text = s })
        dp.clear()
        compare(cleared, 1)
        compare(text, "")
        verify(dp.displayDates.length === 0 || dp.displayDates[0] === null)
        dp.destroy()
    }

    function test_presetClickSetsRangeAndSignals() {
        const dp = make("DatePicker { type: Enums.TypeDateRange; presets: "
            + "[{ text: '两天', start: new Date(2026, 9, 5), end: new Date(2026, 9, 6) }] }")
        let clicked = ""
        let text = ""
        dp.presetClicked.connect(function (item) { clicked = item.text })
        dp.changed.connect(function (d, s) { text = s })
        openAndGet(dp)
        // 四个方位各有一个 DateQuickControl，只有当前方位那排是可见的
        const buttons = findAll(dp, "presetButton").filter(function (b) { return b.visible })
        compare(buttons.length, 1)
        mouseClick(buttons[0])
        compare(clicked, "两天")
        compare(text, "2026-10-05 ~ 2026-10-06")
        dp.destroy()
    }

    function test_controlledValueDoesNotSelfChange() {
        const dp = make("DatePicker { value: '2026-10-05' }")
        openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 20))
        compare(dp.value, "2026-10-05")                       // 受控值不由组件自己改
        compare(dp.displayDates[0].getDate(), 5)              // 面板显示仍是外部给的值
        dp.destroy()
    }

    function test_uncontrolledValueUpdatesAfterClick() {
        const dp = make("DatePicker { }")
        openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 20))
        compare(dp.displayDates[0].getDate(), 20)
        compare(dp.singleText, "2026-10-20")
        dp.destroy()
    }

    function test_weekStartsOnOffsetSelectsWholeWeek() {
        // 2026-10-07 是周三；周一为起点 -> 区间 10-05 ~ 10-11
        const dp = make("DatePicker { type: Enums.TypeDateRange; weekStartsOn: 1; "
            + "startDateOffset: (d) => new Date(d.getFullYear(), d.getMonth(), "
            + "d.getDate() - (d.getDay() + 6) % 7); "
            + "endDateOffset: (d) => new Date(d.getFullYear(), d.getMonth(), "
            + "d.getDate() + (7 - d.getDay()) % 7) }")
        let text = ""
        dp.changed.connect(function (d, s) { text = s })
        openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 7))
        compare(text, "2026-10-05 ~ 2026-10-11")
        dp.destroy()
    }

    function test_syncSwitchMonthShiftsBothPanels() {
        // 间隔三个月的两栏，同步翻月要保持这个间隔（不同步时右栏不动）
        const dp = make("DatePicker { type: Enums.TypeDateRange; syncSwitchMonth: true; "
            + "value: ['2026-10-05', '2027-01-20'] }")
        openAndGet(dp)
        compare(grid(dp, 0).pickerDate.getMonth(), 9)
        compare(grid(dp, 1).pickerDate.getMonth(), 0)
        dp.handleNav(0, "nextMonth")
        compare(grid(dp, 0).pickerDate.getMonth(), 10)
        compare(grid(dp, 1).pickerDate.getMonth(), 1)
        dp.destroy()
    }

    function test_plainRangePanelsShiftIndependently() {
        const dp = make("DatePicker { type: Enums.TypeDateRange; value: "
            + "['2026-10-05', '2027-01-20'] }")
        openAndGet(dp)
        dp.handleNav(0, "nextMonth")
        compare(grid(dp, 0).pickerDate.getMonth(), 10)
        compare(grid(dp, 1).pickerDate.getMonth(), 0)   // 右栏没跟着走
        dp.destroy()
    }

    function test_panelChangeFiresOnMonthSwitch() {
        const dp = make("DatePicker { type: Enums.TypeDateRange; value: "
            + "['2026-10-05', '2026-11-20'] }")
        let lastText = ""
        dp.panelChanged.connect(function (d, s) { lastText = String(s) })
        openAndGet(dp)
        dp.handleNav(0, "prevMonth")
        verify(lastText.indexOf("2026-09") >= 0)
        dp.destroy()
    }

    function test_autoSwitchDateMovesSelectedDay() {
        const dp = make("DatePicker { value: '2026-10-31'; autoSwitchDate: true }")
        let text = ""
        dp.changed.connect(function (d, s) { text = s })
        openAndGet(dp)
        dp.handleNav(0, "nextMonth")              // 11 月没有 31 号 -> 夹到 30
        compare(text, "2026-11-30")
        dp.destroy()
    }

    function test_needConfirmIgnoresPressOutside() {
        const dp = make("DatePicker { type: Enums.TypeDateTime; needConfirm: true; "
            + "defaultValue: '2026-10-05 08:30:00' }")
        const popup = openAndGet(dp)
        dp.handleDayClicked(day(2026, 9, 20))
        // 面板外空白处点一下：官方开启确认后不再点外关闭，只能按「取消」
        mouseClick(testCase, 860, 860)
        wait(200)
        verify(popup.isOpen)
        dp.handleCancel()
        tryVerify(function () { return !popup.isOpen })
        dp.destroy()
    }

    function test_plainPickerClosesOnPressOutside() {
        const dp = make("DatePicker { }")
        const popup = openAndGet(dp)
        mouseClick(testCase, 860, 860)
        tryVerify(function () { return !popup.isOpen })
        dp.destroy()
    }

    function test_presetPositionLeftRendersOneSideColumn() {
        const dp = make("DatePicker { type: Enums.TypeDateRange; presetPosition: Enums.PresetLeft; "
            + "presets: [{ text: 'A', start: new Date(2026, 9, 5), end: new Date(2026, 9, 6) }, "
            + "{ text: 'B', start: new Date(2026, 9, 7), end: new Date(2026, 9, 8) }] }")
        const popup = openAndGet(dp)
        const visible = findAll(dp, "presetButton").filter(function (b) { return b.visible })
        compare(visible.length, 2)                       // 只有左侧那一排在渲染
        compare(popup.width, 568 + 200)                  // 面板 + 左右方位快捷面板 200
        dp.destroy()
    }

    // 左右方位那 14px 是内容 wrapper 的 margin-top（官方 -left-content-wrapper），
    // 落在 overflow 容器**里面**就会吃掉一格的高度，按钮会被裁掉半截。
    function test_sidePresetButtonsAreNotClipped() {
        const dp = make("DatePicker { type: Enums.TypeDateTime; presetPosition: Enums.PresetLeft; "
            + "presets: [{ text: 'Today', start: new Date(2026, 9, 1), end: new Date(2026, 9, 1) }, "
            + "{ text: 'Tomorrow', start: new Date(2026, 9, 2), end: new Date(2026, 9, 2) }, "
            + "{ text: 'Next week', start: new Date(2026, 9, 8), end: new Date(2026, 9, 8) }] }")
        openAndGet(dp)
        const clipper = one(dp, "quickControlClipper")
        verify(clipper !== null)
        const buttons = findAll(dp, "presetButton").filter(function (b) { return b.visible })
        compare(buttons.length, 3)
        compare(clipper.height, 24 * 2 + 8)              // 两行：24×2 + 行距 8
        // 标题与第一格之间是 wrapper 的 margin-top 14
        const title = one(dp, "quickControlTitle")
        const tBottom = title.y + title.height
        const firstTop = buttons[0].mapToItem(clipper.parent, 0, 0).y
        compare(Math.round(firstTop - tBottom), 14)
        for (let i = 0; i < buttons.length; ++i) {
            const p = buttons[i].mapToItem(clipper, 0, 0)
            // 排布结果是浮点的，留半像素容差
            verify(p.y >= -0.5, buttons[i].text + " 顶部被裁: " + p.y)
            verify(p.y + buttons[i].height <= clipper.height + 0.5,
                buttons[i].text + " 底部被裁: " + (p.y + buttons[i].height) + " > " + clipper.height)
        }
        dp.destroy()
    }

    function test_disabledDoesNotOpen() {
        const dp = make("DatePicker { disabled: true }")
        dp.openPanel()
        wait(150)
        verify(!dp.panelOpen)
        dp.destroy()
    }

    function test_openChangeFiresBothWays() {
        const dp = make("DatePicker { }")
        const seen = []
        dp.openChange.connect(function (isOpen) { seen.push(isOpen) })
        openAndGet(dp)
        dp.closePanel()
        tryVerify(function () { return seen.length >= 2 })
        verify(seen[0])
        verify(!seen[seen.length - 1])
        dp.destroy()
    }

    function test_controlledOpenPropDrivesPanel() {
        const dp = make("DatePicker { open: false }")
        const requested = []
        dp.openChange.connect(function (isOpen) { requested.push(isOpen) })
        dp.openPanel()
        wait(150)
        compare(requested.length, 1)                        // 只通知，不自己开
        verify(!dp.panelOpen)
        dp.open = true
        tryVerify(function () {
            const popup = dp._popup
            return popup !== null && popup.isOpen
        })
        dp.destroy()
    }

    // ---- 触发器形态 ----

    function test_monthRangeUsesSingleInputWithJoinedPlaceholder() {
        const dp = make("DatePicker { type: Enums.TypeMonthRange }")
        verify(!dp.isMultiInputRange)
        compare(dp.triggerPlaceholder, "开始月份~结束月份")
        dp.destroy()
    }

    function test_rangeUsesTwoInputsAndLocalePlaceholders() {
        const dp = make("DatePicker { type: Enums.TypeDateRange; width: 300 }")
        verify(dp.isMultiInputRange)
        compare(dp.placeholderAt(0), "开始日期")
        compare(dp.placeholderAt(1), "结束日期")
        openAndGet(dp)
        dp.destroy()
    }

    function test_customFormatUsedInTriggerText() {
        const dp = make("DatePicker { format: 'yyyy年MM月dd日'; value: '2026-10-05' }")
        compare(dp.singleText, "2026年10月05日")
        dp.destroy()
    }

    function test_triggerRenderHidesDefaultBox() {
        const dp = make("DatePicker { triggerRender: Component { "
            + "Item { property var placeholder; objectName: 'customTrigger'; "
            + "width: 100; height: 32 } } }")
        const boxes = walk(dp, "triggerBox")
        compare(boxes.length, 1)
        verify(!boxes[0].visible)                // 官方：自定义触发器时不画默认框
        wait(60)
        verify(walk(dp, "customTrigger").length === 1)
        dp.destroy()
    }

    // 后缀图标的右内缩，官方两种形态本来就不一样：
    // 单输入框走 .semi-input-suffix-icon（margin 0 8），
    // 双输入框走 .semi-datepicker-range-input-suffix（padding 8 左 / 12 右）。
    function gapRightOfCalendar(dp) {
        const box = walk(dp, "triggerBox")[0]
        const icons = walk(dp, "calendarIcon").filter(function (i) { return i.visible })
        compare(icons.length, 1)
        const b = box.mapToItem(dp, 0, 0)
        const i = icons[0].mapToItem(dp, 0, 0)
        return Math.round(b.x + box.width - (i.x + icons[0].width))
    }

    function test_calendarIconInsetFollowsInputMode() {
        const single = make("DatePicker { width: 260 }")
        const singleSmall = make("DatePicker { width: 260; size: Enums.Small }")
        const month = make("DatePicker { width: 260; type: Enums.TypeMonth }")
        const monthRange = make("DatePicker { width: 340; type: Enums.TypeMonthRange }")
        const range = make("DatePicker { width: 340; type: Enums.TypeDateRange }")
        const rangeSmall = make("DatePicker { width: 340; type: Enums.TypeDateRange; size: Enums.Small }")
        const dateTimeRange = make("DatePicker { width: 340; type: Enums.TypeDateTimeRange }")
        wait(60)                                  // 位置是排布那一拍才定的

        compare(gapRightOfCalendar(single), 8)
        compare(gapRightOfCalendar(singleSmall), 8)
        compare(gapRightOfCalendar(month), 8)
        compare(gapRightOfCalendar(monthRange), 8)      // monthRange 官方也是单输入框
        compare(gapRightOfCalendar(range), 12)
        compare(gapRightOfCalendar(rangeSmall), 12)
        compare(gapRightOfCalendar(dateTimeRange), 12)

        single.destroy(); singleSmall.destroy(); month.destroy(); monthRange.destroy()
        range.destroy(); rangeSmall.destroy(); dateTimeRange.destroy()
    }

    function test_renderFullDateReceivesDayStatus() {
        const dp = make("DatePicker { type: Enums.TypeDateRange; value: "
            + "['2026-10-05', '2026-10-22']; renderFullDate: Component { "
            + "Rectangle { property var dayNumber; property var fullDate; "
            + "property var dayStatus; objectName: 'customDay'; width: 10; height: 10 } } }")
        openAndGet(dp)
        const cells = findAll(dp, "customDay")
        verify(cells.length > 0)
        const middle = cells.filter(function (c) { return c.fullDate === "2026-10-10" })
        compare(middle.length, 1)
        verify(middle[0].dayStatus.isInRange)
        verify(!middle[0].dayStatus.isSelected)
        verify(!band(dp, "2026-10-10").visible)       // 给了 renderFullDate 就不画默认色带
        dp.destroy()
    }

    function test_insetInputFieldOrder() {
        const single = make("DatePicker { type: Enums.TypeDateTime; insetInput: true }")
        openAndGet(single)
        const singleFields = single.insetFields()
        compare(singleFields.length, 2)
        compare(singleFields[0].kind, "dateStart")
        compare(singleFields[1].kind, "timeStart")
        single.destroy()

        const range = make("DatePicker { type: Enums.TypeDateTimeRange; insetInput: true }")
        openAndGet(range)
        const fields = range.insetFields()
        compare(fields.length, 4)
        compare(fields[0].kind, "dateStart")
        compare(fields[1].kind, "timeStart")
        compare(fields[2].kind, "dateEnd")
        compare(fields[2].separator, "-")
        compare(fields[3].kind, "timeEnd")
        range.destroy()
    }

    function test_insetInputValueKeepsOtherHalf() {
        const dp = make("DatePicker { type: Enums.TypeDateTime; insetInput: true; "
            + "defaultValue: '2026-10-05 08:30:00' }")
        openAndGet(dp)
        dp.applyInsetText("timeStart", "20:15:00")
        compare(dp.displayDates[0].getDate(), 5)          // 改时间不能把日期抹掉
        compare(dp.displayDates[0].getHours(), 20)
        compare(dp.displayDates[0].getMinutes(), 15)
        dp.applyInsetText("dateStart", "2026-12-25")
        compare(dp.displayDates[0].getMonth(), 11)
        compare(dp.displayDates[0].getHours(), 20)        // 改日期保留已选时间
        dp.destroy()
    }

    function test_yearMonthPanelPicksMonth() {
        // 年月两列各自一选就落值（官方 handleYMSelectedChange 每次 onSelect 都提交）
        const byMonth = make("DatePicker { type: Enums.TypeMonth; value: '2027-05' }")
        let text = ""
        byMonth.changed.connect(function (d, s) { text = s })
        openAndGet(byMonth)
        const panel = one(byMonth, "dateYearMonthPanel")
        verify(panel !== null)
        panel.monthPicked(3)
        compare(text, "2027-03")
        byMonth.destroy()

        const byYear = make("DatePicker { type: Enums.TypeMonth; value: '2027-05' }")
        let yearText = ""
        byYear.changed.connect(function (d, s) { yearText = s })
        openAndGet(byYear)
        one(byYear, "dateYearMonthPanel").yearPicked(2026)
        compare(yearText, "2026-05")
        byYear.destroy()
    }

    function test_yearMonthOverlayReturnsToDatePanel() {
        const dp = make("DatePicker { value: '2026-10-05' }")
        openAndGet(dp)
        dp.handleNav(0, "yam")
        const panel = one(dp, "dateYearMonthPanel")
        tryVerify(function () { return panel.visible })
        // 再点一次月份按钮要回到月历（官方是 toggle，不是只开不合）
        dp.handleNav(0, "yam")
        tryVerify(function () { return !panel.visible })
        dp.handleNav(0, "yam")
        tryVerify(function () { return panel.visible })
        panel.monthPicked(6)
        tryVerify(function () { return !panel.visible })
        compare(grid(dp, 0).pickerDate.getMonth(), 5)
        dp.destroy()
    }

    function test_sizeAffectsTriggerHeight() {
        const small = make("DatePicker { size: Enums.Small }")
        const def = make("DatePicker { }")
        const large = make("DatePicker { size: Enums.Large }")
        compare(small.implicitHeight, 24)
        compare(def.implicitHeight, 32)
        compare(large.implicitHeight, 40)
        small.destroy(); def.destroy(); large.destroy()
    }
}
