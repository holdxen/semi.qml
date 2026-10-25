import QtQuick
import QtQuick.Shapes
import QtTest
import Semi

// Progress：属性面照抄官方 ProgressProps（semi-ui/progress/index.tsx:14-35 + defaultProps:38-52），
// 取色算法照抄 semi-foundation/progress/generates.ts，几何照抄 progress.scss / variables.scss，
// 并用浏览器实测对过数（harness：tests/tmp_progress_dom.html）。
// 下面的期望值多数直接写成字面量（令牌的具体色、实测出来的 45 / 16 / 8 / 72 / 24 / 35%），
// 这样改坏组件里的常量就会红，而不是「组件和测试一起改、两边照旧绿」。
TestCase {
    id: testCase

    name: "Progress"
    when: windowShown
    width: 800
    height: 600

    Component {
        id: progressComponent
        Progress {}
    }

    function init() {
        // 根项读到的 effectiveVisible 在窗口 show 后不会立即刷新，不重新置位的话
        // 补间与几何断言拿不到帧
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(props) {
        return createTemporaryObject(progressComponent, testCase, props)
    }

    // 逐字写 QML 的用例：Qt.createQmlObject 的字符串里必须自带 import
    function makeQml(qml) {
        return Qt.createQmlObject("import QtQuick; import QtQuick.Shapes; import Semi; " + qml,
            testCase, "progressProbe")
    }

    function track(c) {
        return testCase.findChild(c, "progressTrack")
    }

    function rail(c) {
        return testCase.findChild(c, "progressRail")
    }

    function inner(c) {
        return testCase.findChild(c, "progressInner")
    }

    function ring(c) {
        return testCase.findChild(c, "progressRing")
    }

    function arcPath(c) {
        return testCase.findChild(c, "arcPath")
    }

    function orbitPath(c) {
        return testCase.findChild(c, "orbitPath")
    }

    function innerArc(c) {
        return testCase.findChild(c, "innerArc")
    }

    function orbitArc(c) {
        return testCase.findChild(c, "orbitArc")
    }

    function info(c) {
        return testCase.findChild(c, "progressInfo")
    }

    // ---------------------------------------------------------------- 默认值（defaultProps）

    function test_defaultPropsMatchOfficial() {
        const c = make({ x: 20, y: 20 })
        verify(c, "Progress 创建失败")
        compare(c.percent, 0)
        compare(c.type, "line")
        compare(c.size, "default")
        compare(c.direction, "horizontal")
        compare(c.strokeLinecap, "round")
        compare(c.strokeWidth, 4)
        compare(c.strokeGradient, false)
        compare(c.showInfo, false)
        compare(c.indeterminate, false)
        compare(c.motion, true)
        compare(c.format, null)
        compare(c.circleWidth, 0)
        // stroke / orbitStroke 官方没有 defaultProps，色由 scss 兜底
        compare(c.stroke, null)
        compare(c.orbitStroke, null)
        c.destroy()
    }

    // $height-progress_horizontal=4 / $height-progress_horizontal_large=6 /
    // $width-progress_vertical=4 / _large=6；环形的 72 与 24 来自 index.tsx 的算式
    function test_thicknessAndImplicitSize_data() {
        return [
            { tag: "lineDefault", qml: "Progress { }", w: 0, h: 4 },
            { tag: "lineLarge", qml: "Progress { size: 'large' }", w: 0, h: 6 },
            { tag: "verticalDefault", qml: "Progress { direction: 'vertical' }", w: 4, h: 0 },
            { tag: "verticalLarge", qml: "Progress { direction: 'vertical'; size: 'large' }", w: 6, h: 0 },
            { tag: "circleDefault", qml: "Progress { type: 'circle' }", w: 72, h: 72 },
            { tag: "circleSmall", qml: "Progress { type: 'circle'; size: 'small' }", w: 24, h: 24 },
            { tag: "circleLarge", qml: "Progress { type: 'circle'; size: 'large' }", w: 24, h: 24 },
            { tag: "circleWidth", qml: "Progress { type: 'circle'; circleWidth: 100 }", w: 100, h: 100 }
        ]
    }

    function test_thicknessAndImplicitSize(data) {
        const c = makeQml(data.qml)
        verify(c, "Progress 创建失败：" + data.tag)
        compare(c.implicitWidth, data.w, data.tag + " 的 implicitWidth")
        compare(c.implicitHeight, data.h, data.tag + " 的 implicitHeight")
        // size 只管自己那一档：small 不改条状厚度，large 不改环形直径算式
        if (data.tag === "lineDefault" || data.tag === "lineLarge")
            compare(c.thickness, data.h)
        c.destroy()
    }

    function test_sizeDoesNotLeakAcrossTypes() {
        const line = make({ x: 20, y: 20, width: 200, size: "small" })
        verify(line, "Progress 创建失败")
        compare(line.thickness, 4, "small 不该改条状厚度")
        line.destroy()

        const circle = make({ x: 20, y: 40, type: "circle", size: "large" })
        verify(circle, "Progress 创建失败")
        compare(circle.diameter, 24, "large 的环形只有 24（官方算式）")
        circle.destroy()
    }

    // ---------------------------------------------------------------- 条状几何

    function test_lineTrackIsTheBoxAndUsesTheTokens() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, percent: 50 })
        verify(c, "Progress 创建失败")
        const t = track(c)
        const r = rail(c)
        const i = inner(c)
        verify(t !== null && r !== null && i !== null, "条状子项缺失")
        compare(t.width, 200)
        compare(t.height, 4)
        compare(t.clip, true, "官方 .semi-progress-track { overflow: hidden }")
        compare(t.x, 0)
        compare(t.y, 0)
        compare(r.width, 200)
        compare(r.height, 4)
        // $radius-progress_track = border-radius-small = 3
        compare(r.radius, 3)
        compare(i.radius, 3)
        // 轨道 = colorFill0(46,50,56,.05)，进度块 = $color-progress_track_inner-bg = success
        compare(r.color.toString(), "#0d2e3238")
        compare(i.color.toString(), "#3bb346")
        compare(i.x, 0)
        compare(i.y, 0)
        compare(i.width, 100, "50% 应该占一半")
        compare(i.height, 4)
        c.destroy()
    }

    function test_lineRatioFollowsPercent_data() {
        return [
            { tag: "zero", percent: 0, width: 0 },
            { tag: "fraction", percent: 12.5, width: 25 },
            { tag: "half", percent: 50, width: 100 },
            { tag: "full", percent: 100, width: 200 },
            { tag: "over", percent: 150, width: 200 },
            { tag: "under", percent: -20, width: 0 }
        ]
    }

    function test_lineRatioFollowsPercent(data) {
        const c = make({ x: 20, y: 20, width: 200, height: 4, motion: false, percent: data.percent })
        verify(c, "Progress 创建失败")
        compare(c.clamped, Math.max(0, Math.min(100, data.percent)))
        wait(60)
        compare(inner(c).width, data.width, data.tag + " 时进度块宽度")
        c.destroy()
    }

    function test_nanPercentPaintsNothing() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, motion: false, showInfo: true, percent: NaN })
        verify(c, "Progress 创建失败")
        compare(c.clamped, 0)
        wait(60)
        compare(inner(c).width, 0)
        compare(info(c).text, "0%")
        c.destroy()
    }

    // 官方 style={{ height: '8px' }} 直接盖掉 .semi-progress-horizontal 的 4px
    function test_customHeightThickensTheTrack() {
        const c = make({ x: 20, y: 20, width: 200, height: 8, percent: 25 })
        verify(c, "Progress 创建失败")
        compare(c.height, 8)
        compare(track(c).height, 8)
        compare(rail(c).height, 8)
        compare(inner(c).height, 8)
        compare(inner(c).width, 50)
        c.destroy()
    }

    function test_orbitStrokeOverridesTheRail() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, orbitStroke: "#123456" })
        verify(c, "Progress 创建失败")
        compare(rail(c).color.toString(), "#123456")
        // orbitStroke 不该顺手改掉进度块
        compare(inner(c).color.toString(), "#3bb346")
        c.destroy()

        const t = make({ x: 20, y: 40, width: 200, height: 4, orbitStroke: "var(--semi-color-fill-2)" })
        verify(t, "Progress 创建失败")
        compare(rail(t).color.toString(), Theme.current.colorFill2.toString())
        t.destroy()
    }

    // ---------------------------------------------------------------- 百分比文本

    function test_lineInfoBand() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, showInfo: true, motion: false, percent: 25 })
        verify(c, "Progress 创建失败")
        const i = info(c)
        compare(i.visible, true)
        compare(i.text, "25%")
        // 官方 .semi-progress-line-text：min-width 45、margin-left 16、font-weight 600、色 text-0，
        // 不写 font-size（继承 body）
        compare(i.font.pixelSize, 14)
        compare(i.font.weight, Font.DemiBold)
        compare(i.color.toString(), "#1c1f23", "$color-progress_line_text-text = text-0（light 档 grey-9）")
        verify(i.width >= 45, "文本框不该小于 45")
        compare(track(c).width + 16 + i.width, 200, "轨道被挤掉「文本宽 + 16」")
        compare(i.x, 200 - i.width)
        compare(i.y, (4 - i.height) / 2)
        c.destroy()
    }

    function test_shortTextStillReservesFortyFive() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, showInfo: true, motion: false, percent: 5 })
        verify(c, "Progress 创建失败")
        const i = info(c)
        compare(i.text, "5%")
        verify(i.implicitWidth < 45, "前提：这一串的自然宽度本来就小于 45")
        compare(i.width, 45)
        compare(track(c).width, 139)
        c.destroy()
    }

    function test_longTextSqueezesTheTrackFurther() {
        const c = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            showInfo: true,
            motion: false,
            percent: 50,
            format: function (p) {
                return "第 " + p + " 段一共很多字"
            }
        })
        verify(c, "Progress 创建失败")
        const i = info(c)
        verify(i.width > 45, "长文本应该按自然宽度撑开：" + i.width)
        compare(i.width, i.implicitWidth)
        compare(track(c).width + 16 + i.width, 200)
        c.destroy()
    }

    function test_formatReceivesTheNumber() {
        const c = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            showInfo: true,
            motion: false,
            percent: 50,
            format: function (p) {
                return p * 10 + "‰"
            }
        })
        verify(c, "Progress 创建失败")
        compare(info(c).text, "500‰")
        c.destroy()
    }

    function test_infoStaysHiddenWithoutShowInfo() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, percent: 40 })
        verify(c, "Progress 创建失败")
        compare(info(c).visible, false)
        compare(track(c).width, 200)
        c.destroy()
    }

    // ---------------------------------------------------------------- 垂直

    function test_verticalGrowsTopDown() {
        const c = make({ x: 20, y: 20, width: 4, height: 100, direction: "vertical", motion: false, percent: 50 })
        verify(c, "Progress 创建失败")
        compare(c.thickness, 4)
        compare(track(c).width, 4)
        compare(track(c).height, 100)
        const i = inner(c)
        compare(i.width, 4)
        compare(i.height, 50)
        // 官方 flex-direction: column —— 进度块是轨道的第一格，从顶部往下长
        compare(i.x, 0)
        compare(i.y, 0)
        c.destroy()
    }

    function test_verticalLargeIsSixWide() {
        const c = make({ x: 20, y: 20, height: 100, direction: "vertical", size: "large", percent: 25 })
        verify(c, "Progress 创建失败")
        compare(c.width, 6, "implicitWidth 应该跟着 large 的 6 走")
        compare(track(c).width, 6)
        compare(inner(c).width, 6)
        compare(inner(c).height, 25)
        c.destroy()
    }

    function test_verticalInfoSitsBelowTheTrack() {
        const c = make({
            x: 20,
            y: 20,
            width: 4,
            height: 100,
            direction: "vertical",
            showInfo: true,
            motion: false,
            percent: 50
        })
        verify(c, "Progress 创建失败")
        const i = info(c)
        compare(i.visible, true)
        compare(i.text, "50%")
        verify(i.width < 45, "竖条的文本没有 min-width 那一档：" + i.width)
        // margin-top 8，轨道 = 100 - 文本高 - 8
        compare(track(c).height + 8 + i.height, 100)
        compare(i.y, track(c).height + 8)
        compare(i.x, (4 - i.width) / 2, "居中的文本会溢出那 4px（官方如此）")
        compare(inner(c).height, track(c).height / 2)
        c.destroy()
    }

    function test_customWidthThickensTheVerticalTrack() {
        const c = make({ x: 20, y: 20, width: 8, height: 100, direction: "vertical", percent: 50 })
        verify(c, "Progress 创建失败")
        compare(track(c).width, 8)
        compare(inner(c).width, 8)
        c.destroy()
    }

    // ---------------------------------------------------------------- 不确定态

    function test_indeterminateLineIsAThirdOfTheTrack() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, indeterminate: true, showInfo: true, percent: 80 })
        verify(c, "Progress 创建失败")
        const i = inner(c)
        // .semi-progress-track-inner { width: 35% }，percent 与 showInfo 都被忽略
        compare(i.width, 70)
        compare(i.height, 4)
        compare(info(c).visible, false)
        compare(c.infoShown, false)
        c.destroy()
    }

    function test_indeterminateLineSlides() {
        // 滑块默认停在官方 keyframe 0% 的那一档：动画没起来时（组件不可见）就读得到
        const idle = make({ x: 20, y: 20, width: 200, height: 4, indeterminate: true, visible: false })
        verify(idle, "Progress 创建失败")
        compare(idle.slideRatio, -1.2)
        compare(inner(idle).x, -84)
        idle.destroy()

        const c = make({ x: 20, y: 20, width: 200, height: 4, indeterminate: true })
        verify(c, "Progress 创建失败")
        const i = inner(c)
        compare(i.width, 70)
        // 官方 keyframe：0% → -120%、55%（880ms）→ 300%、100% → 300%（停住那一段）
        let minRatio = c.slideRatio
        let maxRatio = c.slideRatio
        let easedIntoTop = false
        let moved = false
        for (let n = 0; n < 40; ++n) {
            wait(50)
            if (Math.abs(i.x - -84) > 0.5)
                moved = true
            const r = c.slideRatio
            // 渐近到 300% 才算走完第一段：直接跳上去的话这一段永远采不到
            if (r > 2.3 && r < 2.9)
                easedIntoTop = true
            minRatio = Math.min(minRatio, r)
            maxRatio = Math.max(maxRatio, r)
        }
        compare(moved, true, "滑块应当从 -120% 位移开始跑（官方 1.6s 一轮）")
        compare(maxRatio, 3.0, "跑满一轮要能停在 300% 那一档")
        verify(minRatio < -1.0 && minRatio >= -1.2, "每一轮开头要回到 -120%：" + minRatio)
        compare(easedIntoTop, true, "880ms 那一档要**渐近**爬到 300%，不是最后一步跳上去")
        c.destroy()
    }

    function test_indeterminateVerticalIsAThirdOfTheHeight() {
        const c = make({ x: 20, y: 20, width: 4, height: 100, direction: "vertical", indeterminate: true })
        verify(c, "Progress 创建失败")
        const i = inner(c)
        compare(i.width, 4)
        compare(i.height, 35)
        compare(i.x, 0)
        c.destroy()
    }

    // 官方 dasharray = "0.3C C" ⇒ 弧长固定三成；起手不再 -90，改由整圈旋转动画带着转
    function test_indeterminateCircleArc() {
        const c = make({ x: 20, y: 20, type: "circle", indeterminate: true, percent: 80, showInfo: true })
        verify(c, "Progress 创建失败")
        compare(c.sweepAngle, 108)
        const a = innerArc(c)
        compare(a.sweepAngle, 108)
        compare(a.startAngle, 0)
        compare(info(c).visible, false)
        compare(c.spinAngle, 0)
        let spun = false
        for (let n = 0; n < 12 && !spun; ++n) {
            wait(50)
            if (c.spinAngle > 0.5)
                spun = true
        }
        compare(spun, true, "环形不确定态应当整圈转起来（1.2s 一轮）")
        c.destroy()
    }

    function test_animationsStopWhenIndeterminateTurnsOff() {
        const c = make({ x: 20, y: 20, type: "circle", indeterminate: true })
        verify(c, "Progress 创建失败")
        wait(120)
        verify(c.spinAngle > 0.5, "先确认它确实在转")
        const frozen = c.spinAngle
        c.indeterminate = false
        wait(200)
        compare(c.spinAngle, frozen, "关掉 indeterminate 后不该继续转")
        compare(c.sweepAngle, c.shownPercent * 3.6)
        c.destroy()
    }

    // ---------------------------------------------------------------- 环形几何

    function test_circleGeometry_data() {
        return [
            { tag: "default", qml: "Progress { type: 'circle'; percent: 25 }", d: 72, r: 34, c: 25 },
            { tag: "small", qml: "Progress { type: 'circle'; size: 'small'; percent: 25 }", d: 24, r: 10, c: 25 },
            { tag: "custom", qml: "Progress { type: 'circle'; circleWidth: 100; percent: 25 }", d: 100, r: 48, c: 25 },
            { tag: "stroke", qml: "Progress { type: 'circle'; strokeWidth: 8; percent: 25 }", d: 72, r: 32, c: 25 },
            { tag: "half", qml: "Progress { type: 'circle'; percent: 50 }", d: 72, r: 34, c: 50 }
        ]
    }

    function test_circleGeometry(data) {
        const c = makeQml(data.qml)
        verify(c, "Progress 创建失败：" + data.tag)
        compare(c.diameter, data.d, data.tag + " 的直径")
        compare(c.radius, data.r, data.tag + " 的半径 = (直径 - strokeWidth) / 2")
        compare(c.circumference, data.r * 2 * Math.PI)
        const ring = testCase.findChild(c, "progressRing")
        compare(ring.width, data.d)
        compare(ring.height, data.d)
        const a = testCase.findChild(c, "innerArc")
        compare(a.centerX, data.d / 2)
        compare(a.centerY, data.d / 2)
        compare(a.radiusX, data.r)
        compare(a.radiusY, data.r)
        compare(a.startAngle, -90, "官方 rotate(-90deg)：从 12 点方向顺时针")
        compare(a.sweepAngle, data.c * 3.6)
        const o = testCase.findChild(c, "orbitArc")
        compare(o.startAngle, 0)
        compare(o.sweepAngle, 360)
        c.destroy()
    }

    // Qt 6.11 的 Shape 默认走 GeometryRenderer：把弧线折成一段段短直线、边缘不做混合，
    // Item.antialiasing 对它完全无效（renderStrategy 那个老属性在 6.x 已经删了）。
    // 像素复核：tests/tmp_progress_ring_shot.qml 把同一个环分别按两种渲染器画出来，
    // tests/tmp_ring_measure.py 量边缘 —— 默认档 0 个部分覆盖像素、内沿 277 个角度只落在
    // 6 个半径值上（正多边形）；CurveRenderer 433 个部分覆盖像素、65 个半径值。
    function test_ringUsesCurveRenderer() {
        const c = make({ x: 20, y: 20, type: "circle", percent: 50 })
        verify(c, "Progress 创建失败")
        compare(ring(c).preferredRendererType, Shape.CurveRenderer,
            "环形必须点名 CurveRenderer，否则整圈全是锯齿")
        c.destroy()
    }

    function test_ringStrokeAndCaps() {
        const c = make({ x: 20, y: 20, type: "circle", percent: 30 })
        verify(c, "Progress 创建失败")
        const arc = arcPath(c)
        const orbit = orbitPath(c)
        compare(arc.strokeWidth, 4)
        compare(orbit.strokeWidth, 4)
        compare(arc.capStyle, ShapePath.RoundCap)
        compare(orbit.capStyle, ShapePath.RoundCap)
        compare(arc.strokeColor.toString(), "#3bb346")
        compare(orbit.strokeColor.toString(), "#0d2e3238")
        compare(arc.fillColor.toString(), "#00000000", "官方 fill=\"transparent\"")
        c.destroy()

        const square = make({ x: 20, y: 40, type: "circle", strokeLinecap: "square", orbitStroke: "#123456" })
        verify(square, "Progress 创建失败")
        compare(square.capStyle, ShapePath.SquareCap)
        compare(arcPath(square).capStyle, ShapePath.SquareCap)
        compare(orbitPath(square).capStyle, ShapePath.SquareCap)
        compare(orbitPath(square).strokeColor.toString(), "#123456")
        square.destroy()
    }

    function test_strokeWidthThickensTheRing() {
        const c = make({ x: 20, y: 20, type: "circle", strokeWidth: 10, percent: 40 })
        verify(c, "Progress 创建失败")
        compare(arcPath(c).strokeWidth, 10)
        compare(orbitPath(c).strokeWidth, 10)
        compare(c.diameter, 72, "笔画变粗不改直径，半径往里缩")
        compare(c.radius, 31)
        c.destroy()
    }

    function test_circleInfoIsCentredText() {
        const c = make({ x: 20, y: 20, type: "circle", showInfo: true, motion: false, percent: 75 })
        verify(c, "Progress 创建失败")
        const i = info(c)
        compare(i.text, "75%")
        compare(i.width, 72)
        compare(i.x, 0)
        compare(i.y, (72 - i.height) / 2)
        compare(i.horizontalAlignment, Text.AlignHCenter)
        compare(i.font.weight, Font.Normal, "环形文字 400，条状 600")
        c.destroy()

        const small = make({ x: 20, y: 40, type: "circle", size: "small", showInfo: true, percent: 30 })
        verify(small, "Progress 创建失败")
        compare(info(small).visible, false, "小号环形官方一律不画中心文字")
        small.destroy()
    }

    // ---------------------------------------------------------------- 取色（stroke / 档位 / 渐变）

    function test_strokeStringResolvesColors_data() {
        return [
            { tag: "hex", stroke: "#f93920", expect: "#f93920" },
            { tag: "hexAlpha", stroke: "#ff000080", expect: "#80ff0000" },
            { tag: "shorthand", stroke: "#f93", expect: "#ff9933" },
            { tag: "rgb", stroke: "rgb(10, 20, 30)", expect: "#0a141e" },
            { tag: "rgbaDecimalAlpha", stroke: "rgba(10, 20, 30, 0.5)", expect: "#800a141e" },
            { tag: "hsla", stroke: "hsla(125, 50%, 46% / 1)", expect: "#3bb044" },
            { tag: "tokenVar", stroke: "var(--semi-color-warning)", expect: "#fc8800" },
            { tag: "bareFamily", stroke: "red", expect: "#f93920" },
            { tag: "familyStep", stroke: "orange-9", expect: "#541d00" },
            { tag: "familyStepTwoDigitName", stroke: "light-green-8", expect: "#395b1b" },
            { tag: "black", stroke: "black", expect: "#000000" },
            { tag: "unknown", stroke: "not-a-color", expect: "#3bb346" }
        ]
    }

    function test_strokeStringResolvesColors(data) {
        const c = make({ x: 20, y: 20, width: 200, height: 4, percent: 30, stroke: data.stroke })
        verify(c, "Progress 创建失败")
        compare(c.fillColor.toString(), data.expect, data.tag + "：" + data.stroke)
        compare(inner(c).color.toString(), data.expect, data.tag + " 应该画到进度块上")
        c.destroy()
    }

    // generateColor 的档位查表：命中取它、落在两档之间取上一档、比首档小回默认、比末档大取末档
    function test_strokeRampPicksASolidColor_data() {
        return [
            { tag: "belowFirst", percent: 10, expect: "#3bb346" },
            { tag: "onFirst", percent: 20, expect: "#f93920" },
            { tag: "between", percent: 50, expect: "#f93920" },
            { tag: "onMiddle", percent: 80, expect: "#fc8800" },
            { tag: "aboveLast", percent: 100, expect: "#541d00" },
            { tag: "rawOver", percent: 150, expect: "#541d00" },
            { tag: "rawNegative", percent: -5, expect: "#3bb346" }
        ]
    }

    function test_strokeRampPicksASolidColor(data) {
        const c = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            percent: data.percent,
            stroke: [
                { percent: 20, color: "#f93920" },
                { percent: 80, color: "#fc8800" },
                { percent: 100, color: "#541d00" }
            ]
        })
        verify(c, "Progress 创建失败")
        compare(c.fillColor.toString(), data.expect, data.tag + "（percent=" + data.percent + "）")
        compare(inner(c).color.toString(), data.expect)
        c.destroy()
    }

    function test_strokeRampSortsBeforeMatching() {
        // 官方先按 percent 升序排再匹配。30 落在 20 与 80 之间 ⇒ 取上一档红；
        // 不排序的话首档是数组第一项 80，80 > 30 直接回默认绿 —— 只有这个落点能把「排没排」分开
        const c = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            percent: 30,
            stroke: [
                { percent: 80, color: "#fc8800" },
                { percent: 20, color: "#f93920" }
            ]
        })
        verify(c, "Progress 创建失败")
        compare(c.fillColor.toString(), "#f93920")
        compare(inner(c).color.toString(), "#f93920")
        c.destroy()
    }

    // 官方 selectStroke 传的是 this.props.percent（**没夹过**），所以档位可以定在 100 以上
    function test_rampLookupUsesTheRawPercent() {
        const over = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            percent: 150,
            stroke: [
                { percent: 20, color: "#f93920" },
                { percent: 110, color: "#3366ff" }
            ]
        })
        verify(over, "Progress 创建失败")
        compare(over.fillColor.toString(), "#3366ff", "原始 150 越过末档 110 ⇒ 取末档")
        compare(over.clamped, 100)
        compare(inner(over).width, 200, "画多少仍然按夹过的 100%")
        over.destroy()

        const mid = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            percent: 100,
            stroke: [
                { percent: 20, color: "#f93920" },
                { percent: 110, color: "#3366ff" }
            ]
        })
        verify(mid, "Progress 创建失败")
        compare(mid.fillColor.toString(), "#f93920", "100 落在 20 与 110 之间 ⇒ 取上一档")
        mid.destroy()
    }

    function test_strokeRampColorsTheRingToo() {
        const c = make({
            x: 20,
            y: 20,
            type: "circle",
            percent: 30,
            stroke: [
                { percent: 20, color: "#f93920" },
                { percent: 80, color: "#fc8800" }
            ]
        })
        verify(c, "Progress 创建失败")
        compare(arcPath(c).strokeColor.toString(), "#f93920")
        c.destroy()
    }

    function test_rampTokenColorsResolve() {
        const c = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            percent: 50,
            stroke: [
                { percent: 20, color: "var(--semi-color-warning)" },
                { percent: 80, color: "light-green-8" }
            ]
        })
        verify(c, "Progress 创建失败")
        compare(c.fillColor.toString(), "#fc8800")
        c.destroy()
    }

    // strokeGradient 打开后不是空间渐变，而是在相邻两档间插值出一个纯色（官方 tHex）
    function test_strokeGradientInterpolates_data() {
        return [
            { tag: "atFirst", percent: 20, expect: "#ff0000" },
            { tag: "quarter", percent: 35, expect: "#bf4000" },
            { tag: "mid", percent: 50, expect: "#808000" },
            { tag: "threeQuarters", percent: 65, expect: "#40bf00" },
            { tag: "atLast", percent: 80, expect: "#00ff00" },
            { tag: "aboveLast", percent: 95, expect: "#00ff00" }
        ]
    }

    function test_strokeGradientInterpolates(data) {
        const c = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            percent: data.percent,
            strokeGradient: true,
            stroke: [
                { percent: 20, color: "#ff0000" },
                { percent: 80, color: "#00ff00" }
            ]
        })
        verify(c, "Progress 创建失败")
        compare(c.fillColor.toString(), data.expect, data.tag + "（percent=" + data.percent + "）")
        compare(inner(c).color.toString(), data.expect)
        c.destroy()
    }

    function test_gradientFlagOffKeepsTheStep() {
        const c = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            percent: 50,
            strokeGradient: false,
            stroke: [
                { percent: 20, color: "#ff0000" },
                { percent: 80, color: "#00ff00" }
            ]
        })
        verify(c, "Progress 创建失败")
        compare(c.fillColor.toString(), "#ff0000", "不插值时落在 50 应该还是 20 那一档")
        c.destroy()
    }

    // ---------------------------------------------------------------- 数字补间

    function test_firstRenderDoesNotAnimate() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, showInfo: true, percent: 50 })
        verify(c, "Progress 创建失败")
        // 轨道被文本挤成 139（200 - 45 - 16），进度块是它的一半
        compare(c.numberShown, 50)
        compare(c.shownPercent, 50)
        compare(info(c).text, "50%")
        compare(track(c).width, 139)
        compare(inner(c).width, 69.5)
        // 补间要在后面几帧里也一次都没冒头（只读创建那一瞬间的值抓不到「首帧才开始动」的写法）
        let drifted = false
        for (let n = 0; n < 6; ++n) {
            wait(30)
            if (c.numberShown !== 50 || c.shownPercent !== 50)
                drifted = true
        }
        compare(drifted, false, "首次渲染不该有补间")
        compare(c.numberShown, 50)
        compare(c.shownPercent, 50)
        compare(inner(c).width, 69.5)
        c.destroy()

        // 另一条构造路径：percent 写在对象定义里（创建过程中就收到 percentChanged 的那一支）
        const d = makeQml("Progress { x: 20; y: 60; width: 200; height: 4; showInfo: true; percent: 50 }")
        verify(d, "Progress 创建失败")
        compare(d.numberShown, 50)
        compare(d.shownPercent, 50)
        let driftedInline = false
        for (let n = 0; n < 6; ++n) {
            wait(30)
            if (d.numberShown !== 50 || d.shownPercent !== 50)
                driftedInline = true
        }
        compare(driftedInline, false, "对象定义里写 percent 也不该触发补间")
        compare(inner(d).width, 69.5)
        d.destroy()
    }

    function test_numberTweenIsIntegerAndLandsExactly() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, showInfo: true, motion: false, percent: 10 })
        verify(c, "Progress 创建失败")
        compare(c.numberShown, 10)
        c.motion = true
        c.percent = 60
        let sawIntermediate = false
        let sawFraction = true
        for (let n = 0; n < 12 && !sawIntermediate; ++n) {
            wait(25)
            const v = c.numberShown
            if (v > 10.5 && v < 59.5) {
                sawIntermediate = true
                sawFraction = /\./.test(info(c).text)
            }
        }
        compare(sawIntermediate, true, "motion 打开时数字应当补间")
        compare(sawFraction, false, "补间途中官方每帧 parseInt，文本不该带小数：" + info(c).text)
        tryCompare(c, "numberShown", 60, 1500)
        compare(info(c).text, "60%")
        c.destroy()
    }

    function test_motionOffMovesTheNumberInstantly() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, showInfo: true, motion: false, percent: 10 })
        verify(c, "Progress 创建失败")
        c.percent = 60
        compare(c.numberShown, 60)
        compare(info(c).text, "60%")
        c.destroy()
    }

    function test_geometryTransitionIgnoresMotionFlag() {
        // 官方那条 CSS transition 与 semi-animation（motion）是两套，motion:false 只关数字
        const c = make({ x: 20, y: 20, width: 200, height: 4, motion: false, percent: 10 })
        verify(c, "Progress 创建失败")
        c.percent = 60
        compare(c.numberShown, 60)
        compare(c.shownPercent, 10)
        compare(inner(c).width, 20)
        tryCompare(c, "shownPercent", 60, 1500)
        compare(inner(c).width, 120)
        c.destroy()
    }

    function test_arcLengthFollowsTheTween() {
        const c = make({ x: 20, y: 20, type: "circle", motion: false, percent: 0 })
        verify(c, "Progress 创建失败")
        c.percent = 25
        compare(innerArc(c).sweepAngle, 0)
        tryCompare(c, "shownPercent", 25, 1500)
        compare(innerArc(c).sweepAngle, 90)
        c.destroy()
    }

    function test_outOfRangePercentStillClampsTheTween() {
        const plain = make({ x: 20, y: 20, width: 200, height: 4, motion: false, percent: 0 })
        verify(plain, "Progress 创建失败")
        plain.percent = 150
        tryCompare(plain, "shownPercent", 100, 1500)
        compare(inner(plain).width, 200)
        compare(plain.clamped, 100)
        compare(plain.numberShown, 150, "补间量本身存的是原始 percent")
        plain.destroy()

        // 官方 format(percNumber)，percNumber = calcPercent(percentNumber) ⇒ 连文本也夹到 100
        const withText = make({ x: 20, y: 40, width: 200, height: 4, motion: false, showInfo: true, percent: 0 })
        verify(withText, "Progress 创建失败")
        withText.percent = 150
        compare(info(withText).text, "100%")
        withText.destroy()
    }

    // ---------------------------------------------------------------- 主题跟随

    function test_followsDarkMode() {
        const c = make({ x: 20, y: 20, width: 200, height: 4, percent: 50 })
        verify(c, "Progress 创建失败")
        compare(rail(c).color.toString(), "#0d2e3238")
        compare(inner(c).color.toString(), "#3bb346")
        Theme.mode = Theme.Dark
        compare(rail(c).color.toString(), "#1fffffff", "轨道 = colorFill0 的暗色档")
        compare(inner(c).color.toString(), "#5dc264", "进度块 = success 的暗色档")
        Theme.mode = Theme.Light
        compare(rail(c).color.toString(), "#0d2e3238")
        compare(inner(c).color.toString(), "#3bb346")
        c.destroy()
    }

    function test_darkModePaletteIsUsedForTokenStrings() {
        Theme.mode = Theme.Dark
        const c = make({ x: 20, y: 20, width: 200, height: 4, percent: 30, stroke: "orange-9" })
        verify(c, "Progress 创建失败")
        compare(c.fillColor.toString(), Theme.current.orange[9].toString())
        Theme.mode = Theme.Light
        compare(c.fillColor.toString(), "#541d00")
        c.destroy()
    }

    // ---------------------------------------------------------------- ARIA

    function test_ariaSurface() {
        const label = Qt.createQmlObject("import QtQuick; Text { objectName: 'ariaLabelSource'; text: '上传' }",
            testCase, "ariaLabelSource")
        const c = make({
            x: 20,
            y: 20,
            width: 200,
            height: 4,
            ariaLabel: "部署进度",
            ariaValueText: "已经完成大半",
            ariaLabelledBy: label
        })
        verify(c, "Progress 创建失败")
        compare(c.Accessible.role, Accessible.ProgressBar)
        compare(c.Accessible.name, "部署进度")
        compare(c.Accessible.description, "已经完成大半")
        compare(c.Accessible.labelledBy, label)
        c.destroy()
        label.destroy()
    }

    function test_ariaDefaultsAreEmpty() {
        const c = make({ x: 20, y: 20, width: 200, height: 4 })
        verify(c, "Progress 创建失败")
        compare(c.ariaLabel, "")
        compare(c.ariaValueText, "")
        compare(c.Accessible.name, "")
        compare(c.Accessible.description, "")
        compare(c.Accessible.labelledBy, null)
        c.destroy()
    }

    // ---------------------------------------------------------------- 官方示例的形态组合

    function test_officialGalleryShapes() {
        // 「动态改变进度」那一节：条状 + 环形同时吃同一个 percent
        const line = make({ x: 20, y: 20, width: 200, height: 4, motion: false, percent: 40 })
        verify(line, "Progress 创建失败")
        compare(inner(line).width, 80)

        const circle = make({ x: 20, y: 60, type: "circle", motion: false, percent: 40, showInfo: true })
        verify(circle, "Progress 创建失败")
        compare(circle.width, 72)
        compare(innerArc(circle).sweepAngle, 144)
        compare(info(circle).text, "40%")
        line.destroy()
        circle.destroy()
    }
}
