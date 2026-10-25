pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 官方示例：content/input/treeselect/index.md（19 个小节，标题与 docs.json 一致）
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ---------------------------------------------------------------- demo 数据
    // 基本用法 / 尺寸 / 禁用 / 受控 / 自定义渲染 都用这棵（官方原样）
    readonly property var asiaTree: [
        {
            label: "亚洲", value: "Asia", key: "0",
            children: [
                {
                    label: "中国", value: "China", key: "0-0",
                    children: [
                        { label: "北京", value: "Beijing", key: "0-0-0" },
                        { label: "上海", value: "Shanghai", key: "0-0-1" }
                    ]
                }
            ]
        },
        { label: "北美洲", value: "North America", key: "1" }
    ]

    // 多选 / 限制标签数 / 可搜索 / 搜索框位置 用的那棵（官方原样）
    readonly property var worldTree: [
        {
            label: "Asia", value: "Asia", key: "0",
            children: [
                {
                    label: "China", value: "China", key: "0-0",
                    children: [
                        { label: "Beijing", value: "Beijing", key: "0-0-0" },
                        { label: "Shanghai", value: "Shanghai", key: "0-0-1" },
                        { label: "Chengdu", value: "Chengdu", key: "0-0-2" }
                    ]
                },
                {
                    label: "Japan", value: "Japan", key: "0-1",
                    children: [{ label: "Osaka", value: "Osaka", key: "0-1-0" }]
                }
            ]
        },
        {
            label: "North America", value: "North America", key: "1",
            children: [
                { label: "United States", value: "United States", key: "1-0" },
                { label: "Canada", value: "Canada", key: "1-1" }
            ]
        }
    ]

    // triggerTagWrap 那棵：中国下面多两个城市
    readonly property var wrapTree: [
        {
            label: "Asia", value: "Asia", key: "0",
            children: [
                {
                    label: "China", value: "China", key: "0-0",
                    children: [
                        { label: "Beijing", value: "Beijing", key: "0-0-0" },
                        { label: "Shanghai", value: "Shanghai", key: "0-0-1" },
                        { label: "Shenzhen", value: "Shenzhen", key: "0-0-2" },
                        { label: "Guangzhou", value: "Guangzhou", key: "0-0-3" }
                    ]
                },
                {
                    label: "Japan", value: "Japan", key: "0-1",
                    children: [{ label: "Osaka", value: "Osaka", key: "0-1-0" }]
                }
            ]
        },
        {
            label: "North America", value: "North America", key: "1",
            children: [
                { label: "United States", value: "United States", key: "1-0" },
                { label: "Canada", value: "Canada", key: "1-1" }
            ]
        }
    ]

    // 展开受控那棵：亚洲下面多一个日本
    readonly property var expandTree: [
        {
            label: "亚洲", value: "Asia", key: "0",
            children: [
                {
                    label: "中国", value: "China", key: "0-0",
                    children: [
                        { label: "北京", value: "Beijing", key: "0-0-0" },
                        { label: "上海", value: "Shanghai", key: "0-0-1" }
                    ]
                },
                { label: "日本", value: "Japan", key: "0-1" }
            ]
        },
        { label: "北美洲", value: "North America", key: "1" }
    ]

    // 严格禁用那棵
    readonly property var strictTree: [
        {
            label: "亚洲", value: "Asia", key: "0",
            children: [
                {
                    label: "中国", value: "China", key: "0-0", disabled: true,
                    children: [
                        { label: "北京", value: "Beijing", key: "0-0-0" },
                        { label: "上海", value: "Shanghai", key: "0-0-1" }
                    ]
                },
                { label: "日本", value: "Japan", key: "0-1" }
            ]
        },
        { label: "北美洲", value: "North America", key: "1" }
    ]

    // 自定义渲染已选项那棵：官方在北美洲后面还排了南美洲、南极洲
    readonly property var renderTree: page.asiaTree.concat([
        { label: "南美洲", value: "South America", key: "2" },
        { label: "南极洲", value: "Antarctica", key: "3" }
    ])

    // 异步加载的初始数据：前两个节点靠 loadData 现补 children，第三个声明 isLeaf
    readonly property var asyncSeed: [
        { label: "Expand to load", value: "0", key: "0" },
        { label: "Expand to load", value: "1", key: "1" },
        { label: "Leaf Node", value: "2", key: "2", isLeaf: true }
    ]

    // ---------------------------------------------------------------- 各小节的动态状态
    property var deferredTree: []          // 默认展开：500ms 后才到位的数据
    property var remoteTree: []            // 远程搜索：每次搜到的结果
    property var dynamicTree: []           // 动态更新数据
    property var asyncTree: []             // 异步加载：整棵会被替换
    property string remoteKeyword: ""
    property var remoteValue: undefined
    property string controlledValue: "Shanghai"
    property var expandControlKeys: []
    property bool showFilteredOnly: false

    // 远程搜索 / 默认展开这类「延时到账」的数据，官方用 setTimeout，QML 用一次性 Timer。
    // 同一时刻只可能有一个在跑，所以每个都配一个 id 各自管自己。
    property string pendingLoadKey: ""

    function fillDeferred() {
        page.deferredTree = page.asiaTree;
    }

    // 官方 generateData(5, 4, 3)：5 个根、每个根下 4 个有子节点、共 4 层，合计 1705 个节点
    function generateData(x, y, z) {
        const data = [];
        function _loop(level, preKey, tns) {
            const localTns = tns === undefined ? data : tns;
            const childrenKeys = [];
            for (let i = 0; i < x; ++i) {
                const key = preKey + "-" + i;
                localTns.push({ label: key + "-标签", key: key + "-key", value: key + "-value" });
                if (i < y)
                    childrenKeys.push(key);
            }
            if (level < 0)
                return;
            for (let i = 0; i < childrenKeys.length; ++i) {
                localTns[i].children = [];
                _loop(level - 1, childrenKeys[i], localTns[i].children);
            }
        }
        _loop(z, "0", undefined);
        return data;
    }

    property var virtualTree: []
    property int virtualTotal: 0

    function makeDynamic() {
        const itemLength = Math.floor(Math.random() * 5) + 1;
        const next = [];
        for (let i = 0; i < itemLength; ++i) {
            const length = Math.floor(Math.random() * 3);
            const children = [];
            for (let ci = 0; ci < length; ++ci)
                children.push({ key: i + "-" + ci, label: "Leaf-" + i + "-" + ci, value: i + "-" + ci });
            next.push({ key: String(i), label: "Item-" + i, value: String(i), children: children });
        }
        page.dynamicTree = next;
    }

    // 官方 updateTreeData：把 children 挂到指定 key 的节点上
    function attachChildren(list, key, children) {
        const out = [];
        for (let i = 0; i < list.length; ++i) {
            const node = list[i];
            if (node.key === key) {
                const merged = {};
                for (const k in node)
                    merged[k] = node[k];
                merged.children = children;
                out.push(merged);
                continue;
            }
            if (node.children !== undefined && node.children !== null) {
                const merged = {};
                for (const k in node)
                    merged[k] = node[k];
                merged.children = page.attachChildren(node.children, key, children);
                out.push(merged);
                continue;
            }
            out.push(node);
        }
        return out;
    }

    function asyncLoad(node, done) {
        if (node === undefined || node === null)
            return;
        if (node.children !== undefined && node.children !== null) {
            done();
            return;
        }
        page.pendingLoadKey = node.key;
        page.pendingDone = done;
        loadTimer.restart();
    }

    property var pendingDone: null

    Timer {
        id: loadTimer

        interval: 1000
        onTriggered: {
            const key = page.pendingLoadKey;
            const done = page.pendingDone;
            page.pendingLoadKey = "";
            page.pendingDone = null;
            page.asyncTree = page.attachChildren(page.asyncTree, key, [
                { label: "Child Node", key: key + "-0" },
                { label: "Child Node", key: key + "-1" }
            ]);
            if (done !== null)
                done();
        }
    }

    Component.onCompleted: {
        page.asyncTree = page.asyncSeed;
        deferredTimer.start();
    }

    Timer {
        id: deferredTimer

        interval: 500
        onTriggered: page.fillDeferred()
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        // ------------------------------------------------------------ 1 基本用法
        GallerySection {
            title: "基本用法"

            TreeSelect {
                width: 300
                treeData: page.asiaTree
                placeholder: qsTr("请选择")
            }
        }

        // ------------------------------------------------------------ 2 多选
        GallerySection {
            title: "多选"

            Column {
                spacing: 20

                TreeSelect {
                    width: 300
                    multiple: true
                    treeData: page.worldTree
                    placeholder: qsTr("请选择")
                }

                TreeSelect {
                    width: 300
                    multiple: true
                    leafOnly: true
                    treeData: page.worldTree
                    placeholder: qsTr("只渲染叶子节点")
                }
            }
        }

        // ------------------------------------------------------------ 3 限制标签展示数量
        GallerySection {
            title: "限制标签展示数量"

            Column {
                spacing: 20

                Text {
                    text: "maxTagCount=2:"
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.Medium
                }

                TreeSelect {
                    width: 300
                    multiple: true
                    maxTagCount: 2
                    treeData: page.worldTree
                    placeholder: qsTr("当选中标签超过两个将折叠")
                    defaultValue: ["Beijing", "Chengdu", "Canada"]
                }

                Text {
                    text: "maxTagCount=2, showRestTagsPopover:"
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.Medium
                }

                TreeSelect {
                    width: 300
                    multiple: true
                    maxTagCount: 2
                    showRestTagsPopover: true
                    treeData: page.worldTree
                    placeholder: qsTr("hover +N 查看")
                    defaultValue: ["Beijing", "Chengdu", "Canada"]
                }
            }
        }

        // ------------------------------------------------------------ 4 可搜索的
        GallerySection {
            title: "可搜索的"

            Column {
                spacing: 20

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
                        onToggled: page.showFilteredOnly = checked
                    }
                }

                TreeSelect {
                    width: 300
                    treeData: page.worldTree
                    filterTreeNode: true
                    showFilteredOnly: page.showFilteredOnly
                    placeholder: qsTr("单选可搜索的")
                }

                TreeSelect {
                    width: 300
                    multiple: true
                    filterTreeNode: true
                    maxTagCount: 2
                    showFilteredOnly: page.showFilteredOnly
                    treeData: page.worldTree
                    placeholder: qsTr("多选可搜索的")
                    searchPlaceholder: qsTr("请输入关键字开始搜索")
                }

                TreeSelect {
                    width: 300
                    multiple: true
                    filterTreeNode: true
                    maxTagCount: 2
                    showFilteredOnly: page.showFilteredOnly
                    searchAutoFocus: true
                    treeData: page.worldTree
                    placeholder: qsTr("搜索框autofocus")
                    searchPlaceholder: "autofocus"
                }
            }
        }

        // ------------------------------------------------------------ 5 远程搜索
        GallerySection {
            title: "远程搜索"

            TreeSelect {
                id: remoteTree

                width: 300
                placeholder: qsTr("请输入关键字进行远程搜索")
                treeData: page.remoteTree
                filterTreeNode: true
                remote: true
                value: page.remoteValue
                onChange: (value) => page.remoteValue = value
                onSearch: (input) => {
                    page.remoteKeyword = input;
                    if (input === "") {
                        page.remoteTree = [];
                        return;
                    }
                    remoteTimer.restart();
                }
            }
        }

        // ------------------------------------------------------------ 6 搜索框位置
        GallerySection {
            title: "搜索框位置"

            Column {
                spacing: 20

                TreeSelect {
                    width: 300
                    searchPosition: "trigger"
                    treeData: page.worldTree
                    filterTreeNode: true
                    placeholder: qsTr("单选")
                }

                TreeSelect {
                    width: 300
                    searchPosition: "trigger"
                    multiple: true
                    maxTagCount: 2
                    treeData: page.worldTree
                    filterTreeNode: true
                    placeholder: qsTr("多选")
                }
            }
        }

        // ------------------------------------------------------------ 7 triggerTagWrap
        GallerySection {
            title: "Trigger 内多行换行（triggerTagWrap）"

            TreeSelect {
                width: 260
                searchPosition: "trigger"
                triggerTagWrap: true
                multiple: true
                filterTreeNode: true
                treeData: page.wrapTree
                placeholder: qsTr("请选择多个选项或输入长文本")
                defaultValue: ["Beijing", "Shanghai", "Shenzhen", "Guangzhou"]
            }
        }

        // ------------------------------------------------------------ 8 尺寸大小
        GallerySection {
            title: "尺寸大小"

            Column {
                spacing: 20

                TreeSelect {
                    width: 300
                    multiple: true
                    size: Enums.Small
                    treeData: page.asiaTree
                    placeholder: "small"
                }

                TreeSelect {
                    width: 300
                    multiple: true
                    size: Enums.Default
                    treeData: page.asiaTree
                    placeholder: "default"
                }

                TreeSelect {
                    width: 300
                    multiple: true
                    size: Enums.Large
                    treeData: page.asiaTree
                    placeholder: "large"
                }
            }
        }

        // ------------------------------------------------------------ 9 默认展开
        GallerySection {
            title: "默认展开"

            Column {
                spacing: 20

                TreeSelect {
                    width: 300
                    expandAll: true
                    treeData: page.deferredTree
                    placeholder: "expandAll"
                }

                TreeSelect {
                    width: 300
                    defaultExpandAll: true
                    treeData: page.deferredTree
                    placeholder: "defaultExpandAll"
                }
            }
        }

        // ------------------------------------------------------------ 10 禁用
        GallerySection {
            title: "禁用"

            Column {
                spacing: 20

                TreeSelect {
                    width: 300
                    treeData: page.asiaTree
                    disabled: true
                    placeholder: qsTr("禁用下拉菜单")
                }

                TreeSelect {
                    width: 300
                    defaultValue: "Shanghai"
                    treeData: page.asiaTree
                    disabled: true
                }

                TreeSelect {
                    width: 300
                    defaultValue: ["Shanghai", "North America"]
                    treeData: page.asiaTree
                    multiple: true
                    disabled: true
                }
            }
        }

        // ------------------------------------------------------------ 11 严格禁用
        GallerySection {
            title: "严格禁用"

            TreeSelect {
                width: 300
                disableStrictly: true
                multiple: true
                defaultValue: ["Shanghai"]
                treeData: page.strictTree
            }
        }

        // ------------------------------------------------------------ 12 受控
        GallerySection {
            title: "受控"

            Column {
                spacing: 20

                TreeSelect {
                    width: 300
                    treeData: page.asiaTree
                    value: page.controlledValue
                    placeholder: qsTr("请选择")
                    onChange: (value) => page.controlledValue = value
                }

                Text {
                    text: qsTr("当前 value：%1").arg(page.controlledValue === undefined
                        ? "（空）" : String(page.controlledValue))
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Space {
                    space: 8

                    Button {
                        text: qsTr("设为上海")
                        variant: Enums.Light
                        onClicked: page.controlledValue = "Shanghai"
                    }

                    Button {
                        text: qsTr("设为北美洲")
                        variant: Enums.Light
                        onClicked: page.controlledValue = "North America"
                    }

                    Button {
                        text: qsTr("清空")
                        variant: Enums.Light
                        onClicked: page.controlledValue = undefined
                    }
                }
            }
        }

        // ------------------------------------------------------------ 13 节点选中关系
        GallerySection {
            title: "节点选中关系"

            TreeSelect {
                width: 300
                multiple: true
                defaultValue: "Asia"
                checkRelation: "unRelated"
                treeData: page.asiaTree
            }
        }

        // ------------------------------------------------------------ 14 开启搜索的展开受控
        GallerySection {
            title: "开启搜索的展开受控"

            TreeSelect {
                width: 300
                treeData: page.expandTree
                filterTreeNode: true
                expandedKeys: page.expandControlKeys
                onExpand: (keys) => page.expandControlKeys = keys
                onSearch: (input, filteredExpandedKeys) => {
                    page.expandControlKeys = filteredExpandedKeys.concat(page.expandControlKeys);
                }
            }
        }

        // ------------------------------------------------------------ 15 虚拟化
        GallerySection {
            title: "虚拟化"

            Column {
                spacing: 20

                Row {
                    spacing: 8

                    Button {
                        text: qsTr("生成数据: ")
                        onClicked: {
                            page.virtualTree = page.generateData(5, 4, 3);
                            page.virtualTotal = 1705;
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("共 %1 个节点").arg(page.virtualTotal)
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                TreeSelect {
                    visible: page.virtualTree.length > 0
                    width: 300
                    treeData: page.virtualTree
                    filterTreeNode: true
                    showFilteredOnly: true
                    placeholder: "Please select"
                    virtualize: ({ itemSize: 28, height: 236 })
                }
            }
        }

        // ------------------------------------------------------------ 16 动态更新数据
        GallerySection {
            title: "动态更新数据"

            Column {
                spacing: 20

                TreeSelect {
                    width: 300
                    treeData: page.dynamicTree
                    placeholder: qsTr("请选择")
                }

                Button {
                    text: qsTr("动态改变数据")
                    onClicked: page.makeDynamic()
                }
            }
        }

        // ------------------------------------------------------------ 17 异步加载数据
        GallerySection {
            title: "异步加载数据"

            TreeSelect {
                width: 300
                loadData: page.asyncLoad
                treeData: page.asyncTree
                placeholder: qsTr("请选择")
            }
        }

        // ------------------------------------------------------------ 18 自定义 Trigger
        GallerySection {
            title: "自定义 Trigger"

            TreeSelect {
                width: 300
                triggerRender: customTriggerComponent
                filterTreeNode: true
                searchPosition: "trigger"
                multiple: true
                treeData: page.asiaTree
                placeholder: "Custom Trigger"
            }
        }

        // ------------------------------------------------------------ 19 自定义渲染已选项
        GallerySection {
            title: "自定义渲染已选项"

            Column {
                spacing: 20

                Text {
                    text: qsTr("单选")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.Medium
                }

                TreeSelect {
                    width: 300
                    treeData: page.renderTree
                    renderSelectedItem: plainLabelComponent
                }

                Text {
                    text: qsTr("多选 + 自己画 Tag")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.Medium
                }

                TreeSelect {
                    width: 300
                    multiple: true
                    treeData: page.renderTree
                    renderSelectedItem: whiteTagComponent
                }

                Text {
                    text: qsTr("多选 + maxTagCount=2，标签里显示 value")
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.Medium
                }

                TreeSelect {
                    width: 300
                    multiple: true
                    maxTagCount: 2
                    treeData: page.renderTree
                    renderSelectedItem: tagShowsValueComponent
                }
            }
        }
    }

    // 远程搜索的「网络延迟」
    Timer {
        id: remoteTimer

        interval: 500
        onTriggered: {
            const kw = page.remoteKeyword;
            page.remoteTree = [
                { label: kw + " - 结果1", value: kw + "-1", key: kw + "-1" },
                { label: kw + " - 结果2", value: kw + "-2", key: kw + "-2" },
                { label: kw + " - 结果3", value: kw + "-3", key: kw + "-3" }
            ];
        }
    }

    // ------------------------------------------------------------ 钩子组件
    // 官方 triggerRender(props)：这里交 Component，根项声明 value / inputValue /
    // placeholder / disabled 四个普通属性 + search / clear / remove 三个函数，
    // 由 TreeSelect 注入。官方 demo 用 TagInput 接管触发器。
    Component {
        id: customTriggerComponent

        Item {
            id: triggerRoot

            property var value: []
            property string inputValue: ""
            property string placeholder: ""
            property bool disabled: false
            property var search: null
            property var clear: null
            property var remove: null

            function labelOfKey(key) {
                for (let i = 0; i < value.length; ++i) {
                    if (String(value[i].key) === key)
                        return String(value[i].label);
                }
                return key;
            }

            implicitWidth: 300
            implicitHeight: 32

            TagInput {
                id: customTagInput

                width: 300
                value: triggerRoot.value.map(item => item.key)
                inputValue: triggerRoot.inputValue
                placeholder: triggerRoot.placeholder
                enabled: !triggerRoot.disabled
                renderTagItem: customTriggerTagComponent
                onInputChange: (text) => {
                    if (triggerRoot.search !== null)
                        triggerRoot.search(text);
                }
                onRemove: (tag) => {
                    if (triggerRoot.remove !== null)
                        triggerRoot.remove(tag);
                }
            }

            // 声明在这里（而不是页面级），才能拿到 triggerRoot 的上下文
            Component {
                id: customTriggerTagComponent

                Tag {
                    id: innerTag

                    property var modelData: undefined
                    property int index: -1
                    property var closeTag: null

                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    text: triggerRoot.labelOfKey(String(innerTag.modelData))
                    closable: true
                    onClosed: {
                        if (innerTag.closeTag !== null)
                            innerTag.closeTag();
                    }
                }
            }
        }
    }

    // renderSelectedItem：单选 —— 官方 renderSelectedItem(treeNode) => content
    Component {
        id: plainLabelComponent

        Text {
            id: singleItem

            property var modelData: ({})
            property int index: -1
            property var remove: null

            width: 260
            text: String(singleItem.modelData.label === undefined
                ? "" : singleItem.modelData.label)
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
            elide: Text.ElideRight
        }
    }

    // renderSelectedItem：多选 —— 官方 isRenderInTag=true 时由框架套 Tag，
    // false 时直接渲染 content。QML 侧只有一条路：钩子自己决定画不画 Tag。
    Component {
        id: whiteTagComponent

        Tag {
            id: multiTag

            property var modelData: ({})
            property int index: -1
            property var remove: null

            text: String(multiTag.modelData.label === undefined
                ? "" : multiTag.modelData.label)
            color: "white"
            size: "large"
            closable: true
            onClosed: {
                if (multiTag.remove !== null)
                    multiTag.remove();
            }
        }
    }

    Component {
        id: tagShowsValueComponent

        Tag {
            id: valueTag

            property var modelData: ({})
            property int index: -1
            property var remove: null

            text: String(valueTag.modelData.value === undefined
                ? "" : valueTag.modelData.value)
            color: "white"
            size: "large"
            closable: true
            onClosed: {
                if (valueTag.remove !== null)
                    valueTag.remove();
            }
        }
    }
}
