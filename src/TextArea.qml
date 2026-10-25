pragma ComponentBehavior: Bound

import QtQuick

// 多行输入。官方 API 面见 semi-ui/input/textarea.tsx + semi-foundation/input/textareaFoundation.ts，
// 外观见 semi-foundation/input/textarea.scss。
//
//     TextArea { placeholderText: "说点什么" }
//     TextArea { maxCount: 100; showClear: true }
//     TextArea { autosize: ({ minRows: 1, maxRows: 3 }) }
//     TextArea { showLineNumber: true; rows: 8 }
//
// 根项就是官方的 .semi-input-textarea-wrapper（底色 / 描边 / 圆角都在这一层），
// 里面依次是行号栏、输入区、清除按钮、字数统计。
Rectangle {
    id: control

    property alias text: area.text
    property alias textArea: area
    property alias readOnly: area.readOnly
    property alias inputMethodHints: area.inputMethodHints

    property string placeholderText: ""
    // ---- 官方同名 prop ----
    property int rows: 4                                     // 官方默认 4 行
    property int maxCount: 0                                 // 官方 maxCount，>0 时显示字数统计
    property bool showClear: false
    property bool borderless: false
    property int validateStatus: Enums.StatusDefault
    // 官方 autosize：true 或 { minRows, maxRows }
    property var autosize: false
    property bool showLineNumber: false
    property int lineNumberStart: 1
    property color lineNumberColor: Theme.current.colorText2
    // 官方 textareaStyle.height —— 这里只把高度这一项拎出来
    property real textareaHeight: -1
    // 官方 composition：Qt 的输入法 preedit 不写进 text，QML 侧没有可观察差异
    property bool composition: false
    property int maxLength: 0
    property var getValueLength: null

    signal cleared
    signal accepted
    // 官方 onKeyDown 的等价物：默认不改行为（事件照样落到 TextEdit），
    // 使用者在回调里把 event.accepted 置 true 就能挡下这次按键
    signal keyPressed(var event)

    readonly property int paddingX: Theme.current.spacingBaseTight
    readonly property int paddingY: 5
    // 官方 font-size-regular 是 14 / 20，开行号时 textarea.scss:312 还会把行高改成 1.5（21px）。
    // Qt 的 TextEdit 根本没有 lineHeight / lineSpacing（实测：Cannot assign to non-existent
    // property "lineHeight"），只能吃字体的自然行高，所以这里取探针量出来的值，
    // 两处（正文与行号栏）必须用同一个值才能对齐。
    readonly property real lineHeightPx: lineProbe.implicitHeight > 0
        ? lineProbe.implicitHeight : 20
    // $height-textarea_counter: 24px
    readonly property real counterHeight: control.maxCount > 0 ? 24 : 0
    readonly property bool autoOn: control.autosize === true
        || (control.autosize !== null && typeof control.autosize === "object")
    readonly property int minRows: control.autosize !== null && typeof control.autosize === "object"
        ? (control.autosize.minRows === undefined ? control.rows : Number(control.autosize.minRows))
        : (control.autosize === true ? control.rows : control.rows)
    readonly property int maxRows: control.autosize !== null && typeof control.autosize === "object"
        && control.autosize.maxRows !== undefined ? Number(control.autosize.maxRows) : 0

    readonly property int controlState:
        Appearance.fieldState(control.enabled, area.activeFocus, hover.hovered, false)
    readonly property bool allowClear: area.text !== "" && control.showClear
        && control.enabled && !area.readOnly && (area.activeFocus || hover.hovered)

    // 内容区高度。官方 autosize 走「隐藏副本量 scrollHeight」那套
    // （util/calculateNodeHeight.ts），Qt 侧 area.contentHeight 本身就是排版后的
    // 实际内容高度（含软换行），直接拿它夹在 minRows / maxRows 之间。
    readonly property real contentHeight: {
        if (control.textareaHeight > 0)
            return control.textareaHeight;
        const one = control.lineHeightPx;
        if (!control.autoOn)
            return control.rows * one;
        let h = Math.max(area.contentHeight, control.minRows * one);
        if (control.maxRows > 0)
            h = Math.min(h, control.maxRows * one);
        return h;
    }

    implicitWidth: 240
    implicitHeight: control.contentHeight + control.paddingY * 2 + 2 + control.counterHeight

    radius: Theme.current.radiusSmall
    color: control.borderless ? "transparent"
        : Appearance.inputBackground(Theme.current, control.controlState, control.validateStatus)
    border.width: 1
    border.color: control.borderless && !area.activeFocus && !hover.hovered
        ? "transparent" : Appearance.inputBorderColor(Theme.current, control.controlState, control.validateStatus)

    Behavior on color {
        ColorAnimation { duration: Theme.current.durationFast }
    }

    function lengthOf(value) {
        const s = String(value === undefined || value === null ? "" : value);
        if (control.getValueLength instanceof Function) {
            const n = Number(control.getValueLength(s));
            return Number.isNaN(n) ? s.length : n;
        }
        return s.length;
    }

    // 官方 TextArea 与 Input 不同：没有 getValueLength 也照样按 value.length 截断
    function truncateToMaxLength(value) {
        const s = String(value);
        if (control.maxLength <= 0 || control.lengthOf(s) <= control.maxLength)
            return s;
        if (!(control.getValueLength instanceof Function))
            return s.slice(0, control.maxLength);
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

    // 量一个自然行高：Qt 的 TextEdit 没有 lineHeight，正文只能用字体自然行高，
    // 行号栏必须用同一个值才会逐行对齐
    TextEdit {
        id: lineProbe

        visible: false
        font.pixelSize: Theme.current.fontSizeRegular
        text: "X"
    }

    // 行号栏要按「硬换行 + 软换行」出行号，所以先拆出硬行
    function hardLines() {
        return area.text === "" ? [""] : String(area.text).split("\n");
    }

    function doClear() {
        area.text = "";
        control.cleared();
    }

    // 官方 <textarea>.focus() 的等价物：聚焦**内层 TextEdit 本体**。
    // 不能用根项的 forceActiveFocus() —— 那只把 activeFocus 给外层 Rectangle，
    // 键 events 不会落到 area，打不了字（点容器空白处/自定义渲染 onClick 都走过这条路）。
    function focusInput() {
        area.forceActiveFocus();
    }

    // ---- 行号栏（.semi-input-textarea-lineNumber）----
    Rectangle {
        id: lineNumberPanel

        objectName: "lineNumberPanel"
        visible: control.showLineNumber
        x: 1
        y: 1
        // min-width 36（textarea.scss:285）
        width: Math.max(36, numbers.implicitWidth + control.paddingX * 2)
        height: parent.height - 2 - control.counterHeight
        color: Theme.current.colorFill1
        border.width: 0
        radius: 0
        clip: true

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // border-right: 1px solid var(--semi-color-border)（textarea.scss:277）
            width: 1
            color: Theme.current.colorBorder
        }

        Column {
            id: numbers

            objectName: "lineNumbers"
            x: control.paddingX
            y: control.paddingY
            width: lineNumberPanel.width - control.paddingX * 2
            spacing: 0

            Repeater {
                model: control.showLineNumber ? control.hardLines().length : 0

                delegate: Item {
                    id: row

                    required property int index

                    objectName: "lineNumberItem"
                    width: numbers.width
                    // 官方 textarea.tsx:446 也是按宽度除法估算软换行数（Math.ceil(量宽 / 可用宽)），
                    // 用一行隐藏 Text 量自然宽度，避免共享 TextMetrics 造成绑定环
                    height: Math.max(1, Math.ceil(
                        measure.implicitWidth / Math.max(1, area.width))) * control.lineHeightPx

                    Text {
                        id: measure

                        visible: false
                        text: control.hardLines()[row.index]
                        font: area.font
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        text: String(control.lineNumberStart + row.index)
                        color: control.lineNumberColor
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.family: "Menlo"
                        // 与正文同一个行高值，否则行号会逐行错位
                        lineHeight: control.lineHeightPx
                        lineHeightMode: Text.FixedHeight
                    }
                }
            }
        }
    }

    // ---- 输入区 ----
    Flickable {
        id: scroller

        objectName: "textareaScroller"
        x: (control.showLineNumber ? lineNumberPanel.width + 1 : 0) + 1
        y: 1
        width: Math.max(0, control.width - x - 1)
        height: Math.max(0, control.height - 2 - control.counterHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        // 滚动区按**实际文本高度**算，不吃夹过的 contentHeight：rows / maxRows 只决定盒子多高，
        // 超出盒子的行仍然要能滚到、点到
        contentHeight: Math.max(height, area.contentHeight + control.paddingY * 2)

        TextEdit {
            id: area

            x: control.paddingX
            y: control.paddingY
            width: Math.max(0, scroller.width - control.paddingX * 2
                // showClear 时 textarea 的 padding-right 变 36（variables.scss:117）
                - (control.showClear ? 36 - control.paddingX : 0))
            // 命中区 = 整个内容区。官方 <textarea> 是「盒子本身就是输入区」，点半空的地方光标落到文末；
            // 这里只吃内容高度时，多行框里点中间与点底部都落在盒子内、
            // 却在 TextEdit 外 —— 焦点与光标都进不来，只有贴着文本的那几行能点中。
            // 用 contentHeight 而不是 implicitHeight：Qt 侧「改 height → geometryChange →
            // updateSize → setImplicitHeight」会回写 implicitHeight 并通知，而这个绑定又读
            // implicitHeight ⇒ 自指环（长内容才显形，报 Binding loop at height）。
            // contentHeight（= contentSize.height()，updateSize 里同一处算出）语义相同、
            // 无 notify 回路 —— 实测三种长内容形态 0 警告，几何不变。
            height: Math.max(area.contentHeight, scroller.height - control.paddingY)
            color: Appearance.inputForeground(Theme.current, control.controlState)
            font.pixelSize: Theme.current.fontSizeRegular
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            enabled: control.enabled
            activeFocusOnTab: true

            // 挂了 Keys 处理器就会被 QML 默认吃掉，所以先显式放开，再交给外面决定
            Keys.onReturnPressed: (event) => {
                event.accepted = false;
                control.keyPressed(event);
            }

            onTextChanged: {
                const cut = control.truncateToMaxLength(area.text);
                if (cut !== area.text) {
                    const caret = area.cursorPosition - (area.text.length - cut.length);
                    area.text = cut;
                    area.cursorPosition = Math.max(0, caret);
                }
            }

            Text {
                visible: control.placeholderText !== "" && area.text === "" && !area.activeFocus
                text: control.placeholderText
                color: Appearance.inputPlaceholderColor(Theme.current, control.controlState)
                font: area.font
                wrapMode: Text.WordWrap
                width: area.width
            }
        }

        onContentYChanged: if (control.showLineNumber)
            numbers.y = control.paddingY - scroller.contentY
    }

    // ---- 清除按钮（贴在右上角，官方是 absolute top:0 right:4）----
    Item {
        objectName: "clearBtn"
        visible: control.showClear
        x: control.width - width - Theme.current.spacingExtraTight
        y: 1
        // min-width = $width-textarea-icon = 图标中尺寸 + 8（variables.scss:115）
        width: Theme.current.widthIconMedium + Theme.current.spacingTight
        height: Theme.current.heightControlDefault

        Icon {
            anchors.centerIn: parent
            visible: control.allowClear
            name: "clear"
            size: 16
            color: clearArea.containsMouse
                ? Theme.current.colorPrimaryHover : Theme.current.colorText2
        }

        MouseArea {
            id: clearArea

            anchors.fill: parent
            hoverEnabled: true
            enabled: control.allowClear
            cursorShape: Qt.PointingHandCursor
            onClicked: control.doClear()
        }
    }

    // ---- 字数统计（.semi-input-textarea-counter）----
    Text {
        objectName: "counter"
        visible: control.maxCount > 0
        width: parent.width - Theme.current.spacingBaseTight * 2
        anchors.right: parent.right
        anchors.rightMargin: Theme.current.spacingBaseTight
        y: parent.height - control.counterHeight
        height: control.counterHeight
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        topPadding: 3
        bottomPadding: 5
        text: control.lengthOf(area.text) + "/" + control.maxCount
        color: control.lengthOf(area.text) > control.maxCount
            ? Theme.current.colorDanger : Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        // font-size-small 的行高是 16（_font.scss:4）
        lineHeight: 16
        lineHeightMode: Text.FixedHeight
    }

    HoverHandler {
        id: hover
        enabled: control.enabled
    }

    TapHandler {
        enabled: control.enabled
        onTapped: area.forceActiveFocus()
    }
}
