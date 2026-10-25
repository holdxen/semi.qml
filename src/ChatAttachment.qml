pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Semi

// Chat 的附件条：输入框里可编辑（hover 露清除钮、上传中有进度环、失败有警示图标），
// 消息内容里的 image_url / file_url 也复用这里的两颗静态芯片。
//
//     ChatAttachment { attachment: inputBox.attachment; onClear: (item) => ... }
//
// 背景色按官方三档走：输入区 $color-chat_attachment_file-bg = fill-0；
// 消息里「其他角色」是 fill-2（chat.scss:235）、用户气泡里是 bg-0（:251），
// 由使用方用 fileBg 直通。
//
// 官方 hover 才露清除钮那条 CSS（chat.scss:474）选择器写的是
// `-inputBox-attachment-clear`，而节点上挂的类名是 `-attachment-clear`
// （attachment.tsx:82）⇒ 规则永远命不中，端口照实测效果：清除钮一直可见。
Flow {
    id: root

    property var attachment: []
    property bool showClear: true
    property color fileBg: Theme.current.colorFill0
    // 官方 onClear(item)
    signal clear(var item)

    spacing: 10                                  // $spacing-chat_attachment-columnGap
    // 官方 row-gap 5；Flow 只有一个 spacing，行距按 10 走（偏差已记 PROGRESS）
    readonly property real fileIconSize: Theme.current.widthIconExtraLarge

    Repeater {
        model: root.attachment

        delegate: Item {
            id: chip

            required property var modelData

            readonly property var item: modelData
            readonly property string fileName: item.name !== undefined ? String(item.name) : ""
            readonly property string fileType: item.type !== undefined ? String(item.type) : ""
            readonly property string fileSuffix: {
                const parts = fileName.split(".");
                return parts.length > 1 ? parts[parts.length - 1].toLowerCase() : "";
            }
            // official: fileInstance.type 以 image/ 开头，或后缀在图库里
            readonly property bool isImg: {
                const pic = ["png", "jpg", "jpeg", "gif", "bmp", "webp"];
                return fileType.indexOf("image/") === 0 || pic.indexOf(fileSuffix) >= 0;
            }
            readonly property real chipSize: 60

            width: isImg ? chipSize : fileChip.implicitWidth
            height: isImg ? chipSize : fileChip.implicitHeight

            // 图片档：官方 <Image width={60} height={60}> + -img（radius medium、object-fit cover）。
            // QML 的 Image 没有 radius，用 MultiEffect 遮罩裁圆角
            Image {
                id: chipImage

                visible: chip.isImg
                anchors.fill: parent
                source: chip.isImg && chip.item.url !== undefined ? String(chip.item.url) : ""
                fillMode: Image.PreserveAspectCrop
                layer.enabled: visible
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: chipMask
                }
            }

            Item {
                id: chipMask

                visible: false
                width: chipImage.width
                height: chipImage.height

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.current.radiusMedium    // $radius-chat_attachment_img
                    color: "white"
                }
            }

            // 文件档：图标 + 标题（90px 截断）+ `TYPE · size`
            Rectangle {
                id: fileChip

                visible: !chip.isImg
                height: 50                             // $width-chat_attachment_file
                implicitWidth: fileRow.implicitWidth + 10   // padding 5×2
                color: root.fileBg
                radius: Theme.current.radiusMedium     // $radius-chat_attachment_file

                Row {
                    id: fileRow

                    anchors.verticalCenter: parent.verticalCenter
                    x: 5
                    height: parent.height - 10
                    spacing: 5                          // $spacing-chat_attachment_file-columnGap

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "brief_stroked"
                        size: root.fileIconSize        // extra-large = 24
                        color: Theme.current.colorText2    // $color-chat_attachment_file_icon
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            width: 90                   // $width-chat_attachment_file_title
                            elide: Text.ElideRight
                            text: chip.fileName
                            color: Theme.current.colorText0  // $color-chat_attachment_file_title
                            font.pixelSize: Theme.current.fontSizeHeader6
                        }

                        Text {
                            // 官方 `type.toUpperCase()` + 有 type 才补 ` · `
                            text: (chip.fileType !== "" ? chip.fileType.toUpperCase() + " · " : "")
                                + (chip.item.size !== undefined ? chip.item.size : "")
                            color: Theme.current.colorText2  // $color-chat_attachment_file_metadata
                            font.pixelSize: Theme.current.fontSizeRegular
                        }
                    }
                }
            }

            // 清除钮：官方一直可见（hover 规则选择器笔误，见文件头）
            Icon {
                visible: root.showClear
                x: parent.width - width + 8             // top: -8; right: -8 的外挑
                y: -8
                name: "clear"
                size: Theme.current.widthIconLarge      // size="large" = 20
                color: Theme.current.colorText2         // $color-chat_attachment_clear_icon

                TapHandler {
                    onTapped: root.clear(chip.item)
                }
            }

            // 上传中且没到 100%：居中盖一个 30px 进度环
            Progress {
                visible: chip.item.percent !== undefined && chip.item.percent !== 100
                    && chip.item.status === "uploading"
                anchors.centerIn: parent
                type: "circle"
                percent: chip.item.percent !== undefined ? chip.item.percent : 0
                circleWidth: 30                         // 官方 width={30}
            }

            // 失败 / 校验不过：居中警示图标
            Icon {
                visible: chip.item.status === "uploadFail" || chip.item.status === "validateFail"
                anchors.centerIn: parent
                name: "alert_circle"
                color: Theme.current.colorDanger        // $color-chat_attachment_fail
            }
        }
    }
}
