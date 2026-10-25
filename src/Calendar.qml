pragma ComponentBehavior: Bound

import QtQuick
import "CalendarDate.js" as CalendarDate

// 日历。四个视图：month 是月网格，day / week / range 共用一条时间轴。
//
//     Calendar {
//         width: 640
//         height: 400
//         mode: "month"
//         displayValue: new Date(2026, 9, 1)
//         events: [
//             { key: "a", start: new Date(2026, 9, 8), children: "季度评审" },
//             { key: "b", start: new Date(2026, 9, 12), end: new Date(2026, 9, 14),
//               children: page.bandNode }
//         ]
//     }
//
// ---------------------------------------------------------------- 官方 CalendarProps
// 逐条对着 `semi-ui/calendar/interface.ts` + `index.tsx:41-50` 的 defaultProps：
//   · `mode` 四档 day / week / month / **range**，缺省 **week**（不是 month —— 本库早期默认
//     month 是因为只做了月视图，现在四个视图都在，默认值改回官方）。
//   · `displayValue`（缺省今天）、`events`（缺省 []）、`range`（缺省没给）、
//     `markWeekend` false、`showCurrTime` **true**、`weekStartsOn` 0、`scrollTop` **400**、
//     `minEventHeight` **Number.MIN_SAFE_INTEGER**、`height` **600**、`width` 没缺省。
//   · 事件对象是 `{ key, start, end, allDay, children }`：`key` 必填且要求唯一（官方拿它
//     控重绘），`children` 是要渲染的那段节点（字符串或 Component）。官方**没有** text /
//     delegate 这两条，本库早期那两份自造的已经并回 `children`。
//   · 回调：`onClick(e, date)` → `clicked(date)`、`onMoreClick(e, date, remaining)` →
//     `moreClicked(date, remaining)`、`onClose(e)` → `close()`。官方第一个参数是
//     React 的 MouseEvent（点卡片外面那一路给的是 null），本库没有对应物，一律不收。
//   · 四个 render prop 全部保留官方名字，类型换成 Component（本库对 ReactNode 的统一口径）：
//     `dateGridRender`（注入 `dateString` + `date`）、`renderTimeDisplay`（注入 `time`）、
//     `renderDateDisplay`（注入 `date` + `dateString`）、`allDayEventsRender`（注入 `events`，
//     而且和官方一样是**未经过滤的原样数组**）。
//   · `header` 官方是 ReactNode 属性，这里就是默认属性（子项），且和官方一样**不带任何样式**：
//     官方那层是塞进吸顶带最前面的裸节点，没有高度、没有分隔线。
//
// ---------------------------------------------------------------- 与官方的差异
//   · `style` / `className` 不收（没有 DOM 与 CSS）。
//   · `width` / `height` 直接落在 `Item` 自己的宽高上；`height` 的缺省 600 走 `implicitHeight`，
//     所以 `Calendar { height: 700 }` 与官方的 inline style 同效。
//   · `mode` 传不认识的值：官方 `React.cloneElement(component[mode])` 直接抛，
//     这里按官方其余三档的兜底走时间轴（QML 里抛异常只会刷一条日志、留一张白卡）。
//   · `mode: "range"` 而 `range` 没给：官方 `range[0]` 抛错，这里退回周视图那 7 列。
//   · 官方解析事件时**就地改写**用户传的事件对象（补 start/end、start>end 时交换），
//     端口只改自己的副本 —— 观感一致，少一条副作用。
//   · 月视图那张「还有 N 项」卡片官方用 Popover 包，方位判定里硬编码的 110 与卡片实际
//     宽 220 对不上、而且「右边有空间就开左边」方向是反的 —— 两条都照抄（见 CalendarMonth）。
//   · 头部容器的高度是「跟着子项走」的（`childrenRect.height`），所以头部子项里不要写
//     `anchors.verticalCenter: parent.verticalCenter` 之类依赖父高的定位，会成绑定循环。
//     翻月/翻周这类导航官方压根不提供，得自己往头部里放按钮改 `displayValue`：
//
//         Calendar {
//             id: calendar
//             Row {
//                 Text { text: calendar.title }
//                 Button { text: "上月"; onClicked: calendar.displayValue =
//                     CalendarDate.addMonths(calendar.displayValue, -1) }
//             }
//         }
//
//   · `title` 是端口自己加的便利串（「2026年10月」），官方没有头部也就没有标题这一说。
Item {
    id: control

    default property alias header: headerHost.data

    property var displayValue: new Date()
    property var events: []
    property string mode: "week"
    property var range: []
    property int weekStartsOn: 0
    property bool markWeekend: false
    property bool showCurrTime: true
    property int scrollTop: 400
    property real minEventHeight: -9007199254740991
    property Component dateGridRender: null
    property Component renderTimeDisplay: null
    property Component renderDateDisplay: null
    property Component allDayEventsRender: null

    signal clicked(var value)
    signal moreClicked(var day, int remaining)
    signal close()

    readonly property string title: CalendarDate.monthTitle(control.displayValue)
    readonly property var timelineDays: CalendarDate.timelineDays(
        control.displayValue, control.mode, control.range, control.weekStartsOn)

    implicitWidth: 640
    implicitHeight: 600

    // 官方那层 `-sticky-top` 的底色（`$color-calendar_sticky-bg` = bg-2）里装的是
    // `header` + 视图自己的表头，所以头部带必须铺 bg-2；日历本体没有背景（CSS 里没有
    // 任何一条 `-calendar { background }`），不能整块铺色。
    Rectangle {
        id: headerBand

        objectName: "calendarHeaderBand"
        width: parent.width
        height: headerHost.height
        visible: headerHost.height > 0
        color: Theme.current.colorBg2
    }

    Item {
        id: headerHost

        objectName: "calendarHeaderHost"
        width: parent.width
        height: childrenRect.height
        z: 1
    }

    Item {
        id: bodyHost

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerHost.bottom
        anchors.bottom: parent.bottom

        CalendarMonth {
            objectName: "calendarMonth"
            anchors.fill: parent
            visible: control.mode === "month"
            displayValue: control.displayValue
            events: control.events
            weekStartsOn: control.weekStartsOn
            markWeekend: control.markWeekend
            dateGridRender: control.dateGridRender
            renderDateDisplay: control.renderDateDisplay
            onClicked: function (value) { control.clicked(value); }
            onMoreClicked: function (day, remaining) { control.moreClicked(day, remaining); }
            onClose: control.close()
        }

        CalendarTimeGrid {
            objectName: "calendarTimeGrid"
            anchors.fill: parent
            visible: control.mode !== "month"
            days: control.timelineDays
            displayValue: control.displayValue
            mode: control.mode
            events: control.events
            showCurrTime: control.showCurrTime
            markWeekend: control.markWeekend
            minEventHeight: control.minEventHeight
            scrollTop: control.scrollTop
            dateGridRender: control.dateGridRender
            renderTimeDisplay: control.renderTimeDisplay
            renderDateDisplay: control.renderDateDisplay
            allDayEventsRender: control.allDayEventsRender
            onClicked: function (value) { control.clicked(value); }
        }
    }
}
