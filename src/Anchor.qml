pragma ComponentBehavior: Bound

import QtQuick

// 锚点导航。左侧一条滑轨 + 一列标题，滚动内容时高亮当前所在的那一节，点标题跳过去。
//
//     Flickable {
//         id: view
//         Column {
//             Item { id: sectionA; height: 300 }
//             Item { id: sectionB; height: 300 }
//         }
//     }
//
//     Anchor {
//         container: view
//         AnchorLink { href: "#a"; title: "第一节"; targetItem: sectionA }
//         AnchorLink { href: "#b"; title: "第二节"; targetItem: sectionB }
//     }
//
// 规格照 packages/semi-ui/anchor/{index.tsx,link.tsx,anchor-context.ts} +
// semi-foundation/anchor/{foundation.ts,linkFoundation.ts,constants.ts,anchor.scss,
// variables.scss,rtl.scss}，数值逐条对编译后的 packages/semi-ui/dist/css/semi.css
// （`.semi-anchor*` 那一组）。
//
// 官方 AnchorProps（index.tsx:20-39）与缺省值（:72-87）：
//   size('default') / railTheme('primary') / offsetTop(0) / targetOffset(0) /
//   scrollMotion(false) / autoCollapse(false) / showTooltip(false) / position(没给) /
//   defaultAnchor('') / maxWidth('200px') / maxHeight('750px') / getContainer(noop ⇒ window) /
//   onChange / onClick / className('') / style / children / 'aria-label'('Side navigation')
// 滑轨：2px 宽、圆角 1、底色 color-border、`left:0 top:0 height:100%`（那条 ::before 才是底色轨，
// 高度取 link-wrapper 的 scrollHeight）；指示器同宽同圆角、高 28（default）/24（small）、
// `top` = 当前那条标题的 offsetTop、`display:none` 直到有 activeLink；
// **railTheme 的 muted 是整条滑轨（底色轨 + 指示器）都不画** —— variables 里那条
// `$color-anchor_slide_muted-bg-active: white` 在 scss 里根本没被引用。
// 外层 `overflow-y:auto; overflow-x:hidden; position:relative` + maxWidth/maxHeight
// ⇒ 列表比 maxHeight 高时**它自己**出滚动条。
//
// 端口与官方的差异（逐条）：
//   · `getContainer` 官方是 `() => HTMLElement | Window`（返回假值落回 window）。端口直接收
//     `container: Flickable`（与 Tooltip/Popover 的 `container` 同名同位），**window 档没有对应物**。
//   · `href` 官方既是「内容节点的 CSS 选择器」又是「activeLink 的键」；端口拆成 `href`
//     （标识串，回调与比对仍用它）+ `targetItem`（端口自有）。缺省值 `'/'` 照抄。
//   · `maxWidth` / `maxHeight` 官方吃 CSS 长度（`'200px'` 或数字），端口解析成像素；
//     解析不出来（`'auto'`、`undefined`）按「不夹」处理。
//   · `scrollMotion` 官方交给浏览器 `el.scroll({behavior:'smooth'})`（时长与曲线浏览器定）；
//     端口用一条 100ms / OutCubic 的 NumberAnimation —— 官方没有可对齐的数值，端口自定。
//   · `onChange(currentLink, previousLink)` ⇒ `change(currentLink, previousLink)`；
//     `onClick(e, currentLink)` 没有事件对象 ⇒ `click(currentLink)`。
//   · `position` 官方是 **Tooltip 的显示位置**（12 档 + leftTopOver/rightTopOver），只在
//     showTooltip 为真时有用；旧端口把这个名字当成「滑轨在左还是在右」用了 ⇒ 本轮改回官方语义，
//     滑轨固定在左（rtl 那档端口不做）。
//   · `className` / `style` 收了不产出可见差异（官方「综合使用」那节靠 style 做 position:fixed，
//     端口由使用方自己摆位）；`aria-label` 落 `Accessible.name`；`role` / `aria-details` /
//     `tabIndex` 落 `Accessible.*` 与 `activeFocusOnTab`。
//   · ResizeObserver（官方在元素从 display:none 变可见时重算滑轨高）端口不需要：那是绑定。
//   · React 子节点的 `componentDidMount` 是**后序**（最深的先注册）⇒ 官方 `links` 数组不是视觉顺序。
//     端口按声明顺序收。这条不影响选中（判据取的是「最接近 0 的那个负值」，与顺序无关），
//     只影响重复 href 时 `indexOf` 摘掉哪一条。
//   · 官方换 `getContainer` 不重挂监听（`this.scrollContainer` 在挂载时取一次），端口同样把
//     `Connections.target` 在 `Component.onCompleted` 钉一次；但 `handleScroll` 每次现读
//     `props.container` ⇒ 换过容器之后，旧容器滚动会用**新**容器的位置来判（同 BackTop 那一条）。
//
// 官方那几条「读起来像 bug」的口径，端口全部照抄并各钉一条用例：
//   · 没有任何负值（还没滚到第一条上方）⇒ `links[-1]` 是 undefined ⇒ **activeLink 被清空**，
//     指示器跟着消失；
//   · `getBoundingClientRect().top - containerTop - offsetTop` 外面套了 `|| -Infinity`
//     ⇒ 恰好等于 0 的那一条也算 -Infinity（永远选不中）；
//   · `handleScroll` 开头 `if (clickLink) return` ⇒ 点击之后到滚动停下来 100ms 之前滚动不抢高亮；
//     而解闩挂在**滚动事件**的 debounce 上 ⇒ 点一条已经在位的 Link 不产生滚动事件 ⇒
//     **闩永远不解**，此后滚动再也不改高亮；
//   · 滚动处理是 `throttle(fn, 100)`、解闩是 `debounce(fn, 100)`，两个挂在同一个 scroll 上；
//   · 指示器**没有过渡动画**（scss 那条 transition 只给标题字色，还是 0ms）；
//   · 标题选中不加字重、选中与未选中的 `background` 都是 transparent；
//   · `defaultAnchor` 非空时挂载走的是 `handleClick(null, defaultAnchor, false)` ⇒
//     置高亮 + 滚动，但 **onChange / onClick 都不发**。
Item {
    id: control

    /// 官方 children：一列 AnchorLink（顶层的；下一级声明在各条自己里面）
    default property alias content: linksColumn.data

    // ---------------------------------------------------------------- 官方 AnchorProps
    property string size: "default"               // small | default
    property string railTheme: "primary"          // primary | tertiary | muted
    property int offsetTop: 0
    property int targetOffset: 0
    property bool scrollMotion: false
    property bool autoCollapse: false
    /// 官方 boolean | { type: 'tooltip'|'popover', opts: object }
    property var showTooltip: false
    /// 官方 Tooltip 位置（字符串档）；空串 = 没给
    property string position: ""
    property string defaultAnchor: ""
    property var maxWidth: "200px"
    property var maxHeight: "750px"
    property string className: ""
    property var style: undefined
    property string ariaLabel: "Side navigation"
    /// 官方 getContainer()：端口收滚动容器本身
    property Flickable container: null

    /// 官方 onChange(currentLink, previousLink) / onClick(e, currentLink)
    signal change(string currentLink, string previousLink)
    signal click(string currentLink)

    /// 给 AnchorLink 认宿主用
    readonly property bool isAnchorRoot: true

    // ---------------------------------------------------------------- 官方那五条 state
    /// 官方 state.activeLink（初值 ''；滚动找不到负值时被写成 undefined）
    property var activeLink: ""
    /// 官方 state.clickLink
    property bool clickLink: false
    /// 官方 state.links（注册顺序的 href 名单）
    property var hrefList: []
    /// 官方 childMap：href → 其全部子孙 href
    property var childMap: ({})
    /// 官方 state.slideBarTop / 那条 height（端口只留数值，几何仍由 refreshVisual 写）
    property real slideBarTop: 0
    property real slideBarHeight: 0

    // ---------------------------------------------------------------- 派生
    readonly property bool small: control.size === "small"
    readonly property real rowHeight: control.small ? 24 : 28
    readonly property real railWidth: 2
    readonly property real railRadius: 1
    readonly property bool railHidden: control.railTheme === "muted"
    readonly property color indicatorColor: control.railTheme === "tertiary"
        ? Theme.current.colorTertiary : Theme.current.colorPrimary
    /// 官方 `showTooltip` 的真值判断（false / 空 ⇒ 不弹）
    readonly property bool tooltipOn: !(control.showTooltip === false
        || control.showTooltip === undefined || control.showTooltip === null
        || control.showTooltip === "" || control.showTooltip === 0)
    /// 官方 `showTooltip.type.toLowerCase() === 'popover'` ⇒ 大小写不敏感
    readonly property string tooltipKind: (typeof control.showTooltip === "object"
        && control.showTooltip.type !== undefined && control.showTooltip.type !== null)
        ? String(control.showTooltip.type).toLowerCase() : "tooltip"
    readonly property real maxWidthPx: control.pxOf(control.maxWidth, 200)
    readonly property real maxHeightPx: control.pxOf(control.maxHeight, 750)
    readonly property bool hasActive: control.activeLink !== undefined
        && control.activeLink !== null && control.activeLink !== ""
    /// 官方 `if (position) opts.position = position`；没给时吃浮层自己的缺省
    readonly property int tooltipPlacement: control.position === ""
        ? Enums.Top : control.placementOf(control.position)

    // 官方 componentDidMount 里造的那两个 100ms
    readonly property int scrollThrottleMs: 100
    readonly property int latchDebounceMs: 100
    property bool scrollPending: false
    /// 接线计数（变异与用例看「这一条接过没有」）
    property int wiredCount: 0
    /// 滚动信号进来到过几次 —— 「监听挂在谁身上」只有这个能干净地钉住
    property int scrollTicks: 0

    implicitWidth: control.maxWidthPx
    implicitHeight: Math.min(linksColumn.height, control.maxHeightPx)
    Accessible.name: control.ariaLabel

    function pxOf(v, fallback) {
        if (typeof v === "number")
            return v;
        if (typeof v !== "string" || v === "")
            return fallback;
        const n = Number(v.replace("px", ""));
        return Number.isNaN(n) ? -1 : n;          // -1 = 不夹（'auto' 那一档）
    }

    function placementOf(name) {
        switch (String(name)) {
        case "top": return Enums.Top;
        case "topLeft": return Enums.TopLeft;
        case "topRight": return Enums.TopRight;
        case "bottom": return Enums.Bottom;
        case "bottomLeft": return Enums.BottomLeft;
        case "bottomRight": return Enums.BottomRight;
        case "left": return Enums.Left;
        case "leftTop": return Enums.LeftTop;
        case "leftBottom": return Enums.LeftBottom;
        case "right": return Enums.Right;
        case "rightTop": return Enums.RightTop;
        case "rightBottom": return Enums.RightBottom;
        }
        return Enums.Top;
    }

    // ---------------------------------------------------------------- 名单、层级、childMap
    function linkNodes() {
        const out = [];
        control.collect(linksColumn, out);
        return out;
    }

    function collect(host, out) {
        if (host === undefined || host === null)
            return;
        const kids = host.children;
        for (let i = 0; i < kids.length; ++i) {
            const k = kids[i];
            if (k.isAnchorLinkType === true) {
                out.push(k);
                control.collect(k.childColumnRef, out);
            }
        }
    }

    /// 官方 renderChildren：按嵌套深度注入 level（顶层 1）
    function applyLevels(host, level) {
        if (host === undefined || host === null)
            return;
        const kids = host.children;
        for (let i = 0; i < kids.length; ++i) {
            const k = kids[i];
            if (k.isAnchorLinkType === true) {
                k.level = level;
                control.applyLevels(k.childColumnRef, level + 1);
            }
        }
    }

    /// 官方 setChildMap：每个祖先留一份「它下面所有 href」
    function buildChildMap() {
        const map = {};
        const list = control.linkNodes();
        for (let i = 0; i < list.length; ++i)
            map[list[i].href] = [];
        for (let i = 0; i < list.length; ++i) {
            let p = list[i].parentLink();
            while (p !== null) {
                if (map[p.href] !== undefined && map[p.href].indexOf(list[i].href) === -1)
                    map[p.href].push(list[i].href);
                p = p.parentLink();
            }
        }
        control.childMap = map;
    }

    /// 官方 Link.renderChildren 那条判据
    function revealsChildren(href) {
        if (!control.autoCollapse)
            return true;
        const active = control.activeLink;
        if (active === href)
            return true;
        const kids = control.childMap[href];
        return kids !== undefined && kids.indexOf(active) !== -1;
    }

    // ---------------------------------------------------------------- 选中
    /// 官方 getLinksBoundingTop 里那条 `(top - containerTop - offsetTop) || -Infinity`
    function relTop(link) {
        if (control.container === null)
            return -Infinity;
        const raw = link.targetTop() - control.container.contentY - control.offsetTop;
        return raw ? raw : -Infinity;
    }

    /// 官方 foundation.handleScroll
    function handleScroll() {
        if (control.clickLink)
            return;
        const list = control.linkNodes();
        let lastNegative = -Infinity;
        let lastNegativeIndex = -1;
        for (let i = 0; i < list.length; ++i) {
            const top = control.relTop(list[i]);
            if (top < 0 && top > lastNegative) {
                lastNegative = top;
                lastNegativeIndex = i;
            }
        }
        // 官方 links[-1] ⇒ undefined：一条都没滚过时 activeLink 被清空
        control.setActiveLink(lastNegativeIndex === -1 ? undefined
            : list[lastNegativeIndex].href, true);
    }

    /// 官方 foundation.setActiveLink：只有变了才写、才回调、才挪指示器
    function setActiveLink(link, shouldNotify) {
        if (control.activeLink === link)
            return;
        const prev = control.activeLink;
        control.activeLink = link;
        control.refreshVisual();
        if (shouldNotify)
            control.change(String(link === undefined ? "" : link),
                String(prev === undefined ? "" : prev));
    }

    /// 官方 foundation.handleClick（defaultAnchor 走 shouldNotify=false 那一档）
    function handleClick(href, shouldNotify) {
        const list = control.linkNodes();
        let target = null;
        for (let i = 0; i < list.length; ++i) {
            if (list[i].href === href) {
                target = list[i];
                break;
            }
        }
        control.setActiveLink(href, shouldNotify);
        // 官方 `if (destNode)`：找不到内容节点就只置高亮、不滚动、也不置闩
        if (target !== null && target.targetItem !== null) {
            control.clickLink = true;
            control.scrollIntoView(target);
        }
        if (shouldNotify)
            control.click(href);
    }

    /// 端口自留的观察口：scrollMotion 那颗动画本身与它跑没跑
    readonly property alias scrollAnimation: scrollAnim
    readonly property bool scrolling: scrollAnim.running

    /// 官方 _scrollIntoView：只滚那条能垂直滚的容器，减 targetOffset
    function scrollIntoView(link) {
        if (control.container === null)
            return;
        const to = Math.max(0, link.targetTop() - control.targetOffset);
        if (!control.scrollMotion) {
            control.container.contentY = to;
            return;
        }
        scrollAnim.from = control.container.contentY;
        scrollAnim.to = to;
        scrollAnim.duration = 100;                  // 浏览器 smooth 的时长没有可对齐的数值
        scrollAnim.start();
    }

    // ---------------------------------------------------------------- 刷新
    /// 把 selected / rowWidth 写进各条，并把指示器挪到当前那条
    function refreshVisual() {
        const list = control.linkNodes();
        for (let i = 0; i < list.length; ++i) {
            const l = list[i];
            l.selected = control.hasActive && l.href === control.activeLink;
            l.rowWidth = control.width;
            if (l.selected) {
                control.slideBarTop = l.y;
                control.slideBarHeight = control.rowHeight;
            }
        }
        if (!control.hasActive) {
            control.slideBarTop = 0;
            control.slideBarHeight = 0;
        }
    }

    function wireLinks() {
        const list = control.linkNodes();
        for (let i = 0; i < list.length; ++i) {
            const l = list[i];
            if (l.hostWired)
                continue;
            l.hostWired = true;
            l.clicked.connect(function () {
                control.handleClick(l.href, true);
            });
            control.wiredCount += 1;
        }
    }

    function refresh() {
        control.applyLevels(linksColumn, 1);
        control.wireLinks();
        control.buildChildMap();
        control.hrefList = control.linkNodes().map(function (l) {
            return l.href;
        });
        control.refreshVisual();
    }

    /// 官方那两个 listener 都挂在容器的 scroll 上：throttle 处理选中、debounce 解闩
    function onContainerScroll() {
        control.scrollTicks += 1;
        if (scrollThrottle.running) {
            control.scrollPending = true;
        } else {
            scrollThrottle.restart();
            control.handleScroll();
        }
        latchTimer.restart();
    }

    Component.onCompleted: {
        scrollConn.target = control.container;      // 只挂这一次，换容器不改挂
        control.refresh();
        if (control.defaultAnchor !== "")
            control.handleClick(control.defaultAnchor, false);
    }

    onActiveLinkChanged: control.refreshVisual()
    onAutoCollapseChanged: control.refresh()
    onSizeChanged: control.refresh()
    onMaxWidthChanged: control.refresh()
    onWidthChanged: control.refreshVisual()
    onOffsetTopChanged: control.handleScroll()

    Connections {
        id: scrollConn

        target: null
        function onContentYChanged() {
            control.onContainerScroll();
        }
    }

    // ---------------------------------------------------------------- 滑轨与列表
    Flickable {
        id: selfScroll

        objectName: "anchorSelfScroll"
        width: parent.width
        height: control.height
        contentHeight: linksColumn.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        // 官方 overflow-y: auto ⇒ 只有真溢出才滚
        interactive: linksColumn.height > control.maxHeightPx

        Item {
            id: slide

            objectName: "anchorSlide"
            x: 0
            y: 0
            width: control.railWidth
            height: linksColumn.height
            visible: !control.railHidden            // -slide-muted { display: none }

            Rectangle {
                objectName: "anchorRail"
                anchors.fill: parent
                radius: control.railRadius
                color: Theme.current.colorBorder
            }

            Rectangle {
                objectName: "anchorIndicator"
                y: control.slideBarTop
                width: control.railWidth
                height: control.slideBarHeight
                radius: control.railRadius
                color: control.indicatorColor
                visible: control.hasActive          // display:none 直到 -slide-bar-active
            }
        }

        Column {
            id: linksColumn

            objectName: "anchorLinks"
            width: parent.width
            spacing: 0
            // 官方是每条 Link 在 componentDidMount 里 addLink（Repeater 延后塞进来的委托也算），
            // 端口没有那个钩子 ⇒ 盯这一列的子项变化重收一遍名单
            onChildrenChanged: control.refresh()
        }
    }

    NumberAnimation {
        id: scrollAnim

        target: control.container
        property: "contentY"
        easing.type: Easing.OutCubic
    }

    Timer {
        id: scrollThrottle

        interval: control.scrollThrottleMs
        onTriggered: {
            if (!control.scrollPending)
                return;
            control.scrollPending = false;
            control.handleScroll();                 // trailing：窗口内滚过就补一次
        }
    }

    Timer {
        id: latchTimer

        interval: control.latchDebounceMs
        onTriggered: control.clickLink = false      // 官方 handleClickLink
    }
}
