import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Controls"
    when: windowShown
    width: 400
    height: 400

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import Semi; " + qml, testCase, "probe")
    }

    // ---------------- ButtonGroup ----------------

    // 成员清单是 relayout() 写进 childItems 的：组根是 Item，按钮都在内层 row 里
    function test_buttonGroupAssignsPositions() {
        const group = make('ButtonGroup { Button { text: "a" } Button { text: "b" } Button { text: "c" } }')
        const buttons = group.childItems
        compare(buttons.length, 3)
        compare(buttons[0].groupPosition, "first")
        compare(buttons[1].groupPosition, "middle")
        compare(buttons[2].groupPosition, "last")
        group.destroy()
    }

    function test_buttonGroupSingleChildIsOnly() {
        const group = make('ButtonGroup { Button { text: "solo" } }')
        const buttons = group.childItems
        compare(buttons.length, 1)
        compare(buttons[0].groupPosition, "only")
        group.destroy()
    }

    function test_buttonRadiiFollowPosition() {
        // 只有首尾保留圆角（Qt 6.7+ 的独立圆角）
        const first = make('Button { text: "f"; groupPosition: "first" }')
        compare(first.topLeftRadius > 0, true)
        compare(first.topRightRadius, 0)
        first.destroy()

        const middle = make('Button { text: "m"; groupPosition: "middle" }')
        compare(middle.topLeftRadius, 0)
        compare(middle.topRightRadius, 0)
        middle.destroy()

        const last = make('Button { text: "l"; groupPosition: "last" }')
        compare(last.topLeftRadius, 0)
        compare(last.bottomRightRadius > 0, true)
        last.destroy()

        const standalone = make('Button { text: "x" }')
        compare(standalone.topLeftRadius > 0, true)
        compare(standalone.topRightRadius > 0, true)
        standalone.destroy()
    }

    // ---------------- SplitButtonGroup ----------------

    // 官方 SplitButtonGroup 只给首尾两个 button 加 -first / -last，其余一概不管
    function test_splitButtonRadii() {
        const split = make('SplitButtonGroup { Button { text: "部署" }'
            + ' Button { icon: "tree_triangle_down" } }')
        const buttons = split.childItems
        compare(buttons.length, 2)
        compare(buttons[0].groupPosition, "first")
        compare(buttons[0].topLeftRadius > 0, true)
        compare(buttons[0].topRightRadius, 0)
        compare(buttons[1].groupPosition, "last")
        compare(buttons[1].topLeftRadius, 0)
        compare(buttons[1].topRightRadius > 0, true)
        split.destroy()
    }

    function test_splitButtonTriggerIsSquare() {
        // 触发按钮是图标按钮，宽高定死成控件高
        const split = make('SplitButtonGroup { Button { text: "部署" }'
            + ' Button { icon: "tree_triangle_down"; size: Enums.Large } }')
        compare(split.childItems[1].implicitWidth, Appearance.buttonHeight(Theme.current, Enums.Large))
        split.destroy()
    }

    function test_splitButtonKeepsPopupMembers() {
        // 菜单是 Popup、不是 Item，不该被当成成员排进位置里
        const split = make('SplitButtonGroup { Button { text: "部署" }'
            + ' Button { icon: "tree_triangle_down" }'
            + ' Dropdown { DropdownItem { text: "编辑" } } }')
        compare(split.childItems.length, 2)
        split.destroy()
    }

    // Empty 的用例在 tst_empty.qml（按官方 EmptyProps 整份重写后单独成篇）。
}
