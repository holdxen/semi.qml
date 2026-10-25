import QtQuick

// 表单分组标题。对应官方 Form.Section：只影响布局，不改变 values 的数据结构。
//
//     FormSection {
//         text: "基本信息"
//         FormItem { field: "name"; Input {} }
//     }
Item {
    id: control

    objectName: "formSection"

    default property alias content: sectionBody.data

    property var text: ""

    readonly property bool isFormSection: true

    width: control.parent ? control.parent.width : control.implicitWidth
    implicitWidth: 320
    // .semi-form-section { margin-top: 40 - 12 = 28 }，折进自身高度里
    implicitHeight: sectionBody.y + sectionBody.implicitHeight

    // 官方 &:nth-of-type(1) { margin-top: 0 } —— 表单里第一个分组不加这段留白
    readonly property real sectionMarginTop: control.isFirstSection()
        ? 0 : Theme.current.spacingSuperLoose - Theme.current.spacingBaseTight

    function isFirstSection() {
        if (control.parent === null || control.parent === undefined)
            return true;
        const kids = control.parent.children;
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i] !== control && kids[i].isFormSection === true)
                return false;
            if (kids[i] === control)
                return true;
            // qmllint enable missing-property
        }
        return true;
    }

    // .semi-form-section-text：h5、加粗、下边框 1px、padding-bottom 8、margin-bottom 4
    Text {
        id: titleBlock

        objectName: "formSectionText"

        y: control.sectionMarginTop
        width: parent.width
        text: String(control.text)
        color: Theme.current.colorText0
        font.pixelSize: Theme.current.fontSizeHeader5
        font.weight: Font.Bold
        bottomPadding: Theme.current.spacingTight
    }

    Rectangle {
        id: formRule

        objectName: "formSectionRule"

        // border-bottom 就在标题 padding-bottom 的底边上
        x: 0
        y: titleBlock.y + titleBlock.height
        width: parent.width
        height: Theme.current.borderThicknessControl
        color: Theme.current.colorBorder
    }

    Column {
        id: sectionBody

        // 标题 border-bottom 与内容之间是 margin-bottom 4
        y: titleBlock.y + titleBlock.height + formRule.height + Theme.current.spacingExtraTight
        width: parent.width
        spacing: 0
    }
}
