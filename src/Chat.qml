pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Chat 对话。官方 semi-ui/chat：一个受控的会话容器 —— 消息列表（含清除上下文
// 分隔线）、提示区、回底 / 停止生成浮钮、输入区，外加拖拽上传蒙层。
//
//     Chat {
//         chats: message; roleConfig: roleInfo
//         onChatsChange: (c) => message = c
//         onMessageSend: (content, attachment) => mockReply()
//     }
//
// 官方 foundation.ts 的行为逐条落在这里：
//   · chats / hints 全受控（getDerivedStateFromProps）——组件只发 chatsChange，
//     自己绝不写回；漏接信号就什么都不发生（与上游一致）。
//   · 用户滚过一次轮之后停掉「新消息自动滚底」（wheelScroll 闩），发送消息时重置。
//   · 回底阈值 SHOW_SCROLL_GAP = 100（距底 ≤100 隐藏）。
//   · clearContext 只在末条不是分隔线时追加一条 role="divider" 的消息。
//   · resetMessage 无条件替换**最后一条**（传入的 message 只透传给回调，官方如此）。
//   · like / dislike 互斥：置一个必清另一个。
//
// 与官方的偏差（均记 PROGRESS）：
//   · 粘贴上传（enableUpload.pasteUpload）QML 拿不到剪贴板文件句柄，不实现；
//     dragUpload / clickUpload 正常。
//   · 代码块顶栏复制走隐藏 TextEdit（QML 无剪贴板 API）。
//   · backBottom / 停止生成两颗浮钮官方是 Button + 类名覆盖底色描边，QML 的
//     Button 缺省样式对不上，按 chat.scss 令牌本地画。
Item {
    id: control

    // ---- 官方 ChatProps（interface.ts:30）----
    property string align: "leftRight"               // leftRight | leftAlign
    property string mode: "bubble"                   // bubble | noBubble | userBubble
    property var chats: []                           // Message[]
    property bool escapeHtml: true
    property var roleConfig: undefined               // { user/assistant/system: Metadata }
    property var chatBoxRenderConfig: undefined      // { renderChatBoxTitle: Component, ... }
    property var renderDivider: undefined            // Component(message)
    property var hints: []
    property var renderHintBox: undefined            // Component({ content, index, hintClick })
    // 官方 v2.90：boolean 三态（undefined = 交给内部判断），用 var 承接
    property var canSend: undefined
    property string sendHotKey: "enter"              // enter | shift+enter
    property bool showStopGenerate: false
    property bool showClearContext: false
    property string placeholder: ""
    property var uploadProps: ({})
    property var uploadTipProps: undefined
    property var enableUpload: undefined             // bool | { clickUpload, pasteUpload, dragUpload }
    property var renderInputArea: undefined          // Component
    // 插槽：Component（Loader）或 Item（重挂到槽位）。官方是 ReactNode。
    property var topSlot: undefined
    property var bottomSlot: undefined
    // 死 prop（QML 无 CSS 类名 / 内联样式对象），保留 API 面
    property string inputBoxCls: ""
    property var inputBoxStyle: undefined
    property string hintCls: ""
    property var hintStyle: undefined

    // ---- 官方回调 ----
    signal chatsChange(var chats)
    signal messageDelete(var message)
    signal messageReset(var message)
    signal messageCopy(var message)
    signal messageGoodFeedback(var message)
    signal messageBadFeedback(var message)
    signal hintClick(string hint)
    signal inputChange(var props)
    signal messageSend(string content, var attachment)
    signal stopGenerator()
    signal clear

    readonly property var effectiveChats: control.chats !== undefined && control.chats !== null
        ? control.chats : []
    readonly property var effectiveHints: control.hints !== undefined && control.hints !== null
        ? control.hints : []
    readonly property real maxWidth: 800             // $width-chat_max

    // 官方 index.tsx:300-306：末条还在生成 ⇒ 停止钮亮、发送禁用
    readonly property var lastChat: control.effectiveChats.length > 0
        ? control.effectiveChats[control.effectiveChats.length - 1] : null
    readonly property bool lastChatOnGoing: control.lastChat !== null
        && control.lastChat !== undefined
        && (control.lastChat.status === "loading" || control.lastChat.status === "incomplete")
    readonly property bool showStopFlag: control.showStopGenerate && control.lastChatOnGoing

    // wheelScroll 闩：用户滚过一次就停掉自动滚底，发送消息时重置（foundation.ts:148-161）
    property bool wheelScroll: false

    width: control.parent !== null ? Math.min(control.parent.width, control.maxWidth)
        : control.maxWidth
    height: control.parent !== null ? control.parent.height : implicitHeight

    // ---------------------------------------------------------------- uuid
    function _uuid() {
        return "chat-" + Date.now() + "-" + Math.random().toString(36).slice(2);
    }

    // 官方 getUploadProps（foundation.ts:330-351）
    function _uploadFlags() {
        const v = control.enableUpload;
        if (typeof v === "object" && v !== null) {
            return {
                drag: v.dragUpload !== false,
                click: v.clickUpload !== false,
                paste: v.pasteUpload !== false
            };
        }
        if (typeof v === "boolean")
            return { drag: v, click: v, paste: v };
        return { drag: true, click: true, paste: true };
    }
    readonly property var uploadFlags: control._uploadFlags()

    // ---------------------------------------------------------------- 布局
    // 官方 .semi-chat：padding-y 12、flex column、overflow hidden
    Column {
        id: shell

        anchors.fill: parent
        anchors.topMargin: 12                       // $spacing-chat_paddingY
        anchors.bottomMargin: 12

        // ---- 顶部插槽 ----
        Loader {
            id: topSlotLoader

            width: shell.width
            active: control.topSlot !== undefined && control.topSlot !== null
                && typeof control.topSlot !== "string"
            sourceComponent: control.topSlot
        }

        Text {
            visible: typeof control.topSlot === "string"
            width: shell.width
            text: typeof control.topSlot === "string" ? control.topSlot : ""
            wrapMode: Text.Wrap
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }

        // ---- 聊天区（flex:1）----
        Item {
            id: contentArea

            width: shell.width
            height: parent.height - y
                - (inputHost.visible ? inputHost.height : 0) - bottomSlotLoader.height

            // 官方 -container：padding-x 16、overflow scroll
            Flickable {
                id: flick

                objectName: "chatContainer"

                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: contentCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                // 用户滚轮一次 ⇒ 停掉自动滚底（官方 registerWheelEvent 的一次性监听）
                WheelHandler {
                    onWheel: function (event) {
                        control.wheelScroll = true;
                        control._followBottom = false;   // 用户拿回滚动控制权
                        event.accepted = false;          // 放行给 Flickable 原生滚动
                    }
                }

                Column {
                    id: contentCol

                    x: 16                           // $spacing-chat_container-paddingX
                    width: flick.width - 32

                    Repeater {
                        model: control.effectiveChats

                        delegate: Item {
                            id: rowHost

                            required property int index
                            required property var modelData

                            readonly property var msg: modelData
                            readonly property bool isDivider: msg !== undefined && msg !== null
                                && msg.role === "divider"

                            width: flick.width - 32
                            height: isDivider ? dividerRow.height + 24
                                : (boxLoader.status === Loader.Ready
                                    ? (boxLoader.item as Item).implicitHeight : 0)

                            // ---- 清除上下文分隔线（chatContent.tsx:29-35）----
                            // 官方复用 Divider + 类名覆盖成 text-2 / small / regular / margin-y 12；
                            // 内层 -inner-text 的 600 字重压过外层 regular（divider.scss:35-39），
                            // 端口 Divider 的文字档写死 text-0 / 14px，按最终生效值就地画。
                            Row {
                                id: dividerRow

                                visible: rowHost.isDivider
                                y: 12                               // $spacing-chat_divider-marginY
                                height: dividerText.implicitHeight
                                width: parent.width

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width / 2 - dividerText.implicitWidth / 2 - 8
                                    height: 1
                                    color: Theme.current.colorBorder
                                }

                                Text {
                                    id: dividerText

                                    objectName: "chatDividerText"

                                    anchors.verticalCenter: parent.verticalCenter
                                    // renderDivider 自定义档（v2.67+）：有就整行交给它
                                    visible: control.renderDivider === undefined
                                        || control.renderDivider === null
                                    text: qsTr("上下文已清除")
                                    color: Theme.current.colorText2    // $color-chat_divider
                                    font.pixelSize: Theme.current.fontSizeSmall
                                    font.weight: Font.DemiBold          // -inner-text 的 600
                                    height: implicitHeight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Loader {
                                    anchors.verticalCenter: parent.verticalCenter
                                    active: control.renderDivider !== undefined
                                        && control.renderDivider !== null
                                    sourceComponent: control.renderDivider

                                    onLoaded: {
                                        if (item !== null && "message" in item)
                                            item.message = rowHost.msg;
                                    }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width / 2 - dividerText.implicitWidth / 2 - 8
                                    height: 1
                                    color: Theme.current.colorBorder
                                }
                            }

                            // ---- 会话框 ----
                            // Loader 不显式给宽会与 ChatBox 的 implicitWidth: parent.width
                            // 成环，宽度钉在 rowHost 上。
                            // 值传递用 Binding 而不是 onLoaded 赋值：后者是一次性的，
                            // 流式更新（status 变化）与 lastChat 漂移就跟丢了
                            Loader {
                                id: boxLoader

                                width: rowHost.width
                                visible: !rowHost.isDivider
                                active: !rowHost.isDivider
                                sourceComponent: boxComp
                            }

                            Binding {
                                target: boxLoader.item
                                property: "message"
                                value: rowHost.msg
                                when: boxLoader.item !== null
                            }

                            Binding {
                                target: boxLoader.item
                                property: "previousMessage"
                                value: rowHost.index > 0
                                    ? control.effectiveChats[rowHost.index - 1] : undefined
                                when: boxLoader.item !== null
                            }

                            Binding {
                                target: boxLoader.item
                                property: "lastChat"
                                value: rowHost.index === control.effectiveChats.length - 1
                                when: boxLoader.item !== null
                            }
                        }
                    }

                    // ---- 提示区（hint.tsx；margin-left 34 对齐会话内容列）----
                    Column {
                        objectName: "chatHints"

                        visible: control.effectiveHints.length > 0
                        width: parent.width - 34 - 16
                        x: 34                                   // $spacing-chat_hint-marginLeft
                        spacing: 10                             // $spacing-chat_hint-rowGap

                        Repeater {
                            model: control.effectiveHints

                            delegate: Item {
                                id: hintHost

                                required property int index
                                required property var modelData

                                readonly property string hintContent: String(modelData)

                                width: customHint.status === Loader.Ready
                                    ? (customHint.item as Item).width : hintRow.implicitWidth
                                height: customHint.status === Loader.Ready
                                    ? (customHint.item as Item).height : hintRow.implicitHeight

                                // 自定义提示渲染（renderHintBox）
                                Loader {
                                    id: customHint

                                    active: control.renderHintBox !== undefined
                                        && control.renderHintBox !== null
                                    sourceComponent: control.renderHintBox

                                    onLoaded: {
                                        if (item === null)
                                            return;
                                        if ("content" in item)
                                            item.content = hintHost.hintContent;
                                        if ("index" in item)
                                            item.index = hintHost.index;
                                        if ("hintClick" in item)
                                            item.hintClick = function () {
                                                control._onHintClick(hintHost.hintContent);
                                            };
                                    }
                                }

                                // 默认提示条（chat.scss:570-598）
                                Row {
                                    id: hintRow

                                    objectName: "chatHintItem"

                                    visible: customHint.status !== Loader.Ready
                                    spacing: 20                          // $spacing-chat_hint_item-columnGap

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: hintLabel.implicitWidth + 24 + hintArrow.width + 20
                                        height: hintLabel.implicitHeight + 16
                                        radius: Theme.current.radiusLarge
                                        color: hintHover.hovered ? Theme.current.colorFill0 : "transparent"
                                        border.width: 1
                                        border.color: Theme.current.colorBorder

                                        HoverHandler {
                                            id: hintHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        TapHandler {
                                            onTapped: control._onHintClick(hintHost.hintContent)
                                        }

                                        Text {
                                            id: hintLabel

                                            x: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: hintHost.hintContent
                                            color: Theme.current.colorText1    // $color-chat_hint_content_text
                                            font.pixelSize: Theme.current.fontSizeRegular
                                        }

                                        Icon {
                                            id: hintArrow

                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: "arrow_right"
                                            color: Theme.current.colorText2    // $color-chat_hint_icon
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- 回底钮 / 停止生成钮（chat.scss:75-108；绝对定位于聊天区底边中点）----
            Item {
                id: backBottom

                objectName: "chatBackBottom"

                visible: control.backBottomVisible && !control.showStopFlag
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                z: 1
                width: 42                           // $width-chat_backBottom_wrapper
                height: 42

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: bbHover.hovered ? Theme.current.colorTertiaryLightHover
                        : Theme.current.colorBg0
                    border.width: 1
                    border.color: Theme.current.colorBorder
                }

                Icon {
                    anchors.centerIn: parent
                    name: "chevron_down"
                    size: Theme.current.widthIconExtraLarge    // size="extra-large"
                    color: Theme.current.colorText1
                }

                HoverHandler {
                    id: bbHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: control.scrollToBottom(true)
                }
            }

            Item {
                id: stopBtn

                objectName: "chatStopButton"

                visible: control.showStopFlag
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                z: 1
                height: 42                           // $height-chat_action_stop
                width: stopRow.implicitWidth + 24

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: stopHover.hovered ? Theme.current.colorTertiaryLightHover
                        : Theme.current.colorBg0
                    border.width: 1
                    border.color: Theme.current.colorBorder
                }

                Row {
                    id: stopRow

                    anchors.centerIn: parent
                    spacing: 4

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "disc"
                        size: Theme.current.widthIconExtraLarge
                        color: Theme.current.colorText1
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("停止")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                HoverHandler {
                    id: stopHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: control.stopGenerator()
                }
            }
        }

        // ---- 输入区 ----
        Item {
            id: inputHost

            objectName: "chatInputHost"

            visible: true
            width: shell.width
            height: inputBox.status === Loader.Ready
                ? (inputBox.item as Item).implicitHeight : 0

            Loader {
                id: inputBox

                sourceComponent: inputComp
            }

            // 同 boxLoader：onLoaded 赋值是一次性的，改 Binding 跟随外层 prop
            Binding { target: inputBox.item; property: "showClearContext"; value: control.showClearContext; when: inputBox.item !== null }
            Binding { target: inputBox.item; property: "sendHotKey"; value: control.sendHotKey; when: inputBox.item !== null }
            Binding { target: inputBox.item; property: "canSend"; value: control.canSend; when: inputBox.item !== null }
            Binding { target: inputBox.item; property: "disableSend"; value: control.showStopFlag; when: inputBox.item !== null }
            Binding { target: inputBox.item; property: "placeholder"; value: control.placeholder; when: inputBox.item !== null }
            Binding { target: inputBox.item; property: "uploadProps"; value: control.uploadProps; when: inputBox.item !== null }
            Binding { target: inputBox.item; property: "uploadTipProps"; value: control.uploadTipProps; when: inputBox.item !== null }
            Binding { target: inputBox.item; property: "clickUpload"; value: control.uploadFlags.click; when: inputBox.item !== null }
            Binding { target: inputBox.item; property: "renderInputArea"; value: control.renderInputArea; when: inputBox.item !== null }
        }

        // ---- 底部插槽 ----
        Loader {
            id: bottomSlotLoader

            width: shell.width
            active: control.bottomSlot !== undefined && control.bottomSlot !== null
                && typeof control.bottomSlot !== "string"
            sourceComponent: control.bottomSlot
        }

        Text {
            visible: typeof control.bottomSlot === "string"
            width: shell.width
            text: typeof control.bottomSlot === "string" ? control.bottomSlot : ""
            wrapMode: Text.Wrap
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    // 官方 handleScrollContainerResize + containerScroll（foundation.ts:127-154）
    // 回底钮：距底 >100 显示（SHOW_SCROLL_GAP，foundation.ts:140-147）。
    // 官方 debounce 100ms；QML 直算等价（只影响出现时机的抖动，不影响阈值）
    property bool backBottomVisible: false

    function _updateBackBottom() {
        const dist = flick.contentHeight - flick.contentY - flick.height;
        control.backBottomVisible = dist > 100;      // SHOW_SCROLL_GAP
    }

    Connections {
        target: flick

        function onContentYChanged() { control._updateBackBottom(); }
        function onContentHeightChanged() {
            control._updateBackBottom();
            if (control._followBottom && !control.wheelScroll)
                control._scrollToBottomImmediately();
        }
        function onHeightChanged() { control._updateBackBottom(); }
    }

    // ---------------------------------------------------------------- 滚底
    // foundation.ts:94-125
    function _scrollToBottomImmediately() {
        const max = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = max;
        control._updateBackBottom();
    }

    property NumberAnimation _scrollAnim: NumberAnimation {
        target: flick
        property: "contentY"
        duration: 300                              // SCROLL_ANIMATION_TIME
        easing.type: Easing.InOutCubic             // easeInOutCubic
    }

    function scrollToBottom(animation) {
        const max = Math.max(0, flick.contentHeight - flick.height);
        if (animation) {
            _scrollAnim.stop();
            _scrollAnim.from = flick.contentY;
            _scrollAnim.to = max;
            _scrollAnim.start();
        } else {
            _scrollAnim.stop();
            flick.contentY = max;
            control._updateBackBottom();
        }
    }

    // 官方 componentDidUpdate 的自动滚底条件（index.tsx:226-254）
    property int _prevLen: 0
    property string _prevLastId: ""
    property string _prevLastStatus: ""
    property int _prevHintLen: 0

    onEffectiveChatsChanged: {
        const arr = control.effectiveChats;
        let shouldScroll = false;
        const last = arr.length > 0 ? arr[arr.length - 1] : null;
        const lastId = last !== null && last !== undefined && last.id !== undefined
            ? String(last.id) : "";
        const lastStatus = last !== null && last !== undefined && last.status !== undefined
            ? String(last.status) : "";
        if (arr.length > control._prevLen) {
            if (control._prevLen === 0 || lastId !== control._prevLastId)
                shouldScroll = true;
        } else if (arr.length === control._prevLen && arr.length > 0
            && (lastStatus !== "complete" || lastStatus !== control._prevLastStatus)) {
            shouldScroll = true;
        }
        control._prevLen = arr.length;
        control._prevLastId = lastId;
        control._prevLastStatus = lastStatus;
        if (shouldScroll && !control.wheelScroll)
            control._requestScrollBottom();
    }

    onEffectiveHintsChanged: {
        if (control.effectiveHints.length > control._prevHintLen && !control.wheelScroll)
            control._requestScrollBottom();
        control._prevHintLen = control.effectiveHints.length;
    }

    // foundation.ts:80-83 的 init 滚底 + componentDidUpdate 的自动滚底：官方在
    // 浏览器里 scrollTop=scrollHeight 是同步的（排版已完成），QML 的 Text 排版 /
    // Repeater 高度是异步长出来的，立即滚只能滚到半山腰（实测 contentY=836）。
    // 等价实现＝「跟随式贴底」：request 时先滚一次，之后 contentHeight 每长一截
    // 再贴一次，直到用户滚轮（官方 wheelScroll 闩同样是唯一让用户拿回控制权的开关）。
    property bool _followBottom: false

    function _requestScrollBottom() {
        control._followBottom = true;
        control._scrollToBottomImmediately();
    }

    Component.onCompleted: control._requestScrollBottom()

    // ---------------------------------------------------------------- foundation
    // onMessageSend（foundation.ts:171-212）：无附件 ⇒ content 就是字符串；
    // 有附件 ⇒ [{type:'text'|'image_url'|'file_url',...}]
    function sendMessage(content, attachment) {
        const att = attachment !== undefined && attachment !== null ? attachment : [];
        let c;
        if (att.length === 0) {
            c = content;
        } else {
            c = [];
            if (content)
                c.push({ type: "text", text: content });
            const picSuffix = ["png", "jpg", "jpeg", "gif", "bmp", "webp"];
            for (let i = 0; i < att.length; ++i) {
                const f = att[i];
                const name = f.name !== undefined ? String(f.name) : "";
                const dot = name.lastIndexOf(".");
                const suffix = dot >= 0 ? name.slice(dot + 1).toLowerCase() : "";
                const mime = f.type !== undefined ? String(f.type) : "";
                const isImg = mime.indexOf("image/") === 0 || picSuffix.indexOf(suffix) >= 0;
                if (isImg) {
                    c.push({ type: "image_url", image_url: { url: String(f.url) } });
                } else {
                    c.push({ type: "file_url", file_url: {
                        url: String(f.url), name: name,
                        size: f.size !== undefined ? String(f.size) : "", type: mime
                    } });
                }
            }
        }
        const m = { role: "user", id: control._uuid(), createAt: Date.now(), content: c };
        // 官方 foundation 先 notifyChatsChange 再 setWheelScroll(false)（:207-210），
        // 但 React 的 componentDidUpdate 在整个回调链跑完后才读 wheelScroll；
        // QML 的属性写是同步的 ⇒ 先落闩再发信号，等价于官方渲染时序
        control.wheelScroll = false;
        control.chatsChange(control.effectiveChats.concat([m]));
        control.messageSend(content, att);
    }

    // onHintClick（foundation.ts:214-225）：提示内容成为新的用户消息。
    // 官方这里**不**动 wheelScroll —— 滚过轮之后点提示也不自动滚底
    function _onHintClick(hint) {
        const m = { role: "user", id: control._uuid(), createAt: Date.now(), content: hint };
        control.chatsChange(control.effectiveChats.concat([m]));
        control.hintClick(hint);
    }

    // clearContext（foundation.ts:156-169）：末条已是分隔线就 no-op
    function clearContext() {
        const arr = control.effectiveChats;
        if (arr.length > 0 && arr[arr.length - 1] !== undefined
            && arr[arr.length - 1].role === "divider") {
            return;
        }
        const divider = { role: "divider", id: control._uuid(), createAt: Date.now() };
        control.chatsChange(arr.concat([divider]));
        control.clear();
    }

    // resetMessage（foundation.ts:273-281）：无条件替换最后一条 —— 展开原消息
    // 全部字段，只覆盖 status/content/id/createAt（role 等保留）
    function resetMessage(message) {
        const arr = control.effectiveChats;
        if (arr.length === 0)
            return;
        const last = arr[arr.length - 1];
        const newLast = control._patchMessage(last, {
            status: "loading", content: "",
            id: control._uuid(), createAt: Date.now()
        });
        const next = arr.slice(0, -1).concat([newLast]);
        control.chatsChange(next);
        control.messageReset(message);
    }

    // likeMessage / dislikeMessage（foundation.ts:239-265）：互斥
    // 注意 qmlcachegen 不吃 `...` 展开（同 .pragma library 那条坑），手动拷贝
    function _patchMessage(cur, patch) {
        const out = {};
        for (const k in cur)
            out[k] = cur[k];
        for (const k in patch)
            out[k] = patch[k];
        return out;
    }

    function likeMessage(message) {
        const arr = control.effectiveChats;
        const idx = control._indexOf(arr, message);
        if (idx < 0)
            return;
        const next = arr.slice();
        next.splice(idx, 1, control._patchMessage(arr[idx], {
            like: !arr[idx].like, dislike: false
        }));
        control.messageGoodFeedback(message);
        control.chatsChange(next);
    }

    function dislikeMessage(message) {
        const arr = control.effectiveChats;
        const idx = control._indexOf(arr, message);
        if (idx < 0)
            return;
        const next = arr.slice();
        next.splice(idx, 1, control._patchMessage(arr[idx], {
            like: false, dislike: !arr[idx].dislike
        }));
        control.messageBadFeedback(message);
        control.chatsChange(next);
    }

    // deleteMessage（foundation.ts:231-237）
    function deleteMessage(message) {
        control.messageDelete(message);
        const next = [];
        const arr = control.effectiveChats;
        for (let i = 0; i < arr.length; ++i) {
            if (arr[i] !== message && arr[i].id !== message.id)
                next.push(arr[i]);
        }
        control.chatsChange(next);
    }

    function _indexOf(arr, message) {
        for (let i = 0; i < arr.length; ++i) {
            if (arr[i] === message)
                return i;
            if (message !== undefined && message !== null
                && arr[i] !== undefined && arr[i].id !== undefined
                && message.id !== undefined && arr[i].id === message.id) {
                return i;
            }
        }
        return -1;
    }

    // 拖拽上传（foundation.ts:283-296）：拖入亮蒙层，落文件交给 Upload.insert
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        enabled: control.uploadFlags.drag

        onEntered: function (drag) {
            dropOverlay.visible = true;
        }
        onExited: function () {
            dropOverlay.visible = false;
        }
        onDropped: function (drop) {
            dropOverlay.visible = false;
            const paths = [];
            for (let i = 0; i < drop.urls.length; ++i)
                paths.push(String(drop.urls[i]).replace("file://", ""));
            if (paths.length > 0 && inputBox.status === Loader.Ready
                && "insertFiles" in inputBox.item) {
                (inputBox.item as ChatInputBox).insertFiles(paths);
            }
        }
    }

    // 拖拽蒙层（chat.scss:29-46）
    Rectangle {
        id: dropOverlay

        objectName: "chatDropArea"

        visible: false
        anchors.fill: parent
        z: 10
        radius: 16                                  // $radius-chat_dropArea
        color: Qt.rgba(Theme.current.grey[2].r, Theme.current.grey[2].g,
            Theme.current.grey[2].b, 0.9)            // rgba(grey-2, .9)
        border.width: 0

        // QML Rectangle 画不出虚线，按官方 dotted 5px 用 Canvas 描（同 Upload.qml:922）
        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.lineWidth = 5;                  // $width-chat_dropArea-border
                ctx.strokeStyle = Qt.rgba(
                    Theme.current.colorBorder.r, Theme.current.colorBorder.g,
                    Theme.current.colorBorder.b, 1);
                ctx.setLineDash([10, 10]);
                ctx.strokeRect(2.5, 2.5, width - 5, height - 5);
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Text {
            anchors.centerIn: parent
            text: qsTr("将文件放到这里")
            color: Theme.current.colorText0
            font.pixelSize: 48                      // $font-chat_dropArea_text
        }
    }

    // Toast：复制成功提示的宿主（官方 ChatContent 里的 useToast）
    Toast {
        id: toastHost
    }

    // ---------------------------------------------------------------- 组件
    Component {
        id: boxComp

        ChatBox {
            align: control.align
            mode: control.mode
            roleConfig: control.roleConfig
            escapeHtml: control.escapeHtml
            chatBoxRenderConfig: control.chatBoxRenderConfig
            toastHost: toastHost

            onMessageDelete: function (message) { control.deleteMessage(message); }
            onMessageReset: function (message) { control.resetMessage(message); }
            onMessageCopy: function (message) { control.messageCopy(message); }
            onMessageGoodFeedback: function (message) { control.likeMessage(message); }
            onMessageBadFeedback: function (message) { control.dislikeMessage(message); }
        }
    }

    Component {
        id: inputComp

        ChatInputBox {
            objectName: "chatInputBox"
            width: shell.width

            onSend: function (content, attachment) {
                control.sendMessage(content, attachment);
            }
            onClearContext: { control.clearContext(); }
            onInputChange: function (props) { control.inputChange(props); }
        }
    }
}
