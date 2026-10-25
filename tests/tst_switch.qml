import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Switch"
    when: windowShown
    width: 400
    height: 300

    Component {
        id: switchComponent
        Switch {}
    }

    SignalSpy {
        id: toggledSpy
        signalName: "toggled"
    }

    function init() {
        // 根项读到的 effectiveVisible 在窗口 show 后不会立即刷新，
        // 不重新置位的话测试项不可见，合成鼠标事件会被直接丢弃
        testCase.visible = true
        toggledSpy.clear()
    }

    function test_togglesOnTap() {
        const control = createTemporaryObject(switchComponent, testCase, { x: 10, y: 10 })
        verify(control, "Switch 创建失败")
        compare(control.checked, false)

        toggledSpy.target = control

        mouseClick(control)
        compare(control.checked, true)
        compare(toggledSpy.count, 1)

        mouseClick(control)
        compare(control.checked, false)
        compare(toggledSpy.count, 2)
    }

    function test_disabledDoesNotToggle() {
        const control = createTemporaryObject(switchComponent, testCase, {
            x: 10,
            y: 60,
            enabled: false
        })
        verify(control, "Switch 创建失败")

        toggledSpy.target = control
        mouseClick(control)
        compare(control.checked, false)
        compare(toggledSpy.count, 0)
    }

    function test_stateFollowsPointer() {
        const control = createTemporaryObject(switchComponent, testCase, { x: 10, y: 10 })
        verify(control, "Switch 创建失败")

        compare(control.controlState, Enums.Normal)
        compare(control.knobExpanded, false)

        // 悬停只换背景色（&:hover），不加宽
        mouseMove(control, control.width / 2, control.height / 2)
        compare(control.controlState, Enums.Hovered)
        compare(control.knobExpanded, false)

        // 按下才走 :active 的加宽（knobExpanded）
        mousePress(control, control.width / 2, control.height / 2)
        compare(control.controlState, Enums.Pressed)
        compare(control.knobExpanded, true)
        mouseRelease(control, control.width / 2, control.height / 2)

        control.destroy()
    }

    function test_disabledStateWins() {
        const control = createTemporaryObject(switchComponent, testCase, {
            x: 10, y: 10, enabled: false
        })
        verify(control, "Switch 创建失败")
        mouseMove(control, control.width / 2, control.height / 2)
        compare(control.controlState, Enums.Disabled)
        control.destroy()
    }

    function test_loadingIgnoresPointer() {
        const control = createTemporaryObject(switchComponent, testCase, {
            x: 10, y: 10, loading: true
        })
        verify(control, "Switch 创建失败")

        toggledSpy.target = control
        mouseClick(control)
        compare(control.checked, false)
        compare(toggledSpy.count, 0)
        // 加载态下 hover 也不换态（官网 loading 时把 input 一起禁了）
        mouseMove(control, control.width / 2, control.height / 2)
        compare(control.controlState, Enums.Normal)
        control.destroy()
    }

    // $width-switch_spin-* 与 $spacing-switch_spin_*-translateX
    function test_spinGeometry_data() {
        return [
            { tag: "small", size: Enums.Small, side: 10, uncheckedX: 2, checkedX: 10 },
            { tag: "default", size: Enums.Default, side: 18, uncheckedX: 2, checkedX: 16 },
            { tag: "large", size: Enums.Large, side: 28, uncheckedX: 2, checkedX: 22 }
        ]
    }

    function test_spinGeometry(data) {
        const control = createTemporaryObject(switchComponent, testCase, { x: 10, y: 10, size: data.size })
        verify(control, "Switch 创建失败")
        compare(control.spinSize, data.side)
        compare(control.spinTranslateX, data.uncheckedX)
        control.checked = true
        compare(control.spinTranslateX, data.checkedX)
        // Spin 垂直居中，上下留白要能装进轨道
        verify(control.trackHeight >= data.side, "Spin 比轨道还高")
        control.destroy()
    }

    // variables.scss：$spacing-switch_*-translateX、$width-switch_knob_*、*_padding、*_expand
    function test_knobGeometry_data() {
        return [
            { tag: "small", size: Enums.Small, unchecked: 1, checked: 11, knob: 12,
              padding: 1, expand: 2 },
            { tag: "default", size: Enums.Default, unchecked: 2, checked: 18, knob: 18,
              padding: 2, expand: 6 },
            { tag: "large", size: Enums.Large, unchecked: 3, checked: 26, knob: 24,
              padding: 3, expand: 10 }
        ]
    }

    function test_knobGeometry(data) {
        const control = createTemporaryObject(switchComponent, testCase, { x: 10, y: 10, size: data.size })
        verify(control, "Switch 创建失败")
        compare(control.travelUnchecked, data.unchecked)
        compare(control.travelChecked, data.checked)
        compare(control.knobSize, data.knob)
        compare(control.knobPadding, data.padding)
        compare(control.knobExpand, data.expand)
        // 圆钮上下各留 border(1) + padding，轨道高正好包住
        compare(control.trackHeight, 2 * (control.borderThickness + data.padding) + data.knob)
        control.destroy()
    }
}
