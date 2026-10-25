import QtQuick
import QtTest
import Semi

// Empty 空状态。规格照 packages/semi-ui/empty/index.tsx（EmptyProps :17-27、缺省 :35-37、
// render :78-134）与 packages/semi-foundation/empty/{empty.scss,variables.scss}，
// 标题那一档的字号/行高再往下是 semi-foundation/typography/typography.scss 的 h4/h6
// 与 semi-theme-default/scss/variables.scss 的 $font-size-header-4 = 20 / -6 = 16。
//
// 端口口径（都在 src/Empty.qml 头注释里）：
//   · 三块都按真值判断，空串算没给；但 `image` 的字符串档**不看真值**（'' 也算有图）。
//   · 内容那层永远渲染 ⇒ 只给图时列档仍比图高 24、行档仍比图宽 32。
//   · style / imageStyle / className 收了不产出可见差异；sprite 档（{id}）收了不画。
//
// 夹具是测试目标资源里的 qrc:/tests/img_wide.png（480×270）。用例跑在 900×700 的窗口里。
TestCase {
    id: testCase

    name: "Empty"
    when: windowShown
    width: 900
    height: 700

    readonly property string wide: "qrc:/tests/img_wide.png"
    readonly property string tall: "qrc:/tests/img_tall.png"

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
    }

    // 断言失败会跳过用例末尾的 destroy ⇒ 残留实例会继续参与布局
    function cleanup() {
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    function make(qml) {
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "empty");
    }

    function part(root, name) {
        return testCase.findChild(root, name);
    }

    function waitTrue(fn, message) {
        tryVerify(fn, 1500);
        verify(fn(), message);
    }

    // 字符串档的图是异步加载的，尺寸要等 sourceSize 到位
    function waitImage(root) {
        const img = part(root, "emptyUrlImage");
        verify(img !== null, "字符串档要有一只 Image");
        tryCompare(img, "status", Image.Ready);
        compare(img.status, Image.Ready, "夹具图要能加载成功");
        waitTrue(function () { return img.sourceSize.width > 0; }, "sourceSize 要报得出尺寸");
        return img;
    }

    // ---------------- 属性面与缺省 ----------------

    function test_officialPropDefaults() {
        const e = make("Empty {}");
        compare(e.layout, "vertical", "index.tsx:36 唯一那条缺省");
        verify(e.image === undefined, "image 官方没有缺省（旧端口那条自造图撤了）");
        verify(e.title === undefined, "title 没有缺省");
        verify(e.description === undefined, "description 没有缺省（旧端口写死「暂无数据」是错的）");
        verify(e.darkModeImage === undefined);
        verify(e.imageStyle === undefined);
        verify(e.style === undefined);
        verify(e.className === undefined);
        e.destroy();
    }

    function test_nothingGivenIsTwentyFourTall() {
        // 内容那层无条件渲染 ⇒ 列档那 24 恒在，整件是 24 高、0 宽
        const e = make("Empty {}");
        compare(e.implicitHeight, 24, "空的 .semi-empty-content 也带 margin-top: 24");
        compare(e.implicitWidth, 0);
        e.destroy();
    }

    // ---------------- 三块的真值门槛 ----------------

    function test_descriptionOnlyRendersAtColumnTop() {
        const e = make('Empty { description: "空空如也" }');
        const desc = part(e, "emptyDescription");
        verify(desc !== null && desc.visible, "给了描述就要有这一行");
        compare(desc.text, "空空如也");
        compare(desc.y, 0, "没有标题 ⇒ 相邻兄弟那条 16 不成立，顶到 0");
        compare(e.implicitHeight, 24 + desc.height);
        e.destroy();
    }

    function test_emptyStringsRenderNothing() {
        const e = make('Empty { title: ""; description: ""; layout: "vertical" }');
        verify(!part(e, "emptyTitle").visible, "空串走 index.tsx:116 的三元 ⇒ 整块不渲染");
        verify(!part(e, "emptyDescription").visible);
        compare(e.implicitHeight, 24, "只剩那个无条件的内容层");
        e.destroy();
    }

    function test_titleOnlyRendersWithoutTheSixteen() {
        const e = make('Empty { title: "只有标题" }');
        const title = part(e, "emptyTitle");
        verify(title.visible);
        compare(title.y, 0);
        compare(e.implicitHeight, 24 + title.height);
        e.destroy();
    }

    // ---------------- 标题字号跟着「有没有图」变 ----------------

    function test_titleIsHeading4WhenImageGiven() {
        const e = make('Empty { image: ({ id: "a-symbol" }); title: "有图" }');
        const title = part(e, "emptyTitle");
        verify(e.hasImage, "对象带 id 也算有图（index.tsx:86 那一支）");
        compare(title.font.pixelSize, 20, "$font-size-header-4");
        compare(title.lineHeight, 28, "font-size-header mixin 里 h4 的行高");
        compare(title.font.weight, Font.DemiBold, "标题字重 600");
        e.destroy();
    }

    function test_titleIsHeading6AndLightWhenNoImage() {
        const e = make('Empty { title: "没图" }');
        const title = part(e, "emptyTitle");
        verify(!e.hasImage);
        compare(title.font.pixelSize, 16, "$font-size-header-6");
        compare(title.lineHeight, 22, "mixin 里 h6 的行高");
        compare(title.font.weight, Font.Normal, "index.tsx:108 那条内联 fontWeight: 400 盖掉 600");
        e.destroy();
    }

    function test_emptyStringImageStillCountsAsImage() {
        // typeof '' === 'string' 先命中，真值判断在官方的图那一支上压根没跑
        const e = make('Empty { image: ""; title: "空串图" }');
        verify(e.hasImage, "'' 在官方也是「有图」");
        compare(part(e, "emptyTitle").font.pixelSize, 20);
        e.destroy();
    }

    function test_spriteIdObjectCountsAsImageButDrawsNothing() {
        const e = make('Empty { image: ({ id: "sym", viewBox: "0 0 20 20" }); title: "sprite" }');
        verify(e.hasImage);
        compare(e.imageNaturalWidth, 0, "<use xlink:href> 在 Qt 侧没有对应物 ⇒ 不画");
        compare(e.imageNaturalHeight, 0);
        verify(!part(e, "emptyUrlImage").visible);
        verify(part(e, "emptyImageLoader").item === null);
        compare(part(e, "emptyTitle").font.pixelSize, 20, "但标题那一档仍按「有图」走");
        e.destroy();
    }

    // ---------------- image 三形：URL / 节点 ----------------

    function test_imageUrlTakesNaturalSize() {
        const e = make('Empty { image: "qrc:/tests/img_wide.png"; title: "宽图" }');
        const img = waitImage(e);
        compare(img.source, "qrc:/tests/img_wide.png");
        compare(e.imageNaturalWidth, 480);
        compare(e.imageNaturalHeight, 270);
        verify(img.visible, "字符串档那只 Image 要显示出来");
        compare(e.implicitWidth, 480, "列档取图与内容的较大者");
        compare(e.implicitHeight, 270 + 24 + part(e, "emptyTitle").height);
        e.destroy();
    }

    function test_svgImageTakesLogicalSizeNotSourceSize() {
        // SVG 的 `sourceSize` 会跟设备像素比放大（cocoa 2× 下那张 200×200 报成 400×400），
        // 图块尺寸必须认 implicit 那一套 —— 错了会把占位图整块撑大一倍
        const e = make('Empty { image: "qrc:/tests/square_200.svg"; title: "方图" }');
        const img = part(e, "emptyUrlImage");
        tryCompare(img, "status", Image.Ready);
        compare(img.status, Image.Ready, "SVG 夹具要能加载成功");
        waitTrue(function () { return img.implicitWidth > 0; });
        compare(img.implicitWidth, 200);
        compare(e.imageNaturalWidth, img.implicitWidth, "读 implicit，不读 sourceSize");
        compare(e.imageNaturalHeight, img.implicitHeight);
        compare(e.implicitWidth, 200);
        e.destroy();
    }

    function test_imageNodeRendersTheComponentItself() {
        const e = make('Empty {\n'
            + '    image: Component { Rectangle { width: 150; height: 150; color: "red" } }\n'
            + '    title: "节点图"\n'
            + '}');
        const loader = part(e, "emptyImageLoader");
        waitTrue(function () { return loader.item !== null; }, "节点档要载出来");
        compare(loader.item.width, 150);
        compare(e.imageNaturalWidth, 150);
        compare(e.imageNaturalHeight, 150);
        verify(!part(e, "emptyUrlImage").visible, "节点档不该同时有那只 Image");
        compare(part(e, "emptyTitle").font.pixelSize, 20);
        e.destroy();
    }

    function test_imageAltComesFromDescription() {
        // index.tsx:81 —— 描述是字符串就拿它当 alt，否则 'empty'
        const withText = make('Empty { image: "qrc:/tests/img_wide.png"; description: "暂无内容" }');
        compare(waitImage(withText).Accessible.name, "暂无内容");
        withText.destroy();

        const nodeDescription = make('Empty {\n'
            + '    image: "qrc:/tests/img_wide.png"\n'
            + '    description: Component { Text { text: "富内容" } }\n'
            + '}');
        compare(waitImage(nodeDescription).Accessible.name, "empty", "描述不是字符串 ⇒ 落 'empty'");
        nodeDescription.destroy();
    }

    // ---------------- darkModeImage ----------------

    function test_darkModeImageSwapsWithThemeMode() {
        const e = make('Empty { image: "qrc:/tests/img_wide.png"; '
            + 'darkModeImage: "qrc:/tests/img_tall.png"; title: "换图" }');
        waitImage(e);
        compare(part(e, "emptyUrlImage").source, "qrc:/tests/img_wide.png", "浅色取 image");
        Theme.mode = Theme.Dark;
        const dark = part(e, "emptyUrlImage");
        tryCompare(dark, "source", "qrc:/tests/img_tall.png");
        compare(dark.source, "qrc:/tests/img_tall.png", "暗色取 darkModeImage");
        waitTrue(function () { return e.imageNaturalWidth === 270; }, "尺寸要跟着换成竖图");
        Theme.mode = Theme.Light;
        e.destroy();
    }

    function test_darkModeWithoutDarkImageFallsBackToImage() {
        const e = make('Empty { image: "qrc:/tests/img_wide.png"; title: "没暗色档" }');
        waitImage(e);
        Theme.mode = Theme.Dark;
        waitTrue(function () { return String(part(e, "emptyUrlImage").source) === "qrc:/tests/img_wide.png"; },
            "index.tsx:82 是真值档 ⇒ 没给 darkModeImage 就退回 image");
        Theme.mode = Theme.Light;
        e.destroy();
    }

    function test_darkModeImageAloneOnlyCountsInDark() {
        const e = make('Empty { darkModeImage: ({ id: "dark-only" }); title: "只有暗色图" }');
        verify(!e.hasImage, "浅色下这份图不算有图 ⇒ 标题走 heading 6");
        compare(part(e, "emptyTitle").font.pixelSize, 16);
        Theme.mode = Theme.Dark;
        waitTrue(function () { return e.hasImage; }, "暗色下换成 darkModeImage ⇒ 有图了");
        compare(part(e, "emptyTitle").font.pixelSize, 20);
        Theme.mode = Theme.Light;
        e.destroy();
    }

    // ---------------- 列档几何 ----------------

    function test_verticalStacksAndCenters() {
        const e = make('Empty {\n'
            + '    image: Component { Rectangle { width: 100; height: 60; color: "blue" } }\n'
            + '    title: "标题"\n    description: "描述"\n'
            + '}');
        const shell = part(e, "emptyImageShell");
        const content = part(e, "emptyContentShell");
        waitTrue(function () { return shell.width === 100; }, "图块要排出来");
        compare(content.y, 60 + 24, "vertical：内容层 margin-top 24");
        compare(shell.x, (e.width - 100) / 2, "align-items: center ⇒ 图水平居中");
        compare(content.x, (e.width - content.width) / 2, "内容层也水平居中");
        compare(content.x + content.width / 2, shell.x + shell.width / 2, "同一根中线");
        compare(e.implicitHeight, 60 + 24 + content.height);
        e.destroy();
    }

    function test_verticalCentersTextButHorizontalDoesNot() {
        const v = make('Empty { title: "标题"; description: "描述" }');
        compare(part(v, "emptyTitle").horizontalAlignment, Text.AlignHCenter,
            "vertical 那档给 title / description 都写了 text-align: center");
        compare(part(v, "emptyDescription").horizontalAlignment, Text.AlignHCenter);
        v.destroy();

        const h = make('Empty { title: "标题"; description: "描述"; layout: "horizontal" }');
        compare(part(h, "emptyTitle").horizontalAlignment, Text.AlignLeft,
            "horizontal 没有那条 text-align ⇒ 左对齐");
        compare(part(h, "emptyDescription").horizontalAlignment, Text.AlignLeft);
        h.destroy();
    }

    function test_verticalCentersNarrowerImageAgainstWiderContent() {
        // 图 40 宽、标题更长 ⇒ align-items: center 要真转出非 0 的 x
        const e = make('Empty {\n'
            + '    image: Component { Rectangle { width: 40; height: 30 } }\n'
            + '    title: "这是一条比图宽得多的标题文字"\n'
            + '}');
        const shell = part(e, "emptyImageShell");
        const content = part(e, "emptyContentShell");
        waitTrue(function () { return content.width > 40; }, "内容要比图宽，否则居中无处可用");
        compare(e.implicitWidth, content.width, "列档 implicitWidth 取两者较大 ⇒ 这里是内容");
        compare(shell.x, (e.width - 40) / 2, "图按中线摆，不是贴左");
        verify(shell.x > 0, "图比内容窄 ⇒ 居中必须真的挪开");
        compare(content.x, 0);
        e.destroy();
    }

    function test_titleThenDescriptionGapIsSixteen() {
        const e = make('Empty { title: "标题"; description: "描述" }');
        const title = part(e, "emptyTitle");
        const desc = part(e, "emptyDescription");
        waitTrue(function () { return title.height > 0; }, "标题要排出来");
        compare(desc.y, title.height + 16, "&-title + &-description ⇒ 16");
        e.destroy();
    }

    // ---------------- 行档几何 ----------------

    function test_horizontalPlacesContentRightWithThirtyTwo() {
        const e = make('Empty {\n'
            + '    layout: "horizontal"\n'
            + '    image: Component { Rectangle { width: 100; height: 60; color: "blue" } }\n'
            + '    title: "标题"\n    description: "描述"\n'
            + '}');
        const shell = part(e, "emptyImageShell");
        const content = part(e, "emptyContentShell");
        waitTrue(function () { return shell.width === 100; }, "图块要排出来");
        compare(shell.x, 0);
        compare(shell.y, 0, "行档图在左上（justify-content 那层是 shrink-to-fit，居中无处可用）");
        compare(content.x, 100 + 32, "horizontal：内容层 margin-left 32");
        compare(content.y, 0);
        compare(e.implicitWidth, 100 + 32 + content.width);
        e.destroy();
    }

    function test_horizontalImageOnlyStillCostsThirtyTwo() {
        const e = make('Empty { layout: "horizontal"; '
            + 'image: Component { Rectangle { width: 80; height: 40; color: "green" } } }');
        waitTrue(function () { return part(e, "emptyImageShell").width === 80; });
        compare(e.implicitWidth, 80 + 32, "内容层无条件存在 ⇒ 那 32 也无条件");
        compare(e.implicitHeight, 40, "行档取图与内容的较大高");
        e.destroy();
    }

    // ---------------- footer（官方 children） ----------------

    function test_footerHoldsDeclaredChildrenWithoutSpacing() {
        const e = make('Empty {\n'
            + '    title: "标题"\n'
            + '    Rectangle { objectName: "footA"; width: 40; height: 20; color: "red" }\n'
            + '    Rectangle { objectName: "footB"; width: 30; height: 20; color: "blue" }\n'
            + '}');
        const footer = part(e, "emptyFooter");
        waitTrue(function () { return footer.implicitWidth > 0; }, "子项要进 footer");
        verify(footer.visible, "有声明式子项 ⇒ footerTaken 要成立");
        compare(footer.implicitWidth, 70, "官方那个 div 里行内子项并排、且没有间距");
        compare(part(e, "footA").x, 0);
        compare(part(e, "footB").x, 40, "spacing: 0 ⇒ 第二颗紧贴着第一颗");
        // 图 0 + 内容层 24 + 标题 22 + footer 自己的 24 + 条目高 20
        compare(e.implicitHeight, 24 + part(e, "emptyTitle").height + 24 + 20,
            "footerTaken 还要把高度算进 implicitHeight");
        e.destroy();
    }

    function test_footerGapIsTwentyFourUnconditional() {
        const onlyFooter = make('Empty { Rectangle { width: 40; height: 20 } }');
        waitTrue(function () { return part(onlyFooter, "emptyFooter").childrenRect.height > 0; });
        compare(part(onlyFooter, "emptyFooter").y, 24, "footer 的 24 不是相邻兄弟规则，恒给");
        onlyFooter.destroy();

        const withTitle = make('Empty {\n'
            + '    title: "标题"\n'
            + '    Rectangle { width: 40; height: 20 }\n'
            + '}');
        const title = part(withTitle, "emptyTitle");
        waitTrue(function () { return title.height > 0; });
        compare(part(withTitle, "emptyFooter").y, title.height + 24);
        withTitle.destroy();

        // 三块齐了才走 descriptionTaken 那一支
        const all = make('Empty {\n'
            + '    title: "标题"\n'
            + '    description: "描述"\n'
            + '    Rectangle { width: 40; height: 20 }\n'
            + '}');
        const allDesc = part(all, "emptyDescription");
        waitTrue(function () { return allDesc.height > 0; });
        compare(part(all, "emptyFooter").y, allDesc.y + allDesc.height + 24,
            "footer 的 24 是从描述那一行底下再往下");
        all.destroy();
    }

    // ---------------- 换行与可用宽 ----------------

    function test_narrowWidthWrapsAndHeightFollows() {
        const long = "这是一段很长的描述文本，当文本过长的时候推荐使用这种布局形式。"
            + "这是一段很长的描述文本，当文本过长的时候推荐使用这种布局形式。";
        const e = make('Empty {\n'
            + '    layout: "horizontal"\n'
            + '    width: 800\n'
            + '    title: "创建成功"\n'
            + '    image: Component { Rectangle { width: 150; height: 150 } }\n'
            + '    description: "' + long + '"\n'
            + '}');
        const desc = part(e, "emptyDescription");
        const content = part(e, "emptyContentShell");
        waitTrue(function () { return content.width > 0; }, "内容层要拿到宽度");
        compare(content.width, 800 - 150 - 32, "行档可用宽 = 外层宽 - 图 - 32");
        verify(desc.height > 20, "长文本要换成多行");
        compare(e.implicitHeight, Math.max(150, content.height), "implicitHeight 跟着换行后的高度");
        e.destroy();
    }

    function test_cjkDescriptionDoesNotWrapAndMeasurersStayHidden() {
        const e = make('Empty { description: "当前功能暂未开放，敬请期待。" }');
        const desc = part(e, "emptyDescription");
        waitTrue(function () { return desc.height > 0; });
        compare(desc.lineCount, 1, "描述同样按量测件给宽，少算几个像素就把最后一个字挤下去");
        // 量测件只量不画：它在 (0,0)、不换行，一旦可见就会在换行那档里盖出一条超长的字
        verify(!part(e, "emptyTitleMeasurer").visible, "量测件不能参与绘制");
        verify(!part(e, "emptyDescriptionMeasurer").visible, "量测件不能参与绘制");
        e.destroy();
    }

    function test_cjkTitleDoesNotWrapAtItsOwnNaturalWidth() {
        // 盒宽取 TextMetrics 时，CJK 那串会被 TextMetrics 与 Text 排版的那 ≈1.8px 差挤掉一个字
        const e = make('Empty { title: "暂未找到匹配的筛选结果" }');
        const title = part(e, "emptyTitle");
        waitTrue(function () { return title.height > 0; });
        compare(title.lineCount, 1, "没有外层约束 ⇒ 一行摆完，不该自己把自己挤换行");
        compare(title.height, title.lineHeight, "行高 22 ⇒ 单行就是 22");
        e.destroy();
    }

    function test_naturalWidthDoesNotWrap() {
        const e = make('Empty { title: "标题"; description: "描述" }');
        const desc = part(e, "emptyDescription");
        waitTrue(function () { return e.width > 0; });
        compare(desc.lineCount, 1, "没被约束就不该换行");
        compare(e.width, e.implicitWidth, "外层没给宽度时 width 回落 implicitWidth");
        e.destroy();
    }

    // ---------------- 颜色与主题 ----------------

    function test_titleAndDescriptionColors() {
        const e = make('Empty { title: "标题"; description: "描述" }');
        compare(part(e, "emptyTitle").color.toString(), Theme.current.colorText0.toString(),
            "标题走 Typography 的 text-0");
        compare(part(e, "emptyDescription").color.toString(), Theme.current.colorText1.toString(),
            ".semi-empty-description 是 --semi-color-text-1");
        e.destroy();
    }

    function test_themeChangeRepaintsBothTexts() {
        const e = make('Empty { title: "标题"; description: "描述" }');
        const title = part(e, "emptyTitle");
        const desc = part(e, "emptyDescription");
        const beforeTitle = title.color.toString();
        const beforeDesc = desc.color.toString();
        Theme.mode = Theme.Dark;
        waitTrue(function () { return title.color.toString() !== beforeTitle
            && desc.color.toString() !== beforeDesc; }, "两件文字都要跟着主题换色");
        verify(title.color.toString() !== beforeTitle, "标题色没跟上就是绑定断了");
        verify(desc.color.toString() !== beforeDesc, "描述色没跟上就是绑定断了");
        Theme.mode = Theme.Light;
        e.destroy();
    }

    // ---------------- 收了但不产出差异的那几条 ----------------

    function test_styleImageStyleAndClassNameAreInert() {
        const base = make('Empty { title: "标题"; description: "描述" }');
        const withStyles = make('Empty { title: "标题"; description: "描述"; '
            + 'style: ({ padding: 30, width: 600 }); imageStyle: ({ width: 40 }); '
            + 'className: "my-empty" }');
        waitTrue(function () { return base.width > 0 && withStyles.width > 0; });
        compare(withStyles.implicitWidth, base.implicitWidth, "style / className 没有 CSS 可落");
        compare(withStyles.implicitHeight, base.implicitHeight);
        compare(part(withStyles, "emptyImageShell").width, part(base, "emptyImageShell").width,
            "imageStyle 也不改图块尺寸");
        base.destroy();
        withStyles.destroy();
    }

    function test_layoutOnlyRecognisesHorizontal() {
        const e = make('Empty { title: "标题"; layout: "horizontal" }');
        verify(e.horizontal);
        compare(part(e, "emptyContentShell").x, 32, "没给图时行档也带那 32");
        e.destroy();
    }

    // ---------------- 节点档的 title / description ----------------

    function test_nodeTitleAndDescriptionGoThroughLoaders() {
        const e = make('Empty {\n'
            + '    title: Component { Text { text: "富标题"; font.pixelSize: 20 } }\n'
            + '    description: Component { Text { text: "富描述"; font.pixelSize: 14 } }\n'
            + '}');
        const titleLoader = part(e, "emptyTitleLoader");
        const descLoader = part(e, "emptyDescriptionLoader");
        waitTrue(function () { return titleLoader.item !== null && descLoader.item !== null; },
            "节点档要各载出一件");
        compare(titleLoader.item.text, "富标题");
        compare(descLoader.item.text, "富描述");
        verify(!part(e, "emptyTitle").visible, "节点档下那只字符串 Text 不该参与");
        compare(descLoader.y, titleLoader.height + 16, "相邻兄弟那条 16 对节点档同样成立");
        e.destroy();
    }
}
