pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as C
import QtQuick.Effects
import "ModalEscStack.js" as EscStack

// 预览层本体。官方那四个文件（semi-ui/image/{previewInner,previewHeader,previewFooter,
// previewImage}.tsx + semi-foundation/image/{previewInnerFoundation,previewFooterFoundation,
// previewImageFoundation}.ts + image/{image.scss,variables.scss,animation.scss,constants.ts}）
// 在这里合成一个：壳（Popup）+ header + 画布 + 两侧箭头 + footer。
//
//     ImagePreviewInner {
//         id: preview
//
//         sources: ["a.png", "b.png"]
//         visible: page.open                 // 受控，同 Modal
//         currentIndex: page.index
//         onVisibleChangeRequested: page.open = $arg
//         onChanged: page.index = $arg
//     }
//
// ------------------------------------------------------------------ 受控口径
// `visible` 与 `currentIndex` 都归调用方，本文件只发信号不自改（`closePolicy: NoAutoClose`）。
// 三条关闭路径发的信号**不一样**（previewInnerFoundation.ts）：
//   · 点遮罩 :119-134 ⇒ 只有 onVisibleChange(false)
//   · ×      :182-186 ⇒ onVisibleChange(false) + onClose
//   · Esc    :141-149 ⇒ onVisibleChange(false) + onClose
// 翻页同理：`switchImage` 只算出目标下标并发 `changed` / `prev` / `next`，
// 调用方不接就一步不动（官方非受控时是自己 setState，端口把这一份状态提到宿主）。
//
// ------------------------------------------------------------------ 没有进出场动画
// `.semi-image-preview` 上那条 `transition: opacity 500ms`（image.scss:71）实际用不到：
// 官方是 `visible && <Portal>…`（previewInner.tsx:413），不显示时整棵子树压根不挂载，
// 没有「从 opacity 0 起步」那一帧。那 500ms 只作用在 `-hide` 上（header / footer / 两侧箭头
// 随 viewerVisible 自动收起，previewInner.tsx:405 / :426-469），自动收起这条端口不排。
//
// ------------------------------------------------------------------ 端口不排的官方项
//   · 下载一族：`onDownload` / `onDownloadError` / `setDownloadName` / `disableDownload`。
//     官方是 fetch 成 blob 再触发 `<a download>`（previewInnerFoundation.ts:171-186），Qt 侧
//     没有等价物。footer 那颗下载键照画（官方 previewFooter.tsx:214-229 的 disabled 态也照画），
//     但点了不发信号；`disableDownload` 还会挡图上的右键菜单（previewImageFoundation.ts:192-201），
//     这条同样没有。
//   · `lazyLoad` / `lazyLoadMargin` / `preLoad` / `preLoadGap`：官方靠 IntersectionObserver +
//     一串 `new Image()` 串行预取（preview.tsx:110-133、previewInnerFoundation.ts:231-300），
//     Qt 的 Image 本来就异步加载，这套没有对应需求。
//   · `viewerVisibleDelay`（10s 无操作收起 chrome）、`showTooltip` 与那八条 `*Tip` 文案。
//   · `previewCls` / `previewStyle` / `className` / `style` / `crossOrigin`。
//   · 官方受控翻页时 `onChange` 会**发两次**（previewFoundation.ts:15-23 一次、
//     previewInner.tsx:107-115 的 notifyChange 又一次）—— 上游的重复通知，端口只发一次。
C.Popup {
    id: control

    // ---- 官方 PreviewProps（interface.tsx:31-95，缺省 previewInner.tsx:68-82）----
    property var sources: []                            // src: string | string[]
    property int currentIndex: 0
    property var previewTitle: undefined                // ReactNode：字符串或 Component
    property bool closable: true
    property bool maskClosable: true
    property bool closeOnEsc: true
    property bool infinite: false
    property real zoomStep: 0.1
    property real minZoom: 0.1
    property real maxZoom: 5
    property real initialZoom: 0                        // 官方 undefined；>0 才算给了
    property int zIndex: Theme.current.zImagePreview
    property var container: undefined                    // 官方 getPopupContainer
    property Component renderHeader: null
    property Component renderPreviewMenu: null           // 官方 (props: MenuProps) => ReactNode
    property Component renderLeftIcon: null
    property Component renderRightIcon: null
    property Component renderCloseIcon: null

    signal visibleChangeRequested(bool visible)
    signal closeRequested()
    signal changed(int index)
    signal prev(int index)
    signal next(int index)
    signal zoomInRequested(double zoom)
    signal zoomOutRequested(double zoom)
    // 官方 onRatioChange（interface.tsx:88）—— 不叫 ratioChanged，
    // 因为 `property string ratio` 自己就带一条 ratioChanged 通知信号
    signal ratioChange(string ratio)
    signal rotateLeft(int angle)

    // ---- 预览层自己的状态（官方 PreviewInnerStates + PreviewImageStates）----
    // zoom 的初值是 0.1 不是 1（previewInner.tsx:196-203），图 load 完才由 initializeImage 重算
    property real zoom: 0.1
    property real rotation: 0
    property string ratio: "adaptation"                  // adaptation | realSize
    property real translateX: 0
    property real translateY: 0
    property string initialZoomFor: ""
    property string zoomInitFor: ""                   // initialZoom 每张图只吃一次

    readonly property var sourceList: {
        const raw = control.sources;
        if (raw === undefined || raw === null)
            return [];
        if (Array.isArray(raw))
            return raw;
        return [String(raw)];
    }
    readonly property int sourceCount: control.sourceList.length
    readonly property int shownIndex: control.clampIndex(control.currentIndex)
    readonly property string currentSource: control.sourceCount > 0
        ? String(control.sourceList[control.shownIndex]) : ""
    // showPrev / showNext（previewInner.tsx:407-408）：只有一条时两侧都不给，
    // 非循环档在两端不给 —— 注意「翻页取模」那条路**不看** infinite（见 switchImage）
    readonly property bool showPrev: control.sourceCount !== 1
        && (control.infinite || control.shownIndex !== 0)
    readonly property bool showNext: control.sourceCount !== 1
        && (control.infinite || control.shownIndex !== control.sourceCount - 1)
    // footer 看到的是百分数（previewInner.tsx:470-473 全部 ×100）
    readonly property real zoomPercent: control.zoom * 100
    readonly property bool disabledZoomOut: control.zoom === control.minZoom
    readonly property bool disabledZoomIn: control.zoom === control.maxZoom
    readonly property real sliderFraction: Math.max(0, Math.min(1,
        (control.zoomPercent - control.minZoom * 100)
            / Math.max(0.0001, control.maxZoom * 100 - control.minZoom * 100)))

    // ---- 度量（variables.scss；那几个明暗一致的按字面量）----
    readonly property real headerHeight: 60                           // $height-image_preview_header
    readonly property real headerPaddingX: 24                         // header-paddingX
    readonly property real closeSize: 30                              // $width-image_preview_header_close
    readonly property color headerColor: Theme.current.colorWhite      // $color-image_preview_header
    readonly property color darkChrome: "#bf000000"                  // rgba(0,0,0,.75)
    readonly property real footerHeight: 48                           // $height-image_preview_footer
    readonly property real footerPaddingX: 16                         // footer-paddingX
    readonly property real footerBottom: 16                           // image.scss:156
    readonly property real footerRadius: Theme.current.radiusMedium    // $radius-image_preview_footer
    readonly property color footerIconColor: Theme.current.colorWhite
    readonly property color disabledColor: "#59f9f9f9"               // rgba(249,249,249,.35)
    readonly property real pageMarginX: 12                            // footer_page-marginX
    readonly property real gapMarginX: 16                             // footer_gap-marginLeft
    readonly property real dividerMarginX: 16                         // footer_divider-marginX
    readonly property real dividerHeight: 20                          // divider/variables.scss
    readonly property color dividerColor: "#80ffffff"                // rgba(255,255,255,.5)
    readonly property real sliderWidth: 132                           // $width-image_preview_footer_slider
    readonly property real sliderPaddingX: 16                         // footer_slider-paddingX
    readonly property real sliderRailHeight: 2                        // $height-image_preview_footer_slider
    readonly property real sliderHandleSize: 16                       // footer_slider_handle 宽
    readonly property real glyphSize: 20                              // $width-icon-large（size="large"）
    readonly property real sideIconSize: 40                           // $width-image_preview_icon
    readonly property real sideIconMarginX: 24                        // $spacing-image_preview_icon-x
    readonly property color spinColor: "#ffcccccc"                   // $color-image_preview_image_spin
    readonly property real adaptMargin: 80                            // 适配档那 80 的余量
    readonly property real maskTolerance: 5                           // 点遮罩的位移容差

    // 图片盒子：官方 width/height = floor(原图 × zoom)（previewImageFoundation.ts:231-232）
    readonly property size naturalSize: canvasImage.sourceSize
    readonly property real boxWidth: control.naturalSize.width > 0
        ? Math.floor(control.naturalSize.width * control.zoom) : 0
    readonly property real boxHeight: control.naturalSize.height > 0
        ? Math.floor(control.naturalSize.height * control.zoom) : 0
    readonly property size boundSize: control.boundingRectSize(control.boxWidth,
        control.boxHeight, control.rotation)
    // getCanDragDirection（:216-224）：包围盒比容器大才拖得动
    readonly property bool canDragHorizontal: control.boundSize.width > control.width
    readonly property bool canDragVertical: control.boundSize.height > control.height
    // 官方 `-content` 那个类只在没有 renderPreviewMenu 时才加（previewFooter.tsx:278-282），
    // 而 padding / 底色 / 圆角 / 高全在这条类上 ⇒ 自定义整条时这层壳一起没
    readonly property bool defaultMenu: control.renderPreviewMenu === null

    function clampIndex(index) {
        const n = control.sourceCount;
        if (n <= 0)
            return 0;
        return Math.max(0, Math.min(n - 1, index));
    }

    // calcBoundingRectSize（previewImageFoundation.ts:203-214）
    function boundingRectSize(w, h, deg) {
        const rad = deg * Math.PI / 180;
        const sinT = Math.abs(Math.sin(rad));
        const cosT = Math.abs(Math.cos(rad));
        return Qt.size(w * cosT + h * sinT, w * sinT + h * cosT);
    }

    // _clampZoom（previewInnerFoundation.ts:321-329）：非有限值落回 min
    function clampZoom(value) {
        if (!isFinite(value))
            return control.minZoom;
        return Math.max(control.minZoom, Math.min(control.maxZoom, value));
    }

    function round2(value) {
        return Number(value.toFixed(2));
    }

    // 适配档 = min((容器宽 - 80) / 包围盒宽, (容器高 - 80) / 包围盒高)，原图尺寸未知先按 1
    // （previewImageFoundation.ts:90-123）
    function adaptationZoom() {
        if (control.naturalSize.width <= 0 || control.naturalSize.height <= 0)
            return control.clampZoom(1);
        const b = control.boundingRectSize(control.naturalSize.width,
            control.naturalSize.height, control.rotation);
        const z = Math.min((control.width - control.adaptMargin) / b.width,
            (control.height - control.adaptMargin) / b.height);
        return control.clampZoom(control.round2(z));
    }

    function ratioZoom() {
        // realSize（官方 UI 上叫「原始大小」）就是数值 1（previewImageFoundation.ts:110）
        return control.ratio === "realSize" ? control.clampZoom(1) : control.adaptationZoom();
    }

    // getExtremeTranslate + getSafeTranslate（:283-309）：只有拖得动的轴才夹，另一轴归 0
    function clampTranslate() {
        const ex = (control.boundSize.width - control.width) / 2;
        const ey = (control.boundSize.height - control.height) / 2;
        control.translateX = control.canDragHorizontal
            ? (control.translateX > 0 ? Math.min(control.translateX, ex)
                : Math.max(control.translateX, -ex))
            : 0;
        control.translateY = control.canDragVertical
            ? (control.translateY > 0 ? Math.min(control.translateY, ey)
                : Math.max(control.translateY, -ey))
            : 0;
    }

    // changeZoom（previewImageFoundation.ts:226-281）。anchor 给的是「滚轮光标落在这张图上」
    // 时图内未旋转坐标，那才走按角度分档的四条公式；没给就是滑杆 / ±，只把已有平移按
    // newZoom / currZoom 缩放（官方那条是 Math.floor）。
    function applyZoom(newZoom, anchor) {
        const target = control.clampZoom(newZoom);
        const curr = control.zoom || 1;
        const scale = target / curr;
        let tx = Math.floor(control.translateX * scale);
        let ty = Math.floor(control.translateY * scale);
        if (anchor !== undefined && anchor !== null && control.boxWidth > 0) {
            let angle = control.rotation % 360;
            if (angle < 0)
                angle = 360 + angle;
            const halfW = control.boxWidth / 2;
            const halfH = control.boxHeight / 2;
            const k = 1 - target / curr;
            const ax = anchor.width;
            const ay = anchor.height;
            if (angle === 0) {
                tx = (ax - halfW) * k + control.translateX;
                ty = (ay - halfH) * k + control.translateY;
            } else if (angle === 90) {
                tx = (halfH - ay) * k + control.translateX;
                ty = (ax - halfW) * k + control.translateY;
            } else if (angle === 180) {
                tx = (halfW - ax) * k + control.translateX;
                ty = (halfH - ay) * k + control.translateY;
            } else if (angle === 270) {
                tx = (ay - halfH) * k + control.translateX;
                ty = (halfW - ax) * k + control.translateY;
            }
        }
        control.zoom = target;
        control.translateX = tx;
        control.translateY = ty;
        control.clampTranslate();
    }

    // 滚轮：±step，且**结果落在界内才动**（previewInnerFoundation.ts:94-117），两位小数
    function wheelZoom(delta, anchor) {
        // 官方 deltaY < 0 是放大（:103-113）；Qt 的 angleDelta.y > 0 对应「向上滚」
        const step = delta > 0 ? control.zoomStep : -control.zoomStep;
        const target = control.round2(control.zoom + step);
        if (target < control.minZoom || target > control.maxZoom)
            return;
        if (target > control.zoom)
            control.zoomInRequested(target);
        else if (target < control.zoom)
            control.zoomOutRequested(target);
        control.applyZoom(target, anchor);
    }

    // 滑杆 / ±：在百分数区间里夹，方向按 value 与当前 zoom 比（previewFooterFoundation.ts:7-25）
    function setZoomPercent(value) {
        const clamped = Math.max(control.minZoom * 100,
            Math.min(control.maxZoom * 100, value));
        const target = control.round2(clamped / 100);
        if (target > control.zoom)
            control.zoomInRequested(target);
        else if (target < control.zoom)
            control.zoomOutRequested(target);
        control.applyZoom(target);
    }

    function zoomIn() {
        control.setZoomPercent((control.zoom + control.zoomStep) * 100);
    }

    function zoomOut() {
        control.setZoomPercent((control.zoom - control.zoomStep) * 100);
    }

    // 比例档互翻（previewFooterFoundation.ts:27-31）
    function adjustRatio() {
        control.ratio = control.ratio === "adaptation" ? "realSize" : "adaptation";
        control.ratioChange(control.ratio);
        control.applyZoom(control.ratioZoom());
    }

    // 旋转：±90 **累加**，state 里不归一（previewInnerFoundation.ts:195-204）。
    // footer 那颗只接 handleRotateLeft；onRotateRight 只在 renderPreviewMenu 的入参里有。
    function handleRotateLeft() {
        control.rotation = control.rotation - 90;
        control.rotateLeft(control.rotation);
        // 官方 rotation 变了走 onWindowResize → initializeImage（previewImage.tsx:98-100），
        // 也就是**重算当前档**：适配档按新的包围盒，realSize 回到 1
        control.recomputeZoom();
    }

    // initializeImageZoom：initialZoom 每张图只吃一次，其余情况按当前比例档重算
    // （previewImageFoundation.ts:54-64,108-123,165-190）
    // fromLoad 那两路（status 与 sourceSize 各拍一拍）只认第一次，否则 initialZoom 会被
    // 后到的那一拍用适配档盖掉。
    // 这里原先还有一道「原图尺寸未知就先不算」的门，摘掉后 54 条一条不红：尺寸未知时
    // ratioZoom() 走的是 clamp(1) 那一条，而那条路不记账 ⇒ load 到位那一趟照样会重算，
    // 两种顺序的结果一样 ⇒ 属于防失控的保险，不是行为（同 List 那轮删掉的两道门）。
    function recomputeZoom(fromLoad) {
        if (fromLoad === true && control.zoomInitFor === control.currentSource)
            return;
        if (control.initialZoom > 0 && control.initialZoomFor !== control.currentSource) {
            control.initialZoomFor = control.currentSource;
            control.zoomInitFor = control.currentSource;
            control.applyZoom(control.initialZoom);
            return;
        }
        control.applyZoom(control.ratioZoom());
    }

    // 换张图：取模**不看 infinite**（previewInnerFoundation.ts:151-165），infinite 只管
    // 按钮给不给；rotation 归 0、ratio 回 adaptation（:167-170 + previewInner.tsx:236-241）
    function switchImage(dir) {
        const n = control.sourceCount;
        if (n <= 0)
            return;
        const target = (control.shownIndex + (dir === "prev" ? -1 : 1) + n) % n;
        control.changed(target);
        if (dir === "prev")
            control.prev(target);
        else
            control.next(target);
    }

    function requestVisibleFalse(withClose) {
        control.visibleChangeRequested(false);
        if (withClose)
            control.closeRequested();
    }

    // 打开时复位（previewInner.tsx:227-235）
    onAboutToShow: {
        control.rotation = 0;
        control.ratio = "adaptation";
        control.translateX = 0;
        control.translateY = 0;
        control.zoom = 0.1;
        control.initialZoomFor = "";
        control.zoomInitFor = "";
    }

    // 换张图把旋转与比例档清掉（onShownIndexChanged 而不是 onCurrentIndexChanged：
    // 受控时调用方可能把同一个下标再写一遍）
    onShownIndexChanged: {
        control.rotation = 0;
        control.ratio = "adaptation";
        control.initialZoomFor = "";
        control.zoomInitFor = "";
    }

    padding: 0
    parent: control.container !== undefined && control.container !== null
        ? control.container : C.Overlay.overlay
    modal: true
    dim: false
    focus: true
    // 样式默认那块不透明底矩形挂在动画之外，留着就是底下一块黑影（坑 103，同 Modal）
    background: null
    closePolicy: C.Popup.NoAutoClose
    z: control.zIndex
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // ---------------------------------------------------------------- 遮罩
    // 官方把 mousedown / mouseup 挂在最外层 div 上，「按下与抬起都在这层、位移不超过 5px」
    // 才算点遮罩（previewInnerFoundation.ts:119-134）。header 整条是 pointer-events: none
    // （image.scss:119）⇒ 顶部那 60px 里除了 × 也算点遮罩。
    Rectangle {
        id: mask

        objectName: "imagePreviewMask"

        anchors.fill: parent
        color: Theme.current.colorOverlayBg

        property real pressX: 0
        property real pressY: 0

        // 落在 footer / 两侧箭头 / × 上都不算遮罩
        function overChrome(x, y) {
            const p = Qt.point(x, y);
            if (footerBar.visible && footerBar.contains(footerBar.mapFromItem(mask, x, y)))
                return true;
            if (prevIcon.visible && prevIcon.contains(prevIcon.mapFromItem(mask, x, y)))
                return true;
            if (nextIcon.visible && nextIcon.contains(nextIcon.mapFromItem(mask, x, y)))
                return true;
            if (closeButton.visible && closeButton.contains(closeButton.mapFromItem(mask, x, y)))
                return true;
            if (imageBox.visible && imageBox.contains(imageBox.mapFromItem(mask, x, y)))
                return true;
            return false;
        }

        PointHandler {
            id: maskPress

            property real startX: 0
            property real startY: 0

            // 按下那一刻记下起点：抬起时和它比，位移在 5px 以内才算点遮罩
            onActiveChanged: {
                if (!active)
                    return;
                mask.pressX = point.position.x;
                mask.pressY = point.position.y;
            }
        }

        TapHandler {
            id: maskTap

            objectName: "imagePreviewMaskTap"

            // 内联档 —— `onTapped: function (event)` 那种单参函数写法会静默连不上
            // （tapped 的 C++ 签名是 (QEventPoint, Qt::MouseButton)，见坑 105）
            onTapped: {
                if (!control.maskClosable)
                    return;
                // handler 报的是相对自己父项（就是这层遮罩）的坐标
                const p = maskTap.point.position;
                if (mask.overChrome(p.x, p.y))
                    return;
                const dx = Math.abs(p.x - mask.pressX);
                const dy = Math.abs(p.y - mask.pressY);
                if (dx > control.maskTolerance || dy > control.maskTolerance)
                    return;
                control.requestVisibleFalse(false);
            }
        }
    }

    // ---------------------------------------------------------------- 画布
    // 官方的 container 就是整块预览面（不减 header / footer），适配档那 80 的余量相对它算
    Item {
        id: canvas

        objectName: "imagePreviewCanvas"

        anchors.fill: parent
        clip: true

        Item {
            id: imageBox

            objectName: "imagePreviewImage"

            x: canvas.width / 2 - width / 2 + control.translateX
            y: canvas.height / 2 - height / 2 + control.translateY
            width: control.boxWidth
            height: control.boxHeight
            rotation: control.rotation

            Image {
                id: canvasImage

                objectName: "imagePreviewSource"

                anchors.fill: parent
                source: control.currentSource
                fillMode: Image.Stretch
                asynchronous: true
                cache: false
            }

            DragHandler {
                id: panDrag

                objectName: "imagePreviewPan"

                target: null
                cursorShape: control.canDragHorizontal || control.canDragVertical
                    ? Qt.ClosedHandCursor : Qt.ArrowCursor

                property real startTranslateX: 0
                property real startTranslateY: 0
                property real grabX: 0
                property real grabY: 0

                onActiveChanged: {
                    if (active) {
                        startTranslateX = control.translateX;
                        startTranslateY = control.translateY;
                        grabX = centroid.position.x;
                        grabY = centroid.position.y;
                    }
                }

                onCentroidChanged: {
                    if (!active)
                        return;
                    control.translateX = startTranslateX + (centroid.position.x - grabX);
                    control.translateY = startTranslateY + (centroid.position.y - grabY);
                    control.clampTranslate();
                }
            }
        }

        Spin {
            id: canvasSpin

            objectName: "imagePreviewSpin"

            anchors.centerIn: parent
            visible: canvasImage.status === Image.Loading
            size: "large"
            color: control.spinColor
        }

        // 滚轮：光标落在图上才按角度公式重锚（changeZoom 里 `e.target === imageDOM` 那一支）
        WheelHandler {
            objectName: "imagePreviewWheel"

            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function (event) {
                var anchor = null;
                const local = imageBox.mapFromItem(canvas, event.x, event.y);
                if (local.x >= 0 && local.y >= 0 && local.x <= imageBox.width
                        && local.y <= imageBox.height)
                    anchor = Qt.size(local.x, local.y);
                control.wheelZoom(event.angleDelta.y, anchor);
            }
        }
    }

    // ---------------------------------------------------------------- header
    Item {
        id: headerBand

        objectName: "imagePreviewHeader"

        x: 0
        y: 0
        width: parent.width
        height: control.headerHeight

        // 官方 renderHeader 是 `(title) => ReactNode`；端口没有函数组件，改成往自定义节点
        // 注入一个声明了的 `title` 属性（同 OverflowList 的 renderer 注入约定）
        Loader {
            id: headerSlot

            objectName: "imagePreviewHeaderSlot"

            active: control.renderHeader !== null
            sourceComponent: control.renderHeader
            x: control.headerPaddingX
            anchors.verticalCenter: parent.verticalCenter

            onItemChanged: {
                if (item)
                    control.injectHeader(item);
            }
        }

        Text {
            id: headerTitle

            objectName: "imagePreviewTitle"

            visible: control.renderHeader === null && control._isText(control.previewTitle)
            x: control.headerPaddingX
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - control.headerPaddingX * 2 - control.closeSize
            text: control._isText(control.previewTitle) ? String(control.previewTitle) : ""
            color: control.headerColor
            font.pixelSize: Theme.current.fontSizeRegular   // @include font-size-regular
            font.weight: Font.Normal
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
            elide: Text.ElideRight
        }

        Loader {
            id: headerTitleNode

            objectName: "imagePreviewTitleNode"

            active: control.renderHeader === null && control._isNode(control.previewTitle)
            sourceComponent: control._nodeOf(control.previewTitle)
            x: control.headerPaddingX
            anchors.verticalCenter: parent.verticalCenter
        }

        // × 的热区是 30×30 的圆，hover 才给 rgba(0,0,0,.75)
        Rectangle {
            id: closeButton

            objectName: "imagePreviewClose"

            visible: control.closable
            width: control.closeSize
            height: control.closeSize
            radius: width / 2
            color: closeHover.hovered ? control.darkChrome : "transparent"
            x: headerBand.width - control.headerPaddingX - width
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                objectName: "imagePreviewCloseGlyph"

                anchors.centerIn: parent
                name: "close"
                size: control.glyphSize
                color: control.headerColor
                visible: control.renderCloseIcon === null
            }

            Loader {
                active: control.renderCloseIcon !== null
                sourceComponent: control.renderCloseIcon
                anchors.centerIn: parent
            }

            HoverHandler { id: closeHover }

            TapHandler {
                objectName: "imagePreviewCloseTap"

                onTapped: control.requestVisibleFalse(true)
            }
        }
    }

    // ---------------------------------------------------------------- 两侧箭头
    // 40×40 的圆、竖直居中、bg rgba(0,0,0,.75)、glyph 20；prev 左 24、next 右 24。
    // 官方这两颗**没有** hover 样式（image.scss:82-95 只有一条底色），所以不挂 HoverHandler
    Rectangle {
        id: prevIcon

        objectName: "imagePreviewPrevIcon"

        visible: control.showPrev
        width: control.sideIconSize
        height: control.sideIconSize
        radius: width / 2
        color: control.darkChrome
        x: control.sideIconMarginX
        y: canvas.height / 2 - height / 2

        Icon {
            anchors.centerIn: parent
            name: "arrow_left"
            size: control.glyphSize
            color: control.footerIconColor
            visible: control.renderLeftIcon === null
        }

        Loader {
            active: control.renderLeftIcon !== null
            sourceComponent: control.renderLeftIcon
            anchors.centerIn: parent
        }

        TapHandler {
            objectName: "imagePreviewPrevTap"

            onTapped: control.switchImage("prev")
        }
    }

    Rectangle {
        id: nextIcon

        objectName: "imagePreviewNextIcon"

        visible: control.showNext
        width: control.sideIconSize
        height: control.sideIconSize
        radius: width / 2
        color: control.darkChrome
        x: canvas.width - width - control.sideIconMarginX
        y: canvas.height / 2 - height / 2

        Icon {
            anchors.centerIn: parent
            name: "arrow_right"
            size: control.glyphSize
            color: control.footerIconColor
            visible: control.renderRightIcon === null
        }

        Loader {
            active: control.renderRightIcon !== null
            sourceComponent: control.renderRightIcon
            anchors.centerIn: parent
        }

        TapHandler {
            objectName: "imagePreviewNextTap"

            onTapped: control.switchImage("next")
        }
    }

    // ---------------------------------------------------------------- footer
    // 官方 DOM 顺序：chevron_left · 页码 · chevron_right · 分割线 · minus · 滑杆 · plus ·
    // 比例 · 分割线 · rotate · download（previewFooter.tsx:256-271，分割线插在下标 3 与 8）。
    // `-gap`（左 16）落在 ratio 与 download 上，因为 showTooltip 恒 false。
    Rectangle {
        id: footerBar

        objectName: "imagePreviewFooter"

        visible: control.sourceCount > 0
        width: control.defaultMenu ? footerRow.x + footerRow.implicitWidth + control.footerPaddingX
            : menuSlot.implicitWidth + control.footerPaddingX * 2
        height: control.defaultMenu ? control.footerHeight : menuSlot.implicitHeight
        radius: control.defaultMenu ? control.footerRadius : 0
        color: control.defaultMenu ? control.darkChrome : "transparent"
        x: Math.round(canvas.width / 2 - width / 2)
        y: canvas.height - height - control.footerBottom

        // 整条操作区可替换（官方 renderPreviewMenu）：给了就换掉默认那排，
        // 而且 -content 那个类不加（padding / 底色 / 圆角 / 高都是它带的）⇒ 这层壳也不画
        Loader {
            id: menuSlot

            objectName: "imagePreviewMenuSlot"

            active: control.renderPreviewMenu !== null
            sourceComponent: control.renderPreviewMenu
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            onItemChanged: {
                if (item)
                    control.injectMenu(item);
            }
        }

        Row {
            id: footerRow

            objectName: "imagePreviewFooterRow"

            visible: control.renderPreviewMenu === null
            x: control.footerPaddingX
            y: 0
            spacing: 0

            // 每个控件都占满 48 高，glyph 在各自格子里居中
            Item {
                objectName: "footerPrev"

                width: control.glyphSize
                height: control.footerHeight

                Icon {
                    anchors.centerIn: parent
                    name: "chevron_left"
                    size: control.glyphSize
                    color: control.showPrev ? control.footerIconColor : control.disabledColor
                }

                TapHandler {
                    objectName: "footerPrevTap"

                    onTapped: if (control.showPrev) control.switchImage("prev")
                }
            }

            Item { width: control.pageMarginX; height: control.footerHeight }

            Text {
                id: pageText

                objectName: "imagePreviewPage"

                height: control.footerHeight
                anchors.verticalCenterOffset: 0
                verticalAlignment: Text.AlignVCenter
                text: (control.shownIndex + 1) + "/" + control.sourceCount
                color: control.footerIconColor
                font.pixelSize: Theme.current.fontSizeHeader6
                lineHeight: 22
                lineHeightMode: Text.FixedHeight
            }

            Item { width: control.pageMarginX; height: control.footerHeight }

            Item {
                objectName: "footerNext"

                width: control.glyphSize
                height: control.footerHeight

                Icon {
                    anchors.centerIn: parent
                    name: "chevron_right"
                    size: control.glyphSize
                    color: control.showNext ? control.footerIconColor : control.disabledColor
                }

                TapHandler {
                    objectName: "footerNextTap"

                    onTapped: if (control.showNext) control.switchImage("next")
                }
            }

            Item { width: control.dividerMarginX; height: control.footerHeight }

            Rectangle {
                objectName: "footerDividerFirst"

                width: 1
                height: control.dividerHeight
                anchors.verticalCenter: parent.verticalCenter
                color: control.dividerColor
            }

            Item { width: control.dividerMarginX; height: control.footerHeight }

            Item {
                objectName: "footerZoomOut"

                width: control.glyphSize
                height: control.footerHeight

                Icon {
                    anchors.centerIn: parent
                    name: "minus"
                    size: control.glyphSize
                    color: control.disabledZoomOut ? control.disabledColor : control.footerIconColor
                }

                TapHandler {
                    objectName: "footerZoomOutTap"

                    onTapped: if (!control.disabledZoomOut) control.zoomOut()
                }
            }

            Item {
                id: footerSlider

                objectName: "imagePreviewSlider"

                width: control.sliderWidth
                height: control.footerHeight

                readonly property real innerX: control.sliderPaddingX
                readonly property real innerW: width - control.sliderPaddingX * 2

                Rectangle {
                    objectName: "sliderRail"

                    x: footerSlider.innerX
                    width: footerSlider.innerW
                    height: control.sliderRailHeight
                    y: footerSlider.height / 2 - height / 2
                    color: control.footerIconColor
                }

                Rectangle {
                    objectName: "sliderFill"

                    x: footerSlider.innerX
                    width: footerSlider.innerW * control.sliderFraction
                    height: control.sliderRailHeight
                    y: footerSlider.height / 2 - height / 2
                    color: control.footerIconColor
                }

                Rectangle {
                    id: sliderHandle

                    objectName: "sliderHandle"

                    width: control.sliderHandleSize
                    height: control.sliderHandleSize
                    radius: width / 2
                    color: control.footerIconColor
                    x: footerSlider.innerX + footerSlider.innerW * control.sliderFraction - width / 2
                    y: footerSlider.height / 2 - height / 2
                    // 绘制交给下面那只 MultiEffect（它连投影一起出）。用 opacity: 0 而不是
                    // visible: false —— 这只手柄上挂着 DragHandler，隐藏的项收不到输入事件
                    opacity: 0

                    // 官方这条滑杆用的是 Slider 那套手柄样式（@mixin shadow-knob），
                    // 参数同 Slider / Switch 那两处
                    MultiEffect {
                        source: sliderHandle
                        anchors.fill: sliderHandle
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 0.35)
                        shadowVerticalOffset: 4
                        shadowBlur: 1.0
                        blurMax: 8
                    }
                }

                DragHandler {
                    objectName: "sliderDrag"

                    target: null

                    onCentroidChanged: {
                        if (!active)
                            return;
                        control.setZoomPercent(control.percentAt(centroid.position.x));
                    }
                }

                TapHandler {
                    objectName: "sliderTap"

                    onTapped: control.setZoomPercent(control.percentAt(point.position.x))
                }
            }

            Item {
                objectName: "footerZoomIn"

                width: control.glyphSize
                height: control.footerHeight

                Icon {
                    anchors.centerIn: parent
                    name: "plus"
                    size: control.glyphSize
                    color: control.disabledZoomIn ? control.disabledColor : control.footerIconColor
                }

                TapHandler {
                    objectName: "footerZoomInTap"

                    onTapped: if (!control.disabledZoomIn) control.zoomIn()
                }
            }

            Item { width: control.gapMarginX; height: control.footerHeight }

            // 图标显示的是「点下去会切到哪一档」，不是当前档（previewFooter.tsx:193）
            Item {
                objectName: "footerRatio"

                width: control.glyphSize
                height: control.footerHeight

                Icon {
                    objectName: "footerRatioGlyph"

                    anchors.centerIn: parent
                    name: control.ratio === "adaptation" ? "real_size_stroked"
                        : "window_adaption_stroked"
                    size: control.glyphSize
                    color: control.footerIconColor
                }

                TapHandler {
                    objectName: "footerRatioTap"

                    onTapped: control.adjustRatio()
                }
            }

            Item { width: control.dividerMarginX; height: control.footerHeight }

            Rectangle {
                objectName: "footerDividerSecond"

                width: 1
                height: control.dividerHeight
                anchors.verticalCenter: parent.verticalCenter
                color: control.dividerColor
            }

            Item { width: control.dividerMarginX; height: control.footerHeight }

            Item {
                objectName: "footerRotate"

                width: control.glyphSize
                height: control.footerHeight

                Icon {
                    anchors.centerIn: parent
                    name: "rotate"
                    size: control.glyphSize
                    color: control.footerIconColor
                }

                TapHandler {
                    objectName: "footerRotateTap"

                    onTapped: control.handleRotateLeft()
                }
            }

            Item { width: control.gapMarginX; height: control.footerHeight }

            Item {
                objectName: "footerDownload"

                width: control.glyphSize
                height: control.footerHeight

                Icon {
                    anchors.centerIn: parent
                    name: "download"
                    size: control.glyphSize
                    color: control.footerIconColor
                    // 下载这条端口不排：键照样画，点了什么都不发
                }
            }
        }
    }

    // 滑杆上某个 x 对应的百分数（官方 Slider 的 min/max/step 都是百分数口径）
    function percentAt(x) {
        const inner = footerSlider.width - control.sliderPaddingX * 2;
        const f = Math.max(0, Math.min(1, (x - control.sliderPaddingX) / Math.max(1, inner)));
        return control.minZoom * 100 + f * (control.maxZoom * 100 - control.minZoom * 100);
    }

    // ---------------------------------------------------------------- Esc
    readonly property int __escId: EscStack.nextId()

    // 栈顶标记由 ModalEscStack 回灌（`.js` 里那个数组不是 notify，绑定读不到变化）
    property bool escIsTop: false

    function __setEscTop(isTop) {
        control.escIsTop = isTop;
    }

    onOpened: {
        EscStack.push(control.__escId, control.__setEscTop)
        // 重开时那张图可能还在缓存里（不会再发 onStatusChanged），这一趟补上。
        // 按「load 那一趟」的口径走，才不会被刚吃下的 initialZoom 与自己打架
        control.recomputeZoom(true)
    }

    onClosed: EscStack.remove(control.__escId)

    Component.onDestruction: EscStack.remove(control.__escId)

    Shortcut {
        objectName: "imagePreviewEscShortcut"

        sequences: [StandardKey.Cancel]
        // ApplicationShortcut：官方是往 document 上挂 keydown、不看窗口焦点（同 Modal 那条）
        context: Qt.ApplicationShortcut
        enabled: control.escIsTop && control.closeOnEsc
        onActivated: control.requestVisibleFalse(true)
    }

    // 容器尺寸变了就重算当前档（官方 initializeImage 在 load / resize / ratio 变化时跑）。
    // 但浏览器里容器在图加载之前就定好尺寸了，Qt 这边 Popup 的 width / height 是打开那一刻
    // 才从 0 变到位的 —— 那一趟不是「resize」，跟着算会把刚吃下去的 initialZoom 盖掉
    property real lastLayoutWidth: 0
    property real lastLayoutHeight: 0

    onWidthChanged: {
        const previous = control.lastLayoutWidth;
        control.lastLayoutWidth = control.width;
        if (previous > 0)
            control.recomputeZoom(false);
    }

    onHeightChanged: {
        const previous = control.lastLayoutHeight;
        control.lastLayoutHeight = control.height;
        if (previous > 0)
            control.recomputeZoom(false);
    }

    // sourceSize 比 status 晚一拍到位（实测：status 已经 Ready 时 naturalSize 还是 0），
    // 只在 onStatusChanged 里算会拿到「尺寸未知 ⇒ 先按 1」那一条，之后再也没有第二次机会
    onNaturalSizeChanged: control.recomputeZoom(true)

    Connections {
        target: canvasImage

        function onStatusChanged() {
            if (canvasImage.status !== Image.Ready)
                return;
            control.recomputeZoom(true);
        }
    }

    // ---- 自定义那两块的注入 ----
    // 官方是 renderPreviewMenu(props) / renderHeader(title)。QML 侧的写法是自定义节点自己
    // 声明 `property var menu` / `property var title`，这里注入 —— 没声明的不写
    // （6.11 给对象塞没声明的属性是直接抛错，见坑 19）。值一律走 Qt.binding，
    // 一次性赋值会拿到还没算完的那一份。
    function injectHeader(node) {
        if (node === null || node === undefined || node.title === undefined)
            return;
        node.title = Qt.binding(function () { return control.previewTitle; });
    }

    function injectMenu(node) {
        if (node === null || node === undefined || node.menu === undefined)
            return;
        node.menu = Qt.binding(function () { return control.menuProps(); });
    }

    // previewFooter.tsx:98-113 那份 props。`menuItems` 是 React 节点数组，端口没有对应物；
    // 官方 demo 解构的是 disableZoomIn / disableZoomOut（少个 d），这里按组件实际给的
    // disabledZoomIn / disabledZoomOut 给（组件是对的，demo 的键名是笔误）
    function menuProps() {
        return {
            min: control.minZoom * 100,
            max: control.maxZoom * 100,
            step: control.zoomStep * 100,
            curPage: control.shownIndex + 1,
            totalNum: control.sourceCount,
            zoom: control.zoomPercent,
            ratio: control.ratio,
            disabledPrev: !control.showPrev,
            disabledNext: !control.showNext,
            disabledZoomIn: control.disabledZoomIn,
            disabledZoomOut: control.disabledZoomOut,
            onPrev: function () { control.switchImage("prev"); },
            onNext: function () { control.switchImage("next"); },
            onZoomIn: function () { control.zoomIn(); },
            onZoomOut: function () { control.zoomOut(); },
            onRatioClick: function () { control.adjustRatio(); },
            onRotateLeft: function () { control.handleRotateLeft(); },
            onRotateRight: function () { control.handleRotateRight(); },
            onDownload: function () {}
        };
    }

    // 官方 footer 那颗只接 handleRotateLeft，但 renderPreviewMenu 的入参里确实有
    // onRotateRight（previewFooter.tsx:105）⇒ 自定义那一整条时转得动另一边
    function handleRotateRight() {
        control.rotation = control.rotation + 90;
        control.rotateLeft(control.rotation);
        control.recomputeZoom();
    }

    // ---- 小工具 ----
    function _isText(value) {
        return typeof value === "string" || typeof value === "number";
    }

    function _isNode(value) {
        return value !== undefined && value !== null && !control._isText(value);
    }

    function _nodeOf(value) {
        return control._isNode(value) ? value : null;
    }
}
