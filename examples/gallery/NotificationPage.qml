pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/feedback/notification/index.md 的 9 个演示小节。
//
// 官方 Notification 是一组静态方法（open / info / success / warning / error / close /
// destroyAll / config / useNotification），QML 的 type 上没有静态方法，所以本页全部走实例方法：
// 一个 Notification {} 就是官方 useNotification() 返回的 [notification, contextHolder] 那一对。
//
// 与官方的三处形式差别（都是端口的既有限制，逐条记在 Notification.qml 头部）：
// · title / content 官方是 ReactNode，这里字符串或 Component 两支；
// · icon 官方是 ReactNode（可以带 style 改色），这里只收图标名，颜色跟着 type 走；
// · top / left / right / bottom 官方既能在 config() 里给也能在调用入参里给，这里同理 ——
//   这四个名字被 Item 的 FINAL 锚点线占了，做不成元素属性。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    Notification {
        id: notice
    }

    // ------------------------------------------------------------ 小节内的状态
    // 官方「手动关闭」那节的 const [ids, setIds] = useState([])
    property var manualIds: []

    // 官方各小节共用同一份 opts，这里把内容原样抄过来
    readonly property var plainOpts: ({
        title: "Hi, Bytedance",
        content: "ies dance dance dance",
        duration: 3
    })
    readonly property var positionOpts: ({
        duration: 3,
        position: "topRight",
        content: "semi-ui-notification",
        title: "Hi bytedance"
    })
    readonly property var lightOpts: ({
        title: "Hi, Bytedance",
        content: "Hi, Bytedance dance dance",
        duration: 3,
        theme: "light"
    })
    readonly property var delayOpts: ({
        content: "Hi, Bytedance dance dance",
        duration: 10
    })
    readonly property var manualOpts: ({
        content: "Not auto close",
        title: "Hi",
        duration: 0
    })

    // 「链接文本」那节的 ReactNode content：一段正文 + marginTop 8 的一行链接
    Component {
        id: linkContent

        Column {
            spacing: 8

            Text {
                text: "Hi, Bytedance dance dance"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeRegular
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }

            Row {
                spacing: 20

                TextLabel {
                    link: true
                    text: "查看详情"
                }

                TextLabel {
                    link: true
                    text: "一会再看"
                }
            }
        }
    }

    // 官方「更新内容」那节的 setTimeout(..., 1000)
    property string updateId: ""

    Timer {
        id: updateTimer

        interval: 1000
        onTriggered: notice.open({
            title: "Hi, Bytedance",
            content: "updated",
            duration: 10,
            id: page.updateId
        })
    }

    function showManual() {
        page.manualIds = page.manualIds.concat([notice.info(page.manualOpts)]);
    }

    function hideManual() {
        if (page.manualIds.length === 0)
            return;
        // 官方 notification.close(idsTmp.shift())：关掉最早弹出的那条
        notice.close(page.manualIds[0]);
        page.manualIds = page.manualIds.slice(1);
    }

    function openAt(position) {
        notice.info({
            duration: page.positionOpts.duration,
            position: position,
            content: page.positionOpts.content,
            title: page.positionOpts.title
        });
    }

    function updateById() {
        page.updateId = notice.open({
            title: "Hi, Bytedance",
            content: "ies dance dance dance",
            duration: 3
        });
        updateTimer.restart();
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 460
                text: "import Semi\n\nNotification { id: notice }\n\nnotice.open({ title: \"Hi, Bytedance\", content: \"ies dance dance dance\", duration: 3 })"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "普通通知"

            Row {
                spacing: 12

                Button {
                    text: "Display Notification"
                    onClicked: notice.open({
                        title: "Hi, Bytedance",
                        content: "ies dance dance dance",
                        duration: 3
                    })
                }
            }
        }

        GallerySection {
            title: "不同位置弹出"

            ButtonGroup {
                Button {
                    text: "top"
                    onClicked: page.openAt("top")
                }

                Button {
                    text: "topLeft"
                    onClicked: page.openAt("topLeft")
                }

                Button {
                    text: "topRight"
                    onClicked: page.openAt("topRight")
                }
            }

            Item {
                width: 1
                height: 16
            }

            ButtonGroup {
                Button {
                    text: "bottom"
                    onClicked: page.openAt("bottom")
                }

                Button {
                    text: "bottomRight"
                    onClicked: page.openAt("bottomRight")
                }

                Button {
                    text: "bottomLeft"
                    onClicked: page.openAt("bottomLeft")
                }
            }
        }

        GallerySection {
            title: "带有图标的通知"

            Text {
                text: "默认的图标"
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeHeader6
                font.weight: Font.DemiBold
            }

            Row {
                spacing: 8

                Button {
                    text: "Success"
                    tone: Enums.Primary
                    onClicked: notice.success(page.plainOpts)
                }

                Button {
                    text: "Info"
                    onClicked: notice.info(page.plainOpts)
                }

                Button {
                    text: "Warning"
                    tone: Enums.Warning
                    onClicked: notice.warning(page.plainOpts)
                }

                Button {
                    text: "Error"
                    tone: Enums.Danger
                    onClicked: notice.error(page.plainOpts)
                }
            }

            Text {
                text: "自定义图标"
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeHeader6
                font.weight: Font.DemiBold
            }

            Row {
                spacing: 8

                Button {
                    icon: "toutiao_logo"
                    onClicked: notice.info({
                        title: page.plainOpts.title,
                        content: page.plainOpts.content,
                        duration: page.plainOpts.duration,
                        icon: "toutiao_logo"
                    })
                }

                Button {
                    icon: "vigo_logo"
                    onClicked: notice.info({
                        title: page.plainOpts.title,
                        content: page.plainOpts.content,
                        duration: page.plainOpts.duration,
                        icon: "vigo_logo"
                    })
                }

                Button {
                    icon: "semi_logo"
                    onClicked: notice.info({
                        title: page.plainOpts.title,
                        content: page.plainOpts.content,
                        duration: page.plainOpts.duration,
                        icon: "semi_logo"
                    })
                }
            }

            Text {
                width: 560
                text: "官方 icon 是 ReactNode，示例里用 style 把图标染成红/粉；本端口的 icon 只收图标名，"
                    + "颜色跟着 type 走（这三条都是 info，于是都是 info 色）。"
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        GallerySection {
            title: "多色样式"

            Column {
                spacing: 12

                Row {
                    spacing: 12

                    Button {
                        text: "Info"
                        onClicked: notice.info(page.lightOpts)
                    }

                    Button {
                        text: "Success"
                        onClicked: notice.success(page.lightOpts)
                    }
                }

                Row {
                    spacing: 12

                    Button {
                        text: "Warning"
                        tone: Enums.Warning
                        onClicked: notice.warning(page.lightOpts)
                    }

                    Button {
                        text: "Error"
                        tone: Enums.Danger
                        onClicked: notice.error(page.lightOpts)
                    }
                }
            }
        }

        GallerySection {
            title: "链接文本"

            Row {
                spacing: 12

                Button {
                    text: "Display Notification"
                    onClicked: notice.info({
                        title: "This is a title",
                        content: linkContent,
                        duration: 3
                    })
                }
            }
        }

        GallerySection {
            title: "修改延时"

            Row {
                spacing: 12

                Button {
                    text: "Close After 10s"
                    onClicked: notice.info(page.delayOpts)
                }
            }
        }

        GallerySection {
            title: "手动关闭"

            Row {
                spacing: 12

                Button {
                    text: "Show Notification"
                    tone: Enums.Primary
                    onClicked: page.showManual()
                }

                Button {
                    text: "Hide Notification"
                    tone: Enums.Primary
                    onClicked: page.hideManual()
                }
            }
        }

        GallerySection {
            title: "更新内容"

            Row {
                spacing: 12

                Button {
                    text: "Display Notification"
                    onClicked: page.updateById()
                }
            }

            Text {
                width: 560
                text: "1 秒后用同一个 id 再 open 一次，于是原地换成 updated、时长改成 10s —— "
                    + "官方这条走的是 notification.open({ id })，等价于按 id 更新 + 重计时长。"
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }
}
