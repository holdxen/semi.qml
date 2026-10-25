pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property var cityOptions: [
        { label: "北京", value: "beijing" },
        { label: "上海", value: "shanghai" },
        { label: "广州", value: "guangzhou" },
        { label: "深圳", value: "shenzhen" },
        { label: "杭州", value: "hangzhou" },
        { label: "成都", value: "chengdu" },
        { label: "武汉", value: "wuhan" },
        { label: "西安", value: "xian" }
    ]

    readonly property var groupOptions: [
        {
            label: "亚洲",
            children: [
                { label: "中国", value: "cn" },
                { label: "日本", value: "jp" },
                { label: "韩国", value: "kr" }
            ]
        },
        {
            label: "欧洲",
            children: [
                { label: "德国", value: "de" },
                { label: "法国", value: "fr" },
                { label: "英国", value: "uk" }
            ]
        },
        {
            label: "美洲",
            children: [
                { label: "美国", value: "us" },
                { label: "加拿大", value: "ca" }
            ]
        }
    ]

    // --shot 下把首个 Select 打开，否则抓不到下拉外观（与弹层页的约定一致）
    Component.onCompleted: {
        if (Qt.application.arguments.indexOf("--shot") >= 0)
            Qt.callLater(() => singleSelect.open());
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本使用"

            Column {
                spacing: 12

                Select {
                    id: singleSelect

                    width: 260
                    options: page.cityOptions
                    placeholder: qsTr("请选择城市")
                    onSelected: (value) => singleSelect.value = value
                }

                Text {
                    text: qsTr("选中值：%1").arg(singleSelect.value === null ? "（空）" : String(singleSelect.value))
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "以数组形式传入 Option"

            Select {
                width: 260
                options: ["简单字符串一", "简单字符串二", "简单字符串三"]
                placeholder: qsTr("字符串数组也能用")
            }
        }

        GallerySection {
            title: "可搜索"

            Column {
                spacing: 12

                Select {
                    width: 260
                    filter: true
                    options: page.cityOptions
                    placeholder: qsTr("输入关键词搜索")
                }

                Text {
                    text: qsTr("输入城市名过滤选项")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "多选"

            Column {
                spacing: 12

                Select {
                    id: multiSelect

                    width: 320
                    multiple: true
                    clearable: true
                    options: page.cityOptions
                    placeholder: qsTr("可多选")
                    onSelected: (value) => multiSelect.values = value
                }

                Text {
                    text: qsTr("已选 %1 项：%2").arg(multiSelect.values.length).arg(multiSelect.displayText)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "多选 + 可搜索"

            Select {
                width: 320
                multiple: true
                filter: true
                clearable: true
                options: page.cityOptions
                placeholder: qsTr("搜索并多选")
            }
        }

        GallerySection {
            title: "多选标签数量限制"

            Column {
                spacing: 12

                Select {
                    width: 320
                    multiple: true
                    maxTagCount: 2
                    options: page.cityOptions
                    placeholder: qsTr("最多显示 2 个标签")
                    values: ["beijing", "shanghai", "guangzhou"]
                }

                Text {
                    text: qsTr("maxTagCount=2，超出显示 +N")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "分组"

            Select {
                width: 260
                options: page.groupOptions
                placeholder: qsTr("选择国家/地区")
            }
        }

        GallerySection {
            title: "不同尺寸"

            Row {
                spacing: 16

                Select {
                    width: 200
                    size: Enums.Small
                    options: page.cityOptions
                    placeholder: qsTr("小尺寸")
                }

                Select {
                    width: 200
                    size: Enums.Default
                    options: page.cityOptions
                    placeholder: qsTr("默认尺寸")
                }

                Select {
                    width: 200
                    size: Enums.Large
                    options: page.cityOptions
                    placeholder: qsTr("大尺寸")
                }
            }
        }

        GallerySection {
            title: "不同校验状态样式"

            Column {
                spacing: 12

                Select {
                    width: 260
                    options: page.cityOptions
                    placeholder: qsTr("默认状态")
                }

                Select {
                    width: 260
                    options: page.cityOptions
                    placeholder: qsTr("警告状态")
                    validateStatus: Enums.StatusWarning
                }

                Select {
                    width: 260
                    options: page.cityOptions
                    placeholder: qsTr("错误状态")
                    validateStatus: Enums.StatusDanger
                }
            }
        }

        GallerySection {
            title: "加载状态"

            Select {
                width: 260
                options: page.cityOptions
                placeholder: qsTr("加载中...")
                loading: true
            }
        }

        GallerySection {
            title: "远程搜索"

            Column {
                spacing: 12

                Select {
                    id: remoteSelect

                    width: 260
                    filter: true
                    placeholder: qsTr("输入搜索远程数据")
                    loading: remoteSelect._loading

                    property bool _loading: false

                    onSearch: (keyword) => {
                        remoteSelect._loading = true;
                        // 模拟远程请求
                        Qt.callLater(() => {
                            remoteSelect.options = [
                                { label: keyword + " 结果 1", value: keyword + "_1" },
                                { label: keyword + " 结果 2", value: keyword + "_2" },
                                { label: keyword + " 结果 3", value: keyword + "_3" }
                            ];
                            remoteSelect._loading = false;
                        });
                    }
                }

                Text {
                    text: qsTr("输入关键词模拟远程搜索")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "自定义渲染选项"

            Select {
                width: 260
                options: page.cityOptions
                placeholder: qsTr("自定义选项渲染")

                // 自定义渲染：组件根声明普通属性（不是 required），Select 用 Binding 注入。
                // 见 src/Select.qml 的 renderOption 注释与 tests/tst_loaderinject.qml。
                renderOption: Component {
                    Row {
                        id: opt
                        property var modelData
                        property int index
                        property bool chosen
                        property bool disabled

                        spacing: 8

                        Icon {
                            name: "map_pin"
                            size: 14
                            color: Theme.current.colorPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: opt.modelData !== null && opt.modelData !== undefined
                                ? (opt.modelData.label !== undefined ? opt.modelData.label : String(opt.modelData))
                                : ""
                            color: opt.chosen ? Theme.current.colorPrimary : Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
