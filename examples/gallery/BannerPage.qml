pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property bool bannerShown: false

    component Band: Rectangle {
        property string label: ""
        property color bg: Theme.current.colorFill0

        color: bg

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: Theme.current.colorText1
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    component Note: Text {
        width: 640
        wrapMode: Text.WordWrap
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Column {
                spacing: 12
                width: parent.width

                Text {
                    text: qsTr("Banner 自 1.0 支持。")
                    font.pixelSize: Theme.current.fontSizeRegular
                    color: Theme.current.colorText1
                }

                Text {
                    width: 640
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    color: Theme.current.colorText0
                    font.family: "Menlo"
                    font.pixelSize: 13
                    text: "import Semi\n\nBanner {\n    description: \"Semi D2C 现已支持 Figma DevMode\"\n    tone: Enums.Info\n    onClosed: page.bannerShown = false\n}"
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                spacing: 16
                width: parent.width

                Button {
                    text: page.bannerShown ? qsTr("Hide Banner") : qsTr("Show Banner")
                    width: 120
                    onClicked: page.bannerShown = !page.bannerShown
                }

                // 官方演示把 banner 放进 Layout 布局里；Layout 家族已按「布局组件不复刻」
                // 的决定删除，这里用 QML 原生 Column 表达同样的 Header/Banner/Content/Footer 竖排
                Column {
                    width: 640
                    spacing: 0

                    Item {
                        width: parent.width
                        height: 64
                        Band { anchors.fill: parent; label: "Header" }
                    }

                    // 官方那节是 {visible ? banner : null} —— 挂载/卸载由 app 的 state 管，
                    // 所以这里用 Loader；banner 内部的 bannerVisible 每次重新挂载都会回到 true
                    Loader {
                        id: bannerLoader

                        width: parent.width
                        active: page.bannerShown
                        sourceComponent: Component {
                            Banner {
                                description: qsTr("Semi D2C 现已支持 Figma DevMode, 安装插件，随时查阅图层对应的前端代码")
                                onClosed: page.bannerShown = false
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 300
                        Band { anchors.fill: parent; label: "Content"; bg: "transparent" }
                    }

                    Item {
                        width: parent.width
                        height: 64
                        Band { anchors.fill: parent; label: "Footer" }
                    }
                }

                Note {
                    text: qsTr("关闭键默认就在（官方是 closeIcon={null} 才不显示）。点它会先回调 closed、"
                        + "再把内部的 bannerVisible 置 false；这里由 app 的开关控挂载，所以 onClosed 里翻的是 page.bannerShown。")
                }
            }
        }

        GallerySection {
            title: "不同类型"

            Column {
                spacing: 16
                width: parent.width

                Banner {
                    width: 640
                    description: qsTr("Semi D2C 现已支持 Figma DevMode, 安装插件，随时查阅图层对应的前端代码")
                }

                Banner {
                    width: 640
                    tone: Enums.Warning
                    description: qsTr("当前使用 Figma UI Kit 为旧版，可能无法支持完整的 Design to code 能力")
                }

                Banner {
                    width: 640
                    tone: Enums.Danger
                    description: qsTr("当前使用 API 已过期，请尽快升级")
                }

                Banner {
                    width: 640
                    tone: Enums.Success
                    description: qsTr("Semi DSM, Make Semi Design to Any Design")
                }
            }
        }

        GallerySection {
            title: "非全屏模式"

            Column {
                spacing: 16
                width: parent.width

                Banner {
                    width: 640
                    fullMode: false
                    bordered: true
                    iconShown: false
                    closable: false
                    title: qsTr("不知道 AppKey？")
                    description: qsTr("你可先联系对应的研发同学，确认是否已在 应用云平台 申请了应用，并填写对应的信息。")
                }

                Banner {
                    width: 640
                    fullMode: false
                    bordered: true
                    iconShown: false
                    closable: false
                    tone: Enums.Warning
                    title: qsTr("不知道 AppKey？")
                    description: qsTr("你可先联系对应的研发同学，确认是否已在 应用云平台 申请了应用，并填写对应的信息。")
                }

                Banner {
                    width: 640
                    fullMode: false
                    bordered: true
                    iconShown: false
                    closable: false
                    tone: Enums.Danger
                    title: qsTr("不知道 AppKey？")
                    description: qsTr("你可先联系对应的研发同学，确认是否已在 应用云平台 申请了应用，并填写对应的信息。")
                }

                Banner {
                    width: 640
                    fullMode: false
                    bordered: true
                    iconShown: false
                    closable: false
                    tone: Enums.Success
                    title: qsTr("不知道 AppKey？")
                    description: qsTr("你可先联系对应的研发同学，确认是否已在 应用云平台 申请了应用，并填写对应的信息。")
                }

                Note {
                    text: qsTr("官方这四条还写了 icon={null} 与 closeIcon={null}（本库是 iconShown / closable 置 false），"
                        + "并把标题换成 14px 半粗的 div、描述里塞了一个 Text link。"
                        + "标题与描述的字号由组件给（18 / 14），链接换成纯文本。")
                }
            }
        }

        GallerySection {
            title: "自定义内容"

            Column {
                spacing: 16
                width: parent.width

                // 官方外面套了个 500 宽、内边距 20、1px 描边的 div
                Rectangle {
                    width: 500
                    height: customBanner.implicitHeight + 40
                    color: "transparent"
                    radius: Theme.current.radiusSmall
                    border.width: 1
                    border.color: Theme.current.colorBorder

                    Banner {
                        id: customBanner

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        fullMode: false
                        bordered: true
                        tone: Enums.Warning
                        title: "Title"
                        description: qsTr("Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
                            + "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
                            + "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris "
                            + "nisi ut aliquip ex ea commodo consequat")

                        // 官方那两颗键借了 .semi-modal-footer：右对齐、键间隔 12，
                        // 第一颗是 tertiary + light，第二颗是 warning
                        Row {
                            anchors.right: parent.right
                            spacing: 12

                            Button {
                                text: "No, thanks."
                                tone: Enums.Tertiary
                            }

                            Button {
                                text: "Sounds great!"
                                tone: Enums.Warning
                            }
                        }
                    }
                }
            }
        }
    }
}
