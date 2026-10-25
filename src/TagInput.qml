pragma ComponentBehavior: Bound

import QtQuick

// 标签输入框。回车把当前输入按分隔符切成若干标签；标签能单个删除、整批清空，
// 也能拖拽排序；标签过长会截断，悬停显示全文。
//
//     TagInput { defaultValue: ["抖音", "火山"]; placeholder: "请输入..." }
//     TagInput { value: tags; onChange: (v) => tags = v }
//
// 官方 API 面见 semi-ui/tagInput/index.tsx，交互见 semi-foundation/tagInput/foundation.ts，
// 外观见 tagInput.scss + variables.scss。几处对不上的地方写在注释里：
//   · 官方 disabled → Qt 的 enabled（与 Input / InputNumber 一致）；
//   · 官方用 `'value' in props` 判受控，QML 没有这个概念，按本仓库惯例拿 undefined
//     当「未传」，所以 `value: undefined` 是非受控、`value: []` 是受控的空数组；
//   · maxLength / max / maxTagCount 官方不传时不参与判断（isNumber），这里用 -1 表示未传；
//   · 官方点标签不会让 input 拿到焦点（点哪儿算哪儿），这里点框内任意处都能直接敲字。
//
// 尺寸 24 / 32 / 40（$height-tagInput-*），标签高 20 / 24（$height-tag_small/large），
// 标签与输入区上下外边距 1 / 2 / 3（$spacing-tagInput_*-Y），容器左右内边距 4。
Item {
    id: control

    // ---------------------------------------------------------------- 值
    property var value: undefined
    property var defaultValue: []
    property var inputValue: undefined
    property var _tags: Array.isArray(control.defaultValue) ? control.defaultValue.slice() : []
    // 官方 state.inputValue 的对应物：只在「这次变更被接受」时更新
    property string _lastInput: ""

    readonly property var tags: control.value !== undefined ? control.value : control._tags
    readonly property string inputText: control.inputValue !== undefined
        ? String(control.inputValue) : control._lastInput
    readonly property var visibleTagList: {
        const list = control.tagList();
        return control.collapsed ? list.slice(0, control.maxTagCount) : list;
    }
    readonly property var restTagList: control.collapsed
        ? control.tagList().slice(control.maxTagCount) : []
    readonly property int restCount: control.collapsed
        ? control.tagList().length - control.maxTagCount : 0

    // ---------------------------------------------------------------- 官方配置
    property string placeholder: ""
    property var separator: ","
    property var split: null
    property int maxLength: -1
    property int max: -1
    property int maxTagCount: -1
    property bool showRestTagsPopover: true
    property var restTagsPopoverProps: ({})
    // 官方 boolean | { type: 'tooltip' | 'popover', opts }
    property var showContentTooltip: true
    property bool allowDuplicates: true
    property bool addOnBlur: false
    property bool draggable: false
    property bool expandRestTagsOnClick: true
    property bool showClear: false
    property string clearIcon: ""
    property string insetLabel: ""
    property int size: Enums.Default
    property int validateStatus: Enums.StatusDefault
    // TreeSelect 把 TagInput 嵌在自己的触发器里，官方用 CSS 把这层的框抹掉
    // （treeSelect.scss:208-211 `.semi-tagInput { border: hidden; background: transparent }`）
    property bool borderless: false
    property bool autoFocus: false
    property string ariaLabel: ""
    // 官方 prefix / suffix 是 ReactNode：传 string 走 -text 那档（左右 12、加粗），
    // 传 Component 走自定义节点（左右 0）。官方靠 isSemiIcon 认出图标，QML 认不出来，
    // 所以另给两个 *Icon 名走 -icon 那档（左右 8）。
    property var prefix: undefined
    property var suffix: undefined
    property string prefixIcon: ""
    property string suffixIcon: ""
    // 官方 renderTagItem(value, index, onClose)。这里交一个 Component，约定它的根项
    // 自己声明 modelData / index / closeTag 三个属性，由下面显式注入
    // （与 Select.renderOption 同一套做法）。
    property Component renderTagItem: null

    // 分角圆角透给外框，InputGroup 要靠它们还原 .semi-input-group 的首尾圆角
    property real radius: Theme.current.radiusSmall
    property alias topLeftRadius: box.topLeftRadius
    property alias topRightRadius: box.topRightRadius
    property alias bottomLeftRadius: box.bottomLeftRadius
    property alias bottomRightRadius: box.bottomRightRadius

    // ---------------------------------------------------------------- 信号
    // 名字对齐官方回调，写起来就是 onChange / onAdd / onRemove / onInputChange /
    // onExceed / onInputExceed / onKeyDown。只有 onFocus / onBlur 对不上：
    // Item.focus 是现成属性，同名信号会让整个类型建不出来，所以按本仓库
    // DatePicker / TimePicker 的既有做法叫 focused / blurred。
    signal change(var tags)
    signal add(var tags)
    signal remove(string tag, int index)
    signal inputChange(string value)
    signal exceed(var tags)
    signal inputExceed(string value)
    signal focused
    signal blurred
    signal keyDown(int key, int modifiers)

    // ---------------------------------------------------------------- 内部状态
    // active 是官方那个「点过自身、还没点到外面」的开关，管两件事：
    // expandRestTagsOnClick 展开多余标签、draggable 开启拖拽（index.tsx:560-591）
    property bool active: false
    property var _rows: []
    property int contentHeight: 0
    property int dragIndex: -1
    property int dropIndex: -1
    property bool _laying: false

    readonly property bool focusing: field.activeFocus
    readonly property bool sortable: control.draggable && control.active
    // 折叠判定的现算版本：`collapsed` 是派生属性，在别的派生属性的变化信号里读它会
    // 吃到一帧滞后（坑 81），而 relayout() 正好要在 `visibleTagList` 刚变的那一刻问
    // 「这次要不要给 +N 排位置」—— 所以布局走函数，公开的 `collapsed` 只是它的镜像。
    function isCollapsed() {
        return !control.sortable
            && (!control.active || !control.expandRestTagsOnClick)
            && control.maxTagCount > 0 && control.tagList().length > control.maxTagCount;
    }

    readonly property bool collapsed: control.isCollapsed()
    // 官方 .semi-tagInput-focus 的条件是 focusing || active，两者都算聚焦态
    readonly property int controlState: Appearance.fieldState(control.enabled,
        control.focusing || control.active, hover.hovered, false)
    readonly property color surfaceColor: control.borderless
        ? "transparent" : Appearance.inputBackground(
            Theme.current, control.controlState, control.validateStatus)
    readonly property color borderColor: control.borderless
        ? "transparent" : Appearance.tagInputBorder(
            Theme.current, control.controlState, control.validateStatus)
    readonly property color foreground: Appearance.inputForeground(Theme.current, control.controlState)
    readonly property color iconColor: Appearance.inputIconColor(Theme.current, control.controlState)
    readonly property color placeholderColor: Appearance.inputPlaceholderColor(
        Theme.current, control.controlState)
    // showClear 时清除按钮永远占 32，只切 visibility（index.tsx:398-419 的 -invisible）：
    // 官方条件是 hovering && 有内容 && 未禁用，三者缺一个就只是「看不见」而不是「不占位」
    readonly property bool clearShown: control.showClear
    readonly property bool clearActive: control.showClear && control.enabled && hover.hovered
        && (control.inputText !== "" || control.tagList().length > 0)
    readonly property bool tooltipIsPopover: control.showContentTooltip !== undefined
        && control.showContentTooltip !== null && typeof control.showContentTooltip === "object"
        && control.showContentTooltip.type === "popover"
    readonly property bool contentTooltipOn: control.showContentTooltip !== false
        && control.showContentTooltip !== undefined && control.showContentTooltip !== null

    // 弹层是 C.Popup，不是 QQuickItem，测试里没法沿 children 找到；
    // 按 Select._popup 的老办法留三个内部句柄。
    readonly property var _contentTip: contentTip
    readonly property var _contentPop: contentPop
    readonly property var _restPop: restPop

    // ---------------------------------------------------------------- 槽位
    readonly property bool prefixIsNode: control.prefix instanceof Component
    readonly property bool prefixHasString: !control.prefixIsNode
        && typeof control.prefix === "string" && String(control.prefix) !== ""
    readonly property bool prefixIconShown: !control.prefixIsNode && control.prefixIcon !== ""
    // 官方 labelNode = prefix || insetLabel，两者抢同一个槽位
    readonly property bool prefixTextShown: !control.prefixIsNode && !control.prefixIconShown
        && (control.prefixHasString || control.insetLabel !== "")
    readonly property string prefixTextValue: control.prefixHasString
        ? String(control.prefix) : control.insetLabel
    readonly property bool suffixIsNode: control.suffix instanceof Component
    readonly property bool suffixIconShown: !control.suffixIsNode && control.suffixIcon !== ""
    readonly property bool suffixTextShown: !control.suffixIsNode && !control.suffixIconShown
        && typeof control.suffix === "string" && String(control.suffix) !== ""

    // ---------------------------------------------------------------- 尺寸令牌
    readonly property int tagHeight: control.size === Enums.Small ? 20 : 24
    // $spacing-tagInput_small-Y(1px) / default-Y(=super-tight 2px) / large-Y(3px)
    readonly property int tagMarginY: control.size === Enums.Small
        ? 1 : (control.size === Enums.Large ? 3 : Theme.current.spacingSuperTight)
    readonly property int rowHeight: control.tagHeight + control.tagMarginY * 2
    readonly property int minHeight: Appearance.inputWrapperHeight(Theme.current, control.size)
    readonly property int tagGap: Theme.current.spacingExtraTight      // margin-right 4
    // 自定义节点（renderTagItem）官方不带 `-wrapper-tag` 那层，横向外边距是 0；
    // 但嵌进 TreeSelect 时 `.semi-treeselect-selection .semi-tag { margin: 1px 2px }`
    // 又给它补回左右各 2（treeSelect.scss:156-158 + variables.scss:72）。
    // 所以这个数由外层给：独立 TagInput 留 0，TreeSelect 传 spacing-super-tight。
    property real tagMarginX: 0
    readonly property int wrapperPad: Theme.current.spacingExtraTight  // wrapper 左右 4
    // 内层 input 是 padding-left:0 / padding-right:12（semi.css:23358），镜像量的宽度
    // 含这 12，所以能写字的区 = 输入区宽 - 12
    readonly property int fieldPadRight: Theme.current.spacingBaseTight
    // 空值时官方输入区的宽 = min-width 2 + padding-right 12
    readonly property int fieldMinWidth: 2 + Theme.current.spacingBaseTight
    readonly property int restHeight: 20                                // +N 的行盒
    readonly property int textGap: Theme.current.spacingBaseTight       // 12
    readonly property int iconGap: Theme.current.spacingTight           // 8
    readonly property real clearWidth: Theme.current.widthIconMedium * 2 // $width-tagInput-clear-medium
    readonly property real prefixSlotWidth: control.prefixIsNode
        ? prefixLoader.implicitWidth
        : (control.prefixIconShown ? control.iconGap * 2 + Theme.current.widthIconMedium
            : (control.prefixTextShown ? prefixText.implicitWidth + control.textGap * 2 : 0))
    readonly property real suffixSlotWidth: control.suffixIsNode
        ? suffixLoader.implicitWidth
        : (control.suffixIconShown ? control.iconGap * 2 + Theme.current.widthIconMedium
            : (control.suffixTextShown ? suffixText.implicitWidth + control.textGap * 2 : 0))

    implicitWidth: 240
    implicitHeight: Math.max(control.minHeight, control.contentHeight + 2)

    // ---------------------------------------------------------------- 取值 / 拆串
    function tagList() {
        const t = control.tags;
        if (Array.isArray(t))
            return t;
        if (t === undefined || t === null)
            return [];
        return [String(t)];
    }

    // 官方 getSplitedArray：string / number 直接 split；数组先拿首项当临时分隔符把
    // 其余分隔符归一化再 split；其它类型（null / undefined）不拆
    function splitArray(origin) {
        const text = String(origin);
        if (control.split instanceof Function)
            return control.split(text, control.separator);
        const seps = control.separator;
        if (typeof seps === "string" || typeof seps === "number")
            return text.split(String(seps));
        if (Array.isArray(seps)) {
            if (seps.length === 0)
                return [text];
            const tempChar = String(seps[0]);
            let acc = text;
            for (let i = 1; i < seps.length; ++i)
                acc = acc.split(String(seps[i])).join(tempChar);
            return acc.split(tempChar);
        }
        return [text];
    }

    // ---------------------------------------------------------------- 提交
    // 官方受控时不写 state、只 notify（foundation.ts:295-312），所以 onChange 收到的是
    // 「算出来的新数组」，显示出来的仍然是 value
    function applyTags(next) {
        if (control.value === undefined)
            control._tags = next;
        control.change(next);
    }

    // 内部一律走这个函数读，不要读 inputText：那是个绑定，在 onInputValueChanged
    // 里读它拿到的是旧值（实测 QML 先发变更信号、后重算依赖绑定），
    // 于是受控推送会慢一拍。
    function currentInputText() {
        return control.inputValue !== undefined ? String(control.inputValue) : control._lastInput;
    }

    function syncInputText() {
        const want = control.currentInputText();
        if (field.text !== want)
            field.text = want;
    }

    // 官方 _onInputChange：先写 state 再 notify
    function commitInput(next) {
        control._lastInput = String(next);
        control.inputChange(control._lastInput);
        control.syncInputText();
    }

    // 官方 _checkInputChangeValid（foundation.ts:122-148）：只在「某一段变长」时查它
    // 是否超过 maxLength，超了整次变更作废并发 onInputExceed(整个新值)
    function checkInputValid(next) {
        if (control.maxLength < 0)
            return true;
        const valueArr = control.splitArray(next);
        const inputArr = control.splitArray(control.currentInputText());
        const maxLen = Math.max(valueArr.length, inputArr.length);
        for (let i = 0; i < maxLen; ++i) {
            if (valueArr[i] !== undefined
                    && (inputArr[i] === undefined || valueArr[i].length > inputArr[i].length)
                    && valueArr[i].length > control.maxLength)
                return false;
        }
        return true;
    }

    function handleUserEdit(raw) {
        if (!control.checkInputValid(raw)) {
            control.inputExceed(raw);
            control.syncInputText();
            return;
        }
        control._lastInput = raw;
        control.inputChange(raw);
        control.syncInputText();
    }

    // 官方 _handleAddTags（foundation.ts:174-207）
    function handleAddTags() {
        const current = control.tagList();
        let addTags = control.splitArray(control.currentInputText());
        addTags = addTags.filter((item, idx) => {
            if (!control.allowDuplicates) {
                if (current.indexOf(item) >= 0 || addTags.indexOf(item) !== idx)
                    return false;
            }
            return typeof item === "string" && item.trim() !== "";
        });
        let newTagList = current.concat(addTags);
        if (control.max >= 0 && newTagList.length > control.max) {
            control.exceed(newTagList);
            newTagList = newTagList.slice(0, control.max);
            addTags = addTags.slice(0, control.max - current.length);
        }
        if (addTags.length > 0) {
            control.applyTags(newTagList);
            control.add(addTags);
        }
        // 不论有没有加成，官方都会清空输入并发 onInputChange('')
        control.commitInput("");
    }

    function handleTagClose(index) {
        if (!control.enabled)
            return;
        const current = control.tagList();
        if (index < 0 || index >= current.length)
            return;
        const next = current.slice();
        const gone = next.splice(index, 1)[0];
        control.applyTags(next);
        control.remove(String(gone), index);
    }

    // 官方 handleClearBtn：清空只发 onChange，不发 onRemove
    function handleClear() {
        if (control.tagList().length > 0)
            control.applyTags([]);
        if (control.currentInputText().length > 0)
            control.commitInput("");
    }

    // 官方 arrayMove + handleSortEnd（foundation.ts:322-330）
    function moveTag(fromIndex, toIndex) {
        const current = control.tagList();
        if (fromIndex === toIndex || fromIndex < 0 || fromIndex >= current.length)
            return;
        const next = current.slice();
        const to = Math.max(0, Math.min(next.length - 1, toIndex));
        next.splice(to, 0, next.splice(fromIndex, 1)[0]);
        control.applyTags(next);
    }

    function activate() {
        if (control.enabled)
            control.active = true;
    }

    // 官方 focus()（index.tsx:623-630）：input 无条件 focus，只在 !disabled 时
    // handleClick() 把 active 打开 —— 焦点本身由 Qt 挡（禁用项拿不到 activeFocus）
    function focusInput() {
        field.forceActiveFocus();
        control.activate();
    }

    // 官方 blur() 除了让 input 失焦，还顺手注销 clickOutside，也就是 active 归 false
    function blurInput() {
        field.focus = false;
        control.active = false;
    }

    // ---------------------------------------------------------------- 排布
    // 官方是 flex-wrap：标签和输入区按行折。用 Row / Flow 的话位置器的 polish 时序会和
    // 「标签宽度取决于可用宽、可用宽又取决于标签摆到哪儿」互相绊住，所以自己排。
    function tagParts() {
        const list = [];
        for (let i = 0; i < repeater.count; ++i) {
            const item = repeater.itemAt(i);
            if (item)
                list.push(item);
        }
        return list;
    }

    function _relayout() {

        const avail = Math.max(0, Math.floor(flowArea.width));
        const parts = control.tagParts();
        if (control.isCollapsed())
            parts.push(restHost);
        parts.push(fieldHost);

        const rows = [];
        const rowIndex = [];
        let row = 0;
        let x = 0;
        for (let i = 0; i < parts.length; ++i) {
            const width = parts[i].hostWidth;
            if (i > 0 && x > 0 && x + width > avail) {
                row += 1;
                x = 0;
            }
            rowIndex[i] = row;
            rows[row] = Math.max(rows[row] === undefined ? 0 : rows[row], parts[i].bandHeight());
            x += width;
        }

        const rowY = [];
        let acc = 0;
        for (let r = 0; r < rows.length; ++r) {
            rowY[r] = acc;
            acc += rows[r];
        }

        let lastRow = -1;
        x = 0;
        for (let i = 0; i < parts.length; ++i) {
            const item = parts[i];
            if (rowIndex[i] !== lastRow) {
                lastRow = rowIndex[i];
                x = 0;
            }
            item.rowIndex = rowIndex[i];
            item.x = x;
            // 行内垂直居中按这一项自己的可视高算（`visualHeight()` 含官方那 1/2/3 的
            // 上下外边距差）。读 `item.height` 会翻车：Loader 的量出来那一刻，
            // `height` 这条绑定和触发 relayout 的属性不在同一轮求值，读到 0 就把这一项
            // 按 (行高 − 0)/2 往下推，第二个标签直接掉出触发器（gallery 实测 y 2 → 14）。
            item.y = rowY[rowIndex[i]]
                + Math.round((rows[rowIndex[i]] - item.visualHeight()) / 2);
            x += item.hostWidth;
        }

        // 输入区是唯一的 flex-grow 项：吃掉本行剩下的宽度
        const last = parts[parts.length - 1];
        last.width = Math.max(last.hostWidth, avail - last.x);

        const bands = [];
        for (let r = 0; r < rows.length; ++r)
            bands.push({ y: rowY[r], height: rows[r] });
        control._rows = bands;
        control.contentHeight = acc;
        flowArea.height = acc;
        control._laying = false;
        control.updateDropBar();
    }

    function relayout() {
        if (control._laying)
            return;
        control._laying = true;
        Qt.callLater(_relayout)
    }

    // 拖拽落点：行优先，返回第一个中心还在指针右侧的标签下标；指针已经过了所有
    // 标签的中心就返回 count（追加到末尾）。官方给 foundation 的 oldIndex / newIndex
    // 都在原始下标空间里，arrayMove 先摘后插，所以 count 落到 length-1 正好是末尾。
    function dropSlotFor(px, py) {
        const tags = control.tagParts();
        if (tags.length === 0)
            return 0;
        let row = control._rows.length - 1;
        for (let r = 0; r < control._rows.length; ++r) {
            if (py < control._rows[r].y + control._rows[r].height) {
                row = r;
                break;
            }
        }
        for (let i = 0; i < tags.length; ++i) {
            if (tags[i].rowIndex === row && tags[i].x + tags[i].width / 2 > px)
                return i;
        }
        for (let r = row + 1; r < control._rows.length; ++r) {
            for (let i = 0; i < tags.length; ++i) {
                if (tags[i].rowIndex === r)
                    return i;
            }
        }
        return tags.length;
    }

    // .semi-tagInput-sortable-item-over::before —— 2px 主色竖线，贴在落点标签的左外侧
    function updateDropBar() {
        const tags = control.tagParts();
        if (control.dragIndex < 0 || tags.length === 0 || control._rows.length === 0
                || control.dropIndex < 0) {
            dropBar.visible = false;
            return;
        }
        const slot = Math.max(0, Math.min(control.dropIndex, tags.length));
        const bandOf = (item) => control._rows[item.rowIndex];
        const band = slot >= tags.length
            ? bandOf(tags[tags.length - 1]) : bandOf(tags[slot]);
        dropBar.x = slot >= tags.length
            ? tags[tags.length - 1].x + tags[tags.length - 1].width + 2
            : Math.max(0, tags[slot].x - 2);
        dropBar.y = band.y;
        dropBar.height = band.height;
        dropBar.visible = true;
    }

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

    onActiveChanged: control.relayout()
    onSizeChanged: control.relayout()
    onVisibleTagListChanged: control.relayout()
    onRenderTagItemChanged: control.relayout()
    onInputTextChanged: control.relayout()
    onInputValueChanged: control.syncInputText()
    onPrefixChanged: control.relayout()
    onSuffixChanged: control.relayout()
    onShowClearChanged: control.relayout()

    Component.onCompleted: {
        control.syncInputText();
        control.relayout();
        if (control.autoFocus && control.enabled)
            control.focusInput();
    }

    // ---- .semi-tagInput ----
    Rectangle {
        id: box

        objectName: "tagInputBox"
        anchors.fill: parent
        radius: control.radius
        color: control.surfaceColor
        border.width: control.borderless ? 0 : 1   // -border-default 与 -focus 都是 1px
        border.color: control.borderColor

        Behavior on color {
            ColorAnimation { duration: Theme.current.durationFast }
        }

        // ---- .semi-tagInput-wrapper ----
        Item {
            id: flowArea

            objectName: "flowArea"
            anchors.left: leftSlot.right
            anchors.right: rightSlot.left
            anchors.leftMargin: control.wrapperPad
            anchors.rightMargin: control.wrapperPad
            // 单行时官方靠 align-items 把内容垂直居中
            y: 1 + Math.max(0, Math.round(((control.height - 2) - control.contentHeight) / 2))

            onWidthChanged: control.relayout()

            Rectangle {
                id: dropBar

                objectName: "dropBar"
                width: 2
                height: control.rowHeight
                visible: false
                color: Theme.current.colorPrimary    // $color-tagInput_sortable_item_over-bg
            }

            Repeater {
                id: repeater

                model: control.visibleTagList

                delegate: Item {
                    id: host

                    required property var modelData
                    required property int index

                    objectName: "tagHost" + index

                    property int rowIndex: 0
                    property real dragX: 0
                    property real dragY: 0
                    readonly property bool custom: control.renderTagItem !== null
                    readonly property real contentWidth: custom
                        ? itemLoader.implicitWidth : tagItem.implicitWidth
                    readonly property real contentHeight: custom
                        ? itemLoader.implicitHeight : control.tagHeight
                    // 自定义节点官方不带 -wrapper-tag 那层，所以没有 4 的右外边距；
                    // 有的外层（TreeSelect）会给它 2+2 的左右外边距，见 tagMarginX
                    readonly property real hostWidth: host.contentWidth
                        + (host.custom ? control.tagMarginX * 2 : control.tagGap)
                    // relayout() 用的两个数，全部现算读源属性，不走绑定属性 ——
                    // 见 relayout 里那条注释
                    function bandHeight() {
                        return host.custom ? itemLoader.implicitHeight : control.rowHeight;
                    }
                    function visualHeight() {
                        return host.custom ? itemLoader.implicitHeight : control.tagHeight;
                    }

                    width: host.contentWidth
                    height: host.contentHeight
                    transform: Translate {
                        x: host.dragX
                        y: host.dragY
                    }
                    // .semi-tagInput-sortable-item-active { opacity: .5 }
                    opacity: control.dragIndex === host.index ? 0.5 : 1
                    z: control.dragIndex === host.index ? 1 : 0

                    onHostWidthChanged: control.relayout()

                    function injectCloseTag() {
                        if (!itemLoader.item)
                            return;
                        itemLoader.item.closeTag = function () {
                            control.handleTagClose(host.index);
                            control.activate();
                        };
                    }

                    Tag {
                        id: tagItem

                        objectName: "tag" + host.index
                        anchors.fill: parent
                        visible: !host.custom
                        text: String(host.modelData)
                        color: "white"
                        size: control.size === Enums.Small ? "small" : "large"
                        closable: control.enabled
                        disabled: !control.enabled
                        // 官方 .semi-tagInput-wrapper-tag { max-width: 100% }
                        maxWidth: flowArea.width
                        // 拖拽态标签里多一个 IconHandle（.semi-tagInput-drag-handler）
                        prefixIcon: control.sortable ? "handle" : ""
                        onClosed: {
                            control.handleTagClose(host.index);
                            control.activate();
                        }
                    }

                    Loader {
                        id: itemLoader

                        x: control.tagMarginX        // 标签自己的左外边距，见 tagMarginX
                        active: host.custom
                        visible: host.custom
                        sourceComponent: control.renderTagItem

                        // 官方 renderTagItem(value, index, onClose)：约定组件根项声明
                        // 这三个普通属性，这里显式注入（同 Select.renderOption）
                        Binding {
                            target: itemLoader.item
                            when: itemLoader.item !== null
                            property: "modelData"
                            value: host.modelData
                        }

                        Binding {
                            target: itemLoader.item
                            when: itemLoader.item !== null
                            property: "index"
                            value: host.index
                        }

                        // closeTag 不能也走 Binding：value 是个 JS 函数，实测目标为空时
                        // 连 when: false 都拦不住，直接报「Unable to assign a function
                        // to a property of any type other than var」。只能在有 item 时写。
                        onItemChanged: host.injectCloseTag()
                    }

                    // 截断时悬停显示全文（官方 Paragraph ellipsis.showTooltip）。
                    // 官方给每个 Paragraph 各包一只 Tooltip/Popover，enter 由组件自己绑；
                    // 本库共用一只实例，这里只负责「这一刻把 target/text 换给哪一项」。
                    // 弹层那一只挂在 target 上的 HoverHandler 会跟着 `parent: control.target`
                    // 一起搬过来，实测：指针不动也会补投这一次 enter（变异复核把下面两处
                    // 曾经手写的 delayShow / delayHide 摘掉，tst_taginput 两档进出各一条断言
                    // 照样红）⇒ 走的还是组件自己那条 50ms 延迟与「卡片也算悬停」的判定。
                    HoverHandler {
                        id: hostHover

                        enabled: control.enabled && control.contentTooltipOn

                        onHoveredChanged: {
                            if (!hostHover.hovered) {
                                if (contentTip.target === host) {
                                    contentTip.target = null;
                                }
                                if (contentPop.target === host) {
                                    contentPop.target = null;
                                }
                                return;
                            }
                            if (!host.custom && !tagItem.textClipped)
                                return;
                            if (control.tooltipIsPopover) {
                                contentPop.target = host;
                                contentPop.text = String(host.modelData);
                            } else {
                                contentTip.target = host;
                                contentTip.text = String(host.modelData);
                            }
                        }
                    }

                    DragHandler {
                        id: hostDrag

                        enabled: control.sortable
                        target: null

                        onActiveChanged: {
                            if (active) {
                                control.dragIndex = host.index;
                                control.dropIndex = host.index;
                                control.updateDropBar();
                            } else if (control.dragIndex === host.index) {
                                const to = control.dropIndex;
                                control.dragIndex = -1;
                                control.dropIndex = -1;
                                host.dragX = 0;
                                host.dragY = 0;
                                control.updateDropBar();
                                control.moveTag(host.index, to);
                            }
                        }

                        onTranslationChanged: {
                            if (!active)
                                return;
                            host.dragX = translation.x;
                            host.dragY = translation.y;
                            control.dropIndex = control.dropSlotFor(
                                host.x + host.width / 2 + translation.x,
                                host.y + host.height / 2 + translation.y);
                            control.updateDropBar();
                        }
                    }
                }
            }

            // ---- .semi-tagInput-wrapper-n ----
            Item {
                id: restHost

                objectName: "restHost"
                visible: control.restCount > 0
                property int rowIndex: 0
                readonly property real hostWidth: restHost.width + control.tagGap
                function bandHeight() { return control.restHeight; }
                function visualHeight() { return control.restHeight; }

                // padding 0 8（$spacing-tagInput_wrapper_n_paddingX = spacing-tight）
                width: restText.implicitWidth + control.iconGap * 2
                height: control.restHeight

                onHostWidthChanged: control.relayout()

                Text {
                    id: restText

                    anchors.centerIn: parent
                    text: "+" + control.restCount
                    color: control.enabled
                        ? Theme.current.colorText0 : Theme.current.colorDisabledText
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }

            // ---- .semi-tagInput-wrapper-input ----
            Item {
                id: fieldHost

                objectName: "fieldHost"
                property int rowIndex: 0
                // 空值时官方是 width: min-content，即 min-width 2 + padding-right 12
                readonly property int hostWidth: String(field.text) !== ""
                    ? Math.ceil(mirror.implicitWidth) + control.fieldPadRight + 2
                    : control.fieldMinWidth
                function bandHeight() { return control.rowHeight; }
                function visualHeight() { return control.rowHeight; }

                width: control.fieldMinWidth
                height: control.rowHeight

                onHostWidthChanged: control.relayout()
                onXChanged: control.updateDropBar()
                onYChanged: control.updateDropBar()

                TextInput {
                    id: field

                    objectName: "tagInputField"
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - control.fieldPadRight)
                    height: control.size === Enums.Small ? 20 : 24
                    // 官方那个 input 的盒子比文字行高（CSS 靠 line-height 把字居中在盒里）。
                    // QQuickTextInput 默认把行**顶格**排，只居中盒子会让光标整体偏上
                    // (height − contentHeight)/2 —— default 档实测偏 3.5px，所以行也要居中。
                    verticalAlignment: TextInput.AlignVCenter
                    color: control.foreground
                    font.pixelSize: control.size === Enums.Large
                        ? Theme.current.fontSizeHeader6 : Theme.current.fontSizeRegular
                    selectByMouse: true
                    enabled: control.enabled
                    activeFocusOnTab: true
                    clip: true
                    cursorVisible: field.activeFocus

                    onTextEdited: control.handleUserEdit(field.text)

                    onActiveFocusChanged: {
                        if (field.activeFocus) {
                            // TextInput 自己吃下这一下 press，外层 TapHandler 收不到，
                            // 所以「点到框内」这件事在这里补上（官方是 root 的 onClick）
                            control.activate();
                            control.focused();
                            return;
                        }
                        // 官方 handleInputBlur（foundation.ts:209-216）：先走一遍添加，
                        // 再 setFocusing(false) / notifyBlur —— **不动 active**。
                        // active 只由 clickOutside 收回（foundation.ts:274-278），
                        // 所以 Tab / 程序把焦点拿走时多余标签仍是展开的。
                        if (control.addOnBlur)
                            control.handleAddTags();
                        control.blurred();
                    }

                    Keys.onPressed: (event) => {
                        const typed = field.text;
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            event.accepted = true;
                            if (typed !== "")
                                control.handleAddTags();
                        } else if (event.key === Qt.Key_Backspace
                                && typed === "" && control.tagList().length > 0) {
                            control.handleTagClose(control.tagList().length - 1);
                        }
                        control.keyDown(event.key, event.modifiers);
                    }
                }

                // .semi-tagInput-wrapper-inputMirror：只用来量宽度
                Text {
                    id: mirror

                    visible: false
                    text: String(field.text) !== ""
                        ? field.text
                        : (control.tagList().length === 0 ? control.placeholder : " ")
                    font: field.font
                }

                // 官方只在没有标签时才把 placeholder 交给 Input
                Text {
                    objectName: "placeholder"

                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.tagList().length === 0 && String(field.text) === ""
                    text: control.placeholder
                    color: control.placeholderColor
                    font.pixelSize: control.size === Enums.Large
                        ? Theme.current.fontSizeHeader6 : Theme.current.fontSizeRegular
                }
            }
        }

        // ---- 左右槽位：官方 flex 行顺序是 prefix | wrapper | clearBtn | suffix，
        // 所以清除按钮在后缀的内侧 ----
        Item {
            id: leftSlot

            objectName: "leftSlot"
            visible: control.prefixSlotWidth > 0
            anchors.left: parent.left
            // 那 1 是 .semi-tagInput 自己的 1px 边框；borderless（嵌进 TreeSelect，
            // treeSelect.scss:208 把 border 覆盖成 hidden）时它不存在，不该留这 1
            anchors.leftMargin: control.borderless ? 0 : 1
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: control.prefixSlotWidth

            Loader {
                id: prefixLoader

                anchors.verticalCenter: parent.verticalCenter
                visible: control.prefixIsNode
                sourceComponent: control.prefixIsNode ? control.prefix : null
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                x: control.iconGap
                visible: control.prefixIconShown
                name: control.prefixIcon
                size: Theme.current.widthIconMedium
                color: control.iconColor
            }

            // -prefix-text 与 -inset-label 是同一档：左右 12、加粗（index.tsx:427-431）
            Text {
                id: prefixText

                objectName: "prefixText"
                anchors.verticalCenter: parent.verticalCenter
                x: control.textGap
                visible: control.prefixTextShown
                text: control.prefixTextValue
                color: control.iconColor
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: Font.Bold
            }

            // 官方 handleClickPrefixOrSuffix：点前/后缀把焦点交给输入框
            MouseArea {
                anchors.fill: parent
                enabled: control.enabled
                onClicked: control.focusInput()
            }
        }

        Item {
            id: rightSlot

            objectName: "rightSlot"
            visible: control.clearShown || control.suffixSlotWidth > 0
            anchors.right: parent.right
            anchors.rightMargin: control.borderless ? 0 : 1
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: (control.clearShown ? control.clearWidth : 0) + control.suffixSlotWidth

            // ---- .semi-tagInput-clearBtn ----
            Item {
                id: clearBtn

                objectName: "clearBtn"
                visible: control.clearShown
                width: control.clearWidth
                height: parent.height

                Icon {
                    anchors.centerIn: parent
                    // 官方 -invisible 只藏图标，32 的占位一直在
                    visible: control.clearActive
                    name: control.clearIcon !== "" ? control.clearIcon : "clear"
                    size: Theme.current.widthIconMedium
                    color: clearArea.containsMouse ? Theme.current.colorPrimaryHover : control.iconColor
                }

                MouseArea {
                    id: clearArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: control.clearActive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        control.handleClear();
                        control.activate();
                    }
                }
            }

            Item {
                id: suffixBox

                objectName: "suffixBox"
                visible: control.suffixSlotWidth > 0
                x: control.clearShown ? control.clearWidth : 0
                width: control.suffixSlotWidth
                height: parent.height

                Loader {
                    id: suffixLoader

                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.suffixIsNode
                    sourceComponent: control.suffixIsNode ? control.suffix : null
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    x: control.iconGap
                    visible: control.suffixIconShown
                    name: control.suffixIcon
                    size: Theme.current.widthIconMedium
                    color: control.iconColor
                }

                Text {
                    id: suffixText

                    objectName: "suffixText"
                    anchors.verticalCenter: parent.verticalCenter
                    x: control.textGap
                    visible: control.suffixTextShown
                    text: control.suffixTextShown ? String(control.suffix) : ""
                    color: control.iconColor
                    font.pixelSize: Theme.current.fontSizeRegular
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: control.enabled
                    onClicked: control.focusInput()
                }
            }
        }
    }

    HoverHandler {
        id: hover
        enabled: control.enabled
    }

    TapHandler {
        enabled: control.enabled
        onTapped: control.focusInput()
    }

    // 官方在 document 上注册 click 来清 active（foundation.ts:267-278）。QML 里的对应做法
    // 是往窗口 contentItem 上挂一个 PointHandler：它只拿 passive grab，handleEventPoint 末尾
    // `point.setAccepted(false)`「just lurking」，不抢别的控件的点击（qquickpointhandler.cpp:128）；
    // 抬手那一刻 `point.position` 已经是落点（handlePointerEventImpl 先 reset 再 handle）。
    //
    // 中间必须垫一层壳 Item。`QQuickPointHandler::wantsEventPoint` 有一条查重：
    // 「同一个 parent、同一个 className 的兄弟已经抓了这个点就让开」
    // （qquickpointhandler.cpp:96-103），而 handler 的 `parent()` 正是它挂的那个 Item ——
    // 全都直接挂 contentItem 时，一个窗口里只有第一个 TagInput 拿得到「点到外面」，
    // 后面的实例 active 永远收不回来（`test_activeSurvivesProgrammaticBlur` 里
    // 两个实例并排就复现：只有 y=60 那个记到事件，y=10 那个一条都不记）。
    // 壳子每实例一个，parent 各不相同，查重就不生效了。
    Item {
        id: outsideShell

        objectName: "outsideShell"
        parent: control.Window.contentItem
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        enabled: control.active

        PointHandler {
            id: outsideTap

            onActiveChanged: {
                if (active || !control.active)
                    return;
                const local = control.mapFromItem(outsideShell,
                    outsideTap.point.position.x, outsideTap.point.position.y);
                if (local.x >= 0 && local.y >= 0 && local.x <= control.width && local.y <= control.height)
                    return;
                control.active = false;
            }
        }
    }

    // ---- 截断提示：tooltip 档 ----
    Tooltip {
        id: contentTip

        objectName: "contentTip"
    }

    // ---- 截断提示：showContentTooltip.type === 'popover' 档 ----
    // 上游 typography/base.tsx:754 —— `<Popover content={children} position="top" {...opts}>`，
    // 触发方式就用 Popover 的缺省 hover（50ms 延迟），showArrow 没给 ⇒ 间距 4、卡片内边距 0。
    // 与 tooltip 档共用 hostHover 那一次判定：两只弹层谁拿到 target 谁响。
    Popover {
        id: contentPop

        objectName: "contentPop"
        position: Enums.Top
    }

    // ---- +N 的剩余标签气泡 ----
    // 上游 tagInput/index.tsx:600-609 —— `<Popover content={restTags} showArrow trigger="hover"
    // position="top" autoAdjustOverflow {...restTagsPopoverProps}>`，restTagsPopoverProps 本库只吃
    // position 这一条。带三角 ⇒ spacing 走 10 那一档（Popover 的 render 现算，见 src/Popover.qml）。
    // showRestTagsPopover=false 时官方整只不渲染，这里等价地关掉 enabled（Tooltip 的
    // targetHover / targetClick 都看了它）。
    Popover {
        id: restPop

        objectName: "restPop"
        target: restHost
        showArrow: true
        enabled: control.enabled && control.showRestTagsPopover
        position: control.restTagsPopoverProps
            && control.restTagsPopoverProps.position
            ? control.placementOf(control.restTagsPopoverProps.position) : Enums.Top

        Column {
            spacing: Theme.current.spacingExtraTight

            Repeater {
                model: control.restTagList

                delegate: Tag {
                    required property var modelData
                    required property int index

                    text: String(modelData)
                    color: "white"
                    size: control.size === Enums.Small ? "small" : "large"
                    closable: control.enabled
                    disabled: !control.enabled
                    // 折叠时前 maxTagCount 个已经显示在外面
                    onClosed: control.handleTagClose(control.maxTagCount + index)
                }
            }
        }
    }
}
