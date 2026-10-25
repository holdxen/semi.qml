pragma ComponentBehavior: Bound

import QtQuick

// 分裂按钮组合。官方 splitButtonGroup.tsx 是个纯容器：拿 MutationObserver 找到
// 子树里第一个和最后一个 <button>，给它们加 -first / -last 两个类，别的什么都不做
// —— 不下发 size / type / theme，也不管中间还有没有 Dropdown。
// 样式只有两条（splitButtonGroup.scss:10-23）：所有按钮切平圆角、彼此隔开 1px，
// 首尾各留外侧那一边的圆角。
//
// 菜单本体交给 Dropdown，触发按钮由使用方自己声明：
//
//     SplitButtonGroup {
//         Button { id: main; text: "分裂按钮"; variant: Enums.Solid }
//         Button { id: trigger; icon: "tree_triangle_down"; variant: Enums.Solid }
//         Dropdown { id: menu; target: trigger; trigger: "click"
//                  DropdownItem { text: "编辑项目" } }
//     }
Item {
    id: control

    objectName: "splitButtonGroup"

    default property alias content: row.data

    property string ariaLabel: ""

    // splitButtonGroup.scss:12 的 margin-right: 1px 是写死的字面值
    readonly property real gap: 1

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property var childItems: []

    function collect() {
        const out = [];
        const kids = row.children;
        for (let i = 0; i < kids.length; ++i) {
            const kid = kids[i];
            // qmllint disable missing-property
            if (kid !== undefined && kid !== null && kid.groupPositionChanged !== undefined)
                out.push(kid);
            // qmllint enable missing-property
        }
        return out;
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
            child.x = x;
            child.y = 0;
            x += child.width + control.gap;
            tallest = Math.max(tallest, child.height);
            // qmllint enable missing-property
        }
        // 最后一个的 margin-right 被 -last 撤掉了（splitButtonGroup.scss:22）
        row.implicitWidth = items.length > 0 ? x - control.gap : 0;
        row.implicitHeight = tallest;
    }

    Component.onCompleted: control.relayout()

    Item {
        id: row

        objectName: "splitButtonGroupRow"
        height: implicitHeight
        onChildrenChanged: control.relayout()
    }
}
