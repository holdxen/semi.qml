pragma ComponentBehavior: Bound

import QtQuick

// 自动补全。输入时按关键字过滤候选词并弹出建议列表。
//
//     AutoComplete {
//         dataList: ["apple", "banana", "cherry"]
//         onSelected: (v) => ...
//     }
//
//     AutoComplete {
//         dataList: [{ label: "选择器", value: "select" }]
//         renderItem: myOptionComponent        // 自定义候选项渲染
//         onSearch: (v) => reload(v)           // 远程搜索
//         loading: busy
//     }
//
// 输入框外观沿用 Input，建议列表用 ListView（弹层里的内容要能可靠生成）。
// 官方 prop 面见 semi-ui/autoComplete/index.tsx + semi-foundation/autoComplete/foundation.ts。
Item {
    id: control

    // ---- 与官方同名 ----
    property var dataList: []                 // data：字符串数组或 { label, value } 对象数组
    property string value: ""
    property string placeholderText: qsTr("请输入")
    property int size: Enums.Default
    // 分角圆角透给触发器，InputGroup 要靠它们还原 .semi-input-group 的首尾圆角
    property alias topLeftRadius: input.topLeftRadius
    property alias topRightRadius: input.topRightRadius
    property alias bottomLeftRadius: input.bottomLeftRadius
    property alias bottomRightRadius: input.bottomRightRadius
    property bool showClear: false
    property string prefixIcon: ""             // 官方 prefix（ReactNode → 这里收图标名）
    property string suffixIcon: ""             // 官方 suffix
    property int validateStatus: Enums.StatusDefault
    property int position: Enums.BottomLeft
    property bool loading: false
    property Component renderItem: null        // 官方 renderItem
    property Component emptyContent: null       // 官方 emptyContent
    property var renderSelectedItem: null       // 官方 renderSelectedItem，必须是函数、返回字符串

    // 本库自有：只允许从候选里选，失焦时清掉不在候选里的输入。
    // 官方 AutoComplete 没有这个 prop（Select 才有），第一版声明了却从没被读过。
    property bool strict: false

    // 本库自有开关：要不要在本地按输入过滤 data。
    // **默认关**，因为官方 AutoComplete 根本不筛 —— data 给什么就显示什么，
    // 过滤是调用方在 onSearch 里做的事（foundation 里没有 AutoComplete 的 filter）。
    // 开着它会把「远程搜索」这类自己已经筛过的数据二次过滤掉，所以只能选装。
    property bool filterLocal: false

    signal selected(string value)
    signal search(string value)
    signal cleared()

    // 注意：不能写成每次求值都新建数组的绑定 ——
    // 那样 model 引用每次都变，列表不会稳定渲染。
    property var filtered: []

    // data 两种写法都要在每个读取点上抹平（坑 41）
    function optionValue(item) {
        return item !== null && typeof item === "object" ? String(item.value) : String(item);
    }

    function optionLabel(item) {
        if (item !== null && typeof item === "object")
            return item.label !== undefined ? String(item.label) : String(item.value);
        return String(item);
    }

    function refilter() {
        if (!control.filterLocal) {
            control.filtered = control.dataList;
            return;
        }
        const keyword = control.value.trim().toLowerCase();
        if (keyword === "") {
            control.filtered = control.dataList;
            return;
        }
        control.filtered = control.dataList.filter(
            (item) => control.optionLabel(item).toLowerCase().indexOf(keyword) >= 0);
    }

    implicitWidth: 220
    implicitHeight: Appearance.inputWrapperHeight(Theme.current, control.size)

    // 外部改 value（受控写法、defaultValue 那类）会经由下面那条同步写进 input.text，
    // 而 input.onTextChanged 是「用户在打字」的入口 —— 不挡一下就会：
    // 一打开页面就弹下拉、还顺手发一次 search。
    property bool _syncingFromValue: false

    onValueChanged: {
        if (input.text !== control.value) {
            control._syncingFromValue = true;
            input.text = control.value;
            control._syncingFromValue = false;
        }
        control.refilter();
    }
    onDataListChanged: control.refilter()

    function isCandidate(text) {
        return control.dataList.some(
            (item) => control.optionValue(item) === text || control.optionLabel(item) === text);
    }

    function open() {
        if (control.loading || control.filtered.length > 0 || control.emptyContent !== null)
            popup.open();
    }

    function close() {
        popup.close();
    }

    // foundation.ts:166-178 —— 回填输入框的是 renderSelectedItem(option) ?? option.value
    function pick(item) {
        const text = typeof control.renderSelectedItem === "function"
            ? String(control.renderSelectedItem(item)) : control.optionValue(item);
        control.value = text;
        input.text = text;
        popup.close();
        control.selected(control.optionValue(item));
    }

    Input {
        id: input

        anchors.fill: parent
        placeholderText: control.placeholderText
        size: control.size
        prefixIcon: control.prefixIcon
        suffixIcon: control.suffixIcon
        showClear: control.showClear
        validateStatus: control.validateStatus
        enabled: control.enabled

        onTextChanged: {
            if (control._syncingFromValue)
                return;               // 不是用户打的字，不发 search、也不弹下拉
            control.value = input.text;
            control.search(input.text);
            if (input.text !== "" && !popup.visible)
                popup.open();
            else if (input.text === "")
                popup.close();
        }
        onCleared: control.cleared()
        onAccepted: {
            if (control.filtered.length > 0)
                control.pick(control.filtered[0]);
        }

        // strict 的落点：失焦时把不在候选里的输入清掉
        onFieldActiveFocusChanged: {
            if (!input.fieldActiveFocus && control.strict && input.text !== ""
                    && !control.isCandidate(input.text)) {
                input.text = "";
                control.value = "";
            }
        }
    }

    // 行高：option.scss 里 line-height 20 + 上下 padding 各 8 = 36（与 Select 同）
    readonly property int optionHeight: 36
    // 弹层内部，测试要量列表内缩与总高，从外面没有别的通路
    readonly property var _popup: popup
    // 触发器内部，同上：禁用态的图标颜色 / 整体不透明度都要从这一层量
    readonly property var _input: input

    PopupBase {
        id: popup

        anchor: input
        placement: control.position
        gap: 4
        fillColor: Theme.current.colorBg3
        // 列表容器 .semi-autocomplete-option-list 四边 padding 都是 0（variables.scss 里
        // $spacing-autoComplete_option_list-padding* = 0px），且 Popover 无箭头时
        // .semi-popover-wrapper 也不带 padding —— 弹层本体不内缩。
        padding: 0
        contentSpacing: 0
        autoFlip: true

        // 上下那 4px 内缩来自 option.scss 的 :first-of-type / :last-of-type margin，
        // 只对 .semi-autocomplete-option 生效 —— 加载条和自定义空内容都不是选项，
        // 所以那两种情况下没有内缩。（Select 的同名 margin 是注释掉的。）
        readonly property bool hasRows: control.filtered.length > 0 && !control.loading
        readonly property bool showEmptyRow: !control.loading && control.filtered.length === 0
            && control.emptyContent === null
        readonly property real inset: (popup.hasRows || popup.showEmptyRow)
            ? Theme.current.spacingExtraTight : 0
        // index.tsx defaultProps 的 maxHeight = 300（Select 是 constants.ts 的 LIST_HEIGHT = 270）
        readonly property real listMaxHeight: 300
        // 内缩算在滚动容器**里面**（overflow-y:auto 自成 BFC，margin 不外逃），
        // 所以官方弹层总高 = min(36n + 8, 300)：3 项实测 116，13 项实测 300 且可滚。
        readonly property real blockHeight: {
            if (control.loading)
                return 36;          // .semi-autocomplete-loading-wrapper：height 20 + 上下 8
            if (popup.hasRows)
                return Math.min(control.filtered.length * control.optionHeight,
                    popup.listMaxHeight - popup.inset * 2);
            if (popup.showEmptyRow)
                return control.optionHeight;
            // Loader.item 静态类型是 QObject，要 as Item 才读得到尺寸（坑 18）
            return emptyLoader.item ? (emptyLoader.item as Item).height : 0;
        }

        implicitWidth: Math.max(control.width, 160)
        // 高度自己按项数算：ListView 的 contentHeight 在弹层完成布局前是 0，
        // 而 PopupBase 的 implicitHeight 又依赖内容尺寸，会互相等成 0。
        implicitHeight: popup.blockHeight + popup.inset * 2

        Item {
            objectName: "listInsetTop"
            width: 1
            height: popup.inset
        }

        // 加载态：官方是 .semi-autocomplete-loading-wrapper 里一个占满宽度的 Spin
        Item {
            objectName: "loadingRow"
            visible: control.loading
            width: Math.max(0, popup.width - popup.padding * 2)
            height: 36

            Spin {
                anchors.centerIn: parent
            }
        }

        ListView {
            id: listView

            objectName: "optionList"
            visible: popup.hasRows
            width: Math.max(0, popup.width - popup.padding * 2)
            height: popup.hasRows ? popup.blockHeight : 0
            model: control.filtered
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                width: listView.width
                height: control.optionHeight

                Rectangle {
                    anchors.fill: parent
                    color: rowHover.hovered ? Theme.current.colorFill0 : "transparent"
                }

                // 自定义渲染。注入方式与 Select 的 renderOption 一致：
                // Loader 不会初始化 required property，带 Bound 的组件也解析不到
                // context object 的自由变量，只能用 Binding 显式写进去（坑 42）。
                Loader {
                    id: itemLoader

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.current.spacingBaseTight
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.current.spacingBaseTight
                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.renderItem !== null
                    sourceComponent: control.renderItem

                    Binding {
                        target: itemLoader.item
                        when: itemLoader.item !== null
                        property: "modelData"
                        value: row.modelData
                    }

                    Binding {
                        target: itemLoader.item
                        when: itemLoader.item !== null
                        property: "index"
                        value: row.index
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.current.spacingBaseTight
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.current.spacingBaseTight
                    anchors.verticalCenter: parent.verticalCenter
                    visible: control.renderItem === null
                    text: control.optionLabel(row.modelData)
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: rowHover
                }

                TapHandler {
                    onTapped: control.pick(row.modelData)
                }
            }
        }

        Item {
            objectName: "listInsetBottom"
            width: 1
            height: popup.inset
        }

        // 空态行按 option.scss 的 &-empty 排（高 36、内容居中、disabled-text）。
        // 官方在无匹配且未传 emptyContent 时其实弹层是空的，这里保留一行提示 —— 有意偏离。
        Text {
            visible: popup.showEmptyRow
            width: Math.max(0, popup.width - popup.padding * 2)
            height: control.optionHeight
            text: qsTr("无匹配结果")
            color: Theme.current.colorDisabledText
            font.pixelSize: Theme.current.fontSizeRegular
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Loader {
            id: emptyLoader

            objectName: "emptyContent"
            visible: !control.loading && control.filtered.length === 0
                && control.emptyContent !== null
            active: visible
            sourceComponent: control.emptyContent
        }
    }
}
