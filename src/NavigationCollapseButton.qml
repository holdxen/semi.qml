pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 底部「收起侧边栏」按钮（semi-ui/navigation/CollapseButton.tsx 的整份对应）。
//
//     NavigationCollapseButton { collapsed: nav.isCollapsed; onClicked: to => ... }
//
// 官方那一只就是 Button（tertiary + borderless + IconSidebar）外面套一层
// `.semi-navigation-collapse-btn`：
//   · 展开态：Button 带文案 —— `collapseText(isCollapsed)` 优先，缺省吃 locale
//     「收起侧边栏 / 展开侧边栏」（locale/source/zh_CN.ts:95-98，本库没有 locale 机制，
//     中文串写死，同其他组件）；
//   · 收起态：只剩图标的 Button 再包一层 Tooltip（position right），文案同一份；
//   · 竖直档按钮的左右内边距被 `-collapse-btn > .semi-button { padding: 0 8 }` 覆盖成 8，
//     字色 text-1（footer 自己的颜色继承）。
//   · 官方 onClick 收到的参数是 `!isCollapsed`，而 Navigation.handleCollapseChange
//     **根本不读这个参数**（它自己 `!state.isCollapsed`）—— 照抄：这里照传，容器照忽略。
//
// 与官方的差异：
//   · `prefixCls` 是 DOM 类名前缀，不搬（坑 91）；
//   · Button 的 `icon: <IconSidebar />` 是 ReactNode，这里收图标名字符串 "sidebar"。
Item {
    id: control

    /// 官方 isCollapsed（由 NavigationFooter 从容器状态注入）
    property bool collapsed: false
    /// 官方 collapseText: (isCollapsed) => ReactNode；undefined 时落回中文缺省
    property var collapseText: undefined

    /// 官方 onClick(!isCollapsed)
    signal clicked(bool toCollapsed)

    readonly property string label: {
        if (typeof control.collapseText === "function")
            return String(control.collapseText(control.collapsed))
        return control.collapsed ? "展开侧边栏" : "收起侧边栏"
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 0

        Button {
            id: btn

            tone: Enums.Tertiary
            variant: Enums.Borderless
            icon: "sidebar"
            text: control.collapsed ? "" : control.label

            onClicked: control.clicked(!control.collapsed)
        }
    }

    // 收起态的 Tooltip（官方 CollapseButton.tsx:39-42：只包收起态，position right）
    Tooltip {
        target: btn

        text: control.label
        position: Enums.Right
        condition: control.collapsed && control.label !== ""
    }
}
