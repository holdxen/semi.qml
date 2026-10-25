pragma ComponentBehavior: Bound

import QtQuick

// 单选框组。一组互斥的 Radio，选中值只有一个。
//
//     // 声明式：每一项必须写 value
//     RadioGroup {
//         defaultValue: 1
//         onChanged: (v) => console.log(v)
//         Radio { value: 1; text: "A" }
//         Radio { value: 2; text: "B" }
//     }
//     // 数组方式
//     RadioGroup { options: ["Guest", "Developer"]; defaultValue: "Guest" }
//
// 规格（packages/semi-foundation/radio/radio.scss:411-443）：
//   横排 gap $spacing-base=16、竖排 row-gap $spacing-base-tight=12 —— 卡片式竖排也是 12，
//     variables.scss:84 那个 $spacing-radio_card_group_vertical-marginBottom=16 全文件没被引用，
//     是死变量（checkbox.scss:402 用的 $spacing-checkbox_card_group_vertical-marginBottom 才是真的，
//     两边别照抄）。
//   type='button' 时官方不给组挂 direction 类（radioGroup.tsx:167 的 `!isButtonRadio`），
//   所以按钮式永远是横排；组本身只有一层 fill-0 底 + 圆角 3，内边距在单项上。
//   options 与声明式子项二选一（radioGroup.tsx:177-208）；受控判定同官方，
//   props 里有 value 就是受控，组只通知、不自改（radioGroupFoundation.ts:32-60）。
Item {
    id: control

    // ---- 官方属性面（radioGroup.tsx:32-56）----
    property var value: undefined           // 受控的选中值
    property var defaultValue: undefined
    // string，或 {label, value, extra, disabled, width}
    // （官方是 {label, value, extra, disabled, style, className, addonStyle…}，
    //   QML 没有内联样式，这里只把 demo 用得到的 width 拎出来）
    property var options: undefined
    property bool disabled: false
    // 官方 DEFAULT_DIRECTION 是 horizontal（constants.ts:24），与 CheckboxGroup 的 vertical 相反
    property int direction: Enums.DirectionHorizontal
    property int type: Enums.ChoiceDefault  // default | button | card | pureCard
    property int buttonSize: Enums.RadioButtonMiddle
    // '' | 'advanced'，下发给组内每一项（radioGroup.tsx:240 的 context.mode）
    property string mode: ""
    property string name: ""

    // 官方 onChange(e)，这里交出去的是选中值；advanced 取消时是 undefined
    signal changed(var value)

    readonly property bool isButton: control.type === Enums.ChoiceButton
    readonly property bool pureCardType: control.type === Enums.ChoicePureCard
    readonly property bool cardType: control.type === Enums.ChoiceCard || control.pureCardType
    // 按钮式不支持竖排（radioGroup.tsx:167）
    readonly property bool horizontal: control.direction === Enums.DirectionHorizontal
        || control.isButton

    property var _inner: control.defaultValue
    readonly property var currentValue: control.value !== undefined ? control.value : control._inner

    // 尺寸只能取布局的隐式宽：chrome 是 anchors.fill: parent 的，取它的隐式宽会自我循环，
    // 结果整组算成 0×0。
    readonly property var layout: control.horizontal ? rowLayout : columnLayout

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // 按钮式组不挂 direction 类（radioGroup.tsx:167 的 `&& !isButtonRadio`），官方那 16 / 12 的
    // gap 对它根本不生效（实测 .semi-radioGroup-buttonRadio 是 display:block、gap:normal、
    // padding:0），项间距离 0，视觉间隔全靠单项自己的内缩（radio.scss:86 + 90-92）。
    readonly property real itemSpacing: control.isButton ? 0
        : (control.horizontal
            ? Theme.current.spacingBase             // $spacing-radio_group_horizontal-marginRight
            : Theme.current.spacingBaseTight)       // $spacing-radio_group_vertical-marginBottom

    function contains(v) {
        return control.currentValue === v;
    }

    // radioGroupFoundation.ts:32-60 handleChange。
    // 这里不判 disabled：官方也没有（禁用的 input 根本发不出 change），挡住点击是单项那一侧
    // Radio._off 的职责，组再判一次就是够不到的死代码。
    function selectItem(v, checked) {
        const last = control.currentValue;
        const next = (control.mode === "advanced" && !checked) ? undefined : v;
        if (control.value === undefined)
            control._inner = next;
        // 官方：advanced 时即使值没变也要通知（radioGroupFoundation.ts:58）
        if (control.mode === "advanced" || last !== next)
            control.changed(next);
    }

    // ---- 子项搬运（与 CheckboxGroup 同一套做法）----
    property bool _moving: false

    default property alias content: staging.data

    Component.onCompleted: control.reparentItems()
    onDirectionChanged: control.reparentItems()
    onTypeChanged: control.reparentItems()

    Connections {
        target: staging

        function onChildrenChanged() {
            if (!control._moving)
                control.reparentItems();
        }
    }

    Connections {
        target: optionHost

        function onChildrenChanged() {
            if (!control._moving)
                control.reparentItems();
        }
    }

    function reparentItems() {
        if (control._moving)
            return;
        control._moving = true;

        const target = control.horizontal ? rowLayout : columnLayout;
        const source = control.horizontal ? columnLayout : rowLayout;
        // 给了 options 就只搬 options 生成的项，声明式子项留在暂存容器里（官方二选一）
        const host = control.options === undefined ? staging : optionHost;

        const pending = [];
        const hosts = [source, host];
        for (let h = 0; h < hosts.length; ++h) {
            const kids = hosts[h].children;
            for (let i = 0; i < kids.length; ++i) {
                // Repeater 本身也是 QQuickItem，会混在 children 里，按 objectName 跳过
                if (kids[i] && kids[i].objectName !== "optionRepeater")
                    pending.push(kids[i]);
            }
        }
        for (let i = 0; i < pending.length; ++i)
            pending[i].parent = target;

        // 只有最后一颗保留右侧内缩（radio.scss:90-92 的 :not(:last-child) { padding-right: 0 }）
        for (let i = 0; i < pending.length; ++i) {
            const it = pending[i];
            if (it.groupTail !== undefined)
                it.groupTail = i === pending.length - 1;
        }

        control._moving = false;
    }

    // 按钮式那一层底（.semi-radioGroup-buttonRadio，radio.scss:438-443）
    Rectangle {
        id: chrome

        objectName: "radioGroupChrome"
        anchors.fill: parent
        visible: control.isButton
        radius: Theme.current.radiusSmall         // $radius-radio_buttonRadio
        color: Theme.current.colorFill0           // $color-radio_buttonRadio-bg-default
    }

    Item {
        id: staging

        visible: false
        width: 0
        height: 0
    }

    // options 生成的项落在另一个暂存容器里：options 与声明式子项谁生效一目了然
    Item {
        id: optionHost

        visible: false
        width: 0
        height: 0

        Repeater {
            objectName: "optionRepeater"
            model: control.options === undefined ? [] : control.options

            delegate: Radio {
                id: option

                required property var modelData

                // 字符串项：value 和文案都是它本身（radioGroup.tsx:179-190）
                text: typeof option.modelData === "string"
                    ? option.modelData : String(option.modelData.label)
                value: typeof option.modelData === "string"
                    ? option.modelData : option.modelData.value
                extra: typeof option.modelData === "string"
                    ? undefined
                    : (option.modelData.extra !== undefined ? option.modelData.extra : undefined)
                disabled: control.disabled
                    || (typeof option.modelData !== "string" && option.modelData.disabled === true)
                // 官方透传的是 style={{ width }}；QML 里没有内联样式，只能把这一项拎出来
                width: typeof option.modelData === "string" || option.modelData.width === undefined
                    ? implicitWidth : option.modelData.width
            }
        }
    }

    Column {
        id: columnLayout

        objectName: "radioColumnLayout"
        visible: !control.horizontal
        spacing: control.itemSpacing
    }

    Row {
        id: rowLayout

        objectName: "radioRowLayout"
        visible: control.horizontal
        spacing: control.itemSpacing
    }
}
