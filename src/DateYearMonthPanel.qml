pragma ComponentBehavior: Bound

import QtQuick

// 年月面板：两列滚动列表（年 / 月），可选一条带返回按钮的表头。
// 对应 semi-ui/datePicker/yearAndMonth.tsx + _utils/getYears.ts。
//
// 三条官方细节：
//   1) 年的范围默认是「今年 ±100」（getYears.ts:4-5），可用 startYear / endYear 收窄，
//      end < start 时两者对调。
//   2) 年那一列的禁用是「该年 12 个月全禁用」（yearAndMonth.tsx:144-146），
//      月那一列按当月任一代表日禁用即禁用（:210）；右栏还额外禁掉早于左栏的年月。
//   3) 中文才给年份补「年」、月份补「月」（:157-160、:217-220），本库固定中文。
Item {
    id: control

    property var pickerDate: new Date()
    property int startYear: 0            // 0 = 用默认（今年 -100）
    property int endYear: 0              // 0 = 用默认（今年 +100）
    property bool showBack: true
    property bool isRightPanel: false
    property int leftYear: 0             // 左栏当前年（右栏要禁掉比它早的）
    property int leftMonth: 0
    property var disabledDateFn: null
    property bool compact: false         // density=compact：项高 32、面板 256、表头 48

    signal yearPicked(int year)
    signal monthPicked(int month)        // 1-12
    signal backClicked()

    readonly property int lowYear: control.startYear !== 0 ? control.startYear
        : new Date().getFullYear() - 100
    readonly property int highYear: control.endYear !== 0 ? control.endYear
        : new Date().getFullYear() + 100
    // 表头：上下内边距 12 + 按钮 32 + 1px 下边框（compact 是 12 + 24 + 12 = 48）
    readonly property int headerHeight: control.showBack ? (control.compact ? 48 : 57) : 0
    readonly property int bodyHeight: control.compact ? 256 : 266   // $height-datepicker_panel_yam_scrolllist
    readonly property int itemHeight: control.compact ? 32 : 36     // $height-datepicker_yam_li_compact

    implicitWidth: 82 * 2 + 1
    implicitHeight: control.headerHeight + control.bodyHeight

    function dayOfMonth() {
        // 官方用「今天的那一天」代表月内检查点，夹到当月月末
        const today = new Date();
        return today.getDate();
    }

    function monthDisabledAt(year, month) {
        if (control.disabledDateFn === null)
            return false;
        const probe = new Date(year, month - 1,
                               Math.min(control.dayOfMonth(),
                                        new Date(year, month, 0).getDate()));
        return control.disabledDateFn(probe, {
            rangeStart: null, rangeEnd: null, rangeInputFocus: false
        }) === true;
    }

    function yearDisabled(year) {
        for (let m = 1; m <= 12; ++m)
            if (!control.monthDisabledAt(year, m))
                return false;
        return true;
    }

    readonly property var yearItems: {
        let low = control.lowYear;
        let high = control.highYear;
        if (high < low) {
            const t = low;
            low = high;
            high = t;
        }
        const out = [];
        for (let y = low; y <= high; ++y) {
            const beforeLeft = control.isRightPanel && control.leftYear !== 0 && y < control.leftYear;
            out.push({ text: y + "年", value: y,
                       disabled: control.yearDisabled(y) || beforeLeft });
        }
        return out;
    }

    readonly property var monthItems: {
        const year = control.pickerDate.getFullYear();
        const out = [];
        for (let m = 1; m <= 12; ++m) {
            const beforeLeft = control.isRightPanel && control.leftYear === year
                && control.leftMonth !== 0 && m < control.leftMonth;
            out.push({ text: m + "月", value: m,
                       disabled: control.monthDisabledAt(year, m) || beforeLeft });
        }
        return out;
    }

    Column {
        id: body

        width: parent.width
        spacing: 0

        // 返回按钮那一行（yearAndMonth.tsx:276-286，.semi-datepicker-yearmonth-header）
        Item {
            id: headerRow

            visible: control.showBack
            width: parent.width
            height: control.showBack ? (control.compact ? 48 : 56) : 0

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                IconButton {
                    id: backIcon

                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron_left"
                    size: Enums.Small
                    variant: Enums.Borderless
                    tone: Enums.Tertiary
                    onClicked: control.backClicked()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("返回选择日期")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }
        }

        Rectangle {
            visible: control.showBack
            width: parent.width
            height: 1
            color: Theme.current.colorBorder
        }

        Item {
            width: parent.width
            height: control.bodyHeight

            Row {
                anchors.fill: parent
                spacing: 0

                DateScrollColumn {
                    id: yearColumn

                    width: (control.width - 1) / 2
                    height: control.bodyHeight
                    bodyHeight: control.bodyHeight
                    itemHeight: control.itemHeight
                    items: control.yearItems
                    selectedIndex: control.indexOfValue(control.yearItems,
                                                        control.pickerDate.getFullYear())

                    onPicked: (index) => control.yearPicked(control.yearItems[index].value)
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.current.colorBorder
                }

                DateScrollColumn {
                    id: monthColumn

                    width: (control.width - 1) / 2
                    height: control.bodyHeight
                    bodyHeight: control.bodyHeight
                    itemHeight: control.itemHeight
                    items: control.monthItems
                    selectedIndex: control.indexOfValue(control.monthItems,
                                                        control.pickerDate.getMonth() + 1)

                    onPicked: (index) => control.monthPicked(control.monthItems[index].value)
                }
            }
        }
    }

    function indexOfValue(items, value) {
        for (let i = 0; i < items.length; ++i)
            if (items[i].value === value)
                return i;
        return -1;
    }
}
