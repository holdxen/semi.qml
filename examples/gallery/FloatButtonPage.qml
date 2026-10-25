pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    component Stage: Item {
        property string label: ""

        width: 220
        height: 120

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Theme.current.colorFill0
        }

        Text {
            x: 12
            y: 8
            text: parent.label
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeSmall
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本用法"

            Row {
                spacing: 16

                Stage {
                    label: "图标按钮"

                    FloatButton { icon: "plus" }
                }

                Stage {
                    label: "带文字"

                    FloatButton { icon: "search"; text: "搜索"; circle: false }
                }

                Stage {
                    label: "禁用"

                    FloatButton { icon: "plus"; disabled: true }
                }
            }
        }

        GallerySection {
            title: "尺寸"

            Row {
                spacing: 16

                Stage {
                    label: "小 24"

                    FloatButton { icon: "plus"; size: Enums.Small }
                }

                Stage {
                    label: "默认 32"

                    FloatButton { icon: "plus" }
                }

                Stage {
                    label: "大 40"

                    FloatButton { icon: "arrow_up"; size: Enums.Large }
                }
            }
        }

        GallerySection {
            title: "形状"

            Row {
                spacing: 16

                Stage {
                    label: "圆形"

                    FloatButton { icon: "plus" }
                }

                Stage {
                    label: "方形"

                    FloatButton { icon: "plus"; circle: false }
                }

                Stage {
                    label: "方形带文字"

                    FloatButton { icon: "edit"; text: "编辑"; circle: false }
                }
            }
        }

        GallerySection {
            title: "悬浮按钮组"

            Row {
                spacing: 16

                Stage {
                    label: "横向排列"

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        FloatButton { icon: "search"; rightMargin: 0; bottomMargin: 0; x: 0; y: 0 }
                        FloatButton { icon: "edit"; rightMargin: 0; bottomMargin: 0; x: 0; y: 0 }
                        FloatButton { icon: "delete"; rightMargin: 0; bottomMargin: 0; x: 0; y: 0 }
                    }
                }
            }
        }
    }
}
