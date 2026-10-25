import QtQuick

// 折叠面板容器。子项是 CollapsePanel；accordion 为 true 时同时只展开一个。
//
//     Collapse {
//         CollapsePanel { title: "第一项"; Text { text: "内容" } }
//         CollapsePanel { title: "第二项"; Text { text: "内容" } }
//     }
Column {
    id: control

    property bool accordion: false

    default property alias content: control.data

    spacing: 0

    // 手风琴模式下收到某个面板展开时，收起其余面板
    function handleExpanded(panel) {
        if (!control.accordion)
            return;
        for (let i = 0; i < control.children.length; ++i) {
            const child = control.children[i];
            if (child === panel)
                continue;
            if (child && child.expanded !== undefined)
                child.expanded = false;
        }
    }
}
