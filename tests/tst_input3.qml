import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "InputPro2"
    when: windowShown
    width: 400
    height: 400

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    // ---------------- AutoComplete ----------------

    function test_autoCompleteFiltersByKeyword() {
        const ac = make("AutoComplete { filterLocal: true }")
        ac.dataList = ["apple", "apricot", "banana"]
        ac.value = "ap"
        compare(ac.filtered.length, 2)
        // filtered 必须是稳定引用（每项算一次），否则列表宽度会塌成 0
        verify(ac.filtered === ac.filtered, "filtered 不应每次返回新数组")
        ac.value = ""
        compare(ac.filtered.length, 3)
        ac.value = "zzz"
        compare(ac.filtered.length, 0)
        ac.destroy()
    }

    function test_autoCompleteIsCaseInsensitive() {
        const ac = make("AutoComplete { filterLocal: true }")
        ac.dataList = ["Apple", "Banana"]
        ac.value = "app"
        compare(ac.filtered.length, 1)
        ac.destroy()
    }

    // 官方几何量自浏览器真实 DOM（.semi-popover-wrapper > .semi-autocomplete-option-list）：
    //   选项行高 = line-height 20 + 上下 padding 各 8 = 36（autoComplete/option.scss）
    //   列表容器四边内缩 0（$spacing-autoComplete_option_list-padding*），
    //   上下那 4px 在选项的 :first-of-type / :last-of-type margin 上（Select 里同名规则被注释了）
    //   3 项时弹层总高实测 116 = 4 + 3×36 + 4
    function test_autoCompleteOptionMetrics() {
        const ac = make("AutoComplete { filterLocal: true }")
        compare(ac.optionHeight, 36)
        compare(ac._popup.padding, 0, "列表容器不该自己内缩，那 4px 在选项 margin 上")
        ac.dataList = ["apple", "apricot", "api"]
        ac.value = "ap"
        compare(ac.filtered.length, 3)
        // 取 3 行是故意的：两行时旧的 32×2 + 上下各 4 也等于 72，断言会假过
        compare(ac._popup.implicitHeight, 3 * 36 + 2 * 4)
        ac.value = "zzz"
        compare(ac._popup.implicitHeight, 36 + 2 * 4, "空态也是一条选项行")
        ac.destroy()
    }

    function test_autoCompleteDropdownInsets() {
        const ac = make("AutoComplete { }")
        ac.dataList = ["apple", "apricot"]
        ac.value = "ap"
        ac.open()
        wait(50)
        const kids = ac._popup.contentItem.children
        const top = kids.filter((it) => it.objectName === "listInsetTop")
        const bottom = kids.filter((it) => it.objectName === "listInsetBottom")
        compare(top.length, 1, "缺首行 4px margin-top")
        compare(bottom.length, 1, "缺末行 4px margin-bottom")
        compare(top[0].height, Theme.current.spacingExtraTight)
        compare(bottom[0].height, Theme.current.spacingExtraTight)
        ac.destroy()
    }

    // 列表 maxHeight 300（autoComplete/index.tsx defaultProps，Select 是 270）。
    // 光把弹层裁到 300 不够 —— 超出那几行必须还能滚到，否则等于够不着。
    function test_autoCompleteDropdownCapsAndScrolls() {
        const ac = make("AutoComplete { }")
        const many = []
        for (let i = 0; i < 13; i++)
            many.push("item" + i)
        ac.dataList = many
        ac.value = "item"
        compare(ac.filtered.length, 13)
        compare(ac._popup.implicitHeight, 300)
        ac.open()
        wait(50)
        const list = ac._popup.contentItem.children
            .filter((it) => it.objectName === "optionList")
        compare(list.length, 1)
        verify(list[0].contentHeight > list[0].height, "内容超出可视区才谈得上滚")
        verify(list[0].interactive, "超上限的候选必须可滚，不能裁掉够不着")
        ac.destroy()
    }

    function test_autoCompletePickSetsValue() {
        const ac = make("AutoComplete { }")
        ac.dataList = ["apple"]
        ac.pick("apple")
        compare(ac.value, "apple")
        ac.destroy()
    }

    // 外部（受控写法、官方 defaultValue 那类）改 value 不该被当成「用户在打字」。
    // 不挡的话：官方「校验状态」那三个预置 value 的 demo 一打开页面就弹三个「无匹配结果」，
    // 链路是 onValueChanged → input.text → Input.onTextChanged → popup.open()
    function test_autoCompleteProgrammaticValueDoesNotOpen() {
        const ac = make('AutoComplete { value: "ies" }')
        wait(50)
        compare(ac._input.input.text, "ies", "值还是要同步进输入框")
        verify(!ac._popup.visible, "外部设 value 不该弹下拉")

        ac._input.input.text = "ies2"          // 模拟用户打字
        wait(50)
        verify(ac._popup.visible, "用户打字才该弹下拉")
        ac.destroy()
    }

    // 官方 AutoComplete 不在本地筛 —— data 给什么显示什么，过滤是调用方 onSearch 的事。
    // 这条盯的是默认值：把 filterLocal 默认写成 true，远程搜索那类数据会被二次筛空。
    function test_autoCompleteShowsDataAsGiven() {
        const ac = make("AutoComplete { }")
        ac.dataList = ["选择器", "输入框", "表单"]
        ac.value = "sel"
        compare(ac.filterLocal, false)
        compare(ac.filtered.length, 3, "默认不该按输入过滤")
        ac.destroy()
    }

    // data 收对象数组时，每个读取点都要抹平（坑 41）：列表显示 label，
    // 回填输入框是 option.value，除非给了 renderSelectedItem
    function test_autoCompleteObjectOptions() {
        const ac = make("AutoComplete { }")
        const opt = { label: "xiakeman@example.com", value: "夏可漫" }
        ac.dataList = [opt]
        compare(ac.optionLabel(opt), "xiakeman@example.com")
        compare(ac.optionValue(opt), "夏可漫")
        ac.pick(opt)
        compare(ac.value, "夏可漫")

        const custom = make("AutoComplete { renderSelectedItem: (item) => item.label }")
        custom.dataList = [opt]
        custom.pick(opt)
        compare(custom.value, "xiakeman@example.com")
        ac.destroy(); custom.destroy()
    }

    function test_autoCompleteTriggerPassthrough() {
        const ac = make('AutoComplete { prefixIcon: "search"; suffixIcon: "link"; '
            + "showClear: true; validateStatus: Enums.StatusDanger; position: Enums.Top }")
        compare(ac._input.prefixIcon, "search")
        compare(ac._input.suffixIcon, "link")
        compare(ac._input.showClear, true)
        compare(ac._input.validateStatus, Enums.StatusDanger)
        compare(ac._popup.placement, Enums.Top)
        ac.destroy()
    }

    // 加载态是 .semi-autocomplete-loading-wrapper：height 20 + 上下 padding 各 8 = 36，
    // 且它不是 .semi-autocomplete-option —— 那 4px 内缩不该出现
    function test_autoCompleteLoadingRow() {
        const ac = make("AutoComplete { loading: true }")
        ac.dataList = ["a", "b"]
        ac.open()
        wait(50)
        const kids = ac._popup.contentItem.children
        const loadingRow = kids.filter((it) => it.objectName === "loadingRow")
        const list = kids.filter((it) => it.objectName === "optionList")
        compare(loadingRow.length, 1)
        verify(loadingRow[0].visible, "loading 时该出加载条")
        verify(!list[0].visible, "loading 时列表要让位")
        compare(ac._popup.implicitHeight, 36)
        ac.destroy()
    }

    function test_autoCompleteEmptyContent() {
        const ac = make('AutoComplete { emptyContent: Component { Item { width: 300; height: 180 } } }')
        ac.dataList = []
        ac.open()
        wait(50)
        const kids = ac._popup.contentItem.children
        const empty = kids.filter((it) => it.objectName === "emptyContent")
        compare(empty.length, 1)
        verify(empty[0].visible, "传了 emptyContent 就该显示它")
        compare(ac._popup.implicitHeight, 180, "空内容自带高度，且没有选项的 4px 内缩")
        ac.destroy()
    }

    // strict 是本库自有开关。两条一起写，才能证明变量真的是 strict 而不是别的
    function test_autoCompleteStrictClearsNonCandidate() {
        const decoy = make("TextInput { activeFocusOnTab: true; width: 10; height: 10 }")

        const strict = make("AutoComplete { strict: true; dataList: ['apple'] }")
        strict._input.input.forceActiveFocus()
        wait(50)
        strict._input.input.text = "zzz"
        wait(50)
        compare(strict.value, "zzz")
        decoy.forceActiveFocus()
        wait(50)
        compare(strict.value, "", "strict 失焦要把不在候选里的输入清掉")

        const loose = make("AutoComplete { dataList: ['apple'] }")
        loose._input.input.forceActiveFocus()
        wait(50)
        loose._input.input.text = "zzz"
        wait(50)
        decoy.forceActiveFocus()
        wait(50)
        compare(loose.value, "zzz", "没开 strict 就不该清")

        strict.destroy(); loose.destroy(); decoy.destroy()
    }

    // ---------------- HotKeys ----------------

    function test_hotKeysHeight() {
        const normal = make('HotKeys { keys: ["Ctrl", "S"] }')
        const small = make('HotKeys { keys: ["Ctrl"]; size: Enums.Small }')
        compare(normal.keyHeight, 22)
        compare(small.keyHeight, 18)
        normal.destroy(); small.destroy()
    }

    function test_hotKeysEmpty() {
        const hk = make("HotKeys { }")
        compare(hk.keys.length, 0)
        hk.destroy()
    }

    // ---------------- ColorPicker ----------------

    function test_colorPickerDefaultPanelLayout() {
        const cp = make("ColorPicker { }")
        compare(cp.areaWidth, 280)
        compare(cp._area.height, 280)
        // 色相条上边距 6、高 10；透明度条同上；手输区再 8
        compare(cp._hue.y, 286)
        compare(cp._hue.height, 10)
        compare(cp._alpha.y, 302)
        compare(cp._dataPart.y, 320)
        compare(cp._dataPart.height, 24)
        compare(cp.implicitHeight, 344)
        compare(cp.currentColor.hex, "#39c5bb")
        cp.destroy()
    }

    function test_colorPickerHandleGeometry() {
        const cp = make("ColorPicker { }")
        // 官方：x = s/100*width - handleSize/2，y = (1 - v/100)*height - handleSize/2
        compare(Math.round(cp.areaHandleX * 10) / 10, 188.8)
        compare(Math.round(cp.areaHandleY * 10) / 10, 54.4)
        compare(Math.round(cp.hueHandleX * 10) / 10, 127.9)
        compare(cp.alphaHandleX, 271)
        compare(cp._areaHandle.width, 20)
        compare(cp._areaHandle.border.width, 2)
        compare(cp._areaHandle.border.color.toString(), Theme.current.colorWhite.toString())
        compare(cp._hueHandle.width, 18)
        // 18 的把手居中在 10 高的轨道上，上下各溢出 4
        compare(cp._hueHandle.y, -4)
        cp.destroy()
    }

    function test_colorPickerAreaDragIgnoresOutside() {
        const cp = make("ColorPicker { }")
        cp.areaMove(0, 0)
        compare(cp.currentColor.hex, "#ffffff")
        compare(cp.currentColor.hsva.s, 0)
        compare(cp.currentColor.hsva.v, 100)
        cp.areaMove(280, 280)
        compare(cp.currentColor.hex, "#000000")
        // mousemove 挂在取色区上，指针跑出去就不再更新（foundation.ts:164-179）
        cp.areaMove(300, 10)
        compare(cp.currentColor.hex, "#000000")
        cp.destroy()
    }

    function test_colorPickerSlidersClampAtEnds() {
        const cp = make("ColorPicker { }")
        cp.hueMove(280)
        compare(cp.currentColor.hsva.h, 360)
        cp.hueMove(-100)
        compare(cp.currentColor.hsva.h, 0)
        cp.alphaMove(140)
        compare(cp.currentColor.hsva.a, 0.5)
        // 带 alpha 的 hex 是 8 位，末两位 = round(a*255) 的十六进制
        compare(cp.currentColor.hex.length, 9)
        compare(cp.currentColor.hex.slice(-2), "80")
        cp.alphaMove(999)
        compare(cp.currentColor.hsva.a, 1)
        compare(cp.currentColor.hex.length, 7)
        cp.destroy()
    }

    function test_colorPickerAlphaOffDropsSliderAndPinsAlpha() {
        const cp = make("ColorPicker { alpha: false }")
        compare(cp._alpha.visible, false)
        // 少一条 6 + 10 的透明度条
        compare(cp.implicitHeight, 328)
        cp.handleChangeA(0.5)
        compare(cp.currentColor.hsva.a, 1)
        compare(cp.currentColor.hex.length, 7)
        cp.destroy()
    }

    function test_colorPickerHsvaConversionMatchesFoundation() {
        const cp = make("ColorPicker { }")
        cp.handleChange({h: 176, s: 71, v: 77, a: 1}, "hsva")
        compare(cp.currentColor.rgba.r, 57)
        // 官方 defaultProps 那串字面量写的是 197 / #39c5bb，但 convert.ts 的 hsvaToRgba
        // 按 176,71,77 算出来是 196（index.md:72 自己就说了「部分格式之间存在理论误差」）。
        // 这里钉的是换算结果，不是那串手写字面量。
        compare(cp.currentColor.rgba.g, 196)
        compare(cp.currentColor.rgba.b, 187)
        compare(cp.currentColor.hex, "#39c4bb")
        cp.handleChange({r: 245, g: 63, b: 63, a: 1}, "rgba")
        compare(cp.currentColor.hex, "#f53f3f")
        compare(cp.currentColor.hsva.h, 0)
        // 六个扇区各钉一个纯色（s=v=100 时取整没有歧义），hsvaToRgba 那张
        // [v,c,b,b,d,v] 的表错任何一格都会掉在这里
        const pure = [
            [0, "#ff0000"], [60, "#ffff00"], [120, "#00ff00"],
            [180, "#00ffff"], [240, "#0000ff"], [300, "#ff00ff"]
        ]
        for (let i = 0; i < pure.length; ++i) {
            cp.handleChange({h: pure[i][0], s: 100, v: 100, a: 1}, "hsva")
            compare(cp.currentColor.hex, pure[i][1])
        }
        cp.destroy()
    }

    function test_colorPickerFormatSwitchRewritesInput() {
        const cp = make("ColorPicker { }")
        cp.handleChange("#ff0000", "hex")
        compare(cp._hexField.text, "#ff0000")
        // 换格式只重算显示那一段（DataPartFoundation.handleFormatChange 只 setState，
        // componentDidUpdate 再把 inputValue 顶过去），不能当成用户改了色去通知
        let notified = 0
        cp.changed.connect(() => { notified += 1 })
        cp.format = Enums.FormatRgba
        compare(cp._hexField.text, "255,0,0")
        cp.format = Enums.FormatHsva
        compare(cp._hexField.text, "0,100,100")
        cp.format = Enums.FormatHex
        compare(cp._hexField.text, "#ff0000")
        compare(notified, 0)
        cp.destroy()
    }

    function test_colorPickerTypingCommitsOnlyValidValues() {
        const cp = make("ColorPicker { }")
        let commits = 0
        cp.changed.connect(() => { commits += 1 })
        cp._hexField.text = "#00ff00"
        compare(cp.currentColor.hex, "#00ff00")
        compare(commits, 1)
        // 不合法（6~8 位十六进制都不到）时不改色、不通知，但用户打的字要留着
        cp._hexField.text = "#00f"
        compare(cp.currentColor.hex, "#00ff00")
        compare(cp._hexField.text, "#00f")
        cp._hexField.text = "1,2,3"
        compare(cp._hexField.text, "1,2,3")
        compare(commits, 1)
        cp.destroy()
    }

    function test_colorPickerAlphaNumberField() {
        const cp = make("ColorPicker { }")
        compare(cp._numberField.width, 58)
        cp.alphaMove(70)
        compare(cp.currentColor.hsva.a, 0.25)
        compare(cp._numberField.value, 25)
        cp.destroy()
    }

    function test_colorPickerAlphaNumberFollowsFormat() {
        // DataPart/index.tsx:86-104：百分比框按当前格式回灌，三条路的取整各不相同
        const rgbaMode = make("ColorPicker { defaultFormat: Enums.FormatRgba }")
        rgbaMode.handleChange({h: 176, s: 1, v: 100, a: 1}, "hsva")
        compare(rgbaMode.currentColor.hsva.h, 176)
        rgbaMode.handleNumberChange(0.5)
        // rgba 格式是把 rgb 重新换算一遍 hsva：近灰色（252,255,255）反算回来 h 顶到 180。
        // 走透明度条那条 handleChangeA 会原样留着 176，这里就是用来钉住这个区别的。
        compare(rgbaMode.currentColor.hsva.h, 180)
        compare(rgbaMode.currentColor.hex, "#fcffff80")
        rgbaMode.destroy()

        // hsva 格式是先取 hsva(176,71,77) 再反算 rgb，绿分量比字面量少 1
        const hsvaMode = make("ColorPicker { defaultFormat: Enums.FormatHsva }")
        hsvaMode.handleNumberChange(0.5)
        compare(hsvaMode.currentColor.hex, "#39c4bb80")
        compare(hsvaMode.currentColor.rgba.g, 196)
        hsvaMode.destroy()

        // hex 格式绕一圈十六进制，a 变成 128/255；透明度条那条 handleChangeA 才是精确的 0.5
        const hexMode = make("ColorPicker { }")
        hexMode.handleNumberChange(0.5)
        compare(Math.round(hexMode.currentColor.rgba.a * 10000) / 10000, 0.502)
        compare(hexMode.currentColor.hex, "#39c5bb80")
        hexMode.alphaMove(140)
        compare(hexMode.currentColor.rgba.a, 0.5)
        hexMode.destroy()
    }

    function test_colorPickerInputGroupLayout() {
        const cp = make("ColorPicker { }")
        compare(cp._demoBlock.width, 20)
        compare(cp._demoBlock.radius, 4)
        compare(cp._group.x, 24)
        // 官方 DOM 实测：dataPart 280 = 色块 20 + 4 + 组 232 + 滴管 24
        compare(cp._group.width, 232)
        // 组 232 = 值输入 94 + 百分比 58 + 格式下拉 80
        compare(cp._hexField.width, 94)
        compare(cp._formatField.width, 80)
        // 滴管是「只有图标的 small 按钮」，官方写死 24×24（不是 Button 自己算出来的 48）
        compare(cp._eyeButton.width, 24)
        compare(cp._eyeButton.height, 24)
        // 相邻处那条 1px colorBorder 分隔线
        const sep = cp._group.children.filter((it) => it.objectName === "separator1")
        compare(sep.length, 1)
        compare(sep[0].width, 1)
        compare(sep[0].height, cp._group.height - 2)
        compare(sep[0].color.toString(), Theme.current.colorBorder.toString())
        cp.destroy()
    }

    function test_colorPickerControlledValueDoesNotSelfChange() {
        const cp = make('ColorPicker { value: ({'
            + 'hsva: {h: 0, s: 100, v: 100, a: 1},'
            + 'rgba: {r: 255, g: 0, b: 0, a: 1},'
            + 'hex: "#ff0000"}) }')
        let notified = null
        cp.changed.connect((v) => { notified = v })
        cp.alphaMove(140)
        verify(notified !== null)
        compare(notified.hsva.a, 0.5)
        // 受控：显示的还是外面给的那个值
        compare(cp.currentColor.hex, "#ff0000")
        compare(cp._hexField.text, "#ff0000")
        // 官方受控时连 state 都不写（foundation.ts:76-78 的 if (!getProp("value"))），
        // 不然松手再放开 value 会捡回那份被丢弃的中间值
        compare(cp._inner.hex, "#39c5bb")
        cp.destroy()
    }

    function test_colorPickerPopoverTriggerAndPanel() {
        const plain = make("ColorPicker { }")
        compare(plain._trigger.visible, false)
        // 不用弹层时面板就挂在组件自己身上（syncPanelHost 的另一条分支）
        verify(plain._panel.parent === plain)
        plain.destroy()

        const cp = make("ColorPicker { usePopover: true; defaultValue: '#00b42a' }")
        compare(cp._trigger.width, 24)
        compare(cp._trigger.height, 24)
        compare(cp.implicitWidth, 24)
        cp._popup.open()
        wait(50)
        verify(cp._popup.isOpen)
        verify(cp._panel.parent === cp._popup.contentItem)
        compare(cp._popup.implicitWidth, 296)
        compare(cp._popup.implicitHeight, 360)
        cp._popup.close()
        cp.destroy()

        const custom = make('ColorPicker { usePopover: true; triggerContent: Component {'
            + 'Item { implicitWidth: 100; implicitHeight: 40 } } }')
        wait(20)
        verify(custom._panel.parent === custom._popup.contentItem)
        compare(custom._trigger.width, 100)
        compare(custom._trigger.height, 40)
        custom.destroy()
    }

    function test_colorPickerStringToValueFormats() {
        const cp = make("ColorPicker { }")
        const fromHex = cp.colorStringToValue("#39c5bb")
        compare(fromHex.hex, "#39c5bb")
        compare(fromHex.rgba.r, 57)
        compare(fromHex.hsva.h, 176)
        const fromRgb = cp.colorStringToValue("rgb(57,197,187)")
        compare(fromRgb.hex, "#39c5bb")
        const fromRgba = cp.colorStringToValue("rgba(57,197,187,0.5)")
        compare(fromRgba.rgba.a, 0.5)
        const fromHsv = cp.colorStringToValue("hsv(176,71,77)")
        compare(fromHsv.hex, "#39c4bb")
        let threw = false
        try {
            cp.colorStringToValue("not-a-color")
        } catch (e) {
            threw = true
        }
        verify(threw)
        cp.destroy()
    }

    function test_colorPickerTopBottomSlotsGrowPanel() {
        const cp = make('ColorPicker {\n'
            + 'topSlot: Component { Item { implicitHeight: 30 } }\n'
            + 'bottomSlot: Component { Item { implicitHeight: 20 } }\n'
            + '}')
        wait(20)
        compare(cp.implicitHeight, 344 + 50)
        compare(cp._area.y, 30)
        cp.destroy()
    }

    // ---------------- Cascader ----------------

    function test_cascaderChildrenAt() {
        const cas = make("Cascader { }")
        cas.options = [
            { label: "浙江", value: "zj", children: [
                { label: "杭州", value: "hz" },
                { label: "宁波", value: "nb" }
            ] },
            { label: "江苏", value: "js" }
        ]
        compare(cas.childrenAt(0).length, 2)
        // 未选之前第二列是空的
        compare(cas.childrenAt(1).length, 0)

        cas.value = ["zj"]
        compare(cas.childrenAt(1).length, 2)
        compare(cas.childrenAt(1)[0].label, "杭州")
        cas.destroy()
    }

    function test_cascaderLabelsOf() {
        const cas = make("Cascader { }")
        cas.options = [
            { label: "浙江", value: "zj", children: [{ label: "杭州", value: "hz" }] }
        ]
        cas.value = ["zj", "hz"]
        compare(cas.displayText, "浙江 / 杭州")
        cas.value = []
        compare(cas.displayText, "")
        cas.destroy()
    }

    // TreeSelect 的回归测试在 tst_treeselect.qml（对齐官方属性面后单独成篇）。
    // PinCode 的回归测试在 tst_pincode.qml。
    // TagInput 的在 tst_taginput.qml。
}
