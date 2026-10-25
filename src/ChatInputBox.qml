pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Chat 的输入区。对应官方 chat/inputBox/index.tsx + inputboxFoundation.ts。
//
//     ChatInputBox {
//         placeholder: "输入消息…"; showClearContext: true
//         onSend: (content, attachment) => ...
//     }
//
// 结构：`-inner`（行、底对齐、gap 4）＝ 清除钮（可选）+ `-container`
// （radius 16、padding 11、1px 边框）＝ 上传钮（可选）+ `-inputArea`
// （TextArea 1~5 行 + 附件条）+ 发送钮。
//
// 与官方的偏差（都记 PROGRESS）：
//   · 官方上传钮的 hover 是 Button borderless 的 fill-0，图标色官方用 CSS 覆盖成
//     text-0、清除钮覆盖成 text-2（chat.scss:394-411）—— Button 缺省给的是
//     primary 色 ⇒ 三颗钮都按 chat.scss 令牌本地画。
//   · 粘贴上传（pasteUpload）：QML 拿不到剪贴板里的文件句柄，不实现。
Item {
    id: root

    // ---- 官方 InputBoxProps（interface.ts:162）----
    property var canSend: undefined               // 官方 v2.90：boolean 三态，给了就盖过内部判断
    property bool showClearContext: false
    property string sendHotKey: "enter"            // enter | shift+enter
    property string placeholder: ""
    property bool disableSend: false               // Chat 下发：末条还在生成
    property var uploadProps: ({})                 // 透传给 Upload
    property var uploadTipProps: undefined         // Tooltip 包上传钮：{ content, ... }
    property var renderInputArea: undefined        // Component：整块替换输入区
    property bool clickUpload: true                // enableUpload.clickUpload
    property string inputBoxCls: ""                // 死 prop（QML 无类名）
    property var inputBoxStyle: undefined          // 死 prop（QML 无内联样式对象）

    // ---- 官方回调 ----
    signal send(string content, var attachment)
    signal clearContext
    signal inputChange(var props)                  // { inputValue, attachment }

    // 内部状态（官方 InputBoxState）
    property string content: ""
    property var attachment: []

    readonly property real paddingHorizontal: 16   // $spacing-chat_inputBox-paddingX
    readonly property real paddingY: 8             // $spacing-chat_inputBox-paddingTop/Bottom

    // 官方 getDisableSend（inputboxFoundation.ts:72-86）
    readonly property bool internalDisabled: {
        if (typeof root.canSend === "boolean")
            return !root.canSend;
        const empty = root.content.length === 0 && root.attachment.length === 0;
        let pending = false;
        for (let i = 0; i < root.attachment.length; ++i) {
            if (root.attachment[i].status !== "success") {
                pending = true;
                break;
            }
        }
        return root.disableSend || empty || pending;
    }

    implicitWidth: inner.implicitWidth + root.paddingHorizontal * 2
    // renderInputArea 接管时整块替换（官方 renderInputArea 返回值顶掉整个 -inputBox，
    // 不吃 paddingY）⇒ 隐式高改吃槽自己的高；否则宿主按默认输入区（单行 ~70）算，
    // 自定义槽（如带 TextArea 的 ~160）溢出 Stage 底边被裁、按钮掉出去点不到
    implicitHeight: customInput.status === Loader.Ready && customInput.item !== null
        ? (customInput.item as Item).implicitHeight
        : inner.implicitHeight + root.paddingY * 2

    // 上传组件：附件列表由这里管（fileList 受控），界面用自己的 Attachment 画
    Upload {
        id: upload

        visible: false
        listType: "none"
        fileList: root.attachment
        action: root.uploadProps.action !== undefined ? root.uploadProps.action : ""
        multiple: root.uploadProps.multiple !== undefined
            ? root.uploadProps.multiple : true

        onChange: function (info) {
            root.attachment = info.fileList;
            root.inputChange({ inputValue: root.content, attachment: root.attachment });
        }
    }

    Item {
        id: inner

        // renderInputArea 接管时官方整块不再渲染 defaultNode（只作为节点传给
        // 自定义渲染决定用不用）⇒ 默认输入区隐藏，避免两套 UI 叠画
        visible: customInput.status !== Loader.Ready
        x: root.paddingHorizontal
        y: root.paddingY
        implicitWidth: clearBtn.width + container.implicitWidth + 4
        // inner 高 = max(清除钮外边距盒 48+4×2, 容器高)：官方 -inner 是 flex-end，
        // clearButton 的 marginY(4px) 上下都算进占位；钮隐藏时官方不渲染 ⇒ 不占
        implicitHeight: Math.max(root.showClearContext ? clearBtn.height + 8 : 0,
            container.implicitHeight)

        // 官方 container 是 flex 行三兄弟平级：upload(32) | inputArea(flex) | send(32)，
        // 零内隙 ⇒ inputArea（文本区 + 附件条）宽度要给两侧按钮各留 32。
        // 端口的发送钮是锚在 container 右下的，文本行得自己扣掉那一列，
        // 否则右缘会钻到发送钮底下（点击显形的 border 正好压在钮上）。
        readonly property real inputAreaWidth: container.width - 22
            - (root.clickUpload ? 36 : 0) - 32

        // ---- 清除上下文钮：48px 圆、borderless primary、icon 30px、色 text-2 ----
        // （chat.scss:383-398；Button 缺省 primary 色对不上，本地画）
        Item {
            id: clearBtn

            objectName: "chatClearButton"

            visible: root.showClearContext
            // 官方 -inner 是 flex-end（外边距盒底对齐）+ clearButton marginY 4px
            // ⇒ 钮的 border box 底缘比容器底缘高 4、单行时近似垂直居中（顶2底4）
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4            // $spacing-chat_inputBox-marginY
            x: 0
            width: 48                               // $width-chat_inputBottom_clearButton
            height: 48

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: clearHover.hovered ? Theme.current.colorFill0 : "transparent"
            }

            Icon {
                anchors.centerIn: parent
                name: "delete_stroked"
                size: 30                            // $font-…-clearButton_icon-fontSize
                color: Theme.current.colorText2     // $color-chat_inputBottom_clearButton_icon
            }

            HoverHandler {
                id: clearHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.clearContext()
            }
        }

        // ---- 容器 ----
        Rectangle {
            id: container

            objectName: "chatInputContainer"

            // 官方 -inner 里 clearNode 是条件渲染（showClearContext && clearNode）
            // ⇒ 隐藏时 container 顶到 inner 左缘、不留空档
            x: root.showClearContext ? clearBtn.width + 4 : 0
            // flex-end：容器也贴 inner 底（inner 被 clearBtn 外边距盒撑高时容器让出顶距）
            anchors.bottom: parent.bottom
            width: root.width - root.paddingHorizontal * 2
                - (root.showClearContext ? clearBtn.width + 4 : 0)
            // 绑 implicitHeight 而不是 height：inner.implicitHeight 读的是它
            // （height 显式赋值后 implicitHeight 仍是 0 ⇒ 宿主恒 64、多行时
            //   发送钮底缘伸出宿主被 Chat 底边裁掉）
            implicitHeight: containerCol.implicitHeight + 22    // padding 11×2
            color: "transparent"
            radius: 16                              // $radius-chat_inputBox_container
            border.width: 1
            border.color: Theme.current.colorBorder

            // 点击容器任意空白处聚焦输入框（官方 inner onClick → inputAreaRef.focus()）
            TapHandler {
                onTapped: textArea.focusInput()
            }

            Column {
                id: containerCol

                x: 11
                y: 11
                width: parent.width - 22
                spacing: 4

                Row {
                    spacing: 4

                    // ---- 上传钮：32px、icon extra-large、色 text-0 ----
                    // （chat.scss:400-412；Tooltip 包裹见 uploadTipProps）
                    Item {
                        id: uploadBtn

                        objectName: "chatUploadButton"

                        visible: root.clickUpload
                        width: 32                   // $width-chat_inputBottom_uploadButton
                        height: 32

                        Loader {
                            anchors.fill: parent
                            active: root.uploadTipProps !== undefined
                                && root.uploadTipProps !== null
                            sourceComponent: tooltipComp
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.current.radiusSmall
                            color: uploadHover.hovered ? Theme.current.colorFill0 : "transparent"
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: "chain_stroked"
                            size: Theme.current.widthIconExtraLarge   // size="extra-large"
                            color: Theme.current.colorText0   // $color-chat_inputBottom_uploadButton_icon
                        }

                        HoverHandler {
                            id: uploadHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: upload.openFileDialog()
                        }
                    }

                    // ---- 文本区：官方 autosize {minRows:1, maxRows:5} ----
                    // 官方聊天框不走 TextArea 的 borderless prop（那个语义是
                    // 「聚焦/悬浮时显边框」），而是 chat.scss 给 -inputBox-textarea
                    // 无条件 `border: none`（特异性压过 focus 档）⇒ 点击也无边框。
                    TextArea {
                        id: textArea

                        objectName: "chatTextArea"

                        width: inner.inputAreaWidth
                        placeholderText: root.placeholder
                        borderless: true
                        border.width: 0
                        autosize: ({ minRows: 1, maxRows: 5 })

                        onTextChanged: {
                            root.content = text;
                            root.inputChange({ inputValue: text, attachment: root.attachment });
                        }

                        // 官方 onEnterPress（inputboxFoundation.ts:96-105）：
                        // enter 档 Shift+Enter 换行不发送；shift+enter 档反过来。
                        // TextArea 只有 Return 会转发 keyPressed（内层 Keys.onReturnPressed），
                        // 按下时先把 accepted 置 false 再转发，这里置 true 即挡掉换行。
                        onKeyPressed: function (event) {
                            if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                                return;
                            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                            if (root.sendHotKey === "enter" && shift)
                                return;                         // 换行
                            if (root.sendHotKey === "shift+enter" && !shift)
                                return;                         // 换行
                            event.accepted = true;              // 挡掉默认换行
                            root.trySend();
                        }
                    }
                }

                // ---- 附件条（官方在 inputArea 内，同宽不进发送钮地盘）----
                ChatAttachment {
                    objectName: "chatAttachment"

                    visible: root.attachment.length > 0
                    width: inner.inputAreaWidth
                    attachment: root.attachment
                    fileBg: Theme.current.colorFill0

                    onClear: function (item) {
                        const next = [];
                        for (let i = 0; i < root.attachment.length; ++i) {
                            if (root.attachment[i].uid !== item.uid)
                                next.push(root.attachment[i]);
                        }
                        root.attachment = next;
                        root.inputChange({ inputValue: root.content, attachment: next });
                    }
                }
            }

            // ---- 发送钮：32px solid primary、icon large、禁用态 primary-disabled ----
            // （chat.scss:414-424；官方那条 disabled 图标色规则要求 borderless 才命中、
            //   发送钮是 solid ⇒ 是条死规则，禁用态照 Button 通用 disabled 令牌画）
            Item {
                id: sendBtn

                objectName: "chatSendButton"

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 11
                anchors.bottomMargin: 11
                width: 32                           // $width-chat_inputBottom_sendButton
                height: 32

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.current.radiusSmall
                    color: root.internalDisabled ? Theme.current.colorDisabledBg
                        : (sendHover.hovered ? Theme.current.colorPrimaryHover
                            : Theme.current.colorPrimary)
                }

                Icon {
                    anchors.centerIn: parent
                    name: "arrow_up"
                    size: Theme.current.widthIconLarge     // size="large"
                    color: root.internalDisabled ? Theme.current.colorDisabledText
                        : Theme.current.colorWhite
                }

                HoverHandler {
                    id: sendHover
                    enabled: !root.internalDisabled
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: !root.internalDisabled
                    onTapped: root.trySend()
                }
            }
        }
    }

    Component {
        id: tooltipComp

        Tooltip {
            text: root.uploadTipProps !== undefined && root.uploadTipProps !== null
                && root.uploadTipProps.content !== undefined
                ? String(root.uploadTipProps.content) : ""
            target: uploadBtn
        }
    }

    // 官方 onSend（inputboxFoundation.ts:78-86）：禁用直接吞掉；发送后清空两处状态
    function trySend() {
        if (root.internalDisabled)
            return;
        const c = root.content;
        const a = root.attachment;
        root.content = "";
        root.attachment = [];
        textArea.text = "";
        root.send(c, a);
    }

    // Chat 拖拽落盘进来的文件（官方 manualUpload → uploadRef.insert）
    function insertFiles(paths) {
        upload.insert(paths);
    }

    // renderInputArea（interface.ts:59）：整块替换，收 defaultNode / onSend / onClear /
    // detailProps 四颗子节点 + onClick。QML 侧把这些作为属性注入给 Component。
    Loader {
        id: customInput

        anchors.fill: parent
        active: root.renderInputArea !== undefined && root.renderInputArea !== null
        sourceComponent: root.renderInputArea
        visible: status === Loader.Ready

        onLoaded: {
            if (item === null)
                return;
            if ("defaultNode" in item)
                item.defaultNode = inner;
            if ("onSend" in item)
                item.onSend = function (content, attachment) { root.send(content, attachment); };
            if ("onClear" in item)
                item.onClear = function () { root.clearContext(); };
            if ("onClick" in item)
                item.onClick = function () { textArea.focusInput(); };
            if ("detailProps" in item)
                item.detailProps = ({
                    clearContextNode: clearBtn,
                    uploadNode: uploadBtn,
                    inputNode: textArea,
                    sendNode: sendBtn,
                    onClick: function () { textArea.focusInput(); }
                });
        }
    }
}
