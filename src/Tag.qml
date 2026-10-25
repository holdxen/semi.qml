import QtQuick

// 标签。官方 TagProps 的 QML 面：size / color / type / shape 四个都是字符串，
// 取值照抄 semi-foundation/tag/constants.ts 的 TAG_SIZE / TAG_COLOR / TAG_TYPE。
// 高度 20（small 与 default 共用一段样式）/ 24（large），左右内边距 8；
// 可关闭时右内边距收成 4（$spacing-tag_closable-paddingRight）。
//
//     Tag { text: "默认" }
//     Tag { text: "已完成"; color: "green"; type: "solid" }
//     Tag { text: "抖音"; color: "white"; closable: true; onClosed: ... }
//
// 官方 children 是 ReactNode：字符串走 -content-ellipsis（截断），节点走
// -content-center。这里字符串用 `text`，节点用 `content` 传一个 Component。
// prefixIcon / suffixIcon 同款：图标名字符串，或者一个 Component。
//
// 官方 onClose(tagChildren, e, tagKey) 里 e.preventDefault() 会让标签留住，
// QML 的 signal 参数带一个同款对象（见 requestClose）。
//
// 官方 visible 是受控字段（index.tsx:81-94：传了就完全听外部，没传才由内部关闭态
// 决定）。这里用「组件内部绑定 visible: !control._hidden」表达 —— 使用处一旦写
// visible 绑定就把内部绑定顶掉，正好是同一种受控语义（实测见 PROGRESS.md）。
Item {
    id: control

    // ---- 官方 TagProps ----
    property string text: ""
    // 官方 children 是 ReactNode：字符串用 text（走 -content-ellipsis 截断），
    // 节点用 content 传一个 Component（走 -content-center）。这里没有把 content
    // 做成 default property：那样一来使用处声明的 HoverHandler / TapHandler
    // 会被塞进正文那一格里，命中范围只剩正文、不再是整枚标签。
    property var content: null
    property var tagKey: undefined
    property string size: "default"
    property string color: "grey"
    property string type: "light"
    property string shape: "square"
    property bool closable: false
    property var prefixIcon: null
    property var suffixIcon: null
    property string avatarSrc: ""
    property string avatarShape: "square"
    property bool colorful: false
    property bool gradient: false
    property string ariaLabel: ""

    // 官方 TagProps 没有这两个，它们本来是外层样式的覆盖：
    // disabled 是 tagInput.scss:119-122（.semi-tagInput-wrapper-disabled 里的
    // -wrapper-tag { color: disabled-text; background-color: transparent }），
    // maxWidth 是 .semi-tagInput-wrapper-tag { max-width: 100% }。
    property bool disabled: false
    property real maxWidth: -1
    // 官方 style 的等价入口（内联样式压过所有类名规则），文档里「自定义颜色」
    // 就是走 style。TagGroup 的 +N 标签用的正是 style={{ backgroundColor: 'transparent' }}，
    // 所以这里只开放底色。
    property string backgroundColor: ""

    signal clicked()
    signal closed(var tagChildren, var event, var tagKey)
    signal keyPressed(var event)
    signal mouseEntered()

    // ---- 尺寸（$height-tag_*、$spacing-tag_*）----
    readonly property bool isLarge: control.size === "large"
    readonly property int tagHeight: control.isLarge ? 24 : 20
    readonly property int gap: Theme.current.spacingExtraTight      // 4
    readonly property int padX: Theme.current.spacingTight          // 8
    readonly property bool isAvatar: control.avatarSrc !== ""
    readonly property bool circleAvatar: control.avatarShape === "circle"
    // 头像档的左内边距被 -avatar-square（0 4 0 0）/ -avatar-circle（2 4 2 2）接管
    readonly property int padLeft: control.isAvatar
        ? (control.circleAvatar ? Theme.current.spacingSuperTight : 0) : control.padX
    // -closable 是 4 4 4 8，-avatar-square 是 0 4 0 0、-avatar-circle 是 2 4 2 2，
    // 两类都把右内边距收成 4（头像那条写在 -closable 之后，两者同时命中也听它的）
    readonly property int padRight: control.closable || control.isAvatar
        ? Theme.current.spacingExtraTight : control.padX
    // -avatar-square 的头像与 tag 等高（20/24），-avatar-circle 是 16/20
    readonly property int avatarSide: !control.isAvatar ? 0
        : (control.circleAvatar ? (control.isLarge ? 20 : 16) : (control.isLarge ? 24 : 20))

    // ---- 色板：官方类名是 semi-tag-{color}-{type} ----
    readonly property bool isWhite: control.color === "white"
    readonly property string colorKey: control.camelCase(control.color)
    readonly property var ramp: Theme.current[control.colorKey]
    readonly property bool hasRamp: control.ramp !== undefined && control.ramp !== null

    function camelCase(name) {
        const parts = String(name).split("-");
        let out = parts[0];
        for (let i = 1; i < parts.length; ++i)
            out += parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        return out;
    }

    // 色板取档。档名不合法时官方那条 mixin 不会命中任何规则，这里退成透明
    function toneColor(index, alpha) {
        if (!control.hasRamp)
            return "transparent";
        const c = control.ramp[index];
        return Qt.rgba(c.r, c.g, c.b, alpha === undefined ? 1 : alpha);
    }

    // ---- 层叠：.colorful.-{type}（两个类名）> .-avatar-* > .-white-{type} / .-{color}-{type} ----
    readonly property bool gradientSurface: control.colorful && control.gradient
        && (control.type === "solid" || control.type === "light")
    // solid+gradient 用 --semi-color-ai-general（= --semi-ai-general-5），
    // light+gradient 用 --semi-ai-general-0
    readonly property string gradientCss: control.type === "light"
        ? Theme.current.aiGeneral0 : Theme.current.aiGeneral5
    readonly property var gradientStops: control.gradientSurface
        ? CssGradient.horizontalStops(control.gradientCss) : []

    readonly property color surfaceColor: {
        const t = Theme.current;
        // 官方 style 是内联样式，压过包括 colorful 在内的所有类名规则
        if (control.backgroundColor !== "")
            return control.backgroundColor;
        if (control.colorful) {
            if (control.type === "solid")
                return control.gradient ? CssGradient.representative(control.gradientCss)
                    : t.colorAiPurple;
            if (control.type === "light")
                return control.gradient ? CssGradient.representative(control.gradientCss)
                    : control.aiRampAt(0);
            return t.colorWhite;                  // ghost：$color-tag_colorful_ghost-bg
        }
        if (control.disabled)
            return "transparent";                 // tagInput.scss:119-122
        if (control.isAvatar || control.isWhite)
            return t.colorBg4;
        if (control.type === "ghost")
            return "transparent";
        return control.type === "solid" ? control.toneColor(5) : control.toneColor(5, 0.15);
    }
    // ghost 才有描边（mixin.scss 的 border），white 与头像档任何 type 都带 1px
    readonly property int borderWidth: control.type === "ghost"
        || control.isWhite || control.isAvatar ? 1 : 0
    readonly property color borderColor: {
        const t = Theme.current;
        if (control.colorful && control.type === "ghost") {
            // 非渐变的官方写的是 border-color: var(--semi-color-ai-general)，那是一支
            // 渐变，浏览器按 IACVT 退成 currentColor（= ai-purple）；渐变那支是
            // border:none + 一个 mask 出来的 ::before 描边环，QML 画不了渐变描边，
            // 同样退成代表色
            return control.gradient ? CssGradient.representative(Theme.current.aiGeneral5)
                : t.colorAiPurple;
        }
        if (control.isAvatar)
            return t.colorBorder;                 // $color-tag_avatar-border-default
        if (control.isWhite)
            return control.greyAt(2, 0.7);        // $color-tag_white-border-default
        if (control.type === "ghost")
            return control.toneColor(4);
        return "transparent";
    }
    readonly property color foreground: {
        const t = Theme.current;
        if (control.colorful) {
            if (control.type === "solid")
                return t.colorWhite;
            // 官方 light/ghost + gradient 用 background-clip: text 铺渐变，
            // Qt Quick 没有等价能力，取渐变代表色（同 Button）
            if (control.gradient)
                return CssGradient.representative(Theme.current.aiGeneral5);
            return t.colorAiPurple;
        }
        if (control.disabled)
            return t.colorDisabledText;           // tagInput.scss:119-122
        if (control.isAvatar || control.isWhite)
            return t.colorText0;
        if (!control.hasRamp)
            return t.colorText1;
        if (control.type === "solid")
            return t.colorWhite;
        return control.type === "ghost" ? control.toneColor(5) : control.toneColor(8);
    }
    // 叉：$color-tag_close-icon-*（default text-2 / hover text-1 / active text-0）。
    // white 档另有 .semi-tag-white-{type} .semi-tag-close = text-2，编译后它在
    // -close:hover（同为两类名）之后，于是白底标签的叉悬浮不再提亮。
    readonly property color closeColor: {
        const t = Theme.current;
        if (control.isWhite)
            return t.colorText2;
        if (closeArea.pressed)
            return t.colorText0;
        if (closeArea.containsMouse && control.enabled)
            return t.colorText1;
        return t.colorText2;
    }

    function aiRampAt(index) {
        const list = Theme.current.aiPurple;
        return index < list.length ? list[index] : Theme.current.colorAiPurple;
    }

    function greyAt(index, alpha) {
        const list = Theme.current.grey;
        const c = list[index];
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    // ---- 圆角：-square 3 / -circle 全圆；-avatar-circle 定死 11（20 高）与 13（24 高）----
    readonly property real cornerRadius: {
        if (control.isAvatar && control.circleAvatar)
            return control.tagHeight / 2 + 1;
        return control.shape === "circle" ? control.tagHeight / 2 : Theme.current.radiusSmall;
    }
    // SplitTagGroup 会把中间标签的圆角清零、只留首尾外侧
    property bool splitChild: false
    property bool splitFirst: false
    property bool splitLast: false
    readonly property real leftRadius: control.splitChild && !control.splitFirst
        ? 0 : control.cornerRadius
    readonly property real rightRadius: control.splitChild && !control.splitLast
        ? 0 : control.cornerRadius

    // ---- 图标位：官方 -prefix-icon / -suffix-icon 吃 ReactNode，图标默认 16（width-icon-medium）----
    readonly property bool prefixIsName: typeof control.prefixIcon === "string"
        && control.prefixIcon !== ""
    readonly property bool prefixIsComponent: control.prefixIcon !== undefined
        && control.prefixIcon !== null && typeof control.prefixIcon !== "string"
    readonly property bool prefixShown: control.prefixIsName || control.prefixIsComponent
    readonly property bool suffixIsName: typeof control.suffixIcon === "string"
        && control.suffixIcon !== ""
    readonly property bool suffixIsComponent: control.suffixIcon !== undefined
        && control.suffixIcon !== null && typeof control.suffixIcon !== "string"
    readonly property bool suffixShown: control.suffixIsName || control.suffixIsComponent
    readonly property real prefixWidth: control.prefixIsName ? Theme.current.widthIconMedium
        : (control.prefixIsComponent ? prefixLoader.implicitWidth : 0)
    readonly property real suffixWidth: control.suffixIsName ? Theme.current.widthIconMedium
        : (control.suffixIsComponent ? suffixLoader.implicitWidth : 0)
    readonly property real closeWidth: control.closable ? Theme.current.widthIconSmall : 0
    readonly property bool hasCustomContent: control.content !== undefined
        && control.content !== null
    // 内容超长时截断。官方是 -content-ellipsis 的 text-overflow，
    // 供外层决定要不要弹 Tooltip
    readonly property bool textClipped: label.truncated

    // 除正文外的部分：每一段自带一个 4px（prefix padding-right、avatar
    // margin-right、suffix/close padding-left 都是 $spacing-extra-tight）
    readonly property real siblingsWidth: (control.prefixShown ? control.prefixWidth + control.gap : 0)
        + (control.isAvatar ? control.avatarSide + control.gap : 0)
        + (control.suffixShown ? control.gap + control.suffixWidth : 0)
        + (control.closable ? control.gap + control.closeWidth : 0)
    readonly property real bodyNatural: control.hasCustomContent
        ? contentLoader.implicitWidth : label.implicitWidth
    // 必须是 real：文字天然宽带小数，取整会让可用宽度比天然宽度小一点，
    // label 白白被判定成截断（PROGRESS.md 坑 47）
    readonly property real naturalWidth: control.padLeft + control.padRight
        + control.siblingsWidth + control.bodyNatural
    readonly property bool clamped: control.maxWidth >= 0 && control.naturalWidth > control.maxWidth
    readonly property real bodyWidth: control.clamped
        ? Math.max(0, control.maxWidth - control.padLeft - control.padRight
            - control.siblingsWidth) : control.bodyNatural
    implicitWidth: control.clamped ? control.maxWidth : control.naturalWidth
    implicitHeight: control.tagHeight

    // 官方 visible：内部关闭态只在「使用处没写 visible」时生效。这里给 visible
    // 一条内部绑定，使用处一旦绑定就把它顶掉 —— 与官方受控语义同一套。
    visible: !control._hidden

    Accessible.name: control.ariaLabel !== "" ? control.ariaLabel : control.text
    Accessible.role: control.closable ? Accessible.Button : Accessible.StaticText
    // 官方 clickable 时给 role=button + tabIndex=0；「传了 onClick」这一支
    // QML 侧探测不到（signal 没有连接查询），只按 closable 判定
    activeFocusOnTab: control.closable && control.enabled

    Rectangle {
        id: surface

        objectName: "tagSurface"
        anchors.fill: parent
        topLeftRadius: control.leftRadius
        bottomLeftRadius: control.leftRadius
        topRightRadius: control.rightRadius
        bottomRightRadius: control.rightRadius
        color: control.surfaceColor
        border.width: control.borderWidth
        border.color: control.borderColor

        Behavior on color {
            ColorAnimation { duration: Theme.current.durationFast }
        }
    }

    // 多彩渐变的底另铺一层：Rectangle 的 gradient 非空时 color 就不生效了
    Rectangle {
        id: gradientSurface

        objectName: "tagGradientSurface"
        anchors.fill: parent
        topLeftRadius: control.leftRadius
        bottomLeftRadius: control.leftRadius
        topRightRadius: control.rightRadius
        bottomRightRadius: control.rightRadius
        visible: control.gradientSurface

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

    // focus-visible：官方是 outline: 2px solid $color-tag-outline-focus
    Rectangle {
        id: focusRing

        objectName: "tagFocusRing"
        anchors.fill: parent
        anchors.margins: -2
        topLeftRadius: control.leftRadius + 2
        bottomLeftRadius: control.leftRadius + 2
        topRightRadius: control.rightRadius + 2
        bottomRightRadius: control.rightRadius + 2
        color: "transparent"
        border.width: 2
        border.color: Theme.current.colorPrimaryLightActive
        visible: FocusVisible.shouldShow(control.activeFocus)
    }

    // 官方 .semi-tag 是 inline-flex + align-items:center；正文两边那几段各带 4px，
    // 所以 Row 的 spacing 取 4 正好逐段复现（正文那一格永远存在，空的时候宽 0，
    // 两侧的 4px 照算 —— 官方 .semi-tag-content 也是永远渲染的）
    Row {
        id: content

        objectName: "tagContent"
        x: control.padLeft
        anchors.verticalCenter: parent.verticalCenter
        spacing: control.gap

        Item {
            id: prefixHost

            objectName: "tagPrefixHost"
            anchors.verticalCenter: parent.verticalCenter
            visible: control.prefixShown
            implicitWidth: control.prefixWidth
            implicitHeight: control.prefixIsName ? Theme.current.widthIconMedium
                : prefixLoader.implicitHeight

            Icon {
                objectName: "tagPrefixIcon"
                anchors.centerIn: parent
                visible: control.prefixIsName
                name: control.prefixIsName ? control.prefixIcon : ""
                size: Theme.current.widthIconMedium
                color: control.foreground
            }

            Loader {
                id: prefixLoader

                objectName: "tagPrefixLoader"
                anchors.centerIn: parent
                visible: control.prefixIsComponent
                sourceComponent: control.prefixIsComponent ? control.prefixIcon : null
            }
        }

        Avatar {
            id: avatarHost

            objectName: "tagAvatar"
            anchors.verticalCenter: parent.verticalCenter
            visible: control.isAvatar
            width: control.avatarSide
            height: control.avatarSide
            src: control.avatarSrc
            shape: control.circleAvatar ? "circle" : "square"
        }

        // .semi-tag-content { flex: 1 }：截断时吃掉剩下的宽度
        Item {
            id: body

            objectName: "tagBody"
            anchors.verticalCenter: parent.verticalCenter
            width: control.bodyWidth
            height: control.tagHeight

            Text {
                id: label

                objectName: "tagLabel"
                anchors.verticalCenter: parent.verticalCenter
                // 官方 isString(children) 才走 -content-ellipsis，节点走 -content-center
                visible: !control.hasCustomContent && control.text !== ""
                width: body.width
                text: control.text
                color: control.foreground
                font.pixelSize: Theme.current.fontSizeSmall
                font.weight: control.colorful ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Loader {
                id: contentLoader

                objectName: "tagContentLoader"
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: control.hasCustomContent ? control.content : null
            }
        }

        Item {
            id: suffixHost

            objectName: "tagSuffixHost"
            anchors.verticalCenter: parent.verticalCenter
            visible: control.suffixShown
            implicitWidth: control.suffixWidth
            implicitHeight: control.suffixIsName ? Theme.current.widthIconMedium
                : suffixLoader.implicitHeight

            Icon {
                objectName: "tagSuffixIcon"
                anchors.centerIn: parent
                visible: control.suffixIsName
                name: control.suffixIsName ? control.suffixIcon : ""
                size: Theme.current.widthIconMedium
                color: control.foreground
            }

            Loader {
                id: suffixLoader

                objectName: "tagSuffixLoader"
                anchors.centerIn: parent
                visible: control.suffixIsComponent
                sourceComponent: control.suffixIsComponent ? control.suffixIcon : null
            }
        }

        Item {
            id: closeHost

            objectName: "tagCloseHost"
            anchors.verticalCenter: parent.verticalCenter
            visible: control.closable
            implicitWidth: control.closeWidth
            implicitHeight: control.closeWidth

            Icon {
                objectName: "tagCloseIcon"
                anchors.centerIn: parent
                // <IconClose size="small" /> → 12
                name: "close"
                size: Theme.current.widthIconSmall
                color: control.closeColor
            }

            // 官方 close() 里 e.stopPropagation() + stopImmediatePropagation()：
            // 点叉不算点标签。MouseArea 把按下吃掉，根项的 TapHandler 拿不到
            // （实测见 tests/tst_tag.qml 的那条断言）。
            MouseArea {
                id: closeArea

                anchors.fill: parent
                cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: control.enabled
                enabled: control.enabled
                onClicked: control.requestClose()
            }
        }
    }

    HoverHandler {
        id: hover

        enabled: control.enabled
        onHoveredChanged: {
            if (hovered)
                control.mouseEntered();
        }
    }

    TapHandler {
        id: tap

        enabled: control.enabled
        onTapped: control.clicked()
    }

    // 官方 handleKeyDown（index.tsx:108-127）：Backspace/Delete 关闭、Enter 触发
    // onClick、Escape 失焦
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
            if (control.closable && control.enabled)
                control.requestClose();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            control.clicked();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            // 官方 event.target.blur()：activeFocus 是只读的，写 focus 才会掉焦
            control.focus = false;
        }
        control.keyPressed(event);
    }

    // 官方 close()：先回调，再读 defaultPrevented；没被拦截才收起
    readonly property bool hidden: control._hidden
    property bool _hidden: false

    function requestClose() {
        const ev = { prevented: false };
        ev.preventDefault = function () {
            ev.prevented = true;
        };
        control.closed(control.text, ev, control.tagKey);
        if (!ev.prevented)
            control._hidden = true;
    }

    function stopPosition(index) {
        return index < control.gradientStops.length ? control.gradientStops[index].position : 1;
    }

    function stopColor(index) {
        return index < control.gradientStops.length ? control.gradientStops[index].color : "transparent";
    }
}
