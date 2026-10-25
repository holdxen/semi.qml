pragma ComponentBehavior: Bound

import QtQuick

// 描述列表的条目。官方 `packages/semi-ui/descriptions/item.tsx`（DescriptionsItemProps :8-16、
// render :35-74）+ `semi-foundation/descriptions/{descriptions.scss,variables.scss}`。
//
// 这一个组件的 render 只有「两种 DOM × 两种 layout」四个组合，全在那 40 行里：
//   · `align === 'plain'` ⇒ 一个 `<td class="-item">`，里面 `-key` 那个 span **带冒号**
//     （`{itemKey}:`，:43），`-value` 左内边距 8（scss:75 只在 `-plain` 下给）。
//   · 其余三档（center / left / justify）⇒ 一对 `<th class="-item -item-th">` +
//     `<td class="-item -item-td" colSpan={span ? span * 2 - 1 : 1}>`，key **不带冒号**。
//   · `layout === 'horizontal'` 时外面那层 `<tr>` 整个不套（:72-73 直接返回单元格本身），
//     由 Descriptions 自己按 span 分组排成 `<tr>`。
//   · `hidden` 直接 `return null`（:38）。
//   · children 是函数就当 ReactNode 工厂调用（:46 那一处 `typeof children === 'function'`）。
//
// 度量（descriptions.scss + variables.scss）：
//   · 整块 `line-height: 20`；`-item { padding-bottom: 12 }`（$spacing-base-tight）。
//   · `-key`：字号 14 / 行高 20（@include font-size-regular）、`white-space: nowrap`、色 text-2；
//     `-value`：同字号同行高、色 text-0。
//   · 双行（`-double`）那一档 `-item` 的 padding 被重赋成 **0**（$…item_double-padding: 0），
//     于是那 12 的行距没了，改成 key 自己带 padding-bottom：small 0 / medium 4 / large 4；
//     item 右内边距 48 / 60 / 80；value 字重 600、字号 16 / 20 / 28（行高 22 / 28 / 40，
//     跟着 @include font-size-header-6/-4/-2 走）；key 字号 12 / 14 / 14（small 那档走
//     font-size-small ⇒ 行高 16，其余两档仍是 regular 的 20）。
//
// 端口与官方的差异（QML 没有 table，逐条）：
//   · 两列宽由宿主 Descriptions 算好后写进来（`cellWidth` / `keyColumnWidth`），本文件只管摆
//     自己这一格；`colSpan` 在端口是「槽数等分」，见 src/Descriptions.qml 头注释。
//   · `-key { white-space: nowrap }` 端口同样不许换行，但宽度不够时**截尾省略号** ——
//     浏览器是让那串字直接溢出到 td 那一格上，端口不照抄那个溢出。
//   · **`keyStyle` 的 width / textAlign 在官方只在 plain 那一档真的生效**：其余三档 `-key`
//     是 inline 的 span，CSS 忽略 width 与 text-align（只有 color 这类继承性的键到处都有效）。
//     端口照抄这一条 —— 所以官网「自定义 Key 样式」那节拿 `align="center"` 配
//     `{ width: 100, textAlign: 'right' }` 的 demo 其实没效果（详见坑 113）。
//   · `className` / `style` 官方写在外层 `<tr>` 上（:63 / :68），端口没有那一层 ⇒ 收了不产出
//     可见差异（与 Empty / Highlight 的 `style` 同一口径）。
Item {
    id: control

    // ---- 官方 DescriptionsItemProps（item.tsx:8-16）----
    /// 官方 itemKey（ReactNode）：字符串或 Component
    property var itemKey: undefined
    property bool hidden: false
    property string className: ""
    property var style: undefined
    /// 官方 keyStyle：color 到处有效，width / textAlign 只在 plain 档生效（见文件头）
    property var keyStyle: undefined
    /// 官方 span。0 与未给都按 1（`colSpan={span || 1}` / `span ? (span * 2) - 1 : 1`）
    property int span: 0
    /// 官方 `isNaN(lastSpan.span)` 那一步要分得开「没给」与「给了 0」：
    /// 给了 0 的末项**不补**，没给的才补。声明档默认按 span > 0 判。
    property bool spanExplicit: control.span > 0
    /// 子项档的宿主链接（官方是 context + children；端口反向收养）。
    /// 类型写死成 Descriptions 而不是 Item —— 不然 qmllint 看不到 itemNaturalChanged()。
    property Descriptions descriptionsHost: null
    /// 给宿主认名单用
    readonly property bool isDescriptionsItem: true
    /// data 档由宿主自己的 Repeater 造，不进取「声明式子项」那份名单
    property bool fromRepeater: false
    /// 官方 children 档：直接写子项
    default property alias content: valueRow.data
    /// 官方 data 档的 value：字符串 / Component / `() => ReactNode`
    property var value: undefined

    // ---- 宿主写进来的档位与几何（官方由 context + table 布局给）----
    property string hostAlign: "center"
    property bool hostRow: false
    property string hostSize: "medium"
    /// 这一格的总宽（plain 档是整个 td；其余档是 th + td 两格之和）
    property real cellWidth: 0
    /// th 那一格宽（align≠plain 才有意义，已含那条 24 的右内边距）
    property real keyColumnWidth: 0

    // ---- 三档来源的归一（官方 children 优先：data 档走 props.value，JSX 档走 children）----
    /// 函数档先调用一次（官方 :46 每拍都调），返回值再按 Component / 文本两档分
    readonly property var resolved: control.valueIsFunction ? control.value() : control.value
    readonly property bool valueIsFunction: !control.hasDeclared && typeof control.value === "function"
    /// `Row.data` 没有 NOTIFY（坑 110 那条），绑定里读 `.data.length` 会打 non-bindable 警告，
    /// 所以由 onChildrenChanged 把条数记进普通属性
    property int declaredCount: 0
    readonly property bool hasDeclared: control.declaredCount > 0
    readonly property bool valueIsComponent: !control.hasDeclared && (control.valueIsFunction
        ? control.resolved instanceof Component : control.value instanceof Component)
    readonly property bool valueIsText: !control.hasDeclared && !control.valueIsComponent
    readonly property bool keyIsComponent: control.itemKey instanceof Component

    // ---- 官方 render 的那两条判断交叉 ----
    readonly property bool plainMode: control.hostAlign === "plain"
    /// 双行档里 th / td 变成上下两段（`tr { display: inline-flex; flex-direction: column }`）；
    /// plain + row 只有一个 td，key 与 value 仍在同一行内
    readonly property bool stacked: control.hostRow && !control.plainMode

    /// plain 档那条 8（$spacing-descriptions_value_plain-paddingLeft），双行档不套
    readonly property real plainGap: control.hostRow ? 0 : Theme.current.spacingExtraTight * 2
    /// 普通档 th 的右内边距（$spacing-descriptions_th-paddingRight = $spacing-loose = 24）。
    /// 它是 **padding**，在文字盒之外 ⇒ key 那个 Text 只能占 `keyColumnWidth − 24`，
    /// 否则右对齐的 key 会正好贴在 value 脸上（center 档实测就是这个）。
    readonly property real thPaddingRight: Theme.current.spacingLoose

    // ---- 字号与行高（双行档分三档，普通档恒 regular）----
    readonly property real keyFont: control.hostRow && control.hostSize === "small"
        ? Theme.current.fontSizeSmall : Theme.current.fontSizeRegular
    readonly property real keyLine: control.hostRow && control.hostSize === "small" ? 16 : 20
    readonly property real keyPadBottom: !control.hostRow ? 0
        : (control.hostSize === "small" ? 0 : Theme.current.spacingExtraTight)
    readonly property real valueFont: !control.hostRow ? Theme.current.fontSizeRegular
        : (control.hostSize === "small" ? Theme.current.fontSizeHeader6
            : (control.hostSize === "large" ? Theme.current.fontSizeHeader2
                : Theme.current.fontSizeHeader4))
    /// 官方 `-double .semi-descriptions-value { font-weight: $font-descriptions_value-fontWeight }`
    /// = 600，只有双行档那条规则在 `-double` 里 ⇒ 普通档是 normal
    readonly property int valueWeight: control.hostRow ? Font.DemiBold : Font.Normal
    readonly property real valueLine: !control.hostRow ? 20
        : (control.hostSize === "small" ? 22 : (control.hostSize === "large" ? 40 : 28))

    implicitWidth: control.cellWidth
    implicitHeight: control.computedHeight

    // ---- 给宿主量用的两个自然尺寸 ----
    /// key 的自然宽（plain 档含那个冒号）。官方 `-key` 是 nowrap ⇒ 这就是它占的宽。
    readonly property real keyNaturalWidth: control.keyIsComponent
        ? keyLoader.implicitWidth : (keyText.text.length > 0 ? keyText.implicitWidth : 0)
    readonly property real valueNaturalWidth: control.hasDeclared ? valueRow.implicitWidth
        : (control.valueIsComponent ? valueLoader.implicitWidth
            : (control.valueIsText ? (valueText.text.length > 0 ? valueText.implicitWidth : 0) : 0))

    /// 值那一格能用的宽
    readonly property real valueAreaWidth: control.plainMode
        ? Math.max(0, control.cellWidth - control.keyAreaWidth - control.plainGap)
        : Math.max(0, control.cellWidth - control.keyColumnWidth)

    readonly property real valueLinesHeight: {
        if (control.hasDeclared)
            return valueRow.implicitHeight;
        if (control.valueIsComponent)
            return valueLoader.implicitHeight;
        const w = control.valueAreaWidth;
        if (w <= 0 || valueText.text.length === 0)
            return control.valueLine;
        return Math.max(1, Math.ceil((control.valueNaturalWidth - 0.5) / w)) * control.valueLine;
    }

    readonly property real computedHeight: control.stacked
        ? control.keyLine + control.keyPadBottom + control.valueLinesHeight
        : Math.max(control.keyLine, control.valueLinesHeight)
            + (control.hostRow ? 0 : Theme.current.spacingBaseTight)

    // ---- key 那一格 ----
    readonly property real keyAreaWidth: {
        if (control.plainMode) {
            // inline-block ⇒ keyStyle.width 生效（其余三档官方是 inline span，width 被 CSS 忽略）
            const w = control.keyStyle ? control.keyStyle.width : undefined;
            return w !== undefined && w !== null ? Number(w) : control.keyNaturalWidth;
        }
        if (control.stacked)
            return Math.max(0, control.cellWidth);
        // 那 24 是 th 的 padding，在文字盒之外
        return Math.max(0, control.keyColumnWidth - control.thPaddingRight);
    }
    readonly property real keyX: 0
    readonly property real keyY: 0
    readonly property string keyLabel: {
        if (control.itemKey === undefined || control.itemKey === null || control.keyIsComponent)
            return "";
        const s = String(control.itemKey);
        return control.plainMode ? s + ":" : s;
    }
    readonly property color keyColor: control.keyStyle
        && control.keyStyle.color !== undefined && control.keyStyle.color !== null
        ? control.keyStyle.color : Theme.current.colorText2
    readonly property int keyAlign: {
        if (control.plainMode) {
            const a = control.keyStyle ? control.keyStyle.textAlign : undefined;
            if (a === "right" || a === "end")
                return Text.AlignRight;
            if (a === "center")
                return Text.AlignHCenter;
            return Text.AlignLeft;
        }
        if (control.hostRow)
            return Text.AlignLeft;
        // 那四条只在非 -double 下套：center ⇒ th 右；left ⇒ 左；justify ⇒ th 左
        return control.hostAlign === "center" ? Text.AlignRight : Text.AlignLeft;
    }

    Loader {
        id: keyLoader

        x: control.keyX
        y: control.keyY
        sourceComponent: control.keyIsComponent ? control.itemKey : null
        visible: control.keyIsComponent
    }

    Text {
        id: keyText

        x: control.keyX
        y: control.keyY
        width: Math.max(0, control.keyAreaWidth)
        visible: !control.keyIsComponent
        text: control.keyLabel
        color: control.keyColor
        font.pixelSize: control.keyFont
        lineHeight: control.keyLine
        lineHeightMode: Text.FixedHeight
        elide: Text.ElideRight
        horizontalAlignment: control.keyAlign
    }

    // ---- value 那一格 ----
    readonly property real valueX: control.plainMode
        ? control.keyAreaWidth + control.plainGap : control.keyColumnWidth
    readonly property real valueY: control.stacked ? control.keyLine + control.keyPadBottom : 0
    readonly property int valueAlign: control.plainMode || control.hostRow
        ? Text.AlignLeft
        : (control.hostAlign === "justify" ? Text.AlignRight : Text.AlignLeft)

    // 值不是文本（Component 档、子项档）时，text-align 那种「贴右」得靠位移做出来：
    // 官方那是 td 上的 text-align 作用在 inline-block 的节点上，端口没有行盒。
    readonly property real nodeShiftRight: control.valueAlign === Text.AlignRight
        ? Math.max(0, control.valueAreaWidth - (control.valueIsComponent
            ? valueLoader.implicitWidth : valueRow.implicitWidth))
        : 0

    Row {
        id: valueRow

        x: control.valueX + (control.hasDeclared ? control.nodeShiftRight : 0)
        y: control.valueY
        spacing: 0

        onChildrenChanged: control.declaredCount = valueRow.children.length
    }

    Loader {
        id: valueLoader

        x: control.valueX + (control.valueIsComponent ? control.nodeShiftRight : 0)
        y: control.valueY
        sourceComponent: control.valueIsComponent ? control.resolved : null
        visible: control.valueIsComponent
    }

    Text {
        id: valueText

        x: control.valueX
        y: control.valueY
        width: control.valueAreaWidth
        visible: control.valueIsText
        text: control.resolved === undefined || control.resolved === null ? "" : String(control.resolved)
        color: Theme.current.colorText0
        font.pixelSize: control.valueFont
        font.weight: control.valueWeight
        lineHeight: control.valueLine
        lineHeightMode: Text.FixedHeight
        wrapMode: Text.Wrap
        horizontalAlignment: control.valueAlign
    }

    // ---- 报给宿主 ----
    // 宿主算列宽要读条目自身的自然宽，而那几个量是异步的（Component 档要等 Loader 出项、
    // 子项档要等 Row 排好），所以三处变了都回敲一次。回敲不会成环：measure 只抄数、
    // relayout 只写同一份几何，第二轮读到的还是那一组值 ⇒ 收敛在一拍之内。
    onKeyNaturalWidthChanged: control.tellHost()
    onValueNaturalWidthChanged: control.tellHost()
    onImplicitHeightChanged: control.tellHost()
    onHiddenChanged: control.tellHost()

    function tellHost() {
        if (control.descriptionsHost !== null)
            control.descriptionsHost.itemNaturalChanged();
    }
}
