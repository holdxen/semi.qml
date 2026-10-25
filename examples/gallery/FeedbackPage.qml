pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/feedback/feedback/index.md 的 8 个演示小节，标题逐字取自 data/docs.json。
//
// 官方每节都是一个「Button + 一个 Feedback」，visible 由 demo 自己管（onOk / onCancel 里
// setVisible(false)），这里同一套：page 上开一堆开关，Feedback 只负责回调。
// 官方的 textAreaProps / radioGroupProps / checkboxGroupProps / okButtonProps 在组件侧摊平成
// 显式属性（见 src/Feedback.qml 文件头），demo 里也就写摊平后的样子。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 每节一个开关，对应官方 demo 里的 useState(false)
    property bool showEmoji: false
    property bool showText: false
    property bool showRadio: false
    property bool showCheckbox: false
    property bool showCustom: false
    property bool showModal: false
    property bool showThanksPopup: false
    property bool showThanksModal: false

    // 官方用 console.log 展示 onValueChange，这里落到页面上，截图也看得见
    property string lastEmojiValue: ""
    property string customPopupText: ""
    property string customModalText: ""
    // 「反馈完成提示」：提交后先换成感谢页，1500ms 再关、关掉后再把内容换回来
    property bool thanksPopup: false
    property bool thanksModal: false

    component Note: Text {
        width: 560
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    function describe(v) {
        if (v === null || v === undefined)
            return "（空）";
        if (v.emoji !== undefined)
            return "{ emoji: " + v.emoji + (v.text !== undefined ? ", text: " + v.text : "") + " }";
        if (v.length !== undefined && typeof v !== "string")
            return "[ " + String(v) + " ]";
        return String(v);
    }

    Timer {
        id: thanksPopupReset

        interval: 1500
        onTriggered: {
            page.showThanksPopup = false;
            page.thanksPopup = false;
        }
    }

    Timer {
        id: thanksModalReset

        interval: 1500
        onTriggered: {
            page.showThanksModal = false;
            page.thanksModal = false;
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 460
                text: "import Semi\n\nFeedback {\n    title: \"您对本产品的评分是？\"\n    visible: page.showEmoji\n    type: \"emoji\"\n    onValueChange: console.log(value)\n    onOk: page.showEmoji = false\n    onCancel: page.showEmoji = false\n}"
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
                width: 560
                spacing: 12

                Button {
                    text: qsTr("展示反馈: Popup, emoji")
                    onClicked: page.showEmoji = !page.showEmoji
                }

                Note {
                    text: qsTr("当前 value：%1").arg(page.lastEmojiValue === ""
                        ? qsTr("（还没选）") : page.lastEmojiValue)
                }
            }

            Feedback {
                id: emojiFeedback

                title: qsTr("您对本产品的评分是？")
                visible: page.showEmoji
                onValueChange: function (value) {
                    page.lastEmojiValue = page.describe(value)
                }
                onOk: page.showEmoji = false
                onCancel: page.showEmoji = false
            }

            Note {
                text: qsTr("三枚表情默认是灰的（官方 filter: grayscale(100%)），悬停或点中才上色。"
                    + "点 😞 会多出一栏补充说明，此时 value 是 { emoji, text }；"
                    + "换一枚 emoji 会把 text 整个丢掉（官方就是拿新对象替换 value）。")
            }
        }

        GallerySection {
            title: "文字类型"

            Button {
                text: qsTr("展示反馈: Popup, text")
                onClicked: page.showText = !page.showText
            }

            Feedback {
                id: textFeedback

                type: "text"
                textAreaMaxCount: 200
                title: qsTr("您对本产品的建议是？")
                visible: page.showText
                onOk: page.showText = false
                onCancel: page.showText = false
            }

            Note {
                text: qsTr("这一支的卡片宽是 600（$width-feedback_text），其余类型都是 400。")
            }
        }

        GallerySection {
            title: "单选反馈"

            Button {
                text: qsTr("展示反馈: Popup, radio")
                onClicked: page.showRadio = !page.showRadio
            }

            Feedback {
                id: radioFeedback

                type: "radio"
                radioOptions: [qsTr("访客"), qsTr("开发者"), qsTr("维护者")]
                title: qsTr("您的身份是")
                visible: page.showRadio
                onOk: page.showRadio = false
                onCancel: page.showRadio = false
            }
        }

        GallerySection {
            title: "多选反馈"

            Button {
                text: qsTr("展示反馈: Popup, checkbox")
                onClicked: page.showCheckbox = !page.showCheckbox
            }

            Feedback {
                id: checkboxFeedback

                type: "checkbox"
                checkboxOptions: [qsTr("抖音"), qsTr("火山"), qsTr("豆包")]
                title: qsTr("您最常使用以下哪些产品？")
                visible: page.showCheckbox
                onOk: page.showCheckbox = false
                onCancel: page.showCheckbox = false
            }

            Note {
                text: qsTr("竖排多选的行距是 16（$spacing-feedback_checkbox_group_vertical-rowGap），"
                    + "比 CheckboxGroup 自己的 12 宽一档。")
            }
        }

        GallerySection {
            title: "自定义反馈内容"

            Button {
                text: qsTr("展示反馈: Popup, custom")
                onClicked: page.showCustom = !page.showCustom
            }

            Feedback {
                id: customFeedback

                type: "custom"
                title: qsTr("您对本产品的建议是？")
                visible: page.showCustom
                // 官方：自定义那一支组件自己不维护 value，提交键的禁用要调用方接管
                okButtonDisabled: page.customPopupText === ""
                onOk: {
                    page.showCustom = false;
                    page.customPopupText = "";
                }
                onCancel: {
                    page.showCustom = false;
                    page.customPopupText = "";
                }

                Column {
                    width: page.width > 0 ? 352 : 352
                    spacing: 12

                    Text {
                        width: parent.width
                        text: qsTr("这是一段自定义的内容")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    TextArea {
                        width: parent.width
                        placeholderText: qsTr("写点什么")
                        onTextChanged: page.customPopupText = text
                    }
                }
            }
        }

        GallerySection {
            title: "模态对话框形式"

            Button {
                text: qsTr("展示反馈: Modal, emoji")
                onClicked: page.showModal = !page.showModal
            }

            Feedback {
                id: modalFeedback

                mode: "modal"
                title: "Why did you choose this rating?"
                visible: page.showModal
                onOk: page.showModal = false
                onCancel: page.showModal = false
            }

            Note {
                text: qsTr("mode 换成 modal 之后就有遮罩了（popup 那支官方写死 mask={false}），"
                    + "卡片居中、宽 400，进场动效也从 SideSheet 的平移换成 Modal 的缩放淡入。")
            }
        }

        GallerySection {
            title: "反馈完成提示"

            Column {
                width: 560
                spacing: 16

                Button {
                    text: qsTr("Open Feedback: Popup, Custom")
                    onClicked: page.showThanksPopup = !page.showThanksPopup
                }

                Button {
                    text: qsTr("Open Feedback: Modal, Custom")
                    onClicked: page.showThanksModal = !page.showThanksModal
                }
            }

            Feedback {
                id: thanksPopupFeedback

                type: "custom"
                title: page.thanksPopup ? " " : qsTr("What is your feedback on this product?")
                showFooter: !page.thanksPopup
                visible: page.showThanksPopup
                okButtonDisabled: page.customPopupText === ""
                onOk: {
                    page.thanksPopup = true;
                    thanksPopupReset.start();
                }
                onCancel: {
                    page.showThanksPopup = false;
                    page.customPopupText = "";
                }

                Column {
                    visible: !page.thanksPopup
                    width: 352
                    spacing: 12

                    Text {
                        width: parent.width
                        text: qsTr("这是一段自定义的内容")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    TextArea {
                        width: parent.width
                        placeholderText: qsTr("写点什么")
                        onTextChanged: page.customPopupText = text
                    }
                }

                Empty {
                    visible: page.thanksPopup
                    width: 352
                    description: qsTr("感谢您的反馈")
                }
            }

            Feedback {
                id: thanksModalFeedback

                type: "custom"
                mode: "modal"
                title: page.thanksModal ? " " : qsTr("What is your feedback on this product?")
                showFooter: !page.thanksModal
                visible: page.showThanksModal
                okButtonDisabled: page.customModalText === ""
                onOk: {
                    page.thanksModal = true;
                    thanksModalReset.start();
                }
                onCancel: {
                    page.showThanksModal = false;
                    page.customModalText = "";
                }

                Column {
                    visible: !page.thanksModal
                    width: 352
                    spacing: 12

                    Text {
                        width: parent.width
                        text: qsTr("这是一段自定义的内容")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    TextArea {
                        width: parent.width
                        placeholderText: qsTr("写点什么")
                        onTextChanged: page.customModalText = text
                    }
                }

                Empty {
                    visible: !page.thanksModal ? false : true
                    width: 352
                    description: qsTr("感谢您的反馈")
                }
            }

            Note {
                text: qsTr("官方是拿 renderContent 在「表单」与「感谢页」之间换，QML 侧就是换子项的 "
                    + "visible；标题换成一个空格、footer 收掉（官方是 title=' ' 与 footer=null）。")
            }
        }

    }

}
