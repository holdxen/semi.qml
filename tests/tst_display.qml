import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Display"
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

    // ---------------- Typography ----------------

    function test_titleLevels() {
        const t1 = make('Title { level: 1; text: "x" }')
        const t4 = make('Title { level: 4; text: "x" }')
        const t6 = make('Title { level: 6; text: "x" }')
        compare(t1.font.pixelSize, 32)   // $font-size-header-1
        compare(t4.font.pixelSize, 20)
        compare(t6.font.pixelSize, 16)
        t1.destroy(); t4.destroy(); t6.destroy()
    }

    function test_paragraphSizes() {
        const def = make('Paragraph { text: "x" }')
        const small = make('Paragraph { size: Enums.Small; text: "x" }')
        compare(def.font.pixelSize, 14)
        compare(small.font.pixelSize, 12)
        def.destroy(); small.destroy()
    }

    function test_textLabelTones() {
        compare(Appearance.textColor(Theme.current, Enums.Neutral).toString(), "#1c1f23")
        compare(Appearance.textColor(Theme.current, Enums.Primary).toString(), "#0064fa")
        compare(Appearance.textColor(Theme.current, Enums.Tertiary).toString(),
                Theme.current.colorText2.toString())
    }

    function test_textLabelLinkAndDisabled() {
        const link = make('TextLabel { text: "链接"; link: true }')
        compare(link.color.toString(), Theme.current.colorLink.toString())
        link.destroy()

        const dis = make('TextLabel { text: "禁用"; disabled: true }')
        compare(dis.color.toString(), Theme.current.colorDisabledText.toString())
        dis.destroy()
    }

    // 排版的四个层级是 text-0/1/2/3，不是语义色 secondary
    // （typography/variables.scss 前四行；浏览器实测 secondary = rgba(28,31,35,.8)）
    function test_textLabelToneLevels() {
        const secondary = make('TextLabel { text: "s"; tone: Enums.Secondary }')
        const quaternary = make('TextLabel { text: "q"; tone: Enums.Quaternary }')
        compare(secondary.color.toString(), Theme.current.colorText1.toString())
        compare(quaternary.color.toString(), Theme.current.colorText3.toString())
        secondary.destroy(); quaternary.destroy()
    }

    // v>=1.0 起链接默认不带下划线；带 underline 时官方给的也不是 <u>，
    // 而是 hover / active 才出现的 1px border-bottom（typography.scss:105-113），
    // 所以 font.underline 在链接上始终是 false
    function test_textLabelLinkUnderlineRules() {
        const plain = make('TextLabel { text: "x"; link: true }')
        const marked = make('TextLabel { text: "x"; link: true; underline: true }')
        const notLink = make('TextLabel { text: "x"; underline: true }')
        compare(plain.font.underline, false)
        compare(marked.font.underline, false, "链接的下划线是 hover 的 border-bottom，不是常显")
        compare(notLink.font.underline, true)
        compare(plain.font.weight, Font.DemiBold)     // $font-typography_link-fontWeight = 600
        plain.destroy(); marked.destroy(); notLink.destroy()
    }

    function test_textLabelInlineDecorations() {
        const del = make('TextLabel { text: "x"; deleted: true }')
        const strong = make('TextLabel { text: "x"; strong: true }')
        const code = make('TextLabel { text: "x"; code: true }')
        compare(del.font.strikeout, true)
        compare(strong.font.weight, Font.DemiBold)    // Semi 的 $font-weight-bold 就是 600
        // code 是带内缩的色块：padding 上下 2 / 左右 4，文字换成 text-2
        compare(code.leftPadding, Theme.current.spacingExtraTight)
        compare(code.topPadding, Theme.current.spacingSuperTight)
        compare(code.color.toString(), Theme.current.colorText2.toString())
        del.destroy(); strong.destroy(); code.destroy()
    }

    // size 为 inherit 时官方靠 SizeContext 往下传，这里顺 parent 链找
    function test_textLabelSizeInherit() {
        const outer = make('TextLabel { size: Enums.Small; text: "a" }')
        const inner = Qt.createQmlObject(
            'import Semi; TextLabel { size: Enums.Inherit; text: "b" }', outer, "inner")
        compare(inner.parent, outer)
        compare(inner.font.pixelSize, Theme.current.fontSizeSmall)

        const loose = make('TextLabel { size: Enums.Inherit; text: "c" }')
        compare(loose.font.pixelSize, Theme.current.fontSizeRegular)
        inner.destroy(); outer.destroy(); loose.destroy()
    }

    function test_paragraphSpacing() {
        const normal = make('Paragraph { text: "x" }')
        const extended = make('Paragraph { spacing: Enums.SpacingExtended; text: "x" }')
        compare(normal.lineHeight, 20)
        compare(extended.lineHeight, 24)      // $font-typography_paragraph_extended-lineHeight
        normal.destroy(); extended.destroy()
    }

    function test_titleHeadingLineHeights() {
        const h1 = make('Title { heading: 1; text: "x" }')
        const h6 = make('Title { heading: 6; text: "x" }')
        compare(h1.font.pixelSize, 32)
        compare(h1.lineHeight, 44)
        compare(h6.font.pixelSize, 16)
        compare(h6.lineHeight, 22)
        h1.destroy(); h6.destroy()
    }

    // ---------------- Numeral ----------------

    function test_numeralRules_data() {
        return [
            // 期望值全部取自官方文档页里那几个 demo 的实际渲染
            { tag: "text", source: "点赞量：1.6111e1 K", rule: "text",
              precision: 1, truncate: "round", expect: "点赞量：16.1 K" },
            { tag: "numbers", source: "播放量:2.4444e2", rule: "numbers",
              precision: 1, truncate: "round", expect: "244.4" },
            { tag: "percentages", source: "好评率: 0.915", rule: "percentages",
              precision: 2, truncate: "round", expect: "好评率: 91.50%" },
            { tag: "percentages-precision-0", source: "胜率0.6", rule: "percentages",
              precision: 0, truncate: "round", expect: "胜率60%" },
            { tag: "bytes-decimal", source: "已使用: 1000", rule: "bytes-decimal",
              precision: 2, truncate: "floor", expect: "已使用: 1.00 KB" },
            { tag: "bytes-decimal-mb", source: "未使用: 1024000", rule: "bytes-decimal",
              precision: 2, truncate: "floor", expect: "未使用: 1.02 MB" },
            { tag: "bytes-binary", source: "已使用: 1024", rule: "bytes-binary",
              precision: 2, truncate: "floor", expect: "已使用: 1.00 KiB" },
            { tag: "bytes-binary-tib", source: "未使用: 2000000000000", rule: "bytes-binary",
              precision: 2, truncate: "floor", expect: "未使用: 1.81 TiB" },
            { tag: "exponential", source: "科学计数 12345", rule: "exponential",
              precision: 2, truncate: "round", expect: "科学计数 1.23e+4" }
        ]
    }

    function test_numeralRules(data) {
        const n = make('Numeral { rule: "' + data.rule + '"; precision: ' + data.precision
            + '; truncate: "' + data.truncate + '" }')
        n.source = data.source
        compare(n.text, data.expect)
        n.destroy()
    }

    // 传了 parser 就完全绕过 rule（formatNumeral.ts:73-75）
    function test_numeralParserBypassesRule() {
        const n = make('Numeral { rule: "percentages"; precision: 2 }')
        n.source = "现已服务 100000 用户"
        n.parser = function (v) {
            return String(v).split(" ").map(function (t) {
                return Number(t)
                    ? String(t).replace(/(\d)(?=(?:\d{3})+(?:\.|$))/g, "$1,") + "+" : t;
            }).join(" ");
        }
        compare(n.text, "现已服务 100,000+ 用户")
        n.destroy()
    }

    // ---------------- copyable / ellipsis ----------------

    function test_textLabelCopyable() {
        const plain = make('TextLabel { text: "正文" }')
        compare(plain.copyableOn, false)

        const on = make('TextLabel { text: "正文"; copyable: true }')
        compare(on.copyableOn, true)
        compare(on.copyContent, "正文")
        compare(on.copyDuration, 3)           // copyable.tsx:46 defaultProps

        const custom = make('TextLabel { text: "正文"; copyable: ({ content: "Hello, Semi!" }) }')
        compare(custom.copyContent, "Hello, Semi!")
        plain.destroy(); on.destroy(); custom.destroy()
    }

    function test_textLabelEllipsis() {
        const on = make('TextLabel { width: 100; ellipsis: true; text: "很长很长很长很长" }')
        compare(on.maximumLineCount, 1)
        compare(on.elide, Text.ElideRight)

        const mid = make('TextLabel { width: 100; ellipsis: ({ pos: "middle" }); text: "很长很长很长很长" }')
        compare(mid.elide, Text.ElideMiddle)

        const rows = make('Paragraph { width: 100; ellipsis: ({ rows: 3 }); text: "很长很长" }')
        compare(rows.maximumLineCount, 3)

        const suffixed = make('TextLabel { width: 100; ellipsis: ({ suffix: "小尾巴" }); text: "很长很长" }')
        verify(suffixed.rightPadding > 0, "suffix 要在正文里留出位置，否则会被压在一起")

        const off = make('TextLabel { width: 100; text: "很短" }')
        compare(off.elide, Text.ElideNone)
        compare(off.maximumLineCount, -1)

        on.destroy(); mid.destroy(); rows.destroy(); suffixed.destroy(); off.destroy()
    }

    // Avatar 的用例整批搬到 tests/tst_avatar.qml（2026-10-21 按官方 AvatarProps 重写那一轮）。
    // 这里原有两条依赖旧端口自造的 `circle` / Enums 三档尺寸 / 「取首字大写」面，已随之删除。

    // Badge 的用例整批搬到 tests/tst_badge.qml（2026-10-21 按官方 BadgeProps 重写那一轮）。
    // 这里原有三条依赖旧端口自造的 label / visibleBadge / showZero 面，已随之删除；
    // Appearance::badgeBackground / badgeForeground 那两个 helper 仍在（Banner、ToastItem 在用），
    // 它们的断言也一并搬进 tst_badge.qml 守着。

}
