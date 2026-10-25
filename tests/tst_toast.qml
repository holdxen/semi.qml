import QtQuick
import QtQuick.Controls as C
import QtTest
import Semi

// Toast：属性面照抄官方 ToastProps / ConfigProps（semi-ui/toast/index.tsx:21-42 +
// :223-242、semi-ui/toast/toast.tsx:33-60），列表与堆叠语义照抄
// semi-foundation/toast/toastListFoundation.ts 与 toastFoundation.ts:67-95，
// 几何照抄 toast.scss / variables.scss / animation.scss。
//
// 官方是一组静态方法（Toast.info(...) 返回 id），QML 的 type 上没有静态方法，
// 所以整个 API 落在组件实例上；一个 Toast {} 就是 useToast() 返回的
// [toast, contextHolder] 那一对。
TestCase {
    id: testCase

    name: "Toast"
    when: windowShown
    width: 900
    height: 900

    property var log: []
    property string contextName: "Light"
    property var alive: []

    function init() {
        testCase.visible = true
        testCase.log = []
        testCase.contextName = "Light"
        Theme.reset()
        Theme.mode = Theme.Light
        // 悬停用例会把指针留在卡片上，而卡片永远在顶部居中，所以下一个用例开始前
        // 先把指针停到左下角那个卡片绝不可能出现的地方
        mouseMove(testCase, 2, testCase.height - 2)
        wait(20)
    }

    // 每个用例结束后收回自己建的宿主：漏掉的宿主会把卡片留在 overlay 里，
    // 后面的用例就会命中上一张卡片，悬停/计时的断言随之互相污染
    function cleanup() {
        mouseMove(testCase, 2, testCase.height - 2)
        wait(20)
        const list = testCase.alive
        testCase.alive = []
        for (let i = 0; i < list.length; ++i)
            list[i].destroy()
    }

    function make(qml) {
        const item = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "toastProbe")
        return item
    }

    function host() {
        const t = make("Toast { }")
        testCase.alive.push(t)
        return t
    }

    function card(t, i) {
        return t.items[i].card
    }

    function box(c) {
        return testCase.findChild(c, "toastBox")
    }

    function line(c) {
        return testCase.findChild(c, "toastLine")
    }

    function textBlock(c) {
        return testCase.findChild(c, "toastTextBlock")
    }

    function text(c) {
        return testCase.findChild(c, "toastText")
    }

    function icon(c) {
        return testCase.findChild(c, "toastIcon")
    }

    function closer(c) {
        return testCase.findChild(c, "toastClose")
    }

    // 指针放到某张卡片本体的中心（本体只有 .semi-toast-content 收事件，
    // 边角那点很容易被相邻卡片的投影层接走，中心最稳）
    function hoverCard(t, i) {
        const b = box(card(t, i))
        mouseMove(b, b.width / 2, b.height / 2)
        wait(60)
    }

    function unhover() {
        mouseMove(testCase, 2, testCase.height - 2)
        wait(60)
    }

    function band(t) {
        return testCase.findChild(t, "toastBand")
    }

    function wrapper(t) {
        return testCase.findChild(t, "toastWrapper")
    }

    function ids(t) {
        const out = []
        for (let i = 0; i < t.items.length; ++i)
            out.push(t.items[i].id)
        return out.join(",")
    }

    // ---------------------------------------------------------------- 配置面
    function test_configDefaults() {
        const t = host()
        compare(t.zIndex, 1010)                     // defaultOpts.zIndex / $z-toast
        compare(t.theme, "normal")                  // toast.tsx defaultProps.theme
        compare(t.duration, 3)                      // constants.ts numbers.duration = 3，单位秒
        compare(t.motion, true)                     // defaultOpts.motion
        compare(t.stack, false)                     // defaultProps.stack
        // 位置量的官方默认：top 0（$spacing-toast_wrapper-top），其余没设
        compare(t.y, 0)
        compare(t.x, 0)
        compare(t.items.length, 0)
        // 官方 wrapper 是 height: 0 + width: 100%，卡片溢出可见；它挂在窗口的 Overlay.overlay
        // （对应官方 append 到 document.body），宿主自己只是个 0×0 的 API 载体
        const w = wrapper(t)
        compare(w.height, 0)
        compare(w.width, w.parent.width)
        compare(w.z, 1010)
        compare(w.parent, C.Overlay.overlay)
        compare(t.width, 0)
    }

    function test_configValidatesLikeOfficial() {
        const t = host()
        t.config({ duration: 8, theme: "light", zIndex: 2000, top: 64 })
        compare(t.duration, 8)
        compare(t.theme, "light")
        compare(t.zIndex, 2000)
        compare(wrapper(t).y, 64)                   // config({ top: 64 })
        // 官方 config 逐项验类型：theme 不在 strings.themes 里、duration 不是 number 都不收
        t.config({ theme: "neon", duration: "3", zIndex: "2000" })
        compare(t.theme, "light")
        compare(t.duration, 8)
        compare(t.zIndex, 2000)
    }

    function test_perCallPositionOverridesContainer() {
        const t = host()
        t.info({ content: "x", top: 30, left: 40 })
        compare(wrapper(t).y, 30)
        compare(wrapper(t).x, 40)
        // 官方每次 create 都把这些量重刷到 wrapper 上，于是后面的调用能挪走整条带
        t.info({ content: "y", top: 5 })
        compare(wrapper(t).y, 5)
        compare(wrapper(t).x, 40)
        // left/right 同时给则把这条横带收窄（官方 CSS 过约束时 right 被丢掉，见 PROGRESS.md）
        t.config({ left: 20, right: 20 })
        compare(wrapper(t).x, 20)
        compare(wrapper(t).width, t.container.width - 40)
    }

    function test_bottomPositionsFromTheBottomEdge() {
        const t = host()
        // top 显式置 undefined 才让位给 bottom（记在 PROGRESS.md 的那处差异）
        t.config({ top: undefined, bottom: 100 })
        compare(wrapper(t).y, t.container.height - 100)
        t.config({ top: 12 })
        compare(wrapper(t).y, 12)
    }

    function test_getPopupContainerMovesWrapper() {
        const holder = make("Item { width: 320; height: 200 }")
        const t = host()
        t.config({ getPopupContainer: function () { return holder } })
        compare(wrapper(t).parent, holder)
        compare(wrapper(t).width, 320)
        t.info({ content: "x", duration: 0 })
        wait(40)
        // 卡片画在这个容器里（wrapper 搬过去之后，band 也在里面）
        compare(testCase.findChild(holder, "toastWrapper") !== null, true)
        compare(band(t).parent, wrapper(t))
        compare(band(t).mapToItem(holder, 0, 0).y, 0)
        holder.destroy()
    }

    // ---------------------------------------------------------------- 类型与图标
    function test_infoAcceptsStringAndOpts() {
        const t = host()
        const id = t.info("已保存")
        compare(typeof id, "string")
        compare(id.indexOf("toast-"), 0)            // 官方 getUuid('toast')
        compare(t.items.length, 1)
        compare(t.items[0].id, id)
        compare(t.has(id), true)
        const c = card(t, 0)
        wait(40)
        compare(c.type, "info")
        compare(c.contentText, "已保存")
        compare(t.items[0].removed, false)
    }

    function test_eachTypeHasItsOwnIconAndColor() {
        const t = host()
        t.success("ok")
        t.warning("warn")
        t.error("bad")
        t.info("info")
        wait(40)
        const want = [
            { type: "success", icon: "tick_circle", color: Theme.current.colorSuccess },
            { type: "warning", icon: "alert_triangle", color: Theme.current.colorWarning },
            { type: "error", icon: "alert_circle", color: Theme.current.colorDanger },
            { type: "info", icon: "info_circle", color: Theme.current.colorInfo }
        ]
        for (let i = 0; i < want.length; ++i) {
            const c = card(t, i)
            compare(c.type, want[i].type)
            compare(c.iconName, want[i].icon)       // toast.tsx renderIcon 的 iconMap
            compare(icon(c).name, want[i].icon)
            compare(icon(c).color.toString(), want[i].color.toString())
        }
    }

    function test_openIsDefaultTypeWithoutIcon() {
        const t = host()
        // 官方 useToast 的 api.open 把 type 定为 default；default 不在 iconMap 里
        t.open({ content: "裸提示", duration: 0 })
        wait(40)
        const c = card(t, 0)
        compare(c.type, "default")
        compare(c.iconName, "")
        compare(c.glyphShown, false)
        compare(icon(c).visible, false)
    }

    function test_customIconOverridesTypeIcon() {
        const t = host()
        t.success({ content: "x", icon: "star", duration: 0 })
        wait(40)
        compare(card(t, 0).iconName, "star")
        compare(icon(card(t, 0)).name, "star")
    }

    // ---------------------------------------------------------------- 外观规格
    function test_cardGeometryMatchesScss() {
        const t = host()
        t.info({ content: "Hi, Bytedance dance dance", duration: 0 })
        wait(40)
        const c = card(t, 0)
        const b = box(c)
        const l = line(c)
        // 盒子 = 本体 + 四周 12px（$spacing-toast_content-margin）；
        // 本体 = 内容行 + 上下 12px（$spacing-toast_content-paddingY）；行高 20（font-size-regular）
        compare(b.implicitHeight, 44)
        compare(c.implicitHeight, 68)
        compare(c.implicitWidth, b.implicitWidth + 24)
        compare(b.implicitWidth, l.implicitWidth + 16)   // paddingX 8
        compare(b.radius, 6)                               // $radius-toast_content
        compare(b.border.width, 0)                         // normal 没有描边
        compare(b.color.toString(), Theme.current.colorBg3.toString())
        // 图标 large = 20
        compare(icon(c).size, Theme.current.widthIconLarge)
        // 文本块左边距 = 图标宽 + 自己的 12px（$spacing-toast_content_text-marginLeft）
        compare(textBlock(c).x, 32)
        const cl = closer(c)
        compare(cl.parent.x, textBlock(c).x + textBlock(c).width + 12)
        compare(cl.parent.y, -2)                           // $spacing-toast_content_close_btn-marginTop
        compare(cl.parent.height, 20)                      // height: $width-icon-large
    }

    function test_textStyleIsBold14OnText0() {
        const t = host()
        t.success({ content: "保存成功", duration: 0 })
        wait(40)
        const c = card(t, 0)
        const item = text(c)
        compare(item.font.pixelSize, Theme.current.fontSizeRegular)
        compare(item.font.weight, Theme.current.fontWeightBold)   // $font-toast_content-fontWeight = 600
        // 官方 light 也只换底色/描边/图标，文字仍是 text-0（$color-toast-text-default）
        compare(item.color.toString(), Theme.current.colorText0.toString())
        compare(item.height, 20)                                   // @mixin font-size-regular：20px 行高
        compare(item.horizontalAlignment, Text.AlignLeft)
    }

    function test_lightThemeSurface() {
        const t = host()
        t.success({ content: "x", theme: "light", duration: 0 })
        t.info({ content: "y", theme: "light", duration: 0 })
        wait(40)
        const ok = card(t, 0)
        compare(ok.lightSurface, true)
        compare(box(ok).color.toString(), Theme.current.colorSuccessLightDefault.toString())
        compare(box(ok).border.width, 1)                            // $width-toast_light-border
        compare(box(ok).border.color.toString(), Theme.current.colorSuccess.toString())
        compare(icon(ok).color.toString(), Theme.current.colorSuccess.toString())
        compare(text(ok).color.toString(), Theme.current.colorText0.toString())
        const info = card(t, 1)
        compare(box(info).color.toString(), Theme.current.colorInfoLightDefault.toString())
        compare(box(info).border.color.toString(), Theme.current.colorInfo.toString())
    }

    function test_defaultTypeIgnoresLightTheme() {
        const t = host()
        // scss 里只有 .semi-toast-light.semi-toast-{warning,success,info,error}，
        // default 没有浅色规则，于是底色仍是 bg-3、没有描边
        t.open({ content: "x", theme: "light", duration: 0 })
        wait(40)
        const c = card(t, 0)
        compare(c.lightSurface, false)
        compare(box(c).color.toString(), Theme.current.colorBg3.toString())
        compare(box(c).border.width, 0)
    }

    function test_showCloseDefaultsToTrue() {
        const t = host()
        // 官方 defaultProps.showClose = true（旧实现里是 false）
        t.info({ content: "x", duration: 0 })
        wait(40)
        const c = card(t, 0)
        compare(c.showClose, true)
        compare(closer(c).visible, true)
        const withClose = c.implicitWidth
        t.info({ content: "x", showClose: false, duration: 0 })
        wait(40)
        const bare = card(t, 1)
        compare(bare.showClose, false)
        compare(closer(bare).parent.visible, false)
        // 关掉按钮后整张卡片正好窄掉一个按钮的宽度
        compare(withClose - bare.implicitWidth, closer(c).width)
    }

    function test_textMaxWidthCapsAndWraps() {
        const t = host()
        const long = "很长很长的中文内容用来撑破默认的最大宽度限制".repeat(12)
        t.info({ content: long, duration: 0 })
        t.info({ content: long, textMaxWidth: 120, duration: 0 })
        wait(60)
        const wide = card(t, 0)
        const narrow = card(t, 1)
        compare(textBlock(wide).width, 450)        // defaultProps.textMaxWidth = 450
        compare(textBlock(narrow).width, 120)
        // 超宽就换行，卡片跟着变高
        compare(text(wide).height > 20, true)
        compare(wide.implicitHeight > 68, true)
    }

    // ---------------------------------------------------------------- 计时
    function test_autoCloseCountsSeconds() {
        const t = host()
        t.info({ content: "x", duration: 1 })
        wait(400)
        // 若把 duration 当成毫秒，1ms 就关了；这里必须还在
        compare(t.items.length, 1)
        t.info({ content: "y", duration: 0.2 })
        tryVerify(function () { return t.items.length === 1 }, 1500, "duration 0.2s 应自动关掉")
        compare(t.items[0].content, "x")
    }

    function test_durationZeroNeverAutoCloses() {
        const t = host()
        t.info({ content: "x", duration: 0 })
        wait(500)
        compare(t.items.length, 1)
        // 官方 toastFoundation:67-75 —— 只有 duration 是非零数字才起 timer
        t.info({ content: "y", duration: undefined })
        wait(500)
        compare(t.items.length, 2)
    }

    function test_closeByIdSkipsOnCloseCallback() {
        const t = host()
        const id = t.info({
            content: "x",
            duration: 0,
            onClose: function () { testCase.log.push("close") }
        })
        t.close(id)
        // 官方 Toast.close(id) 只走 removeToast，不碰 notifyClose
        compare(testCase.log.length, 0)
        compare(t.items.length, 1)
        compare(t.items[0].removed, true)
        tryVerify(function () { return t.items.length === 0 }, 1200, "退场动画后应销毁")
        compare(testCase.log.length, 0)
        compare(t.has(id), false)
    }

    function test_timerCloseFiresOnClose() {
        const t = host()
        t.info({
            content: "x",
            duration: 0.2,
            onClose: function () { testCase.log.push("close") }
        })
        tryVerify(function () { return testCase.log.length === 1 }, 1500, "到点应回调 onClose")
        tryVerify(function () { return t.items.length === 0 }, 1200, "到点后应消失")
        compare(testCase.log.length, 1)
    }

    function test_closeButtonClosesAndFiresOnClose() {
        const t = host()
        t.info({
            content: "x",
            duration: 0,
            onClose: function () { testCase.log.push("close") }
        })
        wait(400)           // 入场动画期间卡片还在往上飘，按下落点会跟着跑掉
        mouseClick(closer(card(t, 0)))
        compare(testCase.log, ["close"])
        compare(t.items.length, 1)
        compare(t.items[0].removed, true)
        tryVerify(function () { return t.items.length === 0 }, 1200, "点 × 之后应消失")
    }

    function test_updateByIdRestartsTimer() {
        const t = host()
        t.info({ id: "u", content: "一", duration: 0.6 })
        wait(350)
        compare(t.items[0].removed, false)
        // 官方 updateToast 之后 refFn 里 restartCloseTimer：重新计满整个 duration
        t.success({ id: "u", content: "二", duration: 0.6 })
        // 距第一次调用已 650ms，原始到点时间（600ms）早过了 —— 没重启这条就关了
        wait(300)
        compare(t.items[0].removed, false)
        compare(t.items[0].deadline > Date.now(), true)
        tryVerify(function () { return t.items.length === 0 }, 1500, "重启后的计时应到点关闭")
    }

    // ---------------------------------------------------------------- 列表语义
    function test_updateByIdKeepsTheSameCard() {
        const t = host()
        t.info({ id: "x", content: "Update Content By Id", duration: 0 })
        wait(40)
        const first = card(t, 0)
        t.success({ id: "x", content: "Id By Content Update", duration: 0 })
        wait(40)
        compare(t.items.length, 1)
        compare(card(t, 0), first)                   // 是同一张卡片，不是先删再加
        compare(first.contentText, "Id By Content Update")
        compare(first.type, "success")
        // create() 不带 type 时沿用原来那条（官方 mergedOpts 里没有 type 这个 key）
        t.create({ id: "x", content: "只改内容", duration: 0 })
        wait(40)
        compare(t.items.length, 1)
        compare(card(t, 0), first)
        compare(first.type, "success")
    }

    function test_removedCardIsMovedToEnd() {
        const t = host()
        const a = t.info({ content: "a", duration: 0 })
        const b = t.info({ content: "bbbbbb", duration: 0 })
        const c = t.info({ content: "c", duration: 0 })
        wait(40)
        const heightA = card(t, 0).implicitHeight
        const heightC = card(t, 2).implicitHeight
        t.close(b)
        // 官方 render：Array.from(new Set([...list, ...removedItems])) —— 离场的那条挪到末尾
        compare(ids(t), [a, c, b].join(","))
        compare(t.items[2].removed, true)
        compare(t.has(b), false)
        compare(t.items[0].removed, false)
        // 前面两条立刻补位，离场那条排到最后
        compare(card(t, 0).y, 0)
        compare(card(t, 1).y, heightA)
        compare(card(t, 2).y, heightA + heightC)
        // 正在退场时再用同一个 id 开一条：官方 hasToast 只看 list，于是两条同 id 并存
        t.info({ id: b, content: "b2", duration: 0 })
        wait(40)
        compare(t.items.length, 4)
        tryVerify(function () { return t.items.length === 3 }, 1200, "退场结束后只留三条")
        compare(ids(t), [a, c, b].join(","))
    }

    function test_destroyAllIsImmediateAndSilent() {
        const t = host()
        t.info({ content: "a", duration: 0, onClose: function () { testCase.log.push("a") } })
        t.info({ content: "b", duration: 0, onClose: function () { testCase.log.push("b") } })
        wait(40)
        // 官方 destroyAll 直接把 wrapper 卸载：没有退场动画，也不跑 onClose
        t.destroyAll()
        compare(t.items.length, 0)
        compare(testCase.log.length, 0)
        // destroy() 是排期删除，要等一轮事件循环才真的从 band 上消失
        wait(40)
        compare(band(t).children.length, 0)
        // 之后还能接着用
        t.info("再来")
        wait(40)
        compare(t.items.length, 1)
    }

    function test_threeToastsStackVerticallyWhenNotStacked() {
        const t = host()
        t.info({ content: "a", duration: 0 })
        t.info({ content: "bb", duration: 0 })
        t.info({ content: "ccc", duration: 0 })
        wait(40)
        compare(card(t, 0).y, 0)
        compare(card(t, 1).y, card(t, 0).implicitHeight)
        compare(card(t, 2).y, card(t, 0).implicitHeight + card(t, 1).implicitHeight)
        // 后面的盖住前面的（DOM 里也是后面的在后面）
        compare(card(t, 0).z, 0)
        compare(card(t, 2).z, 2)
    }

    // ---------------------------------------------------------------- 堆叠
    function test_stackFlagIsContainerLevel() {
        const t = host()
        // 官方 instance.stack 挂在容器上，最后一次调用赢，且作用到全部卡片
        t.info({ content: "a", stack: true, duration: 0 })
        t.info({ content: "b", duration: 0 })
        wait(40)
        compare(t.stack, true)
        compare(card(t, 0).stack, true)
        compare(card(t, 1).stack, true)
        // 未展开时整叠只占一条卡片高（官方 .semi-toast-zero-height-wrapper 高度 0，卡片互相叠住）
        compare(card(t, 0).y, 0)
        compare(card(t, 1).y, 0)
        fuzzyCompare(band(t).height, card(t, 0).implicitHeight, 0.01)
        // reservedIndex = length - index - 1：最新那条在最前
        compare(card(t, 0).reservedIndex, 1)
        compare(card(t, 1).reservedIndex, 0)
        // translate3d(0,0,-10px) 在 perspective 280px 下的投影
        fuzzyCompare(card(t, 0).stackScale, 280 / 290, 0.0001)
        fuzzyCompare(card(t, 1).stackScale, 1, 0.0001)
    }

    function test_stackExpandsOnHoverAndCollapsesOnLeave() {
        const t = host()
        t.info({ content: "a", stack: true, duration: 0 })
        t.info({ content: "bb", stack: true, duration: 0 })
        wait(400)
        const first = card(t, 0)
        const second = card(t, 1)
        compare(t.stackExpanded, false)
        hoverCard(t, 1)
        tryVerify(function () { return t.stackExpanded === true }, 600, "悬停应展开这一叠")
        compare(first.stackExpanded, true)
        // 展开后外壳高度变成卡片高度，于是两条竖着排开；y 走 300ms 的 stack 动画，等它停稳
        fuzzyCompare(band(t).height, first.implicitHeight + second.implicitHeight, 0.01)
        tryVerify(function () { return Math.abs(second.y - first.implicitHeight) < 0.5 }, 1500,
                  "展开后第二条应排在第一条下面")
        compare(first.y, 0)
        // 展开时官方把 perspective 置 unset → 投影回到 1
        fuzzyCompare(first.stackScale, 1, 0.0001)
        unhover()
        tryVerify(function () { return t.stackExpanded === false }, 600, "指针离开应收起")
        tryVerify(function () { return Math.abs(second.y) < 0.5 }, 1500, "收起后两条重新叠回同一位置")
        compare(first.y, 0)
        fuzzyCompare(first.stackScale, 280 / 290, 0.0001)
    }

    // 展开之后指针落在「卡片之间那 24px 缝隙」里：官方那片区域是连续的 zero-height-wrapper
    // （展开时每条的高度 = 卡片高），指针不算离开整叠，所以不能收起。收起条件一旦退回
    // 「没有卡片被悬停」，缝隙里的指针会让这一叠来回抽搐：收起 → 卡片叠回指针底下 → 展开 →
    // 又落回缝隙。这条按「翻转次数」测，不按「收起没收起」测 —— 后者一次采样可能正好躲过。
    function test_hoverInGapKeepsStackExpandedWithoutOscillating() {
        const t = host()
        t.info({ content: "第一条", stack: true, duration: 0 })
        t.success({ content: "第二条", stack: true, duration: 0 })
        wait(400)
        const first = card(t, 0)
        const second = card(t, 1)
        hoverCard(t, 0)
        tryVerify(function () { return t.stackExpanded === true }, 600, "悬停应展开这一叠")
        tryVerify(function () { return Math.abs(second.y - first.implicitHeight) < 0.5 }, 1500,
                  "展开后两条应排开")
        const b1 = box(first)
        const gapY = first.marginSize + b1.height + 6
        // 这个位置必须「谁的本体都不属于」，否则缝隙这个前提没成立，测了个空的
        verify(gapY > b1.y + b1.height, "缝隙要在第一条本体之下")
        verify(gapY < second.y + box(second).y, "缝隙要在第二条本体之上")
        // 粘滞区域得盖住整叠（含卡片之间的 margin），否则指针一进缝隙就被判成离开。
        // 这两量各自要等一轮 polish 才自洽（卡片 implicitHeight 变了要重算 band.height），
        // 所以按轮询断，不取单次采样
        tryVerify(function () { return band(t).height >= second.y + second.implicitHeight }, 600,
                  "band 的高度要覆盖展开后的整叠")
        var flips = 0
        var last = t.stackExpanded
        for (var i = 0; i < 12; ++i) {
            mouseMove(first, first.width / 2, gapY + (i % 2))
            wait(16)
            if (t.stackExpanded !== last) {
                ++flips
                last = t.stackExpanded
            }
        }
        compare(flips, 0)
        compare(t.stackExpanded, true)
        unhover()
        tryVerify(function () { return t.stackExpanded === false }, 600, "指针真的离开整叠才收起")
    }

    function test_hoverWithoutStackDoesNotExpand() {
        const t = host()
        t.info({ content: "a", duration: 0 })
        wait(400)
        hoverCard(t, 0)
        // 悬停本身要真的发生（否则这条断言是空的），但官方 handleMouseEnter 里有 if (this.stack)
        compare(t.items[0].hovered, true)
        compare(t.stackExpanded, false)
        compare(card(t, 0).stack, false)
        // 非堆叠时官方没有 zero-height-wrapper，卡片之间的空隙不吃指针 —— 这片粘滞区域
        // 必须整个不存在，否则白占一条横带的悬停
        compare(band(t).height, 0)
    }

    function test_hoverPausesAutoCloseAndLeaveRestartsIt() {
        const t = host()
        t.info({ content: "a", duration: 0.4 })
        wait(400)           // 入场动画没播完时卡片还在上方，指针落不到本体上
        hoverCard(t, 0)
        compare(t.items[0].hovered, true)
        // onMouseEnter → clearCloseTimer_：悬停期间不计时
        wait(500)
        compare(t.items.length, 1)
        unhover()
        wait(60)
        compare(t.items[0].hovered, false)
        // onMouseLeave → startCloseTimer_：重新计满整个 duration，而不是剩下的那点
        wait(300)
        compare(t.items.length, 1)
        tryVerify(function () { return t.items.length === 0 }, 1500, "离开后重新计时并关闭")
    }

    // 不堆叠时两张卡片各占一行，悬停只算被指到的那一张 —— 计时暂停因此是逐条生效的
    function test_hoverTargetsOneCardAtATime() {
        const t = host()
        t.info({ content: "a", duration: 0 })
        t.info({ content: "bb", duration: 0 })
        wait(400)
        hoverCard(t, 1)
        compare(t.items[1].hovered, true)
        compare(t.items[0].hovered, false)
        hoverCard(t, 0)
        compare(t.items[0].hovered, true)
        compare(t.items[1].hovered, false)
        unhover()
        wait(60)
        compare(t.items[0].hovered, false)
    }

    // ---------------------------------------------------------------- 富文本 / context
    Component {
        id: contextContent

        Column {
            Text {
                objectName: "ctxHead"
                text: "Hi, Bytedance dance dance"
            }

            Text {
                objectName: "ctxBody"
                text: "ReachableContext: " + testCase.contextName
            }
        }
    }

    function test_richContentReadsDefiningScope() {
        const t = host()
        // 官方 useToast 的 contextHolder 决定能读到哪些 context；这里对应到
        // 「content 传 Component，Loader 按 Component 自己的上下文实例化」
        t.success({ content: contextContent, duration: 0 })
        wait(60)
        const c = card(t, 0)
        const rich = testCase.findChild(c, "toastRich")
        compare(rich.active, true)
        compare(testCase.findChild(rich.item, "ctxBody").text, "ReachableContext: Light")
        // 卡片高度跟着内容长高（官方 multi-line demo 的那条）
        compare(c.implicitHeight > 68, true)
        testCase.contextName = "Heavy"
        wait(40)
        compare(testCase.findChild(rich.item, "ctxBody").text, "ReachableContext: Heavy")
    }

    function test_plainAndRichAreMutuallyExclusive() {
        const t = host()
        t.info({ content: contextContent, duration: 0 })
        wait(60)
        const c = card(t, 0)
        compare(c.contentText, "")
        compare(text(c).visible, false)
        t.info({ content: "字符串", duration: 0 })
        wait(60)
        const plain = card(t, 1)
        compare(testCase.findChild(plain, "toastRich").item, null)
        compare(text(plain).text, "字符串")
    }

    // ---------------------------------------------------------------- 容器排布
    function test_bandIsCenteredAndAsWideAsTheWidest() {
        const t = host()
        t.info({ content: "短", duration: 0 })
        t.info({ content: "这条明显要长得多得多", duration: 0 })
        wait(60)
        const b = band(t)
        const w = wrapper(t)
        const wide = card(t, 1)
        const narrow = card(t, 0)
        compare(b.width, wide.implicitWidth)
        // justify-content: center
        fuzzyCompare(w.x + b.x + b.width / 2, w.x + w.width / 2, 1.0)
        // 卡片铺满这条带，本体在带内居中（官方 innerWrapper 的 text-align: center）
        compare(narrow.width, b.width)
        const nb = box(narrow)
        fuzzyCompare(nb.x + nb.width / 2, narrow.width / 2, 1.0)
        compare(nb.x > 0, true)
    }

    // ---------------------------------------------------------------- 动画
    function test_enterAnimationStartsAboveAndSettles() {
        const t = host()
        t.info({ content: "x", duration: 0 })
        const c = card(t, 0)
        // translateY(-100%) + opacity 0 起步（$animation_transform_translateY-toast-show）
        compare(c.reveal < 1, true)
        wait(500)
        fuzzyCompare(c.reveal, 1, 0.001)
    }

    function test_exitAnimationPlaysBeforeDestroy() {
        const t = host()
        t.info({ content: "x", duration: 0 })
        wait(500)
        const c = card(t, 0)
        t.close(t.items[0].id)
        wait(100)
        // 退场过程中还在树上，且已经往上飘
        compare(t.items.length, 1)
        compare(c.reveal < 1, true)
        tryVerify(function () { return t.items.length === 0 }, 1200, "动画播完才销毁")
    }

    function test_motionFalseSkipsBothAnimations() {
        const t = host()
        t.info({ content: "x", duration: 0, motion: false })
        const c = card(t, 0)
        // 官方 CSSAnimation：motion 为 false 时按「时长 0 的动画」处理，挂载即结束
        fuzzyCompare(c.reveal, 1, 0.001)
        t.close(t.items[0].id)
        tryVerify(function () { return t.items.length === 0 }, 300, "没有退场动画，立刻销毁")
    }

    // ---------------------------------------------------------------- 无障碍
    function test_roleIsAlert() {
        const t = host()
        t.info({ content: "x", duration: 0 })
        wait(40)
        const c = card(t, 0)
        // 官方 role="alert"、aria-label="${type} type"
        compare(c.Accessible.role, Accessible.Alert)
        compare(c.Accessible.name, "info type")
    }

    // ---------------------------------------------------------------- 主题联动
    function test_followsThemeTokens() {
        const t = host()
        t.info({ content: "x", theme: "light", duration: 0 })
        wait(40)
        const b = box(card(t, 0))
        compare(b.color.toString(), Theme.current.colorInfoLightDefault.toString())
        Theme.mode = Theme.Dark
        wait(40)
        compare(b.color.toString(), Theme.current.colorInfoLightDefault.toString())
        t.info({ content: "y", duration: 0 })
        wait(40)
        compare(box(card(t, 1)).color.toString(), Theme.current.colorBg3.toString())
        Theme.mode = Theme.Light
    }
}
