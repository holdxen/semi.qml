pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Image 图片。官方 `content/show/image/index.md` 的「代码演示」一共 10 个小节，这里逐节摆齐：
// 如何引入 / 基本用法 / 加载失败的占位图 / 渐进加载 / 自定义预览图片 / 多图预览 /
// 单独使用预览组件 / 渲染在指定容器 / 自定义预览底部操作区 / 自定义预览顶部展示区。
// （`###` 一共 13 个，余下 3 个是 Image / ImagePreview / MenuProps 三张 API 表，不进 demo。）
//
// 端口与本库其它件同名的两条改名：官方 `Image` → `ImageView`、官方 `Image.Preview` →
// `ImagePreview`（模块导出名会遮蔽内置类型，见坑 22）。
// 官方 `ImagePreview` 的 `visible` 在端口叫 `open`（`Item.visible` 是 FINAL 的 bool，
// 装不下「没给 ⇒ 非受控」那一档）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property string img1: "qrc:/qt/qml/SemiGallery/data/img/sample1.png"
    readonly property string img2: "qrc:/qt/qml/SemiGallery/data/img/sample2.png"
    readonly property string img3: "qrc:/qt/qml/SemiGallery/data/img/sample3.png"
    readonly property string img4: "qrc:/qt/qml/SemiGallery/data/img/sample4.png"
    readonly property string broken: "qrc:/qt/qml/SemiGallery/data/img/does-not-exist.png"

    property bool soloSingleOpen: false
    property bool soloGroupOpen: false
    // 「渐进加载」那节的重载开关：官方给 src 加 ?timestamp 强制重取，
    // 端口这边直接清一次 src（清空就是 loading 态，placeholder 立刻回来）再挂回去
    property bool reloading: false

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Column {
                width: 700
                spacing: 10

                Text {
                    text: "import { Image, ImagePreview } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("官方两条都在 v2.20.0 起支持；本库的 API 表没有给各属性标支持版本，"
                        + "这里也不猜。端口对应 `ImageView` 与 `ImagePreview`（名字原因见文件头）。"
                        + "`ImageView` 的 ReactNode 一律是「字符串或 Component」：`fallback: Icon {}`"
                        + " 这种内联节点接不住，要写 `fallback: Component { Icon {} }`。"
                        + "style / className / imgStyle / imgCls 不收（没有 CSS）。")
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 700
                spacing: 12

                ImageView {
                    width: 360
                    height: 200
                    src: page.img1
                }

                Note {
                    text: qsTr("`src` + `width` / `height` 就是一张能点的图。成功态官方什么都不画，"
                        + "能预览时只有 `cursor: zoom-in`（Qt 没有这个光标形状，端口用 pointing-hand 顶替）。"
                        + "两条宽高都不给时是图片的固有尺寸。点开看缩放（0.1~5）、旋转、平移、翻页。")
                }
            }
        }

        GallerySection {
            title: "加载失败的占位图"

            Column {
                width: 700
                spacing: 12

                Row {
                    spacing: 24

                    Column {
                        spacing: 6

                        Text {
                            text: qsTr("加载失败默认样式")
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }

                        ImageView {
                            width: 200
                            height: 200
                            src: page.broken
                        }
                    }

                    Column {
                        spacing: 6

                        Text {
                            text: qsTr("自定义加载失败占位图")
                            color: Theme.current.colorText1
                            font.pixelSize: Theme.current.fontSizeRegular
                        }

                        ImageView {
                            width: 200
                            height: 200
                            src: page.broken
                            fallback: Component {
                                Icon {
                                    name: "upload_error"
                                    size: 50
                                    color: Theme.current.colorDisabledText
                                }
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("默认那一份是 `IconUploadError` 24px（$width-icon-extra-large）铺在 "
                        + "fill-0 那一格里；`fallback` 支持字符串与节点两档，字符串那档官方是 "
                        + "`<img width:100% height:100%>`（铺满拉伸）。两处都是真值判断 ⇒ "
                        + "`fallback: ''` 等于没给，还是回默认图标。失败时那张 img 是 opacity 0，"
                        + "仍然占位、仍然吃点击。")
                }
            }
        }

        GallerySection {
            title: "渐进加载"

        Column {
                width: 700
                spacing: 12

                ImageView {
                    width: 300
                    height: 200
                    src: page.reloading ? "" : page.img1
                    placeholder: Component {
                        ImageView {
                            width: 300
                            height: 200
                            src: page.img3
                            preview: false
                        }
                    }
                }

                Button {
                    text: qsTr("Reload")
                    onClicked: {
                        page.reloading = true;
                        reloadTimer.restart();
                    }

                    Timer {
                        id: reloadTimer

                        interval: 600
                        onTriggered: page.reloading = false
                    }
                }

                Note {
                    text: qsTr("大图用 `placeholder` 先垫一张小的。官方那节给 src 拼了个 "
                        + "`?${timestamp}` 强制重新取图；端口这边清空一次 `src`（空 src 就是 loading 态，"
                        + "placeholder 立刻回来）再挂回去，看到的是同一件事。placeholder 那张自己也用 "
                        + "ImageView 且 `preview: false`，不然它会自己再开一层预览。")
                }
            }
        }

        GallerySection {
            title: "自定义预览图片"

            Column {
                width: 700
                spacing: 12

                ImageView {
                    width: 300
                    height: 200
                    src: page.img2
                    preview: ({ src: page.img4 })
                }

                Note {
                    text: qsTr("`preview` 可以是布尔，也可以是那张 `PreviewProps`。对象档的 `src` "
                        + "盖掉缩略图那张（官方 image.tsx:185 的 `preview.src ?? src`），"
                        + "而且它可以是个数组 ⇒ 一张缩略图也能开出一个可翻页的多图预览。"
                        + "对象档里给了 `visible` 才是受控；没给就是这张图自己记开合。")
                }
            }
        }

        GallerySection {
            title: "多图预览"

            Column {
                width: 700
                spacing: 12

                ImagePreview {
                    ImageView { width: 200; height: 130; src: page.img1 }
                    ImageView { width: 200; height: 130; src: page.img2 }
                    ImageView { width: 200; height: 130; src: page.img3 }
                    ImageView { width: 200; height: 130; src: page.img4 }
                }

                Note {
                    text: qsTr("`ImagePreview` 包住若干 `ImageView` 就是一个组：点哪张开同一层预览、"
                        + "下标落在那一张。官方那排的 5px 右距是 inline style，端口没有 style "
                        + "⇒ 组里按「横着流、放不下换行」排（官方那个 group div 本来也没有样式）。"
                        + "进组的顺序是「`preview` 为真的那些」重新编号的：中间放一张 "
                        + "`preview: false`，后面那张的 imageID 就往前挪一位。")
                }
            }
        }

        GallerySection {
            title: "单独使用预览组件"

            Column {
                width: 700
                spacing: 12

                Row {
                    spacing: 16

                    Button {
                        text: qsTr("Preview single Image")
                        onClicked: page.soloSingleOpen = true
                    }

                    Button {
                        text: qsTr("Preview multiple Images")
                        onClicked: page.soloGroupOpen = true
                    }
                }

                ImagePreview {
                    open: page.soloSingleOpen
                    src: page.img2
                    onVisibleChangeRequested: page.soloSingleOpen = visible
                }

                ImagePreview {
                    open: page.soloGroupOpen
                    src: [page.img1, page.img2, page.img3, page.img4]
                    onVisibleChangeRequested: page.soloGroupOpen = visible
                }

                Note {
                    text: qsTr("不给 children、只给 `src`（字符串或数组），预览层就独立存在，"
                        + "开关归调用方 —— 官方是 `visible` + `onVisibleChange`，端口那条叫 `open`。"
                        + "三条关闭路径发的信号不一样：点遮罩只有 `visibleChangeRequested(false)`，"
                        + "× 与 Esc 还各带一条 `closeRequested()`（previewInnerFoundation.ts 的"
                        + " :119-134 / :182-186 / :141-149）。")
                }
            }
        }

        GallerySection {
            title: "渲染在指定容器"

            Column {
                width: 700
                spacing: 12

                Rectangle {
                    id: hostBox

                    width: 700
                    height: 400
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.current.colorBorder

                    ImagePreview {
                        id: hosted

                        container: hostBox

                        ImageView { width: 200; height: 130; src: page.img1 }
                        ImageView { width: 200; height: 130; src: page.img3 }
                        ImageView { width: 200; height: 130; src: page.img4 }
                    }
                }

                Note {
                    text: qsTr("官方 `getPopupContainer` 指定预览层的父级 DOM（那一层要 position: relative）；"
                        + "端口 `container` 给一个 Item。跟着改的是浮层挂在哪个项、以及它铺满谁 —— "
                        + "`.semi-image-preview-popup` 是 `position: absolute`（image.scss:74-76），"
                        + "所以浏览器里它也被夹在这个容器内，端口同样如此。点图开预览看看遮罩只盖这一格。")
                }
            }
        }

        GallerySection {
            title: "自定义预览底部操作区"

            Column {
                width: 700
                spacing: 12

                ImagePreview {
                    renderPreviewMenu: Component {
                        CustomMenu {}
                    }

                    ImageView { width: 200; height: 130; src: page.img1 }
                    ImageView { width: 200; height: 130; src: page.img2 }
                    ImageView { width: 200; height: 130; src: page.img4 }
                }

                Note {
                    text: qsTr("官方 `renderPreviewMenu(props)` 收到的是那张 MenuProps；端口没有函数组件，"
                        + "改成往自定义节点上注入一个声明了的 `menu` 属性（值 + 那几个 on* 回调都在里面，"
                        + "同 OverflowList 的 renderer 注入约定）。给了这一条，官方连 `-content` 那个类都不加 "
                        + "⇒ padding / 底色 / 圆角 / 高这层壳一起没有，端口照做。"
                        + "官方那节 demo 解构写的是 `disableZoomIn` / `disableZoomOut`（少一个 d），"
                        + "组件实际给的是 `disabledZoomIn` / `disabledZoomOut` ⇒ 端口按组件的键名给。")
                }
            }
        }

        GallerySection {
            title: "自定义预览顶部展示区"

            Column {
                width: 700
                spacing: 12

                ImagePreview {
                    renderHeader: Component {
                        CustomHeader {}
                    }

                    ImageView {
                        width: 200
                        height: 130
                        src: page.img1
                        preview: ({ previewTitle: "lamp1" })
                    }

                    ImageView {
                        width: 200
                        height: 130
                        src: page.img2
                        preview: ({ previewTitle: "lamp2" })
                    }
                }

                Note {
                    text: qsTr("官方 `renderHeader(title)`；端口注入 `title` 属性。标题本身是每张图的 "
                        + "`preview.previewTitle`（组里按当前那张取）。不给 renderHeader 时，"
                        + "顶部就是那条 60 高、左右内边距 24 的标题带 + 右边一枚 30×30 的 ×（hover 才给 "
                        + "rgba(0,0,0,.75) 的底）。")
                }
            }
        }
    }

    // 官方 footer 那一排整条换掉的样子：官方 demo 是灰底 40 高 280 宽、七颗 tertiary 图标键。
    // 端口注入的属性名固定叫 `menu`（ImagePreviewInner.injectMenu 认的就是它）
    component CustomMenu: Rectangle {
        id: shell

        property var menu: null

        width: 300
        height: 40
        radius: 3
        color: "#80808080"

        readonly property bool canPrev: menu !== null && !menu.disabledPrev
        readonly property bool canNext: menu !== null && !menu.disabledNext

        Row {
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: [
                    { "key": "prev", "icon": "chevron_left" },
                    { "key": "next", "icon": "chevron_right" },
                    { "key": "out", "icon": "minus" },
                    { "key": "in", "icon": "plus" },
                    { "key": "ratio", "icon": "real_size_stroked" },
                    { "key": "rotate", "icon": "rotate" },
                    { "key": "download", "icon": "download" }
                ]

                delegate: IconButton {
                    required property var modelData

                    width: 32
                    height: 32
                    variant: Enums.Tertiary
                    icon: modelData.key === "ratio" && shell.menu !== null
                        && shell.menu.ratio !== "adaptation"
                        ? "window_adaption_stroked" : modelData.icon
                    enabled: modelData.key === "prev" ? shell.canPrev
                        : (modelData.key === "next" ? shell.canNext : true)
                    onClicked: {
                        if (shell.menu === null)
                            return;
                        if (modelData.key === "prev")
                            shell.menu.onPrev();
                        else if (modelData.key === "next")
                            shell.menu.onNext();
                        else if (modelData.key === "out")
                            shell.menu.onZoomOut();
                        else if (modelData.key === "in")
                            shell.menu.onZoomIn();
                        else if (modelData.key === "ratio")
                            shell.menu.onRatioClick();
                        else if (modelData.key === "rotate")
                            shell.menu.onRotateLeft();
                    }
                }
            }
        }
    }

    component CustomHeader: Rectangle {
        id: head

        property var title: null

        width: 320
        height: 32
        color: "transparent"

        Rectangle {
            anchors.centerIn: parent
            width: label.implicitWidth + 20
            height: parent.height
            color: "#000000"

            Text {
                id: label

                anchors.centerIn: parent
                text: qsTr("自定义标题：") + (head.title === null || head.title === undefined
                    ? "" : String(head.title))
                color: Theme.current.colorWhite
                font.pixelSize: Theme.current.fontSizeRegular
            }
        }
    }

    component Note: Text {
        width: 700
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
