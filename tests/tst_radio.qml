import QtQuick
import QtTest
import Semi

// Radio / RadioGroup 对齐官方后的回归测试：单选圈的三态与禁用令牌、IconRadio 标记、
// addon/extra 排版、advanced 取消语义、组的互斥与受控、options 二选一、
// button / card / pureCard 三种样式的几何与颜色。
// 断言尽量落在渲染出来的项上（宽高、颜色、图标名、坐标），而不是中间属性。
TestCase {
    id: testCase

    name: "RadioPro"
    when: windowShown
    width: 900
    height: 900

    property var changes: []
    property var ctrlValue: undefined   // 受控组用例把它绑给 RadioGroup.value

    function init() {
        // 见 PROGRESS.md 坑 4 / 坑 70：根项不可见时合成事件会被静默丢弃
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
        testCase.changes = []
        // 合成指针会停在上一条用例留下的位置；新建的探针项就落在 (0,0)，
        // 于是 HoverHandler 一上来就是 hovered，颜色断言按上一条的尾巴取值。
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(20)
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

    // 合成移动偶尔要两拍才落到新挂上的 HoverHandler 上（同 PROGRESS.md 坑 67 那类
    // 「等到状态真的变了再断言」）。这里只等「进入悬浮态」这一件事，颜色照样硬断言。
    function hoverAt(item) {
        mouseMove(item, item.width / 2, item.height / 2)
        let tries = 0
        while (item.controlState !== Enums.Hovered && tries < 10) {
            wait(20)
            mouseMove(item, item.width / 2, item.height / 2)
            ++tries
        }
        compare(item.controlState, Enums.Hovered, "指针没落到 " + item + " 上")
    }

    function unhover(item) {
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        let tries = 0
        while (item.controlState === Enums.Hovered && tries < 10) {
            wait(20)
            ++tries
        }
    }

    // 按视觉顺序返回组内各项，这样几何断言里的 items[0] / items[1] 就是「左边那个 /
    // 右边那个」。点击类断言一律用下面的 radioWithValue 按 value 找，不按下标 ——
    // 下标依赖排布结果，读起来也不知道在点谁。
    function radiosIn(group) {
        return group.layout.children.filter(function (it) {
            return it.objectName !== "optionRepeater"
        }).sort(function (a, b) {
            return a.y !== b.y ? a.y - b.y : a.x - b.x
        })
    }

    function radioWithValue(group, v) {
        const items = radiosIn(group)
        for (let i = 0; i < items.length; ++i)
            if (items[i].value === v)
                return items[i]
        verify(false, "组里找不到 value=" + v + " 的项")
        return null
    }

    // ---- 单选圈：三态与令牌 ----

    // $color-radio_default-border-default = text-3，底色 transparent
    function test_uncheckedCircleIsText3BorderOnTransparent() {
        const r = make('Radio { text: "A" }')
        wait(60)
        compare(r.circleItem.width, Theme.current.widthIconMedium)
        compare(r.circleItem.height, Theme.current.widthIconMedium)
        compare(r.circleItem.radius, Theme.current.widthIconMedium / 2)
        compare(r.circleItem.border.width, 1)
        compare(r.circleItem.color.toString(), "#00000000")
        compare(r.circleItem.border.color.toString(), Theme.current.colorText3.toString())
        verify(!r.markItem.visible, "未选中不该有标记")
        r.destroy()
    }

    // 官方选中标记是 14px 的 IconRadio（radioInner.tsx:149 + radio.scss:229-238），
    // 不是随手画的一个白圆
    function test_checkedCircleFillsPrimaryWithRadioIcon() {
        const r = make('Radio { text: "A"; checked: true }')
        wait(60)
        compare(r.circleItem.color.toString(), Theme.current.colorPrimary.toString())
        compare(r.circleItem.border.color.toString(), Theme.current.colorPrimary.toString())
        compare(r.markItem.name, "radio")
        compare(r.markItem.size, 14)
        compare(r.markItem.color.toString(), Theme.current.colorWhite.toString())
        verify(r.markItem.visible)
        r.destroy()
    }

    // radio.scss:36-45：未选中悬浮填 fill-0，描边同时换成 focus-border
    function test_uncheckedHoverFillsZeroAndBorderTurnsFocus() {
        const r = make('Radio { text: "A" }')
        wait(60)
        hoverAt(r)
        compare(r.circleItem.color.toString(), Theme.current.colorFill0.toString())
        compare(r.circleItem.border.color.toString(), Theme.current.colorFocusBorder.toString())
        r.destroy()
    }

    function test_uncheckedPressedFillsOne() {
        const r = make('Radio { text: "A" }')
        wait(60)
        mousePress(r, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(r.circleItem.color.toString(), Theme.current.colorFill1.toString())
        mouseRelease(r, Qt.LeftButton, Qt.NoModifier)
        r.destroy()
    }

    // $color-radio_primary-bg-hover / -bg-active
    function test_checkedHoverAndPressedFollowPrimaryStates() {
        const r = make('Radio { text: "A"; checked: true }')
        wait(60)
        hoverAt(r)
        compare(r.circleItem.color.toString(), Theme.current.colorPrimaryHover.toString())
        compare(r.circleItem.border.color.toString(), Theme.current.colorPrimaryHover.toString())
        mousePress(r, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(r.circleItem.color.toString(), Theme.current.colorPrimaryActive.toString())
        compare(r.circleItem.border.color.toString(), Theme.current.colorPrimaryActive.toString())
        mouseRelease(r, Qt.LeftButton, Qt.NoModifier)
        r.destroy()
    }

    // radio.scss:353-395：禁用未选中是 disabled-fill + color-border，并且整框 0.75 不透明度
    // （radio.scss:363-364 打在 -inner-display 上，选中那一支 374-386 没有重置 opacity）
    function test_disabledUncheckedUsesDisabledTokens() {
        const r = make('Radio { text: "A"; disabled: true }')
        wait(60)
        compare(r.circleItem.color.toString(), Theme.current.colorDisabledFill.toString())
        compare(r.circleItem.border.color.toString(), Theme.current.colorBorder.toString())
        compare(r.circleItem.opacity, 0.75)
        compare(r.addonItem.color.toString(), Theme.current.colorDisabledText.toString())
        r.destroy()
    }

    function test_disabledCheckedKeepsWhiteMark() {
        const r = make('Radio { text: "A"; checked: true; disabled: true }')
        wait(60)
        compare(r.circleItem.color.toString(), Theme.current.colorPrimaryDisabled.toString())
        compare(r.circleItem.border.color.toString(), Theme.current.colorPrimaryDisabled.toString())
        compare(r.circleItem.opacity, 0.75)   // 与未选中禁用同一档（radio.scss:364）
        compare(r.markItem.color.toString(), Theme.current.colorWhite.toString())
        r.destroy()
    }

    // ---- 排版 ----

    // $spacing-radio_addon-paddingLeft = spacing-tight
    function test_gapBetweenCircleAndLabelIsEight() {
        const r = make('Radio { text: "A" }')
        wait(60)
        compare(r.gap, Theme.current.spacingTight)
        compare(r.addonItem.x, 0, "非按钮式标题不额外内缩")
        r.destroy()
    }

    // .semi-radio-content 是 flex-column、row-gap 4；extra 与 addon 左对齐
    // （radio.scss:390-393 的 -extra 没有 padding-left）
    function test_extraSitsUnderAddonAndSharesItsLeftEdge() {
        const r = make('Radio { text: "Semi Design"; extra: "副文本"; width: 300 }')
        wait(60)
        verify(r.extraItem.visible)
        compare(r.contentItem.spacing, Theme.current.spacingExtraTight)
        compare(r.extraItem.y, r.addonItem.parent.height + r.contentItem.spacing)
        compare(r.extraItem.color.toString(), Theme.current.colorText2.toString())
        r.destroy()
    }

    function test_extraIsHiddenWhenNotGiven() {
        const r = make('Radio { text: "A" }')
        wait(60)
        verify(!r.extraItem.visible, "没给 extra 就不该占一行")
        compare(r.height, 20)
        r.destroy()
    }

    // 圆圈贴第一行：extra 再多也不把圆圈拽下来（官方 .semi-radio-inner 是 16×16 + margin-top 2，
    // radio.scss:212-219；本库做成 20 高的槽、圆圈居中，视觉等效）
    function test_circleStaysOnFirstLineWithLongExtra() {
        const long = "Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统"
        const r = make('Radio { text: "Semi Design"; extra: "' + long + '"; width: 280 }')
        wait(60)
        verify(r.extraItem.height > 24, "副文本应该已经换行成多行")
        compare(r.circleItem.parent.height, 20)
        verify(r.height > r.circleItem.parent.height)
        r.destroy()
    }

    // ---- 点击语义 ----

    function test_clickChecksStandaloneRadio() {
        const r = make('Radio { text: "A" }')
        wait(60)
        let fired = 0
        r.changed.connect(function () { fired++ })
        mouseClick(r, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(r.checked, true)
        compare(fired, 1)
        r.destroy()
    }

    // 官方非 advanced 是 <input type=radio>：点已选中项不触发 change（radioInnerFoundation.ts:38）
    function test_clickingCheckedRadioDoesNothing() {
        const r = make('Radio { text: "A"; checked: true }')
        wait(60)
        let fired = 0
        r.changed.connect(function () { fired++ })
        mouseClick(r, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(r.checked, true)
        compare(fired, 0, "普通模式点已选中项不该再发 change")
        r.destroy()
    }

    // mode='advanced' 时 input 换成 checkbox（radioInner.tsx:139），可以再点掉
    function test_advancedModeClickUnchecks() {
        const r = make('Radio { text: "A"; mode: "advanced"; checked: true }')
        wait(60)
        mouseClick(r, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(r.checked, false)
        r.destroy()
    }

    function test_defaultCheckedAppliesAtInit() {
        const r = make('Radio { text: "A"; defaultChecked: true }')
        wait(60)
        compare(r.checked, true)
        r.destroy()
    }

    function test_disabledRadioIgnoresClick() {
        const r = make('Radio { text: "A"; disabled: true }')
        wait(60)
        mouseClick(r, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(r.checked, false)
        r.destroy()
    }


    // 本库把 QML 的 enabled 也并进 _off（Form 里禁用整项时走这条路），
    // 表现要和官方 disabled 一致
    function test_enabledFalseBehavesLikeDisabled() {
        const r = make('Radio { text: "A"; enabled: false }')
        wait(60)
        compare(r._off, true)
        compare(r.circleItem.border.color.toString(), Theme.current.colorBorder.toString())
        compare(r.addonItem.color.toString(), Theme.current.colorDisabledText.toString())
        mouseClick(r, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(r.checked, false)
        r.destroy()
    }

    // ---- RadioGroup：排布与互斥 ----

    // 横排 gap $spacing-base=16（radio.scss:433-435）
    function test_groupLaysOutHorizontallyWithSixteenGap() {
        const g = make('RadioGroup { defaultValue: 1;'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        compare(g.itemSpacing, Theme.current.spacingBase)
        const items = radiosIn(g)
        compare(items.length, 2)
        compare(items[1].x - (items[0].x + items[0].width), Theme.current.spacingBase)
        compare(items[1].y, items[0].y)
        g.destroy()
    }

    // 竖排 row-gap $spacing-base-tight=12（radio.scss:415-417）
    function test_verticalGroupStacksWithTwelveGap() {
        const g = make('RadioGroup { direction: Enums.DirectionVertical; defaultValue: 1;'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        compare(g.itemSpacing, Theme.current.spacingBaseTight)
        const items = radiosIn(g)
        compare(items[1].y - (items[0].y + items[0].height), Theme.current.spacingBaseTight)
        compare(items[1].x, items[0].x)
        g.destroy()
    }

    function test_groupValueSelectsTheMatchingItem() {
        const g = make('RadioGroup { defaultValue: 2;'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        const items = radiosIn(g)
        compare(radioWithValue(g, 1).checked, false)
        compare(radioWithValue(g, 2).checked, true)
        g.destroy()
    }

    function test_clickingAnotherItemMovesSelectionAndFiresChanged() {
        const g = make('RadioGroup { defaultValue: 1;'
            + ' onChanged: (v) => testCase.changes.push(v);'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        mouseClick(radioWithValue(g, 2), Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(g.currentValue, 2)
        compare(testCase.changes, [2])
        const items = radiosIn(g)
        compare(radioWithValue(g, 1).checked, false)
        compare(radioWithValue(g, 2).checked, true)
        g.destroy()
    }

    function test_clickingCheckedItemDoesNothing() {
        const g = make('RadioGroup { defaultValue: 1;'
            + ' onChanged: (v) => testCase.changes.push(v);'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        mouseClick(radioWithValue(g, 1), Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(testCase.changes.length, 0, "值没变不该发 change（radioGroupFoundation.ts:58）")
        g.destroy()
    }

    function test_groupDisabledDisablesEveryItem() {
        const g = make('RadioGroup { disabled: true; defaultValue: 1;'
            + ' onChanged: (v) => testCase.changes.push(v);'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        compare(radioWithValue(g, 1)._off, true)
        compare(radioWithValue(g, 2)._off, true)
        compare(radioWithValue(g, 1).circleItem.color.toString(),
                Theme.current.colorPrimaryDisabled.toString())
        // 组禁用时点未选中项：既不选中也不通知（radio.tsx:223 的 isDisabled 把 input 关掉了）
        mouseClick(radioWithValue(g, 2), Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(radioWithValue(g, 2).checked, false)
        compare(g.currentValue, 1)
        compare(testCase.changes.length, 0)
        g.destroy()
    }

    // 单项 disabled 与组 disabled 取或（radio.tsx:221）
    function test_itemDisabledOrsGroupDisabled() {
        const g = make('RadioGroup { defaultValue: 1;'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B"; disabled: true } }')
        wait(60)
        compare(radioWithValue(g, 1)._off, false)
        compare(radioWithValue(g, 2)._off, true)
        g.destroy()
    }

    // 受控：组里有 value 绑定时组不自改，只通知（radioGroupFoundation.ts:47）
    function test_controlledGroupDoesNotSelfChange() {
        const g = make('RadioGroup { value: 1;'
            + ' onChanged: (v) => testCase.changes.push(v);'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        mouseClick(radioWithValue(g, 2), Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(testCase.changes, [2], "照样通知")
        compare(g.currentValue, 1, "但值仍由外部说了算")
        g.destroy()
    }

    // advanced 组里点已选中项 → 值变 undefined，并且一定要通知
    function test_advancedGroupClearsValueToUndefined() {
        const g = make('RadioGroup { mode: "advanced"; defaultValue: 1;'
            + ' onChanged: (v) => testCase.changes.push(v);'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        mouseClick(radioWithValue(g, 1), Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(g.currentValue, undefined)
        compare(testCase.changes.length, 1)
        compare(testCase.changes[0], undefined)
        g.destroy()
    }

    // toggleNow() 是公开函数，禁用时也必须没反应（UI 那条路已经被 TapHandler 的
    // enabled: !control._off 挡住了，改法只能从函数入口测）
    function test_toggleNowOnDisabledRadioDoesNothing() {
        const r = make('Radio { text: "A"; disabled: true }')
        wait(60)
        let fired = 0
        r.changed.connect(function () { fired++ })
        r.toggleNow()
        wait(20)
        compare(r.checked, false)
        compare(fired, 0)
        r.destroy()
    }

    // 受控期间的点击只通知、不写内部值（radioGroupFoundation.ts:50-56 的 isControlledComponent）。
    // 泄漏的后果要等组「脱离受控」才看得见：那时读的是 _inner。
    function test_controlledClickLeavesNoInternalValueBehind() {
        testCase.ctrlValue = 1
        const g = make('RadioGroup { value: testCase.ctrlValue;'
            + ' onChanged: (v) => testCase.changes.push(v);'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        mouseClick(radioWithValue(g, 2), Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(testCase.changes, [2])
        compare(radioWithValue(g, 2).checked, false, "外部没接这个值，就不该选中")
        testCase.ctrlValue = undefined
        wait(60)
        compare(radioWithValue(g, 2).checked, false, "脱离受控后也不该翻出受控期间残留的内部值")
        compare(radioWithValue(g, 1).checked, false, "组本来就 defaultValue 未给，谁都不选")
        g.destroy()
    }

    // ---- options ----

    function test_optionsStringsRenderRadios() {
        const g = make('RadioGroup { options: ["Guest", "Developer", "Maintainer"];'
            + ' defaultValue: "Developer" }')
        wait(60)
        const items = radiosIn(g)
        compare(items.length, 3)
        compare(items[0].text, "Guest")
        compare(items[0].value, "Guest", "字符串项的 value 就是它本身")
        compare(items[1].checked, true)
        g.destroy()
    }

    function test_optionsObjectsHonorLabelExtraDisabledAndWidth() {
        const g = make('RadioGroup { options: ['
            + '{ label: "Guest", value: "g" },'
            + '{ label: "Dev", value: "d", extra: "Semi Design", width: 120 },'
            + '{ label: "Mnt", value: "m", disabled: true }'
            + ' ] }')
        wait(60)
        const items = radiosIn(g)
        compare(items.length, 3)
        compare(items[0].text, "Guest")
        compare(items[1].extraItem.visible, true)
        compare(items[1].width, 120)
        compare(items[2]._off, true)
        g.destroy()
    }

    // options 与声明式子项二选一（radioGroup.tsx:181-196）
    function test_optionsWinOverDeclarativeChildren() {
        const g = make('RadioGroup { options: ["x", "y"];'
            + ' Radio { value: "z"; text: "Z" } }')
        wait(60)
        const items = radiosIn(g)
        compare(items.length, 2)
        compare(items[0].text, "x")
        compare(items[1].text, "y")
        g.destroy()
    }

    // ---- 卡片样式 ----

    // .semi-radio-cardRadioGroup：padding 12(纵)/16(横)、圆角 3、1px 描边（radio.scss:104-109）
    function test_cardItemChrome() {
        const r = make('Radio { text: "标题"; extra: "副文本"; type: Enums.ChoiceCard; width: 280 }')
        wait(60)
        compare(r.paddingX, Theme.current.spacingBase)
        compare(r.paddingY, Theme.current.spacingBaseTight)
        compare(r.borderWidth, 1)
        compare(r.cardItem.radius, Theme.current.radiusSmall)
        compare(r.cardItem.border.width, 1)
        compare(r.addonItem.font.weight, Font.DemiBold)
        r.destroy()
    }

    function test_cardCheckedBackgroundAndBorder() {
        const r = make('Radio { text: "标题"; type: Enums.ChoiceCard; checked: true }')
        wait(60)
        compare(r.cardItem.color.toString(), Theme.current.colorPrimaryLightDefault.toString())
        compare(r.cardItem.border.color.toString(), Theme.current.colorPrimary.toString())
        // 卡片里的空框填白（$color-radio_card-bg-default）
        const u = make('Radio { text: "标题"; type: Enums.ChoiceCard }')
        wait(60)
        compare(u.circleItem.color.toString(), Theme.current.colorWhite.toString())
        r.destroy()
        u.destroy()
    }

    function test_cardUncheckedHoverFillsZero() {
        const r = make('Radio { text: "标题"; type: Enums.ChoiceCard }')
        wait(60)
        hoverAt(r)
        compare(r.cardItem.color.toString(), Theme.current.colorFill0.toString())
        r.destroy()
    }

    // 卡片竖排间距也是 12：variables.scss:64 那个 card 专用 16 是死变量，全文件没被引用
    function test_cardVerticalGroupGapIsTwelveNotSixteen() {
        const g = make('RadioGroup { type: Enums.ChoiceCard;'
            + ' direction: Enums.DirectionVertical; defaultValue: 1;'
            + ' Radio { value: 1; text: "A"; width: 280 } Radio { value: 2; text: "B"; width: 280 } }')
        wait(60)
        const items = radiosIn(g)
        compare(items[1].y - (items[0].y + items[0].height), Theme.current.spacingBaseTight)
        g.destroy()
    }

    // pureCard 只是把圈藏掉：不占位、间距归 0（radio.scss:340-347）
    function test_pureCardHidesTheCircleAndItsGap() {
        const r = make('Radio { text: "标题"; type: Enums.ChoicePureCard }')
        wait(60)
        compare(r.gap, 0)
        compare(r.innerWidth, 0)
        compare(r.circleItem.parent.opacity, 0)
        verify(r.cardItem.visible, "pureCard 仍然是卡片底")
        r.destroy()
    }

    function test_cardAndPureCardBothUseTheCardBackground() {
        const c = make('Radio { text: "A"; type: Enums.ChoiceCard; checked: true }')
        const p = make('Radio { text: "A"; type: Enums.ChoicePureCard; checked: true }')
        wait(60)
        compare(c.cardItem.color.toString(), p.cardItem.color.toString())
        c.destroy()
        p.destroy()
    }

    // ---- 按钮样式 ----

    // .semi-radioGroup-buttonRadio：组只有一层 fill-0 底 + 圆角 3（radio.scss:437-442）
    function test_buttonGroupHasFillZeroChrome() {
        const g = make('RadioGroup { type: Enums.ChoiceButton; defaultValue: 1;'
            + ' Radio { value: 1; text: "即时推送" } Radio { value: 2; text: "定时推送" } }')
        wait(60)
        const chrome = testCase.walk(g, "radioGroupChrome")[0]
        verify(chrome !== undefined, "按钮组该有那层底")
        compare(chrome.color.toString(), Theme.current.colorFill0.toString())
        compare(chrome.radius, Theme.current.radiusSmall)
        g.destroy()
    }

    // addon 的内边距与字号按 buttonSize 分三档（radio.scss:281-311 + variables.scss）
    function test_buttonSizesChangePaddingAndFontSize() {
        const small = make('RadioGroup { type: Enums.ChoiceButton;'
            + ' buttonSize: Enums.RadioButtonSmall; defaultValue: 1;'
            + ' Radio { value: 1; text: "推送" } }')
        const middle = make('RadioGroup { type: Enums.ChoiceButton;'
            + ' buttonSize: Enums.RadioButtonMiddle; defaultValue: 1;'
            + ' Radio { value: 1; text: "推送" } }')
        const large = make('RadioGroup { type: Enums.ChoiceButton;'
            + ' buttonSize: Enums.RadioButtonLarge; defaultValue: 1;'
            + ' Radio { value: 1; text: "推送" } }')
        wait(60)
        compare(radioWithValue(small, 1).addonFontSize, Theme.current.fontSizeSmall)
        compare(radioWithValue(middle, 1).addonFontSize, Theme.current.fontSizeSmall)
        compare(radioWithValue(large, 1).addonFontSize, Theme.current.fontSizeRegular)
        // small 的垂直内边距是 super-tight，middle / large 都是 extra-tight
        compare(radioWithValue(small, 1).addonPadY, Theme.current.spacingSuperTight)
        compare(radioWithValue(middle, 1).addonPadY, Theme.current.spacingExtraTight)
        compare(radioWithValue(large, 1).addonPadY, Theme.current.spacingBaseTight * 0.5)
        compare(radioWithValue(large, 1).addonPadX, Theme.current.spacingLoose)
        // 组里单项的外层内边距：三个尺寸的水平都是 extra-tight，垂直 small 才是 super-tight
        compare(radioWithValue(middle, 1).chromeLeft, Theme.current.spacingExtraTight)
        compare(radioWithValue(small, 1).buttonChromeY, Theme.current.spacingSuperTight)
        // 官网实测三档组高 24 / 32 / 40
        compare(small.implicitHeight, 24)
        compare(middle.implicitHeight, 32)
        compare(large.implicitHeight, 40)
        small.destroy()
        middle.destroy()
        large.destroy()
    }

    // 选中项：bg-3 底 + 主色字（$color-radio_addon_buttonRadio-bg-checked / -text-checked）
    function test_buttonCheckedAddonIsBgThreeWithPrimaryText() {
        const g = make('RadioGroup { type: Enums.ChoiceButton; defaultValue: 1;'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        const on = radioWithValue(g, 1)
        const off = radioWithValue(g, 2)
        compare(on.addonItem.color.toString(), Theme.current.colorPrimary.toString())
        compare(on.addonItem.parent.color.toString(), Theme.current.colorBg3.toString())
        // 未选中：透明底 + text-1
        compare(off.addonItem.color.toString(), Theme.current.colorText1.toString())
        compare(off.addonItem.parent.color.toString(), "#00000000")
        g.destroy()
    }

    function test_buttonHoverAddonFillsOne() {
        const g = make('RadioGroup { type: Enums.ChoiceButton;'
            + ' Radio { value: 1; text: "A" } }')
        wait(60)
        const item = radioWithValue(g, 1)
        hoverAt(item)
        compare(item.addonItem.parent.color.toString(), Theme.current.colorFill1.toString())
        g.destroy()
    }

    // 按钮式没有单选圈（.semi-radio-inner-buttonRadio 绝对定位 + 透明），也不渲染 extra
    function test_buttonTypeSuppressesCircleAndExtra() {
        const r = make('Radio { text: "A"; extra: "副文本"; type: Enums.ChoiceButton; checked: true }')
        wait(60)
        compare(r.innerWidth, 0)
        compare(r.gap, 0)
        verify(!r.extraItem.visible, "radio.tsx:285 的 extra && !isButtonRadio")
        r.destroy()
    }


    // 官方只在脱离组的 .semi-radio-buttonRadioComponent 上给 fill-0 底（radio.scss:77-81），
    // 组里的单项换成 -buttonRadioGroup（只有 padding，没有 background，底色在组那一层）
    function test_standaloneButtonHasFillZeroChrome() {
        const r = make('Radio { text: "A"; type: Enums.ChoiceButton }')
        wait(60)
        verify(r.buttonChromeItem.visible, "单独一颗按钮式该有自己的底")
        compare(r.buttonChromeItem.color.toString(), Theme.current.colorFill0.toString())
        const g = make('RadioGroup { type: Enums.ChoiceButton; Radio { value: 1; text: "B" } }')
        wait(60)
        verify(!radioWithValue(g, 1).buttonChromeItem.visible, "组里的单项不该再画一层底")
        r.destroy()
        g.destroy()
    }

    // radio.scss:297-300 的 -addon-buttonRadio-disabled 只有 color，没有 background
    function test_buttonDisabledKeepsBackgroundAndDimsText() {
        const g = make('RadioGroup { type: Enums.ChoiceButton; disabled: true; defaultValue: 1;'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        const on = radioWithValue(g, 1)
        const off = radioWithValue(g, 2)
        compare(off.addonItem.color.toString(), Theme.current.colorDisabledText.toString())
        compare(off.addonItem.parent.color.toString(), "#00000000")
        // 选中项禁用后背景仍是 bg-3，只是字色变主色不变？官方 -disabled 只改 color，
        // 而 -checked 的 color 是 primary，两者谁生效看后写的（radio.scss:291-300 里 disabled 在后）
        compare(on.addonItem.parent.color.toString(), Theme.current.colorBg3.toString())
        compare(on.addonItem.color.toString(), Theme.current.colorDisabledText.toString())
        g.destroy()
    }

    // 官网实测 .semi-radioGroup-buttonRadio：display:block、gap:normal、padding:0，
    // 单项 padding 4 且 :not(:last-child) 的 padding-right 收成 0（radio.scss:86 + 90-92），
    // 于是相邻两份文案正好隔 4px。第一版把通用组的 16 用在了按钮组上，间隙大得肉眼可见。
    function test_buttonGroupHasNoItemGap() {
        const g = make('RadioGroup { type: Enums.ChoiceButton; defaultValue: 1;'
            + ' Radio { value: 1; text: "即时推送" } Radio { value: 2; text: "定时推送" }'
            + ' Radio { value: 3; text: "动态推送" } }')
        wait(60)
        const items = radiosIn(g)
        compare(g.itemSpacing, 0)
        for (let i = 1; i < items.length; ++i)
            compare(items[i].x, items[i - 1].x + items[i - 1].width, "按钮式项间不留 gap")
        compare(items[0].chromeRight, 0, "非末项右侧内缩收成 0")
        compare(items[2].chromeRight, Theme.current.spacingExtraTight, "末项保留右侧内缩")
        // 相邻两个「按钮块」之间隔 4px。官方量的 .semi-radio-addon-buttonRadio 是带内边距的那层，
        // 对应本库 addonItem.parent（addonItem 是里面的 Text，量它会多算两侧 16 的文案内缩）。
        // 断言读渲染位置，不拿 chromeLeft 反推。
        for (let i = 1; i < items.length; ++i) {
            const prevPill = items[i - 1].addonItem.parent
            const curPill = items[i].addonItem.parent
            const prev = prevPill.mapToItem(g, 0, 0)
            const cur = curPill.mapToItem(g, 0, 0)
            compare(cur.x - (prev.x + prevPill.width), Theme.current.spacingExtraTight)
        }
        compare(items[2].width, items[0].width + Theme.current.spacingExtraTight)
        compare(g.implicitWidth, items[0].width + items[1].width + items[2].width)
        // 单项宽 = 左内缩 + 文案块（+ 末项的右内缩），官网那三组量出来是 84 / 84 / 88、组宽 256；
        // 绝对值取决于字体 advance，这里只钉结构
        compare(items[0].width, items[0].chromeLeft + items[0].addonWidth)
        compare(items[2].width, items[2].chromeLeft + items[2].chromeRight + items[2].addonWidth)
        g.destroy()
    }

    // 通用式与卡片式照旧吃 direction 的 gap，别把按钮式那条 0 顺手扩给它们
    function test_defaultAndCardGroupsStillUseDirectionGap() {
        const plain = make('RadioGroup { Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        const card = make('RadioGroup { type: Enums.ChoiceCard;'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        compare(plain.itemSpacing, Theme.current.spacingBase)
        compare(card.itemSpacing, Theme.current.spacingBase)
        const items = radiosIn(plain)
        compare(items[1].x - (items[0].x + items[0].width), Theme.current.spacingBase)
        plain.destroy()
        card.destroy()
    }

    // 官方不给按钮组挂 direction 类（radioGroup.tsx:167 的 !isButtonRadio）
    function test_buttonGroupIgnoresVerticalDirection() {
        const g = make('RadioGroup { type: Enums.ChoiceButton;'
            + ' direction: Enums.DirectionVertical; defaultValue: 1;'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        const items = radiosIn(g)
        compare(items[1].y, items[0].y, "按钮式竖排照样横着排")
        verify(items[1].x > items[0].x)
        g.destroy()
    }

    // 非按钮式不该有那层选中底（第一版把按钮的底色判断漏在了 type 之外）
    function test_defaultTypeAddonHasNoBackground() {
        const r = make('Radio { text: "A"; checked: true }')
        wait(60)
        compare(r.addonItem.parent.color.toString(), "#00000000")
        r.destroy()
    }

    // ---- 转发与信号 ----

    function test_toggledFiresAlongsideChanged() {
        const r = make('Radio { text: "A" }')
        wait(60)
        let toggled = 0
        r.toggled.connect(function () { toggled++ })
        mouseClick(r, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(toggled, 1)
        r.destroy()
    }

    function test_mouseEnterAndLeaveFire() {
        const r = make('Radio { text: "A" }')
        wait(60)
        let entered = 0
        let left = 0
        r.mouseEntered.connect(function () { entered++ })
        r.mouseLeft.connect(function () { left++ })
        hoverAt(r)
        compare(entered, 1)
        unhover(r)
        compare(left, 1)
        r.destroy()
    }
    // 组的 handleChange 复制了一份事件再改 target.value（radioGroupFoundation.ts:32-48），
    // 所以 advanced 取消时只有组的 onChange 看到 undefined；这一项自己的 onChange 仍是自己的
    // value（radio.tsx:162-167 传的是原事件）
    function test_itemChangedKeepsItsOwnValueInAdvancedGroup() {
        const g = make('RadioGroup { mode: "advanced"; defaultValue: 1;'
            + ' onChanged: (v) => testCase.changes.push(v);'
            + ' Radio { value: 1; text: "A" } Radio { value: 2; text: "B" } }')
        wait(60)
        const item = radioWithValue(g, 1)
        const seen = []
        item.changed.connect(function (v) { seen.push(v) })
        mouseClick(item, Qt.LeftButton, Qt.NoModifier)
        wait(60)
        compare(seen, [1], "单项的 changed 发自己的 value")
        compare(testCase.changes.length, 1)
        compare(testCase.changes[0], undefined, "组的通知才是 undefined")
        g.destroy()
    }
}
