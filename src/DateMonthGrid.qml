pragma ComponentBehavior: Bound

import QtQuick
import "CalendarDate.js" as CD
import "DateFormat.js" as DF

// 日历面板里的一「栏」：导航栏 + 星期行 + 若干周行。对应
// semi-ui/datePicker/navigation.tsx + month.tsx + _utils/getMonthTable.ts。
//
// 三条容易照错的规格：
//   1) 月初/月末的空位是**空格子**（getMonthTable.ts:22-26 塞的是 dayNumber:''、fullDate:''，
//      month.tsx:317-323 遇到空 fullDate 只画一个空 div），不是相邻月的灰色日期。
//   2) 周行数按当月实际算（4/5/6 行都可能），但 range 的两栏取两者的最大值补齐
//      （monthsGrid.tsx:390 `weeksRowNum={maxWeekNum}` + month.tsx:292-294 按它定高），
//      否则左右一高一矮。
//   3) 区间态是「整格拉平的色带 + 两端各留一侧圆角」：中间格宽 = 格宽、margin 0、圆角 0；
//      起点宽 34 + 左 margin 2 + 只圆左侧；终点镜像（datePicker.scss:396-472）。
Item {
    id: control

    property var pickerDate: new Date()      // 这一栏显示哪个月
    property int panelIndex: 0               // 0 = 单栏或左栏，1 = 右栏
    property bool isRange: false
    property bool syncSwitchMonth: false
    property int density: Enums.DensityDefault
    property int weekStartsOn: 0
    property int weeksRowNum: 0              // 0 = 按当月实际行数
    property var selectedDates: []           // Date[]，单选时长度 1，multiple 时可多个
    property var rangeStart: null
    property var rangeEnd: null
    property var hoverDay: null              // 正在悬停的日（range 拖拽预览）
    property var offsetRangeStart: null      // 周选择：startDateOffset 算出来的预览起点
    property var offsetRangeEnd: null
    property var disabledDateFn: null        // (date, options) => bool
    property Component renderDate: null
    property Component renderFullDate: null
    property bool insetInput: false      // 面板顶部有内嵌输入框时，导航栏上下内边距 12 -> 8

    signal navClicked(string action)         // prevYear / prevMonth / nextMonth / nextYear / yam
    signal dayClicked(var date)
    signal dayHovered(var date)

    readonly property bool compact: control.density === Enums.DensityCompact
    readonly property real cellSize: control.compact ? 28 : 36          // $width-datepicker_day
    readonly property real mainSize: control.compact ? 24 : 32          // $width-datepicker_day_main
    readonly property real mainRadius: control.compact ? 4 : 3          // --semi-border-radius-small
    readonly property real monthWidth: control.compact ? 216 : 252      // $width-datepicker_month
    readonly property real monthPaddingX: control.compact ? 10 : 16
    readonly property real monthPaddingTop: control.compact ? 6 : 16
    readonly property real navHeight: control.compact ? 24 : 32         // $width-datepicker_nav
    readonly property real navPaddingY: control.insetInput ? 8 : 12
    readonly property real weekdayHeight: 36

    implicitWidth: control.monthWidth + control.monthPaddingX * 2
    implicitHeight: control.navHeight + control.navPaddingY * 2
        + control.monthPaddingTop + control.weekdayHeight + 1
        + control.rowCount * control.cellSize

    // 官方星期表头按 weekStartsOn 轮转（locale DatePicker.weeks：一..六、日）
    readonly property var weekdayLabels: {
        const all = ["日", "一", "二", "三", "四", "五", "六"];
        const out = [];
        for (let i = 0; i < 7; ++i)
            out.push(all[(control.weekStartsOn + i) % 7]);
        return out;
    }

    // 每格是 null（空位）或 Date
    readonly property var rows: control.buildRows()
    readonly property int rowCount: {
        const actual = CD.weeksInMonth(control.pickerDate, control.weekStartsOn);
        return control.weeksRowNum > 0 ? Math.max(control.weeksRowNum, actual) : actual;
    }

    function buildRows() {
        const first = CD.startOfMonth(control.pickerDate);
        const lead = (first.getDay() - control.weekStartsOn + 7) % 7;
        const total = CD.daysInMonth(control.pickerDate);
        const out = [];
        let row = [];
        for (let i = 0; i < lead; ++i)
            row.push(null);
        for (let d = 1; d <= total; ++d) {
            row.push(new Date(first.getFullYear(), first.getMonth(), d));
            if (row.length === 7) {
                out.push(row);
                row = [];
            }
        }
        if (row.length > 0) {
            while (row.length < 7)
                row.push(null);
            out.push(row);
        }
        return out;
    }

    function keyOf(date) {
        return DF.format(date, "yyyy-MM-dd");
    }

    function isSelected(date) {
        for (let i = 0; i < control.selectedDates.length; ++i)
            if (CD.isSameDay(control.selectedDates[i], date))
                return true;
        return false;
    }

    function isSame(a, b) {
        return a !== null && a !== undefined && b !== null && b !== undefined
            && CD.isSameDay(a, b);
    }

    function between(date, start, end) {
        if (!start || !end)
            return false;
        const s = CD.startOfDay(start).getTime();
        const e = CD.startOfDay(end).getTime();
        const d = CD.startOfDay(date).getTime();
        return d >= Math.min(s, e) && d <= Math.max(s, e);
    }

    function isDisabled(date) {
        if (control.disabledDateFn === null)
            return false;
        return control.disabledDateFn(date, {
            rangeStart: control.rangeStart,
            rangeEnd: control.rangeEnd,
            rangeInputFocus: false
        }) === true;
    }

    // 一格的状态。键名与官方 dayStatus 对齐（month.tsx:255-266），
    // renderFullDate 的第三个参数就是它。
    function statusOf(date) {
        if (date === null)
            return {};
        const both = control.rangeStart !== null && control.rangeEnd !== null;
        const dragging = control.isRange && control.hoverDay !== null
            && control.offsetRangeStart === null && control.offsetRangeEnd === null;
        return {
            isToday: CD.isSameDay(date, new Date()),
            isSelected: control.isSelected(date) || control.isSame(date, control.rangeStart)
                || control.isSame(date, control.rangeEnd),
            isDisabled: control.isDisabled(date),
            isSelectedStart: control.isRange && control.isSame(date, control.rangeStart),
            isSelectedEnd: control.isRange && control.isSame(date, control.rangeEnd),
            isInRange: both && control.between(date, control.rangeStart, control.rangeEnd),
            isHover: dragging && control.rangeStart !== null
                && control.between(date, control.rangeStart, control.hoverDay)
                && !control.isSame(date, control.hoverDay),
            isHoverDay: dragging && control.isSame(date, control.hoverDay),
            isHoverInOffsetRange: control.isRange && control.offsetRangeStart !== null
                && control.offsetRangeEnd !== null
                && (control.isSame(date, control.rangeStart)
                    || control.isSame(date, control.rangeEnd)
                    || control.between(date, control.offsetRangeStart, control.offsetRangeEnd)),
            isOffsetRangeStart: control.isSame(date, control.offsetRangeStart),
            isOffsetRangeEnd: control.isSame(date, control.offsetRangeEnd)
        };
    }

    // 色带形状：整格拉平 / 只圆左边 / 只圆右边 / 各自独立
    function bandOf(status) {
        const start = status.isSelectedStart === true || status.isOffsetRangeStart === true;
        const end = status.isSelectedEnd === true || status.isOffsetRangeEnd === true;
        const flat = (status.isInRange === true || status.isHover === true
            || status.isHoverInOffsetRange === true) && !(start && end);
        if (!flat) {
            return {
                width: control.mainSize,
                leftRadius: control.mainRadius,
                rightRadius: control.mainRadius
            };
        }
        return {
            width: control.cellSize,
            leftRadius: start && !end ? control.mainRadius : 0,
            rightRadius: end && !start ? control.mainRadius : 0
        };
    }

    function monthText() {
        // locale zh_CN：DatePicker.monthText = '${year}年 ${month}'
        return control.pickerDate.getFullYear() + "年 " + (control.pickerDate.getMonth() + 1) + "月";
    }

    // 官方 syncSwitchMonth 下左栏藏右箭头、右栏藏左箭头，用 visibility:hidden 保位
    function hidesArrow(side) {
        if (!control.syncSwitchMonth || !control.isRange)
            return false;
        if (control.panelIndex === 0)
            return side === "right";
        return side === "left";
    }

    // ---- 导航栏 ----
    Row {
        id: navRow

        x: control.monthPaddingX
        y: control.navPaddingY
        spacing: 0

        Repeater {
            model: [
                { action: "prevYear", icon: "double_chevron_left", side: "left" },
                { action: "prevMonth", icon: "chevron_left", side: "left" },
                { action: "yam", icon: "", side: "" },
                { action: "nextMonth", icon: "chevron_right", side: "right" },
                { action: "nextYear", icon: "double_chevron_right", side: "right" }
            ]

            delegate: Item {
                id: slot

                required property var modelData

                width: slot.modelData.icon === "" ? control.monthButtonWidth : control.navHeight
                height: control.navHeight

                readonly property bool hidden: control.hidesArrow(slot.modelData.side)

                IconButton {
                    anchors.fill: parent
                    visible: !slot.hidden && slot.modelData.icon !== ""
                    icon: slot.modelData.icon
                    size: Enums.Small
                    variant: Enums.Borderless
                    tone: Enums.Tertiary
                    onClicked: control.navClicked(slot.modelData.action)
                }

                // 月名按钮：16px 加粗，点了进年月面板（navigation.tsx:118-122）
                Text {
                    anchors.fill: parent
                    visible: slot.modelData.action === "yam"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: control.monthText()
                    color: Theme.current.colorText0
                    font.pixelSize: control.compact ? Theme.current.fontSizeRegular
                        : Theme.current.fontSizeHeader6
                    font.weight: Font.DemiBold

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: control.navClicked("yam")
                    }
                }
            }
        }
    }

    readonly property real monthButtonWidth: control.monthWidth - control.navHeight * 4

    // ---- 月历 ----
    Item {
        id: monthBlock

        y: control.navHeight + control.navPaddingY * 2
        width: parent.width
        height: control.monthPaddingTop + control.weekdayHeight + 1
            + control.rowCount * control.cellSize

        Row {
            id: weekdayRow

            x: control.monthPaddingX
            y: control.monthPaddingTop
            spacing: 0

            Repeater {
                model: control.weekdayLabels

                delegate: Text {
                    id: weekdayCell

                    required property var modelData

                    // 36×36、12px 加粗、text-2（datePicker.scss:322-335）
                    width: control.cellSize
                    height: control.weekdayHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: String(weekdayCell.modelData)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                    font.weight: Font.Bold
                }
            }
        }

        Rectangle {
            x: control.monthPaddingX
            y: weekdayRow.y + weekdayRow.height
            width: control.monthWidth
            height: 1
            color: Theme.current.colorBorder
        }

        Column {
            id: weeks

            x: control.monthPaddingX
            y: weekdayRow.y + weekdayRow.height + 1
            spacing: 0

            Repeater {
                model: control.rows

                delegate: Row {
                    id: weekRow

                    required property var modelData

                    spacing: 0

                    Repeater {
                        model: weekRow.modelData

                        delegate: Item {
                            id: dayCell

                            required property var modelData

                            objectName: dayCell.date
                                ? "dayCell-" + control.keyOf(dayCell.date) : "dayCell-empty"
                            width: control.cellSize
                            height: control.cellSize

                            readonly property var date: dayCell.modelData
                            readonly property var status: control.statusOf(dayCell.date)
                            readonly property var band: control.bandOf(dayCell.status)

                            function cellBackground() {
                                const s = dayCell.status;
                                if (s.isSelected || s.isOffsetRangeStart || s.isOffsetRangeEnd)
                                    return s.isDisabled ? Theme.current.colorDisabledFill
                                        : Theme.current.colorPrimary;
                                if (s.isHoverDay && s.isInRange)
                                    return Theme.current.colorPrimaryLightHover;
                                if (s.isInRange || s.isHover || s.isHoverInOffsetRange)
                                    return Theme.current.colorPrimaryLightDefault;
                                if (s.isDisabled)
                                    return "transparent";
                                if (s.isHoverDay)
                                    return Theme.current.colorFill1;
                                if (s.isToday)
                                    return Theme.current.colorFill0;
                                if (pressHandler.pressed)
                                    return Theme.current.colorFill1;
                                if (hoverHandler.hovered)
                                    return Theme.current.colorFill0;
                                return "transparent";
                            }

                            function cellForeground() {
                                const s = dayCell.status;
                                if (s.isSelected || s.isOffsetRangeStart || s.isOffsetRangeEnd)
                                    return s.isDisabled ? Theme.current.colorDisabledText
                                        : Theme.current.colorWhite;
                                if (s.isDisabled)
                                    return Theme.current.colorDisabledText;
                                if (s.isToday)
                                    return Theme.current.colorPrimary;
                                return Theme.current.colorText0;
                            }

                            // renderFullDate 给定时整格由外部画，官方此时连 dayCls 都不挂
                            Loader {
                                id: fullLoader

                                visible: dayCell.date !== null && control.renderFullDate !== null
                                anchors.fill: parent
                                sourceComponent: control.renderFullDate
                            }

                            // 值注入到外部组件的根节点上（Loader 不会替 Component 初始化属性）
                            Binding {
                                target: fullLoader.item
                                when: fullLoader.item !== null
                                property: "dayNumber"
                                value: dayCell.date ? dayCell.date.getDate() : ""
                            }
                            Binding {
                                target: fullLoader.item
                                when: fullLoader.item !== null
                                property: "fullDate"
                                value: dayCell.date ? control.keyOf(dayCell.date) : ""
                            }
                            Binding {
                                target: fullLoader.item
                                when: fullLoader.item !== null
                                property: "dayStatus"
                                value: dayCell.status
                            }

                            Rectangle {
                                objectName: dayCell.date
                                    ? "dayBand-" + control.keyOf(dayCell.date) : ""
                                visible: dayCell.date !== null && control.renderFullDate === null
                                x: (control.cellSize - dayCell.band.width) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: dayCell.band.width
                                height: control.mainSize
                                radius: control.mainRadius
                                topLeftRadius: dayCell.band.leftRadius
                                topRightRadius: dayCell.band.rightRadius
                                bottomLeftRadius: dayCell.band.leftRadius
                                bottomRightRadius: dayCell.band.rightRadius
                                color: dayCell.cellBackground()
                            }

                            Loader {
                                id: dateLoader

                                visible: dayCell.date !== null && control.renderFullDate === null
                                    && control.renderDate !== null
                                anchors.centerIn: parent
                                sourceComponent: control.renderDate
                            }

                            Binding {
                                target: dateLoader.item
                                when: dateLoader.item !== null
                                property: "dayNumber"
                                value: dayCell.date ? dayCell.date.getDate() : ""
                            }
                            Binding {
                                target: dateLoader.item
                                when: dateLoader.item !== null
                                property: "fullDate"
                                value: dayCell.date ? control.keyOf(dayCell.date) : ""
                            }

                            Text {
                                visible: dayCell.date !== null && control.renderFullDate === null
                                    && dateLoader.item === null
                                anchors.centerIn: parent
                                text: dayCell.date ? String(dayCell.date.getDate()) : ""
                                color: dayCell.cellForeground()
                                font.pixelSize: control.compact ? Theme.current.fontSizeSmall
                                    : Theme.current.fontSizeRegular
                                font.weight: dayCell.status.isToday || dayCell.status.isSelected
                                    ? Font.DemiBold : Font.Normal
                            }

                            HoverHandler {
                                id: hoverHandler

                                enabled: dayCell.date !== null && control.renderFullDate === null
                                cursorShape: Qt.PointingHandCursor

                                onHoveredChanged: {
                                    if (hoverHandler.hovered && dayCell.date !== null)
                                        control.dayHovered(dayCell.date);
                                }
                            }

                            TapHandler {
                                id: pressHandler

                                enabled: dayCell.date !== null && !dayCell.status.isDisabled
                                onTapped: control.dayClicked(dayCell.date)
                            }
                        }
                    }
                }
            }
        }
    }
}
