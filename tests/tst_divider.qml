import QtQuick
import QtTest
import Semi

// Divider 分割线。规格照 packages/semi-ui/divider/index.tsx（DividerProps 六条）
// + semi-foundation/divider/{divider.scss,variables.scss}。
//
// 端口口径（完整清单在 src/Divider.qml 文件头）：
//   · `vertical: bool` 承接官方 `layout: 'horizontal'|'vertical'`（两值方向，QML 用 bool）；
//   · 官方 children 一个 ReactNode 槽，端口拆 `text`（字符串档，吃 `-inner-text` 的
//     左右 8px 内边距 + 字重 600 + 正文 14px）与 `content`（Component 档，裸渲染）；
//   · `margin` 吃进 implicit 尺寸（QML 无外边距概念）：水平上下、垂直左右，
//     缺省 variables.scss 的 1px —— 所以水平线 implicitHeight 是 3（1 线 + 上下各 1）；
//   · 垂直档高写死 20px（$height-divider_vertical）；
//   · **children 只在水平档渲染**（index.tsx:63），垂直 + 内容 = 内容丢弃、只画线；
//   · 虚线用 Canvas + setLineDash（QML Rectangle 无 border-style），段长 3px = 3×线宽。
//
// 断言一律走端口自己算出来的几何，不写死字体度量；颜色断言用浅色档下互不相同的令牌。
TestCase {
    id: testCase

    name: "Divider"
    when: windowShown
    width: 600
    height: 400

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "divider")
    }

    // ---------------------------------------------------------------- 几何
    function test_horizontalDefaults() {
        // variables.scss：水平档 margin 上下各 1px、线 1px ⇒ 盒高 3；线满宽
        const d = make("Divider { width: 200 }")
        wait(20)
        compare(d.vertical, false)
        compare(d.implicitHeight, 3, "1px 线 + 上下各 1px 缺省 margin")
        compare(d.width, 200, "显式宽顶掉组件的吃满绑定")

        const line = testCase.findChild(d, "dividerLine")
        verify(line !== null, "实线渲染")
        compare(line.height, 1, "线厚 1px（$width-divider-border）")
        compare(line.width, d.width, "线满宽")
        compare(line.y, 1, "margin 上下各 1 ⇒ 线在 y=1")
        compare(line.color.toString(), Theme.current.colorBorder.toString(),
            "线色恒 --semi-color-border（官方无 color prop）")
        d.destroy()
    }

    function test_horizontalFillsParentWidth() {
        // 官方 -horizontal { width: 100% } —— 不给显式宽时吃满父宽。
        // 前提是父块有实宽：Column 的隐式宽吃子项、子项(水平线)隐式宽又是 0 ⇒ 链条成环，
        // 所以这里放进一个定宽 Item（同官方 block 上下文）
        const host = make("Item { width: 320; height: 60; Divider { } }")
        wait(20)
        const d = host.children[0]
        compare(d.width, 320, "吃满父宽（官方 width:100%）")
        const line = testCase.findChild(d, "dividerLine")
        compare(line.width, 320, "线跟着满宽")
        host.destroy()
    }

    function test_verticalDefaults() {
        // variables.scss：垂直档 margin 左右各 1px、线 1px ⇒ 盒宽 3；高写死 20
        const d = make("Divider { vertical: true }")
        wait(20)
        compare(d.implicitWidth, 3, "1px 线 + 左右各 1px 缺省 margin")
        compare(d.implicitHeight, 20, "$height-divider_vertical 写死 20px")

        const line = testCase.findChild(d, "dividerLine")
        verify(line !== null)
        compare(line.width, 1, "垂直线宽 1px")
        compare(line.height, 20)
        compare(line.x, 1, "margin 左右各 1 ⇒ 线在 x=1")
        d.destroy()
    }

    function test_marginNumberAndString() {
        // 官方 margin: number | string —— number 当 px、"12px" 取数值段；
        // 水平档吃上下 ⇒ 盒高 = 12 + 1 + 12 = 25
        const n = make("Divider { width: 200; margin: 12 }")
        wait(20)
        compare(n.implicitHeight, 25, "number 档：上 12 + 线 1 + 下 12")
        const nLine = testCase.findChild(n, "dividerLine")
        compare(nLine.y, 12, "线被 margin 下推到 y=12")
        n.destroy()

        const s = make("Divider { width: 200; margin: '12px' }")
        wait(20)
        compare(s.implicitHeight, 25, "string 档取数值段，与 number 同值")
        s.destroy()

        // 垂直档 margin 吃左右
        const v = make("Divider { vertical: true; margin: 8 }")
        wait(20)
        compare(v.implicitWidth, 17, "垂直档：左 8 + 线 1 + 右 8")
        const vLine = testCase.findChild(v, "dividerLine")
        compare(vLine.x, 8, "线被 margin 右推到 x=8")
        v.destroy()

        // 非法 string 回落到缺省 1px（CSS 非法值被丢弃 ⇒ 类 margin 1px 生效）
        const bad = make("Divider { width: 200; margin: 'nope' }")
        wait(20)
        compare(bad.implicitHeight, 3, "非法 string 回落缺省 1px")
        bad.destroy()
    }

    // ---------------------------------------------------------------- 虚线
    function test_dashedUsesCanvas() {
        // QML 的 Rectangle 画不出虚线（border 无 style），端口用 Canvas + setLineDash
        const solid = make("Divider { width: 200 }")
        wait(20)
        const solidLine = testCase.findChild(solid, "dividerLine")
        const solidDash = testCase.findChild(solid, "dividerDashLine")
        compare(solidLine.visible, true, "实线档 Rectangle 可见")
        verify(solidDash === null || solidDash.visible === false, "实线档 Canvas 不可见")
        solid.destroy()

        const dashed = make("Divider { width: 200; dashed: true }")
        wait(20)
        const dLine = testCase.findChild(dashed, "dividerLine")
        const dDash = testCase.findChild(dashed, "dividerDashLine")
        compare(dLine.visible, false, "虚线档 Rectangle 隐去")
        verify(dDash !== null, "虚线档 Canvas 渲染")
        compare(dDash.visible, true)
        compare(dDash.height, 1, "虚线 Canvas 与线同高")
        dashed.destroy()
    }

    function test_verticalDashedUsesCanvas() {
        const d = make("Divider { vertical: true; dashed: true }")
        wait(20)
        const dash = testCase.findChild(d, "dividerDashLine")
        verify(dash !== null, "垂直虚线也走 Canvas")
        compare(dash.width, 1)
        compare(dash.height, 20)
        d.destroy()
    }

    function test_dashedRendersWhenVisible() {
        // setLineDash 的段长读不回 Canvas；grabImage 在 offscreen 与 cocoa 都不合成
        // Canvas 层（实测两边都扫不出透明像素，见坑 124）⇒ 像素断言两边都够不到，
        // 虚线的视觉正确性由 gallery 截图复核兜底（div2.png 的虚线节）。
        // 这里只钉「虚线档 Canvas 真的存在且可见」这一层结构事实。
        const d = make("Divider { width: 200; dashed: true }")
        wait(20)
        const dash = testCase.findChild(d, "dividerDashLine")
        verify(dash !== null, "虚线档 Canvas 渲染")
        compare(dash.visible, true)
        compare(dash.width, 200, "虚线 Canvas 与线同宽")
        d.destroy()
    }

    // ---------------------------------------------------------------- 带内容
    function test_textUsesInnerTextStyle() {
        // 官方 _inner-text：padding 0 8 + font-weight 600 + 继承正文 14px + text-0
        // Layout.* 是附着属性、findChild 返回的 QObject 上读不到 ⇒ 断实际排布：
        // 文字左沿与左线右沿的距离就是那 8px 内边距
        const d = make("Divider { width: 300; text: '或者' }")
        wait(20)
        compare(d.withContent, true)
        const t = testCase.findChild(d, "dividerText")
        const before = testCase.findChild(d, "dividerLineBefore")
        verify(t !== null && before !== null)
        compare(t.text, "或者")
        compare(t.font.weight, Font.DemiBold, "$font-divider_text-weight: 600")
        compare(t.font.pixelSize, Theme.current.fontSizeRegular, "继承正文 14px（无 -inner-text 字号覆盖）")
        compare(t.color.toString(), Theme.current.colorText0.toString(), "$color-divider_text-default = text-0")
        compare(t.x - (before.x + before.width), 8, "$spacing-divider_inner_text-paddingLeft")
        const after = testCase.findChild(d, "dividerLineAfter")
        compare(t.x + t.width + 8, after.x, "$spacing-divider_inner_text-paddingRight 对称")
        d.destroy()
    }

    function test_alignLeftFixesBeforeLine() {
        // divider.scss -with-text-left：::before 定宽 40px、::after 吃满剩余
        const d = make("Divider { width: 300; align: 'left'; text: '居左' }")
        wait(20)
        const before = testCase.findChild(d, "dividerLineBefore")
        const after = testCase.findChild(d, "dividerLineAfter")
        verify(before !== null && after !== null)
        compare(before.width, 40, "$width-divider_inner_text_left_line 定宽")
        verify(after.width > 40, "另一侧吃满剩余（flex: 1）")
        d.destroy()
    }

    function test_alignRightFixesAfterLine() {
        const d = make("Divider { width: 300; align: 'right'; text: '居右' }")
        wait(20)
        const before = testCase.findChild(d, "dividerLineBefore")
        const after = testCase.findChild(d, "dividerLineAfter")
        verify(before !== null && after !== null)
        compare(after.width, 40, "$width-divider_inner_text_right_line 定宽")
        verify(before.width > 40, "另一侧吃满剩余")
        d.destroy()
    }

    function test_alignCenterSplitsEvenly() {
        // 缺省 center：两侧各吃一半剩余 —— 剩余宽为奇数时取整差 1px，容 ±1
        const d = make("Divider { width: 300; text: '居中' }")
        wait(20)
        const before = testCase.findChild(d, "dividerLineBefore")
        const after = testCase.findChild(d, "dividerLineAfter")
        verify(before !== null && after !== null)
        verify(Math.abs(before.width - after.width) <= 1, "center 档两侧等宽（容取整 ±1）")
        verify(before.width > 0, "两侧都有实宽")
        d.destroy()
    }

    // ---------------------------------------------------------------- 垂直档丢内容
    function test_verticalDropsContent() {
        // index.tsx:63 —— children 只在 `layout === 'horizontal'` 时渲染；
        // 垂直档 + 内容 = 内容被丢弃，只画线。照抄不修。
        const d = make("Divider { vertical: true; text: '不该出现' }")
        wait(20)
        compare(d.withContent, false, "垂直档 withContent 恒假")
        const row = testCase.findChild(d, "dividerContentRow")
        verify(row === null || row.visible === false, "内容行不渲染")
        const line = testCase.findChild(d, "dividerLine")
        verify(line !== null && line.visible, "线照画")
        d.destroy()
    }

    Component {
        id: textComp

        Text {
            text: "节点档"
            color: Theme.current.colorText0
        }
    }

    function test_contentLoaderUsesComponent() {
        // content 档走 Loader；sourceComponent 接上正规 Component 就能装载
        const d = make("Divider { width: 300; content: textComp }")
        wait(30)
        const loader = testCase.findChild(d, "dividerContentLoader")
        verify(loader !== null)
        verify(loader.item !== null, "Component 装载成功")
        compare(loader.visible, true)
        // 字符串档不该同时出现
        const t = testCase.findChild(d, "dividerText")
        verify(t === null || t.visible === false, "给了 content 就不走 text 档")
        d.destroy()
    }

    function test_textAndContentAreExclusive() {
        // text 与 content 互斥的判定在 hasContent：给了 text 就走字符串档，
        // Loader 因 content 为 null 而不装载
        const d = make("Divider { width: 300; text: '纯文字' }")
        wait(20)
        const loader = testCase.findChild(d, "dividerContentLoader")
        verify(loader === null || loader.item === null, "纯 text 档不装载 content")
        d.destroy()
    }

    // ---------------------------------------------------------------- 线色
    function test_lineColorIsBorderToken() {
        // 官方分割线颜色恒 --semi-color-border，无 color prop；端口 lineColor 收成只读
        const d = make("Divider { }")
        wait(20)
        compare(d.lineColor.toString(), Theme.current.colorBorder.toString())
        d.destroy()
    }
}
