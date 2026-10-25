import QtQuick
import QtQuick.Controls as C
import QtTest
import Semi
import "../src/CalendarDate.js" as CalendarDate

TestCase {
    id: testCase

    name: "Calendar"
    when: windowShown
    width: 900
    height: 900

    property var lastClicked: null
    property int clickCount: 0
    property var lastMoreDay: null
    property int lastRemaining: -1
    property int moreCount: 0
    property int closeCount: 0

    // 卡片的 Popover 挂在窗口的 Overlay.overlay 上（src/PopupBase.qml:58），
    // 不在声明它的那个子树里 ⇒ 递归 children 要能从 overlay 起找。
    readonly property var overlay: C.Overlay.overlay

    // JS 里写不出 Component 字面量（createQmlObject 的串里 `children: Component {…}` 会解析歪），
    // 需要自定义节点的用例统一用这一份
    Component {
        id: eventKeyNode

        Text {
            property var event: null
            text: event === null ? "?" : event.key
        }
    }

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
        testCase.lastClicked = null
        testCase.clickCount = 0
        testCase.lastMoreDay = null
        testCase.lastRemaining = -1
        testCase.moreCount = 0
        testCase.closeCount = 0
    }

    // 失败的那条 compare 会把它后面的 c.destroy() 一起跳过 ⇒ 上一台的壳还留在
    // testCase 里跟下一台重叠，鼠标事件会同时点到叠着的好几个格子。每条测完清干净。
    function cleanup() {
        const leftovers = testCase.children.slice(0)
        for (let i = 0; i < leftovers.length; ++i)
            if (leftovers[i] !== null)
                leftovers[i].destroy()
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    function part(root, name) {
        if (root.objectName === name)
            return root
        for (let i = 0; i < root.children.length; ++i) {
            const found = testCase.part(root.children[i], name)
            if (found !== null)
                return found
        }
        return null
    }

    function findAll(root, name, out) {
        if (out === undefined)
            out = []
        if (root.objectName === name)
            out.push(root)
        for (let i = 0; i < root.children.length; ++i)
            testCase.findAll(root.children[i], name, out)
        return out
    }

    function countAll(root, name) {
        return testCase.findAll(root, name, []).length
    }

    function monthOf(calendar) {
        return testCase.part(calendar, "calendarMonth")
    }

    function gridOf(calendar) {
        return testCase.part(calendar, "calendarTimeGrid")
    }

    // 月视图第 row 周、第 col 列那个格子：Repeater 的代理按行主序排
    function dayCell(month, row, col) {
        return testCase.findAll(month, "calendarDayCell", [])[row * 7 + col]
    }

    function visibleBands(root, name) {
        return testCase.findAll(root, name, []).filter(function (b) { return b.visible })
    }

    // ==================== 文案 ====================

    function test_textHelpers() {
        compare(CalendarDate.weekdayName(new Date(2026, 9, 8)), "周四")
        compare(CalendarDate.weekdayName(new Date(2026, 9, 11)), "周日")
        compare(CalendarDate.monthLabel(new Date(2026, 9, 8)), "10月")
        compare(CalendarDate.dayNumber(new Date(2026, 9, 8)), "8")
        compare(CalendarDate.monthTitle(new Date(2026, 9, 8)), "2026年10月")
        compare(CalendarDate.remainingText(2), "还有2项")
        compare(CalendarDate.ALL_DAY_TEXT, "全天")
        compare(CalendarDate.DATE_SUFFIX, "日")
    }

    // ==================== 日期数学 ====================

    function test_monthGridShape() {
        // 2026-10-01 是周四，weekStartsOn = 0 → 前面补 4 天，共 5 行
        const weeks = CalendarDate.monthGrid(new Date(2026, 9, 1), 0)
        compare(weeks.length, 5)
        compare(weeks[0].length, 7)
        compare(weeks[0][0].date.getMonth(), 8)
        compare(weeks[0][0].date.getDate(), 27)
        compare(weeks[0][0].inMonth, false)
        compare(weeks[0][4].day, 1)
        compare(weeks[0][4].inMonth, true)
        compare(weeks[4][6].day, 31)
    }

    function test_monthGridExactlyFourWeeks() {
        // 2026-02-01 正好是周日，28 天，恰好 4 行
        const weeks = CalendarDate.monthGrid(new Date(2026, 1, 1), 0)
        compare(weeks.length, 4)
        compare(weeks[0][0].day, 1)
        compare(weeks[0][0].inMonth, true)
    }

    function test_monthGridSixWeeks() {
        // 2027-01-01 是周五，前面补 5 天 + 31 天 → 6 行
        const weeks = CalendarDate.monthGrid(new Date(2027, 0, 1), 0)
        compare(weeks.length, 6)
        compare(weeks[0][0].date.getDate(), 27)
        compare(weeks[0][0].inMonth, false)
    }

    function test_weekStartsOnRotatesTheGrid() {
        const weeks = CalendarDate.monthGrid(new Date(2026, 9, 1), 1)
        compare(weeks[0][0].date.getDay(), 1)
        compare(weeks[0][0].date.getDate(), 28)
        compare(CalendarDate.weekdayName(weeks[0][0].date), "周一")
    }

    function test_diffDays() {
        compare(CalendarDate.diffDays(new Date(2026, 9, 5, 20), new Date(2026, 9, 3, 1)), 2)
        compare(CalendarDate.diffDays(new Date(2026, 9, 3), new Date(2026, 9, 5)), -2)
        compare(CalendarDate.diffDays(new Date(2026, 9, 3, 23), new Date(2026, 9, 3, 0)), 0)
    }

    function test_isWeekend() {
        compare(CalendarDate.isWeekend(new Date(2026, 9, 3)), true)
        compare(CalendarDate.isWeekend(new Date(2026, 9, 4)), true)
        compare(CalendarDate.isWeekend(new Date(2026, 9, 5)), false)
    }

    function test_timePosition() {
        // eventUtil.ts 的 getPos：只读时分秒、不读毫秒，也不看是哪一天
        compare(CalendarDate.timePosition(new Date(2026, 9, 8, 0, 0, 0)), 0)
        compare(CalendarDate.timePosition(new Date(2026, 9, 8, 6)), 0.25)
        compare(CalendarDate.timePosition(new Date(2026, 9, 8, 12)), 0.5)
        compare(CalendarDate.timePosition(new Date(2026, 9, 8, 18, 30)), 0.7708333333333334)
        // 只算到秒：23:59:59 = 86399 / 86400，毫秒完全不进账
        compare(CalendarDate.timePosition(new Date(2026, 9, 8, 23, 59, 59)), 0.999988425925926)
        compare(CalendarDate.timePosition(new Date(2026, 9, 8, 23, 59, 59, 999)),
            0.999988425925926, "带毫秒也是同一个值，官方不吃 ms")
        compare(CalendarDate.roundPos(1 / 7), 0.143)
    }

    // ==================== 事件解析 ====================

    function test_isAllDayEvent() {
        // 官方是「键在不在」再取真值：'allDay' in event && Boolean(event.allDay)
        compare(CalendarDate.isAllDayEvent({ allDay: true }), true)
        compare(CalendarDate.isAllDayEvent({ allDay: false }), false)
        compare(CalendarDate.isAllDayEvent({}), false)
        compare(CalendarDate.isAllDayEvent({ start: new Date(2026, 9, 8) }), false)
    }

    function test_amendEvent() {
        const onlyStart = CalendarDate.amendEvent({ start: new Date(2026, 9, 8, 10) })
        compare(onlyStart.end.getHours(), 11)
        compare(onlyStart.end.getMinutes(), 0)

        // 加一小时跨到次日 ⇒ 补到当天 23:59:59
        const lateStart = CalendarDate.amendEvent({ start: new Date(2026, 9, 8, 23, 30) })
        compare(lateStart.end.getHours(), 23)
        compare(lateStart.end.getMinutes(), 59)

        const onlyEnd = CalendarDate.amendEvent({ end: new Date(2026, 9, 8, 10) })
        compare(onlyEnd.start.getHours(), 9)

        // 减一小时跨到前一日 ⇒ 补到当天 0 点
        const earlyEnd = CalendarDate.amendEvent({ end: new Date(2026, 9, 8, 0, 30) })
        compare(earlyEnd.start.getHours(), 0)
        compare(earlyEnd.start.getMinutes(), 0)

        compare(CalendarDate.amendEvent({}), null)
    }

    function test_amendEventDoesNotTouchTheCaller() {
        const source = { key: "a", start: new Date(2026, 9, 8, 10) }
        CalendarDate.amendEvent(source)
        verify(source.end === undefined, "官方就地改写事件对象，端口只改副本")
    }

    function test_parseAllDayEvent() {
        const parts = CalendarDate.parseAllDayEvent({
            key: "a", start: new Date(2026, 9, 8), end: new Date(2026, 9, 10)
        }, true, null)
        compare(parts.length, 3)
        compare(parts[0].date.getDate(), 8)
        compare(parts[2].date.getDate(), 10)
        compare(parts[0].allDay, true)
        // 逐日副本保留原始的 start / end
        compare(parts[1].start.getDate(), 8)
        compare(parts[1].end.getDate(), 10)

        // 两头都没有 ⇒ 挂到 currDate 那天并抹成 0 点；allDay 形参缺省是 true
        const fallback = CalendarDate.parseAllDayEvent({ key: "b" }, undefined,
            new Date(2026, 9, 8, 15))
        compare(fallback.length, 1)
        compare(fallback[0].date.getDate(), 8)
        compare(fallback[0].date.getHours(), 0)
        compare(fallback[0].allDay, true)
    }

    function test_parseEventSameDay() {
        const parts = CalendarDate.parseEvent({
            key: "a", start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11)
        }, null)
        compare(parts.length, 1)
        compare(parts[0].allDay, false)
        compare(parts[0].date.getDate(), 8)
    }

    function test_parseEventShortCrossDay() {
        // 跨天但不足 24 小时 ⇒ 两条：首日铺到 23:59:59、末日从 0 点起
        const parts = CalendarDate.parseEvent({
            key: "a", start: new Date(2026, 9, 8, 22), end: new Date(2026, 9, 9, 2)
        }, null)
        compare(parts.length, 2)
        compare(parts[0].date.getDate(), 8)
        // copyEvent(event, startOfDay(start), null, endOfDay(start)) ⇒ 首尾都留在起始那天，
        // 只有 date 被抹到 0 点
        compare(parts[0].end.getDate(), 8)
        compare(parts[0].end.getHours(), 23)
        compare(parts[0].end.getMinutes(), 59)
        compare(parts[0].end.getSeconds(), 59)
        compare(parts[1].date.getDate(), 9)
        compare(parts[1].start.getHours(), 0)
        compare(parts[1].end.getHours(), 2)
    }

    function test_parseEventPromotesLongSpan() {
        // 满 24 小时 ⇒ 升级成全天条带，逐日一条
        const parts = CalendarDate.parseEvent({
            key: "a", start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 10, 9)
        }, null)
        compare(parts.length, 3)
        compare(parts[0].allDay, true)
        compare(parts[2].date.getDate(), 10)
    }

    function test_parseEventSwapsReversedWithoutMutating() {
        const source = { key: "a", start: new Date(2026, 9, 10), end: new Date(2026, 9, 8) }
        const parts = CalendarDate.parseEvent(source, null)
        compare(parts.length, 3)
        compare(parts[0].date.getDate(), 8, "起止颠倒时按官方先交换再铺")
        compare(source.start.getDate(), 10, "交换只发生在副本上")
    }

    function test_parseEventSingleSided() {
        const parts = CalendarDate.parseEvent({ key: "a", start: new Date(2026, 9, 8, 10) }, null)
        compare(parts.length, 1)
        compare(parts[0].allDay, false)
        compare(parts[0].end.getHours(), 11)
        compare(CalendarDate.parseEvent({ key: "b" }, null).length, 0,
            "两头都没有的定时事件被丢掉")
    }

    // ==================== 时间轴排布 ====================

    function test_timelineDaysPerMode() {
        const display = new Date(2026, 9, 8, 15)
        const day = CalendarDate.timelineDays(display, "day", [], 0)
        compare(day.length, 1)
        compare(day[0].getDate(), 8)
        compare(day[0].getHours(), 0, "归到当天 0 点")

        const week = CalendarDate.timelineDays(display, "week", [], 0)
        compare(week.length, 7)
        compare(week[0].getDate(), 4)
        compare(week[0].getDay(), 0)
        compare(CalendarDate.timelineDays(display, "week", [], 1)[0].getDay(), 1)
        compare(CalendarDate.timelineDays(display, "nope", [], 0).length, 7,
            "认不出的 mode 落回时间轴那三档")

        // range 是左闭右开
        const range = CalendarDate.timelineDays(display, "range",
            [new Date(2020, 8, 26), new Date(2020, 8, 31)], 0)
        compare(range.length, 5)
        compare(range[0].getDate(), 26)
        compare(range[4].getDate(), 30)
        compare(CalendarDate.timelineDays(display, "range",
            [new Date(2020, 8, 26), new Date(2020, 8, 26)], 0).length, 0,
            "[D, D] 是零列 —— 官方 len = diffDays(end, start) 的直接后果")
        compare(CalendarDate.timelineDays(display, "range", [], 0).length, 7,
            "range 没给就退回周视图那七列")
    }

    function test_dailyTimedItems() {
        const day = new Date(2026, 9, 8)
        const items = CalendarDate.buildTimeline([
            { key: "a", start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11) },
            { key: "b", start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11) },
            { key: "c", start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11) }
        ], [day]).timed[0]
        compare(items.length, 3)
        compare(items[0].startPos, 0.375)
        compare(items[0].endPos, 0.458)
        // 官方那条 off-by-one（读的是自增前的计数）：同组前两条都贴左，第三条才错开
        compare(items[0].left, 0)
        compare(items[1].left, 0)
        compare(items[2].left, 0.3333333333333333)
    }

    function test_dailyTimedItemsSkips() {
        const day = new Date(2026, 9, 8)
        const parsed = CalendarDate.buildTimeline([
            { key: "all", allDay: true, start: new Date(2026, 9, 8) },
            { key: "other", start: new Date(2026, 9, 9, 9), end: new Date(2026, 9, 9, 10) }
        ], [day])
        compare(parsed.timed[0].length, 0, "全天事件与别的日子都不进这一列")
        compare(parsed.allDayLanes.length, 1)
    }

    function test_allDayBandKeepsOnePerEvent() {
        // 一条跨 32 天的事件在时间轴上只有一根带子：逐日副本里只有「日期正好是窗口
        // 第一天」那一份留得下（官方 filter isSameDay(event.date, startDate)）
        const days = CalendarDate.timelineDays(new Date(2019, 6, 23), "week", [], 0)
        const parsed = CalendarDate.buildTimeline([
            { key: "long", start: new Date(2019, 5, 25, 14, 45), end: new Date(2019, 6, 26, 6, 18) }
        ], days)
        compare(parsed.allDayLanes.length, 1)
        compare(parsed.allDayRows, 1)
        compare(parsed.allDayLanes[0].leftPos, 0)
        // 起点被挪到窗口第一天，终点在窗口内 ⇒ 铺 6 格
        compare(parsed.allDayLanes[0].width, 0.857)
    }

    function test_allDayBandDropsOutOfWindow() {
        const days = CalendarDate.timelineDays(new Date(2026, 9, 8), "week", [], 0)
        const parsed = CalendarDate.buildTimeline([
            { key: "before", allDay: true, start: new Date(2026, 8, 1), end: new Date(2026, 8, 3) },
            { key: "after", allDay: true, start: new Date(2026, 10, 1), end: new Date(2026, 10, 3) }
        ], days)
        compare(parsed.allDayLanes.length, 0)
        compare(parsed.allDayRows, 1, "calcRowHeight 空数组时算 1")
    }

    function test_assignLanesSeparatesOverlaps() {
        const weekStart = new Date(2026, 9, 4)
        const lanes = CalendarDate.assignLanes([
            { date: weekStart, end: weekStart, item: { key: "a" } },
            { date: weekStart, end: weekStart, item: { key: "b" } }
        ], weekStart, CalendarDate.addDays(weekStart, 7), 7)
        compare(lanes.length, 2)
        compare(lanes[0][0].topInd, 0)
        compare(lanes[1][0].topInd, 1)
        compare(lanes[0][0].leftPos, 0)
        compare(lanes[0][0].width, 0.143)
    }

    function test_assignLanesSpansDays() {
        const weekStart = new Date(2026, 9, 4)
        const lanes = CalendarDate.assignLanes([
            { date: CalendarDate.addDays(weekStart, 1),
                end: CalendarDate.addDays(weekStart, 3), item: { key: "a" } }
        ], weekStart, CalendarDate.addDays(weekStart, 7), 7)
        compare(lanes[0][1].leftPos, 0.143)
        compare(lanes[0][1].width, 0.429)
        // 跨天只有第一格带位置信息，其余格子是占位
        compare(lanes[0][2].leftPos, undefined)
        compare(CalendarDate.flattenLanes(lanes).length, 1)
    }

    function test_assignLanesClampsToWeek() {
        const weekStart = new Date(2026, 9, 4)
        const lanes = CalendarDate.assignLanes([
            { date: CalendarDate.addDays(weekStart, 5),
                end: CalendarDate.addDays(weekStart, 12), item: { key: "a" } }
        ], weekStart, CalendarDate.addDays(weekStart, 7), 7)
        compare(lanes[0][5].leftPos, 0.714)
        // 尾巴伸出周末那格：官方用 min(1 − leftPos, …) 夹住
        compare(lanes[0][5].width, 0.286)
    }

    function test_collectColumnsAndCounts() {
        const weekStart = new Date(2026, 9, 4)
        const lanes = CalendarDate.assignLanes([
            { date: weekStart, end: CalendarDate.addDays(weekStart, 2), item: { key: "a" } },
            { date: CalendarDate.addDays(weekStart, 1), end: null, item: { key: "b" } }
        ], weekStart, CalendarDate.addDays(weekStart, 7), 7)
        const columns = CalendarDate.collectColumns(lanes, 7)
        compare(columns.length, 7)
        compare(columns[0].length, 1)
        // 跨天条带在中途那一列也占一格 ⇒ 卡片里会把它列出来
        compare(columns[1].length, 2)
        compare(columns[2].length, 1)
        compare(columns[3].length, 0)
        compare(CalendarDate.countByColumn(lanes, 7)[1], 2)
        compare(CalendarDate.rowHeight(lanes), 2)
        compare(CalendarDate.rowHeight([]), 1)
    }

    // ==================== 月视图解析 ====================

    function test_parseMonthlyEventsTreatsEverythingAsBands() {
        // 月视图对**每一条**事件都走 parseAllDayEvent ⇒ 带时刻的也当全天条摆
        const weeks = CalendarDate.parseMonthlyEvents([
            { key: "t", start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11) }
        ], new Date(2026, 9, 1), 0)
        compare(weeks.length, 5)
        compare(weeks[1].display.length, 1)
        compare(weeks[1].display[0].topInd, 0)
        compare(weeks[1].counts[4], 1)
        compare(weeks[0].display.length, 0)
    }

    function test_parseMonthlyEventsCutsAtWeekBoundary() {
        // 10/7（周三）跨到 10/12：条带只铺到本周日尾，下周那一格不留占位
        const weeks = CalendarDate.parseMonthlyEvents([
            { key: "x", start: new Date(2026, 9, 7), end: new Date(2026, 9, 12) }
        ], new Date(2026, 9, 1), 0)
        compare(weeks[1].display.length, 1)
        compare(weeks[1].display[0].leftPos, 0.429)
        compare(weeks[1].display[0].width, 0.571)
        compare(weeks[2].display.length, 0)
        compare(weeks[2].columns[0].length, 0)
    }

    function test_parseMonthlyEventsKeepsDeclaredOrder() {
        const weeks = CalendarDate.parseMonthlyEvents([
            { key: "first", start: new Date(2026, 9, 8), children: "先声明" },
            { key: "second", start: new Date(2026, 9, 8), children: "后声明" }
        ], new Date(2026, 9, 1), 0)
        compare(weeks[1].display[0].topInd, 0)
        compare(weeks[1].display[0].item.key, "first")
        compare(weeks[1].display[1].topInd, 1)
        compare(weeks[1].display[1].item.key, "second")
    }

    // ==================== 组件缺省值 ====================

    function test_calendarDefaults() {
        const c = testCase.make("Calendar { }")
        compare(c.mode, "week", "官方 defaultProps.mode 是 week，不是 month")
        compare(c.showCurrTime, true)
        compare(c.scrollTop, 400)
        compare(c.minEventHeight, -9007199254740991)
        compare(c.weekStartsOn, 0)
        compare(c.markWeekend, false)
        compare(c.implicitHeight, 600, "官方 height 缺省 600")
        compare(c.events.length, 0)
        compare(c.displayValue.getFullYear(), new Date().getFullYear())
        c.destroy()
    }

    function test_modeDispatch() {
        const month = testCase.make("Calendar { mode: 'month' }")
        wait(60)
        verify(testCase.monthOf(month).visible)
        verify(!testCase.gridOf(month).visible)
        month.destroy()

        const week = testCase.make("Calendar { mode: 'week' }")
        wait(60)
        verify(!testCase.monthOf(week).visible)
        verify(testCase.gridOf(week).visible)
        week.destroy()

        const unknown = testCase.make("Calendar { mode: 'nope' }")
        wait(60)
        verify(testCase.gridOf(unknown).visible, "认不出的 mode 走时间轴")
        unknown.destroy()
    }

    function test_titleFollowsDisplayValue() {
        const c = testCase.make("Calendar { mode: 'month'; displayValue: new Date(2026, 9, 8) }")
        compare(c.title, "2026年10月")
        c.displayValue = new Date(2027, 0, 1)
        compare(c.title, "2027年1月")
        c.destroy()
    }

    function test_headerSlotIsBare() {
        const c = testCase.make("Calendar { mode: 'month'; Row { Text { text: '头部' } } }")
        wait(60)
        const host = testCase.part(c, "calendarHeaderHost")
        verify(host !== null)
        compare(host.children.length, 1, "默认属性就是官方那个不带样式的 header 槽")
        c.destroy()
    }

    // ==================== 月视图几何 ====================

    function test_monthGeometry() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const m = testCase.monthOf(c)
        compare(m.weekdayHeaderHeight, 27)
        compare(m.eventHeight, 24)
        compare(m.eventAreaTop, 31)
        compare(m.eventAreaBottom, 20)
        compare(m.weeks.length, 5)
        compare(m.cellHeight, 74)
        compare(m.eventAreaHeight, 23)
        // 官方 contentPadding 60 / contentHeight 24：ceil((74 − 60) / 24) = 1
        compare(m.itemLimit, 1)
        compare(m.cardWidth, 220)
        c.destroy()
    }

    function test_monthItemLimitGrowsWithHeight() {
        const c = testCase.make("Calendar { width: 640; height: 700; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const m = testCase.monthOf(c)
        compare(m.cellHeight, 134)
        compare(m.itemLimit, 4, "ceil((134 − 60) / 24)")
        c.destroy()
    }

    function test_monthEventBandsGeometry() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: 'a', start: new Date(2026, 9, 8), children: '甲' },"
            + "{ key: 'b', start: new Date(2026, 9, 9), end: new Date(2026, 9, 11),"
            + " children: '乙' }] }")
        wait(60)
        const bands = testCase.visibleBands(testCase.monthOf(c), "calendarMonthEvent")
        compare(bands.length, 2)
        // 第二周从 10/4 起：10/8 是周四 ⇒ 第 4 列，一条宽 1/7
        compare(bands[0].x, 365.44, 1e-6)
        compare(bands[0].y, 0)
        compare(bands[0].width, 91.52, 1e-6)
        compare(bands[0].height, 24)
        // 10/9 周五起：铺到周日那格为止
        compare(bands[1].x, 456.96, 1e-6)
        compare(bands[1].width, 183.04, 1e-6)
        c.destroy()
    }

    function test_monthHidesLanesBeyondItemLimit() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: '1', start: new Date(2026, 9, 8), children: '一' },"
            + "{ key: '2', start: new Date(2026, 9, 8), children: '二' },"
            + "{ key: '3', start: new Date(2026, 9, 8), children: '三' }] }")
        wait(60)
        const m = testCase.monthOf(c)
        compare(m.itemLimit, 1)
        compare(testCase.countAll(m, "calendarMonthEvent"), 3, "三条都实例化了")
        compare(testCase.visibleBands(m, "calendarMonthEvent").length, 1,
            "但只画得下 itemLimit 那一条")
        c.destroy()
    }

    function test_monthDateCellText() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const m = testCase.monthOf(c)
        // 每月 1 号那一格带月份前缀与「日」后缀：{LLL} + &nbsp;1 + {datestring}
        const first = testCase.dayCell(m, 0, 4)
        compare(testCase.findAll(first, "calendarMonthPrefix", [])[0].text, "10月")
        compare(testCase.findAll(first, "calendarDateNumber", [])[0].text, " 1")
        compare(testCase.findAll(first, "calendarDateSuffix", [])[0].text, "日")
        // 普通格子只有日号
        const plain = testCase.dayCell(m, 1, 4)
        compare(testCase.countAll(plain, "calendarMonthPrefix"), 0)
        compare(testCase.findAll(plain, "calendarDateNumber", [])[0].text, "8")
        compare(testCase.countAll(plain, "calendarDateSuffix"), 0)
        c.destroy()
    }

    function test_monthDateCellSharesOneLineBox() {
        // 官方那块日号是**一段行内文本**：`-month-date` 里 `{LLL}` + `<span>-today-date>&nbsp;1</span>`
        // + `日` 共用 `-skeleton li span { font-size-regular }` 那条 20 的行盒 ⇒ 天然同基线。
        // 端口拆成 Row 三块之后，前缀/后缀走 `lineHeight: 26 + FixedHeight`（Qt 把多出来的高度
        // 全垫在下面 ⇒ 基线在 14），日号走 centerIn（基线在 17）⇒ 像素实测差 3px，
        // 肉眼就是「10月1日 里那个 1 掉下去了」
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const m = testCase.monthOf(c)
        const first = testCase.dayCell(m, 0, 4)
        const row = testCase.findAll(first, "calendarDateRow", [])[0]
        compare(row.height, 20, "行盒是 -skeleton li span 的 20（表头那一档才是 26）")
        const pieces = [testCase.findAll(first, "calendarMonthPrefix", [])[0],
            testCase.findAll(first, "calendarDateNumber", [])[0],
            testCase.findAll(first, "calendarDateSuffix", [])[0]]
        for (let i = 0; i < pieces.length; ++i) {
            const mid = pieces[i].mapToItem(row, 0, 0).y + pieces[i].height / 2
            verify(Math.abs(mid - 10) <= 0.51,
                "第 " + i + " 块的中心要在 20 行盒的中线上，实测 " + mid)
        }
        c.destroy()

        // 今天那一格（24 的圆）与同排普通格子也必须同一条基线：日号盒不能跟着 circled 换高
        const todayCal = testCase.make("Calendar { width: 640; height: 400; mode: 'month' }")
        wait(60)
        const cells = testCase.findAll(testCase.monthOf(todayCal), "calendarDayCell", [])
        let circled = null
        let neighbour = null
        for (let i = 0; i < cells.length; ++i) {
            if (cells[i].modelData.isToday)
                circled = cells[i]
            else if (neighbour === null && cells[i].modelData.inMonth)
                neighbour = cells[i]
        }
        verify(circled !== null, "月网格里必有今天那一格")
        verify(neighbour !== null)
        const number = testCase.findAll(circled, "calendarDateNumber", [])[0]
        const rowOfNumber = testCase.findAll(circled, "calendarDateRow", [])[0]
        const otherNumber = testCase.findAll(neighbour, "calendarDateNumber", [])[0]
        const otherRow = testCase.findAll(neighbour, "calendarDateRow", [])[0]
        const mid = number.mapToItem(rowOfNumber, 0, 0).y + number.height / 2
        const otherMid = otherNumber.mapToItem(otherRow, 0, 0).y + otherNumber.height / 2
        verify(Math.abs(mid - otherMid) <= 0.51,
            "圈里的日号 " + mid + " 要和邻居 " + otherMid + " 同线")
        const dot = testCase.findAll(circled, "calendarTodayDot", [])[0]
        verify(Math.abs(mid - (dot.mapToItem(rowOfNumber, 0, 0).y + dot.height / 2)) <= 0.51,
            "24 的圆也要居中在日号上")

        // 表头那一档（`.semi-calendar-month-grid li { line-height: 26 }`）同样是「字在盒里居中」，
        // 不是 Qt 的 lineHeight + FixedHeight（那套把多出来的高度全垫在下面 ⇒ 字浮高 3px）
        const head = testCase.findAll(testCase.monthOf(todayCal), "calendarWeekdayText", [])[0]
        compare(head.height, 26, "表头行盒 26")
        compare(head.verticalAlignment, Text.AlignVCenter)
        todayCal.destroy()
    }

    function test_monthHeaderWeekdayNames() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const cells = testCase.findAll(testCase.monthOf(c), "calendarWeekdayCell", [])
        compare(cells.length, 7)
        const names = []
        for (let i = 0; i < cells.length; ++i)
            names.push(testCase.findAll(cells[i], "calendarWeekdayText", [])[0].text)
        const expected = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        for (let i = 0; i < expected.length; ++i)
            compare(names[i], expected[i], "第 " + i + " 格")
        c.destroy()

        const monday = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); weekStartsOn: 1 }")
        wait(60)
        const rotated = testCase.findAll(testCase.monthOf(monday), "calendarWeekdayCell", [])
        compare(testCase.findAll(rotated[0], "calendarWeekdayText", [])[0].text, "周一")
        compare(testCase.findAll(rotated[6], "calendarWeekdayText", [])[0].text, "周日")
        monday.destroy()
    }

    function test_monthClickEmitsMidnight() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        c.clicked.connect(function (value) {
            testCase.clickCount += 1
            testCase.lastClicked = value
        })
        const cell = testCase.dayCell(testCase.monthOf(c), 1, 4)
        mouseClick(cell, cell.width / 2, cell.height - 6)
        wait(40)
        compare(testCase.clickCount, 1, "点在事件层那片空白上也算点格子")
        compare(testCase.lastClicked.getDate(), 8)
        compare(testCase.lastClicked.getHours(), 0)
        compare(testCase.lastClicked.getMinutes(), 0)
        c.destroy()
    }

    function test_eventBandDoesNotStealCellClick() {
        // 官方 `-event-items` 是 pointer-events:none、子项 auto ⇒ 点条子不算点格子
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: 'a', start: new Date(2026, 9, 8), children: '占位' }] }")
        wait(60)
        c.clicked.connect(function () { testCase.clickCount += 1 })
        const band = testCase.visibleBands(testCase.monthOf(c), "calendarMonthEvent")[0]
        mouseClick(band, band.width / 2, band.height / 2)
        wait(40)
        compare(testCase.clickCount, 0)
        c.destroy()
    }

    // ==================== 事件条里那一段节点 ====================

    function test_eventBodyRendersStringChildren() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: 'a', start: new Date(2026, 9, 8), children: '甲' }] }")
        wait(60)
        const band = testCase.visibleBands(testCase.monthOf(c), "calendarMonthEvent")[0]
        const text = testCase.findAll(band, "calendarEventText", [])[0]
        compare(text.text, "甲")
        compare(text.font.pixelSize, 14)
        compare(text.color, Theme.current.colorText0)
        verify(!testCase.findAll(band, "calendarEventNode", [])[0].item,
            "字符串那一档不装载 Component")
        c.destroy()
    }

    function test_eventBodyLoadsComponentWithTheEvent() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        c.events = [{ key: "k", start: new Date(2026, 9, 8), children: eventKeyNode }]
        wait(60)
        const band = testCase.visibleBands(testCase.monthOf(c), "calendarMonthEvent")[0]
        compare(testCase.findAll(band, "calendarEventNode", [])[0].item.text, "k",
            "注入的是当前这一条事件（逐日副本）")
        verify(!testCase.findAll(band, "calendarEventText", [])[0].visible,
            "Component 那一档不再排那行字")
        c.destroy()
    }

    // ==================== 「还有 N 项」与卡片 ====================

    readonly property string overflowEvents: "["
        + "{ key: '1', start: new Date(2026, 9, 8), children: '一' },"
        + "{ key: '2', start: new Date(2026, 9, 8), children: '二' },"
        + "{ key: '3', start: new Date(2026, 9, 8), children: '三' }] }"

    function test_moreLinkCountsAndLabel() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: " + testCase.overflowEvents)
        wait(60)
        const links = testCase.visibleBands(testCase.monthOf(c), "calendarMoreLink")
        compare(links.length, 1, "只有周四那一格溢出")
        compare(testCase.findAll(links[0], "calendarMoreLinkText", [])[0].text, "还有2项")
        c.destroy()
    }

    function test_moreLinkOpensCardWithEveryBand() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: " + testCase.overflowEvents)
        wait(60)
        const m = testCase.monthOf(c)
        c.clicked.connect(function () { testCase.clickCount += 1 })
        c.moreClicked.connect(function (day, remaining) {
            testCase.moreCount += 1
            testCase.lastMoreDay = day
            testCase.lastRemaining = remaining
        })
        const link = testCase.visibleBands(m, "calendarMoreLink")[0]
        mouseClick(link, link.width / 2, link.height / 2)
        wait(80)
        compare(testCase.moreCount, 1)
        compare(testCase.clickCount, 0, "官方的 handleMoreClick 会 stopPropagation，不再点中格子")
        compare(testCase.lastMoreDay.getDate(), 8)
        compare(testCase.lastRemaining, 2)
        verify(m.cardOpen)
        compare(m.cardList.length, 3, "卡片列的是这一天的全部条带，不只是没画下的那两条")

        const card = testCase.findAll(testCase.overlay, "calendarMoreCard", [])[0]
        verify(card !== undefined, "卡片挂在窗口遮罩上，不在月视图的子树里")
        compare(card.width, 220)
        compare(testCase.countAll(card, "calendarMoreCardEvent"), 3)
        const row = testCase.findAll(card, "calendarMoreCardEvent", [])[0]
        compare(row.height, 24, "官方 -body li { height: 24px }")
        compare(row.mapToItem(card, 0, 0).x, 16, "官方 -body { padding: 0 16px }")
        const cross = testCase.findAll(card, "calendarMoreCardClose", [])[0]
        compare(cross.x + cross.width, card.width - 16,
            "-header margin 20 再叠 -close 的 margin-right -4 ⇒ 右缘离卡片 16")
        c.destroy()
    }

    function test_moreCardClosesWithTheCross() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: " + testCase.overflowEvents)
        wait(60)
        const m = testCase.monthOf(c)
        c.close.connect(function () { testCase.closeCount += 1 })
        const link = testCase.visibleBands(m, "calendarMoreLink")[0]
        mouseClick(link, link.width / 2, link.height / 2)
        wait(80)
        verify(m.cardOpen)

        const close = testCase.findAll(testCase.overlay, "calendarMoreCardClose", [])[0]
        mouseClick(close, close.width / 2, close.height / 2)
        wait(80)
        verify(!m.cardOpen)
        compare(testCase.closeCount, 1)
        c.destroy()
    }

    function test_moreCardHeaderShowsWeekdayAndDay() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: " + testCase.overflowEvents)
        wait(60)
        const m = testCase.monthOf(c)
        m.openCard(new Date(2026, 9, 8), m.weeks[1].columns[4],
            testCase.visibleBands(m, "calendarMoreLink")[0])
        wait(80)
        const card = testCase.findAll(testCase.overlay, "calendarMoreCard", [])[0]
        const weekday = testCase.findAll(card, "calendarCardWeekday", [])[0]
        const dayNum = testCase.findAll(card, "calendarCardDate", [])[0]
        // 官方 -header 两行：第一行走卡片正文档（text-2 / 14），第二行 font-size-header-4 20/28
        compare(weekday.text, "周四")
        compare(weekday.font.pixelSize, 14)
        compare(weekday.height, 20)
        compare(dayNum.text, "8", "第二行只有日号，不带「日」后缀")
        compare(dayNum.font.pixelSize, 20)
        compare(dayNum.height, 28)
        c.destroy()
    }

    function test_onlyOneCardAtATime() {
        // 官方 openCard 在 setState 时不并 prev（monthCalendar.tsx:122-124）⇒ 同时只有一张
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: '1', start: new Date(2026, 9, 8), children: '一' },"
            + "{ key: '2', start: new Date(2026, 9, 8), children: '二' },"
            + "{ key: '3', start: new Date(2026, 9, 8), children: '三' },"
            + "{ key: '4', start: new Date(2026, 9, 15), children: '四' },"
            + "{ key: '5', start: new Date(2026, 9, 15), children: '五' },"
            + "{ key: '6', start: new Date(2026, 9, 15), children: '六' }] }")
        wait(60)
        const m = testCase.monthOf(c)
        const links = testCase.visibleBands(m, "calendarMoreLink")
        compare(links.length, 2)
        m.openCard(new Date(2026, 9, 8), m.weeks[1].columns[4], links[0])
        m.openCard(new Date(2026, 9, 15), m.weeks[2].columns[4], links[1])
        wait(80)
        compare(m.cardDate.getDate(), 15)
        const card = testCase.findAll(testCase.overlay, "calendarMoreCard", [])
        compare(card.length, 1)
        compare(testCase.countAll(card[0], "calendarMoreCardEvent"), 3)
        c.destroy()
    }

    // ==================== 时间轴几何 ====================

    function test_timeGridConstants() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        const g = testCase.gridOf(c)
        compare(g.hourHeight, 60)
        compare(g.halfHourHeight, 30)
        compare(g.bodyHeight, 1440, "48 个半小时格 × 30 = 官方那个 scrollHeight 基准")
        compare(g.timeColumnWidth, 70)
        compare(g.columnMinWidth, 130)
        compare(g.allDayRowHeight, 26)
        compare(g.dateHeaderHeight, 27)
        compare(g.days.length, 7)
        compare(g.columnWidth, 130, "(640 − 70) / 7 = 81 不足最小列宽 ⇒ 夹到 130")
        compare(g.hasDateHeader, true)
        c.destroy()
    }

    function test_dayModeHasNoDateHeader() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'day'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        const g = testCase.gridOf(c)
        compare(g.days.length, 1)
        compare(g.hasDateHeader, false)
        compare(testCase.countAll(g, "calendarDateHeader"), 0)
        compare(testCase.countAll(g, "calendarMonthLabel"), 0)
        compare(g.columnWidth, 570, "640 − 70")
        c.destroy()
    }

    function test_weekHeaderMonthLabel() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        const g = testCase.gridOf(c)
        const label = testCase.part(g, "calendarMonthLabel")
        compare(label.text, "10月")
        // 官方 `.semi-calendar-week .semi-calendar-week-tag { text-align: right; line-height: 26 }`
        // 再叠 `:first-child { padding-right: 8 }` ⇒ 那一格仍是 70 的 sticky-left，但字贴它的右缘、留 8
        compare(label.x, 0)
        compare(label.width, 70)
        compare(label.horizontalAlignment, Text.AlignRight, "字贴右，不是贴左")
        compare(label.rightPadding, g.tagPaddingRight)
        compare(label.height, g.tagLineHeight, "行盒吃 -tag 自己的 26，不是 -header 的 20")
        compare(label.verticalAlignment, Text.AlignVCenter,
            "CSS 的 line-height 半行距上下各一半 ⇒ 定高居中；lineHeight+FixedHeight 会把字垫到上面")
        c.destroy()
    }

    function test_headerHeightFollowsBandRows() {
        const bare = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        compare(testCase.gridOf(bare).allDayRows, 1, "没有条带时官方 calcRowHeight 也给 1")
        compare(testCase.gridOf(bare).headerHeight, 54)
        compare(testCase.part(testCase.gridOf(bare), "calendarAllDayLabel").text, "全天",
            "左侧那一格写的是 locale.allDay")
        bare.destroy()

        const two = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); events: ["
            + "{ key: 'a', allDay: true, start: new Date(2026, 9, 8) },"
            + "{ key: 'b', allDay: true, start: new Date(2026, 9, 8) }] }")
        wait(60)
        const g = testCase.gridOf(two)
        compare(g.allDayRows, 2)
        compare(g.headerHeight, 80, "27 + 2 × 26 + 1")
        two.destroy()
    }

    function test_bandGeometry() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); events: ["
            + "{ key: 'a', allDay: true, start: new Date(2026, 9, 8),"
            + " end: new Date(2026, 9, 9), children: '两天' }] }")
        wait(60)
        const band = testCase.findAll(testCase.gridOf(c), "calendarBand", [])[0]
        // 条带区宽 = 7 × 130 = 910；10/8 是周四 ⇒ 第 4 列，跨两天
        compare(band.x, 519.61, 1e-6)
        compare(band.y, 0, "第 0 条车道，相对于条带区自己")
        const g = testCase.gridOf(c)
        compare(band.mapToItem(g, 0, 0).y, 27, "整块条带区压在 27px 星期行下面")
        compare(band.width, 260.26, 1e-6)
        compare(band.height, 26)
        c.destroy()
    }

    function test_timedEventGeometry() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); events: ["
            + "{ key: 'a', start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11),"
            + " children: '两小时' }] }")
        wait(60)
        const item = testCase.findAll(testCase.gridOf(c), "calendarTimedEvent", [])[0]
        compare(item.y, 540, "0.375 × 1440")
        compare(item.height, 119.52, 1e-6)
        compare(item.x, 0)
        compare(item.width, 130)
        compare(item.z, 5)
        c.destroy()
    }

    function test_minEventHeight() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); minEventHeight: 200; events: ["
            + "{ key: 'a', start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11),"
            + " children: '两小时' }] }")
        wait(60)
        const item = testCase.findAll(testCase.gridOf(c), "calendarTimedEvent", [])[0]
        compare(item.height, 200, "Math.max(minEventHeight, 算出来的高)")
        c.destroy()
    }

    function test_slotClickQuantisesToHalfHours() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        const g = testCase.gridOf(c)
        c.clicked.connect(function (value) {
            testCase.clickCount += 1
            testCase.lastClicked = value
        })
        const slots = testCase.findAll(g, "calendarSlot", [])
        compare(slots.length, 48 * 7)
        // 第 20 格 = 10:00（floor(20/2) 时、(20 % 2) × 30 分）
        const slot = slots[20]
        mouseClick(slot, slot.width / 2, slot.height / 2)
        wait(40)
        compare(testCase.clickCount, 1)
        compare(testCase.lastClicked.getDate(), 4, "第一列是本周第一天 10/4")
        compare(testCase.lastClicked.getHours(), 10)
        compare(testCase.lastClicked.getMinutes(), 0)
        compare(g.slotDate(new Date(2026, 9, 4), 21).getMinutes(), 30)
        c.destroy()
    }

    function test_bandClickDoesNotEmitSlotClick() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); events: ["
            + "{ key: 'a', start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11),"
            + " children: '两小时' }] }")
        wait(60)
        c.clicked.connect(function () { testCase.clickCount += 1 })
        const item = testCase.findAll(testCase.gridOf(c), "calendarTimedEvent", [])[0]
        mouseClick(item, item.width / 2, item.height / 2)
        wait(40)
        compare(testCase.clickCount, 0)
        c.destroy()
    }

    function test_weekHeaderDateAndWeekdayAligned() {
        // 官方 `-grid-row li` 是 flex + align-items:center，两个 span 各自 `line-height:26` 居中
        // ⇒ 日号与星期共用同一条 26 的行盒。端口 Row 缺省顶对齐：26 的日号盒配一条 ~20 的星期
        // 文字，星期就浮上去（用户：「水平 header 的上面的几号和周几，文字没有对齐」）
        const grid = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date() }")
        wait(60)
        const heads = testCase.findAll(testCase.gridOf(grid), "calendarDateHeader", [])
        verify(heads.length >= 2, "星期行有格子")
        let todayCells = 0
        for (let i = 0; i < heads.length; ++i) {
            const number = testCase.findAll(heads[i], "calendarDateNumber", [])[0]
            const weekday = testCase.findAll(heads[i], "calendarDateHeaderWeekday", [])[0]
            verify(number !== undefined, "第 " + i + " 格有日号")
            verify(weekday !== undefined, "第 " + i + " 格有星期")
            compare(weekday.height, 26, "-grid-row li > span 的 26 行盒")
            const numberCenter = number.mapToItem(heads[i], 0, 0).y + number.height / 2
            const weekdayCenter = weekday.mapToItem(heads[i], 0, 0).y + weekday.height / 2
            verify(Math.abs(numberCenter - weekdayCenter) <= 0.51,
                "第 " + i + " 格日号中心 " + numberCenter + " 与星期中心 " + weekdayCenter
                + " 齐平（今天档圆 24 也要居中）")
            if (heads[i].today)
                todayCells++
        }
        compare(todayCells, 1, "里面必含今天那一格（圆标记那一档也量到了）")
        grid.destroy()
    }

    function test_todayCellIsCircled() {
        // 缺省 displayValue 就是今天 ⇒ 月网格必有一格 isToday，跟着时钟走也不怕月份翻页
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month' }")
        wait(60)
        const cells = testCase.findAll(testCase.monthOf(c), "calendarDayCell", [])
        let today = null
        for (let i = 0; i < cells.length; ++i)
            if (cells[i].modelData.isToday)
                today = cells[i]
        verify(today !== null, "铺开的月网格里一定有今天那一格")
        const dot = testCase.findAll(today, "calendarTodayDot", [])[0]
        verify(dot.visible, "官方 -today 祖先下的 -today-date 才是圆")
        compare(dot.width, 24)
        compare(dot.height, 24)
        compare(dot.color, Theme.current.colorPrimary)
        const number = testCase.findAll(today, "calendarDateNumber", [])[0]
        compare(number.text, CalendarDate.dayNumber(new Date()))
        compare(number.color, Theme.current.colorBg1, "圈里的数字走 bg-1")
        c.destroy()

        const grid = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date() }")
        wait(60)
        const heads = testCase.findAll(testCase.gridOf(grid), "calendarDateHeader", [])
        let head = null
        let other = null
        for (let i = 0; i < heads.length; ++i) {
            if (heads[i].today)
                head = heads[i]
            else
                other = heads[i]
        }
        verify(head !== null, "星期行里也必有一格是今天")
        verify(other !== null)
        const headDot = testCase.findAll(head, "calendarTodayDot", [])[0]
        verify(headDot.visible)
        compare(headDot.color, Theme.current.colorPrimary)
        compare(testCase.findAll(head, "calendarDateNumber", [])[0].color,
            Theme.current.colorBg1)
        verify(!testCase.findAll(other, "calendarTodayDot", [])[0].visible,
            "其它日子不圈圆")
        compare(testCase.findAll(other, "calendarDateNumber", [])[0].color,
            Theme.current.colorText0)
        grid.destroy()
    }

    function test_stickyLeftFollowsHorizontalScroll() {
        // 官方 `-sticky-left` 那两列（刻度列、星期/条带的左格）横向不动，右边的列跟着滚
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        const g = testCase.gridOf(c)
        const view = testCase.part(g, "calendarViewport")
        compare(g.columnWidth, 130, "七列要 980px，容器只有 640 ⇒ 有横滚余量")
        compare(testCase.part(g, "calendarTimeColumn").x, 0)
        compare(testCase.part(g, "calendarWeekdayCells").x, 70)
        compare(testCase.part(g, "calendarAllDayColumns").x, 70)
        view.contentX = 100
        wait(40)
        compare(testCase.part(g, "calendarTimeColumn").x, 100, "刻度列自己往上补，视觉上钉在左边")
        compare(testCase.part(g, "calendarWeekdayCells").x, -30)
        compare(testCase.part(g, "calendarAllDayColumns").x, -30)
        c.destroy()
    }

    function test_currTimeLineOnlyOnToday() {
        // 不设 displayValue ⇒ 缺省就是今天，七列里只有一列画红线
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week' }")
        wait(60)
        const lines = testCase.findAll(testCase.gridOf(c), "calendarCurrTime", [])
        compare(lines.length, 7)
        compare(testCase.visibleBands(c, "calendarCurrTime").length, 1)
        const expected = CalendarDate.roundPos(CalendarDate.timePosition(new Date())) * 1440
        compare(lines[0].y, expected, 2)
        compare(lines[0].z, 8)
        c.destroy()

        const past = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2001, 0, 1) }")
        wait(60)
        compare(testCase.visibleBands(past, "calendarCurrTime").length, 0,
            "窗口里没有今天那一列就不画")
        past.destroy()

        const off = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; showCurrTime: false }")
        wait(60)
        compare(testCase.visibleBands(off, "calendarCurrTime").length, 0)
        off.destroy()
    }

    function test_hourLabels() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        const g = testCase.gridOf(c)
        compare(g.hourLabel(0), "", "官方 list.splice(0, 1, '') 把 0 点那一格抹平")
        compare(g.hourLabel(1), "上午1时")
        compare(g.hourLabel(11), "上午11时")
        compare(g.hourLabel(12), "下午12时")
        compare(g.hourLabel(13), "下午1时")
        compare(g.hourLabel(23), "下午11时")
        c.destroy()
    }

    function test_stickyZOrder() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        const g = testCase.gridOf(c)
        compare(testCase.part(g, "calendarStickyTop").z, 20)
        const ruler = testCase.part(g, "calendarTimeColumn")
        compare(ruler.z, 10)
        compare(ruler.width, 70)
        // 官方 -skeleton 那层在 -event-items 之下 ⇒ 格线自己的 z 也得钉住
        compare(testCase.findAll(g, "calendarSlotLine", [])[1].z, 3)
        c.destroy()
    }

    // ==================== 四个 render prop ====================

    function test_dateGridRenderFillsEveryCell() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); dateGridRender: Component {"
            + "Item { id: node; property var date: null; property string dateString: '' } } }")
        wait(60)
        const nodes = testCase.findAll(testCase.monthOf(c), "calendarDateGrid", [])
        compare(nodes.length, 35)
        compare(nodes[11].item.date.getDate(), 8, "第 11 格 = 第二周周四")
        compare(nodes[11].item.dateString, new Date(2026, 9, 8).toString(),
            "官方传的就是 date.toString() 那个串")
        c.destroy()
    }

    function test_dateGridRenderFillsEveryColumn() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); dateGridRender: Component {"
            + "Item { id: node; property var date: null; property string dateString: '' } } }")
        wait(60)
        const nodes = testCase.findAll(testCase.gridOf(c), "calendarDateGrid", [])
        compare(nodes.length, 7)
        compare(nodes[0].item.date.getDate(), 4)
        c.destroy()
    }

    function test_renderDateDisplayReplacesTheNumber() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); renderDateDisplay: Component {"
            + "Item { id: node; property var date: null; property string dateString: ''"
            + "; width: 20; height: 20 } } }")
        wait(60)
        const m = testCase.monthOf(c)
        compare(testCase.countAll(m, "calendarDateDisplay"), 35)
        const row = testCase.findAll(testCase.dayCell(m, 1, 4), "calendarDateRow", [])[0]
        verify(!row.visible, "官方是二选一：自定义档接管之后那串数字不画")
        c.destroy()

        const grid = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); renderDateDisplay: Component {"
            + "Item { id: node; property var date: null; property string dateString: ''"
            + "; width: 20; height: 20 } } }")
        wait(60)
        compare(testCase.countAll(testCase.gridOf(grid), "calendarDateDisplay"), 7)
        grid.destroy()
    }

    function test_renderTimeDisplayReplacesTheRuler() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); renderTimeDisplay: Component {"
            + "Text { id: node; property var time: -1; text: 'T' + node.time } } }")
        wait(60)
        const nodes = testCase.findAll(testCase.gridOf(c), "calendarTimeDisplay", [])
        compare(nodes.length, 24)
        compare(nodes[9].item.text, "T9", "注入的是整点序号")
        c.destroy()
    }

    function test_allDayEventsRenderGetsTheRawArray() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); events: ["
            + "{ key: 'a', allDay: true, start: new Date(2026, 9, 8), children: '全天' },"
            + "{ key: 'b', start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11),"
            + " children: '定时' },"
            + "{ key: 'c', allDay: true, start: new Date(2026, 0, 1), children: '窗口外' }]"
            + "; allDayEventsRender: Component { Item { id: node; property var events: [] } } }")
        wait(60)
        const g = testCase.gridOf(c)
        const node = testCase.findAll(g, "calendarAllDayCustom", [])[0]
        // 官方把未经过滤的 props.events 原样交给 allDayEventsRender
        compare(node.item.events.length, 3)
        compare(testCase.countAll(g, "calendarBand"), 0, "自定义那一档接管了条带区")
        c.destroy()
    }

    // ==================== 状态与信号 ====================

    function test_signalsForwardFromTimeGrid() {
        // scrollTop 缺省 400 会把 00:00 那几格滚出可视区，点到的是吸顶那一层 ⇒ 从 0 开始滚才摸得到第 0 格
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); scrollTop: 0 }")
        wait(60)
        c.clicked.connect(function (value) {
            testCase.clickCount += 1
            testCase.lastClicked = value
        })
        const slot = testCase.findAll(testCase.gridOf(c), "calendarSlot", [])[0]
        mouseClick(slot, slot.width / 2, slot.height / 2)
        wait(40)
        compare(testCase.clickCount, 1)
        compare(testCase.lastClicked.getDate(), 4)
        c.destroy()
    }

    function test_displayValueSwitchRebuilds() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        compare(testCase.monthOf(c).weeks.length, 5)
        c.displayValue = new Date(2027, 0, 1)
        wait(60)
        compare(testCase.monthOf(c).weeks.length, 6)
        c.destroy()
    }

    function test_eventsUpdateRebuilds() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: [] }")
        wait(60)
        compare(testCase.countAll(testCase.monthOf(c), "calendarMonthEvent"), 0)
        c.events = [{ key: "a", start: new Date(2026, 9, 8), children: "甲" }]
        wait(60)
        compare(testCase.countAll(testCase.monthOf(c), "calendarMonthEvent"), 1)
        c.destroy()
    }

    function test_eventsAreNotMutatedByRendering() {
        const source = [{ key: "a", start: new Date(2026, 9, 8, 10) }]
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        c.events = source
        wait(60)
        compare(testCase.countAll(testCase.gridOf(c), "calendarTimedEvent"), 1,
            "只给一头的也照官方补出另一头")
        verify(source[0].end === undefined, "补出来的是副本，用户那个对象不动")
        c.destroy()
    }

    function test_scrollTopIsOneShot() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); scrollTop: 600 }")
        wait(60)
        const view = testCase.part(testCase.gridOf(c), "calendarViewport")
        compare(view.contentY, 600)
        // 官方只在 componentDidMount 写一次，之后改属性不动
        c.scrollTop = 0
        wait(60)
        compare(view.contentY, 600)
        c.destroy()
    }

    function test_weekStartsOnRotatesColumns() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); weekStartsOn: 1 }")
        wait(60)
        const g = testCase.gridOf(c)
        compare(g.days[0].getDay(), 1)
        compare(g.days[0].getDate(), 5)
        c.destroy()
    }

    function test_markWeekendGreysWeekendColumns() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); markWeekend: true }")
        wait(60)
        const columns = testCase.findAll(testCase.gridOf(c), "calendarDayColumn", [])
        compare(columns.length, 7)
        // 周日开头 ⇒ 第 0 列与第 6 列是周末
        const fills = []
        for (let i = 0; i < columns.length; ++i)
            fills.push(testCase.findAll(columns[i], "calendarWeekendFill", [])[0])
        for (let i = 0; i < 7; ++i) {
            const weekend = i === 0 || i === 6
            compare(fills[i].visible, weekend, "第 " + i + " 列铺不铺")
            if (weekend)
                compare(fills[i].color, Theme.current.colorFill0, "第 " + i + " 列铺的是 fill-0")
        }
        c.destroy()

        const off = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        const plain = testCase.findAll(testCase.gridOf(off), "calendarWeekendFill", [])
        for (let i = 0; i < plain.length; ++i)
            verify(!plain[i].visible, "markWeekend 关掉以后一列都不铺")
        off.destroy()
    }

    // ==================== 变异复核补上的那些缺口 ====================

    function test_monthGridMarksEveryInMonthCell() {
        const weeks = CalendarDate.monthGrid(new Date(2026, 9, 1), 0)
        compare(weeks[4][6].day, 31)
        compare(weeks[4][6].inMonth, true, "月末那格仍算当月（isSameMonth，不是 isSameDay）")
        compare(weeks[0][3].inMonth, false)
        compare(weeks[0][4].inMonth, true)
    }

    function test_parseEventPromotesAnythingOverADay() {
        // 官方门槛是「不足 24 小时才拆两条」⇒ 42 小时也要升级成全天条带
        const parts = CalendarDate.parseEvent({
            key: "a", start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 10, 3)
        }, null)
        compare(parts.length, 3, "8 / 9 / 10 三天各一根带子")
        for (let i = 0; i < parts.length; ++i)
            compare(parts[i].allDay, true)
    }

    function test_orderedEventsSortsByStartNotDeclaration() {
        const ordered = CalendarDate.orderedEvents([
            { key: "late", start: new Date(2026, 9, 10) },
            { key: "early", start: new Date(2026, 9, 5) }
        ])
        compare(ordered.length, 2)
        compare(ordered[0].item.key, "early", "先按 start 排，声明序只兜同刻")
        compare(ordered[1].item.key, "late")
    }

    function test_buildTimelineKeepsAllDayOutOfTimedColumns() {
        const days = CalendarDate.timelineDays(new Date(2026, 9, 8), "week", [], 0)
        const t = CalendarDate.buildTimeline([
            { key: "a", start: new Date(2026, 9, 8), allDay: true, children: "全天" },
            { key: "b", start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 10),
              children: "定时" }
        ], days)
        compare(t.timed[4].length, 1, "全天条目不进时间轴那一桶")
        compare(t.timed[4][0].item.key, "b")
        compare(t.allDayLanes.length, 1)
    }

    function test_allDayBandDropsTailExactlyOnBoundary() {
        // 窗口 10/4..10/10（7 列），从 10/11 起的带子锚点正好压在 rangeEnd 上 ⇒ 官方丢掉
        const days = CalendarDate.timelineDays(new Date(2026, 9, 8), "week", [], 0)
        const t = CalendarDate.buildTimeline([
            { key: "tail", start: new Date(2026, 9, 11), allDay: true, children: "下周" }
        ], days)
        compare(t.allDayLanes.length, 0, "锚点等于窗口右缘也算窗口外")
    }

    function test_monthBandsUseTheFirstDayCopyOnly() {
        // 跨天的定时事件在月视图仍是一根带子（每条事件只由「第一天」那份副本代表）
        const weeks = CalendarDate.parseMonthlyEvents([
            { key: "a", start: new Date(2026, 9, 8, 22), end: new Date(2026, 9, 9, 2),
              children: "夜里两点" }
        ], new Date(2026, 9, 1), 0)
        compare(weeks[1].display.length, 1, "拆出来的第二份副本不再另起一根带子")
        compare(weeks[1].display[0].date.getDate(), 8)
        compare(weeks[1].display[0].leftPos, 0.571)
        compare(weeks[1].display[0].width, 0.286)

        // 下一行第一天的事件不能同时出现在这一行（官方那道 < 而不是 <=）
        const two = CalendarDate.parseMonthlyEvents([
            { key: "b", start: new Date(2026, 9, 11), allDay: true, children: "第三周周日" }
        ], new Date(2026, 9, 1), 0)
        compare(two[1].display.length, 0, "10/11 是第二行的 weekEnd，不进第二行")
        compare(two[2].display.length, 1)
    }

    function test_headerBandFollowsTheSlot() {
        const bare = testCase.make("Calendar { mode: 'month' }")
        wait(60)
        const bareBand = testCase.part(bare, "calendarHeaderBand")
        compare(bareBand.height, 0, "官方把 header 塞进吸顶带最前面，没有子项就没有这一截")
        compare(bareBand.visible, false)
        bare.destroy()

        const withHeader = testCase.make("Calendar { mode: 'month'; width: 640; height: 400;"
            + " Row { Text { text: '头部'; font.pixelSize: 20; height: 30 } } }")
        wait(60)
        const band = testCase.part(withHeader, "calendarHeaderBand")
        const host = testCase.part(withHeader, "calendarHeaderHost")
        compare(band.height, host.height, "带子的高就是子项的高")
        verify(band.height > 0)
        compare(band.visible, true)
        // 日历本体没有背景（CSS 里没有 -calendar { background }）：根项下只有带、槽、主体三块
        compare(withHeader.children.length, 3, "除了头部那一条 bg-2，日历自己不铺底")
        withHeader.destroy()
    }

    function test_markWeekendGreysMonthCells() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); markWeekend: true }")
        wait(60)
        const cells = testCase.findAll(testCase.monthOf(c), "calendarDayCell", [])
        compare(cells.length, 35)
        for (let i = 0; i < cells.length; ++i) {
            const fill = testCase.findAll(cells[i], "calendarWeekendFill", [])[0]
            compare(fill.visible, cells[i].modelData.isWeekend, "第 " + i + " 格")
            if (cells[i].modelData.isWeekend)
                compare(fill.color, Theme.current.colorFill0, "周末铺的是 fill-0")
        }
        c.destroy()

        const plain = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const off = testCase.findAll(testCase.monthOf(plain), "calendarWeekendFill", [])
        for (let i = 0; i < off.length; ++i)
            verify(!off[i].visible, "markWeekend 关掉就一格都不铺")
        plain.destroy()
    }

    function test_monthCellColoursAndHeaderBandToken() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const m = testCase.monthOf(c)
        const inMonth = testCase.findAll(testCase.dayCell(m, 1, 4), "calendarDateNumber", [])[0]
        const neighbour = testCase.findAll(testCase.dayCell(m, 0, 0), "calendarDateNumber", [])[0]
        compare(inMonth.color, Theme.current.colorText0)
        compare(neighbour.color, Theme.current.colorText2, "邻月的日号淡一档")
        c.destroy()

        // 浅色档 bg-0..bg-3 全撞值 ⇒ 底色只能在深色档断
        Theme.mode = Theme.Dark
        const dark = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const bg = testCase.part(testCase.monthOf(dark), "calendarWeekdayHeaderBg")
        verify(bg.color !== Theme.current.colorBg0, "深色档这两个令牌必须分得开，否则断言空转")
        compare(bg.color, Theme.current.colorBg2, "表头那一行吃 -sticky-top 的 bg-2")
        dark.destroy()
        Theme.mode = Theme.Light
    }

    function test_rangeModeColumnsComeFromTheProp() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'range'"
            + "; range: [new Date(2026, 9, 6), new Date(2026, 9, 11)] }")
        wait(60)
        const g = testCase.gridOf(c)
        compare(g.days.length, 5, "range 得真的透传进时间轴：6..10 共五列（右端不开）")
        compare(g.days[0].getDate(), 6)
        compare(g.days[4].getDate(), 10)
        c.destroy()
    }

    function test_itemLimitFollowsTheOfficialSixtyPadding() {
        // 官方 contentPadding 写死 60，而它自己 CSS 的事件区是 31 + 20 = 51 ⇒ 高 84 的格子
        // 按 60 算是 ceil(24/24) = 1 条、按 51 算就变 2 条。这一格专门钉住「照抄 60」。
        const c = testCase.make("Calendar { width: 640; height: 447; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const m = testCase.monthOf(c)
        compare(m.cellHeight, 84, "floor((447 − 27) / 5)")
        compare(m.itemLimit, 1, "ceil((84 − 60) / 24)")
        compare(m.eventAreaHeight, 33, "事件区自己只有 84 − 31 − 20")
        c.destroy()
    }

    function test_secondLaneBandSitsOneRowBelow() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: '1', start: new Date(2026, 9, 8), children: '一' },"
            + "{ key: '2', start: new Date(2026, 9, 8), children: '二' },"
            + "{ key: '3', start: new Date(2026, 9, 8), children: '三' }] }")
        wait(60)
        const bands = testCase.findAll(testCase.monthOf(c), "calendarMonthEvent", [])
        compare(bands.length, 3)
        compare(bands[0].y, 0)
        compare(bands[1].y, 24, "第二条挤到第 1 条车道 ⇒ 一个车道高 24")
        compare(bands[2].y, 48)
        compare(testCase.visibleBands(c, "calendarMonthEvent").length, 1, "但只画 itemLimit 那一条")
        c.destroy()
    }

    function test_eventLayerStacksAboveTheCells() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const layer = testCase.part(testCase.monthOf(c), "calendarEventLayer")
        compare(layer.z, 1, "官方 -event-items 排在 -skeleton 之后 ⇒ 盖在格子那层上面")
        compare(layer.y, 31)
        c.destroy()
    }

    function test_customNodeFillsTheWholeCell() {
        // 官方那层是 position:absolute; inset:0 ⇒ 自定义节点拿到的是整个格子的尺寸
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); dateGridRender: Component {"
            + "Item { id: node; property var date: null; property string dateString: '' } } }")
        wait(60)
        const m = testCase.monthOf(c)
        const node = testCase.findAll(m, "calendarDateGrid", [])[0]
        const cell = testCase.dayCell(m, 0, 0)
        compare(node.width, cell.width)
        compare(node.height, cell.height)
        compare(node.z, 0, "官方 `-date { z-index: 3 }` ⇒ 自定义节点不能盖过数字")
        // 同一格里声明顺序即绘制顺序：自定义节点排在数字那行前面
        const row = testCase.findAll(cell, "calendarDateRow", [])[0]
        compare(cell.children.indexOf(node) < cell.children.indexOf(row), true)
        c.destroy()
    }

    function test_sparseLaneShowsTheOfficialZeroRemaining() {
        // 官方两条口径是分开用的：显隐看「这一列最高占位行 + 1」（稀疏数组的 length），
        // 「还有 N 项」的 N 看「这一列真的占了几条」减 itemLimit ⇒ 中间有空洞时会出现
        // 「还有 0 项」这种官方自己的怪文案。这一格把两条口径分别钉住。
        // A：10/4→10/8 铺第 0..4 列（车道 0）；B：10/5→10/9 只能上车道 1，铺第 1..5 列
        // ⇒ 第 1..4 列 len=2/cnt=2（「还有1项」），第 5 列 len=2/cnt=1（车道 0 是空洞 ⇒「还有0项」）
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: 'A', start: new Date(2026, 9, 4), end: new Date(2026, 9, 8),"
            + " allDay: true, children: 'A' },"
            + "{ key: 'B', start: new Date(2026, 9, 5), end: new Date(2026, 9, 9),"
            + " allDay: true, children: 'B' }] }")
        wait(60)
        const m = testCase.monthOf(c)
        const week = m.weeks[1]
        compare(week.columns[5].length, 2, "第 5 列的稀疏数组长度是 2（车道 1 有占位）")
        compare(week.columns[5][0] === undefined, true, "车道 0 在这一列是空洞")
        compare(week.counts[5], 1, "真的占了几条：只有 B")
        const links = testCase.visibleBands(m, "calendarMoreLink")
        compare(links.length, 5, "第 1..5 列的稀疏长度都是 2 ⇒ 五格都溢出")
        // 同一份数据里两种文案并存：重叠列是正常「还有1项」，空洞列是「还有0项」
        const dense = testCase.findAll(testCase.dayCell(m, 1, 2), "calendarMoreLink", [])[0]
        compare(testCase.findAll(dense, "calendarMoreLinkText", [])[0].text, "还有1项")
        const hole = testCase.findAll(testCase.dayCell(m, 1, 5), "calendarMoreLink", [])[0]
        compare(testCase.findAll(hole, "calendarMoreLinkText", [])[0].text, "还有0项")
        // 第 0 列只有 A 一条：稀疏长度 1 不超过 itemLimit ⇒ 链接留着但不可见
        const col0 = testCase.findAll(testCase.dayCell(m, 1, 0), "calendarMoreLink", [])[0]
        compare(col0.visible, false, "没溢出就不该露「还有 N 项」")
        compare(testCase.findAll(col0, "calendarMoreLinkText", [])[0].text,
            CalendarDate.remainingText(0))
        // 每格都造了节点（可见性才决定露不露）⇒ 数一下总量，确认没漏格
        compare(testCase.findAll(m, "calendarMoreLink", []).length, m.weeks.length * 7)
        const cell = testCase.dayCell(m, 1, 5)
        compare(testCase.countAll(cell, "calendarMonthEvent"), 0,
            "条子画在事件层里，不在格子内部")
        m.openCard(new Date(2026, 9, 9), week.columns[5], hole)
        wait(80)
        compare(m.cardList.length, 1, "卡片要滤掉空洞，稀疏数组本身是 2 项")
        const card = testCase.findAll(testCase.overlay, "calendarMoreCard", [])[0]
        compare(testCase.countAll(card, "calendarMoreCardEvent"), 1)
        c.destroy()
    }

    function test_moreCardPositionAndWidth() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: " + testCase.overflowEvents)
        wait(60)
        const m = testCase.monthOf(c)
        const link = testCase.visibleBands(m, "calendarMoreLink")[0]
        m.openCard(new Date(2026, 9, 8), m.weeks[1].columns[4], link)
        wait(80)
        // 月视图没有刻度列，格子宽 640/7 ⇒ 周四那格右缘 457，链接再让开 anchors.rightMargin 8 ⇒ 449
        // 窗口宽 900 ⇒ 右边还剩 900 − 449 − 110 > 0 ⇒ 官方判 leftTopOver（方向本身是反的，照抄）
        compare(m.cardRoomRight > 0, true)
        compare(m.cardPosition, Enums.LeftTop)
        const popup = testCase.findChild(m, "calendarMoreCardPopup")
        verify(popup !== null, "卡片宽由 cardRoot 的 implicitWidth 交给 PopupBase")
        compare(popup.width, 220)
        const card = testCase.findAll(testCase.overlay, "calendarMoreCard", [])[0]
        compare(card.width, 220)
        compare(card.implicitWidth, 220,
            "PopupBase.bodyWidth 读的是 contentItem.implicitWidth，卡片靠这一条把 220 交出去")
        c.destroy()

        // 860 宽：周六（10/10）那格右缘 860、链接 852 ⇒ 900 − 852 − 110 < 0 ⇒ RightTop；
        // 同一份数据里周五那格链接右缘 729.14 ⇒ 还剩 60.86 ⇒ 依旧 LeftTop。
        // 这两个数把官方那个写死 110 的门槛（卡片其实宽 220）钉住：换成 220，60.86 立刻变负。
        const wide = testCase.make("Calendar { width: 860; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: 'a', start: new Date(2026, 9, 9), end: new Date(2026, 9, 10),"
            + " children: '甲' },"
            + "{ key: 'b', start: new Date(2026, 9, 9), end: new Date(2026, 9, 10),"
            + " children: '乙' }] }")
        wait(60)
        const wm = testCase.monthOf(wide)
        const link5 = testCase.findAll(testCase.dayCell(wm, 1, 5), "calendarMoreLink", [])[0]
        verify(link5 !== undefined && link5.visible, "周五那格两条 ⇒ 露出「还有1项」")
        wm.openCard(new Date(2026, 9, 9), wm.weeks[1].columns[5], link5)
        wait(80)
        compare(wm.cardRoomRight, 60.857142857142776, 1e-6)
        compare(wm.cardPosition, Enums.LeftTop)
        const sat = testCase.findAll(testCase.dayCell(wm, 1, 6), "calendarMoreLink", [])[0]
        verify(sat !== undefined && sat.visible, "周六（10/10）那一格同样溢出")
        wm.openCard(new Date(2026, 9, 10), wm.weeks[1].columns[6], sat)
        wait(80)
        compare(wm.cardRoomRight, -62.0, 1e-6, "格子右缘已经越过 900 − 110")
        compare(wm.cardPosition, Enums.RightTop)
        wide.destroy()
    }

    function test_moreCardClosesOnClickingOutside() {
        // 官方 showCard 自己注册 document mousedown，点卡片外面走 notifyClose ⇒ 也发 close()
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: " + testCase.overflowEvents)
        wait(60)
        const m = testCase.monthOf(c)
        c.close.connect(function () { testCase.closeCount += 1 })
        const link = testCase.visibleBands(m, "calendarMoreLink")[0]
        m.openCard(new Date(2026, 9, 8), m.weeks[1].columns[4], link)
        wait(80)
        verify(m.cardOpen)
        mouseClick(testCase, 880, 880, Qt.LeftButton)
        wait(80)
        verify(!m.cardOpen, "点外面要收卡")
        compare(testCase.closeCount, 1, "点外面那一路也发 close()")
        c.destroy()
    }

    function test_cardHeaderGapIsTheOfficialFour() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: " + testCase.overflowEvents)
        wait(60)
        const m = testCase.monthOf(c)
        m.openCard(new Date(2026, 9, 8), m.weeks[1].columns[4],
            testCase.visibleBands(m, "calendarMoreLink")[0])
        wait(80)
        const card = testCase.findAll(testCase.overlay, "calendarMoreCard", [])[0]
        const weekday = testCase.findAll(card, "calendarCardWeekday", [])[0]
        const dayNum = testCase.findAll(card, "calendarCardDate", [])[0]
        const at = dayNum.mapToItem(card, 0, 0)
        const below = weekday.mapToItem(card, 0, 0)
        compare(at.y - (below.y + weekday.height), 4, "两行之间留 4px")
        c.destroy()
    }

    function test_timeGridLinesAndRulerMetrics() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        const g = testCase.gridOf(c)
        compare(g.gutterWidth, 8, "刻度文字右内边距 8")
        const lines = testCase.findAll(g, "calendarSlotLine", [])
        compare(lines.length, 48 * 7)
        compare(lines[0].visible, false, "00:00 那条官方 :first-child::after { border: 0 }")
        compare(lines[1].visible, true)
        const columnLines = testCase.findAll(g, "calendarColumnLine", [])
        compare(columnLines.length, 7)
        compare(columnLines[6].visible, false, "最后一列右侧不画分隔线")
        compare(columnLines[0].visible, true)
        const hour = testCase.findAll(g, "calendarHourLabel", [])[0]
        compare(hour.y, -10, "刻度文字相对格线上移 10px")
        compare(hour.anchors.rightMargin, 8)
        c.destroy()
    }

    function test_threeIdenticalTimedEventsStaggerHorizontally() {
        // 官方那处 off-by-one：同组前两条重合（NaN% 落回 left:0），第三条起才按 (i−1)/n 挪
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); events: ["
            + "{ key: '1', start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11),"
            + " children: '一' },"
            + "{ key: '2', start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11),"
            + " children: '二' },"
            + "{ key: '3', start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11),"
            + " children: '三' }] }")
        wait(60)
        const items = testCase.findAll(testCase.gridOf(c), "calendarTimedEvent", [])
        compare(items.length, 3)
        compare(items[0].x, 0)
        compare(items[1].x, 0, "第二条也重合在 0")
        compare(items[2].x, 43.333333333333336, 1e-6, "第三条起 left = (i−1)/n")
        compare(items[0].width, 130)
        compare(items[2].width, 86.66666666666667, 1e-6, "宽度是 1 − left")
        c.destroy()
    }

    function test_currTimeLineFollowsTheClockNotDisplayValue() {
        const now = new Date()
        // 故意把当天摆在一个和现在差 6 小时的时刻上：线的位置只能来自真实时钟
        const anchor = new Date(now.getFullYear(), now.getMonth(), now.getDate(),
            (now.getHours() + 6) % 12, 0, 0)
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(" + anchor.getFullYear() + "," + anchor.getMonth()
            + "," + anchor.getDate() + "," + anchor.getHours() + ") }")
        wait(60)
        const lines = testCase.visibleBands(c, "calendarCurrTime")
        compare(lines.length, 1)
        const expected = CalendarDate.roundPos(CalendarDate.timePosition(new Date())) * 1440
        compare(lines[0].y, expected, 2)
        verify(Math.abs(lines[0].y - anchor.getHours() * 60) > 50,
            "线不在 displayValue 那一刻上（两者按构造至少差 50px）")
        c.destroy()

        const off = testCase.make("Calendar { width: 640; height: 400; mode: 'week' }")
        wait(60)
        off.showCurrTime = false
        wait(60)
        compare(testCase.visibleBands(off, "calendarCurrTime").length, 0,
            "showCurrTime 关掉这一列就不画")
        off.showCurrTime = true
        wait(60)
        compare(testCase.visibleBands(off, "calendarCurrTime").length, 1,
            "这一档只由 showCurrTime 决定，别和「是不是今天」互相顶包")
        off.destroy()
    }

    function test_eventBodyTextMetricsAndBranching() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: 'a', start: new Date(2026, 9, 8), children: '甲' }] }")
        wait(60)
        const band = testCase.visibleBands(testCase.monthOf(c), "calendarMonthEvent")[0]
        const text = testCase.findAll(band, "calendarEventText", [])[0]
        compare(text.elide, Text.ElideRight)
        compare(text.verticalAlignment, Text.AlignVCenter)
        const loader = testCase.findAll(band, "calendarEventNode", [])[0]
        compare(loader.active, false, "字符串那一档连 Loader 都不激活")
        c.destroy()
    }

    function test_renderPropsSwapTheDefaultNodesOut() {
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); renderTimeDisplay: Component {"
            + "Text { id: node; property var time: -1; text: 'T' + node.time } } }")
        wait(60)
        const g = testCase.gridOf(c)
        const labels = testCase.findAll(g, "calendarHourLabel", [])
        compare(labels.length, 24)
        for (let i = 0; i < labels.length; ++i)
            verify(!labels[i].visible, "自定义档接管后默认那串刻度要让位")
        const custom = testCase.findAll(g, "calendarTimeDisplay", [])
        compare(custom[0].y, -10, "自定义节点同样相对格线上移 10")
        c.destroy()

        const d = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); dateGridRender: Component {"
            + "Item { id: node; property var date: null; property string dateString: '' } } }")
        wait(60)
        const nodes = testCase.findAll(testCase.gridOf(d), "calendarDateGrid", [])
        compare(nodes[0].item.dateString, new Date(2026, 9, 4).toString(),
            "时间轴那一档注入的也是 date.toString()")
        d.destroy()
    }

    // ==================== 上游 renderDailyEvent 的三档分流 ====================

    function test_dailyTimedItemsFollowsUpstreamBranches() {
        // eventUtil.ts:336-355 三档：全天（由 foundation.ts:230 先分流掉）、两头缺一（补）、
        // 起止颠倒（换）。走 buildTimeline 时 parseEvent 已经把这三档抹平，所以直接喂
        // 逐日副本才测得到这三条分支。
        const day = new Date(2026, 9, 8)
        const list = CalendarDate.dailyTimedItems([
            { key: "ad", date: day, allDay: true,
                start: new Date(2026, 9, 8, 9), end: new Date(2026, 9, 8, 11) },
            { key: "half", date: day, start: new Date(2026, 9, 8, 9) },
            { key: "rev", date: day, start: new Date(2026, 9, 8, 11),
                end: new Date(2026, 9, 8, 9) },
            { key: "none", date: day },
            { key: "elsewhere", date: new Date(2026, 9, 9),
                start: new Date(2026, 9, 9, 9), end: new Date(2026, 9, 9, 11) }
        ], day)
        compare(list.length, 2, "全天那条与两头全缺的那条都不进这一列")
        compare(list[0].item.key, "half")
        compare(list[0].startPos, 0.375)
        compare(list[0].endPos, 0.417, "缺 end 那一档按 amendEvent 补一小时")
        compare(list[1].item.key, "rev")
        compare(list[1].startPos, 0.375, "起止颠倒的先换过来")
        compare(list[1].endPos, 0.458)
    }

    function test_allDayBandChecksBothEndsOfTheWindow() {
        const days = CalendarDate.timelineDays(new Date(2026, 9, 8), "week", [], 0)
        const rangeStart = days[0]
        const rangeEnd = CalendarDate.addDays(rangeStart, 7)
        const bands = CalendarDate.allDayBandItems([
            // 锚点正好压在窗口右缘：官方 isDateInRange 左闭右开 ⇒ 不算在内
            { date: rangeEnd, start: rangeEnd, end: CalendarDate.addDays(rangeEnd, 1),
                allDay: true, key: "tail" },
            // 锚点在窗口内但结束日在窗口之前
            { date: rangeStart, start: rangeStart, end: CalendarDate.addDays(rangeStart, -1),
                allDay: true, key: "stale" },
            { date: rangeStart, start: rangeStart, end: CalendarDate.addDays(rangeStart, 2),
                allDay: true, key: "ok" }
        ], days)
        compare(bands.length, 1, "两头都不许越界")
        compare(bands[0].item.key, "ok")
    }

    function test_allDayBandUsesOnlyTheFirstDayCopy() {
        // 起点落在窗口第一天（10/4，周日）的那条：逐日副本的 date 一天一个、start 却仍是
        // 原事件那天，只有「date == 锚点」那份留得下（官方 filter isSameDay(event.date,
        // startDate)）。少了这道校验，一根跨 5 天的带子会在第一天摞出 5 根。
        const days = CalendarDate.timelineDays(new Date(2026, 9, 4), "week", [], 0)
        const parsed = CalendarDate.buildTimeline([
            { key: "long", allDay: true, start: new Date(2026, 9, 4),
                end: new Date(2026, 9, 8) }
        ], days)
        compare(parsed.allDayLanes.length, 1)
        compare(parsed.allDayRows, 1)
        compare(parsed.allDayLanes[0].width, 0.714, "5 天 ÷ 7 列")
    }

    function test_monthBandsDoNotLeakIntoThePreviousWeek() {
        // 10/11 正好是第二周（weekEnd）那天：分桶用左闭右开，它只能进 10/11 起的那一周
        const c = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1); events: ["
            + "{ key: 'x', allDay: true, start: new Date(2026, 9, 11), children: '一条' }] }")
        wait(60)
        const m = testCase.monthOf(c)
        compare(testCase.countAll(m, "calendarMonthEvent"), 1)
        compare(m.weeks[1].display.length, 0, "上一周不该收到这条")
        compare(m.weeks[2].display.length, 1)
        c.destroy()
    }

    function test_currTimeLineTimerFollowsShowCurrTime() {
        // 官方 initCurrTime（foundation.ts:124-130）：showCurrTime 关上时连那条 rAF 都不启动
        // ⇒ currPos 一直留在 0，而不是「线看不见但位置一直在刷」
        const off = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8); showCurrTime: false }")
        wait(80)
        compare(testCase.gridOf(off).currPos, 0)
        off.destroy()

        const on = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; showCurrTime: true }")
        wait(80)
        verify(testCase.gridOf(on).currPos > 0, "开着时启动即刷一次")
        on.destroy()
    }

    function test_stackedCalendarsOnlyTheFrontOneReacts() {
        // 格子的 handler 走 ReleaseWithinBounds（按下即独占 grab）。换成缺省的 DragThreshold
        // 只取 passive grab ⇒ 叠在同一处窗口坐标上的第二台也会跟着发一次 clicked
        const back = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        const front = testCase.make("Calendar { width: 640; height: 400; mode: 'month'"
            + "; displayValue: new Date(2026, 9, 1) }")
        wait(60)
        let backClicks = 0
        let frontClicks = 0
        back.clicked.connect(function () { backClicks += 1 })
        front.clicked.connect(function () { frontClicks += 1 })
        const cell = testCase.dayCell(testCase.monthOf(front), 1, 1)
        mouseClick(cell, cell.width / 2, cell.height / 2)
        wait(40)
        compare(frontClicks, 1)
        compare(backClicks, 0, "后面那台不该吃这次点击")
        front.destroy()
        back.destroy()

        // 时间轴那一档同理：格子（半小时格）的 handler 也得独占
        const gBack = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        const gFront = testCase.make("Calendar { width: 640; height: 400; mode: 'week'"
            + "; displayValue: new Date(2026, 9, 8) }")
        wait(60)
        let gBackClicks = 0
        let gFrontClicks = 0
        gBack.clicked.connect(function () { gBackClicks += 1 })
        gFront.clicked.connect(function () { gFrontClicks += 1 })
        const slot = testCase.findAll(testCase.gridOf(gFront), "calendarSlot", [])[20]
        mouseClick(slot, slot.width / 2, slot.height / 2)
        wait(40)
        compare(gFrontClicks, 1)
        compare(gBackClicks, 0)
        gFront.destroy()
        gBack.destroy()
    }
}
