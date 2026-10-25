import QtQuick
import QtQuick.Effects

// 头像。规格照 packages/semi-ui/avatar/{index.tsx,interface.ts,TopSlotSvg.tsx}
// + packages/semi-foundation/avatar/{foundation.ts,constants.ts,avatar.scss,variables.scss,animation.scss}，
// 数值逐条对编译后的 packages/semi-ui/dist/css/semi.css（`.semi-avatar*`，2330-2974 行）。
//
//     Avatar { text: "Semi" }                          // 官方 children 是字符串那一支
//     Avatar { src: "qrc:/a.png"; shape: "square" }
//     Avatar { size: 64 }                              // 七档之外按自定义边长走内联宽高
//     AvatarGroup { Avatar { text: "A" }; Avatar { text: "B" } }
//
// 端口口径（其余见 PROGRESS.md 的 Avatar 行与坑 117）：
//   · 官方 `onError` 返回 false 才留住破图；`on`+大写是信号处理器保留前缀 ⇒ 这里改名 `error`。
//   · 官方 `clickable = onClick !== noop` 决定 tabIndex 与 alt 前缀；Qt 的 signal 探测不到有没有连接
//     （同 Tag 那条），所以焦点与 Tab 一律按 enabled 给，alt 不加 "clickable Avatar: " 前缀。
//   · `srcSet` / `imgAttr` 收了不产出差异：Qt 的 Image 没有 srcset 协商，也没有属性袋。
//   · 圆切靠 `Image{visible:false}` + `Rectangle{visible:false;layer.enabled:true}` 遮罩 + MultiEffect。
//     2026-10-21 cocoa 逐像素复验：圆内是图、方框四角是底色；遮罩项少了 layer.enabled 就整块不画，
//     而遮罩的几何是按它自己那圈的包围盒归一化的（挪位置没用，只能改形状）。offscreen 不画（坑 71）。
//   · 官方 `.semi-avatar { overflow: hidden }` 裁的是一切子项；端口只对「图片」与「hoverMask 覆盖层」
//     两道做圆切，文字那一支靠 `scale` 收紧后一般已经在盒子里（七档的行高都小于边长），不另开一层遮罩。
//   · `topSlot` 那圈帽子官方是 51×52 的 SVG 路径（44.5×46.9 外框）+ 竖向渐变 + 投影，端口画不了渐变与
//     feGaussianBlur ⇒ 取 `gradientStart` 一个色、按同一条 `top`/`scale` 摆一颗等比例的椭圆，再被头像自己
//     那颗圆裁一遍；两个 slot 的 `render` 档官方是 **流内** 元素（排在 avatar 之后，会把 wrapper 撑高）。
Item {
    id: control

    // ---- 官方 AvatarProps ----
    property string text: ""                  // 官方 children 的字符串档：整串显示，靠 scale 自适应
    property string src: ""
    property string srcSet: ""
    property string alt: ""
    property int gap: 3
    property string color: "grey"
    property string shape: "circle"
    property var size: "medium"               // 七档字符串之一，或一个数（自定义边长）
    property var hoverMask: null              // 图标名或 Component
    property var imgAttr: null
    property var error: null                  // 官方 onError：返回 false 就留住破图
    property var bottomSlot: null             // {shape,text,bgColor,textColor,render}
    property var topSlot: null                // {text,gradientStart,textColor,render}
    property var border: null                 // true|false，或 {color,motion}
    property bool contentMotion: false
    property var backgroundColor: null        // 官方 style 的内联底色，压过色板类名

    // ---- 官方 onClick / onMouseEnter / onMouseLeave ----
    signal clicked()
    signal mouseEntered()
    signal mouseLeft()

    // ---- AvatarGroup 下发：官方 cloneElement 把组的 size/shape 硬塞给每个成员，成员自己写的顶不掉 ----
    property var groupSize: undefined
    property string groupShape: ""
    property int groupBorderWidth: 0

    // ---- 内部状态 ----
    property bool keepBroken: false           // 官方 state.isImgExist 的反面（error() 返回 false 时留着）
    readonly property bool focusVisible: control.activeFocus   // 官方 state.focusVisible

    readonly property var sizeLadder: ["extra-extra-small", "extra-small", "small", "default",
        "medium", "large", "extra-large"]
    readonly property string sizeKey: control.groupSize !== undefined && control.groupSize !== null
        ? String(control.groupSize) : String(control.size)
    readonly property bool namedSize: control.sizeLadder.indexOf(control.sizeKey) >= 0
    // 认不出档又不是正数：null。用 var 而不是 int —— int 属性会把 Infinity 截成 0（实测），
    // 那样「有没有挡 NaN」这条闸门就读不出差别了
    readonly property var customSide: control.numericSide()
    // 既不在七档里又不是正数：官方那条内联宽高失效、又没有尺寸类名 ⇒ 退成缺省档 48
    readonly property int side: control.namedSize ? control.sizePx(control.sizeKey)
                                                  : (control.customSide !== null ? control.customSide : 48)
    readonly property string boxShape: control.groupShape !== "" ? control.groupShape : control.shape
    // 方角档的半径来自尺寸类名；自定义尺寸没有尺寸类名 ⇒ 0。圆角档恒等于半边（9999px）
    readonly property int radius: control.boxShape === "circle"
        ? Math.round(control.width / 2)
        : (control.namedSize ? control.squareRadiusPx(control.sizeKey) : 0)

    // 官方 isImg = src && state.isImgExist；isImgExist 初值 true，读图失败才翻
    readonly property bool imgKept: photo.status !== Image.Error || control.keepBroken
    readonly property bool isImg: control.src !== "" && control.imgKept

    // 色板类名只在「给了色号且没有图」时挂上；色号不合法时官方那条 mixin 命不中任何规则
    readonly property bool hasColorClass: control.color !== "" && !control.isImg
    readonly property string colorKey: control.camelCase(control.color)
    readonly property var ramp: Theme.current[control.colorKey]
    // COLOR 表里那条 'white' 在 scss 的 $colors 里没有 ⇒ 命不中任何规则。Theme 上的 white 是个
    // QColor 而不是色阶表，所以「有没有色阶可查」要按能不能取第 4 档来判。
    readonly property bool hasRamp: control.ramp !== undefined && control.ramp !== null
                                    && control.ramp.length !== undefined
    readonly property color surfaceColor: control.backgroundColor !== null
        ? control.backgroundColor
        : (control.hasColorClass && control.hasRamp ? control.ramp[3] : "transparent")
    // 文字色跟着色板类名走（那条 mixin 同时写 background-color 与 color: white）；
    // 类名命不中（color 给了 ''、给了图、或给了 'white' 这种表里有、规则里没有的）就退回继承值
    readonly property color labelColor: control.hasColorClass && control.hasRamp
        ? Theme.current.colorWhite : Theme.current.colorText0

    // 官方那两道闸：两个 slot 都只认有样式的六档，topSlot 还要求 shape === 'circle'
    // 两个槽的对象在没给时读属性会抛 TypeError（QML 会吞掉但留下脏值），一律走这两张空壳
    readonly property var topSlotData: control._taken(control.topSlot) ? control.topSlot : ({})
    readonly property var bottomSlotData: control._taken(control.bottomSlot) ? control.bottomSlot : ({})
    readonly property bool slotSized: ["extra-small", "small", "default", "medium", "large",
        "extra-large"].indexOf(control.sizeKey) >= 0
    readonly property bool showTopSlot: control._taken(control.topSlot) && control.slotSized
                                        && control.boxShape === "circle"
    readonly property bool showBottomSlot: control._taken(control.bottomSlot) && control.slotSized
    readonly property bool topSlotCustom: control.showTopSlot && control._taken(control.topSlotData.render)
    readonly property bool bottomSlotCustom: control.showBottomSlot && control._taken(control.bottomSlotData.render)

    readonly property bool borderOn: control._taken(control.border)
    readonly property bool borderMotion: control.borderIsObject() && control.border.motion === true
    readonly property color borderColor: control.borderIsObject() && control._taken(control.border.color)
        ? control.border.color : Theme.current.colorPrimary
    readonly property real ringSide: control.width + 7

    // 官方 changeScale：可用宽 = 边长 − 2*gap，只在 gap*2 < 边长 且两边都量得到时才收紧
    readonly property real availableTextWidth: control.width - control.gap * 2
    readonly property real contentScale: {
        if (control.width === 0 || label.implicitWidth === 0 || control.availableTextWidth <= 0)
            return 1;
        return control.availableTextWidth > label.implicitWidth
            ? 1 : control.availableTextWidth / label.implicitWidth;
    }

    readonly property bool hovered: rootHover.hovered || bottomSlotHover.hovered

    implicitWidth: Math.max(control.side, flowSlots.implicitWidth)
    implicitHeight: control.side + flowSlots.implicitHeight

    Accessible.role: Accessible.ListItem
    Accessible.name: control.alt !== "" ? control.alt : control.text
    activeFocusOnTab: control.enabled

    // ---- 档位表 ----
    function sizePx(key) {
        switch (key) {
        case "extra-extra-small":
            return 20;
        case "extra-small":
            return 24;
        case "small":
            return 32;
        case "default":
            return 40;
        case "medium":
            return 48;
        case "large":
            return 72;
        case "extra-large":
            return 128;
        }
        return 48;
    }

    function squareRadiusPx(key) {
        if (key === "extra-large")
            return 12;
        if (key === "large")
            return 6;
        return 3;
    }

    // $font-avatar_* 与四条 font-size-* mixin；自定义尺寸兜 base 那条 .semi-avatar-label（14）
    function labelPixelSize(key) {
        switch (key) {
        case "extra-extra-small":
        case "extra-small":
            return 10;
        case "small":
            return 12;
        case "default":
            return 18;
        case "medium":
            return 20;
        case "large":
            return 32;
        case "extra-large":
            return 64;
        }
        return 14;
    }

    function numericSide() {
        const v = Number(control.size);
        return isFinite(v) && v > 0 ? v : null;
    }

    function borderIsObject() {
        return typeof control.border === "object" && control.border !== null;
    }

    function camelCase(name) {
        const parts = String(name).split("-");
        let out = parts[0];
        for (let i = 1; i < parts.length; ++i)
            out += parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        return out;
    }

    function _taken(value) {
        return !!value;
    }

    function _isTextValue(value) {
        return typeof value === "string" || typeof value === "number";
    }

    // topSlot 的 svg：位移与缩放照 $spacing-avatar-top_slot_*（extra-small 官方没有这两条规则 ⇒ 0 / 1）
    function capShift(key) {
        switch (key) {
        case "small":
            return -28;
        case "default":
            return -32;
        case "medium":
            return -30;
        case "large":
            return -30;
        case "extra-large":
            return -32;
        }
        return 0;
    }

    function capScaleRatio(key) {
        switch (key) {
        case "small":
            return 0.4;
        case "default":
            return 0.7;
        case "medium":
            return 0.8;
        case "large":
            return 1.1;
        case "extra-large":
            return 1.4;
        }
        return 1;
    }

    function capTextSize(key) {
        switch (key) {
        case "small":
            return 5;
        case "default":
            return 6;
        case "medium":
            return 8;
        case "large":
            return 14;
        case "extra-large":
            return 16;
        }
        return 14;
    }

    function capTextMargin(key) {
        return key === "default" ? -2 : 0;
    }

    // bottomSlot：圆档 12/12/16/18/28/28；方档只有字号与描边分档
    function slotCircleSide(key) {
        switch (key) {
        case "default":
            return 16;
        case "medium":
            return 18;
        case "large":
        case "extra-large":
            return 28;
        }
        return 12;
    }

    function slotCircleText(key) {
        if (key === "extra-large")
            return 14;
        if (key === "extra-small" || key === "small")
            return 5;
        return 12;
    }

    // 方档那组类名官方拼成下划线（-shape_square-extra_small），实际挂出来是连字符 ⇒
    // extra-small 命不中 ⇒ 字号退成继承值、border-width 退成浏览器的 medium(3px)
    function slotSquareText(key) {
        if (key === "extra-small")
            return 14;
        if (key === "extra-large")
            return 14;
        if (key === "small")
            return 5;
        return 12;
    }

    function slotSquareBorder(key) {
        return key === "extra-small" ? 3 : 2;
    }

    // ---- 本体：官方 .semi-avatar（overflow:hidden；contentMotion 变换的就是这一层）----
    Item {
        id: body

        objectName: "avatarBody"
        anchors.fill: parent

        Rectangle {
            id: surface

            objectName: "avatarSurface"
            anchors.fill: parent
            radius: control.radius
            color: control.surfaceColor
        }

        Image {
            id: photo

            objectName: "avatarPhoto"
            anchors.fill: parent
            source: control.src
            sourceSize: Qt.size(control.width * 2, control.width * 2)
            fillMode: Image.PreserveAspectCrop
            visible: false
            smooth: true

            onStatusChanged: {
                if (status === Image.Error) {
                    const flag = (typeof control.error === "function") ? control.error() : undefined;
                    control.keepBroken = flag === false;
                }
            }
        }

        Rectangle {
            id: photoMask

            objectName: "avatarPhotoMask"
            anchors.fill: parent
            radius: control.radius
            color: Theme.current.colorWhite
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            id: photoEffect

            objectName: "avatarPhotoEffect"
            anchors.fill: parent
            visible: control.isImg
            source: photo
            maskEnabled: true
            maskSource: photoMask
        }

        Text {
            id: label

            objectName: "avatarLabel"
            anchors.centerIn: parent
            visible: !control.isImg && control.text !== ""
            text: control.text
            color: control.labelColor
            font.pixelSize: control.labelPixelSize(control.sizeKey)
            font.weight: Font.DemiBold
            scale: control.contentScale
        }

        // 官方 .semi-avatar-hover：绝对定位铺满本体，跟着一起圆切
        Item {
            id: hoverBox

            objectName: "avatarHoverBox"
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Loader {
                objectName: "avatarHoverNode"
                anchors.fill: parent
                active: control.hovered && control._taken(control.hoverMask)
                        && !control._isTextValue(control.hoverMask)
                sourceComponent: control._isTextValue(control.hoverMask) ? null : control.hoverMask
            }

            Icon {
                objectName: "avatarHoverIcon"
                anchors.centerIn: parent
                visible: control.hovered && control._isTextValue(control.hoverMask)
                name: control._isTextValue(control.hoverMask) ? String(control.hoverMask) : ""
            }
        }

        Rectangle {
            id: hoverMaskShape

            objectName: "avatarHoverMask"
            anchors.fill: parent
            radius: control.radius
            color: Theme.current.colorWhite
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            id: hoverEffect

            objectName: "avatarHoverEffect"
            anchors.fill: parent
            visible: control.hovered && control._taken(control.hoverMask)
            source: hoverBox
            maskEnabled: true
            maskSource: hoverMaskShape
        }

        // 官方 .semi-avatar-focus：outline 2px primary-light-active，画在盒子外一圈
        Rectangle {
            id: focusRing

            objectName: "avatarFocusRing"
            x: -2; y: -2
            width: control.width + 4
            height: control.height + 4
            visible: control.focusVisible
            color: "transparent"
            border.width: 2
            border.color: Theme.current.colorPrimaryLightActive
            radius: control.radius + 2
        }

        // 组内成员描边（.semi-avatar-group .semi-avatar-{size}，box-sizing:border-box ⇒ 吃进盒子里）
        Rectangle {
            objectName: "avatarGroupBorder"
            anchors.fill: parent
            visible: control.groupBorderWidth > 0
            color: "transparent"
            border.width: control.groupBorderWidth
            border.color: Theme.current.colorBg1
            radius: control.radius
        }
    }

    // ---- 顶部 slot：一圈被头像自己那个圆裁出来的「帽子」+ 压在顶边的文字 ----
    Item {
        id: topSlotBox

        objectName: "avatarTopSlotBox"
        anchors.fill: parent
        visible: control.showTopSlot && !control.topSlotCustom

        // svg 51×52、路径外框约 44.5×46.9，scale 以 svg 盒中心为原点
        readonly property real s: control.capScaleRatio(control.sizeKey)
        readonly property real blobW: 44.5 * topSlotBox.s
        readonly property real blobH: 46.9 * topSlotBox.s
        readonly property real blobCx: 25.5 + (25.25 - 25.5) * topSlotBox.s
        readonly property real blobCy: control.capShift(control.sizeKey) + 26
                                        + (24.45 - 26) * topSlotBox.s

        Rectangle {
            id: capClip

            objectName: "avatarTopSlotCapClip"
            anchors.fill: parent
            radius: Math.round(control.width / 2)
            color: "transparent"
            visible: false
            layer.enabled: true
        }

        Rectangle {
            id: capDisc

            objectName: "avatarTopSlotCap"
            width: topSlotBox.blobW
            height: topSlotBox.blobH
            x: topSlotBox.blobCx - width / 2
            y: topSlotBox.blobCy - height / 2
            radius: Math.min(width, height) / 2
            // QML 画不了 SVG 那条渐变，取起始色代表（默认两端都是 primary）
            color: control._taken(control.topSlotData.gradientStart)
                ? control.topSlotData.gradientStart : Theme.current.colorPrimary
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            id: capEffect

            objectName: "avatarTopSlotEffect"
            anchors.fill: parent
            source: capDisc
            maskEnabled: true
            maskSource: capClip
        }

        Text {
            id: capText

            objectName: "avatarTopSlotText"
            anchors.horizontalCenter: parent.horizontalCenter
            y: control.capTextMargin(control.sizeKey)
            visible: control._isTextValue(control.topSlotData.text)
            text: control._isTextValue(control.topSlotData.text) ? String(control.topSlotData.text) : ""
            color: control._taken(control.topSlotData.textColor)
                ? control.topSlotData.textColor : Theme.current.colorBg0
            font.pixelSize: control.capTextSize(control.sizeKey)
            font.weight: Font.DemiBold
        }

        Loader {
            id: capTextNode

            objectName: "avatarTopSlotTextNode"
            anchors.horizontalCenter: parent.horizontalCenter
            y: control.capTextMargin(control.sizeKey)
            active: !control._isTextValue(control.topSlotData.text) && control._taken(control.topSlotData.text)
            sourceComponent: control._isTextValue(control.topSlotData.text) ? null : control.topSlotData.text
        }

        SequentialAnimation {
            id: topSlotMotion

            loops: Animation.Infinite
            running: control.contentMotion
            NumberAnimation {
                target: topSlotBox
                property: "scale"
                from: 1; to: 0.9; duration: 500; easing.type: Easing.Linear
            }
            NumberAnimation {
                target: topSlotBox
                property: "scale"
                from: 0.9; to: 1; duration: 500; easing.type: Easing.Linear
            }
        }
    }

    // ---- 底部 slot：骑在头像下沿（bottom:3.5 + translateY(50%) ⇒ 中心压在那条线上）----
    // 官方那条 span 的类名是 -bottom_slot-shape_{bottomSlot.shape}：只有 circle / square 两种命得中，
    // 没给 shape 时两块样式都不落 ⇒ 只剩 -bottom_slot 本身（bg-0 的字、没有底色与尺寸）
    Item {
        id: bottomSlotBox

        objectName: "avatarBottomSlotBox"
        readonly property bool isCircle: control.bottomSlotData.shape === "circle"
        readonly property bool isSquare: control.bottomSlotData.shape === "square"
        readonly property bool boxed: bottomSlotBox.isCircle || bottomSlotBox.isSquare
        readonly property int discSide: control.slotCircleSide(control.sizeKey)
        readonly property int edge: control.slotSquareBorder(control.sizeKey)

        width: boxed ? slotShape.width : slotText.implicitWidth
        height: boxed ? slotShape.height : slotText.implicitHeight
        x: (control.width - width) / 2
        y: control.height - 3.5 - height / 2
        visible: control.showBottomSlot && !control.bottomSlotCustom

        HoverHandler { id: bottomSlotHover }

        TapHandler {
            onTapped: control.clicked()
        }

        Rectangle {
            id: slotShape

            objectName: "avatarBottomSlotShape"
            anchors.centerIn: parent
            visible: bottomSlotBox.boxed
            width: bottomSlotBox.isCircle ? bottomSlotBox.discSide
                : slotText.implicitWidth + 8 + bottomSlotBox.edge * 2
            height: bottomSlotBox.isCircle ? bottomSlotBox.discSide
                : slotText.implicitHeight + 2 + bottomSlotBox.edge * 2
            radius: bottomSlotBox.isCircle ? width / 2 : 4
            color: control._taken(control.bottomSlotData.bgColor)
                ? control.bottomSlotData.bgColor : Theme.current.colorPrimary
            border.width: bottomSlotBox.isSquare ? bottomSlotBox.edge : 0
            border.color: Theme.current.colorBg0
        }

        Text {
            id: slotText

            objectName: "avatarBottomSlotText"
            anchors.centerIn: parent
            text: control._isTextValue(control.bottomSlotData.text)
                ? String(control.bottomSlotData.text) : ""
            visible: control._isTextValue(control.bottomSlotData.text)
            color: control._taken(control.bottomSlotData.textColor)
                ? control.bottomSlotData.textColor : Theme.current.colorBg0
            font.pixelSize: bottomSlotBox.isCircle ? control.slotCircleText(control.sizeKey)
                : (bottomSlotBox.isSquare ? control.slotSquareText(control.sizeKey) : 14)
            font.weight: Font.DemiBold
        }
    }

    // ---- 官方 render 档：两个 slot 的 render() 返回的节点是排在 avatar 下面的流内元素 ----
    Column {
        id: flowSlots

        objectName: "avatarFlowSlots"
        y: control.height
        spacing: 0

        Loader {
            id: topSlotRender

            objectName: "avatarTopSlotRender"
            active: control.topSlotCustom
            sourceComponent: control.topSlotCustom ? control.topSlotData.render : null
        }

        Loader {
            id: bottomSlotRender

            objectName: "avatarBottomSlotRender"
            active: control.bottomSlotCustom
            sourceComponent: control.bottomSlotCustom ? control.bottomSlotData.render : null
        }
    }

    // ---- 额外边框：头像盒子外面再套一圈 1.5px 环（top/left −3.5，边长 = side + 7）----
    Rectangle {
        id: borderRing

        objectName: "avatarBorderRing"
        x: -3.5; y: -3.5
        width: control.ringSide
        height: control.ringSide
        visible: control.borderOn
        color: "transparent"
        border.width: 1.5
        border.color: control.borderColor
        // 方角那一组类名官方拼成下划线（-additionalBorder-extra_small）⇒ 命不中 ⇒ 半径 0；
        // 圆角档是 span 自己带的 -avatar-circle 在起作用
        radius: control.boxShape === "circle" ? control.ringSide / 2 : 0
    }

    Rectangle {
        id: motionRing

        objectName: "avatarBorderMotionRing"
        x: -3.5; y: -3.5
        width: control.ringSide
        height: control.ringSide
        visible: control.borderMotion
        color: "transparent"
        border.width: 1.5
        border.color: control.borderColor
        radius: control.boxShape === "circle" ? control.ringSide / 2 : 0

        // @keyframes semi-avatar-additionalBorder：opacity 1→0、scale 1→1.15、border-width 1.5→0
        // （末态已经全透明，那条 border-width 收零画不出额外差异，不另造）
        NumberAnimation {
            id: ringMotion

            target: motionRing
            property: "opacity"
            from: 1; to: 0; duration: 800
            loops: Animation.Infinite
            easing.type: Easing.Linear
            running: control.borderMotion
        }

        NumberAnimation {
            id: ringScaleMotion

            target: motionRing
            property: "scale"
            from: 1; to: 1.15; duration: 800
            loops: Animation.Infinite
            easing.type: Easing.Linear
            running: control.borderMotion
        }
    }

    // ---- 事件：官方挂在 wrapper 上，wrapper 的盒子就是这枚头像 ----
    HoverHandler {
        id: rootHover

        objectName: "avatarHover"
        cursorShape: Qt.PointingHandCursor
    }

    // 发射挂在合成后的那个标志上：handler 自己的 onHoveredChanged 里读派生属性还是上一拍的值
    // （坑 74 / 坑 93 那一族，Badge 也踩过），于是 enter 会变成一次 leave。
    onHoveredChanged: control.hovered ? control.mouseEntered() : control.mouseLeft()

    TapHandler {
        objectName: "avatarTap"
        onTapped: control.clicked()
    }

    // 官方 handleKeyDown：Enter 触发点击，Escape 掉焦
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            control.clicked();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            control.focus = false;
            event.accepted = true;
        }
    }

    // contentMotion 变换的是 .semi-avatar 本体（.semi-avatar-animated），槽位与环都不跟着走
    SequentialAnimation {
        id: bodyMotion

        loops: Animation.Infinite
        running: control.contentMotion
        NumberAnimation {
            target: body
            property: "scale"
            from: 1; to: 0.9; duration: 500; easing.type: Easing.Linear
        }
        NumberAnimation {
            target: body
            property: "scale"
            from: 0.9; to: 1; duration: 500; easing.type: Easing.Linear
        }
    }
}
