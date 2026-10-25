import QtQuick
import QtTest
import Semi

// Tag / TagGroup / SplitTagGroup。
// 规格照 packages/semi-ui/tag/{index,group,splitTagGroup}.tsx、interface.ts 与
// semi-foundation/tag/{tag,variables,mixin}.scss，色值 / 尺寸一律取编译后的
// packages/semi-ui/dist/css/semi.css 里的字面值（tests/tmp_tag_ramp.qml 把色板档位
// 打成十六进制，期望值直接写死，不拿 Theme 现算 —— 不然算式和断言同源，错了也一起绿）。
// 层叠顺序（colorful 两个类名 > avatar > white > color-type）、-closable 与
// -avatar-* 的内边距、+N 的纯算术溢出都在这份文件里钉住。
TestCase {
    id: testCase

    name: "Tag"
    when: windowShown
    width: 900
    height: 600

    property var spies: []

    // 动态建出来的标签要能拿到 Component —— Qt.createQmlObject 的上下文就是
    // TestCase，所以这两个组件在用到的那两条里裸名引用即可
    property Component smallStar: Component {
        Icon {
            name: "ai_filled_level_3"
            size: 12
            tinted: false
        }
    }

    property Component redBox: Component {
        Rectangle {
            width: 30
            height: 10
            color: "#ff0000"
        }
    }

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    function cleanup() {
        for (let i = 0; i < testCase.spies.length; ++i)
            testCase.spies[i].destroy();
        testCase.spies = [];
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe");
    }

    function makeLaid(qml) {
        const o = make(qml);
        wait(20);
        return o;
    }

    function findAll(root, name, out) {
        if (out === undefined)
            out = [];
        const kids = root.children;
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i].objectName === name)
                out.push(kids[i]);
            // qmllint enable missing-property
            findAll(kids[i], name, out);
        }
        return out;
    }

    function one(root, name) {
        const hits = findAll(root, name);
        return hits.length > 0 ? hits[0] : null;
    }

    function surf(t) {
        return one(t, "tagSurface");
    }

    function label(t) {
        return one(t, "tagLabel");
    }

    function row(t) {
        return one(t, "tagContent");
    }

    // 把某个信号挂上 spy
    function spill(item, names) {
        const out = {};
        for (let i = 0; i < names.length; ++i) {
            const spy = Qt.createQmlObject(
                "import QtQuick; import QtTest; SignalSpy { }", item, "spy");
            spy.target = item;
            spy.signalName = names[i];
            testCase.spies.push(spy);
            out[names[i]] = spy;
        }
        return out;
    }

    // 整棵子树里的 Tag（按 objectName 挑，顺序按排版位置）
    function tagsIn(root, name) {
        const list = findAll(root, name);
        list.sort(function (a, b) {
            return a.mapToItem(root, 0, 0).x - b.mapToItem(root, 0, 0).x;
        });
        return list;
    }

    // ---------------- 尺寸与内边距 ----------------

    function test_sizeHeights() {
        const small = make('Tag { text: "x"; size: "small" }');
        const def = make('Tag { text: "x" }');
        const large = make('Tag { text: "x"; size: "large" }');
        compare(def.size, "default", "官方 defaultProps size = TAG_SIZE[0] = default");
        compare(small.implicitHeight, 20);       // $height-tag_small
        compare(def.implicitHeight, 20, "default 与 small 共用同一段样式");
        compare(large.implicitHeight, 24);       // $height-tag_large
        compare(label(def).font.pixelSize, 12, "@include font-size-small");
        compare(label(large).font.pixelSize, 12);
        small.destroy(); def.destroy(); large.destroy();
    }

    function test_paddings() {
        const plain = make('Tag { text: "x" }');
        const closable = make('Tag { text: "x"; closable: true }');
        const avatarSquare = make('Tag { text: "x"; avatarSrc: "file:///nope.png" }');
        const avatarCircle = make('Tag { text: "x"; avatarSrc: "file:///nope.png"; avatarShape: "circle" }');
        compare(plain.padLeft, 8);
        compare(plain.padRight, 8);
        compare(closable.padLeft, 8, "-closable 只收右边");
        compare(closable.padRight, 4);           // $spacing-tag_closable-paddingRight
        compare(avatarSquare.padLeft, 0, "-avatar-square 是 0 4 0 0");
        compare(avatarSquare.padRight, 4);
        compare(avatarCircle.padLeft, 2, "-avatar-circle 是 2 4 2 2");
        compare(avatarCircle.padRight, 4);
        plain.destroy(); closable.destroy(); avatarSquare.destroy(); avatarCircle.destroy();
    }

    // 宽度算式与 Row 自己排出来的 implicitWidth 互相对账：两边同源就查不出漏算
    function test_widthFormulaAgreesWithRowLayout() {
        const cases = [
            'Tag { text: "抖音" }',
            'Tag { text: "抖音"; closable: true }',
            'Tag { text: "抖音"; prefixIcon: "clock" }',
            'Tag { text: "抖音"; prefixIcon: "clock"; suffixIcon: "close"; closable: true }',
            'Tag { text: "抖音"; size: "large"; shape: "circle"; prefixIcon: "folder" }',
            'Tag { text: "抖音"; avatarSrc: "file:///nope.png" }',
            'Tag { text: "抖音"; avatarSrc: "file:///nope.png"; avatarShape: "circle"; closable: true }'
        ];
        for (let i = 0; i < cases.length; ++i) {
            const t = makeLaid(cases[i]);
            const expected = t.padLeft + t.padRight + row(t).implicitWidth;
            fuzzyCompare(t.implicitWidth, expected, 0.01,
                cases[i] + " 宽度算式 = 内边距 + 行内实际排布");
            t.destroy();
        }
    }

    function test_noFalseTruncationWhenUnclamped() {
        // naturalWidth 一旦声明成 int 就被截掉小数，label 少拿零点几像素、
        // 于是每一条标签都报「截断」（旧坑 47，这里重新钉住）
        const t = make('Tag { text: "抖音" }');
        compare(t.textClipped, false, "没封顶不该判成截断");
        fuzzyCompare(t.bodyWidth, label(t).implicitWidth, 0.001);
        fuzzyCompare(t.implicitWidth, t.naturalWidth, 0.001);
        t.destroy();
    }

    // ---------------- 形状与圆角 ----------------

    function test_shapeRadius() {
        const square = make('Tag { text: "x" }');
        const circleSmall = make('Tag { text: "x"; shape: "circle" }');
        const circleLarge = make('Tag { text: "x"; shape: "circle"; size: "large" }');
        compare(surf(square).topLeftRadius, 3);      // $radius-tag = border-radius-small
        compare(surf(square).topRightRadius, 3);
        compare(surf(circleSmall).topLeftRadius, 10, "全圆角 = 高的一半");
        compare(surf(circleLarge).topLeftRadius, 12);
        // 四角都得是同一个值，胶囊才不会有方角漏出来
        compare(surf(circleLarge).bottomRightRadius, 12);
        square.destroy(); circleSmall.destroy(); circleLarge.destroy();
    }

    function test_avatarCircleRadiusIsHeightHalfPlusOne() {
        const small = make('Tag { text: "焦锐志"; avatarSrc: "file:///nope.png"; avatarShape: "circle" }');
        const large = make('Tag { text: "焦锐志"; avatarSrc: "file:///nope.png"; avatarShape: "circle"; size: "large" }');
        compare(surf(small).topLeftRadius, 11);      // 20 * 0.5 + 1
        compare(surf(large).topLeftRadius, 13);      // 24 * 0.5 + 1
        small.destroy(); large.destroy();
    }

    function test_avatarSides() {
        const square = make('Tag { text: "焦"; avatarSrc: "file:///nope.png" }');
        const squareLarge = make('Tag { text: "焦"; avatarSrc: "file:///nope.png"; size: "large" }');
        const circle = make('Tag { text: "焦"; avatarSrc: "file:///nope.png"; avatarShape: "circle" }');
        const circleLarge = make('Tag { text: "焦"; avatarSrc: "file:///nope.png"; avatarShape: "circle"; size: "large" }');
        compare(square.avatarSide, 20, "-avatar-square 的头与标签等高");
        compare(squareLarge.avatarSide, 24);
        compare(circle.avatarSide, 16, "$width-tag_avatar_circle_small");
        compare(circleLarge.avatarSide, 20, "$width-tag_avatar_circle_large");
        square.destroy(); squareLarge.destroy(); circle.destroy(); circleLarge.destroy();
    }

    // ---------------- 色板层叠 ----------------

    function test_lightTypePaletteRule() {
        const grey = make('Tag { text: "x" }');
        const blue = make('Tag { text: "x"; color: "blue" }');
        const lightBlue = make('Tag { text: "x"; color: "light-blue" }');
        compare(grey.type, "light", "官方默认 type = light");
        compare(grey.color, "grey", "官方默认 color = TAG_COLOR[0] = grey");
        // light = rgba(palette-5, .15) 底 + palette-8 字（mixin.scss）
        compare(surf(grey).color.toString(), "#266b7075");
        compare(label(grey).color.toString(), "#2e3238");
        compare(surf(blue).color.toString(), "#260064fa");
        compare(label(blue).color.toString(), "#003d8f");
        compare(surf(lightBlue).color.toString(), "#260095ee", "连字符档名要能找到 lightBlue");
        compare(label(lightBlue).color.toString(), "#004b83");
        compare(surf(lightBlue).border.width, 0, "light 档没有描边");
        grey.destroy(); blue.destroy(); lightBlue.destroy();
    }

    function test_solidAndGhostRules() {
        const solid = make('Tag { text: "x"; color: "cyan"; type: "solid" }');
        const ghost = make('Tag { text: "x"; color: "teal"; type: "ghost" }');
        compare(surf(solid).color.toString(), "#05a4b6", "solid = palette-5 实底");
        compare(label(solid).color.toString(), "#ffffff", "solid 的字固定是 white");
        compare(surf(solid).border.width, 0);
        compare(surf(ghost).color.toString(), "#00000000", "ghost 的底是 transparent");
        compare(surf(ghost).border.width, 1, "$width-tag-border");
        compare(surf(ghost).border.color.toString(), "#27c2b0", "ghost 的描边取 palette-4");
        compare(label(ghost).color.toString(), "#00b3a1", "ghost 的字取 palette-5");
        solid.destroy(); ghost.destroy();
    }

    function test_allSeventeenColorNamesAreKnown() {
        const names = ["amber", "blue", "cyan", "green", "grey", "indigo", "light-blue",
            "light-green", "lime", "orange", "pink", "purple", "red", "teal", "violet",
            "yellow", "white"];
        const expected = {
            "amber": "#26f0b114", "blue": "#260064fa", "cyan": "#2605a4b6",
            "green": "#263bb346", "grey": "#266b7075", "indigo": "#263f51b5",
            "light-blue": "#260095ee", "light-green": "#267bb63c", "lime": "#269bd100",
            "orange": "#26fc8800", "pink": "#26e91e63", "purple": "#269e28b3",
            "red": "#26f93920", "teal": "#2600b3a1", "violet": "#266a3ac7",
            "yellow": "#26fac800"
        };
        for (let i = 0; i < names.length; ++i) {
            const name = names[i];
            const t = make('Tag { text: "x"; color: "' + name + '" }');
            if (name === "white")
                compare(surf(t).color.toString(), "#ffffff", "white 档走 bg-4");
            else
                compare(surf(t).color.toString(), expected[name], name + " 的 light 底");
            t.destroy();
        }
    }

    function testWhiteRule(type) {
        const t = make('Tag { text: "x"; color: "white"; type: "' + type + '" }');
        // $color-tag_white-*：bg-4 底 + rgba(grey-2,.7) 描边 + text-0 字，三种 type 一样
        compare(surf(t).color.toString(), "#ffffff");
        compare(surf(t).border.width, 1);
        compare(surf(t).border.color.toString(), "#b3c6cacd", "grey-2 = #c6cacd，alpha .7 = b3");
        compare(label(t).color.toString(), "#1c1f23");
        t.destroy();
    }

    function test_whiteSetForEveryType() {
        testWhiteRule("light");
        testWhiteRule("solid");
        testWhiteRule("ghost");
    }

    function test_avatarOverridesColorAndType() {
        // -avatar-square / -avatar-circle 那条写在色板循环之后，压过 white 与各 type
        const t = make('Tag { text: "焦"; color: "light-blue"; type: "solid"; avatarSrc: "file:///nope.png" }');
        compare(surf(t).color.toString(), "#ffffff", "头像是 bg-4，不是 palette-5");
        compare(surf(t).border.width, 1, "-avatar-square / -avatar-circle 各自带 1px 描边");
        compare(surf(t).border.color.toString(), "#141c1f23", "$color-tag_avatar-border-default = color-border");
        compare(label(t).color.toString(), "#1c1f23", "头像的字是 text-0");
        t.destroy();
    }

    function test_unknownColorNameMatchesNoRule() {
        const t = make('Tag { text: "x"; color: "hot-pink" }');
        // 档名不在色板里时官方那条 mixin 生成不出规则，什么都不画
        compare(surf(t).color.toString(), "#00000000");
        compare(surf(t).border.width, 0);
        compare(label(t).color.toString(), "#cc1c1f23", "退到次级文字色");
        t.destroy();
    }

    function test_disabledMatchesTagInputOverride() {
        // tagInput.scss:119-122：底透明、描边不动、文字 disabled-text
        const t = make('Tag { text: "x"; color: "white"; disabled: true }');
        compare(surf(t).color.toString(), "#00000000");
        compare(surf(t).border.width, 1);
        compare(label(t).color.toString(), Theme.current.colorDisabledText.toString());
        const grey = make('Tag { text: "x"; disabled: true }');
        compare(surf(grey).color.toString(), "#00000000");
        compare(label(grey).color.toString(), Theme.current.colorDisabledText.toString());
        t.destroy(); grey.destroy();
    }

    function test_backgroundColorOverrideBeatsClasses() {
        // 官方 style 是内联，压过所有类名规则；+N 标签就是这么把底色抹掉的
        const t = make('Tag { text: "+3"; color: "grey"; backgroundColor: "transparent" }');
        compare(surf(t).color.toString(), "#00000000");
        compare(surf(t).border.width, 0, "style 只写 background 时不会带出描边");
        const painted = make('Tag { text: "+3"; color: "grey"; backgroundColor: "#7c3aed" }');
        compare(surf(painted).color.toString(), "#7c3aed");
        t.destroy(); painted.destroy();
    }

    function test_whiteAndAvatarUseBg4NotBg1() {
        // 浅色下 bg-1..bg-4 全是 #ffffff，只有暗色分得开 —— 不换到暗色就证明
        // 用的确实是 $color-tag_white-bg-default / $color-tag_avatar-bg-default
        const white = makeLaid('Tag { text: "x"; color: "white" }');
        const avatar = makeLaid('Tag { text: "焦"; avatarSrc: "file:///nope.png" }');
        Theme.mode = Theme.Dark;
        wait(320);                                // 底色挂 Behavior，等动画走完
        compare(surf(white).color.toString(), Theme.current.colorBg4.toString());
        verify(surf(white).color.toString() !== Theme.current.colorBg1.toString(),
            "暗色下 bg-1 与 bg-4 不同");
        compare(surf(avatar).color.toString(), Theme.current.colorBg4.toString());
        verify(surf(avatar).color.toString() !== Theme.current.colorBg1.toString());
        Theme.mode = Theme.Light;
        wait(320);
        white.destroy(); avatar.destroy();
    }

    function test_colorfulGhostBgIsWhiteNotBg4() {
        // $color-tag_colorful_ghost-bg: var(--semi-color-white)。浅色下 white 与 bg-4
        // 都是 #ffffff，非要暗色才分得开（同上一条的口径）
        const ghost = makeLaid('Tag { text: "AI"; colorful: true; type: "ghost" }');
        Theme.mode = Theme.Dark;
        wait(320);
        verify(Theme.current.colorWhite.toString() !== Theme.current.colorBg4.toString(),
            "暗色下 white 与 bg-4 必须不同，否则这条断言没有牙");
        compare(surf(ghost).color.toString(), Theme.current.colorWhite.toString());
        Theme.mode = Theme.Light;
        wait(320);
        ghost.destroy();
    }

    function test_backgroundColorBeatsColorfulToo() {
        // 官方内联样式压过 .semi-tag-colorful.semi-tag-solid 那两个类名
        const t = make('Tag { text: "AI"; colorful: true; type: "solid"; backgroundColor: "#123456" }');
        compare(surf(t).color.toString(), "#123456");
        t.destroy();
    }

    function test_disabledTagHasNoCloseIcon() {
        const t = make('Tag { text: "x"; color: "white"; disabled: true; closable: false }');
        compare(one(t, "tagCloseHost").visible, false);
        fuzzyCompare(t.implicitWidth, 8 + label(t).implicitWidth + 8, 0.01,
            "没有叉就没有 4px 的右内边距");
        t.destroy();
    }

    // ---------------- 图标与正文 ----------------

    function test_prefixIconNameIsSixteen() {
        const t = makeLaid('Tag { text: "抖音"; prefixIcon: "github_logo" }');
        const glyph = one(t, "tagPrefixIcon");
        compare(glyph.size, 16, "官方 <IconGithubLogo /> 不写 size 就是 16");
        compare(glyph.color.toString(), "#2e3238", "图标跟着 currentColor（light 档的 palette-8）");
        compare(t.prefixWidth, 16);
        compare(one(t, "tagPrefixLoader").visible, false, "字符串档不该起 Loader");
        // 8 左 + 16 图标 + 4（-prefix-icon padding-right）+ 正文 + 8 右
        fuzzyCompare(one(t, "tagBody").width, label(t).implicitWidth, 0.01);
        fuzzyCompare(t.implicitWidth, 8 + 16 + 4 + label(t).implicitWidth + 8, 0.01);
        t.destroy();
    }

    function test_suffixIconAndBothIcons() {
        const onlySuffix = makeLaid('Tag { text: "x"; suffixIcon: "semi_logo" }');
        fuzzyCompare(onlySuffix.implicitWidth, 8 + label(onlySuffix).implicitWidth + 4 + 16 + 8, 0.01,
            "-suffix-icon 是 padding-left 4");
        const both = makeLaid('Tag { text: "x"; prefixIcon: "clock"; suffixIcon: "close" }');
        fuzzyCompare(both.implicitWidth, 8 + 16 + 4 + label(both).implicitWidth + 4 + 16 + 8, 0.01);
        onlySuffix.destroy(); both.destroy();
    }

    function test_emptyIconNameReservesNothing() {
        // 官方 iconForNode 对空串返回 null（!children 那一支）。空串仍是 string，
        // 所以「是不是字符串」不够，必须连空档一起判掉
        const bare = makeLaid('Tag { text: "x" }');
        const empty = makeLaid('Tag { text: "x"; prefixIcon: ""; suffixIcon: "" }');
        compare(empty.prefixIsName, false);
        compare(empty.suffixIsName, false);
        compare(empty.prefixShown, false, "空串不该占图标位");
        compare(empty.suffixShown, false);
        fuzzyCompare(empty.implicitWidth, bare.implicitWidth, 0.01,
            "否则白占 16 + 4 + 4 的缝");
        bare.destroy(); empty.destroy();
    }

    function test_iconComponentKeepsOwnSize() {
        const t = makeLaid('Tag { text: "AI"; colorful: true; prefixIcon: smallStar }');
        compare(t.prefixIsComponent, true);
        compare(t.prefixIsName, false);
        compare(t.prefixWidth, 12, "组件自己决定尺寸，官方 AI 那一节写的是 size=\"small\"");
        const loader = one(t, "tagPrefixLoader");
        compare(loader.visible, true);
        compare(one(t, "tagPrefixIcon").visible, false, "组件档不画内置图标");
        const glyph = one(loader, "");
        compare(glyph.name, "ai_filled_level_3");
        compare(glyph.tinted, false, "level_3 自带渐变，着色会把渐变糊掉");
        t.destroy();
    }

    function test_customContentReplacesText() {
        const t = makeLaid('Tag { text: "不算数"; content: redBox }');
        compare(t.hasCustomContent, true);
        compare(label(t).visible, false, "官方非字符串 children 走 -content-center");
        const loaded = one(t, "tagContentLoader");
        compare(loaded.implicitWidth, 30);
        fuzzyCompare(t.bodyWidth, 30, 0.01);
        fuzzyCompare(t.implicitWidth, 8 + 30 + 8, 0.01);
        t.destroy();
    }

    function test_fontWeightFollowsColorful() {
        const plain = make('Tag { text: "x" }');
        const colorful = make('Tag { text: "AI"; colorful: true }');
        compare(label(plain).font.weight, Font.Normal, ".semi-tag 没有 font-weight");
        compare(label(colorful).font.weight, Font.DemiBold, "$font-tag_colorful-fontWeight = 600");
        plain.destroy(); colorful.destroy();
    }

    function test_maxWidthClampsAndReportsTruncation() {
        const t = make('Tag { text: "D2C: figma to code in one click"; color: "cyan"; maxWidth: 100 }');
        verify(t.naturalWidth > 100, "不封顶时应该更宽");
        compare(t.implicitWidth, 100);
        compare(t.textClipped, true);
        fuzzyCompare(label(t).width, 100 - 8 - 8, 0.01, "正文吃掉除内边距外的全部宽度");
        const wide = make('Tag { text: "D2C: figma to code in one click"; color: "cyan"; maxWidth: 600 }');
        compare(wide.textClipped, false);
        fuzzyCompare(wide.implicitWidth, wide.naturalWidth, 0.01, "没封顶就用天然宽");
        t.destroy(); wide.destroy();
    }

    // ---------------- 可关闭与受控 visible ----------------

    function test_closeIconBox() {
        const t = makeLaid('Tag { text: "x"; closable: true }');
        const glyph = one(t, "tagCloseIcon");
        compare(glyph.name, "close");
        compare(glyph.size, 12, "<IconClose size=\"small\" />");
        compare(t.closeWidth, 12);
        // 8 左 + 正文 + 4（-close padding-left）+ 12 + 4 右
        fuzzyCompare(t.implicitWidth, 8 + label(t).implicitWidth + 4 + 12 + 4, 0.01);
        t.destroy();
    }

    function test_closeHidesUncontrolledTag() {
        const t = makeLaid('Tag { text: "x"; closable: true }');
        compare(t.visible, true);
        mouseClick(t, t.width - 8, t.height / 2);
        wait(40);
        compare(t.visible, false, "官方 close() 没被拦截时 setVisible(false)");
        t.destroy();
    }

    function test_preventDefaultKeepsTagShown() {
        const t = makeLaid('Tag { text: "x"; closable: true;'
            + ' onClosed: (tagChildren, event, tagKey) => event.preventDefault() }');
        mouseClick(t, t.width - 8, t.height / 2);
        wait(40);
        compare(t.visible, true, "e.preventDefault() 之后标签留着");
        t.destroy();
    }

    function test_closedCarriesChildrenAndTagKey() {
        const t = makeLaid('Tag { text: "抖音"; closable: true; tagKey: "k1" }');
        const spy = spill(t, ["closed"]);
        t.requestClose();
        compare(spy.closed.count, 1);
        const args = spy.closed.signalArguments[0];
        compare(args[0], "抖音", "官方第一个参数是 tagChildren");
        compare(args[2], "k1", "第三个参数是 tagKey（v2.18.0 起）");
        verify(args[1] !== undefined && args[1].prevented === false, "事件对象带 defaultPrevented");
        t.destroy();
    }

    function test_closeClickDoesNotFireClicked() {
        // 官方 close() 里 stopPropagation + stopImmediatePropagation
        const t = makeLaid('Tag { text: "x"; closable: true }');
        const spy = spill(t, ["clicked", "closed"]);
        mouseClick(t, t.width - 8, t.height / 2);
        wait(40);
        compare(spy.closed.count, 1);
        compare(spy.clicked.count, 0, "点叉不该同时算点标签");
        t.destroy();
    }

    function test_bodyClickFiresClicked() {
        const t = makeLaid('Tag { text: "标签一" }');
        const spy = spill(t, ["clicked"]);
        mouseClick(t, 12, t.height / 2);
        wait(40);
        compare(spy.clicked.count, 1);
        t.destroy();
    }

    function test_controlledVisibleIgnoresInternalState() {
        const host = makeLaid('Item { property bool shown: true;'
            + ' Tag { objectName: "ctl"; text: "x"; closable: true; visible: parent.shown } }');
        const t = one(host, "ctl");
        compare(t.visible, true);
        t.requestClose();
        compare(t.visible, true, "使用处绑了 visible 就把内部绑定顶掉（= 官方受控）");
        host.shown = false;
        compare(t.visible, false, "受控时只听外部");
        host.shown = true;
        compare(t.visible, true, "外部绑定不会被内部的状态写死");
        host.destroy();
    }

    function test_closeIconColors() {
        // 两枚都要各自吃得到悬浮，位置错开：叠在一起时只有上层拿得到 hover
        const grey = makeLaid('Tag { x: 0; text: "x"; closable: true }');
        const white = makeLaid('Tag { x: 200; text: "x"; closable: true; color: "white" }');
        compare(one(grey, "tagCloseIcon").color.toString(), "#9e1c1f23", "default text-2");
        mouseMove(grey, grey.width - 8, grey.height / 2);
        wait(60);
        compare(one(grey, "tagCloseIcon").color.toString(), "#cc1c1f23", "-close:hover 是 text-1");
        // white 档那条 .semi-tag-white-* .semi-tag-close 与 :hover 同为两类名且写在后面
        mouseMove(white, white.width - 8, white.height / 2);
        wait(60);
        compare(one(white, "tagCloseIcon").color.toString(), "#9e1c1f23",
            "白底标签的叉悬浮不提亮（编译后的层叠就是这样）");
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
        wait(60);
        grey.destroy(); white.destroy();
    }

    function test_closeIconPressedColor() {
        // $color-tag_close-icon-active = text-0，比 hover 那档（text-1）更深一档
        const t = makeLaid('Tag { text: "x"; closable: true }');
        const host = one(t, "tagCloseHost");
        mouseMove(t, t.width - 8, t.height / 2);
        wait(60);
        compare(one(t, "tagCloseIcon").color.toString(), "#cc1c1f23", "先悬浮：text-1");
        mousePress(host);
        wait(40);
        compare(one(t, "tagCloseIcon").color.toString(), "#1c1f23", "按下 text-0");
        mouseRelease(host);
        wait(40);
        compare(t.visible, false, "叉的抬起照常关闭（按下态没改掉点击语义）");
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
        t.destroy();
    }

    function test_mouseEnteredSignal() {
        const t = makeLaid('Tag { text: "x" }');
        const spy = spill(t, ["mouseEntered"]);
        mouseMove(t, 4, t.height / 2);
        wait(60);
        compare(spy.mouseEntered.count, 1, "官方 onMouseEnter");
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
        wait(40);
        t.destroy();
    }

    // ---------------- 键盘 ----------------

    function test_keyboardDeleteCloses() {
        const t = make('Tag { text: "x"; closable: true }');
        t.forceActiveFocus();
        wait(20);
        keyPress(Qt.Key_Delete);
        wait(20);
        compare(t.visible, false);
        t.destroy();
    }

    function test_keyboardBackspaceCloses() {
        const t = make('Tag { text: "x"; closable: true }');
        t.forceActiveFocus();
        wait(20);
        keyPress(Qt.Key_Backspace);
        wait(20);
        compare(t.visible, false);
        t.destroy();
    }

    function test_keyboardNotClosableDoesNotHide() {
        const t = make('Tag { text: "x" }');
        const spy = spill(t, ["closed"]);
        t.forceActiveFocus();
        wait(20);
        keyPress(Qt.Key_Delete);
        wait(20);
        compare(spy.closed.count, 0, "closable=false 时按键不关闭");
        compare(t.visible, true);
        t.destroy();
    }

    function test_keyboardEnterFiresClicked() {
        const t = make('Tag { text: "x" }');
        const spy = spill(t, ["clicked", "keyPressed"]);
        t.forceActiveFocus();
        wait(20);
        keyPress(Qt.Key_Return);
        wait(20);
        compare(spy.clicked.count, 1, "官方 Enter → onClick");
        compare(spy.keyPressed.count, 1, "onKeyDown 在最后照样回调");
        t.destroy();
    }

    function test_keyboardEscapeBlurs() {
        const t = make('Tag { text: "x"; closable: true }');
        t.forceActiveFocus();
        wait(20);
        verify(t.activeFocus, "先要真的拿到焦点");
        keyPress(Qt.Key_Escape);
        wait(20);
        compare(t.activeFocus, false, "Escape 失焦");
        t.destroy();
    }

    function test_focusableOnlyWhenClosable() {
        const plain = make('Tag { text: "x" }');
        const closable = make('Tag { text: "x"; closable: true }');
        compare(plain.activeFocusOnTab, false, "官方只有 clickable 才给 tabIndex 0");
        compare(closable.activeFocusOnTab, true);
        plain.destroy(); closable.destroy();
    }

    function test_focusRingIsTwoPixels() {
        const t = make('Tag { text: "x"; closable: true }');
        const ring = one(t, "tagFocusRing");
        compare(ring.border.width, 2);             // $width-tag-outline
        compare(ring.border.color.toString(), Theme.current.colorPrimaryLightActive.toString());
        compare(ring.visible, false, "没聚焦不画");
        // 焦点环仿 :focus-visible，只有键盘交互之后才亮。shouldShow() 是函数调用，
        // 绑定只跟 activeFocus 依赖，所以顺序得跟真实操作一致：先进键盘模式，
        // 再让标签拿焦点（Tab 就是按键先到、焦点后动）
        keyPress(Qt.Key_Escape);
        wait(20);
        compare(FocusVisible.keyboardMode, true);
        t.forceActiveFocus();
        wait(20);
        compare(t.activeFocus, true);
        compare(ring.visible, true);
        t.destroy();
    }

    // ---------------- 多彩（AI）标签 ----------------

    function test_colorfulSolidAndLight() {
        const solid = make('Tag { text: "AI"; colorful: true; type: "solid" }');
        const light = make('Tag { text: "AI"; colorful: true; type: "light" }');
        const ghost = make('Tag { text: "AI"; colorful: true; type: "ghost" }');
        compare(surf(solid).color.toString(), "#a647ff", "$color-tag_colorful_solid-bg");
        compare(label(solid).color.toString(), "#ffffff");
        compare(surf(light).color.toString(), "#f8edff", "rgba(var(--semi-ai-purple-0), 1)");
        compare(label(light).color.toString(), "#a647ff");
        compare(surf(ghost).color.toString(), "#ffffff", "ghost 的底是 white");
        compare(label(ghost).color.toString(), "#a647ff");
        compare(surf(ghost).border.width, 1, "-grey-ghost 那条给了 1px，colorful 只改色");
        // border-color: var(--semi-color-ai-general) 是一支渐变，浏览器按 IACVT
        // 退成 currentColor，也就是 ai-purple
        compare(surf(ghost).border.color.toString(), "#a647ff");
        solid.destroy(); light.destroy(); ghost.destroy();
    }

    function test_colorfulGradientUsesAiGeneral() {
        const solid = make('Tag { text: "AI"; colorful: true; type: "solid"; gradient: true }');
        const light = make('Tag { text: "AI"; colorful: true; type: "light"; gradient: true }');
        const ghost = make('Tag { text: "AI"; colorful: true; type: "ghost"; gradient: true }');
        const plain = make('Tag { text: "AI"; colorful: true; type: "light" }');
        compare(one(solid, "tagGradientSurface").visible, true, "solid+gradient 要铺渐变底");
        compare(one(light, "tagGradientSurface").visible, true, "light+gradient 用 ai-general-0");
        compare(one(ghost, "tagGradientSurface").visible, false, "ghost 的渐变是描边，不是底");
        compare(one(plain, "tagGradientSurface").visible, false);
        // background-clip / 渐变描边 QML 画不出来，退成首尾色标中值（同 Button）
        compare(surf(solid).color.toString(), "#8c69ff");
        compare(surf(light).color.toString(), "#f7f5ff");
        compare(label(light).color.toString(), "#8c69ff", "渐变铺字退成代表色");
        compare(surf(ghost).border.color.toString(), "#8c69ff", "渐变描边退成代表色");
        solid.destroy(); light.destroy(); ghost.destroy(); plain.destroy();
    }

    function test_gradientStopsComeFromCss() {
        const t = make('Tag { text: "AI"; colorful: true; type: "solid"; gradient: true }');
        compare(t.gradientStops.length, 4, "278deg 那支渐变四个色标");
        compare(t.stopColor(0), "#2e8cff", "CSS 0% 放在右端，所以首标是最后一个色");
        compare(t.stopPosition(0), 0);
        compare(t.stopColor(3), "#e945ff");
        compare(t.stopPosition(3), 1);
        const bogus = make('Tag { text: "AI"; colorful: true; type: "light" }');
        compare(bogus.gradientStops.length, 0, "不铺渐变时不该去解析");
        t.destroy(); bogus.destroy();
    }

    // ---------------- TagGroup ----------------

    function groupQml(extra, list) {
        const head = extra === "" ? "" : extra + "; ";
        return 'TagGroup { width: 350; ' + head + 'tagList: [' + list + '] }';
    }

    property string fourTags: '{ color: "light-blue", children: "抖音" },'
        + ' { color: "cyan", children: "火山" },'
        + ' { color: "violet", children: "剪映" },'
        + ' { color: "white", children: "醒图" }';

    function test_groupWithoutMaxRendersAll() {
        const g = makeLaid(groupQml('size: "large"', fourTags));
        const items = tagsIn(g, "tagGroupItem");
        compare(items.length, 4, "maxTagCount 缺省时整组渲染");
        compare(one(g, "tagGroupPlusN").visible, false, "没有溢出就不加 +N");
        compare(one(g, "tagGroupPlusN").text, "+0");
        g.destroy();
    }

    function test_groupMaxTagCountArithmetic() {
        const g = makeLaid(groupQml('maxTagCount: 3; size: "large"', fourTags));
        const items = tagsIn(g, "tagGroupItem");
        compare(items.length, 3);
        compare(one(g, "tagGroupPlusN").visible, true);
        compare(one(g, "tagGroupPlusN").text, "+1", "官方写的是 +{n}，中间没有空格");
        g.destroy();
    }

    function test_groupMaxCountsInvisibleTagsToo() {
        // 官方 slice 是按下标的，display:none 的标签照样占一个名额
        const g = makeLaid(groupQml('maxTagCount: 2', '{ color: "grey", children: "一", visible: false },'
            + ' { color: "grey", children: "二" }, { color: "grey", children: "三" },'
            + ' { color: "grey", children: "四" }'));
        const items = tagsIn(g, "tagGroupItem");
        compare(items.length, 2);
        compare(items[0].visible, false, "第一条是被传进来的 visible 关掉的");
        compare(one(g, "tagGroupPlusN").text, "+2");
        g.destroy();
    }

    function test_groupZeroMaxShowsOnlyPlusN() {
        const g = makeLaid(groupQml('maxTagCount: 0; size: "large"', fourTags));
        compare(tagsIn(g, "tagGroupItem").length, 0);
        compare(one(g, "tagGroupPlusN").visible, true, "0 是 falsy，但截断照跑");
        compare(one(g, "tagGroupPlusN").text, "+4");
        g.destroy();
    }

    function test_groupMaxLargerThanList() {
        const g = makeLaid(groupQml('maxTagCount: 9', fourTags));
        compare(tagsIn(g, "tagGroupItem").length, 4);
        compare(one(g, "tagGroupPlusN").visible, false, "n = 4 - 9 是负数，不加 +N");
        g.destroy();
    }

    function test_groupRestCountOverridesArithmetic() {
        const g = makeLaid(groupQml('maxTagCount: 3; restCount: 7', fourTags));
        compare(one(g, "tagGroupPlusN").text, "+7", "官方 restCount ? restCount : 长度差");
        const zero = makeLaid(groupQml('maxTagCount: 3; restCount: 0', fourTags));
        compare(one(zero, "tagGroupPlusN").text, "+1", "restCount 为 0 是 falsy，回到算式");
        g.destroy(); zero.destroy();
    }

    function test_groupInjectsSizeAndAvatarShape() {
        const g = makeLaid(groupQml('maxTagCount: 4; size: "large"; avatarShape: "circle"',
            '{ color: "grey", children: "一" }, { color: "grey", children: "二", size: "small" },'
            + ' { color: "grey", children: "三", avatarSrc: "file:///nope.png" },'
            + ' { color: "grey", children: "四", avatarSrc: "file:///nope.png", avatarShape: "square" }'));
        const items = tagsIn(g, "tagGroupItem");
        compare(items.length, 4);
        compare(items[0].size, "large", "!newTag.size 才换成 group 的");
        compare(items[1].size, "small", "自己写了就听自己的");
        compare(items[2].avatarShape, "circle", "avatarShape 同款注入");
        compare(items[2].avatarSide, 20, "注入的是 circle + large 档 = 20（方角才是 24）");
        compare(items[3].avatarShape, "square", "自带 avatarShape 时不吃组的（!newTag.avatarShape 那一支）");
        compare(items[3].avatarSide, 24, "方角 large 的头与标签等高");
        g.destroy();
    }

    function test_groupPlusNStyle() {
        const g = makeLaid(groupQml('maxTagCount: 1; size: "small"', fourTags));
        const n = one(g, "tagGroupPlusN");
        compare(n.color, "grey");
        compare(n.closable, false);
        compare(n.size, "small", "+N 吃 group 的 size");
        compare(surf(n).color.toString(), "#00000000", "style backgroundColor transparent");
        compare(surf(n).border.width, 0, "grey-light 本来就没描边");
        compare(label(n).color.toString(), "#2e3238", "字还是 grey-8");
        g.destroy();
        // 反方向再来一次：+N 自己没有写死档位，large 组里它得跟着变高
        const lg = makeLaid(groupQml('maxTagCount: 1; size: "large"', fourTags));
        const big = one(lg, "tagGroupPlusN");
        compare(big.size, "large");
        compare(big.implicitHeight, 24, "$height-tag_large");
        lg.destroy();
    }

    function test_groupTagCloseForwardsTagKey() {
        const g = makeLaid(groupQml('maxTagCount: 3',
            '{ tagKey: "1", color: "light-blue", children: "抖音", closable: true },'
            + ' { tagKey: "3", color: "cyan", children: "剪映", closable: true },'
            + ' { tagKey: "2", color: "violet", children: "醒图", closable: true }'));
        const spy = spill(g, ["tagClosed"]);
        const items = tagsIn(g, "tagGroupItem");
        items[1].requestClose();
        compare(spy.tagClosed.count, 1, "onTagClose 要收到 delegate 的关闭");
        compare(spy.tagClosed.signalArguments[0][2], "3", "带的是这一条自己的 tagKey");
        compare(spy.tagClosed.signalArguments[0][0], "剪映");
        g.destroy();
    }

    function test_groupDerivesTagKeyFromChildren() {
        const g = makeLaid(groupQml('maxTagCount: 1',
            '{ color: "grey", children: "火山" }, { color: "grey", children: "醒图" }'));
        const items = tagsIn(g, "tagGroupItem");
        compare(items[0].tagKey, "火山", "字符串 children 直接当 tagKey");
        const num = makeLaid(groupQml('maxTagCount: 1', '{ color: "grey", text: "抖音" },'
            + ' { color: "grey", children: "火山" }'));
        compare(tagsIn(num, "tagGroupItem")[0].tagKey, "抖音", "text 也认");
        g.destroy(); num.destroy();
    }

    function test_groupCustomModeSkipsInjection() {
        const g = makeLaid('TagGroup { width: 350; size: "large"; mode: "custom"; tagList: ['
            + '{ color: "grey", children: "一" }] }');
        const item = tagsIn(g, "tagGroupItem")[0];
        compare(item.size, "", "custom 不注入 group 的 size");
        compare(item.implicitHeight, 20, "空档落回 Tag 自己的默认（default 也是 20）");
        g.destroy();
    }

    function test_groupFlowSpacingAndPinnedHeight() {
        const g = makeLaid(groupQml('maxTagCount: 3; size: "large"', fourTags));
        const items = tagsIn(g, "tagGroupItem");
        for (let i = 1; i < items.length; ++i) {
            const prev = items[i - 1];
            const a = prev.mapToItem(g, 0, 0).x + prev.width;
            const b = items[i].mapToItem(g, 0, 0).x;
            fuzzyCompare(b - a, 8, 0.01, ".semi-tag-group .semi-tag { margin-right: 8 }");
        }
        compare(g.implicitHeight, 26, "-group-max.-group-large 钉到 24 + 2");
        const small = makeLaid(groupQml('maxTagCount: 3', fourTags));
        compare(small.implicitHeight, 22, "非 large 钉到 20 + 2");
        const all = makeLaid(groupQml('', fourTags));
        compare(all.implicitHeight, 20, "不截断时按排出来的高（20 的标签一行）");
        g.destroy(); small.destroy(); all.destroy();
    }

    function test_groupShowPopoverOnHover() {
        const g = makeLaid(groupQml('maxTagCount: 2; size: "large"; showPopover: true', fourTags));
        const n = one(g, "tagGroupPlusN");
        // Popup 不是 Item，递归 children 摸不到，只能按 QObject 找
        const pop = testCase.findChild(g, "tagGroupPopover");
        verify(pop !== null, "要能找到 +N 的气泡");
        compare(pop.visible, false, "没悬浮不开");
        mouseMove(g, n.mapToItem(g, 0, 0).x + 8, n.height / 2);
        wait(120);
        compare(pop.visible, true, "hover 到 +N 才弹（官方 trigger=hover）");
        const restFlow = testCase.findChild(pop, "tagGroupRestFlow");
        const rest = tagsIn(restFlow, "tagGroupRestItem");
        compare(rest.length, 2, "popover 里是 slice(maxTagCount) 那两条");
        compare(rest[0].text, "剪映");
        compare(rest[1].text, "醒图");
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
        // hover 档收起要过 mouseLeaveDelay(50ms) + 退场动画(100ms) 两段，wait(120) 会抢跑
        tryVerify(function () { return pop.visible === false; }, 1500, "移出就收");
        g.destroy();
    }

    function test_groupPopoverPlacementFromProps() {
        const g = makeLaid(groupQml('maxTagCount: 2; showPopover: true', fourTags));
        compare(g.popoverProps, null);
        compare(g.placementOf(), Enums.Top, "官方内置 position 就是 top");
        g.destroy();
        const bottom = makeLaid('TagGroup { width: 350; maxTagCount: 2; showPopover: true;'
            + ' popoverProps: ({ position: "bottom" }); tagList: [' + fourTags + '] }');
        compare(bottom.placementOf(), Enums.Bottom, "popoverProps 展开在最后，用户覆盖内置");
        bottom.destroy();
    }

    function test_groupPlusNMouseEntered() {
        const g = makeLaid(groupQml('maxTagCount: 1; showPopover: false', fourTags));
        const spy = spill(g, ["plusNMouseEntered"]);
        const n = one(g, "tagGroupPlusN");
        mouseMove(g, n.mapToItem(g, 0, 0).x + 8, n.height / 2);
        wait(80);
        compare(spy.plusNMouseEntered.count, 1, "官方 onPlusNMouseEnter");
        // 回调不受 showPopover 影响，但气泡受
        const pop = testCase.findChild(g, "tagGroupPopover");
        compare(pop.visible, false, "showPopover=false 时悬浮也不开气泡");
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
        wait(40);
        g.destroy();
    }

    function test_groupAvatarTagsUseWhiteAndCircle() {
        const g = makeLaid('TagGroup { width: 350; maxTagCount: 2; size: "large";'
            + ' avatarShape: "circle"; tagList: ['
            + '{ color: "white", children: "Douyin", avatarSrc: "file:///nope.png" },'
            + '{ color: "white", children: "Hotsoon", avatarSrc: "file:///nope.png" },'
            + '{ color: "white", children: "Capcut", avatarSrc: "file:///nope.png" }] }');
        const items = tagsIn(g, "tagGroupItem");
        compare(items.length, 2);
        compare(surf(items[0]).color.toString(), "#ffffff", "头像档压过 white 档的描边色");
        compare(surf(items[0]).border.color.toString(), "#141c1f23");
        compare(items[0].avatarSide, 20);
        compare(surf(items[0]).topLeftRadius, 13);
        g.destroy();
    }

    // ---------------- SplitTagGroup ----------------

    function splitRow(g) {
        return one(g, "splitTagRow");
    }

    function test_splitRolesOnThreeChildren() {
        const g = makeLaid('SplitTagGroup { Tag { objectName: "a"; text: "标签一" }'
            + ' Tag { objectName: "b"; text: "标签二" } Tag { objectName: "c"; text: "标签三" } }');
        const a = one(g, "a");
        const b = one(g, "b");
        const c = one(g, "c");
        compare(a.splitChild, true);
        compare([a.splitFirst, a.splitLast], [true, false]);
        compare([b.splitFirst, b.splitLast], [false, false]);
        compare([c.splitFirst, c.splitLast], [false, true]);
        // 首尾只留外侧圆角，中间全直角
        compare(surf(a).topLeftRadius, 3);
        compare(surf(a).topRightRadius, 0);
        compare(surf(b).topLeftRadius, 0);
        compare(surf(b).topRightRadius, 0);
        compare(surf(c).topLeftRadius, 0);
        compare(surf(c).topRightRadius, 3);
        g.destroy();
    }

    function test_splitLateChildGetsRoles() {
        // 角色只挂在 Row 的 childrenChanged 上：建好之后再塞一枚进来也得重排
        const g = makeLaid('SplitTagGroup { Tag { objectName: "a"; text: "标签一" }'
            + ' Tag { objectName: "b"; text: "标签二" } }');
        const a = one(g, "a");
        const b = one(g, "b");
        compare([a.splitFirst, a.splitLast], [true, false], "先头尾各一枚");
        compare([b.splitFirst, b.splitLast], [false, true]);
        const late = Qt.createQmlObject('import QtQuick; import Semi;'
            + 'Tag { objectName: "c"; text: "标签三" }', splitRow(g), "late");
        wait(40);
        compare(late.splitChild, true, "新来的要被认成组合成员");
        compare([a.splitFirst, a.splitLast], [true, false]);
        compare([b.splitFirst, b.splitLast], [false, false], "原来那枚尾退成中间");
        compare([late.splitFirst, late.splitLast], [false, true]);
        compare(surf(late).topRightRadius, 3, "尾枚的外侧圆角回来了");
        compare(surf(b).topRightRadius, 0);
        fuzzyCompare(b.x + b.width + 1, late.x, 0.01, "缝隙仍是 1px");
        g.destroy();
    }

    function test_splitSingleChildGetsBothRoles() {
        const g = makeLaid('SplitTagGroup { Tag { objectName: "solo"; text: "只有一枚" } }');
        const solo = one(g, "solo");
        compare(solo.splitFirst, true);
        compare(solo.splitLast, true);
        compare(surf(solo).topLeftRadius, 3);
        compare(surf(solo).topRightRadius, 3);
        g.destroy();
    }

    function test_splitCircleEndsUseFullRadius() {
        const g = makeLaid('SplitTagGroup { Tag { objectName: "a"; text: "组合"; shape: "circle" }'
            + ' Tag { objectName: "b"; text: "标签"; shape: "circle" } }');
        compare(surf(one(g, "a")).topLeftRadius, 10, "-first 在 circle 下取 radius-tag-circle");
        compare(surf(one(g, "a")).topRightRadius, 0);
        compare(surf(one(g, "b")).topLeftRadius, 0);
        compare(surf(one(g, "b")).topRightRadius, 10);
        g.destroy();
    }

    function test_splitSeamIsOnePixelAndGroupSize() {
        const g = makeLaid('SplitTagGroup { Tag { objectName: "a"; text: "标签一" }'
            + ' Tag { objectName: "b"; text: "标签二" } }');
        const a = one(g, "a");
        const b = one(g, "b");
        compare(b.x - (a.x + a.width), 1, ".semi-tag { margin-right: 1px }");
        compare(g.implicitWidth, a.width + 1 + b.width);
        compare(g.implicitHeight, a.height, "行高就是标签高");
        compare(splitRow(g).spacing, 1);
        g.destroy();
    }

    function test_splitOutsideColorsStillApply() {
        // 组合只动圆角与缝隙，底色/描边仍由 color + type 决定
        const g = makeLaid('SplitTagGroup { Tag { objectName: "a"; text: "镂空"; color: "green"; type: "ghost" }'
            + ' Tag { objectName: "b"; text: "样式"; color: "lime"; type: "ghost" } }');
        compare(surf(one(g, "a")).border.color.toString(), "#5ac262", "green-4");
        compare(surf(one(g, "a")).border.width, 1);
        compare(surf(one(g, "b")).border.color.toString(), "#a7da2c", "lime-4");
        g.destroy();
    }

    function test_splitTagOutsideGroupKeepsRadius() {
        const t = make('Tag { text: "独立" }');
        compare(t.splitChild, false);
        compare(surf(t).topLeftRadius, 3);
        compare(surf(t).topRightRadius, 3);
        t.destroy();
    }

    // ---------------- 无障碍与外部集成 ----------------

    function test_ariaNameFallsBackToText() {
        const plain = make('Tag { text: "标签一" }');
        const marked = make('Tag { text: "标签一"; ariaLabel: "自定义说明" }');
        compare(plain.Accessible.name, "标签一");
        compare(marked.Accessible.name, "自定义说明");
        plain.destroy(); marked.destroy();
    }

    function test_accessibleRoleFollowsClosable() {
        // 官方 index.tsx:171 是 `role: clickable ? "button" : undefined`，
        // clickable 的一支就是 closable（+ onTagClick）
        const plain = make('Tag { text: "x" }');
        const closable = make('Tag { text: "x"; closable: true }');
        compare(plain.Accessible.role, Accessible.StaticText);
        compare(closable.Accessible.role, Accessible.Button);
        plain.destroy(); closable.destroy();
    }

    function tagWithText(root, text) {
        // Tag 的特征：有 readonly 的 tagHeight 与 text（findChild 摸不到 Repeater 代理）
        const kids = root.children;
        for (let i = 0; i < kids.length; ++i) {
            const c = kids[i];
            // qmllint disable missing-property
            if (c.tagHeight !== undefined && c.text === text)
                return c;
            const inner = tagWithText(c, text);
            // qmllint enable missing-property
            if (inner !== null)
                return inner;
        }
        return null;
    }

    function test_selectChipsStillUseWhiteSet() {
        // 官方 select/index.tsx:1095：多选里的选中项就是 color white 的标签
        const sel = makeLaid('Select { width: 300; multiple: true; defaultValues: ["抖音"];'
            + ' options: [{ label: "抖音", value: "抖音" }] }');
        const chip = tagWithText(sel, "抖音");
        verify(chip !== null, "选择器里要真找得到那枚标签");
        compare(chip.color, "white");
        compare(chip.implicitHeight, 20);
        compare(chip.closable, true);
        compare(surf(chip).color.toString(), "#ffffff");
        compare(surf(chip).border.color.toString(), "#b3c6cacd");
        sel.destroy();
    }
}
