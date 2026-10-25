pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/feedback/spin/index.md 的 6 个演示小节，标题逐字取自 data/docs.json。
//
// 官方示例里的 style={{ marginLeft: 30 }} / marginBottom: 10 这类演示用的外边距，
// 对应成 Column / Row 的 spacing；「尺寸」那节三组之间的 marginBottom 是 5 / 10 / 15
// 各不相同（纯演示排版），这里统一成一组间距。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property bool busy: false             // 延迟显示那节的开关

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 460
                text: "import Semi\n\nSpin { }\n\nSpin { size: \"large\"; tip: \"I am loading...\" }"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                spacing: 10

                Text {
                    text: "A basic spin."
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Spin {}
            }
        }

        GallerySection {
            title: "尺寸"

            Column {
                spacing: 20

                Column {
                    spacing: 5

                    Text {
                        text: "size: small"
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Spin { size: "small" }
                }

                Column {
                    spacing: 10

                    Text {
                        text: "size: middle"
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Spin { size: "middle" }
                }

                Column {
                    spacing: 15

                    Text {
                        text: "size: large"
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Spin { size: "large" }
                }
            }
        }

        GallerySection {
            title: "带文字的"

            // 官方：<Spin tip="I am loading..."> 包一个带主色边框的方块，
            // 里面两段 <p>。包裹时内容压暗 0.5、指示符 + tip 整块浮在正中。
            Spin {
                tip: "I am loading..."

                Rectangle {
                    width: 320
                    height: 88
                    radius: 4                             // borderRadius: 4px
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.current.colorPrimary   // 1px solid var(--semi-color-primary)

                    Column {
                        x: 8                              // paddingLeft: 8px
                        y: 16                             // <p> 的默认上下边距
                        spacing: 16                       // 相邻 <p> 之间 16px

                        Text {
                            text: "Here are some texts."
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                            lineHeight: 20
                            lineHeightMode: Text.FixedHeight
                        }

                        Text {
                            text: "And more texts on the way."
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                            lineHeight: 20
                            lineHeightMode: Text.FixedHeight
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "自定义指示符"

            Column {
                spacing: 0

                Text {
                    text: "A spin with customized indicator."
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                // 官方 indicator={<IconLoading />}：给了 indicator 就走 -animate 那一档，
                // 一圈 1600ms（默认那只弧是 600ms），尺寸跟着指示符自己（图标默认 16px）
                Spin {
                    indicator: Component {
                        Icon { name: "loading" }
                    }
                }
            }
        }

        GallerySection {
            title: "延迟显示"

            Row {
                spacing: 20

                Button {
                    text: "延迟显示的spin"
                    onClicked: page.busy = !page.busy
                }

                Spin {
                    delay: 1000
                    spinning: page.busy
                }
            }
        }
    }
}
