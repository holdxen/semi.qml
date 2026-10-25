pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Divider 分割线。小节顺序与标题逐条对齐 content/basic/divider/index.md 的那 2 条 demo
// （加「如何引入」共 3 节，页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/Divider.qml 文件头）：
//   · 官方 `layout: 'horizontal' | 'vertical'` 端口写作 `vertical: bool`；
//   · 官方 `children` 一个 ReactNode 槽收字符串或节点，端口拆成 `text`（字符串档，
//     吃 `-inner-text` 的 8px 内边距 + 字重 600）与 `content`（Component 档，裸渲染）；
//   · `margin` 烘进 implicit 尺寸（QML 无外边距）：水平吃上下、垂直吃左右，缺省 1px；
//   · **children 只在水平档渲染**（官方 index.tsx:63），垂直 + 内容 = 内容丢弃只画线。
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
                    text: "import { Divider } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }
        }

        // ================================================================ 基本用法
        GallerySection {
            title: "基本用法"

            Column {
                spacing: 20
                width: 480

                Text {
                    text: "水平实线"
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "Semi Design 是一个设计系统。"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }
                Divider { width: 480; margin: 12 }
                Text {
                    text: "它定义了一套中后台设计与前端基础组件。"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "水平虚线"
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "Semi Design 是一个设计系统。"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }
                Divider { width: 480; dashed: true; margin: 12 }
                Text {
                    text: "它定义了一套中后台设计与前端基础组件。"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Text {
                    text: "垂直实线"
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                }
                Row {
                    spacing: 0
                    height: 24

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "左"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                    Divider { vertical: true; margin: 12; height: 24 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "中"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                    Divider { vertical: true; margin: 12; height: 24 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "右"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                Text {
                    text: "垂直虚线"
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                }
                Row {
                    spacing: 0
                    height: 24

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "左"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                    Divider { vertical: true; dashed: true; margin: 12; height: 24 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "中"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                    Divider { vertical: true; dashed: true; margin: 12; height: 24 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "右"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }
        }

        // ================================================================ 包含内容
        GallerySection {
            title: "包含内容"

            Column {
                spacing: 24
                width: 480

                Divider { width: 480; align: "left"; margin: 12; text: "这是居左文字" }
                Divider { width: 480; align: "center"; margin: 12; text: "这是居中文字" }
                Divider { width: 480; align: "right"; margin: 12; text: "这是居右文字" }
                // 官方 demo 的 children 是 <IconSemiLogo />—— 节点档裸渲染，
                // 端口用 Component 槽承接
                Divider { width: 480; margin: 12; content: semiLogoComp }
            }
        }
    }

    /// 官方 demo 里的 <IconSemiLogo />：端口给一个 36×36 的 Component
    Component {
        id: semiLogoComp

        Icon {
            name: "semi_logo"
            size: 36
        }
    }
}
