pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 标签栏里的一格。对应 `packages/semi-ui/tabs/TabItem.tsx`（props :7-20、类名 :71-83、
// 结构 :85-104），样式在 `packages/semi-foundation/tabs/tabs.scss`。
//
// 数值全部对着编译后的 `packages/semi-ui/dist/css/semi.css` 21854-22609 段。
//
// ---------------------------------------------------------------- 与官方的口径差异（逐条）
//   · `className` / `style` / `restProps` 是 DOM 通道，不收。
//   · `tab` / `icon` 是 ReactNode ⇒ 端口收「字符串或 Component」两档。
//   · 官方 `onClick` / `handleKeyDown` 收 React 事件对象，端口不带；`deleteTabItem(itemKey, e)`
//     那一步的 `stopPropagation` 端口用「× 自己吃掉这次点击」表达。
//   · `role` / `aria-*` 挂 `Accessible`（role=PageTab + selected/disabled 态）。
//     `tabIndex={selected ? 0 : -1}`（:93）是 roving tabindex，端口换成「只有选中那格接焦点」。
//   · 官方那 2px 指示条**不是独立节点**，是格子自己的 `border-bottom`（竖排是 `border-left`），
//     铺满含左右内边距的整格宽、无圆角无内缩（semi.css 里 `ink-bar` 0 条规则）⇒ 端口画一条
//     同尺寸的 Rectangle 复现那条边，位置与宽度都按边框算。
//
// ---------------------------------------------------------------- 抄下来的上游行为
//   · `.semi-tabs-tab-single` 恒加（:75）且写在后面、同特异度 ⇒ 生效的是 single 那套：
//     `display: inline-block` 赢过 `display: block`，而 `float: left` 因为 single 没重声明而**留着**。
//     颜色阶梯也按 single 那份读：× 的 hover 是 **text-0**（CSS:21988 那条 5 类的规则压过
//     21951 的 text-1），而 bar 那套只在选中时才 text-1。
//   · 禁用那格**不屏蔽 CSS 悬浮态**：`TabItem.tsx:65` 只挡 onClick，`:hover` 那条
//     （0,2,1）特异度高于 `-disabled`（0,2,0）⇒ 禁用格悬停照样变 text-0。
//   · 选中那格的 × 不跟文字变 primary，被显式钉回 text-2（CSS:21948-21950）。
//   · `closable` 不判 type（:39-47 只看 closable）⇒ line / button / slash 一样出 ×，
//     尽管文档写「只有卡片式支持关闭」。
Item {
    id: control

    // ================================================================ 宿主注入
    property var host: null
    readonly property bool isTabItem: true

    // ---- 用户写的（tabList 那一条路从数组里读，children 那一条路从 TabPane 读）----
    property string itemKey: ""
    property var label: ""                      // 官方 `tab`
    property var iconValue: ""                  // 官方 `icon`
    property bool disabled: false
    property bool closable: false

    // ---- 宿主注入 ----
    property string hostType: "line"            // line | card | button | slash
    property string hostSize: "large"           // small | medium | large
    property string hostPosition: "top"         // top | left
    property bool hostSelected: false
    property bool hostFirst: false
    property bool hostLast: false

    signal clicked()
    signal closeClicked()
    signal activated()                          // 官方 Enter / Space 那一条

    readonly property bool vertical: control.hostPosition === "left"
    readonly property bool small: control.hostSize === "small"
    readonly property bool medium: control.hostSize === "medium"

    // ================================================================ 内边距（CSS 逐档）
    // line/top：16/4/14/4、12/4/10/4、8/4/6/4（CSS:22113-22136）—— 下内边距恒比上内边距少 2，
    //           就是给那条 2px 边框让位。line/left：四边同值 12 / 10 / 6（CSS:22146-22168）。
    // card、button：8/12（CSS:22238、22262）；slash：12/0（CSS:22286）。
    readonly property real padTop: control.hostType === "line"
        ? (control.vertical ? (control.small ? 6 : (control.medium ? 10 : 12))
            : (control.small ? 8 : (control.medium ? 12 : 16)))
        : (control.hostType === "slash" ? 12 : 8)
    readonly property real padBottom: control.hostType === "line"
        ? (control.vertical ? control.padTop : control.padTop - 2)
        : (control.hostType === "slash" ? 12 : 8)
    readonly property real padLeft: control.hostType === "line"
        ? (control.vertical ? control.padTop : (control.hostFirst ? 0 : 4))
        : (control.hostType === "slash" ? (control.hostFirst ? 0 : 0) : 12)
    readonly property real padRight: control.hostType === "line"
        ? (control.vertical ? control.padTop : 4)
        : (control.hostType === "slash" ? 0 : 12)

    readonly property real textHeight: 20       // 三档字号都是 14 / 行高 20（CSS:21902-21903）
    readonly property real iconWidth: control.hasIcon ? 16 + 8 : 0     // 16 的 em 盒 + margin-right 8
    readonly property real closeWidth: control.closable ? 14 + 10 : 0  // 14 的 × + margin-left 10
    readonly property real slashWidth: control.hostType === "slash" && !control.hostLast ? 16 + 8 : 0
    readonly property real borderWidth: control.indicatorWidth + control.sideBorderWidth

    /// 2px 那条指示边（line 档独有），横排在下、竖排在左
    readonly property real indicatorWidth: control.hostType === "line" ? 2 : 0
    /// card 档那 1px 实边框（选中才有颜色，未选中是 transparent 但**照样占位**）
    readonly property real sideBorderWidth: control.hostType === "card" ? 1 : 0

    implicitWidth: control.padLeft + control.iconWidth + labelMetrics.width
        + control.closeWidth + control.slashWidth + control.padRight
        + (control.vertical ? control.indicatorWidth : 0)
        + (control.hostType === "card" ? 2 : 0)          // 左右各 1px
    implicitHeight: control.padTop + control.textHeight + control.padBottom
        + (control.vertical ? 0 : control.indicatorWidth)
        + (control.hostType === "card" ? 1 : 0)          // 上边那 1px

    readonly property bool hasIcon: control.iconValue !== undefined && control.iconValue !== null
        && control.iconValue !== ""

    // ================================================================ 状态
    readonly property bool pressed: tap.pressed
    readonly property bool hovered: hover.hovered
    readonly property bool showHover: control.hovered            // 禁用档也吃悬浮态，见文件头
    readonly property bool showActive: control.pressed

    // ================================================================ 颜色
    readonly property color textColor: {
        if (control.hostSelected)
            return Theme.current.colorText0;
        if (control.showActive || control.showHover)
            return Theme.current.colorText0;
        if (control.disabled)
            return Theme.current.colorDisabledText;
        if (control.hostType === "button")
            return Theme.current.colorText2;      // CSS:22265 显式重写了一遍
        return Theme.current.colorText2;
    }
    /// button 档选中把文字染成 primary（CSS:22281-22285），其余档不跟
    readonly property color labelColor: control.hostType === "button" && control.hostSelected
        ? Theme.current.colorPrimary : control.textColor
    readonly property color iconColor: control.hostSelected
        ? (control.hostType === "button" ? Theme.current.colorPrimary : Theme.current.colorPrimary)
        : (control.showHover || control.showActive ? Theme.current.colorText0
            : Theme.current.colorText2)
    /// × 恒 text-2（含选中那格），只有它自己被悬停时才 text-0（CSS:21988-21990）
    readonly property color closeColor: closeHover.hovered ? Theme.current.colorText0
        : Theme.current.colorText2
    readonly property color indicatorColor: control.hostSelected ? Theme.current.colorPrimary
        : (control.showActive ? Theme.current.colorFill1
            : (control.showHover ? Theme.current.colorFill0 : "transparent"))
    readonly property color fillColor: {
        if (control.hostType === "line")
            return control.vertical
                ? (control.hostSelected ? Theme.current.colorPrimaryLightDefault
                    : (control.showActive ? Theme.current.colorFill1
                        : (control.showHover ? Theme.current.colorFill0 : "transparent")))
                : "transparent";                  // line/top 压根没有背景规则
        if (control.hostType === "card")
            return control.hostSelected ? "transparent"
                : (control.showActive ? Theme.current.colorFill1
                    : (control.showHover ? Theme.current.colorFill0 : "transparent"));
        if (control.hostType === "button")
            return control.hostSelected ? Theme.current.colorPrimaryLightDefault
                : (control.showActive ? Theme.current.colorFill1
                    : (control.showHover ? Theme.current.colorFill0 : "transparent"));
        return "transparent";                     // slash 没有任何背景规则
    }
    readonly property color borderColor: control.hostType === "card"
        ? (control.hostSelected ? Theme.current.colorBorder : "transparent") : "transparent"

    // ================================================================ 手势与焦点
    HoverHandler {
        id: hover

        objectName: "tabItemHover"
    }
    TapHandler {
        id: tap

        objectName: "tabItemTap"

        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            if (control.disabled)
                return;                           // TabItem.tsx:65 只挡点击
            control.clicked();
        }
    }
    // 官方 Enter / Space 走的是同一条 handleTabClick，而且**不判 disabled**
    // （foundation.ts:98-102 少了 TabItem.tsx:65 那句）⇒ 端口原样。
    // 格子只把 Qt 的键码翻成官方那串键名，语义（该不该跳、跳去哪）在宿主那边。
    signal keyPressed(string keyName)

    activeFocusOnTab: control.hostSelected
    Keys.onPressed: (event) => {
        const name = control.keyNameOf(event.key);
        if (name === "")
            return;
        event.accepted = true;
        if (name === "Enter")
            control.activated();
        control.keyPressed(name);
    }

    function keyNameOf(code) {
        if (code === Qt.Key_Left)
            return "ArrowLeft";
        if (code === Qt.Key_Right)
            return "ArrowRight";
        if (code === Qt.Key_Up)
            return "ArrowUp";
        if (code === Qt.Key_Down)
            return "ArrowDown";
        if (code === Qt.Key_Home)
            return "Home";
        if (code === Qt.Key_End)
            return "End";
        if (code === Qt.Key_Delete || code === Qt.Key_Backspace)
            return "Delete";
        if (code === Qt.Key_Return || code === Qt.Key_Enter || code === Qt.Key_Space)
            return "Enter";
        return "";
    }

    Accessible.role: Accessible.PageTab
    Accessible.name: control.textOf(control.label)
    Accessible.focusable: control.hostSelected
    Accessible.onPressAction: {
        if (!control.disabled)
            control.clicked();
    }

    // ================================================================ 背景与边框
    Rectangle {
        objectName: "tabItemBackground"

        anchors.fill: parent
        color: control.fillColor
        // card 档的边框：横排是「上左右 1px + 下边那条被涂成 bg-1 用来擦基线」，
        // 竖排是「上左右 1px + 右边不画、改用一条 bg-1 的遮罩」（CSS:22203-22237）
        border.width: control.hostType === "card" ? 1 : 0
        border.color: control.borderColor
        radius: control.hostType === "button" ? Theme.current.radiusExtraSmall : 0
        topLeftRadius: control.cornerTL
        topRightRadius: control.cornerTR
        bottomLeftRadius: control.cornerBL
        bottomRightRadius: control.cornerBR
    }

    readonly property real cornerTL: control.hostType === "card"
        ? (control.vertical ? Theme.current.radiusExtraSmall : Theme.current.radiusExtraSmall) : 0
    readonly property real cornerTR: control.hostType === "card"
        ? (control.vertical ? 0 : Theme.current.radiusExtraSmall) : 0
    readonly property real cornerBL: control.hostType === "card"
        ? (control.vertical ? Theme.current.radiusExtraSmall : 0) : 0
    readonly property real cornerBR: control.hostType === "card" ? 0 : 0

    /// card 档选中时把「与基线重合」那条边涂成 bg-1，等于把基线擦掉（CSS:22206 / 22223-22231）
    Rectangle {
        objectName: "tabItemBaselineMask"

        visible: control.hostType === "card" && control.hostSelected
        color: Theme.current.colorBg1
        x: control.vertical ? parent.width - 1 : control.sideBorderWidth
        y: control.vertical ? 0 : parent.height - 1
        width: control.vertical ? 1 : Math.max(0, parent.width - 2)
        height: control.vertical ? parent.height : 1
    }

    // ================================================================ 2px 指示边
    Rectangle {
        objectName: "tabItemIndicator"

        visible: control.hostType === "line"
        x: control.vertical ? 0 : 0
        y: control.vertical ? 0 : parent.height - control.indicatorWidth
        width: control.vertical ? control.indicatorWidth : parent.width
        height: control.vertical ? parent.height : control.indicatorWidth
        color: control.indicatorColor
    }

    // ================================================================ 内容：图标 + 文字 + ×
    // 官方图标是 `.semi-icon` + `position: relative; top: 3px; margin-right: 8px`（CSS:21914-21920）
    Loader {
        id: iconLoader

        objectName: "tabItemIconComponent"

        x: control.padLeft
        y: control.padTop + (control.textHeight - 16) / 2 + 3
        visible: control.hasIcon && control.iconIsComponent
        sourceComponent: control.iconIsComponent ? control.iconValue : null
        onLoaded: {
            if (item === null)
                return;
            item.color = control.iconColor;
        }
    }

    Icon {
        id: iconName

        objectName: "tabItemIconName"

        x: control.padLeft
        y: control.padTop + (control.textHeight - 16) / 2 + 3
        visible: control.hasIcon && control.iconIsString
        name: control.iconIsString ? String(control.iconValue) : ""
        size: 16
        color: control.iconColor
    }

    readonly property bool iconIsComponent: typeof control.iconValue === "object"
        && control.iconValue !== null
    readonly property bool iconIsString: typeof control.iconValue === "string"
        && control.iconValue !== ""
    readonly property real iconBoxWidth: control.hasIcon ? 16 + 8 : 0

    Text {
        id: labelMetrics

        objectName: "tabItemLabelMetrics"

        visible: false
        font.pixelSize: Theme.current.fontSizeRegular
        text: control.textOf(control.label)
    }

    Loader {
        id: labelLoader

        objectName: "tabItemLabelComponent"

        x: control.padLeft + control.iconBoxWidth
        y: control.padTop
        visible: control.labelIsComponent
        sourceComponent: control.labelIsComponent ? control.label : null
    }

    readonly property bool labelIsComponent: typeof control.label === "object"
        && control.label !== null

    Text {
        id: labelText

        objectName: "tabItemLabel"

        x: control.padLeft + control.iconBoxWidth
        y: control.padTop
        height: control.textHeight
        visible: !control.labelIsComponent
        text: control.textOf(control.label)
        color: control.labelColor
        font.pixelSize: Theme.current.fontSizeRegular
        font.weight: control.hostSelected ? Font.DemiBold : Font.Normal
        Accessible.ignored: true
    }

    // × —— 官方是 IconClose 挂在格子末尾，14×14、margin-left 10（CSS:21921-21926）
    Icon {
        id: closeIcon

        objectName: "tabItemClose"

        x: control.padLeft + control.iconBoxWidth + control.textWidth + 10
        y: control.padTop + (control.textHeight - 14) / 2
        visible: control.closable
        name: "close"
        size: 14
        color: control.closeColor

        HoverHandler {
            id: closeHover

            objectName: "tabItemCloseHover"
        }
        TapHandler {
            objectName: "tabItemCloseTap"

            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: control.closeClicked()      // 官方 deleteTabItem 里那句 stopPropagation
        }
    }

    /// Component 那一档的宽按被载入项的实际宽读（钩子节点是任意 Item，qmllint 认不出类型）
    readonly property real textWidth: control.labelIsComponent
        // qmllint disable missing-property
        ? (labelLoader.item === null ? 0 : labelLoader.item.width)
        // qmllint enable missing-property
        : labelMetrics.implicitWidth

    // ================================================================ slash 档那道斜线
    // 官方是**非末格自己的 ::after**：8×14 的盒子里一条 `to bottom right` 的渐变带，
    // 中线两侧各 1px ⇒ 一条 2px 粗的对角线，颜色恒 text-2（CSS:22295-22305）。
    // 端口用一条等长的旋转矩形复现：盒子对角线长 √(8²+14²)，角度 atan2(14,8)。
    Rectangle {
        objectName: "tabItemSlash"

        readonly property real boxW: 8
        readonly property real boxH: 14
        readonly property real diag: Math.sqrt(boxW * boxW + boxH * boxH)

        visible: control.hostType === "slash" && !control.hostLast
        width: diag
        height: 2
        x: control.padLeft + control.iconBoxWidth + control.textWidth
            + control.closeWidth + 16 + (boxW - diag * Math.cos(Math.atan2(boxH, boxW))) / 2
        y: control.padTop + (control.textHeight - boxH) + boxH / 2
        color: Theme.current.colorText2
        // `to bottom right` 是从左上到右下那条对角线 ⇒ 顺时针转正角度（QML 正角是顺时针）
        rotation: Math.atan2(boxH, boxW) * 180 / Math.PI
        transformOrigin: Item.Center
    }

    function textOf(v) {
        if (v === undefined || v === null)
            return "";
        if (typeof v === "object")
            return "";
        return String(v);
    }
}
