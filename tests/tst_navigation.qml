import QtQuick
import QtTest
import Semi

// Navigation 导航。规格照 packages/semi-ui/navigation/{index.tsx,Item.tsx,SubNav.tsx,
// Header.tsx,Footer.tsx,CollapseButton.tsx} + packages/semi-foundation/navigation/
// {foundation.ts,itemFoundation.ts,subNavFoundation.ts,NavItem.ts,navigation.scss}。
//
// 端口口径（完整清单在 src/Navigation*.qml 头注释）：
//   · 24 条官方 prop 全收；`bodyStyle` 只认 `height` 一个键 = **列表区高**（容器随之
//     header + body + footer；使用方另给 height 时列表区仍听 bodyStyle）；
//     selectedKeys / openKeys / isCollapsed 三组「受控 or 非受控」，
//     openKeys 的受控档还多「竖直 + 未折叠」两道闸（index.tsx:404）。
//   · init（foundation.ts:119-135）：selectedKeys = prop || default || []，再**不去重地**
//     拼零级父 key；openKeys 没给数组、竖直、给了 selectedKeys 时并上全部祖先。
//   · 点选：未受控且原先未选中 ⇒ 整表替换成 [key, 零级父]（点击路径过 Set 去重）；
//     onSelect 只在「原先未选中」时发，onClick 每次都发。
//   · 入表（buildItemKeysMap）只收**真值** itemKey（foundation.ts:81），点击路径的
//     isValidKey 却收 string|number —— 空串 key 点得中但进不了表，两处都照抄。
//   · 收起按钮：内部翻转（受控档不翻），onCollapseChange 恒发；按钮文案缺省吃中文 locale。
//   · 皮肤 precedence：按下 fill-1 > 悬浮 fill-0 > 选中 primary-light-default；
//     水平档整套换 text-2 → text-1 → text-0 且无底色。
//
// 断言一律走端口自己算出来的几何与状态，不写死字体度量；颜色断言用浅色档下互不相同的令牌。
TestCase {
    id: testCase

    name: "Navigation"
    when: windowShown
    width: 900
    height: 700

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
        mouseMove(testCase, 2, 2);
        wait(30);
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "nav");
    }

    function spyOn(target, name) {
        const s = Qt.createQmlObject("import QtTest; SignalSpy { signalName: \"" + name + "\" }",
            testCase, "spy");
        s.target = target;
        return s;
    }

    function sameArray(actual, expected, message) {
        compare(JSON.stringify(actual), JSON.stringify(expected), message || "");
    }

    // 走 children 名单递归（Loader 装载项也在 children 里）
    function findItems(root, out) {
        const list = out === undefined ? [] : out;
        const kids = root.children;
        for (let i = 0; i < kids.length; ++i) {
            const child = kids[i];
            if (child.itemKey !== undefined && child.isNavigationSub !== true)
                list.push(child);
            testCase.findItems(child, list);
        }
        return list;
    }

    function findSubs(root, out) {
        const list = out === undefined ? [] : out;
        const kids = root.children;
        for (let i = 0; i < kids.length; ++i) {
            const child = kids[i];
            if (child.isNavigationSub === true)
                list.push(child);
            testCase.findSubs(child, list);
        }
        return list;
    }

    // data 名单里找弹层（Popup 不是 Item，不在 children 里）
    function findPopups(root, out) {
        const list = out === undefined ? [] : out;
        const data = root.data;
        for (let i = 0; i < data.length; ++i) {
            const d = data[i];
            if (d.position !== undefined && d.condition !== undefined)
                list.push(d);
        }
        return list;
    }

    function findByType(root, typeName) {
        const kids = root.children;
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].toString().indexOf(typeName) === 0)
                return kids[i];
            const hit = testCase.findByType(kids[i], typeName);
            if (hit !== null)
                return hit;
        }
        const data = root.data;
        for (let j = 0; j < data.length; ++j) {
            if (data[j].toString().indexOf(typeName) === 0)
                return data[j];
        }
        return null;
    }

    // ---------------------------------------------------------------- 容器：items 档
    function test_itemsModeRendersEntries() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: ["
            + "    { itemKey: 'user', text: '用户管理', icon: 'user' },"
            + "    { itemKey: 'union', text: '活动管理' },"
            + "    { itemKey: 'job', text: '任务平台', items: ['任务管理', '用户任务查询'] }"
            + "  ] }");
        wait(80);
        const items = findItems(n);
        const subs = findSubs(n);
        compare(subs.length, 1, "一个 sub");
        compare(items.length, 4, "两个平铺 + sub 里两个字符串条目");
        compare(items[0].itemKey, "user");
        compare(items[0].icon, "user");
        compare(subs[0].itemKey, "job");
        compare(items[2].level, 1, "sub 里的条目 level+1");
        compare(items[2].navInSub, true, "sub 里的条目注入 navInSub");
    }

    function test_stringEntryItemKeyIsText() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'job', text: '任务', items: ['a', 'b'] } ] }");
        wait(80);
        const items = findItems(n);
        compare(items.length, 2);
        compare(items[0].text, "a");
        compare(items[0].itemKey, "a", "NavItem 构造器字符串包装：itemKey = text");
        compare(items[1].itemKey, "b");
    }

    function test_objectEntryDefaults() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'x', text: 'X' } ] }");
        wait(80);
        const item = findItems(n)[0];
        compare(item.icon, "", "缺省 icon 空串");
        compare(item.indent, false);
        compare(item.disabled, false);
        compare(item.level, 0);
    }

    function test_emptyItemsFallsToChildren() {
        const n = make("Navigation { width: 240; height: 400; items: [];"
            + "  NavigationItem { itemKey: 'a'; text: 'A' } }");
        wait(80);
        const items = findItems(n);
        compare(items.length, 1, "items: [] 不算 items 档，children 照渲染");
        compare(items[0].itemKey, "a");
    }

    function test_itemsAndChildrenBothRender() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'i', text: 'I' } ];"
            + "  NavigationItem { itemKey: 'c'; text: 'C' } }");
        wait(80);
        const items = findItems(n);
        compare(items.length, 2);
        compare(items[0].itemKey, "i", "items 渲染在前");
        compare(items[1].itemKey, "c", "children 渲染在后");
    }

    // ---------------------------------------------------------------- 点选状态机
    function test_clickReplacesSelectedKeys() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'user', text: '用户' },"
            + "           { itemKey: 'job', text: '任务', items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const items = findItems(n);
        compare(items.length, 2, "sub 不算普通项");
        n.handleItemClick("user", "用户", false, { itemKey: "user" });
        sameArray(n._selectedKeys, ["user"], "顶级项整表替换");

        n.handleItemClick("c", "C", false, { itemKey: "c" });
        sameArray(n._selectedKeys, ["c", "job"], "嵌套项拼零级父 key（Set 去重）");
        compare(items[1].selected, true, "走树把选中写回条目");
        compare(items[0].selected, false, "旧选中被整表替换掉");
    }

    function test_selectFiresOnlyWhenUnselected() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' }, { itemKey: 'b', text: 'B' } ] }");
        wait(80);
        const sselect = spyOn(n, "select");
        n.handleItemClick("a", "A", false, { itemKey: "a" });
        compare(sselect.count, 1, "首次选中发 onSelect");
        n.handleItemClick("a", "A", true, { itemKey: "a" });
        compare(sselect.count, 1, "已选中再点不发 onSelect");
    }

    function test_clickFiresEveryTime() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const cspy = spyOn(n, "click");
        n.handleItemClick("a", "A", false, { itemKey: "a" });
        n.handleItemClick("a", "A", true, { itemKey: "a" });
        compare(cspy.count, 2, "onClick 每次都发");
    }

    function test_callbackPayloadShapes() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const sselect = spyOn(n, "select");
        const cspy = spyOn(n, "click");
        n.handleItemClick("a", "A", false, { itemKey: "a", text: "A" });
        const sel = sselect.signalArguments[0][0];
        compare(sel.itemKey, "a");
        sameArray(sel.selectedKeys, ["a"], "onSelect.selectedKeys 只含点击项");
        compare(sel.selectedItems.length, 1);
        compare(sel.selectedItems[0].itemKey, "a");
        compare(sel.selectedItems[0].text, "A", "selectedItems 是 props 快照");
        compare(sel.domEvent, null, "QML 无 domEvent，恒 null");
        const clk = cspy.signalArguments[0][0];
        compare(clk.itemKey, "a");
        compare(clk.text, "A");
        compare(clk.domEvent, null);
    }

    function test_disabledItemDead() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A', disabled: true } ] }");
        wait(80);
        const sselect = spyOn(n, "select");
        const cspy = spyOn(n, "click");
        const item = findItems(n)[0];
        tryVerify(function () { return item.width > 0; }, 1000, "条目装载完");
        mouseClick(item, 30, 18);
        wait(30);
        sameArray(n._selectedKeys, [], "禁用项点不中（TapHandler.enabled 关掉）");
        compare(sselect.count, 0);
        compare(cspy.count, 0);
        compare(item.selected, false);
    }

    function test_numberItemKey() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 5, text: '五' } ] }");
        wait(80);
        n.handleItemClick(5, "五", false, { itemKey: 5 });
        sameArray(n._selectedKeys, [5], "数字 key 照收（isValidKey 收 string|number）");
        compare(findItems(n)[0].selected, true);
    }

    function test_emptyItemKeyQuirk() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: '', text: '空' }, { itemKey: 'b', text: 'B' } ] }");
        wait(80);
        sameArray(n._itemKeysMap, { "b": [] }, "空串 key 进不了表（buildItemKeysMap 真值闸）");
        n.handleItemClick("", "空", false, { itemKey: "" });
        sameArray(n._selectedKeys, [""], "但空串 key 点得中（isValidKey 只挡 null/非 string|number）");
        compare(findItems(n)[0].selected, true);
    }

    // ---------------------------------------------------------------- 受控三组
    function test_controlledSelectedKeys() {
        const n = make("Navigation { width: 240; height: 400; selectedKeys: ['a'];"
            + "  items: [ { itemKey: 'a', text: 'A' }, { itemKey: 'b', text: 'B' } ] }");
        wait(80);
        const items = findItems(n);
        compare(items[0].selected, true, "受控初值生效");
        const sselect = spyOn(n, "select");
        n.handleItemClick("b", "B", false, { itemKey: "b" });
        sameArray(n._selectedKeys, ["a"], "受控档点击不动内部表");
        compare(items[1].selected, false);
        compare(sselect.count, 1, "但 onSelect 照发");
    }

    function test_selectedKeysPropChange() {
        const n = make("Navigation { width: 240; height: 400; selectedKeys: ['x'];"
            + "  items: [ { itemKey: 'job', text: '任务',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        n.selectedKeys = ["c"];
        wait(30);
        sameArray(n._selectedKeys, ["c", "job"], "prop 变化走 updateSelectedKeys，拼零级父");
        sameArray(n._openKeys, ["job"], "并按 getWillOpenKeys 重算 openKeys（祖先全开）");
        compare(findSubs(n)[0].isOpen, true);
    }

    function test_defaultSelectedKeysAppendsParentNoDedup() {
        const n = make("Navigation { width: 240; height: 400; defaultSelectedKeys: ['c', 'job'];"
            + "  items: [ { itemKey: 'job', text: '任务',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        sameArray(n._selectedKeys, ["c", "job", "job"],
            "init 拼零级父 key 不去重（foundation.ts:127-133 的官方坑）");
    }

    function test_defaultSelectedOpensAncestors() {
        const n = make("Navigation { width: 240; height: 400; defaultSelectedKeys: ['d'];"
            + "  items: [ { itemKey: 'p', text: 'P', items: [ { itemKey: 'q', text: 'Q',"
            + "      items: [ { itemKey: 'd', text: 'D' } ] } ] } ] }");
        wait(80);
        sameArray(n._openKeys, ["p", "q"], "没给 openKeys 数组时全部祖先都开");
        const subs = findSubs(n);
        compare(subs[0].isOpen, true);
        compare(subs[1].isOpen, true);
    }

    function test_openKeysArraySuppressesAutoOpen() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  defaultSelectedKeys: ['c']; defaultOpenKeys: [];"
            + "  items: [ { itemKey: 'job', text: '任务',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        sameArray(n._openKeys, [], "给了 openKeys 数组就不并祖先");
        compare(findSubs(n)[0].isOpen, false);
    }

    function test_horizontalSuppressesAutoOpen() {
        const n = make("Navigation { width: 600; height: 60; mode: Enums.DirectionHorizontal;"
            + "  defaultSelectedKeys: ['c'];"
            + "  items: [ { itemKey: 'job', text: '任务',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        sameArray(n._openKeys, [], "水平档 getWillOpenKeys 不并祖先（mode 闸）");
    }

    function test_defaultOpenKeys() {
        const n = make("Navigation { width: 240; height: 400; defaultOpenKeys: ['job'];"
            + "  items: [ { itemKey: 'job', text: '任务',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        sameArray(n._openKeys, ["job"]);
        compare(findSubs(n)[0].isOpen, true);
    }

    function test_controlledOpenKeys() {
        const n = make("Navigation { width: 240; height: 400; openKeys: ['p'];"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'q', text: 'Q' } ] } ] }");
        wait(80);
        compare(findSubs(n)[0].isOpen, true, "受控 openKeys 初值写进 sub");
        const ospy = spyOn(n, "openChange");
        n.handleSubClick("p");
        sameArray(n._openKeys, ["p"], "受控档 sub 点击不动内部表");
        compare(ospy.count, 1, "但 onOpenChange 照发");
        compare(ospy.signalArguments[0][0].isOpen, false, "payload 报告将要收起");
        sameArray(ospy.signalArguments[0][0].openKeys, [], "payload 里的 openKeys 是将要的表");
    }

    function test_openKeysControlledGateOnCollapse() {
        const n = make("Navigation { width: 240; height: 400; openKeys: ['p'];"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        compare(n.openKeysIsControlled, true, "竖直 + 未折叠 ⇒ 受控");
        n.toggleCollapse();
        wait(300);
        compare(n.openKeysIsControlled, false, "折叠后 openKeys 退回非受控（index.tsx:404）");
        n.handleSubClick("p");
        sameArray(n._openKeys, [], "折叠档 sub 点击照改内部表（canUpdateOpenKeys 恒真）");
    }

    function test_openKeysControlledGateOnHorizontal() {
        const n = make("Navigation { width: 600; height: 60; mode: Enums.DirectionHorizontal;"
            + "  openKeys: ['p'];"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        compare(n.openKeysIsControlled, false, "水平档不受控");
    }

    function test_openKeysPropChange() {
        const n = make("Navigation { width: 240; height: 400; openKeys: [];"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        n.openKeys = ["p"];
        wait(30);
        sameArray(n._openKeys, ["p"], "prop 变化直接替换");
        compare(findSubs(n)[0].isOpen, true);
    }

    // ---------------------------------------------------------------- sub 点击 / 浮层
    function test_subClickTogglesOpenKeys() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const ospy = spyOn(n, "openChange");
        const cspy = spyOn(n, "click");
        n.handleSubClick("p");
        sameArray(n._openKeys, ["p"], "非受控档翻转内部表");
        compare(findSubs(n)[0].isOpen, true);
        compare(ospy.count, 1);
        compare(ospy.signalArguments[0][0].itemKey, "p");
        compare(ospy.signalArguments[0][0].isOpen, true);
        compare(cspy.count, 1, "sub 标题点击也发容器级 onClick");
        n.handleSubClick("p");
        sameArray(n._openKeys, [], "再点收起");
        compare(ospy.signalArguments[ospy.count - 1][0].isOpen, false);
        compare(cspy.count, 2);
    }

    function test_subClickRealMouse() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        tryVerify(function () { return sub.width > 0 && sub.height > 0; }, 1000, "Loader 装载完");
        mouseClick(sub, 60, 18);
        wait(30);
        sameArray(n._openKeys, ["p"], "标题行的真实点击走到 handleSubClick");
    }

    function test_dropdownVisibleChangeOnlyOpenChange() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const ospy = spyOn(n, "openChange");
        const cspy = spyOn(n, "click");
        n.handleDropdownVisibleChange("p", true);
        sameArray(n._openKeys, ["p"], "浮层显隐照改内部表");
        compare(ospy.count, 1, "只发 onOpenChange");
        compare(cspy.count, 0, "不发 onClick（handleDropdownVisibleChange 的口径）");
        n.handleDropdownVisibleChange("p", false);
        sameArray(n._openKeys, []);
        compare(ospy.count, 2);
    }

    function test_subDisabledDead() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P', disabled: true,"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        tryVerify(function () { return sub.width > 0 && sub.height > 0; }, 1000, "Loader 装载完");
        mouseClick(sub, 60, 18);
        wait(30);
        sameArray(n._openKeys, [], "禁用 sub 标题点不动");
    }

    // ---------------------------------------------------------------- 走树注入的缺省值
    function test_defaultInjectedValues() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const item = findItems(n)[0];
        const sub = findSubs(n)[0];
        compare(item.navToggleIconPosition, "right", "箭头缺省行尾");
        compare(item.navTooltipShowDelay, 0, "tooltipShowDelay 缺省 0");
        compare(item.navTooltipHideDelay, 100, "tooltipHideDelay 缺省 100");
        compare(sub.navSubOpenDelay, 0, "subNavOpenDelay 缺省 0");
        compare(sub.navSubCloseDelay, 100, "subNavCloseDelay 缺省 100");
        compare(sub.navSubMotion, true);
        compare(sub.navOpenKeysControlled, false, "没给 openKeys 就不受控");
    }

    // ---------------------------------------------------------------- 重复点击已选中项
    function test_reclickSelectedKeepsTable() {
        // init 拼父不去重：['a','c'] 变 ['a','c','job']；再点已选中的 c 时官方有
        // 「原先未选中」闸 —— 整表替换不会发生，a 不会丢
        const n = make("Navigation { width: 240; height: 400; defaultSelectedKeys: ['a', 'c'];"
            + "  items: [ { itemKey: 'a', text: 'A' },"
            + "           { itemKey: 'job', text: 'J',"
            + "             items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        sameArray(n._selectedKeys, ["a", "c", "job"], "init 拼零级父不去重");
        n.handleItemClick("c", "C", true, { itemKey: "c" });
        sameArray(n._selectedKeys, ["a", "c", "job"],
            "已选中项再点不触发整表替换，a 不丢（「原先未选中」闸）");
    }

    // ---------------------------------------------------------------- children 档入表
    function test_childrenModeKeylessItemSkipped() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  NavigationItem { itemKey: 'a'; text: 'A' }"
            + "  NavigationItem { text: '没 key 的装饰项' } }");
        wait(80);
        sameArray(n._itemKeysMap, { "a": [] },
            "假值 key（缺省空串）进不了表，装饰项被跳过（buildItemKeysMap 真值闸）");
    }

    // ---------------------------------------------------------------- 受控档的浮层显隐
    function test_controlledDropdownVisibleKeepsTable() {
        const n = make("Navigation { width: 240; height: 400; openKeys: ['p'];"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        compare(n.openKeysIsControlled, true);
        const ospy = spyOn(n, "openChange");
        n.handleDropdownVisibleChange("p", false);
        sameArray(n._openKeys, ["p"], "受控档浮层显隐不动内部表");
        compare(ospy.count, 1, "onOpenChange 照发");
        compare(ospy.signalArguments[0][0].isOpen, false);
    }

    // ---------------------------------------------------------------- 收起
    function test_collapseToggle() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const cspy = spyOn(n, "collapseChange");
        compare(n._isCollapsed, false);
        n.toggleCollapse();
        wait(300);
        compare(n._isCollapsed, true, "非受控档内部翻转");
        compare(cspy.count, 1);
        compare(cspy.signalArguments[0][0], true, "onCollapseChange 带目标态");
        n.toggleCollapse();
        wait(300);
        compare(n._isCollapsed, false);
        compare(cspy.count, 2);
        compare(cspy.signalArguments[cspy.count - 1][0], false);
    }

    function test_controlledCollapse() {
        const n = make("Navigation { width: 240; height: 400; isCollapsed: false;"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const cspy = spyOn(n, "collapseChange");
        n.toggleCollapse();
        wait(50);
        compare(n._isCollapsed, false, "受控档不翻内部态");
        compare(cspy.count, 1, "但 collapseChange 恒发");
        compare(cspy.signalArguments[0][0], true);
        n.isCollapsed = true;
        wait(50);
        compare(n._isCollapsed, true, "prop 变化同步进来");
        compare(findItems(n)[0].effectiveCollapsed, true, "并走树写给条目");
    }

    function test_defaultIsCollapsed() {
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(300);
        compare(n._isCollapsed, true);
        compare(n.implicitWidth, 60, "宽度动画到位");
        compare(findItems(n)[0].effectiveCollapsed, true);
    }

    function test_widthAnimation() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        compare(n.expandedWidth, 240);
        compare(n.collapsedWidth, 60);
        compare(n.implicitWidth, 240);
        n.toggleCollapse();
        wait(300);
        compare(n.implicitWidth, 60, "200ms 宽度动画后到位");
        n.toggleCollapse();
        wait(300);
        compare(n.implicitWidth, 240);
    }

    // ---------------------------------------------------------------- 水平档
    function test_horizontalMode() {
        const n = make("Navigation { width: 600; height: 60; mode: Enums.DirectionHorizontal;"
            + "  items: [ { itemKey: 'a', text: 'A' }, { itemKey: 'b', text: 'B' } ] }");
        wait(80);
        compare(n.horizontal, true);
        compare(n.implicitWidth, 0, "水平档宽度由使用方给");
        const items = findItems(n);
        compare(items[0].navHorizontal, true, "走树注入");
        const ax = n.mapFromItem(items[0], 0, 0).x;
        const bx = n.mapFromItem(items[1], 0, 0).x;
        tryVerify(function () { return bx > ax; }, 1000, "Row 排开");
        compare(n.mapFromItem(items[0], 0, 0).y, n.mapFromItem(items[1], 0, 0).y, "同一行");
    }

    function test_horizontalSubFlyoutMode() {
        const n = make("Navigation { width: 600; height: 60; mode: Enums.DirectionHorizontal;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.flyoutMode, true, "水平档 sub 走浮层");
        compare(sub.toggleVisible, true, "水平顶级 sub 标题仍有箭头");
        compare(sub.toggleRotation, 0, "浮层档不旋转");
    }

    function test_collapsedSubFlyoutMode() {
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.flyoutMode, true, "折叠档 sub 走浮层");
        compare(sub.toggleVisible, false, "折叠的顶级标题没有箭头（官方如此）");
        compare(sub.implicitHeight, 36, "子项不在原地展开");
    }

    // ---------------------------------------------------------------- limitIndent / 图标位
    function test_limitIndentPlaceholders() {
        const items3 = "[ { itemKey: 'p', text: 'P', items: [ { itemKey: 'q', text: 'Q',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] } ]";
        const n = make("Navigation { width: 240; height: 400; limitIndent: false;"
            + "  items: " + items3 + " }");
        wait(80);
        const items = findItems(n);
        const subs = findSubs(n);
        compare(subs.length, 2, "p / q 是 sub");
        compare(items.length, 1, "只有 c 是普通项");
        compare(subs[0].placeholderAmount, 0, "level 0 sub 无占位（-1 归 0）");
        compare(subs[1].placeholderAmount, 0, "level 1 sub 无图标 ⇒ level-1 = 0");
        compare(items[0].placeholderCount, 1, "level 2 无图标 ⇒ level-1 = 1");

        const n2 = make("Navigation { width: 240; height: 400; limitIndent: false;"
            + "  items: [ { itemKey: 'p', text: 'P', items: [ { itemKey: 'c', text: 'C',"
            + "    icon: 'user' } ] } ] }");
        wait(80);
        compare(findItems(n2)[0].placeholderCount, 1, "有图标且未 indent ⇒ level 个占位");

        const n3 = make("Navigation { width: 240; height: 400;"
            + "  items: " + items3 + " }");
        wait(80);
        compare(findItems(n3)[0].placeholderCount, 0, "limitIndent: true（缺省）无占位");
    }

    function test_toggleIconPositionLeft() {
        const n = make("Navigation { width: 240; height: 400; toggleIconPosition: 'left';"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const item = findItems(n)[0];
        compare(item.navToggleIconPosition, "left");
        compare(item.toggleLeftSlot, true, "left 档标题前挂空槽");
        compare(item.leadingWidth, item.iconSize + item.gap, "空槽占 20 + 12");
    }

    function test_expandIconItemsModeOnly() {
        const n = make("Navigation { width: 240; height: 400; expandIcon: 'chevron_up';"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.navExpandIcon, "chevron_up", "items 档下放 expandIcon");
        compare(sub.effectiveExpandIcon, "chevron_up");

        const n2 = make("Navigation { width: 240; height: 400; expandIcon: 'chevron_up';"
            + "  NavigationSub { itemKey: 'p'; text: 'P';"
            + "    NavigationItem { itemKey: 'c'; text: 'C' } } }");
        wait(80);
        const sub2 = findSubs(n2)[0];
        compare(sub2.navExpandIcon, undefined, "children 档官方拿不到（context 里没有）");
        compare(sub2.effectiveExpandIcon, "chevron_down", "落回缺省箭头");
    }

    function test_perSubExpandIconDeadInItemsMode() {
        // renderItems 的 JSX 是 `{...item} expandIcon={expandIcon}` —— 容器值同名后写，
        // 即使容器没给（undefined 也盖）⇒ items 档 per-item expandIcon 是死的
        const n = make("Navigation { width: 240; height: 400; expandIcon: 'chevron_up';"
            + "  items: [ { itemKey: 'p', text: 'P', expandIcon: 'chevron_right',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        compare(findSubs(n)[0].effectiveExpandIcon, "chevron_up",
            "容器 expandIcon 盖过 per-item（官方 JSX 后写覆盖）");

        const n2 = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P', expandIcon: 'chevron_right',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        compare(findSubs(n2)[0].effectiveExpandIcon, "chevron_down",
            "容器没给时 per-item 也被 undefined 盖掉，落回缺省箭头");

        const n3 = make("Navigation { width: 240; height: 400;"
            + "  NavigationSub { itemKey: 'p'; text: 'P'; expandIcon: 'chevron_right';"
            + "    NavigationItem { itemKey: 'c'; text: 'C' } } }");
        wait(80);
        compare(findSubs(n3)[0].effectiveExpandIcon, "chevron_right",
            "children 档直接写在 Sub 上的 expandIcon 有效");
    }

    function test_subDropdownPropsPosition() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  subDropdownProps: ({ position: Enums.BottomLeft });"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.positionOf(), Enums.BottomLeft, "容器 subDropdownProps 生效");
        sub.dropdownProps = { position: Enums.RightBottom };
        compare(sub.positionOf(), Enums.RightBottom, "per-sub dropdownProps 整档盖过容器");
        const n2 = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        compare(findSubs(n2)[0].positionOf(), Enums.RightTop, "竖直缺省 rightTop");
    }

    // ---------------------------------------------------------------- 延迟 / 动效
    function test_tooltipDelaysInjected() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  tooltipShowDelay: 300; tooltipHideDelay: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const item = findItems(n)[0];
        compare(item.navTooltipShowDelay, 300);
        compare(item.navTooltipHideDelay, 400);
        const tip = findPopups(item)[0];
        compare(tip.mouseEnterDelay, 300, "折叠 tooltip 吃容器延迟");
        compare(tip.mouseLeaveDelay, 400);
        item.tooltipShowDelay = 50;
        compare(tip.mouseEnterDelay, 50, "per-item 覆盖容器（?? 语义）");
    }

    function test_subNavMotionRotation() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.toggleRotation, 0);
        n.handleSubClick("p");
        compare(sub.toggleRotation, -180, "展开且 motion 开 ⇒ 箭头转 -180");

        const n2 = make("Navigation { width: 240; height: 400; subNavMotion: false;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub2 = findSubs(n2)[0];
        n2.handleSubClick("p");
        compare(sub2.toggleRotation, 0, "motion 关掉连旋转都没有（SubNav.tsx:220-224）");
    }

    function test_subMotionKeepsFollowingItemsInSync() {
        // 官方 Collapsible 的 wrapper height 在文档流里过渡 ⇒ 后续条目每帧跟着动；
        // 端口此前 implicitHeight 直接吃终值 ⇒ 收起时后续条目先跳上去、内容还挂着（重叠），
        // 展开时又提前让出空档。采样点必须取 afterAnimating（polish 之后那一拍的渲染状态）。
        const n = make("Navigation { width: 240; height: 600;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c1', text: 'C1' }, { itemKey: 'c2', text: 'C2' } ] },"
            + "    { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        const after = findItems(n).filter(function (i) { return i.itemKey === "a"; })[0];
        const wrap = testCase.findChild(sub, "navSubMotionWrap");
        verify(after !== undefined && wrap !== null, "夹具齐了");
        const rows = [];
        let sampling = true;
        function sample() {
            if (!sampling)
                return;
            const contentBottom = sub.mapToItem(n, 0, 0).y + 36 + wrap.height;
            rows.push([wrap.height, after.mapToItem(n, 0, 0).y - contentBottom]);
        }
        testCase.Window.window.afterAnimating.connect(sample);
        n.handleSubClick("p");
        wait(400);
        n.handleSubClick("p");
        wait(400);
        sampling = false;
        testCase.Window.window.afterAnimating.disconnect(sample);

        verify(rows.length > 10, "采到动画帧（实得 " + rows.length + "）");
        let mids = 0;
        for (let i = 0; i < rows.length; ++i) {
            if (rows[i][0] > 3 && rows[i][0] < wrap.fullHeight - 3)
                mids++;
            if (Math.abs(rows[i][1] - 8) > 0.51)
                fail("第 " + i + " 帧内容底与下一条目顶的间隙 " + rows[i][1]
                    + " ≠ 列表间距 8（height=" + rows[i][0] + "）");
        }
        verify(mids > 3, "动画中途真的在过渡（中间帧 " + mids + "）");
    }

    function test_subMotionHeightUsesCssEaseCurve() {
        // 官方 height 过渡 = cubic-bezier(.25,.1,.25,1)（CSS ease）：半程已走 ~80%；
        // 旧端口用 InOutQuad，半程只有 ~50%
        const n = make("Navigation { width: 240; height: 600;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c1', text: 'C1' }, { itemKey: 'c2', text: 'C2' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        const wrap = testCase.findChild(sub, "navSubMotionWrap");
        verify(wrap !== null);
        const full = wrap.fullHeight;
        verify(full > 40, "内容有高度（实得 " + full + "）");
        let midSample = -1;
        let sampling = true;
        let t0 = 0;
        function sample() {
            if (!sampling || midSample >= 0)
                return;
            const elapsed = Date.now() - t0;
            if (elapsed >= 100 && elapsed <= 150)
                midSample = wrap.height / full;
        }
        testCase.Window.window.afterAnimating.connect(sample);
        t0 = Date.now();
        n.handleSubClick("p");
        wait(400);
        sampling = false;
        testCase.Window.window.afterAnimating.disconnect(sample);
        verify(midSample >= 0, "采到 100~150ms 的中间帧");
        // ease 在 0.4~0.6 进度处是 0.68~0.85；InOutQuad 只有 0.32~0.50
        verify(midSample > 0.55, "半程附近高度进度 " + midSample.toFixed(3)
            + "（CSS ease 应 > 0.68，InOutQuad 只有 ~0.4）");
    }

    function test_openSubAtMountDoesNotAnimate() {
        // 官方 isTransitioning 只在 isOpen 变化时置真 ⇒ 挂载时就展开的子项直接到位，
        // 不重放一遍展开动画
        const n = make("Navigation { width: 240; height: 600; defaultOpenKeys: ['p'];"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c1', text: 'C1' }, { itemKey: 'c2', text: 'C2' } ] } ] }");
        wait(1);
        const sub = findSubs(n)[0];
        const wrap = testCase.findChild(sub, "navSubMotionWrap");
        verify(wrap !== null);
        const rows = [];
        let sampling = true;
        function sample() {
            if (sampling)
                rows.push([wrap.height, wrap.fullHeight]);
        }
        testCase.Window.window.afterAnimating.connect(sample);
        wait(300);
        sampling = false;
        testCase.Window.window.afterAnimating.disconnect(sample);
        verify(rows.length > 3, "采到帧（实得 " + rows.length + "）");
        const full = rows[rows.length - 1][1];
        verify(full > 40, "内容有高度（实得 " + full + "）");
        for (let i = 0; i < rows.length; ++i) {
            if (rows[i][0] > 0.5 && rows[i][0] < full - 0.5)
                fail("挂载第 " + i + " 帧出现中间高度 " + rows[i][0]
                    + "（full=" + full + "）⇒ 重放了展开动画");
        }
    }

    function test_noMotionHeightIsInstant() {
        const n = make("Navigation { width: 240; height: 600; subNavMotion: false;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c1', text: 'C1' }, { itemKey: 'c2', text: 'C2' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        const wrap = testCase.findChild(sub, "navSubMotionWrap");
        verify(wrap !== null);
        const full = wrap.fullHeight;
        n.handleSubClick("p");
        compare(sub.height, 36 + full, "motion 关掉同一拍就到位");
    }

    function test_subDelaysInjected() {
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  subNavOpenDelay: 200; subNavCloseDelay: 300;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.navSubOpenDelay, 200);
        compare(sub.navSubCloseDelay, 300);
        const flyout = findPopups(sub).filter(function (p) { return p.position !== Enums.Right; })[0];
        verify(flyout !== undefined, "找得到折叠浮层");
        compare(flyout.mouseEnterDelay, 200, "浮层延迟吃容器");
        compare(flyout.mouseLeaveDelay, 300);
    }

    function test_verticalExpandedHoverDoesNotOpenFlyout() {
        // 官方竖直展开档不渲染 Dropdown（SubNav.tsx:356-359 外层、:323-325 内层），
        // 悬浮 sub 标题只许有 fill-0 底色，不许弹浮层
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.flyoutMode, false, "竖直展开不走浮层");
        const flyout = findPopups(sub).filter(function (p) { return p.position !== Enums.Right; })[0];
        verify(flyout !== undefined, "浮层对象常驻（子项搬家要用 flyoutHost）");
        compare(flyout.condition, false, "渲染闸：竖直档官方不渲染 Dropdown（SubNav.tsx:323-325）");
        mouseMove(sub, 10, 18);
        tryVerify(function () { return sub.hovered; }, 1000, "标题真的悬浮上了（否则断言空转）");
        wait(flyout.mouseEnterDelay + 120);
        compare(flyout.visible, false, "悬浮竖直展开档的 sub 标题不弹浮层");
        mouseMove(testCase, 2, 2);
    }

    function test_verticalExpandedControlledOpenDoesNotShowFlyout() {
        // 官方 visible=isOpen 只挂在折叠/水平档渲染出来的 Dropdown 上（SubNav.tsx:314-317
        // 在 wrapDropdown 内）—— 竖直展开 + 受控 openKeys 也不许出现浮层
        const n = make("Navigation { width: 240; height: 400; openKeys: ['p'];"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.navOpenKeysControlled, true, "竖直 + 未折叠 ⇒ 受控");
        compare(sub.isOpen, true, "受控 openKeys 初值写进 sub");
        const flyout = findPopups(sub).filter(function (p) { return p.position !== Enums.Right; })[0];
        verify(flyout !== undefined);
        compare(flyout.visible, false, "竖直档受控展开也不弹浮层");
    }

    function test_collapsedHoverOpensFlyout() {
        // 折叠档官方照常渲染 hover Dropdown（:310 trigger hover）—— 闸不许把这条也掐掉
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.flyoutMode, true);
        const flyout = findPopups(sub).filter(function (p) { return p.position !== Enums.Right; })[0];
        verify(flyout !== undefined);
        compare(flyout.condition, true, "折叠档渲染闸放行");
        mouseMove(sub, 10, 18);
        tryVerify(function () { return flyout.visible; }, 1000, "折叠档悬浮照常弹浮层");
        mouseMove(testCase, 2, 2);
    }

    function test_flyoutCardAndItemWidthsMatch() {
        // 官方 `.semi-dropdown-item` 是块级、`.semi-navigation-item` 只有 min-width 150
        // ⇒ 悬浮底色铺满卡片。端口此前 subEntriesLoader 吃 parent.width（= subColumn.width =
        // 它自己的 implicitWidth）自环塌 0：卡片 0 宽、条目还按 150 画 ⇒ 底色与卡片不一致。
        const long = "一条很长的子导航项文字用来把列宽顶过一百五十";
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  items: [ { itemKey: 'job', text: '任务平台', icon: 'folder',"
            + "    items: ['短项', '" + long + "'] } ] }");
        wait(120);
        const sub = findSubs(n)[0];
        const flyout = findPopups(sub).filter(function (p) { return p.position !== Enums.Right; })[0];
        flyout.visible = true;
        wait(150);
        const kids = findItems(flyout.contentItem);
        compare(kids.length, 2, "两条子项");
        const widest = Math.max(kids[0].implicitWidth, kids[1].implicitWidth);
        verify(widest > 150, "长条目把自然宽顶过 min-width（实得 " + widest + "）");
        compare(flyout.width, widest, "卡片宽 = 最宽条目的自然宽（此前自环塌 0）");
        compare(kids[0].width, flyout.width, "短条目也铺满 ⇒ 悬浮底色与卡片同宽");
        compare(kids[1].width, flyout.width);
    }

    function test_flyoutChildrenModeItemsStretchToCard() {
        // children 档（声明式子项，没有 NavigationSubEntries 那一层）同一口径
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  NavigationSub { itemKey: 'p'; text: 'P';"
            + "    NavigationItem { itemKey: 'c1'; text: '短项' }"
            + "    NavigationItem { itemKey: 'c2'; text: '一条很长的子导航项文字用来把列宽顶过一百五十' } } }");
        wait(120);
        const sub = findSubs(n)[0];
        const flyout = findPopups(sub).filter(function (p) { return p.position !== Enums.Right; })[0];
        flyout.visible = true;
        wait(150);
        const kids = findItems(flyout.contentItem);
        compare(kids.length, 2);
        verify(kids[1].implicitWidth > 150, "长条目自然宽过 150（实得 " + kids[1].implicitWidth + "）");
        compare(flyout.width, kids[1].implicitWidth, "卡片吃最宽条目的自然宽");
        compare(kids[0].width, flyout.width, "短条目铺满");
        compare(kids[1].width, flyout.width);
    }

    function test_flyoutItemClickSelects() {
        // 浮层里的条目沿 parent 走不到宿主（Popup 不是 Item）⇒ 此前点击整条路空转：
        // 容器注入 navRoot（官方 context 沿组件树走、portal 不切断）后才通
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  items: [ { itemKey: 'job', text: '任务平台', icon: 'folder',"
            + "    items: ['任务管理', '用户任务查询'] } ] }");
        wait(120);
        const sub = findSubs(n)[0];
        const flyout = findPopups(sub).filter(function (p) { return p.position !== Enums.Right; })[0];
        mouseMove(sub, 10, 18);
        tryVerify(function () { return flyout.visible; }, 1000, "悬浮开浮层");
        wait(120);                     // 搬进浮层后位置器要下一轮才把条目排开，按下才有落点
        const spy = spyOn(n, "select");
        const target = findItems(flyout.contentItem)
            .filter(function (i) { return i.itemKey === "任务管理"; })[0];
        verify(target !== undefined, "找得到浮层里的条目");
        compare(target.navRoot === n, true, "容器注入到位（此前沿 parent 找不到 ⇒ null）");
        mousePress(target, target.width / 2, 18);
        wait(30);
        mouseRelease(target, target.width / 2, 18);
        wait(60);
        compare(spy.count, 1, "点浮层条目发 onSelect");
        sameArray(n._selectedKeys, ["任务管理", "job"], "选中键 + 零级父（父级表也认浮层子树）");
        compare(target.navSelected, true, "条目自己刷上选中态");
        compare(findSubs(n)[0].navSelected, true, "顶级 sub 标题跟着选中（零级父）");
        mouseMove(testCase, 2, 2);
    }

    function test_subImplicitHeightGrowsWhenOpen() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.implicitHeight, 36, "收起只一行标题");
        n.handleSubClick("p");
        wait(60);
        verify(sub.implicitHeight > 36, "展开吃进子项高度");
    }

    function test_expandedSubItemsUniformHeightAndSpacing() {
        // 官方 Collapsible 的 domHeight 是内容底边（scrollHeight），含首项上方那 8；
        // 此前取子项包围盒的「高」，展开后最后一条被裁 8px、与下一顶级条目的间距塌成 0
        // ⇒ 看着像每个 item 高度不一致
        const n = make("Navigation { width: 240; height: 600;"
            + "  items: [ { itemKey: 'user', text: '用户管理', icon: 'user' },"
            + "    { itemKey: 'job', text: '任务平台', icon: 'folder',"
            + "      items: ['任务管理', '用户任务查询'] },"
            + "    { itemKey: 'bell', text: '推送通知', icon: 'bell' } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        n.handleSubClick("job");
        wait(400);
        const kids = findItems(sub);
        compare(kids.length, 2, "两条子项");
        const subPos = sub.mapToItem(n, 0, 0);
        const first = kids[0].mapToItem(n, 0, 0);
        const second = kids[1].mapToItem(n, 0, 0);
        compare(kids[0].height, 36, "子项统一 36 高");
        compare(kids[1].height, 36);
        compare(first.y, subPos.y + 36 + 8, "标题下 8 起第一条（首项 margin-top 8）");
        compare(second.y, first.y + 36 + 8, "子项间距 8");
        compare(second.y + kids[1].height, subPos.y + sub.height,
            "最后一条的底 = sub 的底（没有被裁掉 8px）");
        const bell = findItems(n).filter(function (i) { return i.itemKey === "bell"; })[0];
        compare(bell.mapToItem(n, 0, 0).y, second.y + kids[1].height + 8,
            "与下一个顶级条目之间保持 8 的间距");
    }

    function test_nestedListWidthNotCollapsed() {
        // 嵌套列表的 Loader 必须吃 subColumn 的实宽 —— 不给宽时「位置器隐式尺寸
        // 吃子项实际宽」成环，整列塌 0（实测子项全部 w=0 画不出来）
        const n = make("Navigation { width: 240; height: 400; defaultOpenKeys: ['job'];"
            + "  items: [ { itemKey: 'job', text: '任务',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(120);
        const item = findItems(n)[0];
        compare(item.width, n.width - 16, "sub 里的条目吃满列表列宽（容器内边距 8 两侧）");
        compare(item.height, 36);
        compare(item.paddingX, 12, "sub 里的条目同吃 12 的横向内边距");
        compare(findSubs(n)[0].paddingX, 12, "sub 标题同吃 12 的横向内边距");
    }

    // ---------------------------------------------------------------- 皮肤
    function test_itemPaddingAndContainerInsetMatchOfficial() {
        // 官方 css 实测：条目 `padding: 8px 12px`（此前端口横向写成 6，注释还错标 base-tight）
        // 与容器 `padding-left/right: 8`（水平档覆盖 24）—— 文字起点官方 x=44、端口此前 38。
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const items = findItems(n);
        compare(items[0].paddingX, 12, "$spacing-navigation_item-paddingX（css: padding: 8px 12px）");
        const pos = items[0].mapToItem(n, 0, 0);
        compare(pos.x, 8, "竖直档列表区吃容器左右内边距 8");
        n.destroy();

        const h = make("Navigation { width: 600; height: 60; mode: Enums.DirectionHorizontal;"
            + "  header: NavigationHeader { text: 'Hi' }"
            + "  footer: NavigationFooter { }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const hItems = findItems(h);
        const hPos = hItems[0].mapToItem(h, 0, 0);
        verify(hPos.x >= 24, "水平档 header 起点吃容器 padding-left 24（实得 " + hPos.x + "）");
        const foot = testCase.findChild(h, "navFooterArea");
        compare(foot.x, h.width - 24 - foot.width, "水平档 footer 右侧内缩容器 padding-right 24");
        h.destroy();
    }

    function test_bodyStyleHeightIsTheListAreaHeight() {
        // 官方 bodyStyle 写在 `.semi-navigation-list-wrapper` 上 ⇒ bodyStyle.height 就是
        // **列表区的高**、容器随之 header + body + footer。端口此前只认容器高，于是 gallery 把
        // 官方的 bodyStyle 320 写成 height: 320 时列表区只剩 152，展开的子项全被 clip 掉
        // （看着就像「点任务平台没有子项」）
        const n = make("Navigation { bodyStyle: ({ height: 320 });"
            + "  header: NavigationHeader { text: 'H' }"
            + "  footer: NavigationFooter { }"
            + "  items: [ { itemKey: 'a', text: 'A' },"
            + "    { itemKey: 'job', text: '任务平台', items: ['任务管理', '用户任务查询'] } ] }");
        wait(120);
        const list = testCase.findChild(n, "navListArea");
        const head = testCase.findChild(n, "navHeaderArea");
        const foot = testCase.findChild(n, "navFooterArea");
        verify(list !== null && head !== null && foot !== null, "三个区都找得到");
        compare(list.height, 320, "bodyStyle.height 就是列表区高");
        compare(n.implicitHeight, head.height + 320 + foot.height,
            "容器 implicit 高 = header + body + footer（实得 " + n.implicitHeight + "）");
        compare(n.height, n.implicitHeight, "没给 height 时容器跟着 implicit 走");
        n.handleSubClick("job");
        wait(400);
        const kids = findItems(n);
        compare(kids.length, 3, "一个平铺项 + 两条子项");
        for (let i = 0; i < kids.length; ++i) {
            const bottom = kids[i].mapToItem(n, 0, 0).y + kids[i].height;
            verify(bottom <= list.y + list.height + 0.01,
                String(kids[i].itemKey) + " 底 " + bottom + " 落在列表区底 "
                + (list.y + list.height) + " 之内（不被 clip）");
        }

        // 「导航样式定义」那一节的官方写法：容器 style 520 + bodyStyle 300 —— 两把尺子各管各的，
        // 列表区是 300（不是 520 − header − footer）
        const h2 = make("Navigation { height: 520; bodyStyle: ({ height: 300 });"
            + "  header: NavigationHeader { text: 'H' }"
            + "  footer: NavigationFooter { }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(120);
        const list2 = testCase.findChild(h2, "navListArea");
        compare(list2.height, 300, "容器与 body 同时给高时，列表区听 bodyStyle 的");
        compare(h2.height, 520, "容器高听使用方的（不随 body 长）");
    }

    function test_noBodyStyleKeepsContainerMinusChrome() {
        // 没给 bodyStyle 时列表区仍是「容器高 − header − footer」、容器缺省高仍 400（老行为）
        const n = make("Navigation { height: 400;"
            + "  header: NavigationHeader { text: 'H' }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(120);
        const list = testCase.findChild(n, "navListArea");
        const head = testCase.findChild(n, "navHeaderArea");
        const foot = testCase.findChild(n, "navFooterArea");
        verify(list !== null && head !== null && foot !== null);
        compare(list.height, 400 - head.height - foot.height, "容器高减去 header/footer");
        compare(n.implicitHeight, 400, "没 bodyStyle 时容器缺省高仍是 400");
    }

    function test_itemSkinsVertical() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' }, { itemKey: 'b', text: 'B' },"
            + "           { itemKey: 'd', text: 'D', disabled: true } ] }");
        wait(80);
        const items = findItems(n);
        compare(items[0].bgColor, Qt.rgba(0, 0, 0, 0), "常态透明底");
        compare(items[0].textColor, Theme.current.colorText0);
        compare(items[0].iconColor, Theme.current.colorText2);

        n.handleItemClick("a", "A", false, { itemKey: "a" });
        wait(30);
        compare(items[0].bgColor, Theme.current.colorPrimaryLightDefault, "选中 primary-light 底");
        compare(items[0].iconColor, Theme.current.colorPrimary, "选中图标 primary");

        mouseMove(items[1], 6, 18);
        tryVerify(function () { return items[1].hovered; }, 1000, "hover 生效");
        compare(items[1].bgColor, Theme.current.colorFill0, "悬浮 fill-0");

        mousePress(items[1], 6, 18);
        wait(30);
        compare(items[1].bgColor, Theme.current.colorFill1, "按下 fill-1 压过选中");
        // 先移开再松手：同点松手会补全一次点击、把选中换成 b，干扰后面的断言
        mouseMove(testCase, 2, 2);
        mouseRelease(testCase, 2, 2);
        wait(30);
        compare(items[0].selected, true, "拖开松手不产生点击，选中仍是 a");

        // 选中项自己悬浮：底让位给 fill-0（(0,2,0) 压 (0,1,0)），图标保持 primary
        mouseMove(items[0], 6, 18);
        tryVerify(function () { return items[0].hovered; }, 1000, "选中项 hover 生效");
        compare(items[0].bgColor, Theme.current.colorFill0, "选中让位给悬浮");
        compare(items[0].iconColor, Theme.current.colorPrimary, "但图标保持 primary");

        compare(items[2].bgColor, Qt.rgba(0, 0, 0, 0), "禁用透明底");
        compare(items[2].textColor, Theme.current.colorDisabledText);
        compare(items[2].iconColor, Theme.current.colorDisabledText);
        mouseMove(testCase, 2, 2);
    }

    function test_selectedSubItemBeatsHoverAndPress() {
        // 官方 `.semi-navigation-sub .semi-navigation-item:hover.semi-navigation-item-selected`
        // 与 `:active.…selected`、`.…-selected.…-disabled` 都是 primary-light-default
        // （同特异度、写在 item-normal 那组后面）⇒ sub 里的选中条目，悬浮/按下都不许让位给灰底。
        const n = make("Navigation { width: 240; height: 400; defaultOpenKeys: ['job'];"
            + "  defaultSelectedKeys: ['c1'];"
            + "  items: [ { itemKey: 'job', text: '任务平台',"
            + "    items: [ { itemKey: 'c1', text: 'C1' }, { itemKey: 'c2', text: 'C2' } ] } ] }");
        wait(150);
        const kids = findItems(n);
        const sel = kids.filter(function (i) { return i.itemKey === "c1"; })[0];
        const plain = kids.filter(function (i) { return i.itemKey === "c2"; })[0];
        compare(sel.navInSub, true, "sub 里的条目");
        compare(sel.selected, true);
        compare(sel.bgColor, Theme.current.colorPrimaryLightDefault, "常态选中底");
        mouseMove(sel, sel.width / 2, 18);
        tryVerify(function () { return sel.hovered; }, 1000, "悬浮上了");
        compare(sel.bgColor, Theme.current.colorPrimaryLightDefault, "悬浮仍是选中底（不是 fill-0）");
        mousePress(sel, sel.width / 2, 18);
        wait(30);
        compare(sel.bgColor, Theme.current.colorPrimaryLightDefault, "按下也是选中底（不是 fill-1）");
        mouseRelease(testCase, 2, 2);
        wait(30);
        mouseMove(plain, plain.width / 2, 18);
        tryVerify(function () { return plain.hovered; }, 1000, "未选中那条悬浮");
        compare(plain.bgColor, Theme.current.colorFill0, "没选中才让位给悬浮");
        mouseMove(testCase, 2, 2);

        // 反面对照：顶级 L1 是 item-normal 那组赢 —— 选中项悬浮让位给 fill-0、按下 fill-1
        const n2 = make("Navigation { width: 240; height: 400; defaultSelectedKeys: ['a'];"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const top = findItems(n2)[0];
        compare(top.navInSub, false, "顶级条目不在 sub 作用域里");
        compare(top.bgColor, Theme.current.colorPrimaryLightDefault);
        mouseMove(top, top.width / 2, 18);
        tryVerify(function () { return top.hovered; }, 1000, "顶级条目悬浮");
        compare(top.bgColor, Theme.current.colorFill0, "顶级档：悬浮压过选中（官方如此，两档相反）");
        mouseMove(testCase, 2, 2);
    }

    function test_selectedDropdownItemKeepsSelectedStyle() {
        // 浮层里的选中条目同样「选中优先」，但机制是另一条：Item.tsx:247 给 Dropdown.Item 传
        // `active={selected}`，而悬浮/按下规则写的是 `.semi-dropdown-item:not(.semi-dropdown-item-active)`
        // ⇒ 选中那条被排除；popover 档的类名里也没有 `-normal`，`.semi-navigation-item-normal:hover…`
        // 那组同样够不着 ⇒ 底色恒 primary-light-default。字重反倒回到 600
        // （`.semi-dropdown-item-active { font-weight: 600 }`）。
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  defaultSelectedKeys: ['c1'];"
            + "  items: [ { itemKey: 'job', text: '任务平台',"
            + "    items: [ { itemKey: 'c1', text: 'C1' }, { itemKey: 'c2', text: 'C2' } ] } ] }");
        wait(150);
        const sub = findSubs(n)[0];
        const flyout = findPopups(sub).filter(function (p) { return p.position !== Enums.Right; })[0];
        flyout.visible = true;
        wait(150);
        const kids = findItems(flyout.contentItem);
        const sel = kids.filter(function (i) { return i.itemKey === "c1"; })[0];
        const plain = kids.filter(function (i) { return i.itemKey === "c2"; })[0];
        compare(sel.navInSub, true, "context 还是 isInSubNav");
        compare(sel.navInDropdown, true);
        compare(sel.bgColor, Theme.current.colorPrimaryLightDefault, "常态选中底");
        compare(sel.labelBold, true, "浮层里选中那条 600（-active）");
        mouseMove(sel, sel.width / 2, 18);
        tryVerify(function () { return sel.hovered; }, 1000, "浮层条目悬浮");
        compare(sel.bgColor, Theme.current.colorPrimaryLightDefault,
            "悬浮不许挤掉选中底（:not(-active) 把选中排除在外）");
        mousePress(sel, sel.width / 2, 18);
        wait(30);
        compare(sel.bgColor, Theme.current.colorPrimaryLightDefault, "按下也不挤掉");
        mouseRelease(testCase, 2, 2);
        wait(30);
        // 没选中的那条照旧走悬浮档
        compare(plain.labelBold, false, "未选中的浮层条目 400");
        mouseMove(plain, plain.width / 2, 18);
        tryVerify(function () { return plain.hovered; }, 1000, "未选中条目悬浮");
        compare(plain.bgColor, Theme.current.colorFill0);
        mouseMove(testCase, 2, 2);
    }

    function test_disabledSelectedOnlyKeepsBgInSubColumn() {
        // 「禁用+选中留选中底 + disabled-text」只有 sub 就地那一列成立；浮层与顶级 L1 都是
        // 透明底 + primary-disabled（`.semi-navigation-item-selected.semi-navigation-item-disabled`）
        const items = "[ { itemKey: 'c', text: 'C', disabled: true } ]";
        const inline = make("Navigation { width: 240; height: 400; defaultOpenKeys: ['job'];"
            + "  defaultSelectedKeys: ['c'];"
            + "  items: [ { itemKey: 'job', text: '任务平台', items: " + items + " } ] }");
        wait(150);
        const inlineItem = findItems(inline)[0];
        compare(inlineItem.navInSub, true);
        compare(inlineItem.navInDropdown, false);
        compare(inlineItem.bgColor, Theme.current.colorPrimaryLightDefault, "就地列：留选中底");
        compare(inlineItem.textColor, Theme.current.colorDisabledText, "就地列：字色 disabled-text");
        compare(inlineItem.iconColor, Theme.current.colorDisabledText);

        const fly = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  defaultSelectedKeys: ['c'];"
            + "  items: [ { itemKey: 'job', text: '任务平台', items: " + items + " } ] }");
        wait(150);
        const flyout = findPopups(findSubs(fly)[0])
            .filter(function (p) { return p.position !== Enums.Right; })[0];
        flyout.visible = true;
        wait(150);
        const flyItem = findItems(flyout.contentItem)[0];
        compare(flyItem.navInDropdown, true);
        compare(flyItem.selected, true);
        compare(flyItem.bgColor, Qt.rgba(0, 0, 0, 0), "浮层：禁用+选中回透明底");
        compare(flyItem.textColor, Theme.current.colorPrimaryDisabled, "浮层：字色 primary-disabled");
        compare(flyItem.iconColor, Theme.current.colorPrimaryDisabled);

        const top = make("Navigation { width: 240; height: 400; defaultSelectedKeys: ['a'];"
            + "  items: [ { itemKey: 'a', text: 'A', disabled: true } ] }");
        wait(80);
        const topItem = findItems(top)[0];
        compare(topItem.bgColor, Qt.rgba(0, 0, 0, 0), "顶级 L1：同浮层");
        compare(topItem.textColor, Theme.current.colorPrimaryDisabled);
    }

    function test_itemSkinSelectedDisabled() {
        const n = make("Navigation { width: 240; height: 400; defaultSelectedKeys: ['a'];"
            + "  items: [ { itemKey: 'a', text: 'A', disabled: true } ] }");
        wait(80);
        const item = findItems(n)[0];
        compare(item.selected, true);
        compare(item.bgColor, Qt.rgba(0, 0, 0, 0), "选中+禁用透明底");
        compare(item.textColor, Theme.current.colorPrimaryDisabled);
        compare(item.iconColor, Theme.current.colorPrimaryDisabled);
    }

    function test_itemSkinsHorizontal() {
        const n = make("Navigation { width: 600; height: 60; mode: Enums.DirectionHorizontal;"
            + "  items: [ { itemKey: 'a', text: 'A' }, { itemKey: 'b', text: 'B' } ] }");
        wait(80);
        const items = findItems(n);
        compare(items[0].bgColor, Qt.rgba(0, 0, 0, 0), "水平档恒透明底");
        compare(items[0].textColor, Theme.current.colorText2, "未选中 text-2");

        mouseMove(items[0], 6, 18);
        tryVerify(function () { return items[0].hovered; }, 1000, "hover 生效");
        compare(items[0].textColor, Theme.current.colorText1, "悬浮 text-1");
        compare(items[0].iconColor, Theme.current.colorText1);

        n.handleItemClick("a", "A", false, { itemKey: "a" });
        wait(30);
        compare(items[0].textColor, Theme.current.colorText0, "选中 text-0");
        compare(items[0].iconColor, Theme.current.colorText0);
        compare(items[0].bgColor, Qt.rgba(0, 0, 0, 0), "选中也无底色");
        mouseMove(testCase, 2, 2);
    }

    function test_subTitleSkins() {
        const n = make("Navigation { width: 240; height: 400; defaultSelectedKeys: ['p'];"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        compare(sub.titleSelectedSkin, true, "竖直 list 直属选中标题有专属皮肤");
        compare(sub.titleIconColor, Theme.current.colorPrimary, "选中标题图标 primary");
        compare(sub.titleBgColor, Qt.rgba(0, 0, 0, 0), "但底色 transparent（官方把 selected 底改回）");
        compare(sub.titleBold, true, "顶级标题 600");

        const n2 = make("Navigation { width: 240; height: 400; defaultSelectedKeys: ['q'];"
            + "  items: [ { itemKey: 'p', text: 'P', items: [ { itemKey: 'q', text: 'Q',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] } ] }");
        wait(80);
        const subs2 = findSubs(n2);
        compare(subs2[1].titleSelectedSkin, false, "嵌套 sub 选中无专属皮肤");
        compare(subs2[1].titleIconColor, Theme.current.colorText2, "嵌套选中图标不 primary");
        compare(subs2[1].titleBold, false, "嵌套标题 400");

        const n3 = make("Navigation { width: 240; height: 400; defaultSelectedKeys: ['p'];"
            + "  items: [ { itemKey: 'p', text: 'P', disabled: true,"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(80);
        const sub3 = findSubs(n3)[0];
        compare(sub3.titleTextColor, Theme.current.colorPrimaryDisabled,
            "选中+禁用的标题字色 primaryDisabled");
        compare(sub3.titleIconColor, Theme.current.colorPrimaryDisabled);
    }

    function test_collapsedHidesItemAndSubTitleText() {
        // navigation.scss `-collapsed .semi-navigation-item-text { opacity: 0 }` ——
        // 官方 SubNav 的标题文字用的就是同一个类名（SubNav.tsx renderTitleDiv），
        // 折叠档必须和普通条目一起隐掉；浮层里的条目 portal 在容器外，那条规则够不着
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  items: [ { itemKey: 'a', text: 'A' }, { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'q', text: 'Q',"
            + "      items: [ { itemKey: 'c', text: 'C' } ] } ] } ] }");
        wait(300);
        const subs = findSubs(n);
        compare(subs.length, 1, "nav 树里只剩顶级 sub（嵌套那只搬进浮层，Popup 不在 children 里）");
        compare(subs[0].titleTextOpacity, 0, "折叠档顶级 sub 标题文字隐掉");
        compare(findItems(n)[0].labelOpacity, 0, "普通条目同闸");
        const flyout = findPopups(subs[0]).filter(function (p) { return p.position !== Enums.Right; })[0];
        verify(flyout !== undefined, "找得到折叠浮层");
        const q = findSubs(flyout.contentItem)[0];
        verify(q !== undefined, "浮层里有嵌套 sub");
        compare(q.navInDropdown, true);
        compare(q.titleTextOpacity, 1, "浮层里的标题不受折叠规则影响（portal 在容器外）");

        const n2 = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(300);
        const fly2 = findPopups(findSubs(n2)[0])
            .filter(function (p) { return p.position !== Enums.Right; })[0];
        const c = findItems(fly2.contentItem)[0];
        verify(c !== undefined, "浮层里有普通条目");
        compare(c.navInDropdown, true);
        // 走树注入认 NavigationSub 的逻辑容器 ⇒ context 照样穿得过 portal（官方就是沿组件树）
        compare(c.navCollapsed, true, "浮层里的条目也吃到 isCollapsed context");
        compare(c.labelOpacity, 1, "但官方那条 CSS 够不着 ⇒ navInDropdown 压过 navCollapsed");

        const n3 = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: 'C' } ] } ] }");
        wait(300);
        compare(findSubs(n3)[0].titleTextOpacity, 1, "展开档标题文字可见");
        compare(findItems(n3)[0].labelOpacity, 1, "展开档条目文字可见");
    }

    function test_collapsedTextGatePrefersDropdown() {
        // 两条闸的优先关系单独钉：搬进浮层的条目 portal 在容器外，官方那条
        // `-collapsed .semi-navigation-item-text` 够不着 ⇒ navInDropdown 压过 navCollapsed。
        // （走树注入碰不到已被搬走的子项，所以这一档只能在属性层面钉）
        const sub = make("NavigationSub { itemKey: 'p'; text: 'P';"
            + "  navCollapsed: true; navInDropdown: false }");
        wait(30);
        compare(sub.titleTextOpacity, 0, "折叠 + 就地 ⇒ 隐字");
        sub.navInDropdown = true;
        compare(sub.titleTextOpacity, 1, "折叠 + 浮层 ⇒ 文字照常（浮层优先）");

        const item = make("NavigationItem { itemKey: 'a'; text: 'A';"
            + "  navCollapsed: true; navInDropdown: false }");
        wait(30);
        compare(item.labelOpacity, 0);
        item.navInDropdown = true;
        compare(item.labelOpacity, 1, "同闸，条目侧亦然");
    }

    function test_navShrinksWhenUserGivesNoWidth() {
        // 官方展开 240 / 收起 60 都来自类名；使用方不写内联宽度时才轮得到这两档
        //（gallery 各节此前硬写 width: 240 ⇒ 收起档缩不回去）
        const n = make("Navigation { height: 400; items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        compare(n.width, 240, "不给宽度时吃 implicitWidth 240");
        n.toggleCollapse();
        tryVerify(function () { return Math.abs(n.width - 60) < 0.01; }, 800,
            "收起档跟着 implicitWidth 缩到 60");
        n.toggleCollapse();
        tryVerify(function () { return Math.abs(n.width - 240) < 0.01; }, 800, "再展开回 240");
    }

    function test_itemCollapsedTooltipCondition() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const item = findItems(n)[0];
        const tip = findPopups(item)[0];
        compare(tip.condition, false, "展开档不挂 tooltip");
        n.toggleCollapse();
        wait(300);
        compare(tip.condition, true, "折叠的顶级项挂 tooltip（Item.tsx:303）");
        compare(tip.position, Enums.Right);
        compare(tip.text, "A", "tooltip 文案就是条目文案");
    }

    function test_itemInDropdownWidth() {
        const n = make("Navigation { width: 240; height: 400; defaultIsCollapsed: true;"
            + "  items: [ { itemKey: 'p', text: 'P',"
            + "    items: [ { itemKey: 'c', text: '短' } ] } ] }");
        wait(80);
        const sub = findSubs(n)[0];
        // 折叠档子项搬进浮层（Popup 的 contentItem 不在窗口 children 树里）
        const flyout = findPopups(sub).filter(function (p) { return p.position !== Enums.Right; })[0];
        verify(flyout !== undefined, "找得到折叠浮层");
        const item = findItems(flyout.contentItem)[0];
        compare(item.navInDropdown, true, "折叠浮层里的条目标记 navInDropdown");
        compare(item.width, 150, "浮层里 min-width 150");
    }

    // ---------------------------------------------------------------- header / footer
    function test_headerPaddingsAndCollapsed() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  header: NavigationHeader {"
            + "    logo: Component { Item { } }"
            + "    text: 'Semi 运营后台' }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const header = n.header[0];
        compare(header.paddingXLeft, 3.5, "(60 − 16 − 1 − 36) × 0.5");
        compare(header.paddingXRight, 8);
        compare(header.implicitHeight, 36 + 32 + 36, "logo 撑满 + 上 32 下 36");
        // headerRow 的子项：logoHost（Item）+ 标题 Text；按有无 text 属性区分
        const kids = header.children[0].children;
        const texts = kids.filter(function (c) { return c.text !== undefined; });
        compare(texts.length, 1, "标题是唯一带 text 的子项");
        compare(texts[0].visible, true, "展开档标题渲染");

        n.toggleCollapse();
        wait(300);
        compare(header.collapsed, true, "走树注入收起态");
        compare(header.paddingXRight, 0, "收起档 right 归 0");
        compare(texts[0].visible, false, "收起档标题直接不渲染（Header.tsx:63）");
    }

    function test_footerBuiltInCollapseConditions() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  footer: NavigationFooter { collapseButton: true }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        compare(n.footer[0].showBuiltInCollapse, true, "给了 collapseButton 且无 children");

        const n2 = make("Navigation { width: 240; height: 400;"
            + "  footer: NavigationFooter { collapseButton: true;"
            + "    Rectangle { implicitWidth: 10; implicitHeight: 10 } }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        compare(n2.footer[0].showBuiltInCollapse, false, "有 children 就不渲染内置按钮");

        const n3 = make("Navigation { width: 600; height: 60; mode: Enums.DirectionHorizontal;"
            + "  footer: NavigationFooter { collapseButton: true }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        compare(n3.footer[0].showBuiltInCollapse, false, "水平档不渲染收起按钮");
    }

    function test_collapseButtonLabels() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  footer: NavigationFooter { collapseButton: true }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const btn = findByType(n, "NavigationCollapseButton");
        verify(btn !== null, "内置收起按钮已装载");
        compare(btn.label, "收起侧边栏", "缺省吃 locale 中文");
        n.toggleCollapse();
        wait(300);
        compare(btn.label, "展开侧边栏");

        const n2 = make("Navigation { width: 240; height: 400;"
            + "  footer: NavigationFooter { collapseButton: true;"
            + "    collapseText: function (c) { return c ? 'open' : 'close'; } }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        compare(findByType(n2, "NavigationCollapseButton").label, "close",
            "collapseText 函数整档接管文案");
    }

    function test_collapseButtonRealClickFlips() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  footer: NavigationFooter { collapseButton: true }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const cspy = spyOn(n, "collapseChange");
        const btn = findByType(n, "NavigationCollapseButton");
        const inner = findByType(btn, "Button");
        verify(inner !== null, "按钮壳里是 Button");
        tryVerify(function () { return inner.width > 0 && inner.height > 0; }, 1000, "按钮装载完");
        mouseClick(inner, inner.width / 2, inner.height / 2);
        wait(300);
        compare(n._isCollapsed, true, "按钮点击经 toggleCollapse 翻转容器");
        compare(cspy.count, 1);
    }

    function test_footerClickedSignal() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  footer: NavigationFooter { collapseButton: true }"
            + "  items: [ { itemKey: 'a', text: 'A' } ] }");
        wait(80);
        const fspy = spyOn(n.footer[0], "clicked");
        const inner = findByType(findByType(n, "NavigationCollapseButton"), "Button");
        tryVerify(function () { return inner.width > 0 && inner.height > 0; }, 1000, "按钮装载完");
        mouseClick(inner, inner.width / 2, inner.height / 2);
        wait(50);
        compare(fspy.count, 1, "footer div 的 onClick 也发（官方两层都收）");
    }

    // ---------------------------------------------------------------- children 档
    function test_childrenModeSelection() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  NavigationItem { itemKey: 'a'; text: 'A' }"
            + "  NavigationSub { itemKey: 'p'; text: 'P';"
            + "    NavigationItem { itemKey: 'c'; text: 'C' } } }");
        wait(80);
        const items = findItems(n);
        const subs = findSubs(n);
        compare(items.length, 2);
        compare(subs.length, 1);
        sameArray(n._itemKeysMap, { "a": [], "p": [], "c": ["p"] }, "children 档也建表");
        n.handleItemClick("c", "C", false, { itemKey: "c" });
        sameArray(n._selectedKeys, ["c", "p"], "children 档嵌套选中拼父 key");
        compare(subs[0].isOpen, false, "点子项不自动开父 sub（官方也不开）");
    }

    function test_childrenModeSubToggleInline() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  NavigationSub { itemKey: 'p'; text: 'P';"
            + "    NavigationItem { itemKey: 'c'; text: 'C' } } }");
        wait(80);
        const sub = findSubs(n)[0];
        n.handleSubClick("p");
        compare(sub.isOpen, true, "children 档 sub 照样走容器状态机");
        sameArray(n._openKeys, ["p"]);
    }

    function test_itemsChangeResetsSelection() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' }, { itemKey: 'b', text: 'B' } ] }");
        wait(80);
        n.handleItemClick("b", "B", false, { itemKey: "b" });
        sameArray(n._selectedKeys, ["b"]);
        n.items = [ { itemKey: "z", text: "Z" } ];
        wait(60);
        sameArray(n._selectedKeys, [], "items 变化整个 init 重来，非受控选中也被打回（官方坑）");
        const items = findItems(n);
        compare(items.length, 1);
        compare(items[0].itemKey, "z");
        compare(items[0].selected, false);
    }

    function test_realClickSelects() {
        const n = make("Navigation { width: 240; height: 400;"
            + "  items: [ { itemKey: 'a', text: 'A' }, { itemKey: 'b', text: 'B' } ] }");
        wait(80);
        const items = findItems(n);
        const ay = n.mapFromItem(items[0], 0, 0).y;
        const by = n.mapFromItem(items[1], 0, 0).y;
        tryVerify(function () { return by > ay; }, 1000, "位置器排布完");
        mouseClick(items[1], 30, 18);
        wait(30);
        sameArray(n._selectedKeys, ["b"], "条目上的真实点击走到 handleItemClick");
        compare(items[1].selected, true);
    }
}
