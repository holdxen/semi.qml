import QtQuick
import QtQuick.Controls
import QtTest
import Semi

// Card / CardMeta / CardGroup。规格照
// packages/semi-ui/card/{index.tsx,meta.tsx,cardGroup.tsx} 与
// packages/semi-foundation/card/{card.scss,variables.scss,constants.ts}。
//
// 端口口径（逐条在 src/Card.qml、src/CardMeta.qml、src/CardGroup.qml 的文件头）：
//   · 本体 `padding: 0`，20 那圈内边距在 header / body / footer 三段各自身上；
//     **body 无条件渲染** ⇒ 空卡也占 40 高。
//   · ReactNode 档 = 字符串（或数字）或 Component；`header` 覆盖 title + headerExtraContent，
//     但外层的 padding 与 headerLine 那条线照旧。
//   · 标题给字符串时走 Typography.Title heading={6} ⇒ 16 / 22 / **600** + 单行截尾 +
//     截到了才出 Tooltip；Card.Meta 的标题是 card 自己的令牌 ⇒ 16 / 22 / **700**（重一档）。
//   · `shadows` 只有 hover / always，给了就有手型；300ms 淡入淡出顶 CSS 的 box-shadow 过渡。
//   · `actions` 的判据是 `Array.isArray` ⇒ 空数组也画那条 41 高的空操作区。
//   · `loading` 只在有 children 时出占位（官方 `{children && <Skeleton>}`）。
//   · CardGroup 是 Space：`wrap` + 缺省 `align-items: center`（行内垂直居中，不是 stretch）；
//     `type: 'grid'` 强制间距 0、成员卡圆角 0、相邻重叠 1px。
//
// 断言只写令牌与几何，字体度量一律从节点上读，不写死像素宽。
TestCase {
    id: testCase

    name: "Card"
    when: windowShown
    width: 900
    height: 900

    readonly property real pad: 20          // $spacing-card-padding = spacing-base-loose
    readonly property real gap: 20          // $spacing-card-margin（标题右 20 / 操作区上 20）
    readonly property real itemGap: 12      // index.tsx 写死的 actions 间距
    readonly property real seam: 1          // $width-card-border = border-thickness-control
    readonly property real line: 20         // $font-card_default-lineHeight
    readonly property real titleLine: 22    // $font-card_title-lineHeight

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    // 断言失败会跳过用例末尾的 destroy ⇒ 残留实例会继续占版面
    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import QtQuick.Controls; import Semi; "
                                  + qml, testCase, "card");
    }

    // 要当 ReactNode 档传进去的节点：`Component {}` 既不能写在 JS 数组字面量里，
    // 也不该当 createQmlObject 的根项（那是弃用写法），所以从内层文档造再交出去
    /// 官方 actions / cover / title 那些 ReactNode 档：端口收 Component。
    /// `Component {}` 既不能写在 JS 数组字面量里，也不该当 createQmlObject 的根项
    /// （那是弃用写法），所以在文档顶层声明成属性再交出去。
    readonly property Component actionBoxProto: Component {
        Rectangle {
            objectName: "box"
            width: 40
            height: 8
        }
    }

    function part(owner, name) {
        const node = testCase.findChild(owner, name);
        verify(node !== null && node !== undefined, "找不到 " + name);
        return node;
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 0.01,
               (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    // grabImage 给的是设备像素，按 item 自己的宽高折算，cocoa（2x）与 offscreen（1x）同一套点
    function px(shot, item, x, y) {
        const s = shot.width / item.width;
        return { x: Math.round(x * s), y: Math.round(y * s) };
    }

    // ---------------- 属性面与缺省 ----------------

    function test_officialPropDefaults() {
        const c = make("Card {}");
        verify(c.actions === undefined, "actions 官方没有缺省");
        verify(c.bodyStyle === undefined);
        compare(c.bordered, true, "index.tsx:79 bordered 缺省 true");
        compare(c.className, "");
        verify(c.cover === undefined);
        verify(c.footer === undefined);
        compare(c.footerLine, false, "index.tsx:80");
        verify(c.footerStyle === undefined);
        verify(c.header === undefined);
        compare(c.headerLine, true, "index.tsx:81 headerLine 缺省 true");
        verify(c.headerStyle === undefined);
        compare(c.loading, false, "index.tsx:82");
        compare(c.shadows, "", "strings.SHADOWS 只有 hover / always，不给就是没阴影");
        verify(c.style === undefined);
        verify(c.title === undefined);
        verify(c.headerExtraContent === undefined);
        compare(c.ariaLabel, "");
        c.destroy();
    }

    function test_metaPropDefaults() {
        const m = make("CardMeta {}");
        verify(m.avatar === undefined);
        verify(m.title === undefined);
        verify(m.description === undefined);
        compare(m.className, "");
        verify(m.style === undefined);
        m.destroy();
    }

    function test_groupPropDefaults() {
        const g = make("CardGroup {}");
        compare(g.spacing, 16, "cardGroup.tsx:33 代码里的缺省是 16（API 表写 12px，那是上游文档陈旧）");
        compare(g.type, "", "strings.TYPE 只有 grid，不给就是普通档");
        compare(g.className, "");
        verify(g.style === undefined);
        compare(g.isGrid, false);
        g.destroy();
    }

    // ---------------- 空卡：body 无条件渲染 ----------------

    function test_emptyCardStillCarriesBodyPadding() {
        const c = make("Card { width: 300 }");
        wait(40);
        const body = part(c, "cardBody");
        compare(body.visible, true, "renderBody 直接 return 那个 div，没有真值判断");
        compare(part(c, "cardHeader").visible, false, "三段里只有 body 是无条件渲染的");
        compare(part(c, "cardCover").visible, false);
        compare(part(c, "cardFooter").visible, false);
        near(c.bodyHeight, testCase.pad * 2, "空卡 = 上下各 20 的内边距");
        near(c.headerHeight, 0);
        near(c.coverHeight, 0);
        near(c.footerHeight, 0);
        near(c.implicitHeight, testCase.seam * 2 + testCase.pad * 2,
             "外加本体那对 1px 描边");
        const b = part(c, "cardSurface");
        compare(b.border.width, testCase.seam);
        c.destroy();
    }

    // 端口相对 CSS 的那条退路：调用方没给宽时按三段自然宽取最大
    function test_naturalWidthFollowsHeaderContent() {
        const plain = make("Card { Text { text: '正文'; font.pixelSize: 30 } }");
        wait(60);
        near(plain.width, plain.bodyNaturalWidth + testCase.pad * 2,
             "没写 width ⇒ 卡片宽 = implicitWidth = 正文自然宽 + 20×2");
        const titled = make("Card { title: 'Semi Design'; Text { text: 'a' } }");
        wait(60);
        near(titled.headerNaturalWidth, testCase.pad * 2 + part(titled, "cardTitleText").implicitWidth,
             "标题档的自然宽就是那 20 + 标题 + 20");
        near(titled.width, Math.max(titled.headerNaturalWidth,
            titled.bodyNaturalWidth + testCase.pad * 2), "三段里取最宽的那条");
        const withExtra = make("Card { title: 'Semi'; headerExtraContent: '更多' }");
        wait(60);
        near(withExtra.headerNaturalWidth,
             testCase.pad * 2 + part(withExtra, "cardTitleText").implicitWidth + testCase.gap
                + part(withExtra, "cardHeaderExtraText").implicitWidth,
             "附加内容在场时要多算那 20 的 margin-right");
        const footed = make("Card { footer: '这是一串比较长的页脚文字用来把脚那一档撑出去' }");
        wait(60);
        near(footed.width, footed.footerNaturalWidth + testCase.pad * 2, "脚档也参与取最大");
        plain.destroy();
        titled.destroy();
        withExtra.destroy();
        footed.destroy();
    }

    function test_borderedFalseDropsTwoRowsOfOne() {
        const on = make("Card { width: 300; title: 'T' }");
        const off = make("Card { width: 300; title: 'T'; bordered: false }");
        wait(40);
        near(off.borderW, 0, "$width-card-border 只跟着 bordered");
        const clipOff = part(off, "cardContentClip");
        near(clipOff.x, 0, "描边没了 ⇒ padding box 顶到本体边缘（overflow 裁的就是 padding box）");
        const clipOn = part(on, "cardContentClip");
        near(clipOn.x, testCase.seam, "有描边时内容要让出那 1px");
        near(off.implicitHeight, on.implicitHeight - testCase.seam * 2,
             "box-sizing: border-box 的 1px 上下各占一格");
        compare(part(off, "cardSurface").border.width, 0);
        // 描边与 headerLine / footerLine 互不相干
        compare(off.headerLine, true, "bordered 关掉不影响 headerLine");
        on.destroy();
        off.destroy();
    }

    // ---------------- header：title / headerExtraContent ----------------

    function test_titleStringIsHeadingSixSemibold() {
        const c = make("Card { width: 300; title: 'Semi Design' }");
        wait(40);
        const t = part(c, "cardTitleText");
        compare(t.visible, true);
        compare(t.font.pixelSize, Theme.current.fontSizeHeader6, "$font-size-header-6 = 16");
        compare(t.font.weight, Font.DemiBold, "Typography.Title 的字重是 600，不是 card 令牌那个 700");
        compare(t.color, Theme.current.colorText0, "$color-card_title-text");
        compare(t.lineHeight, testCase.titleLine, "$font-card_title-lineHeight");
        compare(t.lineHeightMode, Text.FixedHeight);
        compare(t.elide, Text.ElideRight, "ellipsis={{ rows: 1 }}");
        c.destroy();
    }

    function test_headerHeightPadsAndDrawsLine() {
        const c = make("Card { width: 300; title: 'T' }");
        wait(40);
        near(c.headerNodeHeight, testCase.titleLine);
        near(c.headerHeight, testCase.pad * 2 + testCase.titleLine + testCase.seam,
             "padding 20 × 2 + 22 + headerLine 那条 1px");
        const box = part(c, "cardHeaderPaddingBox");
        near(box.x, testCase.pad);
        near(box.y, testCase.pad);
        const seam = part(c, "cardHeaderSeam");
        compare(seam.visible, true, "headerLine 缺省 true");
        compare(seam.color, Theme.current.colorBorder);
        near(seam.height, testCase.seam);
        // 那条线压在 header 底边上，不在 padding 盒里
        near(seam.y + seam.height, c.headerHeight);
        c.destroy();
    }

    function test_headerLineFalseDropsExactlyOne() {
        const on = make("Card { width: 300; title: 'T' }");
        const off = make("Card { width: 300; title: 'T'; headerLine: false }");
        wait(40);
        compare(part(off, "cardHeaderSeam").visible, false);
        near(off.headerHeight, on.headerHeight - testCase.seam);
        near(off.implicitHeight, on.implicitHeight - testCase.seam);
        on.destroy();
        off.destroy();
    }

    function test_extraContentIsSixteenBoldTextZero() {
        const c = make("Card { width: 300; title: 'T'; headerExtraContent: '更多' }");
        wait(40);
        const e = part(c, "cardHeaderExtraText");
        compare(e.visible, true);
        compare(e.font.pixelSize, Theme.current.fontSizeHeader6, "$font-card_extra-fontSize");
        compare(e.font.weight, Font.Bold, "$font-card_extra-fontWeight: 700");
        compare(e.color, Theme.current.colorText0, "$color-card_extra-text 是 text-0，不是 text-2");
        compare(e.lineHeight, testCase.line, "-extra 没重赋行高 ⇒ 继承本体的 20");
        c.destroy();
    }

    function test_extraSitsRightWithTwentyGap() {
        const c = make("Card { width: 300; title: '卡片标题'; headerExtraContent: '更多' }");
        wait(60);
        const wrapper = part(c, "cardHeaderWrapper");
        const title = part(c, "cardTitleSlot");
        const extra = part(c, "cardHeaderExtraSlot");
        near(wrapper.width, c.width - testCase.seam * 2 - testCase.pad * 2,
             "wrapper 吃满 header 的 padding 盒");
        near(extra.x + extra.width, wrapper.width, "row-reverse + space-between ⇒ 附加贴右");
        near(title.width + testCase.gap + extra.width, wrapper.width,
             "标题那格带 margin-right: $spacing-card-margin（20）");
        near(title.x, 0, "标题靠左");
        near(title.y, 0, "align-items: flex-start ⇒ 两坨都顶对齐");
        near(extra.y, 0, "附加那坨也是顶对齐，不是垂直居中");
        // 附加那一格的宽必须按节点报：普通 Item 不 hug 子项，implicitWidth 是 0，
        // 贴右的位移就会把文字整条推到卡片外面
        near(extra.width, part(c, "cardHeaderExtraText").implicitWidth,
             "extraSlot 的宽是那一格节点报的");
        near(extra.height, part(c, "cardHeaderExtraText").implicitHeight);
        verify(extra.x + extra.width <= wrapper.width + 0.01, "附加那格不许溢出 header 的 padding 盒");
        near(title.height, part(c, "cardTitleText").implicitHeight, "标题格的高同理");
        c.destroy();
    }

    function test_extraOnlyStillRightAligned() {
        const c = make("Card { width: 300; headerExtraContent: '更多' }");
        wait(60);
        compare(part(c, "cardTitleSlot").visible, false);
        const extra = part(c, "cardHeaderExtraSlot");
        const wrapper = part(c, "cardHeaderWrapper");
        near(extra.x + extra.width, wrapper.width);
        near(c.headerNodeHeight, extra.height, "没有标题时 header 的高就是附加的高");
        c.destroy();
    }

    function test_titleComponentSlotUsesLoader() {
        const c = make("Card { width: 300; title: Component {"
                       + "Text { objectName: 'node'; text: 'x'; font.pixelSize: 30 } } }");
        wait(60);
        compare(part(c, "cardTitleText").visible, false, "非字符串 ⇒ 不进 Typography 那条路");
        compare(part(c, "cardTitleText").text, "", "字符串档没给时连文字都不该拼出来");
        const loader = part(c, "cardTitleNode");
        compare(loader.visible, true);
        compare(loader.active, true, "Component 档才激活 Loader");
        const node = part(loader, "node");
        near(node.font.pixelSize, 30, "Component 档原样摆进去，端口不套字号");
        near(c.headerNodeHeight, loader.implicitHeight);
        near(c.headerHeight, testCase.pad * 2 + loader.implicitHeight + testCase.seam);
        c.destroy();
    }

    function test_headerOverridesTitleAndExtraButKeepsBoxAndLine() {
        const c = make("Card { width: 300; header: '自定义头'; title: 'T'; headerExtraContent: 'E' }");
        wait(60);
        const t = part(c, "cardTitleText");
        const e = part(c, "cardHeaderExtraText");
        compare(c.customHeader, true, ":117 `{header || (...)}` ⇒ header 赢");
        // 两条开关本身也要断：`t.visible` 读回来的是**有效**可见性，父层 wrapper 一关就恒假，
        // 光看子项分不出「子项自己没渲染」与「被父层整块关掉」。
        compare(c.titleTaken, false, "官方 :117：给了 header 就不再有 title 那一格");
        compare(c.extraTaken, false, "同上，附加那格也不该算进 header");
        compare(t.visible, false, "header 给了就不该再渲染 title 那一格");
        compare(e.visible, false);
        compare(part(c, "cardHeaderWrapper").visible, false);
        const header = part(c, "cardHeaderText");
        compare(header.visible, true);
        near(c.headerNodeHeight, header.implicitHeight);
        near(c.headerHeight, testCase.pad * 2 + header.implicitHeight + testCase.seam,
             "线在 -header 上，不在 wrapper 上 ⇒ 覆盖档也照样有 headerLine");
        const box = part(c, "cardHeaderPaddingBox");
        near(box.x, testCase.pad, "自定义 header 也吃那 20 的内边距");
        c.destroy();
    }

    function test_titleTooltipFollowsElision() {
        const short = make("Card { width: 300; title: '短标题' }");
        wait(40);
        const tip = part(short, "cardTitleTooltip");
        compare(tip.condition, false, "没截尾就不出 Tooltip（showTooltip 只在截断时生效）");
        const longTitle = make("Card { width: 120; title: '这是一串很长很长很长很长很长的卡片标题' }");
        wait(40);
        compare(part(longTitle, "cardTitleText").truncated, true);
        compare(part(longTitle, "cardTitleTooltip").condition, true);
        // 有附加内容时标题格被挤窄，同一条标题在窄卡上会截、在宽卡上不会
        const both = make("Card { width: 300; title: 'Semi Design 是由抖音前端团队与 UED 团队'"
                          + "; headerExtraContent: '更多' }");
        wait(60);
        const slot = part(both, "cardTitleSlot");
        near(slot.width + testCase.gap + part(both, "cardHeaderExtraSlot").width,
             part(both, "cardHeaderWrapper").width, "挤窄的正是那 20 + 附加宽");
        short.destroy();
        longTitle.destroy();
        both.destroy();
    }

    // ---------------- cover ----------------

    function test_coverForcesFullWidth() {
        // 夹具故意给一张比卡片宽得多的封面：不铺满整幅就量不出来
        const c = make("Card { width: 202; cover: Component {"
                       + "Rectangle { objectName: 'big'; width: 500; height: 20 } } }");
        wait(80);
        const big = part(part(c, "cardCoverSlot"), "big");
        near(big.width, c.width - testCase.seam * 2, "`> * { width: 100% }`：节点自己的 500 要被压成整幅");
        near(c.coverHeight, 20);
        c.destroy();
    }

    function test_coverSitsBetweenHeaderAndBody() {
        const c = make("Card { width: 202; title: 'T'; cover: Component {"
                       + "Image { objectName: 'pic'; source: 'qrc:/tests/crop_quads.png' } } }");
        wait(120);
        const cover = part(c, "cardCover");
        const body = part(c, "cardBody");
        near(cover.y, c.headerHeight, "四段顺序 header → cover → body → footer");
        near(body.y, c.headerHeight + c.coverHeight);
        near(c.implicitHeight, testCase.seam * 2 + c.headerHeight + c.coverHeight + c.bodyHeight);
        const pic = part(cover, "pic");
        near(pic.width, c.width - testCase.seam * 2, "`> * { width: 100% }` ⇒ 封面铺满整幅");
        near(cover.height, pic.implicitHeight, "端口不替图片算等比高，高就是节点自己报的");
        c.destroy();
    }

    // 顶角那 6px 的圆切端口做不到（源项一隐藏 MultiEffect 就拿不到纹理，实测见文件头），
    // 这一节把「端口画成什么样」钉住：矩形裁切生效、封面画到卡片的方角上。
    function test_coverPaintsToSquareCorner() {
        const c = make("Card { width: 202; cover: Component {"
                       + "Image { objectName: 'pic'; source: 'qrc:/tests/crop_quads.png' } } }");
        wait(250);
        const shot = testCase.grabImage(c);
        verify(shot !== undefined, "offscreen 下要能读到像素");
        // 封面左上那块是原图的红，卡片 (1,1) 就是封面的 (0,0)
        const corner = px(shot, c, 1, 1);
        compare(shot.red(corner.x, corner.y), 255, "封面画到方角（端口不切那 6px）");
        compare(shot.green(corner.x, corner.y), 0);
        const bottom = px(shot, c, 1, c.coverHeight);
        compare(shot.blue(bottom.x, bottom.y), 255, "左下是蓝块 ⇒ 封面整幅都在");
        // 本体只有 1px 描边那圈被 clip 之外，正文溢出照样被矩形裁掉
        compare(part(c, "cardContentClip").clip, true);
        c.destroy();
    }

    function test_coverTextSlotIsPlainString() {
        const c = make("Card { width: 202; cover: '封面文字' }");
        wait(60);
        const t = part(c, "cardCoverText");
        compare(t.visible, true);
        compare(t.text, "封面文字");
        compare(t.font.pixelSize, Theme.current.fontSizeRegular, "cover 自己没有字号规则 ⇒ 吃本体 14");
        near(c.coverHeight, t.implicitHeight);
        c.destroy();
    }

    // ---------------- body / children ----------------

    function test_childrenStackInBody() {
        const c = make("Card { width: 300\n"
                       + "Text { objectName: 'a'; text: '第一行'; font.pixelSize: 20 }\n"
                       + "Text { objectName: 'b'; text: '第二行'; font.pixelSize: 20 } }");
        wait(80);
        compare(c.declaredCount, 2);
        const zone = part(c, "cardBodyZone");
        const a = part(zone, "a");
        const b = part(zone, "b");
        near(a.x, 0);
        near(a.y, 0);
        near(b.y, a.height, "block 流：竖着叠，段间没有间距");
        near(c.bodyNodeHeight, a.height + b.height);
        near(c.bodyHeight, testCase.pad * 2 + a.height + b.height);
        const box = part(c, "cardBodyPaddingBox");
        near(box.width, c.width - testCase.seam * 2 - testCase.pad * 2);
        c.destroy();
    }

    function test_bodyTextSeesCardWidthNotPageWidth() {
        const c = make("Card { width: 300\n"
                       + "Text { objectName: 'a'; width: parent.width; text: '正文' } }");
        wait(80);
        const a = part(part(c, "cardBodyZone"), "a");
        near(a.width, c.width - testCase.seam * 2 - testCase.pad * 2,
             "`width: parent.width` 读到的是正文的可用宽（262），不是卡片宽");
        c.destroy();
    }

    // ---------------- loading ----------------

    function test_loadingPlaceholderIsTitleBreakThreeRows() {
        const c = make("Card { width: 300; loading: true\n"
                       + "Text { objectName: 'a'; text: '正文' } }");
        wait(80);
        compare(c.skeletonOn, true);
        const skeleton = part(c, "cardBodySkeleton");
        compare(skeleton.loading, true);
        compare(skeleton.active, true, "index.tsx:191 那个 active 是写死的");
        const holder = part(skeleton, "skeletonPlaceholder");
        const ph = part(holder, "cardLoadingPlaceholder");
        const titleBlock = part(ph, "skeletonTitle");
        compare(titleBlock.width, part(c, "cardBodyPaddingBox").width,
                "占位铺满正文的可用宽（官方那层 div 是块级）");
        const para = part(ph, "skeletonParagraph");
        compare(para.rows, 3, "Skeleton.Paragraph rows={3}");
        near(ph.height, 24 + testCase.line + (3 * 16 + 2 * 10),
             "24 的标题 + 一个 <br/>（继承卡片 20 的行高）+ 三行段落");
        near(c.bodyNodeHeight, ph.height);
        near(c.bodyHeight, testCase.pad * 2 + ph.height);
        c.destroy();
    }

    function test_loadingWithoutChildrenShowsNothing() {
        const c = make("Card { width: 300; loading: true }");
        wait(60);
        compare(c.declaredCount, 0);
        compare(c.skeletonOn, false,
                 "官方是 `{children && <Skeleton loading>}` ⇒ 空卡连 Skeleton 都不挂");
        compare(part(c, "cardBodySkeleton").loading, false);
        near(c.bodyHeight, testCase.pad * 2, "只剩那 40 的内边距");
        const holder = part(c, "cardBodySkeleton");
        compare(testCase.findChild(holder, "cardLoadingPlaceholder") === null, true,
                "没有占位节点被创建");
        c.destroy();
    }

    function test_loadingTogglesBetweenPlaceholderAndChildren() {
        const c = make("Card { width: 300; objectName: 'lc'\n"
                       + "Text { objectName: 'a'; text: '正文' } }");
        wait(80);
        const before = c.implicitHeight;
        c.loading = true;
        wait(80);
        verify(c.implicitHeight > before, "占位比一行正文高");
        const content = part(c, "skeletonContent");
        compare(content.visible, false, "loading 时 children 让位");
        c.loading = false;
        wait(80);
        near(c.implicitHeight, before, "关掉之后回到原来的高");
        compare(part(c, "skeletonContent").visible, true);
        c.destroy();
    }

    function test_ariaBusyHasNoQmlEquivalent() {
        const c = make("Card { width: 300; title: 'T'; Text { text: 'x' } }");
        wait(40);
        compare(c.Accessible.name, "", "没给 aria-label 时 Accessible.name 就是空");
        c.loading = true;
        wait(40);
        // 文档那条「Card loading 时，将开启 aria-busy」在端口无处落地：
        // qquickaccessibleattached_p.h 的 STATE_PROPERTY 名单是 checkable / checked / editable /
        // focusable / focused / multiLine / readOnly / selected / selectable / pressed /
        // checkStateMixed / defaultButton / passwordEdit / selectableText / searchEdit，没有 busy。
        compare(c.Accessible.busy, undefined, "端口不产 aria-busy 的等价物（只记录，不硬造一个）");
        c.destroy();
    }

    function test_ariaLabelMapsToAccessibleName() {
        const c = make("Card { width: 300; ariaLabel: '任务卡片'; Text { text: 'x' } }");
        wait(40);
        compare(c.Accessible.name, "任务卡片");
        c.destroy();
    }

    // ---------------- actions ----------------

    function test_emptyActionsArrayStillDrawsTheSeam() {
        const none = make("Card { width: 300; actions: [] }");
        wait(60);
        compare(none.actionsTaken, true, "官方判据是 Array.isArray(actions)，空数组也算");
        const block = part(none, "cardActions");
        compare(block.visible, true);
        compare(part(none, "cardActionsSeam").visible, true);
        compare(part(none, "cardActionsRow").visible, false, "一条都没有 ⇒ Space 里空");
        near(none.actionsHeight, testCase.gap + testCase.seam + testCase.pad,
             "margin-top 20 + border 1 + padding-top 20，条目高 0");
        near(none.bodyHeight, testCase.pad * 2 + none.actionsHeight);
        none.destroy();
    }

    function test_actionsNotArrayIsSkipped() {
        const c = make("Card { width: 300; actions: 'Rating' }");
        wait(60);
        compare(c.actionsTaken, false, "非数组 ⇒ `Array.isArray` 假 ⇒ 整段不渲染");
        near(c.actionsHeight, 0);
        compare(part(c, "cardActions").visible, false);
        // 字符串也有 `.length`，所以「按不按数组建条目」这一条得单独钉：整段不渲染时
        // 条目里必须一个节点都没有（不能拿 'Rating' 的 5 个字符建 5 条）。
        compare(part(c, "cardActionsRow").children.length, 0);
        compare(c.actionNodes.length, 0);
        c.destroy();
    }

    function test_actionItemsAreTwelveApart() {
        const c = make("Card { width: 300; title: 'T'; Text { text: '正文' }\n"
                       + "actions: ['甲', '乙'] }");
        wait(80);
        compare(c.actionCount, 2);
        const row = part(c, "cardActionsRow");
        compare(row.children.length, 2);
        const first = row.children[0];
        const second = row.children[1];
        near(first.x, 0);
        near(second.x, first.width + testCase.itemGap,
             "index.tsx:199 `spacing={12}`，不是令牌");
        near(row.y, testCase.seam + testCase.pad, "那条 1px 线之上是 padding-top 20");
        const block = part(c, "cardActions");
        near(block.y, testCase.pad + c.bodyNodeHeight + testCase.gap,
             "-body-actions 的 margin-top 20 跟在正文后面");
        near(c.actionsNodeHeight, Math.max(first.height, second.height));
        near(c.bodyHeight, testCase.pad * 2 + c.bodyNodeHeight
            + testCase.gap + testCase.seam + testCase.pad + c.actionsNodeHeight);
        c.destroy();
    }

    function test_actionComponentNodeIsKept() {
        // `Component {}` 不能写在 JS 数组字面量里 ⇒ 先建成对象再赋给 actions
        const c = make("Card { width: 300; actions: []\nText { text: '正文' } }");
        c.actions = [testCase.actionBoxProto];
        wait(80);
        const row = part(c, "cardActionsRow");
        compare(row.children.length, 1);
        const box = part(row, "box");
        near(box.width, 40);
        near(row.height, 8);
        c.destroy();
    }

    function test_actionsRebuildWhenReplaced() {
        const c = make("Card { width: 300; actions: ['甲']; Text { text: 'x' } }");
        wait(60);
        compare(part(c, "cardActionsRow").children.length, 1);
        c.actions = ["甲", "乙", "丙"];
        wait(60);
        compare(c.actionCount, 3);
        compare(part(c, "cardActionsRow").children.length, 3, "换数组要重建，不能留旧节点");
        c.actions = undefined;
        wait(60);
        compare(c.actionsTaken, false);
        compare(part(c, "cardActionsRow").children.length, 0);
        c.destroy();
    }

    // ---------------- footer ----------------

    function test_footerHeightFollowsFooterLine() {
        const off = make("Card { width: 300; footer: '页脚'; Text { text: 'x' } }");
        wait(60);
        const f = part(off, "cardFooterText");
        compare(off.footerTaken, true);
        near(off.footerHeight, testCase.pad * 2 + f.implicitHeight,
             "footerLine 缺省 false ⇒ 那条线本来就没有");
        compare(part(off, "cardFooterSeam").visible, false);
        const on = make("Card { width: 300; footer: '页脚'; footerLine: true;"
                        + " Text { text: 'x' } }");
        wait(60);
        compare(part(on, "cardFooterSeam").visible, true);
        near(on.footerHeight, off.footerHeight + testCase.seam);
        const block = part(on, "cardFooter");
        near(block.y, on.headerHeight + on.coverHeight + on.bodyHeight,
             "footer 排在 body 之后");
        // 线在 footer 的**上沿**（border-top 是相对 footer 自己那条边，画在 padding 盒之上）
        const seam = part(on, "cardFooterSeam");
        near(seam.y, 0, "border-top ⇒ 贴在 footer 顶边");
        near(part(on, "cardFooterPaddingBox").y, testCase.pad + testCase.seam,
             "那条线压在 padding 之上 ⇒ 内容再往下让 1");
        near(part(off, "cardFooterPaddingBox").y, testCase.pad, "没有线时内容就贴那 20");
        off.destroy();
        on.destroy();
    }

    function test_footerEmptyStringIsNoFooter() {
        const c = make("Card { width: 300; footer: '' }");
        wait(60);
        compare(c.footerTaken, false, "官方 `{footer && ...}` 的真值判断");
        near(c.footerHeight, 0);
        compare(part(c, "cardFooter").visible, false);
        c.destroy();
    }

    // ---------------- shadows ----------------

    function test_shadowsOffHasNoCursorAndNoShadow() {
        const c = make("Card { width: 300; title: 'T'; Text { text: 'x' } }");
        wait(60);
        compare(c.shadowSet, false);
        compare(c.shadowShown, false);
        const hover = part(c, "cardHover");
        compare(hover.enabled, false, "没给 shadows ⇒ .semi-card-shadows 那条 cursor 不参与");
        compare(hover.cursorShape, Qt.ArrowCursor);
        near(part(c, "cardShadow").opacity, 0);
        compare(c.z, 0);
        c.destroy();
    }

    function test_shadowsAlwaysShowsShadowAndHand() {
        const c = make("Card { width: 300; shadows: 'always'; Text { text: 'x' } }");
        wait(60);
        compare(c.shadowSet, true);
        compare(c.shadowShown, true);
        near(part(c, "cardShadow").opacity, 1, "always 档阴影恒亮");
        compare(part(c, "cardHover").cursorShape, Qt.PointingHandCursor,
                ".semi-card-shadows { cursor: pointer }");
        near(c.z, 0, "z-index: 1 只写在 -hover 那条里");
        c.destroy();
    }

    function test_shadowsHoverFollowsPointer() {
        const c = make("Card { width: 300; shadows: 'hover'; Text { text: 'x' } }");
        wait(60);
        compare(c.shadowShown, false, "没悬浮时不该有阴影");
        mouseMove(c, c.width / 2, c.height / 2);
        wait(400);            // 300ms 的过渡跑完
        compare(c.shadowShown, true, "-shadows-hover:hover");
        near(part(c, "cardShadow").opacity, 1, "悬浮那拍阴影淡入到满");
        compare(c.z, 1, "z-index: 1：栅格卡片组里让悬浮这张压住邻居的阴影");
        mouseMove(c, c.width + 40, c.height + 40);
        wait(400);
        compare(c.shadowShown, false);
        compare(c.z, 0);
        c.destroy();
    }

    function test_unknownShadowsValueIsTreatedAsNone() {
        const c = make("Card { width: 300; shadows: 'alway'; Text { text: 'x' } }");
        wait(60);
        compare(c.shadowSet, false, "strings.SHADOWS 只有 hover / always");
        near(part(c, "cardShadow").opacity, 0);
        c.destroy();
    }

    // ---------------- 死 prop（CSS-only） ----------------

    function test_stylePropsChangeNothing() {
        const plain = make("Card { width: 300; title: 'T'; footer: 'F'; Text { text: 'x' } }");
        const styled = make("Card { width: 300; title: 'T'; footer: 'F'; Text { text: 'x' }\n"
                            + "bodyStyle: ({ padding: 0, display: 'flex' });"
                            + "headerStyle: ({ background: 'red' });"
                            + "footerStyle: ({ display: 'flex' });"
                            + "style: ({ maxWidth: 100 }); className: 'x' }");
        wait(80);
        near(styled.implicitHeight, plain.implicitHeight,
             "style / *Style / className 只喂 DOM，端口收了不产出差异");
        near(styled.bodyHeight, plain.bodyHeight);
        near(styled.headerHeight, plain.headerHeight);
        near(styled.footerHeight, plain.footerHeight);
        plain.destroy();
        styled.destroy();
    }

    // ---------------- CardMeta ----------------

    function test_metaTitleIsSevenHundred() {
        const m = make("CardMeta { title: 'Semi Doc' }");
        wait(60);
        const t = part(m, "cardMetaTitleText");
        compare(t.font.pixelSize, Theme.current.fontSizeHeader6);
        compare(t.font.weight, Font.Bold,
                "$font-card_title-fontWeight 写的是 700，比 header 那个 600 重一档");
        compare(t.lineHeight, testCase.titleLine, "$font-card_title-lineHeight");
        compare(t.color, Theme.current.colorText0, "$color-card_title-text");
        near(m.implicitHeight, testCase.titleLine);
        m.destroy();
    }

    function test_metaDescriptionStacksUnderTitle() {
        const m = make("CardMeta { title: 'Semi Doc'; description: '全面、易用、优质' }");
        wait(60);
        const t = part(m, "cardMetaTitleText");
        const d = part(m, "cardMetaDescriptionText");
        compare(d.visible, true);
        compare(d.font.pixelSize, Theme.current.fontSizeRegular);
        compare(d.lineHeight, testCase.line);
        compare(d.color, Theme.current.colorText2, "$color-card_description-text");
        near(d.y, t.height, "两个 block div 竖着叠，中间没有间距");
        near(m.implicitHeight, t.height + d.height);
        near(m.implicitWidth, Math.max(t.implicitWidth, d.implicitWidth),
             "块宽是两格取最大（不是相加）");
        // 反向的那一档：标题比描述长 ⇒ 只有「取最大」还成立
        const wide = make("CardMeta { title: '这是一串很长很长的卡片标题'; description: '短' }");
        wait(60);
        const wt = part(wide, "cardMetaTitleText");
        const wd = part(wide, "cardMetaDescriptionText");
        verify(wt.implicitWidth > wd.implicitWidth, "夹具：标题这侧更长");
        near(wide.implicitWidth, wt.implicitWidth);
        near(wide.implicitHeight, wt.height + wd.height);
        wide.destroy();
        m.destroy();
    }

    function test_metaAvatarGapAndCentering() {
        // 头像故意比文字块高一大截 ⇒ 「行内垂直居中」在两坨上都量得出来（等高时两边写法同值）
        const m = make("CardMeta { title: 'Semi Doc'; description: '全面、易用、优质';"
                       + "avatar: Component { Rectangle { objectName: 'av'; width: 72; height: 72 } } }");
        wait(60);
        const av = part(m, "cardMetaAvatar");
        const wrapper = part(m, "cardMetaWrapper");
        near(av.x, 0);
        near(wrapper.x, 72 + testCase.itemGap,
             "$spacing-card_avatar-marginRight = spacing-base-tight（12）");
        near(m.implicitWidth, 72 + testCase.itemGap + wrapper.width);
        near(m.implicitHeight, 72, "align-items: center ⇒ 行高取高的那条（这里是头像）");
        near(av.y, 0);
        near(wrapper.y, (72 - wrapper.height) / 2, "文字块在行内垂直居中");
        verify(72 - wrapper.height > 20, "夹具要保证两坨确实不等高");
        m.destroy();
        // 反向那一档：头像比文字块矮 ⇒ 「头像自己也要居中」才量得出来
        //（上一条里头像是最高那条，居中与贴顶是同一个数）
        const small = make("CardMeta { title: 'Semi Doc'; description: '全面、易用、优质';"
                           + "avatar: Component { Rectangle { objectName: 'sm';"
                           + "width: 20; height: 20 } } }");
        wait(60);
        const sm = part(small, "cardMetaAvatar");
        const w2 = part(small, "cardMetaWrapper");
        near(small.implicitHeight, w2.height, "行高取高的那条（这里是文字块）");
        near(sm.y, (w2.height - 20) / 2, "矮的头像在行内垂直居中，不是贴顶");
        near(w2.y, 0);
        near(small.implicitWidth, 20 + testCase.itemGap + w2.width);
        small.destroy();
    }

    function test_metaEmptyStringSlotsVanish() {
        const m = make("CardMeta { title: ''; description: '' }");
        wait(40);
        compare(m.titleTaken, false);
        compare(m.descriptionTaken, false);
        compare(m.wrapperTaken, false,
                 ":62 `title || description ? <wrapper> : null` ⇒ 两格都空就连 wrapper 都不生成");
        compare(part(m, "cardMetaWrapper").visible, false);
        near(m.implicitWidth, 0);
        near(m.implicitHeight, 0);
        const only = make("CardMeta { avatar: 'A' }");
        wait(40);
        compare(only.avatarTaken, true);
        compare(only.wrapperTaken, false);
        near(only.implicitHeight, part(only, "cardMetaAvatarText").implicitHeight);
        m.destroy();
        only.destroy();
    }

    function test_metaInsideCardBody() {
        const c = make("Card { width: 300; title: 'T'\n"
                       + "CardMeta { objectName: 'm'; title: 'Semi Doc';"
                       + "description: '全面、易用、优质' } }");
        wait(80);
        compare(c.declaredCount, 1);
        const m = part(part(c, "cardBodyZone"), "m");
        near(m.y, 0, "Meta 就是正文里的一个块");
        near(c.bodyNodeHeight, m.implicitHeight);
        near(c.implicitHeight, testCase.seam * 2 + c.headerHeight + c.bodyHeight);
        c.destroy();
    }

    // ---------------- CardGroup ----------------

    function test_groupSpacesChildrenBySpacing() {
        const g = make("CardGroup { width: 600\n"
                       + "Card { width: 260; title: 'a'; Text { text: 'x' } }\n"
                       + "Card { width: 260; title: 'a'; Text { text: 'x' } } }");
        wait(120);
        const items = g.nodes();
        compare(items.length, 2);
        near(items[1].x, 260 + 16, "缺省 spacing 16（代码那条）");
        near(items[0].x, 0);
        compare(g.isGrid, false);
        near(g.horizontalGap, 16);
        near(g.verticalGap, 16, "数字档 ⇒ 横竖同值（Space 的 columnGap 与 rowGap 都写这一个数）");
        near(g.layoutHeight, items[0].height);
        near(g.lineWidth, 260 + 16 + 260);
        g.destroy();
    }

    function test_groupWrapsAndUsesArraySpacing() {
        const g = make("CardGroup { width: 560; spacing: [8, 30]\n"
                       + "Card { width: 260; title: 'a'; Text { text: 'x' } }\n"
                       + "Card { width: 260; title: 'a'; Text { text: 'x' } }\n"
                       + "Card { width: 260; title: 'a'; Text { text: 'x' } } }");
        wait(150);
        near(g.horizontalGap, 8, "[水平, 垂直] 第一格");
        near(g.verticalGap, 30, "第二格 ⇒ rowGap");
        const items = g.nodes();
        near(items[0].x, 0);
        near(items[1].x, 260 + 8);
        near(items[2].x, 0, "260+8+260 = 528 > 560 − 260 ⇒ 第三条换行");
        verify(items[2].y > 0, "第三条在下一行");
        near(items[2].y, items[0].height + 30, "换行的位移就是 rowGap 30");
        g.destroy();
    }

    function test_groupCentersItemsInRow() {
        const g = make("CardGroup { width: 700\n"
                       + "Card { objectName: 'hi'; width: 260; title: 'a'; Text { text: 'x' } }\n"
                       + "Card { objectName: 'lo'; width: 260; title: 'a' } }");
        wait(150);
        const hi = part(g, "hi");
        const lo = part(g, "lo");
        verify(hi.height > lo.height, "先确认两张卡确实一高一矮");
        near(lo.y, (hi.height - lo.height) / 2,
             "Space 缺省 align-items: center ⇒ 矮的那张在行里垂直居中，不是贴顶");
        near(hi.y, 0);
        g.destroy();
    }

    function test_groupNonNumericSpacingIsZero() {
        const g = make("CardGroup { width: 600; spacing: []\n"
                       + "Card { width: 260; title: 'a' }\n"
                       + "Card { width: 260; title: 'a' } }");
        wait(120);
        near(g.horizontalGap, 0, "数组缺第一格 ⇒ columnGap 压根没写进 style ⇒ flex 缺省 0");
        near(g.verticalGap, 0, "同理 rowGap");
        near(g.nodes()[1].x, 260);
        g.destroy();
    }

    function test_groupGridForcesZeroGapAndOverlap() {
        const g = make("CardGroup { width: 600; type: 'grid'; spacing: 24\n"
                       + "Card { objectName: 'g0'; width: 260; title: 'a' }\n"
                       + "Card { objectName: 'g1'; width: 260; title: 'a' } }");
        wait(120);
        compare(g.isGrid, true);
        near(g.horizontalGap, 0, ":52 `spacing={isGrid ? 0 : spacing}` ⇒ spacing 被覆盖");
        near(g.verticalGap, 0);
        const g0 = part(g, "g0");
        const g1 = part(g, "g1");
        near(g1.x, 260 - 1, "margin-left: -1px ⇒ 相邻两张重叠 1 像素（描边合成一条）");
        near(g1.y, g0.y);
        compare(g0.cardGroupGrid, true, "-group-grid .semi-card { border-radius: 0 } 逐张下发");
        near(part(g0, "cardSurface").radius, 0);
        near(g0.cornerRadius, 0);
        g.destroy();
    }

    function test_groupGridRowsAlsoOverlapAndOtherChildrenUntouched() {
        const g = make("CardGroup { width: 500; type: 'grid'\n"
                       + "Card { objectName: 'a'; width: 260; title: '甲'; Text { text: 'x' } }\n"
                       + "Card { objectName: 'b'; width: 260; title: '乙'; Text { text: 'x' } }\n"
                       + "Rectangle { objectName: 'rect'; width: 10; height: 10 } }");
        wait(150);
        const a = part(g, "a");
        const b = part(g, "b");
        near(b.y, a.height - 1, "margin-top: -1px ⇒ 第二行也重叠 1 像素");
        const rect = part(g, "rect");
        compare(rect.cardGroupGrid, undefined, "非卡片子项没有那条规则可下发");
        g.destroy();
    }

    function test_groupFallsBackToMaxContentWidth() {
        // 没有父级给宽 ⇒ 容器宽取「全部塞一行」的 max-content（Space 是 inline-flex）
        const g = make("CardGroup {"
                       + "Card { width: 260; title: 'a'; Text { text: 'x' } }\n"
                       + "Card { width: 260; title: 'a'; Text { text: 'x' } } }");
        g.parent = null;          // createQmlObject 不给 null 档，改成就地脱离父级
        verify(g.parent === null, "无父级那一支");
        wait(150);
        near(g.width, 260 + 16 + 260, "缺省宽 = max-content");
        near(g.nodes()[1].x, 276, "放得下就不换行");
        g.destroy();
    }

    // ---------------- 端口的兜底宽与配色 ----------------

    function test_widthlessCardWithWrappingChildDoesNotLoop() {
        const c = make("Card { Text { objectName: 'a'; width: parent.width;"
                       + "text: '正文'; wrapMode: Text.WordWrap; font.pixelSize: 20 } }");
        wait(150);
        const a = part(part(c, "cardBodyZone"), "a");
        near(c.bodyNaturalWidth, a.implicitWidth,
             "正文档的自然宽逐个子项读 implicitWidth（读 Column.implicitWidth 会成环）");
        near(c.width, a.implicitWidth + testCase.pad * 2, "卡片宽 = 那条自然宽 + 20×2");
        near(a.width, c.width - testCase.seam * 2 - testCase.pad * 2,
             "填充式子项吃的是卡片给的宽，不是反过来定义卡片宽");
        c.destroy();
    }

    function test_colorsFollowTheTokens() {
        Theme.mode = Theme.Dark;
        const c = make("Card { width: 300; title: 'T'; cover: '封面'; footer: '页脚';"
                       + " footerLine: true; actions: ['甲']; Text { text: 'x' } }");
        wait(80);
        const surface = part(c, "cardSurface");
        compare(surface.color, Theme.current.colorBg0, "$color-card-bg-default");
        compare(surface.border.color, Theme.current.colorBorder, "$color-card-border");
        compare(part(c, "cardHeaderSeam").color, Theme.current.colorBorder, "headerLine 那条线");
        compare(part(c, "cardFooterSeam").color, Theme.current.colorBorder, "footerLine 那条线");
        compare(part(c, "cardActionsSeam").color, Theme.current.colorBorder, "操作区那条线");
        // card.scss 只给 -body 定字色，其余三段没有颜色规则 ⇒ 端口落 text-0（不是组件规格）
        compare(part(c, "cardCoverText").color, Theme.current.colorText0);
        compare(part(c, "cardFooterText").color, Theme.current.colorText0);
        compare(part(c, "cardActionsRow").children[0].color, Theme.current.colorText1,
                "actions 在 -body 里 ⇒ 吃 text-1");
        Theme.mode = Theme.Light;
        c.destroy();
    }

    function test_customHeaderComponentSlot() {
        const c = make("Card { width: 300; title: '这是一串很长的卡片标题文字';"
                       + " header: Component { Rectangle { objectName: 'hd'; width: 120; height: 30 } } }");
        wait(80);
        compare(part(c, "cardHeaderText").visible, false, "header 给的是 Component ⇒ 不走字符串档");
        const loader = part(c, "cardHeaderNode");
        compare(loader.active, true);
        near(part(loader, "hd").height, 30);
        near(c.headerNodeHeight, 30, "覆盖档的高由那一格报，title 不参与");
        near(c.headerNaturalWidth, testCase.pad * 2 + 120, "自然宽也只按这一格算");
        c.destroy();
    }

    function test_declaredCountTracksLateChildren() {
        const c = make("Card { width: 300 }");
        wait(60);
        compare(c.declaredCount, 0);
        const zone = part(c, "cardBodyZone");
        Qt.createQmlObject("import QtQuick; Text { objectName: 'late'; text: '后加的正文' }",
                           zone, "lateChild");
        wait(120);
        compare(c.declaredCount, 1, "后挂进来的子项要进名单");
        c.loading = true;
        wait(80);
        compare(c.skeletonOn, true, "有了 children 才允许出占位");
        c.destroy();
    }

    function test_metaComponentSlotsStack() {
        const m = make("CardMeta { title: Component {"
                       + "Rectangle { objectName: 'tn'; width: 90; height: 30 } }\n"
                       + "description: Component { Rectangle { objectName: 'dn'; width: 60; height: 20 } } }");
        wait(120);
        near(part(m, "cardMetaTitleNode").y, 0);
        near(part(m, "cardMetaDescriptionNode").y, 30, "Component 档也是「描述接在标题下面」");
        compare(part(m, "tn").objectName, "tn", "两个 Component 档都真的载出了节点");
        near(m.implicitWidth, 90, "块宽两格取最大");
        near(m.implicitHeight, 50);
        m.destroy();
    }

    // ---------------- CardGroup：运行时的重排、名单与两行几何 ----------------

    function test_groupRelayoutOnWidthChange() {
        const g = make("CardGroup { width: 600\n"
                       + "Card { objectName: 'a'; width: 260; title: '甲'; Text { text: 'x' } }\n"
                       + "Card { objectName: 'b'; width: 260; title: '乙'; Text { text: 'x' } } }");
        wait(200);
        near(part(g, "b").x, 276, "一行放得下两条");
        g.width = 500;
        wait(200);
        const b = part(g, "b");
        near(b.x, 0, "容器窄下来 ⇒ 自动换行");
        verify(b.y > 0, "第二条要挪到第二行");
        g.destroy();
    }

    function test_groupRelayoutOnSpacingAndTypeChange() {
        const g = make("CardGroup { width: 600\n"
                       + "Card { objectName: 'a'; width: 260; title: '甲'; Text { text: 'x' } }\n"
                       + "Card { objectName: 'b'; width: 260; title: '乙'; Text { text: 'x' } } }");
        wait(200);
        const b = part(g, "b");
        near(b.x, 276);
        g.spacing = 24;
        wait(150);
        near(b.x, 284, "spacing 改了要重排");
        g.spacing = [8, 30];
        wait(150);
        near(b.x, 268, "换成数组档");
        g.type = "grid";
        wait(150);
        near(b.x, 259, "type 改 grid ⇒ 间距清零 + 相邻重叠 1px");
        near(g.overlap, 1);
        g.type = "";
        g.spacing = 16;
        wait(150);
        near(b.x, 276, "改回普通档也要重排回来");
        g.destroy();
    }

    function test_groupTwoLineExtents() {
        // 夹具刻意让**第二行比第一行宽**，这样「组宽 = 最宽那行」与「组宽 = 第一行」分得开
        const g = make("CardGroup { width: 560\n"
                       + "Card { objectName: 'a'; width: 260; title: '甲'; Text { text: 'x' } }\n"
                       + "Card { objectName: 'b'; width: 300; title: '乙'; Text { text: 'x' } }\n"
                       + "Card { objectName: 'c'; width: 250; title: '丙'; Text { text: 'x' } } }");
        wait(300);
        const a = part(g, "a");
        const b = part(g, "b");
        const c = part(g, "c");
        near(a.x, 0);
        near(b.x, 0, "260 + 16 + 300 = 576 > 560 ⇒ 第二条换行");
        near(b.y, a.height + 16, "行顶 = 上一行行高 + rowGap");
        near(c.x, 0, "316 + 250 = 566 也超 ⇒ 第三条再换一行");
        verify(c.y > b.y, "确实排到了第三行");
        near(g.lineWidth, 300, "组宽 = 最宽那行（第二行那条 300），不是第一行的 260");
        near(g.layoutHeight, a.height + 16 + b.height + 16 + c.height,
             "组高 = 三行行高 + 两条 rowGap");
        g.destroy();
    }

    function test_groupCountsRepeaterDelegatesOnly() {
        const g = make("CardGroup { width: 600\n"
                       + "Repeater { model: 2\n"
                       + "delegate: Card { width: 200; title: '甲'; Text { text: 'x' } } } }");
        wait(250);
        compare(g.nodes().length, 2, "Qt 6.11 里 Repeater 自己也是子项，那个空壳不能进名单");
        near(g.nodes()[1].x, 200 + 16, "空壳进名单的话会多出一格间距");
        near(g.lineWidth, 200 + 16 + 200);
        g.destroy();
    }

    function test_groupChildSeesContainerWidth() {
        const g = make("CardGroup { width: 600\n"
                       + "Card { objectName: 'full'; width: parent.width; title: '甲'; Text { text: 'x' } } }");
        wait(250);
        near(part(g, "full").width, 600, "宿主铺满组宽 ⇒ 子项的 width: parent.width 读到容器宽");
        near(g.lineWidth, 600);
        g.destroy();
    }

    function test_groupReactsToChildResize() {
        const g = make("CardGroup { width: 600\n"
                       + "Card { objectName: 'a'; width: 260; title: '甲'; Text { text: 'x' } }\n"
                       + "Card { objectName: 'b'; width: 260; title: '乙'; Text { text: 'x' } } }");
        wait(250);
        const a = part(g, "a");
        near(g.layoutHeight, a.height, "一开始两条等高");
        part(g, "b").footer = '页脚';
        wait(250);
        const b = part(g, "b");
        verify(b.height > a.height, "加页脚那条确实长高了（组这边一个属性都没动）");
        near(g.layoutHeight, b.height, "行高跟着最高的那条走");
        g.destroy();
    }

    function test_groupTracksAddedChild() {
        const g = make("CardGroup { width: 600\n"
                       + "Card { objectName: 'a'; width: 260; title: '甲'; Text { text: 'x' } } }");
        wait(200);
        compare(g.nodes().length, 1);
        near(g.lineWidth, 260);
        Qt.createQmlObject("import QtQuick; import Semi; Card { objectName: 'b';"
                           + " width: 200; title: '乙'; Text { text: 'x' } }",
                           part(g, "cardGroupHost"), "lateGroupCard");
        wait(250);
        compare(g.nodes().length, 2, "新挂上的卡片要进名单");
        near(g.nodes()[1].x, 260 + 16, "并且排到第一行后面");
        g.destroy();
    }

    function test_groupPartialArraySpacing() {
        const g = make("CardGroup { width: 600; spacing: [8]\n"
                       + "Card { objectName: 'a'; width: 260; title: '甲'; Text { text: 'x' } }\n"
                       + "Card { objectName: 'b'; width: 260; title: '乙'; Text { text: 'x' } }\n"
                       + "Card { objectName: 'c'; width: 100; title: '丙'; Text { text: 'x' } } }");
        wait(300);
        near(g.horizontalGap, 8, "数组第一格");
        near(g.verticalGap, 0, "缺第二格 ⇒ rowGap 压根没写进 style ⇒ flex 缺省 0");
        near(part(g, "b").x, 268, "260 + 8");
        near(part(g, "c").x, 0, "268 + 8 + 100 = 376 ≤ 600，第三条其实放得下——它是 536 + 100 才挤不下的");
        verify(part(g, "c").y > 0, "换行");
        near(part(g, "c").y, part(g, "a").height, "行间距 0：第二行的行顶就是第一行的行高");
        near(g.layoutHeight, part(g, "a").height + part(g, "c").height);
        g.destroy();
    }

    function test_groupStringSpacingTokens() {
        const tight = make("CardGroup { width: 600; spacing: 'tight'\n"
                           + "Card { objectName: 'a'; width: 260; title: '甲'; Text { text: 'x' } }\n"
                           + "Card { objectName: 'b'; width: 260; title: '乙'; Text { text: 'x' } } }");
        wait(200);
        near(tight.horizontalGap, Theme.current.spacingTight,
             "Space 的字符串档：'tight' = $spacing-space-tight（8）");
        near(part(tight, "b").x, 260 + Theme.current.spacingTight);
        const loose = make("CardGroup { width: 600; spacing: ['loose', 'medium'] }");
        wait(100);
        near(loose.horizontalGap, Theme.current.spacingLoose, "'loose' = spacing-loose（20）");
        near(loose.verticalGap, Theme.current.spacingBase, "'medium' = spacing-base（16）");
        const junk = make("CardGroup { width: 600; spacing: 'huge' }");
        wait(100);
        near(junk.horizontalGap, 0, "类名没命中 ⇒ 官方也是 gap 不设");
        tight.destroy();
        loose.destroy();
        junk.destroy();
    }

        // ---------------- 组合：官方 demo 的那几种摆法 ----------------

    function test_flexibleCardWithCoverFooterAndExtra() {
        const c = make("Card { width: 340; title: Component {"
                       + "CardMeta { objectName: 'm'; title: 'Semi Doc';"
                       + "description: '全面、易用、优质' } }\n"
                       + "headerExtraContent: 'More'; footer: '底部'; footerLine: true;"
                       + "cover: Component { Rectangle { objectName: 'cv'; width: 300; height: 120 } }\n"
                       + "Text { objectName: 'body'; text: '正文' } }");
        wait(150);
        const m = part(c, "m");
        near(c.headerNodeHeight, m.implicitHeight, "title 给的是 Meta ⇒ 高由它报");
        near(part(c, "cardCover").height, 120);
        near(part(c, "cardBody").y, c.headerHeight + 120);
        near(part(c, "cardFooter").y, c.headerHeight + 120 + c.bodyHeight);
        near(c.implicitHeight, testCase.seam * 2 + c.headerHeight + 120 + c.bodyHeight
            + c.footerHeight);
        compare(part(c, "cardCover").y, c.headerHeight, "有 header ⇒ 封面不在顶上");
        c.destroy();
    }

    function test_innerCardFlowsAsBodyChild() {
        const c = make("Card { width: 600; title: 'Card title'\n"
                       + "Card { objectName: 'inner'; width: parent.width; title: 'Inner';"
                       + "Text { text: 'i' } } }");
        wait(150);
        const inner = part(c, "inner");
        near(inner.width, c.width - testCase.seam * 2 - testCase.pad * 2,
             "内嵌卡吃正文的可用宽（官方 demo 里就是那一档）");
        near(inner.x, 0);
        near(c.bodyNodeHeight, inner.height);
        // 内层卡自己那 20 的内边距不能漏
        near(inner.bodyHeight, testCase.pad * 2 + part(inner, "cardBodyZone").height);
        c.destroy();
    }

    function test_sectionsStackWithoutGap() {
        const c = make("Card { width: 202; title: 'T'; headerLine: false;"
                       + "cover: Component { Rectangle { objectName: 'cv'; width: 200; height: 60 } }\n"
                       + "Text { objectName: 'body'; text: '正文' }\n"
                       + "footer: 'F'; footerLine: true }");
        wait(150);
        near(part(c, "cardCover").y, c.headerHeight, "段与段之间没有额外间距");
        near(part(c, "cardBody").y, c.headerHeight + c.coverHeight);
        near(part(c, "cardFooter").y, c.headerHeight + c.coverHeight + c.bodyHeight);
        near(c.implicitHeight, part(c, "cardFooter").y + c.footerHeight + testCase.seam * 2);
        c.destroy();
    }

    function test_contentClipRectanglesTheOverflow() {
        const c = make("Card { width: 200\n"
                       + "Rectangle { objectName: 'wide'; width: 400; height: 20 } }");
        wait(80);
        const clip = part(c, "cardContentClip");
        compare(clip.clip, true, "本体 overflow: hidden 的矩形那半");
        near(clip.width, c.width - testCase.seam * 2);
        near(part(c, "cardSurface").radius, Theme.current.radiusMedium);
        const wide = part(clip, "wide");
        near(wide.width, 400, "端口不替节点夹宽，靠 clip 挡住溢出");
        c.destroy();
    }

    function test_gridCardFromGroupIsStillMeasurableAlone() {
        // 单独的卡不该被 grid 那条规则影响
        const c = make("Card { width: 300; title: 'T'; Text { text: 'x' } }");
        wait(60);
        compare(c.cardGroupGrid, false);
        near(part(c, "cardSurface").radius, Theme.current.radiusMedium);
        c.destroy();
    }

    function test_groupWithoutChildrenIsZero() {
        const g = make("CardGroup { width: 400 }");
        wait(60);
        compare(g.nodes().length, 0);
        near(g.layoutHeight, 0);
        near(g.lineWidth, 0);
        near(g.implicitWidth, 0, "max-content 也是 0");
        g.destroy();
    }
}
