pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Tree 树形控件。官方 `content/navigation/tree/index.md` 的代码演示一共 23 节，
// 加「如何引入」这里 24 个小节，标题逐条对齐（页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/Tree.qml 文件头）：
//   · 身份是 key。旧端口那三条自造面（checkable / nodeChecked / 按 value 记身份的
//     selectedKeys）全撤：多选就是 `multiple`（复选框由它决定），勾选联动是 `checkRelation`，
//     回调是 onChange / onSelect / onExpand。
//   · 官方 demo 里 `style={{ width: 260, height: 420, border: ... }}` 那一圈边框，端口用
//     下面那个 Frame 包一层表达；`className` / `searchStyle` / 拖拽影像两条
//     （hideDraggingNode、renderDraggingNode）与 `preventScroll` 都没有对应物。
//   · `children`（JSX 里写 TreeNode）在官方 render 里根本不读 ⇒ 是死 prop，不做。
//   · 「异步加载数据」官方返回 Promise，端口是 `loadData(node, done)`，延时用 Timer。
//   · `renderFullLabel` 的入参里 React 给的是一个已经接好线的箭头节点，端口给的是一个
//     `Component`（expandIcon），由钩子自己 Loader 出来 —— 见下面那两节的写法。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方 demo 里那行小字说明
    component Note: Text {
        width: 700
        textFormat: Text.PlainText
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    // 官方 demo 那圈 1px 边框
    component Frame: Rectangle {
        border.width: 1
        border.color: Theme.current.colorBorder

        default property alias content: holder.data

        Item {
            id: holder

            anchors.fill: parent
            anchors.margins: 1
        }
    }

    // ---------------------------------------------------------------- 官方 demo 的数据
    // 「基本用法 / 受控 / 自动展开父节点」共用
    readonly property var basicData: [
        { key: "0", label: "亚洲", value: "Asia", children: [
            { key: "0-0", label: "中国", value: "China", children: [
                { key: "0-0-0", label: "北京", value: "Beijing" },
                { key: "0-0-1", label: "上海", value: "Shanghai" }
            ] }
        ] },
        { key: "1", label: "北美洲", value: "North America" }
    ]

    // 「开启搜索的展开受控」那一节的树：日本没有孩子，与其它节不同
    readonly property var japanData: [
        { key: "0", label: "亚洲", value: "Asia", children: [
            { key: "0-0", label: "中国", value: "China", children: [
                { key: "0-0-0", label: "北京", value: "Beijing" },
                { key: "0-0-1", label: "上海", value: "Shanghai" }
            ] },
            { key: "0-1", label: "日本", value: "Japan" }
        ] },
        { key: "1", label: "北美洲", value: "North America" }
    ]

    // 官方这几节共用同一份数据，只有「多选 / 节点选中关系」多一个 Chengdu（0-0-2），
    // 「禁用」那档给 Beijing/Shanghai 挂 disabled。Chengdu 在不在很关键：它是 China 的
    // 非禁用兄弟，有它 calcCheckedKeys 就不会把 China 判成 checked ⇒ disableStrictly
    // 的 disabledKeys 也轮不到 China，那节就演示不出「父级自己没写 disabled 也是灰的」。
    function multiData(withDisabled, withChengdu) {
        const off = withDisabled === true;
        const china = [
            { key: "0-0-0", label: "Beijing", value: "Beijing" },
            { key: "0-0-1", label: "Shanghai", value: "Shanghai" }
        ];
        if (off) {
            china[0].disabled = true;
            china[1].disabled = true;
        }
        if (withChengdu === true)
            china.push({ key: "0-0-2", label: "Chengdu", value: "Chengdu" });
        return [
            { key: "0", label: "Asia", value: "Asia", children: [
                { key: "0-0", label: "China", value: "China", children: china },
                { key: "0-1", label: "Japan", value: "Japan", children: [
                    { key: "0-1-0", label: "Osaka", value: "Osaka" }
                ] }
            ] },
            { key: "1", label: "North America", value: "North America", children: [
                { key: "1-0", label: "United States", value: "United States" },
                { key: "1-1", label: "Canada", value: "Canada" }
            ] }
        ];
    }

    // 「连接线」：label === key，且没有 value
    readonly property var lineData: [
        { key: "parent-0", label: "parent-0", children: [
            { key: "leaf-0-0", label: "leaf-0-0", children: [
                { key: "leaf-0-0-0", label: "leaf-0-0-0" },
                { key: "leaf-0-0-1", label: "leaf-0-0-1" },
                { key: "leaf-0-0-2", label: "leaf-0-0-2" }
            ] },
            { key: "leaf-0-1", label: "leaf-0-1" }
        ] },
        { key: "parent-1", label: "parent-1" }
    ]

    // 「自定义展开 Icon」：只有 key + label
    readonly property var zhData: [
        { key: "yazhou", label: "亚洲", children: [
            { key: "zhongguo", label: "中国", children: [
                { key: "beijing", label: "北京" },
                { key: "shanghai", label: "上海" }
            ] },
            { key: "riben", label: "日本" }
        ] },
        { key: "beimeizhou", label: "北美洲" }
    ]

    readonly property var simpleJson: ({
        Node1: { "Child Node1": "0-0-1", "Child Node2": "0-0-2" },
        Node2: "0-1"
    })
    property var dynJson: simpleJson
    readonly property var dynJson2: ({
        Node3: { "Child Node1": "0-0-1", "Child Node2": "0-0-2",
            "Child Node3": "0-0-3", "Child Node4": "0-0-4" },
        Node2: "0-1"
    })

    // 「高级定制」第三、四节：图标 + 分组结构
    readonly property var fullData: [
        { key: "fix-btn-0", label: "黑色固定按钮", icon: "fixed_stroked" },
        { key: "module-0", label: "模块", icon: "section_stroked", children: [
            { key: "free-compo-0", label: "可自由摆放的组件", icon: "absolute_stroked" },
            { key: "split-col-0", label: "分栏容器", icon: "inner_section_stroked", children: [
                { key: "btn-0", label: "按钮组件", icon: "component_stroked" },
                { key: "btn-1", label: "按钮组件", icon: "component_stroked" }
            ] }
        ] },
        { key: "module-1", label: "模块", icon: "section_stroked", children: [
            { key: "cus-0", label: "自定义组件", icon: "component_stroked" }
        ] }
    ]

    // ---------------------------------------------------------------- 页面状态
    property bool showFilteredOnly: false
    property bool showLineOn: true
    property var controlledValue: "Shanghai"
    property var searchExpandedKeys: []
    property var parentExpandedKeys: ["0", "0-0"]
    property var dynamicData: [{ key: "0", label: "item-0", value: "0" }]
    property var asyncData: [
        { key: "0", label: "Expand to load", value: "0" },
        { key: "1", label: "Expand to load", value: "1" },
        { key: "2", label: "Leaf Node", value: "2", isLeaf: true }
    ]
    property var dragData: multiData(false).concat([
        { key: "2", label: "Europe", value: "Europe" }
    ])
    property var fullDragData: fullData
    property var virtualData: []
    property int virtualTotal: 0
    property string lastChange: "（还没点过）"
    // 「单选父节点同时高亮子孙」：选中项实色，子孙半透明
    property var selectedSet: ({})
    property var throughParentSet: ({})
    // 「手动触发搜索」：外部输入框要能拿到树的实例
    property var manualTree: null
    // 异步加载的待完成回调
    property var pendingDone: null

    // ---------------------------------------------------------------- 官方 demo 的两个工具函数
    function generateData(x, y, z) {
        const gData = [];

        function loop(level, preKey, tns) {
            const parentKey = preKey === undefined || preKey === null ? "0" : preKey;
            const list = tns === undefined || tns === null ? gData : tns;
            const childrenKey = [];
            for (let i = 0; i < x; ++i) {
                const key = `${parentKey}-${i}`;
                list.push({ label: `${key}-标签`, key: `${key}-key`, value: `${key}-value` });
                if (i < y)
                    childrenKey.push(key);
            }
            if (level < 0)
                return list;
            for (let j = 0; j < childrenKey.length; ++j) {
                for (let k = 0; k < list.length; ++k) {
                    if (list[k].key !== childrenKey[j])
                        continue;
                    list[k].children = [];
                    loop(level - 1, childrenKey[j], list[k].children);
                }
            }
            return list;
        }

        loop(z, "0", gData);
        return gData;
    }

    function calcTotal(x, y, z) {
        function rec(n) {
            if (n < 0)
                return 0;
            return x * Math.pow(y, n) + rec(n - 1);
        }
        return rec(z + 1);
    }

    // 「可拖拽」两节的 onDrop：官方 demo 那套递归搬移
    function applyDrop(data, dragKey, dropKey, dropPosition, dropToGap) {
        const out = JSON.parse(JSON.stringify(data));
        let dragObj = null;

        function walk(list, key, cb) {
            for (let i = 0; i < list.length; ++i) {
                if (list[i].key === key) {
                    cb(list[i], i, list);
                    return true;
                }
                if (list[i].children !== undefined && list[i].children !== null
                    && walk(list[i].children, key, cb))
                    return true;
            }
            return false;
        }

        walk(out, dragKey, (item, index, arr) => {
            arr.splice(index, 1);
            dragObj = item;
        });
        if (dragObj === null)
            return out;
        if (!dropToGap) {
            walk(out, dropKey, (item) => {
                item.children = item.children === undefined ? [] : item.children;
                item.children.push(dragObj);
            });
            return out;
        }
        walk(out, dropKey, (item, index, arr) => {
            if (dropPosition === 1 && item.children !== undefined && item.children !== null
                && item.expanded === true) {
                item.children.unshift(dragObj);
                return;
            }
            arr.splice(dropPosition === -1 ? index : index + 1, 0, dragObj);
        });
        return out;
    }

    function findNode(list, key) {
        for (let i = 0; i < list.length; ++i) {
            if (list[i].key === key)
                return list[i];
            if (list[i].children !== undefined && list[i].children !== null) {
                const hit = page.findNode(list[i].children, key);
                if (hit !== null)
                    return hit;
            }
        }
        return null;
    }

    function descendantKeys(node) {
        const res = [node.key];
        const kids = node.children === undefined ? null : node.children;
        if (kids !== null && kids !== undefined) {
            for (let i = 0; i < kids.length; ++i)
                res.push.apply(res, page.descendantKeys(kids[i]));
        }
        return res;
    }

    function pick(node) {
        const self = {};
        self[node] = true;
        return self;
    }

    // ---------------------------------------------------------------- renderFullLabel 那几份钩子
    // 「只有叶子可多选，父节点只做分组」
    readonly property Component leafOnlyRow: Component {
        Item {
            id: leafRow

            property var modelData
            property bool checked
            property bool halfChecked
            property Component expandIcon
            property var onCheck
            property var onExpand

            readonly property bool leaf: modelData === undefined || modelData === null
                || modelData.children === undefined || modelData.children === null

            implicitWidth: 400
            implicitHeight: 28

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: leafRow.leaf ? null : leafRow.expandIcon
                }

                Checkbox {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: leafRow.leaf
                    checked: leafRow.checked
                    indeterminate: leafRow.halfChecked
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: leafRow.modelData === undefined ? "" : String(leafRow.modelData.label)
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            TapHandler {
                onTapped: {
                    if (leafRow.leaf) {
                        if (leafRow.onCheck !== undefined)
                            leafRow.onCheck();
                    } else if (leafRow.onExpand !== undefined) {
                        leafRow.onExpand();
                    }
                }
            }
        }
    }

    // 「只有叶子可单选」：官方那档只有 `{expandIcon}<span>{label}</span>`，
    // 点击叶子走 onClick、点父节点走 onExpand，没有图标也没有底色反馈。
    readonly property Component plainRow: Component {
        Item {
            id: plainRowItem

            property var modelData
            property Component expandIcon
            property var onClick
            property var onExpand

            readonly property bool leaf: modelData === undefined || modelData === null
                || modelData.children === undefined || modelData.children === null

            implicitHeight: 28

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: plainRowItem.expandIcon
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: plainRowItem.modelData === undefined ? ""
                        : String(plainRowItem.modelData.label)
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            TapHandler {
                onTapped: {
                    if (plainRowItem.leaf) {
                        if (plainRowItem.onClick !== undefined)
                            plainRowItem.onClick();
                    } else if (plainRowItem.onExpand !== undefined) {
                        plainRowItem.onExpand();
                    }
                }
            }
        }
    }

    // 「单选父节点同时高亮子孙」与「可拖拽的高级定制」共用一份（官方这两段 renderLabel 一字不差）：
    // 叶子放一个 24px 空 span 顶掉箭头，底色是 --semi-blue-0（选中不透明、经父级选中 0.5）
    readonly property Component coloredRow: Component {
        Item {
            id: colorRow

            property var modelData
            property bool expanded
            property Component expandIcon
            property var onClick

            readonly property bool leaf: modelData === undefined || modelData === null
                || modelData.children === undefined || modelData.children === null
            readonly property string nodeKey: modelData === undefined ? "" : String(modelData.key)
            readonly property string iconName: modelData === undefined || modelData === null
                || modelData.icon === undefined ? "" : String(modelData.icon)

            implicitWidth: 400
            implicitHeight: 28

            Rectangle {
                anchors.fill: parent
                // 官方：selected → rgba(var(--semi-blue-0), 1)，经父级选中 → 同色 0.5
                color: page.selectedSet[colorRow.nodeKey] === true
                    ? Qt.rgba(234 / 255, 245 / 255, 1, 1)
                    : (page.throughParentSet[colorRow.nodeKey] === true
                        ? Qt.rgba(234 / 255, 245 / 255, 1, 0.5) : "transparent")
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !colorRow.leaf
                    sourceComponent: colorRow.expandIcon
                }

                // 官方叶子那档是 <span style={{ width: 24 }} />，把箭头的位置顶掉
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: colorRow.leaf
                    implicitWidth: 24
                    implicitHeight: 16
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: colorRow.iconName !== ""
                    name: colorRow.iconName
                    size: 16
                    color: Theme.current.colorText2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: colorRow.modelData === undefined ? "" : String(colorRow.modelData.label)
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }

            TapHandler {
                onTapped: {
                    if (colorRow.onClick !== undefined)
                        colorRow.onClick();
                }
            }
        }
    }

    // 「自定义节点内容」第二节：renderLabel 接管文字，自己做过长省略
    readonly property Component ellipsisLabel: Component {
        Row {
            id: labelRow

            property var label
            property var modelData

            spacing: 8

            Text {
                width: 300
                text: String(labelRow.label === undefined ? "" : labelRow.label)
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                elide: Text.ElideRight
            }

            IconButton {
                icon: "more"
                size: Enums.Small
                variant: Enums.Borderless
                onClicked: rowToast.info({ content: String(labelRow.label) })
            }
        }
    }

    // 「可搜索的」第二节：searchRender 换掉整只搜索框
    readonly property Component customSearch: Component {
        Input {
            id: searchSlot

            property var value
            property string placeholder
            property var onChange

            // showClear 用 Input 自己的那一条（官方从 searchRenderProps 里传进来，
            // 端口声明同名属性会盖住 Input 的基类属性）
            prefixIcon: "search"
            placeholderText: searchSlot.placeholder === undefined ? "" : searchSlot.placeholder
            showClear: searchSlot.showClear === true
            text: searchSlot.value === undefined ? "" : String(searchSlot.value)
            onTextChanged: {
                if (searchSlot.onChange !== undefined)
                    searchSlot.onChange(text);
            }
        }
    }

    function repeatName(name) {
        return name + name + name + name + name + name + name + name;
    }

    function minusPlusIcon(props) {
        return props.expanded === true ? "minus" : "plus";
    }

    // 「异步加载数据」：官方 1000ms 后追加两个孩子
    function loadChildren(node, done) {
        const list = JSON.parse(JSON.stringify(page.asyncData));
        const target = page.findNode(list, String(node.key));
        if (target === null || target.children !== undefined) {
            done();
            return;
        }
        target.children = [
            { label: "Child Node", key: `${node.key}-0` },
            { label: "Child Node", key: `${node.key}-1` }
        ];
        page.pendingDone = done;
        page.pendingData = list;
        loadTimer.restart();
    }

    property var pendingData: []

    Timer {
        id: loadTimer

        interval: 1000
        repeat: false
        onTriggered: {
            page.asyncData = page.pendingData;
            const done = page.pendingDone;
            page.pendingDone = null;
            if (done !== null)
                done();
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        // ================================================================ 如何引入
        GallerySection {
            title: "如何引入"

            Column {
                width: 760
                spacing: 10

                Text {
                    text: "import { Tree } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("Tree 官方 45 条 prop：treeData / treeDataSimpleJson / keyMaps /"
                        + " value / defaultValue / multiple / checkRelation / leafOnly / autoMergeValue /"
                        + " onChangeWithObject / disabled / disableStrictly / defaultExpandAll / expandAll /"
                        + " defaultExpandedKeys / expandedKeys / autoExpandParent / blockNode / showLine /"
                        + " motion / directory / icon / expandIcon / labelEllipsis / emptyContent / aria-label /"
                        + " filterTreeNode / treeNodeFilterProp / showFilteredOnly / showClear /"
                        + " searchPlaceholder / searchRender / expandAction / loadData / loadedKeys /"
                        + " draggable / autoExpandWhenDragEnter / hideDraggingNode / renderDraggingNode /"
                        + " virtualize / renderLabel / renderFullLabel / expandAction，外加 13 个回调"
                        + "（onChange onSelect onExpand onSearch onDoubleClick onContextMenu onLoad"
                        + " onDragStart onDragEnter onDragOver onDragLeave onDragEnd onDrop）"
                        + "与 search / scrollTo 两个方法。")
                }

                Note {
                    text: qsTr("端口撤掉旧端口的三条自造面：`checkable`（官方多选就画复选框，没有单独开关）、"
                        + "`nodeChecked`、以及按 value 记身份的 `selectedKeys` —— 官方所有状态集合都按"
                        + " **key** 存，value 只在进出 onChange / value 时经 valueEntities 换算。"
                        + "`hideDraggingNode` / `renderDraggingNode` 是 DOM 拖拽影像、`preventScroll`"
                        + " 是浏览器焦点滚动 ⇒ 没有对应物。`children`（JSX 里直接写 TreeNode）"
                        + "在官方 render 里根本不读，是死 prop。")
                }
            }
        }

        // ================================================================ 基本用法
        GallerySection {
            title: "基本用法"

            Frame {
                width: 260
                height: 420

                Tree {
                    anchors.fill: parent
                    treeData: page.basicData
                    defaultExpandAll: true
                }
            }
        }

        // ================================================================ 多选
        GallerySection {
            title: "多选"

            Column {
                width: 400
                spacing: 12

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.multiData(false, true)
                        multiple: true
                        defaultExpandAll: true
                        onChange: (v) => page.lastChange = JSON.stringify(v)
                    }
                }

                Text {
                    text: qsTr("onChange 目前：") + page.lastChange
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        // ================================================================ 可搜索的
        GallerySection {
            title: "可搜索的"

            Column {
                width: 400
                spacing: 16

                Row {
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "showFilteredOnly"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        size: Enums.Small
                        checked: page.showFilteredOnly
                        onToggled: page.showFilteredOnly = !page.showFilteredOnly
                    }
                }

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.multiData(false)
                        multiple: true
                        filterTreeNode: true
                        showFilteredOnly: page.showFilteredOnly
                    }
                }

                GalleryLabel {
                    text: qsTr("searchRender 自定义搜索框")
                }

                Frame {
                    width: 260
                    height: 300

                    Tree {
                        anchors.fill: parent
                        treeData: page.multiData(false)
                        filterTreeNode: true
                        searchRender: page.customSearch
                    }
                }
            }
        }

        // ================================================================ 手动触发搜索
        GallerySection {
            title: "手动触发搜索"

            Column {
                width: 400
                spacing: 12

                Input {
                    width: 300
                    prefixIcon: "search"
                    showClear: true
                    placeholderText: qsTr("请输入")
                    onTextChanged: {
                        if (page.manualTree !== null)
                            page.manualTree.searchBy(text);
                    }
                }

                Text {
                    text: qsTr("搜索结果如下：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Frame {
                    width: 300
                    height: 300

                    Tree {
                        id: manualTreeRef

                        anchors.fill: parent
                        treeData: page.multiData(false)
                        filterTreeNode: true
                        searchRender: false
                        blockNode: false
                        Component.onCompleted: page.manualTree = manualTreeRef
                    }
                }
            }
        }

        // ================================================================ 简单 JSON 格式的数据
        GallerySection {
            title: "简单 JSON 格式的数据"

            Frame {
                width: 260
                height: 420

                Tree {
                    anchors.fill: parent
                    treeDataSimpleJson: page.simpleJson
                    multiple: true
                    onChange: (v) => console.log("当前所有选中项: ", JSON.stringify(v))
                    onSelect: (key) => console.log("当前选项: ", key)
                }
            }
        }

        // ================================================================ 行显示节点
        GallerySection {
            title: "行显示节点"

            Row {
                spacing: 24

                Tree {
                    width: 260
                    treeData: page.multiData(false)
                    defaultValue: "Shanghai"
                    blockNode: false
                }

                Tree {
                    width: 260
                    treeData: page.multiData(false)
                    defaultValue: "Shanghai"
                    multiple: true
                    blockNode: false
                }
            }
        }

        // ================================================================ 自定义节点内容
        GallerySection {
            title: "自定义节点内容"

            Column {
                width: 420
                spacing: 24

                Frame {
                    width: 400
                    height: 200

                    Tree {
                        anchors.fill: parent
                        treeData: [
                            { key: "yazhou", value: "yazhou", label: "亚洲", children: [
                                { key: "zhongguo", value: "zhongguo", label: "中国" },
                                { key: "riben", value: "riben", label: "日本" }
                            ] }
                        ]
                        defaultExpandAll: true
                    }
                }

                Frame {
                    width: 400
                    height: 200

                    Tree {
                        anchors.fill: parent
                        renderLabel: page.ellipsisLabel
                        treeData: [
                            { key: "yazhou", value: "yazhou",
                                label: page.repeatName("亚洲"), children: [
                                { key: "zhongguo", value: "zhongguo", label: page.repeatName("中国") },
                                { key: "riben", value: "riben", label: page.repeatName("日本") }
                            ] }
                        ]
                        defaultExpandAll: true
                    }
                }
            }
        }

        // ================================================================ 自定义图标
        GallerySection {
            title: "自定义图标"

            Frame {
                width: 260
                height: 420

                Tree {
                    anchors.fill: parent
                    defaultExpandAll: true
                    treeData: [
                        { key: "0", label: "Asia", value: "Asia", icon: "map_pin", children: [
                            { key: "0-0", label: "China", value: "China", icon: "map_pin" },
                            { key: "0-1", label: "Japan", value: "Japan", icon: "map_pin" }
                        ] }
                    ]
                }
            }
        }

        // ================================================================ 目录树模式
        GallerySection {
            title: "目录树模式"

            Frame {
                width: 260
                height: 420

                Tree {
                    anchors.fill: parent
                    directory: true
                    defaultExpandAll: true
                    treeData: page.multiData(false)
                }
            }
        }

        // ================================================================ 禁用
        GallerySection {
            title: "禁用"

            Column {
                width: 400
                spacing: 12

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.multiData(true)
                        defaultValue: "Shanghai"
                        multiple: true
                        defaultExpandAll: true
                        disableStrictly: true
                    }
                }

                Note {
                    text: qsTr("官方口径：`disableStrictly` 的 disabledKeys 走 calcCheckedKeys 的补集，"
                        + "「兄弟全禁用」的父级也会被判成禁用 —— 所以这一节里 China 自己没写 disabled"
                        + " 也是灰的，点 Asia 也不会把它勾上。这是上游算法，端口照抄。")
                }
            }
        }

        // ================================================================ 节点选中关系
        GallerySection {
            title: "节点选中关系"

            Frame {
                width: 260
                height: 420

                Tree {
                    anchors.fill: parent
                    treeData: page.multiData(false, true)
                    multiple: true
                    checkRelation: "unRelated"
                    defaultExpandAll: true
                }
            }
        }

        // ================================================================ 默认展开
        GallerySection {
            title: "默认展开"

            Column {
                width: 620
                spacing: 12

                Button {
                    text: qsTr("点击更新 TreeData")
                    onClicked: page.dynJson = page.dynJson2
                }

                Row {
                    spacing: 24

                    Column {
                        spacing: 6

                        GalleryLabel { text: "defaultExpandAll" }

                        Frame {
                            width: 260
                            height: 420

                            Tree {
                                anchors.fill: parent
                                defaultExpandAll: true
                                treeDataSimpleJson: page.dynJson
                            }
                        }
                    }

                    Column {
                        spacing: 6

                        GalleryLabel { text: "expandAll" }

                        Frame {
                            width: 260
                            height: 420

                            Tree {
                                anchors.fill: parent
                                expandAll: true
                                treeDataSimpleJson: page.dynJson
                            }
                        }
                    }
                }
            }
        }

        // ================================================================ 开启搜索的展开受控
        GallerySection {
            title: "开启搜索的展开受控"

            Column {
                width: 400
                spacing: 12

                Frame {
                    width: 300
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.japanData
                        filterTreeNode: true
                        expandedKeys: page.searchExpandedKeys
                        onExpand: (keys) => page.searchExpandedKeys = keys
                        onSearch: (input, keys) => page.searchExpandedKeys = keys
                    }
                }

                Text {
                    text: qsTr("expandedKeys：%1").arg(JSON.stringify(page.searchExpandedKeys))
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        // ================================================================ 受控
        GallerySection {
            title: "受控"

            Frame {
                width: 260
                height: 420

                Tree {
                    anchors.fill: parent
                    treeData: page.basicData
                    value: page.controlledValue
                    onChange: (v) => page.controlledValue = v
                }
            }
        }

        // ================================================================ 自动展开父节点
        GallerySection {
            title: "自动展开父节点"

            Column {
                width: 400
                spacing: 12

                Text {
                    text: qsTr("需要先将“中国”节点收起后，才能够收起“亚洲”节点")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.basicData
                        autoExpandParent: true
                        expandedKeys: page.parentExpandedKeys
                        onExpand: (keys) => page.parentExpandedKeys = keys
                    }
                }
            }
        }

        // ================================================================ 自定义展开 Icon
        GallerySection {
            title: "自定义展开 Icon"

            Column {
                width: 400
                spacing: 20

                GalleryLabel { text: qsTr("expandIcon 是 ReactNode") }

                Frame {
                    width: 260
                    height: 200

                    Tree {
                        anchors.fill: parent
                        multiple: true
                        expandIcon: "chevron_down"
                        defaultExpandedKeys: ["yazhou"]
                        treeData: page.zhData
                    }
                }

                GalleryLabel { text: qsTr("expandIcon 是函数") }

                Frame {
                    width: 260
                    height: 200

                    Tree {
                        anchors.fill: parent
                        multiple: true
                        expandIcon: page.minusPlusIcon
                        defaultExpandedKeys: ["yazhou"]
                        treeData: page.zhData
                    }
                }
            }
        }

        // ================================================================ 连接线
        GallerySection {
            title: "连接线"

            Column {
                width: 400
                spacing: 12

                Row {
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "showLine"
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: Font.Bold
                    }

                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: page.showLineOn
                        onToggled: page.showLineOn = !page.showLineOn
                    }
                }

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        showLine: page.showLineOn
                        defaultExpandAll: true
                        treeData: page.lineData
                    }
                }
            }
        }

        // ================================================================ 虚拟化
        GallerySection {
            title: "虚拟化"

            Column {
                width: 400
                spacing: 12

                Row {
                    spacing: 8

                    Button {
                        text: qsTr("生成数据: ")
                        onClicked: {
                            page.virtualData = page.generateData(5, 4, 3);
                            page.virtualTotal = page.calcTotal(5, 4, 3);
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("共 %1 个节点").arg(page.virtualTotal)
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                Frame {
                    visible: page.virtualData.length > 0
                    width: 260
                    height: 300

                    Tree {
                        anchors.fill: parent
                        treeData: page.virtualData
                        filterTreeNode: true
                        showFilteredOnly: true
                        virtualize: ({ height: 300, itemSize: 28 })
                    }
                }
            }
        }

        // ================================================================ 动态更新数据
        GallerySection {
            title: "动态更新数据"

            Column {
                width: 300
                spacing: 12

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.dynamicData
                    }
                }

                Button {
                    text: qsTr("动态改变数据")
                    onClicked: page.dynamicData = page.randomDynamic()
                }
            }
        }

        // ================================================================ 异步加载数据
        GallerySection {
            title: "异步加载数据"

            Frame {
                width: 260
                height: 420

                Tree {
                    anchors.fill: parent
                    treeData: page.asyncData
                    loadData: (node, done) => page.loadChildren(node, done)
                }
            }
        }

        // ================================================================ 可拖拽的Tree
        GallerySection {
            title: "可拖拽的Tree"

            Column {
                width: 400
                spacing: 12

                Note {
                    text: qsTr("拖拽于 v1.8.0 之后提供，目前不支持与虚拟化同时使用。端口用一只 DragHandler"
                        + " 表达 HTML5 的 dragstart / enter / over / leave / drop / end：落点判定照抄"
                        + " DRAG_OFFSET = 0.45，悬停 400ms 自动展开也照抄。")
                }

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.dragData
                        draggable: true
                        defaultExpandAll: true
                        onDrop: (node, dragNode, keys, dropPosition, dropToGap) => {
                            page.dragData = page.applyDrop(page.dragData, String(dragNode.key),
                                String(node.key), dropPosition, dropToGap);
                        }
                    }
                }
            }
        }

        // ================================================================ 高级定制
        GallerySection {
            title: "高级定制"

            Column {
                width: 420
                spacing: 24

                Note {
                    text: qsTr("官方提醒：开启虚拟化时要把自己那行的高度/偏移 style 交给 DOM。"
                        + " 端口的 renderFullLabel 就是行本体，位置由列表排，不需要这一步。")
                }

                GalleryLabel { text: qsTr("只有叶子可多选，父节点只做分组") }

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.multiData(false)
                        renderFullLabel: page.leafOnlyRow
                        multiple: true
                        leafOnly: true
                    }
                }

                GalleryLabel { text: qsTr("只有叶子可单选") }

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.multiData(false)
                        renderFullLabel: page.plainRow
                        onChange: (v) => page.lastChange = JSON.stringify(v)
                    }
                }

                GalleryLabel { text: qsTr("单选父节点同时高亮子孙") }

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.fullData
                        renderFullLabel: page.coloredRow
                        defaultExpandAll: true
                        onSelect: (key, selected, node) => page.highlightSubtree(key, node)
                    }
                }
            }
        }

        // ================================================================ 可拖拽的高级定制
        GallerySection {
            title: "可拖拽的高级定制"

            Column {
                width: 420
                spacing: 12

                Note {
                    text: qsTr("1.27.0 起 draggable 与 renderFullLabel 可以同时用。此时官方那 2px 的"
                        + " `-draggable` 左边框类名门槛是 `!renderFullLabel` ⇒ 自定义整行不再有那 2px 右移，"
                        + "标示线改由 `-fullLabel-drag-over-gap-*` 那两条画。")
                }

                Frame {
                    width: 260
                    height: 420

                    Tree {
                        anchors.fill: parent
                        treeData: page.fullDragData
                        renderFullLabel: page.coloredRow
                        draggable: true
                        defaultExpandAll: true
                        onSelect: (key, selected, node) => page.highlightSubtree(key, node)
                        onDrop: (node, dragNode, keys, dropPosition, dropToGap) => {
                            page.fullDragData = page.applyDrop(page.fullDragData,
                                String(dragNode.key), String(node.key), dropPosition, dropToGap);
                        }
                    }
                }
            }
        }

        Toast {
            id: rowToast
        }
    }

    function highlightSubtree(key, node) {
        page.selectedSet = page.pick(key);
        const through = {};
        const list = page.descendantKeys(node);
        for (let i = 0; i < list.length; ++i)
            through[String(list[i])] = true;
        page.throughParentSet = through;
    }

    function randomDynamic() {
        const out = [];
        const itemLength = Math.floor(Math.random() * 5) + 1;
        for (let i = 0; i < itemLength; ++i) {
            const length = Math.floor(Math.random() * 3);
            const children = [];
            for (let c = 0; c < length; ++c) {
                children.push({ key: `${i}-${c}`, label: `Leaf-${i}-${c}`, value: `${i}-${c}` });
            }
            out.push({ key: `${i}`, label: `Item-${i}`, value: `${i}`, children: children });
        }
        return out;
    }
}
