import QtQuick
import QtTest
import Semi

// Input 的前缀 / 后缀 / 前后置标签 / 清除 / 密码 / 自定义长度，TextArea 的行号 / 字数统计 /
// autosize，以及独立 InputGroup。断言尽量落在渲染出来的项上（坐标、宽度、颜色、文字），
// 而不是组件上那些中间属性。
TestCase {
    id: testCase

    name: "InputPro3"
    when: windowShown
    width: 900
    height: 900

    property int clearEvents: 0
    property int acceptedEvents: 0
    property string counted: ""

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
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

    // 某个容器里真正被画出来的那个文字项
    function glyph(item) {
        const kids = item.children.filter(function (c) { return c.text !== undefined && c.visible })
        return kids.length > 0 ? kids[0] : null
    }

    // ---- 前缀 / 后缀 ----

    // .semi-input-prefix-text { margin: 0 12 }，图标是 0 8（input.scss:516-531）
    function test_prefixTextGapIsTwelve() {
        const i = make('Input { width: 300; prefix: "Prefix"; text: "abc" }')
        wait(60)
        const box = one(i, "inputWrapper")
        const text = one(i, "prefixText")
        const field = i.input
        // 有 prefix 时 wrapper 自己的左内边距清 0，那 12 由标签的左边距提供
        compare(Math.round(text.mapToItem(i, 0, 0).x - box.mapToItem(i, 0, 0).x), 12)
        // 标签右边缘到输入文字左边缘也是 12
        verify(Math.round(field.mapToItem(i, 0, 0).x - (text.mapToItem(i, 0, 0).x + text.width)) === 12,
            "prefix 与文字之间应为 12")
        i.destroy()
    }

    function test_prefixIconGapIsEight() {
        const i = make('Input { width: 300; prefixIcon: "search"; text: "abc" }')
        wait(60)
        const box = one(i, "inputWrapper")
        const icon = one(i, "prefixIcon")
        compare(Math.round(icon.mapToItem(box, 0, 0).x), 8)
        i.destroy()
    }

    // 自定义 ReactNode 左右间距为 0
    function test_prefixNodeGapIsZero() {
        // 内联 Component 不能写在 Qt.createQmlObject 的单行串里，先建一个带 id 的组件再指过去
        const host = make('Item { Component { id: node; Rectangle { width: 20; height: 12; color: "red" } } Input { objectName: "theInput"; width: 300; prefix: node; text: "abc" } }')
        wait(60)
        const i = one(host, "theInput")
        const node = one(i, "prefixNode")
        const box = one(i, "inputWrapper")
        verify(node !== null && node.visible)
        compare(Math.round(node.mapToItem(box, 0, 0).x), 0)
        host.destroy()
    }

    function test_insetLabelSharesPrefixSlot() {
        const i = make('Input { width: 300; insetLabel: "姓名"; text: "amy" }')
        wait(60)
        const label = one(i, "insetLabel")
        const box = one(i, "inputWrapper")
        verify(label.visible)
        compare(label.color.toString(), Theme.current.colorText2.toString())
        compare(label.font.weight, Font.DemiBold)
        compare(Math.round(label.mapToItem(box, 0, 0).x), 12)
        i.destroy()
    }

    // ---- 前置 / 后置标签 ----

    function test_addonsSitOutsideTheInputBox() {
        const i = make('Input { width: 300; addonBefore: "http://"; addonAfter: ".com" }')
        wait(60)
        const pre = one(i, "prepend")
        const app = one(i, "append")
        const box = one(i, "inputWrapper")
        verify(pre.visible && app.visible)
        // 三段从左到右：prepend | 输入区 | append，且总宽等于组件宽度
        compare(pre.x, 0)
        compare(box.x, pre.width)
        compare(app.x + app.width, i.width)
        // 官方 __with-prepend 时 wrapper 透明、.semi-input 自己保留 fill-0 底 + 透明描边
        compare(box.color.toString(), Theme.current.colorFill0.toString())
        compare(box.border.color.toString(), "#00000000")
        // 圆角只留在最外侧两端
        compare(pre.topLeftRadius, Theme.current.radiusSmall)
        compare(pre.topRightRadius, 0)
        compare(box.topLeftRadius, 0)
        compare(box.topRightRadius, 0)
        compare(app.topRightRadius, Theme.current.radiusSmall)
        i.destroy()
    }

    function test_addonTextIsBoldText2WithPadding() {
        const i = make('Input { width: 300; addonBefore: "http://" }')
        wait(60)
        const pre = one(i, "prepend")
        const text = glyph(pre)
        verify(text !== null, "前置标签里没找到文字项")
        compare(text.color.toString(), Theme.current.colorText2.toString())
        compare(text.font.weight, Font.DemiBold)
        // -prepend-text { padding: 0 12 }
        compare(Math.round(pre.width - text.implicitWidth), 24)
        i.destroy()
    }

    // ---- 清除按钮 ----

    function test_clearButtonNeedsValueAndFocus() {
        const i = make('Input { width: 300; showClear: true }')
        wait(60)
        compare(shown(i, "clearBtn").length, 0, "空值时不该有清除按钮")
        i.input.text = "abc"
        wait(20)
        compare(shown(i, "clearBtn").length, 0, "有值但未聚焦 / 悬浮时也不该出现")
        i.input.forceActiveFocus()
        wait(60)
        const btn = shown(i, "clearBtn")[0]
        verify(btn !== undefined, "聚焦后应出现清除按钮")
        // min-width = 图标中尺寸 + 8 × 2
        compare(Math.round(btn.width), Theme.current.widthIconMedium + Theme.current.spacingTight * 2)
        i.destroy()
    }

    function test_clearButtonUsesClearIconAndEmptiesValue() {
        testCase.clearEvents = 0
        const i = make('Input { width: 300; showClear: true; text: "abc"; onCleared: testCase.clearEvents++ }')
        i.input.forceActiveFocus()
        wait(60)
        const btn = shown(i, "clearBtn")[0]
        const icon = btn.children.filter(function (c) { return c.name !== undefined })[0]
        // 官方是 IconClear，不是 close
        compare(icon.name, "clear")
        mouseClick(btn, Qt.LeftButton, Qt.NoModifier)
        wait(20)
        compare(i.text, "")
        compare(testCase.clearEvents, 1)
        i.destroy()
    }

    function test_hideSuffixOnlyWhileClearIsShown() {
        const i = make('Input { width: 300; suffix: "元"; showClear: true; hideSuffix: true; text: "abc" }')
        wait(60)
        // 未聚焦：清除按钮没出现，后缀照常
        compare(shown(i, "suffixText").length, 1)
        i.input.forceActiveFocus()
        wait(60)
        compare(shown(i, "suffixText").length, 0, "清除按钮出现时后缀应被藏起来")
        i.input.text = ""
        wait(60)
        compare(shown(i, "suffixText").length, 1, "清空后后缀要回来")
        i.destroy()
    }

    // 清除按钮必须**正好站在后缀图标那一格**：官方 wrapper 自己不留右内边距，
    // 后缀图标（16 + 8 外边距）与 clearbtn（32 宽、图标居中）距右边界都是 16
    // （input.scss:151 / 517-541 + variables.scss:72）。原先布局的右边距只看
    // `suffixShown`，清除按钮一顶上来整排就被推左 12px —— 表现为「时钟图标和
    // 清除图标不在同一个位置」。TimePicker 就是这一档（suffixIcon + hideSuffix）。
    function test_clearButtonSitsExactlyWhereTheSuffixIconWas() {
        const i = make('Input { width: 300; suffixIcon: "clock"; hideSuffix: true; showClear: true; text: "abc" }')
        tryVerify(function () { return one(i, "inputWrapper").width > 0; })
        const edge = one(i, "inputWrapper").mapToItem(null, 300, 0).x
        const clock = shown(i, "suffixIcon")[0]
        compare(Math.round(edge - clock.mapToItem(null, clock.width / 2, 0).x), 16)
        i.input.forceActiveFocus()
        tryVerify(function () { return shown(i, "clearBtn")[0].height > 0; })
        const btn = shown(i, "clearBtn")[0]
        compare(Math.round(btn.width), 32)
        compare(Math.round(edge - btn.mapToItem(null, btn.width / 2, 0).x), 16)
        // 后缀在（虽然被顶掉）→ 官方 __with-suffix 把 input 的右内边距清 0
        compare(Math.round(edge - i.input.mapToItem(null, i.input.width, 0).x), 32)
        i.destroy()
    }

    // 没有后缀时官方那条 `__with-suffix` 不成立，input 的 12 右内边距还在：
    // 文字右端距边界 = 32（clearbtn）+ 12。
    function test_clearButtonWithoutSuffixKeepsTheTextInputPadding() {
        const i = make('Input { width: 300; showClear: true; text: "abc" }')
        i.input.forceActiveFocus()
        tryVerify(function () { return shown(i, "clearBtn")[0].height > 0; })
        const edge = one(i, "inputWrapper").mapToItem(null, 300, 0).x
        const btn = shown(i, "clearBtn")[0]
        compare(Math.round(btn.width), 32)
        compare(Math.round(edge - btn.mapToItem(null, btn.width / 2, 0).x), 16)
        compare(Math.round(edge - i.input.mapToItem(null, i.input.width, 0).x), 44)
        i.destroy()
    }

    // 后缀没被顶掉时（hideSuffix 为假）官方是另一档：clearbtn 收到 24 宽并且
    // `justify-content: flex-end`（input.scss:197-201），图标贴右沿、紧挨后缀图标。
    function test_clearButtonBeforeASuffixIconIsNarrowAndRightAligned() {
        const i = make('Input { width: 300; suffixIcon: "clock"; showClear: true; text: "abc" }')
        i.input.forceActiveFocus()
        tryVerify(function () { return shown(i, "clearBtn")[0].height > 0; })
        const edge = one(i, "inputWrapper").mapToItem(null, 300, 0).x
        const btn = shown(i, "clearBtn")[0]
        const icon = btn.children[0]
        compare(Math.round(btn.width), 24)
        // 后缀那一格 32（8 + 16 + 8），clearbtn 贴它的左边：图标右沿 = 格子右沿 = 距边界 32，
        // 中心因此落在 40（居中在 24 里的话会是 44）
        compare(Math.round(edge - btn.mapToItem(null, btn.width, 0).x), 32)
        compare(Math.round(edge - btn.mapToItem(null, icon.x + icon.width / 2, 0).x), 40)
        compare(Math.round(edge - i.input.mapToItem(null, i.input.width, 0).x), 56)
        i.destroy()
    }

    // ---- 密码模式 ----

    function test_passwordModeStartsHiddenAndToggles() {
        const i = make('Input { width: 300; mode: "password"; text: "123456" }')
        wait(60)
        const btn = one(i, "modeBtn")
        verify(btn.visible)
        const icon = btn.children.filter(function (c) { return c.name !== undefined })[0]
        compare(icon.name, "eye_closed_solid")
        compare(i.input.echoMode, TextInput.PasswordEchoOnEdit)
        mouseClick(btn, Qt.LeftButton, Qt.NoModifier)
        wait(20)
        compare(icon.name, "eye_opened")
        compare(i.input.echoMode, TextInput.Normal)
        compare(i.text, "123456", "切换显隐不该改动值本身")
        i.destroy()
    }

    // ---- 校验状态 / 边框形态 ----

    function test_validateStatusPaintsTheWrapper() {
        const warn = make('Input { width: 300; validateStatus: Enums.StatusWarning }')
        const err = make('Input { width: 300; validateStatus: Enums.StatusDanger }')
        wait(60)
        compare(one(warn, "inputWrapper").color.toString(), Theme.current.colorWarningLightDefault.toString())
        compare(one(err, "inputWrapper").color.toString(), Theme.current.colorDangerLightDefault.toString())
        warn.destroy(); err.destroy()
    }

    function test_borderlessAndOnlyBorderChangeTheBox() {
        const plain = make('Input { width: 300 }')
        const borderless = make('Input { width: 300; borderless: true }')
        const only = make('Input { width: 300; onlyBorder: 1 }')
        wait(60)
        compare(one(borderless, "inputWrapper").color.toString(), "#00000000")
        compare(one(borderless, "inputWrapper").border.color.toString(), "#00000000")
        const onlyBox = one(only, "inputWrapper")
        compare(onlyBox.color.toString(), "#00000000")
        compare(onlyBox.border.color.toString(), Theme.current.colorBorder.toString())
        compare(onlyBox.border.width, 1)
        // 普通输入框不受影响
        compare(one(plain, "inputWrapper").color.toString(), Theme.current.colorFill0.toString())
        plain.destroy(); borderless.destroy(); only.destroy()
    }

    function test_largeSizeUsesHeader6Font() {
        const small = make('Input { width: 300 }')
        const large = make('Input { width: 300; size: Enums.Large }')
        wait(60)
        compare(small.input.font.pixelSize, Theme.current.fontSizeRegular)
        compare(large.input.font.pixelSize, Theme.current.fontSizeHeader6)
        compare(large.implicitHeight, Theme.current.heightControlLarge)
        small.destroy(); large.destroy()
    }

    // ---- 长度限制 ----

    function test_nativeMaxLengthCapsInput() {
        const i = make('Input { width: 300; maxLength: 3 }')
        i.input.text = "abcdef"
        wait(20)
        // 没给 getValueLength 时交给 TextInput.maximumLength，粘贴 / 赋值同样被截
        compare(i.text.length, 3)
        i.destroy()
    }

    function test_customLengthCountsEmojiAsOne() {
        const i = make('Input { width: 300; maxLength: 3; getValueLength: (s) => { let n = 0; for (let k = 0; k < s.length; ++k) { const c = s.charCodeAt(k); if (c >= 0xD800 && c <= 0xDBFF) ++k; ++n; } return n; } }')
        i.input.text = "💖💖💖💖💖"
        wait(20)
        // 按码点算：5 个 emoji = 5，超过 3 就截到 3
        compare(i.text, "💖💖💖")
        i.destroy()
    }

    // ---- InputGroup ----

    function test_groupLaysChildrenSideBySideWithSeams() {
        const g = make('InputGroup { Input { objectName: "a"; width: 100 } Input { objectName: "b"; width: 140 } Input { objectName: "c"; width: 60 } }')
        wait(60)
        const a = one(g, "a")
        const b = one(g, "b")
        const c = one(g, "c")
        compare(a.x, 0)
        compare(b.x, 100)
        compare(c.x, 240)
        compare(Math.round(g.implicitWidth), 300)
        // n 个子控件之间有 n-1 条接缝，每条 1px、压在左格的右边界上
        const seams = walk(g, "groupSeam")
        compare(seams.length, 2)
        compare(seams[0].width, Theme.current.borderThicknessControl)
        compare(seams[0].x, 100 - Theme.current.borderThicknessControl)
        compare(seams[1].x, 240 - Theme.current.borderThicknessControl)
        g.destroy()
    }

    function test_groupCornersOnlyOnEnds() {
        const g = make('InputGroup { Input { objectName: "a"; width: 100 } Input { objectName: "b"; width: 100 } Input { objectName: "c"; width: 100 } }')
        wait(60)
        const r = Theme.current.radiusSmall
        const a = one(g, "a")
        const b = one(g, "b")
        const c = one(g, "c")
        compare(a.topLeftRadius, r)
        compare(a.topRightRadius, 0)
        compare(b.topLeftRadius, 0)
        compare(b.topRightRadius, 0)
        compare(c.topLeftRadius, 0)
        compare(c.topRightRadius, r)
        g.destroy()
    }

    function test_groupSizeAndDisabledGoToChildren() {
        const g = make('InputGroup { size: Enums.Small; disabled: true; Input { objectName: "a"; width: 100 } Input { objectName: "b"; width: 100 } }')
        wait(60)
        const a = one(g, "a")
        const b = one(g, "b")
        compare(a.size, Enums.Small)
        compare(b.size, Enums.Small)
        compare(Math.round(a.height), Theme.current.heightControlSmall)
        verify(!a.enabled)
        verify(!b.enabled)
        g.destroy()
    }

    // ---- TextArea ----

    function test_textAreaRowsDriveHeight() {
        const four = make('TextArea { width: 300 }')
        const two = make('TextArea { width: 300; rows: 2 }')
        wait(60)
        compare(four.rows, 4)
        // rows × 行高 + 上下 padding 各 5 + 描边各 1
        compare(four.implicitHeight, 4 * four.lineHeightPx + 12)
        compare(two.implicitHeight, 2 * two.lineHeightPx + 12)
        four.destroy(); two.destroy()
    }

    // 命中区：官方 <textarea> 的盒子本身就是输入区，点半空的地方也要能落光标。
    // 正文项只吃 implicitHeight（= 已有文本的行数）时，多行框点中间 / 点底部都落在盒子内、TextEdit 外，
    // 焦点与光标都进不来 —— 只有贴着文本的那几行能点中。
    function test_textAreaEditableCoversWholeBox() {
        const empty = make('TextArea { width: 300; rows: 6 }')
        const counted = make('TextArea { width: 300; rows: 6; maxCount: 20 }')
        wait(60)
        const a = empty.textArea
        const sc = one(empty, "textareaScroller")
        verify(a.implicitHeight < sc.height - 20, "前提：文本只占盒子最上面几行")
        compare(a.y, empty.paddingY)
        compare(Math.round(a.y + a.height), Math.round(sc.height), "正文盒没铺到内容区下沿")

        const c = counted.textArea
        const sc2 = one(counted, "textareaScroller")
        compare(Math.round(c.y + c.height), Math.round(sc2.height))
        // 但统计条那一行不算进命中区（官方 counter 是 textarea 之后的兄弟节点）
        compare(Math.round(sc2.y + sc2.height), Math.round(counted.height - counted.counterHeight - 1))
        empty.destroy(); counted.destroy()
    }

    function test_textAreaLongTextStaysReachable() {
        const t = make('TextArea { width: 300; rows: 2; text: "1\\n2\\n3\\n4\\n5\\n6" }')
        wait(60)
        const area = t.textArea
        const sc = one(t, "textareaScroller")
        verify(area.contentHeight > t.contentHeight, "前提：文本比盒子高")
        compare(area.height, area.contentHeight, "正文项要吃满自己的文本高度，下面的行才点得到")
        verify(sc.contentHeight >= area.contentHeight + t.paddingY * 2,
            "滚动区按盒子高度夹住了文本：" + sc.contentHeight + " < " + (area.contentHeight + 10))
        t.destroy()
    }

    function test_textAreaCounterHasNoSpaces() {
        const t = make('TextArea { width: 300; rows: 2; maxCount: 100; text: "semi design" }')
        wait(60)
        const counter = one(t, "counter")
        verify(counter.visible)
        // 官方渲染的是 `{当前}/{上限}`，中间没有空格（textarea.tsx:375-381）
        compare(counter.text, "11/100")
        compare(counter.color.toString(), Theme.current.colorText2.toString())
        compare(counter.horizontalAlignment, Text.AlignRight)
        // 统计条占 24 高，挂在最下面
        compare(Math.round(t.implicitHeight - counter.y), 24)
        t.destroy()
    }

    function test_textAreaCounterTurnsDangerWhenExceeded() {
        const t = make('TextArea { width: 300; maxCount: 5; text: "semi design" }')
        wait(60)
        compare(one(t, "counter").color.toString(), Theme.current.colorDanger.toString())
        const ok = make('TextArea { width: 300; maxCount: 50; text: "semi design" }')
        wait(60)
        compare(one(ok, "counter").color.toString(), Theme.current.colorText2.toString())
        t.destroy(); ok.destroy()
    }

    function test_textAreaCustomLengthDrivesCounter() {
        const t = make('TextArea { width: 300; maxCount: 10; getValueLength: (s) => String(s).replace(/\\s/g, "").length; text: "semi design" }')
        wait(60)
        // "semi design" 去掉空白是 10 个字符，超过 maxCount=10 时统计条转红
        compare(one(t, "counter").text, "10/10")
        t.destroy()
    }

    // TextArea 的截断看 maxLength（官方 textareaFoundation.ts:162-176 用的就是 maxLength，
    // maxCount 只管统计条），而且二分找截点时必须按 getValueLength 量，不能按 code unit 数
    function test_textAreaMaxLengthUsesCustomLengthFn() {
        const t = make('TextArea { width: 300; maxLength: 3; getValueLength: (s) => { let n = 0; for (let k = 0; k < s.length; ++k) { const c = s.charCodeAt(k); if (c >= 0xD800 && c <= 0xDBFF) ++k; ++n; } return n; } }')
        wait(60)
        t.textArea.text = "💖💖💖💖💖"
        wait(20)
        compare(t.text, "💖💖💖", "按码点截到 3 个 emoji")
        compare(t.text.length, 6, "3 个 emoji 是 6 个 code unit，不是 3 个")
        t.destroy()
    }

    function test_textAreaClearPadsTheTextAndSitsTopRight() {
        const plain = make('TextArea { width: 300 }')
        const clearable = make('TextArea { width: 300; showClear: true; text: "abc" }')
        wait(60)
        const btn = one(clearable, "clearBtn")
        verify(btn.visible, "showClear 时按钮常驻（未满足条件时只是不画图标）")
        // 官方贴在右上角：top 0 / right 4，min-width 图标中尺寸 + 8，高 32
        compare(btn.y, 1)
        compare(Math.round(clearable.width - (btn.x + btn.width)), Theme.current.spacingExtraTight)
        compare(Math.round(btn.width), Theme.current.widthIconMedium + Theme.current.spacingTight)
        compare(Math.round(btn.height), Theme.current.heightControlDefault)
        // 有清除按钮时正文右侧要留出 36 的内边距
        const plainArea = plain.textArea
        const clearArea = clearable.textArea
        verify(clearArea.width < plainArea.width - 20, "showClear 后正文宽度没留出 36")
        plain.destroy(); clearable.destroy()
    }

    function test_textAreaClearEmptiesValue() {
        testCase.clearEvents = 0
        const t = make('TextArea { width: 300; showClear: true; text: "abc"; onCleared: testCase.clearEvents++ }')
        t.textArea.forceActiveFocus()
        wait(60)
        const btn = one(t, "clearBtn")
        mouseClick(btn, Qt.LeftButton, Qt.NoModifier)
        wait(20)
        compare(t.text, "")
        compare(testCase.clearEvents, 1)
        t.destroy()
    }

    function test_textAreaLineNumberOneItemPerHardLine() {
        const t = make('TextArea { width: 420; rows: 6; showLineNumber: true; text: "a\\nb\\nc" }')
        wait(60)
        const items = walk(t, "lineNumberItem")
        compare(items.length, 3)
        compare(glyph(items[0]).text, "1")
        compare(glyph(items[2]).text, "3")
        t.destroy()
    }

    function test_textAreaLineNumberStartOffsetsNumbers() {
        const t = make('TextArea { width: 420; rows: 6; showLineNumber: true; lineNumberStart: 10; text: "a\\nb" }')
        wait(60)
        const items = walk(t, "lineNumberItem")
        compare(glyph(items[0]).text, "10")
        compare(glyph(items[1]).text, "11")
        t.destroy()
    }

    // 软换行那一行要占两格高，行号本身仍然只有一个
    function test_textAreaLineNumberSpansSoftWrappedLine() {
        const t = make('TextArea { width: 300; rows: 6; showLineNumber: true; text: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }')
        wait(60)
        const items = walk(t, "lineNumberItem")
        compare(items.length, 1)
        verify(items[0].height > t.lineHeightPx + 1, "软换行没让行号格变高")
        const tall = make('TextArea { width: 300; rows: 6; showLineNumber: true; text: "aaa" }')
        wait(60)
        const shortItems = walk(tall, "lineNumberItem")
        compare(Math.round(shortItems[0].height), Math.round(tall.lineHeightPx))
        t.destroy(); tall.destroy()
    }

    function test_textAreaLineNumberPanelStyle() {
        const t = make('TextArea { width: 300; rows: 4; showLineNumber: true; text: "a" }')
        wait(60)
        const panel = one(t, "lineNumberPanel")
        verify(panel.visible)
        compare(panel.color.toString(), Theme.current.colorFill1.toString())
        // min-width 36
        verify(panel.width >= 36, "行号栏最小宽度不足 36：" + panel.width)
        // border-right: 1px solid color-border
        const edge = panel.children.filter(function (c) {
            return c.width === 1 && c.color.toString() === Theme.current.colorBorder.toString()
        })
        compare(edge.length, 1)
        t.destroy()
    }

    function test_textAreaAutosizeClampsToMaxRows() {
        const one1 = make('TextArea { width: 300; rows: 1; autosize: true }')
        wait(60)
        compare(one1.implicitHeight, 1 * one1.lineHeightPx + 12)
        one1.text = "a\nb\nc"
        wait(60)
        compare(one1.implicitHeight, 3 * one1.lineHeightPx + 12)

        const capped = make('TextArea { width: 300; autosize: ({ minRows: 1, maxRows: 2 }) }')
        capped.text = "a\nb\nc\nd"
        wait(60)
        compare(capped.implicitHeight, 2 * capped.lineHeightPx + 12)
        one1.destroy(); capped.destroy()
    }

    function test_textAreaTextareaHeightOverridesRows() {
        const t = make('TextArea { width: 300; rows: 8; textareaHeight: 120 }')
        wait(60)
        compare(t.implicitHeight, 120 + 12)
        t.destroy()
    }

    // 官方这一节靠 onKeyDown 对不带 Shift 的 Enter 调 preventDefault
    function test_textAreaEnterCanBeBlockedWithShiftEscape() {
        const t = make('TextArea { width: 300; rows: 3; text: "ab"; onKeyPressed: (event) => { if (!(event.modifiers & Qt.ShiftModifier)) event.accepted = true; } }')
        t.textArea.forceActiveFocus()
        wait(60)
        keyClick(Qt.Key_Return)
        wait(20)
        compare(t.text, "ab", "不带 Shift 的 Enter 应该被挡掉")
        keyClick(Qt.Key_Return, Qt.ShiftModifier)
        wait(20)
        verify(t.text.length > 2, "Shift + Enter 应该换行")
        t.destroy()
    }

    // 不接 keyPressed 时默认行为不变：Enter 照样换行
    function test_textAreaEnterStillWorksByDefault() {
        const t = make('TextArea { width: 300; rows: 3; text: "ab" }')
        t.textArea.forceActiveFocus()
        wait(60)
        keyClick(Qt.Key_Return)
        wait(20)
        verify(t.text.length > 2, "默认情况下 Enter 应该换行，text=" + JSON.stringify(t.text))
        t.destroy()
    }
}
