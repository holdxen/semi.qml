import QtQuick
import QtQuick.Controls as C
import Semi

// 文字提示。挂在 target 上，按 trigger 指定的动作弹出，用于解释一个控件或一段文字。
//
//     Button { id: btn; text: "悬停我" }
//     Tooltip { target: btn; text: "这是一条提示"; position: Enums.Top }
//
//     Tooltip { target: btn; text: "受控"; trigger: "custom"; visible: page.tipOpen }
//
// 规格全部照 semi-ui/tooltip（index.tsx:128-194 的 propTypes 与 defaultProps 字面顺序、
// :448-472 的点外判定）与 semi-foundation/tooltip（foundation.ts:201-284 _generateEvent、
// :305-340 delayShow/show、:1207-1231 delayHide/hide、:1277-1329 _handleTriggerKeydown
// 与 _handleEscKeyDown、:438-627 定位算式、constants.ts:8-45 枚举与默认值、
// tooltip.scss + variables.scss + arrow.scss 度量）。
//
// 度量（variables.scss 逐条）：
//   宽 max-width 240（$width-tooltip，官方「覆盖特定样式」用 style.maxWidth 覆盖它）、
//   内边距左右 12（$spacing-base-tight）上下 8（$spacing-tight）、字号 14
//   （$font-tooltip-fontSize）、行高 20、圆角 radius-medium 6（$radius-tooltip）、
//   底色 grey-7（$color-tooltip-bg-default）、文字 bg-0（$color-tooltip-text-default）；
//   **没有阴影**（tooltip.scss 里不含 shadow-elevated）；
//   小三角 24×7（水平）/ 7×24（垂直）、探出 6px（arrow.scss 的 bottom: -7 + 1），
//   角落方位时三角中心离卡片边 18px（$spacing-tooltip_arrow_adjusted_offset-x =
//   round(0.24 × 24) = 6，再加半个箭头宽 12）；带三角的卡片最小宽 36 = 6*2 + 24、
//   最小高 34 = 24 + 5*2；进出场各 100ms + easeOutCubic、scale .8↔1、opacity 只走前 50% / 60%
//   （这一条在基座 PopupBase 的 enter / exit，与官方同一份 keyframes，`motion` 也在那里）；
//   卡片与 target 的主轴间距 spacing 8（numbers.SPACING）、翻面余量 margin 0
//   （numbers.MARGIN）、层级 zIndex 1060（numbers.DEFAULT_Z_INDEX）、
//   延迟 mouseEnterDelay / mouseLeaveDelay 都是 50ms（numbers.MOUSE_*_DELAY）。
//
// 触发模型（_generateEvent 五档，逐档）：
//   · hover：mouseEnter → delayShow、mouseLeave → delayHide，**另外还绑了 focus/blur**
//     （a11y，:241-248，由 disableFocusListener 关掉）；卡片本身的事件集是这一份的拷贝
//     （:250 `portalEventSet = { ...triggerEventSet }`），所以鼠标从 target 挪进卡片不会消失；
//     clickToHide 会把卡片的 click 换成「置 isClickToHide + hide」，并给卡片的 mouseEnter
//     加一条「刚被点过就别再弹」的闸门（:251-262），而 target 的 mouseEnter 会先清掉这个标记
//     （:233）；
//   · focus：focus → delayShow、blur → delayHide。这一档**不看 disableFocusListener**
//     （:212-217 没有那个判断，只有 hover 档的那对看），且 portalEventSet 就是同一个对象
//     （:218，不是拷贝）；
//   · click：只绑 click → show()（**不是开关**，已开着再点还是开），关由点外收起负责；
//   · contextMenu：只绑 contextMenu → e.preventDefault() + show()，关同样靠点外；
//   · custom：什么都不绑，显隐完全由 `visible` 说了算；点外只注册一个空回调
//     （:366-368），也就是 `clickedOutside` 照发、但不会因此收起。
//   点外 handler 绑在 document 上并排除掉 trigger 与卡片自身（index.tsx:452-472），
//   click / contextMenu / clickTriggerToHide 三档才把 hide 挂上去（:379-381）。
//   condition !== false 只挡「显示」那几条路径（:213/:223/:232/:243/:262/:272），
//   隐藏与 blur 不挡；custom 档没有 handler，所以 condition 对它整个无效。
//   show() 自己只看 animating 与 visible（:333-339），内容空不空它不管 —— 所以这里
//   没有「text 为空就不弹」这种额外条件。
//   Esc：keydown 绑在 trigger 上（:202-208，五档都绑），但走的是
//   `closeOnEsc && _handleEscKeyDown(event)`（:1286）—— **closeOnEsc 缺省 false，
//   所以默认按 Esc 既不关层、也不发 onEscKeyDown**；发了的时候，非 custom 档先
//   focusTrigger 再 hide（:1321-1327，避免「焦点回到 trigger 又把它弹开」）。
//
// 与官方的差异（React / CSS 在 QML 侧无处落地，逐条）：
//   · 官方把 Tooltip 包在 children 外面（并替它合并事件与 ref），QML 的 Item 没有这层
//     能力，改成显式的 `target`。挂在 target 上的是 HoverHandler / TapHandler / Connections，
//     target 自己的点击照旧生效（实测两个同 parent 的 TapHandler 都能收到 tapped，
//     qquicktaphandler.cpp:70 的 wantsEventPoint 没有 QQuickPointHandler 那种「同 parent
//     同类就避让」的逻辑）；但**目标自己（或它的子项）里有会吃掉 press 的 MouseArea 时
//     拿不到点击**（exclusive grab 归那个 MouseArea，实测 0 次），所以 click / contextMenu
//     两档只适用于本库自己的控件（Button / Tag / Switch 内部都是 TapHandler）。
//   · 官方 `content` 收 ReactNode 或 `(props) => ReactNode`。基座 PopupBase 已把 `content`
//     用作默认属性别名（子项进 contentItem），这里不能重名，于是拆成 `text`（字符串档）
//     与 children（富内容档）两条 —— 官方「位置」那节的 `<article><p>hi bytedance</p>×2`
//     就是 children 档。
//   · `position` 收 Enums.Placement 那 12 档，与 PopupBase.placement / UserGuide 同一口径。
//     官方 strings.POSITION_SET 另有 leftTopOver / rightTopOver / leftBottomOver /
//     rightBottomOver 四档，文档 API 表里根本没写（只在 story 里出现），本库不补。
//   · `spacing` / `margin` 官方是 number | object 两型。object 档（spacing.x/.y 按方位分
//     主轴与交叉轴、margin 四边）没有 demo 用到，只落地 number 那一档；且官方 margin
//     **只参与翻面判定、不进最终 left/top**（foundation.ts:887-890 只出现在 :935-972 的
//     shouldReverse* 里），这里同一口径，做成基座的 fitMargin。
//   · 三角形状：照抄官方 SVG 路径。Tooltip 那颗是 `TriangleArrow.tsx` 的 24×7（两条边是**内凹**的
//     三次曲线，不是直边三角 —— 直边画出来就是个钝钝的楔子，与 Semi 的样子差一档），左右方位
//     换 `TriangleArrowVertical.tsx` 的 7×24。摆放吃 `arrow.scss` 的三个量：底边压进卡片边
//     1px（`$spacing-tooltip_arrow_offset-x` / `-y`「渲染会有缝隙，所以加个偏移量」）、
//     沿边离角 18（`$spacing-tooltip_arrow_adjusted_offset-x` = round(0.24×24) = 6 加半个宽 12）、
//     带三角的最小尺寸 36×34。Popover 那一档同一条形状但多一条描边 path（`popover/Arrow.tsx`
//     两条 path，24×8），差在 `PopupBase.arrowStroked`。
//   · 上游 `arrowBounding` 只读 width 与 offsetY —— 垂直方向那行也取的是
//     `arrowBounding.width`（foundation.ts:458），所以 JS 算的是 6 + 24/2 = 18，而 arrow.scss
//     给垂直三角的却是 `top: 5px`（中心 17）。**上游这两处差 1px**，这里统一按 18 实现。
//   · `arrowPointAtCenter` 的缺省值上游是 `!showArrow ? showArrow : arrowPointAtCenter`
//     （render 里取的，index.tsx:767 附近）：只有 `overrideDefaultProps.Tooltip.showArrow`
//     被配成假值时才会连带把它变成假；此时卡片沿交叉轴不再平移，本库同一口径
//     （pointsAtCenter = showArrow && arrowPointAtCenter）。
//   · `showArrow` 官方还收 ReactNode（自定义箭头节点），这里只有布尔。
//   · `keepDOM` 不落 QML：官方 false 是退场后把 portal 从 DOM 摘掉、true 是留一份
//     display:none。Qt 的 Popup 关掉就是不渲染，两档没有区别，所以不开放这个字段。
//   · `getPopupContainer` 官方还有一句「容器不是 body 时得自己写 position: relative」，
//     QML 没有绝对定位那一层，`container` 直接就是弹层的 parent，位置按容器坐标系算。
//   · Esc 那一档：本库没有用 Controls 的 CloseOnEscape（它不认 anchor、也不发信号），
//     改成 open 期间挂一只 `Shortcut`（Qt 6.11 的 QtQuick 里**没有 KeyHandler** 类型，
//     实测 `KeyHandler is not a type`，只能走 Shortcut）。差别是官方的 keydown 绑在
//     trigger 上、焦点在哪都能收到，本库是窗口级：同一窗口里若还有别的 Esc 处理者会互相影响。
//   · `stopPropagation` / `wrapperClassName` / `wrapperId` / `className` / `style` /
//     `prefixCls` / `guardFocus` / `disableArrowKeyDown` / `preventScroll` /
//     `transformFromCenter` / `arrowBounding` / `role` / `wrapWhenSpecial` 都是 DOM 或
//     a11y 框架那一侧的东西，QML 没有对应落点（`Accessible` 附加类型连 value 类属性都没有，
//     见坑 91）；`onVisibleChange` 就是 Popup 自带的 `visibleChanged`，`afterClose` 没有 ——
//     退场动画结束这件事在 QML 侧没有公开信号。
PopupBase {
    id: control

    // ---------------------------------------------------------------- TooltipProps
    property Item target: null                  // 官方是 children 包裹，这里显式指定
    property string text: ""                    // 官方 content 的字符串档
    property string trigger: "hover"            // hover | focus | click | custom | contextMenu
    property int position: Enums.Top            // strings.POSITION_SET 的前 12 档，默认 top
    property int mouseEnterDelay: 50            // numbers.MOUSE_ENTER_DELAY
    property int mouseLeaveDelay: 50            // numbers.MOUSE_LEAVE_DELAY
    property bool condition: true               // 只挡显示那几条路径
    property bool arrowPointAtCenter: true      // 角落方位时卡片平移，让三角指到目标中心
    // 官方 spacing 这个名字**继承自 C.Popup**（qquickpopup_p.h:89 的 `spacing`，
    // FINAL 不能再声明，但可写；Controls 侧只有 qquickpopup.cpp:1771-1780 把它转发给
    // popupItem 的 QQuickControl::spacing，本库布局一行都不读它 —— 借用零副作用），
    // 值接到下面的 gap 上。numbers.SPACING = 8。
    property real margin: 0                     // numbers.MARGIN，只参与翻面判定
    property int zIndex: 1060                   // numbers.DEFAULT_Z_INDEX
    property bool autoAdjustOverflow: true
    property bool clickToHide: false            // hover 档下点卡片也收
    property bool clickTriggerToHide: false     // 点 trigger 也收（private，配合 click 档）
    property bool disableFocusListener: false   // 只关 hover 档附带的那对 focus/blur
    property bool closeOnEsc: false             // 官方默认 false：Esc 既不关也不发信号
    property var rePosKey: undefined            // 变了就重算一次位置
    property Item container: null               // 官方 getPopupContainer
    property real maxWidth: 240                 // $width-tooltip，官方用 style.maxWidth 覆盖

    // 字符串档那条 label 的皮肤量。官方 Popover 直接套 Tooltip（popover/index.tsx:190-206），
    // 两家的 content 只差在「谁给文字上色、谁给内容留内边距」：tooltip 是 bg-0 字 +
    // 12/8 内边距长在 label 上，popover 是 text-0 字 + 内边距长在卡片上（`-with-arrow` 那 12）。
    // 所以这三条要能换，否则 Popover 用 `text` 会拿白字压在 bg-3 上、还多算一层内边距。
    property color labelColor: Theme.current.colorBg0       // $color-tooltip-text-default
    property real labelPaddingX: Theme.current.spacingBaseTight     // 12
    property real labelPaddingY: Theme.current.spacingTight         // 8

    signal clickedOutside()                     // 官方 onClickOutSide
    signal escKeyDown()                         // 官方 onEscKeyDown

    readonly property bool hoverMode: control.trigger === "hover"
    readonly property bool focusMode: control.trigger === "focus"
    readonly property bool clickMode: control.trigger === "click"
    readonly property bool contextMenuMode: control.trigger === "contextMenu"
    readonly property bool customMode: control.trigger === "custom"
    // disableFocusListener 只削 hover 档的那一对（focus 档自己没写这个判断）
    readonly property bool listensToFocus: control.focusMode
        || (control.hoverMode && !control.disableFocusListener)
    // :379-381 这三档才把 hide 挂到 document 的 mousedown 上；custom 挂的是空函数
    readonly property bool watchesOutside: control.clickMode || control.contextMenuMode
        || control.customMode || control.clickTriggerToHide
    readonly property bool closesOnOutside: control.clickMode || control.contextMenuMode
        || control.clickTriggerToHide

    // 官方 portalEventSet 里 clickToHide 那条闸门用的 cache 值（:251-261），
    // target 的 mouseEnter 清、卡片的一次性 TapHandler 置
    property bool clickToHideLatched: false

    // ---------------------------------------------------------------- 接到基座
    anchor: control.target
    placement: control.position
    // 基座默认挂 Overlay；官方 getPopupContainer 换的就是 portal 的宿主
    parent: control.container !== null && control.container !== undefined
        ? control.container : C.Overlay.overlay
    spacing: 8                                  // numbers.SPACING（见上面那条注释：借 Popup 的名字）
    gap: control.spacing                        // 官方 spacing 就是「主轴间距」
    autoFlip: control.autoAdjustOverflow
    fitMargin: control.margin
    showArrow: true
    arrowSize: 7                                // $height-tooltip_arrow（探出 = 7 − 1 补缝 = 6）
    arrowBase: 24                               // $width-tooltip_arrow
    arrowStroked: false                          // TriangleArrow.tsx 只有一条 currentColor 的 path
    padding: 0                                  // 官方 12 / 8 是**不等**的，吃在 label 自己身上
    contentSpacing: 0                           // 富内容子项之间官方没有额外间距
    fillColor: Theme.current.grey[7]            // $color-tooltip-bg-default
    strokeColor: "transparent"
    radius: Theme.current.radiusMedium          // $radius-tooltip
    shadowEnabled: false                        // tooltip.scss 里没有 shadow-elevated
    z: control.zIndex
    // label 不进气泡列（见下面那条注释：它挂在 background 上），所以卡片尺寸是
    // 「文字那档的边框宽」与「使用方子项的自然宽」两者取大，再夹到 maxWidth，
    // 最后兜一个带三角的最小尺寸。Text.width / implicitWidth 都是含内边距的那一档。
    implicitWidth: Math.max(Math.min(control.maxWidth,
        Math.max(control.hasText ? label.width : 0, control.bodyWidth)),
        control.showArrow ? control.arrowMinWidth : 0)
    implicitHeight: Math.max(control.hasText ? label.implicitHeight : 0,
        control.bodyHeight, control.showArrow ? control.arrowMinHeight : 0)
    // 基座那条 closePolicy 表达式整个换掉：官方既没有 Esc 自动关（closeOnEsc 缺省 false）、
    // 点外那一套也要自己按落点判断（trigger 与卡片都算「里面」）
    closePolicy: C.Popup.NoAutoClose
    pointAtCenter: control.pointsAtCenter

    // 带三角时的最小尺寸（arrow.scss 的 minWidth / minHeight mixin）。
    // 三条都不是 readonly：它们跟着 `$spacing-tooltip_arrow_adjusted_offset-*` 与箭头尺寸走，
    // 而 popover/variables.scss 把同一批变量重新赋值了（adjusted_offset-y 5 → 6、
    // $height-tooltip_arrow 7 → 8），派生的 Popover 要按 popover 那一档改写（见 src/Popover.qml）。
    property real arrowMinWidth: 6 * 2 + 24       // 2 * adjusted_offset-x + 箭头宽
    property real arrowMinHeight: 24 + 5 * 2      // 箭头高 + 2 * adjusted_offset-y
    // 三角中心离卡片边的距离：adjusted_offset(6 水平 / 5 垂直) + 半个箭头宽(12)。
    // 上游垂直那档差 1px，见文件头。
    property real arrowCross: 18
    readonly property bool pointsAtCenter: control.showArrow && control.arrowPointAtCenter

    // 卡片定稿之后才能算三角中心：x/y 是 place() 命令式写的，而 mapToItem 在绑定里不反应
    // （基座为此专门轮询），所以这里也只能现算现写，不能做成绑定。
    // 内容列与字符串档 label 各自占的那一块。label 挂在 background 上（不进 contentItem，
    // 见下面那条注释），所以它的宽**已经含自己的内边距**；子类改内边距时要按这个口径算。
    readonly property real labelWidth: control.hasText ? label.width : 0
    readonly property real labelHeight: control.hasText ? label.implicitHeight : 0
    function updateArrowCenter() {
        if (!control.showArrow) {
            control.arrowCenterX = NaN;
            control.arrowCenterY = NaN;
            return;
        }
        switch (control.effectivePlacement) {
        case Enums.TopLeft: case Enums.BottomLeft:
            control.arrowCenterX = control.arrowCross;
            control.arrowCenterY = NaN;
            return;
        case Enums.TopRight: case Enums.BottomRight:
            control.arrowCenterX = control.width - control.arrowCross;
            control.arrowCenterY = NaN;
            return;
        case Enums.LeftTop: case Enums.RightTop:
            control.arrowCenterY = control.arrowCross;
            control.arrowCenterX = NaN;
            return;
        case Enums.LeftBottom: case Enums.RightBottom:
            control.arrowCenterY = control.height - control.arrowCross;
            control.arrowCenterX = NaN;
            return;
        default:
            break;
        }
        // Top / Bottom / Left / Right：卡片可能被夹进容器过，三角仍要指到目标中心
        const layer = control.parent;
        const t = control.target;
        if (!control.arrowPointAtCenter || !t || !layer) {
            control.arrowCenterX = NaN;
            control.arrowCenterY = NaN;
            return;
        }
        if (control.isVertical(control.effectivePlacement)) {
            const cx = t.mapToItem(layer, t.width / 2, 0).x;
            control.arrowCenterX = Math.max(control.arrowCross,
                Math.min(control.width - control.arrowCross, cx - control.x));
            control.arrowCenterY = NaN;
        } else {
            const cy = t.mapToItem(layer, 0, t.height / 2).y;
            control.arrowCenterY = Math.max(control.arrowCross,
                Math.min(control.height - control.arrowCross, cy - control.y));
            control.arrowCenterX = NaN;
        }
    }

    // ---------------------------------------------------------------- 内容
    // `text` 为空时 label 整个不参与尺寸（否则它那 16 上下内边距会在富内容档里留一块空白）
    readonly property bool hasText: control.text !== ""
    // 只有真超宽才开换行：短文案走 NoWrap，避免「TextMetrics 量的宽」与
    // 「Text 排版用的宽」差零点几 px 就被判成两行
    readonly property bool _textNeedsWrap: natural.width + control.labelPaddingX * 2
        > control.maxWidth

    TextMetrics {
        id: natural

        font.pixelSize: Theme.current.fontSizeRegular      // $font-tooltip-fontSize
        text: control.text
    }

    Text {
        id: label

        objectName: "tooltipLabel"
        // 不挂在 contentItem（那个 Column）上，改挂 background：Column 留给使用方的子项，
        // label 只参与上面那两条 implicitWidth / implicitHeight 的算式。
        // 挂哪儿都得是个 Item —— C.Popup 本身不是 Item，不能当 parent。
        parent: control.background
        // 超宽那一档直接给满 maxWidth；没超宽时 implicitWidth 就是「自然宽 + 左右内边距」，
        // 与排版同源（TextMetrics 的 advanceWidth 会差零点几 px，卡片会比文字窄一点）。
        // 注意这条不能写成 implicitWidth 无条件参与：开了 wrapMode 之后
        // width: implicitWidth 是一条收敛到 0 的环。
        width: control._textNeedsWrap ? control.maxWidth : Math.min(control.maxWidth, implicitWidth)
        leftPadding: control.labelPaddingX                  // 12
        rightPadding: control.labelPaddingX
        topPadding: control.labelPaddingY                   // 8
        bottomPadding: control.labelPaddingY
        color: control.labelColor                           // $color-tooltip-text-default
        font.pixelSize: Theme.current.fontSizeRegular
        lineHeight: 20                                     // $font-tooltip_lineHeight
        lineHeightMode: Text.FixedHeight
        wrapMode: control._textNeedsWrap ? Text.WrapAtWordBoundaryOrAnywhere
            : Text.NoWrap                          // 官方 overflow-wrap: break-word
        text: control.text
    }

    // ---------------------------------------------------------------- 显示与隐藏
    // 官方 delayShow / delayHide 共用一只 _timer（:310 / :1211 各自先 clearDelayTimer），
    // 这里拆成两只、互相 stop，落点同一：待显示期间移开鼠标，那次显示会被取消。
    function delayShow() {
        hideTimer.stop();
        if (control.mouseEnterDelay > 0)
            showTimer.restart();
        else
            control.showNow();
    }

    // 鼠标此刻在不在 target 或卡片之上。两个 HoverHandler 的 enter / leave 谁先来不可控
    // （Qt 的 hover 投递与 DOM 的 mouseleave -> mouseenter 定序不同），所以不靠顺序，
    // 只在 hide 定时器真正到点那一刹现查一次：还在任意一侧就不关。
    // 只管 hover 这一路：focus / click 那几档走的是直接 showNow，不经过这里的判定。
    // 写成函数而不是 readonly property：这条绑定会在实例销毁的过程中被重算一次，
    // 那一刻两个 HoverHandler 已经不在了，绑定读 `null.hovered` 直接抛 TypeError
    // （tst_taginput / tst_treeselect 里那几条 QWARN 就是它）。函数只在定时器到点那一拍被调用。
    function pointerOnTipArea() {
        return targetHover.hovered || tipHover.hovered;
    }

    function delayHide() {
        showTimer.stop();
        if (control.mouseLeaveDelay > 0)
            hideTimer.restart();
        else
            control.hideNow();
    }

    // 官方 show() 只看 animating 与 visible，两者都在就直接 return（:323-339）：
    // 已开着的层不会因为再点一次而重放动画。
    function showNow() {
        if (control.visible)
            return;
        control.open();
    }

    function hideNow() {
        showTimer.stop();
        hideTimer.stop();
        if (!control.visible)
            return;
        control.close();
    }

    Timer {
        id: showTimer

        interval: control.mouseEnterDelay
        onTriggered: control.showNow()
    }

    Timer {
        id: hideTimer

        interval: control.mouseLeaveDelay
        onTriggered: {
            if (!control.pointerOnTipArea())
                control.hideNow()
        }
    }

    // ---------------------------------------------------------------- 挂在 target 上的那几只
    HoverHandler {
        id: targetHover

        // 挂到 target 上之后就不在 Tooltip 的子树里了，enabled 得显式接过来 ——
        // 否则 Tooltip { enabled: false } 是空转的，悬停照样弹。
        // 档位也只由这一条决定：handler 里再判一次 `hoverMode` 是重复守卫，
        // 会让「enabled 漏了档位」那种改动打不红（本轮变异 M068 就是这么存活的）。
        enabled: control.enabled && control.hoverMode && control.target !== null
        parent: control.target
        onHoveredChanged: {
            if (targetHover.hovered) {
                // 官方 mouseEnter 第一件事就是清 isClickToHide（:233）
                control.clickToHideLatched = false;
                if (control.condition !== false)
                    control.delayShow();
            } else {
                control.delayHide();
            }
        }
    }

    TapHandler {
        id: targetClick

        enabled: control.enabled && control.target !== null
        parent: control.target
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (!control.clickMode)
                return;
            // 官方 click 档只有 show()，不是开关；关靠点外 handler。
            // clickTriggerToHide 那条走的是 document handler，不在这里关。
            if (control.condition !== false)
                control.showNow();
        }
    }

    TapHandler {
        id: targetMenu

        enabled: control.enabled && control.target !== null
        parent: control.target
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (!control.contextMenuMode)
                return;
            // 官方：condition === false 直接 return，否则 preventDefault + show()
            if (control.condition === false)
                return;
            control.showNow();
        }
    }

    // focus / blur：Item 没有 blur 事件，只有 activeFocusChanged 一前一后两个方向
    Connections {
        id: focusWatch

        target: control.listensToFocus && control.target !== null ? control.target : null

        function onActiveFocusChanged() {
            if (control.target && control.target.activeFocus) {
                if (control.condition !== false)
                    control.delayShow();
            } else {
                control.delayHide();
            }
        }
    }

    // ---------------------------------------------------------------- 卡片自身的那几只
    HoverHandler {
        id: tipHover

        // 官方 portalEventSet 是 triggerEventSet 的一份拷贝（:250）：
        // 鼠标从 target 挪进卡片，等于「还在悬停」，不该收。
        // 挂在 contentItem 上而不是 control 上：C.Popup 不是 Item（parent 只收 QQuickItem），
        // 而 padding 为 0 时 contentItem 正好铺满整张卡片。
        enabled: control.enabled && control.hoverMode
        parent: control.contentItem
        onHoveredChanged: {
            if (tipHover.hovered) {
                // clickToHide 档的闸门（:256-261）：刚在卡片上点过就别再弹
                if (control.clickToHide && control.clickToHideLatched)
                    return;
                if (control.condition !== false)
                    control.delayShow();
            } else {
                control.delayHide();
            }
        }
    }

    // 一次性：点了卡片就关掉，之后到 mouseEnter 之前不该再弹出来（:251-255）
    TapHandler {
        id: tipClick

        enabled: control.clickToHide
        parent: control.contentItem
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (!control.clickToHide)
                return;
            control.clickToHideLatched = true;
            control.hideNow();
        }
    }

    // ---------------------------------------------------------------- 点外面
    // 官方把 handler 绑在 document 的 mousedown 上、并排除掉 trigger 与卡片
    // （index.tsx:452-472）。这里用「每实例一个全窗壳 + PointHandler」，与
    // TagInput / TreeSelect 的 outsideShell 同一套路，两个原因都是本轮实测出来的：
    //   ① MouseArea 只要**挂在浮层宿主上**就会把整窗的点击截住 —— `enabled: false`
    //      与 `visible: false` 都一样，页面里的 MouseArea（TagInput 标签上那枚叉）
    //      一个事件都收不到，`childAt()` 在那个坐标返回的是 QQuickOverlay。
    //      passive handler 只观察、不吃事件，页面的项照常收到这一口。
    //   ② QQuickPointHandler 会给「同一个 parent、同一个 metaObject 类名」的后来者让路
    //      （qquickpointhandler.cpp:96-103），所以壳子必须每实例一个，不能都挂 contentItem。
    Item {
        id: outsideShell

        objectName: "tooltipOutsideShell"
        // 只在真要盯落点的那几档、并且层开着的时候才进场景。
        // 也不能自己写 C.Overlay.overlay：这一项的 QObject parent 是 Popup（不是 Item），
        // 完成时它还没有 window，那条 singleton 附加属性取到的是 null（实测 parent=null），
        // 于是整层失效。直接借浮层自己已经解析好的 parent，两者永远同一个宿主。
        parent: control.isOpen && control.watchesOutside ? control.parent : null
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0

        property Item host: parent

        PointHandler {
            id: outsideWatch

            // 按下即判（官方 mousedown 的时机）
            onActiveChanged: {
                if (!active || !control.isOpen)
                    return;
                const host = outsideShell.host;
                if (!host)
                    return;
                const pt = outsideWatch.point.position
                const p = outsideShell.mapToItem(host, pt.x, pt.y);
                const t = control.target;
                if (t) {
                    const o = t.mapToItem(host, 0, 0);
                    if (p.x >= o.x && p.x < o.x + t.width && p.y >= o.y && p.y < o.y + t.height) {
                        // 落在 trigger 上：官方也不算「外面」，除非 clickTriggerToHide
                        if (control.clickTriggerToHide) {
                            control.clickedOutside();
                            control.hideNow();
                        }
                        return;
                    }
                }
                // C.Popup 不是 Item，没有 mapToItem；place() 写下的 x/y 本来就是浮层坐标系
                if (p.x >= control.x && p.x < control.x + control.width
                        && p.y >= control.y && p.y < control.y + control.height)
                    return;
                control.clickedOutside();
                if (control.closesOnOutside)
                    control.hideNow();
            }
        }
    }

    // ---------------------------------------------------------------- Esc
    // 只在 closeOnEsc 为真时生效（:1254/:1286 那两处都是 closeOnEsc && ...）。
    // 非 custom 档关层，custom 档只发信号（:1321-1323 的 trigger !== 'custom'）。
    Shortcut {
        id: escShortcut

        sequences: [StandardKey.Cancel]
        enabled: control.closeOnEsc && control.isOpen
        onActivated: {
            control.escKeyDown();
            if (!control.customMode)
                control.hideNow();
        }
    }

    // ---------------------------------------------------------------- 其它
    onRePosKeyChanged: control.reposition()

    // 卡片定稿之后才能算三角中心：x/y 是 place() 命令式写的，而 mapToItem 在绑定里不反应
    // （基座为此专门轮询），所以这里也只能现算现写。方位那一档不挂信号 —— 翻面必然伴随
    // x 或 y 变化，onEffectivePlacementChanged 只是同一件事的第二个守卫，会让
    // 「漏挂其中一个」的改动互相顶包（变异 M056 就这么存活的）。
    // `Component.onCompleted` 那一次不是重复守卫：中间方位（Top / Bottom / Left / Right）
    // 要读 control.x 与 arrowPointAtCenter，而创建期那阵几何信号来得**早于**这两个绑定定稿，
    // 那一拍算出来是 NaN、之后再没有信号 —— 实测摘掉种子后 `position: Enums.Top` +
    // `arrowPointAtCenter: true` 的卡片直到开层前 `arrowCenterX` 都还是 NaN（角落方位看不出
    // 来，它那值是常量 18）。种子补的就是这一拍，place() 首帧才用得上中心值。
    onXChanged: control.updateArrowCenter()
    onYChanged: control.updateArrowCenter()
    onWidthChanged: control.updateArrowCenter()
    onHeightChanged: control.updateArrowCenter()

    Component.onCompleted: control.updateArrowCenter()
}
