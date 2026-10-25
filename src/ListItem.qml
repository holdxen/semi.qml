pragma ComponentBehavior: Bound

import QtQuick

// 列表条目。官方 `List.Item`（packages/semi-ui/list/item.tsx）就是一个 `<li>`，
// 里面按 [body(header + main)] [children] [extra] 从左到右排；`align` 只管 body 里
// header 与 main 的纵向对齐，三段之间靠 li 自己的 `align-items: center` 各自垂直居中。
//
//     ListItem {
//         header: Component { Avatar { text: "张" } }
//         main: Component { Text { text: "张三" } }
//         extra: Component { Button { text: "编辑" } }
//     }
//
// 规格（semi-foundation/list/list.scss:26-69 + variables.scss）：
//   · li：`display:flex; flex-wrap:wrap; align-items:center; box-sizing:border-box`，
//     内边距跟着 List 的 size —— 默认上下 12 / 左右 24，small 8 / 16，large 16 / 24；
//     **栅格档内边距清 0**（`&.semi-list-grid .semi-list-item { padding: 0 }`，:99-103）。
//     注意 scss 写的是 `padding: $…-paddingX $…-paddingY`，而 CSS 简写第一格是**上下**，
//     所以这两个令牌名读反了：paddingX 是纵向、paddingY 是横向（本库早期就照名字抄成了
//     「横向 12 / 纵向 24」）。
//   · -body `flex:1`（basis 0 ⇒ 富余宽度全给它，它自己声明的宽度被忽略）、`display:flex`；
//     其中那行 `align-items: center` 是**注释掉的**（:38），所以没加 -body-{align} 类时
//     用的是 CSS 初值 stretch；-body-header 右外边距 20（$spacing-list_header-marginRight）；
//     -extra `flex:0 0 auto` + 左外边距 40（$spacing-list_extra-marginLeft）。
//   · 分割线不在本组件上：官方是 `.semi-list-split .semi-list-item { border-bottom: 1px }`
//     配 `&:last-child { border-bottom: none }`（横向布局换成 border-right）。
//     端口由 List 往「items 容器里除最后一条之外」的节点写 `hasSeam`，其它节点没人写、
//     就按 false 处理 —— 栅格档每条独占一个 Col（自己就是 last-child）、条目被
//     Skeleton 之类包了一层、或者单独摆一个 ListItem，这三种官方都不画线，端口同样不画。
//
// 与官方的差异：
//   · `style` / `className` 不收（没有 CSS）；ReactNode 走本库统一口径：字符串或 `Component`。
//   · `align: "baseline"` 官方靠首行文字基线，端口没有排版接口，落回 flex-start；
//     `stretch` 只把那一格的盒子拉高，塞进来的节点不会被撑开。
//   · 官方 `onClick ? onClick : contextOnClick` 是二选一（条目自己的赢，item.tsx:76-77）；
//     QML 探不出「这条信号有没有人接」，所以两层都会发 —— 只写一层时看不出差别。
//   · li 是 `flex-wrap: wrap`，内容超宽会换行；端口不换行，溢出就溢出。
Item {
    id: control

    // ---- 官方 ListItemProps（item.tsx:10-22，缺省见 :42-46）----
    property var header: undefined                  // ReactNode
    property var main: undefined                    // ReactNode
    property var extra: undefined                   // ReactNode
    property string align: "flex-start"             // flex-start|flex-end|center|baseline|stretch

    // 官方 children：裸节点，排在 body 之后
    default property alias content: childrenHost.data

    signal clicked
    signal rightClicked
    // 官方 onMouseEnter / onMouseLeave（item.tsx:20-21，挂在 li 自己身上 :100-101）。
    // 命名跟 Radio / Tag 一致。官方那张 List.Item API 表**没列**这两条，但 props 与
    // propTypes 里都有、也确实挂上了 DOM ⇒ 按 TSX 的 prop 面收。
    signal mouseEntered
    signal mouseLeft

    // ---- 本库自有 ----
    // 整条 li 的底色。官方这里没有 prop：demo 是往 li 上写 CSS 的
    //（.component-list-demo-booklist .list-item:hover { background-color: fill-0 }，
    // index.md:1168-1177）。端口的 children 槽是 flex 横排（Row），塞不进「铺满整条的底」
    // —— 铺进去的那个孩子会被 Row 挪位置、还会把后面的内容顶跑，所以开这一个槽。
    // 它铺的是整条 li（含内边距），和 CSS 的 background 覆盖 padding-box 同口径。
    // 组件本身仍然没有悬浮态（官方也没有），悬浮的「开关」用上面的 mouseEntered / mouseLeft。
    property Component background: null

    // ---- 端口内部：List 给「非末条」写 true，对应官方那条 :last-child ----
    property bool hasSeam: false

    // ---- 排版上下文：由上层 List 在重排时写下来（对应官方 CSS 从 .semi-list 命中
    // .semi-list-item）。端口不让条目自己回读父项：那条路把 listCtx → inGrid → padV →
    // implicitHeight 串成一串懒求值的绑定，List 在重排里读条目隐式高的瞬间正好把这条链
    // 就地初始化一遍，Qt 判成 `Binding loop detected for property "implicitHeight"` 并把
    // 这一轮求值整个丢掉（探针：换档路径每换一次冒一条警告；改成 List 先写、条目再算，
    // 警告归零、值当场就对）。单独摆一个 ListItem（没有上层 List）⇒ 三个都取缺省，
    // 等价官方「这条 li 不在 .semi-list 里」。
    property string hostSize: "default"
    property string hostLayout: "vertical"
    property bool hostInGrid: false

    readonly property string size: control.hostSize
    readonly property bool inGrid: control.hostInGrid
    readonly property bool horizontal: control.hostLayout === "horizontal"

    // 回上层找 List 只为了点击转发（见下面的 TapHandler），不参与几何求值
    // qmllint disable missing-property
    readonly property List listCtx: control._findList()
    // qmllint enable missing-property

    // ---- 令牌 ----
    readonly property real seamWidth: 1                                 // $border-thickness-control
    readonly property real headerGap: Theme.current.spacingBaseLoose     // $spacing-list_header-marginRight 20
    readonly property real extraGap: Theme.current.spacingSuperLoose     // $spacing-list_extra-marginLeft 40
    readonly property real padV: control.inGrid ? 0
        : (control.size === "small" ? Theme.current.spacingTight
            : (control.size === "large" ? Theme.current.spacingBase
                : Theme.current.spacingBaseTight))
    readonly property real padH: control.inGrid ? 0
        : (control.size === "small" ? Theme.current.spacingBase : Theme.current.spacingLoose)

    // ---- 三段是否占位（官方 `{header ? <div> : null}` 的真值判断）----
    readonly property bool headerTaken: control._taken(control.header)
    readonly property bool mainTaken: control._taken(control.main)
    readonly property bool extraTaken: control._taken(control.extra)
    readonly property bool bodyTaken: control.headerTaken || control.mainTaken
    // align 给假值时官方那条 -body-{align} 类不加，落回 CSS 初值 stretch
    readonly property string alignResolved: control.align !== "" ? control.align : "stretch"

    // ---- 各段的自然尺寸：按「字符串档量 Text、节点档量 Loader」取，别用 childrenRect
    // （Text 与 Loader 同躺在一格里，childrenRect 会把没生效的那一份也算进去）----
    readonly property real headerW: control.headerTaken
        ? (control._isText(control.header) ? headerText.implicitWidth : headerLoader.implicitWidth) : 0
    readonly property real headerH: control.headerTaken
        ? (control._isText(control.header) ? headerText.implicitHeight : headerLoader.implicitHeight) : 0
    readonly property real mainW: control.mainTaken
        ? (control._isText(control.main) ? mainText.implicitWidth : mainLoader.implicitWidth) : 0
    readonly property real mainH: control.mainTaken
        ? (control._isText(control.main) ? mainText.implicitHeight : mainLoader.implicitHeight) : 0
    readonly property real extraW: control.extraTaken
        ? (control._isText(control.extra) ? extraText.implicitWidth : extraLoader.implicitWidth) : 0
    readonly property real extraH: control.extraTaken
        ? (control._isText(control.extra) ? extraText.implicitHeight : extraLoader.implicitHeight) : 0
    // children 是一排裸节点 ⇒ 官方那是 flex 横排，这里用 Row 顶替（间距 0）
    readonly property real childrenW: childrenHost.implicitWidth
    readonly property real childrenH: childrenHost.implicitHeight

    // -body 的自然宽：header 与 main 之间那 20 只在两者都在时才出现
    readonly property real bodyNaturalWidth: control.headerTaken
        ? (control.headerW + (control.mainTaken ? control.headerGap + control.mainW : 0))
        : control.mainW
    readonly property real bodyNaturalHeight: Math.max(control.headerTaken ? control.headerH : 0,
        control.mainTaken ? control.mainH : 0)
    readonly property real extraBlockWidth: control.extraTaken ? control.extraGap + control.extraW : 0

    // 自然宽（横向 / 栅格档用它）；纵向档由 List 把宽度铺满，富余的那段归 body
    readonly property real naturalWidth: control.bodyNaturalWidth + control.childrenW
        + control.extraBlockWidth
    readonly property real contentWidth: Math.max(control.naturalWidth,
        control.width - control.padH * 2
            - (control.horizontal && control.hasSeam ? control.seamWidth : 0))
    // 没有 header / main 时官方那个 -body 的 div 压根不创建 ⇒ 富余宽度谁都不吃，
    // children 就贴着左内边距。少了这个判断，纯 children 的条目会被推到最右边。
    readonly property real bodyWidth: control.bodyTaken
        ? Math.max(control.bodyNaturalWidth,
            control.contentWidth - control.childrenW - control.extraBlockWidth)
        : 0
    // li 的内容高 = 三段里最高的那条（li 自己 align-items:center，谁都不拉伸）
    readonly property real contentHeight: Math.max(control.bodyNaturalHeight,
        control.childrenH, control.extraH)

    implicitWidth: control.naturalWidth + control.padH * 2
        + (control.horizontal && control.hasSeam ? control.seamWidth : 0)
    implicitHeight: control.contentHeight + control.padV * 2
        + (!control.horizontal && control.hasSeam ? control.seamWidth : 0)

    function _findList() {
        let node = control.parent;
        while (node !== null && node !== undefined) {
            // qmllint disable missing-property
            if (node.isListHost === true)
                return node;
            node = node.parent;
            // qmllint enable missing-property
        }
        return null;
    }

    // 官方 `{header ? <div> : null}` 就是 JS 真值："" / 0 / false / null 都不占位
    function _taken(value) {
        return !!value;
    }

    function _isText(value) {
        return typeof value === "string" || typeof value === "number";
    }

    function _nodeOf(value) {
        return control._taken(value) && !control._isText(value) ? value : null;
    }

    // 三段在 body 里的纵向位置；baseline 见文件头，按 flex-start 落
    function alignY(boxHeight, bandHeight) {
        if (control.alignResolved === "flex-end")
            return bandHeight - boxHeight;
        if (control.alignResolved === "center")
            return (bandHeight - boxHeight) / 2;
        return 0;
    }

    Loader {
        id: backgroundLoader

        objectName: "listItemBackground"

        anchors.fill: parent
        active: control.background !== null
        sourceComponent: control.background
    }

    // ---------------------------------------------------------------- -body
    Item {
        id: bodyBox

        objectName: "listItemBody"

        x: control.padH
        // 三段各自垂直居中在 li 的内容盒里
        y: control.padV + (control.contentHeight - control.bodyNaturalHeight) / 2
        width: control.bodyWidth
        height: control.bodyNaturalHeight
        visible: control.bodyTaken

        Item {
            id: headerBox

            objectName: "listItemHeader"

            x: 0
            y: control.alignResolved === "stretch" ? 0
                : control.alignY(control.headerH, control.bodyNaturalHeight)
            width: control.headerW
            height: control.alignResolved === "stretch" ? control.bodyNaturalHeight : control.headerH
            visible: control.headerTaken

            Text {
                id: headerText

                objectName: "listItemHeaderText"

                visible: control.headerTaken && control._isText(control.header)
                text: control.headerTaken && control._isText(control.header) ? String(control.header) : ""
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }

            Loader {
                id: headerLoader

                objectName: "listItemHeaderNode"

                active: control._nodeOf(control.header) !== null
                sourceComponent: control._nodeOf(control.header)
            }
        }

        Item {
            id: mainBox

            objectName: "listItemMain"

            x: control.headerTaken ? control.headerW + control.headerGap : 0
            y: control.alignResolved === "stretch" ? 0
                : control.alignY(control.mainH, control.bodyNaturalHeight)
            width: control.mainW
            height: control.alignResolved === "stretch" ? control.bodyNaturalHeight : control.mainH
            visible: control.mainTaken

            Text {
                id: mainText

                objectName: "listItemMainText"

                visible: control.mainTaken && control._isText(control.main)
                text: control.mainTaken && control._isText(control.main) ? String(control.main) : ""
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }

            Loader {
                id: mainLoader

                objectName: "listItemMainNode"

                active: control._nodeOf(control.main) !== null
                sourceComponent: control._nodeOf(control.main)
            }
        }
    }

    // ---------------------------------------------------------------- children
    Row {
        id: childrenHost

        objectName: "listItemChildren"

        x: control.padH + control.bodyWidth
        y: control.padV + (control.contentHeight - control.childrenH) / 2
        spacing: 0
    }

    // ---------------------------------------------------------------- -extra
    Item {
        id: extraBox

        objectName: "listItemExtra"

        // `flex:0 0 auto; margin-left:40`，排最后
        x: control.padH + control.bodyWidth + control.childrenW
            + (control.extraTaken ? control.extraGap : 0)
        y: control.padV + (control.contentHeight - control.extraH) / 2
        width: control.extraW
        height: control.extraH
        visible: control.extraTaken

        Text {
            id: extraText

            objectName: "listItemExtraText"

            visible: control.extraTaken && control._isText(control.extra)
            text: control.extraTaken && control._isText(control.extra) ? String(control.extra) : ""
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
        }

        Loader {
            id: extraLoader

            objectName: "listItemExtraNode"

            active: control._nodeOf(control.extra) !== null
            sourceComponent: control._nodeOf(control.extra)
        }
    }

    // ---------------------------------------------------------------- 分割线
    Rectangle {
        objectName: "listItemSeam"

        visible: control.hasSeam
        color: Theme.current.colorBorder

        // 纵向档贴底边整幅，横向档贴右边整高（官方 -flex 那两条规则互斥）
        x: control.horizontal ? control.width - control.seamWidth : 0
        y: control.horizontal ? 0 : control.height - control.seamWidth
        width: control.horizontal ? control.seamWidth : control.width
        height: control.horizontal ? control.height : control.seamWidth
    }

    // 官方是 `onClick ? onClick : contextOnClick`（item.tsx:76-77）：二选一，条目自己的赢。
    // QML 探不出「这条信号有没有人接」⇒ 端口两层都会发（只写一层时看不出差别）。
    TapHandler {
        objectName: "listItemTap"

        acceptedButtons: Qt.LeftButton

        onTapped: {
            control.clicked();
            // qmllint disable missing-property
            if (control.listCtx !== null)
                control.listCtx._itemClicked();
            // qmllint enable missing-property
        }
    }

    TapHandler {
        objectName: "listItemRightTap"

        acceptedButtons: Qt.RightButton

        onTapped: {
            control.rightClicked();
            // qmllint disable missing-property
            if (control.listCtx !== null)
                control.listCtx._itemRightClicked();
            // qmllint enable missing-property
        }
    }

    // 官方那两个回调挂在 li 本身上，所以命中区是整条（含内边距），且在条目内部的
    // 孩子之间移动不会重发 —— DOM 用的是 mouseenter / mouseleave（不是 mouseover /
    // mouseout），HoverHandler 的 hovered 正好是同一个口径。
    // 官方 ListItemProps 没有 disabled ⇒ 这里也不跟 enabled 挂钩。
    HoverHandler {
        objectName: "listItemHover"

        onHoveredChanged: {
            if (hovered)
                control.mouseEntered();
            else
                control.mouseLeft();
        }
    }
}
