pragma ComponentBehavior: Bound

import QtQuick
import Semi
import "CalendarDate.js" as CalendarDate

// 时间轴网格，day / week / range 三个视图共用：N 个日期列 + 一条 24 小时刻度。
//
// 规格全部照 calendar.scss + dayCol.tsx / timeCol.tsx / weekCalendar.tsx：
//   · 一小时 60px（`$height-calendar_day_grid`），骨架 li 是 30px（`$height-calendar_time_grid`
//     = 60 × 0.5），25 小时 × 2 格 = 50 格、最后两格被 CSS 强制 `height:0` ⇒ 48 × 30 = **1440px**。
//     官方把这个 1440 当缩放基准（`scrollHeight`，挂载时读一次、之后不再读），
//     事件的 top/height 都是 `比例 × 1440`。
//   · 刻度列 70px（`$width-calendar_day-minWidth`）、右内边距 8、文字相对格线**上移 10px**，
//     0 点那一格官方 `list.splice(0, 1, '')` 直接抹平 ⇒ 顶部没有「上午0时」。
//   · 列最小宽 130px（`$width-calendar_day_grid-minWidth`）⇒ 列数多了横向滚。
//   · 吸顶层 z-index 20、吸左列 z-index 10、当前时间线 8、事件 5、格线 3。
//   · 顶部那条「全天」带：行高 26（`$height-calendar_allDay`），一根带子占一行，
//     跨几天就横铺几列（官方 `-event-allday` 是绝对定位 + `left/width` 百分比）。
//   · 定时事件：**官方没有任何重叠排布**，只把「起止完全相同」的那几条横向错开
//     （foundation.ts:253-271），部分重叠的直接 left:0 全叠在一起。错开那条还有个
//     off-by-one（读的是自增前的计数）⇒ 同组前两条重合、从第三条才开始挪。端口照抄，
//     见 CalendarDate.dailyTimedItems。
//   · 点击落在 30 分钟一格的骨架 li 上 ⇒ `clicked(new Date(y, m, d, hour, minute))`，
//     时分秒由点中的那一格决定（displayValue 自己的时刻被丢掉，formatCbValue 只取年月日）。
//     点事件条不算点格子（官方 pointer-events 那一条）。
//   · 当前时间线：只有 `isSameDay(displayValue, 真实今天)` 那一列画，位置取真实时钟，
//     官方用一条自我重排的 requestAnimationFrame 节流到 30 秒刷一次（foundation.ts:169-187），
//     端口用等间隔 Timer。线是 1px 的 `border-top`、圆点 8×8 且 `margin-top:-4`，z 序在事件之上。
//   · day 档**没有日期头部**（dayCalendar.tsx 压根没有 renderHeader），只有那条全天带；
//     week / range 才有星期行。range 官方复用 week 的全套类名（没有 -range 规则）。
//   · scrollTop 官方只在 componentDidMount 写一次 `dom.scrollTop = props.scrollTop`，
//     之后改属性不动 ⇒ 端口同样是一次性的。
Item {
    id: control

    property var days: []
    property var displayValue: new Date()
    property var events: []
    property string mode: "week"
    property bool showCurrTime: true
    property bool markWeekend: false
    property real minEventHeight: -9007199254740991
    property int scrollTop: 400
    property Component dateGridRender: null
    property Component renderTimeDisplay: null
    property Component renderDateDisplay: null
    property Component allDayEventsRender: null

    signal clicked(var value)

    readonly property int hourCount: 24
    readonly property int hourHeight: 60
    readonly property int halfHourHeight: 30
    readonly property int bodyHeight: 1440
    readonly property int timeColumnWidth: 70
    readonly property int columnMinWidth: 130
    readonly property int allDayRowHeight: 26
    readonly property int dateHeaderHeight: 27
    /// `.semi-calendar-week .semi-calendar-week-tag { text-align: right; line-height: 26 }`
    /// + `:first-child { padding-right: 8 }` —— 头部最左那一格（当月）自己把 `-tag` 的
    /// font-size-regular（14 / 20）那一档行高顶掉了
    readonly property int tagLineHeight: 26
    readonly property int tagPaddingRight: 8
    /// `-grid-row li > span { line-height: 26px }` —— 日号与星期共用这一条行盒（对齐的基准）
    readonly property int dateSpanHeight: 26
    readonly property int todayMarkSize: 24
    readonly property int gutterWidth: 8

    readonly property var timeline: CalendarDate.buildTimeline(control.events, control.days)
    readonly property int allDayRows: control.timeline.allDayRows
    readonly property bool hasDateHeader: control.mode !== "day"
    readonly property int headerHeight: (control.hasDateHeader ? control.dateHeaderHeight : 0)
        + control.allDayRows * control.allDayRowHeight + 1
    readonly property int columnWidth: control.days.length > 0
        ? Math.max(control.columnMinWidth,
            Math.floor((control.width - control.timeColumnWidth) / control.days.length))
        : control.columnMinWidth

    // 当前时间线的位置（官方 getCurrLocation 每 30s 刷一次的那个 currPos）
    property real currPos: 0

    function refreshCurrTime() {
        control.currPos = CalendarDate.roundPos(CalendarDate.timePosition(new Date()));
    }

    function eventTop(startPos) {
        return startPos * control.bodyHeight;
    }

    function eventHeightOf(startPos, endPos) {
        return Math.max(control.minEventHeight, (endPos - startPos) * control.bodyHeight);
    }

    function slotDate(day, index) {
        return new Date(day.getFullYear(), day.getMonth(), day.getDate(),
            Math.floor(index / 2), (index % 2) * 30, 0);
    }

    implicitWidth: control.timeColumnWidth + control.days.length * control.columnWidth
    // 列最小宽 130 ⇒ 七列时内容比容器宽，横向溢出由这里裁掉
    //（官方是 `.semi-calendar-week { overflow: auto }` 那一层在管；端口不真做横向滚动，
    // 但表头那一行不吃 Flickable 的 clip，不裁会画到容器外面去）
    clip: true

    Timer {
        id: currTimer

        // 官方那条 rAF 循环节流到 30s，端口用等间隔定时器对齐
        interval: 30000
        running: control.showCurrTime
        repeat: true
        triggeredOnStart: true
        onTriggered: control.refreshCurrTime()
    }

    // ---- 吸顶区：星期行 + 全天行 ----
    Item {
        id: headerArea

        objectName: "calendarStickyTop"
        width: parent.width
        height: control.headerHeight
        z: 20

        Rectangle {
            anchors.fill: parent
            color: Theme.current.colorBg2
        }

        // 星期行（day 档没有这一行）
        Item {
            id: weekdayRow

            width: parent.width
            height: control.hasDateHeader ? control.dateHeaderHeight : 0
            visible: control.hasDateHeader

            // 靠左那一格（官方 `-tag -sticky-left`，min-width 70）：当月 LLL。
            // `.semi-calendar-week .semi-calendar-week-tag { text-align: right; line-height: 26 }`
            // + `:first-child { padding-right: 8 }` ⇒ 字贴这一格的右缘、离列边界留 8。
            // day 档官方压根没有 -header 这层 ⇒ 用 Loader，别留一个看不见的节点
            Loader {
                x: 0
                y: 0
                width: control.timeColumnWidth
                active: control.hasDateHeader
                sourceComponent: Component {
                    Text {
                        objectName: "calendarMonthLabel"
                        text: CalendarDate.monthLabel(control.displayValue)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeRegular
                        // CSS 的 line-height 是半行距上下各分一半 ⇒ 定高 + verticalAlignment，
                        // 不用 lineHeight + FixedHeight（Qt 把多出来的高度全垫在下面，字会浮高）
                        height: control.tagLineHeight
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignRight
                        rightPadding: control.tagPaddingRight
                    }
                }
            }

            Item {
                id: weekdayCells

                objectName: "calendarWeekdayCells"
                x: control.timeColumnWidth - viewport.contentX
                width: control.days.length * control.columnWidth
                height: parent.height

                Repeater {
                    // `-header` 那一层只在多列档存在
                    model: control.hasDateHeader ? control.days : []

                    delegate: Item {
                        id: weekdayCell

                        required property var modelData
                        required property int index

                        objectName: "calendarDateHeader"
                        readonly property bool today: CalendarDate.isSameDay(
                            weekdayCell.modelData, new Date())

                        x: weekdayCell.index * control.columnWidth
                        width: control.columnWidth
                        height: weekdayCells.height

                        Loader {
                            objectName: "calendarDateDisplay"
                            anchors.centerIn: parent
                            active: control.renderDateDisplay !== null
                            sourceComponent: control.renderDateDisplay
                            onLoaded: {
                                item.date = weekdayCell.modelData;
                                item.dateString = weekdayCell.modelData.toString();
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            visible: control.renderDateDisplay === null

                            // 日号（今天那一档 `-today-date` 是 24×24 的圆，圆在 26 的行盒里居中）
                            Item {
                                id: dateMark

                                width: weekdayCell.today ? control.todayMarkSize : markText.width
                                height: control.dateSpanHeight

                                Rectangle {
                                    objectName: "calendarTodayDot"
                                    anchors.centerIn: parent
                                    visible: weekdayCell.today
                                    width: control.todayMarkSize
                                    height: control.todayMarkSize
                                    radius: width / 2
                                    color: Theme.current.colorPrimary
                                }

                                Text {
                                    id: markText

                                    objectName: "calendarDateNumber"
                                    anchors.centerIn: parent
                                    text: CalendarDate.dayNumber(weekdayCell.modelData)
                                    color: weekdayCell.today
                                        ? Theme.current.colorBg1 : Theme.current.colorText0
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }

                            // `:last-child { padding: 0 4px }`；行盒同 `-grid-row li > span`（26）
                            Text {
                                objectName: "calendarDateHeaderWeekday"

                                height: control.dateSpanHeight
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 4
                                rightPadding: 4
                                text: CalendarDate.weekdayName(weekdayCell.modelData)
                                color: Theme.current.colorText2
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }

                        Rectangle {
                            visible: weekdayCell.index < control.days.length - 1
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 1
                            color: Theme.current.colorBorder
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.current.colorBorder
            }
        }

        // 全天事件行
        Item {
            id: allDayArea

            y: control.hasDateHeader ? control.dateHeaderHeight : 0
            width: parent.width
            height: control.allDayRows * control.allDayRowHeight + 1

            Item {
                id: allDayLabel

                width: control.timeColumnWidth
                height: parent.height

                Text {
                    objectName: "calendarAllDayLabel"
                    anchors.right: parent.right
                    anchors.rightMargin: control.gutterWidth
                    anchors.top: parent.top
                    text: CalendarDate.ALL_DAY_TEXT
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: control.allDayRowHeight
                    lineHeightMode: Text.FixedHeight
                }
            }

            Loader {
                id: allDayCustom

                objectName: "calendarAllDayCustom"
                x: control.timeColumnWidth
                width: parent.width - control.timeColumnWidth
                height: parent.height
                active: control.allDayEventsRender !== null
                sourceComponent: control.allDayEventsRender
                // 官方把**未经过滤的 props.events 原样**交给 allDayEventsRender
                // （dayCalendar.tsx:115 等三处），定时事件、窗口外的事件都在里面
                onLoaded: item.events = control.events
            }

            Item {
                id: allDayColumns

                objectName: "calendarAllDayColumns"
                x: control.timeColumnWidth - viewport.contentX
                width: control.days.length * control.columnWidth
                height: parent.height
                clip: true
                visible: control.allDayEventsRender === null

                Repeater {
                    // 官方是二选一：给了 allDayEventsRender 就不再造默认那些条带
                    model: control.allDayEventsRender === null
                        ? control.timeline.allDayLanes : []

                    delegate: Item {
                        id: allDayItem

                        required property var modelData

                        objectName: "calendarBand"
                        x: allDayItem.modelData.leftPos * allDayColumns.width
                        y: allDayItem.modelData.topInd * control.allDayRowHeight
                        width: allDayItem.modelData.width * allDayColumns.width
                        height: control.allDayRowHeight
                        clip: true

                        CalendarEventBody {
                            anchors.fill: parent
                            event: allDayItem.modelData.item
                        }

                        // 官方 pointer-events 那一档：条子吃点击
                        TapHandler {
                            acceptedButtons: Qt.AllButtons
                            gesturePolicy: TapHandler.WithinBounds
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.current.colorBorder
            }
        }
    }

    // ---- 主体：时间刻度 + 各列网格 ----
    Flickable {
        id: viewport

        objectName: "calendarViewport"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerArea.bottom
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: control.timeColumnWidth + control.days.length * control.columnWidth
        contentHeight: control.bodyHeight
        flickableDirection: Flickable.AutoFlickDirection
        boundsBehavior: Flickable.StopAtBounds

        Component.onCompleted: contentY = control.scrollTop

        Repeater {
            model: control.days

            delegate: Item {
                id: dayColumn

                required property var modelData
                required property int index

                objectName: "calendarDayColumn"
                x: control.timeColumnWidth + dayColumn.index * control.columnWidth
                width: control.columnWidth
                height: control.bodyHeight

                Rectangle {
                    objectName: "calendarWeekendFill"
                    anchors.fill: parent
                    // 官方 `-weekend` 那一档只是 background: fill-0；用 visible 切换，
                    // 免得「透明色」和「没铺」在测试里分不清
                    visible: control.markWeekend && CalendarDate.isWeekend(dayColumn.modelData)
                    color: Theme.current.colorFill0
                }

                // 48 个半小时格：格线 + 点击落点。00:00 那条官方 `:first-child::after { border:0 }`
                Repeater {
                    model: control.hourCount * 2

                    delegate: Item {
                        id: slotCell

                        required property int index

                        objectName: "calendarSlot"
                        x: 0
                        y: index * control.halfHourHeight
                        width: dayColumn.width
                        height: control.halfHourHeight

                        Rectangle {
                            objectName: "calendarSlotLine"
                            visible: slotCell.index > 0
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Theme.current.colorBorder
                            z: 3
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: control.clicked(control.slotDate(
                                dayColumn.modelData, slotCell.index))
                        }
                    }
                }

                Rectangle {
                    objectName: "calendarColumnLine"
                    visible: dayColumn.index < control.days.length - 1
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.current.colorBorder
                }

                // dateGridRender：官方那层是 inset:0 的绝对定位容器，铺满整列
                Loader {
                    objectName: "calendarDateGrid"
                    anchors.fill: parent
                    active: control.dateGridRender !== null
                    sourceComponent: control.dateGridRender
                    onLoaded: {
                        item.date = dayColumn.modelData;
                        item.dateString = dayColumn.modelData.toString();
                    }
                }

                // 定时事件
                Repeater {
                    model: control.timeline.timed[dayColumn.index]

                    delegate: Item {
                        id: timedItem

                        required property var modelData

                        objectName: "calendarTimedEvent"
                        x: timedItem.modelData.left * dayColumn.width
                        y: control.eventTop(timedItem.modelData.startPos)
                        width: dayColumn.width * (1 - timedItem.modelData.left)
                        height: control.eventHeightOf(timedItem.modelData.startPos,
                            timedItem.modelData.endPos)
                        clip: true
                        z: 5

                        CalendarEventBody {
                            anchors.fill: parent
                            event: timedItem.modelData.item
                        }

                        // 官方 pointer-events 那一档：条子吃点击，空白处落到格子骨架
                        TapHandler {
                            acceptedButtons: Qt.AllButtons
                            gesturePolicy: TapHandler.WithinBounds
                        }
                    }
                }

                // 当前时间线（只有今天那一列）
                Item {
                    id: currLine

                    visible: control.showCurrTime
                        && CalendarDate.isSameDay(dayColumn.modelData, new Date())
                    objectName: "calendarCurrTime"
                    x: 0
                    y: control.eventTop(control.currPos)
                    width: dayColumn.width
                    height: 1
                    z: 8

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        color: Theme.current.colorDanger
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: width / 2
                        color: Theme.current.colorDanger
                    }
                }
            }
        }

        // 时间刻度列：横向固定在左侧，纵向跟着滚
        Item {
            id: timeColumn

            objectName: "calendarTimeColumn"
            x: viewport.contentX
            y: 0
            width: control.timeColumnWidth
            height: control.bodyHeight
            z: 10

            Rectangle {
                anchors.fill: parent
                color: Theme.current.colorBg2
            }

            Repeater {
                model: control.hourCount

                delegate: Item {
                    id: hourCell

                    required property int index

                    width: timeColumn.width
                    height: control.hourHeight
                    y: hourCell.index * control.hourHeight

                    Loader {
                        objectName: "calendarTimeDisplay"
                        anchors.right: parent.right
                        anchors.rightMargin: control.gutterWidth
                        y: -10
                        active: control.renderTimeDisplay !== null
                        sourceComponent: control.renderTimeDisplay
                        onLoaded: item.time = hourCell.index
                    }

                    Text {
                        objectName: "calendarHourLabel"
                        anchors.right: parent.right
                        anchors.rightMargin: control.gutterWidth
                        y: -10
                        visible: control.renderTimeDisplay === null
                        text: control.hourLabel(hourCell.index)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }
        }
    }

    function hourLabel(hour) {
        // 官方 timeCol.tsx:26-45：hour < 12 走 AM、12 走 PM(12)、>12 走 PM(hour−12)，
        // 而第 0 格随后被 list.splice(0, 1, '') 抹成空串。
        if (hour === 0)
            return "";
        const value = hour <= 12 ? hour : hour - 12;
        return (hour < 12 ? "上午" : "下午") + value + "时";
    }

    SemiScrollBar {
        flickable: viewport
        orientation: Qt.Vertical
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.top: headerArea.bottom
        anchors.bottom: parent.bottom
    }

    // 列最小宽 130 ⇒ 七列要 980px，容器窄于这个数就得横向滚
    SemiScrollBar {
        flickable: viewport
        orientation: Qt.Horizontal
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
