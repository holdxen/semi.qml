import QtQuick

// 加载器。照 semi-ui/spin（`index.tsx` 的 SpinProps 与 `icon.tsx` 那张 SVG）+
// semi-foundation/spin（`spin.scss` / `variables.scss` / `foundation.ts`）。
//
//     Spin { }                                          // 20px 主色，一直转
//     Spin { size: "large" }                            // small 14 / middle 20 / large 32
//     Spin { spinning: page.busy }                      // 开关
//     Spin { delay: 1000; spinning: page.busy }         // 转够 1s 才露出来，关掉立刻藏
//     Spin { indicator: Component { Icon { name: "loading" } } }
//     Spin { tip: "加载中…"; Rectangle { …内容… } }      // 包裹模式
//
// 两种形态对应官方的两组规则：
// - 不包裹内容时，根节点自己就是 `$width-spin_*` 那个方块（`display:inline-block` + size）；
// - 一有 children 官方换 `-block`（`display:block`、宽高 auto）：根节点被内容撑开，
//   指示符那条 `-wrapper` 绝对定位浮在内容正中（`top:50%` + `translateY(-50%)` + `text-align:center`），
//   内容本身 `-children` 压到 `$opacity-spin_children` = 0.5，再加一层 `-block::after`
//   透明遮罩（`z-index:1`）挡住穿透点击。
//
// 指示符照 `icon.tsx`：viewBox 36、弧半径 16、线宽 4、圆头，从 3 点方向起算扫 154.2°，
// 描边是一条「左虚右实」的线性渐变（currentColor α 0 → .5 @39.94% → 1），看着像条彗尾。
// 匀速转一圈 `$animation_duration-spin_wrapper-spin` = 600ms；给了 `indicator` 就换成
// `-animate` 那一档，一圈是 `$animation_duration-spin_customChildren-spin` = 1600ms。
//
// 颜色对应官方 `.semi-spin-wrapper` 的 `color`（`$color-spin-bg` = primary）——
// 官方 FAQ 改色就是改这一处，所以 `tip` 的文字也跟着它。
//
// 与官方的差异（ReactNode / CSS 在 QML 侧无处落地）：
// - `tip` 只收文字（官方 ReactNode）；`wrapperClassName` / `style` / `childStyle` 不提供，
//   直接给控件写 `width` / `height` / `anchors` 即可；
// - `user-select: none`（加载中不许选中文本）没有对应开关；
// - 包裹模式的内容要自己排版（和 Badge 一样是 `content` 里摆一个 Item），
//   别在里面用 `anchors.fill: parent` —— 根节点的隐式尺寸是照着内容算的。
Item {
    id: control

    // ---- 官方 prop ----
    property string size: "middle"          // small | middle | large（index.tsx:47）
    property bool spinning: true            // index.tsx:48
    property int delay: 0                   // index.tsx:50，单位 ms
    property string tip: ""                 // 官方 tip: ReactNode，本地只收文字
    property Component indicator: null      // 官方 indicator: ReactNode

    // 官方 .semi-spin-wrapper 的 color（FAQ 的改色入口）
    property color color: Theme.current.colorPrimary

    // 官方 children：默认属性，摆进来就进「包裹模式」
    default property alias content: contentHost.data

    // ---- 官方 state ----
    // loading：指示符到底画不画。官方构造函数给 true，之后每次 props 变化
    // 按 getDerivedStateFromProps（index.tsx:64-79）同步
    property bool loading: true
    // pendingDelay：官方 state.delay，非 0 = 正在等 delay 毫秒
    property int pendingDelay: 0

    readonly property int side: control.size === "small" ? 14
        : (control.size === "large" ? 32 : 20)      // $width-spin_small / _large / _middle
    readonly property bool wrapped: contentHost.children.length > 0
    // 官方 path 的张角：90°（(34,18) → (18,2)）+ 64.2°（→ (3.59,11.04)）
    readonly property real arcSweep: 154.2 * Math.PI / 180
    // 一圈时长：默认弧 600ms，自定义指示符走 -animate 那档 1600ms
    readonly property int spinDuration: control.indicator !== null ? 1600 : 600

    implicitWidth: control.wrapped ? contentHost.childrenRect.width : control.side
    implicitHeight: control.wrapped ? contentHost.childrenRect.height : control.side

    onSpinningChanged: control.syncLoading()
    onDelayChanged: control.syncLoading()
    Component.onCompleted: control.syncLoading()

    function syncLoading() {
        if (control.delay <= 0) {
            control.pendingDelay = 0;
            control.loading = control.spinning;
            return;
        }
        if (!control.spinning) {
            // 关掉不等延迟，马上藏（index.tsx:70-74）
            control.pendingDelay = 0;
            control.loading = false;
            return;
        }
        control.pendingDelay = control.delay;
    }

    // 官方 foundation.updateLoadingIfNeedDelay（foundation.ts:22-34）：
    // 「在等」的时候挂一个定时器，到点才把 loading 摆到 spinning 的真值
    Timer {
        id: delayTimer

        interval: control.pendingDelay
        running: control.pendingDelay > 0
        onTriggered: {
            control.pendingDelay = 0;
            control.loading = control.spinning;
        }
    }

    // ------------------------------------------------------------------
    // 被包裹的内容（官方 -children）
    // ------------------------------------------------------------------
    Item {
        id: contentHost

        objectName: "spinContent"
        anchors.fill: parent
        // -children { opacity: $opacity-spin_children } / -hidden > -children { opacity: 1 }
        opacity: control.loading ? 0.5 : 1
    }

    // ------------------------------------------------------------------
    // 指示符（官方 -wrapper：绝对定位、整幅宽、垂直居中、text-align:center）
    // ------------------------------------------------------------------
    Item {
        id: spinWrapper

        objectName: "spinWrapper"
        width: parent.width
        // 官方那是 top:50% + translateY(-50%)，被居中的是「弧 + tip」这一整块的高度，
        // 所以盒子高度要跟着内容走，写成 0 的话整块会往下偏半格
        height: spinColumn.height
        anchors.verticalCenter: parent.verticalCenter
        visible: control.loading

        Column {
            id: spinColumn

            anchors.horizontalCenter: parent.horizontalCenter

            // 转的是这一格：默认弧对应 `& > svg`，自定义指示符对应 -animate。
            // 横向自己居中：Column 只管 y，官方那是 -wrapper 的 text-align:center，
            // 每个子块各自居中（tip 比弧宽时弧不能跟着左对齐）
            Item {
                id: spinnerBox

                objectName: "spinBox"
                anchors.horizontalCenter: parent.horizontalCenter
                width: control.indicator !== null ? indicatorLoader.implicitWidth : control.side
                height: control.indicator !== null ? indicatorLoader.implicitHeight : control.side

                Canvas {
                    id: canvas

                    objectName: "spinCanvas"
                    visible: control.indicator === null
                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d");
                        const w = width;
                        const h = height;
                        // 线宽与半径都按 viewBox 36 的比例：线宽 4，弧半径 16 = (36 - 4) / 2
                        const lineWidth = Math.max(1, Math.min(w, h) * (4 / 36));
                        const radius = (Math.min(w, h) - lineWidth) / 2;
                        const cx = w / 2;
                        const cy = h / 2;
                        const sweep = control.arcSweep;
                        const rgb = Math.round(control.color.r * 255) + ", "
                            + Math.round(control.color.g * 255) + ", "
                            + Math.round(control.color.b * 255);

                        ctx.reset();
                        ctx.lineWidth = lineWidth;
                        ctx.lineCap = "round";

                        // linearGradient x1=0% y1=100% x2=100% y2=100%，即沿包围盒从左到右。
                        // 这段弧的 x 单调，所以「左端（尾）全透明 → 右端（头）实心」就是官方那条渐变。
                        const grad = ctx.createLinearGradient(cx + radius * Math.cos(sweep), cy,
                            cx + radius, cy);
                        grad.addColorStop(0, "rgba(" + rgb + ", 0)");
                        grad.addColorStop(0.399430698, "rgba(" + rgb + ", 0.5)");
                        grad.addColorStop(1, "rgba(" + rgb + ", 1)");
                        ctx.strokeStyle = grad;

                        ctx.beginPath();
                        // 画布角度以顺时针为正（y 轴朝下），官方那条弧从 3 点方向往上扫，所以取负角
                        ctx.arc(cx, cy, radius, -sweep, 0);
                        ctx.stroke();
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    Connections {
                        target: control
                        function onColorChanged() { canvas.requestPaint(); }
                        function onSideChanged() { canvas.requestPaint(); }
                    }
                }

                Loader {
                    id: indicatorLoader

                    objectName: "spinIndicator"
                    anchors.centerIn: parent
                    sourceComponent: control.indicator
                }

                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: control.spinDuration
                    loops: Animation.Infinite
                    running: spinWrapper.visible
                }
            }

            // 官方 {tip ? <div>{tip}</div> : null}：块级、跟着 -wrapper 的 text-align:center
            // 与 color，字号行走 body 的 font-size-regular（14px / line-height 20px）
            Text {
                objectName: "spinTip"
                anchors.horizontalCenter: parent.horizontalCenter
                visible: control.tip !== ""
                text: control.tip
                color: control.color
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }
    }

    // ------------------------------------------------------------------
    // 遮罩（官方 -block::after：position:absolute + z-index:1，只在包裹模式且有指示符时）
    // ------------------------------------------------------------------
    MouseArea {
        objectName: "spinMask"
        anchors.fill: parent
        enabled: control.loading && control.wrapped
    }
}
