pragma ComponentBehavior: Bound

import QtQuick
import "TreeEngine.js" as Engine

// 树形选择器。触发器 + 下拉里的树；单选点一行即选、多选点复选框级联勾选。
//
//     TreeSelect {
//         width: 300
//         treeData: [{ label: "前端", value: "fe", children: [{ label: "React", value: "react" }] }]
//         onChange: (value, nodes) => ...
//     }
//
//     TreeSelect {
//         multiple: true
//         filterTreeNode: true
//         showFilteredOnly: true
//         leafOnly: true
//     }
//
// 官方属性面见 semi-ui/treeSelect/index.tsx（TreeSelectProps），交互见
// semi-foundation/treeSelect/foundation.ts + semi-foundation/tree/treeUtil.ts，
// 外观见 treeSelect.scss + tree/tree.scss + 两份 variables.scss。
// 几处对不上的地方（QML 侧的必然取舍，逐条都有测试盯着）：
//   · 官方回调 → 信号：onChange→change、onSelect→select、onSearch→search、
//     onExpand→expand、onClear→clear、onLoad→load、onVisibleChange→visibleChange、
//     onFocus/onBlur→focused/blurred。
//   · onChange 的第三个入参是 React 事件对象，QML 里没有对应物，一律不带。
//     官方在「点标签 X 移除」那一条路径上传的是 null（foundation.ts:585），
//     本来就不可用，去掉之后行为没有损失。
//   · 官方 onChangeWithObject=true 时第一个入参就是节点对象（数组），
//     这里仍走同一个 change(value, nodes) 信号：value 变成节点（数组）。
//   · 官方用 `'value' in props` 判受控；QML 没有这个概念，按仓库惯例
//     value / expandedKeys / loadedKeys 为 undefined 或 null 即非受控。
//   · 官方实例方法 search(value) 与 onSearch 在 React 里不冲突，在 QML 里
//     信号与函数不能同名，方法改名 searchBy。clearAll() 保持原名。
//   · renderSelectedItem 官方多选时返回 { isRenderInTag, content }，QML 的
//     Component 只能给出一棵可视树：这里**总是原样渲染钩子返回的节点**，
//     要不要套 Tag 由钩子自己画（gallery 的「自定义渲染已选项」就是这么写的）。
//     入参也不再是 (treeNode, {index, onClose})，改成根项上的普通属性：
//     modelData（节点数据）、index、selected、disabled、remove（函数）。
//   · triggerRender 同理收 Component，入参属性为 value（节点数组）、inputValue、
//     placeholder、disabled + 三个函数 search / clear / remove。
//   · loadData 官方返回 Promise，QML 没有 Promise：签名改成
//     `loadData(node, done)`，数据取回来后调用 done()。
//   · 展开箭头官方是 IconTreeTriangleDown（收起时 rotate(270deg)），本库图标集
//     没有这枚，用 chevron_right 转 90° 表达同一语义。
//   · 官方 disabledKeys（严格禁用）会把「子级全禁用」的父节点也标成禁用
//     （treeUtil.ts:645-650 那句自底向上的补集），这是上游自己的毛病，
//     这里只按「禁用节点 + 其全部子孙」算，不牵连父级。
//   · 官方单选重复点同一个节点时 onSelect 仍然回 selected=true（foundation.ts:692
//     恒传 true），但 onChange 不再发。这条不一致照抄，见 handleNodeSelect。
//   · showLine 与 expandAction 没有实现：官方这两条都是传给内层 Tree 消费的
//     （index.tsx:1427-1441 与 TreeContext），本库 Tree 自己也没有连线与「点行展开」，
//     不在这边造半个。
//   · 图标覆盖一族（arrowIcon / clearIcon / expandIcon）与 prefix / suffix（ReactNode）
//     没有对应物：本库前缀后缀按仓库惯例叫 prefixIcon / suffixIcon、吃图标名。
//   · DOM / 动画类 prop 一律不进 QML：dropdownClassName、dropdownStyle、optionListStyle、
//     getPopupContainer、stopPropagation、mouseEnterDelay、
//     mouseLeaveDelay、autoAdjustOverflow、zIndex、insetLabelId、position。
//     motion / motionExpand 是例外：官方那条动画是 NodeList 里真实存在的
//     （nodeList.tsx:71-81 → NodeCollapsible → Collapsible 的 height+opacity 过渡），
//     端口按 Tree 那一版复刻，度量同为 200ms。两条闸的分工照上游、不合并：
//     点箭头（含搜索档那一支）看 motionExpand（treeSelect/foundation.ts:253-255），
//     外部换 expandedKeys 与「换数据就关动画」那两支看 motion（index.tsx:417-449、512-533）。
//   · 动画区间「哪些行在演」与「这一行长什么样」是两件事：官方 NodeList 只借缓存那份列表
//     定位区间，行内容仍由 renderTreeNode 现场取 props ⇒ 端口每次现算 renderOptions 时按 key
//     换回当前记录（收起那 200ms 里父行的箭头当场翻面、选区当场亮）。
//     （Tree.qml 走的是另一条等价路径：它折的是行，但 `cachedRows` 是 readonly 绑定、
//     依赖捕获穿透 `makeRows` ⇒ 一样跟着当前状态重算，实测见 PROGRESS.md 坑 128。）
//   · 官方 demo「远程搜索」那一节给 TreeSelect 传了 loading，但 TreeSelectProps 里
//     没有这个 prop（那是 Select 的），这里不跟着造。
//   · clearAll() 的搜索框清理走 handleInputChange("")，官方走 clearInput()：
//     差别是多发一次 onSearch('')（过滤集与展开都按空搜索重算，显示结果一致）；
//     官方 clearInput() 读的是**清空之前**那份 selectedKeys（React setState 批量），
//     所以被清掉那一项的祖先会永久留在 expandedKeys —— 这条已经照抄，见 clearAll。
Item {
    id: control

    // ---------------------------------------------------------------- 官方属性面
    property var treeData: []
    property var keyMaps: ({})                  // { key, label, value, children, disabled, isLeaf, icon }
    property string treeNodeLabelProp: "label"

    property var value: undefined               // 受控值：单选是标量，多选是数组
    property var defaultValue: undefined
    property bool onChangeWithObject: false
    property bool multiple: false
    property string checkRelation: "related"    // "related" | "unRelated"
    property bool leafOnly: false
    property bool autoMergeValue: true
    property bool disabled: false
    property bool disableStrictly: false
    property bool showClear: false
    property bool showSearchClear: true

    property string placeholder: qsTr("请选择")
    property string searchPlaceholder: ""
    property var emptyContent: undefined        // undefined 用默认文案，"" 干脆不画空态
    property int size: Enums.Default
    property int validateStatus: Enums.StatusDefault
    property bool borderless: false

    // 搜索
    property var filterTreeNode: false          // false | function(input, label, node)
    property string treeNodeFilterProp: "label"
    property bool showFilteredOnly: false
    property bool remote: false
    property string searchPosition: "dropdown"  // "dropdown" | "trigger"
    property bool triggerTagWrap: false
    property bool searchAutoFocus: false

    // 展开
    property bool expandAll: false
    property bool defaultExpandAll: false
    property var defaultExpandedKeys: undefined
    property var expandedKeys: undefined
    property bool autoExpandParent: false
    // 展开/收起动画。官方这两条都在 TreeSelectProps 里（index.tsx:111、126，
    // 缺省 index.tsx:298-299 都是 true），且分工不同：
    //   · motionExpand —— foundation._isAnimated() 读的那条（TreeSelect 覆盖掉了
    //     Tree 那边读 motion 的口径），点箭头的这一手全归它管；
    //   · motion —— 只管 getDerivedStateFromProps 里「外部换 expandedKeys」那一支。
    property bool motion: true
    property bool motionExpand: true

    // 异步加载
    property var loadData: null                 // function (node, done)
    property var loadedKeys: undefined

    // 标签
    property int maxTagCount: -1
    property bool showRestTagsPopover: false
    property var restTagsPopoverProps: ({})

    // 下拉
    property bool dropdownMatchSelectWidth: true
    property var virtualize: ({})               // { itemSize, height, width }
    property bool defaultOpen: false
    property bool clickToHide: true
    property bool clickTriggerToHide: true      // 点触发器本身要不要收起（官方默认 true）
    property bool labelEllipsis: false

    // 外观扩展
    property string insetLabel: ""
    property string prefixIcon: ""
    property string suffixIcon: ""
    property string ariaLabel: "TreeSelect"

    // 钩子（根项声明的普通属性由本组件注入）
    property Component renderSelectedItem: null
    property Component triggerRender: null
    property Component outerTopSlot: null
    property Component outerBottomSlot: null

    // 分角圆角透给触发器，InputGroup 要靠它们还原 .semi-input-group 的首尾圆角
    property alias topLeftRadius: trigger.topLeftRadius
    property alias topRightRadius: trigger.topRightRadius
    property alias bottomLeftRadius: trigger.bottomLeftRadius
    property alias bottomRightRadius: trigger.bottomRightRadius

    signal change(var valueOrNodes, var nodes)
    signal select(string selectedKey, bool selected, var selectedNode)
    signal search(string input, var filteredExpandedKeys, var filteredNodes)
    signal expand(var expandedKeys, var info)
    signal clear()
    signal load(var loadedKeys, var node)
    signal visibleChange(bool isOpen)
    signal focused()
    signal blurred()

    // ---------------------------------------------------------------- 内部状态
    property var _selectedKeys: []              // 单选，长度 ≤ 1
    property var _checkedList: []               // 多选 related（含被级联选中的父/子）
    property var _realList: []                  // 多选 unRelated
    property var _expandedSet: ({})             // key → true
    property var _filteredKeySet: ({})
    property var _filteredExpandedSet: ({})
    property var _filteredShownSet: ({})
    property var _loadingSet: ({})
    property var _loadedSet: ({})
    property string _input: ""
    property bool _touched: false               // 用户动过选区，之后不再拿 defaultValue 播种
    property bool _seeded: false                // defaultExpandedKeys 只播一次
    property bool _mounted: false               // 第一次模型建好之后才算「数据变了」
    property bool _hovering: false
    property bool _hasFocus: false
    property bool _fieldFocus: false            // 触发器里那个输入框的焦点

    // 展开/收起动画（官方 state 里那四样：motionKeys / motionType /
    // cachedFlattenNodes + NodeList 自己的 transitionNodes）
    property var _motionKeySet: ({})            // motionKeys
    property string _motionType: "hide"         // 官方 state 初值就是 'hide'（index.tsx:359）
    property bool _motionRunning: false         // 端口记账：transitionNodes 挂没挂上
    property int _motionSeq: 0                  // 起手计数（官方靠 key 换了重挂 NodeCollapsible）
    property var _cachedRows: undefined         // cachedFlattenNodes：收起时那组行取的是**改之前**那份
    property var _prevExpandedSet: ({})         // prevState.expandedKeys 的等价物（派生视图要自己记上一拍）

    // 弹层开关状态一律读 popup.isOpen（PopupBase 由 aboutToShow/aboutToHide 驱动）。
    // 不要自己记一份，也不要读 popup.visible（退场动画期间仍为 true）。
    readonly property bool isOpen: popup.isOpen

    // 受控判定要走函数而不是 readonly 属性：信号发的时候依赖它的 readonly 还没重算，
    // 在 onValueChanged 里读 controlled 拿到的是旧值（实测会漏掉第一次外部赋值）。
    function isControlled() {
        return control.value !== undefined && control.value !== null;
    }

    readonly property bool controlled: control.isControlled()
    // 受控判定走函数：readonly 属性在 onExpandedKeysChanged 那一拍还没重算，
    // 在 handler 里读它拿到的是旧值（同 isControlled 那条坑）
    function isExpandControlled() {
        return control.expandedKeys !== undefined && control.expandedKeys !== null;
    }

    readonly property bool expandControlled: control.isExpandControlled()
    readonly property bool loadControlled: control.loadedKeys !== undefined
        && control.loadedKeys !== null
    readonly property bool interactive: control.enabled && !control.disabled
    readonly property bool related: control.checkRelation === "related"
    readonly property bool filterable: control.filterTreeNode !== false
        && control.filterTreeNode !== undefined && control.filterTreeNode !== null
    readonly property bool triggerSearch: control.filterable && control.searchPosition === "trigger"
    readonly property bool dropdownSearch: control.filterable
        && control.searchPosition !== "trigger"
    readonly property bool inSearch: control._input !== "" && !control.remote
    readonly property bool useVirtualList: control.isObj("virtualize")
        && Object.keys(control.virtualize).length > 0
    readonly property bool wrapped: control.triggerTagWrap && control.multiple && control.triggerSearch

    // 模型不写成 JS 表达式绑定：那种绑定在 Component.onCompleted 那一拍可能还没 flush
    // （实测读到 undefined），播种会整段抛掉。改成「空模型 + 显式 rebuild」，
    // treeData / keyMaps 变化时重算，派生属性盯 _mChanged 重算。
    property var _m: ({ keys: [], roots: [], byKey: {}, byValue: {} })
    // TreeEngine 里 calcMotionKeys / getMotionKeys 要官方 keyEntities 那个形状
    // （{ key, children: [{ key }] }），而本组件的模型存的是 childKeys 字符串数组，
    // 所以每次重建模型时顺手搭一层只含 key 的壳给引擎用。
    property var _entities: ({})
    readonly property var _checkedKeys: control.multiple
        ? (control.related ? control._checkedList : control._realList) : []
    readonly property var _checkedSet: control.toSet(control._checkedKeys)
    readonly property var _halfSet: control.computeHalf(control._checkedSet)
    readonly property var _disabledSet: control.computeDisabledKeys()

    // ---------------------------------------------------------------- 小工具
    function isObj(name) {
        const v = control[name];
        return v !== undefined && v !== null && typeof v === "object" && !Array.isArray(v);
    }

    function toSet(list) {
        const s = {};
        for (let i = 0; i < list.length; ++i)
            s[list[i]] = true;
        return s;
    }

    function mapName(field) {
        const m = control.keyMaps;
        if (m !== undefined && m !== null && m[field] !== undefined)
            return String(m[field]);
        return field;
    }

    function pick(obj, name, fallback) {
        if (obj === undefined || obj === null)
            return fallback;
        const v = obj[name];
        return v === undefined ? fallback : v;
    }

    // restTagsPopoverProps.position → 本库的 placement 枚举（同 TagInput）
    function placementOf(name) {
        switch (String(name)) {
        case "top": return Enums.Top;
        case "topLeft": return Enums.TopLeft;
        case "topRight": return Enums.TopRight;
        case "bottomLeft": return Enums.BottomLeft;
        case "bottomRight": return Enums.BottomRight;
        case "left": return Enums.Left;
        case "leftTop": return Enums.LeftTop;
        case "leftBottom": return Enums.LeftBottom;
        case "right": return Enums.Right;
        case "rightTop": return Enums.RightTop;
        case "rightBottom": return Enums.RightBottom;
        case "bottom":
        default: return Enums.Bottom;
        }
    }

    function copySet(src) {
        const out = {};
        for (const k in src)
            out[k] = src[k];
        return out;
    }

    // ---------------------------------------------------------------- 数据模型
    // 官方 convertDataToEntities（treeUtil.ts:163-195）：内部身份是 key，
    // 没有 key 就用 pos 串（"0-1-2"）顶上；value → key 另建一张表。
    function buildModel() {
        const out = { keys: [], roots: [], byKey: {}, byValue: {} };
        const kidsName = control.mapName("children");
        const keyName = control.mapName("key");
        const valName = control.mapName("value");
        const labName = control.mapName("label");
        const disName = control.mapName("disabled");
        const leafName = control.mapName("isLeaf");
        const walk = (nodes, parentKey, level, posBase) => {
            const levelKeys = [];
            if (!Array.isArray(nodes))
                return levelKeys;
            for (let i = 0; i < nodes.length; ++i) {
                const node = nodes[i];
                if (node === undefined || node === null)
                    continue;
                const pos = posBase === "" ? String(i) : posBase + "-" + i;
                const rawKey = node[keyName];
                const key = rawKey === undefined || rawKey === null ? pos : String(rawKey);
                const rawVal = node[valName];
                const label = node[labName] !== undefined ? node[labName] : node[control.treeNodeLabelProp];
                const rec = {
                    key: key,
                    value: rawVal === undefined ? key : rawVal,
                    label: label === undefined ? "" : label,
                    data: node,
                    parentKey: parentKey,
                    level: level,
                    pos: pos,
                    disabled: node[disName] === true,
                    declaredLeaf: node[leafName] === true,
                    childKeys: [],
                };
                out.keys.push(key);
                out.byKey[key] = rec;
                if (rawVal !== undefined)
                    out.byValue[rawVal] = key;
                levelKeys.push(key);
                // 递归拿到本层子 key 直接挂到 rec.childKeys 上，省掉「第二遍按 parentKey 归拢」
                const kids = node[kidsName];
                if (Array.isArray(kids) && kids.length > 0) {
                    const kidKeys = walk(kids, key, level + 1, pos);
                    for (let j = 0; j < kidKeys.length; ++j)
                        rec.childKeys.push(kidKeys[j]);
                }
            }
            return levelKeys;
        };
        out.roots = walk(control.treeData, null, 0, "");
        return out;
    }

    function recOf(key) {
        return control._m.byKey[key];
    }

    function rebuildModel() {
        const prevKeys = control._m.keys;
        const next = control.buildModel();
        // 官方 gDSFP:417-426：treeData 的 key 集合变了就把动画整段关掉，
        // motionType 直接置空（这条判据读的是 props.motion —— motion:false 时
        // 反而不清，上游自己两处口径不一致，照抄）。
        if (control.motion && control._mounted
            && !control.keySetsEqual(prevKeys, next.keys)) {
            control._motionKeySet = ({});
            control._motionType = "";
        }
        control._m = next;
        control._entities = control.buildEntities();
    }

    // lodash isEqual 用在「两串 key 数组」上：顺序与长度都算
    function keySetsEqual(a, b) {
        if (a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; ++i) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }

    function buildEntities() {
        const out = {};
        for (let i = 0; i < control._m.keys.length; ++i) {
            const rec = control._m.byKey[control._m.keys[i]];
            const kids = [];
            for (let j = 0; j < rec.childKeys.length; ++j)
                kids.push({ key: rec.childKeys[j] });
            out[rec.key] = { key: rec.key, children: kids };
        }
        return out;
    }

    function descendantKeys(key, includeSelf) {
        const rec = control._m.byKey[key];
        const out = [];
        if (rec === undefined)
            return out;
        if (includeSelf)
            out.push(key);
        let stack = rec.childKeys.slice();
        while (stack.length > 0) {
            const k = stack.pop();
            out.push(k);
            const r = control._m.byKey[k];
            if (r !== undefined)
                stack = stack.concat(r.childKeys);
        }
        return out;
    }

    function ancestorKeys(key) {
        const out = [];
        let rec = control._m.byKey[key];
        while (rec !== undefined && rec.parentKey !== null) {
            out.push(rec.parentKey);
            rec = control._m.byKey[rec.parentKey];
        }
        return out;
    }

    function isLeafKey(key) {
        const rec = control._m.byKey[key];
        if (rec === undefined)
            return true;
        if (rec.childKeys.length > 0)
            return false;
        // 官方 isLeaf()（treeNode.tsx:182-192）：声明了 isLeaf 就听声明，
        // 有 loadData 且已加载完才算叶子
        if (rec.declaredLeaf)
            return true;
        if (control.loadData === null || typeof control.loadData !== "function")
            return true;
        return control.isLoadedKey(key);
    }

    // 官方 handleNodeLoad 的去重看的是 state 里那份 loadedKeys，而受控时 state 就是 prop
    // （index.tsx 的 getDerivedStateFromProps 把 new Set(props.loadedKeys) 写回 state，
    // foundation.ts:374-378）。所以外部声明「已加载」的节点同样不该再发一次 loadData。
    function isLoadedKey(key) {
        if (control._loadedSet[key] === true)
            return true;
        if (!control.loadControlled)
            return false;
        const raw = control.loadedKeys || [];
        for (let i = 0; i < raw.length; ++i) {
            if (String(raw[i]) === String(key))
                return true;
        }
        return false;
    }

    function isNodeDisabled(key) {
        const rec = control._m.byKey[key];
        if (rec === undefined)
            return false;
        return rec.disabled === true || control._disabledSet[key] === true;
    }

    // 官方 calcDisabledKeys（treeUtil.ts:645-650）：禁用节点 + 其全部子孙。
    // 上游还会把「子级全禁用」的父级也标禁用，这条毛病不抄（见顶部说明）。
    function computeDisabledKeys() {
        const out = {};
        if (!control.disableStrictly)
            return out;
        for (let i = 0; i < control._m.keys.length; ++i) {
            const k = control._m.keys[i];
            if (control._m.byKey[k].disabled !== true)
                continue;
            out[k] = true;
            const desc = control.descendantKeys(k, false);
            for (let j = 0; j < desc.length; ++j)
                out[desc[j]] = true;
        }
        return out;
    }

    // 半选 = 自己没全选中、但子孙里有选中的（官方 halfCheckedKeys 的稳态等价物）
    function computeHalf(checked) {
        const out = {};
        if (!control.multiple || !control.related)
            return out;
        for (let i = 0; i < control._m.keys.length; ++i) {
            const k = control._m.keys[i];
            const rec = control._m.byKey[k];
            if (rec.childKeys.length === 0 || checked[k] === true)
                continue;
            const desc = control.descendantKeys(k, false);
            for (let j = 0; j < desc.length; ++j) {
                if (checked[desc[j]] === true) {
                    out[k] = true;
                    break;
                }
            }
        }
        return out;
    }

    // ---------------------------------------------------------------- 值 ↔ key
    function keyOfValue(v) {
        const k = control._m.byValue[v];
        // 官方 findKeysForValues：认不出的值原样当 key 用
        return k === undefined ? String(v) : k;
    }

    function keysOfValues(vals) {
        const out = [];
        if (vals === undefined || vals === null)
            return out;
        const list = Array.isArray(vals) ? vals : [vals];
        for (let i = 0; i < list.length; ++i) {
            const one = control.onChangeWithObject && typeof list[i] === "object"
                ? list[i][control.mapName("value")] : list[i];
            if (one === undefined || one === null)
                continue;
            const k = control.keyOfValue(one);
            if (out.indexOf(k) < 0)
                out.push(k);
        }
        return out;
    }

    // 官方 normalizeKeyList：leafOnly 只留叶子，否则把「父也在列表里」的项丢掉
    // （这就是「子全选完自动显示父」的那一步，treeUtil.ts:461-490）
    function normalizeKeyList(keys, leafOnlyMode) {
        const set = control.toSet(keys);
        const out = [];
        for (let i = 0; i < keys.length; ++i) {
            const rec = control._m.byKey[keys[i]];
            if (rec === undefined) {
                out.push(keys[i]);
                continue;
            }
            if (leafOnlyMode) {
                if (rec.childKeys.length === 0)
                    out.push(keys[i]);
            } else if (rec.parentKey === null || set[rec.parentKey] !== true) {
                out.push(keys[i]);
            }
        }
        return out;
    }

    // 触发器上要画的那串 key（官方 triggerRenderKeys，index.tsx:1120-1132）
    readonly property var displayKeys: control.computeDisplayKeys()

    function computeDisplayKeys() {
        if (!control.multiple)
            return control._selectedKeys;
        if (!control.related || !control.autoMergeValue)
            return control._checkedKeys;
        return control.normalizeKeyList(control._checkedKeys, control.leafOnly);
    }

    // 官方 `get(keyMaps, 'label', treeNodeLabelProp)`（index.tsx:885、1206）：
    // keyMaps.label 优先，否则用 treeNodeLabelProp（它自己默认 'label'）。
    // 这个只影响触发器上回显的文字，下拉里的行仍按 keyMaps.label / data.label 渲染。
    function triggerLabelName() {
        const m = control.keyMaps;
        if (m !== undefined && m !== null && m.label !== undefined)
            return String(m.label);
        return control.treeNodeLabelProp;
    }

    function labelOfKey(key) {
        const rec = control._m.byKey[key];
        if (rec !== undefined) {
            const t = rec.data[control.triggerLabelName()];
            return t === undefined ? String(rec.label) : String(t);
        }
        // 官方 getDataForKeyNotInKeyEntities：树里找不到的值，退化成把值本身当标签
        const v = control.value;
        if (Array.isArray(v)) {
            for (let i = 0; i < v.length; ++i) {
                if (typeof v[i] === "object" && v[i] !== null
                    && String(v[i][control.mapName("value")]) === String(key))
                    return String(v[i][control.mapName("label")] === undefined
                        ? key : v[i][control.mapName("label")]);
            }
        }
        return String(key);
    }

    // ---------------------------------------------------------------- 选区写入
    function notifyChange(keys) {
        const nodes = [];
        const values = [];
        for (let i = 0; i < keys.length; ++i) {
            const rec = control._m.byKey[keys[i]];
            if (rec === undefined)
                continue;
            nodes.push(rec.data);
            values.push(rec.value);
        }
        if (control.multiple) {
            control.change(control.onChangeWithObject ? nodes : values, nodes);
            return;
        }
        if (keys.length === 0) {
            control.change(undefined, []);
            return;
        }
        const rec = control._m.byKey[keys[0]];
        control.change(control.onChangeWithObject
            ? (rec === undefined ? undefined : rec.data)
            : (rec === undefined ? keys[0] : rec.value),
        rec === undefined ? [] : [rec.data]);
    }

    function writeSelection(list) {
        if (control.controlled)
            return;
        if (control.multiple) {
            if (control.related)
                control._checkedList = list;
            else
                control._realList = list;
        } else {
            control._selectedKeys = list;
        }
    }

    // 官方 calcCheckedKeysForChecked/Unchecked 的稳态等价：
    // 父节点当且仅当「所有子节点都选中」时才算选中
    function rebalanceParents(list, fromKey) {
        const out = list.slice();
        const set = control.toSet(out);
        const chain = control.ancestorKeys(fromKey);
        for (let i = 0; i < chain.length; ++i) {
            const rec = control._m.byKey[chain[i]];
            if (rec === undefined)
                continue;
            let all = rec.childKeys.length > 0;
            for (let j = 0; j < rec.childKeys.length; ++j) {
                if (set[rec.childKeys[j]] !== true) {
                    all = false;
                    break;
                }
            }
            if (all && set[rec.key] !== true) {
                out.push(rec.key);
                set[rec.key] = true;
            } else if (!all && set[rec.key] === true) {
                const at = out.indexOf(rec.key);
                if (at >= 0)
                    out.splice(at, 1);
                delete set[rec.key];
            }
        }
        return out;
    }

    // 本次操作真正会动到的 key：非严格禁用时是「自己 + 全部子孙」，
    // 严格禁用时只有「自己（若未禁用）+ 未禁用的叶子子孙」
    function affectedKeys(key) {
        const rec = control._m.byKey[key];
        if (rec === undefined)
            return [];
        if (!control.disableStrictly)
            return [key].concat(control.descendantKeys(key, false));
        const out = [];
        if (control.isNodeDisabled(key) !== true)
            out.push(key);
        const desc = control.descendantKeys(key, false);
        for (let i = 0; i < desc.length; ++i) {
            const r = control._m.byKey[desc[i]];
            if (r.childKeys.length === 0 && control.isNodeDisabled(r.key) !== true)
                out.push(r.key);
        }
        return out;
    }

    // 官方 calcCheckedStatus（foundation.ts:773-786）：取消永远允许；
    // 请求勾选时，若这批该选的都选了，就翻成取消
    function targetStatus(key) {
        const aff = control.affectedKeys(key);
        const set = control._checkedSet;
        let allOn = aff.length > 0;
        for (let i = 0; i < aff.length; ++i) {
            if (set[aff[i]] !== true) {
                allOn = false;
                break;
            }
        }
        return !allOn;
    }

    function handleNodeSelect(rec) {
        if (!control.interactive || rec === undefined || rec === null)
            return;
        const key = String(rec.key);
        const model = control._m.byKey[key];
        if (model === undefined || control.isNodeDisabled(key))
            return;
        const data = model.data;

        if (!control.multiple) {
            const already = control._selectedKeys.length > 0 && control._selectedKeys[0] === key;
            // 官方恒传 selected=true（foundation.ts:692），重复点也再发一次 onSelect，
            // 只是不再发 onChange —— 上游的不一致，照抄
            control.select(key, true, data);
            if (!already) {
                control._touched = true;
                control.writeSelection([key]);
                control.notifyChange([key]);
            }
            if (control.clickToHide)
                control.close();
            return;
        }

        const cur = control._checkedKeys.slice();
        let next;
        let target;
        if (control.related) {
            target = control.targetStatus(key);
            const aff = control.affectedKeys(key);
            const drop = control.toSet(aff);
            next = cur.filter(k => drop[k] !== true);
            if (target)
                next = next.concat(aff);
            next = control.rebalanceParents(next, key);
        } else {
            target = control._checkedSet[key] !== true;
            next = cur.filter(k => k !== key);
            if (target)
                next.push(key);
        }
        control._touched = true;
        control.select(key, target, data);
        control.writeSelection(next);
        control.notifyChange(control.related && control.autoMergeValue
            ? control.normalizeKeyList(next, control.leafOnly) : next);
        // 官方：搜索框在触发器里时，勾一下就把输入清空（foundation.ts:753-755）
        if (control.triggerSearch && control._input !== "")
            control.handleInputChange("");
    }

    // 点标签上的 X（官方 removeTag）
    function removeAt(key) {
        if (!control.interactive)
            return;
        const k = String(key);
        if (control.isNodeDisabled(k))
            return;
        const cur = control._checkedKeys.slice();
        let next = cur.filter(x => x !== k);
        if (control.related) {
            const aff = control.descendantKeys(k, true);
            const drop = control.toSet(aff);
            next = next.filter(x => drop[x] !== true);
            next = control.rebalanceParents(next, k);
        }
        control._touched = true;
        control.notifyChange(control.related && control.autoMergeValue
            ? control.normalizeKeyList(next, control.leafOnly) : next);
        control.select(k, false, control._m.byKey[k] === undefined ? {} : control._m.byKey[k].data);
        control.writeSelection(next);
    }

    // 官方 handleClear：先回抛空值，再清内部状态，最后清搜索框 + onClear
    function clearAll() {
        if (!control.interactive)
            return;
        // 官方 clearInput() 读的是**清空之前**的 selectedKeys（React 的 setState 批量，
        // 同一轮 handler 里 getStates() 仍旧值，foundation.ts:534-561）—— 所以带搜索词
        // 点清除之后，刚被清掉那一项的祖先会永久留在 expandedKeys。
        const prev = control.multiple ? control._checkedKeys.slice() : control._selectedKeys.slice();
        control.notifyChange([]);
        control.writeSelection([]);
        control._touched = true;
        // 与官方的差异：官方走 clearInput() 不发 onSearch，我们统一由 handleInputChange("")
        // 清，所以这里多发一次 onSearch('')（过滤集与展开按空搜索重算，结果一致）。
        if (control.triggerSearch && control._input !== "") {
            control.handleInputChange("");
            if (!control.isExpandControlled()) {
                const next = control.copySet(control._expandedSet);
                for (let i = 0; i < prev.length; ++i) {
                    const anc = control.ancestorKeys(prev[i]);
                    for (let j = 0; j < anc.length; ++j)
                        next[anc[j]] = true;
                }
                control._expandedSet = next;
                control.rememberExpanded();
            }
        }
        control.clear();
    }

    // ---------------------------------------------------------------- 搜索
    function matchOne(rec) {
        const prop = control.treeNodeFilterProp !== "label"
            ? control.treeNodeFilterProp : control.mapName("label");
        const target = rec.data[prop];
        if (typeof control.filterTreeNode === "function")
            return Boolean(control.filterTreeNode(control._input, target, rec.data));
        if (typeof target !== "string")
            return String(target) === control._input;
        // 官方 filter()（treeUtil.ts:437-443）：两边转小写的子串匹配
        return target.toLowerCase().indexOf(control._input.toLowerCase()) >= 0;
    }

    function handleInputChange(text) {
        control._input = String(text);
        if (control.remote) {
            // 官方 remote：不做本地过滤，只发 onSearch(input, [], [])
            control._filteredKeySet = {};
            control._filteredExpandedSet = {};
            control._filteredShownSet = {};
            control.search(control._input, [], []);
            return;
        }
        const hits = [];
        const filtered = {};
        const expanded = {};
        const shown = {};
        if (control._input !== "") {
            for (let i = 0; i < control._m.keys.length; ++i) {
                const k = control._m.keys[i];
                const rec = control._m.byKey[k];
                if (!control.matchOne(rec))
                    continue;
                hits.push(k);
                filtered[k] = true;
                shown[k] = true;
                const desc = control.descendantKeys(k, false);
                for (let j = 0; j < desc.length; ++j)
                    shown[desc[j]] = true;
                const anc = control.ancestorKeys(k);
                for (let j = 0; j < anc.length; ++j) {
                    expanded[anc[j]] = true;
                    shown[anc[j]] = true;
                }
            }
        } else {
            // 官方：清空搜索把选中项的祖先并进 expandedKeys（永久生效）
            const next = control.copySet(control._expandedSet);
            const sel = control.multiple ? control._checkedKeys : control._selectedKeys;
            for (let i = 0; i < sel.length; ++i) {
                const anc = control.ancestorKeys(sel[i]);
                for (let j = 0; j < anc.length; ++j)
                    next[anc[j]] = true;
            }
            if (!control.isExpandControlled())
                control._expandedSet = next;
        }
        control._filteredKeySet = filtered;
        control._filteredExpandedSet = expanded;
        control._filteredShownSet = shown;
        // 官方 handleInputChange 的 updateState 里明确写了 motionKeys: new Set([])
        // （foundation.ts:668）—— 换搜索词不算展开动画，不该留一组动画键
        control._motionKeySet = ({});
        control.rememberExpanded();
        const keys = Object.keys(expanded);
        const nodes = hits.map(k => control._m.byKey[k].data);
        control.search(control._input, keys, nodes);
    }

    // 官方实例方法 search(value)：外部手动触发，会照常回抛 onSearch
    function searchBy(value) {
        if (!control.isOpen)
            control.open();
        control.handleInputChange(String(value));
    }

    // ---------------------------------------------------------------- 展开
    function expandedView() {
        if (control.isExpandControlled()) {
            const raw = Array.isArray(control.expandedKeys) ? control.expandedKeys : [];
            if (!control.autoExpandParent)
                return control.toSet(raw.map(k => String(k)));
            const out = {};
            for (let i = 0; i < raw.length; ++i) {
                const k = String(raw[i]);
                out[k] = true;
                const anc = control.ancestorKeys(k);
                for (let j = 0; j < anc.length; ++j)
                    out[anc[j]] = true;
            }
            return out;
        }
        return control.inSearch ? control._filteredExpandedSet : control._expandedSet;
    }

    function isExpanded(key) {
        return control.expandedView()[key] === true;
    }

    function toggleExpand(key) {
        if (!control.interactive)
            return;
        const rec = control._m.byKey[key];
        if (rec === undefined)
            return;
        const wasOpen = control.isExpanded(key);
        // 官方：没有子节点又不给 loadData 的，点箭头没反应（foundation.ts:832）
        if (!wasOpen && rec.childKeys.length === 0
            && (control.loadData === null || typeof control.loadData !== "function"))
            return;

        // foundation.ts:793/845 —— 收起是 hide，展开是 show
        const motionType = wasOpen ? "hide" : "show";
        // 官方在「受控不写状态」那一支**外面**：收起时先把改之前那份列表存下来，
        // 否则 NodeList 拿新列表找不到要消失的那几条，动画区间就空了
        control.cacheRows(motionType === "hide" && control.motionExpand);

        if (control.inSearch) {
            if (!control.isExpandControlled()) {
                const next = control.copySet(control._filteredExpandedSet);
                if (next[key] === true)
                    delete next[key];
                else
                    next[key] = true;
                control._filteredExpandedSet = next;
                control.setMotion(control.motionExpand
                    ? Engine.getMotionKeys(key, next, control._entities) : [], motionType);
            }
        } else if (!control.isExpandControlled()) {
            const next = control.copySet(control._expandedSet);
            if (next[key] === true)
                delete next[key];
            else
                next[key] = true;
            control._expandedSet = next;
            control.setMotion(control.motionExpand
                ? Engine.getMotionKeys(key, next, control._entities) : [], motionType);
        }
        control.rememberExpanded();
        const list = Object.keys(control.inSearch ? control._filteredExpandedSet
            : (control.isExpandControlled() ? control.toSet((control.expandedKeys || []).map(k => String(k))) : control._expandedSet));
        control.expand(list, { expanded: !wasOpen, node: rec.data });
        if (!wasOpen && control.loadData !== null && typeof control.loadData === "function"
            && rec.childKeys.length === 0)
            control.requestLoad(key, rec.data);
    }

    // ---------------------------------------------------------------- 展开/收起动画
    // 官方 foundation._isAnimated() 在 TreeSelect 里读的是 motionExpand
    // （treeSelect/foundation.ts:253-255，Tree 那边读的是 motion）；
    // 而 NodeList 那一侧的闸也是同一条（treeSelect/index.tsx:1464
    // `motionKeys={motionExpand ? motionKeys : new Set([])}`）。
    function beginMotion() {
        if (!control.motionExpand || control.useVirtualList)
            return;
        if (Object.keys(control._motionKeySet).length === 0)
            return;
        control._motionRunning = true;
        control._motionSeq = control._motionSeq + 1;
    }

    function endMotion() {
        control._motionRunning = false;
        control._motionKeySet = ({});
    }

    // 一次写入 motionKeys + motionType 并起手（对应官方 updateState 那一句）。
    // 「要不要算这组键」归调用方管：点箭头那一支看 motionExpand，
    // 受控那一支看 motion，而**显示**那一层的闸永远是 motionExpand。
    function setMotion(keys, type) {
        control._motionKeySet = Engine.toSet(keys);
        control._motionType = type;
        control.beginMotion();
    }

    function cacheRows(on) {
        // 官方 adapter.cacheFlattenNodes：cloneDeep(state.flattenNodes)，读的是**写之前**那份
        control._cachedRows = on ? control.visibleOptions : undefined;
    }

    // prevState.expandedKeys 的等价物：显示用的展开集是派生绑定，改完就读不到旧值了，
    // 所以每次改动收尾都记一份快照，下一次受控变更拿它做 diff
    function rememberExpanded() {
        control._prevExpandedSet = control.copySet(control.expandedView());
    }

    // getDerivedStateFromProps 里「外部换 expandedKeys」那一支（index.tsx:437-449、512-533）。
    // 只有 motion=true 才算动画键，且要求两次展开集**只差一个**（calcMotionKeys:642）。
    function motionOnControlledChange() {
        if (!control.isExpandControlled())
            return;
        const next = control.expandedView();
        if (!control.motion) {
            control._prevExpandedSet = control.copySet(next);
            return;
        }
        const res = Engine.calcMotionKeys(control._prevExpandedSet, next, control._entities);
        let keys = res.motionKeys;
        // index.tsx:524-526：showFilteredOnly 时只留「搜索态下真的看得见」的那几条
        if (control.inSearch && control.showFilteredOnly)
            keys = keys.filter(k => control._filteredShownSet[k] === true);
        control._prevExpandedSet = control.copySet(next);
        control.setMotion(keys, res.motionType);
    }

    function requestLoad(key, data) {
        if (control._loadingSet[key] === true || control.isLoadedKey(key))
            return;
        const loading = control.copySet(control._loadingSet);
        loading[key] = true;
        control._loadingSet = loading;
        const done = function () {
            const l = control.copySet(control._loadingSet);
            delete l[key];
            control._loadingSet = l;
            if (!control.loadControlled) {
                const loaded = control.copySet(control._loadedSet);
                loaded[key] = true;
                control._loadedSet = loaded;
            }
            const after = control.copySet(control._loadedSet);
            after[key] = true;
            control.load(Object.keys(control.loadControlled ? control.toSet(
                (control.loadedKeys || []).map(k => String(k))) : after), data);
        };
        control.loadData(data, done);
    }

    // ---------------------------------------------------------------- 可见列表
    readonly property var visibleOptions: control.buildVisible()

    // 一行的渲染数据。官方 renderTreeNode 是拿 key 现场去 getTreeNodeProps，
    // 所以「哪几个位置在动画」和「这一行长什么样」是两件事；端口把状态烘在记录里，
    // 那就得在每次现算时按 key 取当前那份 —— 收起动画里那几条虽然已经不在可见列表上，
    // 底色与勾选态照样跟着当前选区走。
    function rowRecord(key, expanded, shownOnly) {
        const rec = control._m.byKey[key];
        if (rec === undefined)
            return null;
        return {
            key: key,
            label: rec.label,
            value: rec.value,
            level: rec.level,
            disabled: control.isNodeDisabled(key),
            // 有子节点、或者虽然没子节点但 loadData 还没跑完 —— 官方都给箭头
            hasChildren: rec.childKeys.length > 0 || !control.isLeafKey(key),
            leaf: control.isLeafKey(key),
            expanded: expanded[key] === true,
            selected: !control.multiple && control._selectedKeys[0] === key,
            checked: control._checkedSet[key] === true,
            half: control._halfSet[key] === true,
            matched: control.inSearch && control._filteredKeySet[key] === true,
            loading: control._loadingSet[key] === true,
            data: rec.data,
        };
    }

    function buildVisible() {
        const m = control._m;
        const expanded = control.expandedView();
        const shownOnly = control.inSearch && control.showFilteredOnly
            ? control._filteredShownSet : null;
        const out = [];
        const walk = (keys) => {
            for (let i = 0; i < keys.length; ++i) {
                const k = keys[i];
                const rec = m.byKey[k];
                if (shownOnly !== null && shownOnly[k] !== true) {
                    // 被裁掉的分支里，命中的子孙还得有机会出现（它在 shown 里）
                    walk(rec.childKeys);
                    continue;
                }
                out.push(control.rowRecord(k, expanded, shownOnly));
                if (rec.childKeys.length > 0 && expanded[k] === true)
                    walk(rec.childKeys);
            }
        };
        walk(m.roots);
        return out;
    }

    readonly property bool noData: control.visibleOptions.length === 0
    // 官方 NodeList 的那份 transitionNodes：动画区间那几条被折成一个数组，
    // Repeater 把它当成一格委托项（组），其余还是逐行。收起那一手取的是**改之前**
    // 那份列表（flattenList），否则要消失的行已经不在列表里了。
    readonly property var renderOptions: control.buildRenderOptions()

    function buildRenderOptions() {
        if (control.useVirtualList || !control.motionExpand || !control._motionRunning)
            return control.visibleOptions;
        if (Object.keys(control._motionKeySet).length === 0)
            return control.visibleOptions;
        const live = control.visibleOptions;
        const grouped = Engine.buildTransitionNodes(live, control._motionKeySet,
            control._motionType,
            control._cachedRows === undefined ? [] : control._cachedRows);
        // transitionNodes 里存的只是「哪些位置」，行的内容一律按 key 现取当前那份
        // （官方 renderTreeNode 走 getTreeNodeProps）；只有模型里已经没这个键
        // （动画跑到一半换了 treeData）才退回缓存记录。
        const expanded = control.expandedView();
        const shownOnly = control.inSearch && control.showFilteredOnly
            ? control._filteredShownSet : null;
        const out = [];
        for (let k = 0; k < grouped.length; ++k) {
            const e = grouped[k];
            if (!(e instanceof Array)) {
                out.push(control.currentRow(e, expanded, shownOnly));
                continue;
            }
            const g = [];
            for (let j = 0; j < e.length; ++j)
                g.push(control.currentRow(e[j], expanded, shownOnly));
            out.push(g);
        }
        return out;
    }

    function currentRow(entry, expanded, shownOnly) {
        const fresh = control.rowRecord(entry.key, expanded, shownOnly);
        return fresh === null ? entry : fresh;
    }

    function entryIsGroup(index) {
        const e = control.renderOptions[index];
        return e !== undefined && e !== null && Array.isArray(e);
    }

    function entryLength(index) {
        const e = control.renderOptions[index];
        return Array.isArray(e) ? e.length : 1;
    }

    // 第 index 格（组的话再加组内序号 inner）对应的行记录
    function entryRow(index, inner) {
        const e = control.renderOptions[index];
        if (e === undefined || e === null)
            return null;
        if (!(e instanceof Array))
            return inner > 0 ? null : e;
        return e[inner] === undefined ? null : e[inner];
    }

    // 第 index 格的第一条渲染行在整列里的序号（给行的 objectName 用）
    function entryStartRow(index) {
        let n = 0;
        for (let i = 0; i < index && i < control.renderOptions.length; ++i)
            n += control.entryLength(i);
        return n;
    }

    // 官方 emptyContent 是 ReactNode。QML 侧 var 属性读回来时 undefined 和 null 分不开
    // （实测两者互相 ===），所以「不画空态」用空串表达，不拿 null 当哨兵。
    readonly property string emptyText: control.emptyContent === undefined || control.emptyContent === null
        ? qsTr("暂无数据") : String(control.emptyContent)

    // ---------------------------------------------------------------- 播种与同步
    // 官方在 constructor + getDerivedStateFromProps 里做，QML 里靠这三处：
    //   · 受控 → 显示值永远跟着 value / expandedKeys / loadedKeys
    //   · 非受控且用户没动过 → 跟着 defaultValue 播种
    //   · expandAll 在 treeData 变化后仍然生效，defaultExpandAll 只在初始化生效
    function seedSelection() {
        if (control.controlled || control._touched)
            return;
        const keys = control.keysOfValues(control.defaultValue);
        if (control.multiple) {
            // rebalanceAll 要扫整棵树，空选区没必要走一遍
            control._checkedList = control.related && keys.length > 0
                ? control.rebalanceAll(keys) : keys;
            control._realList = keys;
        } else {
            control._selectedKeys = keys.length > 0 ? [keys[0]] : [];
        }
    }

    // 播种时要把「子全选自动带上父」算全（rebalanceParents 只沿一条链走）
    function rebalanceAll(keys) {
        const m = control._m;
        let out = keys.slice();
        for (let i = 0; i < m.keys.length; ++i) {
            const rec = m.byKey[m.keys[i]];
            if (rec.childKeys.length === 0)
                continue;
            const set = control.toSet(out);
            let all = true;
            for (let j = 0; j < rec.childKeys.length; ++j) {
                if (set[rec.childKeys[j]] !== true) {
                    all = false;
                    break;
                }
            }
            if (all && set[rec.key] !== true)
                out.push(rec.key);
        }
        return out;
    }

    function expandEverything() {
        const all = {};
        for (let i = 0; i < control._m.keys.length; ++i)
            all[control._m.keys[i]] = true;
        control._expandedSet = all;
    }

    function seedExpansion() {
        if (control.isExpandControlled())
            return;
        // expandAll 每次数据变化都生效；defaultExpandAll / defaultExpandedKeys /
        // 「按选中项补祖先」只在第一次拿到非空模型时生效一次
        // （index.tsx:427、450-451）
        if (control.expandAll) {
            control.expandEverything();
            return;
        }
        if (control._seeded)
            return;
        if (control._m.keys.length === 0)
            return;
        control._seeded = true;
        if (control.defaultExpandAll) {
            control.expandEverything();
            return;
        }
        const next = {};
        const raw = control.defaultExpandedKeys;
        if (raw !== undefined && raw !== null) {
            for (let i = 0; i < raw.length; ++i)
                next[String(raw[i])] = true;
        } else {
            const keys = control.keysOfValues(control.defaultValue);
            for (let i = 0; i < keys.length; ++i) {
                const anc = control.ancestorKeys(keys[i]);
                for (let j = 0; j < anc.length; ++j)
                    next[anc[j]] = true;
            }
        }
        control._expandedSet = next;
    }

    // 受控：显示值永远跟着 value（官方 getDerivedStateFromProps 的等价物）。
    // 多选 related 要把「子全选」的父补齐，显示才和官方 normalizeKeyList 对上。
    function syncFromValue() {
        const keys = control.keysOfValues(control.value);
        if (control.multiple) {
            if (control.related)
                control._checkedList = keys.length > 0 ? control.rebalanceAll(keys) : keys;
            else
                control._realList = keys;
        } else {
            control._selectedKeys = keys.length > 0 ? [keys[0]] : [];
        }
    }

    // treeData / keyMaps 变化：模型重建后 value→key 的映射可能变，受控要重同步；
    // 非受控且用户没动过时按 defaultValue 重播种。expandAll 还要重展开。
    function resyncAfterModelChange() {
        if (control.controlled)
            control.syncFromValue();
        else
            control.seedSelection();
        if (!control.isExpandControlled() && (control.expandAll || !control._seeded))
            control.seedExpansion();
        // 模型换了，展开视图的基线也得跟着换：下一次受控变更要拿它做 diff
        control.rememberExpanded();
    }

    Component.onCompleted: {
        // 建实例时 treeData 可能已经给了值，但 _m 还是那份空模型 —— 先重算，
        // _mChanged 会把播种/展开一次带出来
        control.rebuildModel();
        control._mounted = true;
        if (control.defaultOpen)
            popup.open();
    }

    onTreeDataChanged: control.rebuildModel()
    onKeyMapsChanged: control.rebuildModel()
    on_MChanged: control.resyncAfterModelChange()

    // 受控换 expandedKeys：官方在这一支算动画键（index.tsx:437-449 与搜索态那支 512-533）。
    // 「官方从 controlled 切回 uncontrolled（prop 变 undefined）时也会算一次 hide 动画」
    // 这一条病端口不跟：这里只在还是受控时才算，非受控的展开集由上一手自己维护。
    onExpandedKeysChanged: control.motionOnControlledChange()

    onValueChanged: {
        if (!control.isControlled())
            return;
        control.syncFromValue();
    }

    // ---------------------------------------------------------------- 外观令牌
    readonly property real lineHeight: Appearance.inputWrapperHeight(Theme.current, control.size)
    readonly property real minWidth: 80                     // $width-treeSelect_minWidth
    readonly property real suffixBox: Theme.current.spacingBase * 2   // 32，箭头/清除按钮同宽
    readonly property real padLeft: control.multiple
        ? Theme.current.spacingExtraTight                   // 多选 4
        : Appearance.inputPaddingHorizontal(Theme.current)  // 单选 12
    readonly property real searchRowHeight: control.dropdownSearch
        ? Theme.current.spacingTight * 2 + 32 + 1 : 0       // padding 8/8 + 输入框 32 + 1px 分隔
    readonly property real listRowHeight: 28
    readonly property real listPadding: Theme.current.spacingTight * 2   // 列表上下各 8
    readonly property real virtualHeight: {
        const h = control.pick(control.virtualize, "height", undefined);
        return typeof h === "number" ? h : control.visibleOptions.length * control.listRowHeight
            + control.listPadding;
    }
    readonly property real virtualWidth: {
        const w = control.pick(control.virtualize, "width", undefined);
        return typeof w === "number" ? w : popup.width;
    }
    readonly property int virtualItemSize: {
        const n = control.pick(control.virtualize, "itemSize", 28);
        return typeof n === "number" && n > 0 ? Math.floor(n) : 28;
    }
    readonly property int fieldState: Appearance.fieldState(control.interactive,
        control._hasFocus, control._hovering, false)
    readonly property color surfaceColor: control.borderless && control.validateStatus === Enums.StatusDefault
        ? "transparent"
        : Appearance.inputBackground(Theme.current, control.fieldState, control.validateStatus)
    readonly property color edgeColor: control.borderless && control.validateStatus === Enums.StatusDefault
        ? "transparent"
        : Appearance.inputBorderColor(Theme.current, control.fieldState, control.validateStatus)
    readonly property bool hasSelection: control.multiple
        ? control.displayKeys.length > 0 : control._selectedKeys.length > 0
    readonly property bool showClearBtn: control.showClear && (control.hasSelection
        || (control.triggerSearch && control._input !== ""))
        && control.interactive && (control.isOpen || control._hovering)
    readonly property var tagLabels: control.displayKeys.map(k => control.labelOfKey(k))
    readonly property var shownTags: control.maxTagCount > 0 && control.tagLabels.length > control.maxTagCount
        ? control.tagLabels.slice(0, control.maxTagCount) : control.tagLabels
    readonly property int restCount: control.maxTagCount > 0 && control.tagLabels.length > control.maxTagCount
        ? control.tagLabels.length - control.maxTagCount : 0
    readonly property var restLabels: control.maxTagCount > 0
        ? control.tagLabels.slice(control.maxTagCount) : []

    implicitWidth: 240
    // triggerTagWrap 时官方 .semi-treeselect 的 height: auto，由内部 TagInput 的行数撑起来
    // （treeSelect.scss:284-291）。只读 implicitHeight —— TagInput 的 height 是这里算出来的，
    // 读它会和自己绕成绑定环。
    implicitHeight: control.wrapped
        ? Math.max(control.lineHeight, tagField.implicitHeight) : control.lineHeight

    function open() {
        popup.open();
    }

    function close() {
        popup.close();
    }

    // 官方 .semi-treeselect-focus：焦点在触发器本身、还是在里面那个输入框，
    // 外层那圈 1px 都要在（DOM 里 input 是 div 的子节点，:focus-within 的等价物）。
    // 这个「或」只写一处 —— 两处各写一遍会漏改，漏掉的那半表现成「点了没描边」。
    function refreshFocus() {
        const on = trigger.activeFocus || control._fieldFocus;
        if (control._hasFocus === on)
            return;
        control._hasFocus = on;
        if (on)
            control.focused();
        else
            control.blurred();
    }

    function noteFieldFocus(on) {
        if (control._fieldFocus === on)
            return;
        control._fieldFocus = on;
        control.refreshFocus();
    }

    // 官方 handleTriggerFocus：搜索框在触发器时，焦点直接交给输入框
    function handleTriggerFocus() {
        if (control.triggerSearch) {
            if (control.multiple) {
                tagField.focusInput();
                return;
            }
            const host = singleSearchLoader.item;
            if (host !== null && host.focusField !== undefined) {
                host.focusField();
                return;
            }
        }
        trigger.forceActiveFocus();
    }

    // 官方 handleClick（foundation.ts:502-521）：点触发器先补一次焦点；没开就开；
    // 开着时「搜索框在触发器且已经有词」直接返回，否则按 clickTriggerToHide 收起。
    function handleTriggerClick() {
        if (!control.interactive)
            return;
        if (!control._hasFocus)
            control.handleTriggerFocus();
        if (control.isOpen) {
            if (control.triggerSearch && control._input !== "")
                return;
            if (control.clickTriggerToHide)
                control.close();
            return;
        }
        control.open();
    }

    // 官方 popup 关闭后清搜索态（handleAfterClose → clearInput）
    function afterClose() {
        if (control._input !== "")
            control.handleInputChange("");
        control._filteredKeySet = {};
        control._filteredExpandedSet = {};
        control._filteredShownSet = {};
        // 官方 foundation.close():496-501 —— 收起下拉时把动画键清空（motionExpand 开着才清）
        if (control.motionExpand)
            control._motionKeySet = ({});
    }

    // ================================================================ 指针位置
    // 弹层里那一行的底色/箭头变色看的是这里记下的指针位置，不看行自己那枚 HoverHandler：
    // 展开/收起动画起手和收尾各有一次 Repeater 重建（模型条目数变了），而新委托上的
    // HoverHandler 要等**下一个鼠标事件**才知道指针已经落在它里面 ⇒ 被点那一行的底色会
    // 掉一帧不亮，看起来就是闪烁。列表容器不是委托、不会跟着重建，位置一直有效；
    // 口径也和 CSS :hover 一致 —— 官方那条规则判的就是「指针在不在这块盒子里」。
    property point hoverPoint: Qt.point(-1, -1)
    property bool hoverInside: false
    readonly property var rowSpace: control.useVirtualList
        ? (virtualHost.item === null ? null : virtualHost.item.contentItem) : optionColumn

    function trackHover() {
        const space = control.rowSpace;
        if (space === null)
            return;
        const p = space.mapFromItem(null, listHover.point.scenePosition.x,
            listHover.point.scenePosition.y);
        control.hoverPoint = Qt.point(p.x, p.y);
    }

    // 测试用 seams
    readonly property var _trigger: trigger
    readonly property var _arrowBox: arrowBox
    readonly property var _clearBox: clearBox
    readonly property var _popup: popup
    readonly property var _restPop: restPopover
    readonly property var _tagField: tagField
    readonly property var _singleSearch: singleSearchLoader

    // 弹层里的代理对象走 QObject 树找不到（Popup 不是 Item，Repeater 的代理也不在
    // contentItem 的 QObject 子树里），所以按 Select.qml 的老办法留句柄 + 取行函数。
    // 计数与取行都按**真的建出来的行**算：动画组里每一条也是一行，
    // virtualize 那一档普通列表整批不建代理（模型被清空），所以按 optionRepeater 的格数走。
    function rowCount() {
        let n = 0;
        for (let i = 0; i < optionRepeater.count; ++i)
            n += control.entryLength(i);
        return n;
    }

    function rowAt(i) {
        // 委托项挂在 entryRefs 上（optionRepeater.itemAt 的静态类型是 QQuickItem，
        // 拿不到 delegate 自己声明的 rowAt）
        let n = 0;
        for (let k = 0; k < optionRepeater.count; ++k) {
            const len = control.entryLength(k);
            if (i < n + len) {
                const entry = control.entryRefs[k];
                return entry === undefined ? null : entry.rowAt(i - n);
            }
            n += len;
        }
        return null;
    }

    // 第 index 格（一整个动画组也算一格）对应的委托项
    function entryAt(index) {
        return control.entryRefs[index] === undefined ? null : control.entryRefs[index];
    }

    // 一格委托项 = 一行，或者一整个动画组；动画期间 entryCount 比 rowCount 少
    readonly property int entryCount: optionRepeater.count
    readonly property var motionMapView: control._motionKeySet
    readonly property string motionTypeView: control._motionType
    readonly property int motionDuration: 200     // nodeList.tsx:74 duration={200}
    property var entryRefs: []

    function virtualRowCount() {
        return virtualHost.item === null ? 0 : virtualHost.item.count;
    }

    function virtualRowAt(i) {
        // ListView 的 itemAt 是坐标版（要 x,y），按序号取要用 itemAtIndex
        return virtualHost.item === null ? null : virtualHost.item.itemAtIndex(i);
    }

    function tagAt(i) {
        return tagRepeater.itemAt(i);
    }

    function restTagAt(i) {
        return restRepeater.itemAt(i);
    }

    // ---------------------------------------------------------------- 触发器
    Rectangle {
        id: trigger

        objectName: "tsTrigger"
        anchors.fill: parent
        // 官方 triggerRender 接管时整块 .semi-treeselect 的边框/底色都没了
        visible: control.triggerRender === null
        radius: Theme.current.radiusSmall                   // $border-radius-treeSelect_trigger
        color: control.surfaceColor
        border.width: 1                                     // $width-treeSelect-border
        border.color: control.edgeColor

        readonly property real radiusSmallDefault: Theme.current.radiusSmall

        // 官方外层 div 带 tabIndex=0：Tab 能走到、点一下才聚焦，聚焦才有那 1px
        // focus 描边（.semi-treeselect-focus）。不要写 focus: true —— 那样刚建好
        // 实例就会抢到窗口焦点，rest 态直接顶着描边。
        activeFocusOnTab: control.interactive

        onActiveFocusChanged: control.refreshFocus()

        HoverHandler {
            id: triggerHover

            onHoveredChanged: control._hovering = triggerHover.hovered
        }

        TapHandler {
            onTapped: control.handleTriggerClick()
        }

        // 官方 insetLabel / prefix 都排在内容左边
        Text {
            id: insetLabelText

            objectName: "tsInsetLabel"
            visible: control.insetLabel !== ""
            anchors.left: parent.left
            anchors.leftMargin: Appearance.inputPaddingHorizontal(Theme.current)
            anchors.verticalCenter: parent.verticalCenter
            text: control.insetLabel
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeRegular
        }

        Icon {
            objectName: "tsPrefixIcon"
            visible: control.prefixIcon !== ""
            anchors.left: control.insetLabel === ""
                ? parent.left : insetLabelText.right
            anchors.leftMargin: Appearance.inputPaddingHorizontal(Theme.current)
            anchors.verticalCenter: parent.verticalCenter
            name: control.prefixIcon
            size: Theme.current.widthIconMedium
            color: Theme.current.colorText2
        }

        Icon {
            objectName: "tsSuffixIcon"
            visible: control.suffixIcon !== ""
            anchors.right: control.showClearBtn ? clearBox.left : arrowBox.left
            anchors.rightMargin: Theme.current.spacingTight
            anchors.verticalCenter: parent.verticalCenter
            name: control.suffixIcon
            size: Theme.current.widthIconMedium
            color: Theme.current.colorText2
        }

        // ---- 内容区：单选文本 / 单选触发搜索 / 多选标签 / 多选触发搜索 ----
        Item {
            id: contentHost

            objectName: "tsContent"
            anchors.left: parent.left
            anchors.leftMargin: control.padLeft
            anchors.right: control.showClearBtn ? clearBox.left : arrowBox.left
            anchors.rightMargin: Theme.current.spacingExtraTight
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height

            // 单选：文本（或 renderSelectedItem 钩子）
            Loader {
                id: singleHookLoader

                objectName: "tsSingleHook"
                active: !control.multiple && control.renderSelectedItem !== null
                    && control.hasSelection
                visible: active
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: control.renderSelectedItem
                onItemChanged: control.injectSingleHook(item)

                Binding {
                    target: singleHookLoader.item
                    when: singleHookLoader.item !== null
                    property: "modelData"
                    value: control._selectedKeys.length > 0
                        ? control._m.byKey[control._selectedKeys[0]] === undefined
                            ? {} : control._m.byKey[control._selectedKeys[0]].data
                        : {}
                }
            }

            Text {
                id: singleText

                objectName: "tsSingleText"
                visible: !control.multiple && !control.triggerSearch
                    && control.hasSelection && singleHookLoader.item === null
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, contentHost.width)
                text: control.labelOfKey(control._selectedKeys[0])
                color: Appearance.inputForeground(Theme.current, control.fieldState)
                font.pixelSize: control.size === Enums.Large
                    ? Theme.current.fontSizeHeader6 : Theme.current.fontSizeRegular
                elide: Text.ElideRight
            }

            // 官方 renderSelectContent：!multiple || !hasValue() 时渲染那一段文字，
            // 没值就是 placeholder（多选时 .semi-treeselect-selection-multiple
            // .semi-treeselect-selection-placeholder 再补 8 的左内边距，
            // 4 + 8 = 单选那 12 的同一个位置）
            Text {
                id: placeholderText

                objectName: "tsPlaceholderText"
                visible: !control.triggerSearch && !control.hasSelection
                x: control.multiple ? Theme.current.spacingTight : 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, contentHost.width - x)
                text: control.placeholder
                color: Appearance.inputPlaceholderColor(Theme.current, control.fieldState)
                font.pixelSize: control.size === Enums.Large
                    ? Theme.current.fontSizeHeader6 : Theme.current.fontSizeRegular
                elide: Text.ElideRight
            }

            // 多选：标签行（官方 TagGroup mode=custom + maxTagCount 的 +N）
            Row {
                id: tagRow

                objectName: "tsTagRow"
                visible: control.multiple && control.hasSelection && !control.triggerSearch
                // 官方每个 .semi-tag 带 margin: 1px 2px（treeSelect.scss:155-157），
                // 所以整行往右让 2，相邻两项之间是 2+2=4
                x: Theme.current.spacingSuperTight
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.current.spacingSuperTight * 2

                Repeater {
                    id: tagRepeater

                    model: control.shownTags

                    delegate: Loader {
                        id: tagCell

                        required property var modelData
                        required property int index

                        objectName: "tsTag" + index
                        sourceComponent: control.renderSelectedItem === null
                            ? plainTagComponent : control.renderSelectedItem
                        onItemChanged: control.injectTagItem(item, tagCell.index)

                        Binding {
                            target: tagCell.item
                            when: tagCell.item !== null
                            property: "modelData"
                            value: control._m.byKey[control.displayKeys[tagCell.index]] === undefined
                                ? {} : control._m.byKey[control.displayKeys[tagCell.index]].data
                        }

                        Binding {
                            target: tagCell.item
                            when: tagCell.item !== null
                            property: "index"
                            value: tagCell.index
                        }
                    }
                }

                // +N（官方 tag/group.tsx:41-49：color grey，size 取 TagGroup 上写的 large，
                // 和左边逐个标签「按控件尺寸取 small/large」不同档 —— 上游就这样）
                Tag {
                    id: restTag

                    objectName: "tsRestTag"
                    visible: control.restCount > 0
                    size: "large"
                    color: "grey"
                    text: "+" + control.restCount

                    HoverHandler {
                        id: restHover

                        onHoveredChanged: {
                            if (!control.showRestTagsPopover)
                                return;
                            if (restHover.hovered)
                                restPopover.open();
                            else
                                restPopover.close();
                        }
                    }
                }
            }

            // 多选 + 搜索框在触发器：官方直接嵌一个 TagInput（treeSelect.scss:208-211
            // 把它自己的框抹平，边框由 .semi-treeselect 出）
            TagInput {
                id: tagField

                objectName: "tsTagField"
                visible: control.multiple && control.triggerSearch
                anchors.fill: parent
                // 官方 .semi-treeselect-multiple-tagInput-{notEmpty,empty}：有值时整块
                // TagInput 往左挪 4（标签自己那 2 的左外边距补回来一点），空值时往右挪 4
                // —— 让光标落在与单选文字同一个位置（treeSelect.scss:246-257
                // + variables.scss:69-70，都是 $spacing-extra-tight）
                anchors.leftMargin: control._checkedKeys.length > 0
                    ? -Theme.current.spacingExtraTight : Theme.current.spacingExtraTight
                // .semi-treeselect-selection .semi-tag { margin: 1px 2px }（:155-157）
                tagMarginX: Theme.current.spacingSuperTight
                borderless: true
                size: control.size
                validateStatus: control.validateStatus
                placeholder: control.placeholder
                // 官方 value={triggerRenderKeys}，标签文字交给 renderTagItem 现算
                value: control.displayKeys
                inputValue: control._input
                maxTagCount: control.maxTagCount
                showRestTagsPopover: control.showRestTagsPopover
                restTagsPopoverProps: control.restTagsPopoverProps
                renderTagItem: tsKeyTagComponent
                draggable: false
                expandRestTagsOnClick: false
                showClear: false
                enabled: control.interactive
                onRemove: (tag, index) => {
                    if (tag !== undefined && tag !== null)
                        control.removeAt(String(tag));
                }
                onInputChange: (text) => control.handleInputChange(text)
                onFocused: control.noteFieldFocus(true)
                onBlurred: control.noteFieldFocus(false)
            }

            // 点这圈 TagInput 时按下被它自己吃掉，外层 TapHandler 收不到（实测父级
            // TapHandler 永远输给子 TextInput）。官方靠 DOM 的 click 冒泡到
            // .semi-treeselect 才开的下拉 —— 这里用一层「按下即放行」的 MouseArea
            // 补上同一次点击：它看得见，但不抢（mouse.accepted = false，
            // 光标语义、标签上的关闭按钮都照常工作）。
            MouseArea {
                objectName: "tsTagFieldClickPass"
                anchors.fill: parent
                visible: control.multiple && control.triggerSearch
                enabled: visible
                propagateComposedEvents: true
                onPressed: (mouse) => {
                    control.handleTriggerClick();
                    mouse.accepted = false;
                }
                onReleased: (mouse) => mouse.accepted = false
            }

            // 单选 + 搜索框在触发器：一个透明输入框，占位由 placeholder 控制
            Loader {
                id: singleSearchLoader

                objectName: "tsSingleSearch"
                active: !control.multiple && control.triggerSearch
                visible: active
                anchors.fill: parent
                sourceComponent: singleTriggerSearchComponent
            }
        }

        // 箭头：官方平时就在，清除按钮出现时整块让位（renderArrow 直接返回 null）
        Item {
            id: arrowBox

            objectName: "tsArrowBox"
            width: control.suffixBox
            height: parent.height
            anchors.right: parent.right
            visible: !control.showClearBtn

            Icon {
                anchors.centerIn: parent
                name: "chevron_down"
                size: Theme.current.widthIconMedium
                color: control.interactive
                    ? Theme.current.colorText2 : Theme.current.colorDisabledText
            }
        }

        Item {
            id: clearBox

            objectName: "tsClearBox"
            width: control.suffixBox
            height: parent.height
            anchors.right: parent.right
            visible: control.showClearBtn

            Icon {
                anchors.centerIn: parent
                name: "clear"
                size: Theme.current.widthIconMedium
                color: clearPress.pressed
                    ? Theme.current.colorPrimaryActive
                    : (clearHover.hovered ? Theme.current.colorPrimaryHover : Theme.current.colorText2)

                HoverHandler {
                    id: clearHover
                }

                TapHandler {
                    id: clearPress

                    onTapped: control.clearAll()
                }
            }
        }
    }

    // ---------------------------------------------------------------- 弹层
    PopupBase {
        id: popup

        objectName: "tsPopup"
        anchor: trigger
        // 官方那套 clickOutside 认 reference（触发器），Controls 的 CloseOnPressOutside
        // 不认 —— 点触发器会先被收掉、再被我们的点击处理开回来，搜索词还会被
        // afterClose 清掉。所以这里换成自己盯落点（见 outsideShell）。
        dismissOnOutsidePress: false
        placement: Enums.BottomLeft
        gap: 4
        fillColor: Theme.current.colorBg3
        radius: Theme.current.radiusMedium
        padding: 0
        contentSpacing: 0

        implicitWidth: Math.max(control.dropdownMatchSelectWidth ? control.width : 0,
            230)                                        // $width-tree_list-min-width
        implicitHeight: control.searchRowHeight + popup.listBlockHeight
            + topSlotLoader.implicitHeight + bottomSlotLoader.implicitHeight

        // .semi-tree 的一屏高度：官方没有 max-height（300px 那条是死 CSS），
        // 列表按渲染出来的内容长（动画那一组正在收/展的高度也算），
        // virtualize 打开时按 virtualize.height
        readonly property real listBlockHeight: control.useVirtualList
            ? control.virtualHeight
            : (control.noData ? control.listRowHeight + control.listPadding
                : optionColumn.height + control.listPadding)

        onIsOpenChanged: {
            control.visibleChange(popup.isOpen);
            if (popup.isOpen) {
                if (control.dropdownSearch && control.searchAutoFocus)
                    dropInput.input.forceActiveFocus();
            } else {
                control.afterClose();
            }
        }

        Item {
            objectName: "tsTopSlotHost"
            visible: control.outerTopSlot !== null
            width: popup.width
            height: control.outerTopSlot !== null ? topSlotLoader.implicitHeight : 0

            Loader {
                id: topSlotLoader

                objectName: "tsTopSlot"
                active: control.outerTopSlot !== null
                sourceComponent: control.outerTopSlot
            }
        }

        // 搜索框（searchPosition: dropdown，官方在 .semi-tree-search-wrapper 里）
        Item {
            objectName: "tsSearchHost"
            visible: control.dropdownSearch
            width: popup.width
            height: control.searchRowHeight

            Input {
                id: dropInput

                objectName: "tsDropInput"
                x: Theme.current.spacingTight
                y: Theme.current.spacingTight
                width: Math.max(0, popup.width - Theme.current.spacingTight * 2)
                height: 32
                placeholderText: control.searchPlaceholder !== ""
                    ? control.searchPlaceholder : qsTr("搜索")
                prefixIcon: "search"
                showClear: control.showSearchClear
                enabled: control.interactive
                onTextChanged: {
                    if (text !== control._input)
                        control.handleInputChange(text);
                }
            }

            // 官方 .semi-tree-search-wrapper 的 border-bottom: 1px fill-0
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                visible: control.dropdownSearch
                color: Theme.current.colorFill0
            }

            Binding {
                target: dropInput
                property: "text"
                value: control._input
                restoreMode: Binding.RestoreBindingOrValue
            }
        }

        // 选项列表
        Item {
            id: tsListHost

            objectName: "tsListHost"
            width: popup.width
            height: control.useVirtualList ? control.virtualHeight : popup.listBlockHeight

            // 指针位置记在这个不会被重建的容器项上（为什么不用行上的 HoverHandler，
            // 见 hoverPoint 的注释）
            HoverHandler {
                id: listHover

                onPointChanged: control.trackHover()
                onHoveredChanged: control.hoverInside = listHover.hovered
            }

            Flickable {
                id: scroller

                objectName: "tsScroller"
                visible: !control.useVirtualList
                width: parent.width
                height: parent.height
                contentWidth: width
                contentHeight: optionColumn.height
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: optionColumn

                    objectName: "tsOptionList"
                    width: scroller.width
                    y: Theme.current.spacingTight          // 列表 padding 8px 0

                    Repeater {
                        id: optionRepeater

                        // 官方 virtualize 是整块换成 VirtualList。这里不换容器
                        // （换 Loader 会让 rowAt() 的句柄跨不进 Component），
                        // 只把模型清空 —— 一千个节点不至于建两份代理。
                        model: control.useVirtualList ? [] : control.renderOptions

                        delegate: Item {
                            id: entry

                            required property int index

                            objectName: "tsEntry" + index

                            Component.onCompleted: {
                                control.entryRefs[index] = entry;
                            }

                            onIndexChanged: control.entryRefs[index] = entry

                            width: optionColumn.width
                            height: entry.isGroup ? motionBox.height : plainRow.height

                            readonly property bool isGroup: control.entryIsGroup(index)

                            // 测试用：动画那一段的**实际渲染值**（委托自己声明的属性格子外取不到）
                            readonly property real boxHeight: motionBox.height
                            readonly property real boxOpacity: motionBox.opacity
                            readonly property real boxFull: motionColumn.implicitHeight
                            // 两条动画本体：采中间帧在机器压满时会假红（坑 52），
                            // 所以接线（property / from / to / duration）直接从动画对象上读
                            readonly property var anim: heightAnim
                            readonly property var fade: fadeAnim

                            // 普通行
                            TreeSelectOption {
                                id: plainRow

                                objectName: "tsRow" + index
                                visible: !entry.isGroup
                                ts: control
                                rec: control.entryRow(index, 0) || ({})
                                rowIndex: control.entryStartRow(index)
                                width: optionColumn.width
                                originInColumn: entry.y
                            }

                            // 展开动画那一段（nodeList.tsx:71-81 里被 NodeCollapsible 包住的那组）
                            Item {
                                id: motionBox

                                visible: entry.isGroup
                                width: entry.width
                                height: motionBox.animHeight
                                opacity: motionBox.animOpacity
                                clip: true

                                // 起手值在**建立那一拍**就要摆对：收起那一手官方挂载那帧带的就是
                                // domHeight（nodeCollapsible.tsx:15-23 的 setTimeout 只翻 isOpen），
                                // 留到 start() 再写会让弹层先闪一帧 0 高。
                                // 行数 × 行高是式子值（行高固定 28），不依赖 motionColumn 排好版；
                                // 动画一开始写这两个属性，这两条绑定就自然断掉。
                                property real animHeight: control._motionType === "hide"
                                    ? control.entryLength(entry.index) * control.listRowHeight : 0
                                property real animOpacity: control._motionType === "hide" ? 1 : 0

                                function start() {
                                    const full = motionColumn.implicitHeight;
                                    const hiding = control._motionType === "hide";
                                    // 这一笔管的是「同一委托被复用的下一手」—— 动画写过属性之后
                                    // 上面那两条初始绑定就断了，残留可能是上一手的终点
                                    motionBox.animHeight = hiding ? full : 0;
                                    motionBox.animOpacity = hiding ? 1 : 0;
                                    heightAnim.from = hiding ? full : 0;
                                    heightAnim.to = hiding ? 0 : full;
                                    fadeAnim.from = hiding ? 1 : 0;
                                    fadeAnim.to = hiding ? 0 : 1;
                                    heightAnim.start();
                                    fadeAnim.start();
                                }

                                NumberAnimation {
                                    id: heightAnim

                                    target: motionBox
                                    property: "animHeight"
                                    duration: control.motionDuration
                                    easing.type: Easing.InOutQuad
                                    // 官方 onMotionEnd 只把 transitionNodes 清空
                                    onStopped: control.endMotion()
                                }

                                NumberAnimation {
                                    id: fadeAnim

                                    target: motionBox
                                    property: "animOpacity"
                                    duration: control.motionDuration
                                    easing.type: Easing.InQuad
                                }

                                Column {
                                    id: motionColumn

                                    width: motionBox.width
                                    spacing: 0

                                    Repeater {
                                        id: motionRepeater

                                        // 模型的条目直接给那一组行记录：内层代理里再回头读
                                        // entry.xxx 会在外层委托被延后销毁时撞上 null
                                        // （实测 QWARN "Cannot read property 'index' of null"）
                                        model: entry.isGroup ? control.renderOptions[entry.index] : []

                                        delegate: TreeSelectOption {
                                            objectName: "tsMotionRow"

                                            required property var modelData
                                            required property int index

                                            ts: control
                                            rec: modelData
                                            // 行内那些 objectName 的后缀留给普通行按行号编，
                                            // 组里的行另起一段，测试不看它们
                                            rowIndex: 1000 + index
                                            width: parent === null ? 0 : parent.width
                                            originInColumn: entry.y + motionBox.y
                                                + motionColumn.y + y
                                            // 动画盒是 clip 的：被它裁掉的那截指针落上去不算悬停
                                            clipBottom: entry.y + motionBox.y + motionBox.height
                                        }
                                    }
                                }
                            }

                            // 动画起手：_motionSeq 变一次重放一次（官方靠 key 换了重挂
                            // NodeCollapsible）。新建的组不用在 onCompleted 里补一手：
                            // renderOptions 是在写展开集那一刻就重挂委托项的，
                            // 等 beginMotion 推进 _motionSeq 时它已经在这儿了（同 Tree.qml:1716）
                            property int seqStamp: control._motionSeq
                            onSeqStampChanged: {
                                if (entry.isGroup)
                                    kick.restart();
                            }

                            Timer {
                                id: kick

                                interval: 0
                                repeat: false
                                onTriggered: motionBox.start()
                            }

                            function rowAt(inner) {
                                if (entry.isGroup)
                                    return motionRepeater.itemAt(inner);
                                return inner > 0 ? null : plainRow;
                            }
                        }
                    }
                }
            }

            // 空态：官方是一条 .semi-tree-option-empty，不参与 hover 变色
            Text {
                objectName: "tsEmpty"
                visible: control.noData && control.emptyText !== ""
                width: parent.width
                height: control.listRowHeight
                y: Theme.current.spacingTight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: control.emptyText
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeRegular
            }

            // virtualize：官方换成 VirtualList（展开动画一并没了），QML 的等价物是 ListView
            Loader {
                id: virtualHost

                objectName: "tsVirtualHost"
                active: control.useVirtualList
                visible: active
                width: control.virtualWidth
                height: control.virtualHeight
                sourceComponent: virtualListComponent
            }
        }

        Item {
            objectName: "tsBottomSlotHost"
            visible: control.outerBottomSlot !== null
            width: popup.width
            height: control.outerBottomSlot !== null ? bottomSlotLoader.implicitHeight : 0

            Loader {
                id: bottomSlotLoader

                objectName: "tsBottomSlot"
                active: control.outerBottomSlot !== null
                sourceComponent: control.outerBottomSlot
            }
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }
    }

    // 点到「触发器与弹层之外」才收起 —— 官方那套 clickOutside 把触发器算作 reference。
    // 壳子每实例一个、parent 各不相同，才躲开 PointHandler 的同父查重（坑 79）。
    Item {
        id: outsideShell

        objectName: "tsOutsideShell"
        parent: control.Window.contentItem
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        enabled: popup.isOpen

        PointHandler {
            id: outsidePress

            onActiveChanged: {
                if (active || !popup.isOpen)
                    return;
                const p = outsidePress.point.position;
                const t0 = trigger.mapToItem(outsideShell, 0, 0);
                if (p.x >= t0.x && p.x <= t0.x + trigger.width
                    && p.y >= t0.y && p.y <= t0.y + trigger.height)
                    return;
                const host = popup.parent;
                if (host !== null) {
                    const o = host.mapToItem(outsideShell, popup.x, popup.y);
                    if (p.x >= o.x && p.x <= o.x + popup.width
                        && p.y >= o.y && p.y <= o.y + popup.height)
                        return;
                }
                control.close();
            }
        }
    }

    Component {
        id: virtualListComponent

        ListView {
            id: virtualList

            objectName: "tsVirtualList"
            width: control.virtualWidth
            height: control.virtualHeight
            model: control.visibleOptions
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: contentHeight > height

            delegate: TreeSelectOption {
                id: virtualRow

                required property var modelData
                required property int index

                objectName: "tsVirtualRow" + index
                ts: control
                rec: modelData
                rowIndex: index
                width: virtualList.width
                height: control.virtualItemSize
                originInColumn: y
            }
        }
    }

    // +N 的剩余标签浮层（官方 showRestTagsPopover + restTagsPopoverProps）
    PopupBase {
        id: restPopover

        objectName: "tsRestPopover"
        anchor: restTag
        placement: control.restTagsPopoverProps
            && control.restTagsPopoverProps.position
            ? control.placementOf(control.restTagsPopoverProps.position) : Enums.Top
        gap: 4
        padding: Theme.current.spacingExtraTight
        implicitWidth: restRestList.implicitWidth + Theme.current.spacingExtraTight * 2
        implicitHeight: restRestList.implicitHeight + Theme.current.spacingExtraTight * 2

        Column {
            id: restRestList

            objectName: "tsRestList"
            spacing: Theme.current.spacingExtraTight

            Repeater {
                id: restRepeater

                model: control.restLabels

                delegate: Tag {
                    required property var modelData

                    objectName: "tsRestItem"
                    size: control.size === Enums.Small ? "small" : "large"
                    color: "white"
                    text: String(modelData)
                }
            }
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }
    }

    // 默认的多选标签（官方 isRenderInTag=true 那条路径）
    Component {
        id: plainTagComponent

        Tag {
            id: plainTag

            property var modelData: ({})
            property int index: -1
            property var remove: null

            objectName: "tsPlainTag"
            size: control.size === Enums.Small ? "small" : "large"
            color: "white"
            // 官方 treeSelect/index.tsx:913 传 visible: true —— 标签的去留由
            // selection 那一份数据说了算，叉掉之后 delegate 还会复用
            visible: true
            closable: plainTag.modelData !== undefined && plainTag.modelData !== null
                && plainTag.modelData.disabled !== true && control.interactive
            text: String(plainTag.modelData === undefined || plainTag.modelData === null
                ? "" : (plainTag.modelData.label === undefined ? "" : plainTag.modelData.label))
            maxWidth: contentHost.width

            onClosed: {
                if (plainTag.remove !== null)
                    plainTag.remove();
            }
        }
    }

    // 嵌在触发器里的 TagInput 用这个把 key 翻成标签（官方 renderTagItem，
    // index.tsx:1200-1250：value 传的是 key 列表，文字要现算）
    Component {
        id: tsKeyTagComponent

        Tag {
            id: keyTag

            property var modelData: undefined
            property int index: -1
            property var closeTag: null

            objectName: "tsKeyTag"
            size: control.size === Enums.Small ? "small" : "large"
            color: "white"
            visible: true
            closable: control.interactive
                && !control.isNodeDisabled(String(keyTag.modelData))
            text: control.labelOfKey(String(keyTag.modelData))
            maxWidth: contentHost.width

            onClosed: {
                if (keyTag.closeTag !== null)
                    keyTag.closeTag();
            }
        }
    }

    // 单选 + 触发器搜索：一个透明输入框压在内容上（官方 renderSingleTriggerSearch）
    Component {
        id: singleTriggerSearchComponent

        Item {
            id: singleSearchHost

            property var ts: control

            anchors.fill: parent

            function focusField() {
                singleSearchInput.forceActiveFocus();
            }

            // 官方这里不是带框的 Input：treeSelect.scss:183-205 把
            // .semi-input-wrapper 的 border 覆盖成 none（连 -focus 也是 none）、
            // 底色 transparent、.semi-input 左右 padding 归零，焦点环由外层
            // .semi-treeselect 出。所以用裸 TextInput，那圈 1px 才不会只包住输入区。
            TextInput {
                id: singleSearchInput

                objectName: "tsSingleSearchInput"
                anchors.fill: parent
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                selectByMouse: true
                enabled: singleSearchHost.ts.interactive
                onActiveFocusChanged: singleSearchHost.ts.noteFieldFocus(activeFocus)
                onTextChanged: {
                    if (text !== singleSearchHost.ts._input)
                        singleSearchHost.ts.handleInputChange(text);
                }
            }

            Text {
                objectName: "tsSingleSearchOverlay"
                visible: singleSearchHost.ts._input === ""
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width)
                text: singleSearchHost.ts._selectedKeys.length > 0
                    ? singleSearchHost.ts.labelOfKey(singleSearchHost.ts._selectedKeys[0])
                    : singleSearchHost.ts.placeholder
                color: singleSearchHost.ts._selectedKeys.length > 0
                    ? Theme.current.colorText0 : Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeRegular
                elide: Text.ElideRight
            }

            Binding {
                target: singleSearchInput
                property: "text"
                value: singleSearchHost.ts._input
                restoreMode: Binding.RestoreBindingOrValue
            }

            // 同多选那层：按下放行给输入框（光标照常落点），但这一次点击要冒到
            // 触发器的开关逻辑上（官方是 DOM 的 click 冒泡）
            MouseArea {
                objectName: "tsSingleSearchClickPass"
                anchors.fill: parent
                propagateComposedEvents: true
                onPressed: (mouse) => {
                    singleSearchHost.ts.handleTriggerClick();
                    mouse.accepted = false;
                }
                onReleased: (mouse) => mouse.accepted = false
            }
        }
    }

    // ---------------------------------------------------------------- 钩子注入
    // 函数入参只能直接赋值（Binding 的 value 给函数会报错，见 Transfer 同款注释）
    function injectSingleHook(item) {
        if (item === null)
            return;
        item.remove = function () { control.clearAll(); };
    }

    function injectTagItem(item, index) {
        if (item === null)
            return;
        item.remove = function () {
            const key = control.displayKeys[index];
            if (key !== undefined)
                control.removeAt(key);
        };
    }

    // 触发器被接管时（triggerRender）：官方 inner 只剩 <Trigger>，边框/箭头/清除都没了，
    // 但外层 div 上的 onClick=handleClick 还在 —— 点自定义节点照样开关下拉。
    Loader {
        id: triggerHookLoader

        objectName: "tsTriggerHook"
        active: control.triggerRender !== null
        visible: active
        anchors.fill: parent
        sourceComponent: control.triggerRender
        onItemChanged: control.injectTriggerHook(item)

        TapHandler {
            enabled: control.interactive
            onTapped: {
                if (control.isOpen)
                    control.close();
                else
                    control.open();
            }
        }

        Binding {
            target: triggerHookLoader.item
            when: triggerHookLoader.item !== null
            property: "value"
            value: control.displayKeys.map(k => control._m.byKey[k] === undefined
                ? {} : control._m.byKey[k].data)
        }

        Binding {
            target: triggerHookLoader.item
            when: triggerHookLoader.item !== null
            property: "inputValue"
            value: control._input
        }

        Binding {
            target: triggerHookLoader.item
            when: triggerHookLoader.item !== null
            property: "placeholder"
            value: control.placeholder
        }

        Binding {
            target: triggerHookLoader.item
            when: triggerHookLoader.item !== null
            property: "disabled"
            value: !control.interactive
        }
    }

    function injectTriggerHook(item) {
        if (item === null)
            return;
        item.search = function (text) { control.handleInputChange(String(text)); };
        item.clear = function () { control.clearAll(); };
        item.remove = function (key) { control.removeAt(key); };
    }
}
