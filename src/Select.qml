pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// 下拉选择器。复刻 Semi Design 的 Select，支持：
// - 单选 / 多选（multiple）
// - 可搜索（filter + filterFunction）
// - 分组（options 里带 children 的项作为组标题）
// - 校验状态（validateStatus: default/warning/error）
// - 多选标签渲染（maxTagCount / ellipsisTrigger / expandRestTagsOnClick）
// - 键盘导航（上下箭头 / 回车 / Esc）
// - 自定义渲染（renderSelectedItem / renderOption）
// - 远程搜索（onSearch + loading）
// - 受控 / 非受控（value / defaultValue）
//
//     Select {
//         placeholder: "请选择"
//         options: [{ label: "选项一", value: 1 }, { label: "选项二", value: 2 }]
//         onSelected: (v) => ...
//     }
//
//     Select {
//         multiple: true
//         filter: true
//         options: cityOptions
//         onSearch: (keyword) => loadRemote(keyword)
//     }
Item {
    id: control

    // ---- 数据 ----
    property var options: []                    // [{label, value, disabled}] 或字符串数组，或带 children 的分组
    property var value: null                    // 单选值
    property var defaultValue: null             // 非受控默认值
    property bool multiple: false               // 多选
    property var values: []                     // 多选值数组
    property var defaultValues: []              // 多选非受控默认值

    // ---- 行为 ----
    property bool filter: false                 // 可搜索
    property var filterFunction: null           // 自定义过滤函数 (option, keyword) => bool
    property bool clearable: false              // 可清除
    property bool disabled: false
    property bool loading: false                // 远程搜索加载态
    property int maxTagCount: 0                 // 多选时最多显示几个标签，0 表示不限制
    property bool ellipsisTrigger: false        // 宽度不足时截断最后一个标签
    property bool expandRestTagsOnClick: false  // 点击 +N 展开剩余标签
    property bool showRestTagsPopover: false    // hover +N 显示剩余标签的 Popover

    // ---- 外观 ----
    property string placeholder: qsTr("请选择")
    property int size: Enums.Default            // Small / Default / Large
    // 触发器圆角。ColorPicker 的手输区把 Select 拼进 input-group，中间那几段要贴成直角
    // （input.scss:599-612 就是给组内子项设 border-radius: 0）
    property real radius: Theme.current.radiusSmall
    property int validateStatus: Enums.StatusDefault  // StatusDefault / StatusWarning / StatusDanger
    property string prefixIcon: ""
    // 官方 Form 的 labelPosition='inset' 把标签交给控件的 insetLabel 渲染
    property string insetLabel: ""
    // 分角圆角透给触发器，Form.InputGroup 要靠它们还原 .semi-input-group 的首尾圆角
    property alias topLeftRadius: trigger.topLeftRadius
    property alias topRightRadius: trigger.topRightRadius
    property alias bottomLeftRadius: trigger.bottomLeftRadius
    property alias bottomRightRadius: trigger.bottomRightRadius
    property string suffixIcon: ""

    // ---- 自定义渲染 ----
    // 设成 Component。组件根需声明四个**普通**属性（不是 required）：
    //     property var modelData   选项原始数据（{label, value, ...} 或字符串）
    //     property int index
    //     property bool chosen
    //     property bool disabled
    // Select 用 Binding 把值写进去 —— 不要写 required（Loader 不初始化，直接创建报错），
    // 也不要在组件内用自由变量（Bound pragma 下 context 解析失效）。
    // 例见 gallery 的 SelectPage「自定义渲染选项」与 tests/tst_loaderinject.qml。
    property Component renderSelectedItem: null
    property Component renderOption: null

    // ---- 信号 ----
    signal selected(var value)                  // 单选选中 / 多选每次切换
    signal search(string keyword)               // 搜索关键词变化（远程搜索用）
    signal exceed(int maxCount)                 // 多选超出 max 限制
    signal restTagsClick()                      // 点击 +N

    // ---- 内部状态 ----
    // 开关状态取自 PopupBase.isOpen（由 aboutToShow/aboutToHide 驱动）。
    // 不要自己记一份（会漏掉 closePolicy 那条路径），也不要读 popup.visible
    // （退场动画期间仍为 true）—— 两种写法都会造成「要点两次才重开」。
    readonly property bool _popupOpen: popup.isOpen
    property int _highlightIndex: -1            // 键盘高亮项
    property string _searchText: ""             // 搜索框文本
    property bool _expandedTags: false          // 是否展开剩余标签
    property var _initValueSet: false           // 是否已设置初始值

    // 展平后的选项列表（分组标题也作为一项，带 _isGroup 标记）
    readonly property var _flatOptions: {
        const result = [];
        function flatten(items, depth) {
            for (let i = 0; i < items.length; ++i) {
                const item = items[i];
                if (item && typeof item === "object" && Array.isArray(item.children)) {
                    result.push({ _isGroup: true, label: control.optionLabel(item), _depth: depth });
                    flatten(item.children, depth + 1);
                } else {
                    result.push({ _isGroup: false, _depth: depth, _original: item });
                }
            }
        }
        flatten(control.options, 0);
        return result;
    }

    // 过滤后的选项（排除组标题）
    readonly property var _filteredOptions: {
        if (!control.filter || control._searchText === "")
            return control._flatOptions.filter(o => !o._isGroup);
        const keyword = control._searchText.toLowerCase();
        const fn = control.filterFunction;
        return control._flatOptions.filter(o => {
            if (o._isGroup) return false;
            const label = control.optionLabel(o._original);
            if (fn) return fn(o._original, keyword);
            return String(label).toLowerCase().indexOf(keyword) >= 0;
        });
    }

    // 显示文本
    readonly property string displayText: {
        if (control.multiple) {
            if (control.values.length === 0) return "";
            return control.values.map(v => control.labelOf(v)).join("、");
        }
        if (control.value === null || control.value === undefined) return "";
        return control.labelOf(control.value);
    }

    // 触发器高度
    readonly property int triggerHeight: Appearance.inputWrapperHeight(Theme.current, control.size)
    readonly property int paddingH: Appearance.inputPaddingHorizontal(Theme.current)

    // 触发器状态（提到 control 层，供子项引用）
    readonly property int triggerState: Appearance.fieldState(
        control.enabled && !control.disabled,
        triggerHover.hovered || control._popupOpen,
        triggerPress.pressed, false)

    // 多选标签区撑出来的内容高度，由 tagFlow 回写。
    // 触发器高度取「规格高」与「内容高 + 上下内边距」的较大者 ——
    // Semi 的多选框最小高度同单选（small 24 正好容下一行 20 的标签），
    // 标签换行后整体变高。单选不受影响。
    property real tagsBlockHeight: 0

    implicitWidth: 200
    implicitHeight: Math.max(control.triggerHeight,
                             control.multiple ? control.tagsBlockHeight + Theme.current.spacingExtraTight
                                              : 0)

    // ---- 初始化默认值 ----
    Component.onCompleted: {
        if (!control._initValueSet) {
            if (control.multiple && control.defaultValues.length > 0)
                control.values = control.defaultValues.slice();
            else if (!control.multiple && control.defaultValue !== null && control.defaultValue !== undefined)
                control.value = control.defaultValue;
            control._initValueSet = true;
        }
    }

    // ---- 选项工具函数 ----
    function optionValue(item) {
        if (item === null || item === undefined) return item;
        return typeof item === "string" ? item : item.value;
    }

    function optionLabel(item) {
        if (item === null || item === undefined) return "";
        return typeof item === "string" ? item : (item.label !== undefined ? item.label : String(item.value));
    }

    function optionDisabled(item) {
        if (item === null || item === undefined) return false;
        return typeof item !== "string" && item.disabled === true;
    }

    function labelOf(v) {
        for (let i = 0; i < control.options.length; ++i) {
            const item = control.options[i];
            if (item && typeof item === "object" && Array.isArray(item.children)) {
                for (let j = 0; j < item.children.length; ++j) {
                    if (control.optionValue(item.children[j]) === v)
                        return control.optionLabel(item.children[j]);
                }
            } else {
                if (control.optionValue(item) === v)
                    return control.optionLabel(item);
            }
        }
        return String(v);
    }

    function isChosen(v) {
        return control.multiple ? control.values.indexOf(v) >= 0 : control.value === v;
    }

    function choose(v) {
        if (control.optionDisabled(control.findOption(v))) return;
        if (control.multiple) {
            const next = control.values.slice();
            const at = next.indexOf(v);
            if (at >= 0)
                next.splice(at, 1);
            else
                next.push(v);
            control.values = next;
        } else {
            control.value = v;
        }
        // 多选时带数组（Semi 的 onChange 多选下拿到的是整个 values），
        // 否则使用方 `values = value` 会把 values 覆盖成单个值
        control.selected(control.multiple ? control.values.slice() : v);
    }

    function findOption(v) {
        for (let i = 0; i < control.options.length; ++i) {
            const item = control.options[i];
            if (item && typeof item === "object" && Array.isArray(item.children)) {
                for (let j = 0; j < item.children.length; ++j) {
                    if (control.optionValue(item.children[j]) === v)
                        return item.children[j];
                }
            } else {
                if (control.optionValue(item) === v) return item;
            }
        }
        return null;
    }

    // ---- 弹出控制 ----
    function open() {
        if (control.disabled) return;
        control._highlightIndex = -1;
        popup.open();
    }

    function close() {
        control._searchText = "";
        popup.close();
    }

    function toggle() {
        popup.toggle();
    }

    // ---- 键盘导航 ----
    function highlightNext() {
        const list = control._filteredOptions;
        if (list.length === 0) return;
        let idx = control._highlightIndex + 1;
        while (idx < list.length) {
            if (!control.optionDisabled(list[idx]._original)) {
                control._highlightIndex = idx;
                return;
            }
            ++idx;
        }
    }

    function highlightPrev() {
        const list = control._filteredOptions;
        if (list.length === 0) return;
        let idx = control._highlightIndex - 1;
        while (idx >= 0) {
            if (!control.optionDisabled(list[idx]._original)) {
                control._highlightIndex = idx;
                return;
            }
            --idx;
        }
    }

    function confirmHighlight() {
        const list = control._filteredOptions;
        if (control._highlightIndex >= 0 && control._highlightIndex < list.length) {
            const opt = list[control._highlightIndex];
            if (!opt._isGroup && !control.optionDisabled(opt._original))
                control.choose(control.optionValue(opt._original));
        }
        if (!control.multiple) close();
    }

    // ---- 触发器 ----
    Rectangle {
        id: trigger

        anchors.fill: parent
        radius: control.radius
        color: Appearance.inputBackground(Theme.current, triggerState, control.validateStatus)
        border.width: 1
        border.color: control._popupOpen
            ? Theme.current.colorFocusBorder
            : Appearance.inputBorderColor(Theme.current,
                                          control._popupOpen ? Enums.Focused : triggerState,
                                          control.validateStatus)

        Behavior on color {
            ColorAnimation { duration: Theme.current.durationFast }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.current.durationFast }
        }

        opacity: control.disabled ? 0.6 : 1

        // 内容区
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: control.paddingH
            anchors.rightMargin: control.paddingH
            spacing: Theme.current.spacingTight

            // .semi-input-inset-label：margin 0 12 / font-weight 600 / color text-2。
            // 左边那 12 由 RowLayout 的 leftMargin（= paddingH 12）承担，
            // 与内容之间再补 4，凑够 8 + 4 = 12。
            Text {
                objectName: "insetLabel"
                visible: control.insetLabel !== ""
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: Theme.current.spacingBaseTight - Theme.current.spacingTight
                text: control.insetLabel
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: Font.DemiBold
            }

            // 多选标签区
            Item {
                id: tagArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: control.multiple

                // Semi 的多选是 flex-wrap：标签横排、放不下换行、触发器高度随内容长。
                // Repeater 直接挂在 Item 上不会排布（全部落在 0,0 叠成一坨），
                // 所以换行交给 Flow。它撑出来的高度用 onImplicitHeightChanged 回写给
                // control —— 跨对象尺寸派生用只读绑定不会重算（已知坑 14）。
                Flow {
                    id: tagFlow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.current.spacingExtraTight

                    Repeater {
                        model: control._visibleTags

                        delegate: Tag {
                            required property var modelData

                            // 官方 select/index.tsx:1095：color white、closable 取
                            // 非禁用，onClose 里先 preventDefault（受控标签，
                            // 由 selection 那一份数据决定还在不在）
                            text: control.labelOf(modelData)
                            size: "small"
                            color: "white"
                            visible: true
                            closable: !control.disabled

                            onClosed: (tagChildren, event, tagKey) => {
                                event.preventDefault();
                                control.choose(modelData);
                            }
                        }
                    }

                    // +N 标签：点击展开剩余，悬停可选 Popover
                    // 官方 renderNTag（index.tsx:1150）是 color grey，不吃白底档
                    Tag {
                        id: restTag

                        visible: control._restCount > 0 && !control._expandedTags
                        text: "+" + control._restCount
                        size: "small"
                        color: "grey"

                        HoverHandler {
                            enabled: control.showRestTagsPopover
                            onHoveredChanged: {
                                if (hovered) restPopover.open();
                                else restPopover.close();
                            }
                        }

                        TapHandler {
                            onTapped: {
                                control._expandedTags = !control._expandedTags;
                                control.restTagsClick();
                            }
                        }
                    }

                    // 搜索输入（多选 + 可搜索）
                    TextInput {
                        id: multiSearchInput

                        visible: control.filter
                        width: 60
                        height: 20
                        verticalAlignment: Text.AlignVCenter
                        color: Appearance.inputForeground(Theme.current, control.triggerState)
                        font.pixelSize: Theme.current.fontSizeRegular
                        text: control._searchText

                        onTextChanged: {
                            control._searchText = multiSearchInput.text;
                            control.search(multiSearchInput.text);
                            if (!control._popupOpen && multiSearchInput.text !== "")
                                control.open();
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Down) { control.highlightNext(); event.accepted = true; }
                            else if (event.key === Qt.Key_Up) { control.highlightPrev(); event.accepted = true; }
                            else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) { control.confirmHighlight(); event.accepted = true; }
                            else if (event.key === Qt.Key_Escape) { control.close(); event.accepted = true; }
                            else if (event.key === Qt.Key_Backspace && multiSearchInput.text === "" && control.values.length > 0) {
                                control.choose(control.values[control.values.length - 1]);
                                event.accepted = true;
                            }
                        }
                    }

                    // 占位文本
                    Text {
                        visible: control.values.length === 0
                        height: 20
                        verticalAlignment: Text.AlignVCenter
                        text: control.placeholder
                        color: Appearance.inputPlaceholderColor(Theme.current, control.triggerState)
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    onImplicitHeightChanged: control.tagsBlockHeight = implicitHeight
                    Component.onCompleted: control.tagsBlockHeight = implicitHeight
                }
            }

            // 单选显示 / 搜索输入
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !control.multiple

                // 搜索输入（单选 + 可搜索）
                TextInput {
                    id: singleSearchInput
                    anchors.fill: parent
                    visible: control.filter
                    text: control._popupOpen ? control._searchText : control.displayText
                    color: control._popupOpen
                        ? Appearance.inputForeground(Theme.current, triggerState)
                        : (control.displayText !== "" ? Appearance.inputForeground(Theme.current, triggerState)
                                                      : Appearance.inputPlaceholderColor(Theme.current, triggerState))
                    font.pixelSize: Theme.current.fontSizeRegular
                    verticalAlignment: Text.AlignVCenter

                    onTextChanged: {
                        if (control._popupOpen) {
                            control._searchText = singleSearchInput.text;
                            control.search(singleSearchInput.text);
                        }
                    }

                    onAccepted: {
                        if (control._filteredOptions.length > 0) {
                            const opt = control._filteredOptions[control._highlightIndex >= 0 ? control._highlightIndex : 0];
                            if (!opt._isGroup) control.choose(control.optionValue(opt._original));
                        }
                        control.close();
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Down) { control.highlightNext(); event.accepted = true; }
                        else if (event.key === Qt.Key_Up) { control.highlightPrev(); event.accepted = true; }
                        else if (event.key === Qt.Key_Escape) { control.close(); event.accepted = true; }
                    }

                    Keys.onReleased: (event) => {
                        if (!control._popupOpen && (event.key === Qt.Key_Down || event.key === Qt.Key_Up))
                            control.open();
                    }
                }

                // 单选文本显示
                Text {
                    visible: !control.filter || !control._popupOpen
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: control.displayText !== "" ? control.displayText : control.placeholder
                    color: control.displayText !== ""
                        ? Appearance.inputForeground(Theme.current, triggerState)
                        : Appearance.inputPlaceholderColor(Theme.current, triggerState)
                    font.pixelSize: Theme.current.fontSizeRegular
                    elide: Text.ElideRight
                }
            }

            // 加载指示器
            Spin {
                Layout.alignment: Qt.AlignVCenter
                visible: control.loading
                size: "small"
            }

            // 清除按钮
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                visible: control.clearable && !control.loading && (
                    (control.multiple && control.values.length > 0) ||
                    (!control.multiple && control.value !== null && control.value !== undefined)
                ) && control.enabled && !control.disabled
                icon: "close"
                size: Enums.Small
                variant: Enums.Borderless
                tone: Enums.Tertiary
                onClicked: {
                    control.value = null;
                    control.values = [];
                    control._searchText = "";
                    control.selected(null);
                }
            }

            // 自定义后缀图标
            Icon {
                Layout.alignment: Qt.AlignVCenter
                visible: control.suffixIcon !== "" && !control.loading
                name: control.suffixIcon
                size: 16
                color: Appearance.inputIconColor(Theme.current, control.triggerState)
            }

            // 下拉箭头
            Icon {
                Layout.alignment: Qt.AlignVCenter
                visible: !control.loading
                name: "chevron_down"
                size: 16
                // $color-select-icon-default = text-2，禁用态 .semi-select-disabled
                // 把 -arrow / -suffix / -prefix 一起换成 disabled-text
                color: Appearance.inputIconColor(Theme.current, control.triggerState)
                rotation: control._popupOpen ? 180 : 0

                Behavior on rotation {
                    NumberAnimation { duration: Theme.current.durationFast }
                }
            }
        }

        HoverHandler {
            id: triggerHover
            enabled: control.enabled && !control.disabled
        }

        TapHandler {
            id: triggerPress
            enabled: control.enabled && !control.disabled
            onTapped: {
                if (control.filter) {
                    if (!control._popupOpen) {
                        control._searchText = "";
                        control.open();
                        if (control.multiple) multiSearchInput.forceActiveFocus();
                        else singleSearchInput.forceActiveFocus();
                    } else {
                        control.close();
                    }
                } else {
                    control.toggle();
                }
            }
        }

        Keys.onPressed: (event) => {
            if (!control._popupOpen && (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Enter)) {
                control.open();
                event.accepted = true;
            }
        }

        focus: true
    }

    // ---- 下拉弹层 ----
    // 弹层内部，测试要量上下内缩是否对称、总高是否等于内容高
    readonly property var _popup: popup

    PopupBase {
        id: popup

        anchor: trigger
        placement: Enums.BottomLeft
        gap: 4
        fillColor: Theme.current.colorBg3
        padding: 0
        autoFlip: true

        implicitWidth: Math.max(control.width, 160)
        // 搜索区与列表各自带内边距，内容列间距设 0 免得叠成 16
        contentSpacing: 0
        implicitHeight: {
            const searchH = control.filter ? 8 + 32 + 8 + 1 : 0;
            const n = control._filteredOptions.length;
            const listH = n === 0 ? 36 : Math.min(n * 36, 270);
            return searchH + listH + Theme.current.spacingExtraTight * 2;
        }

        onOpened: {
            control._highlightIndex = -1;
            // 打开即可打字
            if (control.filter)
                Qt.callLater(() => popupSearchInput.forceActiveFocus());
        }

        onClosed: {
            control._searchText = "";
            control._expandedTags = false;
        }

        // .semi-select-option-list-wrapper 的上下 padding 各 4（左右 0），
        // 且搜索框在这个 wrapper 里面 —— 所以这 4px 在搜索区之上，不是之下。
        // objectName 是给测试盯「上下都有内缩、且顶部那条没漏」用的。
        Item {
            objectName: "listInsetTop"
            width: 1
            height: Theme.current.spacingExtraTight
        }

        // 搜索区。规格见 semi-foundation/select：
        //   .semi-select-dropdown-search-wrapper 上下 padding 各 8、左右各 12，
        //   border-bottom: 1px solid $color-select_dropdown_input-border
        Item {
            id: searchWrap

            visible: control.filter
            width: parent.width
            height: control.filter ? 8 + 32 + 8 + 1 : 0

            Rectangle {
                id: searchField

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.current.spacingTight
                anchors.leftMargin: Theme.current.spacingBaseTight
                anchors.rightMargin: Theme.current.spacingBaseTight
                height: 32
                color: Theme.current.colorFill0
                radius: Theme.current.radiusSmall
                border.width: 1
                border.color: Theme.current.colorBorder

                TextInput {
                    id: popupSearchInput

                    anchors.fill: parent
                    anchors.leftMargin: Theme.current.spacingTight
                    anchors.rightMargin: 24
                    verticalAlignment: Text.AlignVCenter
                    text: control._searchText
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.current.spacingTight
                        verticalAlignment: Text.AlignVCenter
                        visible: popupSearchInput.text === "" && !popupSearchInput.activeFocus
                        text: qsTr("搜索")
                        color: Theme.current.colorText3
                        font: popupSearchInput.font
                    }

                    onTextChanged: {
                        control._searchText = popupSearchInput.text;
                        control.search(popupSearchInput.text);
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Down) { control.highlightNext(); event.accepted = true; }
                        else if (event.key === Qt.Key_Up) { control.highlightPrev(); event.accepted = true; }
                        else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) { control.confirmHighlight(); event.accepted = true; }
                        else if (event.key === Qt.Key_Escape) { control.close(); event.accepted = true; }
                    }
                }

                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.current.spacingTight
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 14
                    color: Theme.current.colorText3
                }
            }

            // 底部分隔线
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.current.colorBorder
            }
        }

        // 选项列表
        ListView {
            id: optionList

            objectName: "selectOptionList"
            width: parent.width
            // 无结果时列表让位给下面的空状态，不然两块各占 36 会把弹层撑出裁切
            height: control._filteredOptions.length === 0
                ? 0
                : Math.min(control._filteredOptions.length * 36, 270)
            model: control._filteredOptions
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            // 高亮项滚动到可见区域
            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    optionList.positionViewAtIndex(currentIndex, ListView.Contain);
            }

            delegate: Item {
                id: optionRow

                objectName: "selectOptionRow"
                required property var modelData
                required property int index

                readonly property bool isGroup: modelData._isGroup
                readonly property bool chosen: !isGroup && control.isChosen(control.optionValue(modelData._original))
                readonly property bool disabled: !isGroup && control.optionDisabled(modelData._original)
                readonly property bool highlighted: index === control._highlightIndex

                width: optionList.width
                height: isGroup ? 28 : 36

                // 背景
                Rectangle {
                    anchors.fill: parent
                    color: {
                        if (optionRow.isGroup) return "transparent";
                        if (optionRow.highlighted) return Theme.current.colorFill0;
                        if (optionRow.chosen && !control.multiple) return Theme.current.colorPrimaryLightDefault;
                        return "transparent";
                    }
                }

                // 组标题
                Text {
                    visible: optionRow.isGroup
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.current.spacingBaseTight
                    anchors.verticalCenter: parent.verticalCenter
                    // 非组项的 modelData 没有 label 字段；visible:false 也挡不住
                    // 绑定求值，所以只在组项上读，避免刷 undefined 警告
                    text: optionRow.isGroup ? String(optionRow.modelData.label ?? "") : ""
                    color: Theme.current.colorText3
                    font.pixelSize: Theme.current.fontSizeSmall
                    font.weight: Font.Medium
                }

                // 选项内容（非组）
                Row {
                    visible: !optionRow.isGroup
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.current.spacingBaseTight
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.current.spacingBaseTight
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.current.spacingTight

                    // 对勾槽位（多选时显示）
                    Item {
                        visible: control.multiple
                        width: Theme.current.widthIconSmall
                        height: Theme.current.fontSizeRegular

                        Icon {
                            anchors.centerIn: parent
                            visible: optionRow.chosen
                            name: "checkbox_tick"
                            size: Theme.current.widthIconSmall
                            color: Theme.current.colorText2
                        }
                    }

                    // 自定义渲染或默认文本
                    Loader {
                        id: optionLoader

                        width: parent.width - (control.multiple ? Theme.current.widthIconSmall + Theme.current.spacingTight : 0)
                        height: 20
                        visible: control.renderOption !== null
                        sourceComponent: control.renderOption

                        // 显式注入。不能靠「Loader 初始化 required properties」——
                        // 实测 Loader 根本不做这件事（创建直接报 not initialized）；
                        // 也不能靠 context object 自由变量解析 —— renderOption 的
                        // 组件定义在带 `pragma ComponentBehavior: Bound` 的文件里时，
                        // 作用域被绑到组件边界，穿透失效。
                        // 所以约定组件根声明普通属性，这里用 Binding 写进去。
                        // 两条机制的最小验证都在 tests/tst_loaderinject.qml。
                        Binding {
                            target: optionLoader.item
                            when: optionLoader.item !== null
                            property: "modelData"
                            value: optionRow.modelData._original
                        }
                        Binding {
                            target: optionLoader.item
                            when: optionLoader.item !== null
                            property: "index"
                            value: optionRow.index
                        }
                        Binding {
                            target: optionLoader.item
                            when: optionLoader.item !== null
                            property: "chosen"
                            value: optionRow.chosen
                        }
                        Binding {
                            target: optionLoader.item
                            when: optionLoader.item !== null
                            property: "disabled"
                            value: optionRow.disabled
                        }
                    }

                    Text {
                        visible: control.renderOption === null
                        width: parent.width - (control.multiple ? Theme.current.widthIconSmall + Theme.current.spacingTight : 0)
                        text: control.optionLabel(optionRow.modelData._original)
                        color: optionRow.disabled
                            ? Theme.current.colorDisabledText
                            : (optionRow.chosen && !control.multiple ? Theme.current.colorPrimary : Theme.current.colorText0)
                        font.pixelSize: Theme.current.fontSizeRegular
                        font.weight: optionRow.chosen ? Font.DemiBold : Font.Normal
                        lineHeight: 20
                        lineHeightMode: Text.FixedHeight
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    id: optionHover
                    enabled: !optionRow.disabled && !optionRow.isGroup
                    onHoveredChanged: {
                        if (hovered) control._highlightIndex = optionRow.index;
                    }
                }

                TapHandler {
                    enabled: !optionRow.disabled && !optionRow.isGroup
                    onTapped: {
                        control.choose(control.optionValue(optionRow.modelData._original));
                        if (!control.multiple) control.close();
                    }
                }
            }
        }

        // 空状态
        Item {
            visible: control._filteredOptions.length === 0
            width: parent.width
            height: 36

            Text {
                anchors.centerIn: parent
                text: control.loading ? qsTr("加载中...") : qsTr("无匹配结果")
                color: Theme.current.colorText3
                font.pixelSize: Theme.current.fontSizeSmall
            }
        }

        Item {
            objectName: "listInsetBottom"
            width: 1
            height: Theme.current.spacingExtraTight
        }
    }

    // +N 剩余标签 Popover
    PopupBase {
        id: restPopover

        anchor: trigger
        placement: Enums.BottomLeft
        gap: 4
        fillColor: Theme.current.colorBg3
        padding: Theme.current.spacingExtraTight
        autoFlip: true

        implicitWidth: Math.max(control.width, 200)
        implicitHeight: Math.min(control._restTagsList.length * 28 + Theme.current.spacingExtraTight * 2, 200)

        ListView {
            width: parent.width - popup.padding * 2
            height: contentHeight
            model: control._restTagsList
            interactive: false

            delegate: Item {
                required property var modelData
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.current.spacingTight
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.labelOf(modelData)
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                TapHandler {
                    onTapped: control.choose(modelData)
                }
            }
        }
    }

    // ---- 计算属性 ----
    readonly property var _visibleTags: {
        if (!control.multiple) return [];
        const all = control.values;
        if (control._expandedTags) return all;
        if (control.maxTagCount <= 0) return all;
        return all.slice(0, control.maxTagCount);
    }

    readonly property int _restCount: {
        if (!control.multiple || control._expandedTags) return 0;
        if (control.maxTagCount <= 0) return 0;
        return Math.max(0, control.values.length - control.maxTagCount);
    }

    readonly property var _restTagsList: {
        if (control.maxTagCount <= 0) return control.values;
        return control.values.slice(control.maxTagCount);
    }

    // 搜索文本变化时重置高亮
    on_SearchTextChanged: control._highlightIndex = -1
}
