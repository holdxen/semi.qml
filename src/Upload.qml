pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs

// 文件上传。属性面照抄官方 UploadProps（semi-ui/upload/index.tsx:60-147），
// 默认值照抄 defaultProps（同文件 :251-282），状态机照抄
// semi-foundation/upload/foundation.ts，几何/配色照抄 upload.scss + variables.scss。
//
//     Upload {
//         action: "https://example.com/upload"
//         accept: ".pdf,.png"
//         limit: 3
//         trigger: Component { Button { text: "点击上传" } }
//         onChange: (info) => page.files = info.fileList   // 受控用法
//     }
//
// 与官方的结构性偏差（逐条记在 PROGRESS.md）：
// 1. 本端口没有 HTTP 层。action / data / headers / withCredentials / timeout 只被记录、
//    不发请求；未提供 customRequest 时，选中文件直接置 success（percent 100）。
//    要看进度就按官方「自定义请求」示例传 customRequest，自己回调 onProgress / onError / onSuccess。
// 2. QML 拿不到 File 对象与字节数。insert() 入参可以是路径字符串，也可以是带
//    size / name / url / status / percent / preview 的物件；size 给数字按官方 getFileSize
//    格式化，给字符串原样显示。maxSize / minSize 只在 size 是数字时才校验。
//    directory 只能选到文件夹本身（这份 Qt 打包没有目录遍历类型），不展开成目录内文件。
// 3. 官方 children / prompt / dragIcon / render* 都返回 React 节点，QML 里一律用 Component
//    承接，约定其根项自己声明被注入的属性（同 Select.renderOption、TagInput.renderTagItem）。
// 4. 官方 onClear / onRetry / onDrop / onOpenFileDialog 与同名方法（clear / retry）或
//    语义在 QML 里会撞名，信号分别叫 cleared / retried / dropped / dialogOpened。
// 5. 官方 foundation.ts 的 handleChange（选文件/拖拽）与 insertFileToList（ref.insert）两处
//    顺序本身不一致：前者 transformFile 在补 uid 之前、exceed 收到未截断的整批（:332-364），
//    后者相反（:503-538）。本端口两条入口都按前者语义实现，不复制这处上游不一致。
Item {
    id: control

    // ======================================================== 官方属性面
    // ---- 请求相关（本端口只记录，见文件头偏差 1）----
    property string action: ""
    // 官方 data（附带上传的表单字段）。Item 自带 data（子项列表），同名会覆盖它，
    // 所以本端口改名 formData，官方写 data 的地方对应到这里。
    property var formData: ({})
    property var headers: ({})
    property bool withCredentials: false
    property int timeout: 0
    property string name: ""                      // 上传表单字段名
    property string fileName: ""                  // name 的别名，避开 Form 的 name 冲突

    // ---- 列表与状态 ----
    property var fileList: undefined              // 传了即为受控组件
    property var defaultFileList: []
    property string listType: "list"              // list / picture / none
    property string uploadTrigger: "auto"         // auto / custom
    property bool showUploadList: true
    property bool showClear: true
    property bool showPicInfo: false
    property bool showReplace: false
    property bool showRetry: true
    property var showTooltip: true                // true/false 或 { type, opts }
    property string hotSpotLocation: "end"        // start / end
    property string validateMessage: ""
    property string validateStatus: "default"     // 官方四个值都没有样式，纯挂点

    // ---- 选择行为 ----
    property bool multiple: false
    property bool disabled: false
    property bool draggable: false
    property bool directory: false
    property string accept: ""                    // 空串等价官方 undefined
    property int limit: -1                        // -1 等价官方 undefined
    property real maxSize: -1                     // 单位 KB，-1 等价官方 undefined
    property real minSize: -1                     // 单位 KB，-1 等价官方 undefined
    property string capture: ""
    property string promptPosition: "right"       // left / right / bottom

    // ---- 外观 ----
    property var itemStyle: undefined             // { width, height }，官方是 CSSProperties
    property int picWidth: 0                      // 0 等价官方 undefined
    property int picHeight: 0
    property var prompt: undefined                // string 或 Component
    property string dragIcon: ""                  // 图标名，空则官方默认 upload
    property string dragMainText: ""              // 空则官方文案「点击上传文件或拖拽文件到这里」
    property string dragSubText: ""

    // ---- 官方 children 槽位 ----
    property Component trigger: null
    property Component dragIconComponent: null

    // ---- 钩子 ----
    property var beforeUpload: null               // ({ file, fileList }) => bool | 物件 | Promise
    property var beforeRemove: null               // (file, fileList) => bool
    property var beforeClear: null                // (fileList) => bool
    property var afterUpload: null                // ({ response, file, fileList }) => 物件
    property var transformFile: null              // (file) => file
    property var customRequest: null              // (args) => void，接管上传
    property var fileListTitle: undefined         // string 或 Component（官方函数形式）

    // ---- 渲染钩子（Component，根项声明 modelData / index，卡片另注入 remove / retry / replace）
    property Component previewFile: null
    property Component renderFileItem: null
    property Component renderFileOperation: null
    property Component renderThumbnail: null
    property Component renderPicInfo: null
    property Component renderPicPreviewIcon: null
    property Component renderPicClose: null

    // ======================================================== 官方回调（信号）
    signal change(var info)                       // ({ fileList, currentFile })
    signal fileChange(var files)                  // onFileChange
    signal remove(var currentFile, var fileList, var currentFileItem)
    signal cleared                                // onClear
    signal exceed(var files)
    signal progress(real percent, var file, var fileList)
    signal success(var response, var file, var fileList)
    signal error(var err, var file, var fileList)
    signal sizeError(var file, var fileList)
    signal acceptInvalid(var files)
    signal dropped(var urls, var fileList)        // onDrop
    signal dialogOpened                           // onOpenFileDialog
    signal previewClick(var fileItem)
    signal retried(var fileItem)                  // onRetry

    // ======================================================== 内部状态
    property var _items: []
    readonly property var items: (control.fileList !== undefined && control.fileList !== null)
        ? control.fileList : control._items
    property string _dragAreaStatus: "default"    // default / legal（官方 illegal 从未被置位）
    property int _replaceIndex: -1
    property int _uidSeq: 0

    readonly property bool isPicture: control.listType === "picture"
    readonly property bool isNone: control.listType === "none"
    readonly property bool useDragArea: control.draggable && !control.isPicture
    readonly property bool hasPrompt: (typeof control.prompt === "string" && control.prompt !== "")
        || (control.prompt !== undefined && control.prompt !== null && typeof control.prompt === "object")
    readonly property bool promptInline: control.hasPrompt
        && (control.promptPosition === "left" || control.promptPosition === "right")
    readonly property bool promptBelow: control.hasPrompt && control.promptPosition === "bottom"
    // list 模式的 children 触发区；拖拽与 picture 模式下同一份 children 由别处承载
    readonly property bool showTriggerSlot: !control.useDragArea && !control.isPicture
        && control.trigger !== null
    readonly property bool listVisible: !control.isPicture && !control.isNone
        && control.showUploadList && control.items.length > 0
    // 官方 index.tsx:832  limit ? limit > fileList.length : true
    readonly property bool showAddTile: control.limit < 0 || control.limit > control.items.length
    // 官方 index.tsx:902  showTitle = limit !== 1 && fileList.length
    readonly property bool showTitle: control.limit !== 1 && control.items.length > 0 && control.listVisible
    // 官方 index.tsx:903  showClear = props.showClear && !disabled
    readonly property bool canClear: control.showClear && !control.disabled

    // ======================================================== 几何令牌
    readonly property int gap: Theme.current.spacingTight               // 8
    readonly property int cardHeight: 52                                // $height-upload_file_card
    readonly property int cardWidth: (control.itemStyle !== undefined
        && control.itemStyle !== null && control.itemStyle.width !== undefined)
        ? control.itemStyle.width : 250                                 // $width-upload_file_card
    readonly property int tileWidth: control.picWidth > 0 ? control.picWidth : 96
    readonly property int tileHeight: control.picHeight > 0 ? control.picHeight : 96
    readonly property int previewSide: 36                               // $*_upload_file_card_preview
    readonly property real flowWidth: control.width > 0 ? control.width : control.implicitWidth

    implicitWidth: 420
    implicitHeight: body.height

    // ======================================================== 工具函数
    function _nextUid() {
        control._uidSeq = control._uidSeq + 1;
        return "u" + control._uidSeq;
    }

    function _basename(p) {
        const s = String(p);
        const i = s.lastIndexOf("/");
        return i >= 0 ? s.substring(i + 1) : s;
    }

    // 扩展名 → MIME。QML 没有 File 对象，这一步替浏览器认类型。
    readonly property var _mimeTable: ({
        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif",
        "webp": "image/webp", "bmp": "image/bmp", "svg": "image/svg+xml",
        "ico": "image/vnd.microsoft.icon", "tif": "image/tiff", "tiff": "image/tiff",
        "heic": "image/heic", "dpg": "image/dpg",
        "mp4": "video/mp4", "mov": "video/quicktime", "webm": "video/webm",
        "avi": "video/x-msvideo", "mkv": "video/x-matroska", "m4v": "video/x-m4v",
        "mp3": "audio/mpeg", "wav": "audio/wav", "ogg": "audio/ogg", "flac": "audio/flac",
        "m4a": "audio/mp4",
        "pdf": "application/pdf", "zip": "application/zip", "gz": "application/gzip",
        "tar": "application/x-tar", "rar": "application/vnd.rar",
        "7z": "application/x-7z-compressed", "json": "application/json", "xml": "application/xml",
        "doc": "application/msword", "xls": "application/vnd.ms-excel",
        "ppt": "application/vnd.ms-powerpoint",
        "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "txt": "text/plain", "md": "text/markdown", "csv": "text/csv", "html": "text/html",
        "htm": "text/html", "css": "text/css", "js": "text/javascript", "log": "text/plain"
    })
    function _mimeOf(p) {
        const s = String(p).toLowerCase();
        const dot = s.lastIndexOf(".");
        if (dot < 0)
            return "";
        const ext = s.substring(dot + 1);
        return control._mimeTable[ext] !== undefined ? control._mimeTable[ext] : "";
    }

    function _typeOf(f) {
        return String(f.type !== undefined && f.type !== "" ? f.type : control._mimeOf(f.path));
    }

    // 官方 foundation.isImage(:963) 测 file.type 尾段；这里 type 由 _mimeOf 推出
    function _isImage(f) {
        return /\/(webp|svg|png|gif|jpg|jpeg|bmp|dpg)$/.test(control._typeOf(f));
    }

    // 官方 checkFileFormat（foundation.ts:1029-1056）
    function _checkAccept(f) {
        const types = String(control.accept).split(",")
            .map(function (t) { return t.trim(); })
            .filter(function (t) { return t !== ""; });
        const mimeType = control._typeOf(f);
        const baseMimeType = mimeType.replace(/\/.*$/, "");
        const fileName = String(f.name !== undefined ? f.name : control._basename(f.path)).toLowerCase();
        for (let i = 0; i < types.length; ++i) {
            const type = types[i];
            if (type.charAt(0) === ".") {
                if (fileName.endsWith(type.substring(1).toLowerCase()))
                    return true;
            } else if (/\/\*$/.test(type)) {
                if (baseMimeType === type.replace(/\/.*$/, ""))
                    return true;
            } else if (/^[^/]+\/[^/]+$/.test(type)) {
                if (mimeType === type)
                    return true;
            }
        }
        return false;
    }

    // 官方 getFileSize（utils.ts:4-13）；size 给字符串就原样用（官方 transSize 同义）
    function _sizeText(size) {
        if (size === undefined || size === null || size === "")
            return "";
        if (typeof size === "string")
            return size;
        const n = Number(size);
        if (isNaN(n))
            return String(size);
        if (n < 1024)
            return (n / 1024).toFixed(2) + "KB";
        if (n < 1048576)
            return (n / 1024).toFixed(1) + "KB";
        return (n / 1048576).toFixed(1) + "MB";
    }

    // 官方 checkFileSize（foundation.ts:270-278）：拿不到字节数就不校验
    function _sizeIllegal(f) {
        if (f.size === undefined || f.size === null || f.size === "")
            return false;
        if (typeof f.size === "string")
            return false;
        const n = Number(f.size);
        if (isNaN(n))
            return false;
        return (control.maxSize >= 0 && n > control.maxSize * 1024)
            || (control.minSize >= 0 && n < control.minSize * 1024);
    }

    function _listCopy() {
        const out = [];
        const list = control.items;
        for (let i = 0; i < list.length; ++i)
            out.push(list[i]);
        return out;
    }

    function _indexOfUid(list, uid) {
        for (let i = 0; i < list.length; ++i)
            if (list[i].uid === uid)
                return i;
        return -1;
    }

    function _copyOf(item) {
        const out = {};
        for (const k in item)
            out[k] = item[k];
        return out;
    }

    function _commit(list, currentFile) {
        control._items = list;
        control.change({ fileList: list, currentFile: currentFile !== undefined ? currentFile : null });
    }

    // 官方 _getFileIndex + 改一项：复制整份列表再提交
    function _updateItem(uid, patch) {
        const list = control._listCopy();
        const index = control._indexOfUid(list, uid);
        if (index < 0)
            return null;
        const next = control._copyOf(list[index]);
        for (const k in patch)
            next[k] = patch[k];
        list[index] = next;
        control._items = list;
        return next;
    }

    function _findItem(uid) {
        const list = control.items;
        for (let i = 0; i < list.length; ++i)
            if (list[i].uid === uid)
                return list[i];
        return null;
    }

    function _dropItem(uid) {
        const list = control._listCopy();
        const index = control._indexOfUid(list, uid);
        if (index < 0)
            return null;
        list.splice(index, 1);
        control._items = list;
        return list;
    }

    // ======================================================== 建项 / 入列
    function _buildFileItem(f) {
        const status = (f.status !== undefined && f.status !== "")
            ? String(f.status)
            : (control.uploadTrigger === "auto" ? "uploading" : "wait");
        const path = f.path !== undefined ? String(f.path)
            : (f.url !== undefined ? String(f.url) : "");
        const out = {
            uid: f.uid,
            name: f.name !== undefined ? String(f.name) : control._basename(path),
            size: control._sizeText(f.size),
            status: status,
            percent: f.percent !== undefined ? Number(f.percent) : 0,
            url: f.url !== undefined ? String(f.url) : path,
            path: path,
            type: f.type !== undefined ? String(f.type) : control._mimeOf(path),
            preview: f.preview !== undefined ? Boolean(f.preview) : false,
            response: f.response,
            validateMessage: f.validateMessage,
            shouldUpload: f.shouldUpload,
            showRetry: f.showRetry,
            showReplace: f.showReplace,
            _sizeInvalid: f._sizeInvalid === true
        };
        if (!out.preview)
            out.preview = control._isImage(out);   // 官方 buildFileItem:439 图片自动 preview
        return out;
    }

    // 官方 index.tsx:289 直接把 defaultFileList 放进 state，不走 buildFileItem：
    // 没给 status 就是 undefined（不画进度条），也没人给它补 uploading。
    // uid 官方要求必填，这里只在缺失时补一个，方便内部按 uid 定位。
    function _defaultFileItem(f) {
        const out = control._copyOf(f);
        if (out.uid === undefined || out.uid === "")
            out.uid = control._nextUid();
        if (out.name === undefined)
            out.name = control._basename(String(out.url !== undefined ? out.url : out.path));
        out.size = control._sizeText(out.size);
        if (out.percent !== undefined)
            out.percent = Number(out.percent);
        if (out.preview !== undefined)
            out.preview = Boolean(out.preview);
        return out;
    }

    function _normalize(raw) {
        const out = [];
        if (raw === undefined || raw === null)
            return out;
        const arr = (typeof raw === "string") ? [raw] : raw;
        for (let i = 0; i < arr.length; ++i) {
            const v = arr[i];
            const f = (typeof v === "object" && v !== null) ? control._copyOf(v) : { path: String(v) };
            if (f.path === undefined)
                f.path = (typeof v === "string") ? v : String(f.url !== undefined ? f.url : "");
            if (f.name === undefined)
                f.name = control._basename(f.path);
            // 官方把 objectURL 的字符串塞进 selectedFiles 里，这边统一剥掉 scheme
            f.path = String(f.path).replace("file://", "");
            out.push(f);
        }
        return out;
    }

    // 官方 handleChange：选文件与拖拽共用
    function _handleChange(raw) {
        let files = control._normalize(raw);
        if (files.length === 0)
            return;
        files = control._filterAccept(files);
        if (files === null)
            return;
        const before = control._listCopy();
        const prepared = [];
        for (let i = 0; i < files.length; ++i) {
            let f = files[i];
            if (typeof control.transformFile === "function")
                f = control._copyOf(control.transformFile(f));
            if (f.uid === undefined)
                f.uid = control._nextUid();
            if (control._sizeIllegal(f)) {
                f._sizeInvalid = true;
                f.status = "validateFail";
                control.sizeError(f, before);
            }
            prepared.push(f);
        }

        if (control.limit >= 0 && before.length + prepared.length > control.limit) {
            // 传副本：下面要把 prepared 截断，官方 notifyExceed 收到的是截断前的整批
            control.exceed(prepared.slice());
            if (control.limit === 1) {
                // 官方 :353-359 limit===1 时用最后一个替换，不报错、不追加
                const last = [prepared[prepared.length - 1]];
                control.fileChange(last);
                control._replaceFileList(last);
                return;
            }
            const restNum = control.limit - before.length;
            prepared.length = Math.max(0, restNum);
        }

        control.fileChange(prepared);
        control._addFilesToList(prepared);
    }

    // accept 过滤：返回过滤后的数组，全被拦掉时返回 null（官方 :316-330）
    function _filterAccept(files) {
        if (control.accept === "")
            return files;
        const invalid = [];
        const kept = [];
        for (let i = 0; i < files.length; ++i) {
            if (control._checkAccept(files[i]))
                kept.push(files[i]);
            else
                invalid.push(files[i]);
        }
        if (invalid.length !== 0)
            control.acceptInvalid(invalid);
        return kept.length === 0 ? null : kept;
    }

    // 官方 addFilesToList
    function _addFilesToList(files) {
        const list = control._listCopy();
        const built = [];
        for (let i = 0; i < files.length; ++i)
            built.push(control._buildFileItem(files[i]));
        for (let i = 0; i < built.length; ++i) {
            const index = control._indexOfUid(list, built[i].uid);
            if (index !== -1) {
                list[index] = built[i];
            } else {
                list.push(built[i]);
                control._commit(list.slice(), built[i]);   // 官方每推一个 notifyChange 一次
            }
        }
        control._items = list;
        if (control.uploadTrigger === "auto")
            control._startUpload(built);
    }

    // 官方 replaceFileList
    function _replaceFileList(files) {
        const built = [];
        for (let i = 0; i < files.length; ++i)
            built.push(control._buildFileItem(files[i]));
        control._commit(built, built.length ? built[0] : null);
        if (control.uploadTrigger === "auto")
            control._startUpload(built);
    }

    // ======================================================== 上传状态机
    function _startUpload(built) {
        for (let i = 0; i < built.length; ++i) {
            if (!built[i]._sizeInvalid)
                control._uploadUid(built[i].uid);
        }
    }

    function _uploadUid(uid) {
        const item = control._findItem(uid);
        if (item === null)
            return;
        if (typeof control.beforeUpload !== "function") {
            control._post(item);
            return;
        }
        const result = control.beforeUpload({ file: item, fileList: control.items });
        if (result === true) {
            control._post(item);
            return;
        }
        if (result === false) {
            // 官方 :597-600：false 等价 { shouldUpload:false, status:'validateFail' }
            control._applyBeforeUpload(uid, { shouldUpload: false, status: "validateFail" });
            return;
        }
        if (result !== undefined && result !== null && typeof result === "object"
            && typeof result.then !== "function") {
            control._applyBeforeUpload(uid, result);
            return;
        }
        if (result !== undefined && result !== null && typeof result.then === "function") {
            result.then(function (data) {
                control._applyBeforeUpload(uid,
                    (data !== null && typeof data === "object") ? data : { shouldUpload: true });
            }, function (reason) {
                control._applyBeforeUpload(uid, (reason !== null && typeof reason === "object")
                    ? reason : { shouldUpload: false, status: "validateFail" });
            });
        }
    }

    // 官方 handleBeforeUploadResultInObject
    function _applyBeforeUpload(uid, result) {
        if (result.autoRemove === true) {
            const removed = control._findItem(uid);
            const list = control._dropItem(uid);
            if (list !== null)
                control.change({ fileList: list, currentFile: removed });
            return;
        }
        const patch = {};
        if (result.status !== undefined)
            patch.status = String(result.status);
        if (result.validateMessage !== undefined)
            patch.validateMessage = result.validateMessage;
        if (result.shouldUpload !== undefined)
            patch.shouldUpload = Boolean(result.shouldUpload);
        const next = control._updateItem(uid, patch);
        if (next === null)
            return;
        control.change({ fileList: control._items, currentFile: next });
        if (result.shouldUpload === true)
            control._post(next);
    }

    // 官方 post
    function _post(item) {
        if (typeof control.customRequest === "function") {
            const uid = String(item.uid);
            control.customRequest({
                fileName: control.name !== "" ? control.name
                    : (control.fileName !== "" ? control.fileName : item.name),
                data: (typeof control.formData === "function") ? control.formData(item) : control.formData,
                file: item,
                fileInstance: item.path,
                withCredentials: control.withCredentials,
                action: control.action,
                onProgress: function (e) { control._handleProgress(uid, e); },
                onError: function () { control._handleError(uid, { status: 0, message: "upload error" }); },
                onSuccess: function (response) { control._handleSuccess(uid, response); }
            });
            return;
        }
        // 无 HTTP 层：直接判成功（见文件头偏差 1）
        control._handleSuccess(String(item.uid), null);
    }

    // 官方 handleProgress：loaded/total*100*PROGRESS_COEFFICIENT(0.95)
    function _handleProgress(uid, e) {
        let percent = 0;
        if (e !== undefined && e !== null && Number(e.total) > 0)
            percent = Number(((Number(e.loaded) / Number(e.total)) * 100 * 0.95).toFixed(0)) || 0;
        const next = control._updateItem(uid, { percent: percent, status: "uploading" });
        if (next === null)
            return;
        control.progress(percent, next, control._items);
        control.change({ fileList: control._items, currentFile: next });
    }

    function _handleError(uid, err) {
        const next = control._updateItem(uid, { status: "uploadFail", response: err });
        if (next === null)
            return;
        control.error(err, next, control._items);
        control.change({ fileList: control._items, currentFile: next });
    }

    // 官方 handleSuccess + afterUpload
    function _handleSuccess(uid, response) {
        const patch = { status: "success", percent: 100, response: response };
        if (typeof control.afterUpload === "function") {
            const current = control._findItem(uid);
            const result = control.afterUpload({
                response: response, file: current, fileList: control.items
            });
            if (result !== undefined && result !== null && typeof result === "object") {
                if (result.status !== undefined)
                    patch.status = String(result.status);
                if (result.validateMessage !== undefined)
                    patch.validateMessage = result.validateMessage;
                if (result.name !== undefined)
                    patch.name = String(result.name);
                if (result.url !== undefined)
                    patch.url = String(result.url);
                if (result.autoRemove === true) {
                    const removed = control._findItem(uid);
                    const list = control._dropItem(uid);
                    if (list !== null)
                        control.change({ fileList: list, currentFile: removed });
                    return;
                }
            }
        }
        const next = control._updateItem(uid, patch);
        if (next === null)
            return;
        control.progress(100, next, control._items);
        control.success(next.response, next, control._items);
        control.change({ fileList: control._items, currentFile: next });
    }

    // ======================================================== 公开方法
    // 官方 ref.insert(files, index)
    function insert(raw, index) {
        let files = control._normalize(raw);
        if (files.length === 0)
            return;
        files = control._filterAccept(files);
        if (files === null)
            return;
        const before = control._listCopy();
        const prepared = [];
        for (let i = 0; i < files.length; ++i) {
            let f = files[i];
            if (f.uid === undefined)
                f.uid = control._nextUid();
            if (control._sizeIllegal(f)) {
                f._sizeInvalid = true;
                f.status = "validateFail";
                control.sizeError(f, before);
            }
            if (typeof control.transformFile === "function")
                f = control._copyOf(control.transformFile(f));
            prepared.push(f);
        }
        if (control.limit >= 0 && before.length + prepared.length > control.limit) {
            // 官方 insertFileToList 是先截断再 notifyExceed（:535-537）、limit===1 时干脆不通知
            // （:524-531），与 handleChange :351-359 不一致；这里两条入口统一按后者。
            // 传副本，否则下面截断后信号接收方看到的是同一个被改短的数组。
            control.exceed(prepared.slice());
            if (control.limit === 1) {
                const last = [prepared[prepared.length - 1]];
                control.fileChange(last);
                control._replaceFileList(last);
                return;
            }
            prepared.length = Math.max(0, control.limit - before.length);
        }
        const built = [];
        for (let i = 0; i < prepared.length; ++i)
            built.push(control._buildFileItem(prepared[i]));
        const list = control._listCopy();
        if (index !== undefined && index >= 0)
            list.splice(index, 0, ...built);
        else
            list.push(...built);
        control.fileChange(prepared);
        control._commit(list, null);
        if (control.uploadTrigger === "auto")
            control._startUpload(built);
    }

    // 官方 ref.upload()：把 wait 的都推上去
    function upload() {
        const waiting = [];
        const list = control.items;
        for (let i = 0; i < list.length; ++i)
            if (list[i].status === "wait")
                waiting.push(list[i]);
        control._startUpload(waiting);
    }

    // 官方 ref.openFileDialog()
    function openFileDialog() {
        control._openPicker();
    }

    function _openPicker() {
        if (control.disabled)
            return;
        control.dialogOpened();
        if (control.directory) {
            folderDialog.open();
            return;
        }
        picker.nameFilters = control._nameFilters();
        picker.open();
    }

    // 官方 accept 是原生 input 属性；能表达成后缀筛的就交给系统对话框，MIME 交给 _checkAccept
    function _nameFilters() {
        if (control.accept === "")
            return [];
        const exts = String(control.accept).split(",")
            .map(function (t) { return t.trim(); })
            .filter(function (t) { return t.length > 1 && t.charAt(0) === "."; })
            .map(function (t) { return "*" + t.substring(1); });
        if (exts.length === 0)
            return [];
        return [qsTr("允许的文件") + " (" + exts.join(" ") + ")"];
    }

    // 官方 handleRemove（disabled 不响应；beforeRemove 返回 false 中止）
    function removeAt(index) {
        const list = control.items;
        if (index < 0 || index >= list.length || control.disabled)
            return;
        const file = list[index];
        if (typeof control.beforeRemove === "function"
            && control.beforeRemove(file, control._listCopy()) === false)
            return;
        const next = control._dropItem(String(file.uid));
        if (next === null)
            return;
        control.remove(file.path, next, file);
        control.change({ fileList: next, currentFile: file });
    }

    // 官方 handleClear
    function clear() {
        if (control.disabled)
            return;
        if (typeof control.beforeClear === "function"
            && control.beforeClear(control._listCopy()) === false)
            return;
        control._items = [];
        control.cleared();
        control.change({ fileList: [], currentFile: null });
    }

    // 官方 foundation.retry
    function retry(uid) {
        const item = control._findItem(uid);
        if (item === null)
            return;
        control.retried(item);
        control._post(item);
    }

    // 官方 replace(index)：记住位置，用单选对话框接住下一次选择
    function replaceAt(index) {
        if (control.disabled)
            return;
        control._replaceIndex = index;
        replaceDialog.nameFilters = control._nameFilters();
        replaceDialog.open();
    }

    // 官方 handleReplaceFile：整项替换，不追加
    function _replaceWith(index, raw) {
        let files = control._normalize(raw);
        control._replaceIndex = -1;
        if (files.length === 0)
            return;
        files = control._filterAccept(files);
        if (files === null)
            return;
        const list = control._listCopy();
        let f = files[0];
        if (f.uid === undefined)
            f.uid = control._nextUid();
        if (control._sizeIllegal(f)) {
            f._sizeInvalid = true;
            f.status = "validateFail";
            control.sizeError(f, list);
        }
        if (typeof control.transformFile === "function")
            f = control._copyOf(control.transformFile(f));
        control.fileChange([f]);
        const built = control._buildFileItem(f);
        if (index >= 0 && index < list.length)
            list[index] = built;
        else
            list.push(built);
        control._commit(list, built);
        if (control.uploadTrigger === "auto" && !built._sizeInvalid)
            control._uploadUid(built.uid);
    }

    // 官方 dragEnter 一律置 legal，drop / leave 回 default；disabled 时不响应
    function _setDragStatus(s) {
        if (!control.disabled)
            control._dragAreaStatus = s;
    }

    function _urlsToPaths(urls) {
        const out = [];
        for (let i = 0; i < urls.length; ++i)
            out.push(String(urls[i].toString()).replace("file://", ""));
        return out;
    }

    // 文件 url → Image source（官方用 objectURL，本端口直接用路径）
    function _imageSource(u) {
        const s = String(u === undefined ? "" : u);
        if (s === "")
            return "";
        // 已经带 scheme（qrc:/ http:// file:// …）就原样用，否则按本地路径补 file://
        return /^[a-zA-Z0-9+.-]+:/.test(s) ? s : "file://" + s;
    }

    // 卡片状态派生（官方 fileCard.tsx:156-159 / :248-251）
    function _showRetryOn(item) {
        const flag = item.showRetry !== undefined ? Boolean(item.showRetry) : control.showRetry;
        return item.status === "uploadFail" && flag;
    }
    function _showReplaceOn(item) {
        const flag = item.showReplace !== undefined ? Boolean(item.showReplace) : control.showReplace;
        return item.status === "success" && flag;
    }
    function _showProgressOn(item) {
        return item.status === "uploading" && item.percent !== 100;
    }
    // 官方 index.tsx:800-806：失败/尺寸不合法时补默认文案
    function _messageOf(item) {
        if (item.validateMessage !== undefined && item.validateMessage !== null
            && item.validateMessage !== "")
            return item.validateMessage;
        if (item.status === "uploadFail")
            return qsTr("上传失败");              // locale.fail
        if (item._sizeInvalid)
            return qsTr("文件尺寸不合法");         // locale.illegalSize
        return "";
    }
    function _isFail(item) {
        return item.status === "validateFail" || item.status === "uploadFail";
    }

    // ======================================================== 选择器
    FileDialog {
        id: picker

        title: qsTr("选择文件")
        fileMode: control.multiple ? FileDialog.OpenFiles : FileDialog.OpenFile
        onAccepted: control._handleChange(picker.selectedFiles)
    }

    FileDialog {
        id: replaceDialog

        title: qsTr("替换文件")
        fileMode: FileDialog.OpenFile
        onAccepted: control._replaceWith(control._replaceIndex, replaceDialog.selectedFiles)
    }

    FolderDialog {
        id: folderDialog

        title: qsTr("选择文件夹")
        // 这份 Qt 打包没有目录遍历类型，directory 只能选到文件夹本身、按一项加入
        onAccepted: control._handleChange([folderDialog.selectedFolder.toString()])
    }

    Component.onCompleted: {
        if (control.fileList === undefined || control.fileList === null)
            control._items = control._normalize(control.defaultFileList)
                .map(function (f) { return control._defaultFileItem(f); });
    }

    // ======================================================== 布局骨架
    // 官方根是 display:flex + flex-wrap：触发区与 prompt 同行、文件列表另起一行
    // （flex-basis:100%）。picture 模式下 prompt 的参照物是整面墙（upload.scss:57-95, 295-307）。
    Column {
        id: body

        width: control.flowWidth
        spacing: 0

        Item {
            id: headLine

            width: body.width
            height: control.promptInline
                ? Math.max(mainBlock.height, promptSlot.implicitHeight)
                : mainBlock.height + (control.promptBelow ? promptSlot.implicitHeight : 0)

            // ---- 主块：list 模式是触发区，picture 模式是整面墙 ----
            Item {
                id: mainBlock

                x: control.promptInline && control.promptPosition === "left"
                    ? promptSlot.implicitWidth : 0
                y: 0
                // 只有拖拽区和图片墙铺满整行；list 模式的 children 触发区是按内容收拢的
                width: control.useDragArea || control.isPicture
                    ? (control.promptInline
                        ? Math.max(0, headLine.width - promptSlot.implicitWidth) : headLine.width)
                    : triggerSlot.width
                height: control.isPicture ? wall.height
                    : (control.useDragArea ? dragArea.height : triggerSlot.height)

                // 拖拽区（官方 .semi-upload-drag-area）
                Rectangle {
                    id: dragArea

                    objectName: "uploadDrag"
                    visible: control.useDragArea
                    width: mainBlock.width
                    radius: Theme.current.radiusSmall           // $radius-upload_drag_area
                    // 官方 :children 非空时加 -custom：border/padding/背景全部清掉，
                    // 高度就是 children 的高度（upload.scss:407-417）
                    readonly property bool custom: control.trigger !== null
                    height: custom ? dragCustom.implicitHeight
                        : dragContent.height + Theme.current.spacingBaseTight * 2
                    color: custom ? "transparent"
                        : (control._dragAreaStatus === "legal" || dragHover.hovered
                            ? Theme.current.colorPrimaryLightDefault    // $color-upload_drag_area-bg-hover
                            : Theme.current.colorTertiaryLightDefault)  // $color-upload_drag_area-bg
                    border.width: 0

                    // QML 的 Rectangle 画不出虚线，这里按官方 border:2px dashed 用 Canvas 描
                    // （虚线段长按 Blink 的 3×线宽 取，圆角半径同 $radius-upload_drag_area）
                    Canvas {
                        id: dragDash

                        anchors.fill: parent
                        visible: !control.disabled && !dragArea.custom
                        property color pen: control._dragAreaStatus === "legal" || dragHover.hovered
                            ? Theme.current.colorPrimary : Theme.current.colorBorder

                        onPenChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: control._paintDashRect(getContext("2d"), width, height,
                            Theme.current.radiusSmall, pen, 2)
                    }

                    // children 完全替掉默认的图标 + 主/副文案 + tips
                    Loader {
                        id: dragCustom

                        objectName: "uploadDragCustom"
                        anchors.centerIn: parent
                        active: dragArea.custom
                        visible: active
                        sourceComponent: control.trigger
                    }

                    Column {
                        id: dragContent

                        anchors.centerIn: parent
                        spacing: 0
                        visible: !dragArea.custom

                        Loader {
                            id: dragIconSlot

                            anchors.horizontalCenter: parent.horizontalCenter
                            active: control.dragIconComponent !== null
                            sourceComponent: control.dragIconComponent
                            visible: active
                        }

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: control.dragIconComponent === null
                            name: control.dragIcon !== "" ? control.dragIcon : "upload"
                            size: 24                                    // IconUpload size=extra-large
                            color: control.disabled
                                ? Theme.current.colorDisabledText        // $color-upload_drag_area_disabled-text
                                : Theme.current.colorPrimary            // $color-upload_drag_area_icon
                        }

                        Text {
                            objectName: "uploadDragMain"
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: control.dragMainText !== "" || control.dragIconComponent === null
                            text: control.dragMainText !== "" ? control.dragMainText
                                : qsTr("点击上传文件或拖拽文件到这里")     // locale.mainText
                            color: control.disabled
                                ? Theme.current.colorDisabledText : Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeRegular
                            topPadding: Theme.current.spacingExtraTight   // 官方图标与文字之间靠行高
                            bottomPadding: Theme.current.spacingExtraTight // $spacing-upload_drag_area_main_text-marginBottom
                        }

                        Text {
                            objectName: "uploadDragSub"
                            anchors.horizontalCenter: parent.horizontalCenter
                            // 官方 legal 态隐藏 sub-text
                            visible: control.dragSubText !== "" && control._dragAreaStatus !== "legal"
                            text: control.dragSubText
                            color: control.disabled
                                ? Theme.current.colorDisabledText : Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        Text {
                            objectName: "uploadDragTips"
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: control._dragAreaStatus !== "default"
                            text: control._dragAreaStatus === "legal"
                                ? qsTr("松手开始上传")                    // locale.legalTips
                                : qsTr("不支持此类型文件")                // locale.illegalTips
                            color: control._dragAreaStatus === "legal"
                                ? Theme.current.colorPrimary : Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeSmall
                            font.weight: Font.DemiBold                    // $font-...-tips-fontWeight 600
                        }
                    }

                    HoverHandler { id: dragHover }

                    TapHandler {
                        enabled: !control.disabled
                        onTapped: control._openPicker()
                    }

                    DropArea {
                        anchors.fill: parent
                        enabled: control.draggable && !control.disabled
                        onEntered: control._setDragStatus("legal")
                        onExited: control._setDragStatus("default")
                        onDropped: (drop) => {
                            const paths = control._urlsToPaths(drop.urls);
                            control._setDragStatus("default");
                            if (paths.length > 0)
                                control._handleChange(paths);
                            control.dropped(paths, control._listCopy());
                        }
                    }
                }

                // list 模式：官方 children 那层 .semi-upload-add（无默认内容，点了就开选择框）
                Item {
                    id: triggerSlot

                    objectName: "uploadTrigger"
                    visible: control.showTriggerSlot
                    width: triggerLoader.implicitWidth
                    height: triggerLoader.implicitHeight

                    Loader {
                        id: triggerLoader

                        // 拖拽模式下同一份 children 是由拖拽区里那个 Loader 承载的，
                        // 这里必须关掉，否则用户的组件会被实例化两份。
                        // 注意别写成 active: triggerSlot.visible —— QML 的 visible 读回来是
                        // 「有效可见性」（qquickitem.cpp:6657 返回 effectiveVisible），祖先隐藏
                        // 就会连带把这里关掉，几何跟着窗口显隐抖
                        active: control.showTriggerSlot
                        sourceComponent: control.trigger
                    }

                    HoverHandler { id: triggerHover }

                    TapHandler {
                        // 官方是 children 的点击冒泡到外层 .semi-upload-add 再开选择框。
                        // 实测：外层 Item 尺寸收拢到 children 之后，CanTakeOverFromAnything
                        // 的 TapHandler 和 children 自己的 onClicked 会双双触发（同 DOM 冒泡）；
                        // 但只要外层 Item 宽或高是 0，命中测试就不把它算进投递路径，
                        // 处理器直接收不到事件，点击全留给 children —— 所以 width 必须绑实值。
                        grabPermissions: PointerHandler.CanTakeOverFromAnything
                        enabled: !control.disabled
                        onTapped: control._openPicker()
                    }
                }

                // picture 模式：add tile 与卡片同流（.semi-upload-file-list-main，gap 8）
                Item {
                    id: wall

                    objectName: "uploadWall"
                    visible: control.isPicture
                    width: mainBlock.width
                    height: control.items.length === 0 && !control.showAddTile ? 0
                        : (control._wallRows() * (control.tileHeight + control.gap)) - control.gap

                    // 拖到墙上也算拖拽区（官方给 add tile 挂 draggableProps）
                    DropArea {
                        anchors.fill: parent
                        enabled: control.draggable && !control.disabled
                        onEntered: control._setDragStatus("legal")
                        onExited: control._setDragStatus("default")
                        onDropped: (drop) => {
                            const paths = control._urlsToPaths(drop.urls);
                            control._setDragStatus("default");
                            if (paths.length > 0)
                                control._handleChange(paths);
                            control.dropped(paths, control._listCopy());
                        }
                    }

                    Repeater {
                        model: control.isPicture && control.showUploadList ? control.items : []

                        delegate: Loader {
                            id: picLoader

                            objectName: "uploadPicHost" + picLoader.index
                            required property var modelData
                            required property int index

                            // 热区在开头时，卡片整体后移一格
                            readonly property int slot: control.hotSpotLocation === "start"
                                ? picLoader.index + 1 : picLoader.index
                            x: control._wallX(slot)
                            y: control._wallY(slot)
                            active: control.showUploadList
                            sourceComponent: control.renderFileItem !== null
                                ? control.renderFileItem : picCardDefault

                            Binding { target: picLoader.item; property: "modelData"; value: picLoader.modelData }
                            Binding { target: picLoader.item; property: "index"; value: picLoader.index }
                            Binding { target: picLoader.item; property: "tileWidth"; value: control.tileWidth }
                            Binding { target: picLoader.item; property: "tileHeight"; value: control.tileHeight }
                            // 回调值是 JS 函数，走 Binding 会报「Unable to assign a function
                            // to a property of any type other than var」，只能在有 item 时直接写
                            onItemChanged: {
                                if (picLoader.item === null)
                                    return;
                                picLoader.item.onRemoveItem = function () {
                                    control.removeAt(picLoader.index);
                                };
                                picLoader.item.onRetryItem = function () {
                                    control.retry(String(picLoader.modelData.uid));
                                };
                                picLoader.item.onReplaceItem = function () {
                                    control.replaceAt(picLoader.index);
                                };
                            }
                        }
                    }

                    // 添加热区（.semi-upload-picture-add）
                    Loader {
                        id: addTile

                        objectName: "uploadAddTileHost"
                        active: control.showAddTile && control.isPicture
                        visible: active
                        x: control.hotSpotLocation === "start" ? control._wallX(0)
                            : control._wallX(control.items.length)
                        y: control.hotSpotLocation === "start" ? control._wallY(0)
                            : control._wallY(control.items.length)
                        sourceComponent: addTileContent
                    }
                }
            }

            // ---- prompt 槽（官方 .semi-upload-prompt 自身无样式）----
            Loader {
                id: promptSlot

                objectName: "uploadPrompt"
                // 官方 bottom 时 prompt 有 flex-basis:100%，独占一行、从 0 开始；
                // left/right 时和触发区同行
                x: control.promptPosition === "left" || control.promptBelow ? 0 : mainBlock.width
                y: control.promptBelow ? mainBlock.height : Math.max(0, (headLine.height - implicitHeight) / 2)
                visible: control.hasPrompt
                // 同 triggerLoader：绑 visible 会让实例化跟着祖先显隐走（读回来的是有效可见性）
                active: control.hasPrompt
                sourceComponent: control.hasPrompt && typeof control.prompt === "object"
                    ? control.prompt : promptTextContent

                // string 形式要能把文本递给内部 Text
                Binding {
                    target: promptSlot.item
                    property: "promptText"
                    value: typeof control.prompt === "string" ? control.prompt : ""
                    when: promptSlot.item !== null && typeof control.prompt === "string"
                }
            }
        }

        // ---- 整组件级 validateMessage（官方 .semi-upload-validate-message：flex-basis 100%）----
        Text {
            id: rootValidateMessage

            objectName: "uploadValidateMessage"
            width: body.width
            visible: control.validateMessage !== ""
            text: control.validateMessage
            wrapMode: Text.WordWrap
            color: Theme.current.colorDanger        // $color-upload_file_card_fail_info-text
            font.pixelSize: Theme.current.fontSizeSmall
        }

        // ---- list 模式的文件列表 ----
        Column {
            id: fileListColumn

            width: body.width
            visible: control.listVisible
            spacing: 0

            // .semi-upload-file-list 的 margin-top 8
            Item {
                width: 1
                height: Theme.current.spacingTight
            }

            // .semi-upload-file-list-title
            Item {
                id: titleRow

                objectName: "uploadTitleRow"
                // 函数形式由用户的节点自己排版（官方 demo 用 space-between 占满整行），
                // 这里按节点的隐式宽度收拢；ReactNode / 字符串形式仍是「标题文字 + 清空」一行
                width: control._titleIsFunctionForm ? titleCustom.implicitWidth
                    : (titleContentRow.x + titleContentRow.width)
                height: control.showTitle
                    ? Math.max(titleContentRow.implicitHeight, titleCustom.implicitHeight, 16) : 0
                visible: control.showTitle

                Row {
                    id: titleContentRow

                    spacing: 0
                    // ReactNode 形式：官方把节点塞进 -choosen 那个 span 里，也就是标题文字
                    // 的位置，清空按钮跟在它后面（span 的 margin-right 8 由这个偏移量代劳）
                    x: control.titleIsCustom && !control._titleIsFunctionForm
                        ? titleCustom.implicitWidth + Theme.current.spacingTight : 0
                    // 官方函数形式接管整块标题区，默认的「已选择文件 + 清空」就不画了
                    visible: !control._titleIsFunctionForm

                    Text {
                        objectName: "uploadChosen"
                        anchors.verticalCenter: parent.verticalCenter
                        // .semi-upload-file-list-title-choosen：margin-right 8
                        rightPadding: Theme.current.spacingTight
                        visible: !control.titleIsCustom
                        text: (typeof control.fileListTitle === "string" && control.fileListTitle !== "")
                            ? control.fileListTitle : qsTr("已选择文件")   // locale.selectedFiles
                        color: Theme.current.colorText2                   // $color-upload_assist-text
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Text {
                        id: clearLabel

                        objectName: "uploadClear"
                        visible: control.canClear
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("清空")                                // locale.clear
                        color: clearHover.hovered
                            ? Theme.current.colorPrimaryHover : Theme.current.colorPrimary
                        font.pixelSize: Theme.current.fontSizeSmall

                        HoverHandler { id: clearHover }
                        TapHandler { onTapped: control.clear() }
                    }
                }

                // 官方两种节点形式共用一个槽：根项声明了 fileList / clearText / onClear 的
                // 按函数形式处理（整块标题归它），没声明的按 ReactNode 处理（只当标题文字）。
                Loader {
                    id: titleCustom

                    objectName: "uploadTitleCustom"
                    anchors.verticalCenter: parent.verticalCenter
                    active: control.titleIsCustom
                    visible: active
                    sourceComponent: control.fileListTitle

                    // 注入的三个属性都可能是「用户根本没声明」的情况：ReactNode 形式的
                    // 节点不需要它们，直接赋值会报 Cannot assign to non-existent property。
                    // 所以先用 in 判断，同时据此区分函数形式 / ReactNode 形式。
                    onItemChanged: {
                        if (titleCustom.item === null) {
                            control._titleIsFunctionForm = false;
                            return;
                        }
                        control._titleIsFunctionForm = "fileList" in titleCustom.item
                            || "onClear" in titleCustom.item
                            || "clearText" in titleCustom.item;
                        if (!control._titleIsFunctionForm)
                            return;
                        // onClear 是函数值，Binding 注不进去，只能在有 item 时直接写
                        titleCustom.item.onClear = function () { control.clear(); };
                    }

                    // items 变化时要持续同步（官方每次 render 都把最新 fileList 传给函数）
                    Binding {
                        target: titleCustom.item
                        property: "fileList"
                        value: control.items
                        when: titleCustom.item !== null && control._titleIsFunctionForm
                            && "fileList" in titleCustom.item
                    }
                    Binding {
                        target: titleCustom.item
                        property: "clearText"
                        value: qsTr("清空")
                        when: titleCustom.item !== null && control._titleIsFunctionForm
                            && "clearText" in titleCustom.item
                    }
                }
            }

            Item {
                width: 1
                height: Theme.current.spacingExtraTight     // title margin-bottom 4
                visible: control.showTitle
            }

            Item {
                id: listFlow

                objectName: "uploadListFlow"
                width: body.width
                height: control.listVisible
                    ? (control._listRows() * (control.cardHeight + control.gap)) - control.gap : 0

                // Repeater 必须挂在这个 Item 里：delegate 的父项就是 Repeater 的父项，
                // 放在外层 Column 里的话 y 会被 Column 排掉，卡片全挤成一行。
                Repeater {
                    // QQuickRepeater 没有 active，只能把模型换成空数组来关掉另一种模式
                    model: (!control.isPicture && !control.isNone && control.showUploadList)
                        ? control.items : []

                    delegate: Loader {
                        id: listCardLoader

                        objectName: "uploadCardHost" + listCardLoader.index
                        required property var modelData
                        required property int index

                        x: control._flowX(listCardLoader.index, control.cardWidth, control._listColumns())
                        y: control._flowY(listCardLoader.index, control.cardHeight, control._listColumns())
                        sourceComponent: control.renderFileItem !== null
                            ? control.renderFileItem : listCardDefault

                        Binding { target: listCardLoader.item; property: "modelData"; value: listCardLoader.modelData }
                        Binding { target: listCardLoader.item; property: "index"; value: listCardLoader.index }
                        Binding { target: listCardLoader.item; property: "cardWidth"; value: control.cardWidth }
                        Binding { target: listCardLoader.item; property: "cardHeight"; value: control.cardHeight }
                        // 同上：函数值不能用 Binding 注入
                        onItemChanged: {
                            if (listCardLoader.item === null)
                                return;
                            listCardLoader.item.onRemoveItem = function () {
                                control.removeAt(listCardLoader.index);
                            };
                            listCardLoader.item.onRetryItem = function () {
                                control.retry(String(listCardLoader.modelData.uid));
                            };
                            listCardLoader.item.onReplaceItem = function () {
                                control.replaceAt(listCardLoader.index);
                            };
                        }
                    }
                }
            }

            Item {
                width: 1
                height: Theme.current.spacingTight          // .semi-upload-file-list margin-bottom 8
            }
        }
    }

    // ======================================================== 排布计算
    readonly property bool titleIsCustom: control.fileListTitle !== undefined
        && control.fileListTitle !== null && typeof control.fileListTitle === "object"
    // 官方 index.tsx:917 用 typeof fileListTitle === 'function' 区分两种形式：
    // 函数形式接管整块标题，ReactNode 形式只替换标题文字、默认清空按钮保留。
    // QML 的 Component 不是函数，改由「根项有没有声明被注入的属性」来区分。
    property bool _titleIsFunctionForm: false

    // QML 的 Rectangle 画不出虚线，Context2D 又没有 roundRect，圆角矩形路径只能 arcTo 拼。
    // 虚线段长按浏览器虚线边框的 3×线宽 比例取。
    function _paintDashRect(ctx, w, h, radius, pen, lineWidth) {
        ctx.clearRect(0, 0, w, h);
        const half = lineWidth / 2;
        ctx.lineWidth = lineWidth;
        ctx.strokeStyle = pen;
        ctx.setLineDash([lineWidth * 3, lineWidth * 3]);
        ctx.beginPath();
        ctx.moveTo(half + radius, half);
        ctx.lineTo(w - half - radius, half);
        ctx.arcTo(w - half, half, w - half, half + radius, radius);
        ctx.lineTo(w - half, h - half - radius);
        ctx.arcTo(w - half, h - half, w - half - radius, h - half, radius);
        ctx.lineTo(half + radius, h - half);
        ctx.arcTo(half, h - half, half, h - half - radius, radius);
        ctx.lineTo(half, half + radius);
        ctx.arcTo(half, half, half + radius, half, radius);
        ctx.closePath();
        ctx.stroke();
    }

    function _listColumns() {
        return Math.max(1, Math.floor((body.width + control.gap) / (control.cardWidth + control.gap)));
    }
    function _listRows() {
        const n = control.items.length;
        if (n === 0)
            return 0;
        return Math.ceil(n / control._listColumns());
    }
    // picture 墙上多了一个 add tile，槽位数 = 卡片 + 热区
    function _wallSlots() {
        return control.items.length + (control.showAddTile ? 1 : 0);
    }
    function _wallColumns() {
        return Math.max(1, Math.floor((body.width + control.gap) / (control.tileWidth + control.gap)));
    }
    function _wallRows() {
        const n = control._wallSlots();
        if (n === 0)
            return 0;
        return Math.ceil(n / control._wallColumns());
    }
    function _wallX(slot) {
        return control._flowX(slot, control.tileWidth, control._wallColumns());
    }
    function _wallY(slot) {
        return control._flowY(slot, control.tileHeight, control._wallColumns());
    }
    function _flowX(i, side, cols) {
        return (i % cols) * (side + control.gap);
    }
    function _flowY(i, side, cols) {
        return Math.floor(i / cols) * (side + control.gap);
    }

    // ======================================================== prompt（string 形式）
    Component {
        id: promptTextContent

        Text {
            property string promptText: ""
            text: promptText
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeSmall
        }
    }

    // ======================================================== add tile（picture 模式）
    Component {
        id: addTileContent

        Rectangle {
            id: addTileRoot

            objectName: "uploadAddTile"
            implicitWidth: control.tileWidth
            implicitHeight: control.tileHeight
            radius: Theme.current.radiusSmall                 // $radius-upload_picture_add
            color: control.disabled ? Theme.current.colorFill0
                : (addPressed.pressed ? Theme.current.colorFill2    // $color-upload_pic_add-bg-active
                    : (addHover.hovered ? Theme.current.colorFill1   // -bg-hover
                        : Theme.current.colorFill0))                 // $color-upload_pic_add-bg
            border.width: 0

            // 官方 .semi-upload-picture-add：border:2px dashed $color-upload-border
            Canvas {
                id: addDash

                anchors.fill: parent
                property color pen: control._dragAreaStatus === "legal" || addHover.hovered
                    ? Theme.current.colorPrimary : Theme.current.colorBorder

                onPenChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: control._paintDashRect(getContext("2d"), width, height,
                    Theme.current.radiusSmall, pen, 2)
            }

            Loader {
                anchors.centerIn: parent
                active: control.trigger !== null
                sourceComponent: control.trigger
            }

            Icon {
                anchors.centerIn: parent
                visible: control.trigger === null
                name: "plus"
                size: 24                                        // IconPlus size=extra-large
                color: control.disabled ? Theme.current.colorDisabledText
                    : Theme.current.colorTertiary               // $color-upload-icon
            }

            DropArea {
                anchors.fill: parent
                enabled: control.draggable && !control.disabled
                onEntered: control._setDragStatus("legal")
                onExited: control._setDragStatus("default")
                onDropped: (drop) => {
                    const paths = control._urlsToPaths(drop.urls);
                    control._setDragStatus("default");
                    if (paths.length > 0)
                        control._handleChange(paths);
                    control.dropped(paths, control._listCopy());
                }
            }

            HoverHandler { id: addHover }
            TapHandler {
                id: addPressed
                // 同上：热区要抢在 children（常见是一颗 Button）之前拿到点击
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                enabled: !control.disabled
                onTapped: control._openPicker()
            }
        }
    }

    // ======================================================== list 卡片
    // 官方 .semi-upload-file-card：52 高、250 宽、圆角 medium、fill-0（悬浮 fill-1），
    // 失败态 danger-light-default（悬浮 danger-light-hover）。
    Component {
        id: listCardDefault

        Rectangle {
            id: card

            objectName: "uploadCard" + card.index
            property var modelData: ({})
            property int index: 0
            property real cardWidth: 250
            property real cardHeight: 52
            property var onRemoveItem: function () {}
            property var onRetryItem: function () {}
            property var onReplaceItem: function () {}

            width: cardWidth
            height: cardHeight
            radius: Theme.current.radiusMedium                  // $radius-upload_file_card
            color: card.failed
                ? (cardHover.hovered ? Theme.current.colorDangerLightHover    // $color-upload_card_fail-bg-hover
                    : Theme.current.colorDangerLightDefault)                  // $color-upload_card_fail-bg
                : (cardHover.hovered ? Theme.current.colorFill1               // $color-upload_card-bg-hover
                    : Theme.current.colorFill0)                               // $color-upload_card-bg

            readonly property bool failed: control._isFail(modelData)
            readonly property bool uploading: modelData.status === "uploading"
            readonly property bool showProgress: control._showProgressOn(modelData)
            readonly property bool showRetry: control._showRetryOn(modelData)
            readonly property bool showReplace: control._showReplaceOn(modelData)
            readonly property string message: String(control._messageOf(modelData))
            readonly property bool hasThumb: modelData.preview === true
                && String(modelData.url) !== "" && !card.fallbackPreview
            property bool fallbackPreview: false
            // 官方 Typography 的 ellipsis.showTooltip：只在真的截断时弹
            readonly property bool nameTruncated: nameText.truncated
            readonly property bool tooltipWanted: control.showTooltip === true
                || (control.showTooltip !== undefined && control.showTooltip !== null
                    && typeof control.showTooltip === "object")

            HoverHandler { id: cardHover }

            TapHandler {
                onTapped: control.previewClick(card.modelData)
            }

            // ---- 预览块 36x36，四周 margin 8 ----
            Rectangle {
                id: previewBox

                objectName: "uploadPreview"
                x: Theme.current.spacingTight
                y: (parent.height - height) / 2
                width: control.previewSide
                height: control.previewSide
                radius: Theme.current.radiusSmall               // $radius-upload_file_card_preview
                // .semi-upload-file-card-preview-placeholder：非图片预览时是灰底白图标
                color: card.hasThumb && control.previewFile === null
                    ? "transparent" : Theme.current.grey[3]     // $color-upload_file_card_preview_placeholder-bg

                Loader {
                    id: previewCustom

                    anchors.centerIn: parent
                    active: control.previewFile !== null
                    sourceComponent: control.previewFile
                    visible: active

                    // 官方 previewFile(fileItem)：钩子按当前项决定预览内容，所以要把项递给它的根
                    Binding {
                        target: previewCustom.item
                        property: "modelData"
                        value: card.modelData
                        when: previewCustom.item !== null
                    }
                }

                Image {
                    anchors.fill: parent
                    readonly property bool wantThumb: card.hasThumb && control.previewFile === null
                    visible: wantThumb
                    // 不可见时把 source 置空，否则每张卡片都会去 open 一个不存在的文件
                    source: wantThumb ? control._imageSource(card.modelData.url) : ""
                    sourceSize: Qt.size(control.previewSide, control.previewSide)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    onStatusChanged: if (status === Image.Error) card.fallbackPreview = true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: !card.hasThumb && control.previewFile === null
                    name: "file"
                    size: 20                                    // IconFile size=large
                    color: Theme.current.colorWhite             // $color-upload_file_card_preview_placeholder-text
                }
            }

            // ---- 信息区：名称/大小(+替换) → 进度 → 校验信息/重试 ----
            // .semi-upload-file-card-close 有左右各 8 的外边距，中间是 small 图标按钮。
            // 官方右侧那块是 flex 项、信息区 flex:1 + min-width:0，所以 renderFileOperation
            // 给了更宽的操作区时，被压缩的是信息区（名称跟着省略），不是让两者叠在一起。
            readonly property int closeBlockWidth: control.renderFileOperation !== null
                ? (operationSlot.implicitWidth + Theme.current.spacingTight)
                : (Theme.current.spacingTight * 2
                    + Appearance.buttonHeight(Theme.current, Enums.Small))
            readonly property int infoWidth: Math.max(0, width - control.previewSide
                - Theme.current.spacingTight * 2 - closeBlockWidth)
            readonly property int sizeBlockWidth: sizeLabel.visible ? sizeLabel.implicitWidth : 0
            readonly property int replaceBlockWidth: card.showReplace
                ? 24 + Theme.current.spacingTight : 0      // $width-upload_file_card-replace + margin-left

            Column {
                id: infoColumn

                objectName: "uploadInfo"
                x: control.previewSide + Theme.current.spacingTight * 2
                y: (parent.height - height) / 2
                width: card.infoWidth
                spacing: 0

                Item {
                    width: infoColumn.width
                    height: nameText.implicitHeight

                    Row {
                        id: nameRow

                        spacing: 0

                        Text {
                            id: nameText

                            objectName: "uploadName"
                            width: Math.max(0, infoColumn.width - card.sizeBlockWidth
                                - card.replaceBlockWidth)
                            text: String(card.modelData.name)
                            elide: Text.ElideRight
                            color: Theme.current.colorText0                 // $color-upload-text
                            font.pixelSize: Theme.current.fontSizeRegular
                            font.weight: Font.DemiBold                      // 600
                        }

                        Text {
                            id: sizeLabel

                            objectName: "uploadSize"
                            visible: String(card.modelData.size) !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: Theme.current.spacingTight          // margin-left 8
                            bottomPadding: 1                                 // margin-top 1px
                            text: String(card.modelData.size)
                            color: Theme.current.colorText2                  // $color-upload_assist-text
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        // 官方替换按钮：24 宽、borderless 图标按钮、tooltip「替换文件」。
                        // Row 里左外边距只能靠外层 Item 撑（IconButton 没有 padding 属性）
                        Item {
                            objectName: "uploadReplaceBtn"
                            visible: card.showReplace
                            width: Theme.current.spacingTight + replaceBtn.implicitWidth
                            height: replaceBtn.implicitHeight
                            anchors.verticalCenter: parent.verticalCenter

                            IconButton {
                                id: replaceBtn

                                x: Theme.current.spacingTight
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "folder"
                                tooltip: qsTr("替换文件")                     // locale.replace
                                size: Enums.Small
                                variant: Enums.Borderless
                                tone: Enums.Tertiary
                                onClicked: card.onReplaceItem()
                            }
                        }
                    }

                    Tooltip {
                        id: nameTip

                        objectName: "uploadNameTip"
                        target: nameText
                        text: String(card.modelData.name)
                        // 官方：showTooltip 为真且文本真的被截断时才弹
                        enabled: card.tooltipWanted && card.nameTruncated
                    }
                }

                // 进度：轨道 4 高、上下各 4 外边距（.semi-progress-horizontal）
                Item {
                    objectName: "uploadProgress"
                    width: infoColumn.width
                    height: 12
                    visible: card.showProgress

                    Progress {
                        id: lineProgress

                        objectName: "uploadProgressLine"
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        percent: Number(card.modelData.percent)
                    }
                }

                Row {
                    spacing: 0
                    visible: card.message !== "" || card.showRetry

                    Text {
                        id: messageRow

                        objectName: "uploadMessage"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.message !== ""
                        text: card.message
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth,
                            infoColumn.width - (card.showRetry ? retryLabel.implicitWidth : 0))
                        color: card.failed ? Theme.current.colorDanger        // $color-upload_file_card_fail_info-text
                            : Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Text {
                        id: retryLabel

                        objectName: "uploadRetry"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.showRetry
                        leftPadding: Theme.current.spacingTight
                        text: qsTr("重试")                                    // locale.retry
                        color: Theme.current.colorPrimary                     // $color-upload_retry-text
                        font.pixelSize: Theme.current.fontSizeSmall

                        HoverHandler { id: retryHover }
                        TapHandler { onTapped: card.onRetryItem() }
                    }
                }
            }

            // ---- 操作区：官方默认是一颗 borderless 关闭按钮 ----
            Loader {
                id: operationSlot

                objectName: "uploadOperation"
                anchors.right: parent.right
                anchors.rightMargin: Theme.current.spacingTight                // $spacing-upload_file_card_close-marginRight
                anchors.verticalCenter: parent.verticalCenter
                active: control.renderFileOperation !== null
                visible: active
                sourceComponent: control.renderFileOperation

                Binding {
                    target: operationSlot.item
                    property: "modelData"
                    value: card.modelData
                    when: operationSlot.item !== null
                }
                Binding {
                    target: operationSlot.item
                    property: "index"
                    value: card.index
                    when: operationSlot.item !== null
                }
                // 函数值只能直接写。而且必须再包一层：这个 Loader 的 item 是在卡片
                // 自己构造时就建好的，那一刻宿主还没把真正的 onRemoveItem 注入到 card 上，
                // 直接赋值会把默认的空调关进钩子里。包一层等于把查找推迟到点击那一刻。
                onItemChanged: {
                    if (operationSlot.item === null)
                        return;
                    operationSlot.item.onRemoveItem = function () { card.onRemoveItem(); };
                    operationSlot.item.onRetryItem = function () { card.onRetryItem(); };
                    operationSlot.item.onReplaceItem = function () { card.onReplaceItem(); };
                }
            }

            IconButton {
                id: defaultClose

                objectName: "uploadClose"
                anchors.right: parent.right
                anchors.rightMargin: Theme.current.spacingTight                // $spacing-upload_file_card_close-marginRight
                anchors.verticalCenter: parent.verticalCenter
                visible: control.renderFileOperation === null && !control.disabled
                icon: "close"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
                onClicked: card.onRemoveItem()
            }
        }
    }

    // ======================================================== picture 卡片
    Component {
        id: picCardDefault

        Rectangle {
            id: picCard

            objectName: "uploadPic" + picCard.index
            property var modelData: ({})
            property int index: 0
            property real tileWidth: 96
            property real tileHeight: 96
            property var onRemoveItem: function () {}
            property var onRetryItem: function () {}
            property var onReplaceItem: function () {}

            width: tileWidth
            height: tileHeight
            radius: Theme.current.radiusSmall                   // $radius-upload_picture_file_card_img
            color: "transparent"
            clip: true

            readonly property bool failed: modelData.status === "uploadFail"
            readonly property bool uploading: control._showProgressOn(modelData)
            readonly property bool showRetry: control._showRetryOn(modelData)
            readonly property bool showReplace: control._showReplaceOn(modelData)
            readonly property bool showPreview: modelData.status === "success" && !picCard.showReplace
            readonly property string message: String(control._messageOf(modelData))
            readonly property bool hasThumb: modelData.preview === true
                && String(modelData.url) !== "" && !picCard.fallbackPreview
            readonly property bool actionsVisible: picHover.hovered || picCard.uploading
            property bool fallbackPreview: false

            HoverHandler { id: picHover }

            TapHandler {
                onTapped: control.previewClick(picCard.modelData)
            }

            Loader {
                id: thumbCustom

                objectName: "uploadPicThumbCustom"
                anchors.fill: parent
                active: control.renderThumbnail !== null
                visible: active
                sourceComponent: control.renderThumbnail

                Binding { target: thumbCustom.item; property: "modelData"; value: picCard.modelData }
                Binding { target: thumbCustom.item; property: "index"; value: picCard.index }
            }

            Image {
                id: thumb

                objectName: "uploadPicThumb"
                anchors.fill: parent
                readonly property bool wantThumb: !thumbCustom.active && picCard.hasThumb
                visible: wantThumb
                source: wantThumb ? control._imageSource(picCard.modelData.url) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                onStatusChanged: if (status === Image.Error) picCard.fallbackPreview = true
            }

            // 预览图缺失/加载失败：官方 fallback 是 fill-0 底 + tertiary 图标
            Rectangle {
                anchors.fill: parent
                visible: !thumbCustom.active && !picCard.hasThumb
                radius: parent.radius
                color: Theme.current.colorFill0
            }

            Icon {
                anchors.centerIn: parent
                visible: !thumbCustom.active && !picCard.hasThumb
                name: "file"
                size: 20
                color: Theme.current.colorTertiary              // $color-upload-icon
            }

            // hover / uploading 遮罩（.semi-picture-file-card::before）
            Rectangle {
                objectName: "uploadPicOverlay"
                anchors.fill: parent
                visible: picCard.actionsVisible
                radius: parent.radius
                color: Theme.current.colorOverlayBg             // $color-upload_picture_file_card_hover-bg
            }

            // 失败态描边：官方 border 1px + outline 1px
            Rectangle {
                objectName: "uploadPicErrorRing"
                anchors.fill: parent
                anchors.margins: -1
                visible: picCard.failed
                radius: parent.radius + 1
                color: "transparent"
                border.width: 1                                 // $color-upload_picture_file_card_error-border
                border.color: Theme.current.colorDanger
            }

            Rectangle {
                anchors.fill: parent
                visible: picCard.failed
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.current.colorDanger
            }

            // 关闭：hover 才可见，右上 8/8，图标 16 白
            Loader {
                id: picClose

                objectName: "uploadPicCloseSlot"
                anchors.fill: parent
                active: control.renderPicClose !== null
                visible: active
                sourceComponent: control.renderPicClose

                // 同 renderFileOperation：必须包一层，否则会把宿主还没注入时的默认空函数关进去
                onItemChanged: {
                    if (picClose.item === null)
                        return;
                    picClose.item.remove = function () { picCard.onRemoveItem(); };
                }
            }

            Icon {
                id: closeIcon

                objectName: "uploadPicClose"
                x: parent.width - width - Theme.current.spacingTight     // close-right 8
                y: Theme.current.spacingTight                             // close-top 8
                visible: !control.disabled && !picClose.active && picHover.hovered
                name: "clear"
                size: 16                                                  // $width-upload_picture_file_card_close
                color: Theme.current.colorWhite                           // $color-upload_picture_file_card_close-icon

                TapHandler { onTapped: picCard.onRemoveItem() }
            }

            // 重试：白底 24 圆 + 镜像刷新图标
            Rectangle {
                id: retryCircle

                objectName: "uploadPicRetry"
                visible: picCard.showRetry && picCard.actionsVisible
                anchors.centerIn: parent
                width: 24                                                 // $width-upload_file_card_retry
                height: 24
                radius: width / 2                                         // $radius-upload_file_card_retry
                color: Theme.current.colorWhite                           // $color-upload_file_card_retry-bg

                Icon {
                    anchors.centerIn: parent
                    name: "refresh"
                    size: 13                                              // $width-upload_file_card_retry-icon
                    color: Theme.current.colorPrimary                     // $color-upload_file_card_retry-text
                    // 官方 transform: scale(-1, 1)，把刷新箭头镜像
                    transform: Scale { xScale: -1 }
                }

                TapHandler { onTapped: picCard.onRetryItem() }
            }

            // 替换：官方是 28x28 的内嵌 SVG（深底圆 + 文件夹交换描边）
            Rectangle {
                visible: picCard.showReplace && picCard.actionsVisible
                anchors.centerIn: parent
                width: 28
                height: 28
                radius: 14
                color: Qt.rgba(22 / 255, 22 / 255, 26 / 255, 0.6)

                Icon {
                    anchors.centerIn: parent
                    name: "folder_stroked"
                    size: 16
                    color: Theme.current.colorWhite                       // $color-upload_replace-text
                }

                TapHandler { onTapped: picCard.onReplaceItem() }
            }

            // 预览图标：官方无内置，只能由 renderPicPreviewIcon 提供
            Loader {
                id: previewIconSlot

                objectName: "uploadPicPreviewIcon"
                anchors.centerIn: parent
                active: picCard.showPreview && control.renderPicPreviewIcon !== null
                    && picCard.actionsVisible
                visible: active
                sourceComponent: control.renderPicPreviewIcon

                Binding {
                    target: previewIconSlot.item
                    property: "modelData"
                    value: picCard.modelData
                    when: previewIconSlot.item !== null
                }
            }

            // showPicInfo：默认是一张序号条（官方 pic-info 放 index+1）
            Loader {
                id: picInfoSlot

                objectName: "uploadPicInfoCustom"
                anchors.fill: parent
                active: control.showPicInfo && control.renderPicInfo !== null
                visible: active
                sourceComponent: control.renderPicInfo

                Binding { target: picInfoSlot.item; property: "modelData"; value: picCard.modelData }
                Binding { target: picInfoSlot.item; property: "index"; value: picCard.index }
            }

            Rectangle {
                id: picInfoBar

                objectName: "uploadPicInfo"
                visible: control.showPicInfo && control.renderPicInfo === null
                anchors.bottom: parent.bottom
                width: parent.width
                height: 24                                                // $height 24
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(22 / 255, 22 / 255, 26 / 255, 0) }
                    GradientStop { position: 0.2292; color: Qt.rgba(22 / 255, 22 / 255, 26 / 255, 0) }
                    GradientStop { position: 1.0; color: Qt.rgba(22 / 255, 22 / 255, 26 / 255, 0.3) }
                }

                Text {
                    objectName: "uploadPicInfoText"
                    anchors.left: parent.left
                    anchors.leftMargin: 10                                // padding 0 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: picCard.index + 1
                    color: Theme.current.colorWhite                       // $color-upload_picture_file_card_pic_info-text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            // 上传中：圆形进度（Progress type=circle size=small → 直径 24、线宽 4、轨道白）
            Progress {
                id: circleProgress

                objectName: "uploadPicProgress"
                visible: picCard.uploading
                anchors.centerIn: parent
                type: "circle"
                size: "small"
                orbitStroke: "#FFFFFF"
                percent: Number(picCard.modelData.percent)
            }

            // 校验/失败角标：bottom 6 right 6
            Item {
                id: statusIcon

                objectName: "uploadPicStatus"
                visible: picCard.message !== ""
                    && (picCard.modelData.status === "validateFail"
                        || picCard.modelData.status === "uploadFail"
                        || picCard.modelData.status === "validating")
                x: parent.width - width - 6                               // loading_error-right 6
                y: parent.height - height - 6                             // -bottom 6
                width: 16
                height: 16

                Spin {
                    visible: picCard.modelData.status === "validating"
                    anchors.centerIn: parent
                    size: "small"                                           // 14
                }

                Icon {
                    visible: picCard.modelData.status !== "validating"
                    anchors.centerIn: parent
                    name: "alert_circle"
                    size: 16
                    color: Theme.current.colorDanger
                }

                Tooltip {
                    target: statusIcon
                    text: picCard.message
                }
            }
        }
    }
}
