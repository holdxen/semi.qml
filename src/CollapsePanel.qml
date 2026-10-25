import QtQuick

// 折叠面板。标题栏可点，内容区带展开动画。
//
//     CollapsePanel { title: "标题"; expanded: true; Text { text: "内容" } }
Item {
    id: control

    default property alias content: body.data

    property string title: ""
    property bool expanded: false
    property bool disabled: false

    // 展开/收起时通知父级（Collapse 的手风琴模式靠它）。
    // 静态检查认不出 parent 是 Collapse，逐行抑制 missing-property。
    function requestExpand() {
        if (control.disabled)
            return;
        control.expanded = !control.expanded;
        const p = control.parent;
        // qmllint disable missing-property
        if (p && control.expanded && typeof p.handleExpanded === "function")
            p.handleExpanded(control);
        // qmllint enable missing-property
    }

    readonly property int headerHeight: 40

    implicitWidth: 320
    implicitHeight: header.height + bodyWrapper.height
    opacity: control.disabled ? 0.6 : 1

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        // 标题栏
        Item {
            id: header

            width: parent.width
            height: control.headerHeight
            activeFocusOnTab: !control.disabled

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.current.colorBorder
            }

            Icon {
                id: caret

                x: 0
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron_right"
                size: 16
                color: Theme.current.colorText2
                rotation: control.expanded ? 90 : 0

                // 官方 collapse.scss 里箭头没有任何 transition —— 保持瞬时切换
                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.current.durationNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                anchors.left: caret.right
                anchors.leftMargin: Theme.current.spacingTight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: control.title
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            HoverHandler {
                id: headerHover
                enabled: !control.disabled
            }

            TapHandler {
                enabled: !control.disabled
                onTapped: control.requestExpand()
            }
        }

        // 内容区
        Item {
            id: bodyWrapper

            width: parent.width
            height: control.expanded ? body.implicitHeight + Theme.current.spacingBaseTight * 2 : 0
            clip: true
            visible: height > 0

            // $transition_duration-collapsible-height = 250ms + cubic-bezier(.25,.1,.25,1)。
            // 不能用 Theme.current.durationNormal —— 默认主题把全局时长令牌设成 0ms，
            // 组件级动效走各自 animation.scss 的硬编码值。
            Behavior on height {
                NumberAnimation {
                    duration: 250
                    // CSS ease：Qt 的 Easing.BezierSpline 实测退化为线性，改用形状最接近的内置曲线
                easing.type: Easing.InOutQuad
                }
            }

            Column {
                id: body

                x: Theme.current.spacingLoose
                y: Theme.current.spacingBaseTight
                width: Math.max(0, parent.width - Theme.current.spacingLoose * 2)
                spacing: Theme.current.spacingBaseTight
            }
        }
    }
}
