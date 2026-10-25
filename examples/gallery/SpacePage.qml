pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Space 间距。小节顺序与标题逐条对齐 content/basic/space/index.md 的那 5 条 demo
// （加「如何引入」共 6 节，页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/Space.qml 文件头）：
//   · 排布是两趟手工排布（Row/Column 不换行不认 align，Flow 单 spacing 撑不住两档）；
//   · 换行以 width 为可用宽 —— 两个 wrap demo 都按官方语义把宽钉给容器
//     （`width: parent.width`，官方 inline-flex 吃的就是所在栏的可用宽）；
//   · baseline 档按「后代第一个 Text 的基线」摆位，Qt 侧没有可靠信号 ⇒ 只在
//     baseline 档每帧幂等重排（FrameAnimation）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

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
                    text: "import { Space } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }
        }

        // ================================================================ 基本用法
        GallerySection {
            title: "基本用法"

            Space {
                Switch { checked: true }
                Button { text: qsTr("次要"); tone: Enums.Secondary }
                Button { text: qsTr("第三"); tone: Enums.Tertiary }
                Button { text: qsTr("警告"); tone: Enums.Warning }
            }
        }

        // ================================================================ 对齐方式
        GallerySection {
            title: "对齐方式"

            // 官方：外层 vertical Space，内层四个 align 档各一行（start/center/end/
            // baseline），行内是 100 高的描边文本盒 + solid 按钮 + large 绿标签 ——
            // 三种高度差让四档肉眼可分
            Space {
                vertical: true

                Space {
                    align: "start"

                    DemoBox {}
                    Button { text: qsTr("按钮"); variant: Enums.Solid }
                    Tag { text: qsTr("标签"); color: "green"; size: "large" }
                }

                Space {
                    align: "center"

                    DemoBox {}
                    Button { text: qsTr("按钮"); variant: Enums.Solid }
                    Tag { text: qsTr("标签"); color: "green"; size: "large" }
                }

                Space {
                    align: "end"

                    DemoBox {}
                    Button { text: qsTr("按钮"); variant: Enums.Solid }
                    Tag { text: qsTr("标签"); color: "green"; size: "large" }
                }

                Space {
                    align: "baseline"

                    DemoBox {}
                    Button { text: qsTr("按钮"); variant: Enums.Solid }
                    Tag { text: qsTr("标签"); color: "green"; size: "large" }
                }
            }
        }

        // ================================================================ 间距尺寸
        GallerySection {
            title: "间距尺寸"

            // 官方演示栏宽 = 主栏 800（site variable.scss 的 $max-paragraph-width）×
            // 预览 40%（semi-site-playground 内联 width:calc(40%)，编辑器占 60%）−
            // 预览 20px 内边距 ≈ 279；端口取 280 —— tab 栏刚好放得下四格（官方同款
            // 267px），array 档的换行行分布（4+4+2）与官方同形
            Tabs {
                width: 280
                type: "line"

                TabPane {
                    itemKey: "1"
                    tab: "tight"

                    Space {
                        spacing: "tight"

                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                    }
                }
                TabPane {
                    itemKey: "2"
                    tab: "medium"

                    Space {
                        spacing: "medium"

                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                    }
                }
                TabPane {
                    itemKey: "3"
                    tab: "loose"

                    Space {
                        spacing: "loose"

                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                        Button { text: qsTr("按钮"); variant: Enums.Solid }
                    }
                }
                // 官方 array 档：[8, 16] 两轴间距 + wrap —— 挂在 TabPane 的整幅宽下换行
                TabPane {
                    itemKey: "4"
                    tab: "array"

                    Space {
                        width: parent !== null ? parent.width : implicitWidth
                        spacing: [8, 16]
                        wrap: true

                        Repeater {
                            model: 10

                            delegate: Button {
                                text: qsTr("按钮")
                                variant: Enums.Solid
                            }
                        }
                    }
                }
            }
        }

        // ================================================================ 间距方向
        GallerySection {
            title: "间距方向"

            Space {
                vertical: true

                Button { text: qsTr("按钮"); variant: Enums.Solid }
                Button { text: qsTr("按钮"); variant: Enums.Solid }
                Button { text: qsTr("按钮"); variant: Enums.Solid }
                Button { text: qsTr("按钮"); variant: Enums.Solid }
            }
        }

        // ================================================================ 设置换行
        GallerySection {
            title: "设置换行"

            // 官方 demo：wrap + 十枚 solid secondary。可用宽同上 = 官方预览栏 ≈ 279
            // （主栏 800 × 40% 预览 − 20×2 内边距）⇒ 十枚 52 宽的按钮排 4+4+2，
            // 行分布与官方文档逐行同形
            Space {
                width: 280
                wrap: true

                Repeater {
                    model: 10

                    delegate: Button {
                        text: qsTr("按钮")
                        variant: Enums.Solid
                        tone: Enums.Secondary
                    }
                }
            }
        }
    }

    /// 官方对齐档里那个 80×100 的描边文本盒（divStyle：width 80 / height 100 /
    /// 1px color-border 描边 / 3px 圆角 / 文本居中），四行各来一份同款数据
    component DemoBox: Rectangle {
        width: 80
        height: 100
        radius: 3
        color: "transparent"
        border.width: 1
        border.color: Theme.current.colorBorder

        Text {
            anchors.centerIn: parent
            text: qsTr("文本")
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }
}
