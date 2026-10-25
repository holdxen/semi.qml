pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/feedback/skeleton/index.md 的 4 个演示小节，标题逐字取自 data/docs.json。
//
// 官方 demo 的 style={{ width: 200, height: 150 }} 这里就是 width / height；
// style 里的 marginBottom / marginRight 是演示排版，折进 Column / Row 的 spacing。
// 承载 Skeleton 的 Column 都得写死宽度 —— Skeleton 是块级元素、宽度跟着父项，
// 父项若是没写宽的 Column（隐式宽度又由子项的实际宽度算）会一路塌成 0。
//
// 「组合使用 · 表格」官方是把占位件塞进 Table 的 columns / dataSource；本库的 Table
// 单元格只渲染文本，所以改成「空文本的 Table 铺底 + 按 Table 自己的行列度量摆占位块」，
// 观感与官方一致（官方表头那排放的是 width: '0' 的 Title，本来就看不见）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方「基本使用」的 useState(true)：一开始是占位，拨开关才显示真内容
    property bool loading: true

    readonly property var statsItems: [
        { key: qsTr("实际用户数量"), value: "1,480,000" }
    ]

    readonly property var tableColumns: [
        { title: qsTr("Name"), dataIndex: "name" },
        { title: qsTr("Age"), dataIndex: "age" },
        { title: qsTr("Address"), dataIndex: "address" }
    ]

    // 官方骨架表格的表头放的是 width:'0' 的 Skeleton.Title，也就是不出字
    readonly property var skeletonTableColumns: [
        { title: "", dataIndex: "name" },
        { title: "", dataIndex: "age" },
        { title: "", dataIndex: "address" }
    ]

    readonly property var tableRows: [
        { name: "John Brown", age: 32, address: "New York No. 1 Lake Park, New York No. 1 Lake Park" },
        { name: "Jim Green", age: 42, address: "London No. 1 Lake Park" },
        { name: "Joe Black", age: 32, address: "Sidney No. 1 Lake Park" },
        { name: "Disabled User", age: 99, address: "Sidney No. 1 Lake Park" }
    ]

    component Note: Text {
        width: 520
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    // 官方骨架表格里每格的宽度是 50 × 列序（style={{ width: 50 * i }}）
    function skeletonCellWidth(columnInRow) {
        return 50 * (columnInRow + 1);
    }

    function skeletonCellX(skTable, columnInRow) {
        let x = skTable.borderWidth;
        for (let i = 0; i < columnInRow; ++i)
            x += skTable.columnWidths[i];        // Table 侧是 columnWidths 数组（没有 columnWidth() 函数）
        return x + skTable.cellPaddingX;
    }

    function skeletonCellY(skTable, row) {
        return skTable.borderWidth + skTable.headerHeight + row * skTable.rowHeight + skTable.cellPaddingY;
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 460
                text: "import Semi\n\nSkeleton {\n    loading: page.busy\n    active: true\n    placeholder: Component { SkeletonParagraph { rows: 2 } }\n\n    Text { text: \"精心打磨每一个组件的用户体验……\" }\n}"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "基本使用"

            Column {
                width: 520
                spacing: 20

                Row {
                    spacing: 10

                    // 官方这里是 <Switch onChange={() => showContent()} />，非受控
                    Switch {
                        onToggled: {
                            page.loading = !checked
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("显示加载内容")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                // 官方逐个是 Avatar / Image / Title / Paragraph(rows 2) / Button
                Skeleton {
                    loading: page.loading
                    placeholder: Component { SkeletonAvatar {} }

                    Avatar { text: "U" }
                }

                Skeleton {
                    width: 200
                    height: 150
                    loading: page.loading
                    placeholder: Component { SkeletonImage {} }

                    Image {
                        width: 200
                        height: 150
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/qt/qml/SemiGallery/data/img/sample1.png"
                    }
                }

                Skeleton {
                    width: 80
                    loading: page.loading
                    placeholder: Component { SkeletonTitle {} }

                    Text {
                        text: "Semi UI"
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeHeader6
                        font.weight: Font.DemiBold
                    }
                }

                Skeleton {
                    width: 240
                    loading: page.loading
                    placeholder: Component { SkeletonParagraph { rows: 2 } }

                    Text {
                        width: 240
                        wrapMode: Text.WordWrap
                        text: qsTr("精心打磨每一个组件的用户体验，从用户的角度考虑每个组件的使用场景。")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        lineHeight: 20
                        lineHeightMode: Text.FixedHeight
                    }
                }

                Skeleton {
                    loading: page.loading
                    placeholder: Component { SkeletonButton {} }

                    Button { text: qsTr("Button") }
                }
            }
        }

        GallerySection {
            title: "组合使用"

            Column {
                width: 520
                spacing: 28

                Column {
                    width: 520
                    spacing: 8

                    Note { text: qsTr("图片和标题。") }

                    Skeleton {
                        placeholder: Component {
                            Column {
                                width: parent ? parent.width : 0
                                spacing: 10

                                SkeletonImage {
                                    width: 200
                                    height: 150
                                }

                                SkeletonTitle { width: 120 }
                            }
                        }

                        Column {
                            spacing: 10

                            Image {
                                width: 200
                                height: 150
                                fillMode: Image.PreserveAspectFit
                                source: "qrc:/qt/qml/SemiGallery/data/img/sample1.png"
                            }

                            Text {
                                text: "Semi UI"
                                color: Theme.current.colorText0
                                font.pixelSize: Theme.current.fontSizeHeader6
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                Column {
                    width: 520
                    spacing: 8

                    Note { text: qsTr("统计数字。") }

                    Skeleton {
                        placeholder: Component {
                            Column {
                                width: parent ? parent.width : 0
                                spacing: 10

                                SkeletonParagraph {
                                    rows: 1
                                    width: 80
                                }

                                SkeletonTitle { width: 120 }
                            }
                        }

                        Descriptions {
                            width: 320
                            dataList: page.statsItems
                        }
                    }
                }

                Column {
                    width: 520
                    spacing: 8

                    Note { text: qsTr("头像和标题。") }

                    Skeleton {
                        placeholder: Component {
                            Row {
                                spacing: 12

                                SkeletonAvatar {}

                                SkeletonTitle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 120
                                }
                            }
                        }

                        Row {
                            spacing: 12

                            Avatar { text: "UI" }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Semi UI"
                                color: Theme.current.colorText0
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }
                    }
                }

                Column {
                    width: 520
                    spacing: 8

                    Note { text: qsTr("居中段落和按钮。") }

                    Skeleton {
                        width: 300
                        placeholder: Component {
                            Column {
                                width: 300
                                spacing: 10

                                SkeletonParagraph {
                                    width: 300
                                    rows: 3
                                }

                                SkeletonButton {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        Column {
                            width: 300
                            spacing: 6

                            Repeater {
                                model: 3

                                delegate: Text {
                                    width: 300
                                    horizontalAlignment: Text.AlignHCenter
                                    text: qsTr("Hi, Bytedance dance dance.")
                                    color: Theme.current.colorText0
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }

                            Button {
                                text: qsTr("Button")
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                Column {
                    width: 520
                    spacing: 8

                    Note { text: qsTr("头像、标题和段落。") }

                    Skeleton {
                        placeholder: Component {
                            Row {
                                spacing: 12

                                SkeletonAvatar {}

                                Column {
                                    spacing: 12

                                    SkeletonTitle { width: 120 }

                                    SkeletonParagraph {
                                        width: 240
                                        rows: 3
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: 12

                            Avatar { text: "UI" }

                            Column {
                                spacing: 6

                                Text {
                                    text: "Semi UI"
                                    color: Theme.current.colorText0
                                    font.pixelSize: Theme.current.fontSizeHeader6
                                    font.weight: Font.DemiBold
                                }

                                Repeater {
                                    model: 3

                                    delegate: Text {
                                        text: qsTr("Hi, Bytedance dance dance.")
                                        color: Theme.current.colorText0
                                        font.pixelSize: Theme.current.fontSizeRegular
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: 520
                    spacing: 8

                    Note { text: qsTr("表格。") }

                    Skeleton {
                        width: 520
                        placeholder: Component {
                            Item {
                                id: skeletonTableBox

                                width: parent ? parent.width : 0
                                // 占位根节点要把高度写成 implicitHeight —— 容器照它撑开，
                                // 写 height 的话容器会停在 0（SkeletonImage 那种 100% 高的除外）
                                implicitHeight: skeletonTable.height

                                Table {
                                    id: skeletonTable

                                    width: skeletonTableBox.width
                                    columns: page.skeletonTableColumns
                                    // 格子先留空，再按 Table 自己的行列度量把占位块摆上去
                                    dataSource: [
                                        { name: "", age: "", address: "" },
                                        { name: "", age: "", address: "" },
                                        { name: "", age: "", address: "" },
                                        { name: "", age: "", address: "" }
                                    ]
                                    pagination: false
                                }

                                Repeater {
                                    model: 12

                                    delegate: SkeletonParagraph {
                                        id: cell

                                        required property int index

                                        readonly property int rowIndex: Math.floor(cell.index / 3)
                                        readonly property int columnInRow: cell.index % 3

                                        rows: 1
                                        width: page.skeletonCellWidth(cell.columnInRow)
                                        x: page.skeletonCellX(skeletonTable, cell.columnInRow)
                                        y: page.skeletonCellY(skeletonTable, cell.rowIndex)
                                    }
                                }
                            }
                        }

                        Table {
                            width: 520
                            columns: page.tableColumns
                            dataSource: page.tableRows
                            pagination: false
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "加载动画"

            Column {
                width: 520

                Skeleton {
                    active: true
                    placeholder: Component {
                        Row {
                            spacing: 12

                            SkeletonAvatar {}

                            Column {
                                spacing: 12

                                SkeletonTitle { width: 120 }

                                SkeletonParagraph {
                                    width: 240
                                    rows: 3
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 12

                        Avatar { text: "UI" }

                        Column {
                            spacing: 6

                            Text {
                                text: "Semi UI"
                                color: Theme.current.colorText0
                                font.pixelSize: Theme.current.fontSizeHeader6
                                font.weight: Font.DemiBold
                            }

                            Repeater {
                                model: 3

                                delegate: Text {
                                    text: qsTr("Hi, Bytedance dance dance.")
                                    color: Theme.current.colorText0
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
