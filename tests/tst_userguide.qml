import QtQuick
import QtQuick.Controls as C
import QtQuick.Window
import QtTest
import Semi

// UserGuide 的用例。规格逐条出处写在 src/UserGuide.qml 的文件头。
TestCase {
    id: testCase

    name: "UserGuide"
    when: windowShown
    width: 900
    height: 600

    // 附加属性只能在 QML 语法里取（JS 里 testCase.Window.window 是 undefined）
    readonly property var win: Window.window

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    // C.Popup 不是 Item，没有 children：视觉树挂在 contentItem / background 上
    function kidsOf(node) {
        if (node.children !== undefined)
            return node.children
        const out = []
        if (node.contentItem !== undefined && node.contentItem)
            out.push(node.contentItem)
        if (node.background !== undefined && node.background)
            out.push(node.background)
        return out
    }

    function partOf(node, name) {
        if (node === null || node === undefined)
            return null
        if (node.objectName === name)
            return node
        const kids = testCase.kidsOf(node)
        for (let i = 0; i < kids.length; ++i) {
            const hit = testCase.partOf(kids[i], name)
            if (hit !== null)
                return hit
        }
        return null
    }

    // 按只有 UserGuide 才有的 stepCount 把引导本体从宿主里捞出来
    function guideOf(root) {
        for (let i = 0; i < root.children.length; ++i) {
            const child = root.children[i]
            if (child.stepCount !== undefined)
                return child
            const nested = testCase.guideOf(child)
            if (nested !== null)
                return nested
        }
        return null
    }

    readonly property string defaultFirst: "{ title: '第一步', description: '说明一', target: t1 }"
    readonly property string defaultSecond: "{ title: '第二步', description: '说明二', target: t2 }"

    // 公共宿主：两块目标 + 一颗页面上的键（拦截用例要吃它的点击数）+ 两幕引导。
    // attrs 传官方那一串属性，尾巴上的逗号会被 QML 的 `}` 顶掉，所以换成 `;`。
    function makeHost(attrs, first, second) {
        // QML 对象体里属性之间要用 `;` 或换行，逗号只在数组字面量里合法
        const extra = attrs === undefined ? "" : attrs.replace(/,+$/, "").replace(/,/g, ";")
        return testCase.make("Item { id: root; property Item first: t1; property Item second: t2;"
            + " property Item outsideBtn: outside; property int hits: 0;"
            + " width: 700; height: 500;"
            + " Rectangle { id: t1; x: 100; y: 60; width: 80; height: 40 }"
            + " Rectangle { id: t2; x: 300; y: 300; width: 80; height: 40 }"
            + " Button { id: outside; x: 20; y: 440; width: 90; height: 32;"
            + "   text: '页面键'; onClicked: root.hits++ }"
            + " UserGuide { visible: true;"
            + (extra === "" ? "" : " " + extra + ";")
            + " steps: ["
            + (first !== undefined ? first : testCase.defaultFirst) + ", "
            + (second !== undefined ? second : testCase.defaultSecond) + "] } }")
    }

    // 走窗口那条路发事件：直接 mouseClick(目标) 会跳过命中测试，拦不拦都点得动
    function clickIn(item, posX, posY) {
        const p = item.mapToItem(testCase.win.contentItem, posX, posY)
        testCase.mouseClick(testCase.win.contentItem, p.x, p.y)
    }

    TextMetrics {
        id: tmTitle

        font.pixelSize: Theme.current.fontSizeHeader5
        font.weight: Font.DemiBold
    }

    TextMetrics {
        id: tmDescription

        font.pixelSize: Theme.current.fontSizeRegular
    }

    TextMetrics {
        id: tmIndicator

        font.pixelSize: Theme.current.fontSizeRegular
    }

    // ---------------- 属性面与默认值 ----------------

    function test_userGuideDefaults() {
        const g = testCase.make("UserGuide { }")
        compare(g.mode, "popup")
        compare(g.mask, true)
        compare(g.theme, "default")
        compare(g.position, Enums.Bottom)
        compare(g.showPrevButton, true)
        compare(g.showSkipButton, true)
        compare(g.spotlightPadding, undefined)
        compare(g.current, undefined)
        compare(g.controlled, false)
        compare(g.zIndex, 1030)
        compare(g.finishText, "完成")
        compare(g.container, null)
        // locale.UserGuide（zh_CN.ts:192-197）
        compare(g.skipLabel, "跳过")
        compare(g.prevLabel, "上一步")
        compare(g.nextLabel, "下一步")
        compare(g.visible, false)
        compare(g.stepCount, 0)
        compare(g.shown, false)
        compare(g.overlayLayer.visible, false)
        compare(g.popupCard.visible, false)
        compare(g.modalCard.visible, false)
        g.destroy()
    }

    function test_localeTokensAreTheDefaultSizes() {
        // 卡片度量的四个令牌，抄错一位整版排版就跑
        const g = testCase.make("UserGuide { }")
        compare(g.popoverWidthMax, 400, "$width-userGuide_popover-default")
        compare(g.bodyPadding, 24, "$spacing-userGuide_popup_content_body-padding")
        compare(g.titleGap, 8, "…popup_content_title-marginBottom")
        compare(g.descriptionGap, 48, "…popup_content_description-marginBottom")
        compare(g.buttonGap, 12, "…popup_content_button-gap")
        compare(g.buttonsMarginLeft, 120, "…popup_content_button-marginLeft")
        compare(g.popupCoverHeight, 200, "$height-userGuide_popup_content_cover-default")
        compare(g.titleLineHeight, 24)
        compare(g.descriptionLineHeight, 20)
        compare(g.indicatorLineHeight, 20)
        compare(g.modalCardWidth, 600, "$width-userGuide_modal_content_cover-default")
        compare(g.modalCoverHeight, 300, "$height-userGuide_modal_content_cover-default")
        compare(g.modalIndicatorHeight, 30, "$height-userGuide_modal_content_indicator-default")
        compare(g.modalDotSize, 6)
        compare(g.modalDotGap, 8, "$spacing-userGuide_popup_content_indicator-gap")
        compare(g.modalBodyPaddingX, 48, "$spacing-userGuide_modal_content_body-padding")
        compare(g.modalFooterPadding, 24, "$spacing-userGuide_modal_content_footer-padding")
        compare(g.motionDuration, 200, "$transition_duration-userGuide_spotLight")
        g.destroy()
    }

    function test_visibleFalseRendersNothing() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " Rectangle { id: t; x: 10; y: 10; width: 40; height: 40 }"
            + " UserGuide { visible: false; steps: [{ title: 'A', description: 'B', target: t }] } }")
        wait(120)
        const g = testCase.guideOf(host)
        compare(g.shown, false)
        compare(g.popupCard.visible, false)
        compare(g.overlayLayer.visible, false)
        host.destroy()
    }

    function test_emptyStepsShowsNothing() {
        // index.tsx:527：visible 但 steps 为空 ⇒ 整片不渲染
        const g = testCase.make("UserGuide { visible: true }")
        wait(120)
        compare(g.stepCount, 0)
        compare(g.shown, false)
        compare(g.isLastStep, false, "index.tsx:248 的 isLast 用等号比：0 !== -1")
        compare(g.nextLabel, "下一步")
        compare(g.popupCard.visible, false)
        compare(g.overlayLayer.visible, false)
        g.destroy()
    }

    function test_stepWithoutTargetRendersNothing() {
        // renderStep:319 与 renderSpotlight:361 都先判 step.target
        const host = testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { visible: true; steps: [{ title: '没有目标', description: 'x' }] } }")
        wait(120)
        const g = testCase.guideOf(host)
        compare(g.targetTaken, false)
        compare(g.spotlightTaken, false)
        compare(g.popupCard.visible, false)
        compare(testCase.partOf(g.overlayLayer, "userGuideMask").visible, false)
        compare(testCase.partOf(g.overlayLayer, "userGuideBlockTop").enabled, false)
        host.destroy()
    }

    // ---------------- 高亮矩形与 padding 取值 ----------------

    function test_spotlightDefaultPaddingIsFive() {
        const host = testCase.makeHost()
        wait(150)
        const g = testCase.guideOf(host)
        const origin = host.first.mapToItem(g.overlayLayer, 0, 0)
        compare(g.finalPadding, 5, "numbers.DEFAULT_SPOTLIGHT_PADDING")
        compare(g.spotlight.x, origin.x - 5)
        compare(g.spotlight.y, origin.y - 5)
        compare(g.spotlight.width, 80 + 10)
        compare(g.spotlight.height, 40 + 10)
        host.destroy()
    }

    function test_spotlightPaddingGlobalAndPerStep() {
        const host = testCase.make("Item { id: root; property Item first: t1;"
            + " width: 700; height: 500;"
            + " Rectangle { id: t1; x: 100; y: 60; width: 80; height: 40 }"
            + " UserGuide { visible: true; spotlightPadding: 10; steps: ["
            + "   { title: '全局 10', target: t1 },"
            + "   { title: '单步 15', spotlightPadding: 15, target: t1 },"
            + "   { title: '单步 0', spotlightPadding: 0, target: t1 }] } }")
        wait(150)
        const g = testCase.guideOf(host)
        const origin = host.first.mapToItem(g.overlayLayer, 0, 0)
        compare(g.finalPadding, 10)
        compare(g.spotlight.width, 80 + 20)
        compare(g.spotlight.x, origin.x - 10)

        g.handleNext()
        wait(50)
        compare(g.index, 1)
        compare(g.finalPadding, 15, "step.spotlightPadding 覆盖全局")
        compare(g.spotlight.x, origin.x - 15)
        compare(g.spotlight.height, 40 + 30)

        g.handleNext()
        wait(50)
        compare(g.finalPadding, 0, "官方 || 取值会把 0 吞成 5，这里按 getFinalPaading 的意图")
        compare(g.spotlight.width, 80)
        host.destroy()
    }

    function test_zeroGlobalPaddingAlsoRespected() {
        const host = testCase.make("Item { width: 400; height: 300;"
            + " Rectangle { id: t; x: 50; y: 50; width: 60; height: 30 }"
            + " UserGuide { visible: true; spotlightPadding: 0;"
            + "   steps: [{ title: 'A', target: t }] } }")
        wait(120)
        const g = testCase.guideOf(host)
        compare(g.finalPadding, 0)
        compare(g.spotlight.width, 60)
        compare(g.spotlight.height, 30)
        host.destroy()
    }

    function test_spotlightMotionUsesStandardCurve() {
        // 官方 $transition_function-userGuide_spotLight = cubic-bezier(0.4, 0, 0.2, 1)。
        // Qt 的 bezierCurve 要六个值（四值被静默丢弃退化线性，坑 134）；判别：0.35~0.45·duration
        // 窗口里标准曲线跑在 quad+0.2 前面（差 0.255~0.30），线性与 quad 都永远够不到。
        // duration 拉到 1500 采样（写权限见 motionDuration 注释）。
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        compare(g.motionCurve, [0.4, 0, 0.2, 1, 1, 1], "官方令牌 + Qt 要的隐含终点 (1,1)")
        const hole = testCase.partOf(g.overlayLayer, "userGuideHole")
        g.motionDuration = 1500
        const from = hole.x
        const to = host.second.mapToItem(g.overlayLayer, 0, 0).x - 5
        g.handleNext()
        const t0 = Date.now()
        tryVerify(function () {
            const t = (Date.now() - t0) / 1500
            if (t < 0.35 || t > 0.45)
                return false
            const quad = t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t)
            return (hole.x - from) / (to - from) > quad + 0.2
        }, 1500, "标准曲线要在判别窗内跑赢 quad+0.2（hole.x=" + hole.x + "）")
        host.destroy()
    }

    function test_holeAnimatesButAnchorSnaps() {
        // 官方只有 SVG 那块洞带 transition，锚点 div 是立刻到位的
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        const spot = testCase.partOf(g.overlayLayer, "userGuideSpot")
        const hole = testCase.partOf(g.overlayLayer, "userGuideHole")
        const origin = host.second.mapToItem(g.overlayLayer, 0, 0)
        g.handleNext()
        wait(50)
        compare(spot.x, origin.x - 5, "锚点这一份不动画，一帧就到")
        compare(spot.y, origin.y - 5)
        verify(Math.abs(hole.y - (origin.y - 5)) > 5, "洞还在 200ms 的路上")
        wait(400)
        compare(hole.x, spot.x, "200ms 之后两份重合")
        compare(hole.y, spot.y)
        host.destroy()
    }

    function test_holeSnapsOnFirstShow() {
        // 打开那一拍要把动画按住：不按住的话洞是从 (0,0) 长到目标上的（官方首次 render
        // 没有前值，直接就在那儿）。settleTimer 只压住开层这一拍，之后的换步照样动画。
        const host = testCase.make("Item { id: root; property bool open: false; property Item t: t;"
            + " width: 700; height: 500;"
            + " Rectangle { id: t; x: 320; y: 260; width: 80; height: 40 }"
            + " UserGuide { visible: root.open; steps: [{ title: 'A', target: t }] } }")
        wait(120)
        const g = testCase.guideOf(host)
        const hole = testCase.partOf(g.overlayLayer, "userGuideHole")
        host.open = true
        wait(60)
        const origin = host.t.mapToItem(g.overlayLayer, 0, 0)
        compare(hole.x, origin.x - 5, "开层 60ms 时洞已经在目标上，没有 200ms 的路程")
        compare(hole.y, origin.y - 5)
        compare(hole.width, 90)
        compare(hole.height, 50)
        host.destroy()
    }

    function test_spotlightTracksTargetLayout() {
        // mapToItem 不是响应式的：目标被位置器搬走之后，只在绑定里算一次的 rect
        // 会永远停在第一次求值的位置上（洞落在别处）。这里盯的就是这一条。
        const host = testCase.make("Item { id: root; property Item t: t; property Item gap: gap;"
            + " width: 700; height: 500;"
            + " Column { x: 20; y: 30;"
            + "   Item { id: gap; width: 10; height: 40 }"
            + "   Rectangle { id: t; width: 80; height: 40 } }"
            + " UserGuide { visible: true; steps: [{ title: 'A', description: 'B', target: t }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        let origin = host.t.mapToItem(g.overlayLayer, 0, 0)
        compare(g.spotlight.x, origin.x - 5)
        compare(g.spotlight.y, origin.y - 5, "位置器排完版之后洞要对上目标")
        compare(g.spotlight.height, 50)

        host.gap.height = 200
        wait(60)
        origin = host.t.mapToItem(g.overlayLayer, 0, 0)
        compare(g.spotlight.y, origin.y - 5, "目标被顶下去之后洞跟着走")
        const spot = testCase.partOf(g.overlayLayer, "userGuideSpot")
        compare(spot.y, g.spotlight.y)
        host.destroy()
    }

    // ---------------- 气泡卡片：宽度、内边距、footer ----------------

    function test_popoverCapsAtFourHundred() {
        const host = testCase.makeHost(undefined,
            "{ title: '新手引导', description: 'Lorem ipsum dolor sit amet, consectetur "
            + "adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna "
            + "aliqua ut enim ad minim veniam quis nostrud', target: t1 }")
        wait(200)
        const g = testCase.guideOf(host)
        compare(g.popupCard.width, 400, "内容超过 400 就夹到 400")
        host.destroy()
    }

    function test_popoverShrinksToFitContent() {
        const host = testCase.makeHost(undefined, "{ title: '短', description: 'Hi', target: t1 }")
        wait(200)
        const g = testCase.guideOf(host)
        const card = g.popupCard
        tmTitle.text = "短"
        tmDescription.text = "Hi"
        tmIndicator.text = g.indicatorText
        const skip = testCase.partOf(card, "userGuidePopupSkip")
        const next = testCase.partOf(card, "userGuidePopupNext")
        const expected = Math.min(400, Math.max(tmTitle.advanceWidth, tmDescription.advanceWidth,
            tmIndicator.advanceWidth + 120 + skip.implicitWidth + 12 + next.implicitWidth) + 48)
        compare(card.width, expected, "400 那层还套了 max-width: fit-content")
        verify(card.width < 400, "这一步的内容本来就用不到 400")
        host.destroy()
    }

    function test_popoverCoverForcesFullWidth() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " Component { id: cvr; Rectangle { color: '#e8f3ff' } }"
            + " Rectangle { id: t; x: 100; y: 60; width: 80; height: 40 }"
            + " UserGuide { visible: true; steps: [{ title: 'A', description: 'B',"
            + "   target: t, cover: cvr }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        compare(g.coverTaken, true)
        compare(g.popupCard.width, 400, "有 cover 时按 400 铺满")
        const cover = testCase.partOf(g.popupCard, "userGuidePopupCover")
        compare(cover.height, 200)
        compare(cover.width, 400)
        compare(cover.y, 0, "cover 顶到卡片上沿，body 的 24 内边距在它下面")
        const body = testCase.partOf(g.popupCard, "userGuidePopupBody")
        compare(body.y, 200)
        host.destroy()
    }

    function test_popupBodyPaddingAndTextMetrics() {
        const host = testCase.makeHost()
        wait(200)
        const card = testCase.guideOf(host).popupCard
        const body = testCase.partOf(card, "userGuidePopupBody")
        const title = testCase.partOf(card, "userGuidePopupTitle")
        const desc = testCase.partOf(card, "userGuidePopupDescription")
        const footer = testCase.partOf(card, "userGuidePopupFooter")

        compare(body.leftPadding, 24, "$spacing-userGuide_popup_content_body-padding")
        compare(body.rightPadding, 24)
        compare(body.topPadding, 24)
        compare(body.bottomPadding, 24)
        compare(title.y, 24)
        compare(title.height, 24, "$font-userGuide_popup_content_title-lineHeight")
        compare(title.font.pixelSize, Theme.current.fontSizeHeader5)
        compare(title.font.weight, Font.DemiBold, "$font-weight-bold = 600")
        compare(desc.y, title.y + title.height)
        compare(desc.topPadding, 8, "…title-marginBottom")
        compare(desc.height, 28, "行高 20 + 上边距 8")
        compare(desc.font.pixelSize, Theme.current.fontSizeRegular)
        compare(footer.topGap, 48, "…description-marginBottom")
        compare(footer.y, desc.y + desc.height)
        host.destroy()
    }

    function test_popupFooterGapFollowsWhichTextsExist() {
        const onlyTitle = testCase.guideOf(testCase.makeHost(undefined,
            "{ title: '只有标题', target: t1 }"))
        wait(200)
        compare(onlyTitle.descriptionTaken, false)
        compare(testCase.partOf(onlyTitle.popupCard, "userGuidePopupFooter").topGap, 8)
        onlyTitle.destroy()

        const noTexts = testCase.guideOf(testCase.makeHost(undefined, "{ target: t1 }"))
        wait(200)
        compare(noTexts.bodyTaken, false)
        // 官方的 -body 那层 div 是无条件渲染的，两颗键照样在
        compare(testCase.partOf(noTexts.popupCard, "userGuidePopupBody").visible, true)
        compare(testCase.partOf(noTexts.popupCard, "userGuidePopupFooter").topGap, 0)
        noTexts.destroy()
    }

    function test_popupIndicatorIsTextNotDots() {
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        const indicator = testCase.partOf(g.popupCard, "userGuidePopupIndicator")
        compare(g.indicatorTaken, true)
        compare(indicator.text, "1/2")
        compare(indicator.font.pixelSize, Theme.current.fontSizeRegular)
        compare(indicator.height, 20, "$font-userGuide_popup_content_indicator-lineHeight")
        compare(indicator.y, 48, "footer 的顶部留白之内")
        g.handleNext()
        wait(50)
        compare(indicator.text, "2/2")
        host.destroy()
    }

    function test_popupIndicatorHiddenForSingleStep() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " Rectangle { id: t; x: 100; y: 60; width: 80; height: 40 }"
            + " UserGuide { visible: true; steps: [{ title: 'A', description: 'B', target: t }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        compare(g.stepCount, 1)
        compare(g.indicatorTaken, false)
        const buttons = testCase.partOf(g.popupCard, "userGuidePopupButtons")
        const footer = testCase.partOf(g.popupCard, "userGuidePopupFooter")
        // 只有一段时 space-between 把按钮组贴左，再吃它自己的 margin-left
        compare(buttons.x, 120, "$spacing-userGuide_popup_content_button-marginLeft")
        compare(testCase.partOf(g.popupCard, "userGuidePopupPrev").visible, false)
        compare(testCase.partOf(g.popupCard, "userGuidePopupSkip").visible, false,
            "index.tsx:271 的 showSkipButton && !isLast")
        compare(buttons.x + buttons.implicitWidth > footer.width, false)
        host.destroy()
    }

    function test_popupButtonsKeepOneTwentyGapWhenContentIsWide() {
        // 中间一步：描述长到把卡片顶满 400，三颗键又宽到右对齐放不下 ⇒ 退成「指示器右边 120」
        const host = testCase.make("Item { id: root; property Item first: t1; property Item second: t2;"
            + " width: 700; height: 500;"
            + " Rectangle { id: t1; x: 100; y: 60; width: 80; height: 40 }"
            + " Rectangle { id: t2; x: 300; y: 300; width: 80; height: 40 }"
            + " UserGuide { visible: true; nextButtonText: '进入下一步骤';"
            + "   prevButtonText: '回到上一个步骤'; steps: ["
            + "   { title: '一', description: '短', target: t1 },"
            + "   { title: 'T', description: 'Lorem ipsum dolor sit amet consectetur adipiscing "
            + "elit sed do eiusmod tempor incididunt ut labore et dolore magna', target: t2 },"
            + "   { title: '三', description: '末步', target: t1 }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        g.handleNext()
        wait(50)
        const buttons = testCase.partOf(g.popupCard, "userGuidePopupButtons")
        const indicator = testCase.partOf(g.popupCard, "userGuidePopupIndicator")
        const footer = testCase.partOf(g.popupCard, "userGuidePopupFooter")
        compare(g.index, 1)
        compare(g.isLastStep, false)
        compare(g.popupCard.width, 400, "这一支的内容该把卡片顶满")
        compare(testCase.partOf(g.popupCard, "userGuidePopupSkip").visible, true)
        verify(footer.width - buttons.implicitWidth < indicator.width + 120,
            "先确认右对齐那一支真的放不下：按钮组 " + buttons.implicitWidth
            + "，可用宽 " + footer.width)
        compare(buttons.x, indicator.width + 120)
        host.destroy()
    }

    function test_popupButtonsGapIsTwelve() {
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        const skip = testCase.partOf(g.popupCard, "userGuidePopupSkip")
        const next = testCase.partOf(g.popupCard, "userGuidePopupNext")
        compare(next.x, skip.x + skip.width + 12)
        host.destroy()
    }

    // ---------------- 弹出位置与箭头 ----------------

    function test_positionBottomByDefault() {
        const host = testCase.makeHost(undefined, "{ title: 'A', description: 'B', target: t2 }")
        wait(200)
        const g = testCase.guideOf(host)
        const spot = testCase.partOf(g.overlayLayer, "userGuideSpot")
        const card = g.popupCard
        compare(g.stepPosition, Enums.Bottom)
        compare(card.y, spot.y + spot.height + 10, "洞下方 10（同 src/Popover.qml 的 gap）")
        compare(card.showArrow, true)
        verify(card.visible)
        host.destroy()
    }

    function test_positionTopRightLeft_data() {
        return [
            { position: Enums.Top, expect: "top" },
            { position: Enums.Right, expect: "right" },
            { position: Enums.Left, expect: "left" }
        ]
    }

    function test_positionTopRightLeft(data) {
        // 目标摆在窗口中间，四个方位都放得下，不该触发自动翻转
        const host = testCase.make("Item { width: 700; height: 500;"
            + " Rectangle { id: t; x: 300; y: 300; width: 80; height: 40 }"
            + " UserGuide { visible: true; position: " + data.position + ";"
            + "   steps: [{ title: 'A', description: 'B', target: t }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        const spot = testCase.partOf(g.overlayLayer, "userGuideSpot")
        const card = g.popupCard
        compare(g.stepPosition, data.position)
        compare(card.effectivePlacement, data.position, "这一格不该翻转")
        if (data.expect === "top")
            compare(card.y + card.height + 10, spot.y)
        else if (data.expect === "right")
            compare(card.x, spot.x + spot.width + 10)
        else
            compare(card.x + card.width + 10, spot.x)
        host.destroy()
    }

    function test_stepPositionOverridesGlobal() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " Rectangle { id: t; x: 300; y: 300; width: 80; height: 40 }"
            + " UserGuide { visible: true; position: Enums.Bottom; steps: ["
            + "   { title: 'A', description: 'B', target: t, position: Enums.Right }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        const spot = testCase.partOf(g.overlayLayer, "userGuideSpot")
        compare(g.position, Enums.Bottom)
        compare(g.stepPosition, Enums.Right, "index.tsx:336 的 step.position || position")
        compare(g.popupCard.x, spot.x + spot.width + 10)
        host.destroy()
    }

    function test_showArrowDefaultsTrueAndPerStepFalse() {
        const shown = testCase.guideOf(testCase.makeHost())
        wait(200)
        compare(shown.arrowShown, true, "index.tsx:339 的 step.showArrow !== false")
        compare(shown.popupCard.showArrow, true)
        shown.destroy()

        const hidden = testCase.guideOf(testCase.makeHost(undefined,
            "{ title: 'A', description: 'B', target: t1, showArrow: false }"))
        wait(200)
        compare(hidden.arrowShown, false)
        compare(hidden.popupCard.showArrow, false)
        hidden.destroy()
    }

    // ---------------- 主题 ----------------

    function test_defaultThemePaint() {
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        const card = g.popupCard
        const title = testCase.partOf(card, "userGuidePopupTitle")
        const skip = testCase.partOf(card, "userGuidePopupSkip")
        const next = testCase.partOf(card, "userGuidePopupNext")
        compare(g.primaryLook, false)
        compare(card.fillColor.toString(), Theme.current.colorBg3.toString())
        compare(card.strokeColor.toString(), Theme.current.colorBorder.toString())
        compare(card.radius, Theme.current.radiusMedium, "$radius-popover")
        compare(card.gap, 10, "与 src/Popover.qml 同一档间距")
        compare(card.arrowSize, 8, "$height-popover_arrow")
        compare(title.color.toString(), Theme.current.colorText0.toString(),
            "$color-userGuide_popup-text-default")
        // index.tsx:274-275 的 theme light / type tertiary，:293-295 的 solid / primary
        compare(skip.resolvedVariant, Enums.Light)
        compare(skip.resolvedTone, Enums.Tertiary)
        compare(next.resolvedVariant, Enums.Solid)
        compare(next.resolvedTone, Enums.Primary)
        host.destroy()
    }

    function test_primaryThemePaint() {
        const host = testCase.makeHost(" theme: 'primary',")
        wait(200)
        const g = testCase.guideOf(host)
        const card = g.popupCard
        const title = testCase.partOf(card, "userGuidePopupTitle")
        const desc = testCase.partOf(card, "userGuidePopupDescription")
        const skip = testCase.partOf(card, "userGuidePopupSkip")
        const prev = testCase.partOf(card, "userGuidePopupPrev")
        const next = testCase.partOf(card, "userGuidePopupNext")
        compare(g.primaryLook, true)
        compare(card.fillColor.toString(), Theme.current.colorPrimary.toString(),
            "index.tsx:327 给 Popover 盖的 backgroundColor")
        compare(card.strokeColor.toString(), Theme.current.colorBorder.toString(),
            "style 只改底色，描边照旧")
        compare(title.color.toString(), Theme.current.colorTertiaryLightDefault.toString(),
            "$color-userGuide_popup-text-primary")
        compare(desc.color.toString(), Theme.current.colorTertiaryLightDefault.toString())
        compare(skip.resolvedVariant, Enums.Solid)
        compare(skip.resolvedTone, Enums.Primary)
        compare(skip.color.toString(), Theme.current.colorFill2.toString(),
            "style backgroundColor: var(--semi-color-fill-2)")
        compare(prev.color.toString(), Theme.current.colorFill2.toString())
        compare(next.resolvedVariant, Enums.Borderless)
        compare(next.color.toString(), "#ffffff", "style backgroundColor: #FFF")
        host.destroy()
    }

    function test_primaryThemePaintInDark() {
        // 浅色下 bg-2 / bg-3 / white 三个令牌都是 #ffffff，分不出用的是哪一个；
        // 暗色才分得开 —— 官方那颗是字面量 '#FFF'，不是 theme 令牌。
        Theme.mode = Theme.Dark
        const host = testCase.makeHost(" theme: 'primary',")
        wait(200)
        const g = testCase.guideOf(host)
        verify(Theme.current.colorBg2.toString() !== "#ffffff",
            "暗色下 bg-2 已经不是白，这条断言才有区分度")
        const next = testCase.partOf(g.popupCard, "userGuidePopupNext")
        const skip = testCase.partOf(g.popupCard, "userGuidePopupSkip")
        compare(next.color.toString(), "#ffffff", "index.tsx:293 的 backgroundColor: '#FFF'")
        compare(skip.color.toString(), Theme.current.colorFill2.toString(),
            "skip 那颗才是令牌 var(--semi-color-fill-2)")
        Theme.mode = Theme.Light
        host.destroy()
    }

    function test_stepThemeOverridesGlobal() {
        const host = testCase.makeHost(undefined,
            "{ title: 'A', description: 'B', target: t1, theme: 'primary' }")
        wait(200)
        const g = testCase.guideOf(host)
        compare(g.theme, "default")
        compare(g.primaryLook, true, "index.tsx:250 的 theme==='primary' || step.theme==='primary'")
        compare(g.popupCard.fillColor.toString(), Theme.current.colorPrimary.toString())
        host.destroy()
    }

    // ---------------- modal 模式 ----------------

    function test_modalCardGeometry() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " Component { id: cvr; Rectangle { color: '#e8f3ff' } }"
            + " UserGuide { mode: 'modal'; visible: true; steps: ["
            + "   { title: '欢迎使用 Semi DSM!', description: '你可以从已发布的主题出发', cover: cvr },"
            + "   { title: '高可用的色盘', description: '选取主色后自动生成', cover: cvr }] } }")
        wait(250)
        const g = testCase.guideOf(host)
        const card = g.modalCard
        const cover = testCase.partOf(card, "userGuideModalCover")
        const indicator = testCase.partOf(card, "userGuideModalIndicator")
        const dots = testCase.partOf(card, "userGuideModalDots")
        const body = testCase.partOf(card, "userGuideModalBody")
        const footer = testCase.partOf(card, "userGuideModalFooter")
        const row = testCase.partOf(card, "userGuideModalButtons")

        compare(card.width, 600, "$width-userGuide_modal_content_cover-default")
        compare(card.z, g.zIndex + 1, "两支卡片都住在宿主之上，蒙层与遮罩都在下面")
        compare(card.radius, Theme.current.radiusLarge, "Modal 面板圆角")
        compare(card.fillColor.toString(), Theme.current.colorBg2.toString())
        compare(card.x, (g.overlayLayer.width - 600) / 2, "centered")
        compare(card.y, (g.overlayLayer.height - card.height) / 2)
        compare(cover.height, 300, "$height-userGuide_modal_content_cover-default")
        compare(cover.y, 0)
        compare(indicator.height, 30, "$height-userGuide_modal_content_indicator-default")
        compare(dots.spacing, 8, "$spacing-userGuide_popup_content_indicator-gap")
        compare(dots.x + dots.width / 2, card.width / 2, "整条居中")
        compare(body.leftPadding, 48, "$spacing-userGuide_modal_content_body-padding")
        compare(body.rightPadding, 48)
        compare(body.topPadding, 24)
        compare(body.bottomPadding, 24)
        compare(footer.height, 48 + row.implicitHeight, "footer 上下各 24")
        compare(row.x + row.width / 2, card.width / 2, "footer 也是居中排")
        compare(card.height, 300 + 30 + body.implicitHeight + footer.height)
        host.destroy()
    }

    function test_modalDots() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " Component { id: cvr; Rectangle { color: '#e8f3ff' } }"
            + " UserGuide { mode: 'modal'; visible: true; steps: ["
            + "   { title: 'A', cover: cvr }, { title: 'B', cover: cvr },"
            + "   { title: 'C', cover: cvr }] } }")
        wait(250)
        const g = testCase.guideOf(host)
        const dots = testCase.partOf(g.modalCard, "userGuideModalDots")
        const first = testCase.partOf(g.modalCard, "userGuideModalDot0")
        const second = testCase.partOf(g.modalCard, "userGuideModalDot1")
        const third = testCase.partOf(g.modalCard, "userGuideModalDot2")
        // children 里除了三枚代理还挂着 Repeater 自己，数圆点按几何数：3×6 + 2×8
        verify(third !== null)
        compare(dots.width, 3 * 6 + 2 * 8)
        compare(second.x, first.x + 6 + 8)
        compare(third.x, second.x + 6 + 8)
        compare(testCase.partOf(g.modalCard, "userGuideModalDot3"), null)
        compare(first.width, 6, "$width-userGuide_modal_content_indicator_item-default")
        compare(first.height, 6)
        compare(first.radius, Theme.current.radiusLarge, "6px 的盒子，圆角被自己夹成圆")
        compare(first.color.toString(), Theme.current.colorPrimary.toString(),
            "$color-userGuide_modal_content_indicator-bg-active")
        compare(second.color.toString(), Theme.current.colorPrimaryLightActive.toString(),
            "$color-userGuide_modal_content_indicator-bg")
        g.handleNext()
        wait(50)
        compare(first.color.toString(), Theme.current.colorPrimaryLightActive.toString())
        compare(second.color.toString(), Theme.current.colorPrimary.toString())
        host.destroy()
    }

    function test_modalDotsNeedCover() {
        // index.tsx:473-482：整排圆点与 cover 绑在一起，没 cover 就没圆点
        const host = testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { mode: 'modal'; visible: true; steps: ["
            + "   { title: 'A', description: '一' }, { title: 'B', description: '二' }] } }")
        wait(250)
        const g = testCase.guideOf(host)
        compare(g.coverTaken, false)
        compare(g.modalIndicatorTaken, false)
        compare(testCase.partOf(g.modalCard, "userGuideModalIndicator").visible, false)
        compare(testCase.partOf(g.modalCard, "userGuideModalCover").visible, false)
        compare(testCase.partOf(g.modalCard, "userGuideModalBody").visible, true,
            "没 cover 只是少了圆点排，正文照旧")
        host.destroy()
    }

    function test_modalIgnoresThemeAndNeedsNoTarget() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { mode: 'modal'; theme: 'primary'; visible: true; steps: ["
            + "   { title: 'A', description: '说明' }] } }")
        wait(250)
        const g = testCase.guideOf(host)
        compare(g.targetTaken, false, "modal 那一支根本不读 step.target")
        compare(g.modalCard.visible, true)
        compare(g.primaryLook, false, "renderModal 里没有 isPrimaryTheme")
        compare(g.modalCard.fillColor.toString(), Theme.current.colorBg2.toString())
        compare(testCase.partOf(g.modalCard, "userGuideModalTitle").color.toString(),
            Theme.current.colorText0.toString(), ".semi-modal { color: text-0 }")
        compare(testCase.partOf(g.modalCard, "userGuideModalDescription").color.toString(),
            Theme.current.colorText0.toString())
        compare(g.popupCard.visible, false, "mode 为 modal 时不渲染气泡那一支")
        host.destroy()
    }

    function test_modalBodyIsCenteredAndConditional() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { mode: 'modal'; visible: true; steps: [{ description: '只有一段说明' }] } }")
        wait(250)
        const g = testCase.guideOf(host)
        compare(g.titleTaken, false)
        compare(testCase.partOf(g.modalCard, "userGuideModalTitle").visible, false)
        const desc = testCase.partOf(g.modalCard, "userGuideModalDescription")
        compare(desc.topPadding, 0, "没有标题就没有那 8")
        compare(desc.y, 24, "body 的 topPadding")
        compare(desc.horizontalAlignment, Text.AlignHCenter, "align-items: center")
        host.destroy()

        // 标题那一份也得单独断：两支各有自己的 horizontalAlignment，只量描述的话
        // 标题那行写错照样绿
        const both = testCase.guideOf(testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { mode: 'modal'; visible: true;"
            + "   steps: [{ title: '标题', description: '说明' }] } }"))
        wait(250)
        const title = testCase.partOf(both.modalCard, "userGuideModalTitle")
        compare(title.horizontalAlignment, Text.AlignHCenter, "body 是 align-items: center")
        compare(title.width, 600 - 48 - 48, "正文宽 = 卡宽减两侧内边距，居中才有意义")
        compare(title.contentWidth < title.width, true, "文字窄于行 ⇒ 居中才看得出来")
        both.destroy()

        // (title || description) 都不给时，官方整块 -body 都不渲染
        const bare = testCase.guideOf(testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { mode: 'modal'; visible: true; steps: [{ title: '' }] } }"))
        wait(250)
        compare(bare.bodyTaken, false)
        compare(testCase.partOf(bare.modalCard, "userGuideModalBody").visible, false)
        bare.destroy()
    }

    function test_modalButtonTextsAndStyles() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { mode: 'modal'; visible: true; steps: ["
            + "   { title: 'A' }, { title: 'B' }] } }")
        wait(250)
        const g = testCase.guideOf(host)
        const skip = testCase.partOf(g.modalCard, "userGuideModalSkip")
        const prev = testCase.partOf(g.modalCard, "userGuideModalPrev")
        const next = testCase.partOf(g.modalCard, "userGuideModalNext")
        compare(skip.text, "跳过")
        compare(skip.resolvedTone, Enums.Tertiary, "index.tsx:494 只有 type，theme 走默认 light")
        compare(skip.resolvedVariant, Enums.Light)
        compare(next.text, "下一步")
        compare(next.resolvedVariant, Enums.Solid, "index.tsx:510 的 theme='solid'")
        compare(prev.visible, false, "第一步没有上一步键")
        g.handleNext()
        wait(50)
        compare(prev.visible, true)
        compare(next.text, "完成")
        host.destroy()
    }

    function test_modalStepChangeReplaysCloseThenOpen() {
        // 官方 modal 每步整个重播「关闭再打开」（浏览器实测：换步后内容直接回到 enter 起点
        // opacity 0 / scale 0.7 再放大，标题已是新步骤）。端口等价：current 变化把卡片按住
        // 一个 exit 时长（120ms）再放开。
        const host = testCase.make("Item { width: 700; height: 500;"
            + " Component { id: cvr; Rectangle { color: '#e8f3ff' } }"
            + " UserGuide { mode: 'modal'; visible: true; steps: ["
            + "   { title: '一', cover: cvr }, { title: '二', cover: cvr }] } }")
        wait(250)
        const g = testCase.guideOf(host)
        const card = g.modalCard
        compare(card.visible, true, "开层后卡片可见（开层不重播）")
        g.handleNext()
        // C.Popup 的 visible 在 exit 过渡期间不落假（属性要等收尾才翻）⇒ 钉过渡的 running
        verify(card.exit.running, "换步当场走 exit 过渡（等价官方的关闭那半）")
        compare(testCase.findChild(g, "userGuideModalReplayTimer").running, true,
            "重播计时在跑")
        tryVerify(function () { return card.enter.running; }, 300,
            "exit 之后重跑 enter（官方的重开那半）")
        tryVerify(function () { return !card.enter.running && !card.exit.running; }, 500,
            "进出场都收尾")
        compare(card.visible, true, "重播完卡片回到显示态")
        host.destroy()
    }

    // ---------------- 步进行为 ----------------

    function test_nextAdvancesAndNotifies() {
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        let changeCount = 0
        let nextCount = 0
        let lastChange = -1
        g.changed.connect(function (current) { changeCount++; lastChange = current })
        g.next.connect(function () { nextCount++ })
        g.handleNext()
        wait(50)
        compare(g.index, 1)
        compare(changeCount, 1)
        compare(lastChange, 1)
        compare(nextCount, 1)
        host.destroy()
    }

    function test_lastStepOnlyNotifiesFinishAndNeverCloses() {
        // foundation.ts:67-81：最后一步的下一步只 notifyFinish，不动 current 也不关自己
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        let finishedCount = 0
        let changeCount = 0
        g.finished.connect(function () { finishedCount++ })
        g.changed.connect(function () { changeCount++ })
        g.handleNext()
        wait(50)
        compare(g.isLastStep, true)
        g.handleNext()
        wait(50)
        compare(finishedCount, 1)
        compare(changeCount, 1, "最后一步不发 onChange")
        compare(g.index, 1, "current 不动")
        compare(g.visible, true, "官方没有「自己关自己」这条路")
        compare(g.popupCard.visible, true)
        host.destroy()
    }

    function test_skipButtonOnlyNotifies() {
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        let skipCount = 0
        g.skipped.connect(function () { skipCount++ })
        testCase.partOf(g.popupCard, "userGuidePopupSkip").clicked()
        wait(50)
        compare(skipCount, 1)
        compare(g.visible, true, "关由调用方在 onSkip 里做")
        compare(g.index, 0)
        host.destroy()
    }

    function test_prevAtFirstStepDoesNothing() {
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        let prevCount = 0
        let changeCount = 0
        g.prev.connect(function () { prevCount++ })
        g.changed.connect(function () { changeCount++ })
        g.handlePrev()
        compare(g.index, 0)
        compare(prevCount, 0)
        compare(changeCount, 0)
        g.handleNext()
        wait(50)
        g.handlePrev()
        wait(50)
        compare(g.index, 0)
        compare(prevCount, 1)
        compare(changeCount, 2, "上一步也发 onChange")
        host.destroy()
    }

    function test_controlledModeNeverSelfAdvances() {
        const host = testCase.make("Item { id: root; property int cur: 0;"
            + " width: 700; height: 500;"
            + " Rectangle { id: t1; x: 100; y: 60; width: 80; height: 40 }"
            + " Rectangle { id: t2; x: 300; y: 300; width: 80; height: 40 }"
            + " UserGuide { visible: true; current: root.cur; steps: ["
            + "   { title: 'A', description: '一', target: t1 },"
            + "   { title: 'B', description: '二', target: t2 }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        let changeCount = 0
        let nextCount = 0
        g.changed.connect(function (current) { changeCount++; host.cur = current })
        g.next.connect(function () { nextCount++ })
        compare(g.controlled, true)
        compare(g.index, 0)
        g.handleNext()
        wait(50)
        compare(changeCount, 1)
        compare(nextCount, 1)
        compare(g.index, 1, "受控：值是调用方写回来的，不是组件自己改的")
        g.handleNext()
        wait(50)
        compare(g.index, 1, "最后一步只发 finished，不自改")
        host.destroy()
    }

    function test_controlledLeavesInnerCursorUntouched() {
        // 受控那一支里 handleNext / handlePrev 一次都不写内部游标（foundation.ts:63-66 的
        // if (!getIsControlledComponent())）。游标被动过唯一的可见时刻是「后来不给了」：
        // 那时候 index 回落到游标，官方是 0，被自改过就是 1。
        const host = testCase.make("Item { id: root; property var cur: 0;"
            + " width: 700; height: 500;"
            + " Rectangle { id: t1; x: 100; y: 60; width: 80; height: 40 }"
            + " Rectangle { id: t2; x: 300; y: 300; width: 80; height: 40 }"
            + " UserGuide { visible: true; current: root.cur; steps: ["
            + "   { title: 'A', description: '一', target: t1 },"
            + "   { title: 'B', description: '二', target: t2 }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        g.handleNext()
        wait(50)
        compare(g.controlled, true)
        compare(g.index, 0, "调用方没写回 current，步数就不动")
        host.cur = undefined
        wait(50)
        compare(g.controlled, false)
        compare(g.index, 0, "受控期间内部游标一次都没被写过")
        host.destroy()
    }

    function test_controlledIndexTracksProp() {        const host = testCase.make("Item { id: root; property int cur: 0;"
            + " width: 700; height: 500;"
            + " Rectangle { id: t1; x: 100; y: 60; width: 80; height: 40 }"
            + " Rectangle { id: t2; x: 300; y: 300; width: 80; height: 40 }"
            + " UserGuide { visible: true; current: root.cur; steps: ["
            + "   { title: 'A', description: '一', target: t1 },"
            + "   { title: 'B', description: '二', target: t2 }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        let changeCount = 0
        g.changed.connect(function () { changeCount++ })
        host.cur = 1
        wait(50)
        compare(g.index, 1)
        compare(testCase.partOf(g.popupCard, "userGuidePopupTitle").text, "B")
        compare(changeCount, 0, "调用方自己改 current 不再回发 onChange")
        host.destroy()
    }

    function test_showResetsIndexToZero() {
        const host = testCase.make("Item { id: root; property bool open: false;"
            + " width: 700; height: 500;"
            + " Rectangle { id: t1; x: 100; y: 60; width: 80; height: 40 }"
            + " Rectangle { id: t2; x: 300; y: 300; width: 80; height: 40 }"
            + " UserGuide { visible: root.open; steps: ["
            + "   { title: 'A', description: '一', target: t1 },"
            + "   { title: 'B', description: '二', target: t2 }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        host.open = true
        wait(150)
        compare(g.index, 0)
        g.handleNext()
        wait(50)
        compare(g.index, 1)
        host.open = false
        wait(200)
        host.open = true
        wait(200)
        compare(g.index, 0, "index.tsx:180 的 setState({current: 0})")
        host.destroy()
    }

    function test_buttonFlagsHideTheRightOnes() {
        const noSkip = testCase.guideOf(testCase.makeHost(" showSkipButton: false,"))
        wait(200)
        compare(testCase.partOf(noSkip.popupCard, "userGuidePopupSkip").visible, false)
        compare(testCase.partOf(noSkip.popupCard, "userGuidePopupNext").visible, true)
        compare(testCase.partOf(noSkip.popupCard, "userGuidePopupPrev").visible, false,
            "第一步本来也没有上一步键")
        noSkip.destroy()

        const noPrev = testCase.guideOf(testCase.makeHost(" showPrevButton: false,"))
        wait(200)
        compare(testCase.partOf(noPrev.popupCard, "userGuidePopupSkip").visible, true)
        noPrev.handleNext()
        wait(50)
        compare(testCase.partOf(noPrev.popupCard, "userGuidePopupPrev").visible, false,
            "showPrevButton 假 ⇒ 中间步也不长出来")
        compare(testCase.partOf(noPrev.popupCard, "userGuidePopupSkip").visible, false,
            "这一步是最后一步，跳过键按 !isLast 隐藏")
        noPrev.destroy()
    }

    function test_buttonLabelsComeFromFlattenedProps() {
        const host = testCase.makeHost(" nextButtonText: 'Next', finishText: '我知道啦！',")
        wait(200)
        const g = testCase.guideOf(host)
        const next = testCase.partOf(g.popupCard, "userGuidePopupNext")
        const prev = testCase.partOf(g.popupCard, "userGuidePopupPrev")
        compare(next.text, "Next", "index.tsx:299 的非最后一步吃 nextButtonProps.children")
        compare(prev.visible, false)
        g.handleNext()
        wait(50)
        compare(next.text, "我知道啦！", "最后一步换成 finishText")
        host.destroy()
    }

    function test_prevButtonPropsFlatten() {
        const host = testCase.makeHost(" prevButtonText: 'Prev', prevButtonVariant: Enums.Borderless,")
        wait(200)
        const g = testCase.guideOf(host)
        g.handleNext()
        wait(50)
        const prev = testCase.partOf(g.popupCard, "userGuidePopupPrev")
        compare(prev.visible, true)
        compare(prev.text, "Prev")
        compare(prev.resolvedVariant, Enums.Borderless, "{...prevButtonProps} 摊在 theme 之后")
        compare(testCase.partOf(g.popupCard, "userGuidePopupSkip").resolvedVariant,
            Enums.Light, "跳过键不受 prev 的覆盖影响")
        host.destroy()
    }

    function test_skipButtonHiddenOnLastStep() {
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        compare(testCase.partOf(g.popupCard, "userGuidePopupSkip").visible, true)
        g.handleNext()
        wait(50)
        compare(testCase.partOf(g.popupCard, "userGuidePopupSkip").visible, false,
            "index.tsx:271 的 showSkipButton && !isLast")
        host.destroy()
    }

    function test_cardTitleAndDescriptionFollowStep() {
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        const title = testCase.partOf(g.popupCard, "userGuidePopupTitle")
        const desc = testCase.partOf(g.popupCard, "userGuidePopupDescription")
        compare(title.text, "第一步")
        compare(desc.text, "说明一")
        g.handleNext()
        wait(50)
        compare(title.text, "第二步")
        compare(desc.text, "说明二")
        host.destroy()
    }

    // ---------------- 遮罩与拦截 ----------------

    // pixel() 返回 "#rrggbb" 字符串，用 Qt.color 解析；grabImage 会把窗口底色合成进透明区
    // ⇒ 断言按 RGB 不按 alpha（白底夹具上：洞心=白、洞角与洞外=遮罩压白的灰）
    function test_maskCarvesRoundedHole() {
        // 官方洞是 svg `rect rx={4}`（圆角矩形，index.tsx:382）；端口用 OddEvenFill 环带等价。
        // 旧版是四块矩形围直角洞 —— 直角版的洞角像素是白，圆角版是遮罩灰，这一条就是分水岭。
        const host = testCase.make("Item { id: root; width: 700; height: 500\n"
            + " Rectangle { anchors.fill: parent; color: '#ffffff' }\n"
            + " Rectangle { id: t1; x: 100; y: 60; width: 80; height: 40; color: '#1234aa' }\n"
            + " UserGuide { visible: true; steps: [{ title: 'A', description: 'B', target: t1 }] } }")
        wait(350)
        const g = testCase.guideOf(host)
        const layer = g.overlayLayer
        verify(testCase.partOf(layer, "userGuideMask").visible, "遮罩整片可见")
        const spot = g.spotlight
        const dpr = Screen.devicePixelRatio
        const img = testCase.grabImage(layer)
        // 洞内、目标上方那条（不含目标本身）：透出白底
        const holeMid = Qt.color(img.pixel((spot.x + spot.width / 2) * dpr, (spot.y + 2) * dpr))
        verify(holeMid.r > 0.9 && holeMid.g > 0.9 && holeMid.b > 0.9,
            "洞内透出白底（洞开开了），实得 " + holeMid);
        // 洞角原点：rx=4 的圆角月牙把这枚像素罩进遮罩（实测 ~115）；直角版这里是白(255)
        const corner = Qt.color(img.pixel(spot.x * dpr, spot.y * dpr))
        verify(corner.r < 0.7, "洞角是遮罩灰（圆角切出来的月牙；直角版这里是白），实得 " + corner);
        // 洞外：同样的遮罩灰
        const outside = Qt.color(img.pixel((spot.x - 4) * dpr, (spot.y + spot.height / 2) * dpr))
        verify(outside.r < 0.8, "洞外是遮罩灰，实得 " + outside);
        host.destroy()
    }

    function test_clickGoesThroughInsideHole() {
        const host = testCase.make("Item { id: root; property Item btn: t; property int hits: 0;"
            + " width: 700; height: 500;"
            + " Button { id: t; x: 300; y: 200; width: 100; height: 32; text: '目标';"
            + "   onClicked: root.hits++ }"
            + " UserGuide { visible: true; steps: [{ title: 'A', description: 'B', target: t }] } }")
        wait(250)
        const g = testCase.guideOf(host)
        compare(testCase.partOf(g.overlayLayer, "userGuideBlockTop").enabled, true)
        testCase.clickIn(host.btn, 50, 16)
        compare(host.hits, 1, "洞里的目标照旧可点（官方那四块只围外面）")
        host.destroy()
    }

    function test_clickOutsideHoleIsSwallowed() {
        const host = testCase.makeHost()
        wait(250)
        testCase.guideOf(host)
        compare(host.hits, 0)
        testCase.clickIn(host.outsideBtn, 45, 16)
        compare(host.hits, 0, "洞外那点被透明 rect 吃掉")
        host.destroy()
    }

    function test_maskFalseRendersNoBlocking() {
        const host = testCase.makeHost(" mask: false,")
        wait(250)
        const g = testCase.guideOf(host)
        compare(g.mask, false)
        const layer = g.overlayLayer
        compare(testCase.partOf(layer, "userGuideMask").visible, false,
            "官方那五块 rect 全在 mask && (…) 里")
        compare(testCase.partOf(layer, "userGuideBlockTop").enabled, false)
        compare(testCase.partOf(layer, "userGuideBlockLeft").enabled, false)
        compare(testCase.partOf(layer, "userGuideBlockRight").enabled, false)
        compare(testCase.partOf(layer, "userGuideBlockBottom").enabled, false)
        compare(g.popupCard.visible, true, "卡片不受 mask 影响")
        testCase.clickIn(host.outsideBtn, 45, 16)
        compare(host.hits, 1, "没有遮罩 ⇒ 页面照旧能点")
        host.destroy()
    }

    function test_stepMaskIsNotWiredUpstream() {
        // StepItem.mask 文档写了但实现只读 props.mask；这里同样不接，也不开放那一段
        const host = testCase.makeHost(undefined,
            "{ title: 'A', description: 'B', target: t1, mask: false }")
        wait(200)
        const g = testCase.guideOf(host)
        compare(g.mask, true)
        compare(testCase.partOf(g.overlayLayer, "userGuideMask").visible, true)
        host.destroy()
    }

    function test_modalModeMaskAndBlocking() {
        const host = testCase.makeHost(" mode: 'modal',")
        wait(250)
        const g = testCase.guideOf(host)
        compare(g.popupCard.visible, false)
        compare(g.modalCard.visible, true)
        const mask = testCase.partOf(g.overlayLayer, "userGuideModalMask")
        compare(mask.visible, true)
        compare(mask.width, g.overlayLayer.width)
        compare(mask.height, g.overlayLayer.height)
        compare(mask.color.toString(), Theme.current.colorOverlayBg.toString())
        compare(g.modalCard.modal, true, ".semi-modal-wrap 整层拦点击，跟 mask 开不开无关")
        testCase.clickIn(host.outsideBtn, 45, 16)
        compare(host.hits, 0)
        host.destroy()
    }

    function test_modalMaskOffKeepsRectHidden() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { mode: 'modal'; mask: false; visible: true;"
            + "   steps: [{ title: 'A', description: 'B' }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        compare(testCase.partOf(g.overlayLayer, "userGuideModalMask").visible, false)
        compare(g.modalCard.visible, true, "mask 只改视觉，不关拦截")
        compare(g.modalCard.modal, true)
        host.destroy()
    }

    // ---------------- 层级与容器 ----------------

    function test_cardButtonsRespondToRealClicks() {
        // 换步那几条都是直接调 handleNext()，这里走窗口那条路：卡片必须真的压在
        // 四块拦截 rect 之上，否则 gallery 的 demo 就是「看得到点不动」。
        // 顺序有讲究 —— 跳过键在最后一步是藏起来的，所以先点它、再推进。
        const host = testCase.makeHost()
        wait(250)
        const g = testCase.guideOf(host)
        const next = testCase.partOf(g.popupCard, "userGuidePopupNext")
        const skip = testCase.partOf(g.popupCard, "userGuidePopupSkip")
        let skipCount = 0
        let finishCount = 0
        g.skipped.connect(function () { skipCount++ })
        g.finished.connect(function () { finishCount++ })
        compare(g.index, 0)
        testCase.clickIn(skip, skip.width / 2, skip.height / 2)
        wait(100)
        compare(skipCount, 1, "跳过键收得到点击")
        compare(g.index, 0, "跳过只发信号，不自改也不自关")
        compare(g.visible, true)
        testCase.clickIn(next, next.width / 2, next.height / 2)
        wait(250)
        compare(g.index, 1, "点卡片上的下一步真的推进了")
        testCase.clickIn(next, next.width / 2, next.height / 2)
        wait(100)
        compare(finishCount, 1, "最后一步那颗是完成")
        compare(g.index, 1)
        host.destroy()
    }

    function test_modalCardButtonRespondsToRealClick() {
        const host = testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { mode: 'modal'; visible: true; steps: ["
            + "   { title: 'A', description: '一' }, { title: 'B', description: '二' }] } }")
        wait(250)
        const g = testCase.guideOf(host)
        const next = testCase.partOf(g.modalCard, "userGuideModalNext")
        testCase.clickIn(next, next.width / 2, next.height / 2)
        wait(250)
        compare(g.index, 1)
        compare(testCase.partOf(g.modalCard, "userGuideModalTitle").text, "B")
        host.destroy()
    }

    function test_zOrderAndLayerSizing() {
        const host = testCase.makeHost(" zIndex: 1200,")
        wait(200)
        const g = testCase.guideOf(host)
        compare(g.zIndex, 1200)
        compare(g.overlayLayer.z, 1200)
        compare(g.popupCard.z, 1201, "卡片压在遮罩上")
        compare(g.overlayLayer.width, testCase.win.contentItem.width)
        compare(g.overlayLayer.height, testCase.win.contentItem.height)
        host.destroy()
    }

    function test_containerPropMovesTheLayer() {
        const host = testCase.make("Item { id: root; property Item box: box; property Item t: t;"
            + " width: 700; height: 500;"
            + " Item { id: box; x: 10; y: 20; width: 300; height: 200 }"
            + " Rectangle { id: t; x: 100; y: 60; width: 80; height: 40 }"
            + " UserGuide { visible: true; container: box;"
            + "   steps: [{ title: 'A', description: 'B', target: t }] } }")
        wait(200)
        const g = testCase.guideOf(host)
        compare(g.overlayLayer.parent, host.box, "官方 getPopupContainer")
        compare(g.overlayLayer.width, 300)
        compare(g.overlayLayer.height, 200)
        // 洞的坐标是**宿主层**那一系的，不是组件自己那一系的。box 相对 root 偏了 (10, 20)，
        // 所以目标在宿主层里落在 (90, 40)；拿 mapToItem(control) 算的话会少掉这段偏移。
        const origin = host.t.mapToItem(g.overlayLayer, 0, 0)
        compare(origin.x, 90, "宿主层不是组件自己的父项，偏移要一起算进来")
        compare(origin.y, 40)
        compare(g.spotlight.x, 90 - 5)
        compare(g.spotlight.y, 40 - 5)
        const spot = testCase.partOf(g.overlayLayer, "userGuideSpot")
        compare(spot.x, 90 - 5)
        compare(spot.y, 40 - 5)
        host.destroy()
    }

    function test_noAutoClose() {
        // 官方既不 Esc 也不点外关闭：closePolicy 得整个关掉
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        compare(g.popupCard.closePolicy, C.Popup.NoAutoClose)
        compare(g.modalCard.closePolicy, C.Popup.NoAutoClose)
        compare(g.popupCard.isOpen, true)
        g.handleNext()
        wait(50)
        compare(g.popupCard.isOpen, true)
        host.destroy()
    }

    function test_followsTheme() {
        const host = testCase.makeHost()
        wait(200)
        const g = testCase.guideOf(host)
        Theme.mode = Theme.Dark
        wait(150)
        // ShapePath 是 Shape 的路径数据，不在 children 里 ⇒ partOf 递归不到，走 findChild
        compare(testCase.findChild(g.overlayLayer, "userGuideMaskPath").fillColor.toString(),
            Theme.current.colorOverlayBg.toString(), "遮罩 fill=overlay-bg")
        compare(testCase.partOf(g.popupCard, "userGuidePopupTitle").color.toString(),
            Theme.current.colorText0.toString())
        compare(g.popupCard.fillColor.toString(), Theme.current.colorBg3.toString())
        Theme.mode = Theme.Light
        host.destroy()

        // 弹窗那支的底色是 bg-2，与气泡的 bg-3 在浅色下同值，只有暗色分得开
        Theme.mode = Theme.Dark
        const modal = testCase.guideOf(testCase.make("Item { width: 700; height: 500;"
            + " UserGuide { mode: 'modal'; visible: true; steps: [{ title: 'A' }] } }"))
        wait(250)
        verify(Theme.current.colorBg2.toString() !== Theme.current.colorBg3.toString(),
            "暗色下 bg-2 与 bg-3 才不是同一个值")
        compare(modal.modalCard.fillColor.toString(), Theme.current.colorBg2.toString(),
            "$color-modal-bg")
        compare(modal.popupCard.fillColor.toString(), Theme.current.colorBg3.toString(),
            "气泡走的是 popover 的 bg-3，两支不能混")
        Theme.mode = Theme.Light
        modal.destroy()
    }
}
