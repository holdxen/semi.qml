pragma ComponentBehavior: Bound

import QtQuick

// 锚点的一节。规格照 packages/semi-ui/anchor/link.tsx +
// semi-foundation/anchor/{linkFoundation.ts,anchor.scss,variables.scss}，
// 数值逐条对编译后的 packages/semi-ui/dist/css/semi.css（`.semi-anchor*`）。
//
// 官方一节的 DOM（link.tsx:160-174）：
//   <div class="-link" role="listitem">            ← 没有自己的内边距/外边距
//     <div role="link" tabindex=0 class="-link-title [-active] [-disabled]"
//          style="padding-left: 8×level" onClick onKeyPress>
//       {showTooltip ? <Typography.Text ellipsis size type=tertiary> : title}
//     </div>
//     <div role="list">{children}</div>            ← autoCollapse 时按 activeLink 决定画不画
//   </div>
//
// 度量（variables.scss + 编译后的 semi.css）：
//   · 标题行 = 行高（default 20 / small 16）+ 上下内边距各 4 ⇒ 28 / 24，**行与行之间没有间距**；
//   · 左内边距只有那一处内联的 `8 × level`（`$spacing-anchor_link-paddingLeft: 8` 在 scss 里
//     根本没被引用 ⇒ 死令牌）；
//   · 字号 default 14/20、small 12/16；
//   · 四档字色：未选中 text-2、悬浮 tertiary-hover、选中 text-0、禁用 disabled-text；
//     选中与未选中的 `background` 都是 transparent，选中**不加字重**；
//   · `overflow: hidden; text-overflow: ellipsis; white-space: nowrap` ⇒ 标题永远单行、超出就截；
//   · `transition: color var(--semi-transition_duration-none)` = **0ms**（无动画）；
//     顺带一条上游 bug：scss 写的是 `transform: scale(var(--semi-transform_scale-none))`，
//     而那个 token 自己就是 `scale(1,1)` ⇒ 展开成 `scale(scale(1,1))` 非法声明，整条失效；
//   · `:focus-visible` 环 2px solid primary-light-active、offset -2、圆角 3；
//   · disabled 的 `:hover` 又被钉回 disabled-text ⇒ 悬浮不变色。
//
// 端口与官方的差异（逐条）：
//   · 官方 `href` 既是 CSS 选择器（`document.querySelector(href)` 找内容节点）又是 activeLink 的键。
//     QML 没有全局选择器 ⇒ `href` 只当**标识串**（回调载荷、比对仍用它），内容节点走端口自有的
//     `targetItem`。缺省值 `'/'` 照抄（官方 defaultProps 里那条）。
//   · `title` 官方是 ReactNode ⇒ 端口是「字符串或 Component」。字符串走截断 + 浮层那一档；
//     Component 原样摆（没有可截断的文字，也就永远不会出浮层）。
//   · `showTooltip` 官方可以是 `true` 或 `{type:'tooltip'|'popover', opts}`；端口两档都接，
//     popover 档官方往 opts 并一条 `showArrow: true`，端口照做。没给 `position` 时
//     tooltip 吃本库缺省（Top）、popover 吃 Popover 缺省（Bottom）。
//   · 官方 `onKeyPress` 没判键（浏览器只对可打印字符与回车发 keypress）⇒ 端口按
//     `event.text` 非空或回车过滤，贴近那一档。
//   · `aria-disabled` / `aria-details="active"` / `role` / `tabIndex` 落 `Accessible.*` 与
//     `activeFocusOnTab`；官方「!showTooltip 且 title 是字符串时把 title 塞进原生 title 属性」
//     是浏览器悬浮提示，Qt 侧没有等价物 ⇒ 不收。
//   · `className` / `style` 与全站同一口径：收了不产出可见差异。rtl 那档（paddingRight、
//     滑轨换边）端口不做。
Item {
    id: control

    // ---------------------------------------------------------------- 官方 LinkProps
    property string href: "/"
    property var title: ""
    property bool disabled: false
    property string className: ""
    property var style: undefined
    /// 官方 children：下一级锚点（宿主按层级注入 `level`）
    default property alias sublinks: childColumn.data
    /// 端口替身：官方靠 `document.querySelector(href)` 找内容节点
    property Item targetItem: null

    /// 官方由宿主 renderChildren 注入（1 起，每深一级 +1）
    property int level: 1
    /// 官方由 AnchorContext 的 activeLink === href 算，端口由宿主写
    property bool selected: false
    /// 宿主在排布时写进来的可用宽（0 = 还没排过）
    property real rowWidth: 0
    /// 宿主接线一次（官方是 context 注入 onClick；端口用 signal connect，得防重复接）
    property bool hostWired: false
    /// 给宿主认名单用（同 BreadcrumbItem.isBreadcrumbItem 那条口径）
    readonly property bool isAnchorLinkType: true
    /// 给宿主递归用：下一级那一列
    readonly property alias childColumnRef: childColumn

    /// 官方 context.onClick 的那一跳（点击与按键都走它）
    signal clicked()

    // ---------------------------------------------------------------- context 派生
    readonly property var root: anchorRoot()
    readonly property bool small: root !== null ? root.size === "small" : false
    readonly property real lineHeight: control.small ? 16 : 20
    readonly property real fontSize: control.small
        ? Theme.current.fontSizeSmall : Theme.current.fontSizeRegular
    /// 官方内联在标题上的 paddingLeft: 8 × level
    readonly property real indent: Theme.current.spacingTight * control.level
    readonly property real paddingY: Theme.current.spacingExtraTight
    readonly property bool showTooltip: root !== null ? root.tooltipOn : false
    readonly property bool tipIsPopover: root !== null && root.tooltipKind === "popover"
    /// 官方 children 是字符串还是节点，决定走不走 Typography 的截断档
    readonly property bool textMode: typeof control.title === "string"
    readonly property bool hovered: rowHover.hovered
    readonly property color titleColor: control.disabled
        ? Theme.current.colorDisabledText
        : (control.hovered ? Theme.current.colorTertiaryHover
            : (control.selected ? Theme.current.colorText0 : Theme.current.colorText2))

    implicitWidth: Math.max(titleRow.width, childColumn.visible ? childColumn.width : 0)
    implicitHeight: titleRow.height + (childColumn.visible ? childColumn.height : 0)

    // qmllint disable missing-property
    function anchorRoot() {
        let node = control.parent;
        while (node !== null && node !== undefined) {
            if (node.isAnchorRoot === true)
                return node;
            node = node.parent;
        }
        return null;
    }

    /// 官方 _getLinkToMap 走的是 React 元素树；端口按父链找上一条 AnchorLink
    function parentLink() {
        let node = control.parent;
        while (node !== null && node !== undefined) {
            if (node.isAnchorLinkType === true)
                return node;
            node = node.parent;
        }
        return null;
    }
    // qmllint enable missing-property

    /// 官方 handleClick：`!disabled && context.onClick(e, href)`
    function handleClick() {
        if (control.disabled)
            return;
        control.clicked();
    }

    /// 官方 getLinksBoundingTop 里那一条：找不到节点给 -Infinity；
    /// 而 `(... - containerTop - offsetTop) || -Infinity` 让**恰好等于 0** 也算 -Infinity
    function targetTop() {
        const r = control.root;
        if (control.targetItem === null)
            return -Infinity;
        if (r === null || r.container === null)
            return control.targetItem.y;
        return control.targetItem.mapToItem(r.container.contentItem, 0, 0).y;
    }

    // ---------------------------------------------------------------- 标题那一行
    Item {
        id: titleRow

        objectName: "anchorTitleRow"
        width: control.rowWidth > 0 ? control.rowWidth
            : titleText.implicitWidth + control.indent
        height: control.lineHeight + control.paddingY * 2       // 28 / 24
        activeFocusOnTab: true

        Text {
            id: titleText

            objectName: "anchorTitle"
            x: control.indent
            anchors.verticalCenter: parent.verticalCenter
            visible: control.textMode
            text: control.textMode ? String(control.title) : ""
            width: Math.max(0, titleRow.width - control.indent)
            elide: Text.ElideRight
            maximumLineCount: 1
            font.pixelSize: control.fontSize
            color: control.titleColor
            Accessible.role: Accessible.StaticText     // 官方 role="link"，Qt 侧没有这一档角色
            Accessible.name: control.textMode ? String(control.title) : ""
            // 官方 aria-disabled 在 Qt 侧没有等价物（Accessible 附加属性里没有 disabled 这一条）
            Accessible.description: control.disabled ? "disabled" : ""
        }

        Loader {
            id: nodeTitle

            objectName: "anchorTitleNode"
            x: control.indent
            anchors.verticalCenter: parent.verticalCenter
            visible: !control.textMode
            sourceComponent: control.textMode ? null : control.title
        }

        // 官方 disabled 那一档照样有 :hover（只是颜色被钉回 disabled-text）与
        // cursor: not-allowed ⇒ handler 不关，挡点在 handleClick 里（同官方）
        HoverHandler {
            id: rowHover

            objectName: "anchorRowHover"
            cursorShape: control.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        }

        TapHandler {
            id: rowTap

            objectName: "anchorRowTap"
            acceptedButtons: Qt.LeftButton
            onTapped: control.handleClick()
        }

        // 官方 onKeyPress 没判键 ⇒ 可打印字符与回车都跳
        Keys.onPressed: function (event) {
            if (event.text.length > 0 || event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter)
                control.handleClick();
        }

        // :focus-visible 那一圈（2px、offset -2、圆角 3）
        Rectangle {
            objectName: "anchorFocusRing"
            anchors.fill: parent
            anchors.margins: -2
            radius: 3
            color: "transparent"
            border.width: 2
            border.color: Theme.current.colorPrimaryLightActive
            visible: FocusVisible.shouldShow(titleRow.activeFocus)
        }
    }

    // ---------------------------------------------------------------- 下一级
    Column {
        id: childColumn

        objectName: "anchorChildColumn"
        y: titleRow.height
        // 不许写 parent.width：Item.width 没赋值时回落 implicitWidth，而本项的 implicitWidth
        // 又读这一列的宽 ⇒ 自己成环。可用宽由宿主写进 rowWidth
        width: control.rowWidth
        spacing: 0
        // 官方 !autoCollapse ⇒ 无条件渲染；开了才按「自己是 activeLink，或 activeLink 在自己的子孙里」
        visible: control.root !== null ? control.root.revealsChildren(control.href) : true
    }

    // ---------------------------------------------------------------- 浮层那一档
    // 官方走 Typography 的 ellipsis：只有真的截断才弹
    Tooltip {
        id: tipLayer

        objectName: "anchorTipTooltip"
        target: titleText
        text: control.textMode ? String(control.title) : ""
        trigger: "hover"
        visible: false
        position: control.root !== null ? control.root.tooltipPlacement : Enums.Top
        condition: control.showTooltip && !control.tipIsPopover
            && control.textMode && titleText.implicitWidth > titleText.width + 0.5
    }

    Popover {
        id: tipLayerPopover

        objectName: "anchorTipPopover"
        target: titleText
        text: control.textMode ? String(control.title) : ""
        trigger: "hover"
        visible: false
        showArrow: true                                       // 官方 popover 档并进 opts 的那条
        position: control.root !== null ? control.root.tooltipPlacement : Enums.Bottom
        condition: control.showTooltip && control.tipIsPopover
            && control.textMode && titleText.implicitWidth > titleText.width + 0.5
    }
}
