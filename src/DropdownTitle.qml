import QtQuick

// 下拉菜单的分组标题。官方 `dropdownTitle.tsx`（Dropdown.Title）—— 只有 `className` / `style`
// 两条 prop，内容走 children ⇒ 端口就一个 `text`。
//
//     Dropdown { DropdownTitle { text: "文件" } DropdownItem { text: "新建" } }
//
// 规格（dropdown.scss + variables.scss）：字色 `--semi-color-text-2`、字号 12 / 行高 16
// （@include font-size-small）、`padding: 8 16 4`（top / 左右 / bottom 三个不同值）⇒ 一条高 28；
// `cursor: default`。对勾档（`-title-withTick`）左内边距变 **31**，与条目里
// 「12 padding + 12 对勾 + 9 间距 = 33」那条约文字左边缘对齐（官方自己差 2px，照抄）。
//
// 这一件不参与键盘导航（官方它是 `<div>`，不是 `<li role="menuitem">`）。
Item {
    id: control

    property string text: ""

    /// 给 Dropdown 认「有子项」用的标记（官方它是 div，不进键盘名单）
    readonly property bool isDropdownTitle: true

    // 与 DropdownItem 同一份口径：宿主在 refreshItems 里反向收养（条目自己往上走 parent 走不到）
    property var dropdownHost: null
    readonly property bool realShowTick: control.dropdownHost !== null
        ? control.dropdownHost.showTick : false

    width: parent ? parent.width : implicitWidth
    implicitWidth: control.padLeft + metrics.width + 16
    height: 28                                       // 8 + 16 + 4
    implicitHeight: height

    readonly property real padLeft: control.realShowTick ? 31 : 16

    Text {
        id: metrics

        objectName: "dropdownTitleText"

        anchors.left: parent.left
        anchors.leftMargin: control.padLeft
        anchors.verticalCenter: parent.verticalCenter
        text: control.text
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        lineHeight: 16
        lineHeightMode: Text.FixedHeight
    }

}
