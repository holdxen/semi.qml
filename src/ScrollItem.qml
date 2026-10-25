pragma ComponentBehavior: Bound

import QtQuick

// 滚动列表的一列。官方 ScrollItem（packages/semi-ui/scrollList/scrollItem.tsx:20-32）
// 才是真正的滚轮 / 普通列表，外壳（标题、页脚、多列排版）在 src/ScrollList.qml。
//
//     C.ScrollList {
//         header: "选择时间"
//         C.ScrollItem { mode: "wheel"; list: hours; selectedIndex: 1; type: 1;
//                        onSelect: (data) => { page.hour = data.index; } }
//         C.ScrollItem { mode: "wheel"; cycled: true; list: minutes; transform: pad }
//         footer: Button { text: "Ok" }
//     }
//
// list 收 ItemData（index.md#ItemData）：`{ text, value, disabled, transform }`。
// 文案取 `item.text == null ? item.value : item.text`（scrollItem.tsx:431），
// 所以官方只认对象；直接塞字符串两栏都是 undefined，渲染成空行，这里照抄。
//
// 规格（scrollList/scrollList.scss + variables.scss）：
//   行高 $height-scrollList_item = 36，文案居中（li 是 flex 居中）、14/20、text-0
//   列表首尾各一块 (300 - 36) / 2 的留白（ul::before + padding-bottom），
//     这样第一项和最后一项也能滚到正中；normal 模式同样有这块留白
//   列间 1px color-border 由外壳画（:not(:last-child) 的 border-right）
//   wheel：中间一条选择带（上下各 1px color-border，高 36，translateY(-50%)），
//     上下各一块 50% 高、bg-3、opacity .5 的遮罩（分别再外扩 19 = 行高/2 + 描边宽），
//     滚动容器右侧留 18（= 行高 / 2）给浏览器的滚动条，选中项加粗且换主色
//   normal：选中底 primary-light-default、字 text-0；悬浮 fill-1、按下 fill-2；
//     禁用字 disabled-text
//   悬浮/按下这两条都排除选中与禁用项（scrollList.scss:101 的 :not() 链）
//   滚动动画 $numbers.DEFAULT_SCROLL_DURATION = 120ms，motion=false 时直接落位
Item {
    id: control

    // ---------------------------------------------------------------- 官方 ScrollItemProps
    property string mode: "wheel"                   // strings.MODE = ['normal','wheel']
    property bool cycled: false                     // 仅 wheel 生效
    property var list: []
    property int selectedIndex: 0
    property bool motion: true
    // 官方 ScrollItemProps.transform（(value, text) => string）。Item 已经占了 FINAL 的
    // transform 列表属性，同名声明会被拒（坑 83 同族，FormItem 的 valueTransform 也一样），
    // 这里只能换名；ItemData 里的 transform 键不受影响，照官方原样读。
    property var textTransform: null
    property var type: undefined                    // 只用来在 onSelect 载荷里回传身份
    property string className: ""
    property var style: ({})
    property string ariaLabel: ""                   // 官方 aria-label，挂在 ul 上

    /// 官方 onSelect(data)，data = {...ItemData, value, type, index}
    signal select(var data)

    readonly property bool isWheel: control.mode === "wheel"
    // cycled 只在 wheel 模式生效（componentDidMount 的条件是 mode==='wheel' && cycled）
    readonly property bool usesCycle: control.cycled && control.isWheel
    readonly property real itemHeight: 36           // $height-scrollList_item
    readonly property int duration: 120             // numbers.DEFAULT_SCROLL_DURATION
    readonly property real wheelPadRight: 18        // $spacing-...-item_wheel_list_outer-paddingRight
    readonly property int dataCount: control.list === undefined || control.list === null
        ? 0 : control.list.length
    /// 首尾留白：官方写死 (300 - 36) / 2 = 132，这里跟着 body 高走，
    /// 默认 300 时两者相等（传 bodyHeight 覆盖时官方那条会露馅，见 PROGRESS.md）
    readonly property real padHeight: Math.max(0, (control.height - control.itemHeight) / 2)

    implicitWidth: 88
    implicitHeight: 300                             // $height-scrollList

    // cycled 时把模型铺若干份，滚到任一份都能映射回真下标。
    // 份数按视口算：至少要盖住「一屏 + 两份」，否则两三项的列铺三份还不满一个视口。
    readonly property int copies: {
        if (!control.usesCycle || control.dataCount === 0)
            return 1;
        const copyHeight = control.dataCount * control.itemHeight;
        return Math.max(3, Math.ceil(control.height / copyHeight) + 2);
    }
    readonly property int middleCopy: Math.floor(control.copies / 2)

    readonly property var rows: {
        const src = control.list === undefined || control.list === null ? [] : control.list;
        if (!control.usesCycle || control.dataCount === 0)
            return src;
        const out = [];
        for (let c = 0; c < control.copies; ++c) {
            for (let i = 0; i < src.length; ++i)
                out.push(src[i]);
        }
        return out;
    }

    // 真下标 → 模型下标（cycled 时落在中间那一份）
    function modelIndexOf(real) {
        if (!control.usesCycle || control.dataCount === 0)
            return real;
        return control.middleCopy * control.dataCount
            + ((real % control.dataCount) + control.dataCount) % control.dataCount;
    }

    // 模型下标 → 真下标
    function realIndexOf(model) {
        if (control.dataCount <= 0)
            return -1;
        return ((model % control.dataCount) + control.dataCount) % control.dataCount;
    }

    function dataAt(model) {
        const rows = control.rows;
        return model >= 0 && model < rows.length ? rows[model] : null;
    }

    function isDisabled(model) {
        const item = control.dataAt(model);
        return item !== null && typeof item === "object" && item.disabled === true;
    }

    function textOf(model) {
        const item = control.dataAt(model);
        if (item === null || item === undefined)
            return "";
        const real = control.realIndexOf(model);
        let text = item.text === undefined || item.text === null ? item.value : item.text;
        // 官方只对「选中那一项」跑 transform（scrollItem.tsx:426-434），
        // 且 ItemData 自带的 transform 优先于整列的
        if (real === control.selectedIndex && typeof control.transformOf(item) === "function")
            text = control.transformOf(item)(item.value, item.text);
        return text === undefined || text === null ? "" : String(text);
    }

    function transformOf(item) {
        if (item !== null && typeof item === "object" && typeof item.transform === "function")
            return item.transform;
        return control.textTransform;
    }

    // 按 selectedIndex 回到正中（首帧、换 list、外部改选中项都走这里）
    function recenter() {
        const model = control.modelIndexOf(control.clampIndex(control.selectedIndex));
        control.selectedModel = control.dataCount > 0 ? model : -1;
        control.scrollToSelector(model, false);
    }

    // 滚动停下 = 官方 onScroll 的 debouncedSelect：吸附到最近的可选项并通知。
    // 真拖拽收尾会发 movementEnded，程序化 flick() 只发 flickEnded，两条都接上；
    // 同一落点跑两遍是幂等的（selectedModel 与 __lastNotified 都已就位）。
    function settleAfterScroll() {
        if (!control.isWheel)
            return;
        const nearest = control.nearestEnabledIndex(control.indexAtCenter());
        if (nearest < 0)
            return;
        control.selectNode(control.wrapToMiddleCopy(nearest));
    }

    // 首尾留白是 ListView 的 header/footer 项，会整体推进内容坐标：
    // 第 model 项居中时 contentY = model * 行高 - 留白高（DateScrollColumn 同源）
    function contentYOfCentered(model) {
        return model * control.itemHeight - control.padHeight;
    }

    function indexAtCenter() {
        const count = control.rows.length;
        if (count === 0)
            return -1;
        const raw = Math.round((scroller.contentY + control.padHeight) / control.itemHeight);
        return Math.max(0, Math.min(count - 1, raw));
    }

    function clampIndex(index) {
        if (control.dataCount === 0)
            return 0;
        if (control.usesCycle)
            return ((index % control.dataCount) + control.dataCount) % control.dataCount;
        return Math.max(0, Math.min(control.dataCount - 1, index));
    }

    // 距中心最近、且没被禁用的一行（官方 getNearestNodeInfo 会跳过 disabled）
    function nearestEnabledIndex(model) {
        const count = control.rows.length;
        if (count === 0)
            return -1;
        const start = Math.max(0, Math.min(count - 1, model));
        if (!control.isDisabled(start))
            return start;
        for (let step = 1; step < count; ++step++) {
            if (start - step >= 0 && !control.isDisabled(start - step))
                return start - step;
            if (start + step < count && !control.isDisabled(start + step))
                return start + step;
        }
        return -1;
    }

    // 官方 animatedScrollTo 只传 duration，semi-animation 缺省 easing 是 linear
    function scrollToSelector(model, withMotion) {
        if (control.rows.length === 0)
            return;
        const target = control.contentYOfCentered(model);
        if (withMotion && control.motion) {
            glide.to = target;
            glide.restart();
        } else {
            glide.stop();
            scroller.contentY = target;
        }
    }

    // 无限列静默挪回中间那一份：内容逐字相同，跳整数份看不出来
    function wrapToMiddleCopy(model) {
        if (!control.usesCycle || control.dataCount === 0)
            return model;
        const low = control.middleCopy * control.dataCount;
        if (model >= low && model < low + control.dataCount)
            return model;
        const next = model - Math.floor((model - low) / control.dataCount) * control.dataCount;
        scroller.contentY = control.contentYOfCentered(next);
        return next;
    }

    function notifySelection(model) {
        const item = control.dataAt(model);
        if (item === null || item === undefined)
            return;
        const real = control.realIndexOf(model);
        // 官方载荷是 {...ItemData, value, type, index}（itemFoundation.ts:22-29）
        control.select(Object.assign({}, item, {
            "value": item.value,
            "type": control.type,
            "index": real
        }));
    }

    // 官方 selectNode：滚到正中 + 只在真换了项时通知一次
    function selectNode(model) {
        const real = control.realIndexOf(model);
        control.selectedModel = model;
        control.scrollToSelector(model, true);
        if (real !== control.__lastNotified) {
            control.__lastNotified = real;
            control.notifySelection(model);
        }
    }

    // 点选：normal 只通知（官方 selectIndex 不滚也不去重），wheel 走 selectNode 滚过去。
    // 禁用行不走到这里 —— 唯一的调用点是那个 TapHandler，它的 enabled 已经挡住
    //（官方 normal 不给禁用 li 挂 onClick、wheel 的 clickToSelectItem 也查 disabled）
    function pickRow(model) {
        if (control.isWheel) {
            control.selectNode(model);
            return;
        }
        control.notifySelection(model);
    }

    // wheel 的加粗项 = 官方那条 -item-selected 类，落在「最后一次落位 / 点选的那个物理行」上
    // （官方是给那个 DOM 节点加类名，cycled 铺多份时只有那一份加粗）；
    // normal 的选中底走 selectedIndex（官方 -item-sel = selectedIndex === index）
    property int selectedModel: -1

    readonly property int currentModel: control.isWheel ? control.selectedModel
        : control.modelIndexOf(control.clampIndex(control.selectedIndex))

    property int __lastNotified: -1

    // 首帧落位：官方 componentDidMount 用 duration 0 直接 scrollToNode
    Component.onCompleted: {
        control.recenter();
        control.__lastNotified = control.dataCount > 0 ? control.clampIndex(control.selectedIndex) : -1;
    }

    // 外部改 selectedIndex 就平滑滚过去（官方 componentDidUpdate）
    onSelectedIndexChanged: {
        const model = control.modelIndexOf(control.clampIndex(control.selectedIndex));
        control.selectedModel = model;
        if (model !== control.indexAtCenter())
            control.scrollToSelector(model, true);
    }

    // 外壳给列分配高度时留白高会变（padHeight 跟着视口高走），wheel 得重新落位
    onHeightChanged: {
        if (control.isWheel && control.selectedModel >= 0)
            control.scrollToSelector(control.selectedModel, false);
    }


    // 官方 style 只落地背景色这一条：这一层在 DOM 里是列容器本身，
    // 声明在滚动容器之前才能压在它下面（z 相同时按声明顺序画）
    Rectangle {
        objectName: "scrollItemBackground"

        anchors.fill: parent
        visible: control.styleBgCss !== ""
        color: control.styleBgCss
    }

    readonly property string styleBgCss: control.__colorOf(control.style, "backgroundColor")

    // ---------------- 滚动容器：wheel 是 -list-outer（右侧留 18），normal 是 -item
    ListView {
        id: scroller

        objectName: "scrollItemScroller"

        x: 0
        y: 0
        width: control.width - (control.isWheel ? control.wheelPadRight : 0)
        height: control.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // 官方没有 CSS scroll-snap，吸附是滚动停下后由 JS 把最近一行滚到正中
        snapMode: ListView.NoSnap
        spacing: 0
        model: control.rows

        // 官方 ul 是 role="listbox" + aria-label（scrollItem.tsx:471-473）
        Accessible.role: Accessible.List
        Accessible.name: control.ariaLabel

        header: Item {
            objectName: "scrollItemPadBefore"

            width: scroller.width
            height: control.padHeight
        }

        footer: Item {
            objectName: "scrollItemPadAfter"

            width: scroller.width
            height: control.padHeight
        }

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            objectName: "scrollItemRow"

            width: scroller.width
            height: control.itemHeight

            readonly property bool disabled: control.isDisabled(row.index)
            readonly property bool selected: row.index === control.currentModel

            // 悬浮 / 按下 / 选中底色；官方那三条 :not() 排除了选中与禁用
            Rectangle {
                objectName: "scrollItemRowBg"

                anchors.fill: parent
                visible: !row.disabled && !control.isWheel && (row.selected || pressHandler.pressed
                    || hoverHandler.hovered)
                color: row.selected ? Theme.current.colorPrimaryLightDefault
                    : (pressHandler.pressed ? Theme.current.colorFill2 : Theme.current.colorFill1)
            }

            // wheel 模式选中项也要能被悬浮/按下染色（official li:hover 不排除 wheel）
            Rectangle {
                objectName: "scrollItemRowWheelBg"

                anchors.fill: parent
                visible: !row.disabled && control.isWheel && !row.selected
                    && (pressHandler.pressed || hoverHandler.hovered)
                color: pressHandler.pressed ? Theme.current.colorFill2 : Theme.current.colorFill1
            }

            Text {
                objectName: "scrollItemRowText"

                anchors.centerIn: parent
                text: control.textOf(row.index)
                color: row.disabled ? Theme.current.colorDisabledText
                    : (control.isWheel && row.selected
                        ? Theme.current.colorPrimary : Theme.current.colorText0)
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: control.isWheel && row.selected ? Font.DemiBold : Font.Normal
            }

            HoverHandler {
                id: hoverHandler

                objectName: "scrollItemRowHover"

                // 官方把光标与悬浮底写在同一条 :not(.disabled):not(-sel):not(-selected) 里，
                // 禁用项另给 cursor: not-allowed。handler 一关就连光标都没了（Qt 没有 not-allowed
                // 的声明式写法），所以这里 handler 常开、光标按档位换，底色交给上面两条 visible
                cursorShape: row.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            }

            TapHandler {
                id: pressHandler

                // 禁用项两种模式都不给点（normal 不挂 onClick、wheel clickToSelectItem 查 disabled）
                enabled: !row.disabled
                onTapped: control.pickRow(row.index)
            }

            // 官方 li 是 role="option" + aria-disabled；Qt 这边 Attached 没有 state/disabled
            // 可写，只落 role 与文案
            Accessible.role: Accessible.StaticText
            Accessible.name: control.textOf(row.index)
        }

        onMovementEnded: control.settleAfterScroll()
        onFlickEnded: control.settleAfterScroll()

        // 换 list / cycled 份数变化后按 selectedIndex 重新落位。挂在这里而不是 rows 上：
        // count 变了说明模型已经吃进来，此刻 contentHeight 才是新的，直接写 contentY 不会被旧边界夹住
        onCountChanged: control.recenter()
    }

    SemiScrollBar {
        objectName: "scrollItemScrollBar"

        visible: !control.isWheel
        flickable: scroller
        orientation: Qt.Vertical
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    // ---------------- wheel：上下两块 50% 高、半透明的 bg-3 遮罩
    Rectangle {
        objectName: "scrollItemShadeBefore"

        visible: control.isWheel
        x: 0
        // 官方 top: 0 + margin-top -(18 + 1)：往上多盖一条描边宽
        y: -(control.wheelPadRight + 1)
        width: control.width
        height: control.height / 2
        z: 1
        color: Theme.current.colorBg3
        opacity: 0.5
    }

    Rectangle {
        objectName: "scrollItemShadeAfter"

        visible: control.isWheel
        x: 0
        // 官方 top: 50% + margin-top (18 + 1)
        y: control.height / 2 + control.wheelPadRight + 1
        width: control.width
        height: control.height / 2
        z: 3
        color: Theme.current.colorBg3
        opacity: 0.5
    }

    // ---------------- wheel：中间那条选择带（上下各 1px color-border）
    // 官方 -selector 是 content-box：height 36 再加上下各 1px 描边 = 38 高，
    // translateY(-50%) 按边框盒算，所以带子中心正好压在视口中线上。
    Item {
        objectName: "scrollItemSelector"

        visible: control.isWheel
        x: 0
        y: control.height / 2 - (control.itemHeight / 2 + 1)
        width: control.width
        height: control.itemHeight + 2
        z: 2
        Accessible.ignored: true

        Rectangle {
            objectName: "scrollItemSelectorTop"

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.current.colorBorder
        }

        Rectangle {
            objectName: "scrollItemSelectorBottom"

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.current.colorBorder
        }
    }

    // 官方 animatedScrollTo：duration 120、easing 缺省 linear
    NumberAnimation {
        id: glide

        objectName: "scrollItemGlide"

        target: scroller
        property: "contentY"
        duration: control.duration
        easing.type: Easing.Linear
    }

    function __colorOf(obj, key) {
        if (obj === undefined || obj === null)
            return "";
        const v = key in obj ? obj[key] : undefined;
        return typeof v === "string" && v !== "" ? v : "";
    }
}
