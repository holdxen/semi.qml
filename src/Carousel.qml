pragma ComponentBehavior: Bound

import QtQuick

// 轮播。官方 `packages/semi-ui/carousel/index.tsx`（CarouselProps 见 interface.ts:12-32、
// defaultProps :43-59、renderChildren :175-213、renderIndicator :215-241、renderArrow :243-259、
// render :262-296）+ `semi-foundation/carousel/{foundation.ts,carousel.scss,variables.scss,
// constants.ts}`。
//
//     Carousel {
//         width: 480; height: 240
//         indicatorType: "line"
//         theme: "dark"
//         Rectangle { color: "#2f6feb" }
//         Rectangle { color: "#e05c5c" }
//     }
//
// ------------------------------------------------------------------ 官方 prop（18 条）
//   `activeIndex` `animation` `arrowProps` `autoPlay` `arrowType` `children` `className`
//   `defaultActiveIndex` `indicatorPosition` `indicatorSize` `indicatorType` `theme` `onChange`
//   `showArrow` `showIndicator` `slideDirection` `speed` `style` `trigger`，方法五个：
//   `next` / `prev` / `goTo` / `play` / `stop`（CarouselMethod）。
//   缺省（defaultProps）：animation slide、autoPlay true、arrowType always、
//   defaultActiveIndex 0、indicatorPosition center、indicatorSize small、indicatorType dot、
//   theme light、showArrow / showIndicator true、slideDirection left、speed 300、trigger click。
//   `className` / `style` 收了不产出可见差异（只喂 DOM）。
//
// ------------------------------------------------------------------ 受控 / 非受控
//   `getIsControlledComponent()` 就是「props 里有没有 activeIndex」。受控时
//   goTo / next / prev / 指示器**只发 onChange、不改内部状态**（等使用方回写）；
//   挂载（componentDidMount → 组件层 handleAutoPlay，index.tsx:139-143）与鼠标离开那两处
//   的重启都被这道门挡掉 ⇒ 受控档不会自己播。但 `next` / `prev` 调的是 foundation 自己那道
//   没有门的 handleAutoPlay（foundation.ts:65 / :79）⇒ 受控档下手动切一次照样把计时起起来，
//   之后每次触发只发 onChange、视图不动（官方就是这个行为，端口照抄并钉一条用例）。
//   未受控时初值取 `defaultActiveIndex`（构造期快照一次，之后改它无效）。
//
// ------------------------------------------------------------------ 切换动画（与旧端口最大的差别）
//   官方**不是轨道平移**：`-content-item` 每一片都是 `position:absolute; left:0; top:0;
//   width:100%; height:100%`，全部叠在同一格上，靠三件事区分：
//     · `-item-current` ⇒ `z-index: 1`（进片盖在出片上面）；
//     · slide 档 `> *:not(-item-current) { visibility: hidden }`；
//     · 只有「进来的那片」（`!isInit && isCurrent`）挂 `-item-slide-in` 关键帧
//       （从 translateX(±100%) 到 0），「出去的那片」（`index === preIndex`）挂 `-item-slide-out`
//       （0 到 ∓100%），两条都 `animation-fill-mode: forwards`。
//   **两片同时在动**。早先以为「-slide-out 没恢复 visibility ⇒ 出去那片整段不可见」是错的：
//   index.tsx:188-193 给每片都内联了 `transitionDuration: speed ms`，而 `transition-property`
//   的初值是 `all` ⇒ `visibility` 也在过渡；CSS visibility 的插值规则是「严格在 (0,1) 之间时
//   只要有一端是 visible 就取 visible」⇒ 出去那片整段动画都可见、到动画结束那一帧才变
//   hidden；进片只在 progress 恰好 0 的那一瞬是 hidden（那时它还在屏外 +100%，无视觉差）。
//   浏览器逐帧实测（编译后的 semi.css + 手工 DOM 探针）：进片 400→0、出片 0→-400 全程对称
//   同速，t=0.275·speed 时已走完 46.8% ⇒ 曲线就是内联的 `animationTimingFunction: 'ease'`
//   = cubic-bezier(0.25, 0.1, 0.25, 1)。
//   端口照这个结果落：动画期间**两片都画**，进片按 `1 - progress` 从 ±宽 到 0、出片按
//   `progress` 从 0 到 ∓宽；动画一结束出片重新隐藏（官方是 visibility 过渡到头）。
//   方向：`isReverse` 由 prev / 「目标索引比当前小」置真，真正生效的那一位是
//   `slideDirection === 'left' ? isReverse : !isReverse`（:286）⇒ next 时进片从右滑入、
//   出片向左滑出，prev 反之。
//   已知不复刻的微差（上游 `transition: all` 的偶然副作用）：**连点打断**时，更老的那一片
//   （上一轮的出片）会脱掉动画类、靠 `transition: all 3s ease` 从 -100% 滑回 0 并且可见
//   3 秒才 hidden；端口在打断时把它直接隐掉。正常逐次切换两边一致。
//   fade 档则是 `> * { opacity: 0 }` + `-current { opacity: 1 }`，配合内联的
//   `transition: all ${speed}ms ease` ⇒ 新旧两片同时交叉淡入淡出。
//   `isInit` 只在第一次 `_notifyChange` 时翻假 ⇒ **首屏不带动画**；受控档由使用方改
//   `activeIndex` 时不走 `_notifyChange` ⇒ 那一次 `isInit` 仍为真 ⇒ 首切不 animate（照抄）。
//   官方给每片还挂了 `-item-prev` / `-item-next`（相邻两片）两个类名，carousel.scss 里
//   **没有任何规则用到它们** ⇒ 端口不落。
//
// ------------------------------------------------------------------ 自动播放
//   `autoPlay`：`true` | `false` | `{ interval?, hoverToPause? }`（**没有独立的 interval prop**）。
//   下一次切换的等待 = `getSwitchingTime()` = 布尔档 `2000 + speed`、对象档
//   `(interval ?? 2000) + speed`、其余 `speed` —— 也就是**过渡时长也算进间隔**。
//   `next()` / `prev()` 会先 `stop()` 再 `handleAutoPlay()`（手动切一次会把计时重新对齐），
//   而 `goTo()` 与指示器点击**都不重启计时器**（官方 :42-52 / :146-153 就是没写），端口照抄。
//   鼠标进出走 lodash 的 `debounce(fn, 400)` ⇒ 进 / 出都延迟 400ms 才生效；
//   进入时只有 `autoPlay === true` 或 `hoverToPause` 为真才停，离开时
//   「不是对象档 或 hoverToPause」且非受控才重启。
//   `play()` / `stop()` 带一个 `_forcePlay` 开关：`play()` 置真后，即使 `autoPlay={false}`
//   也能播起来；组件的 `stop()` 会把它清掉（foundation 自己的 `stop()` 不会）。
//   只有 `children.length > 1` 才允许起播（:132），指示器与箭头同样要 `> 1` 才渲染。
//
// ------------------------------------------------------------------ 尺寸与配色（variables.scss）
//   指示器距边 32（`$spacing-carousel_indicator-padding`）、点 8/12 见方间距 8、
//   柱 4/6 宽、高 12→20 / 20→28、间距 4、条状容器写死 240 高 4/6 间距 4；
//   箭头 32（`$width-carousel_arrow` 兼 font-size）、左右各 20、垂直居中；
//   指示器三主题 alpha：dark .5/.7/1、primary 与 light .4/.7/1（蓝取 `--semi-blue-6` 而不是语义主色）；
//   箭头只有 .4(.5) → 1 两档。两条 `transition` 规则的时长令牌都误取了
//   `--semi-transition_delay-none`（0ms）⇒ 换色瞬时，端口不做过渡动画。
//
// ------------------------------------------------------------------ 端口差异与不抄的上游 bug
//   · QML 分不清「键给了但值是 undefined」与「没给这个键」⇒ 受控判据只能按真值取
//     `activeIndex !== undefined`：写 `activeIndex: undefined` 在官方算受控、在端口算非受控，
//     写 `activeIndex: null` 两边都算受控。钉成 `test_nullActiveIndexCountsAsControlled`。
//   · 官方 `getValidIndex` 是 `(index + length) % length` ⇒ 只加一次长度，
//     `index < -length` 时 JS 取模会给出**负数**（匹配不到任何一片）。端口用规范化取模，
//     并钉成 `test_validIndexNormalizesFarNegative`。
//   · 同样那条在 `children.length === 0` 时是 `NaN`；端口兜 0。
//   · 官方 `role='listbox'`、`tabIndex`、`handleKeyDown`（左右键切页）三处**全被注释掉**了
//     （index.tsx:272-281、:137-144）⇒ 没有键盘档，端口也不做；只保留箭头图标的 aria-label。
//   · 官方进出场用 CSS 关键帧 + `animation-fill-mode: forwards`，端口用一个被动画驱动的
//     `progress` + 每片自己的位移/透明度绑定（子项是使用方声明的，端口给不了 `Behavior`）。
//   · CSS 关键字 `ease` = cubic-bezier(0.25, 0.1, 0.25, 1)，端口用 `Easing.Bezier` 精确复刻；
//     Qt 的 setBezierCurve 每段要六个值（含收尾点）⇒ 曲线写成六元组
//     `[0.25, 0.1, 0.25, 1, 1, 1]`，提成只读 `easeCurve` 供测试读（grouped property 的
//     bezierCurve 从 JS 读回来是空的，见坑 132）。
Item {
    id: control

    // ---- 官方 CarouselProps（interface.ts:12-32，缺省 index.tsx:43-59）----
    property var activeIndex: undefined            // 给了就是受控
    property string animation: "slide"             // slide | fade
    property var arrowProps: undefined             // { leftArrow: { children }, rightArrow: { children } }
    property var autoPlay: true                    // true | false | { interval, hoverToPause }
    property string arrowType: "always"            // always | hover
    property string className: ""                  // 死 prop
    property var defaultActiveIndex: 0
    property string indicatorPosition: "center"    // left | center | right
    property string indicatorSize: "small"         // small | medium
    property string indicatorType: "dot"           // dot | line | columnar
    property string theme: "light"                 // dark | primary | light
    property bool showArrow: true
    property bool showIndicator: true
    property string slideDirection: "left"         // left | right
    property int speed: 300
    property var style: undefined                  // 死 prop
    property string trigger: "click"               // click | hover

    /// 官方 children（每一片是一屏）
    default property alias content: viewport.data

    /// 官方 onChange(activeIndex, preIndex)
    signal changed(int activeIndex, int preIndex)

    // ---- 官方 CarouselState ----
    property int innerIndex: 0
    property int preIndex: 0
    property bool isReverse: false
    property bool isInit: true
    property bool forcePlay: false

    /// 切换进度：1 = 到位，0 = 刚起步（进来的那片还在 ±100% 处）
    property real progress: 1
    property int declaredCount: 0
    property bool bootedOnce: false

    readonly property int defaultInterval: 2000    // numbers.DEFAULT_INTERVAL
    readonly property real indicatorInset: 32      // $spacing-carousel_indicator-padding
    /// 官方判据是「props 里有没有 activeIndex 这个键」（`_isInProps`），与值无关。
    /// QML 侧分不出「键在但值是 undefined」和「没给键」，只能按真值判：`undefined` 算没给，
    /// `null` 算受控（差异已记文件头）。
    readonly property bool controlled: control.activeIndex !== undefined
    readonly property int shownIndex: control.controlled
        ? control.numberOr(control.activeIndex, 0) : control.innerIndex
    readonly property bool autoPlayObject: control.autoPlayIsObject()
    readonly property bool hoverToPauseOn: control.autoPlayIsObject()
        ? !!control.autoPlay.hoverToPause : true
    readonly property int count: control.declaredCount
    readonly property bool hasPages: control.count > 1
    /// 官方 :286 `slideDirection === 'left' ? isReverse : !isReverse`
    readonly property bool reversed: control.slideDirection === "left" ? control.isReverse : !control.isReverse
    readonly property real switchingTime: typeof control.autoPlay === "boolean"
        ? control.defaultInterval + control.speed
        : (control.autoPlayIsObject()
            ? control.numberOr(control.autoPlay.interval, control.defaultInterval) + control.speed
            : control.speed)
    /// CSS 关键字 `ease` = cubic-bezier(0.25, 0.1, 0.25, 1)：官方给每片内联的
    /// animationTimingFunction / transitionTimingFunction 都是它。Qt 的 setBezierCurve
    /// 每段要**六个值**（c1x c1y c2x c2y c3x c3y，收尾点必须写出来），只给 CSS 那四个会
    /// **静默丢弃并退化成线性**（qqmlvaluetype.cpp:515 `size() % 6 != 0` 直接 return）
    /// ⇒ 这里补上 CSS 隐含的终点 (1, 1)。赋了合法 bezierCurve 之后**整条曲线连 type 一起被
    /// 换成 BezierSpline**（setter 里 `*this = newEasingCurve`）⇒ `easing.type` 那行是死的，
    /// 已删。提成属性而不是直接塞进 `easing.bezierCurve`，是因为那个 grouped property
    /// 从 JS 读回来是空的、钉不住（坑 132）。
    readonly property var easeCurve: [0.25, 0.1, 0.25, 1, 1, 1]

    implicitWidth: 480
    implicitHeight: 240

    // ------------------------------------------------------------------ 索引与状态
    /// 官方是 lodash 的 `isObject(autoPlay)`（null 不算对象）。
    /// **写成函数而不是派生只读属性给别处读**：`autoPlay` 从对象档改成 null 的那一拍，
    /// 下游绑定（switchingTime / hoverToPauseOn / playTimer.interval）可能还拿着旧的
    /// `autoPlayObject` 真值去点 `null.interval` —— 实测会刷一条 TypeError 并把值停在旧读数的
    /// 边界上（见 tests/tmp_carousel_probe.qml 的 D 段）。同一条纪律在 Card 那轮也栽过（坑 114）。
    function autoPlayIsObject() {
        return typeof control.autoPlay === "object" && control.autoPlay !== null;
    }

    function numberOr(value, fallback) {
        if (value === undefined || value === null)
            return fallback;
        const n = Number(value);
        return isNaN(n) ? fallback : n;
    }

    /// 官方 `(index + length) % length`（负得超过一圈会给出负数）⇒ 端口规范化，差异已记文件头
    function validIndex(index) {
        const n = control.count;
        if (n <= 0)
            return 0;
        const raw = control.numberOr(index, 0);
        return ((raw % n) + n) % n;
    }

    function notifyChange(index) {
        const cur = control.shownIndex;
        if (control.isInit)
            control.isInit = false;
        if (cur !== index) {
            control.preIndex = cur;
            control.changed(index, cur);
        }
    }

    /// 官方 foundation.ts:156-161 那条 `if (stateActiveIndex !== activeIndex)` 在 Qt 侧
    /// 是 no-op（同值赋值不触发 changed），端口删掉，只留 setState 那一半。
    function handleNewActiveIndex(index) {
        control.innerIndex = index;
    }

    function goTo(index) {
        const target = control.validIndex(index);
        control.isReverse = control.shownIndex > target;
        control.notifyChange(target);
        if (!control.controlled)
            control.handleNewActiveIndex(target);
    }

    function next() {
        playTimer.stop();
        const target = control.validIndex(control.shownIndex + 1);
        control.isReverse = false;
        control.notifyChange(target);
        if (!control.controlled)
            control.handleNewActiveIndex(target);
        control.handleAutoPlay();
    }

    function prev() {
        playTimer.stop();
        const target = control.validIndex(control.shownIndex - 1);
        control.isReverse = true;
        control.notifyChange(target);
        if (!control.controlled)
            control.handleNewActiveIndex(target);
        control.handleAutoPlay();
    }

    /// 指示器那一档：只 notify + 改状态，**不重启计时器**（官方 :146-153 没写）
    function handleIndicatorChange(index) {
        control.isReverse = control.shownIndex > index;
        control.notifyChange(index);
        if (!control.controlled)
            control.handleNewActiveIndex(index);
    }

    // ------------------------------------------------------------------ 自动播放
    /// 官方 `foundation.play(interval)` 把 getSwitchingTime() 当参数传给 setInterval；
    /// 端口让 Timer.interval 直接绑 switchingTime（改 autoPlay / speed 时跟着变），
    /// 这里只负责 restart —— 那条 setInterval 每次 play 都重建，等价。
    function handleAutoPlay() {
        if (control.hasPages && (control.autoPlay === true || control.autoPlayIsObject()
            || control.forcePlay))
            playTimer.restart();
    }

    /// 官方 CarouselMethod.play：置 forcePlay 再起播
    function play() {
        control.forcePlay = true;
        control.handleAutoPlay();
    }

    /// 官方 CarouselMethod.stop：清 forcePlay 再停
    function stop() {
        control.forcePlay = false;
        playTimer.stop();
    }

    function handleMouseEnter() {
        if (control.autoPlay === true || (control.autoPlayIsObject() && control.hoverToPauseOn))
            playTimer.stop();
    }

    function handleMouseLeave() {
        if ((!control.autoPlayIsObject() || control.hoverToPauseOn) && !control.controlled)
            control.handleAutoPlay();
    }

    /// 组件层那层门（index.tsx:139-143）只有挂载（componentDidMount）与鼠标离开两处走它，
    /// 而 `next` / `prev` 调的是 foundation 自己的 handleAutoPlay（foundation.ts:65 / :79），
    /// 没有这道门 ⇒ 受控档下手动切一次仍会把计时起起来，之后每次触发只发 onChange、视图不动。
    /// 官方就是这个行为，端口照抄并钉成 test_controlledNextStartsTimer。

    // ------------------------------------------------------------------ 每片的几何
    /// 官方那条 `> *:not(-item-current) { visibility: hidden }` 被内联的
    /// `transitionDuration` + `transition-property` 初值 `all` 化解：visibility 的插值在
    /// 严格 (0,1) 之间只要有一端是 visible 就取 visible ⇒ 出片整段动画可见、到动画结束
    /// 那一帧才 hidden（浏览器逐帧实测，见文件头）。
    function pageVisible(index) {
        if (control.animation !== "slide")
            return true;
        if (index === control.shownIndex)
            return true;
        return index === control.preIndex && control.progress < 1;
    }

    function pageOpacity(index) {
        if (control.animation === "slide")
            return 1;
        if (index === control.shownIndex)
            return control.progress;
        if (index === control.preIndex)
            return 1 - control.progress;
        return 0;
    }

    /// slide-in 关键帧 从 translateX(±100%) 到 0、slide-out 关键帧 从 0 到 ∓100%
    /// ⇒ 进片 (1-p)·宽·dir、出片 -p·宽·dir，两片全程对称同速（浏览器实测间距恒等于宽）。
    function pageX(index) {
        if (control.animation !== "slide")
            return 0;
        const w = viewport.width;
        const dir = control.reversed ? -1 : 1;
        if (index === control.shownIndex)
            return (1 - control.progress) * w * dir;
        if (index === control.preIndex && control.progress < 1)
            return control.progress * w * -dir;
        return 0;
    }

    function bindChildren() {
        const nodes = control.pageNodes();
        for (let i = 0; i < nodes.length; ++i) {
            const node = nodes[i];
            const index = i;
            node.width = Qt.binding(function () { return viewport.width; });
            node.height = Qt.binding(function () { return viewport.height; });
            node.x = Qt.binding(function () { return control.pageX(index); });
            node.visible = Qt.binding(function () { return control.pageVisible(index); });
            node.opacity = Qt.binding(function () { return control.pageOpacity(index); });
            node.z = Qt.binding(function () { return index === control.shownIndex ? 1 : 0; });
        }
    }

    /// `children` 没有 NOTIFY ⇒ 名单由 onChildrenChanged 记；Qt 6.11 起 Repeater 自己
    /// 也是个 Item，那一层空壳不算一屏。
    function pageNodes() {
        const out = [];
        for (let i = 0; i < viewport.children.length; ++i) {
            const node = viewport.children[i];
            if (node === null || node === undefined || node instanceof Repeater)
                continue;
            out.push(node);
        }
        return out;
    }

    // ------------------------------------------------------------------ 触发
    // 换 animation 不用手动重排：pageVisible / pageOpacity 的绑定都读它，会自动重算
    onShownIndexChanged: control.handleShownChange()

    Component.onCompleted: {
        const first = control.numberOr(control.defaultActiveIndex, 0);
        control.innerIndex = first;
        control.preIndex = first;
        // 声明式子项在 onCompleted 之前就把 viewport.childrenChanged 发过一趟，
        // 片数与绑定那一趟已经做完 ⇒ 这里不再重数/重绑（整条删掉都不红，见坑 115）。
        control.bootedOnce = true;
        if (!control.controlled)
            control.handleAutoPlay();
    }

    function handleShownChange() {
        if (!control.bootedOnce)
            return;
        // 官方 slide-in 要 `!isInit`；受控档由使用方改 activeIndex 不走 _notifyChange，
        // 那一次 isInit 仍为真 ⇒ 首切不 animate（照抄）
        if (control.animation === "slide" && control.isInit) {
            control.progress = 1;
            return;
        }
        control.progress = 0;
        progressAnim.start();
    }

    Item {
        id: viewport

        objectName: "carouselViewport"

        anchors.fill: parent
        clip: true

        onChildrenChanged: {
            control.declaredCount = control.pageNodes().length;
            control.bindChildren();
        }
    }

    NumberAnimation {
        id: progressAnim

        objectName: "carouselProgressAnim"

        target: control
        property: "progress"
        from: 0
        to: 1
        duration: control.speed
        easing.bezierCurve: control.easeCurve    // 0.25 0.1 0.25 1，再补 Qt 要的收尾点 1 1
    }

    Timer {
        id: playTimer

        objectName: "carouselPlayTimer"

        interval: control.switchingTime
        // **不写 repeat: true**：每次到点都走 next()，而 next() 自己 stop + 按门 restart
        // （官方 setInterval 每次 play 也是重建），变异扫描实测 repeat 写 true / false 全绿
        // ⇒ 那条是冗余，摘掉（口径见 PROGRESS.md 坑 115）。
        onTriggered: control.next()
    }

    // 官方 `onMouseEnter / onMouseLeave` 都是 `debounce(fn, 400)`
    Timer {
        id: enterTimer

        objectName: "carouselEnterDebounce"

        interval: 400
        onTriggered: control.handleMouseEnter()
    }

    Timer {
        id: leaveTimer

        objectName: "carouselLeaveDebounce"

        interval: 400
        onTriggered: control.handleMouseLeave()
    }

    HoverHandler {
        id: rootHover

        objectName: "carouselHover"

        onHoveredChanged: {
            if (rootHover.hovered)
                enterTimer.restart();
            else
                leaveTimer.restart();
        }
    }

    // ------------------------------------------------------------------ 指示器
    CarouselIndicator {
        id: indicator

        objectName: "carouselIndicator"

        visible: control.showIndicator && control.hasPages
        z: 2
        total: control.count
        activeIndex: control.shownIndex
        type: control.indicatorType
        size: control.indicatorSize
        theme: control.theme
        position: control.indicatorPosition
        trigger: control.trigger
        x: control.indicatorPosition === "left" ? control.indicatorInset
            : (control.indicatorPosition === "right"
                ? control.width - control.indicatorInset - width
                : (control.width - width) / 2)
        y: control.height - control.indicatorInset - height

        onIndicatorChanged: function (index) { control.handleIndicatorChange(index); }
        onIndicatorEntered: function (index) { control.handleIndicatorChange(index); }
    }

    // ------------------------------------------------------------------ 箭头
    CarouselArrow {
        id: arrow

        objectName: "carouselArrow"

        width: control.width
        height: control.height
        visible: control.showArrow && control.hasPages
        z: 2
        type: control.arrowType
        theme: control.theme
        arrowProps: control.arrowProps
        carouselHovered: rootHover.hovered

        onPrevClicked: control.prev()
        onNextClicked: control.next()
    }
}
