pragma ComponentBehavior: Bound

import QtQuick

// 穿梭框。左右两个面板：左侧永远是全量选项（带勾选框），勾上即进右侧；
// 右侧列已选项，悬浮出关闭图标可单个移除，能拖拽排序、能一键清空。
// 中间没有搬运按钮 —— 勾选本身就是搬运，这是官方 Transfer 的交互。
//
//     Transfer {
//         width: 568; height: 416
//         dataSource: [{ label: "选项一", value: 1, key: 1 }]
//         defaultValue: [2, 4]
//         onChange: (values, items) => console.log(values, items)
//     }
//
// 官方 API 面见 semi-ui/transfer/index.tsx（TransferProps），交互见
// semi-foundation/transfer/foundation.ts + transferUtils.ts，外观见
// transfer.scss + variables.scss，文案见 locale/source/zh_CN.ts 的 Transfer 段。
// 几处对不上的地方：
//   · 官方 onChange / onSelect / onDeselect / onSearch 四个回调 → 四个信号
//     change / select / deselect / search；pagination.onPageChange → pageChanged。
//   · 官方还有个绑在实例上的方法 search(value)（通过 ref 调用）。JS 里它和 onSearch
//     不冲突，QML 里冲突（信号与函数不能同名），这里方法改名 searchBy。
//   · 官方用 `'value' in props` 判受控；QML 没有这个概念，按仓库惯例 value 为
//     undefined / null 即非受控，`value: []` 是受控的空数组。
//   · 官方六个 render* 钩子收函数，这里收 Component。注入的入参一律声明成组件
//     根项的普通属性；QML 不允许声明 `property var onXxx`（on+大写是信号处理器的
//     保留前缀），所以官方带 on 前缀的入参在这里去掉 on：
//     onSearch→search、onAllClick→allClick、onSelectOrRemove→selectOrRemove、
//     onSelect→selectValues、onClear→clear、onRemove→remove、onSortEnd→sortEnd、
//     renderSourceItem 的 onChange→toggle。
//   · 官方 sortableHandle 是 render-prop（把任意节点变成拖拽触发器），QML 没有
//     等价物：拖拽手柄固定由行外壳画在最左，用自定义已选项渲染时也只差这一处。
//   · 官方 onSelect 收到的是没带 fullPath 的原始项、onDeselect 收到的是带 fullPath
//     的（foundation.ts:203-212）。上游自己的不一致，这里照抄。
Item {
    id: control

    // ---------------------------------------------------------------- 官方属性面
    property var dataSource: []
    property string type: "list"              // "list" | "groupList" | "treeList"
    property var value: undefined             // 受控已选值，元素是 item.value
    property var defaultValue: []
    property bool disabled: false
    property bool draggable: false
    property var filter: true                 // false 不渲染搜索框；函数自定义筛选
    property var inputProps: ({})             // { placeholder, size, showClear, ... }
    property var emptyContent: ({})           // { left, right, search }
    property bool showPath: false
    property var treeProps: ({})              // treeList 时透给左侧树，这里用得上 filterTreeNode
    property bool loading: false
    property var virtualize: ({})             // { height, width, itemSize }，官方 isEmpty({}) 即不开虚拟化
    property var pagination: undefined         // { currentPage, defaultCurrentPage, pageSize }，官方 Boolean(pagination) 判开关

    property Component renderSourceItem: null
    property Component renderSelectedItem: null
    property Component renderSourcePanel: null
    property Component renderSelectedPanel: null
    property Component renderSourceHeader: null
    property Component renderSelectedHeader: null

    signal change(var values, var items)
    signal select(var item)
    signal deselect(var item)
    signal search(string input)
    signal pageChanged(int currentPage)

    // ---------------------------------------------------------------- 内部状态
    // 非受控时的已选 key，按勾选先后排列（官方是 state.selectedItems: Map）
    property var _keys: []
    property string _input: ""                // 官方 state.inputValue
    property int _page: 1                     // 官方 state.leftCurrentPage
    property var _collapsed: ({})             // treeList：被折叠起来的节点 key
    property bool _touched: false             // 用户动过选区，之后不再拿 defaultValue 重新播种
    property var _rows: []                    // 右侧行外壳，拖拽时按 index 量位置
    property int _dragIndex: -1
    property int _dropIndex: -1
    property real _dragHeight: 0

    readonly property bool controlled: control.value !== undefined && control.value !== null
    readonly property bool interactive: control.enabled && !control.disabled
    // 官方 -custom-panel：两个面板都被接管时，描边和尺寸一起撤掉
    readonly property bool customPanel: control.renderSourcePanel !== null
        && control.renderSelectedPanel !== null
    readonly property var _data: control.generateData()

    implicitWidth: control.customPanel ? customRow.width : 402    // $width-transfer-minWidth
    implicitHeight: control.customPanel ? customRow.height : 400  // $height-transfer
    width: control.customPanel ? control.implicitWidth : 402
    height: control.customPanel ? control.implicitHeight : 400

    // ---------------------------------------------------------------- 小工具
    function copyObj(obj) {
        const out = {};
        for (const k in obj)
            out[k] = obj[k];
        return out;
    }

    // 官方 lodash omit
    function omit(obj, drop) {
        const out = {};
        for (const k in obj) {
            if (drop.indexOf(k) < 0)
                out[k] = obj[k];
        }
        return out;
    }

    function pick(obj, name, fallback) {
        if (obj === undefined || obj === null)
            return fallback;
        const v = obj[name];
        return v === undefined ? fallback : v;
    }

    function isObj(name) {
        const v = control[name];
        return v !== undefined && v !== null && typeof v === "object" && !Array.isArray(v);
    }

    // ---------------------------------------------------------------- 数据预处理
    // 官方 _generateDataByType（transferUtils.ts）：
    //   list      原样
    //   groupList 把每个分组的 children 摊平，条目挂 _parent（组本身去掉 children）
    //   treeList  深度优先摊平，节点带 path（根到自身）与 isLeaf
    function generateData() {
        const src = Array.isArray(control.dataSource) ? control.dataSource : [];
        if (control.type === "groupList") {
            const out = [];
            for (let g = 0; g < src.length; ++g) {
                const kids = Array.isArray(src[g].children) ? src[g].children : [];
                const parent = control.omit(src[g], ["children"]);
                for (let i = 0; i < kids.length; ++i) {
                    const item = control.copyObj(kids[i]);
                    item._parent = parent;
                    out.push(item);
                }
            }
            return out;
        }
        if (control.type === "treeList") {
            const out = [];
            const stack = [];
            for (let i = src.length - 1; i >= 0; --i)
                stack.push(control.copyObj(src[i]));
            while (stack.length > 0) {
                const current = stack.pop();
                if (current.path === undefined)
                    current.path = [control.omit(current, ["children"])];
                const kids = current.children;
                if (kids !== undefined && Array.isArray(kids)) {
                    for (let i = kids.length - 1; i >= 0; --i) {
                        const child = control.copyObj(kids[i]);
                        child.path = current.path.concat([control.omit(child, ["children"])]);
                        stack.push(child);
                    }
                } else {
                    current.isLeaf = true;
                }
                out.push(control.omit(current, ["children"]));
            }
            return out;
        }
        return src.slice();
    }

    // ---------------------------------------------------------------- 选区
    function dataByKey(key) {
        for (let i = 0; i < control._data.length; ++i) {
            if (control._data[i].key === key)
                return control._data[i];
        }
        return null;
    }

    function dataByValue(v) {
        for (let i = 0; i < control._data.length; ++i) {
            if (control._data[i].value === v)
                return control._data[i];
        }
        return null;
    }

    // 官方 _generateSelectedItems：入参是 value 数组，内部按 key 记账
    function keysOfValues(vals) {
        const out = [];
        if (!Array.isArray(vals))
            return out;
        for (let i = 0; i < vals.length; ++i) {
            const d = control.dataByValue(vals[i]);
            if (d !== null && out.indexOf(d.key) < 0)
                out.push(d.key);
        }
        return out;
    }

    function keyList() {
        return control.controlled ? control.keysOfValues(control.value) : control._keys;
    }

    function isSelected(item) {
        return item !== undefined && item !== null
            && control.keyList().indexOf(item.key) >= 0;
    }

    // 官方 _injectFullPath：只有 treeList + showPath 才挂 fullPath
    // 注：走 Repeater modelData 的那份数据会被转成 QVariant，嵌套数组不再是 JS Array，
    // 所以这里按 length 判，不能用 Array.isArray
    function withFullPath(item) {
        if (control.type !== "treeList" || !control.showPath || !pathOf(item))
            return item;
        const path = [];
        for (let i = 0; i < item.path.length; ++i)
            path.push(control.copyObj(item.path[i]));
        const copy = control.copyObj(item);
        copy.fullPath = path;
        return copy;
    }

    function pathOf(item) {
        return item !== undefined && item !== null
            && item.path !== undefined && item.path !== null && item.path.length > 0
            ? item.path : null;
    }

    function selectedItems() {
        const keys = control.keyList();
        const out = [];
        for (let i = 0; i < keys.length; ++i) {
            const d = control.dataByKey(keys[i]);
            if (d !== null)
                out.push(control.withFullPath(d));
        }
        return out;
    }

    readonly property var selected: control.selectedItems()

    // 官方 getValuesAndItemsFromMap：groupList 通知时抹掉 _parent
    function notifyChange(keys) {
        const items = [];
        const values = [];
        for (let i = 0; i < keys.length; ++i) {
            const d = control.dataByKey(keys[i]);
            if (d === null)
                continue;
            const src = control.type === "groupList" ? control.omit(d, ["_parent"]) : d;
            const item = control.withFullPath(src);
            items.push(item);
            values.push(item.value);
        }
        control.change(values, items);
    }

    // 官方受控时不写内部 state、只 notify（各 handler 里的 _isControlledComponent 分支）
    function applyKeys(next) {
        if (!control.controlled)
            control._keys = next;
        control._touched = true;
        control.notifyChange(next);
    }

    // 官方 handleSelectOrRemove：勾上即入选、再勾即退出，左右两栏走同一条路径
    function selectOrRemove(item) {
        if (!control.interactive || item === undefined || item === null
            || item.disabled === true)
            return;
        const keys = control.keyList().slice();
        const at = keys.indexOf(item.key);
        if (at >= 0) {
            keys.splice(at, 1);
            // 官方这里给 onDeselect 的是带 fullPath 的、给 onSelect 的是原始项
            control.deselect(control.withFullPath(item));
        } else {
            keys.push(item.key);
            control.select(item);
        }
        control.applyKeys(keys);
    }

    // 右侧行的移除入口（TransferRightItem 用）
    function removeAt(item) {
        control.selectOrRemove(item);
    }

    // 官方 handleClear：清掉全部数据里所有未禁用的项（已选的禁用项保留）
    function clearAll() {
        if (!control.interactive)
            return;
        const keys = control.keyList().slice();
        for (let i = control._data.length - 1; i >= 0; --i) {
            const d = control._data[i];
            if (d.disabled === true)
                continue;
            const at = keys.indexOf(d.key);
            if (at >= 0)
                keys.splice(at, 1);
        }
        control.applyKeys(keys);
    }

    // 官方 handleAll(wantAllChecked)：作用域是当前筛选结果的全部、不分页；
    // 禁用项只在「本来就选中」时保留
    function handleAll(wantAll) {
        if (!control.interactive)
            return;
        const operate = control.filterData;
        const keys = control.keyList().slice();
        for (let i = 0; i < operate.length; ++i) {
            const d = operate[i];
            if (d.disabled === true)
                continue;
            const at = keys.indexOf(d.key);
            if (wantAll && at < 0)
                keys.push(d.key);
            else if (!wantAll && at >= 0)
                keys.splice(at, 1);
        }
        control.applyKeys(keys);
    }

    // 官方 handleSelect（treeList 由树的 onChange 驱动）：入参是 value 数组
    function handleTreeSelect(vals) {
        if (!control.interactive)
            return;
        control.applyKeys(control.keysOfValues(vals));
    }

    // 官方 handleSortEnd：arrayMove 之后重排已选
    function sortEnd(oldIndex, newIndex) {
        if (oldIndex === newIndex)
            return;
        const keys = control.keyList().slice();
        if (oldIndex < 0 || oldIndex >= keys.length || newIndex < 0 || newIndex >= keys.length)
            return;
        const moved = keys.splice(oldIndex, 1)[0];
        keys.splice(newIndex, 0, moved);
        control.applyKeys(keys);
    }

    // ---------------------------------------------------------------- 搜索
    function matchOne(item) {
        if (typeof control.filter === "function")
            return Boolean(control.filter(control._input, item));
        return typeof item.label === "string" && item.label.indexOf(control._input) >= 0;
    }

    readonly property bool inSearch: control._input !== ""

    // 官方 treeList 把 searchResult 置成全集、过滤交给树自己（foundation.ts handleInputChange）
    readonly property var searchKeys: control.computeSearchKeys()

    function computeSearchKeys() {
        if (!control.inSearch)
            return null;
        const out = [];
        if (control.type === "treeList") {
            for (let i = 0; i < control._data.length; ++i)
                out.push(control._data[i].key);
            return out;
        }
        for (let i = 0; i < control._data.length; ++i) {
            if (control.matchOne(control._data[i]))
                out.push(control._data[i].key);
        }
        return out;
    }

    readonly property var filterData: control.computeFilterData()

    function computeFilterData() {
        if (control.searchKeys === null)
            return control._data;
        const out = [];
        for (let i = 0; i < control._data.length; ++i) {
            if (control.searchKeys.indexOf(control._data[i].key) >= 0)
                out.push(control._data[i]);
        }
        return out;
    }

    // 官方 handleInputChange(value, notify)：搜索顺手把左侧页码打回 1
    function handleInputChange(value, notify) {
        control._input = value;
        control._page = 1;
        if (notify)
            control.search(value);
    }

    // 官方实例方法 search(value)：外部手动触发搜索，不回抛 onSearch
    function searchBy(value) {
        control.handleInputChange(String(value), false);
    }

    // ---------------------------------------------------------------- 左侧分页
    // 官方是 Boolean(pagination)：给个空对象也算开分页
    readonly property bool hasPagination: control.isObj("pagination")
    readonly property int pageSize: {
        const n = control.pick(control.pagination, "pageSize", 10);   // DEFAULT_PAGE_SIZE
        return typeof n === "number" && n > 0 ? Math.floor(n) : 10;
    }
    readonly property int currentPage: {
        if (!control.hasPagination)
            return 1;
        const n = control.pick(control.pagination, "currentPage", undefined);
        return typeof n === "number" ? n : control._page;
    }
    readonly property int totalPage: Math.ceil(control.filterData.length / control.pageSize)
    readonly property bool paginationShown: control.hasPagination
        && control.totalPage > 1 && control.leftMode === "list" && control.type !== "treeList"

    readonly property var pagedData: control.computePagedData()

    function computePagedData() {
        if (!control.hasPagination || control.type === "treeList")
            return control.filterData;
        const start = (control.currentPage - 1) * control.pageSize;
        return control.filterData.slice(start, start + control.pageSize);
    }

    function changePage(page) {
        // 官方 handlePageChange：写内部页码 + 通知 pagination.onPageChange
        if (control.pick(control.pagination, "currentPage", undefined) === undefined)
            control._page = page;
        const cb = control.pick(control.pagination, "onPageChange", null);
        if (typeof cb === "function")
            cb(page);
        control.pageChanged(page);
    }

    // ---------------------------------------------------------------- 左面板派生
    // searchKeys 为 null 就是「不在搜索态」。不能拿 inSearch 当开关再读 searchKeys：
    // 两个绑定各自求值，_input 刚变的那一刻 searchKeys 还是旧的 null，直接就是 TypeError
    readonly property int showNumber: control.searchKeys === null
        ? control._data.length : control.searchKeys.length
    readonly property bool noMatch: control.searchKeys !== null && control.searchKeys.length === 0

    // 官方 renderLeft:486-496 的 leftContainsNotInSelected / filterDataAllDisabled
    readonly property var leftAll: control.computeLeftAll()

    function computeLeftAll() {
        const keys = control.keyList();
        const fd = control.filterData;
        let allDisabled = true;
        let containsFree = false;
        for (let i = 0; i < fd.length; ++i) {
            if (fd[i].disabled === true)
                continue;
            allDisabled = false;
            if (keys.indexOf(fd[i].key) < 0) {
                containsFree = true;
                break;
            }
        }
        return {
            allChecked: !containsFree,
            showButton: control.type !== "treeList" && !allDisabled,
        };
    }

    readonly property string leftMode: control.loading ? "loading"
        : (control.noMatch ? "noMatch"
            : (control._data.length === 0 ? "empty" : "list"))
    readonly property bool filterShown: control.filter !== false && !control.customPanel

    // 左侧行模型：分组时在同一组第一个条目前插一条组标题（官方 renderLeftList）
    readonly property var leftRows: control.buildLeftRows()

    function buildLeftRows() {
        if (control.type === "treeList")
            return [];
        const out = [];
        const seen = [];
        const list = control.pagedData;
        for (let i = 0; i < list.length; ++i) {
            const item = list[i];
            const parent = item._parent;
            if (parent !== undefined && parent !== null) {
                const title = parent.title;
                if (seen.indexOf(title) < 0) {
                    seen.push(title);
                    out.push({ kind: "group", title: title });
                }
            }
            out.push({ kind: "item", item: item });
        }
        return out;
    }

    // ---------------------------------------------------------------- 树（treeList）
    readonly property var treeNodes: control.buildTreeNodes()

    function buildTreeNodes() {
        if (control.type !== "treeList")
            return [];
        const out = [];
        const collectLeaves = (list, acc) => {
            for (let j = 0; j < list.length; ++j) {
                const inner = Array.isArray(list[j].children) ? list[j].children : [];
                if (inner.length > 0)
                    collectLeaves(inner, acc);
                else if (list[j].disabled !== true)
                    acc.push(list[j].key);
            }
        };
        const walk = (nodes, depth, ancestors) => {
            for (let i = 0; i < nodes.length; ++i) {
                const node = nodes[i];
                const kids = Array.isArray(node.children) ? node.children : [];
                const leafKeys = [];
                collectLeaves(kids, leafKeys);
                out.push({
                    key: node.key,
                    value: node.value,
                    label: node.label,
                    disabled: node.disabled === true,
                    depth: depth,
                    ancestors: ancestors,
                    hasChildren: kids.length > 0,
                    // 叶子自己：禁用时不参与勾选传播（官方 disableStrictly）
                    leafKeys: kids.length > 0 ? leafKeys : (node.disabled === true ? [] : [node.key]),
                });
                if (kids.length > 0)
                    walk(kids, depth + 1, ancestors.concat([node.key]));
            }
        };
        walk(Array.isArray(control.dataSource) ? control.dataSource : [], 0, []);
        return out;
    }

    // 官方给树的是 defaultExpandAll，所以折叠状态反过来记
    function isExpanded(key) {
        return control._collapsed[key] !== true;
    }

    function toggleExpand(key) {
        const next = {};
        for (const k in control._collapsed)
            next[k] = control._collapsed[k];
        next[key] = !control._collapsed[key];
        control._collapsed = next;
    }

    readonly property var treeRows: control.visibleTreeRows()

    function visibleTreeRows() {
        const out = [];
        const nodes = control.treeNodes;
        for (let i = 0; i < nodes.length; ++i) {
            const ancestors = nodes[i].ancestors;
            let blocked = false;
            for (let a = 0; a < ancestors.length; ++a) {
                if (!control.isExpanded(ancestors[a])) {
                    blocked = true;
                    break;
                }
            }
            if (!blocked)
                out.push(nodes[i]);
        }
        return out;
    }

    function nodeChecked(rec) {
        const keys = control.keyList();
        if (rec.hasChildren) {
            if (rec.leafKeys.length === 0)
                return false;
            for (let i = 0; i < rec.leafKeys.length; ++i) {
                if (keys.indexOf(rec.leafKeys[i]) < 0)
                    return false;
            }
            return true;
        }
        return keys.indexOf(rec.key) >= 0;
    }

    function nodeHalfChecked(rec) {
        if (!rec.hasChildren)
            return false;
        const keys = control.keyList();
        let hit = 0;
        for (let i = 0; i < rec.leafKeys.length; ++i) {
            if (keys.indexOf(rec.leafKeys[i]) >= 0)
                hit += 1;
        }
        return hit > 0 && hit < rec.leafKeys.length;
    }

    // 官方 handleMultipleSelect + calcCheckedStatus（disableStrictly）：子孙里有禁用项时，
    // 目标态不是「取反」而是「未禁用的子孙是否已全勾」
    function toggleTreeNode(rec) {
        if (!control.interactive || rec.disabled)
            return;
        const keys = control.keyList().slice();
        const leaves = rec.leafKeys;
        let allOn = leaves.length > 0;
        for (let i = 0; i < leaves.length; ++i) {
            if (keys.indexOf(leaves[i]) < 0) {
                allOn = false;
                break;
            }
        }
        const target = !allOn;
        for (let i = 0; i < leaves.length; ++i) {
            const at = keys.indexOf(leaves[i]);
            if (target && at < 0)
                keys.push(leaves[i]);
            else if (!target && at >= 0)
                keys.splice(at, 1);
        }
        const vals = [];
        for (let i = 0; i < keys.length; ++i) {
            const d = control.dataByKey(keys[i]);
            if (d !== null)
                vals.push(d.value);
        }
        control.handleTreeSelect(vals);
    }

    // 官方 filteredKeys：树里命中搜索词的节点自己（含祖先展开），命中处高亮
    function treeMatched(rec) {
        if (!control.inSearch)
            return false;
        const custom = control.pick(control.treeProps, "filterTreeNode", undefined);
        if (typeof custom === "function")
            return Boolean(custom(control._input, rec.label));
        return typeof rec.label === "string" && rec.label.indexOf(control._input) >= 0;
    }

    function treeLeafCount() {
        if (control.type !== "treeList")
            return undefined;
        let n = 0;
        for (let i = 0; i < control._data.length; ++i) {
            if (control._data[i].isLeaf === true)
                n += 1;
        }
        return n;
    }

    // ---------------------------------------------------------------- 右面板派生
    readonly property bool showClearButton: {
        if (control.selected.length === 0)
            return false;
        return control.selected.filter(i => i.disabled !== true).length > 0;
    }

    function rightLabel(item) {
        if (item === undefined || item === null)
            return "";
        // 官方 _generatePath：path 里每级 label 用 " > " 连
        if (control.type === "treeList" && control.showPath
            && item.path !== undefined && item.path !== null && item.path.length > 0) {
            const parts = [];
            for (let i = 0; i < item.path.length; ++i)
                parts.push(item.path[i].label);
            return parts.join(" > ");
        }
        return item.label;
    }

    readonly property bool useVirtualList: control.isObj("virtualize")
        && Object.keys(control.virtualize).length > 0
        && !control.draggable && control.renderSelectedItem === null
        && control.renderSelectedPanel === null
    readonly property real virtualItemSize: {
        const n = control.pick(control.virtualize, "itemSize", 36);
        return typeof n === "number" && n > 0 ? n : 36;
    }

    // ---------------------------------------------------------------- 拖拽排序
    function setRow(index, row) {
        const a = control._rows.slice();
        a[index] = row;
        control._rows = a;
    }

    function clearRow(row) {
        const a = control._rows.slice();
        for (let i = 0; i < a.length; ++i) {
            if (a[i] === row)
                a[i] = undefined;
        }
        control._rows = a;
    }

    function beginDrag(index, h) {
        control._dragIndex = index;
        control._dropIndex = index;
        control._dragHeight = h;
    }

    // 官方 collisionDetection=closestCenter：被拖行的中心和各行布局中心比
    function updateDrop(index, centerY) {
        let best = index;
        let bestDist = Infinity;
        for (let i = 0; i < control._rows.length; ++i) {
            const row = control._rows[i];
            if (row === undefined || row === null)
                continue;
            const d = Math.abs(row.y + row.height / 2 - centerY);
            if (d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
        control._dropIndex = best;
    }

    function shiftFor(index) {
        if (control._dragIndex < 0 || index === control._dragIndex)
            return 0;
        if (control._dragIndex < control._dropIndex
            && index > control._dragIndex && index <= control._dropIndex)
            return -control._dragHeight;
        if (control._dragIndex > control._dropIndex
            && index < control._dragIndex && index >= control._dropIndex)
            return control._dragHeight;
        return 0;
    }

    function endDrag() {
        const from = control._dragIndex;
        const to = control._dropIndex;
        control._dragIndex = -1;
        control._dropIndex = -1;
        control._dragHeight = 0;
        if (from >= 0 && to >= 0 && from !== to)
            control.sortEnd(from, to);
    }

    // ---------------------------------------------------------------- 播种
    // 官方只在 constructor 里拿 defaultValue 播一次；这里 dataSource 可能是后到的，
    // 所以「用户还没动过选区」时跟着 _data 重播（和官方的差异记在 PROGRESS 坑 80）。
    // 光靠 on_DataChanged 不够：dataSource 和 defaultValue 同一批写进来时 _data
    // 只算一次、不会发变更信号，所以完成时也要播一次。
    function seedDefaults() {
        if (!control.controlled && !control._touched)
            control._keys = control.keysOfValues(control.defaultValue);
    }

    Component.onCompleted: control.seedDefaults()

    on_DataChanged: control.seedDefaults()

    // ---------------------------------------------------------------- 外观令牌
    readonly property real inputHeight: Appearance.inputWrapperHeight(
        Theme.current, control.pick(control.inputProps, "size", Enums.Default))
    readonly property real headerHeight: 24                 // $height-transfer_header
    readonly property real rightHeaderHeight: 32            // $height-transfer_right_header
    readonly property real emptyHeight: 36                  // $height-transfer_left_empty
    readonly property string totalText: control.fillToken(
        qsTr("总个数：${total}"), control.showNumber)
    readonly property string selectedText: control.fillToken(
        qsTr("已选个数：${total}"), control.selected.length)

    function fillToken(token, n) {
        return String(token).replace("${total}", String(n));
    }

    // 槽位高度：没渲染的那一段占 0，下面的槽位跟着上移
    readonly property real filterSlotHeight: control.filterShown ? 12 + control.inputHeight : 0
    readonly property real leftHeaderSlotHeight: control.leftMode !== "list" ? 0
        : (control.renderSourceHeader !== null
            ? sourceHeaderLoader.implicitHeight : 12 + control.headerHeight + 8)
    readonly property real paginationSlotHeight: control.paginationShown
        ? Theme.current.spacingBaseTight * 2 + Theme.current.heightControlDefault : 0
    readonly property real rightHeaderSlotHeight: control.renderSelectedHeader !== null
        ? selectedHeaderLoader.implicitHeight : Theme.current.spacingBaseTight + control.rightHeaderHeight
    readonly property real virtualWidth: {
        const w = control.pick(control.virtualize, "width", undefined);
        return typeof w === "number" ? w : rightPanel.width;
    }
    // 官方 height 允许 '100%'（AutoSizer 自适应），QML 里没有字符串高度，
    // 非数字一律按「头部以下剩余高度」处理
    readonly property real virtualHeight: {
        const h = control.pick(control.virtualize, "height", undefined);
        return typeof h === "number"
            ? h : Math.max(0, rightPanel.height - control.rightHeaderSlotHeight);
    }

    // ---------------------------------------------------------------- 外框
    Rectangle {
        id: frame

        objectName: "frame"
        anchors.fill: parent
        visible: !control.customPanel
        color: Theme.current.colorBg1                     // $color-transfer-bg
        radius: Theme.current.radiusMedium                // $radius-transfer
        border.width: 1                                   // $width-transfer-border
        border.color: Theme.current.colorBorder           // $color-transfer-border
    }

    // 完全自定义渲染：两个面板由用户接管，外框无描边、尺寸跟着内容（-custom-panel）
    Row {
        id: customRow

        visible: control.customPanel
        spacing: 0

        Loader {
            id: sourcePanelLoader

            objectName: "sourcePanelLoader"
            active: control.customPanel
            visible: control.customPanel
            sourceComponent: control.renderSourcePanel
            onItemChanged: control.injectSourcePanel(item)

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "value"
                value: control.notifyValues()
            }

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "loading"
                value: control.loading
            }

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "noMatch"
                value: control.noMatch
            }

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "filterData"
                value: control.filterData
            }

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "sourceData"
                value: control._data
            }

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "propsDataSource"
                value: control.dataSource
            }

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "allChecked"
                value: control.leftAll.allChecked
            }

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "showNumber"
                value: control.showNumber
            }

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "inputValue"
                value: control._input
            }

            Binding {
                target: sourcePanelLoader.item
                when: sourcePanelLoader.item !== null
                property: "selectedItems"
                value: control.selected
            }
        }

        Loader {
            id: selectedPanelLoader

            active: control.customPanel
            visible: control.customPanel
            sourceComponent: control.renderSelectedPanel
            onItemChanged: control.injectSelectedPanel(item)

            Binding {
                target: selectedPanelLoader.item
                when: selectedPanelLoader.item !== null
                property: "length"
                value: control.selected.length
            }

            Binding {
                target: selectedPanelLoader.item
                when: selectedPanelLoader.item !== null
                property: "selectedData"
                value: control.selected
            }
        }
    }

    // ---------------------------------------------------------------- 面板体
    Item {
        id: bodyHost

        objectName: "bodyHost"
        x: 1
        y: 1
        width: Math.max(0, control.width - 2)
        height: Math.max(0, control.height - 2)
        visible: !control.customPanel
        clip: true

        // ---- 左面板（width 50%，右缘 1px 分隔线）----
        Item {
            id: leftPanel

            objectName: "leftPanel"
            width: Math.floor(bodyHost.width / 2)
            height: bodyHost.height

            // 搜索框：官方只有左栏有，margin 12/12/0/12
            Item {
                id: filterSlot

                objectName: "filterSlot"
                width: leftPanel.width
                height: control.filterSlotHeight
                visible: control.filterShown

                Input {
                    id: filterInput

                    objectName: "filterInput"
                    x: 12
                    y: 12
                    width: Math.max(0, leftPanel.width - 24)
                    height: control.inputHeight
                    size: control.pick(control.inputProps, "size", Enums.Default)
                    placeholderText: String(control.pick(control.inputProps,
                        "placeholder", qsTr("搜索")))
                    prefixIcon: "search"
                    showClear: control.pick(control.inputProps, "showClear", true) == true
                    enabled: control.interactive
                    onTextChanged: {
                        if (text !== control._input)
                            control.handleInputChange(text, true);
                    }
                }

                // 官方是受控 Input（value=state.inputValue）。用户敲字会写断外层绑定，
                // 所以用 Binding 元素：依赖一变就把值写回来。
                Binding {
                    target: filterInput
                    property: "text"
                    value: control._input
                    restoreMode: Binding.RestoreBindingOrValue
                }
            }

            // 头部：总个数 + 全选/取消全选（treeList 不给出按钮）
            Item {
                id: leftHeaderSlot

                objectName: "leftHeaderSlot"
                y: control.filterSlotHeight
                width: leftPanel.width
                height: control.leftHeaderSlotHeight
                visible: control.leftMode === "list"

                Item {
                    id: leftHeader

                    objectName: "leftHeader"
                    x: 12
                    y: 12
                    width: Math.max(0, leftPanel.width - 24)
                    height: control.headerHeight
                    visible: control.renderSourceHeader === null

                    Text {
                        id: leftTotal

                        objectName: "leftTotal"
                        anchors.verticalCenter: parent.verticalCenter
                        text: control.totalText
                        color: control.interactive
                            ? Theme.current.colorText2              // $color-transfer_header-text
                            : Theme.current.colorDisabledText       // .semi-transfer-disabled -header
                        font.pixelSize: Theme.current.fontSizeSmall // @include font-size-small
                    }

                    Button {
                        id: leftAllButton

                        objectName: "leftAllButton"
                        anchors.verticalCenter: parent.verticalCenter
                        x: leftTotal.width + Theme.current.spacingBase  // -header-all margin-left 16
                        visible: control.leftAll.showButton
                        text: control.leftAll.allChecked ? qsTr("取消全选") : qsTr("全选")
                        tone: Enums.Tertiary
                        variant: Enums.Borderless
                        size: Enums.Small
                        enabled: control.interactive
                        onClicked: control.handleAll(!control.leftAll.allChecked)
                    }
                }

                Loader {
                    id: sourceHeaderLoader

                    objectName: "sourceHeaderLoader"
                    active: control.renderSourceHeader !== null
                    visible: control.renderSourceHeader !== null
                    sourceComponent: control.renderSourceHeader
                    onItemChanged: control.injectSourceHeader(item)

                    // 官方头部 div 是块级元素，宽度跟着面板走；根项自己只声明 implicitHeight
                    Binding {
                        target: sourceHeaderLoader.item
                        when: sourceHeaderLoader.item !== null
                        property: "width"
                        value: leftHeaderSlot.width
                    }

                    Binding {
                        target: sourceHeaderLoader.item
                        when: sourceHeaderLoader.item !== null
                        property: "num"
                        value: control.showNumber
                    }

                    Binding {
                        target: sourceHeaderLoader.item
                        when: sourceHeaderLoader.item !== null
                        property: "showButton"
                        value: control.leftAll.showButton
                    }

                    Binding {
                        target: sourceHeaderLoader.item
                        when: sourceHeaderLoader.item !== null
                        property: "allChecked"
                        value: control.leftAll.allChecked
                    }

                    Binding {
                        target: sourceHeaderLoader.item
                        when: sourceHeaderLoader.item !== null
                        property: "leafOnlyNum"
                        value: control.treeLeafCount()
                    }
                }
            }

            // 分页：padding $spacing-base-tight(12)、水平居中
            // （官方只在 list/groupList 且总页数 > 1 时出）
            Item {
                id: paginationSlot

                objectName: "paginationSlot"
                anchors.bottom: leftPanel.bottom
                width: leftPanel.width
                height: control.paginationSlotHeight
                visible: control.paginationShown

                Pagination {
                    id: leftPagination

                    objectName: "leftPagination"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    total: control.filterData.length
                    pageSize: control.pageSize
                    currentPage: control.currentPage

                    // 给了 currentPage 就是受控档（官方 'currentPage' in props）：翻页器自己
                    // 不动页码，只发信号，所以外层那条绑定不会被挣断
                    onChange: page => control.changePage(page)
                }
            }

            // 列表 / 树 / 加载 / 空态
            Item {
                id: leftBody

                objectName: "leftBody"
                y: control.filterSlotHeight + control.leftHeaderSlotHeight
                width: leftPanel.width
                height: Math.max(0, leftPanel.height
                    - control.filterSlotHeight - control.leftHeaderSlotHeight
                    - control.paginationSlotHeight)
                clip: true

                // 官方 case loading：整块换成 Spin（头部一起消失）
                Spin {
                    id: leftSpin

                    objectName: "leftSpin"
                    anchors.centerIn: parent
                    visible: control.leftMode === "loading"
                }

                // 官方 .semi-transfer-left-empty：width 100%、height 36、居中、small、text-2
                Text {
                    id: leftEmpty

                    objectName: "leftEmpty"
                    width: parent.width
                    height: control.emptyHeight
                    visible: control.leftMode === "empty" || control.leftMode === "noMatch"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: control.leftMode === "noMatch"
                        ? String(control.pick(control.emptyContent, "search", qsTr("无搜索结果")))
                        : String(control.pick(control.emptyContent, "left", qsTr("暂无数据")))
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                // ---- 列表（list / groupList）----
                Flickable {
                    id: leftFlick

                    objectName: "leftFlick"
                    width: leftBody.width
                    height: leftBody.height
                    visible: control.leftMode === "list" && control.type !== "treeList"
                    contentHeight: leftList.height
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: leftList

                        objectName: "leftList"
                        width: leftFlick.width

                        Repeater {
                            model: control.leftRows

                            delegate: Item {
                                id: leftRow

                                required property var modelData
                                required property int index

                                readonly property bool isGroup: modelData.kind === "group"
                                readonly property var item: modelData.item
                                readonly property bool custom: control.renderSourceItem !== null
                                readonly property bool off: !control.interactive
                                    || (leftRow.item !== undefined && leftRow.item.disabled === true)

                                objectName: isGroup ? "groupTitle" : "leftRow" + index
                                width: leftList.width
                                height: isGroup ? 28 : Math.max(36,
                                    custom ? sourceLoader.implicitHeight : rowCheck.implicitHeight)

                                Rectangle {
                                    objectName: "leftRowBg" + leftRow.index

                                    anchors.fill: parent
                                    visible: !leftRow.isGroup && !leftRow.custom
                                    color: leftRow.off
                                        ? "transparent"
                                        : (rowCheck.pressed ? Theme.current.colorFill1
                                            : (leftHover.hovered ? Theme.current.colorFill0 : "transparent"))
                                }

                                // 整行的悬浮带（含左右 12/9 的内边距）；按下态只能从行内
                                // 那个 Checkbox 拿 —— 它就是官方 .semi-transfer-item 本身
                                HoverHandler {
                                    id: leftHover

                                    enabled: !leftRow.isGroup
                                }

                                // 分组标题：height 28、padding-left $spacing-base-tight、small、text-2
                                Text {
                                    objectName: "groupTitleText"

                                    visible: leftRow.isGroup
                                    anchors.verticalCenter: parent.verticalCenter
                                    leftPadding: Theme.current.spacingBaseTight
                                    text: leftRow.isGroup ? leftRow.modelData.title : ""
                                    color: Theme.current.colorText2
                                    font.pixelSize: Theme.current.fontSizeSmall
                                }

                                // 默认条目：一个占满整行的 Checkbox
                                // （官方把 .semi-transfer-item 直接挂在 Checkbox 上）
                                Checkbox {
                                    id: rowCheck

                                    objectName: "leftCheck" + leftRow.index
                                    visible: !leftRow.isGroup && !leftRow.custom
                                    x: Theme.current.spacingBaseTight           // padding-left 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, leftRow.width
                                        - Theme.current.spacingBaseTight - 9)   // padding-right 9
                                    text: leftRow.item === undefined ? "" : String(leftRow.item.label)
                                    disabled: !control.interactive
                                        || (leftRow.item !== undefined && leftRow.item.disabled === true)

                                    Binding {
                                        target: rowCheck
                                        property: "checked"
                                        value: control.isSelected(leftRow.item)
                                        restoreMode: Binding.RestoreBindingOrValue
                                    }

                                    onToggled: control.selectOrRemove(leftRow.item)
                                }

                                Loader {
                                    id: sourceLoader

                                    objectName: "sourceLoader" + leftRow.index
                                    active: !leftRow.isGroup && leftRow.custom
                                    visible: active
                                    sourceComponent: control.renderSourceItem
                                    onItemChanged: control.injectSourceItem(item, leftRow.item)

                                    // 官方 renderSourceItem 的根节点是块级元素：宽度铺满整行，
                                    // 高度由根项自己的 implicitHeight 决定（.semi-transfer-item 只给 min-height）
                                    Binding {
                                        target: sourceLoader.item
                                        when: sourceLoader.item !== null
                                        property: "width"
                                        value: leftRow.width
                                    }

                                    Binding {
                                        target: sourceLoader.item
                                        when: sourceLoader.item !== null
                                        property: "modelData"
                                        value: leftRow.item
                                    }

                                    Binding {
                                        target: sourceLoader.item
                                        when: sourceLoader.item !== null
                                        property: "checked"
                                        value: control.isSelected(leftRow.item)
                                    }

                                    Binding {
                                        target: sourceLoader.item
                                        when: sourceLoader.item !== null
                                        property: "hovered"
                                        value: leftHover.hovered
                                    }

                                    Binding {
                                        target: sourceLoader.item
                                        when: sourceLoader.item !== null
                                        property: "index"
                                        value: leftRow.index
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- 树（treeList）----
                Flickable {
                    id: treeFlick

                    objectName: "treeFlick"
                    width: leftBody.width
                    height: leftBody.height
                    visible: control.leftMode === "list" && control.type === "treeList"
                    contentHeight: treeList.height + 16
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: treeList

                        objectName: "treeList"
                        y: 8
                        width: treeFlick.width

                        Repeater {
                            model: control.treeRows

                            delegate: Item {
                                id: treeRow

                                required property var modelData
                                required property int index

                                readonly property real indent: Theme.current.spacingTight
                                    + treeRow.modelData.depth * 20
                                readonly property bool matched: control.inSearch
                                    && control.treeMatched(treeRow.modelData)

                                objectName: "treeRow" + index
                                width: treeList.width
                                height: 28

                                Rectangle {
                                    anchors.fill: parent
                                    color: treeHover.hovered && !treeRow.modelData.disabled
                                        ? Theme.current.colorFill0 : "transparent"
                                }

                                HoverHandler {
                                    id: treeHover
                                }

                                Icon {
                                    id: treeCaret

                                    objectName: "treeCaret" + treeRow.index
                                    width: 12
                                    height: 12
                                    x: treeRow.indent
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: treeRow.modelData.hasChildren
                                    name: "chevron_right"
                                    size: 12
                                    color: Theme.current.colorText2
                                    rotation: control.isExpanded(treeRow.modelData.key) ? 90 : 0

                                    TapHandler {
                                        onTapped: control.toggleExpand(treeRow.modelData.key)
                                    }
                                }

                                Checkbox {
                                    id: treeCheck

                                    objectName: "treeCheck" + treeRow.index
                                    x: treeRow.indent + 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    disabled: !control.interactive || treeRow.modelData.disabled
                                    indeterminate: control.nodeHalfChecked(treeRow.modelData)

                                    Binding {
                                        target: treeCheck
                                        property: "checked"
                                        value: control.nodeChecked(treeRow.modelData)
                                        restoreMode: Binding.RestoreBindingOrValue
                                    }

                                    onToggled: control.toggleTreeNode(treeRow.modelData)
                                }

                                Text {
                                    objectName: "treeLabel" + treeRow.index

                                    visible: !treeRow.matched
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: treeRow.indent + 18 + 24
                                    width: Math.max(0, treeRow.width - treeRow.indent - 42)
                                    text: String(treeRow.modelData.label)
                                    color: treeRow.modelData.disabled
                                        ? Theme.current.colorDisabledText : Theme.current.colorText0
                                    font.pixelSize: Theme.current.fontSizeRegular
                                    elide: Text.ElideRight
                                }

                                // 命中搜索词的节点文本高亮（官方 filtered → <Highlight>）
                                Highlight {
                                    objectName: "treeMatch" + treeRow.index

                                    visible: treeRow.matched
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: treeRow.indent + 18 + 24
                                    sourceString: String(treeRow.modelData.label)
                                    searchWords: [control._input]
                                }
                            }
                        }
                    }
                }
            }
        }

        // 左右面板之间 1px 分隔线（$width-transfer_left-border = $border-thickness-control）
        Rectangle {
            objectName: "divider"

            x: leftPanel.width - Theme.current.borderThicknessControl
            y: 0
            width: Theme.current.borderThicknessControl
            height: bodyHost.height
            color: Theme.current.colorBorder
        }

        // ---- 右面板（width 50%）----
        Item {
            id: rightPanel

            objectName: "rightPanel"
            x: leftPanel.width
            width: Math.max(0, bodyHost.width - leftPanel.width)
            height: bodyHost.height

            Item {
                id: rightHeaderSlot

                objectName: "rightHeaderSlot"
                width: rightPanel.width
                height: control.rightHeaderSlotHeight

                Item {
                    id: rightHeader

                    objectName: "rightHeader"
                    x: 12
                    y: Theme.current.spacingBaseTight      // -right-header margin-top 8
                    width: Math.max(0, rightPanel.width - 24)
                    height: control.rightHeaderHeight
                    visible: control.renderSelectedHeader === null

                    Text {
                        id: rightTotal

                        objectName: "rightTotal"
                        anchors.verticalCenter: parent.verticalCenter
                        text: control.selectedText
                        color: control.interactive
                            ? Theme.current.colorText2 : Theme.current.colorDisabledText
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Button {
                        id: rightClearButton

                        objectName: "rightClearButton"
                        anchors.verticalCenter: parent.verticalCenter
                        x: rightTotal.width + Theme.current.spacingBase
                        visible: control.showClearButton
                        text: qsTr("清空")
                        tone: Enums.Tertiary
                        variant: Enums.Borderless
                        size: Enums.Small
                        enabled: control.interactive
                        onClicked: control.clearAll()
                    }
                }

                Loader {
                    id: selectedHeaderLoader

                    objectName: "selectedHeaderLoader"
                    active: control.renderSelectedHeader !== null
                    visible: control.renderSelectedHeader !== null
                    sourceComponent: control.renderSelectedHeader
                    onItemChanged: control.injectSelectedHeader(item)

                    Binding {
                        target: selectedHeaderLoader.item
                        when: selectedHeaderLoader.item !== null
                        property: "width"
                        value: rightHeaderSlot.width
                    }

                    Binding {
                        target: selectedHeaderLoader.item
                        when: selectedHeaderLoader.item !== null
                        property: "num"
                        value: control.selected.length
                    }

                    Binding {
                        target: selectedHeaderLoader.item
                        when: selectedHeaderLoader.item !== null
                        property: "showButton"
                        value: control.showClearButton
                    }
                }
            }

            // 官方 .semi-transfer-right-empty 是 absolute + height:100%，
            // 即从头部下方起算再撑满一个面板高，文字落在偏下的位置
            Text {
                id: rightEmpty

                objectName: "rightEmpty"
                y: control.rightHeaderSlotHeight
                width: rightPanel.width
                height: rightPanel.height
                visible: control.selected.length === 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: String(control.pick(control.emptyContent,
                    "right", qsTr("暂无内容，可从左侧勾选")))
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
            }

            Flickable {
                id: rightFlick

                objectName: "rightFlick"
                y: control.rightHeaderSlotHeight
                width: rightPanel.width
                height: Math.max(0, rightPanel.height - control.rightHeaderSlotHeight)
                visible: control.selected.length > 0 && !control.useVirtualList
                contentHeight: rightList.height
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: rightList

                    objectName: "rightList"
                    width: rightFlick.width

                    Repeater {
                        model: control.selected

                        delegate: TransferRightItem {
                            id: rightRow

                            required property var modelData
                            required property int index

                            objectName: "rightRow" + index
                            transfer: control
                            rowData: modelData
                            rowIndex: index
                            width: rightList.width
                            height: implicitHeight
                            shift: control.shiftFor(index)

                            Component.onCompleted: control.setRow(index, rightRow)
                            Component.onDestruction: control.clearRow(rightRow)
                        }
                    }
                }
            }

            // virtualize：官方用 react-window，QML 的等价物就是 ListView。
            // 必须整块包在 Loader 里 —— ListView 只要挂了 model 就会建代理，
            // 平时（不开虚拟化）让它存在就等于把右侧列表重复渲染一遍。
            Loader {
                id: rightVirtualHost

                objectName: "rightVirtualHost"
                active: control.useVirtualList
                sourceComponent: rightVirtualComponent
                y: control.rightHeaderSlotHeight
                width: control.virtualWidth
                height: control.virtualHeight
                visible: control.selected.length > 0
            }

            Component {
                id: rightVirtualComponent

                ListView {
                    id: rightVirtual

                    objectName: "rightVirtual"
                    width: control.virtualWidth
                    height: control.virtualHeight
                    model: control.selected
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    delegate: TransferRightItem {
                        id: virtualRow

                        required property var modelData
                        required property int index

                        objectName: "virtualRow" + index
                        transfer: control
                        rowData: modelData
                        rowIndex: index
                        width: rightVirtual.width
                        height: control.virtualItemSize
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- 钩子注入
    // 函数入参只能直接赋值：Binding 的 value 给函数时，即使 when:false 也会报
    // 「Unable to assign a function to a property of any type other than a var」
    function injectSourceItem(item, row) {
        if (item === null)
            return;
        item.toggle = function () { control.selectOrRemove(row); };
    }

    function injectSourceHeader(item) {
        if (item === null)
            return;
        item.allClick = function () { control.handleAll(!control.leftAll.allChecked); };
    }

    function injectSelectedHeader(item) {
        if (item === null)
            return;
        item.clear = function () { control.clearAll(); };
    }

    function injectSourcePanel(item) {
        if (item === null)
            return;
        item.search = function (text) { control.handleInputChange(String(text), true); };
        item.allClick = function () { control.handleAll(!control.leftAll.allChecked); };
        item.selectOrRemove = function (row) { control.selectOrRemove(row); };
        item.selectValues = function (vals) { control.handleTreeSelect(vals); };
    }

    function injectSelectedPanel(item) {
        if (item === null)
            return;
        item.clear = function () { control.clearAll(); };
        item.remove = function (row) { control.selectOrRemove(row); };
        item.sortEnd = function (props) { control.sortEnd(props.oldIndex, props.newIndex); };
    }

    // SourcePanelProps.value 要的就是 onChange 回抛的那份 values
    function notifyValues() {
        const keys = control.keyList();
        const out = [];
        for (let i = 0; i < keys.length; ++i) {
            const d = control.dataByKey(keys[i]);
            if (d !== null)
                out.push(d.value);
        }
        return out;
    }
}
