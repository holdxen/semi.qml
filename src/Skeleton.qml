import QtQuick

// 骨架屏容器。照 semi-ui/skeleton（`index.tsx` 的 SkeletonProps + `item.tsx` 的五个占位件）
// 和 semi-foundation/skeleton（`skeleton.scss` / `variables.scss`）。
//
//     Skeleton {
//         loading: page.busy
//         active: true
//         placeholder: Component {
//             Column {
//                 width: parent ? parent.width : 0
//                 SkeletonTitle {}
//                 SkeletonParagraph { rows: 2 }
//             }
//         }
//         Text { text: "精心打磨每一个组件的用户体验……" }
//     }
//
// 官方只有两组行为：
// - `loading` 为 true 渲染 `<div class="semi-skeleton [-active]">{placeholder}</div>`，
//   为 false 时**直接渲染 children**，那层 div 都不生成；
// - `active` 是容器上的类，靠 `.semi-skeleton-active .semi-skeleton-xxx` 后代选择器点亮里面
//   每一格的流光，所以占位件（SkeletonAvatar 等）自己没有 active 属性。
//
// 占位件挂在 placeholderHost 下面，那个盒子就是官方那层 div：宽跟着容器、高由占位件撑。
// 这里没用 Loader —— Loader 会把自己显式设置的宽高盖到载入项上（QQuickLoaderPrivate 的
// setInitialState / _q_updateSize，连载入项自己的 width 绑定都会被 takeBinding 摘掉），
// 于是 `SkeletonAvatar` 被拉成整幅宽。
//
// 与官方的差异（ReactNode / CSS 在 QML 侧无处落地）：
// - `placeholder` 收一个 Component（官方 ReactNode）。官方那层 div 是块级元素，占位内容自然
//   100% 宽、从上往下流式排；QML 侧这层排版归占位根节点自己 —— 要 100% 宽就写
//   `width: parent ? parent.width : 0`，要竖排就用 Column；
// - `style` / `className` 不提供，尺寸直接写 `width` / `height`（官方 demo 里的
//   `style={{ width: 200, height: 150 }}` 就是这里的 `width: 200; height: 150`）；
// - 容器的高由占位根节点的 `implicitHeight` 决定（官方那层 div 是 height:auto）。根节点
//   自己排版时把算出来的高度写进 `implicitHeight`，只写 `height` 容器不会跟着长；
// - children 落在一个宿主 Item 里、由调用方自己排版：宿主的宽跟着容器、**高由内容算**（官方
//   loading=false 时那层 div 不生成，children 直接摆进父级）。所以别在里面对宿主写
//   `anchors.fill` / `parent.height` —— 容器在 loading=false 时的隐式高度正是照着它算的，
//   反向依赖就成环（和 Spin 同一条）。
Item {
    id: control

    // ---- 官方 prop ----
    property bool active: false          // index.tsx 没给默认值 ⇒ false
    property bool loading: true          // index.tsx defaultProps
    property Component placeholder: null // index.tsx ReactNode

    // 官方 children
    default property alias content: contentHost.data

    // 供占位件沿父链认领（对应官方的 .semi-skeleton-active 后代选择器）
    readonly property bool isSkeletonHost: true

    // 官方 loading 时那层 div 里的节点；非 loading 时是 null（内部状态，别从外面写）
    property Item placeholderItem: null

    objectName: "skeleton"

    // 官方那个 div 是块级元素：宽度跟着父容器，除非调用方像官方 demo 那样写死
    width: control.parent ? control.parent.width : control.implicitWidth
    implicitWidth: control.placeholderItem !== null ? control.placeholderItem.implicitWidth : 0
    implicitHeight: control.loading
        ? (control.placeholderItem !== null ? control.placeholderItem.implicitHeight : 0)
        : contentHost.height

    onPlaceholderChanged: control.syncPlaceholder()
    onLoadingChanged: control.syncPlaceholder()
    Component.onCompleted: control.syncPlaceholder()

    // 官方 loading 为 false 时 placeholder 根本不进 DOM，这里直接销毁
    function syncPlaceholder() {
        if (control.placeholderItem !== null)
            control.placeholderItem.destroy();
        control.placeholderItem = control.loading && control.placeholder !== null
            ? control.placeholder.createObject(placeholderHost)
            : null;
    }

    Item {
        id: placeholderHost

        objectName: "skeletonPlaceholder"
        visible: control.loading
        width: control.width
        height: control.height
    }

    // 官方非 loading 时直接渲染 children（连容器都不生成），QML 侧总得有个宿主。
    // 高**不能**写 anchors.fill: parent —— 容器的 implicitHeight 要读这个宿主的内容高度，
    // 而没写死 height 的 Item 其 height 又回落成 implicitHeight，于是「读一次就把自己标脏」：
    // loading 一翻成 false 就刷一轮绑定环警告（值是对的，纯噪声）。宿主改成自己 hug 内容。
    Item {
        id: contentHost

        objectName: "skeletonContent"
        visible: !control.loading
        width: control.width
        height: childrenRect.height
    }
}
