pragma ComponentBehavior: Bound

import QtQuick

// 面板里的一栏：月历 + 底部「日期 / 时间」切换条，年月面板和时间面板作为覆盖层盖在
// 月历之上。对应 monthsGrid.tsx:256-317 的 -left / -right 那一列。
//
// 官方规格：
//   切换条只在 type 含 Time 且没开 insetInput 时出现（monthsGrid.tsx:532），高 54
//   （$height-datepicker_switch），左右各 50%、上边框 1px；默认 density 才画图标。
//   激活的一侧文字 text-0 + 字重 600，未激活 text-2，悬浮（非禁用）底 fill-0。
//   年月/时间层的高度是「整栏高 - 切换条高」（datePicker.scss:7-8 的 calc(100% - 54px)）。
Item {
    id: control

    property var pickerDate: new Date()
    property int panelIndex: 0
    property string view: "date"          // date | yam | time
    property bool showTimeType: false
    property bool showSwitchBar: false
    property bool insetInput: false
    property string timeFormat: "HH:mm:ss"
    property string switchDateText: ""
    property string switchTimeText: ""
    property bool disabledTimePicker: false
    property bool densityCompact: false
    property bool syncSwitchMonth: false
    property bool isRange: false
    property int weeksRowNum: 0
    property int weekStartsOn: 0
    property var selectedDates: []
    property var rangeStart: null
    property var rangeEnd: null
    property var hoverDay: null
    property var offsetRangeStart: null
    property var offsetRangeEnd: null
    property var disabledDateFn: null
    property var disabledHoursFn: null
    property var disabledMinutesFn: null
    property var disabledSecondsFn: null
    property bool hideDisabledOptions: false
    property Component renderDate: null
    property Component renderFullDate: null
    property int startYear: 0
    property int endYear: 0
    property int leftYear: 0
    property int leftMonth: 0
    property bool showYamBackButton: true

    signal navAction(string action)
    signal dayClicked(var date)
    signal dayHovered(var date)
    signal timePicked(int hour, int minute, int second)
    signal yamYearPicked(int year)
    signal yamMonthPicked(int month)
    signal backToDates()

    readonly property real switchHeight: control.showSwitchBar && control.showTimeType
        && !control.insetInput ? (control.densityCompact ? 32 : 54) : 0
    readonly property real gridHeight: grid.implicitHeight
    // 时间/年月覆盖层展开时整栏有最小高度（$height-datepicker_yamShowing_min 378，
    // compact 288）；只看月历时不硬撑，否则 5 行的月份下面会多出一条空白。
    readonly property real overlayMinHeight: control.densityCompact ? 288 : 378
    readonly property real columnHeight: control.view === "date"
        ? grid.implicitHeight + control.switchHeight
        : Math.max(grid.implicitHeight + control.switchHeight, control.overlayMinHeight)

    implicitWidth: grid.implicitWidth
    implicitHeight: control.columnHeight

    // ---- 月历 ----
    DateMonthGrid {
        id: grid

        objectName: "dateMonthGrid"
        y: 0
        width: control.width
        pickerDate: control.pickerDate
        panelIndex: control.panelIndex
        isRange: control.isRange
        syncSwitchMonth: control.syncSwitchMonth
        density: control.densityCompact ? Enums.DensityCompact : Enums.DensityDefault
        weekStartsOn: control.weekStartsOn
        weeksRowNum: control.weeksRowNum
        selectedDates: control.selectedDates
        rangeStart: control.rangeStart
        rangeEnd: control.rangeEnd
        hoverDay: control.hoverDay
        offsetRangeStart: control.offsetRangeStart
        offsetRangeEnd: control.offsetRangeEnd
        disabledDateFn: control.disabledDateFn
        renderDate: control.renderDate
        renderFullDate: control.renderFullDate
        insetInput: control.insetInput

        onNavClicked: (action) => control.navAction(action)
        onDayClicked: (date) => control.dayClicked(date)
        onDayHovered: (date) => control.dayHovered(date)
    }

    // ---- 底部「日期 / 时间」切换条 ----
    Item {
        id: switchBar

        visible: control.switchHeight > 0
        y: grid.height
        width: parent.width
        height: control.switchHeight

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.current.colorBorder
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: [
                    { kind: "date", icon: "calendar", text: control.switchDateText },
                    { kind: "time", icon: "clock", text: control.switchTimeText }
                ]

                delegate: Rectangle {
                    id: half

                    required property var modelData

                    width: switchBar.width / 2
                    height: control.switchHeight

                    readonly property bool active: half.modelData.kind === "date"
                        ? control.view !== "time" : control.view === "time"
                    readonly property bool timeDisabled: half.modelData.kind === "time"
                        && control.disabledTimePicker

                    color: hoverHalf.hovered && !half.timeDisabled
                        ? Theme.current.colorFill0 : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.current.spacingExtraTight

                        Icon {
                            visible: !control.densityCompact
                            anchors.verticalCenter: parent.verticalCenter
                            name: half.modelData.icon
                            size: 16
                            color: half.active ? Theme.current.colorText0 : Theme.current.colorText2
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: half.modelData.text
                            color: half.active ? Theme.current.colorText0 : Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeRegular
                            font.weight: half.active ? Font.DemiBold : Font.Normal
                        }
                    }

                    HoverHandler {
                        id: hoverHalf

                        enabled: !half.timeDisabled
                        cursorShape: half.timeDisabled ? Qt.ForbiddenCursor
                            : Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: !half.timeDisabled
                        onTapped: {
                            if (half.modelData.kind === "time")
                                control.navAction("openTime");
                            else
                                control.navAction("openDate");
                        }
                    }
                }
            }
        }
    }

    // ---- 时间面板（盖住月历，留出切换条那 54）----
    DateTimeColumns {
        id: timePanel

        objectName: "dateTimeColumns"
        visible: control.view === "time"
        anchors.top: parent.top
        width: control.width
        height: control.columnHeight - control.switchHeight
        panelWidth: control.width
        pickerDate: control.pickerDate
        timeFormat: control.timeFormat
        hideDisabledOptions: control.hideDisabledOptions
        disabledHoursFn: control.disabledHoursFn
        disabledMinutesFn: control.disabledMinutesFn
        disabledSecondsFn: control.disabledSecondsFn

        onPicked: (hour, minute, second) => control.timePicked(hour, minute, second)
    }

    // ---- 年月面板（同样盖住月历）----
    DateYearMonthPanel {
        id: yamPanel

        objectName: "dateYearMonthPanel"
        visible: control.view === "yam"
        anchors.top: parent.top
        width: control.width
        height: control.columnHeight - control.switchHeight
        pickerDate: control.pickerDate
        showBack: control.showYamBackButton
        compact: control.densityCompact
        startYear: control.startYear
        endYear: control.endYear
        isRightPanel: control.panelIndex === 1
        leftYear: control.leftYear
        leftMonth: control.leftMonth
        disabledDateFn: control.disabledDateFn

        onYearPicked: (year) => control.yamYearPicked(year)
        onMonthPicked: (month) => control.yamMonthPicked(month)
        onBackClicked: control.backToDates()
    }
}
