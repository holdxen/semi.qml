import QtQuick

// 下拉菜单。官方 `packages/semi-ui/dropdown/index.tsx` 的 render（:211-270）自己一行弹层逻辑
// 都不写 —— 把菜单包成 `.semi-dropdown` + `.semi-dropdown-content` 两层 div 当 content，
// 再连 trigger / position / motion / margin / zIndex 一起转交 **Tooltip**，只钉死
// `showArrow: false` 与 `returnFocusOnClose: true`。所以这里和 Popover 一样以 Tooltip 为根：
// 五档触发、十二档方位、两个 delay、点外判定、Esc、进出场全部继承，本文件只写
// 「Dropdown 这一档改了哪些缺省值、多了哪几条 prop、菜单那一层怎么排、键盘怎么走」。
//
//     Button { id: btn; text: "更多操作" }
//     Dropdown {
//         target: btn
//         DropdownItem { text: "编辑"; icon: "edit" }
//         DropdownItem { text: "复制" }
//         DropdownDivider {}
//         DropdownItem { text: "删除"; type: "danger" }
//     }
//
//     // 官方 menu 那一档（JSON 数组），与声明式子项二选一
//     Dropdown {
//         target: btn
//         menu: [
//             { node: "title", name: "文件" },
//             { node: "item", name: "新建" },
//             { node: "divider" },
//             { node: "item", name: "删除", type: "danger" }
//         ]
//     }
//
// ------------------------------------------------------------------ 与 Tooltip 的缺省差
// 逐条对着 index.tsx:105-116 的 defaultProps 与 :236-252 转交的那一坨：
//   · `position` **bottom**（tooltip 是 top）、`zIndex` **1050**（tooltip 1060 —— Dropdown 的
//     defaultProps 写的是 tooltipNumbers.DEFAULT_Z_INDEX，那个常量是 1050）、
//     `mouseLeaveDelay` **100**（tooltip 50；`mouseEnterDelay` 没进 defaultProps ⇒ 沿用 50）、
//     `closeOnEsc` **true**（tooltip false）、`trigger` hover、`motion` true、
//     `autoAdjustOverflow` true、`margin` 0、`showTick` false。
//   · `spacing` 不在 defaultProps 里，由 render 现算（:230-234）：**外层 4，嵌套进第二层起变 2**
//     （`level > 0` 时只有 number 档才沿用，否则吃 NESTED_SPACING）。
//   · `showArrow` 恒 false（:248 写死，不给使用方改）、`returnFocusOnClose` 恒 true（:249）。
//   · `disableFocusListener` Dropdown 不碰 ⇒ 沿用 tooltip 的 false（与 Popover 相反）。
//   · `.semi-dropdown` 没有 max-width（那条 280 写在**条目**上），所以 tooltip 的 240 上限摘掉。
//
// ------------------------------------------------------------------ 皮肤（dropdown.scss）
//   `.semi-dropdown-wrapper`：底色 bg-3、圆角 radius-medium、**@mixin shadow-elevated**、
//   `overflow-y: auto`；字号继承 `.semi-dropdown` 的 14 / 行高 20。那条 1px 环与 Popover 同源
//   （阴影第一层），由 strokeColor 顶替（坑 34）。
//   `.semi-dropdown-menu`：`padding: 4px 0`（上下 extra-tight、左右 0）⇒ 卡片纵向多 8、横向多 0；
//   条目之间**没有间距** —— 基座那个 `contentSpacing` 缺省 8，必须关掉，否则每条之间多一道 8。
//
// ------------------------------------------------------------------ 键盘（foundation.ts + menuFoundation.ts）
//   trigger 那半（Dropdown.foundation.handleKeyDown :43-59）：Enter / Space ⇒ `event.target.click()`、
//   ArrowDown ⇒ 焦点进第一项、ArrowUp ⇒ 进最后一项，且**只有层已经开着时方向键才 preventDefault**。
//   菜单那半（menuFoundation.onMenuKeydown）：ArrowUp / ArrowDown 在**可用项之间**跳（`ariaDisabled
//   !== "true"` 那条过滤 ⇒ 禁用项、标题、分隔线都不在名单里）、Enter / Space ⇒ 点当前项、
//   Escape ⇒ custom 档把焦点送回 trigger、可打印字符 ⇒ 跳到首字母相同的那一项。
//   三条上游口径照抄：① trigger 上 Enter/Space 官方是「再点一次 target」，本库 Button 自己就
//   响应 Enter/Space ⇒ 端口不重复注入（否则一次按键两下）；② `menuItemNodes` 与 `firstChars`
//   都是「第一次算完就缓存」，端口对应「每次打开重算一次」；③ `firstChars` 用
//   `textContent.trim()[0]?.toLowerCase()` —— 空文本那一项会 push `undefined`，端口照抄。
Tooltip {
    id: control

    // ---------------------------------------------------------------- DropdownProps 自有
    /// 官方 menu：[{ node: 'item' | 'title' | 'divider', name, ...条目 props }]
    property var menu: undefined
    /// 官方 showTick：整份菜单的对勾档（条目自己那条在 Dropdown 里不生效，见 DropdownItem 头注释）
    property bool showTick: false

    readonly property bool isDropdownHost: true
    /// 官方 context 的 level：外层还套着 Dropdown 就是那一层的 level + 1（外层是 0 ⇒ 自己是 1）。
    /// 外层的认法是「我的 target 属于谁的菜单」—— 嵌套那一档内层的 trigger 就是外层的条目，
    /// 而条目被外层收养时写进了 `dropdownHost`，所以这条链是通的（自己往上走 parent 走不到，
    /// Popup 不是 Item）。
    // 层级是**命令式**算的，不是绑定：`target` 的静态类型是 Item，`dropdownHost` 只在
    // DropdownItem 上，那一跳动态取值不登记依赖（写成绑定实测永远停在 1）；给 target 挂
    // Connections 收 dropdownHostChanged 又会在使用方 target 是普通 Rectangle / Button 时打
    // "no signal of the target matches the name"。所以改成「收养完成之后、每次 refreshItems
    // 重算一遍」—— 打开那一拍必然重算，而 spacing 只在定位时用得着。
    property int ctxLevel: 1

    function _outerLevel() {
        const t = control.target;
        if (t === null || t === undefined)
            return 0;
        // qmllint disable missing-property
        const h = t.dropdownHost;
        // qmllint enable missing-property
        return h === undefined || h === null ? 0 : h.ctxLevel;
    }

    // ---------------------------------------------------------------- 覆盖 Tooltip 的缺省值
    position: Enums.Bottom
    zIndex: 1050
    mouseLeaveDelay: 100
    closeOnEsc: true
    showArrow: false
    maxWidth: Number.MAX_VALUE
    // 官方 .semi-dropdown-menu 的 padding 是「上下 4、左右 0」，基座那一只 padding 是四边同值
    padding: 0
    topPadding: 4
    bottomPadding: 4
    leftPadding: 0
    rightPadding: 0
    contentSpacing: 0
    // 官方 spacing：外层 4、嵌套档 2（numbers.SPACING / numbers.NESTED_SPACING）
    spacing: control.ctxLevel > 1 ? 2 : 4

    fillColor: Theme.current.colorBg3
    strokeColor: Theme.current.colorBorder
    radius: Theme.current.radiusMedium
    shadowEnabled: true

    // 卡片 = 菜单自然宽（条目自己已经含左右内边距与 280 上限）与字符串档 label 取大。
    // **不用基座的 bodyWidth / bodyHeight**：位置器的隐式尺寸吃的是子项的**实际**宽高，
    // 而条目又是 `width: parent.width` ⇒ 卡片宽 ← 列隐式宽 ← 条目实际宽 ← 卡片宽，成环之后
    // 这一路全塌 0（实测卡片 0×8）。改成自己走一遍子项、只读它们的 implicitWidth 与 height。
    implicitWidth: Math.max(control.labelWidth, control.menuNaturalWidth)
    implicitHeight: Math.max(control.labelHeight, control.menuNaturalHeight + 8)

    property real menuNaturalWidth: 0
    property real menuNaturalHeight: 0

    // ---------------------------------------------------------------- menu JSON 档
    readonly property bool menuIsArray: Array.isArray(control.menu)
    // 官方 :150-154 是「render 是元素就用 render，否则 Array.isArray(menu) 才走 menu」——
    // 端口的「render 档」就是声明式子项，所以子项优先：有子项就不看 menu。
    // 数的是 `contentItem.data` 里使用方声明的那几件（Repeater 自己也在 data 里，Qt 6.11 起
    // QQuickRepeater : public QQuickItem ⇒ 必须按名字摘掉），**不能数 children**：menu 生成的
    // 那几件也是 children，数它们会自己把自己关掉。
    readonly property int declaredItemCount: control._countDeclared()
    readonly property var menuModel: control.menuIsArray && control.declaredItemCount === 0
        ? control.menu : []

    // 只数 contentItem 的**直属**子项里带标记的那几件 —— 使用方声明的那三件就是直属子项，
    // 而 menu 生成的挂在 Loader 下面（Loader 自己是直属子项，但它没有这些标记）。
    // 不能数 `content`（那是 contentItem.data，里面还挂着 Tooltip 自己的十来件）。
    function _countDeclared() {
        const kids = control.contentItem.children;
        let n = 0;
        for (let i = 0; i < kids.length; ++i) {
            const k = kids[i];
            // qmllint disable missing-property
            if (k.isDropdownItem === true || k.isDropdownTitle === true
                || k.isDropdownDivider === true)
                ++n;
            // qmllint enable missing-property
        }
        return n;
    }

    // ---------------------------------------------------------------- 键盘导航的名单
    // 官方过滤口径：`<li>` 且 `ariaDisabled !== "true"` ⇒ 禁用项与标题、分隔线都不在名单里
    property var focusableItems: []
    /// 官方 firstChars：`textContent.trim()[0]?.toLowerCase()`，只算一次就缓存
    property var firstChars: []

    /// 一次遍历把「键盘名单」与「卡片自然宽高」都算出来。触发点：子项增减、以及打开那一拍。
    function refreshItems() {
        control.ctxLevel = control._outerLevel() + 1;
        const rows = [];
        control._collectRows(control.contentItem, rows);
        let w = 0;
        let h = 0;
        for (let i = 0; i < rows.length; ++i) {
            const r = rows[i];
            if (r.implicitWidth > w)
                w = r.implicitWidth;
            h += r.height;
        }
        control.menuNaturalWidth = w;
        control.menuNaturalHeight = h;

        // 反向收养：条目的 parent 链走不到 Popup 那一层，只能由宿主把自已写进去
        for (let i = 0; i < rows.length; ++i) {
            // qmllint disable missing-property
            if (rows[i].dropdownHost !== undefined)
                rows[i].dropdownHost = control;
            // qmllint enable missing-property
        }

        // 不排序：`contentItem.children` 本来就是视觉序（位置器按同一份序排），
        // 变异扫描里把 sort 摘掉一条都不红 ⇒ 按「摘掉看不红就删」的口径不排。
        const list = [];
        control._collectItems(control.contentItem, list);
        control.focusableItems = list;
        const chars = [];
        for (let i = 0; i < list.length; ++i) {
            const t = String(list[i].text).trim();
            chars.push(t.length > 0 ? t[0].toLowerCase() : undefined);
        }
        control.firstChars = chars;
    }

    /// 收所有参与排布的行（条目 / 标题 / 分隔线，含 Loader 里生成的）
    function _collectRows(node, out) {
        const kids = node.children;
        for (let i = 0; i < kids.length; ++i) {
            const k = kids[i];
            // qmllint disable missing-property
            if (k.isDropdownHost === true)
                continue;
            if (k.isDropdownItem === true || k.isDropdownTitle === true
                || k.isDropdownDivider === true) {
                out.push(k);
            } else if (k.item !== undefined && k.item !== null) {
                control._collectRows(k, out);
            } else {
                control._collectRows(k, out);
            }
            // qmllint enable missing-property
        }
    }

    // 递归收：menu 那一档是 Repeater + Loader，条目挂在 Loader 下面而不是 contentItem 下面。
    // 遇到另一只 Dropdown（嵌套菜单）就停 —— 官方那边它被 portal 到 body、天然不在这份名单里。
    function _collectItems(node, out) {
        const kids = node.children;
        for (let i = 0; i < kids.length; ++i) {
            const k = kids[i];
            // qmllint disable missing-property
            if (k.isDropdownHost === true)
                continue;
            if (k.isDropdownItem === true) {
                if (k.disabled !== true)
                    out.push(k);
            } else if (k.item !== undefined && k.item !== null) {
                control._collectItems(k, out);          // Loader：往它载出来的那件里走
            } else {
                control._collectItems(k, out);          // 别的容器（再包一层）
            }
            // qmllint enable missing-property
        }
    }

    function focusItemAt(index) {
        const list = control.focusableItems;
        if (list.length === 0 || index < 0 || index >= list.length)
            return false;
        list[index].forceActiveFocus();
        return true;
    }

    function focusedIndex() {
        const list = control.focusableItems;
        for (let i = 0; i < list.length; ++i)
            if (list[i].activeFocus)
                return i;
        return -1;
    }

    /// 官方 setFocusToFirstItem / setFocusToLastItem
    function focusFirstItem() { control.refreshItems(); control.focusItemAt(0); }
    function focusLastItem() { control.refreshItems(); control.focusItemAt(control.focusableItems.length - 1); }

    /// 官方 setFocusToNextMenuitem / setFocusToPreviousMenuItem（走到两端就停，不循环）
    function focusNextItem() {
        control.refreshItems();
        const at = control.focusedIndex();
        control.focusItemAt(at < 0 ? 0 : at + 1);
    }
    function focusPreviousItem() {
        control.refreshItems();
        const at = control.focusedIndex();
        control.focusItemAt(at < 0 ? control.focusableItems.length - 1 : at - 1);
    }

    /// 官方 setFocusByFirstCharacter：findIndexByCharacter 从当前项往后找，找不到就不动
    function focusItemByChar(ch) {
        control.refreshItems();
        const needle = String(ch).toLowerCase();
        const start = control.focusedIndex();
        const n = control.firstChars.length;
        for (let step = 1; step <= n; ++step) {
            const i = (start + step + n) % n;
            if (control.firstChars[i] === needle) {
                control.focusItemAt(i);
                return;
            }
        }
    }

    /// 菜单那半：焦点在条目上时由条目把事件转过来（官方挂在 `<ul>` 上靠冒泡）
    function handleItemKey(event) {
        switch (event.key) {
        case Qt.Key_Enter:
        case Qt.Key_Return:
        case Qt.Key_Space:
            // 官方 event.target.click()，且注释明说「不 stopPropagation」
            control.activateFocused();
            return;
        case Qt.Key_Escape:
            // 官方 handleEscape：只有 custom 档把焦点送回 trigger（关层那一步走 closeOnEsc 那条路）
            if (control.trigger === "custom" && control.target)
                control.target.forceActiveFocus();
            return;
        case Qt.Key_Up:
            control.focusPreviousItem();
            event.accepted = true;
            return;
        case Qt.Key_Down:
            control.focusNextItem();
            event.accepted = true;
            return;
        default:
            if (control.isPrintableKey(event.key, event.text)) {
                // 官方这条不 preventDefault（注释：别影响条目里放的 input）
                control.focusItemByChar(event.text);
            }
            return;
        }
    }

    function activateFocused() {
        const at = control.focusedIndex();
        if (at < 0)
            return;
        const item = control.focusableItems[at];
        // qmllint disable missing-property
        if (item.clicked !== undefined)
            item.clicked();
        // qmllint enable missing-property
    }

    /// 官方 utils/a11y 的 isPrintableCharacter：长度为 1 的可打印字符
    function isPrintableKey(key, text) {
        return text !== undefined && text.length === 1 && key !== Qt.Key_Control
            && key !== Qt.Key_Shift && key !== Qt.Key_Alt && key !== Qt.Key_Meta
            && key !== Qt.Key_Tab && key !== Qt.Key_Backtab;
    }

    // trigger 那半的方向键：层开着才吞事件（官方 `visible && handlePrevent(event)`）。
    // 用 Shortcut 而不是 Keys —— 焦点在 target 上，而 Keys 处理器只能写在被聚焦那件自己的
    // 声明里；Shortcut 在 WindowContext 下能在外部接住，并用 target.activeFocus 把范围收窄。
    Shortcut {
        objectName: "dropdownTriggerDown"

        sequences: ["Down"]
        enabled: control.target !== null && control.target.activeFocus
        onActivated: {
            control.focusFirstItem();
            if (control.visible)
                control.refreshItems();
        }
    }

    Shortcut {
        objectName: "dropdownTriggerUp"

        sequences: ["Up"]
        enabled: control.target !== null && control.target.activeFocus
        onActivated: control.focusLastItem()
    }

    // 完成那一拍先收养一次：childrenChanged 可能在 Connections 建立之前就已经响过了
    // （子项是在组件创建期挂进 contentItem 的），只挂信号会漏掉这一批。
    Component.onCompleted: control.refreshItems()

    // 子项增减 ⇒ 重算名单与尺寸（`children` 不是可绑定属性，只能挂信号手动刷）
    Connections {
        target: control.contentItem

        function onChildrenChanged() { control.refreshItems(); }
    }

    // 官方 handleVisibleChange（foundation.ts:14-22）：先 setState + notify，
    // 然后**只有 click 档**在打开时把焦点送进第一项
    Connections {
        target: control

        function onVisibleChanged() {
            control.refreshItems();
            if (control.visible && control.trigger === "click")
                control.focusFirstItem();
        }
    }

    Repeater {
        objectName: "dropdownMenuRepeater"

        model: control.menuModel

        delegate: Loader {
            id: row

            required property var modelData
            required property int index

            // 官方 renderMenu（:166-193）按 node 分流，default 那一支返回 null
            // 那三个 Component 里一律走 `row.modelData` —— **不能给它们自己声明
            // `required property var modelData`**：required 只由 Repeater 往委托上注入，
            // 经 sourceComponent 这一路没人填，实例化会静默失败、Loader.item 留 null
            // （实测三条里只有不带这个声明的 divider 载了出来）。
            property var entry: row.modelData
            sourceComponent: row.componentFor(row.modelData)

            function componentFor(entry) {
                if (entry === undefined || entry === null)
                    return null;
                if (entry.node === "divider")
                    return dividerPart;
                if (entry.node === "title")
                    return titlePart;
                if (entry.node === "item")
                    return itemPart;
                return null;
            }

            // 三个 Component 里都要读委托的 `row.entry` —— 那是外层作用域的 id，静态检查按
            // 「未限定访问」报（同坑 35 那批委托里的引用），这一段整体豁免。
            // qmllint disable unqualified
            Component {
                id: itemPart

                DropdownItem {
                    text: row.entry !== undefined && row.entry.name !== undefined
                        ? String(row.entry.name) : ""
                    icon: row.entry !== undefined && row.entry.icon !== undefined
                        ? row.entry.icon : ""
                    disabled: row.entry !== undefined && row.entry.disabled === true
                    active: row.entry !== undefined && row.entry.active === true
                    type: row.entry !== undefined && row.entry.type !== undefined
                        ? String(row.entry.type) : ""
                    onClicked: {
                        if (row.entry !== undefined && row.entry.onClick !== undefined)
                            row.entry.onClick();
                    }
                }
            }

            Component {
                id: titlePart

                DropdownTitle {
                    text: row.entry !== undefined && row.entry.name !== undefined
                        ? String(row.entry.name) : ""
                }
            }

            Component {
                id: dividerPart

                DropdownDivider {}
            }
            // qmllint enable unqualified
        }
    }

}
