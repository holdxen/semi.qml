import QtQuick

// 通知横幅。用于页面顶部那条常驻的状态说明，带一个自绘的关闭键。
//
//     Banner {
//         description: "Semi D2C 现已支持 Figma DevMode"
//         tone: Enums.Warning
//         onClosed: page.showBanner = false
//     }
//
// 规格照 semi-ui/banner（`index.tsx:22-35` 的 BannerProps + `:53-58` 的 defaultProps +
// `:104-158` 的 render）与 semi-foundation/banner（`foundation.ts:19-22`、`banner.scss` +
// `variables.scss`，编译后的规则在 semi.css:3196-3240）。逐条（间距令牌照
// semi-theme-default/scss/variables.scss:20-25：extra-tight 4 / tight 8 / base-tight 12）：
//   · 内边距 12（$spacing-banner-paddingX/paddingY = $spacing-base-tight）；
//   · 底色 = 该色调的 light-default，横幅自身的 `color` = 该色调本色（`color-banner_*-text-default`）
//     —— 但这条本色**只落到图标上**：标题与描述是 Typography 节点，`.semi-typography` 自己写了
//     `color: var(--semi-color-text-0)`（semi.css:25291），元素自身的声明永远压过继承，
//     所以**标题与描述恒为 text-0**，不是本色；
//   · 标题 = `Typography.Title heading={5}` ⇒ 18/24 字重 600（semi.css:25549）；
//     描述 = `Typography.Paragraph` ⇒ 14/20（semi.css:25291），两者 `margin: 0`；
//   · 默认图标按色调取（`index.tsx:126-133`）：info ⇒ info_circle、warning ⇒ alert_triangle、
//     danger ⇒ alert_circle、success ⇒ tick_circle，`size="large"` ⇒ 20px（Icon.tsx:23）；
//     图标右外边距 12（$spacing-banner_icon-marginRight）；
//   · 关闭键 24×24（$height/$width-banner_closeBtn，正好是 small 档 IconButton 的边长）、
//     左外边距 12（$spacing-banner_closeBtn-marginLeft）、顶对齐，
//     外观是 borderless + small + tertiary（`index.tsx:112-118`），`aria-label="Close"`；
//   · 圆角 3 **只在非全屏**（`-in-container { border-radius: $radius-banner }`），
//     描边 1px 本色**只在非全屏且 bordered**（`-bordered` 的选择器是
//     `!fullMode && bordered`，`index.tsx:141`）；
//   · 全屏那支：`.semi-banner-content { justify-content: center }` 且 icon / content-body 都是
//     `display: flex; align-items: center` ⇒ **整组水平居中、垂直居中，标题与描述并排在一行**；
//     非全屏那支 content-body 是 `flex: 1` 的块 ⇒ 标题在上、描述在下，间距 2
//     （$spacing-banner_title_description-marginTop，只在 `-in-container` 里给）；
//   · children 落在 `.semi-banner-extra`（`index.tsx:155`），顶边距 8（$spacing-banner_extra-marginTop）。
//
// 与官方的差异（React / CSS 在 QML 侧无处落地，逐条）：
//   · 官方 `type` 在这里叫 `tone`（本库把「语义色档」统一叫 tone，见 Button / Toast / Notification）；
//   · 官方 `icon` / `closeIcon` 吃 ReactNode，`null` 表示不显示。这里拆成两组：
//     `iconName`（空串 = 按 tone 取默认）+ `iconShown: false`（= 官方 `icon={null}`），
//     `closeIconName`（缺省 "close"）+ `closable: false`（= 官方 `closeIcon={null}`）。
//     不拿 `var` 的 undefined/null 当哨兵，是因为 QML 侧未赋值的 `property var x: undefined`
//     在绑定里和 `null` 比较是**相等**的，两者分不开；
//   · 官方 `title` / `description` 是 ReactNode（demo 里会塞 `<div style>` 与 `<Text link>`），
//     这里收字符串；要在描述里放链接，把那段挪进 children（`extraTaken`）自己摆；
//   · 官方 `className` / `style` 没有对应物，宽高与外边距由调用方写在 Item 上；
//   · 关闭后官方是 `state.visible=false` ⇒ 整棵子树卸载。这里是 `bannerVisible=false` ⇒
//     根项 `visible` 走掉、`implicitHeight` 归 0。**这条 `visible` 是根项上的默认绑定**，
//     调用方一旦自己绑了 `visible`（官方 基本用法 那节就是 app 拿着 state 控挂载），
//     覆盖掉它是正常的 —— 那种场合请照 demo 一样在 `onClosed` 里翻自己那个开关。
Item {
    id: control

    // ---------------------------------------------------------------- BannerProps
    property int tone: Enums.Info                       // 官方 type，缺省 info
    property bool fullMode: true
    property bool bordered: false
    property string title: ""
    property string description: ""
    property string iconName: ""                        // 空串 = 按 tone 取默认
    property bool iconShown: true
    property string closeIconName: "close"
    property bool closable: true
    property bool bannerVisible: true                   // 官方 state.visible

    signal closed()

    default property alias content: extraHost.data
    readonly property alias iconItem: bannerIcon
    readonly property alias closeItem: closeBtn
    readonly property alias titleText: titleLine
    readonly property alias descriptionText: descriptionLine

    readonly property color accent: Appearance.textColor(Theme.current, control.tone)
    readonly property color fill: Appearance.badgeBackground(Theme.current, control.tone, true)
    readonly property string resolvedIconName: control.iconName !== ""
        ? control.iconName
        : (control.tone === Enums.Warning ? "alert_triangle"
            : control.tone === Enums.Danger ? "alert_circle"
                : control.tone === Enums.Success ? "tick_circle" : "info_circle")

    readonly property bool iconTaken: control.iconShown && control.resolvedIconName !== ""
    readonly property bool titleTaken: control.title !== ""
    readonly property bool descriptionTaken: control.description !== ""
    readonly property bool extraTaken: extraHost.children.length > 0

    readonly property real padX: Theme.current.spacingBaseTight        // $spacing-banner-paddingX 12
    readonly property real padY: Theme.current.spacingBaseTight        // $spacing-banner-paddingY 12
    readonly property real iconSize: Theme.current.widthIconLarge      // size="large" ⇒ 20
    readonly property real iconGap: control.iconTaken ? Theme.current.spacingBaseTight : 0
    readonly property real closeSize: Theme.current.heightControlSmall // 24 = small 档 IconButton
    readonly property real closeGap: control.closable ? Theme.current.spacingBaseTight : 0
    readonly property real textGap: 2                                  // $spacing-banner_title_description-marginTop

    // 全屏那支整组按内容宽算（CSS 的 flex 收缩）。自然宽只能从 TextMetrics 取：
    // Text 自己 `width: implicitWidth` 在开了 wrapMode 之后是一条自我回读的环
    // （Binding loop detected for property "width"，量出来宽恒 0）。
    readonly property real titleNaturalWidth: titleMetrics.advanceWidth
    readonly property real descriptionNaturalWidth: descriptionMetrics.advanceWidth
    readonly property real bodyNaturalWidth: control.fullMode
        ? (control.titleTaken ? control.titleNaturalWidth : 0)
            + (control.descriptionTaken ? control.descriptionNaturalWidth : 0)
        : 0
    // 正文可用宽度：整幅减掉内边距、图标与它的右外边距、关闭键与它的左外边距
    readonly property real bodyAvailable: Math.max(0, width - padX * 2
        - (control.iconTaken ? iconSize + iconGap : 0)
        - (control.closable ? closeSize + closeGap : 0))

    readonly property real bodyWidth: control.fullMode
        ? Math.min(control.bodyNaturalWidth, control.bodyAvailable)
        : control.bodyAvailable
    readonly property real bodyHeight: control.fullMode
        ? Math.max(control.titleTaken ? titleLine.implicitHeight : 0,
            control.descriptionTaken ? descriptionLine.implicitHeight : 0)
        : (control.titleTaken ? titleLine.implicitHeight : 0)
            + (control.titleTaken && control.descriptionTaken ? control.textGap : 0)
            + (control.descriptionTaken ? descriptionLine.implicitHeight : 0)
    // `-content` 是 flex 行，行高取最高的那个孩子（图标 20 也算一个孩子）
    readonly property real rowHeight: Math.max(control.iconTaken ? control.iconSize : 0,
        control.bodyHeight)

    implicitWidth: 480
    implicitHeight: control.bannerVisible
        ? control.padY * 2 + control.rowHeight
            + (control.extraTaken ? Theme.current.spacingTight + extraHost.implicitHeight : 0)
        : 0
    visible: control.bannerVisible
    Accessible.role: Accessible.Alert                   // 官方 role="alert"

    TextMetrics {
        id: titleMetrics

        font.pixelSize: Theme.current.fontSizeHeader5
        font.weight: Font.DemiBold
        text: control.title
    }

    TextMetrics {
        id: descriptionMetrics

        font.pixelSize: Theme.current.fontSizeRegular
        text: control.description
    }

    Rectangle {
        id: skin

        objectName: "bannerSkin"
        anchors.fill: parent
        color: control.fill
        radius: control.fullMode ? 0 : Theme.current.radiusSmall       // $radius-banner 3
        border.width: !control.fullMode && control.bordered ? 1 : 0    // $width-banner-border
        border.color: control.accent

        Item {
            id: contentRow

            objectName: "bannerContent"
            x: control.padX
            y: control.padY
            width: parent.width - control.padX * 2
            height: control.rowHeight

            Item {
                id: group

                objectName: "bannerGroup"
                width: (control.iconTaken ? control.iconSize + control.iconGap : 0) + body.width
                height: parent.height
                x: control.fullMode ? Math.max(0, (parent.width - width) / 2) : 0

                Icon {
                    id: bannerIcon

                    objectName: "bannerIcon"
                    visible: control.iconTaken
                    y: control.fullMode ? Math.max(0, (group.height - control.iconSize) / 2) : 0
                    name: control.resolvedIconName
                    size: control.iconSize
                    color: control.accent
                }

                Item {
                    id: body

                    objectName: "bannerBody"
                    x: control.iconTaken ? control.iconSize + control.iconGap : 0
                    width: control.bodyWidth
                    height: control.bodyHeight

                    Text {
                        id: titleLine

                        objectName: "bannerTitle"
                        visible: control.titleTaken
                        width: control.fullMode
                            ? Math.min(control.titleNaturalWidth, body.width) : body.width
                        text: control.title
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeHeader5      // 18
                        font.weight: Font.DemiBold                         // 600
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        id: descriptionLine

                        objectName: "bannerDescription"
                        visible: control.descriptionTaken
                        x: control.fullMode && control.titleTaken ? titleLine.width : 0
                        y: control.fullMode
                            ? Math.max(0, (body.height - implicitHeight) / 2)
                            : (control.titleTaken ? titleLine.height + control.textGap : 0)
                        width: control.fullMode && control.titleTaken
                            ? Math.max(0, body.width - titleLine.width)
                            : body.width
                        text: control.description
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular      // 14
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        IconButton {
            id: closeBtn

            objectName: "bannerClose"
            visible: control.closable
            anchors.right: parent.right
            anchors.rightMargin: control.padX
            anchors.top: parent.top
            anchors.topMargin: control.padY
            icon: control.closeIconName
            size: Enums.Small
            variant: Enums.Borderless
            tone: Enums.Tertiary
            Accessible.name: "Close"                    // 官方 aria-label="Close"
            onClicked: {
                control.closed();
                control.bannerVisible = false;
            }
        }

        Column {
            id: extraHost

            objectName: "bannerExtra"
            visible: control.extraTaken
            x: control.padX
            y: contentRow.y + contentRow.height + Theme.current.spacingTight   // 8
            width: skin.width - control.padX * 2
            spacing: 0
        }
    }
}
