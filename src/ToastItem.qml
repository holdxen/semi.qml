pragma ComponentBehavior: Bound

import QtQuick

// Toast 的单张卡片，对应官方 .semi-toast 那一层。
//
// 官方一张提示是两层 DOM：
//   .semi-toast          带动画的盒子，含 12px margin，pointer-events: none
//   .semi-toast-content  有底色/圆角/阴影的本体，pointer-events: all
// 这里照抄这个层次：根 Item 是盒子（宿主按它的 implicitWidth/implicitHeight 排布），
// box 是本体，卡片在本体里居中（官方靠 innerWrapper 的 text-align: center）。
//
// 卡片不自己掐时间：duration 归宿主统一调度（理由见 Toast.qml）。卡片只把
// 「用户按了关闭」「指针进出了本体」「退场动画播完了」三件事报上去。
Item {
    id: card

    // ---------------------------------------------------------------- Options
    property string toastId: ""           // id
    property string type: "default"       // success / warning / info / error / default
    property string theme: "normal"       // normal | light
    property string contentText: ""       // content：字符串那一支
    property var contentComponent: null   // content：富文本那一支（官方是 ReactNode）
    property string icon: ""              // icon：自定义图标名，空则用 type 自带的
    property bool showClose: true
    property real textMaxWidth: 450
    property bool stack: false            // 堆叠（开关在宿主，见 Toast.qml）
    property bool stackExpanded: false    // 悬停展开
    property bool motion: true
    property bool removed: false          // 宿主置 true → 播退场动画
    property int reservedIndex: 0         // 官方 positionInList 推出来的景深

    // ---------------------------------------------------------------- 信号
    signal requestClose(string id)        // × 被按下（官方 foundation.close）
    signal pointerHovered(bool hovering)  // onMouseEnter / onMouseLeave
    signal layoutDirty()                  // 自身尺寸变了，宿主需要重排
    signal hideFinished()                 // 退场动画播完，宿主可以销毁了

    // ---------------------------------------------------------------- 令牌
    readonly property int marginSize: Theme.current.spacingBaseTight   // $spacing-toast_content-margin
    readonly property int padX: Theme.current.spacingTight             // $spacing-toast_content-paddingX
    readonly property int padY: Theme.current.spacingBaseTight         // $spacing-toast_content-paddingY
    readonly property int textGap: Theme.current.spacingBaseTight      // $spacing-toast_content_text-marginLeft/Right
    readonly property int glyphSize: Theme.current.widthIconLarge      // iconSize = large
    readonly property int closeHeight: 20                              // .semi-toast-close-button: height $width-icon-large
    readonly property int closeTop: -2                                 // $spacing-toast_content_close_btn-marginTop
    readonly property int textLineHeight: 20                            // @mixin font-size-regular：14px / 20px
    readonly property int perspective: 280                              // $spacing-toast-perspective
    // $animation_duration-toast-show/hide/stack = 300ms。曲线 cubic-bezier(.22,.57,.02,1.2) 会过冲，
    // 但 Qt 6.11 的 Easing.BezierSpline 实测退化成线性（坑 50），改用形状最接近的 OutBack。
    readonly property int motionDuration: 300

    // type → 色调 / 图标，照抄 toast.tsx 的 iconMap（default 没有图标）
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

    // 官方 light 只换底色/描边/图标色，文字仍是 text-0（$color-toast-text-default）；
    // 而且没有 .semi-toast-light.semi-toast-default 这条规则 —— default 用不上浅色。
    readonly property color accent: toned ? Appearance.textColor(Theme.current, tone) : Theme.current.colorText0
    readonly property bool lightSurface: card.theme === "light" && toned
    readonly property color fill: lightSurface
        ? Appearance.badgeBackground(Theme.current, tone, true)
        : Theme.current.colorBg3

    // 盒子 = 本体 + 四周 12px margin
    implicitWidth: box.implicitWidth + card.marginSize * 2
    implicitHeight: box.implicitHeight + card.marginSize * 2

    // 堆叠且未展开 → 零高度外壳（.semi-toast-zero-height-wrapper），卡片互相叠住。
    // 写成函数而不是绑定属性：宿主的排布函数要在「刚把 stackExpanded 赋完」那一轮就读到它，
    // 绑定属性那时还没重算（坑 81 那一族）。
    function flowHeight() {
        return card.stack && !card.stackExpanded ? 0 : card.implicitHeight
    }

    // translate3d(0, 0, reservedIndex * -10px) 在 perspective: 280px 下的投影：
    // scale = P / (P - z)，各点绕 perspective-origin（center 280px）缩放。
    // 展开后官方把 perspective 置 unset，于是回到 1。
    readonly property real stackScale: card.stack && !card.stackExpanded
        ? card.perspective / (card.perspective + 10 * card.reservedIndex)
        : 1

    // reveal 同时驱动 opacity 与 translateY(-100%)：CSS 整个 animation 共用一条曲线，
    // 这里也必须共用。OutBack 会冲过 1 —— 于是卡片略微冲过头再回落，opacity 端自动被夹住。
    property real reveal: 1

    opacity: card.reveal
    transform: [
        Translate {
            id: slide

            y: (card.reveal - 1) * card.height
        },
        Scale {
            id: depth

            // origin 用的是卡片自己的坐标：外壳的 (宽/2, 280px) 换算过来就是这个值
            origin.x: card.width / 2
            origin.y: card.perspective - card.y
            xScale: card.stackScale
            yScale: card.stackScale
        }
    ]

    Accessible.role: Accessible.Alert     // 官方 role="alert"、aria-label="${type} type"
    Accessible.name: card.type + " type"

    // .semi-toast-content：inline-flex + align-items: flex-start，于是三块内容都贴顶
    Rectangle {
        id: box

        objectName: "toastBox"
        x: Math.round((card.width - implicitWidth) / 2)
        y: card.marginSize
        width: implicitWidth
        height: implicitHeight
        radius: Theme.current.radiusMedium              // $radius-toast_content
        color: card.fill
        border.width: card.lightSurface ? 1 : 0         // $width-toast_light-border
        border.color: card.accent

        implicitWidth: line.implicitWidth + card.padX * 2
        implicitHeight: line.implicitHeight + card.padY * 2

        // $shadow-toast = --semi-shadow-elevated
        SemiPopupShadow {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            fill: card.fill
        }

        Item {
            id: line

            objectName: "toastLine"
            x: card.padX
            y: card.padY
            width: implicitWidth
            height: implicitHeight

            implicitWidth: textBlock.x + textBlock.width + card.textGap
                + (closeWrap.visible ? closeWrap.width : 0)
            // align-items: flex-start → 行高取各孩子外边距盒的最大值
            implicitHeight: Math.max(card.glyphShown ? card.glyphSize : 0,
                textBlock.height,
                closeWrap.visible ? card.closeHeight + card.closeTop : 0)

            Icon {
                id: glyph

                objectName: "toastIcon"
                x: 0
                y: 0
                name: card.iconName
                size: card.glyphSize
                color: card.accent
            }

            // .semi-toast-content-text：左右各 12px 外边距、max-width textMaxWidth、text-align left
            Item {
                id: textBlock

                objectName: "toastTextBlock"
                x: (card.glyphShown ? card.glyphSize : 0) + card.textGap
                y: 0
                width: Math.max(1, Math.min(card.textMaxWidth, implicitWidth))
                height: implicitHeight

                // Loader 的 item 在 QML 侧只是 QObject，取尺寸要放宽类型检查
                // qmllint disable missing-property
                implicitWidth: rich.item ? rich.item.implicitWidth : bodyText.implicitWidth
                implicitHeight: rich.item ? rich.item.implicitHeight : bodyText.implicitHeight
                // qmllint enable missing-property

                Text {
                    id: bodyText

                    objectName: "toastText"
                    visible: card.contentText !== ""
                    width: textBlock.width
                    text: card.contentText
                    color: Theme.current.colorText0     // $color-toast-text-default
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Theme.current.fontWeightBold   // $font-toast_content-fontWeight
                    lineHeight: card.textLineHeight
                    lineHeightMode: Text.FixedHeight
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                }

                // 富文本 content（官方是 ReactNode）。Component 在调用方那一侧定义，
                // Loader 按它自己的上下文实例化 —— 这就是官方 useToast 说的「读得到 context」。
                Loader {
                    id: rich

                    objectName: "toastRich"
                    active: card.contentComponent !== null && card.contentComponent !== undefined
                    sourceComponent: card.contentComponent
                    onItemChanged: card.layoutDirty()
                }
            }

            // .semi-toast-close-button：height 20、margin-top -2，里面装小号 borderless tertiary 图标按钮
            Item {
                id: closeWrap

                x: textBlock.x + textBlock.width + card.textGap
                y: card.closeTop
                visible: card.showClose
                width: closer.implicitWidth
                height: card.closeHeight

                IconButton {
                    id: closer

                    objectName: "toastClose"
                    x: 0
                    y: 0
                    icon: "close"
                    size: Enums.Small
                    variant: Enums.Borderless
                    tone: Enums.Tertiary
                    onClicked: card.requestClose(card.toastId)
                }
            }
        }

        // 指针事件只算本体的：.semi-toast 是 pointer-events: none，.semi-toast-content 才是 all，
        // 所以那 12px margin 的空隙不算悬停（既不暂停计时，也不展开堆叠）。
        // handler 挂在 box 之下，作用范围就是本体。
        HoverHandler {
            id: pointer

            onHoveredChanged: card.pointerHovered(pointer.hovered)
        }
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

    // motion=false 时官方按「时长 0 的动画」处理：挂载即结束、离场即销毁
    Component.onCompleted: {
        card.reveal = card.motion ? 0 : 1
        if (card.motion)
            enterAnim.start()
        card.layoutDirty()
    }

    onRemovedChanged: {
        if (card.removed) {
            if (card.motion) {
                exitAnim.from = card.reveal
                exitAnim.start()
            } else {
                Qt.callLater(function () { card.hideFinished() })
            }
        }
    }

    onImplicitWidthChanged: card.layoutDirty()
    onImplicitHeightChanged: card.layoutDirty()

    Behavior on y {
        enabled: card.stack
        NumberAnimation {
            duration: card.motionDuration
            easing.type: Easing.OutBack
        }
    }
}
