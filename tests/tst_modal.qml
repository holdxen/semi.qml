import QtQuick
import QtQuick.Controls as C
import QtTest
import Semi

// Modal 用例。规格照 semi-ui/modal/{Modal,ModalContent,ConfirmModal,confirm}.tsx +
// semi-foundation/modal/{modalFoundation,modalContentFoundation}.ts +
// modal/{modal,animation,variables}.scss；期望数字全部来自浏览器里真 React + semi.css
// 的量取（官方默认头部 448×236、带图标头部 448×202、header=null 448×182、
// 无头部 448×178、命令式 448×158、footerFill 每颗 193、medium 684、large 920、
// full-width 容器宽−64、居中 448×354）。
TestCase {
    id: testCase

    name: "Modal"
    when: windowShown
    width: 705
    height: 1200

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "modal")
    }

    function part(root, name) {
        return testCase.findChild(root, name)
    }

    // 打开并等进场动画（120ms）播完。qml 参数是完整的 "Modal { … }" 片段
    function openModal(qml) {
        const m = make(qml)
        m.visible = true
        wait(240)
        return m
    }

    function destroyAll(...items) {
        for (let i = 0; i < items.length; ++i)
            items[i].destroy()
    }

    // JS 函数体里不能直接写 Component 对象，需要节点的用例用这几份
    // （Qt.createQmlObject 的字符串里也不能：`Modal { a: Component {…}; …}` 解析会歪）
    Component {
        id: nodeContent

        Text {
            text: "节点内容"
        }
    }

    Component {
        id: customHeaderNode

        Rectangle {
            implicitHeight: 40
            color: "transparent"
        }
    }

    // 只写 height、没写 implicitHeight 的节点：Loader 自己那条 `height:` 是显式宽高，
    // 会把载入项的尺寸接管过来（这里接成 implicitHeight = 0），所以整节点塌成 0。
    // 组件头注释里那条「自定义节点请写 implicit 尺寸」的契约由 `test_heightOnlyNodeIsNotMeasured` 钉住。
    Component {
        id: heightOnlyHeaderNode

        Rectangle {
            height: 40
            color: "transparent"
        }
    }

    Component {
        id: customFooterNode

        Button {
            text: "Yes, I Understand"
        }
    }

    // ---------------- 属性面与默认值 ----------------

    function test_defaultProps() {
        const m = make("Modal { }")
        compare(m.size, "small")
        compare(m.okType, "primary")
        compare(m.hasCancel, true)
        compare(m.closable, true)
        compare(m.mask, true)
        compare(m.maskClosable, true)
        compare(m.closeOnEsc, true)
        compare(m.centered, false)
        compare(m.motion, true)
        compare(m.fullScreen, false)
        compare(m.footerFill, false)
        compare(m.confirmLoading, false)
        compare(m.cancelLoading, false)
        compare(m.zIndex, 1000)
        compare(m.closeIcon, "close")
        compare(m.okText, "")
        compare(m.cancelText, "")
        compare(m.className, "")
        compare(m.visible, false)
        m.destroy()
    }

    // 官方 Modal.defaultProps 把 visible 定为 false，所有关闭路径又都只 notify ⇒
    // Qt 那套「点外面自动关」必须整个关掉，否则 Esc 会把绑定打断。
    function test_popupShellIsFullyControlled() {
        const m = make("Modal { }")
        compare(m.modal, true, ".semi-modal-wrap 整层拦点击")
        compare(m.dim, false, "遮罩自绘")
        compare(m.padding, 0)
        compare(m.closePolicy, C.Popup.NoAutoClose)
        // zIndex 收下但不生效：层序由 Overlay 的打开顺序给，本库弹层一族都不写 z
        // （单把 Modal 抬到 1000 会盖掉对话框里再开的下拉）
        compare(m.zIndex, 1000)
        compare(m.z, 0, "zIndex 不落到 z 上")
        m.destroy()
    }

    // 样式默认的 Popup background 是一块不透明直角矩形（cocoa 实测 palette.window = #1e1e1e），
    // 挂在 panel 外面 ⇒ 进/出场那条 Transition 只动 panel，它整块留在原地：卡片底下先露出
    // 一块黑框，停稳后四角还各比圆角卡片多出一截直角。底色与投影都由 panel 里的
    // modalSurface + modalShadow 画，所以样式这一层必须整个关掉（background: null）。
    function test_shellPaintsOnlyInsideThePanel() {
        const m = openModal('Modal { title: "t" }')
        verify(m.background === null, "样式那块底矩形要置 null")
        const panel = part(m, "modalPanel")
        compare(part(m, "modalSurface").parent, panel, "底色层要挂在 panel 里，动画才带着它一起缩")
        compare(part(m, "modalShadow").parent, panel, "投影层同上")
        m.destroy()
    }

    function test_sizeWidths() {
        const small = make('Modal { size: "small" }')
        const medium = make('Modal { size: "medium" }')
        const large = make('Modal { size: "large" }')
        const full = make('Modal { size: "full-width" }')
        compare(small.width, 448, "$width-modal_small")
        compare(medium.width, 684, "$width-modal_medium")
        compare(large.width, 920, "$width-modal_large")
        compare(full.width, full.hostWidth - 64, "$width-modal_full_width = calc(100vw - 64px)")
        destroyAll(small, medium, large, full)
    }

    // 官方 getDialogElement 里 inline style 的 width 排在 size 类之后 ⇒ width 盖 size
    function test_widthPropOverridesSize() {
        const m = make('Modal { size: "large"; width: 600 }')
        compare(m.width, 600)
        m.destroy()
    }

    // 内容区 = 面板宽 − 左右各 24（paddingX）− 左右各 1（描边），实测 448 ⇒ 398
    function test_blockWidth() {
        const m = make("Modal { }")
        compare(m.blockWidth, 398)
        compare(m.contentPaddingX, 24)
        compare(m.borderWidth, 1)
        m.destroy()
    }

    // .semi-modal-content 只有左右 24 的内边距，纵向那条 0 ⇒ 三块起点就是描边 + 内边距
    function test_stackOffsetIsBorderPlusPadding() {
        const m = openModal('Modal { title: "t" }')
        const stack = part(m, "modalStack")
        compare(stack.x, 1 + 24, "$width-modal_content-border + $spacing-modal_content-paddingX")
        compare(stack.y, 1, "纵向没有 padding，只剩描边")
        compare(stack.width, 398)
        m.destroy()
    }

    // 面板底色吃 $color-modal-bg = bg-2；浅色档 bg-1 / bg-2 不同值，改令牌才分得开
    function test_surfaceFollowsBg2Token() {
        const m = openModal('Modal { title: "t" }')
        Theme.current.colorBg2 = "#0f1e2d"
        compare(part(m, "modalSurface").color.toString(), "#0f1e2d",
            "表面色就是 color-bg-2 那一条，不是 bg-1 / bg-3")
        m.destroy()
    }

    // ---------------- 位置 ----------------

    // .semi-modal { margin: 80px auto }
    function test_sitsEightyFromTopAndCentred() {
        const m = openModal('Modal { title: "t" }')
        compare(m.y, 80, "$spacing-modal-marginY")
        compare(m.x, (m.hostWidth - 448) / 2)
        m.destroy()
    }

    function test_centeredVertically() {
        const m = openModal('Modal { title: "t"; centered: true }')
        const host = m.host
        verify(host !== null, "host 就是弹层实际挂上去的那个项（Overlay）")
        compare(m.y, (host.height - m.height) / 2, "面板在 host 项里垂直居中")
        // 再用窗口坐标钉一遍：host 项在窗口里的 (0,0) 与面板顶边的关系。
        // 这一档必须跟着 host 走 —— TestCase 自己那个项是 705x1200，而 cocoa 上窗口高被屏幕
        // 夹成 926（实测 host 705x926、面板 y 386 == (926-154)/2），拿声明项的 1200 去算
        // 就会差出 123px，那条 1200 写死的断言在 cocoa 上就是这么红的。
        const originY = host.mapToItem(null, 0, 0).y
        const panelTop = part(m, "modalPanel").mapToItem(null, 0, 0).y
        compare(Math.round(panelTop), Math.round(originY + (host.height - m.height) / 2),
            "窗口坐标里的顶边 = host 项在窗口里的 y + 居中偏移")
        compare(Math.round(part(m, "modalWrap").mapToItem(null, 0, 0).y), Math.round(originY),
            "遮罩从 host 项顶部铺起，不跟着面板一起往下偏")
        m.destroy()
    }

    // 官方 centered 是 flex-start + margin:auto：装不下时 auto 边距塌成 0 ⇒ 顶对齐
    function test_centeredFallsBackToTopWhenTallerThanHost() {
        const m = openModal('Modal { title: "t"; centered: true; height: 2000 }')
        compare(m.y, 0, "比容器还高就贴顶")
        m.destroy()
    }

    // ---------------- 面板表面 ----------------

    function test_surfaceTokens() {
        const m = openModal('Modal { title: "t" }')
        const surface = part(m, "modalSurface")
        compare(surface.radius, Theme.current.radiusLarge, "$radius-modal_content = 12")
        compare(surface.border.width, 1, "$width-modal_content-border")
        compare(surface.border.color.toString(), Theme.current.colorBorder.toString())
        compare(surface.color.toString(), Theme.current.colorBg2.toString(), "$color-modal-bg")
        m.destroy()
    }

    function test_fullScreenClearsRadiusAndBorder() {
        const m = openModal('Modal { title: "全屏"; fullScreen: true }')
        const surface = part(m, "modalSurface")
        compare(m.width, m.hostWidth)
        compare(m.height, m.hostHeight)
        compare(m.x, 0)
        compare(m.y, 0, "全屏把 80 的 margin 也取消")
        compare(surface.radius, 0, "$radius-modal_content_fullscreen")
        compare(surface.border.width, 0)
        compare(part(m, "modalStack").width, m.hostWidth - 50)
        m.destroy()
    }

    function test_heightPropFixesPanel() {
        const m = openModal('Modal { title: "t"; height: 300 }')
        compare(m.height, 300)
        m.destroy()
    }

    // ---------------- 遮罩与 wrap ----------------

    function test_maskColorAndToggle() {
        const on = openModal('Modal { title: "t" }')
        const mask = part(on, "modalMask")
        compare(mask.visible, true)
        compare(mask.color.toString(), Theme.current.colorOverlayBg.toString(),
            "$color-modal_mask-bg = var(--semi-color-overlay-bg)")
        compare(mask.color.a, 0.6, "浏览器实测 rgba(22,22,26,.6)")
        on.destroy()

        const off = openModal('Modal { title: "t"; mask: false }')
        compare(part(off, "modalMask").visible, false)
        compare(off.modal, true, "mask 只改视觉，wrap 照样拦点击")
        off.destroy()
    }

    // wrap 是面板的兄弟层，靠负偏移铺满整个容器
    function test_wrapCoversWholeHost() {
        const m = openModal('Modal { title: "t" }')
        const wrap = part(m, "modalWrap")
        compare(wrap.width, m.hostWidth)
        compare(wrap.height, m.hostHeight)
        compare(wrap.x + m.x, 0)
        compare(wrap.y + m.y, 0)
        m.destroy()
    }

    // ---------------- 头部三档 ----------------

    // 默认头部：24 / 24 / 24（$spacing-modal_header-marginY），标题 18/24/600，× 24×24
    function test_defaultHeaderMetrics() {
        const m = openModal('Modal { title: "基本对话框" }')
        const header = part(m, "modalHeader")
        const row = part(m, "modalHeaderRow")
        const title = part(m, "modalTitle")
        const close = part(m, "modalClose")
        compare(header.visible, true)
        compare(header.height, 72)
        compare(header.y, 0)
        compare(row.y, 24)
        compare(row.height, 24)
        compare(title.x, 0)
        compare(title.width, 374, "398 − 24（× 那一格）")
        compare(title.font.pixelSize, 18, "Typography.Title h5")
        compare(title.font.weight, Font.DemiBold, "$font-weight-bold = 600")
        compare(title.lineHeight, 24)
        compare(title.color.toString(), Theme.current.colorText0.toString())
        compare(close.width, 24)
        compare(close.height, 24)
        compare(close.x, 374)
        compare(close.y, 0, "align-items: flex-start ⇒ 与标题行顶对齐")
        m.destroy()
    }

    // body 的 margin / padding 都是 0，紧跟在头部块后面
    function test_bodyFollowsHeaderWithoutGap() {
        const m = openModal('Modal { title: "t"; Rectangle { width: parent.width; height: 82;'
            + ' color: "transparent" } }')
        const body = part(m, "modalBody")
        compare(m.headerBlockHeight, 72)
        compare(body.y, 72)
        compare(body.height, 82)
        // 官方实测：内容 448×236 = 2 描边 + 72 头部块 + 82 body + 80 页脚块
        compare(m.height, 236)
        m.destroy()
    }

    function test_iconShiftsTitleAndBody() {
        const m = openModal('Modal { title: "带图标的标题"; icon: "info_circle";'
            + ' Rectangle { width: parent.width; height: 48; color: "transparent" } }')
        const icon = part(m, "modalIcon")
        const title = part(m, "modalTitle")
        const scroll = part(m, "modalBodyScroll")
        compare(icon.width, 24, "$width-icon-extra-large")
        compare(icon.size, 24)
        compare(title.x, 36, "24 + 12（$spacing-modal_icon_wrapper-marginRight）")
        compare(title.width, 338)
        compare(scroll.x, 36, "$spacing-modal_content_withicon-marginLeft")
        compare(scroll.width, 362)
        compare(m.height, 202, "官方实测 448×202")
        m.destroy()
    }

    // 官方 .semi-modal-withIcon 只看 props.icon，头部为空时 body 也照移
    function test_iconIndentsBodyEvenWithoutHeader() {
        const m = openModal('Modal { header: null; icon: "info_circle";'
            + ' Rectangle { width: parent.width; height: 40; color: "transparent" } }')
        compare(part(m, "modalBodyScroll").x, 36)
        compare(part(m, "modalHeader").visible, false)
        m.destroy()
    }

    // 没 header 没 title 那一档：图标落在 body-wrapper 层里，跟着那两条 24 外边距走
    function test_noHeaderBranchIconSitsInWrapper() {
        const m = openModal('Modal { icon: "info_circle";'
            + ' Rectangle { width: parent.width; height: 40; color: "transparent" } }')
        const icon = part(m, "modalWrapperIcon")
        compare(m.hasHeaderBlock, false)
        compare(icon.visible, true, "这一档图标在 wrapper 层，不在头部")
        compare(part(m, "modalIcon").visible, false)
        compare(icon.y, 24, "$spacing-modal_header-marginY 那两条 24 在这一层照旧")
        compare(icon.size, 24)
        const scroll = part(m, "modalBodyScroll")
        compare(scroll.x, 36, "body 整体右移 36")
        compare(scroll.y, 24)
        // 与实测过的 448×178（内容 48）同一套算式：2 + (24 + max(40, 24) + 24) + 80
        compare(m.height, 170)
        m.destroy()
    }

    // header = null：整块不渲染，× 也不画（官方 renderBody 只在 hasHeader 为 false 那支放 closer）
    function test_headerNullDropsHeaderAndClose() {
        const m = openModal('Modal { header: null;'
            + ' Rectangle { width: parent.width; height: 100; color: "transparent" } }')
        compare(m.hasHeaderBlock, true)
        compare(m.headerTaken, false)
        compare(m.closeTaken, false)
        compare(part(m, "modalHeader").visible, false)
        compare(part(m, "modalClose").visible, false)
        compare(part(m, "modalWrapperClose").visible, false)
        const body = part(m, "modalBody")
        compare(body.y, 0, "上面那 24 是头部的外边距，头部没了它也没了")
        compare(body.height, 100)
        compare(m.height, 182, "官方实测 448×182")
        m.destroy()
    }

    // 没传 header 也没 title：body 外面套一层 body-wrapper（上下各 24），× 在这一层
    function test_noHeaderUsesWrapperBranch() {
        const m = openModal('Modal { Rectangle { width: parent.width; height: 48;'
            + ' color: "transparent" } }')
        compare(m.hasHeaderBlock, false)
        compare(m.headerTaken, false)
        compare(m.wrapperCloseTaken, true)
        const body = part(m, "modalBody")
        const close = part(m, "modalWrapperClose")
        compare(body.height, 24 + 48 + 24)
        compare(close.visible, true)
        compare(close.y, 24)
        compare(part(m, "modalBodyScroll").y, 24)
        compare(m.height, 178, "官方实测 448×178")
        m.destroy()
    }

    function test_customHeaderReplacesWholeBlock() {
        const m = openModal('Modal { title: "这一条不该出现";'
            + ' Rectangle { width: parent.width; height: 20; color: "transparent" } }')
        m.header = customHeaderNode
        wait(60)
        compare(m.headerTaken, true)
        compare(m.headerIsDefault, false)
        compare(m.headerBlockHeight, 40, "自定义头部没有那两条 24 外边距")
        compare(part(m, "modalHeaderNode").height, 40, "载入项量到 implicitHeight")
        compare(part(m, "modalHeaderRow").visible, false)
        compare(part(m, "modalTitle").visible, false)
        m.destroy()
    }

    // 只写 height、没写 implicitHeight 的自定义头部：Loader 自己那条 `height: item.implicitHeight`
    // 是显式宽高，会接管载入项的尺寸（qquickloader.cpp:632），于是节点被压成 0、头部块也是 0。
    // 组件头注释里「自定义节点请写 implicit 尺寸」这条契约由这一支钉住。
    function test_heightOnlyNodeIsNotMeasured() {
        const m = make('Modal { title: "t" }')
        m.header = heightOnlyHeaderNode
        m.visible = true
        wait(240)
        compare(m.customHeaderHeight, 0, "光写 height 的节点量不到高")
        compare(m.headerBlockHeight, 0, "头部块跟着是 0")
        compare(part(m, "modalHeaderNode").item.height, 0, "节点自己被 Loader 接管成 0")
        m.destroy()
    }

    function test_stringHeaderUsesRegularMetrics() {
        const m = openModal('Modal { header: "一段裸文字" }')
        const text = part(m, "modalHeaderText")
        compare(text.visible, true)
        compare(text.text, "一段裸文字")
        compare(text.font.pixelSize, 14)
        compare(text.lineHeight, 20, ".semi-modal 的 font-size-regular = 14 / 20")
        m.destroy()
    }

    function test_closableFalseHidesCloseKey() {
        const m = openModal('Modal { title: "t"; closable: false }')
        compare(m.headerCloseTaken, false)
        compare(part(m, "modalClose").visible, false)
        compare(part(m, "modalTitle").width, 398, "× 不在了，标题占满")
        m.destroy()
    }

    // 标题折行把那一行撑高时，× 仍贴行顶（align-items: flex-start），不是垂直居中
    function test_closeKeyStaysTopAlignedWhenTitleWraps() {
        const m = openModal('Modal { title: "这是一个很长很长会折到第二行的对话框标题，'
            + '用来把头部那一行撑高到两行文字的高度" }')
        const row = part(m, "modalHeaderRow")
        const close = part(m, "modalClose")
        verify(row.height > 24, "标题折行后行高要真被撑起来，否则这条测不到对齐方式")
        verify(close.height < row.height, "行高必须大于关闭键，顶对齐与居中才分得开")
        compare(close.y, 0, "flex-start ⇒ 贴行顶")
        m.destroy()
    }

    // 命令式那一支：.semi-modal-confirm .semi-modal-header { margin-bottom: 8px }
    function test_confirmShapeHeaderGap() {
        const m = openModal('Modal { title: "t"; className: "semi-modal-confirm";'
            + ' Rectangle { width: parent.width; height: 20; color: "transparent" } }')
        compare(m.confirmShape, true)
        compare(m.headerBlockHeight, 24 + 24 + 8)
        compare(part(m, "modalBody").y, 56)
        m.destroy()
    }

    // ---------------- 页脚 ----------------

    function test_defaultFooterMetrics() {
        const m = openModal('Modal { title: "t";'
            + ' Rectangle { width: parent.width; height: 20; color: "transparent" } }')
        const footer = part(m, "modalFooter")
        const row = part(m, "modalFooterRow")
        const ok = part(m, "modalOkButton")
        const cancel = part(m, "modalCancelButton")
        compare(footer.height, 80, "24 + 32 + 24")
        compare(row.y, 24)
        compare(row.spacing, 12, "$spacing-modal_footer_button-marginLeft")
        compare(row.height, 32)
        compare(row.x, 398 - row.implicitWidth, "text-align: right")
        verify(Math.abs(row.implicitWidth - 116) <= 1, "两颗 52 + 12 的间距")
        verify(Math.abs(ok.width - 52) <= 1, "两颗字 + 左右 16 内边距，cocoa 的字宽差在小数")
        compare(ok.height, 32)
        verify(Math.abs(cancel.width - 52) <= 1)
        compare(ok.text, "确定", "locale.confirm")
        compare(cancel.text, "取消", "locale.cancel")
        m.destroy()
    }

    // Modal.tsx renderFooter：cancel = type tertiary（theme 默认 light），ok = okType + solid
    function test_defaultButtonAppearance() {
        const m = openModal('Modal { title: "t" }')
        const ok = part(m, "modalOkButton")
        const cancel = part(m, "modalCancelButton")
        compare(ok.tone, Enums.Primary)
        compare(ok.variant, Enums.Solid)
        compare(cancel.tone, Enums.Tertiary)
        compare(cancel.variant, Enums.Light)
        m.destroy()
    }

    function test_okTypeMappedToTone() {
        const m = openModal('Modal { okType: "danger" }')
        compare(part(m, "modalOkButton").tone, Enums.Danger)
        const w = openModal('Modal { okType: "warning" }')
        compare(part(w, "modalOkButton").tone, Enums.Warning)
        destroyAll(m, w)
    }

    function test_buttonTextProps() {
        const m = openModal('Modal { okText: "Sounds great!"; cancelText: "No, thanks." }')
        compare(part(m, "modalOkButton").text, "Sounds great!")
        compare(part(m, "modalCancelButton").text, "No, thanks.")
        m.destroy()
    }

    // 官方 {...okButtonProps} 排在 type / theme 之后 ⇒ props 里的 key 盖掉默认
    function test_buttonPropsOverride() {
        const m = make('Modal { title: "自定义按钮属性";'
            + ' Rectangle { width: parent.width; height: 20; color: "transparent" } }')
        m.okButtonProps = { size: "small", type: "warning" }
        m.cancelButtonProps = { size: "small", disabled: true }
        m.visible = true
        wait(240)
        const ok = part(m, "modalOkButton")
        const cancel = part(m, "modalCancelButton")
        compare(ok.tone, Enums.Warning)
        compare(ok.height, 24, "$height-button_small")
        compare(cancel.height, 24)
        compare(cancel.enabled, false)
        compare(part(m, "modalFooter").height, 24 + 24 + 24)
        m.destroy()

        // 确定键那一侧的 disabled 也得单独测（两侧各读各自的 props）
        const w = openModal('Modal { title: "t"; okButtonProps: ({ disabled: true }) }')
        compare(part(w, "modalOkButton").enabled, false, "okButtonProps.disabled 盖掉默认可用")
        compare(part(w, "modalCancelButton").enabled, true, "取消键不受影响")
        w.destroy()
    }

    function test_loadingFlags() {
        const m = openModal('Modal { confirmLoading: true; cancelLoading: true }')
        compare(part(m, "modalOkButton").loading, true)
        compare(part(m, "modalCancelButton").loading, true)
        m.destroy()
    }

    function test_hasCancelFalse() {
        const m = openModal('Modal { hasCancel: false }')
        compare(m.cancelTaken, false)
        compare(part(m, "modalCancelButton").visible, false)
        verify(Math.abs(part(m, "modalFooterRow").implicitWidth - 52) <= 1)
        m.destroy()
    }

    function test_footerNull() {
        const m = openModal('Modal { title: "t"; footer: null;'
            + ' Rectangle { width: parent.width; height: 20; color: "transparent" } }')
        compare(m.footerTaken, false)
        compare(part(m, "modalFooter").visible, false)
        compare(m.height, 2 + 72 + 20)
        m.destroy()
    }

    // 官方 footer 传节点时仍套在 .semi-modal-footer 里，那两条 24 外边距照旧
    function test_customFooterNodeKeepsFooterMargins() {
        const m = openModal('Modal { title: "t";'
            + ' Rectangle { width: parent.width; height: 20; color: "transparent" } }')
        m.footer = customFooterNode
        wait(60)
        compare(m.footerIsDefault, false)
        compare(part(m, "modalFooterRow").visible, false)
        const node = part(m, "modalFooterNode")
        compare(node.visible, true)
        compare(node.y, 24)
        compare(node.height, 32)
        compare(part(m, "modalFooter").height, 80)
        m.destroy()
    }

    // footerFill：flex 撑满，每颗 (398 − 12) / 2 = 193（实测）
    function test_footerFillButtons() {
        const m = openModal('Modal { title: "t"; footerFill: true;'
            + ' Rectangle { width: parent.width; height: 20; color: "transparent" } }')
        const row = part(m, "modalFooterRow")
        compare(row.x, 0)
        compare(row.width, 398)
        compare(part(m, "modalCancelButton").width, 193)
        compare(part(m, "modalOkButton").width, 193)
        m.destroy()
    }

    // 只剩一颗按钮时 footerFill 依然把整行撑满：行的宽是 stack.width，不是隐式宽
    // （两颗那档 193 + 12 + 193 恰好等于 398，分不开，所以必须用这颗）
    function test_footerFillWithSingleButton() {
        const m = openModal('Modal { title: "t"; footerFill: true; hasCancel: false }')
        const row = part(m, "modalFooterRow")
        compare(part(m, "modalCancelButton").visible, false)
        compare(part(m, "modalOkButton").width, 193)
        compare(row.width, 398, "撑满 = 内容区宽，不是按钮隐式宽")
        compare(row.implicitWidth, 193)
        m.destroy()
    }

    // ---------------- 受控行为 ----------------

    function test_okOnlyNotifies() {
        const m = openModal('Modal { title: "t" }')
        let n = 0
        m.ok.connect(function () { n++ })
        part(m, "modalOkButton").clicked()
        compare(n, 1)
        compare(m.visible, true, "官方 handleOk 只 notify，关不关由调用方决定")
        m.destroy()
    }

    function test_cancelButtonOnlyNotifies() {
        const m = openModal('Modal { title: "t" }')
        let n = 0
        m.cancel.connect(function () { n++ })
        part(m, "modalCancelButton").clicked()
        compare(n, 1)
        compare(m.visible, true)
        m.destroy()
    }

    // 右上角 × 走 onClose → handleCancel（Modal.tsx 把两者接在一起）
    function test_closeKeyGoesThroughCancel() {
        const m = openModal('Modal { title: "t" }')
        let n = 0
        m.cancel.connect(function () { n++ })
        mouseClick(part(m, "modalClose"), 12, 12)
        wait(60)
        compare(n, 1, "点 × 发 cancel")
        compare(m.visible, true, "但不自己关")
        m.destroy()
    }

    function test_maskTapCancels() {
        const m = openModal('Modal { title: "t" }')
        let n = 0
        m.cancel.connect(function () { n++ })
        mouseClick(part(m, "modalMask"), 20, 20)
        wait(60)
        compare(n, 1)
        m.destroy()
    }

    function test_maskClosableFalseIgnoresTap() {
        const m = openModal('Modal { title: "t"; maskClosable: false }')
        let n = 0
        m.cancel.connect(function () { n++ })
        mouseClick(part(m, "modalMask"), 20, 20)
        wait(60)
        compare(n, 0, "maskClosable: false 就只剩按钮 / × / Esc")
        m.destroy()
    }

    // 官方 handleMaskClick 的 e.target === e.currentTarget：落在面板盒子里不算点遮罩
    function test_tapInsidePanelIsNotMaskClick() {
        const m = openModal('Modal { title: "t";'
            + ' Rectangle { width: parent.width; height: 60; color: "transparent" } }')
        let n = 0
        m.cancel.connect(function () { n++ })
        mouseClick(part(m, "modalMask"), 352, 150)   // 面板正中
        wait(60)
        compare(n, 0)
        m.destroy()
    }

    // 两条 notify 各带 100ms leading debounce；换来源就重开一轮
    function test_debounceSwallowsSameSource() {
        const m = openModal('Modal { title: "t" }')
        let n = 0
        m.cancel.connect(function () { n++ })
        let k = 0
        m.ok.connect(function () { k++ })
        m.handleCancel("close")
        m.handleCancel("close")
        m.handleCancel("close")
        compare(n, 1, "同一个来源 100ms 内只发一次")
        m.handleCancel("esc")
        compare(n, 2, "换来源立刻重开一轮")
        m.handleOk("ok")
        m.handleOk("ok")
        compare(k, 1)
        m.destroy()
    }

    function test_afterCloseFiresWhenHidden() {
        const m = openModal('Modal { title: "t" }')
        let n = 0
        m.afterClose.connect(function () { n++ })
        compare(n, 0)
        m.visible = false
        wait(300)
        compare(n, 1, "afterClose 在退场动画结束时发")
        m.destroy()
    }

    // ---------------- Esc ----------------

    function test_escCancelsTopMostOnly() {
        const first = openModal('Modal { title: "第一层" }')
        const second = openModal('Modal { title: "第二层" }')
        // 闸门本身：只有栈顶那条 Shortcut 是 enabled（这条不依赖按键真能送进来）
        compare(part(first, "modalEscShortcut").enabled, false, "下面那层的 Shortcut 关着")
        compare(part(second, "modalEscShortcut").enabled, true, "栈顶那层的 Shortcut 开着")
        let a = 0
        let b = 0
        first.cancel.connect(function () { a++ })
        second.cancel.connect(function () { b++ })
        keyClick(Qt.Key_Escape)
        wait(60)
        compare(b, 1, "最后打开那一层收到 Esc")
        compare(a, 0, "官方 escListenerStack：一次 Esc 只关一层")
        destroyAll(first, second)
    }

    // 关掉栈顶之后，Esc 应该落到下面那一层（push / remove 得配平）
    function test_escFallsBackToLayerBelow() {
        const first = openModal('Modal { title: "第一层" }')
        const second = openModal('Modal { title: "第二层" }')
        let a = 0
        let b = 0
        first.cancel.connect(function () { a++ })
        second.cancel.connect(function () { b++ })
        keyClick(Qt.Key_Escape)
        wait(60)
        compare(b, 1, "先关上面那层")
        second.visible = false
        wait(300)
        keyClick(Qt.Key_Escape)
        wait(60)
        compare(b, 1, "已经关掉的那层不再收 Esc")
        compare(a, 1, "退到下面那一层")
        destroyAll(first, second)
    }

    // 官方 escListenerStack 按挂载（这里是打开）顺序排：把下面那层重新打开，它重新占栈顶
    function test_reopenedModalTakesEscBack() {
        const first = openModal('Modal { title: "第一层" }')
        const second = openModal('Modal { title: "第二层" }')
        let a = 0
        let b = 0
        first.cancel.connect(function () { a++ })
        second.cancel.connect(function () { b++ })
        keyClick(Qt.Key_Escape)
        wait(60)
        compare(b, 1, "第一次 Esc 归最后打开那层")
        first.visible = false
        wait(300)
        first.visible = true
        wait(240)
        keyClick(Qt.Key_Escape)
        wait(60)
        compare(a, 1, "重新打开的那层回到栈顶")
        compare(b, 1, "另一层不再收这次 Esc")
        destroyAll(first, second)
    }

    function test_escIgnoredWhenCloseOnEscFalse() {
        const m = openModal('Modal { title: "t"; closeOnEsc: false }')
        compare(part(m, "modalEscShortcut").enabled, false, "closeOnEsc: false 直接把 Shortcut 关掉")
        let n = 0
        m.cancel.connect(function () { n++ })
        keyClick(Qt.Key_Escape)
        wait(60)
        compare(n, 0)
        m.destroy()
    }

    function test_escDoesNothingWhileClosed() {
        const m = make('Modal { title: "t" }')
        let n = 0
        m.cancel.connect(function () { n++ })
        m.visible = true
        wait(240)
        m.visible = false
        wait(300)
        keyClick(Qt.Key_Escape)
        wait(60)
        compare(n, 0, "关着的 Modal 不吃 Esc")
        m.destroy()
    }

    // ---------------- 动效 ----------------

    function test_motionDurations() {
        const m = make("Modal { }")
        compare(m.motionDuration, 120, "$animation_duration-modal-show/hide")
        compare(m.maskDuration, 90, "$animation_duration-modal_mask-*")
        compare(m.motionEase, Easing.OutCubic, "cubic-bezier(.215,.61,.355,1)")
        m.destroy()
    }

    function test_zoomMotionOnPanel() {
        const m = make('Modal { title: "t" }')
        m.visible = true
        wait(15)
        const panel = part(m, "modalPanel")
        verify(panel.scale < 1 || panel.opacity < 1,
            "进场中 scale/opacity 应未满，实际 scale=" + panel.scale + " opacity=" + panel.opacity)
        wait(240)
        verify(Math.abs(panel.scale - 1) < 0.001)
        compare(panel.opacity, 1)
        m.visible = false
        wait(240)
        compare(m.visible, false)
        m.destroy()
    }

    function test_motionFalseSkipsAnimation() {
        const m = make('Modal { title: "t"; motion: false }')
        m.visible = true
        wait(15)
        const panel = part(m, "modalPanel")
        compare(panel.scale, 1)
        compare(panel.opacity, 1)
        m.destroy()
    }

    // ---------------- bodyStyle ----------------

    function test_bodyStyleHeight() {
        const m = openModal('Modal { title: "自定义样式";'
            + ' Rectangle { width: parent.width; height: 400; color: "transparent" } }')
        m.bodyStyle = { overflow: "auto", height: 200 }
        wait(120)
        compare(part(m, "modalBodyScroll").height, 200)
        compare(m.height, 354, "官方实测 centered + bodyStyle 200 ⇒ 448×354")
        compare(part(m, "modalBodyScroll").interactive, true)
        m.destroy()
    }

    function test_bodyStyleMaxHeightCaps() {
        const m = make('Modal { title: "t"; Rectangle { width: parent.width; height: 400;'
            + ' color: "transparent" } }')
        m.bodyStyle = { maxHeight: 120 }
        m.visible = true
        wait(240)
        compare(part(m, "modalBodyScroll").height, 120)
        m.destroy()
    }

    // overflow 不是 auto / scroll 就不滚（官方那条 overflow:auto 写在 bodyStyle 里）
    function test_bodyScrollOnlyWithOverflow() {
        const m = openModal('Modal { title: "t";'
            + ' Rectangle { width: parent.width; height: 400; color: "transparent" } }')
        compare(m.bodyScrollable, false, "没设 overflow 就是自然高")
        compare(part(m, "modalBodyScroll").height, 400)
        m.destroy()

        // 高度夹住了、内容超出，但没写 overflow ⇒ 裁掉而不是能滚
        const w = openModal('Modal { title: "t";'
            + ' Rectangle { width: parent.width; height: 400; color: "transparent" } }')
        w.bodyStyle = { height: 100 }
        wait(120)
        compare(w.bodyScrollable, false, "overflow 没开就不许滚")
        compare(part(w, "modalBodyScroll").height, 100)
        compare(part(w, "modalBodyScroll").interactive, false)
        w.destroy()
    }

    // ---------------- 内容 ----------------

    function test_childrenLandInBodyColumn() {
        const m = openModal('Modal { title: "t"; Text { text: "一" } Text { text: "二" } }')
        const column = part(m, "modalContentColumn")
        compare(column.children.length, 2)
        compare(column.spacing, 0, "官方 body 没有 gap，块之间靠各自的 margin")
        compare(part(m, "modalContentColumn").width, 398)
        m.destroy()
    }

    // ---------------- ModalConfirm ----------------

    function test_confirmDefaults() {
        const c = make('ModalConfirm { confirmType: "info"; title: "Here is some info";'
            + ' contentText: "bla bla bla..." }')
        wait(240)
        compare(c.className, "semi-modal-confirm")
        compare(c.visible, true, "官方 ConfirmModal 的 useState(true)")
        compare(c.icon, "info_circle")
        compare(c.iconColor.toString(), Theme.current.colorInfo.toString())
        compare(c.width, 448, "文档表里 Modal.method() 的 width 写 520 是 stale，实测走 small")
        compare(c.height, 158, "官方实测 448×158")
        compare(part(c, "modalHeader").height, 56, "24 + 24 + 8")
        compare(part(c, "modalConfirmContent").text, "bla bla bla...")
        c.destroy()
    }

    // 默认档 info 的图标色与 primary 同值，所以改令牌才能证明走的是 color-info 那一条
    function test_confirmInfoColorFollowsInfoToken() {
        const c = make('ModalConfirm { confirmType: "info"; title: "t"; contentText: "c" }')
        wait(240)
        Theme.current.colorInfo = "#0a141e"
        compare(c.iconColor.toString(), "#0a141e", "info 档取 color-info，不是 color-primary")
        Theme.current.colorPrimary = "#1e2814"
        compare(c.iconColor.toString(), "#0a141e", "primary 变了也不算")
        c.destroy()
    }

    function test_confirmIconPerType() {
        const cases = [
            { type: "success", icon: "tick_circle", color: "colorSuccess" },
            { type: "error", icon: "alert_circle", color: "colorDanger" },
            { type: "warning", icon: "alert_triangle", color: "colorWarning" },
            { type: "confirm", icon: "help_circle", color: "colorPrimary" },
            { type: "info", icon: "info_circle", color: "colorInfo" }
        ]
        for (let i = 0; i < cases.length; ++i) {
            const c = make('ModalConfirm { confirmType: "' + cases[i].type + '" }')
            compare(c.icon, cases[i].icon, cases[i].type + " 的默认图标")
            compare(c.iconColor.toString(), Theme.current[cases[i].color].toString(),
                cases[i].type + " 的图标色")
            c.destroy()
        }
    }

    // 官方 error() 的 okButtonProps 垫了 { type: 'danger' }
    function test_confirmErrorOkToneThroughHost() {
        const host = make("ModalHost { }")
        host.error({ title: "E", content: "c" })
        wait(240)
        const card = host.items[0].card
        compare(card.confirmType, "error")
        compare(card.icon, "alert_circle", "宿主的默认图标表按 type 走")
        compare(part(card, "modalOkButton").tone, Enums.Danger)
        compare(part(card, "modalOkButton").variant, Enums.Solid)
        host.destroy()
    }

    // withError 把 okButtonProps 从整体展开里摘出来单独合：入参的 key 排在 danger 之后
    function test_hostErrorOkButtonPropsWinsOverDanger() {
        const host = make("ModalHost { }")
        host.error({ title: "E", content: "c", okButtonProps: { type: "warning" } })
        wait(240)
        const card = host.items[0].card
        compare(part(card, "modalOkButton").tone, Enums.Warning, "入参盖掉垫进去的 danger")
        host.destroy()
    }

    // 五支包装函数各自的默认图标与图标色
    function test_hostIconPerType() {
        const cases = [
            { fn: "info", icon: "info_circle", color: "colorInfo" },
            { fn: "success", icon: "tick_circle", color: "colorSuccess" },
            { fn: "warning", icon: "alert_triangle", color: "colorWarning" },
            { fn: "error", icon: "alert_circle", color: "colorDanger" },
            { fn: "confirm", icon: "help_circle", color: "colorPrimary" }
        ]
        for (let i = 0; i < cases.length; ++i) {
            const host = make("ModalHost { }")
            host[cases[i].fn]({ title: "t", content: "c" })
            wait(240)
            const card = host.items[0].card
            compare(card.icon, cases[i].icon, cases[i].fn + "() 的默认图标")
            compare(card.iconColor.toString(), Theme.current[cases[i].color].toString(),
                cases[i].fn + "() 的图标色")
            host.destroy()
        }
    }

    // 命令式那五支确定与取消都在（官方压根没传 hasCancel）
    function test_confirmShowsBothButtons() {
        const host = make("ModalHost { }")
        host.info({ title: "i", content: "c" })
        wait(240)
        const card = host.items[0].card
        compare(card.hasCancel, true)
        compare(part(card, "modalCancelButton").visible, true)
        compare(part(card, "modalOkButton").visible, true)
        host.destroy()
    }

    function test_confirmIconOverrideByConfig() {
        const host = make("ModalHost { }")
        host.info({ title: "custom", content: "c", icon: "send" })
        wait(240)
        const card = host.items[0].card
        compare(card.icon, "send", "config 的 icon 排在默认之后 ⇒ 盖掉")
        compare(card.iconColor.toString(), Theme.current.colorInfo.toString(),
            "颜色仍按 type（官方 clone 上去的是 …-info-icon）")
        host.destroy()
    }

    // ---------------- ModalHost ----------------

    function test_hostApiSurface() {
        const host = make("ModalHost { }")
        compare(typeof host.info, "function")
        compare(typeof host.success, "function")
        compare(typeof host.warning, "function")
        compare(typeof host.error, "function")
        compare(typeof host.confirm, "function")
        compare(typeof host.destroyAll, "function")
        compare(host.items.length, 0)
        host.destroy()
    }

    function test_hostOpensAndTracks() {
        const host = make("ModalHost { }")
        const h = host.info({ title: "Here is some info", content: "bla bla bla..." })
        wait(240)
        compare(host.items.length, 1)
        const card = host.items[0].card
        compare(card !== null, true)
        compare(card.title, "Here is some info")
        compare(card.contentText, "bla bla bla...", "字符串 content 走文本那一支")
        compare(part(card, "modalConfirmContentNode").item === null, true, "另一支不载入")
        compare(card.visible, true)
        compare(typeof h.destroy, "function")
        compare(typeof h.update, "function")
        host.destroy()
    }

    function test_hostOkCallbackCloses() {
        const host = make("ModalHost { }")
        let n = 0
        host.confirm({ title: "t", content: "c", onOk: function () { n++ } })
        wait(240)
        const card = host.items[0].card
        // 官方 handleOk：先跑 onOk，返回值不是 promise 就 setVisible(false)
        part(card, "modalOkButton").clicked()
        wait(60)
        compare(n, 1)
        compare(card.shown, false, "onOk 跑完就把 shown 收下来")
        compare(host.items.length, 1, "退场动画期间卡片还在")
        wait(300)
        compare(host.items.length, 0, "退场动画结束后卸载")
        host.destroy()
    }

    function test_hostUpdateMergesConfig() {
        const host = make("ModalHost { }")
        const h = host.info({ title: "旧标题", content: "c", okText: "自定义" })
        wait(240)
        const card = host.items[0].card
        compare(part(card, "modalOkButton").text, "自定义")
        h.update({ title: "更新的标题" })
        wait(60)
        compare(card.title, "更新的标题")
        compare(part(card, "modalOkButton").text, "自定义", "没写的 key 保留原值")
        host.destroy()
    }

    function test_hostDestroyIsAnimatedClose() {
        const host = make("ModalHost { }")
        let done = 0
        const h = host.info({ title: "t", content: "c", afterClose: function () { done++ } })
        wait(240)
        const card = host.items[0].card
        h.destroy()
        wait(30)
        compare(card.shown, false, "destroy 就是官方的 close：先收 shown")
        compare(host.items.length, 1, "退场动画没播完不卸载")
        compare(done, 0, "afterClose 要等动画结束")
        wait(300)
        compare(done, 1, "afterClose 只跑一次")
        compare(host.items.length, 0)
        host.destroy()
    }

    function test_hostAfterCloseRunsOnceOnly() {
        const host = make("ModalHost { }")
        let done = 0
        const h = host.success({ title: "t", content: "c", afterClose: function () { done++ } })
        wait(240)
        const card = host.items[0].card
        part(card, "modalCancelButton").clicked()   // 自己关一次
        wait(300)
        compare(done, 1)
        h.destroy()                                 // 再调 destroy 不该重复
        wait(300)
        compare(done, 1, "官方 closing 那道闸门")
        host.destroy()
    }

    function test_hostDestroyAll() {
        const host = make("ModalHost { }")
        host.info({ title: "A", content: "a" })
        host.warning({ title: "B", content: "b" })
        wait(240)
        compare(host.items.length, 2)
        host.destroyAll()
        wait(300)
        compare(host.items.length, 0)
        host.destroy()
    }

    function test_hostContentNode() {
        const host = make("ModalHost { }")
        host.info({ title: "t", content: nodeContent })
        wait(240)
        const card = host.items[0].card
        compare(card.contentText, "", "非字符串走 Component 那一支")
        const node = part(card, "modalConfirmContentNode")
        compare(node.item !== null, true, "Component 那一支真的载入了")
        compare(node.item.text, "节点内容")
        compare(part(card, "modalConfirmContent").visible, false, "字符串那一支同时收起")
        compare(card.icon, "info_circle")
        host.destroy()
    }

    function test_hostPassthroughProps() {
        const host = make("ModalHost { }")
        host.info({ title: "t", content: "c", footerFill: true, maskClosable: false,
            centered: true, okText: "GO" })
        wait(240)
        const card = host.items[0].card
        compare(card.footerFill, true)
        compare(card.maskClosable, false)
        compare(card.centered, true)
        compare(part(card, "modalOkButton").text, "GO")
        host.destroy()
    }

    // ---------------- modalRender ----------------

    function test_modalRenderHostsPanel() {
        const m = make('Modal { title: "可拖拽"; centered: true;'
            + ' modalRender: Component { DragMove { constrainToParent: false } } }')
        m.visible = true
        wait(240)
        const host = part(m, "modalRenderHost")
        compare(host.visible, true)
        const panel = part(m, "modalPanel")
        compare(panel.parent === host.item, true, "面板被搬进 modalRender 的宿主里")
        compare(m.width, 448, "盒子尺寸不受影响")
        m.destroy()
    }

    function test_modalRenderAbsentByDefault() {
        const m = openModal('Modal { title: "t" }')
        compare(part(m, "modalRenderHost").visible, false)
        // 没宿主时面板直接挂在弹层项上，不会漂到别处
        compare(part(m, "modalPanel").parent, m.contentItem)
        m.destroy()
    }
}
