pragma ComponentBehavior: Bound

import QtQuick
import "DateFormat.js" as DF

// 时间面板：一条「选择时间」标题 + 时/分/秒滚动列。
// 对应 monthsGrid.tsx:439-491（renderTimePicker → Combobox）与 .semi-datepicker-tpk。
//
// 两处官方细节：
//   1) 列数由 format 里的时间位决定（getValidTimeFormat，monthsGridFoundation.ts:801-818）：
//      format 只到分就只给两列。
//   2) DatePicker 内嵌的时间列**不套 TimePicker 那 64px 定宽**（monthsGrid.tsx:484-491 没传
//      prefixCls，那几条 .semi-timepicker-panel-list-* 规则根本挂不上），列宽是等分，
//      284 宽面板三列各约 94px。
Item {
    id: control

    property var pickerDate: new Date()
    property string timeFormat: "HH:mm:ss"
    property real panelWidth: 284
    property bool hideDisabledOptions: false
    property var disabledHoursFn: null         // () => number[]
    property var disabledMinutesFn: null       // (hour) => number[]
    property var disabledSecondsFn: null       // (hour, minute) => number[]

    signal picked(int hour, int minute, int second)

    readonly property bool showHour: control.timeFormat.indexOf("H") >= 0
        || control.timeFormat.indexOf("h") >= 0
    readonly property bool showMinute: control.timeFormat.indexOf("m") >= 0
    readonly property bool showSecond: control.timeFormat.indexOf("s") >= 0
    readonly property int columnCount: (showHour ? 1 : 0) + (showMinute ? 1 : 0)
        + (showSecond ? 1 : 0)
    readonly property real headerHeight: 16 * 2 + 24 + 1   // padding 16 + 行高 24 + 下边框

    implicitWidth: control.panelWidth
    implicitHeight: control.headerHeight + 252              // $height-timePicker_panel_body

    function contains(list, value) {
        if (list === null || list === undefined)
            return false;
        for (let i = 0; i < list.length; ++i)
            if (list[i] === value)
                return true;
        return false;
    }

    function hourDisabled(hour) {
        if (control.disabledHoursFn === null)
            return false;
        return control.contains(control.disabledHoursFn(), hour);
    }

    function minuteDisabled(minute) {
        if (control.disabledMinutesFn === null)
            return false;
        return control.contains(control.disabledMinutesFn(control.pickerDate.getHours()), minute);
    }

    function secondDisabled(second) {
        if (control.disabledSecondsFn === null)
            return false;
        return control.contains(control.disabledSecondsFn(control.pickerDate.getHours(),
                                                          control.pickerDate.getMinutes()), second);
    }

    // 禁用项：hideDisabledOptions 为真时整条不出现，否则只是灰掉
    function build(count, isOff) {
        const out = [];
        for (let i = 0; i < count; ++i) {
            const off = isOff(i);
            if (off && control.hideDisabledOptions)
                continue;
            out.push({ text: DF.pad(i, 2), disabled: off });
        }
        return out;
    }

    readonly property var hourItems: control.showHour
        ? control.build(24, (h) => control.hourDisabled(h)) : []
    readonly property var minuteItems: control.showMinute
        ? control.build(60, (m) => control.minuteDisabled(m)) : []
    readonly property var secondItems: control.showSecond
        ? control.build(60, (s) => control.secondDisabled(s)) : []

    readonly property var columns: {
        const out = [];
        // 选中项后缀「时 / 分 / 秒」——内嵌面板用的就是 TimePicker 那个 Combobox
        // （monthsGrid.tsx:484），Combobox.tsx:202 的 transform 是无条件加的
        if (control.showHour)
            out.push({ items: control.hourItems, index: control.pickerDate.getHours(),
                kind: "H", unit: qsTr("时") });
        if (control.showMinute)
            out.push({ items: control.minuteItems, index: control.pickerDate.getMinutes(),
                kind: "M", unit: qsTr("分") });
        if (control.showSecond)
            out.push({ items: control.secondItems, index: control.pickerDate.getSeconds(),
                kind: "S", unit: qsTr("秒") });
        return out;
    }

    Column {
        id: body

        width: parent.width

        // 标题「选择时间」（.semi-scrolllist-header：padding 16、下边框 1）
        Text {
            id: header

            width: parent.width
            topPadding: 16
            bottomPadding: 16
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("选择时间")
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.current.colorBorder
        }

        Item {
            width: parent.width
            height: 252

            Row {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: control.columns

                    delegate: Item {
                        id: columnSlot

                        required property var modelData
                        required property int index

                        readonly property int dividerCount: control.columns.length - 1
                        width: (control.width - dividerCount) / control.columns.length
                        height: 252

                        DateScrollColumn {
                            anchors.fill: parent
                            items: columnSlot.modelData.items
                            selectedIndex: columnSlot.modelData.index
                            unit: columnSlot.modelData.unit
                            bodyHeight: 252

                            onPicked: (rowIndex) => {
                                const text = columnSlot.modelData.items[rowIndex].text;
                                control.emitTime(columnSlot.modelData.kind, Number(text));
                            }
                        }

                        Rectangle {
                            visible: columnSlot.index < control.columns.length - 1
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
    }

    function emitTime(kind, value) {
        let h = control.pickerDate.getHours();
        let m = control.pickerDate.getMinutes();
        let s = control.pickerDate.getSeconds();
        if (kind === "H")
            h = value;
        else if (kind === "M")
            m = value;
        else
            s = value;
        control.picked(h, m, s);
    }
}
