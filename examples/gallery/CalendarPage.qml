pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Calendar 日历。小节与标题对齐官方文档页 content/show/calendar/index.md：
// 如何引入 + 日视图 + 周视图 + 月视图 + 设置周起始日 + 多日视图 + 事件渲染用法 + 自定义渲染
// （最后一节官方是三份 demo：自定义事件、自定义单元格样式、自定义日期文案）。
//
// 官方这几份 demo 的事件对象都是 `{ key, start, end, allDay, children: <div/> }`，
// 看到的描边、底色、内边距全部来自 children 那一段节点 —— 组件自己一个字都不画。
// 端口的 children 收字符串或 Component，所以下面把官方那两组 style 落成两个 Component，
// 文字挂在事件对象的 label 上（官方是把文字直接写进 div 里的）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property string eventDemoMode: "week"
    property var eventDemoDate: new Date(2019, 6, 23, 8, 32, 0)
    readonly property bool eventDemoIsMonth: page.eventDemoMode === "month"

    // 官方「设置周起始日」那节的 useState(0)
    property int weekStart: 0

    // 官方 renderDateDisplay 那节用的 Avatar 色档（avatar.scss 的 @mixin avatar-style
    // 取的是 --semi-{color}-3 那一档，字是 white）
    readonly property var avatarFamilies: ["amber", "blue", "cyan", "green", "grey", "indigo", "lime"]

    // 官方「事件渲染用法」那十条，逐条照抄时间、文字与用哪一组样式
    readonly property var eventDemoEvents: [
        { key: "0", start: new Date(2019, 5, 25, 14, 45, 0), end: new Date(2019, 6, 26, 6, 18, 0),
          label: qsTr("6月25日 14:45 ~ 7月26日 6:18"),
          children: page.eventDemoIsMonth ? page.allDayNode : page.dailyNode },
        { key: "1", start: new Date(2019, 6, 18, 10, 0, 0), end: new Date(2019, 6, 30, 8, 0, 0),
          label: qsTr("7月18日 10:00 ~ 7月30日 8:00"), children: page.allDayNode },
        { key: "2", start: new Date(2019, 6, 19, 20, 0, 0), end: new Date(2019, 6, 23, 14, 0, 0),
          label: qsTr("7月19日 20:00 ~ 7月23日 14:00"), children: page.allDayNode },
        { key: "3", start: new Date(2019, 6, 21, 6, 0, 0), end: new Date(2019, 6, 25, 6, 0, 0),
          label: qsTr("7月21日 6:00 ~ 7月25日 6:00"), children: page.allDayNode },
        { key: "4", allDay: true, start: new Date(2019, 6, 22, 8, 0, 0),
          label: qsTr("7月22日 全天"), children: page.allDayNode },
        { key: "5", start: new Date(2019, 6, 22, 9, 0, 0), end: new Date(2019, 6, 23, 23, 0, 0),
          label: qsTr("7月22日 9:00 ~ 7月23日 23:00"), children: page.allDayNode },
        { key: "6", start: new Date(2019, 6, 23, 8, 32, 0), end: new Date(2019, 6, 23, 8, 42, 0),
          label: qsTr("7月23日 8:32"),
          children: page.eventDemoIsMonth ? page.allDayNode : page.dailyNode },
        { key: "7", start: new Date(2019, 6, 23, 14, 30, 0), end: new Date(2019, 6, 23, 20, 0, 0),
          label: qsTr("7月23日 14:30-20:00"),
          children: page.eventDemoIsMonth ? page.allDayNode : page.dailyNode },
        { key: "8", start: new Date(2019, 6, 25, 8, 0, 0), end: new Date(2019, 6, 27, 6, 0, 0),
          label: qsTr("7月25日 8:00 ~ 7月27日 6:00"), children: page.allDayNode },
        { key: "9", start: new Date(2019, 6, 26, 10, 0, 0), end: new Date(2019, 6, 27, 16, 0, 0),
          label: qsTr("7月26日 10:00 ~ 7月27日 16:00"), children: page.allDayNode }
    ]

    // 官方 dailyEventStyle：primary 1px 描边 + primary-light-default 底 + 10px 内边距
    component DailyNode: Rectangle {
        id: dailyNode

        property var event: null

        radius: 3
        color: Theme.current.colorPrimaryLightDefault
        border.width: 1
        border.color: Theme.current.colorPrimary
        clip: true

        Text {
            anchors.fill: parent
            anchors.margins: 10
            text: dailyNode.event !== null ? dailyNode.event.label : ""
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            elide: Text.ElideRight
        }
    }

    // 官方 allDayStyle：bg-1 1px 描边 + primary-light-active 底 + 2px/4px 内边距
    component AllDayNode: Rectangle {
        id: allDayNode

        property var event: null

        radius: 3
        color: Theme.current.colorPrimaryLightActive
        border.width: 1
        border.color: Theme.current.colorBg1
        clip: true

        Text {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            text: allDayNode.event !== null ? allDayNode.event.label : ""
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    readonly property Component dailyNode: DailyNode {}
    readonly property Component allDayNode: AllDayNode {}

    // 官方「自定义渲染事件」：命中 2019-07-23 那一列时摆三个绝对定位的块
    readonly property string bandDay: new Date(2019, 6, 23).toString()

    component BandCells: Item {
        id: bandCells

        property var date: null
        property string dateString: ""

        readonly property bool hit: bandCells.dateString === page.bandDay

        Item {
            anchors.fill: parent
            visible: bandCells.hit

            Repeater {
                // 官方那三段：top 0 / 500 / 700，高 400 / 50 / 100
                model: [
                    { top: 0, h: 400, text: qsTr("睡觉 😪") },
                    { top: 500, h: 50, text: qsTr("吃饭 🍰") },
                    { top: 700, h: 100, text: qsTr("打豆豆 🎮") }
                ]

                delegate: Rectangle {
                    id: bandCell

                    required property var modelData

                    x: 0
                    y: bandCell.modelData.top
                    width: bandCells.width
                    height: bandCell.modelData.h
                    radius: 3
                    color: Theme.current.colorPrimaryLightDefault
                    border.width: 1
                    border.color: Theme.current.colorPrimary
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.margins: 10
                        text: bandCell.modelData.text
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }
        }
    }

    // 官方「自定义渲染单元格样式」：重要日期整格铺 danger-light-default。
    // 月视图里日期数字的 z 比自定义层高（官方 `-date { z-index: 3 }`），所以数字仍然看得见。
    readonly property var importantDays: [new Date(2019, 6, 2).toString(),
        new Date(2019, 6, 8).toString(), new Date(2019, 6, 19).toString(),
        new Date(2019, 6, 23).toString()]

    component ImportantCell: Item {
        id: importantCell

        property var date: null
        property string dateString: ""

        Rectangle {
            anchors.fill: parent
            visible: page.importantDays.indexOf(importantCell.dateString) >= 0
            color: Theme.current.colorDangerLightDefault
        }
    }

    // 官方「自定义日期文案」：`<Avatar color={colors[date.getDay()]} size="small">`。
    // 本库 Avatar 的文字档只取首字（两位数会被截），所以这里照 avatar-style 自己铺一颗。
    component AvatarDay: Rectangle {
        id: avatarDay

        property var date: null
        property string dateString: ""

        width: 32
        height: 32
        radius: width / 2
        visible: avatarDay.date !== null
        color: avatarDay.date !== null
            ? Theme.current[page.avatarFamilies[avatarDay.date.getDay()]][3] : "transparent"

        Text {
            anchors.centerIn: parent
            text: avatarDay.date !== null ? avatarDay.date.getDate() : ""
            color: Theme.current.colorWhite
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    readonly property Component bandCellsNode: BandCells {}
    readonly property Component importantCellNode: ImportantCell {}
    readonly property Component avatarDayNode: AvatarDay {}

    component Note: Text {
        width: 640
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Column {
                spacing: 12
                width: parent.width

                Text {
                    text: qsTr("Calendar 自 0.x 支持；weekStartsOn 自 2.18，minEventHeight 自 2.49。")
                    font.pixelSize: Theme.current.fontSizeRegular
                    color: Theme.current.colorText1
                }

                Text {
                    width: 640
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    color: Theme.current.colorText0
                    font.family: "Menlo"
                    font.pixelSize: 13
                    text: "import Semi\n\nCalendar {\n    mode: \"week\"\n    displayValue: new Date(2026, 9, 8)\n    events: [\n        { key: \"a\", start: new Date(2026, 9, 8), children: \"季度评审\" }\n    ]\n}"
                }
            }
        }

        GallerySection {
            title: "日视图"

            Column {
                width: 640
                spacing: 12

                Calendar {
                    width: parent.width
                    mode: "day"
                }

                Note {
                    text: qsTr("单列时间轴：左边一列小时刻度，带时刻的事件排进轴里，全天事件进顶部的「全天」带。"
                        + "红线是当前时刻，showCurrTime 关掉就没有（官方默认是开着）；只有当天那一列会画。")
                }
            }
        }

        GallerySection {
            title: "周视图"

            Column {
                width: 640
                spacing: 12

                Calendar {
                    width: parent.width
                    mode: "week"
                }

                Note {
                    text: qsTr("和日视图同一套时间轴，只是七列。官方 mode 的缺省值就是 week —— "
                        + "不写 mode 时进来的是这一档。列最小宽 130，七列要 980px，"
                        + "容器比这窄就横向滚（官方同理，那条 overflow: auto）。")
                }
            }
        }

        GallerySection {
            title: "月视图"

            Column {
                width: 640
                spacing: 12

                Calendar {
                    id: monthCalendar

                    width: parent.width
                    mode: "month"
                    markWeekend: true

                    Row {
                        spacing: 12

                        Text {
                            text: monthCalendar.title
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeHeader6
                            font.weight: Font.DemiBold
                        }

                        Button {
                            text: qsTr("上月")
                            variant: Enums.Light
                            size: Enums.Small
                            onClicked: monthCalendar.displayValue = new Date(
                                monthCalendar.displayValue.getFullYear(),
                                monthCalendar.displayValue.getMonth() - 1, 1)
                        }

                        Button {
                            text: qsTr("下月")
                            variant: Enums.Light
                            size: Enums.Small
                            onClicked: monthCalendar.displayValue = new Date(
                                monthCalendar.displayValue.getFullYear(),
                                monthCalendar.displayValue.getMonth() + 1, 1)
                        }
                    }
                }

                Note {
                    text: qsTr("月视图不带任何翻页与标题：官方压根没有头部，`title` 是本库给的便利串，"
                        + "上面那行是自己塞进默认属性（头部槽）里的，翻月就是改 displayValue。"
                        + "markWeekend 会把周末列铺灰。格子里放不下时右下角出「还有 N 项」，"
                        + "点开是一张 220px 的卡片，× 或点卡片外面都能关。"
                        + "每月 1 号那一格写的是「10月 1日」——官方那三段是**一段行内文本**"
                        + "（`-month-date` 里 `{LLL}` + `&nbsp;1` + `日`，行盒走 `-skeleton li span` 的 20）"
                        + "⇒ 天然同基线；本库拆成三块，靠同一档定高 + 垂直居中对齐。")
                }
            }
        }

        GallerySection {
            title: "设置周起始日"

            Column {
                width: 640
                spacing: 16

                RadioGroup {
                    value: page.weekStart
                    type: Enums.ChoiceButton
                    onChanged: (v) => page.weekStart = v

                    Radio { value: 0; text: qsTr("周日") }
                    Radio { value: 1; text: qsTr("周一") }
                    Radio { value: 2; text: qsTr("周二") }
                    Radio { value: 3; text: qsTr("周三") }
                    Radio { value: 4; text: qsTr("周四") }
                    Radio { value: 5; text: qsTr("周五") }
                    Radio { value: 6; text: qsTr("周六") }
                }

                Calendar {
                    width: parent.width
                    mode: "month"
                    weekStartsOn: page.weekStart
                }

                Note {
                    text: qsTr("weekStartsOn 取 0~6（周日到周六），缺省 0；月视图与周视图都吃这一条，"
                        + "表头那一行的顺序跟着轮转。周末铺灰看的永远是周六周日，与这一条无关。")
                }
            }
        }

        GallerySection {
            title: "多日视图"

            Column {
                width: 640
                spacing: 12

                Calendar {
                    width: parent.width
                    mode: "range"
                    range: [new Date(2020, 8, 26), new Date(2020, 8, 31)]
                }

                Note {
                    text: qsTr("range 必传，口径是左闭右开：上面这组是 8 月 26 到 30 共五列，"
                        + "31 号不进窗口。这一档复用的是周视图那套排布。")
                }
            }
        }

        GallerySection {
            title: "事件渲染用法"

            Column {
                width: 640
                spacing: 12

                RadioGroup {
                    value: page.eventDemoMode
                    type: Enums.ChoiceButton
                    onChanged: (v) => page.eventDemoMode = v

                    Radio { value: "day"; text: qsTr("日视图") }
                    Radio { value: "week"; text: qsTr("周视图") }
                    Radio { value: "month"; text: qsTr("月视图") }
                    Radio { value: "range"; text: qsTr("多日视图") }
                }

                DatePicker {
                    value: page.eventDemoDate
                    onChanged: (date) => page.eventDemoDate = date
                }

                Calendar {
                    width: 640
                    height: 400
                    mode: page.eventDemoMode
                    displayValue: page.eventDemoDate
                    events: page.eventDemoEvents
                    minEventHeight: 40
                    range: page.eventDemoMode === "range"
                        ? [new Date(2019, 6, 23), new Date(2019, 6, 26)] : []
                }

                Note {
                    text: qsTr("事件对象是 { key, start, end, allDay, children }：key 必填且要唯一，"
                        + "children 是条上那段节点（字符串或 Component 都收，官方那两组 style 就是上面的 "
                        + "dailyNode / allDayNode，文字挂在 label 上）。"
                        + "跨天满 24 小时的定时事件会被升级成全天条带，跨天不足 24 小时的会拆成两条"
                        + "（首日铺到 24 点、末日从 0 点起）；只给一头的由 amendEvent 补另一头。"
                        + "minEventHeight 只压时间轴那三档的最短高度。")
                }
            }
        }

        GallerySection {
            title: "自定义渲染"

            Column {
                width: 640
                spacing: 16

                GalleryLabel {
                    text: qsTr("自定义渲染事件")
                }

                Note {
                    text: qsTr("dateGridRender 给一周里每一列都摆一份节点，节点里自己按注入的 "
                        + "date / dateString 判断要不要画。官方要求绝对定位 —— 端口的这一层是铺满整列的"
                        + "（1440px 高），所以子项直接写 x / y / width / height。")
                }

                Calendar {
                    width: 640
                    height: 700
                    mode: "week"
                    displayValue: new Date(2019, 6, 23, 8, 32, 0)
                    dateGridRender: page.bandCellsNode
                }

                GalleryLabel {
                    text: qsTr("自定义渲染单元格样式")
                }

                Note {
                    text: qsTr("同一份 prop 也能铺整格背景。月视图里日期数字压在这层上面"
                        + "（官方 `-date` 的 z-index 是 3），要完全盖住就给自己那个根节点写更大的 z。")
                }

                Calendar {
                    width: 640
                    height: 700
                    mode: "month"
                    displayValue: new Date(2019, 6, 23, 8, 32, 0)
                    dateGridRender: page.importantCellNode
                }

                GalleryLabel {
                    text: qsTr("自定义日期文案")
                }

                Note {
                    text: qsTr("renderDateDisplay 换掉周视图表头里那块日期（注入 date 与 dateString）。"
                        + "官方那一节用的是 date.getDay() 取色档的一圈小 Avatar，"
                        + "本库的 Avatar 文字档只取首字，所以这里按 avatar.scss 的色档自己铺了一颗圆。")
                }

                Calendar {
                    width: 640
                    height: 400
                    mode: "week"
                    displayValue: new Date(2023, 4, 14)
                    renderDateDisplay: page.avatarDayNode
                }
            }
        }
    }
}
