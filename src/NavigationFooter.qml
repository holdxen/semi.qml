pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 导航页脚（semi-ui/navigation/Footer.tsx 的整份对应）。
//
//     NavigationFooter {
//         collapseButton: true    // 或 Component 档整只替换
//         onClicked: ...
//         Rectangle { ... }       // children 档：给了 children 且非水平时不再渲染收起按钮
//     }
//
// 官方行为（Footer.tsx:59-78）：
//   · children 不是有效元素 && collapseButton 真值 && mode !== horizontal ⇒ 渲染收起按钮
//     （collapseButton 是 ReactNode 时整只替换内置那一只）；
//   · 整个 footer div 挂 onClick —— 这里是 clicked 信号；
//   · `-footer` 皮肤：padding 16 24，竖直档左右改 8（variables.scss:54-55），
//     水平档 padding-right 0；字色 text-1；**没有描边**（$width-navigation_footer_border
//     是没人引用的死令牌）。
//   · `-footer-collapsed`：整行居中；`-collapse-btn` 宽度 100%。
//
// 与官方的差异：`style` / `className` 是 DOM 内联样式（坑 91）。
Item {
    id: control

    /// 官方 collapseButton: boolean | ReactNode —— bool 走内置收起按钮，Component 整只替换
    property var collapseButton: false
    /// 官方 collapseText: (collapsed) => ReactNode
    property var collapseText: undefined

    /// 官方 footer div 的 onClick
    signal clicked()

    /// Navigation 注入
    property bool collapsed: false
    property bool navHorizontal: false

    default property alias content: body.data

    function navigationRoot() {
        let node = control.parent;
        while (node !== null && node !== undefined) {
            // qmllint disable missing-property
            if (node.isNavigationRoot === true)
                return node;
            // qmllint enable missing-property
            node = node.parent;
        }
        return null;
    }

    readonly property bool showBuiltInCollapse: control.collapseButton !== false
        && control.collapseButton !== undefined && control.collapseButton !== null
        && body.children.length === 0 && !control.navHorizontal

    readonly property real paddingY: 16
    readonly property real paddingXLeft: control.navHorizontal ? 24 : 8
    readonly property real paddingXRight: control.navHorizontal ? 0 : 8

    implicitWidth: row.implicitWidth + control.paddingXLeft + control.paddingXRight
    implicitHeight: row.implicitHeight + control.paddingY * 2

    Row {
        id: row

        y: control.paddingY
        // 展开：左对齐（含内边距）；收起：整行居中（`-footer-collapsed { justify-content: center }`）
        x: control.collapsed
            ? Math.max(0, (control.parent.width - width) / 2) : control.paddingXLeft
        spacing: 12

        Item {
            id: body
        }

        Loader {
            visible: sourceComponent !== null
            sourceComponent: control.showBuiltInCollapse ? collapseBtnComponent : null
        }
    }

    Component {
        id: collapseBtnComponent

        NavigationCollapseButton {
            collapsed: control.collapsed
            collapseText: control.collapseText
            // 官方 CollapseButton 的 onClick 就是 context.onCollapseChange ——
            // 容器 handleCollapseChange 不读参数、自己翻内部态（见 Navigation.qml）
            onClicked: {
                const root = control.navigationRoot();
                if (root !== null)
                    root.toggleCollapse();
            }
        }
    }

    TapHandler {
        onTapped: control.clicked()
    }
}
