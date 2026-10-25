pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property var demoIcons: [
        "home", "search", "plus", "delete", "edit", "folder",
        "list", "clock", "image", "close", "arrow_up", "arrow_down",
        "checkbox_tick", "rotate", "apps", "eye_opened"
    ]

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基础使用"

            Flow {
                width: 640
                spacing: 20

                Repeater {
                    model: page.demoIcons

                    delegate: Icon {
                        id: iconCell

                        required property var modelData

                        width: 28
                        height: 28
                        name: iconCell.modelData
                        size: 22
                        color: Theme.current.colorText1
                    }
                }
            }
        }

        GallerySection {
            title: "尺寸"

            Row {
                spacing: 24

                Icon { name: "home"; size: 12; color: Theme.current.colorText1 }
                Icon { name: "home"; size: 16; color: Theme.current.colorText1 }
                Icon { name: "home"; size: 20; color: Theme.current.colorText1 }
                Icon { name: "home"; size: 28; color: Theme.current.colorText1 }
                Icon { name: "home"; size: 36; color: Theme.current.colorText1 }
            }
        }

        GallerySection {
            title: "颜色"

            Row {
                spacing: 24

                Icon { name: "checkbox_tick"; size: 24; color: Theme.current.colorPrimary }
                Icon { name: "checkbox_tick"; size: 24; color: Theme.current.colorSuccess }
                Icon { name: "checkbox_tick"; size: 24; color: Theme.current.colorWarning }
                Icon { name: "checkbox_tick"; size: 24; color: Theme.current.colorDanger }
                Icon { name: "checkbox_tick"; size: 24; color: Theme.current.colorText2 }
            }
        }

        GallerySection {
            title: "旋转"

            Row {
                spacing: 24

                Icon { name: "arrow_up"; size: 24; color: Theme.current.colorText1 }
                Icon { name: "arrow_up"; size: 24; color: Theme.current.colorText1; rotation: 90 }
                Icon { name: "arrow_up"; size: 24; color: Theme.current.colorText1; rotation: 180 }
                Icon { name: "arrow_up"; size: 24; color: Theme.current.colorText1; rotation: 270 }
            }
        }
    }
}
