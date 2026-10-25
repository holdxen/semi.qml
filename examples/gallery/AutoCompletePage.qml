pragma ComponentBehavior: Bound

import QtQuick
import Semi

// AutoComplete。小节顺序与演示内容对齐官方文档页
// content/input/autocomplete/index.md（基本用法 / 自定义候选项渲染 / 远程搜索 /
// 尺寸 / 下拉菜单的位置 / 禁用 / 校验状态 / 自定义空内容）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property var languages: [
        "JavaScript", "TypeScript", "Python", "Rust",
        "Go", "Java", "Kotlin", "Swift", "C++", "C#"
    ]

    // ---- 基本用法：候选由 onSearch 现场生成（官方用三个邮箱域名）----
    property var basicData: []

    // ---- 自定义候选项渲染：官方那四个人 ----
    readonly property var people: [
        { value: "夏可漫", label: "夏可漫", email: "xiakeman@example.com", abbr: "XK", color: "amber" },
        { value: "申悦", label: "申悦", email: "shenyue@example.com", abbr: "SY", color: "indigo" },
        { value: "曲晨一", label: "曲晨一", email: "quchenyi@example.com", abbr: "CY", color: "blue" },
        { value: "文嘉茂", label: "文嘉茂", email: "wenjiamao@example.com", abbr: "JM", color: "cyan" }
    ]

    // ---- 远程搜索：官方那五个组件条目，图标换成本库图标库里最接近的 ----
    readonly property var componentList: [
        { value: "select", label: "选择器", icon: "component_stroked" },
        { value: "input", label: "输入框", icon: "edit" },
        { value: "form", label: "表单", icon: "list" },
        { value: "button", label: "按钮", icon: "button_stroked" },
        { value: "table", label: "表格", icon: "template_stroked" }
    ]
    property var remoteData: []
    property bool remoteLoading: false

    // ---- 下拉菜单的位置 ----
    property var positionData: []

    // ---- 自定义空内容 ----
    property var emptyData: []
    property bool emptyLoading: false

    function domainsFor(input) {
        if (input === "")
            return [];
        return ["gmail.com", "163.com", "qq.com"].map((d) => input + "@" + d);
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本用法"

            Column {
                spacing: 12

                TextLabel {
                    text: qsTr("通过 onSearch 监听用户输入，把输入建议更新到 data；选中候选项时触发 selected。")
                    tone: Enums.Secondary
                }

                AutoComplete {
                    width: 200
                    prefixIcon: "search"
                    showClear: true
                    placeholderText: qsTr("搜索... ")
                    dataList: page.basicData
                    onSearch: (v) => page.basicData = page.domainsFor(v)
                }

                TextLabel {
                    text: qsTr("输入邮箱前缀试试，候选是 onSearch 现拼出来的")
                    size: Enums.Small
                    tone: Enums.Tertiary
                }
            }
        }

        GallerySection {
            title: "自定义候选项渲染"

            Column {
                spacing: 12

                TextLabel {
                    text: qsTr("data 传对象数组（必须含 label、value），renderItem 自定义候选项，"
                        + "renderSelectedItem 决定回填到输入框的文字。")
                    tone: Enums.Secondary
                }

                AutoComplete {
                    width: 280
                    prefixIcon: "search"
                    showClear: true
                    placeholderText: qsTr("输入姓名")
                    dataList: page.people
                    renderItem: personOption
                    renderSelectedItem: (item) => item.email
                }
            }
        }

        GallerySection {
            title: "远程搜索"

            Column {
                spacing: 12

                TextLabel {
                    text: qsTr("从 onSearch 拿到输入值，异步更新 data；期间把 loading 设为 true，"
                        + "下拉里换成一条 Spin。")
                    tone: Enums.Secondary
                }

                AutoComplete {
                    width: 250
                    prefixIcon: "search"
                    placeholderText: qsTr("搜索组件")
                    dataList: page.remoteData
                    loading: page.remoteLoading
                    renderItem: remoteOption
                    renderSelectedItem: (item) => item.value
                    onSearch: (v) => {
                        page.remoteLoading = true;
                        remoteTimer.restart();
                        page.remoteData = page.componentList.filter(
                            (it) => v === "" ? true : it.value.indexOf(v) >= 0);
                    }
                }

                // 官方用 debounce(200ms) + setTimeout(1s) 模拟请求，这里只把延迟留下
                Timer {
                    id: remoteTimer

                    interval: 1000
                    onTriggered: page.remoteLoading = false
                }
            }
        }

        GallerySection {
            title: "尺寸"

            Row {
                spacing: 16

                AutoComplete {
                    width: 200
                    size: Enums.Small
                    dataList: [1, 2, 3, 4]
                    placeholderText: qsTr("small")
                }

                AutoComplete {
                    width: 200
                    dataList: [1, 2, 3, 4]
                    placeholderText: qsTr("default")
                }

                AutoComplete {
                    width: 200
                    size: Enums.Large
                    dataList: [1, 2, 3, 4]
                    placeholderText: qsTr("large")
                }
            }
        }

        GallerySection {
            title: "下拉菜单的位置"

            Column {
                spacing: 12

                TextLabel {
                    text: qsTr("position 可选值参考 Tooltip 的 position。")
                    tone: Enums.Secondary
                }

                Row {
                    spacing: 16

                    AutoComplete {
                        width: 200
                        position: Enums.Top
                        placeholderText: qsTr("选项菜单在上方显示")
                        dataList: page.positionData
                        onSearch: (v) => page.positionData = page.domainsFor(v)
                    }

                    AutoComplete {
                        width: 200
                        position: Enums.RightTop
                        placeholderText: qsTr("选项菜单在右侧显示")
                        dataList: page.positionData
                        onSearch: (v) => page.positionData = page.domainsFor(v)
                    }
                }
            }
        }

        GallerySection {
            title: "禁用"

            AutoComplete {
                width: 200
                enabled: false
                dataList: [1, 2, 3, 4]
                placeholderText: qsTr("禁用下拉菜单")
            }
        }

        GallerySection {
            title: "校验状态"

            Column {
                spacing: 16

                AutoComplete {
                    width: 200
                    value: "ies"
                    validateStatus: Enums.StatusWarning
                }

                AutoComplete {
                    width: 200
                    value: "ies"
                    validateStatus: Enums.StatusDanger
                }

                AutoComplete {
                    width: 200
                    value: "ies"
                }
            }
        }

        GallerySection {
            title: "自定义空内容"

            Column {
                spacing: 12

                TextLabel {
                    text: qsTr("emptyContent 换成自定义节点，这里放一个 Empty。")
                    tone: Enums.Secondary
                }

                AutoComplete {
                    width: 250
                    placeholderText: qsTr("输入任意内容")
                    dataList: page.emptyData
                    loading: page.emptyLoading
                    emptyContent: emptyBlock
                    onSearch: (v) => {
                        page.emptyLoading = true;
                        emptyTimer.restart();
                        page.emptyData = [];
                    }
                }

                Timer {
                    id: emptyTimer

                    interval: 1000
                    onTriggered: page.emptyLoading = false
                }
            }
        }

        GallerySection {
            title: "严格模式"

            Column {
                spacing: 12

                TextLabel {
                    text: qsTr("strict 与 filterLocal 都是本库自有开关（官方 AutoComplete 既不筛也不清）："
                        + "开着时按输入过滤候选，失焦再把不在候选里的输入清掉。")
                    tone: Enums.Secondary
                }

                AutoComplete {
                    width: 250
                    strict: true
                    filterLocal: true
                    dataList: page.languages
                    placeholderText: qsTr("只能从候选中选")
                }
            }
        }
    }

    // renderItem 的组件：根上声明**普通**属性 modelData / index，
    // 由组件那边用 Binding 显式写进来（Loader 不初始化 required property，
    // 带 Bound 的文件也解析不到 context object 的自由变量 —— 坑 42）
    Component {
        id: personOption

        Item {
            id: personRoot

            property var modelData: null
            property int index: 0

            implicitWidth: rowLayout.implicitWidth
            implicitHeight: 32

            Row {
                id: rowLayout

                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Avatar {
                    anchors.verticalCenter: parent.verticalCenter
                    size: "small"
                    text: personRoot.modelData.abbr
                    backgroundColor: Theme.current[personRoot.modelData.color][5]
                }

                Column {
                    spacing: 0

                    TextLabel {
                        text: personRoot.modelData.value
                        size: Enums.Small
                    }

                    TextLabel {
                        text: personRoot.modelData.email
                        size: Enums.Small
                        tone: Enums.Tertiary
                    }
                }
            }
        }
    }

    Component {
        id: remoteOption

        Item {
            id: remoteRoot

            property var modelData: null
            property int index: 0

            implicitWidth: remoteRow.implicitWidth
            implicitHeight: 32

            Row {
                id: remoteRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: remoteRoot.modelData.icon
                    size: 28
                    color: Theme.current.colorText1
                }

                Column {
                    spacing: 0

                    TextLabel { text: remoteRoot.modelData.value }
                    TextLabel { text: remoteRoot.modelData.label; tone: Enums.Tertiary }
                }
            }
        }
    }

    Component {
        id: emptyBlock

        Empty {
            width: 300
            height: 180
            description: qsTr("暂无内容")
        }
    }
}
