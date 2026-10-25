import QtQuick

// 下拉菜单项。官方 `packages/semi-ui/dropdown/dropdownItem.tsx` 的 DropdownItemProps。
//
//     Dropdown {
//         DropdownItem { text: "编辑"; icon: "edit" }
//         DropdownItem { text: "删除"; type: "danger"; disabled: true }
//     }
//
// ------------------------------------------------------------------ 官方 DropdownItemProps
// 逐条对着 dropdownItem.tsx:14-30（接口）与 :57-63（defaultProps）：
//   · `disabled` / `selected` 缺省 false，`onMouseEnter` / `onMouseLeave` / `forwardRef` 是 noop。
//   · **`selected` 是死 prop**：propTypes 里声明了（:41）、TS 接口里也有（:16），但 `render()`
//     解构 props 时压根没取它 —— 对勾与字重 600 只看 `active`。端口收了不用，并钉用例。
//   · `type` 五档 `primary` / `secondary` / `tertiary` / `warning` / `danger`（constants.ts:16）。
//     **API 表里那条「缺省 tertiary」是官网写错的**：`defaultProps` 里没有 `type`，
//     `cls` 那行是 `[`${prefixCls}-item-${type}`]: type` —— 没给就不加类 ⇒ 字色走
//     `$color-dropdown_item-text-default` = text-0。端口按代码口径来。
//   · `showTick` 官方是「context 那份优先」：`const realShowTick = contextShowTick ?? showTick`。
//     而 Dropdown 只要渲染就一定会往 context 里塞自己的 `showTick`（缺省 false），`??` 只在
//     null/undefined 才落回 ⇒ **条目自己那条 `showTick` 在 Dropdown 里永远不生效**。端口照抄，
//     并钉用例（想开对勾就设 Dropdown 的那一条）。
//   · `hover` 官方注释写着 "internal prop, please do not use"，只加一条底色类，没人传 ⇒ 不收。
//   · 四个鼠标回调都只在 `!disabled` 时挂（:85-96）。另外那条 **`level !== 1` 时 `onClick`
//     换成 `onMouseDown`（且只认左键）** —— 嵌套进第二层的条目走的是「按下即发」，端口照抄。
//   · 键盘：焦点在条目上时由 Dropdown 统一处理（官方挂在 `<ul>` 上靠冒泡），见 src/Dropdown.qml。
//
// ------------------------------------------------------------------ 规格（dropdown.scss + variables.scss）
// `.semi-dropdown-item`：`padding: 8 16`（$spacing-tight / $spacing-base）、字色 text-0、
// `max-width: 280`、`display: flex; align-items: center`、字号继承 `.semi-dropdown` 的 14 / 行高 20
// ⇒ 一条高 8 + 20 + 8 = **36**（旧端口写的 32 是错的）。
//   · 底色三档：hover `fill-0`、按下 `fill-1`、`:focus-visible` `fill-0`；**三条都排除 `-active`**
//     （`&:not(.semi-dropdown-item-active):hover`），所以选中那一条悬停不变色。
//   · 禁用：字色 `disabled-text`、悬停与按下都透明。
//   · 对勾档（`-withTick`）：左内边距从 16 变 **12**（$spacing-base-tight），对勾本身是条目的
//     直接子 `.semi-icon` ⇒ 吃 `& > .semi-icon { margin-right: 9px; font-size: 12px }` 那条，
//     所以文字左边缘在 12 + 12 + 9 = 33（分组标题的 withTick 左内边距 31 就是冲着它对齐的）。
//     未选中时官方画一枚 **透明** 对勾占位（`<IconTick style={{color:'transparent'}}/>`），
//     不是不画 —— 否则选中/未选中的文字会横跳。
//   · `icon` prop 那一路是包在 `.semi-dropdown-item-icon` 里的（`margin-right: 8`），
//     **不是** 条目的直接子节点 ⇒ 那条 12px / 9px 对它不生效，图标按自身尺寸（端口 16）画。
//   · 字重：`-active` ⇒ 600（$font-dropdown_item_active-fontWeight）。
//   · 过渡：`background-color` 的时长是 `--semi-transition_duration-none` ⇒ 官方自己就没动画，
//     端口也不挂 ColorAnimation（旧端口那条 durationFast 是本地加的）。
//   · **children 是 flex 的最后一格**（dropdownItem.tsx:141 `{tick}{iconContent}{children}`）：
//     行内元素（HotKeys 之类）排在文字后面并**参与条目与卡片的宽度**（`max-width: 280` 封顶
//     整行）⇒ 永远画在卡片背景里。端口把声明式子项收进内容行 Row；官方 demo 给 HotKeys 的
//     `marginLeft: 20` 是页面侧的，端口落成内容行的行内间距（text 与子项、子项与子项之间）。
Item {
    id: control

    // ---- 官方 DropdownItemProps ----
    property string text: ""
    property var icon: undefined
    property bool disabled: false
    property bool selected: false
    property bool active: false
    property string type: ""
    property bool showTick: false

    /// 官方 `{children}`：排在文字后面的行内内容（HotKeys 等），参与宽度
    default property alias content: contentRow.data

    /// 给 Dropdown 认名单用的标记（官方是 `<li role="menuitem">`）
    readonly property bool isDropdownItem: true

    signal clicked
    signal mouseEntered
    signal mouseLeft
    signal contextMenu

    // 官方 context：{ showTick, level, trigger }，Dropdown 那份优先。
    // **不是条目往上找宿主** —— Popup 不是 Item，条目的 parent 链只有 Column → popupItem →
    // Overlay，走不到 Dropdown 那一层（实测）。改成宿主在 refreshItems 里反向收养：
    // 宿主有这条链（它就是从 contentItem 往下数的），所以由它把自已写进来。
    property var dropdownHost: null

    readonly property bool inDropdown: control.dropdownHost !== null
    readonly property int level: control.inDropdown && control.dropdownHost.ctxLevel !== undefined
        ? control.dropdownHost.ctxLevel : 0
    readonly property bool realShowTick: control.inDropdown
        ? control.dropdownHost.showTick : control.showTick

    // 端口近似：Qt 的 activeFocus 分不出「键盘来的」还是「点出来的」
    readonly property bool focusVisible: control.activeFocus

    readonly property color contentColor: control.disabled
        ? Theme.current.colorDisabledText
        : control.typeColor

    readonly property color typeColor: {
        switch (control.type) {
        case "primary": return Theme.current.colorPrimary;
        case "secondary": return Theme.current.colorSecondary;
        case "tertiary": return Theme.current.colorTertiary;
        case "warning": return Theme.current.colorWarning;
        case "danger": return Theme.current.colorDanger;
        default: return Theme.current.colorText0;
        }
    }

    readonly property color bgColor: !control.enabled || control.disabled || control.active
        ? "transparent"
        : (pressArea.pressed ? Theme.current.colorFill1
            : (hoverArea.hovered || control.focusVisible ? Theme.current.colorFill0 : "transparent"))

    width: parent ? parent.width : implicitWidth
    // 官方 li 是 flex + max-width 280 ⇒ 整行（文字 + 行内 children）一起算、一起封顶
    implicitWidth: Math.min(280, control.paddingLeft + control.tickWidth
        + control.iconWidth + contentRow.implicitWidth + 16)
    height: 36                                       // 8 + 20 + 8
    implicitHeight: height

    readonly property real paddingLeft: control.realShowTick ? 12 : 16
    readonly property real tickWidth: control.realShowTick ? 12 + 9 : 0
    readonly property real iconWidth: control.icon !== undefined && control.icon !== "" ? 16 + 8 : 0
    readonly property real textWidth: metrics.width
    /// 文字与行内 children 的起点（官方 flex 里文字是第二个格子）——测试观察口
    readonly property real contentX: contentRow.x

    Text {
        id: metrics

        visible: false
        text: control.text
        font.pixelSize: Theme.current.fontSizeRegular
        font.weight: control.active ? Font.DemiBold : Font.Normal
    }

    // 底色那一层
    Rectangle {
        objectName: "dropdownItemBg"

        anchors.fill: parent
        color: control.bgColor
    }

    // 对勾：未选中也要占位（透明），否则文字会横跳
    Icon {
        id: tickIcon

        objectName: "dropdownItemTick"

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: control.realShowTick
        name: "checkbox_tick"
        size: 12
        color: control.active ? Theme.current.colorPrimary : "transparent"
    }

    Icon {
        id: iconNode

        objectName: "dropdownItemIcon"

        anchors.left: parent.left
        anchors.leftMargin: control.paddingLeft + control.tickWidth
        anchors.verticalCenter: parent.verticalCenter
        visible: control.icon !== undefined && control.icon !== ""
        name: control.icon !== undefined && control.icon !== "" ? control.icon : ""
        size: 16
        color: control.contentColor
    }

    // 内容行 = 官方 flex 的「文字 + children」那两格（children 是 default 槽，见文件头）。
    // spacing 20 = 官方 demo 给 HotKeys 的 `marginLeft: 20`（页面侧内联样式，端口落成行内缺省）
    Row {
        id: contentRow

        objectName: "dropdownItemContent"

        x: control.paddingLeft + control.tickWidth + control.iconWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20

        Text {
            objectName: "dropdownItemText"

            text: control.text
            color: control.contentColor
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: control.active ? Font.DemiBold : Font.Normal
        }
    }

    HoverHandler {
        id: hoverArea

        objectName: "dropdownItemHover"

        // 官方 disabled 时四个回调都不挂；底色那条 hover 规则也在 :not(-active) 下
        enabled: !control.disabled
        onHoveredChanged: {
            if (hoverArea.hovered)
                control.mouseEntered();
            else
                control.mouseLeft();
        }
    }

    // 左键：level === 1（或不在 Dropdown 里）走 click，嵌套那一档走 mouseDown
    TapHandler {
        id: pressArea

        objectName: "dropdownItemTap"

        enabled: !control.disabled
        acceptedButtons: Qt.LeftButton
        // 用 pressedChanged 而不是 activeChanged：这条路径上 TapHandler 拿的是 passive grab，
        // 实测按下时 `pressed` 变真而 `active` 一直是 false ⇒ 挂 activeChanged 那一档永远不触发
        onPressedChanged: {
            if (!pressArea.pressed || control.disabled)
                return;
            // 官方 :86-93 —— `this.context.level !== 1` 时 onClick 被换成 onMouseDown
            if (control.level !== 1)
                control.clicked();
        }
        onTapped: {
            if (control.level === 1 && !control.disabled)
                control.clicked();
        }
    }

    TapHandler {
        objectName: "dropdownItemContextMenu"

        enabled: !control.disabled
        acceptedButtons: Qt.RightButton
        onTapped: control.contextMenu()
    }

    // 焦点可进入（官方 tabIndex={-1}：只能被程序聚焦，不参与 Tab 序）
    focus: true
    activeFocusOnTab: false

    // 键盘那一半：官方挂在 `<ul>` 上靠冒泡，端口挂在条目自己身上转给 Dropdown
    // qmllint disable unqualified
    Keys.onPressed: {
        if (control.dropdownHost !== null)
            control.dropdownHost.handleItemKey(event);
    }
    // qmllint enable unqualified

}
