pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as C
import "CalendarDate.js" as CD
import "DateFormat.js" as DF

// 日期选择。触发器是一只（或两只）输入框，点开是日历面板；type 决定面板形态。
//
//     DatePicker { }                                   // 单个日期
//     DatePicker { type: Enums.TypeDateRange }         // 范围，两只输入框
//     DatePicker { type: Enums.TypeDateTime needConfirm: true }
//     DatePicker { type: Enums.TypeMonth }             // 年月滚轮
//     DatePicker { multiple: true; max: 3 }
//     DatePicker { presets: [{ text: "今天", start: new Date(), end: new Date() }] }
//
// 值是 Date（range / multiple 是 Date 数组），也收 "yyyy-MM-dd" 这类字符串，按 format 解析。
// 信号 changed(date, dateString) 与官方 onChange 同形：非范围/非多选时第一个参数是单个 Date。
//
// 规格（semi-foundation/datePicker/{datePicker.scss,variables.scss}，本地 semi.css 实测）：
//   单栏 = 导航栏 32 + 上下内边距 12×2 + 月历（上内边距 16 + 星期行 36 + 1px 线 + 6 行 ×36）
//     = 284 宽 × 325 高；带时间的一栏再加 54 的切换条 = 378。
//   范围 = 两栏并排 568；年月面板 284（monthRange 384），滚动列高 266。
//   快捷面板左右方位宽 200、上下方位最大高 100。
//   确认底栏 padding 10 8 10 0、底 fill-0、按钮高 32，顺序「取消 / 确定」。
//   触发器：单框走 input 那套令牌；范围框是 fill-0 底、无描边，
//     被点的那半区加 1px focus 环 + fill-1 底（datePicker.scss:896-1002）。
Item {
    id: control

    // ---- 官方属性面（content/input/datepicker/index.md:818-892）----
    property int type: Enums.TypeDate
    property var value: undefined               // 受控值
    property var defaultValue: undefined        // 非受控初值
    property string format: ""                  // 空 = 按 type 取默认
    property string rangeSeparator: "~"         // constants.ts:47，展示时两侧各补一个空格
    property int weekStartsOn: 0
    property int size: Enums.Default
    // 分角圆角透给触发器，InputGroup 要靠它们还原 .semi-input-group 的首尾圆角
    property alias topLeftRadius: triggerBox.topLeftRadius
    property alias topRightRadius: triggerBox.topRightRadius
    property alias bottomLeftRadius: triggerBox.bottomLeftRadius
    property alias bottomRightRadius: triggerBox.bottomRightRadius
    property int density: Enums.DensityDefault
    property bool disabled: false
    property var placeholder: undefined         // string | [start, end]
    property bool inputReadOnly: false
    property bool showClear: true
    property bool multiple: false               // 仅 date
    property int max: 0                         // 0 = 不限
    property bool needConfirm: false            // 仅 dateTime / dateTimeRange
    property var presets: []
    property int presetPosition: Enums.PresetBottom
    property bool syncSwitchMonth: false
    property var defaultPickerValue: undefined
    property bool autoSwitchDate: true
    property bool insetInput: false
    property var disabledDate: null             // (date, options) => bool
    property var disabledTime: null             // (date, panelType) => ({ disabledHours, ... })
    property bool hideDisabledOptions: false
    property bool disabledTimePicker: false
    property var startDateOffset: null          // (date) => Date，周选择
    property var endDateOffset: null
    property int startYear: 0                   // 0 = 今年 -100
    property int endYear: 0                     // 0 = 今年 +100
    property Component triggerRender: null
    property Component renderDate: null
    property Component renderFullDate: null
    property Component topSlot: null
    property Component bottomSlot: null
    property Component leftSlot: null
    property Component rightSlot: null
    property int position: Enums.BottomLeft
    property real spacing: 4                    // numbers.SPACING
    property var open: undefined                // 受控显隐
    property bool defaultOpen: false

    signal changed(var date, var dateString)
    // 官方回调 onOpenChange。这里不能叫 openChanged —— property open 的自动变更信号
    // 就叫那个名字，撞上了整个类型创建不出来（坑 26）。
    signal openChange(bool isOpen)
    signal panelChanged(var date, var dateString)
    signal confirmed(var date, var dateString)
    signal cancelled(var date, var dateString)
    signal cleared
    signal presetClicked(var item)

    // ---- 派生的类型信息 ----
    readonly property string typeKey: {
        if (control.type === Enums.TypeDateRange) return "dateRange";
        if (control.type === Enums.TypeDateTime) return "dateTime";
        if (control.type === Enums.TypeDateTimeRange) return "dateTimeRange";
        if (control.type === Enums.TypeMonth) return "month";
        if (control.type === Enums.TypeMonthRange) return "monthRange";
        if (control.type === Enums.TypeYear) return "year";
        return "date";
    }
    readonly property bool isRangeType: control.typeKey === "dateRange"
        || control.typeKey === "dateTimeRange" || control.typeKey === "monthRange"
    readonly property bool isTimeType: control.typeKey === "dateTime"
        || control.typeKey === "dateTimeRange"
    readonly property bool isYamType: control.typeKey === "month"
        || control.typeKey === "monthRange" || control.typeKey === "year"
    // monthRange 虽然叫 range，触发器仍是一只输入框（dateInput.tsx:321-324）
    readonly property bool isMultiInputRange: control.isRangeType
        && control.typeKey !== "monthRange"
    readonly property bool compact: control.density === Enums.DensityCompact
    readonly property string fmt: control.format !== ""
        ? control.format : DF.defaultFormatToken(control.typeKey)
    readonly property string timeFormat: DF.timeFormatOf(control.format)
    readonly property bool showTimePart: control.isTimeType && DF.hasTimeToken(control.fmt)
    readonly property bool showFooter: control.needConfirm && control.isTimeType
    readonly property string sep: DF.rangeSeparatorOf(control.rangeSeparator)

    // ---- 内部状态 ----
    property var _inner: control.toDates(control.defaultValue)
    property var _pending: null            // 范围未选完 / needConfirm 未确认的暂存
    property bool _rangeSelecting: false
    property var _hoverDay: null
    property var _offsetStart: null
    property var _offsetEnd: null
    property bool _typing: false
    property bool _panelReady: false        // 面板建过一次就一直留着，重开不重建
    property string _typedText: ""
    property string _typedStart: ""
    property string _typedEnd: ""
    property var _leftDate: control.initialLeftDate()
    property var _rightDate: control.initialRightDate()
    property string _viewLeft: "date"
    property string _viewRight: "date"

    // 非受控时弹层自己就是状态源（坑 48）；受控时听调用方的 open
    readonly property bool panelOpen: control.open !== undefined ? control.open === true
        : popup.isOpen
    readonly property var _popup: popup        // 弹层根节点，与 AutoComplete._popup 同形
    readonly property var displayDates: control._pending !== null ? control._pending
        : (control.value !== undefined ? control.toDates(control.value) : control._inner)

    implicitWidth: 220
    implicitHeight: Appearance.inputWrapperHeight(Theme.current, control.size)

    // ---- 值 <-> Date[] ----
    function toDate(v) {
        if (v === undefined || v === null)
            return null;
        if (v instanceof Date)
            return v;
        if (typeof v === "number")
            return new Date(v);
        const text = String(v);
        let d = DF.parse(text, control.fmt);
        if (d === null)
            d = DF.parse(text, "yyyy-MM-dd");
        if (d === null)
            d = DF.parse(text, "yyyy-MM");
        if (d === null)
            d = DF.parse(text, "yyyy-MM-dd HH:mm:ss");
        return d;
    }

    function toDates(v) {
        if (v === undefined || v === null)
            return [];
        const arr = Array.isArray(v) ? v : [v];
        const out = [];
        for (let i = 0; i < arr.length; ++i)
            out.push(control.toDate(arr[i]));
        return out;
    }

    // onChange 的第一个参数：范围/多选给数组，其余给单个 Date
    function dateArg(dates) {
        if (control.isRangeType || control.multiple)
            return dates;
        return dates.length > 0 ? dates[0] : null;
    }

    function stringArg(dates) {
        const valid = dates.filter((d) => d !== null && d !== undefined);
        if (control.multiple)
            return DF.formatMultiple(valid, control.fmt);
        if (control.isRangeType) {
            if (valid.length < 2)
                return valid.length === 1 ? DF.format(valid[0], control.fmt) : "";
            return DF.formatRange(valid[0], valid[1], control.fmt, control.sep);
        }
        return valid.length > 0 ? DF.format(valid[0], control.fmt) : "";
    }

    function notify(dates, fromConfirm) {
        if (control.value === undefined)
            control._inner = dates;
        const d = control.dateArg(dates);
        const s = control.stringArg(dates);
        if (fromConfirm === true)
            control.confirmed(d, s);
        control.changed(d, s);
    }

    // needConfirm 时先落进暂存，点「确定」才通知
    function commit(dates) {
        if (control.showFooter) {
            control._pending = dates;
            return;
        }
        control._pending = null;
        control.notify(dates);
    }

    // ---- 面板初值 ----
    function initialLeftDate() {
        const base = control.firstDate(control.value) !== null ? control.firstDate(control.value)
            : (control.firstDate(control.defaultPickerValue) !== null
                ? control.firstDate(control.defaultPickerValue)
                : (control.firstDate(control.defaultValue) !== null
                    ? control.firstDate(control.defaultValue) : new Date()));
        return CD.startOfMonth(base);
    }

    function initialRightDate() {
        // 范围值的第二端优先（monthRange 的右栏要停在已选的那个月，不是左栏 +1）
        const fromValue = control.toDates(control.value);
        if (fromValue.length > 1 && fromValue[1] !== null)
            return CD.startOfMonth(fromValue[1]);
        const fromDefault = control.toDates(control.defaultValue);
        if (fromDefault.length > 1 && fromDefault[1] !== null)
            return CD.startOfMonth(fromDefault[1]);
        return CD.addMonths(control.initialLeftDate(), 1);
    }

    function firstDate(v) {
        const arr = control.toDates(v);
        return arr.length > 0 && arr[0] !== null ? arr[0] : null;
    }

    function keepTime(target, source) {
        if (target === null || source === null || source === undefined)
            return target;
        return new Date(target.getFullYear(), target.getMonth(), target.getDate(),
                        source.getHours(), source.getMinutes(), source.getSeconds());
    }

    // ---- 选择 ----
    // 官方的 disabledDate 第二参是 { rangeStart, rangeEnd, rangeInputFocus }，
    // 前两个是格式化后的字符串（datePicker.tsx disabledDisposeDate）
    function isDateDisabled(date) {
        if (control.disabledDate === null)
            return false;
        const dates = control.displayDates;
        return control.disabledDate(date, {
            rangeStart: control.textOf(dates, 0),
            rangeEnd: control.textOf(dates, 1),
            rangeInputFocus: control.isMultiInputRange && control.panelOpen
                ? (control._endFocused ? "rangeEnd" : "rangeStart") : false
        }) === true;
    }

    function handleDayClicked(date) {
        if (control.isDateDisabled(date))
            return;                           // 官方：禁用格子的 onClick 根本不绑
        if (control.isRangeType) {
            const hasOffset = control.startDateOffset !== null || control.endDateOffset !== null;
            if (hasOffset) {
                const start = control.startDateOffset !== null
                    ? control.startDateOffset(date) : date;
                const end = control.endDateOffset !== null ? control.endDateOffset(date) : date;
                control.clearHover();
                control.commit([CD.startOfDay(start), CD.startOfDay(end)]);
                if (!control.showFooter)
                    control.closePanel();
                return;
            }
            if (!control._rangeSelecting) {
                control._pending = [date, null];
                control._rangeSelecting = true;
                control._endFocused = true;      // 选完起点，激活对面那只输入框
                return;
            }
            let start = control.displayDates[0];
            let end = date;
            if (CD.isBefore(end, start)) {
                const t = start;
                start = end;
                end = t;
            }
            if (control.isTimeType) {
                start = control.keepTime(start, control.displayDates[0]);
                end = control.keepTime(end, control._rightDate);
            }
            control._rangeSelecting = false;
            control.commit([start, end]);
            if (!control.showFooter)
                control.closePanel();
            return;
        }

        if (control.multiple) {
            const cur = control.displayDates.slice();
            let found = -1;
            for (let i = 0; i < cur.length; ++i)
                if (cur[i] !== null && CD.isSameDay(cur[i], date))
                    found = i;
            if (found >= 0)
                cur.splice(found, 1);
            else
                cur.push(date);
            if (control.max > 0 && cur.length > control.max)
                return;                       // 超上限：官方静默不选
            control._pending = null;
            control.notify(cur);
            return;
        }

        let value = date;
        if (control.isTimeType)
            value = control.keepTime(date, control.viewSideDate(0));
        control._pending = null;
        control.commit([value]);
        // 官方只在「date 且非 multiple」时选完就关面板（foundation.ts:1019）
        if (!control.isTimeType && !control.showFooter)
            control.closePanel();
    }

    function viewSideDate(panel) {
        const d = panel === 1 ? control._rightDate : control._leftDate;
        const fromValue = control.displayDates[panel === 1 ? 1 : 0];
        if (control.isTimeType && fromValue !== undefined && fromValue !== null)
            return fromValue;
        return d;
    }

    function handleDayHovered(date) {
        if (!control.isRangeType)
            return;
        const hasOffset = control.startDateOffset !== null || control.endDateOffset !== null;
        // 官方只在「区间还没选完」或带 offset（周选择）时给悬浮预览；
        // 已经是一个完整区间时再悬停，不该把色带拖到鼠标那格。
        if (!control._rangeSelecting && !hasOffset)
            return;
        control._hoverDay = date;
        if (!hasOffset)
            return;
        control._offsetStart = control.startDateOffset !== null
            ? control.startDateOffset(date) : date;
        control._offsetEnd = control.endDateOffset !== null
            ? control.endDateOffset(date) : date;
    }

    function clearHover() {
        control._hoverDay = null;
        control._offsetStart = null;
        control._offsetEnd = null;
    }

    function handleTimePicked(panel, hour, minute, second) {
        const dates = control.displayDates.slice();
        const idx = control.isRangeType ? panel : 0;
        const base = dates[idx] !== undefined && dates[idx] !== null ? dates[idx]
            : control.viewSideDate(panel);
        dates[idx] = new Date(base.getFullYear(), base.getMonth(), base.getDate(),
                              hour, minute, second);
        control.commit(dates);
    }

    // ---- 导航 ----
    function handleNav(panel, action) {
        if (action === "yam") {
            if (panel === 1)
                control._viewRight = control._viewRight === "yam" ? "date" : "yam";
            else
                control._viewLeft = control._viewLeft === "yam" ? "date" : "yam";
            return;
        }
        if (action === "openTime") {
            control._viewLeft = "time";
            return;
        }
        if (action === "openDate") {
            control._viewLeft = "date";
            control._viewRight = "date";
            return;
        }
        const months = action === "prevYear" ? -12 : action === "nextYear" ? 12
            : action === "prevMonth" ? -1 : 1;
        control.shiftPanel(panel, months);
    }

    function shiftPanel(panel, months) {
        const sync = control.syncSwitchMonth && control.isRangeType;
        control._leftDate = CD.addMonths(control._leftDate, sync ? months : (panel === 0 ? months : 0));
        if (!sync && panel === 1)
            control._rightDate = CD.addMonths(control._rightDate, months);
        if (sync)
            control._rightDate = CD.addMonths(control._rightDate, months);
        control.adjustRight();
        // autoSwitchDate：翻月时把已选的「几号」搬过去（仅 date，非 multiple）
        if (control.autoSwitchDate && !control.multiple && control.typeKey === "date"
            && control.displayDates.length > 0 && control.displayDates[0] !== null) {
            const picked = control.displayDates[0];
            const moved = control.clampToMonth(control._leftDate, picked.getDate());
            control.notify([moved]);
        }
        control.emitPanelChange();
    }

    function clampToMonth(monthDate, day) {
        const last = new Date(monthDate.getFullYear(), monthDate.getMonth() + 1, 0).getDate();
        return new Date(monthDate.getFullYear(), monthDate.getMonth(), Math.min(day, last));
    }

    // 右栏始终不早于左栏的下一月（_autoAdjustMonth，monthsGridFoundation.ts:785-799）
    function adjustRight() {
        if (!control.isRangeType)
            return;
        if (!CD.isSameMonth(control._rightDate, control._leftDate)
            && CD.isAfter(control._rightDate, control._leftDate))
            return;
        control._rightDate = CD.addMonths(control._leftDate, 1);
    }

    function emitPanelChange() {
        control.panelChanged(control.dateArg(control.panelDates()),
                             control.stringArg(control.panelDates()));
    }

    function panelDates() {
        if (control.isRangeType)
            return [CD.startOfMonth(control._leftDate), CD.startOfMonth(control._rightDate)];
        return [CD.startOfMonth(control._leftDate)];
    }

    function handleYearMonth(panel, year, month) {
        const base = new Date(year, month - 1, 1);
        if (control.isYamType) {
            // month / monthRange：直接落值
            if (control.typeKey === "monthRange") {
                if (!control._rangeSelecting) {
                    control._pending = [base, null];
                    control._rangeSelecting = true;
                    return;
                }
                let start = control.displayDates[0];
                let end = base;
                if (CD.isBefore(end, start)) {
                    const t = start;
                    start = end;
                    end = t;
                }
                control._rangeSelecting = false;
                control.commit([start, end]);
                control.closePanel();
                return;
            }
            control.commit([base]);
            control.closePanel();
            return;
        }
        // 年月面板里选了 → 回到月历，并把这一月设为面板月
        if (panel === 1)
            control._rightDate = base;
        else
            control._leftDate = base;
        control._viewLeft = "date";
        control._viewRight = control.isRangeType ? control._viewRight : "date";
        control.adjustRight();
        control.emitPanelChange();
    }

    // ---- 开关 ----
    // 官方 ref 上的 open()/close() 在这里叫 openPanel()/closePanel()：
    // `open` 这个名字被受控显隐属性占了，同名方法会被属性遮蔽（坑 26 同族）。
    function showPanel() {
        control._panelReady = true;         // 面板子树到第一次打开才建
        control._leftDate = control.initialLeftDate();
        control.adjustRight();
        popup.open();
        control.emitPanelChange();
    }

    function openPanel() {
        if (control.disabled || control.panelOpen)
            return;
        if (control.open !== undefined)
            control.openChange(true);      // 受控：只通知，开合由调用方改 open
        else
            control.showPanel();
    }

    function closePanel() {
        if (control.open !== undefined)
            control.openChange(false);
        else
            popup.close();
    }

    function toggle() {
        if (control.panelOpen)
            control.closePanel();
        else
            control.openPanel();
    }

    // 关闭时丢弃暂存（点外面、Esc 走的也是这条路，见 popup.onAboutToHide）
    function discardTransient() {
        control._pending = null;
        control._rangeSelecting = false;
        control.clearHover();
        control._typing = false;
        control._endFocused = false;
        control._viewLeft = "date";
        control._viewRight = "date";
    }

    // ---- 触发器显示 ----
    readonly property string startText: control._typing && control.isMultiInputRange
        ? control._typedStart : control.textOf(control.displayDates, 0)
    readonly property string endText: control._typing && control.isMultiInputRange
        ? control._typedEnd : control.textOf(control.displayDates, 1)
    readonly property string singleText: control._typing ? control._typedText
        : control.stringArg(control.displayDates)

    function textOf(dates, index, pattern) {
        const d = dates[index];
        const p = pattern === undefined ? control.fmt : pattern;
        return d === undefined || d === null ? "" : DF.format(d, p);
    }

    // locale zh_CN DatePicker.placeholder（datePicker.tsx:674 是 placeholder || locale[type]）
    function placeholderAt(index) {
        if (control.placeholder !== undefined && control.placeholder !== null) {
            if (Array.isArray(control.placeholder))
                return String(control.placeholder[Math.min(index, control.placeholder.length - 1)]);
            return String(control.placeholder);
        }
        if (control.typeKey === "dateTime") return qsTr("请选择日期及时间");
        if (control.typeKey === "dateRange" || control.typeKey === "dateTimeRange")
            return index === 0 ? qsTr("开始日期") : qsTr("结束日期");
        if (control.typeKey === "monthRange")
            return index === 0 ? qsTr("开始月份") : qsTr("结束月份");
        // month / year 在官方 locale 里没有条目，占位是空的
        if (control.typeKey === "month" || control.typeKey === "year")
            return "";
        return qsTr("请选择日期");
    }

    // monthRange 只有一只输入框，官方把两个占位拼起来显示（dateInput.tsx:460）
    readonly property string triggerPlaceholder: control.typeKey === "monthRange"
        && !Array.isArray(control.placeholder)
        ? control.placeholderAt(0) + control.rangeSeparator + control.placeholderAt(1)
        : control.placeholderAt(0)

    function commitTyped(text, index) {
        const parsed = control.toDate(text);
        if (text === "" ) {
            const dates = control.displayDates.slice();
            dates[index] = null;
            control.notify(dates.filter((d) => d !== null));
            control._typing = false;
            return;
        }
        if (parsed === null) {
            control._typing = false;
            return;
        }
        const dates = control.displayDates.slice();
        dates[index] = parsed;
        if (control.isRangeType && (dates[0] === null || dates[1] === undefined))
            dates[1] = dates[1] === undefined ? null : dates[1];
        control._typing = false;
        control.notify(dates);
    }

    // 官方 ref 上的 clear()
    function clear() {
        control._pending = null;
        control._rangeSelecting = false;
        if (control.value === undefined)
            control._inner = [];
        control.cleared();
        control.changed(control.dateArg([]), "");
    }

    // ---- 触发器 ----
    Loader {
        id: customTrigger

        anchors.fill: parent
        active: control.triggerRender !== null
        sourceComponent: control.triggerRender
    }

    // 官方 triggerRender({ placeholder })：把占位文案注入到自定义触发器的根节点上
    Binding {
        target: customTrigger.item
        when: customTrigger.item !== null
        property: "placeholder"
        value: control.placeholderAt(0)
    }

    // 自定义触发器时官方不画清除按钮（datePicker.tsx:413-415）
    Rectangle {
        id: triggerBox

        objectName: "triggerBox"
        anchors.fill: parent
        visible: control.triggerRender === null
        radius: Theme.current.radiusSmall
        color: control.isMultiInputRange
            ? (control.disabled ? Theme.current.colorDisabledFill : Theme.current.colorFill0)
            : Appearance.inputBackground(Theme.current, control.fieldState, control.validateStatus)
        border.width: control.isMultiInputRange ? 0 : 1
        border.color: Appearance.inputBorderColor(Theme.current, control.fieldState,
                                                  control.validateStatus)

        readonly property bool focused: control.panelOpen

        Behavior on color {
            ColorAnimation { duration: Theme.current.durationFast }
        }
    }

    readonly property int fieldState: Appearance.fieldState(!control.disabled,
        control.panelOpen, singleHover.hovered, false)
    property int validateStatus: Enums.StatusDefault

    // 单输入框（date / dateTime / month / monthRange）
    Item {
        id: singleTrigger

        anchors.fill: parent
        visible: control.triggerRender === null && !control.isMultiInputRange

        TextInput {
            id: singleField

            anchors.left: parent.left
            anchors.leftMargin: Appearance.inputPaddingHorizontal(Theme.current)
            anchors.right: suffixRow.left
            anchors.rightMargin: Theme.current.spacingTight
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
            color: Appearance.inputForeground(Theme.current, control.fieldState)
            font.pixelSize: Theme.current.fontSizeRegular
            enabled: !control.disabled
            readOnly: control.inputReadOnly
            clip: true
            text: control.singleText

            onTextChanged: {
                if (singleField.text === control.singleText)
                    return;
                control._typedText = singleField.text;
                control._typing = true;
                singleField.text = Qt.binding(function () { return control.singleText; });
            }

            onEditingFinished: control.commitTyped(singleField.text, 0)

            onActiveFocusChanged: {
                if (singleField.activeFocus)
                    control.openPanel();
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: singleField.text === "" && !control._typing
                text: control.triggerPlaceholder
                color: Appearance.inputPlaceholderColor(Theme.current, control.fieldState)
                font.pixelSize: Theme.current.fontSizeRegular
                elide: Text.ElideRight
            }
        }

        Row {
            id: suffixRow

            anchors.right: parent.right
            anchors.rightMargin: Theme.current.spacingTight
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.current.spacingExtraTight

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.showClear && control.displayDates.length > 0
                    && control.hasValue && !control.disabled
                icon: "close"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
                onClicked: control.clear()
            }

            Icon {
                objectName: "calendarIcon"

                anchors.verticalCenter: parent.verticalCenter
                name: "calendar"
                size: 16
                color: Appearance.inputIconColor(Theme.current, control.fieldState)
            }
        }
    }

    readonly property bool hasValue: control.displayDates.filter((d) => d !== null).length > 0

    // 分隔符宽度。它画在 delegate 里（要夹在两半区中间），而 delegate 之间不能互拿 id，
    // 所以在这里放一个隐形探针给两侧算宽用。
    Text {
        id: separatorProbe

        visible: false
        text: control.rangeSeparator
        font.pixelSize: Theme.current.fontSizeRegular
    }

    readonly property real separatorWidth: separatorProbe.implicitWidth

    // 双输入框（dateRange / dateTimeRange）
    Row {
        id: rangeTrigger

        visible: control.triggerRender === null && control.isMultiInputRange
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: [0, 1]

            delegate: Row {
                id: halfSlot

                required property int index

                readonly property int slot: index
                readonly property real halfWidth: (rangeTrigger.width - control.separatorWidth
                                                   - suffixSlot2.width) / 2
                spacing: 0
                height: rangeTrigger.height

                Rectangle {
                    id: halfBox

                    width: halfSlot.halfWidth
                    height: rangeTrigger.height
                    radius: Theme.current.radiusSmall          // $radius-datepicker_range_input_inputWrapper
                    color: control.halfFocused(halfSlot.slot) ? Theme.current.colorFill1 : "transparent"
                    border.width: control.halfFocused(halfSlot.slot) ? 1 : 0
                    border.color: Theme.current.colorFocusBorder

                    TextInput {
                        id: halfField

                        anchors.fill: parent
                        anchors.leftMargin: Theme.current.spacingBaseTight
                        anchors.rightMargin: Theme.current.spacingExtraTight
                        verticalAlignment: Text.AlignVCenter
                        clip: true
                        color: Appearance.inputForeground(Theme.current, control.fieldState)
                        font.pixelSize: control.size === Enums.Small
                            ? Theme.current.fontSizeSmall : Theme.current.fontSizeRegular
                        enabled: !control.disabled
                        readOnly: control.inputReadOnly
                        text: halfSlot.slot === 0 ? control.startText : control.endText

                        onTextChanged: {
                            const current = halfSlot.slot === 0
                                ? control.startText : control.endText;
                            if (halfField.text === current)
                                return;
                            control._typing = true;
                            if (halfSlot.slot === 0)
                                control._typedStart = halfField.text;
                            else
                                control._typedEnd = halfField.text;
                            halfField.text = Qt.binding(function () {
                                return halfSlot.slot === 0 ? control.startText : control.endText;
                            });
                        }

                        onEditingFinished: control.commitTyped(halfField.text, halfSlot.slot)

                        // 官方是「点进输入框就开面板」，没有点击收起一说（dateInput.tsx 的
                        // onFocus → handleFocus → openPanel）。关面板靠选完、点外面或 Esc。
                        onActiveFocusChanged: {
                            if (!halfField.activeFocus)
                                return;
                            control._endFocused = halfSlot.slot === 1;
                            control.openPanel();
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: halfField.text === "" && !control._typing
                            text: control.placeholderAt(halfSlot.slot)
                            color: Appearance.inputPlaceholderColor(Theme.current, control.fieldState)
                            font.pixelSize: Theme.current.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }

                // 分隔符只在左侧那半后面出现一次
                Item {
                    id: separatorCell

                    visible: halfSlot.slot === 0
                    width: visible ? control.separatorWidth : 0
                    height: rangeTrigger.height

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: control.rangeSeparator
                        color: control._endFocused && control.panelOpen
                            ? Theme.current.colorText0 : Theme.current.colorText3
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }
        }

        // .semi-datepicker-range-input-suffix：paddingLeft 8 / paddingRight 12
        // （单输入框那条是 .semi-input-suffix-icon 的 margin 0 8，
        // 所以官方这两种形态的右间距本来就不一样：12 与 8）
        Item {
            id: suffixSlot2

            width: Theme.current.spacingTight + suffixRow2.implicitWidth
                + Theme.current.spacingBaseTight
            height: rangeTrigger.height

            Row {
                id: suffixRow2

                x: Theme.current.spacingTight
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.current.spacingExtraTight

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.showClear && control.hasValue && !control.disabled
                    icon: "close"
                    size: Enums.Small
                    variant: Enums.Borderless
                    tone: Enums.Tertiary
                    onClicked: control.clear()
                }

                Icon {
                    objectName: "calendarIcon"

                    anchors.verticalCenter: parent.verticalCenter
                    name: "calendar"
                    size: 16
                    color: Appearance.inputIconColor(Theme.current, control.fieldState)
                }
            }
        }
    }

    // rangeInputFocus：点哪半区就把「激活」给哪一侧（dateInput.tsx:272-299）
    function halfFocused(index) {
        return control.panelOpen && (index === 0 ? !control._endFocused : control._endFocused);
    }

    property bool _endFocused: false

    HoverHandler {
        id: singleHover

        enabled: !control.disabled
    }

    // 落在输入框以外的区域（后缀图标那带）才走这里；官方点触发器只开不合，
    // 关面板靠选完、点外面或 Esc。
    TapHandler {
        enabled: !control.disabled && !control.insetInput
        onTapped: control.openPanel()
    }

    // ---- 弹层 ----
    PopupBase {
        id: popup

        objectName: "datePickerPopup"
        anchor: control
        placement: control.position
        gap: control.spacing
        padding: 0
        fillColor: Theme.current.colorBg3

        // needConfirm 时点空白不再关面板，只能按「取消」（官方 v2.2.0 起）
        closePolicy: control.showFooter ? C.Popup.CloseOnEscape
            : (C.Popup.CloseOnEscape | C.Popup.CloseOnPressOutside)

        implicitWidth: panelLoader.implicitWidth
        implicitHeight: panelLoader.implicitHeight

        // 点外面 / Esc 也走这里。非受控时弹层就是状态源，开合信号由它发；
        // 受控时只负责告诉调用方「我想关」，真正的状态由 open 属性说了算。
        onAboutToShow: {
            if (control.open === undefined)
                control.openChange(true)
        }

        onAboutToHide: {
            control.discardTransient();
            if (control.open === undefined)
                control.openChange(false)
        }

        Loader {
            id: panelLoader

            active: control._panelReady
            sourceComponent: panelContent
        }
    }

    Component {
        id: panelContent

        Item {
            id: panel

            objectName: "datePickerPanel"
            implicitWidth: panel.bodyWidth
            implicitHeight: panel.bodyHeight
            width: panel.implicitWidth
            height: panel.implicitHeight

            // ---- 几何 ----
            // 月历一栏 252 + 左右内边距 16（compact 216 + 10）；年月面板按实测的
            // li 最小宽 82 ×2 栏 + 1px 分隔 = 165，monthRange 是 165 + 1 + 165 = 331
            // （$width-datepicker_insetInput_month_type_wrapper 就是这两个数）。
            readonly property real columnWidth: control.compact ? 216 + 20 : 252 + 32
            readonly property real yamColumnWidth: 82 * 2 + 1
            readonly property real presetSideWidth: 200       // $width-datepicker_presetPanel_left_and_right
            readonly property bool presetIsSide: control.presetPosition === Enums.PresetLeft
                || control.presetPosition === Enums.PresetRight
            readonly property bool hasPresets: control.presets.length > 0
            readonly property int weeksRowNum: control.isRangeType
                ? Math.max(CD.weeksInMonth(control._leftDate, control.weekStartsOn),
                           CD.weeksInMonth(control._rightDate, control.weekStartsOn))
                : CD.weeksInMonth(control._leftDate, control.weekStartsOn)

            property real sideSlotWidth: (leftLoader.item as Item ? (leftLoader.item as Item).implicitWidth : 0)
                + (rightLoader.item as Item ? (rightLoader.item as Item).implicitWidth : 0)

            // 面板尺寸一律问布局自己（columns / middle 的 implicit 尺寸），避免两处各算一遍对不上
            readonly property real panelWidth: columns.implicitWidth
            readonly property real panelHeightValue: columns.implicitHeight
            readonly property real bodyWidth: middle.implicitWidth
                + (panel.hasPresets && panel.presetIsSide ? panel.presetSideWidth : 0)
                + panel.sideSlotWidth
            readonly property real bodyHeight: middle.implicitHeight
                + (control.showFooter ? 52 : 0)      // $spacing-datepicker_footer 10+10 + 按钮 32


            readonly property bool confirmEnabled: {
                if (!control.isRangeType)
                    return true;
                const d = control.displayDates;
                return d.length >= 2 && d[0] !== null && d[1] !== null;
            }

            Row {
                id: bodyRow

                anchors.left: parent.left
                anchors.top: parent.top
                spacing: 0

                // 左槽 / 左右方位的快捷面板
                Loader {
                    id: leftLoader

                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: control.leftSlot
                }

                DateQuickControl {
                    visible: panel.hasPresets && control.presetPosition === Enums.PresetLeft
                    anchors.verticalCenter: parent.verticalCenter
                    sideHeight: panel.panelHeightValue
                    presets: control.presets
                    position: control.presetPosition
                    typeKey: control.typeKey
                    onClicked: (item) => control.handlePreset(item)
                }

                Column {
                    id: middle

                    spacing: 0

                    Loader {
                        id: topLoader

                        objectName: "topSlotLoader"
                        sourceComponent: control.topSlot
                    }

                    Loader {
                        id: presetTopLoader

                        active: panel.hasPresets && control.presetPosition === Enums.PresetTop
                        sourceComponent: Component {
                            DateQuickControl {
                                presets: control.presets
                                position: Enums.PresetTop
                                typeKey: control.typeKey
                                onClicked: (item) => control.handlePreset(item)
                            }
                        }
                    }

                    // insetInput：面板顶部那排输入框。
                    // .semi-datepicker-inset-input-wrapper：padding 12 16 / 下 0、列间距 8，
                    // 输入框 flex:1；开了它之后导航栏的上下内边距从 12 变 8。
                    Loader {
                        id: insetLoader

                        active: control.insetInput
                        sourceComponent: Component {
                            Row {
                                id: insetRow

                                readonly property real padX: control.compact ? 8 : 16
                                readonly property real fieldHeight: control.compact ? 26 : 32
                                readonly property int fieldCount: control.insetFields().length
                                readonly property int slotCount: fieldCount
                                    + (control.insetHasEnd ? 1 : 0)
                                // 分隔符两侧各 4px 内边距（.semi-datepicker-inset-input-separator）
                                readonly property real sepWidth: control.insetHasEnd
                                    ? (insetSepProbe.implicitWidth + 8) : 0
                                readonly property real fieldWidth: (panel.panelWidth
                                    - padX * 2 - sepWidth
                                    - Theme.current.spacingTight * (slotCount - 1)) / fieldCount

                                width: panel.panelWidth
                                spacing: Theme.current.spacingTight
                                leftPadding: padX
                                rightPadding: padX
                                topPadding: control.compact ? 8 : 12
                                bottomPadding: 0

                                Text {
                                    id: insetSepProbe

                                    visible: false
                                    text: "-"
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }

                                Repeater {
                                    model: control.insetFields()

                                    delegate: Item {
                                        id: insetSlot

                                        required property var modelData

                                        width: insetRow.fieldWidth
                                            + (insetSlot.modelData.separator === "" ? 0
                                               : insetRow.sepWidth + insetRow.spacing)
                                        height: insetRow.fieldHeight

                                        Rectangle {
                                            id: insetBox

                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: insetRow.fieldHeight
                                            radius: Theme.current.radiusSmall
                                            color: Theme.current.colorBg3
                                            border.width: 1
                                            border.color: Theme.current.colorBorder

                                            TextInput {
                                                anchors.fill: parent
                                                anchors.leftMargin: Theme.current.spacingExtraTight
                                                anchors.rightMargin: Theme.current.spacingExtraTight
                                                verticalAlignment: Text.AlignVCenter
                                                clip: true
                                                enabled: !insetSlot.modelData.disabled
                                                font.pixelSize: control.compact
                                                    ? Theme.current.fontSizeSmall
                                                    : Theme.current.fontSizeRegular
                                                color: Theme.current.colorText0
                                                text: insetSlot.modelData.text

                                                onEditingFinished: control.applyInsetText(
                                                    insetSlot.modelData.kind, text)
                                            }
                                        }

                                        // 日期与时间之间那个 "-"（compact 不画）
                                        Text {
                                            visible: insetSlot.modelData.separator !== ""
                                                && !control.compact
                                            anchors.left: insetBox.right
                                            anchors.leftMargin: Theme.current.spacingTight
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: insetSlot.modelData.separator
                                            color: Theme.current.colorText3
                                            font.pixelSize: Theme.current.fontSizeRegular
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        id: columns

                        spacing: 0

                        DatePanelColumn {
                            id: leftColumn

                            visible: !control.isYamType
                            pickerDate: control._leftDate
                            panelIndex: 0
                            view: control._viewLeft
                            isRange: control.isRangeType
                            syncSwitchMonth: control.syncSwitchMonth
                            showTimeType: control.showTimePart
                            showSwitchBar: control.showTimePart
                            insetInput: control.insetInput
                            timeFormat: control.timeFormat
                            densityCompact: control.compact
                            weekStartsOn: control.weekStartsOn
                            weeksRowNum: panel.weeksRowNum
                            selectedDates: control.selectedForPanel(0)
                            rangeStart: control.isRangeType ? control.displayDates[0] : null
                            rangeEnd: control.isRangeType ? control.displayDates[1] : null
                            hoverDay: control._hoverDay
                            offsetRangeStart: control._offsetStart
                            offsetRangeEnd: control._offsetEnd
                            disabledDateFn: (date) => control.isDateDisabled(date)
                            disabledHoursFn: control.disabledHoursFn(0)
                            disabledMinutesFn: control.disabledMinutesFn(0)
                            disabledSecondsFn: control.disabledSecondsFn(0)
                            hideDisabledOptions: control.hideDisabledOptions
                            disabledTimePicker: control.disabledTimePicker
                            renderDate: control.renderDate
                            renderFullDate: control.renderFullDate
                            startYear: control.startYear
                            endYear: control.endYear
                            showYamBackButton: !control.isYamType
                            switchDateText: control.switchText(0, "date")
                            switchTimeText: control.switchText(0, "time")

                            onNavAction: (action) => control.handleNav(0, action)
                            onDayClicked: (date) => control.handleDayClicked(date)
                            onDayHovered: (date) => control.handleDayHovered(date)
                            onTimePicked: (h, m, s) => control.handleTimePicked(0, h, m, s)
                            onYamYearPicked: (year) => control.handleYearMonth(0, year,
                                control._leftDate.getMonth() + 1)
                            onYamMonthPicked: (month) => control.handleYearMonth(0,
                                control._leftDate.getFullYear(), month)
                            onBackToDates: control._viewLeft = "date"
                        }

                        DatePanelColumn {
                            id: rightColumn

                            visible: control.isRangeType && !control.isYamType
                            pickerDate: control._rightDate
                            panelIndex: 1
                            view: control._viewRight
                            isRange: control.isRangeType
                            syncSwitchMonth: control.syncSwitchMonth
                            showTimeType: control.showTimePart
                            showSwitchBar: control.showTimePart
                            insetInput: control.insetInput
                            timeFormat: control.timeFormat
                            densityCompact: control.compact
                            weekStartsOn: control.weekStartsOn
                            weeksRowNum: panel.weeksRowNum
                            selectedDates: control.selectedForPanel(1)
                            rangeStart: control.displayDates[0]
                            rangeEnd: control.displayDates[1]
                            hoverDay: control._hoverDay
                            offsetRangeStart: control._offsetStart
                            offsetRangeEnd: control._offsetEnd
                            disabledDateFn: (date) => control.isDateDisabled(date)
                            disabledHoursFn: control.disabledHoursFn(1)
                            disabledMinutesFn: control.disabledMinutesFn(1)
                            disabledSecondsFn: control.disabledSecondsFn(1)
                            hideDisabledOptions: control.hideDisabledOptions
                            disabledTimePicker: control.disabledTimePicker
                            renderDate: control.renderDate
                            renderFullDate: control.renderFullDate
                            startYear: control.startYear
                            endYear: control.endYear
                            leftYear: control._leftDate.getFullYear()
                            leftMonth: control._leftDate.getMonth() + 1
                            showYamBackButton: !control.isYamType
                            switchDateText: control.switchText(1, "date")
                            switchTimeText: control.switchText(1, "time")

                            onNavAction: (action) => control.handleNav(1, action)
                            onDayClicked: (date) => control.handleDayClicked(date)
                            onDayHovered: (date) => control.handleDayHovered(date)
                            onTimePicked: (h, m, s) => control.handleTimePicked(1, h, m, s)
                            onYamYearPicked: (year) => control.handleYearMonth(1, year,
                                control._rightDate.getMonth() + 1)
                            onYamMonthPicked: (month) => control.handleYearMonth(1,
                                control._rightDate.getFullYear(), month)
                            onBackToDates: control._viewRight = "date"
                        }

                        // monthRange：两个年月面板并排，中间一条 1px 线
                        Row {
                            id: yamRangeBox

                            visible: control.isYamType && control.isRangeType
                            spacing: 0

                            DateYearMonthPanel {
                                id: yamLeft

                                pickerDate: control._leftDate
                                showBack: false
                                compact: control.compact
                                startYear: control.startYear
                                endYear: control.endYear
                                disabledDateFn: (date) => control.isDateDisabled(date)

                                onYearPicked: (year) => control.handleYearMonth(0, year,
                                    control._leftDate.getMonth() + 1)
                                onMonthPicked: (month) => control.handleYearMonth(0,
                                    control._leftDate.getFullYear(), month)
                            }

                            Rectangle {
                                width: 1
                                height: yamLeft.height
                                color: Theme.current.colorBorder
                            }

                            DateYearMonthPanel {
                                id: yamRight

                                pickerDate: control._rightDate
                                showBack: false
                                compact: control.compact
                                isRightPanel: true
                                leftYear: control._leftDate.getFullYear()
                                leftMonth: control._leftDate.getMonth() + 1
                                startYear: control.startYear
                                endYear: control.endYear
                                disabledDateFn: (date) => control.isDateDisabled(date)

                                onYearPicked: (year) => control.handleYearMonth(1, year,
                                    control._rightDate.getMonth() + 1)
                                onMonthPicked: (month) => control.handleYearMonth(1,
                                    control._rightDate.getFullYear(), month)
                            }
                        }

                        // 纯 month / year：单个年月面板
                        DateYearMonthPanel {
                            id: yamSingle

                            visible: control.isYamType && !control.isRangeType
                            pickerDate: control._leftDate
                            showBack: false
                            compact: control.compact
                            startYear: control.startYear
                            endYear: control.endYear
                            disabledDateFn: (date) => control.isDateDisabled(date)

                            onYearPicked: (year) => control.handleYearMonth(0, year,
                                control._leftDate.getMonth() + 1)
                            onMonthPicked: (month) => control.handleYearMonth(0,
                                control._leftDate.getFullYear(), month)
                        }
                    }

                    Loader {
                        id: presetBottomLoader

                        active: panel.hasPresets && control.presetPosition === Enums.PresetBottom
                        sourceComponent: Component {
                            DateQuickControl {
                                presets: control.presets
                                position: Enums.PresetBottom
                                typeKey: control.typeKey
                                onClicked: (item) => control.handlePreset(item)
                            }
                        }
                    }

                    Loader {
                        id: bottomLoader

                        objectName: "bottomSlotLoader"
                        sourceComponent: control.bottomSlot
                    }
                }

                DateQuickControl {
                    visible: panel.hasPresets && control.presetPosition === Enums.PresetRight
                    anchors.verticalCenter: parent.verticalCenter
                    sideHeight: panel.panelHeightValue
                    presets: control.presets
                    position: control.presetPosition
                    typeKey: control.typeKey
                    onClicked: (item) => control.handlePreset(item)
                }

                Loader {
                    id: rightLoader

                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: control.rightSlot
                }
            }

            // 确认底栏（needConfirm）
            Item {
                id: footer

                visible: control.showFooter
                anchors.left: parent.left
                anchors.right: parent.right
                y: bodyRow.height
                height: 52

                Rectangle {
                    anchors.fill: parent
                    color: Theme.current.colorFill0
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.current.spacingBaseTight

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("取消")
                        size: Enums.Default
                        variant: Enums.Borderless
                        onClicked: control.handleCancel()
                    }

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("确定")
                        size: Enums.Default
                        tone: Enums.Primary
                        variant: Enums.Solid
                        enabled: panel.confirmEnabled
                        onClicked: control.handleConfirm()
                    }
                }
            }
        }
    }


    function handleConfirm() {
        const dates = control.displayDates;
        control._pending = null;
        control._rangeSelecting = false;
        control.notify(dates, true);
        control.closePanel();
    }

    function handleCancel() {
        // onCancel 报的是「确认之前已提交的值」：受控给 value，非受控给内部值
        const previous = control.value !== undefined ? control.toDates(control.value)
            : control._inner;
        control._pending = null;
        control._rangeSelecting = false;
        control.cancelled(control.dateArg(previous), control.stringArg(previous));
        control.closePanel();
    }

    function handlePreset(item) {
        const start = control.resolvePreset(item.start);
        const end = control.resolvePreset(item.end);
        if (control.isRangeType)
            control.commit([start, end === null ? start : end]);
        else
            control.commit([start !== null ? start : end]);
        control.presetClicked(item);
        if (!control.showFooter)
            control.closePanel();
    }

    function resolvePreset(v) {
        if (v === undefined || v === null)
            return null;
        if (typeof v === "function")
            return control.toDate(v());
        return control.toDate(v);
    }

    // ---- 供子面板用的小工具 ----
    function selectedForPanel(panel) {
        if (control.isRangeType)
            return [];
        return control.displayDates;
    }

    function switchText(panel, which) {
        const date = which === "date"
            ? (control.displayDates[panel] !== undefined && control.displayDates[panel] !== null
                ? control.displayDates[panel] : control.viewSideDate(panel))
            : control.viewSideDate(panel);
        if (date === null)
            return "";
        return DF.format(date, which === "date" ? "yyyy-MM-dd" : control.timeFormat);
    }

    // DateTimeColumns 调用时不带参数，所以 panel 只能靠闭包捕获（写成 (panel) => 会把
    // 外面的 panel 遮蔽成 undefined）
    function disabledHoursFn(panel) {
        if (control.disabledTime === null)
            return null;
        return function () {
            const spec = control.timeSpecFor(panel);
            return spec === null || spec.disabledHours === undefined ? null
                : spec.disabledHours;
        };
    }

    function disabledMinutesFn(panel) {
        if (control.disabledTime === null)
            return null;
        return function () {
            const spec = control.timeSpecFor(panel);
            return spec === null || spec.disabledMinutes === undefined ? null
                : spec.disabledMinutes;
        };
    }

    function disabledSecondsFn(panel) {
        if (control.disabledTime === null)
            return null;
        return function () {
            const spec = control.timeSpecFor(panel);
            return spec === null || spec.disabledSeconds === undefined ? null
                : spec.disabledSeconds;
        };
    }

    function timeSpecFor(panel) {
        if (control.disabledTime === null)
            return null;
        const date = panel === 1 ? control._rightDate : control._leftDate;
        const spec = control.disabledTime(date, panel === 1 ? "right" : "left");
        return spec === null || spec === undefined ? null : spec;
    }

    // 内嵌那排：日期格只给日期部分、时间格只给时间部分（官方把字符串按空格切开，
    // getInsetInputValueFromInsetInputStr.ts），顺序是 日期 时间 - 日期 时间。
    readonly property string insetDateFmt: control.fmt.split(" ")[0]
    readonly property bool insetHasEnd: control.isRangeType && control.typeKey !== "monthRange"
    readonly property bool insetHasTime: control.isTimeType

    function insetFields() {
        const out = [];
        const dates = control.displayDates;
        out.push({ kind: "dateStart", text: control.textOf(dates, 0, control.insetDateFmt),
                   disabled: false, separator: "" });
        if (control.insetHasTime)
            out.push({ kind: "timeStart", text: control.textOf(dates, 0, control.timeFormat),
                       disabled: control.textOf(dates, 0, control.insetDateFmt) === "",
                       separator: "" });
        if (control.insetHasEnd)
            out.push({ kind: "dateEnd", text: control.textOf(dates, 1, control.insetDateFmt),
                       disabled: false, separator: "-" });
        if (control.insetHasEnd && control.insetHasTime)
            out.push({ kind: "timeEnd", text: control.textOf(dates, 1, control.timeFormat),
                       disabled: control.textOf(dates, 1, control.insetDateFmt) === "",
                       separator: "" });
        return out;
    }

    function applyInsetText(kind, text) {
        const isTime = kind === "timeStart" || kind === "timeEnd";
        const idx = (kind === "dateEnd" || kind === "timeEnd") ? 1 : 0;
        const dates = control.displayDates.slice();
        if (isTime) {
            const t = DF.parse(text, control.timeFormat);
            if (t === null)
                return;
            const base = dates[idx] !== null && dates[idx] !== undefined
                ? dates[idx] : control.viewSideDate(idx);
            dates[idx] = new Date(base.getFullYear(), base.getMonth(), base.getDate(),
                                  t.getHours(), t.getMinutes(), t.getSeconds());
        } else {
            const d = DF.parse(text, control.insetDateFmt);
            if (d === null)
                return;
            dates[idx] = control.keepTime(d, dates[idx]);
        }
        control.commit(dates);
    }

    function mergeTime(day, time) {
        if (day === null || day === undefined)
            return time;
        return new Date(day.getFullYear(), day.getMonth(), day.getDate(),
                        time.getHours(), time.getMinutes(), time.getSeconds());
    }

    // 受控：调用方改 open 才真的开合
    onOpenChanged: {
        if (control.open === undefined)
            return;
        if (control.open === true) {
            if (!popup.isOpen)
                control.showPanel();
        } else if (popup.isOpen) {
            popup.close();
        }
    }

    Component.onCompleted: {
        if (control.open === true || control.defaultOpen)
            control.showPanel();
    }
}
