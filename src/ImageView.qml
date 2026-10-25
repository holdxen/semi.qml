pragma ComponentBehavior: Bound

import QtQuick

// 图片展示。官方 `Image`（packages/semi-ui/image/image.tsx +
// semi-foundation/image/imageFoundation.ts + image/{image.scss,variables.scss}）：
// 一个带圆角的外壳 + 一张 img，加载中 / 失败时在 img 上面盖一层状态块，能预览时只有光标变化。
//
//     ImageView {
//         width: 240
//         height: 160
//         src: "photo.jpg"
//         preview: ({ previewTitle: "详情图" })     // 布尔，或官方那张 PreviewProps
//     }
//
// 名字带 View，是因为本模块一旦导出名为 `Image` 的类型，同模块里所有 `Image { }` 都会被
// 遮蔽掉（`Text`→`TextLabel` 同理，见坑 22）。
//
// ------------------------------------------------------------------ 官方 ImageProps
// 逐条对着 interface.tsx:16-30 与 image.tsx:37-41 的 defaultProps：
//   · `preview` 缺省 **true**；`src` / `fallback` / `placeholder` / `alt` 都没有缺省。
//   · `width` / `height` 落在本 Item 自己身上（官方是外层 div 的 style + img 的同名属性）。
//     两条都没给时官方是 img 的固有尺寸（外层 inline-block 跟着缩），端口用
//     `implicitWidth / implicitHeight = thumb 的隐式尺寸` 顶替那一条。
//   · `preview` 两形：布尔，或者那张 `PreviewProps` 对象。对象档只有 `isObject(preview)`
//     且 `typeof visible === "boolean"` 时才受控（image.tsx:74-79、imageFoundation.ts:48-62）；
//     预览那张的源走 `preview.src ?? src`（:185，可以是数组 ⇒ 单张图也能开出多图预览）。
//   · `placeholder` 换加载中的那一块、`fallback` 换失败的那一块，两处都是 `{x ? … : 默认}`
//     的真值判断 ⇒ **空串等于没给**，落回默认（加载中是 `Skeleton.Image`，失败是
//     `IconUploadError` 24px）。`fallback` 给字符串时官方是 `<img width:100% height:100%>`，
//     也就是铺满拉伸。
//   · `onLoad` / `onError` / `onClick` ⇒ 端口的 `loaded` / `failed` / `clicked`。官方 `onClick`
//     是随 restProps 漏到 `<img>` 上的（image.tsx:177-179 没解构它），而开预览那条挂在
//     **外层 div**（:195）⇒ 两件事在官方是两个节点；端口的 img 铺满外壳，落在哪都算。
//   · `imgStyle` / `imgCls` / `className` / `style` / `prefixCls` 不收（没有 CSS）。
//   · `children` 官方**从不渲染**（:177-179 没解构，跟着 restProps 塞进 `<img>` 变成属性）
//     ⇒ 端口也不收这一档。
//   · `crossOrigin` / `imageID` / `setDownloadName`：前者 Qt 侧没有对应（本地资源不涉及 CORS），
//     中者是组内下标（端口是内部的 `groupIndex`），后者属于下载那一族，端口不排。
//
// ------------------------------------------------------------------ 规格（image.scss）
//   · 外壳 `inline-block` + `overflow: hidden` + 圆角 3（$radius-image = border-radius-small）。
//   · `-overlay` 绝对铺满（:43-49），里面 `-status` 100%×100% 居中（:53-61）：底色 fill-0、
//     圆角 3、文字色 disabled-text。加载中与失败**都**盖这一层，成功态什么都不画（:215）。
//   · `-img-error` 是 `opacity: 0`（:38-40）—— 失败时那张 img 仍然占位、仍然吃点击。
//   · 能预览时只有 `cursor: zoom-in`（:34-36，条件是 `preview && 成功`，**组内也算**）。
//     Qt 的 cursor 形状里没有 zoom-in，端口用 PointingHandCursor 顶替。
//   · 失败默认图标 `$width-icon-extra-large` = 24，名 upload_error。
//
// ------------------------------------------------------------------ 与官方的差异 / 照抄的怪处
//   · **官方没有悬停遮罩**：`renderMask`（:168-173）从来没被调用，`semi-image-mask*` 三个类名
//     在 scss 里没有规则，配套的 `$color-image_mask-bg` / `$color-image_mask_info_text` /
//     `$spacing-image_mask_info_text-marginTop` 全是死令牌。端口原先的 `showMask` / `maskText`
//     就是照那段死代码造的，这一轮撤掉。
//   · 点开的判定与「画不画预览层」是两套（imageFoundation.ts:15-30 vs image.tsx:183）：
//     `handleClick` 只看 `preview` 真值与在不在组里，**不看加载成功**；而 `canPreview`
//     （自己那张预览层画不画）要求 `loadStatus === "success"`。结果是：单张时点失败的图
//     什么都不会发生，而**组里点一张失败的图照样开预览**（开出来那张是坏的）。端口照抄。
//   · 组内的下标是「按 `preview` 真值筛过之后」重排的（preview.tsx:161-196）：组里放三张、
//     中间那张 `preview: false` ⇒ 第三张的 imageID 是 1 而不是 2。端口同样按筛后的顺序发。
//   · `fillMode` 是本库自有：Qt 的 Image 必须自己挑缩放方式，官方那边是 img 的固有尺寸加
//     CSS object-fit。缺省 PreserveAspectFit。
Item {
    id: control

    // ---- 官方 ImageProps（interface.tsx:16-30，缺省 image.tsx:37-41）----
    property url src: ""
    property string alt: ""
    property var placeholder: undefined                 // ReactNode：字符串或 Component
    property var fallback: undefined                    // string | ReactNode
    property var preview: true                          // bool | PreviewProps

    // ---- 本库自有 ----
    property int fillMode: Image.PreserveAspectFit

    signal loaded()
    signal failed()
    signal clicked()
    // 官方 preview.onVisibleChange / onClose（只有对象档那两个回调）
    signal previewVisibleChangeRequested(bool visible)
    signal previewCloseRequested()

    // ---- 组内登记：由 ImagePreview 往下写（条目不回读父项，理由同 List）----
    readonly property bool isImageView: true
    property var groupHost: null
    property int groupIndex: -1

    // ---- 官方 ImageStates（image.tsx:56-60）----
    readonly property string loadStatus: thumb.status === Image.Ready ? "success"
        : (thumb.status === Image.Error ? "error" : "loading")
    property bool previewVisibleInternal: false
    property int previewIndexInternal: 0

    readonly property var pv: control._isPreviewObject(control.preview) ? control.preview : ({})
    readonly property bool previewOn: control._previewOn(control.preview)
    readonly property bool previewControlled: typeof control.pv.visible === "boolean"
    readonly property bool previewVisible: control.previewControlled
        ? Boolean(control.pv.visible) : control.previewVisibleInternal
    readonly property bool inGroup: control.groupHost !== null
    // canPreview（image.tsx:183）：成功 + preview 真 + 不在组里 —— 决定自己那张画不画
    readonly property bool canPreview: control.loadStatus === "success"
        && control.previewOn && !control.inGroup
    // showPreviewCursor（:184）：**不**排除组内，也不看 canPreview
    readonly property bool showPreviewCursor: control.previewOn
        && control.loadStatus === "success"
    // previewSrc（:185）：对象档的 src 优先，可以是个数组
    readonly property var previewSourceValue: control._has(control.pv, "src")
        ? control.pv.src : control.src
    readonly property var previewTitleValue: control._has(control.pv, "previewTitle")
        ? control.pv.previewTitle : undefined
    // 官方 PreviewInner 自己管 currentIndex；端口把这一份提到宿主（受控与否用「给没给」判，
    // 同 ImagePreview 的口径）
    readonly property bool previewIndexControlled: control._has(control.pv, "currentIndex")
    readonly property int previewIndexValue: control.previewIndexControlled
        ? Number(control.pv.currentIndex) : control.previewIndexInternal

    // 官方没给 width / height 时是 img 的固有尺寸（外层 inline-block 跟着缩）
    implicitWidth: thumb.implicitWidth
    implicitHeight: thumb.implicitHeight

    // ---- 令牌 ----
    readonly property real radius: Theme.current.radiusSmall              // $radius-image
    readonly property real errorIconSize: Theme.current.widthIconExtraLarge  // 24

    function requestVisible(next) {
        if (!control.previewControlled)
            control.previewVisibleInternal = next;
        control.previewVisibleChangeRequested(next);
    }

    // imageFoundation.ts:15-30：只看 preview 真值与在不在组里，不看加载状态
    function handleClick() {
        control.clicked();
        if (!control.previewOn)
            return;
        if (control.inGroup) {
            control.groupHost.childClicked(control.groupIndex);
            return;
        }
        control.requestVisible(true);
    }

    function _isPreviewObject(value) {
        return typeof value === "object" && value !== null;
    }

    function _previewOn(value) {
        if (value === undefined || value === null)
            return false;
        return Boolean(value);
    }

    function _has(obj, key) {
        return obj !== undefined && obj !== null && typeof obj === "object" && key in obj
            && obj[key] !== undefined && obj[key] !== null;
    }

    // 官方两处都是 `{x ? … : 默认}` 的真值判断 ⇒ 空串与 0 都是「没给」
    function _taken(value) {
        return Boolean(value === undefined || value === null ? false : value);
    }

    function _isText(value) {
        return (typeof value === "string" || typeof value === "number") && control._taken(value);
    }

    function _nodeOf(value) {
        return (control._taken(value) && !control._isText(value)) ? value : null;
    }

    // 官方外壳：inline-block + overflow hidden + 圆角 3，img 铺在里面
    Rectangle {
        id: surface

        objectName: "imageSurface"

        anchors.fill: parent
        radius: control.radius
        clip: true
        color: "transparent"

        Image {
            id: thumb

            objectName: "imageThumb"

            anchors.fill: parent
            source: control.src
            fillMode: control.fillMode
            asynchronous: true

            // -img-error { opacity: 0 }：仍然占位、仍然吃点击
            opacity: control.loadStatus === "error" ? 0 : 1

            onStatusChanged: {
                if (thumb.status === Image.Ready)
                    control.loaded();
                else if (thumb.status === Image.Error)
                    control.failed();
            }
        }

        // -overlay：只有非成功态才画（image.tsx:215）
        Item {
            id: overlay

            objectName: "imageOverlay"

            anchors.fill: parent
            visible: control.loadStatus !== "success"

            // -status：100%×100%、fill-0 底、内容居中
            Rectangle {
                id: statusBox

                objectName: "imageStatus"

                anchors.fill: parent
                radius: control.radius
                color: Theme.current.colorFill0

                // ---- 加载中 ----
                Item {
                    id: loadingBox

                    objectName: "imageLoading"

                    anchors.fill: parent
                    visible: control.loadStatus === "loading"

                    Text {
                        objectName: "imagePlaceholderText"

                        visible: control._isText(control.placeholder)
                        anchors.centerIn: parent
                        text: control._isText(control.placeholder) ? String(control.placeholder) : ""
                        color: Theme.current.colorDisabledText
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Loader {
                        objectName: "imagePlaceholderNode"

                        anchors.centerIn: parent
                        active: control._nodeOf(control.placeholder) !== null
                        sourceComponent: control._nodeOf(control.placeholder)
                    }

                    // 默认那一份：Skeleton.Image（官方给它带 width / height 的 style）
                    Loader {
                        objectName: "imageDefaultPlaceholder"

                        anchors.fill: parent
                        active: loadingBox.visible
                            && !control._isText(control.placeholder)
                            && control._nodeOf(control.placeholder) === null
                        sourceComponent: componentSkeletonImage
                    }
                }

                // ---- 失败 ----
                Item {
                    id: errorBox

                    objectName: "imageError"

                    anchors.fill: parent
                    visible: control.loadStatus === "error"

                    // 官方 `typeof fallback === "string"` 时是一张 100%×100% 的 img（:142）
                    Image {
                        objectName: "imageFallbackImage"

                        anchors.fill: parent
                        visible: control._isText(control.fallback)
                        source: control._isText(control.fallback) ? String(control.fallback) : ""
                        fillMode: Image.Stretch
                        asynchronous: true
                    }

                    Loader {
                        objectName: "imageFallbackNode"

                        anchors.centerIn: parent
                        active: control._nodeOf(control.fallback) !== null
                        sourceComponent: control._nodeOf(control.fallback)
                    }

                    // 默认那一份：IconUploadError size="extra-large"
                    Icon {
                        objectName: "imageErrorIcon"

                        anchors.centerIn: parent
                        name: "upload_error"
                        size: control.errorIconSize
                        color: Theme.current.colorDisabledText
                        visible: errorBox.visible && !control._isText(control.fallback)
                            && control._nodeOf(control.fallback) === null
                    }
                }
            }
        }
    }

    Component {
        id: componentSkeletonImage

        SkeletonImage {}
    }

    // 官方 cursor: zoom-in 挂在 img 上（条件是 preview && 成功，组内也算）
    HoverHandler {
        objectName: "imageCursor"

        cursorShape: control.showPreviewCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        objectName: "imageTap"

        onTapped: control.handleClick()
    }

    // 组外的图自己带一张预览层（image.tsx:216-225：canPreview 才画）。
    // 对象档那几条键在这里逐条接过去 —— 官方是 `{...omit(preview, 那四个样式键)}`。
    ImagePreviewInner {
        id: ownPreview

        objectName: "imageOwnPreview"

        visible: control.canPreview && control.previewVisible
        sources: control.canPreview ? control.previewSourceValue : []
        currentIndex: control.previewIndexValue
        previewTitle: control.previewTitleValue
        closable: control._pvBool("closable", true)
        maskClosable: control._pvBool("maskClosable", true)
        closeOnEsc: control._pvBool("closeOnEsc", true)
        infinite: control._pvBool("infinite", false)
        zoomStep: control._pvNum("zoomStep", 0.1)
        minZoom: control._pvNum("minZoom", 0.1)
        maxZoom: control._pvNum("maxZoom", 5)
        initialZoom: control._pvNum("initialZoom", 0)
        zIndex: control._pvNum("zIndex", Theme.current.zImagePreview)
        container: control._has(control.pv, "getPopupContainer")
            ? control.pv.getPopupContainer : undefined
        renderHeader: control._pvComp("renderHeader")
        renderPreviewMenu: control._pvComp("renderPreviewMenu")
        renderLeftIcon: control._pvComp("renderLeftIcon")
        renderRightIcon: control._pvComp("renderRightIcon")
        renderCloseIcon: control._pvComp("renderCloseIcon")

        onVisibleChangeRequested: function (next) {
            control.requestVisible(next);
            control._pvCall("onVisibleChange", next);
        }

        onCloseRequested: control._pvCall("onClose")

        onChanged: function (index) {
            if (!control.previewIndexControlled)
                control.previewIndexInternal = index;
            control._pvCall("onChange", index);
        }

        onPrev: function (index) {
            control._pvCall("onPrev", index);
        }

        onNext: function (index) {
            control._pvCall("onNext", index);
        }

        onZoomInRequested: function (value) {
            control._pvCall("onZoomIn", value);
        }

        onZoomOutRequested: function (value) {
            control._pvCall("onZoomOut", value);
        }

        onRatioChange: function (value) {
            control._pvCall("onRatioChange", value);
        }

        onRotateLeft: function (angle) {
            control._pvCall("onRotateLeft", angle);
        }
    }

    // ---- 对象档 preview 的取值：没给的那条落回官方 PreviewInner 的 defaultProps ----
    function _pvBool(key, fallbackValue) {
        return control._has(control.pv, key) ? Boolean(control.pv[key]) : fallbackValue;
    }

    function _pvNum(key, fallbackValue) {
        return control._has(control.pv, key) ? Number(control.pv[key]) : fallbackValue;
    }

    function _pvComp(key) {
        const value = control._has(control.pv, key) ? control.pv[key] : null;
        return value instanceof Component ? value : null;
    }

    // 对象档里的函数档回调（官方 preview.onVisibleChange 那一族）
    function _pvCall(key, arg) {
        const cb = control._has(control.pv, key) ? control.pv[key] : null;
        if (typeof cb === "function")
            cb(arg);
    }
}
