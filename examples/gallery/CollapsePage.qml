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

            Collapse {
                width: 560

                CollapsePanel {
                    title: qsTr("面板一")
                    expanded: true

                    Text {
                        width: parent.width
                        text: qsTr("第一个面板的内容，默认展开。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                CollapsePanel {
                    title: qsTr("面板二")

                    Text {
                        width: parent.width
                        text: qsTr("第二个面板，点标题展开。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                CollapsePanel {
                    title: qsTr("面板三")

                    Text {
                        width: parent.width
                        text: qsTr("第三个面板，可以多个同时展开。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }
        }

        GallerySection {
            title: "手风琴效果"

            Collapse {
                width: 560
                accordion: true

                CollapsePanel {
                    title: qsTr("第一个")
                    expanded: true

                    Text {
                        width: parent.width
                        text: qsTr("同时只展开一个，点开别的会自动收起当前这个。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                CollapsePanel {
                    title: qsTr("第二个")

                    Text {
                        width: parent.width
                        text: qsTr("第二个的内容。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                CollapsePanel {
                    title: qsTr("第三个")

                    Text {
                        width: parent.width
                        text: qsTr("第三个的内容。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }
        }

        GallerySection {
            title: "禁用面板"

            Collapse {
                width: 560

                CollapsePanel {
                    title: qsTr("可以展开")
                    expanded: true

                    Text {
                        width: parent.width
                        text: qsTr("这个面板正常。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                CollapsePanel {
                    title: qsTr("禁用面板")
                    disabled: true

                    Text {
                        width: parent.width
                        text: qsTr("看不到这段内容，因为面板点不开。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }
        }
    }
}
