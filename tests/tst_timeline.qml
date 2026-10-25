import QtQuick
import QtTest
import Semi

// Timeline 时间轴。规格照 packages/semi-ui/timeline/{index,item}.tsx 与
// semi-foundation/timeline/{timeline,variables}.scss，
// 期望值全部是浏览器实测 DOM 的数（tests/tmp_timeline_dom.html + /tmp/semi_ref/timeline/*.json）：
// 条目宽 520（Timeline 给 536，官方 ul 的 8px 内边距算在 width 里），
// 圆点 9×9 @top 5、连线 1px @(4,20) 高 = 条目高 - 20、正文 14/20 @x 25、
// extra / time 12/16 且块间距 4，center 档时间浮到 x=-5、y=2。
// 行高是 Text.FixedHeight 锁死的，这些高度不随字体变，可以直接断绝对值。
// 条目在列容器里的 y 要下一帧才排好，所以凡断位置 / 高度都先 wait()。
TestCase {
    id: testCase

    name: "Timeline"
    when: windowShown
    width: 900
    height: 600

    property bool hit: false

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    // 建完等一拍，让列容器真的把条目排下去
    function makeLaid(qml) {
        const o = make(qml)
        wait(20)
        return o
    }

    // 只数真正在渲染的那一条列容器里的条目：Repeater 生成的条目 findChild 摸不到，
    // 而给了 dataSource 时声明式子项还留在暂存容器里（不能算进来）。
    // 顺序要看排版，所以一律走 visualItems（childItems 在 QML 里根本摸不到）
    function itemsOf(tl) {
        const body = testCase.findChild(tl,
            tl.usesDataSource ? "timelineDataBody" : "timelineDeclaredBody")
        const out = [];
        const kids = body.children;
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].objectName === "timelineItem")
                out.push(kids[i]);
        }
        return out;
    }

    // 渲染顺序（Column 从上到下）
    function visualItems(tl) {
        const list = itemsOf(tl).slice(0);
        list.sort((a, b) => a.y - b.y);
        return list;
    }

    function slot(item, name) {
        return testCase.findChild(item, name);
    }

    function textOf(item, name) {
        return slot(item, name).text;
    }

    // ---------------------------------------------------------------- 属性面

    function test_defaults() {
        const tl = make("Timeline { }")
        compare(tl.mode, "left", "index.tsx:35-37 defaultProps")
        compare(tl.dataSource, undefined)
        compare(tl.usesDataSource, false)
        compare(tl.implicitWidth, 320)
        // 官方 ul = padding: $spacing-tight 8 一圈，没有条目时高度就是这 16
        compare(tl.implicitHeight, 16)
        tl.destroy()

        const it = make("TimelineItem { }")
        compare(it.type, "default", "item.tsx:37-41 defaultProps")
        compare(it.color, "")
        compare(it.position, "")
        compare(it.time, "")
        compare(it.extra, "")
        compare(it.content, "")
        compare(it.dot, null)
        compare(it.timelineMode, "left")
        compare(it.timelineIndex, 0)
        compare(it.timelineCount, 1)
        compare(it.side, "left")
        compare(it.isLast, true)
        compare(it.timeFloating, false)
        it.destroy()
    }

    // ---------------------------------------------------------------- left 档几何

    function test_leftModeGeometry() {
        const tl = makeLaid("Timeline { width: 536;"
            + " TimelineItem { time: '2019-07-14 10:35'; content: '第一个节点内容' }"
            + " TimelineItem { time: '2019-06-13 16:17'; content: '第二个节点内容' }"
            + " }")
        const items = itemsOf(tl)
        compare(items.length, 2)
        const a = items[0]
        compare(a.width, 520, "条目 = ul 内容框 520（536 - 两侧 8 内边距）")
        compare(a.side, "left")
        compare(a.contentX, 25)                       // $spacing-timeline_content-marginLeft
        compare(a.contentW, 495)
        compare(a.tailX, 4)                           // $spacing-timeline_tail-left
        compare(a.dotX, 0)
        compare(a.customDotX, 5)                      // $spacing-timeline_head_custom-left
        compare(a.timeFloating, false)

        const dot = slot(a, "timelineDot")
        compare(dot.x, 0)
        compare(dot.y, 5)                             // $spacing-timeline_head-top
        compare(dot.width, 9)                         // $width-timeline_dot
        compare(dot.height, 9)
        compare(dot.radius, 4.5, "$radius-timeline_head = circle，9 的一半")

        const tail = slot(a, "timelineTail")
        compare(tail.x, 4)
        compare(tail.y, 20)                           // $spacing-timeline_tail-top
        compare(tail.width, 1)                        // $border-thickness-control
        compare(tail.height, 44)
        compare(tail.visible, true)

        // 正文 20 + 4 + 时间 16 = 40，再加 $spacing-loose 24 = 64（DOM 实测 li 高 64）
        compare(a.height, 64)
        compare(slot(a, "timelineFlow").x, 25)
        compare(slot(a, "timelineContentText").height, 20)
        compare(slot(a, "timelineTimeText").height, 16)
        compare(slot(a, "timelineTimeSlot").y, 24)

        // 官方把 24 的节点间距记在每个条目的 padding-bottom 里，列容器本身不留 spacing
        compare(items[1].y, 64)
        compare(items[1].x, 0)
        const body = testCase.findChild(tl, "timelineDeclaredBody")
        compare(body.x, 8, "列容器吃 ul 的 8px 左内边距")
        compare(body.y, 8, "列容器吃 ul 的 8px 上内边距")
        compare(body.width, 520)
        compare(body.visible, true)
        const dataBody = testCase.findChild(tl, "timelineDataBody")
        compare(dataBody.visible, false,
            "没给 dataSource 时那条容器要收起：日后改给 dataSource 才不会两批条目同时画")

        compare(tl.implicitHeight, 16 + 64 + 64)
        tl.destroy()
    }

    function test_extraAndTimeStackInDomOrder() {
        const tl = makeLaid("Timeline { width: 536;"
            + " TimelineItem { time: '2019-07-14 10:35'; extra: '节点辅助说明信息'; content: '第一个节点内容' }"
            + " }")
        const a = itemsOf(tl)[0]
        // DOM：正文 20 → extra(4,16) → time(4,16)，li 84
        compare(a.height, 84)
        compare(slot(a, "timelineContentText").height, 20)
        compare(slot(a, "timelineExtraSlot").y, 24)
        compare(slot(a, "timelineExtraText").height, 16)
        compare(slot(a, "timelineTimeSlot").y, 44)
        compare(slot(a, "timelineTimeSlot").visible, true)
        tl.destroy()
    }

    function test_lastItemDropsTail() {
        const tl = makeLaid("Timeline { width: 536;"
            + " TimelineItem { content: '一' }"
            + " TimelineItem { content: '二' }"
            + " TimelineItem { content: '三' }"
            + " }")
        const items = visualItems(tl)
        compare(items.length, 3)
        compare(textOf(items[0], "timelineContentText"), "一")
        compare(items[0].isLast, false)
        compare(items[1].isLast, false)
        compare(items[2].isLast, true)
        compare(slot(items[0], "timelineTail").visible, true)
        compare(slot(items[2], "timelineTail").visible, false,
            "官方 .semi-timeline-item:last-child > .tail { border-left: none }")
        tl.destroy()
    }

    function test_timeOnlyRowKeepsNoGap() {
        // 官方空正文时第一个块的上外边距会穿破父容器（DOM 实测 time y=0、li 40），
        // 所以这边时间贴流顶部、不额外留 4
        const tl = makeLaid("Timeline { width: 536; TimelineItem { time: '2019-07-14 10:35' } }")
        const a = itemsOf(tl)[0]
        compare(slot(a, "timelineContentSlot").visible, false)
        compare(a.height, 40)
        compare(slot(a, "timelineTimeSlot").y, 0)
        tl.destroy()
    }

    function test_tailHeightFollowsWrappedContent() {
        // DOM：正文换行后条目长高，连线跟着走到条目底边（实测 content 100、li 124、tail 104）
        const long = "很长的中文内容很长的中文内容很长的中文内容很长的中文内容很长的中文内容"
            + "很长的中文内容很长的中文内容很长的中文内容很长的中文内容很长的中文内容"
        const tl = makeLaid("Timeline { width: 536; TimelineItem { content: '" + long + "' } }")
        const a = itemsOf(tl)[0]
        const body = slot(a, "timelineContentText")
        compare(body.width, 495)
        verify(body.height > 20, "该换行了")
        compare(body.height % 20, 0, "行高锁 20，换几行都是整数倍")
        compare(a.height, body.height + 24)
        compare(slot(a, "timelineTail").height, a.height - 20)
        tl.destroy()
    }

    // ---------------------------------------------------------------- 色值

    function test_dotColorFollowsType() {
        const cases = [
            ["default", Theme.current.colorTertiaryLightActive],   // $color-timeline_dot_info-bg-default
            ["ongoing", Theme.current.colorPrimary],
            ["success", Theme.current.colorSuccess],
            ["warning", Theme.current.colorWarning],
            ["error", Theme.current.colorDanger]
        ]
        for (let i = 0; i < cases.length; ++i) {
            const it = make("TimelineItem { type: '" + cases[i][0] + "' }")
            compare(it.dotColor.toString(), cases[i][1].toString(), cases[i][0])
            it.destroy()
        }
        // 官方对认不出的 type 不给背景色（圆点直接消失），这里落回 default
        const odd = make("TimelineItem { type: 'nope' }")
        compare(odd.dotColor.toString(), Theme.current.colorTertiaryLightActive.toString())
        odd.destroy()
    }

    function test_colorPropOverridesType() {
        const tl = make("Timeline { width: 536;"
            + " TimelineItem { type: 'success'; color: 'pink'; content: '自定义节点颜色' }"
            + " }")
        const a = itemsOf(tl)[0]
        compare(a.dotColor.toString(), "#ffc0cb",
            "color 是内联样式，盖过 type（item.tsx:66）")
        compare(slot(a, "timelineDot").color.toString(), "#ffc0cb")
        tl.destroy()
    }

    function test_textAndTailColors() {
        const tl = make("Timeline { width: 536;"
            + " TimelineItem { content: '正文'; extra: '辅助'; time: '时间' }"
            + " }")
        const a = itemsOf(tl)[0]
        compare(slot(a, "timelineContentText").color.toString(),
            Theme.current.colorText0.toString())
        compare(slot(a, "timelineExtraText").color.toString(),
            Theme.current.colorText2.toString())
        compare(slot(a, "timelineTimeText").color.toString(),
            Theme.current.colorText2.toString())
        compare(slot(a, "timelineTail").color.toString(),
            Theme.current.colorText3.toString())
        compare(slot(a, "timelineContentText").font.pixelSize, 14)
        compare(slot(a, "timelineExtraText").font.pixelSize, 12)
        compare(slot(a, "timelineTimeText").font.pixelSize, 12)
        tl.destroy()
    }

    function test_tailColorFollowsTheme() {
        const tl = makeLaid("Timeline { width: 536; TimelineItem { content: 'x' } }")
        const tail = slot(itemsOf(tl)[0], "timelineTail")
        compare(tail.color.toString(), Theme.current.colorText3.toString())
        const before = tail.color.toString()
        Theme.mode = Theme.Dark
        verify(tail.color.toString() !== before, "连线色要随主题走（$color-timeline_tail-border = text-3）")
        compare(tail.color.toString(), Theme.current.colorText3.toString(),
            "皮肤项是跟着令牌走的，不是缓存值")
        Theme.mode = Theme.Light
        tl.destroy()
    }

    // ---------------------------------------------------------------- 自定义 dot

    function test_customDotCentredAtAnchor() {
        const tl = makeLaid("Timeline { width: 536;"
            + " TimelineItem { content: '自定义图标'; type: 'warning';"
            + "     dot: Component { Icon { name: 'alert_triangle' } } }"
            + " }")
        const a = itemsOf(tl)[0]
        const loader = slot(a, "timelineCustomDot")
        verify(loader.item !== null, "dot 该被装载出来")
        compare(slot(a, "timelineDot").visible, false, "给了 dot 就不画默认圆点")
        // -head-custom：left 5 / top 10 再 translate(-50%,-50%) → 中心落在这两点上
        compare(loader.x + loader.width / 2, 5)
        compare(loader.y + loader.height / 2, 10)
        tl.destroy()
    }

    function test_customDotTintedByType() {
        const tl = make("Timeline { width: 536;"
            + " TimelineItem { content: 'x'; type: 'warning';"
            + "     dot: Component { Icon { name: 'alert_triangle' } } }"
            + " }")
        const a = itemsOf(tl)[0]
        const loader = slot(a, "timelineCustomDot")
        compare(loader.item.color.toString(), Theme.current.colorWarning.toString(),
            "-head-custom.-head-warning { color: warning }，图标靠 currentColor 取色")
        compare(slot(a, "timelineCustomDotBg").visible, false, "没给 color 时背景是 transparent")
        tl.destroy()
    }

    function test_customDotBackdropNeedsColor() {
        const tinted = make("Timeline { width: 536; TimelineItem { content: 'x'; color: 'pink';"
            + " dot: Component { Icon { name: 'alert_triangle' } } } }")
        const it = itemsOf(tinted)[0]
        const bg = slot(it, "timelineCustomDotBg")
        const loader = slot(it, "timelineCustomDot")
        compare(bg.visible, true, "内联 background-color 盖过那条 transparent")
        compare(bg.x, loader.x)
        compare(bg.y, loader.y)
        compare(bg.width, loader.width)
        compare(bg.height, loader.height)
        compare(bg.color.toString(), "#ffc0cb")
        tinted.destroy()
    }

    // ---------------------------------------------------------------- center 档

    function test_centerModeGeometry() {
        const tl = makeLaid("Timeline { width: 536; mode: \"center\";"
            + " TimelineItem { time: '2019-07-14 10:35'; extra: '节点辅助说明信息'; content: '第一个节点内容' }"
            + " }")
        const a = itemsOf(tl)[0]
        compare(a.side, "left", "center 档 getPosCls 恒给 -item-left（index.tsx:47-52）")
        compare(a.tailX, 260)                          // left: 50%
        compare(a.dotX, 256)                           // -head 的 margin-left: -4
        compare(a.customDotX, 260)
        compare(a.contentX, 281)                       // margin 25 + relative left(50%-4)
        compare(a.contentW, 246)                       // 50% - 14
        compare(a.timeFloating, true)

        // 时间在 center 档脱离文档流：条目高不含它（DOM 实测 li 64）；extra 仍留在流里
        compare(a.height, 64)
        compare(slot(a, "timelineExtraSlot").visible, true)
        compare(slot(a, "timelineExtraSlot").y, 24)
        compare(slot(a, "timelineTimeSlot").visible, false)
        const floating = slot(a, "timelineFloatingSlot")
        compare(floating.visible, true)
        compare(floating.x, -5, "官方实测就是 -5，压在 ul 的 8px 内边距里")
        compare(floating.y, 2)                         // top -2 + margin-top 4
        compare(floating.width, 246)
        compare(slot(a, "timelineFloatingTimeText").horizontalAlignment, Text.AlignRight)
        compare(slot(a, "timelineFloatingTimeText").text, "2019-07-14 10:35")
        tl.destroy()
    }

    function test_centerModeClampsFullyOffBoxTime() {
        // 官方 center 档 + position=right 时 margin-left: calc(-40px - 100%) 会把时间整块
        // 推到条目左边界外（实测 x=-280、右边缘 -40，文字全看不见）。这里只在整块出界时夹回 0。
        const tl = makeLaid("Timeline { width: 536; mode: \"center\";"
            + " TimelineItem { position: \"right\"; time: '2019-07-14 10:35'; content: 'x' }"
            + " }")
        const a = itemsOf(tl)[0]
        compare(a.side, "right")
        compare(a.contentX, 0)
        compare(a.contentW, 240)                       // 50% - 20
        compare(a.floatingTimeRawX, -280, "官方的原始算式确实是这个数")
        compare(a.floatingTimeX, 0, "整块出界，夹回条目左边")
        compare(slot(a, "timelineFloatingSlot").x, 0)
        tl.destroy()
    }

    // ---------------------------------------------------------------- alternate 档

    function test_alternateSidesAlternate() {
        const tl = makeLaid("Timeline { width: 536; mode: \"alternate\";"
            + " TimelineItem { content: '一'; time: 't1' }"
            + " TimelineItem { content: '二'; time: 't2' }"
            + " TimelineItem { content: '三'; time: 't3' }"
            + " TimelineItem { content: '四'; time: 't4' }"
            + " }")
        const items = visualItems(tl)
        compare(items.length, 4)
        // idx % 2 === 0 → left（index.tsx:45）
        compare(items[0].side, "left")
        compare(items[1].side, "right")
        compare(items[2].side, "left")
        compare(items[3].side, "right")

        compare(items[0].contentX, 281)
        compare(items[0].contentW, 246)
        compare(items[0].alignRight, false)
        compare(items[1].contentX, 0)
        compare(items[1].contentW, 240)                // 50% - 20，margin 归 0
        compare(items[1].alignRight, true)
        compare(items[0].tailX, 260)
        compare(items[1].tailX, 260)
        compare(items[0].dotX, 256)
        compare(slot(items[1], "timelineFlow").x, 0)
        compare(slot(items[1], "timelineTail").x, 260)

        // alternate 档时间不浮（只有 center 档那条规则），照 DOM 顺序排在正文之后
        compare(items[0].timeFloating, false)
        compare(slot(items[0], "timelineTimeSlot").visible, true)
        compare(slot(items[0], "timelineTimeSlot").y, 24)
        compare(slot(items[0], "timelineTimeText").horizontalAlignment, Text.AlignLeft)
        compare(slot(items[1], "timelineTimeText").horizontalAlignment, Text.AlignRight)
        compare(items[0].height, 20 + 4 + 16 + 24)
        tl.destroy()
    }

    function test_positionOverridesInCenterAndAlternate() {
        const tl = make("Timeline { width: 536; mode: \"alternate\";"
            + " TimelineItem { position: \"right\"; content: '一' }"
            + " TimelineItem { position: \"left\"; content: '二' }"
            + " }")
        const items = itemsOf(tl)
        compare(items[0].side, "right", "偶数条本来在左，position 覆盖")
        compare(items[1].side, "left")
        compare(items[0].contentW, 240)
        compare(items[1].contentW, 246)
        tl.destroy()
    }

    function test_positionIgnoredInLeftAndRightMode() {
        // getPosCls 在 left / right 档直接返回 mode，压根不看 position（index.tsx:53-54）
        const left = make("Timeline { width: 536;"
            + " TimelineItem { position: \"right\"; content: 'x' } }")
        compare(itemsOf(left)[0].side, "left")
        compare(itemsOf(left)[0].contentW, 495)
        left.destroy()

        const right = make("Timeline { width: 536; mode: \"right\";"
            + " TimelineItem { position: \"left\"; content: 'x' } }")
        compare(itemsOf(right)[0].side, "right")
        right.destroy()
    }

    // ---------------------------------------------------------------- right 档

    function test_rightModeAxisAtEdge() {
        const tl = makeLaid("Timeline { width: 536; mode: \"right\";"
            + " TimelineItem { content: '第一个节点内容'; extra: '节点辅助说明信息'; time: '2019-07-14 10:35' }"
            + " }")
        const a = itemsOf(tl)[0]
        // compiled css: .semi-timeline-right .semi-timeline-item-right … { left: calc(100% - 9px) }
        compare(a.tailX, 511)
        compare(a.dotX, 507)
        compare(a.customDotX, 511)
        compare(a.contentX, 0)
        compare(a.contentW, 492)                       // 100% - 28
        compare(a.alignRight, true)
        compare(a.timeFloating, false)
        compare(a.height, 84)
        compare(slot(a, "timelineTail").x, 511)
        compare(slot(a, "timelineTimeText").horizontalAlignment, Text.AlignRight)
        tl.destroy()
    }

    function test_rightModeLeftItemKeepsCentredAxis() {
        // right 档那条贴边规则要求 -item-right 类；center 档里 position=left 的条目
        // 就仍走通用「左侧条目」公式（轴线在 50%）
        const tl = make("Timeline { width: 536; mode: \"center\";"
            + " TimelineItem { position: \"left\"; content: 'x' } }")
        const a = itemsOf(tl)[0]
        compare(a.side, "left")
        compare(a.tailX, 260)
        compare(a.contentX, 281)
        tl.destroy()
    }

    // ---------------------------------------------------------------- dataSource

    function test_dataSourceBuildsItemsInVisualOrder() {
        const tl = makeLaid("Timeline { width: 536; dataSource: ["
            + " { content: '第一个节点内容', time: '2019-07-14 10:35' },"
            + " { content: '第二个节点内容', time: '2019-06-13 16:17', type: 'success' },"
            + " { content: '第三个节点内容', time: '2019-05-14 18:34', type: 'error' }"
            + " ] }")
        const items = visualItems(tl)
        compare(items.length, 3)
        const dataBody = testCase.findChild(tl, "timelineDataBody")
        compare(dataBody.x, 8, "dataSource 那条容器同样吃 8px 内边距")
        compare(dataBody.y, 8)
        compare(dataBody.width, 520)
        compare(dataBody.visible, true)
        compare(testCase.findChild(tl, "timelineDeclaredBody").visible, false)
        compare(textOf(items[0], "timelineContentText"), "第一个节点内容")
        compare(textOf(items[1], "timelineContentText"), "第二个节点内容")
        compare(textOf(items[2], "timelineContentText"), "第三个节点内容")
        // 角色下发用的顺序必须就是渲染顺序
        compare(items[0].timelineIndex, 0)
        compare(items[1].timelineIndex, 1)
        compare(items[2].timelineIndex, 2)
        compare(items[0].y, 0)
        compare(items[1].y, items[0].height)
        compare(items[2].y, items[0].height + items[1].height)
        compare(items[2].isLast, true, "角色也要推给 Repeater 生成的条目")
        compare(items[0].dotColor.toString(), Theme.current.colorTertiaryLightActive.toString(),
            "不写 type 就是 default")
        compare(items[1].dotColor.toString(), Theme.current.colorSuccess.toString())
        compare(items[2].dotColor.toString(), Theme.current.colorDanger.toString())
        compare(items[0].time, "2019-07-14 10:35")
        compare(items[0].extra, "", "缺省不渲染辅助内容")
        compare(slot(items[0], "timelineExtraSlot").visible, false)
        compare(items[0].height, 64)
        tl.destroy()
    }

    function test_dataSourcePassesEveryItemProp() {
        // 注意：内联 Component 只能声明成属性，不能写在 dataSource 的对象字面量里
        // （createQmlObject 解析 `{ dot: Component { … } }` 会报 Expected token `,`）
        const tl = makeLaid("Timeline { width: 536; mode: \"alternate\";"
            + " property Component dotComp: Component { Icon { name: 'alert_triangle' } }"
            + " dataSource: ["
            + " { content: '带图标', type: 'warning', dot: dotComp },"
            + " { content: '带颜色', color: 'pink', position: 'left' },"
            + " { content: '带辅助', extra: '节点辅助说明信息', time: '2019-05-14 18:34' }"
            + " ] }")
        const items = visualItems(tl)
        compare(items.length, 3)

        const dotLoader = slot(items[0], "timelineCustomDot")
        verify(dotLoader.item !== null, "dataSource 的 dot 也该装载")
        compare(dotLoader.item.color.toString(), Theme.current.colorWarning.toString())

        compare(items[1].color, "pink")
        compare(items[1].dotColor.toString(), "#ffc0cb")
        compare(items[1].side, "left", "奇数条本来在右，dataSource 里的 position 也得透传")
        compare(items[1].contentW, 246)

        // 偶数条（idx 0、2）在 alternate 下默认左
        compare(items[0].side, "left")
        compare(items[2].side, "left")
        compare(textOf(items[2], "timelineExtraText"), "节点辅助说明信息")
        compare(textOf(items[2], "timelineTimeText"), "2019-05-14 18:34")
        compare(textOf(items[1], "timelineContentText"), "带颜色")
        tl.destroy()
    }

    function test_dataSourceContentCanBeComponent() {
        const tl = makeLaid("Timeline { width: 536;"
            + " property Component big: Component { Text { text: '自定义节点样式'; font.pixelSize: 18 } }"
            + " dataSource: [ { content: big } ] }")
        const a = visualItems(tl)[0]
        compare(a.contentIsText, false)
        compare(slot(a, "timelineContentText").visible, false)
        const node = slot(a, "timelineContentNode")
        verify(node.item !== null)
        compare(node.item.text, "自定义节点样式")
        compare(node.item.font.pixelSize, 18)
        verify(a.height > 40, "自定义内容的行高要算进条目高度")
        tl.destroy()
    }

    function test_dataSourceOnClickCallback() {
        testCase.hit = false
        const tl = makeLaid("Timeline { width: 536; dataSource: ["
            + " { content: '点我', time: 't', onClick: () => { testCase.hit = true } }"
            + " ] }")
        const a = visualItems(tl)[0]
        mouseClick(a, a.width / 2, 5)
        wait(40)
        compare(testCase.hit, true, "官方 Timeline.Item 2.2.0 起有 onClick，dataSource 也透传")
        tl.destroy()
    }

    function test_dataSourceWinsOverDeclarativeChildren() {
        // 官方二选一：dataSource 非空就完全不看 children（index.tsx:83-89）
        const tl = makeLaid("Timeline { width: 536;"
            + " TimelineItem { content: '声明式一' }"
            + " TimelineItem { content: '声明式二' }"
            + " dataSource: [ { content: '数据源一' } ]"
            + " }")
        const items = visualItems(tl)
        compare(items.length, 1, "声明式子项不渲染")
        compare(textOf(items[0], "timelineContentText"), "数据源一")
        compare(items[0].timelineCount, 1, "条数只算真的在渲染的那几条")
        tl.destroy()
    }

    function test_clearingDataSourceMovesParkedChildren() {
        // 创建时给了 dataSource，声明式子项就留在暂存容器里（refreshItems 那一档闸门）。
        // 运行中把 dataSource 收回去，补搬的触发点只剩 onDataSourceChanged 这一处，
        // 而那一趟里派生绑定 usesDataSource 还是上一步的 true —— 所以闸门必须直接看
        // dataSource 本身。搬完就得立刻带上角色（同步断，等下一趟排版就看不出这一处了）。
        const tl = makeLaid("Timeline { width: 536;"
            + " TimelineItem { content: '声明式一' }"
            + " TimelineItem { content: '声明式二' }"
            + " dataSource: [ { content: '数据源一' } ] }")
        compare(visualItems(tl).length, 1, "先只渲染数据源")

        tl.dataSource = []
        compare(tl.usesDataSource, false)
        let items = visualItems(tl)
        compare(items.length, 2, "收回数据源之后要把留在暂存容器的子项补搬进来")
        compare(textOf(items[0], "timelineContentText"), "声明式一")
        compare(textOf(items[1], "timelineContentText"), "声明式二")
        compare(items[0].timelineIndex, 0, "补搬的当场就要推角色")
        compare(items[1].timelineIndex, 1)
        compare(items[1].timelineCount, 2)
        compare(items[1].isLast, true)
        compare(slot(items[0], "timelineTail").visible, true)

        wait(20)
        items = visualItems(tl)
        compare(items.length, 2, "排版之后条目还是这两条")
        compare(tl.implicitHeight, 16 + 44 * 2)
        tl.destroy()
    }

    function test_emptyDataSourceFallsBackToChildren() {
        const tl = makeLaid("Timeline { width: 536; dataSource: [];"
            + " TimelineItem { content: '声明式一' }"
            + " TimelineItem { content: '声明式二' }"
            + " }")
        compare(tl.usesDataSource, false, "空数组不算给了 dataSource")
        const items = visualItems(tl)
        compare(items.length, 2)
        compare(textOf(items[0], "timelineContentText"), "声明式一")
        compare(textOf(items[1], "timelineContentText"), "声明式二")
        compare(items[1].isLast, true)
        tl.destroy()
    }

    // ---------------------------------------------------------------- 角色同步

    function test_rolesFollowModeChange() {
        const tl = makeLaid("Timeline { width: 536;"
            + " TimelineItem { content: '一' }"
            + " TimelineItem { content: '二' }"
            + " }")
        const items = itemsOf(tl)
        compare(items[0].side, "left")
        compare(items[0].contentX, 25)
        compare(items[1].side, "left")

        tl.mode = "alternate"
        wait(20)
        compare(items[0].side, "left")
        compare(items[1].side, "right", "mode 一改，推下来的 timelineMode 要跟着改")
        compare(items[1].contentX, 0)
        compare(items[1].tailX, 260)

        tl.mode = "center"
        compare(items[1].side, "left", "center 档不看奇偶")
        compare(items[1].contentX, 281)

        tl.mode = "right"
        compare(items[0].tailX, 511)
        compare(items[0].contentW, 492)
        tl.destroy()
    }

    function test_appendingDataSourceItemResyncsRoles() {
        const tl = makeLaid("Timeline { width: 536; dataSource: [ { content: '一' } ] }")
        compare(itemsOf(tl).length, 1)
        compare(itemsOf(tl)[0].isLast, true)

        tl.dataSource = [{ content: "一" }, { content: "二" }]
        wait(20)
        const items = visualItems(tl)
        compare(items.length, 2, "数组变长要长出第二个条目")
        compare(textOf(items[0], "timelineContentText"), "一")
        compare(textOf(items[1], "timelineContentText"), "二")
        compare(items[0].isLast, false, "总数要重算，否则第一条的连线不会画出来")
        compare(items[1].isLast, true)
        compare(items[1].timelineIndex, 1)
        compare(slot(items[0], "timelineTail").visible, true)
        compare(tl.implicitHeight, 16 + 44 + 44)
        tl.destroy()
    }

    function test_childrenAddedLaterGetMovedAndResync() {
        // 声明式子项也可以是运行时长出来的（Repeater 套在 Timeline 里 = 官方 JSX 的 map 写法）。
        // 宿主跟着一起搬进列容器，所以长出来的条目直接落在列容器里，由列容器的 childrenChanged
        // 重推角色；条目数、序号、收尾都得跟着变。
        const host = makeLaid("Item { property int n: 1;"
            + " Timeline { width: 536; Repeater { model: n;"
            + " delegate: TimelineItem { content: '第' + index + '条' } } } }")
        const tl = host.children[0]
        compare(itemsOf(tl).length, 1, "第一条要搬进列容器")

        host.n = 3
        wait(20)
        const items = visualItems(tl)
        compare(items.length, 3, "后长出来的两条也要进列容器")
        compare(textOf(items[0], "timelineContentText"), "第0条")
        compare(textOf(items[2], "timelineContentText"), "第2条")
        compare(items[0].timelineIndex, 0)
        compare(items[2].timelineIndex, 2)
        compare(items[0].timelineCount, 3)
        compare(items[0].isLast, false, "条数要重算，否则第一条的连线不会画出来")
        compare(items[2].isLast, true)
        compare(slot(items[2], "timelineTail").visible, false)
        host.destroy()
    }

    function test_repeaterGrownBetweenSiblingsKeepsLayoutOrder() {
        // 声明式条目与 Repeater 混排（官方 JSX 里静态节点和 map 输出混写）。宿主跟着一起搬进
        // 列容器之后，Repeater 长出来的条目用 stackBefore 插在兄弟之间 —— 序号必须跟着**排版**
        // 走，按 QObject 名单排就会把「丙」认成第三条，alternate 的左右和收尾全错。
        const host = makeLaid("Item { property int n: 1;"
            + " Timeline { width: 536; mode: \"alternate\"; TimelineItem { content: '甲' }"
            + " Repeater { model: n; delegate: TimelineItem { content: '乙' + index } }"
            + " TimelineItem { content: '丙' } } }")
        const tl = host.children[0]
        let items = visualItems(tl)
        compare(items.length, 3)
        compare(textOf(items[0], "timelineContentText"), "甲")
        compare(textOf(items[1], "timelineContentText"), "乙0")
        compare(textOf(items[2], "timelineContentText"), "丙", "声明在后就得排在后")
        compare(items[0].timelineIndex, 0)
        compare(items[1].timelineIndex, 1)
        compare(items[2].timelineIndex, 2)
        compare(items[0].side, "left")
        compare(items[1].side, "right")
        compare(items[2].side, "left")
        compare(tl.implicitHeight, 16 + 44 * 3)

        host.n = 3
        wait(20)
        items = visualItems(tl)
        compare(items.length, 5, "长出来的两条要插在丙之前")
        compare(textOf(items[0], "timelineContentText"), "甲")
        compare(textOf(items[1], "timelineContentText"), "乙0")
        compare(textOf(items[2], "timelineContentText"), "乙1")
        compare(textOf(items[3], "timelineContentText"), "乙2")
        compare(textOf(items[4], "timelineContentText"), "丙")
        for (let i = 0; i < items.length; ++i) {
            compare(items[i].timelineIndex, i, "序号要按上下位置排")
            compare(items[i].timelineCount, 5)
            compare(items[i].side, i % 2 === 0 ? "left" : "right", "左右也得跟着位置")
        }
        compare(items[4].isLast, true, "收尾归最后那一行，不归名单末尾")
        compare(items[3].isLast, false)
        compare(slot(items[4], "timelineTail").visible, false)
        compare(slot(items[3], "timelineTail").visible, true)
        compare(tl.implicitHeight, 16 + 44 * 5)

        host.n = 1
        wait(20)
        items = visualItems(tl)
        compare(items.length, 3, "数组缩短要收回条目")
        compare(textOf(items[2], "timelineContentText"), "丙")
        compare(items[2].timelineIndex, 2)
        compare(items[2].timelineCount, 3)
        compare(items[1].timelineIndex, 1)
        compare(tl.implicitHeight, 16 + 44 * 3)
        host.destroy()
    }

    function test_countAndIndexDriveOnlyOneTail() {
        const tl = makeLaid("Timeline { width: 536; mode: \"alternate\";"
            + " TimelineItem { content: '一' }"
            + " TimelineItem { content: '二' }"
            + " TimelineItem { content: '三' }"
            + " }")
        const items = visualItems(tl)
        compare(items.length, 3)
        compare(slot(items[0], "timelineTail").visible, true)
        compare(slot(items[1], "timelineTail").visible, true)
        compare(slot(items[2], "timelineTail").visible, false)
        for (let i = 0; i < items.length; ++i) {
            compare(items[i].timelineCount, 3)
            compare(items[i].timelineIndex, i)
        }
        tl.destroy()
    }

    // ---------------------------------------------------------------- 交互与独立使用

    function test_clickedSignalFires() {
        const tl = makeLaid("Timeline { width: 536; TimelineItem { content: '点我' } }")
        const a = itemsOf(tl)[0]
        let fired = 0
        const spy = () => { fired += 1 }
        a.clicked.connect(spy)
        mouseClick(a, a.width / 2, 6)
        wait(40)
        compare(fired, 1, "官方 onClick 挂在 li 上，整块都是点击区")
        a.clicked.disconnect(spy)
        tl.destroy()
    }

    function test_standaloneItemFallsBackToLeftMode() {
        // 没有 Timeline 推角色：mode 默认 left、自己是唯一一条（没有连线）
        const it = make("TimelineItem { content: '单摆' }")
        compare(it.timelineMode, "left")
        compare(it.timelineCount, 1)
        compare(it.isLast, true)
        compare(it.tailX, 4)
        compare(it.dotX, 0)
        compare(it.contentX, 25)
        compare(slot(it, "timelineTail").visible, false)
        it.destroy()
    }
}
