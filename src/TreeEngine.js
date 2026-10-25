.pragma library

// Tree 的算法内核 —— semi-foundation/tree/treeUtil.ts 的逐条移植（674 行那份）。
//
// 只做纯计算，不碰任何 QML 类型，所以能放进 `.pragma library` 当无状态模块用。
// TreeSelect 里那份同源代码是它自己的一版（口径有几处偏差，见 TreeSelect.qml 头注释），
// 这一份严格按上游逐行对齐；等 TreeSelect 换内核时再并过来。
//
// 移植时统一的取舍：
//   · 官方用 Set / 数组存键集，这边一律用**纯对象** `{ key: true }`（QML 里 var 属性
//     换对象才会发 changed，Set  mutate 不会），取值走 `keysOf(set)`；
//   · 官方 `get(obj, name, fallback)`（lodash）只用在「单层键」上，端口写成
//     `obj[name] !== undefined ? obj[name] : fallback`，语义一致；
//   · 官方 `calcDropRelativePosition(event, treeNode)` 读 `event.clientY` 和
//     `nodeInstance.getBoundingClientRect()`，QML 没有这两个东西：改成收三个数字
//     `(clientY, top, height)`，判定式和 DRAG_OFFSET 原样保留；
//   · lodash 的 `pick` 只拷「键存在」的字段（值为 undefined 但键不存在也不算），
//     端口用 `hasOwn` 对齐 —— 这条直接影响 disableStrictly 的覆盖顺序。

// strings.JSON_KEY_SPLIT（constants.ts:11）
var JSON_KEY_SPLIT = "_SEMI_TREE_SPLIT_";
// treeUtil.ts:34
var DRAG_OFFSET = 0.45;

// ---------------------------------------------------------------- 小工具

function hasOwn(obj, name) {
    return obj !== undefined && obj !== null
        && Object.prototype.hasOwnProperty.call(obj, name);
}

// treeUtil.ts:40-42
function isValid(val) {
    return val !== null && val !== undefined;
}

// treeUtil.ts:36-38
function getPosition(level, index) {
    return `${level}-${index}`;
}

// keyMaps 取真实键名：get(keyMaps, 'key', 'key')
function realName(keyMaps, field) {
    if (keyMaps === undefined || keyMaps === null)
        return field;
    const v = keyMaps[field];
    return v === undefined || v === null ? field : v;
}

// lodash pick（只拷存在的键）
function pick(obj, names) {
    const out = {};
    if (obj === undefined || obj === null)
        return out;
    for (let i = 0; i < names.length; ++i) {
        if (hasOwn(obj, names[i]))
            out[names[i]] = obj[names[i]];
    }
    return out;
}

// lodash get(obj, singleKey, fallback)
function get(obj, name, fallback) {
    if (obj === undefined || obj === null)
        return fallback;
    const v = obj[name];
    return v === undefined ? fallback : v;
}

function toSet(list) {
    const out = {};
    if (list === undefined || list === null)
        return out;
    // 已经是一张表（对象）时原样拷一份，避免调用方 mutate
    if (!(list instanceof Array)) {
        for (const k in list)
            out[k] = true;
        return out;
    }
    for (let i = 0; i < list.length; ++i)
        out[list[i]] = true;
    return out;
}

function keysOf(set) {
    const out = [];
    if (set === undefined || set === null)
        return out;
    for (const k in set)
        out.push(k);
    return out;
}

function setHas(set, key) {
    return set !== undefined && set !== null && set[key] === true;
}

function copySet(src) {
    const out = {};
    if (src === undefined || src === null)
        return out;
    for (const k in src)
        out[k] = src[k];
    return out;
}

// qmlcachegen 的解析器不收对象/数组展开语法（`{...x}` / `[...a, b]` 直接
// "Unexpected token ..."），下面这几处用显式拷贝代替
function shallowCopy(src) {
    const out = {};
    if (src === undefined || src === null)
        return out;
    for (const k in src)
        out[k] = src[k];
    return out;
}

function assignAll(target, src) {
    if (src === undefined || src === null)
        return target;
    for (const k in src)
        target[k] = src[k];
    return target;
}

function concatArr(a, b) {
    const out = [];
    for (let i = 0; i < a.length; ++i)
        out.push(a[i]);
    for (let j = 0; j < b.length; ++j)
        out.push(b[j]);
    return out;
}

function isEmptyVal(val) {
    if (val === undefined || val === null)
        return true;
    if (typeof val === "string" || val instanceof Array)
        return val.length === 0;
    if (typeof val === "object")
        return Object.keys(val).length === 0;
    return false;
}

// 官方 renderNodeList 的门槛是 `!virtualize || isEmpty(virtualize)` ⇒ 空对象等于没开
function isPlainObject(val) {
    return val !== undefined && val !== null && !(val instanceof Array)
        && typeof val === "object" && Object.keys(val).length > 0;
}

// lodash uniq
function uniq(list) {
    const out = [];
    const seen = {};
    for (let i = 0; i < list.length; ++i) {
        const v = list[i];
        if (seen[v] !== true) {
            seen[v] = true;
            out.push(v);
        }
    }
    return out;
}

// lodash difference（保持 a 的顺序）
function difference(a, b) {
    const bSet = toSet(b);
    const out = [];
    for (let i = 0; i < a.length; ++i) {
        if (!setHas(bSet, a[i]))
            out.push(a[i]);
    }
    return out;
}

// ---------------------------------------------------------------- convertDataToEntities

// treeUtil.ts:128-160
function traverseDataNodes(treeNodes, callback, keyMaps) {
    const realKeyName = realName(keyMaps, "key");
    const realChildrenName = realName(keyMaps, "children");

    function processNode(node, ind, parent) {
        const children = node ? node[realChildrenName] : treeNodes;
        const pos = node ? getPosition(parent.pos, ind) : "0";
        if (node) {
            const nodeKey = get(node, realKeyName, null);
            callback({
                data: shallowCopy(node),
                ind: ind,
                pos: pos,
                key: nodeKey !== null ? nodeKey : pos,
                parentPos: parent.node ? parent.pos : null,
                level: Number(parent.level) + 1,
            });
        }
        if (children) {
            for (let i = 0; i < children.length; ++i) {
                processNode(children[i], i, {
                    node: node,
                    pos: pos,
                    level: parent ? Number(parent.level) + 1 : -1,
                });
            }
        }
    }
    processNode(null, undefined, undefined);
}

// treeUtil.ts:163-195
function convertDataToEntities(dataNodes, keyMaps) {
    const posEntities = {};
    const keyEntities = {};
    const valueEntities = {};
    const realValueName = realName(keyMaps, "value");

    traverseDataNodes(dataNodes, (data) => {
        const pos = data.pos;
        const key = data.key;
        const parentPos = data.parentPos;
        const entity = shallowCopy(data);
        // 上游是 get(entity, `data.${realValueName}`, null)；端口的 get() 只吃单层键，逐层取
        const realValue = entity.data === undefined || entity.data === null
            ? null : get(entity.data, realValueName, null);
        if (realValue !== null)
            valueEntities[realValue] = key;

        posEntities[pos] = entity;
        keyEntities[key] = entity;

        entity.parent = isValid(parentPos) ? posEntities[parentPos] : undefined;
        if (entity.parent) {
            entity.parent.children = entity.parent.children || [];
            entity.parent.children.push(entity);
        }
    }, keyMaps);

    return { posEntities: posEntities, keyEntities: keyEntities, valueEntities: valueEntities };
}

// ---------------------------------------------------------------- flattenTreeData

// treeUtil.ts:51-99。filteredShown 是 false 或一张键表。
function flattenTreeData(treeNodeList, expandedSet, keyMaps, filteredShown = false) {
    const flattenList = [];
    const filterSearch = Boolean(filteredShown);
    const realKeyName = realName(keyMaps, "key");
    const realChildrenName = realName(keyMaps, "children");
    if (treeNodeList === undefined)
        return [];

    function flatten(list, parent = null) {
        const out = [];
        for (let index = 0; index < list.length; ++index) {
            const treeNode = list[index];
            const pos = getPosition(parent ? parent.pos : "0", index);
            const mergedKey = treeNode[realKeyName];
            const otherData = {};
            if (keyMaps) {
                for (const key in keyMaps) {
                    if (key === "children")
                        continue;
                    const result = treeNode[keyMaps[key]];
                    if (result !== undefined)
                        otherData[key] = result;
                }
            }

            const isEndList = [];
            if (parent) {
                for (let e = 0; e < parent.isEnd.length; ++e)
                    isEndList.push(parent.isEnd[e]);
            }
            isEndList.push(index === list.length - 1);

            const flattenNode = assignAll(assignAll({},
                pick(treeNode, ["key", "label", "value", "icon", "disabled", "isLeaf"])), otherData);
            flattenNode.parent = parent;
            flattenNode.pos = pos;
            flattenNode.children = null;
            flattenNode.data = treeNode;
            flattenNode._innerDataTag = true;
            flattenNode.isEnd = isEndList;
            const isBooleanFilteredShown = typeof filteredShown === "boolean";
            const shown = !filterSearch || (!isBooleanFilteredShown && setHas(filteredShown, mergedKey));
            if (shown)
                flattenList.push(flattenNode);

            if (setHas(expandedSet, mergedKey) && shown)
                flattenNode.children = flatten(treeNode[realChildrenName] || [], flattenNode);
            else
                flattenNode.children = [];
            out.push(flattenNode);
        }
        return out;
    }

    flatten(treeNodeList);
    return flattenList;
}

// ---------------------------------------------------------------- treeDataSimpleJson

// treeUtil.ts:101-123
function convertJsonToData(treeJson) {
    const treeData = [];

    function traverseNode(key, children, path, res) {
        const currPath = concatArr(path, [key]);
        const itemKey = currPath.join(JSON_KEY_SPLIT);
        const newNode = {
            key: itemKey,
            label: key,
            value: children,
        };
        if (children !== null && typeof children === "object") {
            const newChildren = [];
            for (const name in children) {
                traverseNode(name, children[name], currPath, newChildren);
            }
            newNode.children = newChildren;
        }
        res.push(newNode);
    }

    if (treeJson === undefined || treeJson === null)
        return treeData;
    for (const name in treeJson)
        traverseNode(name, treeJson[name], [], treeData);
    return treeData;
}

// ---------------------------------------------------------------- 找键

// treeUtil.ts:226-248
function findDescendantKeys(selectedKeys, keyEntities, self = true) {
    const res = [];

    function findChild(item) {
        if (!item)
            return;
        const children = item.children;
        if (isValid(children)) {
            for (let i = 0; i < children.length; ++i) {
                res.push(children[i].key);
                findChild(keyEntities[children[i].key]);
            }
        }
    }

    for (let i = 0; i < selectedKeys.length; ++i) {
        if (self)
            res.push(selectedKeys[i]);
        findChild(keyEntities[selectedKeys[i]]);
    }
    return res;
}

// treeUtil.ts:250-264
function findChildKeys(keys, keyEntities, omitKeys = []) {
    const res = [];
    if (!keys)
        return res;
    for (let i = 0; i < keys.length; ++i) {
        const opts = keyEntities[keys[i]];
        if (opts && opts.children) {
            for (let c = 0; c < opts.children.length; ++c) {
                const child = opts.children[c];
                if (!omitKeys.length || omitKeys.indexOf(child.key) < 0)
                    res.push(child.key);
            }
        }
    }
    return res;
}

// treeUtil.ts:267-287
function findLeafKeys(keys, keyEntities) {
    const res = [];

    function findChild(item) {
        if (!item)
            return;
        if (!isValid(item.children))
            res.push(item.key);
        else {
            for (let i = 0; i < item.children.length; ++i)
                findChild(keyEntities[item.children[i].key]);
        }
    }
    for (let i = 0; i < keys.length; ++i)
        findChild(keyEntities[keys[i]]);
    return res;
}

// treeUtil.ts:289-299
function findSiblingKeys(selectedKeys, keyEntities, self = true) {
    const par = [];
    for (let i = 0; i < selectedKeys.length; ++i) {
        const item = selectedKeys[i];
        if (keyEntities[item] && keyEntities[item].parent)
            par.push(keyEntities[item].parent.key);
    }
    return findChildKeys(uniq(par), keyEntities, self ? [] : selectedKeys);
}

// treeUtil.ts:301-317
function findAncestorKeys(selectedKeys, keyEntities, self = true) {
    const res = [];

    function findPar(item) {
        if (item.parent) {
            res.push(item.parent.key);
            findPar(item.parent);
        }
    }
    for (let i = 0; i < selectedKeys.length; ++i) {
        const item = selectedKeys[i];
        if (keyEntities[item])
            findPar(keyEntities[item]);
        if (self)
            res.push(item);
    }
    return res;
}

// treeUtil.ts:319-333
function getSortedKeyList(keyList, keyEntities) {
    const levelMap = {};
    for (let i = 0; i < keyList.length; ++i) {
        const key = keyList[i];
        if (!keyEntities[key])
            continue;
        const level = keyEntities[key].level;
        if (levelMap[level])
            levelMap[level].push(key);
        else
            levelMap[level] = [key];
    }
    return levelMap;
}

// ---------------------------------------------------------------- 勾选联动

// treeUtil.ts:335-384。values 是键数组，返回两张键表。
function calcCheckedKeys(values, keyEntities) {
    const keyList = values instanceof Array ? values : [values];
    const descendantKeys = findDescendantKeys(keyList, keyEntities, true);
    let checkedSet = toSet(descendantKeys);
    let halfSet = {};
    let visited = [];
    const levelMap = getSortedKeyList(keyList, keyEntities);

    function calcCurrLevel(node) {
        const key = node.key;
        const parent = node.parent;
        const level = node.level;
        if (!parent || visited.indexOf(key) >= 0)
            return;
        const siblingKeys = findSiblingKeys([key], keyEntities);
        visited = concatArr(visited, siblingKeys);
        let allChecked = true;
        for (let i = 0; i < siblingKeys.length; ++i) {
            if (!setHas(checkedSet, siblingKeys[i])) {
                allChecked = false;
                break;
            }
        }
        if (!allChecked) {
            const ancestorKeys = findAncestorKeys([key], keyEntities, false);
            for (let i = 0; i < ancestorKeys.length; ++i)
                halfSet[ancestorKeys[i]] = true;
        } else {
            checkedSet[parent.key] = true;
            // 上游注释：parent 的层级可能不在原 levelMap 里，直接追加会打乱层级顺序
            if (level - 1 in levelMap && level)
                levelMap[level - 1].push(parent.key);
            else
                levelMap[level - 1] = [parent.key];
        }
    }

    while (Object.keys(levelMap).length) {
        let maxLevel = 0;
        const levels = Object.keys(levelMap);
        for (let i = 0; i < levels.length; ++i)
            maxLevel = Math.max(maxLevel, Number(levels[i]));
        const list = levelMap[maxLevel];
        for (let i = 0; i < list.length; ++i)
            calcCurrLevel(keyEntities[list[i]]);
        delete levelMap[maxLevel];
    }

    return { checkedKeys: checkedSet, halfCheckedKeys: halfSet };
}

// treeUtil.ts:509-534
function calcCheckedKeysForChecked(key, keyEntities, checkedSet, halfSet) {
    const descendantKeys = findDescendantKeys([key], keyEntities, true);
    const nodeItem = keyEntities[key];
    checkedSet = copySet(checkedSet);
    checkedSet[key] = true;
    halfSet = copySet(halfSet);

    function calcCurrLevel(node) {
        if (!node.parent)
            return;
        const nodeKey = node.key;
        const siblingKeys = findSiblingKeys([nodeKey], keyEntities);
        let allChecked = true;
        for (let i = 0; i < siblingKeys.length; ++i) {
            if (!setHas(checkedSet, siblingKeys[i])) {
                allChecked = false;
                break;
            }
        }
        if (!allChecked) {
            const ancestorKeys = findAncestorKeys([nodeKey], keyEntities, false);
            for (let i = 0; i < ancestorKeys.length; ++i)
                halfSet[ancestorKeys[i]] = true;
        } else {
            const par = node.parent;
            checkedSet[par.key] = true;
            calcCurrLevel(par);
        }
    }
    calcCurrLevel(nodeItem);

    const merged = copySet(checkedSet);
    for (let i = 0; i < descendantKeys.length; ++i)
        merged[descendantKeys[i]] = true;
    return { checkedKeys: merged, halfCheckedKeys: halfSet };
}

// treeUtil.ts:536-586
function calcCheckedKeysForUnchecked(key, keyEntities, checkedSet, halfSet) {
    const descendantKeys = findDescendantKeys([key], keyEntities, true);
    const nodeItem = keyEntities[key];
    checkedSet = copySet(checkedSet);
    halfSet = copySet(halfSet);

    for (let i = 0; i < descendantKeys.length; ++i) {
        const descendantKey = descendantKeys[i];
        delete checkedSet[descendantKey];
        delete halfSet[descendantKey];
    }

    function calcCurrLevel(node) {
        const par = node.parent;
        if (!par)
            return;
        if (!setHas(checkedSet, par.key) && !setHas(halfSet, par.key))
            return;
        const nodeKey = node.key;
        const siblingKeys = findSiblingKeys([nodeKey], keyEntities);
        let anyChecked = false;
        for (let i = 0; i < siblingKeys.length; ++i) {
            if (setHas(checkedSet, siblingKeys[i]) || setHas(halfSet, siblingKeys[i])) {
                anyChecked = true;
                break;
            }
        }
        const ancestorKeys = findAncestorKeys([nodeKey], keyEntities, false);
        if (anyChecked) {
            for (let i = 0; i < ancestorKeys.length; ++i) {
                if (setHas(checkedSet, ancestorKeys[i])) {
                    delete checkedSet[ancestorKeys[i]];
                    halfSet[ancestorKeys[i]] = true;
                }
            }
        } else {
            delete checkedSet[par.key];
            delete halfSet[par.key];
            calcCurrLevel(par);
        }
    }
    if (nodeItem)
        calcCurrLevel(nodeItem);

    return { checkedKeys: checkedSet, halfCheckedKeys: halfSet };
}

// treeUtil.ts:645-650。严格禁用时「禁用键 + 其全部子孙 + 兄弟全禁用的父级」。
function calcDisabledKeys(keyEntities, keyMaps) {
    const disabledName = realName(keyMaps, "disabled");
    const disabledKeys = [];
    for (const key in keyEntities) {
        if (keyEntities[key].data[disabledName])
            disabledKeys.push(key);
    }
    return calcCheckedKeys(disabledKeys, keyEntities).checkedKeys;
}

// ---------------------------------------------------------------- 展开

// treeUtil.ts:387-396
function calcExpandedKeys(keyList, keyEntities, autoExpandParent = true) {
    let list = keyList;
    if (!(list instanceof Array))
        list = [list];
    if (autoExpandParent)
        return toSet(findAncestorKeys(list, keyEntities, true));
    return toSet(list);
}

// treeUtil.ts:399-402。注意 findAncestorKeys(..., false)：只展开选中项的**祖先**，不含它自己。
function calcExpandedKeysForValues(value, keyEntities, isMultiple, valueEntities) {
    const keys = findKeysForValues(value, valueEntities, isMultiple);
    return toSet(findAncestorKeys(keys, keyEntities, false));
}

// treeUtil.ts:199-224
function findKeysForValues(valueList, valueEntities, isMultiple = false) {
    if (!isValid(valueList))
        return [];
    let list = valueList;
    if (!isMultiple && list instanceof Array)
        list = list.length ? [list[0]] : [];
    else if (!(list instanceof Array))
        list = [list];

    if (isEmptyVal(valueEntities))
        return list;

    const res = [];
    for (let i = 0; i < list.length; ++i) {
        const val = list[i];
        if (hasOwn(valueEntities, val))
            res.push(valueEntities[val]);
        else if (val)
            res.push(val);
    }
    return res;
}

// treeUtil.ts:404-425
function calcMotionKeys(oldKeySet, newKeySet, keyEntities) {
    let motionType = "show";
    const oldKeys = keysOf(oldKeySet);
    const newKeys = keysOf(newKeySet);

    if (Math.abs(oldKeys.length - newKeys.length) !== 1)
        return { motionType: motionType, motionKeys: [] };

    let diffKeys = [];
    if (oldKeys.length > newKeys.length) {
        motionType = "hide";
        diffKeys = difference(oldKeys, newKeys);
    } else {
        diffKeys = difference(newKeys, oldKeys);
    }

    return {
        motionType: diffKeys.length === 1 ? motionType : "show",
        motionKeys: diffKeys.length === 1 ? findDescendantKeys(diffKeys, keyEntities, false) : [],
    };
}

// treeUtil.ts:492-507
function getMotionKeys(eventKey, expandedSet, keyEntities) {
    const res = [];

    function getChild(itemKey) {
        const kids = keyEntities[itemKey].children;
        if (kids) {
            for (let i = 0; i < kids.length; ++i) {
                const key = kids[i].key;
                res.push(key);
                if (setHas(expandedSet, key))
                    getChild(key);
            }
        }
    }
    getChild(eventKey);
    return res;
}

// ---------------------------------------------------------------- 搜索

// treeUtil.ts:430-449
function filter(sugInput, option, filterTreeNode, filterProps) {
    if (!filterTreeNode)
        return true;
    let filterFn = filterTreeNode;
    let target = option;
    if (typeof filterTreeNode === "boolean") {
        filterFn = (targetVal, val) => {
            const input = String(targetVal).toLowerCase();
            return val === undefined || val === null
                ? false : String(val).toLowerCase().includes(input);
        };
    }
    if (filterProps)
        target = option[filterProps];
    return filterFn(sugInput, target, option);
}

// 命中搜索条件的键（foundation.ts:537-539 那一句 Object.values(keyEntities).filter().map()）
function filteredOptionKeys(keyEntities, sugInput, filterTreeNode, filterProp) {
    const res = [];
    for (const key in keyEntities) {
        const item = keyEntities[key];
        if (filter(sugInput, item.data, filterTreeNode, filterProp))
            res.push(item.key);
    }
    return res;
}

// treeUtil.ts:588-619
function filterTreeData(info) {
    const showFilteredOnly = info.showFilteredOnly;
    const keyEntities = info.keyEntities;
    const inputValue = info.inputValue;
    const treeData = info.treeData;
    const filterTreeNode = info.filterTreeNode;
    const filterProps = info.filterProps;
    const prevExpandedKeys = info.prevExpandedKeys;
    const keyMaps = info.keyMaps;

    const filteredOptsKeys = filteredOptionKeys(keyEntities, inputValue, filterTreeNode, filterProps);
    let expandedOptsKeys = findAncestorKeys(filteredOptsKeys, keyEntities, false);
    if (prevExpandedKeys.length) {
        const prevValid = [];
        for (let i = 0; i < prevExpandedKeys.length; ++i) {
            if (Boolean(keyEntities[prevExpandedKeys[i]]))
                prevValid.push(prevExpandedKeys[i]);
        }
        expandedOptsKeys = expandedOptsKeys.concat(prevValid);
    }
    const shownChildKeys = findDescendantKeys(filteredOptsKeys, keyEntities, true);
    const filteredShownKeys = toSet(concatArr(shownChildKeys, expandedOptsKeys));
    const flattenNodes = flattenTreeData(
        treeData, toSet(expandedOptsKeys), keyMaps, showFilteredOnly ? filteredShownKeys : false);

    return {
        flattenNodes: flattenNodes,
        filteredKeys: toSet(filteredOptsKeys),
        filteredExpandedKeys: toSet(expandedOptsKeys),
        filteredShownKeys: filteredShownKeys,
    };
}

// ---------------------------------------------------------------- 取值 / 归一

// treeUtil.ts:451-457
function normalizedArr(val) {
    return !(val instanceof Array) ? [val] : val;
}

// treeUtil.ts:461-490
function normalizeKeyList(keyList, keyEntities, leafOnly = false, flag = undefined) {
    const res = [];
    const keyListSet = toSet(keyList);
    if (!leafOnly) {
        for (let i = 0; i < keyList.length; ++i) {
            const key = keyList[i];
            if (!keyEntities[key]) {
                if (flag)
                    res.push(key);
                continue;
            }
            const parent = keyEntities[key].parent;
            if (parent && setHas(keyListSet, parent.key))
                continue;
            res.push(key);
        }
    } else {
        for (let i = 0; i < keyList.length; ++i) {
            const key = keyList[i];
            if (keyEntities[key] && !isValid(keyEntities[key].children))
                res.push(key);
            if (!keyEntities[key] && flag)
                res.push(key);
        }
    }
    return res;
}

// treeUtil.ts:622-629
function getValueOrKey(data, keyMaps) {
    const valueName = realName(keyMaps, "value");
    const keyName = realName(keyMaps, "key");
    if (data instanceof Array) {
        const out = [];
        for (let i = 0; i < data.length; ++i) {
            const item = data[i];
            out.push(get(item, valueName, item === null || item === undefined
                ? undefined : item[keyName]));
        }
        return out;
    }
    return get(data, valueName, data === null || data === undefined ? undefined : data[keyName]);
}

// treeUtil.ts:632-638
function normalizeValue(value, withObject, keyMaps) {
    if (withObject && isValid(value))
        return getValueOrKey(value, keyMaps);
    return value;
}

// treeUtil.ts:640-643
function updateKeys(keySet, keyEntities) {
    return keysOf(keySet).filter((key) => hasOwn(keyEntities, key));
}

// ---------------------------------------------------------------- 拖拽

// treeUtil.ts:652-664。端口签名改成三个数字（见文件头取舍）：
// bottom = top + height，所以第二条是 clientY >= top + height*(1 - DRAG_OFFSET)。
function calcDropRelativePosition(clientY, top, height) {
    if (clientY <= top + height * DRAG_OFFSET)
        return -1;
    if (clientY >= top + height * (1 - DRAG_OFFSET))
        return 1;
    return 0;
}

// treeUtil.ts:666-668
function getDragNodesKeys(key, keyEntities) {
    return findDescendantKeys([key], keyEntities, true);
}

// treeUtil.ts:670-674
function calcDropActualPosition(pos, relativeDropPos) {
    const posArr = String(pos).split("-");
    return relativeDropPos + Number(posArr[posArr.length - 1]);
}

// ---------------------------------------------------------------- 过渡节点（nodeList.tsx:21-53）

// 返回数组，元素是「一个节点」或「一组要一起收放的节点」。
// 上游把 motionKeys 里连续的那一段抽成一个数组插在 rangeStart 位置，交给
// NodeCollapsible 套一层高度动画；顺序、空数组都照抄。
function buildTransitionNodes(flattenNodes, motionKeys, motionType, flattenList) {
    const motionArr = keysOf(motionKeys);
    if (!motionArr.length)
        return flattenNodes;
    const transitionNodes = [];
    const transitionRange = [];
    let rangeStart = 0;
    const lookUpTarget = motionType === "hide" && flattenList ? flattenList : flattenNodes;
    for (let ind = 0; ind < lookUpTarget.length; ++ind) {
        const treeNode = lookUpTarget[ind];
        const nodeKey = treeNode.key;
        if (setHas(motionKeys, nodeKey)) {
            transitionRange.push(treeNode);
            if (nodeKey === motionArr[0])
                rangeStart = ind;
        } else {
            transitionNodes.push(treeNode);
        }
    }
    if (!transitionRange.length)
        return flattenNodes;
    transitionNodes.splice(rangeStart, 0, transitionRange);
    return transitionNodes;
}

// ---------------------------------------------------------------- 行状态（foundation.ts）

// foundation.ts:387-439 getTreeNodeProps。s 是状态包（键表 / 键数组），opt 是属性包。
// 返回 null 表示这个键不在 keyEntities 里（上游此时直接不渲染这一行）。
function treeNodeProps(key, s, opt) {
    const entities = s.keyEntities || {};
    const entity = entities[key];
    if (!entity)
        return null;

    let realChecked = false;
    let realHalfChecked = false;
    if (opt.checkRelation === "related") {
        realChecked = setHas(s.checkedKeys, key);
        realHalfChecked = setHas(s.halfCheckedKeys, key);
    } else if (opt.checkRelation === "unRelated") {
        realChecked = setHas(s.realCheckedKeys, key);
        realHalfChecked = false;
    }

    const props = {
        eventKey: key,
        expanded: s.isSearching ? setHas(s.filteredExpandedKeys, key) : setHas(s.expandedKeys, key),
        selected: (s.selectedKeys || []).indexOf(key) >= 0,
        checked: realChecked,
        halfChecked: realHalfChecked,
        pos: String(entity.pos),
        level: entity.level,
        filtered: setHas(s.filteredKeys, key),
        loading: setHas(s.loadingKeys, key) && !setHas(s.loadedKeys, key),
        loaded: setHas(s.loadedKeys, key),
        keyword: s.inputValue,
        treeNodeFilterProp: opt.treeNodeFilterProp,
    };

    if (opt.disableStrictly && setHas(s.disabledKeys, key))
        props.disabled = true;

    return props;
}

// foundation.ts:582-599 handleSingleSelect。端口把「通知」和「改状态」拆开返回，
// 由 Tree.qml 决定先 emit 还是先赋值；官方那条「重复点同一个节点仍然
// onSelect(selected=true) 但不再 onChange」的不一致照抄在 notifySelected 上。
function singleSelect(key, selectedKeys, controlled) {
    const selected = (selectedKeys || []).indexOf(key) >= 0;
    const targetSelected = !selected;
    const res = {
        notifySelected: true,
        targetSelected: targetSelected,
        selectedKeys: (selectedKeys || []).slice(),
        notifyChange: false,
        updateState: false,
    };
    if (!targetSelected)
        return res;
    if (res.selectedKeys.indexOf(key) < 0) {
        res.selectedKeys = [key];
        res.notifyChange = true;
        res.updateState = !controlled;
    }
    return res;
}
