import QtQuick
import QtQuick.Controls as C
import QtQuick.Window
import QtTest
import Semi

// Popover 的用例。规格逐条出处写在 src/Popover.qml 的文件头。
//
// Popover 是「换皮的 Tooltip」（官方 popover/index.tsx 就是把一切转交 Tooltip），
// 所以这份用例分两半：
//   · 前半逐个核对 popover 档**改掉的那些缺省值**（showArrow / position / zIndex / closeOnEsc /
//     disableFocusListener / spacing / padding / 皮肤色与阴影 / 箭头 24×8 / 最小 36×36），
//     并且每次都和同一档的 Tooltip 对照 —— 只写「值等于多少」看不出是 Popover 还是 Tooltip；
//   · 后半是继承来的触发模型在 popover 缺省档下的实际行为（hover 50ms、卡片算悬停、
//     click 才发点外关闭、custom 只发信号、Esc 关层并把焦点送回 target）。
//
// 跑法（本仓约定，优先 offscreen）：
//   QT_QPA_PLATFORM=offscreen ./build/debug/tests/tst_semi -input tests/tst_popover.qml
TestCase {
    id: testCase

    name: "Popover"
    when: windowShown
    width: 900
    height: 700

    // 附加属性只能在 QML 语法里取（JS 里 testCase.Window.window 是 undefined）
    readonly property var win: Window.window

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; import QtQuick.Controls as C; " + qml,
            testCase, "probe")
    }

    // 公共宿主：一块可聚焦的 target + 一只 Popover + 计数用的三个信号 + 第三块可聚焦项。
    // 内容缺省是 60×20 的 Rectangle —— 60 而不是 100 是有意的：target 宽 100，
    // 卡片若与 target 同宽，BottomLeft / BottomRight（边对齐）会算出同一个 x，
    // 断言就分不出这两档了。
    // thief 是给「回焦点」那几条用的：卡片隐掉时 Qt 自己会找下一家，焦点先放在这张
    // 与卡片无关的项上，才分得出「组件主动送回 target」与「Qt 顺手捡回来」。
    // motion 一律先关：进出场那 100ms 会让 visible / 几何读数抢跑，只有看动画的用例才打开。
    function makeHost(popAttrs, popChildren) {
        return make("Item { id: root; width: 800; height: 600;"
            + " property var popRef: pop; property Item tgtRef: tgt; property Item thiefRef: thief;"
            + " property int opens: 0; property int outsideHits: 0; property int escHits: 0;"
            + " property bool holdVisible: false;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40;"
            + "     color: '#eeeeee'; focusPolicy: Qt.StrongFocus }"
            + " Rectangle { id: thief; x: 30; y: 520; width: 40; height: 20;"
            + "     color: '#dddddd'; focusPolicy: Qt.StrongFocus }"
            + " Popover { id: pop; target: tgt; motion: false;"
            + (popAttrs === undefined ? "" : " " + popAttrs + ";")
            + " onVisibleChanged: if (pop.visible) root.opens++;"
            + " onEscKeyDown: root.escHits++;"
            + " onClickedOutside: root.outsideHits++;"
            + (popChildren === undefined
                ? " Rectangle { objectName: 'popBody'; width: 60; height: 20; color: '#cfd4de' }"
                : " " + popChildren)
            + " } }")
    }

    function popOf(host) {
        return host.popRef
    }

    // C.Popup 不是 Item，contentItem / background 得这么摸
    function arrowOf(pop) {
        const kids = pop.background.children
        for (let i = 0; i < kids.length; ++i)
            if (kids[i].objectName === "popupArrow")
                return kids[i]
        return null
    }

    function labelOf(pop) {
        return pop.background.children.filter(function (c) {
            return c.objectName === "tooltipLabel"
        })[0]
    }

    // 卡片里那个 60×20 的内容项（contentItem 是个 Column）
    function bodyOf(pop) {
        return pop.contentItem.children.filter(function (c) {
            return c.objectName === "popBody"
        })[0]
    }

    function hoverOver(item, x, y) {
        const p = item.mapToItem(testCase.win.contentItem, x, y)
        mouseMove(testCase.win.contentItem, p.x, p.y)
    }

    function clickOn(item, x, y, button) {
        const p = item.mapToItem(testCase.win.contentItem, x, y)
        mouseClick(testCase.win.contentItem, p.x, p.y,
            button === undefined ? Qt.LeftButton : button)
    }

    // 指针挪到窗口的右下角：所有宿主里的 target 与卡片都碰不到
    function away() {
        mouseMove(testCase.win.contentItem, 880, 690)
    }

    function clickInCard(pop, dx, dy) {
        const p = pop.parent.mapToItem(testCase.win.contentItem, pop.x + dx, pop.y + dy)
        mouseClick(testCase.win.contentItem, p.x, p.y)
    }

    function hoverInCard(pop, dx, dy) {
        const p = pop.parent.mapToItem(testCase.win.contentItem, pop.x + dx, pop.y + dy)
        mouseMove(testCase.win.contentItem, p.x, p.y)
    }

    // target 在 (300,250,100,40)：中心 (350,270)，右边 400、下边 290
    readonly property real tgtMiddleX: 350
    readonly property real tgtMiddleY: 270

    // ---------------------------------------------------------------- 官方缺省值
    function test_officialDefaultProps() {
        const host = makeHost()
        const pop = popOf(host)
        compare(pop.showArrow, false, "popover 档把 tooltip 的 showArrow:true 改成 false")
        compare(pop.position, Enums.Bottom, "官方 position 缺省 bottom（tooltip 是 top）")
        compare(pop.effectivePlacement, Enums.Bottom)
        compare(pop.zIndex, 1030, "numbers.DEFAULT_Z_INDEX 在 popover 档是 1030")
        compare(pop.z, 1030, "z 要真的接上 zIndex")
        compare(pop.closeOnEsc, true, "popover 档缺省 closeOnEsc:true")
        compare(pop.disableFocusListener, true, "hover 档那对 focus/blur 默认被关掉")
        compare(pop.trigger, "hover")
        // motion / autoAdjustOverflow 要在裸实例上读：makeHost 那一只把 motion 关了
        // （进出场那 100ms 会让几何读数抢跑），这里断的是组件自己的缺省值
        const bare = make("Popover { }")
        compare(bare.motion, true, "官方 motion 缺省 true")
        compare(bare.autoAdjustOverflow, true)
        bare.destroy()
        compare(pop.arrowPointAtCenter, true, "文档 API 表：缺省 true")
        compare(pop.condition, true)
        compare(pop.margin, 0)
        compare(pop.keepDOM === undefined, true, "keepDOM 不落 QML")
        // 一只 Tooltip 摆在同一档上，这几条必须和上面相反 —— 否则说明 Popover
        // 压根没改写缺省值，继承来的那份 tooltip 配置原样漏了出来
        const tip = make('Tooltip { text: "x" }')
        compare(tip.showArrow, true)
        compare(tip.position, Enums.Top)
        compare(tip.zIndex, 1060)
        compare(tip.closeOnEsc, false)
        compare(tip.disableFocusListener, false)
        compare(tip.z, 1060)
        tip.destroy()
        host.destroy()
    }

    function test_spacingAndPaddingFollowShowArrow() {
        const plain = makeHost()
        compare(plain.popRef.spacing, 4, "numbers.SPACING（showArrow=false 那一档）")
        compare(plain.popRef.gap, 4, "spacing 接进基座的 gap")
        compare(plain.popRef.padding, 0, "scss 里只有 -with-arrow 那条 padding:12")

        const arrow = makeHost("showArrow: true")
        compare(arrow.popRef.spacing, 10, "numbers.SPACING_WITH_ARROW")
        compare(arrow.popRef.gap, 10)
        compare(arrow.popRef.padding, 12, "$spacing-popover_withArrow-padding")

        // 官方是 `if (isNullOrUndefined(spacing)) spacing = showArrow ? 10 : 4`：
        // 使用方给了就以使用方为准，0 也算给了
        const given = makeHost("showArrow: true; spacing: 0")
        compare(given.popRef.gap, 0, "显式 spacing 压过那两档现算值")
        given.destroy(); arrow.destroy(); plain.destroy()
    }

    function test_arrowMetricsArePopoverColumn() {
        const host = makeHost("showArrow: true")
        const pop = popOf(host)
        compare(pop.arrowSize, 8, "$height-popover_arrow（tooltip 那一档是 7）")
        compare(pop.arrowBase, 24, "$width-popover_arrow")
        compare(pop.arrowOverlap, 1, "$spacing-tooltip_arrow_offset-*")
        compare(pop.arrowStroked, true, "popover/Arrow.tsx 是两条 path")
        compare(pop.arrowMinWidth, 36, "min-width = 6*2 + 24")
        compare(pop.arrowMinHeight, 36, "popover 的 adjusted_offset-y 是 6 ⇒ 24+12，tooltip 同档只有 34")
        compare(pop.arrowCross, 18, "round(0.24×24)=6 加半个箭头宽 12")
        compare(pop.pointsAtCenter, true, "pointsAtCenter = showArrow && arrowPointAtCenter")

        // 两条都得断：只断「带三角时为真」的话，把守卫改成 `arrowPointAtCenter` 一条也照样绿
        const plain = makeHost("showArrow: false; arrowPointAtCenter: true")
        compare(plain.popRef.pointsAtCenter, false, "没有三角就谈不上指中心")
        compare(plain.popRef.pointAtCenter, false, "基座那条开关也得跟着关")
        plain.destroy()

        const tip = make('Tooltip { text: "x"; showArrow: true }')
        compare(tip.arrowSize, 7)
        compare(tip.arrowStroked, false)
        compare(tip.arrowMinHeight, 34)
        tip.destroy()
        host.destroy()
    }

    // 三条颜色口子最后要落到那两条 path 上 —— 只读属性值不算数，画出来的东西才算。
    // ShapePath 不是 Item（摸不到 children），但 findChild 走的是 QObject 树：
    // background 的 parent 就是浮层自己的 QQuickPopupItem（探针 tests/tmp_findchild2_probe.qml），
    // 所以从浮层那一侧按 objectName 找得到 Shape 与 ShapePath，不必绕窗口项。
    function test_arrowPaintUsesTheThreeColors() {
        const host = makeHost("showArrow: true; style: ({ backgroundColor: '#aabbcc' });"
            + " arrowStyle: ({ borderColor: '#001122', backgroundColor: '#334455',"
            + " borderOpacity: 0.25 })")
        const pop = popOf(host)
        pop.open()
        wait(60)
        const borderShape = testCase.findChild(pop, "popupArrowBorderShape")
        const fillShape = testCase.findChild(pop, "popupArrowFillShape")
        verify(borderShape !== null && fillShape !== null, "两条 path 都得在")
        compare(borderShape.visible, true, "popover 档 arrowStroked=true")
        compare(borderShape.opacity, 0.25, "arrowStyle.borderOpacity 吃在描边那一只上")
        compare(testCase.findChild(pop, "popupArrowBorderPath").fillColor.toString(), "#001122",
            "描边那条吃 arrowStrokeColor")
        compare(testCase.findChild(pop, "popupArrowFillPath").fillColor.toString(), "#334455",
            "底色那条吃 arrowFillColor（这里刻意与卡片色 #aabbcc 分开）")
        host.destroy()

        // tooltip 档只有底色那一条：描边那只整只关掉
        const tipHost = make('Tooltip { text: "x"; showArrow: true; motion: false }')
        tipHost.open()
        wait(60)
        compare(testCase.findChild(tipHost, "popupArrowBorderShape").visible, false,
            "arrowStroked=false ⇒ 描边那条不画")
        compare(testCase.findChild(tipHost, "popupArrowFillPath").fillColor.toString(),
            tipHost.fillColor.toString(), "tooltip 档底色那条仍跟着 fillColor")
        tipHost.destroy()
    }

    function test_skinTokensAndShadow() {
        const host = makeHost()
        const pop = popOf(host)
        compare(pop.fillColor.toString(), Theme.current.colorBg3.toString(),
            "$color-popover-bg-default = var(--semi-color-bg-3)")
        compare(pop.strokeColor.toString(), Theme.current.colorBorder.toString(),
            "那条 1px 环是 shadow-elevated 第一层的替身（同 Dropdown）")
        compare(pop.arrowStrokeColor.toString(), Theme.current.colorBorder.toString(),
            "$color-popover-arrow-border")
        compare(pop.arrowFillColor.toString(), Theme.current.colorBg3.toString(),
            "$color-popover-arrow-bg")
        compare(pop.arrowBorderOpacity, 1)
        compare(pop.shadowEnabled, true, "popover.scss 的 wrapper 有 @include shadow-elevated")
        compare(pop.radius, Theme.current.radiusMedium)
        compare(pop.labelColor.toString(), Theme.current.colorText0.toString(),
            "卡片没有 color 规则 ⇒ 取继承来的 text-0（tooltip 是 bg-0 白字）")
        compare(pop.closePolicy, C.Popup.NoAutoClose)

        const tip = make('Tooltip { text: "x" }')
        compare(tip.shadowEnabled, false, "tooltip.scss 里不含阴影")
        compare(tip.strokeColor.a, 0, "tooltip 那一档描边是整个透明")
        compare(tip.fillColor.toString(), Theme.current.grey[7].toString())
        compare(tip.labelColor.toString(), Theme.current.colorBg0.toString())
        tip.destroy(); host.destroy()
    }

    function test_skinFollowsTheme() {
        const host = makeHost("showArrow: true")
        const pop = popOf(host)
        const lightFill = pop.fillColor.toString()
        const lightStroke = pop.strokeColor.toString()
        const lightArrow = pop.arrowStrokeColor.toString()
        Theme.mode = Theme.Dark
        verify(pop.fillColor.toString() !== lightFill, "底色要跟着主题走")
        verify(pop.strokeColor.toString() !== lightStroke, "描边环要跟着主题走")
        verify(pop.arrowStrokeColor.toString() !== lightArrow)
        compare(pop.fillColor.toString(), Theme.current.colorBg3.toString())
        compare(pop.arrowStrokeColor.toString(), Theme.current.colorBorder.toString())
        Theme.mode = Theme.Light
        host.destroy()
    }

    function test_noMaxWidthOnPopover() {
        const host = makeHost('text: "很长很长很长很长很长很长很长很长很长很长很长很长很长"')
        const pop = popOf(host)
        pop.open()
        wait(60)
        const label = labelOf(pop)
        // tooltip 那条 max-width:240 只写在 .semi-tooltip-wrapper 上：同样一句话，
        // Popover 不换行、卡片比 240 宽，Tooltip 夹到 240 并换行
        compare(pop.maxWidth, Number.MAX_VALUE)
        compare(label.wrapMode, Text.NoWrap)
        verify(pop.width > 240, "官方 popover 没有 max-width，实际 " + pop.width)
        const tip = make('Tooltip { text: "很长很长很长很长很长很长很长很长很长很长很长很长很长" }')
        tip.open()
        wait(60)
        compare(labelOf(tip).wrapMode, Text.WrapAtWordBoundaryOrAnywhere)
        verify(tip.width <= 240, "tooltip 还是夹在 240，实际 " + tip.width)
        tip.destroy(); host.destroy()
    }

    // ---------------------------------------------------------------- style / arrowStyle 三级回退
    function test_styleMapCoversThreeKeys() {
        const host = makeHost('showArrow: true; style: ({ backgroundColor: "#aabbcc",'
            + " borderColor: '#ddeeff', color: '#112233' })")
        const pop = popOf(host)
        compare(pop.fillColor.toString(), "#aabbcc")
        compare(pop.strokeColor.toString(), "#ddeeff")
        compare(pop.labelColor.toString(), "#112233")
        pop.open()
        wait(60)
        compare(labelOf(pop).color.toString(), "#112233", "style.color 要真画到字符串档那一层上")
        // 卡片被 style 改色时，三角按官方那句 popStyle 回退跟着一起改
        compare(pop.arrowFillColor.toString(), "#aabbcc")
        compare(pop.arrowStrokeColor.toString(), "#ddeeff")
        host.destroy()
    }

    function test_arrowStyleBeatsStyle() {
        const host = makeHost("showArrow: true;"
            + " style: ({ backgroundColor: '#aabbcc', borderColor: '#ddeeff' });"
            + " arrowStyle: ({ borderColor: '#001122', backgroundColor: '#334455',"
            + " borderOpacity: 0.5 })")
        const pop = popOf(host)
        compare(pop.arrowStrokeColor.toString(), "#001122", "arrowStyle.borderColor 优先")
        compare(pop.arrowFillColor.toString(), "#334455", "arrowStyle.backgroundColor 只改三角")
        compare(pop.arrowBorderOpacity, 0.5)
        compare(pop.fillColor.toString(), "#aabbcc", "卡片不受 arrowStyle 影响")
        compare(pop.strokeColor.toString(), "#ddeeff")
        host.destroy()
    }

    function test_styleMapPartialKeysFallBackToTokens() {
        const host = makeHost("showArrow: true; style: ({ backgroundColor: '#aabbcc' });"
            + " arrowStyle: ({})")
        const pop = popOf(host)
        compare(pop.fillColor.toString(), "#aabbcc")
        compare(pop.strokeColor.toString(), Theme.current.colorBorder.toString(),
            "style 没给 borderColor ⇒ 落回令牌")
        compare(pop.arrowStrokeColor.toString(), Theme.current.colorBorder.toString())
        compare(pop.arrowFillColor.toString(), "#aabbcc", "arrowStyle 没给 ⇒ 顺着 style")
        compare(pop.labelColor.toString(), Theme.current.colorText0.toString())
        host.destroy()
    }

    function test_styleMapExplicitNullFallsBackToo() {
        // 官方那两处是 lodash get(style, key, 令牌)：键**没给**才落回下一档；
        // 但 React 把 `backgroundColor: null` 这一项整个丢掉，浏览器里等价于没给
        // ⇒ 端口按「undefined 与 null 都算没给」处理，两条都要落回令牌
        const host = makeHost("showArrow: true;"
            + " style: ({ backgroundColor: null, borderColor: null, color: null });"
            + " arrowStyle: ({ borderColor: null, backgroundColor: null })")
        const pop = popOf(host)
        compare(pop.fillColor.toString(), Theme.current.colorBg3.toString(),
            "显式 null 落回 bg-3")
        compare(pop.strokeColor.toString(), Theme.current.colorBorder.toString())
        compare(pop.labelColor.toString(), Theme.current.colorText0.toString())
        compare(pop.arrowStrokeColor.toString(), Theme.current.colorBorder.toString(),
            "arrowStyle 里的 null 要继续往 style / 令牌落")
        compare(pop.arrowFillColor.toString(), Theme.current.colorBg3.toString())
        pop.open()
        wait(60)
        compare(labelOf(pop).color.toString(), Theme.current.colorText0.toString(),
            "画出来的也是 text-0")
        host.destroy()
    }

    function test_styleMapIgnoresBorderWidthSwitch() {
        // 官方 borderWidth / borderStyle 决定「真边框画不画」；我们那条环是阴影第一层的替身，
        // 不给 borderColor 时它就该一直在（与 Dropdown 同一口径），borderStyle:'none' 也不关
        const host = makeHost("style: ({ borderWidth: 0, borderStyle: 'none' })")
        compare(host.popRef.strokeColor.toString(), Theme.current.colorBorder.toString())
        host.destroy()
    }

    function test_explicitChannelBeatsStyleMap() {
        // QML 侧另有 fillColor / strokeColor / arrowStrokeColor 三条等价通道；
        // 使用方直接写它们时压过本组件里的缺省绑定（instance 赋值换掉绑定），
        // 这条测试钉住「两条口子都可用」而不是只钉谁赢
        const host = makeHost("fillColor: '#ff0000'")
        compare(host.popRef.fillColor.toString(), "#ff0000")
        host.destroy()
    }

    // ---------------------------------------------------------------- 尺寸
    function test_sizeWithoutArrow() {
        const host = makeHost()
        const pop = popOf(host)
        pop.open()
        wait(60)
        compare(pop.width, 60, "padding 0 ⇒ 卡片就是内容宽")
        compare(pop.height, 20)
        compare(bodyOf(pop).x, 0)
        compare(bodyOf(pop).y, 0)
        host.destroy()
    }

    function test_sizeWithArrowAddsPadding() {
        const host = makeHost("showArrow: true")
        const pop = popOf(host)
        pop.open()
        wait(60)
        compare(pop.width, 60 + 24, "内容宽 + 左右各 12")
        compare(pop.height, 20 + 24)
        // padding 吃在 contentItem 的定位上（Controls 把 Popup.padding 转给 popupItem 的
        // leftPadding 等四条），Column 里那一项相对 contentItem 仍是 0
        compare(pop.contentItem.x, 12, "内容整列被 padding 推进去")
        compare(pop.contentItem.y, 12)
        compare(bodyOf(pop).x, 0)
        compare(bodyOf(pop).y, 0)
        host.destroy()
    }

    function test_minSizeWithArrow() {
        const host = makeHost("showArrow: true",
            "Rectangle { objectName: 'popBody'; width: 4; height: 4; color: '#cfd4de' }")
        const pop = popOf(host)
        pop.open()
        wait(60)
        compare(pop.width, 36, "带三角的最小尺寸 36×36（min-width/height 那两条 mixin）")
        compare(pop.height, 36)
        // 不带同一档：内容多小都跟着缩，36 那条只在 -with-arrow 下生效
        const plain = makeHost("showArrow: false",
            "Rectangle { objectName: 'popBody'; width: 4; height: 4; color: '#cfd4de' }")
        plain.popRef.open()
        wait(60)
        compare(plain.popRef.width, 4)
        compare(plain.popRef.height, 4)
        plain.destroy(); host.destroy()
    }

    function test_textChannelUsesCardPadding() {
        // 官方 Popover 没有 title/content 之外的第二层内边距：字符串档那行的内边距
        // 就是卡片那 12（labelPaddingX/Y 接的是 padding），不能像 tooltip 那样再叠一层 8。
        // 取一句比「带三角最小 36」长的话，卡片宽才真的等于 label 的边框宽。
        const host = makeHost("showArrow: true; text: 'hi bytedancer'", "")
        const pop = popOf(host)
        const label = labelOf(pop)
        compare(pop.labelPaddingX, 12)
        compare(pop.labelPaddingY, 12)
        pop.open()
        wait(60)
        // 四条边逐条量：卡片宽/高与 label 宽高同源于同一个算式，写死任何一条都照样相等
        compare(label.leftPadding, 12)
        compare(label.rightPadding, 12)
        compare(label.topPadding, 12)
        compare(label.bottomPadding, 12)
        fuzzyCompare(pop.width, label.width, 0.01, "字符串档：卡片宽 = label 边框宽")
        fuzzyCompare(pop.height, label.height, 0.01)
        const plain = makeHost("text: 'hi bytedancer'", "")
        plain.popRef.open()
        wait(60)
        const plainLabel = labelOf(plain.popRef)
        compare(plainLabel.leftPadding, 0, "showArrow=false 时卡片没有内边距")
        compare(plainLabel.rightPadding, 0)
        compare(plainLabel.topPadding, 0)
        compare(plainLabel.bottomPadding, 0)
        plain.destroy(); host.destroy()
    }

    // ---------------------------------------------------------------- 12 个方位
    // target = (300,250,100,40)，内容 60×20 ⇒ 带三角时卡片 84×44、gap 10
    function test_positionsWithArrow() {
        const cases = [
            ["Enums.Top", 308, 196], ["Enums.TopLeft", 332, 196], ["Enums.TopRight", 284, 196],
            ["Enums.Left", 206, 248], ["Enums.LeftTop", 206, 252], ["Enums.LeftBottom", 206, 244],
            ["Enums.Right", 410, 248], ["Enums.RightTop", 410, 252], ["Enums.RightBottom", 410, 244],
            ["Enums.Bottom", 308, 300], ["Enums.BottomLeft", 332, 300], ["Enums.BottomRight", 284, 300]
        ]
        for (let i = 0; i < cases.length; ++i) {
            const host = makeHost("showArrow: true",
                "Rectangle { objectName: 'popBody'; width: 60; height: 20; color: '#cfd4de' }")
            const pop = popOf(host)
            pop.position = eval(cases[i][0])
            pop.open()
            wait(60)
            compare(pop.effectivePlacement, eval(cases[i][0]), cases[i][0] + " 方位不该翻面")
            compare(pop.x, cases[i][1], cases[i][0] + " 的卡片 x")
            compare(pop.y, cases[i][2], cases[i][0] + " 的卡片 y")
            compare(pop.width, 84)
            compare(pop.height, 44)
            host.destroy()
        }
    }

    function test_arrowSitsTwelveOffCornerAndAtCenterMiddle() {
        // 角落：三角中心离卡片边 18 ⇒ 盒子离边 18-12 = 6（arrow.scss 的 left/top/bottom: 6px）
        // 中间：arrowPointAtCenter 默认 true ⇒ 三角指到 target 的中心
        // [方位, 三角盒子宽, 盒子高, x, y]：横档 24×8、竖档 8×24
        //（$width-popover_arrow / $height-popover_arrow 两档互换）
        const cases = [
            ["Enums.TopLeft", 24, 8, 6, 43], ["Enums.TopRight", 24, 8, 54, 43],
            ["Enums.BottomLeft", 24, 8, 6, -7], ["Enums.BottomRight", 24, 8, 54, -7],
            ["Enums.LeftTop", 8, 24, 83, 6], ["Enums.LeftBottom", 8, 24, 83, 14],
            ["Enums.RightTop", 8, 24, -7, 6], ["Enums.RightBottom", 8, 24, -7, 14],
            ["Enums.Top", 24, 8, 30, 43], ["Enums.Bottom", 24, 8, 30, -7],
            ["Enums.Left", 8, 24, 83, 10], ["Enums.Right", 8, 24, -7, 10]
        ]
        for (let i = 0; i < cases.length; ++i) {
            const host = makeHost("showArrow: true")
            const pop = popOf(host)
            pop.position = eval(cases[i][0])
            pop.open()
            wait(60)
            const arrow = arrowOf(pop)
            compare(arrow.visible, true)
            fuzzyCompare(arrow.width, cases[i][1], 0.01, cases[i][0] + " 的三角盒子宽")
            fuzzyCompare(arrow.height, cases[i][2], 0.01, cases[i][0] + " 的三角盒子高")
            fuzzyCompare(arrow.x, cases[i][3], 0.01, cases[i][0] + " 的三角 x")
            fuzzyCompare(arrow.y, cases[i][4], 0.01, cases[i][0] + " 的三角 y")
            host.destroy()
        }
    }

    function test_pointAtCenterFalseAlignsCardEdges() {
        // 关掉后卡片退回「边与边对齐」：TopLeft 的左边贴 target 左边，
        // 但三角仍然待在离边 18 的位置 ⇒ 它只指到 target 左边 18px 那里（官方 :505 那一支）
        const left = makeHost("showArrow: true; arrowPointAtCenter: false; position: Enums.TopLeft")
        left.popRef.open()
        wait(60)
        compare(left.popRef.x, 300, "边对齐：卡片左边贴 target 左边")
        fuzzyCompare(arrowOf(left.popRef).x, 6, 0.01)
        compare(left.popRef.pointsAtCenter, false)

        const right = makeHost("showArrow: true; arrowPointAtCenter: false; position: Enums.TopRight")
        right.popRef.open()
        wait(60)
        compare(right.popRef.x, 400 - 84, "边对齐：卡片右边贴 target 右边")
        fuzzyCompare(arrowOf(right.popRef).x, 54, 0.01)
        right.destroy(); left.destroy()
    }

    function test_middlePlacementArrowTracksTargetWhenCardClamped() {
        // 卡片宽到放不下（内容 300 + 左右 12 ⇒ 324，target 中心在 100 ⇒ 本该 x = -62）：
        // keepClearOfAnchor 把卡片夹回 x=0，这时 target 中心不在卡片几何中心上了，
        // 三角要跟着挪到 100（官方那对 --semi-tooltip-arrow-offset-x / -y 变量干的事）。
        // 关掉 arrowPointAtCenter 就留在几何中心 162 —— 两条都要断，才分得开谁在跟。
        const wide = "Rectangle { objectName: 'popBody'; width: 300; height: 20; color: '#cfd4de' }"
        const host = makeHost("showArrow: true; position: Enums.Bottom", wide)
        const pop = popOf(host)
        host.tgtRef.x = 50                           // 中心 (100, 270)
        pop.open()
        wait(60)
        compare(pop.width, 324)
        compare(pop.x, 0, "卡片被夹进窗口左缘")
        fuzzyCompare(arrowOf(pop).x + 12, 100, 1, "三角跟着 target 中心走")

        const fixed = makeHost("showArrow: true; position: Enums.Bottom;"
            + " arrowPointAtCenter: false", wide)
        fixed.popRef.target.x = 50
        fixed.popRef.open()
        wait(60)
        compare(fixed.popRef.x, 0)
        fuzzyCompare(arrowOf(fixed.popRef).x + 12, 162, 1, "关掉后三角留在卡片几何中心")
        fixed.destroy(); host.destroy()
    }

    function test_flipsToTheOtherSideWhenNoRoom() {
        // target 贴窗口底部：往下放不下 10+44，往上放得下 ⇒ 翻到 Top（autoAdjustOverflow）
        const host = makeHost("showArrow: true; position: Enums.Bottom")
        const pop = popOf(host)
        host.tgtRef.y = 640
        pop.open()
        wait(60)
        compare(pop.effectivePlacement, Enums.Top, "下方不够要翻到上方")
        verify(pop.y + pop.height <= host.tgtRef.y, "翻面后卡片整体在 target 上方")
        host.destroy()
    }

    function test_autoAdjustOverflowFalseKeepsSide() {
        const host = makeHost("showArrow: true; position: Enums.Bottom; autoAdjustOverflow: false")
        const pop = popOf(host)
        host.tgtRef.y = 640
        pop.open()
        wait(60)
        compare(pop.effectivePlacement, Enums.Bottom, "关掉开关就不许翻面")
        host.destroy()
    }

    // ---------------------------------------------------------------- 触发模型（继承自 Tooltip）
    function test_hoverOpensAfterFiftyAndClosesOnLeave() {
        const host = makeHost()
        const pop = popOf(host)
        compare(pop.visible, false)
        hoverOver(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500, "hover 50ms 后弹出")
        compare(host.opens, 1, "只开一次")
        away()
        tryVerify(function () { return pop.visible === false; }, 1500, "移出后按 mouseLeaveDelay 收起")
        host.destroy()
    }

    function test_cardCountsAsStillHovering() {
        // 官方 portalEventSet 是 triggerEventSet 的一份拷贝：鼠标从 target 挪进卡片不该收
        const host = makeHost()
        const pop = popOf(host)
        hoverOver(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500)
        hoverInCard(pop, 30, 10)
        wait(300)
        compare(pop.visible, true, "鼠标进了卡片还算悬停")
        away()
        tryVerify(function () { return pop.visible === false; }, 1500)
        host.destroy()
    }

    function test_hoverDoesNotListenToFocusAnymore() {
        // disableFocusListener 在 popover 档默认就是 true：聚焦不再顺带弹层。
        // 对照同一档的 Tooltip（false）——聚焦会弹。
        const host = makeHost("trigger: 'hover'")
        host.tgtRef.forceActiveFocus()
        wait(200)
        compare(popOf(host).visible, false, "聚焦不该弹（disableFocusListener 默认 true）")

        const tipHost = make("Item { id: r; width: 400; height: 200;"
            + " property var tipRef: tip; property Item tgt2Ref: t2;"
            + " Rectangle { id: t2; x: 40; y: 40; width: 60; height: 24;"
            + "     color: '#eeeeee'; focusPolicy: Qt.StrongFocus }"
            + " Tooltip { id: tip; target: t2; text: 'x'; motion: false } }")
        tipHost.tgt2Ref.forceActiveFocus()
        tryVerify(function () { return tipHost.tipRef.visible === true; }, 1500,
            "tooltip 档同一件事会弹（它的 disableFocusListener 缺省 false）")
        tipHost.tgt2Ref.focus = false
        wait(200)
        tipHost.destroy(); host.destroy()
    }

    function test_focusTriggerStillWorks() {
        // focus 档自己不看 disableFocusListener（foundation.ts:212-217 没有那个判断）
        const host = makeHost("trigger: 'focus'")
        host.tgtRef.forceActiveFocus()
        tryVerify(function () { return popOf(host).visible === true; }, 1500,
            "focus 档不受 disableFocusListener 影响")
        host.tgtRef.focus = false
        tryVerify(function () { return popOf(host).visible === false; }, 1500, "blur 收起")
        host.destroy()
    }

    function test_clickOpensAndOutsidePressCloses() {
        const host = makeHost("trigger: 'click'")
        const pop = popOf(host)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500, "点击弹出")
        compare(host.outsideHits, 0)
        clickOn(host.tgtRef, 50, 20)
        wait(200)
        compare(pop.visible, true, "官方 click 档只有 show()，不是开关")
        away()
        clickOn(testCase.win.contentItem, 860, 670)
        tryVerify(function () { return pop.visible === false; }, 1500, "点外面收起")
        compare(host.outsideHits, 1, "click 档才发 clickedOutside")
        host.destroy()
    }

    function test_clickOnTargetDoesNotCountAsOutside() {
        const host = makeHost("trigger: 'click'")
        const pop = popOf(host)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500)
        clickOn(host.tgtRef, 50, 20)
        wait(200)
        compare(host.outsideHits, 0, "落在 trigger 上官方也不算外面")
        compare(pop.visible, true)
        host.destroy()
    }

    function test_customModeOnlySignals() {
        // custom：绑的是个空回调 ⇒ 信号照发、层不收（visible 由外面说了算）
        const host = makeHost('trigger: "custom"; visible: true')
        const pop = popOf(host)
        wait(60)
        compare(pop.visible, true)
        away()
        clickOn(testCase.win.contentItem, 860, 670)
        wait(200)
        compare(host.outsideHits, 1, "clickedOutside 还是发了")
        compare(pop.visible, true, "但 custom 档不因此收起")
        host.destroy()
    }

    function test_contextMenuOpensOnRightClick() {
        const host = makeHost("trigger: 'contextMenu'")
        const pop = popOf(host)
        clickOn(host.tgtRef, 50, 20, Qt.RightButton)
        tryVerify(function () { return pop.visible === true; }, 1500, "右键弹出")
        away()
        clickOn(testCase.win.contentItem, 860, 670)
        tryVerify(function () { return pop.visible === false; }, 1500, "这一档点外面也收")
        host.destroy()
    }

    function test_conditionFalseBlocksHoverAndClick() {
        const hover = makeHost("condition: false")
        hover.tgtRef.forceActiveFocus()
        hoverOver(hover.tgtRef, 50, 20)
        wait(300)
        compare(hover.popRef.visible, false, "condition=false ⇒ hover 不弹")
        away()
        hover.destroy()

        const click = makeHost("condition: false; trigger: 'click'")
        clickOn(click.tgtRef, 50, 20)
        wait(300)
        compare(click.popRef.visible, false, "condition=false ⇒ click 也不弹")
        click.destroy()
    }

    function test_conditionDoesNotAffectCustom() {
        const host = makeHost('condition: false; trigger: "custom"; visible: true')
        wait(60)
        compare(host.popRef.visible, true, "custom 档没有 handler，condition 整个无效")
        host.destroy()
    }

    function test_clickToHideClosesTheCard() {
        const host = makeHost("clickToHide: true")
        const pop = popOf(host)
        hoverOver(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500)
        clickInCard(pop, 30, 10)
        tryVerify(function () { return pop.visible === false; }, 1500, "点卡片即收（clickToHide）")
        host.destroy()
    }

    function test_marginOnlyFeedsFlipDecision() {
        // 官方 margin 只进 shouldReverse* 判定、不进最终 left/top
        const room = makeHost("showArrow: true; position: Enums.Bottom; margin: 20")
        room.popRef.open()
        wait(60)
        compare(room.popRef.fitMargin, 20)
        compare(room.popRef.effectivePlacement, Enums.Bottom, "空间够 ⇒ 不翻面")
        compare(room.popRef.y, 300, "margin 不参与最终 y")
        room.destroy()

        const tight = makeHost("showArrow: true; position: Enums.Bottom")
        tight.popRef.target.y = 640
        tight.popRef.open()
        wait(60)
        compare(tight.popRef.effectivePlacement, Enums.Top, "同样贴边、margin=0 时翻面")
        tight.destroy()
    }

    // ---------------------------------------------------------------- Esc 与焦点
    function test_escClosesAndSignalsByDefault() {
        // popover 档 closeOnEsc 就是 true（tooltip 缺省 false，那边另一份用例守着）
        const host = makeHost("trigger: 'click'")
        const pop = popOf(host)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500)
        keyClick(Qt.Key_Escape)
        tryVerify(function () { return pop.visible === false; }, 1500, "Esc 关层")
        compare(host.escHits, 1, "escKeyDown 信号也发了")
        host.destroy()
    }

    function test_closeOnEscFalseLeavesItOpen() {
        const host = makeHost("trigger: 'click'; closeOnEsc: false")
        const pop = popOf(host)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500)
        keyClick(Qt.Key_Escape)
        wait(300)
        compare(pop.visible, true, "closeOnEsc=false ⇒ 不关")
        compare(host.escHits, 0, "也不发信号（官方 closeOnEsc && _handleEscKeyDown）")
        host.destroy()
    }

    function test_initialFocusMovesFocusIntoCard() {
        const host = makeHost("trigger: 'click'",
            "C.TextField { objectName: 'popBody'; placeholderText: 'focus here' }")
        const pop = popOf(host)
        const field = bodyOf(pop)
        pop.initialFocus = field
        host.tgtRef.forceActiveFocus()
        wait(40)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return field.activeFocus === true; }, 1500,
            "initialFocus 那一项要拿到焦点")
        compare(pop.visible, true)
        host.destroy()
    }

    function test_initialFocusOnContentCreatedAtOpen() {
        // 官方 content 的函数档是「portal 变可见才把 DOM 挂上去」，focusRef 是挂载之后的事；
        // 端口对应的就是「卡片内容由 Loader 现造」这种摆法 —— 打开那一拍才出现的那一项
        // 也要拿到焦点（这一条同时证伪了「不等一帧就送不进去」那句猜测：摘掉 callLater 它照样绿）
        const host = make("Item { id: root; width: 700; height: 500;"
            + " property var popRef: pop;"
            + " property Item tgtRef: tgt;"
            + " property Item fieldRef: fieldLoader.item;"
            + " Rectangle { id: tgt; x: 160; y: 160; width: 100; height: 40;"
            + "     color: '#eeeeee'; focusPolicy: Qt.StrongFocus }"
            + " Popover { id: pop; target: tgt; motion: false; trigger: 'click';"
            + "     initialFocus: root.fieldRef;"
            + "     Loader { id: fieldLoader; objectName: 'fieldLoader'; active: pop.visible;"
            + "         sourceComponent: Component {"
            + "             C.TextField { objectName: 'lazyField'; placeholderText: 'lazy' } } }"
            + " } }")
        const pop = host.popRef
        verify(host.fieldRef === null, "没开层时那一项不该存在")
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500)
        tryVerify(function () { return host.fieldRef !== null; }, 1500,
            "开层后 Loader 要把那一项造出来")
        tryVerify(function () { return host.fieldRef.activeFocus === true; }, 1500,
            "晚一帧才存在的那一项也要拿到焦点")
        host.destroy()
    }

    function test_initialFocusNullLeavesFocusAlone() {
        // 缺省 initialFocus:null ⇒ 开层不抢焦点（官方那句只在 focusRefNode 存在时 focus）
        const host = makeHost("trigger: 'click'",
            "C.TextField { objectName: 'popBody'; placeholderText: 'focus here' }")
        const pop = popOf(host)
        const field = bodyOf(pop)
        host.tgtRef.forceActiveFocus()
        wait(40)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500)
        wait(300)
        compare(field.activeFocus, false, "没给 initialFocus 就不抢焦点")
        compare(host.tgtRef.activeFocus, true)
        host.destroy()
    }

    function test_returnFocusOnClosePutsFocusBackOnTarget() {
        // 判据要能把「组件主动把焦点送回 target」与「卡片隐掉时 Qt 自己另找一家」分开：
        // Esc 之前先把焦点放到 thief（既不在 target 也不在卡片）上，收层那一路惊动不到它 ——
        // 只有 forceActiveFocus(target) 真跑了，target 才会拿到焦点。
        const host = makeHost("trigger: 'click'")
        const pop = popOf(host)
        host.tgtRef.forceActiveFocus()
        wait(40)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500)
        host.thiefRef.forceActiveFocus()
        wait(40)
        compare(host.tgtRef.activeFocus, false, "先把焦点让给 thief")
        keyClick(Qt.Key_Escape)
        wait(300)
        compare(pop.visible, false)
        compare(host.thiefRef.activeFocus, false, "焦点不能留在 thief 上")
        compare(host.tgtRef.activeFocus, true, "returnFocusOnClose 缺省 true ⇒ 焦点回 target")
        host.destroy()
    }

    function test_returnFocusOnCloseFalseKeepsFocusAway() {
        const host = makeHost("trigger: 'click'; returnFocusOnClose: false")
        const pop = popOf(host)
        host.tgtRef.forceActiveFocus()
        wait(40)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return pop.visible === true; }, 1500)
        host.thiefRef.forceActiveFocus()
        wait(40)
        keyClick(Qt.Key_Escape)
        tryVerify(function () { return pop.visible === false; }, 1500)
        wait(300)
        compare(host.thiefRef.activeFocus, true, "关掉这条就不回焦点")
        compare(host.tgtRef.activeFocus, false)
        host.destroy()
    }

    function test_closeDoesNotReSendInitialFocus() {
        // 送焦点那一步只看「由假变真」那一拍（官方 setInitialFocus 挂在 portal 可见时）；
        // 收层那一拍不能再送一次，否则紧随其后的回焦点会被它顶掉
        const host = makeHost("trigger: 'click'",
            "C.TextField { objectName: 'popBody'; placeholderText: 'focus here' }")
        const pop = popOf(host)
        const field = bodyOf(pop)
        pop.initialFocus = field
        host.tgtRef.forceActiveFocus()
        wait(40)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return field.activeFocus === true; }, 1500,
            "开层时焦点进了卡片")
        keyClick(Qt.Key_Escape)
        wait(300)
        compare(pop.visible, false)
        compare(field.activeFocus, false, "收层那拍不得再把焦点送回卡片")
        compare(host.tgtRef.activeFocus, true)
        host.destroy()
    }

    function test_closingTransitionDoesNotRegrabFocus() {
        // 实测（tests/tmp_popover_focus_probe.qml）：motion 开着时 `Popup.visible` 要等退场
        // 动画跑完才变假，所以动画进行中的那 ~100ms 里卡片项还活着、**还收得到焦点**
        // （探针里手动 forceActiveFocus 在 +1 帧 / +40ms 都能把焦点送进卡片）。
        // 这一条量的就是这个中间态：Esc 之后焦点回 target，动画中与动画跑完都不许被卡片抢回去。
        const host = makeHost("trigger: 'click'",
            "C.TextField { objectName: 'popBody'; placeholderText: 'focus here' }")
        const pop = popOf(host)
        const field = bodyOf(pop)
        pop.initialFocus = field
        pop.motion = true
        host.tgtRef.forceActiveFocus()
        wait(40)
        clickOn(host.tgtRef, 50, 20)
        tryVerify(function () { return field.activeFocus === true; }, 1500,
            "开层时焦点进了卡片")
        keyClick(Qt.Key_Escape)
        wait(40)
        compare(pop.visible, true, "退场动画还在走 ⇒ visible 此刻还是真")
        compare(field.activeFocus, false, "动画进行中也不许把焦点送回卡片")
        compare(host.tgtRef.activeFocus, true)
        tryVerify(function () { return pop.visible === false; }, 1500)
        compare(field.activeFocus, false, "动画跑完那一拍同样不送")
        compare(host.tgtRef.activeFocus, true)
        host.destroy()
    }

    function test_customModeEscDoesNotReturnFocus() {
        // 官方 focusTrigger 那句 `returnFocusOnClose && trigger !== 'custom'`：
        // custom 档 Esc 只发信号，既不收层也不回焦点
        const host = makeHost('trigger: "custom"; visible: root.holdVisible',
            "C.TextField { objectName: 'popBody'; placeholderText: 'focus here' }")
        const pop = popOf(host)
        const field = bodyOf(pop)
        pop.initialFocus = field
        host.tgtRef.forceActiveFocus()
        wait(40)
        host.holdVisible = true
        tryVerify(function () { return field.activeFocus === true; }, 1500,
            "custom 档也照样吃 initialFocus")
        keyClick(Qt.Key_Escape)
        wait(300)
        compare(host.escHits, 1, "信号还是要发")
        compare(pop.visible, true, "custom 档不因此收层")
        compare(host.tgtRef.activeFocus, false, "也不回焦点")
        host.destroy()
    }

    // ---------------------------------------------------------------- 容器与层级
    function test_containerOverridesPopupParent() {
        const host = make("Item { id: root; width: 500; height: 400;"
            + " property var popRef: pop;"
            + " Rectangle { id: box; objectName: 'popBox'; x: 20; y: 20; width: 300; height: 200;"
            + "     color: '#eeeeee'; Rectangle { id: tgt; x: 100; y: 80; width: 40; height: 20;"
            + "     color: '#cccccc' } Popover { id: pop; target: tgt; container: box;"
            + "     position: Enums.Bottom; motion: false;"
            + "     Rectangle { objectName: 'popBody'; width: 30; height: 10; color: '#88aaff' }"
            + "     } } }")
        host.popRef.open()
        wait(60)
        compare(host.popRef.parent, host.popRef.container, "container 就是浮层的 parent")
        // box 在窗口里 (20,20)，tgt 在 box 里 (100,80) ⇒ 卡片顶边 = 20+80+20+4 = 124
        compare(host.popRef.y, 104, "位置按容器坐标系算")
        host.destroy()
    }

    function test_zIndexIsAppliedToZ() {
        const host = makeHost("zIndex: 900")
        compare(host.popRef.z, 900)
        host.destroy()
    }

    // ---------------------------------------------------------------- 与官方 demo 的对应
    function test_reproducibleFromOfficialConditionDemo() {
        // 官方「condition 条件触发」那一节：content 是字符串 ⇒ 走 text 档，
        // 不带三角 ⇒ 卡片没有内边距、间距 4
        const host = makeHost("text: 'condition is false'")
        const pop = popOf(host)
        pop.open()
        wait(60)
        compare(pop.padding, 0)
        compare(pop.gap, 4)
        compare(pop.labelColor.toString(), Theme.current.colorText0.toString())
        compare(labelOf(pop).color.toString(), Theme.current.colorText0.toString(),
            "画出来的字色才是 text-0（tooltip 那一档画的是 bg-0 白字）")
        compare(labelOf(pop).leftPadding, 0)
        host.destroy()
    }

    function test_colorfulDemoAppliesBorderAndFillTogether() {
        // 官方「设置浮层背景色」的提醒：backgroundColor 与 borderColor 要一起声明，
        // 否则卡片与三角对不上色。这里给同一对值 ⇒ 三条线同色
        const host = makeHost("showArrow: true; style: ({ backgroundColor: '#2a6ff5',"
            + " borderColor: '#2a6ff5' })")
        const pop = popOf(host)
        compare(pop.fillColor.toString(), pop.arrowFillColor.toString())
        compare(pop.strokeColor.toString(), pop.arrowStrokeColor.toString())
        compare(pop.fillColor.toString(), pop.arrowStrokeColor.toString(),
            "两条都给了同一个色 ⇒ 卡片、描边、三角对齐")
        host.destroy()
    }
}
