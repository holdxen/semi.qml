import QtQuick

// 下拉菜单的分隔线。官方 `dropdownDivider.tsx`（Dropdown.Divider）—— 没有内容，一条线。
//
//     Dropdown { DropdownItem { text: "复制" } DropdownDivider {} DropdownItem { text: "删除" } }
//
// 规格（dropdown.scss + variables.scss）：`.semi-dropdown-divider` 高 **1px**、宽 100%、
// 色 `--semi-color-border`、`margin: 4px 0`（$spacing-dropdown_seperator-marginY = extra-tight）
// ⇒ 在流里占 9px（旧端口把这条 9 直接写成条目高度，是对的，只是没拆出来）。
Item {
    id: control

    /// 给 Dropdown 认「有子项」用的标记（官方它是 div，不进键盘名单）
    readonly property bool isDropdownDivider: true

    width: parent ? parent.width : 0
    height: 9                                        // 1px 线 + 上下各 4
    implicitHeight: height

    Rectangle {
        objectName: "dropdownDividerLine"

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.current.colorBorder
    }
}
