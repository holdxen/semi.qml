pragma ComponentBehavior: Bound

import QtQuick

// 时间轴条目。官方叫 Timeline.Item，QML 里没有嵌套类型，就拆成 TimelineItem 单独一个文件，
// 由 Timeline 生成（dataSource）或直接声明在 Timeline 里（官方 JSX 写法）。
//
// 三个 timeline 角色（timelineIndex / timelineCount / timelineMode）由 Timeline 推下来：
// 官方也是父项 cloneElement 给条目加位置类名（index.tsx:62-73），条目自己并不知道自己在第几个。
// 单摆一个 TimelineItem 也能画，只是位置一律按 left 档算。
//
// 度量全部来自 packages/semi-foundation/timeline/{timeline,variables}.scss，
// 并且逐条对过 DOM 实测（tests/tmp_timeline_dom.html，量出来的数记在 docs/gallery-progress.md）：
//   条目高 = 正文块 + $spacing-loose 24 的下边距；
//   连线 -tail：top 20、宽 1（$width-timeline_tail-border = $border-thickness-control）、
//       高 = 条目高 - 20（正好接到下一条的顶边），最后一个条目不画（:last-child）；
//   圆点 -head：top 5、9×9、圆形，色按 type；
//   自定义 dot -head-custom：锚点 (left, 10) + translate(-50%,-50%)，即中心落在 (left, 10)，
//       背景被 -head-custom.-head-<type> 清成 transparent，type 色靠 CSS color 继承到图标上；
//   正文 -content：14/20（font-size-regular）text-0，margin-left 25；
//   -content-extra / -content-time：12/16（font-size-small）text-2，margin-top 4。
//
// 轴线和正文的横向关系（mode 决定，实测逐档核对）：
//   left              轴在边上（线 x=4、点 x=0、自定义 dot 中心 x=5），正文 x=25、宽 = 条目宽 - 25，左对齐；
//                     这一档 -item-left 的百分比规则根本不存在（scss 只写在 alternate/right/center 里），
//                     而 getPosCls 在 left/right 档直接返回 mode、不看 position（index.tsx:53-54），
//                     所以 mode="left" 下给条目写 position 不生效。
//   center / alternate 轴在条目宽 50% 处（线 x=W/2、点 x=W/2-4、自定义 dot 中心 x=W/2）；
//                     左侧条目：正文 x=W/2+21（margin 25 + relative left W/2-4）、宽 W/2-14，左对齐；
//                     右侧条目：margin 归 0、x=0、宽 W/2-20，右对齐；
//   right             条目整体靠右：线 x=W-9、点 x=W-13、自定义 dot 中心 x=W-9，正文 x=0、宽 W-28，右对齐。
//                     这是 compiled css 里 `.semi-timeline-right .semi-timeline-item-right .semi-timeline-item-*`
//                     那条赢下来的结果，实测轴确实贴右边缘、不是停在 50%；
//                     这一档里 position="left" 的条目仍走通用「左侧条目」公式（轴线回 50%）。
//   只有 center 档把 time 绝对定位到轴线左边（top -2 + margin-top 4，宽 = 正文宽，右对齐），
//   其余档位 time 按 DOM 顺序排在 extra 之后。
//
// 和官方的一处出入：mode="center" 下给某个条目写 position="right" 时，官方那条
// margin-left: calc(-40px - 100%) 会把 time 推到条目左边界外 280px（DOM 实测 x=-280，整行文字看不见）。
// 这里只在「整块都掉出条目左边界」时把 x 夹回 0（普通条目实测 -5 属可见范围，照抄）。
Item {
    id: control

    // Timeline 靠 objectName 认出条目、把序号和 mode 推下来（见 Timeline.syncRoles）
    objectName: "timelineItem"

    // ---- 官方 TimelineItemProps ----
    property string type: "default"       // default | ongoing | success | warning | error
    property string color: ""             // 圆点色值覆盖，空串就是不覆盖
    property string position: ""          // left | right，只在 center / alternate 下生效
    property var time: ""                 // string 或 Component
    property var extra: ""                // string 或 Component
    property var content: ""              // 官方是 children / Data.content，string 或 Component
    property Component dot: null

    signal clicked

    // ---- Timeline 推下来的角色 ----
    property int timelineIndex: 0
    property int timelineCount: 1
    property string timelineMode: "left"

    readonly property bool contentIsText: typeof control.content === "string"
    readonly property bool extraIsText: typeof control.extra === "string"
    readonly property bool timeIsText: typeof control.time === "string"
    readonly property bool hasExtra: control.extra !== undefined && control.extra !== null
        && String(control.extra) !== ""
    readonly property bool hasTime: control.time !== undefined && control.time !== null
        && String(control.time) !== ""

    // 槽位的高度要吃「这一格走文本还是走组件」这个**条件**，不能吃子项的 visible：
    // Item.visible 读回来是有效可见性（含祖先），而槽位自己的 visible 又由高度决定，
    // 于是「高度 0 → 槽位不可见 → 子项读来不可见 → 取组件那一支的高度 0」会自锁（实测卡死在 0）。
    readonly property bool showContentText: control.contentIsText && String(control.content) !== ""
    readonly property bool showExtraText: control.extraIsText
    readonly property bool showTimeText: control.timeIsText

    // 条目落在哪一侧：getPosCls（index.tsx:39-60）的结论，逐档抄
    readonly property string side: {
        if (control.timelineMode === "center")
            return control.position === "left" || control.position === "right"
                ? control.position : "left";
        if (control.timelineMode === "alternate")
            return control.position === "left" || control.position === "right"
                ? control.position : (control.timelineIndex % 2 === 0 ? "left" : "right");
        if (control.timelineMode === "left" || control.timelineMode === "right")
            return control.timelineMode;
        return "left";
    }

    // 轴线落在哪儿：left 档贴边、center / alternate 取中、right 档贴右。
    // right 档不用再判 side —— getPosCls 在那一档恒返回 -item-right（index.tsx:53-54），
    // 所以那条 `.semi-timeline-right .semi-timeline-item-right …{ left: calc(100% - 9px) }`
    // 对这一档的每个条目都成立，通用那档的 50% 永远轮不到。
    readonly property bool axisAtRight: control.timelineMode === "right"
    readonly property bool axisAtCenter: control.timelineMode === "center"
        || control.timelineMode === "alternate"

    // 连线左边缘。圆点永远比它再左 4（-head 的 margin-left: -4px；left 档没写 left，
    // 静态位置 0 而那一档 tailX 正好是 4，所以两种情况都是 tailX - 4）。
    readonly property real tailX: control.axisAtRight ? control.width - 9
        : (control.axisAtCenter ? control.width / 2 : 4)
    readonly property real dotX: control.tailX - 4
    // 自定义 dot 的锚点 x（-head-custom 的 left；中心就落在这儿）
    readonly property real customDotX: control.axisAtRight ? control.width - 9
        : (control.axisAtCenter ? control.width / 2 : 5)

    readonly property real contentX: control.timelineMode === "left" ? 25
        : (control.side === "left" ? control.width / 2 + 21 : 0)
    readonly property real contentW: Math.max(0,
        control.timelineMode === "left" ? control.width - 25
            : (control.side === "left" ? control.width / 2 - 14
                : (control.timelineMode === "right" ? control.width - 28 : control.width / 2 - 20)))
    readonly property bool alignRight: control.side === "right"

    // 只有 center 档把时间浮到轴线左边
    readonly property bool timeFloating: control.timelineMode === "center"
    readonly property real floatingTimeRawX: control.contentX - 40 - control.contentW
    // 官方普通条目实测就是 -5（负的那 5px 落在 ul 的 8px 内边距里，看得见），照抄。
    // 只有算到整块都掉出条目左边时才夹回来：center 档里给条目写 position="right"，
    // 官方的 margin-left: calc(-40px - 100%) 会算出 x=-280、右边缘 -40，文字整个看不见。
    readonly property real floatingTimeX: control.floatingTimeRawX + control.contentW < 0
        ? 0 : control.floatingTimeRawX

    readonly property bool isLast: control.timelineIndex === control.timelineCount - 1

    // type → 色值（variables.scss 的 5 个 dot 令牌）。认不出的一律按 default：
    // 官方那档没有 background-color、圆点直接消失，不算可用结果。
    readonly property color typeColor: {
        switch (control.type) {
        case "ongoing":
            return Theme.current.colorPrimary;
        case "success":
            return Theme.current.colorSuccess;
        case "warning":
            return Theme.current.colorWarning;
        case "error":
            return Theme.current.colorDanger;
        default:
            return Theme.current.colorTertiaryLightActive;
        }
    }
    // color 是内联样式，盖过 type；自定义 dot 的背景框同理（官方 -head-custom 只有 transparent）
    readonly property color dotColor: control.color !== "" ? control.color : control.typeColor
    readonly property color customDotBg: control.color !== "" ? control.color : "transparent"

    implicitWidth: 320
    // 官方 li 是 ul 内容框的 100%，父项就是 Timeline 那条列容器；单摆时退回 implicit
    width: control.parent ? control.parent.width : control.implicitWidth
    implicitHeight: flow.height + 24          // $spacing-timeline_item-paddingBottom

    // 连线：官方 -tail 高 calc(100% - 20px)，从 y=20 画到条目底边
    Rectangle {
        objectName: "timelineTail"
        visible: !control.isLast
        x: control.tailX
        y: 20                                  // $spacing-timeline_tail-top
        width: 1
        height: Math.max(0, control.height - 20)
        color: Theme.current.colorText3       // $color-timeline_tail-border
    }

    // 圆点（没给 dot 才有）
    Rectangle {
        objectName: "timelineDot"
        visible: !control.dot
        x: control.dotX
        y: 5                                   // $spacing-timeline_head-top
        width: 9                               // $width-timeline_dot
        height: 9
        radius: 4.5
        color: control.dotColor
    }

    // color 给自定义 dot 时官方是内联 background-color（-head-custom 圆角为 0，所以是个方框），
    // 它垫在图标下面
    Rectangle {
        objectName: "timelineCustomDotBg"
        visible: control.dot !== null && control.color !== ""
        x: dotLoader.x
        y: dotLoader.y
        width: dotLoader.width
        height: dotLoader.height
        color: control.customDotBg
    }

    // 自定义 dot：中心锚在 (customDotX, 10)
    Loader {
        id: dotLoader

        objectName: "timelineCustomDot"
        x: control.customDotX - width / 2
        y: 10 - height / 2                     // $spacing-timeline_head_custom-top
        sourceComponent: control.dot

        // 官方把 type 色写在 -head 的 color 上、图标靠 currentColor 继承；
        // QML 没有继承这一说，只能装载后把同一个色推给子项的 color。
        // （Loader.item 的静态类型是 QObject，读它的 color 得把缺失属性警告按下 —— 同 ListItem 那处）
        // qmllint disable missing-property
        onLoaded: {
            if (dotLoader.item && dotLoader.item.color !== undefined)
                dotLoader.item.color = control.typeColor;
        }
        // qmllint enable missing-property
    }

    // 正文纵向流：主内容 → extra → time（非 center 档），块间距 4（$spacing-timeline_time-marginTop）
    Column {
        id: flow

        objectName: "timelineFlow"
        x: control.contentX
        y: 0
        width: control.contentW
        spacing: 4

        // 主内容（官方 children，空就不占行）
        Item {
            id: contentSlot

            objectName: "timelineContentSlot"
            width: flow.width
            height: control.showContentText ? contentText.height : contentNode.height
            visible: height > 0

            Text {
                id: contentText

                objectName: "timelineContentText"
                visible: control.showContentText
                width: parent.width
                text: control.contentIsText ? control.content : ""
                horizontalAlignment: control.alignRight ? Text.AlignRight : Text.AlignLeft
                wrapMode: Text.WordWrap
                color: Theme.current.colorText0      // $color-timeline_item_content-text-default
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeight: 20                        // -content 的 14/20
                lineHeightMode: Text.FixedHeight
            }

            Loader {
                id: contentNode

                objectName: "timelineContentNode"
                visible: !control.showContentText
                active: !control.showContentText
                // 官方 children 是行内内容，跟着 text-align 走
                x: control.alignRight ? parent.width - width : 0
                sourceComponent: control.contentIsText ? null : control.content
            }
        }

        Item {
            id: extraSlot

            objectName: "timelineExtraSlot"
            width: flow.width
            height: control.showExtraText ? extraText.height : extraNode.height
            // 只有 time 会在 center 档脱流，extra 两支都在流里（DOM 实测 center 档 extra y=24）
            visible: control.hasExtra && height > 0

            Text {
                id: extraText

                objectName: "timelineExtraText"
                visible: control.showExtraText
                width: parent.width
                text: control.extraIsText ? control.extra : ""
                horizontalAlignment: control.alignRight ? Text.AlignRight : Text.AlignLeft
                wrapMode: Text.WordWrap
                color: Theme.current.colorText2      // $color-timeline_time_default-text-default
                font.pixelSize: Theme.current.fontSizeSmall
                lineHeight: 16                        // -content-extra 的 12/16
                lineHeightMode: Text.FixedHeight
            }

            Loader {
                id: extraNode

                objectName: "timelineExtraNode"
                visible: !control.showExtraText
                active: !control.showExtraText
                x: control.alignRight ? parent.width - width : 0
                sourceComponent: control.extraIsText ? null : control.extra
            }
        }

        Item {
            id: timeSlot

            objectName: "timelineTimeSlot"
            width: flow.width
            height: control.showTimeText ? timeText.height : timeNode.height
            visible: control.hasTime && !control.timeFloating && height > 0

            Text {
                id: timeText

                objectName: "timelineTimeText"
                visible: control.showTimeText
                width: parent.width
                text: control.timeIsText ? control.time : ""
                horizontalAlignment: control.alignRight ? Text.AlignRight : Text.AlignLeft
                wrapMode: Text.WordWrap
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                lineHeight: 16                        // -content-time 的 12/16
                lineHeightMode: Text.FixedHeight
            }

            Loader {
                id: timeNode

                objectName: "timelineTimeNode"
                visible: !control.showTimeText
                active: !control.showTimeText
                x: control.alignRight ? parent.width - width : 0
                sourceComponent: control.timeIsText ? null : control.time
            }
        }
    }

    // center 档的 time：绝对到轴线左边、右对齐、宽 = 正文宽（官方是 -content-time 那 5 行）
    Item {
        id: floatingSlot

        objectName: "timelineFloatingSlot"
        x: control.floatingTimeX
        y: 2                                          // top -2 + margin-top 4
        width: control.contentW
        height: control.showTimeText ? floatingTimeText.height : floatingTimeNode.height
        visible: control.timeFloating && control.hasTime && height > 0

        Text {
            id: floatingTimeText

            objectName: "timelineFloatingTimeText"
            visible: control.showTimeText
            width: parent.width
            text: control.timeIsText ? control.time : ""
            horizontalAlignment: Text.AlignRight      // 官方这一档恒右对齐
            wrapMode: Text.WordWrap
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeSmall
            lineHeight: 16
            lineHeightMode: Text.FixedHeight
        }

        Loader {
            id: floatingTimeNode

            objectName: "timelineFloatingTimeNode"
            visible: !control.showTimeText
            active: !control.showTimeText
            x: parent.width - width
            sourceComponent: control.timeIsText ? null : control.time
        }
    }

    // 官方 onClick 挂在 li 上，条目整块都是点击区
    TapHandler {
        onTapped: control.clicked()
    }
}
