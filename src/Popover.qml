import QtQuick
import Semi

// 气泡卡片。比 Tooltip 能装，用来放结构化内容；官方那一份就是「换了皮肤的 Tooltip」。
//
// 看 popover/index.tsx:169-205 的 render：它自己一行逻辑都不写，把 content 包成一张卡片
// （`.semi-popover` + `.semi-popover-content` 两层无样式的 div），再连 trigger / position /
// style / spacing / showArrow 一起转交 Tooltip。所以这里同样以 Tooltip 为根：
// 五档触发模型、自动翻面、点外判定、Esc、进出场动画全都继承过来，
// Popover 只写「官方在这一档改了哪些缺省值、换了哪层皮肤」。
//
//     Button { id: btn; text: "打开" }
//     Popover {
//         target: btn
//         position: Enums.BottomLeft
//         showArrow: true
//         Text { text: "内容" }
//     }
//
//     // 官方 content 的字符串档，这里叫 text；富内容直接写子项
//     Popover { target: btn; text: "condition is false" }
//
// 官方缺省值（popover/index.tsx:126-144 的 defaultProps，逐条对着 tooltip 那一份）：
//   showArrow false（tooltip true）、position bottom（top）、zIndex 1030（1060）、
//   closeOnEsc true（false）、returnFocusOnClose true（false）、guardFocus true（false）、
//   disableFocusListener true（false）、arrowBounding {...tooltip, offsetY 6, height 8}；
//   spacing 不在 defaultProps 里，由 render 现算 `showArrow ? SPACING_WITH_ARROW(10) : SPACING(4)`
//   （constants.ts:44-46，tooltip 那一档恒为 8）。
//   其余沿用 tooltip：trigger 'hover'、motion true、autoAdjustOverflow true、
//   mouseEnter/LeaveDelay 50、arrowPointAtCenter true、margin 0、condition true。
//
// 皮肤（popover.scss + variables.scss 编译出的 `.semi-popover-wrapper` 一族）：
//   底色 $color-popover-bg-default = var(--semi-color-bg-3)、圆角 radius-medium、
//   字号 14 / 行高 20、**阴影 @mixin shadow-elevated**（tooltip 没有这一条）；
//   卡片在 scss 里没有任何 border 规则 —— 看到的那条 1px 是 shadow-elevated 的第一层
//   （`0 0 1px rgba(0,0,0,.3)`）画出来的环，本库跟 Dropdown 一样由 strokeColor 顶替（坑 34）；
//   文字色也没有规则，取 body 继承来的 text-0（tooltip 那条 `color: $color-tooltip-text-default`
//   只写在 `.semi-tooltip-wrapper` 上）；
//   内边距只有一条 `.semi-popover-with-arrow { padding: 12px }` ⇒ **showArrow=false 时是 0**，
//   官方「condition 条件触发」那节的字符串内容就是紧贴卡片边的；
//   小三角 24×8（$width/$height-popover_arrow）、探出 7（arrow.scss 的 -$height + $offset），
//   与卡片边重叠 1（同一份 $spacing-tooltip_arrow_offset-*）；卡片离触发器 10 ⇒ 三角尖离触发器 3；
//   带三角时最小 36×36：min-width = adjusted_offset-x(6) * 2 + 24，
//   min-height = 箭头竖档高 24 + adjusted_offset-y * 2，**popover 的 offset-y 是 6、tooltip 是 5**
//   （popover/variables.scss 把同名变量重赋了一遍），所以 tooltip 是 34、popover 是 36；
//   那颗三角是 popover/Arrow.tsx 的**两条 path**：描边色打底（$color-popover-arrow-border
//   = var(--semi-color-border)）+ 底色盖上面（$color-popover-arrow-bg = var(--semi-color-bg-3)），
//   也就是「卡片没有边、三角有一条边」—— 官方自己就长这样，文档「设置浮层背景色」也在提醒：
//   自定义底色时务必把 borderColor 一起声明，否则两边对不上。
//
// 与官方的差异（React / CSS 在 QML 侧无处落地，逐条）：
//   · `content` 官方收 ReactNode 或 `({ initialFocusRef }) => ReactNode`。这里拆成
//     `text`（字符串档，继承自 Tooltip 的 label）与子项（富内容档）两条，
//     函数档由 `initialFocus` 顶上：把要聚焦的那一项给它，打开时自动 forceActiveFocus。
//   · `style` 是内联样式表，官方在这张卡上真正读到的键只有 backgroundColor / borderColor /
//     color（以及 Arrow.tsx 的 popStyle 那两级回退）。这里就按这三条落地，值要写成 QML 认得的
//     颜色（"#2a6ff5"、Qt.rgba()、Theme.current.blue[4]），浏览器那套 `var(--semi-*)` 字符串
//     解析不了；`borderWidth` / `borderStyle` **不开关我们那条环** —— 它是 shadow-elevated
//     第一层的替身，官方即使 borderStyle: none 也还有那圈阴影。
//   · `arrowStyle` 三个键（borderColor / backgroundColor / borderOpacity）按 Arrow.tsx 的
//     「先看 arrowStyle、再看 style、最后落回令牌」三级回退接进 arrowStrokeColor /
//     arrowFillColor / arrowBorderOpacity。
//   · `guardFocus`（Tab 在浮层内循环）与 `disableArrowKeyDown`（方向键把焦点送进浮层）依赖
//     DOM 的 focusable 枚举，本库不劫 Tab / 方向键，交给 Qt 自己的焦点链；
//   · `returnFocusOnClose` 只接 Esc 那一路（官方 focusTrigger 也只在 _handleEscKeyDown 里被调，
//     foundation.ts:1321-1327），焦点能不能真的落回触发器取决于 target 自己的 focusPolicy；
//   · `role`（click / custom 档给 dialog、hover 档给 tooltip）、children 上的
//     `aria-expanded` / `aria-haspopup` / `aria-controls`、content wrapper 的自动 `id`
//     都是 ARIA 框架那一侧，QML 没有落点（同坑 91）；
//   · `stopPropagation` / `wrapperClassName` / `wrapperId` / `className` / `contentClassName` /
//     `prefixCls` / `preventScroll` / `transformFromCenter` / `arrowBounding` / `wrapWhenSpecial`
//     与 keepDOM 同理不落 QML（详见 src/Tooltip.qml 文件头那几条）；
//     `arrowBounding` 的三个数在 JS 侧只被用来算 `6 + width/2 = 18`（popover 的 width 也是 24，
//     与 tooltip 同值），本库就是 arrowCross 18；height/offsetY 只有 CSS 用，已经吃在
//     arrowSize / arrowOverlap 里。
//   · `onVisibleChange` 就是 Popup 自带的 `visibleChanged`，`afterClose`（退场动画结束）
//     在 QML 侧没有公开信号；`onClickOutSide` / `onEscKeyDown` 是继承来的
//     `clickedOutside` / `escKeyDown` 两个信号。
//   · `.semi-popover-title { padding: 8; border-bottom: 1px solid }` 那条 scss **没有对应的 prop**：
//     PopoverProps 里压根没有 title，组件也从没渲染这个类名（渲染它的是 Popconfirm，
//     用的是 `.semi-popconfirm-title`）。上一版本地加的 `title` 属性因此撤掉 ——
//     要标题就自己写进子项，官方就是这么排的。
//   · **那条环在 `showArrow: false` 时会被子项盖住**（2026-10-18 cocoa 像素复核，
//     `tests/tmp_popover_shot.qml` + `tests/tmp_popover_shot_measure.py`）：官方的环是
//     `box-shadow: 0 0 1px`，画在盒子**外面**，内容再满也遮不着；本库那条是 background 的
//     1px 边框，画在盒子**里面**，而 `.semi-popover-with-arrow` 之外没有内边距 ⇒ 子项铺满
//     卡片时正好把它压掉（实测 plain 那一档：横切 100…220 全是子项的 bg-0 #16161a，
//     没有 #525358 那 1px；带三角那一档左右各 1px 都在）。差的是边界 1px，不改基座 ——
//     PopupBase 那条环被所有弹层共用（Dropdown / Select / Menu 都是 padding 0），
//     要挪到内容之上得整轮重验，另开一轮再说。
Tooltip {
    id: control

    // ---------------------------------------------------------------- PopoverProps
    /// 官方 style：写在浮层那一张卡上的内联样式。只有带颜色语义的键能落地，见文件头
    property var style: ({})
    /// 官方 arrowStyle：{ borderColor, backgroundColor, borderOpacity }，只管小三角那两条 path
    property var arrowStyle: ({})
    /// 官方 content 函数档的 initialFocusRef 口子：打开时把焦点交给这一项
    property Item initialFocus: null
    /// 官方 returnFocusOnClose（popover 档缺省 true）：Esc 关掉后焦点回 target
    property bool returnFocusOnClose: true

    // 官方两处都是 lodash `get(map, key, fallback)`：键不存在（或显式给了 null）才落回下一档。
    // 写成函数而不是绑定 —— `style` 是整个 map 被换掉的，键级回退逐条读才跟得上。
    function styleOf(key, fallback) {
        const v = control.style ? control.style[key] : undefined
        return v === undefined || v === null ? fallback : v
    }

    function arrowStyleOf(key, fallback) {
        const v = control.arrowStyle ? control.arrowStyle[key] : undefined
        return v === undefined || v === null ? control.styleOf(key, fallback) : v
    }

    // ---------------------------------------------------------------- 覆盖 Tooltip 的缺省值
    position: Enums.Bottom                    // strings 里 popover 的 'bottom'
    zIndex: 1030                              // numbers.DEFAULT_Z_INDEX（tooltip 1060）
    showArrow: false
    closeOnEsc: true
    disableFocusListener: true                // 只削 hover 档附带的那对 focus/blur
    // 官方 .semi-popover-wrapper 没有 max-width（240 那条只写在 .semi-tooltip-wrapper 上）
    maxWidth: Number.MAX_VALUE

    // showArrow 决定间距与内边距两档，两边都得跟着它走
    spacing: control.showArrow ? 10 : 4       // SPACING_WITH_ARROW / SPACING（借 Popup 的名字，见 Tooltip）
    padding: control.showArrow ? Theme.current.spacingBaseTight : 0   // .semi-popover-with-arrow 12

    // 字符串档那一层的皮肤：字号 14 / 行高 20 与 tooltip 同源（@include font-size-regular），
    // 差的是颜色与内边距 —— popover 的字取继承来的 text-0，内边距长在卡片上（label 自己不再留）
    labelColor: control.styleOf("color", Theme.current.colorText0)
    labelPaddingX: control.padding
    labelPaddingY: control.padding

    // 三角：popover 档 24×8、两条 path；带三角的最小尺寸竖档是 36（tooltip 34），
    // 横档与 arrowCross 两档同值（18），不用改
    arrowSize: 8                              // $height-popover_arrow（探出 = 8 − 1 补缝 = 7）
    arrowBase: 24                             // $width-popover_arrow
    arrowStroked: true                        // Arrow.tsx 的描边 path + 底色 path
    arrowMinHeight: 24 + 6 * 2                // popover 的 adjusted_offset-y = 6

    // 卡片、描边环、三角三条颜色各自独立（官方 scss 就是分三处声明的）
    fillColor: control.styleOf("backgroundColor", Theme.current.colorBg3)
    strokeColor: control.styleOf("borderColor", Theme.current.colorBorder)
    arrowStrokeColor: control.arrowStyleOf("borderColor", Theme.current.colorBorder)
    arrowFillColor: control.arrowStyleOf("backgroundColor", Theme.current.colorBg3)
    arrowBorderOpacity: control.arrowStyleOf("borderOpacity", 1)
    // @mixin shadow-elevated 就写在 `.semi-popover-wrapper` 上（tooltip 那一档没有 ⇒
    // Tooltip 把它关掉了，这里重新打开；那条 1px 环由 strokeColor 顶替，见基座注释）
    shadowEnabled: true

    // 卡片尺寸 = 「字符串档那条 label 的边框宽」与「子项自然宽 + 左右内边距」取大，
    // 再兜带三角时的最小尺寸（label.width 已含它自己的内边距，见 src/Tooltip.qml:204-209）
    implicitWidth: Math.max(Math.min(control.maxWidth,
        Math.max(control.labelWidth, control.bodyWidth + control.padding * 2)),
        control.showArrow ? control.arrowMinWidth : 0)
    implicitHeight: Math.max(control.labelHeight,
        control.bodyHeight + control.padding * 2,
        control.showArrow ? control.arrowMinHeight : 0)

    // ---------------------------------------------------------------- 焦点
    // 两条内部钩子都必须走 Connections，不能写成 `onVisibleChanged:` / `onEscKeyDown:`：
    // 信号处理器就是一枚属性，使用方在实例上挂同名的那一只，会把组件里这一份整个顶掉
    // （实测：宿主一旦写了 onEscKeyDown 计数，returnFocusOnClose 就再也不生效 ——
    // 开发期变异扫描打出来的那条存活就是这么来的）。Connections 是独立对象上的连接，
    // 与实例上的处理器并存，两边都收。
    //
    // 官方 setInitialFocus 挂在「portal 真正可见」那一拍（foundation.ts:390-397 →
    // index.tsx:566-573），对象是 content 函数档塞进 DOM 的 initialFocusRef。
    // 这里就对应 visible 变真那一拍。原来还多写了一次 `Qt.callLater` 晚一帧，理由是
    // 「那一刻卡片还没布局，forceActiveFocus 是空转」—— 这句已经证伪：摘掉晚一帧，offscreen
    // 与 cocoa 两套都全绿，连「内容由 Loader 现造、visible 变真时才出现」那一档
    // （test_initialFocusOnContentCreatedAtOpen）也照样拿到焦点 ⇒ 那一帧是重复守卫，删了。
    // visible 的闸门只留这一条（外层原本还有一道同样的判断，两道都在时摘掉任何一道都零红，
    // 已经把外层删了）。这一条本身在 Qt 这边观察不到：实测
    // （tests/tmp_popover_focus_probe.qml）motion 开着时 `Popup.visible` 要等退场动画跑完才变假
    // —— +1 帧 / +40ms 时 visible 仍是真、卡片项还活着；+160ms 才变假，那一刻整项已经隐了 ——
    // 所以「变假」那一拍只剩「对不可见的项试一次」这个分支，Qt 本来就拒绝 ⇒ 摘掉它是等价变异
    // （P36 登记在这）。留着是因为官方那一步本来就只有「变真」这一条路，写清楚比赌 Qt 的行为省事；
    // 真正的中间态（动画进行中不许把焦点抢回卡片）由 test_closingTransitionDoesNotRegrabFocus 钉住。
    //
    // Esc 这一路官方是 focusTrigger() 在前、hide() 在后（foundation.ts:1318-1327），
    // 顺序要保住：hover / focus 档下「先回焦点」会让 target 的显示信号先来一次，
    // 而紧随其后的 hideNow 会把那一次待显示定时器停掉（Tooltip 里同一只 hideTimer）。
    // custom 档两边都不做（`returnFocusOnClose && trigger !== 'custom'` 与
    // `if (trigger !== 'custom') hide()` 那两句）。
    Connections {
        id: popBehavior

        target: control

        function onVisibleChanged() {
            if (control.visible && control.initialFocus)
                control.initialFocus.forceActiveFocus()
        }

        function onEscKeyDown() {
            if (!control.returnFocusOnClose || control.customMode || !control.target)
                return;
            control.target.forceActiveFocus()
        }
    }
}
