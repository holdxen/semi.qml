import QtQuick
import QtQuick.Controls as C
import QtQuick.Effects
import QtQuick.Shapes

// 弹层基座。所有浮层组件（Tooltip / Popover / Dropdown / Select）都建在它上面。
//
// 定位、自动翻转、点外关闭、Esc 关闭这些交给 QtQuick.Controls 的 Popup ——
// 外观（底色、描边、圆角、阴影、箭头）全部自绘，不吃 Controls 的样式。
//
//     PopupBase {
//         anchor: someButton
//         placement: Enums.Bottom
//         visible: true
//         Text { text: "内容" }
//     }
C.Popup {
    id: control

    property Item anchor: null
    property int placement: Enums.Bottom
    property real gap: 8                    // 与锚点的间距
    property bool autoFlip: true            // 空间不足时翻到对面
    property bool showArrow: false
    // 那颗三角是官方那两张 SVG 的**内凹**形状（不是直边三角）：
    //   · `arrowSize` = 官方盒子里「探出方向」那条边 —— tooltip 7（`$height-tooltip_arrow`）、
    //     popover 8（`$height-popover_arrow`，`constants.ts` 的 `ARROW_BOUNDING.height`）
    //   · `arrowBase` = 沿卡片那条边铺开的宽 —— 两支都是 24（`$width-tooltip_arrow`）
    //   · `arrowOverlap` = 1（`$spacing-tooltip_arrow_offset-x` / `-y`，「渲染会有缝隙，所以加个偏移量」）
    //     ⇒ 实际探出 = arrowSize − 1（tooltip 6、popover 7），另 1px 压在卡片边里补缝
    //   · `arrowStroked` = 官方 popover 的 `Arrow.tsx` 是**两条 path**（先描边色再底色，描边那条整体
    //     下移 0.5 让出 1px 边线），tooltip 的 `TriangleArrow.tsx` 只有一条 `currentColor`
    property real arrowSize: 8
    property real arrowBase: 24
    property real arrowOverlap: 1
    property bool arrowStroked: true

    // 小三角沿卡片那条边的中心位置（从左边 / 上边算起）。NaN = 居中，也就是
    // Popover / Dropdown / Menu 一直以来的样子。Tooltip 的角落方位要把三角放在
    // 离边 18px 的地方（$spacing-tooltip_arrow_adjusted_offset-x 6 + 半个箭头宽 12），
    // 这样卡片贴边对齐时三角仍然指得准（semi-foundation/tooltip/arrow.scss）。
    property real arrowCenterX: NaN
    property real arrowCenterY: NaN

    // 角落方位（topLeft / topRight / …）时，卡片沿交叉轴平移，让放在
    // arrowCenterX/Y 处的那颗三角正好指到目标的中心 —— 官方 arrowPointAtCenter
    // （foundation.ts:446 的 pointAtCenter 与 :505-597 各 case）。缺省 false，
    // 保持「卡片边与目标边对齐」的老行为。
    property bool pointAtCenter: false

    // 判定「放得下」时额外让出来的余量（官方 margin，只参与翻面判定、
    // 不进最终 left/top，见 foundation.ts:887-890 与 :935-938）。缺省 0 = 不改变任何行为。
    property real fitMargin: 0

    // 挂到窗口的 Overlay 层（与 Modal / ImageView 预览同一做法）。
    // 不这么做的话 parent 就是声明处的触发器，place() 里 `parent.width/height`
    // 拿到的是触发器自己的尺寸 —— 翻转判断整个失真，夹紧还会把弹层推回盖住触发器。
    parent: C.Overlay.overlay

    property color fillColor: Theme.current.colorBg2
    property color strokeColor: Theme.current.colorBorder
    // 官方 popover 那颗三角的两条 path 各取自己的颜色，和卡片是**三条独立的线**：
    //   · 描边那条 = `arrowStyle.borderColor ?? popStyle.borderColor ?? $color-popover-arrow-border`
    //     （popover/Arrow.tsx:22-34 + compiled css `.semi-popover-icon-arrow path:nth-child(1)`，
    //     该档令牌就是 var(--semi-color-border)）；
    //   · 底色那条 = `arrowStyle.backgroundColor ?? popStyle.backgroundColor ?? $color-popover-arrow-bg`
    //     （同文件的 nth-child(2)，令牌也是 var(--semi-color-bg-3)，与卡片同色）；
    //   · 卡片自己 `.semi-popover-wrapper` 在 scss 里**没有 border 规则**，那条 1px 是
    //     shadow-elevated 第一层（0 0 1px）画出来的环 —— 本库由 strokeColor 顶替（坑 34），
    //     与 Dropdown 同一口径。
    // 三个口子分开声明，`arrowStyle` 才能只改三角、不动卡片。缺省两条都跟着卡片，
    // 老使用者（Dropdown / Select / Menu…）一个像素都不变。
    property color arrowStrokeColor: strokeColor
    property color arrowFillColor: fillColor
    // Arrow.tsx 给描边那条 path 挂 `opacity: borderOpacity`（不传就是 1，CSS 也没有别的规则动它）
    property real arrowBorderOpacity: 1
    property real radius: Theme.current.radiusMedium

    // Semi 的弹层阴影 @mixin shadow-elevated（semi-theme-default/scss/global.scss）：
    //   浅色  0 0 1px rgba(0,0,0,.3), 0 4px 14px rgba(0,0,0,.1)
    //   深色  inset 0 0 0 1px rgba(255,255,255,.1), 0 4px 14px rgba(0,0,0,.25)
    // 用在 dropdown / popover / toast / notification / sideSheet / modal 上，
    // **Tooltip 没有**（semi-foundation/tooltip/tooltip.scss 里不含阴影）。
    //
    // MultiEffect 一次只能出一层投影（已知坑 34），所以 Semi 拿来做描边的
    // 那层 1px 阴影由 surface 的真实 border 顶替 —— 有意偏离，观感等价。
    //
    // alpha 直接取 CSS 的 .1，但 **blurMax 不能照抄 CSS 的 blur radius**：Qt 的 blurMax 是卷积核
    // 半径（约 3~4σ），CSS 的是 2σ。换算系数 2.3 是拿 Switch 圆钮定下来的（CSS 6px → blurMax 14）。
    // 这里的 32 / .1 是扫出来的：拿官方 `.semi-dropdown-wrapper`（semi.css:8383 那条
    // box-shadow: var(--semi-shadow-elevated)）在浏览器里渲一张 2x 图，与 grabToImage 的同尺寸图
    // 比四条边外侧 2~26 设备像素的最暗亮度 —— 平均绝对差 0.47/255（旧的 18/.2 是 1.58，
    // 外溢总暗度只有官方的**一半**，看着就是「阴影比官方淡」）。深色同理扫到 CSS 的 .25
    // （原来 0.5 是官方的 2.5 倍暗，总暗度 +152%）。
    // 剩下 -12% 的总暗度差来自那条 1px 环：官方在盒外，我们的描边在盒内。
    property bool shadowEnabled: true
    property color shadowColor: Theme.mode === Theme.Dark
        ? Qt.rgba(0, 0, 0, 0.25)
        : Qt.rgba(0, 0, 0, 0.1)
    property real shadowBlurMax: 32
    property real shadowVerticalOffset: 4

    // 实际生效的方位（自动翻转后可能和 placement 不同）
    property int effectivePlacement: control.placement

    // 是否播进出场动画。官方 Tooltip / Popover / Dropdown 共用同一个 `motion`
    // （semi-ui/tooltip/index.tsx:172 defaultProps motion: true；:780 `motion && isPositionUpdated`
    // 决定要不要挂 CSS 的 zoomIn/zoomOut class），弹层都走 tooltip 那一套动效，
    // 所以开关放在基座。false 时四条动画时长都归 0，等价于「直接显示」。
    property bool motion: true

    // 打开态。**不能用 visible 做切换判断** —— 退场动画期间 visible 还是 true，
    // 那段时间点触发器会走到 close() 分支（对已关的弹层再关一次，什么也没发生），
    // 表现为「要点两次才能重新打开」。
    //
    // 父类其实有个 Popup.opened，但实测这个 Qt 版本里 open() 之后它仍是 false
    // （visible 已经 true），不可靠；自己再声明同名属性会撞 FINAL 属性、
    // 整个类型创建不出来（坑 25 那类）。所以换个名字，由 aboutToShow /
    // aboutToHide 驱动 —— 两者都在动画之前发，且 open()/close()/closePolicy
    // 任一路径都会发。
    property bool isOpen: false

    function toggle() {
        if (control.isOpen)
            control.close();
        else
            control.open();
    }

    // 内容列的间距。默认 8（Semi 多数弹层的小节间距），
    // 自带内边距的内容（如 Select 的搜索区）设成 0 自己排，否则会叠成 16。
    property real contentSpacing: Theme.current.spacingTight

    // 点到弹层外面就收。Controls 这条**不认 anchor** —— 点触发器本身也会先被它收掉，
    // 需要「触发器例外」的组件（TreeSelect）把它关掉、自己按落点判断。
    property bool dismissOnOutsidePress: true

    // 暴露给子类：内容容器的自然尺寸
    readonly property real bodyWidth: contentItem.implicitWidth
    readonly property real bodyHeight: contentItem.implicitHeight

    default property alias content: contentItem.data

    padding: Theme.current.spacingBaseTight
    closePolicy: C.Popup.CloseOnEscape
        | (control.dismissOnOutsidePress ? C.Popup.CloseOnPressOutside : C.Popup.NoAutoClose)

    // ---- 进出场动画 ----
    // Semi 的弹层统一走 tooltip 基座的 zoomIn / zoomOut
    // （semi-foundation/tooltip/tooltip.scss + animation.scss）：
    //   时长 进出各 100ms，曲线 cubic-bezier(0.215, 0.61, 0.355, 1)
    //   zoomIn:  scale 0.8→1 走满全程，opacity 0→1 只在前 50%
    //   zoomOut: scale 1→0.8 走满全程，opacity 1→0 只在前 60%
    // 拆成两条不同 duration 的动画来还原 keyframes 的分段。
    transformOrigin: control.originForPlacement

    readonly property int originForPlacement: {
        switch (effectivePlacement) {
        case Enums.Top: case Enums.TopLeft: case Enums.TopRight:
            return Item.Bottom;                       // 向上长：锚点在底边
        case Enums.Left: case Enums.LeftTop: case Enums.LeftBottom:
            return Item.Right;
        case Enums.Right: case Enums.RightTop: case Enums.RightBottom:
            return Item.Left;
        default:
            return Item.Top;                          // 向下长：锚点在顶边
        }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: control.motion ? 50 : 0
                // easeOutCubic：Qt 的 Easing.BezierSpline 实测退化为线性，改用形状最接近的内置曲线
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.8
                to: 1
                duration: control.motion ? 100 : 0
                // easeOutCubic：Qt 的 Easing.BezierSpline 实测退化为线性，改用形状最接近的内置曲线
                easing.type: Easing.OutCubic
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: control.motion ? 60 : 0
                // easeOutCubic：Qt 的 Easing.BezierSpline 实测退化为线性，改用形状最接近的内置曲线
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1
                to: 0.8
                duration: control.motion ? 100 : 0
                // easeOutCubic：Qt 的 Easing.BezierSpline 实测退化为线性，改用形状最接近的内置曲线
                easing.type: Easing.OutCubic
            }
        }
    }

    implicitWidth: contentItem.implicitWidth + control.padding * 2
    implicitHeight: contentItem.implicitHeight + control.padding * 2

    // aboutToShow 这一拍弹层尺寸可能还是 0（内容尚未布局），place() 会误判
    // 「放得下」从而不翻转；等尺寸稳定后必须再定位一次。
    onAboutToShow: {
        control.isOpen = true;
        control.reposition();
    }
    onAboutToHide: control.isOpen = false
    onAnchorChanged: control.reposition()
    onPlacementChanged: control.reposition()

    // 内容尺寸变化（选项数变、远程数据到）时重新定位
    onHeightChanged: if (control.visible) control.reposition()
    onWidthChanged: if (control.visible) control.reposition()

    // 弹层挂 Overlay 层后脱离了内容坐标系，页面滚动时锚点自身 x/y 并不变
    // （变的是祖先 Flickable 的 contentY），所以只能盯「锚点在父坐标系里的位置」。
    // 本想用 anchor 的 SceneTransform 附加属性做声明式绑定，但附加属性在运行时
    // JS 表达式里取不到（`anchor.SceneTransform.x` 只会拿到 undefined，已知坑 23
    // 的一般情形），只能轮询。开销很小：仅弹层可见时跑，每帧一次 mapToItem，
    // 位置没动就不重算。
    //
    // 盯的是**整个矩形**（四条边），不是左上角：锚点自己长高变宽时 top/left 一动不动，
    // Select 多选标签换行把触发器撑高就是这一型 —— 原先只比 top/left，弹层会停在旧的
    // 下边界上直接盖住锚点。
    property real _lastAnchorTop: NaN
    property real _lastAnchorLeft: NaN
    property real _lastAnchorBottom: NaN
    property real _lastAnchorRight: NaN

    FrameAnimation {
        running: control.visible && control.anchor !== null
        onTriggered: {
            const r = control.anchorRect();
            if (!r)
                return;
            if (r.top !== control._lastAnchorTop || r.left !== control._lastAnchorLeft
                || r.bottom !== control._lastAnchorBottom || r.right !== control._lastAnchorRight) {
                control._lastAnchorTop = r.top;
                control._lastAnchorLeft = r.left;
                control._lastAnchorBottom = r.bottom;
                control._lastAnchorRight = r.right;
                control.reposition();
            }
        }
    }

    function isVertical(p) {
        return p === Enums.Top || p === Enums.TopLeft || p === Enums.TopRight
            || p === Enums.Bottom || p === Enums.BottomLeft || p === Enums.BottomRight;
    }

    function isFlipped(p) {
        switch (p) {
        case Enums.Top: case Enums.TopLeft: case Enums.TopRight:
            return Enums.Bottom;
        case Enums.Bottom: case Enums.BottomLeft: case Enums.BottomRight:
            return Enums.Top;
        case Enums.Left: case Enums.LeftTop: case Enums.LeftBottom:
            return Enums.Right;
        default:
            return Enums.Left;
        }
    }

    // 按方位摆放；返回是否完整落在窗口内
    function place(p) {
        const parent = control.parent;
        if (!control.anchor || !parent)
            return true;

        const origin = control.anchor.mapToItem(parent, 0, 0);
        const aw = control.anchor.width;
        const ah = control.anchor.height;
        const pw = control.width;
        const ph = control.height;
        const gap = control.gap;

        let x = 0;
        let y = 0;

        // 角落方位在 pointAtCenter 打开时改成「三角指中心」的算法：卡片沿交叉轴平移，
        // 让摆在 arrowCenterX/Y 的三角落在目标中心上。两份坐标同一个参照系 —— 中心值一律
        // 从卡片的**左 / 上边**量起（右 / 下角落方位给的是 width − 18 / height − 18），
        // 所以八个方位都写成 middle − ac，没有「middle + ac − size」那一支。
        // 没给 arrowCenter（NaN）就退回边缘对齐的老行为。
        const acx = control.pointAtCenter && !isNaN(control.arrowCenterX) ? control.arrowCenterX : NaN;
        const acy = control.pointAtCenter && !isNaN(control.arrowCenterY) ? control.arrowCenterY : NaN;
        const middleX = origin.x + aw / 2;
        const middleY = origin.y + ah / 2;

        switch (p) {
        case Enums.Top:
            x = origin.x + aw / 2 - pw / 2; y = origin.y - ph - gap; break;
        case Enums.TopLeft:
            x = isNaN(acx) ? origin.x : middleX - acx; y = origin.y - ph - gap; break;
        case Enums.TopRight:
            x = isNaN(acx) ? origin.x + aw - pw : middleX - acx; y = origin.y - ph - gap; break;

        case Enums.Bottom:
            x = origin.x + aw / 2 - pw / 2; y = origin.y + ah + gap; break;
        case Enums.BottomLeft:
            x = isNaN(acx) ? origin.x : middleX - acx; y = origin.y + ah + gap; break;
        case Enums.BottomRight:
            x = isNaN(acx) ? origin.x + aw - pw : middleX - acx; y = origin.y + ah + gap; break;

        case Enums.Left:
            x = origin.x - pw - gap; y = origin.y + ah / 2 - ph / 2; break;
        case Enums.LeftTop:
            x = origin.x - pw - gap; y = isNaN(acy) ? origin.y : middleY - acy; break;
        case Enums.LeftBottom:
            x = origin.x - pw - gap; y = isNaN(acy) ? origin.y + ah - ph : middleY - acy; break;

        case Enums.Right:
            x = origin.x + aw + gap; y = origin.y + ah / 2 - ph / 2; break;
        case Enums.RightTop:
            x = origin.x + aw + gap; y = isNaN(acy) ? origin.y : middleY - acy; break;
        case Enums.RightBottom:
            x = origin.x + aw + gap; y = isNaN(acy) ? origin.y + ah - ph : middleY - acy; break;

        default:
            break;
        }

        control.x = Math.round(x);
        control.y = Math.round(y);

        const maxX = parent.width - pw + control.fitMargin;
        const maxY = parent.height - ph + control.fitMargin;
        return control.x >= -control.fitMargin && control.y >= -control.fitMargin
            && control.x <= maxX && control.y <= maxY;
    }

    // anchor 在 popup parent 坐标系里的矩形
    function anchorRect() {
        const parent = control.parent;
        if (!control.anchor || !parent)
            return null;
        const origin = control.anchor.mapToItem(parent, 0, 0);
        return { top: origin.y,
                 bottom: origin.y + control.anchor.height,
                 left: origin.x,
                 right: origin.x + control.anchor.width };
    }

    // 对齐 Semi 的 autoAdjustOverflow（semi-foundation/tooltip/foundation.ts
    // adjustPosIfNeed）：弹层**永远不遮挡锚点**。
    //
    // 原先最后一步把 x/y 一起夹进窗口，y 会被夹到锚点的 [top, bottom] 区间里 ——
    // 窗口下方空间不够时，下拉面板直接盖住 Select 自己。
    // 现在主轴（弹层展开的方向）只做「避开锚点」，允许溢出窗口被裁；
    // 交叉轴才夹紧到窗口内。
    function keepClearOfAnchor() {
        const parent = control.parent;
        const a = control.anchorRect();
        if (!parent || !a)
            return;

        const gap = control.gap;
        const p = control.effectivePlacement;

        if (control.isVertical(p)) {
            const below = p === Enums.Bottom || p === Enums.BottomLeft || p === Enums.BottomRight;
            if (below)
                control.y = Math.max(control.y, a.bottom + gap);
            else
                control.y = Math.min(control.y, a.top - gap - control.height);
            control.x = Math.max(0, Math.min(control.x, parent.width - control.width));
        } else {
            const right = p === Enums.Right || p === Enums.RightTop || p === Enums.RightBottom;
            if (right)
                control.x = Math.max(control.x, a.right + gap);
            else
                control.x = Math.min(control.x, a.left - gap - control.width);
            control.y = Math.max(0, Math.min(control.y, parent.height - control.height));
        }
    }

    function reposition() {
        if (!control.anchor)
            return;

        const wanted = control.placement;
        control.effectivePlacement = wanted;

        if (!control.place(wanted) && control.autoFlip) {
            const flipped = control.isFlipped(wanted);
            // 反向放得下才翻（place 的返回值即「完整落在窗口内」），
            // 与 Semi 的 isReverse（原空间不足 && 反向空间足够）一致
            if (control.place(flipped))
                control.effectivePlacement = flipped;
            else
                control.place(wanted);   // 两边都放不下：保持原方位，宁可溢出
        }

        control.keepClearOfAnchor();
    }

    // 箭头的盒子与摆放。本体与阴影源共用这一份算法，避免两处各写一遍。
    // 横档（top / bottom 那一族）盒子 = arrowBase × arrowSize，竖档（left / right 那一族）反过来。
    readonly property real arrowBoxW: isVertical(effectivePlacement) ? arrowBase : arrowSize
    readonly property real arrowBoxH: isVertical(effectivePlacement) ? arrowSize : arrowBase

    // 官方两张 SVG 的 path，缺省画成「底边贴在 x=0 / y=0、尖朝 +y（横档）或 +x（竖档）」，
    // 反方向交给下面的 Scale 翻 —— path 里有 S（平滑三次）命令，手改坐标会把镜像控制点算错。
    //   · 横档 = TriangleArrow.tsx 的 24×7（与 popover/Arrow.tsx 的底色那条同形）
    //   · 竖档 = TriangleArrowVertical.tsx 的 7×24
    readonly property string arrowFillPath: isVertical(effectivePlacement)
        ? "M24 0V1C20 1 18.5 2 16.5 4C14.5 6 14 7 12 7C10 7 9.5 6 7.5 4C5.5 2 4 1 0 1V0H24Z"
        : "M0 0L1 0C1 4 2 5.5 4 7.5S7 10 7 12S6 14.5 4 16.5S1 20 1 24L0 24L0 0z"
    // popover 档多一条压在底下的描边 path：整体比底色那条外扩 1px（尖端到 8），
    // 于是两条叠起来就是「三角带 1px 边线」（`Arrow.tsx` 的两个 path）
    readonly property string arrowBorderPath: isVertical(effectivePlacement)
        ? "M0 0.5L0 1.5C4 1.5 5.5 3 7.5 5S10 8 12 8S14.5 7 16.5 5S20 1.5 24 1.5L24 0.5L0 0.5z"
        : "M0.5 0L1.5 0C1.5 4 3 5.5 5 7.5S8 10 8 12S7 14.5 5 16.5S1.5 20 1.5 24L0.5 24L0.5 0z"

    // 尖朝哪一侧：Top / Left 用缺省方向，Bottom / Right 翻一次
    readonly property bool arrowFlippedY: isVertical(effectivePlacement)
        && (effectivePlacement === Enums.Bottom || effectivePlacement === Enums.BottomLeft
            || effectivePlacement === Enums.BottomRight)
    readonly property bool arrowFlippedX: !isVertical(effectivePlacement)
        && (effectivePlacement === Enums.Right || effectivePlacement === Enums.RightTop
            || effectivePlacement === Enums.RightBottom)

    function arrowX(aw, bw) {
        switch (effectivePlacement) {
        case Enums.Left: case Enums.LeftTop: case Enums.LeftBottom:
            // 卡片在目标左边 ⇒ 三角贴在卡片右边线上：1px 压在边里补缝（arrowOverlap），
            // 剩下的 arrowSize − 1 探出去（官方 bottom: -$height + $offset 那一档）
            return bw - control.arrowOverlap;
        case Enums.Right: case Enums.RightTop: case Enums.RightBottom:
            return -(aw - control.arrowOverlap);
        default:
            // 上下两支的三角沿水平边走；给了 arrowCenterX 就按它摆（官方角落方位的 18px）
            return isNaN(control.arrowCenterX) ? (bw - aw) / 2 : control.arrowCenterX - aw / 2;
        }
    }

    function arrowY(ah, bh) {
        switch (effectivePlacement) {
        case Enums.Top: case Enums.TopLeft: case Enums.TopRight:
            return bh - control.arrowOverlap;
        case Enums.Bottom: case Enums.BottomLeft: case Enums.BottomRight:
            return -(ah - control.arrowOverlap);
        default:
            // 左右两支的三角沿垂直边走
            return isNaN(control.arrowCenterY) ? (bh - ah) / 2 : control.arrowCenterY - ah / 2;
        }
    }

    // 自绘背景（含可选的箭头）
    background: Item {

        // 阴影源：只借它的 alpha 轮廓。
        // 源保持 visible:false，MultiEffect 照样取到形状（坑 9 已更正）。
        // 但效果项**也会把源画一遍**（autoPadding 下边缘会露出 1~2px），
        // 所以源的填充必须与本体同色 —— 露边才看不出来。
        // 阴影本身的颜色由 shadowColor 决定，与源颜色无关。
        Item {
            id: shadowSource

            anchors.fill: parent
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: control.radius
                color: control.fillColor
            }

            // 箭头也进源 —— Semi 的箭头有独立投影，只给本体画阴影
            // 会在箭头那一圈留下没有投影的缺口。源只要轮廓，所以描边那条（外沿）优先
            Item {
                id: shadowArrow

                width: control.arrowBoxW
                height: control.arrowBoxH
                x: control.arrowX(width, parent.width)
                y: control.arrowY(height, parent.height)
                visible: control.showArrow
                // 方向靠 Scale 翻（path 里有 S 平滑命令，手改坐标会把镜像控制点算错）。
                // 列表里的 Scale 默认 origin 是 (0,0)，必须点名中心，否则整颗三角飞出去。
                transform: [
                    Scale {
                        xScale: control.arrowFlippedX ? -1 : 1
                        origin: Qt.point(shadowArrow.width / 2, shadowArrow.height / 2)
                    },
                    Scale {
                        yScale: control.arrowFlippedY ? -1 : 1
                        origin: Qt.point(shadowArrow.width / 2, shadowArrow.height / 2)
                    }
                ]

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        // 只要轮廓，但露边那一两像素得跟本体同色 —— 描边档外面那圈是描边色
                        fillColor: control.arrowStroked ? control.arrowStrokeColor : control.arrowFillColor
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: control.arrowStroked ? control.arrowBorderPath : control.arrowFillPath
                        }
                    }
                }
            }
        }

        MultiEffect {
            source: shadowSource
            anchors.fill: shadowSource
            visible: control.shadowEnabled
            shadowEnabled: true
            shadowColor: control.shadowColor
            shadowVerticalOffset: control.shadowVerticalOffset
            shadowBlur: 1.0
            blurMax: control.shadowBlurMax
        }

        Rectangle {
            id: surface

            anchors.fill: parent
            color: control.fillColor
            border.width: 1
            border.color: control.strokeColor
            radius: control.radius
        }

        // 那颗内凹三角，压在朝向锚点的那条边上。popover 档是「描边 path 打底 + 底色 path 盖上」
        // 两条叠出来的 1px 边线（`popover/Arrow.tsx`），tooltip 档只有底色那一条。
        Item {
            id: arrow

            objectName: "popupArrow"
            width: control.arrowBoxW
            height: control.arrowBoxH
            x: control.arrowX(width, surface.width)
            y: control.arrowY(height, surface.height)
            visible: control.showArrow
            transform: [
                Scale {
                    xScale: control.arrowFlippedX ? -1 : 1
                    origin: Qt.point(arrow.width / 2, arrow.height / 2)
                },
                Scale {
                    yScale: control.arrowFlippedY ? -1 : 1
                    origin: Qt.point(arrow.width / 2, arrow.height / 2)
                }
            ]

            Shape {
                anchors.fill: parent
                objectName: "popupArrowBorderShape"
                visible: control.arrowStroked
                opacity: control.arrowBorderOpacity
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    objectName: "popupArrowBorderPath"
                    fillColor: control.arrowStrokeColor
                    strokeColor: "transparent"
                    strokeWidth: 0

                    PathSvg {
                        path: control.arrowBorderPath
                    }
                }
            }

            Shape {
                anchors.fill: parent
                objectName: "popupArrowFillShape"
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    objectName: "popupArrowFillPath"
                    fillColor: control.arrowFillColor
                    strokeColor: "transparent"
                    strokeWidth: 0

                    PathSvg {
                        path: control.arrowFillPath
                    }
                }
            }
        }
    }

    // 内容容器用 Column：弹层内容基本都是纵向排列的，
    // 这样组件（如 Popover）不用自己再包一层，也避免重复声明 default property。
    contentItem: Column {
        id: contentItem

        spacing: control.contentSpacing
    }
}
