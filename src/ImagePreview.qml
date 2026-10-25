pragma ComponentBehavior: Bound

import QtQuick

// 图片预览组 / 独立预览层。官方 `Image.Preview`（semi-ui/image/preview.tsx）——
// 它自己就是一层「把若干 ImageView 收进一个组」的壳：组里每张图点击都开**同一张**预览层，
// 下标按点击的那张走。也可以不给 children、只给 `src`，那就是「单独使用预览组件」那一节。
//
//     ImagePreview {
//         id: group
//
//         open: page.open                       // 不给就是组自己记（官方非受控那一支）
//         ImageView { src: "a.png"; preview: ({ previewTitle: "甲" }) }
//         ImageView { src: "b.png" }
//     }
//
// ------------------------------------------------------------------ 与官方的对应
//   · 官方 `PreviewProps.visible` / `currentIndex` 用「props 里有没有这个键」决定受不受控
//     （preview.tsx:135-144）。QML 探不出「这条属性写没写过」，所以这两条都做成 `var`，
//     **给了值就是受控、留 undefined 就是组自己记**（本库 CheckboxGroup / RadioGroup 的
//     `value` 同一口径）。`visible` 这个名字在 Item 上是 FINAL 的 bool，装不下「没给」
//     那一档 ⇒ 端口的开关叫 `open`。
//   · `defaultVisible` 官方是死的：preview.tsx:84 读的是 `props.currentDefaultVisible`
//     （拼错），那条 prop 永不生效 ⇒ 端口不提供（上游 bug 只记录不抄）。
//   · `defaultCurrentIndex` 只给组内状态播种一次（preview.tsx:83），官方 PreviewInner
//     自己声明了这条但忽略（previewInner.tsx:29）。
//   · `previewCls` / `previewStyle` 官方在 Preview 里映射成 children 的 className/style
//     （preview.tsx:200-204），没有 CSS ⇒ 不收。
//   · `lazyLoad` / `lazyLoadMargin` / `disableDownload` / 下载一族 / `viewerVisibleDelay` /
//     `showTooltip` 同 ImagePreviewInner 的头注释，端口不排。
//
// ------------------------------------------------------------------ 组内登记
// 官方 `loopImageIndex`（preview.tsx:161-196）只遍历**直属 children**，挑 `type.isSemiImage`
// 且 `preview` 为真的那些，按顺序发 `imageID`，并把它们的 `preview.src ?? src` 与
// `preview.previewTitle` 收进两份数组；最后 `finalSrcList = src 数组 + children 那份`
// （:207-208）—— 也就是**先排 `src` 给的，再排组里的**。端口照这个顺序，`imageID` 叫
// `groupIndex`，由这里往下写（跟 List 往条目推上下文的理由一样：条目不回读父项）。
Item {
    id: control

    // ---- 官方 PreviewProps 的受控面 ----
    property var src: undefined                        // string | string[]，排在组内那些之前
    property var open: undefined                       // 官方 visible；undefined = 非受控
    property var currentIndex: undefined               // undefined = 非受控
    property int defaultCurrentIndex: 0
    property bool infinite: false
    property bool closable: true
    property bool maskClosable: true
    property bool closeOnEsc: true
    property real zoomStep: 0.1
    property real minZoom: 0.1
    property real maxZoom: 5
    property real initialZoom: 0
    property int zIndex: Theme.current.zImagePreview
    property var container: undefined
    property Component renderHeader: null
    property Component renderPreviewMenu: null
    property Component renderLeftIcon: null
    property Component renderRightIcon: null
    property Component renderCloseIcon: null

    // ---- 官方 PreviewProps 的信号 ----
    signal visibleChangeRequested(bool visible)
    signal closeRequested()
    signal changed(int index)
    signal prev(int index)
    signal next(int index)
    signal zoomInRequested(double zoom)
    signal zoomOutRequested(double zoom)
    signal ratioChange(string ratio)
    signal rotateLeft(int angle)

    // 组自己记的那两份（非受控时用）
    property bool innerVisible: false
    property int innerIndex: 0

    readonly property bool isOpen: control.open !== undefined ? Boolean(control.open)
        : control.innerVisible
    readonly property int shownIndex: control.currentIndex !== undefined
        ? Number(control.currentIndex) : control.innerIndex
    readonly property bool isGroup: control.childCount > 0

    // 官方是 React children。这里必须让 children 仍然进 `data`（可视树）—— 写成
    // `default property list<Item>` 会把它们从可视树里摘走（parent 变 null、没有 window，
    // 鼠标事件与渲染全丢，探针实测 win=null），所以用 alias 指回 data
    default property alias groupChildren: control.data

    readonly property int childCount: control._groupImages.length

    implicitWidth: control._naturalWidth()
    implicitHeight: control.flowHeight

    // 官方预览层不显示时不占位；这层壳的几何只跟着 children 排
    onGroupChildrenChanged: control.relayout()

    // 声明式 children 到位比 groupChildrenChanged 晚一拍，完成后再登记一次
    Component.onCompleted: control.relayout()

    // 子项自己长高 / 换宽 ⇒ 重排（childrenRect 那条信号不可靠，见坑 105，这里挂尺寸监听）
    // 子项增减 ⇒ 重排。子项**自己后来变宽变高**不会自动重排（官方是文档流，天然跟着变）；
    // 组里的图都是给了 width / height 的，这一条在实际用法上碰不到
    onChildrenChanged: control.relayout()

    function relayout() {
        const images = control._groupImages;
        for (let i = 0; i < images.length; ++i) {
            images[i].groupHost = control;
            images[i].groupIndex = i;
        }
        // 官方 `.semi-image-preview-group` 那条 div **没有任何样式**，而 Image 的外壳是
        // inline-block ⇒ 组里那排图是横着流、放不下才换行。纵向堆是错的。
        const limit = control.width > 0 ? control.width : Number.MAX_VALUE;
        let x = 0;
        let y = 0;
        let rowHeight = 0;
        let widest = 0;
        // 走 children（只有可视项），别走 groupChildren —— 那是 data 的别名，
        // 里面还混着本文件声明的那只 Popup，而 Popup 也有 height（= 整块预览面）
        for (let i = 0; i < control.children.length; ++i) {
            const child = control.children[i];
            if (x > 0 && x + child.width > limit) {
                y += rowHeight;
                x = 0;
                rowHeight = 0;
            }
            child.x = x;
            child.y = y;
            x += child.width;
            rowHeight = Math.max(rowHeight, child.height);
            widest = Math.max(widest, x);
        }
        control.flowHeight = y + rowHeight;
        control.flowWidth = widest;
    }

    // 流式排完的两项尺寸（implicit 尺寸从这里取，不用 childrenRect —— 它在子项自己
    // 长高时不发信号，见坑 105）
    property real flowHeight: 0
    property real flowWidth: 0

    // 官方 loopImageIndex 的挑选条件：是 Image 且 preview 为真
    readonly property var _groupImages: {
        const out = [];
        for (let i = 0; i < control.children.length; ++i) {
            const child = control.children[i];
            if (child === null || child === undefined)
                continue;
            if (child.isImageView === true && control._previewOn(child))
                out.push(child);
        }
        return out;
    }

    function _previewOn(child) {
        const p = child.preview;
        if (p === undefined || p === null)
            return false;
        if (typeof p === "object")
            return true;
        return Boolean(p);
    }

    // finalSrcList = src 数组 + children 那份（preview.tsx:207-208，顺序就是这两支拼接）
    readonly property var sourceList: {
        const out = [];
        const extra = control.src;
        if (extra !== undefined && extra !== null) {
            if (Array.isArray(extra)) {
                for (let i = 0; i < extra.length; ++i)
                    out.push(String(extra[i]));
            } else {
                out.push(String(extra));
            }
        }
        const images = control._groupImages;
        for (let i = 0; i < images.length; ++i)
            out.push(images[i].previewSourceValue);
        return out;
    }

    readonly property int totalSources: control.sourceList.length

    // 标题按「这一张的 preview.previewTitle」取（官方 titles 与 srcList 同一趟收集）
    readonly property var titleList: {
        const out = [];
        const extra = control.src;
        const extraCount = (extra === undefined || extra === null) ? 0
            : (Array.isArray(extra) ? extra.length : 1);
        for (let i = 0; i < extraCount; ++i)
            out.push(undefined);
        const images = control._groupImages;
        for (let i = 0; i < images.length; ++i)
            out.push(images[i].previewTitleValue);
        return out;
    }

    readonly property var currentTitle: control.titleList.length > control.shownIndex
        ? control.titleList[control.shownIndex] : undefined

    // 组里的图被点：官方是先 setCurrentIndex(imageID) 再 handleVisibleChange(true)
    // （imageFoundation.ts:22-25），两条都发通知，受控与否决定动不动
    function childClicked(index) {
        const target = Math.max(0, Math.min(control.totalSources - 1, index));
        // 受控时只发通知，不动自己记的那两份（官方 preview.tsx:135-144 的 "x" in props）
        if (control.currentIndex === undefined)
            control.innerIndex = target;
        control.changed(target);
        control.requestVisible(true);
    }

    function requestVisible(next) {
        if (control.open === undefined)
            control.innerVisible = next;
        control.visibleChangeRequested(next);
    }

    // 没给宽度的时候官方是「一行摆得下就摆、摆不下换行」的块级流，这里按全部一行的自然宽
    function _naturalWidth() {
        let w = 0;
        for (let i = 0; i < control.children.length; ++i)
            w += control.children[i].width;
        return w;
    }

    ImagePreviewInner {
        id: inner

        objectName: "imagePreviewInner"

        sources: control.sourceList
        currentIndex: control.shownIndex
        previewTitle: control.currentTitle
        infinite: control.infinite
        closable: control.closable
        maskClosable: control.maskClosable
        closeOnEsc: control.closeOnEsc
        zoomStep: control.zoomStep
        minZoom: control.minZoom
        maxZoom: control.maxZoom
        initialZoom: control.initialZoom
        zIndex: control.zIndex
        container: control.container
        renderHeader: control.renderHeader
        renderPreviewMenu: control.renderPreviewMenu
        renderLeftIcon: control.renderLeftIcon
        renderRightIcon: control.renderRightIcon
        renderCloseIcon: control.renderCloseIcon
        visible: control.isOpen

        onVisibleChangeRequested: function (next) {
            control.requestVisible(next);
        }

        onCloseRequested: control.closeRequested()

        onChanged: function (index) {
            if (control.currentIndex === undefined)
                control.innerIndex = index;
            control.changed(index);
        }

        onPrev: function (index) {
            control.prev(index);
        }

        onNext: function (index) {
            control.next(index);
        }
        onZoomInRequested: function (value) {
            control.zoomInRequested(value);
        }
        onZoomOutRequested: function (value) {
            control.zoomOutRequested(value);
        }
        onRatioChange: function (value) {
            control.ratioChange(value);
        }
        onRotateLeft: function (angle) {
            control.rotateLeft(angle);
        }
    }
}
