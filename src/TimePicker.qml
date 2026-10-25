pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as C
import Semi
import "DateFormat.js" as DF

// 时间选择。点输入框弹出「(上午下午) 时 / 分 / 秒」几列滚动列表，点中一项立刻提交。
//
//     TimePicker { }                                            // HH:mm:ss
//     TimePicker { defaultValue: "10:24"; format: "HH:mm" }
//     TimePicker { use12Hours: true }                           // a h:mm:ss
//     TimePicker { minuteStep: 15; secondStep: 10 }
//     TimePicker { scrollItemProps: ({ mode: "wheel", cycled: true }) }
//     TimePicker { type: "timeRange"; defaultValue: ["10:23", "12:38"] }
//     TimePicker { disabledHours: () => [0, 1, 2, 3] }
//     TimePicker { value: tpValue; onChanged: (d, s) => tpValue = d }
//
// 官方属性面见 semi-ui/timePicker/TimePicker.tsx:34-104 与
// semi-foundation/timePicker/constants.ts，行为见 foundation.ts / ComboxFoundation.ts /
// Combobox.tsx，外观见 timePicker.scss + scrollList.scss。
//
// 值可以是 Date / 时间戳 / 字符串（range 时是这几者的数组）。字符串**严格按 format 解**
// —— date-fns 的 parse：'10:24' 配 'HH:mm:ss' 解不出来，配 'HH:mm' 才解得出；
// 解不出来就整个丢掉、按空值处理（foundation.ts:158-172）。
//
// 与官方的三处有意差异：
//   1. 官方 parseToDate 用「今天」当基准日期补 Date 的年月日（utils/index.ts:22），
//      这里统一用 1970-01-01，值只表示时刻，测试也才写得确定。
//   2. 敲字后失焦的行为照 handleInputBlur:388-410 —— 没解成值的输入直接丢回去，
//      敲空了连值一起清；官方没有「回车提交」这回事，所以 Input.accepted 不接。
//   3. 受控（传了 open）时弹层 NoAutoClose，点外面 / Esc 只发 openChange，
//      跟官方 visible 完全由外部说了算的语义一致。
//
// 本库没做的官方属性：className / popupClassName / popupStyle / getPopupContainer /
// dropdownMargin / stopPropagation / preventScroll / aria-*（DOM 与 React 专有）、
// motion（PopupBase 的进出场动画是硬编码的，没有开关）、
// timeZone（QML 的 Date 只有本地时区，见 PROGRESS.md 待办）。
Item {
    id: control

    // ---- 值 ----
    // 受控值。官方是 `'value' in props`，QML 分不出「没写」和「写了 undefined」，
    // 所以用 undefined 当非受控哨兵（与 Radio / Rating / PinCode / DatePicker 同一口径）
    property var value: undefined
    property var defaultValue: undefined
    property string type: "time"              // "time" | "timeRange"
    // 展示格式。留空时按 use12Hours 取 HH:mm:ss / a h:mm:ss（ComboxFoundation.ts:88-96）
    property string format: ""
    property bool use12Hours: false

    // ---- 列的生成 ----
    property int hourStep: 1
    property int minuteStep: 1
    property int secondStep: 1
    property bool hideDisabledOptions: false
    property var disabledHours: null          // () => number[]
    property var disabledMinutes: null        // (hour) => number[]
    property var disabledSeconds: null        // (hour, minute) => number[]
    // 仅 range 生效：(dates, "left"|"right") => ({ disabledHours: ... })，
    // 返回里有的字段覆盖顶层、没有的回退顶层（TimePicker.tsx:359-402）
    property var disabledTime: null

    // ---- 输入框 ----
    property bool disabled: false
    property bool showClear: true
    property string clearIcon: ""
    // 留空时按类型取 locale 的占位（locale/source/zh_CN.ts:21-25）
    property var placeholder: undefined
    property int size: Enums.Default
    property var prefix: undefined
    property string prefixIcon: ""
    property string insetLabel: ""
    property bool borderless: false
    property bool inputReadOnly: false
    property int validateStatus: Enums.StatusDefault
    // 官方默认 ' ~ '（constants.ts:6）。这里与 DatePicker 同口径：给 "~"，展示时两侧补空格
    property string rangeSeparator: "~"

    // ---- 面板 ----
    property var panelHeader: undefined       // 字符串 / Component / range 时 [起, 止]
    property var panelFooter: undefined
    property var open: undefined              // 受控显隐；undefined 表示非受控
    property bool defaultOpen: false
    property bool autoFocus: false
    property bool focusOnOpen: false
    property int position: Enums.BottomLeft
    property bool autoAdjustOverflow: true
    // ({ mode: "wheel", cycled: true })
    property var scrollItemProps: null
    // 自定义触发器：Component，根节点上的 placeholder 会被注入（官方 triggerRender({placeholder})）
    property Component triggerRender: null

    // 官方 onChange（本库叫 changed，与 DatePicker 同口径）：(Date, string)，range 时两边都是数组
    signal changed(var date, var dateString)
    signal openChange(bool isOpen)
    signal focused()
    signal blurred()

    readonly property bool isRange: control.type === "timeRange"
    readonly property string fmt: control.format !== ""
        ? control.format : DF.defaultTimeFormat(control.use12Hours)
    readonly property string sep: DF.rangeSeparatorOf(control.rangeSeparator)
    // locale zh_CN TimePicker.placeholder（TimeInput.tsx:159 是 placeholder || locale[type]）
    readonly property string placeholderText: control.placeholder !== undefined
        && control.placeholder !== null && String(control.placeholder) !== ""
        ? String(control.placeholder)
        : (control.isRange ? qsTr("请选择时间范围") : qsTr("请选择时间"))

    readonly property bool wheelMode: control.scrollItemProps !== null
        && control.scrollItemProps !== undefined
        && control.scrollItemProps.mode === "wheel"
    readonly property bool cycled: control.scrollItemProps !== null
        && control.scrollItemProps !== undefined && control.scrollItemProps.cycled === true

    // ---- 内部状态 ----
    property var _inner: []                   // 非受控时的 [Date] / [Date|null, Date|null]
    readonly property var _popup: popup       // 弹层根节点，与 DatePicker._popup 同形
    property bool _typing: false              // 正在敲字，输入框显示原始输入
    property string _typedText: ""
    property bool _invalid: false             // foundation.ts:364-386 validateDates
    // 非受控时弹层自己就是状态源（坑 48）；受控时听调用方的 open
    readonly property bool panelOpen: control.open !== undefined ? control.open === true
        : popup.isOpen

    implicitWidth: 211
    implicitHeight: Appearance.inputWrapperHeight(Theme.current, control.size)

    // ---- 取值 ----
    function toDate(v) {
        if (v === undefined || v === null || v === "")
            return null;
        if (v instanceof Date)
            return v;
        if (typeof v === "number")
            return new Date(v);
        return DF.parse(String(v), control.fmt);
    }

    // initDataFromDefaultValue:146-160：非数组包成单元素数组逐段解，**只要有一段解不出来
    // 就整个作废**（parsedValues.length !== value.length → value = []）。
    // range 再补齐成两格，好让左右两块面板都有得显示；另一头没选时尾格留 null。
    function datesOf(raw) {
        if (raw === undefined || raw === null)
            return [];
        const src = Array.isArray(raw) ? raw : [raw];
        const out = [];
        for (let i = 0; i < src.length; ++i) {
            const d = control.toDate(src[i]);
            if (d === null)
                return [];
            out.push(d);
        }
        if (out.length === 0)
            return [];
        if (!control.isRange)
            return [out[0]];
        return [out[0], out.length > 1 ? out[1] : null];
    }

    readonly property var displayDates: control.value !== undefined
        ? control.datesOf(control.value) : control._inner

    function dateAt(index) {
        const d = control.displayDates;
        return d.length > index ? d[index] : null;
    }

    function textOf(date) {
        return date === null || date === undefined ? "" : DF.format(date, control.fmt);
    }

    // formatValue:412-435：dates.map(空→'').join(rangeSeparator)，所以只选了一半时
    // 连分隔符都不出现（长度 1 的数组 join 不出分隔符）
    function trimTail(dates) {
        let last = -1;
        for (let i = 0; i < dates.length; ++i)
            if (dates[i] !== null && dates[i] !== undefined)
                last = i;
        return dates.slice(0, last + 1);
    }

    function rangeParts(dates) {
        return control.trimTail(dates).map(function (d) { return control.textOf(d); });
    }

    readonly property string formattedText: {
        const d = control.displayDates;
        if (!control.isRange)
            return control.textOf(d.length > 0 ? d[0] : null);
        return control.rangeParts(d).join(control.sep);
    }
    // 敲字期间显示用户输入的原样，失焦后回到格式化结果（handleInputBlur:388-410）
    readonly property string displayText: control._typing ? control._typedText
        : control.formattedText

    readonly property bool hasValue: control.displayDates.length > 0
        && control.displayDates.some(v => v !== null && v !== undefined)

    // ---- 提交 ----
    function dateArg(dates) {
        if (!control.isRange)
            return dates.length > 0 ? dates[0] : null;
        return control.trimTail(dates);
    }

    function stringArg(dates) {
        if (!control.isRange)
            return control.textOf(dates.length > 0 ? dates[0] : null);
        // _notifyChange:466-473：range 的字符串参数就是把 inputValue 按分隔符拆开，
        // 所以只选一半时是长度 1 的数组
        return control.rangeParts(dates);
    }

    function sameArg(a, b) {
        if (Array.isArray(a) && Array.isArray(b))
            return JSON.stringify(a) === JSON.stringify(b);
        return a === b;
    }

    // foundation.ts:495-515：格式化后的字符串没变就不发 onChange
    function commit(dates) {
        const after = control.stringArg(dates);
        const differs = !control.sameArg(control.stringArg(control.displayDates), after);
        if (control.value === undefined)
            control._inner = dates;
        if (differs)
            control.changed(control.dateArg(dates), after);
    }

    function clear() {
        control._typing = false;
        control._typedText = "";
        control._invalid = false;
        control.commit(control.isRange ? [null, null] : []);
    }

    // 面板里点中一项：Combobox.tsx:135-174
    function applyPick(panel, kind, value) {
        const base = control.dateAt(panel);
        const src = base === null ? new Date(1970, 0, 1, 0, 0, 0) : base;
        const next = new Date(src.getFullYear(), src.getMonth(), src.getDate(),
            src.getHours(), src.getMinutes(), src.getSeconds());
        if (kind === "hour") {
            if (control.use12Hours)
                next.setHours(DF.isPM(next) ? (value % 12) + 12 : value % 12);
            else
                next.setHours(value);
        } else if (kind === "minute") {
            next.setMinutes(value);
        } else if (kind === "second") {
            next.setSeconds(value);
        } else if (kind === "ampm") {
            if (value === 1 && next.getHours() < 12)
                next.setHours((next.getHours() % 12) + 12);
            else if (value === 0 && next.getHours() >= 12)
                next.setHours(next.getHours() - 12);
        }
        const dates = control.displayDates.slice();
        while (dates.length < (control.isRange ? 2 : 1))
            dates.push(null);
        dates[panel] = next;
        // handleSelect 会把 inputValue 重写成格式化结果，敲字状态到此结束
        control._typing = false;
        control._typedText = "";
        control.commit(dates);
    }

    // handleInputChange:313-346：每敲一个字就试着解一次，解不出或撞上禁用只记 invalid，
    // 不改值、也不打断输入（所以输入框保留用户敲的原样文本）。
    function parseTyped(text) {
        if (text === "") {
            control._invalid = false;
            control.commit(control.isRange ? [null, null] : []);
            return;
        }
        // 位数没敲够的中间态直接跳过，别把 '10:2' 当成 10:02 提交出去（foundation.ts:326-329）
        const bits = control.isRange ? String(text).split(control.sep) : [String(text)];
        for (let i = 0; i < bits.length; ++i) {
            if (!DF.isFormatLike(bits[i], control.fmt))
                return;
        }
        const dates = control.parseText(text);
        if (dates === null || control.datesDisabled(dates)) {
            control._invalid = true;
            return;
        }
        control._invalid = false;
        control.commit(dates);
    }

    // parseInput:438-448：按分隔符拆开逐段解，range 要求两段都解得出
    function parseText(text) {
        if (!control.isRange) {
            const d = control.toDate(text);
            return d === null ? null : [d];
        }
        const bits = String(text).split(control.sep);
        const out = [];
        for (let i = 0; i < 2; ++i) {
            const d = control.toDate(bits.length > i ? bits[i] : "");
            if (d === null)
                return null;
            out.push(d);
        }
        return out;
    }

    // validateDates:364-386 + isDisabledHMS:97-112（禁用表按 0-23 的小时直接查，不做 12 小时映射）
    function datesDisabled(dates) {
        for (let i = 0; i < dates.length; ++i) {
            const d = dates[i];
            if (d === null || d === undefined)
                continue;
            const panel = control.isRange && i === 1 ? 1 : 0;
            const hours = control.disabledHoursFor(panel);
            const minutes = control.disabledMinutesFor(panel);
            const seconds = control.disabledSecondsFor(panel);
            if (typeof hours === "function" && hours().indexOf(d.getHours()) >= 0)
                return true;
            if (typeof minutes === "function"
                && minutes(d.getHours()).indexOf(d.getMinutes()) >= 0)
                return true;
            if (typeof seconds === "function"
                && seconds(d.getHours(), d.getMinutes()).indexOf(d.getSeconds()) >= 0)
                return true;
        }
        return false;
    }

    // handleInputBlur:388-410：敲出来但没解成值的输入丢回去，回到格式化后的当前值。
    // （敲空那条不用在这里补：parseTyped('') 已经先把值清掉了。）
    function handleBlur() {
        control._typing = false;
        control._typedText = "";
        control._invalid = false;
    }

    // ---- range 面板的禁用规则（TimePicker.tsx:359-402）----
    function disabledTimeFor(panel) {
        if (!control.isRange || typeof control.disabledTime !== "function")
            return null;
        return control.disabledTime(control.displayDates, panel === 0 ? "left" : "right");
    }

    function pickFn(one, key, fallback) {
        if (one !== null && one !== undefined && one[key] !== undefined)
            return one[key];
        return fallback;
    }

    function disabledHoursFor(panel) {
        return control.pickFn(control.disabledTimeFor(panel), "disabledHours", control.disabledHours);
    }

    function disabledMinutesFor(panel) {
        return control.pickFn(control.disabledTimeFor(panel), "disabledMinutes", control.disabledMinutes);
    }

    function disabledSecondsFor(panel) {
        return control.pickFn(control.disabledTimeFor(panel), "disabledSeconds", control.disabledSeconds);
    }

    function headerFor(panel) {
        return Array.isArray(control.panelHeader) ? control.panelHeader[panel] : control.panelHeader;
    }

    function footerFor(panel) {
        return Array.isArray(control.panelFooter) ? control.panelFooter[panel] : control.panelFooter;
    }

    // ---- 开合 ----
    function openPanel() {
        if (control.disabled || control.panelOpen)
            return;
        if (control.open !== undefined)
            control.openChange(true);      // 受控：只通知，开合由调用方改 open
        else
            popup.open();
        if (control.focusOnOpen)
            control.focusInput();
    }

    function closePanel() {
        if (control.open !== undefined)
            control.openChange(false);
        else
            popup.close();
    }

    // 官方 ref 上的 focus() / blur() 都是空实现（TimePicker.tsx:464-472 整个被注释掉，
    // autoFocus 那条还挂着 TODO），这里只留一个真能用的聚焦；QML 的 Item.focus 是
    // 保留属性，方法不能同名（坑 26 那一类）。
    function focusInput() {
        input.input.forceActiveFocus();
    }

    // ---- 触发器 ----
    Input {
        id: input

        objectName: "timePickerInput"
        anchors.fill: parent
        visible: control.triggerRender === null
        size: control.size
        enabled: !control.disabled
        borderless: control.borderless
        readOnly: control.inputReadOnly
        // TimeInput.tsx:166 mergeValidateStatus = invalid ? 'error' : validateStatus
        validateStatus: control._invalid ? Enums.StatusDanger : control.validateStatus
        showClear: control.showClear && !control.disabled
        clearIcon: control.clearIcon
        insetLabel: control.insetLabel
        prefix: control.prefix
        prefixIcon: control.prefixIcon
        placeholderText: control.placeholderText
        suffixIcon: "clock"
        // TimeInput.tsx:169 hideSuffix：出清除按钮时把时钟图标让位掉
        hideSuffix: true
        text: control.displayText

        onTextChanged: {
            if (input.text === control.displayText)
                return;
            // 必须先存敲进去的文本、再切 _typing：displayText 是绑定，_typing 一变就立刻
            // 重算，先切状态会让它读到上一轮的 _typedText，把刚敲的那个字符冲掉。
            control._typedText = input.text;
            control._typing = true;
            control.parseTyped(input.text);
            // 重新挂回绑定：敲字不会自己断开绑定，不挂回来值变了文字就不跟了（已知坑 72）
            input.text = Qt.binding(function () { return control.displayText; });
        }

        onFieldActiveFocusChanged: {
            if (input.fieldActiveFocus) {
                control.focused();
                control.openPanel();      // handleFocus:269-274
            } else {
                control.blurred();
                control.handleBlur();     // handleInputBlur:388-410
            }
        }
    }

    Loader {
        id: customTrigger

        anchors.fill: parent
        active: control.triggerRender !== null
        sourceComponent: control.triggerRender
    }

    // 官方 triggerRender({ placeholder })：把占位文案注入自定义触发器的根节点
    Binding {
        target: customTrigger.item
        when: customTrigger.item !== null
        property: "placeholder"
        value: control.placeholderText
    }

    // 自定义触发器：官方外层 div 的 onClick 就是 openPanel（TimePicker.tsx:562-564），只开不合
    TapHandler {
        enabled: control.triggerRender !== null && !control.disabled
        onTapped: control.openPanel()
    }

    PopupBase {
        id: popup

        objectName: "timePickerPopup"
        anchor: control
        placement: control.position
        gap: 4
        padding: 0
        fillColor: Theme.current.colorBg3
        autoFlip: control.autoAdjustOverflow
        // 受控时面板不能自己关（官方 visible={Boolean(open)}，点外面 / Esc 都只是转成
        // onOpenChange，真正的开合由调用方改 open 决定）
        closePolicy: control.open !== undefined ? C.Popup.NoAutoClose
            : (C.Popup.CloseOnEscape | C.Popup.CloseOnPressOutside)

        implicitWidth: panels.implicitWidth
        implicitHeight: panels.implicitHeight

        onAboutToShow: {
            if (control.open === undefined)
                control.openChange(true);
        }

        onAboutToHide: {
            if (control.open === undefined)
                control.openChange(false);
        }

        Row {
            id: panels

            spacing: 0

            Repeater {
                model: control.isRange ? 2 : 1

                delegate: Item {
                    id: panelSlot

                    required property int index

                    // range 时左面板额外让出 2px 给中间的分割线
                    // （$width-timePicker_range_panel_scrolllist_body-border）
                    width: panel.implicitWidth + (control.isRange && panelSlot.index === 0 ? 2 : 0)
                    height: panel.implicitHeight

                    TimePickerPanel {
                        id: panel

                        objectName: "timePickerPanel" + panelSlot.index
                        date: control.dateAt(panelSlot.index)
                        timeFormat: control.fmt
                        use12Hours: control.use12Hours
                        hourStep: control.hourStep
                        minuteStep: control.minuteStep
                        secondStep: control.secondStep
                        hideDisabledOptions: control.hideDisabledOptions
                        disabledHoursFn: control.disabledHoursFor(panelSlot.index)
                        disabledMinutesFn: control.disabledMinutesFor(panelSlot.index)
                        disabledSecondsFn: control.disabledSecondsFor(panelSlot.index)
                        wheel: control.wheelMode
                        cycled: control.cycled
                        header: control.headerFor(panelSlot.index)
                        footer: control.footerFor(panelSlot.index)
                        rangePanel: control.isRange
                        onPicked: (kind, value) => control.applyPick(panelSlot.index, kind, value)
                    }

                    // 两块面板中间 2px 分割线
                    // （$width-timePicker_range_panel_scrolllist_body-border）
                    Rectangle {
                        visible: control.isRange && panelSlot.index === 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: Theme.current.colorBorder
                    }
                }
            }
        }
    }

    // 受控：调用方改 open 才真的开合（这里不能再走 openPanel / closePanel，
    // 它们会再把 openChange 发回给调用方）
    onOpenChanged: {
        if (control.open === undefined)
            return;
        if (control.open === true) {
            if (!popup.isOpen)
                popup.open();
        } else if (popup.isOpen) {
            popup.close();
        }
    }

    Component.onCompleted: {
        if (control.value === undefined)
            control._inner = control.datesOf(control.defaultValue);
        if (control.defaultOpen)
            control.openPanel();
        if (control.autoFocus)
            control.focusInput();
    }
}
