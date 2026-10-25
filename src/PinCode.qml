pragma ComponentBehavior: Bound

import QtQuick

// 验证码输入。count 个单格输入框并排，输满一格自动跳到下一格。
//
//     PinCode { }                                   // 6 位纯数字
//     PinCode { size: "large"; defaultValue: "6688"; count: 4 }
//     PinCode { format: "mixed" }
//     PinCode { format: /[A-Z]/ }
//     PinCode { format: (char) => /[a-z]/.test(char) }
//
// 官方属性面见 semi-ui/pinCode/index.tsx:15-19 与
// semi-foundation/pincode/foundation.ts:4-13（PinCodeBaseProps），行为见
// foundation.ts，外观见 pincode.scss + variables.scss。
//
// 官方 DOM（pinCode/index.tsx:131-139）：
//   div.semi-pincode-wrapper        display:flex
//     Input × count                  .semi-input-wrapper-{size}，宽 24/32/42、
//                                    非末项 margin-right 6/8/12（末项 0），
//                                    里面的 input 清掉内边距并居中（pincode.scss:28-31）
//   每一格就是一个普通的 Input，所以底色 / 描边 / 悬浮 / 聚焦 / 禁用全部沿用 Input 的令牌，
//   本组件只负责「宽度、间距、居中、一格一字符、格子之间的焦点转移」。
Item {
    id: control

    // ---- 官方属性面（默认值 index.tsx:41-45）----
    // 受控值。官方是 `'value' in props`（foundation.ts:45），QML 分不出「没写」与
    // 「写了 undefined」，所以用 undefined 当「非受控」，与 Radio / Rating 同一口径。
    property var value: undefined
    property string defaultValue: ""
    property int count: 6
    // 单字符格式限制：'number' | 'mixed' | 正则 | (char) => boolean
    property var format: "number"
    // 'small' | 'default' | 'large'（官方 size 直接透传给 Input）
    property string size: "default"
    property bool disabled: false
    // 官方只给第 0 格传 autoFocus（index.tsx:105），默认 true
    property bool autoFocus: true

    // 官方 onChange(value) / onComplete(value)
    signal changed(string value)
    signal completed(string value)

    // ---- 内部状态（index.tsx:53-56 的 state.valueList）----
    // 每格一个字符；格子之间可以有空洞（官方就是稀疏数组，join 时空洞塌成空串）。
    property var _cells: []
    readonly property bool _controlled: control.value !== undefined
    readonly property bool _off: control.disabled || !control.enabled
    readonly property int _sizeEnum: control.size === "small" ? Enums.Small
        : (control.size === "large" ? Enums.Large : Enums.Default)

    // ---- 尺寸（variables.scss）----
    readonly property int cellWidth: control.size === "small" ? 24
        : (control.size === "large" ? 42 : 32)              // $width-pinCode_input_*
    readonly property int cellSpacing: control.size === "small" ? 6
        : (control.size === "large" ? 12 : 8)               // $spacing-pinCode_*-marginRight

    implicitWidth: control.count * control.cellWidth + (control.count - 1) * control.cellSpacing
    implicitHeight: Appearance.inputWrapperHeight(Theme.current, control._sizeEnum)

    Component.onCompleted: {
        control._cells = control.split(String(control._controlled ? control.value
                                                                : control.defaultValue));
        if (control.autoFocus && !control._off)
            control.focusCell(0);
    }

    // 官方 componentDidUpdate（index.tsx:59-64）：只有 props.value 变了才重刷 valueList，
    // defaultValue 之后改动不生效。
    onValueChanged: {
        if (control.value !== undefined) {
            control._cells = control.split(String(control.value));
            control.syncCells();
        }
    }

    function split(s) {
        return s === "" ? [] : s.split("");
    }

    function cellText(index) {
        const ch = control._cells[index];
        return ch === undefined ? "" : String(ch);
    }

    // Positioner 的 at() / itemAt() 只在 C++ 侧，QML 里只能从 children 里数。
    // 而 `Item.children` 是 **QObject 级**的子对象列表：挂在 Row 上的那只 `Repeater`
    // 自己也在里面（它不是 Item 也照样出现，位置还不固定），所以必须按 objectName 筛。
    function cellAt(index) {
        const kids = row.children
        let seen = 0
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].objectName !== "pinCodeCell")
                continue
            if (seen === index)
                return kids[i]
            ++seen
        }
        return null
    }

    // 用户敲过的格子，它自己的 text 绑定已经断了（TextInput 写 text 会顶掉声明式绑定），
    // 所以每次改完 _cells 都要命令式回写一遍 —— 等价于 React 受控 Input 重新渲染。
    function syncCells() {
        for (let i = 0; i < control.count; ++i) {
            const it = control.cellAt(i);
            if (it === null)
                continue;
            const want = control.cellText(i);
            if (it.text !== want)
                it.text = want;
        }
    }

    // validateValue（foundation.ts:64-79）。官方对「其它字符串」的 format 退化成全放行。
    function validateValue(ch) {
        if (typeof control.format === "string") {
            if (control.format === "number")
                return ch.length === 0 || /^\d*$/.test(ch);
            if (control.format === "mixed")
                return ch.length === 0 || /^[0-9a-zA-Z]$/.test(ch);
            return true;
        }
        if (control.format instanceof RegExp)
            return control.format.test(ch);
        if (typeof control.format === "function")
            return control.format(ch);
        return true;
    }

    // focus / blur（index.tsx:90-98）。官方挂在 ref 上叫 focus(index) / blur(index)；
    // QML 的 Item 已经有 focus 属性，名字让给它，这里叫 focusCell / blurCell。
    function focusCell(index) {
        const it = control.cellAt(index);
        if (it === null)
            return;
        it.input.forceActiveFocus();
        it.input.cursorPosition = 1;                        // 官方 setSelectionRange(1, 1)
    }

    function blurCell(index) {
        const it = control.cellAt(index);
        if (it === null)
            return;
        // Qt 的 activeFocus 是只读的，没有「只让这一项失焦」的 API，所以把焦点接到容器自己
        // 身上 —— 官方输完最后一格是 blur 那一格（foundation.ts:56）。
        // forceActiveFocus() 自带 setFocus(true)，再往外面找焦点域，所以只用它。
        control.forceActiveFocus();
    }

    // completeSingleInput（foundation.ts:44-62）
    function completeSingleInput(i, ch) {
        const list = control._cells.slice(0);
        list[i] = ch;
        control.changed(list.join(""));                     // notifyValueChange
        if (!control._controlled)
            control._cells = list;                          // 受控时不写自己的状态
        const joined = list.join("");
        if (i + 1 > control.count - 1) {
            control.blurCell(i);
            control.completed(joined);
        } else {
            control.focusCell(i + 1);
        }
        control.syncCells();
    }

    // 一格里的文本变了。官方是 Input 的 onChange：只取最后一个字符（index.tsx:123），
    // 因为一格只该有一个字符 —— 格子里本来有字符、又敲一个键，文本会临时变成「旧 + 新」，
    // 官方取最后一个，也就是后写的覆盖前面的。
    //
    // 粘贴对不上这条规则：官方有 onPaste（foundation.ts:85-100）可以 preventDefault 后自己
    // 一格一格灌。Qt 侧没有可用的 paste 信号 —— QQuickTextInput::event() 在 ShortcutOverride
    // 里把 QKeySequence::Paste 自己收下（qquicktextinput.cpp:1706-1732），外层 Shortcut 抢不到，
    // 粘贴只会把整串插进这一格。所以只能从「一次插进来几个字符」把粘贴认出来。
    function handleCellEdited(index, text) {
        // syncCells 自己写回去的那次也会发 textChanged，用「和模型一致」把它挡掉，
        // 否则一次输入会发两遍 changed。
        const old = control.cellText(index);
        if (text === old)
            return;
        if (text.length - old.length <= 1) {
            const ch = text.charAt(text.length - 1);
            if (control.validateValue(ch))
                control.completeSingleInput(index, ch);
            else
                control.syncCells();                        // 非法字符刷回去（等价受控重渲染）
            return;
        }
        // 一次插进多于一个字符 = 粘贴。粘贴是在光标处插入，格子里原有的字符不会被替换掉、
        // 还留在文本开头（focusCell 把光标停在末尾），摘掉它剩下的才是剪贴板内容。
        control.distribute(index, old === "" ? text : text.substring(old.length));
    }

    // handlePaste（foundation.ts:85-100）：从这一格往后依次灌，遇到第一个不合法的字符就停。
    function distribute(index, pasted) {
        let charIndex = 0;
        for (let i = index; i < control.count && charIndex < pasted.length; ++i, ++charIndex) {
            const ch = pasted.charAt(charIndex);
            if (control.validateValue(ch))
                control.completeSingleInput(i, ch);
            else
                break;
        }
    }

    // handleKeyDownOnSingleInput（foundation.ts:102-124）。注意官方的退格 / 删除分支
    // 不判受控，直接写 state —— 这里照抄。
    function handleKey(index, key) {
        // 稀疏无所谓：join 会把空洞塌成空串，和官方 valueList 的行为一致。
        const list = control._cells.slice(0);
        if (key === Qt.Key_Backspace) {
            list[index] = "";
            control._cells = list;
            control.changed(list.join(""));
            control.syncCells();
            control.focusCell(Math.max(0, index - 1));
        } else if (key === Qt.Key_Delete) {
            list[index] = "";
            control._cells = list;
            control.changed(list.join(""));
            control.syncCells();
            control.focusCell(Math.min(control.count - 1, index + 1));
        } else if (key === Qt.Key_Left) {
            control.focusCell(Math.max(0, index - 1));
        } else if (key === Qt.Key_Right) {
            control.focusCell(Math.min(control.count - 1, index + 1));
        }
    }

    Row {
        id: row

        spacing: control.cellSpacing

        Repeater {
            model: control.count

            delegate: Input {
                id: cell

                required property int index

                objectName: "pinCodeCell"

                // 官方把整只 Input 的宽度定死成一格，内边距清 0、文字居中
                width: control.cellWidth
                text: control.cellText(cell.index)
                size: control._sizeEnum
                paddingH: 0
                textAlign: TextInput.AlignHCenter
                enabled: !control._off
                // 官方 inputMode={format === 'number' ? 'numeric' : 'text'}（index.tsx:106）
                inputMethodHints: control.format === "number" ? Qt.ImhDigitsOnly : Qt.ImhNone

                onTextChanged: control.handleCellEdited(cell.index, cell.text)

                // 格子之间移动焦点。挂在 Input 的 keyPressed（它转发自内层 TextInput 自己的
                // Keys 处理）上，而不是外层 Item 的 Keys —— 退格 / 左右方向键会被
                // TextInput 吃掉并停止向上冒泡，挂在 Input 上收不到。
                onKeyPressed: (key, modifiers) => {
                    if (key === Qt.Key_Backspace || key === Qt.Key_Delete
                        || key === Qt.Key_Left || key === Qt.Key_Right)
                        control.handleKey(cell.index, key);
                }
            }
        }
    }
}
