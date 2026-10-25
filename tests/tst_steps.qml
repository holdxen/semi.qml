import QtQuick
import QtTest
import Semi

// Steps / Step 步骤条。规格照 packages/semi-ui/steps/{index.tsx,step.tsx,basicSteps.tsx,
// fillSteps.tsx,navSteps.tsx,basicStep.tsx,fillStep.tsx,navStep.tsx,context.ts} 与
// packages/semi-foundation/steps/{constants.ts,bacisSteps.scss,fillSteps.scss,navSteps.scss,
// variables.scss,animation.scss}，数值对着编译产物 packages/semi-ui/dist/css/semi.css
// 20437-20897 段。
//
// 端口口径（完整清单在 src/Steps.qml / src/Step.qml 头注释）：
//   · type 分派三档，缺省 fill；nav 静默丢 status/direction/hasLine，fill 静默丢 size。
//   · `stepNumber = initial + index`，画出来的序号是 `stepNumber + 1`；状态由 stepNumber
//     与 current 比出来，格子自己写了真值 status 才算它自己的。
//   · onChange 的门禁比的是**裸 index**（上游 bug，被它自己的 steps.test.js:240-256 钉死），
//     payload 却是 `index + initial` ⇒ 本文件 test_gateComparesRawIndexNotStepNumber 钉住。
//   · 官方「容器有没有 onChange」决定格子可否点，QML 看不出来 ⇒ 端口换成 clickable 开关。
//   · 全组件 0ms 动画 ⇒ 本文件不测任何过渡。
//
// 断言一律走「给定的容器宽 + 端口自己算出来的格子宽」，不写死字体度量。
TestCase {
    id: testCase

    name: "Steps"
    when: windowShown
    width: 900
    height: 700

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    // 断言失败会跳过用例末尾的 destroy ⇒ 残留实例会继续占版面
    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "steps");
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 0.01,
               (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    function child(step, name) {
        const found = testCase.findChild(step, name);
        verify(found !== null, "格子里要有 " + name);
        return found;
    }

    // 相对宿主格子的左上角，量一个内部节点的落点
    function offsetIn(step, name) {
        const node = child(step, name);
        return node.mapToItem(step, 0, 0);
    }

    function visibleOf(step, name) {
        return child(step, name).visible;
    }

    // ---------------- 属性面与缺省 ----------------

    function test_officialPropDefaults() {
        const s = make("Steps { }");
        compare(s.type, "fill", "index.tsx:40 defaultProps 给的是 fill");
        compare(s.current, 0);
        compare(s.initial, 0);
        compare(s.status, "process", "index.tsx:40");
        compare(s.direction, "horizontal");
        compare(s.size, "default");
        compare(s.hasLine, true, "basicSteps.tsx:26");
        compare(s.items.length, 0);
        compare(s.count, 0);
        s.destroy();
    }

    function test_stepPropDefaults() {
        const k = make("Step { }");
        compare(k.title, "");
        compare(k.description, "");
        compare(k.icon, "");
        compare(k.status, "", "官方 status 的缺省在三个实现里各写一次，端口交给宿主推");
        compare(k.hostType, "", "context.ts 的缺省是 null ⇒ 落在宿主外什么都不画");
        compare(k.visible, false, "没有宿主就不该画");
        compare(k.hostClickable, false);
        k.destroy();
    }

    function test_portOnlySwitchesExist() {
        const s = make("Steps { }");
        compare(s.clickable, true, "端口开关：替代官方「容器有没有 onChange」");
        s.destroy();
        const k = make("Step { }");
        compare(k.clickable, false, "端口开关：替代官方「本格有没有 onClick」");
        k.destroy();
    }

    // ---------------- 收养：子元素档与 items 档 ----------------

    function test_adoptsDeclarativeChildren() {
        const s = make('Steps { width: 600; type: "basic"'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        compare(s.count, 3);
        const cells = s.cellList;
        compare(cells.length, 3);
        for (let i = 0; i < 3; ++i) {
            verify(cells[i].host === s, "第 " + i + " 格要认宿主");
            compare(cells[i].hostIndex, i);
            compare(cells[i].hostTotal, 3);
            compare(cells[i].visible, true);
        }
        s.destroy();
    }

    function test_itemsArrayWinsAndChildrenAreUnadopted() {
        const s = make('Steps { width: 600; items: [{ title: "一" }, { title: "二" }]'
            + '; Step { title: "抢不到的子元素" } }');
        compare(s.listMode, true);
        compare(s.count, 2, "数组非空 ⇒ 整条子元素路不读");
        const cells = s.cellList;
        compare(cells[0].title, "一");
        compare(cells[1].title, "二");
        compare(cells[0].fromRepeater, true);
        let orphan = null;
        for (let i = 0; i < s.children.length; ++i)
            if (s.children[i].title === "抢不到的子元素")
                orphan = s.children[i];
        verify(orphan !== null, "声明式那一格得还挂在容器上");
        compare(orphan.visible, false, "被数组档顶掉 ⇒ 藏掉");
        verify(orphan.host === null, "也不收养它");
        s.destroy();
    }

    function test_itemsReadTitleDescriptionIconStatus() {
        const s = make('Steps { width: 600; type: "basic"; items: ['
            + '{ title: "甲", description: "说明甲", status: "warning" },'
            + '{ title: "乙", icon: "home" } ] }');
        const cells = s.cellList;
        compare(cells.length, 2);
        compare(cells[0].title, "甲");
        compare(cells[0].description, "说明甲");
        compare(cells[0].status, "warning");
        compare(cells[1].icon, "home");
        compare(cells[1].description, "", "数组里没给的键就是缺省");
        s.destroy();
    }

    function test_remountAfterItemsCleared() {
        const s = make('Steps { width: 600; items: [{ title: "一" }]'
            + '; Step { title: "子元素档" } }');
        compare(s.count, 1);
        s.items = [];
        compare(s.listMode, false, "数组清空 ⇒ 回到子元素档");
        compare(s.count, 1, "这时候收养到的就是那条子元素");
        compare(s.cellList[0].title, "子元素档");
        compare(s.cellList[0].visible, true);
        s.destroy();
    }

    // ---------------- 序号与状态推导 ----------------

    function test_displayNumberIsOneBased() {
        const s = make('Steps { width: 600; type: "basic"; current: 1'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        verify(s.numberView.join(",") === "1,2,3", "basicSteps.tsx:48 画的是 stepNumber+1");
        s.destroy();
    }

    function test_initialShiftsNumberingAndStatusTogether() {
        const s = make('Steps { width: 600; type: "basic"; initial: 2; current: 3'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        verify(s.numberView.join(",") === "3,4,5", "initial 把画出来的序号整体抬起来");
        verify(s.statusView.join(",") === "finish,process,wait",
            "current 比的也是 stepNumber ⇒ 3 那一格才是 process");
        verify(s.activeView.join(",") === "false,true,false");
        const cells = s.cellList;
        compare(cells[0].isFirst, true, "isFirst 比的是 hostIndex，不是 stepNumber");
        compare(cells[2].isLast, true, "isLast 同上 ⇒ 末格判定不能跟着 initial 平移");
        near(offsetIn(cells[0], "stepBasicMarker").x, 0, "首格不留那 16 的左内边距");
        compare(visibleOf(cells[2], "stepBasicLine"), false, ":last-child 那一档不画线");
        compare(visibleOf(cells[0], "stepBasicLine"), true);
        s.destroy();
    }

    function test_statusDerivedFromCurrent() {
        const s = make('Steps { width: 600; type: "basic"; current: 1'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        verify(s.statusView.join(",") === "finish,process,wait",
            "basicSteps.tsx:57-65：小于 current 是 finish，等于吃容器 status，大于是 wait");
        verify(s.doneView.join(",") === "true,false,false");
        s.destroy();
    }

    function test_containerStatusColorsOnlyCurrentCell() {
        const s = make('Steps { width: 600; type: "basic"; current: 1; status: "error"'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        verify(s.statusView.join(",") === "finish,error,wait",
            "官方文档那条「使用 Steps 的 status 指定当前步骤的状态」");
        s.destroy();
    }

    function test_userStatusBeatsDerivation() {
        const s = make('Steps { width: 600; type: "basic"; current: 2'
            + '; Step { title: "甲"; status: "warning" } Step { title: "乙" }'
            + ' Step { title: "丙" } }');
        verify(s.statusView.join(",") === "warning,finish,process",
            "格子写了真值就不覆盖；current=2 ⇒ 第二格 finish、第三格才是 process");
        s.destroy();
    }

    function test_emptyStringStatusCountsAsUnset() {
        const s = make('Steps { width: 600; type: "basic"; current: 0'
            + '; Step { title: "甲"; status: "" } Step { title: "乙" } }');
        verify(s.statusView.join(",") === "process,wait",
            "basicSteps.tsx:57 判的是 `!child.props.status` ⇒ 空串等于没写");
        s.destroy();
    }

    function test_navIgnoresStatusAndDirection() {
        const s = make('Steps { width: 600; type: "nav"; current: 1; status: "error"'
            + '; direction: "vertical"'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        const cells = s.cellList;
        verify(s.statusView.join(",") === ",,", "navSteps.tsx 一个都不解构 ⇒ 没有状态概念");
        compare(cells[0].hostDirection, "horizontal", "nav 永远横排");
        compare(cells[0].hostHasLine, false, "hasLine 只管 basic");
        verify(s.activeView.join(",") === "false,true,false");
        s.destroy();
    }

    function test_navActiveUsesRawIndexWhileBasicUsesStepNumber() {
        // initial=1 current=1：basic 比 stepNumber ⇒ 亮的是第一格（stepNumber 1）；
        // nav 比裸 index ⇒ 亮的是第二格（index 1）。同一份入参，两档亮在不同的格上。
        const head = 'Steps { width: 600; initial: 1; current: 1';
        const basic = make(head + '; type: "basic"; Step { title: "甲" } Step { title: "乙" } }');
        const nav = make(head + '; type: "nav"; Step { title: "甲" } Step { title: "乙" } }');
        verify(basic.activeView.join(",") === "true,false",
            "basic 比的是 stepNumber ⇒ 第一格才亮");
        verify(nav.activeView.join(",") === "false,true",
            "navSteps.tsx:34 比的是裸 index ⇒ 第二格亮");
        nav.destroy();
        basic.destroy();
    }

    function test_fillIgnoresSizeButBasicReadsIt() {
        const s = make('Steps { width: 600; size: "small";'
            + ' Step { title: "甲" } Step { title: "乙" } }');
        compare(s.type, "fill");
        const cells = s.cellList;
        compare(cells[0].hostSize, "default", "index.tsx 把 size 传给了 fillSteps，但它不读");
        compare(offsetIn(cells[0], "stepFillMarker").x, 17);
        compare(child(cells[0], "stepFillMarker").height, 24, "fill 的标记恒 24");
        s.destroy();
        const b = make('Steps { width: 600; type: "basic"; size: "small"'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        compare(b.cellList[0].hostSize, "small");
        compare(child(b.cellList[0], "stepBasicMarker").height, 20,
            "bacisSteps.scss:196-201 小档 -left/-icon 收 20");
        b.destroy();
    }

    // ---------------- 可点开关 ----------------

    function test_containerClickableSwitchPropagates() {
        const on = make('Steps { width: 600; type: "basic"; clickable: true'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        verify(on.clickableListView.join(",") === "true,true");
        on.destroy();
        const off = make('Steps { width: 600; type: "basic"; clickable: false'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        verify(off.clickableListView.join(",") === "false,false");
        off.destroy();
    }

    function test_stepOwnClickableMakesOnlyThatCellClickable() {
        const s = make('Steps { width: 600; type: "basic"; clickable: false'
            + '; Step { title: "甲" } Step { title: "乙"; clickable: true }'
            + ' Step { title: "丙" } }');
        verify(s.clickableListView.join(",") === "false,true,false",
            "官方是「本格有 onClick」单独成立");
        s.destroy();
    }

    // ---------------- change 信号与那条裸 index 门禁 ----------------

    // 格子与容器都是 createQmlObject 造出来的，拿不到 TestCase 自动生成的 spy
    // ⇒ 一律用 signal.connect 把发射记到这张表里再断。
    property var signalLog: []

    function spyOn(target) {
        testCase.signalLog = [];
        target.change.connect(function (index) { testCase.signalLog.push(index); });
    }

    function test_changePayloadAddsInitial() {
        const s = make('Steps { width: 600; type: "basic"; initial: 10; current: 0'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        spyOn(s);
        s.requestChange(2);
        compare(testCase.signalLog.length, 1);
        compare(testCase.signalLog[0], 12, "payload = index + initial");
        s.destroy();
    }

    function test_gateComparesRawIndexNotStepNumber() {
        // 上游 steps.test.js:240-256 钉的就是这一对：initial=1 current=1 时
        // 点 index 1（stepNumber 2，并不是当前步）反而**不发**；点 index 0 发。
        const s = make('Steps { width: 600; type: "basic"; initial: 1; current: 1'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        spyOn(s);
        s.requestChange(1);
        compare(testCase.signalLog.length, 0, "裸 index 撞上 current ⇒ 被门禁吃掉");
        s.requestChange(0);
        compare(testCase.signalLog.length, 1, "同一步（stepNumber 1）从 index 0 点得动");
        compare(testCase.signalLog[0], 1);
        s.destroy();
    }

    function test_clickOnCellEmitsChange() {
        const s = make('Steps { width: 600; type: "basic"; current: 0'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        spyOn(s);
        s.stepClicked(1);
        compare(testCase.signalLog.length, 1);
        compare(testCase.signalLog[0], 1);
        s.destroy();
    }

    function test_clickOnCurrentCellIsSilent() {
        const s = make('Steps { width: 600; type: "basic"; current: 0'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        spyOn(s);
        s.stepClicked(0);
        compare(testCase.signalLog.length, 0);
        s.destroy();
    }

    function test_enterOnCurrentCellIsStillGated() {
        // basicStep.tsx:101-106：Enter 调的是 child.props.onChange，而容器把那条
        // onChange 覆盖成了带门禁的闭包 ⇒ 当前格按 Enter 也不发
        const s = make('Steps { width: 600; type: "basic"; current: 0'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        let entered = 0;
        s.cellList[0].enterPressed.connect(function () { entered = entered + 1; });
        spyOn(s);
        s.stepEntered(0);
        compare(entered, 1, "本格自己的 enterPressed 照发");
        compare(testCase.signalLog.length, 0, "容器那条 change 被裸 index 门禁吃掉");
        s.stepEntered(1);
        compare(testCase.signalLog.length, 1);
        s.destroy();
    }

    function test_stepClickedSignalFiresRegardlessOfGate() {
        const s = make('Steps { width: 600; type: "basic"; current: 0'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        const first = s.cellList[0];
        let ownClicked = 0;
        first.clicked.connect(function () { ownClicked = ownClicked + 1; });
        spyOn(s);
        s.stepClicked(0);
        compare(ownClicked, 1, "本格自己的 clicked 不受容器门禁管");
        compare(testCase.signalLog.length, 0, "但容器那条 change 被裸 index 门禁吃掉");
        s.destroy();
    }

    // ---------------- 排布：fill ----------------

    function test_fillCellsAreEqualColumnsWithGutter() {
        const s = make('Steps { width: 640'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" }'
            + ' Step { title: "丁" } }');
        const cells = s.cellList;
        compare(cells.length, 4);
        for (let i = 0; i < 4; ++i) {
            near(cells[i].width, 640 / 4 - 16, "第 " + i + " 格卡面 = 列宽 - 16");
            near(cells[i].x, i * 160, "第 " + i + " 格的步距是整列宽");
            compare(cells[i].y, 0);
            compare(cells[i].height, 72);
        }
        near(s.implicitHeight, 72);
        s.destroy();
    }

    function test_fillLastCellKeepsItsGutter() {
        const s = make('Steps { width: 640; Step { title: "甲" } Step { title: "乙" } }');
        const last = s.cellList[1];
        near(last.x + last.width, 640 - 16, "fillSteps.scss 没有 :last-child 复位 ⇒ 末格也让出 16");
        s.destroy();
    }

    function test_fillVerticalStacksFullWidthMinusGutter() {
        const s = make('Steps { width: 300; direction: "vertical"'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        const cells = s.cellList;
        for (let i = 0; i < 3; ++i) {
            near(cells[i].width, 300 - 16, "第 " + i + " 格整幅减那 16 的右外边距");
            compare(cells[i].x, 0);
            near(cells[i].y, i * 72);
        }
        near(s.implicitHeight, 216);
        s.destroy();
    }

    function test_fillHasNoConnectorInAnyVariant() {
        const h = make('Steps { width: 640; Step { title: "甲" } Step { title: "乙" } }');
        compare(visibleOf(h.cellList[0], "stepBasicLine"), false,
            "fill 档压根没有 -basicLine 这个节点 ⇒ 该不可见");
        h.destroy();
        const v = make('Steps { width: 300; direction: "vertical"'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        compare(visibleOf(v.cellList[0], "stepBasicVLine"), false);
        v.destroy();
    }

    // ---------------- 排布：basic ----------------

    function test_basicLastCellIsContentSizedAndRestShare() {
        const s = make('Steps { width: 640; type: "basic"; current: 1'
            + '; Step { title: "填写信息" } Step { title: "确认信息" }'
            + ' Step { title: "完成" } }');
        const cells = s.cellList;
        const last = cells[2];
        near(last.width, last.implicitWidth, "末格 flex:none 吃内容宽");
        verify(last.width > 24, "末格自然宽要真的算出来，否则上一条是空的");
        const rest = 640 - last.width;
        for (let i = 0; i < 2; ++i) {
            near(cells[i].width, rest / 2, "第 " + i + " 格均分剩下的");
            near(cells[i].x, i * (rest / 2));
        }
        near(last.x, rest);
        near(last.x + last.width, 640, "整条正好铺满容器宽");
        s.destroy();
    }

    function test_basicVerticalStacksAndContainerHeightFollows() {
        const s = make('Steps { width: 300; type: "basic"; direction: "vertical"; current: 1'
            + '; Step { title: "甲"; description: "说明" } Step { title: "乙"; description: "说明" }'
            + ' Step { title: "丙"; description: "说明" } }');
        const cells = s.cellList;
        let sum = 0;
        for (let i = 0; i < 3; ++i) {
            near(cells[i].x, 0, "第 " + i + " 格整幅");
            near(cells[i].width, 300);
            near(cells[i].y, sum, "第 " + i + " 格接在上一格底下");
            verify(cells[i].height > 40, "第 " + i + " 格要有内容高（实得 " + cells[i].height + "）");
            sum += cells[i].height;
        }
        near(s.implicitHeight, sum, "容器高 = 逐格累加（格子晚一拍才有高 ⇒ 靠 hookCell 补算）");
        s.destroy();
    }

    function test_basicSingleCellTakesItsOwnContentWidth() {
        const s = make('Steps { width: 640; type: "basic"; Step { title: "只有一步" } }');
        compare(s.count, 1);
        const only = s.cellList[0];
        near(only.width, only.implicitWidth,
            "count-1 是 0 ⇒ 不能拿去当除数，末格那一档直接吃内容宽");
        verify(only.width > 24, "单格也得有内容宽（实得 " + only.width + "）");
        s.destroy();
    }

    function test_verticalContainerFollowsCellGrowthDeclarative() {
        const s = make('Steps { width: 300; type: "basic"; direction: "vertical"; current: 0'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        const before = s.implicitHeight;
        verify(before > 100, "起手就要有高度（实得 " + before + "）");
        // 描述行从无到有：内容块从 min-height 42 长成 24 + 4 + 20 = 48 ⇒ 本格要跟着高 6
        s.cellList[0].description = "补一行描述";
        wait(20);
        verify(s.implicitHeight > before,
            "格子长高了容器要跟着长（实得 " + s.implicitHeight + "，原来 " + before + "）");
        near(s.implicitHeight, s.cellList[0].height + s.cellList[1].height,
            "容器高恒等于逐格累加，别停在装配那一拍");
        s.destroy();
    }

    function test_verticalContainerFollowsCellGrowthFromItems() {
        const s = make('Steps { width: 300; type: "basic"; direction: "vertical"; current: 0'
            + '; items: [{ title: "甲" }, { title: "乙" }] }');
        const before = s.implicitHeight;
        s.cellList[0].description = "数组档造的格子也一样，长高了容器得跟着重算一次";
        wait(20);
        verify(s.implicitHeight > before,
            "Repeater 那一档也得 hook 上格子的高度变化（实得 " + s.implicitHeight
            + "，原来 " + before + "）");
        s.destroy();
    }

    function test_horizontalContainerHeightIsTallestCell() {
        const s = make('Steps { width: 640; type: "basic"; current: 1'
            + '; Step { title: "甲" } Step { title: "乙"; description: "一行说明" }'
            + ' Step { title: "丙" } }');
        const cells = s.cellList;
        let tallest = 0;
        for (let i = 0; i < cells.length; ++i)
            if (cells[i].implicitHeight > tallest)
                tallest = cells[i].implicitHeight;
        verify(cells[1].implicitHeight > cells[0].implicitHeight,
            "带描述的那一格要比第一格高，否则「取最高的」与「取第一格」同值");
        near(s.implicitHeight, tallest, "横排容器高 = 逐格里最高的那个");
        s.destroy();
    }

    function test_arrangeRerunsWhenWidthChanges() {
        const s = make('Steps { width: 640; Step { title: "甲" } Step { title: "乙" } }');
        near(s.cellList[0].width, 640 / 2 - 16);
        s.width = 400;
        wait(20);
        near(s.cellList[0].width, 400 / 2 - 16, "换宽要重算，不能停在装配时那一版");
        s.destroy();
    }

    // ---------------- 排布：nav ----------------

    function test_navCellsPackLeftToRightByContent() {
        const s = make('Steps { width: 640; type: "nav"; current: 1'
            + '; Step { title: "注册账号" } Step { title: "这个项目的文字比较多多多多" }'
            + ' Step { title: "产品用途" } Step { title: "期待尝试功能" } }');
        const cells = s.cellList;
        let x = 0;
        for (let i = 0; i < 4; ++i) {
            near(cells[i].x, x, "第 " + i + " 格挨着上一格");
            near(cells[i].width, cells[i].implicitWidth, "nav 不撑满，按内容物撑开");
            verify(cells[i].width > 0);
            x += cells[i].width;
        }
        verify(x < 640, "整条只占内容宽，不铺满容器（实得 " + x + "）");
        s.destroy();
    }

    // ---------------- 格子内部几何 ----------------

    function test_fillMarkerAndContentAreTopAligned() {
        const s = make('Steps { width: 640; Step { title: "甲"; description: "说明" }'
            + ' Step { title: "乙" } }');
        const k = s.cellList[0];
        const marker = offsetIn(k, "stepFillMarker");
        near(marker.x, 17, "边框 1 + paddingX 16");
        near(marker.y, 13, "边框 1 + paddingY 12；容器没写 align-items ⇒ 顶对齐不是居中");
        const content = offsetIn(k, "stepFillContent");
        near(content.x, 57, "17 + 24 标记 + -content{margin-left:16}");
        near(content.y, 13);
        near(child(k, "stepFillTitle").height, 24, "CSS:20458 行高 24");
        near(child(k, "stepFillDescription").height, 20, "CSS:20470 行高 20");
        s.destroy();
    }

    function test_fillContentBoxAndMarkerShape() {
        const s = make('Steps { width: 640; current: 0; Step { title: "甲"; description: "说明" }'
            + ' Step { title: "乙" } }');
        const k = s.cellList[0];
        const content = child(k, "stepFillContent");
        near(content.width, k.width - 57 - 17, "内容块右边也要让出 1 边框 + 16 内边距");
        compare(child(k, "stepFillMarker").radius, 12, "24 的圆：border-radius 50%");
        near(k.implicitWidth, k.width, "fill 的隐式宽就是卡面宽（外部按内容排时要读它）");
        s.destroy();
    }

    function test_fillMarkerColorAndGlyphPerStatus() {
        const s = make('Steps { width: 640; current: 1; Step { title: "甲" }'
            + ' Step { title: "乙" } Step { title: "丙"; status: "error" }'
            + ' Step { title: "丁"; status: "warning" } }');
        const cells = s.cellList;
        compare(child(cells[1], "stepFillMarker").color, Theme.current.colorPrimary,
            "process 是实心 primary 底");
        compare(child(cells[2], "stepFillMarker").color, Qt.rgba(0, 0, 0, 0),
            "error 这一档不画底，画 glyph");
        compare(child(cells[2], "stepFillGlyph").name, "alert_circle");
        compare(child(cells[3], "stepFillGlyph").name, "alert_triangle",
            "warning 用的是三角，不是圆");
        s.destroy();
    }

    function test_stepHandlersFollowTheClickableSwitch() {
        const off = make('Steps { width: 640; type: "basic"; clickable: false; Step { title: "甲" } }');
        const on = make('Steps { width: 640; type: "basic"; clickable: true; Step { title: "甲" } }');
        compare(child(off.cellList[0], "stepTap").enabled, false, "不可点 ⇒ 连手势都不接");
        compare(child(off.cellList[0], "stepHover").enabled, false);
        compare(child(on.cellList[0], "stepTap").enabled, true);
        compare(child(on.cellList[0], "stepHover").enabled, true);
        on.destroy();
        off.destroy();
    }

    function test_verticalBasicLineGeometry() {
        const s = make('Steps { width: 300; type: "basic"; direction: "vertical"; current: 0'
            + '; Step { title: "甲"; description: "说明" } Step { title: "乙" } }');
        const k = s.cellList[0];
        compare(visibleOf(k, "stepBasicLine"), false, "竖排那一档画的是竖线，横线该收着");
        near(child(k, "stepBasicVLine").height, child(k, "stepBasicBox").height - 33);
        s.destroy();
    }

    function test_horizontalConnectorIsOnePixelTall() {
        const s = make('Steps { width: 640; type: "basic"; current: 0; Step { title: "甲" }'
            + ' Step { title: "乙" } }');
        near(child(s.cellList[0], "stepBasicLine").height, 1, "$height-steps_title_after");
        near(child(s.cellList[0], "stepBasicVLine").width, 1, "竖着那根同理 1px");
        s.destroy();
    }

    function test_smallVerticalContentMinHeightIsForty() {
        const big = make('Steps { width: 300; type: "basic"; direction: "vertical"; Step { title: "甲" } }');
        const small = make('Steps { width: 300; type: "basic"; direction: "vertical"; size: "small"'
            + '; Step { title: "甲" } }');
        near(child(big.cellList[0], "stepBasicContent").height, 42,
            "variables.scss:52 竖排内容 min-height 42");
        near(child(small.cellList[0], "stepBasicContent").height, 40,
            "variables.scss:55 小档收到 40");
        small.destroy();
        big.destroy();
    }

    function test_lastCellTitleIsNotSqueezedToEightyPercent() {
        // 两格标题都写得足够长，长到一定撞 max-width，这样 80% 与 100% 才分得开
        const long = "这一格的标题写得相当长一些好去撞那道百分比上限所以故意拉这么长";
        const s = make('Steps { width: 640; type: "basic"; current: 0'
            + '; Step { title: "' + long + '" } Step { title: "' + long + '" } }');
        const cells = s.cellList;
        near(child(cells[0], "stepBasicTitle").width,
            child(cells[0], "stepBasicContent").width * 0.8, "横排非末格：max-width 80%");
        verify(child(cells[1], "stepBasicTitle").width
            > child(cells[1], "stepBasicContent").width * 0.8 + 1,
            ":last-child 那一档改回 100% 且 padding-right:0（CSS:20600-20608）");
        s.destroy();
    }

    function test_fillDescriptionLineExistsWithoutDescription() {
        const s = make('Steps { width: 640; Step { title: "甲" } }');
        const line = child(s.cellList[0], "stepFillDescription");
        compare(line.visible, true, "fillStep.tsx:100-105 无条件渲染那一行");
        compare(line.text, "");
        s.destroy();
    }

    function test_basicMarkerIndentOnlyForNonFirstHorizontal() {
        const h = make('Steps { width: 640; type: "basic"'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        near(offsetIn(h.cellList[0], "stepBasicMarker").x, 0, ":first-child 清掉左内边距");
        near(offsetIn(h.cellList[1], "stepBasicMarker").x, 16);
        near(offsetIn(h.cellList[2], "stepBasicMarker").x, 16);
        near(offsetIn(h.cellList[1], "stepBasicContent").x, 16 + 24 + 8,
            "-left{margin-right:8} = $spacing-tight");
        h.destroy();
        const v = make('Steps { width: 300; type: "basic"; direction: "vertical"'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        for (let i = 0; i < 3; ++i)
            near(offsetIn(v.cellList[i], "stepBasicMarker").x, 0,
                "竖排那一档没有 padding-left（它写在 &-horizontal 里）第 " + i + " 格");
        v.destroy();
    }

    function test_basicFirstCellHasNoTopPaddingInVertical() {
        const s = make('Steps { width: 300; type: "basic"; direction: "vertical"'
            + '; Step { title: "甲"; description: "说明" } Step { title: "乙"; description: "说明" } }');
        const first = s.cellList[0];
        const second = s.cellList[1];
        near(second.height - first.height, 9,
            "bacisSteps.scss:122-126：padding-top 9，:first-child 清掉");
        s.destroy();
    }

    function test_basicNumberFontSizeFollowsSize() {
        const big = make('Steps { width: 640; type: "basic"; current: 0'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        const small = make('Steps { width: 640; type: "basic"; size: "small"; current: 0'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        compare(child(big.cellList[0], "stepBasicNumber").font.pixelSize, 16,
            "bacisSteps.scss:187 数字 16px");
        compare(child(small.cellList[0], "stepBasicNumber").font.pixelSize, 12,
            "bacisSteps.scss:200 小档收 12");
        compare(child(small.cellList[0], "stepBasicTitle").height, 20, "小档标题行盒 20");
        small.destroy();
        big.destroy();
    }

    function test_basicContentHeightCarriesTheFourPixelGap() {
        // 标题 24 + title 的 margin-bottom 4 + 描述 20 = 48，已经高过 min-height 42
        // ⇒ 这一档吃的是文字块，那 4 漏掉就少 4
        const s = make('Steps { width: 640; type: "basic"; direction: "vertical"; current: 0'
            + '; Step { title: "甲"; description: "一行说明" } }');
        const k = s.cellList[0];
        const content = child(k, "stepBasicContent");
        near(content.implicitHeight,
            child(k, "stepBasicTitle").height + 4 + child(k, "stepBasicDescription").height);
        verify(content.height > 42, "文字块要压过 min-height，否则这条是空的（实得 "
            + content.height + "）");
        near(content.height, content.implicitHeight, "竖排吃的是 max(42, 文字块)");
        s.destroy();
    }

    function test_onlyOneBranchIsVisible() {
        const fill = make('Steps { width: 640; Step { title: "甲" } Step { title: "乙" } }');
        const basic = make('Steps { width: 640; type: "basic"; Step { title: "甲" }'
            + ' Step { title: "乙" } }');
        const nav = make('Steps { width: 640; type: "nav"; Step { title: "甲" }'
            + ' Step { title: "乙" } }');
        const boxes = ["stepFillBox", "stepBasicBox", "stepNavBox"];
        const tables = [[true, false, false], [false, true, false], [false, false, true]];
        const trio = [fill, basic, nav];
        for (let t = 0; t < 3; ++t) {
            const k = trio[t].cellList[0];
            for (let b = 0; b < 3; ++b)
                compare(visibleOf(k, boxes[b]), tables[t][b],
                    "第 " + t + " 档里 " + boxes[b] + " 该" + (tables[t][b] ? "画" : "不画"));
        }
        nav.destroy();
        basic.destroy();
        fill.destroy();
    }

    function test_basicConnectorEndsAtCellEdgeAndSkipsLast() {
        const s = make('Steps { width: 640; type: "basic"; current: 1'
            + '; Step { title: "填写信息" } Step { title: "确认信息" } Step { title: "完成" } }');
        const cells = s.cellList;
        const line = child(cells[0], "stepBasicLine");
        compare(line.visible, true);
        const box = child(cells[0], "stepBasicBox");
        const lineOrigin = line.mapToItem(cells[0], 0, 0);
        near(lineOrigin.x + line.width, box.width,
            "连接线是标题的 ::after 被 overflow:hidden 裁在格子边上");
        verify(lineOrigin.x > offsetIn(cells[0], "stepBasicTitle").x
            + child(cells[0], "stepBasicTitle").width,
            "起点在标题右边界之外（含标题那 16 的 padding-right）");
        compare(visibleOf(cells[2], "stepBasicLine"), false, ":last-child 那一档 display:none");
        s.destroy();
    }

    function test_hasLineFalseHidesBothConnectors() {
        const s = make('Steps { width: 640; type: "basic"; hasLine: false'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        compare(visibleOf(s.cellList[0], "stepBasicLine"), false, "1.18.0 那条 hasLine");
        compare(child(s.cellList[0], "stepBasicLine").visible, false);
        s.destroy();
    }

    function test_verticalConnectorSitsUnderTheMarker() {
        const s = make('Steps { width: 300; type: "basic"; direction: "vertical"; current: 0'
            + '; Step { title: "甲"; description: "说明" } Step { title: "乙"; description: "说明" } }');
        const k = s.cellList[0];
        const line = child(k, "stepBasicVLine");
        compare(line.visible, true);
        const origin = line.mapToItem(k, 0, 0);
        const marker = offsetIn(k, "stepBasicMarker");
        near(origin.x, marker.x + 12 - 0.5, "left:50% 宽 1");
        near(origin.y, marker.y + 24 + 9, "top:100% 且 -icon{padding-bottom:9}");
        near(line.height, child(k, "stepBasicBox").height - origin.y,
            "高 9999 被裁到格子底边");
        compare(visibleOf(s.cellList[1], "stepBasicVLine"), false, "末格不给");
        s.destroy();
    }

    function test_navChevronAbsentOnLastCell() {
        const s = make('Steps { width: 640; type: "nav"'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        const cells = s.cellList;
        compare(visibleOf(cells[0], "stepNavChevron"), true);
        compare(child(cells[0], "stepNavChevron").size, 12, 'navStep.tsx:46 size="small"');
        compare(visibleOf(cells[1], "stepNavChevron"), false, "最后一格不给分隔符");
        s.destroy();
    }

    // ---------------- 颜色分派 ----------------

    function test_fillTitleColorFollowsStatus() {
        const s = make('Steps { width: 640; current: 1; status: "process"'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        const cells = s.cellList;
        compare(child(cells[0], "stepFillTitle").color, Theme.current.colorSuccess,
            "CSS:20508 只有 fill 档把已完成的标题染成 success");
        compare(child(cells[1], "stepFillTitle").color, Theme.current.colorPrimary);
        compare(child(cells[2], "stepFillTitle").color, Theme.current.colorText0);
        s.destroy();
    }

    function test_fillProcessCardBackgroundOnlyOnProcess() {
        const s = make('Steps { width: 640; current: 1; Step { title: "甲" }'
            + ' Step { title: "乙" } Step { title: "丙" } }');
        const cells = s.cellList;
        compare(child(cells[1], "stepFillCard").color, Theme.current.colorPrimaryLightDefault);
        compare(child(cells[0], "stepFillCard").color, Qt.rgba(0, 0, 0, 0),
            "fill 的卡片底色只有 process 那一档有");
        compare(child(cells[2], "stepFillCard").color, Qt.rgba(0, 0, 0, 0));
        s.destroy();
    }

    function test_basicTitleColorOnlyWaitIsDimmed() {
        const s = make('Steps { width: 640; type: "basic"; current: 1'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        const cells = s.cellList;
        compare(child(cells[0], "stepBasicTitle").color, Theme.current.colorText0,
            "basic 档 finish 不改标题（CSS:20767 只有 wait 那一条）");
        compare(child(cells[1], "stepBasicTitle").color, Theme.current.colorText0);
        compare(child(cells[2], "stepBasicTitle").color, Theme.current.colorText2);
        s.destroy();
    }

    function test_basicBadgeOnlyForWaitAndProcess() {
        const s = make('Steps { width: 640; type: "basic"; current: 0; status: "error"'
            + '; Step { title: "甲"; status: "finish" } Step { title: "乙"; status: "error" }'
            + ' Step { title: "丙"; status: "warning" } Step { title: "丁"; status: "process" }'
            + ' Step { title: "戊"; status: "wait" } }');
        const cells = s.cellList;
        compare(visibleOf(cells[0], "stepBasicBadge"), false, "finish 画 glyph 不画徽标");
        compare(visibleOf(cells[0], "stepBasicGlyph"), true);
        compare(child(cells[0], "stepBasicGlyph").color, Theme.current.colorPrimary);
        compare(child(cells[1], "stepBasicGlyph").color, Theme.current.colorDanger);
        compare(child(cells[2], "stepBasicGlyph").color, Theme.current.colorWarning);
        compare(visibleOf(cells[3], "stepBasicBadge"), true);
        compare(child(cells[3], "stepBasicBadge").color, Theme.current.colorPrimary);
        compare(child(cells[3], "stepBasicNumber").color, Theme.current.colorWhite);
        compare(child(cells[4], "stepBasicBadge").color, Theme.current.colorFill0,
            "CSS:20774 wait 的徽标底是 fill-0");
        compare(child(cells[4], "stepBasicNumber").color, Theme.current.colorText2);
        s.destroy();
    }

    function test_navOnlyVisualIsWeightAndColor() {
        const s = make('Steps { width: 640; type: "nav"; current: 1'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        const cells = s.cellList;
        const active = child(cells[1], "stepNavTitle");
        const idle = child(cells[0], "stepNavTitle");
        compare(active.color, Theme.current.colorText0);
        compare(idle.color, Theme.current.colorText2);
        verify(active.font.weight > idle.font.weight, "选中加粗、未选中常规");
        compare(child(cells[0], "stepNavChevron").color, Theme.current.colorText2,
            "槽位那条 --semi-grey-3 是非法声明，实际继承的是容器的 text-2");
        s.destroy();
    }

    // ---------------- 图标档 ----------------

    function test_stringIconReplacesTheMarker() {
        const s = make('Steps { width: 640; type: "basic"; current: 0'
            + '; Step { title: "甲"; icon: "home" } Step { title: "乙" } }');
        const cells = s.cellList;
        compare(visibleOf(cells[0], "stepBasicBadge"), false, "给了 icon 就没有数字徽标");
        compare(visibleOf(cells[0], "stepBasicNumber"), false);
        compare(visibleOf(cells[0], "stepBasicIconName"), true);
        compare(child(cells[0], "stepBasicIconName").name, "home");
        compare(child(cells[0], "stepBasicIconName").size, 24);
        compare(visibleOf(cells[1], "stepBasicBadge"), true, "没给的那格照旧");
        s.destroy();
    }

    function test_explicitNullIconKillsWholeMarker() {
        const s = make('Steps { width: 640; type: "basic"; current: 0'
            + '; Step { title: "甲"; icon: null } }');
        const k = s.cellList[0];
        compare(visibleOf(k, "stepBasicBadge"), false);
        compare(visibleOf(k, "stepBasicNumber"), false);
        compare(visibleOf(k, "stepBasicGlyph"), false);
        compare(visibleOf(k, "stepBasicIconName"), false);
        compare(visibleOf(k, "stepBasicIconHook"), false);
        s.destroy();
    }

    function test_emptyStringIconCountsAsNotGiven() {
        // 端口把「没写」与空串并成一档（QML 的 var 缺省读回来就是 null，没法再细分），
        // 所以只有显式 null 才走官方那条 `'icon' in props`。
        const s = make('Steps { width: 640; type: "basic"; current: 0'
            + '; Step { title: "甲"; icon: "" } }');
        const k = s.cellList[0];
        compare(k.noOverrideIcon, true);
        compare(visibleOf(k, "stepBasicBadge"), true, "空串不抹标记位");
        compare(visibleOf(k, "stepBasicIconName"), false);
        s.destroy();
    }

    function test_stringIconInFillReplacesCircle() {
        const s = make('Steps { width: 640; current: 0; Step { title: "甲"; icon: "lock" } }');
        const k = s.cellList[0];
        compare(visibleOf(k, "stepFillMarker"), false);
        compare(visibleOf(k, "stepFillIconName"), true);
        compare(child(k, "stepFillIconName").name, "lock");
        near(offsetIn(k, "stepFillIconName").x, 17, "自定义图标顶到标记位那一格");
        s.destroy();
    }

    // ---------------- 边界 ----------------

    function test_emptyContainerIsHarmless() {
        const s = make("Steps { width: 640 }");
        compare(s.count, 0);
        near(s.implicitHeight, 0);
        compare(s.cellList.length, 0);
        s.destroy();
    }

    function test_currentBeyondCountLeavesAllFinished() {
        const s = make('Steps { width: 640; type: "basic"; current: 5'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        verify(s.statusView.join(",") === "finish,finish",
            "current 越界时官方也只是全 finish，不夹取");
        s.destroy();
    }

    function test_negativeCurrentLeavesAllWaiting() {
        const s = make('Steps { width: 640; type: "basic"; current: -1'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        verify(s.statusView.join(",") === "wait,wait");
        s.destroy();
    }

    function test_unknownTypeDrawsNothing() {
        const s = make('Steps { width: 640; type: "mystery"'
            + '; Step { title: "甲" } Step { title: "乙" } }');
        compare(s.count, 2, "收养照做（index.tsx 的分派不看 type 合不合法）");
        compare(s.cellList[0].hostType, "mystery");
        compare(s.cellList[0].visible, false, "step.tsx:19-35 认不出分派 ⇒ 什么都不画");
        s.destroy();
    }

    function test_cellsRecycleWhenItemsChange() {
        const s = make('Steps { width: 640; type: "basic"; items: [{ title: "一" },'
            + ' { title: "二" }] }');
        compare(s.count, 2);
        const before = s.cellList[0];
        s.items = [{ title: "甲" }];
        wait(20);
        compare(s.count, 1, "数组换短了 ⇒ 格子跟着少");
        verify(s.cellList[0] !== before || s.cellList[0].title === "甲",
            "剩下的那一格得是新数据");
        compare(s.cellList[0].title, "甲");
        verify(s.numberView.join(",") === "1");
        s.destroy();
    }

    function test_injectRerunsOnCurrentChange() {
        const s = make('Steps { width: 640; type: "basic"; current: 0'
            + '; Step { title: "甲" } Step { title: "乙" } Step { title: "丙" } }');
        verify(s.statusView.join(",") === "process,wait,wait");
        s.current = 2;
        verify(s.statusView.join(",") === "finish,finish,process",
            "改 current 要重推每一格的状态");
        verify(s.doneView.join(",") === "true,true,false");
        s.destroy();
    }
}
