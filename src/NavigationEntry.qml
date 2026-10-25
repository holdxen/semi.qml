pragma ComponentBehavior: Bound

import QtQuick
import Semi

// items 数组里的「一格」：按有没有子级装 NavigationItem 或 NavigationSub。
//
//     NavigationEntry { modelData: raw; level: 1; horizontal: false }
//
// 嵌套子级那一路**不能**写成类型引用 —— QML 引擎对「类型的定义里直接包含自己
// （哪怕隔一层文件成环）」一律拒绝：`Node is instantiated recursively`
// （qqmlimport.cpp:873 的 typeRecursionDetected；2026-10-22 在 /tmp 最小复现里钉死：
// 文件级自引与两文件互引都中枪，`Semi.X` 限定名也救不了 —— 目录/模块组件的查找走
// qqmlDirComponents，带 base 的那条路在 PreventRecursion 下直接跳过候选）。
// 出口是 `Loader { source: "X.qml" }` 字符串装载：编译期不解析、运行期按 URL 载入，
// 环当场断开（同一最小复现里验证通过）。
//
// 官方 renderItems 的规则：`Array.isArray(item.items) && item.items.length` 的条目渲染成
// SubNav（level+1 递归），否则渲染成 Item；字符串条目被 NavItem 构造器包装成
// `{ text, itemKey }`（NavItem.ts:12-24）。
Item {
    id: entry

    // 普通属性而非 required：值由 NavigationSubEntries 的创建后 Binding 投喂，
    // required 会在实例化瞬间校验、Binding 来不及喂（QWARN: Required property
    // modelData was not initialized）；且 Repeater 代理根是 Loader 时 required
    // property 与 modelData 都不注入
    property var modelData: undefined
    property int level: 0
    property bool horizontal: false
    /// NavigationSub 把子项搬进浮层时写（宽度不再吃父项）
    property bool navInDropdown: false

    /// foundation NavItem 构造器的字符串包装档 + 缺省补全
    readonly property var norm: {
        const raw = entry.modelData;
        if (raw === null || typeof raw !== "object") {
            return { text: raw, itemKey: raw, icon: "", indent: false,
                disabled: false, items: null, isCollapsed: false, dropdownProps: ({}) };
        }
        const hasItems = Array.isArray(raw.items) && raw.items.length > 0;
        return {
            text: raw.text !== undefined && raw.text !== null ? raw.text : "",
            itemKey: raw.itemKey !== undefined && raw.itemKey !== null ? raw.itemKey : "",
            icon: raw.icon !== undefined ? raw.icon : "",
            indent: raw.indent !== undefined ? raw.indent : false,
            disabled: raw.disabled !== undefined ? raw.disabled : false,
            isCollapsed: raw.isCollapsed !== undefined ? raw.isCollapsed : false,
            dropdownProps: raw.dropdownProps !== undefined && raw.dropdownProps !== null
                ? raw.dropdownProps : ({}),
            items: hasItems ? raw.items : null
        };
    }

    implicitHeight: kindLoader.implicitHeight
    // 浮层档 min-width 150 挂在隐式宽上：代理 Loader 会按 implicitWidth 接管尺寸，
    // width 里的 max(150) 会被覆盖掉（实测塌成文字宽）；也不能 width 绑 parent 再
    // 经 subColumn.implicit 回环（实测整列塌 0）
    implicitWidth: kindLoader.implicitWidth
        + (entry.navInDropdown ? Math.max(0, 150 - kindLoader.implicitWidth) : 0)
    height: implicitHeight
    width: parent && !entry.navInDropdown ? parent.width : implicitWidth

    Loader {
        id: kindLoader

        width: entry.width
        sourceComponent: entry.norm.items !== null ? subComp : itemComp
    }

    Component {
        id: itemComp

        NavigationItem {
            itemKey: entry.norm.itemKey
            text: entry.norm.text
            icon: entry.norm.icon
            indent: entry.norm.indent
            disabled: entry.norm.disabled
            level: entry.level
            // items 档折叠/水平浮层里宽度与选中皮肤要走 dropdown 档（children 档由
            // NavigationSub.placeChildren 直写，这条链管 items 档）
            navInDropdown: entry.navInDropdown
        }
    }

    Component {
        id: subComp

        NavigationSub {
            id: nestedSub

            itemKey: entry.norm.itemKey
            text: entry.norm.text
            icon: entry.norm.icon
            indent: entry.norm.indent
            disabled: entry.norm.disabled
            level: entry.level
            navInDropdown: entry.navInDropdown
            // per-item dropdownProps 经 {...item} 展开活下来（被覆盖的是 expandIcon /
            // subDropdownProps 两条，前者是同名后写覆盖、后者是不同键）；
            // expandIcon 在 items 档是死的 —— renderItems 的 `expandIcon={expandIcon}`
            // 同名后写，把 {...item} 里的覆盖成容器值（即使容器没给）
            dropdownProps: entry.norm.dropdownProps

            // 嵌套子级列表：字符串 source 断开类型递归（见文件头）
            Loader {
                id: subEntriesLoader

                source: "NavigationSubEntries.qml"
                // 列表宽度吃 subColumn：就地档由 placeChildren 给实宽；浮层档给它
                // entriesNaturalWidth（各子项**隐式**宽取大，见 NavigationSub）——
                // 浮层档若把 subColumn.width 绑回它自己的 implicitWidth（吃子项实际宽）就成环，
                // 实测整列与卡片一起塌 0，而条目还按 min-width 150 画 ⇒ 底色与卡片不一致
                width: parent ? parent.width : 0

                Binding {
                    target: subEntriesLoader.item
                    property: "entries"
                    value: entry.norm.items
                }
                Binding {
                    target: subEntriesLoader.item
                    property: "level"
                    value: entry.level + 1
                }
                Binding {
                    target: subEntriesLoader.item
                    property: "horizontal"
                    value: entry.horizontal
                }
                Binding {
                    target: subEntriesLoader.item
                    property: "navInDropdown"
                    value: nestedSub.flyoutMode
                }
            }
        }
    }
}
