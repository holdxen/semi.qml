import QtQuick
import QtQuick.Controls as C
import QtTest
import Semi

// Notification：属性面照抄官方 NoticeProps（semi-ui/notification/notice.tsx:36-56 +
// index.tsx:52-58 的 defaultConfig）与 ConfigProps（notificationListFoundation.ts:20-28），
// 列表/合并/退场语义照抄 notificationListFoundation.ts 与 notificationFoundation.ts，
// 几何照抄 notification.scss / variables.scss / animation.scss，
// 并用浏览器实测对过数（harness：tests/tmp_notice_dom.html）：
// 标题+正文 78、只有标题 58、只有正文（带关闭按钮）56、正文且无关闭按钮 52、
// light 档因为那 1px 描边走 content-box 而 +2，卡片宽一律 352（min-width 320 + 20 + 12）。
//
// 官方是一组静态方法（Notification.info(...) 返回 id），QML 的 type 上没有静态方法，
// 所以整个 API 落在组件实例上；一个 Notification {} 就是 useNotification() 返回的
// [notification, contextHolder] 那一对。
TestCase {
    id: testCase

    name: "Notification"
    when: windowShown
    width: 900
    height: 900

    property var log: []
    property var alive: []
    property string contextName: "Light"

    function init() {
        testCase.visible = true
        testCase.log = []
        testCase.contextName = "Light"
        Theme.reset()
        Theme.mode = Theme.Light
        // 悬停用例会把指针留在卡片上，而卡片总贴着窗口边缘，所以下一个用例开始前
        // 先把指针挪到左边中段那块六档位置都不会有卡片的地方
        mouseMove(testCase, 2, testCase.height / 2)
        wait(20)
    }

    // 每个用例结束后收回自己建的宿主：漏掉的宿主会把卡片留在 overlay 里，
    // 后面的用例就会命中上一张卡片，悬停/计时的断言随之互相污染
    function cleanup() {
        mouseMove(testCase, 2, testCase.height / 2)
        wait(20)
        const list = testCase.alive
        testCase.alive = []
        for (let i = 0; i < list.length; ++i)
            list[i].destroy()
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "noticeProbe")
    }

    // 默认关掉进出场动画与自动关闭：几何与时序断言不该被 300ms 动画干扰，
    // 需要它们的用例自己把 motion / duration 开回来
    function host() {
        const t = make("Notification { motion: false; duration: 0 }")
        testCase.alive.push(t)
        return t
    }

    // 盯着「官方默认值」本身的用例不能用上面那个（它已经把 duration 改成 0 了）
    function bareHost() {
        const t = make("Notification { }")
        testCase.alive.push(t)
        return t
    }

    // 官方那五个静态方法都把 type 钉在自己那档上，所以想开某个 type 只能调对应的方法
    function fire(t, type, opts) {
        const o = opts || ({})
        if (o.content === undefined)
            o.content = "x"
        if (type === "success")
            return t.success(o)
        if (type === "warning")
            return t.warning(o)
        if (type === "info")
            return t.info(o)
        if (type === "error")
            return t.error(o)
        return t.open(o)
    }

    function card(t, i) {
        return t.items[i].card
    }

    function surface(c) {
        return testCase.findChild(c, "noticeSurface")
    }

    function iconCol(c) {
        return testCase.findChild(c, "noticeIconCol")
    }

    function glyph(c) {
        return testCase.findChild(c, "noticeIcon")
    }

    function column(c) {
        return testCase.findChild(c, "noticeColumn")
    }

    function titleText(c) {
        return testCase.findChild(c, "noticeTitle")
    }

    function bodyText(c) {
        return testCase.findChild(c, "noticeContent")
    }

    function titleLoader(c) {
        return testCase.findChild(c, "noticeTitleRich")
    }

    function contentLoader(c) {
        return testCase.findChild(c, "noticeContentRich")
    }

    function closer(c) {
        return testCase.findChild(c, "noticeClose")
    }

    function closeWrap(c) {
        return testCase.findChild(c, "noticeCloseWrap")
    }

    function list(t, position) {
        return testCase.findChild(t, "noticeList_" + position)
    }

    function wrapper(t) {
        return testCase.findChild(t, "noticeWrapper")
    }

    // 卡片相对窗口的落点（motion 关掉时没有位移干扰）
    function abs(c) {
        return c.mapToItem(null, 0, 0)
    }

    function recordIds(t) {
        const out = []
        for (let i = 0; i < t.items.length; ++i)
            out.push(t.items[i].id)
        return out.join(",")
    }

    // 一段足以把卡片拉到 352 以外、但又不到封顶的正文
    readonly property string longText: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    // 一段必定撞到容器右缘的正文
    readonly property string hugeText: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        + "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

    // ---------------------------------------------------------------- 配置面
    function test_configDefaults() {
        const t = bareHost()
        compare(t.zIndex, 1010)                     // defaultConfig.zIndex / $z-notification
        compare(t.position, "topRight")             // defaultConfig.position
        compare(t.duration, 3)                      // constants.ts numbers.duration = 3，单位秒
        compare(t.motion, true)                     // defaultConfig.motion
        compare(t.items.length, 0)
        compare(t.width, 0)
        compare(t.height, 0)
        // 宿主只是 API 载体；六条固定列表挂在窗口的 Overlay.overlay 上（对应官方 append 到 body）
        const w = wrapper(t)
        compare(w.parent, C.Overlay.overlay)
        compare(w.z, 1010)
        compare(w.width, w.parent.width)
        compare(w.height, w.parent.height)
        const positions = ["top", "bottom", "topLeft", "topRight", "bottomLeft", "bottomRight"]
        for (let i = 0; i < positions.length; ++i) {
            compare(list(t, positions[i]).objectName, "noticeList_" + positions[i])
            compare(list(t, positions[i]).width, 0)
            compare(list(t, positions[i]).height, 0)
        }
    }

    function test_configSetsContainerDefaultsAndInsets() {
        const t = host()
        t.config({ duration: 8, position: "topLeft", zIndex: 2000, top: 64, left: 12 })
        compare(t.duration, 8)
        compare(t.position, "topLeft")
        compare(t.zIndex, 2000)
        // 官方 setPosInStyle 把这些量写到列表盒子上，卡片自己再让 20 的外边距
        t.open({ content: "x" })
        const c = card(t, 0)
        compare(abs(c).y, 64 + 20)
        compare(abs(c).x, 12 + 20)
    }

    function test_configIgnoresBadTypesLikeOfficial() {
        const t = bareHost()
        // 官方 config 逐档验类型：typeof === 'number' / 'string' 才收
        t.config({ duration: "8", zIndex: "2000" })
        compare(t.duration, 3)
        compare(t.zIndex, 1010)
        // position 官方只验 typeof 'string'，非法值会在分组渲染时抛异常；端口退化成默认档
        t.config({ position: "middle" })
        compare(t.position, "topRight")
    }

    function test_perCallTopDoesNotBecomeContainerDefault() {
        const t = host()
        t.open({ content: "a", top: 100 })
        compare(abs(card(t, 0)).y, 120)
        t.open({ content: "b" })                    // 没写 top ⇒ 官方这个 key 不参与合并
        const slot = list(t, "topRight")
        compare(slot.y, 0)                          // 于是回到 CSS 的 top: 0
        compare(abs(card(t, 0)).y, 20)              // 最新那条在最前
        compare(abs(card(t, 1)).y, 20 + card(t, 0).height + 20)
    }

    function test_zIndexLockedOnFirstNotice() {
        const t = host()
        compare(t.zIndexLocked, false)
        t.open({ content: "a", zIndex: 2200 })
        compare(wrapper(t).z, 2200)
        compare(t.zIndexLocked, true)
        // 文档写明「首次设置一次生效」：之后再给都改不动已经挂上去的那层
        t.open({ content: "b", zIndex: 3000 })
        compare(wrapper(t).z, 2200)
        t.config({ zIndex: 4000 })
        compare(t.zIndex, 4000)
        compare(wrapper(t).z, 2200)
    }

    function test_zIndexFallsBackToConfigLayer() {
        const t = host()
        t.config({ zIndex: 1500 })
        t.open({ content: "a" })                    // 调用点没写 zIndex ⇒ defaultConfig 那档
        compare(wrapper(t).z, 1500)
    }

    function test_getPopupContainerMovesListsAndIsReadOnce() {
        const t = host()
        const first = make("Item { width: 640; height: 520 }")
        // 官方 config() 里没有 getPopupContainer，它只挂在单条通知上，且只在建 wrapper 那一次读
        t.open({ content: "a", getPopupContainer: function () { return first } })
        compare(wrapper(t).parent, first)
        compare(wrapper(t).width, 640)
        compare(card(t, 0).parent.parent, wrapper(t))
        compare(abs(card(t, 0)).x + card(t, 0).width, 640 - 20)
        const other = make("Item { width: 400; height: 300 }")
        t.open({ content: "b", getPopupContainer: function () { return other } })
        compare(wrapper(t).parent, first)           // 第二次调用换不了容器
        compare(abs(card(t, 0)).x + card(t, 0).width, 640 - 20)
        // 这两个容器不销毁：wrapper 还挂在 first 上，先把它拆了会让宿主留下悬空 parent
    }

    // ---------------------------------------------------------------- API 面
    function test_openReturnsIdAndUsesDefaultType() {
        const t = host()
        const id = t.open({ title: "Hi, Bytedance", content: "ies dance dance dance" })
        compare(typeof id, "string")
        compare(id.indexOf("notification-"), 0)     // 官方 getUuid('notification')
        compare(t.items.length, 1)
        compare(t.items[0].id, id)
        compare(t.has(id), true)
        const c = card(t, 0)
        compare(c.noticeId, id)
        compare(c.type, "default")
        compare(iconCol(c).visible, false)          // iconMap 里 default 没有图标
        compare(titleText(c).text, "Hi, Bytedance")
        compare(bodyText(c).text, "ies dance dance dance")
    }

    function test_fiveStaticsPinTheirType() {
        const t = host()
        t.info({ content: "a", type: "error" })     // type 排在 ...opts 之后 ⇒ 入参 type 被顶掉
        t.success({ content: "b" })
        t.warning({ content: "c" })
        t.error({ content: "d" })
        t.open({ content: "e" })
        const want = ["default", "error", "warning", "success", "info"]
        for (let i = 0; i < want.length; ++i)
            compare(card(t, i).type, want[i])
    }

    function test_newestRecordComesFirst() {
        const t = host()
        const a = t.open({ content: "a" })
        const b = t.open({ content: "b" })
        const c = t.open({ content: "c" })
        compare(t.items.length, 3)
        compare(recordIds(t), c + "," + b + "," + a)
    }

    function test_callerSuppliedIdIsUsedVerbatim() {
        const t = host()
        compare(t.open({ content: "a", id: "notice-a" }), "notice-a")
        compare(t.items[0].id, "notice-a")
        // 官方 NoticeProps.id 是 string，数字那条靠 React 的 key 也能跑；端口统一成字符串
        compare(t.open({ content: "b", id: 42 }), "42")
        compare(t.has(42), true)
    }

    function test_stringArgumentIsNotShorthand() {
        const t = host()
        // Toast 收字符串简写，Notification 只收 options：官方 {...defaultConfig, ...'x'}
        // 摊出来的是 {0:'x'}，title/content 仍是默认空串
        const id = t.info("已保存")
        compare(t.items.length, 1)
        compare(t.has(id), true)
        const c = card(t, 0)
        compare(c.type, "info")
        compare(c.titleText, "")
        compare(c.contentText, "")
        compare(titleText(c).visible, false)
        compare(bodyText(c).visible, false)
    }

    // ---------------------------------------------------------------- 图标与配色
    function test_typeIconMap() {
        const t = host()
        // 按调用顺序摆 open，读回来是倒的（最新那条在 items[0]）
        const want = [
            { type: "success", name: "tick_circle" },
            { type: "warning", name: "alert_triangle" },
            { type: "info", name: "info_circle" },
            { type: "error", name: "alert_circle" }
        ]
        for (let i = 0; i < want.length; ++i)
            fire(t, want[i].type)
        for (let i = 0; i < want.length; ++i) {
            const c = card(t, i)
            const w = want[want.length - 1 - i]
            compare(c.type, w.type)
            compare(glyph(c).name, w.name)
            compare(iconCol(c).visible, true)
            compare(glyph(c).size, 20)              // iconMap 里全是 size="large"
        }
    }

    function test_customIconReplacesTypeIcon() {
        const t = host()
        t.success({ content: "x", icon: "vigo_logo" })
        const c = card(t, 0)
        compare(glyph(c).name, "vigo_logo")
        compare(iconCol(c).visible, true)
    }

    function test_iconColorFollowsType() {
        const t = host()
        const want = [
            { type: "success", tone: Enums.Success },
            { type: "warning", tone: Enums.Warning },
            { type: "info", tone: Enums.Info },
            { type: "error", tone: Enums.Danger }
        ]
        for (let i = 0; i < want.length; ++i)
            fire(t, want[i].type)
        for (let i = 0; i < want.length; ++i)
            compare(glyph(card(t, i)).color.toString(),
                Appearance.textColor(Theme.current, want[want.length - 1 - i].tone).toString())
    }

    function test_normalThemeSurface() {
        const t = host()
        t.info({ content: "x", theme: "normal" })
        const s = surface(card(t, 0))
        compare(s.color.toString(), Theme.current.colorBg3.toString())
        compare(s.border.width, 0)
        compare(s.radius, Theme.current.radiusMedium)   // $radius-notification_notice
    }

    // 官方 -light.-{type}：底色 *-light-default，描边是纯色调 1px
    function test_lightThemeSurface() {
        const t = host()
        const want = [
            { type: "success", bg: Theme.current.colorSuccessLightDefault,
                border: Theme.current.colorSuccess },
            { type: "warning", bg: Theme.current.colorWarningLightDefault,
                border: Theme.current.colorWarning },
            { type: "info", bg: Theme.current.colorInfoLightDefault,
                border: Theme.current.colorInfo },
            { type: "error", bg: Theme.current.colorDangerLightDefault,
                border: Theme.current.colorDanger }
        ]
        for (let i = 0; i < want.length; ++i)
            fire(t, want[i].type, { theme: "light" })
        for (let i = 0; i < want.length; ++i) {
            const s = surface(card(t, i))
            const w = want[want.length - 1 - i]
            compare(s.color.toString(), w.bg.toString())
            compare(s.border.width, 1)              // $width-notification_notice-border
            compare(s.border.color.toString(), w.border.toString())
        }
    }

    function test_lightDefaultTypeSharesInfoRule() {
        const t = host()
        // notification.scss:107-112 把 -light.-default 与 -light.-info 写在同一条选择器里，
        // 于是 default 也吃浅色、走 info 的色（Toast 那边 default 是没有浅色的）
        t.open({ content: "x", theme: "light" })
        const c = card(t, 0)
        compare(c.type, "default")
        compare(surface(c).color.toString(), Theme.current.colorInfoLightDefault.toString())
        compare(surface(c).border.color.toString(), Theme.current.colorInfo.toString())
        compare(surface(c).border.width, 1)
    }

    function test_textColorsDoNotChangeWithTheme() {
        const t = host()
        t.info({ title: "T", content: "C", theme: "light" })
        const c = card(t, 0)
        // 官方 light 只换底色/描边/图标色，标题正文仍是 text-0 / text-1
        compare(titleText(c).color.toString(), Theme.current.colorText0.toString())
        compare(bodyText(c).color.toString(), Theme.current.colorText1.toString())
    }

    // ---------------------------------------------------------------- 卡片几何
    function test_minWidthAndPadding() {
        const t = host()
        t.info({ title: "Hi, Bytedance", content: "ies dance dance dance" })
        const c = card(t, 0)
        // min-width: 320px 落在 content-box 上 ⇒ 边框盒 320 + 20 + 12
        compare(c.minBoxWidth, 352)
        compare(c.naturalWidth, 352)
        compare(c.width, 352)
        compare(iconCol(c).x, 20)                   // padding-left: $spacing-base-loose
        compare(iconCol(c).y, 16)                   // padding-top: $spacing-base
        compare(iconCol(c).width, 24)               // $width-notification_notice-icon
        compare(iconCol(c).height, 20)
        compare(column(c).x, 20 + 24 + 12)          // 图标宽 + icon-marginRight
        compare(column(c).y, 16)
        compare(closeWrap(c).width, 24)
        compare(closeWrap(c).height, 24)            // &-icon-close { height: $width-icon-extra-large }
        compare(closeWrap(c).x, c.width - 12 - 24)  // padding-right: $spacing-base-tight
        compare(closeWrap(c).y, 16)
        compare(c.sideWidth, 24 + 12 + 8 + 24)
        compare(c.columnWidth, 352 - 20 - 12 - 68)
        compare(column(c).width, c.columnWidth)
    }

    function test_typographyTokens() {
        const t = host()
        t.info({ title: "Hi, Bytedance", content: "ies dance dance dance" })
        const c = card(t, 0)
        compare(titleText(c).font.pixelSize, 16)    // @mixin font-size-header-6
        compare(titleText(c).lineHeight, 22)
        compare(titleText(c).font.weight, 600)      // $font-notification_notice_title-fontWeight
        compare(bodyText(c).font.pixelSize, 14)     // @mixin font-size-regular
        compare(bodyText(c).lineHeight, 20)
        compare(bodyText(c).font.weight, 400)       // $font-notification_notice_content-fontWeight
        // 官方两个文本都写了 word-wrap/overflow-wrap: break-word ⇒ 超长单词也要硬折
        compare(titleText(c).wrapMode === Text.WrapAtWordBoundaryOrAnywhere, true)
        compare(bodyText(c).wrapMode === Text.WrapAtWordBoundaryOrAnywhere, true)
        compare(titleText(c).y, 0)                  // content-wrapper 顶部对齐
        compare(bodyText(c).y, c.titleBox + 4)      // $spacing-notification_notice_title-marginBottom
    }

    // 行高 = flex 行里最高的那个 item：字形 20 / 正文列 / 关闭按钮 24
    // 官方两个文本都写了 word-wrap / overflow-wrap: break-word ⇒ 一个长过整行的「单词」也要硬折。
    // Text.WordWrap 只在空格处折，那样这段没有空格的正文会一行溢出；这条盯着它必须折起来。
    function test_longWordBreaksInsteadOfOverflowing() {
        const t = host()
        t.info({ content: testCase.hugeText + testCase.hugeText })
        wait(20)
        const c = card(t, 0)
        compare(c.width, t.container.width - 40)    // 封顶在容器宽减左右 20
        verify(c.contentNatural > c.columnWidth)     // 不折就是一行放不下
        verify(c.contentBox > 20)                   // 于是必须折成不止一行
        verify(c.height > 56)
    }

    function test_heightTitleAndContent() {
        const t = host()
        t.info({ title: "Hi, Bytedance", content: "ies dance dance dance" })
        const c = card(t, 0)
        compare(c.titleBox, 22)
        compare(c.contentBox, 20)
        compare(c.columnHeight, 22 + 4 + 20)
        compare(c.rowHeight, 46)
        compare(c.height, 16 + 46 + 16)             // 实测 78
    }

    function test_heightTitleOnly() {
        const t = host()
        t.info({ title: "Only a title" })
        const c = card(t, 0)
        compare(c.columnHeight, 26)                 // 标题的 4px 下外边距也算进行里
        compare(c.height, 16 + 26 + 16)             // 实测 58
    }

    function test_heightContentOnlyNeedsCloseButton() {
        const t = host()
        t.info({ content: "content only" })
        const c = card(t, 0)
        compare(c.columnHeight, 20)
        compare(c.rowHeight, 24)                    // 关闭按钮那 24 把行撑高
        compare(c.height, 56)                       // 实测 56
        t.info({ content: "content only", showClose: false })
        const bare = card(t, 0)                     // 最新那条在最前
        compare(bare.rowHeight, 20)                 // 没有关闭按钮就没有那个 24 的候选
        compare(bare.height, 52)                    // 实测 52
    }

    function test_heightIconOnlyRow() {
        const t = host()
        // 正文与标题都空：行高取字形 20 与关闭按钮 24 里更高的那个
        t.info({ icon: "vigo_logo" })
        const c = card(t, 0)
        compare(c.columnHeight, 0)
        compare(c.rowHeight, 24)
        compare(c.height, 56)
        t.info({ icon: "vigo_logo", showClose: false })
        const noClose = card(t, 0)
        compare(noClose.rowHeight, 20)              // 只剩字形 20
        compare(noClose.height, 52)
    }

    function test_lightBorderAddsTwoPixels() {
        const t = host()
        t.info({ content: "same content" })
        t.info({ content: "same content", theme: "light" })
        const light = card(t, 0)                    // 最新那条在最前
        const normal = card(t, 1)
        // 官方 notice 是 content-box，1px 描边长在盒子外面（实测同样内容 52 → 54）
        compare(normal.borderWidth, 0)
        compare(light.borderWidth, 1)
        compare(light.height, normal.height + 2)
        compare(light.naturalWidth, normal.naturalWidth + 2)
        compare(iconCol(normal).x, 20)
        compare(iconCol(light).x, 21)               // 描边把内容整体让进 1px
        compare(column(light).x, 57)                // 20 + 24 + 12 再加 1px 描边
        compare(closeWrap(light).x, light.width - 1 - 12 - 24)
        compare(closeWrap(normal).x, normal.width - 12 - 24)
    }

    function test_showCloseFalseRemovesButtonAndItsWidth() {
        const t = host()
        t.info({ content: "x" })
        t.info({ content: "x", showClose: false })
        const withClose = card(t, 1)
        const noClose = card(t, 0)                  // 最新那条在最前
        compare(withClose.sideWidth, 24 + 12 + 8 + 24)
        compare(noClose.sideWidth, 24 + 12)         // 只剩图标列那一段
        compare(closeWrap(noClose).visible, false)
        // 正文因此能多拿 8 + 24 的宽度（两条被拉成同宽，差值就是省下来的关闭按钮那一栏）
        compare(noClose.columnWidth, withClose.columnWidth + 32)
        compare(noClose.width, withClose.width)
    }

    function test_noIconNoCloseWidensColumn() {
        const t = host()
        t.open({ content: "x", showClose: false })
        const c = card(t, 0)
        compare(c.sideWidth, 0)
        compare(column(c).x, 20)
        compare(c.columnWidth, c.width - 20 - 12)
    }

    function test_longContentStretchesWholeList() {
        const t = host()
        t.info({ content: "short" })
        t.info({ content: testCase.longText })
        const wide = card(t, 0)                     // 最新那条在最前
        const narrow = card(t, 1)
        verify(wide.naturalWidth > 352)
        compare(narrow.naturalWidth, 352)
        // 官方一条列表是 shrink-to-fit：所有卡片被拉成最宽那张的宽度
        compare(narrow.width, wide.width)
        verify(narrow.width > 352)
        compare(narrow.width, Math.min(wide.naturalWidth, t.container.width - 40))
        compare(narrow.columnWidth, wide.columnWidth)
    }

    // 内容撑出来的那个宽度是**边框盒**：官方 .semi-notification-notice 是 width:auto 的
    // 块级 flex 容器，padding 算在宽度里面。少算一次左右 padding，卡片就会比正文的
    // 自然宽窄 32px，一行放得下的话被白折成两行（行高从 52 变 72）。
    function test_contentWidthIsBorderBoxSoTextStaysOnOneLine() {
        const t = host()
        t.open({ content: testCase.longText, showClose: false })
        const c = card(t, 0)
        verify(c.naturalWidth > 352)
        verify(c.naturalWidth < t.container.width - 40)   // 没被封顶，量的是自然宽
        compare(Math.round(c.width), 20 + 12 + Math.round(c.columnNatural))
        compare(Math.round(c.columnWidth), Math.round(c.columnNatural))
        compare(c.implicitHeight, 16 + 20 + 16)           // 一行正文
    }

    function test_listWidthCappedByContainer() {
        const t = host()
        t.info({ content: testCase.hugeText })
        const c = card(t, 0)
        // 封顶到可用宽减去卡片左右各 20 的外边距（实测列表右缘贴视口右缘、卡片再让 20）
        verify(c.naturalWidth > t.container.width - 40)
        compare(c.width, t.container.width - 40)
        compare(abs(c).x + c.width, t.container.width - 20)
    }

    function test_wideCardLeavesOtherListAlone() {
        const t = host()
        t.info({ content: testCase.longText, position: "topRight" })
        t.info({ content: "short", position: "bottomLeft" })
        const right = card(t, 1)
        const left = card(t, 0)
        verify(right.width > 352)
        compare(left.width, 352)                    // 分组按 position 隔开，互不拉伸
        compare(list(t, "bottomLeft").width, 392)
    }

    // ---------------------------------------------------------------- 六档位置
    function test_sixPositionPlacement() {
        const t = host()
        const positions = ["top", "bottom", "topLeft", "topRight", "bottomLeft", "bottomRight"]
        const W = t.container.width
        const H = t.container.height
        for (let i = 0; i < positions.length; ++i)
            t.info({ title: "T", content: "C", position: positions[i] })
        for (let i = 0; i < positions.length; ++i) {
            const c = card(t, positions.length - 1 - i)   // 最新那条在最前
            const p = abs(c)
            const name = positions[i]
            compare(c.width, 352, name)
            if (name === "topLeft" || name === "bottomLeft")
                compare(p.x, 20, name)
            else if (name === "topRight" || name === "bottomRight")
                compare(p.x + c.width, W - 20, name)
            else
                compare(Math.round(p.x - 20 - (W - c.width - 40) / 2), 0, name)
            if (name === "top" || name === "topLeft" || name === "topRight")
                compare(p.y, 20, name)
            else
                compare(p.y + c.height, H - 20, name)
        }
    }

    function test_stackingMarginsCollapse() {
        const t = host()
        t.info({ title: "T", content: "C" })
        t.info({ title: "T", content: "C" })
        t.info({ title: "T", content: "C" })
        const a = card(t, 0)
        const b = card(t, 1)
        const c = card(t, 2)
        const h = a.height
        // 相邻 20px 外边距折叠成一条 20 的缝：首条前 20、条间 20、末条后 20
        compare(a.y, 20)
        compare(b.y, 20 + h + 20)
        compare(c.y, 20 + 2 * (h + 20))
        const slot = list(t, "topRight")
        compare(slot.height, 20 + 3 * h + 3 * 20)
        compare(slot.width, a.width + 40)
        compare(slot.y, 0)
        compare(slot.x, t.container.width - slot.width)
    }

    function test_bottomListGrowsUpwards() {
        const t = host()
        t.info({ title: "A", content: "C", position: "bottomLeft" })
        t.info({ title: "B", content: "C", position: "bottomLeft" })
        const oldCard = card(t, 1)
        const newCard = card(t, 0)
        // 官方 addNotice 是 prepend、DOM 顺序自上而下 ⇒ 新的在上、旧的贴着下边缘
        verify(newCard.y < oldCard.y)
        compare(abs(oldCard).y + oldCard.height, t.container.height - 20)
        compare(abs(newCard).y, t.container.height - 40 - oldCard.height - newCard.height)
    }

    function test_eachPositionHasItsOwnList() {
        const t = host()
        t.info({ content: "a", position: "top" })
        t.info({ content: "b", position: "topLeft" })
        t.info({ content: "c", position: "top" })
        compare(card(t, 0).parent, list(t, "top"))
        compare(card(t, 1).parent, list(t, "topLeft"))
        compare(card(t, 2).parent, list(t, "top"))
        compare(list(t, "top").height, card(t, 0).height + card(t, 2).height + 60)
        compare(list(t, "topLeft").height, card(t, 1).height + 40)
        compare(list(t, "topRight").height, 0)
    }

    function test_illegalPositionFallsBackToTopRight() {
        const t = host()
        // 官方这里不校验，非法值会在分组渲染时抛异常；端口退化成默认档（记在文件头）
        t.info({ content: "x", position: "middle" })
        compare(t.items[0].position, "topRight")
        compare(card(t, 0).parent, list(t, "topRight"))
    }

    // ---------------------------------------------------------------- 时长与关闭
    function test_durationIsSeconds() {
        const t = make("Notification { motion: false }")
        testCase.alive.push(t)
        t.info({ content: "x", duration: 0.3 })
        wait(120)
        compare(t.items.length, 1)                  // 120ms 还不到 0.3s
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_containerDurationIsTheDefault() {
        const t = make("Notification { motion: false; duration: 0.25 }")
        testCase.alive.push(t)
        t.info({ content: "x" })
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_zeroDurationNeverAutoCloses() {
        const t = host()
        t.info({ content: "x", duration: 0 })
        wait(300)
        compare(t.items.length, 1)
        compare(t.items[0].removed, false)
    }

    function test_nonNumberDurationStartsNoTimer() {
        const t = host()
        // 官方 if (duration && isNumber(duration))：字符串那种连定时器都不装
        t.info({ content: "x", duration: "0.2" })
        wait(300)
        compare(t.items.length, 1)
        compare(t.items[0].removed, false)
    }

    function test_closeByIdSkipsOnClose() {
        const t = host()
        let closed = 0
        const id = t.info({ content: "x", onClose: function () { closed = closed + 1 } })
        t.close(id)
        compare(closed, 0)                          // 官方 removeNotice 只摘记录，不通知 item
        compare(t.items.length, 1)
        compare(t.items[0].removed, true)
        compare(t.has(id), false)                   // has() 只看还在位的那些
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_timerFireRunsOnClose() {
        const t = make("Notification { motion: false }")
        testCase.alive.push(t)
        let closed = 0
        t.info({ content: "x", duration: 0.2, onClose: function () { closed = closed + 1 } })
        tryVerify(function () { return t.items.length === 0 })
        wait(60)
        compare(closed, 1)                          // 计时到点走 item 自己的 close() ⇒ notifyClose
    }

    function test_closeButtonRunsOnCloseClickThenOnClose() {
        const t = host()
        let clickedId = ""
        let closed = 0
        const id = t.info({
            content: "x",
            onCloseClick: function (nid) { clickedId = nid },
            onClose: function () { closed = closed + 1 }
        })
        mouseClick(closer(card(t, 0)))
        compare(clickedId, id)                      // 官方先 onCloseClick(this.props.id)
        compare(closed, 1)                          // 再 foundation.close() ⇒ notifyClose
        compare(t.items.length, 1)
        compare(t.items[0].removed, true)
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_cardClickRunsOnClick() {
        const t = host()
        let clicks = 0
        t.info({ title: "T", content: "x", onClick: function () { clicks = clicks + 1 } })
        const c = card(t, 0)
        // 官方 onClick 挂在 .semi-notification-notice 整张盒子上
        mouseClick(c, c.width / 2, c.height - 6)
        compare(clicks, 1)
        compare(t.items.length, 1)                  // 点正文不关闭
        compare(t.items[0].removed, false)
        mouseClick(closer(c))
        compare(t.items[0].removed, true)
        compare(clicks, 1)                          // × 那条不再触发卡片的 onClick
    }

    function test_hoverPausesAndLeaveRestartsFullDuration() {
        const t = make("Notification { motion: false }")
        testCase.alive.push(t)
        t.info({ content: "x", duration: 0.3 })
        const c = card(t, 0)
        mouseMove(c, c.width / 2, c.height / 2)
        wait(60)
        // 官方 onMouseEnter 只 _clearCloseTimer，不记还剩多少
        wait(500)
        compare(t.items.length, 1)
        compare(t.items[0].removed, false)
        mouseMove(testCase, 2, testCase.height / 2)
        wait(60)
        // onMouseLeave 是 _startCloseTimer ⇒ 重新计满整个 0.3s
        wait(120)
        compare(t.items.length, 1)
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_destroyAllAnimatesAndSkipsOnClose() {
        const t = host()
        let closed = 0
        t.info({ content: "a", onClose: function () { closed = closed + 1 } })
        t.info({ content: "b", onClose: function () { closed = closed + 1 } })
        t.destroyAll()
        compare(closed, 0)                          // 官方 updateNotices([], notices) 不跑 onClose
        compare(t.items.length, 2)
        compare(t.items[0].removed, true)
        compare(t.items[1].removed, true)
        // 和 Toast 相反：Toast 的 destroyAll 是逐条 close，这里是整条列表进 removedItems ⇒ 播退场
        verify(t.items[0].card !== null)
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_destroyAllDropsCardsAlreadyExiting() {
        const t = host()
        const a = t.info({ content: "a" })
        t.info({ content: "b" })
        t.close(a)                                  // 第一条已经在退场
        compare(t.items.length, 2)
        t.destroyAll()
        // 官方 removedItems 被整份换成「还在位的那些」⇒ 正在退场那张立刻消失
        compare(t.items.length, 1)
        compare(t.items[0].removed, true)
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_destroyAllIsNoopWhenNothingIsInPlace() {
        const t = host()
        t.destroyAll()
        compare(t.items.length, 0)
        t.info({ content: "a" })
        const id = t.items[0].id
        t.close(id)
        tryVerify(function () { return t.items.length === 0 })
        t.destroyAll()                              // 官方 notices.length 那一关拦住
        compare(t.items.length, 0)
    }

    // ---------------------------------------------------------------- 按 id 更新
    function test_openWithKnownIdReplacesInPlace() {
        const t = host()
        const id = t.info({ title: "Hi", content: "before" })
        t.info({ id: id, content: "after" })
        compare(t.items.length, 1)                  // 官方 has(id) 命中就走 update
        const c = card(t, 0)
        compare(c.contentText, "after")
        // title/content 在 defaultConfig 里 ⇒ 没写就是把它抹成空串（官方语义）
        compare(c.titleText, "")
        compare(titleText(c).visible, false)
        compare(c.type, "info")                     // info 那个 type 每次都重钉
    }

    function test_updateKeepsKeysOutsideDefaultConfig() {
        const t = host()
        const id = t.success({
            title: "Hi",
            content: "before",
            theme: "light",
            icon: "vigo_logo",
            showClose: false
        })
        t.open({ id: id, content: "after" })
        const c = card(t, 0)
        // theme / icon / showClose 不在 defaultConfig 里 ⇒ 没给就保留原值
        compare(c.theme, "light")
        compare(c.icon, "vigo_logo")
        compare(c.showClose, false)
        compare(surface(c).border.width, 1)
        compare(glyph(c).name, "vigo_logo")
        // defaultConfig 那六档每次都覆盖：type 被 open 钉成 default、title 抹平、位置回默认
        compare(c.type, "default")
        compare(c.titleText, "")
        compare(c.position, "topRight")
        compare(c.contentText, "after")
    }

    function test_updateRestartsCloseTimer() {
        const t = make("Notification { motion: false; duration: 0.3 }")
        testCase.alive.push(t)
        const id = t.info({ content: "a" })
        wait(200)
        t.info({ id: id, content: "b" })            // 官方 refFn 里 restartCloseTimer
        wait(200)                                   // 距第一次装填已 400ms > 300ms
        compare(t.items.length, 1)                  // 还活着 ⇒ 计时器被重头算过
        compare(t.items[0].removed, false)
        compare(t.items[0].card.contentText, "b")
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_updateMovesNoticeToAnotherList() {
        const t = host()
        const id = t.info({ title: "T", content: "a", position: "topRight" })
        compare(card(t, 0).parent, list(t, "topRight"))
        t.info({ id: id, content: "b", position: "bottomLeft" })
        const c = card(t, 0)
        compare(c.parent, list(t, "bottomLeft"))
        compare(c.position, "bottomLeft")
        compare(list(t, "topRight").height, 0)
        compare(abs(c).x, 20)
        compare(abs(c).y + c.height, t.container.height - 20)
        t.close(id)
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_updateRecomputesHeightAndRelayouts() {
        const t = host()
        t.info({ content: "lower" })                // 先弹的那条排在下面
        const id = t.info({ content: "a" })         // 新的在最上面
        const lower = card(t, 1)
        const top = card(t, 0)
        const before = lower.y
        compare(top.height, 56)
        compare(before, 20 + 56 + 20)
        // 三段才够长：单靠一段在 offscreen 的默认字体下可能刚好还不折行
        t.update(id, { content: testCase.hugeText + testCase.hugeText + testCase.hugeText })
        wait(20)                                    // height 是几何量，要等一轮 polish 才刷新
        verify(top.height > 56)                     // 正文换成长句，折行把卡片撑高
        compare(lower.y, 20 + top.height + 20)      // 下面那条跟着往下挪
        verify(before < lower.y)
    }

    function test_updateUnknownIdDoesNothing() {
        const t = host()
        t.info({ content: "a" })
        compare(t.update("nope", { content: "b" }), false)
        compare(t.items.length, 1)
        compare(card(t, 0).contentText, "a")
    }

    function test_closeUnknownIdDoesNothing() {
        const t = host()
        t.info({ content: "a" })
        t.close("nope")
        compare(t.items.length, 1)
        compare(t.items[0].removed, false)
        compare(t.has("a"), false)
    }

    // ---------------------------------------------------------------- 富文本两支
    function test_richContentReadsDefiningScope() {
        const t = host()
        testCase.contextName = "Light"
        t.info({ content: richBody })
        const c = card(t, 0)
        compare(contentLoader(c).active, true)
        compare(bodyText(c).visible, false)
        // Component 由 Loader 按它自己那份作用域实例化 ⇒ 读得到页面属性（官方 contextHolder 的等价物）。
        // 代理项就是那个 Text 本身，findChild 只往下找，所以直接读 item
        const line = contentLoader(c).item
        compare(line.objectName, "probeLine")
        compare(line.text, "ReachableContext: Light")
        compare(c.width, 352)
        testCase.contextName = "Heavy and then a long tail of words so the line really does get wide"
        wait(20)
        compare(line.text, "ReachableContext: " + testCase.contextName)
        // 富文本自己变宽 ⇒ 卡片与整条列表都得跟着重排（靠 layoutDirty 那条连线，宿主这一侧没人再调 _relayout）
        verify(c.naturalWidth > 352)
        verify(c.width > 352)
        compare(list(t, "topRight").width, c.width + 40)
        testCase.contextName = "Light"
        wait(20)
        compare(c.width, 352)
    }

    Component {
        id: richBody

        Text {
            objectName: "probeLine"
            text: "ReachableContext: " + testCase.contextName
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
        }
    }

    function test_richTitleUsesLoaderBranch() {
        const t = host()
        t.info({ title: richTitle, content: "x" })
        const c = card(t, 0)
        compare(titleLoader(c).active, true)
        compare(titleText(c).visible, false)
        compare(titleLoader(c).item.objectName, "probeTitle")
        compare(titleLoader(c).item.text, "rich title")
        compare(c.titleShown, true)
        compare(c.titleBox, 22)
        compare(bodyText(c).y, 26)                  // 标题盒子 + 4px 下边距
        compare(c.height, 78)
    }

    Component {
        id: richTitle

        Text {
            objectName: "probeTitle"
            text: "rich title"
            font.pixelSize: 16
            lineHeight: 22
            lineHeightMode: Text.FixedHeight
        }
    }

    // ---------------------------------------------------------------- 进出场动画
    function test_motionFalseSkipsAnimation() {
        const t = host()
        t.info({ content: "x" })
        const c = card(t, 0)
        compare(c.reveal, 1)
        compare(c.opacity, 1)
        compare(abs(c).x, t.container.width - 20 - c.width)
    }

    function test_enterSlidesInFromItsEdge() {
        const t = make("Notification { duration: 0 }")
        testCase.alive.push(t)
        t.info({ title: "T", content: "C", position: "topRight" })
        const c = card(t, 0)
        // 动画起点：translateX(100%) + opacity 0（$animation_opacity-notification-show）
        compare(c.reveal, 0)
        compare(c.opacity, 0)
        compare(abs(c).x, t.container.width - 20)
        tryCompare(c, "reveal", 1, 2000)
        compare(c.opacity, 1)
        compare(abs(c).x, t.container.width - 20 - c.width)
    }

    function test_enterTopSlidesFromAbove() {
        const t = make("Notification { duration: 0 }")
        testCase.alive.push(t)
        t.info({ title: "T", content: "C", position: "top" })
        const c = card(t, 0)
        compare(c.reveal, 0)
        compare(abs(c).y, 20 - c.height)            // translateY(-100%)
        tryCompare(c, "reveal", 1, 2000)
        compare(abs(c).y, 20)
    }

    function test_enterBottomSlidesFromBelow() {
        const t = make("Notification { duration: 0 }")
        testCase.alive.push(t)
        t.info({ title: "T", content: "C", position: "bottom" })
        const c = card(t, 0)
        compare(c.reveal, 0)
        compare(abs(c).y, t.container.height - 20)  // translateY(100%)
        tryCompare(c, "reveal", 1, 2000)
        compare(abs(c).y + c.height, t.container.height - 20)
    }

    function test_exitAnimationThenDispose() {
        const t = make("Notification { duration: 0 }")
        testCase.alive.push(t)
        const id = t.info({ title: "T", content: "C" })
        tryCompare(card(t, 0), "reveal", 1, 2000)
        t.close(id)
        const c = card(t, 0)
        compare(c.removed, true)
        verify(c.reveal > 0.5)                      // 从当前位置往 0 播，不是直接消失
        tryVerify(function () { return t.items.length === 0 })
    }

    function test_motionFalseExitStillDisposes() {
        const t = host()
        const id = t.info({ content: "x" })
        t.close(id)
        tryVerify(function () { return t.items.length === 0 })
    }

    // ---------------------------------------------------------------- 可访问性
    function test_accessibilityRoleAndName() {
        const t = host()
        t.info({ title: "部署完成", content: "x" })
        const c = card(t, 0)
        compare(c.Accessible.role, Accessible.Alert)
        compare(c.Accessible.name, "部署完成")       // 官方 aria-labelledby 指向标题那个节点
    }

    // ---------------------------------------------------------------- 容器换了要重排
    function test_containerResizeRefitsLists() {
        const t = host()
        const holder = make("Item { width: 600; height: 500 }")
        t.getPopupContainer = function () { return holder }
        t.info({ content: "x" })
        compare(wrapper(t).parent, holder)
        const c = card(t, 0)
        compare(abs(c).x + c.width, 600 - 20)
        holder.width = 480
        wait(20)
        compare(abs(c).x + c.width, 480 - 20)       // 右缘仍贴着容器内边 20
        holder.height = 320
        wait(20)
        compare(abs(c).y, 20)
        holder.width = 300
        wait(20)
        // min-width 压过封顶：官方也是让卡片溢出容器
        compare(c.width, 352)
        // holder 不销毁：wrapper 还挂在它上面
    }
}
