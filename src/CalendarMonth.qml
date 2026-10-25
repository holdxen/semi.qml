pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Semi
import "CalendarDate.js" as CalendarDate

// 日历的月视图。一般不单独用，交给 Calendar 的 mode: "month" 即可。
//
// 规格全部照 semi-foundation/calendar/{calendar.scss,variables.scss} + monthCalendar.tsx：
//   · 表头一行只有星期名（官方压根不带头部、不带翻页键，`Calendar` 也没有 title）：
//     `li { line-height: 26px; text-align: right; padding-right: 8px; border-bottom: 1px }`
//     ⇒ 表头高 27（26 + 1 描边），下面网格区官方写死 `height: calc(100% - 27px)`；
//     那 26 是 CSS 的半行距（上下各分一半）⇒ 端口用定高 26 + `verticalAlignment: AlignVCenter`。
//   · 日期数字在格子右上角：`-month-date { position:absolute; right:4px; z-index:3 }`，
//     字号 14 / 行高 20，格子 `padding-top: 4`。当月 text-0、邻月 text-2。
//     **只有每月 1 号那一格**带月份前缀（`{LLL}` + `&nbsp;1` + `{datestring}` ⇒ 「10月 1日」），
//     其余格子只有日号；被圈起来的永远是日号那一截（`-today-date` 只在 `-today` 祖先下成圆）。
//     那三段官方是**一段行内文本**（`-skeleton li span { font-size-regular }` ⇒ 20 的行盒），
//     天然同基线；端口拆成 Row 三块 ⇒ 三块一律「定高 20 + verticalAlignment 居中」，
//     谁用 `lineHeight + FixedHeight` 谁就浮高 3px（Qt 把多出来的行距整个垫在下面）。
//   · 今日：24×24 圆、底色 primary、文字 bg-1（`$width/$height-calendar_today_date`）。
//     官方那两条宽高其实吃不开（`-today-date` 是 inline span，只有 line-height 24 与底色生效），
//     端口照旧画 24 的圆，但日号盒恒 20 —— 否则圈起来的格子比邻居高/矮 1px。
//   · markWeekend ⇒ 周末格底色 fill-0。`isWeekend` 恒按周六周日算，与 weekStartsOn 无关。
//   · 事件层：`position:absolute; top:31px; right:0; bottom:20px; left:0`，一条高 1em，
//     而 `-event-month { font-size: 24px; height: 1em }` ⇒ **一条 24px**。
//   · 每格最多几条：官方 `Math.max(0, Math.ceil((cellHeight - 60) / 24))`
//     （monthCalendar.tsx:27-28 的 contentPadding=60 / contentHeight=24）。60 是硬编码的，
//     跟它自己 CSS 的「距顶 31 + 距底 20 = 51」对不上 ⇒ 最后一格事件贴着下沿时会裁掉半截。
//     这条**照抄**（上一版端口按 51 取整，属于自作聪明的偏离）。
//   · 「还有 N 项」：`-month-event-card-wrapper { position:absolute; right:8px; bottom:0;
//     padding-top:2px }` ⇒ 钉在格子右下角，不是接在事件条下面。N = 该列占位数 − itemLimit
//     （占位数含跨天条带在中途的占位格，官方 collectDailyEvents 就是这个口径）。
//   · 点它开一张 220px 宽的卡片（`$width-calendar_card`）列出这一天的全部条带：
//     `-content { padding: 12px 0 }` > `-header { margin: 12px 20px }`（星期 text-2 在上、
//     日号 20/28 居中在下、两者间距 4）+ `-body { padding: 0 16px }` 且 `li { height: 24px }`，
//     右上角一枚 tertiary + borderless + small 的 ×（`-close { margin-right: -4px }`）。
//     方位判定照抄官方：`body宽 − 目标右缘 − 110 > 0 ⇒ 开在左边`（foundation.ts:147-151）。
//     那个 110 是硬编码的 popoverWidth，而卡片实际宽 220 ⇒ 靠右时卡片会先溢出再翻，
//     并且**右边有位置就开左边**这个方向本身是反的 —— 两条都照抄，见 PROGRESS 的坑记录。
//   · 卡片关闭两条路：点 × 与点卡片外面，都发 `close()`（官方 onClose）。官方 `openCard`
//     setState 时没并 prev（monthCalendar.tsx:122-124）⇒ 同时只会开一张，端口同样只记一张。
//   · 点格子发 `clicked(date)`，date 是当天 00:00（官方 `formatCbValue([date])`）。
//     点事件条**不算**点格子：官方事件条在格子的兄弟 ul 里，且 `-event-items` 是
//     `pointer-events:none`、子项 `auto` ⇒ 落点被条子吃掉。端口让事件层盖一层 TapHandler 对齐。
//   · dateGridRender 的节点铺在格子内部（官方那层是 `position:absolute; inset:0` 的
//     `-custom-container`），所以 Loader 直接 fill 格子，节点自己摆 x/y/width/height。
//     注入 `dateString`（= date.toString()，官方传的就是这个串）与 `date` 两个属性。
//   · renderDateDisplay 换掉整块日期数字（官方 formatDayString 的第一档）。
Item {
    id: control

    property var displayValue: new Date()
    property var events: []
    property int weekStartsOn: 0
    property bool markWeekend: false
    property Component dateGridRender: null
    property Component renderDateDisplay: null

    signal clicked(var value)
    signal moreClicked(var day, int remaining)
    signal close()

    readonly property var weeks: CalendarDate.parseMonthlyEvents(
        control.events, control.displayValue, control.weekStartsOn)

    readonly property int weekdayHeaderHeight: 27
    /// 格子里那块日号的行盒：`.semi-calendar-month-skeleton li span { font-size-regular }` ⇒ 行高 20
    /// （表头那一档才是 `-grid li { line-height: 26 }`，两层不同值）
    readonly property int dateSpanHeight: 20
    readonly property int eventHeight: 24
    readonly property int eventAreaTop: 31
    readonly property int eventAreaBottom: 20
    readonly property int todayMarkSize: 24
    readonly property int weekdayCount: 7
    readonly property int cardWidth: 220
    readonly property int cardCloseSize: 24
    readonly property int cardHeaderWeekdayHeight: 20
    readonly property int cardHeaderDateHeight: 28
    readonly property int cardHeaderDateGap: 4

    readonly property int cellHeight: control.weeks.length > 0
        ? Math.floor((control.height - control.weekdayHeaderHeight) / control.weeks.length)
        : 0
    readonly property int eventAreaHeight: Math.max(0,
        control.cellHeight - control.eventAreaTop - control.eventAreaBottom)
    readonly property int itemLimit: Math.max(0,
        Math.ceil((control.cellHeight - 60) / control.eventHeight))

    // ---- 「还有 N 项」那张卡片的状态（同时只有一张） ----
    property var cardDate: null
    property var cardEvents: []
    property Item cardTarget: null
    readonly property bool cardOpen: control.cardTarget !== null
    // 官方 collectDailyEvents 出来的那一列是按行号铺的稀疏数组，卡片渲染前先滤掉空位
    readonly property var cardList: control.cardEvents.filter(function (it) {
        return it !== undefined && it !== null;
    })
    // 官方 popoverWidth = 110 的判定：右边还剩多少空间（够 110 就开左边）
    readonly property real cardRoomRight: {
        if (control.cardTarget === null)
            return 0;
        const at = control.cardTarget.mapToItem(null, control.cardTarget.width, 0);
        const viewport = Window.window ? Window.window.width : control.width;
        return viewport - at.x - 110;
    }
    // 判定结果单独露出来：卡片实际宽 220 而官方这个门槛写死 110，方向又是反的，
    // 两条都照抄 ⇒ 得有一格能直接断到「这一趟判到了哪个方位」
    readonly property int cardPosition: control.cardRoomRight > 0 ? Enums.LeftTop : Enums.RightTop

    function openCard(date, events, target) {
        control.cardDate = date;
        control.cardEvents = events;
        control.cardTarget = target;
    }

    function closeCard() {
        if (control.cardTarget === null)
            return;
        control.cardTarget = null;
        control.cardEvents = [];
        control.cardDate = null;
        control.close();
    }

    implicitWidth: 640
    implicitHeight: control.weekdayHeaderHeight + control.weeks.length * 90

    Column {
        id: body

        anchors.fill: parent

        Item {
            id: weekdayHeader

            width: parent.width
            height: control.weekdayHeaderHeight

            // 官方这一行整条都在 `-sticky-top` 里 ⇒ 底色 bg-2
            Rectangle {
                objectName: "calendarWeekdayHeaderBg"
                anchors.fill: parent
                color: Theme.current.colorBg2
            }

            Repeater {
                // 官方表头取的是 monthlyData[0] 的每一天（不是写死的星期串），
                // 因为 markWeekend 要给周末那一格也铺 fill-0
                model: control.weeks.length > 0 ? control.weeks[0].days : []

                delegate: Item {
                    id: weekdayCell

                    required property var modelData
                    required property int index

                    objectName: "calendarWeekdayCell"
                    x: weekdayCell.index * weekdayHeader.width / control.weekdayCount
                    width: weekdayHeader.width / control.weekdayCount
                    height: weekdayHeader.height

                    Rectangle {
                        visible: control.markWeekend && weekdayCell.modelData.isWeekend
                        anchors.fill: parent
                        color: Theme.current.colorFill0
                    }

                    Text {
                        objectName: "calendarWeekdayText"
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        // 官方 `-grid li { line-height: 26 }` 是半行距上下各分一半 ⇒ 字在 26 的盒里居中。
                        // Qt 的 lineHeight + FixedHeight 把多出来的高度**全加在下面**，字会浮高 3px，
                        // 所以这里用定高 + verticalAlignment 复刻 CSS 的那套半行距。
                        height: 26
                        verticalAlignment: Text.AlignVCenter
                        text: CalendarDate.weekdayName(weekdayCell.modelData.date)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeRegular
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
        }

        Repeater {
            model: control.weeks

            delegate: Item {
                id: weekRow

                required property var modelData
                required property int index

                width: body.width
                height: control.cellHeight

                Row {
                    id: dayRow

                    anchors.fill: parent

                    Repeater {
                        model: weekRow.modelData.days

                        delegate: Item {
                            id: dayCell

                            required property var modelData
                            required property int index

                            objectName: "calendarDayCell"
                            // 官方两条口径是分开用的：显隐看「这一列最高占位行 + 1」（稀疏
                            // 数组的 length），条数看「这一列真的占了几条」。两者在有空洞的
                            // 列上会不一样 ⇒ 「还有 0 项」这种怪文案也是官方的。
                            readonly property var laneColumn: weekRow.modelData.columns[dayCell.index]
                            readonly property int shownLanes: laneColumn.length
                            readonly property int hiddenCount: weekRow.modelData.counts[dayCell.index]
                                - control.itemLimit

                            width: dayRow.width / control.weekdayCount
                            height: dayRow.height

                            Rectangle {
                                objectName: "calendarWeekendFill"
                                anchors.fill: parent
                                visible: control.markWeekend && dayCell.modelData.isWeekend
                                color: Theme.current.colorFill0
                            }

                            // dateGridRender：官方那层是 inset:0 的绝对定位容器，铺在格子内部。
                            // 声明顺序排在日期数字之前 ⇒ 数字压在自定义节点上面
                            //（`-date { z-index: 3 }`，自定义节点要盖住它得自己写更高的 z）
                            Loader {
                                objectName: "calendarDateGrid"
                                anchors.fill: parent
                                active: control.dateGridRender !== null
                                sourceComponent: control.dateGridRender
                                onLoaded: {
                                    item.date = dayCell.modelData.date;
                                    item.dateString = dayCell.modelData.date.toString();
                                }
                            }

                            // renderDateDisplay：整块日期数字换掉
                            Loader {
                                objectName: "calendarDateDisplay"
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                active: control.renderDateDisplay !== null
                                sourceComponent: control.renderDateDisplay
                                onLoaded: {
                                    item.date = dayCell.modelData.date;
                                    item.dateString = dayCell.modelData.date.toString();
                                }
                            }

                            Row {
                                objectName: "calendarDateRow"
                                visible: control.renderDateDisplay === null
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                height: control.dateSpanHeight

                                // 官方 formatDayString 只在 1 号那天拼出月份前缀与「日」后缀
                                // （monthCalendar.tsx:320-335）⇒ 这里用 Loader：其它日子连节点都不建。
                                //（Row 本身会跳过 visible:false 的项、不留宽，探针量过；但那样每格
                                // 都躺着一份隐藏文本，「这一格没有前缀」就没法用「找不到节点」断）
                                Loader {
                                    active: dayCell.modelData.day === 1
                                    sourceComponent: Component {
                                        Text {
                                            objectName: "calendarMonthPrefix"
                                            text: CalendarDate.monthLabel(dayCell.modelData.date)
                                            color: dayCell.modelData.inMonth
                                                ? Theme.current.colorText0 : Theme.current.colorText2
                                            font.pixelSize: Theme.current.fontSizeRegular
                                            height: control.dateSpanHeight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                Item {
                                    id: dateMark

                                    readonly property bool circled: dayCell.modelData.isToday

                                    // 官方 `-today-date` 是个 inline span：24×24 那两条根本不吃得开，
                                    // 只有 line-height 24 与底色生效 ⇒ 圆跟着字走、装在 20 的行盒里居中。
                                    // 高度不吃 circled：否则圈起来的格子比邻居高/矮 1px，日号会跳。
                                    width: circled ? control.todayMarkSize : dateMarkText.width
                                    height: control.dateSpanHeight

                                    Rectangle {
                                        objectName: "calendarTodayDot"
                                        anchors.centerIn: parent
                                        visible: dateMark.circled
                                        width: control.todayMarkSize
                                        height: control.todayMarkSize
                                        radius: width / 2
                                        color: Theme.current.colorPrimary
                                    }

                                    Text {
                                        id: dateMarkText

                                        objectName: "calendarDateNumber"
                                        anchors.centerIn: parent
                                        text: (dayCell.modelData.day === 1 ? " " : "")
                                            + CalendarDate.dayNumber(dayCell.modelData.date)
                                        color: dateMark.circled
                                            ? Theme.current.colorBg1
                                            : (dayCell.modelData.inMonth
                                                ? Theme.current.colorText0
                                                : Theme.current.colorText2)
                                        font.pixelSize: Theme.current.fontSizeRegular
                                    }
                                }

                                Loader {
                                    active: dayCell.modelData.day === 1
                                    sourceComponent: Component {
                                        Text {
                                            objectName: "calendarDateSuffix"
                                            text: CalendarDate.DATE_SUFFIX
                                            color: dayCell.modelData.inMonth
                                                ? Theme.current.colorText0 : Theme.current.colorText2
                                            font.pixelSize: Theme.current.fontSizeRegular
                                            height: control.dateSpanHeight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: dayCell.index < control.weekdayCount - 1
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 1
                                color: Theme.current.colorBorder
                            }

                            Rectangle {
                                visible: weekRow.index < control.weeks.length - 1
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Theme.current.colorBorder
                            }

                            TapHandler {
                                // 缺省 DragThreshold 只取被动 grab，同一处叠着的 handler 会一起响应
                                // （条子、格子、甚至另一台叠放的日历都能收到同一次点击）；
                                // ReleaseWithinBounds 按下即抢独占 grab，等价于官方那条 DOM 链只走一个 onClick
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: control.clicked(dayCell.modelData.date)
                            }

                            // 「还有 N 项」：钉在格子右下角
                            Item {
                                id: moreLink

                                objectName: "calendarMoreLink"
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                visible: dayCell.shownLanes > control.itemLimit
                                width: moreText.width
                                height: moreText.height

                                Text {
                                    id: moreText

                                    objectName: "calendarMoreLinkText"
                                    text: CalendarDate.remainingText(dayCell.hiddenCount)
                                    color: Theme.current.colorText2
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }

                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: {
                                        control.moreClicked(dayCell.modelData.date,
                                            dayCell.hiddenCount);
                                        control.openCard(dayCell.modelData.date,
                                            weekRow.modelData.columns[dayCell.index], moreLink);
                                    }
                                }
                            }
                        }
                    }
                }

                // 这一周的事件条。官方 `-event-items` 是 weekrow 的子层，盖在格子那层上面
                Item {
                    id: eventLayer

                    objectName: "calendarEventLayer"
                    x: 0
                    y: control.eventAreaTop
                    width: parent.width
                    height: control.eventAreaHeight
                    clip: true
                    z: 1

                    Repeater {
                        model: weekRow.modelData.display

                        delegate: Item {
                            id: eventItem

                            required property var modelData

                            objectName: "calendarMonthEvent"
                            visible: eventItem.modelData.topInd < control.itemLimit
                            x: eventItem.modelData.leftPos * eventLayer.width
                            y: eventItem.modelData.topInd * control.eventHeight
                            width: eventItem.modelData.width * eventLayer.width
                            height: control.eventHeight
                            clip: true

                            CalendarEventBody {
                                anchors.fill: parent
                                event: eventItem.modelData.item
                            }

                            // 官方 `-event-items > * { pointer-events: auto }` ⇒ 只有条子本身吃点击，
                            // 层里那些空白格子照旧点到格子。WithinBounds 按下即独占，
                            // 底下那层的格子就不会再跟着响一次
                            TapHandler {
                                acceptedButtons: Qt.AllButtons
                                gesturePolicy: TapHandler.WithinBounds
                            }
                        }
                    }
                }
            }
        }
    }

    Popover {
        id: moreCard

        objectName: "calendarMoreCardPopup"
        trigger: "custom"
        showArrow: false
        spacing: 0
        visible: control.cardOpen
        target: control.cardTarget
        position: control.cardPosition
        // 官方点卡片外面也走 notifyClose ⇒ 两条关闭路径都发 close()
        onClickedOutside: control.closeCard()

        // PopupBase.bodyWidth 读的是 contentItem.implicitWidth，而 Column 的那一只只读、
        // 由子项隐式宽取大（这里子项只写了 width ⇒ 全是 0），卡片会塌。套一层 Item 把 220 交出去。
        // objectName 也挂在这一层：Popup 本身不是 Item，递归 children 摸不到它，只有这层能被找到
        Item {
            id: cardRoot

            objectName: "calendarMoreCard"
            implicitWidth: control.cardWidth
            implicitHeight: cardColumn.height
            width: control.cardWidth

            Column {
                id: cardColumn

                width: parent.width

                // -content { padding: 12px 0 }
                Item {
                    width: parent.width
                    height: 12
                }

                // -header { display:flex; margin: 12px 20px }，里面是 flex:1 的信息列 + ×
                Item {
                    width: parent.width
                    height: 12
                }

                Item {
                    id: cardHeader

                    width: parent.width
                    height: Math.max(cardHeaderInfo.height, closeIcon.height)

                    Column {
                        id: cardHeaderInfo

                        // flex:1 + align-items:center ⇒ 从左边距 20 一直顶到 × 的左缘，两行都居中
                        x: 20
                        width: cardHeader.width - 20 - control.cardCloseSize - 16
                        spacing: control.cardHeaderDateGap

                        // 继承卡片那一档 font-size-regular（14/20）
                        Text {
                            objectName: "calendarCardWeekday"
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: control.cardHeaderWeekdayHeight
                            text: control.cardDate ? CalendarDate.weekdayName(control.cardDate) : ""
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeRegular
                            verticalAlignment: Text.AlignVCenter
                        }

                        // @include font-size-header-4 ⇒ 20/28
                        Text {
                            objectName: "calendarCardDate"
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: control.cardHeaderDateHeight
                            text: control.cardDate ? CalendarDate.dayNumber(control.cardDate) : ""
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeHeader4
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // -close { margin-right: -4px } ⇒ 右缘比 20 的边距再往右 4
                    IconButton {
                        id: closeIcon

                        objectName: "calendarMoreCardClose"
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.top: parent.top
                        icon: "close"
                        size: Enums.Small
                        variant: Enums.Borderless
                        tone: Enums.Tertiary
                        onClicked: control.closeCard()
                    }
                }

                Item {
                    width: parent.width
                    height: 12
                }

                // -body { padding: 0 16px }，li 高 24
                Item {
                    width: parent.width
                    height: cardBody.height

                    Column {
                        id: cardBody

                        x: 16
                        width: parent.width - 32

                        Repeater {
                            model: control.cardList

                            delegate: Item {
                                id: cardEvent

                                required property var modelData

                                objectName: "calendarMoreCardEvent"
                                width: cardBody.width
                                height: control.eventHeight

                                CalendarEventBody {
                                    anchors.fill: parent
                                    event: cardEvent.modelData.item
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 12
                }
            }
        }
    }
}
