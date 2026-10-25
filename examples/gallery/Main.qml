import QtQuick
import QtQuick.Layouts
import Semi

Window {
    id: window

    property int clickCount: 0

    width: 760
    height: 760
    visible: true
    title: qsTr("Semi Gallery")
    color: Theme.current.colorBg0

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + Theme.current.spacingExtraLoose * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: content
            x: Theme.current.spacingExtraLoose
            y: Theme.current.spacingExtraLoose
            width: flickable.width - Theme.current.spacingExtraLoose * 2
            spacing: Theme.current.spacingLoose

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.current.spacingBaseTight

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Semi QML")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeHeader5
                    font.weight: Font.DemiBold
                }

                Button {
                    text: Theme.mode === Theme.Dark ? qsTr("浅色主题") : qsTr("深色主题")
                    onClicked: Theme.mode = Theme.mode === Theme.Dark ? Theme.Light : Theme.Dark
                }
            }

            // ---- 主题定制 ----
            Card {
                Layout.fillWidth: true

                Text {
                    text: qsTr("主题定制")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                }

                Text {
                    text: qsTr("customize() 只覆盖写出来的令牌，其余继承 Semi 默认值。")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                RowLayout {
                    spacing: Theme.current.spacingTight

                    Button {
                        text: qsTr("Semi 默认")
                        onClicked: Theme.reset()
                    }

                    Button {
                        text: qsTr("紫色品牌")
                        onClicked: Theme.customize({ colorPrimary: "#7c3aed" })
                    }

                    Button {
                        text: qsTr("绿色品牌")
                        onClicked: Theme.customize({ colorPrimary: "#0f9d58" })
                    }

                    Button {
                        text: qsTr("橙色危险色")
                        onClicked: Theme.customize({ colorDanger: "#fc8800" })
                    }

                    Button {
                        text: qsTr("大圆角")
                        onClicked: Theme.customize({ radiusSmall: 12, radiusMedium: 14, radiusLarge: 18 })
                    }
                }

                Text {
                    text: qsTr("当前主色 %1　危险色 %2　圆角 %3")
                        .arg(Theme.current.colorPrimary)
                        .arg(Theme.current.colorDanger)
                        .arg(Theme.current.radiusSmall)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }

            // ---- 色阶 ----
            Card {
                Layout.fillWidth: true

                Text {
                    text: qsTr("色阶（16 色系 × 10 级，语义色由它派生）")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: ["blue", "red", "green", "orange", "purple", "grey"]

                    delegate: RowLayout {
                        id: scaleRow

                        required property string modelData

                        Layout.fillWidth: true
                        spacing: Theme.current.spacingTight

                        Text {
                            Layout.preferredWidth: 56
                            text: scaleRow.modelData
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        Row {
                            Layout.fillWidth: true
                            spacing: 2

                            Repeater {
                                model: Theme.current[scaleRow.modelData]

                                delegate: Rectangle {
                                    required property color modelData

                                    width: 46
                                    height: 26
                                    radius: Theme.current.radiusExtraSmall
                                    color: modelData
                                }
                            }
                        }
                    }
                }
            }

            // ---- 表单 ----
            Card {
                Layout.fillWidth: true

                // 卡片本体没有内部间距（官方 -body 只有那 20 的内边距），
                // 段与段之间这 12 由调用方自己包一层 Column。
                Column {
                    width: parent.width
                    spacing: Theme.current.spacingBaseTight

                    Text {
                        text: qsTr("Input")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    Input {
                        Layout.fillWidth: true
                        placeholderText: qsTr("请输入内容")
                        prefixIcon: "search"
                    }

                    Input {
                        Layout.fillWidth: true
                        text: qsTr("可清空")
                        showClear: true
                    }

                    Input {
                        Layout.fillWidth: true
                        text: qsTr("非法值")
                        validateStatus: Enums.StatusDanger
                    }

                    Input {
                        Layout.fillWidth: true
                        text: qsTr("禁用")
                        enabled: false
                    }

                    Text {
                        text: qsTr("Checkbox / Radio / Switch")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        spacing: Theme.current.spacingLoose

                        ColumnLayout {
                            spacing: Theme.current.spacingTight

                            Checkbox { text: qsTr("已选中"); checked: true }
                            Checkbox { text: qsTr("未选中") }
                            Checkbox { text: qsTr("半选"); indeterminate: true }
                            Checkbox { text: qsTr("禁用"); checked: true; enabled: false }
                        }

                        ColumnLayout {
                            spacing: Theme.current.spacingTight

                            Radio { text: qsTr("选项一"); checked: true }
                            Radio { text: qsTr("选项二") }
                            Radio { text: qsTr("禁用"); enabled: false }
                        }

                        ColumnLayout {
                            spacing: Theme.current.spacingTight

                            Switch { checked: true }
                            Switch { }
                            Switch { checked: true; enabled: false }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ---- 标签与排版 ----
            Card {
                Layout.fillWidth: true

                // 卡片本体没有内部间距（官方 -body 只有那 20 的内边距），
                // 段与段之间这 12 由调用方自己包一层 Column。
                Column {
                    width: parent.width
                    spacing: Theme.current.spacingBaseTight

                    Text {
                        text: qsTr("Tag")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.current.spacingTight

                        Tag { text: qsTr("默认") }
                        Tag { text: qsTr("主色"); color: "blue" }
                        Tag { text: qsTr("成功"); color: "green" }
                        Tag { text: qsTr("警告"); color: "orange" }
                        Tag { text: qsTr("危险"); color: "red" }
                        Tag { text: qsTr("可关闭"); color: "blue"; closable: true }
                        Tag { text: qsTr("胶囊"); shape: "circle"; color: "violet" }
                        Tag { text: qsTr("大尺寸"); size: "large"; color: "green" }
                    }

                    Divider { Layout.fillWidth: true }
                    Divider { Layout.fillWidth: true; text: qsTr("或者") }

                    Text {
                        text: qsTr("TextArea")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    TextArea {
                        Layout.fillWidth: true
                        placeholderText: qsTr("多行输入，固定高度")
                    }

                    TextArea {
                        Layout.fillWidth: true
                        autosize: true
                        text: qsTr("autosize 时高度跟着内容走")
                    }

                    Text {
                        text: qsTr("Space 与 Divider")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.current.spacingTight

                        Tag { text: qsTr("标签") }
                        Tag { text: qsTr("另一个"); color: "blue" }

                        Item {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 20
                            Divider { anchors.fill: parent; vertical: true }
                        }

                        Tag { text: qsTr("分割线后面"); color: "green" }
                        Item { Layout.fillWidth: true }

                        Space {
                            Button { text: qsTr("取消") }
                            Button { text: qsTr("确定"); tone: Enums.Primary }
                        }
                    }
                }
            }

            // ---- 组件 ----
            Card {
                Layout.fillWidth: true

                // 卡片本体没有内部间距（官方 -body 只有那 20 的内边距），
                // 段与段之间这 12 由调用方自己包一层 Column。
                Column {
                    width: parent.width
                    spacing: Theme.current.spacingBaseTight

                    Text {
                        text: qsTr("Button · 带图标 / 图标按钮")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.current.spacingTight

                        Button { text: qsTr("新建"); icon: "plus" }
                        Button { text: qsTr("删除"); icon: "delete"; tone: Enums.Danger }
                        Button { text: qsTr("更多"); icon: "chevron_down"; variant: Enums.Outline }
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.current.spacingTight

                        ButtonGroup {
                            Button { text: qsTr("左") }
                            Button { text: qsTr("中") }
                            Button { text: qsTr("右") }
                        }

                        ButtonGroup {
                            Button { text: qsTr("复制"); icon: "copy"; variant: Enums.Outline }
                            Button { text: qsTr("粘贴"); icon: "plus"; variant: Enums.Outline }
                        }

                        SplitButtonGroup {
                            Button { text: qsTr("部署"); variant: Enums.Solid }
                            Button { icon: "tree_triangle_down"; variant: Enums.Solid }
                        }

                        SplitButtonGroup {
                            Button { text: qsTr("导出"); icon: "download" }
                            Button { icon: "tree_triangle_down" }
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.current.spacingTight

                        IconButton { icon: "plus"; tone: Enums.Primary }
                        IconButton { icon: "search" }
                        IconButton { icon: "copy" }
                        IconButton { icon: "edit" }
                        IconButton { icon: "delete"; tone: Enums.Danger }
                        IconButton { icon: "setting"; variant: Enums.Outline }
                        IconButton { icon: "close"; enabled: false }
                        IconButton { icon: "plus"; size: Enums.Small }
                        IconButton { icon: "plus"; size: Enums.Large }
                    }

                    Text {
                        text: qsTr("图标（523 个，按 alpha 着色，跟随主题）")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.current.spacingBaseTight

                        Repeater {
                            model: ["plus", "close", "search", "checkbox_tick", "delete", "star",
                                    "like_heart", "copy", "edit", "setting", "chevron_down",
                                    "chevron_right", "refresh", "download", "upload", "info_circle"]

                            delegate: Icon {
                                required property string modelData

                                name: modelData
                                size: 20
                                color: Theme.current.colorText1
                            }
                        }
                    }

                    Text {
                        text: qsTr("Button · 色调")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.current.spacingTight

                        Button { text: qsTr("主要"); tone: Enums.Primary; onClicked: window.clickCount++ }
                        Button { text: qsTr("次要"); tone: Enums.Secondary; onClicked: window.clickCount++ }
                        Button { text: qsTr("第三"); tone: Enums.Tertiary; onClicked: window.clickCount++ }
                        Button { text: qsTr("警告"); tone: Enums.Warning; onClicked: window.clickCount++ }
                        Button { text: qsTr("危险"); tone: Enums.Danger; onClicked: window.clickCount++ }
                        Button { text: qsTr("禁用"); enabled: false }
                    }

                    Text {
                        text: qsTr("Button · 形态")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.current.spacingTight

                        Button { text: qsTr("Solid"); variant: Enums.Solid }
                        Button { text: qsTr("Light"); variant: Enums.Light }
                        Button { text: qsTr("Outline"); variant: Enums.Outline }
                        Button { text: qsTr("Borderless"); variant: Enums.Borderless }
                    }

                    Text {
                        text: qsTr("Button · 尺寸")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.DemiBold
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.current.spacingTight

                        Button { text: qsTr("小"); size: Enums.Small }
                        Button { text: qsTr("默认"); size: Enums.Default }
                        Button { text: qsTr("大"); size: Enums.Large }
                    }

                    Text {
                        text: qsTr("已点击 %1 次　按 Tab 聚焦 —— 只有键盘操作才出现焦点环").arg(window.clickCount)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }
            }

            Card {
                Layout.fillWidth: true

                Text {
                    text: qsTr("Switch")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    spacing: Theme.current.spacingBaseTight

                    Switch {
                        id: switchA
                        checked: true
                    }

                    Switch {
                        id: switchB
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: qsTr("A：%1　B：%2").arg(switchA.checked).arg(switchB.checked)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("令牌清单见 gallery 的 Tokens 页；生成脚本 scripts/gen-theme-tokens.py")
                color: Theme.current.colorText3
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }
}
