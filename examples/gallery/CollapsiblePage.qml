pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本用法"

            Column {
                spacing: 12

                Collapsible {
                    id: basic

                    width: 520

                    Card {
                        width: 520

                        Text {
                            width: parent.width
                            text: qsTr("这块内容可以被折叠。和 Collapse 的区别是：Collapsible 只管"
                                + "「一块内容展开收起」，没有面板标题那一套。")
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                            lineHeight: 24
                            lineHeightMode: Text.FixedHeight
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Button {
                    text: basic.isOpen ? qsTr("收起") : qsTr("展开")
                    onClicked: basic.toggle()
                }
            }
        }

        GallerySection {
            title: "自定义折叠高度"

            Column {
                spacing: 12

                Text {
                    width: 520
                    text: qsTr("下面这个 collapseHeight 设为 60，收起时仍露出开头一部分：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }

                Collapsible {
                    width: 520
                    collapseHeight: 60

                    Card {
                        width: 520

                        Text {
                            width: parent.width
                            text: qsTr("第一段：这段在收起时也能看到一部分。\n\n"
                                + "第二段：这段会被折起来。\n\n"
                                + "第三段：这段也会被折起来。")
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                            lineHeight: 24
                            lineHeightMode: Text.FixedHeight
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "自定义动画时间"

            Column {
                spacing: 12

                Text {
                    width: 520
                    text: qsTr("duration 控制展开收起用多久，下面这个是 600ms，比默认慢三倍：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }

                Collapsible {
                    id: slowOne

                    width: 520
                    duration: 600

                    Card {
                        width: 520

                        Text {
                            width: parent.width
                            text: qsTr("慢慢展开的内容。")
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }
                    }
                }

                Button {
                    text: slowOne.isOpen ? qsTr("收起") : qsTr("展开")
                    onClicked: slowOne.toggle()
                }
            }
        }

        GallerySection {
            title: "嵌套使用"

            Column {
                spacing: 12

                Collapsible {
                    id: outer

                    width: 520

                    Card {
                        width: 520

                        Column {
                            width: parent.width
                            spacing: 12

                            Text {
                                width: parent.width
                                text: qsTr("外层内容。")
                                color: Theme.current.colorText1
                                font.pixelSize: Theme.current.fontSizeRegular
                            }

                            Collapsible {
                                id: inner

                                width: parent.width

                                Card {
                                    width: parent.width
                                    bordered: false

                                    Text {
                                        width: parent.width
                                        text: qsTr("内层内容，可以自己独立折叠。")
                                        color: Theme.current.colorText1
                                        font.pixelSize: Theme.current.fontSizeRegular
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Button {
                                text: inner.isOpen ? qsTr("收起内层") : qsTr("展开内层")
                                variant: Enums.Light
                                size: Enums.Small
                                onClicked: inner.toggle()
                            }
                        }
                    }
                }

                Button {
                    text: outer.isOpen ? qsTr("收起外层") : qsTr("展开外层")
                    onClicked: outer.toggle()
                }
            }
        }
    }
}
