pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Semi
import "ChatMarkdown.js" as ChatMarkdown

// 单条会话框：头像 + 包裹列（标题 / 内容 / 操作区）。
// 对应官方 chatBox/index.tsx + chatBoxAvatar / Title / Content / Action 四件套。
//
//     ChatBox {
//         message: { role: "user", id: "1", content: "hi" }
//         align: "leftRight"; mode: "bubble"
//     }
//
// 两处官方 CSS 在 QML 里对不上号的地方（都按实测画、记 PROGRESS）：
//   · 操作区按钮官方用 Button(borderless/tertiary)，但 chat.scss:193-203 把 hover 底色
//     改成 transparent、字色改成 text-2 → hover text-0（Button 缺省 fill-0 / text-1），
//     这里按 chat.scss 令牌画 ChatActionGlyph。
//   · 官方 send 按钮的 rotate(45deg) 挂在 `.semi-…-sendButton.semi-button-icon` 上
//     （scss `&-icon` 展开成双类选择器），图标节点永远没有 semi-button 类 ⇒ 死规则，
//     LTR 下箭头不转（编译产物 chat.css:330 佐证）；端口照实测：不转。
Item {
    id: root

    objectName: "chatBox"

    // ---- 官方 ChatBoxProps（interface.ts:152）----
    property var message: ({})
    property var previousMessage: undefined
    property bool lastChat: false
    property string align: "leftRight"             // leftRight | leftAlign
    property string mode: "bubble"                 // bubble | noBubble | userBubble
    property var roleConfig: undefined
    property bool escapeHtml: true
    // ChatBoxRenderConfig（interface.ts:113）：五个渲染函数在 QML 落成 Component，
    // 使用方传 { renderChatBoxTitle: Component {...}, ... }；组件需自行声明
    // message / role / className / defaultNodes 等属性，Loader 只给声明过的赋值。
    property var chatBoxRenderConfig: undefined
    // Chat 塞进来的 Toast 实例（复制成功提示用，官方是 ChatContent 里的 useToast）
    property var toastHost: null

    // ---- Chat 转发的回调（官方 ChatBoxAction / foundation 的 notify*）----
    signal messageDelete(var message)
    signal messageReset(var message)
    signal messageCopy(var message)
    signal messageGoodFeedback(var message)
    signal messageBadFeedback(var message)

    readonly property var msg: root.message !== undefined && root.message !== null
        ? root.message : ({})
    readonly property string role: msg.role !== undefined && msg.role !== null
        ? String(msg.role) : ""
    readonly property var info: {
        if (root.roleConfig === undefined || root.roleConfig === null)
            return {};
        const r = root.roleConfig[root.role];
        return r !== undefined && r !== null ? r : {};
    }
    // continueSend（chatBox/index.tsx:33）：与上一条同角色 ⇒ 头像占位但不可见、标题不渲染
    readonly property bool continueSend: root.previousMessage !== undefined
        && root.previousMessage !== null
        && root.previousMessage.role === root.role
    readonly property bool isUser: root.role === "user"
    // leftRight 布局下用户消息靠右（-right：row-reverse + wrap 右对齐）
    readonly property bool rightAligned: root.isUser && root.align === "leftRight"

    // status 缺省 complete（chatBoxAction.tsx:220 的解构默认值）
    readonly property string status: {
        const s = root.msg.status;
        return s !== undefined && s !== null ? String(s) : "complete";
    }
    readonly property bool complete: root.status === "complete"
    readonly property bool finished: root.status !== "loading" && root.status !== "incomplete"

    // 气泡三档（chatBoxContent.tsx:46-55 的 wrapCls）
    readonly property bool bubbleAll: root.mode === "bubble"
    readonly property bool userBubbleOnly: root.mode === "userBubble" && root.isUser
    readonly property bool bubbleOn: root.bubbleAll || root.userBubbleOnly
    readonly property bool bubbleUser: (root.bubbleAll && root.isUser) || root.userBubbleOnly
    readonly property bool bubbleError: root.status === "error" && root.bubbleOn

    readonly property color contentBg: root.bubbleError ? Theme.current.colorDangerHover
        : (root.bubbleUser ? Theme.current.colorPrimary : Theme.current.colorFill0)
    readonly property color contentFg: root.bubbleUser || root.bubbleError
        ? Theme.current.colorWhite : Theme.current.colorText0

    // 操作区显隐（chatBoxAction.tsx:225-228 + chat.scss:126 的 hover 规则）
    readonly property bool showReset: root.lastChat && root.role === "assistant"
    readonly property bool showFeedback: !root.isUser && root.complete

    // 原始 content 的文本形态（数组档取全部 text 段拼接，复制/转义都用它）
    readonly property string rawText: {
        const c = root.msg.content;
        if (Array.isArray(c)) {
            let acc = "";
            for (let i = 0; i < c.length; ++i) {
                if (c[i].type === "text")
                    acc += (c[i].text !== undefined ? String(c[i].text) : "");
            }
            return acc;
        }
        return c !== undefined && c !== null ? String(c) : "";
    }
    // 官方只对 user 消息转义（chatBoxContent.tsx:22）
    readonly property string mdText: root.escapeHtml && root.isUser
        ? ChatMarkdown.escapeHtmlInMarkdown(root.rawText) : root.rawText
    // 围栏切分：text 段交给 MarkdownText，code 段单独画（顶栏 + 复制钮）
    readonly property var segments: root.status === "loading" ? []
        : ChatMarkdown.splitFences(root.mdText)

    // ---- 几何（手排：官方 wrap 是 flex column row-gap 8；continueSend 时标题
    //      不渲染、操作区 visibility 隐但占位 ⇒ 两种占位语义不同，不用 Column）----
    readonly property real maxContentWidth: Math.max(0, implicitWidth - 24 - 12)  // avatar 24 + gap 12
    // 官方 chatBox 是 flex row + column-gap 12：头像槽恒占 24（continueSend 时
    // visibility:hidden 仍占位）⇒ wrap 列（标题/内容/操作区）从 36 起；右对齐档
    // 行反转、头像在右，wrap 从 0 起并在 maxContentWidth 内右贴。
    readonly property real wrapX: root.rightAligned ? 0 : 36
    // 官方标题是 `{!continueSend && titleNode}` —— continueSend 时**完全不渲染**
    // （chatBox/index.tsx:103），连 20px 行盒都不留
    readonly property real titleH: root.continueSend ? 0 : 20
    // 有标题时内容在标题下 8px（row-gap）；无标题时顶格
    readonly property real contentY: root.titleH > 0 ? root.titleH + 8 : 0
    readonly property real contentH: contentHost.implicitHeight
    readonly property real actionY: root.contentY + root.contentH + 8
    // 气泡收缩宽度（官方 shrink-to-fit + max-width:100%）：裸文本量自然宽、
    // 图/文件段按 60/芯片宽，多段取最大，再被 maxContentWidth 钳住。
    readonly property real naturalContentWidth: {
        if (root.status === "loading")
            return 24 + 20;
        let w = widthProbe.implicitWidth;
        if (Array.isArray(root.msg.content)) {
            for (let i = 0; i < root.msg.content.length; ++i) {
                const p = root.msg.content[i];
                if (p.type === "image_url")
                    w = Math.max(w, 60);
                else if (p.type === "file_url")
                    w = Math.max(w, 180);
            }
        }
        return w + 24;                                  // 气泡 padding 12×2
    }

    implicitWidth: parent !== null ? parent.width : 480
    implicitHeight: root.actionY + 16

    // 量自然宽度的探针（不参与布局）
    Text {
        id: widthProbe

        visible: false
        textFormat: Text.PlainText
        text: root.mdText
    }

    HoverHandler {
        id: boxHover
    }

    // 自定义整框渲染优先（chatBox/index.tsx:95-107）；给了就整体替换
    readonly property bool fullTaken: fullLoader.status === Loader.Ready

    // ---------------------------------------------------------------- 头像
    Avatar {
        id: avatarItem

        objectName: "chatBoxAvatar"

        x: root.rightAligned ? root.width - width : 0
        y: 0
        width: 24                              // $width-chat_chatBox_avatar
        height: 24
        size: "extra-small"
        src: typeof root.info.avatar === "string" ? root.info.avatar : ""
        // 官方 ChatBoxAvatar.tsx:34 解构 role 的 color 传给 Avatar 调色板
        color: root.info.color !== undefined && root.info.color !== null
            && root.info.color !== "" ? root.info.color : "grey"
        // 官方 -avatar-hidden 是 visibility: hidden —— 占位但不可见
        // （自定义头像渲染接管时默认头像让位；官方那条隐藏类只挂默认节点上）
        visible: !root.continueSend && !root.fullTaken
            && customAvatar.status !== Loader.Ready

        // 非字符串档（官方 children：图标等）—— Component 注入
        Loader {
            anchors.fill: parent
            active: typeof root.info.avatar !== "string" && root.info.avatar !== undefined
                && root.info.avatar !== null
            sourceComponent: typeof root.info.avatar === "object" ? root.info.avatar : null
        }
    }

    // 自定义头像渲染（chatBoxAvatar.tsx:32-34）：给了就整块替换默认头像
    // —— 官方连 continueSend 的隐藏类都只挂默认节点上，自定义节点照常渲染
    Loader {
        id: customAvatar

        x: avatarItem.x
        y: avatarItem.y
        width: status === Loader.Ready && item !== null
            && (item as Item).implicitWidth > 0 ? (item as Item).implicitWidth : 24
        height: status === Loader.Ready && item !== null
            && (item as Item).implicitHeight > 0 ? (item as Item).implicitHeight : 24
        active: root._cfg("renderChatBoxAvatar") !== null
        sourceComponent: root._cfg("renderChatBoxAvatar")
        visible: status === Loader.Ready && !root.fullTaken

        Binding {
            target: customAvatar.item
            property: "message"
            value: root.msg
            when: customAvatar.item !== null && "message" in customAvatar.item
        }
        Binding {
            target: customAvatar.item
            property: "role"
            value: root.info
            when: customAvatar.item !== null && "role" in customAvatar.item
        }
        Binding {
            target: customAvatar.item
            property: "defaultAvatar"
            value: avatarItem
            when: customAvatar.item !== null && "defaultAvatar" in customAvatar.item
        }
    }

    // ---------------------------------------------------------------- 标题
    // 官方 title = <span>{role.name}</span>：line-height 20 / header-6 / text-0 / regular
    Text {
        id: titleText

        objectName: "chatBoxTitle"

        x: root.wrapX + (root.rightAligned && root.maxContentWidth > titleText.width
            ? root.maxContentWidth - titleText.width : 0)
        y: 0
        visible: !root.continueSend && !root.fullTaken && customTitle.status !== Loader.Ready
        text: root.info.name !== undefined ? String(root.info.name) : ""
        color: Theme.current.colorText0
        font.pixelSize: Theme.current.fontSizeHeader6
        font.weight: Theme.current.fontWeightRegular
        height: 20
        verticalAlignment: Text.AlignVCenter
    }

    // ---------------------------------------------------------------- 内容盒
    Item {
        id: contentHost

        objectName: "chatBoxContentHost"

        x: root.wrapX + (root.rightAligned && root.maxContentWidth > width
            ? root.maxContentWidth - width : 0)
        y: root.contentY
        visible: !root.fullTaken && customContent.status !== Loader.Ready
        width: root.bubbleOn
            ? Math.min(root.naturalContentWidth, root.maxContentWidth)
            : root.maxContentWidth
        implicitHeight: root.status === "loading" ? 20
            : segmentsCol.implicitHeight + (root.bubbleOn ? 16 : 0)

        // 气泡底（bubble / userBubble / error 三色，chat.scss:219-274）
        Rectangle {
            objectName: "chatBoxBubble"

            anchors.fill: parent
            visible: root.bubbleOn
            color: root.contentBg
            radius: Theme.current.radiusLarge         // $radius-chat_chatBox_content

            Behavior on color {
                ColorAnimation { duration: Theme.current.durationFast }
            }
        }

        // 加载态：三个闪烁圆点（chat.scss:276-317）
        Row {
            objectName: "chatBoxLoading"

            visible: root.status === "loading"
            anchors.centerIn: parent
            spacing: 7                              // 8px 圆点、15px 步距 ⇒ 净距 7

            Repeater {
                model: 3

                delegate: Rectangle {
                    id: loadDot

                    objectName: "chatLoadingDot"

                    required property int index

                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.current.colorText0     // $color-chat_chatBox_loading-bg

                    // 官方三个圆点同为 .8s 一圈、相位差 -0.2 / -0.4 / 0（左领先）。
                    // Qt 6.11 的 Animation 没有 delay 属性（qquickanimation_p.h 只有
                    // running/paused/alwaysRunToEnd/loops），Sequence 里塞 PauseAnimation
                    // 又会让三圈周期不等而漂移 ⇒ 三个等周期序列用一次性 Timer 错峰启动：
                    // 左 0ms、中 200ms、右 400ms，稳态相位差与官方一致。
                    property bool phased: false

                    Component.onCompleted: phaseTimer.start()

                    Timer {
                        id: phaseTimer

                        interval: [0, 200, 400][loadDot.index]
                        onTriggered: loadDot.phased = true
                    }

                    SequentialAnimation on opacity {
                        running: root.status === "loading" && loadDot.phased
                        loops: Animation.Infinite

                        NumberAnimation { from: 1; to: 0.1; duration: 400 }
                        NumberAnimation { from: 0.1; to: 1; duration: 400 }
                    }
                }
            }
        }

        // 正文列：text 段（MarkdownText）/ code 段（顶栏+复制）/ image / file 逐段排
        Column {
            id: segmentsCol

            objectName: "chatBoxSegments"

            visible: root.status !== "loading"
            x: root.bubbleOn ? 12 : 0
            y: root.bubbleOn ? 8 : 0
            width: root.bubbleOn ? parent.width - 24 : parent.width
            spacing: 4

            Repeater {
                model: Array.isArray(root.msg.content)
                    ? root._expandParts(root.msg.content) : root.segments

                delegate: Item {
                    id: part

                    required property var modelData

                    property var seg: modelData

                    readonly property bool isImage: seg.type === "image"
                    readonly property bool isFile: seg.type === "file"
                    readonly property bool isCode: seg.type === "code"

                    width: segmentsCol.width
                    height: isImage ? 60
                        : (isFile ? filePart.implicitHeight
                            : (isCode ? codeBox.implicitHeight : textPart.implicitHeight))

                    // ---- 文本段：Qt MarkdownText 承接官方 MarkdownRender ----
                    // （MarkdownRender 组件本库未实现，docs.json 里 markdownrender 仍 skipped；
                    // customMarkDownComponents / markdownRenderProps 因此无落点，记死 prop）
                    Text {
                        id: textPart

                        objectName: "chatBoxText"

                        visible: !part.isImage && !part.isFile && !part.isCode
                        width: parent.width
                        text: part.seg.body
                        textFormat: Text.MarkdownText
                        wrapMode: Text.Wrap
                        color: root.contentFg
                        font.pixelSize: Theme.current.fontSizeRegular

                        onLinkActivated: function (link) {
                            Qt.openUrlExternally(link);
                        }
                    }

                    // ---- 代码段：官方 Code 组件（code.tsx）的语言顶栏 + 复制钮 ----
                    // 顶栏与正文恒 dark（semi-always-dark），取 Theme.dark 令牌
                    Rectangle {
                        id: codeBox

                        objectName: "chatCodeBlock"

                        visible: part.isCode
                        width: parent.width
                        implicitHeight: codeCol.implicitHeight
                        height: implicitHeight
                        color: Theme.dark.colorBg0              // always-dark 的 bg-0
                        radius: Theme.current.radiusLarge
                        clip: true

                        Column {
                            id: codeCol

                            width: parent.width

                            // 顶栏：语言名 + 复制（code.tsx:27-48）
                            Rectangle {
                                visible: part.seg.lang !== ""
                                width: parent.width
                                height: 30
                                color: Theme.dark.grey[4]           // always-dark grey-4 = #6b7075

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 8
                                    text: part.seg.lang
                                    color: Theme.dark.colorWhite    // rgba(--semi-white)
                                    font.pixelSize: 12
                                    height: 16
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    width: copyRow.implicitWidth + 10
                                    height: 26

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.current.radiusLarge
                                        color: copyHover.hovered
                                            ? Theme.dark.grey[5] : "transparent"   // grey-5 hover

                                        HoverHandler {
                                            id: copyHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        Row {
                                            id: copyRow

                                            anchors.centerIn: parent
                                            spacing: 5

                                            Icon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                name: codeBox.copied ? "tick" : "copy_stroked"
                                                size: 14
                                                color: Theme.dark.colorWhite
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: codeBox.copied ? qsTr("复制成功") : qsTr("复制")
                                                color: Theme.dark.colorWhite
                                                font.pixelSize: 12
                                            }
                                        }

                                        TapHandler {
                                            onTapped: {
                                                clipHelper.text = part.seg.body;
                                                clipHelper.selectAll();
                                                clipHelper.copy();
                                                codeBox.copied = true;
                                                copiedReset.restart();
                                            }
                                        }
                                    }
                                }
                            }

                            // 正文：等宽 + pre-wrap（chat.scss:327-330）
                            Text {
                                width: parent.width - 16
                                x: 8
                                text: part.seg.body
                                color: Theme.dark.colorWhite
                                font.family: "monospace"
                                font.pixelSize: Theme.current.fontSizeRegular
                                wrapMode: Text.Wrap
                            }
                        }

                        property bool copied: false

                        Timer {
                            id: copiedReset

                            interval: 2000
                            onTriggered: codeBox.copied = false
                        }
                    }

                    // ---- 图片段（image_url）：Image 无 radius，MultiEffect 遮罩裁角 ----
                    Image {
                        id: segImage

                        visible: part.isImage
                        width: 60
                        height: 60
                        source: part.isImage && part.seg.url !== undefined ? String(part.seg.url) : ""
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: visible
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: segMask
                        }
                    }

                    Item {
                        id: segMask

                        visible: false
                        width: segImage.width
                        height: segImage.height

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.current.radiusMedium
                            color: "white"
                        }
                    }

                    // ---- 文件段（file_url）----
                    ChatAttachment {
                        id: filePart

                        visible: part.isFile
                        width: implicitWidth
                        showClear: false
                        // 官方：用户气泡里附件底是 bg-0，其他角色是 fill-2（chat.scss:235/251）
                        fileBg: root.bubbleUser ? Theme.current.colorBg0 : Theme.current.colorFill2
                        attachment: part.isFile ? [{
                            url: part.seg.url !== undefined ? part.seg.url : "",
                            name: part.seg.name !== undefined ? part.seg.name : "",
                            size: part.seg.size !== undefined ? part.seg.size : "",
                            type: part.seg.typeName !== undefined ? part.seg.typeName : ""
                        }] : []
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- 操作区
    Item {
        id: actionBar

        objectName: "chatBoxAction"

        x: root.wrapX + (root.rightAligned && root.maxContentWidth > width
            ? root.maxContentWidth - width - 10 : 10)    // 官方 margin-x 10
        y: root.actionY
        width: actionRow.implicitWidth
        height: 16
        // 官方 visibility: hidden；reset 常显（-show）、hover 露、未完成恒隐（-hidden 优先）
        visible: !root.fullTaken && root.finished
            && (root.showReset || boxHover.hovered || actionBar.actionPopVisible)
            && customAction.status !== Loader.Ready

        Row {
            id: actionRow

            spacing: 10                              // $spacing-chat_chatBox_action-columnGap

            // 复制：complete 才渲染（chatBoxAction.tsx:262）
            ChatActionGlyph {
                objectName: "chatActionCopy"

                visible: root.complete
                icon: "copy_stroked"

                onClicked: {
                    clipHelper.text = root.rawText;
                    clipHelper.selectAll();
                    clipHelper.copy();
                    if (root.toastHost !== null && root.toastHost !== undefined)
                        root.toastHost.success({ content: qsTr("复制成功") });
                    root.messageCopy(root.msg);
                }
            }

            // 正向反馈：非 user 且 complete
            ChatActionGlyph {
                objectName: "chatActionLike"

                visible: root.showFeedback
                icon: root.msg.like ? "like_thumb" : "thumb_up_stroked"

                onClicked: root.messageGoodFeedback(root.msg)
            }

            // 负向反馈：图标上下翻转（chat.scss:177 scaleY(-1)）
            ChatActionGlyph {
                objectName: "chatActionDislike"

                visible: root.showFeedback
                icon: root.msg.dislike ? "like_thumb" : "thumb_up_stroked"
                flipped: true

                onClicked: root.messageBadFeedback(root.msg)
            }

            // 重置：最后一条 assistant 才有
            ChatActionGlyph {
                objectName: "chatActionReset"

                visible: root.showReset
                icon: "redo_stroked"

                onClicked: root.messageReset(root.msg)
            }

            // 删除：恒渲染，点开确认气泡
            ChatActionGlyph {
                id: deleteGlyph

                objectName: "chatActionDelete"

                icon: "delete_stroked"

                onClicked: deletePop.open()
            }
        }

        // 官方 showAction（chatBoxAction.tsx:113-117）：删除气泡开着时操作区保持显示
        property bool actionPopVisible: false

        Popconfirm {
            id: deletePop

            objectName: "chatDeletePop"

            anchor: deleteGlyph
            placement: Enums.Top
            title: qsTr("确认删除该会话吗？")

            onAboutToShow: actionBar.actionPopVisible = true
            onAboutToHide: hideDelay.restart()
            onConfirmed: root.messageDelete(root.msg)
        }

        // 官方 hideDeletePopup：气泡关掉后 150ms 才收 showAction，避免闪动
        // （chatBoxActionFoundation.ts:28-35 的 setTimeout 150）
        Timer {
            id: hideDelay

            interval: 150
            onTriggered: actionBar.actionPopVisible = false
        }
    }

    // 复制到剪贴板的载体：QML 无剪贴板 API，用隐藏 TextEdit 的 selectAll+copy
    TextEdit {
        id: clipHelper

        visible: false
        textFormat: TextEdit.PlainText
    }

    // ---------------------------------------------------------------- 自定义渲染
    function _cfg(key) {
        if (root.chatBoxRenderConfig === undefined || root.chatBoxRenderConfig === null)
            return null;
        const v = root.chatBoxRenderConfig[key];
        return v !== undefined && v !== null ? v : null;
    }

    // content 数组里的 image_url / file_url 段拍平成统一的块列表
    function _expandParts(parts) {
        const out = [];
        for (let i = 0; i < parts.length; ++i) {
            const p = parts[i];
            if (p.type === "image_url") {
                out.push({ type: "image", url: p.image_url !== undefined
                    && p.image_url !== null ? String(p.image_url.url) : "" });
            } else if (p.type === "file_url") {
                const f = p.file_url !== undefined && p.file_url !== null ? p.file_url : {};
                const name = f.name !== undefined ? String(f.name) : "";
                const dot = name.lastIndexOf(".");
                out.push({ type: "file", url: f.url !== undefined ? String(f.url) : "",
                    name: name, size: f.size !== undefined ? String(f.size) : "",
                    typeName: dot >= 0 ? name.slice(dot + 1) : "" });
            } else {
                const raw = p.text !== undefined ? String(p.text) : "";
                const esc = root.escapeHtml && root.isUser
                    ? ChatMarkdown.escapeHtmlInMarkdown(raw) : raw;
                const segs = ChatMarkdown.splitFences(esc);
                for (let j = 0; j < segs.length; ++j)
                    out.push(segs[j]);
            }
        }
        return out;
    }

    // 整框自定义（renderFullChatBox）
    Loader {
        id: fullLoader

        anchors.fill: parent
        active: root._cfg("renderFullChatBox") !== null
        sourceComponent: root._cfg("renderFullChatBox")

        // 注入用 Binding 而非 onLoaded：onLoaded 在外层把 message 喂进来之前
        // 就跑了（一次性拿到初始空对象），Binding 会跟着 root.msg 重算
        Binding {
            target: fullLoader.item
            property: "message"
            value: root.msg
            when: fullLoader.item !== null && "message" in fullLoader.item
        }
        Binding {
            target: fullLoader.item
            property: "role"
            value: root.info
            when: fullLoader.item !== null && "role" in fullLoader.item
        }
        Binding {
            target: fullLoader.item
            property: "className"
            value: root.rightAligned
                ? "semi-chat-chatBox semi-chat-chatBox-right" : "semi-chat-chatBox"
            when: fullLoader.item !== null && "className" in fullLoader.item
        }
        Binding {
            target: fullLoader.item
            property: "defaultNodes"
            value: ({
                avatar: avatarItem,
                title: titleText,
                content: contentHost,
                action: actionBar
            })
            when: fullLoader.item !== null && "defaultNodes" in fullLoader.item
        }
    }

    // 槽位级自定义（renderChatBoxTitle / Content / Action）
    Loader {
        id: customTitle

        // 官方 -wrap 在右对齐档是 align-items: flex-end —— 槽按**自己的宽度**
        // 右贴（缺省标题的宽度量不出自定义槽，别拿 titleText.width 算）
        x: root.wrapX + (root.rightAligned && root.maxContentWidth > width
            ? root.maxContentWidth - width : 0)
        y: titleText.y
        active: root._cfg("renderChatBoxTitle") !== null
        sourceComponent: root._cfg("renderChatBoxTitle")
        visible: status === Loader.Ready && !root.fullTaken

        Binding {
            target: customTitle.item
            property: "message"
            value: root.msg
            when: customTitle.item !== null && "message" in customTitle.item
        }
        Binding {
            target: customTitle.item
            property: "role"
            value: root.info
            when: customTitle.item !== null && "role" in customTitle.item
        }
        Binding {
            target: customTitle.item
            property: "defaultTitle"
            value: titleText
            when: customTitle.item !== null && "defaultTitle" in customTitle.item
        }
    }

    Loader {
        id: customContent

        x: contentHost.x
        y: contentHost.y
        width: contentHost.width
        active: root._cfg("renderChatBoxContent") !== null
        sourceComponent: root._cfg("renderChatBoxContent")
        visible: status === Loader.Ready && !root.fullTaken

        Binding {
            target: customContent.item
            property: "message"
            value: root.msg
            when: customContent.item !== null && "message" in customContent.item
        }
        Binding {
            target: customContent.item
            property: "role"
            value: root.info
            when: customContent.item !== null && "role" in customContent.item
        }
        Binding {
            target: customContent.item
            property: "defaultContent"
            value: contentHost
            when: customContent.item !== null && "defaultContent" in customContent.item
        }
        Binding {
            target: customContent.item
            property: "className"
            value: root.bubbleUser
                ? "semi-chat-chatBox-content semi-chat-chatBox-content-user"
                : "semi-chat-chatBox-content"
            when: customContent.item !== null && "className" in customContent.item
        }
    }

    Loader {
        id: customAction

        x: actionBar.x
        y: actionBar.y
        width: actionBar.width
        height: actionBar.height
        active: root._cfg("renderChatBoxAction") !== null
        sourceComponent: root._cfg("renderChatBoxAction")
        visible: status === Loader.Ready && !root.fullTaken

        Binding {
            target: customAction.item
            property: "message"
            value: root.msg
            when: customAction.item !== null && "message" in customAction.item
        }
        Binding {
            target: customAction.item
            property: "defaultActions"
            value: actionRow
            when: customAction.item !== null && "defaultActions" in customAction.item
        }
        Binding {
            target: customAction.item
            property: "className"
            value: "semi-chat-chatBox-action semi-chat-chatBox-action-show"
            when: customAction.item !== null && "className" in customAction.item
        }
    }
}
