pragma ComponentBehavior: Bound

import QtQuick

// entries 数组的递归渲染（index.tsx 的 renderItems + foundation NavItem 的字符串包装的对应）。
//
//     NavigationSubEntries { entries: nav.items; level: 0; horizontal: nav.horizontal }
//
// 官方 renderItems 的规则：`Array.isArray(item.items) && item.items.length` 的条目渲染成
// SubNav（level+1 递归），否则渲染成 Item；字符串条目被 NavItem 构造器包装成
// `{ text, itemKey }`（NavItem.ts:12-24）。
//
// items 档的 level 自动下发（renderItems 的第二个参数）；children 档官方不发 level，
// 由使用方手写 —— 两种模式这里都由「谁创建谁给 level」，同官方。
//
// 递归经 Loader 字符串 source 断开（本文件 Loader → NavigationEntry → NavigationSub →
// 本文件），见 NavigationEntry.qml 文件头。
Item {
    id: control

    /// 原始条目数组（string | object，可嵌套）
    property var entries: []
    property int level: 0
    property bool horizontal: false
    /// NavigationSub 把子项搬进浮层时写（宽度不再吃父项）
    property bool navInDropdown: false

    readonly property Item listHost: control.horizontal ? rowHost : columnHost
    readonly property int count: control.horizontal ? rowRepeater.count : columnRepeater.count

    // 浮层档的列宽：吃各条目的**隐式**宽（NavigationEntry 的隐式宽已含 min-width 150），
    // 不能吃 columnHost.implicitWidth —— 位置器的隐式宽吃子项**实际**宽，而实际宽又要回过来
    // 读列宽，成环当场塌 0（实测整列与卡片都是 0 宽）
    readonly property real entriesNaturalWidth: {
        let widest = 0;
        const n = control.horizontal ? rowRepeater.count : columnRepeater.count;
        for (let i = 0; i < n; ++i) {
            const loader = control.horizontal ? rowRepeater.itemAt(i) : columnRepeater.itemAt(i);
            // qmllint disable missing-property
            if (loader !== null && loader.item !== undefined && loader.item
                && loader.item.implicitWidth > widest)
                widest = loader.item.implicitWidth;
            // qmllint enable missing-property
        }
        return widest;
    }

    implicitHeight: control.horizontal ? rowHost.implicitHeight : columnHost.implicitHeight
    implicitWidth: control.horizontal ? rowHost.implicitWidth : columnHost.implicitWidth
    width: control.navInDropdown ? control.entriesNaturalWidth
        : (parent ? parent.width : control.implicitWidth)
    height: implicitHeight

    Column {
        id: columnHost

        visible: !control.horizontal
        width: control.width
        spacing: 8                          // li 的 margin-bottom tight（Column 间距不落末位）

        Repeater {
            id: columnRepeater

            model: control.horizontal ? [] : control.entries

            delegate: Loader {
                id: columnEntryLoader

                // Repeater 的代理根若是 Loader 而非 Item，QML 不会注入 modelData
                // （实测 QWARN: Required property modelData was not initialized）：
                // index 走 required property 注入，modelData 按下标自己取
                required property int index
                property var modelData: control.entries[index]

                source: "NavigationEntry.qml"

                // 浮层档：条目拉伸到整列宽（官方 `.semi-dropdown-item` 是块级、
                // `.semi-navigation-item` 只有 min-width 150 ⇒ 悬浮底色 == 卡片内宽）。
                // 这里读 entriesNaturalWidth 而不是 parent.width —— 后者就是本列宽，
                // 而列宽又要吃子项实际宽，成环当场塌 0（实测）。
                // Loader 的 item 在 QML 侧只是 QObject，取尺寸要放宽类型检查
                // qmllint disable missing-property
                width: control.navInDropdown
                    ? control.entriesNaturalWidth
                    : (parent ? parent.width : 0)
                height: item ? item.implicitHeight : 0
                // qmllint enable missing-property
                Binding {
                    target: columnEntryLoader.item
                    property: "modelData"
                    value: columnEntryLoader.modelData
                }
                Binding {
                    target: columnEntryLoader.item
                    property: "level"
                    value: control.level
                }
                Binding {
                    target: columnEntryLoader.item
                    property: "horizontal"
                    value: control.horizontal
                }
                Binding {
                    target: columnEntryLoader.item
                    property: "navInDropdown"
                    value: control.navInDropdown
                }
            }
        }
    }

    Row {
        id: rowHost

        visible: control.horizontal
        spacing: 8                          // 非末位 margin-right tight

        Repeater {
            id: rowRepeater

            model: control.horizontal ? control.entries : []

            delegate: Loader {
                id: rowEntryLoader

                // Repeater 的代理根若是 Loader 而非 Item，QML 不会注入 modelData
                // （实测 QWARN: Required property modelData was not initialized）：
                // index 走 required property 注入，modelData 按下标自己取
                required property int index
                property var modelData: control.entries[index]

                source: "NavigationEntry.qml"

                // 高度不能绑 parent.height：Row 的高度吃子项高度，绑回去就是环
                // （实测整条 Row 布局塌成 0），Loader 不写尺寸时自己吃 item 的隐式尺寸
                // 浮层档同竖直档：拉伸到整列宽，底色与卡片同宽
                // qmllint disable missing-property
                width: control.navInDropdown
                    ? control.entriesNaturalWidth
                    : (item ? item.implicitWidth : 0)
                // qmllint enable missing-property
                Binding {
                    target: rowEntryLoader.item
                    property: "modelData"
                    value: rowEntryLoader.modelData
                }
                Binding {
                    target: rowEntryLoader.item
                    property: "level"
                    value: control.level
                }
                Binding {
                    target: rowEntryLoader.item
                    property: "horizontal"
                    value: control.horizontal
                }
                Binding {
                    target: rowEntryLoader.item
                    property: "navInDropdown"
                    value: control.navInDropdown
                }
            }
        }
    }
}
