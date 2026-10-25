pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as C
import QtQuick.Effects
import Semi

// 反馈卡。照 semi-ui/feedback（`index.tsx:26-47` 的 FeedbackProps + `:65-72` 的 defaultProps）
// 与 semi-foundation/feedback（`foundation.ts:22-115` 的 handler、`constants.ts:9-17` 的
// MODE/TYPE/Emoji、`feedback.scss` + `variables.scss` 的度量）。
//
//     Feedback {
//         id: fb
//         title: "您对本产品的评分是？"
//         visible: page.open
//         onValueChange: console.log(value)
//         onOk: page.open = false
//         onCancel: page.open = false
//     }
//
// 官方只有两组行为：mode 决定外壳（popup = 底部侧边抽屉、modal = 模态框），type 决定内容区
// （emoji / text / radio / checkbox / custom）。外壳与内容之间没有任何耦合，所以这里也只做
// 一张卡，mode 改的是宽 / 位置 / 蒙层 / 动效。
//
// 度量（feedback.scss + variables.scss，逐条）：
//   · 宽：popup 400（$width-feedback）、type 为 text 时 600（$width-feedback_text）；modal 一律 400；
//   · popup 贴在窗口右下：右 20（$spacing-feedback_sidesheet_bottom-right）、
//     下 50（$spacing-feedback_sidesheet_bottom_inner_wrap-bottom）、圆角 12
//     （$radius-feedback_sidesheet_inner）；modal 居中，圆角同 Modal 的 radius-large（也是 12）；
//   · emoji 行：三枚居中、列间距 24、上下各 24（$spacing-feedback_emoji_container-*），
//     字号 = 行高 = 高 = 36（$font-feedback_emoji-fontSize），默认 grayscale(100%)，
//     hover 或选中还原彩色；
//   · checkbox 竖排组行距 16（$spacing-feedback_checkbox_group_vertical-rowGap，
//     盖掉 CheckboxGroup 自己的 12）；
//   · footer 右对齐、按钮间距 12（$spacing-feedback_footer-columnGap）。
// 外壳的 header / body / 关闭键度量照 src/SideSheet.qml 与 src/Modal.qml（官方那两种壳就是它们）。
//
// 值语义（foundation.ts:22-53）：
//   · emoji ⇒ { emoji }，点同一枚会重发一次 onValueChange；选中 😞 才长出补充说明的 TextArea，
//     打字时是**合并**（{ ...value, text }），换 emoji 时整个对象被替换 ⇒ 之前写的 text 丢掉；
//   · text ⇒ 字符串；radio ⇒ 单选的选中值；checkbox ⇒ 数组；custom ⇒ 组件自己不碰 value；
//   · 提交键的禁用算式（index.tsx:231-234）：`!Boolean(value) || (Array.isArray(value) && !value.length)`，
//     给了 okButtonDisabled 就以它为准（官方 `{...okButtonProps}` 展在算式后面，覆盖那一份）；
//   · 取消 / 提交都只回调 + 把 value 清成 null，**不关自己** —— visible 是调用方的
//     （官方 demo 就是在 onOk / onCancel 里 setVisible(false)）；
//   · TextArea 是非受控的（官方没给它传 value），所以这里也不回写 text：清 value 不清框里的字。
//
// 与官方的差异（React / CSS 在 QML 侧无处落地，逐条）：
//   · `textAreaProps` / `radioGroupProps` / `checkboxGroupProps` / `okButtonProps` /
//     `cancelButtonProps` 这五个「props 对象」摊平成显式属性（同 DateScrollColumn 把
//     `scrollItemProps.mode` 摊平成 `wheel`）：官方 demo 真正用到的就是 placeholder / maxCount /
//     options / disabled 这几样；其余参数用 `readonly property alias textArea / radioGroup /
//     checkboxGroup` 摸到内部件自己设；
//   · `renderContent` 不收：QML 侧 `type: "custom"` 的内容就是 Feedback 的子项（官方 children 与
//     renderContent 的叠加在 QML 里是同一件事），要「提交后换成感谢页」由调用方自己换子项
//     （见 gallery 的「反馈完成提示」那节）；
//   · `onOk` / `onCancel` 的返回值 promise 与 `e` 事件对象没有：官方靠它驱动
//     `onOKReturnPromiseStatus` 那一套 loading，这里改成 `okButtonLoading` / `cancelButtonLoading`
//     两个显式开关；`afterClose` 官方压根没调用过（`notifyClose` 在 foundation.ts 里是死代码），
//     所以不提供；
//   · 关闭路径（右上角 X / 点蒙层）会补发一次 `cancel()` —— 官方是外壳的 onCancel 走到
//     `handleCancel`，这里等价；Esc 与外部把 visible 置 false 也共用同一条 `onClosed`，
//     这一份是**有意偏离**（与 src/Modal.qml 的 `cancelled` 同一口径）；
//   · `canVerticalSetWidth`（SideSheet 的拖宽）与 `disableScroll` 不透传；popup 模式没有蒙层是
//     官方写死的 `mask={false}`，不开放；
//   · 官方 demo 里「反馈完成提示」用的 `footer={null}` 与 `title=' '` 摊平成 `showFooter`
//     与照常传的 `title`。
C.Popup {
    id: control

    // ---------------------------------------------------------------- FeedbackProps
    property string mode: "popup"                   // popup | modal（strings.MODE）
    property string type: "emoji"                   // emoji | text | radio | checkbox | custom
    property string title: ""
    property bool closable: true
    property bool showFooter: true                // 官方是往外壳传 footer={null}
    property var value: null

    // locale.Feedback（zh_CN.ts:227-230）
    property string okText: qsTr("提交")
    property string cancelText: qsTr("取消")

    // 官方 okButtonProps / cancelButtonProps 里被用到的那几项
    property var okButtonDisabled: undefined        // 不给 ⇒ 走内部算式
    property bool okButtonLoading: false
    property bool cancelButtonLoading: false

    // 官方 textAreaProps（emoji 那支的默认占位文案带 (optional)）
    property string textAreaPlaceholder: ""
    property int textAreaMaxCount: 0

    // 官方 radioGroupProps / checkboxGroupProps
    property var radioOptions: undefined
    property var checkboxOptions: undefined

    signal ok()
    signal cancel()
    signal valueChange(var value)

    // type 为 custom 时，官方渲染的是 children
    default property alias content: customHost.data

    // 高级用法：直接摸到三个内部件
    readonly property alias textArea: textAreaItem
    readonly property alias radioGroup: radioGroupItem
    readonly property alias checkboxGroup: checkboxGroupItem
    readonly property Item customHost: customHost

    // strings.Emoji 的声明序就是展示序（constants.ts:12-16）
    readonly property var emojiValues: ["😞", "😐", "😃"]
    readonly property string emojiBad: "😞"

    readonly property bool isPopup: control.mode === "popup"
    readonly property real panelWidth: control.isPopup && control.type === "text" ? 600 : 400
    readonly property bool maskShown: !control.isPopup

    // 当前 value 里的那枚 emoji / 那段补充说明
    readonly property string pickedEmoji: control.value !== null && control.value !== undefined
        && control.value.emoji !== undefined ? String(control.value.emoji) : ""
    readonly property string pickedText: control.value !== null && control.value !== undefined
        && control.value.text !== undefined ? String(control.value.text) : ""

    // 官方 disableSubmitButton（index.tsx:231-234）。数组按 length 判而不按 Array.isArray ——
    // 从 QuickTest 属性表递进来的数组不是真数组（坑 85）。
    readonly property bool autoBlocked: {
        const v = control.value;
        if (!v)
            return true;
        return v.length !== undefined && v.length === 0;
    }
    readonly property bool submitBlocked: control.okButtonDisabled !== undefined
        ? Boolean(control.okButtonDisabled) : control.autoBlocked

    parent: C.Overlay.overlay
    modal: true
    focus: true
    dim: false                                      // 蒙层自绘，同 Modal / SideSheet
    padding: 0
    closePolicy: C.Popup.CloseOnEscape
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // ---- 动效：popup 走 SideSheet 的平移，modal 走 Modal 的缩放淡入 ----
    // $animation_duration-sideSheet_inner-show/hide = 180ms + cubic-bezier(.25,.46,.45,.94)
    // $animation_duration-modal-show/hide = 120ms + cubic-bezier(.215,.61,.355,1)
    // Qt 的 Easing.BezierSpline 退化成线性（坑 50），两条都取形状最接近的内置曲线，
    // 与 src/SideSheet.qml / src/Modal.qml 同一份近似。不能用 Theme.current.duration* ——
    // 默认主题把全局时长令牌设成 0ms。
    readonly property int motionDuration: control.isPopup ? 180 : 120
    readonly property int motionEase: control.isPopup ? Easing.OutQuad : Easing.OutCubic
    readonly property int maskDuration: 90

    enter: Transition {
        NumberAnimation {
            target: card
            property: "motion"
            from: 0
            to: 1
            duration: control.motionDuration
            easing.type: control.motionEase
        }
    }

    exit: Transition {
        NumberAnimation {
            target: card
            property: "motion"
            from: 1
            to: 0
            duration: control.motionDuration
            easing.type: control.motionEase
        }
    }

    background: Rectangle {
        objectName: "feedbackMask"

        // 官方 popup 那支写死 mask={false}，所以只有 modal 有蒙层，也只有它能点蒙层关闭
        color: control.maskShown && control.visible
            ? Theme.current.colorOverlayBg : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: control.maskDuration
                easing.type: Easing.OutCubic
            }
        }

        TapHandler {
            enabled: control.maskShown && control.closable
            onTapped: control.dismiss()
        }
    }

    onClosed: {
        // X / 点蒙层走 dismiss()，已经发过 cancel；Esc 与外部置 visible=false 只有这一条路，
        // 补发一次（有意偏离，见文件头）。
        if (!control.__settled)
            control.cancel();
        control.__settled = false;
        control.resetValue();
    }

    property bool __settled: false

    function resetValue() {
        control.value = null;
    }

    // 官方 notifyValueChange：先 setState 再回调，**每次调用都回调**（点同一枚 emoji 也算一次）
    function applyValue(next) {
        control.value = next;
        control.valueChange(next);
    }

    function pickEmoji(emoji) {
        control.applyValue({ emoji: emoji });
    }

    // index.tsx:147 + foundation.ts:28-36：补充说明是往当前对象上**合并** text
    function handleEmojiText(text) {
        control.applyValue({ emoji: control.pickedEmoji, text: text });
    }

    function handleCancel() {
        control.__settled = true;
        control.cancel();
        control.resetValue();
    }

    function handleSubmit() {
        control.__settled = true;
        control.ok();
        control.resetValue();
    }

    // 右上角 X / 点蒙层：官方是外壳的 onCancel 走到 handleCancel
    function dismiss() {
        control.handleCancel();
        control.close();
    }

    // ---------------------------------------------------------------- 卡片
    Rectangle {
        id: card

        objectName: "feedbackCard"
        // 0 = 起始位（popup 在窗口下沿之外、modal 是 0.7 倍 + 全透明），1 = 就位
        property real motion: 1

        width: control.panelWidth
        height: stack.implicitHeight + Theme.current.spacingLoose * 2
        color: Theme.current.colorBg2
        radius: Theme.current.radiusLarge   // 12，与 $radius-feedback_sidesheet_inner 同值
        border.width: 1
        border.color: Theme.current.colorBorder
        opacity: control.isPopup ? 1 : (0.3 + 0.7 * card.motion)
        scale: control.isPopup ? 1 : (0.7 + 0.3 * card.motion)
        transformOrigin: Item.Center

        // popup：贴窗口右下，右 20 / 下 50；进场位移 = 自身高 + 那 50
        // （官方被 feedback.scss 改过的 keyframes：translateY(calc(100% + 50px)) → 0）
        readonly property real restingX: control.isPopup
            ? Math.max(0, control.width - width - 20)
            : (control.width - width) / 2
        readonly property real restingY: control.isPopup
            ? Math.max(0, control.height - height - 50)
            : (control.height - height) / 2
        x: restingX
        y: restingY + (control.isPopup ? (1 - card.motion) * (height + 50) : 0)

        SemiPopupShadow {
            anchors.fill: parent
            z: -1
            radius: card.radius
            fill: card.color
        }

        Column {
            id: stack

            x: Theme.current.spacingLoose
            y: Theme.current.spacingLoose
            width: parent.width - Theme.current.spacingLoose * 2
            spacing: 0

            // ---- 标题（度量照 SideSheet 的 header：字号 header6 / 粗体、右侧给关闭键留 28）
            Text {
                objectName: "feedbackTitle"
                visible: control.title !== ""
                width: parent.width - (control.closable ? 28 : 0)
                text: control.title
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeHeader6
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
            }

            // ---- 内容区：type 决定画哪一支。标题与内容之间那 20 是 SideSheet header
            // 高度算式（spacingLoose + spacingBaseLoose）里落在 header 下面的那一份。
            Item {
                objectName: "feedbackBody"
                width: parent.width
                height: bodyColumn.implicitHeight + Theme.current.spacingBaseLoose

                Column {
                    id: bodyColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: Theme.current.spacingBaseLoose
                    spacing: Theme.current.spacingBaseTight

                    // emoji：三枚一行居中，容器上下各 24
                    Item {
                        objectName: "feedbackEmojiContainer"
                        visible: control.type === "emoji"
                        width: bodyColumn.width
                        height: emojiRow.implicitHeight + Theme.current.spacingLoose * 2

                        Row {
                            id: emojiRow

                            objectName: "feedbackEmojiRow"
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 24             // $spacing-feedback_emoji_container-columnGap

                            Repeater {
                                model: control.emojiValues

                                delegate: Item {
                                    id: emojiCell

                                    required property var modelData
                                    required property int index

                                    objectName: "feedbackEmojiItem" + index
                                    width: 36
                                    height: 36      // $font-feedback_emoji-fontSize：字号 = 行高 = 高

                                    // filter: grayscale(100%) ⇒ 下面写 -1（MultiEffect 的
                                    // saturation 是增量，0 是「不改」，-1 才是全去色）；
                                    // &:hover, &-selected ⇒ filter: none
                                    readonly property bool coloured: emojiHover.hovered
                                        || control.pickedEmoji === emojiCell.modelData

                                    HoverHandler { id: emojiHover }

                                    Text {
                                        id: emojiGlyph

                                        objectName: "feedbackEmojiGlyph" + emojiCell.index
                                        anchors.centerIn: parent
                                        text: emojiCell.modelData
                                        // 官方 .semi-feedback-emoji-item 写了 `font-family: Inter`
                                        // （feedback.scss:20），但 Inter 本身不含 emoji 字形 ——
                                        // 浏览器里那行是无效回退，Qt 里则会为缺字体打
                                        // 「Populating font family aliases」警告（实测 61ms）⇒ 不落。
                                        font.pixelSize: 36
                                        // 灰的那一档交给下面的 MultiEffect 画，两者只画一个：
                                        // 源不藏的话彩色本体与效果层会叠在一起（边缘会露色）
                                        visible: emojiCell.coloured
                                    }

                                    MultiEffect {
                                        objectName: "feedbackEmojiGrey" + emojiCell.index
                                        anchors.fill: parent
                                        source: emojiGlyph
                                        visible: !emojiCell.coloured
                                        // saturation 的 0 是「不改」，-1 才是全去色
                                        // （qquickmultieffect.cpp:371-377），对应 grayscale(100%)
                                        saturation: -1
                                    }

                                    TapHandler {
                                        onTapped: control.pickEmoji(emojiCell.modelData)
                                    }
                                }
                            }
                        }
                    }

                    // 选中 😞 才长出补充说明（index.tsx:147）；text 那一支单独占满
                    TextArea {
                        id: textAreaItem

                        objectName: "feedbackTextArea"
                        visible: control.type === "emoji" ? control.pickedEmoji === control.emojiBad
                            : control.type === "text"
                        width: bodyColumn.width
                        placeholderText: control.textAreaPlaceholder !== ""
                            ? control.textAreaPlaceholder
                            : (control.type === "text" ? "Provider additional feedback"
                                : "Provider additional feedback(optional)")
                        maxCount: control.textAreaMaxCount
                        // 官方没给 TextArea 传 value ⇒ 非受控。这里同样不回写 text：
                        // 绑上去就会把用户正在打的字吃掉（坑 41 那一族）。
                        onTextChanged: {
                            if (control.type === "text")
                                control.applyValue(textAreaItem.text);
                            else if (control.type === "emoji")
                                control.handleEmojiText(textAreaItem.text);
                        }
                    }

                    RadioGroup {
                        id: radioGroupItem

                        objectName: "feedbackRadioGroup"
                        visible: control.type === "radio"
                        width: bodyColumn.width
                        direction: Enums.DirectionVertical      // index.tsx:159
                        options: control.radioOptions
                        onChanged: control.applyValue(radioGroupItem.currentValue)
                    }

                    CheckboxGroup {
                        id: checkboxGroupItem

                        objectName: "feedbackCheckboxGroup"
                        visible: control.type === "checkbox"
                        width: bodyColumn.width
                        direction: Enums.DirectionVertical      // index.tsx:169
                        itemSpacing: 16             // $spacing-feedback_checkbox_group_vertical-rowGap
                        options: control.checkboxOptions
                        onChanged: control.applyValue(checkboxGroupItem.currentValue)
                    }

                    // type 为 custom：官方渲染 children。用 Column 而不是裸 Item + childrenRect
                    // 是两个原因：一是位置器本来就会跳过 visible:false 的子项，二是自己读自己的
                    // childrenRect 会踩绑定环（Skeleton 那条同一族，坑 90）。外壳那层的 body 也是
                    // Column（src/SideSheet.qml:192-198），间距同它的 12。
                    Column {
                        id: customHost

                        objectName: "feedbackCustomHost"
                        visible: control.type === "custom"
                        width: bodyColumn.width
                        spacing: Theme.current.spacingBaseTight
                    }
                }
            }

            // ---- footer：右对齐两颗键，间距 12
            Item {
                objectName: "feedbackFooter"
                visible: control.showFooter
                width: parent.width
                height: footerRow.implicitHeight

                Row {
                    id: footerRow

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12                   // $spacing-feedback_footer-columnGap

                    // index.tsx:213 那颗「取消」是 type='primary'（theme 默认 light）
                    Button {
                        objectName: "feedbackCancelButton"
                        text: control.cancelText
                        tone: Enums.Primary
                        loading: control.cancelButtonLoading
                        onClicked: control.handleCancel()
                    }

                    // index.tsx:219 那颗「提交」是 type='primary' theme='solid'
                    Button {
                        objectName: "feedbackOkButton"
                        text: control.okText
                        tone: Enums.Primary
                        variant: Enums.Solid
                        enabled: !control.submitBlocked
                        loading: control.okButtonLoading
                        onClicked: control.handleSubmit()
                    }
                }
            }
        }

        IconButton {
            objectName: "feedbackCloseButton"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.current.spacingBaseTight
            visible: control.closable
            icon: "close"
            size: Enums.Small
            variant: Enums.Borderless
            tone: Enums.Tertiary
            onClicked: control.dismiss()
        }
    }
}
