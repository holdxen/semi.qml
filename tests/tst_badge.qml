import QtQuick
import QtTest
import Semi

// Badge 徽标。规格照 packages/semi-ui/badge/index.tsx（BadgeProps :15-31、propTypes :35-50、
// defaultProps :52-60、render :64-94）与 packages/semi-foundation/badge/{badge.scss,
// variables.scss,constants.ts}，演示与 API 表照 content/show/badge/index.md。
//
// 端口口径（逐条在 src/Badge.qml 文件头）：
//   · `count` 是 ReactNode 三档（数字 / 字符串 / Component），**给了就画**，`count=0` 画 "0"
//     （旧端口的 showZero 是自造的、语义正好相反）；`custom` 那条带真值判断 ⇒ 0 与 '' 都算非节点档。
//   · `overflowCount` 官方无缺省 ⇒ `overflowCount && …` 对 undefined / 0 都是假 ⇒ 不传永不截断。
//   · `-count` 那套 18 高药丸几何要 `!dot && !custom && showBadge`；`-type` / `-theme` 两档在
//     custom 时整条不加；`-position` 要 `Boolean(position) && Boolean(children)` ⇒ 没 base 内容
//     就不绝对定位（改 `-block`）。
//   · 配色是 6 type × 3 theme 的矩阵：solid 只改底色（文字恒 bg-2）、light 底 light-default +
//     字 type 色、inverted 只改字 ⇒ **dot + inverted 是白底白环的隐形点**，照抄并钉一条。
//   · 端口没有 RTL ⇒ position 缺省恒 rightTop（官方 rtl 时 leftTop）。
//
// 一条量测纪律：**浅色主题下 bg-0..bg-3 与 white 全同值**（实测 bg1 == bg2 == #ffffff），
// 所以凡是要分「文字色 vs 描边色 vs 底色」的断言一律先切深色（下面 darkMode()），
// 并且每条都带一句「两个令牌此刻必须不同值，否则这条断言是空的」的前置断言。
TestCase {
    id: testCase

    name: "Badge"
    when: windowShown
    width: 1000
    height: 800

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
        // 上一个用例残留的指针位置会悬停到下一个用例的同一块徽标上（事件与颜色断言会串）
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
    }

    function cleanup() {
        Theme.reset();
        Theme.mode = Theme.Light;
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "badge");
    }

    function part(owner, name) {
        const node = testCase.findChild(owner, name);
        verify(node !== null && node !== undefined, "找不到 " + name);
        return node;
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 0.5,
               (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    function side(b) {
        return part(b, "badgeSide");
    }

    function label(b) {
        return part(b, "badgeLabel");
    }

    function darkMode() {
        Theme.mode = Theme.Dark;
        verify(Theme.current.colorBg1.toString() !== Theme.current.colorBg2.toString(),
               "深浅两档的 bg-1 / bg-2 在浅色主题下同值 ⇒ 这条得在深色下量");
    }

    readonly property Component lockNode: Component {
        Rectangle {
            objectName: "lockNode"
            width: 24
            height: 14
            color: "black"
        }
    }

    // ---------------- 属性面与缺省 ----------------

    function test_officialPropDefaults() {
        const b = make("Badge {}");
        verify(b.count === undefined, "官方 count 没有缺省值 ⇒ 不给就不画");
        compare(b.dot, false, "index.tsx:53");
        compare(b.type, "primary", "index.tsx:54");
        compare(b.theme, "solid", "index.tsx:55");
        compare(b.position, "rightTop", "官方在 render 里现取（rtl 时 leftTop），端口无 RTL 恒右上的");
        verify(b.overflowCount === undefined, "官方 overflowCount 无缺省 ⇒ 不传永不截断");
        compare(b.className, "", "index.tsx:56");
        compare(b.countClassName, "");
        verify(b.countStyle === undefined);
        verify(b.style === undefined);
        compare(b.showBadge, false);
        compare(b.custom, false);
        compare(b.pill, false);
        compare(b.hasChildren, false);
        compare(b.declaredCount, 0);
        b.destroy();
    }

    function test_deadPropsChangeNothing() {
        const plain = make("Badge { count: 5 }");
        const styled = make("Badge { count: 5; className: 'x'; countClassName: 'y';"
                            + "style: ({ color: 'red' }); countStyle: ({ color: 'blue' }) }");
        wait(60);
        near(styled.implicitWidth, plain.implicitWidth, "四条 DOM-only prop 不产出差异");
        near(styled.implicitHeight, plain.implicitHeight);
        near(part(styled, "badgeSide").width, part(plain, "badgeSide").width);
        compare(label(styled).color.toString(), label(plain).color.toString(),
                "官方那条 style 其实挂在内层 count 上、且给了它就整个顶掉 countStyle ⇒ 端口都不落");
        plain.destroy();
        styled.destroy();
    }

    function test_noCountDrawsNothing() {
        const b = make("Badge { Rectangle { width: 40; height: 40 } }");
        wait(60);
        compare(b.showBadge, false, "count 没给 ⇒ showBadge 假");
        near(side(b).width, 0, "官方那是一个 0×0 的空 span（type/theme 类还在，但没尺寸）");
        near(side(b).height, 0);
        compare(side(b).border.width, 0, "`-count` 没挂 ⇒ 连那圈描边也没有");
        compare(part(b, "badgeCustomNode").visible, false, "非节点档不挂 Loader");
        compare(part(b, "badgeCustomNode").active, false, "非节点档连激活都不该有（不激活才建不出 item）");
        compare(part(b, "badgeCustomNode").item, null, "没节点就不该有 item");
        compare(label(b).text, "", "count 没给 ⇒ 连文字都不该算出 undefined 这么个词");
        compare(b.implicitWidth, 40, "外层尺寸仍是 base 内容");
        b.destroy();
    }

    // ---------------- showBadge / custom 三条判据 ----------------

    function test_zeroCountStillShows() {
        // 撤掉旧端口自造的 showZero：官方 `showBadge = count !== null && typeof !== 'undefined'`
        const b = make("Badge { count: 0 }");
        wait(60);
        compare(b.showBadge, true, "count=0 也算给了");
        compare(b.custom, false, "`count && …` 的真值判断 ⇒ 0 走数字档，不算节点档");
        compare(b.pill, true);
        compare(label(b).text, "0");
        near(side(b).height, 18);
        b.destroy();
    }

    function test_nullCountHides() {
        const b = make("Badge { count: null }");
        wait(60);
        compare(b.showBadge, false, "官方显式排掉 null");
        near(side(b).width, 0);
        b.destroy();
    }

    function test_emptyStringCountIsAnEmptyPill() {
        const b = make("Badge { count: '' }");
        wait(60);
        compare(b.custom, false, "'' 也是假值 ⇒ 不算节点档");
        compare(b.pill, true, "showBadge 只看「给没给」");
        compare(label(b).text, "");
        near(side(b).height, 18, "空内容也占 min-width 那一格");
        near(side(b).width, 18);
        b.destroy();
    }

    function test_componentCountIsCustom() {
        const b = make("Badge { count: testCase.lockNode }");
        wait(80);
        compare(b.custom, true, "非数字非字符串 ⇒ custom");
        compare(b.pill, false, "`-count` 那条几何整条不挂");
        near(side(b).width, 24, "custom 档的尺寸就是节点自己那一份");
        near(side(b).height, 14);
        compare(side(b).border.width, 0, "官方 -custom 是 display:flex 的光板一块，没描边没圆角");
        near(side(b).radius, 0);
        compare(label(b).visible, false, "文字档不出现");
        compare(label(b).text, "", "custom 档连文字都不该算出来");
        compare(part(b, "badgeCustomNode").active, true, "节点档才激活 Loader");
        verify(testCase.findChild(b, "lockNode") !== null, "节点要真挂出来");
        b.destroy();
    }

    function test_dotDropsContent() {
        const b = make("Badge { dot: true; count: 5 }");
        wait(60);
        compare(b.pill, false, "`-count` 要 !dot");
        compare(label(b).visible, false, "官方是 `{dot ? null : content}` ⇒ 圆点档内容整个不渲染");
        compare(label(b).text, "", "圆点档的文字也不该算出来");
        near(side(b).width, 8);
        near(side(b).height, 8);
        b.destroy();
    }

    // ---------------- 数字与截断 ----------------

    function test_overflowCountAbsentNeverTruncates() {
        const b = make("Badge { count: 128 }");
        wait(60);
        compare(label(b).text, "128", "官方 overflowCount 无缺省 ⇒ 不传就原样");
        b.destroy();
    }

    function test_overflowCountTruncates() {
        const b = make("Badge { count: 128; overflowCount: 99 }");
        wait(60);
        compare(label(b).text, "99+");
        b.count = 99;
        wait(60);
        compare(label(b).text, "99", "判据是 `<` 而不是 `<=` ⇒ 正好等于上限不截");
        b.count = 100;
        wait(60);
        compare(label(b).text, "99+");
        b.destroy();
    }

    function test_overflowCountZeroIsFalsy() {
        const b = make("Badge { count: 5; overflowCount: 0 }");
        wait(60);
        compare(label(b).text, "5", "`overflowCount && …` ⇒ 0 是假值，不截断");
        b.destroy();
    }

    function test_negativeOverflowCountIsTruthy() {
        // 上游那条只判真值：-5 < 3 成立 ⇒ 拼出 "-5+"。端口不修，钉成照抄条目。
        const b = make("Badge { count: 3; overflowCount: -5 }");
        wait(60);
        compare(label(b).text, "-5+");
        b.destroy();
    }

    function test_stringCountIsNotTruncated() {
        const b = make("Badge { count: '128'; overflowCount: 99 }");
        wait(60);
        compare(label(b).text, "128", "`isNumber(count)` 假 ⇒ 字符串档原样");
        b.destroy();
    }

    // ---------------- 几何 ----------------

    function test_dotGeometryAndRadius() {
        const b = make("Badge { dot: true }");
        wait(60);
        near(side(b).width, 8, "$width-badge_dot");
        near(side(b).height, 8);
        near(side(b).radius, 4, "border-radius: 50% ⇒ 8 的一半");
        compare(side(b).border.width, 1, "$width-badge-border");
        b.destroy();
    }

    function test_pillMinWidthWinsForSingleDigit() {
        const b = make("Badge { count: 5 }");
        wait(60);
        near(side(b).height, 18, "$height-badge_count");
        near(side(b).radius, 9, "圆角 = 高的一半");
        compare(side(b).border.width, 1, "药丸档也带那圈 1px bg-1 描边（不是只有 dot 档）");
        verify(side(b).width >= 18, "min-width: 18");
        near(side(b).width, Math.max(18, label(b).implicitWidth + 10),
             "border-box ⇒ 文字 + 左右 4 内边距 + 左右 1 描边");
        b.destroy();
    }

    function test_pillGrowsWithTextButKeepsHeight() {
        const b = make("Badge { count: 100000 }");
        wait(60);
        near(side(b).height, 18, "多位数也只有一行的高");
        verify(side(b).width > 24, "内容宽 ⇒ 药丸变宽（实得 " + side(b).width + "）");
        near(side(b).width - label(b).implicitWidth, 2 * 4 + 2 * 1,
             "border-box 那 10 = 左右 4 内边距 + 左右 1 描边（少一份就露出来）");
        near(label(b).font.pixelSize, Theme.current.fontSizeSmall, "@include font-size-small = 12");
        compare(label(b).font.weight, Theme.current.fontWeightRegular,
                "$font-weight-regular（旧端口写的 11 / Medium 是自造）");
        b.destroy();
    }

    function test_zIndexOfSide() {
        const b = make("Badge { count: 5 }");
        wait(60);
        compare(side(b).z, 1, "$z-badge");
        b.destroy();
    }

    // ---------------- position 四档与 block 档 ----------------

    function test_positionRightTopCentersOnCorner() {
        const b = make("Badge { count: 5; Rectangle { objectName: 'baseBox'; width: 40; height: 40 } }");
        wait(60);
        near(part(b, "baseBox").width, 40);
        near(b.implicitWidth, 40, "外层尺寸就是 base 内容（徽标溢出去不算）");
        near(side(b).x, 40 - side(b).width / 2, "`right:0` + `translate(50%)` ⇒ 中心压在角点上");
        near(side(b).y, -side(b).height / 2, "`top:0` + `translate(-50%)`");
        b.destroy();
    }

    function test_positionOtherThreeCorners() {
        const b = make("Badge { count: 5; position: 'leftTop'\n"
                       + "Rectangle { width: 40; height: 40 } }");
        wait(60);
        near(side(b).x, -side(b).width / 2, "leftTop ⇒ translate(-50%, -50%)");
        near(side(b).y, -side(b).height / 2);
        b.position = "leftBottom";
        wait(60);
        near(side(b).x, -side(b).width / 2);
        near(side(b).y, 40 - side(b).height / 2, "leftBottom ⇒ bottom:0 + translate(-50%, 50%)");
        b.position = "rightBottom";
        wait(60);
        near(side(b).x, 40 - side(b).width / 2);
        near(side(b).y, 40 - side(b).height / 2);
        b.destroy();
    }

    function test_blockModeWithoutChildren() {
        const b = make("Badge { count: 5 }");
        wait(60);
        compare(b.hasChildren, false);
        near(side(b).x, 0, "官方 `-position` 类要 Boolean(children) ⇒ 没 base 内容就不绝对定位");
        near(side(b).y, 0);
        near(b.implicitWidth, side(b).width, "`-block` 档：外层尺寸就是徽标自己");
        near(b.implicitHeight, side(b).height);
        b.position = "leftBottom";
        wait(60);
        near(side(b).x, 0, "四档全都不生效（那条类名压根没挂）");
        near(side(b).y, 0);
        b.destroy();
    }

    function test_childrenAddedLaterSwitchesToPositioned() {
        const b = make("Badge { count: 5 }");
        wait(60);
        near(side(b).x, 0);
        Qt.createQmlObject("import QtQuick; Rectangle { width: 60; height: 30 }",
                           part(b, "badgeBase"), "lateBase");
        wait(80);
        compare(b.hasChildren, true, "后挂的 base 内容要进名单");
        near(b.implicitWidth, 60);
        near(side(b).x, 60 - side(b).width / 2, "位置档立刻按角点居中");
        b.destroy();
    }

    // ---------------- 配色矩阵（深色档才分得出三个 bg 令牌）----------------

    function test_solidThemeUsesTypeBackgroundOnly() {
        darkMode();
        const b = make("Badge { count: 5; type: 'danger' }");
        wait(60);
        compare(side(b).color.toString(), Theme.current.colorDanger.toString(),
                "solid ⇒ 底色 = --semi-color-danger");
        compare(label(b).color.toString(), Theme.current.colorBg2.toString(),
                "solid 的文字**不随 type 变**，是 -count 那条 default 的 bg-2");
        b.type = "success";
        wait(60);
        compare(side(b).color.toString(), Theme.current.colorSuccess.toString());
        compare(label(b).color.toString(), Theme.current.colorBg2.toString(), "文字仍是 bg-2");
        b.destroy();
    }

    function test_lightThemeSetsBothBackgroundAndText() {
        darkMode();
        const b = make("Badge { count: 5; type: 'warning'; theme: 'light' }");
        wait(60);
        compare(side(b).color.toString(), Theme.current.colorWarningLightDefault.toString());
        compare(label(b).color.toString(), Theme.current.colorWarning.toString());
        b.destroy();
    }

    function test_invertedThemeOnlyChangesText() {
        darkMode();
        const b = make("Badge { count: 5; type: 'tertiary'; theme: 'inverted' }");
        wait(60);
        compare(side(b).color.toString(), Theme.current.colorBg1.toString(),
                "inverted 的底色是 default 那条 bg-1");
        compare(label(b).color.toString(), Theme.current.colorTertiary.toString());
        b.destroy();
    }

    function test_invertedDotIsInvisible() {
        darkMode();
        const b = make("Badge { dot: true; type: 'primary'; theme: 'inverted' }");
        wait(60);
        compare(side(b).color.toString(), Theme.current.colorBg1.toString());
        compare(side(b).border.color.toString(), Theme.current.colorBg1.toString(),
                "描边恒 bg-1 ⇒ 白底白环的点，官方这个组合就是隐形的（照抄）");
        b.destroy();
    }

    function test_allSixTypesLightBackgroundsToo() {
        // solid 那一轮只查了底色，light 档每个 type 取的又是另一组令牌（`<type>-light-default`）
        // ⇒ 六个都要各钉一条，否则改错任意一个都看不出来。
        const pairs = [["primary", "colorPrimaryLightDefault"], ["secondary", "colorSecondaryLightDefault"],
                       ["tertiary", "colorTertiaryLightDefault"], ["warning", "colorWarningLightDefault"],
                       ["danger", "colorDangerLightDefault"], ["success", "colorSuccessLightDefault"]];
        const b = make("Badge { count: 5; theme: 'light' }");
        wait(60);
        for (let i = 0; i < pairs.length; ++i) {
            b.type = pairs[i][0];
            wait(30);
            compare(side(b).color.toString(), Theme.current[pairs[i][1]].toString(),
                    "light + " + pairs[i][0]);
        }
        b.destroy();
    }

    function test_allSixTypesMapToTheirOwnToken() {
        const pairs = [["primary", "colorPrimary"], ["secondary", "colorSecondary"],
                       ["tertiary", "colorTertiary"], ["danger", "colorDanger"],
                       ["warning", "colorWarning"], ["success", "colorSuccess"]];
        const b = make("Badge { count: 5 }");
        wait(60);
        for (let i = 0; i < pairs.length; ++i) {
            b.type = pairs[i][0];
            wait(30);
            compare(side(b).color.toString(), Theme.current[pairs[i][1]].toString(),
                    "type=" + pairs[i][0]);
        }
        b.destroy();
    }

    function test_unknownTypeFallsBackToDefaultBackground() {
        darkMode();
        const b = make("Badge { count: 5; type: 'bogus' }");
        wait(60);
        compare(side(b).color.toString(), Theme.current.colorBg1.toString(),
                "没有对应 type 块 ⇒ 落回 -count 的 default 底色 bg-1");
        b.theme = "light";
        wait(60);
        compare(side(b).color.toString(), Theme.current.colorBg1.toString(),
                "light 档同理：没有 `<type>-light-default` 那条规则 ⇒ 底色也落 bg-1");
        b.theme = "inverted";
        wait(60);
        compare(label(b).color.toString(), Theme.current.colorBg2.toString(),
                "inverted 的文字取不到 type 色 ⇒ 落回 default 的 bg-2");
        b.destroy();
    }

    function test_unknownThemeFallsBackToo() {
        darkMode();
        const b = make("Badge { count: 5; type: 'danger'; theme: 'bogus' }");
        wait(60);
        compare(side(b).color.toString(), Theme.current.colorBg1.toString());
        compare(label(b).color.toString(), Theme.current.colorBg2.toString(),
                "认不出的 theme ⇒ 没有文字规则，落回 default 的 bg-2");
        b.destroy();
    }

    function test_borderIsBg1InEveryTheme() {
        darkMode();
        const b = make("Badge { count: 5; type: 'danger' }");
        wait(60);
        compare(side(b).border.color.toString(), Theme.current.colorBg1.toString(), "solid");
        b.theme = "light";
        wait(60);
        compare(side(b).border.color.toString(), Theme.current.colorBg1.toString(),
                "旧端口 light 档写 transparent 是自造，官方三档都带这圈 bg-1");
        b.theme = "inverted";
        wait(60);
        compare(side(b).border.color.toString(), Theme.current.colorBg1.toString(), "inverted");
        b.destroy();
    }

    function test_customCountPaintsNoBackground() {
        darkMode();
        const b = make("Badge { count: testCase.lockNode; type: 'danger'; theme: 'light' }");
        wait(80);
        compare(side(b).color.toString(), "#00000000",
                "custom 档官方连 type/theme 类都不加 ⇒ 底色透明，节点自己画");
        b.destroy();
    }

    // ---------------- 事件 ----------------

    function test_clickedSignalFires() {
        const b = make("Badge { count: 5; Rectangle { width: 40; height: 40; color: 'transparent' } }");
        b.y = 40;          // 徽标有一半在 root 上边界之外 ⇒ 得留出这段余量，否则事件落在窗口外被丢掉
        wait(60);
        const s = Qt.createQmlObject("import QtTest; SignalSpy {}", testCase, "spy");
        s.target = b;
        s.signalName = "clicked";
        mouseClick(b, 20, 20);
        wait(60);
        compare(s.count, 1, "官方 onClick 挂在外层 span ⇒ 点在 base 内容上也算");
        mouseClick(side(b), side(b).width - 2, side(b).height - 2);
        wait(60);
        compare(s.count, 2, "点在徽标**溢出 root 的那一半**上也算（DOM 会冒泡到外层）");
        mouseClick(b, side(b).x + 2, 4);
        wait(60);
        compare(s.count, 3, "落在两侧重叠的那个象限 ⇒ 只发一次，不重不漏");
        mouseClick(b, side(b).x + 2, -3);
        wait(60);
        compare(s.count, 4, "徽标**伸到 root 上边界之外**的那一条也要算（纵向平移没加上就漏）");
        b.destroy();
        s.destroy();
    }

    function test_enterAndLeaveSignals() {
        const b = make("Badge { count: 5; Rectangle { width: 40; height: 40; color: 'transparent' } }");
        wait(60);
        const inSpy = Qt.createQmlObject("import QtTest; SignalSpy {}", testCase, "spyIn");
        inSpy.target = b;
        inSpy.signalName = "mouseEntered";
        const outSpy = Qt.createQmlObject("import QtTest; SignalSpy {}", testCase, "spyOut");
        outSpy.target = b;
        outSpy.signalName = "mouseLeft";
        mouseMove(b, 20, 20);
        wait(60);
        compare(inSpy.count, 1, "onMouseEnter → mouseEntered");
        compare(outSpy.count, 0);
        mouseMove(side(b), side(b).width - 2, side(b).height - 2);
        wait(60);
        compare(inSpy.count, 1, "从 root 内移到溢出的那一半 ⇒ 还是同一块徽标，不再发一次 entered");
        compare(outSpy.count, 0, "两侧合成一个判据，跨界不误判为离开");
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
        wait(60);
        compare(outSpy.count, 1, "onMouseLeave → mouseLeft（left 撞 QQuickItem 的 FINAL 成员，改名）");
        b.destroy();
        inSpy.destroy();
        outSpy.destroy();
    }

    // ---------------- 旧接口的去向 ----------------

    function test_appearanceHelpersServeBannerAndToastOnly() {
        // Appearance::badgeBackground / badgeForeground 还在（Banner、ToastItem 在用），
        // 但 Badge 这一轮改成按官方令牌名直接查表，不再走它们。
        compare(Appearance.badgeBackground(Theme.current, Enums.Danger, false).toString(), "#f93920");
        compare(Appearance.badgeForeground(Theme.current, Enums.Danger, false).toString(), "#ffffff");
        compare(Appearance.badgeBackground(Theme.current, Enums.Primary, true).toString(),
                Theme.current.colorPrimaryLightDefault.toString());
        compare(Appearance.badgeForeground(Theme.current, Enums.Primary, true).toString(), "#0064fa");
        // Badge 这一轮不再走它们 ⇒ 同一份 danger/solid 由端口自己查表给出，值与官方令牌一致
        const b = make("Badge { count: 5; type: 'danger' }");
        wait(60);
        compare(side(b).color.toString(), Theme.current.colorDanger.toString(),
                "端口取的是 --semi-color-danger 本身，不是 helper 里那份写死值");
        b.destroy();
    }
}
