pragma ComponentBehavior: Bound

import QtQuick

// 快捷方式面板（presets）。对应 semi-ui/datePicker/quickControl.tsx +
// datePicker.scss:625-830。
//
// 官方账（variables.scss:19-21、58-62、225-228、245-248）：
//   左右方位：整栏宽 200、内容左右内边距 12 → 内容 176，固定两列、按钮宽 (176-8)/2 = 84；
//     标题「快捷选择」上内边距 18、字重 600，内容再上边距 14；除内容外占高 52。
//   上下方位：内容左右内边距 20、最大高 100、无标题；列数按 type ——
//     date/dateTime 三列（(244-16)*0.333 ≈ 75.9）、range 五列（(528-32)*0.2 = 99.2）、
//     month 两列（(125-8)*0.5 = 58.5）。
//   按钮间距一律 8；面板本身背景是 transparent，靠外框那条 1px 分隔线与主面板分开。
Item {
    id: control

    objectName: "dateQuickControl"

    property var presets: []             // [{ text, start, end }]，start/end 可以是函数
    property int position: Enums.PresetBottom
    property string typeKey: "date"
    property real sideHeight: 325        // 左右方位时与主面板等高

    signal clicked(var item)

    readonly property bool isSide: control.position === Enums.PresetLeft
        || control.position === Enums.PresetRight
    readonly property bool isRangeType: control.typeKey === "dateRange"
        || control.typeKey === "dateTimeRange"
    readonly property bool isMonthType: control.typeKey === "month" || control.typeKey === "monthRange"
    readonly property real paddingX: control.isSide ? 12 : 20
    readonly property int itemGap: 8
    readonly property int columnCount: control.isSide ? 2
        : (control.isRangeType ? 5 : (control.isMonthType ? 2 : 3))
    readonly property real buttonWidth: control.isSide ? 84
        : (control.isRangeType ? 99.2 : (control.isMonthType ? 58.5 : 75.9))
    readonly property real headerHeight: control.isSide ? 18 + 20 + 14 : 0   // 标题占高

    implicitWidth: control.isSide ? 200 : control.contentWidth + control.paddingX * 2
    implicitHeight: control.isSide ? control.sideHeight
        : Math.min(100, control.contentHeight + 16)      // $height-datepicker_presetPanel_top_and_bottom_max

    property real contentWidth: control.columnCount * control.buttonWidth
        + (control.columnCount - 1) * control.itemGap
    readonly property real contentHeight: {
        const rows = Math.ceil(control.presets.length / control.columnCount);
        return rows * 24 + Math.max(0, rows - 1) * control.itemGap;   // small 按钮高 24
    }

    Column {
        id: column

        width: parent.width
        y: control.isSide ? 18 : 8
        spacing: 0

        // 「快捷选择」标题只在左右方位出现（quickControl.tsx:85）
        Text {
            objectName: "quickControlTitle"

            visible: control.isSide
            width: parent.width
            leftPadding: control.paddingX
            text: qsTr("快捷选择")
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Font.DemiBold
        }

        // .semi-datepicker-quick-control-left-content-wrapper 的 margin-top 14
        // （$spacing-datepicker_quick_control_content-marginTop）—— 它是外层 wrapper 的外边距，
        // 在 overflow 容器**外面**，所以只能占位，不能塞进 clipper 里（否则吃掉一格的高度）。
        Item {
            width: parent.width
            height: control.isSide ? 14 : 0
        }

        Item {
            id: clipper

            objectName: "quickControlClipper"
            width: parent.width
            height: control.isSide ? control.contentHeight
                : Math.min(control.contentHeight, 100 - 16)
            clip: true

            Grid {
                x: control.paddingX
                y: 0
                columns: control.columnCount
                rowSpacing: control.itemGap
                columnSpacing: control.itemGap

                Repeater {
                    model: control.presets

                    delegate: Button {
                        id: presetButton
                        objectName: "presetButton"

                        required property var modelData

                        width: control.buttonWidth
                        height: 24
                        size: Enums.Small
                        tone: Enums.Primary
                        variant: Enums.Light
                        text: String(presetButton.modelData.text !== undefined
                                     ? presetButton.modelData.text : "")
                        onClicked: control.clicked(presetButton.modelData)
                    }
                }
            }
        }
    }

    // 与主面板之间那条 1px 分隔线（datePicker.scss:635-641）
    Rectangle {
        visible: control.isSide
        anchors.verticalCenter: parent.verticalCenter
        x: control.position === Enums.PresetLeft ? parent.width - 1 : 0
        width: 1
        height: parent.height
        color: Theme.current.colorBorder
    }

    Rectangle {
        visible: !control.isSide
        width: parent.width
        height: 1
        y: control.position === Enums.PresetTop ? parent.height - 1 : 0
        color: Theme.current.colorBorder
    }
}
