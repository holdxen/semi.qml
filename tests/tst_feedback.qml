import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Feedback"
    when: windowShown
    width: 900
    height: 600

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    function test_popconfirmDefaults() {
        const pc = make("Popconfirm { }")
        compare(pc.tone, Enums.Warning)
        compare(pc.okText, "确定")
        compare(pc.cancelText, "取消")
        compare(pc.implicitWidth >= 280, true)
        pc.destroy()
    }

    // Select 的 options 也吃字符串数组，那时选项的标签就是字符串本身。
    // 早先直接读 modelData.label，字符串数组下会拿到 undefined，
    // 下拉里的选项文字整片空白。
    function test_selectAcceptsStringOptions() {
        const s = make('Select { options: ["北京", "上海"]; value: "上海" }')
        compare(s.labelOf("上海"), "上海")
        compare(s.displayText, "上海")
        compare(s.optionValue("北京"), "北京")
        compare(s.optionLabel("北京"), "北京")
        compare(s.optionValue({ label: "广州", value: "gz" }), "gz")
        compare(s.optionLabel({ label: "广州", value: "gz" }), "广州")
        compare(s.optionDisabled({ value: "x", disabled: true }), true)
        compare(s.optionDisabled("北京"), false)
        s.destroy()
    }

    // ---------------- Feedback 反馈卡 ----------------
    // 规格照 semi-ui/feedback（index.tsx:26-47 / :65-72 / :231-234）与
    // semi-foundation/feedback（foundation.ts:22-115、constants.ts:9-17、feedback.scss +
    // variables.scss）。期望值多数写成字面量（400 / 600 / 20 / 50 / 12 / 24 / 36 / 16、
    // 😞😐😃、那两条英文占位文案），改坏组件里的令牌或算式就会红。

    // 打开并等进场动画停到位（popup 180ms / modal 120ms）
    function openFb(qml) {
        const fb = make("Feedback { " + qml + " }")
        fb.visible = true
        wait(240)
        return fb
    }

    function cardOf(fb) {
        return testCase.findChild(fb, "feedbackCard")
    }

    // 蒙层是弹层自己的 background：卡片挂在 contentItem 上，background 挂在弹层项上，
    // 所以要从 card.parent.parent 起找（card.parent 里翻不到）
    function maskOf(fb) {
        return partOf(cardOf(fb).parent.parent, "feedbackMask")
    }

    // testCase.findChild 摸不到 Repeater 造出来的代理（它们只挂在视觉父项上），
    // 所以从 card 起按 children 递归找 —— tst_button 的 findAll 是同一套写法。
    function partOf(node, name) {
        if (node === null || node === undefined)
            return null
        if (node.objectName === name)
            return node
        const kids = node.children
        for (let i = 0; i < kids.length; ++i) {
            const hit = partOf(kids[i], name)
            if (hit !== null)
                return hit
        }
        return null
    }

    // 递归找 Radio / Checkbox 代理（它们没有 objectName，但都带 checked）
    function optionItems(node, out) {
        if (out === undefined)
            out = []
        const kids = node.children
        for (let i = 0; i < kids.length; ++i) {
            const k = kids[i]
            if (!k)
                continue
            if (k.checked !== undefined && k.value !== undefined)
                out.push(k)
            else
                optionItems(k, out)
        }
        return out
    }

    function test_feedbackDefaults() {
        const fb = make("Feedback { }")
        compare(fb.mode, "popup")                       // defaultProps index.tsx:66
        compare(fb.type, "emoji")                       // defaultProps index.tsx:67
        compare(fb.title, "")
        compare(fb.closable, true)
        compare(fb.value, null, "官方 state.value 初值是 null")
        compare(fb.okText, "提交")                       // locale.Feedback.submit
        compare(fb.cancelText, "取消")                    // locale.Feedback.cancel
        compare(fb.submitBlocked, true, "没选任何东西时提交键是禁的")
        compare(cardOf(fb).width, 400)                  // $width-feedback
        compare(cardOf(fb).radius, 12, "$radius-feedback_sidesheet_inner = 12px")
        fb.destroy()
    }

    function test_panelWidthPerTypeAndMode() {
        const text = openFb('type: "text"')
        compare(cardOf(text).width, 600, "popup + text ⇒ $width-feedback_text")
        text.destroy()

        const modalText = openFb('mode: "modal"; type: "text"')
        compare(cardOf(modalText).width, 400, "modal 那一支官方只写了一条 400")
        modalText.destroy()

        const radio = openFb('type: "radio"; radioOptions: ["a", "b"]')
        compare(cardOf(radio).width, 400)
        radio.destroy()
    }

    function test_popupSitsBottomRightModalCentres() {
        const popup = openFb('title: "评分"')
        const pc = cardOf(popup)
        compare(pc.restingX, popup.width - 400 - 20, "$spacing-feedback_sidesheet_bottom-right")
        compare(pc.restingY, popup.height - pc.height - 50,
            "$spacing-feedback_sidesheet_bottom_inner_wrap-bottom")
        popup.destroy()

        const modal = openFb('mode: "modal"; title: "评分"')
        const mc = cardOf(modal)
        compare(mc.restingX, (modal.width - 400) / 2)
        compare(mc.restingY, (modal.height - mc.height) / 2)
        modal.destroy()
    }

    function test_maskOnlyInModalMode() {
        const popup = openFb('title: "评分"')
        compare(maskOf(popup).color.toString(), "#00000000",
            "官方 SideSheet 收 mask={false}")
        popup.destroy()

        const modal = openFb('mode: "modal"; title: "评分"')
        compare(maskOf(modal).color.toString(),
            Theme.current.colorOverlayBg.toString())
        modal.destroy()
    }

    function test_maskTapOnlyClosesModal() {
        const modal = openFb('mode: "modal"; title: "评分"')
        let modalCancel = 0
        modal.cancel.connect(function () { modalCancel++ })
        mouseClick(maskOf(modal), 20, 20)           // 卡片居中，左上角是裸蒙层
        wait(300)
        compare(modalCancel, 1, "点蒙层走的是 onCancel（官方 Modal 的 maskClosable）")
        compare(modal.visible, false)
        modal.destroy()

        const popup = openFb('title: "评分"')
        let popupCancel = 0
        popup.cancel.connect(function () { popupCancel++ })
        mouseClick(maskOf(popup), 20, 20)
        wait(60)
        compare(popupCancel, 0, "popup 那支 mask={false}，蒙层不能接点击")
        compare(popup.visible, true)
        popup.destroy()

        const stiff = openFb('mode: "modal"; title: "评分"; closable: false')
        let stiffCancel = 0
        stiff.cancel.connect(function () { stiffCancel++ })
        mouseClick(maskOf(stiff), 20, 20)
        wait(60)
        compare(stiffCancel, 0, "closable=false 连蒙层也不放行")
        compare(stiff.visible, true)
        stiff.destroy()
    }

    function test_emojiRowOrderAndGreyUntilTouched() {
        const fb = openFb('title: "评分"')
        compare(partOf(cardOf(fb), "feedbackEmojiItem0").children.length > 0, true)
        compare(partOf(cardOf(fb), "feedbackEmojiItem0").width, 36, "$font-feedback_emoji-fontSize")
        compare(partOf(cardOf(fb), "feedbackEmojiItem0").height, 36)
        compare(partOf(cardOf(fb), "feedbackEmojiItem2").height, 36)
        // 默认三枚都是灰的（filter: grayscale(100%)）
        compare(partOf(cardOf(fb), "feedbackEmojiGrey0").visible, true)
        compare(partOf(cardOf(fb), "feedbackEmojiGrey2").visible, true)
        // MultiEffect 的 saturation 0 是「不改」、-1 才是全去色（qquickmultieffect.cpp:371-377），
        // 写成 0 画面完全是彩色的，只有这里能把它钉住
        compare(partOf(cardOf(fb), "feedbackEmojiGrey0").saturation, -1)
        // 灰的那一档由效果项画，彩色本体要藏掉，否则两层叠着边缘露色
        compare(partOf(cardOf(fb), "feedbackEmojiGlyph0").visible, false)
        mouseClick(partOf(cardOf(fb), "feedbackEmojiItem0"))
        wait(20)
        compare(partOf(cardOf(fb), "feedbackEmojiGlyph0").visible, true, "选中那枚要画彩色本体")
        compare(partOf(cardOf(fb), "feedbackEmojiGrey0").visible, false)
        compare(partOf(cardOf(fb), "feedbackEmojiGlyph1").visible, false, "没选中的照旧是灰的")
        fb.destroy()
    }

    function test_clickEmojiSetsValueAndNotifies() {
        const fb = openFb('title: "评分"')
        let seen = []
        fb.valueChange.connect(function (v) { seen.push(v) })
        mouseClick(partOf(cardOf(fb), "feedbackEmojiItem2"))
        wait(20)
        compare(fb.value.emoji, "😃", "第三枚是 good")
        compare(seen.length, 1)
        // 选中那枚摘掉灰罩，其余两枚照旧
        compare(partOf(cardOf(fb), "feedbackEmojiGrey2").visible, false)
        compare(partOf(cardOf(fb), "feedbackEmojiGrey0").visible, true)
        fb.destroy()
    }

    // foundation.ts:43-48 是 notifyValueChange，不是「变了才发」：点同一枚也回调一次
    function test_clickingSameEmojiTwiceNotifiesTwice() {
        const fb = openFb('title: "评分"')
        let count = 0
        fb.valueChange.connect(function () { count++ })
        mouseClick(partOf(cardOf(fb), "feedbackEmojiItem1"))
        wait(20)
        mouseClick(partOf(cardOf(fb), "feedbackEmojiItem1"))
        wait(20)
        compare(count, 2)
        compare(fb.value.emoji, "😐")
        fb.destroy()
    }

    function test_onlyBadEmojiGrowsTheTextArea() {
        const fb = openFb('title: "评分"')
        compare(partOf(cardOf(fb), "feedbackTextArea").visible, false)
        mouseClick(partOf(cardOf(fb), "feedbackEmojiItem2"))
        wait(20)
        compare(partOf(cardOf(fb), "feedbackTextArea").visible, false, "😃 不配补充说明")
        mouseClick(partOf(cardOf(fb), "feedbackEmojiItem0"))
        wait(20)
        compare(partOf(cardOf(fb), "feedbackTextArea").visible, true, "index.tsx:147 只有 😞 有")
        compare(partOf(cardOf(fb), "feedbackTextArea").placeholderText,
            "Provider additional feedback(optional)")
        fb.destroy()
    }

    function test_emojiTextMergesAndSwitchingDropsIt() {
        const fb = openFb('title: "评分"')
        mouseClick(partOf(cardOf(fb), "feedbackEmojiItem0"))
        wait(20)
        partOf(cardOf(fb), "feedbackTextArea").text = "按钮太难找"
        wait(20)
        compare(fb.value.emoji, "😞")
        compare(fb.value.text, "按钮太难找", "foundation.ts:28-36 是合并不是替换")
        mouseClick(partOf(cardOf(fb), "feedbackEmojiItem1"))
        wait(20)
        compare(fb.value.emoji, "😐")
        compare(fb.value.text, undefined, "换 emoji ⇒ 整个对象被替换 ⇒ text 丢掉")
        fb.destroy()
    }

    function test_textTypeValueIsTheString() {
        const fb = openFb('type: "text"')
        const area = partOf(cardOf(fb), "feedbackTextArea")
        compare(area.placeholderText, "Provider additional feedback")
        compare(fb.submitBlocked, true)
        area.text = "希望快一点"
        wait(20)
        compare(fb.value, "希望快一点")
        compare(typeof fb.value, "string")
        compare(fb.submitBlocked, false)
        fb.destroy()
    }

    function test_textAreaPropsFlatten() {
        const fb = openFb('type: "text"; textAreaMaxCount: 200; textAreaPlaceholder: "说说看"')
        const area = partOf(cardOf(fb), "feedbackTextArea")
        compare(area.maxCount, 200)
        compare(area.placeholderText, "说说看")
        fb.destroy()
    }

    function test_radioTypeValueIsTheChoice() {
        const fb = openFb('type: "radio"; radioOptions: ["访客", "开发者", "维护者"]')
        const items = optionItems(cardOf(fb))
        compare(items.length, 3)
        compare(items[1].value, "开发者")
        mouseClick(items[1])
        wait(20)
        compare(fb.value, "开发者")
        compare(fb.submitBlocked, false)
        fb.destroy()
    }

    function test_checkboxTypeValueIsAnArray() {
        const fb = openFb('type: "checkbox"; checkboxOptions: ["抖音", "火山", "豆包"]')
        const items = optionItems(cardOf(fb))
        compare(items.length, 3)
        mouseClick(items[0])
        wait(20)
        mouseClick(items[2])
        wait(20)
        compare(fb.value.length, 2, "value 是勾选值数组")
        compare(fb.value[0], "抖音")
        compare(fb.value[1], "豆包")
        compare(fb.submitBlocked, false)
        fb.destroy()
    }

    function test_groupDirectionsAndSpacing() {
        const cb = openFb('type: "checkbox"; checkboxOptions: ["a", "b"]')
        compare(cb.checkboxGroup.direction, Enums.DirectionVertical, "index.tsx:169")
        compare(cb.checkboxGroup.itemSpacing, 16,
            "$spacing-feedback_checkbox_group_vertical-rowGap 盖掉组自己的 12")
        cb.destroy()

        const rd = openFb('type: "radio"; radioOptions: ["a", "b"]')
        compare(rd.radioGroup.direction, Enums.DirectionVertical, "index.tsx:159")
        rd.destroy()
    }

    function test_submitBlockedRules_data() {
        return [
            { tag: "null", value: null, blocked: true },
            { tag: "空串", value: "", blocked: true },
            { tag: "有字", value: "abc", blocked: false },
            { tag: "空数组", value: [], blocked: true },
            { tag: "一个勾", value: ["a"], blocked: false },
            { tag: "emoji对象", value: ({ emoji: "😐" }), blocked: false },
            { tag: "只有text的对象", value: ({ text: "" }), blocked: false }
        ]
    }

    // index.tsx:231-234：!Boolean(value) || (Array.isArray(value) && !value.length)
    function test_submitBlockedRules(data) {
        const fb = make("Feedback { }")
        fb.value = data.value
        compare(fb.autoBlocked, data.blocked, data.tag)
        compare(fb.submitBlocked, data.blocked, data.tag)
        fb.destroy()
    }

    // 官方把 {...okButtonProps} 展在 disabled={算式} 后面 ⇒ 给了就以它为准
    function test_okButtonDisabledOverridesTheComputedOne() {
        const forced = make('Feedback { okButtonDisabled: true; value: "有值" }')
        compare(forced.autoBlocked, false)
        compare(forced.submitBlocked, true)
        forced.destroy()

        const forcedOpen = make('Feedback { okButtonDisabled: false }')
        compare(forcedOpen.submitBlocked, false, "custom 那支就是这么放开提交键的")
        forcedOpen.destroy()
    }

    function test_footerOrderTextsAndTheme() {
        const fb = openFb('title: "评分"')
        const cancel = partOf(cardOf(fb), "feedbackCancelButton")
        const ok = partOf(cardOf(fb), "feedbackOkButton")
        compare(cancel.text, "取消")
        compare(ok.text, "提交")
        verify(cancel.x < ok.x, "取消在左、提交在右（footer 是 flex-end）")
        compare(ok.x - (cancel.x + cancel.width), 12, "$spacing-feedback_footer-columnGap")
        compare(ok.variant, Enums.Solid, "index.tsx:220 提交键是 theme='solid'")
        compare(ok.resolvedTone, Enums.Primary, "index.tsx:219 提交键 type='primary'")
        // index.tsx:213 取消键只写 type='primary'，theme 走默认 light
        compare(cancel.resolvedTone, Enums.Primary)
        compare(cancel.resolvedVariant, Enums.Light)
        compare(ok.enabled, false)
        compare(partOf(cardOf(fb), "feedbackFooter").visible, true)
        fb.destroy()
    }

    function test_submitNotifiesClearsButStaysOpen() {
        const fb = openFb('type: "text"; okButtonDisabled: false')
        let okCount = 0
        let cancelCount = 0
        fb.ok.connect(function () { okCount++ })
        fb.cancel.connect(function () { cancelCount++ })
        partOf(cardOf(fb), "feedbackTextArea").text = "随便写点"
        wait(20)
        compare(fb.value, "随便写点")
        mouseClick(partOf(cardOf(fb), "feedbackOkButton"))
        wait(20)
        compare(okCount, 1)
        compare(cancelCount, 0, "提交不该顺带发 cancel")
        compare(fb.value, null, "foundation.ts:73-89 非 promise 分支 ⇒ setValue(null)")
        compare(fb.visible, true, "关不关是调用方的事（官方 demo 在 onOk 里 setVisible(false)）")
        fb.destroy()
    }

    function test_cancelNotifiesAndClears() {
        const fb = openFb('type: "text"')
        let okCount = 0
        let cancelCount = 0
        fb.ok.connect(function () { okCount++ })
        fb.cancel.connect(function () { cancelCount++ })
        fb.value = "写了一半"
        mouseClick(partOf(cardOf(fb), "feedbackCancelButton"))
        wait(20)
        compare(cancelCount, 1)
        compare(okCount, 0)
        compare(fb.value, null)
        compare(fb.visible, true)
        fb.destroy()
    }

    function test_dismissViaCloseIconNotifiesOnce() {
        const fb = openFb('type: "text"')
        let cancelCount = 0
        let visibleWhenCancelled = null
        fb.cancel.connect(function () { cancelCount++; visibleWhenCancelled = fb.visible })
        fb.value = "写了一半"
        mouseClick(partOf(cardOf(fb), "feedbackCloseButton"))
        wait(300)
        compare(cancelCount, 1, "X 走 handleCancel，只能发一次")
        // 官方 X 只调 onCancel（sideSheetFoundation.ts:68-70 不做关闭动作），
        // 这里的偏离是 cancel 之后顺手 close —— 所以 cancel 必须在还开着的时候发出，
        // 而不是退场动画结束、onClosed 里补发那一条
        compare(visibleWhenCancelled, true, "cancel 应早于关闭动作")
        compare(fb.visible, false)
        compare(fb.value, null)
        fb.destroy()
    }

    function test_closingExternallyStillNotifiesCancel() {
        // 有意偏离：Esc 与外部置 visible=false 共用 onClosed 那一条（与 Modal 的 cancelled 同口径）
        const fb = openFb('title: "评分"')
        let cancelCount = 0
        fb.cancel.connect(function () { cancelCount++ })
        fb.visible = false
        wait(300)
        compare(cancelCount, 1)
        fb.destroy()
    }

    function test_titleAndClosableToggleTheHeader() {
        const bare = openFb('title: ""')
        compare(partOf(cardOf(bare), "feedbackTitle").visible, false)
        bare.destroy()

        const titled = openFb('title: "您对本产品的评分是？"')
        compare(partOf(cardOf(titled), "feedbackTitle").visible, true)
        compare(partOf(cardOf(titled), "feedbackTitle").font.pixelSize, 16, "fontSizeHeader6")
        titled.destroy()

        // 不画关闭键时标题可以多用那 28px（SideSheet header 的同一份算式）
        const noX = openFb('title: "评分"; closable: false')
        const withX = openFb('title: "评分"')
        compare(partOf(cardOf(noX), "feedbackTitle").width
            - partOf(cardOf(withX), "feedbackTitle").width, 28)
        noX.destroy(); withX.destroy()
    }

    function test_customHostOnlyForCustom() {
        const fb = openFb('type: "custom"; Text { objectName: "mine"; text: "这是一段自定义的内容" }')
        const host = partOf(cardOf(fb), "feedbackCustomHost")
        compare(host.visible, true)
        verify(partOf(cardOf(fb), "mine") !== null, "子项要落进 customHost")
        // Repeater 照样会造出三枚代理，位置器只是把不可见的容器整个跳过 —— 所以断容器不可见，
        // 并且卡片高度不含那一行（emoji 那支是 207，custom 这支配到 140）
        compare(partOf(cardOf(fb), "feedbackEmojiContainer").visible, false)
        verify(cardOf(fb).height < 180, "custom 的卡里不该占 emoji 行那 84px：" + cardOf(fb).height)
        fb.destroy()

        const other = openFb('type: "text"; Text { objectName: "mine2"; text: "x" }')
        compare(partOf(cardOf(other), "feedbackCustomHost").visible, false)
        other.destroy()
    }

    function test_showFooterHidesBothButtons() {
        // 官方「反馈完成提示」那节是往外壳传 footer={null}，这里摊平成 showFooter
        const fb = openFb('title: "评分"; showFooter: false')
        compare(partOf(cardOf(fb), "feedbackFooter").visible, false)
        const plain = openFb('title: "评分"')
        compare(partOf(cardOf(plain), "feedbackFooter").visible, true)
        verify(cardOf(plain).height > cardOf(fb).height, "收掉 footer 之后卡片要变矮")
        fb.destroy(); plain.destroy()
    }

    function test_loadingFlagsReachTheButtons() {
        const fb = openFb('type: "text"; okButtonLoading: true; cancelButtonLoading: true')
        compare(partOf(cardOf(fb), "feedbackOkButton").loading, true)
        compare(partOf(cardOf(fb), "feedbackCancelButton").loading, true)
        fb.destroy()
    }

}
