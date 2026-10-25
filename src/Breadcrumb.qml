pragma ComponentBehavior: Bound

import QtQuick

// 面包屑。规格照 packages/semi-ui/breadcrumb/{index.tsx,item.tsx,bread-context.tsx}
// + semi-foundation/breadcrumb/{foundation.ts,constants.ts,breadcrumb.scss,variables.scss}，
// 数值逐条对编译后的 packages/semi-ui/dist/css/semi.css（`.semi-breadcrumb*`）。
//
// 官方 BreadcrumbProps（index.tsx:28-45）与缺省值（:84-98）：
//   routes / onClick / separator('/') / compact(true) / renderItem / showTooltip
//   ({ width: 150, ellipsisPos: 'end' }) / maxItemCount(4) / autoCollapse(true) / renderMore /
//   moreType('default') / activeIndex / aria-label('Breadcrumb') / className / style
//
// 两档数据来源（renderList :216-269）：`routes` 非空时**整条 children 都不读**；
// 否则把声明式子项当 items。两档共用同一套折叠与选中规则：
//   · `active` = 给了 activeIndex 就按它，否则按「最后一项」；
//   · `shouldCollapse` = autoCollapse && 条数 > maxItemCount && 还没展开过；
//   · 折叠时留第 0 项 + 省略号格 + 末尾 maxItemCount-1 项，中间那些**不渲染**
//     （`template.splice(1, n - maxItemCount, spread)`，foundation :188）；
//   · 点省略号格（或按 Enter）⇒ 展开，且**没有再收回去的口子**（官方只有 setState）。
//
// 端口与官方的差异（逐条）：
//   · 官方 `Breadcrumb.Item` 是 `static Item`；QML 没有静态成员 ⇒ 拆成独立类型
//     `BreadcrumbItem`，用法 `Breadcrumb { BreadcrumbItem { label: "…" } }`。
//   · 官方 `onClick(item, event)` 的第二个参数是 React 事件对象；端口只给第一参数。
//   · 官方 `renderMore(restItem)` 拿到的是「被折掉那几节的 ReactNode 数组」；端口给的是
//     那几节的 item 信息数组（`[{ name, href?, … }]`），Component 根项上另注一份 `restItems`。
//   · `className` / `style` 与全站同一口径：收了不产出可见差异（Qt 没有 class 与内联样式）。
//   · `aria-label` ⇒ `Accessible.name`；省略号格上那对 `role="button" tabIndex=0` +
//     `aria-label="Expand breadcrumb items"` 端口用 HoverHandler/TapHandler + Keys 处理 Enter，
//     `aria-current="page"` 在 Qt 侧没有等价物。
//   · 官方外层是 `<nav>` + `display:flex; flex-wrap:wrap`；端口是 Item 自己排，
//     换行规则按「放不下就整格挪到下一行」复刻 flex-wrap。nav 是 block 级容器 ⇒ 可用宽就是
//     所在栏的宽；QML 这边 `width` 没赋值会回落到 `implicitWidth`（坑记录），所以
//     `implicitWidth` 钉成「不换行需要的那条自然宽」，只有使用方真的给了**更窄**的宽才换行，
//     免得 width ← implicitWidth ← 排布 成环。
//   · **官方那条 `.semi-breadcrumb { overflow: hidden }` 是死规则**：nav 上的类名是
//     `-breadcrumb-wrapper`，裸 `-breadcrumb` 谁都没挂 ⇒ 端口不照抄那个裁剪。
//   · **`-item-link:hover` 排在 `-item-active:hover` 之后**（特异度相同）⇒ 没给 `noLink` 的
//     选中项一 hover 照样变链接色，scss 里那组「选中激活仍是 text-0」的写法被盖掉了。端口按
//     实际生效的结果做（见 src/BreadcrumbItem.qml 的 titleColor）。
//   · 官网「自定义的分隔符」那节给 `<Breadcrumb size="small" />` 传了 `size`，但
//     BreadcrumbProps 里没有这条 prop（`size` 是 Typography/Tag 那套的），组件也从没读它 ⇒
//     端口不跟着造。
//   · 官网 API 表把 `showTooltip` 的缺省值写成 `{… opts: { autoAdjustOverflow: true,
//     position: "bottomLeft" }}`，而 item.tsx:106-113 那份 defaultOpts 的 position 是 `'top'`
//     ⇒ 表是旧的。端口按代码走（缺省 'top'）。
//   · `showTooltip: false` 官方**不是**「不截断」：getTooltipOpt 那早退分支仍然给
//     `{ width: 150, ellipsisPos: 'end' }`，只是没有 `opts` ⇒ 截断照旧、不弹 Tooltip。
//     要「不截断」得给 `{ width: 'auto' }`。
//   · `activeIndex` 官方判的是 `!== undefined`（null 也算给了）+ **严格相等** `activeIndex===idx`
//     ⇒ 传 null 或字符串 "1" 谁都配不上，一条都不会是当前页；端口照抄（见 refresh 里那三行）。
//   · `maxItemCount` 给 1 时官方那步 `template.splice(1, n - maxItemCount, spread)` 删的条数
//     从下标 1 起算，正好把**末条（当前页）也删掉** ⇒ 只剩「首条 + 省略号」。端口照抄。
//   · cloneElement 那条 `!(shouldCollapse && (hasRenderMore || popover) && inCollapseArea)`
//     只改 `shouldRenderSeparator` 标记，而那几条本来整条都不渲染 ⇒ 上游这段是个看不见的死分支，
//     端口保留同样的开关（标记层可断言，几何层无差异）。
Item {
    id: control

    // ---------------------------------------------------------------- 官方 BreadcrumbProps
    /// 官方 routes：Array<Route | string>
    property var routes: []
    /// 官方 separator（ReactNode）：字符串或 Component
    property var separator: "/"
    property bool compact: true
    /// 官方 showTooltip：boolean | { width, ellipsisPos, opts }
    property var showTooltip: ({ width: 150, ellipsisPos: "end" })
    property int maxItemCount: 4
    property bool autoCollapse: true
    property string moreType: "default"
    /// 官方 renderItem / renderMore：函数返回节点（端口是 (route) => Component）
    property var renderItem: null
    property var renderMore: null
    /// 官方 activeIndex：未给（undefined）才按「最后一项」
    property var activeIndex: undefined
    property string ariaLabel: "Breadcrumb"
    property string className: ""
    property var style: undefined

    /// 官方 onClick(item, event)：条目被点时发（条目自己的 handler 先，这条后）
    signal clicked(var item)

    // ---------------------------------------------------------------- 缺省值与 context
    readonly property real gap: Theme.current.spacingExtraTight      // 4
    readonly property real restGap: Theme.current.spacingTight       // -restItem { margin-right: 8 }
    readonly property real moreIconSize: Theme.current.widthIconMedium   // .semi-icon { font-size: 16px }
    readonly property real fontSize: control.compact
        ? Theme.current.fontSizeSmall : Theme.current.fontSizeRegular    // 12 / 14
    readonly property real lineHeight: control.compact ? 16 : 20
    readonly property string separatorText: typeof control.separator === "string"
        ? String(control.separator) : ""
    readonly property bool separatorIsNode: control.separator !== undefined
        && control.separator !== null && typeof control.separator !== "string"
    readonly property bool hasRenderMore: control.renderMore !== null
        && control.renderMore !== undefined
    readonly property bool moreIsPopover: control.moreType === "popover"

    /// 官方 getTooltipOpt（item.tsx:98-118）：假值也保留 width/ellipsisPos，只丢 opts；
    /// 给了对象是 lodash merge ⇒ opts 里的键与缺省 opts 逐键合，不是整块替换
    readonly property var tooltipOpt: {
        const st = control.showTooltip;
        if (!st)
            return ({ width: 150, ellipsisPos: "end", opts: undefined });
        const given = typeof st === "object" ? st : {};
        const out = { width: given.width === undefined ? 150 : given.width,
            ellipsisPos: given.ellipsisPos === undefined ? "end" : given.ellipsisPos };
        const base = { autoAdjustOverflow: true, position: "top" };
        const opts = given.opts;
        if (opts === undefined || opts === null)
            out.opts = base;
        else {
            const merged = {};
            for (const k in base)
                merged[k] = base[k];
            for (const k in opts)
                merged[k] = opts[k];
            out.opts = merged;
        }
        return out;
    }

    function give(item, name, value) {
        if (item !== null && item !== undefined && name in item)
            item[name] = value;
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

    /// 标签里的 Component 档、宿主换数据都会改格子宽 ⇒ 回敲重排
    function itemNaturalChanged() {
        control.relayout();
    }

    // ---------------------------------------------------------------- 名单
    /// 官方 `hasRoutes = routes && routes.length > 0`
    readonly property bool useRoutes: control.routes !== undefined && control.routes !== null
        && control.routes.length > 0
    /// 官方 state.isCollapsed（初值 true）
    property bool collapsed: true
    /// 官方 genRoutes（foundation.ts:32-46）：字符串也摊成 { name, _origin }
    readonly property var routeItems: control.buildRouteItems()

    function buildRouteItems() {
        const out = [];
        if (!control.useRoutes)
            return out;
        for (let i = 0; i < control.routes.length; ++i) {
            const r = control.routes[i];
            if (r === undefined || r === null || typeof r !== "object") {
                out.push({ name: r, _origin: { name: r } });
                continue;
            }
            const wrap = {};
            for (const k in r)
                wrap[k] = r[k];
            wrap._origin = r;
            out.push(wrap);
        }
        return out;
    }

    /// 声明式子项（按 data 里的出现顺序；`data` 才数得到不可见的那些）
    function declaredItems() {
        const out = [];
        for (let i = 0; i < control.data.length; ++i) {
            const k = control.data[i];
            if (k === undefined || k === null || k.isBreadcrumbItem !== true)
                continue;
            if (k.fromRepeater === true)
                continue;
            out.push(k);
        }
        return out;
    }

    /// 这一档实际参与排布的条目（routes 非空时子项整条不读，也不收养）
    function activeItems() {
        if (control.useRoutes) {
            const out = [];
            for (let i = 0; i < control.routeItems.length; ++i)
                out.push(routeRepeater.itemAt(i));
            return out;
        }
        return control.declaredItems();
    }

    // ---------------------------------------------------------------- 折叠
    readonly property bool shouldCollapse: control.autoCollapse
        && control.itemCount > control.maxItemCount && control.collapsed
    /// 被折掉的条数（官方 restItemLength = items.length - maxItemCount）
    readonly property int restItemLength: control.itemCount - control.maxItemCount
    /// 下面两条由 refresh() 写：`data` 不是可绑定属性（读它的绑定不会跟着子项增删重算，
    /// qmllint 也会报 depends on non-bindable properties），所以名单类的一律命令式更新
    property int itemCount: 0
    /// 被折掉的那几节（给 renderMore / popover 用）
    property var restList: []

    /// 折叠判据与折掉条数：Changed 处理器与绑定同周期时下游绑定还没重算，
    /// 所以命令式路径里现算，不读上面那两条派生绑定（同 src/Descriptions.qml relayout 的注释）
    function collapseNow(n) {
        return control.autoCollapse && n > control.maxItemCount && control.collapsed;
    }

    /// 官方 handleCollapse 里给 renderMore / popover 的那份「被折掉的节点」
    function restItems() {
        const out = [];
        const items = control.activeItems();
        const rest = items.length - control.maxItemCount;
        if (!control.collapseNow(items.length))
            return out;
        for (let i = 1; i <= rest; ++i) {
            const it = items[i];
            if (it === null || it === undefined)
                continue;
            out.push({ label: it.label, icon: it.icon, route: it.route, href: it.href,
                noLink: it.noLink, info: it.itemInfo });
        }
        return out;
    }

    /// 排布名单：格 = 一条条目，或者省略号格
    function cellList() {
        const items = control.activeItems();
        const out = [];
        if (items.length === 0)
            return out;
        const rest = items.length - control.maxItemCount;
        if (!control.collapseNow(items.length)) {
            for (let i = 0; i < items.length; ++i)
                if (items[i] !== null)
                    out.push(items[i]);
            return out;
        }
        if (items[0] !== null)
            out.push(items[0]);
        out.push(moreBox);
        // 官方 splice(1, n - maxItemCount, spread) ⇒ 留末尾 maxItemCount - 1 条
        for (let i = rest + 1; i < items.length; ++i)
            if (items[i] !== null)
                out.push(items[i]);
        return out;
    }

    /// 收养 + 写 active / shouldRenderSeparator / visible（官方 cloneElement 那一步）
    function refresh() {
        const items = control.activeItems();
        const n = items.length;
        const rest = n - control.maxItemCount;
        const collapse = control.collapseNow(n);
        // 官方 :222/:257 只认 `!== undefined`，且比的是严格相等 ⇒ 给 null 谁都不选中；
        // 这里也必须现算：Changed 处理器跑在 activeGiven 那类下游绑定重算之前
        const given = control.activeIndex !== undefined;
        control.itemCount = n;
        control.restList = control.restItems();
        const hideInCollapse = collapse && (control.hasRenderMore || control.moreIsPopover);
        for (let i = 0; i < n; ++i) {
            const it = items[i];
            if (it === null || it === undefined)
                continue;
            it.host = control;
            it.active = given ? control.activeIndex === i : i === n - 1;
            it.shouldRenderSeparator = i !== n - 1
                && !(hideInCollapse && i > 0 && i <= rest);
            it.visible = !collapse || i === 0 || i > rest;
        }
        // routes 档不读子项：声明式的那些整批让位（官方 items 直接换源）
        if (control.useRoutes) {
            const declared = control.declaredItems();
            for (let i = 0; i < declared.length; ++i) {
                declared[i].host = null;
                declared[i].visible = false;
            }
        }
        control.relayout();
    }

    // ---------------------------------------------------------------- 排布（flex-wrap）
    /// 不换行时整排需要的宽（每格已含 `-item-wrap { margin-right: 4 }`）。
    /// 必须**不依赖 width**：QML 的 Item.width 在没赋值时回落到 implicitWidth，
    /// 而排布又要读 width 判换行 ⇒ 让 implicitWidth 吃「换行后的行宽」就成环，
    /// 第一趟（width 还是 0）还会把每一格都顶到单独一行。
    property real naturalWidth: 0
    property real rowsHeight: 0

    function relayout() {
        const cells = control.cellList();
        let sum = 0;
        for (let i = 0; i < cells.length; ++i)
            sum += cells[i].implicitWidth;
        control.naturalWidth = sum;
        // 官方 nav 是 block 级 flex 容器 ⇒ 换行线宽就是所在栏的宽。端口只在「使用方真的给了
        // 一条更窄的宽」时换行；width 没给（回落到 naturalWidth）时整排铺开，与 shrink-to-fit 一致
        const total = control.width > 0 && control.width < sum ? control.width : Number.MAX_VALUE;
        let x = 0;
        let y = 0;
        let lineH = 0;
        for (let i = 0; i < cells.length; ++i) {
            const c = cells[i];
            c.cellIndex = i;
            const w = c.implicitWidth;
            const h = c.implicitHeight;
            // 首格不需要额外判据：x 还是 0，「换行」也就是把它留在 (0,0)
            if (x + w > total) {
                x = 0;
                y += lineH;
                lineH = 0;
            }
            c.x = x;
            c.y = y;
            x += w;
            lineH = Math.max(lineH, h);
        }
        control.rowsHeight = y + lineH;
    }

    implicitWidth: control.naturalWidth
    implicitHeight: control.rowsHeight
    Accessible.name: control.ariaLabel

    onWidthChanged: control.relayout()
    onRoutesChanged: control.refresh()
    onCompactChanged: control.refresh()
    onSeparatorChanged: control.refresh()
    onShowTooltipChanged: control.refresh()
    onMaxItemCountChanged: control.refresh()
    onAutoCollapseChanged: control.refresh()
    onMoreTypeChanged: control.refresh()
    onRenderItemChanged: control.refresh()
    onRenderMoreChanged: control.refresh()
    onActiveIndexChanged: control.refresh()
    onCollapsedChanged: control.refresh()
    onChildrenChanged: control.refresh()

    Component.onCompleted: control.refresh()

    // routes 档的条目由这里造；子项档用声明式的那些
    Repeater {
        id: routeRepeater

        model: control.routeItems

        delegate: BreadcrumbItem {
            id: routeItem

            required property var modelData
            required property int index

            objectName: "bcRouteItem" + index
            fromRepeater: true
            route: modelData._origin
            label: control.renderItem !== null && control.renderItem !== undefined
                && typeof control.renderItem === "function"
                ? control.renderItem(modelData._origin) : modelData.name
            icon: modelData.icon === undefined ? null : modelData.icon
            href: modelData.href === undefined || modelData.href === null ? "" : String(modelData.href)
            separator: modelData.separator
            noLink: modelData.noLink === true
        }
    }

    // 条目被点 ⇒ 往宿主冒泡（官方 notifyClick 之后 notifyParent；条目自己那份在
    // BreadcrumbItem 的 TapHandler 里先跑，包括 routes 档摊进来的 route.onClick）
    function itemClicked(info) {
        control.clicked(info);
    }

    // ---------------------------------------------------------------- 省略号格
    // 官方 handleCollapse :167-187：-collapse > -item-wrap > (-item -item-more) + (-separator)
    BreadcrumbMore {
        id: moreBox

        objectName: "bcMoreWrap"
        host: control
        visible: control.shouldCollapse
        restItems: control.restList

        onExpandRequested: control.collapsed = false
    }
}
