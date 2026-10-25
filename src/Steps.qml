pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 步骤条。对应 `packages/semi-ui/steps/{index.tsx,step.tsx,basicSteps.tsx,fillSteps.tsx,
// navSteps.tsx,context.ts}` + `semi-foundation/steps/{constants.ts,bacisSteps.scss,
// fillSteps.scss,navSteps.scss,variables.scss,animation.scss}`。
//
//     Steps {
//         type: "basic"
//         current: 1
//         Step { title: "填写信息" }
//         Step { title: "确认信息" }
//         Step { title: "完成" }
//         onChange: (index) => …
//     }
//
// 官方 `index.tsx:43-55` 是一个按 `type` 分派三个实现的外壳，`step.tsx:19-35` 再按 context
// 里的同一枚 `type` 分派三个格子实现 ⇒ 端口同样收成一个 `Steps` + 一个 `Step`，
// 内部按 `hostType` 分支（分派细节见 src/Step.qml 头注释）。
//
// ---------------------------------------------------------------- 与官方的口径差异（逐条）
//   · 官方回调 → 信号：`onChange(current)` → `change(int index)`。官方每个回调第一个入参是
//     React 事件对象，端口不带。Step 的 `onClick` / `onKeyDown`（只认 Enter）→ `clicked()` /
//     `enterPressed()`，无参。
//   · **官方没有数据数组这一档**：三个容器都是 `Children.toArray(children)` 收子元素。
//     `items` 是端口为兼容旧页面留的**第二条路**，口径照 Descriptions：数组非空时子元素
//     整条不读、也不收养（见 collect()）。
//   · `className` / `style` / `prefixCls` 是 DOM 通道，不收。
//   · Step 上**不开 onChange**：官方容器的注入写在 `{...child.props}` 之后
//     （basicSteps.tsx:68-72），用户写在格子上的 onChange 会被无条件覆盖掉，
//     文档表里也没有这一条 ⇒ 端口干脆不提供，避免「写了没用」。
//   · `role` / `aria-label` 收进来挂 `Accessible`。官方 `aria-current="step"` 是**每一格都挂**
//     （basicStep.tsx:112 / fillStep.tsx:80 / navStep.tsx:39 —— 规范上只该给当前那格），
//     端口照抄成 `Accessible.current` 全挂。
//   · RTL（rtl.scss）端口不做。顺带记一条：上游 rtl 那份的 `&-item` 被 Sass 摊平成
//     `.semi-rtl .semi-steps-item`（CSS:20868-20872），**没有 `.semi-steps` 祖先约束**，
//     于是 fill 那 16px 左外边距会漏到 basic 与 nav 的格子上。
//   · **整个组件没有任何动画**：`animation.scss` 把 title / icon / background 三条 transition
//     全映射到 `--semi-transition_duration-none` = 0ms（CSS:710）⇒ 端口一条 Behavior 都不挂。
//     另外 CSS:20454 / 20706 那两处 `transform: scale(var(--semi-transform_scale-small))`
//     展开成 `scale(scale(1,1))` 是非法声明、被丢掉。
//
// ---------------------------------------------------------------- 抄下来的上游 bug（不"修好"）
//   · `onChange` 的门禁写的是**裸 index** 而不是 `stepNumber`：`if (index !== current)`
//     （basicSteps.tsx:69 / fillSteps.tsx:54 / navSteps.tsx:36）。上游
//     `steps/__test__/steps.test.js:240-256` 还把这条钉成了期望：`initial=1 current=1` 时
//     点 index 1 **不发**、点 index 0 **发**。端口照抄。
//   · `nav` 档高亮用 `index === current`（navSteps.tsx:34，**忽略 initial**），
//     但 payload 用 `index + initial`（:37）⇒ 两件事各算各的。端口照抄。
//   · `nav` 档在 `index.tsx:44` 的 restProps 里收得到 `status` / `direction` / `hasLine`，
//     但 `navSteps.tsx:8-18` 一个都不解构 ⇒ 静默丢弃（nav 永远横排、永远没有状态概念）。
//   · `fill` 档同理收得到 `size` 但从不读 ⇒ `size="small"` 对 fill 完全无效。
//   · `basicSteps.tsx:27` 的 `size` 缺省是**空串**，配上 :81 的 `size !== 'default'` 判定，
//     直接用 BasicSteps 会挂出一个空类名 `.semi-steps-`；经 `<Steps>` 走不到那一支
//     （index.tsx:40 的 defaultProps 恒给 'default'）。
//   · `<Step icon={null}/>` 走的是 `'icon' in props`（basicStep.tsx:55 / fillStep.tsx:31）
//     而不是真值判定 ⇒ 显式给 null 会把**整个标记位**抹掉，连状态徽标都拿不回来。
//   · 「前一步变红」那一套 `semi-steps-next-error` 类名（basicSteps.tsx:54 / fillSteps.tsx:41）
//     在 semi.css 里 **0 条规则**，而且它是**赋值不是追加** —— 命中的那一格用户自己的
//     className 会被丢掉。端口不复现（既无视觉，也不该丢用户类名）。
Item {
    id: control

    // ================================================================ 官方属性面
    property string type: "fill"                  // fill | basic | nav，缺省 fill
    property int current: 0                       // 从 0 起算
    property int initial: 0
    property string status: "process"             // wait|process|finish|error|warning；nav 不读
    property string direction: "horizontal"       // horizontal | vertical；nav 不读
    property string size: "default"               // small | default；fill 不读
    property bool hasLine: true                   // 只管 basic 档
    property string ariaLabel: ""
    /// 端口扩展：官方只有子元素那一档，这条是为兼容旧页面留的
    property var items: []

    signal change(int index)

    // ================================================================ 内部
    /// 收养到的格子（Step 实例 + 用户给的数据）
    property var cells: []
    property bool _mounted: false

    readonly property bool vertical: control.direction === "vertical"
    readonly property bool listMode: control.items !== undefined && control.items !== null
        && control.items.length > 0
    readonly property int count: control.cells.length
    /// 官方是「容器有 onChange 或本格有 onClick」⇒ 格子才既可点又有手型与悬浮态。
    /// QML 看不到「有没有人连这个信号」，所以端口把同一件事做成两枚显式开关：
    /// 容器这一枚 = 官方「Steps 有 onChange」，格子那一枚 = 官方「Step 有 onClick」。
    property bool clickable: true

    implicitHeight: control.layoutHeight

    // ================================================================ 收集与注入
    function collect() {
        const out = [];
        for (let i = 0; i < control.children.length; ++i) {
            const k = control.children[i];
            if (k.isStep !== true || k.fromRepeater === true)
                continue;
            if (control.listMode) {
                // 数组那一档赢：子元素整条不读、也不收养（同 Descriptions 的口径）。
                // 不去写 k.visible —— 格子自己那一条 `visible: hostType 认得出档` 的绑定
                // 一旦被赋值打断就再也接不回来，数组清空后那一格会永远隐身；
                // 撤档改回 hostType 空串，让格子那条绑定自己把画面收掉。
                k.host = null;
                k.hostType = "";
                control.unhookCell(k);
                continue;
            }
            k.host = control;
            control.hookCell(k);
            out.push(k);
        }
        if (control.listMode) {
            for (let i = 0; i < control.itemCountForRepeater(); ++i) {
                const k = stepRepeater.itemAt(i);
                if (k !== null) {
                    control.hookCell(k);
                    out.push(k);
                }
            }
        }
        control.cells = out;
        control.inject();
    }

    // 格子的 implicitHeight 要等它自己那棵子树排完才有真值，比 collect()/arrange() 晚一拍。
    // 竖排要把这些高度逐格累加成容器高，所以必须挂上变化信号，否则容器永远停在第一次
    // 算出来的 0（竖直步骤条整节塌成 66 高就是这么来的）。
    function hookCell(k) {
        control.unhookCell(k);
        k.implicitHeightChanged.connect(control.arrange);
    }

    function unhookCell(k) {
        try {
            k.implicitHeightChanged.disconnect(control.arrange);
        } catch (e) {
            // 没连过 ⇒ 断开抛 TypeError，忽略即可
        }
    }

    function itemCountForRepeater() {
        return control.listMode ? control.items.length : 0;
    }

    function inject() {
        for (let i = 0; i < control.cells.length; ++i) {
            const k = control.cells[i];
            const stepNumber = control.initial + i;
            k.hostType = control.type;
            k.hostSize = control.type === "fill" ? "default" : control.size;
            k.hostDirection = control.type === "nav" ? "horizontal" : control.direction;
            k.hostHasLine = control.type === "basic" ? control.hasLine : false;
            k.hostIndex = i;
            k.hostTotal = control.cells.length;
            k.hostStepNumber = stepNumber;
            k.hostDisplayNumber = stepNumber + 1;   // 画出来恒是 1 起（basicSteps.tsx:48）
            k.hostActive = control.type === "nav" ? (i === control.current)
                : (stepNumber === control.current);
            k.hostDone = stepNumber < control.current;
            k.hostStatus = control.deriveStatus(stepNumber, k.status);
            k.hostClickable = control.clickable || k.clickable === true;
        }
        control.arrange();
    }

    function deriveStatus(stepNumber, own) {
        // basicSteps.tsx:57-65：`if (!child.props.status)` ⇒ 用户写了真值才作数
        if (own !== undefined && own !== null && own !== "")
            return own;
        if (control.type === "nav")
            return "";
        if (stepNumber < control.current)
            return "finish";
        if (stepNumber === control.current)
            return control.status;
        return "wait";
    }

    // ================================================================ 交互
    function stepClicked(index) {
        const k = control.cellAt(index);
        if (k !== null)
            k.clicked();
        control.requestChange(index);
    }

    function stepEntered(index) {
        const k = control.cellAt(index);
        if (k !== null)
            k.enterPressed();
        control.requestChange(index);
    }

    function requestChange(index) {
        // 抄上游那条裸 index 门禁（见头注释「抄下来的上游 bug」第一条）
        if (index === control.current)
            return;
        control.change(index + control.initial);
    }

    function cellAt(index) {
        return index >= 0 && index < control.cells.length ? control.cells[index] : null;
    }

    // ================================================================ 排布
    // fill：每格占 1/n 的列宽、卡面再让出 16 的右外边距（**最后一格也让**，上游没有
    //        :last-child 复位）；竖排时列宽整幅、按高 flex。
    // basic：横排除最后一格外都 flex:1，最后一格吃内容宽；竖排整幅往下堆。
    // nav：整条 inline-flex 撑内容宽，格子挨着排。
    function fillItemWidth() {
        if (control.count === 0)
            return 0;
        // 每格包在一个 `<Col style={{width: 100/n}}>` 里（fillSteps.tsx:27,57），格子的
        // `margin-right:16` 是块级盒 ⇒ 卡面 = 列宽 - 16。竖排那一档 colStyle 是 null，
        // 但 `.semi-steps .semi-col{flex:1}`（fillSteps.scss:4-6）+ 交叉轴 stretch 一样是整幅，
        // 那 16 的右外边距照旧 ⇒ 竖排同样是「整幅 - 16」。
        return control.vertical ? Math.max(0, control.width - 16)
            : Math.max(0, control.width / control.count - 16);
    }

    function basicItemWidth(index) {
        if (control.count === 0)
            return 0;
        if (control.vertical)
            return Math.max(0, control.width);
        const last = control.count - 1;
        if (index === last)
            return control.lastNaturalWidth();
        const rest = Math.max(0, control.width - control.lastNaturalWidth());
        return control.count > 1 ? rest / last : rest;
    }

    function lastNaturalWidth() {
        // 不设 24 的下限：basic 格子的 implicitWidth 至少是「标记 24 + 8」= 32，那道夹取永远不生效
        const last = control.cellAt(control.count - 1);
        return last === null ? 0 : last.implicitWidth;
    }

    function arrange() {
        let x = 0;
        let y = 0;
        for (let i = 0; i < control.cells.length; ++i) {
            const k = control.cells[i];
            if (k === null)
                continue;
            k.x = x;
            k.y = y;
            if (control.type === "fill") {
                k.width = control.fillItemWidth();
                k.height = 72;
                x += control.vertical ? 0 : (k.width + 16);
                y += control.vertical ? 72 : 0;
            } else if (control.type === "nav") {
                k.width = k.implicitWidth;
                k.height = k.implicitHeight;
                x += k.width;
            } else {
                k.width = control.basicItemWidth(i);
                k.height = k.implicitHeight;
                x += control.vertical ? 0 : k.width;
                y += control.vertical ? k.height : 0;
            }
        }
        control.layoutHeight = control.count === 0 ? 0
            : (control.type === "fill"
                ? (control.vertical ? 72 * control.count : 72)
                : (control.vertical ? y : control.maxRowHeight()));
    }

    function maxRowHeight() {
        let m = 0;
        for (let i = 0; i < control.cells.length; ++i) {
            const k = control.cells[i];
            if (k !== null && k.implicitHeight > m)
                m = k.implicitHeight;
        }
        return m;
    }

    property real layoutHeight: 0

    // ================================================================ 测试口子
    readonly property var statusView: control.statusListOf()
    readonly property var numberView: control.numberListOf()
    readonly property var activeView: control.activeListOf()
    readonly property var doneView: control.doneListOf()
    readonly property var clickableListView: control.clickableListOf()
    readonly property var cellList: control.cells

    function statusListOf() {
        const out = [];
        for (let i = 0; i < control.cells.length; ++i)
            out.push(control.cells[i].hostStatus);
        return out;
    }

    function numberListOf() {
        const out = [];
        for (let i = 0; i < control.cells.length; ++i)
            out.push(control.cells[i].hostDisplayNumber);
        return out;
    }

    function activeListOf() {
        const out = [];
        for (let i = 0; i < control.cells.length; ++i)
            out.push(control.cells[i].hostActive);
        return out;
    }

    function doneListOf() {
        const out = [];
        for (let i = 0; i < control.cells.length; ++i)
            out.push(control.cells[i].hostDone);
        return out;
    }

    function clickableListOf() {
        const out = [];
        for (let i = 0; i < control.cells.length; ++i)
            out.push(control.cells[i].hostClickable);
        return out;
    }

    // ================================================================ 生命周期
    Component.onCompleted: {
        control.collect();
        control._mounted = true;
    }
    onChildrenChanged: control.collect()
    onItemsChanged: control.collect()
    onTypeChanged: control.inject()
    onCurrentChanged: control.inject()
    onInitialChanged: control.inject()
    onStatusChanged: control.inject()
    onSizeChanged: control.inject()
    onDirectionChanged: control.inject()
    onHasLineChanged: control.inject()
    onWidthChanged: control.arrange()
    onCountChanged: control.arrange()

    Accessible.role: Accessible.Grouping
    Accessible.name: control.ariaLabel

    // items 那一档：数组当模型，造出来的格子标 fromRepeater，不参与 children 收养
    Repeater {
        id: stepRepeater

        model: control.listMode ? control.items : []

        delegate: Step {
            id: repStep

            objectName: "stepFromItems"

            required property var modelData
            required property int index

            fromRepeater: true
            title: repStep.textOfModel("title")
            description: repStep.textOfModel("description")
            icon: repStep.valueOfModel("icon")
            status: repStep.textOfModel("status")

            function textOfModel(k) {
                const v = repStep.valueOfModel(k);
                return typeof v === "string" ? v : "";
            }

            function valueOfModel(k) {
                if (modelData === undefined || modelData === null)
                    return "";
                return modelData[k] === undefined ? "" : modelData[k];
            }
        }
    }
}
