import QtQuick
import QtQuick.Window
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Popup"
    when: windowShown
    width: 400
    height: 400

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

    function test_defaults() {
        const popup = make("PopupBase { }")
        compare(popup.placement, Enums.Bottom)
        compare(popup.autoFlip, true)
        compare(popup.showArrow, false)
        compare(popup.padding, Theme.current.spacingBaseTight)
        popup.destroy()
    }

    function test_verticalDetection() {
        const popup = make("PopupBase { }")
        compare(popup.isVertical(Enums.Top), true)
        compare(popup.isVertical(Enums.BottomLeft), true)
        compare(popup.isVertical(Enums.Left), false)
        compare(popup.isVertical(Enums.RightTop), false)
        popup.destroy()
    }

    function test_flipMapping() {
        const popup = make("PopupBase { }")
        compare(popup.isFlipped(Enums.Bottom), Enums.Top)
        compare(popup.isFlipped(Enums.Top), Enums.Bottom)
        compare(popup.isFlipped(Enums.Left), Enums.Right)
        compare(popup.isFlipped(Enums.Right), Enums.Left)
        popup.destroy()
    }





    function test_followsTheme() {
        const pop = make("PopupBase { }")
        const before = pop.fillColor.toString()
        Theme.mode = Theme.Dark
        verify(pop.fillColor.toString() !== before, "弹层底色应随主题变")
        pop.destroy()
    }

    // ---- 弹层不得遮挡锚点（对齐 Semi 的 autoAdjustOverflow）----

    // 造一个「锚点 + 指定高度弹层」的场景，返回 host（host.a / host.p 取两端）
    // 成员声明之间用换行 —— 对象成员后面加分号会被解析器拒绝
    function makeAnchored(popupHeight) {
        return make("Item {\n"
                + "width: 160\n"
                + "height: 30\n"
                + "property alias a: a\n"
                + "property alias p: p\n"
                + "Rectangle { id: a; anchors.fill: parent }\n"
                + "PopupBase {\n"
                + "id: p\n"
                + "anchor: a\n"
                + "placement: Enums.BottomLeft\n"
                + "gap: 4\n"
                + "padding: 0\n"
                + "Item { width: 160; height: " + popupHeight + " }\n"
                + "}\n"
                + "}\n")
    }

    function anchorsInPopupCoords(host) {
        const o = host.a.mapToItem(host.p.parent, 0, 0)
        return { top: o.y, bottom: o.y + host.a.height }
    }

    // 不变式：弹层要么整体在锚点下方（含 gap），要么整体在上方 —— 绝不与锚点重叠。
    // 早先 reposition 末尾把 y 夹进窗口，下方空间不足时弹层会被推回来盖住锚点。
    function test_popupNeverCoversAnchor() {
        const win = testCase.win
        verify(win !== null, "取不到 window，测试会失去意义")
        if (!win)
            return

        // 锚点贴窗口底部：下方放不下、上方放得下 → 必须翻到上方
        const host = makeAnchored(200)
        host.y = Math.max(0, win.height - host.height - 8)
        host.p.open()
        wait(50)
        const a = anchorsInPopupCoords(host)
        const p = host.p
        verify(p.y >= a.bottom + p.gap || p.y + p.height <= a.top - p.gap,
               "弹层遮挡了锚点: popup.y=" + p.y + " h=" + p.height
               + " anchor=[" + a.top + "," + a.bottom + "]")
        if (a.bottom + p.gap + p.height > p.parent.height && a.top - p.gap >= p.height)
            verify(p.isVertical(p.effectivePlacement)
                   && (p.effectivePlacement === Enums.Top || p.effectivePlacement === Enums.TopLeft
                       || p.effectivePlacement === Enums.TopRight),
                   "下方放不下、上方放得下时应翻到上方，实际 " + p.effectivePlacement)
        host.destroy()
    }

    // isOpen 必须在动画之前翻转，否则「点两次才重开」会换种形式回来：
    // 退场动画期间 visible 仍为 true，此时 toggle() 若看 visible 就会把重开吞掉。
    function test_isOpenFlipsBeforeExitAnimation() {
        const host = makeAnchored(120)
        host.p.open()
        wait(50)
        verify(host.p.isOpen, "open 后 isOpen 应为 true")

        host.p.close()
        verify(!host.p.isOpen, "close() 后 isOpen 应立刻翻回 false，不等退场动画")
        verify(host.p.visible, "退场动画期间 visible 应仍为 true")

        host.p.toggle()                                 // 紧接着再开一次
        wait(200)
        verify(host.p.isOpen, "关闭后一次 toggle 就该重新打开")
        host.destroy()
    }


    // Semi 的弹层进出场是 zoomIn/zoomOut：100ms 内 scale 0.8<->1 + 淡入淡出。
    // 曾经 PopupBase 完全没配 enter/exit，弹层是硬切出现的。
    function test_popupHasZoomMotion() {
        const host = makeAnchored(120)
        verify(host.p.enter !== null, "缺少进场动画")
        verify(host.p.exit !== null, "缺少退场动画")

        host.p.open()
        wait(15)                                    // 动画 100ms，取中间帧
        verify(host.p.scale < 1 || host.p.opacity < 1,
               "进场中 scale/opacity 应未满，实际 scale=" + host.p.scale + " opacity=" + host.p.opacity)
        wait(200)
        verify(Math.abs(host.p.scale - 1) < 0.001, "进场结束 scale 应回到 1")
        compare(host.p.opacity, 1)

        // 有退场动画时，close() 之后弹层不会立刻消失，而是等动画播完才隐藏。
        // 中间帧的 opacity 采样受 wait() 精度影响不稳，这里断言可观测特征本身。
        host.p.close()
        verify(host.p.visible, "close() 后应还在播退场动画，不该立刻消失")
        wait(250)
        verify(!host.p.visible, "退场动画播完应真正关闭")
        host.destroy()
    }


    // 弹层挂在 Overlay 层后脱离了内容坐标系 —— 页面滚动时必须跟着锚点重算位置，
    // 否则锚点滚走了、弹层留在原地。Semi 是监听 scroll 重算，这里等价实现。
    function test_popupFollowsAnchorScroll() {
        const host = make("Item {\n"
                + "width: 300\n"
                + "height: 300\n"
                + "property alias fl: fl\n"
                + "property alias p: p\n"
                + "Flickable {\n"
                + "id: fl\n"
                + "width: 300\n"
                + "height: 300\n"
                + "contentHeight: 900\n"
                + "interactive: false\n"
                + "Rectangle { id: a; x: 20; y: 200; width: 120; height: 30 }\n"
                + "PopupBase {\n"
                + "id: p\n"
                + "anchor: a\n"
                + "placement: Enums.BottomLeft\n"
                + "gap: 4\n"
                + "padding: 0\n"
                + "Item { width: 120; height: 100 }\n"
                + "}\n"
                + "}\n"
                + "}\n")
        host.p.open()
        wait(50)
        const before = host.p.y
        host.fl.contentY = 120
        wait(50)
        verify(host.p.y !== before,
               "滚动后弹层应跟随锚点，实际 y 仍是 " + before)
        compare(host.p.y, before - 120)
        host.destroy()
    }

    // 上下都放不下：保持原方位贴锚点展开，允许溢出窗口，但不许盖住锚点
    function test_keepsSideWhenBothTooSmall() {
        const win = testCase.win
        verify(win !== null, "取不到 window，测试会失去意义")
        if (!win)
            return

        const host = makeAnchored(2000)
        host.y = Math.max(0, (win.height - host.height) / 2)
        host.p.open()
        wait(50)
        const a = anchorsInPopupCoords(host)
        const p = host.p
        compare(p.effectivePlacement, Enums.BottomLeft)
        verify(p.y >= a.bottom + p.gap,
               "上下都放不下时应保持下方，实际 popup.y=" + p.y + " anchor.bottom=" + a.bottom)
        host.destroy()
    }

    // 锚点在弹层打开期间**长高**（Select 多选标签换行把触发器撑高就是这一型）。
    // 帧轮询原先只比 anchor 的 top/left，尺寸变化整个漏掉 —— 弹层停在旧的下边界上，
    // 直接盖住长高的锚点。这里盯的是不变式本身：弹层顶边必须跟到新的下边界。
    function test_popupFollowsAnchorGrowHeight() {
        const host = make("Item {\n"
                + "width: 200\n"
                + "height: 200\n"
                + "property alias a: a\n"
                + "property alias p: p\n"
                + "Rectangle { id: a; x: 20; y: 20; width: 120; height: 30 }\n"
                + "PopupBase {\n"
                + "id: p\n"
                + "anchor: a\n"
                + "placement: Enums.BottomLeft\n"
                + "gap: 4\n"
                + "padding: 0\n"
                + "Item { width: 120; height: 60 }\n"
                + "}\n"
                + "}\n")
        host.p.open()
        wait(50)
        const before = host.p.y
        compare(before, anchorsInPopupCoords(host).bottom + host.p.gap, "起手位置")

        host.a.height = 90
        wait(50)
        const a = anchorsInPopupCoords(host)
        verify(host.p.y >= a.bottom + host.p.gap,
               "锚点长高后弹层应跟着下移，实际 popup.y=" + host.p.y + " anchor.bottom=" + a.bottom)
        compare(host.p.y, a.bottom + host.p.gap, "弹层顶边应正好贴在新的锚点下边界 + gap")
        verify(host.p.y !== before, "y 没动说明这一条根本没走重定位")
        host.destroy()
    }

    // 同一型缺陷的水平档：BottomRight 的 x 取自锚点**右**边界，锚点变宽而 left 不变时，
    // 只比 top/left 同样漏 —— 弹层右端会脱离锚点。
    function test_popupFollowsAnchorGrowWidth() {
        const host = make("Item {\n"
                + "width: 300\n"
                + "height: 200\n"
                + "property alias a: a\n"
                + "property alias p: p\n"
                + "Rectangle { id: a; x: 20; y: 20; width: 120; height: 30 }\n"
                + "PopupBase {\n"
                + "id: p\n"
                + "anchor: a\n"
                + "placement: Enums.BottomRight\n"
                + "gap: 4\n"
                + "padding: 0\n"
                + "Item { width: 120; height: 60 }\n"
                + "}\n"
                + "}\n")
        host.p.open()
        wait(50)
        const before = host.p.x

        host.a.width = 200
        wait(50)
        const o = host.a.mapToItem(host.p.parent, 0, 0)
        const right = o.x + host.a.width
        const expected = Math.round(right - host.p.width)
        compare(host.p.x, expected, "弹层右端应跟到新的锚点右边界")
        verify(host.p.x !== before, "x 没动说明这一条根本没走重定位")
        host.destroy()
    }

    // 上面两条都同时动了底边/右边，所以「只比 top/left」那一支被它们盖住。
    // 这一对把 top 与 left 单独钉住：锚点**远端那条边不动**、只有近端在移
    // （向上/向左展开的弹层正好只看得到近端 —— 卡片贴在锚点的上边线/左边线上）。

    // 向上展开 + 锚点边下移边变矮（底边不动）：只有 top 变了
    function test_popupFollowsAnchorTopEdge() {
        const host = make("Item {\n"
                + "width: 300\n"
                + "height: 300\n"
                + "property alias a: a\n"
                + "property alias p: p\n"
                + "Rectangle { id: a; x: 20; y: 100; width: 120; height: 100 }\n"
                + "PopupBase {\n"
                + "id: p\n"
                + "anchor: a\n"
                + "placement: Enums.TopLeft\n"
                + "gap: 4\n"
                + "padding: 0\n"
                + "Item { width: 120; height: 60 }\n"
                + "}\n"
                + "}\n")
        host.p.open()
        wait(50)
        compare(host.p.y, 100 - host.p.height - host.p.gap, "起手贴在锚点上边线")

        host.a.y = 130                                  // 底边仍是 200
        host.a.height = 70
        wait(50)
        const o = host.a.mapToItem(host.p.parent, 0, 0)
        compare(o.y + host.a.height, 200, "夹具走形了：底边该钉在 200")
        compare(host.p.y, Math.round(o.y - host.p.height - host.p.gap),
                "锚点上边线下移后卡片要跟着下移（只有 top 在动）")
        host.destroy()
    }

    // 向左展开 + 锚点右边不动、左边右移：只有 left 变了
    function test_popupFollowsAnchorLeftEdge() {
        const host = make("Item {\n"
                + "width: 400\n"
                + "height: 300\n"
                + "property alias a: a\n"
                + "property alias p: p\n"
                + "Rectangle { id: a; x: 200; y: 60; width: 120; height: 30 }\n"
                + "PopupBase {\n"
                + "id: p\n"
                + "anchor: a\n"
                + "placement: Enums.LeftTop\n"
                + "gap: 4\n"
                + "padding: 0\n"
                + "Item { width: 120; height: 60 }\n"
                + "}\n"
                + "}\n")
        host.p.open()
        wait(50)
        compare(host.p.effectivePlacement, Enums.LeftTop, "左边空间够，不该翻面")
        compare(host.p.x, 200 - host.p.width - host.p.gap, "起手贴在锚点左边线")

        host.a.x = 230                                  // 右边仍是 320
        host.a.width = 90
        wait(50)
        const o = host.a.mapToItem(host.p.parent, 0, 0)
        compare(o.x + host.a.width, 320, "夹具走形了：右边该钉在 320")
        compare(host.p.x, Math.round(o.x - host.p.width - host.p.gap),
                "锚点左边线右移后卡片要跟着右移（只有 left 在动）")
        host.destroy()
    }
}
