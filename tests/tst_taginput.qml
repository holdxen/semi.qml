import QtQuick
import QtQuick.Window
import QtTest
import Semi

// TagInput：官方属性面（semi-ui/tagInput/index.tsx）+ 交互（foundation.ts）
// + 官方 DOM 量出来的几何（semi.design 上 .semi-tagInput 的实测值）。
TestCase {
    id: testCase

    name: "TagInput"
    when: windowShown
    width: 900
    height: 700

    readonly property var win: Window.window

    Component {
        id: tagInputComponent

        TagInput {}
    }

    // 给「defaultValue 传数组不能被内部改动污染」那条用
    property var probeSeed: ["a", "b"]
    property var spies: []

    function make(qml) {
        const item = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "tagInputProbe")
        item.visible = true
        return item
    }

    function findAll(root, name, out) {
        out = out === undefined ? [] : out
        const kids = root.children
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i].objectName === name)
                out.push(kids[i])
            findAll(kids[i], name, out)
            // qmllint enable missing-property
        }
        return out
    }

    function one(root, name) {
        const hits = findAll(root, name)
        return hits.length > 0 ? hits[0] : null
    }

    function hosts(ti) {
        const out = []
        for (let i = 0; i < 40; ++i) {
            const hit = one(ti, "tagHost" + i)
            if (hit === null)
                break
            out.push(hit)
        }
        return out
    }

    function field(ti) {
        return one(ti, "tagInputField")
    }

    function flow(ti) {
        return one(ti, "flowArea")
    }

    // 走真实输入路径：聚焦 → 光标挪到末尾 → 逐字符按键
    // （QML 的 TestCase 没有 keyClicks(text)，同 tst_timepicker.qml 的写法）
    function typeInto(ti, text) {
        field(ti).forceActiveFocus()
        wait(30)
        field(ti).cursorPosition = field(ti).text.length
        for (let i = 0; i < String(text).length; ++i)
            keyClick(String(text).charAt(i))
        wait(40)
    }

    function pressEnter(ti) {
        keyClick(Qt.Key_Return)
        wait(50)
    }

    function spill(item, names) {
        const out = {}
        for (let i = 0; i < names.length; ++i) {
            const spy = Qt.createQmlObject(
                "import QtQuick; import QtTest; SignalSpy { }", item, "spy")
            spy.target = item
            spy.signalName = names[i]
            testCase.spies.push(spy)
            out[names[i]] = spy
        }
        return out
    }

    function init() {
        // 根项读到的 effectiveVisible 在窗口 show 后不会立即刷新，
        // 不重新置位的话测试项不可见，合成鼠标事件会被直接丢弃
        testCase.visible = true
        testCase.spies = []
        Theme.reset()
        Theme.mode = Theme.Light
        // 合成鼠标位置是跨用例保留的：上一条停在控件上，这一条一上来就是悬浮态，
        // 底色断言会莫名其妙读到 fill-1。先把指针挪到角落。
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(30)
    }

    function cleanup() {
        Theme.reset()
        Theme.mode = Theme.Light
    }

    // ---- 官方默认值（index.tsx:138-159）----

    function test_defaultsMatchOfficial() {
        const ti = createTemporaryObject(tagInputComponent, testCase)
        verify(ti, "TagInput 创建失败")
        compare(ti.showClear, false)
        compare(ti.addOnBlur, false)
        compare(ti.allowDuplicates, true)
        compare(ti.showRestTagsPopover, true)
        compare(ti.autoFocus, false)
        compare(ti.draggable, false)
        compare(ti.expandRestTagsOnClick, true)
        compare(ti.showContentTooltip, true)
        compare(ti.separator, ",")
        compare(ti.size, Enums.Default)
        compare(ti.validateStatus, Enums.StatusDefault)
        compare(ti.value, undefined)
        compare(ti.inputValue, undefined)
        compare(ti.maxLength, -1)
        compare(ti.max, -1)
        compare(ti.maxTagCount, -1)
        compare(ti.tags.length, 0)
        compare(ti.inputText, "")
        compare(ti.implicitWidth, 240)
        compare(ti.implicitHeight, 32)          // $height-tagInput-default
        compare(ti.active, false)
        compare(ti.renderTagItem, null)
    }

    // ---- 三档高度 24 / 32 / 40，标签 20 / 24，行高含上下外边距 1 / 2 / 3 ----

    function test_heightsFollowSize() {
        const small = make("TagInput { size: Enums.Small; defaultValue: ['a'] }")
        const def = make("TagInput { defaultValue: ['a'] }")
        const large = make("TagInput { size: Enums.Large; defaultValue: ['a'] }")
        wait(50)
        compare(small.implicitHeight, 24)       // $height-control-small
        compare(def.implicitHeight, 32)
        compare(large.implicitHeight, 40)
        compare(small.rowHeight, 22)            // 20 + 1 + 1（$spacing-tagInput_small-Y）
        compare(def.rowHeight, 28)              // 24 + 2 + 2（= $spacing-super-tight）
        compare(large.rowHeight, 30)            // 24 + 3 + 3
        compare(hosts(small)[0].children[0].height, 20)   // $height-tag_small
        compare(hosts(def)[0].children[0].height, 24)     // $height-tag_large
        compare(hosts(large)[0].children[0].height, 24)
        small.destroy(); def.destroy(); large.destroy()
    }

    // ---- 几何：内容区离外框 1px 描边、容器左右内边距 4、标签右外边距 4 ----

    function test_geometryMatchesOfficialMeasurements() {
        const ti = make("TagInput { width: 400; defaultValue: ['抖音', '火山', '西瓜视频'] }")
        wait(50)
        const list = hosts(ti)
        compare(list.length, 3)
        compare(flow(ti).width, 390)            // 400 - 1*2 描边 - 4*2 内边距
        compare(list[0].x, 0)
        fuzzyCompare(list[1].x, list[0].x + list[0].width + 4, 0.6, "标签之间隔 4")
        fuzzyCompare(list[2].x, list[1].x + list[1].width + 4, 0.6)
        const fh = one(ti, "fieldHost")
        fuzzyCompare(fh.x, list[2].x + list[2].width + 4, 0.6, "输入区紧跟最后一个标签")
        fuzzyCompare(fh.x + fh.width, 390, 0.6, "输入区吃掉本行剩下的宽度")
        // 单行时内容垂直居中：32 - 2 描边 = 30 可用，行高 28 → 上下各 1
        compare(list[0].y, 2)                   // 28 的行里居中摆 24 高的标签
        compare(ti.contentHeight, 28)
        ti.destroy()
    }

    function test_tagChromeMatchesWhiteTokenSet() {
        const ti = make("TagInput { width: 400; defaultValue: ['抖音'] }")
        wait(50)
        const tag = hosts(ti)[0].children[0]
        compare(tag.visible, true, "标签必须真画得出来")
        compare(tag.color, "white")
        compare(tag.closable, true)
        compare(tag.textClipped, false)
        const surface = tag.children[0]
        compare(surface.color.toString(), Theme.current.colorBg4.toString())
        compare(surface.border.width, 1)
        fuzzyCompare(surface.border.color.a, 0.7, 0.01, "描边 rgba(grey-2, .7)")
        fuzzyCompare(surface.border.color.g, Theme.current.grey[2].g, 0.01)
        // 浅色下 bg-1..bg-4 全是 #ffffff，拿它们互相顶替看不出来 —— 只有暗色分得开
        Theme.mode = Theme.Dark
        wait(300)                               // Tag 的底色挂 Behavior，等动画走完
        compare(surface.color.toString(), Theme.current.colorBg4.toString())
        verify(surface.color.toString() !== Theme.current.colorBg1.toString(),
            "暗色下 bg-1(#232429) 与 bg-4(#4f5159) 不同，才证明用的确实是 bg-4")
        Theme.mode = Theme.Light
        wait(300)
        compare(tag.text, "抖音")
        // 有叉时右内边距是 4（$spacing-tag_closable-paddingRight），不是 8
        fuzzyCompare(tag.implicitWidth, 8 + 24 + 4 + 12 + 4, 1)
        ti.destroy()
    }

    // ---- 换行：官方 root = max(min-height, 内容 + 2) ----

    function test_tagsWrapAndRootGrows() {
        const ti = make("TagInput { width: 140; defaultValue: ['抖音', '火山', '西瓜视频'] }")
        wait(50)
        const list = hosts(ti)
        compare(list.length, 3)
        compare(list[0].y, 2)                   // 官方 margin-top: 2（tagMarginY）
        verify(list[2].y > 0, "第三个标签应折到第二行")
        compare(ti.contentHeight, 56)           // 两行 × 28
        compare(ti.implicitHeight, 58)          // 官方实测 root h=58
        ti.destroy()
    }

    function test_inputWrapsWhenTextDoesNotFit() {
        const ti = make("TagInput { width: 160; defaultValue: ['抖音'] }")
        wait(50)
        const fh = one(ti, "fieldHost")
        const before = fh.y
        typeInto(ti, "abcdefghijklmnop")
        wait(50)
        verify(fh.width > 14, "输入区按镜像宽度长")
        verify(fh.y > before, "放不下时整个输入区折到下一行")
        compare(ti.contentHeight, 56)
        verify(ti.implicitHeight > 32, "折行后外框要长高")
        ti.destroy()
    }

    // 光标必须落在外框的垂直中线上。field 的盒子按官方 input 那样比文字行高
    // （20 / 24 vs 行高 17 / 19），而 QQuickTextInput 默认把文字行**顶格**排在项里 ——
    // 只居中盒子，光标就整体偏上 (height − contentHeight)/2（实测 default 档偏 3.5px）。
    // 靠 `verticalAlignment: TextInput.AlignVCenter` 把行也居中才对。
    function test_caretIsVerticallyCentered() {
        const sizes = ["Enums.Small", "Enums.Default", "Enums.Large"]
        for (let i = 0; i < sizes.length; ++i) {
            const ti = make("TagInput { width: 400; size: " + sizes[i] + "; defaultValue: ['抖音'] }")
            wait(50)
            const f = field(ti)
            const box = one(ti, "tagInputBox")
            const caret = f.positionToRectangle(0)
            verify(f.height > caret.height,
                sizes[i] + " 档盒子要比行高大，否则这条测不到居中：" + f.height + " vs " + caret.height)
            fuzzyCompare(box.mapFromItem(f, 0, caret.y).y + caret.height / 2, box.height / 2,
                0.6, sizes[i] + " 档光标要在外框中线上")
            // 没输入时 placeholder 与光标基线一致
            const ph = one(ti, "placeholder")
            fuzzyCompare(ph.y + ph.height / 2, f.y + caret.y + caret.height / 2, 0.6,
                sizes[i] + " 档 placeholder 与文字不在同一水平线")
            ti.destroy()
        }
    }

    // ---- 回车添加 ----

    function test_enterAddsTagAndClearsInput() {
        const ti = make("TagInput { width: 400 }")
        const spy = spill(ti, ["change", "add", "inputChange"])
        wait(50)
        typeInto(ti, "ab")
        pressEnter(ti)
        compare(ti.tags.length, 1)
        compare(ti.tags[0], "ab")
        compare(ti.inputText, "", "添加后官方一定清空输入")
        compare(spy.change.count, 1)
        compare(spy.add.count, 1)
        compare(spy.add.signalArguments[0][0].join(","), "ab")
        compare(spy.inputChange.count, 3, "两次打字 + 一次清空")
        compare(spy.inputChange.signalArguments[2][0], "")
        ti.destroy()
    }

    function test_enterWithEmptyInputAddsNothing() {
        const ti = make("TagInput { width: 400; defaultValue: ['抖音'] }")
        const spy = spill(ti, ["change", "add", "inputChange"])
        wait(50)
        field(ti).forceActiveFocus()
        wait(30)
        pressEnter(ti)
        compare(spy.change.count, 0)
        compare(spy.add.count, 0)
        compare(spy.inputChange.count, 0, "inputValue 为空时官方连 onInputChange 都不发")
        compare(ti.tags.length, 1)
        ti.destroy()
    }

    function test_blankAndSpacesFilteredButInputStillCleared() {
        const ti = make("TagInput { width: 400 }")
        const spy = spill(ti, ["change", "inputChange"])
        wait(50)
        typeInto(ti, "   ")
        compare(ti.inputText, "   ")
        pressEnter(ti)
        compare(spy.change.count, 0, "纯空格不生成标签")
        compare(ti.tags.length, 0)
        compare(spy.inputChange.count, 4)
        compare(spy.inputChange.signalArguments[3][0], "", "官方总会再发一次 onInputChange('')")
        compare(ti.inputText, "")
        ti.destroy()
    }

    // ---- separator / split ----

    function test_separatorSplitsBatch() {
        const ti = make("TagInput { width: 400; separator: '-' }")
        wait(50)
        typeInto(ti, "a-b-c")
        pressEnter(ti)
        compare(ti.tags.join(","), "a,b,c")
        ti.destroy()
    }

    function test_separatorArrayNormalizesThroughFirstItem() {
        const ti = make("TagInput { width: 400; separator: ['-', '/', '|', '++'] }")
        wait(50)
        typeInto(ti, "a-b/c|d++e")
        pressEnter(ti)
        compare(ti.tags.join(","), "a,b,c,d,e")
        ti.destroy()
    }

    function test_separatorNullKeepsWholeString() {
        const ti = make("TagInput { width: 400; separator: null }")
        wait(50)
        typeInto(ti, "a,b")
        pressEnter(ti)
        compare(ti.tags.length, 1)
        compare(ti.tags[0], "a,b")
        ti.destroy()
    }

    function test_customSplitOverridesSeparator() {
        const ti = make(`TagInput {
            width: 400
            separator: ','
            split: (value) => value.split('/').filter((s) => s !== '')
        }`)
        wait(50)
        typeInto(ti, "a,b/c")
        pressEnter(ti)
        compare(ti.tags.join("|"), "a,b|c", "自定义 split 拿到的是整串")
        ti.destroy()
    }

    function test_splitArrayMirrorsGetSplitedArray() {
        const ti = make("TagInput { width: 400 }")
        compare(ti.splitArray("a,b,,c").join("|"), "a|b||c", "空段保留，交给过滤那一步")
        ti.separator = 1
        compare(ti.splitArray("a1b").join("|"), "a|b", "number 也当分隔符（官方 isNumber 分支）")
        ti.separator = ["+", "++"]
        compare(ti.splitArray("a++b").join("|"), "a|b", "先归一化到首项再拆，不会拆出空段")
        ti.separator = []
        compare(ti.splitArray("a,b").join("|"), "a,b")
        ti.separator = undefined
        compare(ti.splitArray("a,b").join("|"), "a,b")
        ti.destroy()
    }

    // ---- 退格删最后一个 ----

    function test_backspaceRemovesLastTagWhenInputEmpty() {
        const ti = make("TagInput { width: 400; defaultValue: ['a', 'b'] }")
        const spy = spill(ti, ["remove", "change"])
        wait(50)
        field(ti).forceActiveFocus()
        wait(30)
        keyClick(Qt.Key_Backspace)
        wait(50)
        compare(ti.tags.join(","), "a")
        compare(spy.remove.count, 1)
        compare(spy.remove.signalArguments[0][0], "b")
        compare(spy.remove.signalArguments[0][1], 1)
        compare(spy.change.count, 1)
        ti.destroy()
    }

    function test_backspaceWithTextOnlyEditsInput() {
        const ti = make("TagInput { width: 400; defaultValue: ['a'] }")
        const spy = spill(ti, ["remove"])
        wait(50)
        typeInto(ti, "xy")
        keyClick(Qt.Key_Backspace)
        wait(50)
        compare(spy.remove.count, 0, "输入框还有内容时退格只删字符")
        compare(ti.tags.length, 1)
        compare(ti.inputText, "x")
        ti.destroy()
    }

    function test_backspaceWithNoTagsDoesNothing() {
        const ti = make("TagInput { width: 400 }")
        const spy = spill(ti, ["remove", "change"])
        wait(50)
        field(ti).forceActiveFocus()
        wait(30)
        keyClick(Qt.Key_Backspace)
        wait(50)
        compare(spy.remove.count, 0)
        compare(spy.change.count, 0)
        ti.destroy()
    }

    // ---- 点标签上的叉 ----

    function test_closeIconRemovesThatTag() {
        const ti = make("TagInput { width: 400; defaultValue: ['抖音', '火山'] }")
        const spy = spill(ti, ["remove", "change"])
        wait(50)
        const tag = hosts(ti)[1].children[0]
        mouseClick(tag, tag.width - 8, tag.height / 2)
        wait(50)
        compare(ti.tags.join(","), "抖音")
        compare(spy.remove.count, 1)
        compare(spy.remove.signalArguments[0][0], "火山")
        compare(spy.remove.signalArguments[0][1], 1)
        ti.destroy()
    }

    function test_disabledTagHasNoCloseIcon() {
        const ti = make("TagInput { width: 400; defaultValue: ['抖音']; enabled: false }")
        wait(50)
        const tag = hosts(ti)[0].children[0]
        compare(tag.closable, false)
        compare(tag.disabled, true)
        // 官方 .semi-tagInput-disabled .semi-tagInput-wrapper-tag：底透明、描边不动
        compare(tag.children[0].color, Qt.rgba(0, 0, 0, 0))
        compare(tag.children[0].border.width, 1)
        fuzzyCompare(tag.implicitWidth, 8 + 24 + 8, 1, "没有叉就没有 4px 的右内边距")
        compare(one(tag, "tagLabel").color.toString(), Theme.current.colorDisabledText.toString())
        mouseClick(tag, tag.width - 8, tag.height / 2)
        wait(50)
        compare(ti.tags.length, 1, "禁用点叉不掉")
        ti.destroy()
    }

    // ---- allowDuplicates ----

    function test_duplicatesAllowedByDefault() {
        const ti = make("TagInput { width: 400; defaultValue: ['a'] }")
        wait(50)
        typeInto(ti, "a")
        pressEnter(ti)
        compare(ti.tags.join(","), "a,a")
        ti.destroy()
    }

    function test_allowDuplicatesFalseFiltersBothKinds() {
        const ti = make("TagInput { width: 400; defaultValue: ['a']; allowDuplicates: false }")
        const spy = spill(ti, ["add"])
        wait(50)
        typeInto(ti, "a,a,b")
        pressEnter(ti)
        compare(ti.tags.join(","), "a,b", "已有的和同批重复的都过滤")
        compare(spy.add.count, 1)
        compare(spy.add.signalArguments[0][0].join(","), "b")
        ti.destroy()
    }

    // ---- max / onExceed ----

    function test_maxTruncatesAndReportsPreSliceList() {
        const ti = make("TagInput { width: 400; defaultValue: ['a', 'b']; max: 3 }")
        const spy = spill(ti, ["exceed", "add", "change"])
        wait(50)
        typeInto(ti, "c,d")
        pressEnter(ti)
        compare(spy.exceed.count, 1)
        compare(spy.exceed.signalArguments[0][0].join(","), "a,b,c,d",
            "官方把截断前的整串交给 onExceed")
        compare(ti.tags.join(","), "a,b,c", "只补到 max 为止")
        compare(spy.add.signalArguments[0][0].join(","), "c")
        compare(spy.change.count, 1)
        ti.destroy()
    }

    function test_maxAlreadyFullAddsNothing() {
        const ti = make("TagInput { width: 400; defaultValue: ['a', 'b']; max: 2 }")
        const spy = spill(ti, ["exceed", "change", "inputChange"])
        wait(50)
        typeInto(ti, "c")
        pressEnter(ti)
        compare(spy.exceed.count, 1)
        compare(spy.change.count, 0, "一个都没加成就不该发 onChange")
        compare(ti.tags.join(","), "a,b")
        compare(spy.inputChange.count, 2, "清空那一次照发")
        ti.destroy()
    }

    // ---- maxLength / onInputExceed ----

    function test_maxLengthRejectsGrowthPerSegment() {
        const ti = make("TagInput { width: 400; maxLength: 3 }")
        const spy = spill(ti, ["inputExceed", "inputChange"])
        wait(50)
        typeInto(ti, "ab")
        compare(ti.inputText, "ab")
        typeInto(ti, "c")
        compare(spy.inputExceed.count, 0, "刚好等于 maxLength 还合法")
        typeInto(ti, "d")
        compare(spy.inputExceed.count, 1)
        compare(spy.inputExceed.signalArguments[0][0], "abcd", "入参是整串")
        compare(ti.inputText, "abc", "整次变更作废")
        compare(spy.inputChange.count, 3, "被拒的那次不发 onInputChange")
        ti.destroy()
    }

    function test_maxLengthChecksEachSegmentSeparately() {
        const ti = make("TagInput { width: 400; maxLength: 2 }")
        const spy = spill(ti, ["inputExceed"])
        wait(50)
        typeInto(ti, "ab,c")
        compare(spy.inputExceed.count, 0, "两段各自都不超过 2")
        compare(ti.inputText, "ab,c")
        typeInto(ti, "d")
        compare(spy.inputExceed.count, 0, "第二段 'cd' 正好 2")
        typeInto(ti, "e")
        compare(spy.inputExceed.count, 1)
        compare(ti.inputText, "ab,cd", "第二段变长超限 → 整串退回")
        ti.destroy()
    }

    function test_maxLengthAllowsShrinking() {
        const ti = make("TagInput { width: 400; maxLength: 3 }")
        const spy = spill(ti, ["inputExceed", "inputChange"])
        wait(50)
        typeInto(ti, "abc")
        compare(ti.inputText, "abc")
        field(ti).forceActiveFocus()
        field(ti).selectAll()
        wait(30)
        keyClick(Qt.Key_Backspace)
        wait(40)
        compare(spy.inputExceed.count, 0, "变短永远合法")
        compare(ti.inputText, "")
        compare(spy.inputChange.count, 4)
        ti.destroy()
    }

    function test_maxLengthIgnoredWhenUnset() {
        const ti = make("TagInput { width: 400 }")
        const spy = spill(ti, ["inputExceed"])
        wait(50)
        typeInto(ti, "abcdefghij")
        compare(spy.inputExceed.count, 0)
        compare(ti.inputText, "abcdefghij")
        ti.destroy()
    }

    // ---- 受控 ----

    function test_valueControlledNeedsWriteBack() {
        const ti = make("TagInput { width: 400; defaultValue: ['x']; value: ['x'] }")
        const spy = spill(ti, ["change"])
        wait(50)
        typeInto(ti, "y")
        pressEnter(ti)
        compare(spy.change.count, 1)
        compare(spy.change.signalArguments[0][0].join(","), "x,y",
            "onChange 收到算出来的新数组")
        compare(ti.tags.join(","), "x", "使用方没写回，显示仍是 value")
        compare(hosts(ti).length, 1)
        // 受控期间官方根本不写 state：把 value 撤回收成非受控，看到的还是当初那份
        ti.value = undefined
        wait(30)
        compare(ti.tags.join(","), "x", "受控期间没往 _tags 里写过东西")
        compare(hosts(ti).length, 1)
        ti.destroy()
    }

    function test_valueControlledFollowsWriteBack() {
        const ti = make("TagInput { width: 400; value: ['x'] }")
        ti.onChange.connect((v) => {
            ti.value = v
        })
        wait(50)
        typeInto(ti, "y")
        pressEnter(ti)
        compare(ti.tags.join(","), "x,y")
        compare(hosts(ti).length, 2)
        ti.destroy()
    }

    function test_valueEmptyArrayIsControlledNotUncontrolled() {
        const ti = make("TagInput { width: 400; defaultValue: ['ignored']; value: [] }")
        wait(50)
        compare(ti.tags.length, 0, "value 给了空数组就是受控空值，defaultValue 不生效")
        compare(hosts(ti).length, 0)
        ti.destroy()
    }

    function test_inputValueControlledPushesAndReverts() {
        const ti = make("TagInput { width: 400; inputValue: 'abc' }")
        wait(50)
        compare(field(ti).text, "abc")
        compare(ti.inputText, "abc")
        typeInto(ti, "d")
        compare(ti.inputText, "abc", "没人接住 onInputChange 就退回受控值")
        compare(field(ti).text, "abc")
        ti.destroy()
    }

    function test_inputValueControlledFollowsHandler() {
        const ti = make("TagInput { width: 400; inputValue: 'abc' }")
        ti.onInputChange.connect((v) => {
            ti.inputValue = v
        })
        wait(50)
        typeInto(ti, "d")
        compare(ti.inputValue, "abcd")
        compare(field(ti).text, "abcd")
        ti.inputValue = "换"
        wait(40)
        compare(field(ti).text, "换", "外部改 inputValue 会推进输入框")
        ti.destroy()
    }

    // ---- showClear ----

    function test_clearButtonHoldsWidthOnlyOnHover() {
        const ti = make("TagInput { width: 400; showClear: true; defaultValue: ['抖音'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        const btn = one(ti, "clearBtn")
        compare(btn.width, 32)                  // $width-tagInput-clear-medium
        compare(ti.clearShown, true)
        compare(ti.clearActive, false, "没悬停时只是看不见，占位还在")
        const before = one(ti, "fieldHost").width
        mouseMove(ti, 200, 12)
        wait(60)
        compare(ti.clearActive, true)
        compare(one(ti, "fieldHost").width, before, "占位不变 → 输入区宽度不该跟着变")
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(60)
        compare(ti.clearActive, false)
        ti.destroy()
    }

    function test_clearHiddenWhenNothingInside() {
        const ti = make("TagInput { width: 400; showClear: true }")
        ti.x = 40
        ti.y = 40
        wait(50)
        mouseMove(ti, 200, 12)
        wait(60)
        compare(ti.clearActive, false, "空标签空输入时不亮")
        ti.destroy()
    }

    function test_clearIgnoredWhenDisabled() {
        const ti = make("TagInput { width: 400; showClear: true; defaultValue: ['a']; enabled: false }")
        ti.x = 40
        ti.y = 40
        wait(50)
        mouseMove(ti, 200, 12)
        wait(60)
        compare(ti.clearActive, false, "禁用时官方也不亮")
        ti.destroy()
    }

    function test_clearEmitsChangeOnly() {
        const ti = make("TagInput { width: 400; showClear: true; defaultValue: ['a', 'b'] }")
        const spy = spill(ti, ["change", "remove", "inputChange"])
        ti.x = 40
        ti.y = 40
        wait(50)
        typeInto(ti, "c")
        mouseMove(ti, 200, 12)
        wait(60)
        const btn = one(ti, "clearBtn")
        const at = btn.mapToItem(ti, btn.width / 2, btn.height / 2)
        mouseClick(ti, at.x, at.y)
        wait(60)
        compare(ti.tags.length, 0)
        compare(ti.inputText, "")
        compare(spy.change.count, 1, "官方清空只发一次 onChange")
        compare(spy.change.signalArguments[0][0].length, 0)
        compare(spy.remove.count, 0, "官方清空只发 onChange，不发 onRemove")
        ti.destroy()
    }

    // ---- maxTagCount / +N ----

    function test_maxTagCountCollapsesToShowPlusN() {
        const ti = make("TagInput { width: 400; maxTagCount: 2; defaultValue: ['抖音', '火山', '西瓜视频'] }")
        wait(50)
        compare(ti.collapsed, true)
        compare(ti.restCount, 1)
        const list = hosts(ti)
        compare(list.length, 2)
        const rest = one(ti, "restHost")
        compare(rest.visible, true)
        compare(rest.children[0].text, "+1")
        compare(ti.contentHeight, 28)
        // 正好等于 maxTagCount 不该折叠（官方是 tagsArray.length > maxTagCount）
        const exact = make("TagInput { width: 400; maxTagCount: 2; defaultValue: ['a', 'b'] }")
        wait(50)
        compare(exact.collapsed, false)
        compare(hosts(exact).length, 2)
        compare(one(exact, "restHost").visible, false)
        exact.destroy()
        ti.destroy()
    }

    // relayout() 要不要给 +N 排位置看的是 restHost.visible，而 visible 绑 restCount>0
    // 重算得更晚 —— 少了 restHost 自己那次 onVisibleChanged 补排，+N 会永远留在 (0,0)，
    // 直接盖在第一个标签上（TreeSelect「搜索框位置」那节就是这么露出来的）。
    function test_restTagIsLaidOutAfterTheLastTag() {
        const ti = make("TagInput { width: 400; maxTagCount: 2; defaultValue: ['aaa', 'bbb', 'ccc'] }")
        ti.x = 40
        ti.y = 40
        wait(80)
        const list = hosts(ti)
        compare(list.length, 2, "只画前两个")
        const rest = one(ti, "restHost")
        const field = one(ti, "fieldHost")
        compare(rest.visible, true)
        verify(rest.x > list[1].x, "+N 要排在最后一个标签之后")
        compare(rest.x, list[1].x + list[1].width + 4, "官方 -wrapper-tag 的 margin-right 4")
        compare(field.x, rest.x + rest.width + 4, "-n 自己也是 margin-right 4")
        ti.destroy()
    }

    // 自定义节点（renderTagItem）官方不带 -wrapper-tag 那层，横向外边距 0；
    // 嵌进 TreeSelect 才由外层传 2（.semi-treeselect-selection .semi-tag { margin: 1px 2px }）
    function test_customTagStrideUsesTagMarginX() {
        // 钩子组件必须自己声明每个入参（坑 81），否则注入 closeTag 会抛 QML Error
        const ti = make(`TagInput {
            width: 400
            defaultValue: ['a', 'b']
            renderTagItem: Component {
                Rectangle {
                    objectName: "myTag"
                    property var modelData: undefined
                    property int index: -1
                    property var closeTag: null
                    width: 30
                    height: 24
                    color: "transparent"
                }
            }
        }`)
        ti.x = 40
        ti.y = 40
        wait(80)
        const list = hosts(ti)
        compare(list.length, 2)
        compare(list[0].width, 30)
        compare(list[1].x, 30, "tagMarginX 默认 0：两个标签紧贴")
        compare(one(ti, "myTag").mapToItem(flow(ti), 0, 0).x, 0)
        ti.destroy()
        // 带边距的那档另开一个实例：在同一个已排好的实例上运行期改 tagMarginX，
        // 会让后面那条 Tooltip hover 用例红（实测两次都是这个组合触发的，跟断言无关），
        // 拆开建实例既避开这个耦合，也更接近真实用法（外层是一次传对）
        const wide = make(`TagInput {
            width: 400
            tagMarginX: 2
            defaultValue: ['a', 'b']
            renderTagItem: Component {
                Rectangle {
                    objectName: "myTag"
                    property var modelData: undefined
                    property int index: -1
                    property var closeTag: null
                    width: 30
                    height: 24
                    color: "transparent"
                }
            }
        }`)
        wide.x = 40
        wide.y = 90
        wait(80)
        const wideList = hosts(wide)
        compare(wideList[1].x, 34, "左右各 2 → 步长 30+4")
        compare(one(wide, "myTag").mapToItem(flow(wide), 0, 0).x, 2, "标签自己让出左外边距")
        wide.destroy()
    }

    function test_borderlessDropsTheBorderInset() {
        const bordered = make("TagInput { width: 300; defaultValue: ['a'] }")
        const flat = make("TagInput { width: 300; borderless: true; defaultValue: ['a'] }")
        wait(80)
        compare(flow(bordered).x, 1 + Theme.current.spacingExtraTight,
            "带框时那 1 是 .semi-tagInput 自己的 1px 边框")
        compare(flow(flat).x, Theme.current.spacingExtraTight,
            "borderless 时边框被外层覆盖成 hidden，不该再往里让 1")
        compare(flow(bordered).width, bordered.width - 2 * (1 + Theme.current.spacingExtraTight))
        compare(flow(flat).width, flat.width - 2 * Theme.current.spacingExtraTight)
        bordered.destroy()
        flat.destroy()
    }

    function test_plusNCountsAllHiddenTags() {
        const ti = make("TagInput { width: 400; maxTagCount: 2;"
            + " defaultValue: ['a', 'b', 'c', 'd', 'e'] }")
        wait(50)
        compare(one(ti, "restHost").children[0].text, "+3")
        compare(hosts(ti).length, 2)
        ti.destroy()
    }

    function test_clickExpandsRestTags() {
        const ti = make("TagInput { width: 400; maxTagCount: 2; defaultValue: ['抖音', '火山', '西瓜视频'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        compare(hosts(ti).length, 2)
        mouseClick(ti, 300, 12)
        wait(60)
        compare(ti.active, true)
        compare(ti.collapsed, false, "expandRestTagsOnClick 默认开：点一下全展开")
        compare(hosts(ti).length, 3)
        compare(one(ti, "restHost").visible, false)
        ti.destroy()
    }

    function test_expandRestTagsOnClickFalseKeepsCollapsed() {
        const ti = make("TagInput { width: 400; maxTagCount: 2; expandRestTagsOnClick: false;"
            + " defaultValue: ['抖音', '火山', '西瓜视频'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        mouseClick(ti, 300, 12)
        wait(60)
        compare(ti.active, true)
        compare(ti.collapsed, true)
        compare(hosts(ti).length, 2)
        ti.destroy()
    }

    function test_restTagsPopoverOpensOnHover() {
        const ti = make("TagInput { width: 400; maxTagCount: 2; defaultValue: ['抖音', '火山', '西瓜视频'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        const rest = one(ti, "restHost")
        const pop = ti._restPop
        verify(pop, "找不到 restPop")
        compare(pop.visible, false)
        mouseMove(ti, flow(ti).x + rest.x + 8, 12)
        wait(250)
        compare(pop.visible, true, "hover +N 应弹气泡")
        compare(pop.target, rest)
        compare(pop.position, Enums.Top)        // 官方默认 position: top
        compare(pop.showArrow, true, "官方 <Popover showArrow>")
        const inner = findAll(pop.contentItem, "tagLabel")
        compare(inner.length, 1, "气泡里列出剩下的标签")
        compare(inner[0].text, "西瓜视频")
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(250)
        compare(pop.visible, false)
        ti.destroy()
    }

    function test_restTagsPopoverPropsPositionIsHonoured() {
        const ti = make(`TagInput {
            width: 400
            maxTagCount: 1
            restTagsPopoverProps: ({ position: "rightTop" })
            defaultValue: ['抖音', '火山']
        }`)
        wait(50)
        compare(ti._restPop.position, Enums.RightTop)
        ti.destroy()
    }

    function test_showRestTagsPopoverFalseDisablesHoverPopover() {
        const ti = make("TagInput { width: 400; maxTagCount: 1; showRestTagsPopover: false;"
            + " defaultValue: ['抖音', '火山'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        const rest = one(ti, "restHost")
        compare(rest.visible, true)
        compare(rest.children[0].text, "+1")
        mouseMove(ti, flow(ti).x + rest.x + 8, 12)
        wait(250)
        compare(ti._restPop.visible, false)
        ti.destroy()
    }

    // ---- active 的开关 ----

    function test_clickOutsideClearsActive() {
        const ti = make("TagInput { width: 400; maxTagCount: 2; defaultValue: ['a', 'b', 'c'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        mouseClick(ti, 300, 12)
        wait(80)
        compare(ti.active, true)
        compare(hosts(ti).length, 3)
        mouseClick(testCase, 700, 600)
        wait(120)
        compare(ti.active, false, "点到框外官方会注销 clickOutside")
        compare(hosts(ti).length, 2, "重新折回 maxTagCount")
        ti.destroy()
    }

    function test_clickInsideOtherTagKeepsActive() {
        const ti = make("TagInput { width: 400; maxTagCount: 2; defaultValue: ['aaa', 'bbb', 'ccc'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        mouseClick(ti, 300, 12)
        wait(80)
        compare(ti.active, true)
        const tag = hosts(ti)[0].children[0]
        mouseClick(tag, 10, tag.height / 2)
        wait(80)
        compare(ti.active, true, "点框内的标签不算点到外面")
        ti.destroy()
    }

    // 官方 handleInputBlur（foundation.ts:209-216）只 setFocusing(false) + notifyBlur，
    // active 只由 clickOutside 收回（foundation.ts:274-278）。所以「焦点被程序拿走」
    // 跟「点到框外」不是一回事：前者多余标签还摊开着。
    function test_activeSurvivesProgrammaticBlur() {
        const a = make("TagInput { width: 300; x: 10; y: 10; maxTagCount: 1;"
            + " defaultValue: ['a', 'b', 'c'] }")
        const b = make("TagInput { width: 300; x: 10; y: 60; defaultValue: ['z'] }")
        wait(50)
        mouseClick(a, 250, 12)
        wait(80)
        compare(a.active, true)
        compare(hosts(a).length, 3)
        b.focusInput()
        wait(80)
        compare(a.focusing, false, "焦点确实被 b 拿走了")
        compare(a.active, true, "失焦不收回 active（只有 clickOutside 才收）")
        compare(hosts(a).length, 3, "三个标签仍是展开的")
        mouseClick(testCase, 700, 600)
        wait(120)
        compare(a.active, false, "这一下真点到框外了才收")
        compare(hosts(a).length, 1)
        a.destroy(); b.destroy()
    }

    // ---- 焦点管理 ----

    function test_focusAndBlurMethods() {
        const ti = make("TagInput { width: 400; defaultValue: ['a'] }")
        const spy = spill(ti, ["focused", "blurred"])
        ti.x = 40
        ti.y = 40
        wait(50)
        ti.focusInput()
        wait(60)
        compare(field(ti).activeFocus, true)
        compare(ti.active, true)
        compare(spy.focused.count, 1)
        ti.blurInput()
        wait(60)
        compare(field(ti).activeFocus, false)
        compare(ti.active, false, "官方 blur() 顺手把 active 关掉")
        compare(spy.blurred.count, 1)
        ti.destroy()
    }

    function test_focusIgnoredWhenDisabled() {
        const ti = make("TagInput { width: 400; enabled: false }")
        ti.x = 40
        ti.y = 40
        wait(50)
        ti.focusInput()
        wait(60)
        compare(field(ti).activeFocus, false)
        compare(ti.active, false)
        ti.destroy()
    }

    function test_autoFocusOnCompletion() {
        const ti = make("TagInput { width: 400; autoFocus: true }")
        wait(60)
        compare(field(ti).activeFocus, true)
        compare(ti.active, true)
        ti.destroy()
    }

    function test_autoFocusSkippedWhenDisabled() {
        const ti = make("TagInput { width: 400; autoFocus: true; enabled: false }")
        wait(60)
        compare(field(ti).activeFocus, false)
        compare(ti.active, false)
        ti.destroy()
    }

    function test_addOnBlurCreatesTag() {
        const ti = make("TagInput { width: 400; addOnBlur: true; defaultValue: ['a'] }")
        const spy = spill(ti, ["add", "blurred", "inputChange"])
        ti.x = 40
        ti.y = 40
        wait(50)
        typeInto(ti, "bc")
        ti.blurInput()
        wait(60)
        compare(ti.tags.join(","), "a,bc")
        compare(spy.add.count, 1)
        compare(spy.blurred.count, 1)
        compare(spy.inputChange.signalArguments[spy.inputChange.count - 1][0], "")
        ti.destroy()
    }

    function test_addOnBlurFalseLeavesText() {
        const ti = make("TagInput { width: 400; defaultValue: ['a'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        typeInto(ti, "bc")
        ti.blurInput()
        wait(60)
        compare(ti.tags.join(","), "a")
        compare(ti.inputText, "bc", "官方默认失焦不创建")
        ti.destroy()
    }

    function test_keyDownSignalCarriesKey() {
        const ti = make("TagInput { width: 400 }")
        const spy = spill(ti, ["keyDown"])
        wait(50)
        field(ti).forceActiveFocus()
        wait(30)
        keyClick(Qt.Key_A)
        wait(30)
        keyClick(Qt.Key_Return)
        wait(30)
        compare(spy.keyDown.count, 2)
        compare(spy.keyDown.signalArguments[0][0], Qt.Key_A)
        compare(spy.keyDown.signalArguments[1][0], Qt.Key_Return)
        ti.destroy()
    }

    // ---- 拖拽排序 ----

    function test_dragNeedsClickFirst() {
        const ti = make("TagInput { width: 400; draggable: true; allowDuplicates: false;"
            + " defaultValue: ['抖音', '火山'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        compare(ti.sortable, false, "没点之前不可拖")
        compare(hosts(ti)[0].children[0].prefixIcon, "")
        mouseClick(ti, 300, 12)
        wait(60)
        compare(ti.sortable, true)
        compare(hosts(ti)[0].children[0].prefixIcon, "handle", "拖拽态标签前面多一个 IconHandle")
        ti.destroy()
    }

    function test_dragReordersTags() {
        const ti = make("TagInput { width: 400; draggable: true; defaultValue: ['aaa', 'bbb', 'ccc'] }")
        const spy = spill(ti, ["change"])
        ti.x = 40
        ti.y = 40
        wait(50)
        mouseClick(ti, 300, 12)
        wait(60)
        const list = hosts(ti)
        const target = flow(ti).x + list[2].x + list[2].width + 10
        mousePress(ti, flow(ti).x + list[0].x + 10, 12, Qt.LeftButton)
        wait(20)
        // 一帧 move 只够跨过阈值让 DragHandler 抓到（active 在事件末尾才置真），
        // translation 要等下一帧才更新 —— 真实鼠标本来就有几十帧，这里补两帧。
        mouseMove(ti, flow(ti).x + list[1].x + 10, 12, 20, Qt.LeftButton)
        wait(20)
        mouseMove(ti, target, 12, 20, Qt.LeftButton)
        wait(60)
        compare(ti.dragIndex, 0)
        compare(ti.dropIndex, 3)
        compare(one(ti, "dropBar").visible, true, "拖拽时要有落点竖线")
        mouseRelease(ti, target, 12, Qt.LeftButton)
        wait(60)
        compare(ti.tags.join(","), "bbb,ccc,aaa", "arrayMove(0, 2)")
        compare(spy.change.count, 1)
        compare(ti.dragIndex, -1)
        compare(ti.active, true, "落点在框内，clickOutside 那条不能把 active 收掉")
        compare(ti.sortable, true, "收起了就拖不动第二次")
        compare(hosts(ti).length, 3, "仍然是展开态")
        compare(one(ti, "dropBar").visible, false)
        ti.destroy()
    }

    function test_dragDisabledWhenNotDraggable() {
        const ti = make("TagInput { width: 400; defaultValue: ['aaa', 'bbb'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        mouseClick(ti, 300, 12)
        wait(60)
        compare(ti.sortable, false)
        const list = hosts(ti)
        mousePress(ti, flow(ti).x + list[0].x + 10, 12, Qt.LeftButton)
        wait(20)
        mouseMove(ti, flow(ti).x + 150, 12, 20, Qt.LeftButton)
        wait(20)
        mouseMove(ti, flow(ti).x + 300, 12, 20, Qt.LeftButton)
        wait(40)
        mouseRelease(ti, flow(ti).x + 300, 12, Qt.LeftButton)
        wait(40)
        compare(ti.tags.join(","), "aaa,bbb", "没开 draggable 就只是选中")
        ti.destroy()
    }

    // ---- 截断提示 ----

    function test_longTagTruncatesAndTooltips() {
        const ti = make("TagInput { width: 140; defaultValue: ['一二三四五六七八九十'] }")
        ti.x = 40
        ti.y = 40
        wait(60)
        const tag = hosts(ti)[0].children[0]
        compare(tag.textClipped, true, "超过一行宽度要截断")
        verify(tag.implicitWidth <= flow(ti).width, "标签最宽只能到容器内容宽")
        const tip = ti._contentTip
        verify(tip, "找不到 contentTip")
        compare(tip.visible, false)
        mouseMove(ti, 30, 12)
        // Tooltip 自己还有 50ms 的 mouseEnterDelay（官方 numbers.MOUSE_ENTER_DELAY），
        // 悬停要下一帧才到 —— 死等固定毫秒会抢跑
        tryVerify(function () { return tip.visible === true; }, 1500,
            "hover 截断的标签要弹全文")
        compare(tip.text, "一二三四五六七八九十")
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(400)
        compare(tip.visible, false)
        ti.destroy()
    }

    function test_shortTagDoesNotTooltip() {
        const ti = make("TagInput { width: 400; defaultValue: ['抖音'] }")
        ti.x = 40
        ti.y = 40
        wait(60)
        compare(hosts(ti)[0].children[0].textClipped, false)
        mouseMove(ti, 20, 12)
        wait(400)
        compare(ti._contentTip.visible, false, "没截断就不该提示")
        ti.destroy()
    }

    function test_showContentTooltipFalseSuppresses() {
        const ti = make("TagInput { width: 140; showContentTooltip: false;"
            + " defaultValue: ['一二三四五六七八九十'] }")
        ti.x = 40
        ti.y = 40
        wait(60)
        compare(hosts(ti)[0].children[0].textClipped, true)
        mouseMove(ti, 30, 12)
        wait(400)
        compare(ti._contentTip.visible, false)
        ti.destroy()
    }

    function test_showContentTooltipPopoverType() {
        const ti = make(`TagInput {
            width: 140
            showContentTooltip: ({ type: "popover" })
            defaultValue: ['一二三四五六七八九十']
        }`)
        ti.x = 40
        ti.y = 40
        wait(60)
        compare(ti.tooltipIsPopover, true)
        mouseMove(ti, 30, 12)
        wait(400)
        const pop = ti._contentPop
        verify(pop, "找不到 contentPop")
        compare(pop.visible, true)
        compare(pop.text, "一二三四五六七八九十")
        compare(ti._contentTip.visible, false)
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        tryVerify(function () { return pop.visible === false; }, 1500,
            "指针移出截断标签要收掉 popover 档的提示")
        ti.destroy()
    }

    // ---- 前缀 / 后缀 ----

    function test_prefixIconSlotIs32Wide() {
        const ti = make("TagInput { width: 400; prefixIcon: 'vigo_logo' }")
        wait(50)
        compare(one(ti, "leftSlot").width, 32)  // 8 + 16 + 8（$spacing-tight 两侧）
        compare(flow(ti).x, 1 + 32 + 4)
        compare(one(ti, "fieldHost").x, 0)
        fuzzyCompare(one(ti, "fieldHost").width, 390 - 32, 0.6)
        ti.destroy()
    }

    function test_prefixTextSlotAddsTwelveOnEachSide() {
        const ti = make("TagInput { width: 400; prefix: 'Prefix' }")
        wait(50)
        const text = findAll(ti, "prefixText")
        compare(text.length, 1)
        compare(one(ti, "leftSlot").width, text[0].implicitWidth + 24)
        compare(text[0].font.weight, Font.Bold)  // $font-tagInput_prefix_suffix-fontWeight
        compare(text[0].color.toString(), Theme.current.colorText2.toString())
        ti.destroy()
    }

    function test_insetLabelSharesPrefixSlot() {
        const ti = make("TagInput { width: 400; insetLabel: 'insetLabel' }")
        wait(50)
        compare(ti.prefixTextShown, true)
        const text = findAll(ti, "prefixText")
        compare(text[0].text, "insetLabel")
        compare(one(ti, "leftSlot").width, text[0].implicitWidth + 24)
        ti.destroy()
    }

    function test_prefixWinsOverInsetLabel() {
        const ti = make("TagInput { width: 400; prefix: 'Prefix'; insetLabel: 'insetLabel' }")
        wait(50)
        compare(ti.prefixTextValue, "Prefix", "官方 labelNode = prefix || insetLabel")
        ti.destroy()
    }

    function test_customNodePrefixHasNoMargins() {
        const ti = make(`TagInput {
            width: 400
            prefix: Component { Rectangle { width: 40; height: 10 } }
        }`)
        wait(50)
        compare(ti.prefixIsNode, true)
        compare(one(ti, "leftSlot").width, 40, "自定义节点左右间隔 0")
        ti.destroy()
    }

    function test_suffixIconAndText() {
        const ti = make("TagInput { width: 400; suffixIcon: 'gift' }")
        wait(50)
        compare(one(ti, "rightSlot").width, 32)
        ti.destroy()
        const t = make("TagInput { width: 400; suffix: 'Suffix' }")
        wait(50)
        const text = findAll(t, "suffixText")
        compare(one(t, "rightSlot").width, text[0].implicitWidth + 24)
        t.destroy()
    }

    function test_clearSitsInsideSuffix() {
        const ti = make("TagInput { width: 400; showClear: true; suffix: 'Suffix'; defaultValue: ['a'] }")
        wait(50)
        const right = one(ti, "rightSlot")
        const clear = one(ti, "clearBtn")
        const suffix = one(ti, "suffixBox")
        compare(clear.x, 0, "官方 flex 顺序 prefix | wrapper | clearBtn | suffix")
        compare(suffix.x, clear.width)
        compare(right.width, 32 + suffix.width)
        ti.destroy()
    }

    // ---- renderTagItem ----

    function test_renderTagItemInjectsParams() {
        const ti = make(`TagInput {
            width: 400
            defaultValue: ['甲', '乙']
            renderTagItem: Component {
                Rectangle {
                    property var modelData
                    property int index
                    property var closeTag

                    implicitWidth: 60
                    implicitHeight: 32
                    width: 60
                    height: 32
                    color: "transparent"

                    Text {
                        objectName: "chipText"
                        text: parent.index + ":" + parent.modelData
                    }
                }
            }
        }`)
        wait(60)
        const list = hosts(ti)
        compare(list.length, 2)
        const texts = findAll(ti, "chipText")
        compare(texts.length, 2)
        compare(texts[0].text, "0:甲")
        compare(texts[1].text, "1:乙")
        // 自定义节点官方不带 -wrapper-tag，所以没有 4 的右外边距
        fuzzyCompare(list[1].x, 60, 0.6)
        compare(ti.contentHeight, 32)
        compare(ti.implicitHeight, 34, "32 高的自定义节点把外框撑到 34")
        ti.destroy()
    }

    function test_renderTagItemCloseTagRemoves() {
        const ti = make(`TagInput {
            width: 400
            defaultValue: ['甲', '乙']
            renderTagItem: Component {
                Rectangle {
                    property var modelData
                    property int index
                    property var closeTag

                    implicitWidth: 60
                    implicitHeight: 32
                    width: 60
                    height: 32
                    color: "transparent"

                    MouseArea {
                        objectName: "chipClose"
                        anchors.fill: parent
                        onClicked: parent.closeTag()
                    }
                }
            }
        }`)
        const spy = spill(ti, ["remove", "change"])
        wait(60)
        const closes = findAll(ti, "chipClose")
        compare(closes.length, 2)
        mouseClick(closes[0], 10, 10)
        wait(60)
        compare(ti.tags.join(","), "乙")
        compare(spy.remove.signalArguments[0][0], "甲")
        compare(spy.remove.signalArguments[0][1], 0)
        // 新追加的那枚 index 从 0 起就没变过，closeTag 只可能由 Loader.onItemChanged 注入
        // （typeInto 只能打 ASCII：QTest::keyClick(char) 撞上非 ASCII 直接 ASSERT(false) 崩掉）
        typeInto(ti, "c")
        pressEnter(ti)
        wait(60)
        compare(ti.tags.join(","), "乙,c")
        const more = findAll(ti, "chipClose")
        compare(more.length, 2)
        mouseClick(more[1], 10, 10)
        wait(60)
        compare(ti.tags.join(","), "乙", "新建标签的 closeTag 也得注入上")
        ti.destroy()
    }

    // ---- 外观：底 / 描边随状态与校验态 ----

    function test_surfaceFollowsState() {
        const ti = make("TagInput { width: 400; defaultValue: ['a'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        const box = one(ti, "tagInputBox")
        compare(box.color.toString(), Theme.current.colorFill0.toString())
        compare(box.border.color, Qt.rgba(0, 0, 0, 0))
        compare(box.radius, Theme.current.radiusSmall)
        mouseMove(ti, 200, 12)
        wait(250)
        compare(box.color.toString(), Theme.current.colorFill1.toString())
        compare(box.border.color, Qt.rgba(0, 0, 0, 0), "悬浮也没有描边")
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(250)
        field(ti).forceActiveFocus()
        wait(250)
        compare(box.border.color.toString(), Theme.current.colorFocusBorder.toString())
        compare(box.color.toString(), Theme.current.colorFill0.toString(),
            "$color-tagInput_default-bg-focus = fill-0")
        ti.destroy()
    }

    function test_validateStatusSurfaceAndBorder() {
        const warn = make("TagInput { width: 400; validateStatus: Enums.StatusWarning; defaultValue: ['a'] }")
        const err = make("TagInput { width: 400; validateStatus: Enums.StatusDanger; defaultValue: ['a'] }")
        warn.x = 40
        warn.y = 40
        err.x = 40
        err.y = 90
        wait(50)
        const wb = one(warn, "tagInputBox")
        const eb = one(err, "tagInputBox")
        compare(wb.color.toString(), Theme.current.colorWarningLightDefault.toString())
        compare(wb.border.color.toString(), Theme.current.colorWarningLightDefault.toString(),
            "warning 平时就带同色描边（tagInput.scss:77-89）")
        compare(eb.color.toString(), Theme.current.colorDangerLightDefault.toString())
        mouseMove(warn, 200, 12)
        wait(250)
        compare(one(warn, "tagInputBox").border.color.toString(),
            Theme.current.colorWarningLightHover.toString())
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(250)
        field(warn).forceActiveFocus()
        wait(250)
        compare(one(warn, "tagInputBox").border.color.toString(), Theme.current.colorWarning.toString(),
            "聚焦换实色")
        compare(one(warn, "tagInputBox").color.toString(),
            Theme.current.colorWarningLightDefault.toString())
        warn.destroy(); err.destroy()
    }

    function test_disabledSurface() {
        const ti = make("TagInput { width: 400; enabled: false; defaultValue: ['a'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        const box = one(ti, "tagInputBox")
        compare(box.color.toString(), Theme.current.colorDisabledFill.toString())
        compare(box.border.color, Qt.rgba(0, 0, 0, 0), "禁用只换背景，没有 disabled-border")
        compare(field(ti).enabled, false)
        mouseMove(ti, 200, 12)
        wait(250)
        compare(one(ti, "tagInputBox").color.toString(), Theme.current.colorDisabledFill.toString(),
            "禁用不响应悬浮")
        ti.destroy()
    }

    function test_fieldFollowsCustomize() {
        const ti = make("TagInput { width: 400; defaultValue: ['a'] }")
        ti.x = 40
        ti.y = 40
        wait(50)
        const box = one(ti, "tagInputBox")
        const before = box.color.toString()
        Theme.customize({ colorFill0: "#7c3aed" })
        wait(250)
        compare(box.color.toString(), "#7c3aed", "底色要跟着自定义令牌走")
        verify(box.color.toString() !== before)
        Theme.reset()
        ti.destroy()
    }

    // ---- 其它 ----

    function test_placeholderOnlyWhenNoTags() {
        const ti = make("TagInput { width: 400; placeholder: '请输入...' }")
        wait(50)
        const ph = one(ti, "placeholder")
        compare(ph.text, "请输入...")
        compare(ph.visible, true)
        ti.defaultValue = ["a"]
        wait(50)
        compare(ph.visible, false, "官方 tags 非空时不再把 placeholder 交给 Input")
        ti.destroy()
    }

    function test_defaultValueIsCopiedNotAliased() {
        const ti = make("TagInput { width: 400; defaultValue: testCase.probeSeed }")
        wait(50)
        compare(ti.tags.join(","), "a,b")
        // 内部数组不能是调用方那个的别名，否则任何原地改都会串出去
        verify(ti.tags !== testCase.probeSeed, "_tags 必须是 defaultValue 的副本")
        const tag = hosts(ti)[0].children[0]
        mouseClick(tag, tag.width - 8, tag.height / 2)     // 真的去点叉
        wait(50)
        compare(testCase.probeSeed.length, 2, "内部改动不能改坏调用方传进来的数组")
        compare(ti.tags.join(","), "b")
        ti.destroy()
    }

    function test_cornerRadiusAliasesReachBox() {
        const ti = make("TagInput { width: 400 }")
        wait(30)
        compare(ti.radius, Theme.current.radiusSmall)
        ti.topLeftRadius = 0
        compare(one(ti, "tagInputBox").topLeftRadius, 0)
        ti.destroy()
    }

    function test_removedSignalNamesMatchOfficialCallbacks() {
        // 官方回调 onChange / onAdd / onRemove / onInputChange / onExceed /
        // onInputExceed / onKeyDown 都得能直接挂上
        const ti = make("TagInput { width: 400 }")
        const hits = []
        ti.onChange.connect(() => hits.push("change"))
        ti.onAdd.connect(() => hits.push("add"))
        ti.onRemove.connect(() => hits.push("remove"))
        ti.onInputChange.connect(() => hits.push("inputChange"))
        ti.onExceed.connect(() => hits.push("exceed"))
        ti.onInputExceed.connect(() => hits.push("inputExceed"))
        ti.onKeyDown.connect(() => hits.push("keyDown"))
        wait(50)
        ti.max = 0
        typeInto(ti, "a")
        pressEnter(ti)
        keyClick(Qt.Key_Escape)
        wait(40)
        verify(hits.indexOf("exceed") >= 0, "onExceed 挂不上")
        verify(hits.indexOf("inputChange") >= 0, "onInputChange 挂不上")
        verify(hits.indexOf("keyDown") >= 0, "onKeyDown 挂不上")
        verify(hits.indexOf("change") < 0, "max=0 一个都加不上，不该发 onChange")
        ti.max = -1
        typeInto(ti, "b")
        pressEnter(ti)
        verify(hits.indexOf("change") >= 0, "onChange 挂不上")
        verify(hits.indexOf("add") >= 0, "onAdd 挂不上")
        ti.handleTagClose(0)
        wait(30)
        verify(hits.indexOf("remove") >= 0, "onRemove 挂不上")
        ti.destroy()
    }
}
