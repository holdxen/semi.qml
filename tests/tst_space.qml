import QtQuick
import QtTest
import Semi

// Space 间距容器。规格照 packages/semi-ui/space/{index.tsx,utils.ts}
// + semi-foundation/space/{space.scss,variables.scss} + 编译产物 semi.css:20283-20324。
//
// 端口口径（完整清单在 src/Space.qml 文件头）：
//   · 官方 5 条 prop 全收：wrap（缺省 false）、align（缺省 center，四档）、
//     vertical（缺省 false）、spacing（缺省 "tight"）、children；
//   · spacing 解析：三档字符串 8/16/24 + number 两轴同值 + [水平, 垂直] 数组档；
//     认不出的串与数组缺格 = 0（官方类名不命中 ⇒ 没设 gap 规则）；
//     undefined 走 React defaultProps 补 'tight'、null 落 0；
//   · 排布是两趟手工排布（Row/Column 不换行不认 align，Flow 单 spacing 撑不住两档）：
//     wrap 按 width 换行、align 管行内纵向（垂直档管列内横向）、baseline 按子项基线；
//   · 断言一律写死官方令牌与几何常数，期望值不从被测组件的函数里算。
TestCase {
    id: testCase

    name: "Space"
    when: windowShown
    width: 600
    height: 400

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy()
        wait(20)
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "space")
    }

    /// 参与排布的子项（与组件 nodes() 同口径：Repeater 空壳与不可见不收）
    function kids(s) {
        const out = []
        const list = s.children
        for (let i = 0; i < list.length; ++i) {
            const c = list[i]
            if (c === null || c === undefined || c instanceof Repeater)
                continue
            if (c.visible === false)
                continue
            out.push(c)
        }
        return out
    }

    // ---------------------------------------------------------------- 缺省
    function test_defaultsMatchOfficial() {
        // 官方 defaultProps（index.tsx:38-43）：vertical=false、wrap=false、
        // spacing='tight'、align='center'
        const s = make("Space { }")
        wait(20)
        compare(s.vertical, false)
        compare(s.wrap, false)
        compare(s.spacing, "tight", "缺省是字符串 tight，不是 number 8")
        compare(s.align, "center")
        compare(s.effectiveWrap, false, "isWrap 三元在水平缺省档照 wrap 原值")
        s.destroy()
    }

    function test_defaultGapIsTight() {
        // tight 令牌 = 8（semi.css:20307 的 column-gap 实值）；缺省水平档吃它
        const s = make("Space { Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 14 } }")
        wait(20)
        compare(s.horizontalGap, 8)
        const k = kids(s)
        compare(k.length, 2)
        compare(k[1].x, 30 + 8, "行内列距 = tight = 8")
        s.destroy()
    }

    // ---------------------------------------------------------------- spacing 三档
    function test_spacingStringTokens() {
        // semi.css:20307-20324：tight 8 / medium 16 / loose 24
        const t = make("Space { spacing: 'tight' }")
        wait(20)
        compare(t.horizontalGap, 8)
        t.destroy()

        const m = make("Space { spacing: 'medium' }")
        wait(20)
        compare(m.horizontalGap, 16, "medium = $spacing-space-medium = base = 16")
        m.destroy()

        const l = make("Space { spacing: 'loose' }")
        wait(20)
        compare(l.horizontalGap, 24, "loose = $spacing-space-loose = 24")
        l.destroy()
    }

    function test_spacingUnknownStringGivesNoGap() {
        // index.tsx:66-77 只在三档命中时挂类名 ⇒ 未知串一条 gap 规则都没有 ⇒ 0
        const s = make("Space { spacing: 'banana'; Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 10 } }")
        wait(20)
        compare(s.horizontalGap, 0)
        compare(kids(s)[1].x, 30, "没有 gap 规则 ⇒ 子项贴在一起")
        s.destroy()
    }

    function test_spacingNumberIsPx() {
        // index.tsx:62-64：number 档 rowGap / columnGap 同值
        const s = make("Space { spacing: 20; Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 14 } }")
        wait(20)
        compare(s.horizontalGap, 20)
        compare(kids(s)[1].x, 50, "水平列距 20")
        s.vertical = true
        wait(60)
        compare(s.verticalGap, 20, "number 档垂直轴同值")
        compare(kids(s)[1].y, 10 + 20, "垂直行距 20")
        s.destroy()
    }

    function test_spacingArraySplitsAxes() {
        // index.tsx:66-77：数组档 [0] 进列距（horizontal）、[1] 进行距（vertical）
        const s = make("Space { spacing: [12, 34]; Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 14 } }")
        wait(20)
        compare(s.horizontalGap, 12, "数组档索引 0 = 水平列距")
        compare(kids(s)[1].x, 42)
        s.vertical = true
        wait(60)
        compare(s.verticalGap, 34, "数组档索引 1 = 垂直行距")
        compare(kids(s)[1].y, 44, "10 + 34")
        s.destroy()
    }

    function test_spacingArrayMixedStringAndNumber() {
        // 数组档里字符串与 number 混用各走各的解析
        const s = make("Space { spacing: ['medium', 5] }")
        wait(20)
        compare(s.horizontalGap, 16, "字符串档走令牌")
        s.vertical = true
        wait(60)
        compare(s.verticalGap, 5, "number 档当 px")
        s.destroy()
    }

    function test_spacingArrayMissingSlotIsZero() {
        // 缺格 ⇒ 该轴没有 gap 规则 ⇒ 0（不是 tight）
        const s = make("Space { spacing: [8]; Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 14 } }")
        wait(20)
        compare(s.horizontalGap, 8)
        compare(s.verticalGap, 0, "数组缺第二格 ⇒ 垂直轴无规则")
        s.vertical = true
        wait(60)
        compare(kids(s)[1].y, 10, "零行距 ⇒ 直接贴着")
        s.destroy()
    }

    function test_spacingUndefinedAndNull() {
        // React defaultProps 只补 undefined（⇒ 'tight'）；null 与非 string/number/array
        // 三支判据都不命中 ⇒ 0。几何断言跟着走，钉住 onSpacingChanged 真的重排了 ——
        // 定宽是必须的：不定宽时宽度跟着隐式宽（含 gap）走，onWidthChanged 会把这一路盖掉
        const s = make("Space { Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 10 } }")
        wait(20)
        s.width = 300
        wait(20)
        compare(kids(s)[1].x, 38, "缺省 tight：30 + 8")
        s.spacing = undefined
        wait(20)
        compare(s.horizontalGap, 8, "undefined ⇒ defaultProps 补 tight")
        compare(kids(s)[1].x, 38)
        s.spacing = null
        wait(20)
        compare(s.horizontalGap, 0, "null ⇒ 没有 gap 规则")
        compare(kids(s)[1].x, 30, "零 gap 真的重排到贴在一起")
        s.spacing = true
        wait(20)
        compare(s.horizontalGap, 0, "非 string/number/array ⇒ 同样没有 gap 规则")
        compare(kids(s)[1].x, 30)
        s.destroy()
    }

    // ---------------------------------------------------------------- 别名
    function test_spaceAlias() {
        // 本库既有调用点的 `space: 8` 语义等于官方 number 档
        const s = make("Space { space: 20; Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 10 } }")
        wait(20)
        compare(s.spacing, 20)
        compare(s.horizontalGap, 20)
        compare(kids(s)[1].x, 50)
        s.destroy()
    }

    // ---------------------------------------------------------------- vertical
    function test_verticalStacksChildren() {
        // 垂直档：y 逐个叠 verticalGap；跨轴（x）按缺省 align center 摆在内容宽内
        const s = make("Space { vertical: true; Rectangle { width: 30; height: 20 }"
            + " Rectangle { width: 30; height: 20 } Rectangle { width: 50; height: 20 } }")
        wait(60)
        const k = kids(s)
        compare(k.length, 3)
        compare(k[0].y, 0)
        compare(k[1].y, 28, "20 + tight 8")
        compare(k[2].y, 56)
        compare(k[0].x, 10, "内容宽 50，30 宽的子项居中 ⇒ (50-30)/2")
        compare(k[1].x, 10)
        compare(k[2].x, 0, "最宽子项自己顶到边上")
        compare(s.lineStarts.length, 0, "垂直档没有换行概念")
        s.destroy()
    }

    function test_relayoutOnVerticalToggle() {
        // 同一份 children 在水平 ⇄ 垂直间来回排（两趟排布没有搬运宿主，只有坐标重写）
        const s = make("Space { Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 14 } }")
        wait(20)
        let k = kids(s)
        compare(k[1].x, 38, "水平：30 + 8")
        compare(k[0].y, 2, "水平：行高 14，10 高的居中 ⇒ (14-10)/2")
        compare(k[1].y, 0)

        s.vertical = true
        wait(60)
        k = kids(s)
        compare(k[1].y, 18, "垂直：10 + 8")
        compare(k[0].x, 10, "垂直：(50-30)/2")
        compare(k[1].x, 0)

        s.vertical = false
        wait(60)
        k = kids(s)
        compare(k[1].x, 38, "切回水平列距恢复")
        compare(k[0].y, 2, "行内居中恢复")

        // 单子项档：宽度（一行宽 = 最宽子项）与高度在两档间完全同值 ⇒
        // 既没有 widthChanged 也没有 implicitHeight 变化，只有 onVerticalChanged 能喊重排
        const one = make("Space { Rectangle { width: 50; height: 20 } }")
        wait(20)
        compare(one.lineStarts.length, 1, "水平档恒单行")
        one.vertical = true
        wait(60)
        compare(one.lineStarts.length, 0, "垂直档行名单清空（没别的信号可借）")
        one.destroy()
        s.destroy()
    }

    // ---------------------------------------------------------------- align
    function test_alignHorizontalThreeTiers() {
        // 缺省 center，再走 start / end（行高 = 最高子项 60）
        const s = make("Space { Rectangle { width: 30; height: 20 }"
            + " Rectangle { width: 30; height: 60 } Rectangle { width: 30; height: 40 } }")
        wait(20)
        let k = kids(s)
        compare(k[0].y, 20, "center：(60-20)/2")
        compare(k[1].y, 0)
        compare(k[2].y, 10, "center：(60-40)/2")

        s.align = "start"
        wait(20)
        k = kids(s)
        compare(k[0].y, 0, "start = flex-start = 行顶")
        compare(k[1].y, 0)
        compare(k[2].y, 0)

        s.align = "end"
        wait(20)
        k = kids(s)
        compare(k[0].y, 40, "end = flex-end = 行底")
        compare(k[1].y, 0)
        compare(k[2].y, 20)
        s.destroy()
    }

    function test_alignFourTokensExposed() {
        // 官方四档 start/center/end/baseline，缺省 center；端口原样暴露
        const s = make("Space { }")
        wait(20)
        compare(s.align, "center")
        s.align = "start"
        compare(s.align, "start")
        s.align = "center"
        compare(s.align, "center")
        s.align = "end"
        compare(s.align, "end")
        s.align = "baseline"
        compare(s.align, "baseline")
        s.destroy()
    }

    function test_alignUnknownBehavesAsStart() {
        // 未知值官方类名不命中 ⇒ 浏览器 stretch，端口按 start 落（文件头取舍）。
        // 期望与 start 档相同、且行高仍是内容高
        const s = make("Space { align: 'banana'; Rectangle { width: 30; height: 20 }"
            + " Rectangle { width: 30; height: 60 } Rectangle { width: 30; height: 40 } }")
        wait(20)
        const k = kids(s)
        compare(k[0].y, 0, "未知档不重排位移，与 start 同值")
        compare(k[1].y, 0)
        compare(k[2].y, 0)
        s.destroy()
    }

    function test_alignBaselineDeclaredOffsets() {
        // baseline：行内各子项 y = maxB - b_i；行高 = maxB + max(h_i - b_i)。
        // 两个子项直接声明 baselineOffset（无 Text 后代 ⇒ 走子项自己的基线）
        const s = make("Space { align: 'baseline';"
            + " Item { width: 50; height: 60; baselineOffset: 30 }"
            + " Item { width: 40; height: 40; baselineOffset: 50 } }")
        wait(20)
        const k = kids(s)
        compare(k[0].y, 20, "maxB 50 - 30")
        compare(k[1].y, 0, "自己就是 maxB")
        compare(s.layoutHeight, 80, "50 + max(60-30, 40-50)")
        compare(s.implicitHeight, 80)
        s.destroy()
    }

    function test_alignBaselineFindsTextDescendant() {
        // 浏览器基线取首行文本：QML 落法是「后代第一个可见 Text 的
        // mapToItem 位移 + Text.baselineOffset（Qt 自动维护）」。
        // 期望值由用例自己摸 Text 算出，不走组件的 baselineOf。
        const s = make("Space { align: 'baseline';"
            + " Rectangle { width: 80; height: 100; border.color: 'red';"
            + "   Text { anchors.centerIn: parent; text: '文本' } }"
            + " Item { width: 40; height: 20; baselineOffset: 0 } }")
        wait(60)
        const k = kids(s)
        compare(k.length, 2)
        const text = k[0].children[0]
        verify(text !== undefined && text !== null, "盒子里有 Text 后代")
        const bC = text.mapToItem(k[0], 0, 0).y + text.baselineOffset
        verify(bC > 0, "Text 基线为正（有实际排版）")
        compare(k[0].y, 0, "文本盒贡献 maxB ⇒ 自己顶行")
        compare(k[1].y, bC, "无基线声明的子项被推到共同基线上")

        // 盒内 Text 挪位（盒自己没变寸、Text 的 baselineOffset 也没变）⇒
        // 只有 childrenRect 这一路能喊重排，基线要跟着走
        text.anchors.verticalCenterOffset = 20
        wait(60)
        const bC2 = text.mapToItem(k[0], 0, 0).y + text.baselineOffset
        verify(bC2 !== bC, "挪动确实改变了基线")
        compare(k[1].y, bC2, "基线跟到新位置")
        s.destroy()
    }

    function test_alignBaselineTracksTextFontChange() {
        // Text 定宽定高、x/y 不动 ⇒ 变字号时只有 baselineOffset 会动，
        // 子项级的宽高/显隐信号一个都不响 —— 只有 baseline 档的每帧节拍接得住
        const s = make("Space { align: 'baseline';"
            + " Text { width: 60; height: 30; text: '文本'; font.pixelSize: 12 }"
            + " Item { width: 40; height: 20; baselineOffset: 0 } }")
        wait(60)
        let k = kids(s)
        const b0 = k[0].baselineOffset
        verify(b0 > 0, "Text 基线已排出版")
        compare(k[1].y, b0, "直接子项 Text 自己的基线就是共同基线")
        k[0].font.pixelSize = 20
        wait(60)
        k = kids(s)
        const b1 = k[0].baselineOffset
        verify(b1 !== b0, "字号变了基线值确实变了")
        compare(k[1].y, b1, "节拍重排吃到了新基线")
        s.destroy()
    }

    function test_alignVerticalEndPutsChildrenRight() {
        // 垂直档 align 管列内横向；end = flex-end = 靠内容宽右侧
        const s = make("Space { vertical: true; align: 'end';"
            + " Rectangle { width: 30; height: 20 } Rectangle { width: 50; height: 20 } }")
        wait(20)
        const k = kids(s)
        compare(k[0].x, 20, "内容宽 50 - 30")
        compare(k[1].x, 0)
        s.destroy()
    }

    // ---------------------------------------------------------------- wrap
    function test_wrapBreaksLinesAtWidth() {
        // width 120、子项 50 宽、tight 8：x 放到 58 后第三枚 116+50 > 120 ⇒ 换行
        const s = make("Space { width: 120; wrap: true;"
            + " Rectangle { width: 50; height: 20 } Rectangle { width: 50; height: 20 }"
            + " Rectangle { width: 50; height: 20 } Rectangle { width: 50; height: 20 } }")
        wait(60)
        compare(s.effectiveWrap, true)
        const k = kids(s)
        compare(k[0].x, 0)
        compare(k[1].x, 58, "50 + 8")
        compare(k[2].x, 0, "放不下 ⇒ 第二行行首")
        compare(k[3].x, 58)
        compare(k[0].y, 0)
        compare(k[2].y, 28, "行距 verticalGap 8：行高 20 + 8")
        compare(s.lineStarts.length, 2, "两行")
        compare(s.lineStarts[1], 2, "第二行从第 3 枚起")
        compare(s.layoutHeight, 48, "20 + 8 + 20")
        s.destroy()
    }

    function test_wrapInertWhenVertical() {
        // 官方 index.tsx:57 —— `wrap && vertical ? false : wrap`，垂直档不吃换行
        const s = make("Space { wrap: true; vertical: true;"
            + " Rectangle { width: 50; height: 20 } Rectangle { width: 50; height: 20 }"
            + " Rectangle { width: 50; height: 20 } }")
        wait(60)
        compare(s.effectiveWrap, false, "垂直档 wrap 被强制关掉")
        let k = kids(s)
        compare(k[1].y, 28, "照样竖着叠，不换行")
        compare(k[2].y, 56)
        compare(k[0].x, 0, "没给宽 ⇒ 跨轴 = 最宽子项 50，居中即顶到边")
        compare(s.lineStarts.length, 0)
        s.width = 60
        wait(60)
        k = kids(s)
        compare(k[0].x, 5, "给宽后跨轴用 width 居中：(60-50)/2")
        s.destroy()
    }

    function test_wrapOffIgnoresWidth() {
        // wrap 缺省 false：宽度再窄也一行排到底（overflow 由调用方裁）
        const s = make("Space { width: 60;"
            + " Rectangle { width: 50; height: 20 } Rectangle { width: 50; height: 20 }"
            + " Rectangle { width: 50; height: 20 } Rectangle { width: 50; height: 20 } }")
        wait(60)
        const k = kids(s)
        compare(k[1].x, 58)
        compare(k[2].x, 116, "越界也不断行")
        compare(k[3].x, 174)
        compare(k[2].y, 0)
        compare(s.lineStarts.length, 1, "永远单行")
        s.destroy()
    }

    function test_wrapTogglesAtRuntime() {
        // 建成后再给宽、再开 wrap —— 靠 onWidthChanged / onWrapChanged 两条触发重排
        const s = make("Space { wrap: false;"
            + " Rectangle { width: 50; height: 20 } Rectangle { width: 50; height: 20 }"
            + " Rectangle { width: 50; height: 20 } Rectangle { width: 50; height: 20 } }")
        wait(20)
        let k = kids(s)
        compare(k[3].x, 174, "没给宽 = 全塞一行")
        s.width = 120
        wait(20)
        k = kids(s)
        compare(k[3].x, 174, "宽度够了但 wrap 还没开 ⇒ 仍单行")
        s.wrap = true
        wait(60)
        k = kids(s)
        compare(k[1].x, 58, "开 wrap 后按 120 的可用宽分行")
        compare(k[2].x, 0)
        compare(s.lineStarts.length, 2)
        s.destroy()
    }

    function test_wrapArrayRowGapUsesVerticalAxis() {
        // 官方 间距尺寸 array 档：spacing=[8, 16] + wrap ⇒ 行距吃数组第二格（16）、
        // 列距吃第一格（8）—— 定宽 + wrap 是 vgap 唯一露头的地方
        const s = make("Space { width: 120; wrap: true; spacing: [8, 16];"
            + " Rectangle { width: 50; height: 20 } Rectangle { width: 50; height: 20 }"
            + " Rectangle { width: 50; height: 20 } }")
        wait(60)
        const k = kids(s)
        compare(k[1].x, 58, "列距吃第一格 8：50 + 8")
        compare(k[2].x, 0, "116 + 50 > 120 ⇒ 换行")
        compare(k[2].y, 36, "行距吃第二格 16：20 + 16（不是 20 + 8）")
        s.destroy()
    }

    function test_wrapNeverWrapsLineHeadEvenWhenOversized() {
        // 行首项永不换：150 > 120 的首项仍独占第一行；跟班的第二枚在 158 处
        // 放不下 ⇒ 照常换到第二行（flex 对首项只豁免「不被踢走」，不豁免后续判行）
        const s = make("Space { width: 120; wrap: true;"
            + " Rectangle { width: 150; height: 20 } Rectangle { width: 50; height: 20 } }")
        wait(60)
        const k = kids(s)
        compare(k[0].x, 0, "超宽首项不自换、留在第一行行首")
        compare(k[1].x, 0, "158 + 50 > 120 ⇒ 第二枚换到第二行")
        compare(k[1].y, 28, "行高 20 + 行距 8")
        compare(s.lineStarts.length, 2, "首项本身不触发换行 ⇒ 起点只有两个")
        s.destroy()
    }

    // ---------------------------------------------------------------- 子项监视
    function test_childResizeTriggersRelayout() {
        // 官方子项变宽浏览器会重排；端口靠挂在子项上的 width/height 监视。
        // Space 定宽是必须的：不定宽时隐式宽跟着子项走，onWidthChanged 会把监视盖掉
        const s = make("Space { width: 300; Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 10 } }")
        wait(20)
        const k = kids(s)
        compare(k[1].x, 38)
        k[0].width = 70
        wait(60)
        compare(k[1].x, 78, "70 + 8")
        k[0].height = 40
        wait(60)
        compare(k[1].y, 15, "行高变 40 ⇒ 10 高的居中子项落到 (40-10)/2")
        s.destroy()
    }

    function test_childVisibleFlipRerelayouts() {
        // 隐藏子项立刻出排（display:none 口径）；再显形要有人喊重排。
        // 定宽同上：挡住 onWidthChanged 的旁路
        const s = make("Space { width: 300; Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 40; height: 10 }"
            + " Rectangle { width: 50; height: 10 } }")
        wait(20)
        const k = kids(s)
        compare(k.length, 3)
        compare(s.implicitWidth, 30 + 8 + 40 + 8 + 50)
        k[1].visible = false
        wait(60)
        compare(kids(s).length, 2)
        compare(s.implicitWidth, 30 + 8 + 50, "隐藏项不占位")
        compare(kids(s)[1].x, 38, "第三枚顶上来")
        k[1].visible = true
        wait(60)
        compare(kids(s).length, 3)
        compare(s.implicitWidth, 30 + 8 + 40 + 8 + 50, "显形后恢复占位")
        s.destroy()
    }

    function test_hiddenChildAtCreationSkipped() {
        // 建成时就 visible:false 的子项从一开始就不进排布
        const s = make("Space { Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 40; height: 10; visible: false }"
            + " Rectangle { width: 50; height: 10 } }")
        wait(20)
        const k = kids(s)
        compare(k.length, 2)
        compare(k[1].x, 38, "30 + 8：中间的隐藏项不占槽")
        compare(s.implicitWidth, 88)
        s.destroy()
    }

    function test_repeaterShellSkipped() {
        // Qt 6.11 起 Repeater 自己也是个 Item：空壳不入排（官方 flatten 没有这个节点）
        const s = make("Space { Repeater { model: 3;"
            + " delegate: Rectangle { width: 20; height: 10 } } }")
        wait(60)
        const k = kids(s)
        compare(k.length, 3, "三个代理")
        compare(k[0].x, 0, "空壳不占槽、不吃间距")
        compare(k[1].x, 28)
        compare(k[2].x, 56)
        compare(s.implicitWidth, 20 * 3 + 8 * 2)
        s.destroy()
    }

    // ---------------------------------------------------------------- 隐式尺寸
    function test_implicitSizesFollowGeometry() {
        // 水平：宽 = 全塞一行、高 = 行高（最高子项）；垂直反过来
        const s = make("Space { Rectangle { width: 30; height: 10 }"
            + " Rectangle { width: 50; height: 14 } }")
        wait(20)
        compare(s.implicitWidth, 30 + 8 + 50)
        compare(s.implicitHeight, 14, "行内居中不吃额外高")
        s.vertical = true
        wait(60)
        compare(s.implicitWidth, 50, "垂直档跨轴 = 最宽子项")
        compare(s.implicitHeight, 10 + 8 + 14)
        s.destroy()
    }
}
