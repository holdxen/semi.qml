import QtQuick
import QtQuick.Effects

// 开关。几何、配色、动画全部照 packages/semi-foundation/switch/：
//   switch.scss     结构与 transition
//   variables.scss  三档尺寸、位移、按压延展
//   animation.scss  背景色 200ms / ease-in
Item {
    id: control

    property bool checked: false
    // 加载中：圆钮换成 Spin，且不再响应点击（官网是把 native input 一起 disabled）
    property bool loading: false
    // 轨道内嵌文案。Semi 的 API 是 checkedText / uncheckedText，没有外部 label 属性
    // （官网：更推荐把文本说明放在 Switch 外部）。size 为 small 时不显示。
    property string checkedText: ""
    property string uncheckedText: ""
    property int size: Enums.Default

    signal toggled

    readonly property int controlState: Appearance.state(control.enabled, hover.hovered, pointer.pressed)
    // $width-switch_knob_active = 默认宽 + expand，选中态按下时左缘同步回退
    readonly property bool knobExpanded: control.controlState === Enums.Pressed

    // $border-thickness-control：常态也有一条 1px 透明描边，圆钮是相对它的 padding box 定位的，
    // 所以左右上下的留白 = 描边 + $spacing-switch_knob-padding，三档分别是 3 / 2 / 4。
    readonly property int borderThickness: 1

    // small 26×16 / default 40×24 / large 54×32
    readonly property int trackWidth: control.size === Enums.Small ? 26 : control.size === Enums.Large ? 54 : 40
    readonly property int trackHeight: control.size === Enums.Small ? 16 : control.size === Enums.Large ? 32 : 24
    // $width-switch_knob_default / _large / _large_small
    readonly property int knobSize: control.size === Enums.Small ? 12 : control.size === Enums.Large ? 24 : 18
    // $spacing-switch_knob-padding / _large / _small
    readonly property int knobPadding: control.size === Enums.Small ? 1 : control.size === Enums.Large ? 3 : 2
    // $spacing-switch_unchecked/checked-translateX（圆钮 left 是 0，位移全靠 translateX）
    readonly property int travelUnchecked: control.size === Enums.Small ? 1 : control.size === Enums.Large ? 3 : 2
    readonly property int travelChecked: control.size === Enums.Small ? 11 : control.size === Enums.Large ? 26 : 18
    // $width-switch_knob_expand / $spacing-switch_expand_*_translateX
    readonly property int knobExpand: control.size === Enums.Small ? 2 : control.size === Enums.Large ? 10 : 6
    // 加载态的 Spin：$width-switch_spin-* 是 10 / 18 / 28，与圆钮的 12 / 18 / 24 不同档；
    // 位移 $spacing-switch_spin_*-translateX，未选中三档都是 2px，选中才分 10 / 16 / 22。
    readonly property int spinSize: control.size === Enums.Small ? 10 : control.size === Enums.Large ? 28 : 18
    readonly property int spinTranslateX: control.checked
        ? (control.size === Enums.Small ? 10 : control.size === Enums.Large ? 22 : 16) : 2

    // 动画时长。**不能用 Theme.current.durationNormal —— 它是 0。**
    // Semi 默认主题把全局令牌 --semi-transition_duration-* 全设成 0ms（通用过渡被关掉），
    // 但 switch 自己的 animation.scss 里硬编码了 200ms（$transition_duration-switch-bg
    // 与 $motion-switch-transitionDuration），这类组件级值不走全局令牌。
    // 曲线照 CSS 关键字展开：ease-in = cubic-bezier(.42,0,1,1)、
    // ease-in-out = cubic-bezier(.42,0,.58,1)。
    readonly property int motionDuration: 200

    implicitWidth: control.trackWidth
    implicitHeight: control.trackHeight
    // 官网 loading 时把 native input 一起 disabled，所以也不进 Tab 序
    activeFocusOnTab: control.enabled && !control.loading

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Appearance.switchTrack(Theme.current, control.checked, control.controlState,
                                      control.loading)
        border.width: control.borderThickness
        border.color: Appearance.switchTrackBorder(Theme.current, control.checked, control.controlState)

        // transition: background-color 200ms ease-in
        Behavior on color {
            ColorAnimation {
                duration: control.motionDuration
                // ease-in = cubic-bezier(.42,0,1,1)。Qt 的 Easing.BezierSpline 在 QML 里拿不到
                // 控制点（实测退化为线性），只能挑最接近的内置曲线：按最大偏差算 InSine 0.024 <
                // InQuad 0.069 < InCubic 0.216，所以这里用 InSine 而不是 InQuad。
                easing.type: Easing.InSine
            }
        }
    }

    // 圆钮。绘制交给下面的 MultiEffect（它连投影一起出），所以这里不可见 ——
    // 手势都挂在 Switch 自己身上，隐藏圆钮不影响交互。
    Rectangle {
        id: knob

        visible: false
        // x: left(0) + translateX，描边要另外加上；按下时选中态往回退一个 expand
        x: control.borderThickness + control.travelUnchecked
            + (control.checked ? control.travelChecked - control.travelUnchecked
                                 - (control.knobExpanded ? control.knobExpand : 0) : 0)
        y: control.borderThickness + control.knobPadding
        height: control.knobSize
        // :active 时圆钮加宽（未选中向右长、选中左缘回退），border-radius 不变所以是胶囊形
        width: control.knobSize + (control.knobExpanded ? control.knobExpand : 0)
        radius: height / 2
        color: Appearance.switchKnob(Theme.current, control.checked, control.enabled)
        border.width: control.controlState === Enums.Disabled && !control.checked
            ? control.borderThickness : 0
        border.color: Appearance.switchKnobBorder(Theme.current, control.checked, control.controlState)

        // transition: transform 200ms ease-in-out, width 200ms ease-in-out
        Behavior on x {
            NumberAnimation {
                duration: control.motionDuration
                // ease-in-out = cubic-bezier(.42,0,.58,1)，同样退化成内置曲线：
                // InOutQuad 最大偏差 0.012，是所有内置里最小的（InOutSine 0.019、InOutCubic 0.084）。
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: control.motionDuration
                easing.type: Easing.InOutQuad
            }
        }
    }

    // 圆钮投影。规格来自 Semi 的 @mixin shadow-knob：两条 box-shadow
    // （0 4px 6px rgba(0,0,0,.1) 与 0 0 1px rgba(0,0,0,.3)）。MultiEffect 一项只出一个投影，
    // 所以这里叠两层：先软的大范围，再紧的一圈。
    // blurMax 不能照抄 CSS 的 6：Qt 的 blurMax 是核半径，CSS 的是 2σ，同样 σ=3px 要 14 才对得上。
    // 参数是量出来的 —— 拿官方 CSS 在浏览器里渲一张 2x 图，逐行比最暗值：
    // 单层 0.35/8 时圆钮下缘差 50 个亮度级（我们 162、官方 213），现在平均差 1.9、总暗度差 0.3%。
    MultiEffect {
        source: knob
        visible: !control.loading
        anchors.fill: knob
        shadowEnabled: control.enabled
        shadowColor: Qt.rgba(0, 0, 0, 0.08)
        shadowVerticalOffset: 4
        shadowBlur: 1.0
        blurMax: 14
    }

    MultiEffect {
        source: knob
        visible: !control.loading
        anchors.fill: knob
        shadowEnabled: control.enabled
        shadowColor: Qt.rgba(0, 0, 0, 0.3)
        shadowBlur: 0.6
        blurMax: 2
    }

    // 加载指示器。官方是把 Spin 摆在正常流里（switch 那条 -loading 规则是
    // inline-flex + align-items:center），所以这里是「左缘贴描边内侧 + translateX、垂直居中」，
    // 而且没有 transition —— 切换 checked 时 Spin 直接跳位，不像圆钮那样滑过去。
    // Spin 自带 14 / 20 / 32 三档，与开关要的 10 / 18 / 28 不是一套，所以直接给宽高。
    Spin {
        visible: control.loading
        width: control.spinSize
        height: control.spinSize
        x: control.borderThickness + control.spinTranslateX
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.current.colorWhite
    }

    // 内嵌文案。.&{module}-checked-text / -unchecked-text：绝对定位、宽 20px（large 26px）、
    // 占满轨道高、水平垂直居中；开启文案靠左（白色），关闭文案靠右（text-2）。
    // 只渲染当前态那一条，且 small 尺寸下不渲染（index.tsx 的 showCheckedText）。
    Text {
        visible: control.size !== Enums.Small && text.length > 0

        width: control.size === Enums.Large ? 26 : 20
        height: control.height
        x: control.checked ? 0 : control.width - width
        text: control.checked ? control.checkedText : control.uncheckedText
        font.pixelSize: control.size === Enums.Large
            ? Theme.current.fontSizeRegular : Theme.current.fontSizeSmall
        color: control.checked ? Theme.current.colorWhite : Theme.current.colorText2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    HoverHandler {
        id: hover
        enabled: control.enabled && !control.loading
    }

    TapHandler {
        id: pointer
        enabled: control.enabled && !control.loading
        onTapped: {
            control.checked = !control.checked;
            control.toggled();
        }
    }
}
