pragma ComponentBehavior: Bound

import QtQuick
import Semi

// BackTop 回到顶部。小节顺序与标题逐条对齐 content/navigation/backtop/index.md 的那
// 2 条 demo（加「如何引入」共 3 节，页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/BackTop.qml 文件头）：
//   · 官方 `target` 是函数（`() => HTMLElement | window`），端口直接收滚动容器；
//     **window 档没有对应物** ⇒ 整页滚动也要给一只 Flickable；
//   · 官方 `children` 换的是整颗按钮，端口那档叫 `content`（收 Component）；
//   · 官方「自定义样式」那节把尺寸/底色/圆角/`bottom` 全塞进 `style`，QML 没有内联样式 ⇒
//     底色与圆角画在 `content` 那个节点里，位置走端口替身 `bottomMargin`；
//   · 官方 `position: fixed` 相对视口，端口是普通 Item ⇒ 按父项右下角摆，
//     所以这里给每节造一只铺满 demo 区的容器。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方自定义那节的 style 档：30×30 圆、#0077fa 底、白字，配 <IconArrowUp />
    readonly property Component blueRoundButton: Component {
        Rectangle {
            width: 30
            height: 30
            radius: 100
            color: "#0077fa"

            Icon {
                anchors.centerIn: parent
                name: "arrow_up"
                size: Theme.current.widthIconMedium
                color: "#ffffff"
            }
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        // ================================================================ 如何引入
        GallerySection {
            title: "如何引入"

            Column {
                width: 760
                spacing: 10

                Text {
                    text: "import { BackTop } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }
        }

        // ================================================================ 基本用法
        GallerySection {
            title: "基本用法"

            // 官方那句提示写在组件外面（<span> 在 <BackTop /> 之前），端口同位摆
            Text {
                text: qsTr("把下面这块滚过 400px，右下角就浮出预设那颗按钮")
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeRegular
            }

            Item {
                width: 560
                height: 260

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.current.colorBg2
                    border.width: 1
                    border.color: Theme.current.colorBorder
                }

                Flickable {
                    id: basicView

                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    contentHeight: 1400
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        width: basicView.width
                        spacing: 8

                        Repeater {
                            model: 40

                            delegate: Text {
                                required property int index

                                x: 16
                                text: qsTr("第 %1 行内容").arg(index + 1)
                                color: Theme.current.colorText2
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }
                    }

                    Component.onCompleted: contentY = 700
                }

                // 官方缺省：右 100 / 底 50、阈值 400、那颗是 light 档 chevron_up
                BackTop {
                    target: basicView
                }

            }
        }

        // ================================================================ 自定义样式
        GallerySection {
            title: "自定义样式"

            Text {
                text: qsTr("同一块容器，把 children 换成 30×30 蓝底白箭头那颗，"
                    + "并把距底从 50 改成 100（官方那节是 style 里写 bottom: 100）")
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeRegular
                width: 700
                wrapMode: Text.WordWrap
            }

            Item {
                width: 560
                height: 260

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.current.colorBg2
                    border.width: 1
                    border.color: Theme.current.colorBorder
                }

                Flickable {
                    id: customView

                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    contentHeight: 1400
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        width: customView.width
                        spacing: 8

                        Repeater {
                            model: 40

                            delegate: Text {
                                required property int index

                                x: 16
                                text: qsTr("内容 %1").arg(index + 1)
                                color: Theme.current.colorText2
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }
                    }

                    Component.onCompleted: contentY = 700
                }

                BackTop {
                    target: customView
                    // 官方 style 里那条 bottom: 100
                    bottomMargin: 100
                    content: page.blueRoundButton
                }

            }
        }
    }
}
