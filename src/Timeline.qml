pragma ComponentBehavior: Bound

import QtQuick
import QtQml

// 时间轴。官方 TimelineProps 只有三个可见属性：mode、dataSource，加上 JSX 的 children；
// QML 里 children 就是直接声明在 Timeline 里的 TimelineItem（官方写法 <Timeline><Timeline.Item/>）。
//
//     // 声明式（官方 JSX）
//     Timeline {
//         TimelineItem { time: "2019-07-14 10:35"; content: "第一个节点内容" }
//         TimelineItem { time: "2019-06-13 16:17"; content: "第二个节点内容"; type: "success" }
//     }
//     // dataSource（官方 dataSource，二选一：给了就不看声明式子项，index.tsx:83-89）
//     Timeline {
//         mode: "alternate"
//         dataSource: [
//             { time: "2019-07-14 10:35", content: "第一个节点内容", extra: "节点辅助说明信息", type: "ongoing" }
//         ]
//     }
//
// 度量（packages/semi-foundation/timeline/variables.scss，逐条对过 DOM 实测）：
//   ul = $spacing-timeline-padding: $spacing-tight 8 的一圈内边距，$spacing-timeline-margin 0；
//   条目 = TimelineItem，一条的高度自己算（正文块 + $spacing-loose 24）；
//   mode 默认 "left"（index.tsx:35-37）。
//   轴线和正文的横向关系写在 TimelineItem 顶部注释里，两处都在。
//
// 条目落在哪一侧、谁是最后一条，由 Timeline 用 syncRoles() 推给每个条目
// （timelineIndex / timelineCount / timelineMode），因为官方也是父项 cloneElement 加类名
// （index.tsx:62-73），条目自己并不知道自己在第几个。
//
// 不移植的官方属性：className / style / aria-*（DOM 与 React 专有，同 TimePicker 的口径）。
// mode="center" 下给条目写 position="right" 时官方会把时间整个推出左边界（实测 x=-280），
// 这一处只在出界时夹回 0，其余一律照官方渲染结果（细节见 TimelineItem 头注释）。
Item {
    id: control

    property string mode: "left"           // left | right | center | alternate
    property var dataSource: undefined     // 每项 = TimelineItem 的属性 + content

    default property alias content: staging.data

    readonly property bool usesDataSource: control.dataSource !== undefined
        && control.dataSource !== null
        && control.dataSource.length > 0

    implicitWidth: 320                      // 官方 ul 是 width:100%，QML 里由调用方给宽
    implicitHeight: 16 + (control.usesDataSource ? dataBody.height : declaredBody.height)

    // 官方给了 dataSource 就完全不看 children，所以两条路各有各的容器，
    // 谁生效一目了然（同 CheckboxGroup 的做法）。

    Component.onCompleted: control.refreshItems()
    onModeChanged: control.syncRoles()
    onDataSourceChanged: control.refreshItems()

    Connections {
        target: declaredBody

        function onChildrenChanged() {
            control.syncRoles();
        }
    }

    Connections {
        target: dataBody

        function onChildrenChanged() {
            control.syncRoles();
        }
    }

    // 把暂存容器里的声明式子项整批搬进列容器：宿主（Repeater 那类）也一起搬，所以它后来
    // 长出来的条目直接落在列容器里，由列容器自己的 childrenChanged 接手 —— 暂存容器这边
    // 不需要再挂触发器（挂着也没人踩，变异打过一枪确认）。只搬条目不搬宿主的话，新条目要往
    // 「已经不在这儿的大哥」前面插，Qt 每次长条目都打一条
    // 「Cannot stack TimelineItem before QQuickRepeater, which must be a sibling」。
    function refreshItems() {
        if (!control.usesDataNow()) {
            const kids = staging.children;
            const pending = [];
            for (let i = 0; i < kids.length; ++i)
                pending.push(kids[i]);
            for (let i = 0; i < pending.length; ++i)
                pending[i].parent = declaredBody;
        }
        control.syncRoles();
    }

    // 只看 dataSource 本身，不看 usesDataSource：在 onDataSourceChanged 这一趟里，
    // 那个派生绑定还没重算，读回来仍是上一步的值（同一周期里的老问题，坑 74 / 坑 93 那条），
    // 于是「收回数据源要把留在暂存容器的子项补搬进来」这一档会整个不动。
    function usesDataNow() {
        const d = control.dataSource;
        return d !== undefined && d !== null && d.length > 0;
    }

    // 父项把角色推下去：第几条、一共几条、当前 mode
    //
    // 顺序按 y 排，不按 children 名单排：Repeater 往兄弟之间插条目时走的是 stackBefore，
    // 排版顺序跟着变，QObject 名单却一律排在末尾（QML 摸不到 childItems，那个 accessor
    // 连 Q_PROPERTY 都不是）。名单和位置一旦错开，alternate 的左右、最后一条的收尾就全错。
    // 排版是 childrenChanged 之后的下一趟，所以条目自己的 yChanged 再兜一次。
    function syncRoles() {
        const body = control.usesDataNow() ? dataBody : declaredBody;
        const kids = body.children;
        const items = [];
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i] && kids[i].objectName === "timelineItem")
                items.push(kids[i]);
        }
        items.sort(function (a, b) { return a.y - b.y; });
        for (let i = 0; i < items.length; ++i) {
            const it = items[i];
            control.watchPosition(it);
            it.timelineIndex = i;
            it.timelineCount = items.length;
            it.timelineMode = control.mode;
        }
    }

    // 每条只挂一次：排版一挪动就重新对一次序号
    property var _watched: []

    function watchPosition(it) {
        for (let i = 0; i < control._watched.length; ++i) {
            if (control._watched[i] === it)
                return;
        }
        control._watched.push(it);
        it.yChanged.connect(function () { resyncTimer.restart(); });
    }

    // 声明式子项的暂存容器：搬进 declaredBody 之前待在这儿
    Item {
        id: staging

        visible: false
        width: 0
        height: 0
    }

    // 排版那一趟过去之后再来一次，把序号对齐到真正的上下顺序
    Timer {
        id: resyncTimer

        interval: 0
        onTriggered: control.syncRoles()
    }

    Column {
        id: declaredBody

        objectName: "timelineDeclaredBody"
        visible: !control.usesDataSource
        x: 8                               // $spacing-timeline-padding
        y: 8
        width: Math.max(0, control.width - 16)
    }

    Column {
        id: dataBody

        objectName: "timelineDataBody"
        visible: control.usesDataSource
        x: 8
        y: 8
        width: Math.max(0, control.width - 16)

        Repeater {
            objectName: "timelineDataRepeater"
            model: control.usesDataSource ? control.dataSource : []

            delegate: TimelineItem {
                id: entry

                required property var modelData

                // dataSource 的每一项就是 TimelineItemProps + content（index.tsx:12-14、84-85），
                // 缺的一律回到官方 Item 的 defaultProps：type "default"、time ""。
                type: entry.modelData && entry.modelData.type !== undefined
                    ? String(entry.modelData.type) : "default"
                color: entry.modelData && entry.modelData.color !== undefined
                    ? String(entry.modelData.color) : ""
                position: entry.modelData && entry.modelData.position !== undefined
                    ? String(entry.modelData.position) : ""
                content: entry.modelData ? entry.modelData.content : ""
                time: entry.modelData && entry.modelData.time !== undefined
                    ? entry.modelData.time : ""
                extra: entry.modelData && entry.modelData.extra !== undefined
                    ? entry.modelData.extra : ""
                dot: entry.modelData && entry.modelData.dot !== undefined
                    ? entry.modelData.dot : null

                onClicked: {
                    if (entry.modelData && entry.modelData.onClick)
                        entry.modelData.onClick();
                }
            }
        }
    }
}
