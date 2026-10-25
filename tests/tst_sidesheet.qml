import QtQuick
import QtQuick.Controls as C
import QtTest
import Semi

// SideSheet。规格照 semi-ui/sideSheet/{index.tsx,SideSheetContent.tsx} +
// semi-foundation/sideSheet/{sideSheetFoundation.ts,constants.ts} +
// sideSheet/{sideSheet.scss,animation.scss,variables.scss}，字面值一律取编译后的
// packages/semi-ui/dist/css/semi.css：
//   · size 三档只给宽 small 448 / medium 684 / large 920（semi.css:19209-19217），
//     上下方位的主轴是高，恒 448（constants.ts:16 strings.HEIGHT）；交叉轴 100% 容器；
//   · 头部 padding 24 / 24 / 20、border-bottom `0px solid`（:19197-19203）⇒ 默认没有线，
//     标题 18 / 24 / 600 / text-0（:19179-19189），× 是 tertiary + borderless + small ⇒ 24×24，
//     于是短标题的头部高 = 24 + 24 + 20 = 68；标题与 × 之间不留缝（flex 行，align-items 顶对齐）；
//   · body padding `0 24` + flex:1 + overflow auto（:19204-19208），footer 只有 padding 24
//     （:19248-19250）且**没有默认内容**（index.tsx:79 footer: null）；
//   · 面板底色 bg-2、border 0、无圆角；阴影 --semi-shadow-elevated 只在 mask=false 时给
//     （:19190-19196 + sideSheet.scss:307-310）；遮罩 rgba(22,22,26,.6)；
//   · 进出场 180ms cubic-bezier(.25,.46,.45,.94)，位移是自身盒子主轴的一条边长。
// 用例跑在 705×1200 的窗口里：右侧面板 x = 705−448 = 257，上下方位宽 = 705。
TestCase {
    id: testCase

    name: "SideSheet"
    when: windowShown
    width: 705
    height: 1200

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "sidesheet");
    }

    function part(root, name) {
        return testCase.findChild(root, name);
    }

    // 打开并等进场动画（180ms）播完
    function openSheet(qml) {
        const s = make(qml);
        s.visible = true;
        wait(260);
        return s;
    }

    // 标题 / 页脚的节点档：JS 函数体里不能直接写 Component 对象，用这两份属性
    property Component titleNodeComp: Component {
        Item {
            objectName: "customTitleNode"

            implicitWidth: 120
            implicitHeight: 30
        }
    }

    property Component footerNodeComp: Component {
        Item {
            objectName: "customFooterNode"

            implicitWidth: 100
            implicitHeight: 24
        }
    }

    // ---------------- 属性面与默认值 ----------------

    function test_defaultProps() {
        const s = make("SideSheet { }");
        compare(s.visible, false, "官方 defaultProps.visible = false，完全受控");
        compare(s.placement, "right");
        compare(s.size, "small");
        compare(s.motion, true);
        compare(s.mask, true);
        compare(s.maskClosable, true);
        compare(s.closable, true);
        compare(s.closeIcon, "close");
        compare(s.closeOnEsc, false, "index.tsx:84 默认不听 Esc（与 Modal 相反）");
        compare(s.keepDOM, false);
        compare(s.disableScroll, true);
        compare(s.zIndex, 1000);
        compare(s.title, undefined);
        compare(s.footer, undefined);
        compare(s.getPopupContainer, null);
        compare(s.className, "");
        compare(s.direction, "ltr");
        s.destroy();
    }

    // 关闭路径全走 onCancel：Qt 那套「点外面 / 按 Esc 自动关」必须整个关掉，
    // 否则会把调用方那条 visible 绑定打断。
    function test_popupShellIsFullyControlled() {
        const s = make("SideSheet { }");
        compare(s.closePolicy, C.Popup.NoAutoClose);
        compare(s.dim, false, "遮罩自绘");
        compare(s.padding, 0);
        compare(s.modal, true, "mask 开着时整层拦点击");
        compare(s.zIndex, 1000);
        compare(s.panel.z, 0, "zIndex 收下不生效：层序由 Overlay 的打开顺序给");
        // 样式默认的 Popup background 是一块不透明直角矩形（cocoa 实测 #1e1e1e），挂在 panel
        // 外面就不跟着那条 Translate 走 —— 卡片滑进来时底下先整块是黑的。底色与投影都由
        // panel 里的 sideSheetSurface + sideSheetShadow 画，样式这一层必须置 null。
        verify(s.background === null, "样式那块底矩形要置 null");
        s.destroy();
    }

    function test_shellPaintsOnlyInsideThePanel() {
        const s = openSheet("SideSheet { }");
        compare(part(s, "sideSheetSurface").parent, s.panel, "底色层要在 panel 里，动画才带着它一起滑");
        compare(part(s, "sideSheetShadow").parent, s.panel, "投影层同上");
        s.destroy();
    }

    // SideSheet 曾自己声明过 `signal closed`，而 C.Popup 已经有同名的 —— QML 报
    // invalid override 之后整个信号被压掉：closed 一次都不发、onClosed 永远不触发
    // （gallery 里「最近一次关闭」那行一直是空的）。这条钉住 Popup 自己那一份还在。
    function test_closedSignalComesFromPopup() {
        const s = make("SideSheet { }");
        let n = 0;
        s.closed.connect(function () { n++; });
        s.visible = true;
        wait(260);
        compare(n, 0, "打开时不发 closed");
        s.visible = false;
        wait(300);
        compare(n, 1);
        s.destroy();
    }

    // 官方 mask=false 时外部区域照常可操作 ⇒ modal 跟着 mask 走（不像 Modal 常开）
    function test_modalFollowsMask() {
        const withMask = make("SideSheet { }");
        compare(withMask.modal, true);
        withMask.destroy();
        const noMask = make("SideSheet { mask: false }");
        compare(noMask.modal, false);
        noMask.destroy();
    }

    // ---------------- 几何：主轴 / 交叉轴 / 贴边 ----------------

    function test_sizeGivesWidthOnly() {
        const small = testCase.openSheet("SideSheet { title: 't' }");
        const medium = testCase.openSheet("SideSheet { title: 't'; size: 'medium' }");
        const large = testCase.openSheet("SideSheet { title: 't'; size: 'large' }");
        compare(small.width, 448, "$width-sideSheet_size-small");
        compare(medium.width, 684);
        compare(large.width, 920);
        // 交叉轴 100% 容器：左右方位的高就是窗口高
        compare(small.height, 1200);
        compare(small.sizeMainAxis, 448);
        testCase.destroyAll(small, medium, large);
    }

    function test_horizontalPlacementUsesHeight448() {
        const top = testCase.openSheet("SideSheet { title: 't'; placement: 'top'; size: 'large' }");
        compare(top.isHorizontal, true);
        compare(top.height, 448, "strings.HEIGHT 恒 448，size 不参与");
        compare(top.width, 705, "交叉轴 100% 容器");
        compare(top.sizeMainAxis, 448);
        const bottom = testCase.openSheet("SideSheet { placement: 'bottom' }");
        compare(bottom.height, 448);
        testCase.destroyAll(top, bottom);
    }

    function test_explicitWidthAndHeightOverride() {
        const sized = testCase.openSheet("SideSheet { title: 't'; width: 220 }");
        compare(sized.width, 220, "官方 width={220} 那一档");
        compare(sized.x, 705 - 220);
        const band = testCase.openSheet("SideSheet { placement: 'top'; height: 100 }");
        compare(band.height, 100);
        testCase.destroyAll(sized, band);
    }

    function test_edgeAnchoring() {
        const right = testCase.openSheet("SideSheet { placement: 'right' }");
        compare(right.x, 705 - 448);
        compare(right.y, 0);
        const left = testCase.openSheet("SideSheet { placement: 'left' }");
        compare(left.x, 0);
        compare(left.y, 0);
        const top = testCase.openSheet("SideSheet { placement: 'top' }");
        compare(top.x, 0);
        compare(top.y, 0);
        const bottom = testCase.openSheet("SideSheet { placement: 'bottom' }");
        compare(bottom.x, 0);
        compare(bottom.y, 1200 - 448);
        testCase.destroyAll(right, left, top, bottom);
    }

    // ---------------- 头部 ----------------

    function test_headerMetrics() {
        const s = testCase.openSheet("SideSheet { title: '滑动侧边栏' }");
        compare(s.headerPaddingTop, 24);
        compare(s.headerPaddingBottom, 20);
        compare(s.headerRowHeight, 24);
        compare(s.headerOuterHeight, 68, "24 + 24 + 20，border-bottom 是 0px");
        const title = testCase.part(s, "sideSheetTitle");
        compare(title.text, "滑动侧边栏");
        compare(title.font.pixelSize, 18, "$font-sideSheet_title-fontSize = 18");
        compare(title.lineHeight, 24);
        compare(title.font.weight, Font.DemiBold, "$font-weight-bold = 600");
        compare(title.color.toString(), Theme.current.colorText0.toString());
        // 头部块自己也在 padding 里：官方 .semi-sidesheet-header 的 padding 是 24
        compare(testCase.part(s, "sideSheetHeader").x, 24);
        const box = testCase.part(s, "sideSheetClose");
        compare(box.width, 24);
        compare(box.height, 24, "tertiary + borderless + small 的 IconButton");
        compare(box.x, 448 - 48 - 24, "贴着头部内容区右边缘（坐标是头部行里的）");
        // 标题 flex:1 吃剩下的宽：448 − 左右 padding 48 − × 那 24
        compare(title.width, 448 - 48 - 24);
        testCase.destroyAll(s);
    }

    // 官方那一层没有 gate：没标题、没 × 时也是 24 + 0 + 20 的一条空带（旧版本会整块收起）
    function test_headerAlwaysRendered() {
        const s = testCase.openSheet("SideSheet { closable: false }");
        compare(s.headerRowHeight, 0);
        compare(s.headerOuterHeight, 44);
        compare(testCase.part(s, "sideSheetHeader").visible, true);
        compare(testCase.part(s, "sideSheetClose").visible, false);
        const noTitleButClose = testCase.openSheet("SideSheet { }");
        compare(noTitleButClose.headerOuterHeight, 68, "没标题也有 ×");
        // SideSheetContent.tsx:100 是 `if (title)`：空串同样算没有
        const emptyTitle = testCase.openSheet("SideSheet { title: ''; closable: false }");
        compare(emptyTitle.titleTaken, false);
        compare(emptyTitle.headerOuterHeight, 44);
        testCase.destroyAll(s, noTitleButClose, emptyTitle);
    }

    function test_twoLineTitleGrowsHeader() {
        const s = testCase.openSheet("SideSheet { title: '第一行\\n第二行' }");
        compare(testCase.part(s, "sideSheetTitle").implicitHeight, 48);
        compare(s.headerRowHeight, 48);
        compare(s.headerOuterHeight, 92);
        testCase.destroyAll(s);
    }

    function test_titleNodeReplacesTextLayer() {
        const s = testCase.openSheet("SideSheet { title: titleNodeComp }");
        compare(s.titleIsNode, true);
        compare(testCase.part(s, "sideSheetTitle").visible, false);
        compare(testCase.part(s, "customTitleNode").visible, true);
        compare(s.headerRowHeight, 30, "量的是载入项的 implicitHeight");
        compare(s.headerOuterHeight, 74);
        testCase.destroyAll(s);
    }

    // ---------------- 分隔线：默认 0px，只有 headerStyle / bodyStyle 能补 ----------------

    function test_defaultHeaderHasNoDivider() {
        const s = testCase.openSheet("SideSheet { title: 't' }");
        compare(s.headerBorderWidth, 0);
        compare(testCase.part(s, "sideSheetHeaderDivider").visible, false);
        compare(s.bodyBorderWidth, 0);
        compare(testCase.part(s, "sideSheetBodyDivider").visible, false);
        testCase.destroyAll(s);
    }

    // 官方 demo 就是靠 headerStyle={{ borderBottom: '1px solid …' }} 补这条 0px 的线
    function test_headerStyleBorderBottom() {
        const s = testCase.openSheet("SideSheet { title: 't';"
            + " headerStyle: ({ borderBottom: '1px solid #123456' }) }");
        compare(s.headerBorderWidth, 1);
        const line = testCase.part(s, "sideSheetHeaderDivider");
        compare(line.visible, true);
        compare(line.color.toString(), "#123456");
        compare(s.headerOuterHeight, 69, "border-box：线算在头部自己高里");
        testCase.destroyAll(s);
    }

    function test_bodyStyleBorderBottom() {
        const s = testCase.openSheet("SideSheet { title: 't'; height: 300;"
            + " bodyStyle: ({ borderBottom: '2px solid #00ff00' }) }");
        compare(s.bodyBorderWidth, 2);
        const line = testCase.part(s, "sideSheetBodyDivider");
        compare(line.visible, true);
        compare(line.color.toString(), "#00ff00");
        compare(s.bodyHeight, 300 - 68, "body 是 flex:1 那一块，线不吃它的高度");
        testCase.destroyAll(s);
    }

    function test_headerStyleBackgroundColor() {
        const plain = testCase.openSheet("SideSheet { title: 't' }");
        compare(testCase.part(plain, "sideSheetHeaderBackground").visible, false,
            "官方 .semi-sidesheet-header 默认没有底色");
        plain.destroy();

        const s = testCase.openSheet("SideSheet { title: 't';"
            + " headerStyle: ({ backgroundColor: '#123456' }) }");
        const bg = testCase.part(s, "sideSheetHeaderBackground");
        compare(bg.visible, true);
        compare(bg.color.toString(), "#123456");
        compare(bg.height, 68, "底色铺整块头部（含 padding）");
        s.destroy();
    }

    function test_bodyStyleBackgroundColor() {
        const s = testCase.openSheet("SideSheet { title: 't';"
            + " bodyStyle: ({ background: '#00ff00' }) }");
        const bg = testCase.part(s, "sideSheetBodyBackground");
        compare(bg.visible, true, "`background` 那一条也认（Table 的 headerStyle 同一口径）");
        compare(bg.color.toString(), "#00ff00");
        compare(bg.width, 448 - 48);
        s.destroy();
    }

    // ---------------- body / footer ----------------

    function test_bodyMetrics() {
        const s = testCase.openSheet("SideSheet { title: 't';"
            + " Item { objectName: 'bodyOne'; implicitWidth: 100; implicitHeight: 20 } }");
        const body = testCase.part(s, "sideSheetBody");
        compare(body.x, 24, "$spacing-sideSheet_body-paddingX");
        compare(body.width, 448 - 48);
        compare(body.y, 68, "紧跟头部");
        compare(s.bodyHeight, 1200 - 68, "flex:1：剩余高度全给它");
        compare(testCase.part(s, "sideSheetBodyColumn").spacing, 0,
            "官方 body 里就是 children 竖排，没有 gap");
        testCase.destroyAll(s);
    }

    function test_footerAbsentByDefault() {
        const s = testCase.openSheet("SideSheet { title: 't' }");
        compare(s.footerTaken, false, "index.tsx:79 footer: null");
        compare(s.footerOuterHeight, 0);
        compare(testCase.part(s, "sideSheetFooter").visible, false);
        compare(s.bodyHeight, 1200 - 68);
        // SideSheetContent.tsx:159 也是真值判断：空串页脚不渲染那一块
        const empty = testCase.openSheet("SideSheet { title: 't'; footer: '' }");
        compare(empty.footerTaken, false);
        compare(empty.footerOuterHeight, 0);
        testCase.destroyAll(s, empty);
    }

    function test_footerTextAndNodeForms() {
        const textForm = testCase.openSheet("SideSheet { title: 't'; footer: '页脚文案' }");
        compare(textForm.footerIsText, true);
        compare(testCase.part(textForm, "sideSheetFooterText").text, "页脚文案");
        compare(textForm.footerOuterHeight, 48 + textForm.footerNaturalHeight,
            "footer 只有 padding 24");
        compare(textForm.bodyHeight, 1200 - 68 - textForm.footerOuterHeight);

        const nodeForm = testCase.openSheet("SideSheet { title: 't'; footer: footerNodeComp }");
        compare(nodeForm.footerIsNode, true);
        compare(testCase.part(nodeForm, "customFooterNode").visible, true);
        compare(nodeForm.footerOuterHeight, 48 + 24);
        const block = testCase.part(nodeForm, "sideSheetFooter");
        compare(block.y, 1200 - 72, "贴在面板底边");
        testCase.destroyAll(textForm, nodeForm);
    }

    function test_bodyScrollsOnlyWhenTaller() {
        const fits = testCase.openSheet("SideSheet { title: 't'; height: 300;"
            + " Item { implicitWidth: 100; implicitHeight: 20 } }");
        compare(fits.bodyNaturalHeight, 20);
        compare(fits.bodyScrollable, false);
        compare(testCase.part(fits, "sideSheetBodyScroll").interactive, false);

        const scrolls = testCase.openSheet("SideSheet { title: 't'; height: 100;"
            + " Item { implicitWidth: 100; implicitHeight: 400 } }");
        compare(scrolls.bodyHeight, 100 - 68);
        compare(scrolls.bodyScrollable, true);
        const view = testCase.part(scrolls, "sideSheetBodyScroll");
        compare(view.contentHeight, 400);
        compare(view.interactive, true, "官方 body 写死 overflow: auto");
        testCase.destroyAll(fits, scrolls);
    }

    function test_surfaceAndShadow() {
        // 浅色 bg-1 / bg-2 / bg-3 全是 #fff ⇒ 这条走深色
        Theme.mode = Theme.Dark;
        const s = testCase.openSheet("SideSheet { title: 't' }");
        const surface = testCase.part(s, "sideSheetSurface");
        compare(surface.color.toString(), Theme.current.colorBg2.toString(),
            "$color-sidesheet-bg = var(--semi-color-bg-2)");
        compare(testCase.part(s, "sideSheetShadow").visible, false,
            "阴影只在 mask=false 那条双类名规则里给");
        s.destroy();

        const fixed = testCase.openSheet("SideSheet { title: 't'; mask: false }");
        compare(testCase.part(fixed, "sideSheetShadow").visible, true);
        compare(testCase.part(fixed, "sideSheetWrap").visible, true,
            "没遮罩也留着那一层，disableScroll 的滚轮锁挂在它上面");
        compare(testCase.part(fixed, "sideSheetScrollLock").enabled, true);
        fixed.destroy();
    }

    // ---------------- 遮罩 ----------------

    function test_maskColorAndToggle() {
        const on = testCase.openSheet("SideSheet { title: 't' }");
        const mask = testCase.part(on, "sideSheetMask");
        compare(mask.visible, true);
        compare(mask.color.toString(), Theme.current.colorOverlayBg.toString());
        compare(mask.color.a, 0.6, "浏览器实测 rgba(22,22,26,.6)");
        on.destroy();

        const off = testCase.openSheet("SideSheet { title: 't'; mask: false }");
        compare(testCase.part(off, "sideSheetMask").visible, false);
        off.destroy();

        const styled = testCase.openSheet("SideSheet { title: 't';"
            + " maskStyle: ({ backgroundColor: '#123456' }) }");
        compare(testCase.part(styled, "sideSheetMask").color.toString(), "#123456");
        styled.destroy();
    }

    // wrap 靠负偏移铺满整个容器（面板盒子之外的点也归它管）
    function test_wrapCoversWholeHost() {
        const s = testCase.openSheet("SideSheet { title: 't' }");
        const wrap = testCase.part(s, "sideSheetWrap");
        compare(wrap.width, 705);
        compare(wrap.height, 1200);
        compare(wrap.x + s.x, 0);
        compare(wrap.y + s.y, 0);
        testCase.destroyAll(s);
    }

    function test_maskTapCancelsButKeepsVisible() {
        const s = testCase.openSheet("SideSheet { title: 't' }");
        let n = 0;
        s.cancel.connect(function () { n++; });
        mouseClick(testCase.part(s, "sideSheetMask"), 20, 20);
        wait(60);
        compare(n, 1, "三条关闭路径都只 notifyCancel");
        compare(s.visible, true, "组件自己不关");
        testCase.destroyAll(s);
    }

    // 官方 onMaskClick 的 e.target === e.currentTarget：落在面板盒子内就不算点遮罩
    function test_tapInsidePanelIsNotMaskClick() {
        const s = testCase.openSheet("SideSheet { title: 't';"
            + " Item { objectName: 'clickSpot'; width: 100; height: 100 } }");
        let n = 0;
        s.cancel.connect(function () { n++; });
        mouseClick(testCase.part(s, "clickSpot"), 50, 50);
        wait(60);
        compare(n, 0);
        testCase.destroyAll(s);
    }

    function test_maskClosableFalseIgnoresTap() {
        const s = testCase.openSheet("SideSheet { title: 't'; maskClosable: false }");
        let n = 0;
        s.cancel.connect(function () { n++; });
        mouseClick(testCase.part(s, "sideSheetMask"), 20, 20);
        wait(60);
        compare(n, 0);
        testCase.destroyAll(s);
    }

    function test_closeButtonCancels() {
        const s = testCase.openSheet("SideSheet { title: 't' }");
        let n = 0;
        s.cancel.connect(function () { n++; });
        mouseClick(testCase.part(s, "sideSheetClose"), 12, 12);
        wait(60);
        compare(n, 1, "× 走 onClose → handleCancel，与遮罩、Esc 同一条通道");
        compare(s.visible, true);
        testCase.destroyAll(s);
    }

    // 官方 `closeIcon || <IconClose/>`：假值回落默认图标，写 closeIcon={null} 去不掉
    function test_closeIconFallsBack() {
        const blank = testCase.openSheet("SideSheet { title: 't'; closeIcon: '' }");
        compare(blank.closeIconName, "close");
        const named = testCase.openSheet("SideSheet { title: 't'; closeIcon: 'arrow_left' }");
        compare(named.closeIconName, "arrow_left");
        testCase.destroyAll(blank, named);
    }

    // ---------------- Esc ----------------

    function test_escIgnoredByDefault() {
        const s = testCase.openSheet("SideSheet { title: 't' }");
        compare(testCase.part(s, "sideSheetEscShortcut").enabled, false,
            "closeOnEsc 默认 false（与 Modal 的 true 相反）");
        let n = 0;
        s.cancel.connect(function () { n++; });
        keyClick(Qt.Key_Escape);
        wait(60);
        compare(n, 0);
        s.destroy();
    }

    function test_closeOnEscCancels() {
        const s = testCase.openSheet("SideSheet { title: 't'; closeOnEsc: true }");
        compare(testCase.part(s, "sideSheetEscShortcut").enabled, true);
        let n = 0;
        s.cancel.connect(function () { n++; });
        keyClick(Qt.Key_Escape);
        wait(60);
        compare(n, 1);
        compare(s.visible, true);
        s.destroy();
    }

    function test_escGoesToTopMostSheet() {
        const first = testCase.openSheet("SideSheet { title: '第一层'; closeOnEsc: true }");
        const second = testCase.openSheet("SideSheet { title: '第二层'; closeOnEsc: true }");
        compare(testCase.part(first, "sideSheetEscShortcut").enabled, false, "下面那层关着");
        compare(testCase.part(second, "sideSheetEscShortcut").enabled, true);
        let a = 0;
        let b = 0;
        first.cancel.connect(function () { a++; });
        second.cancel.connect(function () { b++; });
        keyClick(Qt.Key_Escape);
        wait(60);
        compare(b, 1);
        compare(a, 0, "一次 Esc 只关最上面那层");
        second.visible = false;
        wait(300);
        keyClick(Qt.Key_Escape);
        wait(60);
        compare(a, 1, "退到下面那层");
        compare(b, 1, "已经关掉的那层不再收 Esc");
        testCase.destroyAll(first, second);
    }

    // 与 Modal 共用同一份 ModalEscStack：后打开的那一支占栈顶
    function test_escStackIsSharedWithModal() {
        const sheet = testCase.openSheet("SideSheet { title: '侧边'; closeOnEsc: true }");
        const modal = testCase.openSheet("Modal { title: '对话框'; closeOnEsc: true }");
        let s = 0;
        let m = 0;
        sheet.cancel.connect(function () { s++; });
        modal.cancel.connect(function () { m++; });
        keyClick(Qt.Key_Escape);
        wait(60);
        compare(m, 1, "Modal 后打开，Esc 归它");
        compare(s, 0);
        testCase.destroyAll(sheet, modal);
    }

    // ---------------- afterVisibleChange ----------------

    function test_afterVisibleChangeFollowsTransitions() {
        const s = make("SideSheet { title: 't' }");
        const seen = [];
        s.afterVisibleChange.connect(function (isVisible) { seen.push(isVisible); });
        s.visible = true;
        wait(60);
        compare(seen, [], "进场动画跑完才算 true");
        wait(260);
        compare(seen, [true]);
        s.visible = false;
        wait(260);
        compare(seen, [true, false]);
        s.destroy();
    }

    function test_motionFalseReportsImmediately() {
        const s = make("SideSheet { title: 't'; motion: false }");
        const seen = [];
        s.afterVisibleChange.connect(function (isVisible) { seen.push(isVisible); });
        s.visible = true;
        wait(60);
        compare(seen, [true], "motion=false 官方压根不挂动画类");
        compare(testCase.part(s, "sideSheetPanel").progress, 1);
        s.visible = false;
        wait(60);
        compare(seen, [true, false]);
        s.destroy();
    }

    // ---------------- 动效：180ms 平移一条自身边长 ----------------

    function test_motionDurationIs180() {
        const s = make("SideSheet { }");
        compare(s.motionDuration, 180, "$animation_duration-sideSheet_inner-show/hide");
        s.destroy();
    }

    function test_panelSlidesInFromItsEdge() {
        const s = make("SideSheet { title: 't' }");
        s.visible = true;
        let progress = 0;
        for (let i = 0; i < 40 && !(progress > 0); ++i) {
            wait(10);
            progress = s.panel.progress;
        }
        compare(progress < 1, true, "180ms 还没跑完");
        const slide = s.panel.transform[0];
        verify(slide.x > 0, "右侧那档从 +宽 处滑进来");
        compare(slide.y, 0);
        wait(300);
        compare(s.panel.progress, 1);
        compare(slide.x, 0, "就位");
        s.destroy();
    }

    function test_leftPlacementSlidesFromNegativeWidth() {
        const s = make("SideSheet { title: 't'; placement: 'left' }");
        s.visible = true;
        let progress = 0;
        for (let i = 0; i < 40 && !(progress > 0); ++i) {
            wait(10);
            progress = s.panel.progress;
        }
        const slide = s.panel.transform[0];
        verify(slide.x < 0, "左侧那档从 −宽 处滑进来");
        wait(300);
        compare(slide.x, 0);
        s.destroy();
    }

    function test_topPlacementSlidesFromNegativeHeight() {
        const s = make("SideSheet { title: 't'; placement: 'top' }");
        s.visible = true;
        let progress = 0;
        for (let i = 0; i < 40 && !(progress > 0); ++i) {
            wait(10);
            progress = s.panel.progress;
        }
        const slide = s.panel.transform[0];
        compare(slide.x, 0, "上下方位只走 y");
        verify(slide.y < 0, "从上边滑下来");
        wait(300);
        compare(slide.y, 0);
        s.destroy();
    }

    // 位移取的是自身盒子主轴那条边：左右方位是宽、上下方位是高（CSS 的 translate 百分比）
    function test_slideDistanceIsOwnBoxEdge() {
        const top = testCase.openSheet("SideSheet { title: 't'; placement: 'top' }");
        top.panel.progress = 0;
        compare(top.panel.transform[0].y, -448, "上下方位滑的是高，不是宽");
        compare(top.panel.transform[0].x, 0);
        top.panel.progress = 1;
        compare(top.panel.transform[0].y, 0);
        top.destroy();

        const right = testCase.openSheet("SideSheet { title: 't' }");
        right.panel.progress = 0;
        compare(right.panel.transform[0].x, 448, "左右方位滑的是宽");
        compare(right.panel.transform[0].y, 0);
        right.destroy();

        const wide = testCase.openSheet("SideSheet { title: 't'; width: 220 }");
        wide.panel.progress = 0;
        compare(wide.panel.transform[0].x, 220, "滑的是自己那条边长，不是 size 档位");
        wide.destroy();
    }

    function test_maskFadesWithThePanel() {
        const s = make("SideSheet { title: 't' }");
        s.visible = true;
        let progress = 0;
        for (let i = 0; i < 40 && !(progress > 0); ++i) {
            wait(10);
            progress = s.panel.progress;
        }
        const mask = testCase.part(s, "sideSheetMask");
        compare(mask.opacity < 1, true, "遮罩与面板同一条 180ms 的进度");
        wait(300);
        compare(mask.opacity, 1);
        s.destroy();
    }

    // ---------------- 渲染在指定容器 ----------------

    function test_getPopupContainerMovesPanelIntoTheBox() {
        const root = make("Item { objectName: 'hostRoot'; width: 400; height: 260;"
            + " SideSheet { objectName: 'inBoxSheet'; title: 't'; width: 220;"
            + " getPopupContainer: function () {"
            + " return testCase.findChild(testCase, 'hostRoot'); } } }");
        const sheet = testCase.findChild(root, "inBoxSheet");
        sheet.visible = true;
        wait(260);
        compare(sheet.host.objectName, "hostRoot");
        compare(sheet.hostWidth, 400);
        compare(sheet.width, 220);
        compare(sheet.x, 400 - 220, "贴的是容器那一边，不是窗口");
        compare(sheet.height, 260, "交叉轴是容器的高");
        compare(sheet.y, 0);
        const wrap = testCase.part(sheet, "sideSheetWrap");
        compare(wrap.width, 400);
        compare(wrap.height, 260);
        root.destroy();
    }

    // 传了 getPopupContainer 官方不锁滚（index.tsx:110 那条 gate）
    function test_scrollLockGate() {
        const plain = testCase.openSheet("SideSheet { title: 't' }");
        compare(testCase.part(plain, "sideSheetScrollLock").enabled, true,
            "disableScroll 默认 true：面板之外吃滚轮");
        plain.visible = false;
        wait(300);
        plain.destroy();

        const off = testCase.openSheet("SideSheet { title: 't'; disableScroll: false }");
        compare(testCase.part(off, "sideSheetScrollLock").enabled, false);
        off.visible = false;
        wait(300);
        off.destroy();

        const boxed = make("Item { objectName: 'lockBox'; width: 400; height: 260;"
            + " SideSheet { objectName: 'boxedSheet'; title: 't';"
            + " getPopupContainer: function () {"
            + " return testCase.findChild(testCase, 'lockBox'); } } }");
        const sheet = testCase.findChild(boxed, "boxedSheet");
        sheet.visible = true;
        wait(260);
        compare(testCase.part(sheet, "sideSheetScrollLock").enabled, false,
            "指定容器时官方不锁 body 的滚动");
        boxed.destroy();
    }

    // mask=false 那一节：外部照常可点（滚轮那条锁不吃鼠标）
    function test_outsideStaysClickableWithoutMask() {
        const root = make("Item { objectName: 'outsideRoot'; width: 705; height: 400;"
            + " Button { objectName: 'outsideButton'; text: '外面的按钮'; x: 0; y: 0 }"
            + " SideSheet { objectName: 'noMaskSheet'; title: 't'; mask: false;"
            + " visible: true } }");
        wait(260);
        let n = 0;
        testCase.findChild(root, "outsideButton").clicked.connect(function () { n++; });
        mouseClick(testCase.findChild(root, "outsideButton"), 20, 10);
        wait(60);
        compare(n, 1, "官方 mask={false} 允许操作外部区域");
        root.destroy();
    }

    // ---------------- 无障碍与不收的 prop ----------------

    function test_accessibleRolesMatchOfficial() {
        const s = testCase.openSheet("SideSheet { title: 't' }");
        compare(s.panel.Accessible.role, Accessible.Dialog, "role=\"dialog\"");
        compare(testCase.part(s, "sideSheetHeader").Accessible.role,
            Accessible.Heading, "role=\"heading\" aria-level=1");
        compare(testCase.part(s, "sideSheetWrap").Accessible.ignored, true,
            "遮罩 aria-hidden");
        testCase.destroyAll(s);
    }

    // keepDOM / className / direction / zIndex 收下不落地，但不能把组件搞坏
    function test_nonLandingPropsLeaveGeometryAlone() {
        const s = testCase.openSheet("SideSheet { title: 't'; keepDOM: true;"
            + " className: 'x'; direction: 'rtl'; zIndex: 2000 }");
        compare(s.width, 448);
        compare(s.height, 1200);
        compare(s.x, 705 - 448);
        compare(s.headerOuterHeight, 68);
        testCase.destroyAll(s);
    }

    function destroyAll(...items) {
        for (let i = 0; i < items.length; ++i)
            items[i].destroy();
    }
}
