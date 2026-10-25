pragma ComponentBehavior: Bound

import QtQuick

// 轮播的左右箭头。官方 `packages/semi-ui/carousel/CarouselArrow.tsx`
// （render :19-59、renderLeftIcon / renderRightIcon :11-18）+
// `semi-foundation/carousel/carousel.scss` 的 `-arrow` 那一段与 variables.scss。
//
//     CarouselArrow {
//         anchors.fill: parent
//         type: "hover"
//         carouselHovered: root.hovered
//         onPrevClicked: control.prev()
//         onNextClicked: control.next()
//     }
//
// 官方这一层的四条行为：
//   · 外层 `-arrow` 只有 `display:flex; font-size: $width-carousel_arrow(32px); cursor:pointer`
//     —— **它自己不带定位**，里面那两个 div 是 `position:absolute` ⇒ 参照物是最近的那个
//     定位祖先，也就是 `.carousel`（`position:relative`）。所以 prev 是 `left: 20 / top: 50%`、
//     next 是 `right: 20 / top: 50%`，都相对整块轮播垂直居中。
//   · 图标是 `IconChevronLeft` / `IconChevronRight`，`size="inherit"` ⇒ 吃那 32px 的 font-size；
//     两个都带 `aria-label`（"Previous index" / "Next index"）。
//   · `arrowProps.leftArrow.children` / `.rightArrow.children` 换掉图标，`.props` 原样摊到
//     那一格 div 上（端口只落 children 那半，且支持「字符串=图标名 / Component=任意节点」两档）。
//   · `arrowType: 'hover'` 是 `-arrow-hover div { opacity: 0 }` + `&:hover .-arrow-hover div
//     { opacity: 1 }` ⇒ 悬浮**整块轮播**才显形（不是悬浮箭头自己）。这一条端口要一个
//     `carouselHovered` 输入（官方靠 CSS 后代选择器，端口没有 CSS）。
//
// 配色：dark 是黑 .5 → 悬浮 1，primary 是 `--semi-blue-6` .4 → 1，light 是白 .4 → 1。
// 与指示器不同，箭头没有「选中态」，也只有这两档。那条 `transition: color …` 的时长令牌
// 同样取的是 `--semi-transition_delay-none`（0ms）⇒ 换色瞬时，端口不做过渡。
// **透明度不能塞进 Icon.color**：Icon 走 MultiEffect 的 colorization，着色器只改 RGB、
// 输出 alpha 恒等于源 alpha（multieffect.frag:84，colorizationColor.a 只是灰度与目标色的
// 混合比）⇒ 带 alpha 的 color 会被画成实心（坑 135，gallery 截图像素实锤 (127,127,127)）。
// 端口落法：color 给**不透明**基色，透明度走 Icon 自己的 `opacity`（真实的合成乘法，
// 与 CSS `color: rgba(...)` 的效果一致）。
Item {
    id: control

    // ---- 官方 CarouselArrowProps（interface.ts:48-54）----
    property var arrowProps: undefined
    property string theme: "light"
    property string type: "always"             // always | hover

    /// 端口侧通道：官方是 `.carousel:hover .-arrow-hover div`，端口把它算好传进来
    property bool carouselHovered: true

    signal prevClicked()
    signal nextClicked()

    readonly property real arrowSize: 32                                      // $width-carousel_arrow
    readonly property real inset: 20                                          // $spacing-carousel_arrow-left/-right
    readonly property bool hiddenByType: control.type === "hover" && !control.carouselHovered
    /// 非悬浮档的 alpha：dark .5、其余 .4（官方三主题的 -bg-default）
    readonly property real restAlpha: control.theme === "dark" ? 0.5 : 0.4

    // 官方那一层是 `display: flex` 的绝对定位容器，自己没有内在尺寸（里面的两个 div 是
    // position:absolute）⇒ 端口不做 implicitWidth / implicitHeight，尺寸由使用方给
    // （Carousel 里铺满整块轮播）。

    // 官方三主题的基色：dark=黑、primary=`--semi-blue-6`、light=白（**恒不透明**，见文件头）
    function themeBase() {
        if (control.theme === "dark")
            return Theme.current.colorBlack;
        if (control.theme === "primary")
            return Theme.current.blue[6];
        return Theme.current.colorWhite;
    }

    function customNode(side, key) {
        const box = control.arrowProps ? control.arrowProps[side] : undefined;
        return box ? box[key] : undefined;
    }

    /// 官方这一格只有两个键：`children`（换成任意 ReactNode）与 `props`（原样摊到 div 上）。
    /// `props` 那半只喂 DOM（含 onClick，端口用 TapHandler 代替）⇒ 收了不落地；
    /// `children` 端口支持两档：字符串 = 图标名（走 Icon.name），Component = 任意节点。
    function customName(side) {
        const value = control.customNode(side, "children");
        return typeof value === "string" ? value : "";
    }

    function customComponent(side) {
        const value = control.customNode(side, "children");
        return value instanceof Component ? value : null;
    }

    // ---- 左箭头 ----
    Item {
        id: prevBox

        objectName: "carouselArrowPrev"

        x: control.inset
        y: (control.height - height) / 2
        // **别读 Loader.implicitWidth 判「有没有自定义节点」**：Loader  deactivated 之后
        // item 变 null，但 implicitWidth 停在 24 不归零（探针 tests/tmp_carousel_probe.qml 的 B 段）
        // ⇒ 换成图标名档时那一格会卡在自定义尺寸。判据只能看 active / item。
        width: customLoader.active ? customLoader.implicitWidth : control.arrowSize
        height: customLoader.active ? customLoader.implicitHeight : control.arrowSize
        opacity: control.hiddenByType ? 0 : 1

        Loader {
            id: customLoader

            objectName: "carouselArrowPrevNode"

            active: control.customComponent("leftArrow") !== null
            sourceComponent: control.customComponent("leftArrow")
            visible: active
        }

        Icon {
            id: prevIcon

            objectName: "carouselArrowPrevIcon"

            visible: customLoader.active === false
            name: control.customName("leftArrow") !== ""
                ? control.customName("leftArrow") : "chevron_left"
            size: control.arrowSize
            color: control.themeBase()                       // 恒不透明；透明度走 opacity
            opacity: prevHover.hovered ? 1 : control.restAlpha

            Accessible.name: "Previous index"        // 官方 aria-label
        }

        HoverHandler {
            id: prevHover

            objectName: "carouselArrowPrevHover"

            cursorShape: Qt.PointingHandCursor       // -arrow { cursor: pointer }
        }

        TapHandler {
            onTapped: control.prevClicked()
        }
    }

    // ---- 右箭头 ----
    Item {
        id: nextBox

        objectName: "carouselArrowNext"

        x: control.width - control.inset - width
        y: (control.height - height) / 2
        width: nextCustom.active ? nextCustom.implicitWidth : control.arrowSize
        height: nextCustom.active ? nextCustom.implicitHeight : control.arrowSize
        opacity: control.hiddenByType ? 0 : 1

        Loader {
            id: nextCustom

            objectName: "carouselArrowNextNode"

            active: control.customComponent("rightArrow") !== null
            sourceComponent: control.customComponent("rightArrow")
            visible: active
        }

        Icon {
            id: nextIcon

            objectName: "carouselArrowNextIcon"

            visible: nextCustom.active === false
            name: control.customName("rightArrow") !== ""
                ? control.customName("rightArrow") : "chevron_right"
            size: control.arrowSize
            color: control.themeBase()                       // 恒不透明；透明度走 opacity
            opacity: nextHover.hovered ? 1 : control.restAlpha

            Accessible.name: "Next index"            // 官方 aria-label
        }

        HoverHandler {
            id: nextHover

            objectName: "carouselArrowNextHover"

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: control.nextClicked()
        }
    }
}
