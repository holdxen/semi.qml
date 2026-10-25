import QtQuick

// 自定义内容占位。对应官方 Form.Slot：让非 Field 的内容也用同一套 Label / 错误提示布局。
//
//     FormSlot {
//         label: "SlotA"
//         error: "我是 SlotA 的 ErrorMessage"
//         Text { text: "我是自定义内容" }
//     }
//
// label 可以是字符串，也可以是 { text, required, optional, align, width }；
// Form 上的 labelWidth / labelAlign / labelPosition 会自动作用到这里。
Item {
    id: control

    objectName: "formSlot"

    default property alias content: slotArea.data

    property var form: null
    // string 或 Label 配置对象
    property var label: undefined
    property string labelPosition: ""
    // string 或 ErrorMessage 配置对象
    property var error: undefined
    property Component errorComponent: null

    readonly property var target: control.form !== null && control.form !== undefined
        ? control.form : control.searchForm()

    readonly property string formLayout: control.target ? control.target.layout : "vertical"
    readonly property string labelPos: control.labelPosition !== "" ? control.labelPosition
        : (control.target ? control.target.labelPosition : "top")
    readonly property bool isObjectLabel: control.label !== undefined
        && control.label !== null && typeof control.label === "object"
    readonly property var labelText: control.isObjectLabel
        ? (control.label.text !== undefined ? control.label.text : "") : control.label
    readonly property real labelBoxWidth: control.isObjectLabel && control.label.width !== undefined
        ? Number(control.label.width)
        : (control.target && control.target.labelWidth > 0 ? control.target.labelWidth : 0)

    function searchForm() {
        let node = control.parent;
        while (node !== null && node !== undefined) {
            // qmllint disable missing-property
            if (node.registerField !== undefined && node.getFormState !== undefined)
                return node;
            // qmllint enable missing-property
            node = node.parent;
        }
        return null;
    }

    function errorText() {
        if (control.error === undefined || control.error === null)
            return "";
        if (typeof control.error === "object" && !Array.isArray(control.error))
            return control.error.error !== undefined ? String(control.error.error) : "";
        if (Array.isArray(control.error))
            return control.error.filter(function (e) { return e; }).join(", ");
        return String(control.error);
    }

    function errorStatus() {
        if (control.error !== undefined && control.error !== null
                && typeof control.error === "object" && !Array.isArray(control.error)
                && control.error.validateStatus !== undefined)
            return String(control.error.validateStatus);
        return control.errorText() === "" ? "default" : "error";
    }

    width: control.formLayout === "horizontal" ? control.implicitWidth + control.paddingRight
        : (control.parent ? control.parent.width : control.implicitWidth)
    implicitWidth: 320
    implicitHeight: control.paddingTop
        + (labelBlock.visible && control.labelPos !== "left" ? labelBlock.implicitHeight : 0)
        + Math.max(mainColumn.implicitHeight,
            labelBlock.visible && control.labelPos === "left" ? labelBlock.implicitHeight : 0)
        + control.paddingBottom

    readonly property real paddingTop: control.formLayout === "vertical" ? Theme.current.spacingBaseTight : 0
    readonly property real paddingBottom: control.formLayout === "vertical" ? Theme.current.spacingBaseTight : 0
    readonly property real paddingRight: control.formLayout === "horizontal" ? Theme.current.spacingBase : 0

    FormLabel {
        id: labelBlock

        visible: control.label !== undefined && control.label !== null && control.label !== ""
        x: 0
        y: control.paddingTop
        width: control.labelBoxWidth > 0 ? control.labelBoxWidth : labelBlock.implicitWidth
        height: implicitHeight
        text: control.labelText
        required: control.isObjectLabel && control.label.required === true
        optional: control.isObjectLabel && control.label.optional === true
        extra: control.isObjectLabel && control.label.extra !== undefined ? control.label.extra : null
        align: control.isObjectLabel && control.label.align !== undefined ? control.label.align
            : (control.target ? control.target.labelAlign : "left")
        labelWidth: control.labelBoxWidth
        padTop: control.labelPos === "left" ? (Theme.current.heightControlDefault - 20) / 2 : 0
        blockLevel: control.labelPos !== "left"
    }

    Column {
        id: mainColumn

        x: control.labelPos === "left" ? labelBlock.width : 0
        y: control.paddingTop + (labelBlock.visible && control.labelPos !== "left"
            ? labelBlock.implicitHeight : 0)
        width: control.labelPos === "left"
            ? Math.max(0, control.width - labelBlock.width - control.paddingRight)
            : Math.max(0, control.width - control.paddingRight)
        spacing: 0

        Item {
            id: slotArea

            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }

        FormErrorMessage {
            visible: control.errorText() !== "" || control.errorComponent !== null
            error: control.errorComponent !== null ? control.errorComponent : control.errorText()
            validateStatus: control.errorStatus()
            showValidateIcon: control.target ? control.target.showValidateIcon : true
        }
    }
}
