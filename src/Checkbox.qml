import QtQuick

// 复选框。方框 16×16、圆角 3px；未选中是 text-3 描边，选中（或半选）填主色加白勾。
//
//     Checkbox { text: "同意条款"; checked: true }
//     Checkbox { text: "Semi DSM"; extra: "从 Semi Design 到 Any Design 的定制" }
//     CheckboxGroup { value: page.picked; Checkbox { value: "a"; text: "A" } }
//
// 规格（packages/semi-foundation/checkbox/checkbox.scss）：
//   框 ↔ 文字间距 $spacing-tight=8；副文本紧跟标题，行间距 $spacing-extra-tight=4，
//     并且和标题左对齐（`&-extra` 没有 padding-left，checkbox.scss:358-364）。
//   文字行高固定 20（variables.scss:9），框的外层 .semi-checkbox-inner 高也是 20、
//     16×16 的方框在它里面垂直居中（checkbox.scss:91-98）——所以方框贴第一行，
//     副文本再多也不会把框拽下来。
//   type=card / pureCard 时整行是一张卡片：内边距 12(纵)/16(横)、圆角 3、1px 描边
//     （checkbox.scss:186-192）。pureCard 只是把框藏起来（width:0 + opacity:0，
//     checkbox.scss:204-210），间距同时归 0（:406-410）。
// 禁用没有整体半透明：官方只在「选中 + 禁用」时给方框 0.75 不透明度（checkbox.scss:330）。
Item {
    id: control

    // ---- 官方属性面（semi-ui/checkbox/checkbox.tsx:53-81）----
    property bool checked: false
    property bool defaultChecked: false
    property bool indeterminate: false
    property bool disabled: false
    // 在 CheckboxGroup 里代表这一项的值。官方用「props 里有没有 value」判定是否算组内项
    // （checkbox.tsx:181），所以默认必须是 undefined 而不是 null。
    property var value: undefined
    property string text: ""                  // 官方是 children（ReactNode），本库只收字符串
    property string extra: ""                 // 副文本
    property int type: Enums.ChoiceDefault    // 组内时被 CheckboxGroup 的 type 覆盖

    signal toggled

    // ---- 与所在组的关系 ----
    readonly property var group: control.findGroup()
    readonly property bool inGroup: control.group !== null && control.value !== undefined

    // 组里整组禁用会把每一项都禁掉（checkbox.tsx:233-235）
    readonly property bool _off: control.disabled || !control.enabled
        || (control.inGroup ? control.group.disabled : false)
    readonly property int controlState: Appearance.state(!control._off, hover.hovered, pointer.pressed)
    // 外层想要按下态自己做底色（Transfer 的整行 :active）；pointer 是内部 handler，
    // 只能这样递出去
    readonly property bool pressed: pointer.pressed
    // 半选和选中填同一套主色（checkbox.scss:279-307）
    readonly property bool _fill: control.checked || control.indeterminate
    readonly property bool _isPureCard: control.inGroup
        ? control.group.pureCardType
        : control.type === Enums.ChoicePureCard
    readonly property bool _isCard: control.inGroup
        ? control.group.cardType
        : (control.type === Enums.ChoiceCard || control._isPureCard)

    function findGroup() {
        for (let p = control.parent; p; p = p.parent) {
            const g = p as CheckboxGroup;
            if (g)
                return p;
        }
        return null;
    }

    implicitWidth: control.chromeX * 2 + control.innerWidth + control.gap + control.contentNatural
    implicitHeight: control.chromeY * 2 + Math.max(control.lineHeight, content.height)
    activeFocusOnTab: true

    readonly property real boxSize: Theme.current.widthIconMedium
    readonly property real lineHeight: 20
    readonly property real gap: control._isPureCard ? 0 : Theme.current.spacingTight
    readonly property real innerWidth: control._isPureCard ? 0 : control.boxSize
    readonly property real paddingX: control._isCard ? Theme.current.spacingBase : 0
    readonly property real paddingY: control._isCard ? Theme.current.spacingBaseTight : 0
    readonly property real borderWidth: control._isCard ? 1 : 0
    readonly property real chromeX: control.paddingX + control.borderWidth
    readonly property real chromeY: control.paddingY + control.borderWidth

    // 内容列的可用宽度：没给宽度时按单行自然宽排，给了宽度就在剩余宽度里换行
    // （.semi-checkbox-content 是 flex:1，实测 280 宽时内容列 256 = 280-16-8）。
    // 自然宽只能取两个 Text 各自的 implicitWidth，不能取 Column 的 —— Column 的隐式宽
    // 来自子项宽度，子项宽度又要回来取它。implicitWidth 同理必须按自然宽算：放在 Row /
    // Column 里时 width 会被父布局定成 implicitWidth，若 implicitWidth 用的是 content.width，
    // 两者互相收敛就成 0 了（实测文案直接被挤没）。
    readonly property real contentNatural: Math.max(addon.implicitWidth, extraText.implicitWidth)
    readonly property real contentWidth: control.width > 0
        ? Math.min(control.contentNatural,
                   Math.max(0, control.width - control.chromeX * 2 - control.innerWidth - control.gap))
        : control.contentNatural

    Component.onCompleted: {
        if (control.defaultChecked)
            control.checked = true;
    }

    // 测试要量真正画出来的那几个 item，从外面没有别的通路（同 AutoComplete 的 _popup）
    readonly property var _card: card
    readonly property var _box: box
    readonly property var _icon: tick
    readonly property var _content: content
    readonly property var _addon: addon
    readonly property var _extra: extraText

    // 组内的 checked 由组的选中值决定，官方明确「在 Group 中使用时无效」（文档 API 表）
    Binding {
        target: control
        property: "checked"
        // 搬运子项时会有一瞬间 parent 为 null，这里不兜住就报 contains of null
        value: control.group ? control.group.contains(control.value) : false
        when: control.inGroup
        restoreMode: Binding.RestoreBindingOrValue
    }

    function toggleNow() {
        if (control.inGroup) {
            // 组里不能自己翻，交给组去改选中数组（checkboxFoundation.ts:90-98）
            control.toggled();
            control.group.toggleItem(control.value, !control.checked);
            return;
        }
        control.checked = !control.checked;
        control.toggled();
    }

    // 卡片底（.semi-checkbox-cardType，checkbox.scss:186-277）
    Rectangle {
        id: card

        anchors.fill: parent
        visible: control._isCard
        radius: Theme.current.radiusExtraSmall
        color: Appearance.choiceCardBackground(Theme.current, control.checked, control.controlState)
        border.width: 1
        border.color: Appearance.choiceCardBorderColor(Theme.current, control.checked, control.controlState)
    }

    Row {
        id: line

        x: control.chromeX
        y: control.chromeY
        spacing: control.gap

        // .semi-checkbox-inner：16×20，方框在里面居中
        Item {
            id: boxSlot

            width: control.innerWidth
            height: control.lineHeight
            opacity: control._isPureCard ? 0 : 1

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: control.boxSize
                height: control.boxSize
                // 选中+禁用时只有方框半透明（checkbox.scss:330, 351-356）
                opacity: (control._off && control._fill) ? 0.75 : 1
                radius: Theme.current.radiusExtraSmall
                color: Appearance.choiceBoxBackground(Theme.current, control._fill,
                                                        control._isCard, control.controlState)
                border.width: 1
                border.color: Appearance.choiceBoxBorderColor(Theme.current, control._fill,
                                                                control.controlState)

                // 官方的勾是 16px 图标（checkbox.scss:113-115），也就是默认的 widthIconMedium
                Icon {
                    id: tick

                    anchors.centerIn: parent
                    visible: control._fill
                    name: control.indeterminate && !control.checked
                        ? "checkbox_indeterminate" : "checkbox_tick"
                    color: Theme.current.colorWhite
                }
            }
        }

        Column {
            id: content

            width: control.contentWidth
            spacing: Theme.current.spacingExtraTight

            Text {
                id: addon

                visible: control.text !== ""
                width: content.width
                text: control.text
                // 卡片样式的标题加粗（$font-checkbox_cardType_addon-fontWeight = 600）
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: control._isCard ? Font.DemiBold : Font.Normal
                color: control._off ? Theme.current.colorDisabledText : Theme.current.colorText0
                lineHeightMode: Text.FixedHeight
                lineHeight: control.lineHeight
                wrapMode: Text.Wrap
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: extraText

                visible: control.extra !== ""
                width: content.width
                text: control.extra
                // $color-checkbox_extra-text-default = text-2；禁用随标题一起变灰
                font.pixelSize: Theme.current.fontSizeRegular
                color: control._off ? Theme.current.colorDisabledText : Theme.current.colorText2
                lineHeightMode: Text.FixedHeight
                lineHeight: control.lineHeight
                wrapMode: Text.Wrap
            }
        }
    }

    HoverHandler {
        id: hover

        enabled: !control._off
    }

    TapHandler {
        id: pointer

        enabled: !control._off
        onTapped: control.toggleNow()
    }
}
