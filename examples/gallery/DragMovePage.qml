pragma ComponentBehavior: Bound

import QtQuick
import Semi

// DragMove 拖拽移动。把内容包进去，按住就能挪位置，默认还会约束在父容器内。
// 本库没有官网那套 handler / constrainer / customMove 回调，
// 但对外发 moveStarted / moved / moveFinished，并且给了 moveTo(x, y)。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property string lastEvent: ""

    component Note: Text {
        width: 560
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    component Stage: Rectangle {
        radius: Theme.current.radiusMedium
        color: Theme.current.colorFill0
        border.width: 1
        border.color: Theme.current.colorBorder
    }

    component Block: Rectangle {
        width: 168
        height: 68
        radius: Theme.current.radiusMedium
        color: Theme.current.colorPrimary

        Text {
            anchors.centerIn: parent
            text: qsTr("按住我拖")
            color: Theme.current.colorBg0
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Item {
                width: 480
                height: 176

                Stage { anchors.fill: parent }

                DragMove {
                    x: 24
                    y: 24

                    Block {}
                }
            }

            Note {
                text: qsTr("被 DragMove 包住的内容就能拖。本库把内容包在内部容器里、"
                    + "拖动由 DragHandler 驱动，所以不存在官网说的「事件和 ref 要透传到底层元素」那一步，"
                    + "里面放什么 QML 都能拖。")
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 560
                spacing: 12

                Item {
                    width: 480
                    height: 176

                    Stage { anchors.fill: parent }

                    DragMove {
                        id: trackedMover

                        x: 24
                        y: 24

                        Block {}

                        onMoveStarted: page.lastEvent = qsTr("开始拖")
                        onMoveFinished: page.lastEvent = qsTr("拖完了，落点 (%1, %2)")
                            .arg(Math.round(trackedMover.x)).arg(Math.round(trackedMover.y))
                    }
                }

                Text {
                    text: qsTr("最近一次：%1").arg(
                        page.lastEvent === "" ? qsTr("（还没拖过）") : page.lastEvent)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }

            Note {
                text: qsTr("isMoving 在拖动过程中为 true，可以用来改样式（官网的悬浮阴影就是这么做）；"
                    + "三个信号分别是开始拖、每动一下、松手。")
            }
        }

        GallerySection {
            title: "限制拖动范围"

            Column {
                width: 620
                spacing: 12

                Row {
                    spacing: 24

                    Column {
                        spacing: 8

                        Text {
                            text: qsTr("constrainToParent: true（默认）")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        Item {
                            width: 280
                            height: 150

                            Stage { anchors.fill: parent }

                            DragMove {
                                x: 16
                                y: 16

                                Block {}
                            }
                        }
                    }

                    Column {
                        spacing: 8

                        Text {
                            text: qsTr("constrainToParent: false")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        Item {
                            width: 280
                            height: 150

                            Stage { anchors.fill: parent }

                            DragMove {
                                x: 16
                                y: 16
                                constrainToParent: false

                                Block {}
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("右边的拖动超出虚线框也不会被拦住（框只是背景，没有裁剪），"
                        + "松手前它还能拖回来 —— 因为坐标是跟着手指算的，不会跑丢。")
                }
            }
        }

        GallerySection {
            title: "自定义拖动后的位置处理"

            Column {
                width: 560
                spacing: 12

                Item {
                    width: 480
                    height: 176

                    Stage { anchors.fill: parent }

                    DragMove {
                        id: resetMover

                        x: 24
                        y: 24
                        movable: !resetSwitch.checked

                        Block {
                            color: resetSwitch.checked
                                ? Theme.current.colorText3
                                : Theme.current.colorPrimary
                        }

                        onMoveFinished: page.lastEvent = qsTr("松手，落在 (%1, %2)")
                            .arg(Math.round(resetMover.x)).arg(Math.round(resetMover.y))
                    }
                }

                Row {
                    spacing: 8

                    Switch {
                        id: resetSwitch
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("先锁住拖动")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("用 moveTo 复位")
                        variant: Enums.Light
                        onClicked: resetMover.moveTo(24, 24)
                    }
                }
            }

            Note {
                text: qsTr("官网用 customMove 接管落点、用 handler 指定只有某个把手能拖、"
                    + "用 constrainer 换约束元素 —— 这三个回调本库都没有。"
                    + "可用的替代是：movable 控制能不能拖，moveTo(x, y) 主动设位置"
                    + "（它会按约束夹一次并发出 moved 信号），想接住落点就读 x / y。")
            }
        }
    }
}
