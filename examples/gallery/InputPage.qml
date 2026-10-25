pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Input / TextArea / InputGroup 的官方示例集。小节标题与 examples/gallery/data/docs.json
// 里从官网文档抓的标题一一对应，说明文字由 GalleryShell 按标题取，这里只写 demo。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property string controlledText: ""
    property string compositionValue: ""
    property int compositionEvents: 0
    property string compositionAreaValue: ""
    property int compositionAreaEvents: 0
    property string maxLengthValue: ""

    // 官方 demo 用 grapheme-splitter 把 emoji 按「可见字符」计数。QML 侧没有这个库，
    // 这里按码点计数：💖 算 1，但 👨‍👩‍‍（4 个 emoji + 3 个零宽连接符）算 7。
    function codePointLength(s) {
        const text = String(s);
        let n = 0;
        for (let i = 0; i < text.length; ++i) {
            const c = text.charCodeAt(i);
            if (c >= 0xD800 && c <= 0xDBFF)
                ++i;
            ++n;
        }
        return n;
    }

    // TextArea 那一格：去掉所有空白后计数（官方 demo 的 getTextAreaStrLength）
    function noSpaceLength(s) {
        return String(s).replace(/\s/g, "").length;
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 420
                text: "import Semi\n\nInput { }\nTextArea { }\nInputGroup { }"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "基本"

            Input {
                width: 320
                text: "hi"
            }
        }

        GallerySection {
            title: "三种大小"

            Column {
                spacing: 16

                Input { width: 320; size: Enums.Large; placeholderText: qsTr("large") }
                Input { width: 320; placeholderText: qsTr("default") }
                Input { width: 320; size: Enums.Small; placeholderText: qsTr("small") }
            }
        }

        GallerySection {
            title: "不可用"

            Column {
                spacing: 16

                Input { width: 320; text: qsTr("enabled input") }
                Input { width: 320; enabled: false; text: qsTr("disabled input") }
            }
        }

        GallerySection {
            title: "前缀/后缀"

            Column {
                spacing: 16

                Input { width: 320; prefixIcon: "search"; showClear: true }

                Input { width: 320; prefix: "Prefix"; showClear: true }

                Input { width: 320; suffixIcon: "search"; showClear: true }

                // 官方这一格传的是 <Typography.Text strong type="secondary"
                // style={{marginRight: 8}}>，自定义节点左右间距为 0，那 8 是节点自己带的
                Input {
                    width: 320
                    showClear: true
                    suffix: Component {
                        Text {
                            text: qsTr("Suffix")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeRegular
                            font.weight: Font.DemiBold
                            rightPadding: Theme.current.spacingTight
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "前置/后置标签"

            Input {
                width: 320
                addonBefore: "http://"
                addonAfter: ".com"
            }
        }

        GallerySection {
            title: "带移除图标"

            Input {
                width: 320
                showClear: true
                text: qsTr("click to clear")
            }
        }

        GallerySection {
            title: "密码模式"

            Input {
                width: 320
                mode: "password"
                text: "123456"
            }
        }

        GallerySection {
            title: "校验状态"

            Column {
                spacing: 16

                Input { width: 320; text: "ies"; validateStatus: Enums.StatusWarning }
                Input { width: 320; text: "ies"; validateStatus: Enums.StatusDanger }
                Input { width: 320; text: "ies" }
            }
        }

        GallerySection {
            title: "受控组件"

            Column {
                spacing: 12

                Input {
                    width: 320
                    text: page.controlledText
                    onTextChanged: page.controlledText = text
                }

                Text {
                    text: qsTr("onChange 收到的值：%1").arg(page.controlledText)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "输入框组合"

            Column {
                spacing: 24

                InputGroup {
                    Input { width: 100; placeholderText: "Name" }
                    InputNumber { width: 140 }
                }

                InputGroup {
                    size: Enums.Small
                    Select {
                        width: 100
                        value: "home"
                        options: [{ label: "Home", value: "home" }, { label: "Work", value: "work" }]
                    }
                    AutoComplete {
                        width: 180
                        dataList: ["Beijing Haidian"]
                        placeholderText: "Address: "
                    }
                }

                InputGroup {
                    size: Enums.Small
                    Select {
                        width: 100
                        value: "signup"
                        options: [{ label: "Sign Up", value: "signup" }, { label: "Sign In", value: "signin" }]
                    }
                    Input { width: 180; placeholderText: "Email" }
                }

                InputGroup {
                    size: Enums.Small
                    Input { width: 100; placeholderText: "Name" }
                    DatePicker { width: 180; placeholder: "Birthday" }
                }

                InputGroup {
                    Select {
                        width: 100
                        value: "from"
                        options: [{ label: "From: ", value: "from" }, { label: "To: ", value: "to" }]
                    }
                    TreeSelect {
                        width: 220
                        placeholder: "Please select"
                        treeData: [
                            {
                                label: "Asia",
                                value: "Asia",
                                children: [{
                                    label: "China",
                                    value: "China",
                                    children: [
                                        { label: "Beijing", value: "Beijing" },
                                        { label: "Shanghai", value: "Shanghai" }
                                    ]
                                }]
                            },
                            { label: "North America", value: "North America" }
                        ]
                    }
                }

                InputGroup {
                    Select {
                        width: 100
                        value: "from"
                        options: [{ label: "From: ", value: "from" }, { label: "To: ", value: "to" }]
                    }
                    Cascader {
                        width: 220
                        placeholder: "Please select"
                        options: [
                            {
                                label: "Asia",
                                value: "Asia",
                                children: [{
                                    label: "China",
                                    value: "China",
                                    children: [
                                        { label: "Beijing", value: "Beijing" },
                                        { label: "Shanghai", value: "Shanghai" }
                                    ]
                                }]
                            },
                            { label: "North America", value: "North America" }
                        ]
                    }
                }
            }
        }

        GallerySection {
            title: "多行输入框"

            Column {
                spacing: 16

                TextArea { width: 320 }
                TextArea { width: 320; maxCount: 100; showClear: true }
            }
        }

        GallerySection {
            title: "设置 TextArea 高度"

            Column {
                spacing: 16

                TextArea { width: 320; textareaHeight: 120; placeholderText: qsTr("高度 120px") }
                TextArea { width: 320; textareaHeight: 200; placeholderText: qsTr("高度 200px") }
                TextArea { width: 320; textareaHeight: 150; placeholderText: qsTr("高度 150px") }
            }
        }

        GallerySection {
            title: "行号"

            TextArea {
                width: 420
                rows: 8
                showLineNumber: true
                lineNumberStart: 1
                text: "Line 1\nLine 2\n这是一行较长的文本，用来演示软换行时的行号对齐效果。\nLine 4\nLine 5"
            }
        }

        GallerySection {
            title: "使用 Shift + Enter 换行的多行输入框"

            Column {
                spacing: 12

                Text {
                    text: qsTr("使用 Shift + Enter 换行的 TextArea")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                TextArea {
                    width: 320
                    rows: 4

                    // 官方在 onKeyDown 里对不带 Shift 的 Enter 调 preventDefault；
                    // TextArea 的 keyPressed 就是那条回调的等价物
                    onKeyPressed: (event) => {
                        if (!(event.modifiers & Qt.ShiftModifier))
                            event.accepted = true;
                    }
                }
            }
        }

        GallerySection {
            title: "自动扩展的多行输入框"

            Column {
                spacing: 16

                TextArea {
                    id: autoOne

                    width: 320
                    rows: 1
                    autosize: true
                }

                TextArea {
                    id: autoRange

                    width: 320
                    autosize: ({ minRows: 1, maxRows: 3 })
                }

                TextArea {
                    id: autoCount

                    width: 320
                    autosize: true
                    maxCount: 100
                }

                Row {
                    spacing: 8

                    Button {
                        text: qsTr("第一组加一行")
                        onClicked: autoOne.text += "追加的一行\n"
                    }

                    Button {
                        text: qsTr("第二组加一行")
                        onClicked: autoRange.text += "追加的一行\n"
                    }

                    Button {
                        text: qsTr("第三组加一行")
                        onClicked: autoCount.text += "追加的一行\n"
                    }
                }
            }
        }

        GallerySection {
            title: "自定义计算字符串长度"

            Column {
                spacing: 12

                Text {
                    text: qsTr("maxLength=10，emoji 按码点计数（官方 demo 用 grapheme-splitter 按可见字符计）")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Input {
                    width: 200
                    maxLength: 10
                    getValueLength: (s) => page.codePointLength(s)
                    onTextChanged: page.maxLengthValue = text
                }

                Text {
                    visible: page.maxLengthValue !== ""
                    text: qsTr("getValueLength=%1    length=%2")
                        .arg(page.codePointLength(page.maxLengthValue))
                        .arg(page.maxLengthValue.length)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Text {
                    topPadding: Theme.current.spacingBaseTight
                    text: qsTr("maxCount=10，去掉空白后计数")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                TextArea {
                    width: 200
                    rows: 2
                    maxCount: 10
                    getValueLength: (s) => page.noSpaceLength(s)
                    text: "semi design"
                }
            }
        }

        GallerySection {
            title: "输入法模式"

            Column {
                spacing: 16

                Column {
                    spacing: 8

                    Input {
                        width: 300
                        composition: true
                        placeholderText: qsTr("开启 composition，拼音输入时不会触发 onChange")
                        text: page.compositionValue
                        onTextChanged: {
                            page.compositionValue = text;
                            page.compositionEvents += 1;
                        }
                    }

                    Text {
                        text: qsTr("onChange 触发次数: %1").arg(page.compositionEvents)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }

                Column {
                    spacing: 8

                    TextArea {
                        width: 300
                        composition: true
                        placeholderText: qsTr("开启 composition，拼音输入时不会触发 onChange")
                        text: page.compositionAreaValue
                        onTextChanged: {
                            page.compositionAreaValue = text;
                            page.compositionAreaEvents += 1;
                        }
                    }

                    Text {
                        text: qsTr("onChange 触发次数: %1").arg(page.compositionAreaEvents)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }
            }
        }
    }
}
