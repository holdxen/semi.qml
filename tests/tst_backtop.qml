import QtQuick
import QtTest
import Semi

// BackTop 回到顶部。规格照 packages/semi-ui/backTop/index.tsx +
// semi-foundation/backTop/{foundation.ts,constants.ts,backtop.scss,variables.scss,rtl.scss}，
// 数值逐条对编译后的 packages/semi-ui/dist/css/semi.css（`.semi-backtop` 与
// `.semi-button…-with-icon-only` 那一组）。
//
// 这份用例盯的几条（端口口径全写在 src/BackTop.qml 文件头）：
//   · 可见性是**命令式 state**：只在挂载与「挂载时挂上的那只容器」滚动时更新 ⇒
//     改 `visibilityHeight` 不立刻重算、换 `target` 不改挂（官方没有 componentDidUpdate）；
//   · 判据是严格大于（`scrollTop > visibilityHeight`）；
//   · 点击走 lodash throttle（leading + trailing），**窗口冻在挂载时的 duration**，
//     而滚动动画的时长每次点击现读 props ⇒ 同一份 duration 两条命运；
//   · 官方 onClick 顺序是先起滚动再发回调（端口用 `scrolling` 这条观察口钉住）；
//   · 默认那颗是 `IconButton theme="light" icon={<IconChevronUp/>}`（icon-only 默认档 32×32），
//     `content`（官方 children）整颗替换；
//   · 不可见时官方 render 返回 null ⇒ 那颗按钮压根不存在，点不着。
//
// 跑法（本仓约定，优先 offscreen）：
//   QT_QPA_PLATFORM=offscreen ./cmake-build-debug/tests/tst_semi -input tests/tst_backtop.qml
TestCase {
    id: testCase

    name: "BackTop"
    when: windowShown
    width: 900
    height: 600

    property var clicks: []

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
        testCase.clicks = [];
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
    }

    function cleanup() {
        Theme.reset();
        Theme.mode = Theme.Light;
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        const o = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "bt");
        wait(60);
        return o;
    }

    function part(owner, name) {
        const node = testCase.findChild(owner, name);
        verify(node !== null && node !== undefined, "找不到 " + name);
        return node;
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 0.5,
            (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    /// 一只 300×200 的容器 + 一颗 BackTop。`extra` 拼进 BackTop 的属性里
    function stage(extra) {
        return make("Item { width: 300; height: 200;"
            + " Flickable { id: view; objectName: 'view'; anchors.fill: parent; contentHeight: 2000;"
            + " boundsBehavior: Flickable.StopAtBounds }"
            + " BackTop { objectName: 'bar'; target: view;" + extra + " } }");
    }

    // ============================================================ 属性面与缺省值
    function test_propDefaults() {
        const host = stage("")
        const bar = part(host, "bar")
        compare(bar.visibilityHeight, 400);
        compare(bar.duration, 450, "官方缺省 450（旧端口写的是 300）");
        compare(bar.rightMargin, 100, "$spacing-backtop-right");
        compare(bar.bottomMargin, 50, "$spacing-backtop-bottom");
        compare(bar.z, 10, "$z-backtop");
        compare(bar.content, null, "没给 children ⇒ 走默认那颗");
        compare(bar.hasCustom, false);
        compare(bar.className, "");
        compare(bar.style, undefined);
        compare(bar.shown, false, "官方 state.visible 初值 false");
        compare(bar.visible, false, "没滚动 ⇒ 整颗不存在");
        compare(bar.throttleWindow, 450, "节流窗口在挂载时取的是 duration 那份快照");
        host.destroy()
    }

    // ============================================================ 可见性判据
    function test_shownUsesStrictGreaterThan() {
        const host = stage("")
        const bar = part(host, "bar")
        const view = part(host, "view")
        view.contentY = 400
        wait(40)
        compare(bar.shown, false, "正好等于阈值不算（官方是 > 不是 >=）");
        view.contentY = 401
        wait(40)
        compare(bar.shown, true);
        view.contentY = 400
        wait(40)
        compare(bar.shown, false, "退回去也要收起来");
        host.destroy()
    }

    function test_visibleComputedAtMount() {
        // 官方 init() 挂完监听就自己调一次 handleScroll ⇒ 容器一进来就是滚过的，也算浮出态
        const host = make("Item { width: 300; height: 200;"
            + " Flickable { id: view; objectName: 'view'; anchors.fill: parent; contentHeight: 2000;"
            + " boundsBehavior: Flickable.StopAtBounds }"
            + " Loader { objectName: 'slot'; active: false;"
            + " sourceComponent: Component { BackTop { objectName: 'bar'; target: view; visibilityHeight: 400 } } } }")
        const view = part(host, "view")
        view.contentY = 800
        wait(40)
        const slot = part(host, "slot")
        slot.active = true
        wait(60)
        const bar = part(host, "bar")
        compare(bar.target, view, "Loader 里那份 target 绑的是同一只容器");
        compare(bar.shown, true, "挂载时现算一次，不需要有人先滚一下");
        host.destroy()
    }

    function test_mountWithoutTargetNeverShows() {
        const host = make("Item { width: 300; height: 200;"
            + " Flickable { id: view; objectName: 'view'; anchors.fill: parent; contentHeight: 2000;"
            + " boundsBehavior: Flickable.StopAtBounds }"
            + " BackTop { objectName: 'bar'; visibilityHeight: 400 } }")
        const bar = part(host, "bar")
        const view = part(host, "view")
        compare(bar.target, null);
        view.contentY = 900
        wait(40)
        compare(bar.shown, false, "官方 init() 里 `!targetNode` 直接 return ⇒ 谁都不听");
        bar.target = view
        view.contentY = 901
        wait(40)
        compare(bar.shown, false, "补上 target 也不会改挂（官方只 componentDidMount 一次）");
        host.destroy()
    }

    function test_visibilityHeightChangeWaitsForNextScroll() {
        const host = stage("")
        const bar = part(host, "bar")
        const view = part(host, "view")
        view.contentY = 500
        wait(40)
        compare(bar.shown, true);
        view.contentY = 300
        wait(40)
        compare(bar.shown, false);
        bar.visibilityHeight = 100
        wait(40)
        compare(bar.shown, false, "改阈值不会立刻重算（官方没有 componentDidUpdate）");
        view.contentY = 301
        wait(40)
        compare(bar.shown, true, "下一次滚动才吃到新阈值（handleScroll 现读 props）");
        host.destroy()
    }

    function test_targetIsBoundOnceButReadFresh() {
        const host = make("Item { width: 300; height: 200;"
            + " Flickable { id: viewA; objectName: 'viewA'; anchors.fill: parent; contentHeight: 2000;"
            + " boundsBehavior: Flickable.StopAtBounds }"
            + " Flickable { id: viewB; objectName: 'viewB'; anchors.fill: parent; contentHeight: 2000;"
            + " boundsBehavior: Flickable.StopAtBounds }"
            + " BackTop { objectName: 'bar'; target: viewA; visibilityHeight: 400 } }")
        const bar = part(host, "bar")
        const a = part(host, "viewA")
        const b = part(host, "viewB")
        a.contentY = 500
        wait(40)
        compare(bar.shown, true);
        bar.target = b
        wait(40)
        compare(bar.shown, true, "换 target 不重算");
        a.contentY = 600
        wait(40)
        compare(bar.shown, false, "监听还挂在旧容器上，但判据读的是**新**容器（0 > 400 不成立）");
        b.contentY = 900
        wait(40)
        compare(bar.shown, false, "新容器滚动没人听 ⇒ 值不动");
        host.destroy()
    }

    // ============================================================ 点击与节流
    function test_clickScrollsToTopAndEmits() {
        const host = stage("duration: 120; visibilityHeight: -1")
        const bar = part(host, "bar")
        const view = part(host, "view")
        view.contentY = 800
        wait(40)
        compare(bar.visible, true, "visibilityHeight: -1 ⇒ 一进来就是浮出态（上游测试也这么干）");
        bar.clicked.connect(function () { testCase.clicks.push(bar.scrolling); });
        const face = part(bar, "backTopFace");
        mouseClick(face, face.width / 2, face.height / 2);
        wait(60)
        compare(testCase.clicks.length, 1);
        verify(testCase.clicks[0] === true,
            "回调里动画已经在跑 ⇒ 官方是先 setScrollTop(0) 再 notifyClick");
        wait(400)
        near(view.contentY, 0, "滚回顶部");
        host.destroy()
    }

    function test_clickIsThrottled() {
        const host = stage("duration: 300; visibilityHeight: -1")
        const bar = part(host, "bar")
        bar.clicked.connect(function () { testCase.clicks.push(1); });
        const face = part(bar, "backTopFace");
        mouseClick(face, face.width / 2, face.height / 2);
        wait(30)
        compare(testCase.clicks.length, 1, "leading 那一次立刻执行");
        mouseClick(face, face.width / 2, face.height / 2);
        wait(30)
        compare(testCase.clicks.length, 1, "窗口内的第二次不执行");
        wait(400)
        compare(testCase.clicks.length, 2, "trailing 在窗口末尾补一次");
        mouseClick(face, face.width / 2, face.height / 2);
        wait(30)
        compare(testCase.clicks.length, 3, "窗口过去后又是新的 leading");
        wait(400)
        compare(testCase.clicks.length, 3, "窗口内没人再点 ⇒ 什么都不补");
        host.destroy()
    }

    function test_throttleWindowFreezesAtMount() {
        // 官方 handler 是 componentDidMount 里用当时的 duration 造的
        const host = stage("duration: 600; visibilityHeight: -1")
        const bar = part(host, "bar")
        compare(bar.throttleWindow, 600, "窗口取的是挂载时那份 duration");
        bar.clicked.connect(function () { testCase.clicks.push(1); });
        bar.duration = 60
        wait(40)
        const face = part(bar, "backTopFace");
        mouseClick(face, face.width / 2, face.height / 2);
        wait(30)
        mouseClick(face, face.width / 2, face.height / 2);
        wait(220)
        compare(testCase.clicks.length, 1, "窗口是挂载时那份 600，不是现在的 60");
        wait(600)
        compare(testCase.clicks.length, 2, "到 600 才补 trailing");
        host.destroy()
    }

    function test_animationReadsLiveDurationAndCubicBezier() {
        const host = stage("duration: 100; visibilityHeight: -1")
        const bar = part(host, "bar")
        const view = part(host, "view")
        view.contentY = 800
        wait(40)
        bar.duration = 900
        wait(40)
        const face = part(bar, "backTopFace");
        mouseClick(face, face.width / 2, face.height / 2);
        wait(30)
        const anim = bar.scrollAnimation;
        compare(anim.from, 800, "起点读的是点击那一刻的 contentY");
        compare(anim.duration, 900, "动画时长现读 props（只有节流窗口是快照）");
        compare(anim.to, 0);
        // 合法 bezierCurve 赋值会把整条曲线连 type 换成 BezierSpline（setter 里
        // `*this = newEasingCurve`，`easing.type` 那行因此是死的、已删，坑 134）
        compare(anim.easing.type, Easing.BezierSpline);
        // `easing.bezierCurve` 从 JS 读回来是空的（grouped property 那口子不 round-trip），
        // 所以曲线走端口自己那条观察口。Qt 的 setBezierCurve 每段要六个值（c1 c2 + 收尾点），
        // 只给四个会静默丢弃并退化成线性（qqmlvaluetype.cpp:515，坑 134）
        const curve = bar.cubicBezier;
        verify(curve.length === 6, "easeInOutCubic 一条 bezier + Qt 要的收尾点 (1,1)");
        compare(curve[0], 0.645);
        compare(curve[1], 0.045);
        compare(curve[2], 0.355);
        compare(curve[3], 1.0);
        compare(curve[4], 1);
        compare(curve[5], 1);
        host.destroy()
    }

    function test_scrollCurveIsEaseInOutCubic() {
        // 曲线形状：easeInOutCubic 前段明显慢于线性（4t³，判别窗 [0.22,0.45] 里比 t 低
        // 0.09~0.19）；四值 bezierCurve 会被 Qt 静默丢弃、整条动画退化成线性 ⇒ 这条钉
        // 「曲线真的在驱动时钟」。闸按实测时刻归一化，wait 被负载拉长也不假红
        const host = stage("duration: 1200; visibilityHeight: -1")
        const bar = part(host, "bar")
        const view = part(host, "view")
        view.contentY = 800
        wait(40)
        const face = part(bar, "backTopFace");
        mouseClick(face, face.width / 2, face.height / 2);
        const t0 = Date.now();
        tryVerify(function () {
            const t = (Date.now() - t0) / 1200;
            if (t < 0.22 || t > 0.45)
                return false;
            const progress = 1 - view.contentY / 800;
            return progress < t - 0.05;
        }, 1500, "easeInOutCubic 前段要慢于线性（contentY=" + view.contentY + "）");
        host.destroy()
    }

    function test_hiddenFaceTakesNoClicks() {
        const host = stage("")
        const bar = part(host, "bar")
        const view = part(host, "view")
        bar.clicked.connect(function () { testCase.clicks.push(1); });
        const face = part(bar, "backTopFace");
        compare(bar.visible, false, "官方不可见时 render 返回 null");
        mouseClick(face, face.width / 2, face.height / 2);
        wait(60)
        compare(testCase.clicks.length, 0, "没浮出来就点不着");
        view.contentY = 900
        wait(60)
        compare(bar.visible, true);
        mouseClick(face, face.width / 2, face.height / 2);
        wait(60)
        compare(testCase.clicks.length, 1, "浮出来才算得着");
        host.destroy()
    }

    // ============================================================ 那颗按钮
    function test_defaultButtonIsLightChevronUp() {
        const host = stage("visibilityHeight: -1")
        const bar = part(host, "bar")
        const face = part(bar, "backTopFace")
        const btn = part(bar, "backTopDefault")
        near(face.width, 32, "icon-only 默认档 $width-button_iconOnly_default");
        near(face.height, 32);
        compare(btn.variant, Enums.Light, "官方 renderDefault 是 theme=light");
        compare(btn.icon, "chevron_up", "IconChevronUp");
        compare(part(bar, "backTopContent").active, false, "没给 children ⇒ 那只 Loader 不载入");
        compare(part(bar, "backTopHover").cursorShape, Qt.PointingHandCursor, "cursor: pointer");
        verify(face.clip, "overflow: hidden");
        host.destroy()
    }

    function test_contentReplacesTheDefaultButton() {
        const host = make("Item { width: 300; height: 200;"
            + " Flickable { id: view; objectName: 'view'; anchors.fill: parent; contentHeight: 2000;"
            + " boundsBehavior: Flickable.StopAtBounds }"
            + " Component { id: node; Rectangle { objectName: 'customNode'; width: 48; height: 20;"
            + " color: '#0077fa' } }"
            + " BackTop { objectName: 'bar'; target: view; visibilityHeight: -1; content: node } }")
        const bar = part(host, "bar")
        compare(bar.hasCustom, true);
        const face = part(bar, "backTopFace")
        near(face.width, 48, "外层 div 是 shrink-to-fit ⇒ 跟着 children 走");
        near(face.height, 20);
        verify(testCase.findChild(bar, "customNode") !== null, "官方 children 整颗替换默认那颗");
        compare(part(bar, "backTopDefault").visible, false);
        // 点击判在**外层 div** 上，不是判在按钮里 ⇒ 自定义节点也照样能点
        bar.clicked.connect(function () { testCase.clicks.push(1); });
        mouseClick(face, 2, 2);
        wait(60)
        compare(testCase.clicks.length, 1);
        host.destroy()
    }

    // ============================================================ fixed 的端口替身
    function test_positionFollowsParentAndMargins() {
        const host = stage("visibilityHeight: -1")
        const bar = part(host, "bar")
        near(bar.x, 300 - 32 - 100, "父项宽 - 自身宽 - 右 100");
        near(bar.y, 200 - 32 - 50, "父项高 - 自身高 - 底 50");
        bar.rightMargin = 20
        bar.bottomMargin = 20
        wait(40)
        near(bar.x, 300 - 32 - 20);
        near(bar.y, 200 - 32 - 20);
        host.destroy()
    }

    function test_deadPropsChangeNothing() {
        const host = stage("visibilityHeight: -1")
        const bar = part(host, "bar")
        const x0 = bar.x
        const y0 = bar.y
        const w0 = bar.width
        bar.className = "mine"
        bar.style = ({ bottom: 100, width: 30, backgroundColor: "#0077fa" })
        wait(60)
        compare(bar.x, x0, "style / className 收了不产出可见差异（全站口径）");
        compare(bar.y, y0);
        compare(bar.width, w0);
        compare(bar.hasCustom, false, "style 也不顶替 children 那一档");
        host.destroy()
    }
}
