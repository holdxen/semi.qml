pragma ComponentBehavior: Bound

import QtQuick

// 轮播的指示器。官方 `packages/semi-ui/carousel/CarouselIndicator.tsx`
// （propTypes :12-22、handleIndicatorClick / handleIndicatorHover :28-40、
// renderIndicatorContent :42-62、render :64-77）+ `semi-foundation/carousel/carousel.scss`
// 的 `-indicator` 那一大段与 variables.scss。
//
//     CarouselIndicator {
//         total: 3
//         activeIndex: 1
//         type: "columnar"
//         onIndicatorChanged: control.goTo(index)
//     }
//
// 官方这一层只有「一排 `<span>`」+ 三种 type 的尺寸规则，能拆成四条：
//   · 容器 `-indicator` 是 `display: flex; align-items: flex-end` ⇒ **每一格底对齐**，
//     柱状档选中时变高就是往上长（不是往下）。
//   · 三型尺寸（variables.scss）：dot 8 / 12 见方、圆角 50%、水平间距 8；
//     columnar 宽 4 / 6、高 12→20 / 20→28、间距 4；line **容器写死 240 宽**、
//     每格 `flex: 1`、高 4 / 6、间距 4。
//   · 三主题配色：dark 是黑（默认 .5 / 悬浮 .7 / 选中 1），primary 是 `--semi-blue-6`
//     （.4 / .7 / 1），light 是白（.4 / .7 / 1）。
//   · `trigger` 两档：`click` 只认 onClick、`hover` 只认 onMouseEnter（:28-40 那两个判断），
//     所以 trigger 是 click 时**划过不该切页**。
//
// 两处「看着像规则其实没有」的地方，端口照实现、不照字面：
//   · scss 给指示器写了 `transition: background-color …`，但那三个令牌取的是
//     `$transition_duration-carousel_indicator-bg: var(--semi-transition_delay-none)` ⇒
//     **时长是 delay 那个 0ms**（键名抄串了），浏览器里换色是瞬时的 ⇒ 端口不做颜色过渡。
//   · `constants.ts` 里的 `CAROUSEL_INDICATOR_INACTIVE` / `_ACTIVE` 两个类名，
//     `CarouselIndicator.tsx` 只加了 `-item-active`，`-inactive` 从头到尾没被用过。
//
// 端口差异：官方那排 `<span>` 是 flex item，端口按「等宽 + 固定间距」自己摆位置
// （Qt 6.11 的 Repeater 自己也是个 Item，塞进 Row 会多出一格间距）；
// `className` / `style` 收了不产出可见差异；`position` 官方是这一层自己贴
// `-indicator-left/center/right` 类、由 scss 绝对定位，端口把那三条规则搬到
// Carousel 里给这一块算 x/y（值一样：距边 32、center 水平居中）。
// 两处官方自己的对不上：propTypes 声明的是 `activeKey`、代码读的却是 `activeIndex`
// （CarouselIndicator.tsx:13 对 :44）⇒ `activeKey` 是死键，端口不做；
// `CarouselIndicatorProps` 里的 `defaultActiveIndex`（interface.ts:37）从头到尾没人读。
Item {
    id: control

    // ---- 官方 CarouselIndicatorProps（interface.ts:34-46）----
    property int activeIndex: 0
    property string className: ""              // 死 prop
    property string position: "center"
    property string size: "small"              // small | medium
    property var style: undefined              // 死 prop
    property string theme: "light"             // dark | primary | light
    property int total: 0
    property string trigger: "click"           // click | hover
    property string type: "dot"                // dot | line | columnar

    signal indicatorChanged(int index)
    signal indicatorEntered(int index)

    readonly property bool isColumnar: control.type === "columnar"
    readonly property bool isDot: control.type === "dot"
    readonly property bool isLine: control.type === "line"
    readonly property bool small: control.size === "small"

    // ---- 尺寸（variables.scss）----
    readonly property real dotSide: control.small ? 8 : 12
    readonly property real columnarWidth: control.small ? 4 : 6
    readonly property real columnarHeight: control.small ? 12 : 20
    readonly property real columnarActiveHeight: control.small ? 20 : 28
    readonly property real lineHeight: control.small ? 4 : 6
    readonly property real lineTotalWidth: 240                                   // $width-carousel_indicator_line
    readonly property real gap: control.isDot ? 8 : 4
    readonly property real baseAlpha: control.theme === "dark" ? 0.5 : 0.4
    readonly property real hoverAlpha: 0.7
    readonly property real itemWidth: control.isLine
        ? Math.max(0, (control.lineTotalWidth - control.gap * (control.total - 1)) / control.total)
        : (control.isColumnar ? control.columnarWidth : control.dotSide)
    readonly property real rowHeight: control.isColumnar ? control.columnarActiveHeight
        : (control.isLine ? control.lineHeight : control.dotSide)

    implicitWidth: control.total > 0
        ? control.total * control.itemWidth + control.gap * (control.total - 1) : 0
    implicitHeight: control.rowHeight

    onTotalChanged: control.layoutItems()
    onWidthChanged: control.layoutItems()
    onItemWidthChanged: control.layoutItems()
    Component.onCompleted: control.layoutItems()

    property var itemNodes: []

    /// 一格的高（柱状档选中态变高，其余两型恒定）—— 布局与委托都走这一个函数，
    /// 免得去读委托自己的 height（那是异步落下来的）
    function cellHeight(index) {
        if (control.isColumnar)
            return index === control.activeIndex ? control.columnarActiveHeight : control.columnarHeight;
        return control.isLine ? control.lineHeight : control.dotSide;
    }

    function layoutItems() {
        const nodes = [];
        for (let i = 0; i < row.children.length; ++i) {
            const node = row.children[i];
            if (node === null || node === undefined || node instanceof Repeater)
                continue;
            nodes.push(node);
        }
        control.itemNodes = nodes;
        for (let i = 0; i < nodes.length; ++i)
            nodes[i].x = i * (control.itemWidth + control.gap);
    }

    // 官方三主题的基色：dark=黑、primary=`--semi-blue-6`、light=白
    function themeBase() {
        if (control.theme === "dark")
            return Theme.current.colorBlack;
        if (control.theme === "primary")
            return Theme.current.blue[6];
        return Theme.current.colorWhite;
    }

    function themeColor(alpha) {
        const base = control.themeBase();
        return Qt.rgba(base.r, base.g, base.b, alpha);
    }

    Item {
        id: row

        objectName: "carouselIndicatorRow"

        width: control.implicitWidth
        height: control.rowHeight

        Repeater {
            model: control.total

            delegate: Rectangle {
                id: cell

                required property int index

                objectName: "carouselIndicatorItem" + index

                readonly property bool current: cell.index === control.activeIndex
                readonly property bool hovered: cellHover.hovered
                readonly property bool pressed: cellTap.pressed

                y: control.rowHeight - control.cellHeight(cell.index)
                width: control.itemWidth
                height: control.cellHeight(cell.index)
                radius: control.isDot ? width / 2 : 0
                // 官方那四条规则权重相同（都是「类型类 + 状态类」两个选择器），按
                // 默认 → 选中 → :hover → :active 的源码顺序排 ⇒ **悬浮会盖住选中**
                // （浏览器实测：划过当前那一格它反而从 1 掉回 .7），按下又盖回 1。
                // 不是端口偷懒的顺序，照官方渲染结果落。
                color: control.themeColor(cell.pressed ? 1
                    : (cell.hovered ? control.hoverAlpha
                        : (cell.current ? 1 : control.baseAlpha)))

                HoverHandler {
                    id: cellHover

                    onHoveredChanged: {
                        if (cellHover.hovered && control.trigger === "hover")
                            control.indicatorEntered(cell.index);
                    }
                }

                TapHandler {
                    id: cellTap

                    onTapped: {
                        if (control.trigger === "click")
                            control.indicatorChanged(cell.index);
                    }
                }
            }
        }
    }
}
