import QtQuick

// 命令式对话框的卡片 —— 官方 semi-ui/modal/ConfirmModal.tsx 的等价物。
//
// 官方那一份就是把 type / icon / content 摊成 Modal 的三个 prop，再自己拿 useState 管开合：
//
//     <Modal className="semi-modal-confirm" title={<span …>{title}</span}>
//         icon={cloneElement(icon, { className: '…confirm-icon …<type>-icon', size: 'extra-large' })}
//         visible={visible} confirmLoading cancelLoading onOk onCancel {...rest}>
//         <div className="semi-modal-confirm-content">{content}</div>
//     </Modal>
//
// 所以这里直接以 Modal 为根：官方 config 里那些 ModalProps 全都天然可用（继承下来的属性面）。
//
// 落地的三条行为：
//   · handleOk / handleCancel：先跑调用方的回调，返回值不是 promise 就立刻关（:33-52 / :55-74）。
//     端口没有 promise，改成「点下去时 confirmLoading / cancelLoading 为真就不关」——
//     与 src/Feedback.qml 同一口径；
//   · 标题行下边距 24→8：官方由 `.semi-modal-confirm .semi-modal-header` 那条 scss 决定
//     （$spacing-modal_confirm_header-marginBottom = 8px），这里就照抄那个 className，
//     Modal 只认这一个类名（见 src/Modal.qml 的 confirmShape）；
//   · content 那一层是个没有 margin / padding 的 div ⇒ 直接做成 Modal 的子项。
//
// 与官方的差异：
//   · `icon` 官方是 ReactNode 再被 cloneElement 强行改成 extra-large + 着色；这里 iconName
//     那支由本组件按 type 上色并给到 24，Component 那支原样渲染（端口没法改写调用方的 Component），
//     所以官方 custom() 那种「自定义图标也跟着着色」只有字符串档能做到；
//   · hasCancel 官方压根没传 ⇒ 命令式那五支**确定与取消都在**（文档 API 表里也没这一项），
//     浏览器实测：cancel = tertiary light、ok = okType solid，error 那支 ok = danger solid。
Modal {
    id: control

    // 官方 ConfirmProps = ModalProps + type（success|info|warning|error|confirm）
    property string confirmType: "info"
    // 官方 config.content：字符串或 Component 两支
    property string contentText: ""
    property var contentComponent: undefined
    // 官方 withInfo 那五个包装函数往 props 里塞的默认图标；config 自己给了就以 config 为准
    // （...props 排在默认值之后）。这两个口子是宿主写图标的地方 —— 直接写 Modal 的 icon
    // 会把下面那条绑定打断，所以另开两个属性。
    property string iconName: ""
    property var iconComponent: undefined
    // 官方 onOk / onCancel / afterClose 三个回调（返回值里的 event 对象端口没有）
    property var okCallback: null
    property var cancelCallback: null
    property var afterCloseCallback: null
    // 官方 ConfirmModal 的 useState(true)
    property bool shown: true

    // 退场动画结束：告诉宿主可以销毁这张卡（宿主自己接 Modal 的 afterClose 会重复一次时机）
    signal hideFinished

    readonly property string defaultIconName: control._iconOf(control.confirmType)
    readonly property color typeColor: control._colorOf(control.confirmType)

    className: "semi-modal-confirm"
    visible: control.shown
    icon: control.iconComponent !== undefined ? control.iconComponent
        : (control.iconName !== "" ? control.iconName : control.defaultIconName)
    iconColor: control.typeColor

    onOk: {
        if (control.okCallback !== null && control.okCallback !== undefined)
            control.okCallback();
        if (!control.confirmLoading)
            control.shown = false;
    }

    onCancel: {
        if (control.cancelCallback !== null && control.cancelCallback !== undefined)
            control.cancelCallback();
        if (!control.cancelLoading)
            control.shown = false;
    }

    onClosed: {
        if (control.afterCloseCallback !== null && control.afterCloseCallback !== undefined)
            control.afterCloseCallback();
        control.hideFinished();
    }

    function _iconOf(t) {
        // confirm.tsx:79-113 的五个 with* 默认图标
        switch (t) {
        case "success":
            return "tick_circle";
        case "error":
            return "alert_circle";
        case "warning":
            return "alert_triangle";
        case "confirm":
            return "help_circle";
        default:
            return "info_circle";
        }
    }

    function _colorOf(t) {
        // modal.scss:186-203 那四条 `.semi-modal-{info|success|error|warning}-icon`，
        // 浏览器实测取到的就是这四条（`.semi-modal-confirm-icon` 那条被它们盖住）。
        // type 为 confirm 时图标 class 只落到 confirm 上 ⇒ primary。
        switch (t) {
        case "success":
            return Theme.current.colorSuccess;
        case "error":
            return Theme.current.colorDanger;      // $color-modal_danger-icon
        case "warning":
            return Theme.current.colorWarning;
        case "confirm":
            return Theme.current.colorPrimary;     // $color-modal_primary-icon
        default:
            return Theme.current.colorInfo;
        }
    }

    // .semi-modal-confirm-content：官方 margin / padding 都是 0，字号跟 .semi-modal 的 14 / 20
    Text {
        objectName: "modalConfirmContent"
        visible: control.contentText !== ""
        width: parent.width
        text: control.contentText
        color: Theme.current.colorText0
        font.pixelSize: Theme.current.fontSizeRegular
        lineHeight: 20
        lineHeightMode: Text.FixedHeight
        wrapMode: Text.WordWrap
    }

    Loader {
        objectName: "modalConfirmContentNode"
        active: control.contentComponent !== undefined && control.contentComponent !== null
        sourceComponent: control.contentComponent
        width: parent.width
        visible: active
    }
}
