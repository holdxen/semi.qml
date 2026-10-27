import QtQuick
import QtQuick.Controls as C
import QtQuick.Window
import QtTest
import Semi

// Tooltip 的用例。规格逐条出处写在 src/Tooltip.qml 的文件头。
//
// 跑法（本仓约定，优先 offscreen）：
//   QT_QPA_PLATFORM=offscreen ./build/debug/tests/tst_semi -input tests/tst_tooltip.qml
TestCase {
    id: testCase

    name: "Tooltip"
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
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    // 公共宿主：一块 target + 一只 Tooltip。
    // tip 声明完就会被 own 的 parent 绑定搬到 Overlay 上，所以只能用 tipRef 拿它。
    // 缺省把 motion 关掉：进出场那 100ms 会让 visible / opacity 的读数抢跑，
    // 只有要看动画的那条用例才把 tipMotion 打开。
    function makeHost(tipAttrs, hostAttrs) {
        return make("Item { id: root; width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " property bool tipMotion: false;"
            + " property int escHits: 0; property int outsideHits: 0; property int hits: 0;"
            + " property int opens: 0;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40; color: '#eeeeee' }"
            + " Tooltip { id: tip; target: tgt;"
            + (tipAttrs === undefined ? "" : " " + tipAttrs + ";")
            + " motion: root.tipMotion;"
            + " onVisibleChanged: if (tip.visible) root.opens++;"
            + " onEscKeyDown: root.escHits++;"
            + " onClickedOutside: root.outsideHits++ }"
            + (hostAttrs === undefined ? "" : hostAttrs) + " }")
    }

    function tipOf(host) {
        return host.tipRef
    }

    // 浮层与 target 的公共坐标系就是浮层的 parent（Overlay 或 container）
    function originInLayer(tip, item) {
        return item.mapToItem(tip.parent, 0, 0)
    }

    // 卡片里那颗内凹三角（PopupBase 的 arrow 项，objectName 钉死在基座里）
    function arrowOf(tip) {
        const kids = tip.background.children
        for (let i = 0; i < kids.length; ++i)
            if (kids[i].objectName === "popupArrow")
                return kids[i]
        return null
    }

    function labelOf(tip) {
        return tip.background.children.filter(function (c) {
            return c.objectName === "tooltipLabel"
        })[0]
    }

    // 点外那只全窗壳：parent 直接就是浮层，所以只在浮层的一层子项里找
    function shellsOf(tip) {
        const layer = tip.parent
        if (!layer)
            return []
        return layer.children.filter(function (c) {
            return c.objectName === "tooltipOutsideShell"
        })
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

    function away() {
        mouseMove(testCase.win.contentItem, 880, 690)
    }

    // C.Popup 不是 Item，没有 mapToItem —— 卡片在浮层坐标系里就是 (tip.x, tip.y)，
    // 再借浮层（一个真 Item）搬到窗口
    function cardPointInWindow(tip, dx, dy) {
        return tip.parent.mapToItem(testCase.win.contentItem, tip.x + dx, tip.y + dy)
    }

    function clickInCard(tip, dx, dy) {
        const p = cardPointInWindow(tip, dx, dy)
        mouseClick(testCase.win.contentItem, p.x, p.y)
    }

    function hoverInCard(tip, dx, dy) {
        const p = cardPointInWindow(tip, dx, dy)
        mouseMove(testCase.win.contentItem, p.x, p.y)
    }

    // 只在 test_wrapDecisionAccountsForPadding 里挑样本用：与组件里那份 natural 同口径
    TextMetrics {
        id: wrapProbe

        font.pixelSize: Theme.current.fontSizeRegular
    }

    // ---------------- 默认值面（defaultProps 字面顺序，index.tsx:167-194） ----------------

    function test_defaultPropSurface() {
        const tip = make("Tooltip { }")
        compare(tip.target, null)
        compare(tip.text, "")
        compare(tip.trigger, "hover")
        compare(tip.position, Enums.Top)              // defaultProps position: 'top'
        compare(tip.mouseEnterDelay, 50)              // numbers.MOUSE_ENTER_DELAY
        compare(tip.mouseLeaveDelay, 50)              // numbers.MOUSE_LEAVE_DELAY
        compare(tip.condition, true)
        compare(tip.arrowPointAtCenter, true)
        compare(tip.spacing, 8)                       // numbers.SPACING（借 Popup 的同名属性）
        compare(tip.margin, 0)                        // numbers.MARGIN
        compare(tip.zIndex, 1060)                     // numbers.DEFAULT_Z_INDEX
        compare(tip.autoAdjustOverflow, true)
        compare(tip.clickToHide, false)
        compare(tip.clickTriggerToHide, false)
        compare(tip.disableFocusListener, false)
        compare(tip.closeOnEsc, false)                // 只在 defaultProps 里，propTypes 没列
        compare(tip.rePosKey, undefined)
        compare(tip.container, null)
        compare(tip.maxWidth, 240)                    // $width-tooltip
        compare(tip.motion, true)
        compare(tip.showArrow, true)
        tip.destroy()
    }

    function test_baseWiring() {
        const tip = make("Tooltip { }")
        compare(tip.gap, tip.spacing)
        compare(tip.placement, Enums.Top)
        compare(tip.autoFlip, true)
        compare(tip.fitMargin, 0)
        compare(tip.arrowSize, 7)                     // $height-tooltip_arrow
        compare(tip.arrowBase, 24)                    // $width-tooltip_arrow
        compare(tip.arrowOverlap, 1)                  // $spacing-tooltip_arrow_offset-y
        compare(tip.arrowStroked, false)              // TriangleArrow.tsx 只有一条 path
        compare(tip.padding, 0)                       // 12 / 8 不等，吃在 label 自己身上
        compare(tip.contentSpacing, 0)
        compare(tip.fillColor.toString(), Theme.current.grey[7].toString())
        compare(tip.strokeColor.toString(), Qt.rgba(0, 0, 0, 0).toString())
        compare(tip.shadowEnabled, false)             // tooltip.scss 里没有 shadow-elevated
        compare(tip.radius, Theme.current.radiusMedium)
        compare(tip.z, 1060)
        compare(tip.closePolicy, C.Popup.NoAutoClose) // 既不 Esc 自动关也不点外自动关
        compare(tip.pointAtCenter, true)
        compare(tip.arrowMinWidth, 36)                // 6*2 + 24
        compare(tip.arrowMinHeight, 34)               // 24 + 5*2
        compare(tip.arrowCross, 18)                   // adjusted_offset 6 + 半个箭头宽 12
        tip.destroy()
    }

    function test_modeFlags() {
        const hover = make("Tooltip { }")
        compare(hover.hoverMode, true)
        compare(hover.listensToFocus, true)           // hover 档也绑 focus/blur（a11y）
        compare(hover.watchesOutside, false)
        compare(hover.closesOnOutside, false)
        hover.destroy()

        const noFocus = make("Tooltip { disableFocusListener: true }")
        compare(noFocus.listensToFocus, false)
        noFocus.destroy()

        // 官方 focus 档那一段没写 disableFocusListener 判断（foundation.ts:212-217）
        const focus = make('Tooltip { trigger: "focus"; disableFocusListener: true }')
        compare(focus.focusMode, true)
        compare(focus.listensToFocus, true)
        focus.destroy()

        const click = make('Tooltip { trigger: "click" }')
        compare(click.watchesOutside, true)
        compare(click.closesOnOutside, true)
        click.destroy()

        const menu = make('Tooltip { trigger: "contextMenu" }')
        compare(menu.watchesOutside, true)
        compare(menu.closesOnOutside, true)
        menu.destroy()

        // custom：挂的是空回调 —— 发信号但不关
        const custom = make('Tooltip { trigger: "custom" }')
        compare(custom.watchesOutside, true)
        compare(custom.closesOnOutside, false)
        custom.destroy()

        const hoverLatch = make("Tooltip { clickTriggerToHide: true }")
        compare(hoverLatch.watchesOutside, true)
        compare(hoverLatch.closesOnOutside, true)
        hoverLatch.destroy()
    }

    // ---------------- 度量（variables.scss + arrow.scss） ----------------

    function test_textLabelMeasures() {
        const host = makeHost('text: "hi bytedance"', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const label = labelOf(tip)
        verify(label !== undefined, "background 里找不到 label")
        compare(label.font.pixelSize, Theme.current.fontSizeRegular)   // 14
        compare(label.lineHeight, 20)
        compare(label.lineHeightMode, Text.FixedHeight)
        compare(label.leftPadding, Theme.current.spacingBaseTight)     // 12
        compare(label.rightPadding, Theme.current.spacingBaseTight)
        compare(label.topPadding, Theme.current.spacingTight)          // 8
        compare(label.bottomPadding, Theme.current.spacingTight)
        compare(label.color.toString(), Theme.current.colorBg0.toString())
        compare(label.wrapMode, Text.NoWrap, "没超 240 就不开换行")
        tip.destroy()
        host.destroy()
    }

    function test_cardBoxEqualsLabelBox() {
        const host = makeHost('text: "hi bytedance"', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const label = labelOf(tip)
        // 单行：边框宽 = 文字自然宽 + 12*2（没到 240 上限），高 = 行高 20 + 8*2
        fuzzyCompare(tip.width, label.width, 0.5)
        fuzzyCompare(tip.width, label.implicitWidth, 0.5)
        fuzzyCompare(tip.height, 36, 0.5)
        compare(label.lineCount, 1)
        tip.destroy()
        host.destroy()
    }

    function test_minBoxWhenContentIsEmpty() {
        // 空 text、无子项：官方那两条 min-width / min-height 才第一次生效
        const arrow = make("Tooltip { motion: false }")
        arrow.open()
        wait(60)
        fuzzyCompare(arrow.width, 36, 0.5)
        fuzzyCompare(arrow.height, 34, 0.5)
        arrow.destroy()

        // 短到 36 以下的文案：带三角被兜到 36，不带三角就照自己那点开
        const withArrow = makeHost('text: "i"', "")
        withArrow.tipRef.open()
        wait(60)
        const label = labelOf(withArrow.tipRef)
        verify(label.width < 36, "先要真的比最小宽窄，实测 " + label.width)
        fuzzyCompare(withArrow.tipRef.width, 36, 0.5)
        withArrow.tipRef.destroy()
        withArrow.destroy()

        const noArrow = makeHost('text: "i"; showArrow: false', "")
        noArrow.tipRef.open()
        wait(60)
        const nLabel = labelOf(noArrow.tipRef)
        fuzzyCompare(noArrow.tipRef.width, nLabel.width, 0.5)
        verify(noArrow.tipRef.width < 36, "没有三角就不兜最小宽")
        noArrow.tipRef.destroy()
        noArrow.destroy()
    }

    function test_longTextClampsToMaxWidthAndWraps() {
        const long = "Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统"
        + "帮助设计师与开发者更容易地打造高质量的组件";
        const host = makeHost('text: "' + long + '"', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const label = labelOf(tip)
        compare(label.wrapMode, Text.WrapAtWordBoundaryOrAnywhere, "超宽才开换行")
        fuzzyCompare(tip.width, 240, 0.5)
        verify(label.lineCount >= 2, "夹到 240 之后必须换行，实际 " + label.lineCount)
        fuzzyCompare(tip.height, label.implicitHeight, 0.5)
        tip.destroy()
        host.destroy()
    }

    function test_maxWidthOverrideWidensTheCard() {
        const long = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            + "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        const dflt = makeHost('text: "' + long + '"', "")
        dflt.tipRef.open()
        wait(60)
        fuzzyCompare(dflt.tipRef.width, 240, 0.5)
        const wide = makeHost('text: "' + long + '"; maxWidth: 320', "")
        wide.tipRef.open()
        wait(60)
        fuzzyCompare(wide.tipRef.width, 320, 0.5)
        // 换行数随之变少，高度也跟着走
        verify(wide.tipRef.height < dflt.tipRef.height, "放宽之后应该更矮")
        dflt.tipRef.destroy()
        dflt.destroy()
        wide.tipRef.destroy()
        wide.destroy()
    }

    // 换行判据是 natural + 左右内边距 24 > maxWidth（官方 max-width 240 是 border-box）。
    // 少算那 24 就会把「只有算上内边距才超宽」的文案判成不超宽：NoWrap + 卡片按 natural 收，
    // 文字被自己的内边距挤出去一截，且卡片宽不等于 240。
    function test_wrapDecisionAccountsForPadding() {
        const word = "测量"
        let s = ""
        for (let i = 1; i <= 60; ++i) {
            s = s + word
            wrapProbe.text = s
            if (wrapProbe.width > 240 - Theme.current.spacingBaseTight * 2 + 4
                    && wrapProbe.width <= 240 - 4)
                break
        }
        verify(wrapProbe.width > 220 && wrapProbe.width <= 236,
            "样本要落在「只有算上内边距才超宽」那一段，实际 " + wrapProbe.width)
        const host = makeHost('text: "' + s + '"', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const label = labelOf(tip)
        compare(label.wrapMode, Text.WrapAtWordBoundaryOrAnywhere, "算上 12+12 已经超宽，必须开换行")
        fuzzyCompare(tip.width, 240, 0.5)
        verify(label.lineCount >= 2, "而且真折了，否则字被内边距挤出去")
        tip.destroy()
        host.destroy()
    }

    function test_childrenSizeTheCardWithoutGhostPadding() {
        // 富内容档：label 不参与（text 为空），Column 里只有使用方的两个 Text。
        // 若 label 还占位，卡片会宽 24、高多 16。
        const host = make("Item { width: 600; height: 400;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 250; y: 180; width: 120; height: 40 }"
            + " Tooltip { id: tip; target: tgt; motion: false;"
            + " Text { objectName: 'p1'; text: 'hi bytedance'; font.pixelSize: 14 }"
            + " Text { objectName: 'p2'; text: 'hi bytedance hi bytedance'; font.pixelSize: 14 } } }")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const p2 = tip.contentItem.children.filter(function (c) {
            return c.objectName === "p2"
        })[0]
        fuzzyCompare(tip.width, p2.implicitWidth, 0.5)
        const p1 = tip.contentItem.children.filter(function (c) {
            return c.objectName === "p1"
        })[0]
        fuzzyCompare(tip.height, p1.implicitHeight + p2.implicitHeight, 0.5)
        tip.destroy()
        host.destroy()
    }

    // 官方那条 max-width 落在**卡片**身上（tooltip.scss 的 $width-tooltip，border-box），
    // 所以 children 比它宽时卡片收、内容自己溢出。文字档的 label 早就自己夹过一遍，
    // 只有 children 档才能证伪「implicitWidth 外面那层 Math.min 没了」。
    function test_wideChildrenAreClampedByMaxWidth() {
        const dflt = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40 }"
            + " Tooltip { id: tip; target: tgt; motion: false;"
            + " Rectangle { objectName: 'wide'; width: 400; height: 60; color: '#abcdef' } } }")
        const tip = tipOf(dflt)
        tip.open()
        wait(60)
        fuzzyCompare(tip.width, 240, 0.5, "卡片夹到 maxWidth")
        const wide = tip.contentItem.children.filter(function (c) {
            return c.objectName === "wide"
        })[0]
        fuzzyCompare(wide.width, 400, 0.5, "内容自己还是 400，溢在卡片外面（官方就是卡片收、内容不出让）")
        verify(wide.width > tip.width, "内容比卡片宽")
        tip.destroy()
        dflt.destroy()

        const widen = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40 }"
            + " Tooltip { id: tip; target: tgt; motion: false; maxWidth: 600;"
            + " Rectangle { objectName: 'wide'; width: 400; height: 60; color: '#abcdef' } } }")
        const tip2 = tipOf(widen)
        tip2.open()
        wait(60)
        fuzzyCompare(tip2.width, 400, 0.5, "放宽之后卡片跟着内容走")
        tip2.destroy()
        widen.destroy()
    }

    // ---------------- 定位：gap、方位、翻面 ----------------

    function test_gapAndCenteringPerSide() {
        const cases = [
            [Enums.Top, "top"], [Enums.Bottom, "bottom"],
            [Enums.Left, "left"], [Enums.Right, "right"]
        ]
        for (let i = 0; i < cases.length; ++i) {
            const p = cases[i][0]
            const host = makeHost("position: " + p + '; text: "hi"', "")
            const tip = tipOf(host)
            tip.open()
            wait(60)
            const o = originInLayer(tip, host.tgtRef)
            const t = host.tgtRef
            if (p === Enums.Top) {
                compare(tip.y + tip.height + 8, o.y, "top: 卡片底边离 target 顶边 8")
                fuzzyCompare(tip.x + tip.width / 2, o.x + t.width / 2, 1, "top: 水平居中")
            } else if (p === Enums.Bottom) {
                compare(tip.y, o.y + t.height + 8, "bottom: 卡片顶边离 target 底边 8")
                fuzzyCompare(tip.x + tip.width / 2, o.x + t.width / 2, 1, "bottom: 水平居中")
            } else if (p === Enums.Left) {
                compare(tip.x + tip.width + 8, o.x, "left: 卡片右边离 target 左边 8")
                fuzzyCompare(tip.y + tip.height / 2, o.y + t.height / 2, 1, "left: 垂直居中")
            } else {
                compare(tip.x, o.x + t.width + 8, "right: 卡片左边离 target 右边 8")
                fuzzyCompare(tip.y + tip.height / 2, o.y + t.height / 2, 1, "right: 垂直居中")
            }
            compare(tip.effectivePlacement, p, cases[i][1] + " 不该翻面")
            tip.destroy()
            host.destroy()
        }
    }

    function test_spacingPropDrivesTheGap() {
        const host = makeHost('text: "hi"; spacing: 20', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const o = originInLayer(tip, host.tgtRef)
        compare(tip.y + tip.height + 20, o.y)
        tip.destroy()
        host.destroy()
    }

    // ---------------- 小三角 ----------------

    function test_arrowShapeAndProtrusion() {
        const host = makeHost('text: "hi bytedance"', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const arrow = arrowOf(tip)
        verify(arrow !== null, "background 里找不到那颗三角")
        compare(arrow.visible, true)
        // 官方那颗是 24×7 的**内凹** SVG 三角（TriangleArrow.tsx），底边压进卡片边 1px
        // （$spacing-tooltip_arrow_offset-y「渲染会有缝隙，所以加个偏移量」）⇒ 探出 6。
        compare(arrow.width, 24, "$width-tooltip_arrow")
        compare(arrow.height, 7, "$height-tooltip_arrow")
        fuzzyCompare(arrow.y, tip.height - 1, 0.01, "Top：底边压在卡片底边里 1px")
        fuzzyCompare(arrow.y + arrow.height, tip.height + 6, 0.01, "探出 = 7 − 1")
        compare(arrow.x + arrow.width / 2, tip.arrowCenterX, "三角中心落在 arrowCenterX")
        // 形状本体：两条边是三次曲线，不是直边三角（直边是本轮之前的样子）
        verify(tip.arrowFillPath.indexOf("C20 1 18.5 2 16.5 4") >= 0,
            "横档要用 TriangleArrow.tsx 那条内凹 path")
        compare(arrow.transform[0].xScale, 1, "Top 不翻")
        compare(arrow.transform[1].yScale, 1, "Top 不翻")
        tip.close()
        tip.position = Enums.Left
        tip.open()
        wait(60)
        const side = arrowOf(tip)
        compare(side.width, 7, "$width-tooltip_arrow_vertical")
        compare(side.height, 24, "$height-tooltip_arrow_vertical")
        fuzzyCompare(side.x, tip.width - 1, 0.01, "Left：底边压在卡片右边线里 1px")
        fuzzyCompare(side.y + side.height / 2, tip.height / 2, 0.5, "纵向居中")
        tip.close()
        tip.position = Enums.Bottom
        tip.open()
        wait(60)
        compare(arrowOf(tip).transform[1].yScale, -1, "Bottom：靠 y 翻，尖朝上")
        tip.close()
        tip.position = Enums.Right
        tip.open()
        wait(60)
        compare(arrowOf(tip).transform[0].xScale, -1, "Right：靠 x 翻，尖朝左")
        tip.destroy()
        host.destroy()
    }

    function test_arrowCenterFollowsTargetForMiddlePositions() {
        const host = makeHost('text: "hi bytedance"; position: Enums.Bottom', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const o = originInLayer(tip, host.tgtRef)
        const center = o.x + host.tgtRef.width / 2
        fuzzyCompare(tip.arrowCenterX, center - tip.x, 1, "中间方位：三角指着 target 中心")
        compare(tip.arrowCenterY, NaN)
        tip.destroy()
        host.destroy()
    }

    // 角落方位的三角中心恒为「离边 18」（arrow.scss 的 adjusted_offset + 半个箭头宽）。
    // 内容刻意取 140×80：卡片高 80 时 height − 18 = 62 ≠ 18，「leftBottom 抄成 leftTop」
    // 这种改动才分得开；三角那颗项也一起断，纵向「不读 arrowCenterY」的改动才有地方红。
    function test_cornerArrowIs18FromEdge() {
        const pairs = [
            [Enums.TopLeft, "x", 18], [Enums.TopRight, "x", -1],
            [Enums.BottomLeft, "x", 18], [Enums.BottomRight, "x", -1],
            [Enums.LeftTop, "y", 18], [Enums.LeftBottom, "y", -1],
            [Enums.RightTop, "y", 18], [Enums.RightBottom, "y", -1]
        ]
        for (let i = 0; i < pairs.length; ++i) {
            const p = pairs[i][0]
            const host = make("Item { width: 800; height: 600;"
                + " property var tipRef: tip; property Item tgtRef: tgt;"
                + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40 }"
                + " Tooltip { id: tip; target: tgt; motion: false; position: " + p + ";"
                + " Rectangle { width: 140; height: 80; color: '#abcdef' } } }")
            const tip = tipOf(host)
            tip.open()
            wait(60)
            const along = pairs[i][1]
            const edge = pairs[i][2]
            const arrow = arrowOf(tip)
            verify(arrow !== null, "方位 " + p + " 找不到三角")
            const want = edge === 18 ? 18 : (along === "x" ? tip.width : tip.height) - 18
            if (along === "x") {
                fuzzyCompare(tip.arrowCenterX, want, 0.5, "方位 " + p + " 的 arrowCenterX")
                compare(tip.arrowCenterY, NaN, "横向方位不该给纵向中心")
                fuzzyCompare(arrow.x + arrow.width / 2, want, 0.5, "方位 " + p + " 的三角真的摆在那")
                // 卡片在 target 上方 ⇒ 三角的底边压在卡片的**下**边里 1px；下方则压在上边
                fuzzyCompare(arrow.y,
                    p === Enums.TopLeft || p === Enums.TopRight ? tip.height - 1
                        : -(arrow.height - 1),
                    0.5, "三角的底边压在朝向 target 的那条边上")
            } else {
                fuzzyCompare(tip.arrowCenterY, want, 0.5, "方位 " + p + " 的 arrowCenterY")
                compare(tip.arrowCenterX, NaN, "纵向方位不该给横向中心")
                fuzzyCompare(arrow.y + arrow.height / 2, want, 0.5, "方位 " + p + " 的三角真的摆在那")
                fuzzyCompare(arrow.x,
                    p === Enums.LeftTop || p === Enums.LeftBottom ? tip.width - 1
                        : -(arrow.width - 1),
                    0.5, "三角的底边压在朝向 target 的那条边上")
            }
            tip.destroy()
            host.destroy()
        }
    }

    // 角落方位 + arrowPointAtCenter：卡片沿交叉轴平移，让那颗离边 18 的三角指到中心。
    // 八个方位逐个测（共享件里那 8 条 case 各写各的，只测一档会漏）。
    function test_pointAtCenterShiftsCardForCorners() {
        const vertical = [Enums.TopLeft, Enums.TopRight, Enums.BottomLeft, Enums.BottomRight]
        const horizontal = [Enums.LeftTop, Enums.LeftBottom, Enums.RightTop, Enums.RightBottom]
        for (let i = 0; i < 8; ++i) {
            const pos = i < 4 ? vertical[i] : horizontal[i - 4]
            const host = make("Item { width: 800; height: 600;"
                + " property var tipRef: tip; property Item tgtRef: tgt;"
                + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40 }"
                + " Tooltip { id: tip; target: tgt; motion: false; position: " + pos + ";"
                + " Rectangle { width: 140; height: 80; color: '#abcdef' } } }")
            const tip = tipOf(host)
            tip.open()
            wait(60)
            const o = originInLayer(tip, host.tgtRef)
            const middleX = o.x + host.tgtRef.width / 2
            const middleY = o.y + host.tgtRef.height / 2
            fuzzyCompare(vertical.indexOf(pos) >= 0 ? tip.x + tip.arrowCenterX
                : tip.y + tip.arrowCenterY,
                vertical.indexOf(pos) >= 0 ? middleX : middleY, 1,
                pos + "：卡片沿交叉轴平移过，三角指着 target 中心")
            tip.destroy()
            host.destroy()
        }
    }

    // 首次 place() 之前三角中心就得备好：卡片宽高在完成时已经定下来，而 place() 是
    // open() 那一拍读的，晚一步（只靠 onXChanged 补算）卡片就按「没有中心值」那档摆好了。
    function test_arrowCenterIsReadyBeforeTheFirstShow() {
        const host = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40 }"
            + " Tooltip { id: tip; target: tgt; motion: false; position: Enums.TopLeft;"
            + " Rectangle { width: 140; height: 80; color: '#abcdef' } } }")
        const tip = tipOf(host)
        fuzzyCompare(tip.width, 140, 0.5)
        fuzzyCompare(tip.arrowCenterX, 18, 0.5, "开层之前中心值就该在")
        tip.open()
        wait(60)
        const o = originInLayer(tip, host.tgtRef)
        fuzzyCompare(tip.x, o.x + host.tgtRef.width / 2 - 18, 1,
            "首次定位用的就是这一份中心值")
        tip.destroy()
        host.destroy()
    }

    // 中间方位那份中心值要读 control.x 与 arrowPointAtCenter，而创建期那阵几何信号来得比
    // 这两个绑定定稿还早（那一拍算出来是 NaN），之后再没有信号 —— 所以 Component.onCompleted
    // 那次重算是开层前唯一的时机。角落方位看不出来：它那值是常量，width 信号顺手就补上了。
    function test_middleArrowCenterIsSeededAtCompletion() {
        const host = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40 }"
            + " Tooltip { id: tip; target: tgt; motion: false; position: Enums.Top;"
            + " arrowPointAtCenter: true; text: \"hi\" } }")
        const tip = tipOf(host)
        compare(tip.isOpen, false)
        verify(!isNaN(tip.arrowCenterX), "声明完、还没开层就该有中心值")
        fuzzyCompare(tip.arrowCenterX, tip.arrowCross, 0.5, "36 宽的卡片只能夹到离边 18")
        tip.destroy()
        host.destroy()
    }

    function test_pointAtCenterOffWhenArrowHidden() {
        // 官方那档 `!showArrow ? showArrow : arrowPointAtCenter`：
        // 没有三角，角落方位就不该再为它平移卡片
        const host = makeHost(
            'text: "hi bytedance"; position: Enums.TopLeft; showArrow: false', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        compare(tip.pointsAtCenter, false)
        compare(tip.pointAtCenter, false)
        const o = originInLayer(tip, host.tgtRef)
        fuzzyCompare(tip.x, o.x, 1, "卡片回到边缘对齐")
        compare(tip.arrowCenterX, NaN)
        compare(arrowOf(tip).visible, false)
        tip.destroy()
        host.destroy()
    }

    // arrowPointAtCenter 关掉之后：卡片改成边缘对齐，三角仍离边 18，于是就不指中心了
    // （官方「指向元素中心」那一节的对照档）。
    function test_arrowPointAtCenterOffAlignsCardToEdge() {
        const host = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40 }"
            + " Tooltip { id: tip; target: tgt; motion: false; position: Enums.TopLeft;"
            + " arrowPointAtCenter: false;"
            + " Rectangle { width: 140; height: 80; color: '#abcdef' } } }")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const o = originInLayer(tip, host.tgtRef)
        fuzzyCompare(tip.x, o.x, 1, "false：卡片与 target 左边缘对齐")
        fuzzyCompare(tip.arrowCenterX, 18, 0.5, "false：三角仍离边 18")
        verify(tip.x + tip.arrowCenterX < o.x + host.tgtRef.width / 2,
            "此时三角不再指着中心")
        tip.destroy()
        host.destroy()
    }

    // 中间方位（Top/Bottom/Left/Right）的三角要跟 target 中心，并被夹回卡片里
    // （foundation.ts 的 getArrowLocation：Math.max(offset, Math.min(width - offset, …))）。
    // 卡片没被夹时 target 中心恒等于几何中心，所以必须造「卡片被交叉轴夹回层内」的输入，
    // 「换成几何中心」这种改动才分得开。
    function test_middleArrowIsClampedInsideTheCard() {
        // 左端：target 贴着容器左边，卡片按公式要跑到 x=-108，被夹回 0
        const left = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: box; x: 40; y: 40; width: 300; height: 200;"
            + " color: '#223344' }"
            + " Rectangle { id: tgt; parent: box; x: 0; y: 90; width: 24; height: 20 }"
            + " Tooltip { id: tip; target: tgt; container: box; motion: false;"
            + " position: Enums.Bottom;"
            + " text: 'Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统帮助' } }")
        const tip = tipOf(left)
        tip.open()
        wait(60)
        compare(tip.x, 0, "卡片被夹回容器左边界")
        const o = left.tgtRef.mapToItem(tip.parent, 0, 0)
        verify(o.x + 12 - tip.x < tip.arrowCross, "夹过之后 target 中心比 18 还靠左，才有下界可测")
        fuzzyCompare(tip.arrowCenterX, 18, 0.5, "下界夹到 18，三角不跑出卡片")
        verify(Math.abs(tip.arrowCenterX - tip.width / 2) > 40,
            "这个值不能等于几何中心，否则测不出「写死居中」")
        fuzzyCompare(arrowOf(tip).x + arrowOf(tip).width / 2, 18, 0.5, "三角项也摆在那")
        tip.destroy()
        left.destroy()

        // 右端：同一套反过来，夹到上界 width - 18
        const right = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: box; x: 40; y: 40; width: 300; height: 200;"
            + " color: '#223344' }"
            + " Rectangle { id: tgt; parent: box; x: 276; y: 90; width: 24; height: 20 }"
            + " Tooltip { id: tip; target: tgt; container: box; motion: false;"
            + " position: Enums.Bottom;"
            + " text: 'Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统帮助' } }")
        const tip2 = tipOf(right)
        tip2.open()
        wait(60)
        fuzzyCompare(tip2.x, 300 - tip2.width, 1, "卡片被夹回容器右边界")
        fuzzyCompare(tip2.arrowCenterX, tip2.width - 18, 0.5, "上界夹到 width - 18")
        tip2.destroy()
        right.destroy()

        // 同一档关掉 arrowPointAtCenter：中间方位也不再跟中心，改成卡片几何居中（NaN = 基座居中）
        const off = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: box; x: 40; y: 40; width: 300; height: 200;"
            + " color: '#223344' }"
            + " Rectangle { id: tgt; parent: box; x: 0; y: 90; width: 24; height: 20 }"
            + " Tooltip { id: tip; target: tgt; container: box; motion: false;"
            + " position: Enums.Bottom; arrowPointAtCenter: false;"
            + " text: 'Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的设计系统帮助' } }")
        const tip3 = tipOf(off)
        tip3.open()
        wait(60)
        compare(tip3.pointsAtCenter, false)
        compare(tip3.arrowCenterX, NaN, "关掉之后不再生成中心值")
        fuzzyCompare(arrowOf(tip3).x + arrowOf(tip3).width / 2,
            tip3.width / 2, 1, "三角回到卡片几何中心")
        tip3.destroy()
        off.destroy()

        // 纵向那两档同理：卡片 200 高、容器 260 高，target 贴顶 / 贴底各造一次
        const low = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: box; x: 40; y: 40; width: 300; height: 260;"
            + " color: '#223344' }"
            + " Rectangle { id: tgt; parent: box; x: 20; y: 0; width: 24; height: 20 }"
            + " Tooltip { id: tip; target: tgt; container: box; motion: false;"
            + " position: Enums.Right;"
            + " Rectangle { width: 140; height: 200; color: '#abcdef' } } }")
        const tip4 = tipOf(low)
        tip4.open()
        wait(60)
        compare(tip4.effectivePlacement, Enums.Right)
        compare(tip4.y, 0, "卡片被夹回容器上边界")
        fuzzyCompare(tip4.arrowCenterY, 18, 0.5, "纵向也夹到 18")
        verify(Math.abs(tip4.arrowCenterY - tip4.height / 2) > 40,
            "这个值不能等于几何中心 " + tip4.height / 2)
        tip4.destroy()
        low.destroy()

        const high = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: box; x: 40; y: 40; width: 300; height: 260;"
            + " color: '#223344' }"
            + " Rectangle { id: tgt; parent: box; x: 20; y: 240; width: 24; height: 20 }"
            + " Tooltip { id: tip; target: tgt; container: box; motion: false;"
            + " position: Enums.Right;"
            + " Rectangle { width: 140; height: 200; color: '#abcdef' } } }")
        const tip5 = tipOf(high)
        tip5.open()
        wait(60)
        compare(tip5.effectivePlacement, Enums.Right)
        fuzzyCompare(tip5.y, 260 - tip5.height, 1, "卡片被夹回容器下边界")
        fuzzyCompare(tip5.arrowCenterY, tip5.height - 18, 0.5, "纵向夹到 height - 18")
        fuzzyCompare(arrowOf(tip5).y + arrowOf(tip5).height / 2,
            tip5.height - 18, 0.5, "三角项也摆在那")
        tip5.destroy()
        high.destroy()
    }

    // 卡片的盒子被**外部**改掉（没有走 place()）时，三角中心必须跟着重算。
    // 分别只改 x、只改宽：两条信号各钉一条断言，别指望另一条兜。
    function test_arrowCenterFollowsCardMoveAndResize() {
        const moved = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40 }"
            + " Tooltip { id: tip; target: tgt; motion: false; position: Enums.Bottom;"
            + ' text: "hi bytedance" } }')
        const tip = tipOf(moved)
        tip.open()
        wait(60)
        const before = tip.arrowCenterX
        const o = originInLayer(tip, moved.tgtRef)
        tip.x = tip.x - 20
        wait(20)
        fuzzyCompare(tip.arrowCenterX, before + 20, 1, "卡片左移 20，中心值要右移 20")
        fuzzyCompare(tip.arrowCenterX, o.x + moved.tgtRef.width / 2 - tip.x, 1,
            "仍然指着 target 中心")
        tip.destroy()
        moved.destroy()

        const grown = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40 }"
            + " Tooltip { id: tip; target: tgt; motion: false; position: Enums.TopRight;"
            + ' text: "hi bytedance" } }')
        const tip2 = tipOf(grown)
        tip2.open()
        wait(60)
        tip2.width = tip2.width + 60
        wait(20)
        fuzzyCompare(tip2.arrowCenterX, tip2.width - 18, 1, "卡片变宽之后右端那档要跟着新宽度")
        tip2.destroy()
        grown.destroy()
    }

    // ---------------- 触发：hover ----------------

    function test_hoverShowsAfterEnterDelay() {
        const host = makeHost('text: "hi bytedance"', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 50, 20)
        compare(tip.visible, false, "50ms 之内不该已经弹出来")
        tryVerify(function () {
            return tip.visible === true
        }, 600, "悬停 " + tip.mouseEnterDelay + "ms 后要弹")
        away()
        tryVerify(function () {
            return tip.visible === false
        }, 600, "移开后要收")
        tip.destroy()
        host.destroy()
    }

    function test_hoverDelaysArePropDriven() {
        const host = makeHost('text: "hi"; mouseEnterDelay: 400; mouseLeaveDelay: 0', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 10, 10)
        wait(150)
        compare(tip.visible, false, "400ms 的进入延迟不该在 150ms 就弹")
        tryVerify(function () {
            return tip.visible === true
        }, 1200)
        compare(tip.mouseLeaveDelay, 0)
        away()
        wait(60)
        compare(tip.visible, false, "离开延迟 0：立刻收")
        tip.destroy()
        host.destroy()
    }

    function test_leavingDuringTheEnterDelayCancelsTheShow() {
        // 官方 delayShow / delayHide 共用一只 _timer：待显示期间移开，那次显示被取消。
        // 「最后没开着」不够 —— 待开的那次照样会弹一下再被关掉，终态一样。要数**开过几次**。
        const host = makeHost('text: "hi"', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 10, 10)
        wait(10)
        away()
        wait(400)
        compare(tip.visible, false)
        compare(host.opens, 0, "那一次待显示必须整个作废，一次都没开过")
        // 反向对照：真停够时间，还是能弹出来的（否则上面那条是空断言）
        hoverOver(host.tgtRef, 10, 10)
        tryVerify(function () {
            return tip.visible === true
        }, 600)
        verify(host.opens >= 1, "停够 mouseEnterDelay 仍然会开")
        away()
        tip.destroy()
        host.destroy()
    }

    // mouseLeaveDelay 0 走的是 hideNow() 那条捷径，它自己也要清掉待开的那次
    function test_leavingWithZeroHideDelayCancelsThePendingShow() {
        const host = makeHost('text: "hi"; mouseLeaveDelay: 0', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 10, 10)
        wait(10)
        away()
        wait(400)
        compare(tip.visible, false)
        compare(host.opens, 0, "mouseLeaveDelay 0 时是 hideNow 负责取消那次待开")
        hoverOver(host.tgtRef, 10, 10)
        tryVerify(function () {
            return tip.visible === true
        }, 600)
        away()
        tip.destroy()
        host.destroy()
    }

    // 官方：mouseEnterDelay > 0 才 setTimeout，否则直接 show()。走定时器的话这一拍
    // 读到的还是 false，差一帧用户就能看见「悬停了没反应」。
    function test_zeroEnterDelayShowsSynchronously() {
        const host = makeHost('text: "hi"; mouseEnterDelay: 0', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 10, 10)
        compare(tip.visible, true, "延迟 0：同一拍就该已经开起来")
        away()
        tip.destroy()
        host.destroy()
    }

    function test_zeroLeaveDelayHidesSynchronously() {
        const host = makeHost('text: "hi"; mouseEnterDelay: 0; mouseLeaveDelay: 0', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 10, 10)
        compare(tip.visible, true)
        away()
        compare(tip.visible, false, "离开延迟 0：同一拍就该关掉")
        tip.destroy()
        host.destroy()
    }

    // 待关的那一拍里焦点又回来：官方 delayShow 第一件事是 clearDelayTimer。
    // 用 focus 档测 —— 卡片没被悬停，pointerOnTipArea 恒假，那条现查悬停的兜底
    // 顶不了包，才能真把「不取消待关」打红。
    function test_refocusCancelsThePendingHide() {
        const host = makeHost('text: "hi"; trigger: "focus"; mouseEnterDelay: 0;'
            + ' mouseLeaveDelay: 300', "")
        const tip = tipOf(host)
        host.tgtRef.forceActiveFocus()
        tryVerify(function () {
            return tip.visible === true
        }, 600)
        host.tgtRef.focus = false
        wait(60)
        compare(tip.visible, true, "300ms 的离开延迟还没到")
        host.tgtRef.forceActiveFocus()
        wait(400)
        compare(tip.visible, true, "重新拿到焦点要取消那次待关")
        compare(host.opens, 1, "取消待关不等于重放一次 open")
        host.tgtRef.focus = false
        tryVerify(function () {
            return tip.visible === false
        }, 600)
        tip.destroy()
        host.destroy()
    }

    // 关到一半再悬停：官方 show() 看到 animating / visible 就直接 return，
    // 不重放进场。Qt 自己的 setVisible(true) 在退场动画里是**允许**重开的
    // （qquickpopup.cpp:2538 那段注释），所以这道闸门只能由组件自己守。
    function test_hoverDuringTheExitTransitionDoesNotReopen() {
        const host = makeHost('text: "hi"; mouseEnterDelay: 0; mouseLeaveDelay: 0', "")
        host.tipMotion = true
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 10, 10)
        compare(tip.visible, true)
        away()
        wait(40)
        const opensBefore = host.opens
        hoverOver(host.tgtRef, 10, 10)
        compare(host.opens, opensBefore, "退场动画这一拍不重开")
        away()
        wait(300)
        compare(tip.visible, false, "退场走完就是走完")
        // 对照：动画走完之后再悬停要能开
        hoverOver(host.tgtRef, 10, 10)
        tryVerify(function () {
            return tip.visible === true
        }, 600)
        away()
        tip.destroy()
        host.destroy()
    }

    // hover 档附带的那对 focus/blur：指针还在 target 上、只是焦点被别人拿走，
    // 官方语义是「还在悬停就别关」（portalEventSet 那份拷贝的另一半）。
    function test_blurWhileStillHoveringKeepsItOpen() {
        const host = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " property Item otherRef: other;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40;"
            + " color: '#eeeeee' }"
            + " Rectangle { id: other; x: 600; y: 400; width: 60; height: 40 }"
            + " Tooltip { id: tip; target: tgt; motion: false;"
            + " mouseEnterDelay: 0; mouseLeaveDelay: 200 } }")
        const tip = tipOf(host)
        away()
        wait(60)
        host.tgtRef.forceActiveFocus()
        hoverOver(host.tgtRef, 50, 20)
        tryVerify(function () {
            return tip.visible === true
        }, 600)
        host.otherRef.forceActiveFocus()
        wait(60)
        compare(tip.visible, true, "blur 只发起一次待关")
        wait(400)
        compare(tip.visible, true, "200ms 到点时指针仍在 target 上，不关")
        away()
        tryVerify(function () {
            return tip.visible === false
        }, 600, "挪开之后要真的会关（否则上面那条是空断言）")
        tip.destroy()
        host.destroy()
    }

    function test_movingIntoTheCardKeepsItOpen() {
        // portalEventSet 是 triggerEventSet 的拷贝：鼠标挪进卡片等于「还在悬停」
        const host = makeHost('text: "hi bytedance"; mouseLeaveDelay: 40', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 50, 20)
        tryVerify(function () {
            return tip.visible === true
        }, 600)
        hoverInCard(tip, 3, 3)
        wait(300)
        compare(tip.visible, true, "挪进卡片不该收掉")
        tip.destroy()
        host.destroy()
    }

    // ---------------- 触发：condition ----------------

    function test_conditionFalseBlocksEveryShowPathButCustom() {
        const modes = ["hover", "focus", "click", "contextMenu"]
        for (let i = 0; i < modes.length; ++i) {
            const host = makeHost('text: "hi"; trigger: "' + modes[i] + '"; condition: false', "")
            const tip = tipOf(host)
            away()
            wait(60)
            if (modes[i] === "hover") {
                hoverOver(host.tgtRef, 50, 20)
            } else if (modes[i] === "focus") {
                host.tgtRef.focus = true
                host.tgtRef.forceActiveFocus()
            } else if (modes[i] === "click") {
                clickOn(host.tgtRef, 50, 20)
            } else {
                clickOn(host.tgtRef, 50, 20, Qt.RightButton)
            }
            wait(300)
            compare(tip.visible, false, modes[i] + "：condition=false 不该弹")
            tip.condition = true
            away()
            host.tgtRef.focus = false
            wait(80)
            if (modes[i] === "hover")
                hoverOver(host.tgtRef, 50, 20)
            else if (modes[i] === "click")
                clickOn(host.tgtRef, 50, 20)
            else if (modes[i] === "contextMenu")
                clickOn(host.tgtRef, 50, 20, Qt.RightButton)
            else
                host.tgtRef.forceActiveFocus()
            tryVerify(function () {
                return tip.visible === true
            }, 900, modes[i] + "：放开 condition 之后要能弹")
            tip.destroy()
            host.destroy()
        }
    }

    function test_customIsFullyControlledAndIgnoresCondition() {
        // 官方 custom 档什么都不绑：hover / click 都不生效，显隐只看 visible；
        // 于是 condition 对它整个无效（文档：trigger='custom' 场景不受影响）
        const host = makeHost(
            'text: "hi"; trigger: "custom"; condition: false; visible: false', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 50, 20)
        wait(200)
        compare(tip.visible, false, "custom 档悬停不该弹")
        clickOn(host.tgtRef, 50, 20)
        wait(200)
        compare(tip.visible, false, "custom 档点击也不该弹")
        host.tgtRef.forceActiveFocus()
        wait(200)
        compare(tip.visible, false, "custom 档聚焦也不该弹")
        tip.visible = true
        wait(60)
        compare(tip.visible, true, "condition=false 也挡不住 custom 的 visible")
        fuzzyCompare(tip.height, 36, 0.5)
        tip.visible = false
        wait(60)
        compare(tip.visible, false)
        tip.destroy()
        host.destroy()
    }

    // ---------------- 触发：focus ----------------

    function test_hoverModeAlsoRespondsToFocus() {
        const host = makeHost('text: "hi"', "")
        const tip = tipOf(host)
        away()
        wait(60)
        host.tgtRef.focus = true
        host.tgtRef.forceActiveFocus()
        tryVerify(function () {
            return tip.visible === true
        }, 900, "hover 档也绑了 focus（a11y）")
        tip.destroy()
        host.destroy()
    }

    function test_focusModeShowsAndHides() {
        const host = makeHost(
            'text: "hi"; trigger: "focus"; mouseEnterDelay: 0; mouseLeaveDelay: 0', "")
        const tip = tipOf(host)
        away()
        wait(60)
        host.tgtRef.focus = true
        host.tgtRef.forceActiveFocus()
        wait(60)
        compare(tip.visible, true, "focus 档聚焦即弹")
        host.tgtRef.focus = false
        tryVerify(function () {
            return tip.visible === false
        }, 900, "失焦要收")
        tip.destroy()
        host.destroy()
    }

    function test_disableFocusListenerOnlyKillsTheHoverPair() {
        const host = makeHost(
            'text: "hi"; disableFocusListener: true; mouseEnterDelay: 0', "")
        const tip = tipOf(host)
        away()
        wait(60)
        host.tgtRef.focus = true
        host.tgtRef.forceActiveFocus()
        wait(200)
        compare(tip.visible, false, "hover 档的那对 focus/blur 被关掉了")
        hoverOver(host.tgtRef, 50, 20)
        wait(60)
        compare(tip.visible, true, "但 mouseEnter 还在")
        tip.destroy()
        host.destroy()
    }

    // ---------------- 触发：click / contextMenu / 点外 ----------------

    function test_clickShowsAndSecondClickDoesNotToggle() {
        // 官方 click 档只绑 show()（已开着再点还是开），关是点外 handler 的活
        const host = makeHost('text: "hi"; trigger: "click"', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 50, 20)
        wait(200)
        compare(tip.visible, false, "click 档不吃悬停：档位只由 handler 的 enabled 决定")
        clickOn(host.tgtRef, 50, 20)
        compare(tip.visible, true, "click 档走的是 show()，不吃 mouseEnterDelay")
        wait(80)
        compare(host.outsideHits, 0)
        clickOn(host.tgtRef, 50, 20)
        wait(80)
        compare(tip.visible, true, "再点一次还是开：官方不是开关")
        tip.destroy()
        host.destroy()
    }

    function test_contextMenuShowsOnRightClickOnly() {
        const host = makeHost('text: "hi"; trigger: "contextMenu"', "")
        const tip = tipOf(host)
        away()
        wait(60)
        // 左键这一档不算触发（官方 contextMenu 档只绑 onContextMenu）
        clickOn(host.tgtRef, 50, 20, Qt.LeftButton)
        wait(120)
        compare(tip.visible, false, "左键不该弹")
        clickOn(host.tgtRef, 50, 20, Qt.RightButton)
        compare(tip.visible, true, "右键档走的也是 show()，不经过 mouseEnterDelay")
        wait(120)
        // 关它是点外 handler 的活：落在 target 上的那一下不算外面
        clickOn(host.tgtRef, 50, 20, Qt.LeftButton)
        wait(120)
        compare(tip.visible, true, "点 trigger 不关")
        clickOn(host, 700, 560)
        wait(120)
        compare(tip.visible, false, "点外面才关")
        compare(host.outsideHits, 1)
        tip.destroy()
        host.destroy()
    }

    function test_clickOutsideClosesAndFiresOnce() {
        const host = makeHost('text: "hi"; trigger: "click"', "")
        const tip = tipOf(host)
        away()
        wait(60)
        clickOn(host.tgtRef, 50, 20)
        wait(80)
        compare(tip.visible, true)
        clickOn(host.tgtRef, 50, 20)          // 落在 trigger 上：官方也不算「外面」
        wait(60)
        compare(host.outsideHits, 0, "点 trigger 不发 clickedOutside")
        clickInCard(tip, 5, 5)                // 卡片内部也不算
        wait(60)
        compare(host.outsideHits, 0, "点卡片不发 clickedOutside")
        compare(tip.visible, true)
        clickOn(host, 700, 560)               // 真·外面
        wait(80)
        compare(host.outsideHits, 1)
        compare(tip.visible, false)
        tip.destroy()
        host.destroy()
    }

    // 观测壳是「铺满浮层宿主的一整块 Item」，常驻场景就等于给窗口多塞一层全窗命中项，
    // 所以 parent 那一条要同时看档位与层开没开。档位那一半有 test_hoverModeIgnoresClicksOutside，
    // 这里钉另一半：只在开层的那一段里存在，关完跟着离开。
    function test_outsideShellExistsOnlyWhileOpen() {
        const host = makeHost('text: "hi"; trigger: "click"', "")
        const tip = tipOf(host)
        away()
        wait(60)
        compare(shellsOf(tip).length, 0, "层没开，全窗壳不该挂在浮层上")
        clickOn(host.tgtRef, 50, 20)
        wait(80)
        compare(tip.visible, true)
        const shells = shellsOf(tip)
        compare(shells.length, 1)
        fuzzyCompare(shells[0].width, tip.parent.width, 0.5)
        fuzzyCompare(shells[0].height, tip.parent.height, 0.5)
        clickOn(host, 700, 560)
        wait(80)
        compare(tip.visible, false)
        compare(shellsOf(tip).length, 0, "关完之后壳要跟着离开场景")
        tip.destroy()
        host.destroy()
    }

    function test_outsidePressClosesAndStillReachesThePage() {
        // 官方那层 handler 绑在 document 的 mousedown 上，组件与页面两边都收得到。
        // 这里的观测壳用 PointHandler（passive），所以底下**页面自己的 MouseArea**
        // 也照样吃到这一口 —— 换成铺在浮层上的 MouseArea，实测整窗点击都被截住，
        // 页面项一个事件都收不到（本轮就是这么把 tst_taginput / tst_treeselect 打红的）。
        const host = makeHost('text: "hi"; trigger: "click"',
            " Rectangle { objectName: 'pagePlate'; x: 600; y: 520; width: 90; height: 32;"
            + " color: '#eeeeee';"
            + " MouseArea { anchors.fill: parent; onPressed: root.hits++ } }")
        const tip = tipOf(host)
        away()
        wait(60)
        clickOn(host.tgtRef, 50, 20)
        wait(80)
        compare(tip.visible, true)
        const plate = host.children.filter(function (c) {
            return c.objectName === "pagePlate"
        })[0]
        clickOn(plate, 45, 16)
        wait(80)
        compare(host.outsideHits, 1, "落在页面控件上的这一下判定为「外面」")
        compare(tip.visible, false, "并且收掉了层")
        compare(host.hits, 1, "这一下同时落进了页面的 MouseArea")
        tip.destroy()
        host.destroy()
    }

    // 官方只在 click / contextMenu / custom（空函数）与 clickTriggerToHide 这几档往
    // document 上挂 mousedown handler，hover 档压根没有点外这一说 —— 观测层也就不该在场。
    function test_hoverModeIgnoresClicksOutside() {
        const host = makeHost('text: "hi"; mouseEnterDelay: 0', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 50, 20)
        compare(tip.visible, true)
        compare(tip.watchesOutside, false)
        compare(tip.closesOnOutside, false)
        clickOn(host, 700, 560)
        wait(80)
        compare(host.outsideHits, 0, "hover 档点外不发 clickedOutside")
        compare(tip.visible, true, "也不因为点外收起（还是靠移开鼠标关）")
        away()
        tryVerify(function () {
            return tip.visible === false
        }, 600)
        tip.destroy()
        host.destroy()
    }

    function test_customClickOutsideFiresButKeepsOpen() {
        // :366-368 custom 注册的是空函数 —— 信号照发、层不关
        const host = makeHost('text: "hi"; trigger: "custom"; visible: true', "")
        const tip = tipOf(host)
        away()
        wait(60)
        clickOn(host, 700, 560)
        wait(80)
        compare(host.outsideHits, 1)
        compare(tip.visible, true, "custom 档点外不关")
        tip.destroy()
        host.destroy()
    }

    function test_clickTriggerToHideTreatsTriggerAsOutside() {
        // clickTriggerToHide 把 trigger 也划进「外面」（index.tsx:462 那个分支）
        const plain = makeHost('text: "hi"; mouseEnterDelay: 0', "")
        plain.tipRef.open()
        wait(60)
        clickOn(plain.tgtRef, 50, 20)
        wait(60)
        compare(plain.outsideHits, 0)
        compare(plain.tipRef.visible, true)
        plain.tipRef.destroy()
        plain.destroy()

        const latched = makeHost(
            'text: "hi"; mouseEnterDelay: 0; clickTriggerToHide: true', "")
        latched.tipRef.open()
        wait(60)
        clickOn(latched.tgtRef, 50, 20)
        wait(60)
        compare(latched.outsideHits, 1, "trigger 上这次点要算「外面」")
        latched.tipRef.destroy()
        latched.destroy()
    }

    function test_clickToHideClosesOnCardAndStaysClosed() {
        // :251-262：点卡片 -> 置 isClickToHide + hide；此后卡片里的 mouseEnter 不再弹，
        // 直到 mouseEnter 落回 target 才清掉这个标记
        const host = makeHost('text: "hi bytedance"; clickToHide: true; mouseEnterDelay: 0', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 50, 20)
        wait(60)
        compare(tip.visible, true)
        compare(tip.clickToHideLatched, false, "没点过卡片之前闸门是开的")
        clickInCard(tip, 4, 4)
        wait(60)
        compare(tip.visible, false, "点卡片要收")
        compare(tip.clickToHideLatched, true, "点卡片要置闸门")
        // 收之后鼠标还留在卡片里：要先挪开再挪回来，才真有一次 mouseEnter
        away()
        wait(60)
        hoverInCard(tip, 4, 4)
        wait(200)
        compare(tip.visible, false, "isClickToHide 闸门：卡片内的悬停不再弹")
        away()
        wait(60)
        hoverOver(host.tgtRef, 50, 20)
        wait(120)
        compare(tip.visible, true, "回到 target 上，标记被清掉，照常再弹")
        compare(tip.clickToHideLatched, false, "target 的 mouseEnter 第一件事就是清标记")
        tip.destroy()
        host.destroy()
    }

    // ---------------- Esc ----------------

    function test_escDoesNothingByDefault() {
        const host = makeHost('text: "hi"', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        keyClick(Qt.Key_Escape)
        wait(120)
        compare(tip.visible, true, "closeOnEsc 缺省 false：Esc 不关")
        compare(host.escHits, 0, "也不发 onEscKeyDown")
        tip.destroy()
        host.destroy()
    }

    function test_closeOnEscClosesAndSignals() {
        const host = makeHost('text: "hi"; closeOnEsc: true', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        keyClick(Qt.Key_Escape)
        wait(120)
        compare(tip.visible, false, "closeOnEsc 打开后 Esc 要关")
        compare(host.escHits, 1)
        tip.destroy()
        host.destroy()
    }

    // hideNow() 自己也要清掉那只待开定时器。官方 delayShow / delayHide 共用一只 _timer，
    // 每次 clearDelayTimer 都顺带取消另一头的待办。这里走的是不经过 delayHide 的那条捷径
    // （Esc 直接调 hideNow）：悬停排了一次 200ms 后显示，中途把层开起来再用 Esc 关掉，
    // 那 200ms 到点时不能把层顶回来。
    function test_hideNowCancelsAPendingShow() {
        const host = makeHost('text: "hi"; closeOnEsc: true; mouseEnterDelay: 200', "")
        const tip = tipOf(host)
        away()
        wait(60)
        hoverOver(host.tgtRef, 10, 10)
        wait(10)
        compare(tip.visible, false, "还在那 200ms 里")
        tip.open()
        wait(60)
        compare(tip.visible, true)
        compare(host.opens, 1)
        keyClick(Qt.Key_Escape)
        wait(300)
        compare(tip.visible, false, "关掉之后那次待开不能把层顶回来")
        compare(host.opens, 1, "关完之后不得重开")
        away()
        tip.destroy()
        host.destroy()
    }

    function test_escInCustomModeOnlySignals() {
        // :1321-1323 `trigger !== 'custom'` 才 hide
        const host = makeHost('text: "hi"; trigger: "custom"; visible: true; closeOnEsc: true', "")
        const tip = tipOf(host)
        wait(60)
        compare(tip.visible, true)
        keyClick(Qt.Key_Escape)
        wait(120)
        compare(host.escHits, 1)
        compare(tip.visible, true, "custom 档只发信号，显隐仍由 visible 说了算")
        tip.destroy()
        host.destroy()
    }

    // ---------------- 动效、rePosKey、container、层级 ----------------

    function test_motionFalseSkipsTheTransition() {
        const still = makeHost('text: "hi"', "")
        still.tipRef.open()
        wait(20)
        fuzzyCompare(still.tipRef.opacity, 1, 0.001, "motion=false：直接就是终态")
        still.tipRef.destroy()
        still.destroy()

        const moved = makeHost('text: "hi"', "")
        moved.tipMotion = true
        moved.tipRef.open()
        wait(20)
        verify(moved.tipRef.opacity < 1, "100ms 的进场动画，20ms 时还没走完")
        tryVerify(function () {
            return moved.tipRef.opacity === 1
        }, 900)
        moved.tipRef.destroy()
        moved.destroy()
    }

    function test_followsTargetResize() {
        // 基座轮询的是 target 的**整个矩形**，尺寸那一型（top/left 不动、宽高变了，
        // Select 多选标签换行撑高触发器就是这个形状）也看得见 ⇒ 不用碰 rePosKey 就要跟着挪。
        const host = makeHost('text: "hi"; position: Enums.Top; mouseEnterDelay: 0', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const before = tip.x
        host.tgtRef.width = 220
        wait(80)
        verify(tip.x !== before, "target 变宽后弹层要跟着挪，实际 x 仍是 " + before)
        const o = originInLayer(tip, host.tgtRef)
        fuzzyCompare(tip.x + tip.width / 2, o.x + host.tgtRef.width / 2, 1,
                     "卡片中心没对齐变宽后的 target")
        tip.destroy()
        host.destroy()
    }

    function test_rePosKeyForcesRecompute() {
        // rePosKey 是官方的手动重算口，基座能自己看见尺寸变化之后它仍然要有用：
        // 这条不动 target 的几何（帧轮询因此不会插手），只把卡片摆歪，
        // key 一变就得自己回到该在的位置 —— 摘掉 onRePosKeyChanged 立刻红。
        const host = makeHost('text: "hi"; position: Enums.Top; mouseEnterDelay: 0', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        const atRest = tip.x
        tip.x = atRest + 40
        wait(60)
        compare(tip.x, atRest + 40, "没动 target 也没动 key 时，帧轮询不该把卡片摆回去")
        tip.rePosKey = "v2"
        wait(60)
        verify(tip.x !== atRest + 40, "rePosKey 一变就要重算位置")
        const o = originInLayer(tip, host.tgtRef)
        fuzzyCompare(tip.x + tip.width / 2, o.x + host.tgtRef.width / 2, 1)
        tip.destroy()
        host.destroy()
    }

    function test_containerMovesTheLayerHost() {
        const host = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " property Item boxRef: box;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 100; height: 40; color: '#eee' }"
            + " Rectangle { id: box; x: 40; y: 40; width: 200; height: 200; color: '#4488ff' }"
            + " Tooltip { id: tip; target: tgt; text: 'hi'; motion: false; container: box } }")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        compare(tip.parent, host.boxRef, "container 换的就是浮层的 parent")
        const o = host.tgtRef.mapToItem(host.boxRef, 0, 0)
        compare(tip.y + tip.height + 8, o.y, "位置改按容器坐标系算")
        tip.destroy()
        host.destroy()
    }

    function test_flipIntoBottomAndNoFlipWhenDisabled() {
        const host = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 650; width: 100; height: 32; color: '#eee' }"
            + " Tooltip { id: tip; target: tgt; text: 'hi bytedance'; motion: false;"
            + " position: Enums.Bottom } }")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        compare(tip.effectivePlacement, Enums.Top, "下面放不下就翻到上面")
        const o = originInLayer(tip, host.tgtRef)
        compare(tip.y + tip.height + 8, o.y)
        // 写官方那个 prop，不写基座的 autoFlip —— 后者会绕过接线，
        // 「autoFlip: control.autoAdjustOverflow 写死 true」这种改动就打不红
        tip.autoAdjustOverflow = false
        wait(20)
        compare(tip.autoFlip, false, "autoAdjustOverflow 接到基座的 autoFlip")
        tip.reposition()
        wait(60)
        compare(tip.effectivePlacement, Enums.Bottom, "关掉 autoAdjustOverflow 就不翻")
        compare(tip.y, o.y + host.tgtRef.height + 8, "位置照官方公式，宁可溢出")
        tip.destroy()
        host.destroy()
    }

    function test_marginOnlyJoinsTheFitJudgement() {
        // 官方 margin 只进 shouldReverse*，不进最终 left/top（foundation.ts:887-890）
        const tight = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 648; width: 100; height: 32; color: '#eee' }"
            + " Tooltip { id: tip; target: tgt; text: 'hi bytedance'; motion: false;"
            + " position: Enums.Bottom } }")
        tight.tipRef.open()
        wait(60)
        compare(tight.tipRef.effectivePlacement, Enums.Top)
        const wide = make("Item { width: 800; height: 600;"
            + " property var tipRef: tip; property Item tgtRef: tgt;"
            + " Rectangle { id: tgt; x: 300; y: 648; width: 100; height: 32; color: '#eee' }"
            + " Tooltip { id: tip; target: tgt; text: 'hi bytedance'; motion: false;"
            + " position: Enums.Bottom; margin: 120 } }")
        wide.tipRef.open()
        wait(60)
        compare(wide.tipRef.effectivePlacement, Enums.Bottom, "margin 让「放得下」多让 120")
        const o = originInLayer(wide.tipRef, wide.tgtRef)
        compare(wide.tipRef.y, o.y + wide.tgtRef.height + 8, "margin 不进最终 y")
        tight.tipRef.destroy()
        tight.destroy()
        wide.tipRef.destroy()
        wide.destroy()
    }

    function test_zAndStackingOrder() {
        const host = makeHost('text: "hi"', "")
        const tip = tipOf(host)
        tip.open()
        wait(60)
        compare(tip.z, 1060)
        tip.zIndex = 900
        wait(20)
        compare(tip.z, 900, "zIndex 改了要落到浮层的 z 上")
        tip.destroy()
        host.destroy()
    }

    function test_followsTheme() {
        const host = makeHost('text: "hi"', "")
        const tip = tipOf(host)
        const light = tip.fillColor.toString()
        compare(light, Theme.current.grey[7].toString())
        Theme.mode = Theme.Dark
        wait(40)
        compare(tip.fillColor.toString(), Theme.current.grey[7].toString())
        verify(tip.fillColor.toString() !== light, "深灰档要跟着换")
        compare(labelOf(tip).color.toString(), Theme.current.colorBg0.toString())
        Theme.mode = Theme.Light
        tip.destroy()
        host.destroy()
    }
}
