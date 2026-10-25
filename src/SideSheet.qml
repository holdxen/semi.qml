import QtQuick
import QtQuick.Controls as C
import "ModalEscStack.js" as EscStack

// 侧边滑动面板。规格照 semi-ui/sideSheet/{index.tsx,SideSheetContent.tsx} +
// semi-foundation/sideSheet/{sideSheetFoundation.ts,constants.ts} +
// sideSheet/{sideSheet.scss,animation.scss,variables.scss,rtl.scss} 逐条移植。
//
//     SideSheet {
//         id: sheet
//         title: "成员详情"
//         visible: page.open          // 受控：开合归调用方
//         onCancel: page.open = false
//         Text { text: "内容" }
//     }
//
// ---------------------------------------------------------------- 受控模型
// 官方 SideSheet 完全受控：`visible` 默认 false（index.tsx:74），三条关闭路径（右上角 ×、
// 点遮罩、Esc）全都只走到 `handleCancel` → `notifyCancel` → `onCancel(e)`
// （index.tsx:191-193 + sideSheetFoundation.ts:68-70），组件自己**不**把 visible 改成 false，
// 是调用方在回调里改。所以这里：
//   · `closePolicy` 写死 NoAutoClose（否则 Popup 自己关层会把调用方那条 visible 绑定打断）；
//   · × / 遮罩 / Esc 三条都只发 `cancel()`，不调 `close()`；
//   · `afterVisibleChange(isVisible)` 在进/出场动画结束时发。官方是 displayNone 翻转 →
//     `onVisibleChange(!displayNone)`（index.tsx:167-183），而 Qt 的 `Popup.opened` / `closed`
//     恰好是 transition 跑完才 emit（qquickpopup.cpp:846-851 与 :928-932），两条直接对上；
//     `motion: false` 时压根没有 transition，Qt 也照样立刻发这两个信号。
//
// ---------------------------------------------------------------- 几何
// 官方 DOM 是 `.semi-sidesheet`（铺满容器的 wrapper）> `.semi-sidesheet-mask` +
// `.semi-sidesheet-inner`（面板本体）。端口的弹层盒子就是**面板本体**（与 src/Modal.qml
// 同一套写法）：官方落在 `.semi-sidesheet-inner` 上的宽高落在 Popup 自己的 width/height 上，
// 遮罩反过来做成子项、靠负偏移铺满整个容器（Modal 实测这样照样收得到面板之外的点击）。
//   · 主轴：左右方位取宽，上下方位取高。宽按 size 三档 small 448 / medium 684 / large 920
//     （variables.scss:17-19 `$width-sideSheet_size-*`），**size 只给宽**：上下方位的主轴
//     恒等于 448（constants.ts:16 `strings.HEIGHT`；官方 API 表里写的 400 是过时的，
//     见下面「与官方的差异」）；`width` / `height` 传了就盖掉这两条；
//   · 交叉轴：100% 容器（左右方位的高、上下方位的宽都是写死的 "100%"，index.tsx:233,242）；
//   · 位置：`-right { right: 0 }` / `-left` / `-top` / `-bottom`（sideSheet.scss:39-72）。
// 面板内部（`.semi-sidesheet-content` 是 flex column，三块按声明序竖排、之间不留缝）：
//   · 头部 padding 24 / 24 / 20（上 24、左右 24、下 20，sideSheet.scss:94-100），
//     分隔线宽是 **0**（`$width-sideSheet_header-borderBottom: 0px`）⇒ 默认看不见线；
//     标题 18 / 24 / 600 / text-0（:74-82，`flex: 1 0 auto` 吃剩余宽），
//     × 是 IconButton tertiary + borderless + small ⇒ 24×24、内边距 4、圆角 3、字色 text-1、
//     悬浮 fill-0、按下 fill-1（iconButton.scss:51-58 + button.scss:326-341），
//     `align-items: flex-start` ⇒ 与标题行顶对齐。于是头部高 = 24 + max(24, 标题行) + 20 = 68。
//   · body padding **0 24**（纵向没有内边距，:102-106），`flex: 1` + `overflow: auto`。
//   · footer 只有 padding 24（:158-160）：没有默认高度、没有对齐、没有上边框 ——
//     官方压根没有默认页脚（index.tsx:79 `footer: null`，SideSheetContent.tsx:159-163 给真值
//     才渲染），demo 里那两颗右对齐按钮是调用方自己的 markup（index.md:229-234）。
//   · 面板底色 bg-2、**无圆角、无描边**、`overflow: auto`（:84-92）；
//     阴影 `--semi-shadow-elevated` 只在 **mask=false** 时给（:307-310 那条双类名规则）。
//   · 遮罩 rgba(22,22,26,.6)，明暗两档同值（`--semi-color-overlay-bg`）。
// 动效：四条（面板进/出 + 遮罩进/出）都是 180ms + cubic-bezier(.25,.46,.45,.94)
// （animation.scss:1-15）；位移是「自身盒子主轴的一条边长」100%，方向按方位
// （right 从 +宽 收到 0、left 从 −宽、top 从 −高、bottom 从 +高），遮罩只淡入淡出。
// Qt 的 `Easing.BezierSpline` 退化成线性（坑 50），取形状最接近的内置曲线 OutQuad。
// 时长不能读 `Theme.current.duration*` —— 默认主题把全局时长令牌设成 0ms。
//
// ---------------------------------------------------------------- 与官方的差异
//   · `width` / `height` 官方收 number|string（"800px"、"90%"），端口落在 Popup 的 real 宽高上
//     ⇒ 只认数字，要铺满就写 `width: host.width`。另外官方对「左右方位给 height、上下方位给
//     width」是直接忽略那一条，端口不拦：交叉轴的显式值照样生效。
//   · `style` / `maskClassName` / `dialogClassName` / `wrapperExtraProps` / `maskExtraProps` /
//     `canVerticalSetWidth`（内部 prop，只有 Feedback 用）不收：本端口没有 DOM 与 CSS。
//     `className` 与 `direction`（RTL 只有 rtl.scss 那两条：`direction: rtl` 与标题右对齐）
//     收下不落地，只为让官方那类调用点不报未知属性。`headerStyle` / `bodyStyle` 只落地
//     backgroundColor 与 borderBottom（官方 demo 正是用它补那条 0px 的头部分隔线，
//     index.md:225-227）；`bodyStyle.height` 官方那条也是 flex:1 之上的覆盖，端口不做。
//     `maskStyle` 只落地 backgroundColor。
//   · `zIndex` 收下但不生效：层序由 Overlay 的打开顺序决定，本库弹层一族都不写 z
//     （同 src/Modal.qml —— 单把它抬到 1000 会盖掉面板里再开的下拉）。
//   · `keepDOM` 收下但不落地：官方 `shouldRender = visible || keepDOM || (motion &&
//     !displayNone)`（index.tsx:251）要解决的是 React 卸载，QML 里 Popup 关掉不销毁子项，
//     两种模式观察到的是同一件事。
//   · `disableScroll` 落地成「面板之外吃滚轮」：官方往 body 上写 `overflow: hidden`
//     （sideSheetFoundation.ts:72-81），Qt 没有文档级滚动，端口用一条只挂 `WheelHandler` 的
//     铺满层吃掉滚轮。它不挂 TapHandler、也不接收鼠标键 ⇒ 点选照旧穿透，正好对上官方
//     `mask={false}` + `disableScroll={false}` 那一节「外部可点也可滚」。传了
//     `getPopupContainer` 时官方不锁滚（index.tsx:110 那条 gate），这里同样不锁。
//   · `modal` 跟着 `mask` 走：官方 mask=false 时页面后面照常可点（那一节 demo 就是点外面的
//     按钮），不像 Modal 那样整层拦死。
//   · Esc 复用 Modal 那一份 `ModalEscStack.js`：官方 SideSheet 自己不入栈（每个打开的面板
//     都往 window 上挂 keydown，一次 Esc 会把所有层一起关掉，sideSheetFoundation.ts:84-91），
//     而 Qt 里两条 sequence 相同的 `Shortcut` 同时 enabled 会互相判歧义、**谁都不触发**，
//     所以只能沿用「只 enable 栈顶」那一条。
//   · `closeIcon` 官方是 ReactNode，且写 `closeIcon={null}` 会回落成默认那颗 ×
//     （SideSheetContent.tsx:108 的 `closeIcon || <IconClose/>`，官方 demo 那么写其实去不掉）；
//     端口收字符串图标名，要把整颗按钮去掉请用 `closable: false`。
//   · 官方 `aria-label`（index.tsx:70 / SideSheetContent.tsx:34）声明了但压根发不出去
//     （wrapper 只 spread `getDataAttr(rest)`，只留 `data-*`），端口不做这条；官方真发出去的
//     三条做了：面板 `role="dialog"`、头部 `role="heading" aria-level=1`、遮罩 `aria-hidden`。
//     `aria-modal` / `aria-labelledby` 官方也没有。
//   · 官方头部那一块**永远渲染**（SideSheetContent.tsx:100 外层 div 没有 gate），
//     没 title 也没 × 时就是 24 + 0 + 20 = 44 的一条空带；端口照抄（旧版本会整块收起来）。
//   · 自定义节点那两档量高只认载入项的 `implicitHeight`（Loader 写了显式宽高就会接管载入项
//     尺寸）—— 与 src/Modal.qml 同一条契约。
C.Popup {
    id: control

    // ---------------------------------------------------------------- 官方 SideSheetProps
    // `visible` 就是官方那条受控开关，直接落在 Popup 自己的 visible 上。
    property string placement: "right"          // top | bottom | left | right
    property string size: "small"               // small | medium | large（只给左右方位定宽）
    property bool motion: true
    property bool mask: true
    property bool maskClosable: true
    property bool closable: true
    property string closeIcon: "close"
    property bool closeOnEsc: false
    property bool keepDOM: false
    property bool disableScroll: true
    property int zIndex: 1000                   // 收下不生效（层序交给 Overlay）
    property var title: undefined
    property var footer: undefined
    property var bodyStyle: undefined
    property var headerStyle: undefined
    property var maskStyle: undefined
    property var getPopupContainer: null
    property string className: ""
    property string direction: "ltr"

    signal cancel
    signal afterVisibleChange(bool isVisible)

    // 官方 children 就是 .semi-sidesheet-body 里的内容
    default property alias content: bodyColumn.data

    readonly property alias panel: panel
    readonly property alias closeButton: closeButton

    // ---------------------------------------------------------------- 派生量
    readonly property Item host: control.parent
    readonly property real hostWidth: control.host ? control.host.width : 0
    readonly property real hostHeight: control.host ? control.host.height : 0
    // 命名照 index.tsx:231-232：isVertical 是左右、isHorizontal 是上下。
    // 上下方位下面板是一条横带，主轴（伸缩那一边）是高。
    readonly property bool isHorizontal: control.placement === "top"
        || control.placement === "bottom"
    readonly property bool onLeft: control.placement === "left"
    readonly property bool onBottom: control.placement === "bottom"

    // 主轴尺寸：左右取宽（size 三档），上下取高（strings.HEIGHT 恒 448，size 不参与）
    readonly property real sizeMainAxis: control.isHorizontal ? 448
        : (control.size === "medium" ? 684 : (control.size === "large" ? 920 : 448))

    // 官方两处都是 JS 真值判断（SideSheetContent.tsx:100 `if (title)`、:159 `props.footer ?`），
    // 所以空串标题等于没有标题，只是头部那一条带照样占 24 + 0 + 20。
    readonly property bool titleTaken: !!control.title
    readonly property bool titleIsText: control.titleTaken && control._isText(control.title)
    readonly property bool titleIsNode: control.titleTaken && !control.titleIsText
    readonly property bool closeTaken: control.closable
    // 官方 `const iconType = closeIcon || <IconClose/>`（SideSheetContent.tsx:108）：
    // 传假值一律回落默认那颗 ×，所以 `closeIcon={null}` 去不掉图标，只能 closable: false。
    readonly property string closeIconName: control.closeIcon !== "" ? control.closeIcon : "close"
    readonly property bool footerTaken: !!control.footer
    readonly property bool footerIsText: control.footerTaken && control._isText(control.footer)
    readonly property bool footerIsNode: control.footerTaken && !control.footerIsText

    // ---------------------------------------------------------------- 度量令牌
    readonly property real headerPaddingTop: Theme.current.spacingLoose            // 24
    readonly property real headerPaddingX: Theme.current.spacingLoose              // 24
    readonly property real headerPaddingBottom: Theme.current.spacingBaseLoose    // 20
    readonly property real bodyPaddingX: Theme.current.spacingLoose                // 0 24
    readonly property real footerPadding: Theme.current.spacingLoose               // 24
    readonly property real closeSize: Theme.current.heightControlSmall             // 24
    // Typography.Title heading=5 的度量：字号 18、行高 24（$font-sideSheet_title-fontSize
    // = $font-size-header-5，字重 $font-weight-bold = 600）
    readonly property real titleFontSizePx: Appearance.titleFontSize(Theme.current, 5)
    readonly property real titleLineHeight: Appearance.titleLineHeight(Theme.current, 5)

    // 头/身的分隔线只能从 headerStyle / bodyStyle 里来：官方 CSS 写死了
    // `border-bottom: 0px solid var(--semi-color-border)`（variables.scss:19），
    // 于是默认一条线都没有，官方 demo 靠 `borderBottom: '1px solid …'` 简写补上
    // （index.md:225-227）。简写在端口拆不成三段，按「宽 + 色」两个槽读。
    readonly property var __headerBorder: control._borderOf(control.headerStyle)
    readonly property var __bodyBorder: control._borderOf(control.bodyStyle)
    readonly property real headerBorderWidth: control.__headerBorder.width
    readonly property string headerBorderCss: control.__headerBorder.color
    readonly property real bodyBorderWidth: control.__bodyBorder.width
    readonly property string bodyBorderCss: control.__bodyBorder.color
    // 空串喂给 color 属性会报无效转换，没线那档直接画透明
    readonly property color headerBorderPaint: control.headerBorderCss === ""
        ? "transparent" : control.headerBorderCss
    readonly property color bodyBorderPaint: control.bodyBorderCss === ""
        ? "transparent" : control.bodyBorderCss
    // headerStyle / bodyStyle 的 backgroundColor 落到两块自己的底色矩形上
    // （官方 .semi-sidesheet-header / -body 默认都没有底色，只有 padding）
    readonly property string headerBgCss: control._colorOf(control.headerStyle,
        "backgroundColor", "background")
    readonly property string bodyBgCss: control._colorOf(control.bodyStyle,
        "backgroundColor", "background")
    readonly property color headerBgPaint: control.headerBgCss === ""
        ? "transparent" : control.headerBgCss
    readonly property color bodyBgPaint: control.bodyBgCss === ""
        ? "transparent" : control.bodyBgCss

    readonly property real blockWidth: Math.max(0, control.width - control.bodyPaddingX * 2)

    // 标题行：官方是 flex 行，内容是标题（18/24，长文案换行）与 × 取高者
    readonly property real titleNodeHeight: control.titleIsNode
        ? ((titleNode.item as Item) ? (titleNode.item as Item).implicitHeight : 0) : 0
    readonly property real headerRowHeight: Math.max(
        control.titleTaken ? Math.max(control.titleLineHeight, titleText.implicitHeight,
            control.titleNodeHeight) : 0,
        control.closeTaken ? control.closeSize : 0)
    readonly property real headerOuterHeight: control.headerPaddingTop
        + control.headerRowHeight + control.headerPaddingBottom + control.headerBorderWidth

    readonly property real footerNaturalHeight: control.footerIsText
        ? footerText.implicitHeight
        : ((footerNode.item as Item) ? (footerNode.item as Item).implicitHeight : 0)
    readonly property real footerOuterHeight: control.footerTaken
        ? (control.footerPadding * 2 + control.footerNaturalHeight) : 0

    readonly property real bodyNaturalHeight: bodyColumn.implicitHeight
    // body 是 flex:1 那一块，官方用 border-box ⇒ 分隔线算在它自己的高度里
    readonly property real bodyHeight: Math.max(0, control.height - control.headerOuterHeight
        - control.footerOuterHeight)
    // 官方 body 自带 overflow: auto ⇒ 内容超出就滚，不需要额外开关
    readonly property bool bodyScrollable: control.bodyNaturalHeight > control.bodyHeight

    // 弹层盒子 = 面板本体：主轴尺寸走调用方显式给的 width / height（官方那两条 prop 在端口
    // 就是 Popup 自己的宽高，只认数字），没给就落回下面两条 implicit。
    implicitWidth: control.isHorizontal ? control.hostWidth : control.sizeMainAxis
    implicitHeight: control.isHorizontal ? control.sizeMainAxis : control.hostHeight

    x: control.isHorizontal ? 0
        : (control.onLeft ? 0 : Math.max(0, control.hostWidth - control.width))
    y: control.isHorizontal
        ? (control.onBottom ? Math.max(0, control.hostHeight - control.height) : 0) : 0

    parent: control.getPopupContainer ? control.getPopupContainer() : C.Overlay.overlay
    // 官方 mask=false 时外部区域照常可操作 ⇒ modal 跟着 mask 走，不能像 Modal 那样常开
    modal: control.mask
    dim: false                                  // 遮罩自绘
    focus: true
    padding: 0
    // 同 Modal：本体由 panel 里的 sideSheetSurface + sideSheetShadow 画。样式默认的
    // background 是一块不透明直角矩形，挂在 panel 外面就不跟着滑动动画走，
    // 卡片滑进来时它整块先留在那儿。
    background: null
    // 所有关闭路径都只 notify ⇒ 开合交给调用方
    closePolicy: C.Popup.NoAutoClose

    // ---------------------------------------------------------------- 动效
    readonly property int motionDuration: 180   // $animation_duration-sideSheet_*
    readonly property int motionEase: Easing.OutQuad

    enter: Transition {
        NumberAnimation {
            target: panel
            property: "progress"
            from: 0
            to: 1
            duration: control.motion ? control.motionDuration : 0
            easing.type: control.motionEase
        }
    }

    exit: Transition {
        NumberAnimation {
            target: panel
            property: "progress"
            from: 1
            to: 0
            duration: control.motion ? control.motionDuration : 0
            easing.type: control.motionEase
        }
    }

    onOpened: {
        EscStack.push(control.__escId, control.__setEscTop);
        control.afterVisibleChange(true);
    }

    onClosed: {
        EscStack.remove(control.__escId);
        control.afterVisibleChange(false);
    }

    Component.onDestruction: EscStack.remove(control.__escId)

    readonly property int __escId: EscStack.nextId()

    // 栈顶标记必须由 ModalEscStack 回灌：`.js` 里的数组变化不是 notify，
    // 写在绑定里的 isTop() 不会重算（同 src/Modal.qml:342-347）。
    property bool escIsTop: false

    function __setEscTop(isTop) {
        control.escIsTop = isTop;
    }

    // ---------------------------------------------------------------- 属性取值小工具
    function _propOf(obj, key, fallback) {
        if (obj === undefined || obj === null)
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

    // 只落地颜色这一条：本端口没有 CSS 层，`var(--semi-color-*)` 这种值转成 color 会无效，
    // 调用方要写 Theme.current 的令牌串。
    function _colorOf(obj, key, altKey) {
        let v = control._propOf(obj, key, undefined);
        if (v === undefined && altKey !== undefined)
            v = control._propOf(obj, altKey, undefined);
        if (typeof v !== "string" || v === "")
            return "";
        return v;
    }

    // CSS 的 `border-bottom: 1px solid X` 拆不成三段，这里按「第一个数是宽、最后一个非
    // 关键字的段是色」读；`borderBottomWidth` / `borderBottomColor` 两条单独给也能生效。
    // 宽或色缺一条就不画 —— 官方默认那条是 `0px solid`，所以缺省就是没有线。
    function _borderOf(obj) {
        let w = 0;
        let c = "";
        const shorthand = control._propOf(obj, "borderBottom", undefined);
        if (typeof shorthand === "string" && shorthand !== "") {
            const parts = shorthand.split(" ");
            w = parseFloat(parts[0]);
            for (let i = 1; i < parts.length; ++i) {
                if (parts[i] !== "solid" && parts[i] !== "dashed" && parts[i] !== "dotted")
                    c = parts.slice(i).join(" ");
            }
        }
        const ownWidth = control._numOf(obj, "borderBottomWidth", NaN);
        if (!Number.isNaN(ownWidth))
            w = ownWidth;
        const ownColor = control._propOf(obj, "borderBottomColor", undefined);
        if (typeof ownColor === "string" && ownColor !== "")
            c = ownColor;
        if (!(w > 0) || c === "")
            return ({ width: 0, color: "" });
        return ({ width: w, color: c });
    }

    function _isText(value) {
        return typeof value === "string" || typeof value === "number";
    }

    // Loader.sourceComponent 只收 Component：字符串档必须给 null
    function _nodeOf(value) {
        return value !== undefined && value !== null && !control._isText(value) ? value : null;
    }

    // ---------------------------------------------------------------- .semi-sidesheet-mask
    // 官方与面板同级、铺满容器。这里做成子项、靠负偏移铺出去（同 src/Modal.qml:479-517）。
    Item {
        id: wrap

        objectName: "sideSheetWrap"

        x: -control.x
        y: -control.y
        width: control.hostWidth
        height: control.hostHeight
        visible: control.mask || control.disableScroll
        // 遮罩在官方那边是 aria-hidden（SideSheetContent.tsx:80）
        Accessible.ignored: true

        Rectangle {
            objectName: "sideSheetMask"

            anchors.fill: parent
            visible: control.mask
            // $animation_duration-sideSheet_mask-* = 180ms 的纯透明度进出
            opacity: control.motion ? panel.progress : 1
            color: control._colorOf(control.maskStyle, "backgroundColor", "background") !== ""
                ? control._colorOf(control.maskStyle, "backgroundColor", "background")
                : Theme.current.colorOverlayBg
        }

        TapHandler {
            objectName: "sideSheetMaskTap"

            acceptedButtons: Qt.LeftButton
            enabled: control.mask && control.maskClosable
            onTapped: {
                // 官方 handleMaskClick 的 e.target === e.currentTarget：
                // 落点在面板盒子之内就不算点遮罩（SideSheetContent.tsx:59-63）。
                // 换回弹层盒子坐标系后，面板就摆在 (0,0) 上、尺寸是 control 自己的宽高。
                const gx = point.position.x + wrap.x;
                const gy = point.position.y + wrap.y;
                if (gx >= 0 && gx < control.width && gy >= 0 && gy < control.height)
                    return;
                control.cancel();
            }
        }

        // disableScroll 的落点：只吃滚轮、不吃鼠标（见文件头那条差异说明）。
        WheelHandler {
            objectName: "sideSheetScrollLock"

            enabled: control.disableScroll && control.getPopupContainer === null
        }
    }

    // ---------------------------------------------------------------- .semi-sidesheet-inner
    Item {
        id: panel

        objectName: "sideSheetPanel"

        // 滑动进度：0 = 完全在屏幕外，1 = 就位。由上面的 enter/exit Transition 驱动。
        property real progress: 1

        x: 0
        y: 0
        width: control.width
        height: control.height
        // 阴影要画在盒子之外，所以裁剪交给里面那只 Flickable，这一层不 clip
        Accessible.role: Accessible.Dialog

        transform: Translate {
            id: slide

            readonly property real dist: control.isHorizontal ? panel.height : panel.width
            readonly property real sign: (control.placement === "right"
                || control.placement === "bottom") ? 1 : -1

            x: control.isHorizontal ? 0 : slide.dist * slide.sign * (1 - panel.progress)
            y: control.isHorizontal ? slide.dist * slide.sign * (1 - panel.progress) : 0
        }

        Rectangle {
            objectName: "sideSheetSurface"

            anchors.fill: parent
            // $color-sidesheet-bg = var(--semi-color-bg-2)；无圆角、无描边
            color: Theme.current.colorBg2
        }

        // 官方那条阴影只在 mask=false 时给
        // （.semi-sidesheet-fixed .semi-sidesheet-inner { box-shadow: var(--semi-shadow-elevated) }）
        SemiPopupShadow {
            objectName: "sideSheetShadow"

            anchors.fill: parent
            z: -1
            visible: !control.mask
            radius: 0
            fill: Theme.current.colorBg2
        }

        // ---------------- 头部：官方永远渲染这一层
        Item {
            id: headerBlock

            objectName: "sideSheetHeader"

            x: control.headerPaddingX
            y: 0
            width: control.blockWidth
            height: control.headerOuterHeight
            Accessible.role: Accessible.Heading

            Rectangle {
                objectName: "sideSheetHeaderBackground"

                anchors.fill: parent
                visible: control.headerBgCss !== ""
                color: control.headerBgPaint
            }

            Rectangle {
                objectName: "sideSheetHeaderDivider"

                // 官方 border-bottom 贴整块头部底边（在左右 padding 之外）
                x: -control.headerPaddingX
                width: panel.width
                y: parent.height - control.headerBorderWidth
                height: control.headerBorderWidth
                visible: control.headerBorderWidth > 0
                color: control.headerBorderPaint
            }

            Item {
                id: headerRow

                objectName: "sideSheetHeaderRow"

                y: control.headerPaddingTop
                width: parent.width
                height: control.headerRowHeight

                Text {
                    id: titleText

                    objectName: "sideSheetTitle"

                    visible: control.titleIsText
                    width: Math.max(0, headerRow.width
                        - (control.closeTaken ? control.closeSize : 0))
                    text: control.titleIsText ? String(control.title) : ""
                    color: Theme.current.colorText0
                    // 官方 .semi-sidesheet-title：18 / 24 / 600
                    font.pixelSize: control.titleFontSizePx
                    font.weight: Font.DemiBold
                    lineHeight: control.titleLineHeight
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }

                Loader {
                    id: titleNode

                    objectName: "sideSheetTitleNode"

                    visible: control.titleIsNode
                    active: visible
                    sourceComponent: control._nodeOf(control.title)
                    width: Math.max(0, headerRow.width
                        - (control.closeTaken ? control.closeSize : 0))
                }

                IconButton {
                    id: closeButton

                    objectName: "sideSheetClose"

                    anchors.right: parent.right
                    anchors.top: parent.top
                    visible: control.closeTaken
                    icon: control.closeIconName
                    size: Enums.Small
                    variant: Enums.Borderless
                    tone: Enums.Tertiary
                    // 官方 × 走 onClose → handleCancel，与遮罩、Esc 同一条通道
                    onClicked: control.cancel()
                }
            }
        }

        // ---------------- body：padding 0 24、flex 1、overflow auto
        Item {
            id: bodyBlock

            objectName: "sideSheetBody"

            x: control.bodyPaddingX
            y: control.headerOuterHeight
            width: control.blockWidth
            height: control.bodyHeight

            Rectangle {
                objectName: "sideSheetBodyBackground"

                anchors.fill: parent
                visible: control.bodyBgCss !== ""
                color: control.bodyBgPaint
            }

            Flickable {
                id: bodyScroll

                objectName: "sideSheetBodyScroll"

                anchors.fill: parent
                contentWidth: width
                contentHeight: control.bodyNaturalHeight
                boundsBehavior: Flickable.StopAtBounds
                // 官方 `overflow: auto`：内容不够就既不滚也不出条。只关 interactive，
                // 不关 enabled —— 后者会把 body 里按钮们的点击一起挡掉。
                interactive: control.bodyScrollable
                clip: true

                Column {
                    id: bodyColumn

                    objectName: "sideSheetBodyColumn"

                    width: bodyScroll.width
                    // 官方 body 里就是 children 竖排，没有任何 gap
                    spacing: 0
                }
            }

            Rectangle {
                objectName: "sideSheetBodyDivider"

                x: -control.bodyPaddingX
                width: panel.width
                anchors.bottom: parent.bottom
                height: control.bodyBorderWidth
                visible: control.bodyBorderWidth > 0
                color: control.bodyBorderPaint
            }
        }

        // ---------------- footer：只有 padding 24，没有默认内容、没有对齐
        Item {
            id: footerBlock

            objectName: "sideSheetFooter"

            x: control.bodyPaddingX
            y: panel.height - control.footerOuterHeight
            width: control.blockWidth
            height: control.footerOuterHeight
            visible: control.footerTaken

            Text {
                id: footerText

                objectName: "sideSheetFooterText"

                visible: control.footerIsText
                width: parent.width
                y: control.footerPadding
                text: control.footerIsText ? String(control.footer) : ""
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
                wrapMode: Text.WordWrap
            }

            Loader {
                id: footerNode

                objectName: "sideSheetFooterNode"

                visible: control.footerIsNode
                active: visible
                sourceComponent: control._nodeOf(control.footer)
                width: parent.width
                y: control.footerPadding
                height: (item as Item) ? (item as Item).implicitHeight : 0
            }
        }
    }

    // ---------------------------------------------------------------- Esc
    // 官方在打开期间往 window 上挂 keydown（sideSheetFoundation.ts:84-91），默认不听。
    Shortcut {
        objectName: "sideSheetEscShortcut"

        sequences: [StandardKey.Cancel]
        // 与 Modal 同一条理由：官方不看窗口焦点，而默认的 WindowShortcut 要 window->isActive()，
        // cocoa 上从终端起的进程抢不到前台。
        context: Qt.ApplicationShortcut
        enabled: control.closeOnEsc && control.escIsTop
        onActivated: control.cancel()
    }
}
