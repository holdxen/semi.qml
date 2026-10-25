pragma ComponentBehavior: Bound

import QtQuick
import "TreeEngine.js" as Engine

// 树形控件。对应 semi-ui/tree（index.tsx + treeNode.tsx + nodeList.tsx + indent.tsx）
// 与 semi-foundation/tree（foundation.ts + treeUtil.ts + tree.scss）。
//
//     Tree {
//         treeData: [{ key: "0", label: "亚洲", value: "Asia",
//                       children: [{ key: "0-0", label: "中国", value: "China" }] }]
//         defaultExpandAll
//         onChange: (v) => ...
//     }
//
// 身份用 **key**（不是 value）：官方所有状态集合都按 key 存，value 只在进出 onChange /
// value / defaultValue 时通过 valueEntities 换成 key（treeUtil.ts:199-224）。
//
// ---------------------------------------------------------------- 与官方的口径差异（逐条有测试盯着）
//   · 官方回调 → 信号：onChange→change、onSelect→select、onExpand→expand、onSearch→search、
//     onDoubleClick→doubleClick、onContextMenu→contextMenu、onLoad→load、
//     onDragStart/Enter/Over/Leave/End/Drop→dragStart/…/drop。
//   · 官方每个回调第一个入参是 React 事件对象（MouseEvent / DragEvent），QML 没有对应物，
//     一律不带。onDrop 的 dropPosition / dropToGap / dragNodesKeys 改成平铺的普通入参。
//   · 实例方法 search(value) 与 onSearch 在 React 里不冲突，在 QML 里信号与函数不能同名：
//     方法叫 **searchBy**（同 TreeSelect）。scrollTo({key, align}) 保持原名。
//   · 官方用 `'value' in props` 判受控；QML 没有这个概念，按仓库惯例 value /
//     expandedKeys / loadedKeys 为 undefined 或 null 即非受控。
//   · DOM / CSS 类 prop 不进 QML：className、style、searchClassName、searchStyle、
//     preventScroll，以及拖拽影像那两条 hideDraggingNode / renderDraggingNode
//     （官方是在 document.body 上挂一个克隆节点喂给 dataTransfer.setDragImage，
//     Qt 的拖拽没有「拖拽影像」这个概念）。
//   · `children`（JSX 子节点 / Tree.TreeNode）：TreeProps 里声明了，index.tsx 的 render
//     从来不读它（只读 flattenNodes）⇒ 上游自己就是死 prop，端口不收。
//   · `active`（`-option-active` 那条类）不在 TreeProps 里，getTreeNodeProps 也不产出它，
//     只有 TreeSelect 的目录树会往里传 ⇒ standalone Tree 渲染不到，端口不做。
//   · loadData 官方返回 Promise，QML 没有 Promise：签名改成 `loadData(node, done)`，
//     数据取回来后调用 done()。
//   · calcDropRelativePosition 官方读 event.clientY 与 getBoundingClientRect()，
//     端口改成 (clientY, top, height) 三个数字，判定式与 DRAG_OFFSET=0.45 原样。
//   · 拖拽 over 时官方用 lodash throttle(16ms) 合批更新 dropPosition；Qt 的指针事件
//     本来就是每帧一次，端口直接同步写，渲染结果一致。
//   · delayedDragEnterLogic 官方是一张按 pos 索引的定时器表，但每次进入前会把**所有**
//     待发定时器清掉 ⇒ 等价于只有一支在跑，端口就只留一支。
//   · 官方 Spin 的 12px 是靠 CSS 压 svg 的宽高，本库 Spin 最小档 14 ⇒ 用 scale 补到 12。
//   · keyMaps 单独改动（treeData 引用不变）时官方不会重建 entities，端口按绑定重算 ——
//     只在运行时改 keyMaps 才有差别，那种用法官方本来也没保证。
//   · 搜索框占位文字取 locale（zh_CN 是「搜索」），空态文案取 locale（「暂无数据」）。
//   · showFilteredOnly=false 且搜索无命中时，官方不是空白也不是空态：
//     filteredExpandedKeys 是空集 ⇒ 所有根节点收起着展示。这条照抄。
//   · 官方 `disabledKeys`（严格禁用）走 calcCheckedKeys 的补集，会把「孩子全禁用」的
//     父节点也标成禁用（treeUtil.ts:645-650）⇒ 官方 demo「禁用」那一节里「中国」
//     自己没写 disabled 也一样是灰的。这是上游口径，端口照抄（TreeSelect 那版是
//     故意不抄的，换内核时再并）。
Item {
    id: control

    // ================================================================ 官方属性面
    // ---- 数据
    property var treeData: []
    property var treeDataSimpleJson: undefined
    property var keyMaps: ({})                  // { key, label, value, children, disabled, isLeaf, icon }

    // ---- 选区
    property var value: undefined               // 受控：单选是标量/节点，多选是数组
    property var defaultValue: undefined
    property bool multiple: false
    property string checkRelation: "related"    // "related" | "unRelated"
    property bool leafOnly: false
    property bool autoMergeValue: true
    property bool onChangeWithObject: false
    property bool disabled: false               // 禁用整棵树
    property bool disableStrictly: false

    // ---- 展开
    property bool defaultExpandAll: false
    property bool expandAll: false
    property var defaultExpandedKeys: undefined
    property var expandedKeys: undefined        // 受控
    property bool autoExpandParent: false

    // ---- 外观
    property bool blockNode: true
    property bool showLine: false
    property bool motion: true
    property bool directory: false
    property var icon: undefined                // ReactNode：图标名 / Component / function(rowProps)
    property var expandIcon: undefined          // 同上
    property var labelEllipsis: undefined       // 缺省跟虚拟化
    property var emptyContent: undefined
    property string ariaLabel: ""

    // ---- 搜索
    property var filterTreeNode: false          // false | true | function(input, target, data)
    property string treeNodeFilterProp: "label"
    property bool showFilteredOnly: false
    property bool showClear: true
    property string searchPlaceholder: ""
    property var searchRender: undefined        // false = 藏搜索框；Component = 自定义

    // ---- 展开逻辑（false | "click" | "doubleClick"）
    property var expandAction: false

    // ---- 异步加载
    property var loadData: null                 // function (node, done)
    property var loadedKeys: undefined

    // ---- 拖拽
    property bool draggable: false
    property bool autoExpandWhenDragEnter: true

    // ---- 虚拟化
    property var virtualize: ({})               // { itemSize, height, width }

    // ---- 钩子（根项声明的普通属性由本组件注入）
    property Component renderLabel: null
    property Component renderFullLabel: null
    readonly property Component renderLabelComp: control.renderLabel

    // ================================================================ 官方回调
    signal change(var value)
    signal select(string selectedKey, bool selected, var selectedNode)
    signal expand(var expandedKeys, var info)
    signal search(string input, var filteredExpandedKeys)
    signal doubleClick(var node)
    signal contextMenu(var node)
    signal load(var loadedKeys, var node)
    signal dragStart(var node)
    signal dragEnter(var node, var expandedKeys)
    signal dragOver(var node)
    signal dragLeave(var node)
    signal dragEnd(var node)
    signal drop(var node, var dragNode, var dragNodesKeys, int dropPosition, bool dropToGap)

    // ================================================================ 内部状态
    // 对应 BasicTreeInnerData：官方那堆 Set 在这里都是 `{ key: true }` 的普通对象
    property var _expandedSet: ({})
    property var _prevExpandedSet: ({})
    property var _selectedKeys: []
    property var _checkedSet: ({})
    property var _halfSet: ({})
    property var _realSet: ({})
    property var _filteredKeySet: ({})
    property var _filteredExpandedSet: ({})
    property var _filteredShownSet: ({})
    property var _loadedSet: ({})
    property var _loadingSet: ({})
    property var _disabledSet: ({})
    property var _motionKeySet: ({})
    property string _motionType: "hide"         // 官方 state 初值就是 'hide'
    property bool _motionRunning: false
    property int _motionSeq: 0
    property var _cachedFlatten: undefined
    property string _input: ""
    // 拖拽：dragging / dragNodesKeys / dragOverNodeKey / dropPosition + 实例字段 dragNode
    property bool _dragging: false
    property var _dragNodesSet: ({})
    property string _dragOverKey: ""
    property var _dropPosition: null
    property string _dragSourceKey: ""
    property string _lastDragKey: ""
    property string _pendingSourceKey: ""
    property bool _dragHasPoint: false
    property real _dragLocalY: -1
    property bool _mounted: false
    property bool _hadData: false
    // expandAction='doubleClick' 时 onClick 走 500ms leading 防抖（treeNode.tsx:55-58）
    property bool _clickGateOpen: true

    // ================================================================ 数据管线
    readonly property bool jsonMode: control.treeDataSimpleJson !== undefined
        && control.treeDataSimpleJson !== null
    // 官方 gDSFP：treeData 引用变化优先，其次 treeDataSimpleJson
    readonly property var sourceData: control.jsonMode
        ? Engine.convertJsonToData(control.treeDataSimpleJson) : control.treeData
    readonly property var _entityMap: Engine.convertDataToEntities(control.sourceData, control.keyMaps)
    readonly property var _keyEntities: control._entityMap.keyEntities
    readonly property var _valueEntities: control._entityMap.valueEntities

    // 行渲染读 isSearching = Boolean(inputValue)，而 gDSFP 重算 flatten 时多一个
    // filterTreeNode 门槛 —— 官方这两套口径本来就不一样
    readonly property bool isSearching: control._input !== ""
    readonly property bool dataSearching: control.truthy(control.filterTreeNode) && control._input !== ""
    readonly property bool filteredOnlyActive: control._input !== "" && control.showFilteredOnly

    readonly property var flattenNodes: control.buildFlatten()
    readonly property var rows: control.makeRows(control.flattenNodes)
    readonly property var cachedRows: control._cachedFlatten === undefined
        ? [] : control.makeRows(control._cachedFlatten)
    // NodeList 那一段：非虚拟化时把动画区间套成子数组，虚拟化时原样
    readonly property var renderRows: control.buildRenderRows()

    readonly property bool useVirtualList: Engine.isPlainObject(control.virtualize)
    readonly property bool renderFullLabelOn: control.renderFullLabel !== null
    // 官方 disabledKeys 只算一次，且门槛是 checkRelation === 'related'
    readonly property bool strictDisabled: control.disableStrictly && control.checkRelation === "related"
    readonly property bool controlled: control.value !== undefined && control.value !== null
    readonly property bool expandControlled: control.expandedKeys !== undefined
        && control.expandedKeys !== null
    readonly property bool loadControlled: control.loadedKeys !== undefined
        && control.loadedKeys !== null
    readonly property bool labelEllipsisOn: control.labelEllipsis === undefined
        || control.labelEllipsis === null
        ? control.useVirtualList : control.labelEllipsis === true

    function truthy(val) {
        return !(val === false || val === undefined || val === null || val === "");
    }

    function rowOption() {
        return {
            checkRelation: control.checkRelation,
            treeNodeFilterProp: control.treeNodeFilterProp,
            disableStrictly: control.disableStrictly,
        };
    }

    function rowState() {
        return {
            keyEntities: control._keyEntities,
            expandedKeys: control._expandedSet,
            selectedKeys: control._selectedKeys,
            checkedKeys: control._checkedSet,
            halfCheckedKeys: control._halfSet,
            realCheckedKeys: control._realSet,
            filteredKeys: control._filteredKeySet,
            filteredExpandedKeys: control._filteredExpandedSet,
            loadingKeys: control._loadingSet,
            loadedKeys: control._loadedSet,
            disabledKeys: control._disabledSet,
            inputValue: control._input,
            isSearching: control.isSearching,
        };
    }

    function propsOf(key) {
        return Engine.treeNodeProps(key, control.rowState(), control.rowOption());
    }

    function dataOf(key) {
        const entity = control._keyEntities[key];
        return entity === undefined ? null : entity.data;
    }

    function buildFlatten() {
        if (control.dataSearching) {
            return Engine.flattenTreeData(control.sourceData, control._filteredExpandedSet,
                control.keyMaps,
                control.showFilteredOnly ? control._filteredShownSet : false);
        }
        return Engine.flattenTreeData(control.sourceData, control._expandedSet, control.keyMaps);
    }

    function buildRenderRows() {
        if (control.useVirtualList || !control.motion || !control._motionRunning)
            return control.rows;
        if (Object.keys(control._motionKeySet).length === 0)
            return control.rows;
        return Engine.buildTransitionNodes(control.rows, control._motionKeySet,
            control._motionType, control.cachedRows);
    }

    // 一行的渲染数据：treeNodeProps + flatten 节点那几个字段，按官方
    // `{...treeNodeProps} {...data} {...props}` 的覆盖顺序（props 是 flatten pick 出来的）
    function makeRows(list) {
        const out = [];
        if (list === undefined || list === null)
            return out;
        const s = control.rowState();
        const opt = control.rowOption();
        const childrenName = Engine.realName(control.keyMaps, "children");
        for (let i = 0; i < list.length; ++i) {
            const node = list[i];
            const p = Engine.treeNodeProps(node.key, s, opt);
            if (p === null)
                continue;                       // 官方 renderTreeNode 此时返回 null
            const data = node.data;
            const kids = data[childrenName];
            const hasChildren = kids !== undefined && kids !== null && kids.length > 0;
            const leafProp = node.isLeaf;
            let isLeaf = false;
            if (leafProp !== false) {
                isLeaf = (leafProp === true)
                    || (control.loadData === null && !hasChildren)
                    || (control.loadData !== null && p.loaded && !hasChildren);
            }
            // disabled：flatten pick 优先（显式 false 也照样压过 disableStrictly 推出的 true）
            let dis = node.disabled;
            if (dis === undefined)
                dis = p.disabled;
            // TreeNode.isDisabled（渲染）与 foundation._isDisabled（能不能选）是两套判定
            const visualOff = dis === false ? false : (control.disabled || Boolean(dis));
            const selectOff = Boolean(control.disabled || dis);
            const row = {
                key: node.key,
                label: node.label,
                value: node.value,
                nodeIcon: node.icon,
                data: data,
                level: p.level,
                pos: p.pos,
                isEnd: node.isEnd,
                expanded: p.expanded,
                loading: p.loading,
                selected: p.selected,
                checked: p.checked,
                halfChecked: p.halfChecked,
                filtered: p.filtered,
                keyword: p.keyword,
                disabled: visualOff,
                selectOff: selectOff,
                hasChildren: hasChildren,
                isLeaf: isLeaf,
                iconKind: "none",
                iconValue: "",
                labelKind: "text",
                labelText: "",
                labelValue: null,
            };
            control.fillIcon(row);
            control.fillLabel(row);
            out.push(row);
        }
        return out;
    }

    // renderIcon()（treeNode.tsx:281-302）：节点自带 > 整棵树的 icon > directory 默认
    function fillIcon(row) {
        const nodeIcon = row.nodeIcon;
        if (nodeIcon !== undefined && nodeIcon !== null && nodeIcon !== "") {
            control.putArt(row, "icon", nodeIcon);
            return;
        }
        const treeIcon = control.icon;
        if (treeIcon !== undefined && treeIcon !== null && treeIcon !== "") {
            if (typeof treeIcon === "function")
                control.putArt(row, "icon", treeIcon(control.iconHookProps(row)));
            else
                control.putArt(row, "icon", treeIcon);
            return;
        }
        if (control.directory) {
            row.iconKind = "name";
            row.iconValue = row.hasChildren
                ? (row.expanded ? "folder_open" : "folder") : "file";
        }
    }

    function iconHookProps(row) {
        // 官方把整份 TreeNodeProps 传给 icon(props)；端口能给出的是这一行的渲染数据
        return {
            eventKey: row.key, data: row.data, label: row.label, value: row.value,
            level: row.level, pos: row.pos, expanded: row.expanded, selected: row.selected,
            checked: row.checked, halfChecked: row.halfChecked, disabled: row.disabled,
            isLeaf: row.isLeaf, hasChildren: row.hasChildren, loading: row.loading,
            filtered: row.filtered, keyword: row.keyword,
        };
    }

    function fillLabel(row) {
        const label = row.label;
        if (typeof label === "string") {
            row.labelKind = "text";
            row.labelText = label;
            return;
        }
        if (typeof label === "number") {
            row.labelKind = "text";
            row.labelText = String(label);
            return;
        }
        if (label === undefined || label === null) {
            row.labelKind = "text";
            row.labelText = "";
            return;
        }
        row.labelKind = "slot";
        row.labelValue = label;
    }

    // ReactNode 档：字符串当图标名，Component / 别的对象当可视项
    function putArt(row, field, value) {
        if (typeof value === "string") {
            row[field + "Kind"] = "name";
            row[field + "Value"] = value;
            return;
        }
        if (value === undefined || value === null) {
            row[field + "Kind"] = "none";
            row[field + "Value"] = "";
            return;
        }
        row[field + "Kind"] = "slot";
        row[field + "Value"] = value;
    }

    function rowRecord(groupIndex, rowIndex) {
        const entry = control.renderRows[groupIndex];
        if (entry === undefined || entry === null)
            return null;
        if (entry instanceof Array)
            return entry[rowIndex];
        return entry;
    }

    function entryIsGroup(index) {
        const entry = control.renderRows[index];
        return entry !== undefined && entry !== null && entry instanceof Array;
    }

    function entryLength(index) {
        const entry = control.renderRows[index];
        return entry instanceof Array ? entry.length : 1;
    }

    // ================================================================ 受控同步（gDSFP）
    // reason = 这次是什么变了（对应官方的 needUpdate(name)）；null = 初次挂载
    function reconcile(reason) {
        const first = !control._mounted;
        // 官方 :269 firstInProps = !prevProps && 'treeData' in props ⇒ 挂载那一次也算数据变化
        const dataChanged = reason === "treeData" || reason === "treeDataSimpleJson"
            || !control._mounted;
        // 在 onXxxChanged 里读派生绑定（_keyEntities）拿到的是**上一份**，
        // 所以这里按原始属性现算一遍；派生绑定随后会自己跟上
        const json = control.treeDataSimpleJson !== undefined && control.treeDataSimpleJson !== null;
        const source = json ? Engine.convertJsonToData(control.treeDataSimpleJson) : control.treeData;
        const map = Engine.convertDataToEntities(source, control.keyMaps);
        const entities = map.keyEntities;
        const valueEnts = map.valueEntities;
        const withObject = control.onChangeWithObject;
        const hasValue = control.value !== undefined && control.value !== null;
        const hasDefault = control.defaultValue !== undefined && control.defaultValue !== null;
        const hasDefaultExpanded = control.defaultExpandedKeys !== undefined
            && control.defaultExpandedKeys !== null;

        // 官方：数据结构变化时把动画关掉（motionKeys 清空、motionType 置 null）
        if (dataChanged && control.motion && !first) {
            control._motionKeySet = ({});
            control._motionType = "";
        }
        const expandAllWhenDataChange = dataChanged && control.expandAll;

        if (!control.dataSearching) {
            if (reason === "expandedKeys" || (reason === "autoExpandParent" && !first)
                || (first && control.expandedKeys !== undefined
                    && control.expandedKeys !== null)) {
                control._expandedSet = Engine.calcExpandedKeys(
                    control.toKeyList(control.expandedKeys), entities,
                    control.autoExpandParent || first);
                // 官方 :348 —— 只有 treeData 没变时才算动画
                if (!first && control.motion && !dataChanged) {
                    const res = Engine.calcMotionKeys(control._prevExpandedSet,
                        control._expandedSet, entities);
                    control._motionKeySet = Engine.toSet(res.motionKeys);
                    control._motionType = res.motionType;
                    if (res.motionType === "hide")
                        control._cachedFlatten = control.flattenNodes;
                    control.beginMotion();
                }
            } else if ((first && (control.defaultExpandAll || control.expandAll))
                || expandAllWhenDataChange) {
                control._expandedSet = Engine.toSet(Object.keys(entities));
            } else if (first && hasDefaultExpanded) {
                control._expandedSet = Engine.calcExpandedKeys(
                    control.toKeyList(control.defaultExpandedKeys), entities, true);
            } else if (first && hasDefault) {
                control._expandedSet = Engine.calcExpandedKeysForValues(control.defaultValue,
                    entities, control.multiple, valueEnts);
            } else if (first && hasValue) {
                control._expandedSet = Engine.calcExpandedKeysForValues(control.value,
                    entities, control.multiple, valueEnts);
            } else if (!control.expandControlled && dataChanged && hasValue) {
                // 官方 :379-394 —— loadData 造成的 treeData 更新不要重算展开，否则
                // 「未选中但已展开」的节点会被收起
                if (!(control._hadData && control.loadData !== null)) {
                    control._expandedSet = Engine.calcExpandedKeysForValues(control.value,
                        entities, control.multiple, valueEnts);
                }
            }
        } else {
            // 搜索态：数据变了整份重算 filterTreeData；expandedKeys 变了只动 filteredExpandedKeys
            if (dataChanged) {
                const res = Engine.filterTreeData({
                    showFilteredOnly: control.showFilteredOnly,
                    keyEntities: entities,
                    inputValue: control._input,
                    treeData: source,
                    filterTreeNode: control.filterTreeNode,
                    filterProps: control.realFilterProp(),
                    prevExpandedKeys: Engine.keysOf(control._filteredExpandedSet),
                    keyMaps: control.keyMaps,
                });
                control._filteredKeySet = res.filteredKeys;
                control._filteredExpandedSet = res.filteredExpandedKeys;
                control._filteredShownSet = res.filteredShownKeys;
                control._motionKeySet = ({});
            }
            // 官方 :432 是 `if (props.expandedKeys)` —— 空数组也算真值，这里同口径
            if (control.expandedKeys !== undefined && control.expandedKeys !== null) {
                control._filteredExpandedSet = Engine.calcExpandedKeys(
                    control.toKeyList(control.expandedKeys), entities,
                    control.autoExpandParent || first);
                if (!first && control.motion && !dataChanged) {
                    const res = Engine.calcMotionKeys(control._prevExpandedSet,
                        control._filteredExpandedSet, entities);
                    let motionKeys = res.motionKeys;
                    if (control.showFilteredOnly)
                        motionKeys = motionKeys.filter((k) => Engine.setHas(control._filteredShownSet, k));
                    if (res.motionType === "hide")
                        control._cachedFlatten = control.flattenNodes;
                    control._motionKeySet = Engine.toSet(motionKeys);
                    control._motionType = res.motionType;
                    control.beginMotion();
                }
            }
        }

        // ---- 选区 ----
        if (!control.multiple) {
            if (reason === "value" || (first && hasValue)) {
                control._selectedKeys = Engine.findKeysForValues(
                    Engine.normalizeValue(control.value, withObject, control.keyMaps),
                    valueEnts, false);
            } else if (first && hasDefault) {
                control._selectedKeys = Engine.findKeysForValues(
                    Engine.normalizeValue(control.defaultValue, withObject, control.keyMaps),
                    valueEnts, false);
            } else if (dataChanged && hasValue) {
                control._selectedKeys = Engine.findKeysForValues(
                    control.or(Engine.normalizeValue(control.value, withObject, control.keyMaps), ""),
                    valueEnts, false);
            }
        } else {
            let checkedKeyValues = null;
            if (reason === "value" || (first && hasValue)) {
                checkedKeyValues = Engine.findKeysForValues(
                    Engine.normalizeValue(control.value, withObject, control.keyMaps),
                    valueEnts, true);
            } else if (first && hasDefault) {
                checkedKeyValues = Engine.findKeysForValues(
                    Engine.normalizeValue(control.defaultValue, withObject, control.keyMaps),
                    valueEnts, true);
            } else if (dataChanged) {
                if (hasValue) {
                    checkedKeyValues = Engine.findKeysForValues(
                        control.or(Engine.normalizeValue(control.value, withObject, control.keyMaps),
                            []), valueEnts, true);
                } else {
                    checkedKeyValues = Engine.updateKeys(
                        control.checkRelation === "related"
                            ? control._checkedSet : control._realSet, entities);
                }
            }
            if (checkedKeyValues !== null && checkedKeyValues !== undefined) {
                if (control.checkRelation === "unRelated") {
                    control._realSet = Engine.toSet(checkedKeyValues);
                } else if (control.checkRelation === "related") {
                    const res = Engine.calcCheckedKeys(checkedKeyValues, entities);
                    control._checkedSet = res.checkedKeys;
                    control._halfSet = res.halfCheckedKeys;
                }
            }
        }

        if (reason === "loadedKeys"
            || (first && control.loadedKeys !== undefined && control.loadedKeys !== null)) {
            control._loadedSet = Engine.toSet(control.toKeyList(control.loadedKeys));
        }
        if (dataChanged && control.strictDisabled)
            control._disabledSet = Engine.calcDisabledKeys(entities, control.keyMaps);

        control._hadData = control.sourceData !== undefined && control.sourceData !== null
            && control.sourceData.length > 0;
        control._mounted = true;
    }

    function or(val, fallback) {
        return (val === undefined || val === null || val === false || val === "") ? fallback : val;
    }

    function toKeyList(list) {
        if (list === undefined || list === null)
            return [];
        return list instanceof Array ? list : [list];
    }

    function realFilterProp() {
        // foundation.ts:526 —— treeNodeFilterProp 是 'label' 时改读 keyMaps.label
        if (control.treeNodeFilterProp !== "label")
            return control.treeNodeFilterProp;
        return Engine.realName(control.keyMaps, "label");
    }

    // ================================================================ 展开
    function cacheFlattenNodes(on) {
        control._cachedFlatten = on ? control.flattenNodes : undefined;
    }

    function beginMotion() {
        if (!control.motion || control.useVirtualList)
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

    function setExpandedStatus(key) {
        const p = control.propsOf(key);
        if (p === null)
            return null;
        const isSearching = control.isSearching;
        const stateName = isSearching ? "_filteredExpandedSet" : "_expandedSet";
        const expandedKeys = Engine.copySet(control[stateName]);
        let motionType = "show";
        if (!p.expanded) {
            expandedKeys[key] = true;
        } else if (expandedKeys[key] === true) {
            delete expandedKeys[key];
            motionType = "hide";
        }
        control.cacheFlattenNodes(motionType === "hide" && control.motion);

        if (!control.expandControlled) {
            let motionKeys = control.motion
                ? Engine.getMotionKeys(key, expandedKeys, control._keyEntities) : [];
            if (isSearching && control.filteredOnlyActive) {
                motionKeys = motionKeys.filter((k) => Engine.setHas(control._filteredShownSet, k));
            }
            control[stateName] = expandedKeys;
            control._motionKeySet = Engine.toSet(motionKeys);
            control._motionType = motionType;
            control.beginMotion();
        }
        return { expandedKeys: expandedKeys, expanded: !p.expanded, data: p };
    }

    function handleNodeExpand(key) {
        const entity = control._keyEntities[key];
        if (entity === undefined)
            return;
        const childrenName = Engine.realName(control.keyMaps, "children");
        const kids = entity.data[childrenName];
        // 官方 foundation.ts:758 —— 没有 loadData 又没有孩子就直接不响应
        if (control.loadData === null && !(kids !== undefined && kids !== null && kids.length > 0))
            return;
        const res = control.setExpandedStatus(key);
        if (res === null)
            return;
        control.expand(Engine.keysOf(res.expandedKeys),
            { expanded: res.expanded, node: entity.data });
        // 官方在 adapter.notifyExpand 里顺手触发 loadData
        if (res.expanded)
            control.requestLoad(key);
    }

    function requestExpand(key) {
        control.handleNodeExpand(key);
    }

    // ================================================================ 选中
    function handleSingleSelect(key) {
        const res = Engine.singleSelect(key, control._selectedKeys, control.controlled);
        // 官方 notifySelect 恒传 selected=true（重复点同一个节点也是），照抄
        control.select(key, res.notifySelected, control.dataOf(key));
        if (!res.notifyChange)
            return;
        control.notifyChange(key);
        if (res.updateState)
            control._selectedKeys = res.selectedKeys;
    }

    function calcCheckedStatus(key, targetStatus) {
        if (!targetStatus)
            return targetStatus;
        const entities = control._keyEntities;
        const descendantKeys = Engine.normalizeKeyList(
            Engine.findDescendantKeys([key], entities, false), entities, true);
        const nonDisabled = descendantKeys.filter((k) => !Engine.setHas(control._disabledSet, k));
        if (nonDisabled.length === descendantKeys.length)
            return true;
        const allChecked = nonDisabled.every((k) => Engine.setHas(control._checkedSet, k));
        return !allChecked;
    }

    function calcCheckedKeysFor(key, targetStatus) {
        return targetStatus
            ? Engine.calcCheckedKeysForChecked(key, control._keyEntities,
                control._checkedSet, control._halfSet)
            : Engine.calcCheckedKeysForUnchecked(key, control._keyEntities,
                control._checkedSet, control._halfSet);
    }

    function calcNonDisabledCheckedKeys(key, targetStatus) {
        const entities = control._keyEntities;
        const descendantKeys = Engine.normalizeKeyList(
            Engine.findDescendantKeys([key], entities, false), entities, true);
        const nonDisabled = descendantKeys.filter((k) => !Engine.setHas(control._disabledSet, k));
        if (nonDisabled.length === descendantKeys.length)
            return control.calcCheckedKeysFor(key, targetStatus);
        const current = Engine.keysOf(control._checkedSet);
        const newChecked = targetStatus
            ? Engine.concatArr(nonDisabled, current)
            : Engine.difference(
                Engine.normalizeKeyList(current, entities, true, true), nonDisabled);
        return Engine.calcCheckedKeys(newChecked, entities);
    }

    function handleMultipleSelect(key) {
        const p = control.propsOf(key);
        if (p === null)
            return;
        if (control.checkRelation === "related") {
            let targetStatus = !p.checked;
            if (control.disableStrictly)
                targetStatus = control.calcCheckedStatus(key, targetStatus);
            const res = control.disableStrictly
                ? control.calcNonDisabledCheckedKeys(key, targetStatus)
                : control.calcCheckedKeysFor(key, targetStatus);
            control.select(key, targetStatus, control.dataOf(key));
            control.notifyChange(Engine.keysOf(res.checkedKeys));
            if (!control.controlled) {
                control._checkedSet = res.checkedKeys;
                control._halfSet = res.halfCheckedKeys;
            }
        } else if (control.checkRelation === "unRelated") {
            const next = Engine.copySet(control._realSet);
            let targetStatus = false;
            if (Engine.setHas(next, key)) {
                delete next[key];
                targetStatus = false;
            } else {
                next[key] = true;
                targetStatus = true;
            }
            control.select(key, targetStatus, control.dataOf(key));
            control.notifyChange(Engine.keysOf(next));
            if (!control.controlled)
                control._realSet = next;
        }
    }

    function handleNodeSelect(key) {
        if (control._keyEntities[key] === undefined)
            return;
        // foundation._isDisabled 只看 props.disabled || treeNode.disabled：树整体禁用时
        // 节点写 disabled:false 也算禁用（跟渲染那套判定不一样，上游就这样）
        const row = control.rowEntryByKey(key);
        if (row !== null && row.selectOff)
            return;
        if (!control.multiple)
            control.handleSingleSelect(key);
        else
            control.handleMultipleSelect(key);
    }

    function requestSelect(key) {
        control.handleNodeSelect(key);
    }

    // 官方 onClick（treeNode.tsx:97-107）
    function rowClicked(key) {
        if (control.expandAction === "doubleClick") {
            control.debounceSelect(key);
            return;
        }
        control.handleNodeSelect(key);
        if (control.expandAction === "click")
            control.handleNodeExpand(key);
    }

    function debounceSelect(key) {
        if (!control._clickGateOpen)
            return;
        control._clickGateOpen = false;
        control.handleNodeSelect(key);
        if (!selectGate.running)
            selectGate.start();
    }

    // 官方 onDoubleClick：先给用户回调，再按 expandAction 展开
    function rowDoubleClicked(key) {
        if (control._keyEntities[key] === undefined)
            return;
        control.doubleClick(control.dataOf(key));
        if (control.expandAction === "doubleClick")
            control.handleNodeExpand(key);
    }

    function requestContextMenu(key) {
        if (control._keyEntities[key] === undefined)
            return;
        control.contextMenu(control.dataOf(key));
    }

    // ================================================================ onChange
    function dataForKeyNotInEntities(key) {
        if (control.onChangeWithObject)
            return control.findDataForValue(key);
        const out = {};
        out[Engine.realName(control.keyMaps, "key")] = key;
        out[Engine.realName(control.keyMaps, "label")] = key;
        return out;
    }

    function findDataForValue(findValue) {
        const valueName = Engine.realName(control.keyMaps, "value");
        const keyName = Engine.realName(control.keyMaps, "key");
        let valueArr = [];
        if (control.value !== undefined && control.value !== null)
            valueArr = control.toKeyList(control.value);
        else if (control.defaultValue !== undefined && control.defaultValue !== null)
            valueArr = control.toKeyList(control.defaultValue);
        for (let i = 0; i < valueArr.length; ++i) {
            const item = valueArr[i];
            if (item !== null && item !== undefined && typeof item === "object"
                && (item[valueName] === findValue || item[keyName] === findValue))
                return item;
        }
        return undefined;
    }

    function notifyMultipleChange(keys) {
        let keyList = [];
        if (control.checkRelation === "related") {
            keyList = control.autoMergeValue
                ? Engine.normalizeKeyList(keys, control._keyEntities, control.leafOnly, true)
                : keys;
        } else if (control.checkRelation === "unRelated") {
            keyList = keys;
        }
        const nodes = keyList.map((key) => control._keyEntities[key] !== undefined
            ? control._keyEntities[key].data
            : control.dataForKeyNotInEntities(key));
        if (control.onChangeWithObject)
            control.change(nodes);
        else
            control.change(Engine.getValueOrKey(nodes, control.keyMaps));
    }

    // 官方 notifyJsonChange 用的是 lodash pick，那是**浅**的：路径 "Node1.Child" 这种
    // 带点的键在顶层对象里不存在 ⇒ onChange 收到的基本恒为空对象。上游就这样，照抄。
    function notifyJsonChange(key) {
        const data = control.treeDataSimpleJson;
        const path = Engine.normalizedArr(key)
            .map((i) => String(i).split(Engine.JSON_KEY_SPLIT).join("."));
        const value = {};
        if (data !== undefined && data !== null) {
            for (let i = 0; i < path.length; ++i) {
                if (Object.prototype.hasOwnProperty.call(data, path[i]))
                    value[path[i]] = data[path[i]];
            }
        }
        control.change(value);
    }

    function notifyChange(keyOrKeys) {
        if (control.jsonMode) {
            control.notifyJsonChange(keyOrKeys);
            return;
        }
        if (control.multiple) {
            control.notifyMultipleChange(keyOrKeys);
            return;
        }
        const entity = control._keyEntities[keyOrKeys];
        if (entity === undefined)
            return;
        if (control.onChangeWithObject)
            control.change(entity.data);
        else
            control.change(Engine.getValueOrKey(entity.data, control.keyMaps));
    }

    // ================================================================ 搜索
    function handleInputChange(text) {
        const input = text === undefined || text === null ? "" : String(text);
        control._input = input;
        const entities = control._keyEntities;
        let filteredOptsKeys = [];
        let expandedOptsKeys = [];
        let shownKeys = {};
        control._motionKeySet = ({});

        if (input === "") {
            // 清空搜索：官方把「选中项及其祖先」并进 expandedKeys（原地改的那个集合）
            const merged = Engine.copySet(control._expandedSet);
            expandedOptsKeys = Engine.findAncestorKeys(control._selectedKeys, entities, true);
            for (let i = 0; i < expandedOptsKeys.length; ++i)
                merged[expandedOptsKeys[i]] = true;
            control._expandedSet = merged;
        } else {
            filteredOptsKeys = Engine.filteredOptionKeys(entities, input,
                control.filterTreeNode, control.realFilterProp());
            expandedOptsKeys = Engine.findAncestorKeys(filteredOptsKeys, entities, false);
            const shownChildKeys = Engine.findDescendantKeys(filteredOptsKeys, entities, true);
            shownKeys = Engine.toSet(Engine.concatArr(shownChildKeys, expandedOptsKeys));
        }
        const filteredExpanded = Engine.toSet(expandedOptsKeys);
        control._filteredKeySet = Engine.toSet(filteredOptsKeys);
        control._filteredExpandedSet = filteredExpanded;
        control._filteredShownSet = shownKeys;
        control.search(input, Engine.keysOf(filteredExpanded));
    }

    function searchBy(value) {
        control.handleInputChange(value);
    }

    // ================================================================ 异步加载
    function requestLoad(key) {
        if (control.loadData === null)
            return;
        if (Engine.setHas(control._loadedSet, key) || Engine.setHas(control._loadingSet, key))
            return;
        const loading = Engine.copySet(control._loadingSet);
        loading[key] = true;
        control._loadingSet = loading;
        control.loadData(control.dataOf(key), function () {
            control.finishLoad(key);
        });
    }

    function finishLoad(key) {
        const loaded = Engine.copySet(control._loadedSet);
        loaded[key] = true;
        const loading = Engine.copySet(control._loadingSet);
        delete loading[key];
        // 官方 : onLoad 先于 setState（再晚一次 loadData 会被触发两遍）
        control.load(Engine.keysOf(loaded), control.dataOf(key));
        if (!control.loadControlled)
            control._loadedSet = loaded;
        control._loadingSet = loading;
    }

    // ================================================================ 拖拽
    function rowEntryByKey(key) {
        const list = control.rows;
        for (let i = 0; i < list.length; ++i) {
            if (list[i].key === key)
                return list[i];
        }
        return null;
    }

    // getDragEventNodeData：{...node.data, expanded, pos, children}
    function dragEventNode(key) {
        const entry = control.rowEntryByKey(key);
        if (entry === null)
            return null;
        const out = {};
        for (const k in entry.data)
            out[k] = entry.data[k];
        out.expanded = entry.expanded;
        out.pos = entry.pos;
        out.children = entry.data[Engine.realName(control.keyMaps, "children")];
        return out;
    }

    function handleNodeDragStart(key) {
        control._dragSourceKey = key;
        control._dragging = true;
        control._dragNodesSet = Engine.toSet(Engine.getDragNodesKeys(key, control._keyEntities));
        control.dragStart(control.dragEventNode(key));
    }

    function handleNodeDragEnter(key) {
        const dragNode = control._dragSourceKey;
        if (dragNode === "" || Engine.setHas(control._dragNodesSet, key))
            return;
        if (control._keyEntities[key] === undefined)
            return;
        const dropPosition = control.dropRelativeAtKey(key);
        if (dragNode === key && dropPosition === 0) {
            control._dragOverKey = "";
            control._dropPosition = null;
            return;
        }
        // 官方 setTimeout(0)：先清掉上一个节点留下的状态，端口在同一个事件里直接写
        control._dragOverKey = key;
        control._dropPosition = dropPosition;
        const p = control.propsOf(key);
        if (p === null)
            return;
        if (!control.autoExpandWhenDragEnter || p.expanded) {
            control.dragEnter(control.dragEventNode(key), undefined);
            return;
        }
        // 悬停 400ms 才自动展开
        dragHoldTimer.restart();
    }

    function handleDragHold() {
        const key = control._dragOverKey;
        if (!control._dragging || key === "")
            return;
        const res = control.setExpandedStatus(key);
        if (res === null)
            return;
        control.dragEnter(control.dragEventNode(key), Engine.keysOf(res.expandedKeys));
    }

    function handleNodeDragOver(key) {
        if (Engine.setHas(control._dragNodesSet, key))
            return;
        if (control._dragSourceKey !== "" && key === control._dragOverKey) {
            const newPos = control.dropRelativeAtKey(key);
            if (control._dropPosition !== newPos)
                control._dropPosition = newPos;
        }
        control.dragOver(control.dragEventNode(key));
    }

    function handleNodeDragLeave(key) {
        dragHoldTimer.stop();
        control._dragOverKey = "";
        control.dragLeave(control.dragEventNode(key));
    }

    function clearDragState() {
        control._dragOverKey = "";
        control._dragging = false;
    }

    // 官方 dragend 落在「被按住的那个元素」上（HTML5 语义），与 drop 的目标无关
    function handleNodeDragEnd(sourceKey) {
        control.clearDragState();
        control.dragEnd(control.dragEventNode(sourceKey));
        control._dragSourceKey = "";
    }

    function handleNodeDrop(key) {
        const dropPosition = control._dropPosition;
        control.clearDragState();
        if (Engine.setHas(control._dragNodesSet, key))
            return;
        const entity = control._keyEntities[key];
        if (entity === undefined)
            return;
        control.drop(control.dragEventNode(key),
            control._dragSourceKey === "" ? null : control.dragEventNode(control._dragSourceKey),
            Engine.keysOf(control._dragNodesSet),
            Engine.calcDropActualPosition(entity.pos, dropPosition),
            dropPosition !== 0);
        control._dragSourceKey = "";
    }

    // 落点在这一行的上 45% / 下 45% / 中间
    function dropRelativeAtKey(key) {
        const box = control.rowBoxOfKey(key);
        if (box === null || control._dragLocalY < 0)
            return 0;
        return Engine.calcDropRelativePosition(control._dragLocalY, box.top, box.height);
    }

    function rowBoxOfKey(key) {
        for (let i = 0; i < control.renderRows.length; ++i) {
            if (control.entryKey(i) !== key)
                continue;
            const item = entryList.itemAt(i);
            if (item === null)
                return null;
            return { top: item.y, height: item.height };
        }
        return null;
    }

    // ================================================================ 几何常量
    readonly property real indentStep: 20        // $spacing-tree_option_level-paddingLeft
    readonly property real level1Pad: 8          // $spacing-tree_option_level1-paddingLeft
    readonly property real caretBox: 12          // $width-tree_emptyIcon = $width-icon-small
    readonly property real iconGap: 8            // $spacing-tree_icon-marginRight
    readonly property real checkBox: 16          // $width-checkbox
    readonly property real iconBox: 16           // .semi-icon 缺省 font-size: 16px
    readonly property real lineWidth: 1          // $width-tree_option_line
    readonly property real dragBorder: 2         // $width-tree_option_draggable-border
    readonly property real rowPadY: 4            // $spacing-tree_option-paddingTop/Bottom
    readonly property real textBoxHeight: 20     // font-size-regular 的行高
    readonly property real listPadX: 0           // $spacing-tree_optionList-paddingX
    readonly property real listPadY: 8           // $spacing-tree_optionList-paddingY
    readonly property real searchPadX: 12        // $spacing-tree_search_wrapper-paddingX
    readonly property real searchPadY: 8         // $spacing-tree_search_wrapper-paddingY
    readonly property int motionDuration: 200    // nodeList.tsx:74 duration={200}

    readonly property real baseRowHeight: 28     // 4 + 20 + 4
    readonly property real virtualItemSize: control.useVirtualList
        && control.virtualize.itemSize !== undefined ? control.virtualize.itemSize : 28
    readonly property real rowHeight: control.useVirtualList ? control.virtualItemSize
        : control.baseRowHeight
    readonly property real rowInnerWidth: Math.max(0, control.width - control.listPadX * 2)

    readonly property bool searchVisible: control.truthy(control.filterTreeNode)
        && control.searchRender !== false
    readonly property real searchHeight: control.searchVisible
        ? control.searchPadY * 2 + 32 : 0
    readonly property bool noData: Object.keys(control._keyEntities).length === 0
        || (control.showFilteredOnly && control.isSearching
            && Object.keys(control._filteredKeySet).length === 0)

    implicitWidth: 280
    implicitHeight: control.searchHeight + control.listPadY * 2 + control.naturalListHeight
    readonly property real naturalListHeight: control.noData ? control.textBoxHeight
        : control.listContentHeight()
    readonly property real viewHeight: control.useVirtualList
        ? control.virtualBoxHeight : Math.max(0, control.height - control.searchHeight)
    // AutoSizer：height 给数字就用它，给 '100%'（或不给）就用可用高度
    readonly property real virtualBoxHeight: {
        if (!control.useVirtualList)
            return 0;
        const h = control.virtualize.height;
        if (typeof h === "number")
            return h;
        return Math.max(0, control.height - control.searchHeight);
    }
    readonly property real virtualBoxWidth: {
        if (!control.useVirtualList)
            return control.rowInnerWidth;
        const w = control.virtualize.width;
        if (typeof w === "number")
            return w;
        return control.rowInnerWidth;
    }

    // ================================================================ 渲染取数（TreeRow 用）
    function dragOverOf(groupIndex, rowIndex) {
        const rec = control.rowRecord(groupIndex, rowIndex);
        if (rec === null)
            return false;
        return control._dragOverKey === rec.key && control._dropPosition === 0;
    }

    function dragGapTopOf(groupIndex, rowIndex) {
        const rec = control.rowRecord(groupIndex, rowIndex);
        if (rec === null)
            return false;
        return control._dragOverKey === rec.key && control._dropPosition === -1;
    }

    function dragGapBottomOf(groupIndex, rowIndex) {
        const rec = control.rowRecord(groupIndex, rowIndex);
        if (rec === null)
            return false;
        return control._dragOverKey === rec.key && control._dropPosition === 1;
    }

    // `& + .-selected::after`：上一条正好是被 drag-over 的那一行
    function prevDragOverSeam(groupIndex, rowIndex) {
        const prev = control.rowRecord(groupIndex - 1, rowIndex);
        if (prev === null)
            return false;
        return control._dragOverKey === prev.key && control._dropPosition === 0;
    }

    // expandIcon 三档：图标名 / Component / function(props)
    function caretArtKind(groupIndex, rowIndex) {
        const art = control.caretArt(groupIndex, rowIndex);
        if (art === undefined || art === null || art === "")
            return "none";
        return typeof art === "string" ? "name" : "slot";
    }

    function caretArtValue(groupIndex, rowIndex) {
        return control.caretArt(groupIndex, rowIndex);
    }

    function caretArt(groupIndex, rowIndex) {
        if (control.expandIcon === undefined || control.expandIcon === null)
            return null;
        if (typeof control.expandIcon === "function") {
            const rec = control.rowRecord(groupIndex, rowIndex);
            if (rec === null)
                return null;
            return control.expandIcon({ expanded: rec.expanded });
        }
        return control.expandIcon;
    }

    // 行在滚动内容里的纵向盒子（拖拽命中用）
    function listContentHeight() {
        let h = 0;
        for (let i = 0; i < entryList.count; ++i) {
            const item = entryList.itemAt(i);
            if (item !== null)
                h += item.height;
        }
        return h;
    }

    function entryKey(index) {
        const entry = control.renderRows[index];
        if (entry === undefined || entry === null)
            return "";
        if (entry instanceof Array)
            return entry.length ? String(entry[0].key) : "";
        return String(entry.key);
    }

    // ================================================================ 钩子注入
    // 钩子那几份 Component 必须自己声明要接的属性（QML 里给没声明的属性赋值会被拒），
    // 这里逐个认一遍，没声明的跳过 —— 同 TreeSelect 的 renderSelectedItem 口径。
    // 节点数据叫 modelData 不叫 data：每个 QQuickItem 自己就有一个 data（默认属性列表），
    // `"data" in item` 恒真，往里塞 QVariantMap 会直接把 children 列表写坏（实测 SIGSEGV）
    function give(item, name, value) {
        if (item !== null && name in item)
            item[name] = value;
    }

    function injectRenderLabel(item, groupIndex, rowIndex) {
        if (item === null)
            return;
        const rec = control.rowRecord(groupIndex, rowIndex);
        if (rec === null)
            return;
        control.give(item, "label", rec.label);
        control.give(item, "modelData", rec.data);
        control.give(item, "searchWord", rec.keyword);
    }

    function injectFullLabel(item, groupIndex, rowIndex, caret) {
        if (item === null)
            return;
        const rec = control.rowRecord(groupIndex, rowIndex);
        if (rec === null)
            return;
        control.give(item, "modelData", rec.data);
        control.give(item, "level", rec.level);
        control.give(item, "filtered", rec.filtered);
        control.give(item, "searchWord", rec.keyword);
        control.give(item, "checkStatus",
            { checked: rec.checked, halfChecked: rec.halfChecked });
        control.give(item, "expandStatus", { expanded: rec.expanded, loading: rec.loading });
        control.give(item, "expandIcon", caret);
        control.give(item, "checked", rec.checked);
        control.give(item, "halfChecked", rec.halfChecked);
        control.give(item, "expanded", rec.expanded);
        control.give(item, "loading", rec.loading);
        control.give(item, "selected", rec.selected);
        control.give(item, "disabled", rec.disabled);
        control.give(item, "isLeaf", rec.isLeaf);
        control.give(item, "onClick", function () { control.rowClicked(rec.key); });
        control.give(item, "onCheck", function () { control.handleNodeSelect(rec.key); });
        control.give(item, "onExpand", function () { control.handleNodeExpand(rec.key); });
        control.give(item, "onDoubleClick", function () { control.rowDoubleClicked(rec.key); });
        control.give(item, "onContextMenu", function () { control.requestContextMenu(rec.key); });
    }

    function injectSearch(item) {
        if (item === null)
            return;
        control.give(item, "value", control._input);
        control.give(item, "placeholder", control.searchPlaceholder !== ""
            ? control.searchPlaceholder : qsTr("搜索"));
        control.give(item, "showClear", control.showClear);
        control.give(item, "onChange", function (text) { control.handleInputChange(text); });
    }

    // ================================================================ 指针位置
    // 行底色与箭头变色看的是这里记下的指针位置，不看行自己那枚 HoverHandler：
    // 展开/收起动画起手和收尾各有一次 Repeater 重建（模型条目数变了），而新委托上的
    // HoverHandler 要等**下一个鼠标事件**才知道指针已经落在它里面 ⇒ 被点那一行的底色会
    // 掉一帧不亮，看起来就是闪烁。容器项不是委托、不会跟着重建，位置一直有效；
    // 口径也和 CSS :hover 一致 —— 官方那条规则判的就是「指针在不在这块盒子里」。
    //   · hoverPoint 是「行所在的内容坐标系」里的位置（非虚拟化 = column，虚拟化 = 列表 contentItem）；
    //   · hoverInside 只看指针在不在列表区里，离开整块就全灭。
    property point hoverPoint: Qt.point(-1, -1)
    property bool hoverInside: false
    readonly property var rowSpace: control.useVirtualList ? virtualList.contentItem : column

    function trackHover() {
        const space = control.rowSpace;
        if (space === null)
            return;
        const p = space.mapFromItem(null, listHover.point.scenePosition.x,
            listHover.point.scenePosition.y);
        control.hoverPoint = Qt.point(p.x, p.y);
    }

    // ================================================================ 测试口子
    readonly property var expandedMapView: control._expandedSet
    readonly property var checkedMapView: control._checkedSet
    readonly property var halfMapView: control._halfSet
    readonly property var realMapView: control._realSet
    readonly property var selectedListView: control._selectedKeys
    readonly property var filteredMapView: control._filteredKeySet
    readonly property var filteredExpandedMapView: control._filteredExpandedSet
    readonly property var disabledMapView: control._disabledSet
    readonly property var loadedMapView: control._loadedSet
    readonly property var loadingMapView: control._loadingSet
    readonly property var dragNodesMapView: control._dragNodesSet
    readonly property string inputValueView: control._input
    readonly property string dragOverView: control._dragOverKey
    readonly property var dropPosView: control._dropPosition
    readonly property bool draggingView: control._dragging
    readonly property var motionMapView: control._motionKeySet
    // QML 侧的 Item 没有 findChild，测试要靠这个名字拿到滚动容器（同 TreeSelect._popup）
    readonly property var _listHost: listHost
    property var entryRefs: []
    readonly property string motionTypeView: control._motionType
    readonly property var _virtualList: virtualList
    readonly property int entryCount: control.renderRows.length

    function expandedKeysList() {
        return Engine.keysOf(control._expandedSet);
    }

    function checkedKeysList() {
        return Engine.keysOf(control._checkedSet);
    }

    function halfKeysList() {
        return Engine.keysOf(control._halfSet);
    }

    function realKeysList() {
        return Engine.keysOf(control._realSet);
    }

    function jsonSplit() {
        return Engine.JSON_KEY_SPLIT;
    }

    function filteredKeysList() {
        return Engine.keysOf(control._filteredKeySet);
    }

    function filteredExpandedList() {
        return Engine.keysOf(control._filteredExpandedSet);
    }

    function loadedKeysList() {
        return Engine.keysOf(control._loadedSet);
    }

    function loadingKeysList() {
        return Engine.keysOf(control._loadingSet);
    }

    function rowKeys() {
        return control.rows.map((r) => String(r.key));
    }

    function rowField(index, field) {
        const rec = control.rows[index];
        if (rec === undefined)
            return undefined;
        return rec[field];
    }

    function rowCount() {
        return control.rows.length;
    }

    function entryCountView() {
        return control.renderRows.length;
    }

    function entryAt(index) {
        return entryList.itemAt(index);
    }

    // 第 i 个可见行（组里第 k 条也算）对应的 TreeRow
    function rowItem(index, inner) {
        // 委托项挂在 entryRefs 上（entryList.itemAt 的静态类型是 QQuickItem，
        // 拿不到 delegate 自己声明的 rowAt）
        if (index < 0 || index >= entryList.count)
            return null;
        const entry = control.entryRefs[index];
        if (entry === undefined)
            return null;
        return entry.rowAt(inner === undefined ? 0 : inner);
    }

    function virtualListCount() {
        return virtualList.count;
    }

    function virtualRowItem(i) {
        return virtualList.itemAtIndex(i);
    }

    function scrollTo(data) {
        if (data === undefined || data === null)
            return;
        const key = data.key;
        const align = data.align === undefined ? "center" : data.align;
        if (!key)
            return;
        const index = control.rows.findIndex((r) => String(r.key) === String(key));
        if (index < 0)
            return;
        // 官方 :612 —— 只有虚拟化那份 ref 存在时才生效，非虚拟化调了什么都没发生
        if (!control.useVirtualList)
            return;
        virtualList.positionViewAtIndex(index, control.alignMode(align));
    }

    // 官方 align 五档对应 react-window 的 scrollToItem 语义。
    // 本机 Qt 6.11 的 QML 侧只注册了 Center=1 / End=2 / Contain=4 三个名字，
    // Begin 取名字拿不到（ListView.Begin 是 undefined），实测数值 0 就是「贴起始边」。
    function alignMode(align) {
        if (align === "start")
            return 0;
        if (align === "end")
            return ListView.End;
        if (align === "center")
            return ListView.Center;
        // react-window 的 smart / auto 都是「就近」
        return ListView.Contain;
    }

    // ================================================================ 拖拽驱动
    property point dragCentroid: Qt.point(-1, -1)

    function dragLocalY() {
        // handler 挂在 listHost 上，Column 的位移要减掉
        return control.dragCentroid.y - column.y + flick.contentY;
    }

    function entryAtLocalY(y) {
        for (let i = 0; i < entryList.count; ++i) {
            const item = entryList.itemAt(i);
            if (item === null)
                continue;
            if (y >= item.y && y < item.y + item.height)
                return i;
        }
        return -1;
    }

    // 按下但还没触发拖拽的那一帧：DragHandler 在 dragThreshold 之后才 active，
    // 而官方 HTML5 的 dragstart 就落在按下的那一行上 ⇒ 起点必须在这里认
    function noteDragPress() {
        control._dragLocalY = control.dragLocalY();
        control._pendingSourceKey = control.draggableKeyAtLocalY(control._dragLocalY);
    }

    function clearDragPress() {
        control._dragHasPoint = false;
        control._pendingSourceKey = "";
    }

    function draggableKeyAtLocalY(y) {
        const index = control.entryAtLocalY(y);
        const key = index < 0 ? "" : control.entryKey(index);
        if (key === "")
            return "";
        const rec = control.rowEntryByKey(key);
        // 官方 draggable 属性只给「没禁用、非自定义整行」的行（treeNode.tsx:424）
        if (rec === null || rec.disabled || control.renderFullLabelOn)
            return "";
        return key;
    }

    function beginDrag() {
        control._dragLocalY = control.dragLocalY();
        control._lastDragKey = "";
        const key = control._pendingSourceKey;
        if (key === "")
            return;
        control.handleNodeDragStart(key);
        // 触发拖拽时指针可能已经挪到别的行上：官方此时也会发一次 dragenter
        control.moveDrag();
    }

    function moveDrag() {
        control._dragLocalY = control.dragLocalY();
        const index = control.entryAtLocalY(control._dragLocalY);
        const key = index < 0 ? "" : control.entryKey(index);
        if (key !== control._lastDragKey) {
            if (control._lastDragKey !== "")
                control.handleNodeDragLeave(control._lastDragKey);
            if (key !== "")
                control.handleNodeDragEnter(key);
            control._lastDragKey = key;
        } else if (key !== "") {
            control.handleNodeDragOver(key);
        }
    }

    function finishDrag() {
        dragHoldTimer.stop();
        const key = control._lastDragKey;
        const source = control._dragSourceKey;
        if (source !== "") {
            // 落在自己身上 / 自己的子孙上时 handleNodeDrop 直接返回，不发 drop，
            // 但 dragend 照样要有
            if (key !== "")
                control.handleNodeDrop(key);
            control.handleNodeDragEnd(source);
        }
        control._lastDragKey = "";
        control._pendingSourceKey = "";
        control._dragLocalY = -1;
    }

    // ================================================================ 视图
    // 官方 .semi-tree-wrapper 是 column flex：搜索区那 8/12 内边距占一行，
    // .semi-tree-option-list 吃剩下的 flex:1 ⇒ 两块各自一个容器，不能叠在一起
    Item {
        id: searchHost

        objectName: "treeSearchHost"

        visible: control.searchVisible
        x: 0
        y: 0
        width: control.width
        height: control.searchHeight

        // ---- 搜索区：内置 Input，或被 searchRender 整只换掉 ----
        Loader {
            id: searchHook

            objectName: "treeSearchHook"

            visible: active
            x: control.searchPadX
            y: control.searchPadY
            width: Math.max(0, searchHost.width - control.searchPadX * 2)
            active: control.searchVisible && control.isCustomSearch()
            sourceComponent: control.activeSearchComponent()
            onLoaded: control.injectSearch(item)
        }

        Item {
            id: searchBox

            objectName: "treeSearchArea"

            visible: control.searchVisible && !searchHook.active
            x: control.searchPadX
            y: control.searchPadY
            width: Math.max(0, searchHost.width - control.searchPadX * 2)
            height: 32

            Input {
                id: searchInput

                objectName: "treeSearchInput"

                anchors.fill: parent
                placeholderText: control.searchPlaceholder !== ""
                    ? control.searchPlaceholder : qsTr("搜索")
                prefixIcon: "search"
                showClear: control.showClear
                text: control._input
                onTextChanged: {
                    if (text !== control._input)
                        control.handleInputChange(text);
                }
            }
        }
    }

    Item {
        id: listHost

        objectName: "treeListHost"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: control.searchHeight
        // 不给高度整块塌成 0，行也点不着
        height: control.viewHeight
        clip: true

        // ---- 空态 ----
        Item {
            id: emptyRow

            objectName: "treeEmptyRow"

            visible: control.noData
            x: 0
            y: control.listPadY
            width: listHost.width
            height: control.textBoxHeight

            Loader {
                id: emptyHook

                objectName: "treeEmptyHook"

                anchors.centerIn: parent
                active: control.emptyHookActive()
                sourceComponent: control.emptyComponent()
            }

            Text {
                id: emptyText

                objectName: "treeEmptyText"

                anchors.centerIn: parent
                visible: !emptyHook.active
                text: control.emptyTextValue
                color: Theme.current.colorDisabledText
                font.pixelSize: Theme.current.fontSizeRegular
            }
        }

        // ---- 非虚拟化列表 ----
        Flickable {
            id: flick

            objectName: "treeFlickable"

            visible: !control.noData && !control.useVirtualList
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: column.height + control.listPadY * 2
            interactive: contentHeight > height

            Column {
                id: column

                objectName: "treeColumn"

                y: control.listPadY
                width: parent.width
                spacing: 0

                Repeater {
                    id: entryList

                    model: control.renderRows

                    delegate: Item {
                        id: entry

                        required property int index

                        objectName: "treeEntry"

                        Component.onCompleted: {
                            control.entryRefs[index] = entry;
                        }

                        onIndexChanged: control.entryRefs[index] = entry

                        width: column.width
                        height: entry.isGroup ? motionBox.height : plainRow.height

                        readonly property bool isGroup: control.entryIsGroup(index)

                        // 测试用：动画那一段的实际渲染高度（委托自己声明的属性格子外取不到）
                        readonly property real boxHeight: motionBox.height

                        // 普通行
                        TreeRow {
                            id: plainRow

                            objectName: "treeRow"

                            visible: !entry.isGroup
                            host: control
                            groupIndex: entry.index
                            rowIndex: 0
                            originInColumn: entry.y
                        }

                        // 展开动画那一段（nodeList.tsx 里被 NodeCollapsible 包住的那组）
                        Item {
                            id: motionBox

                            visible: entry.isGroup
                            width: entry.width
                            height: motionBox.animHeight
                            opacity: motionBox.animOpacity
                            clip: true

                            property real animHeight: 0
                            property real animOpacity: 1

                            function start() {
                                const full = motionColumn.implicitHeight;
                                const hiding = control._motionType === "hide";
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

                                    model: control.entryLength(entry.index)

                                    delegate: TreeRow {
                                        objectName: "treeMotionRow"

                                        required property int index

                                        host: control
                                        groupIndex: entry.index
                                        rowIndex: index
                                        originInColumn: entry.y + motionBox.y + motionColumn.y + y
                                        // 动画盒是 clip 的：被它裁掉的那截指针落上去不算悬停
                                        // （CSS overflow:hidden 同样把 :hover 一起裁掉）
                                        clipBottom: entry.y + motionBox.y + motionBox.height
                                    }
                                }
                            }
                        }

                        // 动画起手：_motionSeq 变一次重放一次（官方靠 key 换了重挂 NodeCollapsible）。
                        // 新建的组不需要在 onCompleted 里补一手：renderRows 是在写展开集那一刻
                        // 就重挂委托项的，等 beginMotion 把 _motionSeq 推进时它已经在这儿了
                        // （试过删那一手，169 条用例含 test_motionOnFreshlyCreatedEntrySettles 全绿）
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

        // ---- 虚拟化列表 ----
        ListView {
            id: virtualList

            objectName: "treeVirtualList"

            visible: !control.noData && control.useVirtualList
            x: 0
            y: 0
            width: control.virtualBoxWidth
            height: control.virtualBoxHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 0
            model: control.rows

            delegate: TreeRow {
                objectName: "treeVirtualRow"

                required property int index

                host: control
                groupIndex: index
                rowIndex: 0
                originInColumn: y
            }
        }

        // 拖拽：整块列表上一个 DragHandler，按落点找行
        DragHandler {
            id: rowDrag

            objectName: "treeDragHandler"

            target: null
            enabled: control.draggable && !control.useVirtualList
            dragThreshold: 0

            onActiveChanged: {
                control.dragCentroid = rowDrag.centroid.position;
                if (rowDrag.active) {
                    control.beginDrag();
                } else {
                    control.finishDrag();
                    control.clearDragPress();
                }
            }

            onCentroidChanged: {
                const p = rowDrag.centroid.position;
                control.dragCentroid = p;
                // 松手后 centroid 会归零：把它当成「没有按下」的标记，下一次非零就是新的一按
                if (!rowDrag.active && p.x === 0 && p.y === 0) {
                    control._dragHasPoint = false;
                    return;
                }
                if (rowDrag.active) {
                    control.moveDrag();
                    return;
                }
                // 还没触发拖拽的第一次 centroid 变化 = 按下的落点，官方 HTML5 的
                // dragstart 就挂在按住的那一行上（DragHandler 没有 startPoint /
                // pressed 可用，只能这样认）
                if (!control._dragHasPoint) {
                    control._dragHasPoint = true;
                    control.noteDragPress();
                }
            }
        }

        // 指针位置记在这个不会被重建的容器项上（为什么不用行上的 HoverHandler，见 hoverPoint）
        HoverHandler {
            id: listHover

            onPointChanged: control.trackHover()
            onHoveredChanged: control.hoverInside = listHover.hovered
        }
    }

    Timer {
        id: dragHoldTimer

        interval: 400                        // 官方 delayedDragEnterLogic 那 400ms
        repeat: false
        onTriggered: control.handleDragHold()
    }

    Timer {
        id: selectGate

        interval: 500                        // 官方 debounce(select, 500, {leading:true, trailing:false})
        repeat: false
        onTriggered: control._clickGateOpen = true
    }

    // ================================================================ 搜索档 / 空态档
    function isCustomSearch() {
        return control.searchRender !== undefined && control.searchRender !== null
            && control.searchRender !== false;
    }

    function activeSearchComponent() {
        return control.isCustomSearch() ? control.searchRender : null;
    }

    function emptyHookActive() {
        return control.emptyContent !== undefined && control.emptyContent !== null
            && !control.emptyIsText();
    }

    function emptyComponent() {
        return control.emptyHookActive() ? control.emptyContent : null;
    }

    function emptyIsText() {
        return typeof control.emptyContent === "string" || typeof control.emptyContent === "number";
    }

    readonly property string emptyTextValue: control.emptyHookActive() ? ""
        : (control.emptyIsText() ? String(control.emptyContent) : qsTr("暂无数据"))

    // ================================================================ 初始化 / 变更
    Component.onCompleted: {
        control.reconcile(null);
        control._prevExpandedSet = Engine.copySet(control._expandedSet);
    }

    // 创建期那一批属性赋值也会发 changed 信号，那时 entities 还没评出来；
    // 官方 gDSFP 是在 render 阶段跑的，端口统一并到 Component.onCompleted 那一次
    function runReconcile(reason) {
        if (!control._mounted)
            return;
        control._prevExpandedSet = Engine.copySet(control._expandedSet);
        control.reconcile(reason);
        control._prevExpandedSet = Engine.copySet(control._expandedSet);
    }

    onTreeDataChanged: control.runReconcile("treeData")
    onTreeDataSimpleJsonChanged: control.runReconcile("treeDataSimpleJson")
    onExpandedKeysChanged: control.runReconcile("expandedKeys")
    onAutoExpandParentChanged: control.runReconcile("autoExpandParent")
    onValueChanged: control.runReconcile("value")
    onLoadedKeysChanged: control.runReconcile("loadedKeys")
    onKeyMapsChanged: control.runReconcile("treeData")
}
