pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// 滑动条。单击轨道或拖拽手柄调整数值，值会按 step 吸附。
//
//     Slider { value: 40 }                                    // 单值
//     Slider { range: true; values: [20, 60] }                // 双滑块
//     Slider { vertical: true; value: 30 }                    // 垂直（上小下大）
//     Slider { vertical: true; verticalReverse: true }        // 垂直反向（上大下小）
//     Slider { marks: [{ value: 0, label: "0" }, …] }          // 刻度
//     Slider { handleDot: ({ size: 6 }) }                      // 手柄中心带圆点
//     （对象字面量一定要拿括号包起来：`handleDot: { size: 6 }` 会被当成
//      「带标签的语句」，属性拿到的是数字 6，圆点会退回默认 4px）
//
// 规格（$color-slider_* / $width-slider_* / $spacing-slider_*）：
// 轨道 4px、手柄白底 + 双层投影（`border: none`，只有按下出 1px focus-border、
// 禁用出 1px color-border 且撤掉投影）、
// 刻度点 4px 白圆、刻度标签 text-2 / 14px、手柄圆点默认 4px primary。
//
// 几何用「手柄圆心沿整条轨道行走」的模型（对应 Semi 的 translateX(-50%)）：
// 圆心从 railStart 走到 railStart + railLength，两端各留 handleSize/2 的余量，
// 手柄因此始终落在组件范围内。这样值到 min 时填充天然为 0，不必特判。
//
// 尺寸照 Semi：轨道 4px、手柄 24px（$width-slider_handle）、
// 两端余量 13px（$spacing-slider-paddingX）、刻度点 4px。
Item {
    id: control

    // ---- 取值 ----
    property real value: 0
    property real min: 0
    property real max: 100
    property real step: 1

    // 双滑块。range 为 true 时读 values（两个值，顺序无所谓，内部按大小当低/高）
    property bool range: false
    property var values: [0, 100]

    // ---- 方向 ----
    property bool vertical: false
    // 垂直时反转：默认是「上小下大」，反转后「上大下小」
    property bool verticalReverse: false

    // ---- 刻度 ----
    // [{ value, label }]，只有落在 [min, max] 内的才画
    property var marks: []
    // false 时不着色填充（官网上「分段背景」那种用法）
    property bool included: true
    property bool showMarkLabel: true
    property bool tooltipOnMark: false

    // ---- 手柄 ----
    // { color, size }；双滑块可以给 [{ … }, { … }] 分别指定
    property var handleDot: null

    // ---- 提示 ----
    property bool showValue: false
    property string suffix: ""
    // function(value) -> string。给了它，拖动时会跟着显示提示
    property var tipFormatter: null
    // 悬停时在两端显示 min / max
    property bool showBoundary: false

    // ---- 轨道底色 ----
    // 给一条**静态**渐变就盖在轨道上（水平滑块记得写 orientation: Gradient.Horizontal）。
    // 注意：别把 GradientStop 的 position 绑到会变的量上 —— 每帧重建渐变材质会让
    // 那一帧超时掉帧（实测最长帧从 22.6ms 涨到 34.2ms）。要画跟着手柄走的分段底色，
    // 用下面的 railContent 画实色块。
    property Gradient railGradient: null

    // 轨道上、手柄下的一层，给调用方画自定义底纹（对应 Semi 的 railStyle）。
    // 坐标是轨道局部坐标：x 从 0 到 railLength，y 以轨道顶为 0。
    property alias railContent: railItem.data

    signal moved(var value)
    signal afterChange(var value)

    // ------------------------------------------------------------------
    // 几何
    // ------------------------------------------------------------------

    readonly property int trackHeight: 4
    readonly property int handleSize: 24          // $width-slider_handle
    readonly property int dotSize: 4              // $width-slider_dot
    // 两端给手柄留的余量（$spacing-slider-paddingX）：圆心落到轨道两端时
    // 手柄正好装得下，还余 1px
    readonly property int paddingX: 13
    readonly property real railStart: control.paddingX
    readonly property real railLength: Math.max(1, control.axisLength - control.paddingX * 2)
    // 水平看宽、垂直看高
    readonly property real axisLength: control.vertical ? control.height : control.width

    readonly property Item handle: handleItem
    readonly property Item handleEnd: handleItemEnd
    readonly property Item rail: railItem

    function clamp01(v) {
        return Math.max(0, Math.min(1, v));
    }

    function ratioOf(v) {
        const span = control.max - control.min;
        return span > 0 ? control.clamp01((v - control.min) / span) : 0;
    }

    function valueOfRatio(r) {
        return control.min + r * (control.max - control.min);
    }

    // 垂直反向只是把沿轴的比例翻过来。这个函数是自己的反函数，来回都能用
    function axisRatioOf(r) {
        return control.verticalReverse ? 1 - r : r;
    }

    // 值 → 手柄圆心在「沿轴坐标」上的位置（水平是 x，垂直是 y）
    function axisPosOf(v) {
        return control.railStart + control.axisRatioOf(control.ratioOf(v)) * control.railLength;
    }

    // 沿轴坐标 → 值（未经 step 吸附）
    function valueOfAxisPos(pos) {
        const raw = (pos - control.railStart) / control.railLength;
        return control.valueOfRatio(control.axisRatioOf(control.clamp01(raw)));
    }

    function snap(v) {
        let next = v;
        if (control.step > 0)
            next = Math.round(next / control.step) * control.step;
        return Math.max(control.min, Math.min(control.max, next));
    }

    // 双滑块的两个值（排好序）
    readonly property real lowValue: {
        const v = control.range && control.values !== null ? control.values : [];
        const a = v.length > 0 ? v[0] : control.min;
        const b = v.length > 1 ? v[1] : control.max;
        return Math.min(a, b);
    }

    readonly property real highValue: {
        const v = control.range && control.values !== null ? control.values : [];
        const a = v.length > 0 ? v[0] : control.min;
        const b = v.length > 1 ? v[1] : control.max;
        return Math.max(a, b);
    }

    readonly property real ratio: control.ratioOf(control.value)

    // ---- 填充 ----
    // 单值：从轨道的最小端画到手柄圆心；双滑块：画在两个手柄圆心之间
    readonly property real fillA: control.range
        ? control.axisPosOf(control.lowValue)
        : control.railStart + control.axisRatioOf(0) * control.railLength
    readonly property real fillB: control.range
        ? control.axisPosOf(control.highValue)
        : control.axisPosOf(control.value)
    readonly property real fillFrom: Math.min(control.fillA, control.fillB)
    readonly property real fillLength: control.included ? Math.abs(control.fillB - control.fillA) : 0

    // ---- 刻度 ----
    readonly property var markList: {
        const out = [];
        const src = control.marks;
        if (src === null || src === undefined)
            return out;
        for (let i = 0; i < src.length; ++i) {
            const m = src[i];
            if (m === undefined || m === null || m.value === undefined)
                continue;
            const v = m.value;
            if (v < control.min || v > control.max)
                continue;
            out.push({
                value: v,
                label: m.label === undefined ? String(v) : String(m.label),
                pos: control.axisPosOf(v)
            });
        }
        return out;
    }

    readonly property real marksHeight: control.markList.length === 0
        ? 0 : (control.showMarkLabel ? 26 : 10)
    readonly property real boundaryHeight: control.showBoundary ? 20 : 0

    // 手柄那一行（水平）/ 那一列（垂直）的中心。轨道和手柄只在这条线上居中 ——
    // 刻度与边界值是排在手柄之外的，组件整体被它们撑高了，
    // 拿整个尺寸去居中会把轨道推到标签上（表现是文字压在滑动条上）。
    readonly property real handleRowCenter: control.handleSize / 2
    // 刻度标签与上一行之间的间距
    readonly property int markGap: 5
    // 刻度标签那一段的起点（水平是 y、垂直是 x）。
    //
    // 挂在**手柄**下方而不是轨道下方：手柄比轨道高得多（24 vs 4），
    // 按轨道算出来的位置会让文字首行比手柄底边还高 4px，看着就是标签压在滑块上。
    // Semi 那边是照轨道算的（轨道底 18、标签顶 23），但它的手柄同样会盖到标签区，
    // 这里改成照手柄算，保证任何手柄尺寸下都不撞。
    readonly property real marksTop: control.handleRowCenter + control.handleSize / 2 + control.markGap

    implicitWidth: control.vertical
        ? (control.markList.length > 0 && control.showMarkLabel ? 72 : control.handleSize)
        : 240
    implicitHeight: control.vertical
        ? 240
        : control.handleSize + control.marksHeight + control.boundaryHeight

    // ---- 写入 ----
    onValueChanged: control.clampValue()
    onValuesChanged: control.clampValues()

    function clampValue() {
        const v = Math.max(control.min, Math.min(control.max, control.value));
        if (v !== control.value)
            control.value = v;
    }

    function clampValues() {
        const src = control.values;
        if (src === null || src === undefined || src.length === undefined || src.length === 0)
            return;
        let changed = false;
        const fixed = [];
        for (let i = 0; i < src.length; ++i) {
            const v = Math.max(control.min, Math.min(control.max, src[i]));
            fixed.push(v);
            if (v !== src[i])
                changed = true;
        }
        if (changed)
            control.values = fixed;
    }

    // 离给定沿轴坐标最近的那个手柄：0 = 低值端，1 = 高值端。
    // 平手取低值端，和官方 checkWhichHandle 的 distToFirst <= distToSecond 一致
    // （semi-foundation/slider/foundation.ts:815-829）。
    // 注意这个「最近」只用于**点轨道**（官方的 handleWrapClick）；
    // 按在手柄上时走下面的 pressHandle。
    function nearestHandle(pos) {
        if (!control.range)
            return 0;
        const dLow = Math.abs(pos - control.axisPosOf(control.lowValue));
        const dHigh = Math.abs(pos - control.axisPosOf(control.highValue));
        return dLow <= dHigh ? 0 : 1;
    }

    // pos 落不落在第 index 个手柄自己的方块里（官方手柄 24×24、translateX(-50%)，
    // slider.scss:45-60 + $width-slider_handle: 24px）
    function onHandleRect(pos, index) {
        const center = control.axisPosOf(control.handleValue(index));
        return Math.abs(pos - center) <= control.handleSize / 2;
    }

    // 指针落点是不是在手柄上（官方 isEventFromHandle，semi-ui/slider/index.tsx:176-189）
    function onHandle(pos) {
        if (control.range)
            return control.onHandleRect(pos, 0) || control.onHandleRect(pos, 1);
        return control.onHandleRect(pos, 0);
    }

    // 按下时该抓哪个手柄。官方不是按最近挑的，是按 DOM 层叠：mousedown 只会发给
    // 盖在最上面那颗手柄，而 range 分支给「上一次按下的那颗」z-index 2
    // （index.tsx:423 / :479，只看 chooseMovePos、不看 isDrag），
    // chooseMovePos 又只在 mousedown 里写、松手不重置（foundation.ts:507 对比 :594-611）。
    // 于是两颗手柄叠在一起时，鼠标永远落在上层，「谁最后动过来就继续拖谁」。
    function pressHandle(pos) {
        if (!control.range)
            return 0;
        const onLow = control.onHandleRect(pos, 0);
        const onHigh = control.onHandleRect(pos, 1);
        if (onLow && onHigh)
            return control.dragHandle;
        if (onHigh)
            return 1;
        if (onLow)
            return 0;
        return control.nearestHandle(pos);
    }

    // 第 index 个手柄当前的值（非双滑块时只有 0）
    function handleValue(index) {
        if (control.range)
            return index === 0 ? control.lowValue : control.highValue;
        return control.value;
    }

    // 把某个手柄挪到给定的沿轴坐标。双滑块时不越过另一个手柄。
    // 返回是否真的改了值。
    function applyAxisPos(pos, index) {
        const next = control.snap(control.valueOfAxisPos(pos));
        if (!control.range) {
            if (next === control.value)
                return false;
            control.value = next;
            control.moved(next);
            return true;
        }

        let a = control.lowValue;
        let b = control.highValue;
        if (index === 0)
            a = Math.min(next, b);
        else
            b = Math.max(next, a);
        if (a === control.lowValue && b === control.highValue)
            return false;
        control.values = [a, b];
        control.moved([a, b]);
        return true;
    }

    // 水平滑块用 x、垂直用 y
    function setFromX(x) {
        return control.applyAxisPos(x, control.nearestHandle(x));
    }

    function setFromY(y) {
        return control.applyAxisPos(y, control.nearestHandle(y));
    }

    // 拖动中的换算：把 centroid 的位置换成值，但**只在拖动进行中**。
    //
    // 不能无条件用 centroid.position：手势结束之后、或者抓取被别的 handler
    // （比如外层 Flickable 要滚动）抢走之后，它的 x/y 会被复位成 0，
    // 而那次复位同样会触发 onCentroidChanged。不挡住的话，一松手值就被算成 min，
    // 表现是「怎么拖最后都变成 0」。见 handlerPoint 文档：
    // "after the point is released ... position.x and position.y are 0"。
    function handleDragPosition(active, pos) {
        if (!active)
            return;
        control.applyAxisPos(pos - control.dragOffset, control.dragHandle);
    }

    // 上一次按下的手柄（0 = 低值端、1 = 高值端），松手之后不清空。
    //
    // 官方没有这个变量，它是靠 z-index 层叠实现的：chooseMovePos 只在 mousedown 写、
    // mouseup 不重置，两颗手柄叠在一起时上层就是上一次拖的那颗。
    // 这里把它显式存下来：既供重叠时的抓取判定（pressHandle），也驱动绘制层叠
    // （两颗手柄的 z 按它互斥抬到 1 / 0，投影精灵跟着手柄走）。
    //
    // 缺省 1 = 官方 chooseMovePos 初值为 ''（两颗都 z-index 1）时的层叠结果：
    // DOM 里 max 排在 min 之后，所以后画的 max 盖在上面（index.tsx:410-501）。
    property int dragHandle: 1
    // 按下点与被抓手柄圆心的差（官方 _dragOffset，foundation.ts:514-522）。
    // 点在手柄上时手柄带着这个差跟随指针、不会跳到指针底下；点轨道拖时差为 0。
    property real dragOffset: 0

    // ------------------------------------------------------------------
    // 轨道
    // ------------------------------------------------------------------
    Rectangle {
        id: railItem

        x: control.vertical ? control.handleRowCenter - width / 2 : control.railStart
        y: control.vertical ? control.railStart : control.handleRowCenter - height / 2
        width: control.vertical ? control.trackHeight : control.railLength
        height: control.vertical ? control.railLength : control.trackHeight
        radius: height / 2
        color: Appearance.progressRail(Theme.current)
        gradient: control.railGradient

        // 已填充
        Rectangle {
            x: control.vertical ? 0 : control.fillFrom - control.railStart
            y: control.vertical ? control.fillFrom - control.railStart : 0
            width: control.vertical ? parent.width : control.fillLength
            height: control.vertical ? control.fillLength : parent.height
            radius: height / 2
            // 禁用态照 Semi 的 $color-slider_track_disabled-bg，
            // 是 primary-disabled（blue-2 那档浅蓝），不是通用的 disabledBg
            color: control.enabled
                ? Theme.current.colorPrimary
                : Theme.current.colorPrimaryDisabled
        }
    }

    // ------------------------------------------------------------------
    // 刻度
    // ------------------------------------------------------------------
    // 刻度点：骑在轨道中线上
    Repeater {
        model: control.markList

        delegate: Rectangle {
            id: markDot

            required property var modelData

            x: control.vertical
                ? control.handleRowCenter - width / 2
                : markDot.modelData.pos - width / 2
            y: control.vertical
                ? markDot.modelData.pos - height / 2
                : control.handleRowCenter - height / 2
            width: control.dotSize
            height: control.dotSize
            radius: width / 2
            color: Theme.current.colorWhite          // $color-slider_dot-bg-default
            // 禁用态 Semi 只把刻度点的 cursor / shadow 改掉，点是留着的

            // tooltipOnMark 才建 Tooltip：每个刻度一个 Popup，没必要常驻。
            // 官方这一处就是裸的 <Tooltip content={marks[mark]}>{dotDOM}</Tooltip>
            // （slider/index.tsx:586），五档延迟、方位全走缺省。
            Loader {
                active: control.tooltipOnMark
                sourceComponent: Tooltip {
                    target: markDot
                    text: markDot.modelData.label
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 手柄投影：渲一次，之后只平移
    // ------------------------------------------------------------------
    // 投影的形状是固定的（一个带投影的白圆），拖动时只有位置在变。所以把它渲成
    // 一张纹理，两个手柄各用一个 ShaderEffectSource 平移过去 —— 拖动时不再逐帧
    // 重算模糊。MultiEffect 的文档专门提醒过：别让会动的控件当源，否则每帧都要
    // 重新生成模糊。实测 8 个双滑块一起动：直接画的最长帧 33.1ms（掉帧），
    // 换成底片后 23.3ms。
    //
    // 规格来自 Semi 的 @mixin shadow-knob（semi-theme-default/scss/mixin.scss:14-16）：
    //
    //     box-shadow: 0 4px 6px rgba(0,0,0,.1), 0 0 1px rgba(0,0,0,.3)
    //
    // 两层都要照画。官方那只圆是 `border: none`（slider.scss:56），外圈那道贴着边缘的
    // 细线是**第二层 1px 模糊的投影**、不是描边 —— 描边只有 -handle-clicked（1px 主色）
    // 和 -disabled（1px colorBorder，且此时 shadow-0）两种状态才有。
    //
    // blurMax / shadowBlur 不是 CSS 的那两个数：CSS 的 blur radius 是 2σ（6px ↔ σ=3），
    // Qt 这边 blurMax 是卷积核半径、shadowBlur 再按 mip 层数打折，模糊宽度还跟着底片
    // 尺寸走（= 圆径 + 2*blurMax），所以只能实测标定。标定表 24 个参数组逐个扫
    // 上/下两条轴（0..14px、半步长），按最小二乘挑最贴的：
    //   软层 σ=3 → blurMax 20 + shadowBlur 1.0（残差 RMS 2.8 / 255；24 与它并列，选 20 是底片更小）
    //   细圈 σ=0.5 → blurMax 1 + shadowBlur 0.5（残差 RMS 1.5 / 255）
    // 两个 α 都直接用令牌的 .1 / .3，拟合出来的最优 α 是 .094 / .235，差在肉眼看不出
    // 的量级上，不为它改令牌。
    readonly property int shadowPad: 20      // 底片余量 = 软层的 blurMax，再多就裁掉投影尾巴了

    Item {
        id: shadowBaker

        width: control.handleSize
        height: control.handleSize

        // 第二层（CSS 写在后面 = 画在下面）：0 0 1px rgba(0,0,0,.3)，一圈贴边的细线
        Rectangle {
            id: ringSeed

            anchors.fill: parent
            radius: width / 2
            color: Theme.current.colorWhite
        }

        MultiEffect {
            source: ringSeed
            anchors.fill: ringSeed
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.3)
            shadowBlur: 0.5
            blurMax: 1
        }

        // 第一层：0 4px 6px rgba(0,0,0,.1)
        Rectangle {
            id: softSeed

            anchors.fill: parent
            radius: width / 2
            color: Theme.current.colorWhite
        }

        MultiEffect {
            source: softSeed
            anchors.fill: softSeed
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.1)
            shadowVerticalOffset: 4
            shadowBlur: 1.0
            blurMax: 20
        }
    }

    // 两个手柄共用这张底片。hideSource 把底片本身（连同里面的效果项）隐掉，
    // 只留纹理；live: false 表示只渲一次，之后移动它不触发重算。
    ShaderEffectSource {
        id: shadowSprite

        sourceItem: shadowBaker
        sourceRect: Qt.rect(-control.shadowPad, -control.shadowPad,
                            control.handleSize + control.shadowPad * 2,
                            control.handleSize + control.shadowPad * 2)
        recursive: true
        hideSource: true
        live: false
        width: control.handleSize + control.shadowPad * 2
        height: width
        x: handleItem.x - control.shadowPad
        y: handleItem.y - control.shadowPad
        // 与手柄同步抬层叠：重合时上层那颗的投影也得在下面那颗之上
        z: handleItem.z
        // 禁用态没有投影：Semi 在 -disabled 下把 shadow-knob 换成了 shadow-0
        visible: control.enabled
    }

    ShaderEffectSource {
        id: shadowSpriteEnd

        sourceItem: shadowBaker
        sourceRect: shadowSprite.sourceRect
        recursive: true
        hideSource: false
        live: false
        width: shadowSprite.width
        height: shadowSprite.height
        x: handleItemEnd.x - control.shadowPad
        y: handleItemEnd.y - control.shadowPad
        z: handleItemEnd.z
        visible: control.enabled && control.range
    }

    // 刻度标签：按刻度位置居中（Semi 那边是 translate(-50%, 0)）。
    // 必须排在投影**之后**：官方 DOM 里 marks 的 label 就在 handle 后面
    // （slider/index.tsx:671-672 renderHandle → renderLabel），所以投影压不住它。
    Repeater {
        model: control.showMarkLabel ? control.markList : []

        delegate: Text {
            id: markLabel

            required property var modelData

            text: markLabel.modelData.label
            color: Theme.current.colorText2          // $color-slider_mark-text-default
            font.pixelSize: Theme.current.fontSizeRegular
            x: control.vertical
                ? control.marksTop + 3
                : markLabel.modelData.pos - width / 2
            y: control.vertical
                ? markLabel.modelData.pos - height / 2
                : control.marksTop
        }
    }

    // ------------------------------------------------------------------
    // 手柄
    // ------------------------------------------------------------------
    Rectangle {
        id: handleItem

        readonly property real pos: control.axisPosOf(control.range
            ? control.lowValue : control.value)

        // 与 pressHandle 同一套归属：上一次按下的那颗抬到 z=1，另一颗沉到 0。
        // dragHandle 缺省 1 ⇒ 谁也没拖过时高值端在上（对应官方 DOM 里 max 后画）。
        // 不绑 dragHandler.active —— 官方 z-index 松手也不降，重合时才能继续看出归谁。
        z: control.range && control.dragHandle === 0 ? 1 : 0

        x: control.vertical ? control.handleRowCenter - width / 2 : pos - width / 2
        y: control.vertical ? pos - height / 2 : control.handleRowCenter - height / 2
        width: control.handleSize
        height: control.handleSize
        radius: width / 2
        color: Theme.current.colorWhite          // $color-slider_handle-bg-default
        // 静止态没有描边（shadow-knob 那圈细线由上面的底片出）。只有两种状态才有：
        // -handle-clicked → 1px 主色（$width-slider_handle_clicked），
        // -disabled → 1px colorBorder（且此时 shadow-0，见上面 sprite 的 visible）。
        // 悬停态官方是 `background-color: white`，也就是没有视觉变化，别在这加描边。
        readonly property bool clicked: dragHandler.active && control.dragHandle === 0

        border.width: (clicked || !control.enabled) ? 1 : 0
        border.color: clicked
            ? Theme.current.colorFocusBorder     // $color-slider_handle-border-focus
            : Theme.current.colorBorder          // $color-slider_handle_disabled-border

        Behavior on border.color {
            ColorAnimation { duration: Theme.current.durationFast }
        }

        // 手柄中心的圆点（$color-slider_handle_dot / $width-slider_handle_dot）
        Rectangle {
            anchors.centerIn: parent
            width: control.dotFor(0).size
            height: width
            radius: width / 2
            color: control.dotFor(0).color
            visible: control.handleDot !== null
        }
    }

    // 双滑块的第二个手柄
    Rectangle {
        id: handleItemEnd

        readonly property real pos: control.axisPosOf(control.highValue)

        visible: control.range
        // 与 handleItem.z 互斥：dragHandle===1 时高值端在上，否则沉在低值端下面
        z: control.range && control.dragHandle === 1 ? 1 : 0
        x: control.vertical ? control.handleRowCenter - width / 2 : pos - width / 2
        y: control.vertical ? pos - height / 2 : control.handleRowCenter - height / 2
        width: control.handleSize
        height: control.handleSize
        radius: width / 2
        color: Theme.current.colorWhite

        readonly property bool clicked: dragHandler.active && control.dragHandle === 1

        border.width: (clicked || !control.enabled) ? 1 : 0
        border.color: clicked
            ? Theme.current.colorFocusBorder
            : Theme.current.colorBorder

        Behavior on border.color {
            ColorAnimation { duration: Theme.current.durationFast }
        }

        Rectangle {
            anchors.centerIn: parent
            width: control.dotFor(1).size
            height: width
            radius: width / 2
            color: control.dotFor(1).color
            visible: control.handleDot !== null
        }
    }

    // handleDot 允许 { … }（两个手柄一样）或 [{ … }, { … }]（分别指定）
    function dotFor(index) {
        const spec = control.handleDot;
        const fallback = { size: control.dotSize, color: Theme.current.colorPrimary };
        if (spec === null || spec === undefined)
            return fallback;
        const one = spec.length !== undefined ? spec[index] : spec;
        if (one === undefined || one === null)
            return fallback;
        return {
            size: one.size === undefined ? control.dotSize : one.size,
            color: one.color === undefined ? Theme.current.colorPrimary : one.color
        };
    }

    // ------------------------------------------------------------------
    // 数值提示
    // ------------------------------------------------------------------
    // 显示时机照 Semi 的 computeHandleVisibleVal：showValue 常显；
    // 否则只有给了 tipFormatter 时才在拖动中显示。
    readonly property bool bubbleVisible: control.showValue
        || (typeof control.tipFormatter === "function" && dragHandler.active)

    readonly property var bubbleValues: {
        if (!control.bubbleVisible)
            return [];
        if (!control.range)
            return [control.value];
        if (dragHandler.active)
            return [control.dragHandle === 0 ? control.lowValue : control.highValue];
        return [control.lowValue, control.highValue];
    }

    Repeater {
        model: control.bubbleValues

        delegate: Rectangle {
            id: valueBubble

            required property var modelData

            readonly property real anchorPos: control.axisPosOf(valueBubble.modelData)

            x: Math.max(0, Math.min(parent.width - width, anchorPos - width / 2))
            anchors.bottom: parent.top
            anchors.bottomMargin: 2
            width: bubbleLabel.implicitWidth + Theme.current.spacingTight
            height: bubbleLabel.implicitHeight + Theme.current.spacingExtraTight
            radius: Theme.current.radiusSmall
            color: Theme.current.grey[7]

            Text {
                id: bubbleLabel

                anchors.centerIn: parent
                text: control.formatValue(valueBubble.modelData)
                color: Theme.current.colorBg0
                font.pixelSize: Theme.current.fontSizeSmall
            }
        }
    }

    function formatValue(v) {
        if (typeof control.tipFormatter === "function")
            return String(control.tipFormatter(v));
        return v.toFixed(0) + control.suffix;
    }

    // ------------------------------------------------------------------
    // 两端边界值（悬停显示）
    // ------------------------------------------------------------------
    Text {
        visible: control.showBoundary && handleHover.hovered
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: control.handleSize + control.marksHeight
        text: control.formatValue(control.min)
        color: Theme.current.colorText0
        font.pixelSize: Theme.current.fontSizeSmall
    }

    Text {
        visible: control.showBoundary && handleHover.hovered
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: control.handleSize + control.marksHeight
        text: control.formatValue(control.max)
        color: Theme.current.colorText0
        font.pixelSize: Theme.current.fontSizeSmall
    }

    // ------------------------------------------------------------------
    // 交互
    // ------------------------------------------------------------------
    HoverHandler {
        id: handleHover
        enabled: control.enabled
    }

    TapHandler {
        enabled: control.enabled

        // 对应官方的 handleWrapClick，它挂在轨道/刻度这些**非手柄**节点上，
        // 事件源是手柄时直接 return（foundation.ts:774-778）。
        // 所以单击手柄不改值 —— 早先这里会把最近的手柄拽到点击点上，
        // 点在手柄边缘值就跳几格；双滑块重叠时更糟，点一下就把低值端拖走了。
        onTapped: (eventPoint) => {
            const pos = control.vertical ? eventPoint.position.y : eventPoint.position.x;
            if (control.onHandle(pos))
                return;
            if (control.applyAxisPos(pos, control.nearestHandle(pos)))
                control.afterChange(control.range ? [control.lowValue, control.highValue] : control.value);
        }
    }

    DragHandler {
        id: dragHandler

        enabled: control.enabled
        target: null
        xAxis.enabled: !control.vertical
        yAxis.enabled: control.vertical

        onActiveChanged: {
            if (active) {
                // 用「按下点」而不是当前点来挑手柄：拖动要过了阈值才激活，
                // 那时当前点已经跑开了
                const press = control.vertical
                    ? centroid.pressPosition.y : centroid.pressPosition.x;
                control.dragHandle = control.pressHandle(press);
                control.dragOffset = control.onHandle(press)
                    ? press - control.axisPosOf(control.handleValue(control.dragHandle)) : 0;
            } else {
                control.afterChange(control.range
                    ? [control.lowValue, control.highValue] : control.value);
            }
        }

        onCentroidChanged: control.handleDragPosition(dragHandler.active,
            control.vertical ? centroid.position.y : centroid.position.x)
    }
}
