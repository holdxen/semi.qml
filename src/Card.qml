pragma ComponentBehavior: Bound

import QtQuick

// 卡片。官方 `packages/semi-ui/card/index.tsx`（CardProps :19-53、defaultProps :78-83、
// renderHeader/renderCover/renderBody/renderFooter :85-215）+ `semi-foundation/card/
// {card.scss,variables.scss}`。
//
//     Card {
//         width: 360
//         title: "Semi Design"
//         headerExtraContent: Component { Text { text: "更多" } }
//         Text { width: parent.width; text: "正文" }
//     }
//
// ------------------------------------------------------------------ 官方 CardProps
//   · `actions` / `bodyStyle` / `bordered` / `className` / `cover` / `headerExtraContent` /
//     `footer` / `footerLine` / `footerStyle` / `header` / `headerLine` / `headerStyle` /
//     `loading` / `shadows` / `style` / `title` + a11y 的 `aria-label`，一共 17 条。
//   · ReactNode 档（title / headerExtraContent / header / cover / footer / actions 的每一项）
//     在本库统一口径：**字符串（或数字）或 `Component`**。
//   · `header` 优先级最高：`if (header || headerExtraContent || title)`（:114）里只要给了
//     `header`，`{header || (...)}`（:117）就把 title 与 headerExtraContent 整条 wrapper 换掉，
//     但**外层的 padding 和 headerLine 那条线照旧**（线在 -header 上，不在 wrapper 上）。
//   · `title` 给的是字符串时官方套 `<Typography.Title heading={6} ellipsis={{showTooltip:true,
//     rows:1}}>`（:131-138）⇒ 16 / 22 / **600**、单行截尾、截到了才出 Tooltip。
//   · `shadows` 只有 `hover` / `always` 两档（strings.SHADOWS），不给就没阴影；给了就有
//     `cursor: pointer`（card.scss -shadows）。
//
// ------------------------------------------------------------------ 规格
// card.scss + variables.scss：
//   · 本体：bg-0、圆角 radius-medium、`box-sizing: border-box`、`overflow: hidden`、
//     **自己没有内边距**（`padding: 0`），描边 1px color-border（bordered）。
//   · 四段从上到下是 header → cover → body → footer，其中 **body 无条件渲染**
//     （renderBody 直接 return 那个 div），所以一张空卡也占上下 20 + 20 = 40。
//   · header / body / footer 各自 `padding: $spacing-card-padding`（base-loose = 20），
//     headerLine 是 header 的 `border-bottom`、footerLine 是 footer 的 `border-top`（各 1px）。
//   · header 里那条 wrapper 是 `flex-direction: row-reverse` + `justify-content: space-between`
//     + `align-items: flex-start`：DOM 里 extra 在前，视觉是标题靠左、附加靠右，两坨**都顶对齐**。
//     有 extra 时标题那格带 `margin-right: $spacing-card-margin`（也是 20）。
//   · 字号：本体 14 / 20 / regular；**只有 -body 定字色**（text-1），-header / -cover / -footer
//     三段没有颜色规则（官方继承使用方页面），端口按本库页面缺省落 text-0；标题（字符串档）16 / 22 / 600；
//     `-header-wrapper-extra` 16 / 700 / text-0（行高没重赋 ⇒ 继承本体的 20）；
//     `-meta-wrapper-title` 16 / 22 / **700**（比 header 的标题重一档，是 card 自己的令牌）。
//   · cover 那条是 `> * { display:block; width:100% }` ⇒ 封面的直接子节点一律铺满整幅。
//   · actions：`margin-top: 20` + `padding-top: 20` + `border-top: 1px`，条目之间 12
//     （index.tsx 写死 `spacing={12}`，不是令牌）。
//   · `shadows` 的阴影是 `--semi-shadow-elevated`，过渡 300ms（$motion-card-transition_duration
//     是写死的 300ms，没走 duration 令牌）。
//
// ------------------------------------------------------------------ 端口取舍
//   · **宽度**：官方是块级 div，宽度恒吃满父容器（demo 一律靠 `style.maxWidth` 收窄）。QML 没有
//     布局引擎兜着 ⇒ 端口把「父容器给的宽」留给调用方自己写 `width`（同 List），另外补一条
//     自然宽当 `implicitWidth` 兜底：调用方没写宽时按头 / 正文 / 脚三段的自然宽取最大，
//     而不是像官方那样塌成 0。正文里写了 `width: parent.width` 的换行 Text 不参与这条自然宽
//     （它自己声明的 width 绑定优先），这是端口相对 CSS 的口径差。
//     不做「按内容收缩」的完整排版是因为位置器（Column/Row）的 implicitWidth 读的是子项
//     **实际宽**，那条链会成环塌 0。
//   · `bodyStyle` / `headerStyle` / `footerStyle` / `style` / `className` 收了不产出可见差异
//     （官方那几条只喂 DOM；demo 里靠 bodyStyle 做的 flex 排版，端口在卡片内容里自己摆 Row）。
//   · `overflow: hidden` 端口只落地**矩形**那一半（contentClip 的 `clip`）。卡片那 6px 圆角
//     切封面顶角这一轮仍然没做，但**原因不是「做不了」**：当年记的「MultiEffect 的 source 必须
//     正在正常绘制、隐藏源纹理是空的」已在 2026-10-21 被 Avatar 那轮逐像素判废（隐藏 Image /
//     分层容器当 source 都画得出来，真门槛只在 `maskSource` 要能当纹理源，见 PROGRESS.md 坑 117）
//     ⇒ 顶角圆切是有路子的（`Image{visible:false}` + 分层圆角矩形遮罩 + MultiEffect），
//     留给 Card 的下一轮重做并补像素复核；现在要圆角仍由调用方自己带遮罩。
//   · 正文那 14 / 20 / text-1 在官方是 CSS **继承**给卡片里的文字；QML 的普通 Item 没有字体
//     继承 ⇒ 端口给不了，调用方自己写 `font.pixelSize` / `color`（gallery 各节就是这么写的）。
//   · `aria-label` → `Accessible.name`；`aria-busy` **端口没有等价物** —— Qt 6.11 的
//     qquickaccessibleattached_p.h 那份 STATE_PROPERTY 名单里没有 busy 这一档。
//   · 阴影那层只出 4px/14px 那一档：`--semi-shadow-elevated` 的第一层是 `0 0 1px`，
//     MultiEffect 出不了双层（坑 34），那 1px 由 `bordered` 的描边顶替 —— 与 SemiPopupShadow
//     同一口径。`bordered: false` 配 `shadows` 时端口会比官方少那一圈 1px。
//   · `shadows: 'hover'` 的 `z-index: 1` 端口落在卡片自己的 `z` 上，只在 hover 期间为 1。
//
// ------------------------------------------------------------------ 照抄的官方怪处
//   · `actions: []` 也给：`Array.isArray(actions)` 是真 ⇒ 那条 41（20+1+20）高的空操作区照样画，
//     一条线挂在正文底下。端口照抄（判据是「是不是数组」，不是「有没有内容」）。
//   · `loading` 只在**有 children 时**才有占位：`{children && <Skeleton …>}`（:189）。
//     一张空卡 `loading: true` 什么占位都不出，只有那 40 的内边距。端口照抄。
//   · `bordered` 只管外框那 1px；`headerLine` / `footerLine` 各自管自己那条线，三个互不相干
//     （`headerLine` 缺省 true、`footerLine` 缺省 false）。
Item {
    id: control

    // ---- 官方 CardProps（index.tsx:19-53，缺省 :78-83）----
    property var actions: undefined              // Array<ReactNode>
    property var bodyStyle: undefined            // 死 prop
    property bool bordered: true
    property string className: ""                // 死 prop
    property var cover: undefined
    property var footer: undefined
    property bool footerLine: false
    property var footerStyle: undefined          // 死 prop
    property var header: undefined
    property bool headerLine: true
    property var headerStyle: undefined          // 死 prop
    property bool loading: false
    property string shadows: ""                  // '' | hover | always
    property var style: undefined                // 死 prop
    property var title: undefined
    property var headerExtraContent: undefined
    property string ariaLabel: ""                // 官方 'aria-label'

    /// 官方 children：内容区的正文，竖着排（block 流）
    default property alias content: bodyZone.data

    /// 官方 children 的条数。`Row.data` / `children` 这类列表属性没有 NOTIFY，绑定读不到 ⇒
    /// 由 onChildrenChanged 记进普通属性。
    property int declaredCount: 0

    /// 网格型卡片组下发给成员卡的（官方是 `.semi-card-group-grid .semi-card{border-radius:0}`
    /// 那条后代选择器，端口没有 CSS ⇒ 由 CardGroup 逐张写）
    property bool cardGroupGrid: false

    // ---- 派生开关 ----
    readonly property bool customHeader: control._taken(control.header)
    readonly property bool titleTaken: !control.customHeader && control._taken(control.title)
    readonly property bool extraTaken: !control.customHeader && control._taken(control.headerExtraContent)
    readonly property bool headerTaken: control.customHeader || control.titleTaken || control.extraTaken
    readonly property bool coverTaken: control._taken(control.cover)
    readonly property bool footerTaken: control._taken(control.footer)
    /// 官方判据是 `Array.isArray(actions)` ⇒ 空数组也算，操作区那条线照样画
    readonly property bool actionsTaken: Array.isArray(control.actions)
    readonly property int actionCount: control.actionsTaken ? control.actions.length : 0
    /// 官方 `<Skeleton>` 只在 children 存在时才挂 ⇒ 空卡 loading 不出占位
    readonly property bool skeletonOn: control.loading && control.declaredCount > 0
    readonly property bool shadowSet: control.shadows === "hover" || control.shadows === "always"
    readonly property bool shadowShown: control.shadows === "always"
        || (control.shadows === "hover" && cardHover.hovered)

    // ---- 令牌 ----
    property real sectionPadding: Theme.current.spacingBaseLoose      // $spacing-card-padding
    property real innerGap: Theme.current.spacingBaseLoose            // $spacing-card-margin
    property real actionsItemGap: Theme.current.spacingBaseTight      // index.tsx 写死 12
    property real seamW: Theme.current.borderThicknessControl         // $width-card-border
    property real borderW: control.bordered ? Theme.current.borderThicknessControl : 0
    property real cornerRadius: control.cardGroupGrid ? 0 : Theme.current.radiusMedium
    property real lineHeight: 20                                      // $font-card_default-lineHeight

    // ---- 各段的内容高 ----
    readonly property real headerNodeHeight: control.customHeader
        ? (control._isText(control.header) ? headerText.implicitHeight : headerLoader.implicitHeight)
        : Math.max(control.titleTaken ? titleSlot.height : 0,
            control.extraTaken ? extraSlot.height : 0)
    readonly property real coverNodeHeight: control.coverTaken
        ? (control._isText(control.cover) ? coverText.implicitHeight : coverLoader.implicitHeight) : 0
    readonly property real bodyNodeHeight: bodySkeleton.implicitHeight
    readonly property real actionsNodeHeight: actionsRow.implicitHeight
    readonly property real footerNodeHeight: control.footerTaken
        ? (control._isText(control.footer) ? footerText.implicitHeight : footerLoader.implicitHeight) : 0

    // ---- 各段占的总高（含自己的 padding 与那条线）----
    readonly property real headerHeight: control.headerTaken
        ? control.sectionPadding * 2 + control.headerNodeHeight
            + (control.headerLine ? control.seamW : 0) : 0
    readonly property real coverHeight: control.coverTaken ? control.coverNodeHeight : 0
    readonly property real actionsHeight: control.actionsTaken
        ? control.innerGap + control.seamW + control.sectionPadding + control.actionsNodeHeight : 0
    readonly property real bodyHeight: control.sectionPadding * 2 + control.bodyNodeHeight
        + control.actionsHeight
    readonly property real footerHeight: control.footerTaken
        ? control.sectionPadding * 2 + control.footerNodeHeight
            + (control.footerLine ? control.seamW : 0) : 0

    // ---- 卡片头那一档的自然尺寸（给 CardGroup 排位置用）----
    /// 官方 header 那格是 `width:100%` 的 flex item ⇒ 端口把它当「标题自然宽 + 20 + 附加自然宽」，
    /// 上下各 20 的内边距照 card.scss。
    readonly property real headerNaturalWidth: !control.headerTaken ? 0
        : control.sectionPadding * 2 + (control.customHeader
            ? (control._isText(control.header) ? headerText.implicitWidth : headerLoader.implicitWidth)
            : (control.titleTaken
                ? (control._isText(control.title) ? titleText.implicitWidth : titleLoader.implicitWidth)
                    + (control.extraTaken
                        ? control.innerGap + (control._isText(control.headerExtraContent)
                            ? extraText.implicitWidth : extraLoader.implicitWidth) : 0)
                : (control._isText(control.headerExtraContent)
                    ? extraText.implicitWidth : extraLoader.implicitWidth)))
    /// 整卡的自然宽 = 头 / 正文 / 脚三段里最宽的那条（封面那条 CSS 只给宽不给值）
    readonly property real naturalWidth: Math.max(control.headerNaturalWidth,
        control.bodyNaturalWidth + control.sectionPadding * 2,
        control.footerNaturalWidth + control.sectionPadding * 2)
    /// 正文档的自然宽要逐个子项读 `implicitWidth`，不能读 `Column.implicitWidth` —— 位置器的
    /// 隐式宽吃的是子项**实际宽**，而正文里那句 `width: parent.width` 的实际宽正是从卡片宽来的，
    /// 「卡片宽 ← implicitWidth ← 子项实际宽 ← 卡片宽」就成环（同坑 110 那一族）。
    /// `declaredCount` 在这里被读了一次：`children` 没有 NOTIFY，绑定靠它才知道名单变了。
    readonly property real bodyNaturalWidth: control.skeletonOn
        ? bodySkeleton.implicitWidth : control.bodyZoneNaturalWidth()

    function bodyZoneNaturalWidth() {
        let w = 0;
        for (let i = 0; i < control.declaredCount; ++i) {
            const node = bodyZone.children[i];
            if (node === null || node === undefined || node instanceof Repeater)
                continue;
            w = Math.max(w, node.implicitWidth);
        }
        return w;
    }
    readonly property real footerNaturalWidth: !control.footerTaken ? 0
        : (control._isText(control.footer) ? footerText.implicitWidth : footerLoader.implicitWidth)

    // 端口相对 CSS 的那条退路：官方块级 div 恒吃满父容器，这里在「调用方没给宽」时按
    // 头 / 正文 / 脚三段的自然宽取最大，免得整张卡塌成 0 宽。
    implicitWidth: control.naturalWidth
    implicitHeight: control.borderW * 2 + control.headerHeight + control.coverHeight
        + control.bodyHeight + control.footerHeight

    // 官方那条 aria-label ⇒ Accessible.name。aria-busy 落不了地：Qt 6.11 的
    // qquickaccessibleattached_p.h 里 STATE_PROPERTY 那张名单没有 busy。
    Accessible.name: control.ariaLabel

    // .semi-card-shadows { cursor: pointer }：给了 shadows 才变手型
    HoverHandler {
        id: cardHover

        objectName: "cardHover"
        enabled: control.shadowSet
        cursorShape: control.shadowSet ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // -shadows-hover:hover { z-index: 1 }：栅格卡片组里让悬浮的这张压在邻居的阴影上
    z: control.shadows === "hover" && cardHover.hovered ? 1 : 0

    // ------------------------------------------------------------------ 底与阴影
    Rectangle {
        id: surface

        objectName: "cardSurface"

        anchors.fill: parent
        radius: control.cornerRadius
        color: Theme.current.colorBg0
        border.width: control.borderW
        border.color: Theme.current.colorBorder
    }

    // --semi-shadow-elevated。hover 档用 300ms 淡入淡出顶 CSS 的
    // `transition: box-shadow $motion-card-transition_duration`。
    SemiPopupShadow {
        id: cardShadow

        objectName: "cardShadow"

        anchors.fill: parent
        z: -1
        radius: control.cornerRadius
        opacity: control.shadowShown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }

    // ------------------------------------------------------------------ 内容（overflow: hidden）
    // 官方 .semi-card { overflow: hidden }：裁的是 padding box ⇒ 内容不许盖住那 1px 描边。
    Item {
        id: contentClip

        objectName: "cardContentClip"

        x: control.borderW
        y: control.borderW
        width: Math.max(0, control.width - control.borderW * 2)
        height: Math.max(0, control.height - control.borderW * 2)
        clip: true

        // ---- header ----
        Item {
            id: headerBlock

            objectName: "cardHeader"

            width: contentClip.width
            height: control.headerHeight
            visible: control.headerTaken

            // renderHeader 的 padding 盒
            Item {
                id: headerPaddingBox

                objectName: "cardHeaderPaddingBox"

                x: control.sectionPadding
                y: control.sectionPadding
                width: headerBlock.width - control.sectionPadding * 2
                height: control.headerNodeHeight

                // header 自定义档
                Loader {
                    id: headerLoader

                    objectName: "cardHeaderNode"

                    visible: control.customHeader && !control._isText(control.header)
                    active: visible
                    sourceComponent: control._nodeOf(control.header)
                }

                Text {
                    id: headerText

                    objectName: "cardHeaderText"

                    visible: control.customHeader && control._isText(control.header)
                    text: control._isText(control.header) ? String(control.header) : ""
                    // card.scss 只给 -body 定色（text-1）；-header / -cover / -footer 三段没有颜色规则，
                    // 官方是继承使用方页面的字色 ⇒ 端口按本库页面缺省落 text-0，这不是组件规格。
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: control.lineHeight
                    lineHeightMode: Text.FixedHeight
                }

                // title / headerExtraContent 档：row-reverse + space-between + flex-start
                Item {
                    id: headerWrapper

                    objectName: "cardHeaderWrapper"

                    visible: !control.customHeader
                    width: headerPaddingBox.width
                    height: control.headerNodeHeight

                    Item {
                        id: extraSlot

                        objectName: "cardHeaderExtraSlot"

                        visible: control.extraTaken
                        y: 0
                        // 贴右的位移要读**自己那条 width 绑定**，不能读 implicitWidth ——
                        // 普通 Item 不 hug 子项，implicitWidth 恒 0，那样会把文字推到卡片外边
                        x: headerWrapper.width - width
                        // 宽高都得自己按那一格的节点报
                        width: control._isText(control.headerExtraContent)
                            ? extraText.implicitWidth : extraLoader.implicitWidth
                        height: control._isText(control.headerExtraContent)
                            ? extraText.implicitHeight : extraLoader.implicitHeight

                        Loader {
                            id: extraLoader

                            objectName: "cardHeaderExtraNode"

                            visible: control.extraTaken && !control._isText(control.headerExtraContent)
                            active: visible
                            sourceComponent: control._nodeOf(control.headerExtraContent)
                        }

                        Text {
                            id: extraText

                            objectName: "cardHeaderExtraText"

                            // -header-wrapper-extra：$font-size-header-6 + 700 + text-0（行高继承 20）
                            visible: control.extraTaken && control._isText(control.headerExtraContent)
                            text: control._isText(control.headerExtraContent)
                                ? String(control.headerExtraContent) : ""
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeHeader6
                            font.weight: Font.Bold
                            lineHeight: control.lineHeight
                            lineHeightMode: Text.FixedHeight
                        }
                    }

                    Item {
                        id: titleSlot

                        objectName: "cardTitleSlot"

                        visible: control.titleTaken
                        y: 0
                        x: 0
                        width: Math.max(0, control.extraTaken
                            ? extraSlot.x - control.innerGap : headerWrapper.width)
                        height: control._isText(control.title)
                            ? titleText.implicitHeight : titleLoader.implicitHeight

                        Loader {
                            id: titleLoader

                            objectName: "cardTitleNode"

                            visible: control.titleTaken && !control._isText(control.title)
                            active: visible
                            sourceComponent: control._nodeOf(control.title)
                        }

                        Text {
                            id: titleText

                            objectName: "cardTitleText"

                            // Typography.Title heading={6} ⇒ 16 / 22 / 600，单行截尾
                            visible: control.titleTaken && control._isText(control.title)
                            width: titleSlot.width
                            text: control._isText(control.title) ? String(control.title) : ""
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeHeader6
                            font.weight: Font.DemiBold
                            lineHeight: 22                                   // font-size-header-6
                            lineHeightMode: Text.FixedHeight
                            elide: Text.ElideRight
                        }

                        // ellipsis={{ showTooltip: true, rows: 1 }}：截到了才出提示
                        Tooltip {
                            id: titleTooltip

                            objectName: "cardTitleTooltip"

                            target: titleText
                            text: titleText.text
                            trigger: "hover"
                            condition: titleText.truncated
                        }
                    }
                }
            }

            // -header-bordered { border-bottom }
            Rectangle {
                objectName: "cardHeaderSeam"

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: control.seamW
                visible: control.headerLine
                color: Theme.current.colorBorder
            }
        }

        // ---- cover ----
        Item {
            id: coverBlock

            objectName: "cardCover"

            y: control.headerHeight
            width: contentClip.width
            height: control.coverHeight
            visible: control.coverTaken

            Item {
                id: coverSlot

                objectName: "cardCoverSlot"

                width: coverBlock.width
                height: control.coverHeight

                Loader {
                    id: coverLoader

                    objectName: "cardCoverNode"

                    // `> * { width: 100% }`：Loader 有显式宽时会把宽转嫁给载入项
                    width: coverSlot.width
                    visible: control.coverTaken && !control._isText(control.cover)
                    active: control.coverTaken && !control._isText(control.cover)
                    sourceComponent: control._nodeOf(control.cover)
                }

                Text {
                    id: coverText

                    objectName: "cardCoverText"

                    visible: control.coverTaken && control._isText(control.cover)
                    text: control._isText(control.cover) ? String(control.cover) : ""
                    // -cover 段没有颜色规则（见 cardHeaderText 那条）
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: control.lineHeight
                    lineHeightMode: Text.FixedHeight
                }
            }
        }

        // ---- body（官方无条件渲染）----
        Item {
            id: bodyBlock

            objectName: "cardBody"

            y: control.headerHeight + control.coverHeight
            width: contentClip.width
            height: control.bodyHeight

            Item {
                id: bodyPaddingBox

                objectName: "cardBodyPaddingBox"

                x: control.sectionPadding
                y: control.sectionPadding
                width: bodyBlock.width - control.sectionPadding * 2
                height: control.bodyNodeHeight

                Skeleton {
                    id: bodySkeleton

                    objectName: "cardBodySkeleton"

                    width: parent.width
                    active: true
                    loading: control.skeletonOn && control.loading
                    placeholder: control.loadingPlaceholder

                    Column {
                        id: bodyZone

                        objectName: "cardBodyZone"

                        width: parent.width
                        spacing: 0

                        onChildrenChanged: control.declaredCount = bodyZone.children.length
                    }
                }
            }

            // -body-actions { margin-top: 20; padding-top: 20; border-top: 1px }
            Item {
                id: actionsBlock

                objectName: "cardActions"

                y: control.sectionPadding + control.bodyNodeHeight + control.innerGap
                width: bodyPaddingBox.width
                height: control.actionsHeight - control.innerGap
                visible: control.actionsTaken

                Rectangle {
                    id: actionsSeam

                    objectName: "cardActionsSeam"

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: control.seamW
                    color: Theme.current.colorBorder
                }

                Row {
                    id: actionsRow

                    objectName: "cardActionsRow"

                    // padding-top: 20 在这条线上边
                    y: control.seamW + control.sectionPadding
                    spacing: control.actionsItemGap
                    visible: control.actionCount > 0
                }
            }
        }

        // ---- footer ----
        Item {
            id: footerBlock

            objectName: "cardFooter"

            y: control.headerHeight + control.coverHeight + control.bodyHeight
            width: contentClip.width
            height: control.footerHeight
            visible: control.footerTaken

            Item {
                id: footerPaddingBox

                objectName: "cardFooterPaddingBox"

                x: control.sectionPadding
                // footerLine 那条是 border-top ⇒ 压在 padding 之上，内容再往下让 1
                y: control.sectionPadding + (control.footerLine ? control.seamW : 0)
                width: footerBlock.width - control.sectionPadding * 2
                height: control.footerNodeHeight

                Loader {
                    id: footerLoader

                    objectName: "cardFooterNode"

                    visible: control.footerTaken && !control._isText(control.footer)
                    active: visible
                    sourceComponent: control._nodeOf(control.footer)
                }

                Text {
                    id: footerText

                    objectName: "cardFooterText"

                    visible: control.footerTaken && control._isText(control.footer)
                    text: control._isText(control.footer) ? String(control.footer) : ""
                    // -footer 段没有颜色规则（见 cardHeaderText 那条）
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    lineHeight: control.lineHeight
                    lineHeightMode: Text.FixedHeight
                }
            }

            // -footer-bordered { border-top }：那条线在 footer 的**上沿**（body 与 footer 之间）
            Rectangle {
                objectName: "cardFooterSeam"

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: control.seamW
                visible: control.footerLine
                color: Theme.current.colorBorder
            }
        }
    }

    // ------------------------------------------------------------------ 动作区节点
    // 官方 `actions.map` 生成一串 div，端口用 `<div>` 顶替成 Text / Loader。
    // 这里没用 Repeater：Qt 6.11 起 Repeater 自己是个 Item、委托是它的兄弟，
    // 落进 Row 里会多出一次 12 的间距（List 那边踩过），所以改成手动建。
    property var actionNodes: []

    onActionsChanged: control.syncActions()
    Component.onCompleted: {
        control.declaredCount = bodyZone.children.length;
        control.syncActions();
    }

    function syncActions() {
        for (let i = 0; i < control.actionNodes.length; ++i) {
            const old = control.actionNodes[i];
            if (old !== undefined && old !== null)
                old.destroy();
        }
        control.actionNodes = [];
        // 这里**不能**读 control.actionsTaken / actionCount：那是绑出来的只读属性，
        // 在 onActionsChanged 里读到的还是上一拍的值（探针量过：换数组后少建一个）。
        const list = control.actions;
        if (!Array.isArray(list))
            return;
        for (let i = 0; i < list.length; ++i) {
            const value = list[i];
            const isText = typeof value === "string" || typeof value === "number";
            const node = isText
                ? actionTextProto.createObject(actionsRow)
                : actionLoaderProto.createObject(actionsRow);
            if (node === null)
                continue;
            if (isText)
                node.text = String(value);
            else
                node.sourceComponent = value;
            control.actionNodes.push(node);
        }
    }

    Component {
        id: actionTextProto

        Text {
            color: Theme.current.colorText1
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: control.lineHeight
            lineHeightMode: Text.FixedHeight
        }
    }

    Component {
        id: actionLoaderProto

        Loader {}
    }

    // ------------------------------------------------------------------ loading 占位
    // 官方 :190-196 那坨 placeholder 是 `<div><Skeleton.Title/><br/><Skeleton.Paragraph rows={3}/></div>`，
    // `<br/>` 是卡片 20 行高的一个空行盒（卡片没别的行高来源）。
    readonly property real placeholderBreakHeight: control.lineHeight

    readonly property Component loadingPlaceholder: Component {
        Column {
            id: placeholderRoot

            objectName: "cardLoadingPlaceholder"

            width: parent ? parent.width : 0
            spacing: 0

            SkeletonTitle {}

            Item {
                objectName: "cardLoadingBreak"

                width: 1
                height: control.placeholderBreakHeight
            }

            SkeletonParagraph {
                rows: 3
            }
        }
    }

    // ------------------------------------------------------------------ 小工具
    function _taken(value) {
        return !!value;
    }

    function _isText(value) {
        return typeof value === "string" || typeof value === "number";
    }

    function _nodeOf(value) {
        return control._taken(value) && !control._isText(value) ? value : null;
    }
}
