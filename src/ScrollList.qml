pragma ComponentBehavior: Bound

import QtQuick

// 滚动列表外壳。官方 ScrollList（packages/semi-ui/scrollList/index.tsx:12-79）只有
// header / body / footer 三段，body 是 `display:flex`，横向铺一到多列 ScrollItem；
// 滚轮、点选、无限循环这些逻辑全在列上（src/ScrollItem.qml）。
//
//     C.ScrollList {
//         header: "无限滚动列表"
//         footer: Button { text: "Ok" }
//
//         C.ScrollItem { mode: "wheel"; list: ampms; selectedIndex: ap; type: 1 }
//         C.ScrollItem { mode: "wheel"; cycled: true; list: hours; type: 2 }
//     }
//
// 规格（packages/semi-foundation/scrollList/scrollList.scss + variables.scss）：
//   本体 bg-3、圆角 radius-medium(6)、overflow hidden、14/20、不可选中文字；
//     投影 $shadow-scrollList = 0 0 1px rgba(0,0,0,.3), 0 4px 14px rgba(0,0,0,.1)
//     —— 就是 --semi-shadow-elevated，本体**没有**描边
//   header 内边距 0 16 且文字居中；标题再套一层 16 0 的内边距、字重 600、text-0、14/20；
//     标题块底下一条 1px color-border 的 -line
//   body 高 $height-scrollList = 300（bodyHeight 覆盖）、内边距 0 16、flex 横排
//   列与列之间 1px color-border（`:not(:last-child)` 的 border-right）
//   footer 上边 1px color-border、内边距 10，内容左对齐（只有 header 那条 text-align:center）
Item {
    id: control

    default property alias content: columnHost.data

    // ---------------------------------------------------------------- 官方 ScrollListProps
    property var header: ""                         // ReactNode
    property var footer: ""                         // ReactNode
    property var bodyHeight: ""                     // number | "NNNpx"，缺省走 CSS 的 300
    property string className: ""
    property var style: ({})

    readonly property bool headerTaken: !!control.header
    readonly property bool footerTaken: !!control.footer
    readonly property bool headerIsText: control._isText(control.header)
    readonly property bool footerIsText: control._isText(control.footer)

    // ---------------- 令牌
    readonly property real lineHeight: 20           // @include font-size-regular → 14 / 20
    readonly property real headerPaddingX: 16       // $spacing-scrollList_header-paddingX
    readonly property real headerTitlePaddingY: Theme.current.spacingBase   // 标题块 16 0
    readonly property real bodyPaddingX: 16         // $spacing-scrollList_body-paddingX
    readonly property real footerPadding: 10        // $spacing-scrollList_footer-padding
    readonly property real seamWidth: 1             // $width-scrollList_item-border / -line
    readonly property real defaultBodyHeight: 300   // $height-scrollList

    readonly property real bodyHeightValue: control.__sizeOf(control.bodyHeight, control.defaultBodyHeight)
    readonly property real headerTitleHeight: control.headerIsText
        ? control.lineHeight : headerHost.childrenRect.height
    /// -header（标题 + 上下 16）+ 那条 1px 的 -line
    readonly property real headerHeight: control.headerTaken
        ? control.headerTitleHeight + control.headerTitlePaddingY * 2 + control.seamWidth : 0
    readonly property real footerHeight: control.footerTaken
        ? (control.footerIsText ? control.lineHeight : footerHost.childrenRect.height)
            + control.footerPadding * 2 + control.seamWidth : 0

    readonly property string surfaceCss: control._colorOf(control.style, "backgroundColor", "background")
    readonly property bool shadowOff: control.__cssUnset(control.style, "boxShadow")
    readonly property real columnWidth: control.columnCount > 0
        ? (columnHost.width - (control.columnCount - 1) * control.seamWidth) / control.columnCount : 0

    property int columnCount: 0

    implicitWidth: 300
    implicitHeight: control.headerHeight + control.bodyHeightValue + control.footerHeight

    // 官方本体是 width/height: 100%，所以宽度由宿主给；这里只保证没父项时也能自量。
    width: parent ? parent.width : implicitWidth

    function relayout() {
        const items = [];
        for (let i = 0; i < columnHost.children.length; ++i) {
            const child = columnHost.children[i];
            if (child === undefined || child === null)
                continue;
            items.push(child);
        }
        control.columnCount = items.length;
        const w = control.columnWidth;
        let x = 0;
        for (let i = 0; i < items.length; ++i) {
            items[i].x = x;
            items[i].y = 0;
            // 官方 flex:1 = flex-basis 0，声明的宽度被忽略，这里同样直接覆写
            items[i].width = w;
            items[i].height = columnHost.height;
            x += w + control.seamWidth;
        }
    }

    Component.onCompleted: control.relayout()
    onWidthChanged: control.relayout()
    onBodyHeightValueChanged: control.relayout()
    onHeaderHeightChanged: control.relayout()
    onFooterHeightChanged: control.relayout()

    // ---------------------------------------------------------------- 属性取值小工具
    function _propOf(obj, key, fallback) {
        if (obj === undefined || obj === null)
            return fallback;
        return key in obj ? obj[key] : fallback;
    }

    // bodyHeight 官方类型是 number | string，字符串按 CSS 长度读（parseFloat 取数字部分）。
    // 百分比要有确定基准才知道除谁，本端口没有布局引擎兜着，读不出来就落回 CSS 默认的 300。
    function __sizeOf(v, fallback) {
        let n = NaN;
        if (typeof v === "number")
            n = v;
        else if (typeof v === "string" && v.indexOf("%") === -1)
            n = parseFloat(v);
        return !Number.isNaN(n) && n > 0 ? n : fallback;
    }

    function _colorOf(obj, key, altKey) {
        let v = control._propOf(obj, key, undefined);
        if (v === undefined && altKey !== undefined)
            v = control._propOf(obj, altKey, undefined);
        return typeof v === "string" && v !== "" ? v : "";
    }

    // 官方 demo 用 style={{border:'unset', boxShadow:'unset'}} 关掉那两条
    function __cssUnset(obj, key) {
        const v = control._propOf(obj, key, undefined);
        return typeof v === "string" && (v === "unset" || v === "none");
    }

    function _isText(value) {
        return typeof value === "string" || typeof value === "number";
    }

    // Loader.sourceComponent 只收 Component：字符串档必须给 null
    function _nodeOf(value) {
        return value !== undefined && value !== null && !control._isText(value) ? value : null;
    }

    // ---------------------------------------------------------------- 投影 + 底面
    SemiPopupShadow {
        objectName: "scrollListShadow"

        anchors.fill: parent
        z: -1
        visible: !control.shadowOff
    }

    Rectangle {
        objectName: "scrollListSurface"

        anchors.fill: parent
        radius: Theme.current.radiusMedium
        // $color-scrollList-bg = var(--semi-color-bg-3)；官方本体没有描边
        color: control.surfaceCss !== "" ? control.surfaceCss : Theme.current.colorBg3
    }

    // ---------------------------------------------------------------- .semi-scrolllist-header
    Item {
        id: headerBlock

        objectName: "scrollListHeader"

        visible: control.headerTaken
        x: 0
        y: 0
        width: control.width
        height: control.headerHeight

        Item {
            id: headerPaddingBox

            objectName: "scrollListHeaderPaddingBox"

            x: control.headerPaddingX
            y: 0
            width: headerBlock.width - control.headerPaddingX * 2
            height: control.headerHeight - control.seamWidth

            Text {
                objectName: "scrollListHeaderText"

                visible: control.headerIsText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: control.headerTitlePaddingY
                text: control.headerIsText ? String(control.header) : ""
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                // $font-scrollList_header_title-fontWeight = $font-weight-bold = 600
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                lineHeight: control.lineHeight
                lineHeightMode: Text.FixedHeight
            }

            Item {
                id: headerHost

                objectName: "scrollListHeaderNode"

                visible: !control.headerIsText
                x: 0
                y: control.headerTitlePaddingY
                width: headerPaddingBox.width

                Loader {
                    sourceComponent: control._nodeOf(control.header)
                }
            }
        }

        // ${clsWrapper}-line：贴在整块头部底边
        Rectangle {
            objectName: "scrollListHeaderLine"

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: control.seamWidth
            color: Theme.current.colorBorder
        }
    }

    // ---------------------------------------------------------------- .semi-scrolllist-body
    Item {
        id: bodyBox

        objectName: "scrollListBody"

        x: 0
        y: control.headerHeight
        width: control.width
        height: control.bodyHeightValue
        clip: true

        // 列与列之间的 1px color-border
        Repeater {
            objectName: "scrollListSeams"

            model: control.columnCount > 1 ? control.columnCount - 1 : 0

            delegate: Rectangle {
                required property int index

                objectName: "scrollListColumnSeam"

                x: control.bodyPaddingX + (index + 1) * control.columnWidth + index * control.seamWidth
                y: 0
                width: control.seamWidth
                height: bodyBox.height
                color: Theme.current.colorBorder
            }
        }

        // padding: 0 16 → 列容器往内缩 16，flex 横排
        Item {
            id: columnHost

            objectName: "scrollListColumnHost"

            x: control.bodyPaddingX
            y: 0
            width: bodyBox.width - control.bodyPaddingX * 2
            height: bodyBox.height

            onChildrenChanged: control.relayout()
        }
    }

    // ---------------------------------------------------------------- .semi-scrolllist-footer
    Item {
        id: footerBlock

        objectName: "scrollListFooter"

        visible: control.footerTaken
        x: 0
        y: control.headerHeight + control.bodyHeightValue
        width: control.width
        height: control.footerHeight

        Rectangle {
            objectName: "scrollListFooterBorder"

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: control.seamWidth
            color: Theme.current.colorBorder
        }

        Text {
            objectName: "scrollListFooterText"

            visible: control.footerIsText
            x: control.footerPadding
            y: control.seamWidth + control.footerPadding
            text: control.footerIsText ? String(control.footer) : ""
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: control.lineHeight
            lineHeightMode: Text.FixedHeight
        }

        Item {
            id: footerHost

            objectName: "scrollListFooterNode"

            visible: !control.footerIsText
            x: control.footerPadding
            y: control.seamWidth + control.footerPadding
            width: footerBlock.width - control.footerPadding * 2

            Loader {
                sourceComponent: control._nodeOf(control.footer)
            }
        }
    }
}
