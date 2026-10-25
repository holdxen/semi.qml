import QtQuick
import QtTest
import Semi

// Chat 对话。规格照 packages/semi-ui/chat/{index.tsx,chatContent.tsx,attachment.tsx,
// hint.tsx,interface.ts,chatBox/*,inputBox/index.tsx} +
// semi-foundation/chat/{foundation.ts,inputboxFoundation.ts,chatBoxActionFoundation.ts,
// constants.ts,chat.scss,variables.scss}，数值对编译产物 chat.css。
//
// 这份用例盯的几条（端口口径全写在 src/Chat*.qml 文件头）：
//   · chats / hints **全受控**：组件只发 chatsChange，自己绝不写回；
//   · 末条状态变化（流式更新）与新增条都触发自动滚底，但**用户滚过一次轮**之后
//     停掉（wheelScroll 闩），发送消息时重置；hint 点击**不**重置闩；
//   · clearContext 只在末条不是分隔线时追加一条 role="divider"；
//   · resetMessage 无条件替换**最后一条**并保留其余字段，传入的 message 只透传给回调；
//   · like / dislike 互斥（置一个必清另一个）；
//   · 回底钮距底 ≤100 隐藏（SHOW_SCROLL_GAP），停止生成钮优先于回底钮、并禁用发送；
//   · escapeHtml 只转义 **user** 消息、只转围栏/行内代码之外的 `<`；
//   · 操作区：copy 仅 complete、反馈仅非 user+complete、reset 仅末条 assistant、
//     delete 恒在；未完成（loading/incomplete）恒隐，完成态 hover 或 reset 常显才露；
//   · continueSend（与上一条同角色）时头像占位不可见、标题**完全不渲染**；
//   · sendHotKey=enter 时 Shift+Enter 只换行不发送，shift+enter 档反之；
//   · canSend 是 boolean 三态：undefined 交给内部判断（空内容/附件未成功则禁发）。
//
// 跑法（本仓约定，优先 offscreen）：
//   QT_QPA_PLATFORM=offscreen ./cmake-build-debug/tests/tst_semi -input tests/tst_chat.qml
TestCase {
    id: testCase

    name: "Chat"
    when: windowShown
    width: 800
    height: 640

    property var model: []
    property var hints: []
    property var lastHint: null
    property var sendCalls: []
    property var msgSends: []
    property var goodCalls: []
    property var badCalls: []
    property var copyCalls: []
    property var delCalls: []
    property var resetCalls: []
    property var clearCalls: []
    property var inputChanges: []

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
        testCase.model = [];
        testCase.hints = [];
        testCase.lastHint = null;
        testCase.sendCalls = [];
        testCase.msgSends = [];
        testCase.goodCalls = [];
        testCase.badCalls = [];
        testCase.copyCalls = [];
        testCase.delCalls = [];
        testCase.resetCalls = [];
        testCase.clearCalls = [];
        testCase.inputChanges = [];
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
    }

    function cleanup() {
        Theme.reset();
        Theme.mode = Theme.Light;
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(msgs, extra) {
        testCase.model = msgs !== undefined && msgs !== null ? msgs : [];
        const o = Qt.createQmlObject(
            "import Semi; Chat { objectName: 'theChat'; x: 0; y: 0;"
            + "width: 560; height: 480;"
            + "chats: testCase.model;"
            + "onChatsChange: (c) => { testCase.model = c; }"
            + "onHintClick: (h) => { testCase.lastHint = h; }"
            + "onMessageSend: (content, attachment) => { testCase.msgSends.push([content, attachment]); }"
            + "onInputChange: (props) => { testCase.inputChanges.push(props); }"
            + "onMessageGoodFeedback: (m) => { testCase.goodCalls.push(m); }"
            + "onMessageBadFeedback: (m) => { testCase.badCalls.push(m); }"
            + "onMessageCopy: (m) => { testCase.copyCalls.push(m); }"
            + "onMessageDelete: (m) => { testCase.delCalls.push(m); }"
            + "onMessageReset: (m) => { testCase.resetCalls.push(m); }"
            + "onClear: () => { testCase.clearCalls.push(1); }"
            + (extra !== undefined ? extra : "")
            + "}", testCase, "chat");
        wait(150);
        return o;
    }

    // 收集所有同名节点（TestCase.findChild 只返回第一个）
    function collect(owner, name) {
        const out = [];
        function walk(item) {
            for (let i = 0; i < item.children.length; ++i) {
                const c = item.children[i];
                if (c.objectName === name)
                    out.push(c);
                walk(c);
            }
        }
        walk(owner);
        return out;
    }

    // 只数可见的：dividerText / chatCodeBlock 这类节点每条消息都实例化、
    // 靠 visible 区分（官方也是每条都渲染、条件隐藏）
    function collectVisible(owner, name) {
        return collect(owner, name).filter(function (n) { return n.visible; });
    }

    function boxAt(chat, i) {
        const boxes = collect(chat, "chatBoxContentHost");
        verify(i < boxes.length, "第 " + i + " 条会话内容盒存在（共 " + boxes.length + "）");
        // 内容盒的父链：contentHost → ChatBox 根
        return boxes[i].parent;
    }

    // 内容盒（Item）—— 几何断言用它，id 在组件外不可见，走 findChild
    function hostAt(chat, i) {
        const boxes = collect(chat, "chatBoxContentHost");
        verify(i < boxes.length, "第 " + i + " 条内容盒存在（共 " + boxes.length + "）");
        return boxes[i];
    }

    // ---------------------------------------------------------------- 默认值
    function test_defaultsMatchOfficial() {
        const chat = make();
        compare(chat.align, "leftRight");           // index.tsx:74
        compare(chat.mode, "bubble");               // :76
        compare(chat.escapeHtml, true);             // :80
        compare(chat.showStopGenerate, false);      // :75
        compare(chat.showClearContext, false);      // :77
        compare(chat.sendHotKey, "enter");          // :78
        compare(chat.wheelScroll, false);
    }

    // ---------------------------------------------------------------- align / mode
    function test_alignLeftRightPutsUserOnRight() {
        const chat = make([
            { role: "user", id: "1", content: "左边还是右边" },
            { role: "assistant", id: "2", content: "看 align" }
        ]);
        const user = boxAt(chat, 0);
        const bot = boxAt(chat, 1);
        compare(user.rightAligned, true, "leftRight 下 user 靠右");
        compare(bot.rightAligned, false, "assistant 永远靠左");
        verify(hostAt(chat, 0).x > 0, "user 内容盒右移");
        // 官方 flex row + column-gap 12：头像槽恒占 24 ⇒ 左侧行 wrap 从 36 起
        compare(hostAt(chat, 1).x, 36, "assistant 内容盒让开头像槽");

        chat.align = "leftAlign";
        wait(50);
        compare(boxAt(chat, 0).rightAligned, false, "leftAlign 下 user 也靠左");
        compare(hostAt(chat, 0).x, 36, "leftAlign 下 user 内容盒同样让开头像槽");
    }

    function test_modeBubbles() {
        const chat = make([
            { role: "user", id: "1", content: "hi" },
            { role: "assistant", id: "2", content: "hello" }
        ]);
        const user = boxAt(chat, 0);
        const bot = boxAt(chat, 1);

        // bubble：全员有泡；user 底 primary、其他 fill-0
        compare(user.bubbleOn, true);
        compare(bot.bubbleOn, true);
        compare(user.bubbleUser, true);
        compare(bot.bubbleUser, false);
        compare(user.contentBg.toString(), Theme.current.colorPrimary.toString());
        compare(bot.contentBg.toString(), Theme.current.colorFill0.toString());

        // noBubble：都没泡
        chat.mode = "noBubble";
        wait(50);
        compare(boxAt(chat, 0).bubbleOn, false);
        compare(boxAt(chat, 1).bubbleOn, false);

        // userBubble：只有 user 有泡
        chat.mode = "userBubble";
        wait(50);
        compare(boxAt(chat, 0).bubbleOn, true, "userBubble 档 user 有泡");
        compare(boxAt(chat, 1).bubbleOn, false, "userBubble 档 assistant 无泡");
    }

    function test_errorStatusRedBubble() {
        const chat = make([
            { role: "assistant", id: "1", content: "炸了", status: "error" }
        ]);
        const bot = boxAt(chat, 0);
        compare(bot.status, "error");
        compare(bot.bubbleError, true);
        compare(bot.contentBg.toString(), Theme.current.colorDangerHover.toString());
    }

    function test_continueSendHidesAvatarAndTitle() {
        const chat = make([
            { role: "user", id: "1", content: "第一条" },
            { role: "user", id: "2", content: "同角色连发" }
        ], "roleConfig: ({ user: { name: '用户甲' } })");
        const first = boxAt(chat, 0);
        const second = boxAt(chat, 1);
        compare(first.continueSend, false);
        compare(second.continueSend, true, "同角色第二条 continueSend");
        // 头像：官方 visibility hidden 占位
        const avatars = collect(chat, "chatBoxAvatar");
        compare(avatars.length, 2);
        compare(avatars[0].visible, true);
        compare(avatars[1].visible, false, "continueSend 头像不可见但占位");
        // 标题：完全不渲染 ⇒ 高度0且不可见
        compare(second.titleH, 0, "continueSend 标题不留行盒");
        compare(first.titleH, 20);
        // 标题内容取 roleConfig.name
        const titles = collect(chat, "chatBoxTitle");
        compare(titles.length, 2);
        compare(titles[0].text, "用户甲");
    }

    function test_roleConfigApplied() {
        const chat = make(
            [{ role: "assistant", id: "1", content: "hi" }],
            "roleConfig: ({ assistant: { name: '小助', avatar: '', color: 'blue' } })");
        const bot = boxAt(chat, 0);
        compare(bot.info.name, "小助");
        const title = collect(chat, "chatBoxTitle")[0];
        compare(title.text, "小助");
        const avatar = collect(chat, "chatBoxAvatar")[0];
        compare(avatar.color, "blue");
    }

    // ---------------------------------------------------------------- 操作区
    function test_actionBarRules() {
        const chat = make([
            { role: "user", id: "1", content: "hi" },
            { role: "assistant", id: "2", content: "loading...", status: "loading" }
        ]);
        // 未完成（loading）：整条操作区恒隐，hover 也不露
        const loading = boxAt(chat, 1);
        compare(loading.finished, false);
        compare(loading.lastChat, true);
        const action = collect(chat, "chatBoxAction")[1];
        compare(action.visible, false, "loading 操作区恒隐（-hidden 优先）");
        // copy 仅 complete
        const copyGlyphs = collect(chat, "chatActionCopy");
        compare(copyGlyphs[1].visible, false, "loading 不渲染 copy");
        // 重置仅末条 assistant（loading 时 showReset 仍为 true，但整条被 -hidden 压住）
        compare(loading.showReset, true);

        // 完成态：末条 assistant 常显（-show）
        testCase.model = [
            { role: "user", id: "1", content: "hi" },
            { role: "assistant", id: "2", content: "done" }
        ];
        wait(80);
        const done = boxAt(chat, 1);
        compare(done.finished, true);
        const action2 = collect(chat, "chatBoxAction")[1];
        compare(action2.visible, true, "末条 assistant 完成态常显");
        // 非末条 assistant：hover 才露
        const first = boxAt(chat, 0);
        compare(first.showReset, false, "非末条无 reset");
        const action1 = collect(chat, "chatBoxAction")[0];
        compare(action1.visible, false, "非末条默认隐");

        // hover 第一条（user）⇒ 操作区露出 ⇒ copy 可见（QML 的 visible 读回有效可见性，
        // 未 hover 时整条操作区隐藏会连带读 false，所以先 hover）
        const box1 = boxAt(chat, 0);
        mouseMove(box1, box1.width / 2, box1.height / 2);
        tryCompare(collect(chat, "chatActionCopy")[0], "visible", true, 1000,
            "hover 后 user 的 copy 露出");
        // 反馈钮不在 user 上渲染：hover 后仍不可见
        const likes = collect(chat, "chatActionLike");
        compare(likes[0].visible, false, "user 无反馈钮（hover 后也无）");
        compare(likes[1].visible, true, "assistant 有反馈钮（末条常显）");
        // 删除恒在
        const dels = collect(chat, "chatActionDelete");
        compare(dels.length, 2);
        compare(dels[0].visible, true);
    }

    function test_likeDislikeExclusive() {
        const chat = make([
            { role: "assistant", id: "1", content: "hi" }
        ]);
        const bot = boxAt(chat, 0);
        chat.likeMessage(bot.msg);
        wait(50);
        compare(testCase.model[0].like, true);
        compare(testCase.goodCalls.length, 1, "点赞回调只发一次");
        chat.dislikeMessage(testCase.model[0]);
        wait(50);
        compare(testCase.model[0].like, false, "点踩必清掉赞（foundation.ts:253-261）");
        compare(testCase.model[0].dislike, true);
        compare(testCase.badCalls.length, 1);
        // 再点赞，dislike 清掉
        chat.likeMessage(testCase.model[0]);
        wait(50);
        compare(testCase.model[0].like, true);
        compare(testCase.model[0].dislike, false);
    }

    function test_deleteViaPopconfirm() {
        const chat = make([
            { role: "assistant", id: "1", content: "hi" }
        ]);
        // C.Popup 不在 Item 树里（findChild 只走 children）；操作区在末条 assistant
        // 完成态常显（showReset），点删除钮 ⇒ 气泡弹出 ⇒ actionPopVisible 翻真
        const action = collect(chat, "chatBoxAction")[0];
        compare(action.visible, true, "末条 assistant 操作区常显");
        compare(action.actionPopVisible, false);
        const glyph = collect(chat, "chatActionDelete")[0];
        mouseClick(glyph, glyph.width / 2, glyph.height / 2);
        tryCompare(action, "actionPopVisible", true, 1000, "点删除钮弹出确认气泡");
        // foundation 删除路径 + 回调
        chat.deleteMessage(testCase.model[0]);
        wait(50);
        compare(testCase.model.length, 0, "删除后消息被滤掉（foundation.ts:231-237）");
        compare(testCase.delCalls.length, 1);
        compare(testCase.delCalls[0].id, "1", "回调拿到的是被删的那条");
    }

    // ---------------------------------------------------------------- 清除上下文
    function test_clearContextAppendsDividerOnce() {
        const chat = make([
            { role: "user", id: "1", content: "hi" },
            { role: "assistant", id: "2", content: "hello" }
        ]);
        chat.clearContext();
        wait(50);
        compare(testCase.model.length, 3, "clear 后共3条");
        compare(testCase.model[2].role, "divider", "追加一条 divider（foundation.ts:156-169）");
        verify(testCase.model[2].id !== undefined, "divider 有 id");
        compare(testCase.clearCalls.length, 1, "onClear 触发");
        // 分隔线渲染出「上下文已清除」
        const divTexts = collectVisible(chat, "chatDividerText");
        compare(divTexts.length, 1, "可见分隔线文字节点数");
        compare(divTexts[0].text, "上下文已清除", "分隔线文案（locale zh Chat.clearContext）");
        // 末条已是分隔线：no-op
        chat.clearContext();
        wait(50);
        compare(testCase.model.length, 3, "连续两次只加一条");
        compare(testCase.clearCalls.length, 1, "第二次连 onClear 都不发");
    }

    // ---------------------------------------------------------------- 提示信息
    function test_hintClickAppendsUserMessage() {
        const chat = make(
            [{ role: "assistant", id: "1", content: "hi" }],
            "hints: ['告诉我更多', '组件有哪些？']");
        wait(80);
        const hintsRow = collect(chat, "chatHintItem");
        compare(hintsRow.length, 2, "两条提示");
        // 点第一条
        mouseClick(hintsRow[0], hintsRow[0].width / 2, hintsRow[0].height / 2);
        wait(80);
        compare(testCase.model.length, 2, "点击后追加 user 消息（foundation.ts:214-225）");
        compare(testCase.model[1].role, "user");
        compare(testCase.model[1].content, "告诉我更多");
        compare(testCase.lastHint, "告诉我更多", "onHintClick 回调收到原文");
    }

    // ---------------------------------------------------------------- 发送
    function test_sendPlainStringContent() {
        const chat = make([]);
        chat.sendMessage("你好 Semi", []);
        wait(50);
        compare(testCase.model.length, 1);
        compare(testCase.model[0].role, "user");
        compare(testCase.model[0].content, "你好 Semi", "无附件时 content 就是字符串");
        compare(testCase.msgSends.length, 1);
        compare(testCase.msgSends[0][0], "你好 Semi");
        verify(testCase.model[0].id !== undefined && testCase.model[0].createAt !== undefined);
    }

    function test_sendBuildsContentArrayWithAttachments() {
        const chat = make([]);
        chat.sendMessage("看图", [
            { name: "pic.png", url: "file:///tmp/pic.png", size: "10 KB", type: "image/png" },
            { name: "doc.pdf", url: "file:///tmp/doc.pdf", size: "20 KB", type: "application/pdf" }
        ]);
        wait(50);
        const c = testCase.model[0].content;
        compare(c.length, 3, "text + image + file 三段");
        compare(c[0].type, "text");
        compare(c[0].text, "看图");
        compare(c[1].type, "image_url", "image/ 前缀判图（foundation.ts:179-183）");
        compare(c[1].image_url.url, "file:///tmp/pic.png");
        compare(c[2].type, "file_url");
        compare(c[2].file_url.name, "doc.pdf");
        compare(c[2].file_url.size, "20 KB");
    }

    function test_inputBoxSendFlow() {
        const chat = make([]);
        const inputBox = findChild(chat, "chatInputBox");
        verify(inputBox !== null && inputBox !== undefined, "输入区存在");
        const ta = findChild(chat, "chatTextArea");
        verify(ta !== null && ta !== undefined, "文本区存在");
        ta.text = "输入框打的字";
        wait(30);
        // inputChange 带 {inputValue, attachment}
        verify(testCase.inputChanges.length > 0, "onInputChange 触发");
        const last = testCase.inputChanges[testCase.inputChanges.length - 1];
        compare(last.inputValue, "输入框打的字");
        compare(last.attachment.length, 0);
        // 点发送钮
        const sendBtn = findChild(chat, "chatSendButton");
        verify(sendBtn !== null && sendBtn !== undefined);
        mouseClick(sendBtn, sendBtn.width / 2, sendBtn.height / 2);
        wait(80);
        compare(testCase.model.length, 1, "发送后追加 user 消息");
        compare(testCase.model[0].content, "输入框打的字");
        compare(ta.text, "", "发送后清空输入框（inputboxFoundation.ts:78-85）");
    }

    function test_inputBoxNoBorderAndSendColumnReserved() {
        // 用户报：点击输入框出现内部 border 且压到发送钮。两处官方口径：
        // ① chat.scss 对 -inputBox-textarea 无条件 `border: none`（特异性压过
        //    textarea.scss 的 focus 档）⇒ 聚焦也不显边框（borderless prop 的
        //    「聚焦显形」语义是错的工具）
        // ② 官方 container 是 flex 行三兄弟平级 upload|inputArea|send ⇒
        //    文本区宽度要给发送钮留出 32，右缘不得越进发送钮
        const chat = make([]);
        const ta = findChild(chat, "chatTextArea");
        const sendBtn = findChild(chat, "chatSendButton");
        compare(ta.border.width, 0, "未聚焦时无边框");
        ta.forceActiveFocus();
        wait(60);
        compare(ta.activeFocus, true, "聚焦成功（否则这条断言空转）");
        compare(ta.border.width, 0, "聚焦后仍无边框（官方 border:none 无条件）");
        // 发送钮左缘（chat 坐标系）—— 文本区右缘必须 <= 它
        const sendLeft = sendBtn.mapToItem(chat, 0, 0).x;
        const taRight = ta.mapToItem(chat, ta.width, 0).x;
        verify(taRight <= sendLeft, "文本区右缘 " + taRight
            + " 不越发送钮左缘 " + sendLeft);
        // 附件条同宽（官方在 inputArea 内）
        const att = findChild(chat, "chatAttachment");
        compare(att.width, ta.width, "附件条与文本区同宽");
        // 顺带钉容器空档：清除钮隐藏时 container 顶到 inner 左缘（官方条件渲染）
        const box = findChild(chat, "chatInputContainer");
        const clear = findChild(chat, "chatClearButton");
        compare(clear.visible, false);
        compare(box.x, 0, "清除钮隐藏时容器不留空档");
        chat.showClearContext = true;
        wait(60);
        compare(box.x, clear.width + 4, "清除钮显示时容器让位");
    }

    function test_clearButtonAlignsLikeOfficialFlexEnd() {
        // 用户报：清除钮和输入框没对齐（端口钮底缘贴容器底、整体偏下）。
        // 官方口径：-clearButton 有 marginY(4px) 上下外边距、-inner 是
        // align-items: flex-end（外边距盒底对齐）⇒ 钮的 border box
        // 底缘 = 容器底缘 − 4；单行容器(54)时钮[2,50]、近似垂直居中。
        const chat = make([], "; showClearContext: true");
        const clear = findChild(chat, "chatClearButton");
        const box = findChild(chat, "chatInputContainer");
        compare(clear.visible, true, "清除钮在（否则断言空转）");
        // inner 高 = max(clearBtn 外边距盒 48+8, 容器高)：单行容器 54 < 56
        // ⇒ 宿主被外边距盒撑到 72（= 容器 54 + 18），这 2px 就是外边距盒的占位
        const host0 = findChild(chat, "chatInputHost");
        compare(host0.height, box.height + 18,
            "单行时 inner 被 clearBtn 外边距盒撑高（56 vs 容器 54）");
        // 以 container 为参照量（官方全部距离都相对容器）
        const cTop = clear.mapToItem(box, 0, 0).y;
        const cBot = clear.mapToItem(box, 0, clear.height).y;
        compare(box.height - cBot, 4, "钮底缘距容器底 4（marginY）");
        compare(cTop, box.height - 52, "钮顶距 = 容器高 − 52（flex-end 反推）");
        // 多行：容器长高，钮贴底跟随（底距恒 4）
        const ta = findChild(chat, "chatTextArea");
        ta.text = "1\n2\n3\n4\n5";
        wait(200);
        verify(box.height > 100, "五行撑高容器");
        const cBot5 = clear.mapToItem(box, 0, clear.height).y;
        compare(box.height - cBot5, 4, "多行时底距仍 4（flex-end 跟随）");
        // inner 高要把 clearBtn 的外边距盒（48+8）算进占位，钮隐藏时不占
        const host = findChild(chat, "chatInputHost");
        chat.showClearContext = false;
        wait(60);
        compare(clear.visible, false);
        compare(host.height, box.height + 16, "钮隐藏后宿主回落到 容器+16");
    }

    function test_clickContainerBlankFocusesAndTypes() {
        // 用户报：自定义输入框无法输入文字。探针实锤两条路径：
        // ① 槽内自带 TextArea 打得进字（组件层无焦点 bug）
        // ② 点容器空白处打不进 —— forceActiveFocus() 聚焦的是 TextArea 根
        //    Rectangle，键 events 到不了内层 TextEdit（官方 inner onClick
        //    聚焦的是 <textarea> 本体）⇒ TextArea 加 focusInput()，三处调用点换用
        const chat = make([]);
        const ta = findChild(chat, "chatTextArea");
        const box = findChild(chat, "chatInputContainer");
        ta.text = "";
        // 点容器左下角空白（不落在文本区/按钮上）
        mouseClick(box, 6, box.height - 6);
        wait(60);
        compare(ta.activeFocus, false, "根 Rectangle 不该拿焦点");
        keyClick(Qt.Key_Y);
        wait(60);
        compare(ta.text, "y", "点容器空白处聚焦后打字进框（focusInput 聚焦内层 TextEdit）");
    }

    function test_inputBoxGrowsWithMultilineText() {
        // 用户报：多行文本时发送钮显示不全。根因是 container 只绑了 height
        // 没绑 implicitHeight（Rectangle 缺省 0）⇒ inner.implicitHeight 恒 48、
        // 宿主恒 64，容器长高后发送钮底缘伸出宿主被 Chat 底边裁掉。
        const chat = make([]);
        const ta = findChild(chat, "chatTextArea");
        const host = findChild(chat, "chatInputHost");
        const sendBtn = findChild(chat, "chatSendButton");
        const box = findChild(chat, "chatInputContainer");
        // 单行基线：宿主至少装得下容器
        verify(host.height >= box.height, "单行时宿主装得下容器");
        // 打满 5 行（autosize maxRows）
        ta.text = "第一行\n第二行\n第三行\n第四行\n第五行";
        wait(200);
        verify(box.height > 100, "五行把容器撑高（实际 " + box.height + "）");
        // 行为判据：发送钮必须完整落在宿主内 —— 这就是「显示不全」的直接症状
        const sendBottom = sendBtn.mapToItem(host, 0, sendBtn.height).y;
        verify(sendBottom <= host.height, "发送钮底缘 " + sendBottom
            + " 在宿主高 " + host.height + " 之内");
        // 机制：宿主高度读的是 ChatInputBox.implicitHeight ⇒ container 必须绑 implicitHeight
        compare(box.implicitHeight, box.height, "container 的 implicitHeight 跟内容");
        compare(host.height, box.height + 16, "宿主跟到 容器高+上下 padding 8×2");
    }

    function test_textAreaHitHeightFollowsContentWithoutLoop() {
        // 用户报：长内容时 TextArea.qml:248 报 Binding loop for height。
        // 环 = height 绑定读自身 implicitHeight，而 Qt「改 height → geometryChange →
        // updateSize → setImplicitHeight」会回写并通知 implicitHeight ⇒ 自指。
        // 修法是自指项换成 contentHeight（同一处算出、无回路）——两者几何等值，
        // 判决性证据是探针警告计数 6 → 0（tests/tmp_textarea_loop_repro.qml + grep）。
        // 这里钉公式的两个档位，防止将来改回自指或砍掉某一档：
        const chat = make([]);
        const ta = findChild(chat, "chatTextArea");
        const scroller = findChild(chat, "textareaScroller");
        const area = scroller.contentItem.children[0];   // 内层 TextEdit
        // 档位一：内容比盒子矮 ⇒ 命中区填满盒子（官方 textarea 点空白处光标落文末）
        ta.text = "短";
        wait(80);
        compare(area.height, Math.max(area.contentHeight, scroller.height - 5),
            "矮内容档：命中区 = max(内容高, 盒子高-paddingY)");
        verify(area.height >= scroller.height - 5, "矮内容档填满盒子");
        // 档位二：一行超长软换行撑过盒子（原报警路径）⇒ 跟随内容、可滚动
        let s = "";
        for (let i = 0; i < 40; ++i)
            s += "长内容";
        ta.text = s;
        wait(200);
        verify(area.contentHeight > scroller.height, "长内容确实超过盒子");
        compare(area.height, area.contentHeight, "高内容档：命中区跟随内容高（可滚动点到）");
    }

    function test_disableSendRules() {
        const chat = make([]);
        const inputBox = findChild(chat, "chatInputBox");
        const ta = findChild(chat, "chatTextArea");
        // 空内容：禁发
        compare(inputBox.internalDisabled, true, "空内容禁发");
        ta.text = "x";
        wait(30);
        compare(inputBox.internalDisabled, false);
        // canSend=false 覆盖
        chat.canSend = false;
        wait(30);
        compare(inputBox.internalDisabled, true, "canSend=false 盖过内部判断");
        chat.canSend = true;
        wait(30);
        compare(inputBox.internalDisabled, false, "canSend=true 强制可发（即使空）");
    }

    function test_sendHotKeyEnterVsShiftEnter() {
        const chat = make([], "sendHotKey: 'enter'");
        const ta = findChild(chat, "chatTextArea");
        verify(ta !== null && ta !== undefined, "文本区存在");
        ta.text = "enter 档";
        wait(30);
        // enter 档：Shift+Enter 只换行不发送
        const evShift = { key: Qt.Key_Return, modifiers: Qt.ShiftModifier, accepted: false };
        ta.keyPressed(evShift);
        wait(30);
        compare(testCase.model.length, 0, "enter 档 Shift+Enter 不发送");
        compare(evShift.accepted, false, "让默认换行发生");
        // 纯 Enter 发送
        const evEnter = { key: Qt.Key_Return, modifiers: 0, accepted: false };
        ta.keyPressed(evEnter);
        wait(30);
        compare(testCase.model.length, 1, "enter 档纯 Enter 发送");
        compare(evEnter.accepted, true, "挡掉默认换行");
    }

    function test_sendHotKeyShiftEnterMode() {
        const chat = make([], "sendHotKey: 'shift+enter'");
        const ta = findChild(chat, "chatTextArea");
        verify(ta !== null && ta !== undefined, "文本区存在");
        ta.text = "shift 档";
        wait(30);
        // shift+enter 档：纯 Enter 只换行
        const evEnter = { key: Qt.Key_Return, modifiers: 0, accepted: false };
        ta.keyPressed(evEnter);
        wait(30);
        compare(testCase.model.length, 0, "shift+enter 档纯 Enter 不发送");
        // Shift+Enter 发送
        const evShift = { key: Qt.Key_Return, modifiers: Qt.ShiftModifier, accepted: false };
        ta.keyPressed(evShift);
        wait(30);
        compare(testCase.model.length, 1, "shift+enter 档 Shift+Enter 发送");
    }

    // ---------------------------------------------------------------- 滚动
    function test_backBottomThreshold() {
        // 造足够多消息撑出滚动
        const msgs = [];
        for (let i = 0; i < 30; ++i)
            msgs.push({ role: "user", id: String(i), content: "消息 " + i });
        const chat = make(msgs);
        wait(200);
        const container = findChild(chat, "chatContainer");
        verify(container !== null && container !== undefined);
        verify(container.contentHeight > container.height, "内容撑出滚动");
        // 挂载即滚底
        compare(chat.backBottomVisible, false, "init 后在底部，回底钮隐藏（foundation.ts:80-83）");
        // 滚上去
        container.contentY = 0;
        wait(50);
        compare(chat.backBottomVisible, true, "距底 >100 显示回底钮（SHOW_SCROLL_GAP）");
        // 回到底部
        container.contentY = container.contentHeight - container.height;
        wait(50);
        compare(chat.backBottomVisible, false);
        // 点回底钮走动画
        container.contentY = 0;
        wait(30);
        const btn = findChild(chat, "chatBackBottom");
        verify(btn !== null && btn !== undefined && btn.visible, "回底钮可见");
        mouseClick(btn, btn.width / 2, btn.height / 2);
        tryCompare(container, "contentY", container.contentHeight - container.height, 600);
    }

    function test_autoScrollAndWheelLatch() {
        const msgs = [];
        for (let i = 0; i < 30; ++i)
            msgs.push({ role: "user", id: String(i), content: "消息 " + i });
        const chat = make(msgs);
        wait(200);
        const container = findChild(chat, "chatContainer");
        // 新消息 ⇒ 自动滚底（组件侧等布局稳定一帧，settle timer 两个 50ms tick）
        chat.sendMessage("新消息", []);
        tryCompare(container, "contentY", container.contentHeight - container.height, 1000,
            "新增条自动滚底（componentDidUpdate:231-245）");
        // 用户滚一次轮 ⇒ 闩上
        const before = container.contentY;
        mouseWheel(container, 100, 100, 0, -1);
        wait(50);
        compare(chat.wheelScroll, true, "滚过一次轮后闩置位");
        // 闩置位后外部推入新消息（模拟流式回复）：不自动滚底
        const mid = container.contentY;
        const grown = testCase.model.concat([{ role: "assistant", id: "99", content: "流式回复" }]);
        testCase.model = grown;
        wait(80);
        compare(container.contentY, mid, "wheelScroll 闩着时外部推入不抢滚动");
        // 发送消息复位闩（foundation.ts:209-210）⇒ 之后的新消息恢复滚底
        chat.sendMessage("复位用的消息", []);
        tryCompare(chat, "wheelScroll", false, 1000, "发送后闩复位");
        testCase.model = testCase.model.concat([{ role: "assistant", id: "98", content: "复位后推入" }]);
        tryCompare(container, "contentY", container.contentHeight - container.height, 1000,
            "复位后新消息恢复自动滚底");
    }

    function test_streamingSameIdKeepsScrolling() {
        // 末条状态变化（流式）也滚底：长度不变、末条 id 不变、status 从 incomplete → incomplete
        const msgs = [
            { role: "user", id: "1", content: "hi" },
            { role: "assistant", id: "2", content: "流式片段", status: "incomplete" }
        ];
        const chat = make(msgs);
        wait(150);
        const container = findChild(chat, "chatContainer");
        // 撑高内容再滚上去
        testCase.model = [
            { role: "user", id: "1", content: "hi" },
            { role: "assistant", id: "2", content: "流式片段".repeat(200), status: "incomplete" }
        ];
        wait(150);
        verify(container.contentHeight > container.height, "长内容撑出滚动");
        container.contentY = 0;
        wait(50);
        compare(chat.backBottomVisible, true, "滚到顶后回底钮出现");
        // 同长度同 id 追加（status 仍非 complete）⇒ 应当滚底
        testCase.model = [
            { role: "user", id: "1", content: "hi" },
            { role: "assistant", id: "2", content: "流式片段".repeat(300), status: "incomplete" }
        ];
        tryCompare(container, "contentY", container.contentHeight - container.height, 1000,
            "末条非 complete 的同长更新也滚底");
    }

    // ---------------------------------------------------------------- 方法
    function test_resetMessageReplacesLastPreservingFields() {
        const chat = make([
            { role: "assistant", id: "1", content: "旧内容", name: "小助", status: "complete" }
        ]);
        chat.resetMessage(testCase.model[0]);
        wait(50);
        compare(testCase.model.length, 1, "替换不新增");
        const last = testCase.model[0];
        compare(last.status, "loading", "重置后回到 loading");
        compare(last.content, "", "内容清空");
        compare(last.role, "assistant", "role 保留");
        compare(last.name, "小助", "其余字段保留（foundation.ts:273-281 展开原消息）");
        compare(last.id !== "1", true, "id 换新");
        compare(testCase.resetCalls.length, 1, "onMessageReset 回调收到传入的 message");
    }

    function test_scrollToBottomMethods() {
        const msgs = [];
        for (let i = 0; i < 30; ++i)
            msgs.push({ role: "user", id: String(i), content: "消息 " + i });
        const chat = make(msgs);
        wait(200);
        const container = findChild(chat, "chatContainer");
        container.contentY = 0;
        wait(30);
        chat.scrollToBottom(false);
        compare(container.contentY, container.contentHeight - container.height,
            "scrollToBottom(false) 立即到底");
        container.contentY = 0;
        wait(30);
        chat.scrollToBottom(true);
        tryCompare(container, "contentY", container.contentHeight - container.height, 600,
            "scrollToBottom(true) 动画到底（SCROLL_ANIMATION_TIME=300）");
    }

    // ---------------------------------------------------------------- 停止生成
    function test_stopGenerateFlag() {
        const chat = make(
            [{ role: "assistant", id: "1", content: "", status: "loading" }],
            "showStopGenerate: true");
        wait(80);
        compare(chat.showStopFlag, true, "末条 loading + showStopGenerate ⇒ 停止钮亮");
        const stopBtn = findChild(chat, "chatStopButton");
        verify(stopBtn !== null && stopBtn !== undefined);
        compare(stopBtn.visible, true, "停止生成钮显示");
        const backBtn = findChild(chat, "chatBackBottom");
        verify(backBtn !== null && backBtn !== undefined);
        compare(backBtn.visible, false, "停止钮优先，回底钮让位（index.tsx:374）");
        // 输入区被禁发
        const inputBox = findChild(chat, "chatInputBox");
        compare(inputBox.disableSend, true, "生成中禁发（index.tsx:305 disableSend）");
        const ta = findChild(chat, "chatTextArea");
        ta.text = "想插话";
        wait(30);
        compare(inputBox.internalDisabled, true, "disableSend 压过有内容");
        // 生成完毕 ⇒ 停止钮灭、可发
        testCase.model = [{ role: "assistant", id: "1", content: "完了", status: "complete" }];
        wait(80);
        compare(chat.showStopFlag, false);
        compare(inputBox.internalDisabled, false);
        compare(stopBtn.visible, false);
    }

    // ---------------------------------------------------------------- escapeHtml
    function test_escapeHtmlOnlyForUserAndOutsideCode() {
        const chat = make([
            { role: "user", id: "1", content: "用 <b>标签</b> 和 `a<b` 代码" },
            { role: "assistant", id: "2", content: "助手 <i>不转</i>" }
        ]);
        const user = boxAt(chat, 0);
        const bot = boxAt(chat, 1);
        // 官方只转 `<`（escapeHtml.ts 的 replace(/</g, '&lt;')），`>` 原样
        verify(user.mdText.indexOf("&lt;") >= 0, "user 的裸 < 被转义");
        verify(user.mdText.indexOf("<b>") < 0, "不再有裸 <b> 起头的标签");
        verify(user.mdText.indexOf("a<b") >= 0, "行内代码里的 < 不转（escapeHtml.ts 逐行跳过 code span）");
        compare(bot.mdText, "助手 <i>不转</i>", "非 user 不转义");
        // escapeHtml=false 时 user 也不转
        chat.escapeHtml = false;
        wait(50);
        compare(boxAt(chat, 0).mdText, "用 <b>标签</b> 和 `a<b` 代码");
    }

    function test_codeFenceSplitsSegments() {
        const chat = make([
            { role: "assistant", id: "1", content: "前文\n```js\nconst a = 1;\n```\n后文" }
        ]);
        const segs = boxAt(chat, 0).segments;
        compare(segs.length, 3, "text / code / text 三段");
        compare(segs[0].type, "text", "首段 text");
        compare(segs[1].type, "code", "中段 code");
        compare(segs[1].lang, "js", "围栏首行余下的是语言名（code.tsx:18）");
        verify(segs[1].body.indexOf("const a = 1;") >= 0);
        // 代码块顶栏渲染出语言名与复制钮
        const blocks = collectVisible(chat, "chatCodeBlock");
        compare(blocks.length, 1, "一个可见代码块");
        verify(blocks[0].implicitHeight > 0, "代码块有高度");
    }

    // ---------------------------------------------------------------- 自定义渲染
    function test_customRenderHintBox() {
        const chat = make(
            [{ role: "assistant", id: "1", content: "hi" }],
            "hints: ['自定义提示']; renderHintBox: hintBoxComp");
        wait(150);
        const customs = collect(chat, "customHintItem");
        compare(customs.length, 1, "renderHintBox 组件被使用");
        const texts = collect(chat, "customHintText");
        compare(texts.length, 1);
        compare(texts[0].text, "自定义提示", "content 注入成功");
        mouseClick(customs[0], customs[0].width / 2, customs[0].height / 2);
        wait(50);
        compare(testCase.lastHint, "自定义提示", "自定义提示的点击走 onHintClick");
        compare(testCase.model[testCase.model.length - 1].content, "自定义提示");
    }

    function test_customRenderInputArea() {
        const chat = make([{ role: "assistant", id: "1", content: "hi" }],
            "; renderInputArea: inputAreaComp");
        wait(150);
        const custom = findChild(chat, "customInputArea");
        verify(custom !== null && custom !== undefined, "renderInputArea 组件被使用");
        verify(custom.defaultNode !== undefined && custom.defaultNode !== null,
            "defaultNode 注入了默认输入框");
        const texts = collect(chat, "customInputText");
        compare(texts.length, 1);
        compare(texts[0].text, "自定义输入框");
        // 官方整块替换：默认输入区不再渲染（defaultNode 只是传给自定义渲染的引用）
        compare(findChild(chat, "chatTextArea").visible, false,
            "renderInputArea 接管后默认输入区隐藏");
        // 宿主高度链：接管时 ChatInputBox.implicitHeight 吃槽自己的高（官方整块
        // 替换、不吃 paddingY）——否则宿主按默认输入区算，槽溢出 Stage 被裁、
        // 槽内按钮掉出去点不到（用户报「自定义输入框无法输入文字」的第二条根因）
        const host = findChild(chat, "chatInputHost");
        compare(host.height, custom.implicitHeight,
            "宿主高 = 槽的 implicitHeight（整块替换）");
        // 点自定义区 ⇒ onSend 走 Chat.sendMessage
        mouseClick(custom, custom.width / 2, custom.height / 2);
        wait(80);
        compare(testCase.model.length, 2, "自定义 onSend 接进发送管线");
        compare(testCase.model[1].content, "来自自定义");
        compare(testCase.msgSends[0][0], "来自自定义");
    }

    function test_customChatBoxRenderConfig() {
        const chat = make(
            [{ role: "assistant", id: "1", content: "hi" }],
            "; roleConfig: ({ assistant: { name: '小助' } })"
            + "; chatBoxRenderConfig: ({ renderChatBoxTitle: titleSlotComp,"
            + " renderChatBoxAvatar: avatarSlotComp })");
        wait(150);
        const slots = collect(chat, "customTitleSlot");
        compare(slots.length, 1, "renderChatBoxTitle 组件被使用");
        const texts = collect(chat, "customTitleText");
        compare(texts.length, 1);
        compare(texts[0].text, "自定义标题-小助", "message/role 注入成功");
        // renderChatBoxAvatar（chatBoxAvatar.tsx:32-34）：整块替换默认头像
        const avatars = collect(chat, "customAvatarSlot");
        compare(avatars.length, 1, "renderChatBoxAvatar 组件被使用");
        compare(avatars[0].role.name, "小助", "头像槽注入 role");
        compare(avatars[0].defaultAvatar !== undefined
            && avatars[0].defaultAvatar !== null, true, "defaultAvatar 注入默认头像节点");
        compare(findChild(chat, "chatBoxAvatar").visible, false,
            "自定义头像接管后默认头像隐藏");
    }

    function test_customTitleRightAlignsByOwnWidth() {
        // 官方 -wrap 右对齐档 align-items: flex-end：自定义标题按**槽自己的宽度**
        // 右贴（缺省标题的宽度量不出自定义槽）
        const chat = make(
            [{ role: "user", id: "1", content: "hi" }],
            "; roleConfig: ({ user: { name: '小明' } })"
            + "; chatBoxRenderConfig: ({ renderChatBoxTitle: titleSlotComp })");
        wait(150);
        const box = boxAt(chat, 0);
        verify(box.rightAligned, "leftRight 下 user 靠右");
        const slots = collect(chat, "customTitleSlot");
        compare(slots.length, 1);
        verify(slots[0].width > 0, "槽有宽度");
        // objectName 在槽 Component 的根项上（Loader 的子项，自身 x=0）；
        // 右缘要按 chatBox 坐标系量
        const right = slots[0].mapToItem(box, slots[0].width, 0).x;
        compare(right, box.maxContentWidth, "自定义标题右缘贴 maxContentWidth");
    }

    function test_topSlotAndBottomSlot() {
        const chat = make([{ role: "assistant", id: "1", content: "hi" }],
            "; topSlot: topSlotComp; bottomSlot: bottomSlotComp");
        wait(150);
        const top = findChild(chat, "topSlotNode");
        verify(top !== null && top !== undefined, "顶部插槽渲染");
        const bottom = findChild(chat, "bottomSlotNode");
        verify(bottom !== null && bottom !== undefined, "底部插槽渲染");
        // 顺序：top 在内容之上，bottom 在输入区之下
        const container = findChild(chat, "chatContainer");
        verify(top.mapToItem(chat, 0, 0).y < container.mapToItem(chat, 0, 0).y, "topSlot 在聊天区上方");
        verify(bottom.mapToItem(chat, 0, 0).y > container.mapToItem(chat, 0, 0).y, "bottomSlot 在聊天区下方");
    }

    // ---------------------------------------------------------------- 附件芯片
    function test_attachmentChips() {
        const chat = make([]);
        const inputBox = findChild(chat, "chatInputBox");
        inputBox.attachment = [
            { uid: 1, name: "pic.png", url: "file:///tmp/pic.png", size: "10 KB", type: "image/png", status: "success", percent: 100 },
            { uid: 2, name: "doc.pdf", url: "file:///tmp/doc.pdf", size: "20 KB", type: "application/pdf", status: "uploading", percent: 40 }
        ];
        wait(80);
        const strip = findChild(chat, "chatAttachment");
        verify(strip !== null && strip !== undefined, "附件条存在");
        compare(strip.visible, true);
        compare(strip.attachment.length, 2);
        // 图片档与文件档的判据（attachment.tsx:64-65）。
        // Flow 的 children 里混着 Repeater 自身，按 isImg 属性挑出芯片
        const chips = [];
        for (let i = 0; i < strip.children.length; ++i) {
            if ("isImg" in strip.children[i])
                chips.push(strip.children[i]);
        }
        compare(chips.length, 2, "两颗芯片");
        compare(chips[0].isImg, true, "image/ 前缀判图");
        compare(chips[1].isImg, false);
    }

    // ---------------------------------------------------------------- markdown 渲染
    function test_markdownTextFormat() {
        const chat = make([
            { role: "assistant", id: "1", content: "**加粗** 与 [链接](https://semi.design)" }
        ]);
        const texts = collect(chat, "chatBoxText");
        verify(texts.length >= 1, "文本段渲染");
        compare(texts[0].textFormat, Text.MarkdownText, "Qt MarkdownText 承接官方 MarkdownRender");
        verify(texts[0].text.indexOf("**加粗**") >= 0, "原文进 Text（格式由 MarkdownText 解析）");
    }

    // ---------------------------------------------------------------- 自定义渲染的组件
    // （data:text/qml 注入不可靠，声明在测试文件顶层由 createQmlString 的调用作用域解析）
    Component {
        id: hintBoxComp

        Item {
            property string content
            property int index
            property var hintClick
            objectName: "customHintItem"
            width: 120
            height: 30

            Text {
                objectName: "customHintText"
                anchors.centerIn: parent
                text: parent.content
            }

            TapHandler {
                onTapped: parent.hintClick()
            }
        }
    }

    Component {
        id: inputAreaComp

        Item {
            property var defaultNode
            property var onSend
            property var onClear
            property var onClick
            property var detailProps
            objectName: "customInputArea"
            width: 560
            // 绑 implicitHeight：宿主高度链读槽的 implicitHeight，Loader 会覆盖显式 height
            implicitHeight: 40

            Text {
                objectName: "customInputText"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "自定义输入框"
            }

            TapHandler {
                onTapped: parent.onSend("来自自定义", [])
            }
        }
    }

    Component {
        id: titleSlotComp

        Item {
            property var message
            property var role
            property var defaultTitle
            objectName: "customTitleSlot"
            width: 80
            height: 20

            Text {
                objectName: "customTitleText"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "自定义标题-" + parent.role.name
            }
        }
    }

    Component {
        id: avatarSlotComp

        Item {
            property var message
            property var role
            property var defaultAvatar
            objectName: "customAvatarSlot"
            width: 24
            height: 24
        }
    }

    Component {
        id: topSlotComp

        Rectangle {
            objectName: "topSlotNode"
            color: "red"
            width: 100
            height: 24
        }
    }

    Component {
        id: bottomSlotComp

        Rectangle {
            objectName: "bottomSlotNode"
            color: "blue"
            width: 100
            height: 24
        }
    }
}
