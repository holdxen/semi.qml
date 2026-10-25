pragma ComponentBehavior: Bound

import QtQuick

// Tree 的一行。半公开：只由 Tree.qml 实例化（普通行、展开动画那一段、虚拟化都走这里），
// 排版口径全部从 host（Tree 控件）上取，本文件不存业务状态。
//
// 对应 semi-ui/tree/treeNode.tsx 的 render()：
//     <li class="semi-tree-option">            ← padding: 4px 0 4px 8px，display:flex
//         <Indent level isEnd/>                 ← level 个 20px 槽，showLine 时槽内 x=6 一条 1px 竖线
//         {renderArrow()}                       ← 三角 / Spin / 连接线开关 / 12px 空图标
//         <span class="-label">                 ← blockNode 时 flex:1，否则收缩到内容宽
//             {multiple ? <Checkbox/> : null}
//             {renderIcon()}
//             <span class="-label-text">{label}</span>
//         </span>
//     </li>
//
// 两套底色是这个文件最容易写错的地方（tree.scss:92-103 与 :361-449）：
//   · blockNode=true（缺省）：底色画在整行上，悬浮 fill-0、按下 fill-1，选中压过这两条；
//     箭头列的 :hover/:active 变色也只写在这个作用域里；
//   · blockNode=false：行本身没有底色，只有被直接悬停的那块文字亮 fill-0/fill-1（圆角 3），
//     选中时整块 -label 上 primary-light-default，同样只包到内容末尾。
// 禁用行官方只改文字颜色，底色规则没有 disabled 门槛 ⇒ 悬浮照样亮，这里也不拦。
//
// 行高：内容是 20px 一行（font-size-regular 的行高），加上下 padding 4 ⇒ 28。label 太长
// 官方会换行（li 上是 word-break: break-word），于是这一行变高 —— 所以行高是从内容算出来的，
// 不是定值；只有虚拟化档被 itemSize 钉死（react-window 给的 style 带固定高度）。
Item {
    id: row

    property var host: null
    // renderRows 里的下标；组（展开动画那一段）里再用 rowIndex 取第 i 条
    property int groupIndex: 0
    property int rowIndex: 0
    // 这一行在「列表内容坐标系」（host.rowSpace）里的上沿与被裁掉的下边界。
    // 底色要看指针，而指针记在 host 的容器项上（行委托会被 Repeater 整个重建，
    // 挂在这上面的 HoverHandler 重建那一拍不知道指针已经在里面 ⇒ 底色闪一下）。
    // 位置只能由知道自己在第几格的委托传进来：mapToItem 写在绑定里不吃依赖。
    property real originInColumn: 0
    property real clipBottom: Number.MAX_VALUE

    readonly property var rec: row.host ? row.host.rowRecord(row.groupIndex, row.rowIndex) : null
    readonly property string nodeKey: row.rec !== null && row.rec.key !== undefined
        ? String(row.rec.key) : ""
    readonly property int level: row.rec !== null && row.rec.level !== undefined
        ? row.rec.level : 0
    readonly property bool expanded: row.rec !== null && row.rec.expanded === true
    readonly property bool loading: row.rec !== null && row.rec.loading === true
    readonly property bool selected: row.rec !== null && row.rec.selected === true
    readonly property bool checked: row.rec !== null && row.rec.checked === true
    readonly property bool halfChecked: row.rec !== null && row.rec.halfChecked === true
    readonly property bool off: row.rec !== null && row.rec.disabled === true
    readonly property bool filtered: row.rec !== null && row.rec.filtered === true
    readonly property bool isLeaf: row.rec !== null && row.rec.isLeaf === true
    readonly property bool hasChildren: row.rec !== null && row.rec.hasChildren === true
    readonly property string labelText: row.rec !== null && row.rec.labelText !== undefined
        ? row.rec.labelText : ""
    readonly property string keyword: row.rec !== null && row.rec.keyword !== undefined
        ? row.rec.keyword : ""
    readonly property bool isEndNode: row.rec !== null && row.rec.isEnd !== undefined
        && row.rec.isEnd[row.rec.isEnd.length - 1] === true

    // -draggable 类要 !disabled && draggable && !renderFullLabel（treeNode.tsx:385）
    readonly property bool dragCapable: row.host !== null && row.host.draggable
        && !row.off && !row.host.renderFullLabelOn
    readonly property real shiftX: row.dragCapable ? row.host.dragBorder : 0

    // ---------------------------------------------------------------- 分段横坐标
    readonly property real indentX: row.host.level1Pad + row.level * row.host.indentStep + row.shiftX
    readonly property real caretX: row.indentX
    readonly property real labelX: row.caretX + row.host.caretBox + row.host.iconGap
    readonly property real checkX: row.labelX
    readonly property real iconX: row.labelX
        + (row.host.multiple ? row.host.checkBox + row.host.iconGap : 0)
    // renderFullLabel 换掉的是整个 li 的内容（treeNode.tsx 里那条 if 直接 return），
    // 行内那枚节点图标也跟着不再画，否则自定义行里自己画的那枚会和它叠成两个。
    readonly property bool iconShown: row.rec !== null
        && row.rec.iconKind !== undefined && row.rec.iconKind !== "none"
        && !row.host.renderFullLabelOn
    readonly property real textX: row.iconX
        + (row.iconShown ? row.host.iconBox + row.host.iconGap : 0)
    readonly property real availWidth: Math.max(0, row.width - row.textX)
    // 非整行档时文字用自然宽（-label 收缩到内容），整行档吃满剩余宽
    readonly property real naturalWidth: row.host.blockNode
        ? row.availWidth : Math.min(textProbe.implicitWidth, row.availWidth)
    readonly property bool slotted: row.activeRenderer === "slot" || row.activeRenderer === "hook"
    readonly property var slotItem: row.activeRenderer === "hook" ? renderLabelSlot
        : (row.activeRenderer === "slot" ? labelSlot : null)
    readonly property real slotWidth: row.slotItem === null || row.slotItem.item === null
        ? 0 : row.slotItem.item.implicitWidth
    readonly property real slotHeight: row.slotItem === null || row.slotItem.item === null
        ? 0 : row.slotItem.item.implicitHeight
    readonly property real textWidth: row.slotted ? row.slotWidth : row.naturalWidth
    readonly property real textHeight: row.slotted ? row.slotHeight
        : (row.useHighlight ? hitText.height : plainText.height)
    // -label 的右界：blockNode 时铺到行尾，否则到文字末尾
    readonly property real labelEnd: row.host.blockNode ? row.width : (row.textX + row.textWidth)
    readonly property real contentHeight: Math.max(row.host.textBoxHeight, row.textHeight)
    readonly property real contentMid: row.host.rowPadY + row.contentHeight / 2

    // 这一行的文字到底是哪种渲染：钩子 > 组件档 label > 高亮 > 纯文本
    readonly property string activeRenderer: row.host.renderLabelComp !== null ? "hook"
        : (row.rec !== null && row.rec.labelKind === "slot" ? "slot"
            : (row.useHighlight ? "highlight" : "text"))
    readonly property bool useHighlight: row.host.renderLabelComp === null && row.filtered
        && row.keyword !== "" && row.rec !== null && row.rec.labelKind === "text"

    implicitWidth: row.host ? row.host.rowInnerWidth : 0
    implicitHeight: row.host
        ? (row.host.useVirtualList ? row.host.rowHeight : row.host.rowPadY * 2 + row.contentHeight)
        : 0
    width: row.host ? row.host.rowInnerWidth : 0
    height: row.host
        ? (row.host.useVirtualList ? row.host.rowHeight : row.host.rowPadY * 2 + row.contentHeight)
        : 0
    clip: row.host !== null && row.host.useVirtualList

    // 探针：永远单行、不限宽，只用来量自然宽（非整行档的底色框要靠它）
    Text {
        id: textProbe

        visible: false
        text: row.labelText
        font.pixelSize: Theme.current.fontSizeRegular
    }

    // ---------------------------------------------------------------- 行底色（blockNode）
    Rectangle {
        id: blockBg

        objectName: "treeRowBg"

        visible: row.host.blockNode && !row.host.renderFullLabelOn
        z: -2
        anchors.fill: parent
        // 官方三条特异度相同、后写的盖前面的：selected > active > hover；
        // transition 时长是 --semi-transition_duration-none ⇒ 不变动画
        color: row.selected
            ? Theme.current.colorPrimaryLightDefault
            : (row.blockPressed
                ? Theme.current.colorFill1
                : (row.blockHovered ? Theme.current.colorFill0 : "transparent"))
    }

    // ---------------------------------------------------------------- 指针判定
    // 三个「悬停」都按 host 记下的指针位置算，不用行上的 HoverHandler：
    // 展开/收起动画起手与收尾各有一次 Repeater 重建（模型条目数变了），新委托上的
    // handler 要等下一个鼠标事件才认得已经在里面的指针 ⇒ 被点那一行会掉一帧底色。
    // 容器项不是委托，位置一直有效；官方 :hover 判的本来就是「指针在不在这块盒子里」。
    readonly property real px: row.host.hoverPoint.x
    readonly property real py: row.host.hoverPoint.y - row.originInColumn
    // 被动画盒裁掉的那截不算（CSS overflow:hidden 把 :hover 一起裁了）
    readonly property bool overRow: row.host.hoverInside
        && row.px >= 0 && row.px < row.width
        && row.py >= 0 && row.py < row.height
        && row.host.hoverPoint.y < row.clipBottom

    // 悬浮/按下只看位置，不看 disabled（官方底色规则没有 disabled 门槛）
    readonly property bool blockHovered: row.host.blockNode && row.overRow
    readonly property bool blockPressed: row.host.blockNode && rowTap.pressed

    readonly property bool caretHovered: row.overRow
        && row.px >= row.caretX && row.px < row.caretX + row.host.caretBox
        && row.py >= row.contentMid - row.host.caretBox / 2
        && row.py < row.contentMid + row.host.caretBox / 2
    readonly property bool textHovered: row.overRow
        && row.px >= row.textX && row.px < row.textX + row.textWidth
        && row.py >= row.contentMid - row.textHeight / 2
        && row.py < row.contentMid + row.textHeight / 2

    // ---------------------------------------------------------------- 连接线：缩进竖线
    Repeater {
        id: lineRepeater

        readonly property string probeTag: "units"

        model: row.host.showLine && !row.host.renderFullLabelOn ? row.level : 0

        delegate: Rectangle {
            id: indentUnit

            required property int index

            objectName: "treeIndentUnit"

            x: row.host.level1Pad + index * row.host.indentStep + row.shiftX
                + row.host.caretBox / 2 - row.host.lineWidth / 2
            // indent-unit 是 align-self:stretch（内容区那么高），::before 再上下各超 4px
            // 补齐 li 的 padding ⇒ 正好铺满整个行框，行与行连成一条线；
            // draggable 档 padding 挪到 label 上（top/bottom 改成 0），最终铺满的仍然是整行
            y: 0
            height: row.height
            visible: row.lineVisibleFor(index)
            color: Theme.current.colorText3
        }
    }

    // 连接线那一格画不画：isEnd[i] 为真 = 第 i 层祖先是本层最后一个孩子 ⇒ 停线
    function lineItemAt(index) {
        return lineRepeater.itemAt(index);
    }

    readonly property int lineUnitCount: lineRepeater.count

    function lineVisibleFor(index) {
        if (!row.host.showLine)
            return false;
        if (row.rec === null || row.rec.isEnd === undefined)
            return true;
        return row.rec.isEnd[index] !== true;
    }

    // indent.tsx:14-22：每个祖先层级一个 20px 槽
    function ancestorIsEnd(index) {
        return row.rec !== null && row.rec.isEnd !== undefined
            && row.rec.isEnd[index] === true;
    }

    // ---------------------------------------------------------------- 箭头列
    // 列宽 12 + 右外边距 8；里面按 renderArrow()（treeNode.tsx:205-247）四路分支
    Item {
        id: caretCol

        objectName: "treeCaret"

        visible: !row.host.renderFullLabelOn
        x: row.caretX
        y: row.contentMid - row.host.caretBox / 2
        width: row.host.caretBox
        height: row.host.caretBox

        Loader {
            id: caretArt

            anchors.fill: parent
            sourceComponent: row.caretComponent()
        }

        // 官方那两条箭头变色是 `.semi-tree-option-expand-icon:hover / :active`
        // ⇒ 变色判定按指针位置算（见上面 px/py），点击动作仍由行上那一只 rowTap 按落点分流
        // （Qt 6.11 的 TapHandler 没有 grabBehavior，实测父子两级 handler 会都收到同一次点击，
        // 所以小块只观察不动作）。
        TapHandler {
            id: caretPressTap

            acceptedButtons: Qt.LeftButton
        }
    }

    readonly property bool caretPressed: caretPressTap.pressed

    function caretComponent() {
        if (row.host === null || row.rec === null)
            return null;
        if (row.loading)
            return spinBlock;
        if (!row.isLeaf) {
            const kind = row.host.caretArtKind(row.groupIndex, row.rowIndex);
            if (kind === "name")
                return caretNameBlock;
            if (kind === "slot")
                return caretSlotBlock;
            return triangleBlock;
        }
        if (row.host.showLine)
            return leafLineBlock;
        // 叶子且没连接线：官方放一个 12px 的 -empty-icon 占位，什么都不画
        return null;
    }

    // 自定义整行时也要能把这枚箭头递出去（官方 renderFullLabel 的 expandIcon 入参）。
    // 不能直接递 triangleBlock：那几个小块是 anchors.fill: parent，靠行内那个 12×12
    // 槽子撑起来，钩子那边的 Loader 没给宽高就会塌成 0。这里包一层自带隐式尺寸的。
    Component {
        id: caretHookBlock

        Item {
            implicitWidth: row.host.caretBox
            implicitHeight: row.host.caretBox

            Loader {
                anchors.fill: parent
                sourceComponent: row.caretComponent()
            }
        }
    }

    readonly property Component caretBlockRef: caretHookBlock

    Component {
        id: spinBlock

        Item {
            implicitWidth: row.host.caretBox
            implicitHeight: row.host.caretBox

            Spin {
                objectName: "treeCaretSpin"

                anchors.centerIn: parent
                size: "small"
                // $width-tree_spinIcon = 12，本库 Spin 最小档 14 ⇒ 缩放补齐
                scale: row.host.caretBox / 14
                color: Theme.current.colorPrimary
            }
        }
    }

    Component {
        id: triangleBlock

        Icon {
            objectName: "treeCaretIcon"

            anchors.fill: parent
            name: "tree_triangle_down"
            size: Math.round(row.host.caretBox)
            // $color-tree_option-icon-default；:hover text-0、:active black 只写在 blockNode 作用域
            color: !row.host.blockNode ? Theme.current.colorText2
                : (row.caretPressed ? Theme.current.colorBlack
                    : (row.caretHovered ? Theme.current.colorText0 : Theme.current.colorText2))
            // -collapsed { transform: rotate(270deg) }
            rotation: row.expanded ? 0 : 270
            Behavior on rotation {
                NumberAnimation { duration: Theme.current.durationFast }
            }
        }
    }

    Component {
        id: caretNameBlock

        Icon {
            objectName: "treeCaretCustom"

            anchors.fill: parent
            name: row.host.caretArtValue(row.groupIndex, row.rowIndex)
            size: Math.round(row.host.caretBox)
            color: row.host.blockNode && row.caretHovered
                ? Theme.current.colorText0 : Theme.current.colorText2
        }
    }

    Component {
        id: caretSlotBlock

        Loader {
            objectName: "treeCaretSlot"

            sourceComponent: row.host.caretArtKind(row.groupIndex, row.rowIndex) === "slot"
                ? row.host.caretArtValue(row.groupIndex, row.rowIndex) : null
        }
    }

    Component {
        id: leafLineBlock

        Item {
            implicitWidth: row.host.caretBox
            implicitHeight: row.host.caretBox

            // switcher-leaf-line::before；最后一条叶子只画上半截（-tree-node-last-leaf）
            Rectangle {
                objectName: "treeLeafVLine"

                x: row.host.caretBox / 2 - row.host.lineWidth / 2
                y: 0
                width: row.host.lineWidth
                height: row.isEndNode ? row.height / 2 : row.height
                color: Theme.current.colorText3
            }

            // ::after —— 宽 (20/2)*0.8、落在行垂直中点的水平短线
            Rectangle {
                objectName: "treeLeafHLine"

                x: row.host.caretBox / 2 + row.host.lineWidth
                y: row.contentMid
                width: row.host.indentStep / 2 * 0.8
                height: row.host.lineWidth
                color: Theme.current.colorText3
            }
        }
    }

    // ---------------------------------------------------------------- 复选框
    Checkbox {
        id: nodeCheck

        objectName: "treeCheck"

        visible: row.host.multiple && !row.host.renderFullLabelOn
        x: row.checkX
        y: row.contentMid - height / 2
        disabled: row.off
        indeterminate: row.halfChecked

        // 官方 checkbox 的 checked 完全跟着选中集合走（index.tsx:905 外面套了
        // CheckboxGroup value=checkedKeys，受控 ⇒ 点一下不会自己翻面）。本库 Checkbox
        // 会自翻 ⇒ 用 Binding 按回去，同 Transfer / TreeSelect；再加一条兜底：
        // 受控被拒时 row.checked 根本不变，Binding 的 value 没有 changed 就不会重写，
        // 靠 onCheckedChanged 发现不一致立刻按回去。
        Binding {
            target: nodeCheck
            property: "checked"
            value: row.checked
            restoreMode: Binding.RestoreBindingOrValue
        }

        onCheckedChanged: {
            if (row.checkSyncing)
                return;
            if (nodeCheck.checked !== row.checked) {
                row.checkSyncing = true;
                nodeCheck.checked = row.checked;
                row.checkSyncing = false;
            }
        }
    }

    // 自翻与按回之间的那道闸：只在按回的时候打开，避免来回弹
    property bool checkSyncing: false

    // ---------------------------------------------------------------- 节点图标
    readonly property var iconSlotComp: row.iconShown && row.rec.iconKind === "slot"
        ? row.rec.iconValue : null
    readonly property var iconItem: iconSlot.item
    readonly property var hookItem: renderLabelSlot.item

    Loader {
        id: iconSlot

        objectName: "treeIconSlot"

        visible: row.iconSlotComp !== null
        x: row.iconX
        y: row.contentMid - (row.iconItem === null ? 0 : row.iconItem.implicitHeight / 2)
        sourceComponent: row.iconSlotComp
    }

    Icon {
        id: nodeIcon

        objectName: "treeIconName"

        visible: row.iconShown && row.rec.iconKind === "name"
        x: row.iconX
        y: row.contentMid - row.host.iconBox / 2
        name: row.iconShown && row.rec.iconKind === "name" ? String(row.rec.iconValue) : ""
        size: row.host.iconBox
        color: Theme.current.colorText2      // $color-tree_option-icon-default
    }

    // ---------------------------------------------------------------- 文字区
    readonly property var labelSlotComp: row.host.renderLabelComp === null
        && row.rec !== null && row.rec.labelKind === "slot" ? row.rec.labelValue : null

    // 官方那条 :hover/:active 落在 .semi-tree-option-label-text 这一块上（它 flex:1
    // 或者收缩到内容），所以判定区域就是下面这个框；四种渲染器都摆进同一个框里。
    Item {
        id: textZone

        objectName: "treeTextZone"

        visible: !row.host.renderFullLabelOn
        x: row.textX
        y: row.contentMid - row.textHeight / 2
        width: row.textWidth
        height: row.textHeight

        Loader {
            id: renderLabelSlot

            objectName: "treeRenderLabelHook"

            visible: row.host.renderLabelComp !== null
            sourceComponent: row.host.renderLabelComp
            onLoaded: row.host.injectRenderLabel(item, row.groupIndex, row.rowIndex)
        }

        Loader {
            id: labelSlot

            objectName: "treeLabelSlot"

            visible: row.labelSlotComp !== null
            sourceComponent: row.labelSlotComp

            // 整行档：-label-text 是 flex:1（blockNode 下还 width:0），组件档要吃满剩余宽；
            // 非整行档 -label 收缩到内容，所以不给宽度，让载入项自己按隐式尺寸排
            Binding {
                target: labelSlot
                property: "width"
                value: row.availWidth
                when: row.host.blockNode
                restoreMode: Binding.RestoreBindingOrValue
            }
        }

        Text {
            id: plainText

            objectName: "treeLabelText"

            visible: row.activeRenderer === "text"
            width: row.textWidth
            text: row.labelText
            color: row.off ? Theme.current.colorDisabledText : Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            // labelEllipsis（虚拟化档缺省开）→ 单行省略；否则 word-break: break-word
            elide: row.host.labelEllipsisOn ? Text.ElideRight : Text.ElideNone
            wrapMode: row.host.labelEllipsisOn ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
        }

        // 搜索命中的那段：官方套 Highlight，`.semi-tree-option-highlight` = primary + 字重 600
        // + background-color: inherit（把 mark 自带的黄底压掉）。QML 的 span 不认 inherit，
        // 而我们的行底色是另一层 Rectangle ⇒ transparent 与 inherit 在这等价。
        Highlight {
            id: hitText

            objectName: "treeLabelHighlight"

            visible: row.activeRenderer === "highlight"
            width: row.textWidth
            sourceString: row.labelText
            searchWords: row.keyword !== "" ? [row.keyword] : []
            component: "span"
            highlightStyle: ({ "color": Theme.current.colorPrimary,
                "background-color": "transparent", "font-weight": 600 })
        }

        TapHandler {
            id: textPressTap

            acceptedButtons: Qt.LeftButton
        }
    }

    readonly property bool textPressed: textPressTap.pressed

    // ---------------------------------------------------------------- 非整行档的底色
    // .semi-tree-option-label-text:hover / :active（tree.scss:92-103）：只有指针真落在
    // 那块文字上才亮，圆角 $radius-tree_checkbox_addon
    Rectangle {
        id: textBg

        objectName: "treeTextBg"

        visible: !row.host.blockNode && !row.host.renderFullLabelOn
            && row.activeRenderer === "text"
        z: -1
        x: row.textX
        y: row.contentMid - row.host.textBoxHeight / 2
        width: row.textWidth
        height: row.host.textBoxHeight
        radius: Theme.current.radiusSmall
        color: row.textPressed
            ? Theme.current.colorFill1
            : (row.textHovered ? Theme.current.colorFill0 : "transparent")
    }

    // blockNode=false 时选中底色画在整块 -label 上（tree.scss:120-129），
    // -label 从复选框（有则从它）开始
    Rectangle {
        id: labelBg

        objectName: "treeLabelBg"

        visible: !row.host.blockNode && row.selected && !row.host.renderFullLabelOn
        z: -2
        x: row.host.multiple ? row.checkX : row.iconX
        y: row.contentMid - row.host.textBoxHeight / 2
        width: Math.max(0, row.labelEnd - (row.host.multiple ? row.checkX : row.iconX))
        height: row.host.textBoxHeight
        radius: Theme.current.radiusSmall
        color: Theme.current.colorPrimaryLightDefault
    }

    // ---------------------------------------------------------------- 拖拽标示
    // -draggable：行左侧恒 2px（透明）边框
    Rectangle {
        objectName: "treeDragLeftEdge"

        visible: row.dragCapable
        x: 0
        y: 0
        width: row.host.dragBorder
        height: row.height
        color: row.dragOver ? Theme.current.colorPrimary : "transparent"
    }

    // drag-over（dropPosition===0）：整圈 2px primary
    Rectangle {
        objectName: "treeDragOverBox"

        visible: row.dragCapable && row.dragOver
        anchors.fill: parent
        color: "transparent"
        border.width: row.host.dragBorder
        border.color: Theme.current.colorPrimary
    }

    // gap-top / gap-bottom：label 的上/下边框上色（label 在 draggable 档贴着行上下沿）
    Rectangle {
        objectName: "treeDragGapTop"

        visible: row.dragCapable && row.dragGapTop
        x: row.labelX
        y: 0
        width: Math.max(0, row.labelEnd - row.labelX)
        height: row.host.dragBorder
        color: Theme.current.colorPrimary
    }

    Rectangle {
        objectName: "treeDragGapBottom"

        visible: row.dragCapable && row.dragGapBottom
        x: row.labelX
        y: row.height - row.host.dragBorder
        width: Math.max(0, row.labelEnd - row.labelX)
        height: row.host.dragBorder
        color: Theme.current.colorPrimary
    }

    // 上一行正被 drag-over、这一行是选中态时补一条上边线（`& + .-selected::after`），
    // 否则选中底色会盖住那条标示
    Rectangle {
        objectName: "treeDragSeam"

        visible: row.dragCapable && row.selected
            && row.host.prevDragOverSeam(row.groupIndex, row.rowIndex)
        x: -row.host.dragBorder
        y: 0
        width: row.width + 1 + row.host.dragBorder
        height: row.host.dragBorder
        color: Theme.current.colorPrimary
    }

    readonly property bool dragOver: row.host.dragOverOf(row.groupIndex, row.rowIndex)
    readonly property bool dragGapTop: row.host.dragGapTopOf(row.groupIndex, row.rowIndex)
    readonly property bool dragGapBottom: row.host.dragGapBottomOf(row.groupIndex, row.rowIndex)

    // ---------------------------------------------------------------- 整行自定义
    Loader {
        id: fullLabel

        objectName: "treeFullLabelHook"

        visible: row.host.renderFullLabelOn
        // -option-fullLabel-level-N { padding-left: 20*(N-1)+8 }：官方把缩进改成 li 的 padding
        x: row.host.level1Pad + row.level * row.host.indentStep + row.shiftX
        y: 0
        width: Math.max(0, row.width - row.host.level1Pad - row.level * row.host.indentStep - row.shiftX)
        height: row.height
        sourceComponent: row.host.renderFullLabel
        onLoaded: row.host.injectFullLabel(item, row.groupIndex, row.rowIndex,
            row.caretBlockRef)
    }

    // ---------------------------------------------------------------- 交互
    TapHandler {
        id: rowTap

        objectName: "treeRowTap"

        acceptedButtons: Qt.LeftButton
        // 官方把 onClick / onDoubleClick 挂在同一个 li 上，箭头与复选框各自
        // stopPropagation；QML 里两级 handler 都会收到同一次点击（实测），所以
        // 这里按落点横坐标分流，等价于官方那三次 stopPropagation。
        onTapped: (eventPoint) => {
            // 落点横坐标：eventPoint.position 是「所属项的父项」坐标系，统一换成行内坐标
            const local = row.mapFromItem(null, eventPoint.scenePosition.x,
                eventPoint.scenePosition.y)
            const x = local.x
            if (x >= row.caretX && x < row.caretX + row.host.caretBox) {
                if (!row.isLeaf && !row.loading)
                    row.host.requestExpand(row.nodeKey)
                return
            }
            if (row.host.multiple && x >= row.checkX && x < row.checkX + row.host.checkBox) {
                row.host.requestSelect(row.nodeKey)
                return
            }
            row.host.rowClicked(row.nodeKey)
        }

        // 浏览器里两下会发两次 click 加一次 dblclick，所以上面那次 tapped 不抑制
        onDoubleTapped: row.host.rowDoubleClicked(row.nodeKey)
    }

    TapHandler {
        objectName: "treeRowRightTap"

        acceptedButtons: Qt.RightButton
        onTapped: row.host.requestContextMenu(row.nodeKey)
    }
}
