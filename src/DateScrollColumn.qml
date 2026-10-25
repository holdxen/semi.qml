pragma ComponentBehavior: Bound

import QtQuick

// 一列可滚动的选择列（时 / 分 / 秒、年 / 月都用它）。对应 .semi-scrolllist-item。
//
// 官方规格（scrollList/scrollList.scss + timePicker/timePicker.scss）：
//   项高 $height-scrollList_item = 36；列表首尾各有一块 (body - item) / 2 的留白
//   （ul::before + padding-bottom），这样第一项和最后一项也能滚到正中。
//   normal 模式的选中态走 .semi-scrolllist-item-sel：底 primary-light-default、
//   字 text-0（scrollList/variables.scss:10-11）—— TimePicker / 年月面板都是
//   mode='normal'（Combobox.tsx:209、yearAndMonth.tsx:167）。
//   悬浮 fill-1、按下 fill-2（scrollList.scss:104/108，令牌
//   $color-scrollList_item-text-hover / $color-scrollList_item-bg-active）。
//   禁用字 disabled-text（scrollList.scss:112）。
//
// wheel 模式（scrollItemProps.mode === 'wheel'）是另一套样子：中间一条选择带
// （上下各 1px color-border），选中项加粗且换成主色（scrollList.scss:128-131
// 的 -item-selected，font-weight bold + var(--semi-color-primary) !important），
// 而且**不能点选**、只能滚（scrollItem.tsx:438 的 events.onClick 排除了 wheel）。
// cycled 为 true 时首尾相接无限滚（把模型铺三份、滚出中间那份时静默挪回去）。
//
// unit 对应 Combobox.tsx:202 的 transform —— 官方只给**选中那一项**加「时 / 分 / 秒」，
// 其它项还是光秃秃的数字。
Item {
    id: control

    property var items: []              // [{ text, disabled }]
    property int selectedIndex: -1
    property real bodyHeight: 252       // $height-timePicker_panel_body
    property real itemHeight: 36        // $height-scrollList_item
    property real columnWidth: 82       // $width-datepicker_panel_yam_scrolllist_li_min + wheel 右内边距
    property string unit: ""            // 选中项后缀：时 / 分 / 秒
    property bool wheel: false          // scrollItemProps.mode === 'wheel'
    property bool cycled: false         // scrollItemProps.cycled

    signal picked(int index)

    implicitWidth: control.columnWidth
    implicitHeight: control.bodyHeight

    readonly property real padHeight: (control.bodyHeight - control.itemHeight) / 2
    readonly property int realCount: control.items === undefined ? 0 : control.items.length

    // cycled 时把模型铺三份，滚到任一份都能映射回真下标
    readonly property var listModel: {
        const src = control.items === undefined ? [] : control.items;
        if (!control.cycled)
            return src;
        const out = [];
        for (let rep = 0; rep < 3; ++rep) {
            for (let i = 0; i < src.length; ++i)
                out.push(src[i]);
        }
        return out;
    }

    // 真下标 → 模型下标（cycled 时落在中间那一份）
    function modelIndexOf(real) {
        return control.cycled ? control.realCount + real : real;
    }

    // 模型下标 → 真下标
    function realIndexOf(model) {
        if (control.realCount <= 0)
            return -1;
        return control.cycled ? ((model % control.realCount) + control.realCount) % control.realCount
            : model;
    }

    function textOf(modelIndex) {
        const item = control.listModel[modelIndex];
        if (item === undefined || item === null)
            return "";
        const base = item.text === undefined ? String(item.value) : String(item.text);
        return modelIndex === control.modelIndexOf(control.selectedIndex) && control.unit !== ""
            ? base + control.unit : base;
    }

    function centerCurrent() {
        if (list.count === 0 || control.selectedIndex < 0)
            return;
        list.positionViewAtIndex(control.modelIndexOf(control.selectedIndex), ListView.Center);
    }

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        snapMode: control.wheel ? ListView.SnapToItem : ListView.NoSnap
        model: control.listModel
        currentIndex: control.selectedIndex < 0 ? -1 : control.modelIndexOf(control.selectedIndex)
        spacing: 0

        header: Item { width: list.width; height: control.padHeight }
        footer: Item { width: list.width; height: control.padHeight }

        onCurrentIndexChanged: control.centerCurrent()
        onCountChanged: control.centerCurrent()
        Component.onCompleted: control.centerCurrent()
        onHeightChanged: control.centerCurrent()

        // wheel / cycled 是靠滚到中间来选中的，松手即提交
        onMovementEnded: {
            if (!control.wheel && !control.cycled)
                return;
            const centered = list.currentIndexAtCenter();
            if (centered >= 0 && centered !== control.selectedIndex)
                control.picked(centered);
        }

        function currentIndexAtCenter() {
            if (control.realCount <= 0)
                return -1;
            // 居中第 i 项时 contentY 正好等于 i * itemHeight（首尾留白 = (body-item)/2，
            // 一加一减抵消），所以直接除就行
            const row = Math.round(list.contentY / control.itemHeight);
            return control.realIndexOf(Math.max(0, Math.min(list.count - 1, row)));
        }

        delegate: Item {
            id: cell

            required property var modelData
            required property int index

            // 测试用名字：带上本项文字，cycled 铺三份时会重名，取第一个即可
            objectName: "scrollCell-" + (cell.modelData.text === undefined
                ? String(cell.modelData.value) : String(cell.modelData.text))

            width: list.width
            height: control.itemHeight

            readonly property bool disabled: cell.modelData.disabled === true
            readonly property bool selected: cell.index === control.modelIndexOf(control.selectedIndex)

            Rectangle {
                anchors.fill: parent
                visible: !control.wheel && (cell.selected || cellHover.hovered || cellTap.pressed)
                color: cell.selected ? Theme.current.colorPrimaryLightDefault
                    : (cellTap.pressed ? Theme.current.colorFill2 : Theme.current.colorFill1)
            }

            Text {
                anchors.centerIn: parent
                text: control.textOf(cell.index)
                font.pixelSize: Theme.current.fontSizeRegular
                font.bold: control.wheel && cell.selected
                color: cell.disabled ? Theme.current.colorDisabledText
                    : (control.wheel && cell.selected ? Theme.current.colorPrimary
                        : Theme.current.colorText0)
            }

            HoverHandler {
                id: cellHover

                enabled: !cell.disabled && !control.wheel
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: cellTap

                // wheel 模式官方不给点选（scrollItem.tsx:438）
                enabled: !cell.disabled && !control.wheel
                onTapped: control.picked(control.realIndexOf(cell.index))
            }
        }
    }

    // wheel 模式中间那条选择带（上下各 1px color-border）
    Item {
        id: wheelBand

        objectName: "wheelBand"
        visible: control.wheel
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: control.itemHeight
        z: 2

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.current.colorBorder
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.current.colorBorder
        }
    }
}
