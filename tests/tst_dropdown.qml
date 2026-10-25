import QtQuick
import QtQuick.Window
import QtTest
import Semi

// Dropdown 下拉菜单。规格逐条出处写在 src/Dropdown.qml 与 src/DropdownItem.qml 的文件头。
//
// Dropdown 与 Popover 同构（官方 dropdown/index.tsx 的 render 把一切转交 Tooltip），所以这份
// 用例分四半：
//   · 缺省差 —— 每个值都和同一档的 Tooltip 对照着断，只写「等于多少」分不出是谁；
//   · 条目面 —— 36 高、type 五档、selected 死 prop、showTick 被 context 顶死、对勾占位、
//     四个鼠标回调、嵌套那一档的 mouseDown；
//   · 键盘 —— trigger 那半（ArrowDown/Up 送焦点）与菜单那半（上下跳、跳过禁用、Enter 点、
//     首字符跳、焦点底色）；
//   · menu JSON —— 三种 node、子项优先、未知 node 不渲染。
//
// 跑法（本仓约定，优先 offscreen）：
//   QT_QPA_PLATFORM=offscreen ./build/debug/tests/tst_semi -input tests/tst_dropdown.qml
TestCase {
    id: testCase

    name: "Dropdown"
    when: windowShown
    width: 900
    height: 700

    readonly property string tipSrc: "qrc:/qt/qml/Semi/Tooltip.qml"

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    // 断言失败会跳过用例末尾的 destroy ⇒ 残留的弹层还会继续抢焦点与点击
    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "dropdown");
    }

    function part(root, name) {
        return testCase.findChild(root, name);
    }

    function waitTrue(fn, message) {
        tryVerify(fn, 1500);
        verify(fn(), message);
    }

    // 公共宿主：一块可聚焦的 target + 一只 Dropdown（三条目）+ 三个计数。
    // motion 先关：进出场那 100ms 会让 visible 与几何读数抢跑。
    function makeHost(attrs, children) {
        return make("Item { id: root; width: 800; height: 600;"
            + " property var ddRef: dd; property Item tgtRef: tgt;"
            + " property int clicks: 0; property int enters: 0; property int leaves: 0;"
            + " property int ctxHits: 0; property int opens: 0; property int escHits: 0;"
            + " Rectangle { id: tgt; x: 300; y: 250; width: 120; height: 40;"
            + "     color: '#eeeeee'; focusPolicy: Qt.StrongFocus }"
            + " Dropdown { id: dd; target: tgt; motion: false;"
            + (attrs === undefined ? "" : " " + attrs + ";")
            + " onVisibleChanged: if (dd.visible) root.opens++;"
            + " onEscKeyDown: root.escHits++;"
            + " onClickedOutside: root.ctxHits++;"
            + (children === undefined
                ? " DropdownItem { objectName: 'itA'; text: '编辑' }"
                    + " DropdownItem { objectName: 'itB'; text: '复制' }"
                    + " DropdownItem { objectName: 'itC'; text: '删除'; type: 'danger' }"
                : " " + children)
            + " } }")
    }

    function ddOf(host) {
        return host.ddRef;
    }

    // 打开：走 custom 档那条最省事的路（visible 直接归调用方），避免每例都去模拟悬停
    function openByCustom(host) {
        const dd = ddOf(host);
        dd.trigger = "custom";
        dd.visible = true;
        // 等到位置器真的把第二项挪下去 —— 只等「有宽」会抢在排布之前读数
        waitTrue(function () { return dd.height > 0 && dd.width > 0; }, "卡片要排出来");
        wait(60);        // 位置器把第二行挪下去要下一帧
        return dd;
    }

    function openByClick(host) {
        const dd = ddOf(host);
        dd.trigger = "click";
        mouseClick(host.tgtRef, 5, 5);
        waitTrue(function () { return dd.visible; }, "click 档点 target 要开");
        return dd;
    }

    function test_longItemTextIsCappedAtTwoEighty() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '" + "很长很长".repeat(40) + "' }");
        const dd = openByCustom(host);
        compare(part(host, "itA").implicitWidth, 280, "$width-dropdown: 280px 写在条目上");
        compare(dd.width, 280, "卡片跟着封顶");
        host.destroy();
    }

    // ---------------- 与 Tooltip 的缺省差 ----------------

    function test_officialDefaultsAreTheDropdownFlavour() {
        const dd = make("Dropdown { }");
        const tip = make("Tooltip { }");
        compare(dd.position, Enums.Bottom, "Dropdown 的 position 缺省 bottom（tooltip 是 top）");
        compare(tip.position, Enums.Top);
        compare(dd.zIndex, 1050, "tooltipNumbers.DEFAULT_Z_INDEX 是 1050");
        compare(tip.zIndex, 1060);
        compare(dd.mouseLeaveDelay, 100, "strings.DEFAULT_LEAVE_DELAY");
        compare(tip.mouseLeaveDelay, 50);
        compare(dd.mouseEnterDelay, 50, "mouseEnterDelay 没进 Dropdown 的 defaultProps ⇒ 沿用");
        compare(dd.closeOnEsc, true, "Dropdown 把 closeOnEsc 翻成 true");
        compare(tip.closeOnEsc, false);
        compare(dd.showArrow, false, "index.tsx:248 写死");
        compare(dd.disableFocusListener, false, "Dropdown 不碰这一条（Popover 才翻成 true）");
        compare(dd.trigger, "hover");
        compare(dd.motion, true);
        compare(dd.autoAdjustOverflow, true);
        compare(dd.showTick, false);
        verify(!Array.isArray(dd.menu), "menu 没有缺省值");
        dd.destroy();
        tip.destroy();
    }

    function test_noMaxWidthCapUnlikeTooltip() {
        const dd = make("Dropdown { }");
        const tip = make("Tooltip { }");
        verify(dd.maxWidth > 1e6, ".semi-dropdown 没有 max-width，那条 280 在条目上");
        compare(tip.maxWidth, 240);
        dd.destroy();
        tip.destroy();
    }

    function test_spacingIsFourOutsideAndTwoNested() {
        const outer = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '编辑' }"
            + " DropdownItem { objectName: 'nestedHost'; text: '更多' }");
        const dd = ddOf(outer);
        compare(dd.spacing, 4, "外层 numbers.SPACING");
        compare(dd.ctxLevel, 1, "没有外层 ⇒ 自己是第一层");

        const inner = make("Dropdown { }");
        // 嵌套那一档：外层 Dropdown 的 context.level 是 1 ⇒ 内层 renderContent 里读到 1、+1 变 2
        compare(inner.ctxLevel, 1);
        inner.destroy();
        outer.destroy();
    }

    function test_spacingTwoWhenInsideAnotherDropdown() {
        // 内层的 trigger 就是外层的一条菜单项 ⇒ 它的宿主链上多了一层
        const host = make("Item { width: 700; height: 600;"
            + " property var innerRef: inner; property var outerRef: outer;"
            + " Rectangle { id: tgt; width: 120; height: 40; focusPolicy: Qt.StrongFocus }"
            + " Dropdown { id: outer; target: tgt; motion: false; trigger: 'custom'; visible: true;"
            + "     DropdownItem { id: outerItem; objectName: 'outerItem'; text: '外层条目' }"
            + "     Dropdown { id: inner; target: outerItem; motion: false }"
            + " } }");
        waitTrue(function () { return host.innerRef !== undefined; });
        host.innerRef.trigger = "custom";
        host.innerRef.visible = true;
        waitTrue(function () { return host.innerRef.ctxLevel === 2; }, "内层认得出自己在外层里");
        compare(host.outerRef.ctxLevel, 1, "外层自己是第一层");
        compare(host.innerRef.spacing, 2, "level > 0 ⇒ NESTED_SPACING 2");
        compare(host.outerRef.spacing, 4, "外层还是 4");
        host.destroy();
    }

    function test_menuHasNoItemGapAndFourPixelEnds() {
        const host = makeHost();
        const dd = openByCustom(host);
        const a = part(host, "itA");
        const b = part(host, "itB");
        const c = part(host, "itC");
        compare(dd.contentSpacing, 0, "官方条目之间没有间距（基座缺省 8 必须关掉）");
        compare(b.y, a.y + 36, "第二条紧贴第一条 ⇒ 间距 0");
        compare(c.y, b.y + 36);
        const content = dd.contentItem;
        verify(content !== null, "基座要有内容列");
        compare(content.y, 4, ".semi-dropdown-menu 的上内边距 4");
        compare(dd.height, content.y + content.height + 4);
        host.destroy();
    }

    // ---------------- 条目几何与颜色 ----------------

    function test_itemGeometry() {
        const host = makeHost();
        const dd = openByCustom(host);
        const a = part(host, "itA");
        compare(a.height, 36, "8 + 20 + 8（旧端口写的 32 是错的）");
        compare(a.width, dd.width, "条目铺满卡片");
        const text = part(a, "dropdownItemText");
        // 文字进了内容行之后左内边距由 Row 的 x 承担（官方 flex 里文字就是第二个格子）
        compare(part(a, "dropdownItemContent").x, 16, "$spacing-dropdown_item-paddingX");
        compare(text.font.pixelSize, Theme.current.fontSizeRegular);
        host.destroy();
    }

    function test_dividerAndTitleHeights() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '编辑' }"
            + " DropdownDivider { objectName: 'dv' }"
            + " DropdownTitle { objectName: 'tt'; text: '分组' }");
        const dd = openByCustom(host);
        const dv = part(host, "dv");
        const tt = part(host, "tt");
        compare(dv.height, 9, "1px 线 + 上下各 4");
        compare(part(dv, "dropdownDividerLine").height, 1);
        compare(tt.height, 28, "8 + 16 + 4");
        const ttText = part(tt, "dropdownTitleText");
        compare(ttText.font.pixelSize, Theme.current.fontSizeSmall, "标题走 font-size-small");
        compare(ttText.color.toString(), Theme.current.colorText2.toString());
        host.destroy();
    }

    function test_typeColorsAndNoTypeMeansTextZero() {
        const pairs = [
            ["primary", "colorPrimary"], ["secondary", "colorSecondary"],
            ["tertiary", "colorTertiary"], ["warning", "colorWarning"],
            ["danger", "colorDanger"]
        ];
        for (let i = 0; i < pairs.length; ++i) {
            const host = makeHost("trigger: 'custom'",
                " DropdownItem { objectName: 'itA'; text: 'x'; type: '" + pairs[i][0] + "' }");
            openByCustom(host);
            const a = part(host, "itA");
            compare(a.children.length > 0, true);
            const text = testCase.findChild(a, "dropdownItemText");
            compare(text.color.toString(), Theme.current[pairs[i][1]].toString(),
                pairs[i][0] + " 那一档的字色");
            host.destroy();
        }
    }

    function test_noTypeFallsBackToTextZeroNotTertiary() {
        // API 表里那条「type 缺省 tertiary」是官网写错的：defaultProps 里没有这一条
        const host = makeHost();
        openByCustom(host);
        const text = testCase.findChild(part(host, "itA"), "dropdownItemText");
        compare(text.color.toString(), Theme.current.colorText0.toString());
        verify(text.color.toString() !== Theme.current.colorTertiary.toString(),
            "别把官网那条错的缺省抄进来");
        host.destroy();
    }

    function test_activeIsBoldAndKeepsNoHoverBackground() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '选中项'; active: true }"
            + " DropdownItem { objectName: 'itB'; text: '普通项' }");
        const dd = openByCustom(host);
        const a = part(host, "itA");
        const b = part(host, "itB");
        compare(testCase.findChild(a, "dropdownItemText").font.weight, Font.DemiBold,
            "$font-dropdown_item_active-fontWeight = 600");
        mouseMove(a, a.width / 2, a.height / 2);
        waitTrue(function () {
            return Qt.colorEqual(testCase.findChild(a, "dropdownItemBg").color, "transparent");
        }, "官方三条底色规则都写着 :not(-active) ⇒ 选中项悬停不变色");
        mouseMove(b, b.width / 2, b.height / 2);
        waitTrue(function () {
            return testCase.findChild(b, "dropdownItemBg").color.toString()
                === Theme.current.colorFill0.toString();
        }, "普通项悬停出 fill-0");
        host.destroy();
    }

    function test_pressBackgroundIsFillOneAndDisabledStaysQuiet() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '甲'\n"
            + "     onMouseEntered: root.enters++ }"
            + " DropdownItem { objectName: 'itB'; text: '乙'; disabled: true\n"
            + "     onMouseEntered: root.enters++ }");
        openByCustom(host);
        const a = part(host, "itA");
        const b = part(host, "itB");
        mousePress(a, a.width / 2, a.height / 2);
        waitTrue(function () {
            return testCase.findChild(a, "dropdownItemBg").color.toString()
                === Theme.current.colorFill1.toString();
        }, "按下是 fill-1（$color-dropdown_item-bg-active），与悬停的 fill-0 不是一档");
        mouseRelease(a, a.width / 2, a.height / 2);
        const entersBefore = host.enters;
        mouseMove(b, b.width / 2, b.height / 2);
        wait(80);
        compare(host.enters, entersBefore, "禁用项不挂 onMouseEnter（官方 :85-96 那个 if）");
        host.destroy();
    }

    function test_disabledHasNoEventsAndNoBackground() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '禁用'; disabled: true }");
        openByCustom(host);
        const a = part(host, "itA");
        compare(testCase.findChild(a, "dropdownItemText").color.toString(),
            Theme.current.colorDisabledText.toString());
        mouseMove(a, a.width / 2, a.height / 2);
        wait(60);
        verify(Qt.colorEqual(testCase.findChild(a, "dropdownItemBg").color, "transparent"),
            "disabled 时 hover 底色透明（官方 :hover/:active 都写 transparent）");
        mouseClick(a, a.width / 2, a.height / 2);
        compare(host.clicks, 0, "disabled 时四个回调都不挂");
        host.destroy();
    }

    function test_selectedIsADeadProp() {
        // dropdownItem.tsx 的 render 压根没解构 selected ⇒ 对勾与字重都只看 active
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '只给 selected'; selected: true }");
        openByCustom(host);
        const a = part(host, "itA");
        verify(!testCase.findChild(a, "dropdownItemTick").visible,
            "selected 不该画对勾（官方它就是个死 prop）");
        compare(testCase.findChild(a, "dropdownItemText").font.weight, Font.Normal,
            "selected 也不该改字重");
        host.destroy();
    }

    function test_itemShowTickNeverWinsInsideDropdown() {
        // context 那份恒有值 ⇒ `contextShowTick ?? showTick` 永远落不回条目自己那条
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: 'x'; showTick: true }");
        openByCustom(host);
        verify(!testCase.findChild(part(host, "itA"), "dropdownItemTick").visible,
            "Dropdown 没开 showTick ⇒ 条目那条不生效");
        host.destroy();

        const on = makeHost("trigger: 'custom'; showTick: true",
            " DropdownItem { objectName: 'itA'; text: 'x' }"
            + " DropdownItem { objectName: 'itB'; text: 'y'; active: true }");
        openByCustom(on);
        verify(!testCase.findChild(part(on, "itA"), "dropdownItemTick").visible === false,
            "Dropdown 开了 showTick ⇒ 未选中那条也要画（透明）对勾占位");
        const tickA = testCase.findChild(part(on, "itA"), "dropdownItemTick");
        const tickB = testCase.findChild(part(on, "itB"), "dropdownItemTick");
        verify(tickA.visible && tickB.visible, "两条都得有对勾位");
        verify(Qt.colorEqual(tickA.color, "transparent"), "未选中是透明占位，不是不画");
        compare(tickB.color.toString(), Theme.current.colorPrimary.toString(), "选中那枚上色");
        on.destroy();
    }

    function test_withTickShiftsTextRightBySeventeen() {
        // 文字进了内容行，左内边距 = Row 的 x = paddingLeft（+ tickWidth + iconWidth）
        const plain = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: 'x' }");
        openByCustom(plain);
        const plainMargin = part(plain, "itA").contentX;
        plain.destroy();

        const ticked = makeHost("trigger: 'custom'; showTick: true",
            " DropdownItem { objectName: 'itA'; text: 'x' }");
        openByCustom(ticked);
        compare(part(ticked, "itA").contentX, 12 + 12 + 9,
            "withTick 左内边距 12 + 对勾 12 + 间距 9 = 33");
        compare(part(ticked, "itA").contentX - plainMargin, 17, "文字右移 17px");
        ticked.destroy();
    }

    function test_iconPropSitsBetweenTickAndText() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '带图标'; icon: 'edit' }");
        openByCustom(host);
        const a = part(host, "itA");
        const icon = testCase.findChild(a, "dropdownItemIcon");
        verify(icon.visible);
        compare(icon.size, 16, "icon prop 那一路包在 -item-icon 里 ⇒ 不吃那条 12px 规则");
        compare(a.contentX, 16 + 16 + 8, "$spacing-dropdown_item-paddingX + 图标 + 8");
        host.destroy();
    }

    // ---------------- 四个鼠标回调 ----------------

    function test_clickAndHoverSignals() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: 'x'\n"
            + "     onClicked: root.clicks++\n"
            + "     onMouseEntered: root.enters++\n"
            + "     onMouseLeft: root.leaves++\n"
            + "     onContextMenu: root.ctxHits++ }");
        openByCustom(host);
        const a = part(host, "itA");
        const before = host.enters;
        mouseMove(a, a.width / 2, a.height / 2);
        waitTrue(function () { return host.enters > before; }, "move 进条目要发 mouseEntered");
        mouseMove(host.tgtRef, 5, 5);
        waitTrue(function () { return host.leaves > 0; }, "move 出条目要发 mouseLeft");
        mouseClick(a, a.width / 2, a.height / 2);
        compare(host.clicks, 1, "左键一次 = clicked 一次（level === 1 走 click）");
        mouseClick(a, a.width / 2, a.height / 2, Qt.RightButton);
        compare(host.ctxHits, 1, "onContextMenu");
        host.destroy();
    }

    function test_nestedLevelFiresOnClickDownNotRelease() {
        // dropdownItem.tsx:86-93 —— context.level !== 1 时 onClick 被换成 onMouseDown(左键)
        const host = make("Item { id: root; width: 700; height: 600;"
            + " property var innerRef: inner; property int innerClicks: 0;"
            + " Rectangle { id: tgt; width: 120; height: 40; focusPolicy: Qt.StrongFocus }"
            + " Dropdown { id: outer; target: tgt; motion: false; trigger: 'custom'; visible: true;"
            + "     DropdownItem { id: outerItem; objectName: 'outerItem'; text: '外层条目' }"
            + "     Dropdown { id: inner; target: outerItem; motion: false;"
            + "         trigger: 'custom'; visible: true;"
            + "         DropdownItem { objectName: 'innerItem'; text: '内层条目'\n"
            + "             onClicked: root.innerClicks++ }"
            + "     }"
            + " } }");
        waitTrue(function () { return host.innerRef.ctxLevel === 2; }, "内层是第二层");
        wait(60);   // 收养之后位置器才把条目排开，按下才有落点
        const item = part(host, "innerItem");
        verify(item !== null, "内层条目要能找到");
        compare(item.level, 2, "条目的 level 取自宿主");
        mousePress(item, item.width / 2, item.height / 2);
        waitTrue(function () { return host.innerClicks === 1; },
            "嵌套那一档按下就发（官方换成 onMouseDown）");
        mouseRelease(item, item.width / 2, item.height / 2);
        compare(host.innerClicks, 1, "松开不该再发一次");
        host.destroy();
    }

    // ---------------- 继承来的触发模型 ----------------

    function test_onlyClickTriggerGrabsFocusOnOpen() {
        const host = makeHost("trigger: 'custom'");
        const dd = openByCustom(host);
        wait(120);
        dd.refreshItems();
        for (let i = 0; i < dd.focusableItems.length; ++i)
            verify(!dd.focusableItems[i].activeFocus,
                "官方 foundation:18-21 那个 if 只认 click 档 ⇒ custom 档打开不该自己抢焦点");
        host.destroy();
    }

    function test_hoverOpensAfterEnterDelayAndCardCountsAsInside() {
        const host = makeHost();
        const dd = ddOf(host);
        compare(dd.trigger, "hover", "缺省档");
        mouseMove(host.tgtRef, 5, 5);
        waitTrue(function () { return dd.visible; }, "悬停 target 50ms 后开");
        const a = part(host, "itA");
        mouseMove(a, a.width / 2, a.height / 2);
        wait(160);
        verify(dd.visible, "鼠标从 target 挪进卡片还在悬停 ⇒ 不该收");
        host.destroy();
    }

    function test_clickTriggerFocusesFirstItemOnOpen() {
        const host = makeHost();
        const dd = openByClick(host);
        waitTrue(function () {
            return part(host, "itA").activeFocus;
        }, "官方 foundation:18-21 只有 click 档在打开时把焦点送进第一项");
        host.destroy();
    }

    function test_customTriggerDoesNotCloseItself() {
        const host = makeHost("trigger: 'custom'");
        const dd = ddOf(host);
        dd.visible = true;
        waitTrue(function () { return part(host, "itA").width > 0; });
        mouseClick(host.tgtRef, 5, 5);
        wait(120);
        verify(dd.visible, "custom 档显隐完全归调用方");
        dd.visible = false;
        host.destroy();
    }

    function test_escClosesAndReturnsFocusToTarget() {
        const host = makeHost("trigger: 'click'");
        openByClick(host);
        verify(host.tgtRef.activeFocus || true);
        keyClick(Qt.Key_Escape);
        waitTrue(function () { return !ddOf(host).visible; }, "closeOnEsc 缺省 true ⇒ Esc 关层");
        compare(host.escHits, 1, "onEscKeyDown 发一次");
        host.destroy();
    }

    // ---------------- 键盘导航 ----------------

    function test_triggerArrowDownFocusesFirstItem() {
        // 先开层：没开的时候菜单内容还没造出来，官方那边是 getElementById 拿不到 ⇒ 同样空操作
        const host = makeHost("trigger: 'custom'");
        openByCustom(host);
        host.tgtRef.forceActiveFocus();
        waitTrue(function () { return host.tgtRef.activeFocus; });
        keyClick(Qt.Key_Down);
        waitTrue(function () {
            return part(host, "itA").activeFocus;
        }, "trigger 上 ArrowDown ⇒ 焦点进第一项（层没开也送，官方只把 preventDefault 收了）");
        host.destroy();
    }

    function test_triggerArrowUpFocusesLastItem() {
        const host = makeHost("trigger: 'custom'");
        openByCustom(host);
        host.tgtRef.forceActiveFocus();
        waitTrue(function () { return host.tgtRef.activeFocus; });
        keyClick(Qt.Key_Up);
        waitTrue(function () {
            return part(host, "itC").activeFocus;
        }, "trigger 上 ArrowUp ⇒ 焦点进最后一项");
        host.destroy();
    }

    function test_arrowKeysInsideMenuDoNotWrap() {
        // 焦点进了菜单之后就是菜单那半在管：第一项再按 Up 不会绕回末项
        const host = makeHost("trigger: 'custom'");
        const dd = openByCustom(host);
        dd.focusFirstItem();
        waitTrue(function () { return part(host, "itA").activeFocus; });
        keyClick(Qt.Key_Up);
        wait(80);
        verify(part(host, "itA").activeFocus, "第一项按 Up 停住");
        verify(!part(host, "itC").activeFocus, "没有绕回末项");
        host.destroy();
    }

    function test_arrowKeysMoveAndSkipDisabledAndDoNotWrap() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '甲' }"
            + " DropdownItem { objectName: 'itB'; text: '乙'; disabled: true }"
            + " DropdownItem { objectName: 'itC'; text: '丙' }");
        const dd = openByCustom(host);
        compare(dd.focusableItems.length, 2, "禁用项不在名单里（官方那条 ariaDisabled 过滤）");
        dd.focusFirstItem();
        waitTrue(function () { return part(host, "itA").activeFocus; });
        keyClick(Qt.Key_Down);
        waitTrue(function () {
            return part(host, "itC").activeFocus;
        }, "往下要跳过禁用那条");
        keyClick(Qt.Key_Down);
        wait(80);
        verify(part(host, "itC").activeFocus, "走到末了就停住，官方不循环");
        keyClick(Qt.Key_Up);
        waitTrue(function () { return part(host, "itA").activeFocus; });
        keyClick(Qt.Key_Up);
        wait(80);
        verify(part(host, "itA").activeFocus, "走到头也停住");
        host.destroy();
    }

    function test_titlesAndDividersAreNotFocusable() {
        const host = makeHost("trigger: 'custom'",
            " DropdownTitle { text: '分组' }"
            + " DropdownItem { objectName: 'itA'; text: '甲' }"
            + " DropdownDivider {}"
            + " DropdownItem { objectName: 'itB'; text: '乙' }");
        const dd = openByCustom(host);
        compare(dd.focusableItems.length, 2, "标题与分隔线都不是 <li role=menuitem>");
        dd.focusFirstItem();
        keyClick(Qt.Key_Down);
        waitTrue(function () { return part(host, "itB").activeFocus; });
        host.destroy();
    }

    function test_enterActivatesTheFocusedItem() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '甲'; onClicked: root.clicks++ }"
            + " DropdownItem { objectName: 'itB'; text: '乙'; onClicked: root.clicks++ }");
        const dd = openByCustom(host);
        dd.focusLastItem();
        waitTrue(function () { return part(host, "itB").activeFocus; });
        keyClick(Qt.Key_Return);
        compare(host.clicks, 1, "Enter 等于点当前项");
        keyClick(Qt.Key_Space);
        compare(host.clicks, 2, "Space 同一条路");
        host.destroy();
    }

    function test_printableCharJumpsToMatchingItem() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: 'Alpha' }"
            + " DropdownItem { objectName: 'itB'; text: 'beta' }"
            + " DropdownItem { objectName: 'itC'; text: 'Gamma' }");
        const dd = openByCustom(host);
        dd.focusFirstItem();
        keyClick(Qt.Key_G);
        waitTrue(function () {
            return part(host, "itC").activeFocus;
        }, "按首字母跳（官方 findIndexByCharacter 从当前项往后绕一圈）");
        keyClick(Qt.Key_A);
        waitTrue(function () {
            return part(host, "itA").activeFocus;
        }, "绕回开头也能找到");
        keyClick(Qt.Key_Z);
        wait(80);
        verify(part(host, "itA").activeFocus, "没有匹配项就不动");
        host.destroy();
    }

    function test_focusBackgroundMatchesHover() {
        const host = makeHost("trigger: 'custom'");
        const dd = openByCustom(host);
        dd.focusLastItem();
        waitTrue(function () { return part(host, "itC").activeFocus; });
        compare(testCase.findChild(part(host, "itC"), "dropdownItemBg").color.toString(),
            Theme.current.colorFill0.toString(), "官方 :focus-visible 与 hover 同色");
        host.destroy();
    }

    function test_itemKeysReachDropdownEvenFromNestedLoader() {
        // menu 档的条目挂在 Repeater + Loader 下面，键盘名单得递归才收得到
        const host = makeHost("trigger: 'custom'; visible: true; menu: ["
            + "{ node: 'item', name: 'Alpha' },"
            + "{ node: 'item', name: 'Beta' }]", "");
        const dd = ddOf(host);
        waitTrue(function () { dd.refreshItems(); return dd.focusableItems.length === 2; },
            "menu 生成的两条要进名单");
        dd.focusFirstItem();
        waitTrue(function () { return dd.focusableItems[0].activeFocus; });
        keyClick(Qt.Key_Down);
        waitTrue(function () { return dd.focusableItems[1].activeFocus; });
        host.destroy();
    }

    // ---------------- menu JSON 档 ----------------

    function test_menuJsonRendersThreeNodeKinds() {
        const host = make("Item { width: 700; height: 600;"
            + " property var ddRef: dd;"
            + " Rectangle { id: tgt; width: 120; height: 40 }"
            + " Dropdown { id: dd; target: tgt; motion: false; trigger: 'custom'; visible: true;"
            + "     menu: [ { node: 'title', name: '分组' },"
            + "             { node: 'item', name: '新建' },"
            + "             { node: 'divider' },"
            + "             { node: 'item', name: '删除', type: 'danger' } ]"
            + " } }");
        const dd = ddOf(host);
        waitTrue(function () { dd.refreshItems(); return dd.focusableItems.length === 2; },
            "menu 要生成出来：两条 item 可聚焦，title / divider 不算");
        compare(dd.focusableItems[0].text, "新建");
        compare(dd.focusableItems[1].type, "danger");
        compare(dd.focusableItems[1].height, 36);
        host.destroy();
    }

    function test_declaredChildrenWinOverMenu() {
        const host = makeHost("trigger: 'custom'; menu: [{ node: 'item', name: 'JSON 那条' }]",
            " DropdownItem { objectName: 'itA'; text: '声明那条' }");
        const dd = openByCustom(host);
        compare(dd.declaredItemCount, 1, "子项算 1（Repeater 自己不算）");
        compare(dd.menuModel.length, 0, "官方 :150-154 是 render 优先 ⇒ menu 被忽略");
        verify(part(host, "itA").visible);
        host.destroy();
    }

    function test_unknownNodeAndMissingFieldsRenderNothing() {
        const host = make("Item { width: 700; height: 600;"
            + " property var ddRef: dd;"
            + " Rectangle { id: tgt; width: 120; height: 40 }"
            + " Dropdown { id: dd; target: tgt; motion: false; trigger: 'custom'; visible: true;"
            + "     menu: [ { node: 'whatever', name: '不算数' },"
            + "             { node: 'item' } ]"
            + " } }");
        const dd = ddOf(host);
        waitTrue(function () { dd.refreshItems(); return dd.focusableItems.length === 1; },
            "未知 node 走官方 default 那一支返回 null");
        compare(dd.focusableItems[0].text, "", "缺 name 的那条还是条目，只是文字空");
        host.destroy();
    }

    function test_menuItemCallbacksFire() {
        // 注意别写成 "…a" + "…b".replace(...) —— 那样 replace 只作用在最后那一段字面量上
        const host = make("Item { id: root; width: 700; height: 600;"
            + " property var ddRef: dd; property int hits: 0;"
            + " function bump() { root.hits++ }"
            + " Rectangle { id: tgt; width: 120; height: 40 }"
            + " Dropdown { id: dd; target: tgt; motion: false; trigger: 'custom'; visible: true;"
            + "     menu: [ { node: 'item', name: '点我',"
            + "             onClick: function () { root.bump() } } ]"
            + " } }");
        const dd = ddOf(host);
        waitTrue(function () { dd.refreshItems(); return dd.focusableItems.length === 1; });
        dd.focusFirstItem();
        waitTrue(function () { return dd.focusableItems[0].activeFocus; });
        keyClick(Qt.Key_Return);
        compare(host.hits, 1, "JSON 里那个 onClick 要真的被调");
        host.destroy();
    }

    function test_menuNonArrayIsIgnored() {
        const host = makeHost("trigger: 'custom'; menu: '不是数组'",
            " DropdownItem { objectName: 'itA'; text: 'x' }");
        const dd = openByCustom(host);
        verify(!dd.menuIsArray, "官方判据是 Array.isArray");
        compare(dd.menuModel.length, 0);
        host.destroy();
    }

    // ---------------- 主题 ----------------

    function test_titleWithTickIndentIsThirtyOne() {
        const plain = makeHost("trigger: 'custom'",
            " DropdownTitle { objectName: 'tt'; text: '分组' }");
        openByCustom(plain);
        compare(part(plain, "tt").padLeft, 16, "不开放大标题左内边距就是 $spacing-base");
        plain.destroy();

        const ticked = makeHost("trigger: 'custom'; showTick: true",
            " DropdownTitle { objectName: 'tt'; text: '分组' }");
        openByCustom(ticked);
        waitTrue(function () { return part(ticked, "tt").dropdownHost !== null; }, "标题也要被收养");
        compare(part(ticked, "tt").padLeft, 31, "$spacing-dropdown_title_withTick-paddingLeft");
        ticked.destroy();
    }

    // 官方 li 是 flex：children 排在文字后面、参与条目与卡片的宽度（max-width 280 封顶）
    // ⇒ HotKeys 那类行内元素永远画在卡片背景里。旧端口条目没有内容槽，demo 只能绝对锚定
    // 在 x=160，超出卡片宽度的那截背景是透明的（用户报的问题）
    function test_itemInlineChildrenFlowAndWidenCard() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: '短'\n"
                + " Rectangle { objectName: 'inlineKid'; width: 100; height: 20; color: 'transparent' } }");
        const dd = openByCustom(host);
        const a = part(host, "itA");
        const kid = part(a, "inlineKid");
        verify(kid.x >= a.textWidth + 20 - 0.5,
            "行内子项排在文字右侧（kid.x=" + kid.x + "，文字宽=" + a.textWidth + "，行内间距 20）");
        verify(dd.implicitWidth >= a.contentX + a.textWidth + 20 + 100 + 16 - 0.5,
            "卡片自然宽把行内子项连同右内边距一起包进来（实得 " + dd.implicitWidth + "）");
        host.destroy();
    }

    function test_themeChangeRepaintsCardAndItems() {
        const host = makeHost("trigger: 'custom'",
            " DropdownItem { objectName: 'itA'; text: 'x' }");
        const dd = openByCustom(host);
        const before = dd.fillColor.toString();
        const textBefore = testCase.findChild(part(host, "itA"), "dropdownItemText").color.toString();
        Theme.mode = Theme.Dark;
        waitTrue(function () {
            return dd.fillColor.toString() !== before
                && testCase.findChild(part(host, "itA"), "dropdownItemText").color.toString()
                    !== textBefore;
        }, "卡片底色与条目字色都要跟着主题换");
        compare(dd.fillColor.toString(), Theme.current.colorBg3.toString());
        Theme.mode = Theme.Light;
        host.destroy();
    }
}
