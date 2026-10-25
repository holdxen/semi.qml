import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Extras"

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml, parent) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml,
            parent !== undefined ? parent : testCase, "probe");
    }

    function findBy(root, prop) {
        for (let i = 0; i < root.children.length; ++i) {
            const child = root.children[i];
            if (child[prop] !== undefined)
                return child;
            const found = testCase.findBy(child, prop);
            if (found !== null)
                return found;
        }
        return null;
    }

    // ---------------- BackTop ----------------
    // 那三条旧用例（可见性 / 滚回顶部 / 位置）钉的是自造面（`duration` 缺省 300、
    // `size` / `iconName` 两条官方没有的 prop、命令式 `scrollToTop()` 的信号计数），
    // 2026-10-24 按官方 BackTopProps 重写后一条都不成立 ⇒ 整批搬进 tests/tst_backtop.qml。

    // ---------------- Collapsible ----------------

    function test_collapsibleHeightAnimation() {
        const c = make("Collapsible {"
            + " Rectangle { implicitWidth: 200; implicitHeight: 120 } }")
        wait(50)
        compare(c.fullHeight, 120)
        compare(c.currentHeight, 0)

        c.isOpen = true
        wait(400)
        compare(c.currentHeight, 120)

        c.isOpen = false
        wait(400)
        compare(c.currentHeight, 0)
        c.destroy()
    }

    function test_collapsibleKeepsCollapseHeight() {
        const c = make("Collapsible { collapseHeight: 30 }")
        wait(50)
        compare(c.currentHeight, 30)
        c.destroy()
    }

    function test_collapsibleToggleSignal() {
        const c = make("Collapsible {}")
        const spy = Qt.createQmlObject("import QtTest; SignalSpy { signalName: 'toggled' }",
            testCase, "spy")
        spy.target = c

        c.toggle()
        compare(c.isOpen, true)
        compare(spy.count, 1)

        c.toggle()
        compare(c.isOpen, false)
        compare(spy.count, 2)
        c.destroy()
    }

    function test_collapsibleFadesWhenFullyClosed() {
        const c = make("Collapsible {}")
        wait(50)
        compare(c.opacity, 0)          // 收起且不留高度 → 整体淡出

        c.isOpen = true
        wait(400)
        compare(c.opacity, 1)
        c.destroy()
    }

    // ---------------- FloatButton ----------------

    function test_floatButtonSizes() {
        const f = make("FloatButton { icon: 'plus' }")
        compare(f.side, 32)
        f.size = Enums.Small
        compare(f.side, 24)
        f.size = Enums.Large
        compare(f.side, 40)
        f.destroy()
    }

    function test_floatButtonPosition() {
        const host = make("Item { width: 300; height: 200;"
            + " FloatButton { rightMargin: 24; bottomMargin: 24 } }")
        wait(50)
        const f = testCase.findBy(host, "rightMargin")
        verify(f !== null)
        compare(f.x, 300 - 32 - 24)
        compare(f.y, 200 - 32 - 24)
        host.destroy()
    }

    function test_floatButtonDisabled() {
        const f = make("FloatButton { disabled: true }")
        compare(f.disabled, true)
        f.destroy()
    }

    // ---------------- DragMove ----------------

    function test_dragMoveConstrainedToParent() {
        const host = make("Item { width: 300; height: 200;"
            + " DragMove { id: box; width: 80; height: 60 } }")
        wait(50)
        const box = testCase.findBy(host, "constrainToParent")
        verify(box !== null)

        box.moveTo(50, 40)
        compare(box.x, 50)
        compare(box.y, 40)

        // 越界会被钳回父容器内
        box.moveTo(500, 400)
        compare(box.x, 220)      // 300 - 80
        compare(box.y, 140)      // 200 - 60

        box.moveTo(-30, -30)
        compare(box.x, 0)
        compare(box.y, 0)
        host.destroy()
    }

    function test_dragMoveWithoutConstraint() {
        const host = make("Item { width: 300; height: 200;"
            + " DragMove { width: 80; height: 60; constrainToParent: false } }")
        wait(50)
        const box = testCase.findBy(host, "constrainToParent")

        box.moveTo(500, 400)
        compare(box.x, 500)
        compare(box.y, 400)
        host.destroy()
    }

    function test_dragMoveSignal() {
        const host = make("Item { width: 300; height: 200;"
            + " DragMove { width: 80; height: 60 } }")
        wait(50)
        const box = testCase.findBy(host, "constrainToParent")

        const spy = Qt.createQmlObject("import QtTest; SignalSpy { signalName: 'moved' }",
            testCase, "spy")
        spy.target = box

        box.moveTo(10, 10)
        compare(spy.count, 1)
        box.moveTo(20, 20)
        compare(spy.count, 2)
        host.destroy()
    }
}
