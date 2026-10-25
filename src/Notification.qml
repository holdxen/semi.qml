pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as C
import QtQuick.Window

// Notification 通知 —— 宿主 + 命令式 API。
//
// 官方 Notification 和 Toast 一样不是「摆在那里 open() 一下」的控件，而是一组静态方法
// （semi-ui/notification/index.tsx:101-218）：
//
//     Notification.open({ title: "Hi", content: "ies dance", duration: 3 })   // 返回 id
//     Notification.info(...)  .success(...)  .warning(...)  .error(...)
//     Notification.close(id)  Notification.destroyAll()  Notification.config({...})
//     const [notification, contextHolder] = Notification.useNotification()
//
// QML 的 type 上没有静态方法，所以整套 API 落在组件实例上：一个 Notification {} 就是
// 「容器 + API」那一对，正好对应 useNotification() 返回的 [notification, contextHolder]。
// 标题/正文传 Component 时读的是它定义处那份作用域（Loader 用 Component 自己的上下文实例化），
// 这就是官方说的「得到 contextHolder 所在位置的所有上下文」。
//
// 层级对应官方：
//   Notification（本文件）  = .semi-notification-wrapper + NotificationList（state.notices 那一层）
//   listTop / listTopLeft / … = .semi-notification-list（每个位置一条，[placement=…]）
//   NotificationItem        = .semi-notification-notice（盒子本身，不含 20px 外边距）
//
// 与官方对齐的语义（notificationListFoundation.ts + notificationFoundation.ts）：
//   · duration 单位是**秒**（foundation 里才 * 1000），0 或非数字不自动关闭；
//   · 悬停 clearCloseTimer / 离开 startCloseTimer —— 离开后**重新计满整个 duration**；
//   · 按 id 更新是浅合并 {...notice, ...noticeOpts} + restartCloseTimer。**关键在于
//     noticeOpts 里出现过的 key 才参与覆盖**：index.tsx:145-184 那五个方法先把入参垫上
//     defaultConfig 的 duration/position/motion/title/content/zIndex 六档，所以这六档每次都会被
//     重写（没写 title 就是抹成空串），而 theme/icon/showClose/top/… 只有调用方给了才出现，
//     没给就保留原来那条的值；type 更狠 —— 它排在 ...opts 之后，info()/success() 会把入参里的
//     type 顶掉，open() 则一律钉成 default；
//   · addNotice 是 **prepend**（最新那条排在列表最前），官方 bottom 位置因此是
//     「新的往上长、旧的贴底边」；
//   · 正在退场那条挪到渲染末尾（[...notices, ...removedItems]）；
//   · has(id) 只看还在位的那些；
//   · close(id) 只把卡片摘掉，**不跑**那条自己的 onClose（官方 removeNotice 不通知 item）；
//     计时到点与按 × 走的是 item 自己的 foundation.close()，那两条会跑 onClose；
//   · destroyAll() 把全部塞进 removedItems —— 所以**会**播退场动画（这点和 Toast 相反），
//     但同样不跑 onClose。
//
// 有意的差异（逐条对）：
//   · top/left/right/bottom 不能做成元素属性：Item 上这四个名字是 FINAL 的锚点线
//     （qquickitem.h:90-94），只从 config({...}) 与调用入参进；
//   · getPopupContainer 官方只在创建 wrapper 那一次读，这里每次重算（容器换了就跟着换）；
//   · title / content / icon 官方是 ReactNode，这里字符串或 Component 两支；
//     icon 只收图标名，所以官方示例里那种「给图标单独染个色」做不到，图标色一律跟着 type；
//   · 关闭按钮的字形：官方 IconButton 是 24×24、内边距 4、字形 16，本端口的 IconButton
//     一律取控件高度的一半（字形 12）—— 那是全库共用的约定，改它会波及别处，这里只记录；
//   · style / className / direction（RTL）不收：本端口没有 DOM 样式，整个库也还没做 RTL；
//   · 官方 position 给了非法值会在 noticesInPosition[position].push 处直接抛异常，
//     这里退化成容器默认位置；
//   · has(id) / update(id, opts) 是把官方那条隐藏分支显式化的便利方法：官方静态面只有
//     addNotice / removeNotice / info / success / error / warning / open / close / destroyAll /
//     config（index.tsx:101-202），「按 id 更新」只能靠再调一次带同 id 的展示方法走到
//     addNotice 里的 has(id) 分支，这两条的语义与那条分支完全一致（见 update 的注释）。
Item {
    id: control

    // ---------------------------------------------------------------- Config
    // 官方 ConfigProps：top / left / right / bottom / duration / position / zIndex
    // 这一层对应 notificationListFoundation 那边被 Notification.config() 改写的 defaultConfig，
    // 是「容器默认值」，调用点入参覆盖它。
    property int zIndex: Theme.current.zNotification      // $z-notification = 1010
    property string position: "topRight"                  // strings.positions 的默认那档
    property real duration: 3                             // 秒；0 = 不自动关闭
    property bool motion: true                            // 官方 defaultConfig.motion

    // 官方只有 config({ top }) 这一种入口，没有元素属性形式：Item 上这四个名字是 FINAL 的锚点线
    // （qquickitem.h:90-94）。这里同样只从 config({...}) 与调用入参进。
    property var _topPos: undefined
    property var _leftPos: undefined
    property var _rightPos: undefined
    property var _bottomPos: undefined

    // 官方 wrapper 的 z-index 是**建 wrapper 那一次**写死的（文档：「首次设置一次生效」），
    // 之后 config({zIndex}) 只改 defaultConfig，改不动已经挂上去的那个 div。
    readonly property bool zIndexLocked: control._zIndexApplied
    property bool _zIndexApplied: false
    property int _appliedZIndex: Theme.current.zNotification

    // 弹层挂在哪个节点。官方只在创建 wrapper 那一次读 getPopupContainer，
    // 这里跟着属性走（容器换了就跟着换）。
    property var getPopupContainer: null

    // 实例记录，最新那条在最前（官方 addNotice 是 prepend）。每条就是官方那条
    // 「合并完的 notice」本身，再挂上端口的调度字段：
    // { …noticeProps, removed, hovered, deadline, card }
    readonly property var items: control._records
    property var _records: []

    readonly property var _positions: ["top", "bottom", "topLeft", "topRight",
        "bottomLeft", "bottomRight"]

    // 官方把 wrapper append 到 document.body；这里默认挂到窗口的 Overlay.overlay。
    // 宿主自己不绑 parent：Item 在 QML 侧没有 window 属性，parent 绑到 Overlay.overlay 会在
    // 还没进场景时一次求值成 null 且永不自愈（坑 83）—— 真正搬出去的是下面那层 wrapper。
    readonly property var container: control.getPopupContainer
        ? control.getPopupContainer()
        : (Window.window ? C.Overlay.overlay : control)

    width: 0
    height: 0

    // .semi-notification-wrapper：position fixed，本身没有尺寸；六个位置各一条固定列表
    // （官方一个位置一条 .semi-notification-list[placement=…]，六条同时存在、空的没内容）
    Item {
        id: wrapper

        objectName: "noticeWrapper"
        parent: control.container
        z: control._appliedZIndex
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0

        // 官方那条列表是 shrink-to-fit，宽度跟着视口走；这里容器换了尺寸就重排一次
        onWidthChanged: control._relayout()
        onHeightChanged: control._relayout()

        property var slots: [listTop, listBottom, listTopLeft, listTopRight,
            listBottomLeft, listBottomRight]

        Item {
            id: listTop

            property string slotName: "top"

            objectName: "noticeList_top"
            width: 0
            height: 0
        }

        Item {
            id: listBottom

            property string slotName: "bottom"

            objectName: "noticeList_bottom"
            width: 0
            height: 0
        }

        Item {
            id: listTopLeft

            property string slotName: "topLeft"

            objectName: "noticeList_topLeft"
            width: 0
            height: 0
        }

        Item {
            id: listTopRight

            property string slotName: "topRight"

            objectName: "noticeList_topRight"
            width: 0
            height: 0
        }

        Item {
            id: listBottomLeft

            property string slotName: "bottomLeft"

            objectName: "noticeList_bottomLeft"
            width: 0
            height: 0
        }

        Item {
            id: listBottomRight

            property string slotName: "bottomRight"

            objectName: "noticeList_bottomRight"
            width: 0
            height: 0
        }
    }

    Component {
        id: cardFactory

        NotificationItem {}
    }

    Timer {
        id: tickTimer

        onTriggered: control._onTick()
    }

    // ---------------------------------------------------------------- API
    // 官方 ConfigProps 只有 top / left / right / bottom / duration / position / zIndex（+ direction）。
    // 注意和 Toast 不一样：Notification.config() 里没有 getPopupContainer，那个量只挂在单条通知上
    // （NoticeProps），而且只在第一次建 wrapper 时读一次。
    function config(opts) {
        if (opts === undefined || opts === null)
            return
        const keys = ["top", "left", "right", "bottom"]
        for (let i = 0; i < keys.length; ++i) {
            // 官方只看 key 在不在（`pos in opts`）
            if (keys[i] in opts)
                control._setPosition(keys[i], opts[keys[i]])
        }
        if (typeof opts.zIndex === "number")
            control.zIndex = Math.round(opts.zIndex)
        if (typeof opts.duration === "number")
            control.duration = opts.duration
        if (typeof opts.position === "string" && control._positions.indexOf(opts.position) >= 0)
            control.position = opts.position
    }

    // 官方五个静态展示方法：都只收 options 对象（没有 Toast 那种字符串简写），返回 id
    function info(opts) { return control._add2(opts, "info") }
    function success(opts) { return control._add2(opts, "success") }
    function warning(opts) { return control._add2(opts, "warning") }
    function error(opts) { return control._add2(opts, "error") }
    function open(opts) { return control._add2(opts, "default") }

    function close(id) {
        // 官方 removeNotice 只把这条从列表里摘掉，不会跑它自己的 onClose
        control._close(String(id), false)
    }

    function destroyAll() {
        // 官方 foundation.destroyAll = updateNotices([], notices)，且 notices.length 为空时直接返回
        const list = control._records
        const live = list.filter(function (r) { return !r.removed })
        if (live.length === 0)
            return
        // removedItems 被**整份换成**「还在位的那些」，于是一边正在退场的那几张立刻从渲染列表里
        // 消失（动画不播完）—— 这点和 Toast 相反，Toast 的 destroyAll 走的是逐条 close。
        const dying = list.filter(function (r) { return r.removed })
        for (let i = 0; i < dying.length; ++i) {
            const deadCard = dying[i].card
            dying[i].card = null
            if (deadCard !== null)
                deadCard.destroy()
        }
        for (let i = 0; i < live.length; ++i) {
            live[i].removed = true
            live[i].deadline = Number.POSITIVE_INFINITY
            live[i].card.removed = true
        }
        control._records = live
        control._relayout()
        control._arm()
    }

    function has(id) {
        return control._find(String(id)) !== null
    }

    // 官方 NotificationList.update 只能被 addNotice 走到（文档 API 表里没有它），
    // 那里传进去的 noticeOpts 已经是补全过的 notice。所以这里也按那份补全结果去浅合并，
    // 于是行为和「用同一个 id 再 open 一次」一致：没写的字段沿用 defaultConfig（会被抹成默认值），
    // defaultConfig 里没有的字段（theme/icon/showClose/onClose…）没写就保留原值。
    function update(id, opts) {
        const rec = control._find(String(id))
        if (rec === null)
            return false
        control._applyToRecord(rec, control._normalize(opts, ""))
        return true
    }

    // ---------------------------------------------------------------- 内部
    function _add2(opts, presetType) {
        const m = control._normalize(opts, presetType)
        // 官方 wrapper 的 z-index 是创建那一次写死的（文档：「首次设置一次生效」），
        // 之后 config({zIndex}) 或调用点再给都改不动它
        if (!control._zIndexApplied) {
            control._zIndexApplied = true
            control._appliedZIndex = control._px(m.zIndex, Theme.current.zNotification)
        }
        if (control.has(m.id))
            control._applyToRecord(control._find(m.id), m)
        else
            control._add(m)
        return m.id
    }

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

    // 官方 getUuid('notification') => `notification-<毫秒>-<随机>`
    function _nextId() {
        return "notification-" + Date.now() + "-" + Math.random()
    }

    // 官方在静态方法里先拼 {...defaultConfig, ...globalConfig, ...opts, type: '…'}，
    // addNotice 里再拼一次（幂等）。defaultConfig 的六档（duration / position / motion /
    // content / title / zIndex）加上 config() 设过的位置量**永远在场**，其余 key 只在调用方
    // 给了才在场。更新走 {...notice, ...noticeOpts} ⇒「没给的 key 保留原值」是官方语义，
    // 所以必须先确定哪些 key 在场，不能拿一份全默认的副本去整覆盖。
    function _normalize(opts, presetType) {
        const raw = (opts === undefined || opts === null) ? {} : opts
        control._applyContainerConfig(raw)
        const m = {
            duration: control.duration,
            position: control.position,
            motion: control.motion,
            title: "",
            content: "",
            zIndex: control.zIndex
        }
        // 这四档只有 config() 设过之后才进 defaultConfig
        if (control._topPos !== undefined)
            m.top = control._topPos
        if (control._leftPos !== undefined)
            m.left = control._leftPos
        if (control._rightPos !== undefined)
            m.right = control._rightPos
        if (control._bottomPos !== undefined)
            m.bottom = control._bottomPos
        const keys = Object.keys(raw)
        for (let i = 0; i < keys.length; ++i)
            m[keys[i]] = raw[keys[i]]
        // 官方把 type 排在 ...opts **之后**：info/success/warning/error 一律钉死自己的 type，
        // open 钉成 default。只有内部 update（presetType 传空）才让调用方的 type 生效。
        if (presetType !== "")
            m.type = presetType
        if (m.id === undefined || m.id === null)
            m.id = control._nextId()
        else
            m.id = String(m.id)
        // 官方在这里不校验 position，非法值会在 noticesInPosition[position].push 直接抛异常；
        // 端口退化成默认那档（见文件头的差异清单）
        if (control._positions.indexOf(m.position) < 0)
            m.position = "topRight"
        return m
    }

    // 官方 addNotice 只在**建 wrapper 那一次**读 getPopupContainer。
    // 注意 top/left/right/bottom 不在这里吸收：调用点给的量只属于那一条 notice
    // （setPosInStyle 读的是当前该位置第一条），能写进 defaultConfig 的只有 config()。
    function _applyContainerConfig(raw) {
        if (typeof raw.getPopupContainer === "function" && control.getPopupContainer === null)
            control.getPopupContainer = raw.getPopupContainer
    }

    function _nodeProp(value) {
        // 官方 title / content 是 ReactNode：字符串（或数字）走文本那一支，其余按 Component
        const plain = typeof value === "string" || typeof value === "number"
        return {
            text: plain ? String(value) : "",
            component: plain || value === undefined || value === null ? null : value
        }
    }

    // 官方 addNotice(opts)：那条记录就是合并完的 notice 本身（state.notices 里存的
    // 正是 {...defaultConfig, ...globalConfig, ...opts, type, id}），端口只额外挂调度字段。
    function _add(m) {
        m.removed = false
        m.hovered = false
        m.deadline = Number.POSITIVE_INFINITY
        m.card = null
        // 官方是 updateNotices([opts, ...notices]) ⇒ 最新那条在最前
        control._records = [m].concat(control._records)
        const card = cardFactory.createObject(control._listItem(m.position), control._cardProps(m))
        m.card = card
        // qmllint disable missing-property
        card.requestClose.connect(function (id) { control._closeById(id) })
        card.pointerHovered.connect(function (hovering) { control._onHover(m, hovering) })
        card.cardClicked.connect(function () { control._onClick(m) })
        card.hideFinished.connect(function () { control._dispose(m.id) })
        card.layoutDirty.connect(function () { control._relayout() })
        // qmllint enable missing-property
        control._scheduleAutoClose(m)
        control._relayout()
        control._arm()
    }

    function _cardProps(rec) {
        // 卡片那几个属性带类型，收不了 undefined：官方那边由 React 的
        // defaultProps（theme 'normal'、showClose true、content/title ''）和 iconMap 兜底
        const t = control._nodeProp(rec.title)
        const c = control._nodeProp(rec.content)
        return {
            noticeId: rec.id,
            type: rec.type === undefined ? "default" : String(rec.type),
            theme: rec.theme === undefined ? "normal" : String(rec.theme),
            titleText: t.text,
            titleComponent: t.component,
            contentText: c.text,
            contentComponent: c.component,
            icon: rec.icon === undefined ? "" : String(rec.icon),
            showClose: rec.showClose === undefined ? true : Boolean(rec.showClose),
            position: rec.position,
            motion: rec.motion === undefined ? true : Boolean(rec.motion)
        }
    }

    // 官方 foundation.update：{ ...notice, ...noticeOpts }，随后 refFn 里 restartCloseTimer。
    // 只有 noticeOpts 里**出现过**的 key 才覆盖，其余保留原值。
    function _applyToRecord(rec, m) {
        const before = rec.position
        const keys = Object.keys(m)
        for (let i = 0; i < keys.length; ++i)
            rec[keys[i]] = m[keys[i]]
        const card = rec.card
        const p = control._cardProps(rec)
        card.noticeId = p.noticeId
        card.type = p.type
        card.theme = p.theme
        card.titleText = p.titleText
        card.titleComponent = p.titleComponent
        card.contentText = p.contentText
        card.contentComponent = p.contentComponent
        card.icon = p.icon
        card.showClose = p.showClose
        card.motion = p.motion
        if (before !== rec.position) {
            // 换了位置就搬到那条列表里去（官方是按 position 分组渲染的）
            card.parent = control._listItem(rec.position)
            card.position = rec.position
        }
        control._scheduleAutoClose(rec)
        control._arm()
        control._relayout()
    }

    function _listItem(position) {
        const all = wrapper.slots
        for (let i = 0; i < all.length; ++i) {
            if (all[i].slotName === position)
                return all[i]
        }
        return wrapper
    }

    function _find(id) {
        const list = control._records
        for (let i = 0; i < list.length; ++i) {
            // 只认还在位的：官方 has() 读的是 state.notices，正在退场的那条不算
            if (!list[i].removed && list[i].id === id)
                return list[i]
        }
        return null
    }

    // × 按下：官方先 onCloseClick(id)，再 foundation.close()（那条会跑 onClose）
    function _closeById(id) {
        const rec = control._find(String(id))
        if (rec !== null && typeof rec.onCloseClick === "function")
            rec.onCloseClick(rec.id)
        control._close(String(id), true)
    }

    function _onClick(rec) {
        if (typeof rec.onClick === "function")
            rec.onClick()
    }

    // 计时到点与按 × 都走这条路：官方 item 自己的 close() 会通知移除 + 跑 onClose
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
        if (notify && typeof rec.onClose === "function")
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

    function _onHover(rec, hovering) {
        rec.hovered = hovering
        // 官方：进 → _clearCloseTimer，出 → _startCloseTimer（重新计满整个 duration）
        control._scheduleAutoClose(rec)
        control._arm()
    }

    // 一条 Timer 盯所有到点时间；重新装填按绝对时间重算，不会累积误差
    function _arm() {
        const list = control._records
        let next = Number.POSITIVE_INFINITY
        for (let i = 0; i < list.length; ++i) {
            if (list[i].removed)
                continue
            if (list[i].deadline < next)
                next = list[i].deadline
        }
        const now = Date.now()
        if (next === Number.POSITIVE_INFINITY) {
            tickTimer.stop()
            return
        }
        tickTimer.interval = Math.max(0, Math.round(next - now))
        tickTimer.restart()
    }

    function _onTick() {
        const list = control._records
        const now = Date.now()
        for (let i = 0; i < list.length; ++i) {
            const rec = list[i]
            if (!rec.removed && rec.deadline <= now)
                control._close(rec.id, true)
        }
        control._arm()
    }

    // 官方一条 .semi-notification-list：margin/padding 都是 0，卡片自己带 20px 外边距。
    // 于是列表盒子 = 卡片宽 + 左右各 20、高 = 各卡高之和 + 首尾各 20（相邻 margin 折叠成 20），
    // 而 placement 钉的是**列表盒子**的那两条边 ⇒ 右上角那张卡片的右边缘落在窗口右缘再往里 20，
    // 左上角的左边缘在 20（浏览器实测：list x=49.27 / card x=69.27，视口 705）。
    // 列表宽度是 shrink-to-fit：取最宽那张的 max-content，封顶到可用宽减去左右 20，但不小于 min-width。
    function _relayout() {
        const list = control._records
        const avail = control.container ? control.container.width : 0
        const availH = control.container ? control.container.height : 0
        const margin = Theme.current.spacingBaseLoose
        const all = wrapper.slots
        for (let p = 0; p < all.length; ++p) {
            const slot = all[p]
            const mine = list.filter(function (r) { return r.position === slot.slotName })
            let natural = 0
            let floor = 0
            for (let i = 0; i < mine.length; ++i) {
                natural = Math.max(natural, mine[i].card.naturalWidth)
                floor = Math.max(floor, mine[i].card.minBoxWidth)
            }
            const width = mine.length ? Math.max(floor, Math.min(natural, avail - margin * 2)) : 0
            let y = margin
            for (let i = 0; i < mine.length; ++i) {
                const card = mine[i].card
                card.width = width
                card.x = margin
                card.y = y
                y += card.implicitHeight + margin
            }
            slot.width = mine.length ? width + margin * 2 : 0
            slot.height = mine.length ? y : 0
            control._placeList(slot, mine, avail, availH)
        }
    }

    // placement 那六条规则 + 官方 setPosInStyle（用该位置**第一条**卡片带的位置量覆盖）
    function _placeList(slot, mine, availW, availH) {
        const first = mine.length ? mine[0] : null
        const top = first ? control._px(first.top, 0) : 0
        const left = first ? control._px(first.left, 0) : 0
        const right = first ? control._px(first.right, 0) : 0
        const bottom = first ? control._px(first.bottom, 0) : 0
        const h = slot.height
        if (slot.slotName === "top" || slot.slotName === "bottom")
            slot.x = Math.round((availW - slot.width) / 2)     // left: 50% + translateX(-50%)
        else if (slot.slotName === "topLeft" || slot.slotName === "bottomLeft")
            slot.x = left
        else
            slot.x = Math.max(0, availW - slot.width - right)
        if (slot.slotName === "bottom" || slot.slotName === "bottomLeft"
            || slot.slotName === "bottomRight")
            slot.y = Math.max(0, availH - h - bottom)
        else
            slot.y = top
    }
}
