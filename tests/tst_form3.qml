import QtQuick
import QtTest
import Semi

// Form / FormItem / FormSection / FormSlot / FormInputGroup / FormArrayField。
// 断言尽量落在渲染出来的东西上（标签与控件的实际位置、错误文案、数组行数），
// 而不是组件内部的中间属性。
TestCase {
    id: testCase

    name: "Form3"
    when: windowShown
    width: 900
    height: 900

    property var capturedApi: undefined
    property int changes: 0
    property int valueEvents: 0
    property int errorEvents: 0

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

    function fields(root) {
        return walk(root, "formField")
    }

    function labels(root) {
        return walk(root, "formLabel").filter(function (l) { return l.visible })
    }

    function messages(root) {
        return walk(root, "formErrorMessage").filter(function (m) { return m.visible })
    }

    function textOf(item) {
        const t = walk(item, "formErrorMessageText")
        return t.length > 0 ? t[0].text : ""
    }

    function colorOf(item) {
        const t = walk(item, "formErrorMessageText")
        return t.length > 0 ? t[0].color : ""
    }

    // ---- 字段路径 ----

    function test_nestedFieldPathsMapIntoValues() {
        const f = make('Form { width: 400; Component.onCompleted: { registerField("parents[0].name", { rules: [] }); registerField("siblings[\'2\']", { rules: [] }); registerField("user[0]", { rules: [] }); registerField("a.b.c", { rules: [] }) } }')
        f.setValue("parents[0].name", "amy")
        f.setValue("siblings['2']", "s2")
        f.setValue("user[0]", "u0")
        f.setValue("a.b.c", 7)

        compare(f.values.parents[0].name, "amy")
        compare(f.values.siblings[2], "s2")
        compare(f.values.user[0], "u0")
        compare(f.values.a.b.c, 7)
        verify(Array.isArray(f.values.user))
        verify(Array.isArray(f.values.parents))
        f.destroy()
    }

    function test_emptyValueDropsKeyUnlessAllowEmpty() {
        const f = make('Form { width: 400 }')
        f.setValue("x", "abc")
        compare(f.values.x, "abc")
        f.setValue("x", "")
        verify(f.values.x === undefined)

        f.allowEmpty = true
        f.setValue("y", "v")
        f.setValue("y", "")
        compare(f.values.y, "")
        f.destroy()
    }

    // ---- 值与控件的双向接线 ----

    function test_inputWritesBackAndInitValuePushesIn() {
        const f = make('Form { width: 400; FormItem { field: "name"; label: "姓名"; initValue: "semi"; Input { objectName: "theInput"; width: 200 } } }')
        wait(60)
        const input = walk(f, "theInput")[0]

        compare(input.text, "semi")
        input.text = "typed"
        wait(20)
        compare(f.getValue("name"), "typed")
        f.destroy()
    }

    function test_formSetValuePushesIntoControl() {
        const f = make('Form { width: 400; FormItem { field: "note"; Input { objectName: "theInput"; width: 200 } } }')
        wait(60)
        f.setValue("note", "from api")
        wait(20)
        compare(walk(f, "theInput")[0].text, "from api")
        f.destroy()
    }

    // ---- 校验 ----

    function test_rulesCoverOfficialTypes() {
        const f = make('Form { width: 400; Component.onCompleted: { registerField("mail", { rules: [{ type: "email", message: "email bad" }] }); registerField("age", { rules: [{ type: "number", min: 18, message: "min 18" }] }); registerField("tags", { rules: [{ type: "array", max: 2, message: "max 2" }] }); registerField("len", { rules: [{ len: 3, message: "len 3" }] }) } }')
        f.setValue("mail", "nope")
        compare(f.checkField("mail"), "email bad")
        f.setValue("mail", "a@b.co")
        compare(f.checkField("mail"), "")

        f.setValue("age", 10)
        compare(f.checkField("age"), "min 18")
        f.setValue("age", 20)
        compare(f.checkField("age"), "")

        f.setValue("tags", ["a", "b", "c"])
        compare(f.checkField("tags"), "max 2")

        f.setValue("len", "ab")
        compare(f.checkField("len"), "len 3")
        f.destroy()
    }

    function test_fieldValidatorDisablesRules() {
        const f = make('Form { width: 400; Component.onCompleted: registerField("v", { rules: [{ required: true, message: "rule says empty" }], validator: function (value) { return value === "ok" ? "" : "validator says no" } }) }')
        f.setValue("v", "x")
        compare(f.checkField("v"), "validator says no")
        f.setValue("v", "ok")
        compare(f.checkField("v"), "")
        f.destroy()
    }

    function test_stopValidateWithErrorSkipsLaterRules() {
        // 两条规则都不通过：不中断时两条都跑（错误聚合），中断时只跑第一条
        const f = make('Form { width: 400; property int calls: 0; Component.onCompleted: { registerField("go", { rules: [{ min: 5, message: "E1" }, { validator: function (r, v) { calls += 1; return "E2" } }] }); registerField("stop", { stopValidateWithError: true, rules: [{ min: 5, message: "E1" }, { validator: function (r, v) { calls += 1; return "E2" } }] }) } }')
        f.calls = 0
        f.setValue("go", "ab")
        compare(f.calls, 1)
        compare(f.errorOf("go"), "E1, E2")

        f.calls = 0
        f.setValue("stop", "ab")
        compare(f.calls, 0)
        compare(f.errorOf("stop"), "E1")
        f.destroy()
    }

    function test_validateScopeAndSilent() {
        const f = make('Form { width: 400; Component.onCompleted: { registerField("a[0]", { required: true }); registerField("b", { required: true }) } }')
        // 静默：只出结果，不写 errors、不置 touched
        verify(!f.validate({ silent: true }))
        compare(Object.keys(f.errors).length, 0)
        compare(f.getTouched("b"), false)

        // 部分校验：只校 a 前缀
        verify(!f.validate(["a"]))
        verify(f.errorOf("a[0]") !== "")
        compare(f.errorOf("b"), "")
        compare(f.getTouched("b"), false)
        compare(f.getTouched("a[0]"), true)
        f.destroy()
    }

    function test_formLevelValidatorOverridesFieldRules() {
        const f = make('Form { width: 400; validator: function (values) { return values.name === "mike" ? {} : { name: "must be mike" } }; Component.onCompleted: registerField("name", { required: true }) }')
        f.setValue("name", "x")
        verify(!f.validate())
        compare(f.errorOf("name"), "must be mike")
        f.setValue("name", "mike")
        verify(f.validate())
        compare(f.errorOf("name"), "")
        f.destroy()
    }

    function test_errorOfJoinsArrayErrors() {
        const f = make('Form { width: 400 }')
        f.setError("x", ["第一条", "第二条"])
        compare(f.errorOf("x"), "第一条, 第二条")
        f.destroy()
    }

    function test_resetRestoresInitValueAndClearsState() {
        const f = make('Form { width: 400; initValues: ({ city: "hangzhou" }); FormItem { field: "city"; Input { objectName: "cityInput"; width: 200 } } FormItem { field: "other"; initValue: "keep" } }')
        wait(60)
        f.setValue("city", "beijing")
        f.setValue("other", "changed")
        f.validate()
        f.reset()
        compare(f.getValue("city"), "hangzhou")
        compare(f.getValue("other"), "keep")
        compare(Object.keys(f.errors).length, 0)
        compare(walk(f, "cityInput")[0].text, "hangzhou")
        f.destroy()
    }

    function test_fieldInitValueBeatsFormInitValues() {
        // 官方：Field 的 initValue 优先级高于 Form 的 initValues
        const f = make('Form { width: 400; initValues: ({ a: "from form", b: "from form" }); FormItem { field: "a"; initValue: "from field" } FormItem { field: "b" } }')
        wait(60)
        compare(f.getValue("a"), "from field")
        compare(f.getValue("b"), "from form")
        f.destroy()
    }

    function test_partialResetOnlyTouchesListedFields() {
        const f = make('Form { width: 400; Component.onCompleted: { registerField("a", { initValue: "A" }); registerField("b", { initValue: "B" }) } }')
        f.setValue("a", "x")
        f.setValue("b", "y")
        f.reset(["a"])
        compare(f.getValue("a"), "A")
        compare(f.getValue("b"), "y")
        f.destroy()
    }

    // ---- 渲染几何 ----

    function test_labelSitsAboveControlInTopPosition() {
        const f = make('Form { width: 400; FormItem { field: "n"; label: "姓名"; Input { objectName: "i1"; width: 200 } } }')
        wait(60)
        const label = labels(f)[0]
        const input = walk(f, "i1")[0]
        const field = fields(f)[0]

        const glyph = walk(label, "formLabelText")[0]
        // .semi-form-field-label { margin-bottom: 4 }
        compare(Math.round(input.mapToItem(f, 0, 0).y
            - (glyph.mapToItem(f, 0, 0).y + glyph.height)), 4)
        compare(input.mapToItem(f, 0, 0).x, 0)
        // .semi-form-vertical .semi-form-field { padding: 12px 0 }
        compare(Math.round(field.implicitHeight), 12 + label.height + input.height + 12)
        f.destroy()
    }

    function test_leftLabelUsesLabelWidthAndAlignsFirstLine() {
        const f = make('Form { width: 500; labelPosition: "left"; labelWidth: 120; FormItem { field: "n"; label: "手机号码"; Input { objectName: "i1"; width: 200 } } }')
        wait(60)
        const label = labels(f)[0]
        const input = walk(f, "i1")[0]

        compare(label.width, 120)
        // 控件从 labelWidth 之后开始（padding-right 16 含在标签宽度里）
        compare(Math.round(input.mapToItem(f, 0, 0).x), 120)
        // (控件高 32 - 行高 20) / 2 = 6
        const glyph = walk(label, "formLabelText")[0]
        compare(Math.round(glyph.mapToItem(f, 0, 0).y - input.mapToItem(f, 0, 0).y), 6)
        f.destroy()
    }

    function test_requiredMarkComesAfterLabelText() {
        const f = make('Form { width: 400; FormItem { field: "n"; label: ({ text: "姓名", required: true }); Input { width: 200 } } }')
        wait(60)
        const label = labels(f)[0]
        const text = walk(label, "formLabelText")[0]
        const star = walk(label, "formLabelRequired")[0]
        verify(star.visible)
        // 官方是 label-text 的 ::after，所以 * 在文字右侧
        verify(star.mapToItem(f, 0, 0).x > text.mapToItem(f, 0, 0).x + text.width - 1)
        compare(star.color, Theme.current.colorDanger)
        f.destroy()
    }

    function test_optionalLabelHidesRequiredMark() {
        const f = make('Form { width: 400; FormItem { field: "n"; label: ({ text: "角色", required: true, optional: true }); Input { width: 200 } } }')
        wait(60)
        const label = labels(f)[0]
        compare(walk(label, "formLabelRequired")[0].visible, false)
        const optional = walk(label, "formLabelOptional")
        compare(optional.length, 1)
        verify(optional[0].visible)
        compare(optional[0].color, Theme.current.colorTertiary)
        f.destroy()
    }

    function test_labelIsBoldAndText0() {
        const f = make('Form { width: 400; FormItem { field: "n"; label: "姓名"; Input { width: 200 } } }')
        wait(60)
        const text = walk(labels(f)[0], "formLabelText")[0]
        // $font-form_label-fontWeight: bold；color: text-0
        compare(text.font.weight, Font.Bold)
        compare(text.color, Theme.current.colorText0)
        f.destroy()
    }

    function test_errorMessageColorAndMargin() {
        const f = make('Form { width: 400; FormItem { field: "n"; label: "姓名"; trigger: "change"; rules: [{ required: true, message: "不能为空" }]; Input { objectName: "i1"; width: 200 } } }')
        wait(60)
        const input = walk(f, "i1")[0]
        input.text = "x"
        wait(20)
        input.text = ""
        // 位置器要过一次 polish 才给出新位置，20ms 不够
        wait(60)

        const msg = messages(f)[0]
        compare(textOf(msg), "不能为空")
        compare(colorOf(msg), Theme.current.colorDanger)
        // .semi-form-field-error-message { margin-top: 4 }
        const main = walk(f, "fieldMain")[0]
        const glyph = walk(msg, "formErrorMessageText")[0]
        compare(Math.round(glyph.mapToItem(main, 0, 0).y
            - input.mapToItem(main, 0, input.height).y), 4)
        f.destroy()
    }

    function test_helpTextAndExtraTextRenderTogether() {
        const f = make('Form { width: 400; FormItem { field: "n"; label: "姓名"; helpText: "帮助"; extraText: "补充"; Input { width: 200 } } }')
        wait(60)
        const msgs = messages(f)
        compare(msgs.length, 2)
        compare(textOf(msgs[0]), "帮助")
        compare(textOf(msgs[1]), "补充")
        // helpText 无错误时不是红色；extraText 常显且是 tertiary
        compare(colorOf(msgs[0]), Theme.current.colorText0)
        compare(colorOf(msgs[1]), Theme.current.colorTertiary)
        // 顺序：helpText 紧跟控件，extraText 在其后
        verify(msgs[0].mapToItem(f, 0, 0).y < msgs[1].mapToItem(f, 0, 0).y)
        f.destroy()
    }

    function test_errorWinsOverHelpText() {
        const f = make('Form { width: 400; FormItem { field: "n"; label: "姓名"; helpText: "提示"; trigger: "change"; rules: [{ required: true, message: "必填" }]; Input { objectName: "i1"; width: 200 } } }')
        wait(60)
        const input = walk(f, "i1")[0]
        input.text = "x"
        wait(20)
        input.text = ""
        wait(20)
        const msgs = messages(f)
        compare(msgs.length, 1)
        compare(textOf(msgs[0]), "必填")
        f.destroy()
    }

    function test_extraTextPositionMiddlePutsItAboveControl() {
        const f = make('Form { width: 400; extraTextPosition: "middle"; FormItem { field: "n"; label: "姓名"; extraText: "在控件上方"; Input { objectName: "i1"; width: 200 } } }')
        wait(60)
        const msg = messages(f)[0]
        const input = walk(f, "i1")[0]
        verify(msg.mapToItem(f, 0, 0).y < input.mapToItem(f, 0, 0).y)
        f.destroy()
    }

    function test_noLabelHidesLabelButKeepsErrorSlot() {
        const f = make('Form { width: 400; FormItem { field: "a"; label: "甲"; noLabel: true; trigger: "change"; rules: [{ required: true, message: "必填" }]; Input { objectName: "i1"; width: 200 } } }')
        wait(60)
        compare(labels(f).length, 0)
        const input = walk(f, "i1")[0]
        // 没有标签时控件贴着上内边距
        compare(Math.round(input.mapToItem(f, 0, 0).y), 12)
        input.text = "x"
        wait(20)
        input.text = ""
        wait(20)
        compare(textOf(messages(f)[0]), "必填")
        f.destroy()
    }

    function test_pureRendersOnlyTheControl() {
        const f = make('Form { width: 400; FormItem { field: "b"; label: "乙"; pure: true; trigger: "change"; rules: [{ required: true, message: "必填" }]; Input { objectName: "i2"; width: 200 } } }')
        wait(60)
        compare(labels(f).length, 0)
        const input = walk(f, "i2")[0]
        input.text = "x"
        wait(20)
        input.text = ""
        wait(20)
        // pure：数据流仍被接管，但不渲染 Label / ErrorMessage
        compare(f.errorOf("b"), "必填")
        compare(messages(f).length, 0)
        f.destroy()
    }

    function test_insetLabelGoesToTheControl() {
        const f = make('Form { width: 400; labelPosition: "inset"; FormItem { field: "n"; label: "姓名"; Input { objectName: "i1"; width: 200 } } }')
        wait(60)
        const input = walk(f, "i1")[0]
        compare(input.insetLabel, "姓名")
        const shown = walk(input, "insetLabel")[0]
        verify(shown.visible)
        compare(shown.text, "姓名")
        compare(shown.color, Theme.current.colorText2)
        compare(shown.font.weight, Font.DemiBold)
        compare(labels(f).length, 0)
        f.destroy()
    }

    function test_horizontalFormPlacesFieldsOnOneLine() {
        const f = make('Form { width: 600; layout: "horizontal"; FormItem { field: "a"; label: "甲"; Input { objectName: "i1"; width: 120 } } FormItem { field: "b"; label: "乙"; Input { objectName: "i2"; width: 120 } } }')
        wait(60)
        const first = walk(f, "i1")[0]
        const second = walk(f, "i2")[0]
        // 同一行：第二个字段的控件在第一个右边 120 + 16（field 的 padding-right）
        compare(Math.round(second.mapToItem(f, 0, 0).x - first.mapToItem(f, 0, 0).x), 136)
        compare(Math.round(second.mapToItem(f, 0, 0).y - first.mapToItem(f, 0, 0).y), 0)
        f.destroy()
    }

    // ---- 子组件 ----

    function test_sectionTitleRuleAndMargins() {
        const f = make('Form { width: 500; FormSection { text: "基本信息"; FormItem { field: "a"; label: "甲"; Input { objectName: "i1"; width: 200 } } } FormSection { text: "资源详情"; FormItem { field: "b"; label: "乙"; Input { width: 200 } } } }')
        wait(60)
        const sections = walk(f, "formSection")
        compare(sections.length, 2)
        const titles = walk(f, "formSectionText")
        compare(titles[0].text, "基本信息")
        compare(titles[0].font.pixelSize, Theme.current.fontSizeHeader5)
        compare(titles[0].color, Theme.current.colorText0)

        const rules = walk(f, "formSectionRule")
        compare(rules.length, 2)
        compare(rules[0].height, Theme.current.borderThicknessControl)
        compare(rules[0].color, Theme.current.colorBorder)

        // 第一个分组不带 margin-top；后面的分组 margin-top = superLoose 40 - baseTight 12
        const firstLabel = walk(sections[0], "formLabelText")[0]
        const rule0 = rules[0]
        // 标题下边框与内容之间是 margin-bottom 4
        compare(Math.round(firstLabel.mapToItem(f, 0, 0).y
            - (rule0.mapToItem(f, 0, 0).y + rule0.height)), 4 + 12)
        const gap = Math.round(titles[1].mapToItem(f, 0, 0).y
            - (titles[0].mapToItem(f, 0, 0).y + sections[0].implicitHeight))
        compare(gap, 28)
        f.destroy()
    }

    function test_slotSharesFieldLayout() {
        const f = make('Form { width: 500; labelPosition: "left"; labelWidth: 100; FormItem { field: "a"; label: "特效名称"; Input { objectName: "i0"; width: 250 } } FormSlot { objectName: "sl"; label: "SlotA"; error: "我是 SlotA 的错误"; Text { objectName: "slotText"; text: "自定义内容" } } }')
        wait(60)
        const slotLabels = labels(f)
        compare(slotLabels.length, 2)
        compare(slotLabels[1].text, "SlotA")
        compare(slotLabels[1].width, 100)
        // Slot 的主体与 FormItem 的主体左对齐（都从 labelWidth 开始）
        compare(Math.round(walk(f, "slotText")[0].mapToItem(f, 0, 0).x),
            Math.round(walk(f, "i0")[0].mapToItem(f, 0, 0).x))
        compare(textOf(messages(walk(f, "sl")[0])[0]), "我是 SlotA 的错误")

        // 官方 SlotB：label 对象里的 width / align 覆盖 Form 的 labelWidth
        const g = make('Form { width: 500; labelPosition: "left"; labelWidth: 100; FormSlot { label: ({ text: "SlotB", width: 160, align: "right" }); Text { objectName: "bText"; text: "内容" } } }')
        wait(60)
        const slotB = labels(g)[0]
        compare(slotB.width, 160)
        const glyphB = walk(slotB, "formLabelText")[0]
        // 右对齐：文字右边距标签盒右边缘正好是 padding-right 16
        compare(Math.round(slotB.mapToItem(g, slotB.width, 0).x
            - glyphB.mapToItem(g, glyphB.width, 0).x), 16)
        f.destroy()
        g.destroy()
    }

    function test_inputGroupHasOneLabelAndAggregatedError() {
        const f = make('Form { width: 500; FormInputGroup { label: ({ text: "手机号码", required: true }); FormItem { field: "prefix"; rules: [{ required: true, message: "前缀必填" }]; Select { objectName: "sel"; width: 150 } } FormItem { field: "number"; rules: [{ required: true, message: "号码必填" }]; Input { objectName: "inp"; width: 250 } } } }')
        wait(60)
        // 组内两个 Field 不再各自插 Label，Label 归组
        compare(labels(f).length, 1)
        compare(labels(f)[0].text, "手机号码")

        const groupRow = walk(f, "inputGroupRow")[0]
        const sel = walk(f, "sel")[0]
        const inp = walk(f, "inp")[0]
        // .semi-input-group：相邻控件共用一条接缝，后一个压前一个 1px
        compare(Math.round(inp.mapToItem(groupRow, 0, 0).x
            - (sel.mapToItem(groupRow, 0, 0).x + sel.width)), -1)
        // 中间切平，首尾各留一侧圆角
        compare(sel.topLeftRadius, Theme.current.radiusSmall)
        compare(sel.topRightRadius, 0)
        compare(inp.topRightRadius, Theme.current.radiusSmall)
        compare(inp.topLeftRadius, 0)

        f.validate()
        wait(20)
        const msg = messages(f)[0]
        compare(textOf(msg), "前缀必填, 号码必填")
        // 组里的错误固定用 alert_circle
        compare(walk(msg, "formErrorMessageIcon")[0].name, "alert_circle")
        f.destroy()
    }

    function test_arrayFieldAddRemoveAndPaths() {
        const f = make('Form { width: 700; FormArrayField { objectName: "af"; field: "rules"; initValue: [{ name: "one" }, { name: "two" }] } }')
        wait(60)
        const af = walk(f, "af")[0]
        compare(af.arrayFields.length, 2)
        compare(af.arrayFields[0].field, "rules[0]")
        compare(f.getValue("rules")[1].name, "two")

        af.add()
        wait(20)
        compare(af.arrayFields.length, 3)

        af.addWithInitValue({ name: "four" })
        wait(20)
        compare(af.arrayFields.length, 4)
        compare(f.getValue("rules")[3].name, "four")

        af.remove(0)
        wait(20)
        compare(af.arrayFields.length, 3)
        compare(f.getValue("rules")[0].name, "two")
        f.destroy()
    }

    function test_arrayFieldRowFieldWritesIntoRow() {
        // FormArrayField 自己带了内容（官方那节也是把按钮摆在 ArrayField 里面），
        // 这种形状下它挂进 Form.body 的时机最晚，initArray 只能靠 parentChanged 兜住
        const f = make('Form { width: 700; FormArrayField { objectName: "af"; field: "rules"; initValue: [{ name: "one" }]; Button { objectName: "addBtn"; text: "Add" } } FormItem { field: "rules[0][name]"; Input { objectName: "cell"; width: 100 } } }')
        wait(60)
        const cell = walk(f, "cell")[0]
        compare(cell.text, "one")
        cell.text = "renamed"
        wait(20)
        compare(f.getValue("rules")[0].name, "renamed")
        f.destroy()
    }

    function test_unmountedFieldDropsStateUnlessKeepState() {
        const root = make('Form { width: 400; property Component keepComp: Component { FormItem { field: "x"; keepState: true; Input { objectName: "kx"; width: 100 } } }; property Component plainComp: Component { FormItem { field: "x"; keepState: false; Input { objectName: "px"; width: 100 } } }; Loader { objectName: "ld"; active: true; sourceComponent: undefined } }')
        wait(60)
        const loader = walk(root, "ld")[0]

        // keepState：卸载再挂回，值与错误都保留
        loader.sourceComponent = root.keepComp
        wait(60)
        root.setValue("x", "kept")
        root.setTouched("x", true)
        wait(20)
        verify(root.getFieldExist("x"))
        compare(root.getTouched("x"), true)
        loader.sourceComponent = null
        wait(60)
        compare(root.getFieldExist("x"), false)
        loader.sourceComponent = root.keepComp
        wait(60)
        compare(root.getValue("x"), "kept")
        compare(walk(root, "kx")[0].text, "kept")

        // 不设 keepState：卸载即清掉 value / error / touched
        loader.sourceComponent = null
        wait(60)
        loader.sourceComponent = root.plainComp
        wait(60)
        root.setValue("x", "temp")
        verify(root.getValue("x") === "temp")
        loader.sourceComponent = null
        wait(60)
        verify(root.values.x === undefined)
        root.destroy()
    }

    function test_signalsFireOnValueAndErrorChange() {
        const f = make('Form { width: 400 }')
        testCase.changes = 0
        testCase.valueEvents = 0
        testCase.errorEvents = 0
        f.change.connect(function () { testCase.changes += 1 })
        f.valueChange.connect(function () { testCase.valueEvents += 1 })
        f.errorChange.connect(function () { testCase.errorEvents += 1 })
        f.setValue("a", "1")
        verify(testCase.valueEvents >= 1)
        verify(testCase.changes >= 1)
        verify(testCase.errorEvents >= 1)
        f.destroy()
    }

    function test_getFormApiCallbackReceivesForm() {
        const f = make('Form { width: 400; getFormApi: function (api) { testCase.capturedApi = api } }')
        verify(testCase.capturedApi !== undefined)
        compare(testCase.capturedApi, f)
        f.destroy()
    }

    // 「如何访问 formState」：formState 就是 values / errors / touched 三块
    function test_getFormStateCarriesValuesErrorsTouched() {
        const f = make('Form { width: 400; FormItem { field: "username"; label: "用户名"; rules: [{ required: true, message: "此项为必填" }]; Input { objectName: "i1"; width: 200 } } }')
        wait(60)
        compare(Object.keys(f.getFormState()).sort().join(","), "errors,touched,values")

        f.setError("username", "外部写入的错误")
        f.setTouched("username", true)
        const state = f.getFormState()
        compare(state.errors.username, "外部写入的错误")
        compare(state.touched.username, true)
        // 外部写进去的错误，字段上要渲染出来
        wait(60)
        const msgs = messages(f)
        compare(msgs.length, 1)
        compare(textOf(msgs[0]), "外部写入的错误")

        f.setValue("username", "semi")
        compare(f.getFormState().values.username, "semi")
        f.destroy()
    }

    // 官方这条 demo 的关键：Form 外部只握着 formApi 引用，也能驱动字段渲染
    function test_formStateReadOutsideFormDrivesRenderedText() {
        const root = make('Column { width: 400; property var api: null; Form { width: 360; getFormApi: (a) => { api = a } FormItem { field: "u"; label: "U"; Input { width: 200 } } } Text { objectName: "dump"; text: api ? JSON.stringify(api.getFormState().errors) : "-" } }')
        wait(60)
        verify(root.api !== null)

        const dump = walk(root, "dump")[0]
        compare(dump.text, "{}")
        root.api.setError("u", "外部写入的错误")
        wait(60)
        // getFormState() 是函数调用，绑定要能因为它内部读到 errors 而重算
        compare(dump.text, JSON.stringify({ u: "外部写入的错误" }))
        compare(textOf(messages(root)[0]), "外部写入的错误")

        root.api.reset()
        wait(60)
        compare(dump.text, "{}")
        root.destroy()
    }
    // FormItem 只按 <valueKey>Changed 接线，而组的信号叫 changed，所以 RadioGroup 放进表单时
    // 回写那一行得自己接（gallery 四处 Form.RadioGroup demo 都是这个写法）。
    // 这条盯住双向：FormItem 把 formState 推进组（组因此受控），点击回写 formState。
    function test_radioGroupInsideFormItemRoundTripsWithForm() {
        const f = make('Form { id: fm;'
            + ' FormItem { field: "isMonopolize"; label: "是否独占"; valueKey: "value";'
            + ' RadioGroup { objectName: "grp"; onChanged: (v) => fm.setValue("isMonopolize", v);'
            + ' Radio { objectName: "yes"; value: 1; text: "是" }'
            + ' Radio { objectName: "no"; value: 0; text: "否" } } } }')
        wait(60)
        const yes = testCase.walk(f, "yes")[0]
        const no = testCase.walk(f, "no")[0]
        const grp = testCase.walk(f, "grp")[0]
        verify(yes !== undefined && no !== undefined && grp !== undefined, "组与两项都该渲染出来")
        compare(yes.checked, false)
        compare(no.checked, false)

        mouseClick(no, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(f.values.isMonopolize, 0, "点击要回写 formState")
        compare(no.checked, true)

        f.setValue("isMonopolize", 1)
        wait(60)
        compare(grp.value, 1, "formState 要推得进组")
        compare(yes.checked, true)
        compare(no.checked, false)
        f.destroy()
    }

    // Rating 的提交信号也叫 changed（官方 onChange），所以 FormPage 的「满意度」那一行
    // 同样是手写回写；这条把双向都钉住。
    function test_ratingInsideFormItemRoundTripsWithForm() {
        const f = make('Form { id: fm;'
            + ' FormItem { field: "satisfaction"; label: "满意度"; valueKey: "value";'
            + ' Rating { objectName: "rt"; onChanged: (v) => fm.setValue("satisfaction", v) } } }')
        wait(60)
        const rt = testCase.walk(f, "rt")[0]
        verify(rt !== undefined, "Rating 该渲染出来")
        const stars = testCase.walk(rt, "ratingStar")
        compare(stars.length, 5)

        mouseClick(stars[3], 20, 12, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(f.values.satisfaction, 4, "点击要回写 formState")
        compare(rt.value, 4, "回写之后 Rating 是受控的 4")

        f.setValue("satisfaction", 2)
        wait(60)
        compare(rt.displayValue, 2, "formState 要推得进 Rating")
        f.destroy()
    }

    function test_inputNumberInsideFormItemWiresTheControlNotItsInnerInput() {
        // InputNumber 的 value 初始就是 undefined（非受控哨兵）。旧探测按「当前值在不在」
        // 判属性，会认为它没有 value，于是钻进控件内部把那只 Input 当成控件去写 text。
        const f = make('Form { FormItem { field: "qty"; label: "数量";'
            + ' InputNumber { objectName: "num"; min: 0; max: 100 } } }')
        wait(60)
        const item = fields(f)[0]
        const num = walk(f, "num")[0]
        verify(item !== undefined && num !== undefined, "FormItem 与 InputNumber 都要渲染出来")
        compare(item.resolvedKey, "value", "值属性要认成 value，不是钻进内部认成 text")
        compare(item.innerControl, num, "接的要是 InputNumber 自己，不是它里面那只 Input")

        num.field.forceActiveFocus()
        wait(20)
        keyClick(Qt.Key_7)
        wait(60)
        compare(f.values.qty, 7, "敲进去的数字要回写 formState")

        f.setValue("qty", 60)
        wait(60)
        compare(num.value, 60)
        compare(num.field.text, "60", "formState 的值要经 InputNumber 自己的格式化显示出来")
        f.destroy()
    }

    function test_pinCodeInsideFormItemWiresTheControlNotItsCells() {
        // 同一个探测缺口对 PinCode 也成立：它的 value 初始也是 undefined。
        // （PinCode 的提交信号叫 changed，FormItem 只认 <valueKey>Changed，
        //  所以敲格子不会回写 formState —— 与 Rating 是同一个已知缺口，这里只钉推的方向。）
        const f = make('Form { FormItem { field: "code"; label: "验证码";'
            + ' PinCode { objectName: "pc"; autoFocus: false } } }')
        wait(60)
        const item = fields(f)[0]
        const pc = walk(f, "pc")[0]
        compare(item.resolvedKey, "value")
        compare(item.innerControl, pc, "接的要是 PinCode，不是它某一格 Input")
        f.setValue("code", "1234")
        wait(60)
        const cells = walk(pc, "pinCodeCell")
        compare(cells.length, 6)
        compare(cells.map(function (c) { return c.text }).join(""), "1234")
        f.destroy()
    }
}
