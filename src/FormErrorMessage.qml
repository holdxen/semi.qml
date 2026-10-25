import QtQuick

// 校验信息 / 辅助文案。对应官方 Form.ErrorMessage，可从 Form 中导出单独使用。
//
//     FormErrorMessage { error: "至少 3 个字符"; validateStatus: "error" }
//     FormErrorMessage { helpText: "用于找回密码" }
//
// error 与 helpText 共用同一区块，两者都有值时优先显示 error（官方 errorMessage.tsx）。
Item {
    id: control

    objectName: "formErrorMessage"

    // string | string[] | Component
    property var error: ""
    property var helpText: ""
    // default / error / warning / success
    property string validateStatus: "default"
    property bool showValidateIcon: true
    // InputGroup 里聚合子字段错误时，官方固定用 alert_circle
    property bool isInInputGroup: false
    // extraText 走同一套排版，但颜色是 tertiary（.semi-form-field-extra-string）
    property bool isExtraText: false

    readonly property bool hasError: control.error !== undefined && control.error !== null
        && control.error !== "" && !(Array.isArray(control.error) && control.error.length === 0)
    readonly property bool hasHelp: control.helpText !== undefined && control.helpText !== null
        && control.helpText !== ""
    // 官方：async-validator 的 message: '' 约定「校验失败但不显示文案」，此时整块不渲染，
    // 否则会退回 helpText，看起来像成功态
    readonly property bool suppressed: control.error === "" && control.validateStatus === "error"

    readonly property string shownText: {
        if (Array.isArray(control.error))
            return control.error.filter(function (e) { return e; }).join(", ");
        if (control.hasError)
            return String(control.error);
        if (Array.isArray(control.helpText))
            return control.helpText.filter(function (e) { return e; }).join(", ");
        return String(control.helpText);
    }
    readonly property bool shownIsComponent: (control.hasError && !Array.isArray(control.error)
            && typeof control.error === "object")
        || (!control.hasError && control.hasHelp && !Array.isArray(control.helpText)
            && typeof control.helpText === "object")

    readonly property color foreground: control.isExtraText ? Theme.current.colorTertiary
        : (control.hasError ? Theme.current.colorDanger : Theme.current.colorText0)

    visible: (control.hasError || control.hasHelp) && !control.suppressed
    implicitWidth: row.implicitWidth
    // 官方 margin-top: 4 折进自身高度，外层用 Column 排时不用再补间距
    implicitHeight: control.marginTop + (visible
        ? Math.max(row.implicitHeight, Theme.current.fontSizeRegular) : 0)

    property real marginTop: Theme.current.spacingExtraTight

    Row {
        id: row

        x: 0
        y: control.marginTop
        spacing: Theme.current.spacingExtraTight

        // .semi-form-field-validate-status-icon { top: 2px; align-self: flex-start }
        // 图标没有单独设字号，继承本区块的 14px（.semi-icon 本身不带 font-size）
        Icon {
            objectName: "formErrorMessageIcon"

            visible: control.showValidateIcon
                && (control.isInInputGroup || control.validateStatus === "error"
                    || control.validateStatus === "warning")
            name: (control.isInInputGroup || control.validateStatus === "error")
                ? "alert_circle" : "alert_triangle"
            size: Theme.current.fontSizeRegular
            // alert_triangle 被单独覆写成 warning，alert_circle 跟着文字色走
            color: control.validateStatus === "warning" && !control.isInInputGroup
                ? Theme.current.colorWarning : control.foreground
            y: 2
        }

        Text {
            objectName: "formErrorMessageText"

            visible: !control.shownIsComponent
            text: control.shownText
            color: control.foreground
            font.pixelSize: Theme.current.fontSizeRegular
        }

        Loader {
            visible: control.shownIsComponent
            sourceComponent: control.hasError ? control.error : control.helpText
        }
    }
}
