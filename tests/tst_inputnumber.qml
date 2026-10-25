import QtQuick
import QtTest
import Semi

// InputNumber 对齐官方后的回归测试：步进器 DOM 结构 / 令牌、步进数学与越界规则、
// precision、formatter/parser、失焦钳位、onChange 与 onNumberChange 的分工、
// 长按连发、键盘、innerButtons / hideButtons、科学计数法、货币展示。
// 断言尽量落在渲染出来的项上（宽高、颜色、图标名、显示串），而不是中间属性。
TestCase {
    id: testCase

    name: "InputNumberPro"
    when: windowShown
    width: 900
    height: 900

    property var changes: []
    property var numberChanges: []

    function init() {
        // 见 PROGRESS.md 坑 4：TestCase 根项的 effectiveVisible 在窗口 show 后不刷新，
        // 不显式置 visible 的话 QtTest 的合成鼠标 / 键盘事件会被静默丢弃
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
        testCase.changes = []
        testCase.numberChanges = []
    }

    function rmbFormat(v) {
        return "￥ " + String(v).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }

    function rmbParse(v) {
        return String(v).replace(/￥\s?|(,*)/g, "");
    }

    function dashFormat(v) {
        return String(v).split("").join("-");
    }

    function dashParse(v) {
        return String(v).replace(/-/g, "");
    }

    function digitsOnly(v) {
        return String(v).replace(/\D/g, "");
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
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

    function one(root, name) {
        const found = walk(root, name)
        return found.length > 0 ? found[0] : null
    }

    function shown(root, name) {
        return walk(root, name).filter(function (it) { return it.visible })
    }

    // ---- 步进器的 DOM 与令牌 ----

    // 官方步进器是 Input 的兄弟节点，不是塞在框里（index.tsx:587-589）
    function test_stepperSitsOutsideTheBox() {
        const n = make('InputNumber { width: 200; value: 1 }')
        wait(60)
        const col = one(n, "stepperColumn")
        verify(col !== null, "该有步进器列")
        // $width-inputNumber_button 14 + 两侧 1px 描边
        compare(col.width, 14 + 1 + 1)
        // 左边距 $spacing-inputNumber_button-marginLeft = 4，所以 Input 让出 4+16
        compare(n.innerInput.width, 200 - (Theme.current.spacingExtraTight + col.width))
        compare(col.height, Theme.current.heightControlDefault)
        n.destroy()
    }

    function test_borderlessStepperHiddenWhileIdle() {
        const n = make('InputNumber { width: 200; value: 1; borderless: true }')
        wait(60)
        const stepper = one(n, "stepperColumn").parent
        compare(stepper.opacity, 0)
        n.field.forceActiveFocus()
        wait(60)
        compare(stepper.opacity, 1)
        n.destroy()
        // 有边框时不受这条规则影响
        const m = make('InputNumber { width: 200; value: 1 }')
        wait(60)
        compare(one(m, "stepperColumn").parent.opacity, 1)
        m.destroy()
    }

    // 官方 wrapper 是 inline-flex（inputNumber.scss:7），宽度由内容撑开：
    // Input 的自然宽 + 步进器（4 左边距 + 16 列宽）
    function test_implicitWidthIsInputPlusStepper() {
        const n = make('InputNumber { value: 1 }')
        wait(60)
        compare(n.implicitWidth, n.innerInput.implicitWidth + Theme.current.spacingExtraTight + 16)
        compare(n.width, n.implicitWidth)
        n.destroy()
        const h = make('InputNumber { value: 1; hideButtons: true }')
        wait(60)
        compare(h.implicitWidth, h.innerInput.implicitWidth)
        h.destroy()
    }

    function test_stepperColumnTokens() {
        const n = make('InputNumber { width: 200; value: 1 }')
        wait(60)
        const col = one(n, "stepperColumn")
        compare(col.border.width, 1)                            // $width-inputNumber_button-border
        compare(col.radius, Theme.current.radiusSmall)          // --semi-border-radius-small
        compare(col.color.toString(), Theme.current.colorBg2.toString())
        compare(col.border.color.toString(), Theme.current.colorBorder.toString())
        n.destroy()
    }

    // 列是 border-box（inputNumber.scss:15-23），按钮 height:50% 相对的是内容盒，
    // 也就是 (控件高 - 上下各 1px 描边) / 2；按钮还要整体内缩一个描边宽，
    // 否则会画在列的描边上面。
    function test_twoButtonsStackVerticallyAtHalfHeight() {
        const n = make('InputNumber { width: 200; value: 1 }')
        wait(60)
        const col = one(n, "stepperColumn")
        const up = one(n, "stepUpButton")
        const down = one(n, "stepDownButton")
        compare(col.height, Theme.current.heightControlDefault)
        compare(up.width, 14)
        compare(up.height, (Theme.current.heightControlDefault - col.border.width * 2) / 2)
        compare(up.height, 15)
        compare(up.x, col.border.width)
        compare(up.y, col.border.width)
        compare(down.y, up.y + up.height)
        compare(down.height, up.height)
        // 两个按钮正好填满内容盒，上下各留 1px 描边
        compare(up.y + up.height * 2, col.height - col.border.width)
        n.destroy()
    }

    // 官方 <IconChevronUp size="extra-small" />（index.tsx:485、493），extra-small = 8px
    function test_iconsAreEightPxChevrons() {
        const n = make('InputNumber { width: 200; value: 1 }')
        wait(60)
        const upIcon = one(n, "stepUpIcon")
        const downIcon = one(n, "stepDownIcon")
        compare(upIcon.name, "chevron_up")
        compare(downIcon.name, "chevron_down")
        compare(upIcon.size, Theme.current.widthIconExtraSmall)
        compare(upIcon.size, 8)
        // $color-inputNumber_button-text-default
        compare(upIcon.color.toString(), Theme.current.colorText2.toString())
        n.destroy()
    }

    function test_sizeChangesColumnHeight() {
        const small = make('InputNumber { width: 200; size: Enums.Small; value: 1 }')
        const large = make('InputNumber { width: 200; size: Enums.Large; value: 1 }')
        wait(60)
        compare(one(small, "stepperColumn").height, Theme.current.heightControlSmall)
        compare(one(large, "stepperColumn").height, Theme.current.heightControlLarge)
        compare(small.height, Theme.current.heightControlSmall)
        compare(large.height, Theme.current.heightControlLarge)
        small.destroy(); large.destroy()
    }

    function test_disabledStepperUsesDisabledTokens() {
        const n = make('InputNumber { width: 200; value: 1; enabled: false }')
        wait(60)
        const up = one(n, "stepUpButton")
        const icon = one(n, "stepUpIcon")
        // $color-inputNumber_button-bg-disabled / -text-disabled
        compare(up.color.toString(), Theme.current.colorDisabledFill.toString())
        compare(icon.color.toString(), Theme.current.colorDisabledText.toString())
        n.destroy()
    }

    // ---- hideButtons / innerButtons ----

    function test_hideButtonsLeavesNoStepper() {
        const n = make('InputNumber { width: 200; hideButtons: true; value: 1 }')
        wait(60)
        compare(shown(n, "stepperColumn").length, 0)
        compare(n.innerInput.width, 200)
        n.destroy()
    }

    // 官方：innerButtons 时外层不渲染（index.tsx:587），内层只在 hovering || focusing 出现
    // （index.tsx:499-508），且高度是控件高 - 2（VA:4-6）
    function test_innerButtonsAppearOnlyOnFocus() {
        const n = make('InputNumber { width: 200; innerButtons: true; value: 1 }')
        wait(60)
        compare(shown(n, "stepperColumn").length, 0, "未悬浮未聚焦时内联步进器不该出现")
        n.field.forceActiveFocus()
        wait(60)
        const cols = shown(n, "stepperColumn")
        compare(cols.length, 1, "聚焦后内联步进器该出现")
        compare(cols[0].height, Theme.current.heightControlDefault - 2)
        // 内联形态是走 Input 的 suffix 槽（官方 .semi-input__with-suffix 清掉输入区
        // 自己的右内边距），让出宽度的是文本区，不是外层那个 Input 盒子
        const inside = cols[0].mapToItem(n.innerInput, 0, 0)
        verify(inside.x > 0, "内联步进器应在 Input 盒子内部")
        verify(Math.round(inside.x + cols[0].width) <= n.innerInput.width,
               "内联步进器不该超出 Input 右边界")
        verify(n.field.width < n.innerInput.width - 24, "文本区要给内联步进器让位")
        n.destroy()
    }

    // .semi-input-number-suffix-btns-inner-hover：悬浮但未聚焦时描边换 color-fill-2
    function test_innerStepperBorderFollowsHoverState() {
        const n = make('InputNumber { width: 300; innerButtons: true; value: 1 }')
        n.x = 20; n.y = 20
        wait(60)
        mouseMove(n, 60, 10)
        wait(80)
        const cols = shown(n, "stepperColumn")
        compare(cols.length, 1, "悬浮时内联步进器该出现")
        compare(cols[0].border.color.toString(), Theme.current.colorFill2.toString())
        n.destroy()
    }

    // ---- 步进 ----

    function test_clickUpStepsByStep() {
        const n = make('InputNumber { width: 200; value: 5; step: 2 }')
        wait(60)
        const up = one(n, "stepUpButton")
        mouseClick(up, Qt.LeftButton, Qt.NoModifier)
        wait(30)
        compare(n.value, 7)
        compare(n.field.text, "7")
        n.destroy()
    }

    function test_clickDownStepsByStep() {
        const n = make('InputNumber { width: 200; value: 5; step: 2 }')
        wait(60)
        const down = one(n, "stepDownButton")
        mouseClick(down, Qt.LeftButton, Qt.NoModifier)
        wait(30)
        compare(n.value, 3)
        n.destroy()
    }

    // shiftStep 默认 10（constants.ts:10 + index.tsx:124）。
    // 带修饰符的 mouseClick 在这个环境下不会送达（实测 mouseClick(item, LeftButton,
    // ShiftModifier) 后值没动），所以按官方按下时读 event.shiftKey 的那条分支
    // 直接喂 shift 标志，键盘那条路径另有用例覆盖。
    function test_shiftStepUsedWhenShiftHeld() {
        const n = make('InputNumber { width: 200; value: 5 }')
        wait(60)
        n.stepBy(true, true)
        wait(30)
        compare(n.value, 15)
        n.stepBy(false, true)
        wait(30)
        compare(n.value, 5)
        const m = make('InputNumber { width: 200; value: 5; shiftStep: 0.5 }')
        wait(60)
        m.stepBy(true, true)
        compare(m.field.text, "5.5", "shiftStep 可以为小数")
        n.destroy(); m.destroy()
    }

    // 官方不补半步：剩余距离不足一个步长就完全不动（foundation.ts:504-507）
    function test_noPartialStepAtBoundary() {
        const n = make('InputNumber { width: 200; value: 98; step: 5; max: 100 }')
        wait(60)
        n.stepBy(true, false)
        compare(n.field.text, "98")
        compare(n.value, 98)
        n.destroy()
    }

    // notAllowedUp = disabled || number === max（index.tsx:462-463），此时按钮挂的是 noop
    function test_upButtonDoesNothingAtMax() {
        const n = make('InputNumber { width: 200; value: 10; max: 10 }')
        wait(60)
        compare(n.notAllowedUp, true)
        const up = one(n, "stepUpButton")
        mouseClick(up, Qt.LeftButton, Qt.NoModifier)
        wait(30)
        compare(n.value, 10)
        n.destroy()
    }

    function test_downButtonDoesNothingAtMin() {
        const n = make('InputNumber { width: 200; value: 3; min: 3 }')
        wait(60)
        compare(n.notAllowedDown, true)
        const down = one(n, "stepDownButton")
        mouseClick(down, Qt.LeftButton, Qt.NoModifier)
        wait(30)
        compare(n.value, 3)
        n.destroy()
    }

    function test_readOnlyBlocksStepping() {
        const n = make('InputNumber { width: 200; value: 5; readOnly: true }')
        wait(60)
        n.stepBy(true, false)
        compare(n.value, 5, "readOnly 时按钮步进不生效（foundation.ts:374-377）")
        n.destroy()
    }

    // keyClick 要按仓库里既有的写法走窗口级（keyClick(key[, mods])）：
    // 传成 keyClick(item, key) 会落错重载，实测事件里 key=0、按键值跑到 modifiers 上
    function test_keyboardUpAndDownStep() {
        const n = make('InputNumber { width: 200; value: 5; step: 1 }')
        wait(60)
        n.field.forceActiveFocus()
        wait(60)
        keyClick(Qt.Key_Up)
        wait(30)
        compare(n.value, 6, "ArrowUp 加一步")
        keyClick(Qt.Key_Down)
        wait(30)
        compare(n.value, 5, "ArrowDown 减一步")
        keyClick(Qt.Key_Down, Qt.ShiftModifier)
        wait(30)
        compare(n.value, -5, "Shift+ArrowDown 走 shiftStep")
        n.destroy()
    }

    // Input.arrowsAsKeys 打开后 Up/Down 不再挪光标（官方是 preventDefault）
    function test_arrowKeysDoNotMoveCaret() {
        const n = make('InputNumber { width: 200; value: 123 }')
        wait(60)
        n.field.forceActiveFocus()
        wait(60)
        n.field.cursorPosition = 0
        keyClick(Qt.Key_Up)
        wait(30)
        compare(n.value, 124)
        compare(n.field.cursorPosition, 0, "Up 被步进吃掉，不该挪光标")
        n.destroy()
    }

    function test_stepFromEmptyStartsAtZero() {
        const n = make('InputNumber { width: 200; step: 3 }')
        wait(60)
        n.stepBy(true, false)
        // curNum = toNumber(curVal) || 0（foundation.ts:490）
        compare(n.value, 3)
        n.destroy()
    }

    // 放大成整数再运算，避开二进制误差（utils/number.ts:9-18）
    function test_decimalStepHasNoFloatNoise() {
        const n = make('InputNumber { width: 200; value: 0.2; step: 0.1 }')
        wait(60)
        n.stepBy(true, false)
        compare(n.field.text, "0.3")
        compare(n.value, 0.3)
        n.destroy()
        // 放大成整数后仍然留着二进制尾巴（0.01*100 + 1.12*100 = 113.00000000000001），
        // accurateAdd 里那道 Math.round 才把它收成 1.13
        const m = make('InputNumber { width: 200; value: 0.01; step: 1.12 }')
        wait(60)
        m.stepBy(true, false)
        compare(m.field.text, "1.13")
        compare(m.value, 1.13)
        m.destroy()
    }

    // ---- 长按连发 ----

    function test_longPressRepeatsAfterPressTimeout() {
        const n = make('InputNumber { width: 200; value: 0; step: 1 }')
        wait(60)
        const up = one(n, "stepUpButton")
        mousePress(up, Qt.LeftButton, Qt.NoModifier)
        wait(30)
        compare(n.value, 1, "按下即刻走第一步，不是等 pressTimeout")
        // 官方时序：首步 0ms，之后第一次连发在 pressTimeout + pressInterval = 500ms
        // （foundation.ts:387-391，_registerTimer 到点才 _registerInterval）
        wait(700)
        compare(n.value >= 2, true, "pressTimeout 之后要按 pressInterval 连发")
        mouseRelease(up, Qt.LeftButton, Qt.NoModifier)
        const held = n.value
        wait(500)
        compare(n.value, held, "松开后计时器要停")
        n.destroy()

        // 第一次连发必须等满 pressTimeout：把两段时长拉开成 300 / 100，
        // 那么在 t=200 这一刻只可能有「按下时的第一步」
        const m = make('InputNumber { width: 200; value: 0; pressTimeout: 300; pressInterval: 100 }')
        wait(60)
        const up2 = one(m, "stepUpButton")
        mousePress(up2, Qt.LeftButton, Qt.NoModifier)
        wait(200)
        compare(m.value, 1, "pressTimeout 之前不该有第二次步进")
        wait(450)
        compare(m.value >= 3, true, "过了 pressTimeout 就该按 pressInterval 连发")
        mouseRelease(up2, Qt.LeftButton, Qt.NoModifier)
        m.destroy()
    }

    function test_pressTimeoutAndIntervalAreConfigurable() {
        const n = make('InputNumber { width: 200; value: 0; pressTimeout: 50; pressInterval: 50 }')
        wait(60)
        const up = one(n, "stepUpButton")
        mousePress(up, Qt.LeftButton, Qt.NoModifier)
        wait(320)
        mouseRelease(up, Qt.LeftButton, Qt.NoModifier)
        compare(n.value >= 5, true, "把两个时长调小后连发更密")
        n.destroy()
    }

    function test_keepFocusReturnsFocusToField() {
        const n = make('InputNumber { width: 200; value: 1; keepFocus: true }')
        wait(60)
        n.field.forceActiveFocus()
        wait(60)
        const up = one(n, "stepUpButton")
        mouseClick(up, Qt.LeftButton, Qt.NoModifier)
        wait(40)
        compare(n.field.activeFocus, true, "keepFocus 点按钮后焦点留在输入框")
        n.destroy()
    }

    // ---- precision / 上下界默认值 ----

    function test_precisionFixesDecimals() {
        const n = make('InputNumber { width: 200; precision: 2; defaultValue: 1.234 }')
        wait(60)
        compare(n.field.text, "1.23")
        n.destroy()
        // 手输超精度的串：失焦后不只是显示要收成 1.23，写进 value 的数字也得是收过的
        // （官方 _toNumber 的 adjustPrecision 就是干这个的）
        const m = make('InputNumber { width: 200; precision: 2 }')
        wait(60)
        m.handleInputTextChanged("1.2345")
        m.handleFocusOut()
        wait(30)
        compare(m.field.text, "1.23")
        compare(m.value, 1.23, "value 也得按 precision 收过")
        m.destroy()
    }

    function test_withoutPrecisionKeepsRawDigits() {
        // 官方 precision 没有默认值，也不会从 step 反推
        const n = make('InputNumber { width: 200; step: 0.25; defaultValue: 1 }')
        wait(60)
        n.stepBy(true, false)
        compare(n.field.text, "1.25")
        n.destroy()
    }

    // min/max 默认 ±Infinity（index.tsx:119-120）
    function test_boundsDefaultToInfinity() {
        const n = make('InputNumber { width: 200 }')
        wait(60)
        compare(n.min, -Infinity)
        compare(n.max, Infinity)
        n.handleInputTextChanged("999999999999")
        wait(30)
        compare(n.value, 999999999999)
        n.destroy()
    }

    // 输入过程中不钳位，失焦才钳（foundation.ts:283 + 674-683）
    function test_typingOutOfRangeKeepsTextUntilBlur() {
        const n = make('InputNumber { width: 200; min: 0; max: 10; '
            + 'onChange: (v) => testCase.changes.push(v) }')
        wait(60)
        n.handleInputTextChanged("999")
        wait(30)
        compare(n.field.text, "999", "输入中不该被改写成 10")
        compare(n.number, undefined, "越界的值不该写进 number")
        compare(testCase.changes.length, 1)
        compare(testCase.changes[0], 999)
        n.handleFocusOut()
        wait(30)
        compare(n.field.text, "10")
        compare(n.value, 10)
        n.destroy()
    }

    function test_blurClampsBelowMin() {
        const n = make('InputNumber { width: 200; min: 5; max: 20 }')
        wait(60)
        n.handleInputTextChanged("1")
        n.handleFocusOut()
        wait(30)
        compare(n.value, 5)
        compare(n.field.text, "5")
        n.destroy()
    }

    // issue #38：串里混了非数字字符，失焦时仍能提出数字并钳位
    function test_blurExtractsNumberFromJunk() {
        const n = make('InputNumber { width: 200; max: 10 }')
        wait(60)
        n.handleInputTextChanged("8abc")
        n.handleFocusOut()
        wait(30)
        compare(n.value, 8)
        n.destroy()
    }

    // ---- onChange / onNumberChange 分工 ----

    function test_clearingEmitsEmptyStringAndNoNumberChange() {
        const n = make('InputNumber { width: 200; value: 3; '
            + 'onChange: (v) => testCase.changes.push([v, typeof v]); '
            + 'onNumberChange: (v) => testCase.numberChanges.push(v) }')
        wait(60)
        testCase.changes = []
        testCase.numberChanges = []
        n.handleInputTextChanged("")
        wait(30)
        compare(testCase.changes.length, 1)
        compare(testCase.changes[0][0], "")
        compare(testCase.changes[0][1], "string", "官方清空时 onChange 收的是空串（foundation.ts:843-844）")
        compare(testCase.numberChanges.length, 0)
        compare(n.number, undefined)
        n.destroy()
    }

    function test_numberChangeSkipsOutOfRange() {
        const n = make('InputNumber { width: 200; min: 0; max: 10; '
            + 'onNumberChange: (v) => testCase.numberChanges.push(v) }')
        wait(60)
        n.handleInputTextChanged("999")
        wait(30)
        compare(testCase.numberChanges.length, 0, "越界不触发 onNumberChange")
        n.handleInputTextChanged("7")
        wait(30)
        compare(testCase.numberChanges, [7])
        n.destroy()
    }

    function test_upClickAndDownClickCarryFormattedString() {
        const n = make('InputNumber { width: 200; value: 1000; '
            + 'onUpClick: (v) => testCase.changes.push([v, typeof v]) }')
        wait(60)
        n.stepBy(true, false)
        wait(30)
        compare(testCase.changes.length, 1)
        compare(testCase.changes[0][0], "1001")
        compare(testCase.changes[0][1], "string", "onUpClick 收的是格式化后的串")
        n.destroy()
    }

    // ---- formatter / parser ----

    function test_formatterAppliesOnEveryKeystroke() {
        const n = make('InputNumber { width: 220; defaultValue: 1000; min: 0; '
            + 'formatter: rmbFormat; parser: rmbParse }')
        wait(60)
        compare(n.field.text, "￥ 1,000")
        n.handleInputTextChanged("2500")
        wait(30)
        compare(n.field.text, "￥ 2,500")
        compare(n.value, 2500, "parser 要能把格式化串还原成数字")
        n.destroy()
    }

    function test_digitGroupingFormatterDemo() {
        // 官方「自定义串」：formatter 把每位数字用 - 连起来
        const n = make('InputNumber { width: 220; defaultValue: 1111; '
            + 'formatter: dashFormat; parser: dashParse }')
        wait(60)
        compare(n.field.text, "1-1-1-1")
        n.destroy()
    }

    // 纯数字输入框：formatter 去掉所有非数字（官方 >=1.9.0 示例）
    function test_digitsOnlyFormatterStripsNonDigits() {
        const n = make('InputNumber { width: 220; min: 0; formatter: digitsOnly }')
        wait(60)
        n.handleInputTextChanged("12a3")
        wait(30)
        compare(n.field.text, "123")
        n.destroy()
    }

    function test_trailingDotSurvivesTyping() {
        // foundation.ts:218-228：打「1.」时不要把小数点吃掉
        const n = make('InputNumber { width: 200 }')
        wait(60)
        n.handleInputTextChanged("1.")
        wait(30)
        compare(n.field.text, "1.")
        n.destroy()
    }

    // ---- 科学计数法 ----

    function test_scientificShowsWhenDigitsReachThreshold() {
        const n = make('InputNumber { width: 240; scientificNotation: true; value: 123456789012345 }')
        wait(60)
        compare(n.field.text, "1.23456789012345e+14")
        n.handleFocusIn()
        wait(30)
        compare(n.field.text, "123456789012345", "聚焦时还原完整数字")
        n.handleFocusOut()
        wait(30)
        compare(n.field.text, "1.23456789012345e+14")
        n.destroy()
    }

    function test_scientificBelowThresholdStaysPlain() {
        const n = make('InputNumber { width: 240; scientificNotation: true; value: 12345678901234 }')
        wait(60)
        // 14 位有效数字 < 默认阈值 15
        compare(n.field.text, "12345678901234")
        n.destroy()
    }

    function test_scientificCustomThreshold() {
        // 尾数位数要超过阈值才看得出 toExponential(阈值-1)：12 位有效数字、阈值 10，
        // 少减 1 就会多留一位（1.2345678901e+11）
        const n = make('InputNumber { width: 240; scientificNotation: ({ threshold: 10 });'
            + ' value: 123456789012 }')
        wait(60)
        compare(n.field.text, "1.23456789e+11")
        n.destroy()
    }

    // ---- 货币 ----

    // 期望值逐个取自 Node 的 Intl（与浏览器同一份 CLDR），NBSP 用 \\u00A0 写死
    function test_currencySymbolPerLocale() {
        const zh = make('InputNumber { width: 240; localeCode: "zh-CN"; currency: "CNY"; value: 123456.78 }')
        const de = make('InputNumber { width: 240; localeCode: "de-DE"; currency: "EUR"; value: 123456.78 }')
        const ja = make('InputNumber { width: 240; localeCode: "ja-JP"; currency: "JPY"; value: 123456.78 }')
        const vi = make('InputNumber { width: 240; localeCode: "vi-VN"; currency: "VND"; value: 123456.78 }')
        wait(60)
        compare(zh.field.text, "¥123,456.78")
        compare(de.field.text, "123.456,78 €")
        // JPY / VND 是 0 位小数的币种，四舍五入到整数
        compare(ja.field.text, "￥123,457")
        compare(vi.field.text, "123.457 ₫")
        zh.destroy(); de.destroy(); ja.destroy(); vi.destroy()
    }

    function test_currencyDisplayCodeAndName() {
        const code = make('InputNumber { width: 240; currency: "CNY"; currencyDisplay: "code"; value: 123456.78 }')
        const name = make('InputNumber { width: 240; currency: "CNY"; currencyDisplay: "name"; value: 123456.78 }')
        wait(60)
        compare(code.field.text, "CNY 123,456.78")
        // zh-CN 的 name 形式是后缀，且与数字之间没有空格
        compare(name.field.text, "123,456.78人民币")
        code.destroy(); name.destroy()
    }

    function test_showCurrencySymbolStripsToken() {
        const n = make('InputNumber { width: 240; currency: "CNY"; showCurrencySymbol: false;'
            + ' value: 123456.78 }')
        wait(60)
        compare(n.field.text, "123,456.78")
        n.destroy()
    }

    // currency={true} 按 localeCode 选币种（foundation.ts:879-918）
    function test_currencyTruePicksCurrencyFromLocale() {
        const ru = make('InputNumber { width: 240; localeCode: "ru-RU"; currency: true; value: 123456.78 }')
        const fr = make('InputNumber { width: 240; localeCode: "fr-FR"; currency: true; value: 123456.78 }')
        wait(60)
        compare(ru.currencyActive, true)
        compare(ru.field.text, "123 456,78 ₽")
        // 法语千分位是窄 NBSP（U+202F）
        compare(fr.field.text, "123 456,78 €")
        ru.destroy(); fr.destroy()
    }

    function test_currencyParsesBackToNumber() {
        const n = make('InputNumber { width: 240; localeCode: "de-DE"; currency: "EUR"; value: 100 }')
        wait(60)
        n.handleInputTextChanged("123.456,78\u00A0€")
        wait(30)
        compare(n.value, 123456.78, "德语小数点是逗号，parser 走货币分支")
        n.destroy()
    }

    // ---- 初值与转发 ----

    function test_defaultValueOnlySetsInitialValue() {
        const n = make('InputNumber { width: 200; defaultValue: 7 }')
        wait(60)
        compare(n.value, 7)
        compare(n.field.text, "7")
        n.stepBy(true, false)
        compare(n.defaultValue, 7, "步进不该回写 defaultValue")
        n.destroy()
    }

    function test_emptyStartShowsNothing() {
        const n = make('InputNumber { width: 200 }')
        wait(60)
        compare(n.field.text, "")
        compare(n.value, undefined)
        n.destroy()
    }

    function test_showClearForwardsToInput() {
        const n = make('InputNumber { width: 240; showClear: true; value: 5 }')
        wait(60)
        compare(n.innerInput.showClear, true)
        n.destroy()
    }

    function test_prefixAndInsetLabelForward() {
        const n = make('InputNumber { width: 240; prefix: "CNY"; value: 1 }')
        const m = make('InputNumber { width: 240; insetLabel: "数量"; value: 1 }')
        wait(60)
        compare(one(n, "prefixText").text, "CNY")
        compare(one(m, "insetLabel").text, "数量")
        n.destroy(); m.destroy()
    }
}
