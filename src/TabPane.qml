pragma ComponentBehavior: Bound

import QtQuick

// 标签页的内容面板。对应 `packages/semi-ui/tabs/TabPane.tsx`（props 见 interface.ts:81-91、
// shouldRender :50-56、getDirection :32-47、render :58-117）。
//
//     Tabs {
//         activeKey: "a"
//         TabPane { itemKey: "a"; tab: "标签一"; Text { text: "内容一" } }
//     }
//
// ---------------------------------------------------------------- 与官方的口径差异（逐条）
//   · `className` / `style` 是 DOM 通道，不收。
//   · 官方两层节点（`-pane` 外壳 + `-pane-motion-overlay` 内壳）端口合成一层：内壳那个类名
//     在 semi.css 里 **0 条规则**（死类名，CSS:22325 起只挂动画，动画本身挂在被检出的那层）。
//   · 官方 `-pane-inactive { display: none }`（CSS:22322-22324）与 `keepDOM: false` 走的是
//     两条不同的路：前者是「不显示」，后者是「根本不渲染」。QML 里内联子项**没法推迟创建**
//     ⇒ 端口把 `keepDOM: false` 与 `lazyRender` 都落成「内容层 visible/enabled 关掉」，
//     差异只在 `Component.onCompleted` 会不会提前跑一次，这条差异在下面那节 Note 里也写了。
//   · `tabIndex` 官方是 `tabIndex ? tabIndex : 0` ⇒ 显式给 0 与没给同值，要给负数才真的退出 Tab 序。
Item {
    id: control

    // ================================================================ 官方属性面
    property var tab: ""                        // ReactNode ⇒ 字符串或 Component
    property var icon: ""                       // ReactNode ⇒ 图标名或 Component
    property string itemKey: ""
    property bool disabled: false
    property bool closable: false
    property int tabIndex: 0

    // ================================================================ 宿主注入
    property var host: null
    readonly property bool isTabPane: true
    property bool fromRepeater: false
    property bool hostActive: false
    property bool hostFromEnd: false            // TabPane.getDirection :32-47 的结果
    property bool hostMotion: false             // 宿主按 tabPaneMotion + 是否刚激活算好
    property bool hostVertical: false           // 宿主的 tabPosition === "left"，决定位移走哪个轴

    implicitWidth: contentColumn.width
    implicitHeight: contentColumn.implicitHeight
    // 官方 `.semi-tabs-pane-inactive { display: none }`（CSS:22322-22324）：不激活就整块不占位。
    // 少了这一道，keepDOM 的默认档（true）会让所有面板**叠着一起画**。
    visible: control.hostActive

    // 官方入场：200ms ease-in-out、±60px 位移 + 透明度 0→1、forwards，只在激活那一次
    //（横排走 leftShow / rightShow 的 translateX，竖排换成 topShow / bottomShow 的 translateY）
    SequentialAnimation {
        id: enterMotion

        property real fromX: control.hostVertical ? 0 : (control.hostFromEnd ? 60 : -60)
        property real fromY: control.hostVertical ? (control.hostFromEnd ? 60 : -60) : 0

        ParallelAnimation {
            NumberAnimation {
                target: contentColumn
                property: "x"
                from: enterMotion.fromX
                to: 0
                duration: 200
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: contentColumn
                property: "opacity"
                from: 0
                to: 1
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }
    }

    /// 测试口子：入场那一帧的起点（轴向与正负就是官方 leftShow/rightShow 与 topShow/bottomShow 的差）
    readonly property real motionFromX: enterMotion.fromX
    readonly property real motionFromY: enterMotion.fromY

    onHostMotionChanged: {
        if (!control.hostMotion)
            return;
        contentColumn.x = enterMotion.fromX;
        contentColumn.opacity = 0;
        enterMotion.start();
    }

    Accessible.role: Accessible.Pane
    Accessible.name: control.textOf(control.tab)
    Accessible.ignored: !control.hostActive

    // 官方 `.semi-tabs-pane { width:100%; overflow:hidden; color:text-0 }`（CSS:22314-22318）
    // ⇒ 内容层整幅、裁掉溢出。块级流用 Column 表达（QML 裸 Item 会把子项全叠在 0）。
    Column {
        id: contentColumn

        objectName: "tabPaneContent"

        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width
        spacing: 0
    }

    /// 内联子项进内容层（**不能**用 `default property list<Item>`：那会把子项从可视树上摘走，
    /// `item.window` 变 null、渲染与事件全丢 —— 见坑 116 同族）
    default property alias paneContent: contentColumn.data

    function textOf(v) {
        if (v === undefined || v === null)
            return "";
        if (typeof v === "object")
            return "";
        return String(v);
    }
}
