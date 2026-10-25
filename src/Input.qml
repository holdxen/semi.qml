import QtQuick
import QtQuick.Layouts

// 文本输入框。官方 API 面见 semi-ui/input/index.tsx，外观见
// semi-foundation/input/input.scss + variables.scss。
//
//     Input { placeholderText: "请输入"; onAccepted: ... }
//     Input { prefix: "Prefix"; showClear: true }
//     Input { addonBefore: "http://"; addonAfter: ".com" }
//     Input { mode: "password" }
//
// 排布与官方 DOM 一致：wrapper 里依次是 prepend、prefix、input、clear、suffix、modebtn、append
// （index.tsx:554-560）。带前置/后置标签时 wrapper 自己透明，三段各画底色、圆角落在最外侧
// （input.scss:211-230）。
Item {
    id: control

    // ---- 值 ----
    property alias text: field.text
    property alias input: field
    // Item.activeFocus 不会往非 FocusScope 的祖先传，外层想知道「编辑中」只能读这里
    readonly property alias fieldActiveFocus: field.activeFocus
    property alias echoMode: field.echoMode
    property alias readOnly: field.readOnly
    property alias validator: field.validator
    property alias inputMethodHints: field.inputMethodHints

    property string placeholderText: ""
    property int size: Enums.Default
    // 官方 Input.validateStatus：default / warning / error / success，只有后两者有样式
    property int validateStatus: Enums.StatusDefault
    // 官方 Input.mode，可选 password
    property string mode: ""
    // 官方 Input.borderless：非聚焦、非悬浮时底与描边都透明
    property bool borderless: false
    // 官方 Input.onlyBorder?: number：给了就把底清空、描边换成 color-border 且宽度为该值
    property real onlyBorder: -1
    // 官方 maxLength（0 表示不限）。配 getValueLength 时改由 JS 侧截断
    property int maxLength: 0
    // 官方 getValueLength: (value) => number
    property var getValueLength: null
    // 官方 composition。Qt 的输入法 preedit 本来就不写进 text
    // （「the text being composed by the input method is not part of this property」），
    // 所以这条在 QML 侧没有可观察差异，只是把官方的写法接住。
    property bool composition: false

    // ---- prefix / suffix / addon ----
    // 官方是 ReactNode：这里传 string 走 -text 样式，传 Component 走自定义节点（左右间距 0）
    property var prefix: undefined
    property var suffix: undefined
    property var addonBefore: undefined
    property var addonAfter: undefined
    // 本库便利写法：图标名，等价官方传 <IconSearch />（走 -icon 样式，左右间距 8）
    property string prefixIcon: ""
    property string suffixIcon: ""
    // 官方 Form 的 labelPosition='inset' 把标签交给 insetLabel，而 insetLabel 在官方
    // 就是走 prefix 那一格（index.tsx:373）
    property string insetLabel: ""
    property bool showClear: false
    // 官方 clearIcon（ReactNode）：这里收图标名，默认 clear
    property string clearIcon: ""
    // 官方 hideSuffix：清除按钮与后缀并存时把后缀藏掉
    property bool hideSuffix: false

    signal accepted
    signal cleared

    // 本库便利项（官方 Input 没有这一条）：QQuickTextInput 自己就处理 ArrowUp/Down（单行里挪
    // 光标）并吃掉事件，祖先项的 Keys 收不到，Keys.forwardTo 在 TextInput 上也不投递（实测）。
    // 官方 InputNumber 要拦这两个键做步进（foundation.ts:260-276），只能从 TextInput 自己的
    // Keys 上接。开启后 Up/Down 不再挪光标、改发 keyPressed，其余按键行为完全不变。
    // 注意 Keys 那个事件对象是一次性的，跨信号传 var 会串位（实测 key 读成 0、modifiers 装着
    // key），所以这里只传 key / modifiers 两个整数。
    property bool arrowsAsKeys: false
    signal keyPressed(int key, int modifiers)

    // wrapper 的圆角。根项不再是 Rectangle（要容纳前置/后置标签），所以自己开一个，
    // 让 ColorPicker 那类「把输入框压平」的用法仍然写得到。
    property real radius: Theme.current.radiusSmall
    // 分角圆角透给 wrapper：InputGroup / Form.InputGroup 靠这四个值还原
    // .semi-input-group 的首尾圆角（没有前置/后置标签时才有效）
    property alias topLeftRadius: box.topLeftRadius
    property alias topRightRadius: box.topRightRadius
    property alias bottomLeftRadius: box.bottomLeftRadius
    property alias bottomRightRadius: box.bottomRightRadius

    readonly property int controlState:
        Appearance.fieldState(control.enabled, field.activeFocus, hover.hovered, pointer.pressed)
    readonly property color foreground: Appearance.inputForeground(Theme.current, control.controlState)
    readonly property color iconColor: Appearance.inputIconColor(Theme.current, control.controlState)
    // 左右内边距（$spacing-input-paddingLeft/Right = spacing-base-tight）。PinCode 的每一格
    // 要把它清 0（pincode.scss:29 `input { padding: 0 }`），所以留成可覆盖的。
    property int paddingH: Appearance.inputPaddingHorizontal(Theme.current)
    // 同上：官方 .semi-pincode-wrapper 里的 input 是 `text-align: center`。
    property int textAlign: TextInput.AlignLeft

    // ---- 槽位占用 ----
    readonly property bool prefixIsText: control.prefix !== undefined && control.prefix !== null
        && typeof control.prefix === "string" && String(control.prefix) !== ""
    readonly property bool prefixIsNode: control.prefix instanceof Component
    readonly property bool suffixIsText: control.suffix !== undefined && control.suffix !== null
        && typeof control.suffix === "string" && String(control.suffix) !== ""
    readonly property bool suffixIsNode: control.suffix instanceof Component
    readonly property bool hasInsetLabel: control.insetLabel !== "" && !control.prefixIsText
        && !control.prefixIsNode
    readonly property bool hasPrefix: control.prefixIsText || control.prefixIsNode
        || control.prefixIcon !== "" || control.hasInsetLabel
    readonly property bool prependIsNode: control.addonBefore instanceof Component
    readonly property bool appendIsNode: control.addonAfter instanceof Component
    readonly property bool hasPrepend: control.addonBefore !== undefined
        && control.addonBefore !== null
        && (control.prependIsNode || String(control.addonBefore) !== "")
    readonly property bool hasAppend: control.addonAfter !== undefined
        && control.addonAfter !== null
        && (control.appendIsNode || String(control.addonAfter) !== "")

    // 官方 allowClear：有值 + showClear + 未禁用 + （聚焦或悬浮）
    readonly property bool allowClear: field.text !== "" && control.showClear
        && control.enabled && (field.activeFocus || hover.hovered)
    readonly property bool suffixShown: (control.suffixIsText || control.suffixIsNode
        || control.suffixIcon !== "") && !(control.hideSuffix && control.allowClear)
    // 官方 wrapper 的 `__with-suffix` 类只看「有没有后缀节点」，与它当前是否被清除按钮
    // 顶掉无关（input.scss:151）—— 文本右内边距归零的条件是它，不是 suffixShown。
    readonly property bool hasSuffix: control.suffixIsText || control.suffixIsNode
        || control.suffixIcon !== ""
    // 尾部只要挂着任何东西（后缀 / 清除 / 密码按钮），wrapper 自己就不再留 12 的内边距：
    // 那三个部件各自带够间距（clearbtn 是 32 宽、图标居中 = 距右边界 16，与后缀图标同位）。
    // 少了这条，清除图标会比时钟图标往左偏 12px。
    readonly property bool trailingShown: control.suffixShown || control.allowClear
        || control.showModeBtn
    readonly property bool showModeBtn: control.mode === "password" && control.enabled
    // 官方 eyeClosed 初值是 mode === 'password'，点一下切换（foundation.ts:239-252）
    property bool revealed: false
    readonly property bool eyeClosed: control.mode === "password" && !control.revealed

    // 文本 / insetLabel 左右 12，图标左右 8，自定义节点 0（input.scss:516-531）
    readonly property real textGap: Theme.current.spacingBaseTight
    readonly property real iconGap: Theme.current.spacingTight
    // 清除按钮最小宽度（variables.scss:72-74）：独立 32；后缀是图标时 24；密码按钮在前时 16
    readonly property bool clearBeforeSuffixIcon: control.suffixIcon !== "" && !control.hideSuffix
    readonly property real clearMinWidth: control.showModeBtn
        ? Theme.current.widthIconMedium
        : (control.clearBeforeSuffixIcon
            ? Theme.current.widthIconMedium + Theme.current.spacingTight
            : Theme.current.widthIconMedium + Theme.current.spacingTight * 2)
    // 24 宽那一档官方是 `justify-content: flex-end`（input.scss:197-201）：图标贴这条
    // 24 的右沿、紧挨着后缀图标。默认那两档才是 flex-end 之外的居中。
    readonly property bool clearIconAtEnd: !control.showModeBtn && control.clearBeforeSuffixIcon

    // 官方 maxLength 与 getValueLength 的组合（index.tsx:527-529）：
    // 传了自定义长度函数就不再交给原生限制，改由 JS 截断
    readonly property bool useNativeMaxLength: control.maxLength > 0
        && !(control.getValueLength instanceof Function)

    implicitWidth: 240
    implicitHeight: Appearance.inputWrapperHeight(Theme.current, control.size)

    // 带前置/后置标签时官方把「wrapper 容器」变透明，而 .semi-input 自己仍是 fill-0 底 +
    // 1px 透明描边，聚焦时才换主色描边（input.scss:247-263）。我们的 box 就是那一层输入区。
    readonly property color boxColor:
        Appearance.inputBackground(Theme.current, control.controlState, control.validateStatus)
    readonly property color boxBorderColor: control.hasPrepend || control.hasAppend
        ? (field.activeFocus
            ? Appearance.inputBorderColor(Theme.current, Enums.Focused, control.validateStatus)
            : "transparent")
        : Appearance.inputBorderColor(Theme.current, control.controlState, control.validateStatus)

    function lengthOf(value) {
        const s = String(value === undefined || value === null ? "" : value);
        if (control.getValueLength instanceof Function) {
            const n = Number(control.getValueLength(s));
            return Number.isNaN(n) ? s.length : n;
        }
        return s.length;
    }

    // 官方 truncateValue：二分找出「自定义长度不超过 maxLength」的最长前缀
    function truncateToMaxLength(value) {
        const s = String(value);
        if (control.maxLength <= 0 || control.lengthOf(s) <= control.maxLength)
            return s;
        let left = 0;
        let right = s.length;
        while (left < right) {
            const mid = left + ((right - left + 1) >> 1);
            if (control.lengthOf(s.slice(0, mid)) <= control.maxLength)
                left = mid;
            else
                right = mid - 1;
        }
        return s.slice(0, left);
    }

    function doClear() {
        field.text = "";
        control.cleared();
    }

    // ---- .semi-input-prepend ----
    Rectangle {
        id: prependBox

        objectName: "prepend"
        visible: control.hasPrepend
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: prependLoader.visible ? prependLoader.implicitWidth
            : prependText.implicitWidth + control.textGap * 2
        color: Appearance.inputBackground(Theme.current, Enums.Normal, Enums.StatusDefault)
        border.width: 1
        border.color: "transparent"
        topLeftRadius: Theme.current.radiusSmall
        bottomLeftRadius: Theme.current.radiusSmall
        // 只有前置标签时，右外侧的圆角也归它
        topRightRadius: control.hasAppend ? 0 : Theme.current.radiusSmall
        bottomRightRadius: control.hasAppend ? 0 : Theme.current.radiusSmall

        Loader {
            id: prependLoader

            anchors.centerIn: parent
            visible: control.prependIsNode
            sourceComponent: control.prependIsNode ? control.addonBefore : null
        }

        Text {
            id: prependText

            anchors.centerIn: parent
            visible: !control.prependIsNode
            text: control.addonBefore === undefined || control.addonBefore === null
                ? "" : String(control.addonBefore)
            color: control.iconColor
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Font.DemiBold
        }
    }

    // ---- .semi-input-append ----
    Rectangle {
        id: appendBox

        objectName: "append"
        visible: control.hasAppend
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: appendLoader.visible ? appendLoader.implicitWidth
            : appendText.implicitWidth + control.textGap * 2
        color: Appearance.inputBackground(Theme.current, Enums.Normal, Enums.StatusDefault)
        border.width: 1
        border.color: "transparent"
        topRightRadius: Theme.current.radiusSmall
        bottomRightRadius: Theme.current.radiusSmall
        topLeftRadius: control.hasPrepend ? 0 : Theme.current.radiusSmall
        bottomLeftRadius: control.hasPrepend ? 0 : Theme.current.radiusSmall

        Loader {
            id: appendLoader

            anchors.centerIn: parent
            visible: control.appendIsNode
            sourceComponent: control.appendIsNode ? control.addonAfter : null
        }

        Text {
            id: appendText

            anchors.centerIn: parent
            visible: !control.appendIsNode
            text: control.addonAfter === undefined || control.addonAfter === null
                ? "" : String(control.addonAfter)
            color: control.iconColor
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Font.DemiBold
        }
    }

    // ---- .semi-input-wrapper ----
    Rectangle {
        id: box

        objectName: "inputWrapper"
        anchors.left: control.hasPrepend ? prependBox.right : parent.left
        anchors.right: control.hasAppend ? appendBox.left : parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        topLeftRadius: control.hasPrepend ? 0 : control.radius
        bottomLeftRadius: control.hasPrepend ? 0 : control.radius
        topRightRadius: control.hasAppend ? 0 : control.radius
        bottomRightRadius: control.hasAppend ? 0 : control.radius
        radius: control.radius
        color: control.borderless || control.onlyBorder >= 0 ? "transparent" : control.boxColor
        border.width: control.onlyBorder >= 0 ? control.onlyBorder : 1
        border.color: control.onlyBorder >= 0
            ? Theme.current.colorBorder
            : (control.borderless && !field.activeFocus && !hover.hovered
                ? "transparent" : control.boxBorderColor)

        Behavior on color {
            ColorAnimation { duration: Theme.current.durationFast }
        }

        RowLayout {
            anchors.fill: parent
            // 官方 __with-prefix / __with-suffix 会把 input 自己的左 / 右内边距清 0
            anchors.leftMargin: control.hasPrefix ? 0 : control.paddingH
            anchors.rightMargin: control.trailingShown ? 0 : control.paddingH
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            spacing: 0

            Text {
                objectName: "insetLabel"
                visible: control.hasInsetLabel
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: control.textGap
                Layout.rightMargin: control.textGap
                text: control.insetLabel
                color: control.iconColor
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: Font.DemiBold
            }

            Loader {
                objectName: "prefixNode"
                visible: control.prefixIsNode
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: control.prefixIsNode ? control.prefix : null
            }

            Text {
                objectName: "prefixText"
                visible: control.prefixIsText
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: control.textGap
                Layout.rightMargin: control.textGap
                text: control.prefixIsText ? String(control.prefix) : ""
                color: control.iconColor
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: Font.DemiBold
            }

            Icon {
                objectName: "prefixIcon"
                visible: control.prefixIcon !== ""
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: control.iconGap
                Layout.rightMargin: control.iconGap
                name: control.prefixIcon
                size: 16
                color: control.iconColor
            }

            // ---- .semi-input ----
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                // 官方 .semi-input 的 padding-right 只在 `__with-suffix` 时归零
                // （input.scss:151-157）；没有后缀、只有清除 / 密码按钮时那 12 还在。
                Layout.rightMargin: control.trailingShown && !control.hasSuffix
                    ? control.paddingH : 0

                TextInput {
                    id: field

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    color: control.foreground
                    horizontalAlignment: control.textAlign
                    font.pixelSize: control.size === Enums.Large
                        ? Theme.current.fontSizeHeader6 : Theme.current.fontSizeRegular
                    selectByMouse: true
                    enabled: control.enabled
                    clip: true
                    activeFocusOnTab: true
                    maximumLength: control.useNativeMaxLength ? control.maxLength : 2147483647
                    echoMode: control.eyeClosed ? TextInput.PasswordEchoOnEdit : TextInput.Normal

                    Keys.onPressed: (event) => {
                        control.keyPressed(event.key, event.modifiers);
                        if (control.arrowsAsKeys
                                && (event.key === Qt.Key_Up || event.key === Qt.Key_Down))
                            event.accepted = true;
                    }

                    onAccepted: control.accepted()

                    onTextChanged: {
                        if (control.useNativeMaxLength)
                            return;
                        const cut = control.truncateToMaxLength(field.text);
                        if (cut !== field.text) {
                            const caret = field.cursorPosition - (field.text.length - cut.length);
                            field.text = cut;
                            field.cursorPosition = Math.max(0, caret);
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === "" && !field.activeFocus
                        text: control.placeholderText
                        color: Appearance.inputPlaceholderColor(Theme.current, control.controlState)
                        font: field.font
                    }
                }
            }

            // ---- .semi-input-clearbtn ----
            Item {
                objectName: "clearBtn"
                visible: control.allowClear
                Layout.alignment: Qt.AlignVCenter
                Layout.fillHeight: true
                implicitWidth: control.clearMinWidth

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    // 用 x 而不是 centerIn / right 混着挂：同一组 anchors 里两种水平定位并存会冲突
                    x: control.clearIconAtEnd ? parent.width - width : (parent.width - width) / 2
                    name: control.clearIcon !== "" ? control.clearIcon : "clear"
                    size: 16
                    color: clearArea.containsMouse
                        ? Theme.current.colorPrimaryHover : control.iconColor
                }

                // MouseArea 而不是 TapHandler：QtTest 的合成点击与外层 TapHandler 抢 grab，
                // 用 MouseArea 才稳定，且它自带 containsMouse
                MouseArea {
                    id: clearArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: control.doClear()
                }
            }

            Loader {
                objectName: "suffixNode"
                visible: control.suffixIsNode && control.suffixShown
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: control.suffixIsNode ? control.suffix : null
            }

            Text {
                objectName: "suffixText"
                visible: control.suffixIsText && control.suffixShown
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: control.textGap
                Layout.rightMargin: control.textGap
                text: control.suffixIsText ? String(control.suffix) : ""
                color: control.iconColor
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: Font.DemiBold
            }

            Icon {
                objectName: "suffixIcon"
                visible: control.suffixShown && control.suffixIcon !== ""
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: control.iconGap
                Layout.rightMargin: control.iconGap
                name: control.suffixIcon
                size: 16
                color: control.iconColor
            }

            // ---- .semi-input-modebtn ----
            Item {
                objectName: "modeBtn"
                visible: control.showModeBtn
                Layout.alignment: Qt.AlignVCenter
                Layout.fillHeight: true
                implicitWidth: Theme.current.widthIconMedium + Theme.current.spacingTight * 2

                Icon {
                    anchors.centerIn: parent
                    // 官方 index.tsx:349：闭眼 eye_closed_solid，睁眼 eye_opened
                    name: control.eyeClosed ? "eye_closed_solid" : "eye_opened"
                    size: 16
                    color: eyeArea.containsMouse
                        ? Theme.current.colorPrimaryHover : control.iconColor
                }

                MouseArea {
                    id: eyeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // 官方 handleClickEye：切换显隐后把焦点还给输入框
                    onClicked: {
                        control.revealed = !control.revealed;
                        field.forceActiveFocus();
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hover
        enabled: control.enabled
    }

    TapHandler {
        id: pointer
        enabled: control.enabled
        onTapped: field.forceActiveFocus()
    }
}
