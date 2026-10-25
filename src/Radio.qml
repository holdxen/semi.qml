import QtQuick

// 单选框。官方 API 面见 semi-ui/radio/radio.tsx，状态与通知见
// semi-foundation/radio/radioFoundation.ts + radioInnerFoundation.ts，
// 外观见 radio.scss + variables.scss。
//
//     Radio { text: "单选"; checked: true }
//     Radio { text: "Semi Design"; extra: "由抖音前端与 UED 团队维护的设计系统" }
//     Radio { text: "允许取消选择"; mode: "advanced"; checked: true }
//     RadioGroup { type: Enums.ChoiceButton; Radio { value: 1; text: "即时推送" } }
//
// 官方 DOM（radio.tsx:295-312 + radioInner.tsx:128-146）：
//   label.semi-radio                     inline-flex，column-gap 8，min-height 20（radio.scss:8-20）
//     span.semi-radio-inner              16×16 + margin-top 2（radio.scss:212-219；button / pureCard
//                                        时改成绝对定位 + 透明，radio.scss:340-351）
//       span.semi-radio-inner-display    16×16 圆圈，选中时里面放 14px 的 IconRadio
//     div.semi-radio-content             flex-column，row-gap 4（radio.scss:252-256）
//       span.semi-radio-addon            标题（button 样式时换成 -addon-buttonRadio）
//       div.semi-radio-extra             副文本，button 样式下不渲染（radio.tsx:285）
//
// 四种 type 的差别全在 radio.scss 的 -buttonRadioComponent / -buttonRadioGroup /
// -cardRadioGroup 三个类上，见下面的 _isButton / _isCard / _isPureCard。
Item {
    id: control

    // ---- 官方属性面（radio.tsx:24-49）----
    property bool checked: false
    property bool defaultChecked: false
    // 组里代表这一项的值。官方用 group.value === 本项 value 判选中（radio.tsx:222），
    // 所以默认必须是 undefined，不能是 null 或 0
    property var value: undefined
    // 官方 disabled 与组的 disabled 取或（radio.tsx:223）
    property bool disabled: false
    property string text: ""                  // 官方是 children（ReactNode），本库只收字符串
    property var extra: undefined             // 官方 ReactNode；这里收字符串或 Component
    // '' | 'advanced'。advanced 时官方把 input 换成 type="checkbox"，
    // 于是点已选中项可以取消（radioInner.tsx:134）
    property string mode: ""
    property int type: Enums.ChoiceDefault    // 在组里时被 RadioGroup 的 type 覆盖
    property bool autoFocus: false

    signal toggled
    // 官方 onChange(e)，e.target 带 checked 与 value；这里直接把 value 交出去
    signal changed(var value)
    signal mouseEntered()
    signal mouseLeft()

    // ---- 与所在组的关系（radio.tsx:147-150 的 isInGroup）----
    readonly property var group: control.findGroup()
    readonly property bool inGroup: control.group !== null
    // 组里的最后一颗。RadioGroup 搬运子项时按顺序写；脱离组时恒为 true。
    property bool groupTail: true

    readonly property bool _off: control.disabled || !control.enabled
        || (control.inGroup ? control.group.disabled : false)
    readonly property bool _advanced: (control.inGroup ? control.group.mode : control.mode) === "advanced"
    readonly property int _type: control.inGroup ? control.group.type : control.type
    readonly property bool _isButton: control._type === Enums.ChoiceButton
    readonly property bool _isPureCard: control._type === Enums.ChoicePureCard
    readonly property bool _isCard: control._type === Enums.ChoiceCard || control._isPureCard
    readonly property int _buttonSize: control.inGroup
        ? control.group.buttonSize : Enums.RadioButtonMiddle
    readonly property int controlState: Appearance.state(!control._off, hover.hovered, pointer.pressed)

    function findGroup() {
        for (let p = control.parent; p; p = p.parent) {
            const g = p as RadioGroup;
            if (g)
                return p;
        }
        return null;
    }

    // ---- 几何（variables.scss）----
    readonly property real circleSize: Theme.current.widthIconMedium      // $width-radio_inner
    readonly property real markSize: 14                                   // radio.scss:238
    readonly property real lineHeight: 20                                 // $height-radio_inner_min
    readonly property real gap: control._isPureCard || control._isButton
        ? 0 : Theme.current.spacingTight                                  // $spacing-radio_addon-paddingLeft
    readonly property real contentGap: Theme.current.spacingExtraTight    // $spacing-radio_content-rowGap
    readonly property real innerWidth: (control._isPureCard || control._isButton) ? 0 : control.circleSize
    // 卡片：padding 12(纵)/16(横)、1px 描边、圆角 3（radio.scss:106-111）
    readonly property real paddingX: control._isCard ? Theme.current.spacingBase
        : (control._isButton ? control.buttonChromeX : 0)
    readonly property real paddingY: control._isCard ? Theme.current.spacingBaseTight
        : (control._isButton ? control.buttonChromeY : 0)
    readonly property real borderWidth: control._isCard ? 1 : 0
    // .semi-radio-buttonRadioGroup:not(:last-child) { padding-right: 0 }（radio.scss:90-92）：
    // 按钮式组里除最后一颗，其余的右侧内缩收成 0，相邻两份文案才只隔 4px。
    // 「最后一颗」按 DOM 顺序算，由 RadioGroup 在搬运子项时写 groupTail。
    readonly property real chromeLeft: control.paddingX + control.borderWidth
    readonly property real chromeRight: control._isButton && control.inGroup && !control.groupTail
        ? 0 : control.paddingX + control.borderWidth
    readonly property real chromeY: control.paddingY + control.borderWidth
    // .semi-radio-buttonRadioComponent / -buttonRadioGroup 的外层内边距（radio.scss:77-104）。
    // 注意 small 那条写的是 `padding: $…-paddingX $…-paddingY`，CSS 简写里第一个数是垂直，
    // 所以变量名反着：small 是垂直 super-tight(2) / 水平 extra-tight(4)，middle 与 large 都是 4。
    readonly property real buttonChromeX: Theme.current.spacingExtraTight
    readonly property real buttonChromeY: control.inGroup
        ? (control._buttonSize === Enums.RadioButtonSmall
            ? Theme.current.spacingSuperTight : Theme.current.spacingExtraTight)
        : Theme.current.spacingExtraTight
    // .semi-radio-addon-buttonRadio 的内层内边距（radio.scss:276-311）
    readonly property real addonPadX: control._buttonSize === Enums.RadioButtonLarge
        ? Theme.current.spacingLoose : Theme.current.spacingBase
    readonly property real addonPadY: control._buttonSize === Enums.RadioButtonSmall
        ? Theme.current.spacingSuperTight
        : (control._buttonSize === Enums.RadioButtonLarge
            ? Theme.current.spacingBaseTight * 0.5 : Theme.current.spacingExtraTight)
    readonly property real addonLineHeight: control._isButton
        ? (control._buttonSize === Enums.RadioButtonLarge ? 20 : 16)
        : control.lineHeight
    readonly property int addonFontSize: control._isButton
        ? (control._buttonSize === Enums.RadioButtonLarge
            ? Theme.current.fontSizeRegular : Theme.current.fontSizeSmall)
        : Theme.current.fontSizeRegular

    implicitWidth: control.chromeLeft + control.chromeRight + control.innerWidth
        + control.gap + control.contentNatural
    implicitHeight: control.chromeY * 2 + Math.max(control.innerWidth > 0 ? control.lineHeight : 0,
                                                  content.height)
    activeFocusOnTab: true

    // 内容列的可用宽度：没给宽度时按单行自然宽排，给了宽度就在剩余宽度里换行。
    // 自然宽只能取两个 Text 各自的 implicitWidth，不能取 Column 的（Column 的隐式宽来自
    // 子项宽度，子项宽度又要回来取它）——同 Checkbox.qml:76-86。
    readonly property real contentNatural: Math.max(addonWidth, extraWidth)
    readonly property real addonWidth: control._isButton
        ? addon.implicitWidth + control.addonPadX * 2 : addon.implicitWidth
    readonly property real extraWidth: extraText.implicitWidth
    readonly property real contentWidth: control.width > 0
        ? Math.min(control.contentNatural,
                   Math.max(0, control.width - control.chromeLeft - control.chromeRight
                              - control.innerWidth - control.gap))
        : control.contentNatural

    Component.onCompleted: {
        if (control.defaultChecked && !control.inGroup)
            control.checked = true;
        if (control.autoFocus)
            control.forceActiveFocus();
    }

    // 组里的 checked 由组的选中值决定（radio.tsx:222）
    Binding {
        target: control
        property: "checked"
        value: control.group ? control.group.contains(control.value) : false
        when: control.inGroup
        restoreMode: Binding.RestoreBindingOrValue
    }

    // 官方 input 的点击语义（radioInnerFoundation.ts:38-58）：
    //   非 advanced 是 <input type=radio>，点已选中项不会触发 change；
    //   advanced 是 <input type=checkbox>，点已选中项会取消。
    function toggleNow() {
        if (control._off)
            return;
        if (control.checked && !control._advanced)
            return;
        const next = !control.checked;
        // 官方顺序（radio.tsx:160-168）：先交给组处理并通知，再自持 checked，最后发自己的 onChange。
        // 组的 handleChange 复制了一份事件（radioGroupFoundation.ts:32-37），所以它把 advanced 取消
        // 时的 target.value 改成 undefined 不会影响这一项自己的 onChange —— 这里始终发自己的 value。
        if (control.inGroup)
            control.group.selectItem(control.value, next);
        if (!control.inGroup)
            control.checked = next;
        control.toggled();
        control.changed(control.value);
    }

    // 测试与外部量尺要看的都在这几个渲染项上（同 Checkbox.qml:93-99）
    readonly property alias circleItem: box
    readonly property alias markItem: mark
    readonly property alias addonItem: addon
    readonly property alias extraItem: extraText
    readonly property alias contentItem: content
    readonly property alias cardItem: card
    readonly property alias buttonChromeItem: buttonChrome

    // 卡片底（.semi-radio-cardRadioGroup，radio.scss:106-194）
    Rectangle {
        id: card

        anchors.fill: parent
        visible: control._isCard
        radius: Theme.current.radiusSmall             // $radius-radio_cardRadioGroup
        color: Appearance.choiceCardBackground(Theme.current, control.checked, control.controlState)
        border.width: control.borderWidth
        border.color: Appearance.choiceCardBorderColor(Theme.current, control.checked, control.controlState)
    }

    // 按钮式的外层底（.semi-radio-buttonRadioComponent，radio.scss:77-81）。
    // 在组里时这层底色由 RadioGroup 自己画，官方给单项也留了同一份 padding。
    Rectangle {
        id: buttonChrome

        anchors.fill: parent
        visible: control._isButton && !control.inGroup
        radius: Theme.current.radiusSmall             // $radius-radio_buttonRadio
        color: Theme.current.colorFill0               // $color-radio_buttonRadio-bg-default
    }

    Row {
        id: line

        x: control.chromeLeft
        y: control.chromeY
        anchors.verticalCenter: control._isButton ? parent.verticalCenter : undefined
        spacing: control.gap

        // .semi-radio-inner 官方是 16×16 + margin-top 2（radio.scss:212-219）；这里做成 20 高的槽、
        // 圆圈居中，等效于官方的 margin-top 2。button / pureCard 整槽不占位（radio.scss:340-351）
        Item {
            id: inner

            width: control.innerWidth
            height: control.innerWidth > 0 ? control.lineHeight : 0
            opacity: (control._isPureCard || control._isButton) ? 0 : 1

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: control.circleSize
                height: control.circleSize
                radius: control.circleSize / 2        // border-radius: $width-radio_inner
                // 禁用整框 0.75（radio.scss:363-364）。注意与 Checkbox 不同：
                // checkbox.scss:326-330 只在选中时给 0.75，而 radio 的 -disabled 直接打在
                // -inner-display 上，选中那一支（374-386）没有重置 opacity，所以两种都暗。
                opacity: control._off ? 0.75 : 1
                color: Appearance.choiceBoxBackground(Theme.current, control.checked,
                                                     control._isCard, control.controlState)
                border.width: 1                       // $width-radio_innder-border
                border.color: Appearance.choiceBoxBorderColor(Theme.current, control.checked,
                                                              control.controlState)

                Behavior on color {
                    ColorAnimation { duration: Theme.current.durationFast }
                }

                // 官方的选中标记是 14px 的 IconRadio（radioInner.tsx:145 + radio.scss:235-238），
                // 不是随手画的内圈；SVG 本身是 r=5/24 的实心圆，所以视觉直径约 5.8px
                Icon {
                    id: mark

                    anchors.centerIn: parent
                    visible: control.checked
                    name: "radio"
                    size: control.markSize
                    color: Theme.current.colorWhite   // $color-radio_primary-text-default
                }
            }
        }

        Column {
            id: content

            width: control.contentWidth
            spacing: control.contentGap

            // 标题。button 样式时它自己就是一颗按钮（.semi-radio-addon-buttonRadio）
            Rectangle {
                id: addonWrap

                visible: control.text !== ""
                width: control._isButton ? control.addonWidth : addon.implicitWidth
                height: control._isButton
                    ? addon.implicitHeight + control.addonPadY * 2 : addon.implicitHeight
                radius: Theme.current.radiusSmall
                // 非按钮式这一层只是标题的容器，官方没有底色（radio.scss:270-275 的 -addon
                // 只有 color 与 display）；底色只属于 -addon-buttonRadio
                color: control._isButton
                    ? Appearance.radioButtonAddonBackground(Theme.current, control.checked,
                                                           control.controlState)
                    : "transparent"

                Text {
                    id: addon

                    // addonPadX 是按钮式的内边距，其他 type 标题就贴着容器左缘
                    x: control._isButton ? control.addonPadX : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.text
                    color: control._isButton
                        ? Appearance.radioButtonAddonColor(Theme.current, control.checked,
                                                          control.controlState)
                        : (control._off ? Theme.current.colorDisabledText : Theme.current.colorText0)
                    font.pixelSize: control.addonFontSize
                    // $font-radio_buttonRadio-default-fontWeight / -cardRadioGroup_addon-fontWeight
                    // 都是 $font-weight-bold
                    font.weight: (control._isButton || control._isCard) ? Font.DemiBold : Font.Normal
                    lineHeightMode: Text.FixedHeight
                    lineHeight: control.addonLineHeight
                    wrapMode: Text.Wrap
                }
            }

            // 副文本。button 样式下官方直接不渲染（radio.tsx:285 的 extra && !isButtonRadio）
            Text {
                id: extraText

                visible: control.extraPresent && !control._isButton
                width: content.width
                text: control.extraTextValue
                color: control._off ? Theme.current.colorDisabledText : Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeightMode: Text.FixedHeight
                lineHeight: 20
                wrapMode: Text.Wrap
            }
        }
    }

    // extra 是 ReactNode：收字符串直接显示，收 Component 就实例化进这个槽
    readonly property bool extraPresent: control.extra !== undefined && control.extra !== null
        && String(control.extra) !== ""
    readonly property string extraTextValue: control.extra === undefined || control.extra === null
        ? "" : String(control.extra)

    HoverHandler {
        id: hover

        enabled: !control._off
        onHoveredChanged: {
            if (hovered)
                control.mouseEntered();
            else
                control.mouseLeft();
        }
    }

    TapHandler {
        id: pointer

        enabled: !control._off
        onTapped: control.toggleNow()
    }

    // 官方 .semi-radio-focus 是 2px 的 primary-light-active 轮廓（radio.scss:402-408）。
    // CSS 走的是 :focus-visible，QML 只有 activeFocus，所以 Tab 与鼠标点击都会亮环。
    Rectangle {
        anchors.fill: parent
        visible: control.activeFocus && !control._off
        radius: control._isCard ? Theme.current.radiusSmall : 0
        color: "transparent"
        border.width: 2                               // $width-radio-outline
        border.color: Theme.current.colorPrimaryLightActive
    }
}
