pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 未实现组件的占位页。侧边栏里这些项是灰的、点不进来，
// 这个页面主要用于直接改 currentDir 或将来放开时兜底。
Item {
    id: control

    width: parent ? parent.width : 0
    implicitHeight: 200

    Column {
        anchors.centerIn: parent
        spacing: 12

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "image"
            size: 40
            color: Theme.current.colorText2
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("这个组件还没实现")
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }
}
