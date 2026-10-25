pragma ComponentBehavior: Bound

import QtQuick

// 输入框组合。对应官方 semi-ui/input/inputGroup.tsx + .semi-input-group（input.scss:593-673）。
//
//     InputGroup {
//         Input { placeholderText: "Name"; width: 100 }
//         InputNumber { placeholderText: "Score"; width: 140 }
//     }
//
// 官方做的事有三件：组的 size 一律盖到子控件上（inputGroup.tsx:92-104）、
// 中间控件切平四角只留首尾外侧圆角、相邻控件的接缝上画一条 1px 分隔线
// （::after，right: -1px / top: 1px / bottom: 1px，颜色 color-border）。
Item {
    id: control

    objectName: "inputGroup"

    default property alias content: row.data

    // ---- 官方同名 ----
    property int size: Enums.Default
    property bool disabled: false
    // string 或 { text, required, optional, align, width }
    property var label: undefined
    property string labelPosition: "top"

    readonly property bool isInputGroup: true
    // 子控件清单由 relayout() 写入。做成绑定会和「relayout 里给子控件设 size」互相触发，
    // Qt 直接报 Binding loop，所以这里用可写属性 + 手动刷新。
    property var childItems: []

    readonly property bool isObjectLabel: control.label !== undefined && control.label !== null
        && typeof control.label === "object"
    readonly property var labelText: control.isObjectLabel
        ? (control.label.text !== undefined ? control.label.text : "") : control.label

    function collectChildren() {
        const list = [];
        const kids = row.children;
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            // 官方不认类型，任何子元素都照抄 size / disabled；这里以「有没有 size」
            // 认输入类控件（QQuickItem 本身没有这个属性）
            if (kids[i] !== undefined && kids[i] !== null && kids[i].size !== undefined)
                list.push(kids[i]);
            // qmllint enable missing-property
        }
        return list;
    }

    function relayout() {
        const items = control.collectChildren();
        control.childItems = items;
        let x = 0;
        let tallest = 0;
        for (let i = 0; i < items.length; ++i) {
            const child = items[i];
            child.x = x;
            x += child.width;
            tallest = Math.max(tallest, child.height);
            // qmllint disable missing-property
            // 组的 size 一律盖下去（官方 cloneElement 里 size 写在子级之后）
            if (child.size !== undefined)
                child.size = control.size;
            // disabled 官方是「子级显式给了就听子级」，QML 侧读不出有没有显式给，
            // 只做单向：组禁用则子控件必禁用
            if (control.disabled && child.enabled !== undefined)
                child.enabled = false;
            control.applyCorners(child, i, items.length);
            // qmllint enable missing-property
        }
        row.implicitWidth = x;
        row.implicitHeight = tallest;
        for (let i = 0; i < items.length; ++i)
            items[i].y = Math.round((tallest - items[i].height) / 2);
    }

    // .semi-input-group > * { border-radius: 0 } :first-child / :last-child 各留一侧
    function applyCorners(child, index, count) {
        // qmllint disable missing-property
        try {
            const r = Theme.current.radiusSmall;
            const first = index === 0;
            const last = index === count - 1;
            if (child.topLeftRadius === undefined)
                return;
            child.topLeftRadius = first ? r : 0;
            child.bottomLeftRadius = first ? r : 0;
            child.topRightRadius = last ? r : 0;
            child.bottomRightRadius = last ? r : 0;
        } catch (e) { }
        // qmllint enable missing-property
    }

    width: control.implicitWidth
    implicitWidth: row.implicitWidth
    implicitHeight: control.labelBlockHeight + row.implicitHeight

    readonly property real labelBlockHeight: labelBlock.visible
        && control.labelPosition !== "left" ? labelBlock.implicitHeight : 0

    Component.onCompleted: control.relayout()
    onSizeChanged: control.relayout()

    FormLabel {
        id: labelBlock

        visible: control.label !== undefined && control.label !== null && control.label !== ""
        x: 0
        y: 0
        width: control.labelPosition === "left" ? labelBlock.implicitWidth : row.width
        height: implicitHeight
        text: control.labelText
        required: control.isObjectLabel && control.label.required === true
        optional: control.isObjectLabel && control.label.optional === true
        align: control.isObjectLabel && control.label.align !== undefined
            ? control.label.align : "left"
        blockLevel: control.labelPosition !== "left"
    }

    Item {
        id: row

        objectName: "inputGroupRow"
        x: control.labelPosition === "left" && labelBlock.visible ? labelBlock.implicitWidth : 0
        y: control.labelBlockHeight
        // 宽高由 relayout() 单点写入：这里再挂 childrenRect 绑定会和它互相触发（绑定环）
        height: implicitHeight

        onChildrenChanged: control.relayout()
    }

    // 相邻控件接缝上的 1px 分隔线（官方 ::after，top/bottom 各缩 1px）
    Repeater {
        model: control.childItems.length > 1 ? control.childItems.length - 1 : 0

        delegate: Rectangle {
            id: seam

            required property int index

            objectName: "groupSeam"
            readonly property var leftChild: control.childItems[index]
            x: row.x + (leftChild !== undefined ? leftChild.x + leftChild.width : 0)
                - Theme.current.borderThicknessControl
            y: row.y + 1
            width: Theme.current.borderThicknessControl
            height: Math.max(0, row.height - 2)
            color: Theme.current.colorBorder
        }
    }
}
