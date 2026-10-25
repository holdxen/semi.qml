pragma ComponentBehavior: Bound

import QtQuick

// 面包屑的一节。官方 packages/semi-ui/breadcrumb/item.tsx（BreadcrumbItemProps :19-28、
// renderIcon :86-96、getTooltipOpt :98-118、getItemInfo :120-133、renderBreadItem :135-170、
// renderItem :172-192、render :194-213）+ semi-foundation/breadcrumb/{itemFoundation.ts,
// breadcrumb.scss,variables.scss}，数值逐条对编译后的 semi.css 里 `.semi-breadcrumb*` 那一组。
//
// 官方一节的 DOM：
//   <span class="-item-wrap">                       ← inline-flex / align-items:center
//                                                       margin 4px 0 / margin-right 4
//     <span|a class="-item [-item-active] [-item-link]">  ← inline-flex / column-gap 4 /
//                                                       margin-right 4 / text-2 / 字重 400
//       {icon}                                       ← -item-icon { margin-bottom: -1 }
//                                                       尺寸被宿主改成 small(12) / default(16)
//       <span class="-item-title [-title-inline]">    ← 字符串档走 Typography.Text（maxWidth 截断
//                                                       + 溢出弹 Tooltip），节点档原样摆
//     </span>
//     <span class="-separator">/</span>             ← display:flex / text-2
//   </span>
//
// 三套颜色（variables.scss:7-13）：
//   · 未选中 -item：text-2；选中 -item-active：text-0 + 字重 600；
//   · -item-link（= !noLink，**跟是不是 a 标签、是不是选中项无关**）：hover → colorLink、
//     active → colorLinkHover；
//   · 分隔符：text-2。
//
// 端口与官方的差异（逐条，另有 PROGRESS.md 的取舍记录）：
//   · **选中项 hover 也变链接色**：官方 -item-active 那组 :hover 写的是 text-0 + cursor:default，
//     但 -item-link:hover 在样式表里排在它后面、特异度相同 ⇒ 只要没给 noLink，选中项一 hover
//     照样变 colorLink。端口照抄这个实际生效的结果（scss 的注释意图不是这样，见坑记录）。
//   · `href` 官方用来选 `a`/`span` 并真的跳转；端口没有导航，只把它挂进点击回调的那份 item 信息里。
//   · `aria-current="page"`（选中项的 wrap 上）在 Qt 侧没有等价属性 ⇒ 收了不产出差异。
//   · `-item-icon { margin-bottom: -1px }` 是 align-items:center 下 0.5px 级的视觉微调，端口按行高居中。
//   · 子项档的「children」在 QML 里没有落点（Item 的子项是 Item，不是文字），改名 `label`；
//     字符串与 Component 两档的分野与官方一致（只有字符串走截断 + Tooltip）。
//   · 一节里**条目自己给的 separator 不套 -separator 那层 span**（item.tsx:202 的 `props.separator ||
//     <span class=-separator>`）⇒ 它拿不到 text-2，跟着页面文字色走。端口照抄。
//     宿主那份（字符串还是节点都算）在这层 span **里面** ⇒ 给 Component 也照样画、也吃 text-2；
//     而 `||` 让条目给的**空串**等于没给，回落到宿主那份并重新套上 span。
Item {
    id: control

    // ---------------------------------------------------------------- 官方 BreadcrumbItemProps
    /// 官方 children（ReactNode）：字符串 ⇒ Typography 截断档；Component ⇒ inline 档，不截断
    property var label: undefined
    /// 官方 icon（ReactNode）：端口收图标名或 Component
    property var icon: null
    property string href: ""
    /// 覆盖宿主的分隔符；不给就用 context.separator
    property var separator: undefined
    property bool noLink: false
    /// 下面两条官方由宿主 cloneElement 注入（item.tsx:255-259 / :201-206）
    property bool active: false
    property bool shouldRenderSeparator: true
    /// 官方 route：routes 档是那条路由对象原样（`route._origin`），子项档不给
    property var route: undefined

    /// 宿主（官方 BreadContext：onClick / showTooltip / compact / separator）
    property Breadcrumb host: null
    /// 给宿主认名单用
    readonly property bool isBreadcrumbItem: true
    /// routes 档的条目由宿主的 Repeater 造，不进取「声明式子项」那份名单
    property bool fromRepeater: false
    /// 宿主排布时写的格序（-1 = 还没排）
    property int cellIndex: -1

    /// 官方 item 自己的 onClick（先发这条，再发宿主的 onClick —— itemFoundation.ts:29-33）
    signal clicked(var item)

    // ---------------------------------------------------------------- context 派生
    // 官方 context 缺省是 {} ⇒ 没有宿主时 compact 为假（走 default/normal 那一档）
    readonly property bool compact: control.host !== null && control.host.compact === true
    readonly property real fontSize: control.compact
        ? Theme.current.fontSizeSmall : Theme.current.fontSizeRegular      // 12 / 14
    readonly property real lineHeight: control.compact ? 16 : 20           // font-size mixin 的行高
    readonly property real iconSize: control.compact
        ? Theme.current.widthIconSmall : Theme.current.widthIconMedium      // 12 / 16
    readonly property real gap: Theme.current.spacingExtraTight             // column-gap / margin-right 4
    /// 宿主那侧的截断配置（宿主的 tooltipOpt 已经并过缺省值）
    readonly property var tooltipOpt: control.host !== null ? control.host.tooltipOpt
        : ({ width: 150, ellipsisPos: "end", opts: undefined })
    /// 官方 showTooltip: false 时 opts 是 undefined ⇒ 只截断、不弹 Tooltip
    readonly property bool tooltipOn: control.tooltipOpt.opts !== undefined
        && control.tooltipOpt.opts !== null
    readonly property real maxWidth: control.tooltipOpt.width === undefined ? 150
        : control.tooltipOpt.width
    readonly property bool elideMiddle: control.tooltipOpt.ellipsisPos === "middle"
    /// 字符串档才截断（item.tsx:140 `Boolean(children) && typeof children === 'string'`）
    readonly property bool textMode: typeof control.label === "string"
    readonly property bool hasText: control.textMode && String(control.label).length > 0
    readonly property bool hasNode: !control.textMode && control.label !== undefined
        && control.label !== null
    readonly property bool iconIsComponent: control.icon !== null && typeof control.icon !== "string"
    readonly property string iconText: control.iconIsComponent ? ""
        : (control.icon === undefined || control.icon === null ? "" : String(control.icon))
    /// 分隔符：官方 render :202 `props.separator || <span class=-separator>{context.separator}</span>`
    /// ⇒ 自己给的那份（真值才算，空串会被 `||` 顶掉）**原样摆**、不套 -separator，拿不到 text-2；
    ///   没给才吃宿主那份，且字符串与节点都套在 -separator 里 ⇒ 宿主给 Component 也照画
    readonly property bool ownSeparator: control.separator !== undefined
        && control.separator !== null && control.separator !== "" && control.separator !== false
    readonly property var effSeparator: control.ownSeparator ? control.separator
        : (control.host !== null ? control.host.separator : undefined)
    readonly property bool sepIsString: typeof control.effSeparator === "string"
    readonly property bool sepIsNode: control.effSeparator !== undefined
        && control.effSeparator !== null && !control.sepIsString
    readonly property string sepText: control.sepIsString ? String(control.effSeparator) : ""

    // 官方 getItemInfo（:120-133）：有 route 就用 route，否则现拼 { name, href? }
    readonly property var itemInfo: control.route !== undefined && control.route !== null
        ? control.route : infoOf()

    function infoOf() {
        const out = { name: control.label };
        if (control.href !== "")
            out.href = control.href;
        return out;
    }

    // 颜色三条：active 只压「基色」，hover / 按下看的是 -item-link（见文件头那条差异）
    readonly property bool linkable: !control.noLink
    readonly property color titleColor: control.pressed && control.linkable
        ? Theme.current.colorLinkHover
        : (control.hovered && control.linkable
            ? Theme.current.colorLink
            : (control.active ? Theme.current.colorText0 : Theme.current.colorText2))
    readonly property int titleWeight: control.active ? Font.DemiBold : Font.Normal   // 600 / 400
    property bool hovered: false
    property bool pressed: false

    implicitWidth: lineRow.width + control.gap       // -item-wrap { margin-right: 4 }
    implicitHeight: contentBox.height + control.gap * 2   // -item-wrap { margin: 4px 0 }

    // 条目本体（icon + 标题）与分隔符并排；两者之间那 4px 是 -item { margin-right: 4 }
    Row {
        id: lineRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: control.gap

        // ---------------------------------------------------------------- -item
        Item {
            id: contentBox

            objectName: "bcItemBox"
            width: innerRow.width
            height: control.lineHeight

            Row {
                id: innerRow

                anchors.verticalCenter: parent.verticalCenter
                // -item { column-gap: 4 }
                spacing: control.gap

                Loader {
                    id: iconSlot

                    objectName: "bcIconSlot"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.iconIsComponent
                    sourceComponent: control.iconIsComponent ? control.icon : null
                    onLoaded: control.host !== null
                        ? control.host.give(item, "size", control.iconSize) : null
                }

                Icon {
                    id: iconText

                    objectName: "bcIcon"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.iconText !== ""
                    name: control.iconText
                    size: control.iconSize
                    // 官方 renderIcon 是 cloneElement 塞 className/size，颜色跟着 -item 走
                    color: control.titleColor
                }

                // 字符串档：Typography.Text 的截断档
                Text {
                    id: titleText

                    objectName: "bcTitle"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.hasText
                    text: control.hasText ? String(control.label) : ""
                    font.pixelSize: control.fontSize
                    font.weight: control.titleWeight
                    color: control.titleColor
                    height: control.lineHeight
                    verticalAlignment: Text.AlignVCenter
                    // maxWidth 给 'auto'（或任意非数字）⇒ 不截断（官方 style.maxWidth: 'auto'）
                    property real cap: typeof control.maxWidth === "number" ? control.maxWidth : -1
                    width: cap > 0 ? Math.min(implicitWidth, cap) : implicitWidth
                    elide: cap > 0 ? (control.elideMiddle ? Text.ElideMiddle : Text.ElideRight)
                        : Text.ElideNone
                    onImplicitWidthChanged: control.host !== null
                        ? control.host.itemNaturalChanged() : null
                }

                // 节点档：-item-title-inline，不截断
                Loader {
                    id: nodeSlot

                    objectName: "bcNodeTitle"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.hasNode
                    sourceComponent: control.hasNode ? control.label : null
                    onLoaded: control.host !== null ? control.host.itemNaturalChanged() : null
                }
            }

            HoverHandler {
                id: boxHover

                cursorShape: control.linkable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onHoveredChanged: control.hovered = boxHover.hovered
            }

            TapHandler {
                id: boxTap

                acceptedButtons: Qt.LeftButton
                onPressedChanged: control.pressed = boxTap.pressed
                onTapped: {
                    // 官方：route 里带的 onClick（routes 档摊平进来的）先，再往宿主冒泡
                    if (control.route !== undefined && control.route !== null
                            && typeof control.route.onClick === "function")
                        control.route.onClick(control.itemInfo, null);
                    control.clicked(control.itemInfo);
                    if (control.host !== null)
                        control.host.itemClicked(control.itemInfo);
                }
            }
        }

        // ---------------------------------------------------------------- -separator
        Item {
            id: sepBox

            objectName: "bcSeparatorBox"
            visible: control.shouldRenderSeparator
                && (control.ownSeparator || control.sepIsNode || control.sepText !== "")
            width: Math.max(sepText.width, sepNode.width)
            height: control.lineHeight

            // 自己给的分隔符不套 -separator ⇒ 拿不到 text-2（见文件头）
            readonly property color sepColor: control.ownSeparator
                ? Theme.current.colorText0 : Theme.current.colorText2

            Text {
                id: sepText

                objectName: "bcSeparator"
                anchors.verticalCenter: parent.verticalCenter
                visible: !control.sepIsNode
                text: control.sepText
                font.pixelSize: control.fontSize
                color: sepBox.sepColor
            }

            Loader {
                id: sepNode

                objectName: "bcSeparatorNode"
                anchors.verticalCenter: parent.verticalCenter
                visible: control.sepIsNode
                sourceComponent: control.sepIsNode ? control.effSeparator : null
            }
        }
    }

    // 截断时的完整文字（官方 Typography 的 showTooltip.opts 那条路）
    Tooltip {
        id: ellipsisTip

        objectName: "bcTooltip"
        target: titleText
        text: control.hasText ? String(control.label) : ""
        trigger: "hover"
        visible: false
        position: control.host !== null && control.tooltipOpt.opts !== undefined
            && control.tooltipOpt.opts !== null && control.tooltipOpt.opts.position !== undefined
            ? control.host.placementOf(control.tooltipOpt.opts.position) : Enums.Top
        autoAdjustOverflow: control.tooltipOpt.opts !== undefined
            && control.tooltipOpt.opts !== null && control.tooltipOpt.opts.autoAdjustOverflow !== undefined
            ? control.tooltipOpt.opts.autoAdjustOverflow === true : true
        condition: control.host !== null && control.tooltipOn && control.textMode
            && titleText.implicitWidth > titleText.width + 0.5
    }
}
