import QtQuick
import QtTest
import Semi

// Highlight 关键词高亮。规格照 packages/semi-ui/highlight/index.tsx +
// packages/semi-foundation/highlight/{foundation.ts,highlight.scss,variables.scss,constants.ts}，
// demo 面照 content/show/highlight/index.md 的 5 个小节（如何引入 / 基本用法 / 指定高亮样式 /
// 不同文本使用差异化样式 / 指定高亮标签；`###` 一共 6 个，多出的是 Highlight 那张 API 表）。
//
// 断言的口径：不比「自己生成的那串 HTML」，而是把 `<span>` 里包住的文本抽出来当事实钉住
// （marks()），样式那几条再单独钉 token 值与先后顺序。
//
//   · HighlightProps（index.tsx:26-34，缺省 :52-57）：component **"mark"** / autoEscape **true** /
//     caseSensitive **false** / sourceString **''**；searchWords 三形（字符串、字符串数组、
//     `{text, className, style}` 对象数组，v2.71 起）。
//   · 算法是「每词各扫一遍 → 按 start 排序 → 一趟合并（判据 next.start <= prev.end，**相接也算**）
//     → 补非高亮段」，不是把词拼成一个 big-alternation 正则 ⇒ 'aaa do dollar aaa' + ['do','dollar']
//     亮的是整段 "dollar"（foundation.ts:52-68 注释里的原例）。
//   · 合并时 style 是 `{...prev, ...next}`（后者逐键盖掉）、className 是 `prev || next`。
//   · autoEscape 为假 ⇒ 词按正则用；零宽匹配靠 `end > start` 与 `lastIndex++` 两条挡住（:121-132）。
//   · `.semi-highlight-tag` 恒加 ⇒ 换 `component` 观感不变（端口收了不生效）；
//     `highlightClassName` / 对象档的 `className` 没有 CSS 可落；`style` / `className` 官方
//     propTypes 里有但 render 从不使用（返回的是数组，连外层元素都没有）。
//   · 样式能落到 Qt 行内富文本的只有 color / background-color / font-weight / font-style /
//     text-decoration / font-size / font-family；官方 demo 的 borderRadius / padding / margin 不生效。
TestCase {
    id: testCase

    name: "Highlight"
    when: windowShown
    width: 700
    height: 400

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "hl");
    }

    // 把高亮片段抽出来（顺序即出现顺序），这是本件唯一有意义的「渲染结果」
    function marks(t) {
        const out = [];
        const re = /<span[^>]*>([^<]*)<\/span>/g;
        let m = re.exec(t.text);
        while (m !== null) {
            out.push(m[1]);
            m = re.exec(t.text);
        }
        return out.join("|");
    }

    // 高亮段与非高亮段的切分（含空段边界），用来钉 fillInChunks 的位置
    function segments(t) {
        const re = /(<span[^>]*>[^<]*<\/span>)|([^<]+)/g;
        const out = [];
        let m = re.exec(t.text);
        while (m !== null) {
            out.push(m[1] !== undefined && m[1].length > 0 ? "[" + m[1].replace(/<[^>]*>/g, "") + "]"
                : m[2]);
            m = re.exec(t.text);
        }
        return out.join("");
    }

    function styleOf(t) {
        const at = t.text.indexOf("style=\"");
        if (at < 0)
            return "";
        return t.text.substring(at + 7, t.text.indexOf("\"", at + 7));
    }

    // ---------------- 属性面 ----------------

    function test_officialPropDefaults() {
        const t = make("Highlight {}");
        compare(t.component, "mark", "index.tsx:53 defaultProps");
        compare(t.autoEscape, true);
        compare(t.caseSensitive, false);
        compare(t.sourceString, "");
        compare(t.text, "", "空源串就什么都没有，不是空标签");
        t.destroy();
    }

    function test_noWordsReturnsPlainSource() {
        const t = make("Highlight { sourceString: '小米是一家公司' }");
        compare(t.text, "小米是一家公司");
        t.searchWords = [];
        compare(t.text, "小米是一家公司");
        t.searchWords = ["", null, undefined];
        compare(t.text, "小米是一家公司", "空词被 filter 掉（foundation.ts:109）");
        t.destroy();
    }

    function test_numberWordsAreDropped() {
        // :108 的归一只认字符串与对象；数字既不是字符串也没有 text ⇒ 被丢掉，
        // 端口不能替它 String()（旧实现就是这里多算了一个词）
        const t = make("Highlight { sourceString: 'a1b'; searchWords: [1] }");
        compare(marks(t), "", "数字词不生效");
        t.destroy();
    }

    function test_bareStringSearchWordsIsNormalized() {
        const t = make("Highlight { sourceString: '小米是一家公司'; searchWords: '小米' }");
        compare(marks(t), "小米", "foundation.ts:78-80：整条给字符串也认");
        // 只钉「亮出什么」还不够：不归一的话会退化成按字符切，'a' 与 'b' 各自命中，
        // 挨着时又被合并规则并成一段 ⇒ 上面那条测不出来。这条用不相邻的两个字符才穿透。
        const apart = make("Highlight { sourceString: 'aXb'; searchWords: 'ab' }");
        compare(marks(apart), "", "归一之后 'ab' 是一个词，在 'aXb' 里根本不命中");
        t.destroy();
        apart.destroy();
    }

    function test_objectWithoutTextIsDropped() {
        // filter(sw => sw.text) 那条：没有 text 的对象如果漏进 reduce，会被 String(undefined)
        // 当成正则 'undefined' 去匹配 ⇒ 源文本里出现这个词就会莫名亮一段
        const t = make("Highlight { sourceString: 'undefined is fine';"
            + " searchWords: [{ style: ({ color: '#111111' }) }] }");
        compare(marks(t), "", "没给 text 的对象整个丢掉");
        t.destroy();
    }

    // ---------------- 切分与合并 ----------------

    function test_singleWordWrapsOnlyTheMatch() {
        const t = make("Highlight { sourceString: '小米是一家公司'; searchWords: ['是一家'] }");
        compare(marks(t), "是一家");
        compare(segments(t), "小米[是一家]公司", "非高亮段由 fillInChunks 补出来");
        t.destroy();
    }

    function test_allOccurrencesAreHighlighted() {
        const t = make("Highlight { sourceString: 'aaazaaazaaa'; searchWords: ['z'] }");
        compare(marks(t), "z|z");
        compare(segments(t), "aaa[z]aaa[z]aaa", "foundation.ts:43-49 注释里那条原例");
        t.destroy();
    }

    function test_overlappingWordsMergeIntoOneSpan() {
        // foundation.ts:52-68 那条原例：'do' 命中 (4,6) 与 (7,9)，'dollar' 命中 (7,13)；
        // 后两条相接 ⇒ 并成 (7,13) ⇒ 亮的是整段 "dollar"，而不是 "do" 把 "dollar" 切碎
        const t = make("Highlight { sourceString: 'aaa do dollar aaa';"
            + " searchWords: ['do', 'dollar'] }");
        compare(marks(t), "do|dollar");
        compare(segments(t), "aaa [do] [dollar] aaa", "合并发生在第二个词上，(4,6) 那一条不受影响");
        t.destroy();
    }

    function test_touchingChunksAlsoMerge() {
        // 'abc' → (0,3)，'bcd' → (1,4)：判据是 next.start <= prev.end ⇒ 并成 (0,4)
        const t = make("Highlight { sourceString: 'abcd'; searchWords: ['abc', 'bcd'] }");
        compare(marks(t), "abcd", "首尾相接的两段并成一段");
        t.destroy();
    }

    function test_adjacentButNotOverlappingStayApart() {
        // 'ab' → (0,2)，'cd' → (2,4)：next.start(2) <= prev.end(2) ⇒ 仍然并成一段！
        // 这条钉的是官方那条「小于等于」的判据本身 —— 挨着的两段会被并掉
        const t = make("Highlight { sourceString: 'abcd'; searchWords: ['ab', 'cd'] }");
        compare(marks(t), "abcd", "判据含等于 ⇒ 紧挨着的两段也并成一段");
        t.destroy();
    }

    function test_longWordDoesNotChopShortWord() {
        const t = make("Highlight { sourceString: 'abcd'; searchWords: ['bc', 'abc'] }");
        compare(marks(t), "abc", "排序后 (0,3) 在前、(1,3) 并进它 ⇒ end 取大者");
        t.destroy();
    }

    function test_repeatedWordHitsEveryMatch() {
        const t = make("Highlight { sourceString: 'abXabXab'; searchWords: ['ab'] }");
        compare(marks(t), "ab|ab|ab");
        compare(segments(t), "[ab]X[ab]X[ab]");
        t.destroy();
    }

    // ---------------- 大小写与正则 ----------------

    function test_caseSensitiveBothWays() {
        const t = make("Highlight { sourceString: 'Xiaomi'; searchWords: ['xiaomi'] }");
        compare(marks(t), "Xiaomi", "缺省不敏感");
        t.caseSensitive = true;
        compare(marks(t), "", "敏感档下大小写不同就不命中");
        t.searchWords = ["Xiaomi"];
        compare(marks(t), "Xiaomi");
        t.destroy();
    }

    function test_autoEscapeTrueIsLiteral() {
        const t = make("Highlight { sourceString: 'axb'; searchWords: ['a.b'] }");
        compare(marks(t), "", "点号是字面量，不是通配符");
        t.sourceString = "a.b";
        compare(marks(t), "a.b");
        t.destroy();
    }

    function test_autoEscapeFalseUsesRegex() {
        const t = make("Highlight { sourceString: 'axb'; searchWords: ['a.b'];"
            + " autoEscape: false }");
        compare(marks(t), "axb", "关掉转义 ⇒ 词按正则用");
        t.searchWords = ["^a"];
        compare(marks(t), "a", "锚点也生效");
        t.destroy();
    }

    function test_zeroWidthRegexDoesNotHang() {
        // 'a*' 在 (0,1) 命中一次，之后全是零宽匹配：靠 end > start 与 lastIndex++ 两条挡住
        const t = make("Highlight { sourceString: 'abc'; searchWords: ['a*'];"
            + " autoEscape: false }");
        compare(marks(t), "a");
        t.destroy();
    }

    function test_brokenRegexSkipsThatWordOnly() {
        const t = make("Highlight { sourceString: 'ab'; searchWords: ['(', 'b'];"
            + " autoEscape: false }");
        compare(marks(t), "b", "写坏的正则只跳过那一个词，别的照常");
        t.destroy();
    }

    // ---------------- 样式 ----------------

    function test_usesTokenColorsAndWeight() {
        const t = make("Highlight { sourceString: 'ab'; searchWords: ['a'] }");
        const css = styleOf(t);
        verify(css.indexOf("color:" + Theme.current.colorHighlight) === 0, "文字色 " + css);
        verify(css.indexOf("background-color:" + Theme.current.colorHighlightBg) > 0, css);
        verify(css.indexOf("font-weight:600") > 0, css);
        t.destroy();
    }

    function test_themeChangeRepaintsTheStyle() {
        const t = make("Highlight { sourceString: 'ab'; searchWords: ['a'] }");
        const light = t.text;
        Theme.mode = Theme.Dark;
        verify(t.text !== light, "切暗色必须换掉那两条颜色（令牌是绑上去的，不是拼死在串里）");
        verify(styleOf(t).indexOf("color:" + Theme.current.colorHighlight) === 0, styleOf(t));
        Theme.mode = Theme.Light;
        compare(t.text, light);
        t.destroy();
    }

    function test_highlightStyleAddsToTheTagStyle() {
        const t = make("Highlight { sourceString: 'ab'; searchWords: ['a'];"
            + " highlightStyle: ({ color: '#ffffff', backgroundColor: '#0077fa' }) }");
        const css = styleOf(t);
        verify(css.indexOf("font-weight:600") > 0, "类上的那条还在");
        verify(css.indexOf("color:#ffffff") > css.indexOf("color:" + Theme.current.colorHighlight),
            "内联的 color 写在后面 ⇒ Qt 解析时后写的盖掉先写的：" + css);
        verify(css.indexOf("background-color:#0077fa") > css.indexOf("background-color:"
            + Theme.current.colorHighlightBg), css);
        verify(css.indexOf("undefined") < 0, "没给的键不产出声明：" + css);
        t.destroy();
    }

    function test_objectSearchWordsCarryTheirOwnStyle() {
        // 取两个不相邻的词：相邻的话会被合并规则先并成一段，测不出「各带各的样式」
        const t = make("Highlight { sourceString: '甲乙丙';"
            + " searchWords: [{ text: '甲', style: ({ backgroundColor: '#111111' }),"
            + " className: 'keyword1' },"
            + " { text: '丙', style: ({ backgroundColor: '#222222' }) }] }");
        compare(marks(t), "甲|丙");
        const first = t.text.indexOf("#111111");
        const second = t.text.indexOf("#222222");
        verify(first > 0 && second > first, "两段各自带自己的底色");
        verify(t.text.indexOf("keyword1") < 0, "className 没有 CSS 可落 ⇒ 不进输出");
        t.destroy();
    }

    function test_mergedStyleLetsTheLaterWordWinPerKey() {
        // 两个词起点相同 (0,3) 与 (0,2)，稳定排序保持数组顺序 ⇒ prev 是第一个词，
        // {...prev, ...next} 让第二个词的 color 盖掉第一个
        const t = make("Highlight { sourceString: 'abcd';"
            + " searchWords: [{ text: 'abc', style: ({ color: '#111111' }) },"
            + " { text: 'ab', style: ({ color: '#222222', fontWeight: 700 }) }] }");
        compare(marks(t), "abc", "并成 (0,3)");
        const css = styleOf(t);
        verify(css.indexOf("color:#222222") > css.indexOf("color:#111111"), css);
        verify(css.indexOf("font-weight:700") > css.indexOf("font-weight:600"),
            "per-word 的字重写在最后 ⇒ 盖掉类上的 600");
        t.destroy();
    }

    function test_geometryStyleKeysAreDropped() {
        // 官方 demo 用了 borderRadius / padding / margin，Qt 的行内 span 不吃 ⇒ 不拼进输出
        const t = make("Highlight { sourceString: 'ab'; searchWords: ['a'];"
            + " highlightStyle: ({ borderRadius: 6, paddingLeft: 4, marginLeft: 4,"
            + " color: '#ffffff' }) }");
        const css = styleOf(t);
        verify(css.indexOf("border") < 0 && css.indexOf("padding") < 0 && css.indexOf("margin") < 0,
            "几何类键不产出声明：" + css);
        verify(css.indexOf("color:#ffffff") > 0, "认得的还是生效的");
        t.destroy();
    }

    function test_componentPropIsAcceptedButInert() {
        // 官方那条 .semi-highlight-tag 恒加 ⇒ 换标签观感一致；端口也没有「标签」这一档
        const mark = make("Highlight { sourceString: 'ab'; searchWords: ['a'] }");
        const before = mark.text;
        mark.component = "strong";
        compare(mark.text, before, "component 收了不生效（官方同理，差的只是 DOM 语义）");
        mark.destroy();
    }

    // ---------------- 转义与边界 ----------------

    function test_htmlEscaping() {
        const t = make("Highlight { sourceString: '<b>&</b>'; searchWords: ['&'] }");
        compare(segments(t), "&lt;b&gt;[&amp;]&lt;/b&gt;", "非高亮段与高亮段都要转义");
        t.destroy();
    }

    function test_regexMetacharactersAreLiteral() {
        const t = make("Highlight { sourceString: 'a[b]{c}d$e|f'; searchWords: ['[b]', '$', '|'] }");
        compare(marks(t), "[b]|$||", "方括号 / 美元 / 竖线都按字面量匹配");
        t.destroy();
    }

    function test_emptySourceWithWords() {
        const t = make("Highlight { sourceString: ''; searchWords: ['a'] }");
        compare(t.text, "");
        t.destroy();
    }

    function test_wordLongerThanSource() {
        const t = make("Highlight { sourceString: 'ab'; searchWords: ['abcd'] }");
        compare(t.text, "ab");
        t.destroy();
    }
}
