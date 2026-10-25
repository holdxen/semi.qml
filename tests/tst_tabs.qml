import QtQuick
import QtTest
import Semi

// Tabs / TabPane / TabItem 标签页。规格照 packages/semi-ui/tabs/{index.tsx,TabBar.tsx,
// TabItem.tsx,TabPane.tsx} + packages/semi-foundation/tabs/{foundation.ts,constants.ts,
// tabs.scss,variables.scss,animation.scss}，数值对着编译产物 semi.css 21854-22609 段。
//
// 端口口径（完整清单在 src/Tabs.qml / src/TabItem.qml / src/TabPane.qml 头注释）：
//   · 四档 type（缺省 line）× 三档 size（缺省 large）× 两档 tabPosition，指示条是格子自己的
//     2px 边框，没有 ink bar；card 的「擦基线」是把下边涂成 bg-1。
//   · 两条数据来源：tabList 数组档只出标签栏、零面板；TabPane 子元素档同时出标签与面板。
//   · change / tabClick / tabClose / visibleTabsChange 是信号；官方那三条回调带的 React
//     事件对象端口不带。
//   · 键盘方向键只挪焦点不激活；Enter / Space 才激活且**不判 disabled**；Delete / Backspace
//     只在那格 closable 时走关闭，且只剩一格时跳过挪焦点 —— 全是上游行为，逐条钉。
//   · 唯一有动画的是面板入场（200ms ease-in-out、±60px + 透明度），标签栏全 0ms。
//
// 断言一律走「给定的容器宽 + 端口自己算出来的格子宽」，不写死字体度量。
TestCase {
    id: testCase

    name: "Tabs"
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
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "tabs");
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 0.01,
               (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    function cell(t, i) {
        const list = t.cells();
        verify(i < list.length, "标签栏里要有第 " + i + " 格（实有 " + list.length + "）");
        return list[i];
    }

    function part(item, name) {
        const found = testCase.findChild(item, name);
        verify(found !== null, "格子里要有 " + name);
        return found;
    }

    function paneOf(t, i) {
        verify(i < t.count, "要有第 " + i + " 项");
        return t.items[i].pane;
    }

    // 三格一条龙的公共片段（子元素档）
    readonly property string threePanes: '; TabPane { itemKey: "a"; tab: "甲"; Text { text: "A" } }'
        + ' TabPane { itemKey: "b"; tab: "乙"; Text { text: "B" } }'
        + ' TabPane { itemKey: "c"; tab: "丙"; Text { text: "C" } }';

    property var signalLog: []

    function spyOn(t) {
        testCase.signalLog = [];
        t.change.connect(function (k) { testCase.signalLog.push("change:" + k); });
        t.tabClick.connect(function (k) { testCase.signalLog.push("click:" + k); });
        t.tabClose.connect(function (k) { testCase.signalLog.push("close:" + k); });
    }

    // ---------------- 属性面与缺省 ----------------

    function test_officialPropDefaults() {
        const t = make("Tabs { }");
        compare(t.type, "line", "index.tsx:72 defaultProps");
        compare(t.size, "large", "index.tsx:69 —— 缺省是 large 不是 medium");
        compare(t.tabPosition, "top");
        compare(t.keepDOM, true);
        compare(t.lazyRender, false);
        compare(t.tabPaneMotion, true);
        compare(t.collapsible, false);
        compare(t.showRestInDropdown, true);
        compare(t.arrowPosition, "both", "文档表里写「无」是 stale，代码缺省 both");
        compare(t.preventScroll, false);
        compare(t.more, undefined);
        verify(t.activeKey === undefined, "activeKey 官方没给缺省");
        verify(t.defaultActiveKey === undefined, "defaultActiveKey 也没有（文档那条 '1' 是 stale）");
        verify(t.tabList === undefined);
        compare(t.count, 0);
        compare(t.currentKey, "");
        t.destroy();
    }

    function test_tabPanePropDefaults() {
        const p = make("TabPane { }");
        compare(p.tab, "");
        compare(p.icon, "");
        compare(p.itemKey, "");
        compare(p.disabled, false);
        compare(p.closable, false);
        compare(p.tabIndex, 0);
        verify(p.host === null, "落在宿主外不认宿主");
        compare(p.hostActive, false);
        p.destroy();
    }

    function test_sizeLargeEmitsNoVariant() {
        // TabItem.tsx:80-81 只给 small/medium 挂类名 ⇒ large 走「无 size 类名」那条默认
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" }] }');
        near(t.itemHeight, 52, "line/top large 高 52（16 + 20 + 14 + 2）");
        t.size = "medium";
        near(t.itemHeight, 44);
        t.size = "small";
        near(t.itemHeight, 36);
        t.destroy();
    }

    function test_verticalLineHeightsFollowSize() {
        const cases = [["large", 44], ["medium", 40], ["small", 32]];
        for (let i = 0; i < cases.length; ++i) {
            const t = make('Tabs { width: 300; tabPosition: "left"; size: "' + cases[i][0]
                + '"; tabList: [{ itemKey: "a", tab: "甲" }] }');
            near(t.itemHeight, cases[i][1], "line/left " + cases[i][0]);
            near(cell(t, 0).implicitHeight, cases[i][1], "格子自己也得算出这个高");
            t.destroy();
        }
    }

    function test_sizeDoesNothingForCardButtonSlash() {
        const types = ["card", "button", "slash"];
        const fixed = [37, 36, 44];
        for (let i = 0; i < types.length; ++i) {
            const t = make('Tabs { width: 600; type: "' + types[i]
                + '"; size: "small"; tabList: [{ itemKey: "a", tab: "甲" }] }');
            near(t.itemHeight, fixed[i], types[i] + " 档三档 size 同值（semi.css 里没有 size 变体）");
            t.destroy();
        }
    }

    // ---------------- 收养：两条数据来源 ----------------

    function test_adoptsTabPaneChildrenInOrder() {
        const t = make('Tabs { width: 600' + testCase.threePanes + ' }');
        compare(t.count, 3);
        compare(t.items[0].itemKey, "a");
        compare(t.items[2].itemKey, "c");
        for (let i = 0; i < 3; ++i)
            verify(paneOf(t, i).host === t, "第 " + i + " 张面板要认宿主");
        compare(cell(t, 0).itemKey, "a");
        compare(cell(t, 2).hostLast, true);
        t.destroy();
    }

    function test_tabListWinsAndChildrenUnadopted() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "x", tab: "数组甲" }]'
            + '; TabPane { itemKey: "a"; tab: "子元素甲" } }');
        compare(t.listMode, true);
        compare(t.count, 1);
        compare(t.items[0].itemKey, "x");
        let orphan = null;
        for (let i = 0; i < t.children.length; ++i)
            if (t.children[i].isTabPane === true)
                orphan = t.children[i];
        verify(orphan !== null, "声明式那张面板还挂在容器上");
        verify(orphan.host === null, "数组档赢 ⇒ 子元素整条不读");
        compare(orphan.visible, false, "没宿主就没有激活位 ⇒ 不画");
        t.destroy();
    }

    function test_tabListPathHasNoPanes() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }] }');
        compare(t.count, 2);
        verify(t.items[0].pane === null, "PlainTab 没有内容字段 ⇒ 零面板");
        near(t.activePaneHeight, 0);
        near(t.implicitHeight, t.itemHeight + 10, "没有面板就只剩标签栏 + 那 10 的内容区内边距");
        t.destroy();
    }

    function test_tabListReadsEveryField() {
        const t = make('Tabs { width: 600; tabList: ['
            + '{ itemKey: "a", tab: "甲", icon: "mail_stroked", disabled: true, closable: true },'
            + '{ itemKey: "b", tab: "乙" }] }');
        const c0 = cell(t, 0);
        compare(c0.label, "甲");
        compare(c0.iconValue, "mail_stroked");
        compare(c0.disabled, true);
        compare(c0.closable, true);
        const c1 = cell(t, 1);
        compare(c1.disabled, false, "没给的键就是缺省");
        compare(c1.closable, false);
        t.destroy();
    }

    function test_keylessEntryFallsBackToIndex() {
        const t = make('Tabs { width: 600; tabList: [{ tab: "甲" }, { tab: "乙" }] }');
        compare(t.items[0].itemKey, "0");
        compare(t.items[1].itemKey, "1");
        compare(t.currentKey, "0", "退出来的键也要能当激活位用");
        t.destroy();
    }

    function test_nullEntryIsSkipped() {
        const t = make('Tabs { width: 600; tabList: [{ tab: "甲" }, null, { tab: "丙" }] }');
        compare(t.count, 2, "官方那一档会把 undefined 塞进 panes 随后抛，端口收成没有这一格");
        compare(t.items[1].tab, undefined);
        compare(t.items[1].label, "丙");
        t.destroy();
    }

    function test_repeaterPanesKeepModelOrder() {
        const t = make('Tabs { width: 420; type: "card"; Repeater { model: 6;'
            + ' delegate: TabPane { required property int index; itemKey: "K-" + index;'
            + ' tab: "T" + index } } }');
        wait(60);
        compare(t.count, 6);
        compare(t.items[0].itemKey, "K-0");
        compare(t.items[5].itemKey, "K-5");
        compare(t.currentKey, "K-0", "逐张加进来时不能把激活位漂到最后一张");
        t.destroy();
    }

    // ---------------- 激活位 ----------------

    function test_defaultActiveKeyWins() {
        const t = make('Tabs { width: 600; defaultActiveKey: "b"' + testCase.threePanes + ' }');
        compare(t.currentKey, "b");
        compare(t.activeIndex, 1);
        compare(cell(t, 1).hostSelected, true);
        compare(cell(t, 0).hostSelected, false);
        t.destroy();
    }

    function test_activeKeyBeatsDefaultActiveKey() {
        const t = make('Tabs { width: 600; activeKey: "b"; defaultActiveKey: "a"'
            + testCase.threePanes + ' }');
        compare(t.currentKey, "b", "getDefaultActiveKey 第一眼看的就是 activeKey");
        t.destroy();
    }

    function test_nullActiveKeyCountsAsUncontrolled() {
        // index.tsx:146 判的是 `!isNullOrUndefined(props.activeKey)` ⇒ null 等于没给
        const t = make('Tabs { width: 600; activeKey: null; tabList: ['
            + '{ itemKey: "a", tab: "甲" }, { itemKey: "b", tab: "乙" }] }');
        compare(t.activeGiven, false);
        compare(t.currentKey, "a");
        t.handleClick("b");
        compare(t.currentKey, "b", "null 不算受控 ⇒ 内部自己跳");
        t.destroy();
    }

    function test_firstNonDisabledWhenNothingGiven() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲", disabled: true },'
            + ' { itemKey: "b", tab: "乙" }] }');
        compare(t.currentKey, "b", "getDefaultActiveKeyFromChildren 取第一个没禁用的");
        t.destroy();
    }

    function test_controlledKeyDoesNotMoveInternally() {
        const t = make('Tabs { width: 600; activeKey: "a"' + testCase.threePanes + ' }');
        spyOn(t);
        t.handleClick("c");
        compare(t.currentKey, "a", "受控档内部不改");
        verify(testCase.signalLog.indexOf("click:c") >= 0, "tabClick 照发");
        verify(testCase.signalLog.indexOf("change:c") < 0, "受控档不发 change");
        t.activeKey = "c";
        compare(t.currentKey, "c", "使用方回灌才动");
        t.destroy();
    }

    function test_uncontrolledClickEmitsChange() {
        const t = make('Tabs { width: 600' + testCase.threePanes + ' }');
        spyOn(t);
        t.handleClick("b");
        compare(t.currentKey, "b");
        verify(testCase.signalLog.indexOf("click:b") >= 0);
        verify(testCase.signalLog.indexOf("change:b") >= 0);
        verify(testCase.signalLog.indexOf("change:b") > testCase.signalLog.indexOf("click:b"),
            "官方是先 notifyTabClick 再 setNewActiveKey ⇒ 顺序也照抄");
        t.destroy();
    }

    function test_clickOnCurrentKeyIsSilent() {
        const t = make('Tabs { width: 600' + testCase.threePanes + ' }');
        spyOn(t);
        t.handleClick("a");
        verify(testCase.signalLog.indexOf("click:a") >= 0, "tabClick 每次都发");
        verify(testCase.signalLog.indexOf("change:a") < 0, "同键不发 change");
        t.destroy();
    }

    function test_reseatFallsBackToFirstAndStaysSilent() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }, { itemKey: "c", tab: "丙" }] }');
        t.handleClick("c");
        compare(t.currentKey, "c");
        spyOn(t);
        t.tabList = [{ itemKey: "a", tab: "甲" }, { itemKey: "b", tab: "乙" }];
        compare(t.currentKey, "a", "激活位漂了 ⇒ 退成**第一项**，不是相邻项（index.tsx:109-115）");
        compare(testCase.signalLog.length, 0, "而且这一退**不发 change**");
        t.destroy();
    }

    function test_reseatToEmptyWhenAllGone() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" }] }');
        t.tabList = [];
        compare(t.currentKey, "");
        compare(t.count, 0);
        compare(t.listMode, false, "空数组不等于「走了数组档」—— 那条 length > 0 的判据要有人钉");
        t.destroy();
    }

    // ---------------- 关闭 ----------------

    function test_closeOnlyNotifies() {
        const t = make('Tabs { width: 600; type: "card"; tabList: ['
            + '{ itemKey: "a", tab: "甲", closable: true }, { itemKey: "b", tab: "乙" }] }');
        spyOn(t);
        t.handleDelete("a");
        verify(testCase.signalLog.indexOf("close:a") >= 0);
        compare(t.count, 2, "onTabClose **从不真的关闭**（foundation.ts:71-73）");
        compare(t.currentKey, "a", "也不换激活位");
        t.destroy();
    }

    function test_closeMarkIsDrawnForEveryType() {
        const types = ["line", "card", "button", "slash"];
        for (let i = 0; i < types.length; ++i) {
            const t = make('Tabs { width: 600; type: "' + types[i] + '"; tabList: ['
                + '{ itemKey: "a", tab: "甲", closable: true }] }');
            compare(part(cell(t, 0), "tabItemClose").visible, true,
                types[i] + " 档也出 ×（文档那句「只有卡片式支持关闭」与代码不符）");
            t.destroy();
        }
    }

    function test_closeMarkGeometryAndColor() {
        const t = make('Tabs { width: 600; type: "card"; tabList: ['
            + '{ itemKey: "a", tab: "甲", closable: true }] }');
        const c = cell(t, 0);
        const mark = part(c, "tabItemClose");
        compare(mark.size, 14, "CSS:21923 font-size 14 ⇒ 14×14");
        near(mark.x, c.padLeft + c.textWidth + 10, "margin-left 10");
        compare(mark.color, Theme.current.colorText2,
            "选中那格的 × 被显式钉回 text-2，不跟文字变 primary（CSS:21948-21950）");
        t.destroy();
    }

    // ---------------- 标签栏几何 ----------------

    function test_gapPerTypeAndPosition() {
        const cases = [["line", "top", 24], ["line", "left", 0], ["card", "top", 8],
            ["button", "top", 8], ["slash", "top", 16]];
        for (let i = 0; i < cases.length; ++i) {
            const t = make('Tabs { width: 600; type: "' + cases[i][0] + '"; tabPosition: "'
                + cases[i][1] + '"; tabList: [{ itemKey: "a", tab: "甲" },'
                + ' { itemKey: "b", tab: "乙" }] }');
            near(t.itemGap, cases[i][2], cases[i][0] + "/" + cases[i][1] + " 的格间距");
            t.destroy();
        }
    }

    function test_cellsPackWithGapsAndLastHasNoGap() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲甲" },'
            + ' { itemKey: "b", tab: "乙乙" }, { itemKey: "c", tab: "丙丙" }] }');
        const c0 = cell(t, 0);
        const c1 = cell(t, 1);
        near(c1.x, c0.x + c0.implicitWidth + 24, "行距 = 上一格宽 + 24（:not(:last-of-type)）");
        const flow = testCase.findChild(t.barBox, "tabsBarRow");
        verify(flow !== null, "横排那一条是 Row");
        near(flow.spacing, 24);
        t.destroy();
    }

    function test_indicatorIsFullCellWidthAndTwoTall() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }] }');
        const c = cell(t, 0);
        const bar = part(c, "tabItemIndicator");
        compare(bar.visible, true);
        near(bar.height, 2, "$width-tabs_bar_line_tab-border");
        near(bar.width, c.width, "指示条铺满含内边距的整格宽（**没有内缩、没有圆角**）");
        near(bar.y, c.height - 2);
        near(c.implicitHeight, 52, "16 + 20 + 14 + 2 = 52（下内边距让那 2px）");
        near(c.padBottom, 14);
        t.destroy();
    }

    function test_verticalIndicatorIsTheLeftEdge() {
        const t = make('Tabs { width: 300; tabPosition: "left"; tabList:'
            + ' [{ itemKey: "a", tab: "甲" }] }');
        const c = cell(t, 0);
        const bar = part(c, "tabItemIndicator");
        near(bar.width, 2);
        near(bar.height, c.height);
        near(bar.x, 0);
        t.destroy();
    }

    function test_indicatorColorStates() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }] }');
        compare(part(cell(t, 0), "tabItemIndicator").color, Theme.current.colorPrimary);
        compare(part(cell(t, 1), "tabItemIndicator").color, Qt.rgba(0, 0, 0, 0),
            "未选中是 transparent（官方那条边框就是 transparent，不是没画）");
        t.destroy();
    }

    function test_baselineFollowsType() {
        const cases = [["line", true], ["card", true], ["button", false], ["slash", false]];
        for (let i = 0; i < cases.length; ++i) {
            const t = make('Tabs { width: 600; type: "' + cases[i][0]
                + '"; tabList: [{ itemKey: "a", tab: "甲" }] }');
            compare(part(t.barBox, "tabsBarBaseline").visible, cases[i][1],
                cases[i][0] + " 档" + (cases[i][1] ? "有" : "没有") + "基线");
            t.destroy();
        }
    }

    function test_firstCellDropsItsLeftPaddingOnlyHorizontally() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "甲" }] }');
        const first = cell(t, 0);
        const second = cell(t, 1);
        near(first.padLeft, 0, ":nth-of-type(1) 清掉左内边距");
        near(second.padLeft, 4);
        near(second.implicitWidth - first.implicitWidth, 4);
        t.destroy();
        const v = make('Tabs { width: 300; tabPosition: "left"; tabList:'
            + ' [{ itemKey: "a", tab: "甲" }, { itemKey: "b", tab: "甲" }] }');
        near(cell(v, 0).padLeft, 12, "竖排那一档首格**不**清左内边距（四边同值 12）");
        near(cell(v, 0).padTop, 12);
        v.destroy();
    }

    function test_extraSlotHeightAndOnlyForLine() {
        const line = make('Tabs { width: 600; tabBarExtraContent: extraBox;'
            + ' tabList: [{ itemKey: "a", tab: "甲" }] }');
        near(line.extraHeight, 50, "CSS:22176-22179 只给 line 档一个 50");
        line.size = "small";
        near(line.extraHeight, 36, "只有 -extra-small 那一档改 36");
        line.destroy();
        const btn = make('Tabs { width: 600; type: "button"; tabBarExtraContent: extraBox;'
            + ' tabList: [{ itemKey: "a", tab: "甲" }] }');
        near(btn.extraHeight, 0, "card / button / slash 那一档 extra 没有高度规则");
        btn.destroy();
    }

    Component {
        id: extraBox

        Item {
            implicitWidth: 80
            implicitHeight: 24
        }
    }

    function test_extraSlotSitsAtTheRightEdge() {
        const t = make('Tabs { width: 600; tabBarExtraContent: extraBox;'
            + ' tabList: [{ itemKey: "a", tab: "甲" }] }');
        const slot = testCase.findChild(t.barBox, "tabsExtraSlot");
        verify(slot !== null, "extra 槽要在");
        near(slot.x + slot.width + 5, 600, "官方 float:right ⇒ 端口贴右");
        near(t.extraPadX, 5, "CSS:21871 padding 0 5px");
        near(t.extraSlotWidth, 90, "槽宽 = 内容 80 + 左右各 5（决定折叠档的可用宽）");
        t.destroy();
    }

    // ---------------- 格子颜色 ----------------

    function test_lineTextColors() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }, { itemKey: "c", tab: "丙", disabled: true }] }');
        compare(part(cell(t, 0), "tabItemLabel").color, Theme.current.colorText0, "选中 text-0");
        compare(part(cell(t, 1), "tabItemLabel").color, Theme.current.colorText2, "未选中 text-2");
        compare(part(cell(t, 2), "tabItemLabel").color, Theme.current.colorDisabledText);
        t.destroy();
    }

    function test_hoverAndPressRepaintTheLabel() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }] }');
        const idle = cell(t, 1);
        compare(part(idle, "tabItemLabel").color, Theme.current.colorText2, "起手 text-2");
        testCase.mouseMove(idle, 6, idle.height / 2);
        wait(40);
        if (!idle.hovered) {
            skip("这一档平台合成不出悬浮态");
            t.destroy();
            return;
        }
        compare(part(idle, "tabItemLabel").color, Theme.current.colorText0,
            "CSS:21929 悬浮染 text-0");
        compare(part(idle, "tabItemIndicator").color, Theme.current.colorFill0,
            "未选中格悬浮时那条边是 fill-0");
        testCase.mouseMove(t, 2, 2);
        wait(40);
        t.destroy();
    }

    function test_selectedWeightIsSixHundred() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }] }');
        compare(part(cell(t, 0), "tabItemLabel").font.weight, Font.DemiBold, "600");
        compare(part(cell(t, 1), "tabItemLabel").font.weight, Font.Normal, "400");
        t.destroy();
    }

    function test_buttonSelectedPaintsPrimaryAndLightBg() {
        const t = make('Tabs { width: 600; type: "button"; tabList:'
            + ' [{ itemKey: "a", tab: "甲" }, { itemKey: "b", tab: "乙" }] }');
        compare(part(cell(t, 0), "tabItemLabel").color, Theme.current.colorPrimary);
        compare(part(cell(t, 0), "tabItemBackground").color,
            Theme.current.colorPrimaryLightDefault);
        compare(part(cell(t, 1), "tabItemLabel").color, Theme.current.colorText2,
            "CSS:22265 未选中显式重写了一遍 text-2");
        compare(part(cell(t, 1), "tabItemBackground").color, Qt.rgba(0, 0, 0, 0));
        t.destroy();
    }

    function test_lineTopHasNoBackgroundButLineLeftDoes() {
        const top = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" }] }');
        compare(part(cell(top, 0), "tabItemBackground").color, Qt.rgba(0, 0, 0, 0),
            "line/top 压根没有背景规则");
        top.destroy();
        const left = make('Tabs { width: 300; tabPosition: "left"; tabList:'
            + ' [{ itemKey: "a", tab: "甲" }] }');
        compare(part(cell(left, 0), "tabItemBackground").color,
            Theme.current.colorPrimaryLightDefault, "line/left 选中吃 primary-light");
        left.destroy();
    }

    function test_cardBorderAndBaselineMask() {
        const t = make('Tabs { width: 600; type: "card"; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }] }');
        const sel = cell(t, 0);
        const un = cell(t, 1);
        compare(part(sel, "tabItemBackground").border.color, Theme.current.colorBorder);
        compare(part(un, "tabItemBackground").border.color, Qt.rgba(0, 0, 0, 0),
            "未选中是 1px transparent —— 照样占位");
        compare(part(sel, "tabItemBaselineMask").visible, true);
        compare(part(sel, "tabItemBaselineMask").color, Theme.current.colorBg1,
            "「擦掉基线」是把下边涂成 bg-1（CSS:22206）");
        compare(part(un, "tabItemBaselineMask").visible, false);
        compare(part(sel, "tabItemBackground").topLeftRadius, 3, "圆角只给上面两角");
        compare(part(sel, "tabItemBackground").bottomLeftRadius, 0);
        t.destroy();
    }

    function test_cardTopIsThreeSevenTall() {
        const t = make('Tabs { width: 600; type: "card"; tabList: [{ itemKey: "a", tab: "甲" }] }');
        near(t.itemHeight, 37, "1 边框 + 8 + 20 + 8 = 37");
        near(cell(t, 0).padBottom, 8, "未选中下内边距 8");
        t.destroy();
    }

    function test_iconSlotGeometryAndColor() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲", icon: "mail_stroked" },'
            + ' { itemKey: "b", tab: "乙", icon: "mail_stroked" }] }');
        const sel = cell(t, 0);
        const idle = cell(t, 1);
        compare(part(sel, "tabItemIconName").size, 16, "缺省 em 盒 16");
        near(part(sel, "tabItemIconName").x, sel.padLeft);
        near(part(sel, "tabItemIconName").y, sel.padTop + 2 + 3, "top:3px 那点相对位移");
        near(part(sel, "tabItemLabel").x - part(sel, "tabItemIconName").x, 24,
            "图标 16 + margin-right 8");
        compare(part(sel, "tabItemIconName").color, Theme.current.colorPrimary,
            "选中那格的图标染 primary（CSS:21945-21947）");
        compare(part(idle, "tabItemIconName").color, Theme.current.colorText2);
        t.destroy();
    }

    function test_slashOnlyOnNonLastAndItsBox() {
        const t = make('Tabs { width: 600; type: "slash"; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }] }');
        const first = cell(t, 0);
        compare(part(first, "tabItemSlash").visible, true);
        near(part(first, "tabItemSlash").width, Math.sqrt(8 * 8 + 14 * 14),
            "8×14 盒子里那条对角线 = 盒子对角长");
        near(part(first, "tabItemSlash").height, 2, "渐变 ±1px ⇒ 2px 粗");
        compare(part(first, "tabItemSlash").color, Theme.current.colorText2,
            "恒 text-2，四档状态都不改（CSS:22304）");
        verify(part(first, "tabItemSlash").rotation > 45 && part(first, "tabItemSlash").rotation < 90,
            "to bottom right ⇒ 顺时针 60° 左右（实得 " + part(first, "tabItemSlash").rotation + "）");
        compare(part(cell(t, 1), "tabItemSlash").visible, false, ":not(:last-of-type)");
        t.destroy();
    }

    // ---------------- 面板与内容区 ----------------

    function test_onlyActivePaneIsVisible() {
        const t = make('Tabs { width: 600' + testCase.threePanes + ' }');
        compare(paneOf(t, 0).visible, true);
        compare(paneOf(t, 1).visible, false, "官方 -pane-inactive{display:none}");
        compare(paneOf(t, 2).visible, false);
        t.handleClick("b");
        compare(paneOf(t, 0).visible, false);
        compare(paneOf(t, 1).visible, true);
        t.destroy();
    }

    function test_panesStackAtTheSameBox() {
        const t = make('Tabs { width: 600' + testCase.threePanes + ' }');
        const p0 = paneOf(t, 0);
        const p1 = paneOf(t, 1);
        near(p0.x, p1.x);
        near(p0.y, p1.y);
        near(p0.width, p1.width);
        near(p0.y, t.itemHeight + 5, "内容区 top padding 5（CSS:22306-22309）");
        near(p0.x, 0);
        t.destroy();
    }

    function test_verticalContentSitsBesideTheBar() {
        const t = make('Tabs { width: 300; height: 200; tabPosition: "left"'
            + testCase.threePanes + ' }');
        const p = paneOf(t, 0);
        verify(t.barWidth > 0, "竖排的标签栏宽要量得出来");
        near(p.x, t.barWidth + 5, "竖排内容区左右各 5");
        near(p.y, 0);
        t.destroy();
    }

    function test_keepDOMAndLazyRenderCollapseToVisibility() {
        // 官方那两条是「不进 DOM / 推迟进 DOM」；QML 的内联子项没法推迟创建，而
        // `-pane-inactive { display: none }` 已经把非激活那块整个收掉 ⇒ 四档组合的可观察
        // 行为同一条：只有激活那一块看得见。端口因此不留第二道守卫（留了也打不红）。
        const combos = [["true", "false"], ["false", "false"], ["true", "true"], ["false", "true"]];
        for (let i = 0; i < combos.length; ++i) {
            const t = make('Tabs { width: 600; keepDOM: ' + combos[i][0] + '; lazyRender: '
                + combos[i][1] + testCase.threePanes + ' }');
            compare(paneOf(t, 0).visible, true, combos[i].join("/") + " 档：激活那张要看得见");
            compare(paneOf(t, 1).visible, false, combos[i].join("/") + " 档：非激活那张要看不见");
            t.handleClick("b");
            compare(paneOf(t, 0).visible, false);
            compare(paneOf(t, 1).visible, true);
            t.destroy();
        }
    }

    function test_paneMotionAxisAndDirection() {
        const h = make('Tabs { width: 600' + testCase.threePanes + ' }');
        h.handleClick("c");
        near(paneOf(h, 2).motionFromX, -60, "往后翻 ⇒ 从左边 60px 外进来（leftShow）");
        near(paneOf(h, 2).motionFromY, 0);
        h.handleClick("a");
        near(paneOf(h, 0).motionFromX, 60, "往回翻 ⇒ 从右边进来（rightShow）");
        h.destroy();
        const v = make('Tabs { width: 300; height: 300; tabPosition: "left"'
            + testCase.threePanes + ' }');
        v.handleClick("b");
        near(paneOf(v, 1).motionFromX, 0, "竖排换成 Y 轴（topShow / bottomShow）");
        near(paneOf(v, 1).motionFromY, -60);
        v.destroy();
    }

    function test_autoCollapseBoundaryIsStrictlyOverOnePixel() {
        const t = make('Tabs { width: 600; collapsible: "auto"; tabList: ['
            + '{ itemKey: "a", tab: "标签甲" }, { itemKey: "b", tab: "标签乙" }] }');
        wait(40);
        const natural = t.barNaturalLen;
        verify(natural > 0, "先要量到自然宽（实得 " + natural + "）");
        t.width = natural;
        wait(40);
        compare(t.autoCollapsed, false, "刚好放得下 ⇒ 不折（判据是 > 宽 + 1）");
        t.width = natural + 1;
        wait(40);
        compare(t.autoCollapsed, false, "多出 1px 也算放得下");
        t.width = natural - 1;
        wait(40);
        compare(t.autoCollapsed, false, "挤 1px 还在容差里（官方那条是 > clientWidth + 1）");
        t.width = natural - 2;
        wait(40);
        compare(t.autoCollapsed, true, "挤到 2px 才算溢出");
        t.destroy();
    }

    function test_horizontalCellHeightsFollowSizeAbsolutely() {
        const cases = [["large", 52], ["medium", 44], ["small", 36]];
        for (let i = 0; i < cases.length; ++i) {
            const t = make('Tabs { width: 600; size: "' + cases[i][0]
                + '"; tabList: [{ itemKey: "a", tab: "甲" }] }');
            near(cell(t, 0).implicitHeight, cases[i][1],
                "line/top " + cases[i][0] + " 的格子自己也得算出这个高");
            t.destroy();
        }
    }

    function test_closeMarkWidensTheCellByTwentyFour() {
        const withX = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲", closable: true }] }');
        const noX = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" }] }');
        near(cell(withX, 0).closeWidth, 24, "14 的 × + margin-left 10");
        near(cell(withX, 0).implicitWidth - cell(noX, 0).implicitWidth, 24,
            "× 要把格子撑宽 24");
        noX.destroy();
        withX.destroy();
    }

    function test_slashCellHasNoBackgroundAtAll() {
        const t = make('Tabs { width: 600; type: "slash"; tabList:'
            + ' [{ itemKey: "a", tab: "甲" }] }');
        compare(part(cell(t, 0), "tabItemBackground").color, Qt.rgba(0, 0, 0, 0),
            "slash 档选中也不画底（CSS 里 slash 只有那道对角线）");
        t.destroy();
    }

    function test_motionFlagFollowsTabPaneMotion() {
        const off = make('Tabs { width: 600; tabPaneMotion: false' + testCase.threePanes + ' }');
        compare(paneOf(off, 0).hostMotion, false);
        off.destroy();
        const on = make('Tabs { width: 600' + testCase.threePanes + ' }');
        compare(paneOf(on, 0).hostMotion, true, "缺省 tabPaneMotion=true 且这一格正激活");
        compare(paneOf(on, 1).hostMotion, false, "非激活格永远不播");
        on.destroy();
    }

    function test_directionOfDecidesWhichAxisEnters() {
        const t = make('Tabs { width: 600' + testCase.threePanes + ' }');
        t.handleClick("c");
        compare(paneOf(t, 2).hostFromEnd, false, "往后翻 ⇒ 从左边进来（leftShow）");
        t.handleClick("a");
        compare(paneOf(t, 0).hostFromEnd, true, "往回翻 ⇒ 从右边进来（rightShow）");
        t.destroy();
    }

    // ---------------- 键盘 ----------------

    function test_arrowsMoveFocusWithoutActivating() {
        const t = make('Tabs { width: 600' + testCase.threePanes + ' }');
        spyOn(t);
        const before = t.currentKey;
        cell(t, 0).forceActiveFocus();
        wait(20);
        t.handleKeyDown("ArrowRight", "a", false);
        compare(t.currentKey, before, "方向键只挪焦点，不激活、不发 change");
        compare(t.focusedKey, "b", "焦点落到右边那一格");
        t.handleKeyDown("ArrowRight", "b", false);
        compare(t.focusedKey, "c");
        compare(t.currentKey, "a", "焦点已经不在当前格上了，方向键也不许顺手激活");
        t.handleKeyDown("ArrowRight", "c", false);
        compare(t.focusedKey, "a", "末尾越界 ⇒ 回第一格");
        t.handleKeyDown("ArrowLeft", "a", false);
        compare(t.focusedKey, "c", "开头越界 ⇒ 回最后一格");
        t.destroy();
    }

    function test_wrongAxisIsSwallowed() {
        const t = make('Tabs { width: 600' + testCase.threePanes + ' }');
        cell(t, 0).forceActiveFocus();
        wait(20);
        t.handleKeyDown("ArrowDown", "a", false);
        compare(t.focusedKey, "", "横排只认 ←/→，↑↓ 静默吞掉");
        t.destroy();
        const v = make('Tabs { width: 300; tabPosition: "left"' + testCase.threePanes + ' }');
        cell(v, 0).forceActiveFocus();
        wait(20);
        v.handleKeyDown("ArrowRight", "a", false);
        compare(v.focusedKey, "", "竖排反过来");
        v.handleKeyDown("ArrowDown", "a", false);
        compare(v.focusedKey, "b");
        v.destroy();
    }

    function test_arrowsSkipDisabledCells() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙", disabled: true }, { itemKey: "c", tab: "丙" }] }');
        cell(t, 0).forceActiveFocus();
        wait(20);
        t.handleKeyDown("ArrowRight", "a", false);
        compare(t.focusedKey, "c", "禁用格不在那份名单里 ⇒ 直接跳过去");
        t.destroy();
    }

    function test_homeAndEndUseTheUsableList() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲", disabled: true },'
            + ' { itemKey: "b", tab: "乙" }, { itemKey: "c", tab: "丙", disabled: true }] }');
        verify(t.usableKeys().join(",") === "b");
        t.handleKeyDown("Home", "b", false);
        compare(t.focusedKey, "b");
        t.handleKeyDown("End", "b", false);
        compare(t.focusedKey, "b", "可用名单只有一格 ⇒ Home/End 同格");
        t.destroy();
    }

    function test_enterActivatesEvenForDisabledCell() {
        // foundation.ts:98-102 少了 TabItem.tsx:65 那句 disabled 判定 ⇒ 上游真行为
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙", disabled: true }] }');
        spyOn(t);
        t.handleKeyDown("Enter", "b", false);
        compare(t.currentKey, "b", "Enter 不判 disabled");
        verify(testCase.signalLog.indexOf("click:b") >= 0);
        t.destroy();
    }

    function test_deleteNeedsClosableAndMovesFocus() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲", closable: true },'
            + ' { itemKey: "b", tab: "乙", closable: true }, { itemKey: "c", tab: "丙" }] }');
        spyOn(t);
        t.handleKeyDown("Delete", "c", false);
        compare(testCase.signalLog.length, 0, "不可关的那格按 Delete 什么都不做");
        cell(t, 0).forceActiveFocus();
        wait(20);
        t.handleKeyDown("Delete", "a", true);
        verify(testCase.signalLog.indexOf("close:a") >= 0);
        compare(t.focusedKey, "b", "删完焦点去后一格");
        t.handleKeyDown("Delete", "b", true);
        verify(testCase.signalLog.indexOf("close:b") >= 0, "只剩一格可关时照样通知");
        t.destroy();
    }

    function test_deleteOnLastUsableSkipsFocusMove() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲", closable: true }] }');
        cell(t, 0).forceActiveFocus();
        wait(20);
        spyOn(t);
        t.handleKeyDown("Delete", "a", true);
        verify(testCase.signalLog.indexOf("close:a") >= 0);
        compare(cell(t, 0).activeFocus, true, "usable.length===1 时官方跳过挪焦点");
        t.destroy();
    }

    // ---------------- 折叠 / more ----------------

    function test_collapsibleTrueAlwaysCollapses() {
        const t = make('Tabs { width: 600; collapsible: true; tabList:'
            + ' [{ itemKey: "a", tab: "甲" }] }');
        compare(t.collapseOn, true);
        verify(testCase.findChild(t.barBox, "tabsOverflowList") !== null);
        const flow = testCase.findChild(t.barBox, "tabsBarFlow");
        compare(flow.visible, false, "折叠档不走那条流排");
        t.destroy();
    }

    function test_autoCollapsesOnlyWhenTooNarrow() {
        const wide = make('Tabs { width: 600; collapsible: "auto"; tabList: ['
            + '{ itemKey: "a", tab: "标签甲" }, { itemKey: "b", tab: "标签乙" },'
            + ' { itemKey: "c", tab: "标签丙" }, { itemKey: "d", tab: "标签丁" }] }');
        wait(40);
        compare(wide.autoCollapsed, false, "放得下就不折");
        wide.width = 90;
        wait(40);
        compare(wide.collapseOn, true, "auto 量出来要真的把折叠档打开");
        compare(wide.autoCollapsed, true, "挤了才折（官方 scrollWidth > clientWidth + 1）");
        wide.width = 600;
        wait(40);
        compare(wide.autoCollapsed, false, "放开之后要能自己退回来");
        wide.destroy();
    }

    function test_collapsibleWinsOverMore() {
        const t = make('Tabs { width: 300; collapsible: true; more: 2; tabList: ['
            + '{ itemKey: "a", tab: "甲" }, { itemKey: "b", tab: "乙" }, { itemKey: "c", tab: "丙" }] }');
        compare(t.collapseOn, true);
        compare(t.moreOn, false, "TabBar.tsx:425 那个三元：折叠赢");
        t.collapsible = false;
        compare(t.moreOn, true, "不折了才轮到 more");
        t.destroy();
    }

    function test_moreKeepsLengthMinusCount() {
        const t = make('Tabs { width: 600; more: 3; tabList: [{ itemKey: "0", tab: "零" },'
            + ' { itemKey: "1", tab: "一" }, { itemKey: "2", tab: "二" }, { itemKey: "3", tab: "三" },'
            + ' { itemKey: "4", tab: "四" }] }');
        compare(t.moreCount, 3, "数字 = 收进下拉的**数量**，不是留下的");
        compare(t.barModel().length, 2, "五条收三条 ⇒ 栏上只剩两条");
        wait(30);   // 那张表是 Qt.callLater 建的（避开同轮绑定环）
        compare(t.moreMenuStore.length, 3);
        compare(t.moreMenuStore[0].node, "item");
        compare(t.moreMenuStore[0].name, "二");
        t.destroy();
    }

    function test_moreObjectFormReadsCount() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "0", tab: "零" },'
            + ' { itemKey: "1", tab: "一" }, { itemKey: "2", tab: "二" },'
            + ' { itemKey: "3", tab: "三" }] }');
        t.more = ({ count: 2 });
        compare(t.moreIsValid, true);
        compare(t.moreCount, 2, "对象档吃 count，语义与数字档同（收进下拉的数量）");
        compare(t.barModel().length, 2);
        t.destroy();
    }

    function test_moreZeroAndMoreBoolAreIgnored() {
        const zero = make('Tabs { width: 600; more: 0; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }] }');
        compare(zero.moreOn, false, "`more` 给 0 被当真值判断的假值忽略");
        compare(zero.barModel().length, 2);
        zero.destroy();
        const bool = make('Tabs { width: 600; more: true; tabList: [{ itemKey: "a", tab: "甲" }] }');
        compare(bool.moreOn, false, "官方那边直接抛 invalid props，端口收成「不算 more 档」");
        bool.destroy();
    }

    function test_moreMenuEntriesAreClosuresNotInvoked() {
        const t = make('Tabs { width: 600; more: 1; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }, { itemKey: "c", tab: "丙" }] }');
        compare(t.currentKey, "a", "建表时不许把每一项都点一遍（写成调用就会漂到最后一项）");
        wait(30);
        const entry = t.moreMenuStore[t.moreMenuStore.length - 1];
        spyOn(t);
        entry.onClick();
        verify(testCase.signalLog.indexOf("click:c") >= 0, "点下拉里那一条才走 handleClick");
        t.destroy();
    }

    function test_arrowPositionGatesEachSide() {
        const t = make('Tabs { width: 200; collapsible: true; arrowPosition: "start"; tabList: ['
            + '{ itemKey: "a", tab: "甲甲甲" }, { itemKey: "b", tab: "乙乙乙" },'
            + ' { itemKey: "c", tab: "丙丙丙" }] }');
        wait(60);
        const arrows = [];
        const walk = function (n) {
            if (n === null || n === undefined)
                return;
            if (n.objectName === "tabsArrowNode")
                arrows.push(n);
            const kids = n.children;
            if (kids === undefined)
                return;
            for (let i = 0; i < kids.length; ++i)
                walk(kids[i]);
        };
        walk(t);
        verify(arrows.length >= 2, "两侧都要有箭头节点，才分得出哪一侧被关掉");
        let start = null;
        let end = null;
        for (let i = 0; i < arrows.length; ++i) {
            if (arrows[i].overflowSide === "before")
                start = arrows[i];
            else
                end = arrows[i];
        }
        verify(start !== null && end !== null);
        compare(start.allowed, true);
        compare(end.allowed, false, "arrowPosition='start' ⇒ 只留左箭头");
        near(end.implicitWidth, 0, "关掉那一侧要收成 0 宽，否则白占视口");
        t.destroy();
    }

    // ---------------- 二次封装与杂项 ----------------

    function test_renderTabBarReceivesHostAndDefaultBar() {
        const t = make('Tabs { width: 600; renderTabBar: hookBar; tabList:'
            + ' [{ itemKey: "a", tab: "甲" }, { itemKey: "b", tab: "乙" }] }');
        wait(60);
        const hook = testCase.findChild(t, "tabsHookRoot");
        verify(hook !== null, "钩子那一份要装起来");
        verify(hook.host === t, "注入 host");
        verify(hook.defaultTabBar !== null && hook.defaultTabBar !== undefined, "注入 defaultTabBar");
        compare(hook.barLoaded, true, "钩子自己 Loader 默认栏要能出格子");
        t.destroy();
    }

    Component {
        id: hookBar

        Item {
            id: hookRoot

            objectName: "tabsHookRoot"

            property var host: null
            property Component defaultTabBar: null
            readonly property bool barLoaded: inner.item !== null && inner.item !== undefined

            implicitWidth: 300
            implicitHeight: 60

            Loader {
                id: inner

                anchors.fill: parent
                sourceComponent: hookRoot.defaultTabBar
            }
        }
    }

    function test_emptyContainerIsHarmless() {
        const t = make("Tabs { width: 600 }");
        compare(t.count, 0);
        compare(t.cells().length, 0);
        near(t.implicitHeight, t.itemHeight + 10,
            "内容区那 5px 上下内边距是无条件给的（CSS:22306-22309）⇒ 空容器也占 10");
        t.handleClick("nope");
        compare(t.currentKey, "nope", "官方 handleNewActiveKey 不校验键在不在名单里 ⇒ 端口照抄");
        t.destroy();
    }

    function test_currentKeyNotInListStillRendersBar() {
        const t = make('Tabs { width: 600; activeKey: "zzz"; tabList:'
            + ' [{ itemKey: "a", tab: "甲" }] }');
        compare(t.activeIndex, -1);
        compare(cell(t, 0).hostSelected, false, "没有一格亮，但格子照样画");
        verify(t.items[0].pane === null, "数组档本来就没有面板");
        t.destroy();
    }

    function test_duplicateKeysResolveToFirst() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "a", tab: "乙" }] }');
        compare(t.count, 2);
        compare(t.indexOfKey("a"), 0);
        t.destroy();
    }

    function test_cellsReturnOnlyDrawnCells() {
        const t = make('Tabs { width: 600; tabList: [{ itemKey: "a", tab: "甲" },'
            + ' { itemKey: "b", tab: "乙" }] }');
        compare(t.cells().length, 2);
        t.tabList = [{ itemKey: "a", tab: "甲" }];
        wait(40);
        compare(t.cells().length, 1, "少一项就要少一格，不能留下孤儿格子");
        t.destroy();
    }
}
