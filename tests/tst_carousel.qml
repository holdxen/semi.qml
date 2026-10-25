import QtQuick
import QtTest
import Semi

// Carousel / CarouselIndicator / CarouselArrow。规格照
// packages/semi-ui/carousel/{index.tsx,CarouselIndicator.tsx,CarouselArrow.tsx,interface.ts} 与
// packages/semi-foundation/carousel/{foundation.ts,constants.ts,carousel.scss,variables.scss}，
// 演示与 API 表照 content/show/carousel/index.md。
//
// 端口口径（逐条在 src/Carousel.qml、src/CarouselIndicator.qml、src/CarouselArrow.qml 文件头）：
//   · 动画不是轨道平移：每片都叠在同一格，slide 档**两片同时动** —— 进片从 ±100% 滑入、
//     出片滑出到 ∓100%，动画结束出片才重新隐藏。早先「出片被 :not(-current) 的 visibility
//     挡住整段不可见」的口径是错的：每片都内联了 `transitionDuration`，而
//     `transition-property` 初值是 `all` ⇒ visibility 也在过渡，(0,1) 之间取 visible
//     （浏览器逐帧实测，见 src/Carousel.qml 文件头）。曲线是 CSS `ease` =
//     cubic-bezier(0.25, 0.1, 0.25, 1)。
//   · `autoPlay` 是 `true | false | { interval, hoverToPause }`，没有独立 interval prop；
//     间隔 = interval + speed；进出场各延迟 400ms（lodash debounce）。
//   · 给了 `activeIndex` 就是受控：只发 changed、不改内部状态，且挂载与鼠标离开那两处
//     不会起播（但 `next()` 走的是 foundation 那份没有门的 ⇒ 照样起，单独钉一条）。
//   · next/prev 会重启计时器，goTo 与指示器点击**不会**（官方就是没写）。
//   · 上游三处不抄：`getValidIndex` 只加一次长度（负得超过一圈会给出负数）、0 片时 NaN、
//     官方那三处 DOM-only 的键盘 / role 属性；端口规范化取模并兜 0，各钉一条。
//
// 两条量测纪律：
//   · QML 字符串里 `prop: { a: 1 }` 会被解析成「带标签的语句」，对象字面量必须写成
//     `prop: ({ a: 1 })`，否则 autoPlay 收到的是 undefined（这条会静默骗过断言）。
//   · Qt 6.11 的 Timer 没有 `elapsed` 可读，计时相位只能用 `triggered` 的到达时刻反推
//     ⇒ 下面两组时序断言都留了 ≥200ms 的余量。
TestCase {
    id: testCase

    name: "Carousel"
    when: windowShown
    width: 1000
    height: 800

    readonly property int defaultInterval: 2000
    readonly property int defaultSpeed: 300

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
        // 上一个用例残留的指针位置会悬停到下一个用例的同名格子上（颜色断言全是 .7）
        // ⇒ 每个用例开跑前把指针停到窗口右下角（所有实例都在左上角 ≤400×200）
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
    }

    // 断言失败会跳过用例末尾的 destroy ⇒ 残留实例会继续占版面
    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "carousel");
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

    function pages() {
        return make("Carousel { width: 300; height: 200; autoPlay: false\n"
                    + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                    + "Rectangle { objectName: 'p1'; color: 'green' }\n"
                    + "Rectangle { objectName: 'p2'; color: 'blue' } }");
    }

    function page(c, i) {
        return part(c, "p" + i);
    }

    function timer(c) {
        return part(c, "carouselPlayTimer");
    }

    function cell(c, i) {
        return part(c, "carouselIndicatorItem" + i);
    }

    function spy(target, signalName) {
        const s = Qt.createQmlObject("import QtTest; SignalSpy {}", testCase, "spy");
        s.target = target;
        s.signalName = signalName;
        return s;
    }

    readonly property Component squareComponent: Component {
        Rectangle {
            objectName: "customArrowNode"
            width: 24
            height: 24
            color: "black"
        }
    }

    // ---------------- 属性面与缺省 ----------------

    function test_officialPropDefaults() {
        const c = make("Carousel {}");
        verify(c.activeIndex === undefined, "官方没有 activeIndex 缺省 ⇒ 不给就是非受控");
        compare(c.animation, "slide", "index.tsx:45");
        verify(c.arrowProps === undefined);
        compare(c.autoPlay, true, "index.tsx:46");
        compare(c.arrowType, "always", "index.tsx:47");
        compare(c.className, "");
        compare(c.defaultActiveIndex, 0, "numbers.DEFAULT_ACTIVE_INDEX");
        compare(c.indicatorPosition, "center", "index.tsx:49");
        compare(c.indicatorSize, "small", "index.tsx:50");
        compare(c.indicatorType, "dot", "index.tsx:51");
        compare(c.theme, "light", "index.tsx:52");
        compare(c.showArrow, true, "index.tsx:54");
        compare(c.showIndicator, true, "index.tsx:55");
        compare(c.slideDirection, "left", "index.tsx:56");
        compare(c.speed, 300, "numbers.DEFAULT_SPEED");
        verify(c.style === undefined);
        compare(c.trigger, "click", "index.tsx:58");
        compare(c.shownIndex, 0);
        compare(c.controlled, false);
        compare(c.isInit, true, "CarouselState.isInit 初值 true");
        compare(c.innerIndex, 0);
        compare(c.preIndex, 0);
        compare(c.isReverse, false);
        compare(c.forcePlay, false);
        near(c.implicitWidth, 480, "端口给的缺省尺寸（官方靠 CSS，没有固有尺寸）");
        near(c.implicitHeight, 240);
        c.destroy();
    }

    function test_deadPropsChangeNothing() {
        const plain = pages();
        const styled = make("Carousel { width: 300; height: 200; autoPlay: false;"
                            + "className: 'x'; style: ({ border: '2px solid red' });"
                            + "arrowProps: ({ leftArrow: { props: { style: { color: 'red' } } } })\n"
                            + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                            + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        near(styled.implicitHeight, 240, "style / className 只喂 DOM，端口不产出差异");
        near(plain.height, 200);
        compare(part(styled, "carouselArrowPrevIcon").name, "chevron_left",
                "arrowProps 里那截 DOM props 不落地，图标仍是默认那个");
        plain.destroy();
        styled.destroy();
    }

    // ---------------- 索引与状态 ----------------

    function test_uncontrolledStartsAtDefaultActiveIndex() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; defaultActiveIndex: 2\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' }\n"
                       + "Rectangle { objectName: 'p2'; color: 'blue' } }");
        wait(60);
        compare(c.shownIndex, 2, "构造期取 defaultActiveIndex");
        compare(c.preIndex, 2, "官方 state.preIndex 初值与 activeIndex 同一个");
        near(c.progress, 1, "初值那一拍不算一次切换（bootedOnce 那时还没置真）");
        c.defaultActiveIndex = 0;
        wait(60);
        compare(c.shownIndex, 2, "defaultActiveIndex 是构造期快照，之后改它无效");
        c.destroy();
    }

    function test_nextPrevWrap() {
        const c = pages();
        wait(60);
        compare(c.shownIndex, 0);
        c.next();
        compare(c.shownIndex, 1);
        c.next();
        c.next();
        compare(c.shownIndex, 0, "过尾回绕");
        c.prev();
        compare(c.shownIndex, 2, "过头回绕");
        c.destroy();
    }

    function test_goToWraps() {
        const c = pages();
        wait(60);
        c.goTo(5);
        compare(c.shownIndex, 2, "5 % 3");
        compare(c.isReverse, false, "0 → 2 往后 ⇒ 假");
        c.goTo(-1);
        compare(c.shownIndex, 2, "官方 (-1 + 3) % 3 = 2");
        compare(c.isReverse, false, "目标就是当前那一片 ⇒ `>` 不成立（写成 `>=` 就错）");
        c.goTo(0);
        compare(c.shownIndex, 0);
        compare(c.isReverse, true, "2 → 0 往前 ⇒ 真（isReverse 就是这条 `>` 比较）");
        c.destroy();
    }

    function test_validIndexNormalizesFarNegative() {
        // 上游不抄的那条：官方 `(index + length) % length` 只加一次长度，
        // index = -7、length = 3 时给出 (-4 % 3) = -1 ⇒ 匹配不到任何一片
        const c = pages();
        wait(60);
        compare(c.validIndex(-7), 2, "端口规范化取模（官方这里会给出 -1）");
        compare(c.validIndex(10), 1);
        compare(c.validIndex("1"), 1, "字符串数字按 Number 转");
        compare(c.validIndex("abc"), 0, "转不出数就当没给（官方是 NaN % 3 = NaN ⇒ 谁都不匹配）");
        c.destroy();
    }

    function test_validIndexWithoutPages() {
        const c = make("Carousel { autoPlay: false }");
        wait(60);
        compare(c.count, 0);
        compare(c.validIndex(3), 0, "官方是 (3 + 0) % 0 = NaN ⇒ 端口兜 0");
        c.next();
        compare(c.shownIndex, 0, "0 片时 next 也不该把状态打成 NaN");
        c.destroy();
    }

    function test_outOfRangeInitialIndexShowsNothing() {
        // 官方 state.activeIndex 是**不校验**的原始值，渲染时按 `index === activeIndex` 比 ⇒
        // 越界的初值谁都不是 current，slide 档整块空白
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; defaultActiveIndex: 7\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        compare(c.shownIndex, 7, "初值原样存，不夹进 [0, count)");
        compare(page(c, 0).visible, false);
        compare(page(c, 1).visible, false);
        c.destroy();
    }

    function test_changedSignalArgumentsAndPreIndex() {
        const c = pages();
        wait(60);
        const s = spy(c, "changed");
        c.next();
        compare(s.count, 1);
        compare(s.signalArguments[0][0], 1, "onChange(activeIndex");
        compare(s.signalArguments[0][1], 0, "…preIndex)");
        compare(c.preIndex, 0, "preIndex 记的是切之前那一片");
        c.prev();
        compare(s.count, 2);
        compare(s.signalArguments[1][0], 0);
        compare(s.signalArguments[1][1], 1);
        c.destroy();
        s.destroy();
    }

    function test_sameIndexIsSilentButStillEndsInitPhase() {
        const c = pages();
        wait(60);
        const s = spy(c, "changed");
        c.goTo(0);
        compare(s.count, 0, "_notifyChange 里 `stateActiveIndex !== activeIndex` 才发");
        c.goTo(3);
        compare(s.count, 0, "3 % 3 = 0 ⇒ 绕回原地同样不发");
        compare(c.isInit, false,
                "但 setIsInit(false) 在那道比较**之前**（foundation.ts:96-98）⇒ 没切页也翻篇");
        c.destroy();
        s.destroy();
    }

    // ---------------- 受控档 ----------------

    function test_controlledOnlyNotifies() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; activeIndex: 0\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        const s = spy(c, "changed");
        compare(c.controlled, true);
        c.next();
        compare(s.count, 1, "受控档照发 onChange");
        compare(s.signalArguments[0][0], 1);
        compare(c.shownIndex, 0, "但内部状态不动，等使用方回写");
        compare(c.innerIndex, 0, "handleNewActiveIndex 被 controlled 挡掉");
        c.activeIndex = 1;
        wait(60);
        compare(c.shownIndex, 1, "回写之后才切过去（官方 getDerivedStateFromProps）");
        compare(s.count, 1, "由 prop 驱动的那次不再补发一遍 changed");
        c.goTo(2);
        wait(60);
        compare(s.count, 2, "goTo 在受控档也发 onChange（2 % 2 = 0）");
        compare(c.shownIndex, 1, "goTo 也不回写内部状态");
        c.handleIndicatorChange(0);
        wait(60);
        compare(s.count, 3, "指示器那条在受控档也照发 onChange");
        compare(c.shownIndex, 1, "但一样不回写内部状态");
        c.destroy();
        s.destroy();
    }

    function test_controlledDoesNotStartAutoPlay() {
        const c = make("Carousel { width: 300; height: 200; activeIndex: 0;"
                       + "autoPlay: ({ interval: 50, hoverToPause: true })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        compare(timer(c).running, false,
                "componentDidMount 走的是组件层那道 `!getIsControlledComponent()` 门");
        mouseMove(c, 10, 10);
        wait(500);
        mouseMove(c, c.width + 60, c.height + 60);
        wait(500);
        compare(timer(c).running, false, "鼠标离开那条重启也带同一道门（index.tsx:154）");
        c.destroy();
    }

    function test_controlledNextStillStartsTimer() {
        // 上游那道门只挂在组件层的 handleAutoPlay 上，而 foundation.next / prev 调的是
        // 自己那份没有门的（foundation.ts:65 / :79）⇒ 受控档手动切一次照样把计时起起来，
        // 之后每次触发只发 onChange、视图一动不动。官方就是这个行为，端口照抄并钉住。
        const c = make("Carousel { width: 300; height: 200; speed: 50; activeIndex: 0;"
                       + "autoPlay: ({ interval: 100 })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        const s = spy(c, "changed");
        compare(timer(c).running, false);
        c.next();
        compare(timer(c).running, true, "next 里的 handleAutoPlay 没有受控那道门");
        wait(400);
        compare(c.shownIndex, 0, "计时在跑，视图却切不动（受控）");
        verify(s.count >= 3,
               "间隔 150ms、等 400ms ⇒ 至少要重复触发两拍（Timer 不 repeat 就只有 1 拍）"
               + "（实得 " + s.count + " 次）");
        c.destroy();
        s.destroy();
    }

    function test_controlledFirstChangeDoesNotAnimate() {
        // 官方 slide-in 要 `!isInit`，而受控档由 prop 驱动时不走 _notifyChange ⇒ isInit 仍真
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; activeIndex: 0\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        c.activeIndex = 1;
        wait(20);
        compare(c.isInit, true, "受控首切不翻 isInit");
        near(c.progress, 1, "也就没有位移动画");
        near(page(c, 1).x, 0);
        c.next();                       // 走一次 notifyChange，isInit 翻假
        wait(20);
        compare(c.isInit, false);
        c.activeIndex = 0;
        wait(20);
        verify(c.progress < 0.5, "之后由 prop 驱动的切换才有动画（起步那一拍）");
        c.destroy();
    }

    function test_nullActiveIndexCountsAsControlled() {
        // 官方判据是「props 里有没有这个键」，与值无关 ⇒ null 算受控。
        // QML 分不出「键给了、值是 undefined」和「没给键」，端口只能按真值判（undefined 算没给）。
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; activeIndex: null\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        compare(c.controlled, true, "activeIndex: null 仍算给了");
        compare(c.shownIndex, 0, "null 经 numberOr 兜回 0，不会把视图打成谁都不是");
        c.next();
        wait(60);
        compare(c.shownIndex, 0, "受控 ⇒ 内部状态不动");
        c.destroy();
    }

    // ---------------- 切换动画 ----------------

    function test_slideShowsOnlyCurrent() {
        const c = pages();
        wait(60);
        compare(page(c, 0).visible, true, "-item-current");
        compare(page(c, 1).visible, false, "`> *:not(-item-current) { visibility: hidden }");
        compare(page(c, 2).visible, false);
        compare(page(c, 0).z, 1, "-item-current { z-index: 1 }");
        compare(page(c, 1).z, 0);
        near(page(c, 0).opacity, 1, "slide 档不靠透明度区分");
        c.destroy();
    }

    function test_slideInComesFromRight() {
        const c = pages();
        wait(60);
        c.next();
        wait(20);
        const p = page(c, 1);
        verify(p.visible, "进来的那片要画出来");
        verify(c.progress < 0.1, "动画才起步（实得 " + c.progress + "）");
        verify(p.x > 250, "slide-in 从 +100%（=300）起步 ⇒ 刚开始还在右边（实得 " + p.x + "）");
        wait(400);
        near(p.x, 0, "到位");
        near(c.progress, 1);
        c.destroy();
    }

    function test_slideInComesFromLeftWhenReversed() {
        const c = pages();
        wait(60);
        c.prev();
        tryVerify(function () { return c.progress > 0.2 && c.progress < 0.9; }, 1000);
        verify(page(c, 2).x < -25, "prev ⇒ isReverse ⇒ 从 -100% 滑进来（中段仍为负，实得 "
               + page(c, 2).x + "）");
        verify(page(c, 0).x > 0, "reverse 档出片向右滑出（slide-out-reverse 0→+100%，实得 "
               + page(c, 0).x + "）");
        tryVerify(function () { return c.progress >= 1; }, 1000);
        near(page(c, 2).x, 0);
        c.destroy();
    }

    function test_easeCurveMatchesCssEase() {
        // CSS 关键字 ease = cubic-bezier(0.25, 0.1, 0.25, 1)：官方给每片内联的
        // animationTimingFunction / transitionTimingFunction 都是它（index.tsx:189/191）。
        // Qt 的 setBezierCurve 每段要六个值（c1 c2 + 收尾点），只给四个会静默丢弃并退化
        // 成线性（qqmlvaluetype.cpp:515 `size() % 6 != 0` 直接 return）⇒ 末尾补 (1, 1)。
        // 曲线提成只读 easeCurve 是因为 grouped property 的 bezierCurve 从 JS 读回来是空的（坑 132）
        const c = pages();
        compare(c.easeCurve, [0.25, 0.1, 0.25, 1, 1, 1]);
        c.destroy();
    }

    function test_easeCurveDrivesTheClock() {
        // 曲线形状：ease 在 0.2~0.55·speed 这段明显跑在 InOutQuad 前面（浏览器实测
        // 0.275·speed 走完 46.8%，InOutQuad = 2t² 只有 15.1%，全段最小差 ~0.23）。
        // 闸写成「实测时刻的 quad 值 + 0.12」：wait 被机器负载拉长时按真实 elapsed 归一化，
        // 不假红（固定 wait(360) 在 -j4 变异扫描下会漂过判别窗，复跑过一次）
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; speed: 1200\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        const t0 = Date.now();
        c.next();
        tryVerify(function () {
            const t = (Date.now() - t0) / 1200;
            if (t < 0.2 || t > 0.55)
                return false;
            const quad = t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);
            return c.progress > quad + 0.12;
        }, 1500, "ease 要在判别窗内跑赢 InOutQuad + 0.12（实得 " + c.progress + "）");
        c.destroy();
    }

    function test_slideDirectionRightFlipsTheAxis() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; slideDirection: 'right'\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' }\n"
                       + "Rectangle { objectName: 'p2'; color: 'blue' } }");
        wait(60);
        // :286 `slideDirection === 'left' ? isReverse : !isReverse` ⇒ next（isReverse 假）取反为真
        c.next();
        wait(20);
        verify(page(c, 1).x < -250, "right 档下 next 变成从左边进来");
        wait(400);
        c.prev();
        wait(20);
        verify(page(c, 0).x > 250, "right 档下 prev 反过来从右边进来");
        c.destroy();
    }

    function test_outgoingPageSlidesOutThenHides() {
        // 官方每片都内联 transitionDuration + transition-property 初值 all ⇒ visibility 也在
        // 过渡，严格 (0,1) 之间取 visible ⇒ 出片整段可见并滑出，动画结束那一帧才 hidden
        //（浏览器逐帧实测：t=0.275·speed 时 outVis 仍是 visible、transform 已到 -46.8%）
        const c = pages();
        wait(60);
        c.next();
        // offscreen 下动画要几帧才起走（固定 wait 会读到 progress 仍为 0 的那一瞬）
        tryVerify(function () { return c.progress > 0.2 && c.progress < 0.9; }, 1000);
        const old = page(c, 0);
        verify(old.visible, "动画期间出片要画出来");
        verify(old.x < 0, "slide-out 向左滑出（实得 " + old.x + "）");
        tryVerify(function () { return c.progress >= 1; }, 1000);
        compare(old.visible, false, "动画结束出片重新隐藏");
        near(old.x, 0, "动画一结束出片回位（fill-mode 到头后它已经不可见）");
        c.destroy();
    }

    function test_slideMovesBothPagesSymmetrically() {
        // 进片 (1-p)·w、出片 -p·w ⇒ 两片的间距恒等于宽（浏览器实测 inRectX - outRectX 恒 400）
        const c = pages();
        wait(60);
        c.next();
        tryVerify(function () { return c.progress > 0.2 && c.progress < 0.9; }, 1000);
        near(page(c, 1).x - page(c, 0).x, 300, "中段两片间距 = 宽（同速对称）");
        c.destroy();
    }

    function test_firstMountHasNoAnimation() {
        const c = pages();
        wait(60);
        compare(c.isInit, true);
        near(c.progress, 1, "首屏不挂 slide-in（官方 !isInit 那道门）");
        near(page(c, 0).x, 0);
        c.destroy();
    }

    function test_fadeInitialIndexDoesNotAnimateOnMount() {
        // 这道 `bootedOnce` 门只有 fade 档测得出来：slide 档另有「!isInit」那条挡着，
        // 两条门叠在一起时摘掉任何一条都还有另一条守着 ⇒ 必须单独来一发 fade 的挂载档。
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; animation: 'fade';"
                       + " defaultActiveIndex: 2\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' }\n"
                       + "Rectangle { objectName: 'p2'; color: 'blue' } }");
        wait(60);
        near(c.progress, 1, "初值那一拍不是一次切换 ⇒ 不该有淡入淡出");
        near(page(c, 2).opacity, 1, "第二片直接到位");
        near(page(c, 0).opacity, 0);
        c.destroy();
    }

    function test_fadeCrossesBothPages() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; animation: 'fade'\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' }\n"
                       + "Rectangle { objectName: 'p2'; color: 'blue' } }");
        wait(60);
        near(page(c, 0).opacity, 1);
        near(page(c, 1).opacity, 0);
        near(page(c, 2).opacity, 0);
        compare(page(c, 1).visible, true, "fade 档不隐藏任何东西（`> * { opacity: 0 }`）");
        c.next();
        wait(16);
        verify(page(c, 1).opacity < 0.2,
               "先要量到「还没到位」—— 只对终态成立的断言抓不住瞬间跳（实得 "
               + page(c, 1).opacity + "）");
        wait(104);
        verify(page(c, 1).opacity > 0.15, "进来的那片在淡入（实得 " + page(c, 1).opacity + "）");
        verify(page(c, 0).opacity < 0.85, "出去的那片同时在淡出（交叉，不是瞬间）");
        near(page(c, 0).opacity + page(c, 1).opacity, 1, "两条腿同步");
        verify(page(c, 2).opacity < 0.01, "第三片与这次切换无关");
        wait(400);
        near(page(c, 1).opacity, 1, "跑完落在终态");
        near(page(c, 0).opacity, 0);
        c.destroy();
    }

    function test_fadeAnimatesEvenOnFirstChange() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: false; animation: 'fade'\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        c.next();
        wait(16);
        verify(page(c, 1).opacity < 0.2, "起步那一拍还没淡进来");
        wait(104);
        verify(page(c, 1).opacity > 0.15,
               "fade 靠内联 transition 而不是关键帧 ⇒ 不受 isInit 那道门影响");
        near(page(c, 1).x, 0, "fade 档不位移");
        c.destroy();
    }

    function test_fadeControlledFirstChangeStillAnimates() {
        // 那道 `!isInit` 的门只挂在 slide 那条关键帧上；fade 靠内联 transition ⇒ 受控首切也淡入
        const c = make("Carousel { width: 300; height: 200; animation: 'fade'; activeIndex: 0;\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        compare(c.isInit, true);
        c.activeIndex = 1;
        wait(16);
        verify(page(c, 1).opacity < 0.2, "起步那一拍还没淡进来");
        wait(104);
        verify(page(c, 1).opacity > 0.15,
               "fade 不看 isInit（把门写成「不分 animation」就没了这一拍）");
        verify(page(c, 0).opacity < 0.85, "出去那片同时在淡出");
        c.destroy();
    }

    function test_switchingAnimationReevaluates() {
        const c = pages();
        wait(60);
        compare(page(c, 1).visible, false);
        c.animation = "fade";
        wait(60);
        compare(page(c, 1).visible, true, "换到 fade 档 ⇒ 不再隐藏非当前片");
        near(page(c, 1).opacity, 0);
        near(page(c, 1).x, 0, "fade 档那一片回到叠放原点");
        c.animation = "slide";
        wait(60);
        compare(page(c, 1).visible, false, "换回来又只留当前片");
        c.destroy();
    }

    function test_pagesAreForcedToViewportSize() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: false\n"
                       + "Rectangle { objectName: 'p0'; color: 'red'; width: 10; height: 10 } }");
        wait(60);
        near(page(c, 0).width, 300, "`-item { width:100%; height:100% }` 盖掉子项自己的尺寸");
        near(page(c, 0).height, 200);
        compare(part(c, "carouselViewport").clip, true, "-content { overflow: hidden }");
        c.destroy();
    }

    function test_pagesFollowViewportResize() {
        // 坑 14 那一族：派生几何里读「另一个对象的 width」会不会跟着重算。
        // 端口每片的 x / 宽高都是即时求值的函数，这一条就是那条门。
        const c = pages();
        wait(60);
        c.width = 500;
        c.height = 300;
        wait(80);
        near(page(c, 0).width, 500, "视口变宽 ⇒ 子项宽跟着变");
        near(page(c, 0).height, 300);
        c.next();
        wait(400);
        near(page(c, 1).x, 0, "切完停在新的原点");
        c.next();
        wait(20);
        verify(page(c, 2).x > 450,
               "±100% 位移吃的是变化后的视口宽（还按 300 算就到这里了：实得 " + page(c, 2).x + "）");
        c.destroy();
    }

    // ---------------- 自动播放 ----------------

    function test_switchingTimeThreeShapes() {
        const c = pages();
        wait(60);
        c.autoPlay = true;
        compare(c.autoPlayObject, false, "布尔档不算对象");
        near(c.switchingTime, testCase.defaultInterval + testCase.defaultSpeed,
             "布尔 true 档 = DEFAULT_INTERVAL + speed");
        c.autoPlay = { interval: 500 };
        compare(c.autoPlayObject, true);
        near(c.switchingTime, 500 + testCase.defaultSpeed, "对象档取 autoPlay.interval");
        c.autoPlay = {};
        near(c.switchingTime, testCase.defaultInterval + testCase.defaultSpeed,
             "对象没给 interval ⇒ get(…, 'interval', 2000)");
        c.autoPlay = false;
        compare(c.autoPlayObject, false);
        near(c.switchingTime, testCase.defaultInterval + testCase.defaultSpeed,
             "上游 typeof autoPlay === 'boolean' 先判 ⇒ false 也算布尔档 2300（只是门是关的）");
        c.autoPlay = null;
        compare(c.autoPlayObject, false, "lodash isObject(null) 是假 ⇒ null 不算对象档");
        near(c.switchingTime, testCase.defaultSpeed, "null 只剩 speed");
        c.autoPlay = undefined;
        compare(c.autoPlayObject, false);
        near(c.switchingTime, testCase.defaultSpeed, "既不是布尔也不是对象 ⇒ 只剩 speed");
        c.speed = 100;
        near(c.switchingTime, 100);
        c.destroy();
    }

    function test_playTimerIntervalStaysLive() {
        // 端口把 Timer.interval 绑在 switchingTime 上（官方每次 play 重算再传给 setInterval）
        const c = pages();
        wait(60);
        near(timer(c).interval, testCase.defaultInterval + testCase.defaultSpeed);
        c.autoPlay = { interval: 500 };
        wait(60);
        near(timer(c).interval, 800, "改 autoPlay ⇒ 间隔跟着变");
        c.speed = 100;
        wait(60);
        near(timer(c).interval, 600, "改 speed 也跟着变（间隔含过渡时长）");
        c.destroy();
    }

    function test_autoPlayAdvancesByItself() {
        const c = make("Carousel { width: 300; height: 200; speed: 50; autoPlay: ({ interval: 60 })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' }\n"
                       + "Rectangle { objectName: 'p2'; color: 'blue' } }");
        wait(60);
        compare(timer(c).running, true);
        near(timer(c).interval, 60 + 50, "间隔 = interval + speed");
        wait(160);
        verify(c.shownIndex > 0, "自己往前走过了（停在 " + c.shownIndex + "）");
        c.destroy();
    }

    function test_autoPlayFalseStopsTimer() {
        const c = pages();
        wait(60);
        compare(c.autoPlay, false);
        compare(timer(c).running, false);
        c.destroy();
    }

    function test_changingAutoPlayAloneDoesNotStartTimer() {
        // 官方起播只有五个入口：挂载 / next / prev / 鼠标离开 / play()。改 prop 不补起。
        const c = pages();
        wait(60);
        compare(timer(c).running, false);
        c.autoPlay = { interval: 100 };
        wait(60);
        compare(timer(c).running, false, "改 autoPlay 不会自己把计时起起来");
        c.next();
        wait(60);
        compare(timer(c).running, true, "next 那一拍才起");
        c.autoPlay = null;
        c.next();
        wait(60);
        compare(timer(c).running, false,
                "门是「autoPlay === true 或 isObject 或 forcePlay」⇒ null / 0 / undefined 都进不来"
                + "（写成 `autoPlay !== false` 就开了）");
        c.destroy();
    }

    function test_nextAndPrevStopWhenAutoPlayTurnedOff() {
        // next / prev 第一件事是 stop()，然后才按门重启；门关着就停在那儿了。
        const c = make("Carousel { width: 300; height: 200; autoPlay: ({ interval: 3000 })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' }\n"
                       + "Rectangle { objectName: 'p2'; color: 'blue' } }");
        wait(60);
        compare(timer(c).running, true);
        c.autoPlay = false;                     // 官方不看真值变化，计时照旧在跑
        compare(timer(c).running, true, "改 autoPlay 也不停（上面那条的镜像）");
        c.next();
        compare(timer(c).running, false, "next 里先 stop，重启那道门此刻是关的");
        c.autoPlay = { interval: 3000 };
        c.prev();
        compare(timer(c).running, true, "prev 同理，门开着就重启");
        c.autoPlay = false;
        c.prev();
        compare(timer(c).running, false);
        c.destroy();
    }

    function test_switchingTimeIgnoresNonNumericInterval() {
        // 官方 `get(autoPlay, 'interval', 2000)` 只兜 undefined：给它字符串会直接
        // `"abc" + 300` 拼成字符串交给 setInterval（等价于 1ms 不停切页）。端口收数。
        const c = pages();
        wait(60);
        c.autoPlay = { interval: "abc" };
        near(c.switchingTime, testCase.defaultInterval + testCase.defaultSpeed,
             "非数字 interval ⇒ 回落 2000（官方会拼成字符串）");
        c.autoPlay = { interval: 700 };
        near(c.switchingTime, 1000);
        c.destroy();
    }

    function test_singlePageNeverPlays() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: ({ interval: 50 })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' } }");
        wait(60);
        compare(c.hasPages, false);
        compare(timer(c).running, false, "foundation:132 只有 children > 1 才起播");
        c.play();
        compare(timer(c).running, false, "play() 也过不了 children > 1 那道门");
        c.destroy();
    }

    function test_playAndStopMethods() {
        const c = pages();
        wait(60);
        compare(timer(c).running, false);
        c.play();
        compare(c.forcePlay, true, "CarouselMethod.play 先 setForcePlay(true)");
        compare(timer(c).running, true, "autoPlay=false 也照样播");
        near(timer(c).interval, testCase.defaultInterval + testCase.defaultSpeed,
             "间隔仍走 getSwitchingTime（false 也算布尔档）");
        c.stop();
        compare(c.forcePlay, false, "组件的 stop 会清 forcePlay（foundation 自己的 stop 不会）");
        compare(timer(c).running, false);
        c.destroy();
    }

    function test_nextRestartsPlayTimer() {
        const c = make("Carousel { width: 300; height: 200; speed: 50;"
                       + "autoPlay: ({ interval: 550 })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' }\n"
                       + "Rectangle { objectName: 'p2'; color: 'blue' } }");
        const s = spy(timer(c), "triggered");
        wait(500);
        compare(s.count, 0, "600ms 的间隔，前 500ms 不该触发");
        c.next();
        wait(400);
        compare(s.count, 0, "next 里 stop + handleAutoPlay ⇒ 相位归零（不归零这 400ms 里就该落一拍）");
        wait(400);
        compare(s.count, 1, "归零后的那一拍在 1100ms 到达");
        c.destroy();
        s.destroy();
    }

    function test_goToAndIndicatorDoNotRestartPlayTimer() {
        const c = make("Carousel { width: 300; height: 200; speed: 50;"
                       + "autoPlay: ({ interval: 550 })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' }\n"
                       + "Rectangle { objectName: 'p2'; color: 'blue' } }");
        const s = spy(timer(c), "triggered");
        wait(500);
        c.goTo(2);
        wait(300);
        compare(s.count, 1, "goTo 不重启计时器 ⇒ 600ms 那一拍照旧落（重启的话要等到 1100ms）");
        compare(c.shownIndex, 0, "600ms 那拍是 next ⇒ 2 又绕回 0");
        c.handleIndicatorChange(2);
        wait(150);
        c.handleIndicatorChange(0);
        wait(350);
        compare(s.count, 2, "指示器那条同样不重启（1200ms 那一拍照旧落）");
        c.destroy();
        s.destroy();
    }

    function test_hoverPauseIsDebounced() {
        const c = make("Carousel { width: 300; height: 200; speed: 50;"
                       + "autoPlay: ({ interval: 3000, hoverToPause: true })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        const t = timer(c);
        compare(t.running, true);
        mouseMove(c, 10, 10);
        wait(200);
        compare(t.running, true, "官方 debounce 400ms ⇒ 前两拍还不该停");
        wait(300);
        compare(t.running, false, "过了 400ms 才停");
        mouseMove(c, c.width + 60, c.height + 60);
        wait(200);
        compare(t.running, false, "离开也要等 400ms");
        wait(300);
        compare(t.running, true, "然后自动续播");
        c.destroy();
    }

    function test_hoverToPauseFalseDoesNotPause() {
        const c = make("Carousel { width: 300; height: 200; speed: 50;"
                       + "autoPlay: ({ interval: 3000, hoverToPause: false })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        compare(c.hoverToPauseOn, false);
        mouseMove(c, 10, 10);
        wait(500);
        compare(timer(c).running, true, "对象档没开 hoverToPause ⇒ 不暂停");
        c.destroy();
    }

    function test_autoPlayObjectWithoutHoverToPauseDoesNotPause() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: ({ interval: 3000 })\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        compare(c.hoverToPauseOn, false, "`{interval}` 里 hoverToPause 是 undefined ⇒ 假");
        // 「划过不暂停」那一半由 test_hoverToPauseFalseDoesNotPause 守着，这里只测独一条：
        // 对象档没开 hoverToPause ⇒ 离开那条也不许重启计时
        mouseMove(c, 10, 10);
        wait(500);
        compare(timer(c).running, true);
        c.stop();
        wait(60);
        compare(timer(c).running, false);
        mouseMove(c, c.width + 60, c.height + 60);
        wait(500);
        compare(timer(c).running, false,
                "离开那条的判据是 `typeof autoPlay !== 'object' || hoverToPause` ⇒ 对象档没开就不重启");
        c.destroy();
    }

    function test_autoPlayTruePausesOnHover() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: true\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        compare(c.hoverToPauseOn, true, "布尔档 hoverToPause 恒真");
        mouseMove(c, 10, 10);
        wait(500);
        compare(timer(c).running, false, "autoPlay===true 那条也停");
        c.destroy();
    }

    function test_autoPlayFalseLeaveDoesNotResume() {
        const c = pages();
        wait(60);
        c.play();
        wait(60);
        compare(timer(c).running, true);
        mouseMove(c, 10, 10);
        wait(500);
        compare(timer(c).running, true,
                "handleMouseEnter 的条件是 `autoPlay===true || (对象且 hoverToPause)` ⇒ 不停");
        c.stop();
        wait(60);
        compare(timer(c).running, false);
        mouseMove(c, c.width + 60, c.height + 60);
        wait(500);
        compare(timer(c).running, false,
                "stop() 清了 forcePlay ⇒ 离开那条重启进不来");
        c.destroy();
    }

    function test_progressAnimDurationFollowsSpeed() {
        const c = pages();
        wait(60);
        compare(part(c, "carouselProgressAnim").duration, 300, "过渡时长吃 speed");
        c.speed = 800;
        wait(60);
        compare(part(c, "carouselProgressAnim").duration, 800);
        c.destroy();
    }

    // ---------------- 指示器 ----------------

    function test_indicatorVisibilityGates() {
        const one = make("Carousel { width: 300; height: 200; autoPlay: false\n"
                         + "Rectangle { objectName: 'p0'; color: 'red' } }");
        wait(60);
        compare(part(one, "carouselIndicator").visible, false,
                "renderIndicator 要 children.length > 1");
        const off = make("Carousel { width: 300; height: 200; autoPlay: false; showIndicator: false\n"
                         + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                         + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        compare(part(off, "carouselIndicator").visible, false);
        compare(part(off, "carouselIndicator").z, 2, "-indicator { z-index: 2 }");
        one.destroy();
        off.destroy();
    }

    function test_indicatorDotGeometry() {
        const c = pages();
        wait(60);
        const ind = part(c, "carouselIndicator");
        compare(ind.total, 3);
        near(ind.itemWidth, 8, "dot small = 8");
        near(ind.gap, 8, "$spacing-carousel_indicator_dot-marginX");
        near(ind.implicitWidth, 3 * 8 + 2 * 8);
        near(ind.implicitHeight, 8, "点状行高 = 点径");
        near(cell(c, 1).x, 16, "8 + 8");
        near(cell(c, 1).radius, 4, "border-radius: 50%");
        near(cell(c, 1).height, 8);
        compare(ind.itemNodes.length, 3, "格子名单只数真格子（Repeater 那层空壳不占一格）");
        compare(testCase.findChild(ind, "carouselIndicatorItem3"), null,
                "只按 total 建格子，不多建");
        near(ind.height, 8, "点状档整块的高就是行高");
        c.indicatorSize = "medium";
        wait(60);
        near(ind.itemWidth, 12, "dot medium = 12");
        near(ind.implicitWidth, 3 * 12 + 2 * 8);
        near(cell(c, 1).radius, 6);
        c.destroy();
    }

    function test_indicatorColumnarActiveHeightAndBottomAlign() {
        const c = pages();
        wait(60);
        c.indicatorType = "columnar";
        wait(60);
        const ind = part(c, "carouselIndicator");
        near(ind.itemWidth, 4, "columnar small 宽 4");
        near(ind.rowHeight, 20, "行高取选中态那条 20");
        near(cell(c, 0).height, 20, "当前那格 12 → 20");
        near(cell(c, 1).height, 12);
        near(cell(c, 1).y, 8, "align-items: flex-end ⇒ 底对齐、往上长");
        near(cell(c, 0).y, 0);
        near(ind.gap, 4, "$spacing-carousel_indicator_columnar-marginX");
        near(cell(c, 1).radius, 0, "只有 dot 档有圆角");
        near(cell(c, 1).width, ind.itemWidth, "格宽跟着类型走，不是恒 8");
        near(ind.height, 20, "整块高 = 行高（选中态那条），不是点径");
        c.indicatorSize = "medium";
        wait(60);
        near(ind.itemWidth, 6);
        near(cell(c, 1).height, 20, "medium 默认 20");
        near(cell(c, 0).height, 28, "medium 选中 28");
        near(ind.rowHeight, 28);
        c.destroy();
    }

    function test_indicatorLineWidthIsFixedContainer() {
        const c = pages();
        wait(60);
        c.indicatorType = "line";
        wait(60);
        const ind = part(c, "carouselIndicator");
        near(ind.lineTotalWidth, 240, "$width-carousel_indicator_line 写死 240");
        near(ind.itemWidth, (240 - 4 * 2) / 3, "每格 flex:1 ⇒ (240 − 间距) / 条数");
        near(ind.implicitWidth, 240);
        near(ind.rowHeight, 4, "line small 高 4");
        near(cell(c, 1).height, 4, "格子自己的高也是 4（不是 rowHeight 属性对就行）");
        near(ind.height, 4, "整块高跟着 line 档走，不是点径 8");
        near(cell(c, 1).width, ind.itemWidth, "格宽 = (240 − 间距) / 条数，不是点径");
        near(cell(c, 2).x, 2 * (ind.itemWidth + 4), "line 档也按等宽 + 4 间距摆");
        c.indicatorSize = "medium";
        wait(60);
        near(ind.rowHeight, 6, "line medium 高 6");
        c.destroy();
    }

    function test_indicatorPositions() {
        const c = pages();
        wait(60);
        c.width = 400;
        c.height = 200;
        wait(60);
        const ind = part(c, "carouselIndicator");
        near(ind.y, 200 - 32 - ind.height, "bottom: $spacing-carousel_indicator-padding(32)");
        near(ind.x, (400 - ind.width) / 2, "center ⇒ left:50% + translate(-50%)");
        c.indicatorPosition = "left";
        wait(60);
        near(ind.x, 32);
        c.indicatorPosition = "right";
        wait(60);
        near(ind.x, 400 - 32 - ind.width);
        c.destroy();
    }

    function test_indicatorThemeColors() {
        const c = pages();
        wait(60);
        const active = cell(c, 0);
        const other = cell(c, 1);
        compare(active.color, Qt.rgba(1, 1, 1, 1), "light 主题选中 = 白 1");
        compare(other.color, Qt.rgba(1, 1, 1, 0.4), "light 默认 = 白 .4");
        c.theme = "dark";
        wait(60);
        compare(other.color, Qt.rgba(0, 0, 0, 0.5), "dark 默认 = 黑 .5");
        c.theme = "primary";
        wait(60);
        const blue = Theme.current.blue[6];
        compare(other.color, Qt.rgba(blue.r, blue.g, blue.b, 0.4),
                "primary 用 --semi-blue-6，不是语义主色");
        compare(active.color, Qt.rgba(blue.r, blue.g, blue.b, 1));
        c.destroy();
    }

    function test_primaryThemeReadsBlueSixNotSemanticPrimary() {
        // 默认主题下 blue[6] 与 colorPrimary 同值 ⇒ 先把语义主色改掉，才分得出指示器与箭头
        // 读的到底是官方那个 --semi-blue-6，还是我们的主色令牌（同值令牌会骗过断言）。
        Theme.customize({ colorPrimary: "#7c3aed" });
        const c = pages();
        wait(60);
        const blue = Theme.current.blue[6];
        verify(blue.toString() !== Theme.current.colorPrimary.toString(),
               "两个令牌此刻必须不同值，否则这条断言是空的");
        c.theme = "primary";
        wait(60);
        compare(cell(c, 1).color, Qt.rgba(blue.r, blue.g, blue.b, 0.4),
                "指示器 primary 档 = blue[6] 的 .4");
        compare(cell(c, 0).color, Qt.rgba(blue.r, blue.g, blue.b, 1), "选中仍是 blue[6] 满不透明");
        const arrowIcon = part(c, "carouselArrowPrevIcon");
        compare(arrowIcon.color, Qt.rgba(blue.r, blue.g, blue.b, 1),
                "箭头同一套令牌（基色不透明，alpha 在 opacity）");
        near(arrowIcon.opacity, 0.4, "箭头非悬浮 .4");
        c.destroy();
    }

    function test_indicatorHoverOrder() {
        const c = pages();
        wait(60);
        const other = cell(c, 1);
        mouseMove(other, other.width / 2, other.height / 2);
        wait(60);
        compare(other.color, Qt.rgba(1, 1, 1, 0.7), "light 悬浮 = 白 .7");
        compare(c.shownIndex, 0, "trigger 是 click ⇒ 划过不该切页");
        const current = cell(c, 0);
        mouseMove(current, current.width / 2, current.height / 2);
        wait(60);
        compare(current.color, Qt.rgba(1, 1, 1, 0.7),
                "官方 :hover 那条排在 -active 之后、权重相同 ⇒ 划过当前那格反而掉回 .7");
        c.theme = "dark";
        wait(60);
        compare(current.color, Qt.rgba(0, 0, 0, 0.7), "dark 悬浮 .7");
        mousePress(current, current.width / 2, current.height / 2);
        wait(60);
        compare(current.color, Qt.rgba(0, 0, 0, 1),
                "按下那一拍又盖回 1（`:active` 排在 `:hover` 之后，且没有 .7 这一档）");
        mouseRelease(current, current.width / 2, current.height / 2);
        wait(60);
        c.destroy();
    }

    function test_indicatorTriggerGatesBothSignals() {
        const c = pages();
        wait(60);
        const ind = part(c, "carouselIndicator");
        const clicked = spy(ind, "indicatorChanged");
        const entered = spy(ind, "indicatorEntered");
        const target = cell(c, 1);
        mouseMove(target, target.width / 2, target.height / 2);
        wait(60);
        mouseClick(target, target.width / 2, target.height / 2);
        wait(60);
        compare(entered.count, 0, "trigger=click ⇒ onMouseEnter 那条不认（tsx:34-40）");
        compare(clicked.count, 1, "click 那条认");
        compare(c.shownIndex, 1);

        c.trigger = "hover";
        wait(60);
        const other = cell(c, 2);
        mouseMove(other, other.width / 2, other.height / 2);
        wait(60);
        mouseClick(other, other.width / 2, other.height / 2);
        wait(60);
        compare(entered.count, 1, "trigger=hover ⇒ 换认 onMouseEnter");
        compare(clicked.count, 1, "click 那条不再认（没有第二条）");
        compare(c.shownIndex, 2);
        c.destroy();
        clicked.destroy();
        entered.destroy();
    }

    function test_indicatorClickDrivesState() {
        const c = pages();
        wait(60);
        const s = spy(c, "changed");
        mouseClick(cell(c, 2), 4, 4);
        wait(80);
        compare(c.shownIndex, 2, "点第三格切过去");
        compare(c.isReverse, false, "0 → 2 是往后 ⇒ isReverse 假");
        mouseClick(cell(c, 0), 4, 4);
        wait(80);
        compare(c.shownIndex, 0);
        compare(c.isReverse, true, "2 → 0 是往前 ⇒ isReverse 真");
        mouseClick(cell(c, 0), 4, 4);
        wait(80);
        compare(c.isReverse, false, "点已经选中的那格 ⇒ 目标等于当前 ⇒ `>` 不成立");
        compare(s.count, 2, "两次真切换各发一条 changed（第三点在同一格 ⇒ 不发）");
        c.destroy();
        s.destroy();
    }

    // ---------------- 箭头 ----------------

    function test_arrowGatesAndGeometry() {
        const one = make("Carousel { width: 300; height: 200; autoPlay: false\n"
                         + "Rectangle { objectName: 'p0'; color: 'red' } }");
        wait(60);
        compare(part(one, "carouselArrow").visible, false, "renderArrow 也要 children > 1");
        one.destroy();
        const off = make("Carousel { width: 300; height: 200; autoPlay: false; showArrow: false\n"
                         + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                         + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        compare(part(off, "carouselArrow").visible, false);
        off.destroy();

        const c = pages();
        wait(60);
        c.width = 400;
        c.height = 200;
        wait(60);
        const prev = part(c, "carouselArrowPrev");
        const next = part(c, "carouselArrowNext");
        near(prev.x, 20, "$spacing-carousel_arrow-left");
        near(next.x, 400 - 20 - next.width, "$spacing-carousel_arrow-right");
        near(prev.y, (200 - prev.height) / 2, "top:50% + translateY(-50%)");
        near(part(prev, "carouselArrowPrevIcon").size, 32, "$width-carousel_arrow 兼 font-size");
        compare(part(prev, "carouselArrowPrevIcon").visible, true, "没给自定义节点就画默认图标");
        compare(part(c, "carouselArrow").z, 2, "-arrow-prev/-next { z-index: 2 }");
        compare(part(prev, "carouselArrowPrevIcon").name, "chevron_left", "IconChevronLeft");
        compare(part(next, "carouselArrowNextIcon").name, "chevron_right", "IconChevronRight");
        compare(part(prev, "carouselArrowPrevIcon").Accessible.name, "Previous index");
        compare(part(next, "carouselArrowNextIcon").Accessible.name, "Next index");
        compare(part(c, "carouselArrowPrevHover").cursorShape, Qt.PointingHandCursor,
                "-arrow { cursor: pointer }");
        c.destroy();
    }

    function test_arrowHoverTypeRevealsWithCarousel() {
        const c = pages();
        wait(60);
        const prev = part(c, "carouselArrowPrev");
        near(prev.opacity, 1, "always 档恒显");
        c.arrowType = "hover";
        wait(60);
        near(prev.opacity, 0, "-arrow-hover div { opacity: 0 }");
        mouseMove(c, 10, 10);
        wait(80);
        near(prev.opacity, 1, "悬浮整块轮播才显形（`:hover .-arrow-hover div`）");
        mouseMove(c, c.width + 60, c.height + 60);
        wait(80);
        near(prev.opacity, 0);
        c.arrowType = "always";
        wait(60);
        near(prev.opacity, 1, "切回 always 立刻恒显");
        c.destroy();
    }

    function test_arrowColorsAndHover() {
        // 官方把 rgba 色写在 `color` 上、图标 fill=currentColor 跟着走 ⇒ 非悬浮档是
        // **半透明**合成。Icon 走 MultiEffect colorization，着色器只改 RGB、输出 alpha 恒
        // 等于源 alpha（multieffect.frag:84）⇒ alpha 塞进 color 会被画成实心（坑 135）
        // ⇒ 端口 color 给不透明基色、透明度走 Icon.opacity
        const c = pages();
        wait(60);
        const icon = part(c, "carouselArrowPrevIcon");
        compare(icon.color, Qt.rgba(1, 1, 1, 1), "light 基色是不透明白（alpha 在 opacity）");
        near(icon.opacity, 0.4, "light 箭头默认 .4");
        mouseMove(icon, icon.width / 2, icon.height / 2);
        wait(60);
        compare(icon.color, Qt.rgba(1, 1, 1, 1), "悬浮不换色");
        near(icon.opacity, 1, "悬浮箭头自己 → 1（没有 .7 那一档）");
        c.theme = "dark";
        wait(60);
        near(icon.opacity, 1, "dark 悬浮仍是 1");
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
        wait(60);
        compare(icon.color, Qt.rgba(0, 0, 0, 1), "dark 基色是不透明黑");
        near(icon.opacity, 0.5, "dark 默认 .5");
        c.theme = "primary";
        wait(60);
        const blue = Theme.current.blue[6];
        compare(icon.color, Qt.rgba(blue.r, blue.g, blue.b, 1), "primary 也取 --semi-blue-6（不透明）");
        near(icon.opacity, 0.4, "primary 默认 .4");
        c.destroy();
    }

    // pixel() 返回 "#rrggbb" 字符串（不是整数，位移解码得 0 —— 上一版的「grabImage 不画 SVG」
    // 就是这么误判的，见坑 137）；grabImage 会把窗口底色合成进透明区 ⇒ 按 RGB 采样、白底夹具。
    function test_arrowIconCompositesTranslucent() {
        // light 主题箭头 = 不透明白 × opacity 0.4 ⇒ 白 40% 叠红 = (255,102,102)；
        // 实心白会是 (255,255,255)（坑 135 的 gallery 实锤是实心 (127,127,127)）
        const c = make("Carousel { width: 300; height: 200; autoPlay: false\n"
                       + "Rectangle { objectName: 'p0'; color: '#ff0000' }\n"
                       + "Rectangle { objectName: 'p1'; color: '#00ff00' } }");
        wait(120);
        const img = testCase.grabImage(c);
        // 左箭头图标盒 (20..52, 84..116)，"<" 笔画取样扫描左半；取区域里 g 最高的点
        // （AA 边缘的 g 偏低，最高点才是满覆盖的笔画本体）
        let strokeG = 0;
        for (let y = 92; y <= 108; ++y) {
            for (let x = 24; x <= 44; ++x) {
                const col = Qt.color(img.pixel(x * Screen.devicePixelRatio,
                    y * Screen.devicePixelRatio));
                if (col.r > 0.9 && col.g > strokeG)
                    strokeG = col.g;
            }
        }
        verify(strokeG > 0.1, "箭头笔画要抓得到（grabImage 画得出 SVG），实得 g=" + strokeG);
        // offscreen 单绘 g≈0.4；cocoa 的 grab 通道里 MultiEffect 的 hideSource 不生效 ⇒
        // 源（白 svg）与 colorization 双绘，g = 1−(1−0.4)² ≈ 0.64（真机 gallery 截图仍是单绘，
        // 只有 grab 失真）。两档都算对，实心白（1.0）仍然判红。
        verify(Math.abs(strokeG - 0.4) <= 0.12 || Math.abs(strokeG - 0.64) <= 0.08,
            "白 40% 叠红 g≈0.4（offscreen）或 0.64（cocoa grab 双绘），实得 " + strokeG);
        c.destroy();
    }

    function test_arrowClicksDrivePrevNext() {
        const c = pages();
        wait(60);
        const prev = part(c, "carouselArrowPrev");
        const next = part(c, "carouselArrowNext");
        mouseClick(next, next.width / 2, next.height / 2);
        wait(80);
        compare(c.shownIndex, 1, "点右箭头 = next");
        compare(c.isReverse, false, "next 里 isReverse 置假");
        mouseClick(prev, prev.width / 2, prev.height / 2);
        wait(80);
        compare(c.shownIndex, 0, "点左箭头 = prev");
        compare(c.isReverse, true, "prev 里 isReverse 置真");
        c.destroy();
    }

    function test_arrowPropsChildrenKeySwapsTheIcon() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: false\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' }\n"
                       + "Rectangle { objectName: 'p1'; color: 'green' } }");
        wait(60);
        // 左格先走字符串档
        c.arrowProps = { leftArrow: { children: "arrow_left" } };
        wait(60);
        compare(part(c, "carouselArrowPrevIcon").name, "arrow_left",
                "ArrowButton.children 给字符串 = 换图标名（官方 demo 用的就是这个键）");
        compare(part(c, "carouselArrowPrevIcon").visible, true, "字符串档仍走 Icon 那条路");
        compare(part(c, "carouselArrowPrevNode").item, null, "字符串档不挂自定义节点");
        near(part(c, "carouselArrowPrev").width, 32, "字符串档不改那一格的尺寸");
        compare(part(c, "carouselArrowNextIcon").name, "chevron_right", "另一侧不受影响");

        // 左格换成 Component 档
        c.arrowProps = { leftArrow: { children: testCase.squareComponent } };
        wait(80);
        verify(part(c, "carouselArrowPrevNode").item !== null, "自定义节点要挂出来");
        compare(part(c, "carouselArrowPrevIcon").visible, false, "Component 档把默认图标收起来");
        near(part(c, "carouselArrowPrev").width, 24, "那一格的宽跟着自定义节点");
        near(part(c, "carouselArrowPrev").height, 24, "高也一样");

        // 右格换成 Component 档，左格收回字符串档
        c.arrowProps = { leftArrow: { children: "arrow_left" },
                         rightArrow: { children: testCase.squareComponent } };
        wait(80);
        compare(part(c, "carouselArrowNextIcon").visible, false, "右侧同理");
        verify(part(c, "carouselArrowNextNode").item !== null);
        near(part(c, "carouselArrowNext").width, 24);
        near(part(c, "carouselArrowNext").height, 24, "右侧那一格的高也跟着节点");
        near(part(c, "carouselArrowNext").y, (200 - 24) / 2, "换了尺寸仍然垂直居中");
        compare(part(c, "carouselArrowPrevNode").item, null, "左格换回字符串档 ⇒ Loader 收掉");
        near(part(c, "carouselArrowPrev").width, 32, "尺寸也跟着收回默认 32");
        c.destroy();
    }

    // ---------------- 子项名单 ----------------

    function test_childrenAddedLaterRebind() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: false\n"
                       + "Rectangle { objectName: 'p0'; color: 'red' } }");
        wait(60);
        compare(c.count, 1);
        compare(part(c, "carouselIndicator").visible, false);
        Qt.createQmlObject("import QtQuick; Rectangle { objectName: 'p1'; color: 'green' }",
                           part(c, "carouselViewport"), "latePage");
        wait(80);
        compare(c.count, 2, "后挂的子项要进名单");
        compare(part(c, "carouselIndicator").visible, true, "指示器跟着出现");
        near(part(c, "p1").width, 300, "并且补上整屏尺寸");
        compare(part(c, "p1").visible, false, "slide 档下它不是当前片");
        c.next();
        wait(80);
        compare(part(c, "p1").visible, true, "切过去之后换它画");
        c.destroy();
    }

    function test_repeaterShellIsNotAPage() {
        const c = make("Carousel { width: 300; height: 200; autoPlay: false\n"
                       + "Repeater { model: 2\n"
                       + "delegate: Rectangle { objectName: 'rp'; color: 'red' } } }");
        wait(120);
        compare(c.count, 2, "Qt 6.11 里 Repeater 自己也是子项，那一层空壳不算一屏");
        c.next();
        wait(60);
        near(part(c, "carouselIndicator").total, 2);
        c.destroy();
    }
}
