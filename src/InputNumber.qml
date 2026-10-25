import QtQuick
import QtQuick.Layouts
import "InputNumberCurrency.js" as Money

// 数字输入框。官方 API 面见 semi-ui/inputNumber/index.tsx，步进 / 钳位 / 格式化逻辑见
// semi-foundation/inputNumber/foundation.ts，外观见 inputNumber.scss + variables.scss。
//
//     InputNumber { min: 1; max: 10; step: 2 }
//     InputNumber { innerButtons: true; suffix: "小时" }
//     InputNumber { onChange: console.log(v); onNumberChange: console.log(v) }
//     InputNumber { currency: "CNY"; localeCode: "zh-CN" }
//
// 结构照官方 DOM：wrapper 是 inline-flex + 垂直居中，里面先是 Input，步进器列是
// Input 的兄弟节点（index.tsx:587-589）；innerButtons 时步进器改挂到 Input 的 suffix
// 槽，并且只在悬浮 / 聚焦时出现，否则显示用户自己的 suffix（index.tsx:499-508）。
Item {
    id: control

    // ---- 值 ----
    // 官方区分受控 value 与非受控 defaultValue；QML 没有这层二象性，value 既是初值
    // 也是当前值，组件内部改值会断掉外部绑定（需要跟随的话自己 Qt.binding 装回去）。
    property var value: undefined
    property var defaultValue: undefined
    property var min: -Infinity
    property var max: Infinity
    property real step: 1
    // v2.13 起默认值由 1 调整为 10（constants.ts:10 + index.tsx:124）
    property real shiftStep: 10
    // 官方 precision 没有默认值，也不从 step 反推（源码里没有任何推断逻辑）。
    // QML 的 int 不能留空，用 -1 表示「未设置」
    property int precision: -1

    // ---- 显示格式 ----
    property var formatter: null
    property var parser: null
    // 官方是 boolean | { threshold?: number }，threshold 默认 15 位有效数字
    // （foundation.ts:596-603）。默认值必须写 undefined 而不是 false：qmllint 会照初始值
    // 把属性收窄成 bool，传对象会被强转成 true
    property var scientificNotation: undefined
    // QML 的 JS 引擎没有 Intl（实测 typeof Intl === undefined），货币只能靠下面的常量表
    property var currency: false
    property string currencyDisplay: "symbol"
    property bool showCurrencySymbol: true
    property string localeCode: ""

    // ---- 步进器形态 ----
    property bool innerButtons: false
    property bool hideButtons: false
    property bool keepFocus: false
    // 官方 defaultProps 把 pressInterval 也写成了 DEFAULT_PRESS_TIMEOUT，即 250
    // （index.tsx:122-123），不是 constants 里那个 0
    property int pressTimeout: 250
    property int pressInterval: 250

    // ---- 转发给 Input ----
    property int size: Enums.Default
    property string placeholderText: ""
    property var prefix: undefined
    property var suffix: undefined
    property string insetLabel: ""
    property bool showClear: false
    property string clearIcon: ""
    property bool borderless: false
    property bool readOnly: false
    property bool autofocus: false
    property int validateStatus: Enums.StatusDefault
    // ColorPicker 把它压进分段控件里时需要改圆角，本库便利写法，透给 Input
    property real radius: Theme.current.radiusSmall

    // ---- 回调 ----
    // 官方 onFocus 在 QML 里没法直接写：Item 已经有 focus 属性了，所以信号叫 focused
    signal focused()
    signal blur()
    signal change(var value)
    signal numberChange(var value)
    signal upClick(var value)
    signal downClick(var value)

    onValueChanged: {
        if (!control._writingValue)
            control.applyValue();
    }

    // 官方在 props 变化时重渲染（index.tsx:398-412）。这里跟着重算显示，顺带解决
    // 「value 绑定先于 scientificNotation / currency 那几个绑定落地」的时序问题：
    // 只靠 Component.onCompleted 那次快照会漏掉后到的格式化配置。
    onScientificNotationChanged: control.applyValue()
    onCurrencyChanged: control.applyValue()
    onCurrencyDisplayChanged: control.applyValue()
    onShowCurrencySymbolChanged: control.applyValue()
    onPrecisionChanged: control.applyValue()

    // 官方 state.number：只有解析得出合法数字时才有值，清空后回到 undefined
    property var number: undefined
    readonly property bool hovering: wrapHover.hovered
    readonly property bool focusing: focusWatch.focused
    readonly property bool stepDisabled: !control.enabled || control.readOnly
    readonly property bool notAllowedUp: !control.enabled || (control.number !== undefined
        && control.number === control.max)
    readonly property bool notAllowedDown: !control.enabled || (control.number !== undefined
        && control.number === control.min)
    // 内联步进器只在悬浮或聚焦时出现（index.tsx:503）
    readonly property bool innerShown: control.innerButtons && (control.hovering || control.focusing)
    readonly property int controlHeight: Appearance.inputWrapperHeight(Theme.current, control.size)
    readonly property bool currencyActive: control.currency === true
        || (typeof control.currency === "string" && String(control.currency).trim() !== "")
    readonly property bool scientificActive: control.scientificNotation === true
        || (control.scientificNotation !== null && typeof control.scientificNotation === "object")

    // 内层那个 Input / TextInput，测试与外部聚焦都从这里进
    readonly property alias innerInput: inner
    readonly property alias field: inner.input

    // 官方 wrapper 是 inline-flex，宽度由内容撑开：Input 的自然宽 + 外层步进器（4 + 16）。
    // innerButtons / hideButtons 时步进器不占外层位置。
    implicitWidth: inner.implicitWidth
        + ((control.hideButtons || control.innerButtons) ? 0 : outerStepper.implicitWidth)
    implicitHeight: control.controlHeight

    // 只在组件自己写显示串时吃掉 Input 的 onTextChanged，避免递归
    property bool _applying: false
    property int _pressDir: 0
    property bool _pressShift: false
    property var _lastNotifiedNumber: undefined
    // 组件内部写 value 时不要再走一遍外部同步，否则会把用户正打的「1.」压成「1」
    property bool _writingValue: false


    // ---- 数字 ↔ 字符串 ----

    // foundation.ts:537-554 _getPrecLen：非有限值与 0 记 0 位，指数写法要减掉指数
    function precLen(x) {
        const n = Number(x);
        if (!Number.isFinite(n) || n === 0)
            return 0;
        const s = String(Math.abs(n));
        if (s.indexOf("e") !== -1) {
            const parts = s.split("e");
            const mantissa = parts[0].indexOf(".") !== -1 ? parts[0].split(".")[1].length : 0;
            return Math.max(0, mantissa - parseInt(parts[1], 10));
        }
        return s.indexOf(".") !== -1 ? s.split(".")[1].length : 0;
    }

    // utils/number.ts:9-18：先按最大小数位放大成整数再运算，避开二进制误差
    function accurateAdd(a, b) {
        const scale = Math.pow(10, Math.max(control.precLen(a), control.precLen(b)));
        return Math.round(a * scale + b * scale) / scale;
    }

    function accurateMinus(a, b) {
        return control.accurateAdd(a, -b);
    }

    // 把显示串还原成数字：parser → 去货币符号 → 只留数字相关字符
    function toNumber(raw, adjustPrec) {
        let s = String(raw);
        if (typeof control.parser === "function")
            s = String(control.parser(s));
        if (control.currencyActive)
            s = control.parseCurrencyString(s);
        s = s.replace(/[^\d+\-.eE]/g, "");
        if (s === "" || s === "-" || s === "+" || s === ".")
            return undefined;
        let n = Number(s);
        if (!Number.isFinite(n))
            return undefined;
        if (adjustPrec && control.precision >= 0)
            n = Number(n.toFixed(control.precision));
        return n;
    }

    function afterParser(raw) {
        if (typeof control.parser === "function")
            return String(control.parser(String(raw)));
        return String(raw);
    }

    // foundation.ts:817-830
    function isValidNumber(n) {
        if (!Number.isFinite(n))
            return false;
        if (control.precision >= 0 && control.precLen(n) > control.precision)
            return false;
        return n >= Number(control.min) && n <= Number(control.max);
    }

    // foundation.ts:674-683 fetchMinOrMax
    function fetchMinOrMax(n) {
        const lo = Number(control.min);
        const hi = Number(control.max);
        if (Number.isFinite(lo) && n < lo)
            return lo;
        if (Number.isFinite(hi) && n > hi)
            return hi;
        return n;
    }

    // ---- 显示格式化 ----
    // blurStyle 对应官方 doFormat 的第三个参数 needAdjustCurrency：只有失焦 / 初始化
    // 才走货币与科学计数法（foundation.ts:327 传 true、:522 传 _isCurrency()），
    // 输入过程中保持用户刚打出来的样子。
    function doFormat(value, adjustPrec, blurStyle) {
        if (value === undefined || value === null || value === "") {
            if (typeof control.formatter === "function")
                return String(control.formatter(""));
            return "";
        }
        let str;
        if (control.currencyActive && blurStyle)
            str = control.formatCurrency(Number(value));
        else if (adjustPrec && control.precision >= 0)
            str = Number(value).toFixed(control.precision);
        else
            str = String(value);
        if (blurStyle && control.scientificActive && !control.currencyActive)
            str = control.toScientific(Number(value));
        if (typeof control.formatter === "function")
            str = String(control.formatter(str));
        return str;
    }

    // 输入时保住刚打的小数点与尾随 0（foundation.ts:218-228）
    function preserveTypedTail(raw, shown) {
        if (raw.length === 0 || shown.indexOf("e") !== -1)
            return shown;
        const rawTail = raw.split(".")[1];
        if (raw.indexOf(".") === -1)
            return shown;
        if (shown.indexOf(".") === -1)
            return shown + "." + (rawTail === undefined ? "" : rawTail);
        const shownTail = shown.split(".")[1];
        if (rawTail !== undefined && rawTail.length > shownTail.length)
            return shown + rawTail.substring(shownTail.length);
        return shown;
    }

    // foundation.ts:596-630：有效数字达到阈值才转，toExponential(阈值-1) 后清尾随 0
    function thresholdValue() {
        const s = control.scientificNotation;
        // qmllint disable missing-property
        if (s !== null && typeof s === "object" && typeof s.threshold === "number"
                && Number.isFinite(s.threshold) && s.threshold >= 1)
            return s.threshold;
        // qmllint enable missing-property
        return 15;
    }

    function toScientific(num) {
        const absNum = Math.abs(num);
        const raw = String(num);
        const hasExp = /e/i.test(raw);
        const digits = String(absNum).replace(/[.\-+eE]/g, "").replace(/^0+/, "").length;
        const t = control.thresholdValue();
        if ((!hasExp && digits < t) || absNum === 0)
            return String(num);
        const frac = Math.max(0, Math.min(100, Math.floor(t) - 1));
        let out = num.toExponential(frac);
        out = out.replace(/(\.\d*?)0+e/, "$1e");
        out = out.replace(/\.e/, "e");
        return out;
    }

    // ---- 货币 ----
    // 具体数据 / 格式化在 InputNumberCurrency.js（QML 无 Intl，表是从 Node ICU 落盘的）
    readonly property string effectiveLocale: control.localeCode !== ""
        ? control.localeCode : "zh-CN"

    function formatCurrency(num) {
        return Money.format({
            "localeCode": control.effectiveLocale,
            "currency": control.currency,
            "currencyDisplay": control.currencyDisplay,
            "showCurrencySymbol": control.showCurrencySymbol,
            "value": num,
            "precision": control.precision
        });
    }

    function parseCurrencyString(s) {
        return Money.unformat(s, {
            "localeCode": control.effectiveLocale,
            "currency": control.currency
        });
    }

    // ---- 步进 ----
    // foundation.ts:484-530。越界规则照官方：剩余距离不足一个步长就不动（不是补半步）
    function add(stepArg, shift) {
        const propStep = shift ? control.shiftStep : control.step;
        const s = (stepArg === undefined || stepArg === null) ? Number(propStep) : Number(stepArg);
        const stepAbs = Math.abs(s);
        let cur = control.toNumber(inner.text, false);
        cur = (cur === undefined) ? 0 : cur;
        const scale = Math.pow(10, Math.max(control.precLen(control.min), control.precLen(control.max),
                                            control.precLen(cur), control.precLen(s)));
        const lo = Number(control.min);
        const hi = Number(control.max);
        if (s > 0) {
            if (Math.abs(control.accurateMinus(hi, cur)) >= stepAbs)
                cur = Math.round(cur * scale + s * scale) / scale;
        } else {
            if (Math.abs(control.accurateMinus(cur, lo)) >= stepAbs)
                cur = Math.round(cur * scale + s * scale) / scale;
        }
        if (Number.isFinite(lo) && lo > cur)
            cur = lo;
        if (Number.isFinite(hi) && hi < cur)
            cur = hi;
        return control.doFormat(cur, true, control.currencyActive);
    }

    function minus(stepArg, shift) {
        const propStep = shift ? control.shiftStep : control.step;
        const s = (stepArg === undefined || stepArg === null) ? -Number(propStep) : -Number(stepArg);
        return control.add(s, shift);
    }

    function stepBy(up, shift) {
        if (control.stepDisabled || (up ? control.notAllowedUp : control.notAllowedDown))
            return;
        // 官方步进前后会记下并还原光标（foundation.ts:265 + 268-270 的 recordCursor /
        // restoreCursor），重写显示串不能把光标甩到末尾
        const caret = control.field.cursorPosition;
        const before = control.field.text.length;
        const shown = up ? control.add(null, shift) : control.minus(null, shift);
        control.applyText(shown);
        control.field.cursorPosition = Math.max(0,
            Math.min(caret + shown.length - before, shown.length));
        const n = control.toNumber(shown, true);
        if (n !== undefined) {
            control.number = n;
            control.writeValue(n);
        }
        control.notifyChange(shown);
        if (up)
            control.upClick(shown);
        else
            control.downClick(shown);
        // keepFocus：官方每步之后把焦点抢回输入框（foundation.ts:96-100）
        if (control.keepFocus || control.innerButtons)
            control.field.forceActiveFocus();
    }

    function notifyChange(v) {
        if (v === undefined || v === null || v === "") {
            control.change("");
            return;
        }
        const n = control.toNumber(v, true);
        if (n !== undefined) {
            control.change(n);
            if (control.isValidNumber(n) && n !== control._lastNotifiedNumber) {
                control._lastNotifiedNumber = n;
                control.numberChange(n);
            }
        } else {
            control.change(control.afterParser(v));
        }
    }

    // ---- 输入 / 焦点 ----
    function writeValue(n) {
        control._writingValue = true;
        control.value = n;
        control._writingValue = false;
    }

    // 外部改 value（受控用法）时重算数字与显示
    function applyValue() {
        const raw = control.value;
        if (raw === undefined || raw === null || String(raw) === "") {
            control.number = undefined;
            control.applyText("");
            return;
        }
        const n = Number(raw);
        control.number = Number.isFinite(n) ? n : undefined;
        control.applyText(control.doFormat(control.number, true, true));
    }

    function applyText(s) {
        control._applying = true;
        inner.text = s;
        control._applying = false;
    }

    function handleInputTextChanged(raw) {
        if (control._applying)
            return;
        if (raw === "") {
            control.number = undefined;
            control.writeValue(undefined);
            control._lastNotifiedNumber = undefined;
            control.notifyChange("");
            return;
        }
        const n = control.toNumber(raw, false);
        if (n !== undefined && n >= Number(control.min) && n <= Number(control.max)) {
            control.number = n;
            control.writeValue(n);
            control.applyText(control.preserveTypedTail(raw, control.doFormat(n, false, false)));
            control.notifyChange(n);
        } else {
            // 越界 / 非法：输入过程中不改 number，显示只过 formatter / parser
            const shown = control.doFormat(raw, false, false);
            control.applyText(shown);
            control.notifyChange(shown);
        }
    }

    function handleFocusIn() {
        // 科学计数法只在失焦态显示，拿回焦点还原成完整数字（foundation.ts:166-179）
        const s = inner.text;
        if (control.scientificActive && !control.currencyActive
                && /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)[eE][+-]?\d+$/.test(s)) {
            const n = parseFloat(s);
            if (Number.isFinite(n))
                control.applyText(control.doFormat(n, true, false));
        }
        control.focused();
    }

    function handleFocusOut() {
        const current = control.number;
        const raw = inner.text;
        if (current !== undefined || raw !== "") {
            let parsed = control.toNumber(raw, true);
            let willSetNum;
            let willSetVal;
            let numChanged = false;
            let strChanged = false;
            if (parsed !== undefined && control.isValidNumber(parsed) && parsed !== current) {
                willSetNum = parsed;
                numChanged = true;
            }
            if (parsed === undefined || !control.isValidNumber(parsed)) {
                // issue #38：串里混了非数字字符时，能提出数字就钳位
                const extracted = Number.parseFloat(control.afterParser(raw));
                if (!Number.isNaN(extracted)) {
                    const limited = control.fetchMinOrMax(extracted);
                    if (limited !== current) {
                        willSetNum = limited;
                        numChanged = true;
                    }
                } else if (current !== undefined) {
                    const limited = control.fetchMinOrMax(current);
                    if (limited !== current) {
                        willSetNum = limited;
                        numChanged = true;
                    }
                }
            }
            const base = willSetNum !== undefined ? willSetNum : current;
            const formatted = control.doFormat(base, true, true);
            if (formatted !== raw) {
                willSetVal = formatted;
                strChanged = true;
            }
            if (numChanged) {
                control.number = willSetNum;
                control.writeValue(willSetNum);
            }
            if (strChanged)
                control.applyText(willSetVal);
            if (strChanged || numChanged)
                control.notifyChange(willSetVal !== undefined ? willSetVal : willSetNum);
        }
        control.blur();
    }

    // ---- 长按连发 ----
    function startRepeat(up, shift) {
        // 官方在非 keepFocus / 非 innerButtons 时不 preventDefault，点按钮会让输入框失焦
        // 从而立刻按 min/max 钳位（foundation.ts:421-427）。QML 这边清掉 forceActiveFocus()
        // 拿到的活跃焦点没有对应 API（见 blurField 的注释），实测点完按钮焦点仍在，
        // 钳位就推迟到真正离开输入框那一刻。
        control._pressDir = up ? 1 : -1;
        control._pressShift = shift;
        control.stepBy(up, shift);
        pressStartTimer.restart();
    }

    function stopRepeat() {
        pressStartTimer.stop();
        pressRepeatTimer.stop();
        control._pressDir = 0;
        // QQuickWindow 默认在 release 上改活跃焦点，keepFocus / innerButtons 要把焦点按回去
        if (control.keepFocus || control.innerButtons)
            control.field.forceActiveFocus();
    }

    // 官方 Methods: focus() / blur()（index.md 的 Methods 一节）。
    // blur 只能写成 focus = false —— 实测这样清不掉用 forceActiveFocus() 拿到的活跃焦点
    // （QML 没有清焦点的 API），所以点步进钮不会像官方那样「顺手失焦」。
    // 少掉的这一拍只影响「点按钮时立刻按 min/max 钳位」，真正离开输入框时仍会钳。
    function focusField() {
        control.field.forceActiveFocus();
    }

    function blurField() {
        control.field.focus = false;
    }

    // foundation.ts:260-276：只有 Up / Down 参与步进，其余按键保持 TextInput 默认行为。
    // 吞事件由 Input 的 arrowsAsKeys 负责，这里只做计算。
    function handleKeyPressed(key, modifiers) {
        if (key === Qt.Key_Up)
            control.stepBy(true, (modifiers & Qt.ShiftModifier) !== 0);
        else if (key === Qt.Key_Down)
            control.stepBy(false, (modifiers & Qt.ShiftModifier) !== 0);
    }

    Timer {
        id: pressStartTimer

        interval: control.pressTimeout
        onTriggered: pressRepeatTimer.restart()
    }

    Timer {
        id: pressRepeatTimer

        interval: control.pressInterval
        repeat: true
        onTriggered: control.stepBy(control._pressDir > 0, control._pressShift)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        Input {
            id: inner

            Layout.fillWidth: true
            Layout.fillHeight: true
            size: control.size
            enabled: control.enabled
            readOnly: control.readOnly
            placeholderText: control.placeholderText
            prefix: control.prefix
            suffix: control.innerShown ? innerStepperNode : control.suffix
            insetLabel: control.insetLabel
            showClear: control.showClear
            clearIcon: control.clearIcon
            borderless: control.borderless
            validateStatus: control.validateStatus
            radius: control.radius
            arrowsAsKeys: true
            onKeyPressed: (key, modifiers) => control.handleKeyPressed(key, modifiers)

            onTextChanged: control.handleInputTextChanged(text)
            onCleared: control.handleInputTextChanged("")
        }

        InputNumberStepper {
            id: outerStepper

            visible: !control.hideButtons && !control.innerButtons
            // inputNumber.scss:106-114：borderless 且未悬浮未聚焦时，外层步进器 opacity:0
            opacity: (control.borderless && !control.hovering && !control.focusing) ? 0 : 1
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: columnHeight
            columnHeight: control.controlHeight
            upAllowed: !control.notAllowedUp
            downAllowed: !control.notAllowedDown
            onStepUp: (shift) => control.startRepeat(true, shift)
            onStepDown: (shift) => control.startRepeat(false, shift)
            onReleased: control.stopRepeat()
        }
    }

    // innerButtons 时步进器挪进 Input 的 suffix 槽：高度减 2、左边距 8、圆角裁切
    // 这里要读组件自己的状态，所以不能开 ComponentBehavior: Bound
    // qmllint disable unqualified
    Component {
        id: innerStepperNode

        InputNumberStepper {
            id: innerStepper

            columnHeight: control.controlHeight - 2
            inner: true
            hoverBorder: control.hovering && !control.focusing
            upAllowed: !control.notAllowedUp
            downAllowed: !control.notAllowedDown
            onStepUp: (shift) => control.startRepeat(true, shift)
            onStepDown: (shift) => control.startRepeat(false, shift)
            onReleased: control.stopRepeat()
        }
    }
    // qmllint enable unqualified

    // Input 的 activeFocus 是别名，外面接不上 onXxxChanged，只能自己镜像一层
    Item {
        id: focusWatch

        visible: false
        width: 0
        height: 0
        property bool focused: inner.fieldActiveFocus

        onFocusedChanged: {
            if (focused)
                control.handleFocusIn();
            else
                control.handleFocusOut();
        }
    }

    HoverHandler {
        id: wrapHover

        enabled: control.enabled
    }

    TapHandler {
        enabled: control.enabled
        onTapped: control.focusField()
    }

    Component.onCompleted: {
        // 带 value 绑定创建时（ColorPicker 的百分比框就是这么用的）不能回写 value：
        // 一写就把外面那条绑定打断，之后颜色怎么变、这个数字都停在初值上。
        if (control.value !== undefined && control.value !== null && String(control.value) !== "") {
            const n = Number(control.value);
            if (Number.isFinite(n)) {
                control.number = n;
                control.applyText(control.doFormat(n, true, true));
            }
        } else if (control.defaultValue !== undefined && control.defaultValue !== null
                && String(control.defaultValue) !== "") {
            const n = Number(control.defaultValue);
            if (Number.isFinite(n)) {
                control.writeValue(n);
                control.number = n;
                control.applyText(control.doFormat(n, true, true));
            }
        } else {
            control.applyText(control.doFormat("", false, false));
        }
        if (control.autofocus)
            control.focusField();
    }
}
