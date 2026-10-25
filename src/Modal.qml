import QtQuick
import QtQuick.Controls as C
import "ModalEscStack.js" as EscStack

// 模态对话框。照 semi-ui/modal/{Modal,ModalContent,ConfirmModal,confirm}.tsx +
// semi-foundation/modal/{modalFoundation,modalContentFoundation}.ts +
// modal/{modal,animation,variables}.scss 的行为与度量逐条移植。
//
//     Modal {
//         id: basic
//         title: "基本对话框"
//         visible: page.open           // 受控：开合由调用方决定
//         onOk: page.open = false
//         onCancel: page.open = false
//         Text { text: "这是内容" }
//     }
//
// ---------------------------------------------------------------- 受控模型
// 官方 Modal 完全受控：`handleOk` / `handleCancel` 只做 notify（modalFoundation.ts:85-105），
// 组件自己不把 `visible` 改成 false —— 是调用方在回调里 setVisible(false)。右上角 ×、点遮罩、
// Esc 三条关闭路径全部汇到 `onCancel`（Modal.tsx 把 ModalContent 的 onClose 接到
// this.handleCancel）。所以这里：
//   · `closePolicy` 写死 NoAutoClose，Esc 自己接（挂在面板里的那条 Shortcut）；
//   · `ok()` / `cancel()` 只发信号，绝不调 close()；
//   · 两条 notify 各带 100ms leading-only debounce，且**换来源就重开一轮**
//     （handleOk 与 handleCancel 里 target 不同就 cancel 掉挂起的那次）；
//   · `afterClose()` 在退场动画结束时发（componentDidUpdate 里 displayNone 翻转 →
//     foundation.afterHide → notifyClose），QML 侧就是 Popup 的 onClosed；
//   · 多个对话框叠着时只有最后打开的那一个听 Esc（modalContentFoundation.ts 的
//     escListenerStack，src/ModalEscStack.js）。
//
// ---------------------------------------------------------------- 几何
// 弹层盒子就是官方 `.semi-modal-content`（浏览器实测：默认头部 448×236、
// 带图标的头部 448×202、header=null 448×182、无头部 448×178、命令式 448×158）：
//   · 宽：size 四档 small 448 / medium 684 / large 920 / full-width 容器宽 − 64
//     （$width-modal_*）。`width` 传了就盖掉 size（官方 inline style 排在 size 类之后），
//     fullScreen 再盖掉一切（100% × 100% + margin unset + 圆角 0 + 无描边）；
//   · 高：没传 `height` 时是 max-content，传了就定死（-content-height-set 让内容填满）；
//   · 位置：`.semi-modal` 的 `margin: 80px auto`（$spacing-modal-marginY）⇒ 水平居中、
//     距容器顶 80（实测 modal.y − host.y = 80）；这里的「容器」是 `host` = 弹层真正挂上去
//     的那个 Overlay 项（`parent: C.Overlay.overlay`），不是声明处那个项 —— 页面里那根
//     滚动列比窗口高得多，拿它算居中与全屏就歪（cocoa 实测窗口 705x926、host 同值，而
//     声明项还报 1200）；`centered` 换成 `margin: auto` +
//     wrap 的 `align-items: flex-start` ⇒ 装得下才垂直居中，装不下退回顶对齐，
//     这里用 Math.max(0, …) 复现同一条退化；
//   · 内边距：content 只有左右 24（$spacing-modal_content-paddingX），纵向 0 ——
//     那 24 是 header / footer 各自的外边距（$spacing-modal_header-marginY 等），
//     body 自己的 margin 与 padding 都是 0；描边 1（$width-modal_content-border）。
//     于是内容区宽 = 448 − 2×24 − 2×1 = 398（实测）。
// 头部：24 / 标题行 / 24（命令式那支下边距是 8，$spacing-modal_confirm_header-marginBottom）。
// 标题 = Typography.Title heading=5（18 / 24 / 600，text-0）；图标位宽 24 + 右 12
// （$width-icon-extra-large + $spacing-base-tight）；关闭键 24×24 顶对齐贴在行末。
// 只要 `icon` 在场，body 就整体右移 36（$spacing-modal_content_withicon-marginLeft）——
// 官方 .semi-modal-withIcon 只看 props.icon，头部为空时也照移，这一条照抄。
// 页脚：24 / 32 / 24，右对齐，两颗按钮间距 12（$spacing-modal_footer_button-marginLeft）；
// footerFill 时 flex 撑满，每颗 (398 − 12) / 2 = 193（实测）。
// 默认页脚两颗的类型：cancel = tertiary + light，ok = okType + solid（Modal.tsx renderFooter）。
// 动效：面板 scale 0.7↔1 + 淡入淡出 120ms，蒙层 90ms（animation.scss），曲线
// cubic-bezier(.215,.61,.355,1) = easeOutCubic（Qt 的 BezierSpline 退化成线性，见坑 50）。
// 弹层盒子自己一层都不画（`background: null`）：底色与投影都在面板里，动画才带得动它们，
// 留着样式默认那块底矩形就会在卡片底下露出黑影（见坑 103）。
//
// ---------------------------------------------------------------- 三种头部形态
// ModalContent 里 header 与 body 是两条分支，端口照抄成三档（headerBlock / bodyBlock 的可见性
// 与高度都按这三档算）：
//   · 默认（有 title、没传 header）：24 + [图标 + 标题 + ×] + 24，body 紧跟其后、margin 0；
//   · 传了 header（含 null）：header 原样落地、四周没有那两条 24，body 照常是普通 body。
//     这一档 × 也不画 —— 官方 renderBody 只在 hasHeader 为 false 的那支里放 closer；
//   · 既没 title 也没 header：body 外面套 .semi-modal-body-wrapper（上下各 24），
//     图标与 × 都在这一层里，body 依旧右移 36。
//
// ---------------------------------------------------------------- 与官方的差异
//   · `style` / `maskStyle` / `direction`（RTL）/ `preventScroll` / `getContainerContext` /
//     `lazyRender` / `keepDOM` 不收：本端口没有 DOM 与 CSS；官方那两条「保留 / 延迟挂载」
//     要解决的 React 卸载问题在 QML 里不存在（Popup 关掉不销毁子项）。
//   · `className` 收下但只认一个类名：官方 `.semi-modal-confirm` 那组 scss 里只有一条影响
//     布局（标题行下边距 24→8），所以这里只按它判 `confirmShape`。`modalContentClass`
//     收下不用，只为让官方那类调用点不报未知属性。
//   · `zIndex` 收下但不生效：本库弹层层级由 Overlay 的打开顺序决定，PopupBase / Popover /
//     Select 那一整族都没设 z；单把 Modal 抬到 1000 会盖掉对话框里再开的下拉。
//   · 遮罩点击「按下起点必须落在遮罩上」官方靠 dialogMouseDown 那个 state，这里由命中测试
//     本身保证，另在 TapHandler 里补一条与官方 `e.target === e.currentTarget` 等价的判断。
//   · `title` / `header` / `footer` / `icon` 官方是 ReactNode：这里都是「字符串或 Component」，
//     字符串按官方度量排 Text，Component 交给 Loader。`closeIcon` 只收字符串（图标名）。
//   · 官方 ModalProps 表里那条 `content` 在 `Modal.tsx` 里根本不参与渲染（`ModalContent.tsx:233`
//     往 .semi-modal-body 里放的是 `children`，只有 `ConfirmModal` 消费 content），所以端口的
//     正文槽就是子项，名字沿用官方的 `content`（default property）。
//   · 传节点那两档量高只认载入项的 `implicitHeight`（Loader 自己写了显式宽高就会接管
//     载入项尺寸，节点里光写 `height: 40` 会被压成 0）—— 自定义节点请写 implicit 尺寸。
//     同一机制的宽度那一半：页脚槽的 `width: stack.width` 会把节点拉成整块宽，想要官方
//     那种「自然宽、贴右」的按钮得自己在节点里垫一层 Item（见 ModalPage 的「自定义页脚样式」）。
//   · Esc 用一条 `Shortcut`（StandardKey.Cancel）+ 一个「只有栈顶那一层 enabled」的闸门：
//     闸门必须写成 ModalEscStack 回灌进来的 `escIsTop` 属性 —— 绑定里直接调 `.js` 的
//     `isTop()` 不会重算（那个数组不是 notify），Shortcut 会永远停在第一次求出的 disabled。
//     `Shortcut` 挂哪儿都行：Qt 那条 context matcher 会沿 QObject parent 找到 window
//     （qquickshortcut.cpp:60-74，实测挂在 Popup 根上照样收 Esc）。context 用
//     `Qt.ApplicationShortcut`：官方往 document 上挂监听、不看窗口焦点，而默认的
//     WindowShortcut 要 `window->isActive()`（cocoa 上从终端起的进程抢不到前台，实测
//     三条 Esc 用例全红）。
//   · onOk / onCancel 返回 Promise 驱动的那套 loading（`onOKReturnPromiseStatus`）没有对应物，
//     改成显式的 `confirmLoading` / `cancelLoading` —— 同 src/Feedback.qml 的口径。
//   · 焦点：官方开层时聚焦取消键（ok/cancelButtonProps 里的 autoFocus 可改），这条做了；
//     「关闭后焦点回到打开前的元素」交给 Popup 自己的 focus 语义。
//   · 面板比容器还高时官方靠 .semi-modal-wrap 的 overflow: auto 滚动，这里不滚
//     （顶对齐那条退化仍然成立）。
C.Popup {
    id: control

    // ---------------------------------------------------------------- 官方 ModalProps
    // `visible` 就是官方那个受控开关，`width` / `height` 就是 .semi-modal-content 的宽高，
    // 三条都直接落在 Popup 自己的属性上。
    property var title: undefined
    // undefined = 没传（按 title 推）；null = 不渲染头部；其余 = 自定义头部
    property var header: undefined
    // undefined = 默认两颗按钮；null = 不渲染页脚；其余 = 自定义页脚
    property var footer: undefined
    property var icon: undefined
    property string closeIcon: "close"
    property string okText: ""                  // 空 ⇒ locale.confirm「确定」
    property string cancelText: ""              // 空 ⇒ locale.cancel「取消」
    property string okType: "primary"           // primary|secondary|tertiary|warning|danger
    property bool hasCancel: true
    property bool closable: true
    property bool mask: true
    property bool maskClosable: true
    property bool closeOnEsc: true
    property bool centered: false
    property bool motion: true
    property bool fullScreen: false
    property bool footerFill: false
    property string size: "small"               // strings.SIZE
    property int zIndex: Theme.current.zModal
    property bool confirmLoading: false
    property bool cancelLoading: false
    property var okButtonProps: undefined
    property var cancelButtonProps: undefined
    // 官方是 CSSProperties，这里只认 height / maxHeight / overflow
    property var bodyStyle: undefined
    // 官方 (modal: ReactNode) => ReactNode；这里是承接面板的 Component（可拖拽那一节）
    property var modalRender: undefined
    property var getPopupContainer: null
    property string className: ""
    property string modalContentClass: ""
    property string direction: "ltr"
    property bool preventScroll: false

    // 非官方：官方靠 .semi-modal-{info|success|warning|error}-icon 那四条 scss 给命令式那五支
    // 的图标着色，端口没有 CSS，翻成一个显式颜色，由 ModalConfirm 按 type 写。
    property color iconColor: Theme.current.colorText0

    signal ok
    signal cancel
    signal afterClose

    // 官方 children 就是 .semi-modal-body 里的内容
    default property alias content: contentColumn.data

    // 高级用法：摸到内部件
    readonly property alias okButton: okButton
    readonly property alias cancelButton: cancelButton
    readonly property alias closeButton: closeButton

    // ---------------------------------------------------------------- 派生量
    readonly property Item host: control.parent
    readonly property real hostWidth: control.host ? control.host.width : 0
    readonly property real hostHeight: control.host ? control.host.height : 0

    // $width-modal_*
    readonly property real sizeWidth: control.size === "medium" ? 684
        : (control.size === "large" ? 920
            : (control.size === "full-width" ? Math.max(0, control.hostWidth - 64) : 448))

    readonly property bool confirmShape: control.className.split(" ")
        .indexOf("semi-modal-confirm") >= 0
    readonly property bool titleTaken: control.title !== undefined && control.title !== null
    readonly property bool headerPassed: control.header !== undefined
    // renderHeader：'header' in props 就一切以它为准（null ⇒ 整块不渲染）
    readonly property bool headerTaken: control.headerPassed ? control.header !== null : control.titleTaken
    // renderBody 的 hasHeader：true 走普通 body，false 走 body-wrapper（图标与 × 在那一层）
    readonly property bool hasHeaderBlock: control.headerPassed || control.titleTaken
    readonly property bool headerIsDefault: control.headerTaken && !control.headerPassed
    readonly property bool headerIsText: control.headerTaken && control._isText(control.header)
    readonly property bool headerIsNode: control.headerTaken && !control.headerIsText
    readonly property bool iconTaken: control.icon !== undefined && control.icon !== null
        && control.icon !== ""
    readonly property bool iconIsText: control.iconTaken && control._isText(control.icon)
    readonly property bool footerTaken: control.footer !== undefined ? control.footer !== null : true
    readonly property bool footerIsDefault: control.footerTaken && control.footer === undefined
    readonly property bool footerIsText: control.footerTaken && control._isText(control.footer)
    readonly property bool footerIsNode: control.footerTaken && !control.footerIsDefault
        && !control.footerIsText
    readonly property bool cancelTaken: control.footerIsDefault && control.hasCancel
    // × 只在默认头部里、或 body-wrapper 里画（header=null 那一支官方就不画 ×）
    readonly property bool headerCloseTaken: control.closable && control.headerIsDefault
    readonly property bool wrapperCloseTaken: control.closable && !control.hasHeaderBlock
    readonly property bool closeTaken: control.headerCloseTaken || control.wrapperCloseTaken

    // $spacing-modal_content-paddingX / $width-modal_content-border / $spacing-modal-marginY
    readonly property real contentPaddingX: Theme.current.spacingLoose
    readonly property real borderWidth: 1
    readonly property real dialogTopMargin: 80
    // header / footer 的上下外边距（$spacing-modal_header-marginY / $spacing-modal_footer-marginY）
    readonly property real blockMarginY: Theme.current.spacingLoose
    // $spacing-modal_confirm_header-marginBottom
    readonly property real confirmHeaderMarginBottom: 8
    // $spacing-modal_icon_wrapper-marginRight / $spacing-modal_footer_button-marginLeft
    readonly property real tightGap: Theme.current.spacingBaseTight
    // $width-icon-extra-large
    readonly property real iconWidth: Theme.current.widthIconExtraLarge
    // $spacing-modal_content_withicon-marginLeft
    readonly property real bodyIndentX: control.iconTaken ? 36 : 0
    // Typography.Title heading=5 的行高
    readonly property real titleLineHeight: Appearance.titleLineHeight(Theme.current, 5)

    readonly property real blockWidth: Math.max(0, control.width
        - (control.contentPaddingX + control.borderWidth) * 2)

    // 默认头部那一行的高：标题与图标都按 24，标题换行就跟着长
    readonly property real headerRowHeight: Math.max(control.titleLineHeight,
        control.iconTaken ? control.iconWidth : 0, titleText.implicitHeight)
    readonly property real customHeaderHeight: control.headerIsText
        ? headerText.implicitHeight
        : ((headerNodeLoader.item as Item) ? (headerNodeLoader.item as Item).implicitHeight : 0)
    readonly property real headerBlockHeight: !control.headerTaken ? 0
        : (control.headerIsDefault
            ? (control.blockMarginY + control.headerRowHeight
                + (control.confirmShape ? control.confirmHeaderMarginBottom
                    : control.blockMarginY))
            : control.customHeaderHeight)

    // body：bodyStyle.height 优先，否则内容自然高，maxHeight 封顶
    readonly property real bodyNaturalHeight: contentColumn.implicitHeight
    readonly property real bodyHeight: {
        const fixed = control._numOf(control.bodyStyle, "height", 0);
        const max = control._numOf(control.bodyStyle, "maxHeight", 0);
        let h = fixed > 0 ? fixed : control.bodyNaturalHeight;
        if (max > 0)
            h = Math.min(h, max);
        return Math.max(0, h);
    }
    readonly property bool bodyScrollable: {
        const overflow = String(control._propOf(control.bodyStyle, "overflow", ""));
        return (overflow === "auto" || overflow === "scroll")
            && control.bodyNaturalHeight > control.bodyHeight;
    }
    readonly property real bodyBlockHeight: control.hasHeaderBlock
        ? control.bodyHeight
        : (control.blockMarginY + Math.max(control.bodyHeight, control.iconWidth)
            + control.blockMarginY)

    readonly property real footerNaturalHeight: control.footerIsDefault
        ? footerRow.implicitHeight
        : (control.footerIsText ? footerText.implicitHeight
            : ((footerNodeLoader.item as Item) ? (footerNodeLoader.item as Item).implicitHeight : 0))
    readonly property real footerBlockHeight: control.footerTaken
        ? (control.blockMarginY * 2 + control.footerNaturalHeight) : 0

    implicitWidth: control.fullScreen ? control.hostWidth : control.sizeWidth
    implicitHeight: control.fullScreen ? control.hostHeight
        : (stack.implicitHeight + control.borderWidth * 2)

    parent: control.getPopupContainer ? control.getPopupContainer() : C.Overlay.overlay
    // .semi-modal-wrap 铺满容器并吃掉容器内别处的点击，跟 mask 开不开无关
    modal: true
    dim: false                              // 遮罩自绘
    focus: true
    padding: 0
    // 本体的底与投影都由 panel 里的 modalSurface + SemiPopupShadow 画。样式默认的
    // background 是一块不透明直角矩形（macOS 样式取 palette.window），它挂在 panel 外面，
    // 进/出场动画只动 panel ⇒ 卡片缩小时它照样整块留在原地（实测 cocoa #1e1e1e）。
    background: null
    // 官方所有关闭路径都只 notify，不自己关 ⇒ 交给调用方改 visible
    closePolicy: C.Popup.NoAutoClose

    x: control.host ? Math.max(0, (control.hostWidth - control.width) / 2) : 0
    y: {
        if (control.fullScreen)
            return 0;
        if (control.centered)
            return control.host ? Math.max(0, (control.hostHeight - control.height) / 2) : 0;
        return control.dialogTopMargin;
    }

    // ---------------------------------------------------------------- 动效
    // 两条时长都是 animation.scss 的硬编码值，不能读 Theme.current.duration*（默认主题把
    // 全局时长令牌设成 0ms）。motion 为 false 时官方压根不挂动画类，这里用 0ms 等价。
    readonly property int motionDuration: 120     // $animation_duration-modal-show/hide
    readonly property int maskDuration: 90         // $animation_duration-modal_mask-*
    readonly property int motionEase: Easing.OutCubic

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                target: panel
                property: "scale"
                from: control.motion ? 0.7 : 1
                to: 1
                duration: control.motion ? control.motionDuration : 0
                easing.type: control.motionEase
            }
            NumberAnimation {
                target: panel
                property: "opacity"
                from: control.motion ? 0 : 1
                to: 1
                duration: control.motion ? control.motionDuration : 0
                easing.type: control.motionEase
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                target: panel
                property: "scale"
                from: 1
                to: control.motion ? 0.7 : 1
                duration: control.motion ? control.motionDuration : 0
                easing.type: control.motionEase
            }
            NumberAnimation {
                target: panel
                property: "opacity"
                from: 1
                to: control.motion ? 0 : 1
                duration: control.motion ? control.motionDuration : 0
                easing.type: control.motionEase
            }
        }
    }

    onOpened: {
        EscStack.push(control.__escId, control.__setEscTop);
        control.applyAutoFocus();
    }

    onClosed: {
        EscStack.remove(control.__escId);
        control.afterClose();
    }

    Component.onDestruction: EscStack.remove(control.__escId)

    // ---------------------------------------------------------------- Esc
    readonly property int __escId: EscStack.nextId()

    // 栈顶标记由 ModalEscStack 回灌（`.js` 里的数组不是 notify，绑定读不到变化）
    property bool escIsTop: false

    function __setEscTop(isTop) {
        control.escIsTop = isTop;
    }

    // ---------------------------------------------------------------- 通知与 debounce
    // 时间戳必须留 real：Date.now() 是 1.7e12，写进 int 会溢出成 32 位（实测截成 1.2e9），
    // 差值就永远大于 100，debounce 形同没有。
    property real __lastOkAt: 0
    property string __lastOkFrom: ""
    property real __lastCancelAt: 0
    property string __lastCancelFrom: ""

    function handleOk(from) {
        if (from === control.__lastOkFrom && Date.now() - control.__lastOkAt < 100)
            return;
        control.__lastOkFrom = from;
        control.__lastOkAt = Date.now();
        control.ok();
    }

    function handleCancel(from) {
        if (from === control.__lastCancelFrom && Date.now() - control.__lastCancelAt < 100)
            return;
        control.__lastCancelFrom = from;
        control.__lastCancelAt = Date.now();
        control.cancel();
    }

    // 官方 Modal 打开时聚焦取消键，ok/cancelButtonProps 里的 autoFocus 可以改
    function applyAutoFocus() {
        const cancelAuto = control._boolOf(control.cancelButtonProps, "autoFocus", true);
        const okAuto = control._boolOf(control.okButtonProps, "autoFocus", false);
        if (cancelAuto && control.cancelTaken)
            cancelButton.forceActiveFocus();
        else if (okAuto && control.footerIsDefault)
            okButton.forceActiveFocus();
    }

    // 官方 {...props} 展开的语义：只有对象里**出现过**的 key 才盖默认值
    function _propOf(obj, key, fallback) {        if (obj === undefined || obj === null)
            return fallback;
        return key in obj ? obj[key] : fallback;
    }

    function _numOf(obj, key, fallback) {
        const v = control._propOf(obj, key, undefined);
        if (typeof v === "number")
            return v;
        if (typeof v === "string") {
            const n = parseFloat(v);
            if (!Number.isNaN(n))
                return n;
        }
        return fallback;
    }

    function _boolOf(obj, key, fallback) {
        const v = control._propOf(obj, key, undefined);
        return v === undefined ? fallback : Boolean(v);
    }

    // 官方 Button 的 type / theme / size 都是字符串；端口的 Button 收 Enums，
    // 所以这里把官方值翻成枚举（也允许调用方直接给枚举）
    function _toneOf(value, fallback) {
        if (value === undefined || value === null)
            return fallback;
        if (typeof value === "number")
            return value;
        switch (String(value)) {
        case "primary":
            return Enums.Primary;
        case "secondary":
            return Enums.Secondary;
        case "tertiary":
            return Enums.Tertiary;
        case "warning":
            return Enums.Warning;
        case "danger":
            return Enums.Danger;
        default:
            return fallback;
        }
    }

    function _variantOf(value, fallback) {
        if (value === undefined || value === null)
            return fallback;
        if (typeof value === "number")
            return value;
        switch (String(value)) {
        case "solid":
            return Enums.Solid;
        case "light":
            return Enums.Light;
        case "outline":
            return Enums.Outline;
        case "borderless":
            return Enums.Borderless;
        default:
            return fallback;
        }
    }

    function _sizeOf(value, fallback) {
        if (value === undefined || value === null)
            return fallback;
        if (typeof value === "number")
            return value;
        switch (String(value)) {
        case "small":
            return Enums.Small;
        case "large":
            return Enums.Large;
        case "default":
            return Enums.Default;
        default:
            return fallback;
        }
    }

    function _isText(value) {
        return typeof value === "string" || typeof value === "number";
    }

    // Loader.sourceComponent 只收 Component：字符串档那几支必须给 null，
    // 否则即使 active 为 false 也会报「Unable to assign QString to QQmlComponent*」
    function _nodeOf(value) {
        return value !== undefined && value !== null && !control._isText(value) ? value : null;
    }

    // ---------------------------------------------------------------- .semi-modal-wrap
    // 官方是铺满视口的一层，和 .semi-modal-mask 同级（mask 先画）。这里因为弹层盒子本身要当
    // 面板用（官方 width / height 落在它身上），遮罩只能反过来做成子项，靠负偏移铺满整个容器
    // —— 实测这种子项照样收得到面板之外的点击。
    Item {
        id: wrap

        objectName: "modalWrap"
        x: -control.x
        y: -control.y
        width: control.hostWidth
        height: control.hostHeight

        // $color-modal_mask-bg = var(--semi-color-overlay-bg)
        Rectangle {
            objectName: "modalMask"

            anchors.fill: parent
            visible: control.mask
            color: control.visible ? Theme.current.colorOverlayBg : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: control.motion ? control.maskDuration : 0
                    easing.type: control.motionEase
                }
            }
        }

        TapHandler {
            objectName: "modalWrapTap"
            enabled: control.maskClosable
            onTapped: {
                // 官方 handleMaskClick 的 e.target === e.currentTarget：
                // 落点在面板盒子之内就不算点遮罩
                const gx = point.position.x + wrap.x;
                const gy = point.position.y + wrap.y;
                if (gx >= 0 && gx < control.width && gy >= 0 && gy < control.height)
                    return;
                control.handleCancel("mask");
            }
        }
    }

    // ---------------------------------------------------------------- modalRender
    // 官方把 modalRender(node) 放在 .semi-modal 里面包 .semi-modal-content；可拖拽那一支就是
    // 在这一层把面板整体挪走。宿主按面板尺寸给，面板搬进去后照常摆。
    Loader {
        id: renderHost

        objectName: "modalRenderHost"
        active: control.modalRender !== undefined && control.modalRender !== null
        sourceComponent: control._nodeOf(control.modalRender)
        x: 0
        y: 0
        width: control.width
        height: control.height
        visible: active
    }

    // ---------------------------------------------------------------- .semi-modal-content
    Item {
        id: panel

        objectName: "modalPanel"
        parent: (renderHost.item as Item) !== null ? (renderHost.item as Item) : control.contentItem
        x: 0
        y: 0
        width: control.width
        height: control.height
        transformOrigin: Item.Center

        // Esc。挂在面板这个 Item 里（父项是 Popup 还是 Item 实测都能收到，
        // 见 qquickshortcut.cpp:60 那条 context matcher —— 它会沿 QObject parent
        // 一路找到 window）。真正决定「谁听 Esc」的是下面那条 escIsTop。
        Shortcut {
            id: escShortcut

            objectName: "modalEscShortcut"
            sequences: [StandardKey.Cancel]
            // 官方是往 document 上挂 keydown 监听（谁显示谁听、按 escListenerStack 只关最上面那层），
            // 不看窗口有没有拿到系统焦点 ⇒ 这里用 ApplicationShortcut 对齐。默认的 WindowShortcut
            // 要求 `window->isActive()`（qquickshortcut.cpp 的 context matcher），cocoa 上从终端
            // 起的进程抢不到前台，Esc 用例就会全红。
            context: Qt.ApplicationShortcut
            // 只有栈顶（最后打开）那一层听 Esc：一次 Esc 关一层
            // （modalContentFoundation.ts 的 escListenerStack）。不用 `visible` 挡是
            // 因为 close 之后 onClosed 必然把 escIsTop 收掉，两条闸门同义、留着只会互相
            // 遮蔽（变异复核里「不看 visible」因此打不红）。
            enabled: control.closeOnEsc && control.escIsTop
            onActivated: control.handleCancel("esc")
        }

        // $color-modal-bg / $radius-modal_content / $width-modal_content-border /
        // $shadow-modal_content；全屏那档圆角 0、无描边
        Rectangle {
            id: surface

            objectName: "modalSurface"
            anchors.fill: parent
            color: Theme.current.colorBg2
            radius: control.fullScreen ? 0 : Theme.current.radiusLarge
            border.width: control.fullScreen ? 0 : control.borderWidth
            border.color: Theme.current.colorBorder
        }

        SemiPopupShadow {
            objectName: "modalShadow"

            anchors.fill: surface
            z: -1
            visible: !control.fullScreen
            radius: surface.radius
            fill: Theme.current.colorBg2
        }

        // .semi-modal-content 是 flex column，三块按声明序竖排
        Column {
            id: stack

            objectName: "modalStack"
            x: control.borderWidth + control.contentPaddingX
            y: control.borderWidth
            width: control.blockWidth
            spacing: 0

            // ---------------- 头部
            Item {
                id: headerBlock

                objectName: "modalHeader"
                visible: control.headerTaken
                width: stack.width
                height: control.headerBlockHeight

                // 自定义头部（字符串档）：官方是 props.header 原样落地
                Text {
                    id: headerText

                    objectName: "modalHeaderText"
                    visible: control.headerIsText
                    width: stack.width
                    text: control.headerIsText ? String(control.header) : ""
                    color: Theme.current.colorText0
                    // .semi-modal 的 @include font-size-regular = 14 / 20
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: 20
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }

                Loader {
                    id: headerNodeLoader

                    objectName: "modalHeaderNode"
                    active: control.headerIsNode
                    sourceComponent: control._nodeOf(control.header)
                    width: stack.width
                    height: (item as Item) ? (item as Item).implicitHeight : 0
                    visible: active
                }

                // 默认头部那一行：图标 + 标题 +（×）
                Item {
                    id: headerRow

                    objectName: "modalHeaderRow"
                    visible: control.headerIsDefault
                    width: stack.width
                    y: control.blockMarginY
                    height: control.headerRowHeight

                    Icon {
                        id: headerIcon

                        objectName: "modalIcon"
                        visible: control.iconIsText
                        anchors.verticalCenter: parent.verticalCenter
                        name: control.iconIsText ? String(control.icon) : ""
                        size: control.iconWidth
                        color: control.iconColor
                    }

                    Loader {
                        id: headerIconLoader

                        objectName: "modalIconNode"
                        active: control.iconTaken && !control.iconIsText
                        sourceComponent: control._nodeOf(control.icon)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: active
                    }

                    Text {
                        id: titleText

                        objectName: "modalTitle"
                        visible: control.headerIsDefault && control._isText(control.title)
                        x: control.iconTaken ? control.iconWidth + control.tightGap : 0
                        width: Math.max(0, headerRow.width - x
                            - (control.headerCloseTaken ? control.iconWidth : 0))
                        text: control._isText(control.title) ? String(control.title) : ""
                        color: Theme.current.colorText0
                        font.pixelSize: Appearance.titleFontSize(Theme.current, 5)
                        font.weight: Font.DemiBold
                        lineHeight: control.titleLineHeight
                        lineHeightMode: Text.FixedHeight
                        wrapMode: Text.WordWrap
                    }

                    Loader {
                        id: titleLoader

                        objectName: "modalTitleNode"
                        active: control.headerIsDefault && !control._isText(control.title)
                        sourceComponent: control._nodeOf(control.title)
                        x: control.iconTaken ? control.iconWidth + control.tightGap : 0
                        width: Math.max(0, headerRow.width - x
                            - (control.headerCloseTaken ? control.iconWidth : 0))
                        visible: active
                    }

                    IconButton {
                        id: closeButton

                        objectName: "modalClose"
                        anchors.right: parent.right
                        anchors.top: parent.top
                        visible: control.headerCloseTaken
                        icon: control.closeIcon
                        size: Enums.Small
                        variant: Enums.Borderless
                        tone: Enums.Tertiary
                        // 官方的 × 走 onClose → handleCancel，和取消键同一条通道
                        onClicked: control.handleCancel("close")
                    }
                }
            }

            // ---------------- body：margin 与 padding 都是 0
            Item {
                id: bodyBlock

                objectName: "modalBody"
                width: stack.width
                height: control.bodyBlockHeight

                // body-wrapper 那一支（没传 header 也没 title）：图标与 × 在这一层
                Icon {
                    id: wrapperIcon

                    objectName: "modalWrapperIcon"
                    visible: !control.hasHeaderBlock && control.iconIsText
                    y: control.blockMarginY
                    name: control.iconIsText ? String(control.icon) : ""
                    size: control.iconWidth
                    color: control.iconColor
                }

                Loader {
                    id: wrapperIconLoader

                    objectName: "modalWrapperIconNode"
                    active: !control.hasHeaderBlock && control.iconTaken && !control.iconIsText
                    sourceComponent: control._nodeOf(control.icon)
                    y: control.blockMarginY
                    visible: active
                }

                IconButton {
                    id: wrapperCloseButton

                    objectName: "modalWrapperClose"
                    visible: control.wrapperCloseTaken
                    anchors.right: parent.right
                    y: control.blockMarginY
                    icon: control.closeIcon
                    size: Enums.Small
                    variant: Enums.Borderless
                    tone: Enums.Tertiary
                    onClicked: control.handleCancel("close")
                }

                Flickable {
                    id: bodyScroll

                    objectName: "modalBodyScroll"
                    x: control.bodyIndentX
                    y: control.hasHeaderBlock ? 0 : control.blockMarginY
                    width: Math.max(0, bodyBlock.width - control.bodyIndentX)
                    height: control.bodyHeight
                    contentWidth: width
                    contentHeight: contentColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: control.bodyScrollable
                    enabled: control.bodyScrollable
                    clip: true

                    Column {
                        id: contentColumn

                        objectName: "modalContentColumn"
                        width: bodyScroll.width
                        spacing: 0
                    }
                }
            }

            // ---------------- 页脚
            Item {
                id: footerBlock

                objectName: "modalFooter"
                visible: control.footerTaken
                width: stack.width
                height: control.footerBlockHeight

                // 官方默认页脚：先 cancel（tertiary + light）再 ok（okType + solid），右对齐
                Row {
                    id: footerRow

                    objectName: "modalFooterRow"
                    visible: control.footerIsDefault
                    y: control.blockMarginY
                    x: control.footerFill ? 0 : Math.max(0, stack.width - footerRow.implicitWidth)
                    width: control.footerFill ? stack.width : implicitWidth
                    spacing: control.tightGap

                    Button {
                        id: cancelButton

                        objectName: "modalCancelButton"
                        visible: control.cancelTaken
                        text: control.cancelText !== "" ? control.cancelText : qsTr("取消")
                        enabled: !control._boolOf(control.cancelButtonProps, "disabled", false)
                        tone: control._toneOf(
                            control._propOf(control.cancelButtonProps, "type", "tertiary"),
                            Enums.Tertiary)
                        variant: control._variantOf(
                            control._propOf(control.cancelButtonProps, "theme", undefined), Enums.Light)
                        size: control._sizeOf(
                            control._propOf(control.cancelButtonProps, "size", undefined), Enums.Default)
                        loading: control._boolOf(control.cancelButtonProps, "loading",
                            control.cancelLoading)
                        width: control.footerFill
                            ? Math.max(0, (stack.width - control.tightGap) / 2) : implicitWidth

                        onClicked: control.handleCancel("cancel")
                    }

                    Button {
                        id: okButton

                        objectName: "modalOkButton"
                        text: control.okText !== "" ? control.okText : qsTr("确定")
                        enabled: !control._boolOf(control.okButtonProps, "disabled", false)
                        // 官方 type={okType} 在前、{...okButtonProps} 在后 ⇒ props 里的 type 盖 okType
                        tone: control._toneOf(
                            control._propOf(control.okButtonProps, "type", control.okType),
                            Enums.Primary)
                        variant: control._variantOf(
                            control._propOf(control.okButtonProps, "theme", undefined), Enums.Solid)
                        size: control._sizeOf(
                            control._propOf(control.okButtonProps, "size", undefined), Enums.Default)
                        loading: control._boolOf(control.okButtonProps, "loading",
                            control.confirmLoading)
                        width: control.footerFill
                            ? Math.max(0, (stack.width - control.tightGap) / 2) : implicitWidth

                        onClicked: control.handleOk("ok")
                    }
                }

                // 自定义页脚：官方 <div className=-footer>{footer}</div>，那两条 24 外边距照旧
                Text {
                    id: footerText

                    objectName: "modalFooterText"
                    visible: control.footerIsText
                    width: stack.width
                    y: control.blockMarginY
                    text: control.footerIsText ? String(control.footer) : ""
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: 20
                    lineHeightMode: Text.FixedHeight
                }

                Loader {
                    id: footerNodeLoader

                    objectName: "modalFooterNode"
                    active: control.footerIsNode
                    sourceComponent: control._nodeOf(control.footer)
                    y: control.blockMarginY
                    width: stack.width
                    height: (item as Item) ? (item as Item).implicitHeight : 0
                    visible: active
                }
            }
        }
    }
}
