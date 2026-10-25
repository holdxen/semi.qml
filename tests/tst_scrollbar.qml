import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "ScrollBar"

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml, parent) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml,
            parent !== undefined ? parent : testCase, "probe");
    }

    function findScrollBar(item) {
        for (let i = 0; i < item.children.length; ++i) {
            const child = item.children[i];
            if (child.thumbLength !== undefined)
                return child;
            const found = testCase.findScrollBar(child);
            if (found !== null)
                return found;
        }
        return null;
    }

    function makeHost(contentHeight) {
        return make("Item {"
            + " width: 200; height: 100;"
            + " Flickable { id: view; anchors.fill: parent; contentHeight: " + contentHeight + " }"
            + " SemiScrollBar { id: bar; flickable: view; orientation: Qt.Vertical;"
            + "   anchors.right: parent.right; anchors.top: parent.top;"
            + "   anchors.bottom: parent.bottom; width: 8 }"
            + " }")
    }

    function test_thumbLength() {
        const host = makeHost(400)
        wait(50)

        const bar = testCase.findScrollBar(host)
        verify(bar !== null)
        compare(bar.contentLength, 400)
        compare(bar.viewLength, 100)
        compare(bar.trackLength, 100)
        compare(bar.needed, true)
        // 视口占内容 1/4，滑块就是轨道的 1/4
        compare(bar.thumbLength, 25)
        compare(bar.thumbPosition, 0)
        host.destroy()
    }

    function test_thumbFollowsScroll() {
        const host = makeHost(400)
        wait(50)

        const bar = testCase.findScrollBar(host)
        const view = host.children[0]

        view.contentY = 150          // 内容位移的一半
        wait(20)
        // 轨道可走 100 - 25 = 75，走一半就是 37.5
        compare(bar.thumbPosition, 37.5)

        view.contentY = 300
        wait(20)
        compare(bar.thumbPosition, 75)   // 贴底
        host.destroy()
    }

    function test_scrollToMovesContent() {
        const host = makeHost(400)
        wait(50)

        const bar = testCase.findScrollBar(host)
        const view = host.children[0]

        bar.scrollTo(0, 37.5)
        compare(view.contentY, 150)

        bar.scrollTo(0, 75)
        compare(view.contentY, 300)

        // 超出范围要钳住
        bar.scrollTo(0, 500)
        compare(view.contentY, 300)
        host.destroy()
    }

    function test_hiddenWhenContentFits() {
        const host = makeHost(50)
        wait(50)

        const bar = testCase.findScrollBar(host)
        compare(bar.needed, false)
        compare(bar.visible, false)
        compare(bar.thumbLength, 0)
        host.destroy()
    }

    function test_horizontalOrientation() {
        const host = make("Item {"
            + " width: 200; height: 100;"
            + " Flickable { id: view; anchors.fill: parent; contentWidth: 800 }"
            + " SemiScrollBar { id: bar; flickable: view; orientation: Qt.Horizontal;"
            + "   anchors.left: parent.left; anchors.right: parent.right;"
            + "   anchors.bottom: parent.bottom; height: 8 }"
            + " }")
        wait(50)

        const bar = testCase.findScrollBar(host)
        compare(bar.vertical, false)
        compare(bar.contentLength, 800)
        compare(bar.viewLength, 200)
        compare(bar.trackLength, 200)
        compare(bar.thumbLength, 50)
        host.destroy()
    }

    function test_minThumbLength() {
        // 内容极长时滑块不至于细成一条
        const host = makeHost(20000)
        wait(50)

        const bar = testCase.findScrollBar(host)
        compare(bar.thumbLength, 24)      // minThumbLength
        host.destroy()
    }

    // ---- 回填检查：三个组件都换成了自绘滚动条 ----

    function test_tableUsesSemiScrollBar() {
        const t = make("Table {"
            + " columns: [{ title: 'n', dataIndex: 'n', width: 200 }];"
            + " dataSource: Array.from({ length: 60 }, (_, i) => ({ n: i }));"
            + " pagination: false; scroll: ({ y: 300 }) }")
        t.width = 600
        wait(100)

        const bar = testCase.findScrollBar(t)
        verify(bar !== null)
        verify(bar.flickable !== null)
        compare(bar.needed, true)
        t.destroy()
    }

    function test_scrollListUsesSemiScrollBar() {
        const s = make("ScrollList { width: 240; bodyHeight: 120;"
            + " ScrollItem { mode: 'normal'; list: [{value: 1}, {value: 2}, {value: 3},"
            + " {value: 4}, {value: 5}, {value: 6}, {value: 7}] } }")
        wait(100)

        const bar = testCase.findScrollBar(s)
        verify(bar !== null)
        verify(bar.flickable !== null)
        compare(bar.needed, true)
        s.destroy()
    }

    function test_calendarTimelineUsesSemiScrollBar() {
        const c = make("Calendar { mode: 'week'; displayValue: new Date(2026, 9, 8) }")
        c.width = 800
        c.height = 400
        wait(100)

        const bar = testCase.findScrollBar(c)
        verify(bar !== null)
        verify(bar.flickable !== null)
        // 时间轴内容 1440px，视口装不下
        compare(bar.needed, true)
        c.destroy()
    }
}
