import QtQuick
import QtTest
import Semi

// Spin：属性面照抄官方 SpinProps（semi-ui/spin/index.tsx:15-25 + defaultProps:46-52），
// 延迟语义照 index.tsx:64-79 的 getDerivedStateFromProps + foundation.ts:22-34，
// 尺寸与层叠照 semi-foundation/spin/spin.scss + variables.scss。
// 期望值多数写成字面量（14 / 20 / 32 / 0.5 / 600 / 1600 / 20 行高），
// 这样改坏组件里的令牌就会红。
TestCase {
    id: testCase

    name: "Spin"
    when: windowShown
    width: 800
    height: 600

    Component {
        id: spinComponent
        Spin {}
    }

    function init() {
        // 根项读到的 effectiveVisible 在窗口 show 后不会立即刷新，不重新置位的话
        // 拿不到帧，几何与旋转断言会失真
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(props) {
        return createTemporaryObject(spinComponent, testCase, props)
    }

    function makeQml(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "spinProbe")
    }

    function content(c) {
        return testCase.findChild(c, "spinContent")
    }

    function wrapper(c) {
        return testCase.findChild(c, "spinWrapper")
    }

    function box(c) {
        return testCase.findChild(c, "spinBox")
    }

    function canvas(c) {
        return testCase.findChild(c, "spinCanvas")
    }

    function indicatorLoader(c) {
        return testCase.findChild(c, "spinIndicator")
    }

    function tipLabel(c) {
        return testCase.findChild(c, "spinTip")
    }

    function mask(c) {
        return testCase.findChild(c, "spinMask")
    }

    // ---------------- 缺省值与三档尺寸 ----------------

    function test_defaultPropsMatchOfficial() {
        const s = make({})
        compare(s.size, "middle")                  // index.tsx:47
        compare(s.spinning, true)                  // :48
        compare(s.delay, 0)                        // :50
        compare(s.indicator, null)                 // :49
        compare(s.loading, true)
        compare(s.side, 20)
        s.destroy()
    }

    function test_sizeTokens() {
        const small = make({ size: "small" })
        const middle = make({ size: "middle" })
        const large = make({ size: "large" })
        compare(small.side, 14)                    // $width-spin_small
        compare(middle.side, 20)                   // $width-spin_middle
        compare(large.side, 32)                    // $width-spin_large
        small.destroy(); middle.destroy(); large.destroy()
    }

    // 不包裹内容时，根节点自己就是那一档方块（spin.scss:10 的 @include size）
    function test_standaloneBoxIsTheSizeToken() {
        const s = make({ size: "large" })
        compare(s.implicitWidth, 32)
        compare(s.implicitHeight, 32)
        compare(s.wrapped, false)
        s.destroy()
    }

    function test_colorDefaultsToPrimaryToken() {
        const s = make({})
        compare(s.color.toString(), Theme.current.colorPrimary.toString())
        compare(s.color.toString(), "#0064fa")     // 浅色主题下的具体值，写死才防住改令牌
        s.destroy()
    }

    // 官方没有「禁用态的 Spin」：老实现那句 visible: control.enabled 是自造的，已删
    function test_disabledDoesNotHideSpin() {
        const s = make({})
        s.enabled = false
        wait(20)
        compare(s.visible, true)
        compare(s.loading, true)
        s.destroy()
    }

    // ---------------- spinning / loading ----------------

    function test_spinningFalseHidesIndicator() {
        const s = make({ spinning: false })
        wait(20)
        compare(s.loading, false)
        compare(wrapper(s).visible, false)
        s.destroy()
    }

    function test_spinningTogglesBothWays() {
        const s = make({ spinning: true })
        wait(20)
        compare(s.loading, true)
        s.spinning = false
        wait(20)
        compare(s.loading, false)
        compare(wrapper(s).visible, false)
        s.spinning = true
        wait(20)
        compare(s.loading, true)
        compare(wrapper(s).visible, true)
        s.destroy()
    }

    // ---------------- 延迟显示 ----------------

    function test_delayWaitsBeforeShowing() {
        const s = make({ delay: 200, spinning: false })
        wait(20)
        compare(s.loading, false)
        s.spinning = true
        wait(60)
        compare(s.loading, false)                  // 60ms 还没到 200ms
        compare(s.pendingDelay, 200)
        wait(220)
        compare(s.loading, true)
        compare(s.pendingDelay, 0)
        s.destroy()
    }

    function test_delayOffHidesImmediately() {
        const s = make({ delay: 400, spinning: true })
        wait(20)
        compare(s.loading, true)
        s.spinning = false
        wait(20)                                   // 不等 400ms：关掉是立刻的
        compare(s.loading, false)
        compare(s.pendingDelay, 0)
        s.destroy()
    }

    // 官方构造函数把 loading 初始化成 true，而 gDSFP 在 spinning 为真时只写 state.delay
    // （index.tsx:76-78）⇒ 一上来就是 spinning + delay 时指示符立刻可见
    function test_delayAtMountWithSpinningShowsImmediately() {
        const s = make({ delay: 500 })
        wait(20)
        compare(s.spinning, true)
        compare(s.loading, true)
        s.destroy()
    }

    function test_zeroDelayFollowsSpinningExactly() {
        const s = make({})
        compare(s.delay, 0)
        s.spinning = false
        compare(s.loading, false)                  // 没有定时器，同步就是赋值
        s.spinning = true
        compare(s.loading, true)
        s.destroy()
    }

    // ---------------- 包裹模式 ----------------

    function test_wrapModeSizesToContent() {
        const s = makeQml("Spin { Rectangle { width: 200; height: 80; color: \"#eeeeee\" } }")
        wait(60)
        compare(s.wrapped, true)
        compare(s.implicitWidth, 200)
        compare(s.implicitHeight, 80)
        s.destroy()
    }

    function test_wrapContentDimmedWhileSpinning() {
        const s = makeQml("Spin { Rectangle { width: 120; height: 40; color: \"#eeeeee\" } }")
        wait(60)
        compare(content(s).opacity, 0.5)           // $opacity-spin_children
        s.spinning = false
        wait(20)
        compare(content(s).opacity, 1)             // -hidden > -children
        s.destroy()
    }

    // 指示符浮在内容正中（-wrapper：width 100% + top 50% + translateY(-50%)）。
    // spinnerBox 自己在转，mapToItem 会把旋转算进去 ⇒ 位置一律按「父链相加」算
    function test_overlayCentredOverContent() {
        const s = makeQml("Spin { Rectangle { width: 200; height: 80; color: \"#eeeeee\" } }")
        wait(60)
        const c = centreOf(s, box(s))
        fuzzyCompare(c.x, 100, 0.5)
        fuzzyCompare(c.y, 40, 0.5)
        compare(box(s).width, 20)
        compare(box(s).height, 20)
        s.destroy()
    }

    // 把某个「非旋转」祖先链上的 item 换算到根坐标，再取中心
    function centreOf(root, item) {
        let x = item.x + item.width / 2
        let y = item.y + item.height / 2
        let p = item.parent
        while (p !== null && p !== root) {
            x += p.x
            y += p.y
            p = p.parent
        }
        return Qt.point(x, y)
    }

    // 带 tip 时官方居中的是「弧 + 文字」那一整块（tip 是块级 div，行高 20px），
    // 所以弧心比内容中心高 10px；两块各自水平居中（-wrapper 的 text-align:center）
    function test_tipMakesGroupCentredAndArcShiftsUp() {
        const s = makeQml("Spin { tip: \"I am loading...\";"
            + " Rectangle { width: 200; height: 80; color: \"#eeeeee\" } }")
        wait(60)
        const t = tipLabel(s)
        compare(t.visible, true)
        compare(t.text, "I am loading...")
        compare(t.height, 20)                      // font-size-regular 的 line-height
        compare(t.color.toString(), s.color.toString())
        const arc = centreOf(s, box(s))
        const tip = centreOf(s, t)
        fuzzyCompare(arc.y, 40 - 10, 0.5)
        fuzzyCompare(tip.y, 40 + 10, 0.5)
        fuzzyCompare(arc.x, 100, 0.5)
        fuzzyCompare(tip.x, 100, 0.5)
        s.destroy()
    }

    // tip 比弧窄时反过来：Column 的宽度由弧决定，tip 自己不居中就会贴到左边
    function test_narrowTipStillCentredUnderWideArc() {
        const s = makeQml("Spin { size: \"large\"; tip: \"…\";"
            + " Rectangle { width: 200; height: 80; color: \"#eeeeee\" } }")
        wait(60)
        const t = tipLabel(s)
        verify(t.width < box(s).width,
            "这一条要的就是「tip 比弧窄」：" + t.width + " vs " + box(s).width)
        fuzzyCompare(centreOf(s, box(s)).x, 100, 0.5)
        fuzzyCompare(centreOf(s, t).x, 100, 0.5)
        s.destroy()
    }

    function test_tipHiddenWhenEmpty() {
        const s = make({})
        wait(20)
        compare(tipLabel(s).visible, false)
        compare(tipLabel(s).text, "")
        s.destroy()
    }

    // -block::after 那层遮罩：只在包裹模式且 loading 时挡点击
    function test_wrapMaskBlocksClicksWhileSpinning() {
        const s = makeQml("Spin { Rectangle { width: 160; height: 60; color: \"#eeeeee\";"
            + " MouseArea { anchors.fill: parent; onClicked: testCase.hit = true } } }")
        wait(60)
        testCase.hit = false
        mouseClick(s, 80, 30, Qt.LeftButton)
        compare(testCase.hit, false)
        compare(mask(s).enabled, true)
        s.spinning = false
        wait(20)
        compare(mask(s).enabled, false)
        mouseClick(s, 80, 30, Qt.LeftButton)
        compare(testCase.hit, true)
        s.destroy()
    }

    property bool hit: false

    // 不包裹内容时遮罩不该拦事（Select / Transfer 那些浮在角落的 Spin 会顺带吃掉点击）
    function test_standaloneMaskIsDisabled() {
        const s = make({})
        wait(20)
        compare(s.wrapped, false)
        compare(mask(s).enabled, false)
        s.destroy()
    }

    // ---------------- 自定义指示符 ----------------

    function test_defaultArcIsTheOnlyIndicatorWhenNoneGiven() {
        const s = make({})
        wait(20)
        compare(canvas(s).visible, true)
        compare(indicatorLoader(s).item, null)
        compare(s.spinDuration, 600)               // $animation_duration-spin_wrapper-spin
        s.destroy()
    }

    function test_indicatorReplacesArcAndUsesItsOwnTiming() {
        const s = makeQml('Spin { indicator: Component { Rectangle { width: 24; height: 24;'
            + ' color: "#ff0000" } } }')
        wait(60)
        compare(canvas(s).visible, false)
        verify(indicatorLoader(s).item !== null)
        compare(box(s).width, 24)                  // -animate 是 inline-flex，跟着内容尺寸
        compare(box(s).height, 24)
        compare(s.spinDuration, 1600)              // $animation_duration-spin_customChildren-spin
        s.destroy()
    }

    function test_arcRotates() {
        const s = make({})
        wait(20)
        const start = box(s).rotation
        wait(200)
        verify(Math.abs(box(s).rotation - start) > 1,
            "转起来才说明动画真的在跑：" + start + " → " + box(s).rotation)
        s.destroy()
    }

    // 弧的张角与圆头照 icon.tsx 的 path（90° + 64.2°），线宽 4 / viewBox 36
    function test_arcGeometryFollowsIconSvg() {
        const s = make({})
        fuzzyCompare(s.arcSweep, 154.2 * Math.PI / 180, 0.0001)
        fuzzyCompare(s.arcSweep * 180 / Math.PI, 154.2, 0.0001)
        s.destroy()
    }

    // 尺寸换了要重画：Canvas 的宽高跟着 side 走
    function test_sizeChangeResizesCanvas() {
        const s = make({ size: "small" })
        wait(20)
        compare(canvas(s).width, 14)
        s.size = "large"
        wait(20)
        compare(canvas(s).width, 32)
        compare(canvas(s).height, 32)
        s.destroy()
    }
}
