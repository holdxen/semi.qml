pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/plus/chat/index.md 的 9 个演示小节，标题逐字取自 data/docs.json。
//
// Chat 是**全受控**组件（chats 只读、变更走 onChatsChange），所以每节的 demo 都
// 自己维护一份 message 数组并接回 onChatsChange —— 这与官方 demo 的 useState 一致。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方 roleInfo（三个 demo 共用同一份）
    readonly property var roleInfo: ({
        user: {
            name: "User",
            avatar: "qrc:/qt/qml/SemiGallery/data/img/sample1.png"
        },
        assistant: {
            name: "Assistant",
            avatar: "qrc:/qt/qml/SemiGallery/data/img/sample2.png"
        },
        system: {
            name: "System",
            avatar: "qrc:/qt/qml/SemiGallery/data/img/sample2.png"
        }
    })

    // ---- 基本用法节的受控模型 ----
    property var basicChats: [
        { role: "system", id: "1", createAt: 1715676751919, content: "你好，我是你的 AI 助手。" },
        { role: "user", id: "2", createAt: 1715676751919, content: "给一个 Semi Design 的 Button 组件的使用示例" },
        {
            role: "assistant", id: "3", createAt: 1715676751919,
            content: "以下是一个 Semi Button 的使用示例：\n\n```jsx\nimport React from 'react';\nimport { Button } from '@douyinfe/semi-ui';\n\nconst Demo = () => {\n  return <Button theme=\"solid\">主要按钮</Button>;\n};\n```"
        }
    ]
    property string basicMode: "bubble"
    property string basicAlign: "leftRight"
    property int nextId: 100

    function getId() {
        page.nextId += 1;
        return "id-" + page.nextId;
    }

    // ---- 消息状态节 ----
    property var statusChats: [
        { role: "assistant", id: "s1", content: "请求成功" },
        { id: "loading", role: "assistant", status: "loading" },
        { role: "assistant", id: "s2", content: "请求错误", status: "error" }
    ]

    // ---- 动态更新数据节（流式）----
    property var streamChats: [
        { role: "user", id: "m2", createAt: 1715676751919, content: "介绍一下 Semi Design" },
        {
            role: "assistant", id: "m3", createAt: 1715676751919, status: "complete",
            content: "Semi Design 是由抖音前端团队和 MED 产品设计团队设计、开发并维护的设计系统，"
                + "目前已经支撑了近千个平台产品。特点包括：\n\n"
                + "1. 设计简洁、现代化\n2. 提供主题方案，可深度样式定制\n3. 提供明暗两套模式"
        }
    ]
    property string streamPending: ""
    property bool streamRunning: false

    // ---- 清除上下文节 ----
    property var clearChats: [
        { role: "user", id: "c1", content: "介绍一下 semi design" },
        { role: "assistant", id: "c2", content: "Semi Design 是由抖音前端团队和 MED 产品设计团队维护的设计系统" }
    ]

    // ---- 自定义渲染会话框节 ----
    property var customChats: [
        { role: "user", id: "k1", content: "这两条消息的头像和标题是自定义的" },
        { role: "assistant", id: "k2", content: "操作区也换成了自定义渲染" }
    ]

    // ---- 自定义渲染输入框节 ----
    property var inputChats: [
        { role: "system", id: "i1", content: "试试下面这个不像聊天框的输入区" }
    ]

    // ---- 提示信息节 ----
    property var hintChats: [
        {
            role: "assistant", id: "h1",
            content: "Semi Design 是由抖音前端团队和 MED 产品设计团队设计、开发并维护的设计系统，你可以向我提问任何关于 Semi 的问题。"
        }
    ]
    property var hints: ["告诉我更多", "Semi Design 的组件有哪些？", "我能够通过 DSM 定制自己的主题吗？"]

    component Note: Text {
        width: 560
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    // 官方 demo 外壳：1px 边框 + 16 圆角 + 固定高
    component Stage: Rectangle {
        radius: Theme.current.radiusMedium
        color: Theme.current.colorBg0
        border.width: 1
        border.color: Theme.current.colorBorder
        clip: true
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        // ================================================================ 如何引入
        GallerySection {
            title: "如何引入"

            Note {
                text: qsTr("Chat 从 v2.63.0 版本开始支持。")
            }
            Note {
                width: 560
                text: qsTr("对话内容渲染基于 MarkdownRender 组件，本库用 Qt 内建的 "
                    + "Text.MarkdownText 承接（MarkdownRender 本体仍未实现）。"
                    + "附件支持点击上传；粘贴上传与拖拽上传需要操作系统剪贴板/拖放通道，QML 侧没有入口，未实现。")
            }
        }

        // ================================================================ 基本用法
        GallerySection {
            title: "基本用法"

            Column {
                spacing: Theme.current.spacingBase

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("模式")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    RadioGroup {
                        value: page.basicMode
                        onChanged: (v) => page.basicMode = v

                        Radio { value: "bubble"; text: qsTr("气泡") }
                        Radio { value: "noBubble"; text: qsTr("非气泡") }
                        Radio { value: "userBubble"; text: qsTr("用户会话气泡") }
                    }
                }

                Row {
                    spacing: Theme.current.spacingBaseTight

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("会话布局方式")
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    RadioGroup {
                        value: page.basicAlign
                        onChanged: (v) => page.basicAlign = v

                        Radio { value: "leftRight"; text: qsTr("左右分布") }
                        Radio { value: "leftAlign"; text: qsTr("左对齐") }
                    }
                }

                Stage {
                    width: 640
                    height: 550

                    Chat {
                        anchors.fill: parent
                        anchors.margins: 1

                        align: page.basicAlign
                        mode: page.basicMode
                        chats: page.basicChats
                        roleConfig: page.roleInfo
                        uploadProps: ({ action: "https://api.semi.design/upload" })
                        uploadTipProps: ({ content: "自定义上传按钮提示信息" })

                        onChatsChange: (c) => page.basicChats = c
                        onMessageSend: (content, attachment) => {
                            const reply = {
                                role: "assistant",
                                id: page.getId(),
                                createAt: Date.now(),
                                content: "这是一条 mock 回复信息"
                            };
                            replyTimer.reply = reply;
                            replyTimer.restart();
                        }
                    }

                    // 官方 demo 用 setTimeout(200) 延迟追加 mock 回复
                    Timer {
                        id: replyTimer

                        property var reply

                        interval: 200
                        onTriggered: {
                            if (reply !== undefined && reply !== null)
                                page.basicChats = page.basicChats.concat([reply]);
                        }
                    }
                }
            }
        }

        // ================================================================ 消息状态
        GallerySection {
            title: "消息状态"

            Note {
                text: qsTr("chats 类型为 Message[]，status 不同则会话样式不同："
                    + "loading 是三个闪烁圆点、error 是红色气泡、complete 正常渲染。")
            }

            Stage {
                width: 640
                height: 400

                Chat {
                    anchors.fill: parent
                    anchors.margins: 1

                    chats: page.statusChats
                    roleConfig: page.roleInfo
                    placeholder: qsTr("输入消息…")

                    onChatsChange: (c) => page.statusChats = c
                    onMessageSend: () => {
                        const reply = {
                            role: "assistant", id: page.getId(),
                            createAt: Date.now(), content: "这是一条 mock 回复信息"
                        };
                        page.statusChats = page.statusChats.concat([reply]);
                    }
                }
            }
        }

        // ================================================================ 动态更新数据
        GallerySection {
            title: "动态更新数据"

            Note {
                text: qsTr("后台返回 SSE 数据时把增量塞进 chats 即可实时更新。")
                + qsTr("showStopGenerate 打开后，末条还在生成时会显示停止按钮并禁用发送。")
            }

            Stage {
                width: 640
                height: 600

                Chat {
                    anchors.fill: parent
                    anchors.margins: 1

                    chats: page.streamChats
                    roleConfig: page.roleInfo
                    showStopGenerate: true

                    onChatsChange: (c) => page.streamChats = c
                    onStopGenerator: {
                        streamTimer.stop();
                        const arr = page.streamChats.slice();
                        const last = arr[arr.length - 1];
                        arr[arr.length - 1] = Object.assign({}, last, { status: "complete" });
                        page.streamChats = arr;
                    }
                    onMessageSend: (content) => {
                        page.streamPending = content;
                        page.streamChats = page.streamChats.concat([
                            { role: "assistant", id: page.getId(), createAt: Date.now(), status: "loading" }
                        ]);
                        streamTimer.start();
                    }
                }

                // 官方 demo 用 setInterval(400) 往末条追加 mock 流式文本
                Timer {
                    id: streamTimer

                    interval: 400
                    repeat: true
                    onTriggered: {
                        const arr = page.streamChats.slice();
                        const last = arr[arr.length - 1];
                        if (last === undefined)
                            return;
                        if (last.status === "loading") {
                            arr[arr.length - 1] = Object.assign({}, last, {
                                content: "mock Response for " + page.streamPending + "\n",
                                status: "incomplete"
                            });
                        } else if (last.content.length > 200) {
                            arr[arr.length - 1] = Object.assign({}, last, {
                                content: last.content + " mock stream message",
                                status: "complete"
                            });
                            stop();
                        } else {
                            arr[arr.length - 1] = Object.assign({}, last, {
                                content: last.content + " mock stream message"
                            });
                        }
                        page.streamChats = arr;
                    }
                }
            }
        }

        // ================================================================ 清除上下文
        GallerySection {
            title: "清除上下文"

            Note {
                text: qsTr("showClearContext 在输入框里显示清除上下文按钮；")
                + qsTr("也可以调用 clearContext 方法。清除会在末尾追加一条「上下文已清除」分隔线。")
            }

            Stage {
                width: 640
                height: 550

                Chat {
                    anchors.fill: parent
                    anchors.margins: 1

                    chats: page.clearChats
                    roleConfig: page.roleInfo
                    showClearContext: true

                    onChatsChange: (c) => page.clearChats = c
                    onMessageSend: (content) => {
                        page.clearChats = page.clearChats.concat([
                            { role: "assistant", id: page.getId(), createAt: Date.now(), content: "这是一条 mock 回复信息" }
                        ]);
                    }
                }
            }
        }

        // ================================================================ 自定义渲染会话框
        GallerySection {
            title: "自定义渲染会话框"

            Note {
                text: qsTr("chatBoxRenderConfig 传入自定义渲染配置：renderChatBoxTitle / renderChatBoxAvatar / ")
                + qsTr("renderChatBoxContent / renderChatBoxAction / renderFullChatBox。QML 侧的槽是 Component，")
                + page.qsQuotedNote()
            }

            Stage {
                width: 640
                height: 400

                Chat {
                    anchors.fill: parent
                    anchors.margins: 1

                    chats: page.customChats
                    roleConfig: page.roleInfo
                    chatBoxRenderConfig: ({
                        renderChatBoxTitle: titleSlot,
                        renderChatBoxAvatar: avatarSlot
                    })

                    onChatsChange: (c) => page.customChats = c
                }

                // 自定义标题：名字 + 创建时间
                Component {
                    id: titleSlot

                    Item {
                        id: titleRoot

                        property var message
                        property var role
                        property var defaultTitle

                        width: titleRow.implicitWidth
                        height: 20

                        Row {
                            id: titleRow

                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.current.spacingTight

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: titleRoot.role !== undefined && titleRoot.role.name !== undefined
                                    ? titleRoot.role.name : ""
                                color: Theme.current.colorText0
                                font.pixelSize: Theme.current.fontSizeHeader6
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    const d = new Date(titleRoot.message !== undefined && titleRoot.message.createAt !== undefined
                                        ? titleRoot.message.createAt : 0);
                                    const pad = function (n) { return ("0" + n).slice(-2); };
                                    return pad(d.getHours()) + ":" + pad(d.getMinutes());
                                }
                                color: Theme.current.colorText2
                                font.pixelSize: Theme.current.fontSizeSmall
                            }
                        }
                    }
                }

                // 自定义头像：方形 + 角色名首字母
                Component {
                    id: avatarSlot

                    Item {
                        id: avatarRoot

                        property var message
                        property var role
                        property var defaultAvatar

                        width: 24
                        height: 24

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: Theme.current.colorPrimary

                            Text {
                                anchors.centerIn: parent
                                text: avatarRoot.role !== undefined && avatarRoot.role.name !== undefined
                                    ? avatarRoot.role.name.charAt(0) : ""
                                color: Theme.current.colorWhite
                                font.pixelSize: Theme.current.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }

        // ================================================================ 自定义渲染输入框
        GallerySection {
            title: "自定义渲染输入框"

            Note {
                text: qsTr("renderInputArea 整块替换输入区。QML 的 Component 通过 onSend / onClear / ")
                + qsTr("onClick 三个函数属性接回发送、清除上下文与聚焦（官方 renderInputArea props 同名）。")
            }

            Stage {
                width: 640
                height: 320

                Chat {
                    anchors.fill: parent
                    anchors.margins: 1

                    chats: page.inputChats
                    roleConfig: page.roleInfo
                    renderInputArea: customInput

                    onChatsChange: (c) => page.inputChats = c
                    onMessageSend: (content) => {
                        page.inputChats = page.inputChats.concat([
                            { role: "assistant", id: page.getId(), createAt: Date.now(), content: "这是一条 mock 回复信息" }
                        ]);
                    }
                }

                Component {
                    id: customInput

                    Rectangle {
                        id: customRoot

                        // 注入契约 = 官方 renderInputArea props：onSend / onClear /
                        // onClick / defaultNode（ChatInputBox onLoaded 按这些名字注入）
                        property var onSend
                        property var onClear
                        property var onClick
                        property var defaultNode

                        // 绑 implicitHeight 而不是 height：宿主高度链读的是
                        // ChatInputBox.implicitHeight ← 槽的 implicitHeight；
                        // Loader 还会把显式 height 覆盖成自身尺寸（绑了也白绑）
                        implicitHeight: customCol.height + 32
                        color: Theme.current.colorFill0
                        radius: Theme.current.radiusMedium

                        // 这里不挂整区 TapHandler 做「点空白聚焦」：祖先级 TapHandler
                        // 会干扰子级 Button 的点击（实测 onPressedChanged 抢了 grab、
                        // 钮的 clicked 不发）。TextArea 自身可点可打，聚焦入口够用。

                        Column {
                            id: customCol

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: Theme.current.spacingBaseTight

                            Text {
                                text: qsTr("输入信息（自定义输入区）")
                                color: Theme.current.colorText0
                                font.pixelSize: Theme.current.fontSizeRegular
                                font.weight: Font.DemiBold
                            }

                            // 槽自己的输入框：Enter 经注入的 onSend 发送
                            TextArea {
                                id: customTa

                                objectName: "galleryCustomTa"
                                width: parent.width
                                placeholderText: qsTr("在这里输入，回车发送…")
                                autosize: ({ minRows: 1, maxRows: 3 })

                                onKeyPressed: (event) => {
                                    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                                        return;
                                    event.accepted = true;          // 挡掉换行
                                    if (text.length > 0 && customRoot.onSend !== undefined
                                        && customRoot.onSend !== null) {
                                        customRoot.onSend(text, []);
                                        text = "";
                                    }
                                }
                            }

                            Row {
                                spacing: Theme.current.spacingBaseTight

                                Button {
                                    text: qsTr("随便发一句")
                                    onClicked: customRoot.onSend("来自自定义输入框的消息", [])
                                }

                                Button {
                                    text: qsTr("清除上下文")
                                    tone: Enums.Tertiary
                                    onClicked: customRoot.onClear()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ================================================================ 提示信息
        GallerySection {
            title: "提示信息"

            Note {
                text: qsTr("hints 设置提示区内容；点击提示后内容成为新的用户输入，")
                + qsTr("并触发 onHintClick。")
            }

            Stage {
                width: 640
                height: 400

                Chat {
                    anchors.fill: parent
                    anchors.margins: 1

                    chats: page.hintChats
                    hints: page.hints
                    roleConfig: page.roleInfo

                    onChatsChange: (c) => page.hintChats = c
                    onHintClick: () => page.hints = []
                    onMessageSend: () => {
                        page.hintChats = page.hintChats.concat([
                            { role: "assistant", id: page.getId(), createAt: Date.now(), content: "这是一条 mock 回复信息" }
                        ]);
                    }
                }
            }
        }

        // ================================================================ 自定义提示信息渲染
        GallerySection {
            title: "自定义提示信息渲染"

            Note {
                text: qsTr("renderHintBox 是 Component，收 content / index / hintClick 三个属性。")
            }

            Stage {
                width: 640
                height: 400

                Chat {
                    anchors.fill: parent
                    anchors.margins: 1

                    chats: page.hintChats
                    hints: page.hints
                    roleConfig: page.roleInfo
                    renderHintBox: hintSlot

                    onChatsChange: (c) => page.hintChats = c
                    onHintClick: () => page.hints = []
                    onMessageSend: () => {
                        page.hintChats = page.hintChats.concat([
                            { role: "assistant", id: page.getId(), createAt: Date.now(), content: "这是一条 mock 回复信息" }
                        ]);
                    }
                }

                Component {
                    id: hintSlot

                    Item {
                        id: hintRoot

                        property string content
                        property int index
                        property var hintClick

                        width: hintRow.implicitWidth
                        height: hintRow.implicitHeight

                        Row {
                            id: hintRow

                            spacing: Theme.current.spacingTight

                            Rectangle {
                                width: hintText.implicitWidth + 24
                                height: hintText.implicitHeight + 16
                                radius: Theme.current.radiusLarge
                                color: hintHover.hovered ? Theme.current.colorPrimaryLightHover
                                    : Theme.current.colorBg2
                                border.width: 1
                                border.color: Theme.current.colorBorder

                                HoverHandler {
                                    id: hintHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: hintRoot.hintClick()
                                }

                                Text {
                                    id: hintText

                                    anchors.centerIn: parent
                                    text: hintRoot.content
                                    color: Theme.current.colorText1
                                    font.pixelSize: Theme.current.fontSizeRegular
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Note 里拼接引号文本的小助手（QML 的 qsTr 不能含引号拼接时用普通串）
    function qsQuotedNote() {
        return qsTr("槽需要声明 message / role / defaultTitle 等属性，没声明的不会被注入。");
    }
}
