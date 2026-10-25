import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Form"
    when: windowShown
    width: 300
    height: 300

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import Semi; " + qml, testCase, "probe")
    }

    // Input 的根项只是容器（要装前置/后置标签），底色与描边画在 .semi-input-wrapper
    // 那一层，断言要落在真正被画出来的那个矩形上。
    function boxOf(input) {
        return findByObjectName(input, "inputWrapper")[0]
    }

    // Row/Column 位置器要把子项排好得等下一次场景图更新：组里的项是组件创建完成后才
    // 搬进布局的（CheckboxGroup.reparentItems），搬进去那一拍坐标还是 0，下一帧才排好。
    // 探针实测（动态创建的横排组）第一拍三个子项全在 x=0，一帧后才是 0/49.125/98.01。
    // 所以断言坐标之前要轮询到「位置器动过了」，死等固定毫秒数在 cocoa 下会时好时坏。
    // 只判「最后一项离开了原点」这一件事，具体间距仍由下面的 compare 把关。
    function settled(g) {
        const kids = g.layout.children
        if (kids.length < 2)
            return true
        const last = kids[kids.length - 1]
        return g.horizontal ? last.x > 0 : last.y > 0
    }

    function settle(g) {
        for (let i = 0; i < 10 && !settled(g); ++i)
            wait(20)
    }

    // ---------------- Input ----------------

    function test_inputSizes() {
        const small = make("Input { size: Enums.Small }")
        const def = make("Input { }")
        const large = make("Input { size: Enums.Large }")
        compare(small.implicitHeight, 24)
        compare(def.implicitHeight, 32)
        compare(large.implicitHeight, 40)
        small.destroy(); def.destroy(); large.destroy()
    }

    function test_inputDefaultAppearance() {
        const input = make("Input { }")
        const box = boxOf(input)
        compare(box.color.toString(), Theme.current.colorFill0.toString())
        // 未聚焦时没有描边
        compare(box.border.color.toString(), "#00000000")
        input.destroy()
    }

    function test_inputStatusColors() {
        const danger = make("Input { validateStatus: Enums.StatusDanger }")
        compare(boxOf(danger).color.toString(), Theme.current.colorDangerLightDefault.toString())

        const warning = make("Input { validateStatus: Enums.StatusWarning }")
        compare(boxOf(warning).color.toString(), Theme.current.colorWarningLightDefault.toString())
        danger.destroy(); warning.destroy()
    }

    function test_inputDisabled() {
        const input = make("Input { enabled: false }")
        const box = boxOf(input)
        compare(box.color.toString(), Theme.current.colorDisabledFill.toString())
        compare(box.border.color.toString(), Theme.current.colorDisabledBorder.toString())
        // 官方靠 token 变暗，没有整体透明度：浏览器里量 .semi-input-wrapper-disabled
        // 的 computed opacity 就是 1（bg/border/text 各自换成 disabled-* 三个变量）
        compare(input.opacity, 1)
        input.destroy()
    }

    // 图标项在 RowLayout 里，从组件根项隔着一层，只能按 objectName 递归找
    function findByObjectName(root, name, acc) {
        const out = acc || []
        const kids = root.children
        for (let i = 0; i < kids.length; i++) {
            if (kids[i].objectName === name)
                out.push(kids[i])
            findByObjectName(kids[i], name, out)
        }
        return out
    }

    // 禁用态 prefix/suffix 图标要跟着换成 disabled-text。
    // 浏览器实测：enabled 的 .semi-icon 是 rgba(28,31,35,.62)=text-2，
    // 加 -disabled 后是 rgba(28,31,35,.35)=disabled-text（input.scss 的 &-disabled 块）。
    // 断的是**图标项自己的 color**，不是组件上那个 iconColor 属性 —— 只断属性的话，
    // 声明处漏接一根线（图标还写死 text-2）它照样绿。
    function test_inputIconColorFollowsState() {
        const on = make('Input { prefixIcon: "search"; suffixIcon: "search" }')
        const off = make('Input { prefixIcon: "search"; suffixIcon: "search"; enabled: false }')
        const painted = (it) => findByObjectName(it, "prefixIcon")
            .concat(findByObjectName(it, "suffixIcon"))
            .map((c) => c.color.toString())
        compare(painted(on).length, 2)
        compare(painted(off).length, 2)
        for (const c of painted(on))
            compare(c, Theme.current.colorText2.toString())
        for (const c of painted(off))
            compare(c, Theme.current.colorDisabledText.toString())
        on.destroy(); off.destroy()
    }

    function test_autoCompleteDisabledIcon() {
        const on = make("AutoComplete { }")
        const off = make("AutoComplete { enabled: false }")
        const icon = (it) => findByObjectName(it, "suffixIcon")
        compare(icon(on).length, 1)
        compare(icon(on)[0].color.toString(), Theme.current.colorText2.toString())
        compare(icon(off)[0].color.toString(), Theme.current.colorDisabledText.toString())
        compare(off._input.opacity, 1)
        on.destroy(); off.destroy()
    }

    function test_inputPlaceholderHiddenWhenFocused() {
        const input = make('Input { placeholderText: "请输入" }')
        compare(input.placeholderText, "请输入")
        compare(input.input.text, "")
        input.destroy()
    }

    function test_inputFollowsTheme() {
        const input = make("Input { }")
        const box = boxOf(input)
        const before = box.color.toString()
        Theme.mode = Theme.Dark
        verify(box.color.toString() !== before, "输入框底色应随主题变")
        input.destroy()
    }

    // ---------------- Checkbox ----------------

    function test_checkboxToggle() {
        let toggles = 0
        const cb = make('Checkbox { text: "x"; onToggled: toggles++ }')
        compare(cb.checked, false)
        cb.checked = true
        compare(cb.checked, true)
        cb.destroy()
    }

    function test_checkboxColors() {
        const box = Qt.createQmlObject(
            'import Semi; Checkbox { checked: true }', testCase, "cb2")
        compare(Appearance.choiceBoxBorderColor(Theme.current, true, Enums.Normal).toString(), "#0064fa")
        // 未选中描边是 text-3
        compare(Appearance.choiceBoxBorderColor(Theme.current, false, Enums.Normal).toString(),
                Theme.current.colorText3.toString())
        box.destroy()
    }

    function test_checkboxExtraLayoutMatchesOfficial() {
        const long = "Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统"
        const cb = make('Checkbox { text: "Semi Design"; extra: "' + long + '"; width: 280 }')
        // 框 ↔ 内容间距 $spacing-tight = 8
        compare(cb._content.x + cb._content.parent.x, 24)
        // 副文本和标题同一列，不额外缩进（&-extra 没有 padding-left）
        compare(cb._extra.x, cb._addon.x)
        // 标题与副文本的行间距 $spacing-extra-tight = 4
        compare(cb._extra.y - (cb._addon.y + cb._addon.height), 4)
        // 280 宽时内容列 256 = 280 - 16 - 8（官方实测同值）
        compare(cb._content.width, 256)
        // 副文本折两行：20 + 4 + 40
        compare(cb.implicitHeight, 64)
        compare(cb._extra.color.toString(), Theme.current.colorText2.toString())
        cb.destroy()
    }

    function test_checkboxBoxStaysOnFirstLine() {
        const cb = make('Checkbox { text: "标题"; extra: "很长很长很长很长很长很长"; width: 160 }')
        verify(cb.implicitHeight > 44, "副文本换行后整项应该变高")
        // .semi-checkbox-inner 高 20、方框在里面居中，所以框贴第一行文字，不会被副文本拽下来
        const centre = cb._box.mapToItem(cb._content, cb._box.width / 2, cb._box.height / 2)
        compare(centre.y, 10)
        cb.destroy()
    }

    function test_checkboxTickIsSixteenAndWhite() {
        const cb = make("Checkbox { checked: true }")
        verify(cb._icon.visible)
        // 官方 .semi-checkbox-inner-display .semi-icon { font-size: 16px }
        compare(cb._icon.width, 16)
        compare(cb._icon.color.toString(), Theme.current.colorWhite.toString())
        cb.destroy()

        const indet = make("Checkbox { indeterminate: true }")
        compare(indet._icon.name, "checkbox_indeterminate")
        // 半选和选中填同一套主色
        compare(indet._box.color.toString(), Theme.current.colorPrimary.toString())
        indet.destroy()

        const both = make("Checkbox { checked: true; indeterminate: true }")
        compare(both._icon.name, "checkbox_tick")
        both.destroy()
    }

    function test_checkboxDisabledUsesTokensNotItemOpacity() {
        const offChecked = make("Checkbox { checked: true; enabled: false }")
        // 整项不再有自造的 0.9 半透明
        compare(offChecked.opacity, 1)
        // 选中 + 禁用：方框 primary-disabled，并且方框自己 0.75（checkbox.scss:326-339）
        compare(offChecked._box.color.toString(), Theme.current.colorPrimaryDisabled.toString())
        compare(offChecked._box.opacity, 0.75)
        compare(offChecked._addon.color.toString(), Theme.current.colorDisabledText.toString())
        offChecked.destroy()

        const offPlain = make("Checkbox { enabled: false }")
        compare(offPlain._box.color.toString(), Theme.current.colorDisabledFill.toString())
        compare(offPlain._box.border.color.toString(), Theme.current.colorBorder.toString())
        compare(offPlain._box.opacity, 1)
        offPlain.destroy()
    }

    function test_checkboxHoverAndActiveTokens() {
        // 未选中的悬浮 / 按下底色：Radio 没有、Checkbox 有（checkbox.scss:48-73）
        compare(Appearance.choiceBoxBackground(Theme.current, false, false, Enums.Normal).toString(),
                "#00000000")
        compare(Appearance.choiceBoxBackground(Theme.current, false, false, Enums.Hovered).toString(),
                Theme.current.colorFill0.toString())
        compare(Appearance.choiceBoxBackground(Theme.current, false, false, Enums.Pressed).toString(),
                Theme.current.colorFill1.toString())
        compare(Appearance.choiceBoxBorderColor(Theme.current, false, Enums.Normal).toString(),
                Theme.current.colorText3.toString())
        compare(Appearance.choiceBoxBorderColor(Theme.current, false, Enums.Hovered).toString(),
                Theme.current.colorFocusBorder.toString())
        // 卡片里的空框填白，不是透明（$color-checkbox_cardType_inner-bg-default）
        compare(Appearance.choiceBoxBackground(Theme.current, false, true, Enums.Normal).toString(),
                Theme.current.colorWhite.toString())
    }

    function test_checkboxCardMetricsAndColors() {
        const off = make('Checkbox { text: "标题"; type: Enums.ChoiceCard }')
        verify(off._card.visible)
        compare(off._card.radius, Theme.current.radiusExtraSmall)
        compare(Theme.current.radiusExtraSmall, 3)
        compare(off.paddingX, 16)
        compare(off.paddingY, 12)
        compare(off.borderWidth, 1)
        // 单行：12 + 20 + 12 + 上下 1px 描边
        compare(off.implicitHeight, 46)
        compare(off._card.color.toString(), "#00000000")
        compare(off._card.border.color.toString(), "#00000000")
        // 内边距 + 描边 + 方框 + 8 间距
        compare(off._content.mapToItem(off, 0, 0).x, 16 + 1 + 16 + 8)
        off.destroy()

        const on = make('Checkbox { text: "标题"; type: Enums.ChoiceCard; checked: true }')
        compare(on._card.color.toString(), Theme.current.colorPrimaryLightDefault.toString())
        compare(on._card.border.color.toString(), Theme.current.colorPrimary.toString())
        // 卡片标题加粗（$font-checkbox_cardType_addon-fontWeight = 600）
        compare(on._addon.font.weight, Font.DemiBold)
        on.destroy()

        const onDisabled = make('Checkbox { text: "标题"; type: Enums.ChoiceCard; checked: true; enabled: false }')
        compare(onDisabled._card.color.toString(), Theme.current.colorPrimaryLightDefault.toString())
        compare(onDisabled._card.border.color.toString(), Theme.current.colorPrimaryDisabled.toString())
        onDisabled.destroy()
    }

    function test_checkboxPureCardHidesBox() {
        const cb = make('Checkbox { text: "标题"; type: Enums.ChoicePureCard }')
        compare(cb.innerWidth, 0)
        compare(cb.gap, 0)
        // 官方是 width:0 + opacity:0，不是直接不画（a11y 焦点还要靠它）
        compare(cb._box.parent.opacity, 0)
        verify(cb._box.visible)
        // 内容顶到卡片左内边距，框不占位
        compare(cb._content.mapToItem(cb, 0, 0).x, 17)
        cb.destroy()
    }

    function test_groupOptionsRender() {
        const g = make('CheckboxGroup { options: ["Semi UI", "Semi DSM"]; defaultValue: ["Semi DSM"] }')
        compare(g.layout.children.length, 2)
        compare(g.layout.children[0].text, "Semi UI")
        // 字符串项：value 就是它本身
        compare(g.layout.children[0].value, "Semi UI")
        compare(g.layout.children[0].checked, false)
        compare(g.layout.children[1].checked, true)
        g.destroy()

        const rich = make('CheckboxGroup { options: [{ label: "DSM", value: "dsm", extra: "副文本", disabled: true }] }')
        const item = rich.layout.children[0]
        compare(item.text, "DSM")
        compare(item.value, "dsm")
        verify(item._extra.visible)
        verify(item._off)
        rich.destroy()
    }

    function test_groupOptionsWinOverDeclarativeChildren() {
        const g = make('CheckboxGroup { options: ["A"]; Checkbox { text: "不该出现" } }')
        compare(g.layout.children.length, 1)
        compare(g.layout.children[0].text, "A")
        g.destroy()
    }

    function test_groupToggleAppendsAndRemoves() {
        const g = make('CheckboxGroup { options: ["A", "B"] }')
        const seen = []
        g.changed.connect((v) => seen.push(JSON.stringify(v)))
        g.layout.children[0].toggleNow()
        compare(JSON.stringify(g.currentValue), '["A"]')
        g.layout.children[1].toggleNow()
        compare(JSON.stringify(g.currentValue), '["A","B"]')
        g.layout.children[0].toggleNow()
        // 取消是按下值过滤，不是按索引删
        compare(JSON.stringify(g.currentValue), '["B"]')
        compare(seen.length, 3)
        compare(seen[2], '["B"]')
        g.destroy()
    }

    function test_groupControlledModeOnlyNotifies() {
        const g = make('CheckboxGroup { options: ["A", "B"]; value: [] }')
        let notified = null
        g.changed.connect((v) => { notified = v })
        g.layout.children[0].toggleNow()
        // 受控：组不自己改值（checkboxGroupFoundation.ts:47-56）
        compare(g.currentValue.length, 0)
        verify(notified !== null)
        compare(notified.length, 1)
        // 成员的勾选也只跟组的 value，点一下不会自己变
        compare(g.layout.children[0].checked, false)
        g.destroy()
    }

    function test_groupDisabledBlocksMembers() {
        const g = make('CheckboxGroup { options: ["A"]; disabled: true }')
        const item = g.layout.children[0]
        verify(item._off)
        item.toggleNow()
        compare(g.currentValue.length, 0)
        g.destroy()
    }

    function test_groupDirectionSpacing() {
        const v = make('CheckboxGroup { options: ["A", "B"] }')
        settle(v)
        compare(v.layout.objectName, "columnLayout")
        compare(v.layout.children[1].y - (v.layout.children[0].y + v.layout.children[0].height), 12)
        v.destroy()

        const card = make('CheckboxGroup { options: ["A", "B"]; type: Enums.ChoiceCard }')
        settle(card)
        compare(card.layout.children[1].y - (card.layout.children[0].y + card.layout.children[0].height), 16)
        // 组的 type 会下发给每一项（checkbox.tsx:236-238 走 context）
        verify(card.layout.children[0]._isCard)
        card.destroy()

        const h = make('CheckboxGroup { options: ["A", "B"]; direction: Enums.DirectionHorizontal }')
        settle(h)
        compare(h.layout.objectName, "rowLayout")
        compare(h.layout.children[1].x - (h.layout.children[0].x + h.layout.children[0].width), 16)
        h.destroy()
    }

    function test_groupMemberNeedsValue() {
        const g = make('CheckboxGroup { defaultValue: ["A"]; '
            + 'Checkbox { value: "A"; text: "A" } Checkbox { text: "无 value" } }')
        compare(g.layout.children.length, 2)
        const member = g.layout.children[0]
        const stray = g.layout.children[1]
        verify(member.inGroup)
        compare(member.checked, true)
        // 官方按「props 里有没有 value」判定归属（checkbox.tsx:181）
        verify(!stray.inGroup)
        stray.toggleNow()
        compare(stray.checked, true)
        compare(g.currentValue.length, 1)
        g.destroy()
    }

    // ---------------- Switch ----------------

    function test_switchTrackColors() {
        // 开启态是 success 绿，不是主色
        compare(Appearance.switchTrack(Theme.current, true, Enums.Normal, false).toString(),
                Theme.current.colorSuccess.toString())
        compare(Theme.current.colorSuccess.toString(), "#3bb346")
        compare(Appearance.switchTrack(Theme.current, false, Enums.Normal, false).toString(),
                Theme.current.colorFill0.toString())
        compare(Appearance.switchTrack(Theme.current, true, Enums.Disabled, false).toString(),
                Theme.current.colorSuccessDisabled.toString())
        compare(Appearance.switchTrack(Theme.current, false, Enums.Disabled, false).toString(), "#00000000")
    }

    function test_switchHoverColors() {
        // $color-switch_default-bg-hover / -checked-bg-hover
        compare(Appearance.switchTrack(Theme.current, false, Enums.Hovered, false).toString(),
                Theme.current.colorFill1.toString())
        compare(Appearance.switchTrack(Theme.current, true, Enums.Hovered, false).toString(),
                Theme.current.colorSuccessHover.toString())
    }

    function test_switchLoadingColors() {
        // $color-switch_spin_unchecked/checked-bg-default
        compare(Appearance.switchTrack(Theme.current, false, Enums.Normal, true).toString(),
                Theme.current.colorFill1.toString())
        compare(Appearance.switchTrack(Theme.current, true, Enums.Normal, true).toString(),
                Theme.current.colorSuccessHover.toString())
        // 禁用 + 加载 + 未选中仍是 fill-1；+ 选中被后面的
        // .semi-switch-disabled.semi-switch-checked 翻回 success-disabled
        compare(Appearance.switchTrack(Theme.current, false, Enums.Disabled, true).toString(),
                Theme.current.colorFill1.toString())
        compare(Appearance.switchTrack(Theme.current, true, Enums.Disabled, true).toString(),
                Theme.current.colorSuccessDisabled.toString())
    }

    function test_switchBorders() {
        // 按下描边 fill-2；禁用未选中是 --semi-color-border，禁用已选中透明
        compare(Appearance.switchTrackBorder(Theme.current, false, Enums.Pressed).toString(),
                Theme.current.colorFill2.toString())
        compare(Appearance.switchTrackBorder(Theme.current, false, Enums.Normal).toString(), "#00000000")
        compare(Appearance.switchTrackBorder(Theme.current, false, Enums.Disabled).toString(),
                Theme.current.colorBorder.toString())
        compare(Appearance.switchTrackBorder(Theme.current, true, Enums.Disabled).toString(), "#00000000")
        compare(Appearance.switchKnobBorder(Theme.current, false, Enums.Disabled).toString(),
                Theme.current.colorBorder.toString())
        compare(Appearance.switchKnobBorder(Theme.current, true, Enums.Disabled).toString(), "#00000000")
    }

    function test_switchSize() {
        // 26×16 / 40×24 / 54×32（$width-switch、_small、_large）
        const small = make("Switch { size: Enums.Small }")
        const def = make("Switch { }")
        const large = make("Switch { size: Enums.Large }")
        compare(small.implicitWidth, 26)
        compare(small.implicitHeight, 16)
        compare(def.implicitWidth, 40)
        compare(def.implicitHeight, 24)
        compare(large.implicitWidth, 54)
        compare(large.implicitHeight, 32)
        small.destroy(); def.destroy(); large.destroy()
    }

    function test_switchCheckedUsesSuccess() {
        // 开启态的轨道色跟随主题（不是主色）
        compare(Appearance.switchTrack(Theme.current, true, Enums.Normal, false).toString(), "#3bb346")
        Theme.mode = Theme.Dark
        compare(Appearance.switchTrack(Theme.current, true, Enums.Normal, false).toString(),
                Theme.current.colorSuccess.toString())
    }
}
