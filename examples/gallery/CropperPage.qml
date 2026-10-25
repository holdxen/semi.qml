pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Cropper 图片裁切。官方 `content/show/cropper/index.md` 的「代码演示」一共 6 个小节，这里逐节摆齐：
// 如何引入 / 基本用法 / 自定义裁切框比例 / 受控旋转-缩放图片 / 裁切框设置 / 实时预览裁切效果。
//
// 端口与官方的几处口径差（各自写在节内说明里，完整清单在 src/Cropper.qml 文件头）：
//   · 官方 demo 的 `src` 是两张远端图（image.png / abstract.jpg）。端口的裁切要**同步读到像素**，
//     `CropperRuntime` 只认本地路径与 qrc ⇒ 这里换成 gallery 自带的两张同族资产
//     （sample1.png 480×270 是「蓝紫底 + 白椭圆」，sample4.png 是同尺寸的渐变图）。
//     远端 URL 仍然能显示、能拖能缩，只有「裁切」那一步出不来结果。
//   · `getCropperCanvas()` 返回 HTML canvas ⇒ 这里是 `cropToUrl()`（结果挂在
//     `image://semi-cropper/<md5>` 上）；官方那句 `canvas.toDataURL()` 的等价物就是它。
//   · `preview` 官方是 `() => HTMLElement`，端口收一个 `Item`：往里挂一张 Image，
//     并且会**改掉宿主的 width/height**（官方同样改 `previewContainer.style.width`）。
//   · `cropperBoxCls` / `className` / `style` / `imgProps` 收了不产出可见差异（`imgProps`
//     官方自己就没展开过）；`cropperBoxStyle` 只认 `outlineColor` 与 `backgroundColor` 两条键。
//   · 受控 `zoom` 官方那条分支被 `!isUndefined(newRotate)` 挡着（只改 zoom 不改 rotate 时不生效），
//     端口两条各自独立生效 —— 所以「缩放」那根滑杆在端口是真的能动。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property string photo: "qrc:/qt/qml/SemiGallery/data/img/sample1.png"
    readonly property string gradient: "qrc:/qt/qml/SemiGallery/data/img/sample4.png"

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
                    text: "import { Cropper } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("官方从 v2.73.0 开始提供。整套裁切交互是 Semi 手写的（`cropper/foundation.ts` 903 行，"
                        + "没有第三方依赖）：拖调整块、拖框、拖图、滚轮缩放、绕框心旋转，全在那一个文件里。"
                        + "三层各管一件事：**只有**框边那八块 10×10 的 primary 方块（`-box-corner`，各边外扩 5px，"
                        + "`round` 档只剩上下左右四块）能改框的尺寸；框内拖是挪框（尺寸与图都不动，中心夹在容器里）；"
                        + "框外那片遮罩拖的是图（`handleImgMove` 连边界都不夹）。光标也是三条：方块按方向给 resize，"
                        + "框内与遮罩都是 `move`。"
                        + "缺省值只有六条 —— `shape: 'rect'`、`defaultAspectRatio: 1`、`showResizeBox: true`、"
                        + "`fill: 'rgba(0,0,0,0)'`、`maxZoom: 3` / `minZoom: 0.1` / `zoomStep: 0.1`，"
                        + "`zoom` 与 `rotate` 都没有缺省（它们是受控值）。")
                }

                Note {
                    text: qsTr("端口这边像素走 C++（`src/CropperRuntime.cpp` 的 QImage + QPainter）：QtQuick 的 Canvas "
                        + "撑不住官方那条 getImageData / putImageData 管线 —— 实测 `drawImage(Image)` 在 cocoa 下"
                        + "什么都不画、`putImageData` 两平台都静默空操作。几何仍然全在 QML 侧算好再传进去，"
                        + "所以那套公式照样被变异扫描覆盖。")
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                id: basic

                property string shape: "rect"
                property string cropUrl: ""

                width: 700
                spacing: 12

                RadioGroup {
                    options: ["rect", "round", "roundRect"]
                    value: basic.shape
                    onChanged: function (value) {
                        basic.shape = value
                    }
                }

                Cropper {
                    id: basicCropper

                    width: 550
                    height: 300
                    src: page.photo
                    shape: basic.shape
                }

                Button {
                    text: "裁切"
                    onClicked: basic.cropUrl = basicCropper.cropToUrl()
                }

                Image {
                    width: 300
                    height: 200
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    source: basic.cropUrl
                    visible: basic.cropUrl !== ""
                }

                Note {
                    text: qsTr("「裁切」那一步官方是 `ref.current.getCropperCanvas()` + `canvas.toDataURL()`，"
                        + "端口是 `cropToUrl()`：结果图挂在自建的 `image://semi-cropper/<md5>` provider 上。"
                        + "上面那块 550×300 里，图按容器等比适配（480×270 正好铺满宽 ⇒ 上下各留 15），"
                        + "框吃 `defaultAspectRatio: 1` ⇒ 300×300 横着居中。")
                }

                Note {
                    text: qsTr("`shape` 三档里 「roundRect 在官方是个圆」：scss 只有 `-view-box-round "
                        + "{ border-radius: 50% }` 一条规则，而判断写的是 `shape.includes('round')`。"
                        + "端口照抄。差的是外面那条环与调整块 —— 那两处用的是严格等于 `shape === 'round'`，"
                        + "所以 roundRect 的环仍是方的、仍是八块。")
                }
            }
        }

        GallerySection {
            title: "自定义裁切框比例"

            Column {
                id: ratio

                property string cropUrl: ""

                width: 700
                spacing: 12

                Cropper {
                    id: ratioCropper

                    width: 550
                    height: 300
                    src: page.photo
                    aspectRatio: 3 / 4
                }

                Button {
                    text: "裁切"
                    onClicked: ratio.cropUrl = ratioCropper.cropToUrl()
                }

                Image {
                    width: 225
                    height: 200
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    source: ratio.cropUrl
                    visible: ratio.cropUrl !== ""
                }

                Note {
                    text: qsTr("`defaultAspectRatio` 只管初始那一下，拖动时比例会跟着变；`aspectRatio` 是受控比例，"
                        + "给了就把八块调整块全锁在该比例上（`getRangeForAspectChange` 那一档算法），"
                        + "并且「也参与初始尺寸」。这里 550/300 = 1.83 大于 3/4 ⇒ 走「框高 = 容器高」那一档，"
                        + "框是 225×300。")
                }
            }
        }

        GallerySection {
            title: "受控旋转/缩放图片"

            Column {
                id: controlled

                property real rotate: 0
                property real zoom: 1
                property string cropUrl: ""

                width: 700
                spacing: 12

                Cropper {
                    id: controlledCropper

                    width: 550
                    height: 300
                    src: page.photo
                    rotate: controlled.rotate
                    zoom: controlled.zoom
                    // 滚轮缩放也走这一条：官方 `onZoomChange` 把新值回灌给 state，
                    // 于是滑杆跟着滚轮动。端口同样把值写回来。
                    onZoomChange: controlled.zoom = zoom
                }

                Row {
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("旋转")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Slider {
                        width: 500
                        min: -360
                        max: 360
                        step: 1
                        value: controlled.rotate
                        onMoved: function (value) {
                            controlled.rotate = value
                        }
                    }
                }

                Row {
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("缩放")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Slider {
                        width: 500
                        min: 0.1
                        max: 3
                        step: 0.1
                        value: controlled.zoom
                        onMoved: function (value) {
                            controlled.zoom = value
                        }
                    }
                }

                Button {
                    text: "裁切"
                    onClicked: controlled.cropUrl = controlledCropper.cropToUrl()
                }

                Image {
                    width: 300
                    height: 200
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    source: controlled.cropUrl
                    visible: controlled.cropUrl !== ""
                }

                Note {
                    text: qsTr("两条都是「受控」值：官方在 `getDerivedStateFromProps` 里把它们换成「绕裁切框中心」的"
                        + "一串变换（端口是 `applyRotate` / `applyZoom`，那套「y 先取负再算」的式子照抄）。"
                        + "`zoom` 是相对「适配档」的绝对倍数，不是在当前显示尺寸上再乘一次。"
                        + "在裁切区里按住滚轮也能缩放，缩放中心就是指针那一点。")
                }

                Note {
                    text: qsTr("一处与官方的差异（官方 bug 只记录不抄）：官方那条 zoom 分支写的是 "
                        + "`!isUndefined(newRotate) && newZoom !== zoom`（index.tsx:153 用错了变量名），"
                        + "也就是「只改 zoom、不改 rotate 时受控缩放整条不生效」。端口两条各自独立生效，"
                        + "所以这里单拖动「缩放」滑杆是能动的 —— 官方那一版得同时动「旋转」才见效。")
                }
            }
        }

        GallerySection {
            title: "裁切框设置"

            Column {
                id: boxed

                property bool showResizeBox: false
                property string cropUrl: ""

                width: 700
                spacing: 12

                Text {
                    text: qsTr("showResizeBox = false，并修改边框颜色")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.DemiBold
                }

                Cropper {
                    id: boxedCropper

                    width: 550
                    height: 300
                    src: page.photo
                    showResizeBox: boxed.showResizeBox
                    // 官方 demo 写的是 { outlineColor: 'var(--semi-color-bg-0)' }：那条 1px 是 outline
                    // 而不是 border，所以能盖住它的键是 outlineColor。端口只认这一条与 backgroundColor。
                    cropperBoxStyle: ({ outlineColor: Theme.current.colorBg0 })
                }

                Row {
                    spacing: 16

                    Button {
                        text: "裁切"
                        onClicked: boxed.cropUrl = boxedCropper.cropToUrl()
                    }

                    Switch {
                        checked: boxed.showResizeBox
                        onToggled: boxed.showResizeBox = checked
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("showResizeBox")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                Image {
                    width: 300
                    height: 200
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    source: boxed.cropUrl
                    visible: boxed.cropUrl !== ""
                }

                Note {
                    text: qsTr("API 表里那行 `cropperBoxClassName` 是官网写错的，代码里的 prop 叫 `cropperBoxCls`"
                        + "（而且端口没有对应的 CSS 层，收了不产出差异）。`imgProps` 更彻底：接口与 API 表都写着"
                        + "「透传给 img 标签」，但组件从头到尾没展开过它 —— 是一条死 prop。"
                        + "`style` / `className` 同理，官方那两条只喂给 DOM。")
                }
            }
        }

        GallerySection {
            title: "实时预览裁切效果"

            Column {
                id: live

                property real rotate: 0
                property real zoom: 1
                property string cropUrl: ""

                width: 700
                spacing: 12

                Cropper {
                    id: liveCropper

                    width: 550
                    height: 300
                    src: page.gradient
                    rotate: live.rotate
                    zoom: live.zoom
                    preview: previewBox
                    onZoomChange: live.zoom = zoom
                }

                Row {
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("旋转")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Slider {
                        width: 500
                        min: -360
                        max: 360
                        step: 1
                        value: live.rotate
                        onMoved: function (value) {
                            live.rotate = value
                        }
                    }
                }

                Row {
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("缩放")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Slider {
                        width: 500
                        min: 0.1
                        max: 3
                        step: 0.1
                        value: live.zoom
                        onMoved: function (value) {
                            live.zoom = value
                        }
                    }
                }

                Row {
                    spacing: 24

                    Column {
                        spacing: 8

                        Text {
                            text: qsTr("实时预览")
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                            font.weight: Font.DemiBold
                        }

                        // 官方是 <div id='previewWrapper' style={{height: 300}} />，
                        // 组件往里 appendChild 一张 img 并实时改它的 width/height/transform。
                        Item {
                            id: previewBox

                            width: 260
                            height: 200
                        }
                    }

                    Column {
                        spacing: 8

                        Button {
                            text: "裁切"
                            onClicked: live.cropUrl = liveCropper.cropToUrl()
                        }

                        Image {
                            width: 260
                            height: 200
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            source: live.cropUrl
                            visible: live.cropUrl !== ""
                        }
                    }
                }

                Note {
                    text: qsTr("预览那一块官方分两步：`renderPreview`（图片加载完那一拍）往 `preview()` 给的节点里 "
                        + "appendChild 一张 img、「记下节点当时的尺寸」、顺手把 `overflow: hidden` 写上；"
                        + "`updatePreview`（每拍）按「预览容器 / 裁切框」的比例算 zoom，改掉那张 img 的 "
                        + "width/height/transform 「和容器自己的 width/height」。端口照这两步做，"
                        + "所以那块预览区的尺寸会被组件改掉 —— 记的是初值，不会一路缩下去。")
                }
            }
        }
    }

    // 说明里会出现 `shape.includes('round')` 这类尖括号与引号，AutoText 会把尖括号当标签吃掉 ⇒ 钉 PlainText
    component Note: Text {
        width: 700
        textFormat: Text.PlainText
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
