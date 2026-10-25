import QtQuick

// 表单标签。对应官方 Form.Label，可从 Form 中导出单独使用。
//
//     FormLabel { text: "用户名"; required: true }
//     FormLabel { text: "角色"; optional: true; labelWidth: 120; align: "right" }
//
// 必填的 * 在官方是 .semi-form-field-label-text 的 ::after，落在文字之后（margin-left 4），
// 不是前缀 —— 与早期本模块的写法相反。
Item {
    id: control

    objectName: "formLabel"

    property var text: ""
    property bool required: false
    // v2.18：true 时在文字后追加「（可选）」，同时不再显示 required 的 *
    property bool optional: false
    property Component extra: null
    property string align: "left"
    property real labelWidth: 0
    property bool disabled: false
    // top 位置的标签是 display:block，与控件之间留 marginBottom；左标签靠 padTop 对齐
    property bool blockLevel: true
    // 官方：(控件高 32 - 行高 20) / 2，让标签首行与控件文字水平对齐
    property real padTop: 0

    readonly property color foreground: control.disabled
        ? Theme.current.colorDisabledText : Theme.current.colorText0

    // .semi-form-field-label { padding-right: 16 } 属于标签盒，box-sizing: border-box
    implicitWidth: control.labelWidth > 0
        ? control.labelWidth
        : row.implicitWidth + Theme.current.spacingBase
    implicitHeight: row.height + control.padTop * 2
        + (control.blockLevel ? Theme.current.spacingExtraTight : 0)

    Row {
        id: row

        // 右对齐时留回 padding-right 16（它在 border-box 内）
        x: control.align === "right"
            ? control.width - Theme.current.spacingBase - row.implicitWidth : 0
        y: control.padTop
        spacing: 0

        Text {
            objectName: "formLabelText"

            text: String(control.text)
            color: control.foreground
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Font.Bold
        }

        Text {
            objectName: "formLabelOptional"

            visible: control.optional
            text: qsTr("（可选）")
            // .semi-form-field-label-optional-text 只改颜色，字号字重跟标签一致
            color: Theme.current.colorTertiary
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Font.Bold
        }

        Text {
            objectName: "formLabelRequired"

            visible: control.required && !control.optional
            text: "*"
            leftPadding: Theme.current.spacingExtraTight
            color: Theme.current.colorDanger
            font.pixelSize: Theme.current.fontSizeRegular
            font.weight: Font.Bold
        }

        // .semi-form-field-label-extra { margin-left: 4; display: flex; align-items: center }
        Item {
            visible: control.extra !== null
            implicitWidth: extraLoader.implicitWidth + Theme.current.spacingExtraTight
            implicitHeight: extraLoader.implicitHeight
            height: implicitHeight

            Loader {
                id: extraLoader

                x: Theme.current.spacingExtraTight
                sourceComponent: control.extra
            }
        }
    }
}
