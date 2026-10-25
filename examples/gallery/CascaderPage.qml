pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property var regionOptions: [
        {
            label: "浙江", value: "zj", children: [
                { label: "杭州", value: "hz" },
                { label: "宁波", value: "nb" },
                { label: "温州", value: "wz" }
            ]
        },
        {
            label: "江苏", value: "js", children: [
                { label: "南京", value: "nj" },
                { label: "苏州", value: "sz" }
            ]
        },
        {
            label: "广东", value: "gd", children: [
                { label: "广州", value: "gz" },
                { label: "深圳", value: "sz2" }
            ]
        }
    ]

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本用法"

            Column {
                spacing: 12

                Cascader {
                    id: basicCascader

                    width: 280
                    options: page.regionOptions
                    placeholder: qsTr("请选择地区")
                    onSelected: (path, labels) => basicCascader.value = path
                }

                Text {
                    text: qsTr("一级一级往下选，选中路径：%1")
                        .arg(basicCascader.value.length === 0
                            ? "（空）" : basicCascader.value.join(" / "))
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "可搜索的"

            Cascader {
                width: 280
                clearable: true
                options: page.regionOptions
                placeholder: qsTr("点开后可直接搜")
            }
        }

        GallerySection {
            title: "尺寸"

            Row {
                spacing: 16

                Cascader {
                    width: 200
                    size: Enums.Small
                    options: page.regionOptions
                    placeholder: qsTr("小尺寸")
                }

                Cascader {
                    width: 200
                    size: Enums.Default
                    options: page.regionOptions
                    placeholder: qsTr("默认尺寸")
                }

                Cascader {
                    width: 200
                    size: Enums.Large
                    options: page.regionOptions
                    placeholder: qsTr("大尺寸")
                }
            }
        }

        GallerySection {
            title: "受控组件"

            Column {
                spacing: 12

                Cascader {
                    id: controlled

                    width: 280
                    options: page.regionOptions
                    placeholder: qsTr("由外部控制")
                }

                Space {
                    space: 8

                    Button {
                        text: qsTr("选中 浙江 / 杭州")
                        variant: Enums.Light
                        onClicked: controlled.value = ["zj", "hz"]
                    }

                    Button {
                        text: qsTr("清空")
                        variant: Enums.Light
                        onClicked: controlled.value = []
                    }
                }
            }
        }
    }
}
