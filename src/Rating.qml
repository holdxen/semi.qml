pragma ComponentBehavior: Bound

import QtQuick

// 评分。可点选、可半星、可只读、可清除，支持自定义字符 / 个数 / 尺寸 / 每项提示。
//
//     Rating { defaultValue: 5 }
//     Rating { size: "small"; defaultValue: 5 }
//     Rating { allowHalf: true; defaultValue: 3.5 }
//     Rating { allowClear: false; defaultValue: 3 }
//     Rating { tooltips: ["terrible", "bad", "normal", "good", "wonderful"] }
//     Rating { character: "赞"; size: 18; defaultValue: 3 }
//
// 官方属性面见 semi-ui/rating/index.tsx:16-42，行为见
// semi-foundation/rating/foundation.ts，外观见 rating.scss + variables.scss，
// 单颗星的 DOM 见 semi-ui/rating/item.tsx。
//
// 官方 DOM（index.tsx:275-306 + item.tsx:231-238）：
//   ul.semi-rating                     inline-block，color = yellow-5，圆角 3，宽 = count*(尺寸+6)
//     li.semi-rating-star × (count+1)  24×24（small 16），非末项 margin-right 6
//       div.semi-rating-star-wrapper    overflow:hidden，点击 / 悬浮都打在这层
//         div.semi-rating-star-first    绝对定位、宽 (1-diff)*100%、只有半星时 opacity 1、色 = inherit
//         div.semi-rating-star-second   整星，色 = fill-0（整星那支才 color: inherit）
//     最后那个 li 是 0×0 的「空星」，代表 0 分，只为键盘焦点与 ARIA 存在
//     （index.tsx:290 给它 size={0}）—— QML 的焦点在控件上，这一项不需要搬。
//
// 半星不是「画半颗」，而是同一枚图标画两遍、上面那层按分数裁切（item.tsx:234 的
// style={{ width: firstWidth*100 + '%' }}）。所以 allowHalf 也能正确显示 3.65 这种
// 非 0.5 的小数（官方 半星 小节就是这么演示的）。
Item {
    id: control

    // ---- 官方属性面（index.tsx:16-42，默认值 index.tsx:88-99）----
    // 受控值。官方是 `'value' in props` 判受控（index.tsx:155），QML 分不出「没写」与
    // 「写了 undefined」，所以用 undefined 当「非受控」，与 Radio / CheckboxGroup 同一口径。
    property var value: undefined
    property real defaultValue: 0
    property int count: 5
    property bool allowHalf: false
    property bool allowClear: true
    property bool disabled: false
    // 'default' | 'small' | 数字（官方 size?: 'small' | 'default' | number，index.tsx:36）
    property var size: "default"
    // 自定义字符：字符串直接当文字画；Component 走 Loader（官方是 ReactNode）
    property var character: undefined
    // 每一项的提示文案（index.tsx:296-303 用 Tooltip 包住每颗星）
    property var tooltips: undefined
    property bool autoFocus: false
    // 官方没有 color 属性，星星的颜色是 ul 的 CSS `color` 继承下来的（rating.scss:11,39）。
    // 文档 自定义 小节就是写 <Rating style={{color:'red'}} …>，QML 里没有 style，
    // 所以把这条映射成控件自己的 color。
    property color color: Theme.current.yellow[5]   // $color-rating-icon-default

    // 官方 onChange(value)。非受控才自改值，但**一定**通知（index.tsx:153-161）。
    signal changed(real value)
    // 官方 onHoverChange(value)：离开时是 undefined，所以参数得是 var
    signal hoverChanged(var value)
    // 官方 onFocus / onBlur / onKeyDown。QML 的 Item 已有 focus 属性，故信号叫 focused。
    signal focused()
    signal blurred()
    signal keyPressed()

    // ---- 内部状态（index.tsx:109-115）----
    property real _inner: control.defaultValue
    property var _hoverValue: undefined
    // allowClear 清掉那一下的原值：悬浮回到它时不再预览（foundation.ts:86-92）
    property var _clearedValue: null
    readonly property bool _off: control.disabled || !control.enabled
    // QML 没有 :focus-visible（Qt 也没把 focusReason 暴露给 Item，实测 undefined），
    // 所以自己记一下「这焦点是鼠标点出来的」：那种情况下官方不给环（Chrome 的
    // :focus-visible 规则），键盘 Tab 进来 / 编程式聚焦才给。
    property bool _focusByMouse: false
    readonly property var currentValue: control.value !== undefined ? control.value : control._inner
    // 显示值 = 悬浮预览优先（index.tsx:283）
    readonly property real displayValue: control._hoverValue === undefined
        ? control.currentValue : control._hoverValue

    // ---- 尺寸（variables.scss）----
    readonly property bool _customSize: typeof control.size === "number"
    readonly property int itemSize: control._customSize ? control.size
        : (control.size === "small" ? 16 : 24)               // $width-rating_item_*
    readonly property real itemSpacing: 6                    // $spacing-rating_item-marginRight
    readonly property color emptyColor: Theme.current.colorFill0   // $color-rating-bg-default

    // ul 的盒子把末星的 margin-right 也算进内容宽（官方实测 5×24 + 5×6 = 150），
    // 所以隐式宽是 count*(尺寸+间隙)，而行内布局的隐式宽只有 (count-1) 个间隙。
    implicitWidth: control.count * (control.itemSize + control.itemSpacing)
    implicitHeight: control.itemSize
    activeFocusOnTab: !control._off

    Component.onCompleted: {
        if (control.autoFocus && !control._off)
            control.forceActiveFocus();          // foundation.ts:22-27
    }

    onAutoFocusChanged: {
        if (control.autoFocus && !control._off)
            control.forceActiveFocus();
    }

    // getStarValue（foundation.ts:68-84）：第 index 颗的右半按整星算、左半减 0.5。
    // 官方还处理 rtl，本库不做 rtl。
    function starValueAt(index, localX) {
        let v = index + 1;
        if (control.allowHalf && localX < control.itemSize / 2)
            v -= 0.5;
        return v;
    }

    // updateValue（index.tsx:153-161）：非受控才写值，通知无条件发
    function setValue(v) {
        if (control.value === undefined)
            control._inner = v;
        control.changed(v);
    }

    // notifyHoverChange（index.tsx:145-152）：hoverValue 与 clearedValue 一起写
    function setHover(hv, cv) {
        control._hoverValue = hv;
        control._clearedValue = cv;
        control.hoverChanged(hv);
    }

    // handleHover（foundation.ts:86-92）
    function preview(v) {
        if (v === control._hoverValue || v === control._clearedValue)
            return;
        control.setHover(v, null);
    }

    // handleMouseLeave（foundation.ts:94-96）
    function leave() {
        control.setHover(undefined, null);
    }

    // handleClick（foundation.ts:98-109）
    function clickAt(index, localX) {
        const newValue = control.starValueAt(index, localX);
        const isReset = control.allowClear ? newValue === control.currentValue : false;
        control.setValue(isReset ? 0 : newValue);
        if (isReset)
            control.setHover(undefined, newValue);
        else
            control._clearedValue = null;        // clearValue(null)，不发通知
    }

    // handleKeyDown（foundation.ts:119-146）：右 / 上前进一档，左 / 下后退一档，
    // 越过两端就回绕（>count 归 0、<0 归 count），allowHalf 时步长 0.5。
    function stepBy(dir) {
        const step = control.allowHalf ? 0.5 : 1;
        const temp = control.currentValue + dir * step;
        let next = temp;
        if (temp > control.count)
            next = 0;
        else if (temp < 0)
            next = control.count;
        control.keyPressed();                    // notifyKeyDown
        control.setValue(next);                  // updateValue
        control.setHover(undefined, null);       // notifyHoverChange(undefined, null)
        control._focusByMouse = false;           // 键盘动过之后环就该出现了
    }

    Row {
        id: row

        // Row 的 width 不会自动跟 implicitWidth，不给尺寸的话下面那个 HoverHandler 永远
        // 悬不到（Positioner 只负责排子项）。
        width: row.implicitWidth
        height: control.itemSize
        spacing: control.itemSpacing

        Repeater {
            model: control.count

            delegate: Item {
                id: star

                required property int index

                objectName: "ratingStar"

                readonly property real starValue: star.index + 1
                readonly property real diff: star.starValue - control.displayValue
                readonly property bool isFull: star.starValue <= control.displayValue
                // isHalf（item.tsx:162）：0 < 差 < 1，于是 3.65 也算第 4 颗「部分填充」
                readonly property bool isHalf: control.allowHalf
                    && star.diff < 1 && star.diff > 0
                // firstWidth = (1 - diff) * 100%（item.tsx:163,234）
                readonly property real firstWidth: Math.max(0, Math.min(star.width,
                    (1 - star.diff) * star.width))

                width: control.itemSize
                height: control.itemSize
                // .semi-rating-star > div:hover { transform: scale(1.1) }（rating.scss:48-52）。
                // 缩放打在内层 wrapper 上，wrapper 与 li 等大，所以直接缩 li；wrapper 没有
                // transition，故这里是瞬间生效（rating.scss:41 那条 all .5s 是给 li 的）。
                scale: starArea.containsMouse ? 1.1 : 1

                // 下层：整星。isFull 用主色，否则用未填色（rating.scss:85-110）
                Item {
                    id: secondLayer

                    anchors.fill: parent
                    readonly property color glyphColor: star.isFull ? control.color
                        : control.emptyColor

                    RatingGlyph {
                        objectName: "ratingStarBase"

                        size: control.itemSize
                        character: control.character
                        color: secondLayer.glyphColor
                    }
                }

                // 上层：叠在上面的裁切层，只有半星时可见（rating.scss:92-105）
                Item {
                    id: firstLayer

                    objectName: "ratingStarFill"
                    x: 0
                    y: 0
                    width: star.firstWidth
                    height: star.height
                    visible: star.isHalf
                    clip: true

                    // 图形仍然是整星宽，靠 firstLayer 的 clip 切出左半边
                    RatingGlyph {
                        objectName: "ratingStarFillGlyph"

                        size: control.itemSize
                        character: control.character
                        color: control.color
                    }
                }

                // 悬浮：官方把 mousemove 打在 wrapper 上（item.tsx:186）。这里用
                // acceptedButtons: Qt.NoButton 的 MouseArea，只为拿到「移动中的坐标」
                // （HoverHandler 只有进/出，没有移动信号），它不吃按键，点击仍然落到
                // 下面那个 TapHandler 上。
                MouseArea {
                    id: starArea

                    anchors.fill: parent
                    // 只关 hoverEnabled 就够：它 acceptedButtons 是 NoButton，不吃点击，
                    // 再叠一层 enabled 是死代码（变异验证里那一层被抓出来是「改哪半边都还
                    // 剩一边挡着」，所以只有删掉它才谈得上这条守卫有没有被测住）。
                    hoverEnabled: !control._off
                    acceptedButtons: Qt.NoButton
                    onPositionChanged: (mouse) => control.preview(
                        control.starValueAt(star.index, mouse.x))
                }

                TapHandler {
                    enabled: !control._off
                    // 官方把 click 打在 wrapper 上（item.tsx:184），间隙不响应
                    onTapped: (eventPoint) => {
                        // 浏览器点 div 会聚焦，这样点完还能继续用方向键
                        control._focusByMouse = true;
                        control.forceActiveFocus();
                        control.clickAt(star.index, eventPoint.position.x);
                    }
                }

                // 官方 tooltips 是给每颗星套一层受控 Tooltip（index.tsx:296-303）：
                // `visible={hoverValue - 1 === ind}`、`trigger="custom"`。
                // 所以 allowHalf 且悬在左半时不显示文案（那时 hoverValue 是 x.5，
                // 对不上任何 ind）。常驻一个 Popup 太浪费，只在该项有文案时才创建。
                Loader {
                    objectName: "ratingStarTip"

                    active: control.tooltips !== undefined && star.index < control.tooltips.length
                    sourceComponent: Tooltip {
                        target: star
                        text: control.tooltips[star.index]
                        trigger: "custom"
                        visible: control._hoverValue - 1 === star.index
                    }
                }
            }
        }

        // 「离开」统一挂在这层（官方是 ul 的 onMouseLeave，index.tsx:332）。
        // 用整行的 HoverHandler 而不是每颗星一个，是为了让 6px 间隙保持上一颗的预览值 ——
        // 间隙不落进 li 的 mousemove，效果一致。
        HoverHandler {
            id: rowHover

            enabled: !control._off
            onHoveredChanged: {
                if (!hovered && !control._off)
                    control.leave();
            }
        }
    }

    // 焦点环：官方 .semi-rating-focus 是 2px 的 primary-light-active 描边
    // （rating.scss:18-20 + $width-rating-outline-focus）。它打在「当前选中那颗」的
    // wrapper 上（item.tsx:181），0 分时打在整只 ul 上（index.tsx:320 emptyStarFocusVisible）。
    // CSS 只在 :focus-visible 时给环，QML 没有这个伪类（Qt 也没把 focusReason 暴露给
    // Item），所以按 _focusByMouse 近似：鼠标点出来的焦点不画环，Tab / 编程式焦点才画。
    Rectangle {
        id: focusRing

        objectName: "ratingFocusRing"

        // 环跟的是已提交的值，不是悬浮预览值（index.tsx:133-140 adapter.focus 用 state.value）
        readonly property int focusedIndex: control.currentValue <= 0 ? -1
            : Math.ceil(control.currentValue) - 1
        x: focusedIndex < 0 ? 0 : focusedIndex * (control.itemSize + control.itemSpacing)
        y: 0
        width: focusedIndex < 0 ? control.implicitWidth : control.itemSize
        height: control.itemSize
        visible: control.activeFocus && !control._off && !control._focusByMouse
        radius: 3                                    // rating.scss:16 border-radius
        color: "transparent"
        border.width: 2                              // $width-rating-outline-focus
        border.color: Theme.current.colorPrimaryLightActive
    }

    Keys.onPressed: (event) => {
        if (control._off)
            return;
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) {
            control.stepBy(1);
            event.accepted = true;                   // 官方 event.preventDefault()
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            control.stepBy(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // item.tsx:121-126：回车等于点当前聚焦的那颗星。键盘事件没有 pageX，
            // 官方 getStarValue 里那个「左半」判断因此恒为 false，等于按整星算。
            // 0 分时焦点落在那个 0×0 的空星上（index.tsx:138），官方回车会算出
            // count+1 这种越界值；本库不跟着越界。
            if (control.currentValue > 0) {
                control.clickAt(Math.ceil(control.currentValue) - 1, control.itemSize);
                event.accepted = true;
            }
        }
    }

    // 官方 onFocus / onBlur 打在 ul 上（index.tsx:334-335）
    onActiveFocusChanged: {
        if (control.activeFocus) {
            control.focused();
        } else {
            control._focusByMouse = false;       // 下次 Tab 进来要重新有环
            control.blurred();
        }
    }
}
