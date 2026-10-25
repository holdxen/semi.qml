pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as C
import QtQuick.Window

// Modal 的命令式调用宿主 —— 官方 semi-ui/modal/{index,confirm,useModal}.tsx 那一层的等价物。
//
// 官方 Modal 的静态面是五个方法 + 两个工具（Modal.tsx:378-402）：
//
//     Modal.info({ title, content })      Modal.success()  Modal.error()
//     Modal.warning()                     Modal.confirm()
//     const h = Modal.info({…});  h.update({…});  h.destroy();
//     Modal.destroyAll();
//     const [modal, contextHolder] = Modal.useModal();   // 要读 Context 时用这一对
//
// QML 的类型上没有静态方法，所以整套 API 落在组件实例上（同 src/Notification.qml 与
// src/Toast.qml 的做法）：摆一个 `ModalHost {}` 就是「容器 + API」那一对，它同时就是
// useModal() 返回的 contextHolder —— 官方那句「得到 contextHolder 所在位置的所有上下文」，
// 在端口里对应「config 里的 Component 由它定义处的那份作用域实例化」。
//
// 生命周期照 confirm.tsx:16-79 逐条：
//   · 每次调用创建一个 DOM 节点再渲染 ConfirmModal ⇒ 这里是 createObject 一张 ModalConfirm；
//   · 返回的引用里 destroy **其实就是 close**（:74 `return { destroy: close, update }`），
//     它不立刻卸载：把 config 的 visible 置 false 重渲染一次 ⇒ 走退场动画 ⇒ afterClose；
//   · afterClose 只跑一次（官方在 :41-47 用 `closing` 那道闸门挡重复回调；端口里 Popup
//     一次开层只发一次 closed，所以这道闸门本来就落在组件层），跑完才真的卸载；
//   · update(newConfig) 是 `{...currentConfig, ...newConfig}` 浅合并后重新渲染；
//   · destroyAll() 遍历 destroyFns 挨个 close（Modal.tsx:391-401）⇒ 会播退场动画。
//
// 上游那条「重渲染时 motion 取 `props.motion`（最初那一份）而不是合并后的
// currentConfig.motion」（confirm.tsx:47）是它自己的小瑕疵：端口不抄，`_render` 里
// 所有 key 一律取合并后的 config，`motion` 也不例外。
//
// 五个包装函数的合并顺序也照抄（confirm.tsx:79-113）：type 与默认图标排在展开之前，
// 调用方给了就盖掉；只有 error() 多改一项 —— okButtonProps 垫 `{ type: 'danger' }`，
// 且 `...omit(props, ['okButtonProps'])` 把入参整体排在前面，所以调用方的 okButtonProps
// 按 key 覆盖 danger。
//
// 与官方的差异：
//   · config 里的 onOk / onCancel 返回 promise 那一套（ConfirmModal 靠它驱动 loading 并等
//     resolve 才关）没有对应物，改成显式的 confirmLoading / cancelLoading；
//   · `width` 官方文档 API 表给 Modal.method() 写的是 520，实测走的是 size='small' 的 448
//     （ConfirmModal 压根没传 width）—— 表里那条是 stale，端口按实测；
//   · 官方把节点 append 到 document.body，这里默认挂到窗口的 Overlay.overlay；
//   · 一条 config 里出现过的 key 才写进卡片（没写、或写成 undefined 就保留上一次的值）；
//     前半条是官方 `{...currentConfig, ...newConfig}` 的语义，后半条是端口的差异 ——
//     官方显式给 undefined 会退回组件 defaultProps，这层没有对应物（见 `_propsOf`）。
Item {
    id: control

    // 官方 getPopupContainer 那一档：弹层挂到哪个节点
    property var getPopupContainer: null

    // 每一条在世的调用：合并完的 config + 卡片 + 关闭闸门
    readonly property var items: control._records
    property var _records: []

    readonly property Item container: control.getPopupContainer
        ? control.getPopupContainer()
        : (Window.window ? C.Overlay.overlay : control)

    width: 0
    height: 0

    Component {
        id: cardFactory

        ModalConfirm {}
    }

    // ---------------------------------------------------------------- 五个静态方法
    function info(cfg) { return control._open(control._with("info", cfg)) }
    function success(cfg) { return control._open(control._with("success", cfg)) }
    function warning(cfg) { return control._open(control._with("warning", cfg)) }
    function error(cfg) { return control._open(control._with("error", cfg)) }
    function confirm(cfg) { return control._open(control._with("confirm", cfg)) }

    function destroyAll() {
        // 官方 destroyFns 里存的就是各条 close()，挨个调；调完不清空（Modal.tsx:391-401）
        const list = control._records.slice();
        for (let i = 0; i < list.length; ++i)
            control._closeRec(list[i]);
    }

    // ---------------------------------------------------------------- 合并
    function _with(type, cfg) {
        const raw = (cfg === undefined || cfg === null) ? {} : cfg;
        // 官方 `{ type: 'info', icon: <IconInfoCircle/>, ...props }`：默认在前，入参在后
        const m = { type: type, iconName: control._iconOf(type) };
        const keys = Object.keys(raw);
        for (let i = 0; i < keys.length; ++i)
            m[keys[i]] = raw[keys[i]];
        if (type === "error") {
            // withError 另外垫 danger，并把 okButtonProps 从整体展开里摘出去单独合
            const base = (raw.okButtonProps === undefined || raw.okButtonProps === null)
                ? {} : raw.okButtonProps;
            const merged = { type: "danger" };
            const bk = Object.keys(base);
            for (let i = 0; i < bk.length; ++i)
                merged[bk[i]] = base[bk[i]];
            m.okButtonProps = merged;
        }
        return m;
    }

    function _iconOf(type) {
        switch (type) {
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

    // ---------------------------------------------------------------- 一条调用
    // 一条记录就是「合并完的 config + 卡片」。卡片在退场动画结束时置 null，
    // 之后 destroy / update 都走 `_render` 那道 null 判断什么也不做 —— 官方 close()
    // 重复调用也只是再渲染一次 visible=false。
    function _open(m) {
        const rec = {
            config: m,
            card: null
        };
        control._records = control._records.concat([rec]);
        const card = cardFactory.createObject(control.container, control._propsOf(rec.config));
        rec.card = card;
        // qmllint disable missing-property
        card.hideFinished.connect(function () { control._finish(rec); });
        // qmllint enable missing-property
        return {
            // 官方 destroy 就是 close
            destroy: function () { control._closeRec(rec); },
            update: function (newConfig) { control._updateRec(rec, newConfig); }
        };
    }

    function _closeRec(rec) {
        // 官方 close()：currentConfig.visible = false 再渲染一次
        rec.config.visible = false;
        control._render(rec);
    }

    function _updateRec(rec, newConfig) {
        const raw = (newConfig === undefined || newConfig === null) ? {} : newConfig;
        const keys = Object.keys(raw);
        for (let i = 0; i < keys.length; ++i)
            rec.config[keys[i]] = raw[keys[i]];
        control._render(rec);
    }

    function _render(rec) {
        if (rec.card === null)
            return;
        const p = control._propsOf(rec.config);
        const pk = Object.keys(p);
        for (let i = 0; i < pk.length; ++i)
            rec.card[pk[i]] = p[pk[i]];
    }

    // config 里出现**且不是 undefined** 的 key 才写进卡片（值是 undefined 的那支留着卡片上一次的取值）。
    // 官方那条 `{...currentConfig, ...newConfig}` 摊开之后交给 React 受控属性，显式给 undefined
    // 等于回到组件默认值；端口没有 defaultProps 那一层，只能保留旧值 —— 这条差异按实测留在这。
    function _propsOf(m) {
        const p = {};
        // type 决定图标与图标色（ModalConfirm 自己按 confirmType 取）
        if (m.type !== undefined)
            p.confirmType = String(m.type);
        // 官方 with* 塞的默认图标：字符串档走 iconName，Component 档走 iconComponent
        if (m.iconName !== undefined)
            p.iconName = String(m.iconName);
        if (m.icon !== undefined) {
            if (typeof m.icon === "string")
                p.iconName = m.icon;
            else
                p.iconComponent = m.icon;
        }
        if (m.content !== undefined) {
            if (typeof m.content === "string" || typeof m.content === "number")
                p.contentText = String(m.content);
            else
                p.contentComponent = m.content;
        }
        if (m.onOk !== undefined)
            p.okCallback = m.onOk;
        if (m.onCancel !== undefined)
            p.cancelCallback = m.onCancel;
        if (m.afterClose !== undefined)
            p.afterCloseCallback = m.afterClose;
        // 其余就是 ModalProps 本体，名字与官方一一对应
        const passthrough = ["title", "header", "footer", "closeIcon", "okText", "cancelText",
            "okType", "hasCancel", "closable", "mask", "maskClosable", "closeOnEsc", "centered",
            "motion", "fullScreen", "footerFill", "size", "zIndex", "confirmLoading",
            "cancelLoading", "okButtonProps", "cancelButtonProps", "bodyStyle", "modalRender",
            "className", "modalContentClass", "direction", "preventScroll", "iconColor",
            "width", "height"];
        for (let i = 0; i < passthrough.length; ++i) {
            const k = passthrough[i];
            if (m[k] !== undefined)
                p[k] = m[k];
        }
        // 官方 visible 是 ConfirmModal 自己的 state；close() 之后才由 rest 传进去盖掉它
        if (m.visible !== undefined)
            p.shown = Boolean(m.visible);
        return p;
    }

    // 退场动画结束：把卡片从名单里摘掉并毁掉。afterClose 只跑一次的闸门在 ModalConfirm
    // 自己身上 —— Popup 一次开层只发一次 closed。
    function _finish(rec) {
        const card = rec.card;
        rec.card = null;
        control._records = control._records.filter(function (r) { return r !== rec; });
        if (card !== null)
            card.destroy();
    }
}
