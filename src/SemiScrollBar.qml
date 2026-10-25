pragma ComponentBehavior: Bound

import QtQuick

// 滚动条。8px 粗、圆角 6px 的滑块，轨道透明；默认不显眼，鼠标进到滚动区域才浮出来。
//
//     Flickable { id: view; anchors.fill: parent; ... }
//
//     SemiScrollBar {
//         flickable: view
//         anchors.right: view.right
//         anchors.top: view.top
//         anchors.bottom: view.bottom
//     }
//
// 规格取自 Semi 的 `.semi-light-scrollbar`（semi-foundation/base/base.scss）：
//   轨道与角落透明；滑块 8px、圆角 6px；容器悬停时用 fill-2，滑块自身悬停时用 fill-1。
//
// 位置由调用方摆 —— QML 里做不出 Controls 那种 `ScrollBar.vertical:` 附加属性，
// 所以这里不做自动锚定，免得和调用方的布局打架。
Item {
    id: control

    property Flickable flickable: null
    property int orientation: Qt.Vertical
    property int thickness: 8
    property int radius: 6
    property real minThumbLength: 24
    property bool autoHide: true

    readonly property bool vertical: control.orientation === Qt.Vertical
    readonly property real contentLength: {
        if (!control.flickable)
            return 0;
        return control.vertical ? control.flickable.contentHeight : control.flickable.contentWidth;
    }
    readonly property real viewLength: {
        if (!control.flickable)
            return 0;
        return control.vertical ? control.flickable.height : control.flickable.width;
    }
    readonly property real scrollOffset: {
        if (!control.flickable)
            return 0;
        return control.vertical ? control.flickable.contentY : control.flickable.contentX;
    }
    readonly property real trackLength: control.vertical ? control.height : control.width
    readonly property bool needed: control.contentLength > control.viewLength && control.trackLength > 0

    readonly property real thumbLength: {
        if (!control.needed)
            return 0;
        const ratio = control.viewLength / control.contentLength;
        return Math.min(control.trackLength, Math.max(control.minThumbLength, control.trackLength * ratio));
    }
    readonly property real thumbPosition: {
        const range = control.contentLength - control.viewLength;
        const trackRange = control.trackLength - control.thumbLength;
        if (range <= 0 || trackRange <= 0)
            return 0;
        return control.scrollOffset / range * trackRange;
    }

    property real dragStartOffset: 0

    implicitWidth: control.thickness
    implicitHeight: control.thickness
    visible: control.needed

    // 把鼠标移进滚动区域时浮出滑块（handler 挂在 flickable 上）
    HoverHandler {
        id: areaHover
        parent: control.flickable !== null ? control.flickable : control
    }

    // 把滑块位移换算成内容位移。offset 是相对本次拖拽起点的位移，
    // 所以基准要用按下那一刻的 scrollOffset，不能每帧累加。
    function scrollTo(baseOffset, delta) {
        if (!control.flickable || !control.needed)
            return;
        const range = control.contentLength - control.viewLength;
        const trackRange = control.trackLength - control.thumbLength;
        if (trackRange <= 0)
            return;

        const next = baseOffset + delta / trackRange * range;
        const clamped = Math.max(0, Math.min(range, next));
        if (control.vertical)
            control.flickable.contentY = clamped;
        else
            control.flickable.contentX = clamped;
    }

    Rectangle {
        id: thumb

        width: control.vertical ? control.thickness : control.thumbLength
        height: control.vertical ? control.thumbLength : control.thickness
        x: control.vertical ? 0 : control.thumbPosition
        y: control.vertical ? control.thumbPosition : 0
        radius: control.radius
        color: thumbHover.hovered ? Theme.current.colorFill1 : Theme.current.colorFill2
        opacity: !control.autoHide || areaHover.hovered || thumbHover.hovered || dragHandler.active
            ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.current.durationFast }
        }

        HoverHandler {
            id: thumbHover
            cursorShape: Qt.ArrowCursor
        }

        DragHandler {
            id: dragHandler

            target: null

            onActiveChanged: {
                if (active)
                    control.dragStartOffset = control.scrollOffset;
            }

            onTranslationChanged: {
                if (active)
                    control.scrollTo(control.dragStartOffset,
                        control.vertical ? translation.y : translation.x);
            }
        }
    }
}
