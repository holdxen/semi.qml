pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/input/rating/index.md 的 7 个演示小节。
// 官方 jsx 里 <br/> 一档、<br/><br/> 两档，这里分别排 8 / 12。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方「文案展现」一节用 useState(0) 受控
    property real demoValue: 0
    readonly property var demoDesc: ["terrible", "bad", "normal", "good", "wonderful"]

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 420
                text: "import Semi\n\nRating { }"
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
                spacing: 12

                Rating { defaultValue: 5 }

                Rating { size: "small"; defaultValue: 5 }
            }
        }

        GallerySection {
            title: "半星"

            Column {
                spacing: 8

                Rating { allowHalf: true; defaultValue: 3.5 }

                Rating { allowHalf: true; defaultValue: 3.65; disabled: true }
            }
        }

        GallerySection {
            title: "只读"

            Rating { disabled: true; defaultValue: 3 }
        }

        GallerySection {
            title: "点击清除"

            Column {
                spacing: 12

                Column {
                    spacing: 8

                    Text {
                        text: qsTr("允许再次点击清除")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Rating { allowClear: true; defaultValue: 3 }
                }

                Column {
                    spacing: 8

                    Text {
                        text: qsTr("禁止再次点击清除")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Rating { allowClear: false; defaultValue: 3 }
                }
            }
        }

        GallerySection {
            title: "文案展现"

            Column {
                spacing: 8

                Text {
                    text: qsTr("How was the help you received: ")
                        + (page.demoValue ? page.demoDesc[page.demoValue - 1] : "")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Rating {
                    tooltips: page.demoDesc
                    value: page.demoValue
                    onChanged: (v) => page.demoValue = v
                }
            }
        }

        GallerySection {
            title: "自定义"

            Column {
                spacing: 12

                Rating {
                    color: "red"
                    character: Component {
                        Icon { name: "like_heart"; size: 24 }
                    }
                    defaultValue: 3
                }

                Rating {
                    color: "red"
                    size: 48
                    allowHalf: true
                    character: Component {
                        Icon { name: "like_heart"; size: 48 }
                    }
                    defaultValue: 3
                }

                Rating { character: "赞"; size: 18; defaultValue: 3 }

                Rating { count: 10; defaultValue: 6 }
            }
        }
    }
}
