pragma ComponentBehavior: Bound

import QtQuick
import "TableEngine.js" as Engine

// 列筛选面板。官方 ColumnFilter.tsx 是「Dropdown + 每项一个 Checkbox/Radio」，
// 面板本体只额外加两条：菜单最大高 290 后内滚（$height-table_column_filter_dropdown），
// 以及 filterConfirmMode:'confirm' 那一档的底部 重置 / 确定 两个小按钮
// （ColumnFilter.tsx:150-168 的 inline style：padding 8px 12px、上边 1px color-border、右对齐）。
//
// 项的度量来自 Dropdown：padding 8/16 ⇒ 行高 36、单项 max-width $width-dropdown、
// 悬浮 fill-0、面板底色 bg-3、圆角 6、阴影 shadow-elevated。
// 宽度由内容决定（官方是 Dropdown 自己量的），端口拿 TextMetrics 量最长那条筛选项：
//   16（左 padding）+ 16（选框）+ 8（$spacing-checkbox_label-paddingLeft）+ 文字 + 16（右 padding）。
//
// 与官方的差异（逐条）：
//   · 官方 filters 带 children 时是「悬浮展开二级 Dropdown（position: right）」，
//     端口把二级项拍平进同一张列表、按 level 递进缩进；
//   · filterDropdownProps 只落地 position（→ placement），Dropdown 的其余透传属性
//     （showTick / trigger / getPopupContainer …）没有 QML 对应物；
//   · 官方每项外面包 Dropdown.Item（点击项即触发 changeFn），端口直接给行加 TapHandler，
//     于是 Checkbox 自己的点击与行的点击合成一次。
PopupBase {
    id: panel

    property var table: null
    property var column: null
    property var tempValues: []
    property var initialValues: []

    fillColor: Theme.current.colorBg3
    strokeColor: Theme.current.colorBorder
    radius: Theme.current.radiusMedium
    padding: 0
    gap: 4
    showArrow: false
    autoFlip: true
    dismissOnOutsidePress: true
    placement: panel.dropdownPlacement()

    readonly property var filters: panel.column !== null && Array.isArray(panel.column.filters)
        ? panel.column.filters : []

    readonly property bool multiple: panel.column === null
        || panel.column.filterMultiple === undefined ? true : panel.column.filterMultiple !== false

    readonly property bool confirmMode: panel.column !== null
        && panel.column.filterConfirmMode === "confirm"

    readonly property var flatList: panel.flatten(panel.filters, 0)

    // renderFilterDropdown（props 那 6 个键）与 filterDropdown（一个现成节点）都整块替换菜单内容。
    readonly property var customNode: panel.customNodeOf()

    function customNodeOf() {
        if (panel.column === null)
            return null;
        if (panel.column.filterDropdown instanceof Component)
            return panel.column.filterDropdown;
        const fn = panel.column.renderFilterDropdown;
        if (typeof fn !== "function")
            return null;
        const r = fn(panel.dropdownArgs());
        return r instanceof Component ? r : null;
    }

    // 官方递给 renderFilterDropdown 的就是这一份（ColumnFilter.tsx:48 的 pick 列表 + :270-278）。
    function dropdownArgs() {
        return {
            tempFilteredValue: panel.valuesOf(),
            setTempFilteredValue: function (values) {
                panel.tempValues = Array.isArray(values) ? values.slice() : [];
            },
            confirm: function (opts) {
                const o = opts !== undefined && opts !== null ? opts : ({});
                const next = o.filteredValue !== undefined ? o.filteredValue : panel.tempValues;
                panel.apply(next);
                if (o.closeDropdown === true)
                    panel.close();
            },
            clear: function (opts) {
                const o = opts !== undefined && opts !== null ? opts : ({});
                panel.tempValues = [];
                panel.apply([]);
                if (o.closeDropdown === true)
                    panel.close();
            },
            close: function () {
                panel.close();
            },
            reset: function () {
                panel.tempValues = panel.initialValues.slice();
            },
            filters: panel.filters
        };
    }

    function flatten(list, level) {
        let out = [];
        for (let i = 0; i < list.length; ++i) {
            const f = list[i];
            out.push({ value: f.value, text: f.text, level: level });
            if (Array.isArray(f.children) && f.children.length)
                out = out.concat(panel.flatten(f.children, level + 1));
        }
        return out;
    }

    function textOf(value) {
        return panel.table !== null ? panel.table.plainText(value) : "";
    }

    function openFor(column, anchor) {
        if (panel.table === null)
            return;
        panel.column = column;
        panel.anchor = anchor;
        const current = panel.table.filteredValueAt(panel.table.leafIndexOf(column));
        panel.tempValues = Array.isArray(current) ? current.slice() : [];
        // 官方在打开时把 initialFilteredValue 存一份，「重置」回到它而不是清空
        // （ColumnFilter.tsx:258-268）。
        panel.initialValues = Array.isArray(current) ? current.slice() : [];
        if (typeof column.onFilterDropdownVisibleChange === "function")
            column.onFilterDropdownVisibleChange(true);
        panel.open();
    }

    function valuesOf() {
        return panel.confirmMode ? panel.tempValues
            : (panel.table !== null
                ? panel.table.filteredValueAt(panel.table.leafIndexOf(panel.column)) : []);
    }

    function isChecked(value) {
        return Engine.indexOfKey(panel.valuesOf(), value) >= 0;
    }

    function apply(values) {
        if (panel.table === null || panel.column === null)
            return;
        panel.table.handleFilter(panel.column, values);
    }

    function pick(value) {
        const current = panel.valuesOf().slice();
        let next;
        if (panel.multiple) {
            const at = Engine.indexOfKey(current, value);
            if (at >= 0)
                current.splice(at, 1);
            else
                current.push(value);
            next = current;
        } else {
            next = Engine.indexOfKey(current, value) >= 0 ? [] : [value];
        }
        if (panel.confirmMode) {
            panel.tempValues = next;
            return;
        }
        panel.apply(next);
        if (!panel.multiple)
            panel.close();
    }

    function confirm() {
        panel.apply(panel.tempValues);
        panel.close();
    }

    function reset() {
        panel.tempValues = panel.initialValues.slice();
    }

    function dropdownPlacement() {
        const p = panel.column !== null && panel.column.filterDropdownProps !== undefined
            && panel.column.filterDropdownProps !== null
            ? panel.column.filterDropdownProps.position : undefined;
        switch (String(p)) {
        case "top": return Enums.Top;
        case "topLeft": return Enums.TopLeft;
        case "topRight": return Enums.TopRight;
        case "bottomLeft": return Enums.BottomLeft;
        case "bottomRight": return Enums.BottomRight;
        case "left": return Enums.Left;
        case "leftTop": return Enums.LeftTop;
        case "leftBottom": return Enums.LeftBottom;
        case "right": return Enums.Right;
        case "rightTop": return Enums.RightTop;
        case "rightBottom": return Enums.RightBottom;
        case "bottom":
        default: return Enums.Bottom;
        }
    }

    onClosed: {
        if (panel.column !== null
            && typeof panel.column.onFilterDropdownVisibleChange === "function")
            panel.column.onFilterDropdownVisibleChange(false);
    }

    // 量最长的那条筛选项（Text 全都不设 width，childrenRect 取最右边界 = 最宽那条）。
    Item {
        id: measureHost

        objectName: "tableFilterMeasure"

        x: -9999
        y: 0
        width: childrenRect.width
        height: childrenRect.height
        visible: false

        Repeater {
            model: panel.flatList

            delegate: Text {
                required property var modelData

                text: panel.textOf(modelData.text)
                font.pixelSize: Theme.current.fontSizeRegular
            }
        }
    }

    // 左 padding 16 + 选框 16 + 文字与选框间距 8（$spacing-checkbox_label-paddingLeft）
    readonly property real itemIndent: Theme.current.spacingBase + Theme.current.spacingBase
        + Theme.current.spacingTight

    // 官方没给这个面板定宽，宽度是 Dropdown 量内容出来的；上限 $width-dropdown 280、
    // 下限与 Dropdown 同源 140。
    implicitWidth: panel.customNode !== null
        ? Math.max(140, panel.customContentWidth())
        : Math.min(280, Math.max(140, panel.itemIndent + measureHost.width
            + Theme.current.spacingBase))

    function customContentWidth() {
        if (customLoader.item === null || customLoader.item === undefined)
            return 140;
        return customLoader.width > 0 ? customLoader.width + 2 * Theme.current.spacingBase : 140;
    }

    // 官方 .semi-table-column-filter-dropdown 只给菜单加 max-height 290 + 内滚，
    // 这里用同一个夹法：列表块自己夹高，底部按钮始终留在面板里、不跟着滚。
    Item {
        id: listBlock

        objectName: "tableFilterList"

        width: panel.implicitWidth
        height: panel.customNode !== null ? 0 : Math.min(listColumn.height, 290)
        visible: panel.customNode === null
        clip: true

        Flickable {
            id: listScroll

            anchors.fill: parent
            contentHeight: listColumn.height
            boundsBehavior: Flickable.StopAtBounds
            clip: false

            Column {
                id: listColumn

                objectName: "tableFilterItems"

                width: parent.width

                Repeater {
                    model: panel.flatList

                    delegate: Item {
                        id: filterItem

                        objectName: "tableFilterItem"

                        required property var modelData

                        readonly property var info: modelData
                        readonly property bool checkedItem: panel.isChecked(info.value)
                        readonly property var customNode: panel.column !== null
                            && typeof panel.column.renderFilterDropdownItem === "function"
                            ? panel.column.renderFilterDropdownItem({
                                value: info.value, text: info.text, checked: filterItem.checkedItem,
                                level: info.level, filterMultiple: panel.multiple,
                                filteredValue: panel.valuesOf(),
                                onChange: function () { panel.pick(info.value); }
                            }) : null
                        // 官方这一档返回的 ReactNode 就是这一项的全部内容：节点走 Loader，
                        // 字符串 / 数字换成文案层（勾选框那一档让位，选中态靠字色）。
                        readonly property bool isNode: customNode instanceof Component
                        readonly property bool textOverride: customNode !== null && !isNode

                        width: listColumn.width
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            visible: itemHover.hovered
                            color: Theme.current.colorFill0
                        }

                        Loader {
                            objectName: "tableFilterItemNode"

                            anchors.left: parent.left
                            anchors.leftMargin: panel.itemMargin(filterItem.info.level)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: filterItem.isNode
                            sourceComponent: filterItem.customNode
                        }

                        Checkbox {
                            objectName: "tableFilterItemCheckbox"

                            anchors.left: parent.left
                            anchors.leftMargin: panel.itemMargin(filterItem.info.level)
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -1
                            visible: !filterItem.isNode && !filterItem.textOverride
                                && panel.multiple
                            checked: filterItem.checkedItem
                            text: panel.textOf(filterItem.info.text)
                        }

                        Text {
                            objectName: "tableFilterItemText"

                            anchors.left: parent.left
                            anchors.leftMargin: panel.itemMargin(filterItem.info.level)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !filterItem.isNode
                                && (filterItem.textOverride || !panel.multiple)
                            text: filterItem.textOverride
                                ? panel.textOf(filterItem.customNode) : panel.textOf(filterItem.info.text)
                            color: filterItem.checkedItem
                                ? Theme.current.colorPrimary : Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                        }

                        HoverHandler {
                            id: itemHover
                        }

                        TapHandler {
                            objectName: "tableFilterItemTap"

                            acceptedButtons: Qt.LeftButton
                            onTapped: panel.pick(filterItem.info.value)
                        }
                    }
                }
            }
        }
    }

    function itemMargin(level) {
        return Theme.current.spacingBase + level * Theme.current.spacingTight;
    }

    // renderFilterDropdown / filterDropdown 给出的整块内容（官方：这一档连菜单都被替换）。
    Loader {
        id: customLoader

        objectName: "tableFilterCustomPanel"

        // 尺寸交给 Loader 自己跟着节点走：这里再写一遍 width/height 就等于
        // 让 panel.implicitWidth 回读自己的结果，QML 会报 binding loop。
        visible: panel.customNode !== null
        sourceComponent: panel.customNode

        Binding {
            target: customLoader.item
            when: customLoader.item !== null
            property: "args"
            value: panel.dropdownArgs()
        }
    }

    // filterConfirmMode:'confirm' 的底部两个小按钮（官方是 inline style 的那一块）。
    Item {
        objectName: "tableFilterFooter"

        width: panel.implicitWidth
        height: panel.confirmMode && panel.customNode === null
            ? 24 + 2 * Theme.current.spacingTight + 1 : 0
        visible: panel.confirmMode && panel.customNode === null

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.current.colorBorder
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.current.spacingBaseTight
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.current.spacingTight

            Button {
                objectName: "tableFilterReset"

                text: qsTr("重置")
                size: Enums.Small
                tone: Enums.Tertiary
                // 官方 reset 只把暂存值倒回打开面板那一刻，不关面板、也不改筛选结果。
                onClicked: panel.reset()
            }

            Button {
                objectName: "tableFilterConfirm"

                text: qsTr("确定")
                size: Enums.Small
                tone: Enums.Primary
                variant: Enums.Solid
                onClicked: panel.confirm()
            }
        }
    }
}
