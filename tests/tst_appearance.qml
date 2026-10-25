import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Appearance"
    when: windowShown
    width: 200
    height: 200

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    // ---------- 状态收敛 ----------

    function test_statePriority() {
        compare(Appearance.state(false, true, true), Enums.Disabled)
        compare(Appearance.state(true, true, true), Enums.Pressed)
        compare(Appearance.state(true, true, false), Enums.Hovered)
        compare(Appearance.state(true, false, false), Enums.Normal)
    }

    // ---------- solid ----------

    function test_solidPrimary() {
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Solid, Enums.Normal).toString(), "#0064fa")
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Solid, Enums.Hovered).toString(), "#0062d6")
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Solid, Enums.Pressed).toString(), "#004fb3")
        compare(Appearance.buttonForeground(Theme.current, Enums.Primary, Enums.Solid, Enums.Normal).toString(), "#ffffff")
    }

    function test_solidDanger() {
        compare(Appearance.buttonBackground(Theme.current, Enums.Danger, Enums.Solid, Enums.Normal).toString(), "#f93920")
        compare(Appearance.buttonForeground(Theme.current, Enums.Danger, Enums.Solid, Enums.Normal).toString(), "#ffffff")
    }

    function test_solidTertiaryUsesWhiteText() {
        compare(Appearance.buttonBackground(Theme.current, Enums.Tertiary, Enums.Solid, Enums.Normal).toString(),
                Theme.current.colorTertiary.toString())
        compare(Appearance.buttonForeground(Theme.current, Enums.Tertiary, Enums.Solid, Enums.Normal).toString(), "#ffffff")
    }

    // ---------- light：背景不看色调，一律 fill-0/1/2 ----------

    function test_lightVariantIgnoresTone() {
        const fill0 = Theme.current.colorFill0.toString()
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Light, Enums.Normal).toString(), fill0)
        compare(Appearance.buttonBackground(Theme.current, Enums.Danger, Enums.Light, Enums.Normal).toString(), fill0)
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Light, Enums.Hovered).toString(),
                Theme.current.colorFill1.toString())
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Light, Enums.Pressed).toString(),
                Theme.current.colorFill2.toString())
        // 前景仍取各自色调
        compare(Appearance.buttonForeground(Theme.current, Enums.Danger, Enums.Light, Enums.Normal).toString(), "#f93920")
    }

    // ---------- borderless / outline ----------

    function test_borderless() {
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Borderless, Enums.Normal).toString(), "#00000000")
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Borderless, Enums.Hovered).toString(),
                Theme.current.colorFill0.toString())
        compare(Appearance.buttonForeground(Theme.current, Enums.Primary, Enums.Borderless, Enums.Normal).toString(), "#0064fa")
    }

    function test_outlineBorder() {
        compare(Appearance.buttonBorderWidth(Enums.Outline), 1)
        compare(Appearance.buttonBorderWidth(Enums.Solid), 0)
        compare(Appearance.buttonBorderWidth(Enums.Light), 0)

        // primary / secondary / tertiary 用通用描边色
        compare(Appearance.buttonBorderColor(Theme.current, Enums.Primary, Enums.Outline, Enums.Normal).toString(),
                Theme.current.colorBorder.toString())
        // danger / warning 用自身色描边
        compare(Appearance.buttonBorderColor(Theme.current, Enums.Danger, Enums.Outline, Enums.Normal).toString(), "#f93920")
        compare(Appearance.buttonBorderColor(Theme.current, Enums.Warning, Enums.Outline, Enums.Normal).toString(), "#fc8800")
        // 非 outline 形态没有边框
        compare(Appearance.buttonBorderColor(Theme.current, Enums.Danger, Enums.Solid, Enums.Normal).toString(), "#00000000")
    }

    function test_tertiaryNonSolidUsesSecondaryText() {
        compare(Appearance.buttonForeground(Theme.current, Enums.Tertiary, Enums.Borderless, Enums.Normal).toString(),
                Theme.current.colorText1.toString())
        compare(Appearance.buttonForeground(Theme.current, Enums.Tertiary, Enums.Outline, Enums.Normal).toString(),
                Theme.current.colorText1.toString())
    }

    // ---------- 禁用 ----------

    function test_disabled() {
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Solid, Enums.Disabled).toString(),
                Theme.current.colorDisabledBg.toString())
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Light, Enums.Disabled).toString(),
                Theme.current.colorFill0.toString())
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Borderless, Enums.Disabled).toString(), "#00000000")
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Outline, Enums.Disabled).toString(), "#00000000")
        compare(Appearance.buttonForeground(Theme.current, Enums.Primary, Enums.Solid, Enums.Disabled).toString(),
                Theme.current.colorDisabledText.toString())
        // 禁用时 outline 仍是通用描边色
        compare(Appearance.buttonBorderColor(Theme.current, Enums.Danger, Enums.Outline, Enums.Disabled).toString(),
                Theme.current.colorBorder.toString())
    }

    // ---------- 尺寸 ----------

    function test_sizes() {
        compare(Appearance.buttonHeight(Theme.current, Enums.Small), 24)
        compare(Appearance.buttonHeight(Theme.current, Enums.Default), 32)
        compare(Appearance.buttonHeight(Theme.current, Enums.Large), 40)

        compare(Appearance.buttonPaddingVertical(Theme.current, Enums.Small), 2)
        compare(Appearance.buttonPaddingVertical(Theme.current, Enums.Default), 6)
        compare(Appearance.buttonPaddingVertical(Theme.current, Enums.Large), 10)

        compare(Appearance.buttonPaddingHorizontal(Theme.current, Enums.Small), 12)
        compare(Appearance.buttonPaddingHorizontal(Theme.current, Enums.Default), 12)
        compare(Appearance.buttonPaddingHorizontal(Theme.current, Enums.Large), 16)

        compare(Appearance.buttonFontSize(Theme.current, Enums.Small), 14)
        compare(Appearance.buttonFontSize(Theme.current, Enums.Large), 14)
    }

    // ---------- 焦点环 ----------

    function test_focusRing() {
        // 基规则不分 type 一律 primary；danger / warning 只在 solid 与 outline 下换自身色
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Primary, Enums.Solid).toString(),
                Theme.current.colorPrimaryLightActive.toString())
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Secondary, Enums.Solid).toString(),
                Theme.current.colorPrimaryLightActive.toString())
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Tertiary, Enums.Light).toString(),
                Theme.current.colorPrimaryLightActive.toString())
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Danger, Enums.Solid).toString(),
                Theme.current.colorDangerLightActive.toString())
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Warning, Enums.Outline).toString(),
                Theme.current.colorWarningLightActive.toString())
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Danger, Enums.Light).toString(),
                Theme.current.colorPrimaryLightActive.toString())
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Warning, Enums.Borderless).toString(),
                Theme.current.colorPrimaryLightActive.toString())
    }

    function test_groupLineFollowsThemeThenType() {
        // .semi-button-group-line-* 同特异度、后来的赢：light 与 borderless 压过 type 与 disabled
        compare(Appearance.buttonGroupLine(Theme.current, Enums.Primary, Enums.Light, Enums.Normal),
                Theme.current.colorFill0)
        compare(Appearance.buttonGroupLine(Theme.current, Enums.Primary, Enums.Borderless, Enums.Normal).toString(),
                "#00000000")
        compare(Appearance.buttonGroupLine(Theme.current, Enums.Danger, Enums.Solid, Enums.Normal),
                Theme.current.colorDanger)
        compare(Appearance.buttonGroupLine(Theme.current, Enums.Danger, Enums.Solid, Enums.Disabled),
                Theme.current.colorDisabledBg)
        compare(Appearance.buttonGroupLine(Theme.current, Enums.Primary, Enums.Light, Enums.Disabled),
                Theme.current.colorFill0)
    }

    // ---------- 跟随主题 ----------

    function test_followsCustomTheme() {
        Theme.customize({ colorPrimary: "#7c3aed" })
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Solid, Enums.Normal).toString(), "#7c3aed")
    }

    function test_darkMode() {
        Theme.mode = Theme.Dark
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Solid, Enums.Normal).toString(), "#54a9ff")
        // 注意：暗色下 color-white 本身就不是纯白（Semi 定义为 #e4e7f5），白字按钮跟着它走
        compare(Appearance.buttonForeground(Theme.current, Enums.Primary, Enums.Solid, Enums.Normal).toString(),
                Theme.current.colorWhite.toString())
        compare(Theme.current.colorWhite.toString(), "#e4e7f5")
    }

    function test_darkModeDisabled() {
        Theme.mode = Theme.Dark
        // disabled-bg 引用 grey-1，暗色下是深灰 #2e3238 —— 不该在暗背景上显出浅色块
        compare(Theme.current.colorDisabledBg.toString(), "#2e3238")
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Solid, Enums.Disabled).toString(), "#2e3238")
        compare(Appearance.buttonForeground(Theme.current, Enums.Primary, Enums.Solid, Enums.Disabled).toString(),
                "#59f9f9f9")   // QColor 对带 alpha 的颜色输出 #AARRGGBB，0x59 = 0.35
        // light 形态的禁用底是 fill-0，暗色下是白色 12% 透明
        compare(Appearance.buttonBackground(Theme.current, Enums.Primary, Enums.Light, Enums.Disabled).toString(),
                Theme.current.colorFill0.toString())
    }

    // ---------- TagInput 自己的描边规则 ----------

    // tagInput.scss:77-105：默认态只有聚焦才画边（跟 Input 的「平时也有 border」相反），
    // warning / danger 平时是浅色边、聚焦换实色。
    function test_tagInputBorderFollowsStateAndStatus() {
        const t = Theme.current
        compare(Appearance.tagInputBorder(t, Enums.Normal, Enums.StatusDefault).toString(), "#00000000")
        compare(Appearance.tagInputBorder(t, Enums.Hovered, Enums.StatusDefault).toString(), "#00000000")
        compare(Appearance.tagInputBorder(t, Enums.Disabled, Enums.StatusDefault).toString(), "#00000000")
        compare(Appearance.tagInputBorder(t, Enums.Focused, Enums.StatusDefault).toString(),
                t.colorFocusBorder.toString())

        compare(Appearance.tagInputBorder(t, Enums.Normal, Enums.StatusWarning).toString(),
                t.colorWarningLightDefault.toString())
        compare(Appearance.tagInputBorder(t, Enums.Hovered, Enums.StatusWarning).toString(),
                t.colorWarningLightHover.toString())
        compare(Appearance.tagInputBorder(t, Enums.Focused, Enums.StatusWarning).toString(),
                t.colorWarning.toString())

        compare(Appearance.tagInputBorder(t, Enums.Normal, Enums.StatusDanger).toString(),
                t.colorDangerLightDefault.toString())
        compare(Appearance.tagInputBorder(t, Enums.Hovered, Enums.StatusDanger).toString(),
                t.colorDangerLightHover.toString())
        compare(Appearance.tagInputBorder(t, Enums.Focused, Enums.StatusDanger).toString(),
                t.colorDanger.toString())
    }

    // ---------- 组件与解析结果保持一致 ----------

    function test_buttonComponentMatchesAppearance() {
        const button = Qt.createQmlObject(
            "import Semi; Button { text: \"x\"; tone: Enums.Danger; variant: Enums.Outline }",
            testCase, "btn")

        compare(button.color.toString(), Appearance.buttonBackground(Theme.current, Enums.Danger, Enums.Outline, Enums.Normal).toString())
        compare(button.implicitHeight, Appearance.buttonHeight(Theme.current, Enums.Default))
        button.destroy()
    }

    // 这条是回归测试：Appearance 是 C++ 函数调用，QML 追踪不到它内部读的令牌，
    // 组件必须显式依赖令牌版本才能跟着主题变
    function test_buttonFollowsModeChange() {
        const button = Qt.createQmlObject(
            "import Semi; Button { text: \"x\" }", testCase, "btnMode")
        const before = button.color.toString()
        Theme.mode = Theme.Dark
        verify(button.color.toString() !== before,
               "按钮颜色应随明暗切换更新（before=" + before + " after=" + button.color.toString() + "）")
        button.destroy()
    }

    function test_buttonFollowsCustomize() {
        // 默认是 light 形态、底色 fill-0 跟 primary 无关，所以拿 solid 形态来验
        const button = Qt.createQmlObject(
            "import Semi; Button { text: \"x\"; variant: Enums.Solid }", testCase, "btnCustom")
        const before = button.color.toString()
        Theme.customize({ colorPrimary: "#7c3aed" })
        verify(button.color.toString() !== before,
               "按钮颜色应随 customize 更新（before=" + before + " after=" + button.color.toString() + "）")
        button.destroy()
    }
}
