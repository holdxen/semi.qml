import QtQuick
import QtTest
import Semi
import "../src/CssGradient.js" as CssGradient

TestCase {
    id: testCase

    name: "Button"
    when: windowShown
    width: 600
    height: 400

    Component {
        id: buttonComponent
        Button {}
    }

    SignalSpy {
        id: clickedSpy
        signalName: "clicked"
    }

    function init() {
        // 根项读到的 effectiveVisible 在窗口 show 后不会立即刷新，
        // 不重新置位的话测试项不可见，合成鼠标事件会被直接丢弃
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
        clickedSpy.target = null
        clickedSpy.clear()
    }

    function make(qml) {
        const item = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "buttonProbe")
        item.visible = true
        return item
    }

    function findAll(root, name, out) {
        out = out === undefined ? [] : out
        const kids = root.children
        for (let i = 0; i < kids.length; ++i) {
            // qmllint disable missing-property
            if (kids[i].objectName === name)
                out.push(kids[i])
            findAll(kids[i], name, out)
            // qmllint enable missing-property
        }
        return out
    }

    // ---- 默认值：官方 defaultProps 是 type=primary、theme=light、size=default ----

    function test_defaultsMatchOfficial() {
        const button = createTemporaryObject(buttonComponent, testCase, { text: "主要按钮" })
        verify(button, "Button 创建失败")
        compare(button.resolvedTone, Enums.Primary)
        compare(button.resolvedVariant, Enums.Light)
        compare(button.resolvedSize, Enums.Default)
        compare(button.color, Theme.current.colorFill0)
        compare(button.foregroundColor, Theme.current.colorPrimary)
        compare(button.border.width, 0)
        compare(button.height, 32)
    }

    function test_solidVariantIsFilled() {
        const button = createTemporaryObject(buttonComponent, testCase, {
            text: "深色", variant: Enums.Solid
        })
        compare(button.color, Theme.current.colorPrimary)
        compare(button.foregroundColor, Theme.current.colorWhite)
        // 标签是真的用这个前景色画出来的
        compare(findAll(button, "buttonLabel")[0].color, Theme.current.colorWhite)
    }

    function test_textIsExposed() {
        const button = createTemporaryObject(buttonComponent, testCase, { text: "取消" })
        verify(button, "Button 创建失败")
        compare(button.text, "取消")
    }

    // ---- 点击与键盘激活 ----

    function test_clickedOnTap() {
        const button = createTemporaryObject(buttonComponent, testCase, {
            text: "确定", x: 10, y: 10, width: 100, height: 32
        })
        verify(button, "Button 创建失败")
        clickedSpy.target = button
        mouseClick(button)
        compare(clickedSpy.count, 1)
    }

    function test_disabledDoesNotEmitClicked() {
        const button = createTemporaryObject(buttonComponent, testCase, {
            text: "禁用", x: 10, y: 60, width: 100, height: 32, enabled: false
        })
        clickedSpy.target = button
        mouseClick(button)
        compare(clickedSpy.count, 0)
    }

    function test_enterKeyEmitsClicked() {
        const button = createTemporaryObject(buttonComponent, testCase, {
            text: "确定", x: 10, y: 10, width: 100, height: 32
        })
        clickedSpy.target = button
        button.forceActiveFocus()
        keyPress(Qt.Key_Return)
        keyRelease(Qt.Key_Return)
        compare(clickedSpy.count, 1, "Enter 应当激活按钮")
    }

    function test_spaceKeyEmitsClicked() {
        const button = createTemporaryObject(buttonComponent, testCase, {
            text: "确定", x: 10, y: 10, width: 100, height: 32
        })
        clickedSpy.target = button
        button.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(clickedSpy.count, 1, "空格应当激活按钮")
    }

    function test_buttonIsInTabChain() {
        // 官方 Accessibility 一节：Button 的焦点管理与原生 button 一致，可用 Tab 切换。
        // 焦点链本身是 Qt 窗口的事，这里只断言我们声明了参与切换。
        const button = createTemporaryObject(buttonComponent, testCase, { text: "确定" })
        compare(button.activeFocusOnTab, true)
    }

    // ---- 尺寸与几何 ----

    function test_heightsPerSize() {
        const small = createTemporaryObject(buttonComponent, testCase, { size: Enums.Small })
        const large = createTemporaryObject(buttonComponent, testCase, { size: Enums.Large })
        compare(small.implicitHeight, 24)
        compare(large.implicitHeight, 40)
    }

    function test_iconOnlyIsSquareOfControlHeight() {
        // $width-button_iconOnly_* = $height-control-*，不是「两倍高」
        const plain = make('Button { icon: "camera" }')
        compare(plain.iconOnly, true)
        compare(plain.width, 32)
        compare(plain.height, 32)
        const large = make('Button { icon: "camera"; size: Enums.Large }')
        compare(large.width, 40)
        const small = make('Button { icon: "camera"; size: Enums.Small }')
        compare(small.width, 24)
    }

    function test_textOnlyWidthIsContentPlusPadding() {
        const text = make('Button { text: "主要按钮" }')
        const withIcon = make('Button { text: "主要按钮"; icon: "camera" }')
        // 左右各 $spacing-base-tight = 12
        compare(withIcon.implicitWidth - text.implicitWidth, Theme.current.widthIconMedium
            + Theme.current.spacingTight)
        // 官方按钮里图标与文字之间是 $spacing-button_iconOnly_content-marginLeft = 8
        compare(Theme.current.spacingTight, 8)
    }

    function test_iconPositionDoesNotChangeWidth() {
        const left = make('Button { text: "展开选项"; icon: "chevron_down" }')
        const right = make('Button { text: "展开选项"; icon: "chevron_down"; iconPosition: "right" }')
        compare(right.implicitWidth, left.implicitWidth)
        compare(right.iconPosition, "right")
        // 排布也得跟着换位：left 的图标在 x=0，right 的文字在 x=0
        compare(findAll(left, "buttonGlyph")[0].x, 0)
        compare(findAll(right, "buttonLabel")[0].x, 0)
        compare(findAll(right, "buttonGlyphHost")[0].x,
            findAll(right, "buttonLabel")[0].implicitWidth + Theme.current.spacingTight)
    }

    function test_emptyButtonIsJustPadding() {
        const empty = make('Button { }')
        compare(empty.iconOnly, false, "没有图标也没有转圈就不算图标按钮")
        compare(empty.implicitWidth, Theme.current.spacingBaseTight * 2)
    }

    function test_blockFillsParent() {
        const host = make('Item { width: 300; height: 60; Button { block: true; text: "块级" } }')
        compare(host.children[0].width, 300)
        const notBlock = make('Item { width: 300; height: 60; Button { text: "块级" } }')
        verify(notBlock.children[0].width < 300)
    }

    function test_noHorizontalPaddingOnlyOnIconButtons() {
        const both = make('Button { text: "无内边距"; icon: "plus"; noHorizontalPadding: true }')
        const none = make('Button { text: "无内边距"; icon: "plus" }')
        compare(none.implicitWidth - both.implicitWidth, Theme.current.spacingBaseTight * 2)
        const left = make('Button { text: "无内边距"; icon: "plus"; noHorizontalPadding: "left" }')
        compare(none.implicitWidth - left.implicitWidth, Theme.current.spacingBaseTight)
        const array = make('Button { text: "无内边距"; icon: "plus"; noHorizontalPadding: ["left", "right"] }')
        compare(array.implicitWidth, both.implicitWidth)
        const right = make('Button { text: "无内边距"; icon: "plus"; noHorizontalPadding: "right" }')
        compare(none.implicitWidth - right.implicitWidth, Theme.current.spacingBaseTight)
    }

    function test_pressedDoesNotScale() {
        // 官方 transform 令牌是 --semi-transform_scale-none，按下不缩放
        const button = make('Button { text: "确定"; x: 10; y: 10; width: 100; height: 32 }')
        mousePress(button)
        compare(button.scale, 1.0)
        mouseRelease(button)
    }

    // ---- 加载态 ----

    function test_loadingShowsSpinnerAndBlocksClicks() {
        const button = make('Button { text: "保存"; loading: true; x: 10; y: 10; width: 100; height: 32 }')
        compare(button.spinnerShown, true)
        clickedSpy.target = button
        mouseClick(button)
        compare(clickedSpy.count, 0, "加载中不该响应点击")
    }

    function test_disabledBeatsLoading() {
        // index.tsx:34 的 isLoading && !isDisabled
        const button = make('Button { text: "保存"; loading: true; enabled: false }')
        compare(button.spinnerShown, false)
        compare(button.glyphShown, false)
    }

    function test_loadingKeepsIconWhenDisabled() {
        const button = make('Button { text: "删除"; icon: "delete"; loading: true; enabled: false }')
        compare(button.spinnerShown, false)
        compare(button.glyphShown, true, "禁用 + 加载时官方画的是原图标")
    }

    function test_loadingSwapsIconForSpinner() {
        const button = make('Button { text: "保存"; icon: "delete"; loading: true }')
        compare(findAll(button, "buttonGlyph")[0].name, "spin")
        const colorful = make('Button { text: "Colorful"; colorful: true; loading: true }')
        compare(findAll(colorful, "buttonGlyph")[0].name, "ai_loading")
        compare(findAll(colorful, "buttonGlyph")[0].size, Theme.current.widthIconMedium)
    }

    function test_spinnerRotatesInPlace() {
        // Rotation 当普通子对象声明只会落到 resources 里，angle 不进场景图（transform.length === 0）；
        // 挂进 transform 列表后又要自己给 origin —— itemToParentTransform 对列表原样 applyTo，
        // 只有 Item.rotation/scale 那支才做 transformOrigin 补偿
        const button = make('Button { text: "保存"; loading: true; width: 120; height: 32 }')
        const hosts = findAll(button, "buttonGlyphHost")
        compare(hosts.length, 1)
        const host = hosts[0]
        compare(host.transform.length, 1, "Rotation 必须在 transform 列表里")
        const turn = host.transform[0]
        compare(turn.origin.x, host.width / 2, "绕图标自己的中心转，别绕左上角甩出去")
        compare(turn.origin.y, host.height / 2)
        const first = turn.angle
        wait(200)
        verify(turn.angle !== first, "转圈角度该在动")
        button.loading = false
        const stopped = turn.angle
        wait(200)
        compare(turn.angle, stopped, "不加载就不该再转")
    }

    function test_loadingTextOnlyStillCountsAsIconButton() {
        const button = make('Button { text: "保存"; loading: true }')
        compare(button.iconOnly, false)
        const noText = make('Button { loading: true }')
        compare(noText.iconOnly, true, "只有转圈时按图标按钮算，正方形")
        compare(noText.width, 32)
    }

    // ---- 多彩按钮 ----

    function test_colorfulSolidUsesGradient() {
        const button = make('Button { text: "Colorful"; colorful: true; variant: Enums.Solid }')
        compare(button.resolvedColorful, true)
        compare(button.colorfulSurface, true)
        compare(button.colorfulLevel, 5)
        verify(button.colorfulGradientCss.indexOf("linear-gradient(278deg") === 0,
            "primary 常态取 --semi-ai-general-5")
        const surface = findAll(button, "colorfulSurface")
        compare(surface.length, 1)
        compare(surface[0].visible, true, "渐变底那一层应该真的显示出来")
        const stops = button.colorfulStops
        compare(stops.length, 4)
        // CSS 的 0% 在右端：QML position 0 拿到的是最后一个色标
        compare(stops[0].color, "#2e8cff")
        compare(stops[3].color, "#e945ff")
        compare(stops[0].position, 0)
        compare(stops[3].position, 1)
    }

    function test_colorfulSolidTertiaryUsesLowerLevels() {
        const button = make('Button { text: "Colorful"; colorful: true; variant: Enums.Solid; tone: Enums.Tertiary }')
        compare(button.colorfulLevel, 0)
        compare(findAll(button, "colorfulSurface")[0].visible, true)
        compare(button.colorfulText, true, "solid tertiary 是渐变字")
        verify(button.foregroundColor.toString() !== Theme.current.colorText1.toString(),
            "多彩 tertiary 不该再用普通 tertiary 文本色")
    }

    function test_colorfulLightAndBorderlessUseGradientText() {
        const light = make('Button { text: "Colorful"; colorful: true; variant: Enums.Light }')
        compare(light.colorfulSurface, false)
        compare(light.colorfulText, true)
        compare(light.foregroundColor.toString(), "#8c69ff")
        const borderless = make('Button { text: "Colorful"; colorful: true; variant: Enums.Borderless }')
        compare(borderless.colorfulText, true)
    }

    function test_colorfulOutlineIsAiPurple() {
        const button = make('Button { text: "Colorful"; colorful: true; variant: Enums.Outline }')
        compare(button.colorfulPurple, true)
        compare(button.colorfulText, false)
        compare(button.foregroundColor, Theme.current.colorAiPurple)
        compare(button.border.color, Theme.current.colorAiPurple)
    }

    function test_colorfulIconTintFollowsFillArray() {
        // 官方给图标塞的是 fill 数组，单路径图标实际吃到 fill[0] = 渐变最后一个色标
        const multiple = make('Button { text: "Colorful"; colorful: true; variant: Enums.Light }')
        compare(multiple.colorfulIconMultiple, true)
        compare(multiple.glyphColor.toString(), "#2e8cff")
        const two = make('Button { text: "Colorful"; colorful: true; variant: Enums.Light; tone: Enums.Tertiary }')
        compare(two.colorfulIconTwo, true)
        compare(two.glyphColor, Theme.current.colorAiPurple)
    }

    function test_disabledDropsColorfulSurface() {
        // 禁用时 DOM 上不挂 -primary / -tertiary，整套多彩规则失效
        const button = make('Button { text: "Colorful"; colorful: true; variant: Enums.Solid; enabled: false }')
        compare(button.colorfulSurface, false)
        compare(findAll(button, "colorfulSurface")[0].visible, false)
        compare(button.colorfulText, false)
        compare(button.color, Theme.current.colorDisabledBg)
        compare(button.foregroundColor, Theme.current.colorDisabledText)
    }

    function test_loadingColorfulUsesAiSpinner() {
        const button = make('Button { text: "Colorful"; colorful: true; loading: true }')
        compare(button.spinnerShown, true)
        const plain = make('Button { text: "保存"; loading: true }')
        compare(plain.spinnerShown, true)
    }

    // ---- ButtonGroup ----

    function test_groupMergesCorners() {
        const group = make('ButtonGroup { Button { text: "甲" } Button { text: "乙" } Button { text: "丙" } }')
        const members = group.childItems
        compare(members.length, 3)
        compare(members[0].groupPosition, "first")
        compare(members[1].groupPosition, "middle")
        compare(members[2].groupPosition, "last")
        const r = Theme.current.radiusSmall
        compare(members[0].topLeftRadius, r)
        compare(members[0].topRightRadius, 0)
        compare(members[1].topLeftRadius, 0)
        compare(members[1].topRightRadius, 0)
        compare(members[2].topLeftRadius, 0)
        compare(members[2].topRightRadius, r)
    }

    function test_singleMemberKeepsBothCorners() {
        const group = make('ButtonGroup { Button { text: "只有一支" } }')
        compare(group.childItems[0].groupPosition, "only")
        compare(group.childItems[0].topLeftRadius, Theme.current.radiusSmall)
        compare(group.childItems[0].topRightRadius, Theme.current.radiusSmall)
    }

    function test_groupInsertsOneDividerPerSeam() {
        const group = make('ButtonGroup { Button { text: "甲" } Button { text: "乙" } Button { text: "丙" } }')
        const lines = testCase.findAll(group, "groupLine")
        compare(lines.length, 2)
        compare(group.childItems.length, 3)
        for (let i = 0; i < lines.length; ++i) {
            compare(lines[i].visible, true)
            compare(lines[i].width, Theme.current.borderThicknessControl)
            compare(lines[i].height, group.height, "分隔条被 flex 拉成整行高")
            // 官方 ::before 是 1px × 20px
            compare(lines[i].children[0].height, 20)
            compare(lines[i].children[0].color, Theme.current.colorBorder)
            compare(lines[i].x, group.childItems[i].x + group.childItems[i].width)
        }
    }

    function test_groupWidthCountsDividerSeams() {
        const group = make('ButtonGroup { Button { text: "甲" } Button { text: "乙" } }')
        let sum = 0
        for (let i = 0; i < group.childItems.length; ++i)
            sum += group.childItems[i].width
        compare(group.width, sum + Theme.current.borderThicknessControl)
        compare(group.childItems[1].x, group.childItems[0].width + Theme.current.borderThicknessControl)
    }

    function test_groupLineColourFollowsThemeAndType() {
        // light → fill-0；solid → 该 type 的底色；borderless → 透明
        const light = make('ButtonGroup { Button { text: "甲" } Button { text: "乙" } }')
        compare(testCase.findAll(light, "groupLine")[0].color, Theme.current.colorFill0)
        const solid = make('ButtonGroup { variant: Enums.Solid; tone: Enums.Danger;'
            + ' Button { text: "甲" } Button { text: "乙" } }')
        compare(testCase.findAll(solid, "groupLine")[0].color, Theme.current.colorDanger)
        const borderless = make('ButtonGroup { variant: Enums.Borderless;'
            + ' Button { text: "甲" } Button { text: "乙" } }')
        compare(testCase.findAll(borderless, "groupLine")[0].color.toString(), "#00000000")
    }

    function test_outlineGroupOverlapsInsteadOfDrawingLines() {
        const group = make('ButtonGroup { Button { variant: Enums.Outline; text: "甲" }'
            + ' Button { variant: Enums.Outline; text: "乙" } }')
        const lines = testCase.findAll(group, "groupLine")
        compare(lines.length, 1, "两支按钮之间是一条缝")
        compare(lines[0].visible, false, "outline 形态官方不插分隔条")
        compare(group.childItems[1].x, group.childItems[0].width - Theme.current.borderThicknessControl,
            "改成后一支压前一支 1px")
    }

    function test_groupPropagatesSizeAndTone() {
        const group = make('ButtonGroup { size: Enums.Large; tone: Enums.Warning;'
            + ' Button { text: "甲" } Button { text: "乙" } }')
        for (let i = 0; i < group.childItems.length; ++i) {
            compare(group.childItems[i].resolvedSize, Enums.Large)
            compare(group.childItems[i].resolvedTone, Enums.Warning)
            compare(group.childItems[i].height, 40)
        }
    }

    function test_groupSizeDoesNotBeatChildSize() {
        // cloneElement 里 ...itm.props 在 size 之后，单项写了就以单项为准
        const group = make('ButtonGroup { size: Enums.Large; Button { text: "甲"; size: Enums.Small }'
            + ' Button { text: "乙" } }')
        compare(group.childItems[0].resolvedSize, Enums.Small)
        compare(group.childItems[1].resolvedSize, Enums.Large)
    }

    function test_groupVariantBeatsChildVariant() {
        // theme / colorful 走 ...rest，排在子级 props 之后，是「组盖单项」
        const group = make('ButtonGroup { variant: Enums.Solid; Button { text: "甲"; variant: Enums.Light } }')
        compare(group.childItems[0].resolvedVariant, Enums.Solid)
    }

    function test_groupDisablesMembers() {
        const group = make('ButtonGroup { disabled: true; Button { text: "甲" } Button { text: "乙" } }')
        compare(group.childItems[0].enabled, false)
        compare(group.childItems[1].enabled, false)
        clickedSpy.target = group.childItems[0]
        mouseClick(group.childItems[0])
        compare(clickedSpy.count, 0)
    }

    function test_disabledSolidGroupLineIsDisabledBg() {
        const group = make('ButtonGroup { variant: Enums.Solid; disabled: true;'
            + ' Button { text: "甲" } Button { text: "乙" } }')
        compare(testCase.findAll(group, "groupLine")[0].color, Theme.current.colorDisabledBg)
    }

    function test_disabledLightGroupLineStaysFillZero() {
        // -group-line-light 排在 -group-line-disabled 之后，同特异度后来的赢
        const group = make('ButtonGroup { disabled: true; Button { text: "甲" } Button { text: "乙" } }')
        compare(testCase.findAll(group, "groupLine")[0].color, Theme.current.colorFill0)
    }

    function test_groupIgnoresNonButtons() {
        const group = make('ButtonGroup { Button { text: "甲" } Item { width: 10; height: 10 }'
            + ' Button { text: "乙" } }')
        compare(group.childItems.length, 2, "普通 Item 不该算成员")
        compare(testCase.findAll(group, "groupLine").length, 1)
    }

    // ---- SplitButtonGroup ----

    function test_splitKeepsOuterCornersAndOnePixelGap() {
        const split = make('SplitButtonGroup { Button { text: "分裂按钮" } Button { icon: "tree_triangle_down" } }')
        const members = split.childItems
        compare(members.length, 2)
        compare(members[0].groupPosition, "first")
        compare(members[1].groupPosition, "last")
        const r = Theme.current.radiusSmall
        compare(members[0].topLeftRadius, r)
        compare(members[0].topRightRadius, 0)
        compare(members[1].topLeftRadius, 0)
        compare(members[1].topRightRadius, r)
        compare(members[1].x, members[0].width + 1, "官方是 margin-right: 1px 的真间隔")
        compare(split.width, members[0].width + 1 + members[1].width)
    }

    function test_splitPropagatesNothing() {
        // splitButtonGroup.tsx 只加 -first / -last 两个类，不下发 size / theme / type
        const split = make('SplitButtonGroup { Button { text: "甲"; variant: Enums.Solid }'
            + ' Button { text: "乙"; size: Enums.Small } }')
        compare(split.childItems[0].resolvedVariant, Enums.Solid)
        compare(split.childItems[1].resolvedSize, Enums.Small)
        compare(split.childItems[0].resolvedSize, Enums.Default)
    }

    // ---- CssGradient ----

    function test_gradientParsing() {
        const css = "linear-gradient(278deg, rgba(233,69,255) 0%, rgba(166,71,255) 30%,"
            + " rgba(107,97,255) 60%, rgba(46,140,255) 100%)"
        const stops = CssGradient.horizontalStops(css)
        compare(stops.length, 4)
        compare(stops[1].position, 0.4)
        compare(stops[2].position, 0.7)
        compare(stops[0].color, "#2e8cff")
        compare(CssGradient.representative(css), "#8c69ff")
        compare(CssGradient.endColor(css), "#2e8cff")
        // 90deg 指向右，CSS 的 0% 在左端，不翻转
        const right = "linear-gradient(90deg, rgba(1,2,3) 0%, rgba(4,5,6) 100%)"
        compare(CssGradient.horizontalStops(right)[0].color, "#010203")
        compare(CssGradient.horizontalStops(""), [])
        compare(CssGradient.representative(undefined), "")
    }

    // ---- 焦点轮廓色（官方那条 :not(.borderless):not(.light) 的分支）----

    function test_focusRingColour() {
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Primary, Enums.Solid).toString(),
            Theme.current.colorPrimaryLightActive.toString())
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Secondary, Enums.Solid).toString(),
            Theme.current.colorPrimaryLightActive.toString())
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Danger, Enums.Solid).toString(),
            Theme.current.colorDangerLightActive.toString())
        compare(Appearance.buttonFocusRing(Theme.current, Enums.Warning, Enums.Light).toString(),
            Theme.current.colorPrimaryLightActive.toString())
    }

    function test_focusRingRendersOnKeyboardFocus() {
        // 只查 Appearance 不算数，得看按钮真的把轮廓按同一支函数画出来
        const danger = make('Button { text: "删除"; tone: Enums.Danger; variant: Enums.Solid;'
            + ' x: 10; y: 10; width: 100; height: 32 }')
        const rings = findAll(danger, "focusRing")
        compare(rings.length, 1)
        danger.forceActiveFocus()
        // FocusVisible 靠 app 级事件过滤切键盘模式，随便按一个键就能切过去
        keyPress(Qt.Key_A)
        compare(danger.activeFocus, true)
        compare(rings[0].visible, true)
        compare(rings[0].border.width, 2, "官方是 outline: 2px")
        compare(rings[0].anchors.margins, -2, "outline 贴着边框外沿")
        compare(rings[0].border.color.toString(),
            Appearance.buttonFocusRing(Theme.current, Enums.Danger, Enums.Solid).toString())
        compare(rings[0].border.color.toString(), Theme.current.colorDangerLightActive.toString())
        keyRelease(Qt.Key_A)
    }

    // ---------------------------------------------------------------- 官方 onMouseDown
    function test_mouseDownFiresBeforeClick() {
        const b = make('Button { text: "提交"; x: 10; y: 10; width: 100; height: 32 }')
        wait(30)
        const downSpy = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "mouseDown" }',
            testCase, "spy")
        downSpy.target = b
        clickedSpy.target = b
        // 按下不等抬起：mouseDown 在 press 那一拍就发，clicked 在 release 才发
        mousePress(b, 50, 16)
        wait(20)
        compare(downSpy.count, 1, "onMouseDown 按下即发（Button.tsx:131 挂在 <button> 上）")
        compare(clickedSpy.count, 0, "按下还不发 onClick")
        mouseRelease(b, 50, 16)
        wait(20)
        compare(downSpy.count, 1, "抬起不重发 mouseDown")
        compare(clickedSpy.count, 1, "抬起发 onClick")
        downSpy.destroy()
    }

    function test_mouseDownDeadWhenDisabledOrLoading() {
        // 官方 disabled 是原生 disabled、loading 是 pointer-events:none —— 两样都收不到 mousedown
        const off = make('Button { text: "禁用"; enabled: false; x: 10; y: 10; width: 100; height: 32 }')
        const load = make('Button { text: "加载"; loading: true; x: 10; y: 60; width: 100; height: 32 }')
        wait(30)
        const offSpy = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "mouseDown" }',
            testCase, "spy1")
        offSpy.target = off
        const loadSpy = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "mouseDown" }',
            testCase, "spy2")
        loadSpy.target = load
        mouseClick(off, 50, 16)
        mouseClick(load, 50, 16)
        wait(20)
        compare(offSpy.count, 0, "禁用档 TapHandler 关掉，mousedown 进不来")
        compare(loadSpy.count, 0, "加载档同理")
        offSpy.destroy()
        loadSpy.destroy()
    }

    // ---------------------------------------------------------------- 官方 onMouseEnter / onMouseLeave
    function test_mouseEnterAndLeaveFireOnHover() {
        const b = make('Button { text: "悬浮"; x: 10; y: 10; width: 100; height: 32 }')
        wait(30)
        const enterSpy = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "mouseEntered" }',
            testCase, "spy1")
        enterSpy.target = b
        const leaveSpy = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "mouseLeft" }',
            testCase, "spy2")
        leaveSpy.target = b
        // 指针先停在窗外，进按钮、再离开
        mouseMove(testCase, 2, 2)
        wait(20)
        mouseMove(b, 50, 16)
        tryVerify(function () { return enterSpy.count === 1; }, 1000, "onMouseEnter 进入即发")
        mouseMove(testCase, 2, 2)
        tryVerify(function () { return leaveSpy.count === 1; }, 1000, "onMouseLeave 离开即发")
        compare(enterSpy.count, 1, "离开不重发 enter")
        enterSpy.destroy()
        leaveSpy.destroy()
    }

    function test_mouseEnterLeaveDeadWhenLoading() {
        // .semi-button-loading { pointer-events: none } —— 加载态连悬浮事件都不该有
        const b = make('Button { text: "加载"; loading: true; x: 10; y: 10; width: 100; height: 32 }')
        wait(30)
        const enterSpy = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "mouseEntered" }',
            testCase, "spy1")
        enterSpy.target = b
        mouseMove(testCase, 2, 2)
        wait(20)
        mouseMove(b, 50, 16)
        wait(60)
        compare(enterSpy.count, 0, "加载档 HoverHandler 关掉，悬浮事件进不来")
        enterSpy.destroy()
    }

    // ---------------------------------------------------------------- circle 死 prop
    function test_circleIsInert() {
        // 官方 Button.tsx:112 emit `-circle` 类名但全仓无规则消费（compiled semi.css 0 命中）
        // ⇒ 收下不产出差异：几何、圆角、尺寸与不开完全一致
        const plain = make('Button { icon: "camera"; x: 10; y: 10 }')
        const round = make('Button { icon: "camera"; circle: true; x: 10; y: 60 }')
        wait(30)
        compare(round.width, plain.width, "circle 不改宽")
        compare(round.height, plain.height, "circle 不改高")
        compare(round.topLeftRadius, plain.topLeftRadius, "circle 不改圆角")
        compare(round.topRightRadius, plain.topRightRadius)
        plain.destroy()
        round.destroy()
    }

    function test_cursorIsPointingHand() {
        // button.scss:14 的 cursor: pointer。HoverHandler 不是 Item，不在 children 名单里
        // （住 data），用实例的 findChild 按 objectName 捞
        const b = make('Button { text: "悬浮"; x: 10; y: 10; width: 100; height: 32 }')
        wait(30)
        const h = testCase.findChild(b, "buttonHoverHandler")
        verify(h !== null, "HoverHandler 找得到")
        compare(h.cursorShape, Qt.PointingHandCursor, "button.scss:14 的 cursor: pointer")
        b.destroy()
    }
}
