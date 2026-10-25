import QtQuick
import QtTest
import Semi

// Breadcrumb。规格照 packages/semi-ui/breadcrumb/{index.tsx,item.tsx,bread-context.tsx}
// + semi-foundation/breadcrumb/{foundation.ts,constants.ts,breadcrumb.scss,variables.scss}，
// 数值逐条对编译后的 packages/semi-ui/dist/css/semi.css（`.semi-breadcrumb*` 那一组）；
// 演示与 API 表照 content/navigation/breadcrumb/index.md 的 8 节。
//
// 端口口径都在 src/Breadcrumb.qml 文件头，这份用例盯的几条：
//   · 两档数据源：`routes` 非空时**声明式子项整条不读**（官方 items 直接换源）；
//   · 折叠数学：`autoCollapse && n > maxItemCount && 没展开过` ⇒ 留第 0 条 + 省略号格 +
//     末尾 maxItemCount-1 条（官方 `template.splice(1, n - maxItemCount, spread)`），
//     展开是单向的（官方只有 setState，没有收回去的口子）；
//   · `active` 给了 activeIndex 就按它、否则按最后一项；
//   · 三条颜色：未选中 text-2 / 选中 text-0 + 600 / 链接 hover colorLink、按下 colorLinkHover，
//     而 **-item-link:hover 排在 -item-active:hover 之后 ⇒ 没给 noLink 的选中项 hover 也变色**
//     （官方 scss 的意图不是这样，端口按实际生效的结果钉，见坑记录）；
//   · 截断只看字符串档：`showTooltip: false` 是「截断但不弹」，要「不截断」得给 width:'auto'。
//
// 跑法（本仓约定，优先 offscreen）：
//   QT_QPA_PLATFORM=offscreen ./cmake-build-debug/tests/tst_semi -input tests/tst_breadcrumb.qml
TestCase {
    id: testCase

    name: "Breadcrumb"
    when: windowShown
    width: 900
    height: 500

    // 节点档的标签、分隔符、renderMore 用的 Component：文件里声明好，测的时候从 JS 侧赋
    Component {
        id: nodeLabelComp

        Text {
            objectName: "nodeLabel"

            text: "节点标题"
            font.pixelSize: 12
        }
    }

    Component {
        id: longNodeComp

        Text {
            objectName: "longNode"

            text: "很长很长很长的节点标题不该被截断"
            font.pixelSize: 12
        }
    }

    Component {
        id: nodeSeparatorComp

        Rectangle {
            objectName: "nodeSeparator"

            width: 2
            height: 12
            color: "#ff0000"
        }
    }

    Component {
        id: moreComp

        Text {
            objectName: "moreNode"

            property var restItems

            text: "共" + (restItems === undefined ? "?" : restItems.length) + "项"
        }
    }

    property var clicks: []
    property var order: []

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
        testCase.clicks = [];
        testCase.order = [];
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
    }

    function cleanup() {
        Theme.reset();
        Theme.mode = Theme.Light;
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        const o = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "bc");
        wait(60);
        return o;
    }

    function part(owner, name) {
        const node = testCase.findChild(owner, name);
        verify(node !== null && node !== undefined, "找不到 " + name);
        return node;
    }

    // 浮层里的东西 findChild 摸不到（在另一棵树上），只能自己递归 children
    function deep(owner, name) {
        const kids = owner.children === undefined ? [] : owner.children;
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].objectName === name)
                return kids[i];
            const hit = deep(kids[i], name);
            if (hit !== null)
                return hit;
        }
        return null;
    }

    function deepPart(owner, name) {
        const node = deep(owner, name);
        verify(node !== null, "浮层里找不到 " + name);
        return node;
    }

    // QColor 与 "transparent" 字面量永远比不等，要比 alpha
    function clear(c) {
        return c.a === 0;
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 0.5,
            (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    function labels(bc) {
        const out = [];
        const cells = bc.cellList();
        for (let i = 0; i < cells.length; ++i)
            out.push(cells[i].objectName === "bcMoreWrap" ? "…" : String(cells[i].label));
        return out;
    }

    function titles(bc) {
        const out = [];
        const items = bc.activeItems();
        for (let i = 0; i < items.length; ++i)
            out.push(items[i] === null ? "null" : String(items[i].label));
        return out;
    }

    // ============================================================ 属性面与缺省值
    function test_propDefaults() {
        const bc = make("Breadcrumb { }")
        compare(bc.separator, "/");
        compare(bc.compact, true);
        compare(bc.maxItemCount, 4);
        compare(bc.autoCollapse, true);
        compare(bc.moreType, "default");
        compare(bc.ariaLabel, "Breadcrumb");
        compare(bc.collapsed, true, "官方 state.isCollapsed 初值 true");
        compare(bc.activeIndex, undefined);
        compare(bc.renderItem, null);
        compare(bc.renderMore, null);
        verify(bc.routes.length === 0);
        // showTooltip 的缺省是那个对象（不是 true）
        compare(bc.tooltipOpt.width, 150);
        compare(bc.tooltipOpt.ellipsisPos, "end");
        compare(bc.tooltipOpt.opts.position, "top");
        compare(bc.tooltipOpt.opts.autoAdjustOverflow, true);
        bc.destroy()
    }

    function test_showTooltipThreeShapes() {
        const bc = make("Breadcrumb { }")
        // 假值：width / ellipsisPos 还在，只丢 opts ⇒ 截断但不弹 Tooltip（item.tsx:100-105）
        bc.showTooltip = false
        compare(bc.tooltipOpt.width, 150);
        compare(bc.tooltipOpt.ellipsisPos, "end");
        compare(bc.tooltipOpt.opts, undefined);
        // true：吃整套缺省 opts
        bc.showTooltip = true
        compare(bc.tooltipOpt.opts.position, "top");
        // 对象：lodash merge ⇒ 只覆盖给的那个键
        bc.showTooltip = ({ opts: ({ position: "topLeft" }) })
        compare(bc.tooltipOpt.opts.position, "topLeft");
        compare(bc.tooltipOpt.opts.autoAdjustOverflow, true, "merge 不是整块替换");
        compare(bc.tooltipOpt.width, 150);
        // 只给 width
        bc.showTooltip = ({ width: 88, ellipsisPos: "middle" })
        compare(bc.tooltipOpt.width, 88);
        compare(bc.tooltipOpt.ellipsisPos, "middle");
        compare(bc.tooltipOpt.opts.position, "top");
        bc.destroy()
    }

    function test_fontSizeFollowsCompact() {
        const bc = make("Breadcrumb { }")
        compare(bc.fontSize, Theme.current.fontSizeSmall, "compact 缺省 ⇒ font-size-small 12");
        compare(bc.lineHeight, 16);
        compare(bc.moreIconSize, 16, "-collapse 里那枚 IconMore 不吃 compact（.semi-icon 恒 16）");
        bc.compact = false
        compare(bc.fontSize, Theme.current.fontSizeRegular);
        compare(bc.lineHeight, 20);
        bc.destroy()
    }

    // ============================================================ 两档数据源
    function test_childrenMode() {
        const bc = make("Breadcrumb { width: 600;"
            + " BreadcrumbItem { label: 'Semi-ui' } BreadcrumbItem { label: 'Breadcrumb' }"
            + " BreadcrumbItem { label: 'Default' } }")
        compare(bc.useRoutes, false);
        compare(bc.itemCount, 3);
        compare(bc.cellList().length, 3);
        const items = bc.activeItems();
        compare(items[0].active, false);
        compare(items[1].active, false);
        compare(items[2].active, true, "没给 activeIndex ⇒ 最后一项是当前页");
        compare(items[0].shouldRenderSeparator, true);
        compare(items[2].shouldRenderSeparator, false, "末项不带分隔符");
        // 标记之外那一格也得真的收掉（只看标记的话，格子上没接这条判据也照样绿）
        verify(part(items[2], "bcSeparatorBox").visible === false, "末项的分隔符格整个不画");
        verify(part(items[0], "bcSeparatorBox").visible, "非末项照画");
        compare(labels(bc), ["Semi-ui", "Breadcrumb", "Default"]);
        bc.destroy()
    }

    function test_routesModeStringAndObject() {
        const bc = make("Breadcrumb { width: 600; routes: ['a', 'b'] }")
        compare(bc.useRoutes, true);
        compare(titles(bc), ["a", "b"]);
        const items = bc.activeItems();
        compare(items[0].itemInfo.name, "a", "字符串也摊成 {name}");
        bc.routes = [{ name: "甲", path: "/a", href: "/a" }, { name: "乙" }]
        wait(40)
        const two = bc.activeItems();
        compare(two[0].label, "甲");
        compare(two[0].href, "/a", "Route 上的属性摊进条目");
        compare(two[0].itemInfo.path, "/a", "routes 档的回调载荷就是那条 route 本身");
        compare(two[1].href, "");
        bc.destroy()
    }

    function test_routesWinsOverChildren() {
        const bc = make("Breadcrumb { width: 600; routes: ['r1', 'r2'];"
            + " BreadcrumbItem { label: '子项一' } BreadcrumbItem { label: '子项二' } }")
        compare(bc.useRoutes, true);
        compare(bc.itemCount, 2);
        compare(labels(bc), ["r1", "r2"]);
        // 官方 items 直接换源 ⇒ 声明式的那两条整条不读：不显示、不收养
        const declared = bc.declaredItems();
        compare(declared.length, 2);
        compare(declared[0].visible, false);
        compare(declared[0].host, null);
        bc.destroy()
    }

    function test_emptyAndSingle() {
        const bc = make("Breadcrumb { width: 600 }")
        compare(bc.cellList().length, 0);
        near(bc.implicitHeight, 0);
        bc.routes = ["只有一条"]
        wait(40)
        const only = bc.activeItems()[0];
        compare(only.active, true, "单条时它就是末项");
        compare(only.shouldRenderSeparator, false);
        near(bc.implicitHeight, 24);
        bc.destroy()
    }

    // ============================================================ 折叠数学
    function test_collapseShape() {
        const bc = make("Breadcrumb { width: 600; routes: ['a','b','c','d','e','f','g'] }")
        compare(bc.restItemLength, 3);
        compare(bc.shouldCollapse, true);
        compare(bc.cellList().length, 5, "第 0 条 + 省略号 + 末尾三条");
        compare(labels(bc), ["a", "…", "e", "f", "g"]);
        const items = bc.activeItems();
        compare(items[0].visible, true);
        compare(items[1].visible, false, "b/c/d 整条不渲染（官方 splice 掉）");
        compare(items[2].visible, false);
        compare(items[3].visible, false);
        compare(items[4].visible, true);
        compare(items[6].active, true, "当前页还是最后一条");
        var rest = bc.restList;
        compare(rest.length, 3);
        compare([rest[0].label, rest[1].label, rest[2].label], ["b", "c", "d"]);
        // 官方 cloneElement 那条闸是 `!(shouldCollapse && (hasRenderMore || popover) && inCollapseArea)`
        // ⇒ 只有给了 renderMore 或 popover 才关掉被折那几条的分隔符；default 档不关
        //（反正它们整条都不渲染，关不关看不出来 —— 上游那段是个只改标记的死分支）
        compare(items[1].shouldRenderSeparator, true, "default 档那条闸不开");
        bc.destroy()
    }

    function test_collapseRespectsMaxItemCount() {
        const bc = make("Breadcrumb { width: 600; maxItemCount: 3;"
            + " routes: ['a','b','c','d','e','f','g'] }")
        compare(bc.restItemLength, 4);
        compare(labels(bc), ["a", "…", "f", "g"]);
        bc.maxItemCount = 7
        wait(40)
        compare(bc.shouldCollapse, false, "刚好等于条数不折（官方是 > 不是 >=）");
        bc.maxItemCount = 1
        wait(40)
        // 官方 splice(1, n - maxItemCount, spread)：删掉的条数是从 1 起的 n-max，
        // max=1 ⇒ 一次删掉 6 条，把末条（当前页）也删没了 ⇒ 只剩「a …」
        compare(labels(bc), ["a", "…"], "max 1 ⇒ 官方那一步连末条一起删（上游数学就这样）");
        verify(bc.activeItems()[6].visible === false, "当前页整条不渲染");
        bc.destroy()
    }

    function test_autoCollapseOffAndBoundary() {
        const four = make("Breadcrumb { width: 600; routes: ['a','b','c','d'] }")
        compare(four.shouldCollapse, false, "四条不超四条 ⇒ 不折");
        // 只看 shouldCollapse 那条绑定不够：命令式那条判据（collapseNow）算错时绑定还是 false，
        // 名单却已经折上了 ⇒ 名单本身也得钉
        compare(labels(four), ["a", "b", "c", "d"], "边界上四格全在、没有省略号格");
        four.destroy()
        const bc = make("Breadcrumb { width: 600; autoCollapse: false;"
            + " routes: ['a','b','c','d','e'] }")
        compare(bc.shouldCollapse, false);
        compare(bc.cellList().length, 5);
        compare(labels(bc), ["a", "b", "c", "d", "e"], "闸门关掉 ⇒ 一条都不折（省略号格不进名单）");
        verify(part(bc, "bcMoreWrap").visible === false, "不折时省略号格不出现");
        bc.destroy()
    }

    function test_expandIsOneWay() {
        const bc = make("Breadcrumb { width: 600; routes: ['a','b','c','d','e','f','g'] }")
        compare(bc.collapsed, true);
        const icon = part(bc.cellList()[1], "bcMoreIcon");
        mouseClick(icon, icon.width / 2, icon.height / 2);
        wait(60)
        compare(bc.collapsed, false);
        compare(bc.cellList().length, 7, "展开后七条全在");
        var xs = [];
        const items = bc.activeItems();
        for (let i = 0; i < items.length; ++i)
            xs.push(items[i].x);
        for (let i = 1; i < xs.length; ++i)
            verify(xs[i] > xs[i - 1], "重排后 x 严格递增（第 " + i + " 格）");
        // 官方没有「再收回去」的口子：换数据也只是重算，isCollapsed 不再回 true
        bc.routes = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
        wait(60)
        compare(bc.collapsed, false, "展开是单向的（setState 没有回头路）");
        compare(bc.shouldCollapse, false);
        bc.destroy()
    }

    function test_moreBoxCarriesParentSeparator() {
        const bc = make("Breadcrumb { width: 600; separator: '>'; routes:"
            + " ['a','b','c','d','e'] }")
        const more = bc.cellList()[1];
        compare(more.objectName, "bcMoreWrap");
        const sep = part(more, "bcMoreSeparator");
        compare(sep.text, ">");
        verify(sep.visible, "折叠格后面也带父级那份分隔符（官方 spread 里那个 -separator span）");
        compare(sep.color, Theme.current.colorText2, "-separator 那层是 text-2");
        near(more.implicitHeight, 24, "折叠格与条目格同高（line-height 16 + margin 4/4）");
        bc.destroy()
    }

    // ============================================================ 分隔符
    function test_separatorShapes() {
        const bc = make("Breadcrumb { width: 600; routes: ['a','b'] }")
        compare(part(bc.activeItems()[0], "bcSeparator").text, "/");
        bc.separator = "—"
        wait(40)
        compare(part(bc.activeItems()[0], "bcSeparator").text, "—");
        // 宿主给 Component：官方是把它塞进 <span class=-separator> 里 ⇒ 那一层照画
        bc.separator = nodeSeparatorComp
        wait(60)
        const box = part(bc.activeItems()[0], "bcSeparatorBox");
        compare(box.visible, true);
        verify(part(box, "nodeSeparator") !== null, "Component 档的分隔符由 Loader 载入");
        compare(part(bc.activeItems()[0], "bcSeparator").visible, false, "节点档不再画文字那层");
        compare(part(bc.activeItems()[0], "bcSeparator").text, "", "宿主给节点时字符串那层清空");
        verify(part(bc.activeItems()[1], "nodeSeparator") !== null, "每条都吃宿主那份");
        // 宿主给空串 ⇒ 官方 `props.separator || <span>` 里那层是空 span（零宽），
        // 端口整格收掉：几何一致
        const wideCell = bc.activeItems()[0].implicitWidth;
        bc.separator = ""
        wait(40)
        compare(box.visible, false, "空串分隔符 ⇒ 没有可画的层");
        verify(bc.activeItems()[0].implicitWidth < wideCell, "空串那格不留分隔符的宽");
        bc.destroy()
    }

    function test_itemSeparatorOverridesButLosesTheClass() {
        // 官方 item.tsx:202：条目自己给的 separator 是 `props.separator || <span class=-separator>`
        // ⇒ 那一档不套 -separator，拿不到 text-2，跟着页面文字色走
        const bc = make("Breadcrumb { width: 600; separator: '/';"
            + " BreadcrumbItem { label: 'a'; separator: ':' }"
            + " BreadcrumbItem { label: 'b'; separator: '' } BreadcrumbItem { label: 'c' } }")
        const items = bc.activeItems();
        compare(part(items[0], "bcSeparator").text, ":");
        compare(part(items[0], "bcSeparator").color, Theme.current.colorText0,
            "条目自带 ⇒ 没有 -separator 那条 text-2");
        compare(part(items[1], "bcSeparator").text, "/",
            "空串算没给 ⇒ 回落到宿主那份");
        compare(part(items[1], "bcSeparator").color, Theme.current.colorText2,
            "宿主那份走 -separator");
        bc.destroy()
    }

    // ============================================================ 图标与标签档
    function test_iconSizes() {
        const bc = make("Breadcrumb { width: 600;"
            + " BreadcrumbItem { label: 'a'; icon: 'home' } BreadcrumbItem { label: 'b' } }")
        const icon = part(bc.activeItems()[0], "bcIcon");
        compare(icon.name, "home");
        compare(icon.size, 12, "compact ⇒ renderIcon 把尺寸按 small 塞（.semi-icon-small 12）");
        compare(icon.color, Theme.current.colorText2, "图标跟着 -item 的字色");
        bc.compact = false
        wait(40)
        compare(icon.size, 16, "loose ⇒ default（.semi-icon-default 16）");
        bc.destroy()
    }

    function test_iconOnlyItem() {
        // 官方 renderBreadItem :163 `{children ? <span class=-item-title> : null}`
        // ⇒ 没有标题时那一层整个不渲染，条目本体只剩图标那么宽
        const bc = make("Breadcrumb { width: 600;"
            + " BreadcrumbItem { icon: 'home' } BreadcrumbItem { label: '二级标题' } }")
        const first = bc.activeItems()[0];
        const icon = part(first, "bcIcon");
        compare(icon.visible, true);
        compare(part(first, "bcTitle").visible, false, "没有 children ⇒ -item-title 那层整个不渲染");
        near(part(first, "bcItemBox").width, icon.width, "位置器不给不可见的标题留位");
        verify(first.implicitWidth < bc.activeItems()[1].implicitWidth, "只剩图标自然更窄");
        bc.destroy()
    }

    function test_nodeLabelSkipsTruncation() {
        const long = "当这个页面标题很长很长时需要省略"
        const bc = make("Breadcrumb { width: 900; routes: ['" + long + "'] }")
        const textItem = bc.activeItems()[0];
        const title = part(textItem, "bcTitle");
        compare(title.width, 150, "字符串档按 showTooltip.width 夹住");
        bc.activeItems()[0].label = longNodeComp
        wait(80)
        const nodeItem = bc.activeItems()[0];
        compare(part(nodeItem, "bcTitle").visible, false, "节点档不走 Typography");
        verify(part(nodeItem, "longNode") !== null, "Component 档由 Loader 载入");
        verify(nodeItem.implicitWidth > 160, "不截断 ⇒ 这一格铺满自然宽");
        bc.destroy()
    }

    function test_renderItemHook() {
        const bc = make("Breadcrumb { width: 900; routes: ['a', 'b'] }")
        bc.renderItem = function (route) {
            return nodeLabelComp;
        }
        wait(80)
        const first = bc.activeItems()[0];
        compare(part(first, "bcTitle").visible, false, "renderItem 给的是节点 ⇒ 走 inline 档");
        verify(part(first, "nodeLabel") !== null);
        bc.renderItem = null
        wait(60)
        compare(part(bc.activeItems()[0], "bcTitle").text, "a", "撤掉钩子回到 route.name");
        bc.destroy()
    }

    // ============================================================ 截断与 Tooltip
    function test_truncateShapes() {
        const long = "当这个页面标题很长很长时需要省略"
        const bc = make("Breadcrumb { width: 900; routes: ['首页', '" + long + "', '详情页'] }")
        const title = part(bc.activeItems()[1], "bcTitle");
        near(title.width, 150);
        verify(title.implicitWidth > 150, "自然宽确实溢出");
        compare(title.elide, Text.ElideRight);
        bc.showTooltip = ({ width: "auto" })
        wait(40)
        compare(title.elide, Text.ElideNone, "width 'auto' ⇒ 不截断");
        verify(title.width > 150);
        bc.showTooltip = ({ ellipsisPos: "middle" })
        wait(40)
        compare(title.elide, Text.ElideMiddle, "ellipsisPos middle");
        bc.showTooltip = false
        wait(40)
        near(title.width, 150, "false 只是不弹 Tooltip，截断照旧");
        bc.destroy()
    }

    function test_tooltipGate() {
        const long = "当这个页面标题很长很长时需要省略"
        const bc = make("Breadcrumb { width: 900; routes: ['" + long + "'] }")
        const item = bc.activeItems()[0];
        const tip = part(item, "bcTooltip");
        compare(tip.condition, true, "溢出 + 有 opts ⇒ 该弹");
        bc.showTooltip = false
        wait(40)
        compare(tip.condition, false, "没有 opts ⇒ 只截断不弹");
        bc.showTooltip = ({ width: "auto" })
        wait(40)
        compare(tip.condition, false, "没溢出也不弹");
        bc.showTooltip = ({ opts: ({ position: "bottomRight" }) })
        wait(40)
        compare(tip.position, Enums.BottomRight, "opts.position 透到 Tooltip");
        compare(tip.autoAdjustOverflow, true, "merge 后没给的键仍吃缺省");
        bc.destroy()
    }

    // ============================================================ 点击与回调载荷
    function test_clickPayloadChildrenMode() {
        const bc = make("Breadcrumb { width: 600;"
            + " BreadcrumbItem { label: '甲' } BreadcrumbItem { label: '乙'; href: '/x' } }")
        bc.clicked.connect(function (item) { testCase.clicks.push(item); });
        const first = bc.activeItems()[0];
        const box = part(first, "bcItemBox");
        mouseClick(box, box.width - 4, box.height / 2);
        wait(40)
        compare(testCase.clicks.length, 1);
        compare(testCase.clicks[0].name, "甲", "子项档现拼 { name }");
        compare(testCase.clicks[0].href, undefined);
        const second = bc.activeItems()[1];
        mouseClick(part(second, "bcItemBox"), 4, 12);
        wait(40)
        compare(testCase.clicks[1].href, "/x", "给了 href 才带这个键");
        bc.destroy()
    }

    function test_clickOrderOwnThenParent() {
        const bc = make("Breadcrumb { width: 600; routes: ['a', 'b'] }")
        bc.clicked.connect(function () { testCase.order.push("parent"); });
        bc.routes = [{ name: 'a', onClick: function () { testCase.order.push("own"); } }, 'b']
        wait(60)
        const box = part(bc.activeItems()[0], "bcItemBox");
        mouseClick(box, 4, box.height / 2);
        wait(40)
        compare(testCase.order, ["own", "parent"], "itemFoundation.ts:31 先自己再往宿主冒");
        bc.destroy()
    }

    function test_separatorIsNotAClickTarget() {
        const bc = make("Breadcrumb { width: 600; routes: ['a', 'b'] }")
        bc.clicked.connect(function () { testCase.order.push("click"); });
        const first = bc.activeItems()[0];
        const sep = part(first, "bcSeparator");
        mouseClick(sep, sep.width / 2, sep.height / 2);
        wait(40)
        compare(testCase.order.length, 0, "官方 :hover / onClick 都在 -item 上，分隔符不算");
        mouseClick(part(first, "bcItemBox"), 4, 12);
        wait(40)
        compare(testCase.order.length, 1, "同一格里条目本体才算");
        bc.destroy()
    }

    // ============================================================ 颜色三条
    function test_hoverAndPressColors() {
        const bc = make("Breadcrumb { width: 600; routes: ['a', 'b', 'c'] }")
        const first = bc.activeItems()[0];
        const box = part(first, "bcItemBox");
        compare(first.titleColor, Theme.current.colorText2, "未选中基色 text-2");
        mouseMove(box, box.width - 3, box.height / 2);
        wait(60)
        compare(first.hovered, true);
        compare(first.titleColor, Theme.current.colorLink, "-item-link:hover");
        const icon = bc.activeItems()[2];
        compare(part(icon, "bcTitle").color, Theme.current.colorText0, "当前页 text-0");
        compare(part(icon, "bcTitle").font.weight, Font.DemiBold, "当前页字重 600");
        bc.destroy()
    }

    function test_activeItemStillLightsOnHover() {
        // 上游那条「选中激活仍是 text-0」被后面的 -item-link:hover 盖掉了：
        // 没给 noLink 的当前页一 hover 照样变链接色。端口照实际生效的结果做。
        const bc = make("Breadcrumb { width: 600; routes: ['a', 'b'] }")
        const last = bc.activeItems()[1];
        compare(last.active, true);
        const box = part(last, "bcItemBox");
        mouseMove(box, box.width - 3, box.height / 2);
        wait(60)
        compare(last.titleColor, Theme.current.colorLink);
        bc.destroy()
    }

    function test_noLinkRemovesHoverAndPress() {
        const bc = make("Breadcrumb { width: 600;"
            + " BreadcrumbItem { label: 'a'; noLink: true } BreadcrumbItem { label: 'b' } }")
        const off = bc.activeItems()[0];
        const box = part(off, "bcItemBox");
        mouseMove(box, box.width - 3, box.height / 2);
        wait(60)
        compare(off.hovered, true, "指针确实在上面");
        compare(off.titleColor, Theme.current.colorText2, "noLink ⇒ 没有 -item-link 那两条");
        mousePress(box, box.width - 3, box.height / 2);
        wait(40)
        compare(off.pressed, true);
        compare(off.titleColor, Theme.current.colorText2, "按下也不变色");
        mouseRelease(box, box.width - 3, box.height / 2);
        wait(40)
        const on = bc.activeItems()[1];
        mouseMove(part(on, "bcItemBox"), 4, 12);
        wait(60)
        compare(on.titleColor, Theme.current.colorLink, "另一条照常");
        bc.destroy()
    }

    function test_pressColor() {
        const bc = make("Breadcrumb { width: 600; routes: ['a', 'b'] }")
        const box = part(bc.activeItems()[0], "bcItemBox");
        mouseMove(box, box.width - 3, box.height / 2);
        wait(60)
        compare(bc.activeItems()[0].hovered, true, "先让指针进去");
        mousePress(box, box.width - 3, box.height / 2);
        wait(60)
        compare(bc.activeItems()[0].titleColor, Theme.current.colorLinkHover,
            ":active 用 link-hover（variables.scss:9）");
        mouseRelease(box, box.width - 3, box.height / 2);
        wait(40)
        compare(bc.activeItems()[0].pressed, false);
        compare(bc.activeItems()[0].titleColor, Theme.current.colorLink, "松开回到 hover 档");
        bc.destroy()
    }

    // ============================================================ activeIndex
    function test_activeIndexControlled() {
        const bc = make("Breadcrumb { width: 600; routes: ['a','b','c'] }")
        compare(bc.activeItems()[2].active, true);
        bc.activeIndex = 0
        wait(60)
        const items = bc.activeItems();
        compare(items[0].active, true);
        compare(items[1].active, false);
        compare(items[2].active, false, "给了 activeIndex 就不再默认末项是当前页");
        compare(items[0].shouldRenderSeparator, true, "选中的是第 0 条也照样带分隔符");
        compare(items[2].shouldRenderSeparator, false,
            "分隔符只看「是不是最后一条」，与 activeIndex 无关（末项照样没分隔符）");
        bc.activeIndex = undefined
        wait(60)
        compare(bc.activeItems()[2].active, true, "撤掉受控回到缺省");
        // 官方只认 `!== undefined`，且比的是严格相等（props.activeIndex === idx）
        // ⇒ null 也算「给了」，而 null 谁都配不上 ⇒ 一条都不选中
        bc.activeIndex = null
        wait(60)
        compare(bc.activeItems()[0].active, false);
        compare(bc.activeItems()[2].active, false, "null 也走受控档：没有当前页（上游就这样）");
        bc.activeIndex = "1"
        wait(60)
        compare(bc.activeItems()[1].active, false, "字符串同样配不上严格相等");
        bc.activeIndex = 1
        wait(60)
        compare(bc.activeItems()[1].active, true);
        bc.destroy()
    }

    // ============================================================ 排布（flex-wrap）
    function test_layoutMetrics() {
        const bc = make("Breadcrumb { width: 600; routes: ['aaa', 'bbb'] }")
        const items = bc.activeItems();
        near(items[0].y, 0);
        near(items[1].x, items[0].implicitWidth, "第二格紧跟第一格（含 wrap 的 4px 右外边距）");
        near(bc.implicitHeight, 24, "一行 ⇒ 16 行高 + 上下各 4");
        // 格内：图标/文字之间 4、条目与分隔符之间 4
        const title = part(items[0], "bcTitle");
        const box = part(items[0], "bcItemBox");
        const sepBox = part(items[0], "bcSeparatorBox");
        near(box.x + box.width + Theme.current.spacingExtraTight, sepBox.x,
            "-item { margin-right: 4 }");
        near(title.x, 0, "没图标时文字从 0 起（Row 不给不可见的图标留位）");
        near(sepBox.height, 16, "-separator 跟行高");
        bc.destroy()
    }

    function test_layoutWithoutWidth() {
        // QML 的 Item.width 没赋值时回落到 implicitWidth（坑记录），而这里的 implicitWidth 是
        // 「整排不换行需要的那条」⇒ 不给宽就是一行铺开，永不换行（也不会成环）
        const bc = make("Breadcrumb { routes: ['aaa','bbb','ccc'] }")
        const items = bc.activeItems();
        near(bc.width, bc.implicitWidth, "width 回落 implicitWidth");
        near(items[0].y, 0);
        near(items[1].y, 0, "没给宽 ⇒ 不换行（三格都在 y=0 那一行）");
        near(items[2].y, 0);
        near(bc.implicitHeight, 24);
        bc.width = 40
        wait(60)
        verify(bc.activeItems()[1].y > 0, "给了窄宽才换行");
        near(bc.implicitHeight, 72, "三行");
        verify(bc.implicitWidth > 40, "换行不把 implicitWidth 收缩成行宽");
        bc.destroy()
    }

    function test_wrapsWhenTooNarrow() {
        const bc = make("Breadcrumb { width: 120; routes: ['aaaaaaaa','bbbbbbbb','cccccccc'] }")
        const items = bc.activeItems();
        near(items[0].y, 0);
        near(items[1].y, 24, "放不下 ⇒ 整格挪到下一行");
        near(items[2].y, 48);
        near(bc.implicitHeight, 72, "三行");
        verify(bc.implicitWidth > 120, "implicitWidth 是「不换行需要的那条」，不随行数收缩");
        bc.width = 600
        wait(60)
        near(bc.activeItems()[1].y, 0, "够宽了就回到一行");
        near(bc.implicitHeight, 24);
        bc.destroy()
    }

    // ============================================================ moreType / renderMore
    function test_popoverMoreType() {
        const bc = make("Breadcrumb { width: 600; moreType: 'popover';"
            + " routes: ['a','b','c','d','e','f','g'] }")
        const more = bc.cellList()[1];
        const pop = part(more, "bcRestPopover");
        compare(pop.enabled, true, "popover 档浮层可用");
        compare(pop.visible, false, "缺省收着，hover 那枚图标才开");
        // 官方 Popover 没给 trigger ⇒ 吃 BaseTooltip 的缺省 'hover'（index.tsx:160-162）
        const icon = part(more, "bcMoreIcon");
        mouseMove(icon, icon.width / 2, icon.height / 2);
        wait(300)
        compare(pop.visible, true, "悬浮 IconMore ⇒ 浮层开");
        compare(bc.activeItems()[1].shouldRenderSeparator, false,
            "popover 档那条闸开了：被折的几条连分隔符标记一起关");
        // 浮层里是被折掉的三条，条目之间夹 -restItem 分隔符
        const cells = [];
        for (let i = 0; i < 3; ++i)
            cells.push(deepPart(pop.contentItem, "bcRestItem" + i));
        compare([cells[0].label, cells[1].label, cells[2].label], ["b", "c", "d"],
            "浮层拿的是 restItem 那三条，不是全表");
        compare(cells[0].shouldRenderSeparator, false, "分隔符由 -restItem 那层给");
        compare(cells[0].active, false, "浮层里那几条都不算当前页");
        compare(deepPart(pop.contentItem, "bcRestSeparator0").text, "/");
        compare(deepPart(pop.contentItem, "bcRestSeparator0").color, Theme.current.colorText2);
        near(deepPart(pop.contentItem, "bcRestSeparator0").rightPadding, 8,
            "-restItem { margin-right: 8 }");
        compare(deepPart(pop.contentItem, "bcRestSeparator2").visible, false, "最后一条后面不夹");
        // default 档整只浮层不可用
        bc.moreType = "default"
        wait(40)
        compare(pop.enabled, false);
        bc.destroy()
    }

    function test_renderMoreOverridesBoth() {
        const bc = make("Breadcrumb { width: 600; routes: ['a','b','c','d','e','f','g'] }")
        compare(part(bc.cellList()[1], "bcMoreIcon").visible, true, "default 档就是那枚 IconMore");
        bc.renderMore = moreComp
        wait(80)
        const more = bc.cellList()[1];
        compare(part(more, "bcMoreIcon").visible, false, "renderMore 顶掉缺省那枚");
        const node = part(more, "moreNode");
        compare(node.text, "共3项", "restItems 注进 Component 根项");
        // 官方：renderMore 时 moreType 那条分支整个不走 ⇒ 浮层不该可用
        bc.moreType = "popover"
        wait(40)
        compare(part(more, "bcRestPopover").enabled, false, "renderMore 优先于 moreType");
        bc.renderMore = null
        wait(80)
        compare(part(bc.cellList()[1], "bcMoreIcon").visible, true, "撤掉钩子回到内置那两档");
        compare(part(bc.cellList()[1], "bcRestPopover").enabled, true);
        bc.destroy()
    }

    // ============================================================ a11y 与死 prop
    function test_ariaLabelAndDeadProps() {
        const bc = make("Breadcrumb { width: 600; routes: ['a'] }")
        compare(bc.Accessible.name, "Breadcrumb");
        bc.ariaLabel = "位置导航"
        wait(40)
        compare(bc.Accessible.name, "位置导航");
        // className / style 与全站同一口径：收了不产出可见差异
        const before = bc.cellList().length;
        bc.className = "x";
        bc.style = ({ color: "red", width: 10 });
        wait(40)
        compare(bc.cellList().length, before);
        near(bc.implicitHeight, 24, "style 不影响排布");
        bc.destroy()
    }
}
