import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Icon"
    when: windowShown
    width: 200
    height: 200

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function icon(props) {
        return Qt.createQmlObject(
            "import Semi; Icon { " + (props || "") + " }", testCase, "icon")
    }

    function test_sourceIsBuiltFromName() {
        const i = icon('name: "plus"')
        compare(i.source.toString(), "qrc:/qt/qml/Semi/icons/plus.svg")
        i.destroy()
    }

    function test_emptyNameHasNoSource() {
        const i = icon("")
        compare(i.source.toString(), "")
        compare(i.visible, false)
        i.destroy()
    }

    function test_defaultSizeAndColor() {
        const i = icon('name: "plus"')
        compare(i.implicitWidth, Theme.current.widthIconMedium)   // 16
        compare(i.implicitHeight, Theme.current.widthIconMedium)
        compare(i.color.toString(), Theme.current.colorText0.toString())
        i.destroy()
    }

    function test_explicitSizeIsUsed() {
        const i = icon('name: "plus"; size: 24')
        compare(i.implicitWidth, 24)
        compare(i.implicitHeight, 24)
        i.destroy()
    }

    function test_colorFollowsTheme() {
        const i = icon('name: "delete"; color: Theme.current.colorDanger')
        compare(i.color.toString(), "#f93920")

        Theme.mode = Theme.Dark
        verify(i.color.toString() !== "#f93920", "图标颜色应随主题变")
        i.destroy()
    }

    // 图标资源确实在 qrc 里 —— 加载失败时 Image 的 status 会是 Error
    function test_resourceIsReachable() {
        const probe = Qt.createQmlObject(
            'import QtQuick; Image { source: "qrc:/qt/qml/Semi/icons/plus.svg"; visible: false }',
            testCase, "probe")
        tryCompare(probe, "status", Image.Ready)
        probe.destroy()
    }
}
