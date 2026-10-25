.pragma library

// Table 的数据流水线 —— semi-foundation/table/{foundation.ts,utils.ts} 的逐条移植。
//
// 只做纯计算，不碰任何 QML 类型，所以能放进 `.pragma library` 当无状态模块用。
// 顺序照 foundation.ts:getFilteredSortedDataSource → getCurrentPageData：
//     筛选 → 排序 → 分组 → 分页 → （行流：树形展开 / 展开行 / 组头行）
//
// 移植时统一的取舍：
//   · 官方用 Map / Set 存中间结果，`.pragma library` 这边按纯对象 + 数组写；
//   · 官方 sortDataSource / filterDataSource 会**就地改**传进去的 dataSource
//     （`dataSource.sort(...)`），端口一律先拷贝再算，免得改到调用方 var 数组上；
//   · 官方 assignColumnKeys 会往 column 对象上写 key，这里同样只写副本；
//   · 不做 shouldCellUpdate / cached / keepDOM 那几条：那是 React 的渲染期优化，
//     QML 的 delegate 复用由 ListView 自己管。

// ---------------------------------------------------------------- 列

// 官方 DEFAULT_KEY_COLUMN_SELECTION / _EXPAND（constants.ts:25-26）。
var KEY_SELECTION = "column-selection";
var KEY_EXPAND = "column-expand";
var KEY_TITLE = "column-title";

// 官方 assignColumnKeys（utils.ts:241-257）：没有 key 时用 `${level}-${dataIndex||index}` 兜。
function assignColumnKeys(columns, childrenName, level) {
    var out = [];
    var kids = [];
    for (var i = 0; i < columns.length; ++i) {
        var col = shallowCopy(columns[i]);
        if (col.key === undefined || col.key === null) {
            col.key = String(level) + "-" + (col.dataIndex !== undefined && col.dataIndex !== null
                ? col.dataIndex : i);
        }
        var children = col[childrenName];
        if (Array.isArray(children) && children.length) {
            col[childrenName] = assignColumnKeys(children, childrenName, level + 1);
            for (var j = 0; j < col[childrenName].length; ++j)
                kids.push(col[childrenName][j]);
        }
        out.push(col);
    }
    return out;
}

// 官方 flattenColumns（utils.ts:225-239）：把树状列拍平成叶子列。
function flattenColumns(columns, childrenName) {
    var list = [];
    for (var i = 0; i < columns.length; ++i) {
        var children = columns[i][childrenName];
        if (Array.isArray(children) && children.length)
            list = list.concat(flattenColumns(children, childrenName));
        else
            list.push(columns[i]);
    }
    return list;
}

function maxDepth(columns, childrenName) {
    var d = 0;
    for (var i = 0; i < columns.length; ++i) {
        var children = columns[i][childrenName];
        var sub = (Array.isArray(children) && children.length)
            ? 1 + maxDepth(children, childrenName) : 1;
        if (sub > d)
            d = sub;
    }
    return d;
}

// 表头网格 —— TableHeader.tsx:11-98 parseHeaderRows/fillRowCells 的逐条移植：
// colSpan 取子列之和、没有子列的列 rowSpan 到最后一行、column.colSpan/rowSpan 覆盖。
// 端口额外把每格换算成叶子列区间 [leafStart, leafStart+leafSpan)，因为 QML 侧
// 表头格是按 <colgroup> 的叶子宽度绝对定位的（官方交给 <th colSpan> 由浏览器铺）。
// 选择列 / 展开列不参与合并，调用方把它们单独当作第 0 层的一格处理。
function buildHeaderRows(columns, childrenName) {
    var depth = maxDepth(columns, childrenName);
    var rows = [];
    for (var r = 0; r < depth; ++r)
        rows.push([]);

    var leafCursor = 0;

    function spanOf(col, computed) {
        var override = col.colSpan !== undefined && col.colSpan !== null ? col.colSpan : undefined;
        return override !== undefined ? override : computed;
    }

    function walk(cols, level) {
        for (var i = 0; i < cols.length; ++i) {
            var col = cols[i];
            var children = col[childrenName];
            var isGroup = Array.isArray(children) && children.length > 0;
            var leafStart = leafCursor;
            var cell = {
                column: col,
                colSpan: 1,
                rowSpan: isGroup ? 1 : (depth - level),
                leafStart: leafStart,
                leafSpan: 1,
                hasSubColumns: isGroup,
                level: level
            };
            rows[level].push(cell);
            if (isGroup) {
                cell.rowSpan = 1;
                walk(children, level + 1);
            }
            // 官方在递归之后才落 colSpan，且游标按最终 colSpan 前进；
            // 叶子格递归为空，游标仍只前进 1。
            var span = spanOf(col, isGroup ? leafCursor - leafStart : 1);
            cell.colSpan = span;
            cell.leafSpan = span;
            if (!isGroup)
                leafCursor += span;
            if (col.rowSpan !== undefined && col.rowSpan !== null)
                cell.rowSpan = col.rowSpan;
        }
    }

    if (depth > 0)
        walk(columns, 0);
    return { rows: rows, depth: depth, leafTotal: leafCursor };
}

// ---------------------------------------------------------------- 行主键

// 官方 rowKey 两种写法（foundation.ts getRecordKey）：字符串取字段，函数调一下。
function recordKey(record, rowKey) {
    if (record === undefined || record === null)
        return undefined;
    if (typeof rowKey === "function")
        return rowKey(record);
    var name = (rowKey === undefined || rowKey === null || rowKey === "") ? "key" : rowKey;
    return record[name];
}

function recordKeys(records, rowKey) {
    var out = [];
    for (var i = 0; i < records.length; ++i)
        out.push(recordKey(records[i], rowKey));
    return out;
}

// 官方 _getRecordChildren：数组就原样返回，对象包一层。
function recordChildren(record, childrenName) {
    var children = record === undefined || record === null ? undefined : record[childrenName];
    if (Array.isArray(children))
        return children;
    if (children !== undefined && children !== null && typeof children === "object")
        return [children];
    return [];
}

// ---------------------------------------------------------------- 状态初始化

// 官方 initColumnsFilteredValueAndSorterOrder（foundation.ts:142-177）：
// filteredValue 缺省时落到 defaultFilteredValue，没有就给空数组；
// 有 sorter 且 sortOrder 未定义时落到 defaultSortOrder，没有就是 false。
function initQueries(columns) {
    var out = [];
    for (var i = 0; i < columns.length; ++i) {
        var col = columns[i];
        var q = {
            key: col.key,
            dataIndex: col.dataIndex,
            sorter: col.sorter,
            onFilter: col.onFilter,
            filterChildrenRecord: col.filterChildrenRecord,
            sortChildrenRecord: col.sortChildrenRecord,
            // 受控标记：调用方传了这两个字段就走受控，组件内部不改它。
            sortOrderControlled: col.sortOrder !== undefined,
            filteredValueControlled: col.filteredValue !== undefined,
            defaultSortOrder: col.defaultSortOrder !== undefined ? col.defaultSortOrder : false,
            defaultFilteredValue: Array.isArray(col.defaultFilteredValue) ? col.defaultFilteredValue : []
        };
        q.sortOrder = col.sortOrder !== undefined ? col.sortOrder
            : (col.sorter !== undefined ? q.defaultSortOrder : false);
        q.filteredValue = col.filteredValue !== undefined ? col.filteredValue : q.defaultFilteredValue;
        out.push(q);
    }
    return out;
}

// 列定义变了之后重算查询态：保留同 key 的当前值，新列按 default 初始化。
// 官方是靠 handleColumns(cachedColumns) 把 queries 往 columns 上回灌；这里反过来
// 以 columns 为准、按 key 合并旧值，语义一样（用户换了列引用就重来）。
function mergeQueries(columns, previous) {
    var fresh = initQueries(columns);
    if (!Array.isArray(previous))
        return fresh;
    for (var i = 0; i < fresh.length; ++i) {
        for (var j = 0; j < previous.length; ++j) {
            var old = previous[j];
            if (old === undefined)
                continue;
            if (sameKey(fresh[i].key, old.key) || (fresh[i].dataIndex !== undefined
                && fresh[i].dataIndex === old.dataIndex)) {
                if (!fresh[i].sortOrderControlled)
                    fresh[i].sortOrder = old.sortOrder;
                if (!fresh[i].filteredValueControlled)
                    fresh[i].filteredValue = old.filteredValue;
                break;
            }
        }
    }
    return fresh;
}

function sameKey(a, b) {
    return a !== undefined && b !== undefined && String(a) === String(b);
}

// ---------------------------------------------------------------- 筛选

// 官方 filterDataSource（foundation.ts:439-500）：
//   · 逐条 filter 串起来跑（列与列之间是「与」）；
//   · 同一列内多个筛选值是「或」，用 recordKey 去重（所以是 Map）；
//   · filterChildrenRecord 时先递归过滤子级，子级命中就保留父级并把命中的子级并回
//     父级 children 里（父级本身不命中也留）。
function filterDataSource(dataSource, filters, ctx) {
    var data = dataSource.slice();
    var anyValid = false;

    for (var f = 0; f < filters.length; ++f) {
        var filterObj = filters[f];
        if (typeof filterObj.onFilter !== "function")
            continue;
        var values = Array.isArray(filterObj.filteredValue) ? filterObj.filteredValue
            : (Array.isArray(filterObj.defaultFilteredValue) ? filterObj.defaultFilteredValue : []);
        if (!values.length)
            continue;

        anyValid = true;
        var stored = {};
        var order = [];

        for (var i = 0; i < data.length; ++i) {
            var record = data[i];
            var rawKey = recordKey(record, ctx.rowKey);
            var key = String(rawKey);

            for (var v = 0; v < values.length; ++v) {
                var kids = recordChildren(record, ctx.childrenName);
                var filteredKids = (kids.length && filterObj.filterChildrenRecord)
                    ? filterDataSource(kids, [filterObj], ctx) : [];

                if (filteredKids.length) {
                    if (rawKey === undefined || rawKey === null)
                        continue;
                    // 官方从 filteredData 里取回这一行已有的 children 再并，
                    // 所以同一行被多个筛选值命中时子级是累加的。
                    var prev = stored[key];
                    var merged = prev ? recordChildren(prev, ctx.childrenName) : [];
                    for (var n = 0; n < filteredKids.length; ++n) {
                        if (!containsSameKey(merged, recordKey(filteredKids[n], ctx.rowKey)))
                            merged.push(filteredKids[n]);
                    }
                    var copy = shallowCopy(record);
                    copy[ctx.childrenName] = merged;
                    if (stored[key] === undefined)
                        order.push(key);
                    stored[key] = copy;
                } else if (filterObj.onFilter(values[v], record)) {
                    if (stored[key] === undefined)
                        order.push(key);
                    stored[key] = record;
                }
            }
        }

        data = order.map(function (k) {
            return stored[k];
        });
    }

    return anyValid ? data : dataSource.slice();
}

// ---------------------------------------------------------------- 排序

// 官方 withOrderSort（foundation/utils.ts）：descend 就把比较结果取反。
function compareWithOrder(sorter, order) {
    return function (a, b) {
        var r = sorter(a, b, order);
        return order === "descend" ? -r : r;
    };
}

// 官方 sortDataSource（foundation.ts:378-409）：
//   · 按 sorters 数组顺序依次排（实际只有一个列有 sortOrder，见 handleSort）；
//   · currentSortOrder 无效时退 defaultSortOrder；
//   · sorter 不是函数（服务端排序 sorter:true）不排；
//   · sortChildrenRecord 先递归排每个 record 的子级，再排顶层。
function sortDataSource(dataSource, sorters, ctx) {
    var data = dataSource.slice();

    for (var s = 0; s < sorters.length; ++s) {
        var obj = sorters[s];
        if (obj === undefined || typeof obj.sorter !== "function")
            continue;
        var order = isValidSortOrder(obj.sortOrder) ? obj.sortOrder : obj.defaultSortOrder;
        if (!order || (order !== "ascend" && order !== "descend"))
            continue;

        if (obj.sortChildrenRecord) {
            data = data.map(function (record) {
                var kids = recordChildren(record, ctx.childrenName);
                if (kids.length) {
                    var copy = shallowCopy(record);
                    copy[ctx.childrenName] = sortDataSource(kids, [obj], ctx);
                    return copy;
                }
                return record;
            });
        }
        data.sort(compareWithOrder(obj.sorter, order));
    }

    return data;
}

function isValidSortOrder(order) {
    return order === "ascend" || order === "descend" || order === false;
}

// 官方 handleSort（foundation.ts:1243-1303）的循环规则：
// 点中的列 ascend → descend → false → ascend …；其它列一律置 false（只支持单列排序）。
function nextSortQueries(queries, dataIndex) {
    var out = [];
    var cur = null;
    for (var i = 0; i < queries.length; ++i) {
        var q = shallowCopy(queries[i]);
        if (q.sorter === undefined) {
            out.push(q);
            continue;
        }
        var order = isValidSortOrder(q.sortOrder) ? q.sortOrder : q.defaultSortOrder;
        if (q.dataIndex && q.dataIndex === dataIndex) {
            if (order === "ascend")
                order = "descend";
            else if (order === "descend")
                order = false;
            else
                order = "ascend";
            cur = q;
        } else {
            order = false;
        }
        q.sortOrder = order;
        out.push(q);
    }
    return { queries: out, current: cur };
}

// ---------------------------------------------------------------- 分组

// 官方 groupDataSource（foundation.ts:333-369）：按 groupBy 取组键，
// 组键为 null / '' 的行不进任何组；有组时把 dataSource 按组顺序重排。
function groupDataSource(dataSource, groupBy, ctx) {
    var groups = [];
    var index = {};
    var ordered = [];

    if (groupBy === undefined || groupBy === null)
        return { groups: groups, dataSource: dataSource.slice() };

    for (var i = 0; i < dataSource.length; ++i) {
        var record = dataSource[i];
        var key = typeof groupBy === "function" ? groupBy(record) : record[groupBy];
        if (key === undefined || key === null || key === "")
            continue;
        var slot = index[String(key)];
        if (slot === undefined) {
            slot = { key: key, recordKeys: [] };
            index[String(key)] = slot;
            groups.push(slot);
        }
        var rk = recordKey(record, ctx.rowKey);
        if (slot.recordKeys.indexOf(rk) < 0)
            slot.recordKeys.push(rk);
    }

    if (groups.length) {
        for (var g = 0; g < groups.length; ++g) {
            for (var k = 0; k < groups[g].recordKeys.length; ++k) {
                var rec = findRecord(dataSource, groups[g].recordKeys[k], ctx.rowKey);
                if (rec !== undefined)
                    ordered.push(rec);
            }
        }
    } else {
        ordered = dataSource.slice();
    }

    return { groups: groups, dataSource: ordered };
}

function findRecord(records, key, rowKey) {
    for (var i = 0; i < records.length; ++i)
        if (sameKey(recordKey(records[i], rowKey), key))
            return records[i];
    return undefined;
}

// ---------------------------------------------------------------- 分页

// 官方 normalizePagination（foundation.ts:521-554）。
// 受控判定：pagination 里给了 currentPage 就是受控（Table.tsx _pagerIsControlled）。
function normalizePagination(pagination, total, controlled) {
    if (pagination === false || pagination === undefined || pagination === null)
        return null;
    var p = (typeof pagination === "object") ? shallowCopy(pagination) : {};
    if (p.total === undefined)
        p.total = total;
    if (p.pageSize === undefined)
        p.pageSize = 10;                       // numbers.DEFAULT_PAGE_SIZE
    if (p.currentPage === undefined)
        p.currentPage = (p.defaultCurrentPage !== undefined ? p.defaultCurrentPage : 1);
    if (p.position === undefined)
        p.position = "bottom";                 // PAGINATION_POSITIONS[0]
    if (p.formatPageText === undefined)
        p.formatPageText = true;

    if (!controlled) {
        // total 优先取调用方显式给的（官方 get(prop,'total', dataSource.length)）。
        var realPages = Math.ceil(p.total / p.pageSize);
        if (p.currentPage > realPages)
            p.currentPage = 1;
    }
    return p;
}

// 官方 limitPageDataSource（foundation.ts:502-519）：只有非受控才真的切片。
function limitPageDataSource(dataSource, pagination, controlled) {
    if (pagination === null || controlled)
        return dataSource.slice();
    var size = pagination.pageSize !== undefined ? pagination.pageSize : 10;
    var page = pagination.currentPage;
    if (!page)
        return dataSource.slice();
    return dataSource.slice((page - 1) * size, page * size);
}

function paginationInfo(pagination, dataSource) {
    if (pagination === null)
        return { currentStart: 0, currentEnd: 0, total: dataSource.length };
    var size = pagination.pageSize;
    var page = pagination.currentPage;
    // 官方 formatPaginationInfo（foundation.ts:1175-1194）两头都夹在 total 里。
    var start = Math.min((page - 1) * size + 1, pagination.total);
    var end = Math.min(page * size, pagination.total);
    return { currentStart: start, currentEnd: end, total: pagination.total };
}

// ---------------------------------------------------------------- 行流

// 官方 mergedRowExpandable（Table.tsx:390-403）：
//   有子级或有 expandedRowRender ⇒ rowExpandable 没给就算可展开；
//   两者都没有 ⇒ 只有 rowExpandable(record) 亲口说可展开才算。
function recordExpandable(record, opts) {
    var hasKids = recordChildren(record, opts.childrenName).length > 0;
    var hasRender = opts.expandedRowRenderPresent === true;
    var hasFn = typeof opts.rowExpandable === "function";
    var strict = hasFn ? Boolean(opts.rowExpandable(record)) : false;
    return ((hasRender || hasKids) && (!hasFn || strict)) || (!(hasRender || hasKids) && strict);
}

// 官方 expandBtnShouldInRow（semi-foundation/table/utils.ts:343-357）：
// 决定「这一列的缩进要不要给不可展开的行也留一档」——
// 有 expandedRowRender 且不单独成列 ⇒ 一律留；否则看当页里有没有可展开的记录。
function expandBtnShouldInRow(pageData, opts) {
    var hasRender = opts.expandedRowRenderPresent === true;
    if (opts.hideExpandedColumn && hasRender)
        return true;
    if (hasRender)
        return false;
    for (var i = 0; i < pageData.length; ++i)
        if (recordExpandable(pageData[i], opts))
            return true;
    return false;
}

// 把「当页数据」摊成真正要画的那些行：
//   · 分组（groupBy）→ 每组前插一行 kind:'section'；组收起时整组不画；
//   · 树形（childrenRecordName）→ 展开的节点后面按序插子级，depth +1；
//   · 展开行（expandedRowRender）→ 该记录后面插一行 kind:'expand'。
// index 是这条记录在**它所属那一层数组**里的下标，与官方
// dataSource.map((record, index) => ...) 的 index 一致。
function buildRowStream(pageData, groups, opts) {
    var out = [];
    var seq = 0;

    function inKeys(keys, key) {
        for (var i = 0; i < keys.length; ++i)
            if (sameKey(keys[i], key))
                return true;
        return false;
    }

    function pushData(record, index, depth, groupKey) {
        var key = recordKey(record, opts.rowKey);
        var kids = recordChildren(record, opts.childrenName);
        var expandable = recordExpandable(record, opts);
        var hasRender = opts.expandedRowRenderPresent === true;
        var expanded = key !== undefined && inKeys(opts.expandedRowKeys, key);
        out.push({
            kind: "data",
            seq: seq++,
            record: record,
            key: key,
            index: index,
            depth: depth,
            groupKey: groupKey,
            hasChildren: kids.length > 0,
            // 树形子级与额外展开行共用同一个展开状态，但两件事各画各的：
            // 官方 Body 先按 record 渲染一行，expanded 时既插子级行、也插 expandedRowRender 那行。
            expandable: expandable,
            treeExpanded: expanded,
            // 官方 Body/index.tsx:860 插展开行的条件：hasExpandedRowRender && 可展开 && 已展开。
            rowExpanded: expanded && hasRender && expandable
        });
        if (expanded) {
            if (hasRender && expandable) {
                out.push({
                    kind: "expand", seq: seq++, record: record, key: key,
                    index: index, depth: depth, groupKey: groupKey
                });
            }
            for (var i = 0; i < kids.length; ++i)
                pushData(kids[i], i, depth + 1, groupKey);
        }
    }

    if (groups.length) {
        for (var g = 0; g < groups.length; ++g) {
            var group = groups[g];
            var open = inKeys(opts.expandedRowKeys, group.key);
            var members = [];
            for (var m = 0; m < group.recordKeys.length; ++m) {
                for (var d = 0; d < pageData.length; ++d) {
                    if (sameKey(recordKey(pageData[d], opts.rowKey), group.recordKeys[m])) {
                        members.push(pageData[d]);
                        break;
                    }
                }
            }
            out.push({
                kind: "section", seq: seq++, groupKey: group.key,
                recordKeys: group.recordKeys, count: members.length, expanded: open
            });
            if (!open)
                continue;
            for (var i2 = 0; i2 < members.length; ++i2)
                pushData(members[i2], i2, 0, group.key);
        }
    } else {
        for (var p = 0; p < pageData.length; ++p)
            pushData(pageData[p], p, 0, undefined);
    }

    return out;
}

// ---------------------------------------------------------------- 选择态

// 官方 unRelated 分支（foundation.ts:829-979）：
//   · 点行：selected 为真就把 key 推进集合，否则从集合里摘掉；
//   · 点全选：取**当页 allRowKeys**（已经过滤排序分页过的），跳过 disabled 的。
function selectRow(keys, key, selected) {
    var out = keys.slice();
    var at = indexOfKey(out, key);
    if (selected) {
        if (at < 0)
            out.push(key);
    } else if (at >= 0) {
        out.splice(at, 1);
    }
    return out;
}

function selectAllRows(keys, allKeys, disabledKeys, selected) {
    var out = keys.slice();
    if (selected) {
        for (var i = 0; i < allKeys.length; ++i) {
            if (indexOfKey(disabledKeys, allKeys[i]) < 0 && indexOfKey(out, allKeys[i]) < 0)
                out.push(allKeys[i]);
        }
    } else {
        for (var j = allKeys.length - 1; j >= 0; --j) {
            var at = indexOfKey(out, allKeys[j]);
            if (at >= 0)
                out.splice(at, 1);
        }
    }
    return out;
}

function indexOfKey(list, key) {
    for (var i = 0; i < list.length; ++i)
        if (sameKey(list[i], key))
            return i;
    return -1;
}

// checkRelation:'related' 的级联 —— 官方走的是 rc-tree 的 conductCheck
// （foundation.ts:839-865 / 906-952 调 calcCheckedKeysForChecked / ForUnchecked）。
// 那两个函数做的事可以完整等价地写成两步：
//   1. 传导向下：勾一个节点 = 把它和它整棵子树放进勾选集合；取消 = 整棵一起摘掉；
//      受控的 selectedRowKeys 里直接写父节点也走同一条（官方对整个入参集做 conduct），
//      所以这一步是对**入参里的每个 key** 展开子树，不只是刚被点那一个。
//   2. 传导向上：后序遍历，叶子看自己在不在集合里；有子级的节点，
//      子级全勾 → 自己勾，子级里有勾或半选 → 自己半选，否则不勾。
// 第 2 步每次全量重算，所以取消子级之后父节点的降级也是准的。
function conductCheck(records, inputKeys, ctx) {
    var keys = [];
    var list = inputKeys || [];
    for (var i = 0; i < list.length; ++i)
        collectSubtreeKeys(records, list[i], ctx, keys);

    var checked = [];
    var half = [];

    // 返回这一层节点是否全部为「勾」。
    function sweep(nodes) {
        var all = nodes.length > 0;
        for (var n = 0; n < nodes.length; ++n) {
            var node = nodes[n];
            var key = recordKey(node, ctx.rowKey);
            var kids = recordChildren(node, ctx.childrenName);
            var state;
            if (!kids.length) {
                state = indexOfKey(keys, key) >= 0 ? "all" : "none";
            } else {
                var kidsAll = sweep(kids);
                state = kidsAll ? "all"
                    : (kidsAny(checked, half, kids, ctx) ? "half" : "none");
            }
            if (state === "all" && !containsSameKey(checked, key))
                checked.push(key);
            else if (state === "half" && !containsSameKey(half, key))
                half.push(key);
            if (state !== "all")
                all = false;
        }
        return all;
    }

    sweep(records);
    return { checked: checked, half: half };
}

// 这一层子级里有没有勾上或半选的（父节点自身可能根本不在集合里）。
function kidsAny(checked, half, kids, ctx) {
    for (var i = 0; i < kids.length; ++i) {
        var key = recordKey(kids[i], ctx.rowKey);
        if (containsSameKey(checked, key) || containsSameKey(half, key))
            return true;
    }
    return false;
}

// 点某一行：把目标那一支的子树先加/摘，再全量重算（官方 handleSelectRow 同构）。
function collectAncestorKeys(records, targetKey, ctx, trail, out) {
    for (var i = 0; i < records.length; ++i) {
        var rec = records[i];
        var key = recordKey(rec, ctx.rowKey);
        var kids = recordChildren(rec, ctx.childrenName);
        if (sameKey(key, targetKey)) {
            for (var k = 0; k < trail.length; ++k)
                if (!containsSameKey(out, trail[k]))
                    out.push(trail[k]);
            return true;
        }
        if (kids.length) {
            trail.push(key);
            if (collectAncestorKeys(kids, targetKey, ctx, trail, out))
                return true;
            trail.pop();
        }
    }
    return false;
}

function cascadeKeys(records, checkedKeys, targetKey, checked, ctx) {
    var keys = (checkedKeys || []).slice();
    var subtree = [];
    collectSubtreeKeys(records, targetKey, ctx, subtree);

    for (var i = 0; i < subtree.length; ++i) {
        var at = indexOfKey(keys, subtree[i]);
        if (checked) {
            if (at < 0)
                keys.push(subtree[i]);
        } else if (at >= 0) {
            keys.splice(at, 1);
        }
    }

    // 取消勾选还得把祖先一并摘掉：conductCheck 会把「父在列表里」当成
    // 「整棵子树都选上」往下推，留着 p 就又把手刚取消的那条子级加回来了。
    if (!checked) {
        var up = [];
        collectAncestorKeys(records, targetKey, ctx, [], up);
        for (var u = 0; u < up.length; ++u) {
            var at2 = indexOfKey(keys, up[u]);
            if (at2 >= 0)
                keys.splice(at2, 1);
        }
    }

    return conductCheck(records, keys, ctx);
}

function collectSubtreeKeys(records, targetKey, ctx, out) {
    for (var i = 0; i < records.length; ++i) {
        var rec = records[i];
        var key = recordKey(rec, ctx.rowKey);
        var kids = recordChildren(rec, ctx.childrenName);
        if (sameKey(key, targetKey)) {
            if (!containsSameKey(out, key))
                out.push(key);
            collectAllKeys(kids, ctx, out);
            return true;
        }
        if (kids.length && collectSubtreeKeys(kids, targetKey, ctx, out))
            return true;
    }
    return false;
}

function collectAllKeys(records, ctx, out) {
    for (var i = 0; i < records.length; ++i) {
        var key = recordKey(records[i], ctx.rowKey);
        if (!containsSameKey(out, key))
            out.push(key);
        var kids = recordChildren(records[i], ctx.childrenName);
        if (kids.length)
            collectAllKeys(kids, ctx, out);
    }
}

function containsSameKey(list, key) {
    for (var i = 0; i < list.length; ++i)
        if (sameKey(list[i], key))
            return true;
    return false;
}

// 官方 getAllDisabledRowKeys（utils.ts:413-427）：getCheckboxProps(record).disabled
// 为真的行 key 进 disabled 列表，只看顶层。
function allDisabledRowKeys(records, getCheckboxProps, rowKey) {
    var out = [];
    if (typeof getCheckboxProps !== "function")
        return out;
    for (var i = 0; i < records.length; ++i) {
        var props = getCheckboxProps(records[i]);
        if (props !== undefined && props !== null && props.disabled)
            out.push(recordKey(records[i], rowKey));
    }
    return out;
}

// 表头全选框的三态：当页可选行全勾=checked，部分=indeterminate，全不=空。
function headerCheckState(selectedKeys, allKeys, disabledKeys) {
    var count = 0;
    var disabled = 0;
    for (var i = 0; i < allKeys.length; ++i) {
        if (indexOfKey(disabledKeys, allKeys[i]) >= 0) {
            disabled += 1;
            continue;
        }
        if (indexOfKey(selectedKeys, allKeys[i]) >= 0)
            count += 1;
    }
    var selectable = allKeys.length - disabled;
    if (selectable <= 0)
        return { checked: false, indeterminate: false };
    return {
        checked: count === selectable,
        indeterminate: count > 0 && count < selectable
    };
}

// ---------------------------------------------------------------- 列宽

// 指定了 width 的按 width，没指定的均分剩下的空间。官方是浏览器表格布局，
// 这里取「所有列都给宽时浏览器收敛成的样子」这条确定性路径。
// 返回每个内容列（含选择列 / 展开列）的像素宽。
function layoutColumns(columns, available) {
    var widths = [];
    var fixed = 0;
    var autoCount = 0;
    for (var i = 0; i < columns.length; ++i) {
        var w = toPixels(columns[i].width);
        if (w !== null) {
            widths.push(w);
            fixed += w;
        } else {
            widths.push(0);
            autoCount += 1;
        }
    }
    var free = available - fixed;
    if (autoCount > 0) {
        var each = free > 0 ? free / autoCount : 0;
        for (var j = 0; j < widths.length; ++j)
            if (widths[j] === 0)
                widths[j] = each;
    } else if (free > 0 && widths.length > 0) {
        // 全给了宽但比容器窄：官方表格 width:100% 会把多出来的空间分给自动列，
        // 没有自动列时浏览器按各列比例放大，这里把差额给最后一列（铺满容器）。
        widths[widths.length - 1] += free;
    }
    return widths;
}

function toPixels(width) {
    if (width === undefined || width === null)
        return null;
    if (typeof width === "number")
        return width;
    var s = String(width);
    if (s.indexOf("%") >= 0 || s === "max-content" || s === "auto")
        return null;
    var n = parseFloat(s);
    return isNaN(n) ? null : n;
}

// ---------------------------------------------------------------- 杂项

function shallowCopy(obj) {
    if (obj === undefined || obj === null || typeof obj !== "object")
        return obj;
    if (Array.isArray(obj))
        return obj.slice();
    var out = {};
    for (var k in obj)
        if (Object.prototype.hasOwnProperty.call(obj, k))
            out[k] = obj[k];
    return out;
}
