pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as C
import QtQuick.Shapes
import Semi

// 用户引导。照 semi-ui/userGuide（index.tsx:23-59 的 UserGuideProps 与 StepItem、
// :84-101 的 defaultProps、:243-308 气泡卡片内容、:451-522 弹窗内容、:524-544 的 render）
// 与 semi-foundation/userGuide（foundation.ts:28-85 那四个 handler、constants.ts:8-33 的
// MODE / THEME / DEFAULT_*、userGuide.scss + variables.scss 的度量）。
//
//     UserGuide {
//         id: guide
//         visible: page.guideOpen          // 显示与否整个归调用方
//         steps: [
//             { title: "搜索", description: "在这里找东西", target: searchBox },
//             { title: "新建", description: "点这里创建", target: createButton }
//         ]
//         onFinish: page.guideOpen = false
//         onSkip: page.guideOpen = false
//     }
//
// 三条主干行为（官方就是这么写的，别往回改）：
//   · 组件从不自己关：handleSkip 只 notifySkip，最后一步的 handleNext 只 notifyFinish
//     （foundation.ts:57-85）；关不关由调用方在 onFinish / onSkip 里改 visible；
//   · 传了 current 就是受控（foundation.ts:35-37 的 `'current' in props`）：上一步 / 下一步
//     只通知、不自改，调用方在 onChange 里自己推进；非受控才动内部状态；
//   · 打开那一拍官方 setState({current: 0})（index.tsx:177-184），非受控那支跟着归零；
//     受控那支随后被 getDerivedStateFromProps（:159-165）按 props.current 顶回去。
//   · onChange 只在真的换步时发（foundation.ts:28-33 拿 state 比对），最后一步不发。
//   · popup 模式里没有 target 的那一步**整步不渲染**（renderStep :319 与 renderSpotlight :361
//     都先判 step.target）—— 卡片和遮罩一起没有，官方就是这个行为。
//
// 度量（userGuide.scss + variables.scss，逐条）：
//   气泡卡片就是一支 Popover：宽 400（$width-userGuide_popover-default，外面还套了
//     max-width: fit-content ⇒ 内容窄时整张卡跟着收，见 popupCardWidth）、圆角 radius-medium
//     （$radius-popover）、内边距 0（index.tsx:322 的 basePopoverStyle）、cover 高 200
//     （$height-userGuide_popup_content_cover-default）、body 内边距 24、标题 18px/600/行高 24/
//     下边距 8、描述 14px/行高 20/下边距 48、footer 两段 space-between、按钮组 gap 12 +
//     margin-left 120；指示器是「2/3」这样的**文字**（$font-*_indicator-lineHeight 20），
//     只有步数 > 1 才出现；
//   弹窗卡片：壳是 Modal（圆角 radius-large、阴影 elevated、蒙层 overlay-bg、文字 text-0）；
//     **换步整个重播「关闭再打开」**：上游 LocaleConsumer 函数子节点那轮 render 重建 Modal
//     子树 ⇒ exit 120ms + enter 120ms（浏览器实测换步后内容直接回到 enter 起点 0/0.7 再放大），
//     端口把卡片按住一个 exit 时长再放开（onIndexChanged + modalReplayTimer，见坑 138）；
//     被 userGuide.scss 改成宽 600、内边距 0；cover 高 300、指示器整条高 30 居中、
//     圆点 6×6 间距 8（$radius-userGuide_modal_content_indicator 是 radius-large，
//     6px 的盒子上 CSS 自己夹成圆，Qt 的 Rectangle 同样夹）、body 内边距 24 48 竖排居中、
//     footer 内边距 24、按钮间距 12；**指示器只在有 cover 时才渲染**（index.tsx:473-482）；
//   高亮：挖空矩形 = 目标矩形外扩 padding；padding 依序取 step.spotlightPadding →
//     spotlightPadding → 5（numbers.DEFAULT_SPOTLIGHT_PADDING）；洞的圆角官方写死 4（svg rx={4}）；
//   动效：$transition_duration-userGuide_spotLight = 200ms + cubic-bezier(.4,0,.2,1)。
//     官方只有 SVG 里那块洞带 transition，锚点 div 与四块透明拦截块是立刻到位的 ——
//     所以卡片跟着目标跳、洞慢慢挪，这里同一份分工。
//     不能用 Theme.current.duration* —— 默认主题把全局时长令牌设成 0ms。
//
// 与官方的差异（React / CSS 在 QML 侧无处落地，逐条）：
//   · `position` 收 Enums.Placement（与 PopupBase.placement、DatePicker.position 同一口径，
//     官方 strings.POSITION_SET 前 12 个值一一对应；leftTopOver / rightTopOver 那两档本库没有）；
//     `mode` / `theme` 保留官方字符串；
//   · `nextButtonProps` / `prevButtonProps` 摊平成 *Text / *Variant / *Tone 六个显式属性
//     （官方 demo 真正吃到的就是 children 与 theme），其余按钮参数走
//     `readonly property Item skipButton / prevButton / nextButton`；
//   · `spotlightPadding: 0` 官方渲染成 5：index.tsx:228 与 :325 用 `||` 取值，0 被当成「没给」。
//     foundation.ts:47-55 的 getFinalPaading 才是 typeof 判定（0 生效），但它在整个包里
//     一个调用点都没有。这里按 getFinalPaading 的意图实现，官方那处 `||` 只记录不抄；
//   · `StepItem.mask` 文档写了「会覆盖全局配置」，实现里 renderSpotlight / renderModal 只读
//     `this.props.mask`（index.tsx:357、:452），单步蒙层压根没接。这里同样不接，也不开放这个字段；
//   · 挖洞：官方是一整片 overlay-bg 加 SVG mask（`rect rx={4}`），QML 侧没有减法遮罩，
//     用 OddEvenFill 的 Shape 环带等价（外路径铺满 + 内路径圆角矩形 r=4）⇒ 洞里透明、
//     四角带官方那圈 rx=4 的小月牙遮罩色；高亮区也没有描边 ——
//     官方全靠遮罩反差，原实现那圈 2px primary 描边是本地加的，已去掉；
//   · 拦截：高亮区外围那四块官方是 `pointer-events: auto` 的透明 rect（点出去被吃掉、洞里的目标
//     仍可点），`mask={false}` 时这一整组 rect 连同拦截一起不渲染。这里同构：mask 假 ⇒
//     视觉块与 MouseArea 全不建，页面照旧可点；
//   · `getPopupContainer` 换成 `container`（与 Toast / Notification 同一口径：给了就用，
//     不给挂窗口 Overlay）；`zIndex` 落在遮罩层，卡片在它上面一层（官方 popover 的层归
//     $z-popover 与 portal 顺序，效果就是压在遮罩上）；
//   · `style` / `className` 不落 QML；`cover` 是 ReactNode，这里收 Component；
//     `title` / `description` 只收字符串；
//   · modal 那一支不复用 src/Modal.qml：它的面板写死 448 宽、内容四周 24 内边距，
//     而 userGuide.scss 恰好把这两样都改了（600 宽、padding 0、cover 顶到边）。
//     同 src/Feedback.qml 的做法，自绘一张按 userGuide-modal 度量排的卡；
//   · 遮罩自身的淡入淡出（$animation_duration-modal_mask-* = 90ms）没有：整层由 visible
//     直接开关，关的那一拍 Qt 立刻移除，不留动画窗口。两支卡片各有各的进出场。
//   · 官方的高亮矩形只在 render 时算一次（getBoundingClientRect），页面滚动时洞不跟目标；
//     这里每帧刷一次，洞与卡片都跟着目标走 —— mapToItem 在 QML 侧不是响应式的，
//     不刷的话位置器排完版之后洞会停在第一次求值的位置上。
Item {
    id: control

    // ---------------------------------------------------------------- UserGuideProps
    property var current: undefined                   // 受控的当前步；undefined = 非受控
    property string finishText: qsTr("完成")           // locale.UserGuide.finish
    property bool mask: true
    property string mode: "popup"                     // popup | modal（strings.MODE）
    property int position: Enums.Bottom               // 官方 'bottom'
    property var spotlightPadding: undefined           // 留 undefined 才让 5 兜底
    property bool showPrevButton: true
    property bool showSkipButton: true
    property var steps: []
    property string theme: "default"                  // default | primary（strings.THEME）
    property int zIndex: 1030                         // numbers.DEFAULT_Z_INDEX
    property var container: null                      // 官方 getPopupContainer

    // 官方 nextButtonProps / prevButtonProps 里 demo 真正用到的三项
    property string nextButtonText: ""
    property var nextButtonVariant: undefined
    property var nextButtonTone: undefined
    property string prevButtonText: ""
    property var prevButtonVariant: undefined
    property var prevButtonTone: undefined

    signal changed(int current)                       // 官方 onChange
    signal next(int current)
    signal prev(int current)
    signal finished()
    signal skipped()

    // 三颗键的本体：摊平属性覆盖不到的参数直接在它身上设
    readonly property Item skipButton: control.popupMode ? popupSkip : modalSkip
    readonly property Item prevButton: control.popupMode ? popupPrev : modalPrev
    readonly property Item nextButton: control.popupMode ? popupNext : modalNext
    // 两支卡片与遮罩层。这三样在声明上都是 control 的子项，但自己会搬到窗口 Overlay 上，
    // 从外部按 children 是翻不到的，所以留三个口子（同 src/Feedback.qml 的 textArea / radioGroup）。
    readonly property alias popupCard: popupCard
    readonly property alias modalCard: modalCard
    readonly property alias overlayLayer: host

    // ---------------------------------------------------------------- 令牌
    readonly property real popoverWidthMax: 400        // $width-userGuide_popover-default
    readonly property real bodyPadding: 24             // $spacing-userGuide_popup_content_body-padding
    readonly property real titleGap: 8                 // …popup_content_title-marginBottom
    readonly property real descriptionGap: 48          // …popup_content_description-marginBottom
    readonly property real buttonGap: 12               // …popup_content_button-gap
    readonly property real buttonsMarginLeft: 120     // …popup_content_button-marginLeft
    readonly property real popupCoverHeight: 200       // $height-userGuide_popup_content_cover-default
    readonly property real titleLineHeight: 24         // $font-userGuide_popup_content_title-lineHeight
    readonly property real descriptionLineHeight: 20   // …description-lineHeight
    readonly property real indicatorLineHeight: 20     // …indicator-lineHeight
    readonly property real modalCardWidth: 600         // $width-userGuide_modal_content_cover-default
    readonly property real modalCoverHeight: 300       // $height-userGuide_modal_content_cover-default
    readonly property real modalIndicatorHeight: 30    // $height-userGuide_modal_content_indicator-default
    readonly property real modalDotSize: 6             // …indicator_item-default
    readonly property real modalDotGap: 8              // $spacing-userGuide_popup_content_indicator-gap
    readonly property real modalBodyPaddingY: 24       // $spacing-userGuide_modal_content_body-padding
    readonly property real modalBodyPaddingX: 48
    readonly property real modalFooterPadding: 24      // $spacing-userGuide_modal_content_footer-padding
    readonly property real popoverGap: 10              // 同 src/Popover.qml
    readonly property real arrowSize: 8                // $height-popover_arrow
    /// 官方 $transition_duration-userGuide_spotLight = 200ms。可写是给测试拉长采样用的
    /// （同 carousel `speed` 的口径；官方值恒 200，使用方改它不背离任何官方语义）。
    property int motionDuration: 200
    /// 官方 $transition_function-userGuide_spotLight = cubic-bezier(0.4, 0, 0.2, 1)。
    /// Qt 的 bezierCurve 每段要六个值（四值被静默丢弃退化线性，坑 134）⇒ 补隐含终点 (1,1)；
    /// 合法赋值会把整条曲线连 type 换成 BezierSpline ⇒ `easing.type` 不写（写了也是死行）。
    readonly property var motionCurve: [0.4, 0, 0.2, 1, 1, 1]

    // ---------------------------------------------------------------- 状态与派生
    readonly property bool controlled: control.current !== undefined && control.current !== null
    property int __inner: 0                            // 官方 state.current（非受控那一支）
    readonly property int stepCount: control.steps !== undefined && control.steps !== null
        && control.steps.length !== undefined ? control.steps.length : 0
    readonly property int index: control.controlled ? Number(control.current) : control.__inner
    readonly property var step: control.index >= 0 && control.index < control.stepCount
        ? control.steps[control.index] : null
    readonly property bool isFirstStep: control.index === 0
    // index.tsx:248 的 `index === steps.length - 1`：按等号判，越界不算最后一步
    readonly property bool isLastStep: control.index === control.stepCount - 1
    readonly property bool popupMode: control.mode === "popup"
    readonly property bool modalMode: control.mode === "modal"
    // index.tsx:527 的 `if (!visible || !steps.length) return null`
    readonly property bool shown: control.visible && control.stepCount > 0 && control.step !== null

    readonly property Item targetItem: control.step !== null && control.step.target !== undefined
        && control.step.target !== null ? control.step.target : null
    readonly property bool targetTaken: control.targetItem !== null
    // modal 那一支完全不读 theme（renderModal 里没有 isPrimaryTheme），所以收在 popupMode 里
    readonly property bool primaryLook: control.popupMode
        && (control.theme === "primary"
            || (control.step !== null && control.step.theme === "primary"))
    readonly property int stepPosition: control.step !== null && control.step.position !== undefined
        ? control.step.position : control.position
    readonly property bool arrowShown: control.step === null || control.step.showArrow === undefined
        || control.step.showArrow !== false
    readonly property real finalPadding: {
        const stepPadding = control.step !== null ? control.step.spotlightPadding : undefined;
        if (typeof stepPadding === "number")
            return stepPadding;
        if (typeof control.spotlightPadding === "number")
            return control.spotlightPadding;
        return 5;                                      // numbers.DEFAULT_SPOTLIGHT_PADDING
    }
    readonly property string stepTitle: control.step !== null && control.step.title !== undefined
        && control.step.title !== null ? String(control.step.title) : ""
    readonly property string stepDescription: control.step !== null
        && control.step.description !== undefined && control.step.description !== null
        ? String(control.step.description) : ""
    readonly property bool titleTaken: control.stepTitle !== ""
    readonly property bool descriptionTaken: control.stepDescription !== ""
    readonly property var coverComponent: control.step !== null && control.step.cover !== undefined
        && control.step.cover !== null ? control.step.cover : null
    readonly property bool coverTaken: control.coverComponent !== null
    // popup：步数 > 1 才有「2/3」；modal：只有 cover 才有圆点排
    readonly property bool indicatorTaken: control.stepCount > 1
    readonly property bool modalIndicatorTaken: control.coverTaken
    readonly property bool bodyTaken: control.titleTaken || control.descriptionTaken
    // renderSpotlight 也先判 step.target（index.tsx:361）：没有 target 就连遮罩带卡片整片不画
    readonly property bool spotlightTaken: control.popupMode && control.targetTaken

    readonly property color maskColor: Theme.current.colorOverlayBg   // 遮罩 fill
    readonly property color popupTextColor: control.primaryLook
        ? Theme.current.colorTertiaryLightDefault : Theme.current.colorText0
    readonly property string indicatorText: (control.index + 1) + "/" + control.stepCount

    readonly property int resolvedSkipTone: control.primaryLook ? Enums.Primary : Enums.Tertiary
    readonly property int resolvedSkipVariant: control.primaryLook ? Enums.Solid : Enums.Light
    readonly property int resolvedNextTone: Enums.Primary
    readonly property int resolvedNextVariant: control.primaryLook
        ? Enums.Borderless : Enums.Solid

    readonly property string skipLabel: qsTr("跳过")            // locale.UserGuide.skip
    readonly property string prevLabel: control.prevButtonText !== ""
        ? control.prevButtonText : qsTr("上一步")               // …prevButtonProps.children
    readonly property string nextLabel: control.isLastStep
        ? (control.finishText !== "" ? control.finishText : qsTr("完成"))
        : (control.nextButtonText !== "" ? control.nextButtonText : qsTr("下一步"))

    // 卡片宽度：400 与内容自然宽取小（index.tsx 那层 max-width: fit-content）。
    // footer 是 flex 不换行，max-content = 指示器 + 120 + 按钮组；有 cover 时按 400 铺满。
    readonly property real titleNaturalWidth: titleMetrics.advanceWidth
    readonly property real descriptionNaturalWidth: descriptionMetrics.advanceWidth
    readonly property real indicatorNaturalWidth: indicatorMetrics.advanceWidth
    readonly property real footerNaturalWidth: (control.indicatorTaken ? control.indicatorNaturalWidth : 0)
        + control.buttonsMarginLeft + popupButtons.implicitWidth
    readonly property real popupCardWidth: control.coverTaken ? control.popoverWidthMax
        : Math.min(control.popoverWidthMax, Math.max(control.titleNaturalWidth,
            control.descriptionNaturalWidth, control.footerNaturalWidth) + control.bodyPadding * 2)

    // 目标在遮罩层坐标系里的矩形，外扩 finalPadding。没有 target 时整步不渲染，给 0 就够。
    //
    // mapToItem 不是响应式的：目标被位置器搬走（Column / Row 排完版、页面滚动）之后，
    // 绑在表达式里的 rect 会一直停在第一次求值的值上 —— 洞会落在别处。所以拆成四个数存着，
    // 由下面的 FrameAnimation 每帧刷一次，与 PopupBase 盯锚点同一口径。
    // （官方只在 render 时算一次 rect，滚动时洞并不跟目标；这里跟着，是有意偏离。）
    property real __spotX: 0
    property real __spotY: 0
    property real __spotW: 0
    property real __spotH: 0
    readonly property rect spotlight: Qt.rect(control.__spotX, control.__spotY,
        control.__spotW, control.__spotH)

    function refreshSpotlight() {
        if (!control.targetTaken) {
            control.__spotX = 0;
            control.__spotY = 0;
            control.__spotW = 0;
            control.__spotH = 0;
            return;
        }
        const p = control.targetItem.mapToItem(host, 0, 0);
        const pad = control.finalPadding;
        const x = p.x - pad;
        const y = p.y - pad;
        const w = control.targetItem.width + pad * 2;
        const h = control.targetItem.height + pad * 2;
        // 值没变就不写：写了会把 hole 的 Behavior 重新起一遍，洞永远停在动画起点
        if (x !== control.__spotX || y !== control.__spotY
            || w !== control.__spotW || h !== control.__spotH) {
            control.__spotX = x;
            control.__spotY = y;
            control.__spotW = w;
            control.__spotH = h;
        }
    }

    // 打开那一拍先把洞摆到位，别让动画从 (0,0) 长出来 —— 官方首次 render 也没有前值。
    // 只能等下一帧再放开动画：同一个通知周期里 index 已经变了，但 step / targetItem
    // 这些下游只读绑定还没重算，此刻刷新的还是上一个目标的矩形。
    function snapSpotlight() {
        hole.animate = false;
        control.refreshSpotlight();
        settleTimer.restart();
    }

    width: 0
    height: 0
    // 官方 defaultProps 的 visible: false。关掉只是不渲染，没有任何「自己关自己」的路径。
    visible: false

    // ---------------------------------------------------------------- modal 换步重播
    // 官方 modal 模式点下一步时**整个 dialog 重播「关闭再打开」**（浏览器实测：换步后内容
    // 直接回到 enter 起点 opacity 0 / scale 0.7 再放大，标题已是新步骤；上游是
    // LocaleConsumer 函数子节点那一轮 render 重建 Modal 子树的副作用，index.tsx:455-461）。
    // 端口等价：current 变化时把卡片按住一个 exit 时长（120ms，与 enter/exit 过渡同值）
    // 再放开 —— C.Popup 的 visible 翻假走 exit 过渡、翻真走 enter 过渡，与官方同观感。
    property bool __modalReplayOff: false
    property bool __justOpened: false

    // 挂 index 不挂 current：非受控档换步走 __inner，current（受控 prop）根本不变化
    onIndexChanged: {
        // 开层那一拍 visible 刚翻真、卡片 enter 还在起跑 —— 那不是换步，官方那里也只有一层 enter
        if (control.__justOpened || !control.modalMode || !control.shown
                || !control.modalCard.visible)
            return;
        control.__modalReplayOff = true;
        modalReplayTimer.restart();
    }

    Timer {
        id: modalReplayTimer

        objectName: "userGuideModalReplayTimer"
        interval: 120                        // exit 过渡时长（与 modalCard.exit 同步）
        onTriggered: control.__modalReplayOff = false
    }

    Timer {
        id: settleTimer

        objectName: "userGuideSettleTimer"
        interval: 32
        onTriggered: {
            control.refreshSpotlight();
            hole.animate = true;
        }
    }

    Component.onCompleted: control.snapSpotlight()

    FrameAnimation {
        running: control.spotlightTaken
        onTriggered: control.refreshSpotlight()
    }

    // index.tsx:177-184：visible 转真时 setState({current: 0})
    onVisibleChanged: {
        if (control.visible) {
            control.__justOpened = true;
            control.__inner = 0;
            control.snapSpotlight();
            Qt.callLater(function () { control.__justOpened = false; });
        }
    }

    // 官方只在 state 与目标值不同时发 onChange（foundation.ts:28-33）
    function pushChange(nextIndex) {
        if (nextIndex !== control.index)
            control.changed(nextIndex);
    }

    // foundation.ts:57-65：最后一步的下一步 = 只 notifyFinish，不关也不动 current
    function handleNext() {
        if (control.isLastStep) {
            control.finished();
            return;
        }
        const nextIndex = control.index + 1;
        control.pushChange(nextIndex);
        control.next(nextIndex);
        if (!control.controlled)
            control.__inner = nextIndex;
    }

    function handlePrev() {
        // 官方按 isFirst 把上一步键整个藏掉，从这里进不来；留着等价的那道门
        if (control.index <= 0)
            return;
        const nextIndex = control.index - 1;
        control.pushChange(nextIndex);
        control.prev(nextIndex);
        if (!control.controlled)
            control.__inner = nextIndex;
    }

    function handleSkip() {
        control.skipped();
    }

    TextMetrics {
        id: titleMetrics

        font.pixelSize: Theme.current.fontSizeHeader5
        font.weight: Font.DemiBold
        text: control.stepTitle
    }

    TextMetrics {
        id: descriptionMetrics

        font.pixelSize: Theme.current.fontSizeRegular
        text: control.stepDescription
    }

    TextMetrics {
        id: indicatorMetrics

        font.pixelSize: Theme.current.fontSizeRegular
        text: control.indicatorText
    }

    // ---------------------------------------------------------------- 遮罩层
    Item {
        id: host

        objectName: "userGuideHost"
        // Item 在 QML 侧没有 window 属性，parent 直接绑 Overlay 会在还没进场景时求值成
        // null 且永不自愈（坑 83）—— 与 Toast / Notification 同一写法。
        parent: control.container !== null && control.container !== undefined
            ? control.container : (Window.window ? C.Overlay.overlay : control)
        z: control.zIndex
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        visible: control.shown

        // 洞的当前位置：向 control.spotlight 靠拢。官方只有 SVG 那块带 transition，
        // 所以视觉遮罩跟着它走，拦截块与卡片锚点用立刻到位的那一份。
        // 测试读 control.spotlight 验证几何，不关心动画中间态。
        Item {
            id: hole

            objectName: "userGuideHole"
            property bool animate: true

            x: control.spotlight.x
            y: control.spotlight.y
            width: control.spotlight.width
            height: control.spotlight.height

            Behavior on x {
                enabled: hole.animate

                NumberAnimation {
                    duration: control.motionDuration
                    easing.bezierCurve: control.motionCurve
                }
            }
            Behavior on y {
                enabled: hole.animate

                NumberAnimation {
                    duration: control.motionDuration
                    easing.bezierCurve: control.motionCurve
                }
            }
            Behavior on width {
                enabled: hole.animate

                NumberAnimation {
                    duration: control.motionDuration
                    easing.bezierCurve: control.motionCurve
                }
            }
            Behavior on height {
                enabled: hole.animate

                NumberAnimation {
                    duration: control.motionDuration
                    easing.bezierCurve: control.motionCurve
                }
            }
        }

        // 卡片锚点 = 官方那个 position: fixed 的透明 div，尺寸就是高亮矩形、不动画
        Item {
            id: spot

            objectName: "userGuideSpot"
            x: control.spotlight.x
            y: control.spotlight.y
            width: control.spotlight.width
            height: control.spotlight.height
        }

        // 一整片遮罩挖圆角洞（官方是 overlay-bg + SVG mask 的 `rect rx={4}`，index.tsx:382）。
        // QML 没有减法遮罩，用 OddEvenFill 的环带等价：外路径铺满、内路径是圆角矩形 ⇒
        // 洞里透明、四角带 rx=4 的小月牙遮罩色。`mask` 假 ⇒ 整块不渲染（官方那五个 rect
        // 全在 `mask && (…)` 里）。
        Shape {
            id: userGuideMask

            objectName: "userGuideMask"

            anchors.fill: parent
            visible: control.mask && control.spotlightTaken
            // 坑 123/127：Shape 默认渲染器不做 AA，圆角小弧会出锯齿，点名 CurveRenderer
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                objectName: "userGuideMaskPath"

                fillColor: control.maskColor
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill

                PathRectangle {
                    x: 0
                    y: 0
                    width: userGuideMask.width
                    height: userGuideMask.height
                }

                // 官方 svg rx={4} 写死；洞比 8px 还小时夹到半边，避免半径大于盒子
                PathRectangle {
                    x: hole.x
                    y: hole.y
                    width: hole.width
                    height: hole.height
                    radius: Math.min(4, hole.width / 2, hole.height / 2)
                }
            }
        }

        // 拦截层：位置与视觉遮罩同一套算法，但吃的是不动画的那份矩形
        MouseArea {
            objectName: "userGuideBlockTop"
            x: 0
            y: 0
            width: host.width
            height: Math.max(0, spot.y)
            enabled: control.mask && control.spotlightTaken
            acceptedButtons: Qt.AllButtons
        }

        MouseArea {
            objectName: "userGuideBlockBottom"
            x: 0
            y: spot.y + spot.height
            width: host.width
            height: Math.max(0, host.height - spot.y - spot.height)
            enabled: control.mask && control.spotlightTaken
            acceptedButtons: Qt.AllButtons
        }

        MouseArea {
            objectName: "userGuideBlockLeft"
            x: 0
            y: spot.y
            width: Math.max(0, spot.x)
            height: spot.height
            enabled: control.mask && control.spotlightTaken
            acceptedButtons: Qt.AllButtons
        }

        MouseArea {
            objectName: "userGuideBlockRight"
            x: spot.x + spot.width
            y: spot.y
            width: Math.max(0, host.width - spot.x - spot.width)
            height: spot.height
            enabled: control.mask && control.spotlightTaken
            acceptedButtons: Qt.AllButtons
        }

        // modal 那一支的蒙层：一整片，不挖洞（官方把 mask 直接透给 Modal）
        Rectangle {
            objectName: "userGuideModalMask"
            visible: control.mask && control.modalMode
            anchors.fill: parent
            color: control.maskColor
        }
    }

    // ---------------------------------------------------------------- 气泡卡片
    PopupBase {
        id: popupCard

        objectName: "userGuidePopupCard"
        anchor: spot
        placement: control.stepPosition
        gap: control.popoverGap
        arrowSize: control.arrowSize
        showArrow: control.arrowShown
        padding: 0                          // index.tsx:322 的 basePopoverStyle = { padding: 0 }
        contentSpacing: 0
        radius: Theme.current.radiusMedium   // $radius-popover
        // primary 主题只是往 Popover 上盖了一层 backgroundColor，描边照旧
        fillColor: control.primaryLook ? Theme.current.colorPrimary : Theme.current.colorBg3
        strokeColor: Theme.current.colorBorder
        modal: false                        // 拦截交给遮罩层，洞里要还能点
        dim: false
        closePolicy: C.Popup.NoAutoClose     // 官方既不 Esc 也不点外关闭
        visible: control.shown && control.popupMode && control.targetTaken
        width: control.popupCardWidth
        z: control.zIndex + 1

        Column {
            id: popupStack

            objectName: "userGuidePopupStack"
            width: popupCard.width
            spacing: 0

            Loader {
                id: popupCover

                objectName: "userGuidePopupCover"
                active: control.coverTaken
                // 显式 height 会把没启用的 Loader 也撑成 200，得连 visible 一起关：
                // 位置器只跳过 visible:false 的子项
                visible: control.coverTaken
                sourceComponent: control.coverComponent
                width: popupStack.width
                height: control.popupCoverHeight
            }

            Column {
                id: popupBody

                objectName: "userGuidePopupBody"
                // 官方那个 -body 的 div 是无条件渲染的，只有 title / description 各自判空
                width: popupStack.width
                leftPadding: control.bodyPadding
                rightPadding: control.bodyPadding
                topPadding: control.bodyPadding
                bottomPadding: control.bodyPadding
                spacing: 0

                Text {
                    id: popupTitle

                    objectName: "userGuidePopupTitle"
                    visible: control.titleTaken
                    width: popupBody.width - popupBody.leftPadding - popupBody.rightPadding
                    text: control.stepTitle
                    color: control.popupTextColor   // $color-userGuide_popup-text-*
                    font.pixelSize: Theme.current.fontSizeHeader5
                    font.weight: Font.DemiBold      // $font-weight-bold = 600
                    lineHeight: control.titleLineHeight
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }

                Text {
                    id: popupDescription

                    objectName: "userGuidePopupDescription"
                    visible: control.descriptionTaken
                    width: popupBody.width - popupBody.leftPadding - popupBody.rightPadding
                    topPadding: control.titleTaken ? control.titleGap : 0
                    text: control.stepDescription
                    color: control.popupTextColor
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: control.descriptionLineHeight
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }

                // footer：display:flex + justify-content:space-between。
                // 顶部留白并进 height，Column 才认这一段间距。
                Item {
                    id: popupFooter

                    objectName: "userGuidePopupFooter"
                    width: popupBody.width - popupBody.leftPadding - popupBody.rightPadding
                    readonly property real topGap: control.descriptionTaken ? control.descriptionGap
                        : (control.titleTaken ? control.titleGap : 0)
                    height: popupFooter.topGap
                        + Math.max(control.indicatorTaken ? control.indicatorLineHeight : 0,
                            popupButtons.implicitHeight)

                    Text {
                        id: popupIndicator

                        objectName: "userGuidePopupIndicator"
                        visible: control.indicatorTaken
                        y: popupFooter.topGap
                        text: control.indicatorText
                        color: control.popupTextColor
                        font.pixelSize: Theme.current.fontSizeRegular
                        lineHeight: control.indicatorLineHeight
                        lineHeightMode: Text.FixedHeight
                    }

                    Row {
                        id: popupButtons

                        objectName: "userGuidePopupButtons"
                        // 剩余空间够就顶到右边缘，不够就从指示器右边 120 处排下去；
                        // 没有指示器时 space-between 的单元素就是贴左 + margin-left 120
                        x: control.indicatorTaken
                            ? Math.max(popupIndicator.width + control.buttonsMarginLeft,
                                popupFooter.width - popupButtons.implicitWidth)
                            : control.buttonsMarginLeft
                        y: popupFooter.topGap
                        spacing: control.buttonGap

                        Button {
                            id: popupSkip

                            objectName: "userGuidePopupSkip"
                            // index.tsx:271 的 showSkipButton && !isLast
                            visible: control.showSkipButton && !control.isLastStep
                            text: control.skipLabel
                            tone: control.resolvedSkipTone
                            variant: control.resolvedSkipVariant
                            // primary 主题那两支靠 inline style 把底压成 fill-2；
                            // 默认主题照抄 Button 自己那套 Appearance::buttonBackground
                            color: control.primaryLook
                                ? Theme.current.colorFill2
                                : Appearance.buttonBackground(Theme.current,
                                    popupSkip.resolvedTone, popupSkip.resolvedVariant,
                                    popupSkip.controlState)
                            onClicked: control.handleSkip()
                        }

                        Button {
                            id: popupPrev

                            objectName: "userGuidePopupPrev"
                            // index.tsx:281 的 showPrevButton && !isFirst
                            visible: control.showPrevButton && !control.isFirstStep
                            text: control.prevLabel
                            tone: control.prevButtonTone !== undefined
                                ? control.prevButtonTone : control.resolvedSkipTone
                            variant: control.prevButtonVariant !== undefined
                                ? control.prevButtonVariant : control.resolvedSkipVariant
                            color: control.primaryLook
                                ? Theme.current.colorFill2
                                : Appearance.buttonBackground(Theme.current,
                                    popupPrev.resolvedTone, popupPrev.resolvedVariant,
                                    popupPrev.controlState)
                            onClicked: control.handlePrev()
                        }

                        Button {
                            id: popupNext

                            objectName: "userGuidePopupNext"
                            text: control.nextLabel
                            tone: control.nextButtonTone !== undefined
                                ? control.nextButtonTone : control.resolvedNextTone
                            variant: control.nextButtonVariant !== undefined
                                ? control.nextButtonVariant : control.resolvedNextVariant
                            // primary 主题那支是 style backgroundColor: '#FFF'（index.tsx:293）。
                            // 是字面量白，不是 Theme.colorWhite —— 后者暗色下是 #e4e7f5。
                            color: control.primaryLook
                                ? "#ffffff"
                                : Appearance.buttonBackground(Theme.current,
                                    popupNext.resolvedTone, popupNext.resolvedVariant,
                                    popupNext.controlState)
                            onClicked: control.handleNext()
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- 弹窗卡片
    PopupBase {
        id: modalCard

        objectName: "userGuideModalCard"
        anchor: null
        padding: 0                          // bodyStyle={{ padding: 0 }} + modal-content padding 0
        contentSpacing: 0
        radius: Theme.current.radiusLarge   // Modal 面板圆角
        fillColor: Theme.current.colorBg2   // $color-modal-bg
        strokeColor: Theme.current.colorBorder
        showArrow: false
        // .semi-modal-wrap 整层拦点击，跟 mask 开不开无关 ⇒ modal 恒真
        modal: true
        dim: false
        focus: true
        closePolicy: C.Popup.NoAutoClose    // maskClosable={false}；Esc 只走到没人听的 onCancel
        visible: control.shown && control.modalMode && !control.__modalReplayOff
        width: control.modalCardWidth
        x: parent ? Math.max(0, (parent.width - width) / 2) : 0
        y: parent ? Math.max(0, (parent.height - height) / 2) : 0
        z: control.zIndex + 1
        transformOrigin: Item.Center

        // 官方这一支的外壳是 Modal，进出场 $animation_duration-modal-show/hide = 120ms
        // + scale 0.7→1，不是 PopupBase 默认的 popover zoom
        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 120
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.7
                    to: 1
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        exit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 120
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 1
                    to: 0.7
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        Column {
            id: modalStack

            objectName: "userGuideModalStack"
            width: modalCard.width
            spacing: 0

            Loader {
                id: modalCover

                objectName: "userGuideModalCover"
                active: control.coverTaken
                visible: control.coverTaken
                sourceComponent: control.coverComponent
                width: modalStack.width
                height: control.modalCoverHeight
            }

            // 圆点排：官方只在有 cover 时渲染（index.tsx:473-482）
            Item {
                id: modalIndicator

                objectName: "userGuideModalIndicator"
                visible: control.modalIndicatorTaken
                width: modalStack.width
                height: control.modalIndicatorHeight

                Row {
                    objectName: "userGuideModalDots"
                    anchors.centerIn: parent
                    spacing: control.modalDotGap

                    Repeater {
                        model: control.stepCount

                        delegate: Rectangle {
                            required property int modelData

                            // 整数 model 的 modelData 就是这一项的下标，省掉 index 那一档命名
                            objectName: "userGuideModalDot" + modelData
                            width: control.modalDotSize
                            height: control.modalDotSize
                            radius: Theme.current.radiusLarge
                            color: modelData === control.index
                                ? Theme.current.colorPrimary
                                : Theme.current.colorPrimaryLightActive
                        }
                    }
                }
            }

            Column {
                id: modalBody

                objectName: "userGuideModalBody"
                visible: control.bodyTaken
                width: modalStack.width
                leftPadding: control.modalBodyPaddingX
                rightPadding: control.modalBodyPaddingX
                topPadding: control.modalBodyPaddingY
                bottomPadding: control.modalBodyPaddingY
                spacing: 0

                Text {
                    id: modalTitle

                    objectName: "userGuideModalTitle"
                    visible: control.titleTaken
                    width: modalBody.width - modalBody.leftPadding - modalBody.rightPadding
                    horizontalAlignment: Text.AlignHCenter   // body 是 align-items: center
                    text: control.stepTitle
                    color: Theme.current.colorText0           // .semi-modal { color: text-0 }
                    font.pixelSize: Theme.current.fontSizeHeader5
                    font.weight: Font.DemiBold
                    lineHeight: control.titleLineHeight
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }

                Text {
                    id: modalDescription

                    objectName: "userGuideModalDescription"
                    visible: control.descriptionTaken
                    width: modalBody.width - modalBody.leftPadding - modalBody.rightPadding
                    topPadding: control.titleTaken ? control.titleGap : 0
                    horizontalAlignment: Text.AlignHCenter
                    text: control.stepDescription
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: control.descriptionLineHeight
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }
            }

            Item {
                id: modalFooter

                objectName: "userGuideModalFooter"
                width: modalStack.width
                height: control.modalFooterPadding * 2 + modalFooterRow.implicitHeight

                Row {
                    id: modalFooterRow

                    objectName: "userGuideModalButtons"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: control.buttonGap

                    Button {
                        id: modalSkip

                        objectName: "userGuideModalSkip"
                        // index.tsx:492 的 type='tertiary'（theme 走默认 light）
                        visible: control.showSkipButton && !control.isLastStep
                        text: control.skipLabel
                        tone: Enums.Tertiary
                        variant: Enums.Light
                        onClicked: control.handleSkip()
                    }

                    Button {
                        id: modalPrev

                        objectName: "userGuideModalPrev"
                        // index.tsx:501 的 type='tertiary'，后面才摊 prevButtonProps
                        visible: control.showPrevButton && !control.isFirstStep
                        text: control.prevLabel
                        tone: control.prevButtonTone !== undefined
                            ? control.prevButtonTone : Enums.Tertiary
                        variant: control.prevButtonVariant !== undefined
                            ? control.prevButtonVariant : Enums.Light
                        onClicked: control.handlePrev()
                    }

                    Button {
                        id: modalNext

                        objectName: "userGuideModalNext"
                        // index.tsx:510 的 theme='solid'（type 走默认 primary）
                        text: control.nextLabel
                        tone: control.nextButtonTone !== undefined
                            ? control.nextButtonTone : Enums.Primary
                        variant: control.nextButtonVariant !== undefined
                            ? control.nextButtonVariant : Enums.Solid
                        onClicked: control.handleNext()
                    }
                }
            }
        }
    }
}
