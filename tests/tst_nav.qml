import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Nav"
    when: windowShown
    width: 400
    height: 400

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    // ---------------- Tabs ----------------
    // Tabs / TabPane / TabItem 的用例在 tests/tst_tabs.qml：那一对的 prop 面是官方
    // TabsProps（26 条）/ TabPaneProps，四档 type × 三档 size × 两档 tabPosition 的几何与颜色、
    // 两条数据来源、激活位三条来源、键盘五条上游口径、折叠与 more 都在那边逐条断。
    // 这里原先那三条走的是旧自造面（tabs:[{text}] / currentIndex / card: bool / barHeight 50），
    // 整批删掉 —— 其中「large 档 barHeight 50」与官方实测的 52 就不一致。

    // ---------------- Steps ----------------
    // Steps / Step 的用例在 tests/tst_steps.qml：那一对的 prop 面是官方 StepsProps /
    // FillStepProps（三档 type 共用一份），分派、状态推导、initial 与那条裸 index 门禁都在那边逐条断。

    // ---------------- List ----------------
    // List / ListItem 的用例在 tests/tst_list.qml：那一对组件的 prop 面是官方
    // ListProps / ListItemProps，几何、四段结构、栅格与点击转发都在那边逐条断。

    // Descriptions / DescriptionsItem 的用例在 tests/tst_descriptions.qml：那一对的 prop 面是
    // 官方 DescriptionsProps / DescriptionsItemProps，四档 align、两种 layout、双行三档与
    // span 分组都在那边逐条断。

    // ---------------- Collapse ----------------

    function test_collapsePanelToggle() {
        const panel = make('CollapsePanel { title: "标题" }')
        compare(panel.expanded, false)
        panel.requestExpand()
        compare(panel.expanded, true)
        panel.requestExpand()
        compare(panel.expanded, false)
        panel.destroy()
    }

    function test_collapsePanelDisabledIgnoresToggle() {
        const panel = make('CollapsePanel { title: "标题"; disabled: true }')
        panel.requestExpand()
        compare(panel.expanded, false)
        panel.destroy()
    }

    function test_collapseAccordionCollapsesOthers() {
        const collapse = make(`
            Collapse {
                accordion: true
                CollapsePanel { id: p1; title: "一"; expanded: true }
                CollapsePanel { id: p2; title: "二" }
                CollapsePanel { id: p3; title: "三" }
            }`)

        const panels = [];
        for (let i = 0; i < collapse.children.length; ++i) {
            if (collapse.children[i].expanded !== undefined)
                panels.push(collapse.children[i]);
        }
        compare(panels.length, 3)
        compare(panels[0].expanded, true)

        // 展开第二个，其余应收起
        panels[1].requestExpand()
        compare(panels[1].expanded, true)
        compare(panels[0].expanded, false)
        compare(panels[2].expanded, false)
        collapse.destroy()
    }

    function test_collapseNonAccordionKeepsOthers() {
        const collapse = make(`
            Collapse {
                CollapsePanel { title: "一"; expanded: true }
                CollapsePanel { title: "二" }
            }`)

        const panels = [];
        for (let i = 0; i < collapse.children.length; ++i) {
            if (collapse.children[i].expanded !== undefined)
                panels.push(collapse.children[i]);
        }

        panels[1].requestExpand()
        compare(panels[1].expanded, true)
        compare(panels[0].expanded, true)   // 非手风琴模式互不影响
        collapse.destroy()
    }
}
