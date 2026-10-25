import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Misc"
    when: windowShown
    width: 300
    height: 300

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import Semi; " + qml, testCase, "probe")
    }

    // ---------------- Divider ----------------
    // 2026-10-23 按官方 DividerProps 整份重写（补 dashed / align / margin / content 档、
    // 撤掉可写的 lineColor），几何与皮肤用例整批迁进 tests/tst_divider.qml。

    // ---------------- TextArea ----------------

    function test_textAreaAutoSize() {
        // 官方 rows 默认 4；高度 = 行数 × 行高 + 上下 padding 各 5 + 描边各 1。
        // 行高取 Qt 的自然行高（TextEdit 没有 lineHeight），所以断言按组件自己的
        // lineHeightPx 展开，而不是写死像素。
        const fixed = make('TextArea { }')
        compare(fixed.rows, 4)
        compare(fixed.implicitHeight, 4 * fixed.lineHeightPx + 12)

        const auto = make('TextArea { rows: 1; autosize: true }')
        compare(auto.implicitHeight, 1 * auto.lineHeightPx + 12)   // 空内容贴到 minRows=rows
        auto.text = "a\nb\nc"
        compare(auto.implicitHeight, 3 * auto.lineHeightPx + 12)

        const clamped = make('TextArea { autosize: ({ minRows: 1, maxRows: 2 }) }')
        clamped.text = "a\nb\nc\nd"
        compare(clamped.implicitHeight, 2 * clamped.lineHeightPx + 12)   // 超过 maxRows 就夹住
        fixed.destroy(); auto.destroy(); clamped.destroy()
    }

    function test_textAreaUsesInputAppearance() {
        const area = make("TextArea { }")
        compare(area.color.toString(), Theme.current.colorFill0.toString())
        compare(area.border.color.toString(), "#00000000")   // 未聚焦无描边
        area.destroy()
    }

    function test_textAreaFollowsTheme() {
        const area = make("TextArea { }")
        const before = area.color.toString()
        Theme.mode = Theme.Dark
        verify(area.color.toString() !== before, "多行输入底色应随主题变")
        area.destroy()
    }

    // ---------------- Space ----------------
    // 2026-10-23 按官方 SpaceProps 整份重写（补 wrap / align / vertical / spacing 三档），
    // 缺省 spacing 从 number 8 改成官方字符串 "tight"，几何与别名用例整批迁进 tests/tst_space.qml。
}
