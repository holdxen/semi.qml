import QtQuick
import "CssGradient.js" as CssGradient

// 按钮。官方一个 <Button> 背后其实是两个组件：没有图标、也没有加载态时走
// button/Button.tsx（只渲染 children），一旦有 icon 或 loading 就转给
// iconButton/index.tsx（负责图标位置、加载图标、去掉内边距）。这里合成一个组件，
// 属性面取两边的并集。
//
//     Button { text: "确定"; variant: Enums.Solid; onClicked: submit() }
//     Button { icon: "camera"; ariaLabel: "截屏" }
//     Button { text: "展开选项"; icon: "chevron_down"; iconPosition: "right" }
//
// 尺寸令牌来自 semi-foundation/button/{variables,iconButton}.scss，色值解析在
// Appearance::button* 那一组函数里。与官方的偏差逐条写在注释和 PROGRESS.md。
Rectangle {
    id: control

    // ---- 官方属性面（Button.tsx:18-41 / iconButton/index.tsx:16-29）----
    // 官方的文字走 children，QML 没有 children，用 text 承接
    property string text: ""
    property string icon: ""
    // "left" | "right"（constants.ts 的 DEFAULT_ICON_POSITION）
    property string iconPosition: "left"
    property bool loading: false
    property bool block: false
    // 官方 Button.tsx:112 会 emit `-circle` 这个类名，但全仓没有任何规则消费它
    // （button.scss / iconButton.scss / 编译产物 semi.css 均 0 命中）—— 死 prop，
    // 收下不产出差异（口径同 Tree 的 multiple：官方 emit 了类名但没人画）
    property bool circle: false
    // 官方默认 type=primary、theme=light、size=default、colorful=false。
    // 这里默认留 undefined，好让 ButtonGroup 的下发值补进来（单项自己写了以单项为准，
    // 见 buttonGroup.tsx:80 的 cloneElement）
    property var tone: undefined
    property var variant: undefined
    property var size: undefined
    property var colorful: undefined
    // true | "left" | "right" | ["left", "right"]（iconButton/index.tsx:80-89）
    property var noHorizontalPadding: false
    // 官方 aria-label，图标按钮的推荐读屏名
    property string ariaLabel: ""

    // ---- 由 ButtonGroup / SplitButtonGroup 写入 ----
    // "" | "only" | "first" | "middle" | "last"，决定哪一侧保留圆角
    property string groupPosition: ""
    property var groupTone: undefined
    property var groupVariant: undefined
    property var groupSize: undefined
    property var groupColorful: undefined
    property bool groupDisabled: false

    signal clicked
    /// 官方 onMouseDown（Button.tsx:131 直挂在 <button> 上）
    signal mouseDown
    /// 官方 onMouseEnter / onMouseLeave —— 改名理由同 Avatar/Badge：entered/left
    /// 撞 QQuickItem 的 FINAL 成员
    signal mouseEntered
    signal mouseLeft

    readonly property int resolvedTone: control.tone !== undefined ? control.tone
        : (control.groupTone !== undefined ? control.groupTone : Enums.Primary)
    // cloneElement 把组的 rest（theme / colorful）排在子级 props 之后，
    // 所以这两个是「组盖单项」，跟 size / tone / disabled 的方向相反
    readonly property int resolvedVariant: control.groupVariant !== undefined ? control.groupVariant
        : (control.variant !== undefined ? control.variant : Enums.Light)
    readonly property int resolvedSize: control.size !== undefined ? control.size
        : (control.groupSize !== undefined ? control.groupSize : Enums.Default)
    readonly property bool resolvedColorful: control.groupColorful !== undefined ? control.groupColorful
        : (control.colorful !== undefined ? control.colorful : false)

    readonly property int controlState: Appearance.state(control.enabled, hover.hovered, tap.pressed)

    // index.tsx:34 的 isLoading && !isDisabled —— 禁用优先于加载，禁用时不画转圈
    readonly property bool spinnerShown: control.loading && control.enabled
    readonly property bool glyphShown: control.icon !== "" || control.spinnerShown
    // .semi-button-with-icon-only：有图标（或转圈）又没文字，这时宽高定死成正方形
    readonly property bool iconOnly: control.text === "" && control.glyphShown

    // 多彩态的三种分支（button.scss:139-231 编进 semi.css 的那几条）：
    // solid 是渐变底；light / borderless 的 primary、solid 的 tertiary 是渐变字；
    // outline 的 primary 是 ai-purple 字 + ai-purple 描边。
    // 禁用时 DOM 上根本不挂 -primary / -tertiary 这个类（Button.tsx:106 的 !disabled && type），
    // 整套多彩规则一起失效，所以三个分支都要求 enabled。
    readonly property bool colorfulSurface: control.resolvedColorful && control.enabled
        && control.resolvedVariant === Enums.Solid
        && (control.resolvedTone === Enums.Primary || control.resolvedTone === Enums.Tertiary)
    readonly property bool colorfulText: control.resolvedColorful && control.enabled
        && ((control.resolvedTone === Enums.Primary
                && (control.resolvedVariant === Enums.Light || control.resolvedVariant === Enums.Borderless))
            || (control.resolvedTone === Enums.Tertiary && control.resolvedVariant === Enums.Solid))
    readonly property bool colorfulPurple: control.resolvedColorful && control.enabled
        && control.resolvedTone === Enums.Primary && control.resolvedVariant === Enums.Outline

    // 渐变档位：primary 用 5 / 6 / 7，tertiary 用 0 / 1 / 2（normal / hover / active）
    readonly property int colorfulLevel: {
        const step = control.controlState === Enums.Hovered ? 1
            : (control.controlState === Enums.Pressed ? 2 : 0);
        return control.resolvedTone === Enums.Tertiary ? step : step + 5;
    }
    readonly property string colorfulGradientCss: [
        Theme.current.aiGeneral0, Theme.current.aiGeneral1, Theme.current.aiGeneral2,
        Theme.current.aiGeneral3, Theme.current.aiGeneral4, Theme.current.aiGeneral5,
        Theme.current.aiGeneral6, Theme.current.aiGeneral7, Theme.current.aiGeneral8,
        Theme.current.aiGeneral9
    ][control.colorfulLevel]
    readonly property var colorfulStops: control.colorfulSurface
        ? CssGradient.horizontalStops(control.colorfulGradientCss) : []

    readonly property color flatForeground: Appearance.buttonForeground(Theme.current,
        control.resolvedTone, control.resolvedVariant, control.controlState)
    // 渐变铺字（background-clip: text）Qt Quick 没有等价能力，退成首尾色标的中值
    readonly property color foregroundColor: control.colorfulText
        ? CssGradient.representative(Theme.current.aiGeneral5)
        : (control.colorfulPurple ? Theme.current.colorAiPurple : control.flatForeground)
    // 图标官方是被 cloneElement 塞了一个 fill 数组的（iconButton/index.tsx:102-131），
    // 而这些 AI 图标实际只有一条 path，真正吃到的就是 fill[0] = 渐变的最后一个色标
    readonly property bool colorfulIconMultiple: control.colorfulText
    readonly property bool colorfulIconTwo: control.resolvedColorful && control.enabled
        && control.resolvedTone === Enums.Tertiary && control.resolvedVariant !== Enums.Solid
    readonly property color glyphColor: control.colorfulIconMultiple
        ? CssGradient.endColor(Theme.current.aiGeneral5)
        : (control.colorfulIconTwo ? Theme.current.colorAiPurple : control.foregroundColor)

    readonly property bool roundLeft: control.groupPosition === "" || control.groupPosition === "only"
        || control.groupPosition === "first"
    readonly property bool roundRight: control.groupPosition === "" || control.groupPosition === "only"
        || control.groupPosition === "last"

    readonly property real paddingHorizontal: Appearance.buttonPaddingHorizontal(Theme.current,
        control.resolvedSize)

    function padsSide(side) {
        const raw = control.noHorizontalPadding;
        if (raw === true)
            return true;
        if (Array.isArray(raw))
            return raw.indexOf(side) >= 0;
        return raw === side;
    }

    function stopColor(index) {
        return index < control.colorfulStops.length ? control.colorfulStops[index].color : "transparent";
    }

    function stopPosition(index) {
        return index < control.colorfulStops.length ? control.colorfulStops[index].position : 1;
    }

    // 官方 .semi-button 高度定死、宽度由内容 + padding 撑开；
    // .semi-button-with-icon-only 另有 $width-button_iconOnly_* = 控件高，是个正方形。
    implicitWidth: control.iconOnly
        ? Appearance.buttonHeight(Theme.current, control.resolvedSize)
        : content.implicitWidth + (control.padsSide("left") ? 0 : control.paddingHorizontal)
            + (control.padsSide("right") ? 0 : control.paddingHorizontal)
    implicitHeight: Appearance.buttonHeight(Theme.current, control.resolvedSize)
    // .semi-button-block { width: 100% }
    width: control.block && control.parent !== null ? control.parent.width : implicitWidth
    // 独立圆角（Qt 6.7+），这时 radius 不再起作用
    topLeftRadius: control.roundLeft ? Theme.current.radiusSmall : 0
    bottomLeftRadius: control.roundLeft ? Theme.current.radiusSmall : 0
    topRightRadius: control.roundRight ? Theme.current.radiusSmall : 0
    bottomRightRadius: control.roundRight ? Theme.current.radiusSmall : 0
    color: Appearance.buttonBackground(Theme.current, control.resolvedTone, control.resolvedVariant, control.controlState)
    border.width: Appearance.buttonBorderWidth(control.resolvedVariant)
    border.color: control.colorfulPurple ? Theme.current.colorAiPurple
        : Appearance.buttonBorderColor(Theme.current, control.resolvedTone, control.resolvedVariant, control.controlState)
    // 组的 disabled 一律压下来；单项自己写了 enabled 就听单项（赋值会顶掉这条绑定）
    enabled: control.groupDisabled !== true
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: control.ariaLabel !== "" ? control.ariaLabel : control.text

    Behavior on color {
        ColorAnimation { duration: Theme.current.durationFast }
    }

    // 多彩 solid 的渐变底另铺一层：Rectangle 的 gradient 非空时 color 就不生效了，
    // 所以不能直接挂在根上，只有多彩态才需要它。
    Rectangle {
        objectName: "colorfulSurface"
        anchors.fill: parent
        topLeftRadius: control.topLeftRadius
        bottomLeftRadius: control.bottomLeftRadius
        topRightRadius: control.topRightRadius
        bottomRightRadius: control.bottomRightRadius
        visible: control.colorfulSurface

        gradient: Gradient {
            // 官方一律 278deg，Qt 的 Gradient 只有水平 / 垂直两个朝向，取水平、
            // 并把 CSS 的 0% 放到右端（见 CssGradient.js）
            orientation: Gradient.Horizontal

            GradientStop { position: control.stopPosition(0); color: control.stopColor(0) }
            GradientStop { position: control.stopPosition(1); color: control.stopColor(1) }
            GradientStop { position: control.stopPosition(2); color: control.stopColor(2) }
            GradientStop { position: control.stopPosition(3); color: control.stopColor(3) }
        }
    }

    // focus-visible：官方是 outline: 2px solid，贴着边框外沿、不额外留缝
    Rectangle {
        objectName: "focusRing"
        anchors.fill: parent
        anchors.margins: -2
        radius: Theme.current.radiusSmall + 2
        color: "transparent"
        border.width: 2
        border.color: Appearance.buttonFocusRing(Theme.current, control.resolvedTone, control.resolvedVariant)
        visible: FocusVisible.shouldShow(control.activeFocus)
    }

    // 图标 + 文字。官方把顺序交给 iconPosition 决定，这里手排：
    // Row 换 layoutDirection 会连带把 Text 也翻成右到左
    Item {
        id: content

        objectName: "buttonContent"
        anchors.centerIn: parent
        readonly property real gap: label.visible && glyphHost.visible
            ? Theme.current.spacingTight : 0
        implicitWidth: (label.visible ? label.implicitWidth : 0)
            + (glyphHost.visible ? glyphHost.implicitWidth : 0) + gap
        implicitHeight: label.visible ? label.implicitHeight : (glyphHost.visible ? glyphHost.implicitHeight : 0)

        Text {
            id: label

            objectName: "buttonLabel"
            // iconPosition 为 right 时文字在左、图标在右
            x: control.iconPosition === "right" ? 0
                : (glyphHost.visible ? glyphHost.implicitWidth + content.gap : 0)
            anchors.verticalCenter: parent.verticalCenter
            visible: control.text !== ""
            text: control.text
            color: control.foregroundColor
            font.pixelSize: Appearance.buttonFontSize(Theme.current, control.resolvedSize)
            font.weight: Font.DemiBold
        }

        Item {
            id: glyphHost

            objectName: "buttonGlyphHost"
            x: control.iconPosition === "right"
                ? (label.visible ? label.implicitWidth + content.gap : 0) : 0
            anchors.verticalCenter: parent.verticalCenter
            visible: control.glyphShown
            implicitWidth: Theme.current.widthIconMedium
            implicitHeight: Theme.current.widthIconMedium

            Icon {
                objectName: "buttonGlyph"
                anchors.centerIn: parent
                // 加载态把图标顶掉；多彩态官方换的是 IconAILoading
                name: control.spinnerShown ? (control.resolvedColorful ? "ai_loading" : "spin") : control.icon
                // spin 是单色弧线，跟着字色走；ai_loading 自带渐变，着色会糊
                tinted: !control.spinnerShown || !control.resolvedColorful
                size: Theme.current.widthIconMedium
                color: control.glyphColor
            }

            // Rotation 必须写进 transform 列表：当普通子对象声明时它只会落到 resources 里
            // 成为一个不生效的资源 QObject —— QQuickTransform::appendToItem 只由
            // transform_append 调（qquickitem.cpp:3673），实测那样写 transform.length === 0、
            // angle 画面上毫无变化（探针 /tmp/semi_ref/button/spin_probe.qml）。
            // 转轴要自己给 origin：itemToParentTransform 把 transforms 原样 applyTo，
            // 只有 Item.rotation / scale 那两支才走 transformOrigin 补偿
            // （qquickitem.cpp:3257-3271），所以 Item.transformOrigin 对这里是无效的。
            transform: Rotation {
                id: glyphTurn

                origin.x: glyphHost.width / 2
                origin.y: glyphHost.height / 2
                axis.x: 0
                axis.y: 0
                axis.z: 1
            }

            // $animation_duration-button_icon_loading: 600ms，linear 无限转。
            // 不用 `SequentialAnimation on glyphTurn.angle`：qmllint 解析不了这种
            // 「分组属性上的内联动画」（会把 id 当成类型名报 unresolved-type）
            NumberAnimation {
                target: glyphTurn
                property: "angle"
                from: 0
                to: 360
                duration: 600
                loops: Animation.Infinite
                easing.type: Easing.Linear
                running: control.spinnerShown
            }
        }
    }

    HoverHandler {
        id: hover
        objectName: "buttonHoverHandler"
        // .semi-button-loading { pointer-events: none } —— 加载态连悬浮都不算
        enabled: control.enabled && !control.loading
        // button.scss:14 的 `cursor: pointer`。-disabled 那条 `cursor: not-allowed`
        // 在 Qt 里够不到：Item.enabled 为假时指针事件根本不投给它的 handler，
        // cursorShape 一起失效（实测，与 NavigationItem 那条 disabled 光标同族）
        cursorShape: Qt.PointingHandCursor

        onHoveredChanged: {
            if (hover.hovered)
                control.mouseEntered();
            else
                control.mouseLeft();
        }
    }

    TapHandler {
        id: tap
        gesturePolicy: TapHandler.ReleaseWithinBounds
        enabled: control.enabled && !control.loading
        // 官方 onMouseDown 直挂在 <button> 上（Button.tsx:131）；按下即发、
        // 不等抬起。disabled / loading 档上游是原生 disabled / pointer-events: none，
        // 两样都收不到 mousedown，端口由 TapHandler.enabled 承接同一道闸
        onPressedChanged: {
            if (tap.pressed)
                control.mouseDown();
        }
        onTapped: control.clicked()
    }

    // 原生 button 的键盘行为：Enter 与空格都能激活。
    // Keys 只提供 *Pressed 这一组信号（qquickitem.cpp:765 的键表里没有 released 变体），
    // 所以空格官方是抬起触发、这里按下触发。
    Keys.onReturnPressed: function (event) {
        if (control.loading)
            return;
        control.clicked();
        event.accepted = true;
    }
    Keys.onSpacePressed: function (event) {
        if (control.loading)
            return;
        control.clicked();
        event.accepted = true;
    }
}
