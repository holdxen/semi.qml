pragma ComponentBehavior: Bound

import QtQuick

// 回到顶部。滚动过一段距离后浮出一颗按钮，点一下滚回顶部。
//
//     Flickable { id: view; contentHeight: 2000 }
//     BackTop { target: view }
//
// 规格照 packages/semi-ui/backTop/index.tsx + semi-foundation/backTop/{foundation.ts,
// constants.ts,backtop.scss,variables.scss,rtl.scss}，数值逐条对编译后的
// packages/semi-ui/dist/css/semi.css（`.semi-backtop`、`.semi-button…icon-only`）。
//
// 官方 BackTopProps（index.tsx:18-26）与缺省值（:37-41）一共 6 条 + children：
//   target(() => any，缺省 () => window) / visibilityHeight(400) / duration(450) /
//   onClick(e) / style / className / children（不给就用默认的
//   <IconButton theme="light" icon={<IconChevronUp />} />）
// 度量（variables.scss + backtop.scss）：`position: fixed`、右 100、底 50、`z-index: 10`、
// `cursor: pointer`、`text-align: center`、`overflow: hidden`；rtl 档把右 100 换成左 100。
// 默认那颗是 icon-only 的 Button（`$width-button_iconOnly_default = $height-control-default`
// = 32×32），theme 走 light。
//
// 端口与官方的差异（逐条）：
//   · `target` 官方是**函数**（`() => HTMLElement | window`，因为 DOM 节点要等挂载后才拿得到，
//     而 window 压根不是元素）。端口直接收 `Flickable` 对象；**window 档没有对应物** ——
//     整页滚动也要自己给一个当滚动容器的 Flickable。
//   · `children` 在 QML 里没有落点（Item 的子项是 Item，整体替换不了默认那颗）⇒ 改名 `content`，
//     收 Component，与全站 ReactNode 档同一口径。
//   · `onClick(e)` 的入参是 React 鼠标事件，端口没有事件对象 ⇒ `clicked()` 不带参数。
//   · `style` / `className` 与全站同一口径：收了不产出可见差异。官方 demo 里 `style` 真正用到的
//     那两条（`bottom: 100` 与那颗蓝圆按钮）端口换成 `bottomMargin` / `content`。
//   · **`position: fixed` 是相对视口的**，端口是普通 Item ⇒ 按**父项**的右下角摆
//     （把 BackTop 和滚动容器放在同一个铺满窗口的根里，效果与 fixed 一致）。
//     `z-index: 10` ⇒ `z: 10`；rtl 那档（左右互换）端口不做（本库没有 direction 概念）。
//   · 官方 `handleScroll` 把更新塞进 `requestAnimationFrame` ⇒ 可见性晚一帧；端口在滚动信号里
//     **同步**写。判据与结果一致，只是少那一帧（上游自己的测试也把 rAF mock 成同步跑的）。
//   · 官方 `init()` 只在挂载时挂一次 scroll 监听，**换 `target` 不会改挂**；而 `handleScroll`
//     每次现读 `props.target()` ⇒ 换过 target 之后，旧容器滚动仍会用**新**容器的 contentY 来判。
//     两条都是上游行为，端口照抄（`Connections` 的 target 在 `Component.onCompleted` 钉一次，
//     判据现读 `control.target`）。
//   · 同理，`visibilityHeight` 改了**不会立刻**重算，要等下一次滚动（官方没有 componentDidUpdate）。
//   · 点击走 lodash `throttle(handleClick, duration)`（leading + trailing），**那个 duration 是
//     mount 时冻在 handler 上的**；而滚动动画的时长每次点击现读 props ⇒ 同一份 `duration`
//     两条命运。端口照抄：`throttleWindow` 在 `Component.onCompleted` 取一次快照。
//   · 不可见时官方 `render()` 返回 `null`（那颗按钮整个不存在）⇒ 端口 `visible: false`，
//     等价（拿不到事件、也不占绘制）。
//   · 缓动：semi-animation 的 `easeInOutCubic` 是 bezier `[0.645, 0.045, 0.355, 1.0]`
//     （`getEasing.ts` 的 InOut 表），端口用 `Easing.Bezier` 同一条曲线。
//   · 官方每次点击 `this.animation = new Animation(...)`，**旧的没停** ⇒ 连点会有两个动画抢
//     同一个 scrollTop。端口用一条 NumberAnimation 重启（`from` 现读当前 contentY），
//     这条不抄（throttle 已经把连点挡成每 `duration` 一次，官方那两条本来就几乎不重叠）。
Item {
    id: control

    // ---------------------------------------------------------------- 官方 BackTopProps
    /// 官方 target: () => any（端口收滚动容器本身，见文件头）
    property Flickable target: null
    property int visibilityHeight: 400
    property int duration: 450
    /// 官方 children：端口是 Component，不给就用那颗默认的 light icon-only 按钮
    property var content: null
    property var style: undefined
    property string className: ""

    /// 官方 onClick(e)
    signal clicked()

    // ---------------------------------------------------------------- 端口替身（CSS fixed / right / bottom）
    property int rightMargin: 100
    property int bottomMargin: 50

    readonly property bool hasCustom: control.content !== null && control.content !== undefined

    /// 官方 state.visible（初值 false，且**只由滚动与挂载驱动**）
    property bool shown: false
    /// 官方 handler 在 componentDidMount 里用当时的 duration 造好 ⇒ 窗口冻在挂载那一刻
    property int throttleWindow: 450
    /// 窗口内又有人点过（lodash 的 trailing）
    property bool throttlePending: false

    x: control.parent ? control.parent.width - width - control.rightMargin : 0
    y: control.parent ? control.parent.height - height - control.bottomMargin : 0
    width: face.width
    height: face.height
    visible: control.shown
    z: 10

    /// 官方 foundation.handleScroll：`scrollTop > visibilityHeight`（严格大于）。
    /// 这里**不设 target 为空的挡**：官方 handleScroll 也没有（`init()` 的早退只挡监听挂载），
    /// 换 target 之后旧容器滚动读新容器读到 null 同样会抛
    function refreshVisible() {
        control.shown = control.target.contentY > control.visibilityHeight;
    }

    /// 官方 handleClick 被 throttle 包了一层
    function handleClick() {
        if (throttleTimer.running) {
            control.throttlePending = true;
            return;
        }
        throttleTimer.start();
        control.scrollToTop();                        // leading：第一次点击立刻执行
    }

    /// 官方 foundation.onClick：先起滚动，再发回调
    function scrollToTop() {
        control.startScroll();
        control.clicked();
    }

    /// 端口自留的两个观察口：那颗动画本身（时长 / 缓动），与它此刻在不在跑。
    /// 「先起滚动再发回调」这条顺序只有回调里读得到
    readonly property alias scrollAnimation: scrollAnim
    readonly property bool scrolling: scrollAnim.running

    function startScroll() {
        if (control.target === null)
            return;
        scrollAnim.from = control.target.contentY;
        scrollAnim.to = 0;
        scrollAnim.duration = control.duration;       // 这条是现读 props
        scrollAnim.start();
    }

    Component.onCompleted: {
        control.throttleWindow = control.duration;
        if (control.target === null)
            return;                                   // 官方 init() 的 `!targetNode` ⇒ 监听与首算都不做
        scrollConn.target = control.target;           // 只挂这一次，换 target 不再改挂
        control.refreshVisible();                     // 官方 init() 末尾那句 handleScroll()
    }

    // 官方 targetNode.addEventListener('scroll', handleScroll)
    Connections {
        id: scrollConn

        target: null
        function onContentYChanged() {
            control.refreshVisible();
        }
    }

    // ---------------------------------------------------------------- 那颗按钮
    Item {
        id: face

        objectName: "backTopFace"
        width: control.hasCustom ? customSlot.width : defaultButton.width
        height: control.hasCustom ? customSlot.height : defaultButton.height
        clip: true                                    // overflow: hidden

        // 外层 div 是 shrink-to-fit ⇒ 格子跟着里面那颗走。两边都不许 anchors.fill: parent
        // （那会把「格子宽 ← 内容宽 ← 格子宽」接成环）
        Loader {
            id: customSlot

            objectName: "backTopContent"
            active: control.hasCustom
            visible: control.hasCustom
            sourceComponent: control.hasCustom ? control.content : null
        }

        IconButton {
            id: defaultButton

            objectName: "backTopDefault"
            visible: !control.hasCustom
            // 官方 renderDefault：<IconButton theme="light" icon={<IconChevronUp />} />
            variant: Enums.Light
            icon: "chevron_up"
        }

        HoverHandler {
            id: faceHover

            objectName: "backTopHover"
            cursorShape: Qt.PointingHandCursor        // cursor: pointer
        }

        // onClick 挂在**外层 div** 上，不是挂在按钮里 ⇒ 自定义节点留白处也算点
        TapHandler {
            id: faceTap

            acceptedButtons: Qt.LeftButton
            onTapped: control.handleClick()
        }
    }

    Timer {
        id: throttleTimer

        interval: control.throttleWindow
        onTriggered: {
            if (!control.throttlePending)
                return;
            control.throttlePending = false;
            control.scrollToTop();                    // trailing：窗口内最后一次点击补上
        }
    }

    /// semi-animation 的 `easeInOutCubic`（getEasing.ts 的 InOut 表）就是这条 bezier。
    /// 写成属性而不是直接塞进 `easing.bezierCurve` —— 那个 grouped property 从 JS 读回来是空的，
    /// 钉不住（端口自留的观察口）。Qt 的 setBezierCurve 每段要**六个值**（c1 c2 + 收尾点），
    /// 只给 CSS/bezier 那四个会静默丢弃并退化成线性（qqmlvaluetype.cpp:515）⇒ 补上终点 (1,1)。
    readonly property var cubicBezier: [0.645, 0.045, 0.355, 1.0, 1, 1]

    NumberAnimation {
        id: scrollAnim

        target: control.target
        property: "contentY"
        easing.bezierCurve: control.cubicBezier
    }
}
