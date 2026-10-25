pragma ComponentBehavior: Bound

import QtQuick

// 可拖动移动的容器。内容照常摆放，按住就能挪位置。
//
//     DragMove {
//         Rectangle { width: 120; height: 80; color: ... }
//     }
//
// 对应 Semi 的 DragMove：默认约束在父容器内，可以关掉；移动过程对外发信号。
Item {
    id: control

    default property alias content: body.data

    // 名字没叫 enabled：那是 QQuickItem 自己的属性，会遮蔽
    property bool movable: true
    property bool constrainToParent: true
    property bool isMoving: false

    signal moveStarted
    signal moved
    signal moveFinished

    implicitWidth: body.childrenRect.width
    implicitHeight: body.childrenRect.height

    function moveTo(nextX, nextY) {
        let x = nextX;
        let y = nextY;
        if (control.constrainToParent && control.parent) {
            x = Math.max(0, Math.min(control.parent.width - control.width, x));
            y = Math.max(0, Math.min(control.parent.height - control.height, y));
        }
        control.x = x;
        control.y = y;
        control.moved();
    }

    Item {
        id: body

        anchors.fill: parent
    }

    DragHandler {
        id: dragHandler

        target: null
        enabled: control.movable
        property real startX: 0
        property real startY: 0

        onActiveChanged: {
            control.isMoving = active;
            if (active) {
                startX = control.x;
                startY = control.y;
                control.moveStarted();
            } else {
                control.moveFinished();
            }
        }

        onTranslationChanged: {
            if (!active)
                return;

            control.moveTo(startX + translation.x, startY + translation.y);
        }
    }
}
