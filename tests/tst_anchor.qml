import QtQuick
import QtTest
import Semi

// Anchor 锚点导航。规格照 packages/semi-ui/anchor/{index.tsx,link.tsx,anchor-context.ts}
// + semi-foundation/anchor/{foundation.ts,linkFoundation.ts,constants.ts,anchor.scss,
// variables.scss,rtl.scss}，数值逐条对编译后的 packages/semi-ui/dist/css/semi.css。
//
// 这份用例盯的几条（端口口径全写在 src/Anchor.qml 文件头）：
//   · `activeLink` 是**命令式 state**：滚动时取「最接近 0 的那个负值」，一条都没滚过时
//     官方读 `links[-1]` ⇒ **undefined**（高亮被清空，指示器跟着消失）；
//   · 那串 `(... - containerTop - offsetTop) || -Infinity` 让**恰好等于 0** 也算 -Infinity；
//   · 滚动处理 `throttle(fn, 100)`、解闩 `debounce(fn, 100)`；点击后置闩 ⇒ 闩着的时候
//     滚动不抢高亮，而**点一条已经在位的 Link 不产生滚动事件 ⇒ 闩永远不解**；
//   · 点击顺序：先置 active（发 onChange）→ 置闩 + 滚动 → 发 onClick；
//     `targetItem` 为空的链接只置高亮，不滚动也不置闩；
//   · `defaultAnchor` 挂载走 `handleClick(..., false)` ⇒ 置高亮 + 滚动但**两个回调都不发**；
//   · `autoCollapse` 靠 childMap（每个祖先留一份全部子孙）决定下一级画不画；
//   · `railTheme: 'muted'` 是**整条滑轨都不画**（variables 里那条 white 是死令牌）；
//   · 指示器 28/24 高、`top` = 当前那条的 y、**没有过渡**；标题选中不加字重；
//   · `position` 是 Tooltip 位置，不是滑轨左右（旧端口把这个名字用错了，本轮改回）。
//
// 跑法（本仓约定，优先 offscreen）：
//   QT_QPA_PLATFORM=offscreen ./cmake-build-debug/tests/tst_semi -input tests/tst_anchor.qml
TestCase {
    id: testCase

    name: "Anchor"
    when: windowShown
    width: 900
    height: 600

    property var changes: []
    property var clicks: []

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
        testCase.changes = [];
        testCase.clicks = [];
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
    }

    function cleanup() {
        Theme.reset();
        Theme.mode = Theme.Light;
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        const o = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "an");
        wait(120);
        return o;
    }

    function part(owner, name) {
        const node = testCase.findChild(owner, name);
        verify(node !== null && node !== undefined, "找不到 " + name);
        return node;
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 1.0,
            (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    /// 三只 300 高的内容段 + 三条锚点；`extra` 拼进 Anchor 的属性里
    function stage(extra) {
        return make("Item { width: 600; height: 420;\n"
            + " Flickable { id: view; objectName: 'view'; width: 300; height: 300;\n"
            + "  contentHeight: 1200; boundsBehavior: Flickable.StopAtBounds\n"
            + "  Column { Item { id: a; objectName: 'secA'; width: 100; height: 300 }\n"
            + "   Item { id: b; objectName: 'secB'; width: 100; height: 300 }\n"
            + "   Item { id: c; objectName: 'secC'; width: 100; height: 300 } } }\n"
            + " Anchor { id: nav; objectName: 'nav'; y: 330; width: 200; container: view;"
            + extra + "\n"
            + "  AnchorLink { href: '#a'; title: '第一节'; targetItem: a }\n"
            + "  AnchorLink { href: '#b'; title: '第二节'; targetItem: b }\n"
            + "  AnchorLink { href: '#c'; title: '第三节'; targetItem: c } } }")
    }

    /// 三层嵌套：1 → 1.1 → 1.1.1，另有一条平级的 2
    function nestedStage(extra) {
        return make("Item { width: 600; height: 420;\n"
            + " Flickable { id: view; objectName: 'view'; width: 300; height: 300;\n"
            + "  contentHeight: 1500; boundsBehavior: Flickable.StopAtBounds\n"
            + "  Column { Item { id: s1; objectName: 'sec1'; width: 100; height: 300 }\n"
            + "   Item { id: s11; objectName: 'sec11'; width: 100; height: 300 }\n"
            + "   Item { id: s111; objectName: 'sec111'; width: 100; height: 300 }\n"
            + "   Item { id: s2; objectName: 'sec2'; width: 100; height: 300 } } }\n"
            + " Anchor { id: nav; objectName: 'nav'; y: 330; width: 200; container: view;"
            + extra + "\n"
            + "  AnchorLink { href: '#1'; title: '1'; targetItem: s1\n"
            + "   AnchorLink { href: '#1.1'; title: '1.1'; targetItem: s11\n"
            + "    AnchorLink { href: '#1.1.1'; title: '1.1.1'; targetItem: s111 } } }"
            + "\n  AnchorLink { href: '#2'; title: '2'; targetItem: s2 } } }")
    }

    function hrefs(nav) {
        return nav.linkNodes().map(function (l) {
            return l.href;
        });
    }

    // ============================================================ 属性面与缺省值
    function test_propDefaults() {
        const host = stage("")
        const nav = part(host, "nav")
        compare(nav.size, "default");
        compare(nav.railTheme, "primary");
        compare(nav.offsetTop, 0);
        compare(nav.targetOffset, 0);
        compare(nav.scrollMotion, false);
        compare(nav.autoCollapse, false);
        compare(nav.showTooltip, false);
        compare(nav.position, "");
        compare(nav.defaultAnchor, "");
        compare(nav.maxWidth, "200px");
        compare(nav.maxHeight, "750px");
        compare(nav.className, "");
        compare(nav.ariaLabel, "Side navigation");
        compare(nav.Accessible.name, "Side navigation");
        nav.ariaLabel = "目录";
        wait(40)
        compare(nav.Accessible.name, "目录", "aria-label 接进 Accessible.name");
        // 官方那五条 state 的初值
        compare(nav.activeLink, "");
        compare(nav.clickLink, false);
        compare(nav.hrefList, ["#a", "#b", "#c"]);
        compare(nav.hasActive, false, "初值 '' 也算没有高亮 ⇒ 指示器不画");
        compare(part(nav, "anchorIndicator").visible, false);
        host.destroy()
    }

    // ============================================================ 名单、层级、childMap
    function test_registryAndLevels() {
        const host = nestedStage("")
        const nav = part(host, "nav")
        compare(hrefs(nav), ["#1", "#1.1", "#1.1.1", "#2"], "按声明顺序收（深度优先）");
        compare(nav.linkNodes().map(function (l) {
            return l.level;
        }), [1, 2, 3, 1], "官方 renderChildren 注入的 8×level 那个层级");
        // 左内边距 = 8 × level（官方 $spacing-anchor_link-paddingLeft 是死令牌，只有那条内联的）
        compare(nav.linkNodes()[2].indent, 24);
        compare(nav.linkNodes()[3].indent, 8);
        host.destroy()
    }

    function test_childMapCoversAllDescendants() {
        const host = nestedStage("")
        const nav = part(host, "nav")
        compare(nav.childMap["#1"], ["#1.1", "#1.1.1"], "每个祖先留一份全部子孙");
        compare(nav.childMap["#1.1"], ["#1.1.1"]);
        compare(nav.childMap["#1.1.1"], []);
        host.destroy()
    }

    // ============================================================ 选中判据
    function test_scrollPicksLastScrolledPast() {
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        view.contentY = 350
        wait(160)
        compare(nav.activeLink, "#b", "secB 在 300，是最接近 0 的那个负值");
        view.contentY = 650
        wait(160)
        compare(nav.activeLink, "#c");
        view.contentY = 50
        wait(160)
        compare(nav.activeLink, "#a");
        host.destroy()
    }

    function test_boundaryExactlyZeroIsSkipped() {
        // 官方 `(top - containerTop - offsetTop) || -Infinity` ⇒ 恰好 0 的那条算 -Infinity
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        compare(nav.relTop(nav.linkNodes()[0]), -Infinity, "secA 在 0、没滚、offsetTop 0 ⇒ -Infinity");
        view.contentY = 1
        wait(160)
        compare(nav.activeLink, "#a", "滚 1px 之后才选得中");
        host.destroy()
    }

    function test_activeClearedWhenNothingScrolledPast() {
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        view.contentY = 350
        wait(160)
        compare(nav.activeLink, "#b");
        verify(part(nav, "anchorIndicator").visible, true);
        view.contentY = 0
        wait(160)
        compare(nav.activeLink, undefined, "官方读 links[-1] ⇒ undefined，高亮被清空");
        compare(nav.hasActive, false);
        compare(part(nav, "anchorIndicator").visible, false, "指示器跟着消失");
        compare(nav.linkNodes()[1].selected, false);
        host.destroy()
    }

    function test_offsetTopShiftsTheThreshold() {
        const host = stage("offsetTop: 300")
        const nav = part(host, "nav")
        const view = part(host, "view")
        view.contentY = 350
        wait(160)
        // relB = 300-350-300 = -350，relC = 600-350-300 = -50 ⇒ 取 -50 那条
        compare(nav.activeLink, "#c", "offsetTop 把阈值整条往下推");
        host.destroy()
    }

    function test_changeSignalCarriesBothLinks() {
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        nav.change.connect(function (cur, prev) {
            testCase.changes.push(cur + "<-" + prev);
        });
        view.contentY = 350
        wait(160)
        view.contentY = 650
        wait(160)
        compare(testCase.changes, ["#b<-", "#c<-#b"], "第一次的 previous 是初值 ''");
        view.contentY = 700;                       // 还在 secC 那一段里
        wait(160)
        view.contentY = 750;
        wait(160)
        compare(testCase.changes.length, 2, "同一条重复算出来不再发 change");
        host.destroy()
    }

    // ============================================================ 点击
    function test_clickSetsActiveScrollsAndNotifies() {
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        const order = [];
        nav.change.connect(function () { order.push("change"); });
        nav.click.connect(function (link) { order.push("click:" + link); });
        nav.linkNodes()[2].handleClick();
        wait(160)
        compare(nav.activeLink, "#c");
        near(view.contentY, 600, "滚到目标");
        compare(order, ["change", "click:#c"], "官方先 setActiveLink（发 onChange）再 notifyClick");
        host.destroy()
    }

    function test_clickLinkWithoutTargetOnlyHighlights() {
        const host = make("Item { width: 600; height: 420;\n"
            + " Flickable { id: view; objectName: 'view'; width: 300; height: 300;\n"
            + "  contentHeight: 1200; boundsBehavior: Flickable.StopAtBounds }\n"
            + " Anchor { objectName: 'nav'; y: 330; width: 200; container: view;\n"
            + "  AnchorLink { href: '#x'; title: '没有目标' } } }")
        const nav = part(host, "nav")
        const view = part(host, "view")
        nav.linkNodes()[0].handleClick();
        wait(160)
        compare(nav.activeLink, "#x", "官方 setActiveLink 在 destNode 判断之前");
        compare(nav.clickLink, false, "找不到内容节点 ⇒ 不置闩也不滚动");
        compare(view.contentY, 0);
        host.destroy()
    }

    function test_latchBlocksScrollSelection() {
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        nav.linkNodes()[2].handleClick();          // 点 c ⇒ 滚到 600、置闩
        wait(20)
        verify(nav.clickLink, "刚点完闩是关着的");
        view.contentY = 50;                        // 闩着的时候手动往回滚
        wait(20)
        compare(nav.activeLink, "#c", "闩着 ⇒ 滚动不抢高亮");
        wait(200)                                  // 滚动停下来 100ms 之后解闩
        compare(nav.clickLink, false);
        view.contentY = 60;                        // 换个值，才有滚动信号
        wait(160)
        compare(nav.activeLink, "#a", "解闩之后照常");
        host.destroy()
    }

    function test_latchNeverReleasesWhenNothingScrolls() {
        // 官方解闩挂在 scroll 事件的 debounce 上：点了「已经在位」的那条 ⇒ contentY 不变
        // ⇒ 没有滚动事件 ⇒ debounce 从没启动 ⇒ 闩永远不解
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        view.contentY = 300
        wait(160)
        compare(nav.activeLink, "#a", "secB 的 relTop 恰好 0 ⇒ 被 `|| -Infinity` 吞掉");
        nav.linkNodes()[1].handleClick();          // 目标就在 300 ⇒ 赋值不产生变化
        wait(250)                                  // 比 debounce 的 100ms 长得多
        verify(nav.clickLink, "没有滚动事件 ⇒ 闩永远不解");
        compare(nav.activeLink, "#b", "点击自己那次仍置了高亮");
        view.contentY = 500;
        wait(60)
        compare(nav.activeLink, "#b", "闩着 ⇒ 这一路滚动都不抢高亮（上游真缺陷，照抄）");
        host.destroy()
    }

    function test_scrollIsThrottledTo100ms() {
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        view.contentY = 350
        wait(20)
        compare(nav.activeLink, "#b", "leading 那次立刻算");
        view.contentY = 650
        wait(20)
        compare(nav.activeLink, "#b", "窗口内的第二次只记 pending，不立刻算");
        wait(200)
        compare(nav.activeLink, "#c", "窗口末尾补一次 trailing");
        host.destroy()
    }

    // ============================================================ defaultAnchor / targetOffset
    function test_defaultAnchorSelectsSilently() {
        // 挂载那一下发生在 make() 里，connect 来得及的只有 activeLink/contentY；
        // 两个回调是否在挂载时闭着，只能让宿主自己把日志记在字符串里
        const host = make("Item { id: root; width: 600; height: 420; property var log: [];\n"
            + " Flickable { id: view; objectName: 'view'; width: 300; height: 300;\n"
            + "  contentHeight: 1200; boundsBehavior: Flickable.StopAtBounds\n"
            + "  Column { Item { id: a; objectName: 'secA'; width: 100; height: 300 }\n"
            + "   Item { id: b; objectName: 'secB'; width: 100; height: 300 }\n"
            + "   Item { id: c; objectName: 'secC'; width: 100; height: 300 } } }\n"
            + " Anchor { id: nav; objectName: 'nav'; y: 330; width: 200; container: view;\n"
            + "  defaultAnchor: '#c';\n"
            + "  onChange: root.log.push('change:' + currentLink);\n"
            + "  onClick: root.log.push('click:' + currentLink);\n"
            + "  AnchorLink { href: '#a'; title: 'A'; targetItem: a }\n"
            + "  AnchorLink { href: '#b'; title: 'B'; targetItem: b }\n"
            + "  AnchorLink { href: '#c'; title: 'C'; targetItem: c } } }")
        const nav = part(host, "nav")
        const view = part(host, "view")
        compare(nav.activeLink, "#c", "挂载时走一遍 handleClick");
        near(view.contentY, 600, "也真的滚过去了");
        wait(200)
        compare(host.log, [], "shouldNotify=false ⇒ onChange / onClick 都不发");
        nav.linkNodes()[0].handleClick();
        wait(160)
        compare(host.log, ["change:#a", "click:#a"], "平时两个都发");
        host.destroy()
    }

    function test_targetOffsetShiftsTheLanding() {
        const host = stage("targetOffset: 80")
        const nav = part(host, "nav")
        const view = part(host, "view")
        nav.linkNodes()[1].handleClick();
        wait(160)
        near(view.contentY, 220, "官方 offsetTop = top - targetOffset");
        host.destroy()
    }

    function test_scrollMotionAnimatesInsteadOfJumping() {
        const host = stage("scrollMotion: true")
        const nav = part(host, "nav")
        const view = part(host, "view")
        nav.linkNodes()[2].handleClick();
        verify(nav.scrolling, "scrollMotion ⇒ 起的是动画");
        compare(nav.scrollAnimation.to, 600);
        near(nav.scrollAnimation.duration, 100);
        wait(400)
        near(view.contentY, 600, "最终还是到位");
        compare(nav.scrolling, false);
        host.destroy()
    }

    function test_scrollMotionOffJumpsInOneStep() {
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        nav.linkNodes()[2].handleClick();
        compare(nav.scrolling, false, "缺省 false ⇒ 官方 behavior:'auto'，一步赋值不启动画");
        wait(60)
        near(view.contentY, 600);
        host.destroy()
    }

    // ============================================================ autoCollapse
    function test_autoCollapseRevealsOnlyTheActiveBranch() {
        const host = nestedStage("autoCollapse: true")
        const nav = part(host, "nav")
        const view = part(host, "view")
        const list = nav.linkNodes();
        compare(list[0].childColumnRef.visible, false, "没人选中 ⇒ 1 的下一级收着");
        compare(list[3].childColumnRef.children.length, 0, "它本来就没有下一级可展开");
        view.contentY = 650                        // 落在 1.1.1 上
        wait(160)
        compare(nav.activeLink, "#1.1.1");
        compare(list[0].childColumnRef.visible, true, "祖先跟着展开");
        compare(list[1].childColumnRef.visible, true, "自己是被选中的那条");
        host.destroy()
    }

    function test_autoCollapseOffAlwaysRendersChildren() {
        const host = nestedStage("")
        const nav = part(host, "nav")
        const list = nav.linkNodes();
        compare(list[0].childColumnRef.visible, true, "官方 !autoCollapse ⇒ 无条件渲染");
        compare(list[1].childColumnRef.visible, true);
        compare(nav.hasActive, false);
        host.destroy()
    }

    // ============================================================ 滑轨与指示器
    function test_railThemeThreeStates() {
        const p = stage("")
        const nav = part(p, "nav");
        const view = part(p, "view");
        view.contentY = 350
        wait(160)
        compare(part(nav, "anchorSlide").visible, true);
        compare(part(nav, "anchorRail").color, Theme.current.colorBorder);
        compare(part(nav, "anchorIndicator").color, Theme.current.colorPrimary);
        p.destroy()

        const t = stage("railTheme: 'tertiary'")
        const navT = part(t, "nav");
        part(t, "view").contentY = 350
        wait(160)
        compare(part(navT, "anchorIndicator").color, Theme.current.colorTertiary);
        t.destroy()

        const m = stage("railTheme: 'muted'")
        const navM = part(m, "nav");
        part(m, "view").contentY = 350
        wait(160)
        // 官方 -slide-muted { display: none } ⇒ 底色轨与指示器一起没了
        //（variables 里那条 muted 的 white 是死令牌，scss 没引用）
        compare(part(navM, "anchorSlide").visible, false, "muted 是整条滑轨都不画");
        compare(part(navM, "anchorIndicator").visible, false);
        m.destroy()
    }

    function test_indicatorGeometryFollowsTheActiveRow() {
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        view.contentY = 350
        wait(160)
        const list = nav.linkNodes();
        near(nav.slideBarTop, list[1].y, "指示器 top = 当前那条标题的 offsetTop");
        near(nav.slideBarHeight, 28, "default 档 20 行高 + 上下各 4");
        const ind = part(nav, "anchorIndicator");
        near(ind.height, 28);
        near(ind.width, 2, "$width-anchor_slide_default");
        near(ind.radius, 1);
        host.destroy()
    }

    function test_indicatorHasNoTransition() {
        // 官方 scss 里那条 transition 只给标题字色（还是 0ms），指示器没有过渡
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        const ind = part(nav, "anchorIndicator");
        view.contentY = 350
        wait(160)
        const first = ind.y;
        view.contentY = 650
        wait(20)
        near(ind.y, nav.linkNodes()[2].y, "换选中之后当场到位（实得 " + ind.y + "，起点 " + first + "）");
        host.destroy()
    }

    // ============================================================ 尺寸
    function test_sizeSmallMetrics() {
        const host = stage("size: 'small'")
        const nav = part(host, "nav")
        const view = part(host, "view")
        compare(nav.rowHeight, 24);
        const list = nav.linkNodes();
        near(list[0].height, 24, "行高 = 16 行 + 上下各 4");
        compare(part(list[0], "anchorTitle").font.pixelSize, Theme.current.fontSizeSmall);
        view.contentY = 350
        wait(160)
        near(nav.slideBarHeight, 24, "-slide-bar-small 那条高度");
        host.destroy()
    }

    function test_rowsHaveNoSpacing() {
        const host = stage("")
        const nav = part(host, "nav")
        const list = nav.linkNodes();
        near(list[1].y, list[0].y + list[0].height, "官方行与行之间没有间距");
        near(nav.linkNodes()[2].y, 56);
        host.destroy()
    }

    // ============================================================ 标题四档字色
    function test_titleColorFourStates() {
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        const list = nav.linkNodes();
        const first = part(list[0], "anchorTitle");
        compare(first.color, Theme.current.colorText2, "未选中 text-2");
        compare(first.font.weight, Font.Normal);
        const row = part(list[0], "anchorTitleRow");
        mouseMove(row, row.width - 4, row.height / 2);
        wait(80)
        compare(list[0].hovered, true);
        compare(first.color, Theme.current.colorTertiaryHover, "悬浮 tertiary-hover");
        view.contentY = 350
        wait(160)
        compare(list[1].selected, true);
        compare(part(list[1], "anchorTitle").color, Theme.current.colorText0, "选中 text-0");
        compare(part(list[1], "anchorTitle").font.weight, Font.Normal, "选中**不加字重**");
        host.destroy()
    }

    function test_disabledLinkIgnoresEverything() {
        const host = make("Item { width: 600; height: 420;\n"
            + " Flickable { id: view; objectName: 'view'; width: 300; height: 300;\n"
            + "  contentHeight: 1200; boundsBehavior: Flickable.StopAtBounds\n"
            + "  Column { Item { id: a; objectName: 'secA'; width: 100; height: 300 } } }\n"
            + " Anchor { objectName: 'nav'; y: 330; width: 200; container: view;\n"
            + "  AnchorLink { href: '#a'; title: '禁用'; disabled: true; targetItem: a } } }")
        const nav = part(host, "nav")
        const view = part(host, "view")
        const link = nav.linkNodes()[0];
        const row = part(link, "anchorTitleRow");
        nav.click.connect(function () { testCase.clicks.push("click"); });
        compare(part(link, "anchorTitle").color, Theme.current.colorDisabledText);
        mouseMove(row, row.width - 4, row.height / 2);
        wait(80)
        compare(link.hovered, true, "官方 disabled 那档照样吃 :hover（只是颜色被钉回去）");
        compare(part(link, "anchorTitle").color, Theme.current.colorDisabledText,
            "连 :hover 都是 disabled-text ⇒ 悬浮不变色");
        compare(part(link, "anchorRowHover").cursorShape, Qt.ForbiddenCursor,
            "cursor: not-allowed");
        mouseClick(row, row.width - 4, row.height / 2);
        wait(80)
        compare(testCase.clicks.length, 0, "不响应点击跳转");
        compare(view.contentY, 0);
        compare(nav.activeLink, "", "也不置高亮");
        host.destroy()
    }

    function test_nonPrintableKeyDoesNotJump() {
        // 官方 `onKeyPress={e => this.handleClick(e)}` 没判键，但浏览器只对可打印字符与回车
        // 发 keypress ⇒ 端口按 event.text 非空或回车过滤。这一档能证伪的是「不过滤」那一边：
        // 合成事件在 offscreen 不带 text（实测 key 与 text 都是空），所以可打印那一半
        // 在本 harness 里发不出来，只能钉「Tab 不跳」
        const host = stage("")
        const nav = part(host, "nav")
        const view = part(host, "view")
        nav.click.connect(function (link) { testCase.clicks.push(link); });
        const row = part(nav.linkNodes()[1], "anchorTitleRow");
        row.forceActiveFocus();
        wait(40)
        verify(row.activeFocus, "焦点没落上 ⇒ 这条用例的前提就没了");
        keyClick(row, Qt.Key_Tab);
        wait(120)
        compare(testCase.clicks, [], "Tab 不算 keypress ⇒ 不跳");
        compare(view.contentY, 0);
        compare(nav.activeLink, "");
        host.destroy()
    }

    // ============================================================ 截断与浮层
    function test_titleTruncatesAtHostWidth() {
        const host = stage("")
        const nav = part(host, "nav")
        const link = nav.linkNodes()[0];
        link.title = "工具提示是一个有用的工具，它可以在文字缩略时展示全部内容。";
        wait(80)
        const title = part(link, "anchorTitle");
        near(nav.width, 200, "maxWidth 200px");
        verify(title.implicitWidth > title.width, "自然宽溢出");
        compare(title.elide, Text.ElideRight, "官方 overflow + text-overflow: ellipsis + nowrap");
        compare(title.maximumLineCount, 1);
        host.destroy()
    }

    function test_tooltipGate() {
        const long = "工具提示是一个有用的工具，它可以在文字缩略时展示全部内容。";
        const host = stage("")
        const nav = part(host, "nav")
        const link = nav.linkNodes()[0];
        link.title = long;
        wait(60)
        const tip = part(link, "anchorTipTooltip");
        compare(nav.tooltipOn, false);
        compare(tip.condition, false, "showTooltip 缺省 false ⇒ 截断也不弹");
        nav.showTooltip = true
        wait(60)
        compare(nav.tooltipOn, true);
        compare(tip.condition, true, "溢出 + 开了 ⇒ 该弹");
        compare(nav.tooltipKind, "tooltip", "没给 type 就是 tooltip");
        compare(part(link, "anchorTipPopover").condition, false, "popover 那档不抢");
        nav.showTooltip = ({ type: "popover" })
        wait(60)
        compare(nav.tooltipKind, "popover");
        compare(part(link, "anchorTipPopover").condition, true);
        compare(tip.condition, false);
        const short = part(nav.linkNodes()[1], "anchorTipTooltip");
        compare(short.condition, false, "没溢出就不弹（Typography 那条 overflowed 判据）");
        nav.showTooltip = ({ type: "Popover" })
        wait(60)
        compare(nav.tooltipKind, "popover", "官方比的是 toLowerCase() 之后的值");
        compare(part(link, "anchorTipPopover").condition, true);
        host.destroy()
    }

    function test_positionIsTooltipPlacementNotRailSide() {
        const host = stage("showTooltip: true; position: 'right'")
        const nav = part(host, "nav")
        compare(nav.tooltipPlacement, Enums.Right, "官方 position 是 Tooltip 位置");
        compare(part(nav, "anchorSlide").x, 0, "滑轨固定在左（旧端口把它当左右开关用了）");
        const link = nav.linkNodes()[0];
        compare(part(link, "anchorTipTooltip").position, Enums.Right);
        nav.position = ""
        wait(60)
        compare(nav.tooltipPlacement, Enums.Top, "没给 ⇒ 吃浮层自己的缺省");
        host.destroy()
    }

    // ============================================================ 容器与溢出
    function test_containerIsBoundOnce() {
        const host = make("Item { width: 600; height: 420;\n"
            + " Flickable { id: v1; objectName: 'v1'; width: 300; height: 300; contentHeight: 1200;\n"
            + "  boundsBehavior: Flickable.StopAtBounds\n"
            + "  Column { Item { id: a; objectName: 'secA'; width: 100; height: 300 } } }\n"
            + " Flickable { id: v2; objectName: 'v2'; x: 310; width: 300; height: 300;\n"
            + "  contentHeight: 1200; boundsBehavior: Flickable.StopAtBounds\n"
            + "  Column { Item { id: d; objectName: 'secD'; width: 100; height: 300 } } }\n"
            + " Anchor { objectName: 'nav'; y: 330; width: 200; container: v1;\n"
            + "  AnchorLink { href: '#a'; title: 'A'; targetItem: a } } }")
        const nav = part(host, "nav")
        const v1 = part(host, "v1")
        const v2 = part(host, "v2")
        v1.contentY = 100
        wait(160)
        compare(nav.activeLink, "#a");
        compare(nav.scrollTicks, 1, "挂载后第一次滚动进来了");
        const ticks = nav.scrollTicks;
        nav.container = v2
        wait(60)
        compare(nav.activeLink, "#a", "换容器不重算（官方 this.scrollContainer 只在挂载时取一次）");
        compare(nav.scrollTicks, ticks, "换容器也不改挂");
        v2.contentY = 100
        wait(160)
        compare(nav.scrollTicks, ticks, "新容器滚动没人听 ⇒ 信号一次都没进");
        compare(nav.activeLink, "#a");
        v1.contentY = 0
        wait(160)
        verify(nav.scrollTicks > ticks, "旧容器还在驱动 ⇒ 监听确实留在它身上");
        host.destroy()
    }

    function test_noContainerNeverSelects() {
        const host = make("Item { width: 600; height: 420;\n"
            + " Column { Item { id: a; objectName: 'secA'; width: 100; height: 300 } }\n"
            + " Anchor { objectName: 'nav'; y: 330; width: 200;\n"
            + "  AnchorLink { href: '#a'; title: 'A'; targetItem: a } } }")
        const nav = part(host, "nav")
        compare(nav.container, null);
        compare(nav.relTop(nav.linkNodes()[0]), -Infinity);
        nav.handleScroll();
        compare(nav.activeLink, undefined, "没有容器 ⇒ 谁都选不中");
        host.destroy()
    }

    function test_maxHeightMakesTheAnchorItselfScroll() {
        const many = make("Item { width: 600; height: 420;\n"
            + " Flickable { id: view; objectName: 'view'; width: 300; height: 300;\n"
            + "  contentHeight: 1200; boundsBehavior: Flickable.StopAtBounds\n"
            + "  Column { Item { id: a; objectName: 'secA'; width: 100; height: 300 } } }\n"
            + " Anchor { objectName: 'nav'; y: 330; width: 200; maxHeight: 60; container: view;\n"
            + "  AnchorLink { href: '#1'; title: '一' }  AnchorLink { href: '#2'; title: '二' }\n"
            + "  AnchorLink { href: '#3'; title: '三' }  AnchorLink { href: '#4'; title: '四' }\n"
            + "  AnchorLink { href: '#5'; title: '五' } } }")
        const nav = part(many, "nav")
        near(nav.maxHeightPx, 60, "'60' 也解析成像素");
        near(nav.implicitHeight, 60, "列表 5×28=140 被夹到 maxHeight");
        const self = part(nav, "anchorSelfScroll");
        compare(self.interactive, true, "官方 overflow-y: auto ⇒ 真溢出才可滚");
        near(self.contentHeight, 140);
        compare(part(nav, "anchorRail").height, 140, "滑轨高取 link-wrapper 的 scrollHeight");
        many.destroy()
    }

    function test_selfScrollOffWhenNotOverflowing() {
        const host = stage("maxHeight: 500")
        const nav = part(host, "nav")
        const self = part(nav, "anchorSelfScroll");
        compare(self.interactive, false, "三条 84 高没到 500 ⇒ overflow-y: auto 不给条");
        near(nav.implicitHeight, 84, "没溢出就不夹");
        host.destroy()
    }

    function test_linksArrivingLateAreCollected() {
        // 官方是每条 Link 在 componentDidMount 里 addLink；端口盯宿主那一列的 children 变化。
        // Repeater 的委托在挂载之后才多出来 ⇒ 名单与接线都得跟着长
        const host = make("Item { id: root; property int count: 2;\n"
            + " width: 600; height: 420;\n"
            + " Flickable { id: view; objectName: 'view'; width: 300; height: 300;\n"
            + "  contentHeight: 1200; boundsBehavior: Flickable.StopAtBounds\n"
            + "  Column { Item { id: a; objectName: 'secA'; width: 100; height: 300 }\n"
            + "   Item { id: b; objectName: 'secB'; width: 100; height: 300 }\n"
            + "   Item { id: c; objectName: 'secC'; width: 100; height: 300 } } }\n"
            + " Anchor { objectName: 'nav'; y: 330; width: 200; container: view;\n"
            + "  Repeater { model: root.count; delegate: AnchorLink { href: '#r' + index;\n"
            + "   title: '第 ' + (index + 1) + ' 条'; targetItem: index === 2 ? c : a } } } }")
        const nav = part(host, "nav")
        compare(nav.hrefList, ["#r0", "#r1"]);
        compare(nav.wiredCount, 2);
        host.count = 3
        wait(160)
        compare(nav.hrefList, ["#r0", "#r1", "#r2"], "后到的委托也要进名单");
        // 注：Repeater 换 int 模型时会整批重建委托 ⇒ 计数会跳过旧的那几条
        verify(nav.linkNodes()[2].hostWired, "新委托的 clicked 也接上了");
        const view = part(host, "view")
        view.contentY = 350
        wait(160)
        compare(nav.activeLink, "#r0", "前两条都指向 secA ⇒ 还是第一条");
        nav.linkNodes()[2].handleClick();
        wait(160)
        compare(nav.activeLink, "#r2", "新那条点得动（说明线接上了）");
        near(view.contentY, 600);
        host.destroy()
    }

    function test_nodeTitleSkipsTheTextLayer() {
        const host = make("Item { width: 600; height: 420;\n"
            + " Flickable { id: view; objectName: 'view'; width: 300; height: 300;\n"
            + "  contentHeight: 1200; boundsBehavior: Flickable.StopAtBounds }\n"
            + " Component { id: node; Text { objectName: 'nodeTitle'; text: '节点标题'; font.pixelSize: 12 } }\n"
            + " Anchor { objectName: 'nav'; y: 330; width: 200; container: view; showTooltip: true;\n"
            + "  AnchorLink { href: '#n'; title: node } } }")
        const nav = part(host, "nav")
        const link = nav.linkNodes()[0]
        compare(link.textMode, false);
        compare(part(link, "anchorTitle").visible, false, "节点档不走截断那一层");
        verify(testCase.findChild(link, "nodeTitle") !== null, "Component 由 Loader 载入");
        compare(part(link, "anchorTipTooltip").condition, false,
            "没有可截断的文字 ⇒ 永远不会弹");
        host.destroy()
    }

    // ============================================================ 死 prop 与端口替身
    function test_deadPropsChangeNothing() {
        const host = stage("")
        const nav = part(host, "nav")
        const before = nav.linkNodes()[0].rowWidth;
        nav.className = "mine";
        nav.style = ({ position: "fixed", right: 20, top: 100, zIndex: 3 });
        wait(80)
        compare(nav.linkNodes()[0].rowWidth, before, "style 不参与排布（官方靠它做 fixed）");
        compare(nav.x, 0);
        compare(nav.width, 200, "maxWidth 才是宽的来源");
        host.destroy()
    }

    function test_pxParsingOfCssLengths() {
        const host = stage("maxWidth: 320; maxHeight: 'auto'")
        const nav = part(host, "nav")
        compare(nav.maxWidthPx, 320, "数字档直接用");
        compare(nav.maxHeightPx, -1, "'auto' 解析不出来 ⇒ 不夹");
        near(nav.implicitWidth, 320);
        host.destroy()
    }
}
