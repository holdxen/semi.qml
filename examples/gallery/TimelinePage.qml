pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Timeline。小节顺序与标题对齐官方文档页 content/show/timeline/index.md
// （docs.json 里的 6 个小节；官方「时间轴位置」下的 4 个 #### 子标题，按 PinCodePage
// 「限制验证码格式」那一节的写法做成小节内的小标题）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    component ModeCaption: Text {
        width: 520
        wrapMode: Text.WordWrap
        color: Theme.current.colorText1
        font.pixelSize: Theme.current.fontSizeRegular
    }

    // 官方两处把正文写成 <span style={{ fontSize: '18px' }}>，
    // 行内内容继承 -content 的 14/20，所以这边锁同样的行高、只换字号。
    readonly property Component bigContent: Component {
        Text {
            text: "自定义节点样式"
            color: Theme.current.colorText0
            font.pixelSize: 18
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
        }
    }

    readonly property Component bigContent2: Component {
        Text {
            text: "第二个节点内容"
            color: Theme.current.colorText0
            font.pixelSize: 18
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
        }
    }

    readonly property Component alertDot: Component {
        Icon {
            name: "alert_triangle"
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 620
                text: "import Semi\n\n"
                    + "// 官方写 <Timeline><Timeline.Item/></Timeline>，\n"
                    + "// QML 没有嵌套类型，条目就叫 TimelineItem，直接声明在 Timeline 里\n"
                    + "Timeline {\n"
                    + "    mode: \"alternate\"            // left（默认）| right | center | alternate\n"
                    + "    TimelineItem {\n"
                    + "        time: \"2019-07-14 10:35\"\n"
                    + "        content: \"第一个节点内容\"\n"
                    + "        type: \"ongoing\"          // default | ongoing | success | warning | error\n"
                    + "        extra: \"节点辅助说明信息\"\n"
                    + "    }\n"
                    + "}"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "基本用法"

            Timeline {
                width: 536

                TimelineItem {
                    time: "2019-07-14 10:35"
                    content: "第一个节点内容"
                }
                TimelineItem {
                    time: "2019-06-13 16:17"
                    content: "第二个节点内容"
                }
                TimelineItem {
                    time: "2019-05-14 18:34"
                    content: "第三个节点内容"
                }
            }
        }

        GallerySection {
            title: "节点类型"

            Timeline {
                width: 536

                TimelineItem {
                    time: "2019-07-14 10:35"
                    type: "ongoing"
                    content: "审核中"
                }
                TimelineItem {
                    time: "2019-06-13 16:17"
                    type: "success"
                    content: "发布成功"
                }
                TimelineItem {
                    time: "2019-05-14 18:34"
                    type: "error"
                    content: "审核失败"
                }
            }
        }

        GallerySection {
            title: "自定义节点"

            Timeline {
                width: 536

                TimelineItem {
                    time: "2019-07-14 10:35"
                    content: "默认样式的节点"
                }
                TimelineItem {
                    time: "2019-06-13 16:17"
                    type: "warning"
                    dot: page.alertDot
                    content: "自定义图标"
                }
                TimelineItem {
                    time: "2019-05-14 18:34"
                    color: "pink"
                    content: "自定义节点颜色"
                }
                TimelineItem {
                    time: "2019-04-10 12:20"
                    content: page.bigContent
                }
            }
        }

        GallerySection {
            title: "时间轴位置"

            Column {
                spacing: 24

                ModeCaption { text: "时间轴在左侧（默认）" }

                Timeline {
                    width: 536

                    TimelineItem {
                        time: "2019-07-14 10:35"
                        extra: "节点辅助说明信息"
                        content: "第一个节点内容"
                    }
                    TimelineItem {
                        time: "2019-06-13 16:17"
                        extra: "节点辅助说明信息"
                        content: "第二个节点内容"
                    }
                    TimelineItem {
                        time: "2019-05-14 18:34"
                        extra: "节点辅助说明信息"
                        content: "第三个节点内容"
                    }
                    TimelineItem {
                        time: "2019-05-09 09:12"
                        extra: "节点辅助说明信息"
                        content: "第四个节点内容"
                    }
                }

                ModeCaption { text: "时间节点在左侧" }

                Timeline {
                    width: 536
                    mode: "center"

                    TimelineItem {
                        time: "2019-07-14 10:35"
                        extra: "节点辅助说明信息"
                        content: "第一个节点内容"
                    }
                    TimelineItem {
                        time: "2019-06-13 16:17"
                        extra: "节点辅助说明信息"
                        content: "第二个节点内容"
                    }
                    TimelineItem {
                        time: "2019-05-14 18:34"
                        extra: "节点辅助说明信息"
                        content: "第三个节点内容"
                    }
                    TimelineItem {
                        time: "2019-05-09 09:12"
                        extra: "节点辅助说明信息"
                        content: "第四个节点内容"
                    }
                }

                ModeCaption { text: "交替展现" }

                Timeline {
                    width: 536
                    mode: "alternate"

                    TimelineItem {
                        time: "2019-07-14 10:35"
                        extra: "节点辅助说明信息"
                        content: "第一个节点内容"
                    }
                    TimelineItem {
                        time: "2019-06-13 16:17"
                        extra: "节点辅助说明信息"
                        content: "第二个节点内容"
                    }
                    TimelineItem {
                        time: "2019-05-14 18:34"
                        extra: "节点辅助说明信息"
                        content: "第三个节点内容"
                    }
                    TimelineItem {
                        time: "2019-05-09 09:12"
                        extra: "节点辅助说明信息"
                        content: "第四个节点内容"
                    }
                }

                ModeCaption { text: "时间轴在右侧" }

                Timeline {
                    width: 536
                    mode: "right"

                    TimelineItem {
                        time: "2019-07-14 10:35"
                        extra: "节点辅助说明信息"
                        content: "第一个节点内容"
                    }
                    TimelineItem {
                        time: "2019-06-13 16:17"
                        extra: "节点辅助说明信息"
                        content: "第二个节点内容"
                    }
                    TimelineItem {
                        time: "2019-05-14 18:34"
                        extra: "节点辅助说明信息"
                        content: "第三个节点内容"
                    }
                    TimelineItem {
                        time: "2019-05-09 09:12"
                        extra: "节点辅助说明信息"
                        content: "第四个节点内容"
                    }
                }
            }
        }

        GallerySection {
            title: "使用 dataSource"

            Timeline {
                width: 536
                mode: "alternate"
                dataSource: [
                    {
                        "time": "2019-07-14 10:35",
                        "extra": "节点辅助说明信息",
                        "content": "第一个节点内容",
                        "type": "ongoing"
                    },
                    {
                        "time": "2019-06-13 16:17",
                        "extra": "节点辅助说明信息",
                        "content": page.bigContent2,
                        "color": "pink"
                    },
                    {
                        "time": "2019-05-14 18:34",
                        "extra": "节点辅助说明信息",
                        "dot": page.alertDot,
                        "content": "第三个节点内容",
                        "type": "warning"
                    },
                    {
                        "time": "2019-05-09 09:12",
                        "extra": "节点辅助说明信息",
                        "content": "第四个节点内容",
                        "type": "success"
                    }
                ]
            }
        }
    }
}
