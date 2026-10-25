pragma ComponentBehavior: Bound

import QtQuick

// 复选框组。把一组 Checkbox 的选中值收在一个数组里。
//
//     // 数组方式
//     CheckboxGroup {
//         options: ["Semi UI", "Semi DSM", "Semi D2C"]
//         defaultValue: ["Semi D2C"]
//         onChanged: (v) => console.log(v)
//     }
//     // 声明式（官方叫 JSX 方式）：每一项必须写 value，不写就不算组内项
//     CheckboxGroup {
//         Checkbox { value: "A"; text: "A" }
//         Checkbox { value: "B"; text: "B" }
//     }
//
// 规格（packages/semi-foundation/checkbox/checkbox.scss:375-412）：
//   竖排行间距 $spacing-base-tight=12，卡片样式时 $spacing-base=16；横排 gap 16。
//   options 与 children 二选一：给了 options 就忽略声明式子项（checkboxGroup.tsx:128-162）。
//   受控判定同官方：props 里有 value 就是受控，组只通知、不自改（checkboxGroupFoundation.ts:47-56）。
Item {
    id: control

    property var options: undefined         // string 或 {label, value, extra, disabled}
    property var value: undefined           // 受控的选中值数组
    property var defaultValue: []
    property bool disabled: false
    property int direction: Enums.DirectionVertical
    property int type: Enums.ChoiceDefault  // default | card | pureCard

    // 官方 onChange(checkedValue)
    signal changed(var checkedValue)

    readonly property bool pureCardType: control.type === Enums.ChoicePureCard
    readonly property bool cardType: control.type === Enums.ChoiceCard || control.pureCardType
    readonly property bool horizontal: control.direction === Enums.DirectionHorizontal

    property var _inner: control.defaultValue
    readonly property var currentValue: control.value !== undefined ? control.value : control._inner

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // 竖排默认 12（$spacing-checkbox_group_vertical_item-marginBottom）；
    // 做成可覆盖是因为 Feedback 的 checkbox 那一支要 16
    // （$spacing-feedback_checkbox_group_vertical-rowGap）
    property real itemSpacing: control.horizontal
        ? Theme.current.spacingBase
        : (control.cardType ? Theme.current.spacingBase : Theme.current.spacingBaseTight)

    function contains(v) {
        return control.currentValue.indexOf(v) >= 0;
    }

    function toggleItem(v, on) {
        if (control.disabled)
            return;
        const prev = control.currentValue;
        const next = on ? prev.concat([v]) : prev.filter((x) => x !== v);
        if (control.value === undefined)
            control._inner = next;
        control.changed(next);
    }

    // ---- 子项搬运（把 default 子项挪进真正的布局容器）----
    property bool _moving: false

    default property alias content: staging.data

    Component.onCompleted: control.reparentItems()
    onDirectionChanged: control.reparentItems()

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
                // Repeater 本身也是个 QQuickItem，会混在 children 里（实测），
                // 把它搬进布局只会污染子项列表，所以按 objectName 跳过。
                if (kids[i] && kids[i].objectName !== "optionRepeater")
                    pending.push(kids[i]);
            }
        }
        for (let i = 0; i < pending.length; ++i)
            pending[i].parent = target;

        control._moving = false;
    }

    Item {
        id: staging

        visible: false
        width: 0
        height: 0
    }

    // options 生成的项落在另一个暂存容器里：这样 options 和声明式子项谁生效一目了然，
    // 不用在搬运时区分两类孩子（官方本就是二选一，checkboxGroup.tsx:128-162）。
    Item {
        id: optionHost

        visible: false
        width: 0
        height: 0

        Repeater {
            objectName: "optionRepeater"
            model: control.options === undefined ? [] : control.options

            delegate: Checkbox {
                id: option

                required property var modelData

                // 字符串项：value 和文案都是它本身（checkboxGroup.tsx:130-141）
                text: typeof option.modelData === "string"
                    ? option.modelData : String(option.modelData.label)
                value: typeof option.modelData === "string"
                    ? option.modelData : option.modelData.value
                extra: typeof option.modelData === "string"
                    ? "" : (option.modelData.extra !== undefined ? String(option.modelData.extra) : "")
                disabled: control.disabled
                    || (typeof option.modelData !== "string" && option.modelData.disabled === true)
            }
        }
    }

    Column {
        id: columnLayout

        objectName: "columnLayout"
        visible: !control.horizontal
        spacing: control.itemSpacing
    }

    Row {
        id: rowLayout

        objectName: "rowLayout"
        visible: control.horizontal
        spacing: control.itemSpacing
    }

    readonly property var layout: control.horizontal ? rowLayout : columnLayout
}
