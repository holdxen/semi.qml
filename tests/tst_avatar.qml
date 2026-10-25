import QtQuick
import QtTest
import Semi

// Avatar / AvatarGroup。规格照 packages/semi-ui/avatar/{index.tsx,interface.ts,avatarGroup.tsx}
// + packages/semi-foundation/avatar/{foundation.ts,constants.ts,avatar.scss,variables.scss,animation.scss}，
// 数值逐条对编译后的 packages/semi-ui/dist/css/semi.css（`.semi-avatar*`，2330-2974 行）；
// 演示与 API 表照 content/show/avatar/index.md 的 11 节。
//
// 端口口径（都在 src/Avatar.qml 文件头）：
//   · 官方 `onError` 返回 false 才留住破图 ⇒ QML 里 `on`+大写是保留前缀，属性改名 `error`。
//   · `clickable = onClick !== noop` 那一支 QML 探测不到（signal 没有连接查询，同 Tag），
//     所以 alt 不加 "clickable Avatar: " 前缀、Tab 一律按 enabled 给。
//   · `srcSet` / `imgAttr` 收了不产出差异；`.semi-avatar-image` 那条死类名（tsx 挂的是 `-img`）不复现，
//     因为「有图时本来就不挂色板类名」已经把底色清成透明了。
//   · 色板取 `--semi-<color>-3`；COLOR 表里的 'white' 在 scss 的 $colors 里没有 ⇒ 命不中任何规则，
//     底色透明 + 字退回继承值（钉一条，防「white 也当一档」）。
//   · 圆切只能 cocoa 验（offscreen 整层不画 MultiEffect 内容，坑 71），所以那条用例先探一次底色、
//     画不出来就显式 skip，不写「读回来没变化 ⇒ 通过」的空转断言。
TestCase {
    id: testCase

    name: "Avatar"
    when: windowShown
    width: 900
    height: 700

    readonly property string quads: "qrc:/tests/crop_quads.png"   // 200×100 四色块

    Rectangle {
        objectName: "avatarBackdrop"
        anchors.fill: parent
        color: "#ff00ff"
    }

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
    }

    function cleanup() {
        Theme.reset();
        Theme.mode = Theme.Light;
        for (let i = testCase.children.length - 1; i >= 0; --i) {
            const it = testCase.children[i];
            if (it.objectName !== "avatarBackdrop")
                it.destroy();
        }
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "avatar");
    }

    function part(owner, name) {
        const node = testCase.findChild(owner, name);
        verify(node !== null && node !== undefined, "找不到 " + name);
        return node;
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 0.01,
               (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    function camel(name) {
        const parts = String(name).split("-");
        let out = parts[0];
        for (let i = 1; i < parts.length; ++i)
            out += parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        return out;
    }

    function label(a) {
        return part(a, "avatarLabel");
    }

    function surface(a) {
        return part(a, "avatarSurface");
    }

    function spy(target, signalName, tag) {
        const s = Qt.createQmlObject("import QtTest; SignalSpy {}", testCase, tag || "spy");
        s.target = target;
        s.signalName = signalName;
        return s;
    }

    function darkMode() {
        Theme.mode = Theme.Dark;
        verify(String(Theme.current.colorBg0) !== String(Theme.current.colorBg1),
               "浅色档 bg-0…bg-3 全同值 ⇒ 这类底色/描边断言得在深色下量");
    }

    // ---------------- 尺寸：官方七档 + 自定义数 ----------------

    function test_sevenNamedSizes() {
        const expect = { "extra-extra-small": 20, "extra-small": 24, "small": 32, "default": 40,
            "medium": 48, "large": 72, "extra-large": 128 };
        for (const key in expect) {
            const a = make('Avatar { text: "A"; size: "' + key + '" }');
            compare(a.side, expect[key], key + " 的边长（$width-avatar_*）");
            compare(a.implicitWidth, expect[key], key + " 的隐式宽跟着边长");
            compare(a.implicitHeight, expect[key], key + " 的隐式高跟着边长");
            a.destroy();
        }
    }

    function test_propDefaults() {
        const a = make("Avatar { }");
        compare(a.text, "", "children 那一支的缺省");
        compare(a.src, "", "src 没给就是空串（官方表里默认值是 -）");
        compare(a.srcSet, "");
        compare(a.alt, "");
        compare(a.gap, 3, "defaultProps.gap = 3");
        compare(a.color, "grey", "defaultProps.color = 'grey'");
        compare(String(a.surfaceColor), String(Theme.current.grey[3]), "缺省色板真的落到底色上");
        compare(a.shape, "circle", "defaultProps.shape = 'circle'");
        compare(a.size, "medium", "defaultProps.size = 'medium'");
        compare(a.hoverMask, null);
        compare(a.imgAttr, null);
        compare(a.error, null, "官方 onError 没给时不调用");
        compare(a.bottomSlot, null);
        compare(a.topSlot, null);
        compare(a.border, null);
        compare(a.contentMotion, false);
        compare(a.backgroundColor, null, "内联底色没给 ⇒ 走色板");
        compare(a.keepBroken, false, "isImgExist 初值 true 的反面");
        compare(a.groupSize, undefined, "不在组里就没有下发");
        compare(a.groupShape, "");
        compare(a.groupBorderWidth, 0, "不在组里就没有那圈 bg-1 描边");
        compare(part(a, "avatarGroupBorder").visible, false, "组描边外壳也不该画");
        compare(a.focusVisible, false);
        a.destroy();
    }

    function test_defaultSizeIsMedium() {
        const a = make("Avatar { text: \"A\" }");
        compare(a.size, "medium", "官方 defaultProps.size = 'medium'");
        compare(a.side, 48);
        a.destroy();
    }

    function test_numericSizeIsCustomSide() {
        const a = make("Avatar { text: \"A\"; size: 64 }");
        compare(a.side, 64, "不在 SIZE 七档里 ⇒ 官方走 customStyle 的宽高");
        compare(a.namedSize, false);
        const square = make('Avatar { text: "A"; size: 64; shape: "square" }');
        compare(square.radius, 0, "自定义尺寸没有尺寸类名 ⇒ 那条 border-radius 命不中");
        a.destroy(); square.destroy();
    }

    function test_unknownSizeFallsBackToMedium() {
        const a = make('Avatar { text: "A"; size: "huge" }');
        compare(a.side, 48, "既不是档位又不是数字：官方那条内联宽高失效 ⇒ 退成缺省档");
        const zero = make('Avatar { text: "A"; size: 0 }');
        compare(zero.side, 48, "0 边长画不出东西 ⇒ 同样退缺省档");
        compare(zero.customSide, null, "认不出正数就记成 null（`customSide` 是 var 不是 int：int 会把 Infinity 截成 0，那道闸门就读不出差别了）");
        const inf = make('Avatar { text: "A"; size: Infinity }');
        compare(inf.side, 48, "Infinity 量不出盒子 ⇒ 也退缺省档");
        const negative = make('Avatar { text: "A"; size: -64 }');
        compare(negative.side, 48, "负数不算自定义尺寸");
        a.destroy(); zero.destroy(); inf.destroy(); negative.destroy();
    }

    function test_squareRadiusPerSize() {
        const expect = { "extra-extra-small": 3, "extra-small": 3, "small": 3, "default": 3,
            "medium": 3, "large": 6, "extra-large": 12 };
        for (const key in expect) {
            const a = make('Avatar { text: "A"; size: "' + key + '"; shape: "square" }');
            compare(a.radius, expect[key], key + " 方角的 border-radius");
            compare(surface(a).radius, expect[key], key + " 方角画在外壳上");
            a.destroy();
        }
    }

    function test_circleRadiusIsHalfSide() {
        const a = make('Avatar { text: "A"; size: "large" }');
        compare(a.shape, "circle", "官方 defaultProps.shape = 'circle'");
        compare(a.radius, 36, "border-radius: 9999px 落在 72 的盒子上就是半边");
        const forced = make("Avatar { size: \"large\"; width: 100; height: 100 }");
        compare(forced.radius, 50, "使用处钉了宽高 ⇒ 半径按实际盒子算");
        a.destroy(); forced.destroy();
    }

    // ---------------- 色板 ----------------

    function test_paletteUsesRampThree() {
        // 官方 mixin：background-color: rgba(var(--semi-<color>-3),1); color: white
        const sixteen = ["grey", "red", "pink", "purple", "violet", "indigo", "blue", "light-blue",
            "cyan", "teal", "green", "light-green", "lime", "yellow", "amber", "orange"];
        for (let i = 0; i < sixteen.length; ++i) {
            const name = sixteen[i];
            const a = make('Avatar { text: "A"; color: "' + name + '" }');
            const ramp = Theme.current[camel(name)];
            verify(ramp !== undefined && ramp !== null, camel(name) + " 这个色板得在 Theme 上");
            compare(String(a.surfaceColor), String(ramp[3]), name + " 的底色取 --semi-" + name + "-3");
            compare(String(a.labelColor), String(Theme.current.colorWhite), name + " 档的文字恒白");
            a.destroy();
        }
    }

    function test_paletteLiterals() {
        const g = make('Avatar { text: "A"; color: "grey" }');
        compare(String(g.surfaceColor), "#a7abb0", "缺省 grey-3 的字面值");
        const r = make('Avatar { text: "A"; color: "red" }');
        compare(String(r.surfaceColor), "#fb9078", "red-3 的字面值");
        verify(String(Theme.current.grey[3]) !== String(Theme.current.grey[4]),
               "grey-3 与 grey-4 同值的话上面两条就是空转");
        g.destroy(); r.destroy();
    }

    function test_whiteColorMatchesNoRule() {
        const a = make('Avatar { text: "A"; color: "white" }');
        // COLOR 表里有 white，但 avatar.scss 的 $colors 列表里没有 ⇒ 两条属性都不落
        compare(a.hasRamp, false, "white 在 Theme 上是个 QColor，不是色阶表");
        compare(String(a.surfaceColor), "#00000000", "命不中规则 ⇒ 底色透明");
        compare(String(a.labelColor), String(Theme.current.colorText0), "文字退回继承值");
        a.destroy();
    }

    function test_unknownColorNameIsTransparent() {
        const a = make('Avatar { text: "A"; color: "magenta" }');
        compare(a.hasRamp, false);
        compare(String(a.surfaceColor), "#00000000");
        a.destroy();
    }

    function test_emptyColorNameHasNoClass() {
        const a = make('Avatar { text: "A"; color: "" }');
        compare(a.hasColorClass, false, "官方是 `color && !isImg`，空串算没给");
        compare(String(a.surfaceColor), "#00000000");
        a.destroy();
    }

    function test_backgroundColorOverridesPalette() {
        const a = make('Avatar { text: "A"; backgroundColor: "#00ff00" }');
        compare(String(a.surfaceColor), "#00ff00", "官方 style 内联压过一切类名");
        const withImage = make("Avatar { src: '" + quads + "'; backgroundColor: '#00ff00' }");
        compare(String(withImage.surfaceColor), "#00ff00", "有图时内联底色照样压得住");
        a.destroy(); withImage.destroy();
    }

    // ---------------- 图片档 ----------------

    function test_imageDropsPaletteClass() {
        const a = make('Avatar { text: "A"; src: "' + quads + '" }');
        compare(a.isImg, true, "官方 isImg = src && isImgExist，而 isImgExist 初值 true");
        compare(a.hasColorClass, false, "有图那一支不挂色板类名");
        compare(String(a.surfaceColor), "#00000000", "于是底色透明（.semi-avatar-image 那条死规则的本意）");
        compare(label(a).visible, false, "有图就不画文字");
        a.destroy();
    }

    function test_srcEmptyMeansNoImage() {
        const a = make('Avatar { text: "A"; src: "" }');
        compare(a.isImg, false, "官方 `src &&` 的真值判断：空串算没给");
        compare(a.hasColorClass, true);
        compare(label(a).visible, true);
        a.destroy();
    }

    function test_loadErrorFallsBackToLabel() {
        const a = make('Avatar { text: "备"; src: "qrc:/definitely-not-there.png" }');
        tryVerify(function () { return part(a, "avatarPhoto").status === Image.Error; }, 2000);
        compare(a.isImg, false, "foundation.ts handleImgLoadError ⇒ notifyImgState(false)");
        compare(label(a).visible, true, "回落成文字那一支");
        compare(a.hasColorClass, true, "色板类名跟着回来");
        a.destroy();
    }

    function test_errorCallbackReturningFalseKeepsImage() {
        const a = make('Avatar { text: "备"; src: "qrc:/definitely-not-there.png";'
                       + " error: function () { return false } }");
        tryVerify(function () { return part(a, "avatarPhoto").status === Image.Error; }, 2000);
        compare(a.imgKept, true, "onError() 严格返回 false 才留住（foundation.ts:24-30）");
        compare(a.isImg, true);
        compare(label(a).visible, false);
        const other = make('Avatar { text: "备"; src: "qrc:/definitely-not-there.png";'
                           + " error: function () { return 0 } }");
        tryVerify(function () { return part(other, "avatarPhoto").status === Image.Error; }, 2000);
        compare(other.imgKept, false, "只有严格 false 算「留住」，0 / undefined 都放行");
        a.destroy(); other.destroy();
    }

    function test_srcSetAndImgAttrAreInert() {
        const a = make('Avatar { text: "A"; srcSet: "x 2x"; imgAttr: ({ title: "t" }) }');
        compare(a.srcSet, "x 2x", "两条官方 prop 收得到");
        compare(a.side, 48, "但 Qt 的 Image 没有 srcset 协商与属性袋 ⇒ 不产出差异");
        compare(a.implicitWidth, 48);
        a.destroy();
    }

    function test_altBecomesAccessibleName() {
        const plain = make('Avatar { text: "半" }');
        compare(plain.Accessible.name, "半", "官方 tempAlt = alt ?? children");
        const named = make('Avatar { text: "半"; alt: "头像：半" }');
        compare(named.Accessible.name, "头像：半");
        const imageOne = make('Avatar { src: "' + quads + '"; alt: "猫" }');
        compare(imageOne.Accessible.name, "猫");
        plain.destroy(); named.destroy(); imageOne.destroy();
    }

    // ---------------- 文字与自适应缩放 ----------------

    function test_labelShowsWholeString() {
        const a = make('Avatar { text: "字节" }');
        compare(label(a).text, "字节", "官方整串显示，不取首字、不大写化");
        compare(label(a).font.weight, Font.DemiBold, "$font-weight-bold = 600");
        a.destroy();
    }

    function test_labelFontPerSize() {
        const expect = { "extra-extra-small": 10, "extra-small": 10, "small": 12, "default": 18,
            "medium": 20, "large": 32, "extra-large": 64 };
        for (const key in expect) {
            const a = make('Avatar { text: "A"; size: "' + key + '" }');
            compare(label(a).font.pixelSize, expect[key], key + " 档的 label 字号");
            a.destroy();
        }
        const custom = make("Avatar { text: \"A\"; size: 96 }");
        compare(label(custom).font.pixelSize, 14, "自定义尺寸没有尺寸类名 ⇒ 兜 .semi-avatar-label 的 14");
        custom.destroy();
    }

    function test_emptyAvatarDrawsNoLabel() {
        const a = make("Avatar { }");
        compare(label(a).visible, false, "官方没有 children 就什么都不画（旧端口那个 '?' 是自造的）");
        compare(a.side, 48, "空头像还是按档位占尺寸");
        compare(a.contentScale, 1, "量不到文字宽度 ⇒ changeScale 的闸门不放行");
        a.destroy();
    }

    function test_contentScaleKeepsShortText() {
        const a = make('Avatar { text: "A"; size: "extra-large" }');
        verify(label(a).implicitWidth > 0, "先确认量得到文字宽度，否则这条是空转");
        compare(a.availableTextWidth, 122, "可用宽 = 边长 − 2*gap");
        compare(a.contentScale, 1, "放得下就是 1");
        a.destroy();
    }

    function test_contentScaleShrinksLongText() {
        const a = make('Avatar { text: "很长的一个名字试试看"; size: "small" }');
        const natural = label(a).implicitWidth;
        verify(natural > 26, "先确认这串在 32 的盒子里放不下，实得 " + natural);
        near(a.contentScale, (32 - 3 * 2) / natural, "官方 (nodeWidth - gap*2) / stringWidth");
        verify(a.contentScale < 1, "放不下就该收紧");
        near(natural * a.contentScale, 26, "收紧后正好贴进可用宽");
        compare(label(a).scale, a.contentScale, "缩放任那一项真的吃到这个值，不是只算不画");
        a.destroy();
    }

    function test_gapFeedsScale() {
        const tight = make('Avatar { text: "很长的一个名字试试看"; size: "small"; gap: 9 }');
        const loose = make('Avatar { text: "很长的一个名字试试看"; size: "small"; gap: 1 }');
        near(tight.contentScale, (32 - 18) / label(tight).implicitWidth, "gap 越大收得越狠");
        near(loose.contentScale, (32 - 2) / label(loose).implicitWidth, "gap 小就几乎不收");
        verify(tight.contentScale < loose.contentScale, "两条必须分得开，否则 gap 没参与运算");
        tight.destroy(); loose.destroy();
    }

    function test_scaleGuardWhenGapTooWide() {
        const a = make('Avatar { text: "很长的一个名字试试看"; size: "small"; gap: 16 }');
        compare(a.availableTextWidth, 0, "gap*2 已经不小于边长");
        compare(a.contentScale, 1, "官方那条 gap*2 < nodeWidth 的闸门不放行 ⇒ 保持 1");
        a.destroy();
    }

    // ---------------- 形状与外壳 ----------------

    function test_shapeStringOnly() {
        const a = make('Avatar { text: "A"; shape: "square"; size: "large" }');
        compare(a.radius, 6, "$radius-avatar_large");
        const bogus = make('Avatar { text: "A"; shape: "hexagon"; size: "large" }');
        compare(bogus.radius, 6, "-hexagon 命不中任何规则 ⇒ 只剩尺寸类名那条 6");
        a.destroy(); bogus.destroy();
    }

    function test_photoMaskMatchesShellShape() {
        const square = make('Avatar { text: "A"; src: "' + quads + '"; shape: "square"; size: "large" }');
        const sqMask = part(square, "avatarPhotoMask");
        compare(sqMask.radius, 6, "遮罩形状跟外壳，不然图片角上会多出圆");
        compare(sqMask.layer.enabled, true,
                "遮罩项必须能直接当纹理源，少这一层整块图片画不出（坑 9，cocoa 像素复核过的同一套写法）");
        const circle = make('Avatar { text: "A"; src: "' + quads + '"; size: "small" }');
        compare(part(circle, "avatarPhotoMask").radius, 16);
        const effect = part(circle, "avatarPhotoEffect");
        compare(effect.maskEnabled, true, "圆切靠的就是这一道遮罩");
        compare(effect.maskSource, part(circle, "avatarPhotoMask"), "遮罩接的是那颗形状件");
        compare(effect.visible, true, "有图 ⇒ 效果图层开着");
        compare(part(circle, "avatarPhoto").fillMode, Image.PreserveAspectCrop, "官方 img 是 object-fit: cover");
        compare(part(circle, "avatarPhoto").sourceSize.width, 64, "取图按两倍边长预加载，缩出来才不糊");
        const none = make("Avatar { text: \"A\" }");
        compare(part(none, "avatarPhotoEffect").visible, false, "没图就不开这一层");
        square.destroy(); circle.destroy(); none.destroy();
    }

    function test_photoIsClippedToCircle() {
        const a = make("Avatar { x: 40; y: 40; width: 120; height: 120; src: \"" + quads + "\" }");
        wait(400);
        const shot = testCase.grabImage(testCase);
        verify(shot !== undefined, "抓图失败");
        const dpr = shot.width / testCase.width;
        function at(lx, ly) {
            const p = shot.pixel(Math.round(lx * dpr), Math.round(ly * dpr));
            return p === undefined || p === null ? "null" : p.toString();
        }
        // offscreen 整层不画 MultiEffect 的内容（坑 71）：先探圆心，画不出来就显式跳过
        if (at(100, 100) === "#ff00ff")
            skip("这一档平台不画 MultiEffect 的内容，圆切只能在 cocoa 下量（见 PROGRESS.md 坑 71 / 坑 117）");
        compare(at(90, 90), "#ff0000", "圆内左上那块是夹具的红（盒内坐标 50,50 → 图内 91,41）");
        compare(at(110, 90), "#00ff00", "圆内右上那块是夹具的绿 ⇒ 图确实画出来了，不是只裁了个形状");
        compare(at(44, 44), "#ff00ff", "方框左上角在圆外 ⇒ 得是底色");
        compare(at(156, 44), "#ff00ff", "右上角离圆心 79 > 60 ⇒ 也得是底色");
        compare(at(44, 156), "#ff00ff", "左下角同理");
        compare(at(156, 156), "#ff00ff", "右下角同理");
        a.destroy();
    }

    // ---------------- 事件与焦点 ----------------

    function test_clickedSignalFires() {
        const a = make("Avatar { x: 20; y: 20; text: \"A\" }");
        wait(60);
        const s = spy(a, "clicked", "clickSpy");
        mouseClick(a, 20, 20);
        wait(60);
        compare(s.count, 1, "官方 onClick 挂在 wrapper 上 ⇒ 落在头像盒子里就算");
        a.destroy(); s.destroy();
    }

    function test_enterAndLeaveSignals() {
        const a = make("Avatar { x: 20; y: 20; text: \"A\"; bottomSlot: ({shape: \"circle\", text: \"1\"}) }");
        wait(100);
        const inSpy = spy(a, "mouseEntered", "inSpy");
        const outSpy = spy(a, "mouseLeft", "outSpy");
        mouseMove(a, 20, 20);
        wait(60);
        compare(inSpy.count, 1, "onMouseEnter → mouseEntered");
        compare(outSpy.count, 0);
        const box = part(a, "avatarBottomSlotBox");
        // 槽位的下沿在头像盒子外面（avatar 48 高，槽中心压在 44.5，底沿到 52.5）
        mouseMove(box, box.width / 2, box.height - 1);
        wait(60);
        verify(box.y + box.height - 1 > 48, "这个点得真的落在头像外面，否则测不到槽位那半边判据");
        compare(inSpy.count, 1, "槽位骑在盒子外面，但 DOM 里它冒泡到同一个 wrapper ⇒ 不该重发");
        compare(outSpy.count, 0, "两侧合成一个判据：只认本体那一半的话，移到头像外面的槽位上就会误判成离开");
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
        wait(60);
        compare(outSpy.count, 1, "onMouseLeave → mouseLeft（left 撞 QQuickItem 的 FINAL 成员，改名）");
        a.destroy(); inSpy.destroy(); outSpy.destroy();
    }

    function test_cursorIsPointerOnHover() {
        const a = make("Avatar { x: 20; y: 20; text: \"A\" }");
        wait(60);
        compare(part(a, "avatarHover").cursorShape, Qt.PointingHandCursor,
                ".semi-avatar:hover { cursor: pointer } 对所有头像生效，不只 clickable 那一支");
        a.destroy();
    }

    function test_focusRingFollowsActiveFocus() {
        const a = make("Avatar { x: 20; y: 20; text: \"A\" }");
        wait(60);
        compare(part(a, "avatarFocusRing").visible, false, "没聚焦不画轮廓");
        a.forceActiveFocus();
        wait(60);
        compare(a.focusVisible, true);
        const ring = part(a, "avatarFocusRing");
        compare(ring.visible, true, "官方 :focus-visible 那一档探测不到 ⇒ 拿 activeFocus 代理（端口口径）");
        compare(ring.border.width, 2, "$width-avatar-outline");
        compare(String(ring.border.color), String(Theme.current.colorPrimaryLightActive),
                "$color-avatar-outline-focus");
        compare(ring.x, -2, "outline 画在盒子外一圈");
        compare(ring.width, a.side + 4);
        a.destroy();
    }

    function test_keyboardEnterAndEscape() {
        const a = make("Avatar { x: 20; y: 20; text: \"A\" }");
        wait(60);
        const s = spy(a, "clicked", "keySpy");
        a.forceActiveFocus();
        wait(60);
        keyPress(Qt.Key_Return);
        wait(60);
        compare(s.count, 1, "handleKeyDown 的 Enter 那一支走 onClick");
        keyPress(Qt.Key_Enter);
        wait(60);
        compare(s.count, 2, "小键盘那枚 Key_Enter 也算（官方 switch 吃的是 event.key === 'Enter'，两枚都落到那个字符串）");
        keyPress(Qt.Key_Escape);
        wait(60);
        compare(a.activeFocus, false, "Escape 是 blur");
        compare(s.count, 2, "Esc 不该被当成一次点击（前面 Enter 与小键盘 Enter 各一次）");
        a.destroy(); s.destroy();
    }

    function test_tabOrderFollowsEnabled() {
        const a = make("Avatar { text: \"A\" }");
        compare(a.activeFocusOnTab, true, "官方 clickable 才有 tabIndex，QML 探测不到连接 ⇒ 按 enabled 给");
        a.enabled = false;
        compare(a.activeFocusOnTab, false);
        a.destroy();
    }

    function test_clickOnSlotStillEmitsClicked() {
        const a = make("Avatar { x: 20; y: 20; text: \"A\"; bottomSlot: ({shape: \"circle\", text: \"1\"}) }");
        wait(150);
        const box = part(a, "avatarBottomSlotBox");
        verify(box.y + box.height - 1 > 48, "先确认这个点在头像盒子外面，否则测不到冒泡那一路");
        const s = spy(a, "clicked", "slotClickSpy");
        mouseClick(box, box.width / 2, box.height - 1);
        wait(60);
        compare(s.count, 1, "官方 mouseEvent 挂在 wrapper 上 ⇒ 点骑在下沿外的那半枚槽位也算");
        mouseClick(a, 20, 20);
        wait(60);
        compare(s.count, 2, "点头像本体照旧算一次");
        a.destroy(); s.destroy();
    }

    // ---------------- hoverMask ----------------

    function test_hoverMaskOnlyShowsOnHover() {
        const a = make("Avatar { x: 20; y: 20; text: \"A\"; hoverMask: \"close\" }");
        wait(60);
        const effect = part(a, "avatarHoverEffect");
        compare(effect.visible, false, "官方 hoverContent 只在 enter 之后才有值");
        compare(effect.maskEnabled, true, "覆盖层也在 overflow:hidden 里面 ⇒ 得跟着圆切");
        compare(effect.maskSource, part(a, "avatarHoverMask"), "接的是形状件那一层");
        compare(part(a, "avatarHoverBox").layer.enabled, true, "覆盖层要能当纹理源，否则整层是空的");
        // 图标名与 Component 两条分支各自的数据通路（盒本身 visible:false ⇒ 只能读属性，读不到可见性）
        compare(part(a, "avatarHoverIcon").name, "close", "字符串那一支把图标名交给 Icon");
        compare(part(a, "avatarHoverNode").active, false, "字符串那一支不该去载入 Component");
        mouseMove(a, 20, 20);
        wait(60);
        compare(part(a, "avatarHoverIcon").name, "close", "悬浮上来还是那一枚图标");
        mouseMove(a, 20, 20);
        wait(60);
        compare(effect.visible, true, "悬浮上去才铺遮罩");
        compare(a.hovered, true);
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
        wait(60);
        compare(effect.visible, false);
        a.destroy();
    }

    function test_hoverMaskNodeBranch() {
        const a = make("Avatar { x: 20; y: 20; text: \"A\"; hoverMask: hoverNode }");
        wait(60);
        const node = part(a, "avatarHoverNode");
        compare(node.active, false, "没悬浮不实例化");
        mouseMove(a, 20, 20);
        wait(150);
        compare(node.active, true, "Component 那一支走 Loader");
        compare(node.item.objectName, "hoverNodeRect", "载入的是使用处那个节点");
        a.destroy();
    }

    function test_hoverMaskWithoutValueIsSilent() {
        const a = make("Avatar { x: 20; y: 20; text: \"A\" }");
        wait(60);
        mouseMove(a, 20, 20);
        wait(60);
        compare(part(a, "avatarHoverEffect").visible, false, "没给 hoverMask ⇒ 只发信号、不铺层");
        compare(a.hovered, true);
        a.destroy();
    }

    readonly property Component hoverNode: Component {
        Rectangle {
            objectName: "hoverNodeRect"
            width: 20
            height: 20
            color: "#00ff00"
        }
    }

    // ---------------- 顶部 slot ----------------

    function test_topSlotGates() {
        const ok = make('Avatar { text: "A"; topSlot: ({text: "VIP"}) }');
        compare(ok.showTopSlot, true, "官方：topSlot 且 size 在有样式的六档里且 shape === 'circle'");
        const tiny = make('Avatar { text: "A"; size: "extra-extra-small"; topSlot: ({text: "VIP"}) }');
        compare(tiny.showTopSlot, false, "extra-extra-small 那一档官方连字号规则都没给 ⇒ 不渲染");
        const square = make('Avatar { text: "A"; shape: "square"; topSlot: ({text: "VIP"}) }');
        compare(square.showTopSlot, false, "方角那一支官方明确挡掉");
        const none = make("Avatar { text: \"A\" }");
        compare(none.showTopSlot, false);
        verify(none.topSlotData !== null && typeof none.topSlotData === "object",
               "没给槽位时读的是那张空壳，不是 null（少这层壳每一处 topSlot.x 都要抛异常收敛）");
        compare(none.topSlotData.text, undefined);
        ok.destroy(); tiny.destroy(); square.destroy(); none.destroy();
    }

    function test_bottomSlotDataShell() {
        const none = make("Avatar { text: \"A\" }");
        verify(none.bottomSlotData !== null && typeof none.bottomSlotData === "object",
               "同上：底部槽位也走空壳");
        compare(none.bottomSlotData.shape, undefined);
        none.destroy();
    }

    function test_topSlotCapGeometry() {
        const expect = { "small": [-28, 0.4], "default": [-32, 0.7], "medium": [-30, 0.8],
            "large": [-30, 1.1], "extra-large": [-32, 1.4] };
        for (const key in expect) {
            const a = make('Avatar { text: "A"; size: "' + key + '"; topSlot: ({text: "V"}) }');
            const cap = part(a, "avatarTopSlotCap");
            const s = expect[key][1];
            near(cap.width, 44.5 * s, key + " 档帽子宽 = svg 路径外框 × scale");
            near(cap.height, 46.9 * s, key + " 档帽子高");
            near(cap.x, 25.5 - 0.25 * s - 44.5 * s / 2, key + " 档帽子的横向位置");
            near(cap.y, expect[key][0] + 26 - 1.55 * s - 46.9 * s / 2,
                 key + " 档帽子的竖向位移照 top:" + expect[key][0]);
            a.destroy();
        }
        const tiny = make('Avatar { text: "A"; size: "extra-small"; topSlot: ({text: "V"}) }');
        const cap = part(tiny, "avatarTopSlotCap");
        compare(tiny.showTopSlot, true, "extra-small 在 topSlot 的名单里");
        near(cap.width, 44.5, "官方那两条 top/scale 规则没有 extra-small ⇒ 位移 0、缩放 1");
        near(cap.height, 46.9);
        near(cap.x, 25.5 - 0.25 - 44.5 / 2, "兜底的 top 位移是 0（svg 盒子贴在圆的左上角）");
        near(cap.y, 26 - 1.55 - 46.9 / 2, "兜底的 scale 是 1");
        tiny.destroy();
    }

    function test_topSlotClipIsAvatarCircle() {
        const a = make('Avatar { text: "A"; size: "default"; topSlot: ({text: "V"}) }');
        const clip = part(a, "avatarTopSlotCapClip");
        compare(clip.radius, 20, "-top_slot-bg 自己是和头像等大的圆 + overflow:hidden");
        compare(clip.width, 40);
        compare(part(a, "avatarTopSlotEffect").maskSource, clip, "帽子要靠这颗圆裁出来");
        a.destroy();
    }

    function test_topSlotTextColorAndFont() {
        darkMode();
        const expect = { "small": 5, "default": 6, "medium": 8, "large": 14, "extra-large": 16 };
        for (const key in expect) {
            const a = make('Avatar { text: "A"; size: "' + key + '"; topSlot: ({text: "VIP"}) }');
            const t = part(a, "avatarTopSlotText");
            compare(t.font.pixelSize, expect[key], key + " 档顶部文字字号");
            compare(String(t.color), String(Theme.current.colorBg0), "$color-avatar-top_slot_text");
            compare(t.y, key === "default" ? -2 : 0, key + " 档的 margin-top");
            a.destroy();
        }
        const tiny = make('Avatar { text: "A"; size: "extra-small"; topSlot: ({text: "VIP"}) }');
        compare(part(tiny, "avatarTopSlotText").font.pixelSize, 14,
                "extra-small 没有那条字号规则 ⇒ 兜底取 .semi-avatar 继承的 14");
        tiny.destroy();
        const painted = make('Avatar { text: "A"; topSlot: ({text: "VIP", textColor: "#00ff00"}) }');
        compare(String(part(painted, "avatarTopSlotText").color), "#00ff00", "textColor 压过令牌");
        painted.destroy();
    }

    function test_topSlotGradientTakesStartColor() {
        const a = make('Avatar { text: "A"; topSlot: ({text: "V", gradientStart: "#ff0000",'
                       + ' gradientEnd: "#0000ff"}) }');
        compare(String(part(a, "avatarTopSlotCap").color), "#ff0000",
                "QML 画不了那条 SVG 渐变，取起始色代表（默认两端都是 primary）");
        const def = make('Avatar { text: "A"; topSlot: ({text: "V"}) }');
        compare(String(part(def, "avatarTopSlotCap").color), String(Theme.current.colorPrimary),
                "$color-avatar-top_slot_gradient_start 的缺省就是 primary");
        a.destroy(); def.destroy();
    }

    function test_topSlotRenderBranchGoesInFlow() {
        const a = make("Avatar { text: \"A\"; topSlot: ({render: slotNode}) }");
        wait(150);
        compare(a.topSlotCustom, true);
        compare(part(a, "avatarTopSlotBox").visible, false, "render() 给节点时官方不走那套壳");
        const loader = part(a, "avatarTopSlotRender");
        compare(loader.active, true);
        compare(part(a, "avatarFlowSlots").y, a.height,
                "render 的节点是 wrapper 的流内子项 ⇒ 排在头像下面");
        compare(loader.y, 0, "流内那一列自己贴在头像下沿上");
        compare(loader.item.objectName, "slotNodeRect", "载入的是使用处给的节点");
        verify(a.implicitHeight > a.side, "流内节点要把整枚头像的隐式高顶起来，实得 " + a.implicitHeight);
        a.destroy();
    }

    readonly property Component slotNode: Component {
        Rectangle {
            objectName: "slotNodeRect"
            width: 60
            height: 20
            color: "#00ff00"
        }
    }

    // ---------------- 底部 slot ----------------

    function test_bottomSlotGates() {
        const ok = make('Avatar { text: "A"; bottomSlot: ({shape: "circle", text: "1"}) }');
        compare(ok.showBottomSlot, true);
        const tiny = make('Avatar { text: "A"; size: "extra-extra-small"; bottomSlot: ({shape: "circle", text: "1"}) }');
        compare(tiny.showBottomSlot, false, "那一档也不在名单里");
        const squareOk = make('Avatar { text: "A"; shape: "square"; bottomSlot: ({shape: "circle", text: "1"}) }');
        compare(squareOk.showBottomSlot, true, "bottomSlot 不像 topSlot 那样要求圆角");
        const none = make("Avatar { text: \"A\" }");
        compare(none.showBottomSlot, false, "没给 bottomSlot 就不该有这一层");
        compare(part(none, "avatarBottomSlotBox").visible, false);
        ok.destroy(); tiny.destroy(); squareOk.destroy(); none.destroy();
    }

    function test_bottomSlotCircleDisc() {
        const expect = { "extra-small": 12, "small": 12, "default": 16, "medium": 18, "large": 28,
            "extra-large": 28 };
        const fonts = { "extra-small": 5, "small": 5, "default": 12, "medium": 12, "large": 12,
            "extra-large": 14 };
        for (const key in expect) {
            const a = make('Avatar { text: "A"; size: "' + key + '"; bottomSlot: ({shape: "circle", text: "9"}) }');
            const box = part(a, "avatarBottomSlotShape");
            compare(box.width, expect[key], key + " 档圆片直径");
            compare(box.height, expect[key]);
            compare(box.radius, expect[key] / 2, "border-radius: circle");
            compare(String(box.color), String(Theme.current.colorPrimary), "$color-avatar-bottom_slot_bg");
            compare(box.border.width, 0, "圆档没有描边");
            compare(part(a, "avatarBottomSlotText").font.pixelSize, fonts[key], key + " 档圆片字号");
            a.destroy();
        }
    }

    function test_bottomSlotSitsOnTheEdgeLine() {
        const a = make('Avatar { text: "A"; size: "default"; bottomSlot: ({shape: "circle", text: "9"}) }');
        wait(150);
        const box = part(a, "avatarBottomSlotBox");
        near(box.x, (40 - box.width) / 2, "水平居中（wrapper 的 align-items:center）");
        near(box.y + box.height / 2, 40 - 3.5, "bottom:3.5 + translateY(50%) ⇒ 中心压在头像下沿上 3.5px");
        verify(box.y + box.height > 40, "一半身子要露在头像外面");
        a.destroy();
    }

    function test_bottomSlotSquareBox() {
        const a = make('Avatar { text: "A"; size: "default"; bottomSlot: ({shape: "square", text: "hi"}) }');
        wait(150);
        const box = part(a, "avatarBottomSlotShape");
        const text = part(a, "avatarBottomSlotText");
        compare(box.radius, 4, "$radius-avatar-bottom_slot_square");
        compare(box.border.width, 2, "$width-avatar-bottom_slot_square_default-border");
        compare(String(box.border.color), String(Theme.current.colorBg0),
                "$color-avatar-bottom_slot_square-border");
        near(box.width, text.implicitWidth + 8 + 4, "padding 1px 4px + 两侧 2px 描边");
        near(box.height, text.implicitHeight + 2 + 4, "上下各 1px 内边距 + 描边");
        compare(text.font.pixelSize, 12, "$font-avatar_bottom_slot-default-fontSize");
        a.destroy();
    }

    function test_bottomSlotSquareExtraSmallMissesItsRule() {
        const a = make('Avatar { text: "A"; size: "extra-small"; bottomSlot: ({shape: "square", text: "hi"}) }');
        wait(150);
        const box = part(a, "avatarBottomSlotShape");
        compare(box.border.width, 3, "官方类名拼成 -shape_square-extra_small（下划线）⇒ 命不中，退成 medium=3");
        compare(part(a, "avatarBottomSlotText").font.pixelSize, 14, "字号那条也命不中 ⇒ 退成继承值");
        a.destroy();
    }

    function test_bottomSlotWithoutShapeIsBareText() {
        const a = make('Avatar { text: "A"; bottomSlot: ({text: "hi"}) }');
        wait(150);
        compare(part(a, "avatarBottomSlotShape").visible, false,
                "class 是 -shape_undefined ⇒ 两块样式都不落，只剩 -bottom_slot");
        const t = part(a, "avatarBottomSlotText");
        compare(part(a, "avatarBottomSlotText").font.pixelSize, 14, "没有档位规则 ⇒ 继承值");
        const box = part(a, "avatarBottomSlotBox");
        near(box.width, t.implicitWidth, "没有盒子时外壳的尺寸就是文字自己（不是 padding + 描边那一套）");
        near(box.height, t.implicitHeight);
        near(t.x, 0, "宽度就是文字宽 ⇒ 居中后没有余量");
        a.destroy();
    }

    function test_bottomSlotColorsOverride() {
        const a = make('Avatar { text: "A"; bottomSlot: ({shape: "circle", text: "9",'
                       + ' bgColor: "#00ff00", textColor: "#ff0000"}) }');
        wait(60);
        compare(String(part(a, "avatarBottomSlotShape").color), "#00ff00", "bgColor 是内联 style");
        compare(String(part(a, "avatarBottomSlotText").color), "#ff0000", "textColor 同理");
        a.destroy();
    }

    function test_bottomSlotRenderBranchGoesInFlow() {
        const a = make("Avatar { text: \"A\"; bottomSlot: ({render: slotNode}) }");
        wait(150);
        compare(a.bottomSlotCustom, true);
        compare(part(a, "avatarBottomSlotBox").visible, false, "render 给了就不走那套壳");
        compare(part(a, "avatarBottomSlotRender").active, true);
        verify(a.implicitHeight > a.side, "流内节点要把隐式高顶起来");
        a.destroy();
    }

    function test_bottomSlotSquarePerSizeFont() {
        const expect = { "small": 5, "default": 12, "medium": 12, "large": 12, "extra-large": 14 };
        for (const key in expect) {
            const a = make('Avatar { text: "A"; size: "' + key + '"; bottomSlot: ({shape: "square", text: "hi"}) }');
            compare(part(a, "avatarBottomSlotText").font.pixelSize, expect[key],
                    key + " 档方牌字号（$font-avatar_bottom_slot-*）");
            a.destroy();
        }
    }

    function test_bottomSlotSquareBorderNeedsDarkMode() {
        darkMode();
        const a = make('Avatar { text: "A"; size: "default"; bottomSlot: ({shape: "square", text: "hi"}) }');
        wait(60);
        const box = part(a, "avatarBottomSlotShape");
        compare(String(box.border.color), String(Theme.current.colorBg0),
                "$color-avatar-bottom_slot_square-border 是 bg-0（浅色档与 bg-1 撞值 ⇒ 深色下量）");
        verify(String(box.border.color) !== String(Theme.current.colorPrimary),
               "描边色与底色此刻也不能同值，否则这条读不出方向");
        a.destroy();
    }

    // ---------------- 额外边框与动效 ----------------

    function test_borderFlags() {
        const off = make("Avatar { text: \"A\" }");
        compare(off.borderOn, false, "没给 border 就只有头像");
        compare(part(off, "avatarBorderRing").visible, false, "静态那一圈也不该画出来");
        compare(part(off, "avatarBorderMotionRing").visible, false);
        const on = make("Avatar { text: \"A\"; border: true }");
        compare(on.borderOn, true);
        compare(on.borderMotion, false, "border: true 不带 motion");
        compare(part(on, "avatarBorderMotionRing").visible, false, "静态环之外那第二圈只在 motion 时才画");
        const motion = make("Avatar { text: \"A\"; border: ({motion: true}) }");
        compare(motion.borderOn, true);
        compare(motion.borderMotion, true);
        compare(part(motion, "avatarBorderRing").visible, true, "官方那两支 span 是并存的");
        compare(part(motion, "avatarBorderMotionRing").visible, true);
        off.destroy(); on.destroy(); motion.destroy();
    }

    function test_borderRingGeometry() {
        const a = make('Avatar { text: "A"; size: "default"; border: true }');
        const ring = part(a, "avatarBorderRing");
        compare(a.ringSide, 47, "$width-avatar_additional-border 1.5 + gap 2 各两侧");
        compare(ring.width, 47);
        compare(ring.height, 47);
        compare(ring.x, -3.5, "top/left = −(1.5 + 2)");
        compare(ring.border.width, 1.5);
        compare(String(ring.border.color), String(Theme.current.colorPrimary),
                "$color-avatar_additional-border");
        compare(ring.radius, 23.5, "圆角档那一支 span 自带 -avatar-circle");
        const square = make('Avatar { text: "A"; size: "default"; shape: "square"; border: true }');
        compare(part(square, "avatarBorderRing").radius, 0,
                "方角那组类名官方拼成下划线 ⇒ 命不中 ⇒ 半径 0");
        const large = make('Avatar { text: "A"; size: "large"; border: ({color: "#00ff00"}) }');
        compare(large.ringSide, 79, "环的边长跟着尺寸档");
        compare(String(part(large, "avatarBorderRing").border.color), "#00ff00", "border.color 压过令牌");
        compare(part(large, "avatarBorderMotionRing").visible, false,
                "对象档里没写 motion ⇒ 第二圈不画（只有 motion === true 才加）");
        compare(part(large, "avatarBorderRing").visible, true);
        a.destroy(); square.destroy(); large.destroy();
    }

    function test_borderMotionAnimatesRing() {
        const a = make("Avatar { text: \"A\"; size: \"large\"; border: ({motion: true}) }");
        const ring = part(a, "avatarBorderMotionRing");
        compare(ring.border.width, 1.5, "动起来那一圈也是 1.5px");
        compare(ring.opacity, 1, "起态是不透明");
        compare(ring.scale, 1, "起态是不缩放");
        wait(200);
        verify(ring.opacity < 1 && ring.opacity > 0.2,
               "800ms 跑到这一拍该在衰减途中，实得 " + ring.opacity);
        verify(ring.scale > 1 && ring.scale < 1.15, "同一拍缩放该在 1→1.15 之间，实得 " + ring.scale);
        wait(700);
        verify(ring.opacity > 0.2, "一轮 800ms 跑完会重开 ⇒ 不该停在 0，实得 " + ring.opacity);
        a.destroy();
    }

    function test_contentMotionShrinksBodyOnly() {
        const a = make('Avatar { text: "A"; size: "large"; contentMotion: true;'
                       + ' topSlot: ({text: "V"}); border: true }');
        const body = part(a, "avatarBody");
        compare(body.scale, 1, "起态");
        wait(250);
        verify(body.scale < 1 && body.scale > 0.9, "1000ms 的中段在 1→0.9 之间，实得 " + body.scale);
        const cap = part(a, "avatarTopSlotBox");
        verify(cap.scale < 1 && cap.scale > 0.9, "topSlot 那层也带 -animated，实得 " + cap.scale);
        compare(part(a, "avatarBorderRing").scale, 1, "额外边框那圈不参与 contentMotion");
        compare(body.scale !== 1, true, "本体确实在动，不然上面那句 topSlot 也说明不了什么");
        wait(800);
        verify(body.scale > 0.9, "一轮跑完会重开 ⇒ 不停在 0.9");
        a.destroy();
    }

    function test_contentMotionOffByDefault() {
        const a = make("Avatar { text: \"A\"; size: \"large\" }");
        const body = part(a, "avatarBody");
        compare(body.scale, 1, "缺省不带动效");
        wait(400);
        compare(body.scale, 1, "等一拍也不该自己动起来");
        a.destroy();
    }

    // ---------------- AvatarGroup ----------------

    function test_groupDefaults() {
        const g = make("AvatarGroup { Avatar { text: \"A\" } Avatar { text: \"B\" } }");
        wait(150);
        compare(g.size, "medium", "官方 defaultProps.size = 'medium'");
        compare(g.shape, "circle");
        compare(g.overlapFrom, "start");
        compare(g.maxCount, undefined, "官方没有 maxCount 的缺省 ⇒ 不传永不截断");
        compare(g.memberSide, 48);
        compare(g.overlap, 12, "$spacing-avatar_medium-marginLeft");
        compare(g.borderWidth, 2, "$width-avatar_medium-border");
        const row = part(g, "avatarGroupRow");
        compare(row.spacing, -12, "重叠是负 margin-left");
        g.destroy();
    }

    function test_groupPerSizeMetrics() {
        const expect = { "extra-extra-small": [20, 1, 4], "extra-small": [24, 1, 10],
            "small": [32, 2, 12], "default": [40, 2, 12], "medium": [48, 2, 12],
            "large": [72, 3, 18], "extra-large": [128, 3, 32] };
        for (const key in expect) {
            const g = make('AvatarGroup { size: "' + key + '"; Avatar { text: "A" } Avatar { text: "B" } }');
            wait(120);
            compare(g.memberSide, expect[key][0], key + " 档成员边长");
            compare(g.borderWidth, expect[key][1], key + " 档成员描边");
            compare(g.overlap, expect[key][2], key + " 档重叠量");
            g.destroy();
        }
    }

    function test_groupPushesSizeAndShapeDown() {
        const g = make('AvatarGroup { size: "large"; shape: "square";'
                       + ' Avatar { text: "A"; size: "extra-extra-small" } Avatar { text: "B" } }');
        wait(150);
        const first = part(g, "avatarGroupRow").children[0];
        compare(first.side, 72, "官方 cloneElement 把组的 size 硬塞给每个成员，成员自己写的顶不掉");
        compare(first.radius, 6, "shape 同理");
        compare(first.groupShape, "square");
        g.destroy();
    }

    function test_groupOverlapPositions() {
        const g = make('AvatarGroup { size: "default";'
                       + ' Avatar { objectName: "g0"; text: "A" } Avatar { objectName: "g1"; text: "B" }'
                       + ' Avatar { objectName: "g2"; text: "C" } }');
        wait(150);
        const a0 = part(g, "g0"), a1 = part(g, "g1"), a2 = part(g, "g2");
        compare(a0.x, 0, "官方 :first-child { margin-left: 0 }");
        compare(a1.x, 28, "40 − 12");
        compare(a2.x, 56, "两两都按同一档负边距叠");
        compare(g.implicitWidth, 96, "整体宽 = 最后一项的右沿");
        compare(g.implicitHeight, 40);
        g.destroy();
    }

    function test_groupMemberBorder() {
        const g = make('AvatarGroup { size: "default"; Avatar { text: "A" } }');
        wait(150);
        const member = part(g, "avatarGroupRow").children[0];
        compare(member.groupBorderWidth, 2, "组内成员有逐档 bg-1 描边");
        const ring = part(member, "avatarGroupBorder");
        compare(ring.visible, true);
        compare(ring.border.width, 2);
        compare(String(ring.border.color), String(Theme.current.colorBg1),
                "$color-avatar_default-border-default");
        g.destroy();
    }

    function test_groupZOrderBothWays() {
        const start = make('AvatarGroup { overlapFrom: "start";'
                           + ' Avatar { objectName: "s0"; text: "A" } Avatar { objectName: "s1"; text: "B" } }');
        wait(150);
        compare(part(start, "s0").z, 100, "start ⇒ 越靠前越浮（z-index:100-i）");
        compare(part(start, "s1").z, 99);
        const end = make('AvatarGroup { overlapFrom: "end";'
                         + ' Avatar { objectName: "e0"; text: "A" } Avatar { objectName: "e1"; text: "B" } }');
        wait(150);
        compare(part(end, "e0").z, 80, "end ⇒ 越靠后越浮（z-index:80+i）");
        compare(part(end, "e1").z, 81);
        start.destroy(); end.destroy();
    }

    function test_groupMaxCountAppendsMore() {
        const g = make('AvatarGroup { maxCount: 2; Avatar { objectName: "m0"; text: "A" }'
                       + ' Avatar { objectName: "m1"; text: "B" } Avatar { objectName: "m2"; text: "C" }'
                       + ' Avatar { objectName: "m3"; text: "D" } }');
        wait(200);
        compare(g.totalCount, 4);
        compare(g.truncated, true);
        compare(g.restNumber, 2, "官方 restNumber = length - maxCount");
        compare(g.keepCount, 2);
        compare(part(g, "m2").visible, false, "溢出那几枚不再渲染");
        compare(part(g, "m3").visible, false);
        const more = part(g, "avatarGroupMore");
        compare(more.visible, true);
        compare(more.text, "+2", "官方那一支 children 是 +{restNumber}");
        compare(more.side, 48, "「+N」也吃组的尺寸");
        compare(String(more.backgroundColor), String(Theme.current.grey[5]),
                "$color-avatar_more_default-bg-default");
        compare(String(more.surfaceColor), String(Theme.current.grey[5]), "底色真的落在外壳上");
        compare(more.x, 72, "排在最后一个保留项之后，照同一档重叠：48 + (48−12) − 12");
        compare(more.z, 98, "它是 merged 数组的第 3 项 ⇒ 层序按 index 2 发");
        g.destroy();
    }

    function test_groupMoreNotAddedWhenNothingOverflows() {
        const g = make('AvatarGroup { maxCount: 3; Avatar { text: "A" } Avatar { text: "B" }'
                       + ' Avatar { text: "C" } }');
        wait(150);
        compare(g.truncated, false, "restNumber > 0 才 push 那一枚");
        compare(part(g, "avatarGroupMore").visible, false);
        compare(g.implicitWidth, 48 + 36 + 36);
        g.destroy();
    }

    function test_groupMaxCountAboveLength() {
        const g = make('AvatarGroup { maxCount: 9; Avatar { text: "A" } Avatar { text: "B" } }');
        wait(150);
        compare(g.truncated, false, "maxCount 比成员数大 ⇒ 不截断（官方 restNumber 为负）");
        compare(g.keepCount, 2, "保留数不能超实际成员数");
        compare(part(g, "avatarGroupMore").visible, false);
        g.destroy();
    }

    function test_groupMaxCountZeroStillShowsMore() {
        const g = make('AvatarGroup { maxCount: 0; Avatar { text: "A" } Avatar { text: "B" } }');
        wait(150);
        compare(g.truncated, true, "isNumber(0) 也算给了 ⇒ 官方 slice(0,0) 只剩「+N」");
        compare(g.keepCount, 0);
        compare(part(g, "avatarGroupMore").visible, true);
        compare(part(g, "avatarGroupMore").text, "+2");
        compare(part(g, "avatarGroupMore").x, 0, "一项都没保留 ⇒ 它从 0 开始");
        g.destroy();
    }

    function test_groupMoreAltJoinsRestLabels() {
        const g = make('AvatarGroup { maxCount: 1; Avatar { objectName: "k0"; text: "A" }'
                       + ' Avatar { objectName: "k1"; text: "B"; alt: " bee " }'
                       + ' Avatar { objectName: "k2"; text: "" } Avatar { objectName: "k3"; alt: "dd" } }');
        wait(200);
        compare(part(g, "avatarGroupMore").alt, " Number of remaining Avatars：3, bee ,dd",
                "官方那条 alt 是全角冒号 + 溢出项的 alt ?? 文字（原样带空格），空串那枚跳过；restNumber = 4 − 1");
        g.destroy();
    }

    function test_groupRenderMoreReplacesNode() {
        const g = make("AvatarGroup { maxCount: 1; renderMore: moreNode;"
                       + ' Avatar { text: "A" } Avatar { text: "B" } Avatar { text: "C" } }');
        wait(250);
        compare(g.truncated, true);
        compare(part(g, "avatarGroupMore").visible, false, "官方 renderMore 给节点时整支替换掉 +N");
        const node = part(g, "avatarGroupMoreNode");
        compare(node.active, true);
        compare(node.item.objectName, "moreNodeRect", "载入的是使用处那个节点");
        verify(node.x > 0, "自定义节点也排在最后一个保留项之后，实得 " + node.x);
        compare(node.z, 99, "这一支同样按 merged 数组的 index 1 发层序");
        g.destroy();
    }

    readonly property Component moreNode: Component {
        Rectangle {
            objectName: "moreNodeRect"
            width: 24
            height: 24
            color: "#00ff00"
        }
    }

    function test_groupKeepsMemberOwnImage() {
        const g = make('AvatarGroup { size: "small"; Avatar { src: "' + quads + '" }'
                       + ' Avatar { text: "B" } }');
        wait(150);
        const first = part(g, "avatarGroupRow").children[0];
        compare(first.isImg, true, "成员自己的图不被组的 size 影响");
        compare(first.side, 32, "但尺寸照组的档位");
        g.destroy();
    }

    function test_groupLateMemberIsCounted() {
        const g = make('AvatarGroup { maxCount: 1; Avatar { objectName: "late0"; text: "A" } }');
        wait(150);
        compare(g.totalCount, 1);
        compare(g.truncated, false, "只有一枚 ⇒ 还没到截断那一步");
        Qt.createQmlObject('import QtQuick; import Semi; Avatar { objectName: "late1"; text: "B" }',
                           part(g, "avatarGroupRow"), "late");
        wait(200);
        compare(g.totalCount, 2, "后加的成员要进名单（content 是 Row.data、没有 NOTIFY，得借 childrenChanged 当脉冲）");
        compare(g.truncated, true);
        compare(g.restNumber, 1);
        compare(part(g, "avatarGroupMore").visible, true);
        compare(part(g, "avatarGroupMore").text, "+1");
        g.destroy();
    }

    function test_groupCountsOnlyAvatars() {
        const g = make('AvatarGroup { Avatar { objectName: "n0"; text: "A" } Timer { interval: 5000 }'
                       + ' Avatar { objectName: "n1"; text: "B" } }');
        wait(200);
        compare(g.totalCount, 2, "名单只数真头像，混进来的非头像项不参与重叠与层序");
        compare(g.truncated, false);
        compare(part(g, "avatarGroupMore").visible, false);
        const row = part(g, "avatarGroupRow");
        compare(row.data.length, 3, "Row 的 data 里确实是三个对象（children 只数可视项），门是在名单那一层");
        compare(part(g, "n0").x, 0);
        compare(part(g, "n1").x, 36, "那枚 Timer 不占位（Row 只排可见项）");
        g.destroy();
    }

    function test_groupAccessibleRoleIsList() {
        const g = make('AvatarGroup { Avatar { text: "A" } }');
        wait(100);
        compare(g.Accessible.role, Accessible.List, "官方 role='list'");
        const member = part(g, "avatarGroupRow").children[0];
        compare(member.Accessible.role, Accessible.ListItem, "官方 role='listitem'，与在不在组里无关");
        g.destroy();
    }

    // ---------------- 旧接口的去向 ----------------
    // 旧端口的 `circle`（bool）与 `size: Enums.*` 三档整份换掉：
    //   circle: true|false        → shape: "circle"|"square"
    //   Enums.Small/Default/Large → "small"/"default"/"large"（另有官方那四档与自定义数）
    //   文字取首字并大写化        → 官方整串显示 + gap/scale 自适应
    //   Appearance::avatarSize / avatarBackground → 查表整份搬进 Avatar.qml（C++ 那两个 helper 已删）
}
