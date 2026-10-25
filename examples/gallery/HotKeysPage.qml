pragma ComponentBehavior: Bound

import QtQuick
import Semi

// HotKeys 快捷键。注意本库的 HotKeys 是「把快捷键画成一排键帽」的展示组件 ——
// 官网同名组件是监听器（hotKeys + onHotKey 触发动作），两者只是名字一样，
// 页面里逐条标了差异。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    component Note: Text {
        width: 560
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Row {
                spacing: 16

                HotKeys {
                    keys: ["Ctrl", "Shift", "A"]
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("唤起对话框")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            Note {
                text: qsTr("给 keys 一个字符串数组，组件把它们画成「键 + 键 + 键」的样子，"
                    + "中间自动加号分隔，最后一个后面不加。")
            }
        }

        GallerySection {
            title: "说明"

            Column {
                width: 560
                spacing: 16

                Row {
                    spacing: 16

                    HotKeys { keys: ["Meta", "C"] }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Meta 在 macOS 上是 Command 键")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                Row {
                    spacing: 16

                    HotKeys { keys: ["Alt", "Enter"] }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("换成 Alt 也一样，键名就是显示出来的字")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }

            Note {
                text: qsTr("这里和官网有个大差别要说清楚：官网的 HotKeys 是监听器，"
                    + "传入组合键后由它监听按键、回调 onHotKey 干活；本库的 HotKeys 只负责显示，"
                    + "不监听任何按键。要在 QML 里真正响应快捷键，得自己用 Keys、"
                    + "Shortcut 或者 Action。")
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 560
                spacing: 14

                Row {
                    spacing: 16

                    HotKeys { keys: ["Ctrl", "S"] }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("保存")
                        color: Theme.current.colorText1
                    }
                }

                Row {
                    spacing: 16

                    HotKeys { keys: ["Ctrl", "Shift", "P"] }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("命令面板")
                        color: Theme.current.colorText1
                    }
                }

                Row {
                    spacing: 16

                    HotKeys { keys: ["Esc"] }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("单个键也行")
                        color: Theme.current.colorText1
                    }
                }
            }

            Note {
                text: qsTr("keys 里放什么就显示什么，组件不做组合键合法性校验 ——"
                    + "官网会拦掉不合规的组合，本库不会。")
            }
        }

        GallerySection {
            title: "自定义内容"

            Column {
                width: 560
                spacing: 14

                Row {
                    spacing: 16

                    HotKeys {
                        keys: ["Ctrl", "K"]
                        size: Enums.Small
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("size: Small")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }

                Row {
                    spacing: 16

                    HotKeys { keys: ["Ctrl", "K"] }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("size: Default")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }
            }

            Note {
                text: qsTr("官网能用 content / render 换掉键帽里的渲染内容；本库没有这两个属性，"
                    + "键帽形状是固定的，可调的就只有 size 两档（small 18 高、default 22 高）。")
            }
        }
    }
}
