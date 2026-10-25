pragma ComponentBehavior: Bound

import QtQuick

// 按钮组合。官方 buttonGroup.tsx 只干三件事：
//   1. 下发属性：size / type / disabled 是「单项没写才生效」的默认值，
//      theme 与 colorful 反过来是「组盖单项」（buttonGroup.tsx:80 的 cloneElement
//      把 ...itm.props 排在这三个之后、把 ...rest 排在最后）；
//   2. 子按钮去掉自己的圆角与内边距，只留首尾外侧圆角（button.scss:403-462）；
//   3. 相邻两个按钮之间插一条 .semi-button-group-line。
//
// 那条分隔条官方是 1px 宽、被 flex 拉成整行高的 type 色底，正中再摆一条
// 1px × 20px 的 color-border（::before，variables.scss:145-146 / 198）。
// outline 形态不插线，改成后一个压前一个 1px、把右侧描边盖掉（button.scss:464-467）。
//
//     ButtonGroup {
//         Button { text: "拷贝" }
//         Button { text: "查询" }
//     }
Item {
    id: control

    objectName: "buttonGroup"

    default property alias content: row.data

    // ---- 官方属性面（buttonGroup.tsx:13-21）----
    // size 官方有 defaultProps 'default'，这里留 undefined 就等于默认档。
    // type / theme 官方故意不给默认值，好让单项能自己定（buttonGroup.tsx:36-41 的注释）。
    property var size: undefined
    property var tone: undefined
    property var variant: undefined
    property var colorful: undefined
    property bool disabled: false
    property string ariaLabel: ""

    // 成员清单由 relayout() 写入（做成绑定会和「relayout 里给子项设属性」互相触发）
    property var childItems: []

    // $width-button_group-border = $border-thickness-control
    readonly property real lineWidth: Theme.current.borderThicknessControl
    // outline 那侧重叠的量取描边宽，和按钮实际画多宽的边框同步
    readonly property real overlap: Appearance.buttonBorderWidth(Enums.Outline)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // 官方 .semi-button-group 是 display:flex，子项按声明顺序横排；
    // QML 不能既让用户把按钮直接声明在组里、又往里插分隔条，所以自己算 x。
    function collect() {
        const out = [];
        const kids = row.children;
        for (let i = 0; i < kids.length; ++i) {
            const kid = kids[i];
            // qmllint disable missing-property
            // 探测属性存不存在要看它的自动信号：groupPosition 是 string，
            // 没这个属性的控件读出来是 undefined，有但没赋值的读出来是 ""
            if (kid !== undefined && kid !== null && kid.groupPositionChanged !== undefined)
                out.push(kid);
            // qmllint enable missing-property
        }
        return out;
    }

    // 某个成员右侧占多宽：outline 重叠一个描边宽，其余是一条分隔条
    function seamAfter(child) {
        // qmllint disable missing-property
        if (child.resolvedVariant === Enums.Outline)
            return -control.overlap;
        // qmllint enable missing-property
        return control.lineWidth;
    }

    function relayout() {
        const items = control.collect();
        control.childItems = items;
        let x = 0;
        let tallest = 0;
        for (let i = 0; i < items.length; ++i) {
            const child = items[i];
            // qmllint disable missing-property
            child.groupPosition = items.length === 1 ? "only"
                : (i === 0 ? "first" : (i === items.length - 1 ? "last" : "middle"));
            child.groupSize = control.size;
            child.groupTone = control.tone;
            child.groupVariant = control.variant;
            child.groupColorful = control.colorful;
            // 官方是「单项显式写了 disabled 就听单项」，QML 里读不出有没有写过，
            // 只做单向：组禁用则成员必禁用
            child.groupDisabled = control.disabled;
            child.x = x;
            // flex 交叉轴默认 stretch，但按钮是定高的，等效于顶部对齐
            child.y = 0;
            x += child.width;
            if (i < items.length - 1)
                x += control.seamAfter(child);
            tallest = Math.max(tallest, child.height);
            // qmllint enable missing-property
        }
        row.implicitWidth = x;
        row.implicitHeight = tallest;
    }

    Component.onCompleted: control.relayout()
    onSizeChanged: control.relayout()
    onToneChanged: control.relayout()
    onVariantChanged: control.relayout()
    onColorfulChanged: control.relayout()
    onDisabledChanged: control.relayout()

    Item {
        id: row

        objectName: "buttonGroupRow"
        // 宽高由 relayout() 单点写入：这里再挂 childrenRect 绑定会和它互相触发
        height: implicitHeight
        onChildrenChanged: control.relayout()
    }

    // 相邻按钮之间的分隔条：整行高的 type 色底 + 居中一条 1px × 20px 的 color-border
    Repeater {
        model: control.childItems.length > 1 ? control.childItems.length - 1 : 0

        delegate: Rectangle {
            id: seam

            required property int index

            objectName: "groupLine"
            // qmllint disable missing-property
            // 名字不能叫 left —— 那是 QQuickItem 的 FINAL 成员（坑 59 同族）
            readonly property var leftButton: control.childItems[index]
            readonly property bool drawn: leftButton !== undefined && leftButton !== null
                // outline 形态官方不插线（buttonGroup.tsx:50 的 theme !== 'outline'）
                && leftButton.resolvedVariant !== Enums.Outline
            visible: drawn
            // qmllint enable missing-property
            x: leftButton !== undefined && leftButton !== null ? leftButton.x + leftButton.width : 0
            y: 0
            width: control.lineWidth
            height: row.height
            color: seam.drawn
                // qmllint disable missing-property
                ? Appearance.buttonGroupLine(Theme.current, leftButton.resolvedTone,
                    leftButton.resolvedVariant, leftButton.enabled ? Enums.Normal : Enums.Disabled)
                // qmllint enable missing-property
                : "transparent"

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.current.borderThicknessControl
                height: 20
                color: Theme.current.colorBorder
            }
        }
    }
}
