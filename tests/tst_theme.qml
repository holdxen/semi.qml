import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Theme"
    when: windowShown
    width: 200
    height: 200

    function init() {
        // QuickTest 视图根项的 effectiveVisible 在窗口 show 后不会立即刷新
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    // ---------- 色板 ----------

    function test_scaleValues() {
        compare(Theme.current.blue[5].toString(), "#0064fa")
        compare(Theme.current.blue[0].toString(), "#eaf5ff")
        compare(Theme.current.blue[9].toString(), "#002c6b")
        compare(Theme.current.grey[0].toString(), "#f9f9f9")
        compare(Theme.current.red[5].toString(), "#f93920")
    }

    function test_scaleHasTenLevels() {
        compare(Theme.current.blue.length, 10)
        compare(Theme.current.grey.length, 10)
        compare(Theme.current.aiPurple.length, 10)
    }

    // ---------- 暗色反转（这套体系最容易做错的性质）----------

    function test_darkScaleIsInverted() {
        Theme.mode = Theme.Dark
        compare(Theme.current.grey[0].toString(), "#1c1f23")
        compare(Theme.current.grey[9].toString(), "#f9f9f9")
        compare(Theme.current.blue[5].toString(), "#54a9ff")
        compare(Theme.current.red[5].toString(), "#fc725a")
    }

    // ---------- 语义色由色阶派生 ----------

    function test_semanticDerivedFromScale() {
        compare(Theme.current.colorPrimary.toString(), "#0064fa")
        compare(Theme.current.colorPrimaryHover.toString(), "#0062d6")
        compare(Theme.current.colorPrimaryActive.toString(), "#004fb3")
        compare(Theme.current.colorDanger.toString(), "#f93920")
    }

    function test_changingScaleUpdatesSemantics() {
        const patched = Theme.light.blue.slice()
        patched[5] = "#7c3aed"
        Theme.light.blue = patched

        compare(Theme.light.colorPrimary.toString(), "#7c3aed")
        // 只改了 5，其余档位保持
        compare(Theme.light.colorPrimaryHover.toString(), "#0062d6")
    }

    function test_overrideWinsOverDerivation() {
        Theme.light.colorPrimary = "#abcdef"

        const patched = Theme.light.blue.slice()
        patched[5] = "#ff0000"
        Theme.light.blue = patched

        compare(Theme.light.colorPrimary.toString(), "#abcdef")
    }

    // ---------- customize ----------

    function test_customizeAppliesToBothModes() {
        Theme.customize({ colorPrimary: "#123456" })
        compare(Theme.light.colorPrimary.toString(), "#123456")
        compare(Theme.dark.colorPrimary.toString(), "#123456")
    }

    function test_customizeOnlyTouchesGivenTokens() {
        const dangerBefore = Theme.light.colorDanger.toString()
        const radiusBefore = Theme.light.radiusSmall
        const textBefore = Theme.light.colorText0.toString()

        Theme.customize({ colorPrimary: "#123456" })

        compare(Theme.light.colorDanger.toString(), dangerBefore)
        compare(Theme.light.radiusSmall, radiusBefore)
        compare(Theme.light.colorText0.toString(), textBefore)
    }

    function test_customizeSizingAndRadius() {
        Theme.customize({ radiusSmall: 12, spacingBase: 20, fontSizeRegular: 15 })
        compare(Theme.light.radiusSmall, 12)
        compare(Theme.light.spacingBase, 20)
        compare(Theme.light.fontSizeRegular, 15)
        // 未指定的圆角不受影响
        compare(Theme.light.radiusLarge, 12)
    }

    function test_customizeLightOnly() {
        Theme.customizeLight({ colorPrimary: "#0f9d58" })
        compare(Theme.light.colorPrimary.toString(), "#0f9d58")
        compare(Theme.dark.colorPrimary.toString(), "#54a9ff")
    }

    function test_unknownTokenIsIgnored() {
        Theme.customize({ notAToken: "#000000", colorPrimary: "#0f9d58" })
        compare(Theme.light.colorPrimary.toString(), "#0f9d58")
    }

    // ---------- reset ----------

    function test_resetRestoresDefaults() {
        Theme.customize({ colorPrimary: "#123456", radiusSmall: 99, spacingBase: 7 })
        Theme.reset()

        compare(Theme.light.colorPrimary.toString(), "#0064fa")
        compare(Theme.light.radiusSmall, 3)
        compare(Theme.light.spacingBase, 16)
    }

    function test_resetClearsOverride() {
        Theme.light.colorPrimary = "#abcdef"
        Theme.light.blue = ["#000000", "#111111", "#222222", "#333333", "#444444",
                            "#555555", "#666666", "#777777", "#888888", "#999999"]
        Theme.reset()

        // 覆盖被清除后，重新回到「由色阶派生」
        compare(Theme.light.colorPrimary.toString(), "#0064fa")
        compare(Theme.light.blue[5].toString(), "#0064fa")
    }

    // ---------- 明暗切换 ----------

    function test_modeSelectsCurrent() {
        Theme.mode = Theme.Light
        verify(Theme.current === Theme.light)

        Theme.mode = Theme.Dark
        verify(Theme.current === Theme.dark)
    }

    function test_lightAndDarkAreIndependentObjects() {
        verify(Theme.light !== Theme.dark)
        compare(Theme.light.colorBg0.toString(), "#ffffff")
        compare(Theme.dark.colorBg0.toString(), "#16161a")
    }

    // ---------- 令牌完整性抽查 ----------

    function test_otherTokenGroups() {
        // 圆角
        compare(Theme.current.radiusExtraSmall, 3)
        compare(Theme.current.radiusMedium, 6)
        compare(Theme.current.radiusLarge, 12)
        // 尺寸
        compare(Theme.current.heightControlSmall, 24)
        compare(Theme.current.heightControlDefault, 32)
        compare(Theme.current.heightControlLarge, 40)
        compare(Theme.current.widthIconMedium, 16)
        // 字体
        compare(Theme.current.fontSizeSmall, 12)
        compare(Theme.current.fontSizeRegular, 14)
        compare(Theme.current.fontWeightBold, 600)
        // z-index
        compare(Theme.current.zTooltip, 1060)
        compare(Theme.current.zModal, 1000)
        // 动效（源库默认全 0ms）
        compare(Theme.current.durationFast, 0)
        compare(Theme.current.durationNormal, 0)
        compare(Theme.current.easingEaseIn, "ease-in")
    }

    function test_bindingFollowsTokenChange() {
        // 组件读的是 Theme.current.xxx，令牌一变绑定要跟着刷新
        const probe = Qt.createQmlObject(
            "import QtQuick; import Semi; QtObject { property color c: Theme.current.colorPrimary }",
            testCase, "probe")

        compare(probe.c.toString(), "#0064fa")
        Theme.customize({ colorPrimary: "#0f9d58" })
        compare(probe.c.toString(), "#0f9d58")
        probe.destroy()
    }
}
