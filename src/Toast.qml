pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as C
import QtQuick.Window

// Toast 轻提示 —— 宿主 + 命令式 API。
//
// 官方 Toast 不是「摆在那里、open() 一下」的控件，而是一组静态方法：
//
//     Toast.info({ content: "已保存", duration: 3, stack: true })   // 返回 id
//     Toast.close(id)  Toast.destroyAll()  Toast.config({ theme: "light" })
//     const [toast, contextHolder] = Toast.useToast()
//     ToastFactory.create(config) => 另一份带自己 config 的 Toast
//
// QML 里 type 上没有静态方法，所以整个 API 落在组件实例上：一个 Toast {} 就是
// 「容器 + API」这一对，正好对应官方 useToast() 返回的 [toast, contextHolder] ——
// 卡片渲染在实例 parent 所在的那一层，content 传 Component 时读的是它定义处那份作用域
// （Loader 用 Component 自己的上下文实例化，这就是官方说的「消费 context」）。
//
//     Toast { id: toast }
//     toast.info("已保存")
//     toast.success({ content: "部署完成", duration: 0, showClose: true })
//     toast.close(id)
//
// 层级对应官方：
//   Toast（本文件） = .semi-toast-wrapper（fixed、height 0、宽 100%、水平居中、z-index 1010）
//                     + ToastList（state.list / removedItems 那一层）
//   band            = .semi-toast-innerWrapper（fit-content + text-align: center）
//   ToastItem       = .semi-toast（带 12px margin 的盒子）与 .semi-toast-content
//
// duration 单位是「秒」（constants.ts 的 numbers.duration = 3 即 3s），不是毫秒；
// 0 或非数字则不自动关闭 —— 抄 toastFoundation.startCloseTimer_ 的 `if (duration && isNumber)`。
//
// 计时集中在宿主：一条 Timer 管所有卡片，每张卡片只存一个绝对到点时间 deadline。
// 这样做的原因是官方也是把 duration 放在 foundation 层，而卡片是可以被 update(id)
// 原地换内容的 —— 计时跟着记录走，换内容才不会把已经跑了一半的计时打乱。
Item {
    id: control

    // ---------------------------------------------------------------- Config
    // 官方 ConfigProps：top/left/right/bottom/zIndex/theme/duration/getPopupContainer。
    // 前四个在 QML 里不能写成组件属性 —— Item 的 top/left/right/bottom 是 FINAL 的锚点线，
    // 名字被占了（qquickitem.h:90-94）。官方本来也是静态 API、没有元素属性写法，
    // 所以这四个只从 config({...}) 与调用时的 opts 进来，值存在下面的内部量里。
    property var _topPos: 0
    property var _leftPos: undefined
    property var _rightPos: undefined
    property var _bottomPos: undefined
    property int zIndex: Theme.current.zToast       // $z-toast = 1010
    property string theme: "normal"                 // normal | light
    property real duration: 3                       // 秒；0 = 不自动关闭
    property bool motion: true                      // 官方 defaultOpts.motion
    property bool stack: false                      // 官方 instance.stack：整叠共用，最后一次调用赢
    property bool stackExpanded: false              // state.mouseInSide

    // 渲染顺序的实例记录：在位的那些 + 正在退场的（退场的挪到末尾，同官方
    // Array.from(new Set([...list, ...removedItems]))）。每条是
    // { id, type, theme, content, icon, showClose, textMaxWidth, duration, motion,
    //   onClose, removed, hovered, deadline, card }
    readonly property var items: control._records
    property var _records: []

    readonly property var _themes: ["normal", "light"]     // constants.ts strings.themes

    // 官方 ConfigProps.getPopupContainer：这一层挂到哪个容器。默认窗口的 Overlay.overlay，
    // 对应官方把 wrapper append 到 document.body；用 config({...}) 或调用时的 opts 换容器
    // （ToastFactory.create({getPopupContainer}) 那节演示的就是它）。
    property var getPopupContainer: null
    // 宿主自己不绑 parent：Item 在 QML 侧没有 window 属性（qquickitem.h 只有 parent，
    // 而 top/left/right/bottom 是 FINAL 的锚点线），一旦把 parent 绑到 Overlay.overlay，
    // 求值时既拿不到 window 也等不到 windowChanged —— 「页面里声明 Toast {}」会永远停在 null。
    // 真正搬出去的是下面那层 wrapper。
    readonly property var container: control.getPopupContainer
        ? control.getPopupContainer()
        : (Window.window ? C.Overlay.overlay : control)

    width: 0
    height: 0

    // 位置量可以是字符串，官方直接塞给 CSS。这里按数值解析，解析不出就用默认。
    // 官方 .semi-toast-wrapper 写死了 top: 0 与 height: 0，于是 bottom / right 在浏览器里
    // 属于「过约束被丢掉」的那两个。本端口让它们真的能用：显式把 top 置 undefined 就让位给
    // bottom，left/right 同时给则收窄这条横带（差异记在 PROGRESS.md）。
    readonly property real _leftPx: control._px(control._leftPos, 0)
    readonly property real _rightPx: control._px(control._rightPos, 0)
    readonly property real _topPx: control._topPos === undefined && control._bottomPos !== undefined
        ? Math.max(0, (control.container ? control.container.height : 0) - control._px(control._bottomPos, 0))
        : control._px(control._topPos, 0)

    // .semi-toast-wrapper：position fixed、height 0、width 100%、flex 水平居中、z-index
    Item {
        id: wrapper

        objectName: "toastWrapper"
        parent: control.container
        z: control.zIndex
        width: Math.max(0, (parent ? parent.width : 0) - control._leftPx - control._rightPx)
        height: 0
        x: control._leftPx
        y: control._topPx

        // .semi-toast-innerWrapper：fit-content + text-align center
        Item {
            id: band

            objectName: "toastBand"
            x: Math.round((wrapper.width - width) / 2)     // justify-content: center
            y: 0
            width: 0
            height: 0

            // 展开/收起的开关挂在「整叠区域」上，不是挂在单张卡片上。官方是 innerWrapper 的
            // mouseenter/leave，而它那些 zero-height-wrapper 在展开时高度 = 卡片高，把卡片之间
            // 那 24px margin 连成了一整片可命中区域 —— 指针落在缝里不算离开。
            // 只用「任一卡片被悬停」当条件时：指针停在缝隙里 → 没有卡片被悬停 → 收起 →
            // 卡片又叠回指针底下 → 悬停 → 展开，位置来回抽搐。
            HoverHandler {
                id: pileHover

                onHoveredChanged: {
                    if (!pileHover.hovered)
                        control._onPileLeave()
                }
            }
        }
    }

    Component {
        id: cardFactory

        ToastItem {}
    }

    Timer {
        id: tickTimer

        onTriggered: control._onTick()
    }

    // ---------------------------------------------------------------- API
    function config(opts) {
        if (opts === undefined || opts === null)
            return
        const keys = ["top", "left", "right", "bottom"]
        for (let i = 0; i < keys.length; ++i) {
            // 官方只看 key 在不在（`pos in opts`），值原样交给样式
            if (keys[i] in opts)
                control._setPosition(keys[i], opts[keys[i]])
        }
        if (typeof opts.theme === "string" && control._themes.indexOf(opts.theme) >= 0)
            control.theme = opts.theme
        if (typeof opts.zIndex === "number")
            control.zIndex = Math.round(opts.zIndex)
        if (typeof opts.duration === "number")
            control.duration = opts.duration
        if (typeof opts.getPopupContainer === "function")
            control.getPopupContainer = opts.getPopupContainer
    }

    // 官方静态方法：字符串或选项对象都收，返回 id
    function info(opts) { return control._open(opts, "info") }
    function success(opts) { return control._open(opts, "success") }
    function warning(opts) { return control._open(opts, "warning") }
    function error(opts) { return control._open(opts, "error") }
    // useToast() 的 api.open 把 type 定为 default（没有图标、也用不上 light 底色）
    function open(opts) { return control._open(opts, "default") }
    // 官方 ToastList.create(opts)：不预设 type，opts.type 给了就用
    function create(opts) { return control._open(opts, "") }

    function close(id) {
        // 注意：官方 Toast.close(id) 只把卡片摘掉，不会跑那条 toast 自己的 onClose
        control._close(String(id), false)
    }

    function destroyAll() {
        // 官方直接把 wrapper 卸载：没有退场动画、也不跑 onClose
        const list = control._records
        control._records = []
        for (let i = 0; i < list.length; ++i) {
            const card = list[i].card
            list[i].card = null
            if (card !== null)
                card.destroy()
        }
        control.stackExpanded = false
        control._relayout()
        control._arm()
    }

    function has(id) {
        return control._find(String(id)) !== null
    }

    function update(id, opts) {
        const rec = control._find(String(id))
        if (rec === null)
            return false
        control._applyToRecord(rec, control._normalize(opts, ""))
        control._syncStack()
        return true
    }

    // ---------------------------------------------------------------- 内部
    function _setPosition(key, value) {
        if (key === "top")
            control._topPos = value
        else if (key === "left")
            control._leftPos = value
        else if (key === "right")
            control._rightPos = value
        else
            control._bottomPos = value
    }

    function _px(value, fallback) {
        if (value === undefined || value === null)
            return fallback
        if (typeof value === "number")
            return value
        const n = parseFloat(value)
        return Number.isNaN(n) ? fallback : n
    }

    // 官方 getUuid('toast') => `toast-<毫秒>-<随机>`
    function _nextId() {
        return "toast-" + Date.now() + "-" + Math.random()
    }

    function _normalize(opts, presetType) {
        const raw = (typeof opts === "string" || typeof opts === "number")
            ? { content: String(opts) }
            : (opts === undefined || opts === null ? {} : opts)
        control._applyContainerConfig(raw)
        // type 为 null 表示「这次没提」（官方 mergedOpts 里没有 type 这个 key，
        // 于是 update 时沿用原来那条的 type —— 官方文档的 id 更新示例靠它保持 info→success 的差别）
        let type = null
        if (presetType !== "")
            type = presetType
        else if (raw.type !== undefined)
            type = String(raw.type)
        return {
            id: raw.id !== undefined ? String(raw.id) : control._nextId(),
            type: type,
            theme: control._themes.indexOf(raw.theme) >= 0 ? raw.theme : control.theme,
            content: raw.content !== undefined ? raw.content : "",
            icon: raw.icon !== undefined ? String(raw.icon) : "",
            showClose: raw.showClose === undefined ? true : Boolean(raw.showClose),
            textMaxWidth: raw.textMaxWidth === undefined ? 450 : Number(raw.textMaxWidth),
            duration: raw.duration === undefined ? control.duration : Number(raw.duration),
            stack: raw.stack === undefined ? control.stack : Boolean(raw.stack),
            motion: raw.motion === undefined ? control.motion : Boolean(raw.motion),
            onClose: typeof raw.onClose === "function" ? raw.onClose : undefined
        }
    }

    // 官方每次 create 都会把这一趟带的位置量重刷到 wrapper 上，并同步 stack
    function _applyContainerConfig(raw) {
        const keys = ["top", "left", "right", "bottom"]
        for (let i = 0; i < keys.length; ++i) {
            if (keys[i] in raw)
                control._setPosition(keys[i], raw[keys[i]])
        }
        if (typeof raw.zIndex === "number")
            control.zIndex = Math.round(raw.zIndex)
        if (typeof raw.getPopupContainer === "function")
            control.getPopupContainer = raw.getPopupContainer
        if (raw.stack !== undefined)
            control.stack = Boolean(raw.stack)
    }

    function _open(opts, presetType) {
        const m = control._normalize(opts, presetType)
        if (control.has(m.id))
            control._applyToRecord(control._find(m.id), m)
        else
            control._add(m)
        control._syncStack()
        return m.id
    }

    function _add(m) {
        const rec = {
            id: m.id,
            type: m.type === null ? "default" : m.type,
            theme: m.theme,
            content: m.content,
            icon: m.icon,
            showClose: m.showClose,
            textMaxWidth: m.textMaxWidth,
            duration: m.duration,
            motion: m.motion,
            onClose: m.onClose === undefined ? null : m.onClose,
            removed: false,
            hovered: false,
            deadline: Number.POSITIVE_INFINITY,
            card: null
        }
        const card = cardFactory.createObject(band, control._cardProps(rec))
        rec.card = card
        // qmllint disable missing-property
        card.requestClose.connect(function (id) { control._close(id, true) })
        card.pointerHovered.connect(function (hovering) { control._onHover(rec, hovering) })
        card.hideFinished.connect(function () { control._dispose(rec.id) })
        card.layoutDirty.connect(function () { control._relayout() })
        // qmllint enable missing-property
        control._records = control._records.concat([rec])
        control._scheduleAutoClose(rec)
        control._relayout()
        control._arm()
    }

    function _cardProps(rec) {
        // content 是 Component 走富文本那一支，其余按字符串渲染（官方是 ReactNode）
        const rich = (rec.content !== undefined && rec.content !== null
            && typeof rec.content !== "string" && typeof rec.content !== "number")
            ? rec.content : null
        return {
            toastId: rec.id,
            type: rec.type,
            theme: rec.theme,
            contentText: rich === null
                ? (rec.content === undefined || rec.content === null ? "" : String(rec.content)) : "",
            contentComponent: rich,
            icon: rec.icon,
            showClose: rec.showClose,
            textMaxWidth: rec.textMaxWidth,
            motion: rec.motion,
            stack: control.stack
        }
    }

    // 官方 updateToast：{ ...toast, ...toastOpts }，随后 restartCloseTimer
    function _applyToRecord(rec, m) {
        if (m.type !== null)
            rec.type = m.type
        rec.theme = m.theme
        rec.content = m.content
        rec.icon = m.icon
        rec.showClose = m.showClose
        rec.textMaxWidth = m.textMaxWidth
        rec.duration = m.duration
        rec.motion = m.motion
        if (m.onClose !== undefined)
            rec.onClose = m.onClose
        const p = control._cardProps(rec)
        const card = rec.card
        card.type = p.type
        card.theme = p.theme
        card.contentText = p.contentText
        card.contentComponent = p.contentComponent
        card.icon = p.icon
        card.showClose = p.showClose
        card.textMaxWidth = p.textMaxWidth
        card.motion = p.motion
        control._scheduleAutoClose(rec)
        control._arm()
        control._relayout()
    }

    function _find(id) {
        const list = control._records
        for (let i = 0; i < list.length; ++i) {
            // 只认还在位的：官方 hasToast 读的是 state.list，正在退场的那条不算
            if (!list[i].removed && list[i].id === id)
                return list[i]
        }
        return null
    }

    // 定时器到点与 × 按下走这条路，官方 foundation.close() 会同时通知移除与回调 onClose
    function _close(id, notify) {
        const rec = control._find(id)
        if (rec === null)
            return
        rec.removed = true
        rec.deadline = Number.POSITIVE_INFINITY
        control._records = control._records.filter(function (r) { return r !== rec }).concat([rec])
        rec.card.removed = true
        control._relayout()
        control._arm()
        if (notify && rec.onClose !== null)
            rec.onClose()
    }

    function _dispose(id) {
        const list = control._records
        let rec = null
        for (let i = 0; i < list.length; ++i) {
            if (list[i].id === id && list[i].removed)
                rec = list[i]
        }
        if (rec === null)
            return
        const card = rec.card
        rec.card = null
        control._records = control._records.filter(function (r) { return r !== rec })
        if (card !== null) {
            // 这条是从卡片自己的退场动画结束里发出来的，销毁往后推一拍，
            // 免得在信号发送过程中把发送者删掉
            Qt.callLater(function () { card.destroy() })
        }
        control._relayout()
        control._arm()
    }

    function _scheduleAutoClose(rec) {
        if (rec.hovered || !rec.duration || typeof rec.duration !== "number")
            rec.deadline = Number.POSITIVE_INFINITY
        else
            rec.deadline = Date.now() + rec.duration * 1000
    }

    // 一条 Timer 盯所有到点时间；重新装填时按绝对时间重算，不会累积误差
    function _arm() {
        const list = control._records
        let next = Number.POSITIVE_INFINITY
        for (let i = 0; i < list.length; ++i) {
            if (list[i].removed)
                continue
            if (list[i].deadline < next)
                next = list[i].deadline
        }
        if (next === Number.POSITIVE_INFINITY) {
            tickTimer.stop()
            return
        }
        tickTimer.interval = Math.max(1, Math.round(next - Date.now()))
        tickTimer.restart()
    }

    function _onTick() {
        const now = Date.now()
        const list = control._records.slice()
        for (let i = 0; i < list.length; ++i) {
            const rec = list[i]
            if (!rec.removed && rec.deadline <= now)
                control._close(rec.id, true)
        }
        control._arm()
    }

    function _onHover(rec, hovering) {
        rec.hovered = hovering
        // 官方：进 → clearCloseTimer_，出 → startCloseTimer_（重新计满整个 duration）
        control._scheduleAutoClose(rec)
        control._arm()
        if (control.stack && hovering && !control.stackExpanded) {
            // 展开由「悬停到某张卡片」触发；收起只由「离开整叠区域」触发（见 band 上那条 HoverHandler）
            control.stackExpanded = true
            control._syncStack()
        }
    }

    function _onPileLeave() {
        if (!control.stackExpanded)
            return
        control.stackExpanded = false
        control._syncStack()
    }

    function _syncStack() {
        const list = control._records
        for (let i = 0; i < list.length; ++i) {
            list[i].card.stack = control.stack
            list[i].card.stackExpanded = control.stack && control.stackExpanded
        }
        control._relayout()
    }

    function _relayout() {
        const list = control._records
        let boxWidth = 0
        for (let i = 0; i < list.length; ++i)
            boxWidth = Math.max(boxWidth, list[i].card.implicitWidth)
        band.width = boxWidth
        // 外壳高度读卡片上的 flowHeight()（函数，现算），不读绑定属性：_syncStack() 刚把
        // card.stackExpanded 赋完就调到这里，绑定还没重算，读回来是上一轮的值
        // （整叠排不开，band.height 也会跟着错一轮）。
        let y = 0
        let bottom = 0
        for (let i = 0; i < list.length; ++i) {
            const card = list[i].card
            card.z = i                                  // 后面的盖住前面的（官方 DOM 顺序同理）
            card.width = boxWidth
            card.x = 0
            card.y = y
            card.reservedIndex = list.length - 1 - i    // 官方 length - index - 1
            bottom = Math.max(bottom, y + card.implicitHeight)
            y += card.flowHeight()
        }
        // 整叠区域的高度：悬停的「粘滞」判定范围，要含卡片之间那 24px margin
        band.height = control.stack ? Math.max(0, bottom) : 0
    }
}
