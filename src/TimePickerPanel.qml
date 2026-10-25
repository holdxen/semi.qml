pragma ComponentBehavior: Bound

import QtQuick
import Semi
import "DateFormat.js" as DF

// TimePicker 的一格面板（单选用一块，range 用左右两块）。对应 .semi-scrolllist：
// header + 列（上午下午 / 时 / 分 / 秒）+ footer。
//
// 规格：timePicker/timePicker.scss:59-76 列宽 ampm 72 / hour 64 / minute 64 / second 64
// （$width-timePicker_panel_list_*）；body 高 252（$height-timePicker_panel_body）、项高 36、
// body 左右内边距 16（$spacing-scrollList_body-paddingX）；header 内边距 0 16、标题加粗
// text-0、下面一条 1px color-border（scrollList.scss:22-33、178-181）；footer 上描边 1px
// color-border、内边距 10（scrollList.scss:174-177）。range 面板内边距归零
// （$spacing-timePicker_range_panel_scrolllist_header_body-padding）。
//
// 列的生成规则照搬 ComboxFoundation.ts:26-34（generateOptions：按 step 跳、
// hideDisabledOptions 才把禁用项从列表里删掉）、ComboxFoundation.ts:98-110
// （12 小时制把 disabled 数组按上午/下午映射）与 Combobox.tsx:182-314。
Item {
    id: control

    property var date: null                     // 面板显示的时间，null 按 00:00:00
    property string timeFormat: "HH:mm:ss"
    property bool use12Hours: false
    property int hourStep: 1
    property int minuteStep: 1
    property int secondStep: 1
    property bool hideDisabledOptions: false
    property var disabledHoursFn: null
    property var disabledMinutesFn: null
    property var disabledSecondsFn: null
    // scrollItemProps：mode === 'wheel' 与 cycled
    property bool wheel: false
    property bool cycled: false
    // panelHeader / panelFooter：字符串或 Component
    property var header: null
    property var footer: null
    property bool rangePanel: false

    signal picked(string kind, int value)

    readonly property int bodyHeight: 252       // $height-timePicker_panel_body
    readonly property int itemHeight: 36        // $height-scrollList_item
    readonly property int bodyPaddingX: control.rangePanel ? 0 : 16
    readonly property real headerHeight: headerArea.height
    readonly property real footerHeight: footerArea.height
    readonly property bool isPM: control.date !== null && control.date !== undefined
        && DF.isPM(control.date)

    function listOf(count, step, disabled) {
        const out = [];
        for (let v = 0; v < count; v += step) {
            const off = disabled !== null && disabled !== undefined && disabled.indexOf(v) >= 0;
            if (off && control.hideDisabledOptions)
                continue;
            out.push({ text: DF.pad(v, 2), value: v, disabled: off });
        }
        return out;
    }

    // 12 小时制的小时列：[12] + (1..11 里生成了的那些)（Combobox.tsx:195）
    function hourListOf(step, disabled) {
        const base = listOf(24, step, disabled);
        if (!control.use12Hours)
            return base;
        const out = [{ text: "12", value: 12, disabled: base.some(o => o.value === 12 && o.disabled) }];
        for (let i = 0; i < base.length; ++i) {
            const o = base[i];
            if (o.value > 0 && o.value < 12)
                out.push(o);
        }
        return out;
    }

    readonly property var disabledHours: typeof control.disabledHoursFn === "function"
        ? control.disabledHoursFn() : null

    // ComboxFoundation.ts:98-110：12 小时制下把 0-23 的禁用表映射到当前半天的 1-12
    readonly property var disabledHoursMapped: {
        const raw = control.disabledHours;
        if (raw === null || raw === undefined || !Array.isArray(raw) || !control.use12Hours)
            return raw;
        const out = [];
        if (!control.isPM) {
            for (let i = 0; i < raw.length; ++i) {
                if (raw[i] < 12)
                    out.push(raw[i] === 0 ? 12 : raw[i]);
            }
        } else {
            for (let i = 0; i < raw.length; ++i)
                out.push(raw[i] === 12 ? 12 : raw[i] - 12);
        }
        return out;
    }

    readonly property var disabledMinutes: typeof control.disabledMinutesFn === "function"
        ? control.disabledMinutesFn(control.date === null || control.date === undefined
            ? null : control.date.getHours()) : null
    readonly property var disabledSeconds: typeof control.disabledSecondsFn === "function"
        ? control.disabledSecondsFn(control.date === null || control.date === undefined
            ? null : control.date.getHours(), control.date === null || control.date === undefined
            ? null : control.date.getMinutes()) : null

    readonly property bool showHour: /HH|hh|H|h/.test(control.timeFormat)
    readonly property bool showMinute: /mm/.test(control.timeFormat)
    readonly property bool showSecond: /ss/.test(control.timeFormat)

    readonly property var hourItems: control.showHour
        ? hourListOf(Math.max(1, control.hourStep), control.disabledHoursMapped) : []
    readonly property var minuteItems: control.showMinute
        ? listOf(60, Math.max(1, control.minuteStep), control.disabledMinutes) : []
    readonly property var secondItems: control.showSecond
        ? listOf(60, Math.max(1, control.secondStep), control.disabledSeconds) : []
    readonly property var ampmItems: control.use12Hours
        ? [{ text: DF.meridiemItems()[0], value: 0, disabled: false },
            { text: DF.meridiemItems()[1], value: 1, disabled: false }] : []

    function indexOfValue(list, value) {
        for (let i = 0; i < list.length; ++i)
            if (list[i].value === value)
                return i;
        return -1;
    }

    readonly property int hourValue: control.date === null || control.date === undefined
        ? 0 : control.date.getHours()
    readonly property int minuteValue: control.date === null || control.date === undefined
        ? 0 : control.date.getMinutes()
    readonly property int secondValue: control.date === null || control.date === undefined
        ? 0 : control.date.getSeconds()

    // 列的显示顺序照 Combobox.tsx:332-335：上午下午、时、分、秒
    readonly property var columns: {
        const out = [];
        if (control.use12Hours)
            out.push({ kind: "ampm", width: 72, unit: "", items: control.ampmItems,
                selected: control.isPM ? 1 : 0 });
        if (control.showHour)
            out.push({ kind: "hour", width: 64, unit: "时", items: control.hourItems,
                selected: control.indexOfValue(control.hourItems, control.use12Hours
                    ? DF.hour12Of(control.hourValue) : control.hourValue) });
        if (control.showMinute)
            out.push({ kind: "minute", width: 64, unit: "分", items: control.minuteItems,
                selected: control.indexOfValue(control.minuteItems, control.minuteValue) });
        if (control.showSecond)
            out.push({ kind: "second", width: 64, unit: "秒", items: control.secondItems,
                selected: control.indexOfValue(control.secondItems, control.secondValue) });
        return out;
    }

    implicitWidth: control.bodyPaddingX * 2
        + control.columns.reduce((sum, c) => sum + c.width, 0)
    implicitHeight: headerArea.height + control.bodyHeight + footerArea.height

    Column {
        id: box

        x: 0
        y: 0
        width: control.width
        spacing: 0

        // ---- header（panelHeader）----
        Item {
            id: headerArea

            visible: control.header !== null && control.header !== undefined && control.header !== ""
            width: box.width
            height: visible ? headerInner.height + 1 : 0

            Item {
                id: headerInner

                x: control.bodyPaddingX
                width: parent.width - control.bodyPaddingX * 2

                Text {
                    id: headerText

                    visible: control.headerIsText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    text: String(control.header)
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.Bold
                    color: Theme.current.colorText0         // $color-scrollList_header-title
                }

                Loader {
                    id: headerNode

                    visible: !control.headerIsText
                    active: visible
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    sourceComponent: control.headerIsText ? null : control.header
                }

                implicitHeight: control.headerIsText ? headerText.height + 16 : headerNode.height + 16
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.current.colorBorder           // $height-scrollList_line
            }
        }

        // ---- body：一排列 ----
        Item {
            id: bodyArea

            width: box.width
            height: control.bodyHeight

            Row {
                id: bodyRow

                anchors.left: parent.left
                anchors.leftMargin: control.bodyPaddingX
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: control.columns

                    delegate: Item {
                        id: slot

                        required property var modelData
                        required property int index

                        width: slot.modelData.width
                        height: control.bodyHeight

                        DateScrollColumn {
                            anchors.fill: parent
                            objectName: "column-" + slot.modelData.kind
                            items: slot.modelData.items
                            selectedIndex: slot.modelData.selected
                            bodyHeight: control.bodyHeight
                            itemHeight: control.itemHeight
                            columnWidth: slot.modelData.width
                            unit: slot.modelData.unit
                            wheel: control.wheel
                            cycled: control.cycled
                            onPicked: (realIndex) => control.picked(slot.modelData.kind, realIndex)
                        }

                        // 列间 1px 分隔（.semi-scrolllist-item:not(:last-child) 的 border-right；
                        // wheel 模式官方去掉描边，timePicker.scss:54-57）
                        Rectangle {
                            visible: !control.wheel && slot.index < control.columns.length - 1
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 1
                            color: Theme.current.colorBorder
                        }
                    }
                }
            }
        }

        // ---- footer（panelFooter）----
        Item {
            id: footerArea

            visible: control.footer !== null && control.footer !== undefined && control.footer !== ""
            width: box.width
            height: visible ? footerInner.height + 20 + 1 : 0

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: Theme.current.colorBorder           // $color-scrollList_footer-border
            }

            Item {
                id: footerInner

                y: 10
                width: parent.width

                Text {
                    id: footerText

                    visible: control.footerIsText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(control.footer)
                    font.pixelSize: Theme.current.fontSizeRegular
                    color: Theme.current.colorText0
                }

                Loader {
                    id: footerNode

                    visible: !control.footerIsText
                    active: visible
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: control.footerIsText ? null : control.footer
                }

                implicitHeight: control.footerIsText ? footerText.height : footerNode.height
            }
        }
    }

    readonly property bool headerIsText: typeof control.header === "string"
    readonly property bool footerIsText: typeof control.footer === "string"
}
