import QtQuick

// 骨架屏的一格占位。官方是 `item.tsx` 的 `Generic` 渲染出的
// `<div class="semi-skeleton-{type}">`，以及 Paragraph 的每个 `<li>`：
// 底色 `--semi-color-fill-0`、圆角 `--semi-border-radius-small`。
// `Generic` 在官方是内部类，对外只有 SkeletonAvatar / SkeletonImage / SkeletonTitle /
// SkeletonButton 这四个壳（SkeletonParagraph 是另一支，ul 套 li），这里照抄这个分工。
//
// 官方动的是**背景图**，不是颜色：
//     background: linear-gradient(90deg, fill-0 25%, fill-1 44%, fill-0 88%);
//     background-size: 400% 100%;                        // 带是元素宽的 4 倍
//     animation: 1400ms skeleton-loading ease infinite;  // background-position: 100% → 0
// Qt 的 Rectangle.gradient 只描述元素自身 0..1 那一段，也没有渐变起点终点可动，
// 所以每帧把「带」重新换算进窗口：窗口左沿在带上的分数位置 = 0.75 × (1 − phase)，
// phase 从 0 走到 1 就是 background-position 从 100% 走到 0%（高亮自左向右扫过）。
// 掉在窗口外的色标塌到窗口边上、颜色取窗口边上的采样值 —— 等于多一个和边重复的色标，画出来不变。
//
// 官方 `.semi-skeleton-active` 是后代选择器，占位件自己没有 active 属性，
// 所以这里沿父链认领承载它的那个 Skeleton（同 GallerySection 找外壳的写法）。
Rectangle {
    id: block

    objectName: "skeletonBlock"

    readonly property Item skeletonHost: {
        let node = block.parent;
        while (node !== null && node !== undefined) {
            // qmllint disable missing-property
            if (node.isSkeletonHost === true)
                return node;
            // qmllint enable missing-property
            node = node.parent;
        }
        return null;
    }
    // qmllint disable missing-property
    readonly property bool shimmerOn: block.skeletonHost !== null && block.skeletonHost.active === true
    // qmllint enable missing-property

    // 动画进度，0 = background-position: 100%，1 = 0%
    property real bandPhase: 0
    readonly property var shimmerStops: block.stopsAtPhase(block.bandPhase)
    // $animation_duration-skeleton-highlight
    readonly property int shimmerDuration: 1400

    color: Theme.current.colorFill0
    radius: Theme.current.radiusSmall
    gradient: block.shimmerOn ? shimmer : null

    // 带上三个 CSS 色标（0.25 fill-0 / 0.44 fill-1 / 0.88 fill-0）换算到窗口内的位置
    function stopsAtPhase(phase) {
        const windowStart = 0.75 * (1 - phase);
        const left = block.sampleAt(windowStart);
        const right = block.sampleAt(windowStart + 0.25);
        const base = Theme.current.colorFill0;
        const bright = Theme.current.colorFill1;
        return [
            { position: 0, color: left },
            block.stopInWindow(0.25, windowStart, base, left, right),
            block.stopInWindow(0.44, windowStart, bright, left, right),
            block.stopInWindow(0.88, windowStart, base, left, right),
            { position: 1, color: right }
        ];
    }

    function stopInWindow(fraction, windowStart, cssColor, left, right) {
        const local = (fraction - windowStart) / 0.25;
        if (local <= 0)
            return { position: 0, color: left };
        if (local >= 1)
            return { position: 1, color: right };
        return { position: local, color: cssColor };
    }

    // 官方 linear-gradient 在色标之间线性插值。fill-0 与 fill-1 是同一个 RGB、
    // 只有 alpha 不同（semi.css 的 --semi-color-fill-0 / -1），所以这里逐通道插就够了。
    function sampleAt(fraction) {
        const base = Theme.current.colorFill0;
        const bright = Theme.current.colorFill1;
        if (fraction <= 0.25 || fraction >= 0.88)
            return base;
        if (fraction <= 0.44)
            return block.mixColor(base, bright, (fraction - 0.25) / 0.19);
        return block.mixColor(bright, base, (fraction - 0.44) / 0.44);
    }

    function mixColor(from, to, ratio) {
        return Qt.rgba(from.r + (to.r - from.r) * ratio, from.g + (to.g - from.g) * ratio,
            from.b + (to.b - from.b) * ratio, from.a + (to.a - from.a) * ratio);
    }

    Gradient {
        id: shimmer

        orientation: Gradient.Horizontal
        GradientStop { position: block.shimmerStops[0].position; color: block.shimmerStops[0].color }
        GradientStop { position: block.shimmerStops[1].position; color: block.shimmerStops[1].color }
        GradientStop { position: block.shimmerStops[2].position; color: block.shimmerStops[2].color }
        GradientStop { position: block.shimmerStops[3].position; color: block.shimmerStops[3].color }
        GradientStop { position: block.shimmerStops[4].position; color: block.shimmerStops[4].color }
    }

    // $animation_duration-skeleton-highlight = 1400ms，$animation_function-skeleton-highlight = ease。
    // CSS 的 ease 是 cubic-bezier(.25,.1,.25,1)，Qt 6.11 的 Easing.BezierSpline 退化成线性（坑 50），
    // 取形状最接近的内置曲线 InOutQuad（同 Collapsible 那条）。
    NumberAnimation {
        target: block
        property: "bandPhase"
        from: 0
        to: 1
        duration: block.shimmerDuration
        loops: Animation.Infinite
        running: block.shimmerOn
        easing.type: Easing.InOutQuad
    }
}
