import QtQuick
import Semi

// 会话操作区的小图标钮（复制/点赞/点踩/重置/删除）。
// 官方是 Button(theme=borderless, type=tertiary)，但 chat.scss:193-203 把
// hover 底色改成 transparent、字色改成 text-2 → hover text-0（Button 缺省是
// fill-0 / text-1），两处都对不上 ⇒ 按 chat.scss 的令牌直接画。
Item {
    id: root

    property string icon: ""
    property bool flipped: false          // 点踩图标上下翻转（chat.scss:177 scaleY(-1)）

    signal clicked

    implicitWidth: 16
    implicitHeight: 16

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: 16
        color: hover.hovered ? Theme.current.colorText0 : Theme.current.colorText2

        // -icon-flip：上下颠倒（轴心放图标中心，否则 yScale=-1 会翻出界）
        transform: Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            yScale: root.flipped ? -1 : 1
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
