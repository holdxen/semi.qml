pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Semi
import "ProgressStroke.js" as Stroke

// Progress 进度条 —— 官方 semi-ui/progress/index.tsx 的两形态（条状 / 环形）。
//
// 层级对应：
//   control            = .semi-progress（条状）或 .semi-progress-circle（环形的根，注意它没有 .semi-progress 类）
//   track / inner      = .semi-progress-track / -track-inner
//   info               = .semi-progress-line-text / -circle-text
//   ring / orbitPath / arcPath = svg.semi-progress-circle-ring 与它的两个 <circle>
//
// 几何全部照 semi-foundation/progress/{progress.scss,variables.scss} 与 index.tsx 的算式，
// 并用浏览器实测对过数（harness：tests/tmp_progress_dom.html）：
//   · 条状横：高 4（large 6）、上下各 4 外边距（外边距不在盒子里，交给布局）、轨道圆角 3；
//     百分比文本 min-width 45、左外边距 16、字重 600、色 text-0，**容器高度仍是 4**，
//     文本靠 align-items:center 溢出上下 —— 轨道因此被挤成 width - 45 - 16（实测 200 宽时轨道 139）；
//   · 条状竖：宽 4（large 6）、左右各 4 外边距、flex-direction: column，
//     进度块从轨道**顶部往下**长（官方就是这个方向），文本在下方、上外边距 8、水平居中且会溢出那 4px；
//   · 环形：直径 width 给了就用，否则 default 72 / 其余 24；半径 = (直径 - strokeWidth) / 2、
//     圆心 = 直径 / 2、周长 = 2πr；官方用 stroke-dasharray="C C" + dashoffset=(1-p/100)C +
//     rotate(-90deg) 表达同一段弧，本端口直接画弧：startAngle -90、sweepAngle = p * 3.6；
//     不确定态改成固定 30% 弧（官方 dasharray = 0.3C C）并把 -90 的起手去掉、整圈 1.2s 线性转；
//   · 环形文本 400 字重、条状文本 600 字重，两处官方都没写 font-size（继承 body，本端口取基准 14）。
//
// 动画：宽度 / 弧长走 300ms 的 $motion-progress-transition_timing_function
// = cubic-bezier(.62,.05,.36,.95)。Qt 的 Easing.BezierSpline 在这台机器上退化成线性（坑 50），
// 按解析拟合挑最接近的内置曲线是 InOutCubic（最大偏差 0.030、RMS 0.020，脚本
// /tmp/semi_ref/prog/ease_fit.py）。中间那个百分比数字是另一套：官方用 semi-animation 以
// **linear 300ms** 补间、每帧 parseInt 取整、rest 时落回精确值 —— 所以动画中显示截断值、
// 停下来显示原值。不确定态的滑块位移是 ease-in-out 1.6s，0%→-120%、55%→300%、100%→300%
// （百分比相对滑块自身宽度），曲线拟合成 InOutQuad（0.012，与 Switch 那条同一档）。
//
// 与官方对齐的语义：
//   · percent 夹到 0..100 只影响**画多少**；stroke 档位查表用的是**原始 percent**
//     （官方 selectStroke 传的是 this.props.percent），所以 150 拿最后一档、-5 拿默认色；
//   · stroke 给字符串直接当颜色用；给 [{percent, color}] 时按档位挑一个**纯色**，
//     strokeGradient 为真时在相邻两档之间再插值出一个纯色（官方不是空间渐变，整条换一个色）；
//   · indeterminate 打开后 percent 不再控制长度、文本不显示、aria-valuenow 省略；
//   · showInfo 在环形上还多一条 size !== 'small'，小号环形的中心文字官方一律不画；
//   · size 只对相应形态生效：small 只影响环形（直径 24、不画文字），large 只影响条状（4→6）。
//
// 有意差异（逐条对）：
//   · 官方 width 这个 prop 名在 QML 里是 FINAL 的 Item.width（坑 83 同一族），改叫 circleWidth；
//     id / className / style / motion 的 ReactNode 形式不收；
//   · stroke 字符串只支持纯色，官方那条 `background: linear-gradient(...)` 在条状上能画空间渐变，
//     QML 的 Rectangle.color 画不了，需要渐变请直接用 Rectangle.gradient 自己铺；
//   · aria-valuenow / min / max 在 QML 侧没有对应接口（Accessible 只暴露 role/name/description/
//     labelledBy/labelFor，qquickaccessibleattached_p.h:56-62），所以数值只能靠
//     readonly 属性给测试与使用者读；aria-valuetext 落到 Accessible.description；
//   · 官方 format 的 propTypes 允许直接给节点，本端口只收函数（给节点会在官方自己那行
//     format(percNumber) 处抛异常）；
//   · percent 给 NaN 官方在 componentDidUpdate 里抛 Error，这里退化成 0；
//   · 官方 size 落到环形是「default → 72，**其余一律 24**」，所以 size="large" 的环形只有 24，
//     这是上游算式的结果，照抄不修；
//   · 条状文本颜色官方只在 -horizontal 那档声明，-vertical 档漏了（继承 body 色），
//     本端口两档都用 text-0。
Item {
    id: control

    // ---------------------------------------------------------------- ProgressProps
    property real percent: 0
    property string type: "line"                      // line | circle
    property string size: "default"                   // default | small | large
    property string direction: "horizontal"           // horizontal | vertical
    property var stroke: null                         // 颜色串 或 [{percent, color}]
    property bool strokeGradient: false
    property string strokeLinecap: "round"            // round | square（只作用在环形上）
    property real strokeWidth: 4                      // 只作用在环形上
    property var orbitStroke: null                    // 轨道色，没给走 colorFill0
    property bool showInfo: false
    property var format: null                         // function (percent) => string
    property bool indeterminate: false
    property bool motion: true
    property real circleWidth: 0                      // 官方 width：Item.width 是 FINAL，改名
    property string ariaLabel: ""
    property string ariaValueText: ""
    property Item ariaLabelledBy: null

    // 官方 state.percentNumber：数字补间的那一份
    property real numberShown: 0
    // 宽度 / 弧长的补间量（CSS transition 的替身，不受 motion 开关影响）。
    // 用绑定而不是在 onCompleted 里赋值：Behavior 在组件初始化那一次不落动画，
    // 官方首次渲染也没有 transition。
    property real shownPercent: control.clamped
    // 不确定态滑块位置，按滑块自身宽度的倍数算（官方 -120% → 300%）
    property real slideRatio: -1.2
    property real spinAngle: 0

    readonly property bool circle: control.type === "circle"
    readonly property bool vertical: !control.circle && control.direction === "vertical"
    // $height-progress_horizontal[_large] / $width-progress_vertical[_large]
    readonly property real thickness: control.size === "large" ? 6 : 4
    readonly property real diameter: control.circle
        ? (control.circleWidth > 0 ? control.circleWidth : (control.size === "default" ? 72 : 24))
        : 0
    readonly property real clamped: control.calcPercent(control.percent)
    readonly property real radius: control.circle ? Math.max(0, (control.diameter - control.strokeWidth) / 2) : 0
    readonly property real circumference: control.radius * 2 * Math.PI
    readonly property real sweepAngle: control.indeterminate
        ? 360 * 0.3                                   // 官方 dasharray 取 0.3 个周长
        : control.shownPercent * 3.6
    readonly property int capStyle: control.strokeLinecap === "square"
        ? ShapePath.SquareCap : ShapePath.RoundCap

    // 官方：环形 showInfo && size !== 'small' && !indeterminate；条状 showInfo && !indeterminate
    readonly property bool infoShown: control.showInfo && !control.indeterminate
        && (!control.circle || control.size !== "small")
    readonly property real textNatural: control.infoShown ? info.implicitWidth : 0
    readonly property real textHeight: control.infoShown ? info.implicitHeight : 0
    // 横条的文本框是 min-width 45 的 flex 项，轨道被挤掉「文本宽 + 16」
    readonly property real textBand: control.infoShown && !control.circle && !control.vertical
        ? Math.max(45, control.textNatural) : 0
    readonly property real trackWidth: control.circle ? control.diameter
        : (control.vertical ? control.width
            : Math.max(0, control.width - control.textBand - (control.textBand > 0 ? 16 : 0)))
    // 条状的盒子高度就是轨道高度：官方 .semi-progress-horizontal { height: 4px } 是普通声明，
    // 示例里那句 style={{ height: '8px' }} 直接把它盖掉，所以「自定义高度」走的是控件自己的
    // height —— 这里不写死 thickness，而是吃 control.height（没给时 implicitHeight 已经是 4/6）。
    readonly property real trackHeight: control.circle ? control.diameter
        : (control.vertical
            ? Math.max(0, control.height - control.textHeight - (control.textHeight > 0 ? 8 : 0))
            : control.height)

    readonly property color orbitColor: control.orbitStroke === undefined || control.orbitStroke === null
        ? Theme.current.colorFill0
        : control.cssColor(String(control.orbitStroke), Theme.current.colorFill0)
    readonly property color fillColor: control.fillOf()

    // 数字动画中显示截断值、停下来显示精确值（官方 frame 里 parseInt、rest 里回写 percent）
    readonly property real numberValue: numberAnim.running
        ? control.calcPercent(Math.trunc(control.numberShown))
        : control.calcPercent(control.percent)
    readonly property string infoText: control.textOf(control.numberValue)

    implicitWidth: control.circle ? control.diameter : (control.vertical ? control.thickness : 0)
    implicitHeight: control.circle ? control.diameter : (control.vertical ? 0 : control.thickness)

    Accessible.role: Accessible.ProgressBar
    Accessible.name: control.ariaLabel
    Accessible.description: control.ariaValueText
    // labelledBy 不能用绑定：Qt 侧的 setter 见到 nullptr 就 qmlWarning 并直接 return
    // （qquickaccessibleattached_p.h:146-159），而且每次重新求值都会往 m_relations 追加一份。
    // 所以只在真的给了节点时写一次；写回 null 清不掉关系（官方这时会摘掉 aria-labelledby 属性）。
    onAriaLabelledByChanged: {
        if (control.ariaLabelledBy !== null)
            control.Accessible.labelledBy = control.ariaLabelledBy
    }

    // 官方在构造函数里就把 percentNumber 初始化成 props.percent，首次渲染不参与补间。
    // QML 侧对象定义里的 percent: 25 会走一次 percentChanged，所以拿这个开关把创建那一次挡掉。
    property bool _started: false

    Component.onCompleted: {
        control.numberShown = control.percent;
        control._started = true;
    }

    onPercentChanged: {
        // 创建过程里的那一次只挡掉补间，值本身交给 Component.onCompleted（官方构造函数那一行）
        if (!control._started)
            return;
        if (!control.motion) {
            control.numberShown = control.percent;
            return;
        }
        numberAnim.from = control.numberShown;
        numberAnim.to = control.percent;
        numberAnim.start();
    }

    // 宽度 / 弧长的补间：官方是 CSS transition，与 motion 开关无关
    Behavior on shownPercent {
        NumberAnimation {
            duration: 300
            easing.type: Easing.InOutCubic        // ≈ cubic-bezier(.62,.05,.36,.95)，见文件头
        }
    }

    NumberAnimation {
        id: numberAnim

        target: control
        property: "numberShown"
        duration: 300
        easing.type: Easing.Linear
    }

    // 不确定态：横条滑块 1.6s 一轮，0%→-120%、55%→300%、100%→300%
    SequentialAnimation {
        id: slideAnim

        loops: Animation.Infinite
        running: control.indeterminate && control.visible && !control.circle
        NumberAnimation {
            target: control
            property: "slideRatio"
            from: -1.2
            to: 3.0
            duration: 880
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: control
            property: "slideRatio"
            from: 3.0
            to: 3.0
            duration: 720
        }
    }

    // 不确定态：环形整圈 1.2s 线性转
    NumberAnimation {
        id: spinAnim

        target: control
        property: "spinAngle"
        from: 0
        to: 360
        duration: 1200
        loops: Animation.Infinite
        easing.type: Easing.Linear
        running: control.indeterminate && control.visible && control.circle
    }

    // ---------------------------------------------------------------- 条状
    Item {
        id: track

        objectName: "progressTrack"
        visible: !control.circle
        clip: true                                  // 官方 .semi-progress-track { overflow: hidden }
        x: 0
        y: 0                                        // 横条：盒子即轨道；竖条：轨道在上、文本在下
        width: control.trackWidth
        height: control.trackHeight

        Rectangle {
            id: rail

            objectName: "progressRail"
            anchors.fill: parent
            radius: Theme.current.radiusSmall       // $radius-progress_track = border-radius-small
            color: control.orbitColor
        }

        Rectangle {
            id: inner

            objectName: "progressInner"
            // 竖条从轨道顶部往下长（官方 flex-direction: column 的第一格就是它）。
            // 不确定态的位移是 CSS transform: translate(-120% → 300%)，百分比按滑块自身尺寸算，
            // 这里直接用 x/y 表达同一件事（轨道 clip 着，所以越界部分不外漏）。
            x: control.vertical ? 0
                : (control.indeterminate ? control.slideRatio * width : 0)
            y: control.vertical
                ? (control.indeterminate ? control.slideRatio * height : 0) : 0
            width: control.indeterminate
                ? (control.vertical ? parent.width : parent.width * 0.35)
                : (control.vertical ? parent.width : parent.width * control.shownPercent / 100)
            height: control.indeterminate
                ? (control.vertical ? parent.height * 0.35 : parent.height)
                : (control.vertical ? parent.height * control.shownPercent / 100 : parent.height)
            radius: Theme.current.radiusSmall       // $radius-progress_track_inner
            color: control.fillColor
        }
    }

    // ---------------------------------------------------------------- 环形
    Shape {
        id: ring

        objectName: "progressRing"
        visible: control.circle
        width: control.diameter
        height: control.diameter
        // Qt 6.11 起 Shape 的 renderStrategy 没了，换成 preferredRendererType，而默认那一档
        // GeometryRenderer 把弧折成一段段短直线、边缘**不做混合**，Item.antialiasing 对它无效。
        // 实测（120px / 12 笔画，tests/tmp_progress_ring_shot.qml + tmp_ring_measure.py）：
        // 默认档 0 个边缘过渡像素、内沿 283 个角度只落在 10 个半径值上；CurveRenderer 766 / 64。
        preferredRendererType: Shape.CurveRenderer

        transform: Rotation {
            origin.x: control.diameter / 2
            origin.y: control.diameter / 2
            angle: control.indeterminate ? control.spinAngle : 0
        }

        ShapePath {
            id: orbitPath

            objectName: "orbitPath"
            fillColor: "transparent"
            strokeColor: control.orbitColor
            strokeWidth: control.strokeWidth
            capStyle: control.capStyle

            PathAngleArc {
                objectName: "orbitArc"
                centerX: control.diameter / 2
                centerY: control.diameter / 2
                radiusX: control.radius
                radiusY: control.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            id: arcPath

            objectName: "arcPath"
            fillColor: "transparent"
            strokeColor: control.fillColor
            strokeWidth: control.strokeWidth
            capStyle: control.capStyle

            PathAngleArc {
                objectName: "innerArc"
                centerX: control.diameter / 2
                centerY: control.diameter / 2
                radiusX: control.radius
                radiusY: control.radius
                startAngle: control.indeterminate ? 0 : -90
                sweepAngle: control.sweepAngle
            }
        }
    }

    // ---------------------------------------------------------------- 百分比文本
    Text {
        id: info

        objectName: "progressInfo"
        visible: control.infoShown
        text: control.infoText
        font.pixelSize: Theme.current.fontSizeRegular   // 官方不写 font-size，继承 body ⇒ 取基准 14
        font.weight: control.circle ? Font.Normal : Font.DemiBold
        color: Theme.current.colorText0
        horizontalAlignment: control.circle ? Text.AlignHCenter : Text.AlignLeft

        // 环形：绝对定位居中、宽 100%；横条：贴轨道右侧、垂直溢出居中；竖条：贴在下方、水平居中
        x: control.circle ? 0 : (control.vertical
                ? (control.width - width) / 2
                : control.trackWidth + 16)
        y: control.circle ? (control.diameter - height) / 2
            : (control.vertical ? control.trackHeight + 8 : (control.height - height) / 2)
        width: control.circle ? control.diameter
            : (control.vertical ? implicitWidth : control.textBand)
    }

    // ---------------------------------------------------------------- 取色与令牌
    // 官方 stroke 的数组那一档：除了 QML 里写 `[...]`（真 JS 数组），从 QVariantMap 传进来的
    // 值是 list-like 对象 —— Array.isArray 为 false，但 length 与下标都能用，这里一并认。
    function isStrokeList(value) {
        if (Array.isArray(value))
            return true;
        return value !== null && typeof value === "object" && typeof value.length === "number";
    }

    function fillOf() {
        const raw = control.stroke;
        if (raw === undefined || raw === null || raw === "")
            return Theme.current.colorSuccess;          // $color-progress_track_inner-bg
        if (typeof raw === "string")
            return control.cssColor(raw, Theme.current.colorSuccess);
        if (control.isStrokeList(raw)) {
            const picked = Stroke.strokeColor(raw, control.percent, control.strokeGradient,
                function (text) {
                    return control.resolveToken(text);
                });
            if (picked === null)
                return Theme.current.colorSuccess;      // 官方 STROKE_DEFAULT 那一支
            return picked;
        }
        return Theme.current.colorSuccess;
    }

    function cssColor(text, fallback) {
        const rgba = Stroke.toRgba(text, function (name) {
            return control.resolveToken(name);
        });
        return rgba === null ? fallback : Stroke.hexText(rgba);
    }

    // 官方 formatToHex 里那套「Semi Design Token」查表：色阶名走 --semi-<family>-<级>，
    // 裸色名（red / orange）走第 5 档，black / white 是单值。
    function resolveToken(text) {
        let name = String(text).trim().toLowerCase();
        const wrap = /^var\(\s*([^)]*?)\s*\)$/.exec(name);
        if (wrap !== null)
            name = wrap[1];
        if (name.indexOf("--semi-") === 0)
            name = name.slice(7);
        else if (name.indexOf("--") === 0)
            name = name.slice(2);

        if (name === "black")
            return channels(Theme.current.colorBlack);
        if (name === "white")
            return channels(Theme.current.colorWhite);
        if (name.indexOf("color-") === 0) {
            const value = Theme.current[control.camelOf(name)];
            if (value !== undefined && value.r !== undefined)
                return channels(value);
            return null;
        }
        const dash = name.lastIndexOf("-");
        const tail = dash > 0 ? name.slice(dash + 1) : "";
        if (tail >= "0" && tail <= "9" && dash > 0) {
            const family = control.camelOf(name.slice(0, dash));
            if (control.families.indexOf(family) >= 0) {
                const list = Theme.current[family];
                if (list !== undefined)
                    return channels(list[parseInt(tail, 10)]);
            }
            return null;
        }
        if (control.families.indexOf(name) >= 0) {
            const list = Theme.current[name];
            if (list !== undefined)
                return channels(list[5]);
        }
        return null;
    }

    function channels(value) {
        return [value.r * 255, value.g * 255, value.b * 255, value.a * 255];
    }

    function camelOf(name) {
        const parts = String(name).split("-");
        let out = parts[0];
        for (let i = 1; i < parts.length; ++i)
            out += parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        return out;
    }

    readonly property var families: ["amber", "blue", "cyan", "green", "grey", "indigo",
        "lightBlue", "lightGreen", "lime", "orange", "pink", "purple", "red", "teal", "violet",
        "yellow"]

    function calcPercent(value) {
        if (isNaN(value))
            return 0;
        if (value > 100)
            return 100;
        if (value < 0)
            return 0;
        return value;
    }

    function textOf(value) {
        if (typeof control.format === "function")
            return String(control.format(value));
        return value + "%";
    }
}
