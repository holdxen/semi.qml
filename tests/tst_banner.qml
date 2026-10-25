import QtQuick
import QtTest
import Semi

// Banner 通知横幅。规格照 semi-ui/banner/index.tsx 与 semi-foundation/banner
// （banner.scss + variables.scss，编译结果 semi.css:3196-3240）。
// 期望值里 12 / 20 / 24 / 2 / 8 / 3 / 1 与那四个默认图标名都直接写死，
// 改坏组件里的令牌或算式就会红。行高不吃死值（字体在 offscreen 与 cocoa 下量得不一样），
// 只断「描述顶边 − 标题底边 == 2」这类相对关系。
TestCase {
    id: testCase

    name: "Banner"
    when: windowShown
    width: 900
    height: 600

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    // findChild 摸不到 Repeater 代理，但这里的子项都是声明式的，直接找即可
    function part(root, name) {
        return testCase.findChild(root, name)
    }

    // ---------------------------------------------------------------- 属性面

    function test_bannerDefaults() {
        const b = make("Banner { }")
        compare(b.tone, Enums.Info)                     // defaultProps index.tsx:56
        compare(b.fullMode, true)                       // defaultProps index.tsx:57
        compare(b.bordered, false, "官方 bordered 缺省 false")
        compare(b.closable, true, "官方 close 键是恒渲染的，除非 closeIcon={null}")
        compare(b.iconShown, true)
        compare(b.bannerVisible, true, "官方 state.visible 初值 true")
        compare(b.Accessible.role, Accessible.Alert, "官方 role=\"alert\"")
        compare(b.title, "")
        compare(b.description, "")
        compare(b.implicitWidth, 480)
        b.destroy()
    }

    function test_bannerTones() {
        const warn = make("Banner { tone: Enums.Warning }")
        compare(warn.fill.toString(), Theme.current.colorWarningLightDefault.toString())
        compare(warn.accent.toString(), Theme.current.colorWarning.toString())
        warn.destroy()

        const danger = make("Banner { tone: Enums.Danger }")
        compare(danger.accent.toString(), Theme.current.colorDanger.toString())
        danger.destroy()

        const ok = make("Banner { tone: Enums.Success }")
        compare(ok.accent.toString(), Theme.current.colorSuccess.toString())
        ok.destroy()
    }

    // 默认图标按色调取（index.tsx:126-133）
    function test_defaultIconPerTone_data() {
        return [
            { tag: "info", tone: Enums.Info, name: "info_circle" },
            { tag: "warning", tone: Enums.Warning, name: "alert_triangle" },
            { tag: "danger", tone: Enums.Danger, name: "alert_circle" },
            { tag: "success", tone: Enums.Success, name: "tick_circle" }
        ]
    }

    function test_defaultIconPerTone(data) {
        const b = make("Banner { tone: " + data.tone + " }")
        compare(part(b, "bannerIcon").name, data.name)
        compare(part(b, "bannerIcon").size, 20, "size='large' ⇒ 20（Icon.tsx:23）")
        compare(part(b, "bannerIcon").color.toString(), b.accent.toString(),
            "本色只落到图标上")
        b.destroy()
    }

    function test_iconOverrideAndHide() {
        const custom = make("Banner { iconName: 'home' }")
        compare(part(custom, "bannerIcon").name, "home")
        custom.destroy()

        const hidden = make("Banner { iconShown: false }")
        compare(part(hidden, "bannerIcon").visible, false, "官方 icon={null}")
        compare(part(hidden, "bannerGroup").width, part(hidden, "bannerBody").width,
            "图标不占位了，正文从 0 起")
        hidden.destroy()

        const hiddenNamed = make("Banner { iconShown: false; iconName: 'home' }")
        compare(part(hiddenNamed, "bannerIcon").visible, false,
            "iconShown 优先，给了名字也不画")
        hiddenNamed.destroy()
    }

    // ---------------------------------------------------------------- 外壳几何

    function test_paddingAndClosePlacement() {
        const b = make("Banner { width: 640; description: '一段说明' }")
        const row = part(b, "bannerContent")
        compare(row.x, 12, "$spacing-banner-paddingX")
        compare(row.y, 12, "$spacing-banner-paddingY")
        compare(row.width, 616, "640 − 左右各 12")

        const close = part(b, "bannerClose")
        compare(close.width, 24, "$width-banner_closeBtn")
        compare(close.height, 24, "$height-banner_closeBtn")
        compare(close.x, 640 - 12 - 24)
        compare(close.y, 12)
        compare(close.tone, Enums.Tertiary, "index.tsx:112-118 borderless + small + tertiary")
        compare(close.variant, Enums.Borderless)
        compare(close.size, Enums.Small)
        compare(close.Accessible.name, "Close", "官方 aria-label='Close'")
        b.destroy()
    }

    function test_radiusAndBorderOnlyInNonFull() {
        const full = make("Banner { width: 640; description: 'x' }")
        const fullSkin = part(full, "bannerSkin")
        compare(fullSkin.radius, 0, "圆角只在 -in-container 那条规则里")
        compare(fullSkin.border.width, 0)
        full.destroy()

        const plain = make("Banner { width: 640; fullMode: false; description: 'x' }")
        compare(part(plain, "bannerSkin").radius, 3, "$radius-banner = border-radius-small")
        compare(part(plain, "bannerSkin").border.width, 0, "bordered 缺省 false")
        plain.destroy()

        const bordered = make("Banner { width: 640; fullMode: false; bordered: true; description: 'x' }")
        compare(part(bordered, "bannerSkin").border.width, 1, "$width-banner-border")
        compare(part(bordered, "bannerSkin").border.color.toString(),
            Theme.current.colorInfo.toString())
        bordered.destroy()

        // 全屏那支即使写 bordered 也不给描边（选择器是 !fullMode && bordered）
        const fullBordered = make("Banner { width: 640; bordered: true; description: 'x' }")
        compare(part(fullBordered, "bannerSkin").border.width, 0)
        compare(part(fullBordered, "bannerSkin").radius, 0)
        fullBordered.destroy()
    }

    function test_backgroundFollowsTone() {
        const info = make("Banner { width: 640 }")
        compare(part(info, "bannerSkin").color.toString(),
            Theme.current.colorInfoLightDefault.toString())
        info.destroy()

        const danger = make("Banner { width: 640; tone: Enums.Danger }")
        compare(part(danger, "bannerSkin").color.toString(),
            Theme.current.colorDangerLightDefault.toString())
        danger.destroy()
    }

    // ---------------------------------------------------------------- 两种排版

    function test_fullModeCentresGroupAndPutsTextsOnOneRow() {
        const b = make("Banner { width: 640; title: '标题'; description: '描述' }")
        const row = part(b, "bannerContent")
        const group = part(b, "bannerGroup")
        compare(group.x, (row.width - group.width) / 2, "justify-content: center")

        const title = part(b, "bannerTitle")
        const desc = part(b, "bannerDescription")
        compare(desc.x, title.width, "content-body 是 display:flex ⇒ 标题与描述并排")
        compare(desc.y > 0 || desc.height >= title.height, true, "并排时按 align-items:center 居中")
        compare(title.font.pixelSize, 18, "Typography.Title heading=5")
        compare(title.font.weight, Font.DemiBold, "h5 是 600")
        compare(desc.font.pixelSize, 14, "Typography.Paragraph")
        compare(title.color.toString(), Theme.current.colorText0.toString(),
            "标题不是本色：.semi-typography 自己写了 color")
        compare(desc.color.toString(), Theme.current.colorText0.toString())
        b.destroy()
    }

    function test_nonFullStacksTextsWithTwoPixelGap() {
        const b = make("Banner { width: 640; fullMode: false; title: '标题'; description: '描述' }")
        const group = part(b, "bannerGroup")
        compare(group.x, 0, "非全屏左对齐")

        const title = part(b, "bannerTitle")
        const desc = part(b, "bannerDescription")
        const body = part(b, "bannerBody")
        compare(desc.x, 0, "非全屏是块级 ⇒ 描述另起一行")
        compare(desc.y - (title.y + title.height), 2, "$spacing-banner_title_description-marginTop")
        compare(title.width, body.width, "正文吃掉剩余宽度")
        compare(body.width, 640 - 12 * 2 - 20 - 12 - 24 - 12,
            "减掉内边距、图标与其右距、关闭键与其左距")
        b.destroy()
    }

    function test_iconGapOnlyWhenIconShown() {
        const withIcon = make("Banner { width: 640; description: 'x' }")
        compare(part(withIcon, "bannerBody").x, 20 + 12, "$spacing-banner_icon-marginRight")
        withIcon.destroy()

        const without = make("Banner { width: 640; iconShown: false; description: 'x' }")
        compare(part(without, "bannerBody").x, 0)
        without.destroy()
    }

    function test_rowHeightFollowsTheTallestChild() {
        // 只有图标时行高由图标撑（CSS 那行 flex 取最高孩子）
        const only = make("Banner { width: 640; iconName: 'home' }")
        compare(part(only, "bannerContent").height, 20)
        compare(only.implicitHeight, 12 + 20 + 12)
        only.destroy()

        // 关掉关闭键要把那 24+12 还给正文（contentRow 恒是内边距之内的整幅，宽度看 body）
        const withClose = make("Banner { width: 640; fullMode: false; iconShown: false; description: 'x' }")
        compare(part(withClose, "bannerBody").width, 640 - 12 * 2 - 24 - 12)
        withClose.destroy()

        const closeless = make("Banner { width: 640; fullMode: false; iconShown: false;"
            + " closable: false; description: 'x' }")
        compare(part(closeless, "bannerContent").width, 616, "内容行始终是内边距之内的整幅")
        compare(part(closeless, "bannerBody").width, 616, "关闭键不占位了，宽度要还给正文")
        closeless.destroy()
    }

    // ---------------------------------------------------------------- children

    function test_extraChildrenRow() {
        const bare = make("Banner { width: 640; description: 'x' }")
        const bareExtra = part(bare, "bannerExtra")
        compare(bareExtra.visible, false, "官方没 children 就不生成 -extra 那层")
        compare(bare.extraTaken, false)
        bare.destroy()

        const withExtra = make("Banner { width: 640; description: 'x'\n"
            + "    Row { Button { text: 'No, thanks.' } Button { text: 'Sounds great!' } }\n"
            + "}")
        const extra = part(withExtra, "bannerExtra")
        compare(extra.visible, true)
        compare(withExtra.extraTaken, true)
        const row = part(withExtra, "bannerContent")
        compare(extra.y - (row.y + row.height), 8, "$spacing-banner_extra-marginTop")
        compare(extra.width, 640 - 12 * 2)
        compare(withExtra.implicitHeight, 12 + row.height + 8 + extra.implicitHeight + 12)
        withExtra.destroy()
    }

    // ---------------------------------------------------------------- 关闭

    function test_closeNotifiesThenHides() {
        const b = make("Banner { width: 640; description: 'x' }")
        let count = 0
        let visibleWhenClosed = null
        b.closed.connect(function () { count++; visibleWhenClosed = b.bannerVisible })
        mouseClick(part(b, "bannerClose"))
        wait(40)
        compare(count, 1)
        compare(visibleWhenClosed, true, "foundation.ts:19-22 先 notifyClose 再 setVisible(false)")
        compare(b.bannerVisible, false)
        compare(b.visible, false)
        compare(b.implicitHeight, 0, "官方是整棵子树卸载")
        b.destroy()
    }

    function test_closeButtonAbsentWhenNotClosable() {
        // 先证明这条路径本身是通的，再断 closable=false 时它不动
        const live = make("Banner { width: 640; description: 'x' }")
        let liveCount = 0
        live.closed.connect(function () { liveCount++ })
        mouseClick(part(live, "bannerClose"))
        wait(40)
        compare(liveCount, 1, "同一个点击在放行时是能出信号的")
        live.destroy()

        const b = make("Banner { width: 640; closable: false; description: 'x' }")
        let count = 0
        b.closed.connect(function () { count++ })
        compare(part(b, "bannerClose").visible, false, "官方 closeIcon={null}")
        mouseClick(part(b, "bannerClose"))
        wait(40)
        compare(count, 0, "关掉之后点不到也不该发 closed")
        compare(b.bannerVisible, true)
        b.destroy()
    }

    function test_callerControlledVisibilityStillNotifies() {
        // 官方 基本用法 那节：app 拿着 state 控挂载。调用方绑了 visible 之后，
        // 组件内部的 bannerVisible 就不再决定显隐，得自己在 onClosed 里翻开关
        const b = make("Banner { id: root; width: 640; description: 'x'; visible: root.flag\n"
            + "    property bool flag: true\n"
            + "    onClosed: root.flag = false }")
        wait(20)
        compare(b.visible, true)
        mouseClick(part(b, "bannerClose"))
        wait(40)
        compare(b.visible, false, "调用方的开关接住了")
        b.destroy()
    }

    // ---------------------------------------------------------------- 其它

    function test_followsTheme() {
        const b = make("Banner { width: 640; description: 'x' }")
        const before = b.fill.toString()
        Theme.mode = Theme.Dark
        verify(b.fill.toString() !== before, "横幅底色应随主题变")
        compare(part(b, "bannerSkin").color.toString(), b.fill.toString(),
            "皮肤项是跟着 fill 走的，不是缓存值")
        Theme.mode = Theme.Light
        b.destroy()
    }
}
