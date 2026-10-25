pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 侧边/顶部导航容器（semi-ui/navigation/index.tsx + foundation/foundation.ts 的整份对应）。
//
//     Navigation {
//         header: NavigationHeader { logo: semiLogo; text: "Semi 运营后台" }
//         footer: NavigationFooter { collapseButton: true }
//         items: [
//             { itemKey: "user", text: "用户管理", icon: "avatar" },
//             { itemKey: "job", text: "任务平台", icon: "tree",
//               items: ["任务管理", "用户任务查询"] }
//         ]
//     }
//
//     // children 档（官方 JSX 写法的对应）：children 里直接写 Item/Sub，
//     // header / footer 用同名属性传（官方是扫 children 里的 Nav.Header / Nav.Footer）
//     Navigation {
//         NavigationItem { itemKey: "a"; text: "A" }
//         NavigationSub { itemKey: "p"; text: "P"; NavigationItem { itemKey: "c"; text: "C" } }
//     }
//
// 状态机（foundation.ts 逐条对应）：
//   · selectedKeys / openKeys / isCollapsed 三组「受控 or 非受控」：prop 给了（非
//     undefined/null）就是受控；受控档点击只发回调不改内部状态。
//     `openKeysIsControlled` 还多两道闸：mode vertical 且未折叠（index.tsx:404）——
//     折叠/水平档的浮层退回 hover 驱动，内部 openKeys 照改。
//   · init（constructor 与 didUpdate 两路）：selectedKeys = prop || default || []，
//     再**无去重地**拼上每个选中 key 的**零级父 key**（selectLevelZeroParentKeys，
//     itemKeysMap[key][0]）；openKeys = prop || default || []，且「没给 openKeys 数组、
//     竖直档、给了 selectedKeys 数组」时并上**全部祖先 key**（getShouldOpenKeys）。
//   · 点选一项：未受控且原先未选中 ⇒ selectedKeys 整表**替换**成 [key, 零级父]；
//     「原先未选中」才发 onSelect，onClick 每次都发（itemFoundation.handleClick）。
//   · 点 sub 标题：翻转 openKeys（点击处必在标题上；官方用 titleRef.contains 判定，
//     点 sub-wrap 其它地方一律当收起 —— QML 里 TapHandler 只挂在标题行上，等价）；
//     发 onOpenChange + onClick。浮层显隐（折叠/水平）走 handleDropdownVisibleChange，
//     只发 onOpenChange。
//   · 收起按钮：内部翻转（受控档不翻），onCollapseChange 恒发。
//   · componentDidUpdate：items 变 ⇒ 整个 init 重来（**非受控档的选中态也会被打回
//     defaultSelectedKeys**，官方如此）；selectedKeys prop 变 ⇒ 替换内部表（这份带去重）
//     并按 getWillOpenKeys 重算 openKeys；openKeys prop 变 ⇒ 直接替换。
//
// 皮肤（navigation.scss + variables.scss）：
//   容器：宽 240 / 折叠 60（width 200ms cubic-bezier(.62,.05,.36,.95)）、左右内边距 8
//   （水平档覆盖成 24，scss :597-598）、
//   右侧 1px 描边（水平档改底部 1px）、底色 --semi-color-nav-bg、overflow hidden；
//   列表区 padding-top 12、竖直档可纵向滚动；列表项间距 8（li margin-bottom）；
//   header 上 32 下 36（见 NavigationHeader）；footer padding 16 8（见 NavigationFooter）。
//
// 上游的坑与死代码（照抄，不"修"）：
//   · `multiple` / `onDeselect` 在 propTypes 与接口里挂着但**全仓无读者**；
//     `collapseIcon` 同样只在 propTypes 里；`renderWrapper` / `getPopupContainer` /
//     `prefixCls` 是 React/DOM 侧无落点（`bodyStyle` 只认 `height`，见下面「与官方的差异」）；
//   · 文档表里 defaultOpenKeys/defaultSelectedKeys 写 `[]`，源码 defaultProps 里这两条
//     **没有**（注释掉了，index.tsx:175-176）—— 缺省是 undefined，等价空表；
//   · `buildItemKeysMap` 只收**真值** itemKey（foundation.ts:81 `if (itemKey)`）——
//     空串 key 进不了 map，选中它不会联动父级；
//   · init 拼零级父 key 时不去重（foundation.ts:127），只有点击路径过 Set。
//
// 与官方的差异（React / CSS 在 QML 侧无处落地，逐条）：
//   · `bodyStyle` 官方是整张 CSSProperties 写在 `.semi-navigation-list-wrapper` 上，端口只认
//     `height` 一个键 ⇒ 直接就是列表区高度，容器随之 header + body + footer（官方各 demo
//     都用它给列表定高，容器自己没有 height 规则）；
//   · `header` / `footer` 官方既收 ReactNode 又收配置对象、还能混在 children 里被扫走；
//     这里是两个属性槽（children 档写在 header:/footer: 上），不扫 children；
//   · QML 没有 React context：选中/折叠/展开状态由本容器**走树写进子项的注入属性**
//     （navSelected / navCollapsed / isOpen …），子项自己不问祖先（跨对象绑定不重算，
//     见旧版注记）；
//   · 折叠档 sub 的浮层用本库 Popover（官方 Dropdown，同 Tooltip 基座）；`subDropdownProps`
//     只接 `position` 一档；
//   · `domEvent` 参数没有落点，回调里恒为 null；
//   · items 与 children 官方可以同时给（items 渲染在前），这里同样两路都渲染；
//   · items 档的递归列表走 NavigationSubEntries（跨文件互引），children 档仍是直接子项。
Item {
    id: control

    readonly property bool isNavigationRoot: true

    default property alias content: contentHost.data
    property alias header: headerSlot.data
    property alias footer: footerSlot.data

    // ---------------------------------------------------------------- 官方 NavProps
    property var items: undefined
    property var isCollapsed: undefined            // 受控：给了就是受控
    property bool defaultIsCollapsed: false
    property var selectedKeys: undefined           // 受控
    property var defaultSelectedKeys: undefined
    property var openKeys: undefined               // 受控
    property var defaultOpenKeys: undefined
    property int mode: Enums.DirectionVertical
    property bool limitIndent: true
    property string toggleIconPosition: "right"
    property var expandIcon: undefined
    property bool subNavMotion: true
    property int subNavOpenDelay: 0
    property int subNavCloseDelay: 100
    property int tooltipShowDelay: 0
    property int tooltipHideDelay: 100
    property var subDropdownProps: ({})
    /// 官方 bodyStyle（CSSProperties）：写在 `.semi-navigation-list-wrapper` 那一层上。
    /// QML 侧只有 `height` 一个键有落点 —— 它就是**列表区的高度**（官方各 demo 都用它给
    /// 列表定高，容器自己是内容高度）；其余键是 DOM 内联样式（坑 91 口径，同 Modal /
    /// SideSheet 各认几键）。容器的 `style` 对应 QML 的 `width` / `height` 本身。
    property var bodyStyle: undefined

    // ---------------------------------------------------------------- 官方回调
    /// 官方 onSelect({ itemKey, selectedKeys, selectedItems, domEvent })
    signal select(var data)
    /// 官方 onClick({ itemKey, text | openKeys…, domEvent })
    signal click(var data)
    /// 官方 onOpenChange({ itemKey, openKeys, isOpen, domEvent })
    signal openChange(var data)
    /// 官方 onCollapseChange(isCollapsed)
    signal collapseChange(bool isCollapsed)

    // ---------------------------------------------------------------- 内部状态（官方 NavState）
    property var _selectedKeys: []
    property var _openKeys: []
    property bool _isCollapsed: false
    property var _itemKeysMap: ({})

    readonly property bool collapsedControlled: control.isCollapsed !== undefined
        && control.isCollapsed !== null
    readonly property bool selectedKeysControlled: control.selectedKeys !== undefined
        && control.selectedKeys !== null
    readonly property bool openKeysControlled: control.openKeys !== undefined
        && control.openKeys !== null
    /// index.tsx:404 —— 受控 openKeys 只在「竖直 + 未折叠」档接管浮层
    readonly property bool openKeysIsControlled: control.openKeysControlled
        && !control.horizontal && !control._isCollapsed
    readonly property bool horizontal: control.mode === Enums.DirectionHorizontal
    readonly property bool itemsMode: Array.isArray(control.items) && control.items.length > 0

    readonly property real expandedWidth: 240       // $width-navigation_container_base
    readonly property real collapsedWidth: 60       // $width-navigation_container_collapsed

    property real _currentWidth: control._isCollapsed ? control.collapsedWidth : control.expandedWidth

    /// `bodyStyle.height`（没给或读不到数字时 -1）—— 官方这一层是 `.semi-navigation-list-wrapper`
    readonly property real _bodyStyleHeight: control.bodyStyle !== undefined && control.bodyStyle !== null
        && control.bodyStyle.height !== undefined && control.bodyStyle.height !== null
        ? Number(control.bodyStyle.height) : -1
    /// 列表区高度：给了 bodyStyle.height 就以它为准（官方 demo 全部这么定高），
    /// 否则回落到「容器高 − header − footer」
    readonly property real _listHeight: control.horizontal ? control.height
        : (control._bodyStyleHeight >= 0 ? control._bodyStyleHeight
            : Math.max(0, control.height - headerArea.height - footerArea.height))

    implicitWidth: control.horizontal ? 0 : control._currentWidth
    // 官方容器 inline-flex、没有 height 规则 ⇒ 竖直档容器高 = header + body + footer（body 来自
    // bodyStyle）；没给 bodyStyle 时端口兜 400，使用方显式给了 height 仍以它为准
    implicitHeight: control.horizontal ? 60 : (control._bodyStyleHeight >= 0
        ? headerArea.height + control._bodyStyleHeight + footerArea.height : 400)

    Behavior on _currentWidth {
        NumberAnimation {
            duration: 200                          // $motion-navigation_width
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.62, 0.05, 0.36, 0.95, 1, 1]
        }
    }

    // ---------------------------------------------------------------- foundation：init
    /// itemFoundation.isValidKey：string | number 且非 null —— `''` 与 0 都算有效（点击可选中）；
    /// 入表（buildItemKeysMap）另有一道真值闸，两处分开照抄
    function _isValidKey(key) {
        return key !== undefined && key !== null
            && (typeof key === "string" || typeof key === "number");
    }

    function _levelZeroParents(keys) {
        const out = [];
        for (let i = 0; i < keys.length; ++i) {
            const parents = control._itemKeysMap[keys[i]];
            if (Array.isArray(parents) && parents.length && parents[0] !== undefined
                && parents[0] !== null) {
                out.push(parents[0]);
            }
        }
        return out;
    }

    function _shouldOpenKeys(keys) {
        const out = [];
        for (let i = 0; i < keys.length; ++i) {
            const parents = control._itemKeysMap[keys[i]];
            if (Array.isArray(parents)) {
                for (let j = 0; j < parents.length; ++j)
                    out.push(parents[j]);
            }
        }
        return out;
    }

    /// getWillOpenKeys（foundation.ts:174-188）：读的是「当前内部 openKeys」那份 state
    function _willOpenKeys() {
        const hasOpenArray = Array.isArray(control.defaultOpenKeys)
            || Array.isArray(control.openKeys);
        let will = control.openKeys || control.defaultOpenKeys || [];
        if (!hasOpenArray && !control.horizontal
            && (Array.isArray(control.defaultSelectedKeys) || Array.isArray(control.selectedKeys))) {
            const current = Array.isArray(control.selectedKeys)
                ? control.selectedKeys : control.defaultSelectedKeys;
            will = Array.from(new Set(
                control._openKeys.concat(control._shouldOpenKeys(current))));
        }
        return will.slice();
    }

    /// foundation init（constructor 与 didUpdate 共用一份语义）
    function init() {
        control._itemKeysMap = {};
        if (control.itemsMode)
            control._mapFromItems(control.items, [], control._itemKeysMap);
        else
            control._mapFromChildren(control, [], control._itemKeysMap);
        let willSelected = control.selectedKeys || control.defaultSelectedKeys || [];
        willSelected = willSelected.concat(control._levelZeroParents(willSelected));
        control._selectedKeys = willSelected;
        control._openKeys = control._willOpenKeys();
    }

    /// buildItemKeysMap：真值 key 才入表（照抄 foundation.ts:81 的 `if (itemKey)`）
    function _mapFromItems(list, parentKeys, map) {
        if (!Array.isArray(list))
            return map;
        for (let i = 0; i < list.length; ++i) {
            const entry = list[i];
            if (Array.isArray(entry)) {
                control._mapFromItems(entry, parentKeys, map);
                continue;
            }
            const norm = (entry !== null && typeof entry === "object") ? {
                itemKey: entry.itemKey !== undefined && entry.itemKey !== null
                    ? entry.itemKey : "",
                items: Array.isArray(entry.items) && entry.items.length ? entry.items : null
            } : { itemKey: entry, items: null };
            if (norm.itemKey) {
                map[norm.itemKey] = parentKeys.slice();
                if (norm.items !== null)
                    control._mapFromItems(norm.items, parentKeys.concat([norm.itemKey]), map);
            }
        }
        return map;
    }

    function _mapFromChildren(node, parentKeys, map) {
        const kids = node.children;
        for (let i = 0; i < kids.length; ++i) {
            const child = kids[i];
            // qmllint disable missing-property
            if (child.itemKey === undefined) {
                // 包装节点（Loader / 位置器 / Entry 壳）：不是导航项，原层继续
                control._mapFromChildren(child, parentKeys, map);
            } else if (child.itemKey) {
                // 真值 key 才入表（buildItemKeysMap 的 `if (itemKey)`），子树挂到本 key 下
                map[child.itemKey] = parentKeys.slice();
                // qmllint enable missing-property
                // 子级照逻辑树走（NavigationSub 的子项可能已被搬进浮层）
                // qmllint disable missing-property
                const host = child.navChildHost;
                // qmllint enable missing-property
                control._mapFromChildren(host !== undefined && host !== null
                    ? host : child, parentKeys.concat([child.itemKey]), map);
            }
            // 假值 key 的导航项：官方 buildItemKeysMap 连子树一起跳过，不递归
            // qmllint enable missing-property
        }
        return map;
    }

    // ---------------------------------------------------------------- 走树注入
    function applyState() {
        control._walk(control, false);
    }

    function _walk(node, inSub) {
        const kids = node.children;
        for (let i = 0; i < kids.length; ++i) {
            const child = kids[i];
            // qmllint disable missing-property
            if (child.navCollapsed !== undefined)
                child.navCollapsed = control._isCollapsed;
            if (child.navHorizontal !== undefined)
                child.navHorizontal = control.horizontal;
            if (child.collapsed !== undefined && child.itemKey === undefined)
                child.collapsed = control._isCollapsed;
            if (child.itemKey !== undefined) {
                // 浮层里的子项沿 parent 找不到宿主（Popup 不是 Item）⇒ context 走逻辑树：
                // 容器自己写下来，点击/键盘那一路靠它回指
                if (child.navRoot !== undefined)
                    child.navRoot = control;
                child.navSelected = control._selectedKeys.indexOf(child.itemKey) >= 0;
                child.navInSub = inSub;
                child.navLimitIndent = control.limitIndent;
                child.navToggleIconPosition = control.toggleIconPosition;
                child.navTooltipShowDelay = control.tooltipShowDelay;
                child.navTooltipHideDelay = control.tooltipHideDelay;
                if (child.isNavigationSub === true) {
                    child.isOpen = control._openKeys.indexOf(child.itemKey) >= 0;
                    child.navSubMotion = control.subNavMotion;
                    child.navSubOpenDelay = control.subNavOpenDelay;
                    child.navSubCloseDelay = control.subNavCloseDelay;
                    child.navOpenKeysControlled = control.openKeysIsControlled;
                    // expandIcon / subDropdownProps 只经 items 档下放（renderItems 是唯一通路，
                    // context 里没有这两条 ⇒ children 档官方拿不到）
                    child.navExpandIcon = control.itemsMode ? control.expandIcon : undefined;
                    child.subDropdownProps = control.itemsMode
                        ? control.subDropdownProps : ({});
                }
            }
            // qmllint enable missing-property
            // qmllint disable missing-property
            const host = child.navChildHost;
            // qmllint enable missing-property
            if (host !== undefined && host !== null)
                // NavigationSub 的子项容器（可能被搬进浮层，不在 children 里）⇒ 认逻辑树，
                // 官方 context 沿组件树走、portal 不切断
                control._walk(host, inSub || (child.isNavigationSub === true));
            else
                control._walk(child, inSub || (child.isNavigationSub === true));
        }
    }

    // ---------------------------------------------------------------- 官方事件面
    /// ItemFoundation.handleClick 的容器侧：selectedKeys 替换 + onSelect/onClick
    function handleItemClick(itemKey, text, wasSelected, itemProps) {
        if (control._isValidKey(itemKey) && !control.selectedKeysControlled && !wasSelected)
            control.updateSelectedKeys([itemKey], true);
        if (!wasSelected) {
            control.select({ itemKey: itemKey, selectedKeys: [itemKey],
                selectedItems: [itemProps], domEvent: null });
        }
        control.click({ itemKey: itemKey, text: text, domEvent: null });
    }

    /// SubNavFoundation.handleClick：翻转 openKeys + onOpenChange + onClick
    function handleSubClick(itemKey) {
        const wasOpen = control._openKeys.indexOf(itemKey) >= 0;
        const isOpen = !wasOpen;
        const payload = { itemKey: itemKey, isOpen: isOpen, domEvent: null,
            openKeys: isOpen ? control._addKeys(control._openKeys, itemKey)
                : control._removeKeys(control._openKeys, itemKey) };
        if (!control.openKeysIsControlled)
            control._openKeys = payload.openKeys;
        control.openChange(payload);
        control.click(payload);
    }

    /// SubNavFoundation.handleDropdownVisibleChange：浮层显隐，只发 onOpenChange
    function handleDropdownVisibleChange(itemKey, visible) {
        const payload = { itemKey: itemKey, isOpen: visible, domEvent: null,
            openKeys: visible ? control._addKeys(control._openKeys, itemKey)
                : control._removeKeys(control._openKeys, itemKey) };
        if (!control.openKeysIsControlled)
            control._openKeys = payload.openKeys;
        control.openChange(payload);
    }

    function _addKeys(keys, key) {
        const out = keys.slice();
        if (key)
            out.push(key);
        return out;
    }

    function _removeKeys(keys, key) {
        const out = [];
        for (let i = 0; i < keys.length; ++i) {
            if (keys[i] !== key)
                out.push(keys[i]);
        }
        return out;
    }

    /// updateSelectedKeys（index.tsx:251-258）：缺省拼零级父 key 并过 Set
    function updateSelectedKeys(keys, includeParentKeys) {
        let will = keys;
        if (includeParentKeys !== false) {
            will = Array.from(new Set(
                keys.concat(control._levelZeroParents(keys))));
        }
        control._selectedKeys = will;
    }

    /// foundation.handleCollapseChange：受控档不翻内部态，onCollapseChange 恒发
    function toggleCollapse() {
        const will = !control._isCollapsed;
        if (!control.collapsedControlled)
            control._isCollapsed = will;
        control.collapseChange(will);
    }

    // ---------------------------------------------------------------- 信号同步（componentDidUpdate / getDerivedStateFromProps）
    // React 的 setState 会重渲染、走树注入自然刷新；QML 侧内部三态每变一次就补一走
    on_SelectedKeysChanged: control.applyState()
    on_OpenKeysChanged: control.applyState()
    on_IsCollapsedChanged: control.applyState()
    onIsCollapsedChanged: {
        if (control.collapsedControlled)
            control._isCollapsed = control.isCollapsed;
    }
    onSelectedKeysChanged: {
        if (control.selectedKeysControlled) {
            control.updateSelectedKeys(control.selectedKeys, true);
            control._openKeys = control._willOpenKeys();
        }
    }
    onOpenKeysChanged: {
        if (control.openKeysControlled)
            control._openKeys = control.openKeys.slice();
    }
    onItemsChanged: {
        control.init();
        Qt.callLater(control.applyState);
    }
    onHorizontalChanged: control.navigationRelayout()
    Connections {
        // default property 是 alias：使用方加/删 children 走的是 contentHost 的名单
        target: contentHost

        function onChildrenChanged() {
            Qt.callLater(function () {
                control.init();
                control.placeChildren();
                control.applyState();
            });
        }
    }

    Component.onCompleted: {
        control._isCollapsed = control.collapsedControlled
            ? Boolean(control.isCollapsed) : control.defaultIsCollapsed;
        control.init();
        control.placeChildren();
        control.applyState();
        // 条目经 Repeater→Loader 两层装载，首走树时嵌套 sub 的条目可能还没落地
        // （React 侧是 commit 后再 render 一轮）——事件循环后再补一走
        Qt.callLater(function () {
            control.init();
            control.placeChildren();
            control.applyState();
        });
    }

    /// children 档：把 contentHost 里的声明子项搬进列表位置器（items 档在前、children 在后，
    /// 同官方 `{items}{children}` 的渲染顺序）
    function placeChildren() {
        const host = itemsList.listHost;
        while (contentHost.children.length > 0)
            contentHost.children[0].parent = host;
    }

    function navigationRelayout() {
        control.placeChildren();
        control.applyState();
    }

    // ---------------------------------------------------------------- 视觉结构
    Item {
        id: contentHost

        visible: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.current.colorNavBg
    }

    // 竖直：右缘 1px；水平：底缘 1px（`.semi-navigation { border-right }` / horizontal 覆盖）
    Rectangle {
        color: Theme.current.colorBorder

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: control.horizontal ? 0 : 1
    }
    Rectangle {
        visible: control.horizontal
        color: Theme.current.colorBorder

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
    }

    Item {
        id: headerArea

        objectName: "navHeaderArea"

        // 水平档容器 padding 24（`semi-navigation-horizontal { padding-left/right: 24 }`）
        x: control.horizontal ? 24 : 0
        y: control.horizontal ? Math.max(0, (control.height - height) / 2) : 0
        width: control.horizontal ? headerSlot.childrenRect.width : parent.width
        height: headerSlot.childrenRect.height

        Item {
            id: headerSlot

            anchors.fill: parent
        }
    }

    Item {
        id: footerArea

        objectName: "navFooterArea"

        x: control.horizontal ? control.width - width - 24 : 0
        y: control.horizontal ? Math.max(0, (control.height - height) / 2)
            : control.height - height
        width: control.horizontal ? footerSlot.childrenRect.width : parent.width
        height: footerSlot.childrenRect.height

        Item {
            id: footerSlot

            anchors.fill: parent
        }
    }

    Item {
        id: listArea

        objectName: "navListArea"

        clip: true
        // 竖直：容器左右内边距 8（`.semi-navigation { padding-left/right: 8px }`）；
        // 水平：紧接 header（官方 header 与列表之间没有固定间距，只有条目间 margin-right 8）
        x: control.horizontal ? headerArea.x + headerArea.width : 8
        y: control.horizontal ? 0 : headerArea.height
        width: control.horizontal
            ? Math.max(0, control.width - x - (control.width - footerArea.x))
            : parent.width - 16
        height: control.horizontal ? control.height : control._listHeight

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: itemsList.height + (control.horizontal ? 0 : 12)
            interactive: !control.horizontal
                && itemsList.height + 12 > listArea.height
            clip: true

            NavigationSubEntries {
                id: itemsList

                x: 0
                y: control.horizontal
                    ? Math.max(0, (listArea.height - height) / 2) : 12
                width: parent.width
                horizontal: control.horizontal
                entries: control.itemsMode ? control.items : []
            }
        }
    }
}
