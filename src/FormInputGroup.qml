import QtQuick

// 字段组。对应官方 Form.InputGroup：把几个控件拼成一个视觉整体，共用一个属于组的 Label。
//
//     FormInputGroup {
//         label: ({ text: "手机号码", required: true })
//
//         FormItem { field: "phonePrefix"; Select { width: 150 } }
//         FormItem { field: "phoneNumber"; Input { width: 250 } }
//     }
//
// 组内的 FormItem 不再各自插 Label / ErrorMessage（官方 isInInputGroup 的行为），
// 错误提示由组这里聚合成一条。
Item {
    id: control

    objectName: "formInputGroup"

    default property alias content: groupRow.data

    readonly property bool isFormInputGroup: true

    property var form: null
    property var label: undefined
    property string labelPosition: ""
    property var extraText: ""
    property string extraTextPosition: ""

    readonly property var target: control.form !== null && control.form !== undefined
        ? control.form : control.searchForm()

    readonly property string formLayout: control.target ? control.target.layout : "vertical"
    readonly property string labelPos: control.labelPosition !== "" ? control.labelPosition
        : (control.target ? control.target.labelPosition : "top")
    readonly property string extraPos: control.extraTextPosition !== "" ? control.extraTextPosition
        : (control.target ? control.target.extraTextPosition : "bottom")
    readonly property bool isObjectLabel: control.label !== undefined
        && control.label !== null && typeof control.label === "object"
    readonly property var labelText: control.isObjectLabel
        ? (control.label.text !== undefined ? control.label.text : "") : control.label

    readonly property var childItems: control.collectChildren()

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

    function collectChildren() {
        const list = [];
        const kids = groupRow.children;
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i].field !== undefined && kids[i].labelText !== undefined)
                list.push(kids[i]);
            // qmllint enable missing-property
        }
        return list;
    }

    // 组内所有字段的错误聚合成一条（官方 GroupError 的做法）
    readonly property string groupError: {
        const parts = [];
        const items = control.childItems;
        for (let i = 0; i < items.length; ++i) {
            if (items[i].error !== undefined && items[i].error !== "")
                parts.push(items[i].error);
        }
        // 依赖 childItems 的变化重新求值
        return parts.join(", ");
    }

    width: control.formLayout === "horizontal" ? control.implicitWidth + control.paddingRight
        : (control.parent ? control.parent.width : control.implicitWidth)
    implicitWidth: 320
    implicitHeight: control.paddingTop
        + (labelBlock.visible && control.labelPos !== "left" ? labelBlock.implicitHeight : 0)
        + Math.max(mainColumn.implicitHeight,
            labelBlock.visible && control.labelPos === "left" ? labelBlock.implicitHeight : 0)
        + control.paddingBottom

    // 官方 .semi-form-vertical .semi-form-field-group { padding: 12px 0 }
    readonly property real paddingTop: control.formLayout === "vertical" ? Theme.current.spacingBaseTight : 0
    readonly property real paddingBottom: control.formLayout === "vertical" ? Theme.current.spacingBaseTight : 0
    readonly property real paddingRight: control.formLayout === "horizontal" ? Theme.current.spacingBase : 0
    readonly property real leftLabelPad: (Theme.current.heightControlDefault - 20) / 2

    function relayout() {
        const items = control.childItems;
        // 官方用 ::after 在接缝处画 1px 分隔线，相邻控件各带 1px 边框；
        // 这里让后一个压前一个 1px，接缝自然只剩一条边框
        let x = 0;
        let tallest = 0;
        for (let i = 0; i < items.length; ++i) {
            const child = items[i];
            child.x = x;
            child.y = 0;
            child.groupIndex = i;
            child.groupCount = items.length;
            x += child.width - (i < items.length - 1 ? 1 : 0);
            tallest = Math.max(tallest, child.height);
            // qmllint disable missing-property
            child.applyGroupCorners();
            // qmllint enable missing-property
        }
        groupRow.implicitWidth = x;
        groupRow.implicitHeight = tallest;
    }

    Component.onCompleted: control.relayout()
    onChildItemsChanged: control.relayout()

    FormLabel {
        id: labelBlock

        visible: control.label !== undefined && control.label !== null && control.label !== ""
        x: 0
        y: control.paddingTop
        width: control.target && control.target.labelWidth > 0
            ? control.target.labelWidth : labelBlock.implicitWidth
        height: implicitHeight
        text: control.labelText
        required: control.isObjectLabel && control.label.required === true
        optional: control.isObjectLabel && control.label.optional === true
        align: control.isObjectLabel && control.label.align !== undefined ? control.label.align
            : (control.target ? control.target.labelAlign : "left")
        padTop: control.labelPos === "left" ? control.leftLabelPad : 0
        blockLevel: control.labelPos !== "left"
    }

    Column {
        id: mainColumn

        x: control.labelPos === "left" ? labelBlock.width : 0
        y: control.paddingTop + (labelBlock.visible && control.labelPos !== "left"
            ? labelBlock.implicitHeight : 0)
        width: Math.max(0, control.width - labelBlock.width - control.paddingRight)
        spacing: 0

        Item {
            visible: control.extraText !== undefined && control.extraText !== null
                && control.extraText !== "" && control.extraPos === "middle"
            width: mainColumn.width
            implicitHeight: extraMiddle.implicitHeight + Theme.current.spacingExtraTight

            FormErrorMessage {
                id: extraMiddle

                error: ""
                helpText: control.extraText
                showValidateIcon: false
                isExtraText: true
                marginTop: 0
            }
        }

        // .semi-input-group { display: inline-flex }
        Item {
            id: groupRow

            objectName: "inputGroupRow"

            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height

            // 组内 Field 与 FormItem 的内层控件一样，是父级 onCompleted 之后才挂上的
            onChildrenChanged: control.relayout()
            onWidthChanged: control.relayout()
        }

        FormErrorMessage {
            visible: control.groupError !== ""
            error: control.groupError
            validateStatus: "error"
            showValidateIcon: control.target ? control.target.showValidateIcon : true
            isInInputGroup: true
        }

        Item {
            visible: control.extraText !== undefined && control.extraText !== null
                && control.extraText !== "" && control.extraPos === "bottom"
            width: mainColumn.width
            implicitHeight: extraBottom.implicitHeight

            FormErrorMessage {
                id: extraBottom

                error: ""
                helpText: control.extraText
                showValidateIcon: false
                isExtraText: true
            }
        }
    }
}
