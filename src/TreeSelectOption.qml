pragma ComponentBehavior: Bound

import QtQuick

// TreeSelect 下拉里的一行选项（.semi-tree-option）。规格照 tree.scss：
// 行高 28（上下 padding 4 + 行 20）、整行左 padding 8（$spacing-tight）、
// 每级缩进 20（$width-tree_option_indent-unit）、展开箭头 12 + 右 margin 8、
// 多选复选框 16 + 右 margin 8、正文 14/20 text-0。
//
// 单独成文件是因为同一份行要出现在两个地方：普通列表的 Repeater 代理，
// 和 virtualize 打开时 ListView 的代理（官方是 NodeList / VirtualList 两套）。
//
// rec 由 TreeSelect 侧算好整条记录再传进来：走 Repeater 的 modelData 会被
// QVariant 往返，嵌套数组（children / path）在代理里不再是 JS 数组，
// 所以这里只读标量字段，节点原始数据留在 rec.data 上给钩子用。
Item {
    id: row

    // 由外壳（Repeater / ListView 代理）注入。名字不带 modelData / index：
    // 那两个名字留给代理自己的 required property。
    property var ts: null
    property var rec: ({})
    property int rowIndex: -1
    // 这一行在列表内容坐标系（ts.rowSpace）里的上沿，与被动画盒裁掉后的下边界。
    // 底色/箭头变色按 ts 上记的指针位置算，不按行自己的 HoverHandler 算 —— 行委托在展开收起
    // 动画的起手与收尾各会被 Repeater 重建一次，新委托上的 handler 要等下一个鼠标事件才认得
    // 已经在里面的指针，那一帧底色就掉了（用户看到的是「被点那行一直在闪」）。
    property real originInColumn: 0
    property real clipBottom: Number.MAX_VALUE

    readonly property bool hovered: row.ts !== null && row.ts.hoverInside
        && row.ts.hoverPoint.x >= 0 && row.ts.hoverPoint.x < row.width
        && row.ts.hoverPoint.y >= row.originInColumn
        && row.ts.hoverPoint.y < row.originInColumn + row.height
        // 被动画盒裁掉的那截不算（CSS overflow:hidden 把 :hover 一起裁了）
        && row.ts.hoverPoint.y < row.clipBottom

    readonly property bool isLeaf: row.rec.hasChildren !== true
    readonly property bool matched: row.rec.matched === true
    readonly property bool off: row.rec.disabled === true
        || (row.ts !== null && row.ts.disabled)
    readonly property bool multiple: row.ts !== null && row.ts.multiple

    readonly property real padLeft: Theme.current.spacingTight            // li padding-left 8
    readonly property real indentUnit: 20                                  // 一级缩进
    readonly property real caretX: row.padLeft + row.rec.level * row.indentUnit
    readonly property real bodyX: row.caretX + Theme.current.widthIconSmall
        + Theme.current.spacingTight                                       // 箭头 12 + 右 margin 8
    readonly property real labelX: row.bodyX
        + (row.multiple ? Theme.current.widthIconMedium + Theme.current.spacingTight : 0)

    height: 28                                  // 4 + 20 + 4
    implicitHeight: 28

    // 测试用 seams
    readonly property var _bg: bg
    readonly property var _caret: caret
    readonly property var _spin: spin
    readonly property var _check: check
    readonly property var _label: label
    readonly property var _highlight: highlight

    Rectangle {
        id: bg

        objectName: "tsRowBg" + row.rowIndex
        anchors.fill: parent
        // .semi-tree-option:hover = fill-0、:active = fill-1、-selected = primary-light-default
        color: row.off
            ? "transparent"
            : (row.rec.selected === true
                ? Theme.current.colorPrimaryLightDefault
                : (rowPress.pressed
                    ? Theme.current.colorFill1
                    : (row.hovered ? Theme.current.colorFill0 : "transparent")))
    }

    // 整行点击 = 选中（官方 expandAction 默认 false，点行不展开）
    TapHandler {
        id: rowPress

        enabled: !row.off
        onTapped: {
            if (row.ts !== null)
                row.ts.handleNodeSelect(row.rec);
        }
    }

    // 展开箭头：官方是 IconTreeTriangleDown（本库图标集里没有这枚），
    // 用 chevron_right 转 90° 表达同一个「收起 / 展开」语义
    Icon {
        id: caret

        objectName: "tsCaret" + row.rowIndex
        width: Theme.current.widthIconSmall
        height: Theme.current.widthIconSmall
        x: row.caretX
        anchors.verticalCenter: parent.verticalCenter
        visible: !row.isLeaf
        name: "chevron_right"
        size: Theme.current.widthIconSmall
        color: row.hovered && !row.off ? Theme.current.colorText0 : Theme.current.colorText2
        rotation: row.rec.expanded === true ? 90 : 0

        TapHandler {
            onTapped: {
                if (row.ts !== null)
                    row.ts.toggleExpand(row.rec.key);
            }
        }
    }

    // 异步加载：官方把箭头换成 .semi-tree-option-spin-icon 里的 Spin
    Spin {
        id: spin

        objectName: "tsSpin" + row.rowIndex
        visible: row.rec.loading === true
        x: row.caretX
        anchors.verticalCenter: parent.verticalCenter
        size: "small"
    }

    // 多选时的复选框（官方只有 context.multiple 才挂 Checkbox）
    Checkbox {
        id: check

        objectName: "tsCheck" + row.rowIndex
        visible: row.multiple
        x: row.bodyX
        anchors.verticalCenter: parent.verticalCenter
        disabled: row.off
        indeterminate: row.rec.half === true

        Binding {
            target: check
            property: "checked"
            value: row.rec.checked === true
            restoreMode: Binding.RestoreBindingOrValue
        }

        // 复选框那一击与点标签走同一条 handleNodeSelect（官方 onCheck / onClick 都进它）
        onToggled: {
            if (row.ts !== null)
                row.ts.handleNodeSelect(row.rec);
        }
    }

    // 正文：命中搜索词时换成 Highlight（官方 .semi-tree-option-highlight = 主色 + 600）
    Text {
        id: label

        objectName: "tsLabel" + row.rowIndex
        visible: !row.matched
        x: row.labelX
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, row.width - row.labelX - row.padLeft)
        text: String(row.rec.label === undefined ? "" : row.rec.label)
        color: row.off
            ? Theme.current.colorDisabledText             // $color-tree_option-disabled-text
            : Theme.current.colorText0                    // $color-tree_option-text
        font.pixelSize: Theme.current.fontSizeRegular     // @include font-size-regular
        elide: row.ts !== null && row.ts.labelEllipsis ? Text.ElideRight : Text.ElideNone
        verticalAlignment: Text.AlignVCenter
    }

    Highlight {
        id: highlight

        objectName: "tsHighlight" + row.rowIndex
        visible: row.matched
        x: row.labelX
        anchors.verticalCenter: parent.verticalCenter
        sourceString: String(row.rec.label === undefined ? "" : row.rec.label)
        searchWords: [row.ts === null ? "" : row.ts._input]
    }
}
