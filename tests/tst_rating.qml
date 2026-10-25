import QtQuick
import QtTest
import Semi

// Rating 对齐官方后的回归测试。
//
// 规格来源：semi-ui/rating/index.tsx（属性面与受控语义）、
// semi-foundation/rating/foundation.ts（悬浮 / 点击 / 键盘的算法）、
// semi-ui/rating/item.tsx（单层裁切的 DOM 与 isHalf / firstWidth）、
// semi-foundation/rating/rating.scss + variables.scss（24 / 16 的格子、6 的间隙、
// yellow-5 与 fill-0、2px 焦点环）。
//
// 断言尽量落在渲染出来的东西上：某颗星里那枚 Icon 的颜色、裁切层的宽度、
// 星在控件坐标系里的 x、焦点环的位置与尺寸，而不是中间的 readonly 属性。
TestCase {
    id: testCase

    name: "Rating"
    when: windowShown
    width: 900
    height: 900

    property var changes: []
    property var hovers: []
    property var keys: []
    property var focusLog: []
    property var ctrlValue: 0       // 受控用例把它绑给 Rating.value

    // 官方 自定义 一节的 character={<IconLikeHeart/>}
    property var likeHeart: Component {
        Icon { name: "like_heart"; size: 24 }
    }

    function init() {
        // 见 PROGRESS.md 坑 4 / 坑 70
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
        changes = []
        hovers = []
        keys = []
        focusLog = []
        ctrlValue = 0
        // 合成指针停在上一条用例的位置，新建的探针就会一上来是悬浮态
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(20)
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    function walk(root, name, out) {
        out = out === undefined ? [] : out
        const kids = root.children
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].objectName === name)
                out.push(kids[i])
            walk(kids[i], name, out)
        }
        return out
    }

    // Repeater 按 model 顺序创建，所以这里就是「从左到右第 i 颗星」
    function star(r, i) {
        const list = walk(r, "ratingStar")
        compare(list.length, r.count)
        return list[i]
    }

    // 那颗星的下层图形（整星那层）里的三个候选绘制项
    function baseGlyph(r, i) {
        return walk(star(r, i), "ratingStarBase")[0]
    }

    function icon(r, i) {
        return baseGlyph(r, i).children[0]
    }

    function fillLayer(r, i) {
        return walk(star(r, i), "ratingStarFill")[0]
    }

    function fillGlyph(r, i) {
        return fillLayer(r, i).children[0]
    }

    function fillIcon(r, i) {
        return fillGlyph(r, i).children[0]
    }

    function ring(r) {
        return walk(r, "ratingFocusRing")[0]
    }

    // 点在第 index 颗星内、横向 localX 处。官方的 click 打在 wrapper 上，
    // 坐标是相对那一颗的；QtTest 的定位重载是 (item, x, y, button, modifiers)（坑 70）。
    function clickStar(r, index, localX) {
        mouseClick(star(r, index), localX, r.itemSize / 2, Qt.LeftButton, Qt.NoModifier)
        wait(20)
    }

    // 合成移动偶尔要两拍才落到新挂上的处理程序上（同坑 67），这里只等「预览值真的变了」
    function hoverStar(r, index, localX, expected) {
        mouseMove(star(r, index), localX, r.itemSize / 2)
        let tries = 0
        while (r.displayValue !== expected && tries < 10) {
            wait(20)
            mouseMove(star(r, index), localX, r.itemSize / 2)
            ++tries
        }
        compare(r.displayValue, expected, "指针没落到第 " + index + " 颗星上")
    }

    function unhover() {
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(40)
    }

    // 从第 index 颗左边往回 3px，即两颗星之间那 6px 间隙里
    function gapPoint(r, index) {
        return star(r, index).mapToItem(testCase, -3, r.itemSize / 2)
    }

    // ---------------- 尺寸与几何（variables.scss + 官方 DOM 实测） ----------------

    function test_defaultCellIs24With6Gap() {
        const r = make("Rating { }")
        compare(r.itemSize, 24)                         // $width-rating_item_default
        compare(r.itemSpacing, 6)                       // $spacing-rating_item-marginRight
        compare(r.implicitHeight, 24)
        // ul 的盒子把末星的 margin-right 也算进内容宽：5×24 + 5×6 = 150（官方实测）
        compare(r.implicitWidth, 150)
        for (let i = 0; i < 5; ++i) {
            compare(star(r, i).width, 24)
            compare(star(r, i).height, 24)
            compare(star(r, i).mapToItem(r, 0, 0).x, i * 30)
        }
        r.destroy()
    }

    function test_smallCellIs16() {
        const r = make("Rating { size: 'small' }")
        compare(r.itemSize, 16)                         // $width-rating_item_small
        compare(r.implicitWidth, 110)                   // 5×16 + 5×6，官方实测 110
        compare(r.implicitHeight, 16)
        compare(star(r, 4).mapToItem(r, 0, 0).x, 4 * 22)
        compare(icon(r, 0).size, 16)
        r.destroy()
    }

    function test_numericSizeIsUsedAsCell() {
        // 官方 size 可以是 number，这时 li 的 width/height/fontSize 都取它，
        // 图标 size 走 'inherit'（item.tsx:171-176）
        const r = make("Rating { size: 48 }")
        compare(r.itemSize, 48)
        compare(r.implicitWidth, 5 * 54)
        compare(star(r, 1).width, 48)
        compare(icon(r, 1).size, 48)
        r.destroy()
    }

    function test_countDrivesStarCountAndWidth() {
        const r = make("Rating { count: 10; defaultValue: 6 }")
        compare(r.count, 10)
        compare(r.implicitWidth, 10 * 30)
        star(r, 9)
        compare(icon(r, 5).color.toString(), Theme.current.yellow[5].toString())
        compare(icon(r, 6).color.toString(), Theme.current.colorFill0.toString())
        r.destroy()
    }

    // ---------------- 填色（rating.scss:85-110） ----------------

    function test_filledStarsYellowEmptyStarsFill0() {
        const r = make("Rating { defaultValue: 2 }")
        for (let i = 0; i < 5; ++i) {
            const want = i < 2 ? Theme.current.yellow[5] : Theme.current.colorFill0
            compare(icon(r, i).color.toString(), want.toString(), "第 " + (i + 1) + " 颗星")
        }
        r.destroy()
    }

    function test_colorPropReplacesFilledColor() {
        // 官方 自定义 一节是 <Rating style={{color:'red'}} …/>，CSS 里靠 color: inherit
        const r = make("Rating { color: 'red'; defaultValue: 3 }")
        compare(icon(r, 0).color.toString(), "#ff0000")
        compare(icon(r, 3).color.toString(), Theme.current.colorFill0.toString())
        r.destroy()
    }

    function test_noOpacityChangeWhenDisabled() {
        // rating.scss 的 -disabled 只改 cursor 和 hover 缩放，没有 opacity
        const r = make("Rating { disabled: true; defaultValue: 3 }")
        compare(r.opacity, 1)
        compare(star(r, 0).opacity, 1)
        compare(icon(r, 2).color.toString(), Theme.current.yellow[5].toString())
        compare(icon(r, 3).color.toString(), Theme.current.colorFill0.toString())
        r.destroy()
    }

    // ---------------- 半星（item.tsx:162-163 + 官方 DOM 实测） ----------------

    function test_halfStarClipsAtLeftHalf() {
        const r = make("Rating { allowHalf: true; defaultValue: 3.5 }")
        // firstWidth = (1 - diff) * 100%：第 4 颗 diff = 0.5 → 12
        compare(fillLayer(r, 3).width, 12)
        compare(fillLayer(r, 3).visible, true)
        compare(fillLayer(r, 3).clip, true)
        // 裁切层里的图形仍然是整颗星，否则不是「裁」而是「缩」
        compare(fillLayer(r, 3).children[0].width, 24)
        compare(fillIcon(r, 3).color.toString(), Theme.current.yellow[5].toString())
        // 底层那颗半星要是空的（-half &-second 没有 color: inherit）
        compare(icon(r, 3).color.toString(), Theme.current.colorFill0.toString())
        compare(icon(r, 2).color.toString(), Theme.current.yellow[5].toString())
        // 裁切层只属于「差值在 0 与 1 之间」那一颗：左边那颗是满的（diff = -0.5）、
        // 右边那颗是空的（diff = 1.5），都不该露出来
        compare(fillLayer(r, 2).visible, false)
        compare(fillLayer(r, 4).visible, false)
        compare(fillLayer(r, 0).visible, false)
        r.destroy()
    }

    function test_fractionalValueDisplays() {
        // 官方 半星 小节第二行：allowHalf + 3.65，diff = 0.35 → (1-0.35)*24 = 15.6
        const r = make("Rating { allowHalf: true; defaultValue: 3.65; disabled: true }")
        fuzzyCompare(fillLayer(r, 3).width, 15.6, 0.001)
        compare(fillLayer(r, 3).visible, true)
        compare(icon(r, 4).color.toString(), Theme.current.colorFill0.toString())
        r.destroy()
    }

    function test_withoutAllowHalfNoClipLayer() {
        const r = make("Rating { defaultValue: 3.5 }")
        // 裁切宽度照算，但 allowHalf 关掉时整层不显示（rating.scss:99 opacity 0）
        compare(fillLayer(r, 3).visible, false)
        compare(fillLayer(r, 3).width, 12)
        compare(icon(r, 3).color.toString(), Theme.current.colorFill0.toString())
        r.destroy()
    }

    function test_halfPreviewCutsTheStar() {
        // 悬浮预览走同一套裁切：hover 第 3 颗左半 → displayValue 2.5
        const r = make("Rating { allowHalf: true; defaultValue: 0 }")
        hoverStar(r, 2, 4, 2.5)
        fuzzyCompare(fillLayer(r, 2).width, 12, 0.001)
        r.destroy()
    }

    // ---------------- 点击与清除（foundation.ts:98-109） ----------------

    function test_clickNotifiesAndCommitsWhenUncontrolled() {
        const r = make("Rating { defaultValue: 0; onChanged: (v) => testCase.changes.push(v) }")
        compare(changes.length, 0)
        clickStar(r, 2, 20)                     // 右半 → 整星 3
        compare(changes.length, 1)
        compare(changes[0], 3)
        compare(r.currentValue, 3)
        compare(r.value, undefined)             // 非受控：属性本身没被写
        compare(icon(r, 2).color.toString(), Theme.current.yellow[5].toString())
        r.destroy()
    }

    function test_clickHalfOnLeftHalf() {
        const r = make("Rating { allowHalf: true; defaultValue: 0 }")
        clickStar(r, 2, 4)                      // 左半 → 2.5
        compare(r.currentValue, 2.5)
        compare(fillLayer(r, 2).width, 12)
        clickStar(r, 2, 20)                     // 这颗的右半 → 3，不等于 2.5，所以不是清除
        compare(r.currentValue, 3)
        r.destroy()
    }

    function test_allowClearResetsToZero() {
        const r = make("Rating { defaultValue: 3; onChanged: (v) => testCase.changes.push(v) }")
        clickStar(r, 2, 20)                     // 又点第 3 颗 → 清除
        compare(r.currentValue, 0)
        compare(changes.length, 1)
        compare(changes[0], 0)
        compare(r._hoverValue, undefined)
        compare(r._clearedValue, 3)
        for (let i = 0; i < 5; ++i)
            compare(icon(r, i).color.toString(), Theme.current.colorFill0.toString())
        r.destroy()
    }

    function test_allowClearFalseKeepsValue() {
        const r = make("Rating { allowClear: false; defaultValue: 3 }")
        clickStar(r, 2, 20)
        compare(r.currentValue, 3)
        compare(r._clearedValue, null)
        compare(icon(r, 2).color.toString(), Theme.current.yellow[5].toString())
        r.destroy()
    }

    function test_gapClickDoesNothing() {
        // 官方的 click 只打在 wrapper（那一颗星本身）上，6px 间隙不属于任何一颗
        const r = make("Rating { defaultValue: 1 }")
        star(r, 1)                              // 先把星数断住，再取间隙坐标
        const p = gapPoint(r, 1)
        mouseClick(testCase, p.x, p.y, Qt.LeftButton, Qt.NoModifier)
        wait(20)
        compare(changes.length, 0)
        compare(r.currentValue, 1)
        r.destroy()
    }

    function test_controlledClickNotifiesButKeepsValue() {
        const r = make("Rating { value: testCase.ctrlValue; defaultValue: 0;"
                       + " onChanged: (v) => testCase.changes.push(v) }")
        clickStar(r, 3, 20)
        compare(changes.length, 1)              // 通知无条件发
        compare(changes[0], 4)
        compare(r.currentValue, 0)              // 页面没接，值不动
        testCase.ctrlValue = 4                  // 接住了才真的变
        wait(20)
        compare(r.currentValue, 4)
        compare(icon(r, 3).color.toString(), Theme.current.yellow[5].toString())
        r.destroy()
    }

    function test_controlledClickLeavesNoInternalValueBehind() {
        // 受控时不能顺手写 _inner，否则解除受控后会冒出用户没选过的值
        const r = make("Rating { value: 2; defaultValue: 0;"
                       + " onChanged: (v) => testCase.changes.push(v) }")
        clickStar(r, 4, 20)
        compare(r.currentValue, 2)
        compare(r._inner, 0)
        r.value = undefined
        compare(r.currentValue, 0)
        r.destroy()
    }

    // ---------------- 悬浮预览（foundation.ts:86-96 + index.tsx:283） ----------------

    function test_hoverShowsPreviewThenRestores() {
        const r = make("Rating { defaultValue: 1; onHoverChanged: (v) => testCase.hovers.push(v) }")
        compare(r.displayValue, 1)
        hoverStar(r, 3, 20, 4)
        compare(r.currentValue, 1)              // 预览不改已提交值
        compare(icon(r, 3).color.toString(), Theme.current.yellow[5].toString())
        compare(hovers[hovers.length - 1], 4)
        unhover()
        compare(r.displayValue, 1)
        compare(hovers[hovers.length - 1], undefined)   // 离开时通知 undefined
        r.destroy()
    }

    function test_hoverGapKeepsPreviousPreview() {
        // 间隙不落进任何一颗星的 mousemove，官方就保持上一个预览值
        const r = make("Rating { defaultValue: 0 }")
        hoverStar(r, 2, 20, 3)
        const p = gapPoint(r, 3)
        mouseMove(testCase, p.x, p.y)
        wait(40)
        compare(r.displayValue, 3)
        r.destroy()
    }

    function test_hoverSkipsClearedValue() {
        // 清除那一下把原值记进 clearedValue，指针留在同一颗上继续移动时不再预览
        // （foundation.ts:86-92）。注意 handleMouseLeave 会把 clearedValue 抹成 null，
        // 所以这个分支只在「点完没挪开」这段时间里有效。
        const r = make("Rating { defaultValue: 3;"
                       + " onHoverChanged: (v) => testCase.hovers.push(v) }")
        clickStar(r, 2, 20)                     // 清除：value 0，hoverValue undefined，clearedValue 3
        compare(r.currentValue, 0)
        compare(r._clearedValue, 3)
        hovers = []                             // 抹掉清除那一下发的 hoverChanged(undefined)
        mouseMove(star(r, 2), 14, 12)           // 同一颗的右半，算出来还是 3
        wait(40)
        compare(hovers.length, 0)
        compare(r._hoverValue, undefined)
        compare(r.displayValue, 0)
        hoverStar(r, 4, 20, 5)                  // 换个值就正常预览，证明悬浮通路没坏
        r.destroy()
    }

    function test_disabledIgnoresHover() {
        const r = make("Rating { disabled: true; defaultValue: 1 }")
        mouseMove(star(r, 3), 20, 12)
        wait(40)
        compare(r.displayValue, 1)
        compare(r._hoverValue, undefined)
        compare(star(r, 3).scale, 1)
        r.destroy()
    }

    function test_disabledIgnoresClick() {
        // item.tsx:184 `onClick: disabled ? null : this.onClick`
        const r = make("Rating { disabled: true; defaultValue: 2 }")
        clickStar(r, 3, 20)
        compare(r.currentValue, 2)
        compare(changes.length, 0)
        compare(icon(r, 3).color.toString(), Theme.current.colorFill0.toString())
        r.destroy()
    }

    function test_enabledFalseBehavesLikeDisabled() {
        // QML 自己的 enabled 关掉时，输入本来就不派发；这里确认预览语义与焦点也跟着收
        const r = make("Rating { enabled: false; defaultValue: 2 }")
        compare(r.activeFocusOnTab, false)
        clickStar(r, 3, 20)
        compare(changes.length, 0)
        mouseMove(star(r, 3), 20, 12)
        wait(40)
        compare(r.displayValue, 2)
        r.destroy()
    }

    function test_hoverScalesStarOnly() {
        // .semi-rating-star > div:hover { transform: scale(1.1) }
        const r = make("Rating { defaultValue: 0 }")
        hoverStar(r, 1, 20, 2)
        compare(star(r, 1).scale, 1.1)
        compare(star(r, 2).scale, 1)
        unhover()
        compare(star(r, 1).scale, 1)
        r.destroy()
    }

    // ---------------- 键盘（foundation.ts:119-146） ----------------

    function test_arrowKeysStepAndWrap() {
        const r = make("Rating { defaultValue: 5;"
                       + " onChanged: (v) => testCase.changes.push(v);"
                       + " onKeyPressed: () => testCase.keys.push(1) }")
        r.forceActiveFocus()
        wait(20)
        keyPress(Qt.Key_Right)
        keyRelease(Qt.Key_Right)
        wait(20)
        compare(r.currentValue, 0)              // 5+1 = 6 > count → 0
        compare(changes.length, 1)
        compare(changes[0], 0)
        compare(keys.length, 1)                 // notifyKeyDown
        keyPress(Qt.Key_Left)
        keyRelease(Qt.Key_Left)
        wait(20)
        compare(r.currentValue, 5)              // 0-1 = -1 < 0 → count
        r.destroy()
    }

    function test_arrowKeysOneAtATime() {
        const r = make("Rating { defaultValue: 0 }")
        r.forceActiveFocus()
        wait(20)
        for (let i = 1; i <= 3; ++i) {
            keyPress(Qt.Key_Right)
            keyRelease(Qt.Key_Right)
            wait(20)
            compare(r.currentValue, i)
        }
        keyPress(Qt.Key_Down)
        keyRelease(Qt.Key_Down)
        wait(20)
        compare(r.currentValue, 2)
        keyPress(Qt.Key_Up)
        keyRelease(Qt.Key_Up)
        wait(20)
        compare(r.currentValue, 3)
        r.destroy()
    }

    function test_halfStepWhenAllowHalf() {
        const r = make("Rating { allowHalf: true; defaultValue: 2 }")
        r.forceActiveFocus()
        wait(20)
        keyPress(Qt.Key_Right)
        keyRelease(Qt.Key_Right)
        wait(20)
        compare(r.currentValue, 2.5)
        compare(fillLayer(r, 2).visible, true)
        fuzzyCompare(fillLayer(r, 2).width, 12, 0.001)
        keyPress(Qt.Key_Left)
        keyRelease(Qt.Key_Left)
        wait(20)
        compare(r.currentValue, 2)
        compare(fillLayer(r, 2).visible, false)
        r.destroy()
    }

    function test_keyPressClearsHover() {
        // handleKeyDown 结尾 notifyHoverChange(undefined, null)
        const r = make("Rating { defaultValue: 1 }")
        hoverStar(r, 4, 20, 5)
        r.forceActiveFocus()
        wait(20)
        keyPress(Qt.Key_Left)
        keyRelease(Qt.Key_Left)
        wait(20)
        compare(r._hoverValue, undefined)
        compare(r.displayValue, r.currentValue)
        r.destroy()
    }

    function test_enterActsLikeClickOnCurrentStar() {
        const r = make("Rating { defaultValue: 3; onChanged: (v) => testCase.changes.push(v) }")
        r.forceActiveFocus()
        wait(20)
        keyPress(Qt.Key_Return)
        keyRelease(Qt.Key_Return)
        wait(20)
        compare(r.currentValue, 0)              // allowClear 默认 true，等于再点第 3 颗
        compare(changes.length, 1)
        r.destroy()
    }

    function test_disabledIgnoresKeys() {
        const r = make("Rating { disabled: true; defaultValue: 2;"
                       + " onChanged: (v) => testCase.changes.push(v) }")
        r.forceActiveFocus()
        wait(20)
        compare(r.activeFocusOnTab, false)
        keyPress(Qt.Key_Right)
        keyRelease(Qt.Key_Right)
        wait(20)
        compare(r.currentValue, 2)
        compare(changes.length, 0)
        r.destroy()
    }

    function test_autoFocus() {
        const r = make("Rating { autoFocus: true; defaultValue: 1 }")
        wait(20)
        compare(r.activeFocus, true)
        const off = make("Rating { autoFocus: true; disabled: true }")
        wait(20)
        compare(off.activeFocusOnTab, false)
        compare(off.activeFocus, false)         // init() 里 autoFocus && !disabled 才聚焦
        r.destroy(); off.destroy()
    }

    // ---------------- 焦点环（rating.scss:18-20，2px primary-light-active） ----------------

    function test_focusRingOnStar() {
        const r = make("Rating { defaultValue: 3 }")
        r.forceActiveFocus()
        wait(20)
        const g = ring(r)
        compare(g.visible, true)
        compare(g.x, 2 * 30)
        compare(g.width, 24)
        compare(g.height, 24)
        compare(g.border.width, 2)
        compare(g.border.color.toString(), Theme.current.colorPrimaryLightActive.toString())
        compare(g.radius, 3)
        r.destroy()
    }

    function test_focusRingAroundWholeControlAtZero() {
        const r = make("Rating { defaultValue: 0 }")
        r.forceActiveFocus()
        wait(20)
        const g = ring(r)
        compare(g.visible, true)
        compare(g.x, 0)
        compare(g.width, r.implicitWidth)
        r.destroy()
    }

    function test_ringFollowsCommittedValueNotPreview() {
        // adapter.focus 用的是 state.value，不是 hoverValue（index.tsx:133-140）
        const r = make("Rating { defaultValue: 1 }")
        r.forceActiveFocus()
        wait(20)
        hoverStar(r, 4, 20, 5)
        compare(ring(r).x, 0)
        r.destroy()
    }

    function test_mouseClickHidesRing() {
        // CSS 的 :focus-visible：鼠标点出来的焦点不给环
        const r = make("Rating { defaultValue: 0 }")
        clickStar(r, 1, 20)
        compare(r.activeFocus, true)
        compare(ring(r).visible, false)
        keyPress(Qt.Key_Right)
        keyRelease(Qt.Key_Right)
        wait(20)
        compare(ring(r).visible, true)          // 键盘一动就该有了
        r.destroy()
    }

    // ---------------- 自定义字符（item.tsx:177） ----------------

    function test_defaultCharacterIsStarIcon() {
        const r = make("Rating { defaultValue: 1 }")
        const ic = icon(r, 0)
        compare(ic.name, "star")
        compare(ic.visible, true)
        compare(baseGlyph(r, 0).children[1].visible, false)     // 那枚 Text 不显示
        compare(baseGlyph(r, 0).children[1].text, "")
        compare(baseGlyph(r, 0).children[2].active, false)      // Component 路由没启用
        r.destroy()
    }

    function test_stringCharacterPaintsText() {
        const r = make("Rating { character: '赞'; size: 18; allowHalf: true; defaultValue: 1.5 }")
        const t = baseGlyph(r, 0).children[1]
        compare(t.visible, true)
        compare(t.text, "赞")
        compare(t.font.pixelSize, 18)
        compare(t.color.toString(), Theme.current.yellow[5].toString())
        compare(icon(r, 0).visible, false)
        // 裁切层里也是同一枚字符，仍然按整格大小画（size 走的是格子，不是层宽）
        const ft = fillGlyph(r, 1).children[1]
        compare(ft.text, "赞")
        compare(ft.width, 18)
        fuzzyCompare(fillLayer(r, 1).width, 9, 0.001)
        r.destroy()
    }

    function test_componentCharacterAndInheritedColor() {
        const r = make("Rating { color: 'red'; defaultValue: 2; character: likeHeart }")
        const loader = baseGlyph(r, 0).children[2]
        compare(loader.visible, true)
        compare(loader.item.name, "like_heart")
        // CSS 的 color: inherit → Loader 载入后把控件颜色绑到被载入项上
        compare(loader.item.color.toString(), "#ff0000")
        r.destroy()
    }

    // ---------------- 每项提示（index.tsx:296-303） ----------------

    function test_tooltipsAttachToEachStar() {
        const r = make("Rating { tooltips: ['terrible','bad','normal','good','wonderful'] }")
        const tips = walk(r, "ratingStarTip")
        compare(tips.length, 5)
        const words = ["terrible", "bad", "normal", "good", "wonderful"]
        for (let i = 0; i < 5; ++i) {
            compare(tips[i].active, true)
            compare(tips[i].item.text, words[i])
            compare(tips[i].item.target, star(r, i))
            // 官方是 trigger="custom" + visible={hoverValue - 1 === ind}（index.tsx:300）
            compare(tips[i].item.trigger, "custom")
            compare(tips[i].item.visible, false)
        }
        r.destroy()
    }

    function test_noTooltipsKeepsPopupClosed() {
        const r = make("Rating { }")
        const tips = walk(r, "ratingStarTip")
        compare(tips.length, 5)
        for (let i = 0; i < 5; ++i)
            compare(tips[i].active, false)
        r.destroy()
    }

    function test_shortTooltipListOnlyCoversThoseStars() {
        const r = make("Rating { count: 5; tooltips: ['a','b'] }")
        const tips = walk(r, "ratingStarTip")
        compare(tips[0].active, true)
        compare(tips[1].item.text, "b")
        compare(tips[2].active, false)
        compare(tips[4].active, false)
        r.destroy()
    }

    // ---------------- 默认值与信号面 ----------------

    function test_defaultsMatchOfficialPropTable() {
        const r = make("Rating { }")
        compare(r.count, 5)
        compare(r.allowHalf, false)
        compare(r.allowClear, true)
        compare(r.disabled, false)
        compare(r.autoFocus, false)
        compare(r.value, undefined)
        compare(r.currentValue, 0)
        compare(r.itemSize, 24)
        compare(r.tooltips, undefined)
        compare(r.character, undefined)
        compare(r.size, "default")
        r.destroy()
    }

    function test_focusBlurSignals() {
        const r = make("Rating { defaultValue: 1;"
                       + " onFocused: () => testCase.focusLog.push('in');"
                       + " onBlurred: () => testCase.focusLog.push('out') }")
        compare(focusLog.length, 0)
        r.forceActiveFocus()
        wait(20)
        compare(focusLog.join(","), "in")
        testCase.forceActiveFocus()
        wait(20)
        compare(focusLog.join(","), "in,out")
        r.destroy()
    }

    function test_hoverChangedFiresWithPreviewValue() {
        const r = make("Rating { allowHalf: true; defaultValue: 0;"
                       + " onHoverChanged: (v) => testCase.hovers.push(v) }")
        hoverStar(r, 2, 20, 3)
        compare(hovers.length, 1)
        compare(hovers[0], 3)
        hoverStar(r, 2, 4, 2.5)                 // 同一颗的左半
        compare(hovers[hovers.length - 1], 2.5)
        unhover()
        compare(hovers[hovers.length - 1], undefined)
        r.destroy()
    }

    function test_starValueAtMatchesOfficial() {
        // getStarValue（foundation.ts:68-84）：右半整星、左半减 0.5；allowHalf 关掉就只看整星
        const r = make("Rating { allowHalf: true }")
        compare(r.starValueAt(0, 20), 1)
        compare(r.starValueAt(0, 4), 0.5)
        compare(r.starValueAt(4, 12), 5)        // 正好一半 → 整星（官方是 < 才减）
        r.allowHalf = false
        compare(r.starValueAt(0, 4), 1)
        r.destroy()
    }
}
