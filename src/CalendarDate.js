.pragma library

// 日历的日期与事件处理。对应 Semi 的 semi-foundation/calendar/{eventUtil,foundation}.ts
// 里那套解析管线。纯函数、无状态，所以用 .pragma library 让几个视图共享同一份。
//
// 官方这几条口径值得先记住，端口逐条对齐：
//   · 月视图把**每一条**事件都当全天条带来摆（monthCalendar 走的是
//     `parseAllDayEvent(event, event.allDay, currDate)`，而 `allDay` 形参的缺省值是 true，
//     传 `undefined` 进去就取到 true —— eventUtil.ts:144、foundation.ts:369）。
//   · 时间轴里跨天满 24 小时的定时事件会被**升级**成全天条带（eventUtil.ts:182）。
//   · 只给了 start 或只给了 end 的定时事件由 amendEvent 补另一头：同一小时内就 ±1h，
//     否则补到当天 00:00 / 24:00（eventUtil.ts:66-76）。两头都没有 ⇒ 丢掉。
//   · 官方 amendEvent / parseEvent 是**就地改写调用方那个事件对象**的（eventUtil.ts:71-73、
//     :174，start>end 还会就地交换）。端口只在自己的副本上改，不动用户数据 —— 这是有意的
//     偏离，观感一致、副作用少一条。

// ==================== 日期数学 ====================

function startOfDay(value) {
    const d = new Date(value);
    d.setHours(0, 0, 0, 0);
    return d;
}

function endOfDay(value) {
    const d = new Date(value);
    d.setHours(23, 59, 59, 999);
    return d;
}

function addDays(value, days) {
    const d = new Date(value);
    d.setDate(d.getDate() + days);
    return d;
}

function addHours(value, hours) {
    const d = new Date(value);
    d.setHours(d.getHours() + hours);
    return d;
}

// 与 date-fns 的 addMonths 一致：目标月没有那一天时夹到月末（1/31 +1 月 = 2/28）
function addMonths(value, months) {
    const day = value.getDate();
    const d = new Date(value.getFullYear(), value.getMonth() + months, 1);
    d.setDate(Math.min(day, daysInMonth(d)));
    d.setHours(value.getHours(), value.getMinutes(), value.getSeconds(), value.getMilliseconds());
    return d;
}

function addYears(value, years) {
    return addMonths(value, years * 12);
}

function isBefore(a, b) {
    return a.getTime() < b.getTime();
}

function isAfter(a, b) {
    return a.getTime() > b.getTime();
}

function startOfMonth(value) {
    return new Date(value.getFullYear(), value.getMonth(), 1);
}

function endOfMonth(value) {
    return new Date(value.getFullYear(), value.getMonth() + 1, 0);
}

function isSameDay(a, b) {
    return a.getFullYear() === b.getFullYear()
        && a.getMonth() === b.getMonth()
        && a.getDate() === b.getDate();
}

function isSameMonth(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();
}

// 日历天差值（忽略时分秒）
function diffDays(a, b) {
    const ms = startOfDay(a).getTime() - startOfDay(b).getTime();
    return Math.round(ms / 86400000);
}

function startOfWeek(value, weekStartsOn) {
    const lead = (value.getDay() - weekStartsOn + 7) % 7;
    return startOfDay(addDays(value, -lead));
}

function isWeekend(value) {
    const day = value.getDay();
    return day === 0 || day === 6;
}

function daysInMonth(value) {
    return endOfMonth(value).getDate();
}

// 一个月横跨几个周行：这个月第一天之前的空位数 + 当月天数，再向上取整
function weeksInMonth(value, weekStartsOn) {
    const first = startOfMonth(value);
    const lead = (first.getDay() - weekStartsOn + 7) % 7;
    return Math.ceil((lead + daysInMonth(value)) / 7);
}

// ==================== 文案 ====================
// 官方这几串全部走 date-fns 的 locale（`format(date, 'EEE' | 'd' | 'LLL')`），不是 Semi
// 自己的 locale 表 —— 实测 date-fns 2.30 的 zh-CN：EEE = 「周四」、d = 「8」、LLL = 「10月」。
// 本库只做中文，所以把中文档直接写死（Semi 自己那 5 条 locale 串见下面三行）。

const WEEKDAYS = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
const ALL_DAY_TEXT = "全天";          // locale.allDay
const REMAINING_TEXT = "还有${remained}项";   // locale.remaining
const DATE_SUFFIX = "日";             // locale.datestring

function weekdayName(value) {
    return WEEKDAYS[value.getDay()];
}

function monthLabel(value) {
    return (value.getMonth() + 1) + "月";
}

function dayNumber(value) {
    return String(value.getDate());
}

// 端口自己加的便利串（官方没有头部，也就没有「标题」这一说）：给调用方摆头部用
function monthTitle(value) {
    return value.getFullYear() + "年" + (value.getMonth() + 1) + "月";
}

// 官方 remaining 的替换法：locale.remaining.replace('${remained}', String(remained))
function remainingText(count) {
    return REMAINING_TEXT.replace("${remained}", String(count));
}

// 月网格：每周一行、每行 7 天，含前后补齐的相邻月日期
function monthGrid(displayValue, weekStartsOn) {
    const first = startOfMonth(displayValue);
    const lead = (first.getDay() - weekStartsOn + 7) % 7;
    const gridStart = addDays(first, -lead);
    const weekCount = weeksInMonth(displayValue, weekStartsOn);
    const today = new Date();

    const weeks = [];
    for (let w = 0; w < weekCount; ++w) {
        const days = [];
        for (let d = 0; d < 7; ++d) {
            const date = addDays(gridStart, w * 7 + d);
            days.push({
                date: date,
                day: date.getDate(),
                inMonth: isSameMonth(date, displayValue),
                isToday: isSameDay(date, today),
                isWeekend: isWeekend(date)
            });
        }
        weeks.push(days);
    }
    return weeks;
}

// ==================== 事件解析 ====================

// 某时刻在当天里的位置比例：0 是 0 点、1 是 24 点。对应 eventUtil.ts:51-55 的 getPos
// （只读时分秒，不读毫秒，也不看日期是哪天）。
function timePosition(value) {
    return (value.getHours() * 3600 + value.getMinutes() * 60 + value.getSeconds()) / 86400;
}

// eventUtil.ts:49
function roundPos(value) {
    return Math.round(value * 1000) / 1000;
}

// eventUtil.ts:57 —— 注意是「键在不在」而不是真值：`'allDay' in event && event.allDay`
function isAllDayEvent(event) {
    return "allDay" in event && Boolean(event.allDay);
}

// eventUtil.ts:25-32 的 copyEvent：浅拷贝一份，再把传进来的 date/start/end 盖上去。
// 传 null 的那几个参数**保留原值**（官方就是靠这条把原始 start/end 留在每一份逐日副本上）。
function copyItem(event, date, start, end, allDay) {
    const res = {};
    for (const key in event)
        res[key] = event[key];
    res.date = date;
    if (start)
        res.start = start;
    if (end)
        res.end = end;
    res.allDay = Boolean(allDay);
    return res;
}

// eventUtil.ts:66-76：缺哪头补哪头，两头都没有返回 null。端口不改原对象。
function amendEvent(event) {
    const res = {};
    for (const key in event)
        res[key] = event[key];
    const start = res.start;
    const end = res.end;
    if (!start && !end)
        return null;
    if (!start)
        res.start = isSameDay(end, addHours(end, -1)) ? addHours(end, -1) : startOfDay(end);
    else
        res.end = isSameDay(start, addHours(start, 1)) ? addHours(start, 1) : endOfDay(start);
    return res;
}

// eventUtil.ts:144-157。allDay 形参的缺省值是 **true**，所以传 undefined 进来算 true ——
// 月视图正是靠这一点把每条事件都摆成全天条带（foundation.ts:369）。
function parseAllDayEvent(event, allDay, currDate) {
    const flag = allDay === undefined ? true : Boolean(allDay);
    const res = [];
    const start = event.start;
    const end = event.end;
    if (start && end) {
        const span = diffDays(end, start);
        for (let day = 0; day <= span; ++day)
            res.push(copyItem(event, addDays(start, day), null, null, flag));
    } else {
        const date = start || end || currDate;
        res.push(copyItem(event, date ? startOfDay(date) : null, null, null, flag));
    }
    return res;
}

// eventUtil.ts:165-189：一条事件 → 逐日条目。
//   全天            → 覆盖到的每一天一条（start/end 保持原值）
//   同一天          → 一条定时
//   跨天不足 24 小时 → 两条：首日铺到 24:00、末日从 0:00 起
//   跨天满 24 小时   → 升级成全天条带
//   只给了一头      → amendEvent 补另一头，再按同一天处理
function parseEvent(event, currDate) {
    if (isAllDayEvent(event))
        return parseAllDayEvent(event, true, currDate);

    const start = event.start;
    const end = event.end;
    const res = [];
    if (start && end) {
        // 官方在这里就地 `[event.start, event.end] = [event.end, event.start]`
        // （eventUtil.ts:143-145），后面 parseAllDayEvent 读的就是交换过的那一对。
        // 端口不改调用方的对象 ⇒ 交换只发生在副本上，长跨度的那条必须显式走副本。
        let target = event;
        if (!isBefore(start, end))
            target = copyItem(event, null, end, start);
        if (isSameDay(start, end)) {
            res.push(copyItem(target, startOfDay(start), null, null, false));
        } else if (Math.abs(end.getTime() - start.getTime()) / 3600000 < 24) {
            res.push(copyItem(target, startOfDay(start), null, endOfDay(start), false));
            res.push(copyItem(target, startOfDay(end), startOfDay(end), null, false));
        } else {
            return parseAllDayEvent(target, true, currDate);
        }
        return res;
    }

    const amend = amendEvent(event);
    if (amend === null)
        return res;
    res.push(copyItem(amend, startOfDay(amend.start), null, null, false));
    return res;
}

// 把一批事件按声明序排好（官方是 `events.sort(...)` **就地排**，见 foundation.ts:361-369；
// 端口排副本。同一时刻的按声明序兜底，否则「先声明的那条在上面」就保不住）。
function orderedEvents(events) {
    const source = events === undefined || events === null ? [] : events;
    const ordered = [];
    for (let i = 0; i < source.length; ++i)
        ordered.push({ item: source[i], order: i });
    ordered.sort(function (a, b) {
        const at = a.item.start ? a.item.start.getTime() : 0;
        const bt = b.item.start ? b.item.start.getTime() : 0;
        if (at !== bt)
            return at - bt;
        return a.order - b.order;
    });
    return ordered;
}

// ==================== 时间轴（day / week / range 共用） ====================

// 时间轴要显示的日期列。day → 1 天；week → 从周起始日算的 7 天；
// range → **左闭右开**（foundation.ts:201-204：len = diffDays(range[1], range[0])，
// 然后 `for ind in [0, len)` ⇒ [D, D] 是 0 列，[7-01, 7-07] 到 7-06 为止）。
function timelineDays(displayValue, mode, range, weekStartsOn) {
    const days = [];
    if (mode === "day") {
        days.push(startOfDay(displayValue));
    } else if (mode === "range" && range !== undefined && range !== null
               && range.length >= 2 && range[0] && range[1]) {
        const len = diffDays(range[1], range[0]);
        const from = startOfDay(range[0]);
        for (let i = 0; i < len; ++i)
            days.push(addDays(from, i));
    } else {
        const from = startOfWeek(displayValue, weekStartsOn);
        for (let i = 0; i < 7; ++i)
            days.push(addDays(from, i));
    }
    return days;
}

// 官方 getParseDailyEvents 的单列版（foundation.ts:236-271）：挑出这一天的定时事件，
// 算出 startPos / endPos，再把**起止完全相同**的那几条横向错开。
//
// 官方这里有个 off-by-one：`curCount` 读的是自增**前**的值，于是同组第一条算出 "NaN%"
// （CSS 无效 ⇒ 落回样式表的 left:0）、第二条读到 0 ⇒ 也是 left:0，从第三条才开始错开。
// 端口按可观察结果复刻：同组前两条重合，第三条起 left = (i−1)/n。
// 部分重叠（起止不完全相同）的事件官方**不做任何排布**，全部 left:0 叠在一起。
function dailyTimedItems(items, day) {
    const list = [];
    for (let i = 0; i < items.length; ++i) {
        const item = items[i];
        if (item.allDay || !isSameDay(item.date, day))
            continue;
        let from = item.start;
        let to = item.end;
        // 上游 renderDailyEvent 的三档（eventUtil.ts:336-355）：全天档不算（由调用方
        // foundation.ts:230 先分流）、两头缺一档用 amendEvent 补、起止颠倒就交换。
        // 走 buildTimeline 时 parseEvent 已经把这三种都抹平了 ⇒ 只有直接调用才走得到。
        if (!from && !to)
            continue;   // 上游这一档 amendEvent 返回 null 会当场抛 ⇒ 只记录，不抄崩溃
        if (!from || !to) {
            const amend = amendEvent(item);
            from = amend.start;
            to = amend.end;
        }
        if (!isBefore(from, to)) {
            from = to;
            to = item.start;
        }
        list.push({
            start: from,
            end: to,
            startPos: roundPos(timePosition(from)),
            endPos: roundPos(timePosition(to)),
            item: item
        });
    }

    const total = {};
    for (let i = 0; i < list.length; ++i) {
        const key = list[i].startPos + "-" + list[i].endPos;
        total[key] = total[key] === undefined ? 1 : total[key] + 1;
    }
    const seen = {};
    for (let i = 0; i < list.length; ++i) {
        const key = list[i].startPos + "-" + list[i].endPos;
        const index = seen[key] === undefined ? 0 : seen[key];
        seen[key] = index + 1;
        list[i].left = index < 2 ? 0 : (index - 1) / total[key];
    }
    return list;
}

// 顶部全天条带的输入：官方按 `startOfDay(event.start)` 分桶、只留 `isSameDay(date, 桶键)`
// 的那一份副本（foundation.ts:283-292），所以一条事件只会有一根带子；起点在窗口左边的
// 外面时官方把它重新挂到 rangeStart 上（eventUtil.ts:232-246 的 filterEvents）。
function allDayBandItems(items, days) {
    if (days.length === 0)
        return [];
    const rangeStart = days[0];
    const rangeEnd = addDays(rangeStart, days.length);
    const res = [];
    for (let i = 0; i < items.length; ++i) {
        const item = items[i];
        if (!item.allDay)
            continue;
        let anchor = item.start ? startOfDay(item.start) : item.date;
        if (!anchor)
            continue;
        if (anchor.getTime() >= rangeEnd.getTime())
            continue;
        if (item.end && isBefore(item.end, rangeStart))
            continue;
        // 官方把窗口之前的那一桶整体挪到 rangeStart（filterEvents），但紧接着
        // `_parseWeeklyEvents` 里还有一道 `isSameDay(event.date, startDate)` ⇒ 逐日副本里
        // 只有「日期正好是窗口第一天」的那一份留下。少了这一道，一条跨 32 天的事件会在
        // 第一天摞出 32 根带子（实测过）。
        if (isBefore(anchor, rangeStart)) {
            if (!isSameDay(item.date, rangeStart))
                continue;
            anchor = rangeStart;
        } else if (!isSameDay(anchor, item.date)) {
            continue;
        }
        res.push({ date: anchor, end: item.end ? item.end : null, item: item });
    }
    return res;
}

// 把条带分到若干「行」上：同一列已有条带就换下一行，并算出横向位置。
// 对应 eventUtil.ts:253-290 的 parseRangeAllDayEvent。
//
// 调用方要先把事件排好序 —— 这里不再自己排，否则同一天的事件会被重排。
// 返回二维数组 lanes[laneIndex][columnIndex]，只有事件的第一格带位置信息
// （leftPos / width / topInd），其余格子放同一个条带的引用，用于占位。
function assignLanes(bands, rangeStart, rangeEnd, columnCount) {
    const lanes = [];

    for (let n = 0; n < bands.length; ++n) {
        const band = bands[n];
        const column = diffDays(band.date, rangeStart);
        // 上游 parseRangeAllDayEvent 没有「列号出界」这道闸 —— 窗口外的带子在 filterEvents /
        // allDayBandItems 那层就被滤掉了，到这里的 column 必在 [0, columnCount) 内。

        let lane = 0;
        while (lanes[lane] !== undefined && lanes[lane][column] !== undefined)
            lane += 1;

        let span = 0;
        if (band.end) {
            const raw = diffDays(band.end, band.date);
            span = Math.max(0, Math.min(raw, columnCount - 1 - column));
        }

        const leftPos = roundPos(column / columnCount);
        // 官方是 `Math.min(1 − round(j/len), round((dateLength+1)/len))`；end 掉到窗口外面时
        // dateLength 会取 diffDays(rangeEnd, startDate)，算出的宽比窗口还宽，最后仍被
        // 「1 − leftPos」这一头夹住 ⇒ 端口直接在 span 上夹，结果同一格。
        const width = Math.min(1 - leftPos, roundPos((span + 1) / columnCount));
        const positioned = {};
        for (const key in band)
            positioned[key] = band[key];
        positioned.leftPos = leftPos;
        positioned.width = width;
        positioned.topInd = lane;

        if (lanes[lane] === undefined)
            lanes[lane] = [];
        // 官方那侧是无条件 `parsed[i][j + dist] = …`（span 已经由 dateLength 夹过），端口
        // 也在 span 上夹 ⇒ 正常数据这里越不到界。不另加 break：分桶一旦漏进来一条越界的，
        // 就让它像官方那样落成一个 leftPos=1 的零宽带子，好让用例咬得住（见 tst 的
        // test_monthBandsDoNotLeakIntoThePreviousWeek）。
        for (let dist = 0; dist <= span; ++dist)
            lanes[lane][column + dist] = dist === 0 ? positioned : band;
    }

    return lanes;
}

// 把 lanes 拍平，只留带位置信息的那一份（跨天条带只出现一次）
function flattenLanes(lanes) {
    const res = [];
    for (let i = 0; i < lanes.length; ++i) {
        for (let j = 0; j < lanes[i].length; ++j) {
            const item = lanes[i][j];
            if (item !== undefined && item.leftPos !== undefined)
                res.push(item);
        }
    }
    return res;
}

// 按列收集条带数（官方 collectDailyEvents 的等价物）
function countByColumn(lanes, columnCount) {
    const counts = [];
    for (let c = 0; c < columnCount; ++c)
        counts.push(0);
    for (let i = 0; i < lanes.length; ++i)
        for (let j = 0; j < lanes[i].length; ++j)
            if (lanes[i][j] !== undefined)
                counts[j] += 1;
    return counts;
}

// 把 lanes 转置成 columns[column][lane] —— 官方 collectDailyEvents（eventUtil.ts:321-334）。
// 「还有 N 项」点开的那张卡片列的就是这一列的全部条带，占位的那一份（没有 leftPos）也算，
// 所以跨天事件在第二天那列里同样会出现一次。
function collectColumns(lanes, columnCount) {
    const columns = [];
    for (let c = 0; c < columnCount; ++c)
        columns.push([]);
    for (let i = 0; i < lanes.length; ++i) {
        for (let j = 0; j < lanes[i].length; ++j) {
            if (lanes[i][j] === undefined)
                continue;
            columns[j][i] = lanes[i][j];
        }
    }
    return columns;
}

// 最高那一行的行号 + 1 —— 官方 calcRowHeight（eventUtil.ts:83-86），空数组时是 1
function rowHeight(lanes) {
    let rows = 0;
    for (let i = 0; i < lanes.length; ++i)
        if (lanes[i] !== undefined)
            rows = i + 1;
    return rows === 0 ? 1 : rows;
}

// 时间轴一整屏的数据：每列的定时事件 + 顶部全天条带
function buildTimeline(events, days) {
    const items = [];
    const ordered = orderedEvents(events);
    for (let i = 0; i < ordered.length; ++i) {
        // currDate 传 null：官方时间轴那条路走的是 `parseAllDayEvent(event)`，第三形参缺省
        // 是 undefined ⇒ 没有起止的全天事件算出 Invalid Date、落不进任何一天（文档却说它会
        // 挂到 displayValue 那天 —— 那句只在月视图成立，见 parseMonthlyEvents）。
        const parts = parseEvent(ordered[i].item, null);
        for (let j = 0; j < parts.length; ++j)
            items.push(parts[j]);
    }

    const timed = [];
    for (let d = 0; d < days.length; ++d)
        timed.push(dailyTimedItems(items, days[d]));

    const rangeStart = days.length > 0 ? days[0] : startOfDay(new Date());
    const rangeEnd = addDays(rangeStart, days.length);
    const lanes = assignLanes(allDayBandItems(items, days), rangeStart, rangeEnd, days.length);

    return {
        items: items,
        timed: timed,
        allDayLanes: flattenLanes(lanes),
        allDayRows: rowHeight(lanes)
    };
}

// ==================== 月视图 ====================

// 月视图一整屏的数据：每周一行，行内 7 天 + 摆好的条带 + 每列占了几条。
//
// 官方按 `getWeekOfMonth(date) − 1` 分桶，并且自己留了注释说月初月末会算错
// （foundation.ts:376-396 那段「WeekInd calculation error」）。端口按「条目的日期落在
// 这一周的窗口里」分桶 —— 同一件事的正确版本，观感一致，少一条上游 bug。
function parseMonthlyEvents(events, displayValue, weekStartsOn) {
    const grid = monthGrid(displayValue, weekStartsOn);
    const ordered = orderedEvents(events);
    const items = [];
    for (let i = 0; i < ordered.length; ++i) {
        // 官方这里对**每一条**事件都走 parseAllDayEvent（allDay 传 event.allDay，
        // undefined 落到形参缺省值 true），所以定时事件在月视图里也是一根横条
        const parts = parseAllDayEvent(ordered[i].item, ordered[i].item.allDay, displayValue);
        for (let j = 0; j < parts.length; ++j)
            items.push(parts[j]);
    }

    const weeks = [];
    for (let w = 0; w < grid.length; ++w) {
        const weekStart = grid[w][0].date;
        const weekEnd = addDays(weekStart, 7);
        const inWeek = [];
        for (let i = 0; i < items.length; ++i) {
            const item = items[i];
            if (!item.date)
                continue;
            // 一条事件只由它「第一天」那一份副本代表（官方 filter isSameDay(event.date, startDate)）
            const anchor = item.start ? startOfDay(item.start) : item.date;
            if (!isSameDay(anchor, item.date))
                continue;
            if (item.date.getTime() >= weekStart.getTime()
                && item.date.getTime() < weekEnd.getTime())
                inWeek.push({ date: item.date, end: item.end, item: item });
        }
        const lanes = assignLanes(inWeek, weekStart, weekEnd, 7);
        weeks.push({
            days: grid[w],
            display: flattenLanes(lanes),
            columns: collectColumns(lanes, 7),
            counts: countByColumn(lanes, 7)
        });
    }
    return weeks;
}
