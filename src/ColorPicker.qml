pragma ComponentBehavior: Bound

import QtQuick
import "ColorConvert.js" as Convert

// 颜色选择器。一整块取色区 + 色相条 + 透明度条 + 手输区。
//
//     ColorPicker { alpha: true; onChanged: (v) => console.log(v.hex) }
//     ColorPicker { usePopover: true; defaultValue: "#39c5bb" }
//
// 值是一个对象（官方 shape，semi-foundation/colorPicker/foundation.ts:15-19）：
//     { hsva: {h,s,v,a}, rgba: {r,g,b,a}, hex: "#39c5bb" }
// 本库额外接受直接给字符串（内部走 colorStringToValue 归一），官方没有这条路。
//
// 规格（semi-foundation/colorPicker/colorPicker.scss + variables.scss，本地 semi.css 实测）：
//   取色区：宽高 = width / areaHeight（默认 280），只有上面两个角是 8 的圆角；底色
//     hsv(h,100,100)，上面压两层渐变（to top #000→透明、to right #fff→透明），再 1px
//     内描边 rgba(0,0,0,.05)；把手 20×20 圆、2px 白边（colorPicker.scss:9-29）。
//   色相条：高 10、上边距 6、圆角 full、彩虹渐变按 0/17/33/50/67/83/100% 分档；
//     把手 18×18、2px 白边，垂直居中在轨道上（上下各溢出 4px，:60-66）。
//   透明度条：轨道同上但底是 8px 棋盘（官方那张内嵌 svg），里面叠一层 radius 4 的
//     hsla(a=0)→hsla(a=1) 渐变；把手同样是棋盘 + 2px 白边（:34-58）。
//   手输区：上边距 8，横排垂直居中 —— 20×20 圆角 4 的当前色块、4px 之后是连成一组的
//     small 控件（值输入 94、百分比输入 58px、格式下拉 80px），相邻处画 1px colorBorder
//     分隔线（input.scss:593-673），最后是 24×24 的滴管按钮（只有图标的 small 按钮）。
//   弹层模式：整体内边距 8，默认 trigger 是 24×24 圆角 4 的色块（:99-108）。
Item {
    id: control

    // ---- 官方属性面（content/input/colorpicker/index.md:139-153）----
    property var value: undefined
    property var defaultValue: ({
        hsva: {h: 176, s: 71, v: 77, a: 1},
        rgba: {r: 57, g: 197, b: 187, a: 1},
        hex: "#39c5bb"
    })
    property bool alpha: true
    property bool eyeDropper: true
    property int defaultFormat: Enums.FormatHex
    // 官方的 width 就是面板宽 = 取色区宽（index.tsx:123 同一份值）。这里没叫 width 有两个原因：
    // QQuickItem::width 是 FINAL 不能在本类型里重声明；而且弹层模式下根只有 24×24 的 trigger
    // 那么大（Qt 会把没显式赋值的 width 顶成 implicitWidth），拿它当面板宽会被拽成 24。
    property real panelWidth: 280
    readonly property real areaWidth: control.panelWidth
    // 官方的 height 指的是取色区高度（index.tsx:123），本库的 height 归 Item 自己用，
    // 所以这个改叫 areaHeight，默认值同样是 280。
    property int areaHeight: 280
    property bool usePopover: false
    property Component topSlot: null
    property Component bottomSlot: null
    // 官方是往 ColorPicker 里塞 children 当 Popover 的 trigger（index.tsx:154），
    // QML 的 children 已经被面板自己占了，所以这一路做成 Component
    property Component triggerContent: null

    signal changed(var value)

    // ---- 内部状态 ----
    property var _inner: control.normalize(control.defaultValue)
    readonly property var currentColor: control.normalize(
        control.value !== undefined ? control.value : control._inner)
    property int format: control.defaultFormat
    // 手输框的内容：正在编辑时原样显示用户打的字（官方 DataPart 的 inputValue 状态），
    // 没在编辑就按当前色 + 格式算规范值（componentDidUpdate 里同样是重算覆盖）。
    property string typedText: ""
    property bool typing: false
    readonly property string inputValue: control.typing ? control.typedText
        : Convert.inputValueOf(control.currentColor, control.formatName)

    readonly property real areaHandleSize: 20
    readonly property real sliderHandleSize: 18
    readonly property real sliderHeight: 10
    readonly property real sliderGap: 6              // $spacing-colorPicker_slider-marginTop
    readonly property real dataPartGap: 8            // $spacing-colorPicker_dataPart-marginTop
    readonly property real dataPartHeight: Appearance.inputWrapperHeight(Theme.current, Enums.Small)
    readonly property real demoBlockSize: 20
    readonly property real demoBlockGap: Theme.current.spacingExtraTight   // inputGroup marginLeft
    readonly property real numberFieldWidth: 58      // $width-colorPicker-colorPickerInputNumber
    readonly property real formatFieldWidth: 80      // $width-colorPicker-formatSelect
    // 官方那颗滴管是「只有图标的 small 按钮」：`.semi-button-with-icon-only.semi-button-size-small`
    // 写死 24×24（padding 4 + 16 图标）。本库 Button 没有 with-icon-only 这条规则，
    // 按普通按钮算出来是 48 宽，会把整条手输行挤窄到 hex 输入框连「#」都放不下。
    readonly property real eyeButtonSize: 24
    readonly property real triggerSize: 24           // $width-colorPicker-defaultTrigger

    implicitWidth: control.usePopover ? trigger.width : control.areaWidth
    implicitHeight: control.usePopover ? trigger.height : control.panelHeight
    readonly property real slotHeight: (topLoader.item as Item ? (topLoader.item as Item).implicitHeight : 0)
        + (bottomLoader.item as Item ? (bottomLoader.item as Item).implicitHeight : 0)
    readonly property real panelHeight: control.areaHeight + control.sliderGap + control.sliderHeight
        + (control.alpha ? control.sliderGap + control.sliderHeight : 0)
        + control.dataPartGap + control.dataPartHeight + control.slotHeight

    // 测试要看真正画出来的那几个 item，从外面没有别的通路
    readonly property var _panel: panel
    readonly property var _area: area
    readonly property var _areaHandle: areaHandle
    readonly property var _hue: hue
    readonly property var _hueHandle: hueHandle
    readonly property var _alpha: alpha
    readonly property var _alphaHandle: alphaHandle
    readonly property var _dataPart: dataPart
    readonly property var _group: group
    readonly property var _demoBlock: demoBlock
    readonly property var _hexField: hexField
    readonly property var _numberField: numberField
    readonly property var _formatField: formatField
    readonly property var _eyeButton: eyeButton
    readonly property var _trigger: trigger
    readonly property var _popup: popup

    function normalize(v) {
        if (typeof v === "string")
            return Convert.colorStringToValue(v);
        return v;
    }

    // 官方是 ColorPicker 的静态方法（index.tsx:74），QML 类型没有静态成员，挂在实例上
    function colorStringToValue(raw) {
        return Convert.colorStringToValue(raw);
    }

    function clamp01(v) {
        return Math.min(Math.max(v, 0), 1);
    }

    // ---- 三条改动路径，全部照 semi-foundation/colorPicker/foundation.ts ----
    function notify(next) {
        control.changed(next);
        if (control.value === undefined)
            control._inner = next;
    }

    function handleChange(color, format) {
        let next;
        if (format === "hsva") {
            next = {
                hsva: color,
                rgba: Convert.hsvaToRgba(color),
                hex: Convert.hsvaToHex(color)
            };
        } else if (format === "rgba") {
            next = {
                rgba: color,
                hsva: Convert.rgbaToHsva(color),
                hex: Convert.rgbaToHex(color)
            };
        } else if (format === "hex") {
            next = {
                hex: color,
                hsva: Convert.hexToHsva(color),
                rgba: Convert.hexToRgba(color)
            };
        } else {
            throw new Error("format error");
        }
        control.notify(next);
    }

    // foundation.ts:61-81
    function handleChangeH(newH) {
        const hsva = {
            h: newH,
            s: control.currentColor.hsva.s,
            v: control.currentColor.hsva.v,
            a: control.currentColor.hsva.a
        };
        control.notify({
            rgba: Convert.hsvaToRgba(hsva),
            hsva: hsva,
            hex: Convert.hsvaToHex(hsva)
        });
    }

    // foundation.ts:84-107：不开 alpha 时把 a 钉回 1，且 hex 只留 6 位
    function handleChangeA(newAlpha) {
        const a = control.alpha ? newAlpha : 1;
        const rgba = {
            r: control.currentColor.rgba.r,
            g: control.currentColor.rgba.g,
            b: control.currentColor.rgba.b,
            a: a
        };
        const hex = Convert.rgbaToHex(rgba);
        control.notify({
            rgba: rgba,
            hex: control.alpha ? hex : hex.slice(0, 7),
            hsva: {
                h: control.currentColor.hsva.h,
                s: control.currentColor.hsva.s,
                v: control.currentColor.hsva.v,
                a: a
            }
        });
    }

    // DataPart/index.tsx:86-104：百分比那个框按「当前格式」回灌，走 handleChange 而不是
    // 透明度条那条 handleChangeA。框只在 alpha 为真时画出来，所以不用再钉 a=1。
    function handleNumberChange(a) {
        const rgba = {
            r: control.currentColor.rgba.r,
            g: control.currentColor.rgba.g,
            b: control.currentColor.rgba.b,
            a: a
        };
        if (control.formatName === "rgba") {
            control.handleChange(rgba, "rgba");
        } else if (control.formatName === "hex") {
            control.handleChange(Convert.rgbaToHex(rgba), "hex");
        } else {
            control.handleChange({
                h: control.currentColor.hsva.h,
                s: control.currentColor.hsva.s,
                v: control.currentColor.hsva.v,
                a: a
            }, "hsva");
        }
    }

    // ---- 拖拽换算 ----
    // foundation.ts:164-179：指针出了取色区就不更新（mousemove 挂在元素上）
    function areaMove(x, y) {
        if (x > control.areaWidth || x < 0 || y > control.areaHeight || y < 0)
            return;
        control.handleChange({
            h: control.currentColor.hsva.h,
            s: Math.round(x / control.areaWidth * 100),
            v: Math.round(100 - control.clamp01(y / control.areaHeight) * 100),
            a: control.currentColor.hsva.a
        }, "hsva");
    }

    // 色相 / 透明度条把 mousemove 挂在 window 上，所以拖出轨道会钳到端点
    function hueMove(x) {
        control.handleChangeH(Math.round(control.clamp01(x / control.areaWidth) * 360));
    }

    function alphaMove(x) {
        control.handleChangeA(Number(control.clamp01(x / control.areaWidth).toFixed(2)));
    }

    // ---- 把手位置（foundation.ts:158-195）----
    readonly property real areaHandleX: control.currentColor.hsva.s / 100 * control.areaWidth
        - control.areaHandleSize / 2
    readonly property real areaHandleY: (1 - control.currentColor.hsva.v / 100) * control.areaHeight
        - control.areaHandleSize / 2
    readonly property real hueHandleX: control.currentColor.hsva.h / 360 * control.areaWidth
        - control.sliderHandleSize / 2
    readonly property real alphaHandleX: control.currentColor.hsva.a * control.areaWidth
        - control.sliderHandleSize / 2
    readonly property color handleColor: Qt.rgba(control.currentColor.rgba.r / 255,
        control.currentColor.rgba.g / 255, control.currentColor.rgba.b / 255,
        control.currentColor.rgba.a)
    // 取色区底色 = hsvaToHslString({h, s:100, v:100})，等价于 hsvaToHex 同参数
    readonly property string areaBaseColor: Convert.hsvaToHex(
        {h: control.currentColor.hsva.h, s: 100, v: 100, a: 1})
    readonly property string formatName: control.format === Enums.FormatRgba ? "rgba"
        : (control.format === Enums.FormatHsva ? "hsva" : "hex")

    onCurrentColorChanged: control.typing = false
    onFormatChanged: control.typing = false

    // 面板在「根上」和「弹层里」之间搬，和 CheckboxGroup 同一套做法
    onUsePopoverChanged: control.syncPanelHost()
    Component.onCompleted: control.syncPanelHost()

    function syncPanelHost() {
        const host = control.usePopover ? popup.contentItem : control;
        if (panel.parent !== host)
            panel.parent = host;
        panel.x = 0;
        panel.y = 0;
    }

    // ---- trigger（usePopover 模式才出现）：没有自定义内容时是 24×24 的色块 ----
    Item {
        id: trigger

        objectName: "popoverTrigger"
        visible: control.usePopover
        width: customTrigger.item as Item ? (customTrigger.item as Item).implicitWidth
            : control.triggerSize
        height: customTrigger.item as Item ? (customTrigger.item as Item).implicitHeight
            : control.triggerSize

        Loader {
            id: customTrigger

            objectName: "customTriggerLoader"
            sourceComponent: control.triggerContent
        }

        Rectangle {
            objectName: "defaultTrigger"
            visible: customTrigger.item === null
            anchors.fill: parent
            radius: 4                              // $radius-colorPicker-defaultTrigger
            color: control.currentColor.hex
        }

        TapHandler {
            enabled: control.usePopover
            onTapped: popup.toggle()
        }
    }

    PopupBase {
        id: popup

        objectName: "colorPickerPopover"
        anchor: trigger
        placement: Enums.BottomLeft
        gap: 6
        padding: Theme.current.spacingTight        // $spacing-colorPicker_popover-padding = 8
        fillColor: Theme.current.colorBg3

        implicitWidth: control.areaWidth + popup.padding * 2
        implicitHeight: control.panelHeight + popup.padding * 2
    }

    // ---- 面板本体 ----
    Item {
        id: panel

        objectName: "colorPickerPanel"
        width: control.areaWidth
        height: control.panelHeight

        Loader {
            id: topLoader

            objectName: "topSlotLoader"
            sourceComponent: control.topSlot
        }

        // 取色区
        Item {
            id: area

            objectName: "colorChooseArea"
            y: topLoader.y + topLoader.height
            width: control.areaWidth
            height: control.areaHeight

            Canvas {
                id: areaCanvas

                objectName: "areaCanvas"
                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.save();
                    const corner = 8;
                    ctx.beginPath();
                    ctx.moveTo(0, corner);
                    ctx.arcTo(0, 0, corner, 0, corner);
                    ctx.lineTo(width - corner, 0);
                    ctx.arcTo(width, 0, width, corner, corner);
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.clip();

                    ctx.fillStyle = control.areaBaseColor;
                    ctx.fillRect(0, 0, width, height);

                    const dark = ctx.createLinearGradient(0, height, 0, 0);
                    dark.addColorStop(0, "#000000");
                    dark.addColorStop(1, "rgba(0, 0, 0, 0)");
                    ctx.fillStyle = dark;
                    ctx.fillRect(0, 0, width, height);

                    const light = ctx.createLinearGradient(0, 0, width, 0);
                    light.addColorStop(0, "#ffffff");
                    light.addColorStop(1, "rgba(255, 255, 255, 0)");
                    ctx.fillStyle = light;
                    ctx.fillRect(0, 0, width, height);

                    // box-shadow: inset 0 0 0 1px rgba(0,0,0,.05)
                    ctx.strokeStyle = "rgba(0, 0, 0, 0.05)";
                    ctx.lineWidth = 2;
                    ctx.strokeRect(0, 0, width, height);
                    ctx.restore();
                }

                Connections {
                    target: control

                    function onAreaBaseColorChanged() {
                        areaCanvas.requestPaint();
                    }
                }
            }

            Rectangle {
                id: areaHandle

                objectName: "areaHandle"
                x: control.areaHandleX
                y: control.areaHandleY
                width: control.areaHandleSize
                height: control.areaHandleSize
                radius: width / 2
                color: control.handleColor
                border.width: 2
                border.color: Theme.current.colorWhite
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons

                onPressed: (mouse) => control.areaMove(mouse.x, mouse.y)
                onPositionChanged: (mouse) => control.areaMove(mouse.x, mouse.y)
            }
        }

        // 色相条
        Item {
            id: hue

            objectName: "colorSlider"
            y: area.y + area.height + control.sliderGap
            width: control.areaWidth
            height: control.sliderHeight

            Canvas {
                objectName: "hueCanvas"
                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.save();
                    const r = height / 2;
                    ctx.beginPath();
                    ctx.moveTo(r, 0);
                    ctx.arcTo(width, 0, width, r, r);
                    ctx.arcTo(width, height, width - r, height, r);
                    ctx.lineTo(r, height);
                    ctx.arcTo(0, height, 0, r, r);
                    ctx.arcTo(0, 0, r, 0, r);
                    ctx.closePath();
                    ctx.clip();

                    // to right, #f00 0%, #ff0 17%, #0f0 33%, #0ff 50%, #00f 67%, #f0f 83%, #f00 100%
                    const g = ctx.createLinearGradient(0, 0, width, 0);
                    g.addColorStop(0, "#ff0000");
                    g.addColorStop(0.17, "#ffff00");
                    g.addColorStop(0.33, "#00ff00");
                    g.addColorStop(0.5, "#00ffff");
                    g.addColorStop(0.67, "#0000ff");
                    g.addColorStop(0.83, "#ff00ff");
                    g.addColorStop(1, "#ff0000");
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, width, height);
                    ctx.restore();
                }
            }

            Rectangle {
                id: hueHandle

                objectName: "hueHandle"
                x: control.hueHandleX
                y: (control.sliderHeight - control.sliderHandleSize) / 2
                width: control.sliderHandleSize
                height: control.sliderHandleSize
                radius: width / 2
                color: control.areaBaseColor
                border.width: 2
                border.color: Theme.current.colorWhite
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons

                onPressed: (mouse) => control.hueMove(mouse.x)
                onPositionChanged: (mouse) => control.hueMove(mouse.x)
            }
        }

        // 透明度条
        Item {
            id: alpha

            objectName: "alphaSlider"
            visible: control.alpha
            y: hue.y + hue.height + control.sliderGap
            width: control.areaWidth
            height: control.sliderHeight

            Canvas {
                id: checkerCanvas

                objectName: "checkerCanvas"
                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.save();
                    const r = height / 2;
                    ctx.beginPath();
                    ctx.moveTo(r, 0);
                    ctx.arcTo(width, 0, width, r, r);
                    ctx.arcTo(width, height, width - r, height, r);
                    ctx.lineTo(r, height);
                    ctx.arcTo(0, height, 0, r, r);
                    ctx.arcTo(0, 0, r, 0, r);
                    ctx.closePath();
                    ctx.clip();
                    // 官方那张 16×16 内嵌 svg：右上 + 左下两个 8×8、fill-opacity .05
                    ctx.fillStyle = "rgba(0, 0, 0, 0.05)";
                    for (let y = 0; y < height; y += 8) {
                        for (let x = 8; x < width; x += 16) {
                            if (y % 16 === 0)
                                ctx.fillRect(x, y, 8, 8);
                        }
                        for (let x = 0; x < width; x += 16) {
                            if (y % 16 === 8)
                                ctx.fillRect(x, y, 8, 8);
                        }
                    }
                    ctx.restore();
                }
            }

            // 内层：radius 4 的 hsla(a=0) → hsla(a=1) 渐变
            Canvas {
                id: alphaGradientCanvas

                objectName: "alphaGradientCanvas"
                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.save();
                    ctx.beginPath();
                    ctx.rect(0, 0, width, height);
                    ctx.clip();
                    const base = {
                        h: control.currentColor.hsva.h,
                        s: control.currentColor.hsva.s,
                        v: control.currentColor.hsva.v
                    };
                    const g = ctx.createLinearGradient(0, 0, width, 0);
                    g.addColorStop(0, Convert.hsvaToHslaString({h: base.h, s: base.s, v: base.v, a: 0}));
                    g.addColorStop(1, Convert.hsvaToHslaString({h: base.h, s: base.s, v: base.v, a: 1}));
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, width, height);
                    ctx.restore();
                }

                Connections {
                    target: control

                    function onCurrentColorChanged() {
                        alphaGradientCanvas.requestPaint();
                    }
                }
            }

            Rectangle {
                id: alphaHandle

                objectName: "alphaHandle"
                x: control.alphaHandleX
                y: (control.sliderHeight - control.sliderHandleSize) / 2
                width: control.sliderHandleSize
                height: control.sliderHandleSize
                radius: width / 2
                color: control.handleColor
                border.width: 2
                border.color: Theme.current.colorWhite
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons

                onPressed: (mouse) => control.alphaMove(mouse.x)
                onPositionChanged: (mouse) => control.alphaMove(mouse.x)
            }
        }

        // 手输区
        Item {
            id: dataPart

            objectName: "dataPart"
            y: (control.alpha ? alpha.y + alpha.height : hue.y + hue.height) + control.dataPartGap
            width: control.areaWidth
            height: control.dataPartHeight

            Rectangle {
                id: demoBlock

                objectName: "demoBlock"
                anchors.verticalCenter: parent.verticalCenter
                width: control.demoBlockSize
                height: control.demoBlockSize
                radius: 4                          // $radius-colorPicker-demoBlock
                color: control.handleColor
            }

            // .semi-input-group：子项圆角归 0，只有首尾各留一侧 radius 3，
            // 相邻处画 1px colorBorder 分隔线（input.scss:593-673）
            Rectangle {
                id: group

                objectName: "inputGroup"
                anchors.verticalCenter: parent.verticalCenter
                x: demoBlock.width + control.demoBlockGap
                width: parent.width - demoBlock.width - control.demoBlockGap
                    - (eyeButton.visible ? control.eyeButtonSize : 0)
                height: control.dataPartHeight
                radius: Theme.current.radiusSmall
                clip: true
                color: Appearance.inputBackground(Theme.current, Enums.Normal, Enums.StatusDefault)

                Input {
                    id: hexField

                    objectName: "valueInput"
                    width: group.width - (control.alpha ? control.numberFieldWidth : 0)
                        - control.formatFieldWidth
                    height: control.dataPartHeight
                    radius: 0
                    size: Enums.Small
                    text: control.inputValue

                    onTextChanged: {
                        // 绑定回写（inputValue 变了把 text 顶成同一个值）不算用户输入
                        if (hexField.text === control.inputValue)
                            return;
                        const parsed = Convert.valueFromInput(hexField.text, control.formatName);
                        control.typedText = hexField.text;
                        control.typing = true;
                        if (parsed)
                            control.handleChange(parsed, control.formatName);
                        // 用户打字会把上面那条绑定冲掉，装回去，否则色值变了输入框不跟
                        hexField.text = Qt.binding(function () { return control.inputValue; });
                    }
                }

                Rectangle {
                    objectName: "separator1"
                    x: hexField.width - 1
                    width: 1
                    height: group.height - 2
                    y: 1
                    color: Theme.current.colorBorder
                }

                InputNumber {
                    id: numberField

                    objectName: "alphaNumber"
                    visible: control.alpha
                    x: hexField.width
                    width: control.numberFieldWidth
                    height: control.dataPartHeight
                    radius: 0
                    size: Enums.Small
                    hideButtons: true
                    suffix: alphaPercentNode
                    min: 0
                    max: 100
                    value: Math.round(control.currentColor.rgba.a * 100)

                    // 官方 DataPart 用的就是 onNumberChange（DataPart/index.tsx:89）
                    onNumberChange: (v) => {
                        control.handleNumberChange(Number((v / 100).toFixed(2)));
                        // InputNumber 自己写过 value，上面的绑定已断，装回去继续跟着色值走
                        numberField.value = Qt.binding(function () {
                            return Math.round(control.currentColor.rgba.a * 100);
                        });
                    }
                }

                // 官方那颗百分号是 ReactNode 后缀：.semi-colorPicker-inputNumberSuffix
                // 只改字号 14 与 4/4 内边距（colorPicker/variables.scss:19、22、27），
                // 颜色沿用 wrapper 的 color-input_default-text-default（input.scss:49）
                Component {
                    id: alphaPercentNode

                    Text {
                        text: "%"
                        font.pixelSize: 14
                        color: Theme.current.colorText0
                        leftPadding: 4
                        rightPadding: 4
                        topPadding: 4
                        bottomPadding: 4
                    }
                }

                Rectangle {
                    objectName: "separator2"
                    visible: control.alpha
                    x: numberField.x + numberField.width - 1
                    width: 1
                    height: group.height - 2
                    y: 1
                    color: Theme.current.colorBorder
                }

                Select {
                    id: formatField

                    objectName: "formatSelect"
                    x: control.alpha ? numberField.x + numberField.width : hexField.width
                    width: control.formatFieldWidth
                    height: control.dataPartHeight
                    radius: 0
                    size: Enums.Small
                    value: control.formatName
                    options: [{label: "hex", value: "hex"}, {label: "rgba", value: "rgba"},
                        {label: "hsva", value: "hsva"}]

                    onSelected: (v) => {
                        control.format = v === "rgba" ? Enums.FormatRgba
                            : (v === "hsva" ? Enums.FormatHsva : Enums.FormatHex);
                    }
                }
            }

            Button {
                id: eyeButton

                objectName: "eyeDropperButton"
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                visible: control.eyeDropper
                width: control.eyeButtonSize
                height: control.eyeButtonSize
                tone: Enums.Tertiary
                variant: Enums.Light
                size: Enums.Small
                icon: "eyedropper"
                // 浏览器的 EyeDropper API 在 Qt 这边没有对应物。官方那份实现
                // （DataPartFoundation.ts:77-98）拿不到 window.EyeDropper 时也是直接 return，
                // 所以按钮照画、点了不做任何事。
            }
        }

        Loader {
            id: bottomLoader

            objectName: "bottomSlotLoader"
            y: dataPart.y + dataPart.height
            sourceComponent: control.bottomSlot
        }
    }
}
