pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 导航菜单项（semi-ui/navigation/Item.tsx + foundation/itemFoundation.ts 的整份对应）。
//
//     NavigationItem { itemKey: "home"; icon: "home"; text: "首页" }
//
// 皮肤（navigation.scss + mixin.scss）：
//   li：高 36、padding 8 12、圆角 radius-small、margin-bottom 8（列表 Column spacing 顶）；
//   状态色：常态透明底 / text-0 字 / text-2 图标；悬浮 fill-0；按下 fill-1；
//   选中 primary-light-default 底、图标 primary；禁用 disabled-text 字与图标、透明底；
//   选中+禁用：透明底、primary-disabled 字与图标（item-disabled-selected）。
//   **选中会往后让位**：`.item-normal:hover`（0,2,0）压过 `.item-selected`（0,1,0）——
//   选中项悬浮变 fill-0、按下变 fill-1，图标保持 primary（item-hover/active-selected 只改底）。
//   水平档整套换成 horizontal 那组令牌：底恒透明，字色 text-2 → 悬浮 text-1 →
//   按下/选中 text-0（hover 不盖 selected：`:hover:not(.item-selected)`）。
//   字重：list 直属子项 600（`.list > .item`），sub 里的子项 400。
//   图标区：`-item-icon-info` min-width 20 + 右距 12；图标 size large=20。
//   收起态文字只是 opacity 0（display:none 被注释掉了）仍在布局里；
//   折叠的顶级项包 Tooltip（position right，延迟吃容器的 tooltipShow/HideDelay）。
//   折叠/水平档里、sub 内部的项变成 Dropdown.Item：min-width 150、选中字重回落 normal
//   （`.semi-navigation-popover .item-selected`）。
//
// 上游的坑与死代码（照抄，不"修"）：
//   · 普通项在 toggleIconPosition 为 right 时恒渲染一个**空的** toggle-right `<i>`
//     （margin-left: auto、宽度 0）—— 无视觉，端口不渲染空槽，见「差异」；
//   · 为 right 时 `link` 包 <a>、Enter 走 handleKeyPress 的链接跳转 —— QML 无落点；
//   · `-item-indent` 类名规则（width 32）从未被任何渲染路径挂上，死规则。
//
// 与官方的差异（React / CSS 在 QML 侧无处落地，逐条）：
//   · `style` / `className` / `link` / `linkOptions` / `tabIndex` 不搬（坑 91）；
//     `onMouseEnter/onMouseLeave` 变成 mouseEntered/mouseLeft 信号；
//   · toggleIconPosition=left 时空槽官方占 20+12（min-width 生效），这里照占；
//     =right 时空槽宽度 0，端口直接不渲染（等价）；
//   · 选中态官方每帧从 context.selectedKeys 现算，这里由 Navigation 走树写
//     navSelected（QML 没有 React context，见 Navigation.qml 文件头）。
Item {
    id: control

    // ---------------------------------------------------------------- 官方 Nav.ItemProps
    property var itemKey: ""
    property var text: ""
    property var icon: undefined               // 图标名字符串
    property var indent: false                 // bool | number
    property bool disabled: false
    property int level: 0
    property bool isCollapsed: false           // 官方 prop：与容器状态取或
    property var link: undefined               // 官方 <a href>，无落点（见文件头）
    /// 官方 tooltipShowDelay（undefined ⇒ 跟容器）
    property var tooltipShowDelay: undefined
    /// 官方 tooltipHideDelay（undefined ⇒ 跟容器）
    property var tooltipHideDelay: undefined

    /// 官方 onClick({ itemKey, text, domEvent })
    signal click(var data)
    /// 官方 onMouseEnter / onMouseLeave
    signal mouseEntered()
    signal mouseLeft()

    // ---------------------------------------------------------------- Navigation 注入
    property bool navSelected: false
    property bool navCollapsed: false
    property bool navHorizontal: false
    property bool navLimitIndent: true
    property bool navInDropdown: false
    property bool navInSub: false
    property int navTooltipShowDelay: 0
    property int navTooltipHideDelay: 100
    property string navToggleIconPosition: "right"

    readonly property bool effectiveCollapsed: control.isCollapsed || control.navCollapsed
    readonly property bool selected: control.navSelected
    readonly property bool hovered: hover.hovered
    readonly property bool hasIcon: control.icon !== undefined && control.icon !== null
        && control.icon !== ""

    readonly property int itemHeight: 36
    readonly property int paddingX: 12                 // $spacing-navigation_item-paddingX = base-tight（12，官方 css 实测 padding: 8px 12px）
    readonly property int iconSize: 20                 // ICON_POS_LEFT 的 size "large"
    readonly property int gap: 12                      // $width-navigation_icon_text_between

    // ---------------------------------------------------------------- 皮肤（可断言）
    /// 「**选中压过悬浮/按下**」在两处作用域成立，走的是两条不同的官方规则：
    ///  · sub 就地那一列 —— `.semi-navigation-sub .semi-navigation-item:hover/:active.…-selected`
    ///    与 `.semi-navigation-item-normal:hover.…-selected`（fill-0 / fill-1）同特异度 (0,4,0)，
    ///    写在后面 ⇒ 由它赢，底色恒 primary-light-default；
    ///  · 折叠/水平的浮层 —— Item.tsx:247 给 Dropdown.Item 传 `active={selected}`，而
    ///    dropdown.scss 的悬浮/按下是 `.semi-dropdown-item:not(.semi-dropdown-item-active):hover/:active`
    ///    ⇒ 选中那条当场被排除；popover 档的类名里也没有 `-normal`（Item.tsx:240-247 那一支不加），
    ///    `.semi-navigation-item-normal:hover…` 同样够不着 ⇒ 底色留在 `.semi-navigation-item-selected`。
    /// 只有「禁用+选中」在两处分岔：sub 列留选中底 + disabled-text，浮层与顶级 L1 都是
    /// 透明底 + primary-disabled（`.semi-navigation-item-selected.semi-navigation-item-disabled`）。
    readonly property bool selectedFirst: control.navInSub && !control.navHorizontal
    /// sub 就地列独有的那组值（浮层与顶级 L1 都不进这一档）
    readonly property bool subColumnScope: control.navInSub && !control.navInDropdown
        && !control.navHorizontal
    readonly property color bgColor: {
        if (control.navHorizontal)
            return Qt.rgba(0, 0, 0, 0)
        // 选中优先档：悬浮/按下都不许把选中底挤掉；浮层里的禁用+选中例外（回透明底）
        if (control.selected && control.selectedFirst
            && !(control.disabled && control.navInDropdown))
            return Theme.current.colorPrimaryLightDefault
        if (control.disabled)
            return Qt.rgba(0, 0, 0, 0)
        if (tap.pressed)
            return Theme.current.colorFill1
        if (hover.hovered)
            return Theme.current.colorFill0
        if (control.selected)
            return Theme.current.colorPrimaryLightDefault
        return Qt.rgba(0, 0, 0, 0)
    }
    /// 字重：顶级 L1 600；sub 列与浮层里未选中 400；**浮层里选中的那条回到 600**
    /// （`.semi-dropdown-item-active { font-weight: 600 }`，active 就是 Nav 传的 selected）
    readonly property bool labelBold: control.navInDropdown ? control.selected : !control.navInSub
    readonly property color textColor: {
        if (control.navHorizontal) {
            if (control.disabled)
                return Theme.current.colorDisabledText
            if (tap.pressed && !control.selected)
                return Theme.current.colorText0
            if (hover.hovered && !control.selected)
                return Theme.current.colorText1
            return control.selected ? Theme.current.colorText0 : Theme.current.colorText2
        }
        if (control.disabled)
            // 禁用+选中：只有 sub 就地那一列是 disabled-text + 选中底
            // （`.semi-navigation-sub .…-selected.…-disabled`）；浮层与顶级 L1 都走
            // `.semi-navigation-item-selected.semi-navigation-item-disabled` = 透明底 + primary-disabled
            return control.selected && !control.subColumnScope ? Theme.current.colorPrimaryDisabled
                : Theme.current.colorDisabledText
        return Theme.current.colorText0
    }
    readonly property color iconColor: {
        if (control.navHorizontal) {
            if (control.disabled)
                return Theme.current.colorDisabledText
            if (tap.pressed && !control.selected)
                return Theme.current.colorText0
            if (hover.hovered && !control.selected)
                return Theme.current.colorText1
            return control.selected ? Theme.current.colorText0 : Theme.current.colorText2
        }
        if (control.disabled)
            return control.selected && !control.subColumnScope ? Theme.current.colorPrimaryDisabled
                : Theme.current.colorDisabledText
        return control.selected ? Theme.current.colorPrimary : Theme.current.colorText2
    }
    /// 折叠档文字渐隐位（navigation.scss `-collapsed .semi-navigation-item-text { opacity: 0 }`；
    /// 浮层里的条目 portal 在容器外，那条规则够不着）
    readonly property real labelOpacity: control.effectiveCollapsed
        && !control.navInDropdown ? 0 : 1

    // limitIndent=false 的层级缩进占位（Item.tsx:213-215：(icon && !indent) ? level : level-1，
    // lodash times 对负数返回空表 ⇒ 顶级永远没有占位）
    readonly property int placeholderCount: {
        if (control.navHorizontal || control.navLimitIndent || control.effectiveCollapsed)
            return 0
        const amount = (control.hasIcon && !control.indent) ? control.level : control.level - 1
        return amount > 0 ? amount : 0
    }
    // `-item-icon-info` 槽：官方 `icon || indent || isInSubNav` 才渲染，
    // renderIcon 又对「水平档且没图标」返回 null（Item.tsx:130-132）
    readonly property bool infoSlot: control.hasIcon
        || (!control.navHorizontal && (control.indent || control.navInSub))
    readonly property bool toggleLeftSlot: control.navToggleIconPosition === "left"
    readonly property int leadingWidth: control.placeholderCount * (control.iconSize + control.gap)
        + (control.toggleLeftSlot ? control.iconSize + control.gap : 0)
        + (control.infoSlot ? control.iconSize + control.gap : 0)

    implicitHeight: control.itemHeight
    implicitWidth: control.paddingX * 2 + control.leadingWidth + label.implicitWidth
    // 浮层档拉伸到整列宽（官方 `.semi-dropdown-item` 块级铺满菜单、nav item 只有 min-width 150
    // ⇒ 悬浮底色与卡片同宽）；拿不到宿主宽时兜 150
    width: control.navInDropdown
        ? (parent && parent.width > 0 ? parent.width : Math.max(150, control.implicitWidth))
        : (control.navHorizontal || !parent ? control.implicitWidth : parent.width)

    /// 容器注入：浮层里的条目沿 parent 走不到宿主（Popup 不是 Item，链在那儿断）
    property var navRoot: null

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

    /// 官方 selectedItems = [cloneDeep(itemProps)]
    function selectedSnapshot() {
        return { itemKey: control.itemKey, text: control.text, icon: control.icon,
            indent: control.indent, disabled: control.disabled, level: control.level };
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.current.radiusSmall
        color: control.bgColor
    }

    Row {
        id: contentRow

        x: control.paddingX
        y: (control.itemHeight - height) / 2
        width: parent.width - control.paddingX * 2
        spacing: control.gap

        Repeater {
            model: control.placeholderCount

            Item {
                width: control.iconSize
                height: control.iconSize
            }
        }

        Item {
            visible: control.toggleLeftSlot
            width: control.iconSize
            height: control.iconSize
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
                color: control.iconColor
            }
        }

        Text {
            id: label

            width: Math.max(0, contentRow.width - control.leadingWidth)
            text: control.text === undefined || control.text === null ? "" : String(control.text)
            color: control.textColor
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: control.labelBold ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            opacity: control.labelOpacity
        }
    }

    HoverHandler {
        id: hover

        cursorShape: control.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor

        onHoveredChanged: {
            if (hover.hovered)
                control.mouseEntered();
            else
                control.mouseLeft();
        }
    }

    TapHandler {
        id: tap

        enabled: !control.disabled

        onTapped: {
            const root = control.navigationRoot();
            if (root !== null) {
                root.handleItemClick(control.itemKey, control.text,
                    control.selected, control.selectedSnapshot());
            }
            control.click({ itemKey: control.itemKey, text: control.text, domEvent: null });
        }
    }

    // 折叠的顶级项悬出文字（Item.tsx:303：`isCollapsed && !isInSubNav && !isSubNav`）；
    // 折叠档禁用的 sub 标题也包，但那是 NavigationSub 的事
    Tooltip {
        target: control

        text: control.text === undefined || control.text === null ? "" : String(control.text)
        position: Enums.Right
        mouseEnterDelay: control.tooltipShowDelay !== undefined && control.tooltipShowDelay !== null
            ? control.tooltipShowDelay : control.navTooltipShowDelay
        mouseLeaveDelay: control.tooltipHideDelay !== undefined && control.tooltipHideDelay !== null
            ? control.tooltipHideDelay : control.navTooltipHideDelay
        condition: control.effectiveCollapsed && !control.navInDropdown && control.text !== ""
            && control.text !== undefined && control.text !== null
    }
}
