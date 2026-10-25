import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "InputPro"
    when: windowShown
    width: 400
    height: 400

    property var options: [
        { label: "北京", value: "bj" },
        { label: "上海", value: "sh" },
        { label: "广州", value: "gz" }
    ]

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "probe")
    }

    // ---------------- Select ----------------

    function test_selectLabelLookup() {
        const sel = make("Select { }")
        sel.options = testCase.options
        compare(sel.labelOf("sh"), "上海")
        compare(sel.labelOf("unknown"), "unknown")
        sel.destroy()
    }

    function test_selectDisplayText() {
        const sel = make("Select { }")
        sel.options = testCase.options
        compare(sel.displayText, "")

        sel.value = "bj"
        compare(sel.displayText, "北京")
        sel.destroy()
    }

    function test_selectMultipleDisplay() {
        const sel = make("Select { }")
        sel.options = testCase.options
        sel.multiple = true
        sel.values = ["bj", "gz"]
        compare(sel.displayText, "北京、广州")
        sel.destroy()
    }

    function test_selectChosen() {
        const sel = make("Select { }")
        sel.options = testCase.options
        sel.value = "sh"
        compare(sel.isChosen("sh"), true)
        compare(sel.isChosen("bj"), false)

        sel.multiple = true
        sel.values = ["bj"]
        compare(sel.isChosen("bj"), true)
        compare(sel.isChosen("sh"), false)
        sel.destroy()
    }

    function test_selectChooseTogglesInMultipleMode() {
        const sel = make("Select { }")
        sel.multiple = true
        sel.choose("a")
        compare(sel.values.length, 1)
        sel.choose("a")               // 再点一次取消
        compare(sel.values.length, 0)
        sel.destroy()
    }

    function test_selectSizes() {
        const small = make("Select { size: Enums.Small }")
        const def = make("Select { }")
        compare(small.implicitHeight, 24)
        compare(def.implicitHeight, 32)
        small.destroy(); def.destroy()
    }

    // .semi-select-option-list-wrapper 的上下 padding 各 4、左右 0，
    // 而搜索框就在这个 wrapper 里面 —— 所以 4px 在搜索区**之上**。
    // 原先放成了「搜索区与列表之间 + 底部」，顶部贴边，看着上下不对称。
    // 盯的是那两条占位 Item（objectName 标出），不是弹层总高 —— 总高由 implicitHeight
    // 的公式算，占位漏一条它也不会变，拿它断言会假过。
    function test_selectDropdownInsets() {
        const sel = make("Select { width: 200 }")
        sel.options = ["北京", "上海"]
        sel.open()
        wait(50)
        const kids = sel._popup.contentItem.children
        const top = kids.filter((it) => it.objectName === "listInsetTop")
        const bottom = kids.filter((it) => it.objectName === "listInsetBottom")
        compare(top.length, 1, "顶部缺 4px 内缩")
        compare(bottom.length, 1, "底部缺 4px 内缩")
        compare(top[0].height, Theme.current.spacingExtraTight)
        compare(bottom[0].height, Theme.current.spacingExtraTight)
        // 左右内缩走 wrapper 的 padding，必须是 0
        compare(sel._popup.padding, 0)
        compare(sel._popup.height, 2 * 36 + 2 * Theme.current.spacingExtraTight)
        sel.destroy()
    }

    function test_selectDropdownInsetsWithSearch() {
        const sel = make("Select { width: 200; filter: true }")
        sel.options = ["北京"]
        sel.open()
        wait(50)
        const kids = sel._popup.contentItem.children
        const top = kids.filter((it) => it.objectName === "listInsetTop")
        const search = kids.filter((it) => it.height === 8 + 32 + 8 + 1)
        compare(top.length, 1)
        // 顶部占位必须排在搜索区前面（4px 在搜索区之上）
        verify(kids.indexOf(top[0]) < kids.indexOf(search[0]), "4px 内缩跑到搜索区下面了")
        // 上 4 + 搜索区(8 + 32 + 8 + 1 分隔线) + 列表 36 + 下 4
        compare(sel._popup.height, 4 + (8 + 32 + 8 + 1) + 36 + 4)
        sel.destroy()
    }

    function test_selectFilter() {
        const sel = make("Select { filter: true }")
        sel.options = testCase.options
        compare(sel._filteredOptions.length, 3)

        sel._searchText = "北"
        compare(sel._filteredOptions.length, 1)
        compare(sel._filteredOptions[0]._original.value, "bj")

        sel._searchText = "不存在"
        compare(sel._filteredOptions.length, 0)
        sel.destroy()
    }

    function test_selectFilterFunction() {
        const sel = make("Select { filter: true }")
        sel.options = testCase.options
        sel.filterFunction = function(opt, keyword) {
            return opt.label.indexOf(keyword) >= 0 || opt.value === keyword;
        }
        sel._searchText = "bj"
        compare(sel._filteredOptions.length, 1)
        sel.destroy()
    }

    function test_selectGroupOptions() {
        const groupOpts = [
            { label: "亚洲", children: [{ label: "中国", value: "cn" }, { label: "日本", value: "jp" }] },
            { label: "欧洲", children: [{ label: "德国", value: "de" }] }
        ]
        const sel = make("Select { }")
        sel.options = groupOpts
        // 展平后应该有 2 个组标题 + 3 个选项 = 5 项
        compare(sel._flatOptions.length, 5)
        compare(sel._flatOptions[0]._isGroup, true)
        compare(sel._flatOptions[0].label, "亚洲")
        compare(sel._flatOptions[1]._isGroup, false)
        compare(sel.labelOf("cn"), "中国")
        sel.destroy()
    }

    // 多选标签曾经直接挂在 Item 上（Repeater 不做排布），全部落在 (0,0) 叠成一坨。
    // 这条盯两点：位置必须互不重叠；换行要把触发器撑高（叠着时高度不变）。
    function test_selectMultipleTagsWrapNotStacked() {
        const sel = make("Select { multiple: true; width: 200 }")
        sel.options = [
            { label: "标签甲", value: "a" }, { label: "标签乙", value: "b" },
            { label: "标签丙", value: "c" }, { label: "标签丁", value: "d" }
        ]
        sel.values = ["a", "b", "c", "d"]
        wait(50)

        // Tag 的特征是 readonly int tagHeight，用它把标签挑出来
        const spots = []
        let count = 0
        const stack = [sel]
        while (stack.length > 0) {
            const node = stack.pop()
            for (let i = 0; i < node.children.length; ++i) {
                const c = node.children[i]
                if (c.tagHeight !== undefined && c.text !== undefined && c.visible) {
                    ++count
                    spots.push(c.x + "," + c.y)
                }
                stack.push(c)
            }
        }
        compare(count, 4)
        compare(new Set(spots).size, 4, "标签位置重叠：\n" + spots.join("\n"))
        verify(sel.implicitHeight > sel.triggerHeight,
               "换行后触发器应变高，实际 " + sel.implicitHeight + " <= " + sel.triggerHeight)
        sel.destroy()
    }

    // 弹层被 closePolicy（点外 / Esc）关掉时，Select 必须跟着知道。
    // 曾经 _popupOpen 是自维护的布尔，停在 true 上 —— 之后第一次点击走
    // toggle() 的关闭分支，表现为「要点两次才能重新打开」。
    function test_selectStateFollowsOutsideClose() {
        const sel = make("Select { width: 200 }")
        sel.options = testCase.options
        sel.open()
        wait(50)
        verify(sel._popupOpen, "open() 后应记为已打开")

        // 点弹层以外的空白处，交给 PopupBase 的 CloseOnPressOutside 关闭
        mouseClick(testCase, 10, 380, Qt.LeftButton)
        wait(50)
        verify(!sel._popupOpen, "点外部关掉弹层后，Select 不能再认为它是开着的")

        // 关键：紧接着一次 toggle 就该重新打开
        sel.toggle()
        wait(50)
        verify(sel._popupOpen, "关闭后一次 toggle 必须能重新打开（曾经需要两次）")
        sel.destroy()
    }

    function test_selectMaxTagCount() {
        const sel = make("Select { multiple: true; maxTagCount: 2 }")
        sel.options = testCase.options
        sel.values = ["bj", "sh", "gz"]
        compare(sel._visibleTags.length, 2)
        compare(sel._restCount, 1)
        sel.destroy()
    }

    function test_selectValidateStatus() {
        const sel = make("Select { }")
        compare(sel.validateStatus, Enums.StatusDefault)

        sel.validateStatus = Enums.StatusWarning
        compare(sel.validateStatus, Enums.StatusWarning)

        sel.validateStatus = Enums.StatusDanger
        compare(sel.validateStatus, Enums.StatusDanger)
        sel.destroy()
    }

    function test_selectDefaultValue() {
        const sel = make("Select { defaultValue: 'bj' }")
        sel.options = testCase.options
        compare(sel.value, "bj")
        sel.destroy()
    }

    function test_selectDefaultValues() {
        const sel = make("Select { multiple: true; defaultValues: ['bj', 'sh'] }")
        sel.options = testCase.options
        compare(sel.values.length, 2)
        compare(sel.values[0], "bj")
        sel.destroy()
    }

    function test_selectKeyboardNavigation() {
        const sel = make("Select { filter: true }")
        sel.options = testCase.options
        sel.open()
        compare(sel._highlightIndex, -1)

        sel.highlightNext()
        compare(sel._highlightIndex, 0)

        sel.highlightNext()
        compare(sel._highlightIndex, 1)

        sel.highlightPrev()
        compare(sel._highlightIndex, 0)
        sel.destroy()
    }

    // ---------------- Slider ----------------

    function test_sliderRatio() {
        const s = make("Slider { min: 0; max: 100; value: 40 }")
        compare(s.ratio, 0.4)
        s.value = 0
        compare(s.ratio, 0)
        s.value = 100
        compare(s.ratio, 1)
        s.destroy()
    }

    function test_sliderClampsValue() {
        // 越界时会被钳回范围
        const s = make("Slider { min: 0; max: 10; value: 0 }")
        s.value = 99
        compare(s.value, 10)
        s.value = -5
        compare(s.value, 0)
        s.destroy()
    }

    function test_sliderStepRounding() {
        const s = make("Slider { min: 0; max: 100; step: 10; width: 210 }")
        s.setFromX(105)      // 中点附近
        compare(s.value % 10, 0)
        s.destroy()
    }

    function test_sliderSetFromX() {
        const s = make("Slider { min: 0; max: 100; width: 216 }")
        s.setFromX(8)                       // 最左：手柄中心正好在起点
        compare(s.value, 0)
        s.setFromX(108)                     // 中点
        compare(s.value, 50)
        s.setFromX(208)                     // 最右
        compare(s.value, 100)
        s.setFromX(999)                     // 越界也不出头
        compare(s.value, 100)
        s.destroy()
    }

    // 填充从轨道的最小端画到手柄圆心，到 min 时必须是 0。
    // 早先的写法无条件加 handleSize/2，到 0 还剩 8px —— 手柄是圆，圆在轨道
    // 左端的切点盖不住那 8px 的左圆角，于是「拖到最左边还突出一小块」。
    // 现在手柄圆心沿整条轨道行走（railStart=8、railLength=width-16），
    // 到 min 时圆心正好落在轨道起点，填充天然为 0。
    function test_sliderFillLength() {
        const s = make("Slider { min: 0; max: 100; width: 216; value: 0 }")
        compare(s.handleSize, 24)       // $width-slider_handle
        compare(s.railStart, 13)        // $spacing-slider-paddingX
        compare(s.railLength, 190)
        compare(s.fillLength, 0)
        s.value = 50
        compare(s.fillLength, 95)       // 从 13 画到圆心 108
        compare(s.fillFrom, 13)
        s.value = 100
        compare(s.fillLength, 190)
        s.destroy()
    }

    // 双滑块：填充画在两个圆心之间，拖一个不许越过另一个
    function test_sliderRange() {
        const s = make("Slider { min: 0; max: 100; width: 216; range: true; values: [20, 60] }")
        compare(s.lowValue, 20)
        compare(s.highValue, 60)
        // 填充从低值圆心到高值圆心：13+0.2*190=51 → 13+0.6*190=127
        compare(s.fillFrom, 51)
        compare(s.fillLength, 76)

        // 值反着传也认（内部按大小当低/高）
        s.values = [70, 30]
        compare(s.lowValue, 30)
        compare(s.highValue, 70)

        // 拖高值端：越过低值就被夹住
        s.values = [20, 60]
        s.applyAxisPos(208, 1)
        compare(s.highValue, 100)
        s.applyAxisPos(0, 1)
        compare(s.highValue, 20)        // 不会越过 lowValue
        compare(s.lowValue, 20)

        // 拖低值端同理
        s.values = [20, 60]
        s.applyAxisPos(208, 0)
        compare(s.lowValue, 60)
        s.destroy()
    }

    function test_sliderRangeIncluded() {
        const s = make("Slider { min: 0; max: 100; width: 216; range: true; values: [20, 60] }")
        compare(s.fillLength, 76)
        s.included = false
        compare(s.fillLength, 0)        // 官网上「分段背景」那种用法：轨道不着色
        s.destroy()
    }

    // 垂直：默认上小下大（min 在上），verticalReverse 反过来
    function test_sliderVertical() {
        const s = make("Slider { min: 0; max: 100; width: 16; height: 216; vertical: true; value: 30 }")
        compare(s.axisLength, 216)
        compare(s.railStart, 13)
        compare(s.axisPosOf(0), 13)             // min 在上
        compare(s.axisPosOf(100), 203)          // max 在下
        compare(s.axisPosOf(30), 70)            // 13 + 0.3*190
        s.setFromY(108)
        compare(s.value, 50)

        s.verticalReverse = true
        compare(s.axisPosOf(0), 203)            // 反过来：min 在下
        compare(s.axisPosOf(100), 13)
        s.value = 30
        compare(s.axisPosOf(30), 146)           // 203 - 0.3*190
        s.destroy()
    }

    // 刻度：只收落在 [min, max] 里的，label 缺省用值本身
    function test_sliderMarks() {
        const s = make('Slider { min: 0; max: 100; width: 216; marks: ['
            + '{ value: 0, label: "起点" }, { value: 50 }, { value: 150, label: "超范围" }] }')
        compare(s.markList.length, 2)           // 150 那项被丢掉
        compare(s.markList[0].label, "起点")
        compare(s.markList[1].label, "50")      // 没给 label 就用值
        compare(s.markList[1].pos, 108)         // 8 + 0.5*200
        s.showMarkLabel = false
        compare(s.marksHeight, 10)              // 只剩点，占的高度小
        s.marks = []
        compare(s.marksHeight, 0)
        s.destroy()
    }

    // 刻度标签不能压在轨道上。
    //
    // 轨道与手柄只在「手柄那一行」里居中；刻度是排在手柄之外的，会把组件撑高。
    // 早先拿整个组件的高度去居中轨道，于是加了刻度之后轨道中心下移、
    // 和标签叠在一起（表现是文字压在滑动条上）。
    function test_sliderMarksClearOfRail() {
        const s = make('Slider { min: 0; max: 100; width: 216; value: 40; '
            + 'marks: [{ value: 0, label: "0" }, { value: 50, label: "50" }] }')
        compare(s.rail.y, s.handleRowCenter - s.trackHeight / 2)   // 12 - 2 = 10
        // 刻度挂在手柄下方（手柄比轨道高得多，照轨道算会让标签压到滑块上）
        compare(s.marksTop, s.handleRowCenter + s.handleSize / 2 + s.markGap)   // 12 + 12 + 5
        compare(s.marksTop >= s.rail.y + s.trackHeight + 5, true)
        compare(s.marksTop >= s.handleRowCenter + s.handleSize / 2 + 5, true)
        // 没有刻度时组件高度就只有手柄那一行
        s.marks = []
        compare(s.implicitHeight, s.handleSize)
        s.destroy()
    }

    // railContent 里的东西挂在轨道上（对应 Semi 的 railStyle），坐标是轨道局部坐标。
    // 给「分段背景」那种要跟着手柄画底色的场景用 —— 比绑定的渐变省得多
    // （见 PROGRESS 已知坑 40）。
    function test_sliderRailContent() {
        const s = make('Slider { min: 0; max: 100; width: 216; value: 40;'
            + ' railContent: [ Rectangle { width: 10; height: 4; color: "#ff0000" } ] }')
        compare(s.railContent.length, 2)     // 已填充那块 + 外面塞进来的那块
        compare(s.rail.children.length, 2)
        s.destroy()
    }

    // 禁用态：填充是 primary-disabled（Semi 的 $color-slider_track_disabled-bg，
    // 也就是 blue-2 那档浅蓝），不是通用的 disabledBg；手柄同时失去投影
    // （Semi 在 -disabled 下把 shadow-knob 换成了 shadow-0）。
    function test_sliderDisabledLook() {
        const s = make("Slider { min: 0; max: 100; width: 216; value: 40 }")
        const fill = s.rail.children[0] as Rectangle     // 轨道里那个「已填充」
        compare(fill.color.toString(), Theme.current.colorPrimary.toString())

        // 只数「真的在画投影」的精灵（第二个在单值模式下不可见，禁用时两个都不可见）
        function activeShadows(item) {
            let n = 0
            const kids = item.children
            for (let i = 0; i < kids.length; ++i) {
                // qmllint disable missing-property
                if (kids[i].sourceRect !== undefined && kids[i].visible)
                    n++
                // qmllint enable missing-property
            }
            return n
        }
        compare(activeShadows(s), 1)

        s.enabled = false
        compare(fill.color.toString(), Theme.current.colorPrimaryDisabled.toString())
        compare(activeShadows(s), 0)                     // 禁用态没有投影
        // -disabled 的描边是 shadow-0 换来的：投影没了，1px colorBorder 才有（slider.scss:88）
        compare((s.handle as Rectangle).border.width, 1)
        s.destroy()
    }

    // 手柄投影的两层参数是**实测标定**出来的（理由写在 Slider.qml 那段注释里）：Qt 的
    // blurMax 不是 CSS 的 blur radius，照抄 6px / 1px 会渲成一圈边缘发硬的光晕。
    // 这里把标定结果钉住，谁改回去就该看见这条红。
    function test_sliderShadowLayersAreCalibrated() {
        const s = make("Slider { min: 0; max: 100; width: 216; value: 40 }")
        const layers = []
        function walk(item) {
            const kids = item.children
            for (let i = 0; i < kids.length; ++i) {
                const k = kids[i]
                // qmllint disable missing-property
                if (k.shadowEnabled !== undefined)
                    layers.push(k)
                walk(k)
                // qmllint enable missing-property
            }
        }
        walk(s)
        compare(layers.length, 2)                        // 一个 MultiEffect 只出一层投影

        let soft = null
        let ring = null
        for (let i = 0; i < layers.length; ++i) {
            // qmllint disable missing-property
            if (layers[i].shadowVerticalOffset === 4)
                soft = layers[i]
            else
                ring = layers[i]
            // qmllint enable missing-property
        }
        verify(soft !== null && ring !== null)
        compare(soft.blurMax, 20)                        // CSS 0 4px 6px
        compare(soft.shadowBlur, 1.0)
        fuzzyCompare(soft.shadowColor.a, 0.1, 0.001)
        compare(ring.blurMax, 1)                         // CSS 0 0 1px
        compare(ring.shadowBlur, 0.5)
        fuzzyCompare(ring.shadowColor.a, 0.3, 0.001)
        s.destroy()
    }

    // 手柄的描边只在**按下**时换成焦点色（Semi 的 -handle-clicked：
    // `border: solid 1px $color-slider_handle-border-focus`）。
    // 悬停态 Semi 是 `background-color: white`，也就是没有视觉变化。
    // 早先我们把这圈蓝挂在了 hover 上，鼠标一划过手柄就出现蓝圈。
    function test_sliderHandleBorderFollowsPress() {
        const s = make("Slider { x: 20; y: 20; width: 216; height: 24; value: 0 }")
        wait(50)
        const handle = s.handle as Rectangle

        compare(handle.border.color.toString(), Theme.current.colorBorder.toString())
        compare(handle.border.width, 0)                  // 静止态官方是 border: none

        // 悬停不许变：Semi 的 hover 是 background-color: white，没有视觉变化
        mouseMove(s, 13, 12)          // 不带按键 = 悬停移动
        wait(100)
        compare(handle.border.color.toString(), Theme.current.colorBorder.toString())
        compare(handle.border.width, 0)

        mousePress(s, 108, 12, Qt.LeftButton)
        wait(20)
        mouseMove(s, 168, 12, 20, Qt.LeftButton)   // 超过拖拽阈值，让 DragHandler 拿到抓取
        wait(20)
        compare(handle.border.color.toString(), Theme.current.colorFocusBorder.toString())
        compare(handle.border.width, 1)

        mouseRelease(s, 168, 12, Qt.LeftButton)
        wait(30)
        compare(handle.border.color.toString(), Theme.current.colorBorder.toString())
        compare(handle.border.width, 0)
        s.destroy()
    }

    // 投影精灵必须排在刻度标签**之前**（官方 DOM 里 marks 的 label 在 handle 后面，
    // 阴影盖不到文字）。把那个 Repeater 挪回投影之前，这条立刻红。
    function test_sliderShadowStaysUnderMarkLabels() {
        const s = make('Slider { min: 0; max: 100; width: 216; value: 40;'
            + ' marks: [{ value: 40, label: "四十" }] }')
        wait(50)
        let sprite = -1
        let label = -1
        const kids = s.children
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i].sourceRect !== undefined && sprite < 0)
                sprite = i
            if (kids[i].text === "四十")
                label = i
            // qmllint enable missing-property
        }
        verify(sprite >= 0)
        verify(label >= 0)
        verify(label > sprite)          // children 的顺序就是绘制顺序（z 相同）
        s.destroy()
    }

    // 点击轨道跳值（走 TapHandler，端到端）
    function test_sliderClickTrackJumps() {
        const s = make("Slider { x: 20; y: 20; width: 216; height: 24; value: 0 }")
        wait(50)
        mouseClick(s, 108, 12, Qt.LeftButton)
        compare(s.value, 50)
        s.destroy()
    }

    // 落点归属：手柄是 24×24 的方块（$width-slider_handle），点在里面归手柄，
    // 点在外面才归轨道（归轨道时才是「最近优先、平手取低值端」）。
    // 圆心 51 / 127 → 低值端方块 [39,63]、高值端 [115,139]。
    function test_sliderPressHandleUsesHandleRects() {
        const s = make("Slider { min: 0; max: 100; width: 216; range: true; values: [20, 60] }")
        compare(s.axisPosOf(20), 51)
        compare(s.axisPosOf(60), 127)
        compare(s.onHandle(50), true)           // 低值手柄里
        compare(s.onHandle(120), true)          // 高值手柄里
        compare(s.onHandle(89), false)          // 两颗中间的空档 = 轨道
        compare(s.pressHandle(50), 0)
        compare(s.pressHandle(120), 1)
        compare(s.pressHandle(89), 0)           // 平手（38 / 38）取低值端
        compare(s.pressHandle(100), 1)          // 离高值端近（49 / 27）
        s.destroy()
    }

    // 两颗叠在一起时，抓取归**上一次拖过来的那颗**（官方靠 z-index 层叠：
    // 上次按下的那颗 z-index 2 且松手不降回去，见 src/Slider.qml 的 pressHandle 注释）。
    //
    // 端到端拖一下。QTest 的一次 mouseMove 只把「最后一个位置」送进来，
    // 而 DragHandler 要下一帧才激活 —— 所以第一次 move 只负责把它推激活
    // （那一下的位置是「未激活」时收到的，被 handleDragPosition 挡掉、不改值），
    // 第二次 move 才对应真机上「激活之后的下一个 move」，值才会跟着走。
    // PROGRESS.md 里说拖动「值跟着走」这一半测不了，缺的就是这第二次 move。
    function dragSlider(item, fromPos, toPos) {
        mousePress(item, fromPos, 12, Qt.LeftButton)
        wait(20)
        mouseMove(item, fromPos + (toPos > fromPos ? 15 : -15), 12, 10, Qt.LeftButton)
        wait(40)
        mouseMove(item, toPos, 12, 10, Qt.LeftButton)
        wait(40)
        mouseRelease(item, toPos, 12, Qt.LeftButton)
        wait(20)
    }

    function test_sliderOverlapKeepsLastDraggedHandle() {
        const s = make("Slider { x: 20; y: 20; min: 0; max: 100; width: 216; height: 24;"
            + " range: true; values: [20, 60] }")
        wait(50)

        // 把高值端一路拖到低值端上（127 → 51）
        dragSlider(s, 127, 51)
        compare(s.lowValue, 20)
        compare(s.highValue, 20)
        compare(s.dragHandle, 1)

        // 再按在这对重叠的手柄上往右拖：动的必须是高值端，低值端留在 20。
        // 早先这里按「最近」挑、平手归低值端，于是低值端被夹在 highValue 上纹丝不动
        // （a = min(50, 20) = 20），表现就是「重叠的手柄只能先往左分离、再拖右边那颗」。
        dragSlider(s, 51, 108)
        compare(s.lowValue, 20)
        compare(s.highValue, 50)
        s.destroy()
    }

    // 反方向同理：把低值端拖到高值端上，再往左拖分开的也是低值端
    function test_sliderOverlapKeepsLastDraggedHandleLowSide() {
        const s = make("Slider { x: 20; y: 20; min: 0; max: 100; width: 216; height: 24;"
            + " range: true; values: [20, 60] }")
        wait(50)

        dragSlider(s, 51, 127)
        compare(s.lowValue, 60)
        compare(s.highValue, 60)
        compare(s.dragHandle, 0)

        dragSlider(s, 127, 89)
        compare(s.lowValue, 40)        // (89-13)/190*100 = 40
        compare(s.highValue, 60)
        s.destroy()
    }

    // 谁也没拖过时，官方层叠结果是 max 在上（DOM 里 max 排在 min 之后），
    // 所以初始重叠也归高值端
    function test_sliderOverlapBeforeAnyDragGrabsHighHandle() {
        const s = make("Slider { x: 20; y: 20; min: 0; max: 100; width: 216; height: 24;"
            + " range: true; values: [50, 50] }")
        wait(50)
        compare(s.axisPosOf(50), 108)
        dragSlider(s, 108, 146)
        compare(s.lowValue, 50)
        compare(s.highValue, 70)       // (146-13)/190*100 = 69.9 → 70
        s.destroy()
    }

    // 合上过一次之后低值端还得照常能拖：抓取归属只是「谁在上面」，不是把另一颗锁死
    function test_sliderOverlapThenSeparatesBothWays() {
        const s = make("Slider { x: 20; y: 20; min: 0; max: 100; width: 216; height: 24;"
            + " range: true; values: [20, 60] }")
        wait(50)
        dragSlider(s, 127, 51)         // 合到 20
        compare(s.highValue, 20)
        dragSlider(s, 51, 108)         // 上层那颗（高值端）拖到 50
        compare(s.highValue, 50)
        dragSlider(s, 51, 33)          // 低值端圆心 51 → 拖到 33 → (33-13)/190*100 = 10.5 → 11
        compare(s.lowValue, 11)
        compare(s.highValue, 50)
        s.destroy()
    }

    // 重合时绘制层叠跟 dragHandle 走：上次按下的那颗 z=1，另一颗 z=0。
    // 投影精灵必须跟着手柄抬，否则上层那颗的影子会沉到下面那颗底下。
    function test_sliderOverlapRaisesPressedHandleZ() {
        const s = make("Slider { x: 20; y: 20; min: 0; max: 100; width: 216; height: 24;"
            + " range: true; values: [20, 60] }")
        wait(50)

        // 缺省 dragHandle=1：谁也没拖过时高值端在上（官方 DOM 里 max 后画）
        compare(s.dragHandle, 1)
        compare(s.handleEnd.z, 1)
        compare(s.handle.z, 0)

        // 把高值端拖合到低值端上：仍归高值端，层叠不变
        dragSlider(s, 127, 51)
        compare(s.dragHandle, 1)
        compare(s.handleEnd.z, 1)
        compare(s.handle.z, 0)

        // 直接改归属（等价 pressHandle 选中低值端）：z 要立刻翻过来
        s.dragHandle = 0
        compare(s.handle.z, 1)
        compare(s.handleEnd.z, 0)
        s.dragHandle = 1
        compare(s.handle.z, 0)
        compare(s.handleEnd.z, 1)

        // 投影精灵与手柄同步抬（顺序：先画的跟低值端、后画的跟高值端）
        const sprites = []
        const kids = s.children
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i].sourceRect !== undefined)
                sprites.push(kids[i])
            // qmllint enable missing-property
        }
        compare(sprites.length, 2)
        s.dragHandle = 0
        compare(sprites[0].z, 1, "低值端上层时它的投影也要跟着抬")
        compare(sprites[1].z, 0)
        s.dragHandle = 1
        compare(sprites[0].z, 0)
        compare(sprites[1].z, 1)
        s.destroy()
    }

    // 按在手柄上时，手柄带着「按下点离圆心的差」跟随指针，不会跳到指针底下
    // （官方 _dragOffset，foundation.ts:514-522）
    function test_sliderHandlePressKeepsGrabOffset() {
        const s = make("Slider { x: 20; y: 20; min: 0; max: 100; width: 216; height: 24; value: 50 }")
        wait(50)
        compare(s.axisPosOf(50), 108)
        mousePress(s, 118, 12, Qt.LeftButton)     // 圆心右 10px，还在 24px 方块里
        wait(20)
        compare(s.value, 50)                      // 按下本身不改值
        mouseMove(s, 133, 12, 10, Qt.LeftButton)   // 推 DragHandler 激活
        wait(40)
        mouseMove(s, 148, 12, 10, Qt.LeftButton)
        wait(40)
        mouseRelease(s, 148, 12, Qt.LeftButton)
        wait(20)
        // 148 - 10 = 138 → (138-13)/190*100 = 65.8 → 66。少了 dragOffset 这里是 71
        compare(s.value, 66)
        s.destroy()
    }

    // 单击手柄不改值：官方的 handleWrapClick 对「事件来自手柄」直接 return
    // （foundation.ts:774-778），手柄自己只处理 mousedown
    function test_sliderTapOnHandleKeepsValue() {
        const s = make("Slider { x: 20; y: 20; min: 0; max: 100; width: 216; height: 24; value: 50 }")
        wait(50)
        mouseClick(s, 118, 12, Qt.LeftButton)     // 手柄方块内（108 ± 12）
        compare(s.value, 50)
        mouseClick(s, 96, 12, Qt.LeftButton)      // 方块边缘，仍属于手柄
        compare(s.value, 50)
        mouseClick(s, 80, 12, Qt.LeftButton)      // 方块外 → 轨道，跳到最近的手柄
        compare(s.value, 35)                      // (80-13)/190*100 = 35.3 → 35
        s.destroy()
    }

    // 双滑块重叠时，单纯点一下这对手柄不该把低值端拽走；
    // 但点在方块**外**的轨道上仍然要照跳（证明上面那条不是「什么都测不到」）
    function test_sliderTapOnOverlappedHandlesKeepsValues() {
        const s = make("Slider { x: 20; y: 20; min: 0; max: 100; width: 216; height: 24;"
            + " range: true; values: [20, 20] }")
        wait(50)
        compare(s.axisPosOf(20), 51)
        mouseClick(s, 41, 12, Qt.LeftButton)      // 叠着的两颗都在 51 ± 12 里
        compare(s.lowValue, 20)
        compare(s.highValue, 20)
        mouseClick(s, 38, 12, Qt.LeftButton)      // 方块外（差 13px）→ 轨道，低值端跳过来
        compare(s.lowValue, 13)                   // (38-13)/190*100 = 13.2 → 13
        compare(s.highValue, 20)
        s.destroy()
    }

    // 手柄的绘制交给了 MultiEffect（它连投影一起出），而**效果项的可见性不跟着源走**。
    // 单值模式下第二个手柄是隐藏的，它的效果项必须自己跟着关掉 ——
    // 少了这一条，轨道右端会多出一个「幽灵手柄」。
    function test_sliderShadowCountFollowsHandles() {
        const s = make("Slider { min: 0; max: 100; width: 216; value: 40 }")

        // 数「可见的投影精灵」。投影现在是渲一次成纹理再平移的，
        // 结构是「一个底片（MultiEffect）+ 每个手柄一个 ShaderEffectSource」，
        // 所以这里数带 sourceRect 的那种（MultiEffect 没有这个属性）。
        function visibleShadows(item) {
            let n = 0
            const kids = item.children
            for (let i = 0; i < kids.length; ++i) {
                // qmllint disable missing-property
                if (kids[i].sourceRect !== undefined && kids[i].visible)
                    n++
                // qmllint enable missing-property
            }
            return n
        }

        compare(visibleShadows(s), 1)       // 单值：只有一个手柄，也只有一个投影
        s.range = true
        s.values = [20, 60]
        compare(visibleShadows(s), 2)       // 双滑块：两个
        s.range = false
        compare(visibleShadows(s), 1)
        s.destroy()
    }

    // 手柄圆点：缺省 4px 主色，可以整体给或按手柄分别给
    function test_sliderHandleDot() {
        const s = make("Slider { min: 0; max: 100 }")
        compare(s.dotFor(0).size, 4)            // 没给 handleDot 时也有缺省值
        s.handleDot = { size: 6 }
        compare(s.dotFor(0).size, 6)
        compare(s.dotFor(1).size, 6)
        s.handleDot = [{ size: 6 }, { size: 10 }]
        compare(s.dotFor(0).size, 6)
        compare(s.dotFor(1).size, 10)
        s.destroy()
    }

    // 提示：给了 tipFormatter 就用它；显示时机照 Semi 的
    // computeHandleVisibleVal —— showValue 常显，否则只在拖动中显示
    function test_sliderTipFormatter() {
        const s = make('Slider { min: 0; max: 100; value: 45; suffix: "分" }')
        compare(s.formatValue(45), "45分")
        compare(s.bubbleVisible, false)         // 没 showValue 也没 formatter

        s.tipFormatter = function (v) { return v.toFixed(0) + "%" }
        compare(s.formatValue(45), "45%")
        compare(s.bubbleVisible, false)         // 不拖的时候还是不显示
        s.showValue = true
        compare(s.bubbleVisible, true)
        compare(s.bubbleValues.length, 1)
        compare(s.bubbleValues[0], 45)
        s.destroy()
    }

    function test_sliderBoundary() {
        const s = make("Slider { min: 0; max: 100; value: 45 }")
        compare(s.boundaryHeight, 0)
        s.showBoundary = true
        compare(s.boundaryHeight, 20)
        s.destroy()
    }

    // 拖动时的换算只在拖动进行中生效。
    //
    // handlerPoint 的 x/y 在「点被松开之后」以及「抓取被别的 handler 抢走之后」
    // 会被复位成 0，而那次复位同样会触发 onCentroidChanged —— 早先 Slider 直接
    // 用 centroid.position 换算，于是松手那一下把值算成了 min，
    // 表现是「怎么拖最后都变成 0」。这条盯住 active=false 时不许改值。
    function test_sliderIgnoresDragPositionWhenInactive() {
        const s = make("Slider { min: 0; max: 100; width: 216; value: 0 }")
        // 不活跃时的位置通知必须丢掉：少了这道闸，下面两次会把值推成 100
        s.handleDragPosition(false, 0)
        compare(s.value, 0)
        s.handleDragPosition(false, 999)
        compare(s.value, 0)
        // 活跃时照常换算
        s.handleDragPosition(true, 108)
        compare(s.value, 50)
        s.handleDragPosition(true, 208)
        compare(s.value, 100)
        s.destroy()
    }

    // Rating 的回归测试在 tst_rating.qml（对齐官方属性面后单独成篇）。
}
