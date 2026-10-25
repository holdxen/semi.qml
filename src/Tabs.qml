pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 标签页。对应 `packages/semi-ui/tabs/{index.tsx,TabBar.tsx,TabItem.tsx,TabPane.tsx,
// tabs-context.ts,interface.ts}` + `packages/semi-foundation/tabs/{foundation.ts,constants.ts,
// tabs.scss,variables.scss,animation.scss}`，数值对着编译产物
// `packages/semi-ui/dist/css/semi.css` 21854-22609 段。
//
//     Tabs {
//         type: "card"
//         activeKey: "a"
//         TabPane { itemKey: "a"; tab: "标签一"; Text { text: "内容一" } }
//         TabPane { itemKey: "b"; tab: "标签二" }
//         onChange: key => …
//     }
//
// 两条数据来源与官方一致：`tabList` 数组档**只出标签栏、零面板**（PlainTab 没有内容字段），
// `TabPane` 子元素档同时出标签与面板。数组非空时子元素整条不读（同 Descriptions / Steps）。
//
// ---------------------------------------------------------------- 与官方的口径差异（逐条）
//   · `className` / `style` / `tabBarClassName` / `tabBarStyle` / `contentStyle` /
//     `visibleTabsStyle` 是 DOM/CSS 通道，不收。
//   · `tab` / `icon` / `tabBarExtraContent` / `more.render` / `renderArrow` / `renderTabBar`
//     官方是 ReactNode 或返回元素的函数；端口统一收「字符串或 Component」，钩子入参靠
//     「节点自己声明 property、端口创建后写进去」这一条通道（本库 render* 口子统一这么办）。
//   · 回调 → 信号：`onChange` → `change(string)`、`onTabClick(key, e)` → `tabClick(string)`
//     （不带事件对象）、`onTabClose` → `tabClose(string)`、`onVisibleTabsChange(Map)` →
//     `visibleTabsChange(var)`（端口给普通对象 `{key: bool}`，同 OverflowList 那一档）。
//   · `preventScroll` 收了但**落不到实处**：官方把它传给 `HTMLElement.focus({preventScroll})`，
//     而 QML 的 `forceActiveFocus()` 本来就不滚祖先。
//   · `keepDOM: false` 与 `lazyRender` 官方是「不渲染 / 推迟渲染」；QML 的内联子项没法推迟创建
//     ⇒ 端口落成「内容层 visible/enabled 关掉」。视觉与布局一致，差别只在子项的
//     `Component.onCompleted` 会不会提前跑一次。
//   · 宿主会给每个 `TabPane` 写 `x/y/width`（官方是块级流 + `width:100%`）⇒ 使用方**别给面板
//     写这三条绑定**，会被打断。
//   · `dropdownProps`（`{start, end}`）收下来，按键写进那两只 Dropdown。
//   · 官方 `more` 的文案走 i18n（`locale.more`）⇒ 端口写死「更多」，本库没有 locale 通道。
//
// ---------------------------------------------------------------- 抄下来的上游行为（不"修好"）
//   · `size` 缺省是 **`large`**（index.tsx:69），而 `TabItem.tsx:80-81` 只给 small/medium 挂类名
//     ⇒ large 的几何就是「无 size 类名那条默认」。card / button / slash **完全没有 size 变体**
//     （类名照挂、semi.css 里 0 条规则匹配）⇒ `size` 对这三档毫无视觉差异。
//   · `closable` 不判 type（TabItem.tsx:39-47）⇒ line / button / slash 一样出 ×，
//     尽管文档写「只有卡片式支持关闭」。
//   · `onTabClose` **从不真的关闭**（foundation.ts:71-73 → index.tsx:138-140 只通知）
//     ⇒ 使用方得自己从 `tabList` / children 里摘掉那一项。
//   · 键盘方向键**只挪焦点、不激活、不发 onChange**（foundation.ts:144-166）；横排只认 ←/→、
//     竖排只认 ↑/↓，另一对静默吞掉；`Enter` / `Space` 才激活，且这一条**不判 disabled**。
//     `Delete` / `Backspace` 只在那格 `closable` 时才走关闭，且**只剩一格时跳过挪焦点**。
//     方向键与 Home/End 走的是「过滤掉 aria-disabled=true」那份名单 ⇒ 会跳过禁用格。
//   · 激活位漂移时退成**第一项**、不是相邻项，而且**不发 onChange**（index.tsx:102-117）。
//   · `collapsible` 与 `more` 互斥、**collapsible 赢**（TabBar.tsx:425）；`more` 给 `0` 被当假值
//     忽略、给 `true` 这类非 number/object 上游直接抛 —— 端口收成「不算 more 档」。
//   · `extra` 槽高 50 而 line 格子高 52 ⇒ 官方自己就有 2px 竖向错位（CSS:22176-22183，
//     且只有 `-extra-small` 那一档改 36，没有 medium/large 变体）。
//   · 整个 Tabs 唯一有动画的是**面板入场**（200ms ease-in-out、±60px 位移 + 透明度、forwards、
//     只在激活那一次）；标签栏所有 hover / active / 底色 / 指示条的 transition 全被
//     `animation.scss:1-17` 映射到 0ms ⇒ 格子上一条 `Behavior` 都不挂。
Item {
    id: control

    // ================================================================ 官方属性面
    property var tabList: undefined                 // PlainTab[]：{itemKey, tab, icon, disabled, closable}
    property var activeKey: undefined               // 给了就是受控
    property var defaultActiveKey: undefined
    property string type: "line"                    // line | card | button | slash
    property string size: "large"                   // small | medium | large
    property string tabPosition: "top"              // top | left
    property bool keepDOM: true
    property bool lazyRender: false
    property bool tabPaneMotion: true
    property var collapsible: false                 // false | true | "auto"
    property var more: undefined                    // number | {count, render}
    property bool showRestInDropdown: true
    property string arrowPosition: "both"           // start | end | both
    property bool preventScroll: false
    property Component tabBarExtraContent: null
    property Component renderArrow: null
    property Component renderTabBar: null
    property var dropdownProps: undefined           // {start: {...}, end: {...}}

    signal change(string activeKey)
    signal tabClick(string activeKey)
    signal tabClose(string itemKey)
    signal visibleTabsChange(var visibleState)

    // ================================================================ 内部状态
    property var items: []                          // {itemKey,label,icon,disabled,closable,pane}
    property string currentKey: ""
    property string prevActiveKey: ""
    /// collapsible:"auto" 量出来的那一轮结果：标签栏自然宽比可用宽多 1px 以上才折
    /// （官方是 `scrollWidth > clientWidth + 1`，TabBar.tsx:118）
    readonly property bool autoCollapsed: control.autoGiven
        && control.barNaturalLen > control.availableBarWidth() + 1
    /// 未折叠那一条流排出来的自然宽，由标签栏里那份 Binding 回写
    property real barNaturalLen: 0

    /// 可用宽 = 容器宽扣掉 extra 槽（竖排没有 extra 的概念，整幅给标签栏）
    function availableBarWidth() {
        return Math.max(0, control.width - control.extraSlotWidth);
    }
    /// index.tsx:173-179：activeKey 换到一个「这一轮新加进来的面板」上时，那一次不播入场动画
    property bool forceDisableMotion: false
    property bool _mounted: false
    property var barBox: null                       // 由标签栏那一层回填，键盘与量宽都从它下面找

    readonly property bool vertical: control.tabPosition === "left"
    readonly property bool listMode: control.tabList !== undefined && control.tabList !== null
        && control.tabList.length > 0
    readonly property bool collapseGiven: control.collapsible === true
    readonly property bool autoGiven: control.collapsible === "auto"
    /// TabBar.tsx:92-100：'auto' 取量出来的 shouldCollapse，否则取布尔本身
    readonly property bool collapseOn: control.autoGiven ? control.autoCollapsed : control.collapseGiven
    /// TabBar.tsx:425 那个三元：collapsible 赢，more 只在没折叠时被读
    readonly property bool moreOn: !control.collapseOn && control.moreIsValid
    readonly property bool moreIsValid: typeof control.more === "number" ? control.more > 0
        : (typeof control.more === "object" && control.more !== null)
    readonly property int moreCount: typeof control.more === "number" ? control.more
        : (typeof control.more === "object" && control.more !== null
            && typeof control.more.count === "number" ? control.more.count : 0)
    readonly property bool activeGiven: control.activeKey !== undefined && control.activeKey !== null
    readonly property int count: control.items.length
    readonly property int activeIndex: control.indexOfKey(control.currentKey)
    /// 官方 `getPanes` 在有 tabList 时整份返回数组，否则读 children
    readonly property int barTotal: control.moreOn
        ? control.count - Math.min(control.moreCount, control.count) : control.count

    // ================================================================ 度量（CSS 逐档）
    /// 一格的高：line/top 52·44·36，line/left 44·40·32，card 37（横）·38（竖），
    /// button 36，slash 44（CSS:22113-22294，全部由 padding + 行高 20 + 边框推出）
    readonly property real itemHeight: control.vertical
        ? (control.type === "line" ? (control.size === "small" ? 32 : (control.size === "medium" ? 40 : 44))
            : (control.type === "card" ? 38 : 36))
        : (control.type === "line" ? (control.size === "small" ? 36 : (control.size === "medium" ? 44 : 52))
            : (control.type === "card" ? 37 : (control.type === "button" ? 36 : 44)))
    /// 格与格之间：line/top 24、card 与 button 8、slash 16、line/left 0（竖排没有 margin 规则）
    readonly property real itemGap: control.vertical
        ? (control.type === "line" ? 0 : 8)
        : (control.type === "line" ? 24 : (control.type === "slash" ? 16 : 8))
    /// 基线归属：line 与 card 有，button 与 slash 没有（CSS:22109 / 22144 / 22189 / 22210）
    readonly property bool hasBaseline: control.type === "line" || control.type === "card"
    /// `.semi-tabs-content` 的 padding：横排 5px 0、竖排 0 5px（CSS:22306-22313）
    readonly property real contentPadX: control.vertical ? 5 : 0
    readonly property real contentPadY: control.vertical ? 0 : 5
    /// extra 槽：只有 line 档有高度（50，small 档 36），padding 恒 0 5px（CSS:21871、22176-22183）
    readonly property real extraHeight: control.type === "line" ? (control.size === "small" ? 36 : 50) : 0
    readonly property real extraPadX: 5
    /// 竖排时标签栏占的宽：官方那一档 bar 是 flex column、宽由内容撑开，
    /// 而 `.semi-tabs-left` 是 `flex-direction: row` ⇒ 端口给「内容自然宽」，容器宽由使用方定
    readonly property real barWidth: control.vertical
        ? (control.barBox === null ? 0 : control.barBox.implicitWidth)
        : Math.max(0, control.width)
    readonly property real barHeight: control.vertical
        ? (control.barBox === null ? control.itemHeight : control.barBox.implicitHeight)
        : control.itemHeight

    implicitWidth: control.vertical ? control.barWidth + control.contentPadX * 2
        : Math.max(0, control.width)
    implicitHeight: control.barHeight + control.contentPadY * 2 + control.activePaneHeight

    readonly property real activePaneHeight: control.activeIndex >= 0
        && control.items[control.activeIndex].pane !== null
        ? control.items[control.activeIndex].pane.implicitHeight : 0

    // ================================================================ 收集两条数据来源
    function collect() {
        const list = [];
        if (control.listMode) {
            // 数组档赢：先前收养过的子元素面板整条撤回（同 Steps 的口径，别留下认旧主的格子）
            for (let i = 0; i < control.children.length; ++i) {
                const k = control.children[i];
                if (k.isTabPane === true) {
                    k.host = null;
                    k.hostActive = false;
                }
            }
            for (let i = 0; i < control.tabList.length; ++i) {
                const raw = control.tabList[i];
                // 上游 getPanes 不筛，null 那一项会让后面读 itemKey 抛 ⇒ 端口收成「没有这一格」
                if (raw === undefined || raw === null)
                    continue;
                list.push(control.makeItem(control.keyOf(raw.itemKey, i),
                    raw.tab === undefined ? "" : raw.tab,
                    raw.icon === undefined ? "" : raw.icon,
                    raw.disabled === true, raw.closable === true, null));
            }
        } else {
            for (let i = 0; i < control.children.length; ++i) {
                const k = control.children[i];
                if (k.isTabPane !== true || k.fromRepeater === true)
                    continue;
                if (control.listMode)
                    continue;
                k.host = control;
                list.push(control.makeItem(control.keyOf(k.itemKey, i), k.tab, k.icon,
                    k.disabled, k.closable, k));
            }
        }
        control.items = list;
        control.reseat();
        control.refresh();
    }

    function makeItem(key, label, icon, disabled, closable, pane) {
        return { itemKey: key, label: label, icon: icon, disabled: disabled,
            closable: closable, pane: pane };
    }

    function keyOf(v, i) {
        if (v === undefined || v === null || v === "")
            return String(i);
        return String(v);
    }

    // ================================================================ 激活位
    /// foundation.getDefaultActiveKey：`'activeKey' in props` → 用它；否则 defaultActiveKey；
    /// 再否则「第一个没禁用的 itemKey」
    function defaultKeyOf() {
        if (control.activeGiven)
            return String(control.activeKey);
        if (control.defaultActiveKey !== undefined && control.defaultActiveKey !== null)
            return String(control.defaultActiveKey);
        for (let i = 0; i < control.items.length; ++i) {
            if (!control.items[i].disabled)
                return control.items[i].itemKey;
        }
        return "";
    }

    /// adapter.collectActiveKey（index.tsx:102-117）：受控档不重挑；非受控档在当前键
    /// 不在新 panes 里时退成 **第一项**（不是相邻项），而且**不发 change**
    function reseat() {
        // 受控档不重挑：currentKey 由 Component.onCompleted 与 onActiveKeyChanged 两处
        // 从 prop 灌进来，这里再写一遍是重复的（变异打它打不红 ⇒ 删）
        if (control.activeGiven)
            return;
        if (control.indexOfKey(control.currentKey) >= 0)
            return;
        control.currentKey = control.items.length > 0 ? control.items[0].itemKey : "";
    }

    function indexOfKey(key) {
        for (let i = 0; i < control.items.length; ++i)
            if (control.items[i].itemKey === key)
                return i;
        return -1;
    }

    function itemOf(key) {
        const i = control.indexOfKey(key);
        return i < 0 ? null : control.items[i];
    }

    function setActiveKey(key) {
        if (control.currentKey === key)
            return;
        control.prevActiveKey = control.currentKey;
        control.currentKey = key;
        control.change(key);
        control.refresh();
    }

    function handleClick(key) {
        control.tabClick(key);
        if (control.activeGiven)
            return;                             // 受控档：内部不改，等使用方回灌
        control.setActiveKey(key);
    }

    /// index.tsx:241-244：先 stopPropagation、再**只通知**，不摘那一格
    function handleDelete(key) {
        control.tabClose(key);
    }

    function refresh() {
        const idx = control.indexOfKey(control.currentKey);
        for (let i = 0; i < control.items.length; ++i) {
            const it = control.items[i];
            if (it.pane === null)
                continue;
            it.pane.hostActive = (i === idx);
            it.pane.hostFromEnd = control.directionOf(i, idx);
            it.pane.hostVertical = control.vertical;
            it.pane.hostMotion = control.tabPaneMotion && (i === idx) && control._mounted
                && !control.forceDisableMotion;
            it.pane.x = control.vertical ? control.barWidth + control.contentPadX : 0;
            it.pane.y = control.vertical ? 0 : control.barHeight + control.contentPadY;
            it.pane.width = Math.max(0, control.width - it.pane.x - control.contentPadX);
        }
        control.rebuildMoreMenu();
    }

    /// TabPane.getDirection :32-47：这一格相对激活位是从「前」还是「后」进来
    function directionOf(i, activeIndex) {
        if (i === activeIndex) {
            const last = control.indexOfKey(control.prevActiveKey);
            return last > activeIndex;
        }
        return i < activeIndex;
    }

    // ================================================================ 键盘（foundation.ts）
    /// 官方那份名单过滤掉了 `aria-disabled="true"` ⇒ 方向键 / Home / End **跳过禁用格**
    function usableKeys() {
        const out = [];
        for (let i = 0; i < control.items.length; ++i)
            if (!control.items[i].disabled)
                out.push(control.items[i].itemKey);
        return out;
    }

    /// 测试与排版都要用：标签栏里现在真实画出来的那些格子（按 x 排）
    function cells() {
        const out = [];
        if (control.barBox === null)
            return out;
        const walk = function (n) {
            if (n === null || n === undefined)
                return;
            if (n.objectName === "tabItemRoot")
                out.push(n);
            const kids = n.children;
            if (kids === undefined)
                return;
            for (let i = 0; i < kids.length; ++i)
                walk(kids[i]);
        };
        walk(control.barBox);
        return out;
    }

    /// moveFocusTo 记下的最后一次焦点落点 —— 焦点在 offscreen 下不一定真能拿到，
    /// 但「该谁拿」这件事必须可断言
    property string focusedKey: ""

    function cellOf(key) {
        const all = control.cells();
        for (let i = 0; i < all.length; ++i)
            if (all[i].itemKey === key)
                return all[i];
        return null;
    }

    function moveFocusTo(key) {
        const cell = control.cellOf(key);
        if (cell === null || !cell.visible)
            return;
        control.focusedKey = key;
        cell.forceActiveFocus();
    }

    function handleKeyDown(keyName, itemKey, closable) {
        if (keyName === "Enter") {
            control.handleClick(itemKey);       // 不判 disabled、也不看那份过滤后的名单
            return;
        }
        const usable = control.usableKeys();
        const at = usable.indexOf(itemKey);
        if (at < 0)
            return;                             // 其余键走的是过滤掉禁用格的那份名单
        const forward = keyName === "ArrowRight" || keyName === "ArrowDown";
        const backward = keyName === "ArrowLeft" || keyName === "ArrowUp";
        const verticalPair = keyName === "ArrowUp" || keyName === "ArrowDown";
        if (forward || backward) {
            // determineOrientation：横排只认 ←/→、竖排只认 ↑/↓，另一对静默吞掉
            if (control.vertical !== verticalPair)
                return;
            const next = at + (forward ? 1 : -1);
            if (next >= 0 && next < usable.length)
                control.moveFocusTo(usable[next]);
            else
                control.moveFocusTo(usable[forward ? 0 : usable.length - 1]);
            return;
        }
        if (keyName === "Home") {
            control.moveFocusTo(usable[0]);
            return;
        }
        if (keyName === "End") {
            control.moveFocusTo(usable[usable.length - 1]);
            return;
        }
        if (keyName === "Delete") {
            if (!closable)
                return;
            control.handleDelete(itemKey);
            if (usable.length !== 1)            // 只剩一格时跳过挪焦点
                control.moveFocusTo(usable[at + 1 >= usable.length ? at - 1 : at + 1]);
        }
    }

    // ================================================================ 生命周期
    Component.onCompleted: {
        control._mounted = true;
        control.collect();
        control.currentKey = control.defaultKeyOf();
        control.reseat();
        control.refresh();
    }
    onChildrenChanged: control.collect()
    onTabListChanged: control.collect()
    onTypeChanged: control.refresh()
    onSizeChanged: control.refresh()
    onTabPositionChanged: control.refresh()
    onKeepDOMChanged: control.refresh()
    onLazyRenderChanged: control.refresh()
    onCollapsibleChanged: control.refresh()
    onMoreChanged: control.refresh()
    onWidthChanged: control.refresh()
    onActiveKeyChanged: {
        if (!control.activeGiven)
            return;
        control.prevActiveKey = control.currentKey;
        control.currentKey = String(control.activeKey);
        control.refresh();
    }
    onCurrentKeyChanged: control.refresh()

    // ================================================================ 标签栏
    Loader {
        id: barLoader

        objectName: "tabsBarLoader"

        anchors.left: parent.left
        anchors.top: parent.top
        width: control.vertical ? undefined : control.width
        height: control.vertical ? undefined : control.itemHeight
        sourceComponent: control.renderTabBar === null ? control.defaultBar : control.renderTabBar
        onLoaded: {
            if (item === null)
                return;
            // 钩子那一份要能拿到宿主与「默认那条栏」，否则它没法只替换一部分
            if (control.renderTabBar !== null) {
                item.host = control;
                item.defaultTabBar = control.defaultBar;
            }
        }
    }

    /// renderTabBar 那一档：钩子节点自己声明 `property var host`（宿主）与
    /// `property Component defaultTabBar`，端口把两枚注进去
    property Component defaultBar: Component {
        Item {
            id: barBox

            objectName: "tabsBar"

            implicitWidth: control.vertical
                ? Math.max(flowLoader.implicitWidth, overflowLoader.implicitWidth) : control.width
            implicitHeight: control.vertical
                ? Math.max(flowLoader.implicitHeight, overflowLoader.implicitHeight)
                : control.itemHeight

            Component.onCompleted: control.barBox = barBox
            Component.onDestruction: {
                if (control.barBox === barBox)
                    control.barBox = null;
            }

            // 基线：line/top 是 bar 的 border-bottom、card/top 是 ::before 那条 1px；
            // 竖排那一档换成 border-right（CSS:22109 / 22144 / 22189 / 22210）
            Rectangle {
                objectName: "tabsBarBaseline"

                visible: control.hasBaseline && !control.vertical
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.current.colorBorder
            }
            Rectangle {
                objectName: "tabsBarBaselineLeft"

                visible: control.hasBaseline && control.vertical
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 1
                color: Theme.current.colorBorder
            }

            Loader {
                id: overflowLoader

                objectName: "tabsOverflowList"

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, parent.width - control.extraSlotWidth)
                active: control.collapseOn
                sourceComponent: control.overflowBar
            }

            // 非折叠档：横排是 Row（官方 float:left + nowrap 的等价物，溢出就超出容器、**不折行**），
            // 竖排是 Column（flex-direction: column）。格子由 barModel() 那份模型造出来，
            // more 档的「更多」触发器与它的 Dropdown 排在末尾。
            Loader {
                id: flowLoader

                objectName: "tabsBarFlow"

                anchors.left: parent.left
                anchors.top: parent.top
                visible: !control.collapseOn
                sourceComponent: control.vertical ? control.colBar : control.rowBar
            }

            // 把「不折叠时这一条有多长」量回宿主 —— 用 Binding 而不是命令式：
            // 格子的隐式宽要等自己那棵子树排完才有真值，比 collect() 晚一拍
            Binding {
                target: control
                property: "barNaturalLen"
                value: flowLoader.item === null || flowLoader.item === undefined ? 0
                    : flowLoader.item.implicitWidth
                when: flowLoader.item !== null && flowLoader.item !== undefined
            }

            Loader {
                id: extraLoader

                objectName: "tabsExtraSlot"

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: control.extraPadX
                y: control.vertical ? 0
                    : Math.max(0, (control.itemHeight - control.extraHeight) / 2)
                sourceComponent: control.tabBarExtraContent
            }
        }
    }

    /// 横排那一条：Row + 末尾的「更多」触发器
    property Component rowBar: Component {
        Row {
            objectName: "tabsBarRow"

            spacing: control.itemGap

            Repeater {
                model: control.barModel()

                delegate: control.tabItemComp
            }

            Loader {
                objectName: "tabsMoreTrigger"

                visible: control.moreOn
                sourceComponent: control.moreOn ? control.moreTriggerNode() : null
            }
        }
    }

    /// 竖排那一条
    property Component colBar: Component {
        Column {
            objectName: "tabsBarColumn"

            spacing: control.itemGap

            Repeater {
                model: control.barModel()

                delegate: control.tabItemComp
            }

            Loader {
                objectName: "tabsMoreTrigger"

                visible: control.moreOn
                sourceComponent: control.moreOn ? control.moreTriggerNode() : null
            }
        }
    }

    /// 一格。抽成 control 上的 Component 是为了让 Row / Column 两条分支共用同一份接线
    property Component tabItemComp: Component {
        TabItem {
            id: cell

            objectName: "tabItemRoot"

            required property var modelData

            itemKey: cell.modelData.itemKey
            label: cell.modelData.label
            iconValue: cell.modelData.icon
            disabled: cell.modelData.disabled
            closable: cell.modelData.closable
            hostType: control.type
            hostSize: control.size
            hostPosition: control.tabPosition
            hostFirst: cell.modelData.at === 0
            hostLast: cell.modelData.last
            hostSelected: cell.modelData.itemKey === control.currentKey

            onClicked: control.handleClick(cell.modelData.itemKey)
            onCloseClicked: control.handleDelete(cell.modelData.itemKey)
            onKeyPressed: name => control.handleKeyDown(name, cell.modelData.itemKey,
                cell.modelData.closable)
        }
    }

    /// 没给 tabBarExtraContent 时官方那个 div 根本不渲染（TabBar.tsx:161 的 `if (tabBarExtraContent)`）
    /// ⇒ 端口也不能占宽，否则可用宽凭空少 10、auto 还会误判成溢出
    readonly property real extraSlotWidth: control.tabBarExtraContent === null || control.barBox === null
        ? 0
        : (control.findExtra(control.barBox) === null ? 0
            : control.findExtra(control.barBox).implicitWidth + control.extraPadX * 2)

    function findExtra(node) {
        if (node === null || node === undefined)
            return null;
        if (node.objectName === "tabsExtraSlot")
            return node;
        const kids = node.children;
        if (kids === undefined)
            return null;
        for (let i = 0; i < kids.length; ++i) {
            const hit = control.findExtra(kids[i]);
            if (hit !== null)
                return hit;
        }
        return null;
    }

    /// 折叠档交给 OverflowList 的滚动档：两侧箭头就是官方那对 chevron 按钮
    property Component overflowBar: Component {
        OverflowList {
            objectName: "tabsOverflowInner"

            items: control.overflowItems()
            renderMode: "scroll"
            visibleItemRenderer: control.overflowCellRenderer
            overflowRenderer: control.arrowRenderer
            onVisibleStateChange: state => control.visibleTabsChange(state)
        }
    }

    property Component overflowCellRenderer: Component {
        TabItem {
            objectName: "tabItemRoot"

            property var item: null
            property int index: 0

            itemKey: cellItemKey()
            label: cellField("label")
            iconValue: cellField("icon")
            disabled: cellBool("disabled")
            closable: cellBool("closable")
            hostType: control.type
            hostSize: control.size
            hostPosition: control.tabPosition
            hostFirst: control.indexOfKey(cellItemKey()) === 0
            hostLast: control.indexOfKey(cellItemKey()) === control.count - 1
            hostSelected: cellItemKey() === control.currentKey

            function cellItemKey() {
                return item === null || item === undefined ? "" : String(item.key);
            }

            function cellField(k) {
                if (item === null || item === undefined || item[k] === undefined)
                    return "";
                return item[k];
            }

            function cellBool(k) {
                return item !== null && item !== undefined && item[k] === true;
            }

            onClicked: control.handleClick(cellItemKey())
            onCloseClicked: control.handleDelete(cellItemKey())
            onKeyPressed: name => control.handleKeyDown(name, cellItemKey(), cellBool("closable"))
        }
    }

    /// 官方 renderCollapse（TabBar.tsx:219-295）：一格宽 4px 外边距 + 一只 borderless 按钮，
    /// 空集时禁用；showRestInDropdown 为真时挂 hover 触发的 Dropdown（bottomLeft / bottomRight）
    property Component arrowRenderer: Component {
        Item {
            id: arrowBox

            objectName: "tabsArrowNode"

            property var overflowItems: []
            property string overflowSide: "after"

            readonly property bool atStart: arrowBox.overflowSide === "before"
            readonly property bool hasRest: arrowBox.overflowItems !== undefined
                && arrowBox.overflowItems !== null && arrowBox.overflowItems.length > 0

            /// arrowPosition：'start' 只留左箭头、'end' 只留右箭头、'both' 两侧都留
            readonly property bool allowed: control.arrowPosition === "both"
                || (control.arrowPosition === "start" && arrowBox.atStart)
                || (control.arrowPosition === "end" && !arrowBox.atStart)

            implicitWidth: allowed ? 28 : 0
            implicitHeight: control.itemHeight
            visible: allowed

            // 默认那对箭头直接画在这里；给了 renderArrow 才换成交付节点，
            // 并按本库 render* 的惯例把 side / rest 注进被载入的项
            Icon {
                objectName: "tabsArrowIcon"

                anchors.centerIn: parent
                visible: control.renderArrow === null
                name: arrowBox.atStart ? "chevron_left" : "chevron_right"
                size: 16
                color: arrowBox.hasRest ? Theme.current.colorPrimary : Theme.current.colorDisabledText
            }

            Loader {
                id: arrowHook

                objectName: "tabsArrowHook"

                anchors.centerIn: parent
                active: control.renderArrow !== null
                sourceComponent: control.renderArrow
                onLoaded: {
                    if (item === null)
                        return;
                    // qmllint disable missing-property
                    item.side = arrowBox.atStart ? "start" : "end";
                    item.rest = arrowBox.overflowItems;
                    // qmllint enable missing-property
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: arrowBox.hasRest
                onClicked: control.handleArrowClick(arrowBox.atStart ? "start" : "end")
            }
        }
    }

    /// TabBar.tsx:210-217：把「这一侧收起的那批」的首/末项滚进视野
    function handleArrowClick(pos) {
        const list = control.overflowItems();
        const side = pos === "start" ? list[0] : list[1];
        if (side === undefined || side.length === 0)
            return;
        const take = pos === "start" ? side[side.length - 1] : side[0];
        const cell = control.cellOf(take.key);
        if (cell !== null)
            control.scrollCellIntoView(cell, pos === "start");
    }

    function scrollCellIntoView(cell, toStart) {
        const scroller = control.findScroller();
        if (scroller === null)
            return;
        const target = cell.x - (toStart ? 0 : Math.max(0, scroller.width - cell.width));
        scroller.contentX = Math.max(0, target);
    }

    function findScroller() {
        if (control.barBox === null)
            return null;
        const inner = control.findNamed(control.barBox, "tabsOverflowInner");
        if (inner === null || inner.scrollViewport === undefined)
            return null;
        return inner.scrollViewport;
    }

    function findNamed(node, name) {
        if (node === null || node === undefined)
            return null;
        if (node.objectName === name)
            return node;
        const kids = node.children;
        if (kids === undefined)
            return null;
        for (let i = 0; i < kids.length; ++i) {
            const hit = control.findNamed(kids[i], name);
            if (hit !== null)
                return hit;
        }
        return null;
    }

    function overflowItems() {
        const out = [];
        for (let i = 0; i < control.count; ++i) {
            const it = control.items[i];
            out.push({
                key: it.itemKey,
                label: it.label,
                icon: it.icon,
                disabled: it.disabled,
                closable: it.closable,
                active: it.itemKey === control.currentKey
            });
        }
        return out;
    }

    /// 折叠档要把「这一格是不是末格」交给 OverflowList 里那份模型，
    /// 而 more / 普通档走 barModel()：切掉尾巴那几项
    function barModel() {
        const out = [];
        const total = control.count;
        const keep = control.moreOn ? total - Math.min(control.moreCount, total) : total;
        for (let i = 0; i < keep; ++i) {
            const it = control.items[i];
            out.push({
                itemKey: it.itemKey,
                label: it.label,
                icon: it.icon,
                disabled: it.disabled,
                closable: it.closable,
                at: i,
                last: i === total - 1
            });
        }
        return out;
    }

    function moreTriggerNode() {
        if (control.more !== null && typeof control.more === "object"
            && control.more.render !== undefined && control.more.render !== null)
            return control.more.render;
        return control.moreTriggerDefault;
    }

    /// 「更多」触发器：文字 + 14px 下箭头，内边距按 type 走 line 16/4/14/4、card 与 button
    /// 8/12，**slash 那一档上游没有规则**（CSS:21892-21900）
    property Component moreTriggerDefault: Component {
        Item {
            id: moreBox

            objectName: "tabsMoreTriggerNode"

            implicitWidth: moreRow.implicitWidth
            implicitHeight: control.itemHeight

            Row {
                id: moreRow

                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "更多"
                    height: 20
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron_down"
                    size: 14
                    color: Theme.current.colorText2
                }
            }

            // TabBar.tsx:393-409：hover 触发、showTick、bottomLeft，条目点击走同一条 onTabClick
            Dropdown {
                id: moreDropdown

                objectName: "tabsMoreDropdown"

                target: moreBox
                position: Enums.BottomLeft
                trigger: "hover"
                showTick: true
                menu: control.moreMenuStore
            }
        }
    }

    /// 收进「更多」的那几项（官方 list.slice(keepCount)）。
    /// 走「命令式重建一张普通数组」而不是属性绑定：那份数组里带着 `active`（读 currentKey）与
    /// `onClicked` 闭包（写 currentKey），放进 Dropdown 的 menu 绑定里会在它内部量宽那一轮被判成绑定环。
    property var moreMenuStore: []

    function rebuildMoreMenu() {
        // 延到本轮绑定算完之后：moreMenu() 要读 currentKey（画 active），而这份表又被
        // Dropdown 读去量宽 —— 同步写会在同一轮里形成 refresh → menu → 量宽 → refresh 的环
        Qt.callLater(control.commitMoreMenu);
    }

    function commitMoreMenu() {
        control.moreMenuStore = control.moreMenu();
    }

    function moreMenu() {
        const out = [];
        const keep = control.count - Math.min(control.moreCount, control.count);
        for (let i = keep; i < control.count; ++i) {
            const it = control.items[i];
            const key = it.itemKey;
            out.push({
                node: "item",
                name: it.label,
                icon: it.icon,
                active: key === control.currentKey,
                // Dropdown 读的是 entry.onClick()（src/Dropdown.qml:424）⇒ 这里给的是闭包；
                // 写成 `onClick: control.handleClick(key)` 会在这张表建起来的那一刻把每项都点一遍
                onClick: function () { control.handleClick(key); }
            });
        }
        return out;
    }
}
