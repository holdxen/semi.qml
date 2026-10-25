import QtQuick
import QtTest
import Semi

// Skeleton：属性面照 semi-ui/skeleton（index.tsx 的 SkeletonProps + item.tsx 的五个占位件），
// 几何照 semi-foundation/skeleton/skeleton.scss + variables.scss，流光照官方那条
// linear-gradient(90deg, fill-0 25%, fill-1 44%, fill-0 88%) + background-size:400% +
// background-position 100%→0（1400ms ease infinite）。
// 期望值多数写成字面量（20/24/32/48/72/128、24、115×32、16、10、60%、1400、0.25/0.44/0.88），
// 这样改坏组件里的令牌或换算就会红。
TestCase {
    id: testCase

    name: "Skeleton"
    when: windowShown
    width: 800
    height: 600

    Component {
        id: avatarPlaceholder
        SkeletonAvatar {}
    }

    Component {
        id: buttonPlaceholder
        SkeletonButton {}
    }

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    // 造一个 Skeleton 容器。外面套一层有宽度的 Item，官方那层 div 的「100% 宽」才有参照。
    // 末尾等一帧：位置器（Paragraph 的 Column）要 polish 一轮才排得出 y / implicitHeight。
    function makeQml(source) {
        const wrap = Qt.createQmlObject("import QtQuick; import Semi;"
            + " Item { width: 520; height: 400; " + source + " }", testCase, "skeletonProbe")
        wait(16)
        return wrap
    }

    function host(wrap) {
        return testCase.findChild(wrap, "skeleton")
    }

    function block(wrap, name) {
        return testCase.findChild(wrap, name)
    }

    // Paragraph 的每一格（Column 里 objectName 是 skeletonBlock 的直接子项）
    function lines(paragraph) {
        const out = [];
        const kids = paragraph.children;
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].objectName === "skeletonBlock")
                out.push(kids[i]);
        }
        return out;
    }

    // ---------------- 容器：官方 prop 面 ----------------

    function test_containerDefaults() {
        const wrap = makeQml("Skeleton { }")
        const sk = host(wrap)
        compare(sk.active, false)        // index.tsx 没给 active 默认值
        compare(sk.loading, true)        // index.tsx defaultProps
        compare(sk.placeholder, null)
        verify(sk.placeholderItem === null, "没给 placeholder 就没有占位节点")
        compare(sk.implicitHeight, 0)
        wrap.destroy()
    }

    function test_placeholderExistsOnlyWhileLoading() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar {} } }')
        const sk = host(wrap)
        verify(sk.placeholderItem !== null, "loading 默认 true，占位节点应在")
        compare(testCase.findChild(wrap, "skeletonContent").visible, false)

        sk.loading = false
        verify(sk.placeholderItem === null, "官方非 loading 时 placeholder 不进 DOM")
        compare(testCase.findChild(wrap, "skeletonContent").visible, true)

        sk.loading = true
        verify(sk.placeholderItem !== null, "切回 loading 要重新造一个")
        wrap.destroy()
    }

    function test_placeholderRebuiltWhenComponentChanges() {
        const wrap = makeQml('Skeleton { }')
        const sk = host(wrap)
        sk.placeholder = avatarPlaceholder
        wait(16)
        const first = sk.placeholderItem
        compare(first.objectName, "skeletonAvatar")
        sk.placeholder = buttonPlaceholder
        wait(16)
        verify(sk.placeholderItem !== first, "换 placeholder 应重建节点")
        compare(sk.placeholderItem.objectName, "skeletonButton")
        // 旧节点要真的拆掉，不能只是不再返回它
        compare(testCase.findChild(wrap, "skeletonPlaceholder").children.length, 1)
        wrap.destroy()
    }

    function test_containerWidthFollowsParent() {
        const wrap = makeQml("Skeleton { }")
        compare(host(wrap).width, 520)   // 官方 div 是块级元素
        wrap.destroy()

        const fixed = makeQml('Skeleton { width: 240 }')
        compare(host(fixed).width, 240)  // 官方 demo 的 style={{ width: 240 }}
        fixed.destroy()
    }

    function test_implicitHeightComesFromPlaceholderImplicitHeight() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar { size: "large" } } }')
        const sk = host(wrap)
        compare(sk.implicitHeight, 72)   // $width-skeleton_avatar_large
        compare(sk.height, 72)
        wrap.destroy()

        // 占位根节点只写 height 的话容器不会跟着长（官方 height:auto 在 QML 侧的落地口径）
        const manual = makeQml('Skeleton { placeholder: Component { Item { height: 120 } } }')
        compare(host(manual).implicitHeight, 0)
        manual.destroy()
    }

    function test_implicitHeightComesFromContentWhenLoaded() {
        const wrap = makeQml('Skeleton { loading: false; Rectangle { width: 100; height: 100 } }')
        const sk = host(wrap)
        compare(sk.implicitHeight, 100)
        wrap.destroy()

        // 来回拨 loading 也要给出同一个值 —— 绑定环就是在这一步冒出来的
        // （宿主原来是 anchors.fill: parent，容器的高又由宿主的内容算 ⇒ 读一次就自己踩自己一圈，
        // 值还是对的、只刷 QML 警告，所以只能靠抓警告的探针发现：tests/tmp_skeleton_loop.qml）
        const flip = makeQml('Skeleton { placeholder: Component { SkeletonAvatar { size: "large" } }'
            + " Rectangle { width: 100; height: 100 } }")
        const sk2 = host(flip)
        compare(sk2.implicitHeight, 72)
        sk2.loading = false
        wait(16)
        compare(sk2.implicitHeight, 100, "拨到显示内容：高要跟内容")
        compare(sk2.height, 100)
        sk2.loading = true
        wait(16)
        compare(sk2.implicitHeight, 72, "拨回占位：高要跟占位件")
        compare(sk2.height, 72)
        flip.destroy()
    }

    // ---------------- 五个占位件的几何 ----------------

    function test_avatarDefaultIsMediumCircle() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        compare(av.size, "medium")
        compare(av.shape, "circle")
        compare(av.width, 48)            // $width-skeleton_avatar_medium
        compare(av.height, 48)
        compare(av.radius, 24)           // border-radius: 50%
        wrap.destroy()
    }

    function test_avatarSizeLadder() {
        const sizes = [
            ["extra-extra-small", 20], ["extra-small", 24], ["small", 32],
            ["medium", 48], ["large", 72], ["extra-large", 128]
        ]
        for (let i = 0; i < sizes.length; ++i) {
            const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar { size: "'
                + sizes[i][0] + '" } } }')
            const av = block(wrap, "skeletonAvatar")
            compare(av.width, sizes[i][1], sizes[i][0] + " 的边长")
            compare(av.height, sizes[i][1], sizes[i][0] + " 的边长")
            wrap.destroy()
        }
    }

    function test_avatarSquareUsesSmallRadius() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar { shape: "square" } } }')
        const av = block(wrap, "skeletonAvatar")
        compare(av.radius, Theme.current.radiusSmall)   // 只有 -circle 才 50%，其余走 $radius-skeleton_item
        wrap.destroy()
    }

    function test_titleIsFullWidthAnd24Tall() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonTitle {} } }')
        const title = block(wrap, "skeletonTitle")
        compare(title.height, 24)        // $height-skeleton_title = $height-control-small
        compare(title.width, 520, "官方是 width:100%")
        compare(title.radius, Theme.current.radiusSmall)
        wrap.destroy()

        const fixed = makeQml('Skeleton { placeholder: Component { SkeletonTitle { width: 120 } } }')
        compare(block(fixed, "skeletonTitle").width, 120)   // 官方 demo 的 style={{ width: 120 }}
        fixed.destroy()
    }

    function test_buttonIs115By32() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonButton {} } }')
        const btn = block(wrap, "skeletonButton")
        compare(btn.width, 115)          // $width-skeleton_button
        compare(btn.height, 32)          // $height-skeleton_button = $height-control-default
        compare(btn.radius, Theme.current.radiusSmall)
        wrap.destroy()
    }

    function test_imageFillsContainerBox() {
        const wrap = makeQml('Skeleton { width: 200; height: 150; placeholder: Component { SkeletonImage {} } }')
        const img = block(wrap, "skeletonImage")
        compare(img.width, 200)          // .semi-skeleton-image { width:100%; height:100% }
        compare(img.height, 150)
        wrap.destroy()

        // 容器不给高，100% 高就是 0 —— 官方同理，所以官方 demo 都是配着 style 高度用的
        const bare = makeQml('Skeleton { width: 200; placeholder: Component { SkeletonImage {} } }')
        compare(block(bare, "skeletonImage").height, 0)
        bare.destroy()
    }

    function test_paragraphDefaultsToFourRows() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonParagraph {} } }')
        const para = block(wrap, "skeletonParagraph")
        compare(para.rows, 4)
        const rows = lines(para)
        compare(rows.length, 4)
        for (let i = 0; i < rows.length; ++i) {
            compare(rows[i].height, 16, "第 " + i + " 行高 $height-skeleton_li")
            compare(rows[i].y, i * 26, "行间距 $spacing-skeleton_li-marginBottom = 10")
        }
        compare(rows[3].width, 520 * 0.6, "li:last-child { width: 60% }")
        compare(rows[0].width, 520, "li { width: 100% }")
        compare(para.height, 4 * 16 + 3 * 10)
        wrap.destroy()
    }

    function test_paragraphSingleRowStillSixtyPercent() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonParagraph { rows: 1; width: 80 } } }')
        const para = block(wrap, "skeletonParagraph")
        const rows = lines(para)
        compare(rows.length, 1)
        compare(para.width, 80)
        compare(rows[0].width, 48, "rows=1 时那一行既是 first 也是 last ⇒ 60%")
        wrap.destroy()
    }

    function test_paragraphRowsShrinkAndGrow() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonParagraph { rows: 2 } } }')
        const para = block(wrap, "skeletonParagraph")
        compare(lines(para).length, 2)
        compare(para.height, 16 + 10 + 16)
        para.rows = 5
        wait(16)
        compare(lines(para).length, 5)
        compare(para.height, 5 * 16 + 4 * 10)
        wrap.destroy()
    }

    function test_itemsShareFillZeroBase() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonButton {} } }')
        const btn = block(wrap, "skeletonButton")
        compare(btn.color.toString(), Theme.current.colorFill0.toString())
        compare(btn.shimmerOn, false, "active 默认 false ⇒ 不流光")
        verify(!btn.gradient, "不流光时不该挂渐变（官方只有 -active 才换背景）")
        wrap.destroy()
    }

    // ---------------- active 与流光 ----------------

    function test_activeHostLightsEveryDescendant() {
        const wrap = makeQml('Skeleton { active: true; placeholder: Component {\n'
            + ' Column { width: parent ? parent.width : 0\n'
            + ' SkeletonTitle {}\n SkeletonParagraph { width: 240; rows: 2 }\n } } }')
        const title = block(wrap, "skeletonTitle")
        compare(title.shimmerOn, true)
        const rows = lines(block(wrap, "skeletonParagraph"))
        compare(rows.length, 2)
        compare(rows[0].shimmerOn, true, "li 也在 .semi-skeleton-active 的后代选择器里")
        compare(rows[1].shimmerOn, true)
        wrap.destroy()
    }

    function test_activeFalsePutsTheBlocksBackToFlatFillZero() {
        const wrap = makeQml('Skeleton { active: true; placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        compare(av.shimmerOn, true)
        host(wrap).active = false
        compare(av.shimmerOn, false, "容器关掉 active，占位件要跟着停")
        verify(!av.gradient, "停了就退回静态的 fill-0（官方是撤掉 -active 那组规则）")
        wrap.destroy()
    }

    function test_shimmerDurationIs1400() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar {} } }')
        compare(block(wrap, "skeletonAvatar").shimmerDuration, 1400)   // $animation_duration-skeleton-highlight
        wrap.destroy()
    }

    // 官方带上的三个色标：fill-0 @25% / fill-1 @44% / fill-0 @88%，带是元素宽的 4 倍
    function test_sampleAtCssStopPositions() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        const base = Theme.current.colorFill0
        const bright = Theme.current.colorFill1
        compare(av.sampleAt(0).toString(), base.toString())
        compare(av.sampleAt(0.25).toString(), base.toString())
        compare(av.sampleAt(0.44).toString(), bright.toString())
        compare(av.sampleAt(0.88).toString(), base.toString())
        compare(av.sampleAt(1).toString(), base.toString())
        // 25%→44% 那段的坡宽 0.19，44%→88% 那段 0.44
        compare(av.sampleAt(0.25 + 0.19 / 2).a, (base.a + bright.a) / 2, 1e-6)
        compare(av.sampleAt(0.44 + 0.44 / 2).a, (base.a + bright.a) / 2, 1e-6)
        // 两段坡各取两点，其中 0.43 贴着坡顶 —— 分支阈值写错就露在这里
        compare(av.sampleAt(0.30).a, base.a + (bright.a - base.a) * ((0.30 - 0.25) / 0.19), 1e-6)
        compare(av.sampleAt(0.43).a, base.a + (bright.a - base.a) * ((0.43 - 0.25) / 0.19), 1e-6)
        compare(av.sampleAt(0.50).a, bright.a + (base.a - bright.a) * ((0.50 - 0.44) / 0.44), 1e-6)
        compare(av.sampleAt(0.80).a, bright.a + (base.a - bright.a) * ((0.80 - 0.44) / 0.44), 1e-6)
        wrap.destroy()
    }

    // phase 0 = background-position: 100% ⇒ 窗口是带的最后 1/4（0.75..1.0）。
    // 那一段不是纯色：44%→88% 的下坡还没走完，左半格还带着一点亮，到 88%（窗口 52% 处）才平。
    function test_stopsAtCycleStart() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        const base = Theme.current.colorFill0
        const bright = Theme.current.colorFill1
        const stops = av.stopsAtPhase(0)
        compare(stops.length, 5)
        const leftAlpha = bright.a + (base.a - bright.a) * ((0.75 - 0.44) / 0.44)
        compare(stops[0].position, 0)
        compare(stops[0].color.a, leftAlpha, 1e-6)
        compare(stops[1].position, 0, "25% 那个色标在窗口左边外面 ⇒ 塌到 0、取边上的颜色")
        compare(stops[1].color.a, leftAlpha, 1e-6)
        compare(stops[2].position, 0, "44% 也在外面")
        compare(stops[2].color.a, leftAlpha, 1e-6)
        compare(stops[3].position, (0.88 - 0.75) / 0.25, 1e-9)
        compare(stops[3].color.toString(), base.toString())
        compare(stops[4].position, 1)
        compare(stops[4].color.toString(), base.toString())
        wrap.destroy()
    }

    function test_stopsAtMidCycle() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        const base = Theme.current.colorFill0
        const bright = Theme.current.colorFill1
        // phase 0.5 ⇒ 窗口左沿在带的 0.375 处，高亮（0.44）落在窗口 26% 处
        const stops = av.stopsAtPhase(0.5)
        compare(stops[2].position, (0.44 - 0.375) / 0.25, 1e-9)
        compare(stops[2].position, 0.26, 1e-9)
        compare(stops[2].color.toString(), bright.toString())
        compare(stops[0].position, 0)
        compare(stops[4].position, 1)
        compare(stops[0].color.a, base.a + (bright.a - base.a) * ((0.375 - 0.25) / 0.19), 1e-6)
        compare(stops[4].color.a, bright.a + (base.a - bright.a) * ((0.625 - 0.44) / 0.44), 1e-6)
        // 掉在窗口外的色标塌到窗口边上，颜色取边上那份，等于和边重复 ⇒ 画出来不变
        compare(stops[1].position, 0)
        compare(stops[1].color.toString(), stops[0].color.toString())
        compare(stops[3].position, 1)
        compare(stops[3].color.toString(), stops[4].color.toString())
        wrap.destroy()
    }

    function test_stopsSweepLeftToRightAndStayInRange() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        const bright = Theme.current.colorFill1
        let peakAt = -1
        for (let phase = 0; phase <= 1.0001; phase += 0.01) {
            const stops = av.stopsAtPhase(phase)
            compare(stops[0].position, 0)
            compare(stops[4].position, 1)
            let previous = -1
            for (let i = 0; i < stops.length; ++i) {
                verify(stops[i].position >= 0 && stops[i].position <= 1, "phase=" + phase + " 越界")
                verify(stops[i].position >= previous - 1e-9, "色标位置必须单调不减，phase=" + phase)
                previous = stops[i].position
            }
            if (Math.abs(stops[2].color.a - bright.a) < 1e-9)
                peakAt = stops[2].position
        }
        verify(peakAt > 0.9, "一圈结束时高亮已经扫到右边缘，实测 " + peakAt)
        wrap.destroy()
    }

    function test_peakEntersLeftAndExitsRight() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        const bright = Theme.current.colorFill1
        // 高亮刚进左沿：0.44 落在窗口最左 ⇒ windowStart = 0.44 ⇒ phase = 1 - 0.44/0.75
        const entering = av.stopsAtPhase(1 - 0.44 / 0.75)
        compare(entering[2].position, 0, 1e-9)
        compare(entering[2].color.toString(), bright.toString())
        // 高亮到右沿：windowStart = 0.19
        const leaving = av.stopsAtPhase(1 - 0.19 / 0.75)
        compare(leaving[2].position, 1, 1e-9)
        wrap.destroy()
    }

    function test_bandPhaseAdvancesOnlyWhenActive() {
        const wrap = makeQml('Skeleton { placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        wait(300)
        compare(av.bandPhase, 0, "active 为 false 时动画不该跑")

        host(wrap).active = true
        wait(300)
        verify(av.bandPhase > 0.001, "active 之后进度应往前走，实测 " + av.bandPhase)
        wrap.destroy()
    }

    function test_gradientStopsFollowBandPhase() {
        const wrap = makeQml('Skeleton { active: true; placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        av.bandPhase = 0.5
        compare(av.gradient.stops[2].position, 0.26, 1e-9)
        compare(av.gradient.stops[2].color.toString(), Theme.current.colorFill1.toString())
        av.bandPhase = 0
        compare(av.gradient.stops[2].position, 0, 1e-9)
        compare(av.gradient.stops[2].color.toString(), av.gradient.stops[0].color.toString(),
            1e-9, "窗口外的色标要和边上的色标重合，不然等于凭空多一个色标")
        wrap.destroy()
    }

    function test_gradientOrientationIsHorizontal() {
        const wrap = makeQml('Skeleton { active: true; placeholder: Component { SkeletonAvatar {} } }')
        const av = block(wrap, "skeletonAvatar")
        verify(av.gradient !== null)
        compare(av.gradient.orientation, Gradient.Horizontal)   // linear-gradient(90deg, …)
        compare(av.gradient.stops.length, 5)
        wrap.destroy()
    }
}
