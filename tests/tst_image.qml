import QtQuick
import QtTest
import Semi

// Image / ImagePreview。规格照 packages/semi-ui/image/{image.tsx,preview.tsx,previewInner.tsx,
// previewHeader.tsx,previewFooter.tsx,previewImage.tsx,list-context…} 与
// packages/semi-foundation/image/{imageFoundation,previewFoundation,previewInnerFoundation,
// previewFooterFoundation,previewImageFoundation}.ts + image/{image.scss,variables.scss,
// animation.scss,constants.ts}；栅格那套不在这里（是 grid 组件的事）。
//
//   · ImageProps（interface.tsx:16-30，缺省 image.tsx:37-41）：preview **true**、src / alt /
//     placeholder / fallback 都没缺省。三态：loading 盖 -status（默认 Skeleton.Image）、
//     success **什么都不画**（image.tsx:215）、error 盖 -status（默认 upload_error 24px）
//     且那张 img 是 opacity 0（image.scss:38-40，仍占位仍吃点击）。
//   · placeholder / fallback 都是 `{x ? … : 默认}` 的真值判断 ⇒ 空串等于没给。
//     fallback 给字符串是 100%×100% 的 img（image.tsx:142）。
//   · 能预览时只有 cursor: zoom-in（:34-36，条件 preview && 成功，**组内也算**）；
//     官方**没有悬停遮罩**（renderMask :168-173 从未被调用、semi-image-mask* 无样式）。
//   · 点开的判定（imageFoundation.ts:15-30）只看 preview 真值与在不在组里，**不看加载成功**；
//     而 canPreview（image.tsx:183）要求成功 ⇒ 单张点坏图不开、组里点坏图照样开。
//   · 组内下标按「preview 真值筛过之后」重排（preview.tsx:161-196）；
//     finalSrcList = src 数组 + children 那份（:207-208）。
//   · 预览层：z-index 1070、底 overlay-bg、header 60 / 内边距 24 / × 30×30（hover 才给
//     rgba(0,0,0,.75)）、footer 高 48 圆角 6 底 rgba(0,0,0,.75) 距底 16 居中、页码 16/22
//     左右 12、滑杆宽 132 内边距 16 轨 2 手柄 16、分割线 rgba(255,255,255,.5) 左右 16 高 20、
//     两侧箭头 40×40 圆、左右 24、glyph 20。
//   · footer 顺序（previewFooter.tsx:256-271）：chevron_left · 页码 · chevron_right · 分割线 ·
//     minus · 滑杆 · plus · 比例 · 分割线 · rotate · download；`-gap`（左 16）在比例与下载上。
//   · 缩放：min 0.1 / max 5 / step 0.1；适配档 = min((容器宽-80)/包围盒宽, (容器高-80)/包围盒高)
//     取两位小数（previewImageFoundation.ts:90-123），包围盒按旋转算（:203-214）；
//     realSize 恒数值 1；滚轮 deltaY<0 是放大且**结果在界内才动**
//     （previewInnerFoundation.ts:99-117）；旋转 ±90 累加、state 不归一（:195-204）。
//   · 翻页取模**不看 infinite**（:151-165），infinite 只管按钮给不给（previewInner.tsx:407-408）。
//   · 三条关闭路径发的信号不一样：遮罩只 onVisibleChange（:119-134，含 5px 容差）、
//     × 与 Esc 各两条（:182-186 / :141-149）。
// 夹具是测试目标资源里的三张已知尺寸的图：qrc:/tests/img_wide.png 480×270、
// img_tall.png 270×480、img_small.png 60×40。用例跑在 900×700 的窗口里。
TestCase {
    id: testCase

    name: "Image"
    when: windowShown
    width: 900
    height: 700

    readonly property string wide: "qrc:/tests/img_wide.png"
    readonly property string tall: "qrc:/tests/img_tall.png"
    readonly property string small: "qrc:/tests/img_small.png"
    readonly property string bad: "file:///nonexistent/definitely-missing.png"

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    // 断言失败会跳过用例末尾的 destroy ⇒ 残留的预览层还会继续抢 Esc 与鼠标
    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "image");
    }

    function part(root, name) {
        return testCase.findChild(root, name);
    }

    function spyOn(target, signalName) {
        const spy = Qt.createQmlObject("import QtTest; SignalSpy {}", testCase, "imagespy");
        spy.target = target;
        spy.signalName = signalName;
        return spy;
    }

    // 等一张图真的加载完（Image 是异步的，offscreen 也要下一帧）。
    // tryCompare / tryVerify 在这版 Qt 里**返回 undefined** ⇒ 不能包进 verify()，
    // 只能先让它们轮询，再自己断一次（本文件所有等待都走这两个助手）
    function waitLoaded(view) {
        tryCompare(view, "loadStatus", "success");
        compare(view.loadStatus, "success", "夹具图要能加载成功");
        return view;
    }

    function waitError(view) {
        tryCompare(view, "loadStatus", "error");
        compare(view.loadStatus, "error", "坏路径要落到 error");
        return view;
    }

    function waitTrue(fn, message) {
        tryVerify(fn, 1500);
        verify(fn(), message);
    }

    // 开一张自己带预览层的图，并返回那个 Inner
    function openInner(qml) {
        const view = waitLoaded(make(qml));
        const inner = part(view, "imageOwnPreview");
        verify(inner !== null, "组外的图自己要有一张预览层");
        waitTrue(function () { return inner.naturalSize.width > 0; }, "预览层里那张图要加载完");
        return inner;
    }

    // ---------------- Image：属性面与三态 ----------------

    function test_officialPropDefaults() {
        const view = make("ImageView {}");
        compare(view.preview, true, "image.tsx:40 defaultProps preview: true");
        compare(view.src.toString(), "");
        compare(view.alt, "");
        compare(view.placeholder, undefined);
        compare(view.fallback, undefined);
        compare(view.loadStatus, "loading", "官方 state 初值就是 loading");
        compare(view.previewVisible, false);
        compare(view.inGroup, false);
        compare(view.isImageView, true);
        view.destroy();
    }

    function test_loadingCoversWithStatusBox() {
        const view = make("ImageView { width: 200; height: 120 }");
        compare(part(view, "imageOverlay").visible, true);
        compare(part(view, "imageStatus").color, Theme.current.colorFill0,
            "-status 的底是 fill-0");
        compare(part(view, "imageDefaultPlaceholder").active, true,
            "没给 placeholder 时默认那一份是 Skeleton.Image");
        compare(part(view, "imageLoading").visible, true);
        compare(part(view, "imageError").visible, false);
        view.destroy();
    }

    function test_successDrawsNothingOnTop() {
        const view = openImageForSuccess();
        compare(view.loadStatus, "success");
        compare(part(view, "imageOverlay").visible, false,
            "image.tsx:215：只有非成功态才画 overlay");
        compare(part(view, "imageThumb").opacity, 1);
        view.destroy();
    }

    function test_implicitSizeFollowsNaturalSize() {
        // 官方没给 width / height 时是 img 的固有尺寸（外层 inline-block 跟着缩）
        const view = make(`ImageView { src: "${testCase.wide}" }`);
        waitLoaded(view);
        compare(view.implicitWidth, 480);
        compare(view.implicitHeight, 270);
        view.destroy();
    }

    function openImageForSuccess() {
        return waitLoaded(make(`ImageView { width: 200; height: 120; src: "${testCase.wide}" }`));
    }

    function test_errorKeepsImageInPlace() {
        const view = make(`ImageView { width: 200; height: 120; src: "${testCase.bad}" }`);
        waitError(view);
        compare(part(view, "imageThumb").opacity, 0,
            "-img-error 是 opacity: 0，不是不画（image.scss:38-40）");
        compare(part(view, "imageOverlay").visible, true);
        compare(part(view, "imageError").visible, true);
        const icon = part(view, "imageErrorIcon");
        compare(icon.visible, true);
        compare(icon.name, "upload_error", "默认那一份是 IconUploadError");
        compare(icon.size, 24, "$width-icon-extra-large");
        compare(icon.color, Theme.current.colorDisabledText);
        view.destroy();
    }

    function test_fallbackStringIsStretchedImage() {
        const view = make(`ImageView { width: 200; height: 120; src: "${testCase.bad}";`
            + ` fallback: "${testCase.wide}" }`);
        waitError(view);
        const img = part(view, "imageFallbackImage");
        compare(img.visible, true);
        compare(img.source.toString(), testCase.wide);
        compare(img.fillMode, Image.Stretch, "官方是 <img width:100% height:100%>");
        compare(img.width, 200);
        compare(img.height, 120);
        compare(part(view, "imageErrorIcon").visible, false);
        view.destroy();
    }

    function test_emptyFallbackFallsBackToDefaultIcon() {
        // 官方 `{fallback ? … : 默认}` ⇒ 空串是「没给」，不是「给一张空图」
        const view = make(`ImageView { width: 120; height: 80; src: "${testCase.bad}";`
            + " fallback: '' }");
        waitError(view);
        compare(part(view, "imageFallbackImage").visible, false);
        compare(part(view, "imageErrorIcon").visible, true);
        view.destroy();
    }

    function test_placeholderTextAndNode() {
        const textForm = make(`ImageView { width: 120; height: 80; placeholder: '载入中' }`);
        compare(part(textForm, "imagePlaceholderText").text, "载入中");
        compare(part(textForm, "imageDefaultPlaceholder").active, false,
            "给了就不画默认那一份");
        textForm.destroy();

        const nodeForm = make(`ImageView { width: 120; height: 80;
            placeholder: Component { Rectangle { objectName: 'ph'; width: 30; height: 12
                color: 'transparent' } } }`);
        compare(part(nodeForm, "imagePlaceholderNode").active, true);
        compare(part(nodeForm, "imageDefaultPlaceholder").active, false);
        verify(part(part(nodeForm, "imagePlaceholderNode"), "ph") !== null);
        nodeForm.destroy();
    }

    // ---------------- Image：光标与点击 ----------------

    function test_cursorOnlyWhenPreviewAndSuccess() {
        const view = make(`ImageView { width: 120; height: 80; src: "${testCase.wide}" }`);
        waitLoaded(view);
        compare(view.showPreviewCursor, true);
        compare(part(view, "imageCursor").cursorShape, Qt.PointingHandCursor);
        view.preview = false;
        compare(view.showPreviewCursor, false);
        compare(part(view, "imageCursor").cursorShape, Qt.ArrowCursor);
        view.destroy();
    }

    function test_clickFiresEvenWhenPreviewOff() {
        const view = waitLoaded(make(`ImageView { width: 200; height: 120; preview: false;`
            + ` src: "${testCase.wide}" }`));
        const clicked = spyOn(view, "clicked");
        const visibleChange = spyOn(view, "previewVisibleChangeRequested");
        mouseClick(part(view, "imageThumb"), 60, 40);
        wait(60);
        compare(clicked.count, 1, "官方 onClick 挂在 img 上");
        compare(visibleChange.count, 0, "preview 关着就不开（imageFoundation.ts:18-20）");
        compare(view.previewVisible, false);
        view.destroy();
    }

    function test_clickOnFailedSingleImageOpensNothing() {
        // handleClick 不看加载状态，但 canPreview 看 ⇒ 单张点坏图什么也不会发生
        const view = make(`ImageView { width: 120; height: 80; src: "${testCase.bad}" }`);
        waitError(view);
        const clicked = spyOn(view, "clicked");
        const visibleChange = spyOn(view, "previewVisibleChangeRequested");
        mouseClick(part(view, "imageSurface"), 60, 40);
        wait(60);
        compare(clicked.count, 1);
        // 官方 handleClick 只看 preview 真值（imageFoundation.ts:15-30）⇒ 通知照发；
        // 但 canPreview 是 false（image.tsx:183）⇒ 那层预览压根没画，什么都看不见
        compare(visibleChange.count, 1, "通知发（与官方同）");
        compare(view.canPreview, false);
        compare(part(view, "imageOwnPreview").visible, false, "预览层没画 ⇒ 屏幕上什么都没开");
        view.destroy();
    }

    function test_clickOpensOwnPreviewAndNotifies() {
        const view = make(`ImageView { width: 200; height: 120; src: "${testCase.wide}" }`);
        waitLoaded(view);
        const visibleChange = spyOn(view, "previewVisibleChangeRequested");
        mouseClick(part(view, "imageThumb"), 100, 60);
        wait(60);
        compare(visibleChange.count, 1);
        compare(visibleChange.signalArguments[0][0], true);
        compare(view.previewVisible, true, "布尔档 preview 是非受控的，自己记");
        view.destroy();
    }

    function test_objectFormVisibleIsControlled() {
        // 官方 image.tsx:74-79 + imageFoundation.ts:48-62：对象档给了 boolean visible 就受控
        const view = make(`ImageView { width: 200; height: 120; src: "${testCase.wide}";`
            + ` preview: ({ visible: false }) }`);
        waitLoaded(view);
        const visibleChange = spyOn(view, "previewVisibleChangeRequested");
        mouseClick(part(view, "imageThumb"), 100, 60);
        wait(60);
        compare(visibleChange.count, 1, "照样发通知");
        compare(view.previewVisible, false, "但状态归调用方");
        compare(view.previewVisibleInternal, false, "自己那份没动");
        view.preview = ({ visible: true });
        wait(60);
        compare(view.previewVisible, true);
        view.destroy();
    }

    function test_objectFormSrcCanOpenMultiImage() {
        // preview.src 可以是数组 ⇒ 一张图也能开出可翻页的预览（image.tsx:185）
        const view = make(`ImageView { width: 200; height: 120; src: "${testCase.wide}";`
            + ` preview: ({ visible: true, src: ['${testCase.wide}', '${testCase.tall}'] }) }`);
        waitLoaded(view);
        const inner = part(view, "imageOwnPreview");
        compare(inner.sourceCount, 2);
        compare(inner.showNext, true);
        compare(part(inner, "imagePreviewPage").text, "1/2");
        view.destroy();
    }

    function test_cursorStaysPlainWhileBroken() {
        // showPreviewCursor 的条件是 preview && 成功（image.tsx:184）—— 坏图不给 zoom-in
        const view = make(`ImageView { width: 120; height: 80; src: "${testCase.bad}" }`);
        waitError(view);
        compare(view.previewOn, true);
        compare(view.showPreviewCursor, false);
        compare(part(view, "imageCursor").cursorShape, Qt.ArrowCursor);
        view.destroy();
    }

    // ---------------- ImagePreview：组 ----------------

    function test_groupChildPreviewSrcOverridesOwnSrc() {
        // 组里收的是每张「preview.src ?? src」那一份（preview.tsx:161-196 收的就是这个）
        const group = make(`ImagePreview {
            ImageView { width: 120; height: 80; src: "${testCase.wide}" }
            ImageView { width: 120; height: 80; src: "${testCase.small}";`
            + ` preview: ({ src: "${testCase.tall}" }) }
        }`);
        wait(60);
        const list = group.sourceList;
        compare(list.length, 2);
        compare(String(list[0]), testCase.wide);
        compare(String(list[1]), testCase.tall,
            "第二张进组的是它 preview.src 那份，不是它自己显示的缩略图");
        group.destroy();
    }

    function test_controlledIndexStaysWhereTheCallerSays() {
        const group = make(`ImagePreview {
            open: true
            currentIndex: 0

            ImageView { width: 120; height: 80; src: "${testCase.wide}" }
            ImageView { width: 120; height: 80; src: "${testCase.tall}" }
        }`);
        wait(60);
        const changed = spyOn(group, "changed");
        group.childClicked(1);
        wait(60);
        compare(changed.count, 1, "通知照发");
        compare(group.shownIndex, 0, "受控时组自己那份不动，下标归调用方");
        compare(group.innerIndex, 0);
        group.destroy();
    }

    function test_groupIndexSkipsPreviewFalse() {
        const group = make(`ImagePreview {
            ImageView { width: 120; height: 80; src: "${testCase.wide}" }
            ImageView { width: 120; height: 80; src: "${testCase.wide}"; preview: false }
            ImageView { width: 120; height: 80; src: "${testCase.wide}" }
        }`);
        wait(60);
        compare(group.childCount, 2, "preview 为假的不进组（preview.tsx:161-196）");
        const images = group._groupImages;
        compare(images[0].groupIndex, 0);
        compare(images[1].groupIndex, 1, "第三张的 imageID 是 1 而不是 2");
        compare(images[1].inGroup, true);
        group.destroy();
    }

    function test_groupSourceOrderIsSrcArrayThenChildren() {
        const group = make(`ImagePreview {
            src: ['${testCase.tall}']

            ImageView { width: 120; height: 80; src: "${testCase.wide}" }
            ImageView { width: 120; height: 80; src: "${testCase.small}" }
        }`);
        wait(60);
        const list = group.sourceList;
        compare(list.length, 3, "finalSrcList = src 数组 + children 那份");
        compare(String(list[0]), testCase.tall);
        compare(String(list[1]), testCase.wide);
        compare(String(list[2]), testCase.small);
        group.destroy();
    }

    function test_childClickSetsIndexAndNotifies() {
        const group = make(`ImagePreview {
            ImageView { objectName: 'first'; width: 120; height: 80; src: "${testCase.wide}" }
            ImageView { objectName: 'second'; width: 120; height: 80; src: "${testCase.tall}" }
        }`);
        wait(60);
        const changed = spyOn(group, "changed");
        const visibleChange = spyOn(group, "visibleChangeRequested");
        const second = part(group, "second");
        waitLoaded(second);
        mouseClick(part(second, "imageThumb"), 60, 40);
        wait(60);
        compare(changed.count, 1);
        compare(changed.signalArguments[0][0], 1, "点第二张 ⇒ 下标 1");
        compare(visibleChange.count, 1);
        compare(visibleChange.signalArguments[0][0], true);
        compare(group.shownIndex, 1);
        compare(group.isOpen, true);
        group.destroy();
    }

    function test_controlledOpenKeepsItClosed() {
        const group = make(`ImagePreview {
            open: false

            ImageView { objectName: 'only'; width: 120; height: 80; src: "${testCase.wide}" }
            ImageView { width: 120; height: 80; src: "${testCase.tall}" }
        }`);
        wait(60);
        const visibleChange = spyOn(group, "visibleChangeRequested");
        const only = part(group, "only");
        waitLoaded(only);
        mouseClick(part(only, "imageThumb"), 60, 40);
        wait(60);
        compare(visibleChange.count, 1, "受控时只发通知");
        compare(group.isOpen, false, "开不开归调用方");
        compare(group.innerVisible, false, "自己记的那份也不动");
        group.destroy();
    }

    function test_groupClickOnFailedImageStillOpens() {
        // imageFoundation.ts:15-30 只看 preview 真值；组里点一张坏图照样开（开出是坏的）
        const group = make(`ImagePreview {
            ImageView { objectName: 'broken'; width: 120; height: 80; src: "${testCase.bad}" }
            ImageView { width: 120; height: 80; src: "${testCase.tall}" }
        }`);
        wait(60);
        const broken = part(group, "broken");
        waitError(broken);
        compare(broken.canPreview, false, "自己那张不画");
        const changed = spyOn(group, "changed");
        mouseClick(part(broken, "imageSurface"), 60, 40);
        wait(60);
        compare(changed.count, 1, "组里的路由不看加载状态");
        compare(group.isOpen, true);
        group.destroy();
    }

    function test_standalonePreviewWithSrcOnly() {
        // 「单独使用预览组件」那一节：不给 children，只给 src 数组
        const group = make(`ImagePreview { open: true; src: ['${testCase.wide}',`
            + ` '${testCase.tall}', '${testCase.small}'] }`);
        wait(60);
        const inner = part(group, "imagePreviewInner");
        verify(inner !== null);
        tryVerify(function () { return inner.naturalSize.width > 0; }, 1500); verify(inner.naturalSize.width > 0);
        compare(inner.sourceCount, 3);
        compare(inner.width, 900, "预览层铺满所在容器");
        compare(inner.height, 700);
        compare(inner.currentSource, testCase.wide);
        compare(part(inner, "imagePreviewPage").text, "1/3");
        group.destroy();
    }

    // ---------------- 预览层：缩放 / 旋转 / 比例 ----------------

    function test_adaptationZoomFormula() {
        const inner = openInnerWide();
        // min((900-80)/480, (700-80)/270) = min(1.7083, 2.2963) = 1.71
        verify(Math.abs(inner.zoom - 1.71) < 0.001, "适配档按包围盒算");
        compare(inner.boxWidth, 820, "floor(480 × 1.71)");
        compare(inner.boxHeight, 461, "floor(270 × 1.71)");
        compare(inner.ratio, "adaptation");
        inner.destroy();
    }

    function openInnerWide() {
        return testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true }) }`);
    }

    function test_rotationAffectsAdaptation() {
        const inner = openInnerWide();
        inner.handleRotateLeft();
        wait(60);
        compare(inner.rotation, -90, "旋转是累加的，state 里不归一");
        // 转 90° 后包围盒是 (270, 480) ⇒ min(820/270, 620/480) = 1.29
        verify(Math.abs(inner.zoom - 1.29) < 0.001);
        inner.handleRotateLeft();
        inner.handleRotateLeft();
        inner.handleRotateLeft();
        wait(60);
        compare(inner.rotation, -360, "四次 -90 累到 -360，不折回 0");
        verify(Math.abs(inner.zoom - 1.71) < 0.001, "包围盒按角度算 ⇒ 转满一圈回到原值");
        inner.destroy();
    }

    function test_realSizeRatioIsNumericOne() {
        const inner = openInnerWide();
        inner.adjustRatio();
        wait(60);
        compare(inner.ratio, "realSize");
        verify(Math.abs(inner.zoom - 1) < 0.001, "「原始大小」就是数值 1");
        inner.adjustRatio();
        wait(60);
        compare(inner.ratio, "adaptation");
        verify(Math.abs(inner.zoom - 1.71) < 0.001);
        inner.destroy();
    }

    function test_ratioIconShowsTheActionNotTheState() {
        const inner = openInnerWide();
        compare(part(inner, "footerRatioGlyph").name, "real_size_stroked",
            "当前是适配档 ⇒ 那颗键画的是「切到原始大小」");
        inner.adjustRatio();
        wait(60);
        compare(part(inner, "footerRatioGlyph").name, "window_adaption_stroked");
        inner.destroy();
    }

    function test_initialZoomYieldsToRatioAfterwards() {
        // 官方 _initialZoomApplied 一旦置起，之后的每一次 initializeImage 都回到比例档
        // （previewImageFoundation.ts:108-124）⇒ initialZoom 只在每张图的第一次生效
        const inner = testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true, initialZoom: 2 }) }`);
        verify(Math.abs(inner.zoom - 2) < 0.001, "先吃 initialZoom");
        inner.adjustRatio();
        wait(60);
        verify(Math.abs(inner.zoom - 1) < 0.001, "切到 realSize 就是 1，不再回到 2");
        inner.adjustRatio();
        wait(60);
        verify(Math.abs(inner.zoom - 1.71) < 0.001, "切回适配档按包围盒算");
        inner.destroy();
    }

    function test_coldPreviewStillLandsOnAdaptation() {
        // 预览那张是冷加载（与缩略图不同的一张）⇒ opened 那一刻 originalSize 还是 0。
        // 没有「尺寸未知先不算」那道门，这一趟会把适配档算成 1 并记账，load 那一趟被跳过
        const inner = testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true, src: "${testCase.tall}" }) }`);
        compare(inner.currentSource, testCase.tall);
        verify(Math.abs(inner.zoom - 1.29) < 0.001,
            "270×480 在 900×700 里的适配档 = min(820/270, 620/480) = 1.29");
        verify(Math.abs(inner.boxWidth - 348) < 1, "floor(270 × 1.29)");
        inner.destroy();
    }

    function test_initialZoomMarkerIsPerSourceUnderRotation() {
        // 官方 _initialZoomApplied 置起后，rotation 引起的那次 initializeImage 回到比例档
        // （previewImage.tsx:98-100 → handleWindowResize → initializeImage）
        const inner = testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.tall}";
            preview: ({ visible: true, initialZoom: 2 }) }`);
        verify(Math.abs(inner.zoom - 2) < 0.001, "先吃 initialZoom");
        inner.handleRotateLeft();
        wait(60);
        // 270×480 转 90° 后包围盒是 (480, 270) ⇒ min(820/480, 620/270) = 1.71
        verify(Math.abs(inner.zoom - 1.71) < 0.001,
            "转 90° 后按新的包围盒走适配档，不是回到 2");
        inner.destroy();
    }

    function test_zoomBoundsAndDisabledStates() {
        const inner = openInnerWide();
        inner.setZoomPercent(500);
        wait(60);
        verify(Math.abs(inner.zoom - 5) < 0.001);
        compare(inner.disabledZoomIn, true, "到顶了 + 键该禁用");
        compare(inner.disabledZoomOut, false);
        inner.setZoomPercent(10);
        wait(60);
        verify(Math.abs(inner.zoom - 0.1) < 0.001);
        compare(inner.disabledZoomOut, true);
        inner.setZoomPercent(900);
        wait(60);
        verify(Math.abs(inner.zoom - 5) < 0.001, "超出 max 也夹住");
        inner.destroy();
    }

    // QtTest 的 wheel(dataItem, x, y, buttons, dx, dy)：dy 就是 angleDelta.y
    function wheelAt(target, x, y, dy) {
        // TestCase.mouseWheel(item, x, y, xDelta, yDelta, ...)
        testCase.mouseWheel(part(target, "imagePreviewCanvas"), x, y, 0, dy);
    }

    function test_wheelStepOnlyWhenResultInBounds() {
        const inner = openInnerWide();
        const zoomInSpy = spyOn(inner, "zoomInRequested");
        const zoomOutSpy = spyOn(inner, "zoomOutRequested");
        // angleDelta.y > 0 是向上滚 ⇒ 放大（官方 deltaY < 0 是放大）
        wheelAt(inner, 450, 350, 120);
        wait(60);
        verify(Math.abs(inner.zoom - 1.81) < 0.001, "1.71 + 0.1");
        compare(zoomInSpy.count, 1);
        compare(zoomOutSpy.count, 0);
        wheelAt(inner, 450, 350, -120);
        wheelAt(inner, 450, 350, -120);
        wait(60);
        verify(Math.abs(inner.zoom - 1.61) < 0.001, "两次向下 ⇒ 回到 1.61");
        compare(zoomOutSpy.count, 2);
        inner.destroy();
    }

    function test_wheelAtMaxIsSilent() {
        const inner = openInnerWide();
        inner.setZoomPercent(500);
        wait(60);
        const spy = spyOn(inner, "zoomInRequested");
        wheelAt(inner, 450, 350, 120);
        wait(60);
        compare(spy.count, 0, "结果越界就整条不动（previewInnerFoundation.ts:105-107）");
        verify(Math.abs(inner.zoom - 5) < 0.001);
        inner.destroy();
    }

    function test_initialZoomOverridesRatioOncePerSource() {
        const inner = testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true, src: ['${testCase.wide}', '${testCase.tall}'],
                initialZoom: 2 }) }`);
        verify(Math.abs(inner.zoom - 2) < 0.001, "给了 initialZoom 就不走适配档");
        inner.switchImage("next");
        wait(150);
        tryVerify(function () { return inner.currentSource === testCase.tall; }, 1500); verify(inner.currentSource === testCase.tall);
        wait(200);
        verify(Math.abs(inner.zoom - 2) < 0.001, "换张图再吃一次（每张只一次）");
        inner.destroy();
    }

    // ---------------- 预览层：平移 ----------------

    function test_translateForcedZeroWhenNothingOverflows() {
        const inner = openInnerWide();
        // 适配档下包围盒 820×461 都比容器小 ⇒ 两个轴都拖不动
        inner.translateX = 100;
        inner.translateY = 80;
        inner.clampTranslate();
        wait(60);
        compare(inner.canDragHorizontal, false);
        compare(inner.canDragVertical, false);
        compare(inner.translateX, 0, "拖不动的轴一律归 0（:294-303）");
        compare(inner.translateY, 0);
        inner.destroy();
    }

    function test_translateClampedToHalfOverflow() {
        const inner = openInnerWide();
        inner.setZoomPercent(300);
        wait(60);
        // 3 倍：box 1440×810，容器 900×700 ⇒ 极值 ((1440-900)/2, (810-700)/2) = (270, 55)
        compare(inner.canDragHorizontal, true);
        compare(inner.canDragVertical, true);
        inner.translateX = 500;
        inner.translateY = -300;
        inner.clampTranslate();
        wait(60);
        verify(Math.abs(inner.translateX - 270) < 0.01);
        verify(Math.abs(inner.translateY - -55) < 0.01);
        inner.translateX = -900;
        inner.clampTranslate();
        wait(60);
        verify(Math.abs(inner.translateX - -270) < 0.01);
        inner.destroy();
    }

    // ---------------- 预览层：翻页与按钮可见性 ----------------

    function test_prevNextVisibilityRules() {
        const single = testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true }) }`);
        compare(single.sourceCount, 1);
        compare(single.showPrev, false, "只有一条时两侧都不给");
        compare(single.showNext, false);
        compare(part(single, "imagePreviewPrevIcon").visible, false);
        compare(part(single, "imagePreviewFooterRow").visible, true, "footer 照画");
        single.destroy();

        const many = openGroupPreview();
        compare(many.sourceCount, 3);
        compare(many.showPrev, false, "非循环档在第一页没有「上一张」");
        compare(many.showNext, true);
        many.destroy();
    }

    function openGroupPreview() {
        const group = make(`ImagePreview {
            open: true
            src: ['${testCase.wide}', '${testCase.tall}', '${testCase.small}']
        }`);
        wait(60);
        const inner = part(group, "imagePreviewInner");
        tryVerify(function () { return inner.naturalSize.width > 0; }, 1500); verify(inner.naturalSize.width > 0);
        return inner;
    }

    function test_pagingWrapsRegardlessOfInfinite() {
        const group = make(`ImagePreview {
            open: true
            src: ['${testCase.wide}', '${testCase.tall}', '${testCase.small}']
        }`);
        wait(60);
        const inner = part(group, "imagePreviewInner");
        waitTrue(function () { return inner.naturalSize.width > 0; }, "预览层那张图要加载完");
        compare(inner.infinite, false);
        const spy = spyOn(inner, "changed");
        // 下标走宿主：直接写 inner.currentIndex 会把宿主那条绑定打断（本库的老坑）
        group.childClicked(2);
        wait(60);
        compare(inner.shownIndex, 2, "先站到末条");
        // 官方取模那一步不看 infinite（previewInnerFoundation.ts:151-165）：
        // 按钮在非循环档的末端不显示，但一旦调到这一格，next 照样回到 0
        inner.switchImage("next");
        wait(60);
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], 0, "末条 next 回到 0");
        inner.switchImage("prev");
        wait(60);
        compare(spy.signalArguments[1][0], 2, "首条 prev 回到末条");
        group.destroy();
    }

    function test_indexChangeResetsRotationAndRatio() {
        const inner = openGroupPreview();
        inner.handleRotateLeft();
        inner.adjustRatio();
        wait(60);
        compare(inner.rotation, -90);
        compare(inner.ratio, "realSize");
        inner.switchImage("next");
        wait(60);
        compare(inner.rotation, 0, "换张图 rotation 归 0");
        compare(inner.ratio, "adaptation", "比例档也回 adaptation");
        inner.destroy();
    }

    function test_pageIndicatorFormat() {
        const inner = openGroupPreview();
        compare(part(inner, "imagePreviewPage").text, "1/3");
        inner.switchImage("next");
        wait(60);
        compare(part(inner, "imagePreviewPage").text, "2/3");
        inner.destroy();
    }

    // ---------------- 预览层：三条关闭路径 ----------------

    function openWideInner() {
        return testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true }) }`);
    }

    function test_maskTapOnlyNotifiesVisibleChange() {
        const inner = openWideInner();
        const visibleSpy = spyOn(inner, "visibleChangeRequested");
        const closeSpy = spyOn(inner, "closeRequested");
        // 点在图上不算遮罩（overChrome 挡掉），点左上角那截空白才算
        mouseClick(part(inner, "imagePreviewMask"), 12, 200);
        wait(60);
        compare(visibleSpy.count, 1);
        compare(visibleSpy.signalArguments[0][0], false);
        compare(closeSpy.count, 0, "官方遮罩那一支只发 onVisibleChange");
        inner.destroy();
    }

    function test_clickOnImageIsNotMaskClick() {
        const inner = openWideInner();
        const visibleSpy = spyOn(inner, "visibleChangeRequested");
        // 适配档下那张图铺在中间（box 820×461，居中）⇒ 正中间必然在图上
        const box = part(inner, "imagePreviewImage");
        compare(box.contains(Qt.point(450 - box.x, 350 - box.y)), true, "先确认这点确实落在图上");
        mouseClick(part(inner, "imagePreviewMask"), 450, 350);
        wait(60);
        compare(visibleSpy.count, 0, "点在图上是拖图，不是关预览");
        inner.destroy();
    }

    function test_closeIconAndEscFireBothSignals() {
        const inner = openWideInner();
        const visibleSpy = spyOn(inner, "visibleChangeRequested");
        const closeSpy = spyOn(inner, "closeRequested");
        mouseClick(part(inner, "imagePreviewClose"), 15, 15);
        wait(60);
        compare(visibleSpy.count, 1);
        compare(closeSpy.count, 1, "× 那两支都发（previewInnerFoundation.ts:182-186）");
        keyClick(Qt.Key_Escape);
        wait(60);
        compare(visibleSpy.count, 2);
        compare(closeSpy.count, 2, "Esc 同样两支（:141-149）");
        inner.destroy();
    }

    function test_closeOnEscFalseIgnoresEsc() {
        const inner = testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true, closeOnEsc: false }) }`);
        const closeSpy = spyOn(inner, "closeRequested");
        keyClick(Qt.Key_Escape);
        wait(60);
        compare(closeSpy.count, 0);
        inner.destroy();
    }

    function test_maskClosableFalseIgnoresMask() {
        const inner = testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true, maskClosable: false }) }`);
        const visibleSpy = spyOn(inner, "visibleChangeRequested");
        mouseClick(part(inner, "imagePreviewMask"), 12, 200);
        wait(60);
        compare(visibleSpy.count, 0);
        inner.destroy();
    }

    function test_closableFalseHidesCloseIcon() {
        const inner = testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true, closable: false }) }`);
        compare(part(inner, "imagePreviewClose").visible, false);
        inner.destroy();
    }

    // ---------------- 预览层：度量与 footer 顺序 ----------------

    function test_previewMetrics() {
        const inner = openWideInner();
        compare(inner.zIndex, 1070, "$z-image_preview");
        compare(part(inner, "imagePreviewMask").color, Theme.current.colorOverlayBg);
        const header = part(inner, "imagePreviewHeader");
        compare(header.height, 60);
        compare(header.width, 900);
        const close = part(inner, "imagePreviewClose");
        compare(close.width, 30);
        compare(close.height, 30);
        compare(close.x, 900 - 24 - 30, "header 内边距 24");
        const footer = part(inner, "imagePreviewFooter");
        compare(footer.height, 48);
        compare(footer.radius, 6, "$radius-image_preview_footer = border-radius-medium");
        compare(footer.y + footer.height, 700 - 16, "距底 16");
        verify(Math.abs(footer.x + footer.width / 2 - 450) < 1, "水平居中");
        const slider = part(inner, "imagePreviewSlider");
        compare(slider.width, 132);
        compare(part(slider, "sliderRail").height, 2);
        compare(part(slider, "sliderHandle").width, 16);
        const prevIcon = part(inner, "imagePreviewPrevIcon");
        compare(prevIcon.width, 40);
        compare(prevIcon.x, 24);
        verify(Math.abs(prevIcon.y + 20 - 350) < 1, "竖直居中");
        inner.destroy();
    }

    function test_footerOrderMatchesUpstream() {
        const inner = openGroupPreview();
        const footer = part(inner, "imagePreviewFooter");
        const at = function (name) {
            return part(footer, name).x;
        };
        // previewFooter.tsx:256-271：分割线插在下标 3 与 8
        verify(at("footerPrev") < at("imagePreviewPage"), "chevron_left · 页码");
        verify(at("imagePreviewPage") < at("footerNext"), "· chevron_right");
        verify(at("footerNext") < at("footerDividerFirst"), "· 第一条分割线");
        verify(at("footerDividerFirst") < at("footerZoomOut"), "· minus");
        verify(at("footerZoomOut") < at("imagePreviewSlider"), "· 滑杆");
        verify(at("imagePreviewSlider") < at("footerZoomIn"), "· plus");
        verify(at("footerZoomIn") < at("footerRatio"), "· 比例");
        verify(at("footerRatio") < at("footerDividerSecond"), "· 第二条分割线");
        verify(at("footerDividerSecond") < at("footerRotate"), "· rotate");
        verify(at("footerRotate") < at("footerDownload"), "· download");
        inner.destroy();
    }

    function test_footerGapMargins() {
        const inner = openGroupPreview();
        const footer = part(inner, "imagePreviewFooter");
        const zoomIn = part(footer, "footerZoomIn");
        const ratio = part(footer, "footerRatio");
        const rotate = part(footer, "footerRotate");
        const download = part(footer, "footerDownload");
        const divider = part(footer, "footerDividerSecond");
        compare(ratio.x - (zoomIn.x + zoomIn.width), 16, "比例的 -gap 左距 16");
        compare(divider.x - (ratio.x + ratio.width), 16, "分割线左右各 16");
        compare(divider.width, 1);
        compare(divider.height, 20);
        compare(download.x - (rotate.x + rotate.width), 16, "下载的 -gap 左距 16");
        inner.destroy();
    }

    property Component menuFixture: Component {
        Rectangle { width: 100; height: 30; color: "transparent" }
    }

    property Component titleNodeFixture: Component {
        Rectangle { objectName: "titleNode"; width: 40; height: 10; color: "transparent" }
    }

    function test_customMenuDropsTheShell() {
        // 官方 `-content` 那个类只在没有 renderPreviewMenu 时才加，而 padding / 底色 /
        // 圆角 / 高全在这条类上 ⇒ 自定义整条时那层壳一起没
        const view = make(`ImageView { width: 200; height: 120; src: "${testCase.wide}" }`);
        waitLoaded(view);
        view.preview = ({ visible: true, renderPreviewMenu: testCase.menuFixture });
        wait(60);
        const inner = part(view, "imageOwnPreview");
        tryVerify(function () { return inner.naturalSize.width > 0; }, 1500); verify(inner.naturalSize.width > 0);
        compare(part(inner, "imagePreviewFooterRow").visible, false);
        compare(part(inner, "imagePreviewMenuSlot").active, true);
        compare(part(inner, "imagePreviewFooter").color, Qt.rgba(0, 0, 0, 0),
            "没有 -content 那层底色");
        compare(part(inner, "imagePreviewFooter").radius, 0);
        compare(part(inner, "imagePreviewFooter").height, 30);
        view.destroy();
    }

    function test_headerTitleTextAndNode() {
        const textForm = testCase.openInner(`ImageView {
            width: 200; height: 120; src: "${testCase.wide}";
            preview: ({ visible: true, previewTitle: '详情图' }) }`);
        compare(part(textForm, "imagePreviewTitle").text, "详情图");
        compare(part(textForm, "imagePreviewTitle").color, Theme.current.colorWhite);
        textForm.destroy();

        const nodeForm = make(`ImageView { width: 200; height: 120; src: "${testCase.wide}" }`);
        waitLoaded(nodeForm);
        nodeForm.preview = ({ visible: true, previewTitle: testCase.titleNodeFixture });
        wait(60);
        const nodeInner = part(nodeForm, "imageOwnPreview");
        tryVerify(function () { return nodeInner.naturalSize.width > 0; }, 1500); verify(nodeInner.naturalSize.width > 0);
        compare(part(nodeInner, "imagePreviewTitle").visible, false, "节点档不画那条文字");
        verify(part(nodeInner, "imagePreviewTitleNode").item !== null);
        nodeForm.destroy();
    }

    function test_noEnterExitTransition() {
        // 官方不显示时整棵子树不挂载（previewInner.tsx:413），那条 500ms 用不到 ⇒
        // 端口不开 enter / exit
        const inner = openWideInner();
        compare(inner.enter, null);
        compare(inner.exit, null);
        inner.destroy();
    }
}
