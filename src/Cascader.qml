pragma ComponentBehavior: Bound

import QtQuick

// 级联选择。options 是嵌套结构 [{ label, value, children }]，
// 面板按层展开成多列，选了上一列才会出下一列。
//
//     Cascader {
//         options: [{ label: "浙江", value: "zj", children: [{ label: "杭州", value: "hz" }] }]
//         onSelected: (path, labels) => ...
//     }
//
// 触发器沿用 Input 的外观（fill-0 / hover fill-1 / focus 主色描边）。
Item {
    id: control

    property var options: []
    property var value: []
    property string placeholder: qsTr("请选择")
    property int size: Enums.Default
    // 分角圆角透给触发器，InputGroup 要靠它们还原 .semi-input-group 的首尾圆角
    property alias topLeftRadius: input.topLeftRadius
    property alias topRightRadius: input.topRightRadius
    property alias bottomLeftRadius: input.bottomLeftRadius
    property alias bottomRightRadius: input.bottomRightRadius
    property bool clearable: true

    signal selected(var path, string labels)

    readonly property int controlState:
        Appearance.fieldState(control.enabled, input.activeFocus || popup.visible, hover.hovered, false)
    readonly property string displayText: control.labelsOf(control.value).join(" / ")

    implicitWidth: 240
    implicitHeight: Appearance.inputWrapperHeight(Theme.current, control.size)

    // 每一列的候选：第 i 列是「沿当前路径走 i 步」的那个节点的 children
    function open() { popup.open(); }

    function close() { popup.close(); }

    function childrenAt(level) {
        let node = null;
        let list = control.options;
        for (let i = 0; i < level; ++i) {
            const chosen = control.value[i];
            node = null;
            for (let j = 0; j < list.length; ++j) {
                if (list[j].value === chosen) {
                    node = list[j];
                    break;
                }
            }
            if (!node || !node.children)
                return [];
            list = node.children;
        }
        return list;
    }

    function labelsOf(path) {
        const out = [];
        let list = control.options;
        for (let i = 0; i < path.length; ++i) {
            let found = null;
            for (let j = 0; j < list.length; ++j) {
                if (list[j].value === path[i]) {
                    found = list[j];
                    break;
                }
            }
            if (!found)
                break;
            out.push(found.label);
            list = found.children || [];
        }
        return out;
    }

    function columnCount() {
        let count = 1;
        let path = control.value.slice();
        while (control.childrenAt(count).length > 0 && count < path.length + 1)
            count++;
        // 至少要显示到「已选路径长度 + 1」列，便于继续往下选
        return Math.min(Math.max(count, path.length + 1), 4);
    }

    function chooseAt(level, item) {
        const next = control.value.slice(0, level);
        next.push(item.value);
        control.value = next;

        const hasChildren = item.children !== undefined && item.children.length > 0;
        if (!hasChildren) {
            const labels = control.labelsOf(next).join(" / ");
            control.selected(next, labels);
            popup.close();
        }
    }

    function clear() {
        control.value = [];
        control.selected([], "");
    }

    // ---- 触发器 ----
    Rectangle {
        id: input

        anchors.fill: parent
        radius: Theme.current.radiusSmall
        activeFocusOnTab: control.enabled
        color: Appearance.inputBackground(Theme.current,
                                          control.displayText !== "" && control.controlState === Enums.Normal
                                              ? Enums.Normal : control.controlState,
                                          Enums.StatusDefault)
        border.width: 1
        border.color: popup.visible
            ? Theme.current.colorFocusBorder
            : Appearance.inputBorderColor(Theme.current,
                                          popup.isOpen ? Enums.Focused : control.controlState,
                                          Enums.StatusDefault)

        Behavior on color {
            ColorAnimation { duration: Theme.current.durationFast }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.inputPaddingHorizontal(Theme.current)
            anchors.right: suffix.left
            anchors.rightMargin: Theme.current.spacingTight
            anchors.verticalCenter: parent.verticalCenter
            text: control.displayText !== "" ? control.displayText : control.placeholder
            color: control.displayText !== ""
                ? Appearance.inputForeground(Theme.current, control.controlState)
                : Appearance.inputPlaceholderColor(Theme.current, control.controlState)
            font.pixelSize: Theme.current.fontSizeRegular
            elide: Text.ElideRight
        }

        Row {
            id: suffix

            anchors.right: parent.right
            anchors.rightMargin: Theme.current.spacingTight
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.current.spacingExtraTight

            IconButton {
                visible: control.clearable && control.value.length > 0 && control.enabled
                icon: "close"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
                onClicked: control.clear()
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron_down"
                size: 16
                color: Theme.current.colorText2
            }
        }

        HoverHandler {
            id: hover
            enabled: control.enabled
        }

        TapHandler {
            enabled: control.enabled
            onTapped: popup.toggle()
        }
    }

    // ---- 多列面板 ----
    PopupBase {
        id: popup

        anchor: input
        placement: Enums.BottomLeft
        gap: 4
        fillColor: Theme.current.colorBg3
        padding: Theme.current.spacingExtraTight
        autoFlip: true

        implicitWidth: Math.max(control.width, columnRow.implicitWidth + popup.padding * 2)
        implicitHeight: 220

        Row {
            id: columnRow

            spacing: 0

            Repeater {
                model: control.columnCount()

                delegate: Column {
                    id: column

                    required property int index

                    readonly property var items: control.childrenAt(column.index)

                    width: 140
                    spacing: 0

                    Repeater {
                        model: column.items

                        delegate: Item {
                            id: optionRow

                            required property var modelData
                            required property int index

                            readonly property bool chosen: control.value[column.index] === optionRow.modelData.value
                            readonly property bool hasChildren: optionRow.modelData.children !== undefined
                                && optionRow.modelData.children.length > 0

                            width: column.width
                            height: 32

                            Rectangle {
                                anchors.fill: parent
                                color: optionRow.chosen
                                    ? Theme.current.colorFill1       // $color-cascader_option-bg-active
                                    : (optionHover.hovered ? Theme.current.colorFill0 : "transparent")
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.current.spacingBaseTight
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - 36)
                                text: optionRow.modelData.label
                                color: optionRow.chosen
                                    ? Theme.current.colorPrimary
                                    : Theme.current.colorText0
                                font.pixelSize: Theme.current.fontSizeRegular
                                elide: Text.ElideRight
                            }

                            Icon {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.current.spacingTight
                                anchors.verticalCenter: parent.verticalCenter
                                visible: optionRow.hasChildren
                                name: "chevron_right"
                                size: 12
                                color: Theme.current.colorText3
                            }

                            HoverHandler {
                                id: optionHover
                            }

                            TapHandler {
                                onTapped: control.chooseAt(column.index, optionRow.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
