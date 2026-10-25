pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// 分割线。官方 DividerProps（semi-ui/divider/index.tsx:9-24 + divider.scss + variables.scss）。
//
//     Divider { }                                // 水平实线，吃满父宽（官方 width:100%）
//     Divider { dashed: true }                   // 水平虚线
//     Divider { vertical: true }                 // 垂直实线（官方 layout: "vertical"）
//     Divider { margin: 12 }                     // 上下各 12（number 当 px；"12px" 也认）
//     Divider { text: "或者" }                   // 带文字：线 — 文字 — 线
//     Divider { content: someIconComp }          // 带节点（官方 children 的 ReactNode 档）
//
// 与官方的偏差逐条：
//   · 官方 `layout: 'horizontal' | 'vertical'` 是字符串枚举，端口收 `vertical: bool`
//     （两值方向在 QML 用 bool 更顺手，语义一一对应）；
//   · 官方 `children` 一个 ReactNode 槽收字符串或节点，QML 没有 children ⇒ 拆成
//     `text`（字符串档）与 `content`（Component 档）。官方对两档的处理本就不同：
//     字符串包一层 `-inner-text`（左右 8px 内边距 + 字重 600 + 继承正文 14px 字号），
//     节点档裸渲染（IconSemiLogo 那种自带尺寸），端口照这条分岔走；
//   · 官方 `margin` 是 CSS margin（吃在盒子外），QML 的 Item 没有外边距概念 ⇒
//     端口把它烘进 implicitWidth/implicitHeight 并把线内缩，Column 里上下邻居
//     拿到的间距与官方一致；缺省吃 variables.scss 的 1px（不是 0）；
//   · 官方 `-vertical` 的高写死 20px（$height-divider_vertical），端口同样给 implicitHeight 20；
//   · **官方 children 只在水平档渲染**（index.tsx:63 的 `children && layout === 'horizontal'`），
//     垂直档 + 内容 = 内容被丢弃、只画线 —— 照抄不修；
//   · `className` / `style` 是 DOM 内联样式（坑 91），不搬；
//   · 虚线：QML 的 Rectangle 画不出虚线（border 无 style），用 Canvas + setLineDash
//     描，段长按浏览器虚线边框的 3×线宽 取（Upload.qml:1380 同一套）。
Item {
    id: control

    // ---------------------------------------------------------------- 官方属性面
    // 官方 layout: "horizontal" | "vertical"（index.tsx:30 缺省 horizontal）
    property bool vertical: false
    // 官方 children 的字符串档
    property string text: ""
    // 官方 children 的 ReactNode 档（Component）
    property var content: undefined
    property bool dashed: false
    // 带内容时的对齐（index.tsx:32 缺省 center）；只在水平档有意义
    property string align: "center"
    // 官方 margin: number | string —— 水平吃上下、垂直吃左右（index.tsx:45-53）
    property var margin: undefined

    /// variables.scss 的缺省：水平 1px 上下、垂直 1px 左右
    readonly property real marginValue: {
        if (control.margin === undefined || control.margin === null)
            return 1;
        if (typeof control.margin === "number")
            return control.margin;
        const parsed = parseFloat(control.margin);
        return isNaN(parsed) ? 1 : parsed;
    }

    readonly property bool hasContent: control.text !== "" || control.content !== null
    // index.tsx:63 —— children 只在水平档渲染，垂直档内容直接丢弃
    readonly property bool withContent: control.hasContent && !control.vertical

    // variables.scss：$width-divider_inner_text_left_line / right_line 都是 40
    readonly property real alignFixedLine: 40
    readonly property color lineColor: Theme.current.colorBorder

    // 官方 -horizontal { width: 100% }：吃满父宽；垂直档只占线宽 + 左右 margin
    implicitWidth: control.vertical ? 1 + control.marginValue * 2 : 0
    // 官方 -with-text 的高由内容撑开；无内容水平档恒 1px；垂直档写死 20px
    implicitHeight: control.vertical ? 20
        : (control.withContent ? contentRow.height + control.marginValue * 2
            : 1 + control.marginValue * 2)
    // 水平档吃满父宽（官方 width:100%）；Layout.fillWidth 让它在 RowLayout 里也成立
    width: control.vertical ? implicitWidth
        : (control.parent !== null ? control.parent.width : implicitWidth)
    Layout.fillWidth: !control.vertical
    // 垂直档不自动 fillHeight —— 那会把所在行整个撑高（官方 inline-block 吃内容高 20）
    Layout.preferredHeight: control.implicitHeight

    // ---------------------------------------------------------------- 无内容 / 垂直档
    // 线：margin 内缩后居中的 1px 条。垂直档官方高 20、线在左右 margin 之间。
    Item {
        objectName: "dividerLineHost"
        anchors.fill: parent
        visible: !control.withContent

        // 实线。水平档 margin 只吃上下（线满宽），垂直档吃左右（线在 x=margin 处）
        Rectangle {
            objectName: "dividerLine"
            visible: !control.dashed
            x: control.vertical ? control.marginValue : 0
            y: control.vertical ? 0 : control.marginValue
            width: control.vertical ? 1 : parent.width
            height: control.vertical ? parent.height : 1
            color: control.lineColor
        }

        // 虚线 —— Rectangle 没有 border-style，用 Canvas 描（Upload.qml 同法）
        Canvas {
            objectName: "dividerDashLine"
            visible: control.dashed
            x: control.vertical ? control.marginValue : 0
            y: control.vertical ? 0 : control.marginValue
            width: control.vertical ? 1 : parent.width
            height: control.vertical ? parent.height : 1

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.lineWidth = 1;
                ctx.strokeStyle = control.lineColor;
                // 浏览器虚线边框的段长是线宽的 3 倍（Upload.qml:1380 同口径）
                ctx.setLineDash([3, 3]);
                ctx.beginPath();
                if (control.vertical) {
                    ctx.moveTo(0.5, 0);
                    ctx.lineTo(0.5, height);
                } else {
                    ctx.moveTo(0, 0.5);
                    ctx.lineTo(width, 0.5);
                }
                ctx.stroke();
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
    }

    // ---------------------------------------------------------------- 水平带内容档
    // 官方 -with-text：display flex、border-bottom 归零、两侧线各占一半（或按对齐固定 40px）
    RowLayout {
        id: contentRow

        objectName: "dividerContentRow"
        visible: control.withContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: control.marginValue
        height: control.withContent ? implicitHeight : 0
        spacing: 0

        // 左线 —— align left 时固定 40px（$width-divider_inner_text_left_line），否则吃一半
        Item {
            objectName: "dividerLineBefore"
            Layout.fillWidth: control.align !== "left"
            Layout.preferredWidth: control.align === "left" ? control.alignFixedLine : -1
            Layout.preferredHeight: 1
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                visible: !control.dashed
                anchors.fill: parent
                color: control.lineColor
            }
            Canvas {
                visible: control.dashed
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = control.lineColor;
                    ctx.setLineDash([3, 3]);
                    ctx.beginPath();
                    ctx.moveTo(0, 0.5);
                    ctx.lineTo(width, 0.5);
                    ctx.stroke();
                }
                onWidthChanged: requestPaint()
            }
        }

        // 文字档：官方包 `-inner-text`（padding 0 8 + 字重 600 + 继承 14px 字号 + text-0）
        Text {
            objectName: "dividerText"
            visible: control.text !== ""
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            text: control.text
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Font.DemiBold
        }

        // 节点档：官方 children 非字符串时裸渲染（无 -inner-text 的内边距与字重）
        Loader {
            objectName: "dividerContentLoader"
            visible: control.content !== null
            active: control.content !== null
            sourceComponent: control.content !== null ? control.content : null
            Layout.alignment: Qt.AlignVCenter
        }

        // 右线 —— align right 时固定 40px，否则吃一半
        Item {
            objectName: "dividerLineAfter"
            Layout.fillWidth: control.align !== "right"
            Layout.preferredWidth: control.align === "right" ? control.alignFixedLine : -1
            Layout.preferredHeight: 1
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                visible: !control.dashed
                anchors.fill: parent
                color: control.lineColor
            }
            Canvas {
                visible: control.dashed
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = control.lineColor;
                    ctx.setLineDash([3, 3]);
                    ctx.beginPath();
                    ctx.moveTo(0, 0.5);
                    ctx.lineTo(width, 0.5);
                    ctx.stroke();
                }
                onWidthChanged: requestPaint()
            }
        }
    }
}
