import QtQuick
import QtTest
import Semi

// Upload：属性面照抄官方 UploadProps（semi-ui/upload/index.tsx:60-147 + :251-282），
// 状态机照抄 semi-foundation/upload/foundation.ts，几何照抄 upload.scss/variables.scss。
// 本端口没有 HTTP 层：上传由 customRequest 驱动，没给 customRequest 时选中即 success，
// 见 src/Upload.qml 文件头。
TestCase {
    id: testCase

    name: "Upload"
    when: windowShown
    width: 900
    height: 900

    property var log: []
    property var reqs: []

    function resetLog() {
        testCase.log = []
        testCase.reqs = []
    }

    function make(qml) {
        const item = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "uploadProbe")
        item.visible = true
        wait(40)          // 新建实例要过一帧才排布，否则合成点击会落在还没归位的项上
        return item
    }

    function basic() {
        return testCase.make('Upload { width: 480 }')
    }

    // 带缩略图的项：url 指到模块自带的一张 svg，避免测试里全是「Cannot open」噪音
    readonly property string imgSource: "qrc:/qt/qml/Semi/icons/file.svg"

    function pic(name) {
        return { path: "/x/" + name, type: "image/png", url: testCase.imgSource }
    }

    // 带 customRequest 的实例：把每次请求的入参攒下来，测试自己回调 onProgress/onSuccess/onError
    function mocked(extra) {
        return testCase.make('Upload { width: 480; customRequest: function (args) { testCase.reqs.push(args); }'
            + (extra === undefined ? "" : extra) + " }")
    }

    function findAll(root, name, out) {
        out = out === undefined ? [] : out
        const kids = root.children
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i].objectName === name)
                out.push(kids[i])
            findAll(kids[i], name, out)
            // qmllint enable missing-property
        }
        return out
    }

    function one(root, name) {
        const hits = findAll(root, name)
        return hits.length > 0 ? hits[0] : null
    }

    // 卡片按 uploadCard0 / uploadCard1 … 命名取，顺序才是确定的模型顺序
    // （Item.children 里 Repeater 的位置不稳定，见 PROGRESS.md 的坑）
    function cards(u) {
        const out = []
        for (let i = 0; i < 64; ++i) {
            const hit = one(u, "uploadCard" + i)
            if (hit === null)
                break
            out.push(hit)
        }
        return out
    }

    function pics(u) {
        const out = []
        for (let i = 0; i < 64; ++i) {
            const hit = one(u, "uploadPic" + i)
            if (hit === null)
                break
            out.push(hit)
        }
        return out
    }

    // 卡片自己不知道流式坐标（x/y 在宿主 Loader 上），要映射回容器再量
    function pos(u, hostName, flowName) {
        const host = one(u, hostName)
        verify(host !== null)
        const flow = one(u, flowName)
        verify(flow !== null)
        return host.mapToItem(flow, 0, 0)
    }

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
        testCase.resetLog()
    }

    // ============================================================ 默认值
    function test_defaultPropsMatchOfficial() {
        const u = basic()
        compare(u.listType, "list")
        compare(u.multiple, false)
        compare(u.disabled, false)
        compare(u.draggable, false)
        compare(u.directory, false)
        compare(u.uploadTrigger, "auto")
        compare(u.showUploadList, true)
        compare(u.showClear, true)
        compare(u.showPicInfo, false)
        compare(u.showReplace, false)
        compare(u.showRetry, true)
        compare(u.showTooltip, true)
        compare(u.hotSpotLocation, "end")
        compare(u.promptPosition, "right")
        compare(u.withCredentials, false)
        compare(u.accept, "")            // 官方 undefined
        compare(u.limit, -1)             // 官方 undefined
        compare(u.maxSize, -1)           // 官方 undefined
        compare(u.minSize, -1)           // 官方 undefined
        u.destroy()
    }

    // ============================================================ insert / 建项
    function test_insertTakesBasenameAndCompletes() {
        const u = basic()
        u.insert(["/tmp/a/b/report.pdf"])
        compare(u.items.length, 1)
        compare(u.items[0].name, "report.pdf")
        compare(u.items[0].path, "/tmp/a/b/report.pdf")
        compare(u.items[0].status, "success")
        compare(u.items[0].percent, 100)
        compare(u.items[0].uid, "u1")
        u.destroy()
    }

    function test_insertStripsFileScheme() {
        const u = basic()
        u.insert(["file:///tmp/a/b.txt"])
        compare(u.items[0].path, "/tmp/a/b.txt")
        compare(u.items[0].url, "/tmp/a/b.txt")
        u.destroy()
    }

    function test_insertAssignsUniqueUids() {
        const u = basic()
        u.insert(["/x/a.txt", "/x/b.txt", "/x/c.txt"])
        compare(u.items.length, 3)
        verify(u.items[0].uid !== u.items[1].uid)
        verify(u.items[1].uid !== u.items[2].uid)
        compare(u.items[2].uid, "u3")
        u.destroy()
    }

    function test_insertAtPosition() {
        const u = basic()
        u.insert(["/x/a.txt", "/x/c.txt"])
        u.insert(["/x/b.txt"], 1)
        compare(u.items.length, 3)
        compare(u.items[0].name, "a.txt")
        compare(u.items[1].name, "b.txt")
        compare(u.items[2].name, "c.txt")
        u.destroy()
    }

    function test_previewFlagFromExtension() {
        const u = basic()
        u.insert([pic("a.png"), "/x/b.pdf"])
        compare(u.items[0].preview, true)
        compare(u.items[1].preview, false)
        u.destroy()
    }

    function test_sizeFormattingFollowsGetFileSize() {
        const u = basic()
        u.insert([{ path: "/x/tiny.txt", size: 512 }])
        compare(u.items[0].size, "0.50KB")
        u.insert([{ path: "/x/k.txt", size: 2048 }])
        compare(u.items[1].size, "2.0KB")
        u.insert([{ path: "/x/m.bin", size: 2097152 }])
        compare(u.items[2].size, "2.0MB")
        u.insert([{ path: "/x/s.txt", size: "130kb" }])
        compare(u.items[3].size, "130kb")      // 字符串原样显示（官方 transSize）
        u.destroy()
    }

    // ============================================================ limit
    function test_limitTruncatesBatch() {
        const u = testCase.make('Upload { width: 480; limit: 2 }')
        u.insert(["/x/a.txt", "/x/b.txt"])
        compare(u.items.length, 2)
        let exceeded = null
        u.exceed.connect((files) => { exceeded = files; })
        u.insert(["/x/c.txt", "/x/d.txt"])
        compare(u.items.length, 2)
        verify(exceeded !== null)
        compare(exceeded.length, 2)            // 官方 notifyExceed 收到的是未截断的整批
        u.destroy()
    }

    function test_limitPartiallyAcceptsBatch() {
        const u = testCase.make('Upload { width: 480; limit: 3 }')
        u.insert(["/x/a.txt"])
        u.insert(["/x/b.txt", "/x/c.txt", "/x/d.txt"])
        compare(u.items.length, 3)
        compare(u.items[2].name, "c.txt")
        u.destroy()
    }

    function test_limitOneReplacesInsteadOfAppending() {
        // 官方 foundation.ts:349-360：total > limit 时先 notifyExceed，再走 limit===1 的替换分支。
        // 文档（content/input/upload/index.md:378）说 limit 为 1 不触发 onExceed，与代码不一致；
        // 这里按代码行为断言，差异记进 PROGRESS.md。
        const u = testCase.make('Upload { width: 480; limit: 1 }')
        u.insert(["/x/a.txt"])
        let exceedCount = 0
        u.exceed.connect((files) => { exceedCount = exceedCount + 1; })
        u.insert(["/x/b.txt"])
        compare(u.items.length, 1)
        compare(u.items[0].name, "b.txt")
        compare(exceedCount, 1)
        u.insert(["/x/c.txt", "/x/d.txt"])
        compare(u.items.length, 1)
        compare(u.items[0].name, "d.txt")      // 官方用最后一个替换
        u.destroy()
    }

    function test_pictureAddTileHiddenAtLimit() {
        const u = testCase.make('Upload { width: 480; listType: "picture"; limit: 1 }')
        compare(findAll(u, "uploadAddTile").length, 1)
        u.insert([pic("a.png")])
        compare(findAll(u, "uploadAddTile").length, 0)
        u.destroy()
    }

    // ============================================================ 尺寸校验
    function test_maxSizeRejectsFile() {
        const u = testCase.make('Upload { width: 480; maxSize: 1 }')
        let rejected = 0
        u.sizeError.connect((file, list) => { rejected = rejected + 1; })
        u.insert([{ path: "/x/big.txt", size: 5000 }])
        compare(rejected, 1)
        compare(u.items.length, 1)
        compare(u.items[0].status, "validateFail")
        compare(u.items[0]._sizeInvalid, true)
        u.destroy()
    }

    function test_minSizeRejectsFile() {
        const u = testCase.make('Upload { width: 480; minSize: 100 }')
        u.insert([{ path: "/x/small.txt", size: 10 }])
        compare(u.items[0].status, "validateFail")
        compare(one(cards(u)[0], "uploadMessage").text, "文件尺寸不合法")
        u.destroy()
    }

    function test_sizeCheckSkippedWhenSizeUnknown() {
        // 拿不到字节数（字符串/缺省）时不能瞎判，官方按 File.size 数字比较
        const u = testCase.make('Upload { width: 480; maxSize: 1; customRequest: function (args) { testCase.reqs.push(args); } }')
        u.insert([{ path: "/x/a.txt", size: "9MB" }])
        compare(testCase.reqs.length, 1)
        compare(u.items[0]._sizeInvalid, false)
        u.insert([{ path: "/x/b.txt" }])
        compare(testCase.reqs.length, 2)
        u.destroy()
    }

    // ============================================================ accept
    function test_acceptKeepsOnlyMatchingExtensions() {
        const u = testCase.make('Upload { width: 480; accept: ".pdf,.png" }')
        let bad = null
        u.acceptInvalid.connect((files) => { bad = files; })
        u.insert(["/x/a.txt", "/x/b.pdf", "/x/c.png"])
        compare(u.items.length, 2)
        compare(u.items[0].name, "b.pdf")
        compare(u.items[1].name, "c.png")
        verify(bad !== null)
        compare(bad.length, 1)
        compare(bad[0].name, "a.txt")
        u.destroy()
    }

    function test_acceptMimeTypeWildcard() {
        const u = testCase.make('Upload { width: 480; accept: "image/*" }')
        u.insert([{ path: "/x/a.jpg", url: testCase.imgSource }, "/x/b.pdf"])
        compare(u.items.length, 1)
        compare(u.items[0].name, "a.jpg")
        u.destroy()
    }

    function test_acceptFullMimeAndEmptyAcceptsAll() {
        const u = testCase.make('Upload { width: 480; accept: "application/pdf" }')
        u.insert(["/x/a.pdf", "/x/b.png"])
        compare(u.items.length, 1)
        compare(u.items[0].name, "a.pdf")
        u.accept = ""
        u.insert(["/x/c.txt"])
        compare(u.items.length, 2)
        u.destroy()
    }

    function test_acceptBlocksWholeBatch() {
        const u = testCase.make('Upload { width: 480; accept: ".gif" }')
        let changes = 0
        u.change.connect(() => { changes = changes + 1; })
        u.insert([pic("a.png"), "/x/b.pdf"])
        compare(u.items.length, 0)
        compare(changes, 0)
        u.destroy()
    }

    // ============================================================ uploadTrigger
    function test_customTriggerWaitsThenUploads() {
        const u = testCase.make('Upload { width: 480; uploadTrigger: "custom"; customRequest: function (args) { testCase.reqs.push(args); } }')
        u.insert(["/x/a.txt"])
        compare(u.items[0].status, "wait")
        compare(u.items[0].percent, 0)
        compare(cards(u)[0].visible, true)
        compare(testCase.reqs.length, 0)
        u.upload()
        compare(testCase.reqs.length, 1)
        // 官方只在实际收到进度时才把状态改成 uploading（handleProgress）
        compare(u.items[0].status, "wait")
        testCase.reqs[0].onProgress({ total: 100, loaded: 20 })
        compare(u.items[0].status, "uploading")
        u.destroy()
    }

    function test_autoTriggerUploadsImmediately() {
        const u = testCase.make('Upload { width: 480; customRequest: function (args) { testCase.reqs.push(args); } }')
        u.insert(["/x/a.txt"])
        compare(u.items[0].status, "uploading")
        compare(testCase.reqs.length, 1)
        u.destroy()
    }

    function test_manualUploadOnlyFlushesWaitItems() {
        const u = testCase.make('Upload { width: 480; uploadTrigger: "custom"; customRequest: function (args) { testCase.reqs.push(args); } }')
        u.insert(["/x/a.txt", "/x/b.txt"])
        u.upload()
        compare(testCase.reqs.length, 2)
        // 成功的那项不再是 wait，第二轮只补剩下那项
        testCase.reqs[0].onSuccess()
        compare(u.items[0].status, "success")
        u.upload()
        compare(testCase.reqs.length, 3)
        compare(u.items.length, 2)
        u.destroy()
    }

    // ============================================================ customRequest
    function test_customRequestDrivesProgressAndSuccess() {
        const u = mocked()
        u.insert(["/x/a.txt"])
        compare(testCase.reqs.length, 1)
        const args = testCase.reqs[0]
        compare(args.fileInstance, "/x/a.txt")
        compare(args.fileName, "a.txt")
        compare(args.action, "")
        compare(u.items[0].percent, 0)
        args.onProgress({ total: 100, loaded: 50 })
        compare(u.items[0].status, "uploading")
        compare(u.items[0].percent, 48)        // 50/100*100*0.95 → 47.5 → toFixed(0) = 48
        compare(one(cards(u)[0], "uploadProgress").visible, true)
        args.onSuccess({ code: 200 })
        compare(u.items[0].status, "success")
        compare(u.items[0].percent, 100)
        compare(u.items[0].response.code, 200)
        compare(one(cards(u)[0], "uploadProgress").visible, false)
        u.destroy()
    }

    function test_customRequestProgressZeroTotalIsZero() {
        const u = mocked()
        u.insert(["/x/a.txt"])
        u.items[0].percent = 30
        testCase.reqs[0].onProgress({ total: 0, loaded: 0 })
        compare(u.items[0].percent, 0)
        u.destroy()
    }

    function test_customRequestErrorMarksUploadFail() {
        const u = mocked()
        let errCount = 0
        u.error.connect(() => { errCount = errCount + 1; })
        u.insert(["/x/a.txt"])
        testCase.reqs[0].onError()
        compare(u.items[0].status, "uploadFail")
        compare(errCount, 1)
        // 官方：uploadFail 且没有 validateMessage 时补 locale.fail
        compare(one(cards(u)[0], "uploadMessage").text, "上传失败")
        u.destroy()
    }

    function test_customRequestSeesFormDataAndFileName() {
        const u = testCase.make('Upload { width: 480; name: "file"; formData: ({ role: "ies" }); customRequest: function (args) { testCase.reqs.push(args); } }')
        u.insert(["/x/a.txt"])
        compare(testCase.reqs[0].fileName, "file")
        compare(testCase.reqs[0].data.role, "ies")
        u.destroy()
    }

    // ============================================================ retry
    function test_retryRefiresRequest() {
        const u = mocked()
        u.insert(["/x/a.txt"])
        testCase.reqs[0].onError()
        compare(u.items[0].status, "uploadFail")
        let retried = null
        u.retried.connect((item) => { retried = item; })
        u.retry(u.items[0].uid)
        compare(testCase.reqs.length, 2)
        verify(retried !== null)
        compare(retried.status, "uploadFail")
        testCase.reqs[1].onSuccess()
        compare(u.items[0].status, "success")
        u.destroy()
    }

    function test_retryLabelOnlyOnUploadFail() {
        // 校验失败不显示重试（官方 fileCard.tsx:249 注释）；上传失败才显示
        const validate = testCase.make('Upload { width: 480; maxSize: 1 }')
        validate.insert([{ path: "/x/big.txt", size: 5000 }])
        compare(one(cards(validate)[0], "uploadRetry").visible, false)
        validate.destroy()

        const failed = mocked()
        failed.insert(["/x/a.txt"])
        testCase.reqs[0].onError()
        const label = one(cards(failed)[0], "uploadRetry")
        compare(label.visible, true)
        compare(label.text, "重试")                          // locale.retry
        compare(label.color, Theme.current.colorPrimary)      // $color-upload_retry-text
        failed.destroy()
    }

    function test_pictureRetryDiscGeometryAtRest() {
        const u = mocked('listType: "picture"')
        u.insert([pic("a.png")])
        compare(one(pics(u)[0], "uploadPicRetry").visible, false)
        testCase.reqs[0].onError()
        const disc = one(pics(u)[0], "uploadPicRetry")
        // 悬浮才可见（offscreen 无 hover，见上一个用例的注释），失败态先钉几何与配色
        compare(disc.visible, false)
        compare(disc.width, 24)                               // $width-upload_file_card_retry
        compare(disc.height, 24)
        compare(disc.color, Theme.current.colorWhite)          // $color-upload_file_card_retry-bg
        u.destroy()
    }

    // ============================================================ before* 钩子
    function test_beforeUploadFalseBlocksRequest() {
        const u = testCase.make('Upload { width: 480; beforeUpload: function () { return false; }; customRequest: function (args) { testCase.reqs.push(args); } }')
        u.insert(["/x/a.txt"])
        compare(testCase.reqs.length, 0)
        compare(u.items[0].status, "validateFail")
        compare(u.items[0].shouldUpload, false)
        u.destroy()
    }

    function test_beforeUploadTrueSendsRequest() {
        const u = testCase.make('Upload { width: 480; beforeUpload: function () { return true; }; customRequest: function (args) { testCase.reqs.push(args); } }')
        u.insert(["/x/a.txt"])
        compare(testCase.reqs.length, 1)
        compare(u.items[0].status, "uploading")
        u.destroy()
    }

    function test_beforeUploadObjectCarriesMessage() {
        const u = testCase.make('Upload { width: 480; beforeUpload: function () { return { shouldUpload: false, status: "validateFail", validateMessage: "第1个注定失败" }; } }')
        u.insert(["/x/a.txt"])
        compare(u.items[0].status, "validateFail")
        const msg = one(cards(u)[0], "uploadMessage")
        compare(msg.text, "第1个注定失败")
        // 失败卡片上的校验信息是 danger 色（$color-upload_file_card_fail_info-text）
        compare(msg.color, Theme.current.colorDanger)
        u.destroy()
    }

    function test_beforeUploadAutoRemoveDropsItem() {
        const u = testCase.make('Upload { width: 480; beforeUpload: function () { return { autoRemove: true }; } }')
        u.insert(["/x/a.txt"])
        compare(u.items.length, 0)
        u.destroy()
    }

    function test_beforeUploadGetsFileAndList() {
        const u = testCase.make('Upload { width: 480; beforeUpload: function (p) { testCase.log.push(p); return true; } }')
        u.insert(["/x/a.txt"])
        compare(testCase.log.length, 1)
        compare(testCase.log[0].file.name, "a.txt")
        compare(testCase.log[0].fileList.length, 1)
        u.destroy()
    }

    Component {
        id: asyncResolveFixture

        Upload {
            width: 480
            customRequest: function (args) { testCase.reqs.push(args); }
            beforeUpload: function () {
                return new Promise(function (resolve) {
                    resolve({ shouldUpload: true, status: "validating" });
                });
            }
        }
    }

    function test_beforeUploadAsyncResolveUploads() {
        const u = asyncResolveFixture.createObject(testCase)
        u.visible = true
        wait(40)
        u.insert(["/x/a.txt"])
        // 官方 foundation.ts:425：auto 触发时建项先给 uploading，Promise 落地才改状态
        compare(u.items[0].status, "uploading")
        compare(testCase.reqs.length, 0)        // Promise 还没落地
        // tryVerify 自己不返回布尔值：它内部直接 verify，超时才 fail（TestCase.qml:569-602）
        tryVerify(function () { return testCase.reqs.length === 1; }, 1000);
        compare(u.items[0].status, "validating")   // 收到进度之前一直是 validating
        u.destroy()
    }

    Component {
        id: asyncRejectFixture

        Upload {
            width: 480
            beforeUpload: function () {
                return new Promise(function (resolve, reject) {
                    reject({ shouldUpload: false, status: "validateFail", validateMessage: "异步不通过" });
                });
            }
        }
    }

    function test_beforeUploadAsyncRejects() {
        const u = asyncRejectFixture.createObject(testCase)
        u.visible = true
        wait(40)
        u.insert(["/x/a.txt"])
        tryVerify(function () {
            return u.items.length === 1 && u.items[0].validateMessage === "异步不通过";
        }, 1000);
        compare(u.items[0].status, "validateFail")
        compare(one(cards(u)[0], "uploadMessage").text, "异步不通过")
        u.destroy()
    }

    function test_beforeRemoveFalseKeepsItem() {
        const u = testCase.make('Upload { width: 480; beforeRemove: function () { return false; } }')
        u.insert(["/x/a.txt"])
        let removed = 0
        u.remove.connect(() => { removed = removed + 1; })
        u.removeAt(0)
        compare(u.items.length, 1)
        compare(removed, 0)
        u.destroy()
    }

    function test_beforeRemoveTrueRemoves() {
        const u = testCase.make('Upload { width: 480; beforeRemove: function () { return true; } }')
        u.insert(["/x/a.txt", "/x/b.txt"])
        let args = null
        u.remove.connect((cur, list, item) => { args = { cur: cur, len: list.length, name: item.name }; })
        u.removeAt(0)
        compare(u.items.length, 1)
        compare(u.items[0].name, "b.txt")
        compare(args.cur, "/x/a.txt")
        compare(args.len, 1)
        compare(args.name, "a.txt")
        u.destroy()
    }

    function test_beforeClearFalseKeepsList() {
        const u = testCase.make('Upload { width: 480; beforeClear: function () { return false; } }')
        u.insert(["/x/a.txt"])
        let cleared = 0
        u.cleared.connect(() => { cleared = cleared + 1; })
        u.clear()
        compare(u.items.length, 1)
        compare(cleared, 0)
        u.destroy()
    }

    function test_clearEmptiesAndFires() {
        const u = basic()
        u.insert(["/x/a.txt", "/x/b.txt"])
        let cleared = 0
        u.cleared.connect(() => { cleared = cleared + 1; })
        u.clear()
        compare(u.items.length, 0)
        compare(cleared, 1)
        compare(cards(u).length, 0)
        u.destroy()
    }

    // ============================================================ transformFile / afterUpload
    function test_transformFileRenamesBeforeUpload() {
        const u = testCase.make('Upload { width: 480; transformFile: function (f) { return { path: f.path, name: "newFileName", size: 2048 }; } }')
        u.insert(["/x/a.txt"])
        compare(u.items.length, 1)
        compare(u.items[0].name, "newFileName")
        compare(u.items[0].size, "2.0KB")
        u.destroy()
    }

    function test_afterUploadRewritesItem() {
        const u = testCase.make('Upload { width: 480; afterUpload: function () { return { status: "uploadFail", validateMessage: "内容不合法", name: "RenameByServer.jpg", url: "qrc:/qt/qml/Semi/icons/file.svg" }; } }')
        u.insert(["/x/a.txt"])
        compare(u.items[0].status, "uploadFail")
        compare(u.items[0].name, "RenameByServer.jpg")
        compare(u.items[0].url, testCase.imgSource)
        compare(one(cards(u)[0], "uploadName").text, "RenameByServer.jpg")
        compare(one(cards(u)[0], "uploadMessage").text, "内容不合法")
        u.destroy()
    }

    Component {
        id: afterUploadArgsFixture

        Upload {
            width: 480
            customRequest: function (args) { testCase.reqs.push(args); }
            afterUpload: function (p) {
                testCase.log.push(p);
                return ({});
            }
        }
    }

    function test_afterUploadSeesResponseAndFileList() {
        const u = afterUploadArgsFixture.createObject(testCase)
        u.visible = true
        wait(40)
        u.insert(["/x/a.txt"])
        testCase.reqs[0].onSuccess({ status_code: 200 })
        compare(testCase.log.length, 1)
        compare(testCase.log[0].response.status_code, 200)
        compare(testCase.log[0].file.name, "a.txt")
        compare(testCase.log[0].fileList.length, 1)
        u.destroy()
    }

    function test_afterUploadAutoRemoveDropsItem() {
        const u = testCase.make('Upload { width: 480; afterUpload: function () { return { autoRemove: true }; } }')
        u.insert(["/x/a.txt"])
        compare(u.items.length, 0)
        u.destroy()
    }

    // ============================================================ 受控
    function test_controlledFileListWinsOverInternal() {
        const u = testCase.make('Upload { width: 480; fileList: [{ uid: "k1", name: "held.pdf", status: "success", size: "1KB", percent: 100 }] }')
        compare(u.items.length, 1)
        compare(u.items[0].name, "held.pdf")
        compare(one(cards(u)[0], "uploadName").text, "held.pdf")
        u.destroy()
    }

    function test_controlledOwnerCanFeedBackOnChange() {
        const u = testCase.make('Upload { property var held: [{ uid: "k0", name: "seed.txt", status: "success" }]; fileList: held; onChange: (info) => { held = info.fileList.slice(); } }')
        u.insert(["/x/a.txt"])
        compare(u.fileList.length, 2)
        compare(u.items[1].status, "success")
        u.insert(["/x/b.txt"])
        compare(u.fileList.length, 3)
        compare(u.items[2].name, "b.txt")
        u.destroy()
    }

    function test_changeCarriesFileListAndCurrentFile() {
        const u = basic()
        u.change.connect((info) => { testCase.log.push(info); })
        // 官方 insertFileToList:550 的 notifyChange 里 currentFile 是 null
        u.insert(["/x/a.txt"])
        compare(testCase.log.length, 2)
        compare(testCase.log[0].currentFile === null, true)
        compare(testCase.log[0].fileList.length, 1)
        compare(testCase.log[1].currentFile.status, "success")
        u.destroy()
    }

    function test_pickerChangeCarriesCurrentFile() {
        // 选文件/拖拽那条路（官方 addFilesToList:467）每推一项 notifyChange 一次，带 currentFile
        const u = basic()
        u.change.connect((info) => { testCase.log.push(info); })
        u._handleChange(["/x/a.txt"])
        compare(testCase.log.length, 2)
        compare(testCase.log[0].currentFile.name, "a.txt")
        compare(testCase.log[0].fileList.length, 1)
        compare(testCase.log[1].currentFile.status, "success")
        u.destroy()
    }

    function test_successAndProgressSignals() {
        const u = basic()
        let seen = null
        u.success.connect((resp, file, list) => { seen = { r: resp, n: file.name, len: list.length }; })
        u.insert(["/x/a.txt"])
        compare(seen.n, "a.txt")
        compare(seen.len, 1)
        compare(seen.r === null, true)         // 无 HTTP 层时 response 是 null
        u.destroy()
    }

    // ============================================================ defaultFileList
    function test_defaultFileListKeepsGivenStates() {
        const u = testCase.make('Upload { width: 480; defaultFileList: [{ uid: "1", name: "dy.jpeg", status: "success", size: "130kb", url: "/img/dy.png" }, { uid: "2", name: "resso.jpeg", status: "uploading", percent: 50, size: "222kb" }] }')
        compare(u.items.length, 2)
        compare(u.items[0].status, "success")
        compare(u.items[1].status, "uploading")
        compare(u.items[1].percent, 50)
        compare(one(cards(u)[1], "uploadProgress").visible, true)
        compare(one(cards(u)[0], "uploadProgress").visible, false)
        u.destroy()
    }

    function test_defaultFileListUidKeptAndNoReupload() {
        const u = testCase.make('Upload { width: 480; customRequest: function (args) { testCase.reqs.push(args); }; defaultFileList: [{ uid: "keep", name: "a.pdf", status: "uploadFail" }] }')
        compare(u.items[0].uid, "keep")
        compare(testCase.reqs.length, 0)
        compare(cards(u).length, 1)
        u.destroy()
    }

    // 官方 index.tsx:289 把 defaultFileList 原样放进 state，不走 buildFileItem：
    // 没写 status 的项不会被补成 uploading，也就不会画进度条、不会染失败底色
    function test_defaultFileItemWithoutStatusStaysBlank() {
        const u = testCase.make('Upload { width: 480; defaultFileList: [{ uid: "1", name: "a.txt", size: "130KB" }] }')
        compare(u.items[0].status, undefined)
        compare(one(cards(u)[0], "uploadProgress").visible, false)
        compare(cards(u)[0].color, Theme.current.colorFill0)
        u.destroy()
    }

    // ============================================================ 列表标题 / 清空
    function test_titleHiddenWhenLimitIsOne() {
        const u = testCase.make('Upload { width: 480; limit: 1 }')
        u.insert(["/x/a.txt"])
        compare(one(u, "uploadTitleRow").visible, false)
        u.destroy()
    }

    function test_titleShowsChosenAndClear() {
        const u = basic()
        u.insert(["/x/a.txt", "/x/b.txt"])
        compare(one(u, "uploadTitleRow").visible, true)
        compare(one(u, "uploadChosen").text, "已选择文件")
        const clear = one(u, "uploadClear")
        compare(clear.text, "清空")
        compare(clear.visible, true)
        compare(clear.color, Theme.current.colorPrimary)       // $color-upload_clear-text
        compare(one(u, "uploadChosen").rightPadding, 8)        // title-choosen margin-right 8
        u.destroy()
    }

    function test_clearLabelHiddenWhenShowClearFalseOrDisabled() {
        const off = testCase.make('Upload { width: 480; showClear: false }')
        off.insert(["/x/a.txt", "/x/b.txt"])
        compare(one(off, "uploadClear").visible, false)
        compare(one(off, "uploadChosen").visible, true)
        off.destroy()

        const disabled = testCase.make('Upload { width: 480; disabled: true }')
        disabled.insert(["/x/a.txt", "/x/b.txt"])
        compare(one(disabled, "uploadClear").visible, false)
        disabled.destroy()
    }

    function test_clickingClearEmptiesList() {
        // 走窗口级坐标点，让命中测试和事件分发一起被覆盖
        const u = basic()
        u.insert(["/x/a.txt", "/x/b.txt"])
        wait(40)
        const label = one(u, "uploadClear")
        const at = label.mapToItem(testCase, label.width / 2, label.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(u.items.length, 0)
        u.destroy()
    }

    function test_fileListTitleStringReplacesChosenText() {
        const u = testCase.make('Upload { width: 480; fileListTitle: "重要文件" }')
        u.insert(["/x/a.txt"])
        compare(one(u, "uploadChosen").text, "重要文件")
        compare(one(u, "uploadClear").visible, true)   // 字符串形式保留默认清空按钮
        u.destroy()
    }

    Component {
        id: customTitle

        Row {
            id: customTitleRoot

            property var fileList: []
            property string clearText: ""
            property var onClear: function () {}

            objectName: "customTitleRow"

            Text {
                objectName: "customTitleText"
                anchors.verticalCenter: parent.verticalCenter
                text: "共 " + fileList.length + " 个文件"
            }

            Text {
                objectName: "customTitleClear"
                anchors.verticalCenter: parent.verticalCenter
                text: "[" + clearText + "]"
                // 只能引用 Component 内部的 id：Component 自己的 id（customTitle）在外面
                // 指的是 QQmlComponent，注入到实例上的属性它一个都没有
                TapHandler { onTapped: customTitleRoot.onClear() }
            }
        }
    }

    // 官方 ReactNode 形式（typeof !== 'function'）：只替换标题文字，清空按钮仍是默认的
    Component {
        id: plainTitleNode

        Text {
            objectName: "plainTitleNodeText"
            text: "重要文件"
            color: Theme.current.colorPrimary
            font.pixelSize: 12
        }
    }

    function test_fileListTitleNodeFormKeepsDefaultClear() {
        const u = testCase.make('Upload { width: 480; fileListTitle: plainTitleNode }')
        u.insert(["/x/a.txt"])
        wait(40)
        compare(u._titleIsFunctionForm, false)
        compare(one(u, "plainTitleNodeText").text, "重要文件")
        compare(one(u, "uploadChosen").visible, false)      // 节点顶替了标题文字
        compare(one(u, "uploadClear").visible, true)        // 清空按钮保持默认
        const clear = one(u, "uploadClear")
        const at = clear.mapToItem(testCase, 2, 2)
        mouseClick(testCase, at.x, at.y)
        compare(u.items.length, 0)
        u.destroy()
    }

    function test_fileListTitleComponentInjectsFileListAndClear() {
        const u = testCase.make('Upload { width: 480; fileListTitle: customTitle }')
        u.insert(["/x/a.txt", "/x/b.txt"])
        const row = one(u, "customTitleRow")
        verify(row !== null)
        compare(one(u, "customTitleText").text, "共 2 个文件")
        compare(one(u, "customTitleClear").text, "[清空]")
        compare(u._titleIsFunctionForm, true)
        compare(one(u, "uploadChosen").visible, false)    // 函数形式接管整块标题区
        compare(one(u, "uploadClear").visible, false)     // 默认清空按钮也不画了
        wait(40)                                          // 等一帧，位置器才把新项排好
        const at = one(u, "customTitleClear").mapToItem(testCase, 2, 2)
        mouseClick(testCase, at.x, at.y)
        compare(u.items.length, 0)
        u.destroy()
    }

    // ============================================================ 卡片几何
    function test_listCardGeometry() {
        const u = basic()
        u.insert([{ path: "/x/a.pdf", size: 2048 }])
        const card = cards(u)[0]
        compare(card.width, 250)                      // $width-upload_file_card
        compare(card.height, 52)                      // $height-upload_file_card
        compare(card.radius, Theme.current.radiusMedium)
        compare(card.color, Theme.current.colorFill0) // $color-upload_card-bg
        const preview = one(card, "uploadPreview")
        compare(preview.width, 36)                    // $width-upload_file_card_preview
        compare(preview.height, 36)
        compare(preview.x, 8)                         // $spacing-upload_file_card_preview-margin
        compare(preview.y, 8)
        compare(preview.radius, Theme.current.radiusSmall)
        const close = one(card, "uploadClose")
        compare(close.visible, true)
        verify(Math.abs(close.x + close.width - (250 - 8)) < 0.6)   // 右边界 = 250 - 8
        u.destroy()
    }

    function test_failCardUsesDangerBackground() {
        const u = basic()
        u.insert(["/x/a.txt"])
        compare(cards(u)[0].color, Theme.current.colorFill0)
        u._handleError(u.items[0].uid, { status: 500 })
        compare(cards(u)[0].color, Theme.current.colorDangerLightDefault)
        u.destroy()
    }

    function test_validateFailCardAlsoUsesDangerBackground() {
        const u = testCase.make('Upload { width: 480; maxSize: 1 }')
        u.insert([{ path: "/x/big.txt", size: 5000 }])
        compare(cards(u)[0].color, Theme.current.colorDangerLightDefault)
        u.destroy()
    }

    function test_nameElidesAndSizeSitsAfterIt() {
        const u = basic()
        u.insert([{ path: "/x/" + "verylongfilename-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf", size: "130KB" }])
        wait(40)                                      // Row 要下一帧才把 size 排到名称后面
        const card = cards(u)[0]
        const name = one(card, "uploadName")
        const size = one(card, "uploadSize")
        compare(name.elide, Text.ElideRight)
        compare(name.truncated, true)                 // 真的被截断了
        verify(size.x >= name.x + name.width)
        compare(size.leftPadding, 8)                  // $spacing-upload_file_card_info_size-marginLeft
        compare(name.font.weight, Font.DemiBold)      // $font-...-info_name-fontWeight 600
        u.destroy()
    }

    function test_listCardsWrapIntoColumns() {
        const u = testCase.make('Upload { width: 520 }')
        u.insert(["/x/a.txt", "/x/b.txt"])
        const list = cards(u)
        compare(list.length, 2)
        const p0 = pos(u, "uploadCardHost0", "uploadListFlow")
        const p1 = pos(u, "uploadCardHost1", "uploadListFlow")
        compare(p0.x, 0)
        compare(p1.x, 258)                            // 250 + gap 8
        compare(p0.y, p1.y)
        compare(one(u, "uploadListFlow").height, 52)
        u.destroy()
    }

    function test_listCardsStackWhenNarrow() {
        const u = testCase.make('Upload { width: 300 }')
        u.insert(["/x/a.txt", "/x/b.txt"])
        const list = cards(u)
        const p0 = pos(u, "uploadCardHost0", "uploadListFlow")
        const p1 = pos(u, "uploadCardHost1", "uploadListFlow")
        compare(p0.x, 0)
        compare(p1.x, 0)
        compare(p1.y, 60)                             // 52 + gap 8
        compare(one(u, "uploadListFlow").height, 112) // 52*2 + 8
        u.destroy()
    }

    function test_progressLineHiddenWhenPercentFull() {
        const u = testCase.make('Upload { width: 480; defaultFileList: [{ uid: "1", name: "a.txt", status: "uploading", percent: 100 }] }')
        compare(one(cards(u)[0], "uploadProgress").visible, false)
        u.destroy()
    }

    function test_progressLineHiddenWhenStatusNotUploading() {
        const u = testCase.make('Upload { width: 480; defaultFileList: [{ uid: "1", name: "a.txt", status: "success", percent: 50 }] }')
        compare(one(cards(u)[0], "uploadProgress").visible, false)
        u.destroy()
    }

    function test_replaceButtonOnlyWhenShowReplaceAndSuccess() {
        const u = testCase.make('Upload { width: 480; showReplace: true; customRequest: function (args) { testCase.reqs.push(args); } }')
        u.insert(["/x/a.txt"])
        testCase.reqs[0].onSuccess()
        const btn = one(cards(u)[0], "uploadReplaceBtn")
        verify(btn !== null)
        compare(btn.visible, true)
        compare(btn.width, 32)                        // margin-left 8 + 24
        u.insert(["/x/b.txt"])
        testCase.reqs[1].onError()
        compare(one(cards(u)[1], "uploadReplaceBtn").visible, false)
        u.destroy()
    }

    function test_showReplaceFalseByDefaultHidesReplaceButton() {
        const u = basic()
        u.insert(["/x/a.txt"])
        compare(one(cards(u)[0], "uploadReplaceBtn").visible, false)
        u.destroy()
    }

    function test_showUploadListFalseHidesCards() {
        const u = testCase.make('Upload { width: 480; showUploadList: false }')
        u.insert(["/x/a.txt"])
        compare(cards(u).length, 0)
        compare(u.items.length, 1)
        u.destroy()
    }

    function test_listTypeNoneRendersNoCards() {
        const u = testCase.make('Upload { width: 480; listType: "none" }')
        u.insert(["/x/a.txt"])
        compare(cards(u).length, 0)
        compare(pics(u).length, 0)
        compare(u.items.length, 1)
        u.destroy()
    }

    function test_disabledKeepsCardsAndBlocksActions() {
        const u = basic()
        u.insert(["/x/a.txt"])
        u.disabled = true
        let removed = 0
        u.remove.connect(() => { removed = removed + 1; })
        u.removeAt(0)
        compare(u.items.length, 1)
        compare(removed, 0)
        let opened = 0
        u.dialogOpened.connect(() => { opened = opened + 1; })
        u.openFileDialog()
        compare(opened, 0)
        // 官方 handleClear 里 disabled 直接 return，列表保持不变
        u.clear()
        compare(u.items.length, 1)
        u.destroy()
    }

    // ============================================================ 图片墙
    function test_pictureTileGeometry() {
        const u = testCase.make('Upload { width: 480; listType: "picture" }')
        u.insert([pic("a.png")])
        const tiles = pics(u)
        compare(tiles.length, 1)
        compare(tiles[0].width, 96)                   // $width-upload_file_pic_card
        compare(tiles[0].height, 96)
        const add = one(u, "uploadAddTile")
        verify(add !== null)
        compare(add.width, 96)
        compare(add.height, 96)
        const addAt = pos(u, "uploadAddTileHost", "uploadWall")
        compare(addAt.x, 104)                         // end：热区排在卡片之后
        compare(addAt.y, 0)
        u.destroy()
    }

    function test_pictureHotSpotStartPutsAddTileFirst() {
        const u = testCase.make('Upload { width: 480; listType: "picture"; hotSpotLocation: "start" }')
        u.insert([pic("a.png")])
        compare(pos(u, "uploadAddTileHost", "uploadWall").x, 0)
        compare(pos(u, "uploadPicHost0", "uploadWall").x, 104)
        u.destroy()
    }

    function test_picturePicInfoShowsIndexByDefault() {
        const u = testCase.make('Upload { width: 480; listType: "picture"; showPicInfo: true }')
        u.insert([pic("a.png"), pic("b.png")])
        const bar0 = one(pics(u)[0], "uploadPicInfo")
        const bar1 = one(pics(u)[1], "uploadPicInfo")
        verify(bar0 !== null)
        compare(bar0.visible, true)
        compare(bar0.height, 24)                      // pic-info 高 24
        compare(bar0.width, 96)
        compare(bar0.y, 96 - 24)                      // 贴底
        compare(findAll(bar0, "uploadPicInfoText")[0].text, "1")
        compare(findAll(bar1, "uploadPicInfoText")[0].text, "2")
        u.destroy()
    }

    function test_picturePicInfoHiddenByDefault() {
        const u = testCase.make('Upload { width: 480; listType: "picture" }')
        u.insert([pic("a.png")])
        compare(one(pics(u)[0], "uploadPicInfo").visible, false)
        u.destroy()
    }

    // 悬浮才显示的那些层（close / 重试圆盘 / 替换）在 offscreen 拿不到 hover：
    // 实测 mouseMove 不会触发 HoverHandler。这里钉住「默认不可见 + 几何 + 配色」，
    // 悬浮态由 cocoa 截图那一轮复核。
    function test_pictureCloseGeometryAtRest() {
        const u = testCase.make('Upload { width: 480; listType: "picture" }')
        u.insert([pic("a.png")])
        const close = one(pics(u)[0], "uploadPicClose")
        compare(close.visible, false)                 // 官方 visibility:hidden，悬浮才显示
        compare(close.x, 96 - 16 - 8)                 // close-right 8
        compare(close.y, 8)                           // close-top 8
        compare(close.size, 16)                       // $width-upload_picture_file_card_close
        compare(close.color, Theme.current.colorWhite)
        u.destroy()
    }

    function test_pictureOverlayVisibleOnHoverAndWhileUploading() {
        const u = mocked('listType: "picture"')
        u.insert([pic("a.png")])
        const overlay = one(pics(u)[0], "uploadPicOverlay")
        verify(overlay !== null)
        compare(overlay.visible, true)                // uploading 时官方 ::before 常显
        compare(overlay.color, Theme.current.colorOverlayBg)
        testCase.reqs[0].onSuccess()
        compare(one(pics(u)[0], "uploadPicOverlay").visible, false)
        u.destroy()
    }

    function test_pictureErrorBorderOnUploadFail() {
        const u = mocked('listType: "picture"')
        u.insert([pic("a.png")])
        compare(one(pics(u)[0], "uploadPicErrorRing").visible, false)
        testCase.reqs[0].onError()
        const ring = one(pics(u)[0], "uploadPicErrorRing")
        compare(ring.visible, true)
        compare(ring.border.color, Theme.current.colorDanger)
        compare(ring.border.width, 1)
        u.destroy()
    }

    function test_pictureCircleProgressWhileUploading() {
        const u = mocked('listType: "picture"')
        u.insert([pic("a.png")])
        // 官方：uploading 且 percent !== 100 就画圆环（fileCard.tsx:156）
        const ring = one(pics(u)[0], "uploadPicProgress")
        compare(ring.visible, true)
        compare(ring.width, 24)                       // Progress size=small 圆环直径 24
        compare(ring.height, 24)
        testCase.reqs[0].onSuccess()
        compare(one(pics(u)[0], "uploadPicProgress").visible, false)
        u.destroy()
    }

    function test_pictureTileSizeFromPicWidthHeight() {
        const u = testCase.make('Upload { width: 480; listType: "picture"; picWidth: 200; picHeight: 110 }')
        u.insert([pic("a.png")])
        compare(pics(u)[0].width, 200)
        compare(pics(u)[0].height, 110)
        compare(one(u, "uploadAddTile").width, 200)
        compare(one(u, "uploadAddTile").height, 110)
        u.destroy()
    }

    function test_wallWrapsTilesIntoRows() {
        const wide = testCase.make('Upload { width: 300; listType: "picture" }')
        wide.insert([pic("a.png"), pic("b.png")])
        wait(40)
        // 300 宽放得下两张 96 + 8 间距（还有热区占第三格）
        const w0 = pos(wide, "uploadPicHost0", "uploadWall")
        const w1 = pos(wide, "uploadPicHost1", "uploadWall")
        compare(w0.x, 0)
        compare(w1.x, 104)
        compare(w0.y, w1.y)
        wide.destroy()

        const narrow = testCase.make('Upload { width: 100; listType: "picture" }')
        narrow.insert([pic("a.png"), pic("b.png")])
        wait(40)
        const n0 = pos(narrow, "uploadPicHost0", "uploadWall")
        const n1 = pos(narrow, "uploadPicHost1", "uploadWall")
        compare(n0.y, 0)
        compare(n1.y, 104)                              // 96 + gap 8
        narrow.destroy()
    }

    // ============================================================ prompt / 触发区
    function test_dragAreaDefaultTexts() {
        const u = testCase.make('Upload { width: 480; draggable: true }')
        const drag = one(u, "uploadDrag")
        verify(drag !== null)
        const main = one(drag, "uploadDragMain")
        compare(main.text, "点击上传文件或拖拽文件到这里")
        // 主文案盒高 = 行高 20 + 上 4 + 下 4（$spacing-upload_drag_area_main_text-marginBottom），
        // 副文案就贴在这个盒底，那 4px 是主文案盒内的下内缩
        compare(main.height, 28)
        compare(one(drag, "uploadDragSub").visible, false)     // 官方 dragSubText 无默认值
        compare(one(drag, "uploadDragTips").visible, false)
        compare(drag.color, Theme.current.colorTertiaryLightDefault)  // $color-upload_drag_area-bg
        compare(drag.border.width, 0)                            // 虚线由 Canvas 画
        u.destroy()
    }

    function test_dragAreaLegalStateHidesSubText() {
        const u = testCase.make('Upload { width: 480; draggable: true; dragMainText: "把日志拖到这里"; dragSubText: "仅 .log" }')
        const drag = one(u, "uploadDrag")
        compare(one(drag, "uploadDragMain").text, "把日志拖到这里")
        compare(one(drag, "uploadDragSub").visible, true)
        // 这里直接调组件自己的状态开关，只验证「legal 态的显示规则」；
        // 真实拖拽的 DropArea 命中与事件分发不在本用例覆盖范围内。
        u._setDragStatus("legal")
        compare(one(drag, "uploadDragSub").visible, false)      // 官方 legal 时隐藏 sub-text
        const tips = one(drag, "uploadDragTips")
        compare(tips.visible, true)
        compare(tips.text, "松手开始上传")
        compare(tips.color, Theme.current.colorPrimary)
        compare(drag.color, Theme.current.colorPrimaryLightDefault)
        compare(drag.border.width, 0)
        u.destroy()
    }

    // 官方 draggable + children：.semi-upload-drag-area-custom 去掉边框/内边距/底色，
    // 默认的图标 + 主副文案 + tips 全部不画（upload.scss:407-417、index.tsx:1042）
    function test_dragAreaChildrenReplaceDefaultContent() {
        const plain = testCase.make('Upload { width: 480; draggable: true }')
        compare(one(plain, "uploadDragCustom").active, false)
        compare(one(plain, "uploadDragMain").visible, true)
        plain.destroy()

        const u = testCase.make('Upload { width: 480; draggable: true; trigger: Component { Rectangle { width: 200; height: 100; color: "transparent" } } }')
        const drag = one(u, "uploadDrag")
        compare(one(u, "uploadDragCustom").active, true)
        verify(one(u, "uploadDragCustom").item !== null)
        compare(one(drag, "uploadDragMain").visible, false)
        compare(one(drag, "uploadDragSub").visible, false)
        compare(one(drag, "uploadDragTips").visible, false)
        compare(drag.color, Qt.rgba(0, 0, 0, 0))
        compare(drag.height, 100)                             // padding 0：高度就是 children 的高度
        compare(findAll(u, "uploadTrigger").length, 1)        // children 只被实例化一次
        u.destroy()
    }

    function test_triggerSlotReplacesDragAreaInListMode() {
        const plain = basic()
        compare(one(plain, "uploadDrag").visible, false)
        compare(one(plain, "uploadTrigger").visible, false)   // 官方 children 为空时不画任何东西
        plain.destroy()

        const u = testCase.make('Upload { width: 480; trigger: Component { Button { text: "点击上传" } } }')
        const slot = one(u, "uploadTrigger")
        compare(slot.visible, true)
        verify(slot.width > 0)
        u.destroy()
    }

    function test_draggablePictureKeepsAddTile() {
        // picture 模式下触发区就是墙上的热区，拖拽时热区也接受落下
        const u = testCase.make('Upload { width: 480; listType: "picture"; draggable: true }')
        // picture 模式不画拖拽区（触发区就是墙上的热区）
        compare(one(u, "uploadDrag").visible, false)
        compare(findAll(u, "uploadAddTile").length, 1)
        u.destroy()
    }

    function test_promptPositions() {
        // prompt 挂在 headLine 上、触发区挂在 mainBlock 上，必须换算到同一坐标系再比
        const bare = testCase.make('Upload { width: 480; trigger: Component { Button { text: "点击上传" } } }')
        const bareH = bare.implicitHeight

        const right = testCase.make('Upload { width: 480; prompt: "请上传资格认证材料"; trigger: Component { Button { text: "点击上传" } } }')
        const promptR = one(right, "uploadPrompt")
        const trigR = one(right, "uploadTrigger").mapToItem(right, 0, 0)
        compare(promptR.visible, true)
        const trigRAt = one(right, "uploadTrigger").mapToItem(right, one(right, "uploadTrigger").width, 0)
        verify(promptR.mapToItem(right, 0, 0).x >= trigRAt.x)     // 官方 right：prompt 紧跟触发区
        // 同行不撑高度：headLine 取 max(触发区, prompt)
        compare(right.implicitHeight, bareH)
        right.destroy()

        const left = testCase.make('Upload { width: 480; promptPosition: "left"; prompt: "提示"; trigger: Component { Button { text: "点击上传" } } }')
        const promptL = one(left, "uploadPrompt").mapToItem(left, 0, 0)
        const trigL = one(left, "uploadTrigger").mapToItem(left, 0, 0)
        compare(promptL.x, 0)
        verify(trigL.x > promptL.x + 8)                           // order:-1，触发区整体右移
        left.destroy()

        const below = testCase.make('Upload { width: 480; promptPosition: "bottom"; prompt: "提示"; trigger: Component { Button { text: "点击上传" } } }')
        const promptB = one(below, "uploadPrompt")
        const promptBat = promptB.mapToItem(below, 0, 0)
        const trigBItem = one(below, "uploadTrigger")
        const trigBBottom = trigBItem.mapToItem(below, 0, trigBItem.height)
        compare(promptBat.x, 0)                                   // 另起一行后从 0 开始
        verify(promptBat.y >= trigBBottom.y)                      // flex-basis:100%，另起一行
        // bottom 是真占一行的：headLine = 触发区高 + prompt 高，少一行就会被当成 inline
        compare(below.implicitHeight, bareH + promptB.implicitHeight)
        below.destroy()
        bare.destroy()

        // bottom 时触发区仍占满整行；错判成 inline 会按 prompt 宽度扣掉一行宽
        const belowDrag = testCase.make('Upload { width: 480; draggable: true; promptPosition: "bottom"; prompt: "提示" }')
        compare(one(belowDrag, "uploadDrag").width, 480)
        belowDrag.destroy()

        const rightDrag = testCase.make('Upload { width: 480; draggable: true; prompt: "提示" }')
        verify(one(rightDrag, "uploadDrag").width < 480)
        rightDrag.destroy()
    }

    function test_promptHiddenWhenAbsent() {
        const u = testCase.make('Upload { width: 480; trigger: Component { Button { text: "点击上传" } } }')
        compare(one(u, "uploadPrompt").visible, false)
        u.destroy()
    }

    function test_picturePromptAnchorsToWholeWall() {
        // 官方：listType 为 picture 时，promptPosition 的参照物是整面墙（upload.scss:57-95）
        const two = '[{ uid: "1", name: "a.png", status: "success" }, { uid: "2", name: "b.png", status: "success" }]'
        const right = testCase.make('Upload { width: 240; listType: "picture"; prompt: "请上传认证材料";'
            + ' promptPosition: "right"; defaultFileList: ' + two + ' }')
        const rPrompt = one(right, "uploadPrompt")
        const rWall = one(right, "uploadWall")
        compare(rWall.height, 200)                              // 2 列 × 2 行：96 + 8 + 96
        compare(rPrompt.x, rWall.width)                          // 另起一列，贴在墙的右边
        verify(Math.abs(rPrompt.y - (rWall.height - rPrompt.height) / 2) <= 1)   // 同行 → 垂直居中
        compare(right.implicitHeight, rWall.height)              // 同行不撑高
        right.destroy()

        const below = testCase.make('Upload { width: 240; listType: "picture"; prompt: "请上传认证材料";'
            + ' promptPosition: "bottom"; defaultFileList: ' + two + ' }')
        const bPrompt = one(below, "uploadPrompt")
        const bWall = one(below, "uploadWall")
        compare(bPrompt.x, 0)                                    // flex-basis:100%，整行从 0 开始
        compare(bPrompt.y, bWall.height)                          // 另起一行，贴在墙的下面
        compare(below.implicitHeight, bWall.height + bPrompt.implicitHeight)
        below.destroy()
    }

    function test_geometryDoesNotFollowAncestorVisibility() {
        // Loader.active 不能绑 visible：QML 读回来的 visible 是「有效可见性」
        // （qquickitem.cpp:6657 返回 effectiveVisible），祖先一隐藏就把实例化关掉，
        // headLine 高度跟着窗口显隐抖
        const shown = testCase.make('Upload { width: 480; prompt: "提示"; trigger: Component { Button { text: "x" } } }')
        const shownH = shown.implicitHeight
        verify(shownH > 0)
        shown.destroy()

        testCase.visible = false
        const hidden = testCase.make('Upload { width: 480; prompt: "提示"; trigger: Component { Button { text: "x" } } }')
        verify(one(hidden, "uploadPrompt").implicitHeight > 0)
        compare(hidden.implicitHeight, shownH)
        testCase.visible = true
        hidden.destroy()
    }

    function test_rootValidateMessageRendered() {
        const u = testCase.make('Upload { width: 480; validateMessage: "整体校验不通过" }')
        const msg = one(u, "uploadValidateMessage")
        compare(msg.visible, true)
        compare(msg.text, "整体校验不通过")
        compare(msg.color, Theme.current.colorDanger)
        u.destroy()
    }

    // ============================================================ 自定义渲染钩子
    Component {
        id: customOperation

        Row {
            id: customOperationRoot

            property var modelData: ({})
            property int index: 0
            property var onRemoveItem: function () {}
            property var onRetryItem: function () {}
            property var onReplaceItem: function () {}

            objectName: "customOperationRow"

            IconButton {
                objectName: "customPreviewBtn"
                icon: "eye_opened"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
            }

            IconButton {
                objectName: "customRemoveBtn"
                icon: "delete"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
                onClicked: customOperationRoot.onRemoveItem()
            }
        }
    }

    Component {
        id: wideOperation

        // gallery「自定义列表操作区」那一节的形状：三颗按钮 + 左右各 8 内缩，
        // 比默认那颗关闭按钮宽得多，用来盯「操作区变宽时压缩的是信息区」
        Row {
            id: wideOperationRoot

            property var modelData: ({})
            property int index: 0
            property var onRemoveItem: function () {}
            property var onRetryItem: function () {}
            property var onReplaceItem: function () {}

            objectName: "wideOperationRow"
            spacing: 8
            leftPadding: 8
            rightPadding: 8

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
                objectName: "wideRemoveBtn"
                icon: "delete"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
                onClicked: wideOperationRoot.onRemoveItem()
            }
        }
    }

    function test_wideOperationAreaShrinksInfoInsteadOfOverlapping() {
        // 官方右侧操作区是 flex 项、信息区 flex:1 + min-width:0：
        // 操作区宽了要压信息区（名称跟着省略），不能让它俩叠在一起
        const u = testCase.make('Upload { width: 480; renderFileOperation: wideOperation }')
        u.insert([{ path: "/x/semi-design-upload-file-name.txt", size: "130KB" }])
        wait(40)
        const card = cards(u)[0]
        const info = one(card, "uploadInfo")
        const op = one(card, "uploadOperation")
        verify(op.implicitWidth > 80)
        const infoRight = info.mapToItem(card, info.width, 0).x
        const opLeft = op.mapToItem(card, 0, 0).x
        verify(infoRight <= opLeft)
        // 名称跟着被压短（不是还占着整行）
        const name = one(card, "uploadName")
        verify(name.width > 0)
        verify(name.width < info.width)
        compare(name.elide, Text.ElideRight)
        u.destroy()
    }

    function test_defaultCloseButtonKeepsInfoWidth() {
        // 没给 renderFileOperation 时按那颗默认关闭按钮留位：250 − 36 − 16 − (16+24) = 158
        const u = testCase.make('Upload { width: 480 }')
        u.insert([{ path: "/x/a.txt", size: "130KB" }])
        wait(40)
        const card = cards(u)[0]
        compare(card.width, 250)
        compare(one(card, "uploadInfo").width, 158)
        u.destroy()
    }

    function test_renderFileOperationReplacesCloseButton() {
        const u = testCase.make('Upload { width: 480; renderFileOperation: customOperation }')
        u.insert(["/x/a.txt"])
        wait(40)
        const card = cards(u)[0]
        compare(one(card, "uploadClose").visible, false)         // 默认关闭按钮让位给操作区
        verify(one(card, "customPreviewBtn") !== null)
        // 注入的 modelData/index 在钩子根项上，不是每个子项
        const row = one(card, "customOperationRow")
        compare(row.modelData.name, "a.txt")
        compare(row.index, 0)
        const removeBtn = one(card, "customRemoveBtn")
        const at = removeBtn.mapToItem(testCase, removeBtn.width / 2, removeBtn.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(u.items.length, 0)
        u.destroy()
    }

    Component {
        id: customFileItem

        Rectangle {
            id: customFileItemRoot

            property var modelData: ({})
            property int index: 0
            property real cardWidth: 250
            property real cardHeight: 52
            property real tileWidth: 96
            property real tileHeight: 96
            property var onRemoveItem: function () {}
            property var onRetryItem: function () {}
            property var onReplaceItem: function () {}

            objectName: "customFileItemRect"
            width: 120
            height: 40
            color: Theme.current.colorFill0

            Text {
                objectName: "customFileItemName"
                text: "自定义：" + (modelData.name === undefined ? "" : modelData.name)
            }

            TapHandler { onTapped: customFileItemRoot.onRemoveItem() }
        }
    }

    function test_renderFileItemOverridesListCards() {
        const u = testCase.make('Upload { width: 480; renderFileItem: customFileItem }')
        u.insert(["/x/a.txt"])
        wait(40)
        const item = one(u, "customFileItemRect")
        verify(item !== null)
        compare(cards(u).length, 0)
        compare(one(item, "customFileItemName").text, "自定义：a.txt")
        const at = item.mapToItem(testCase, 2, item.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(u.items.length, 0)
        u.destroy()
    }

    function test_renderFileItemOverridesPictureTiles() {
        const u = testCase.make('Upload { width: 480; listType: "picture"; renderFileItem: customFileItem }')
        u.insert([pic("a.png")])
        compare(pics(u).length, 0)
        compare(findAll(u, "customFileItemRect").length, 1)
        u.destroy()
    }

    Component {
        id: customThumb

        Rectangle {
            property var modelData: ({})
            property int index: 0

            objectName: "customThumbRect"
            anchors.fill: parent
            color: Theme.current.colorPrimaryLightDefault
        }
    }

    function test_renderThumbnailReplacesImage() {
        const u = testCase.make('Upload { width: 480; listType: "picture"; renderThumbnail: customThumb }')
        u.insert([pic("a.png")])
        const tile = pics(u)[0]
        verify(one(tile, "customThumbRect") !== null)
        compare(one(tile, "uploadPicThumb").visible, false)
        u.destroy()
    }

    Component {
        id: customPicInfo

        Text {
            property var modelData: ({})
            property int index: 0

            objectName: "customPicInfoText"
            text: "第 " + (index + 1) + " 张"
        }
    }

    function test_renderPicInfoOverridesIndexBar() {
        const u = testCase.make('Upload { width: 480; listType: "picture"; showPicInfo: true; renderPicInfo: customPicInfo }')
        u.insert([pic("a.png")])
        const tile = pics(u)[0]
        compare(one(tile, "customPicInfoText").text, "第 1 张")
        compare(one(tile, "uploadPicInfo").visible, false)   // 默认序号条让位
        u.destroy()
    }

    Component {
        id: customPreviewIcon

        Icon {
            property var modelData: ({})

            objectName: "customPreviewIconNode"
            name: "eye_opened"
            size: 24
            color: Theme.current.colorWhite
        }
    }

    function test_picturePreviewIconNeedsRenderPicPreviewIcon() {
        // 官方 hover 预览层没有内置图标，只有 renderPicPreviewIcon 才有内容
        const plain = testCase.make('Upload { width: 480; listType: "picture" }')
        plain.insert([pic("a.png")])
        compare(one(pics(plain)[0], "uploadPicPreviewIcon").sourceComponent === null, true)
        plain.destroy()

        const u = testCase.make('Upload { width: 480; listType: "picture"; renderPicPreviewIcon: customPreviewIcon }')
        u.insert([pic("a.png")])
        const host = one(pics(u)[0], "uploadPicPreviewIcon")
        compare(host.sourceComponent === null, false)   // 钩子接上了
        compare(host.active, false)                     // 官方只有悬浮才显示（offscreen 无 hover）
        u.destroy()
    }

    Component {
        id: customPicClose

        Icon {
            id: customPicCloseRoot

            property var remove: function () {}

            objectName: "customPicCloseNode"
            name: "close"
            size: 16
            color: Theme.current.colorWhite

            TapHandler { onTapped: customPicCloseRoot.remove() }
        }
    }

    function test_renderPicCloseOverridesDefaultClose() {
        const u = testCase.make('Upload { width: 480; listType: "picture"; renderPicClose: customPicClose }')
        u.insert([pic("a.png")])
        wait(40)
        const tile = pics(u)[0]
        compare(one(tile, "uploadPicCloseSlot").active, true)
        const node = one(tile, "customPicCloseNode")
        verify(node !== null)
        // 默认那颗图标被 !slot.active 关掉；offscreen 拿不到 hover，
        // 这里只能钉住「钩子接上了 + 自定义项能删项」，悬浮态由 cocoa 复核。
        compare(one(tile, "uploadPicClose").visible, false)
        const at = node.mapToItem(testCase, node.width / 2, node.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(u.items.length, 0)
        u.destroy()
    }

    Component {
        id: customPreviewFile

        Icon {
            property var modelData: ({})

            objectName: "customPreviewFileIcon"
            name: "file"
            size: 20
            color: Theme.current.colorDanger
        }
    }

    // 官方 previewFile(f)：入参是当前项，节点要能按项切换内容
    Component {
        id: previewReadsItem

        Text {
            property var modelData: ({})

            objectName: "previewReadsItemText"
            text: String(modelData.uid)
        }
    }

    function test_previewFileReceivesCurrentItem() {
        const u = testCase.make('Upload { width: 480; previewFile: previewReadsItem; defaultFileList: [{ uid: "a1", name: "x.png", status: "success" }, { uid: "b2", name: "y.png", status: "success" }] }')
        compare(one(cards(u)[0], "previewReadsItemText").text, "a1")
        compare(one(cards(u)[1], "previewReadsItemText").text, "b2")
        u.destroy()
    }

    function test_previewFileOverridesThumbnailSlot() {
        const u = testCase.make('Upload { width: 480; previewFile: customPreviewFile }')
        u.insert([pic("a.png")])
        const card = cards(u)[0]
        verify(one(card, "customPreviewFileIcon") !== null)
        // 官方：有 previewFile 时预览块回到 placeholder 底色
        compare(one(card, "uploadPreview").color, Theme.current.grey[3])
        u.destroy()
    }

    // ============================================================ 选择 / 拖拽入口
    function test_dropPathsEnterThroughHandleChange() {
        const u = basic()
        u._handleChange(["file:///tmp/drag/one.pdf", "/tmp/drag/two.pdf"])
        compare(u.items.length, 2)
        compare(u.items[0].name, "one.pdf")
        compare(u.items[0].path, "/tmp/drag/one.pdf")
        u.destroy()
    }

    function test_droppedSignalCarriesPathsAndList() {
        const u = basic()
        let seen = null
        u.dropped.connect((urls, list) => { seen = { n: urls.length, len: list.length }; })
        u._handleChange(["/x/a.txt"])
        u.dropped(["/x/a.txt"], u._listCopy())
        compare(seen.n, 1)
        compare(seen.len, 1)
        u.destroy()
    }

    // ============================================================ 替换入口
    function test_replaceWithSwapKeepsLengthAndPosition() {
        // 官方替换走隐藏 input；本端口 replaceAt() 打开对话框，
        // 这里直接驱动对话框回调那一步（_replaceWith），断言替换语义。
        const u = basic()
        u.insert(["/x/a.txt", "/x/b.txt"])
        const uidBefore = u.items[1].uid
        u._replaceWith(1, [pic("replaced.png")])
        compare(u.items.length, 2)
        compare(u.items[1].name, "replaced.png")
        compare(u.items[1].preview, true)
        verify(u.items[1].uid !== uidBefore)
        compare(u.items[0].name, "a.txt")
        u.destroy()
    }

    function test_replaceWithReUploadsReplacedItem() {
        const u = mocked()
        u.insert(["/x/a.txt"])
        const reqsBefore = testCase.reqs.length
        u._replaceWith(0, ["/x/b.txt"])
        compare(testCase.reqs.length, reqsBefore + 1)   // 替换后的项要重新上传
        compare(u.items[0].name, "b.txt")
        compare(u.items.length, 1)
        u.destroy()
    }

    function test_replaceWithRejectsUnacceptedType() {
        const u = testCase.make('Upload { width: 480; accept: ".pdf" }')
        u.insert(["/x/a.pdf"])
        let bad = 0
        u.acceptInvalid.connect((files) => { bad = bad + 1; })
        u._replaceWith(0, ["/x/b.png"])
        compare(bad, 1)
        compare(u.items[0].name, "a.pdf")     // 不合 accept 时保持原项
        u.destroy()
    }

    // ============================================================ 点击路径（窗口级）
    function test_closeButtonClickRemovesThroughWindowDispatch() {
        const u = testCase.make('Upload { width: 300 }')
        u.insert(["/x/a.txt", "/x/b.txt"])
        wait(40)
        const close = one(cards(u)[0], "uploadClose")
        const at = close.mapToItem(testCase, close.width / 2, close.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(u.items.length, 1)
        compare(u.items[0].name, "b.txt")
        u.destroy()
    }

    function test_retryClickRepostsThroughWindowDispatch() {
        const u = mocked()
        u.insert(["/x/a.txt"])
        testCase.reqs[0].onError()
        wait(40)                                      // 重试标签是这一帧才排进来的
        const retry = one(cards(u)[0], "uploadRetry")
        verify(retry !== null)
        const at = retry.mapToItem(testCase, 2, retry.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(testCase.reqs.length, 2)
        u.destroy()
    }

    function test_triggerClickOpensDialog() {
        const u = testCase.make('Upload { width: 480; trigger: Component { Button { text: "点击上传" } } }')
        let opened = 0
        u.dialogOpened.connect(() => { opened = opened + 1; })
        const slot = one(u, "uploadTrigger")
        const at = slot.mapToItem(testCase, slot.width / 2, slot.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(opened, 1)
        u.destroy()
    }

    function test_disabledTriggerClickDoesNotOpenDialog() {
        const u = testCase.make('Upload { width: 480; disabled: true; trigger: Component { Button { text: "点击上传" } } }')
        let opened = 0
        u.dialogOpened.connect(() => { opened = opened + 1; })
        const slot = one(u, "uploadTrigger")
        const at = slot.mapToItem(testCase, slot.width / 2, slot.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(opened, 0)
        u.destroy()
    }

    function test_dragAreaClickOpensDialog() {
        const u = testCase.make('Upload { width: 480; draggable: true }')
        let opened = 0
        u.dialogOpened.connect(() => { opened = opened + 1; })
        const drag = one(u, "uploadDrag")
        const at = drag.mapToItem(testCase, drag.width / 2, drag.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(opened, 1)
        u.destroy()
    }

    function test_addTileClickOpensDialog() {
        const u = testCase.make('Upload { width: 480; listType: "picture" }')
        let opened = 0
        u.dialogOpened.connect(() => { opened = opened + 1; })
        const add = one(u, "uploadAddTile")
        const at = add.mapToItem(testCase, add.width / 2, add.height / 2)
        mouseClick(testCase, at.x, at.y)
        compare(opened, 1)
        u.destroy()
    }
}
