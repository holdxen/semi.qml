import QtQuick
import QtQuick.Shapes

pragma ComponentBehavior: Bound

// 图片裁切。官方 `packages/semi-ui/cropper/index.tsx` + `semi-foundation/cropper/foundation.ts`
// （903 行，**没有第三方依赖**，整套交互是 Semi 手写的）。
//
//     Cropper {
//         width: 550
//         height: 300
//         src: "file:///…/image.png"
//         shape: "round"
//     }
//     Button { text: "裁切"; onClicked: result.source = control.cropToUrl() }
//
// ------------------------------------------------------------------ 官方 CropperProps
// 逐条对着 index.tsx:13-42（接口）与 :65-76（defaultProps）：
//   · `shape` 缺省 rect，另有 round / roundRect；`defaultAspectRatio` 1、`showResizeBox` true、
//     `fill` 'rgba(0,0,0,0)'、`maxZoom` 3、`minZoom` 0.1、`zoomStep` 0.1。
//   · `aspectRatio` 是**受控比例**（给了就把拖调整块锁在该比例上，并参与初始框尺寸计算），
//     `defaultAspectRatio` 只管初始那一下。
//   · `rotate` / `zoom` 是**受控**值：官方在 `getDerivedStateFromProps`（:120-181）里把它们
//     换成一串「绕裁切框中心」的变换。**那条 zoom 分支被 `!isUndefined(newRotate)` 挡着**
//     （:153 写的是 `newRotate`），也就是官方自己「只改 zoom 不改 rotate」时受控缩放不生效 ——
//     按本项目「官方 bug 只记录不抄」的口径，端口两条各自独立生效，差异记在坑 112。
//   · `preview` 官方是 `() => HTMLElement`（往那个 DOM 节点里塞一张 img 并实时改它的
//     width/height/transform，foundation.ts:243-296）⇒ 端口收一个 `Item`，往里挂一张 Image。
//   · **`imgProps` 是死 prop**：接口与 API 表都写着「透传给 img 标签」，但组件从头到尾没展开过它
//     （grep 整个 cropper 目录只有类型声明那行）。端口同样收下、不产出差异。
//   · `cropperBoxStyle` 展开在框那一层的内联样式上 ⇒ 只有两条带颜色的键有落点：
//     `outlineColor` 顶替那条 1px 环的 primary（官方 demo 用的就是这一条，
//     content/show/cropper/index.md:236），`backgroundColor` 进框底色（图没铺满框时露出来）。
//     注意那条是 `outline` 不是 `border`，所以 `borderColor` 在官方那里改不动它。
//   · `cropperBoxCls` / `className` / `style` 是类名与样式表，端口没有对应的 CSS 层 ⇒
//     收了不产出可见差异（与 Highlight 的 `component` 同一口径）。
//     **API 表里那行 `cropperBoxClassName` 是官网写错的**，代码里的 prop 叫 `cropperBoxCls`。
//   · `getCropperCanvas()` 返回 HTML canvas ⇒ 端口是 `cropToImage()` / `cropToUrl()`，
//     像素那一段走 C++（QtQuick 的 Canvas 撑不住：见坑 112）。
//     `src` 走网络那一路端口只能显示、裁不了：裁切要同步读到像素，
//     `CropperRuntime` 只认本地路径与 qrc（不能在同步调用里开事件循环等下载）。
//     裁切结果挂在 `image://semi-cropper/<md5>` 上给 QML 显示（官方是 canvas.toDataURL()）。
//
// ------------------------------------------------------------------ 结构（cropper.scss）
// `.semi-cropper` 是 `position: relative` 的容器，宽高归使用方；里面三层：
//   1. `-img-wrapper`（absolute 铺满 + `overflow: hidden`）里那张 `-img`：
//      `transform: translate(imgX, imgY) rotate(rotate)`、transform-origin center ⇒
//      端口用 x/y + rotation（中心为原点）。
//   2. `-mask`：absolute 铺满整块，底色 `--semi-color-overlay-bg`，`cursor: move` ⇒
//      按在框外的空白处拖 = 移动图片（**不夹边界**，可以把图完全拖出框）。
//   3. `-box`：absolute，`outline: 1px solid colorPrimary`（是 outline 不是 border），
//      里面 `-view-box`（absolute 铺满 + `overflow: hidden` + `cursor: move`，round 档
//      `border-radius: 50%`）再套一张同样的图（偏移 = 图相对框的位置）；
//      外围八个 `-box-corner`（10×10 的 primary 方块，各边外扩 5px）。
//   · `shape === 'round'` 时调整块只剩四块（`strings.roundCorner`）。
//   · **`roundRect` 在官方是个圆**：scss 里只有 `-view-box-round { border-radius: 50% }` 这一条，
//     而代码判断是 `shape.includes('round')` ⇒ roundRect 也命中 50%，没有任何「圆角矩形」规则。
//     端口照抄（同样是圆），差异记进坑 112。
//   · 但同一份类名在**框那一层**用的是严格等于（index.tsx:266 `shape === 'round'`）⇒
//     roundRect 只有里面那张图是圆的，外面那条 outline 环与框底色仍是方的；
//     调整块同理只有 `round` 减到四块，roundRect 保持八块。
Item {
    id: control

    // ---- 官方 CropperProps ----
    property string className: ""
    property var style: undefined
    property string src: ""
    // 三项都要用「解析后的绝对 URL」：Image 自己会按组件基地址解析相对路径，C++ 那一侧不会，
    // 所以统一在这里解析一次，两条路读到的才是同一张图（远端 URL 端口只能显示、裁不了，见文件头）
    readonly property url resolvedSrc: control.src === "" ? "" : Qt.resolvedUrl(control.src)
    property var imgProps: undefined
    property string shape: "rect"
    property var aspectRatio: undefined
    property real defaultAspectRatio: 1
    property var zoom: undefined
    property var rotate: undefined
    property bool showResizeBox: true
    property var cropperBoxStyle: undefined
    property string cropperBoxCls: ""
    property color fill: "transparent"
    property real maxZoom: 3
    property real minZoom: 0.1
    property real zoomStep: 0.1
    property Item preview: null

    // 官方 onZoomChange（foundation notifyZoomChange）。不能叫 zoomChanged ——
    // 那是 `zoom` 属性自己的通知信号，同名会撞。
    signal zoomChange(real zoom)

    // cropperBoxStyle 是一条键级回退的内联样式表：写成函数而不是绑定，整个 map 被换掉时
    // 逐键读才跟得上（同 src/Popover.qml 的 styleOf）。只有带颜色语义的键有落点。
    function boxStyleOf(key, fallback) {
        const v = control.cropperBoxStyle ? control.cropperBoxStyle[key] : undefined
        return v === undefined || v === null ? fallback : v
    }

    // ---- 状态（官方 useState 的 imgData / cropperBox / zoom / rotate / loaded）----
    property real imgW: 0
    property real imgH: 0
    property real imgCX: 0
    property real imgCY: 0
    property real boxW: 0
    property real boxH: 0
    property real boxCX: 0
    property real boxCY: 0
    property real innerZoom: 1
    property real innerRotate: 0
    property bool loaded: false
    property real originalW: 0
    property real originalH: 0
    property real fitScale: 1

    // 拖拽中途量
    property string boxMoveDir: ""
    property int paramX: 0
    property int paramY: 0
    property real rangeXMin: 0
    property real rangeXMax: 0
    property real rangeYMin: 0
    property real rangeYMax: 0
    property point boxMoveStart
    property bool boxMoving: false
    property point imgMoveStart
    property bool imgMoving: false
    property real moveRangeXMin: 0
    property real moveRangeXMax: 0
    property real moveRangeYMin: 0
    property real moveRangeYMax: 0

    readonly property bool isRound: shape === "round" || shape === "roundRect"
    readonly property real boxX: boxCX - boxW / 2
    readonly property real boxY: boxCY - boxH / 2
    readonly property real imgX: imgCX - imgW / 2
    readonly property real imgY: imgCY - imgH / 2

    // 端口自造的兜底，不是官方值：`.semi-cropper` 在 scss 里没有任何宽高规则，尺寸全靠使用方
    // 给（demo 是 `style={{width: 550, height: 300}}`）。QML 这边不给尺寸的 Item 就是 0×0，
    // 整件什么都不画，所以留一对「与 demo 同数量级」的隐式尺寸当兜底。
    implicitWidth: 400
    implicitHeight: 300

    // ---- 加载完的初始布局（foundation.handleImageLoad :195-241）----
    function handleImageLoad(naturalW, naturalH) {
        const cw = control.width, ch = control.height;
        if (naturalW <= 0 || naturalH <= 0 || cw <= 0 || ch <= 0)
            return;
        let scale = 1;
        let w = 0, h = 0;
        if (naturalW / cw > naturalH / ch) {
            scale = cw / naturalW;
            w = cw;
            h = naturalH * scale;
        } else {
            scale = ch / naturalH;
            w = naturalW * scale;
            h = ch;
        }
        control.fitScale = scale;
        control.originalW = naturalW;
        control.originalH = naturalH;
        control.imgW = w;
        control.imgH = h;
        control.imgCX = cw / 2;
        control.imgCY = ch / 2;

        const aspect = control.aspectRatio || control.defaultAspectRatio;
        let bw = 0, bh = 0;
        if (cw / ch > aspect) {
            bw = ch * aspect;
            bh = ch;
        } else {
            bw = cw;
            bh = cw / aspect;
        }
        control.boxW = bw;
        control.boxH = bh;
        control.boxCX = cw / 2;
        control.boxCY = ch / 2;
        control.loaded = true;
    }

    // ---- 受控 rotate / zoom：绕裁切框中心做变换（index.tsx:128-176）----
    // 官方那段把 y 先取负再算（注释：以裁切框左上顶点为原点，y 方向与实际坐标系相反），
    // 端口保住同一套式子。
    function applyRotate(newRotate) {
        if (!control.loaded || newRotate === control.innerRotate)
            return;
        const angle = (newRotate - control.innerRotate) * Math.PI / 180;
        const rcx = control.boxCX, rcy = -control.boxCY;
        const icx = control.imgCX, icy = -control.imgCY;
        const nx = (icx - rcx) * Math.cos(angle) + (icy - rcy) * Math.sin(angle) + rcx;
        const ny = -(-(icx - rcx) * Math.sin(angle) + (icy - rcy) * Math.cos(angle) + rcy);
        control.innerRotate = newRotate;
        control.imgCX = nx;
        control.imgCY = ny;
    }

    function applyZoom(newZoom) {
        if (!control.loaded || newZoom === control.innerZoom)
            return;
        const scx = control.boxCX, scy = -control.boxCY;
        const icx = control.imgCX, icy = -control.imgCY;
        control.imgW = control.imgW / control.innerZoom * newZoom;
        control.imgH = control.imgH / control.innerZoom * newZoom;
        control.imgCX = (icx - scx) / control.innerZoom * newZoom + scx;
        control.imgCY = -((icy - scy) / control.innerZoom * newZoom + scy);
        control.innerZoom = newZoom;
    }

    onRotateChanged: control.applyRotate(Number(control.rotate))
    onZoomChanged: control.applyZoom(Number(control.zoom))

    // ---- 滚轮缩放（foundation.handleWheel :307-360）----
    function handleWheel(offsetX, offsetY, delta) {
        let next;
        if (delta < 0) {
            if (control.innerZoom + control.zoomStep <= control.maxZoom)
                next = Number((control.innerZoom + control.zoomStep).toFixed(2));
        } else if (delta > 0) {
            if (control.innerZoom - control.zoomStep >= control.minZoom)
                next = Number((control.innerZoom - control.zoomStep).toFixed(2));
        }
        if (next === undefined)
            return;
        const scx = offsetX, scy = -offsetY;
        const icx = control.imgCX, icy = -control.imgCY;
        control.imgW = control.imgW / control.innerZoom * next;
        control.imgH = control.imgH / control.innerZoom * next;
        control.imgCX = (icx - scx) / control.innerZoom * next + scx;
        control.imgCY = -((icy - scy) / control.innerZoom * next + scy);
        control.innerZoom = next;
        control.zoomChange(next);
    }

    // ---- 调整块：方向 → 参数（getMoveParamByDir :361-395）----
    function paramsFor(dir) {
        switch (dir) {
        case "tl": return [-1, -1];
        case "tm": return [0, -1];
        case "tr": return [1, -1];
        case "ml": return [-1, 0];
        case "mr": return [1, 0];
        case "bl": return [-1, 1];
        case "bm": return [0, 1];
        case "br": return [1, 1];
        default: return [0, 0];
        }
    }

    /// 比例锁定时每个方向能动的范围（getRangeForAspectChange :397-486）
    function computeAspectRanges(dir) {
        const cw = control.width, ch = control.height;
        const xMin = control.boxCX - control.boxW / 2, xMax = control.boxCX + control.boxW / 2;
        const yMin = control.boxCY - control.boxH / 2, yMax = control.boxCY + control.boxH / 2;
        const aspect = Number(control.aspectRatio);
        let width = 0, height = 0;
        let halfW = 0, halfH = 0;
        switch (dir) {
        case "tl":
            height = yMax; width = xMax;
            [width, height] = control.aspectHW(width, height, aspect);
            control.rangeXMin = xMax - width; control.rangeXMax = xMax;
            control.rangeYMin = yMax - height; control.rangeYMax = yMax;
            return;
        case "tm":
            height = yMax;
            halfW = Math.min(control.boxCX, cw - control.boxCX);
            width = 2 * halfW;
            [width, height] = control.aspectHW(width, height, aspect);
            control.rangeXMin = control.boxCX - width / 2;
            control.rangeXMax = control.boxCX + width / 2;
            control.rangeYMin = yMax - height; control.rangeYMax = yMax;
            return;
        case "tr":
            height = yMax; width = cw - xMin;
            [width, height] = control.aspectHW(width, height, aspect);
            control.rangeXMin = xMin; control.rangeXMax = xMin + width;
            control.rangeYMin = yMax - height; control.rangeYMax = yMax;
            return;
        case "ml":
            width = xMax;
            halfH = Math.min(control.boxCY, ch - control.boxCY);
            height = 2 * halfH;
            [width, height] = control.aspectHW(width, height, aspect);
            control.rangeXMin = xMax - width; control.rangeXMax = xMax;
            control.rangeYMin = control.boxCY - height / 2;
            control.rangeYMax = control.boxCY + height / 2;
            return;
        case "mr":
            width = cw - xMin;
            halfH = Math.min(control.boxCY, ch - control.boxCY);
            height = 2 * halfH;
            [width, height] = control.aspectHW(width, height, aspect);
            control.rangeXMin = xMin; control.rangeXMax = xMin + width;
            control.rangeYMin = control.boxCY - height / 2;
            control.rangeYMax = control.boxCY + height / 2;
            return;
        case "bl":
            height = ch - yMin; width = xMax;
            [width, height] = control.aspectHW(width, height, aspect);
            control.rangeXMin = xMax - width; control.rangeXMax = xMax;
            control.rangeYMin = yMin; control.rangeYMax = yMin + height;
            return;
        case "bm":
            height = ch - yMin;
            halfW = Math.min(control.boxCX, cw - control.boxCX);
            width = 2 * halfW;
            [width, height] = control.aspectHW(width, height, aspect);
            control.rangeXMin = control.boxCX - width / 2;
            control.rangeXMax = control.boxCX + width / 2;
            control.rangeYMin = yMin; control.rangeYMax = yMin + height;
            return;
        case "br":
            height = ch - yMin; width = cw - xMin;
            [width, height] = control.aspectHW(width, height, aspect);
            control.rangeXMin = xMin; control.rangeXMax = xMin + width;
            control.rangeYMin = yMin; control.rangeYMax = yMin + height;
            return;
        default:
            return;
        }
    }

    /// utils.getAspectHW
    function aspectHW(width, height, aspect) {
        if (width / height > aspect)
            width = height * aspect;
        else
            height = width / aspect;
        return [width, height];
    }

    function beginCornerDrag(dir) {
        control.boxMoveDir = dir;
        const p = control.paramsFor(dir);
        control.paramX = p[0];
        control.paramY = p[1];
        if (control.aspectRatio) {
            control.computeAspectRanges(dir);
        } else {
            control.rangeXMin = 0; control.rangeXMax = control.width;
            control.rangeYMin = 0; control.rangeYMax = control.height;
        }
    }

    /// 比例锁定那档的逐方向算法（handleCornerAspectMouseMove :521-608）
    function dragCornerAspect(offsetX, offsetY) {
        const aspect = Number(control.aspectRatio);
        const dir = control.boxMoveDir;
        let w = control.boxW, h = control.boxH;
        let cx = control.boxCX, cy = control.boxCY;
        let ox = 0, oy = 0;
        if (dir === "ml" || dir === "mr")
            ox = control.clamp(offsetX, control.rangeXMin, control.rangeXMax);
        else
            oy = control.clamp(offsetY, control.rangeYMin, control.rangeYMax);

        switch (dir) {
        case "tl":
            h = control.rangeYMax - oy; w = h * aspect;
            cx = control.rangeXMax - w / 2; cy = control.rangeYMax - h / 2;
            break;
        case "tm":
            h = control.rangeYMax - oy; w = h * aspect;
            cx = control.boxCX; cy = control.rangeYMax - h / 2;
            break;
        case "tr":
            h = control.rangeYMax - oy; w = h * aspect;
            cx = control.rangeXMin + w / 2; cy = control.rangeYMax - h / 2;
            break;
        case "ml":
            w = control.rangeXMax - ox; h = w / aspect;
            cx = control.rangeXMax - w / 2; cy = control.boxCY;
            break;
        case "mr":
            w = ox - control.rangeXMin; h = w / aspect;
            cx = control.rangeXMin + w / 2; cy = control.boxCY;
            break;
        case "bl":
            h = oy - control.rangeYMin; w = h * aspect;
            cx = control.rangeXMax - w / 2; cy = control.rangeYMin + h / 2;
            break;
        case "bm":
            h = oy - control.rangeYMin; w = h * aspect;
            cx = control.boxCX; cy = control.rangeYMin + h / 2;
            break;
        case "br":
            h = oy - control.rangeYMin; w = h * aspect;
            cx = control.rangeXMin + w / 2; cy = control.rangeYMin + h / 2;
            break;
        default:
            return;
        }
        // 缩到 0 时官方翻转方向并重算范围（:600-603）
        if (h === 0 && w === 0) {
            control.boxMoveDir = control.flipDir(control.boxMoveDir);
            control.computeAspectRanges(control.boxMoveDir);
        }
        control.boxW = w;
        control.boxH = h;
        control.boxCX = cx;
        control.boxCY = cy;
    }

    function flipDir(dir) {
        let out = dir;
        if (out.indexOf("t") >= 0)
            out = out.replace("t", "b");
        else if (out.indexOf("b") >= 0)
            out = out.replace("b", "t");
        if (out.indexOf("l") >= 0)
            out = out.replace("l", "r");
        else if (out.indexOf("r") >= 0)
            out = out.replace("r", "l");
        return out;
    }

    /// 自由档（handleCornerMouseMove :636-674）
    function dragCornerFree(offsetX, offsetY) {
        const ox = control.clamp(offsetX, control.rangeXMin, control.rangeXMax);
        const oy = control.clamp(offsetY, control.rangeYMin, control.rangeYMax);
        let w = control.boxW, h = control.boxH;
        let cx = control.boxCX, cy = control.boxCY;
        let px = control.paramX, py = control.paramY;
        if (px) {
            const x = control.boxCX + px * control.boxW / 2;
            w = control.boxW + px * (ox - x);
            if (w < 0) {
                w = -w;
                px = -px;
                control.paramX = px;
            }
            cx = ox - px * w / 2;
        }
        if (py) {
            const y = control.boxCY + py * control.boxH / 2;
            h = control.boxH + py * (oy - y);
            if (h < 0) {
                h = -h;
                py = -py;
                control.paramY = py;
            }
            cy = oy - py * h / 2;
        }
        control.boxW = w;
        control.boxH = h;
        control.boxCX = cx;
        control.boxCY = cy;
    }

    function beginBoxDrag(clientX, clientY) {
        control.boxMoveStart = Qt.point(clientX, clientY);
        control.boxMoving = true;
        // 框中心点的可动范围：整框不许出容器（:705-712 用的是 boundingRect 的宽高）
        control.moveRangeXMin = control.boxW / 2;
        control.moveRangeXMax = control.width - control.boxW / 2;
        control.moveRangeYMin = control.boxH / 2;
        control.moveRangeYMax = control.height - control.boxH / 2;
    }

    /// 官方是「每次 move 都以上一次的位置为基准加增量」⇒ 夹边界时超出那部分会永久丢掉，
    /// 端口保住这个增量口径（不是从按下点一次性算）。
    function dragBox(clientX, clientY) {
        if (!control.boxMoving)
            return;
        const dx = clientX - control.boxMoveStart.x;
        const dy = clientY - control.boxMoveStart.y;
        control.boxCX = control.clamp(control.boxCX + dx,
                                      control.moveRangeXMin, control.moveRangeXMax);
        control.boxCY = control.clamp(control.boxCY + dy,
                                      control.moveRangeYMin, control.moveRangeYMax);
        control.boxMoveStart = Qt.point(clientX, clientY);
    }

    function beginImgDrag(clientX, clientY) {
        control.imgMoveStart = Qt.point(clientX, clientY);
        control.imgMoving = true;
    }

    /// 拖遮罩移动图片：官方**不夹边界**（可以把图完全拖出框）
    function dragImg(clientX, clientY) {
        if (!control.imgMoving)
            return;
        control.imgCX += clientX - control.imgMoveStart.x;
        control.imgCY += clientY - control.imgMoveStart.y;
        control.imgMoveStart = Qt.point(clientX, clientY);
    }

    function clamp(value, min, max) {
        return Math.min(Math.max(value, min), max);
    }

    // ---- 裁切结果（foundation.getCropperCanvas :819-902 的那套 relative* 计算）----
    readonly property real realZoom: control.innerZoom * control.fitScale

    function cropGeometry() {
        const angle = control.innerRotate * Math.PI / 180;
        const sine = Math.abs(Math.sin(angle));
        const cosine = Math.abs(Math.cos(angle));
        const containerWidth = control.originalW * cosine + control.originalH * sine;
        const containerHeight = control.originalH * cosine + control.originalW * sine;
        const cropContainerWidth = containerWidth * control.realZoom;
        const cropContainerHeight = containerHeight * control.realZoom;
        const containerTop = control.imgCY - cropContainerHeight / 2;
        const containerLeft = control.imgCX - cropContainerWidth / 2;
        const boxLeft = control.boxCX - control.boxW / 2;
        const boxTop = control.boxCY - control.boxH / 2;
        return {
            containerWidth: containerWidth,
            containerHeight: containerHeight,
            cropLeft: (boxLeft - containerLeft) / control.realZoom,
            cropTop: (boxTop - containerTop) / control.realZoom,
            cropWidth: control.boxW / control.realZoom,
            cropHeight: control.boxH / control.realZoom,
            rotate: control.innerRotate,
            fill: control.fill
        };
    }

    /// 官方 getCropperCanvas() 的等价物：返回一张结果图（QImage）
    function cropToImage() {
        const g = control.cropGeometry();
        return CropperRuntime.cropToImage(control.resolvedSrc, control.originalW, control.originalH,
                                          g.cropLeft, g.cropTop,
                                          g.cropWidth, g.cropHeight, g.rotate, g.fill);
    }

    /// 给使用方显示用的 URL（官方是 canvas.toDataURL()）
    function cropToUrl() {
        return CropperRuntime.putImage(control.cropToImage());
    }

    // ---- 实时预览（foundation.renderPreview / updatePreview :243-306）----
    // 官方往 preview() 给的 DOM 节点里 appendChild 一张 img，再按「预览容器 / 裁切框」的比例
    // 摆它。端口的 preview 收一个 Item，里面挂这张 Image。
    // **renderPreview 只把容器当时的 getBoundingClientRect() 记一次**（previewContainerInitSize），
    // 后面 updatePreview 一边读这份记录、一边把容器的 width/height 改掉 ⇒ 端口必须同样存初值，
    // 否则每次同步都拿上一轮改过的尺寸当基准，框会一路缩到 0。
    property Item previewImage: null
    property real previewInitW: 0
    property real previewInitH: 0

    Component {
        id: previewPart

        Image {
            objectName: "cropperPreviewImage"

            source: control.resolvedSrc
            fillMode: Image.Stretch
            smooth: true
            transformOrigin: Item.Center
        }
    }

    // renderPreview 那一拍：替宿主开 overflow:hidden、往里挂这张 Image。
    // 容器初值**不在这里记** —— 官方是在 img onLoad 那一拍读 getBoundingClientRect()，
    // 而端口的 `preview: 某个同组件里的项` 这一条绑定会在两项都还没排布好时就评上，
    // 当场读到的是 0×0，记一次就永远错（实测 gallery 那一节预览区整块 0 高）。
    // 所以记初值挪到 syncPreview 里「第一次量到正尺寸」那一拍。
    function attachPreview() {
        control.preview.clip = true;         // previewNode.style.overflow = 'hidden'
        control.previewImage = previewPart.createObject(control.preview);
    }

    // updatePreview 那一拍：只读 previewInitW/H 与当前状态
    function syncPreview() {
        if (control.preview === null || control.previewImage === null)
            return;
        if (!control.loaded)
            return;
        if (control.previewInitW <= 0 || control.previewInitH <= 0) {
            control.previewInitW = control.preview.width;
            control.previewInitH = control.preview.height;
            if (control.previewInitW <= 0 || control.previewInitH <= 0)
                return;                      // 宿主还没定下尺寸 ⇒ 这一拍整块不做，等下一拍
        }
        const img = control.previewImage;
        const pw = control.previewInitW, ph = control.previewInitH;
        let zoom = 1;
        let previewWidth = pw, previewHeight = ph;
        if (pw < ph) {
            zoom = pw / control.boxW;
            const tempHeight = zoom * control.boxH;
            if (tempHeight > ph) {
                zoom = ph / control.boxH;
                previewWidth = zoom * control.boxW;
            } else {
                previewHeight = tempHeight;
            }
        } else {
            zoom = ph / control.boxH;
            const tempWidth = zoom * control.boxW;
            if (tempWidth > pw) {
                zoom = pw / control.boxW;
                previewHeight = zoom * control.boxH;
            } else {
                previewWidth = tempWidth;
            }
        }
        // index.tsx:216-229 那五个量：imgData 的宽高 + 图相对框的偏移，全都再乘一遍 zoom
        img.width = control.imgW * zoom;
        img.height = control.imgH * zoom;
        img.x = (control.imgX - control.boxX) * zoom;
        img.y = (control.imgY - control.boxY) * zoom;
        img.rotation = control.innerRotate;
        control.preview.width = previewWidth;
        control.preview.height = previewHeight;
    }

    onWidthChanged: {
        control.handleContainerResize();
        control.tryLoad();
        control.schedulePreview();
    }
    onHeightChanged: {
        control.tryLoad();
        control.schedulePreview();
    }

    // 官方在 render() 里无条件调 updatePreview（index.tsx:224-229）⇒ 端口的口径是
    // 「imgData / cropperBox / rotate / loaded 任一项变了就同步一次预览」。这些量都是普通
    // 属性，一条一条挂 Changed 处理器；漏一条的话预览会停在上一拍（用例逐条钉住）。
    //
    // 摆位那一段必须晚一拍：syncPreview 读的是 imgX / boxX 这类**由同一批状态派生**的绑定属性，
    // 而同周期的 Changed 处理器读不到下游绑定的新值（本项目坑登记过），当场算会把图钉在上一拍。
    // 挂图那一段反而必须当场做 —— 它只读 preview 自己，而且「preview 刚被赋上」这一拍
    // 往往就是最后一拍（后面没有任何状态变化来触发那个 callLater）。
    function schedulePreview() {
        if (control.preview !== null && control.previewImage === null)
            control.attachPreview();
        Qt.callLater(control.syncPreview);
    }

    onImgWChanged: control.schedulePreview()
    onImgHChanged: control.schedulePreview()
    onImgCXChanged: control.schedulePreview()
    onImgCYChanged: control.schedulePreview()
    onBoxWChanged: control.schedulePreview()
    onBoxHChanged: control.schedulePreview()
    onBoxCXChanged: control.schedulePreview()
    onBoxCYChanged: control.schedulePreview()
    onInnerRotateChanged: control.schedulePreview()
    onLoadedChanged: control.schedulePreview()
    // preview 这一项是使用方后挂上来的（官方：preview 是个回调，render 每拍都会去要一次）
    onPreviewChanged: control.schedulePreview()

    // ---- 容器宽变化时等比缩放（handleResize :172-203，官方挂 ResizeObserver）----
    // 官方那条「第一次回调只置 initial 标记、不缩放」是因为 ResizeObserver 在 observe 时
    // 就会以当前尺寸回调一次（ratio 恒为 1，等于不做）。端口没有那个首回调，
    // 基准改由 Component.onCompleted 记一次，`lastContainerWidth <= 0` 就是「还没记过」。
    property real lastContainerWidth: 0

    function handleContainerResize() {
        if (!control.loaded || control.lastContainerWidth === control.width
                || control.lastContainerWidth <= 0)
            return;
        const ratio = control.width / control.lastContainerWidth;
        control.imgW *= ratio;
        control.imgH *= ratio;
        control.imgCX *= ratio;
        control.imgCY *= ratio;
        control.fitScale *= ratio;
        control.lastContainerWidth = control.width;
        control.resizeBoxToFit(ratio);
    }

    /// getCropperBoxWhenResize :110-168：等比放大之后再把框夹回容器里
    function resizeBoxToFit(ratio) {
        const cw = control.width, ch = control.height;
        let w = control.boxW * ratio, h = control.boxH * ratio;
        let cx = control.boxCX * ratio, cy = control.boxCY * ratio;
        let xMin = cx - w / 2, xMax = cx + w / 2;
        let yMin = cy - h / 2, yMax = cy + h / 2;
        if (control.aspectRatio) {
            if (xMax > cw) {
                xMax = cw;
                xMin = w > cw ? 0 : cw - w;
                w = xMax - xMin;
                h = w / Number(control.aspectRatio);
                yMax = yMin + h;
            }
            if (yMax > ch) {
                yMax = ch;
                yMin = h > ch ? 0 : ch - h;
                h = yMax - yMin;
                w = h * Number(control.aspectRatio);
                xMax = xMin + w;
            }
        } else {
            if (xMax > cw) {
                xMax = cw;
                xMin = w > cw ? 0 : cw - w;
            }
            if (yMax > ch) {
                yMax = ch;
                yMin = h > ch ? 0 : ch - h;
            }
        }
        control.boxW = xMax - xMin;
        control.boxH = yMax - yMin;
        control.boxCX = (xMax + xMin) / 2;
        control.boxCY = (yMax + yMin) / 2;
    }

    // ---- 视觉：图层层 ----
    Item {
        id: imageLayer

        objectName: "cropperImageLayer"

        anchors.fill: parent
        clip: true                                   // .semi-cropper-img-wrapper overflow: hidden

        Image {
            objectName: "cropperImage"

            x: control.imgX
            y: control.imgY
            width: control.imgW
            height: control.imgH
            rotation: control.innerRotate
            transformOrigin: Item.Center
            source: control.resolvedSrc
            fillMode: Image.Stretch
            smooth: true
            // 官方给 <img> 挂了 crossOrigin='anonymous'，端口没有 CORS 那一层
        }
    }

    // ---- 遮罩层：按在框外拖 = 移动图片 ----
    Rectangle {
        id: mask

        objectName: "cropperMask"

        anchors.fill: parent
        color: Theme.current.colorOverlayBg

        MouseArea {
            objectName: "cropperMaskArea"

            anchors.fill: parent
            // `-mask { cursor: move }` —— 框外那一片拖的是图
            cursorShape: Qt.SizeAllCursor
            onPressed: function (mouse) { control.beginImgDrag(mouse.x, mouse.y) }
            onPositionChanged: function (mouse) { control.dragImg(mouse.x, mouse.y) }
            onReleased: control.imgMoving = false
        }
    }

    // ---- 裁切框 ----
    Item {
        id: box

        objectName: "cropperBox"

        x: control.boxX
        y: control.boxY
        width: control.boxW
        height: control.boxH

        // cropperBoxStyle 展开在框这一层（index.tsx:265-272）⇒ 只有带颜色语义的那条键能落地：
        // 图没铺满框时（拖图把图拖出框）那块底色会露出来。
        Rectangle {
            objectName: "cropperBoxBackground"

            anchors.fill: parent
            color: control.boxStyleOf("backgroundColor", "transparent")
            radius: control.shape === "round" ? width / 2 : 0
        }

        // outline: 1px solid colorPrimary —— 是 outline，不占布局。
        // `shape === 'round'` 时框自己那层也吃了 VIEW_BOX_ROUND 的类名（index.tsx:266 是严格等于，
        // roundRect 不吃那条），浏览器的 outline 跟着 border-radius 走 ⇒ 环也变圆。
        Rectangle {
            objectName: "cropperBoxOutline"

            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.width: 1
            border.color: control.boxStyleOf("outlineColor", Theme.current.colorPrimary)
            radius: control.shape === "round" ? width / 2 : 0
        }

        // 框里那张亮图（.semi-cropper-view-box + -view-img），clip 把超出框的部分裁掉。
        Item {
            id: viewBox

            objectName: "cropperViewBox"

            anchors.fill: parent
            clip: true

            Image {
                objectName: "cropperViewImage"

                x: control.imgX - control.boxX
                y: control.imgY - control.boxY
                width: control.imgW
                height: control.imgH
                rotation: control.innerRotate
                transformOrigin: Item.Center
                source: control.resolvedSrc
                fillMode: Image.Stretch
                smooth: true
            }
        }

        // round / roundRect 档：官方那条 `-view-box-round { border-radius: 50% }` 配 overflow:hidden
        // 把亮图裁成椭圆，椭圆外那一圈露出的是遮罩。QML 的 clip 只裁矩形。
        // 这里反过来做：图照常铺满框，上面盖一条「框减椭圆」的偶环形带，填的就是遮罩那个颜色 ——
        // 底下两张图是同一张图的同一位置，半透明遮罩叠上去的结果与官方一致。
        // （2026-10-21 更正：当年记的「MultiEffect 这条路走不通、layer.enabled + visible:false 的
        //  Item 当 source 会画成全透明」已被 Avatar 那轮逐像素判废 —— 隐藏源（Image 或分层容器）
        // 当 source 都画得出来，真门槛只在 maskSource 要能当纹理源，见 PROGRESS.md 坑 117。
        // 这一支的遮罩色是已知的 colorOverlayBg，偶环形带本来就是更省的做法，保持不动；
        // 要改成遮罩路线得先重做一轮 Cropper 的像素复核。）
        Shape {
            id: roundFrame

            objectName: "cropperViewRoundFrame"

            anchors.fill: parent
            visible: control.isRound
            preferredRendererType: Shape.CurveRenderer

            function framePath() {
                const w = roundFrame.width, h = roundFrame.height;
                const rx = w / 2, ry = h / 2;
                return "M0,0 H" + w + " V" + h + " H0 Z"
                        + " M0," + ry + " A" + rx + "," + ry + " 0 1,0 " + w + "," + ry
                        + " A" + rx + "," + ry + " 0 1,0 0," + ry + " Z";
            }

            ShapePath {
                fillColor: Theme.current.colorOverlayBg
                strokeColor: "transparent"
                strokeWidth: 0
                fillRule: ShapePath.OddEvenFill

                PathSvg {
                    path: roundFrame.framePath()
                }
            }
        }

        MouseArea {
            objectName: "cropperBoxArea"

            anchors.fill: parent
            // `-view-box { cursor: move }` 铺满整块框 ⇒ 框内那一片也是「移动」光标
            //（八个调整块声明在后面、压在它上面，各自带 resize 光标）
            cursorShape: Qt.SizeAllCursor
            // 官方 handleCropperBoxMouseDown 里那句「落在 corner 上就直接 return」：
            // QML 里调整块是本项的子项且更靠上，按下被它们吃掉，不需要那条判断
            onPressed: function (mouse) { control.beginBoxDrag(mouse.x + control.boxX, mouse.y + control.boxY) }
            onPositionChanged: function (mouse) { control.dragBox(mouse.x + control.boxX, mouse.y + control.boxY) }
            onReleased: control.boxMoving = false
        }

        Repeater {
            objectName: "cropperCornerRepeater"

            model: control.cornerModel()

            delegate: MouseArea {
                id: corner

                required property var modelData

                objectName: "cropperCorner-" + modelData
                property string dir: modelData

                width: 10
                height: 10
                x: corner.offsetX
                y: corner.offsetY
                visible: control.showResizeBox && control.loaded
                cursorShape: corner.cursorFor(dir)

                // `-box-corner { background: $color-cropper_box_corner-bg }` = `--semi-color-primary`，
                // 10×10 的实心方块骑在边线上（`z-index: 1` ⇒ 盖在框那条 outline 上面）。
                // 官方那八块是**看得见**的，命中区就是方块本身。
                Rectangle {
                    objectName: "cropperCornerFace"

                    anchors.fill: parent
                    color: Theme.current.colorPrimary
                }

                // CSS 那八条是 left/right/top/bottom: -5px（块 10×10，骑在边线上）。
                // 换成 x/y：右/下边那条边线在 width/height 处，块要往回让半个身位。
                readonly property real offsetX: corner.sideFor(dir, "x")
                readonly property real offsetY: corner.sideFor(dir, "y")

                function sideFor(direction, axis) {
                    if (axis === "x") {
                        if (direction.charAt(1) === "l")
                            return -5;
                        if (direction.charAt(1) === "r")
                            return box.width - 5;
                        return box.width / 2 - 5;
                    }
                    if (direction.charAt(0) === "t")
                        return -5;
                    if (direction.charAt(0) === "b")
                        return box.height - 5;
                    return box.height / 2 - 5;
                }

                function cursorFor(direction) {
                    switch (direction) {
                    case "tl":
                    case "br":
                        return Qt.SizeFDiagCursor;
                    case "tr":
                    case "bl":
                        return Qt.SizeBDiagCursor;
                    case "tm":
                    case "bm":
                        return Qt.SizeVerCursor;
                    default:
                        return Qt.SizeHorCursor;
                    }
                }

                onPressed: control.beginCornerDrag(corner.dir)
                onPositionChanged: function (mouse) {
                    const p = corner.mapToItem(control, mouse.x, mouse.y);
                    if (control.aspectRatio)
                        control.dragCornerAspect(p.x, p.y);
                    else
                        control.dragCornerFree(p.x, p.y);
                }
                onReleased: {
                    control.paramX = 0;
                    control.paramY = 0;
                }
            }
        }
    }

    function cornerModel() {
        if (control.shape === "round")
            return ["tm", "ml", "mr", "bm"];
        return ["tl", "tm", "tr", "ml", "mr", "bl", "bm", "br"];
    }

    // ---- 滚轮：整个容器范围都吃（官方把 wheel 绑在 container 上）----
    // WheelHandler 不认 acceptedButtons（qquickwheelhandler.cpp:521-527 明说那条属性对它无意义），
    // 所以不用为了「不抢鼠标」去设 Qt.NoButton。
    WheelHandler {
        objectName: "cropperWheel"

        onWheel: function (event) {
            // 上游读 e.deltaY（向下滚为正、向上放大）；Qt 的 angleDelta.y 符号正好相反。
            // WheelEvent 在 Qt6 只有 x/y（没有 5.x 的 point.position，qquickevents_p_p.h:187-188）
            control.handleWheel(event.x, event.y, -event.angleDelta.y);
            event.accepted = true;              // e.preventDefault()
        }
    }

    // ---- 加载 ----
    // 上游把 handleImageLoad 挂在 <img onLoad> 上，容器尺寸读的是那一刻的 clientWidth/Height。
    // 端口两个时机都要补：Image 的 status（异步到位那一拍，绝大多数走这条）与
    // Component.onCompleted（同一帧就已经 Ready 的那条）。原始尺寸读 loader 的隐式宽高 ——
    // 不能用 sourceSize，那个对 SVG 按设备像素比放大（坑 110）；隐式档是设备无关的自然尺寸，
    // 跟 C++ 那边 QImageReader 读到的是同一个数。
    property real naturalW: 0
    property real naturalH: 0
    property string laidOutSrc: ""

    function tryLoad() {
        // 一条源只排一次版：上游的 handleImageLoad 只挂在 <img onLoad> 上，
        // 容器宽变化走的是 handleResize 那套等比缩放，不是重新适配。
        if (control.laidOutSrc === control.src)
            return;
        if (control.naturalW <= 0 || control.naturalH <= 0)
            return;
        if (control.width <= 0 || control.height <= 0)
            return;
        control.handleImageLoad(control.naturalW, control.naturalH);
        if (control.loaded)
            control.laidOutSrc = control.src;
    }

    Image {
        id: loader

        visible: false
        source: control.resolvedSrc

        onStatusChanged: {
            if (status === Image.Ready) {
                control.naturalW = implicitWidth;
                control.naturalH = implicitHeight;
                control.tryLoad();
            } else if (status === Image.Error) {
                control.loaded = false;
            }
        }
    }

    Component.onCompleted: {
        control.lastContainerWidth = control.width;      // 等比缩放的基准（见 handleContainerResize）
        if (loader.status === Image.Ready) {
            control.naturalW = loader.implicitWidth;
            control.naturalH = loader.implicitHeight;
            control.tryLoad();
        }
    }
}
