import QtQuick
import QtTest
import Semi

// PinCode 对齐官方属性面后的回归测试。
//
// 规格来源：semi-ui/pinCode/index.tsx（属性面、受控语义、每格取「最后一个字符」）、
// semi-foundation/pincode/foundation.ts（completeSingleInput / validateValue /
// handlePaste / handleKeyDownOnSingleInput 四个算法）、
// semi-foundation/pincode/pincode.scss + variables.scss（24/32/42 的格子、
// 6/8/12 的间距、padding 清 0、文字居中）。
//
// 断言尽量落在渲染出来的格子上（那一只 Input 的宽、x、里面的 TextInput 的对齐与焦点），
// 而不是 control._cells 这类中间状态。
TestCase {
    id: testCase

    name: "PinCode"
    when: windowShown
    width: 900
    height: 900

    property var changes: []
    property var completes: []
    property string ctrlValue: "000000"
    property string fnSeen: ""

    function init() {
        // 见 PROGRESS.md 坑 4 / 坑 70
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
        changes = []
        completes = []
        ctrlValue = "000000"
        // 合成指针停在上一条用例的位置，新建的探针就会一上来是悬浮态
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(20)
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    // 每只 PinCode 探针都自动记 changed / completed；不关心信号的用例只看 shown()，多记无害。
    function pin(qml) {
        const p = make(qml)
        p.changed.connect(function (v) { testCase.changes.push(v) })
        p.completed.connect(function (v) { testCase.completes.push(v) })
        return p
    }

    function walk(root, name, out) {
        out = out === undefined ? [] : out
        const kids = root.children
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].objectName === name)
                out.push(kids[i])
            walk(kids[i], name, out)
        }
        return out
    }

    // 渲染出来的那些格子（一只格子就是一个 Input）
    function cells(p) {
        const list = walk(p, "pinCodeCell")
        compare(list.length, p.count, "格子数量和 count 对不上")
        return list
    }

    // 每格文本拼起来，方便一次看全「屏幕上到底显示了什么」
    function shown(p) {
        return cells(p).map(c => c.text).join("|")
    }

    function activeIndex(p) {
        const list = cells(p)
        for (let i = 0; i < list.length; ++i)
            if (list[i].input.activeFocus)
                return i
        return -1
    }

    // 走控件自己的 focusCell —— 真实输入时焦点就是这么落到格子上的（它还会把光标停在末尾）
    function focusAt(p, i) {
        p.focusCell(i)
        wait(20)
        compare(activeIndex(p), i, "第 " + i + " 格没拿到焦点")
    }

    // 往第 i 格里「插入」一段文本。粘贴和按键在 Qt 侧都是在光标处插入，不碰光标两边的
    // 原有内容 —— 直接赋值会把整格替换掉，那就不是在模拟粘贴了。
    function typeInto(p, i, text) {
        const field = cells(p)[i].input
        const at = Math.max(0, Math.min(field.cursorPosition, field.text.length))
        field.text = field.text.substring(0, at) + text + field.text.substring(at)
        wait(30)
    }

    // ---------------- 尺寸与几何（variables.scss + 官方 DOM 实测） ----------------

    function test_smallCellIs24With6Gap() {
        const p = pin('PinCode { size: "small" }')
        compare(p.cellWidth, 24)                    // $width-pinCode_input_small
        compare(p.cellSpacing, 6)                   // $spacing-pinCode_small-marginRight
        compare(p.implicitHeight, 24)               // Input 的 small 档高度
        compare(p.implicitWidth, 6 * 24 + 5 * 6)    // 174
        const cs = cells(p)
        for (let i = 0; i < 6; ++i) {
            compare(cs[i].width, 24)
            compare(cs[i].mapToItem(p, 0, 0).x, i * 30)
        }
        p.destroy()
    }

    function test_defaultCellIs32With8Gap() {
        const p = pin("PinCode { }")
        compare(p.cellWidth, 32)
        compare(p.cellSpacing, 8)
        compare(p.implicitHeight, 32)
        compare(p.implicitWidth, 6 * 32 + 5 * 8)    // 232
        const cs = cells(p)
        for (let i = 0; i < 6; ++i)
            compare(cs[i].mapToItem(p, 0, 0).x, i * 40)
        p.destroy()
    }

    function test_largeCellIs42WideBut40Tall() {
        // 官方 large 的格子不是正方形：宽 42、高走 Input 的 large 档 40。
        // 早先手画的实现把它当成 42×42，这一条就是钉住这个差别的。
        const p = pin('PinCode { size: "large" }')
        compare(p.cellWidth, 42)
        compare(p.cellSpacing, 12)
        compare(p.implicitHeight, 40)
        compare(p.implicitWidth, 6 * 42 + 5 * 12)   // 312
        const cs = cells(p)
        for (let i = 0; i < 6; ++i) {
            compare(cs[i].width, 42)
            compare(cs[i].mapToItem(p, 0, 0).x, i * 54)
        }
        p.destroy()
    }

    function test_rowStartsAtWrapperOrigin() {
        // .semi-pincode-wrapper 就是 display:flex，没有内边距
        const p = pin('PinCode { size: "large" }')
        compare(cells(p)[0].mapToItem(p, 0, 0).x, 0)
        compare(cells(p)[0].y, 0)
        p.destroy()
    }

    function test_cellTextIsCenteredWithZeroPadding() {
        // pincode.scss:28-31 把格子里那只 input 的 padding 清 0、text-align 设 center
        const p = pin("PinCode { }")
        const cs = cells(p)
        compare(cs[0].input.horizontalAlignment, TextInput.AlignHCenter)
        compare(cs[0].input.mapToItem(cs[0], 0, 0).x, 0)
        compare(cs[0].input.width, cs[0].width)
        p.destroy()
    }

    function test_paddingHookStillWorksForPlainInput() {
        // 上面那条依赖 Input 的 paddingH / textAlign 是可覆盖的；
        // 普通 Input 必须仍然吃主题的内边距、左对齐。
        const i = make("Input { }")
        verify(i.input.mapToItem(i, 0, 0).x > 0)
        compare(i.input.horizontalAlignment, TextInput.AlignLeft)
        i.destroy()
    }

    function test_sizePassesThroughToEveryCell() {
        const p = pin('PinCode { size: "small" }')
        compare(cells(p)[0].size, Enums.Small)
        p.size = "large"
        compare(cells(p)[0].size, Enums.Large)
        compare(cells(p)[0].height, 40)
        p.destroy()
    }

    function test_numberFormatUsesNumericInputMode() {
        // 官方 inputMode={format === 'number' ? 'numeric' : 'text'}（index.tsx:106）
        const p = pin("PinCode { }")
        compare(cells(p)[0].inputMethodHints, Qt.ImhDigitsOnly)
        p.format = "mixed"
        compare(cells(p)[0].inputMethodHints, Qt.ImhNone)
        p.format = /[a-z]/
        compare(cells(p)[0].inputMethodHints, Qt.ImhNone)
        p.destroy()
    }

    function test_disabledStateReachesEveryCell() {
        const p = pin("PinCode { disabled: true; autoFocus: false }")
        const cs = cells(p)
        for (let i = 0; i < cs.length; ++i)
            verify(!cs[i].enabled, "第 " + i + " 格没被禁用")
        p.destroy()
    }

    function test_outerDisabledBlocksAutoFocus() {
        // 整个控件被外面关掉时，autoFocus 不该去抢焦点
        const other = make("Input { }")
        other.input.forceActiveFocus()
        wait(20)
        const p = pin("PinCode { enabled: false }")
        wait(40)
        compare(activeIndex(p), -1)
        verify(other.input.activeFocus)
        p.destroy()
        other.destroy()
    }

    // ---------------- 位数 ----------------

    function test_countDecidesCellNumber() {
        const p = pin("PinCode { count: 4 }")
        compare(cells(p).length, 4)
        compare(p.implicitWidth, 4 * 32 + 3 * 8)
        p.count = 8
        compare(cells(p).length, 8)
        compare(p.implicitWidth, 8 * 32 + 7 * 8)
        p.destroy()
    }

    function test_defaultCountIsSix() {
        const p = pin("PinCode { }")
        compare(p.count, 6)
        compare(cells(p).length, 6)
        p.destroy()
    }

    // ---------------- 初始值 ----------------

    function test_defaultValueFillsLeadingCells() {
        const p = pin('PinCode { defaultValue: "123456" }')
        compare(shown(p), "1|2|3|4|5|6")
        p.destroy()
    }

    function test_shortDefaultLeavesTrailingCellsEmpty() {
        const p = pin('PinCode { defaultValue: "12"; autoFocus: false }')
        compare(shown(p), "1|2||||")
        p.destroy()
    }

    function test_longerValueThanCountOnlyRendersTheFirstCells() {
        // 官方 valueList 可以比 count 长，只渲染前 count 只 input（index.tsx:132-135）
        const p = pin('PinCode { count: 4; value: "123456" }')
        compare(shown(p), "1|2|3|4")
        p.destroy()
    }

    function test_valueChangeRewritesEveryCell() {
        const p = pin('PinCode { value: testCase.ctrlValue }')
        compare(shown(p), "0|0|0|0|0|0")
        testCase.ctrlValue = "abcdef"
        compare(shown(p), "a|b|c|d|e|f")
        testCase.ctrlValue = "9"
        compare(shown(p), "9|||||")
        p.destroy()
    }

    function test_defaultValueIsOnlyReadOnce() {
        // 官方 componentDidUpdate 只看 props.value（index.tsx:59-64），
        // 之后再改 defaultValue 不生效。
        const p = pin('PinCode { defaultValue: "11"; autoFocus: false }')
        compare(shown(p), "1|1||||")
        p.defaultValue = "222222"
        compare(shown(p), "1|1||||")
        p.destroy()
    }

    function test_emptyValueRendersEmptyCells() {
        const p = pin('PinCode { value: "" }')
        compare(shown(p), "|||||")
        p.destroy()
    }

    // ---------------- 敲键盘 ----------------

    function test_typingFillsCellsInOrder() {
        const p = pin("PinCode { }")
        focusAt(p, 0)
        keyClick(Qt.Key_1)
        compare(shown(p), "1|||||")
        compare(activeIndex(p), 1)
        keyClick(Qt.Key_2)
        compare(shown(p), "1|2||||")
        compare(activeIndex(p), 2)
        compare(changes.length, 2)
        compare(changes[0], "1")
        compare(changes[1], "12")
        p.destroy()
    }

    function test_oneKeystrokeFiresExactlyOneChanged() {
        // syncCells 自己写 text 也会发 textChanged，挡不住的话一次按键两报
        const p = pin("PinCode { }")
        focusAt(p, 0)
        keyClick(Qt.Key_7)
        compare(changes.length, 1)
        compare(changes[0], "7")
        p.destroy()
    }

    function test_typingOverExistingCharReplacesIt() {
        // 官方取 DOM 值的最后一个字符：格子里原有的字符被后敲的覆盖，且不往后挪
        const p = pin('PinCode { defaultValue: "123456"; autoFocus: false }')
        focusAt(p, 1)
        keyClick(Qt.Key_9)
        compare(shown(p), "1|9|3|4|5|6")
        compare(changes.length, 1)
        compare(changes[0], "193456")
        compare(activeIndex(p), 2)
        p.destroy()
    }

    function test_invalidCharIsRejectedSilently() {
        const p = pin("PinCode { }")
        focusAt(p, 0)
        keyClick(Qt.Key_A)
        wait(30)
        compare(shown(p), "|||||")
        compare(changes.length, 0)
        compare(completes.length, 0)
        compare(activeIndex(p), 0)
        p.destroy()
    }

    function test_lastCellCompletesAndBlurs() {
        const p = pin('PinCode { count: 4; defaultValue: "123"; autoFocus: false }')
        focusAt(p, 3)
        keyClick(Qt.Key_9)
        compare(shown(p), "1|2|3|9")
        compare(changes.length, 1)
        compare(changes[0], "1239")
        compare(completes.length, 1)
        compare(completes[0], "1239")
        compare(activeIndex(p), -1)
        p.destroy()
    }

    function test_completedDoesNotFireEarly() {
        // 倒数第二格还不算完：官方是 i + 1 > count - 1（foundation.ts:55）
        const p = pin("PinCode { }")
        focusAt(p, 0)
        keyClick(Qt.Key_1)
        keyClick(Qt.Key_2)
        keyClick(Qt.Key_3)
        keyClick(Qt.Key_4)
        keyClick(Qt.Key_5)
        compare(shown(p), "1|2|3|4|5|")
        compare(completes.length, 0)
        p.destroy()
    }

    function test_countOneCompletesOnFirstKeystroke() {
        const p = pin("PinCode { count: 1 }")
        focusAt(p, 0)
        keyClick(Qt.Key_5)
        compare(shown(p), "5")
        compare(completes.length, 1)
        compare(completes[0], "5")
        p.destroy()
    }

    function test_holesCollapseInTheNotifiedValue() {
        // 官方 valueList 是稀疏数组，join 时空洞塌成空串：
        // ['1', <hole>, <hole>, '5'].join("") === "15"
        const p = pin('PinCode { defaultValue: "1"; autoFocus: false }')
        p.focusCell(3)
        wait(20)
        keyClick(Qt.Key_5)
        compare(shown(p), "1|||5||")
        compare(changes.length, 1)
        compare(changes[0], "15")
        p.destroy()
    }

    function test_clickFocusesTheClickedCell() {
        // 真指针路径：点第 3 格，敲的字符就落在第 3 格
        const p = pin("PinCode { autoFocus: false }")
        compare(activeIndex(p), -1)
        const cs = cells(p)
        mouseClick(cs[3], cs[3].width - 3, cs[3].height / 2)
        wait(30)
        compare(activeIndex(p), 3)
        keyClick(Qt.Key_6)
        compare(shown(p), "|||6||")
        compare(changes[0], "6")
        p.destroy()
    }

    // ---------------- 退格 / 删除 / 方向键 ----------------

    function test_backspaceClearsAndStepsLeft() {
        const p = pin('PinCode { defaultValue: "123"; autoFocus: false }')
        focusAt(p, 2)
        keyClick(Qt.Key_Backspace)
        compare(shown(p), "1|2||||")
        compare(changes.length, 1)
        compare(changes[0], "12")
        compare(activeIndex(p), 1)
        p.destroy()
    }

    function test_backspaceAtFirstCellStaysAtZero() {
        // 官方 Math.max(0, index - 1)
        const p = pin('PinCode { defaultValue: "1" }')
        focusAt(p, 0)
        keyClick(Qt.Key_Backspace)
        compare(shown(p), "|||||")
        compare(changes.length, 1)
        compare(changes[0], "")
        compare(activeIndex(p), 0)
        p.destroy()
    }

    function test_deleteClearsAndStepsRight() {
        const p = pin('PinCode { defaultValue: "123"; autoFocus: false }')
        focusAt(p, 1)
        keyClick(Qt.Key_Delete)
        compare(shown(p), "1||3|||")
        compare(changes.length, 1)
        compare(changes[0], "13")
        compare(activeIndex(p), 2)
        p.destroy()
    }

    function test_deleteAtLastCellStaysPut() {
        // 官方 Math.min(valueList.length - 1, index + 1)
        const p = pin('PinCode { count: 4; defaultValue: "1234"; autoFocus: false }')
        focusAt(p, 3)
        keyClick(Qt.Key_Delete)
        compare(shown(p), "1|2|3|")
        compare(changes[0], "123")
        compare(activeIndex(p), 3)
        p.destroy()
    }

    function test_arrowKeysOnlyMoveFocus() {
        const p = pin('PinCode { defaultValue: "12"; autoFocus: false }')
        focusAt(p, 1)
        keyClick(Qt.Key_Right)
        compare(activeIndex(p), 2)
        keyClick(Qt.Key_Left)
        keyClick(Qt.Key_Left)
        compare(activeIndex(p), 0)
        compare(changes.length, 0)
        compare(shown(p), "1|2||||")
        p.destroy()
    }

    function test_arrowsClampAtBothEnds() {
        const p = pin("PinCode { }")
        focusAt(p, 0)
        keyClick(Qt.Key_Left)
        compare(activeIndex(p), 0)
        focusAt(p, 5)
        keyClick(Qt.Key_Right)
        compare(activeIndex(p), 5)
        keyClick(Qt.Key_Right)
        compare(activeIndex(p), 5)
        p.destroy()
    }

    function test_controlledBackspaceStillClearsTheCell() {
        // 官方 handleKeyDownOnSingleInput 的退格分支不判受控，直接写 state
        // （foundation.ts:104-110）—— 受控时退格照样改画面，这是上游的行为，照抄。
        const p = pin('PinCode { value: "123456"; autoFocus: false }')
        focusAt(p, 2)
        keyClick(Qt.Key_Backspace)
        compare(shown(p), "1|2||4|5|6")
        compare(changes.length, 1)
        compare(changes[0], "12456")
        p.destroy()
    }

    // ---------------- 粘贴 ----------------

    function test_pasteFillsFromTheFocusedCell() {
        const p = pin("PinCode { }")
        focusAt(p, 0)
        typeInto(p, 0, "123456")
        compare(shown(p), "1|2|3|4|5|6")
        compare(changes.length, 6)
        compare(changes[5], "123456")
        compare(completes.length, 1)
        compare(completes[0], "123456")
        compare(activeIndex(p), -1)
        p.destroy()
    }

    function test_pasteStopsAtTheFirstInvalidChar() {
        // 官方 handlePaste 遇到第一个不合法的字符就 break（foundation.ts:89-99）
        const p = pin("PinCode { }")
        focusAt(p, 0)
        typeInto(p, 0, "12ab34")
        compare(shown(p), "1|2||||")
        compare(changes.length, 2)
        compare(changes[1], "12")
        compare(completes.length, 0)
        p.destroy()
    }

    function test_pasteIntoAMiddleCell() {
        const p = pin('PinCode { defaultValue: "12"; autoFocus: false }')
        focusAt(p, 2)
        typeInto(p, 2, "3456")
        compare(shown(p), "1|2|3|4|5|6")
        compare(changes.length, 4)
        compare(changes[0], "123")
        compare(changes[3], "123456")
        p.destroy()
    }

    function test_pasteDoesNotOverflowTheLastCell() {
        // 循环上界是 count：剪贴板比剩余格子长，多出来的丢掉
        const p = pin('PinCode { count: 4; defaultValue: "12"; autoFocus: false }')
        focusAt(p, 2)
        typeInto(p, 2, "345678")
        compare(shown(p), "1|2|3|4")
        compare(completes.length, 1)
        compare(completes[0], "1234")
        p.destroy()
    }

    function test_pasteOfOneCharBehavesLikeTyping() {
        // 剪贴板只有一个字符时，官方 handlePaste 与 onChange 的结果一致：覆盖当前格
        const p = pin('PinCode { defaultValue: "1"; autoFocus: false }')
        focusAt(p, 0)
        typeInto(p, 0, "9")
        compare(shown(p), "9|||||")
        compare(changes.length, 1)
        compare(changes[0], "9")
        p.destroy()
    }

    function test_pasteOverExistingCharStartsAtThatCell() {
        // 粘贴是插入，格子里原有的 'x' 会留在文本开头；官方 handlePaste 从这一格开始灌
        // 剪贴板 "ab"，所以结果是 a、b，而不是 x、a、b。
        const p = pin('PinCode { format: "mixed"; defaultValue: "x"; autoFocus: false }')
        focusAt(p, 0)
        typeInto(p, 0, "ab")
        compare(shown(p), "a|b||||")
        compare(changes.length, 2)
        compare(changes[1], "ab")
        p.destroy()
    }

    function test_realClipboardPasteThroughKeys() {
        const src = make('TextInput { text: "314159"; width: 80; height: 24 }')
        wait(40)
        src.selectAll()
        src.copy()
        wait(40)
        // 先确认这台机器的剪贴板真的能用，否则是环境问题而不是组件问题
        const probe = make("TextInput { width: 80; height: 24 }")
        wait(40)
        probe.forceActiveFocus()
        wait(20)
        keyClick(Qt.Key_V, Qt.ControlModifier)
        wait(40)
        const pasted = probe.text
        probe.destroy()
        src.destroy()
        if (pasted !== "314159") {
            skip("本机没有可用的剪贴板，粘贴用例跳过（探针读到 \"" + pasted + "\"）")
            return
        }

        const p = pin("PinCode { }")
        wait(40)
        compare(activeIndex(p), 0)
        keyClick(Qt.Key_V, Qt.ControlModifier)
        wait(60)
        compare(shown(p), "3|1|4|1|5|9")
        compare(changes.length, 6)
        compare(completes.length, 1)
        compare(completes[0], "314159")
        p.destroy()
    }

    // ---------------- 受控 ----------------

    function test_controlledTypingNotifiesButDoesNotStick() {
        // 官方受控时不写 state（foundation.ts:49-52），DOM 上那一格会被下一次渲染刷回 value
        const p = pin('PinCode { value: "000000"; autoFocus: false }')
        focusAt(p, 0)
        keyClick(Qt.Key_7)
        compare(changes.length, 1)
        compare(changes[0], "700000")
        compare(shown(p), "0|0|0|0|0|0")
        compare(activeIndex(p), 1)
        p.destroy()
    }

    function test_controlledPasteNotifiesEachStep() {
        // 受控时 completeSingleInput 不写 state，所以每一步的通知都是
        // 「旧 value + 只有这一格换了」，而不是越粘越长。
        const p = pin('PinCode { value: "000000"; autoFocus: false }')
        focusAt(p, 0)
        typeInto(p, 0, "123456")
        compare(shown(p), "0|0|0|0|0|0")
        compare(changes.length, 6)
        compare(changes[0], "100000")
        compare(changes[1], "020000")
        compare(changes[5], "000006")
        compare(completes.length, 1)
        compare(completes[0], "000006")
        p.destroy()
    }

    function test_controlledValueChangeAfterTypingRestoresDisplay() {
        const p = pin('PinCode { value: testCase.ctrlValue; autoFocus: false }')
        focusAt(p, 0)
        keyClick(Qt.Key_7)
        compare(shown(p), "0|0|0|0|0|0")
        testCase.ctrlValue = "777777"
        compare(shown(p), "7|7|7|7|7|7")
        p.destroy()
    }

    function test_uncontrolledKeepsWhatWasTyped() {
        const p = pin("PinCode { }")
        focusAt(p, 0)
        keyClick(Qt.Key_1)
        keyClick(Qt.Key_2)
        compare(shown(p), "1|2||||")
        // 只看屏幕上的字不够 —— 那一格是 TextInput 自己留着的。模型没接住的话，
        // 下一次改动会把空洞刷回来，所以再断一次通知的整串与「写断绑定后仍能刷回」。
        compare(changes[1], "12")
        typeInto(p, 0, "9")
        compare(shown(p), "9|2||||")
        focusAt(p, 3)
        keyClick(Qt.Key_7)
        compare(shown(p), "9|2||7||")
        p.destroy()
    }

    function test_syncCoversTheLastCell() {
        // 最后一格的绑定被 JS 写断之后，只有逐格回写刷得动它。
        // （退格不行 —— TextInput 自己也会删一次，正好把漏刷掩盖掉，所以这里换 value。）
        const p = pin('PinCode { value: testCase.ctrlValue; autoFocus: false }')
        focusAt(p, 5)
        typeInto(p, 5, "7")                 // 受控：模型不动，回写把它刷成 "0"，绑定已断
        compare(shown(p), "0|0|0|0|0|0")
        testCase.ctrlValue = "123459"
        compare(shown(p), "1|2|3|4|5|9")    // 少刷最后一格，这里就是 ...|0
        p.destroy()
    }

    function test_controlledValueRewritesCellsWhoseBindingIsGone() {
        const p = pin('PinCode { value: testCase.ctrlValue; autoFocus: false }')
        focusAt(p, 0)
        typeInto(p, 0, "7")                 // 受控：写断绑定，值又被刷回 "0"
        compare(shown(p), "0|0|0|0|0|0")
        testCase.ctrlValue = "123456"
        compare(shown(p), "1|2|3|4|5|6")    // 第 0 格只能靠回写刷出来
        p.destroy()
    }

    // ---------------- format ----------------

    function test_validateValueMatrix() {
        // validateValue（foundation.ts:64-79）
        const num = pin('PinCode { format: "number" }')
        verify(num.validateValue("7"))
        verify(!num.validateValue("a"))
        verify(!num.validateValue("-"))
        verify(num.validateValue(""))
        num.destroy()

        const mixed = pin('PinCode { format: "mixed" }')
        verify(mixed.validateValue("7"))
        verify(mixed.validateValue("a"))
        verify(mixed.validateValue("Z"))
        verify(!mixed.validateValue("-"))
        verify(!mixed.validateValue(" "))
        verify(mixed.validateValue(""))
        mixed.destroy()

        const re = pin('PinCode { format: /[A-Z]/ }')
        verify(re.validateValue("Q"))
        verify(!re.validateValue("q"))
        verify(!re.validateValue("1"))
        re.destroy()

        const fn = pin('PinCode { format: (ch) => { testCase.fnSeen = ch; return /[a-z]/.test(ch) } }')
        verify(fn.validateValue("q"))
        verify(!fn.validateValue("Q"))
        compare(testCase.fnSeen, "Q")
        fn.destroy()
    }

    function test_formatFunctionIsCalledPerCharAndDrivesTyping() {
        // 官方文档：「以字符为单位被依次作为参数分别单独传入进行校验」
        testCase.fnSeen = ""
        const p = pin('PinCode { format: (ch) => /[a-z]/.test(ch) }')
        focusAt(p, 0)
        keyClick(Qt.Key_A)
        wait(30)
        compare(p.cellText(0), "a")
        keyClick(Qt.Key_1)
        wait(30)
        compare(p.cellText(1), "")
        p.destroy()
    }

    function test_unknownFormatStringAllowsEverything() {
        // 官方 format 传字符串但不是 number / mixed 时，校验函数退化成全放行
        const p = pin('PinCode { format: "letters" }')
        focusAt(p, 0)
        keyClick(Qt.Key_A)
        wait(30)
        compare(shown(p), "a|||||")
        p.destroy()
    }

    // ---------------- focus / blur 方法 ----------------

    function test_focusCellMovesActiveFocusAndCaret() {
        // 官方 ref.focus(index)：focus() + setSelectionRange(1, 1)
        const p = pin('PinCode { defaultValue: "123456"; autoFocus: false }')
        compare(activeIndex(p), -1)
        p.focusCell(2)
        wait(20)
        compare(activeIndex(p), 2)
        compare(cells(p)[2].input.cursorPosition, 1)
        p.destroy()
    }

    function test_focusCellOutOfRangeIsHarmless() {
        // 官方 focus / blur 走 inputDOM?.focus() 的可选链，序号越界不炸（index.tsx:90-98）
        const p = pin("PinCode { autoFocus: false }")
        p.focusCell(99)
        p.blurCell(99)
        wait(20)
        compare(activeIndex(p), -1)
        p.destroy()
    }

    function test_blurCellDropsFocusFromAllCells() {
        const p = pin('PinCode { autoFocus: true }')
        compare(activeIndex(p), 0)
        p.blurCell(0)
        wait(20)
        compare(activeIndex(p), -1)
        p.destroy()
    }

    function test_autoFocusSelectsFirstCell() {
        const p = pin("PinCode { }")
        wait(40)
        compare(activeIndex(p), 0)
        p.destroy()
    }

    function test_autoFocusFalseLeavesFocusAlone() {
        const other = make("Input { }")
        other.input.forceActiveFocus()
        wait(20)
        const p = pin("PinCode { autoFocus: false }")
        wait(40)
        compare(activeIndex(p), -1)
        verify(other.input.activeFocus)
        p.destroy()
        other.destroy()
    }

    function test_autoFocusSkippedWhenDisabled() {
        const other = make("Input { }")
        other.input.forceActiveFocus()
        wait(20)
        const p = pin("PinCode { disabled: true }")
        wait(40)
        compare(activeIndex(p), -1)
        verify(other.input.activeFocus)
        p.destroy()
        other.destroy()
    }

    // ---------------- 不产生噪音 ----------------

    function test_noSignalsDuringConstruction() {
        const p = pin('PinCode { defaultValue: "12" }')
        wait(40)
        compare(changes.length, 0)
        compare(completes.length, 0)
        p.destroy()
    }

    function test_settingValueProgrammaticallyDoesNotNotify() {
        // 官方 componentDidUpdate 只刷 state，不 onChange
        const p = pin('PinCode { value: "111111"; autoFocus: false }')
        wait(40)
        compare(changes.length, 0)
        p.value = "222222"
        compare(shown(p), "2|2|2|2|2|2")
        compare(changes.length, 0)
        p.destroy()
    }

    function test_countChangeRebuildsWithoutNotifying() {
        const p = pin('PinCode { defaultValue: "123456"; autoFocus: false }')
        wait(40)
        p.count = 3
        compare(cells(p).length, 3)
        compare(shown(p), "1|2|3")
        compare(changes.length, 0)
        p.destroy()
    }
}
