pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 官方示例：content/input/datepicker/index.md（21 个 demo，标题与 docs.json 一致）
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ---- 各 demo 的受控状态 ----
    property string basicText: ""
    property string panelText: ""
    property string confirmText: "（打开面板，选一个日期时间，再点确定或取消）"
    property string controlledDate: ""
    property int slotTab: 0
    property string customTriggerDate: ""
    property var weekValue: []

    // 周一为一周的第一天
    function startOfWeek(date) {
        const d = new Date(date);
        const lead = (d.getDay() - 1 + 7) % 7;
        d.setDate(d.getDate() - lead);
        d.setHours(0, 0, 0, 0);
        return d;
    }

    function addDays(date, days) {
        const d = new Date(date);
        d.setDate(d.getDate() + days);
        return d;
    }

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function dayKey(date) {
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本使用"

            Column {
                spacing: 12

                DatePicker {
                    width: 240
                    onChanged: (date, dateString) => page.basicText = dateString
                }

                TextLabel {
                    text: page.basicText === "" ? qsTr("还没有选择")
                        : qsTr("onChange 收到：%1").arg(page.basicText)
                }
            }
        }

        GallerySection {
            title: "小尺寸"

            Column {
                spacing: 16

                DatePicker {
                    type: Enums.TypeDateTime
                    density: Enums.DensityCompact
                }

                DatePicker {
                    width: 260
                    type: Enums.TypeDateRange
                    density: Enums.DensityCompact
                }
            }
        }

        GallerySection {
            title: "多个日期选择"

            DatePicker {
                width: 240
                multiple: true
            }
        }

        GallerySection {
            title: "日期与时间选择"

            Column {
                spacing: 12

                TextLabel { text: qsTr("默认日期与时间选择") }

                DatePicker { type: Enums.TypeDateTime }

                TextLabel {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: qsTr("官方还有一个「开启时间列表无限循环」的例子，它靠 timePickerOpts"
                        + "把时间列换成 wheel 模式；本库的时间列只有 normal 一种，"
                        + "timePickerOpts / yearAndMonthOpts 暂未实现。")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "日期范围选择"

            DatePicker {
                width: 260
                type: Enums.TypeDateRange
            }
        }

        GallerySection {
            title: "日期范围时间选择"

            DatePicker {
                width: 400
                type: Enums.TypeDateTimeRange
            }
        }

        GallerySection {
            title: "内嵌输入框"

            Column {
                spacing: 16

                DatePicker { type: Enums.TypeDate; insetInput: true }

                DatePicker { type: Enums.TypeDateTime; insetInput: true }

                DatePicker { width: 260; type: Enums.TypeDateRange; insetInput: true }

                DatePicker { width: 400; type: Enums.TypeDateTimeRange; insetInput: true }

                DatePicker { width: 140; type: Enums.TypeMonth; insetInput: true
                    placeholder: qsTr("请选择年月") }

                DatePicker { width: 200; type: Enums.TypeMonthRange; insetInput: true
                    placeholder: qsTr("请选择年月范围") }

                DatePicker { type: Enums.TypeDate; insetInput: true; position: Enums.BottomLeft }

                DatePicker { type: Enums.TypeDateTime; insetInput: true
                    format: "yyyy-MM-dd HH:mm" }
            }
        }

        GallerySection {
            title: "同步切换双面板月份"

            DatePicker {
                width: 400
                type: Enums.TypeDateTimeRange
                syncSwitchMonth: true
            }
        }

        GallerySection {
            title: "切换面板日期的回调"

            Column {
                spacing: 12

                DatePicker {
                    width: 400
                    type: Enums.TypeDateTimeRange
                    syncSwitchMonth: true
                    onPanelChanged: (date, dateString) => page.panelText = String(dateString)
                }

                TextLabel {
                    text: page.panelText === "" ? qsTr("翻一翻月份，看 onPanelChange 的入参")
                        : qsTr("onPanelChange：%1").arg(page.panelText)
                }
            }
        }

        GallerySection {
            title: "周选择"

            Column {
                spacing: 16

                Column {
                    spacing: 8

                    TextLabel { text: qsTr("选择自然周") }

                    DatePicker {
                        width: 260
                        type: Enums.TypeDateRange
                        weekStartsOn: 1
                        startDateOffset: (date) => page.startOfWeek(date)
                        endDateOffset: (date) => page.addDays(page.startOfWeek(date), 6)
                    }
                }

                Column {
                    spacing: 8

                    TextLabel { text: qsTr("选择双周") }

                    DatePicker {
                        width: 260
                        type: Enums.TypeDateRange
                        weekStartsOn: 1
                        startDateOffset: (date) => page.startOfWeek(date)
                        endDateOffset: (date) => page.addDays(page.startOfWeek(date), 13)
                    }
                }

                Column {
                    spacing: 8

                    TextLabel { text: qsTr("选择当前日和后6日") }

                    DatePicker {
                        width: 260
                        type: Enums.TypeDateRange
                        weekStartsOn: 1
                        endDateOffset: (date) => page.addDays(date, 6)
                    }
                }
            }
        }

        GallerySection {
            title: "年月选择"

            DatePicker {
                width: 140
                type: Enums.TypeMonth
                defaultValue: new Date()
            }
        }

        GallerySection {
            title: "年月范围选择"

            DatePicker {
                width: 200
                type: Enums.TypeMonthRange
            }
        }

        GallerySection {
            title: "确认日期时间选择"

            Column {
                spacing: 12

                DatePicker {
                    type: Enums.TypeDateTime
                    needConfirm: true
                    onChanged: (date, dateString) => page.confirmText
                        = qsTr("onChange（还没确认）：%1").arg(dateString)
                    onConfirmed: (date, dateString) => page.confirmText
                        = qsTr("onConfirm：%1").arg(dateString)
                    onCancelled: (date, dateString) => page.confirmText
                        = qsTr("onCancel：%1").arg(dateString)
                }

                TextLabel {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: page.confirmText
                }
            }
        }

        GallerySection {
            title: "带有快捷方式的日期时间选择"

            Column {
                spacing: 12

                DatePicker {
                    type: Enums.TypeDateTime
                    presetPosition: Enums.PresetLeft
                    presets: [
                        { text: "Today", start: new Date(), end: new Date() },
                        { text: "Tomorrow", start: page.addDays(new Date(), 1),
                          end: page.addDays(new Date(), 1) }
                    ]
                }

                DatePicker {
                    width: 260
                    type: Enums.TypeDateRange
                    presets: [
                        { text: qsTr("最近一周"), start: page.addDays(new Date(), -6),
                          end: new Date() },
                        { text: qsTr("最近一个月"), start: page.addDays(new Date(), -30),
                          end: new Date() }
                    ]
                }
            }
        }

        GallerySection {
            title: "渲染顶部/底部额外区域"

            Column {
                spacing: 16

                DatePicker {
                    id: slotPicker

                    width: 260
                    placeholder: qsTr("请选择排期")
                    value: page.controlledDate === "" ? undefined : page.controlledDate
                    topSlot: Component {
                        Row {
                            spacing: 0
                            topPadding: 12
                            leftPadding: 20
                            rightPadding: 20

                            Tabs {
                                tabList: [
                                    { itemKey: "0", tab: qsTr("UED 排期") },
                                    { itemKey: "1", tab: qsTr("测试排期") }
                                ]
                                size: "small"
                                activeKey: String(page.slotTab)

                                onTabClick: key => {
                                    page.slotTab = Number(key);
                                    page.controlledDate = "";
                                }
                            }
                        }
                    }
                    // 两个页签各有各的禁用区间
                    disabledDate: (date) => {
                        const day = date.getDate();
                        return page.slotTab === 0 ? (day > 10 && day < 15) : (day > 15 && day < 25);
                    }
                    onChanged: (date, dateString) => page.controlledDate = dateString
                }

                DatePicker {
                    placeholder: qsTr("请选择发版时间")
                    bottomSlot: Component {
                        Row {
                            spacing: 8
                            padding: 12
                            leftPadding: 20
                            rightPadding: 20

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "bulb"
                                size: 16
                                color: Theme.current.amber[5]
                            }

                            TextLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("定版前请阅读")
                                strong: true
                                tone: Enums.Tertiary
                            }

                            TextLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("发版须知")
                                color: Theme.current.colorPrimary
                            }
                        }
                    }
                }

                DatePicker {
                    type: Enums.TypeMonth
                    width: 160
                    placeholder: qsTr("请选择年月")
                    bottomSlot: Component {
                        Row {
                            spacing: 8
                            padding: 12
                            leftPadding: 20
                            rightPadding: 20

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "bulb"
                                size: 16
                                color: Theme.current.amber[5]
                            }

                            TextLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("请阅读")
                                strong: true
                                tone: Enums.Tertiary
                            }

                            TextLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("须知")
                                color: Theme.current.colorPrimary
                            }
                        }
                    }
                }

                DatePicker {
                    placeholder: qsTr("小尺寸")
                    density: Enums.DensityCompact
                    topSlot: Component {
                        Row {
                            spacing: 0
                            topPadding: 8
                            leftPadding: 12
                            rightPadding: 12

                            Tabs {
                                tabList: [
                                    { itemKey: "0", tab: qsTr("UED 排期") },
                                    { itemKey: "1", tab: qsTr("测试排期") }
                                ]
                                size: "small"
                                activeKey: String(page.slotTab)

                                // 官方这一节两个选择器共用同一个 TopSlot（同一个 activeTab
                                // + 同一个 onChange），所以这里也要接上
                                onTabClick: key => {
                                    page.slotTab = Number(key);
                                    page.controlledDate = "";
                                }
                            }
                        }
                    }
                    bottomSlot: Component {
                        Row {
                            spacing: 8
                            padding: 8
                            leftPadding: 12
                            rightPadding: 12

                            TextLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("定版前请阅读")
                                tone: Enums.Tertiary
                            }

                            TextLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("发版须知")
                                color: Theme.current.colorPrimary
                            }
                        }
                    }
                }

                DatePicker {
                    width: 400
                    type: Enums.TypeDateTimeRange
                    bottomSlot: Component {
                        Row {
                            spacing: 8
                            padding: 12
                            leftPadding: 20
                            rightPadding: 20

                            TextLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("定版前请阅读")
                                tone: Enums.Tertiary
                            }

                            TextLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("发版须知")
                                color: Theme.current.colorPrimary
                            }
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "禁用日期选择"

            DatePicker {
                disabled: true
                type: Enums.TypeDateTime
                defaultValue: new Date()
            }
        }

        GallerySection {
            title: "禁用部分日期或时间"

            Column {
                spacing: 16

                Column {
                    spacing: 8

                    TextLabel { text: qsTr("禁用时间：禁用今天下午5-6点") }

                    DatePicker {
                        type: Enums.TypeDateTime
                        hideDisabledOptions: false
                        disabledTime: (date) => {
                            if (page.dayKey(date) !== page.dayKey(new Date()))
                                return null;
                            return {
                                disabledHours: () => [17, 18],
                                disabledMinutes: (hour) => hour === 19 ? [0, 1, 2, 3, 4, 5,
                                                                           6, 7, 8, 9] : [],
                                disabledSeconds: (hour, minute) =>
                                    (hour === 20 && minute === 20) ? [0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                                                                      10, 11, 12, 13, 14, 15, 16, 17, 18, 19] : []
                            };
                        }
                    }
                }

                Column {
                    spacing: 8

                    TextLabel { text: qsTr("禁用时间：两个面板禁用不同时间") }

                    DatePicker {
                        width: 400
                        type: Enums.TypeDateTimeRange
                        hideDisabledOptions: false
                        disabledTime: (date, panelType) => panelType === "left"
                            ? { disabledHours: () => [17, 18] }
                            : { disabledHours: () => [12, 13, 14, 15, 16, 17, 18] }
                    }
                }

                Column {
                    spacing: 8

                    TextLabel { text: qsTr("禁用日期：禁用下个月28号之前的所有日期") }

                    DatePicker {
                        width: 400
                        type: Enums.TypeDateTimeRange
                        disabledDate: (date) => {
                            const dead = new Date();
                            dead.setDate(28);
                            dead.setMonth((dead.getMonth() + 1) % 12);
                            return date.getTime() < dead.getTime();
                        }
                        defaultPickerValue: new Date()
                    }
                }

                Column {
                    spacing: 8

                    TextLabel { text: qsTr("动态禁用日期：禁止选择之前的日期") }

                    DatePicker {
                        width: 260
                        type: Enums.TypeDateRange
                        disabledDate: (date, options) => {
                            if (!options.rangeStart)
                                return false;
                            const start = new Date(options.rangeStart);
                            return date.getTime() < start.getTime();
                        }
                    }
                }

                Column {
                    spacing: 8

                    TextLabel {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: qsTr("按焦点禁用：开始日期禁用今天前2日和后2日，"
                            + "结束日期禁用今天前3天和后3天")
                    }

                    DatePicker {
                        width: 260
                        type: Enums.TypeDateRange
                        disabledDate: (date, options) => {
                            const base = new Date();
                            base.setHours(0, 0, 0, 0);
                            const focus = options.rangeInputFocus;
                            const back = focus === "rangeEnd" ? 3 : 2;
                            const start = page.addDays(base, -back);
                            const end = page.addDays(base, back);
                            if (focus === false)
                                return false;
                            return date.getTime() >= start.getTime()
                                && date.getTime() <= end.getTime();
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "自定义显示格式"

            DatePicker {
                width: 240
                format: "yyyy年MM月dd日 HH:mm"
                type: Enums.TypeDateTime
                defaultValue: new Date()
            }
        }

        GallerySection {
            title: "自定义触发器"

            DatePicker {
                id: customTriggerPicker

                format: "yyyy-MM-dd"
                value: page.customTriggerDate === "" ? undefined : page.customTriggerDate
                triggerRender: Component {
                    Button {
                        id: triggerButton

                        property var placeholder: ""

                        text: page.customTriggerDate === ""
                            ? String(triggerButton.placeholder) : page.customTriggerDate
                        variant: Enums.Light
                        icon: page.customTriggerDate === "" ? "chevron_down" : "close"

                        onClicked: {
                            if (page.customTriggerDate === "")
                                customTriggerPicker.openPanel();
                            else
                                customTriggerPicker.clear();
                        }
                    }
                }
                onChanged: (date, dateString) => page.customTriggerDate = dateString
            }
        }

        GallerySection {
            title: "自定义日期显示内容"

            DatePicker {
                width: 260
                renderDate: Component {
                    Rectangle {
                        id: dateCell

                        property var dayNumber: ""
                        property var fullDate: ""

                        width: 28
                        height: 28
                        radius: Theme.current.radiusSmall
                        border.width: 1
                        border.color: Theme.current.colorPrimary
                        color: "transparent"
                        visible: Number(dateCell.dayNumber) === 1

                        Text {
                            anchors.centerIn: parent
                            text: String(dateCell.dayNumber)
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "自定义日期格子渲染"

            DatePicker {
                width: 260
                type: Enums.TypeDateRange
                renderFullDate: Component {
                    Rectangle {
                        id: fullCell

                        property var dayNumber: ""
                        property var fullDate: ""
                        property var dayStatus: ({})

                        readonly property var s: dayStatus

                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: s.isSelected || s.isSelectedStart || s.isSelectedEnd
                            ? Theme.current.colorPrimary
                            : (s.isInRange || s.isHover ? Theme.current.colorPrimaryLightDefault
                                : "transparent")

                        Text {
                            anchors.centerIn: parent
                            text: String(fullCell.dayNumber)
                            color: fullCell.s.isSelected || fullCell.s.isSelectedStart
                                || fullCell.s.isSelectedEnd
                                ? Theme.current.colorWhite : Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                        }
                    }
                }
            }
        }
    }
}
