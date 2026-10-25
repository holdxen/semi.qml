pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 事件条的内容。官方 `EventObject.children` 是一段 ReactNode，组件自己一个字都不画
// （`-event-day` / `-event-allday` / `-event-month` 三档在编译出的 CSS 里只有定位，
//  没有任何底色、圆角、内边距、字号 —— 看到的样式全来自用户给的那段节点）。
//
// 端口的两档：
//   · children 是 Component ⇒ Loader 铺满这一条，并注入 `event`（节点里用
//     `required property var event` 或直接 `property var event` 接当前事件）；
//   · children 是字符串 ⇒ 排一行 Text（官方没有这一档，本库「字符串或 Component」的惯例）。
Item {
    id: control

    property var event: null

    readonly property bool isComponent: control.event !== null && control.event !== undefined
        && control.event.children !== undefined && typeof control.event.children !== "string"

    Loader {
        objectName: "calendarEventNode"
        anchors.fill: parent
        active: control.isComponent
        sourceComponent: control.isComponent ? control.event.children : null
        onLoaded: item.event = control.event
    }

    Text {
        objectName: "calendarEventText"
        anchors.fill: parent
        visible: control.event !== null && control.event !== undefined
            && typeof control.event.children === "string"
        text: visible ? control.event.children : ""
        color: Theme.current.colorText0
        font.pixelSize: Theme.current.fontSizeRegular
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
