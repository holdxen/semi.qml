pragma ComponentBehavior: Bound

import QtQuick

// Transfer 右侧的已选行。默认行照 transfer.scss 的 .semi-transfer-item / -right-item
// 排（左右内边距 12/9、最小高 36、正文 text-0、关闭图标 12px 平时不可见、悬浮才出现）；
// 给了 renderSelectedItem 时正文交给用户，但拖拽手柄仍由这一层画（官方
// sortableHandle 是 render-prop，QML 没有等价物，见 Transfer.qml 顶部说明）。
//
// 拆成单独文件是因为同一份行内容要出现在两个地方：普通列表的 Repeater 代理，
// 和 virtualize 打开时 ListView 的代理。
Item {
    id: row

    // 由外壳（Repeater / ListView 代理）注入。名字不带 modelData / index：
    // 那两个名字留给代理自己的 required property。
    property var transfer: null
    property var rowData: ({})
    property int rowIndex: -1
    // 让位位移：拖别的行时被拖区覆盖到的行会挪开
    property real shift: 0
    // 指针位移：只有正在拖的这一行会被写
    property real pointerOffset: 0

    readonly property bool hovering: rowHover.hovered
    // 右侧那一行本身不可点（官方 cursor: auto），唯一的可点处是关闭图标，
    // 所以 CSS 的 .semi-transfer-item:active 只能由它的按下态驱动
    readonly property bool pressed: closeTap.pressed
    readonly property bool custom: row.transfer !== null && row.transfer.renderSelectedItem !== null
    readonly property bool dragging: row.transfer !== null && row.transfer._dragIndex === row.rowIndex
    readonly property bool dragEnabled: row.transfer !== null && row.transfer.draggable
        && row.transfer.interactive
    readonly property bool itemDisabled: row.rowData !== undefined
        && row.rowData !== null && row.rowData.disabled === true
    // .semi-transfer-item-close-icon-disabled：禁用项悬浮时也不给关闭
    readonly property bool closeShown: row.hovering && !row.itemDisabled

    readonly property real minHeight: 36                              // $height-transfer_item-minHeight
    readonly property real padLeft: Theme.current.spacingBaseTight    // 12
    readonly property real padRight: 9                                // $spacing-transfer_item-paddingRight
    readonly property real handleW: Theme.current.widthIconMedium     // 16
    readonly property real closeW: Theme.current.widthIconSmall       // $width-transfer_item_close-icon
    readonly property real dragGap: Theme.current.spacingExtraTight   // 4
    readonly property real leadWidth: row.dragEnabled ? row.handleW + row.dragGap : 0

    // 官方 .semi-transfer-right-item-sortable-item-active { opacity: 0 } 配 DragOverlay
    // 副本；QML 里没有浮层，直接让原位那一行跟着指针走，看到的还是一个副本在飞、
    // 原来的槽位空着。
    transform: Translate {
        y: row.dragging ? row.pointerOffset : row.shift
    }
    z: row.dragging ? 1 : 0

    implicitWidth: 200
    implicitHeight: Math.max(row.minHeight,
                             row.custom ? bodyLoader.implicitHeight : 20 + 8)

    // 测试用 seams
    readonly property var _text: bodyText
    readonly property var _close: closeIcon
    readonly property var _handle: handleIcon
    readonly property var _custom: bodyLoader

    // .semi-transfer-item:hover / :active。自定义行的底色归用户
    // （官方 demo 的 css 块自己写了 &:hover { background-color: fill-0 }）
    Rectangle {
        objectName: "rightRowBg" + row.rowIndex

        anchors.fill: parent
        visible: !row.custom
        color: !row.transfer || !row.transfer.interactive
            ? "transparent"
            : (row.pressed ? Theme.current.colorFill1
                : (row.hovering ? Theme.current.colorFill0 : "transparent"))
    }

    HoverHandler {
        id: rowHover
    }

    // 关闭图标：官方平时 visibility: hidden（照样占位），悬浮时可见。
    // QML 用 opacity + enabled 复刻同一条语义：占位不变、点不到。
    Icon {
        id: closeIcon

        objectName: "rightClose" + row.rowIndex
        width: row.closeW
        height: row.closeW
        x: row.width - row.padRight - row.closeW
        anchors.verticalCenter: parent.verticalCenter
        name: "close"
        color: Theme.current.colorText2                   // $color-transfer_close_icon-icon
        opacity: row.closeShown ? 1 : 0
        enabled: row.closeShown

        TapHandler {
            id: closeTap

            onTapped: row.transfer.removeAt(row.rowData)
        }
    }

    // 正文：.semi-transfer-right-item-text { flex: 1; word-break: break-all }
    Text {
        id: bodyText

        objectName: "rightText" + row.rowIndex
        visible: !row.custom
        x: row.padLeft + row.leadWidth
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, row.width - row.padLeft - row.padRight - row.leadWidth - row.closeW)
        text: row.transfer === null ? "" : row.transfer.rightLabel(row.rowData)
        color: row.transfer !== null && !row.transfer.interactive
            ? Theme.current.colorDisabledText             // .semi-transfer-disabled .semi-transfer-item
            : Theme.current.colorText0                    // $color-transfer_selected_item-text
        font.pixelSize: Theme.current.fontSizeRegular
        lineHeight: 20
        lineHeightMode: Text.FixedHeight
        wrapMode: Text.WrapAnywhere
        elide: Text.ElideRight
    }

    // 拖拽手柄：官方 IconHandle 在行首，margin-right 4
    Icon {
        id: handleIcon

        objectName: "rightHandle" + row.rowIndex
        visible: row.dragEnabled
        width: row.handleW
        height: row.handleW
        x: row.padLeft
        anchors.verticalCenter: parent.verticalCenter
        name: "handle"
        color: Theme.current.colorText2

        DragHandler {
            id: rowDrag

            target: null
            enabled: row.dragEnabled

            onActiveChanged: {
                if (active) {
                    row.transfer.beginDrag(row.rowIndex, row.height);
                } else {
                    row.pointerOffset = 0;
                    row.transfer.endDrag();
                }
            }

            onTranslationChanged: {
                if (!active)
                    return;
                row.pointerOffset = translation.y;
                row.transfer.updateDrop(row.rowIndex, row.y + row.height / 2 + translation.y);
            }
        }
    }

    Loader {
        id: bodyLoader

        objectName: "selectedItemLoader" + row.rowIndex
        active: row.custom
        visible: row.custom
        x: row.padLeft + row.leadWidth
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: row.transfer === null ? null : row.transfer.renderSelectedItem
        onItemChanged: row.injectCustom()

        // 同左侧：根项宽度铺满，高度由根项 implicitHeight 决定
        Binding {
            target: bodyLoader.item
            when: bodyLoader.item !== null
            property: "width"
            value: Math.max(0, row.width - row.padLeft - row.padRight - row.leadWidth)
        }

        Binding {
            target: bodyLoader.item
            when: bodyLoader.item !== null
            property: "modelData"
            value: row.rowData
        }

        Binding {
            target: bodyLoader.item
            when: bodyLoader.item !== null
            property: "hovered"
            value: row.hovering
        }

        Binding {
            target: bodyLoader.item
            when: bodyLoader.item !== null
            property: "index"
            value: row.rowIndex
        }
    }

    // 函数入参只能直接赋值：Binding 的 value 给函数时，即使 when:false 也会报
    // 「Unable to assign a function to a property of any type other than a var」
    function injectCustom() {
        if (bodyLoader.item === null)
            return;
        bodyLoader.item.remove = function () {
            row.transfer.removeAt(row.rowData);
        };
    }
}
