pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 带子菜单的导航项（semi-ui/navigation/SubNav.tsx + foundation/subNavFoundation.ts 的整份对应）。
//
//     NavigationSub {
//         itemKey: "task"; icon: "list"; text: "任务"
//         NavigationItem { itemKey: "mine"; text: "我的任务" }
//     }
//
// 结构：标题行（36 高）+ 子项列表。竖直展开档子项就地展开（首项上距 8、项间距 8）；
// **折叠或水平档子项搬进浮层**（官方：折叠时 sub ul 不渲染、children 只活在 Dropdown 里，
// 位置 rightTop —— 水平顶级是 bottomLeft；延迟 subNavOpenDelay / subNavCloseDelay）。
//
// 皮肤要点（navigation.scss）：
//   标题字号 14；**只有 list 直属的标题是 600**（`.list > .item > .sub-title`），
//   嵌套标题 400；浮层里的标题也 400。
//   选中标题（`-sub-title-selected`，仅竖直、list 直属那档）：字重 600、图标 primary、
//   **底色被同一规则改回 transparent** —— 选中标题没有高亮底，只有图标变色；
//   悬浮/按下照常 fill-0 / fill-1（item-hover/active-selected）。嵌套标题选中**完全没有**
//   视觉（-selected 那套规则按 DOM 位置写死在 list 直属档）。
//   展开箭头：chevron_down（或 expandIcon），开时 rotate(-180deg)（200ms）——
//   **subNavMotion 为 false 时官方连旋转都没有**（withTransition 只在 motion 档挂，
//   SubNav.tsx:220-224）；折叠档子内的标题箭头是 chevron_right，折叠的顶级标题没有箭头。
//   禁用标题 disabled-text；选中+禁用 primary-disabled。
//
// 上游的坑与死代码（照抄，不"修"）：
//   · `isOpen` prop 是死的（defaultProps 有、文档表有，但渲染读的是 context.openKeys，
//     SubNav.tsx:146-149）—— 端口把容器写下来的展开状态放在同名属性上，使用方写它会被
//     下一次走树顶掉（与官方「写了没效果」同observable）；
//   · `maxHeight`（缺省 999）在 renderSubUl 解构后从未使用；FAQ 说子菜单超 999px 会截断
//     指的是这条死代码之外的 Collapsible 行为；
//   · NavItem foundation 里那对 `toggleIcon: {open:'chevron_up', closed:'chevron_down'}`
//     从没被 SubNav 读过（箭头是 CSS 旋转 chevron_down）。
//
// 与官方的差异：
//   · 折叠/水平档的浮层用本库 Popover（官方是 Dropdown 换皮 Tooltip，同基座）；
//     `dropdownProps` / `subDropdownProps` / `dropdownStyle` 只接 `position` 一档
//     （本库 Dropdown 弹层方位不可配之外的键没有落点）；
//   · 官方折叠档关掉浮层就卸载 children（keepDOM false）；QML 的内联子项没法推迟创建，
//     children 常驻，只搬进搬出浮层（同 Tabs 的 keepDOM 注记）；
//   · `onMouseEnter/onMouseLeave` 变成 mouseEntered/mouseLeft 信号；
//   · 官方 Sub 没有 onClick prop（子标题的点击只走容器级 onClick），这里同样不设。
Item {
    id: control

    default property alias content: subColumn.data

    // ---------------------------------------------------------------- 官方 Nav.SubProps
    property var itemKey: ""
    /// 走树注入时区分 Item / Sub（容器侧唯一可靠判据）
    readonly property bool isNavigationSub: true
    property var text: ""
    property var icon: undefined
    property var indent: false
    property bool disabled: false
    property int level: 0
    /// 官方 prop：**死的**（SubNav 渲染只读 context.isCollapsed，自己的 prop 没人读 ——
    /// 与 NavItem 不同，Item.tsx:112 会把 props.isCollapsed 与 context 取或）
    property bool isCollapsed: false
    property var expandIcon: undefined         // 官方 expandIcon（ReactNode → 图标名）
    property var dropdownProps: ({})           // 只接 position，见文件头
    /// 官方 isOpen prop 是死的；端口把 openKeys 状态写在这里（见文件头）
    property bool isOpen: false

    /// 官方 onMouseEnter / onMouseLeave
    signal mouseEntered()
    signal mouseLeft()

    // ---------------------------------------------------------------- Navigation 注入
    property bool navSelected: false
    property bool navCollapsed: false
    property bool navHorizontal: false
    property bool navLimitIndent: true
    property int navTooltipShowDelay: 0
    property int navTooltipHideDelay: 100
    property bool navSubMotion: true
    property int navSubOpenDelay: 0
    property int navSubCloseDelay: 100
    property bool navOpenKeysControlled: false
    property var navExpandIcon: undefined
    property string navToggleIconPosition: "right"
    property var subDropdownProps: ({})
    property bool navInDropdown: false
    property bool navInSub: false

    // isCollapsed prop 是死的（见属性声明处），折叠态只认容器注入
    readonly property bool effectiveCollapsed: control.navCollapsed
    readonly property bool selected: control.navSelected
    readonly property bool hovered: titleHover.hovered
    readonly property bool flyoutMode: control.effectiveCollapsed || control.navHorizontal
    /// 选中标题的那套皮肤只给「竖直 + list 直属（非嵌套、非浮层）」档（见文件头）
    readonly property bool titleSelectedSkin: control.selected && !control.navHorizontal
        && !control.navInSub && !control.navInDropdown
    readonly property bool titleBold: !control.navInSub && !control.navInDropdown
    readonly property var effectiveExpandIcon: {
        if (control.expandIcon !== undefined && control.expandIcon !== null)
            return control.expandIcon
        if (control.navExpandIcon !== undefined && control.navExpandIcon !== null)
            return control.navExpandIcon
        return "chevron_down"
    }
    // 只有「折叠 + 非 sub 内」的顶级标题没有箭头（SubNav.tsx:205-218）；
    // 折叠的 sub 内标题与水平的 sub 内标题是 chevron_right，水平顶级照常 expandIcon/chevron_down
    readonly property bool toggleVisible: !(control.effectiveCollapsed && !control.navInSub)
    readonly property string toggleName: control.flyoutMode && control.navInSub
        ? "chevron_right" : String(control.effectiveExpandIcon)
    readonly property real toggleRotation: {
        if (control.flyoutMode || !control.navSubMotion)
            return 0
        return control.isOpen ? -180 : 0
    }

    readonly property int itemHeight: 36
    readonly property int paddingX: 12                // $spacing-navigation_item-paddingX（官方 css 实测 padding: 8px 12px）
    readonly property int iconSize: 20
    readonly property int toggleSize: 16             // ICON_POS_RIGHT 的 size "default"
    readonly property int gap: 12

    readonly property bool hasIcon: control.icon !== undefined && control.icon !== null
        && control.icon !== ""
    readonly property int placeholderAmount: {
        if (control.navHorizontal || control.navLimitIndent || control.effectiveCollapsed)
            return 0
        const amount = (control.hasIcon && !control.indent) ? control.level : control.level - 1
        return amount > 0 ? amount : 0
    }
    readonly property bool infoSlot: control.hasIcon
        || (!control.navHorizontal && (control.indent || control.navInSub))
    readonly property int toggleLeftWidth: control.navToggleIconPosition === "left"
        && control.toggleVisible ? control.iconSize : 0
    readonly property int leadingWidth: control.placeholderAmount * (control.iconSize + control.gap)
        + (control.toggleLeftWidth > 0 ? control.iconSize + control.gap : 0)
        + (control.infoSlot ? control.iconSize + control.gap : 0)

    // ---------------------------------------------------------------- 皮肤（可断言）
    readonly property color titleBgColor: {
        if (control.disabled)
            return Qt.rgba(0, 0, 0, 0)
        if (titleTap.pressed)
            return Theme.current.colorFill1
        if (control.hovered)
            return Theme.current.colorFill0
        return Qt.rgba(0, 0, 0, 0)
    }
    readonly property color titleTextColor: {
        if (control.navHorizontal) {
            if (control.disabled)
                return Theme.current.colorDisabledText
            return control.selected ? Theme.current.colorText0 : Theme.current.colorText2
        }
        if (control.disabled)
            return control.titleSelectedSkin ? Theme.current.colorPrimaryDisabled
                : Theme.current.colorDisabledText
        return Theme.current.colorText0
    }
    readonly property color titleIconColor: {
        if (control.navHorizontal) {
            if (control.disabled)
                return Theme.current.colorDisabledText
            return control.selected ? Theme.current.colorText0 : Theme.current.colorText2
        }
        if (control.disabled)
            return control.titleSelectedSkin ? Theme.current.colorPrimaryDisabled
                : Theme.current.colorDisabledText
        return control.titleSelectedSkin ? Theme.current.colorPrimary : Theme.current.colorText2
    }
    /// 折叠档标题文字渐隐位：官方 SubNav 的标题文字用的就是 `-item-text` 同一个类名
    /// （navigation.scss `-collapsed .semi-navigation-item-text { opacity: 0 }`），
    /// 与 NavigationItem 同闸；浮层里的标题 portal 在容器外，够不着那条规则
    readonly property real titleTextOpacity: control.effectiveCollapsed
        && !control.navInDropdown ? 0 : 1

    // 竖直档高度跟着 Collapsible 的动画走：官方 wrapper 的 height 过渡驱动文档流里后续条目
    // 同步移动；直接吃终值的话收起时后续条目先跳上去、内容还挂着 ⇒ 和下面的条目重叠
    implicitHeight: control.itemHeight
        + (control.flyoutMode ? 0 : motionWrap.currentHeight)
    // 浮层档的列宽：各子项**隐式**宽取大、兜官方 min-width 150
    // （`$width-navigation_dropdown_item_nav_item-minWidth`）。不能吃 subColumn.implicitWidth ——
    // 位置器隐式宽吃子项**实际**宽，而实际宽又要回读列宽，成环当场塌 0。
    readonly property real entriesNaturalWidth: {
        let widest = 0;
        for (let i = 0; i < subColumn.children.length; ++i) {
            const kid = subColumn.children[i];
            if (kid.implicitWidth > widest)
                widest = kid.implicitWidth;
        }
        return Math.max(150, widest);
    }
    /// 容器注入：浮层里的子项沿 parent 找不到宿主（Popup 不是 Item），点击与状态都走这条
    property var navRoot: null
    /// 子项的逻辑容器：官方 React context 沿组件树走、portal 不Cut断；端口被搬进浮层后
    /// 只有这个属性一直指得到（Navigation 的走树注入认它，见 Navigation._walk）
    readonly property Item navChildHost: subColumn

    implicitWidth: control.paddingX * 2 + control.leadingWidth + titleLabel.implicitWidth
        + (control.toggleVisible && control.navToggleIconPosition !== "left" ? control.toggleSize : 0)
    // 浮层档拉伸到整列宽（官方 `.semi-dropdown-item` 块级铺满菜单 ⇒ 悬浮底色 == 卡片），
    // 拿不到宿主宽时兜 min-width 150
    width: control.navInDropdown
        ? (parent && parent.width > 0 ? parent.width : Math.max(150, control.implicitWidth))
        : (control.navHorizontal || !parent ? control.implicitWidth : parent.width)

    function navigationRoot() {
        if (control.navRoot !== null && control.navRoot !== undefined)
            return control.navRoot;
        let node = control.parent;
        while (node !== null && node !== undefined) {
            // qmllint disable missing-property
            if (node.isNavigationRoot === true)
                return node;
            // qmllint enable missing-property
            node = node.parent;
        }
        return null;
    }

    /// 浮层方位：per-sub dropdownProps 整档盖过容器的 subDropdownProps（官方是对象展开）
    function positionOf() {
        const user = control.dropdownProps && control.dropdownProps.position !== undefined
            && control.dropdownProps.position !== null ? control.dropdownProps.position
            : (control.subDropdownProps && control.subDropdownProps.position !== undefined
                && control.subDropdownProps.position !== null ? control.subDropdownProps.position
                : undefined)
        if (user !== undefined && user !== null)
            return user
        return (control.navHorizontal && !control.navInSub) ? Enums.BottomLeft : Enums.RightTop
    }

    /// 子项在浮层/就地两档之间搬家，并把 navInDropdown 标记写给直接子项
    function placeChildren() {
        for (let i = 0; i < subColumn.children.length; ++i) {
            const kid = subColumn.children[i];
            // qmllint disable missing-property
            if (kid.navInDropdown !== undefined)
                kid.navInDropdown = control.flyoutMode;
            // qmllint enable missing-property
        }
        if (control.flyoutMode) {
            subColumn.parent = flyoutHost;
            // 浮层档列宽 = 各子项隐式宽取大（兜 150）；子项再拉伸到它 ⇒ 悬浮底色与卡片同宽
            subColumn.width = Qt.binding(function () { return control.entriesNaturalWidth });
            subColumn.y = Qt.binding(function () { return 4 });    // .semi-dropdown-menu 的上下 4
        } else {
            subColumn.parent = inlineHost;
            subColumn.width = Qt.binding(function () { return inlineHost.width });
            subColumn.y = Qt.binding(function () { return 0 });
        }
    }

    onFlyoutModeChanged: control.placeChildren()
    Connections {
        target: subColumn

        function onChildrenChanged() {
            Qt.callLater(control.placeChildren)
        }
    }
    Component.onCompleted: control.placeChildren()

    // ---------------------------------------------------------------- 标题行
    Item {
        id: titleArea

        width: parent.width
        height: control.itemHeight

        Rectangle {
            anchors.fill: parent
            radius: Theme.current.radiusSmall
            color: control.titleBgColor
        }

        Row {
            id: titleRow

            x: control.paddingX
            y: (control.itemHeight - height) / 2
            width: parent.width - control.paddingX * 2
            spacing: control.gap

            Repeater {
                model: control.placeholderAmount

                Item {
                    width: control.iconSize
                    height: control.iconSize
                }
            }

            Item {
                visible: control.toggleLeftWidth > 0
                width: control.iconSize
                height: control.iconSize

                Icon {
                    anchors.fill: parent
                    name: control.toggleName
                    size: control.toggleSize
                    color: control.disabled ? Theme.current.colorDisabledText
                        : Theme.current.colorText2
                    rotation: control.toggleRotation
                }
            }

            Item {
                id: infoHost

                visible: control.infoSlot
                width: control.iconSize
                height: control.iconSize

                Icon {
                    anchors.fill: parent
                    visible: control.hasIcon
                    name: control.hasIcon ? String(control.icon) : ""
                    size: control.iconSize
                    color: control.titleIconColor
                }
            }

            Text {
                id: titleLabel

                width: Math.max(0, titleRow.width - control.leadingWidth
                    - (control.toggleVisible && control.navToggleIconPosition !== "left"
                        ? control.toggleSize : 0))
                text: control.text === undefined || control.text === null ? "" : String(control.text)
                color: control.titleTextColor
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: control.titleBold ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                opacity: control.titleTextOpacity
            }
        }

        Icon {
            visible: control.toggleVisible && control.navToggleIconPosition !== "left"
            anchors.right: parent.right
            anchors.rightMargin: control.paddingX
            anchors.verticalCenter: parent.verticalCenter
            name: control.toggleName
            size: control.toggleSize
            color: control.disabled ? Theme.current.colorDisabledText : Theme.current.colorText2
            rotation: control.toggleRotation
        }

        HoverHandler {
            id: titleHover

            cursorShape: control.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor

            onHoveredChanged: {
                if (titleHover.hovered)
                    control.mouseEntered();
                else
                    control.mouseLeft();
            }
        }

        TapHandler {
            id: titleTap

            enabled: !control.disabled

            onTapped: {
                const root = control.navigationRoot();
                if (root !== null)
                    root.handleSubClick(control.itemKey);
            }
        }
    }

    // ---------------------------------------------------------------- 子项（就地档）
    // subNavMotion 的展开动画（官方 Collapsible motion + fade；关掉 motion 连箭头旋转都没有）
    Collapsible {
        id: motionWrap

        objectName: "navSubMotionWrap"
        anchors.top: titleArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        isOpen: !control.flyoutMode && control.isOpen
        fade: control.navSubMotion
        duration: control.navSubMotion ? 250 : 0

        Item {
            id: inlineHost

            y: 8                                  // `.sub .item:first-child { margin-top: 8 }`
            width: parent.width
            height: subColumn.height

            Column {
                id: subColumn

                width: inlineHost.width
                spacing: 8                        // sub 里项间距 tight
            }
        }
    }

    // ---------------------------------------------------------------- 浮层（折叠/水平档）
    // 官方只在「折叠或水平」时才把标题包进 Dropdown（SubNav.tsx:356-359 外层，
    // :323-325 内层还带 !disabled）—— 竖直展开档压根没有这只浮层，子项就地展开。
    // 端口浮层对象常驻（子项搬家要用 flyoutHost），「不渲染」落到这两道闸上：
    // condition 挡 hover 那几条显示路径，下面的受控 Binding 挡外部写 visible
    // （condition 对 custom 档无效，见 src/Tooltip.qml 文件头）。
    Popover {
        id: flyout

        target: titleArea
        position: control.positionOf()
        trigger: control.navOpenKeysControlled ? "custom" : "hover"
        mouseEnterDelay: control.navSubOpenDelay
        mouseLeaveDelay: control.navSubCloseDelay
        condition: !control.disabled && control.flyoutMode

        Item {
            id: flyoutHost

            width: subColumn.width
            height: subColumn.height + 8
        }
    }

    // 受控 openKeys：浮层显隐完全跟着 isOpen（官方 Dropdown trigger custom + visible，
    // 但那对 prop 只挂在折叠/水平档渲染出来的 Dropdown 上 —— 竖直展开档没有）
    Binding {
        target: flyout
        property: "visible"
        value: control.isOpen
        when: control.navOpenKeysControlled && control.flyoutMode
    }

    // 折叠档禁用的 sub 标题也包 Tooltip（Item.tsx:303 `isCollapsed && isSubNav && disabled`）
    Tooltip {
        target: titleArea

        text: control.text === undefined || control.text === null ? "" : String(control.text)
        position: Enums.Right
        mouseEnterDelay: control.navTooltipShowDelay
        mouseLeaveDelay: control.navTooltipHideDelay
        condition: control.effectiveCollapsed && control.disabled && control.text !== ""
    }

    Connections {
        target: flyout

        function onVisibleChanged() {
            const root = control.navigationRoot();
            if (root !== null)
                root.handleDropdownVisibleChange(control.itemKey, flyout.visible);
        }
    }
}
