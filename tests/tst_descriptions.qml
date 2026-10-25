import QtQuick
import QtTest
import Semi

// Descriptions / DescriptionsItem 描述列表。规格照
// packages/semi-ui/descriptions/{index.tsx,item.tsx}（DescriptionsProps :23-33、
// defaultProps :61-68、getColumns :80-93、renderChildrenList :97-115、render :117-138；
// item.tsx DescriptionsItemProps :8-16、render :35-74）与
// packages/semi-foundation/descriptions/{foundation.ts:12-42,descriptions.scss,variables.scss}。
//
// 端口口径（都在 src/Descriptions.qml / src/DescriptionsItem.qml 头注释里）：
//   · 官方 `data` 在 QML 里被 `Item.data`（子项链表）占着，端口那一档叫 `dataList`。
//   · `column` 与 `span` 只在 `layout: 'horizontal'` 那一路生效；vertical 一个条目一行。
//   · 四档 align 里 plain 是换 DOM（key 带冒号、value 左内边距 8），其余三档只差 text-align。
//   · 双行档（row）那 12 的行距被 `-double` 重赋成 0，改吃 key 的 padding-bottom 与字号三档。
//   · `keyStyle` 的 width / textAlign 只在 plain 档落地（官方其余三档是 inline span，CSS 忽略）。
//
// 断言一律走「给定的容器宽 + 条目自身量出来的自然宽」，不写死字体度量。
TestCase {
    id: testCase

    name: "Descriptions"
    when: windowShown
    width: 900
    height: 700

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
        return Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "desc");
    }

    function near(actual, expected, message) {
        verify(Math.abs(actual - expected) <= 0.01,
               (message || "") + "（实得 " + actual + "，期望 " + expected + "）");
    }

    function itemAt(d, i) {
        verify(i < d.entries.length, "第 " + i + " 条目要在名单里");
        return d.entries[i].item;
    }

    readonly property string threeData: "[{ key: '甲', value: '一' },"
        + " { key: '乙', value: '二' }, { key: '丙', value: '三' }]";

    function makeThree(extra) {
        return make("Descriptions { width: 600; dataList: " + testCase.threeData
                    + (extra || "") + " }");
    }

    // ---------------- 属性面与缺省 ----------------

    function test_officialPropDefaults() {
        const d = make("Descriptions {}");
        compare(d.align, "center", "index.tsx:62");
        compare(d.row, false, "index.tsx:63");
        compare(d.size, "medium", "index.tsx:64");
        compare(d.layout, "vertical", "index.tsx:66");
        compare(d.column, 3, "index.tsx:67");
        compare(d.dataList.length, 0, "index.tsx:65 那条 `[] as Array<Data>`");
        verify(d.style === undefined);
        compare(d.className, "");
        const it = make("DescriptionsItem {}");
        verify(it.itemKey === undefined, "itemKey 官方没有缺省");
        compare(it.hidden, false);
        compare(it.span, 0, "官方没给 span ⇒ `span || 1` 按 1 走");
        compare(it.spanExplicit, false, "端口要分得开「没给」与「给了 0」");
        verify(it.keyStyle === undefined);
        it.destroy();
        d.destroy();
    }

    // ---------------- vertical：一个条目一行，column 完全不参与 ----------------

    function test_verticalStacksOneEntryPerRow() {
        const d = makeThree();
        wait(80);
        compare(d.entries.length, 3);
        // 缺省 column 是 3，但 vertical 档一行只放一条 —— 这一条断言就是「column 没被读到」
        for (let i = 0; i < 3; ++i) {
            const it = itemAt(d, i);
            compare(it.x, 0, "vertical 档每条都从容器左边起");
            near(it.cellWidth, 600, "每条都吃整幅");
            verify(it.y >= i * 20, "第 " + i + " 条要排在下一行");
        }
        verify(itemAt(d, 1).y > itemAt(d, 0).y, "三条是三行，不是一行三格");
        d.destroy();
    }

    function test_verticalColumnPropIsIgnored() {
        const d = makeThree("; column: 10");
        wait(80);
        near(itemAt(d, 0).cellWidth, 600, "column 再大也不许把条目挤窄");
        d.destroy();
    }

    function test_thColumnIsWidestKeyPlus24() {
        const d = make("Descriptions { width: 600; dataList: ["
                       + "{ key: '实际用户数量', value: '1,480,000' },"
                       + "{ key: '短', value: '二' }] }");
        wait(80);
        const wide = itemAt(d, 0);
        const narrow = itemAt(d, 1);
        near(wide.keyColumnWidth, wide.keyNaturalWidth + Theme.current.spacingLoose,
             "th 那一列 = 最宽的那把 key + 24（$spacing-descriptions_th-paddingRight）");
        near(narrow.keyColumnWidth, wide.keyColumnWidth,
             "CSS auto table ⇒ 两行的 th 同宽，key 是上下对齐的");
        near(narrow.valueX, narrow.keyColumnWidth, "value 从 th 列之后起");
        near(narrow.valueX - narrow.keyAreaWidth, 24,
             "那 24 是 th 的 padding，在文字盒之外 ⇒ key 盒右边缘离 value 正好 24");
        near(narrow.valueAreaWidth, 600 - narrow.keyColumnWidth,
             "align≠plain ⇒ 值那一格 = 整格 − th 列");
        d.destroy();
    }

    function test_normalRowCarriesTwelveBottom() {
        const d = makeThree();
        wait(80);
        const it = itemAt(d, 0);
        near(it.implicitHeight, 20 + Theme.current.spacingBaseTight,
             "-item { padding-bottom: 12 } + 行高 20");
        near(d.contentHeight, itemAt(d, 0).implicitHeight + itemAt(d, 1).implicitHeight
             + itemAt(d, 2).implicitHeight, "整块高 = 三行之和");
        d.destroy();
    }

    function test_valueWrapsAndRowGrows() {
        const d = make("Descriptions { width: 200; dataList: [{ key: 'k',"
                       + " value: '很长很长很长很长很长很长很长很长很长很长的一段值' }] }");
        wait(80);
        const it = itemAt(d, 0);
        verify(it.valueNaturalWidth > it.valueAreaWidth, "先确认这一档真的会折行");
        const lines = Math.ceil(it.valueNaturalWidth / it.valueAreaWidth);
        verify(lines >= 2, "至少两行");
        near(it.implicitHeight, lines * 20 + 12, "行高 20 折 lines 行，再加那 12");
        d.destroy();
    }

    // ---------------- align 四档 ----------------

    function test_alignSetsTextAlignOnly() {
        const center = makeThree("; align: 'center'");
        const left = makeThree("; align: 'left'");
        const justify = makeThree("; align: 'justify'");
        wait(80);
        compare(itemAt(center, 0).keyAlign, Text.AlignRight, "center ⇒ th 右");
        compare(itemAt(center, 0).valueAlign, Text.AlignLeft);
        compare(itemAt(left, 0).keyAlign, Text.AlignLeft, "left ⇒ 都左");
        compare(itemAt(left, 0).valueAlign, Text.AlignLeft);
        compare(itemAt(justify, 0).keyAlign, Text.AlignLeft, "justify ⇒ th 左 td 右");
        compare(itemAt(justify, 0).valueAlign, Text.AlignRight);
        near(itemAt(center, 0).keyColumnWidth, itemAt(left, 0).keyColumnWidth,
             "换 align 不改列宽");
        center.destroy();
        left.destroy();
        justify.destroy();
    }

    function test_nodeValueHonoursTextAlign() {
        // 值是节点时没有行盒，text-align 那种「贴右」要靠位移做
        const d = make("Descriptions { width: 600; align: 'justify'; dataList: ["
                       + "{ key: '垂类标签', value: node }]"
                       + "\nComponent { id: node; Text { text: '电商' } } }");
        wait(120);
        const it = itemAt(d, 0);
        compare(it.valueAlign, Text.AlignRight);
        verify(it.nodeShiftRight > 0, "justify 档 ⇒ 节点要往右挪");
        near(it.valueAreaWidth - it.nodeShiftRight, it.valueNaturalWidth,
             "挪完之后节点右边缘正好贴格子右边");
        d.destroy();

        const left = make("Descriptions { width: 600; align: 'left'; dataList: ["
                          + "{ key: '垂类标签', value: node }]"
                          + "\nComponent { id: node; Text { text: '电商' } } }");
        wait(120);
        near(itemAt(left, 0).nodeShiftRight, 0, "其余档不挪");
        left.destroy();
    }

    function test_plainSwapsTheDom() {
        const d = makeThree("; align: 'plain'");
        wait(80);
        const it = itemAt(d, 0);
        compare(it.plainMode, true);
        compare(it.keyLabel, "甲:", "plain 档那个 span 写的是 `{itemKey}:`");
        near(it.keyColumnWidth, 0, "plain 档没有 th 那一列");
        near(it.valueX, it.keyAreaWidth + 8, "value 左内边距 8（$…value_plain-paddingLeft）");
        near(it.valueAreaWidth, 600 - it.keyAreaWidth - 8, "同一份 8 也要从值那一格里扣掉");
        d.destroy();

        // 整块收缩宽里那 8 也只有一份定义
        const shrink = make("Descriptions { align: 'plain'; dataList: [{ key: '甲', value: '一' }] }");
        wait(80);
        const si = itemAt(shrink, 0);
        near(shrink.implicitWidth, si.keyNaturalWidth + 8 + si.valueNaturalWidth,
             "没给宽的 plain 档：整块宽 = key + 8 + value");
        shrink.destroy();

        const aligned = makeThree();
        wait(80);
        compare(itemAt(aligned, 0).keyLabel, "甲", "其余三档不带冒号");
        aligned.destroy();
    }

    function test_keyStyleLandsOnlyInPlain() {
        const styled = make("Descriptions { width: 600; align: 'plain'; dataList: ["
                             + "{ key: '甲', value: '一', keyStyle: ({ width: 100, textAlign: 'right' }) }] }");
        wait(80);
        const p = itemAt(styled, 0);
        near(p.keyAreaWidth, 100, "plain 档 `-key` 是 inline-block ⇒ width 生效");
        compare(p.keyAlign, Text.AlignRight, "textAlign 同样只在 plain 档生效");
        styled.destroy();

        const d = make("Descriptions { width: 600; dataList: ["
                       + "{ key: '甲', value: '一', keyStyle: ({ width: 100, textAlign: 'right' }) }] }");
        wait(80);
        const c = itemAt(d, 0);
        near(c.keyAreaWidth, c.keyColumnWidth - 24,
             "官方 center 档的 -key 是 inline span，CSS 忽略 width ⇒ 端口也不许它生效（坑 113）");
        compare(c.keyAlign, Text.AlignRight, "textAlign 同理不落地，看到的还是那档的缺省右对齐");
        d.destroy();
    }

    function test_keyStyleColorLandsEverywhere() {
        const d = make("Descriptions { width: 600; dataList: ["
                       + "{ key: '甲', value: '一', keyStyle: ({ color: '#0a0b0c' }) }] }");
        wait(80);
        compare(itemAt(d, 0).keyColor, Qt.rgba(10 / 255, 11 / 255, 12 / 255, 1),
                "color 是继承性的键，四档都有效");
        d.destroy();
    }

    // ---------------- hidden ----------------

    function test_hiddenEntryTakesNoRow() {
        const d = make("Descriptions { width: 600; dataList: ["
                       + "{ key: '甲', value: '一' }, { key: '乙', value: '二', hidden: true },"
                       + "{ key: '丙', value: '三' }] }");
        wait(80);
        compare(d.entries.length, 3, "名单还是三条（hidden 是渲染层的事）");
        compare(itemAt(d, 1).visible, false, "官方 Item 在 hidden 时 return null");
        near(itemAt(d, 2).y, itemAt(d, 0).implicitHeight, "第三条顶上来，中间不留空行");
        near(d.contentHeight, 2 * itemAt(d, 0).implicitHeight);
        d.destroy();
    }

    function test_hiddenEntryDroppedBeforeGrouping() {
        // getHorizontalList :16 是先 filter 再累加 ⇒ 隐藏那条不占 span
        const d = make("Descriptions { width: 600; layout: 'horizontal'; column: 3; dataList: ["
                       + "{ key: '甲', value: '一', span: 1 },"
                       + "{ key: '乙', value: '二', hidden: true, span: 2 },"
                       + "{ key: '丙', value: '三', span: 1 }] }");
        wait(80);
        near(itemAt(d, 0).cellWidth, 300, "隐藏那条不累 span ⇒ grid=2，两条各半幅");
        near(itemAt(d, 2).cellWidth, 300);
        compare(itemAt(d, 2).y, itemAt(d, 0).y, "两条并在一行（真按三条算的话第三条就挤到下一行了）");
        d.destroy();
    }

    // ---------------- horizontal：分组、槽数、末行拉伸 ----------------

    function test_horizontalGroupsAtColumnBoundary() {
        const d = make("Descriptions { width: 600; layout: 'horizontal'; column: 4; align: 'plain';"
                       + " dataList: [{ key: 'a', value: '1' }, { key: 'b', value: '2' },"
                       + " { key: 'c', value: '3' }, { key: 'd', value: '4' },"
                       + " { key: 'e', value: '5', span: 3 }] }");
        wait(80);
        for (let i = 0; i < 4; ++i) {
            near(itemAt(d, i).cellWidth, 150, "前四条各占 1 槽 = 600/4");
            near(itemAt(d, i).x, 150 * i);
            compare(itemAt(d, i).y, itemAt(d, 0).implicitHeight === 0 ? 0 : 0, "同一行");
        }
        near(itemAt(d, 4).cellWidth, 450, "第五条 span 3 ⇒ 3/4 幅");
        near(itemAt(d, 4).x, 0, "另起一行");
        verify(itemAt(d, 4).y > 0);
        d.destroy();
    }

    function test_horizontalRowCanExceedColumn() {
        // 断点是「加上当前这条之后 >= column」⇒ 一行总 span 可以超出 column
        const d = make("Descriptions { width: 600; layout: 'horizontal'; column: 5; align: 'plain';"
                       + " dataList: [{ key: 'a', value: '1' }, { key: 'b', value: '2' },"
                       + " { key: 'c', value: '3' }, { key: 'd', value: '4' },"
                       + " { key: 'e', value: '5' }, { key: 'f', value: '6', span: 3 },"
                       + " { key: 'g', value: '7', span: 3 }] }");
        wait(80);
        // 第一行 5 条各 1 槽；第二行 3+3=6 槽 ⇒ grid 取最大的 6
        near(itemAt(d, 0).cellWidth, 100, "grid = max(5, 6) = 6 ⇒ 第一行每条 1/6");
        near(itemAt(d, 4).x, 400);
        near(itemAt(d, 5).cellWidth, 300, "第二行每条 3/6");
        near(itemAt(d, 6).x, 300, "两条各 300 ⇒ 正好铺满，与浏览器多出一列的结果同源");
        d.destroy();
    }

    function test_lastRowStretchesOnlyWhenSpanMissing() {
        const stretched = make("Descriptions { width: 600; layout: 'horizontal'; column: 4;"
                                + " align: 'plain'; dataList: [{ key: 'a', value: '1' },"
                                + " { key: 'b', value: '2' }] }");
        wait(80);
        near(itemAt(stretched, 0).cellWidth, 150, "末项没给 span ⇒ 补成 4-2+1 = 3");
        near(itemAt(stretched, 1).cellWidth, 450);
        stretched.destroy();

        const given = make("Descriptions { width: 600; layout: 'horizontal'; column: 4;"
                           + " align: 'plain'; dataList: [{ key: 'a', value: '1' },"
                           + " { key: 'b', value: '2', span: 1 }] }");
        wait(80);
        near(itemAt(given, 0).cellWidth, 300, "末项显式给了 span ⇒ 不补，末行短一截");
        near(itemAt(given, 1).cellWidth, 300);
        given.destroy();
    }

    function test_horizontalThIsOneSlotOfFixedGrid() {
        const d = make("Descriptions { width: 600; layout: 'horizontal'; column: 4;"
                       + " dataList: [{ key: '甲', value: '一' }, { key: '乙', value: '二' },"
                       + " { key: '丙', value: '三' }, { key: '丁', value: '四' }] }");
        wait(80);
        near(itemAt(d, 0).keyColumnWidth, 600 / (2 * 4),
             "fixed layout ⇒ th 恒占 1 槽 = 容器宽 /(2×grid)");
        near(itemAt(d, 0).cellWidth - itemAt(d, 0).keyColumnWidth, 600 / 8,
             "td 占剩下的 2×span-1 槽");
        d.destroy();
    }

    // ---------------- 双行档 ----------------

    function test_doubleModeMetricsPerSize() {
        const small = makeThree("; row: true; size: 'small'");
        const medium = makeThree("; row: true");
        const large = makeThree("; row: true; size: 'large'");
        wait(80);
        compare(itemAt(medium, 0).stacked, true, "tr 变 inline-flex column ⇒ key 上、value 下");
        near(itemAt(medium, 0).valueY, 20 + 4, "key 行高 20 + padding-bottom 4");
        near(itemAt(medium, 0).implicitHeight, 20 + 4 + 28,
             "那 12 的行距被 -double 重赋成 0");
        near(itemAt(small, 0).implicitHeight, 16 + 0 + 22, "small ⇒ key 12/16、value 16/22");
        near(itemAt(large, 0).implicitHeight, 20 + 4 + 40, "large ⇒ value 28/40");
        compare(itemAt(small, 0).valueFont, Theme.current.fontSizeHeader6);
        compare(itemAt(medium, 0).valueFont, Theme.current.fontSizeHeader4);
        compare(itemAt(large, 0).valueFont, Theme.current.fontSizeHeader2);
        compare(itemAt(small, 0).keyFont, Theme.current.fontSizeSmall, "只有 small 那档 key 降到 12");
        compare(itemAt(large, 0).keyFont, Theme.current.fontSizeRegular);
        small.destroy();
        medium.destroy();
        large.destroy();
    }

    function test_doubleGapPerSize() {
        const small = makeThree("; row: true; size: 'small'");
        const medium = makeThree("; row: true");
        const large = makeThree("; row: true; size: 'large'");
        wait(80);
        near(small.doubleGap, 48, "$…item_small-paddingRight");
        near(medium.doubleGap, 60, "$…item_medium-paddingRight");
        near(large.doubleGap, 80, "$…item_large-paddingRight");
        small.destroy();
        medium.destroy();
        large.destroy();
    }

    function test_doubleNaturalWidthIsOneLineSum() {
        const d = make("Descriptions { row: true; dataList: " + testCase.threeData + " }");
        wait(80);
        let want = 0;
        for (let i = 0; i < 3; ++i) {
            const it = itemAt(d, i);
            want += Math.max(it.keyNaturalWidth, it.valueNaturalWidth) + d.doubleGap;
        }
        near(d.implicitWidth, want,
             "双行档 tbody 是 flex ⇒ shrink-to-fit 出来的就是全排成一行的总宽");
        d.destroy();
    }

    function test_doubleModeSharesWidthPerLine() {
        const d = make("Descriptions { width: 600; row: true; dataList: " + testCase.threeData + " }");
        wait(80);
        near(itemAt(d, 0).cellWidth, 200, "三条塞得下 ⇒ 一行三条各分 1/3");
        near(itemAt(d, 1).x, 200);
        near(itemAt(d, 2).x, 400);
        compare(itemAt(d, 0).y, itemAt(d, 2).y, "同一行");
        near(itemAt(d, 0).keyColumnWidth, 0, "双行档没有 th 列");
        d.destroy();
    }

    function test_valueWeightOnlyInDouble() {
        const normal = makeThree();
        const doubled = makeThree("; row: true");
        wait(80);
        compare(itemAt(normal, 0).valueWeight, Font.Normal,
                "普通档 -value 没有字重规则（@include font-size-regular 只给字号行高）");
        compare(itemAt(doubled, 0).valueWeight, Font.DemiBold,
                "$font-descriptions_value-fontWeight = $font-weight-bold = 600");
        normal.destroy();
        doubled.destroy();
    }

    function test_doubleModeWrapsByNaturalWidth() {
        const d = make("Descriptions { width: 200; row: true; dataList: " + testCase.threeData + " }");
        wait(80);
        verify(itemAt(d, 2).y > itemAt(d, 0).y, "容器只 200 宽 ⇒ 第三条另起一行");
        near(itemAt(d, 0).cellWidth, 100, "第一行两条各分一半");
        near(itemAt(d, 2).cellWidth, 200, "第二行只有它自己 ⇒ 吃整幅");
        d.destroy();
    }

    function test_doubleModeIgnoresAlignButPlainStillSwapsDom() {
        const d = makeThree("; row: true; align: 'justify'");
        wait(80);
        compare(itemAt(d, 0).valueAlign, Text.AlignLeft,
                "-double 下那四条对齐规则整块不套（类名带 !row）");
        compare(itemAt(d, 0).keyAlign, Text.AlignLeft);
        const centered = makeThree("; row: true; align: 'center'");
        wait(80);
        compare(itemAt(centered, 0).keyAlign, Text.AlignLeft,
                "center 档在普通档下 th 是右对齐的，双行档必须看到左");
        centered.destroy();
        d.destroy();

        const plain = makeThree("; row: true; align: 'plain'");
        wait(80);
        const it = itemAt(plain, 0);
        compare(it.plainMode, true, "plain 换 DOM 这一步与 row 无关，官方照换");
        compare(it.stacked, false, "只有一个 td ⇒ key 与 value 仍在同一行");
        near(it.plainGap, 0, "那条 8 写在 -plain 下，双行档拿不到");
        compare(it.keyLabel, "甲:");
        near(it.implicitHeight, Math.max(it.keyLine, it.valueLinesHeight),
             "双行档那 -double 把 -item 的 padding 重赋成 0 ⇒ 没有那 12");
        plain.destroy();
    }

    // ---------------- 两种来源 ----------------

    function test_dataWinsOverDeclaredChildren() {
        const d = make("Descriptions { width: 600; dataList: [{ key: '甲', value: '一' }]"
                       + "\nDescriptionsItem { objectName: 'declared'; itemKey: '乙'; value: '二' } }");
        wait(80);
        compare(d.entries.length, 1, "getColumns 先判 data ⇒ 子项整条不读");
        const declared = testCase.findChild(d, "declared");
        verify(declared !== null);
        compare(declared.visible, false, "官方是不渲染，端口同样不显示");
        compare(declared.descriptionsHost, null, "也不收养");
        d.destroy();
    }

    function test_declaredChildrenPath() {
        const d = make("Descriptions { width: 600; align: 'plain'"
                       + "\nDescriptionsItem { itemKey: '姓名' }"
                       + "\nDescriptionsItem { itemKey: '年龄' } }");
        wait(80);
        compare(d.entries.length, 2, "子项档靠反向收养进名单");
        compare(itemAt(d, 0).descriptionsHost, d);
        near(itemAt(d, 1).y, itemAt(d, 0).implicitHeight);
        d.destroy();
    }

    function test_declaredChildrenAsValue() {
        const d = make("Descriptions { width: 600"
                       + "\nDescriptionsItem { objectName: 'withNode'; itemKey: '垂类标签'"
                       + "\nText { objectName: 'inner'; text: '电商' } } }");
        wait(80);
        const it = testCase.findChild(d, "withNode");
        compare(it.hasDeclared, true, "children 档优先于 value 档");
        compare(it.valueIsText, false);
        verify(it.valueNaturalWidth > 0, "值那一格的宽由子项量出来");
        const inner = testCase.findChild(it, "inner");
        // 子项挂在 valueRow 里，Row 自己平移到 valueX ⇒ 换算回 Item 那一层再比
        near(inner.mapToItem(it, 0, 0).x, it.valueX, "子项挂在 value 那一格的起点上");
        d.destroy();
    }

    function test_valueThreeFlavors() {
        const d = make("Descriptions { width: 600; dataList: ["
                       + "{ key: '文本', value: '一' },"
                       + "{ key: '函数', value: function () { return '三' } }] }");
        wait(80);
        compare(itemAt(d, 0).valueIsText, true);
        compare(itemAt(d, 0).resolved, "一");
        compare(itemAt(d, 1).valueIsFunction, true, "官方 :46 那一步：函数当工厂调用一次");
        compare(itemAt(d, 1).resolved, "三");
        compare(itemAt(d, 1).valueIsText, true, "返回的是文本 ⇒ 走文本档");
        d.destroy();
    }

    function test_valueComponentFlavor() {
        const host = make("Descriptions { width: 600; dataList: [{ key: '甲', value: node }]"
                          + "\nComponent { id: node; Text { objectName: 'nodeVal'; text: '节点值' } } }");
        const d = host;
        wait(120);
        const it = itemAt(d, 0);
        compare(it.valueIsComponent, true);
        verify(it.valueNaturalWidth > 0, "Component 档要等 Loader 出项才量得到宽");
        verify(testCase.findChild(it, "nodeVal") !== null, "节点要真的挂进去");
        host.destroy();
    }

    function test_keyComponentFlavor() {
        const d = make("Descriptions { width: 600; dataList: [{ key: node, value: '一' }]"
                       + "\nComponent { id: node; Text { objectName: 'nodeKey'; text: '键节点' } } }");
        wait(120);
        const it = itemAt(d, 0);
        compare(it.keyIsComponent, true, "itemKey 也是 ReactNode 档");
        verify(it.keyNaturalWidth > 0, "节点档要量得出宽");
        verify(it.keyLabel === "", "Component 档不吃那个冒号拼接");
        verify(testCase.findChild(it, "nodeKey") !== null);
        d.destroy();
    }

    function test_keyDoesNotWrap() {
        // `-key { white-space: nowrap }` ⇒ 容器再窄也不折行，th 列宽照旧，值那一格夹到 0
        const d = make("Descriptions { width: 60; dataList: [{ key: '实际用户数量', value: '一' }] }");
        wait(80);
        const it = itemAt(d, 0);
        verify(it.keyNaturalWidth > 60, "夹具要选得比容器宽");
        near(it.keyColumnWidth, it.keyNaturalWidth + 24, "th 列不因容器窄而收缩");
        compare(it.valueAreaWidth, 0, "值那一格夹到 0，不许是负的");
        d.destroy();
    }

    function test_nonPlainObjectEntrySkipped() {
        const d = make("Descriptions { width: 600; dataList: ['不是对象', null,"
                       + " { key: '甲', value: '一' }] }");
        wait(80);
        compare(d.entries.length, 1, "官方 isPlainObject 不过的那几项渲染成 null");
        near(d.contentHeight, itemAt(d, 0).implicitHeight, "也不占行高");
        d.destroy();
    }

    // ---------------- 重排与收缩 ----------------

    function test_layoutSwitchRelayouts() {
        const d = makeThree();
        wait(80);
        verify(itemAt(d, 1).y > 0, "先确认 vertical 档它是第二行");
        d.layout = "horizontal";
        wait(80);
        compare(itemAt(d, 1).x, 200, "换 horizontal ⇒ 三条并到一行");
        compare(itemAt(d, 1).y, itemAt(d, 0).y, "同一行");
        compare(itemAt(d, 1).cellWidth, 200, "grid=3 ⇒ 每条 1/3 幅");
        d.destroy();
    }

    function test_widthChangeRelayouts() {
        const d = make("Descriptions { width: 600; layout: 'horizontal'; column: 3; align: 'plain';"
                       + " dataList: [{ key: '甲', value: '一' }, { key: '乙', value: '二' },"
                       + " { key: '丙', value: '三' }] }");
        wait(80);
        near(itemAt(d, 0).cellWidth, 200);
        d.width = 300;
        wait(80);
        near(itemAt(d, 0).cellWidth, 100, "容器宽变了要按槽数重算");
        d.destroy();
    }

    function test_naturalWidthShrinksToContent() {
        const d = make("Descriptions { dataList: [{ key: '甲', value: '一' }] }");
        wait(80);
        verify(d.implicitWidth > 0, "没给宽时按内容收缩");
        near(d.implicitWidth, itemAt(d, 0).keyColumnWidth + itemAt(d, 0).valueNaturalWidth,
             "th 列 + 最宽的那把 value");
        d.destroy();
    }

    function test_propChangesRelayoutAtRuntime() {
        const d = make("Descriptions { width: 600; layout: 'horizontal'; column: 4; dataList: ["
                       + "{ key: '甲', value: '一', span: 1 }, { key: '乙', value: '二', span: 1 },"
                       + "{ key: '丙', value: '三', span: 1 }, { key: '丁', value: '四', span: 1 }] }");
        wait(80);
        near(itemAt(d, 0).cellWidth, 150, "四条各 1 槽、grid=4 ⇒ 600/4");
        compare(itemAt(d, 3).y, itemAt(d, 0).y, "四条正好一行");
        d.column = 2;
        wait(80);
        near(itemAt(d, 0).cellWidth, 300, "column 变 2 ⇒ 两行两条、每条 1/2 幅");
        near(itemAt(d, 0).keyColumnWidth, 150, "th 那一槽也跟着走");
        verify(itemAt(d, 2).y > itemAt(d, 0).y, "第三条另起一行");
        d.align = "plain";
        wait(80);
        compare(itemAt(d, 0).keyLabel, "甲:", "换 align ⇒ 换 DOM");
        near(itemAt(d, 0).keyColumnWidth, 0, "plain 档没有 th 列");
        d.size = "large";
        d.row = true;
        wait(80);
        compare(itemAt(d, 1).valueFont, Theme.current.fontSizeHeader2, "换 size ⇒ 三档字号");
        compare(itemAt(d, 1).valueWeight, Font.DemiBold, "换 row ⇒ 上双行档");
        d.dataList = [{ key: '丙', value: '三' }];
        wait(120);
        compare(d.entries.length, 1, "换 data ⇒ 名单重建");
        near(itemAt(d, 0).cellWidth, 600, "只剩一条 ⇒ 吃整幅");
        d.destroy();
    }

    function test_dataListSwapOfSameLengthRebuildsEntries() {
        // 条数不变的一换（非对象 → 对象）不会惊动 Repeater 的子项数，
        // 只有 onDataListChanged 那一次 refresh 能把名单补回来
        const d = make("Descriptions { width: 600; dataList: ['不是对象',"
                       + " { key: '甲', value: '一' }] }");
        wait(80);
        compare(d.entries.length, 1, "非 plain object 的那一项不进名单");
        d.dataList = [{ key: '乙', value: '二' }, { key: '甲', value: '一' }];
        wait(120);
        compare(d.entries.length, 2, "同长度换 data ⇒ 名单要重建");
        near(itemAt(d, 0).cellWidth, 600, "两条各占一行、都吃整幅");
        d.destroy();
    }

    function test_hiddenToggledAtRuntime() {
        const d = makeThree();
        wait(80);
        const before = d.contentHeight;
        itemAt(d, 1).hidden = true;
        wait(80);
        near(d.contentHeight, before - itemAt(d, 0).implicitHeight, "运行时改 hidden 也要收一行");
        compare(itemAt(d, 1).visible, false);
        near(itemAt(d, 2).y, itemAt(d, 0).implicitHeight, "第三条顶上来");
        d.destroy();
    }

    function test_deadPropsDoNotChangeGeometry() {
        const plain = makeThree();
        const dressed = makeThree("; className: 'my-desc'; style: ({ backgroundColor: 'red' })");
        wait(80);
        near(itemAt(dressed, 0).cellWidth, itemAt(plain, 0).cellWidth,
             "style / className 官方只喂给 DOM，收了不产出差异");
        near(itemAt(dressed, 2).y, itemAt(plain, 2).y);
        plain.destroy();
        dressed.destroy();
    }
}
