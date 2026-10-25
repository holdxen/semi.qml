pragma ComponentBehavior: Bound

import QtQuick

// 可折叠容器。展开时高度跟着内容走，收起时收到 collapseHeight，中间有高度动画。
//
//     Collapsible {
//         isOpen: expanded
//         Rectangle { implicitHeight: 120; implicitWidth: 300 }
//     }
//
// 对应 Semi 的 Collapsible：受控的 isOpen、可配 collapseHeight、可选渐隐。
//
// 过渡只在 isOpen 变的那一拍挂（官方 `transitionDuration: motion && isTransitioning
// ? duration : 0`，isTransitioning 仅 isOpen 变化时置真）：内容自己长高/换数据是瞬时跳，
// 挂载时就已经展开的也不重放动画。
//
// 两条曲线照官方 animation.scss：
//   height  = cubic-bezier(0.25, 0.1, 0.25, 1)（CSS ease）
//   opacity = var(--semi-transition_function-easeIn) = ease-in = cubic-bezier(0.42, 0, 1, 1)
// Qt 的 easing.bezierCurve 每段要六个值（坑 134），补上 CSS 隐含的终点 (1,1)。
Item {
    id: control

    default property alias content: body.data

    property bool isOpen: false
    property int collapseHeight: 0
    property bool fade: true
    // $transition_duration-collapsible-height / -opacity 都是 250ms
    property int duration: 250

    readonly property var heightCurve: [0.25, 0.1, 0.25, 1, 1, 1]
    readonly property var opacityCurve: [0.42, 0, 1, 1, 1, 1]

    signal toggled(bool isOpen)

    // 官方 domHeight = 内层 overflow:hidden 容器的 scrollHeight —— 内容**底边**（含子项自己的
    // y 偏移，如 NavigationSub 首项上方那 8），不是子项包围盒的高。取高会让最后一条裁掉那 8px、
    // 与后面条目的间距一起塌掉（实测子项都 36、sub 却只有 116 而内容到 124）。
    readonly property real fullHeight: body.childrenRect.y + body.childrenRect.height

    property real currentHeight: 0

    implicitWidth: body.childrenRect.width
    implicitHeight: control.currentHeight
    clip: true

    Behavior on currentHeight {
        NumberAnimation {
            id: heightAnim

            // duration 由 syncHeight 现定（isOpen 变 250 / 其余 0），Behavior 起手时读
            easing.bezierCurve: control.heightCurve
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: control.duration
            easing.bezierCurve: control.opacityCurve
        }
    }

    onIsOpenChanged: control.syncHeight(true)
    onFullHeightChanged: control.syncHeight(false)
    onCollapseHeightChanged: control.syncHeight(false)
    Component.onCompleted: control.syncHeight(false)

    function syncHeight(animated) {
        heightAnim.duration = animated === true ? control.duration : 0;
        control.currentHeight = control.isOpen ? control.fullHeight : control.collapseHeight;
    }

    function toggle() {
        control.isOpen = !control.isOpen;
        control.toggled(control.isOpen);
    }

    // 收起且没有留高度时整体淡出，避免露出一条空带
    opacity: control.fade && !control.isOpen && control.collapseHeight === 0 ? 0 : 1

    Item {
        id: body

        width: control.width
        height: childrenRect.height
    }
}
