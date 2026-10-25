import QtQuick
import QtTest
import Semi

// Tree。规格照 packages/semi-ui/tree/{index.tsx,treeNode.tsx,nodeList.tsx,indent.tsx,interface.ts}
// + packages/semi-foundation/tree/{foundation.ts,treeUtil.ts,constants.ts,tree.scss,variables.scss}，
// 数值逐条对编译后的 packages/semi-ui/dist/css/semi.css（`.semi-tree*`）；
// 演示与 API 表照 content/navigation/tree/index.md 的 24 节。
//
// 端口口径都在 src/Tree.qml 文件头，这份用例盯的几条：
//   · 身份是 **key**（没有 key 时退成 pos），value 只在进出 onChange / value 时经
//     valueEntities 换算；两套「禁用」判定（渲染 vs 能不能选）分开钉。
//   · 官方 gDSFP 那串 else-if 的优先级：受控 expandedKeys > expandAll/默认展开 >
//     defaultExpandedKeys > defaultValue > value；清空搜索时把「选中项+祖先」并进 expandedKeys。
//   · 上游三条毛病照抄不修：disableStrictly 的 disabledKeys 会牵连「孩子全禁用」的父级
//     （demo 里中国自己没写 disabled 也是灰的）；simpleJson 的 onChange 走浅 pick，
//     子节点选中时基本拿到空对象；非虚拟化时 scrollTo 什么都不做。
//   · motion / 拖拽 / 虚拟化的分支都要落到具体几何上，不接受「跑完没报错就算过」。
//
// 跑法（本仓约定，优先 offscreen）：
//   QT_QPA_PLATFORM=offscreen ./cmake-build-debug/tests/tst_semi -input tests/tst_tree.qml
TestCase {
    id: testCase

    name: "Tree"
    when: windowShown
    width: 900
    height: 700

    // ReactNode 档的槽位：文件里声明好，测的时候直接赋给控件属性
    Component {
        id: emptyHookComp

        Text { objectName: "emptyHook"; text: "钩子空态" }
    }

    Component {
        id: hookTextComp

        Text { objectName: "hookText"; text: "钩子文字"; color: "#00aa00" }
    }

    Component {
        id: labelSlotComp

        Text { objectName: "labelSlotText"; text: "组件标签"; color: "#00aa00" }
    }

    Component {
        id: searchHookComp

        Text { objectName: "searchHookNode"; text: "自定义搜索区" }
    }

    Component {
        id: fullPlainComp

        Item {
            objectName: "fullHook"

            property var modelData

            Text {
                objectName: "fullText"

                text: "H" + (modelData === undefined ? "?" : modelData.label)
                color: "#0000aa"
            }
        }
    }

    Component {
        id: fullPadComp

        Item { objectName: "padHook" }
    }

    Component {
        id: fullTinyComp

        Item { objectName: "tiny" }
    }

    Component {
        id: fullInjectComp

        Item {
            objectName: "inj"

            property var modelData
            property int level
            property var onClick

            Text {
                objectName: "injText"

                text: String(level) + ":" + (onClick === undefined ? "no" : "yes")
                    + ":" + (modelData === undefined ? "no" : "yes")
            }
        }
    }

    // 复刻 gallery 那几个 renderFullLabel 的写法：Loader 不给宽高，只吃载入项的隐式尺寸
    Component {
        id: fullCaretComp

        Item {
            id: caretHookRoot

            objectName: "caretHook"

            property Component expandIcon

            Loader {
                objectName: "hookCaret"

                sourceComponent: caretHookRoot.expandIcon
            }
        }
    }

    // renderLabel 钩子：定宽 77，用来钉「钩子档的文字宽吃的是槽位宽而不是自然宽」
    // （Text 的 implicitHeight 是只读的，所以这里用裸 Item）
    Component {
        id: labelWidthComp

        Item {
            objectName: "labelHook"

            implicitWidth: 77
            implicitHeight: 20
        }
    }

    // 官方 demo 那棵树：亚洲 > 中国(北京/上海) + 日本(大阪)；北美洲 > 美国 + 加拿大
    readonly property string std: "["
        + "{key:\"0\",label:\"亚洲\",value:\"Asia\",children:["
        + "{key:\"0-0\",label:\"中国\",value:\"China\",children:["
        + "{key:\"0-0-0\",label:\"北京\",value:\"Beijing\"},"
        + "{key:\"0-0-1\",label:\"上海\",value:\"Shanghai\"}]},"
        + "{key:\"0-1\",label:\"日本\",value:\"Japan\",children:["
        + "{key:\"0-1-0\",label:\"大阪\",value:\"Osaka\"}]}]},"
        + "{key:\"1\",label:\"北美洲\",value:\"North America\",children:["
        + "{key:\"1-0\",label:\"美国\",value:\"United States\"},"
        + "{key:\"1-1\",label:\"加拿大\",value:\"Canada\"}]}]"

    function init() {
        testCase.visible = true;
        Theme.reset();
        Theme.mode = Theme.Light;
        // 上一用例残留的悬浮会让本用例第一行就带 hover 底色
        mouseMove(testCase, testCase.width - 2, testCase.height - 2);
    }

    function cleanup() {
        Theme.reset();
        Theme.mode = Theme.Light;
        for (let i = testCase.children.length - 1; i >= 0; --i)
            testCase.children[i].destroy();
    }

    // attrs 里属性之间必须用分号隔开；写的时候漏了就在这儿补上
    readonly property var propNames: ["autoExpandParent", "autoExpandWhenDragEnter", "autoMergeValue",
        "blockNode", "checkRelation", "defaultExpandAll", "defaultExpandedKeys", "defaultValue",
        "directory", "disableStrictly", "disabled", "draggable", "emptyContent", "expandAction",
        "expandAll", "expandedKeys", "expandIcon", "filterTreeNode", "icon", "keyMaps",
        "labelEllipsis", "leafOnly", "loadData", "loadedKeys", "motion", "multiple",
        "onChangeWithObject", "renderFullLabel", "renderLabel", "searchPlaceholder", "searchRender",
        "showClear", "showFilteredOnly", "showLine", "treeDataSimpleJson", "treeNodeFilterProp",
        "value", "virtualize"]

    // attrs 里属性之间要有分号；这里按「上一个 token 是值结尾」判断该不该补
    function spread(attrs) {
        const words = String(attrs).split(" ");
        let out = "";
        for (let k = 0; k < words.length; ++k) {
            const w = words[k];
            if (k > 0) {
                const colon = w.indexOf(":");
                const name = colon > 0 ? w.substring(0, colon) : "";
                const prev = words[k - 1];
                const tail = prev.charAt(prev.length - 1);
                const valueEnd = /[A-Za-z0-9_"'\)\}\]]/.test(tail);
                if (propNames.indexOf(name) >= 0 && valueEnd)
                    out += "; ";
                else
                    out += " ";
            }
            out += w;
        }
        return out;
    }

    function make(qml) {
        const obj = Qt.createQmlObject("import QtQuick; import Semi; " + qml, testCase, "tree");
        // 位置器要下一帧才排布；没排布完时行是 0×0，合成点击会打空
        wait(60);
        return obj;
    }

    // QColor 与 "transparent" 字面量永远比不等（读回来是 #00000000），要比 alpha
    function clear(c) {
        return c.a === 0;
    }

    function stdTree(attrs) {
        return make("Tree { width: 260; height: 320; treeData: " + testCase.std
            + (attrs === undefined ? "" : "; " + spread(attrs)) + " }");
    }

    // 文件里声明的 Component id 在动态创建的 QML 对象里看不见，只能创建之后从 JS 侧赋
    function withProps(t, pairs) {
        for (const k in pairs)
            t[k] = pairs[k];
        return t;
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

    // 等展开动画收完：非此状态时 renderRows 里还套着动画组，行下标对不上
    function idx(t, key) {
        const at = t.rowKeys().indexOf(key);
        verify(at >= 0, "列表里找不到 " + key);
        return at;
    }

    function settle(t) {
        tryVerify(function () { return Object.keys(t.motionMapView).length === 0; }, 1500);
        compare(Object.keys(t.motionMapView).length, 0, "动画没收干净");
    }

    function list(qmlCode, attrs) {
        return make("Tree { treeData: " + qmlCode
            + (attrs === undefined ? "" : "; " + spread(attrs)) + " }");
    }

    // ============================================================ 属性面与缺省值
    function test_propDefaults() {
        const t = make("Tree { }")
        // 官方 defaultProps（index.tsx:128-149）逐条
        compare(t.showClear, true);
        compare(t.disabled, false);
        compare(t.blockNode, true);
        compare(t.multiple, false);
        compare(t.filterTreeNode, false);
        compare(t.autoExpandParent, false);
        compare(t.treeNodeFilterProp, "label");
        compare(t.defaultExpandAll, false);
        compare(t.expandAll, false);
        compare(t.onChangeWithObject, false);
        compare(t.motion, true);
        compare(t.leafOnly, false);
        compare(t.showFilteredOnly, false);
        compare(t.showLine, false);
        compare(t.expandAction, false);
        compare(t.disableStrictly, false);
        compare(t.draggable, false);
        compare(t.autoExpandWhenDragEnter, true);
        compare(t.checkRelation, "related");
        compare(t.autoMergeValue, true);
        // 官方没有 defaultProps 的那些：undefined / 空
        compare(t.treeDataSimpleJson, undefined);
        compare(t.value, undefined);
        compare(t.defaultValue, undefined);
        compare(t.expandedKeys, undefined);
        compare(t.defaultExpandedKeys, undefined);
        compare(t.loadedKeys, undefined);
        compare(t.emptyContent, undefined);
        compare(t.icon, undefined);
        compare(t.expandIcon, undefined);
        compare(t.labelEllipsis, undefined);
        compare(t.searchRender, undefined);
        compare(t.searchPlaceholder, "");
        compare(t.directory, false);
        compare(t.loadData, null);
        compare(t.renderLabel, null);
        compare(t.renderFullLabel, null);
        compare(t.virtualize.x, undefined);            // 缺省是空对象 ⇒ 等于没开
        compare(t.useVirtualList, false);
        // 官方 defaultProps 里没有 checkable / nodeChecked / selectedKeys / visibleNodes
        verify(!("checkable" in t), "自造的 checkable 必须已经撤掉");
        verify(!("nodeChecked" in t), "自造的 nodeChecked 必须已经撤掉");
        verify(!("visibleNodes" in t), "自造的 visibleNodes 必须已经撤掉");
        verify(!("checkable" in t) && !("selectedKeys" in t),
               "自造的选中面必须已经撤掉");
        t.destroy()
    }

    function test_geometricTokens() {
        const t = stdTree()
        compare(t.indentStep, 20);              // $spacing-tree_option_level-paddingLeft
        compare(t.level1Pad, 8);                // $spacing-tree_option_level1-paddingLeft
        compare(t.caretBox, 12);                // $width-tree_emptyIcon = $width-icon-small
        compare(t.iconGap, 8);                  // $spacing-tree_icon-marginRight
        compare(t.iconBox, 16);                 // .semi-icon { font-size: 16px }
        compare(t.lineWidth, 1);                // $width-tree_option_line
        compare(t.dragBorder, 2);               // $width-tree_option_draggable-border
        compare(t.rowPadY, 4);                  // $spacing-tree_option-paddingTop
        compare(t.listPadY, 8);                 // $spacing-tree_optionList-paddingY
        compare(t.searchPadX, 12);              // $spacing-tree_search_wrapper-paddingX
        compare(t.searchPadY, 8);
        compare(t.baseRowHeight, 28);           // 4 + 20 + 4
        compare(t.motionDuration, 200);         // nodeList.tsx:74 duration={200}
        t.destroy()
    }

    // ============================================================ 扁平化与身份
    function test_flattenStartsCollapsed() {
        const t = stdTree()
        compare(t.rowKeys(), ["0", "1"], "初始只有两个根")
        t.requestExpand("0")
        settle(t)
        compare(t.rowKeys(), ["0", "0-0", "0-1", "1"], "展开亚洲只放出直接子级")
        t.destroy()
    }

    function test_identityIsKeyNotValue() {
        // 官方所有状态集合按 key 存；value 只用于换算 onChange / value
        const t = list("[{key:\"k1\",label:\"甲\",value:\"v1\"},{key:\"k2\",label:\"乙\"}]")
        compare(t.rowKeys(), ["k1", "k2"]);
        var seen = null
        t.change.connect((v) => { seen = v })
        t.handleNodeSelect("k2")
        // k2 没有 value ⇒ getValueOrKey 退成 key（treeUtil.ts:622-629）
        compare(seen, "k2", "没有 value 的节点 onChange 给 key");
        t.handleNodeSelect("k1")
        compare(seen, "v1", "有 value 的节点 onChange 给 value");
        t.destroy()
    }

    function test_keylessNodesDoNotRender() {
        // entities 那边 node.key 为 null 时退回 pos（treeUtil.ts:141），
        // 但 flattenTreeData 读的是 treeNode["key"]（undefined）⇒ 两边对不上，
        // getTreeNodeProps 返 null ⇒ 这一行渲染不出来。官方同样如此（文档要求 key 必填）。
        const t = list("[{label:\"甲\",children:[{label:\"甲一\"}]},{label:\"乙\"}]")
        compare(t.rowKeys(), [], "没有 key 的行拿不到 props")
        t.requestExpand("0-0")
        compare(t.rowKeys(), [], "没 key 就连展开都记不上")
        t.destroy()
    }

    function test_posLevelAndIsEnd() {
        const t = stdTree()
        t.requestExpand("0")
        t.requestExpand("0-0")
        settle(t)
        // 上游 pos 把根容器也算一层：亚洲 "0-0"、中国 "0-0-0"、北京 "0-0-0-0"
        compare(t.rowField(0, "pos"), "0-0");
        compare(t.rowField(1, "pos"), "0-0-0");
        compare(t.rowField(2, "pos"), "0-0-0-0");
        compare(t.rowField(3, "pos"), "0-0-0-1");
        compare(t.rowField(4, "pos"), "0-0-1");
        compare(t.rowField(0, "level"), 0);
        compare(t.rowField(2, "level"), 2, "北京在第三层 ⇒ level 2");
        compare(t.rowField(4, "level"), 1);
        verify(t.rowField(2, "isEnd")[2] === false, "北京不是中国的最后一个孩子");
        verify(t.rowField(3, "isEnd")[2] === true, "上海是中国最后一个孩子");
        t.destroy()
    }

    function test_isEndFlags() {
        // isEnd[i] = 第 i 层祖先里该格是不是最后一个孩子（flattenTreeData:80）
        const t = stdTree()
        t.requestExpand("0")
        t.requestExpand("0-0")
        settle(t)
        verify(t.rowField(1, "isEnd")[0] === false, "亚洲不是最后一个根");
        verify(t.rowField(4, "isEnd")[1] === true, "日本是亚洲的最后一个孩子");
        verify(t.rowField(3, "isEnd")[2] === true, "上海是中国的最后一个孩子");
        verify(t.rowField(5, "isEnd")[0] === true, "北美洲是最后一个根");
        t.destroy()
    }

    function test_leafNeedsNoChildrenArray() {
        const t = list("[{key:\"a\",label:\"有孩子\",children:[]},{key:\"b\",label:\"没写\"}]")
        compare(t.rowField(0, "isLeaf"), true, "children:[] 也算叶子（长度 0）");
        compare(t.rowField(1, "isLeaf"), true);
        compare(t.rowField(0, "hasChildren"), false);
        t.destroy()
    }

    function test_isLeafFalseKeepsCaret() {
        // isLeaf:false 强制不是叶子（treeNode.tsx:187-191）
        const t = list("[{key:\"a\",label:\"甲\",isLeaf:false},{key:\"b\",label:\"乙\",isLeaf:true}]",
            " loadData: function (node, done) { done() }")
        compare(t.rowField(0, "isLeaf"), false, "isLeaf:false 必须压过「没有孩子」");
        compare(t.rowField(1, "isLeaf"), true);
        t.destroy()
    }

    function test_disabledRowStillFlattens() {
        const t = list("[{key:\"a\",label:\"甲\",disabled:true},{key:\"b\",label:\"乙\"}]")
        compare(t.rowKeys(), ["a", "b"]);
        compare(t.rowField(0, "disabled"), true);
        compare(t.rowField(1, "disabled"), false, "另一条不受影响");
        t.destroy()
    }

    // ============================================================ 展开状态怎么种下
    function test_defaultExpandAllOnlyAtMount() {
        const t = stdTree(" defaultExpandAll: true")
        compare(t.rowKeys().length, 9, "初始化展开全部");
        t.treeData = [{ key: "z", label: "新根", children: [{ key: "z-0", label: "新子" }] }]
        compare(t.rowKeys(), ["z"], "defaultExpandAll 只在初始化生效（官方 demo「默认展开」）");
        t.destroy()
    }

    function test_expandAllSurvivesDataChange() {
        const t = stdTree(" expandAll: true")
        compare(t.rowKeys().length, 9);
        t.treeData = [{ key: "z", label: "新根", children: [{ key: "z-0", label: "新子" }] }]
        compare(t.rowKeys(), ["z", "z-0"], "expandAll 在数据更新后仍然生效");
        t.destroy()
    }

    function test_defaultExpandedKeysExpandsAncestors() {
        // calcExpandedKeys 的 autoExpandParent 形参缺省 true（treeUtil.ts:387）
        const t = stdTree(" defaultExpandedKeys: [\"0-0\"]")
        compare(t.expandedKeysList().sort(), ["0", "0-0"], "父级被一起展开");
        compare(t.rowKeys(), ["0", "0-0", "0-0-0", "0-0-1", "0-1", "1"]);
        t.destroy()
    }

    function test_defaultValueExpandsAncestorsNotSelf() {
        // calcExpandedKeysForValues 用 findAncestorKeys(..., false)：不含自己
        const t = stdTree(" defaultValue: \"Shanghai\"")
        compare(t.expandedKeysList().sort(), ["0", "0-0"]);
        verify(!("0-0-1" in t.expandedMapView) === true, "选中项自己不展开");
        compare(t.selectedListView, ["0-0-1"], "defaultValue 换算成 key");
        t.destroy()
    }

    function test_valueAtMountSeedsBoth() {
        const t = stdTree(" value: \"Japan\"")
        compare(t.selectedListView, ["0-1"]);
        compare(t.expandedKeysList().sort(), ["0"], "只展开日本的中国… 应是亚洲");
        t.destroy()
    }

    function test_controlledExpandedKeys() {
        const t = stdTree(" expandedKeys: [\"0\"]")
        compare(t.rowKeys(), ["0", "0-0", "0-1", "1"]);
        t.requestExpand("0")
        compare(t.rowKeys(), ["0", "0-0", "0-1", "1"], "受控时点收起不改内部状态");
        t.expandedKeys = ["0", "0-0"]
        compare(t.rowKeys(), ["0", "0-0", "0-0-0", "0-0-1", "0-1", "1"], "属性变了才动");
        t.destroy()
    }

    function test_autoExpandParentWhenControlled() {
        const t = stdTree(" expandedKeys: [\"0\", \"0-0\", \"0-1\", \"1\"] autoExpandParent: true")
        // 受控 + autoExpandParent：收起父级要先把所有孩子收起，否则立刻被顶回去
        t.requestExpand("0")
        t.expandedKeys = ["0-0", "0-1"]
        verify("0" in t.expandedMapView, "autoExpandParent 把祖先补回来");
        t.destroy()
    }

    function test_autoExpandParentOffKeepsCollapse() {
        const t = stdTree(" expandedKeys: [\"0\", \"0-0\"]")
        t.requestExpand("0")
        compare(t.expandedKeysList().sort(), ["0", "0-0"], "非受控时内部状态被改？不，受控");
        t.expandedKeys = ["0-0"]
        compare(Object.keys(t.expandedMapView).sort(), ["0-0"],
            "autoExpandParent=false 时祖先不会被补回来");
        t.destroy()
    }

    function test_expandedKeysEmptyArrayIsStillControlled() {
        const t = stdTree(" expandedKeys: []")
        compare(Object.keys(t.expandedMapView).length, 0);
        t.requestExpand("0")
        compare(Object.keys(t.expandedMapView).length, 0, "给了空数组也是受控，点不动");
        t.destroy()
    }

    // ============================================================ 单选
    function test_singleSelectReplaces() {
        const t = stdTree()
        var hits = []
        t.select.connect((k, s, n) => hits.push(k + ":" + s + ":" + (n === null ? "null" : n.key)))
        t.handleNodeSelect("0-0-1")
        compare(t.selectedListView, ["0-0-1"]);
        compare(hits, ["0-0-1:true:0-0-1"]);
        t.handleNodeSelect("1")
        compare(t.selectedListView, ["1"], "单选替换");
        compare(hits.length, 2);
        t.destroy()
    }

    function test_reselectSameNodeStillSaysSelectedTrue() {
        // foundation.ts:587 notifySelect 恒传 true —— 这条不一致照抄
        const t = stdTree()
        var hits = []
        var changes = 0
        t.select.connect((k, s, n) => hits.push(k + ":" + s))
        t.change.connect(() => changes++)
        t.handleNodeSelect("1")
        t.handleNodeSelect("1")
        compare(hits, ["1:true", "1:true"], "第二次仍然 selected=true");
        compare(changes, 1, "但 onChange 只发一次");
        compare(t.selectedListView, ["1"]);
        t.destroy()
    }

    function test_controlledValueRejectsSelect() {
        const t = stdTree(" value: \"Shanghai\"")
        var changes = 0
        t.change.connect(() => changes++)
        t.handleNodeSelect("1")
        compare(t.selectedListView, ["0-0-1"], "受控时内部不写");
        compare(changes, 1, "onChange 照样通知");
        t.value = "Canada"
        compare(t.selectedListView, ["1-1"], "换了 value 才动");
        t.destroy()
    }

    function test_onChangeWithObjectPayload() {
        const t = stdTree(" onChangeWithObject: true")
        var got = null
        t.change.connect((v) => { got = v })
        t.handleNodeSelect("0-1")
        compare(got.key, "0-1", "入参是节点对象");
        compare(got.label, "日本");
        t.destroy()
    }

    function test_controlledObjectValue() {
        // onChangeWithObject 时受控值也要给对象（官方文档那条）
        const t = stdTree(" onChangeWithObject: true value: ({key:\"0-1\", label:\"日本\", value:\"Japan\"})")
        compare(t.selectedListView, ["0-1"], "对象里的 value 换算成 key");
        t.destroy()
    }

    function test_disabledTreeBlocksSelectButNotExpand() {
        const t = stdTree(" disabled: true")
        var changes = 0
        t.change.connect(() => changes++)
        t.handleNodeSelect("1")
        compare(changes, 0, "整树禁用不能选");
        t.requestExpand("1")
        verify("1" in t.expandedMapView, "北美洲有孩子，展开不受整树禁用影响");
        t.requestExpand("0")
        verify("0" in t.expandedMapView, "禁用不影响展开");
        t.destroy()
    }

    function test_explicitFalseDisabledInsideDisabledTree() {
        // TreeNode.isDisabled 遇 disabled:false 直接返回 false，
        // foundation._isDisabled 却仍然算禁用 ⇒ 看着能点、点了没反应（上游就这样）
        const t = list("[{key:\"a\",label:\"甲\",disabled:false}]", " disabled: true")
        compare(t.rowField(0, "disabled"), false, "渲染上没禁用");
        compare(t.rowField(0, "selectOff"), true, "选中判定上是禁用的");
        var changes = 0
        t.change.connect(() => changes++)
        t.handleNodeSelect("a")
        compare(changes, 0, "所以这一下不会被采纳");
        t.destroy()
    }

    // ============================================================ 多选联动
    function test_checkChildMakesParentHalf() {
        const t = stdTree(" multiple: true")
        t.requestExpand("0")
        t.requestExpand("0-0")
        settle(t)
        t.handleNodeSelect("0-0-0")
        compare(t.checkedKeysList().sort(), ["0-0-0"]);
        compare(t.halfKeysList().sort(), ["0", "0-0"], "父与祖父都半选");
        t.destroy()
    }

    function test_checkAllChildrenChecksParent() {
        const t = stdTree(" multiple: true")
        t.handleNodeSelect("0-0-0")
        t.handleNodeSelect("0-0-1")
        compare(t.checkedKeysList().sort(), ["0-0", "0-0-0", "0-0-1"], "中国被联动勾上");
        compare(t.halfKeysList().sort(), ["0", "0-0"], "亚洲半选；中国留在 half 里没被摘掉（上游口径）");
        t.handleNodeSelect("0-1")
        compare(t.checkedKeysList().sort(),
            ["0", "0-0", "0-0-0", "0-0-1", "0-1", "0-1-0"], "勾亚洲连大阪一起勾上");
        t.destroy()
    }

    function test_uncheckChildClearsAncestors() {
        const t = stdTree(" multiple: true")
        t.handleNodeSelect("0")
        compare(t.checkedKeysList().sort(),
            ["0", "0-0", "0-0-0", "0-0-1", "0-1", "0-1-0"], "勾父带子（整棵子树）");
        compare(Object.keys(t.halfMapView).length, 0);
        t.handleNodeSelect("0-0-0")
        compare(t.checkedKeysList().sort(), ["0-0-1", "0-1", "0-1-0"],
            "北京被摘，中国/亚洲整串往下退，日本那支还留着");
        compare(t.halfKeysList().sort(), ["0", "0-0"]);
        t.destroy()
    }

    function test_uncheckParentClearsSubtree() {
        const t = stdTree(" multiple: true")
        t.handleNodeSelect("1")
        compare(t.checkedKeysList().sort(), ["1", "1-0", "1-1"]);
        t.handleNodeSelect("1")
        compare(t.checkedKeysList().sort(), [], "取消父级把子孙一起清掉");
        compare(Object.keys(t.halfMapView).length, 0);
        t.destroy()
    }

    function test_halfStaysAfterParentChecked() {
        // calcCheckedKeysForChecked 只往上加勾，不会把父级从 halfChecked 里摘掉
        // （上游 state 里父级会同时 checked + halfChecked）
        const t = stdTree(" multiple: true")
        t.handleNodeSelect("0-0-0")
        t.handleNodeSelect("0-0-1")
        verify("0-0" in t.checkedMapView, "中国勾上");
        verify("0-0" in t.halfMapView, "但 halfChecked 里仍然留着它（上游口径）");
        t.destroy()
    }

    function test_changePayloadMergesParents() {
        const t = stdTree(" multiple: true")
        var got = null
        t.change.connect((v) => { got = v })
        t.handleNodeSelect("0-0-0")
        t.handleNodeSelect("0-0-1")
        // autoMergeValue=true ⇒ normalizeKeyList 把「父级已勾」的子孙收掉
        compare(got, ["China"], "只给最上层已勾节点的 value");
        t.destroy()
    }

    function test_autoMergeValueFalseKeepsAllKeys() {
        const t = stdTree(" multiple: true autoMergeValue: false")
        var got = null
        t.change.connect((v) => { got = v })
        t.handleNodeSelect("0-0-0")
        compare(got, ["Beijing"]);
        t.handleNodeSelect("0-0-1")
        compare(got.sort(), ["Beijing", "China", "Shanghai"],
            "关掉合并 ⇒ 父级和子孙都在");
        t.destroy()
    }

    function test_leafOnlyPayload() {
        const t = stdTree(" multiple: true leafOnly: true")
        var got = null
        t.change.connect((v) => { got = v })
        t.handleNodeSelect("0-0-0")
        t.handleNodeSelect("0-0-1")
        compare(got.sort(), ["Beijing", "Shanghai"], "leafOnly 只给叶子");
        t.destroy()
    }

    function test_unRelatedTogglesIndependently() {
        const t = stdTree(" multiple: true checkRelation: \"unRelated\"")
        var got = null
        t.change.connect((v) => { got = v })
        t.handleNodeSelect("0-0-0")
        compare(got, ["Beijing"]);
        t.handleNodeSelect("0")
        compare(t.realKeysList().sort(), ["0", "0-0-0"], "父级被勾但不牵连子孙");
        t.handleNodeSelect("0")
        compare(t.realKeysList().sort(), ["0-0-0"], "再点只取消自己");
        compare(Object.keys(t.checkedMapView).length, 0, "related 那套集合始终不参与");
        t.destroy()
    }

    function test_unRelatedNoHalf() {
        const t = stdTree(" multiple: true checkRelation: \"unRelated\"")
        t.handleNodeSelect("0-0-0")
        compare(Object.keys(t.halfMapView).length, 0, "不联动就没有半选");
        t.destroy()
    }

    function test_invalidCheckRelationIsNoOp() {
        // getTreeNodeProps 对无效 checkRelation 直接给未勾选（foundation.ts:408 注释）
        const t = stdTree(" multiple: true checkRelation: \"weird\"")
        t.handleNodeSelect("0-0-0")
        compare(t.rowField(0, "checked"), false);
        compare(Object.keys(t.checkedMapView).length, 0);
        t.destroy()
    }

    function test_disableStrictlyPropagatesToParents() {
        // 官方 demo「禁用」那节：北京+上海禁用 ⇒ 中国（没写 disabled）也变灰
        const t = list("[{key:\"0\",label:\"亚洲\",children:[{key:\"0-0\",label:\"中国\",children:["
            + "{key:\"0-0-0\",label:\"北京\",disabled:true},{key:\"0-0-1\",label:\"上海\",disabled:true}]}]}]",
            " multiple: true disableStrictly: true")
        compare(Object.keys(t.disabledMapView).sort(), ["0", "0-0", "0-0-0", "0-0-1"],
            "calcDisabledKeys 的补集：兄弟全禁用就把父级也算进去，再往上牵连");
        t.requestExpand("0")
        t.requestExpand("0-0")
        settle(t)
        compare(t.rowField(1, "disabled"), true, "中国被判定禁用");
        var changes = 0
        t.change.connect(() => changes++)
        t.handleNodeSelect("0")
        compare(changes, 0, "禁用父级不能被联动勾选");
        compare(Object.keys(t.checkedMapView).length, 0);
        t.destroy()
    }

    function test_disableStrictlyUncheckedParent() {
        const t = list("[{key:\"0\",label:\"亚洲\",children:["
            + "{key:\"0-0\",label:\"中国\",disabled:true},{key:\"0-1\",label:\"日本\"}]}]",
            " multiple: true disableStrictly: true")
        compare(Object.keys(t.disabledMapView).sort(), ["0-0"], "只有中国被禁");
        var got = null
        t.change.connect((v) => { got = v })
        t.handleNodeSelect("0-1")
        // 中国被禁 ⇒ 亚洲不能整勾，父级保持未选
        verify(!("0" in t.checkedMapView), "父级没有被勾上");
        verify("0" in t.halfMapView, "父级是半选");
        compare(got, ["0-1"], "节点没写 value ⇒ onChange 退成 key");
        t.destroy()
    }

    function test_disableStrictlyNeedsRelated() {
        // index.tsx:546 那条门槛：checkRelation 不是 related 时不算 disabledKeys
        const t = list("[{key:\"a\",label:\"甲\",disabled:true}]",
            " multiple: true disableStrictly: true checkRelation: \"unRelated\"")
        t.treeData = [{ key: "a", label: "甲", disabled: true }]
        compare(Object.keys(t.disabledMapView).length, 0, "unRelated 时不算 disabledKeys");
        t.destroy()
    }

    // ============================================================ 搜索
    function test_searchAreaHiddenWithoutFilter() {
        const t = stdTree()
        compare(t.searchVisible, false);
        compare(t._listHost.y, 0);
        t.destroy()
    }

    function test_searchAreaAppearsWithFilter() {
        const t = stdTree(" filterTreeNode: true")
        compare(t.searchVisible, true);
        compare(t.searchHeight, 48, "8 + 32 + 8");
        // 搜索区与列表是 wrapper 那根 column 上的两块，不能叠在第一行上
        compare(t._listHost.y, 48);
        compare(part(t, "treeSearchArea").y, 8);
        const box = part(t, "treeSearchArea")
        compare(box.height, 32);
        const input = part(t, "treeSearchInput")
        compare(input.showClear, true, "showClear 缺省 true");
        compare(input.placeholderText, "搜索", "占位取 locale");
        t.destroy()
    }

    function test_searchPlaceholderAndShowClear() {
        const t = stdTree(" filterTreeNode: true searchPlaceholder: \"挑一个\" showClear: false")
        compare(part(t, "treeSearchInput").placeholderText, "挑一个");
        compare(part(t, "treeSearchInput").showClear, false);
        t.destroy()
    }

    function test_searchIsCaseInsensitiveSubstring() {
        const t = stdTree(" filterTreeNode: true")
        t.searchBy("洲")
        compare(t.filteredKeysList().sort(), ["0", "1"], "label 里含「洲」的两条命中");
        compare(t.inputValueView, "洲");
        t.treeNodeFilterProp = "value"
        t.searchBy("JAPA")
        compare(t.filteredKeysList(), ["0-1"], "按 value 搜且忽略大小写（treeUtil.ts:436-443）");
        t.destroy()
    }

    function test_searchExpandsAncestorsOnly() {
        const t = stdTree(" filterTreeNode: true")
        t.searchBy("北京")
        compare(t.filteredExpandedList().sort(), ["0", "0-0"], "命中的祖先展开，自己不含");
        compare(t.rowKeys(), ["0", "0-0", "0-0-0", "0-0-1", "0-1", "1"],
            "showFilteredOnly=false ⇒ 祖先的其它孩子照样露出来");
        t.destroy()
    }

    function test_rowsReadFilteredExpandedWhileSearching() {
        const t = stdTree(" filterTreeNode: true expandedKeys: [\"0\", \"0-0\"]")
        compare(t.rowField(0, "expanded"), true);
        t.searchBy("大阪")
        compare(t.rowField(0, "expanded"), true, "亚洲是命中的祖先");
        compare(t.rowField(1, "expanded"), false, "中国不再是展开集里的一员");
        t.destroy()
    }

    function test_showFilteredOnlyHidesOthers() {
        const t = stdTree(" filterTreeNode: true showFilteredOnly: true")
        t.searchBy("上海")
        compare(t.rowKeys(), ["0", "0-0", "0-0-1"], "只留命中及其祖先");
        t.destroy()
    }

    function test_noMatchKeepsCollapsedRoots() {
        // showFilteredOnly=false + 无命中 ⇒ 不是空态，是所有根收起着展示（上游就这样）
        const t = stdTree(" filterTreeNode: true")
        t.searchBy("不存在的东西")
        compare(t.filteredKeysList(), []);
        compare(t.noData, false, "keyEntities 不空就不算没数据");
        compare(t.rowKeys(), ["0", "1"]);
        compare(t.rowField(0, "expanded"), false);
        t.destroy()
    }

    function test_noMatchWithShowFilteredOnlyIsEmpty() {
        const t = stdTree(" filterTreeNode: true showFilteredOnly: true")
        t.searchBy("不存在的东西")
        compare(t.noData, true);
        compare(part(t, "treeEmptyText").text, "暂无数据");
        t.destroy()
    }

    function test_onSearchPayload() {
        const t = stdTree(" filterTreeNode: true")
        var got = null
        var input = null
        t.search.connect((i, keys) => { input = i; got = keys })
        t.searchBy("美国")
        compare(input, "美国");
        compare(got, ["1"], "入参是给展开用的 filteredExpandedKeys");
        t.destroy()
    }

    function test_clearSearchMergesSelectedAncestors() {
        // foundation.ts:532-535：清空搜索把「选中项及其祖先」并进 expandedKeys
        const t = stdTree(" filterTreeNode: true")
        t.handleNodeSelect("0-0-1")
        t.searchBy("北京");
        t.searchBy("")
        compare(t.expandedKeysList().sort(), ["0", "0-0", "0-0-1"],
            "选中项自己也进来（findAncestorKeys self=true）");
        compare(t.rowKeys(), ["0", "0-0", "0-0-0", "0-0-1", "0-1", "1"]);
        t.destroy()
    }

    function test_searchRenderFalseHidesBoxButKeepsApi() {
        const t = stdTree(" filterTreeNode: true searchRender: false")
        compare(t.searchVisible, false, "官方 demo「手动触发搜索」");
        t.searchBy("大阪");
        compare(t.rowKeys(), ["0", "0-0", "0-1", "0-1-0", "1"]);
        t.destroy()
    }

    function test_filterTreeNodeFunction() {
        const t = stdTree(" filterTreeNode: function (input, target, data) { return data.key === input }")
        t.searchBy("1-1");
        compare(t.filteredKeysList(), ["1-1"], "函数档完全接管判定");
        t.destroy()
    }

    function test_treeNodeFilterProp() {
        const t = stdTree(" filterTreeNode: true treeNodeFilterProp: \"value\"")
        t.searchBy("osaka");
        compare(t.filteredKeysList(), ["0-1-0"], "按 value 搜");
        t.destroy()
    }

    function test_keyMapsLabelIsDefaultFilterProp() {
        // realFilterProp: treeNodeFilterProp==='label' 时改读 keyMaps.label
        const t = make("Tree { filterTreeNode: true; keyMaps: ({label: \"title\"}); "
            + "treeData: [{key:\"a\",title:\"标题甲\"},{key:\"b\",title:\"标题乙\"}] }")
        t.searchBy("标题甲");
        compare(t.filteredKeysList(), ["a"]);
        t.searchBy("标题乙");
        compare(t.filteredKeysList(), ["b"], "另一条不会被误命中");
        t.destroy()
    }

    function test_keyMapsCustomProps() {
        const t = make("Tree { keyMaps: ({key: \"k\", value: \"v\", children: \"sub\", "
            + "disabled: \"off\", isLeaf: \"leaf\"}); "
            + "treeData: [{k:\"a\",v:\"VA\",sub:[{k:\"a1\",v:\"VA1\"}]},{k:\"b\",off:true,leaf:true}] }")
        compare(t.rowKeys(), ["a", "b"], "children 别名生效");
        compare(t.rowField(0, "labelText"), "", "label 没别名 ⇒ 空文字");
        t.requestExpand("a")
        compare(t.rowKeys(), ["a", "a1", "b"], "展开按别名找孩子");
        compare(t.rowField(idx(t, "b"), "disabled"), true, "disabled 别名生效");
        compare(t.rowField(idx(t, "b"), "isLeaf"), true, "isLeaf 别名生效");
        var got = null
        t.change.connect((v) => { got = v })
        t.handleNodeSelect("a1")
        compare(got, "VA1", "value 别名进 onChange");
        t.destroy()
    }

    function test_highlightOnlyWhenFilteredAndKeyword() {
        const t = stdTree(" filterTreeNode: true")
        t.requestExpand("0")
        settle(t)
        compare(part(t.rowItem(0, 0), "treeLabelText").text, "亚洲");
        t.searchBy("大阪")
        settle(t)
        const hitIndex = t.rowKeys().indexOf("0-1-0")
        verify(hitIndex >= 0, "大阪在列表里");
        compare(t.rowField(hitIndex, "filtered"), true, "命中的是大阪");
        const row = t.rowItem(hitIndex, 0)
        compare(part(row, "treeLabelHighlight").visible, true, "命中的那行换 Highlight");
        compare(part(row, "treeLabelText").visible, false);
        const plain = t.rowItem(0, 0)
        compare(part(plain, "treeLabelHighlight").visible, false, "没命中的行不变");
        compare(part(plain, "treeLabelText").visible, true);
        t.destroy()
    }

    function test_renderLabelReplacesAndStopsHighlight() {
        const t = stdTree(" filterTreeNode: true")
        t.renderLabel = hookTextComp
        t.searchBy("大阪")
        const row = t.rowItem(2, 0)
        compare(part(row, "treeLabelHighlight").visible, false,
            "renderLabel 接管后官方不再自动高亮（treeNode.tsx:321）");
        verify(testCase.findChild(row, "hookText") !== null, "钩子节点要渲染出来");
        t.destroy()
    }

    // ============================================================ treeDataSimpleJson
    function test_jsonShape() {
        const t = make("Tree { treeDataSimpleJson: ({Node1: {\"Child Node1\": \"0-0-1\", \"Child Node2\": \"0-0-2\"}, Node2: \"0-1\"}) }")
        compare(t.jsonMode, true);
        compare(t.rowKeys(), ["Node1", "Node2"]);
        compare(t.rowField(0, "labelText"), "Node1", "JSON 的键就是 label");
        compare(t.rowField(1, "value"), "0-1");
        t.requestExpand("Node1")
        compare(t.rowKeys(), ["Node1", "Node1" + t.jsonSplit() + "Child Node1",
            "Node1" + t.jsonSplit() + "Child Node2", "Node2"],
            "子节点 key 用 _SEMI_TREE_SPLIT_ 拼路径");
        compare(t.rowField(1, "labelText"), "Child Node1", "label 只是键名");
        t.destroy()
    }

    function test_jsonOnChangeIsShallowPick() {
        // 官方 notifyJsonChange 的 pick 是浅的：路径带点 ⇒ 顶层对象里查不到 ⇒ 空对象
        const t = make("Tree { treeDataSimpleJson: ({Node1: {\"Child Node1\": \"0-0-1\"}, Node2: \"0-1\"}) }")
        var got = null
        t.change.connect((v) => { got = v })
        t.requestExpand("Node1")
        t.handleNodeSelect(t.rowKeys()[1])
        verify(got !== null, "子节点那一下也要发 onChange");
        compare(Object.keys(got).length, 0, "onChange 拿到空对象（上游浅 pick 的毛病）");
        t.handleNodeSelect("Node2")
        compare(Object.keys(got), ["Node2"], "选中根节点才拿得到东西");
        t.destroy()
    }

    function test_jsonMultipleChange() {
        const t = make("Tree { multiple: true; treeDataSimpleJson: ({Node1: {\"Child Node1\": \"0-0-1\"}, Node2: \"0-1\"}) }")
        var got = null
        t.change.connect((v) => { got = v })
        t.handleNodeSelect("Node1")
        compare(Object.keys(got), ["Node1"], "根节点的键是浅的 ⇒ 拿得到东西");
        compare(t.checkedKeysList().sort(),
            ["Node1", "Node1" + t.jsonSplit() + "Child Node1"], "内部勾选是正常的");
        t.destroy()
    }

    // ============================================================ 异步加载
    function test_loadDataRunsOncePerNode() {
        const t = list("[{key:\"0\",label:\"展开加载\"},{key:\"2\",label:\"叶子\",isLeaf:true}]")
        var calls = []
        t.loadData = function (node, done) { calls.push(node.key); done() }
        t.requestExpand("0")
        compare(calls, ["0"]);
        verify("0" in t.loadedMapView, "同步 done() 之后进 loadedKeys");
        compare(Object.keys(t.loadingMapView).length, 0, "done 之后 loadingKeys 清空");
        t.requestExpand("0")
        compare(calls.length, 1, "已加载的不再调");
        t.destroy()
    }

    function test_loadingStateWhilePending() {
        const t = list("[{key:\"0\",label:\"展开加载\"}]")
        var pendingDone = null
        t.loadData = function (node, done) { pendingDone = done }
        t.requestExpand("0")
        compare(t.loadingKeysList(), ["0"], "等待期间是 loading");
        compare(t.rowField(0, "loading"), true);
        compare(t.rowField(0, "expanded"), true, "展开状态照样给");
        pendingDone()
        compare(t.loadingKeysList(), []);
        compare(t.loadedKeysList(), ["0"]);
        t.destroy()
    }

    function test_onLoadFiresWithLoadedKeys() {
        const t = list("[{key:\"0\",label:\"展开加载\"}]")
        var gotKeys = null
        var gotNode = null
        t.load.connect((keys, node) => { gotKeys = keys; gotNode = node })
        t.loadData = function (node, done) { done() }
        t.requestExpand("0")
        compare(gotKeys, ["0"]);
        compare(gotNode.key, "0");
        t.destroy()
    }

    function test_leafWithLoadDataNeedsIsLeaf() {
        // handleNodeExpand 的门槛是 loadData || 有孩子；isLeaf 只影响画不画箭头
        const t = list("[{key:\"0\",label:\"能展开\",children:[{key:\"0-0\",label:\"子\"}]},"
            + "{key:\"1\",label:\"没孩子\"}]", " loadData: function (n, done) { done() }")
        t.requestExpand("1")
        verify("1" in t.expandedMapView, "有 loadData 时没孩子的也会被记成展开（官方如此）");
        compare(t.rowField(1, "isLeaf"), true, "但它不画箭头");
        compare(t.rowField(0, "isLeaf"), false);
        t.destroy()
    }

    function test_loadedKeysControlled() {
        const t = list("[{key:\"0\",label:\"甲\"}]", " loadedKeys: [\"0\"]")
            t.loadData = function (node, done) { done() }
        t.requestExpand("0")
        compare(t.loadedKeysList(), ["0"]);
        compare(Object.keys(t.loadingMapView).length, 0, "已经 loaded 的不再进 loading");
        t.destroy()
    }

    function test_loadDataKeepsExpansionOnDataChange() {
        // index.tsx:379-394：loadData 引起的 treeData 更新不能重算 expandedKeys
        const t = list("[{key:\"0\",label:\"甲\"}]", " value: undefined")
        t.loadData = function (node, done) { done() }
        t.requestExpand("0")
        t.treeData = [{ key: "0", label: "甲", children: [{ key: "0-0", label: "子" }] }]
        compare(t.expandedKeysList(), ["0"], "已展开的那条没被收回去");
        compare(t.rowKeys(), ["0", "0-0"]);
        t.destroy()
    }

    function test_valueAndDataChangeRecalcsExpansion() {
        // 官方只在**挂载**时用 value 播展开；运行中换 value 不重算（gDSFP 那条
        // !prevProps 门槛），要等 treeData 变化才会重算 —— 没有 loadData 时才会
        const t = stdTree()
        t.value = "Shanghai"
        compare(t.selectedListView, ["0-0-1"], "选区跟着 value 走");
        compare(t.rowKeys().length, 2, "但展开集合不受运行期 value 影响");
        t.treeData = [{ key: "z", label: "新", children: [{ key: "z-0", label: "新子", value: "Shanghai" }] }]
        compare(t.expandedKeysList(), ["z"], "数据变化时才按 value 重算祖先");
        compare(t.rowKeys().length, 2);
        t.destroy()
    }

    // ============================================================ motion
    function test_expandMotionWrapsShownRows() {
        const t = stdTree()
        compare(t.entryCount, 2);
        t.requestExpand("0")
        compare(t.motionTypeView, "show");
        compare(Object.keys(t.motionMapView).sort(), ["0-0", "0-1"],
            "getMotionKeys 给这一层新出现的键");
        compare(t.entryCount, 3, "亚洲 + 一个动画组 + 北美洲");
        compare(t.rowCount(), 4, "逻辑行是 4 条");
        compare(t.rowItem(1, 1) !== null, true, "组里第二行也实例化了");
        settle(t)
        compare(t.entryCount, 4, "动画收完就是普通四行");
        t.destroy()
    }

    function test_collapseMotionUsesCachedFlatten() {
        const t = stdTree()
        t.requestExpand("0")
        settle(t)
        t.requestExpand("0")
        compare(t.motionTypeView, "hide");
        compare(t.entryCount, 3, "收起时动画组仍然带着要消失的行");
        compare(t.rowCount(), 2, "flatten 已经没有它们了");
        verify(t.rowItem(1, 0) !== null, "缓存那份仍然渲染得出（不是 null）");
        settle(t)
        compare(t.entryCount, 2);
        t.destroy()
    }

    function test_motionFalseHasNoGroup() {
        const t = stdTree(" motion: false")
        t.requestExpand("0")
        compare(t.entryCount, 4, "关掉动画就直接铺好");
        compare(t.rowItem(1, 1), null, "没有组，第二下标就是普通行");
        t.destroy()
    }

    function test_nestedExpandMotionKeysDeeper() {
        // getMotionKeys 只往「已经展开的子级」递归（treeUtil.ts:492-507）
        const t = stdTree()
        t.requestExpand("0-0")
        compare(Object.keys(t.motionMapView).sort(), ["0-0-0", "0-0-1"],
            "先展开一个看不见的世界：动画区间落在它自己的孩子上");
        compare(t.entryCount, 2, "被展开的那一行根本不在列表里 ⇒ 没有可动画的节点");
        // 官方此时也不会清 motionKeys（NodeCollapsible 没挂上，onMotionEnd 不会来），
        // 下一次更新会把它整份覆盖掉
        t.requestExpand("0")
        compare(Object.keys(t.motionMapView).sort(),
            ["0-0", "0-0-0", "0-0-1", "0-1"], "中国已展开 ⇒ 递归把它的孩子也算进动画区间");
        settle(t)
        compare(t.rowKeys(), ["0", "0-0", "0-0-0", "0-0-1", "0-1", "1"]);
        t.destroy()
    }

    function test_controlledExpandSkipsMotion() {
        const t = stdTree(" expandedKeys: []")
        t.requestExpand("0")
        compare(Object.keys(t.motionMapView).length, 0, "受控时 setExpandedStatus 不写状态");
        t.expandedKeys = ["0"]
        compare(t.rowCount(), 4, "换属性才展开");
        t.destroy()
    }

    function test_dataChangeDisablesMotionKeys() {
        const t = stdTree()
        t.requestExpand("0")
        settle(t)
        t.treeData = [{ key: "z", label: "新根" }]
        compare(Object.keys(t.motionMapView).length, 0, "数据变化时官方把动画关掉");
        compare(t.motionTypeView, "", "motionType 被置空");
        t.destroy()
    }

    // 官方 NodeList 折出来的 transitionNodes 里存的只是「哪些位置」，行的内容是
    // renderTreeNode 现场拿 getTreeNodeProps 取的 ⇒ 动画区间不借「内容」。
    // 端口曾经整段吃缓存那份行，表现是收起那 200ms 里父行箭头还指着展开态。
    function test_collapseParentRowFlipsImmediately() {
        const t = stdTree(" defaultExpandedKeys: ['0']")
        waitForRendering(t)
        wait(30)
        compare(t.rowCount(), 4, "起手中国、日本都看得见")
        t.requestExpand("0")
        compare(t.entryCount, 3, "动画组挂着")
        t.handleNodeSelect("0")
        compare(t.rowItem(0, 0).expanded, false,
            "父行的箭头当场就翻了（不是等动画收完才翻）")
        compare(t.rowItem(0, 0).selected, true,
            "父行的底色也当场跟着选区亮（不是缓存那份旧记录）")
        settle(t)
        t.destroy()
    }

    // 组里那几条同理：动画期间才改的选区，正在消失的那行得当场亮
    function test_groupRowsFollowSelectionDuringCollapse() {
        const t = stdTree()
        t.requestExpand("0")
        settle(t)
        compare(t.rowCount(), 4)
        t.requestExpand("0")
        t.handleNodeSelect("0-1")
        compare(t.rowItem(1, 1).rec.key, "0-1", "组里第二条还是日本")
        compare(t.rowItem(1, 1).selected, true,
            "选区跟着当前状态，不是缓存那份旧记录")
        compare(t.rowItem(1, 0).selected, false, "没选中的那条不该跟着亮")
        settle(t)
        t.destroy()
    }

    // ============================================================ 虚拟化
    function test_virtualizeUsesListView() {
        const t = stdTree(" virtualize: ({itemSize: 40, height: 120})")
        compare(t.useVirtualList, true);
        compare(t.rowHeight, 40, "行高取 itemSize");
        compare(part(t, "treeVirtualList").height, 120, "height 给数字就用它");
        compare(t.labelEllipsisOn, true, "虚拟化档默认开启省略");
        t.destroy()
    }

    function test_virtualizeEmptyObjectIsOff() {
        const t = stdTree(" virtualize: ({})")
        compare(t.useVirtualList, false, "空对象等于没开（index.tsx:782 isEmpty）");
        compare(t.rowHeight, 28);
        compare(t.labelEllipsisOn, false);
        t.destroy()
    }

    function test_virtualizeHeightDefaultsToFill() {
        const t = stdTree(" virtualize: ({itemSize: 28})")
        t.height = 200
        compare(t.virtualBoxHeight, 200, "'100%' ⇒ 用可用高度");
        t.filterTreeNode = true
        compare(t.virtualBoxHeight, 152, "减掉搜索区那 48");
        t.destroy()
    }

    function test_virtualizeWidth() {
        const t = stdTree(" virtualize: ({itemSize: 28, width: 180})")
        compare(t.virtualBoxWidth, 180);
        t.destroy()
    }

    function test_scrollToNoopWhenNotVirtual() {
        // 官方 :612 那条 ?. 只在虚拟化 ref 存在时生效
        const t = stdTree(" defaultExpandAll: true")
        t.height = 120
        const flick = part(t, "treeFlickable")
        const before = flick.contentY
        t.scrollTo({ key: "1-1", align: "end" })
        compare(flick.contentY, before, "非虚拟化调了什么都不做");
        t.destroy()
    }

    function test_scrollToMovesVirtualList() {
        const t = stdTree(" virtualize: ({itemSize: 28, height: 100}) defaultExpandAll: true")
        t.height = 100
        compare(t.rowCount(), 9);
        t.scrollTo({ key: "1-1", align: "end" })
        tryVerify(function () { return t._virtualList.contentY > 0; }, 800);
        verify(t._virtualList.contentY > 0, "滚动确实发生了");
        t.scrollTo({ key: "0", align: "start" })
        tryVerify(function () { return t._virtualList.contentY === 0; }, 800);
        compare(t._virtualList.contentY, 0, "start 把它顶到最上");
        t.destroy()
    }

    function test_scrollToUnknownKeyDoesNothing() {
        const t = stdTree(" virtualize: ({itemSize: 28, height: 100}) defaultExpandAll: true")
        const before = t._virtualList.contentY
        t.scrollTo({ key: "不存在" })
        compare(t._virtualList.contentY, before);
        t.scrollTo({});
        t.destroy()
    }

    // ============================================================ 拖拽
    function test_dragSequence() {
        const t = stdTree(" draggable: true autoExpandWhenDragEnter: false")
        t.requestExpand("0")
        settle(t)
        const log = []
        t.dragStart.connect((n) => log.push("start:" + n.key));
        t.dragEnter.connect((n) => log.push("enter:" + n.key));
        t.dragLeave.connect((n) => log.push("leave:" + n.key));
        t.drop.connect((n, dn, keys, pos, gap) => log.push("drop:" + n.key + "/" + pos + "/" + gap));
        t.dragEnd.connect((n) => log.push("end:" + n.key));
        const host = t._listHost
        mousePress(host, 130, 8 + 14)
        wait(20)
        mouseMove(host, 130, 8 + 28 + 14, Qt.LeftButton)   // 移到中国（自己的子孙）⇒ 忽略
        wait(20)
        mouseMove(host, 130, 8 + 3 * 28 + 14, Qt.LeftButton)  // 移到北美洲
        tryVerify(function () { return t.dragOverView === "1"; }, 800);
        compare(t.dragOverView, "1");
        mouseRelease(host, 130, 8 + 3 * 28 + 14, Qt.LeftButton)
        wait(40)
        compare(log, ["start:0", "leave:0-0", "enter:1", "drop:1/1/false", "end:0"],
            "中国是拖拽源的子孙 ⇒ 它的 dragenter 被跳过，但离开时仍发 leave");
        t.destroy()
    }

    function test_dragDropPositionGap() {
        const t = stdTree(" draggable: true autoExpandWhenDragEnter: false")
        t.requestExpand("0")
        settle(t)
        var dropInfo = null
        t.drop.connect((n, dn, keys, pos, gap) => {
            dropInfo = { key: n.key, pos: pos, gap: gap, keys: keys.slice() };
        })
        const host = t._listHost
        mousePress(host, 130, 8 + 14)                          // 亚洲
        wait(20)
        mouseMove(host, 130, 8 + 28 * 3 + 25, Qt.LeftButton)    // 北美洲下沿 ⇒ rel +1
        tryVerify(function () { return t.dragOverView === "1" && t.dropPosView === 1; }, 800);
        compare(t.dropPosView, 1, "落点在行下 45% 之外 ⇒ +1");
        mouseRelease(host, 130, 8 + 28 * 3 + 25, Qt.LeftButton)
        wait(40)
        compare(dropInfo.gap, true, "落在两行之间");
        compare(dropInfo.pos, 2, "calcDropActualPosition = 1 + pos 末位 1");
        dropInfo.keys.sort()
        compare(dropInfo.keys, ["0", "0-0", "0-0-0", "0-0-1", "0-1", "0-1-0"],
            "dragNodesKeys 是整棵子树（连没展开的也算）");
        t.destroy()
    }

    function test_dragOntoSelfIsIgnored() {
        const t = stdTree(" draggable: true")
        var drops = 0
        t.drop.connect(() => drops++)
        const host = t._listHost
        mousePress(host, 130, 8 + 14)
        wait(20)
        mouseMove(host, 130, 8 + 14, Qt.LeftButton)
        wait(30)
        compare(t.dragOverView, "", "落在自己身上且位置为 0 ⇒ 清掉状态");
        compare(t.dropPosView, null);
        mouseRelease(host, 130, 8 + 14, Qt.LeftButton)
        wait(40)
        compare(drops, 0, "不产生 drop");
        t.destroy()
    }

    function test_dragKeepsExpandedAndPosInPayload() {
        const t = stdTree(" draggable: true")
        t.requestExpand("0")
        settle(t)
        var node = null
        t.drop.connect((n) => { node = n })
        const host = t._listHost
        mousePress(host, 130, 8 + 14)
        wait(20)
        mouseMove(host, 130, 8 + 28 * 3 + 14, Qt.LeftButton)
        tryVerify(function () { return t.dragOverView === "1"; }, 800);
        mouseRelease(host, 130, 8 + 28 * 3 + 14, Qt.LeftButton)
        wait(40)
        compare(node.key, "1");
        compare(node.pos, "0-1", "getDragEventNodeData 带 pos");
        compare(node.expanded, false, "还带展开状态");
        compare(node.children.length, 2, "payload 还带着 children 原数组");
        t.destroy()
    }

    function test_dragAutoExpandAfterHold() {
        // 收起态的 std 树：第 0 行亚洲、第 1 行北美洲。从北美洲按住，拖到亚洲上悬着。
        const t = stdTree(" draggable: true")
        const log = []
        t.dragEnter.connect((n, ek) => log.push((ek === undefined ? "plain" : "exp") + ":" + n.key));
        const host = t._listHost
        mousePress(host, 130, 8 + 28 + 14)
        wait(20)
        mouseMove(host, 130, 8 + 14, Qt.LeftButton)
        tryVerify(function () { return t.dragOverView === "0"; }, 800);
        compare(log, [], "400ms 之前不报 dragenter（官方 delayedDragEnterLogic 那一段）");
        verify(!("0" in t.expandedMapView), "也还没展开");
        wait(600)
        tryVerify(function () { return "0" in t.expandedMapView; }, 1500);
        compare(log, ["exp:0"], "到点自动展开，并补一次带 expandedKeys 的 dragenter");
        compare(t.rowKeys(), ["0", "0-0", "0-1", "1"]);
        mouseRelease(host, 130, 8 + 14, Qt.LeftButton)
        wait(40)
        t.destroy()
    }

    function test_autoExpandWhenDragEnterFalse() {
        const t = stdTree(" draggable: true autoExpandWhenDragEnter: false")
        const host = t._listHost
        mousePress(host, 130, 8 + 28 + 14)
        wait(20)
        mouseMove(host, 130, 8 + 14, Qt.LeftButton)
        tryVerify(function () { return t.dragOverView === "0"; }, 800);
        wait(600)
        compare(Object.keys(t.expandedMapView).length, 0, "关掉后悬停不展开");
        mouseRelease(host, 130, 8 + 14, Qt.LeftButton)
        wait(40)
        t.destroy()
    }

    function test_dragDisabledRowDoesNotStart() {
        const t = list("[{key:\"a\",label:\"甲\",disabled:true},{key:\"b\",label:\"乙\"}]",
            " draggable: true")
        var starts = 0
        t.dragStart.connect(() => starts++)
        const host = t._listHost
        mousePress(host, 130, 8 + 14)
        wait(20)
        mouseMove(host, 130, 8 + 40, Qt.LeftButton)
        wait(40)
        compare(starts, 0, "禁用行不能起手（draggable 属性只给 !disabled）");
        compare(t.draggingView, false);
        mouseRelease(host, 130, 8 + 40, Qt.LeftButton)
        t.destroy()
    }

    function test_draggableShiftsContentTwoPx() {
        const t = list("[{key:\"a\",label:\"甲\",disabled:true},{key:\"b\",label:\"乙\"}]",
            " draggable: true")
        const off = t.rowItem(0, 0)
        const on = t.rowItem(1, 0)
        compare(off.caretX, 8, "禁用行没有那 2px 左边框");
        compare(on.caretX, 10, "可拖行整体右移 2px");
        near(on.height, 28, "行高不变");
        t.destroy()
    }

    function test_dragVisualStates() {
        const t = stdTree(" draggable: true defaultExpandAll: true autoExpandWhenDragEnter: false")
        settle(t)
        const host = t._listHost
        // 源用「加拿大」（第 8 行）：它的子树只有自己，目标行才不会被 dragNodesKeys 挡掉
        mousePress(host, 130, 8 + 28 * 8 + 14)
        wait(20)
        mouseMove(host, 130, 8 + 28 * 4 + 5, Qt.LeftButton)
        tryVerify(function () { return t.dragOverView === "0-1" && t.dropPosView === -1; }, 800);
        compare(part(t.rowItem(4, 0), "treeDragGapBottom").visible, false);
        compare(part(t.rowItem(4, 0), "treeDragGapTop").visible, true, "上沿标示线");
        compare(part(t.rowItem(4, 0), "treeDragOverBox").visible, false);
        mouseMove(host, 130, 8 + 28 * 4 + 25, Qt.LeftButton)
        tryVerify(function () { return t.dropPosView === 1; }, 800);
        compare(part(t.rowItem(4, 0), "treeDragGapBottom").visible, true, "下沿标示线");
        compare(part(t.rowItem(4, 0), "treeDragGapTop").visible, false, "上沿收回");
        mouseMove(host, 130, 8 + 28 * 4 + 14, Qt.LeftButton)
        tryVerify(function () { return t.dropPosView === 0; }, 800);
        compare(part(t.rowItem(4, 0), "treeDragOverBox").visible, true, "落在行上 ⇒ 整圈边框");
        compare(part(t.rowItem(4, 0), "treeDragGapBottom").visible, false);
        mouseRelease(host, 130, 8 + 28 * 4 + 14, Qt.LeftButton)
        wait(40)
        compare(part(t.rowItem(4, 0), "treeDragOverBox").visible, false, "松手就清掉");
        t.destroy()
    }

    // ============================================================ 真实点击分流
    function test_clickTextSelects() {
        const t = stdTree(" defaultExpandAll: true")
        settle(t)
        var sel = null
        t.select.connect((k, s) => { sel = k + ":" + s })
        mouseClick(t.rowItem(0, 0), 120, 14)
        wait(40)
        compare(sel, "0:true");
        compare(t.selectedListView, ["0"]);
        compare(t.expandedKeysList().length, 9, "选中不动展开集合");
        t.destroy()
    }

    function test_clickCaretExpandsOnly() {
        const t = stdTree()
        var sel = 0
        t.select.connect(() => sel++)
        const row = t.rowItem(0, 0)
        mouseClick(row, row.caretX + 6, 14)
        wait(40)
        settle(t)
        compare(t.expandedKeysList(), ["0"], "点箭头展开");
        compare(sel, 0, "但没有选中");
        t.destroy()
    }

    function test_clickCheckboxTogglesOnce() {
        const t = stdTree(" multiple: true defaultExpandAll: true")
        settle(t)
        var changes = 0
        t.change.connect(() => changes++)
        const row = t.rowItem(2, 0)
        mouseClick(row, row.checkX + 8, row.height / 2)
        wait(40)
        compare(changes, 1, "点复选框只翻一次（父子两套 handler 不会各来一遍）");
        compare(t.checkedKeysList().sort(), ["0-0-0"]);
        t.destroy()
    }

    function test_clickGapAfterCaretSelects() {
        // 箭头只有 12px 可点，它右边那 8px 属于行 ⇒ 选中而不是展开
        const t = stdTree()
        const row = t.rowItem(0, 0)
        mouseClick(row, row.caretX + 16, 14)
        wait(40)
        compare(Object.keys(t.expandedMapView).length, 0, "没展开");
        compare(t.selectedListView, ["0"], "选中了");
        t.destroy()
    }

    function test_rightClickEmitsContextMenu() {
        const t = stdTree(" defaultExpandAll: true")
        var node = null
        t.contextMenu.connect((n) => { node = n })
        mouseClick(t.rowItem(1, 0), 120, 14, Qt.RightButton)
        wait(40)
        compare(node.key, "0-0");
        t.destroy()
    }

    // QtTest 的合成点击不会让 TapHandler 认定双击（实测 tapCount 恒为 1，
    // 见 tests/tmp_dbl_probe.qml），所以双击路径一律从 rowDoubleClicked 进；
    // 行上的 doubleTapped 连接在 cocoa 真鼠标下才摸得到。
    function test_doubleClickEmitsAndNoExpand() {
        const t = stdTree()
        var dbl = null
        var clicks = 0
        t.doubleClick.connect((n) => { dbl = n.key })
        t.change.connect(() => clicks++)
        t.rowDoubleClicked("0")
        compare(dbl, "0");
        compare(clicks, 0, "expandAction=false 时双击不选中");
        compare(Object.keys(t.expandedMapView).length, 0, "也不展开");
        t.destroy()
    }

    function test_expandActionClick() {
        const t = stdTree(" expandAction: \"click\"")
        mouseClick(t.rowItem(0, 0), 120, 14)
        wait(40)
        settle(t)
        compare(t.expandedKeysList(), ["0"], "点行就展开");
        compare(t.selectedListView, ["0"], "同时选中");
        t.destroy()
    }

    function test_expandActionDoubleClick() {
        const t = stdTree(" expandAction: \"doubleClick\"")
        mouseClick(t.rowItem(0, 0), 120, 14)
        wait(40)
        compare(t.selectedListView, ["0"], "第一次点选");
        compare(Object.keys(t.expandedMapView).length, 0, "但这时还不展开");
        // 官方 debounce(500, leading)：窗口内的第二次 click 无效
        mouseClick(t.rowItem(0, 0), 120, 14)
        wait(60)
        compare(t.selectedListView, ["0"], "第二下的 click 被防抖吞掉");
        t.rowDoubleClicked("0")
        wait(40)
        settle(t)
        compare(t.expandedKeysList(), ["0"], "doubleClick 才展开");
        t.destroy()
    }

    function test_expandActionDoubleClickAfterGate() {
        // debounce(500, {leading:true, trailing:false})：窗口过去以后又能选了
        const t = stdTree(" multiple: true expandAction: \"doubleClick\"")
        var changes = 0
        t.change.connect(() => changes++)
        mouseClick(t.rowItem(0, 0), 120, 14)
        wait(40)
        compare(changes, 1);
        mouseClick(t.rowItem(0, 0), 120, 14)
        wait(40)
        compare(changes, 1, "窗口内的第二次被吞");
        wait(600)
        mouseClick(t.rowItem(0, 0), 120, 14)
        wait(40)
        compare(changes, 2, "窗口过了才再发");
        compare(Object.keys(t.checkedMapView).length, 0, "第二次是取消勾选");
        t.destroy()
    }

    // ============================================================ 行几何与外观
    function test_rowHeightAndWidths() {
        const t = stdTree(" defaultExpandAll: true")
        settle(t)
        for (let i = 0; i < t.rowCount(); ++i) {
            const r = t.rowItem(i, 0)
            near(r.height, 28, "第 " + i + " 行高");
            near(r.width, 260, "第 " + i + " 行宽");
        }
        t.destroy()
    }

    function test_indentGeometry() {
        const t = stdTree(" defaultExpandAll: true multiple: true")
        settle(t)
        compare(t.rowField(0, "level"), 0);
        near(t.rowItem(0, 0).caretX, 8);
        near(t.rowItem(1, 0).caretX, 28, "level 1 ⇒ 8+20");
        near(t.rowItem(2, 0).caretX, 48, "level 2 ⇒ 8+40");
        near(t.rowItem(0, 0).checkX, 28, "箭头 12 + 8 之后才是复选框");
        near(t.rowItem(0, 0).textX, 52, "复选框 16 + 8 之后是文字");
        t.destroy()
    }

    function test_inlineModeHasNoFullRowHighlight() {
        const t = stdTree(" blockNode: false defaultExpandAll: true")
        settle(t)
        const row = t.rowItem(0, 0)
        compare(part(row, "treeRowBg").visible, false, "非整行档不画整行底色");
        mouseClick(row, 200, 14)
        wait(40)
        const bg = part(t.rowItem(0, 0), "treeLabelBg")
        compare(bg.visible, true, "选中底色画在 -label 上");
        compare(bg.color, Theme.current.colorPrimaryLightDefault);
        compare(bg.height, 20);
        compare(bg.x, t.rowItem(0, 0).iconX);
        near(bg.width, t.rowItem(0, 0).textX + t.rowItem(0, 0).textWidth - t.rowItem(0, 0).iconX,
            "宽度只到文字末尾");
        t.destroy()
    }

    function test_blockModeSelectedPaintsWholeRow() {
        const t = stdTree(" defaultExpandAll: true")
        settle(t)
        t.handleNodeSelect("0-1")
        const sel = t.rowItem(t.rowKeys().indexOf("0-1"), 0)
        compare(part(sel, "treeRowBg").color, Theme.current.colorPrimaryLightDefault);
        compare(part(sel, "treeRowBg").width, 260, "整行");
        verify(clear(part(t.rowItem(0, 0), "treeRowBg").color), "另一行不受影响");
        t.destroy()
    }

    function test_blockModeHoverAndPressColors() {
        const t = stdTree(" defaultExpandAll: true")
        settle(t)
        const row = t.rowItem(0, 0)
        mouseMove(row, 120, 14)
        wait(60)
        const again = t.rowItem(0, 0)
        compare(part(again, "treeRowBg").color, Theme.current.colorFill0);
        verify(clear(part(t.rowItem(1, 0), "treeRowBg").color), "邻居没亮");
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(60)
        mousePress(t.rowItem(0, 0), 120, 14)
        wait(60)
        compare(part(t.rowItem(0, 0), "treeRowBg").color, Theme.current.colorFill1,
            ":active 比 :hover 后写 ⇒ 按下色压过悬浮色");
        mouseRelease(t.rowItem(0, 0), 120, 14)
        wait(40)
        t.destroy()
    }

    function test_selectedBeatsHoverColor() {
        const t = stdTree(" defaultExpandAll: true")
        settle(t)
        t.handleNodeSelect("0")
        mouseMove(t.rowItem(0, 0), 120, 14)
        wait(60)
        compare(part(t.rowItem(0, 0), "treeRowBg").color, Theme.current.colorPrimaryLightDefault,
            "selected 的规则写在 hover 之后，压过悬浮色");
        t.destroy()
    }

    function test_hoverColorSurvivesDelegateRebuild() {
        // 展开/收起动画的起手与收尾各有一次 Repeater 重建（模型条目数变了），新委托上的
        // HoverHandler 要等下一个鼠标事件才认得已经在里面的指针 ⇒ 底色会掉一帧，
        // 用户看到的是「被点那一行一直在闪」。悬浮判定改成按容器项记下的指针位置算之后，
        // 重建与否都一样。
        const t = stdTree(" defaultExpandedKeys: [\"0\"]")
        settle(t)
        const first = t.rowItem(0, 0)
        mouseMove(first, 120, 14)
        wait(60)
        compare(part(t.rowItem(0, 0), "treeRowBg").color, Theme.current.colorFill0,
            "起手：指针停在第 0 行 ⇒ 整行底色是 hover 档")
        t.requestExpand("0")
        compare(part(t.rowItem(0, 0), "treeRowBg").color, Theme.current.colorFill0,
            "收起这一拍中间没再发任何鼠标事件 ⇒ 底色还在")
        settle(t)
        verify(t.rowItem(0, 0) !== first, "收尾那一拍第 0 行的委托确实换了（不然这条断言是空转）")
        wait(40)            // 位置器要把新委托的 y 排好，下一拍才是最终几何
        compare(part(t.rowItem(0, 0), "treeRowBg").color, Theme.current.colorFill0,
            "换了委托底色照样在")
        // 反向控制：指针离开列表区就必须全灭（否则「一直亮」也能过上面三条）
        mouseMove(testCase, testCase.width - 2, testCase.height - 2)
        wait(60)
        verify(!t.hoverInside, "指针已经不在列表区里")
        verify(clear(part(t.rowItem(0, 0), "treeRowBg").color), "离开之后底色要掉回透明")
        t.destroy()
    }

    function test_hoverRectIsTheRowUnderThePointer() {
        // 悬浮按几何判定：直接喂容器的指针位置（不靠合成事件与位置器的那一拍），
        // 钉住「亮的是指针下那一行」与「被动画盒裁掉的那截不算」。
        const t = stdTree(" defaultExpandAll: true")
        settle(t)
        verify(t.rowCount() >= 3, "这棵树至少三行")
        const r1 = t.rowItem(1, 0)
        t.hoverInside = true
        t.hoverPoint = Qt.point(120, r1.originInColumn + r1.height / 2)
        compare(part(r1, "treeRowBg").color, Theme.current.colorFill0, "指针下那一行亮")
        verify(clear(part(t.rowItem(0, 0), "treeRowBg").color), "上面那行不亮")
        verify(clear(part(t.rowItem(2, 0), "treeRowBg").color), "下面那行不亮")
        t.hoverPoint = Qt.point(r1.width + 4, r1.originInColumn + r1.height / 2)
        verify(clear(part(r1, "treeRowBg").color), "行宽之外不亮")
        // 被裁掉的那截不算（clipBottom 由动画盒那一手喂进来）
        t.hoverPoint = Qt.point(120, r1.originInColumn + r1.height / 2)
        compare(part(r1, "treeRowBg").color, Theme.current.colorFill0, "先确认没裁的时候是亮的")
        r1.clipBottom = r1.originInColumn + 2
        verify(clear(part(r1, "treeRowBg").color), "被裁到只剩 2px ⇒ 指针那截不亮")
        r1.clipBottom = Number.MAX_VALUE
        t.hoverInside = false
        t.hoverPoint = Qt.point(120, r1.originInColumn + r1.height / 2)
        verify(clear(part(r1, "treeRowBg").color), "指针不在列表区里 ⇒ 不亮")
        // 箭头那一格与文字那一块各自的判定
        const r0 = t.rowItem(0, 0)
        t.hoverInside = true
        t.hoverPoint = Qt.point(r0.caretX + 5, r0.originInColumn + r0.contentMid)
        verify(r0.caretHovered, "落在箭头那 12px ⇒ 箭头算被悬停")
        verify(!r0.textHovered, "同一拍文字区不算被悬停")
        t.hoverPoint = Qt.point(r0.textX + 6, r0.originInColumn + r0.contentMid)
        verify(r0.textHovered, "落在文字上 ⇒ 文字区算被悬停")
        verify(!r0.caretHovered, "同一拍箭头不算被悬停")
        t.destroy()
    }

    function test_motionRowsGetTheirOffsetAndClipFromTheBox() {
        // 组里的行的上沿要连着「那一格的 y + 自己的 y」、下沿要连着动画盒此刻的高度：
        // 悬浮判定就吃这两个数，接错了整块会亮错行（或该亮的没亮）。
        const t = stdTree(" defaultExpandedKeys: [\"0\"]")
        settle(t)
        compare(t.rowItem(0, 0).originInColumn, t.entryAt(0).y, "普通行的上沿 = 那一格的 y")
        t.requestExpand("0")               // 收起：动画盒带着亚洲下面那三条行
        wait(40)
        const box = t.entryAt(1)
        verify(box !== null && box.isGroup, "第二格是动画组")
        for (let i = 0; i < 2; i++) {
            const inner = t.rowItem(1, i)
            verify(inner !== null, "组里第 " + i + " 行拿得到")
            compare(inner.originInColumn, box.y + inner.y, "组里第 " + i + " 行的上沿")
            compare(inner.clipBottom, box.y + box.boxHeight, "组里的行的裁剪下沿 = 盒的底")
        }
        settle(t)
        t.destroy()
    }

    function test_virtualRowsLightByTheirOwnOffset() {
        // 虚拟化那一套的行不在 entry 委托里，originInColumn 得跟着自己那一格的 y
        const t = stdTree(" virtualize: ({itemSize: 28, height: 200}) defaultExpandAll: true")
        settle(t)
        const r = t.virtualRowItem(2)
        verify(r !== null)
        mouseMove(r, 120, 14)
        wait(60)
        compare(part(t.virtualRowItem(2), "treeRowBg").color, Theme.current.colorFill0);
        verify(clear(part(t.virtualRowItem(1), "treeRowBg").color), "上一行没亮");
        verify(clear(part(t.virtualRowItem(3), "treeRowBg").color), "下一行没亮");
        t.destroy()
    }

    function test_inlineHoverOnlyOnText() {
        const t = stdTree(" blockNode: false defaultExpandAll: true")
        settle(t)
        const row = t.rowItem(0, 0)
        mouseMove(row, 10, 14)
        wait(60)
        verify(clear(part(t.rowItem(0, 0), "treeTextBg").color),
            "指针在箭头那格 ⇒ 文字框不亮");
        mouseMove(t.rowItem(0, 0), t.rowItem(0, 0).textX + 10, 14)
        wait(60)
        const bg = part(t.rowItem(0, 0), "treeTextBg")
        compare(bg.color, Theme.current.colorFill0);
        compare(bg.radius, Theme.current.radiusSmall);
        t.destroy()
    }

    function test_disabledRowTextColor() {
        const t = list("[{key:\"a\",label:\"甲\",disabled:true},{key:\"b\",label:\"乙\"}]")
        compare(part(t.rowItem(0, 0), "treeLabelText").color, Theme.current.colorDisabledText);
        compare(part(t.rowItem(1, 0), "treeLabelText").color, Theme.current.colorText0);
        t.destroy()
    }

    function test_caretIconAndRotation() {
        const t = stdTree()
        const parent = t.rowItem(0, 0)
        const icon = part(parent, "treeCaretIcon")
        compare(icon.name, "tree_triangle_down");
        compare(icon.size, 12, "$width-tree_emptyIcon");
        compare(icon.rotation, 270, "收起 ⇒ rotate(270deg)");
        compare(icon.color, Theme.current.colorText2);
        t.requestExpand("0")
        settle(t)
        compare(part(t.rowItem(0, 0), "treeCaretIcon").rotation, 0, "展开 ⇒ 不转");
        t.destroy()
    }

    function test_leafHasNoCaretButKeepsColumn() {
        const t = stdTree(" defaultExpandAll: true")
        settle(t)
        const leaf = t.rowItem(t.rowKeys().indexOf("0-0-0"), 0)
        verify(testCase.findChild(leaf, "treeCaretIcon") === null, "叶子没有箭头");
        near(leaf.textX, leaf.caretX + 20, "但 12+8 那一格照样占位");
        t.destroy()
    }

    function test_showLineIndentUnits() {
        const t = stdTree(" showLine: true defaultExpandAll: true")
        settle(t)
        // level 0 没有缩进格；level 1 一格；level 2 两格
        const lines = [];
        for (let i = 0; i < t.rowCount(); ++i) {
            const r = t.rowItem(i, 0);
            lines.push(r.lineUnitCount);
        }
        compare(lines, [0, 1, 2, 2, 1, 2, 0, 1, 1], "每行的缩进格数 = level");
        t.destroy()
    }

    function test_showLineSuppressesLastChildColumn() {
        // .-indent-unit-end::before { display: none } —— 那一层祖先是本层最后一个孩子时停线
        const t = stdTree(" showLine: true defaultExpandAll: true");
        settle(t)
        const canada = t.rowItem(idx(t, "1-1"), 0)
        compare(canada.ancestorIsEnd(0), true, "北美洲是最后一个根");
        compare(canada.lineItemAt(0).visible, false, "那一格的竖线不画");
        compare(canada.lineUnitCount, 1);
        const beijing = t.rowItem(idx(t, "0-0-0"), 0)
        compare(beijing.ancestorIsEnd(0), false, "亚洲不是最后一个根");
        compare(beijing.lineItemAt(0).visible, true, "中国/亚洲那格照画");
        near(beijing.lineItemAt(0).x, 8 + 6 - 0.5, "第一格线在 20px 槽的中线偏左");
        near(beijing.lineItemAt(1).x, 28 + 6 - 0.5, "第二格再往右 20");
        compare(t.rowItem(0, 0).lineUnitCount, 0, "根级没有缩进格");
        t.destroy()
    }

    function test_showLineLeafSwitcher() {
        const t = stdTree(" showLine: true defaultExpandAll: true")
        settle(t)
        const beijing = t.rowItem(idx(t, "0-0-0"), 0)
        const shanghai = t.rowItem(idx(t, "0-0-1"), 0)
        const v = part(beijing, "treeLeafVLine")
        const h = part(beijing, "treeLeafHLine")
        near(v.width, 1);
        near(v.x, 6 - 0.5, "竖线在这 12px 列自己的中线上");
        near(v.height, 28, "北京不是最后一个孩子 ⇒ 通高");
        near(h.width, 8, "(20/2)*0.8");
        near(h.height, 1);
        near(h.y, 14, "水平短线落在行垂直中点");
        near(part(shanghai, "treeLeafVLine").height, 14, "上海是最后一个孩子 ⇒ 只到行中间");
        verify(isEndOf(t, "0-0-1"), "上海那条 isEnd 末位为真");
        t.destroy()
    }

    function isEndOf(t, key) {
        return t.rowField(idx(t, key), "isEnd")[t.rowField(idx(t, key), "isEnd").length - 1] === true;
    }

    function test_noShowLineHasNoLeafSwitcher() {
        const t = stdTree(" defaultExpandAll: true")
        settle(t)
        const leaf = t.rowItem(2, 0)
        verify(testCase.findChild(leaf, "treeLeafVLine") === null, "没开连接线就不画开关线");
        verify(testCase.findChild(t.rowItem(1, 0), "treeLeafVLine") === null);
        t.destroy()
    }

    function test_emptyStateDefaultText() {
        const t = make("Tree { }")
        compare(t.noData, true);
        compare(t.rowCount(), 0);
        const row = part(t, "treeEmptyRow")
        compare(row.visible, true);
        near(row.y, 8, "列表上下那 8px 内边距");
        compare(part(t, "treeEmptyText").text, "暂无数据");
        compare(part(t, "treeEmptyText").color, Theme.current.colorDisabledText);
        t.destroy()
    }

    function test_emptyContentTextReplacesDefault() {
        const t = make("Tree { emptyContent: \"什么都没有\" }")
        compare(part(t, "treeEmptyHook").active, false);
        compare(part(t, "treeEmptyText").text, "什么都没有");
        t.destroy()
    }

    function test_emptyContentComponent() {
        const t = make("Tree { }")
        t.emptyContent = emptyHookComp
        compare(part(t, "treeEmptyHook").active, true);
        verify(testCase.findChild(t, "emptyHook") !== null);
        compare(part(t, "treeEmptyText").visible, false);
        t.destroy()
    }

    function test_dataDisablesEmpty() {
        const t = list("[{key:\"a\",label:\"甲\"}]")
        compare(t.noData, false);
        compare(part(t, "treeEmptyRow").visible, false);
        compare(t.rowCount(), 1);
        t.destroy()
    }

    function test_directoryIcons() {
        const t = stdTree(" directory: true")
        const parent = t.rowItem(0, 0)
        compare(part(parent, "treeIconName").name, "folder");
        t.requestExpand("0")
        settle(t)
        compare(part(t.rowItem(0, 0), "treeIconName").name, "folder_open", "展开换开着的文件夹");
        t.requestExpand("0-0")
        settle(t)
        compare(part(t.rowItem(t.rowKeys().indexOf("0-0-0"), 0), "treeIconName").name, "file",
            "北京是叶子 ⇒ 文件图标");
        near(t.rowItem(0, 0).textX, 8 + 12 + 8 + 16 + 8, "目录图标也占 16+8");
        t.destroy()
    }

    function test_iconPropOverridesDirectoryDefault() {
        const t = stdTree(" directory: true icon: \"star\"")
        compare(part(t.rowItem(0, 0), "treeIconName").name, "star", "treeIcon 压过目录默认");
        t.destroy()
    }

    function test_nodeIconWinsOverTreeIcon() {
        const t = list("[{key:\"a\",label:\"甲\",icon:\"heart\"},{key:\"b\",label:\"乙\"}]",
            " icon: \"star\"")
        compare(part(t.rowItem(0, 0), "treeIconName").name, "heart");
        compare(part(t.rowItem(1, 0), "treeIconName").name, "star");
        t.destroy()
    }

    function test_iconAsFunction() {
        const t = list("[{key:\"a\",label:\"甲\",children:[{key:\"a1\",label:\"子\"}]},{key:\"b\",label:\"乙\"}]",
            " icon: function (props) { return props.hasChildren ? \"plus\" : \"minus\" }")
        compare(part(t.rowItem(0, 0), "treeIconName").name, "plus");
        compare(part(t.rowItem(1, 0), "treeIconName").name, "minus");
        t.destroy()
    }

    function test_noIconLeavesNoColumn() {
        const t = list("[{key:\"a\",label:\"甲\"}]")
        compare(t.rowItem(0, 0).iconShown, false);
        near(t.rowItem(0, 0).textX, 28, "没图标时文字紧跟箭头那格");
        t.destroy()
    }

    function test_expandIconAsString() {
        const t = stdTree(" expandIcon: \"chevron_down\"")
        compare(part(t.rowItem(0, 0), "treeCaretCustom").name, "chevron_down");
        t.destroy()
    }

    function test_expandIconAsFunction() {
        const t = stdTree(" expandIcon: function (props) { return props.expanded ? \"minus\" : \"plus\" }")
        compare(part(t.rowItem(0, 0), "treeCaretCustom").name, "plus");
        t.requestExpand("0")
        settle(t)
        compare(part(t.rowItem(0, 0), "treeCaretCustom").name, "minus");
        t.destroy()
    }

    function test_expandIconClickStillExpands() {
        const t = stdTree(" expandIcon: \"plus\"")
        const row = t.rowItem(0, 0)
        mouseClick(row, row.caretX + 6, 14)
        wait(40)
        settle(t)
        compare(t.expandedKeysList(), ["0"], "自定义图标照样能点");
        t.destroy()
    }

    function test_leafOnlyIgnoresExpandIconColumn() {
        // 叶子那一格是空占位，expandIcon 不参与（renderArrow 只在非叶子分支用它）
        const t = stdTree(" defaultExpandAll: true expandIcon: \"plus\"")
        settle(t)
        const leaf = t.rowItem(t.rowKeys().indexOf("0-0-0"), 0)
        verify(testCase.findChild(leaf, "treeCaretCustom") === null);
        t.destroy()
    }

    function test_labelAsComponentRenders() {
        const t = make("Tree { width: 300; treeData: [{key: 'a', label: null}] }")
        t.treeData = [{ key: "a", label: labelSlotComp }]
        wait(60)
        compare(t.rowField(0, "labelKind"), "slot");
        const row = t.rowItem(0, 0)
        verify(testCase.findChild(row, "labelSlotText") !== null, "组件档 label 要渲染出来");
        compare(part(row, "treeLabelText").visible, false);
        t.destroy()
    }

    function test_labelEllipsisElides() {
        const t = make("Tree { width: 120; labelEllipsis: true; treeData: [{key:\"a\",label:\"很长很长很长很长的一段标签文字\"}] }")
        const text = part(t.rowItem(0, 0), "treeLabelText")
        compare(text.elide, Text.ElideRight);
        compare(text.wrapMode, Text.NoWrap);
        verify(text.width < text.implicitWidth, "省略档宽度受限");
        t.destroy()
    }

    function test_longLabelWrapsByDefault() {
        // word-break: break-word ⇒ 不省略时是换行，行会变高
        const t = make("Tree { width: 120; treeData: [{key:\"a\",label:\"很长很长很长很长的一段标签文字\"}] }")
        const row = t.rowItem(0, 0)
        compare(row.height > 28, true, "换了两行 ⇒ 行高超过 28");
        compare(part(row, "treeLabelText").wrapMode, Text.WrapAtWordBoundaryOrAnywhere);
        t.destroy()
    }

    // ============================================================ 整行自定义
    function test_fullLabelReplacesRowContent() {
        const t = withProps(stdTree(" defaultExpandAll: true"), {renderFullLabel: fullPlainComp})
        const row = t.rowItem(0, 0)
        verify(testCase.findChild(row, "fullHook") !== null);
        compare(part(row, "treeLabelText").visible, false, "默认那套文字不画了");
        compare(part(row, "treeRowBg").visible, false, "整行底色也不画");
        compare(testCase.findChild(row, "treeCaret") === null, false, "箭头列仍在（由钩子决定显不显示）");
        t.destroy()
    }

    function test_fullLabelLevelPadding() {
        const t = withProps(stdTree(" defaultExpandAll: true"), {renderFullLabel: fullPadComp})
        near(part(t.rowItem(0, 0), "treeFullLabelHook").x, 8, "level 0 ⇒ padding-left 8");
        near(part(t.rowItem(1, 0), "treeFullLabelHook").x, 28, "level 1 ⇒ 28");
        near(part(t.rowItem(2, 0), "treeFullLabelHook").x, 48, "level 2 ⇒ 48");
        near(part(t.rowItem(0, 0), "treeFullLabelHook").width, 260 - 8);
        t.destroy()
    }

    function test_fullLabelInjectsPropsAndCallsBack() {
        const t = withProps(stdTree(), {renderFullLabel: fullInjectComp})
        const row = t.rowItem(0, 0)
        const txt = part(row, "injText")
        compare(txt.text, "0:yes:yes", "level、回调与 modelData 都注入到了");
        compare(row.rec === null, false);
        mouseClick(row, 120, 14)
        wait(40)
        compare(t.selectedListView, ["0"], "钩子调 onClick 走的是 handleNodeSelect");
        t.destroy()
    }

    function test_fullLabelSkipsUndeclaredProps() {
        // 钩子没声明的属性不能被硬塞（QML 会报 Cannot assign to non-existent property）
        const t = withProps(stdTree(), {renderFullLabel: fullTinyComp})
        verify(testCase.findChild(t, "tiny") !== null);
        t.destroy()
    }

    function test_fullLabelDragUsesFullLabelClasses() {
        const t = withProps(stdTree(" draggable: true"), {renderFullLabel: fullPadComp})
        compare(t.rowItem(0, 0).dragCapable, false,
            "-draggable 类要 !renderFullLabel ⇒ 钩子档没有那 2px 左边框");
        near(t.rowItem(0, 0).caretX, 8);
        t.destroy()
    }

    function test_fullLabelExpandIconSelfSizes() {
        // 官方把行内那枚 expandIcon 原样递进 renderFullLabel。钩子那边的 Loader 不给宽高，
        // 载入项要是 anchors.fill: parent 就塌成 0×0，箭头整个看不见 ⇒ 递出去的必须自带隐式尺寸
        const t = withProps(list("[{key:\"a\",label:\"甲\",children:[{key:\"a1\",label:\"子\"}]}]"),
            {renderFullLabel: fullCaretComp})
        const box = part(t.rowItem(0, 0), "hookCaret")
        near(box.width, t.caretBox, "递出去的 expandIcon 要撑出 12×12");
        near(box.height, t.caretBox);
        verify(testCase.findChild(box, "treeCaretIcon") !== null, "箭头本体要真的实例化");
        t.destroy()
    }

    function test_fullLabelHidesRowNodeIcon() {
        // renderFullLabel 换掉的是整个 li 的内容（treeNode.tsx 那条分支直接 return），
        // 行内那枚节点图标留着会和钩子自己画的那枚叠成两个
        const t = withProps(list("[{key:\"a\",label:\"甲\",icon:\"star\"}]"),
            {renderFullLabel: fullPlainComp})
        compare(part(t.rowItem(0, 0), "treeIconName").visible, false);
        t.destroy()
    }

    // ============================================================ 搜索框自定义
    function test_searchRenderComponent() {
        const t = stdTree(" filterTreeNode: true")
        t.searchRender = searchHookComp
        compare(part(t, "treeSearchHook").active, true);
        verify(testCase.findChild(t, "searchHookNode") !== null);
        compare(part(t, "treeSearchArea").visible, false, "内置那只 Input 让位");
        t.searchBy("大阪");
        compare(t.rowKeys(), ["0", "0-0", "0-1", "0-1-0", "1"],
            "搜索框被接管，搜索逻辑照旧（祖先的其它孩子照样露出来）");
        t.destroy()
    }

    function test_inputTypingSearches() {
        const t = stdTree(" filterTreeNode: true")
        const input = part(t, "treeSearchInput")
        input.text = "大阪"
        wait(80)
        compare(t.inputValueView, "大阪");
        compare(t.rowKeys(), ["0", "0-0", "0-1", "0-1-0", "1"], "敲输入框等于调 search()");
        t.destroy()
    }

    // ============================================================ 其它端口口径
    function test_expandMethodNames() {
        const t = stdTree()
        // 官方实例方法 search 与信号 onSearch 同名，端口方法叫 searchBy（同 TreeSelect）
        verify(typeof t.searchBy === "function");
        verify(typeof t.scrollTo === "function");
        verify(t.searchBy !== undefined);
        t.destroy()
    }

    function test_expandSignalPayload() {
        const t = stdTree()
        var keys = null
        var info = null
        t.expand.connect((k, i) => { keys = k; info = i })
        t.requestExpand("0")
        compare(keys.sort(), ["0"]);
        compare(info.expanded, true);
        compare(info.node.key, "0", "info.node 是原始数据");
        t.requestExpand("0")
        settle(t)
        compare(info.expanded, false, "再点一次是收起");
        compare(keys, []);
        t.destroy()
    }

    function test_doubleClickNeedsKnownKey() {
        const t = stdTree()
        var hits = 0
        t.doubleClick.connect(() => hits++)
        t.rowDoubleClicked("不存在")
        compare(hits, 0, "不在 keyEntities 里的键不通知");
        t.rowDoubleClicked("0")
        compare(hits, 1);
        t.destroy()
    }

    function test_expandUnknownKeyIgnored() {
        const t = stdTree()
        var hits = 0
        t.expand.connect(() => hits++)
        t.handleNodeExpand("不存在");
        t.handleNodeSelect("不存在");
        compare(hits, 0);
        compare(t.selectedListView, []);
        t.destroy()
    }

    function test_leafExpandEmitsNothing() {
        // handleNodeExpand：没有 loadData 又没孩子 ⇒ 直接 return，连 onExpand 都不发
        const t = stdTree(" defaultExpandAll: true")
        settle(t)
        var hits = 0
        t.expand.connect(() => hits++)
        t.handleNodeExpand("0-0-0")
        compare(hits, 0, "没 loadData 又没孩子 ⇒ 连 onExpand 都不发");
        t.handleNodeExpand("1")
        compare(hits, 1, "有孩子的正常发");
        t.destroy()
    }

    function test_treeDataSwapDropsStaleKeys() {
        const t = stdTree(" multiple: true")
        t.handleNodeSelect("0-0-0")
        compare(t.checkedKeysList(), ["0-0-0"]);
        t.treeData = [{ key: "z", label: "新根" }]
        compare(t.checkedKeysList(), [], "updateKeys 把不在新树里的键清掉");
        t.destroy()
    }

    function test_ariaLabelProp() {
        const t = make("Tree { ariaLabel: \"example tree\" }")
        compare(t.ariaLabel, "example tree");
        t.destroy()
    }

    // ============================================ 变异扫描补的断言（2026-10-22 那轮 33 条存活）

    function test_isLeafFalseBeatsNoChildren() {
        const t = list("[{key:\"a\",label:\"甲\",isLeaf:false},{key:\"b\",label:\"乙\"}]")
        compare(t.rowField(0, "isLeaf"), false, "节点写了 isLeaf:false 就压过「没有孩子」");
        compare(t.rowField(1, "isLeaf"), true, "没写的照旧退成叶子");
        t.destroy()
    }

    function test_mountFillsAncestorsOfControlledExpandedKeys() {
        // 挂载那一次一律补祖先（官方 `autoExpandParent || !mounted`），运行期才看 autoExpandParent
        const t = stdTree(" expandedKeys: [\"0-0-0\"]")
        const at = t.expandedKeysList()
        verify(at.indexOf("0") >= 0, "亚洲该被补进展开集");
        verify(at.indexOf("0-0") >= 0, "中国该被补进展开集");
        t.destroy()
    }

    function test_dataChangeWhileSearchingRecomputesHits() {
        const t = stdTree(" filterTreeNode: true showFilteredOnly: true")
        t.searchBy("大阪")
        verify(t.rowKeys().indexOf("0-1-0") >= 0, "先确认命中的是大阪");
        t.treeData = [{ key: "n1", label: "新加坡", children: [
            { key: "n1-0", label: "大阪" }, { key: "n1-1", label: "芽笼" }] }]
        compare(t.inputValueView, "大阪", "搜索词留着");
        compare(Object.keys(t.filteredMapView), ["n1-0"], "命中集是按新树算的");
        verify(t.rowKeys().indexOf("n1-0") >= 0, "换数据之后按新树重算命中");
        compare(t.rowKeys().indexOf("n1-1"), -1, "没命中的那项不该被顺带放出来");
        t.destroy()
    }

    function test_defaultExpandAllStopsApplyingAfterMount() {
        // 官方：defaultExpandAll 只在初始化生效，运行期换数据要继续展开得用 expandAll
        const t = stdTree(" defaultExpandAll: true")
        verify(t.expandedKeysList().indexOf("0") >= 0, "挂载那一次是全展开的");
        t.treeData = [{ key: "z1", label: "新根", children: [{ key: "z2", label: "新子" }] }]
        compare(t.expandedKeysList().indexOf("z1"), -1, "换数据不会把 defaultExpandAll 再吃一遍");
        t.destroy()
    }

    function test_checkedKeysSurviveDataSwap() {
        const t = stdTree(" multiple: true")
        t.handleNodeSelect("0-0-0")
        compare(t.checkedKeysList(), ["0-0-0"]);
        // 换一份「键还在」的数据：updateKeys 该把旧勾原样搬过来
        t.treeData = [{ key: "0", label: "亚洲", value: "Asia", children: [
            { key: "0-0", label: "中国", value: "China", children: [
                { key: "0-0-0", label: "北京", value: "Beijing" }] }] }]
        compare(t.checkedKeysList().indexOf("0-0-0") >= 0, true, "数据换了、键没变 ⇒ 勾不能掉");
        t.destroy()
    }

    function test_searchExpandWritesOnlyToFilteredTable() {
        // setExpandedStatus 按 isSearching 选写哪张表：搜索态点箭头只动 filteredExpandedKeys
        const t = stdTree(" filterTreeNode: true")
        t.searchBy("大阪")
        compare(t.expandedKeysList(), []);
        t.handleNodeExpand("1")
        verify(Object.keys(t.filteredExpandedMapView).indexOf("1") >= 0,
            "搜索态的展开写 filteredExpandedKeys");
        compare(t.expandedKeysList(), [], "常态那张表不该被搜索态写脏");
        t.destroy()
    }

    function test_requestLoadSkippedForLoadedKey() {
        const t = list("[{key:\"0\",label:\"甲\"}]")
        var calls = 0
        t.loadData = function (node, done) { calls++; done() }
        t.requestExpand("0")
        compare(calls, 1);
        // 直接再要一次：已经 loaded 的键不该再触发（走展开那条路够不到，因为已展开不再发 load）
        t.requestLoad("0")
        compare(calls, 1, "loadedKeys 里有就什么都不做");
        t.destroy()
    }

    function test_dropIntoOwnSubtreeIsIgnored() {
        const t = stdTree(" draggable: true defaultExpandedKeys: [\"0\", \"0-0\"]")
        var drops = 0
        t.drop.connect(() => drops++)
        t.handleNodeDragStart("0")
        t._lastDragKey = "0-0"
        t.handleNodeDrop("0-0")
        compare(drops, 0, "落在自己的子孙上不发 drop");
        compare(t.draggingView, false, "但拖拽状态照样清");
        t.destroy()
    }

    function test_beginMotionNeedsMotionKeys() {
        const t = stdTree()
        compare(t._motionSeq, 0, "起手计数从 0 开始");
        t.beginMotion()
        compare(t._motionSeq, 0, "motionKeys 空就不起手");
        compare(t._motionRunning, false);
        t.destroy()
    }

    function test_motionEndClearsRunningFlag() {
        const t = stdTree(" defaultExpandedKeys: [\"0\"]")
        t.handleNodeExpand("0")
        verify(t._motionRunning, "动画期间是 running");
        settle(t)
        compare(t._motionRunning, false, "收尾把 running 清掉");
        t.destroy()
    }

    function test_motionOnFreshlyCreatedEntrySettles() {
        // 收起状态下展开 ⇒ 子行那组 entry 是新建的：光靠 seq 那一手踢不动就得在 onCompleted 补一手。
        // 先把「动画确实起了」钉住，否则 settle 那条断言是空转（motionMapView 本来就空也算过）
        const t = stdTree()
        t.handleNodeExpand("0")
        verify(Object.keys(t.motionMapView).length > 0, "展开这一手得留下动画区间");
        verify(t._motionRunning, "动画期间是 running");
        settle(t)
        compare(Object.keys(t.motionMapView).length, 0, "新建的组也得把动画跑完");
        t.destroy()
    }

    function test_keylessNodeEntityFallsBackToPos() {
        // traverseDataNodes 里 `nodeKey !== null ? nodeKey : pos`：没写 key 的节点在 entities 里
        // 用 pos 当身份，value → key 的换算才落得下来（行本身照样不渲染，官方同口径）
        const t = list("[{label:\"甲\",value:\"v1\"}]", " defaultValue: \"v1\"")
        compare(t.selectedListView, ["0-0"], "value 换回来的键是 pos 串（含根容器那一层）");
        t.destroy()
    }

    function test_seededCheckedMarksHalfCheckedAncestors() {
        const t = stdTree(" multiple: true defaultValue: [\"Beijing\"]")
        compare(t.checkedKeysList().indexOf("0-0-0") >= 0, true);
        const half = Object.keys(t.halfMapView)
        verify(half.indexOf("0-0") >= 0, "批量那条路也要标半选（不是只有点击才标）");
        verify(half.indexOf("0") >= 0);
        t.destroy()
    }

    function test_controlledCollapseProducesHideMotion() {
        const t = stdTree(" expandedKeys: [\"0\"]")
        t.expandedKeys = []
        compare(t.motionTypeView, "hide", "变少是 hide");
        verify(Object.keys(t.motionMapView).length > 0, "被收掉的键进 motionKeys");
        t.destroy()
    }

    function test_matchedLeafItselfStaysShown() {
        const t = stdTree(" filterTreeNode: true showFilteredOnly: true")
        t.searchBy("北京")
        verify(t.rowKeys().indexOf("0-0-0") >= 0, "命中项自己没有孩子，也得在显示表里");
        t.destroy()
    }

    function test_unRelatedRowCheckedComesFromRealSet() {
        const t = stdTree(" multiple: true checkRelation: \"unRelated\" defaultValue: [\"Beijing\"]")
        compare(t.propsOf("0-0-0").checked, true, "unRelated 档读 realCheckedKeys");
        compare(t.propsOf("0-0").checked, false, "父级不级联");
        t.destroy()
    }

    function test_loadedKeyStopsSpinner() {
        const t = list("[{key:\"0\",label:\"甲\"}]")
        var pendingDone = null
        t.loadData = function (node, done) { pendingDone = done }
        t.requestExpand("0")
        compare(t.propsOf("0").loading, true);
        t.loadedKeys = ["0"]
        compare(t.propsOf("0").loading, false, "loadedKeys 里有就不再转");
        t.destroy()
    }

    function test_hookRendererUsesSlottedGeometry() {
        const t = stdTree()
        t.renderLabel = labelWidthComp
        near(t.rowItem(0, 0).textWidth, 77, "钩子档的文字宽吃槽位宽，不是自然宽/铺满");
        t.destroy()
    }

    function test_loadingSpinnerScaledToCaretBox() {
        const t = list("[{key:\"0\",label:\"甲\"}]")
        t.loadData = function () { }        // 不给 done ⇒ 一直 loading
        t.requestExpand("0")
        near(part(t.rowItem(0, 0), "treeCaretSpin").scale, t.caretBox / 14,
            "本库 Spin 最小档 14，补到 $width-tree_spinIcon = 12");
        t.destroy()
    }

    function test_disabledRowDisablesCheckbox() {
        const t = list("[{key:\"a\",label:\"甲\",disabled:true}]", " multiple: true")
        compare(part(t.rowItem(0, 0), "treeCheck").disabled, true);
        t.destroy()
    }

    function test_highlightReceivesSearchKeyword() {
        const t = stdTree(" filterTreeNode: true")
        t.searchBy("北京")
        const hi = part(t.rowItem(t.rowKeys().indexOf("0-0-0"), 0), "treeLabelHighlight")
        compare(hi.searchWords.length, 1);
        compare(hi.searchWords[0], "北京");
        t.destroy()
    }

    function test_clickOnCheckboxColumnTogglesCheck() {
        const t = stdTree(" multiple: true")
        const row = t.rowItem(0, 0)
        mouseClick(row, row.checkX + 8, row.height / 2)
        wait(40)
        // 复选框那一格走 requestSelect ⇒ 亚洲整棵子树级联勾上；点文字那一格才是选中
        compare(t.checkedKeysList().indexOf("0") >= 0, true);
        compare(t.selectedListView, [], "不该同时算选中");
        t.destroy()
    }
}
