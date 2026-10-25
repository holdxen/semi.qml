pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 翻页器省略号浮层里的那一列页码（semi-ui/pagination/index.tsx:402-439 renderRestPageList，
// 皮肤 semi.css 17371-17391）。
//
// 官方用 react-window 的 FixedSizeList 虚拟化它：宽写死 78、行高写死 32、可视高
// `count >= 5 ? 5 * 32 : count * 32`，外层 `.semi-page-rest-list` 上下各 4 的内边距。
// 这里换成 ListView：可视高与裁切跟官方一致，行只是普通 delegate，不再需要 itemSize。
//
// 行没有颜色规则：`.semi-page-rest-item` 只给 height/line-height/display/justify-content，
// 字号 14 与字色都来自承载它的浮层（`.semi-popover-wrapper` 的 font-size-regular +
// body 继承来的 text-0，见 src/Popover.qml 文件头）。
// 悬浮 fill-0、按下 fill-1，两档都是瞬时（animation.scss 的 duration 恒为 0）。
//
// 这一列在官方有两个使用处：默认档省略号（内容是这一侧剩下的页码）与迷你档
// hoverShowPageSelect（内容是**全部**页码）。点任意一行等价于官方 goPage(page)。
Item {
    id: control

    property var list: []
    signal jumped(int page)

    readonly property int rowCount: control.list ? control.list.length : 0
    readonly property real itemHeight: 32                   // index.tsx:423 itemHeight
    readonly property real listWidth: 78                    // index.tsx:432 width
    // count >= 5 时只给 5 行的高度，其余靠滚动
    readonly property real viewHeight: control.rowCount >= 5
        ? control.itemHeight * 5 : control.itemHeight * control.rowCount

    implicitWidth: control.listWidth
    implicitHeight: control.viewHeight + Theme.current.spacingExtraTight * 2

    ListView {
        id: restView

        objectName: "paginationRestList"
        y: Theme.current.spacingExtraTight
        width: control.listWidth
        height: control.viewHeight
        clip: true
        interactive: restView.contentHeight > restView.height
        boundsBehavior: Flickable.StopAtBounds
        model: control.list

        delegate: Rectangle {
            id: restRow

            objectName: "paginationRestItem"
            required property var modelData
            required property int index

            width: restView.width
            height: control.itemHeight
            color: restTap.pressed ? Theme.current.colorFill1
                : (restHover.hovered ? Theme.current.colorFill0 : "transparent")

            Text {
                objectName: "paginationRestText"
                anchors.centerIn: parent
                text: String(restRow.modelData)
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
            }

            HoverHandler {
                id: restHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: restTap

                onTapped: control.jumped(Number(restRow.modelData))
            }
        }
    }
}
