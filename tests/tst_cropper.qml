import QtQuick
import QtTest
import Semi

// Cropper 图片裁切。规格照 packages/semi-ui/cropper/index.tsx（CropperProps :13-42、
// defaultProps :65-76、getDerivedStateFromProps :120-181、render :214-300）与
// packages/semi-foundation/cropper/foundation.ts（handleImageLoad :195-241、
// handleResize :171-193、getCropperBoxWhenResize :116-168、renderPreview/updatePreview
// :243-306、handleWheel :316-367、getRangeForAspectChange :397-486、
// handleCornerAspectMouseMove :526-608、handleCornerMouseMove :636-674、
// handleCropperBoxMouseMove :694-723、handleImgMove :769-792、getCropperCanvas :795-818+）。
//
// 夹具 qrc:/tests/crop_quads.png 是 200×100 的四色块（红/绿/蓝/白各占一角，边界正好在
// 中点 100,50）：裁切结果与圆形遮罩都要能「按坐标读出一个已知颜色」，四色块才分得开。
// 像素断言走 TestCase.grabImage —— 实测 offscreen 也画得出内容（不像 Qt6 Canvas 那样
// 分平台，见 src/Cropper.qml 文件头与坑 112），所以这一份不需要 cocoa。
//
// 端口口径（都在 src/Cropper.qml 头注释里）：
//   · 受控 rotate / zoom 两条各自独立生效（官方那条 zoom 分支被 `!isUndefined(newRotate)` 挡着）。
//   · roundRect 与 round 一样是个圆（官方只有 `-view-box-round { border-radius: 50% }` 一条），
//     但框那一层的圆环与四块调整块只认严格等于 'round'。
//   · imgProps / cropperBoxCls / className / style 收了不产出差异（imgProps 官方就是死 prop）。
TestCase {
    id: testCase

    name: "Cropper"
    when: windowShown
    width: 900
    height: 700

    readonly property string quads: "qrc:/tests/crop_quads.png"   // 200×100
    readonly property string tall: "qrc:/tests/img_tall.png"      // 270×480

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Dark;
    }

    // 断言失败会跳过用例末尾的 destroy ⇒ 残留实例会继续吃鼠标与滚轮
    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import QtTest; import Semi; " + qml,
                                  testCase, "cropper");
    }

    function part(root, name) {
        return testCase.findChild(root, name);
    }

    // Repeater 的代理（以及代理里挂的方块）findChild 取不到，只能自己递归走 children
    function findAll(root, name, out) {
        if (out === undefined)
            out = []
        if (root.objectName === name)
            out.push(root)
        for (let i = 0; i < root.children.length; ++i)
            testCase.findAll(root.children[i], name, out)
        return out
    }

    // TestCase.fuzzyCompare 是「自己记账」的那类断言函数（没有返回值），包一层拿不到结果，
    // 而这一份的数几乎每条都要写一句「这个值是怎么来的」⇒ 自己按容差判 + verify。
    function nearly(actual, expected, delta, message) {
        const d = delta === undefined ? 1e-9 : delta;
        verify(Math.abs(actual - expected) <= d,
               (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    // 300×150 的标准夹具：图正好铺满容器（fitScale 1.5），框 150×150 居中 ⇒ 数好算的整数
    function makeQuads(extra) {
        return make("Cropper { width: 300; height: 150; src: 'qrc:/tests/crop_quads.png'; "
                    + (extra || "") + " }");
    }

    function waitLoaded(c, message) {
        tryCompare(c, "loaded", true, 100, 3000);
        verify(c.loaded, message || "夹具图要能加载完成（几何都挂在 handleImageLoad 那一拍）");
    }

    // 调整块是 Repeater 造在框这一层的子项，objectName 带方向后缀
    function cornerDirs(c) {
        const box = part(c, "cropperBox");
        verify(box !== null, "要有一层裁切框");
        const out = [];
        for (let i = 0; i < box.children.length; ++i) {
            const name = box.children[i].objectName;
            if (name.indexOf("cropperCorner-") === 0)
                out.push(name.slice("cropperCorner-".length));
        }
        out.sort();
        return out;
    }

    // ---------------- 属性面与缺省 ----------------

    function test_officialPropDefaults() {
        const c = make("Cropper {}");
        compare(c.shape, "rect", "index.tsx:67");
        compare(c.defaultAspectRatio, 1, "index.tsx:68");
        compare(c.showResizeBox, true, "index.tsx:69");
        compare(c.fill, Qt.rgba(0, 0, 0, 0), "index.tsx:70 那条 'rgba(0, 0, 0, 0)'");
        compare(c.maxZoom, 3, "index.tsx:71");
        compare(c.minZoom, 0.1, "index.tsx:72");
        compare(c.zoomStep, 0.1, "index.tsx:73");
        verify(c.aspectRatio === undefined, "aspectRatio 没有缺省（给了才锁比例）");
        verify(c.zoom === undefined, "zoom 是受控值，没有缺省");
        verify(c.rotate === undefined, "rotate 同上");
        verify(c.imgProps === undefined, "imgProps 官方在接口里、render 里从没展开（死 prop）");
        verify(c.cropperBoxStyle === undefined);
        compare(c.cropperBoxCls, "");
        compare(c.preview, null);
        compare(c.loaded, false, "没图没尺寸 ⇒ 一切几何都还是 0");
        compare(c.imgW, 0);
        compare(c.boxW, 0);
        c.destroy();
    }

    // ---------------- 初始布局（handleImageLoad :195-241）----------------

    function test_initialLayoutFillsHeight() {
        // 200×100 放进 300×150：200/300 == 100/150 ⇒ 走 else 档（按高夹），图正好铺满
        const c = makeQuads();
        waitLoaded(c);
        compare(c.originalW, 200, "原始尺寸读的是隐式宽高，不是 sourceSize（坑 110）");
        compare(c.originalH, 100);
        compare(c.fitScale, 1.5, "scale = 容器高 / 原始高");
        compare(c.imgW, 300);
        compare(c.imgH, 150);
        compare(c.imgX, 0);
        compare(c.imgY, 0);
        compare(c.boxW, 150, "aspect 1 ⇒ 框 = 容器高 × 比例，横着居中");
        compare(c.boxH, 150);
        compare(c.boxX, 75);
        compare(c.boxY, 0);
        c.destroy();
    }

    function test_initialLayoutWidthLimited() {
        // 同一张图放进 400×300：200/400 > 100/300 ⇒ 走 if 档（按宽夹），上下留边
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        compare(c.fitScale, 2);
        compare(c.imgW, 400);
        compare(c.imgH, 200);
        compare(c.imgY, 50, "(300 − 200) / 2，图居中而不是贴顶");
        compare(c.boxW, 300, "400/300 > 1 ⇒ 框宽 = 容器高 × 1");
        compare(c.boxH, 300);
        compare(c.boxX, 50);
        compare(c.boxY, 0);
        c.destroy();
    }

    function test_initialLayoutTallImage() {
        // 270×480 放进 400×300：270/400 < 480/300 ⇒ else 档，左右留边
        const c = make("Cropper { width: 400; height: 300; src: '" + tall + "' }");
        waitLoaded(c);
        compare(c.fitScale, 0.625);
        nearly(c.imgW, 168.75, 1e-6);
        compare(c.imgH, 300);
        nearly(c.imgX, 115.625, 1e-6);
        c.destroy();
    }

    function test_defaultAspectRatioSizesBox() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads
                       + "'; defaultAspectRatio: 16/9 }");
        waitLoaded(c);
        compare(c.boxW, 400, "400/300 = 1.33 不大于 16/9 ⇒ else 档：框宽 = 容器宽");
        nearly(c.boxH, 225, 1e-6, "框高 = 400 / (16/9)");
        nearly(c.boxY, 37.5, 1e-6);
        c.destroy();
    }

    function test_aspectRatioWinsOverDefault() {
        // aspectRatio 既锁拖拽，也参与初始尺寸（:225 `aspectRatio || defaultAspectRatio`）
        const c = make("Cropper { width: 400; height: 300; src: '" + quads
                       + "'; aspectRatio: 0.5; defaultAspectRatio: 2 }");
        waitLoaded(c);
        compare(c.boxW, 150, "1.33 > 0.5 ⇒ 框宽 = 容器高 × 0.5");
        compare(c.boxH, 300);
        compare(c.boxX, 125);
        c.destroy();
    }

    function anyCornerVisible(c) {
        const box = part(c, "cropperBox");
        for (let i = 0; i < box.children.length; ++i) {
            if (box.children[i].objectName.indexOf("cropperCorner-") === 0
                    && box.children[i].visible)
                return true;
        }
        return false;
    }

    function test_noSrcStaysUnloaded() {
        const c = make("Cropper { width: 300; height: 150 }");
        compare(c.loaded, false, "没有 src ⇒ handleImageLoad 根本不跑");
        compare(c.boxW, 0);
        // 官方那圈调整块的条件是 `loaded && showResizeBox`（index.tsx:294）⇒ 没加载完不许有块露着
        compare(anyCornerVisible(c), false, "loaded 那道闸门");
        c.destroy();
    }

    // ---------------- 图层结构（cropper.scss）----------------

    function test_layersExist() {
        const c = makeQuads();
        waitLoaded(c);
        const layer = part(c, "cropperImageLayer");
        const mask = part(c, "cropperMask");
        const box = part(c, "cropperBox");
        const viewBox = part(c, "cropperViewBox");
        verify(layer !== null && mask !== null && box !== null && viewBox !== null,
               "图层层 / 遮罩 / 框 / 框里那张亮图四层都要在");
        compare(layer.clip, true, "-img-wrapper 是 overflow: hidden");
        compare(mask.color, Theme.current.colorOverlayBg,
                "-mask 的底色就是 --semi-color-overlay-bg");
        const outline = part(c, "cropperBoxOutline");
        compare(outline.border.width, 1, "-box 那条 1px 是 outline");
        compare(outline.border.color, Theme.current.colorPrimary);
        // 框里那张亮图的偏移 = 图相对框的位置（index.tsx:219-220）
        const viewImage = part(c, "cropperViewImage");
        compare(viewImage.x, c.imgX - c.boxX);
        compare(viewImage.y, c.imgY - c.boxY);
        c.destroy();
    }

    function test_cornerModelPerShape() {
        const rect = makeQuads();
        waitLoaded(rect);
        compare(cornerDirs(rect), ["bl", "bm", "br", "ml", "mr", "tl", "tm", "tr"],
                "strings.corner 八块");
        rect.shape = "round";
        compare(cornerDirs(rect), ["bm", "ml", "mr", "tm"],
                "shape === 'round' 只剩 strings.roundCorner 四块");
        rect.shape = "roundRect";
        compare(cornerDirs(rect), ["bl", "bm", "br", "ml", "mr", "tl", "tm", "tr"],
                "调整块那一条判断是严格等于，roundRect 仍是八块");
        rect.destroy();
    }

    function test_showResizeBoxFalseHidesCorners() {
        const c = makeQuads("showResizeBox: false");
        waitLoaded(c);
        compare(anyCornerVisible(c), false, "loaded && showResizeBox 那道闸门关掉就不许有块露着");
        c.showResizeBox = true;
        compare(anyCornerVisible(c), true, "开关是活的，不是一次性判断");
        c.destroy();
    }

    function test_cornersRideTheBoxEdges() {
        // 官方是 10×10 的块、各边外扩 5px（`-box-corner` 的 -5px 那四条）⇒ 块中心正好压在边线上
        const c = makeQuads();
        waitLoaded(c);
        const tl = part(c, "cropperCorner-tl");
        const br = part(c, "cropperCorner-br");
        const tm = part(c, "cropperCorner-tm");
        const ml = part(c, "cropperCorner-ml");
        verify(tl !== null && br !== null && tm !== null && ml !== null, "四块都要在");
        compare(tl.x, -5);
        compare(tl.y, -5);
        compare(br.x, c.boxW - 5);
        compare(br.y, c.boxH - 5);
        compare(tm.x, c.boxW / 2 - 5, "上下两条边的中间块骑在边线中点");
        compare(tm.y, -5);
        compare(ml.x, -5);
        compare(ml.y, c.boxH / 2 - 5);
        compare(tl.width, 10);
        compare(tl.height, 10);
        c.destroy();
    }

    function test_cornersAreDrawnAsPrimarySquares() {
        // 官方那八块是**看得见**的实心方块（`-box-corner { background: --semi-color-primary }`），
        // 端口此前只留了 10×10 的命中区，画面上一个点都没有 ⇒ 用户找不到「只有这里能改尺寸」的入口
        const c = makeQuads();
        waitLoaded(c);
        const faces = testCase.findAll(c, "cropperCornerFace", []);
        compare(faces.length, 8, "rect 档八块都要画出来");
        for (let i = 0; i < faces.length; ++i) {
            compare(faces[i].color, Theme.current.colorPrimary, "第 " + i + " 块是 primary");
            compare(faces[i].width, 10, "方块铺满那一档 10×10 的命中区");
            compare(faces[i].height, 10);
            compare(faces[i].parent.visible, true);
        }
        c.destroy();

        // round 档只剩上下左右四块（strings.roundCorner），roundRect 仍是八块
        const round = make("Cropper { width: 300; height: 150; src: '" + quads
            + "'; shape: 'round' }");
        waitLoaded(round);
        compare(testCase.findAll(round, "cropperCornerFace", []).length, 4,
            "圆档只有四边那四块");
        round.destroy();

        const roundRect = make("Cropper { width: 300; height: 150; src: '" + quads
            + "'; shape: 'roundRect' }");
        waitLoaded(roundRect);
        compare(testCase.findAll(roundRect, "cropperCornerFace", []).length, 8,
            "roundRect 官方不减块，仍是八块");
        roundRect.destroy();

        // showResizeBox: false ⇒ 官方连节点都不挂（JSX 那道闸），端口跟着整块不见
        const bare = makeQuads("showResizeBox: false");
        waitLoaded(bare);
        const bareFaces = testCase.findAll(bare, "cropperCornerFace", []);
        let painted = 0;
        for (let i = 0; i < bareFaces.length; ++i)
            if (bareFaces[i].parent.visible)
                painted++;
        compare(painted, 0, "关掉开关一块都不许露着");
        bare.destroy();
    }

    function test_dragLayerCursorsMatchOfficial() {
        // 官方：`-mask { cursor: move }`、`-view-box { cursor: move }`（铺满整块框），
        // 八块调整块各带自己的 resize 光标 ⇒ 除了方块那八处，整片都是「移动」
        const c = makeQuads();
        waitLoaded(c);
        compare(part(c, "cropperMaskArea").cursorShape, Qt.SizeAllCursor, "框外拖图");
        compare(part(c, "cropperBoxArea").cursorShape, Qt.SizeAllCursor, "框内拖框");
        compare(part(c, "cropperCorner-tl").cursorShape, Qt.SizeFDiagCursor);
        compare(part(c, "cropperCorner-br").cursorShape, Qt.SizeFDiagCursor);
        compare(part(c, "cropperCorner-tr").cursorShape, Qt.SizeBDiagCursor);
        compare(part(c, "cropperCorner-bl").cursorShape, Qt.SizeBDiagCursor);
        compare(part(c, "cropperCorner-tm").cursorShape, Qt.SizeVerCursor);
        compare(part(c, "cropperCorner-bm").cursorShape, Qt.SizeVerCursor);
        compare(part(c, "cropperCorner-ml").cursorShape, Qt.SizeHorCursor);
        compare(part(c, "cropperCorner-mr").cursorShape, Qt.SizeHorCursor);
        c.destroy();

        // 方块的颜色就是 primary，不吃 cropperBoxStyle 那枚改环色的键
        const styled = makeQuads("cropperBoxStyle: ({ outlineColor: '#ff0000' })");
        waitLoaded(styled);
        compare(part(styled, "cropperBoxOutline").border.color, "#ff0000", "环跟着键走");
        const faces = testCase.findAll(styled, "cropperCornerFace", []);
        compare(faces.length, 8);
        for (let i = 0; i < faces.length; ++i)
            compare(faces[i].color, Theme.current.colorPrimary,
                "第 " + i + " 块不跟键走（官方那条 background 写死在 -box-corner 上）");
        styled.destroy();
    }

    // ---------------- 拖调整块：自由档（handleCornerMouseMove :636-674）----------------

    function test_freeCornerDragMR() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        mousePress(c, 349, 150);            // mr 块中心（框右边中点）
        mouseMove(c, 379, 150);
        mouseRelease(c, 379, 150);
        nearly(c.boxW, 329, 1e-6, "300 + (379 − 350)");
        nearly(c.boxCX, 214.5, 1e-6, "中心跟着走一半：379 − 329/2");
        compare(c.boxH, 300, "mr 只动横");
        compare(c.boxCY, 150);
        c.destroy();
    }

    function test_freeCornerDragClampsAtContainer() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        mousePress(c, 349, 299);            // br 块
        mouseMove(c, 380, 320);             // 纵向已经顶到容器下边，多出去的那段夹掉
        nearly(c.boxW, 330, 1e-6);
        compare(c.boxH, 300, "框本来就吃满容器高 ⇒ 往下拖不长");
        mouseMove(c, 380, 250);             // 回来：以上一拍为基准的增量口径
        nearly(c.boxH, 250, 1e-6, "500 − 250 那 20 是丢掉的（官方就是增量式夹边界）");
        nearly(c.boxCY, 125, 1e-6);
        mouseRelease(c, 380, 250);
        c.destroy();
    }

    function test_freeCornerDragFlipsPastZero() {
        // 拖过对面那条边：官方把 width 取正、paramX 反号（:651-654），框不许是负的
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        mousePress(c, 349, 150);            // mr：锚点 x = 200 + 150 = 350
        mouseMove(c, 20, 150);              // 300 + (20 − 350) = −30 ⇒ 取正、paramX 反号
        mouseRelease(c, 20, 150);
        nearly(c.boxW, 30, 1e-6, "拖过头只剩 30 宽");
        nearly(c.boxCX, 35, 1e-6, "cx = ox − paramX·w/2 = 20 + 15");
        nearly(c.boxX, 20, 1e-6, "反号之后 mr 变成贴着左边那条");
        c.destroy();
    }

    // ---------------- 拖调整块：比例锁定档（:397-486 / :526-608）----------------

    function test_aspectCornerDragKeepsRatio() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads
                       + "'; aspectRatio: 2 }");
        waitLoaded(c);
        compare(c.boxW, 400);
        compare(c.boxH, 200);
        mousePress(c, 399, 249);            // br
        mouseMove(c, 380, 230);
        mouseRelease(c, 380, 230);
        nearly(c.boxH, 180, 1e-6, "rangeY = [50, 250] ⇒ 高 = 230 − 50");
        nearly(c.boxW, 360, 1e-6, "宽 = 高 × 2");
        nearly(c.boxCX, 180, 1e-6, "左上顶点不动：rangeX[0] + 宽/2");
        nearly(c.boxCY, 140, 1e-6);
        nearly(c.boxX, 0, 1e-6);
        nearly(c.boxY, 50, 1e-6);
        c.destroy();
    }

    function test_aspectCornerDragClampsMiddle() {
        // tm / bm 走的是「以框中心为对称轴」那一档，ml / mr 只夹 offsetX
        const c = make("Cropper { width: 400; height: 300; src: '" + quads
                       + "'; aspectRatio: 2 }");
        waitLoaded(c);
        mousePress(c, 200, 51);             // tm 块（框上边中点）
        mouseMove(c, 200, 120);
        mouseRelease(c, 200, 120);
        nearly(c.boxH, 130, 1e-6, "rangeY = [50, 250] ⇒ 高 = 250 − 120");
        nearly(c.boxW, 260, 1e-6);
        nearly(c.boxCX, 200, 1e-6, "tm 档中心横坐标不变");
        nearly(c.boxCY, 185, 1e-6);
        c.destroy();
    }

    function test_aspectRangesAreRecordedOnPress() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads
                       + "'; aspectRatio: 2 }");
        waitLoaded(c);
        mousePress(c, 399, 249);
        compare(c.rangeXMin, 0, "br 档：左界 = 框左边");
        compare(c.rangeXMax, 400, "右界 = 容器右边（宽 = cw − xMin）");
        compare(c.rangeYMin, 50, "下界 = 框顶 yMin");
        compare(c.rangeYMax, 250, "上界 = yMin + 高（高被 getAspectHW 夹成 宽/比例 = 200）");
        mouseRelease(c, 399, 249);
        c.destroy();
    }

    // ---------------- 拖框 / 拖图 ----------------

    function test_boxDragClampsIncrementally() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        mousePress(c, 200, 150);            // 框内、离四块都远
        mouseMove(c, 230, 150);
        nearly(c.boxCX, 230, 1e-6);
        mouseMove(c, 260, 150);             // 右边界 = 400 − 150 = 250
        nearly(c.boxCX, 250, 1e-6, "夹在 250，多出去那 10 丢掉");
        mouseMove(c, 230, 150);
        nearly(c.boxCX, 220, 1e-6, "往回 30 ⇒ 220，不是回到 230（增量式）");
        mouseRelease(c, 230, 150);
        compare(c.boxW, 300, "拖框不改尺寸");
        compare(c.boxH, 300);
        c.destroy();
    }

    function test_boxDragKeepsImageStill() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        const beforeX = c.imgCX;
        mousePress(c, 200, 150);
        mouseMove(c, 240, 170);
        mouseRelease(c, 240, 170);
        compare(c.imgCX, beforeX, "拖框只动框，图那一层不受影响");
        c.destroy();
    }

    function test_maskDragMovesImageUnclamped() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        mousePress(c, 20, 20);              // 框外（框从 x=50 起）⇒ 落在遮罩上
        mouseMove(c, 60, 40);
        nearly(c.imgCX, 240, 1e-6, "图心跟着指针走，不夹边界");
        nearly(c.imgCY, 170, 1e-6);
        mouseMove(c, 399, 299);             // 一路拖到容器右下角
        nearly(c.imgCX, 579, 1e-6, "拖出容器也照收（官方 handleImgMove 没有夹边界）");
        nearly(c.imgCY, 429, 1e-6, "170 + (299 − 40)");
        mouseRelease(c, 399, 299);
        compare(c.boxCX, 200, "拖图不动框");
        c.destroy();
    }

    // ---------------- 滚轮缩放（handleWheel :316-367）----------------

    function test_wheelZoomAboutCursor() {
        const host = make("Item { property Item theCrop: crop; property var zoomSpy: spy;"
                          + " Cropper { id: crop; width: 400; height: 300; src: '" + quads + "' }"
                          + " SignalSpy { id: spy; target: crop; signalName: \"zoomChange\" } }");
        const c = host.theCrop;
        waitLoaded(c);
        mouseWheel(c, 100, 100, 0, 120);    // angleDelta.y 正 = 向上滚 = 放大
        wait(50);
        nearly(c.innerZoom, 1.1, 1e-6, "缺省 zoomStep 0.1");
        nearly(c.imgW, 440, 1e-6);
        nearly(c.imgH, 220, 1e-6);
        nearly(c.imgCX, 210, 1e-6, "以指针那点为缩放中心：(200−100)/1×1.1+100");
        nearly(c.imgCY, 155, 1e-6, "y 那一档官方先取负再算：−((−150+100)/1×1.1−100)");
        compare(host.zoomSpy.count, 1, "onZoomChange 只在真的改了那一拍发");
        nearly(host.zoomSpy.signalArguments[0][0], 1.1, 1e-6);
        mouseWheel(c, 100, 100, 0, -120);   // 向下滚 = 缩回去
        nearly(c.innerZoom, 1, 1e-6);
        compare(host.zoomSpy.count, 2);
        host.destroy();
    }

    function test_wheelClampsAtMaxAndMin() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        for (let i = 0; i < 25; ++i)
            mouseWheel(c, 200, 150, 0, 120);
        nearly(c.innerZoom, 3, 1e-9, "maxZoom 3 挡在门口");
        const w = c.imgW;
        mouseWheel(c, 200, 150, 0, 120);
        nearly(c.imgW, w, 1e-9, "再滚不许动");
        for (let i = 0; i < 40; ++i)
            mouseWheel(c, 200, 150, 0, -120);
        nearly(c.innerZoom, 0.1, 1e-9, "minZoom 0.1 同理");
        c.destroy();
    }

    function test_wheelStepIsCustomisable() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads
                       + "'; zoomStep: 0.5; maxZoom: 1.2 }");
        waitLoaded(c);
        mouseWheel(c, 200, 150, 0, 120);
        nearly(c.innerZoom, 1, 1e-9, "1 + 0.5 = 1.5 已经越过 maxZoom 1.2 ⇒ 整条不做");
        nearly(c.imgW, 400, 1e-6, "缩放没发生 ⇒ 图的尺寸也不许动");
        c.maxZoom = 1.6;
        mouseWheel(c, 200, 150, 0, 120);
        nearly(c.innerZoom, 1.5, 1e-9, "门槛放宽到 1.6 ⇒ 同样这一步就生效");
        nearly(c.imgW, 600, 1e-6);
        c.destroy();
    }

    // ---------------- 受控 rotate / zoom（getDerivedStateFromProps :120-181）----------------

    function test_controlledRotateTurnsAboutBoxCenter() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        mousePress(c, 20, 20);              // 先把图心挪开，绕框心转才看得出
        mouseMove(c, 50, 40);
        mouseRelease(c, 50, 40);
        nearly(c.imgCX, 230, 1e-6);
        nearly(c.imgCY, 170, 1e-6);
        c.rotate = 90;
        nearly(c.innerRotate, 90);
        nearly(c.imgCX, 180, 1e-6, "(30,−20) 绕 (200,−150) 转 90° ⇒ (−20,−30) ⇒ 180");
        nearly(c.imgCY, 180, 1e-6);
        compare(part(c, "cropperImage").rotation, 90, "画面上那张图也要真的转");
        compare(part(c, "cropperViewImage").rotation, 90, "框里亮图那层同步转");
        c.destroy();
    }

    function test_controlledZoomNeedsNoRotate() {
        // 官方 :153 写的是 `!isUndefined(newRotate) && newZoom !== zoom` ⇒
        // 只改 zoom 不改 rotate 时那条分支整块不生效。端口按「官方 bug 只记录不抄」独立生效。
        const c = make("Cropper { width: 300; height: 150; src: '" + quads + "' }");
        waitLoaded(c);
        c.zoom = 2;
        nearly(c.innerZoom, 2, 1e-9);
        compare(c.imgW, 600, "图宽 = 300/1×2");
        compare(c.imgH, 300);
        compare(c.imgCX, 150, "缩放中心是框心，框心与图心重合 ⇒ 中心不动");
        compare(c.imgCY, 75);
        c.destroy();
    }

    function test_controlledZoomIsAbsolute() {
        // 受控 zoom 是「相对适配档的绝对倍数」，不是「在当前显示尺寸上再乘一次」⇒
        // 式子里必须除回旧的 innerZoom。先滚轮缩到 1.5 再给 zoom = 2 才分得开这两种读法。
        const c = make("Cropper { width: 300; height: 150; src: '" + quads + "' }");
        waitLoaded(c);
        for (let i = 0; i < 5; ++i)
            mouseWheel(c, 150, 75, 0, 120);
        nearly(c.innerZoom, 1.5, 1e-9, "滚轮五档 = 0.5");
        compare(c.imgW, 450);
        c.zoom = 2;
        nearly(c.innerZoom, 2, 1e-9);
        nearly(c.imgW, 600, 1e-6, "450/1.5×2 = 600，不是 450×2 = 900");
        nearly(c.imgH, 300, 1e-6);
        c.destroy();
    }

    function test_controlledBeforeLoadIsIgnored() {
        // 读不到像素的那张源永远进不了 loaded ⇒ 受控值只攒着，不落地
        const c = make("Cropper { width: 300; height: 150; src: 'file:///nonexistent/x.png'"
                       + "; rotate: 45; zoom: 2 }");
        wait(200);
        compare(c.loaded, false, "坏源不该把状态推到已加载");
        nearly(c.innerRotate, 0, 1e-9, ":124 那句 `if (!loaded) return null`");
        nearly(c.innerZoom, 1, 1e-9);
        nearly(c.imgW, 0, 1e-9, "没有尺寸可变换");
        c.destroy();
    }

    // ---------------- 裁切结果几何（getCropperCanvas :795-818）----------------

    function test_cropGeometryAtRest() {
        const c = makeQuads();
        waitLoaded(c);
        const g = c.cropGeometry();
        compare(g.containerWidth, 200, "rotate 0 ⇒ 外接矩形就是原图");
        compare(g.containerHeight, 100);
        compare(g.cropLeft, 50, "(框左 75 − 外接左 0) / realZoom 1.5");
        compare(g.cropTop, 0);
        compare(g.cropWidth, 100, "框宽 150 / 1.5");
        compare(g.cropHeight, 100);
        compare(c.realZoom, 1.5, "realZoom = innerZoom × fitScale");
        c.destroy();
    }

    function test_cropGeometryFollowsZoomAndMove() {
        const c = makeQuads();
        waitLoaded(c);
        c.zoom = 2;                          // 受控缩放，中心是框心 (150,75)
        const g = c.cropGeometry();
        nearly(c.realZoom, 3, 1e-9);
        nearly(g.cropWidth, 50, 1e-6, "框宽不变 ⇒ 原图像素里只占 150/3");
        nearly(g.cropHeight, 50, 1e-6);
        mousePress(c, 10, 10);               // 拖图右移 50
        mouseMove(c, 60, 10);
        mouseRelease(c, 60, 10);
        nearly(c.imgCX, 200, 1e-6);
        const g2 = c.cropGeometry();
        // 外接宽 = 200 × realZoom 3 = 600 ⇒ 外接左 = 200 − 300 = −100 ⇒ (75 + 100)/3
        nearly(g2.cropLeft, 175 / 3, 1e-6, "图往右挪 ⇒ 框在原图里取到的那块往左移");
        c.destroy();
    }

    function test_cropGeometryRotatesContainer() {
        const c = makeQuads();
        waitLoaded(c);
        c.rotate = 90;
        const g = c.cropGeometry();
        nearly(g.containerWidth, 100, 1e-6, "转 90° 后外接矩形宽高对调");
        nearly(g.containerHeight, 200, 1e-6);
        nearly(g.cropWidth, 100, 1e-6, "框宽 / realZoom 与旋转无关");
        nearly(g.cropLeft, 0, 1e-6, "外接宽 100×1.5 = 150 = 框宽 ⇒ 正好贴着左边");
        nearly(g.cropTop, 50, 1e-6, "外接高 300 比容器高 ⇒ 取的是中间那 100 行");
        c.destroy();
    }

    // ---------------- 裁切结果像素（C++ 那一段）----------------

    // 把结果 URL 挂到一只等大的 Image 上，好按 1:1 读像素；底下垫一层纯黑，
    // 这样「结果图自身带 alpha」那一档也能从合成后的读数里看出来
    function showResult(url, side) {
        const host = make("Item { width: " + side + "; height: " + side + "\n"
                          + "Rectangle { anchors.fill: parent; color: 'black' }\n"
                          + "Image { objectName: 'result'; anchors.fill: parent"
                          + "; source: u; property url u } }");
        const img = part(host, "result");
        img.u = url;
        tryCompare(img, "status", Image.Ready, 100, 3000);
        wait(50);
        const shot = testCase.grabImage(host);
        verify(shot !== undefined, "offscreen 下也要能读到结果图的像素");
        return { host: host, image: img, shot: shot };
    }

    function test_cropResultIsTheMiddleSquare() {
        const c = makeQuads();
        waitLoaded(c);
        const url = c.cropToUrl();
        verify(url.indexOf("image://semi-cropper/") === 0, "结果走自建 provider：" + url);
        const r = showResult(url, 100);
        compare(r.image.sourceSize.width, 100, "裁出来 100×100 个原图像素");
        compare(r.image.sourceSize.height, 100);
        compare(r.shot.red(25, 25), 255, "左上那块是原图的红（x 50..100、y 0..50）");
        compare(r.shot.green(25, 25), 0);
        compare(r.shot.green(75, 25), 255, "右上是绿");
        compare(r.shot.red(75, 25), 0);
        compare(r.shot.blue(25, 75), 255, "左下是蓝");
        compare(r.shot.red(75, 75), 255, "右下是白");
        compare(r.shot.green(75, 75), 255);
        compare(r.shot.blue(75, 75), 255);
        c.destroy();
        r.host.destroy();
    }

    function test_cropResultScalesWithZoom() {
        const c = makeQuads();
        waitLoaded(c);
        c.zoom = 2;
        const g = c.cropGeometry();
        nearly(g.cropWidth, 50, 1e-6, "放大两倍 ⇒ 同一块框只取到一半原图像素");
        nearly(g.cropLeft, 75, 1e-6, "缩放中心是框心 ⇒ 取的那块往中间收");
        nearly(g.cropTop, 25, 1e-6);
        const r = showResult(c.cropToUrl(), 50);
        compare(r.image.sourceSize.width, 50);
        // 取的是自然坐标 x 75..125、y 25..75 ⇒ 四色边界正好落在结果的 (25,25)
        compare(r.shot.red(12, 12), 255);
        compare(r.shot.green(12, 12), 0);
        compare(r.shot.green(38, 12), 255, "右上绿");
        compare(r.shot.red(38, 12), 0);
        compare(r.shot.blue(12, 38), 255, "左下蓝");
        compare(r.shot.red(38, 38), 255, "右下白");
        c.destroy();
        r.host.destroy();
    }

    function test_cropFillOutsideImage() {
        // 转 45° + 缩到 0.5 ⇒ 取的那块盖住外接矩形的四角，图外的角是 fill
        const c = make("Cropper { width: 300; height: 150; src: '" + quads
                       + "'; fill: '#ff00ff' }");
        waitLoaded(c);
        c.rotate = 45;
        c.zoom = 0.5;
        const g = c.cropGeometry();
        nearly(g.cropWidth, 200, 1e-2, "缩到 0.5 ⇒ 一块框取到 200×200 个自然像素");
        const r = showResult(c.cropToUrl(), 200);
        compare(r.shot.red(10, 10), 255, "外接矩形的角在菱形外 ⇒ fill 的品红");
        compare(r.shot.green(10, 10), 0);
        compare(r.shot.blue(10, 10), 255);
        verify(r.shot.green(90, 90) !== 0 || r.shot.blue(90, 90) !== 255,
               "菱形中心那一块是图上的颜色，不许整张都是 fill");
        c.destroy();
        r.host.destroy();
    }

    function test_cropSemiTransparentFillIsNotDoubleBlended() {
        // 上游那一步是 putImageData —— **整像素替换**，不是合成。fill 是半透明时，
        // 「外接画布先铺 fill」与「结果画布先铺 fill」只能留一层：
        // 0.5 的品红压在黑底上读出来是 128，叠两层就是 191。
        const c = make("Cropper { width: 300; height: 150; src: '" + quads
                       + "'; fill: " + '"#80ff00ff"' + " }");
        waitLoaded(c);
        c.rotate = 45;
        c.zoom = 0.5;
        const r = showResult(c.cropToUrl(), 200);
        const corner = r.shot.red(10, 10);
        verify(Math.abs(corner - 128) <= 8, "只许有一层 fill：实得 " + corner);
        compare(r.shot.green(10, 10), 0);
        c.destroy();
        r.host.destroy();
    }

    function test_cropNoIntersectionIsPureFill() {
        // 把图拖到与外接矩形完全不相交 ⇒ 上游那条分支返回一张纯 fill
        const c = make("Cropper { width: 300; height: 150; src: '" + quads
                       + "'; fill: '#00ff00' }");
        waitLoaded(c);
        mousePress(c, 10, 10);              // 框（75..225）之外 ⇒ 落在遮罩上
        mouseMove(c, 290, 10);
        mouseRelease(c, 290, 10);
        const g = c.cropGeometry();
        verify(g.cropLeft + g.cropWidth < 0,
               "先确认落在那条「没有交集」的分支上：cropLeft=" + g.cropLeft);
        const r = showResult(c.cropToUrl(), 100);
        compare(r.shot.green(50, 50), 255, "整张都是 fill");
        compare(r.shot.red(50, 50), 0);
        compare(r.shot.blue(50, 50), 0);
        c.destroy();
        r.host.destroy();
    }

    function test_cropTruncatesFractionalSize() {
        // 上游 `canvas.width = relativeWidth` 是往 unsigned long 截断的（100.67 ⇒ 100，不是 101）
        const c = make("Cropper { width: 300; height: 151; src: '" + quads + "' }");
        waitLoaded(c);
        const g = c.cropGeometry();
        verify(g.cropWidth > 100.5 && g.cropWidth < 101,
               "先要落在「四舍五入会进一位」的档上：" + g.cropWidth);
        const r = showResult(c.cropToUrl(), 100);
        compare(r.image.sourceSize.width, 100, "100.67 ⇒ 100");
        c.destroy();
        r.host.destroy();
    }

    function test_cropResultRotatesClockwise() {
        // CSS 与 QPainter 的正角都是顺时针，两边同一口径。转 90° 后：
        // 结果 (rx,ry) ← 外接 (rx, ry+50) ← 源 (100 + (ry+50-100)... ) 手算见下
        const c = makeQuads();
        waitLoaded(c);
        c.rotate = 90;
        const g = c.cropGeometry();
        nearly(g.cropLeft, 0, 1e-6);
        nearly(g.cropTop, 50, 1e-6);
        const r = showResult(c.cropToUrl(), 100);
        compare(r.image.sourceSize.width, 100);
        // 源点 (sx,sy) 转 90° 后落在容器 (100−sy, sx)，结果取的是容器 y 50..150 那一条
        // ⇒ 结果 (rx,ry) 读的是源 (ry+50, 100−rx)。四个象限因此整块换位：
        // 红（源左上）转到结果的右上，蓝（源左下）转到结果的左上。
        compare(r.shot.blue(25, 25), 255, "结果左上是源里的蓝");
        compare(r.shot.red(25, 25), 0);
        compare(r.shot.red(25, 75), 255, "结果左下是白");
        compare(r.shot.blue(25, 75), 255);
        compare(r.shot.red(75, 25), 255, "结果右上是红（顺时针）");
        compare(r.shot.green(75, 25), 0);
        compare(r.shot.green(75, 75), 255, "结果右下是绿");
        compare(r.shot.red(75, 75), 0);
        c.destroy();
        r.host.destroy();
    }

    function test_cropToImageHonoursDeclaredNaturalSize() {
        // C++ 那一段画源图时用的是「QML 报的原始尺寸」，不是解码出来的像素数：
        // SVG / @2x 位图两者不等，只有按声明尺寸归一，两边算好的几何才对得上。
        // 这里把 200×100 的夹具声明成 400×400 ⇒ 外接矩形 400×400，取 (300,0,100,100) 那一块
        // 落在源里的右上象限（绿）。不归一时外接只有 200 宽 ⇒ 300 已经在图外，整张是空。
        const img = CropperRuntime.cropToImage(Qt.url("qrc:/tests/crop_quads.png"),
                                               400, 400, 300, 0, 100, 100, 0, "transparent");
        const r = showResult(CropperRuntime.putImage(img), 100);
        compare(r.image.sourceSize.width, 100);
        compare(r.shot.green(50, 50), 255, "声明尺寸生效 ⇒ 这一块取到的是源里的绿");
        compare(r.shot.red(50, 50), 0);
        r.host.destroy();
    }

    // ---------------- 实时预览（renderPreview / updatePreview :243-306）----------------

    function test_previewKeepsInitSize() {
        const c = makeQuads();
        waitLoaded(c);
        const host = make("Item { objectName: 'pv'; width: 100; height: 200 }");
        c.preview = host;
        wait(50);
        const img = part(host, "cropperPreviewImage");
        verify(img !== null, "preview 那一项里要挂出一张 Image");
        // 100 < 200 ⇒ zoom = 100/150，tempHeight = 100 ≤ 200 ⇒ 容器高被改成 100
        nearly(img.width, 300 * (100 / 150), 1e-3, "imgW × zoom");
        nearly(img.x, (0 - 75) * (100 / 150), 1e-3);
        compare(host.height, 100, "官方 updatePreview 会把容器的 height 改掉");
        compare(host.width, 100);
        nearly(c.previewInitH, 200, 1e-9, "初值要留在 previewContainerInitSize 那一份");
        // 只横着拖图 ⇒ 动的量只有 imgCX，这一拍也要同步（少挂一条 Changed 就停在上一拍）
        mousePress(c, 10, 10);
        mouseMove(c, 30, 10);
        mouseRelease(c, 30, 10);
        nearly(c.imgCX, 170, 1e-6, "先确认只有横坐标动了");
        nearly(c.imgCY, 75, 1e-6);
        wait(50);
        nearly(img.x, (20 - 75) * (100 / 150), 1e-3, "预览那张的 x 要跟着图心走");
        compare(host.height, 100, "第二轮仍然按初值 200 算 ⇒ 不许一路缩下去");
        nearly(img.width, 300 * (100 / 150), 1e-3);
        c.destroy();
        host.destroy();
    }

    function test_previewPlacesImageByBoxOffset() {
        const c = makeQuads();
        waitLoaded(c);
        const host = make("Item { objectName: 'pv'; width: 200; height: 200 }");
        c.preview = host;
        wait(50);
        const img = part(host, "cropperPreviewImage");
        nearly(img.width, 400, 1e-3, "200/150 的 zoom 乘在 imgW 上");
        nearly(img.x, -100, 1e-3, "(imgX − boxX) × zoom = (0 − 75) × 1.33");
        nearly(img.y, 0, 1e-3);
        compare(img.rotation, 0);
        c.rotate = 90;
        wait(50);
        compare(img.rotation, 90, "rotate 也乘到预览那张上");
        c.destroy();
        host.destroy();
    }

    function test_previewHiddenBehindMask() {
        // 官方 renderPreview 只把 overflow:hidden 写在那一个节点上
        const c = makeQuads();
        waitLoaded(c);
        const host = make("Item { objectName: 'pv'; width: 120; height: 120 }");
        compare(host.clip, false, "夹具本来不裁");
        c.preview = host;
        wait(50);
        compare(host.clip, true, "挂上预览就要替宿主开裁切");
        c.destroy();
        host.destroy();
    }

    function test_previewInitSizeIsRecordedAfterLayout() {
        // 「preview: 同一份文件里后面那个项」这一条绑定，会在两项都还没排布好时就评上 ⇒
        // 当场读 preview.width 读到的是 0（gallery「实时预览」那节实测整块 0 高，
        // tests/tmp_cropper_preview_probe.qml 是最小复现）。初值必须等量到正尺寸那一拍再记。
        const host = make("Item { width: 620; height: 340;"
                          + " Column { x: 10; y: 10; spacing: 12;"
                          + " Cropper { id: c; width: 550; height: 300; src: '" + quads
                          + "'; preview: box }"
                          + " Item { id: box; objectName: 'box'; width: 260; height: 200 } } }");
        wait(300);
        const c = host.children[0].children[0];
        const box = part(host, "box");
        verify(c.loaded, "夹具要加载完");
        nearly(c.previewInitW, 260, 1e-6, "记的要是宿主排好之后的尺寸，不是创建那一拍的 0");
        nearly(c.previewInitH, 200, 1e-6);
        // 260 > 200 ⇒ else 档：zoom = 200 / 框高 300 = 0.667，tempWidth = 0.667×300 = 200 ≤ 260
        nearly(box.width, 200, 1e-3, "宿主被改成 contain 之后的尺寸");
        nearly(box.height, 200, 1e-3);
        const img = part(host, "cropperPreviewImage");
        verify(img !== null, "预览那张要挂得出来");
        // 200×100 放进 550×300 ⇒ 走「按宽夹」那一档：imgW = 550、imgH = 275
        nearly(c.imgW, 550, 1e-6);
        nearly(img.width, 550 * (200 / 300), 1e-3);
        host.destroy();
    }

    // ---------------- 容器宽变化（handleResize :171-193）----------------

    function test_containerResizeScalesEverything() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        c.width = 200;
        nearly(c.fitScale, 1, 1e-9, "scale *= 0.5");
        compare(c.imgW, 200);
        compare(c.imgH, 100);
        compare(c.imgCX, 100);
        compare(c.imgCY, 75);
        compare(c.boxW, 150, "框也等比缩");
        compare(c.boxH, 150);
        compare(c.boxCX, 100);
        compare(c.boxCY, 75);
        compare(c.lastContainerWidth, 200);
        c.destroy();
    }

    function test_firstResizeIsSwallowed() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        compare(c.lastContainerWidth, 400, "onCompleted 记一次基准（官方那条首回调在端口不存在）");
        nearly(c.imgW, 400, 1e-6, "没被 ratio=1 之外的数缩过");
        c.destroy();
    }

    function test_resizeBeforeLoadIsSkipped() {
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        c.loaded = false;                    // 假装还没加载完
        c.width = 200;
        compare(c.lastContainerWidth, 400, "!loaded 直接 return，连基准都不更新（官方同）");
        nearly(c.imgW, 400, 1e-6, "等比缩放那一串整块不做");
        c.loaded = true;
        c.destroy();
    }

    function test_layoutIsOnlyFittedOncePerSource() {
        // 换源要重新适配，同一条源反复改宽不许重新适配（那是 handleResize 的活）
        const c = make("Cropper { width: 400; height: 300; src: '" + quads + "' }");
        waitLoaded(c);
        c.width = 200;
        nearly(c.imgW, 200, 1e-6, "改宽走等比缩放，不是重新按新容器铺");
        c.src = tall;
        tryCompare(c, "laidOutSrc", tall, 100, 3000);
        verify(c.laidOutSrc === tall, "换源之后要按新图重新排一次");
        nearly(c.originalW, 270, 1e-6, "270×480 放进 200×300 ⇒ 按高夹");
        nearly(c.imgH, 300, 1e-6);
        nearly(c.imgW, 168.75, 1e-6);
        c.destroy();
    }

    // ---------------- 皮肤：round 那一档 ----------------

    // grabImage 给的是设备像素，按 item 自己的宽高折算一下，cocoa（2x）与 offscreen（1x）同一套点
    function px(shot, item, x, y) {
        const s = shot.width / item.width;
        return { x: Math.round(x * s), y: Math.round(y * s) };
    }

    function test_roundFrameCutsTheBox() {
        const c = makeQuads("shape: 'round'");
        waitLoaded(c);
        wait(150);
        const shot = testCase.grabImage(c);
        verify(shot !== undefined, "offscreen 下要能读到像素");
        const inside = px(shot, c, 140, 70);
        compare(shot.red(inside.x, inside.y), 255, "椭圆内是亮的原图（红）");
        compare(shot.green(inside.x, inside.y), 0);
        const bottom = px(shot, c, 100, 120);
        compare(shot.blue(bottom.x, bottom.y), 255, "左下蓝");
        compare(shot.red(bottom.x, bottom.y), 0);
        // 框 150×150 在容器 (75,0)，椭圆心 (150,75) 半径 (75,75) ⇒ (83,8) 在椭圆外
        const corner = px(shot, c, 83, 8);
        const r = shot.red(corner.x, corner.y);
        const g = shot.green(corner.x, corner.y);
        const b = shot.blue(corner.x, corner.y);
        verify(Math.abs(r - 115) <= 3 && Math.abs(g - 13) <= 3 && Math.abs(b - 16) <= 3,
               "椭圆外那圈 = 遮罩色压在图上（实测 115,13,16），不许还是红的；实得 "
               + r + "," + g + "," + b);
        verify(Theme.current.colorOverlayBg.a > 0, "遮罩本身得是半透明，否则这档判断没有意义");
        c.destroy();
    }

    function test_rectShapeKeepsSquareView() {
        const c = makeQuads();
        waitLoaded(c);
        wait(150);
        const shot = testCase.grabImage(c);
        verify(shot !== undefined);
        const corner = px(shot, c, 83, 8);
        compare(shot.red(corner.x, corner.y), 255, "rect 档框的四角也是亮的（只有 round 才裁）");
        compare(part(c, "cropperViewRoundFrame").visible, false);
        c.destroy();
    }

    function test_roundRectIsRoundToo() {
        // 官方那条判断是 shape.includes('round') ⇒ roundRect 也吃 50%，是个圆（坑 112）
        const c = makeQuads("shape: 'roundRect'");
        waitLoaded(c);
        wait(150);
        const shot = testCase.grabImage(c);
        verify(shot !== undefined);
        const corner = px(shot, c, 83, 8);
        verify(Math.abs(shot.red(corner.x, corner.y) - 115) <= 3,
               "roundRect 的四角同样被裁掉");
        compare(part(c, "cropperBoxOutline").radius, 0,
                "但框那一层是严格等于 'round' ⇒ 环仍是方的");
        c.destroy();
    }

    function test_roundOutlineFollowsShape() {
        const c = makeQuads("shape: 'round'");
        waitLoaded(c);
        // 环那一层比框外扩 1px（anchors.margins: -1）⇒ 圆环半径跟着外框走
        nearly(part(c, "cropperBoxOutline").radius, c.boxW / 2 + 1, 1e-6,
               "index.tsx:266 那条类名在框这一层也生效 ⇒ outline 变圆");
        c.shape = "rect";
        compare(part(c, "cropperBoxOutline").radius, 0);
        c.destroy();
    }

    function test_cropperBoxStyleColors() {
        const c = makeQuads("cropperBoxStyle: ({backgroundColor: '#0a0b0c'})");
        waitLoaded(c);
        compare(part(c, "cropperBoxBackground").color, Qt.rgba(10 / 255, 11 / 255, 12 / 255, 1),
                "cropperBoxStyle 展开在框那一层 ⇒ 底色那条键要落地");
        c.cropperBoxStyle = ({outlineColor: "#123456"});
        compare(part(c, "cropperBoxOutline").border.color, Qt.rgba(18 / 255, 52 / 255, 86 / 255, 1),
                "官方那条 1px 是 outline ⇒ 能盖住它的键是 outlineColor（demo 用的就是这条），不是 borderColor");
        c.cropperBoxStyle = ({borderColor: "#abcdef"});
        compare(part(c, "cropperBoxOutline").border.color, Theme.current.colorPrimary,
                "borderColor 在官方那里改不动 outline ⇒ 端口也不认它");
        c.destroy();
    }

    // ---------------- 与官方一致的两条「不落地」 ----------------

    function test_deadPropsDoNotChangeGeometry() {
        const plain = makeQuads();
        waitLoaded(plain);
        const dressed = makeQuads("imgProps: ({className: 'x', alt: 'y'})"
                                  + "; cropperBoxCls: 'my-box'; className: 'my-crop'"
                                  + "; style: ({backgroundColor: 'red'})");
        waitLoaded(dressed);
        compare(dressed.boxW, plain.boxW, "这四条官方只喂给 DOM，端口收了不产出差异");
        compare(dressed.imgH, plain.imgH);
        plain.destroy();
        dressed.destroy();
    }
}
