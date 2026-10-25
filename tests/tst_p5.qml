import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "P5"

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    // ---------------- Pagination ----------------
    // Pagination 在 2026-10-22 那一轮按官方 PaginationProps 整份重做：`current` /
    // `pageCount` / `pageItems()` / `goTo()` 那套自造面全撤（官方没有钳位，翻页靠
    // prevDisabled / nextDisabled 挡），`showTotal` 缺省也回到 false。
    // 覆盖都在 tests/tst_pagination.qml，这里不再留钉子。

    // ---------------- Tree ----------------
    // Tree 在 2.66 那一轮按官方 TreeProps 整份重做：身份换成 key、`checkable` /
    // `nodeChecked` / `selectedKeys` / `visibleNodes` 这几条自造面全撤。
    // 深度覆盖都在 tests/tst_tree.qml，这里只留一只冒烟钉子。

    function test_treeSmoke() {
        const t = make("Tree { }")
        t.treeData = [
            { key: "p", label: "父", children: [{ key: "c", label: "子" }] },
            { key: "s", label: "独" }
        ]
        compare(t.rowKeys(), ["p", "s"])
        t.requestExpand("p")
        wait(300)                 // 展开动画收完再量，同 tst_tree.qml 的 settle
        compare(t.rowKeys(), ["p", "c", "s"])
        t.handleNodeSelect("c")
        compare(t.selectedListView, ["c"])
        t.destroy()
    }
}
