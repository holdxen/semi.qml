pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 官方示例：content/input/taginput/index.md（17 个小节，标题与 docs.json 一致）
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ---- 各 demo 的受控状态 ----
    property var controlledTags: ["抖音"]
    property string controlledInput: "abc"
    property var eventLog: []

    // 自定义标签渲染那节的数据。官方用四张远程头像，这里换成仓库里的本地图
    readonly property var personList: [
        { name: "夏可漫", avatar: "qrc:/qt/qml/SemiGallery/data/img/sample1.png" },
        { name: "申悦", avatar: "qrc:/qt/qml/SemiGallery/data/img/sample2.png" },
        { name: "曲晨一", avatar: "qrc:/qt/qml/SemiGallery/data/img/sample3.png" },
        { name: "文嘉茂", avatar: "qrc:/qt/qml/SemiGallery/data/img/sample1.png" }
    ]
    property var customTags: ["夏可漫"]

    function avatarOf(name) {
        for (let i = 0; i < page.personList.length; ++i) {
            if (page.personList[i].name === name)
                return page.personList[i].avatar;
        }
        return "qrc:/qt/qml/SemiGallery/data/img/sample2.png";
    }

    function logEvent(line) {
        page.eventLog = page.eventLog.concat([line]).slice(-6);
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本演示"

            TagInput {
                width: 400
                defaultValue: ["抖音", "火山", "西瓜视频"]
                placeholder: qsTr("请输入...")
                onChange: (v) => console.log("onChange", JSON.stringify(v))
            }
        }

        GallerySection {
            title: "批量添加"

            Column {
                spacing: 16

                TagInput {
                    width: 400
                    separator: "-"
                    placeholder: qsTr("使用 - 进行批量输入")
                    onChange: (v) => console.log("onChange", JSON.stringify(v))
                }

                TagInput {
                    width: 400
                    separator: ["-", "/", "|", "++"]
                    placeholder: qsTr("支持多个分隔符进行批量输入")
                    onChange: (v) => console.log("onChange", JSON.stringify(v))
                }
            }
        }

        GallerySection {
            title: "批量删除"

            TagInput {
                width: 400
                showClear: true
                defaultValue: ["抖音", "火山"]
                placeholder: qsTr("请输入...")
                onChange: (v) => console.log("onChange", JSON.stringify(v))
            }
        }

        GallerySection {
            title: "禁用"

            TagInput {
                width: 400
                enabled: false
                showClear: true
                defaultValue: ["抖音", "火山", "西瓜视频"]
                placeholder: qsTr("请输入...")
            }
        }

        GallerySection {
            title: "尺寸大小"

            Column {
                spacing: 16

                TagInput {
                    width: 400
                    size: Enums.Small
                    placeholder: "small"
                }

                TagInput {
                    width: 400
                    placeholder: "default"
                }

                TagInput {
                    width: 400
                    size: Enums.Large
                    placeholder: "large"
                }
            }
        }

        GallerySection {
            title: "不同校验状态样式"

            Column {
                spacing: 16

                TagInput {
                    width: 400
                    placeholder: "default"
                }

                TagInput {
                    width: 400
                    placeholder: "warning"
                    validateStatus: Enums.StatusWarning
                }

                TagInput {
                    width: 400
                    placeholder: "error"
                    validateStatus: Enums.StatusDanger
                }
            }
        }

        GallerySection {
            title: "前缀 / 后缀"

            Column {
                spacing: 16

                TagInput {
                    width: 400
                    prefixIcon: "vigo_logo"
                }

                TagInput {
                    width: 400
                    prefix: "Prefix"
                }

                TagInput {
                    width: 400
                    suffixIcon: "gift"
                }

                TagInput {
                    width: 400
                    suffix: "Suffix"
                }

                // 官方 Form 的 labelPosition='inset' 会把标签交给 insetLabel，
                // 它和 prefix 抢同一个槽位，这里单列出来好对比
                TextLabel { text: qsTr("insetLabel（与 prefix 同槽位）") }

                TagInput {
                    width: 400
                    insetLabel: "insetLabel"
                    showClear: true
                }
            }
        }

        GallerySection {
            title: "失焦后自动创建标签"

            TagInput {
                width: 400
                defaultValue: ["抖音", "火山", "西瓜视频"]
                addOnBlur: true
                placeholder: qsTr("请输入...")
                onChange: (v) => console.log("onChange", JSON.stringify(v))
            }
        }

        GallerySection {
            title: "过滤重复标签"

            TagInput {
                width: 400
                defaultValue: ["抖音", "火山", "西瓜视频"]
                allowDuplicates: false
                placeholder: qsTr("请输入...")
                onChange: (v) => console.log("onChange", JSON.stringify(v))
            }
        }

        GallerySection {
            title: "输入限制"

            Column {
                spacing: 16

                TagInput {
                    width: 400
                    max: 3
                    placeholder: qsTr("最多输入3条标签..")
                    onChange: (v) => console.log("onChange", JSON.stringify(v))
                    onExceed: (v) => {
                        maxToast.warning(qsTr("不允许超过 max"));
                        console.log("onExceed", JSON.stringify(v));
                    }
                }

                TagInput {
                    width: 400
                    maxLength: 5
                    placeholder: qsTr("单个标签长度不超过5...")
                    onChange: (v) => console.log("onChange", JSON.stringify(v))
                    onInputExceed: (v) => {
                        lengthToast.warning(qsTr("不允许超过 maxLength"));
                        console.log("onInputExceed", v);
                    }
                }
            }
        }

        GallerySection {
            title: "限制标签展示数量"

            TagInput {
                width: 400
                maxTagCount: 2
                showRestTagsPopover: true
                restTagsPopoverProps: ({ position: "top" })
                defaultValue: ["抖音", "火山", "西瓜视频"]
                onChange: (v) => console.log("onChange", JSON.stringify(v))
            }
        }

        GallerySection {
            title: "标签受控"

            TagInput {
                width: 400
                value: page.controlledTags
                onChange: (v) => page.controlledTags = v
            }
        }

        GallerySection {
            title: "输入受控"

            TagInput {
                width: 400
                inputValue: page.controlledInput
                onInputChange: (v) => page.controlledInput = v
            }
        }

        GallerySection {
            title: "回调"

            Column {
                spacing: 12

                TagInput {
                    width: 400
                    defaultValue: ["抖音"]
                    placeholder: qsTr("请输入...")
                    showClear: true
                    onFocused: page.logEvent("onFocus")
                    onBlurred: page.logEvent("onBlur")
                    onChange: (v) => page.logEvent("onChange：" + JSON.stringify(v))
                    onAdd: (v) => page.logEvent("onAdd：" + JSON.stringify(v))
                    onRemove: (value, index) => page.logEvent(
                        "onRemove：" + value + "，序号 " + index)
                    onInputChange: (v) => page.logEvent("onInputChange：" + v)
                }

                TextLabel {
                    text: page.eventLog.length === 0
                        ? qsTr("聚焦、打字、回车、删标签，下面会列出最近几次回调")
                        : qsTr("最近 %1 次回调：").arg(page.eventLog.length)
                }

                Repeater {
                    model: page.eventLog

                    delegate: Paragraph {
                        required property var modelData

                        text: String(modelData)
                        size: Enums.Small
                        tone: Enums.Tertiary
                    }
                }
            }
        }

        GallerySection {
            title: "焦点管理"

            Column {
                spacing: 12

                TagInput {
                    id: focusTarget

                    objectName: "focusTarget"
                    width: 400
                    defaultValue: ["抖音", "火山"]
                }

                Button {
                    text: qsTr("点击按钮聚焦")
                    onClicked: focusTarget.focusInput()
                }
            }
        }

        GallerySection {
            title: "自定义标签渲染"

            TagInput {
                width: 400
                value: page.customTags
                renderTagItem: personChip
                onChange: (v) => page.customTags = v
            }
        }

        GallerySection {
            title: "拖拽排序"

            TagInput {
                width: 400
                draggable: true
                allowDuplicates: false
                defaultValue: ["抖音", "火山", "西瓜视频"]
                placeholder: qsTr("请输入...")
                onChange: (v) => console.log("onChange", JSON.stringify(v))
            }
        }
    }

    // 官方 renderTagItem(value, index, onClose) 的 QML 对应物：约定根项声明
    // modelData / index / closeTag，由 TagInput 注入
    Component {
        id: personChip

        Rectangle {
            id: chipRoot

            property var modelData
            property int index
            property var closeTag

            implicitWidth: chipRow.width + 16
            implicitHeight: 32
            width: implicitWidth
            height: 32
            radius: 12
            // 官方用 var(--semi-color-info-light-default) 当这枚 chip 的底
            color: Theme.current.colorInfoLightDefault

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: 8

                // 官方 size="extra-small"（$width-avatar-extra-small = 24），
                // Avatar 只做了三档，这里直接把边写成 24
                Avatar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    src: page.avatarOf(String(chipRoot.modelData))
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(chipRoot.modelData) + "@semi.com"
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "close"
                    size: Theme.current.widthIconSmall
                    color: Theme.current.colorText3

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: chipRoot.closeTag()
                    }
                }
            }
        }
    }

    Toast {
        id: maxToast
    }

    Toast {
        id: lengthToast
    }
}
