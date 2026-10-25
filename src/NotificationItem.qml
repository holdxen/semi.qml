pragma ComponentBehavior: Bound

import QtQuick

// Notification 的单张卡片，对应官方 .semi-notification-notice 那一层。
//
// 官方一张通知的 DOM（semi-ui/notification/notice.tsx:162-204）：
//   .semi-notification-notice                     flex 行：图标列 + inner
//     div > .semi-notification-notice-icon         24 宽、贴顶，字形 20（size = large）
//     .semi-notification-notice-inner              flex 行，占满剩余宽
//       .semi-notification-notice-content-wrapper  标题 + 正文（flex: 1，右外边距 8）
//       Button.-icon-close                         小号 borderless tertiary，24 高，贴顶靠右
//
// 根 Item 就是那个盒子，**不含外边距**：卡片之间 20px 是相邻 margin 折叠之后的结果
// （浏览器实测三条卡片占 320 高 = 20 + 78 + 20 + 56 + 20 + 106 + 20），折叠由宿主算，
// 卡片只报自己的尺寸。
//
// 计时不在卡片里：duration 归宿主统一调度（理由见 Notification.qml）。卡片只把
// 「按了关闭」「指针进出了盒子」「点了整张卡片」「退场动画播完」四件事报上去。
Item {
    id: card

    // ---------------------------------------------------------------- NoticeProps
    property string noticeId: ""              // id
    property string type: "default"           // info / success / warning / error / default
    property string theme: "normal"           // normal | light
    property string titleText: ""             // title：字符串那一支
    property var titleComponent: null         // title：富文本那一支（官方是 ReactNode）
    property string contentText: ""           // content：字符串那一支
    property var contentComponent: null       // content：富文本那一支
    property string icon: ""                  // icon：自定义图标名，空则用 type 自带的
    property bool showClose: true
    property string position: "topRight"      // 只决定进出场往哪个方向滑
    property bool motion: true
    property bool removed: false              // 宿主置 true → 播退场动画

    // ---------------------------------------------------------------- 信号
    signal requestClose(string id)            // × 被按下（官方 foundation.close → onCloseClick）
    signal pointerHovered(bool hovering)      // onMouseEnter / onMouseLeave
    signal cardClicked()                      // onClick（整张卡片）
    signal layoutDirty()                      // 自身尺寸变了，宿主需要重排
    signal hideFinished()                     // 退场动画播完，宿主可以销毁了

    // ---------------------------------------------------------------- 令牌
    // notification.scss + variables.scss；括号里是浏览器 getComputedStyle/getBoundingClientRect
    // 实测值（harness 见 tests/tmp_notice_dom.html，类名照 notice.tsx 的 render 抄）
    readonly property int padTop: Theme.current.spacingBase                 // 16
    readonly property int padRight: Theme.current.spacingBaseTight          // 12
    readonly property int padBottom: Theme.current.spacingBase              // 16
    readonly property int padLeft: Theme.current.spacingBaseLoose           // 20
    readonly property int marginSize: Theme.current.spacingBaseLoose        // 卡片四周 20（宿主排布用）
    readonly property int minContentWidth: 320                              // min-width 算在 content-box 上
    readonly property int iconColWidth: Theme.current.widthIconExtraLarge    // 24（实测图标列 24×46）
    readonly property int iconColGap: Theme.current.spacingBaseTight        // 12
    readonly property int glyphSize: Theme.current.widthIconLarge           // iconSize = large → 20
    readonly property int closeWidth: 24                                    // 实测 24×24，半高小图标按钮
    readonly property int closeHeight: Theme.current.widthIconExtraLarge     // &-icon-close { height: 24 }
    readonly property int contentGap: 8                                     // content-wrapper margin-right
    readonly property int titleGap: Theme.current.spacingExtraTight         // 标题底部外边距 4
    readonly property int titleLineHeight: 22                               // @mixin font-size-header-6
    readonly property int contentLineHeight: 20                             // @mixin font-size-regular
    // $animation_duration-notification-show/hide = 300ms；曲线 cubic-bezier(.62,.63,0,1.13) 会过冲，
    // 但 Qt 6.11 的 Easing.BezierSpline 实测退化成线性（坑 50），改用形状最接近的 OutBack。
    readonly property int motionDuration: 300

    // type → 色调 / 图标，照抄 notice.tsx:96-101 的 iconMap（default 没有图标）
    readonly property bool toned: card.type === "success" || card.type === "warning"
        || card.type === "info" || card.type === "error"
    readonly property int tone: card.type === "success" ? Enums.Success
        : card.type === "warning" ? Enums.Warning
        : card.type === "info" ? Enums.Info
        : card.type === "error" ? Enums.Danger
        : Enums.Neutral
    readonly property string iconName: card.icon !== "" ? card.icon
        : card.type === "success" ? "tick_circle"
        : card.type === "warning" ? "alert_triangle"
        : card.type === "info" ? "info_circle"
        : card.type === "error" ? "alert_circle"
        : ""
    readonly property bool glyphShown: card.iconName !== ""

    // light 档只换底色 + 1px 同色调描边，标题/正文颜色都不动。
    // 与 Toast 不同：官方 -light.-default 与 -light.-info 共用一条规则
    // （notification.scss:107-112），所以 default 也吃浅色，走 info 的色。
    readonly property bool lightSurface: card.theme === "light"
    readonly property int lightTone: card.type === "default" ? Enums.Info : card.tone
    readonly property color accent: toned
        ? Appearance.textColor(Theme.current, tone) : Theme.current.colorText0
    readonly property color lightBorder: card.lightTone === Enums.Success ? Theme.current.colorSuccess
        : card.lightTone === Enums.Warning ? Theme.current.colorWarning
        : card.lightTone === Enums.Danger ? Theme.current.colorDanger
        : Theme.current.colorInfo
    readonly property color lightFill: card.lightTone === Enums.Success
        ? Theme.current.colorSuccessLightDefault
        : card.lightTone === Enums.Warning
            ? Theme.current.colorWarningLightDefault
        : card.lightTone === Enums.Danger
            ? Theme.current.colorDangerLightDefault
        : Theme.current.colorInfoLightDefault
    readonly property color fill: lightSurface ? lightFill : Theme.current.colorBg3
    // $width-notification_notice-border 写死 1px。官方 notice 是 content-box，描边长在盒子外面
    // （实测同样「只有一段正文」的两张卡片：不带描边高 52，带描边高 54）。
    // Qt 的 Rectangle 把描边画在内侧，所以这里把描边算进卡片尺寸、内容整体再往里让 1px。
    readonly property int borderWidth: card.lightSurface ? 1 : 0

    readonly property bool titleShown: card.titleText !== "" || card.titleComponent !== null
    readonly property bool contentShown: card.contentText !== "" || card.contentComponent !== null

    // ---------------------------------------------------------------- 尺寸
    // 一律读 implicit*（plain 属性，宽度一变就重算），不读 height/width —— 那两个是几何量，
    // 要等下一轮 polish，宿主在同一轮里读回来就是旧值（坑 81 那一族）。
    // 富文本那一支量 Loader 代理项，字符串那一支量 Text 自己。
    // Loader 的 item 在 QML 侧只是 QObject，取尺寸要放宽类型检查（同 ToastItem）
    // qmllint disable missing-property
    readonly property real titleNatural: titleLoader.item
        ? titleLoader.item.implicitWidth : titleText.implicitWidth
    readonly property real contentNatural: contentLoader.item
        ? contentLoader.item.implicitWidth : bodyText.implicitWidth
    readonly property real titleBox: titleLoader.item
        ? titleLoader.item.implicitHeight : titleText.implicitHeight
    readonly property real contentBox: contentLoader.item
        ? contentLoader.item.implicitHeight : bodyText.implicitHeight
    // qmllint enable missing-property
    readonly property real columnNatural: Math.max(titleShown ? titleNatural : 0,
                                                   contentShown ? contentNatural : 0)

    // 官方 shrink-to-fit：一条列表里所有卡片被拉成同宽（= 最宽那条的自然宽，且不小于 320+32），
    // 宿主排完就把那个宽度写回 card.width；宽度还没人管的时候（宿主尚未排布）按自然宽算。
    readonly property real sideWidth: (card.glyphShown ? card.iconColWidth + card.iconColGap : 0)
        + (card.showClose ? card.contentGap + card.closeWidth : 0)
    // min-width: 320px 落在 content-box 上 ⇒ 边框盒最小 320 + 20 + 12（实测每张 352 宽）
    readonly property int minBoxWidth: card.minContentWidth + card.padLeft + card.padRight
        + card.borderWidth * 2
    // 内容撑开那一支同样是**边框盒**：官方 .semi-notification-notice 是 width:auto 的块级
    // flex 容器，列表按 shrink-to-fit 取最宽那条的 margin-box，padding 也在里面。
    // 少算一次 padding 就会出现「宽度刚好等于正文自然宽，正文却还是放不下、白折一行」。
    readonly property real naturalWidth: Math.max(card.minBoxWidth,
        card.padLeft + card.padRight + card.sideWidth + card.columnNatural
            + card.borderWidth * 2)
    readonly property real columnWidth: card.width > 0
        ? Math.max(0, card.width - card.borderWidth * 2
            - card.padLeft - card.padRight - card.sideWidth)
        : card.columnNatural

    // .semi-notification-notice 是一条 flex 行，行高取三个 flex item 里最高的那个：
    // 图标列（字形 20）、正文列、关闭按钮（24）。少一样就少一个候选高度 ——
    // 实测「无图标、无关闭、只有一段正文」那张是 52 = 16 + 20 + 16，不是 16 + 24 + 16。
    readonly property real rowHeight: Math.max(
        card.glyphShown ? card.glyphSize : 0,
        card.showClose ? card.closeHeight : 0,
        card.columnHeight)
    readonly property real columnHeight: (card.titleShown ? card.titleBox + card.titleGap : 0)
        + (card.contentShown ? card.contentBox : 0)

    implicitWidth: card.naturalWidth
    implicitHeight: card.padTop + card.rowHeight + card.padBottom + card.borderWidth * 2

    onImplicitWidthChanged: card.layoutDirty()
    onImplicitHeightChanged: card.layoutDirty()

    onRemovedChanged: {
        if (!card.removed)
            return
        if (card.motion) {
            exitAnim.from = card.reveal
            exitAnim.start()
        } else {
            // motion: false 官方是「时长 0 的动画」：挂载即结束，退场即销毁
            Qt.callLater(function () { card.hideFinished() })
        }
    }

    // reveal 同时驱动 opacity 与位移：官方那条 animation 两个属性共用一条曲线，这里也必须共用
    property real reveal: 1

    opacity: card.reveal
    transform: [
        Translate {
            id: slide

            // 官方每个位置一套 keyframes：top 走 -Y、bottom 走 +Y、左 -X、右 +X，幅度都是自身 100%
            x: card.position === "topRight" || card.position === "bottomRight"
                ? (1 - card.reveal) * card.width
                : card.position === "topLeft" || card.position === "bottomLeft"
                    ? (card.reveal - 1) * card.width : 0
            y: card.position === "top" ? (card.reveal - 1) * card.height
                : card.position === "bottom" ? (1 - card.reveal) * card.height : 0
        }
    ]

    Accessible.role: Accessible.Alert         // 官方 role="alert"
    Accessible.name: card.titleText           // 官方 aria-labelledby 指向标题那个节点

    // .semi-notification-notice：圆角 + 底色 + 阴影；light 档再加 1px 同色调描边
    Rectangle {
        id: surface

        objectName: "noticeSurface"
        width: card.width
        height: card.height
        radius: Theme.current.radiusMedium            // $radius-notification_notice
        color: card.fill
        border.width: card.lightSurface ? 1 : 0       // $width-notification_notice-border
        border.color: card.lightBorder

        // $shadow-notification = --semi-shadow-elevated
        SemiPopupShadow {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            fill: card.fill
        }
    }

    // 图标列：24 宽、贴顶，字形 20
    Item {
        id: iconCol

        objectName: "noticeIconCol"
        x: card.borderWidth + card.padLeft
        y: card.borderWidth + card.padTop
        width: card.iconColWidth
        height: card.glyphSize
        visible: card.glyphShown

        Icon {
            id: glyph

            objectName: "noticeIcon"
            name: card.iconName
            size: card.glyphSize
            color: card.accent                    // .semi-notification-notice-{type} 的 color
        }
    }

    // content-wrapper：标题 + 正文
    Item {
        id: column

        objectName: "noticeColumn"
        x: card.borderWidth + card.padLeft + (card.glyphShown ? card.iconColWidth + card.iconColGap : 0)
        y: card.borderWidth + card.padTop
        width: card.columnWidth
        height: card.columnHeight

        Loader {
            id: titleLoader

            objectName: "noticeTitleRich"
            width: card.columnWidth
            active: card.titleComponent !== null && card.titleComponent !== undefined
            sourceComponent: card.titleComponent
            onItemChanged: card.layoutDirty()
        }

        Text {
            id: titleText

            objectName: "noticeTitle"
            visible: !titleLoader.active && card.titleText !== ""
            text: card.titleText
            width: card.columnWidth
            color: Theme.current.colorText0                       // $color-notification_title-text
            font.pixelSize: Theme.current.fontSizeHeader6         // 16
            font.weight: Theme.current.fontWeightBold             // 600
            lineHeight: card.titleLineHeight
            lineHeightMode: Text.FixedHeight
            // 官方 title 上是 word-wrap: break-word + overflow-wrap: break-word，
            // 于是一个长到超过整行的「词」也会被硬切开；Text.WordWrap 只在空格处折，
            // 对应的Qt 值是 WrapAtWordBoundaryOrAnywhere
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        Loader {
            id: contentLoader

            objectName: "noticeContentRich"
            y: card.titleShown ? card.titleBox + card.titleGap : 0
            width: card.columnWidth
            active: card.contentComponent !== null && card.contentComponent !== undefined
            sourceComponent: card.contentComponent
            onItemChanged: card.layoutDirty()
        }

        Text {
            id: bodyText

            objectName: "noticeContent"
            y: card.titleShown ? card.titleBox + card.titleGap : 0
            visible: !contentLoader.active && card.contentText !== ""
            text: card.contentText
            width: card.columnWidth
            color: Theme.current.colorText1                       // $color-notification_content-text
            font.pixelSize: Theme.current.fontSizeRegular         // 14
            lineHeight: card.contentLineHeight
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere   // 同上：overflow-wrap: break-word
        }
    }

    // 关闭按钮：贴在 inner 那一行的右上角（Button size=small theme=borderless type=tertiary）
    Item {
        id: closeWrap

        objectName: "noticeCloseWrap"
        x: card.width - card.borderWidth - card.padRight - card.closeWidth
        y: card.borderWidth + card.padTop
        width: card.closeWidth
        height: card.closeHeight
        visible: card.showClose

        IconButton {
            id: closeBtn

            // 官方这里是不带文字的 IconButton（.semi-button-with-icon-only）：
            // 实测 24×24、内边距 4、字形 16。本端口 IconButton 的图标一律取控件高度的一半，
            // 于是字形 12 —— 这条差异记在 PROGRESS.md，改它会波及全库所有 IconButton。
            objectName: "noticeClose"
            anchors.fill: parent
            icon: "close"
            size: Enums.Small
            variant: Enums.Borderless
            tone: Enums.Tertiary                                  // 图标色 text-2
            onClicked: card.requestClose(card.noticeId)
        }
    }

    // 整张卡片吃点击（官方 onClick 挂在 .semi-notification-notice 上，pointer-events: auto）。
    // 但官方点 × 时不会连带触发它 —— notice.tsx:143 的 close() 里 foundation.close(e) 先
    // e.stopPropagation()。Qt 这边父/子 TapHandler 各自都会收到同一次按下，所以在卡片这一侧
    // 按落点把关闭按钮那块矩形挡掉。
    // tapped 的第一个参数是 QQuickHandlerPoint（qquicktaphandler_p.h:83），
    // 局部坐标在它的 position 里（写成 point.x 读到的是 undefined）。
    function isOnCloseArea(px, py) {
        if (!card.showClose)
            return false
        return px >= closeWrap.x && px < closeWrap.x + closeWrap.width
            && py >= closeWrap.y && py < closeWrap.y + closeWrap.height
    }

    TapHandler {
        id: cardTap

        onTapped: function (point, button) {
            const p = point.position
            if (card.isOnCloseArea(p.x, p.y))
                return
            card.cardClicked()
        }
    }

    HoverHandler {
        id: pointer

        onHoveredChanged: card.pointerHovered(pointer.hovered)
    }

    NumberAnimation {
        id: enterAnim

        target: card
        property: "reveal"
        from: 0
        to: 1
        duration: card.motionDuration
        easing.type: Easing.OutBack
    }

    NumberAnimation {
        id: exitAnim

        target: card
        property: "reveal"
        from: 1
        to: 0
        duration: card.motionDuration
        easing.type: Easing.OutBack
        onFinished: card.hideFinished()
    }

    Component.onCompleted: {
        card.reveal = card.motion ? 0 : 1
        if (card.motion)
            enterAnim.start()
        card.layoutDirty()
    }
}
