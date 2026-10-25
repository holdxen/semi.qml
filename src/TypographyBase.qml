pragma ComponentBehavior: Bound

import QtQuick

// 排版组件的共同底座。官方把 Title / Text / Paragraph / Numeral 共用的东西
// （色调、尺寸与尺寸继承、mark/code/delete、链接的 hover 下划线、copyable、ellipsis）
// 全收在 semi-ui/typography/base.tsx 里，四个组件只写自己的差异。这里同构：
// Title / TextLabel / Paragraph / Numeral 都继承本文件。
//
// 规格：semi-foundation/typography/typography.scss + variables.scss，
// 数值是拿官方 DOM 在浏览器里量出来的（见坑 58）。
Text {
    id: control

    // ---- 与官方同名的 prop ----
    property int tone: Enums.Neutral
    property int size: Enums.Default        // Small / Default / Inherit
    property bool disabled: false
    property bool link: false
    property bool underline: false
    property bool strong: false
    property bool mark: false
    property bool code: false
    property bool deleted: false             // 官方叫 delete，QML 里是保留字
    property string icon: ""
    property int weight: Font.Normal
    property var copyable: false             // true | { content, icon, onCopy, duration }
    property var ellipsis: false             // true | { rows, pos, suffix, showTooltip, expandable, collapsible }

    // size 为 Inherit 时顺 parent 链找最近的排版组件（官方是 SizeContext）
    readonly property int resolvedSize: {
        if (control.size !== Enums.Inherit)
            return control.size;
        let p = control.parent;
        while (p) {
            const tp = p as TypographyBase;
            if (tp !== null && tp.size !== Enums.Inherit)
                return tp.size;
            p = p.parent;
        }
        return Enums.Default;
    }

    readonly property bool isSmall: control.resolvedSize === Enums.Small

    // ---- 颜色 ----
    // 链接禁用态官方不换灰，仍是 link 色（$color-typography_link-text-disabled）
    readonly property int linkPhase: linkPress.pressed ? 2
        : (linkHover.hovered && control.enabled ? 1 : 0)
    color: {
        if (control.link)
            return control.disabled ? Theme.current.colorLink
                : control.linkPhase === 2 ? Theme.current.colorLinkActive
                : control.linkPhase === 1 ? Theme.current.colorLinkHover
                : Theme.current.colorLink;
        if (control.disabled)
            return Theme.current.colorDisabledText;
        if (control.code)
            return Theme.current.colorText2;      // $color-typography_code-text-default
        return Appearance.textColor(Theme.current, control.tone);
    }

    // ---- 字号 / 行高 / 字重 ----
    font.pixelSize: control.isSmall ? Theme.current.fontSizeSmall : Theme.current.fontSizeRegular
    font.weight: control.weight !== Font.Normal ? control.weight
        : (control.link || control.strong) ? Font.DemiBold : Font.Normal
    // v>=1.0 起链接默认不带下划线；带 underline 时官方也不是 <u>，
    // 而是 hover / active 才出现的 1px border-bottom（typography.scss:105-113）
    font.underline: control.underline && !control.link
    font.strikeout: control.deleted
    lineHeight: control.isSmall ? 16 : 20
    lineHeightMode: Text.FixedHeight
    wrapMode: Text.WordWrap

    // ---- code / mark 的底色块 ----
    // code: padding 2px 4px + 1px 描边 + 圆角 2（$radius-typography_code 是写死的 2px，
    // 不是全局的 radius-extra-small=3）；mark 只有底色、没有内缩
    leftPadding: (control.code ? Theme.current.spacingExtraTight : 0)
        + (control.icon !== "" ? 16 + Theme.current.spacingExtraTight : 0)
    // rightPadding 在文件下面和「展开」按钮的占位一起算
    topPadding: control.code ? Theme.current.spacingSuperTight : 0
    bottomPadding: control.code ? Theme.current.spacingSuperTight : 0

    Rectangle {
        visible: control.code
        z: -1
        anchors.fill: parent
        radius: 2
        color: Theme.current.colorFill1
        border.width: 1
        border.color: Theme.current.colorBorder
    }

    Rectangle {
        visible: control.mark && !control.code
        z: -2
        anchors.fill: parent
        color: Theme.current.colorPrimaryLightDefault
    }

    // ---- 前缀图标（$spacing-typography_iconPrefix-marginRight = 4，color: inherit）----
    Icon {
        x: 0
        anchors.verticalCenter: control.verticalCenter
        visible: control.icon !== ""
        name: control.icon
        size: 16
        color: control.color
    }

    // ---- copyable ----
    // 官方：未复制时是 link 色的 copy 图标 + Tooltip「复制」；
    // 点完换成 success 色的 tick + 「复制成功」（文字是 text-2），3s 后复位。
    readonly property bool copyableOn: control.copyable === true
        || (control.copyable !== undefined && control.copyable !== null
            && typeof control.copyable === "object")
    readonly property string copyContent: control.copyableOn && control.copyable.content !== undefined
        ? String(control.copyable.content) : control.text
    readonly property real copyDuration: control.copyableOn && control.copyable.duration !== undefined
        ? Number(control.copyable.duration) : 3

    property bool copied: false

    Item {
        id: copyAction

        x: control.width + Theme.current.spacingExtraTight      // $spacing-typography_copyIcon-marginLeft
        anchors.verticalCenter: control.verticalCenter
        visible: control.copyableOn
        width: Math.max(copyIcon.width, copiedRow.width)
        height: 16

        Icon {
            id: copyIcon

            visible: !control.copied
            name: control.copyableOn && control.copyable.icon !== undefined ? "" : "copy"
            size: 16
            color: Theme.current.colorLink
        }

        Row {
            id: copiedRow

            visible: control.copied
            spacing: Theme.current.spacingSuperTight

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "tick"
                size: 16
                color: Theme.current.colorSuccess
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("复制成功")
                color: Theme.current.colorText2
                font.pixelSize: control.font.pixelSize
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -2
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                copyField.text = control.copyContent;
                copyField.selectAll();
                copyField.copy();
                control.copied = true;
                copyTimer.restart();
                if (control.copyableOn && control.copyable.onCopy !== undefined)
                    control.copyable.onCopy(control.copyContent);
            }
        }

        Tooltip {
            target: copyIcon
            text: qsTr("复制")
            // 不要再绑 visible —— Tooltip 自己由挂在 target 上的 HoverHandler 驱动，
            // 写一条 visible 会把那个绑定整个拆掉（已知坑 14 的老毛病），
            // 结果是每个排版组件都常驻一个「复制」浮层。
            // 复制完成后 copyIcon 自己不可见，HoverHandler 拿不到悬停，浮层自然不再出现。
        }
    }

    TextInput {
        id: copyField

        visible: false
        width: 0
        height: 0
    }

    Timer {
        id: copyTimer

        interval: control.copyDuration * 1000
        onTriggered: control.copied = false
    }

    // ---- ellipsis ----
    readonly property bool ellipsisOn: control.ellipsis === true
        || (control.ellipsis !== undefined && control.ellipsis !== null
            && typeof control.ellipsis === "object")
    readonly property int ellipsisRows: control.ellipsisOn && control.ellipsis.rows !== undefined
        ? Number(control.ellipsis.rows) : 1
    readonly property bool ellipsisMiddle: control.ellipsisOn && control.ellipsis.pos === "middle"
    readonly property string ellipsisSuffix: control.ellipsisOn && control.ellipsis.suffix !== undefined
        ? String(control.ellipsis.suffix) : ""
    readonly property bool ellipsisTooltip: control.ellipsisOn && control.ellipsis.showTooltip === true
    readonly property bool expandable: control.ellipsisOn && control.ellipsis.expandable === true

    property bool expanded: false

    readonly property bool _shouldClamp: control.ellipsisOn && !control.expanded
    elide: control._shouldClamp
        ? (control.ellipsisMiddle ? Text.ElideMiddle : Text.ElideRight) : Text.ElideNone
    maximumLineCount: control._shouldClamp ? control.ellipsisRows : -1

    // Qt 6.11 的 Text 与 Label 都没有 display（实测），所以官方那个跟着截断点走的
    // suffix 改成钉在末行右下角，并在 rightPadding 里给它留出位置。
    Text {
        id: suffixLabel

        visible: control._shouldClamp && control.ellipsisSuffix !== ""
        anchors.right: control.right
        anchors.bottom: control.bottom
        text: control.ellipsisSuffix
        color: control.color
        font: control.font
    }

    // 截断判定用 Qt 自带的 Text.truncated（6.11 上有这个属性，反倒没有
    // Controls.Label 那套 textTrimmed —— 别照搬 Controls 的名字）。
    // 浮层用 Loader 造：Tooltip 的 visible 由它自己挂在 target 上的 HoverHandler
    // 驱动，外面不能再绑一条 visible（会把绑定拆掉，见上面 copyable 那条注释）。
    Loader {
        active: control.ellipsisTooltip && control._shouldClamp && control.truncated
        sourceComponent: Component {
            Tooltip {
                target: control
                text: control.text + control.ellipsisSuffix
            }
        }
    }

    // 展开 / 收起：官方把它排在最后一行末尾（margin-left 8）。
    // QML 的 Text 没有内联子节点，这里把它锚到底行右侧，并给正文留出它的宽度。
    readonly property real expandActionWidth: control.expandable && control._shouldClamp
        ? expandLabel.implicitWidth + Theme.current.spacingTight : 0
    rightPadding: (control.code ? Theme.current.spacingExtraTight : 0)
        + control.expandActionWidth
        + (suffixLabel.visible ? suffixLabel.implicitWidth : 0)

    Text {
        id: expandLabel

        visible: control.expandable
        anchors.right: control.right
        anchors.bottom: control.bottom
        text: control.expanded ? qsTr("收起") : qsTr("展开")
        color: Theme.current.colorLink
        font.pixelSize: control.font.pixelSize
        font.weight: Font.DemiBold

        MouseArea {
            anchors.fill: parent
            anchors.margins: -2
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                control.expanded = !control.expanded;
                if (control.ellipsisOn && control.ellipsis.onExpand !== undefined)
                    control.ellipsis.onExpand(control.expanded);
            }
        }
    }

    HoverHandler {
        id: linkHover

        enabled: control.link && !control.disabled
    }

    TapHandler {
        id: linkPress

        enabled: control.link && !control.disabled
    }
}
