import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Icon"
    when: windowShown
    width: 200
    height: 200

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function icon(props) {
        return Qt.createQmlObject(
            "import Semi; Icon { " + (props || "") + " }", testCase, "icon")
    }

    // 像素采样区：被测图标固定摆在 (20,20) 48×48。
    // inkStats 统计「目标红 / 黑墨」（效果层，白底）；
    // assetInk 统计「白墨 / 黑墨」（资产层，中灰底 #808080，白黑两边都拉得开）。
    function inkStats(img) {
        const dpr = img.width / testCase.width;
        let red = 0, black = 0;
        for (let y = Math.round(20 * dpr); y < Math.round(68 * dpr); ++y) {
            for (let x = Math.round(20 * dpr); x < Math.round(68 * dpr); ++x) {
                const c = Qt.color(img.pixel(x, y));
                if (c.r - c.b > 0.35)
                    red++;                        // 目标红（含底色上的抗锯齿粉）
                else if (c.r < 0.35 && c.g < 0.35 && c.b < 0.35)
                    black++;                      // 黑墨 = 源 SVG 没转白
            }
        }
        return { red, black };
    }

    function assetInk(img) {
        const dpr = img.width / testCase.width;
        let white = 0, black = 0;
        for (let y = Math.round(20 * dpr); y < Math.round(68 * dpr); ++y) {
            for (let x = Math.round(20 * dpr); x < Math.round(68 * dpr); ++x) {
                const c = Qt.color(img.pixel(x, y));
                if (c.r > 0.9)
                    white++;                      // 白填充弧线本体
                else if (c.r < 0.1)
                    black++;                      // 黑填充 = sync 转白漏了
            }
        }
        return { white, black };
    }

    function test_sourceIsBuiltFromName() {
        const i = icon('name: "plus"')
        compare(i.source.toString(), "qrc:/qt/qml/Semi/icons/plus.svg")
        i.destroy()
    }

    function test_emptyNameHasNoSource() {
        const i = icon("")
        compare(i.source.toString(), "")
        compare(i.visible, false)
        i.destroy()
    }

    function test_defaultSizeAndColor() {
        const i = icon('name: "plus"')
        compare(i.implicitWidth, Theme.current.widthIconMedium)   // 16
        compare(i.implicitHeight, Theme.current.widthIconMedium)
        compare(i.color.toString(), Theme.current.colorText0.toString())
        i.destroy()
    }

    function test_explicitSizeIsUsed() {
        const i = icon('name: "plus"; size: 24')
        compare(i.implicitWidth, 24)
        compare(i.implicitHeight, 24)
        i.destroy()
    }

    function test_colorFollowsTheme() {
        const i = icon('name: "delete"; color: Theme.current.colorDanger')
        compare(i.color.toString(), "#f93920")

        Theme.mode = Theme.Dark
        verify(i.color.toString() !== "#f93920", "图标颜色应随主题变")
        i.destroy()
    }

    // colorization 是「灰度 × 目标色」（multieffect.frag:84），黑填充源灰度 0、
    // 染什么色都是黑。上游 svgs 全是黑填充，sync-icons.py 负责转白；其中 8 枚
    // 带 clip-path="url(#…)" 的曾被裸 `url(` 判据误判成「保留原色」，黑填充
    // 落盘后按钮转圈（spin）、Spin 页指示器（loading）等全部恒黑。
    function test_clipPathIconsAreTintable() {
        const names = ["alarm_stroked", "config_stroked", "issue_stroked",
                       "loading", "spin", "sun_stroked", "triangle_arrow", "user_add"];

        // 第一层（资产层，offscreen 也画得出）：裸 Image 直接铺 SVG、垫中灰底，
        // 钉住弧线本体是白填充——黑填充在灰底上会现黑墨。
        for (const n of names) {
            const raw = Qt.createQmlObject(
                'import QtQuick; Item {'
                + ' Rectangle { anchors.fill: parent; color: "#808080" }'
                + ' Image { anchors.fill: parent; source: "qrc:/qt/qml/Semi/icons/' + n + '.svg" }'
                + ' x: 20; y: 20; width: 48; height: 48 }', testCase, "rawAsset");
            tryCompare(raw.children[1], "status", Image.Ready);
            wait(100);
            const img = grabImage(testCase);
            verify(img !== undefined && img !== null, n + " 读不到像素");
            const a = assetInk(img);
            verify(a.white > 0, n + " 弧线本体该是白色填充（白点 " + a.white + "）");
            compare(a.black, 0, n + " 出现黑墨 = sync-icons 转白漏了它");
            raw.destroy();
        }

        // 第二层（效果层，MultiEffect 在 offscreen 画不出）：能力探针 plus 都染不上红
        // 说明这一档着色管线上屏不了，资产层已钉住根因，这里直接收工
        const ref = icon('name: "plus"; color: "#ff0000"; size: 48; x: 20; y: 20');
        wait(150);
        const refImg = grabImage(testCase);
        const refInk = refImg !== undefined && refImg !== null ? inkStats(refImg) : { red: 0, black: 0 };
        ref.destroy();
        if (refInk.red === 0)
            return;

        for (const n of names) {
            const i = icon('name: "' + n + '"; color: "#ff0000"; size: 48; x: 20; y: 20');
            wait(150); // SVG 首帧上屏
            const img = grabImage(testCase);
            verify(img !== undefined && img !== null, n + " 读不到像素");
            const s = inkStats(img);
            verify(s.red > 0, n + " 该被染红（实际红点 " + s.red + "）");
            compare(s.black, 0, n + " 出现黑墨 = 源 SVG 没转白");
            i.destroy();
        }
    }

    // 图标资源确实在 qrc 里 —— 加载失败时 Image 的 status 会是 Error
    function test_resourceIsReachable() {
        const probe = Qt.createQmlObject(
            'import QtQuick; Image { source: "qrc:/qt/qml/Semi/icons/plus.svg"; visible: false }',
            testCase, "probe")
        tryCompare(probe, "status", Image.Ready)
        probe.destroy()
    }
}
