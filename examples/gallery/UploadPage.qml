pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/input/upload/index.md 的 24 个演示小节。
//
// 官方另有「图片裁切」一节（6 个 demo，靠 crop 属性 + 浏览器端图片编辑器），本端口
// 没有对应的裁切面板，整节跳过，记在 PROGRESS.md。
//
// 两处为了在桌面端演示而补的数据注入（官方靠用户真的选中文件才出现）：
// · 「文件名超长省略」「默认文件列表」等小节用 defaultFileList 预先塞好条目，
//   否则页面上只有一个按钮，省略号/缩略图/进度这些形态看不见。
// · 「限制上传文件大小」用 insert() 注入一个数字 size，因为 QML 拿不到 File 对象的字节数。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方 demo 用的是三张远程图，这里对应到 gallery 自带的样图
    readonly property string imgBag: "qrc:/qt/qml/SemiGallery/data/img/sample1.png"
    readonly property string imgDy: "qrc:/qt/qml/SemiGallery/data/img/sample2.png"
    readonly property string imgResso: "qrc:/qt/qml/SemiGallery/data/img/sample3.png"

    // ------------------------------------------------------------ 小节内的受控状态
    property string avatarUrl: page.imgDy
    property int limitTwoCount: 0
    property string hotSpot: "end"
    property var controlledList: [
        { uid: "1", name: "dyBag.jpeg", status: "success", size: "130KB", preview: true, url: page.imgBag },
        { uid: "2", name: "dy.jpeg", status: "uploading", percent: 50, size: "222KB", preview: true, url: page.imgDy }
    ]
    // 官方「上传前自定义校验」用 useRef 计数：第一个文件判失败，之后放行
    property int syncCheckCount: 0
    property int asyncCheckCount: 0

    Toast { id: toast }

    function notify(text, tone) {
        if (tone === Enums.Success)
            toast.success(text);
        else if (tone === Enums.Warning)
            toast.warning(text);
        else if (tone === Enums.Danger)
            toast.error(text);
        else
            toast.info(text);
    }

    // 官方「自定义预览逻辑」第二个 demo：操作区的放大图标点开一个独立的 ImagePreview。
    // 端口就按官方那条摆：一张不受控于任何缩略图的预览层，开关与 src 都由这里驱动。
    property bool expandOpen: false
    property string expandSrc: ""

    function openExpandPreview(file) {
        page.expandSrc = String(file.url === undefined ? "" : file.url);
        page.expandOpen = true;
    }

    // 官方 demo 里的 defaultFileList，逐条照抄（远程 url 换成本地样图）
    readonly property var promptPicList: [
        { uid: "1", name: "dy.jpeg", status: "success", size: "130kb", preview: true, url: page.imgDy },
        { uid: "5", name: "resso.jpeg", percent: 50, size: "222kb", preview: true, url: page.imgResso }
    ]
    readonly property var operationList: [
        { uid: "1", name: "dyBag.png", status: "success", size: "130KB", preview: true, url: page.imgBag }
    ]
    readonly property var titleStringList: [
        { uid: "1", name: "document.pdf", status: "success", size: "130KB" },
        { uid: "2", name: "report.xlsx", status: "success", size: "222KB" }
    ]
    readonly property var previewList: [
        { uid: "1", name: "dyBag.png", status: "success", size: "130KB", url: page.imgBag },
        { uid: "2", name: "dyBag2.png", status: "success", size: "130KB", url: page.imgBag }
    ]
    readonly property var defaultList: [
        { uid: "1", name: "dyBag.jpeg", status: "success", size: "130KB", preview: true, url: page.imgBag },
        { uid: "2", name: "dyBag2.jpeg", status: "uploadFail", size: "222KB", preview: true, url: page.imgBag }
    ]
    readonly property var wallList: [
        { uid: "1", name: "dy.png", status: "success", size: "130KB", preview: true, url: page.imgDy }
    ]
    readonly property var twoPicList: [
        { uid: "1", name: "music.png", status: "success", size: "130KB", preview: true, url: page.imgResso },
        { uid: "2", name: "brand.png", status: "success", size: "130KB", preview: true, url: page.imgResso }
    ]
    readonly property var limitedPicList: [
        { uid: "1", name: "dyBag.png", status: "success", size: "130KB", preview: true, url: page.imgBag },
        { uid: "2", name: "dyBag2.jpeg", status: "success", size: "222KB", preview: true, url: page.imgBag }
    ]
    readonly property var disabledList: [
        { uid: "1", name: "first.png", status: "success", size: "130KB", preview: true, url: page.imgDy },
        { uid: "2", name: "second.png", status: "validateFail", size: "222KB", preview: true, url: page.imgDy }
    ]
    readonly property var longNameList: [
        { uid: "1", name: "Semi Design 上传组件文件名超长省略演示——2024 年度总结报告（终版）.pdf",
            status: "success", size: "130KB" }
    ]
    readonly property var widePicList: [
        { uid: "1", name: "image-1.jpg", status: "success", size: "130KB", preview: true, url: page.imgBag }
    ]

    // ------------------------------------------------------------ 公共触发区
    // 官方 children 位置大多是一颗 <Button icon={<IconUpload/>} theme="light">点击上传</Button>
    Component {
        id: uploadButton

        Button {
            text: qsTr("点击上传")
            icon: "upload"
        }
    }

    // 图片墙的 children 是 <IconPlus size="extra-large" />
    Component {
        id: wallPlus

        Icon {
            name: "plus"
            size: 24
            color: Theme.current.colorText1
        }
    }

    // 官方 prompt 节点：<div style={{display:flex,alignItems:center,color:grey}}>请上传资格认证材料</div>
    Component {
        id: promptCert

        Text {
            text: qsTr("请上传资格认证材料")
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    Component {
        id: promptAuth

        Text {
            text: qsTr("请上传认证材料")
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 420
                text: "import Semi\n\nUpload { trigger: Component { Button { text: \"点击上传\" } } }"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "基本"

            Upload {
                width: 480
                trigger: uploadButton
            }
        }

        GallerySection {
            title: "文件名超长省略"

            Column {
                spacing: 16

                Upload {
                    width: 480
                    showTooltip: false
                    defaultFileList: page.longNameList
                    trigger: uploadButton
                }

                Text {
                    text: qsTr("showTooltip 为 false：文件名截断后不弹提示")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Upload {
                    width: 480
                    showTooltip: ({ renderTooltip: true })
                    defaultFileList: page.longNameList
                    trigger: uploadButton
                }

                Text {
                    text: qsTr("showTooltip 为物件：文件名截断后弹提示（自定义 tooltip 样式本端口用组件默认的）")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "添加提示文本"

            Column {
                spacing: 16

                Row {
                    spacing: 24

                    Upload {
                        width: 240
                        prompt: promptCert
                        promptPosition: "right"
                        trigger: uploadButton
                    }

                    Upload {
                        width: 240
                        prompt: promptCert
                        promptPosition: "left"
                        trigger: uploadButton
                    }
                }

                Upload {
                    width: 480
                    prompt: promptCert
                    promptPosition: "bottom"
                    trigger: uploadButton
                }

                // 官方：listType 为 picture 时，promptPosition 的参照物是整面墙
                Row {
                    spacing: 24

                    Upload {
                        width: 240
                        listType: "picture"
                        prompt: promptAuth
                        promptPosition: "right"
                        defaultFileList: page.promptPicList
                        trigger: wallPlus
                    }

                    Upload {
                        width: 240
                        listType: "picture"
                        prompt: promptAuth
                        promptPosition: "bottom"
                        defaultFileList: page.promptPicList
                        trigger: wallPlus
                    }
                }
            }
        }

        GallerySection {
            title: "点击头像触发上传"

            Upload {
                width: 120
                accept: "image/*"
                showUploadList: false
                trigger: avatarTrigger
                onSuccess: function () {
                    page.avatarUrl = page.imgResso;
                    page.notify(qsTr("头像更新成功"), Enums.Success);
                }
                onError: function () { page.notify(qsTr("上传失败"), Enums.Danger) }
            }
        }

        GallerySection {
            title: "自定义上传属性"

            Column {
                spacing: 12

                Upload {
                    width: 480
                    formData: ({ role: "ies", time: Date.now() })
                    headers: ({ "x-tt-semi": "semi-upload" })
                    trigger: uploadButton
                }

                Text {
                    width: 480
                    wrapMode: Text.WordWrap
                    text: qsTr("本端口没有 HTTP 层，formData / headers / action 只记录不发请求；"
                        + "要接管上传请见「自定义请求」。")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "上传文件类型"

            Column {
                spacing: 16

                Upload {
                    width: 480
                    accept: "image/*"
                    trigger: Component { Button { text: qsTr("上传图片"); icon: "upload" } }
                    onAcceptInvalid: (files) => {
                        if (files.length > 0)
                            page.notify(qsTr("%1 不是图片").arg(files[0].name), Enums.Warning);
                    }
                }

                Upload {
                    width: 480
                    accept: "video/*"
                    trigger: Component { Button { text: qsTr("上传视频"); icon: "upload" } }
                    onAcceptInvalid: (files) => {
                        if (files.length > 0)
                            page.notify(qsTr("%1 不是视频").arg(files[0].name), Enums.Warning);
                    }
                }

                Upload {
                    width: 480
                    accept: ".pdf,.png,.jpeg"
                    trigger: Component { Button { text: qsTr("上传 PDF, PNG, JPEG"); icon: "upload" } }
                    onAcceptInvalid: (files) => {
                        if (files.length > 0)
                            page.notify(qsTr("%1 不在允许的类型里").arg(files[0].name), Enums.Warning);
                    }
                }
            }
        }

        GallerySection {
            title: "上传文件夹"

            Column {
                spacing: 12

                Upload {
                    width: 480
                    directory: true
                    trigger: Component { Button { text: qsTr("上传文件夹"); icon: "upload" } }
                }

                Text {
                    width: 480
                    wrapMode: Text.WordWrap
                    text: qsTr("这份 Qt 打包没有目录遍历类型，directory 只能选到文件夹本身并按一项加入。")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "一次选中多个文件"

            Upload {
                width: 480
                multiple: true
                trigger: uploadButton
            }
        }

        GallerySection {
            title: "限制文件总数量"

            Column {
                spacing: 16

                // limit 为 1：始终用最新选中的替换当前
                Upload {
                    width: 480
                    limit: 1
                    trigger: Component { Button { text: qsTr("点击上传（最多 1 项）"); icon: "upload" } }
                }

                // limit 为 2：超了触发 onExceed，选满后把触发按钮置灰
                Upload {
                    id: limitTwoUpload

                    width: 480
                    multiple: true
                    limit: 2
                    trigger: Component {
                        Button {
                            text: qsTr("点击上传（最多 2 项）")
                            icon: "upload"
                            enabled: page.limitTwoCount < 2
                        }
                    }
                    onChange: (info) => { page.limitTwoCount = info.fileList.length }
                    onExceed: function () {
                        page.notify(qsTr("最多只允许上传 2 个文件"), Enums.Warning);
                    }
                }

                // 照片墙：文件数等于 limit 时热区自动隐藏
                Upload {
                    width: 300
                    listType: "picture"
                    limit: 2
                    accept: "image/*"
                    defaultFileList: page.limitedPicList
                    trigger: wallPlus
                    onExceed: function () {
                        page.notify(qsTr("最多只允许上传 2 个文件"), Enums.Warning);
                    }
                }
            }
        }

        GallerySection {
            title: "限制上传文件大小"

            Column {
                spacing: 12

                Upload {
                    id: sizeUpload

                    width: 480
                    maxSize: 1024
                    minSize: 200
                    trigger: Component {
                        Button { text: qsTr("点击上传（最小 200KB，最大 1MB）"); icon: "upload" }
                    }
                    onSizeError: (file) => {
                        page.notify(qsTr("%1 size invalid").arg(file.name), Enums.Danger);
                    }
                }

                Row {
                    spacing: 12

                    Button {
                        text: qsTr("塞一个 2MB 的文件")
                        onClicked: sizeUpload.insert([{ path: "/demo/big.png", size: 2 * 1024 * 1024 }])
                    }

                    Button {
                        text: qsTr("塞一个 100KB 的文件")
                        onClicked: sizeUpload.insert([{ path: "/demo/small.png", size: 100 * 1024 }])
                    }
                }

                Text {
                    width: 480
                    wrapMode: Text.WordWrap
                    text: qsTr("QML 拿不到选中文件的字节数，maxSize / minSize 只对带数字 size 的项生效，"
                        + "所以这里用 insert() 注入两个大小。")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "自定义列表操作区"

            Upload {
                width: 480
                itemStyle: ({ width: 300 })
                defaultFileList: page.operationList
                renderFileOperation: operationRow
                trigger: uploadButton
            }
        }

        GallerySection {
            title: "自定义文件列表标题"

            Column {
                spacing: 20

                // 字符串形式：只换标题文字，清空按钮保持默认
                Upload {
                    width: 480
                    fileListTitle: qsTr("已上传文件")
                    defaultFileList: page.titleStringList
                    trigger: Component { Button { text: qsTr("自定义标题文字"); icon: "upload" } }
                }

                // ReactNode 形式：节点顶替标题文字，清空按钮仍然是默认的
                Upload {
                    width: 480
                    fileListTitle: styledTitleNode
                    defaultFileList: page.titleStringList
                    trigger: Component { Button { text: qsTr("带样式的标题"); icon: "upload" } }
                }

                // 函数形式：整块标题区归用户，清空按钮自己画
                Upload {
                    width: 480
                    fileListTitle: dangerClearTitle
                    defaultFileList: page.titleStringList
                    trigger: Component { Button { text: qsTr("自定义清空按钮样式"); icon: "upload" } }
                }

                Upload {
                    width: 480
                    fileListTitle: linkClearTitle
                    defaultFileList: page.titleStringList
                    trigger: Component { Button { text: qsTr("完全自定义标题区域"); icon: "upload" } }
                }
            }
        }

        GallerySection {
            title: "自定义预览逻辑"

            Column {
                spacing: 20

                // 官方 previewFile={f => f.uid === '1' ? <IconFile/> : <Image src={f.url}/>}
                Upload {
                    width: 480
                    defaultFileList: page.previewList
                    previewFile: perItemPreview
                    trigger: uploadButton
                }

                // 官方：结合 renderFileOperation 放一个放大图标
                Upload {
                    width: 480
                    itemStyle: ({ width: 300 })
                    defaultFileList: page.operationList
                    previewFile: perItemPreview
                    renderFileOperation: expandOperation
                    trigger: uploadButton
                }
            }
        }

        GallerySection {
            title: "默认文件列表"

            Upload {
                width: 480
                defaultFileList: page.defaultList
                trigger: uploadButton
            }
        }

        GallerySection {
            title: "受控组件"

            Upload {
                width: 480
                fileList: page.controlledList
                showRetry: false
                trigger: uploadButton
                onChange: (info) => { page.controlledList = info.fileList.slice() }
            }
        }

        GallerySection {
            title: "图片墙"

            Column {
                spacing: 20

                Upload {
                    width: 480
                    listType: "picture"
                    accept: "image/*"
                    multiple: true
                    defaultFileList: page.wallList
                    trigger: wallPlus
                }

                Upload {
                    width: 480
                    listType: "picture"
                    showPicInfo: true
                    accept: "image/*"
                    multiple: true
                    defaultFileList: page.twoPicList
                    trigger: wallPlus
                }
            }
        }

        GallerySection {
            title: "图片墙放大预览"

            Column {
                spacing: 20

                // 官方 renderThumbnail={(f) => <Image src={f.url} />}
                Upload {
                    width: 480
                    listType: "picture"
                    accept: "image/*"
                    multiple: true
                    defaultFileList: page.wallList
                    renderThumbnail: wallThumbnail
                    trigger: wallPlus
                }

                // 官方：renderPicPreviewIcon + onPreviewClick；showReplace 打开时不再显示预览图标
                Upload {
                    width: 480
                    listType: "picture"
                    showPicInfo: true
                    accept: "image/*"
                    multiple: true
                    defaultFileList: page.wallList
                    renderPicPreviewIcon: previewEye
                    trigger: wallPlus
                    onPreviewClick: (file) => {
                        page.notify(qsTr("预览 %1").arg(file.name), Enums.Neutral);
                    }
                }
            }
        }

        GallerySection {
            title: "图片墙设置宽高"

            Column {
                spacing: 20

                Upload {
                    width: 480
                    listType: "picture"
                    accept: "image/*"
                    multiple: true
                    picWidth: 200
                    picHeight: 110
                    defaultFileList: page.widePicList
                    renderThumbnail: wideThumbnail
                    trigger: addImageLabel
                }

                Column {
                    spacing: 12

                    RadioGroup {
                        type: Enums.ChoiceButton
                        value: page.hotSpot
                        onChanged: (v) => { page.hotSpot = String(v) }

                        Radio { value: "start"; text: "start" }
                        Radio { value: "end"; text: "end" }
                    }

                    Upload {
                        width: 480
                        listType: "picture"
                        showPicInfo: true
                        accept: "image/*"
                        multiple: true
                        hotSpotLocation: page.hotSpot
                        defaultFileList: page.wallList
                        renderPicPreviewIcon: previewEye
                        trigger: wallPlus
                        onPreviewClick: (file) => {
                            page.notify(qsTr("预览 %1").arg(file.name), Enums.Neutral);
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "禁用"

            Upload {
                width: 480
                disabled: true
                defaultFileList: page.disabledList
                trigger: Component { Button { text: qsTr("点击上传"); icon: "upload"; enabled: false } }
            }
        }

        GallerySection {
            title: "手动触发上传"

            Row {
                spacing: 8

                Upload {
                    id: manualUpload

                    width: 240
                    accept: "image/gif, image/png, image/jpeg, image/bmp, image/webp"
                    uploadTrigger: "custom"
                    trigger: Component { Button { text: qsTr("选择文件"); icon: "plus" } }
                }

                Button {
                    text: qsTr("开始上传")
                    icon: "upload"
                    onClicked: manualUpload.upload()
                }
            }
        }

        GallerySection {
            title: "拖拽上传"

            Column {
                spacing: 16

                Upload {
                    width: 480
                    draggable: true
                    dragMainText: qsTr("点击上传文件或拖拽文件到这里")
                    dragSubText: qsTr("支持任意类型文件")
                }

                Upload {
                    width: 480
                    draggable: true
                    dragIcon: "bolt"
                    accept: "application/pdf,.jpeg"
                    dragMainText: qsTr("点击上传文件或拖拽文件到这里")
                    dragSubText: qsTr("仅支持jpeg、pdf")
                }

                // 官方：children 完全自定义拖拽区（此时 .semi-upload-drag-area-custom
                // 不带边框/内边距/底色，框由 children 自己画）
                Upload {
                    id: customDragUpload

                    width: 480
                    height: 160
                    draggable: true
                    dragIcon: "bolt"
                    accept: "application/pdf,.jpeg"
                    trigger: customDragArea
                }
            }
        }

        GallerySection {
            title: "上传前自定义校验"

            Column {
                spacing: 20

                Upload {
                    width: 480
                    trigger: Component { Button { text: qsTr("点击上传（上传前同步校验）"); icon: "upload" } }
                    beforeUpload: function () {
                        // 官方 demo：第一次选中判失败，之后放行
                        const first = page.syncCheckCount === 0;
                        page.syncCheckCount = page.syncCheckCount + 1;
                        return first
                            ? { autoRemove: false, shouldUpload: false, status: "validateFail" }
                            : { autoRemove: false, shouldUpload: true };
                    }
                }

                Upload {
                    width: 480
                    trigger: Component { Button { text: qsTr("点击上传（上传前异步校验）"); icon: "upload" } }
                    beforeUpload: function () {
                        const pass = page.asyncCheckCount > 1;
                        const seq = page.asyncCheckCount + 1;
                        page.asyncCheckCount = page.asyncCheckCount + 1;
                        return new Promise(function (resolve, reject) {
                            if (pass)
                                resolve({ autoRemove: false, shouldUpload: true });
                            else
                                reject({
                                    autoRemove: false, shouldUpload: false, status: "validateFail",
                                    validateMessage: qsTr("第%1个注定失败").arg(seq)
                                });
                        });
                    }
                }
            }
        }

        GallerySection {
            title: "上传后更新文件信息"

            Column {
                spacing: 12

                Upload {
                    width: 480
                    trigger: uploadButton
                    // 没有 HTTP 层：用 customRequest 造一个官方 demo 里的成功响应
                    customRequest: function (args) { args.onSuccess({ status_code: 200 }); }
                    afterUpload: function (info) {
                        const response = info.response;
                        if (response !== undefined && response !== null && response.status_code === 200) {
                            return {
                                autoRemove: false,
                                status: "uploadFail",
                                validateMessage: qsTr("内容不合法"),
                                name: "RenameByServer.jpg",
                                url: page.imgBag
                            };
                        }
                        return {};
                    }
                }

                Text {
                    width: 480
                    wrapMode: Text.WordWrap
                    text: qsTr("afterUpload 把这一项改成上传失败：状态、校验信息、文件名和预览地址都被重写。")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "自定义请求"

            Column {
                spacing: 12

                Upload {
                    id: customRequestUpload

                    width: 480
                    multiple: true
                    trigger: uploadButton
                    customRequest: function (args) {
                        mockTimer.args = args;
                        mockTimer.count = 0;
                        mockTimer.restart();
                    }
                }

                Text {
                    width: 480
                    wrapMode: Text.WordWrap
                    text: qsTr("customRequest 接管上传：每 500ms 推进 20%，到 100% 调 onSuccess。"
                        + "进度按官方系数打 95 折，所以未满之前指针停在 95%。")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }
    }

    // ------------------------------------------------------------ 定时器
    // 官方「自定义请求」demo 用 setInterval 推进度，QML 侧用 Timer 顶替。
    Timer {
        id: mockTimer

        property var args: null
        property int count: 0
        interval: 500
        repeat: true

        onTriggered: {
            if (args === null) {
                stop();
                return;
            }
            if (count >= 100) {
                stop();
                args.onSuccess();
                return;
            }
            args.onProgress({ total: 100, loaded: count });
            count = count + 20;
        }
    }

    // 「自定义预览逻辑」第二个 demo 的放大预览层：只由 openExpandPreview() 驱动
    ImagePreview {
        id: expandPreview

        open: page.expandOpen
        src: page.expandSrc
        onVisibleChangeRequested: page.expandOpen = visible
    }

    // ------------------------------------------------------------ 钩子组件
    // 官方 renderFileOperation(fileItem)：一行三个 borderless 小图标
    Component {
        id: operationRow

        Row {
            id: operationRoot

            property var modelData: ({})
            property int index: 0
            property var onRemoveItem: function () {}
            property var onRetryItem: function () {}
            property var onReplaceItem: function () {}

            spacing: 8
            leftPadding: 8
            rightPadding: 8
            anchors.verticalCenter: parent.verticalCenter

            IconButton {
                icon: "eye_opened"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
            }

            IconButton {
                icon: "download"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
            }

            IconButton {
                icon: "delete"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
                onClicked: operationRoot.onRemoveItem()
            }
        }
    }

    // 官方「自定义预览逻辑」第二个 demo：第一个图标改成放大
    Component {
        id: expandOperation

        Row {
            id: expandRoot

            property var modelData: ({})
            property int index: 0
            property var onRemoveItem: function () {}
            property var onRetryItem: function () {}
            property var onReplaceItem: function () {}

            spacing: 8
            leftPadding: 8
            rightPadding: 8
            anchors.verticalCenter: parent.verticalCenter

            IconButton {
                icon: "expand"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
                onClicked: page.openExpandPreview(expandRoot.modelData)
            }

            IconButton {
                icon: "download"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
            }

            IconButton {
                icon: "delete"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
                onClicked: expandRoot.onRemoveItem()
            }
        }
    }

    // 点击头像触发上传：官方 <Avatar hoverMask={<IconCamera/>}/>
    Component {
        id: avatarTrigger

        Item {
            id: avatarRoot

            readonly property int side: 40

            implicitWidth: side + 8
            implicitHeight: side + 8

            HoverHandler { id: avatarHover }

            Avatar {
                id: avatar

                x: 4
                y: 4
                src: page.avatarUrl
            }

            // hoverMask：overlay-bg 圆底 + 相机图标
            Rectangle {
                x: 4
                y: 4
                width: avatarRoot.side
                height: avatarRoot.side
                radius: width / 2
                visible: avatarHover.hovered
                color: Theme.current.colorOverlayBg

                Icon {
                    anchors.centerIn: parent
                    name: "camera"
                    size: 16
                    color: Theme.current.colorWhite
                }
            }
        }
    }

    // ReactNode 形式的标题：<span style={{color:primary,fontWeight:600}}>📁 重要文件</span>
    Component {
        id: styledTitleNode

        Text {
            text: qsTr("📁 重要文件")
            color: Theme.current.colorPrimary
            font.pixelSize: Theme.current.fontSizeSmall
            font.weight: Font.DemiBold
        }
    }

    // 函数形式一：主色计数 + 一颗 danger 小按钮
    Component {
        id: dangerClearTitle

        Item {
            id: dangerTitleRoot

            property var fileList: []
            property var onClear: function () {}
            property string clearText: ""

            // 官方 demo 用 justify-content: space-between 占满整行；Loader 按隐式尺寸
            // 排布，所以宽度要写在 implicitWidth 上（Row 的 implicitWidth 只读，故用 Item）
            implicitWidth: 480
            implicitHeight: clearButton.implicitHeight

            Text {
                id: countText

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("📂 共 %1 个文件").arg(dangerTitleRoot.fileList.length)
                color: Theme.current.colorPrimary
                font.pixelSize: Theme.current.fontSizeSmall
            }

            Button {
                id: clearButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: dangerTitleRoot.clearText
                icon: "close"
                size: Enums.Small
                tone: Enums.Danger
                onClicked: dangerTitleRoot.onClear()
            }
        }
    }

    // 函数形式二：计数 + 「全部移除」文字链
    Component {
        id: linkClearTitle

        Item {
            id: linkTitleRoot

            property var fileList: []
            property var onClear: function () {}
            property string clearText: ""

            implicitWidth: 480
            implicitHeight: chosenText.implicitHeight

            Text {
                id: chosenText

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("已选择 %1 个文件").arg(linkTitleRoot.fileList.length)
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeSmall
            }

            Text {
                id: removeLink

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("全部移除")
                color: removeHover.hovered ? Theme.current.colorPrimary : Theme.current.colorLink
                font.pixelSize: Theme.current.fontSizeSmall

                HoverHandler { id: removeHover }
                TapHandler { onTapped: linkTitleRoot.onClear() }
            }
        }
    }

    // previewFile(f)：官方按 uid 三元切换图标与图片；这里把两种节点都摆在根项里，
    // 用同一个条件切 visible（Loader 再嵌一层的化，Upload 只把 modelData 注到最外层根项）
    Component {
        id: perItemPreview

        Item {
            id: previewHost

            property var modelData: ({})

            implicitWidth: 36
            implicitHeight: 36

            readonly property bool isPlainFile: String(previewHost.modelData.uid) === "1"

            Icon {
                anchors.centerIn: parent
                visible: previewHost.isPlainFile
                name: "file"
                size: 20
                color: Theme.current.colorText1
            }

            ImageView {
                anchors.fill: parent
                visible: !previewHost.isPlainFile
                src: String(previewHost.modelData.url === undefined
                    ? "" : previewHost.modelData.url)
                preview: true
            }
        }
    }

    // 图片墙缩略图：官方用 <Image src={f.url} />，这里换成可点击放大的 ImageView
    Component {
        id: wallThumbnail

        ImageView {
            id: wallThumb

            property var modelData: ({})
            property int index: 0

            width: 96
            height: 96
            src: String(wallThumb.modelData.url === undefined
                ? "" : wallThumb.modelData.url)
            preview: true
            fillMode: Image.PreserveAspectCrop
        }
    }

    Component {
        id: wideThumbnail

        ImageView {
            id: wideThumb

            property var modelData: ({})
            property int index: 0

            width: 200
            height: 110
            src: String(wideThumb.modelData.url === undefined
                ? "" : wideThumb.modelData.url)
            preview: true
            fillMode: Image.PreserveAspectCrop
        }
    }

    // 官方 renderPicPreviewIcon：<IconEyeOpened style={{color:white,fontSize:24}} />
    Component {
        id: previewEye

        Icon {
            name: "eye_opened"
            size: 24
            color: Theme.current.colorWhite
        }
    }

    // 图片墙热区里官方写的是 <IconPlus/> + 「点击添加图片」
    Component {
        id: addImageLabel

        Column {
            spacing: 4

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "plus"
                size: 24
                color: Theme.current.colorText1
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("点击添加图片")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
            }
        }
    }

    // 官方「children 完全自定义拖拽区」：图片 + 一行说明，外面的虚线框由 demo 自己画
    //（.semi-upload-drag-area-custom 不带边框/内边距/底色）
    Component {
        id: customDragArea

        Rectangle {
            id: dragRoot

            width: 480
            height: 160
            radius: Theme.current.radiusSmall
            color: dragHover.hovered
                ? Theme.current.colorPrimaryLightDefault : Theme.current.colorTertiaryLightDefault
            border.width: 0

            HoverHandler { id: dragHover }

            Canvas {
                anchors.fill: parent
                property color pen: dragHover.hovered
                    ? Theme.current.colorPrimary : Theme.current.colorBorder

                onPenChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const w = 2;
                    const half = w / 2;
                    const r = Theme.current.radiusSmall;
                    ctx.lineWidth = w;
                    ctx.strokeStyle = pen;
                    ctx.setLineDash([w * 3, w * 3]);
                    ctx.beginPath();
                    ctx.moveTo(half + r, half);
                    ctx.lineTo(width - half - r, half);
                    ctx.arcTo(width - half, half, width - half, half + r, r);
                    ctx.lineTo(width - half, height - half - r);
                    ctx.arcTo(width - half, height - half, width - half - r, height - half, r);
                    ctx.lineTo(half + r, height - half);
                    ctx.arcTo(half, height - half, half, height - half - r, r);
                    ctx.lineTo(half, half + r);
                    ctx.arcTo(half, half, half + r, half, r);
                    ctx.stroke();
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: page.imgDy
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Wow, you can really dance."
                    color: Theme.current.colorTertiary
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }
        }
    }
}
