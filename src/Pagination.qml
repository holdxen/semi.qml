pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 翻页器。官方分两层：算法在 semi-foundation/pagination/foundation.ts，皮肤在
// semi-ui/pagination/index.tsx —— 后者按 size 分成 renderDefaultPage / renderSmallPage 两套。
//
//     Pagination { total: 200; pageSize: 10; onPageChange: page => ... }      // 非受控
//     Pagination { total: 200; currentPage: page; onPageChange: page => ... } // 受控
//     Pagination { total: 200; size: Enums.Small; hoverShowPageSelect: true }
//
// 皮肤（semi.css 17230-17406 = pagination.scss 的编译结果，令牌见 pagination/variables.scss）：
//   容器 `.semi-page` 是 flex、padding 0、align-items center；`.semi-page-small` 另加
//   font-weight 400 与 color text-2，但这条颜色没人吃到 —— 小档唯一的文本是那个 `c/t` 格子，
//   它自己带 `-item` 把 color 覆盖成 text-0。
//   页码格 `.semi-page-item`：height 32、**min-width 32（内容更宽就长宽，不是定宽）**、
//   margin-left 与 margin-right 各 4（⇒ 格子之间视觉间距 8，整行两端各留 4）、
//   radius var(--semi-border-radius-small)=3、`border: 0px solid transparent`（**宽度 0，没有环**）、
//   字号 14 / 行高 32 / 字重 400（选中 600）。
//   颜色（$color-pagination_item-*）：常态 text-0 字 + 透明底；悬浮 fill-0；按下 fill-1；
//   选中 primary 字 + primary-light-default 底；禁用 disabled-text 字 + 透明底（悬浮也不变）；
//   禁用+选中是 disabled-fill 底。CSS 层叠要注意 `.semi-page-item:active`(0,2,0) 压得过
//   `-item-active`(0,1,0) ⇒ **按下的那一格（含当前页）显 fill-1、字色回 text-0**；
//   选中+悬浮靠更晚的 `-item-active:hover`(0,2,0) 拉回 primary-light-default。
//   前后翻页 `.semi-page-prev/-next` 的字色是 **var(--semi-color-tertiary)**（不是 text-2），
//   悬浮/按下回 text-0；禁用是 disabled-text —— `-prev.item-disabled` 写在 `:hover` 之后，
//   同特异度后者赢，所以禁用档悬浮不变色。
//   总页数 `.semi-page-total` 字号 14、text-2、**没有 margin**（挨着它的那个格子自带 4 的左距）；
//   组件禁用时 `-disabled .semi-page-total` 换成 disabled-text。
//   快速跳转 `-quickjump`：margin-left 24、字色 text-0（禁用档 disabled-text）；
//   输入框 `-quickjump-input-number` max-width 50、左右各 4 的 margin。
//   省略号浮层里的页码表 `-rest-list` 上下各 4 的内边距、宽 78；条目 `-rest-item` 高 32、
//   内容居中、悬浮 fill-0、按下 fill-1，字色取浮层继承来的 text-0（见 src/Popover.qml 文件头）。
//   迷你档那个 `c/t` 格子是 `-item -item-small`：**min-width 44、margin 0**，官方没给它
//   onClick ⇒ 只会随悬浮/按下变底色，点它不跳页。禁用档只挂 `-item-all-disabled`
//   （没有 `-active` 那一支）⇒ 小档永远不出 disabled-fill。
//   **全组件零动画**：animation.scss 把 transition 的两个 duration 都指到
//   --semi-transition_duration-none（0ms），只剩 :hover / :active 的瞬时换色。
//
// 文案（locale/source/zh_CN.ts:8-13，官方由 LocaleProvider 注入）：
//   总页数「总页数：${total}」—— 这里填的是**页数**不是条数；每页容量「每页条数：${pageSize}」；
//   快速跳转「跳至」+「页」。本库没有 locale 机制，中文串直接写死（同其他组件）。
//
// 上游的坑与死代码（照抄，不"修"）：
//   · componentDidUpdate:229 把 `props.currentPage` 原样喂给 `updatePage(targetPageIndex = 1, ...)`
//     ⇒ 非受控档（没传 currentPage，即 undefined）只要 total 或 pageSize 这两个 **prop** 变过，
//     当前页就被打回 1，哪怕用户已经翻到第 9 页。
//   · 同处的 `updateAllPageNumbers(props.total, props.pageSize)`：没传 pageSize 时第二个参数是
//     undefined ⇒ `Math.ceil(total / undefined)` = NaN ⇒ `Array.from({length: NaN})` = []，
//     也就是**小档 hoverShowPageSelect 的那张全页码表，一改 total/pageSize 就清空**
//     （首次构造用的是 state.pageSize，所以只有「改之后」才空）。
//   · `pageSizeInOpts()`（foundation.ts:258-268）插值用 `findIndex(el => el > pageSize)`，
//     找不到（比所有可选项都大）时 index 是 -1 ⇒ `splice(-1, 0, x)` 把 x 插到**倒数第二个位置**：
//     opts [10,20,40,100] + pageSize 200 ⇒ [10,20,40,200,100]。
//   · 第 4 支截断写的是 `currentPage - 3 <= currentPage && currentPage <= totalPageNum`，
//     左半边恒真（本意应是 `totalPageNum - 3 <= currentPage`）⇒ 这里只留右半边；`_current`
//     在本端口恒为整数，删掉恒真半边不改行为。
//   · constants 里的 REST_PAGE_SHOW_MAX=5 没有任何地方读（真正生效的是 REST_PAGE_MAX_SIZE=1e6，
//     等于不截断；官方 FAQ「最多 1,000,000 条」说的就是这个数）。
//   · `-item-rest-opening`（悬浮省略号时点亮那一格）对应的 classNames 在 index.tsx:368 整行被
//     注释掉了 ⇒ 死规则，本端口不实现。
//   · `foundation.handleKeyDown()` 是空函数，却 register 到 document 上 ⇒ 死代码，不搬。
//   · `state.showTotal` 从 props 拷了一份，但 render 读的是 props、也没人更新它 ⇒ 死状态；
//     `state.total` 同理恒等于 `props.total`（只有 updatePage 一处写、来源同一个）⇒ 本端口折叠成一个属性。
//   · `goPage(page, i)` 与省略号行 `goPage(page, index)` 传的第二个下标，foundation 的签名里根本没有。
//   · `hideOnSinglePage` 的判据是 `totalPageNum < 2`，NaN（例如 pageSize 传 0）时不成立 ⇒ 不隐藏。
//   · `showSizeChanger` 在小档**根本不渲染**（renderSmallPage 不调 renderPageSizeSwitch:472-480），
//     可它又参与 `hideOnSinglePage` 的豁免判定（`&& !showSizeChanger`）⇒ 小档开着 showSizeChanger 时
//     既没有切换器、也不隐藏自己。constructor:152 那条 warning 就是提醒这个组合。
//   · 官方文档 API 表里 showTotal 与 size 的缺省列是空的（源码是 false 与 'default'），
//     pageSize 那栏写 10，实际是 `props.pageSize || pageSizeOpts[0] || 10` 的第三级回退。
//
// 与官方的差异（React / CSS 在 QML 侧没有落点）：
//   · `style` 与 `className` 是 DOM 内联样式，不搬（同其他组件）；`getDataAttr(rest)` 那套
//     data-* 透传与 aria-*（aria-disabled / aria-label / aria-current / role）同样没有落点（坑 91）。
//   · `prevText` / `nextText` 官方收 ReactNode：这里字符串档与 Component 档都吃，都算「给了」，
//     undefined / null / "" 落回那对 chevron（IconChevronLeft/Right 的 size="large" = 20px，
//     见 semi-icons/components/Icon.tsx:24）。
//   · 官方用 `'currentPage' in props` 判受控；QML 没有这个概念，按仓库惯例 currentPage 为
//     undefined 或 null 即非受控（见 src/Tree.qml 文件头那条）。
//   · `size` 官方只有 'small' 与 'default'，其余值一律走默认档 ⇒ 这里除 Enums.Small 之外都是默认档。
//   · `popoverPosition` 官方是字符串，这里保留字符串入口再映射到 Enums。两处缺省不一样：
//     **省略号浮层**拿到的是 undefined ⇒ 用 Popover 自己的 bottom（index.tsx:391 直接把 prop 转给
//     Popover）；**每页容量下拉**先做 `= defaultPopoverPosition` 解构缺省 ⇒ bottomLeft
//     （rtl 时 bottomRight）。Select 端口的弹层方位不可配，所以这条只落在两处浮层上。
//   · `.semi-page-switch`（每页容量的外壳 div）在 CSS 里压根没有规则，本端口把 Select 直接摆进行里；
//     宽度官方随内容撑开，本库 Select 端口是缺省 200。官方还给 Select 挂了 `key={pageSize + 文案}`
//     （切页容量就整只重建），这里靠 selected 之后重新装回 value 绑定达到同样效果。
//   · 官方省略号表用 react-window 虚拟化，这里换成 ListView（可视高与裁切一致，行是普通 delegate）。
//   · 快速跳转的 Enter：官方 InputNumber 有 onEnterPress，本库 InputNumber 端口没有这个信号，
//     从它透出的 `innerInput`（Input.accepted）接进来。
Row {
    id: control

    // ---------------------------------------------------------------- 官方 PaginationProps
    property int total: 1
    property bool showTotal: false
    property var pageSize: undefined                        // 官方缺省 null；给了就盖过 pageSizeOpts
    property var pageSizeOpts: [10, 20, 40, 100]
    property int size: Enums.Default                        // 官方 'default' | 'small'
    property var currentPage: undefined                     // 给了就是受控
    property int defaultCurrentPage: 1
    property var prevText: undefined
    property var nextText: undefined
    property bool showSizeChanger: false
    property bool showQuickJumper: false
    property int popoverZIndex: 1030                        // popoverNumbers.DEFAULT_Z_INDEX
    property var popoverPosition: undefined                 // 官方字符串档，见 positionOf()
    property bool hideOnSinglePage: false
    property bool hoverShowPageSelect: false                // 官方 defaultProps 里没这一条
    property bool disabled: false
    property bool preventPageChangeOnPageSizeChange: false

    // 官方 onPageChange / onPageSizeChange / onChange
    signal pageChange(int page)
    signal pageSizeChange(int size)
    signal change(int page, int size)

    // ---------------------------------------------------------------- 量（照令牌；官方没有第三档尺寸）
    readonly property real itemHeight: 32                   // $height-pagination_item
    readonly property real itemMinWidth: 32                 // $width-pagination_item-minWidth
    readonly property real smallItemMinWidth: 44            // $width-pagination_item_small-minWidth
    readonly property real itemMarginX: Theme.current.spacingExtraTight   // 左右各 4
    readonly property real quickJumpMarginLeft: 24          // $spacing-pagination_quickjump_marginLeft
    readonly property real quickJumpInputWidth: 50          // $width-pagination_quickjump_input_width

    // ---------------------------------------------------------------- 官方 PaginationState
    // state.total 恒等于 props.total（见文件头），所以只留 total；下面四条才是真的内部状态
    property int _pageSize: 10
    property int _current: 1
    property var _quickJumpPage: ""
    property var _allPageNumbers: []

    readonly property bool isSmall: control.size === Enums.Small
    readonly property real totalPageNum: Math.ceil(control.total / control._pageSize)  // _getTotalPageNumber
    readonly property bool isControlled: control.currentPage !== undefined
        && control.currentPage !== null

    // _updateDisabled 与 _updatePageList 在官方是写进 state 的，可写入点只有 init/updatePage
    // 两处、输入只有 (_current, total, _pageSize) ⇒ 这里做成纯派生绑定，值等价
    readonly property bool prevDisabled: control._current === 1
    readonly property bool nextDisabled: control._current === 1 ? control.totalPageNum < 2
        : (control._current === control.totalPageNum)
    readonly property bool prevBlocked: control.prevDisabled || control.disabled
    readonly property bool nextBlocked: control.nextDisabled || control.disabled
    readonly property var _pager: control.buildPager()
    readonly property var pageList: control._pager.pageList
    readonly property var restLeftPageList: control._pager.restLeftPageList
    readonly property var restRightPageList: control._pager.restRightPageList
    // 官方 renderDefaultPage / renderSmallPage 开头那句 return null
    readonly property bool hiddenOnSinglePage: control.totalPageNum < 2
        && control.hideOnSinglePage && !control.showSizeChanger
    // 小档的 `c/t` 格子里 totalPageNum 那半边的写法
    readonly property string smallLabel: qsTr("%1/%2 ").arg(control._current).arg(String(control.totalPageNum))
    readonly property string totalText: qsTr("总页数：%1").arg(String(control.totalPageNum))
    readonly property bool quickJumpBlocked: control.totalPageNum === 1 || control.disabled

    visible: !control.hiddenOnSinglePage
    spacing: 0

    // 官方 constructor:127-156 + componentDidMount → foundation.init()
    Component.onCompleted: {
        control._pageSize = control.pageSize || control.pageSizeOpts[0] || 10;
        control._current = control.currentPage || control.defaultCurrentPage;
        if (control.showSizeChanger && control.hideOnSinglePage) {
            console.warn("Warning: [Semi Pagination] You should not use showSizeChanger and "
                + "hideOnSinglePage at the same time. At this time, hideOnSinglePage no longer "
                + "takes effect, otherwise there may be a problem that the switch entry disappears");
        }
        control._allPageNumbers = (control.isSmall && control.hoverShowPageSelect && !control.disabled)
            ? control.pageNumbers(control.totalPageNum) : [];
    }

    // 官方 componentDidUpdate:203-235：这三条 prop 任一变化，就用 **props** 重跑一遍
    // updatePage + updateAllPageNumbers（那两处重置行为见文件头）
    onTotalChanged: control.syncProps()
    onPageSizeChanged: control.syncProps()
    onCurrentPageChanged: control.syncProps()

    function syncProps() {
        control.updatePage(control.currentPage, control.total, control.pageSize);
        control.updateAllPageNumbers(control.total, control.pageSize);
    }

    // foundation.updatePage:94-116。官方这里还要把 total 的 undefined 回退到 state.total，
    // 但本端口 state.total 已折叠成 props.total（见文件头那条），那一支没人读 ⇒ 只剩
    // pageSize 的回退与两次「值真的变了才写」。
    function updatePage(targetPageIndex = 1, total, pageSize) {
        if (pageSize === null || typeof pageSize === "undefined")
            pageSize = control._pageSize;
        if (pageSize !== control._pageSize)
            control._pageSize = pageSize;
        if (targetPageIndex !== control._current)
            control._current = targetPageIndex;
    }

    // foundation.updateAllPageNumbers:117-127，只在小档 + hoverShowPageSelect + 未禁用时算
    function updateAllPageNumbers(total, pageSize) {
        if (!control.isSmall || !control.hoverShowPageSelect || control.disabled)
            return;
        control._allPageNumbers = control.pageNumbers(Math.ceil(total / pageSize));
    }

    function pageNumbers(count) {
        return Array.from({ length: count }, (v, i) => i + 1);
    }

    function range(count, start) {
        return Array.from({ length: count }, (v, i) => start + i);
    }

    // foundation._updatePageList:144-209 的四支截断，逐条照抄（PAGE_SHOW_MAX=7 个节点，
    // 省略号本身也算一个）
    function buildPager() {
        const currentPage = control._current;
        const totalPageNum = control.totalPageNum;
        const PAGE_SHOW_MAX = 7;
        const REST_PAGE_MAX_SIZE = 1000000;
        let pageList = [];
        let restLeftPageList = [];
        let restRightPageList = [];

        if (totalPageNum <= PAGE_SHOW_MAX) {
            pageList = control.pageNumbers(totalPageNum);
            restLeftPageList = [];
            restRightPageList = [];
        } else {
            switch (true) {
            case currentPage < 4: {
                pageList = [1, 2, 3, 4, "...", totalPageNum - 1, totalPageNum];
                restRightPageList = control.range(Math.min(totalPageNum - 6, REST_PAGE_MAX_SIZE), 5);
                restLeftPageList = [];
                break;
            }
            case currentPage === 4: {
                pageList = [1, 2, 3, 4, 5, "...", totalPageNum];
                restRightPageList = control.range(Math.min(totalPageNum - 6, REST_PAGE_MAX_SIZE), 6);
                restLeftPageList = [];
                break;
            }
            case 4 < currentPage && currentPage < totalPageNum - 3: {
                const middle = control.range(3, currentPage - 1);
                pageList = [1, "..."].concat(middle, ["...", totalPageNum]);
                restRightPageList = control.range(
                    Math.min(totalPageNum - currentPage - 2, REST_PAGE_MAX_SIZE), currentPage + 2);
                restLeftPageList = control.range(
                    Math.min(currentPage - 3, REST_PAGE_MAX_SIZE), 2);
                break;
            }
            case currentPage <= totalPageNum: {
                const right = control.range(5, totalPageNum - 4);
                pageList = [1, "..."].concat(right);
                restRightPageList = [];
                restLeftPageList = control.range(Math.min(right[0] - 2, REST_PAGE_MAX_SIZE), 2);
                break;
            }
            default:
                // 官方 default 分支什么都不做 ⇒ currentPage 越过总页数时是一张空页码表
                break;
            }
        }
        return {
            pageList: pageList,
            restLeftPageList: restLeftPageList,
            restRightPageList: restRightPageList
        };
    }

    // foundation.goPage:73-92。省略号与「点自己」都直接 return；受控档只发信号不改状态
    function goPage(targetPageIndex) {
        if (targetPageIndex === "...")
            return;
        const pageSize = control._pageSize;
        const currentPage = control._current;
        if (targetPageIndex === currentPage)
            return;
        if (!control.isControlled) {
            control.updatePage(targetPageIndex);
            control.pageChange(targetPageIndex);
            control.change(targetPageIndex, pageSize);
        } else {
            control.pageChange(targetPageIndex);
            control.change(targetPageIndex, pageSize);
        }
    }

    // foundation.goPrev / goNext:129-142（禁用是 tsx 那侧挡的，不在这两个函数里）
    function goPrev() {
        if (control._current > 1)
            control.goPage(control._current - 1);
    }

    function goNext() {
        if (control._current <= control.totalPageNum - 1)
            control.goPage(control._current + 1);
    }

    // foundation.changePageSize:211-238。官方第一句 updatePageSize 是 setState，同一批里
    // 后面 getStates() 读到的还是旧值 ⇒ 换算用的是旧 pageSize
    function changePageSize(newPageSize) {
        const total = control.total;
        const currentPage = control._current;
        const oldPageSize = control._pageSize;
        control.pageSizeChange(newPageSize);

        let newCurrentPage = currentPage;
        if (!control.preventPageChangeOnPageSizeChange) {
            const currentPageFirstItemIndex = (currentPage - 1) * oldPageSize + 1;
            newCurrentPage = Math.ceil(currentPageFirstItemIndex / newPageSize);
        }

        control.updatePage(newCurrentPage, total, newPageSize);
        if (currentPage !== newCurrentPage)
            control.pageChange(newCurrentPage);
        control.change(newCurrentPage, newPageSize);
    }

    // foundation.pageSizeInOpts:258-268（找不到更大项时插到倒数第二个位置，见文件头）
    function pageSizeInOpts() {
        const newPageSizeOpts = control.pageSizeOpts.slice();
        if (newPageSizeOpts.indexOf(control._pageSize) === -1) {
            const firstLargerIndex = newPageSizeOpts.findIndex(el => el > control._pageSize);
            newPageSizeOpts.splice(firstLargerIndex, 0, control._pageSize);
        }
        return newPageSizeOpts;
    }

    function sizeChangerOptions() {
        return control.pageSizeInOpts().map(size => ({
            label: qsTr("每页条数：%1").arg(size),
            value: size
        }));
    }

    // 快速跳转那一串：foundation.handleQuickJumpNumberChange / _handleQuickJump /
    // handleQuickJumpBlur / handleQuickJumpEnterPress:275-311
    function handleQuickJumpNumberChange(value) {
        control._quickJumpPage = value;
    }

    function handleQuickJump(targetPage) {
        const page = Number(targetPage);
        const totalPageNum = control.totalPageNum;
        if (Number.isNaN(page))
            return;
        let target = page;
        if (target > totalPageNum)
            target = totalPageNum;
        if (target <= 0)
            target = 1;
        control._quickJumpPage = "";
        control.goPage(target);
    }

    function handleQuickJumpBlur() {
        const value = control._quickJumpPage;
        if ((typeof value === "string" && value) || typeof value === "number")
            control.handleQuickJump(value);
    }

    function positionOf() {
        switch (String(control.popoverPosition)) {
        case "top": return Enums.Top;
        case "topLeft": return Enums.TopLeft;
        case "topRight": return Enums.TopRight;
        case "left": return Enums.Left;
        case "leftTop": return Enums.LeftTop;
        case "leftBottom": return Enums.LeftBottom;
        case "right": return Enums.Right;
        case "rightTop": return Enums.RightTop;
        case "rightBottom": return Enums.RightBottom;
        case "bottomLeft": return Enums.BottomLeft;
        case "bottomRight": return Enums.BottomRight;
        case "bottom":
        default: return Enums.Bottom;
        }
    }

    // prevText / nextText 的三档：假值给 chevron，字符串给 Text，Component 给 Loader
    function nodeIsText(node) {
        return typeof node === "string" && node !== "";
    }

    function nodeIsComponent(node) {
        return node !== undefined && node !== null && typeof node !== "string";
    }

    // ---------------------------------------------------------------- 总页数
    Item {
        id: totalSlot

        objectName: "paginationTotalSlot"
        visible: !control.isSmall && control.showTotal
        width: totalLabel.implicitWidth
        height: control.itemHeight

        Text {
            id: totalLabel

            objectName: "paginationTotal"
            anchors.verticalCenter: parent.verticalCenter
            text: control.totalText
            color: control.disabled ? Theme.current.colorDisabledText
                : Theme.current.colorText2                        // $color-pagination-text-default
            font.pixelSize: Theme.current.fontSizeRegular
        }
    }

    // ---------------------------------------------------------------- 上一页
    Item {
        id: prevSlot

        objectName: "paginationPrev"
        width: prevBox.width + control.itemMarginX * 2
        height: control.itemHeight

        readonly property real nodeWidth: control.nodeIsText(control.prevText) ? prevText.implicitWidth
            : (control.nodeIsComponent(control.prevText) ? prevLoader.implicitWidth : 20)

        Rectangle {
            id: prevBox

            objectName: "paginationPrevBox"
            x: control.itemMarginX
            width: Math.max(control.itemMinWidth, prevSlot.nodeWidth)
            height: control.itemHeight
            radius: Theme.current.radiusSmall
            border.width: 0                                    // $width-pagination_item_border
            color: control.prevBlocked ? "transparent"
                : (prevTap.pressed ? Theme.current.colorFill1
                    : (prevHover.hovered ? Theme.current.colorFill0 : "transparent"))

            HoverHandler {
                id: prevHover

                cursorShape: control.prevBlocked ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            }

            TapHandler {
                id: prevTap

                onTapped: {
                    if (!control.prevBlocked)
                        control.goPrev();
                }
            }
        }

        Text {
            id: prevText

            objectName: "paginationPrevText"
            anchors.centerIn: prevBox
            visible: control.nodeIsText(control.prevText)
            text: String(control.prevText)
            font.pixelSize: Theme.current.fontSizeRegular
        }

        Loader {
            id: prevLoader

            objectName: "paginationPrevLoader"
            anchors.centerIn: prevBox
            visible: control.nodeIsComponent(control.prevText)
            sourceComponent: control.prevText
        }

        // IconChevronLeft size="large"：20×20，字色 tertiary，悬浮/按下回 text-0
        Icon {
            id: prevIcon

            objectName: "paginationPrevIcon"
            anchors.centerIn: prevBox
            visible: !control.nodeIsText(control.prevText) && !control.nodeIsComponent(control.prevText)
            name: "chevron_left"
            size: 20
            color: control.prevBlocked ? Theme.current.colorDisabledText
                : (prevHover.hovered || prevTap.pressed ? Theme.current.colorText0
                    : Theme.current.colorTertiary)
        }
    }

    // ---------------------------------------------------------------- 页码（默认档）
    Repeater {
        model: control.isSmall ? [] : control.pageList

        delegate: Item {
            id: pageCell

            required property var modelData
            required property int index

            objectName: "paginationCell"

            readonly property bool isEllipsis: pageCell.modelData === "..."
            readonly property bool isCurrent: !pageCell.isEllipsis
                && pageCell.modelData === control._current
            // 官方 renderPageList:383 `i < 3 ? restLeftPageList : restRightPageList`
            readonly property var sideList: pageCell.index < 3
                ? control.restLeftPageList : control.restRightPageList

            width: cellBox.width + control.itemMarginX * 2
            height: control.itemHeight

            Rectangle {
                id: cellBox

                objectName: "paginationCellBox"
                x: control.itemMarginX
                width: Math.max(control.itemMinWidth, cellLabel.implicitWidth)
                height: control.itemHeight
                radius: Theme.current.radiusSmall
                border.width: 0                                // $width-pagination_item_border
                color: control.disabled
                    ? (pageCell.isCurrent ? Theme.current.colorDisabledFill : "transparent")
                    : (cellTap.pressed ? Theme.current.colorFill1
                        : (pageCell.isCurrent ? Theme.current.colorPrimaryLightDefault
                            : (cellHover.hovered ? Theme.current.colorFill0 : "transparent")))

                HoverHandler {
                    id: cellHover

                    cursorShape: control.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                }

                TapHandler {
                    id: cellTap

                    onTapped: {
                        if (!control.disabled)
                            control.goPage(pageCell.modelData);
                    }
                }
            }

            Text {
                id: cellLabel

                objectName: "paginationCellText"
                anchors.centerIn: cellBox
                text: String(pageCell.modelData)
                color: control.disabled ? Theme.current.colorDisabledText
                    : (cellTap.pressed ? Theme.current.colorText0
                        : (pageCell.isCurrent ? Theme.current.colorPrimary
                            : Theme.current.colorText0))
                font.pixelSize: Theme.current.fontSizeRegular
                font.weight: pageCell.isCurrent ? Font.DemiBold : Font.Normal     // 600 / 400
            }

            // 官方 index.tsx:381-397：省略号且未禁用时整格被 Popover 包住，hover 出这一侧
            // 剩下的页码表；position / zIndex 直接来自 Pagination 的那两个 prop
            Popover {
                id: restPop

                objectName: "paginationRestPop"
                target: cellBox
                enabled: pageCell.isEllipsis && !control.disabled
                position: control.positionOf()
                zIndex: control.popoverZIndex
                rePosKey: control.currentPage

                PaginationRestList {
                    objectName: "paginationRestContent"

                    list: pageCell.sideList
                    onJumped: page => control.goPage(page)
                }
            }
        }
    }

    // ---------------------------------------------------------------- 迷你档的 c/t 格子
    Item {
        id: smallSlot

        objectName: "paginationSmallSlot"
        visible: control.isSmall
        width: smallBox.width
        height: control.itemHeight

        Rectangle {
            id: smallBox

            objectName: "paginationSmallBox"
            width: Math.max(control.smallItemMinWidth, smallLabel.implicitWidth)
            height: control.itemHeight
            radius: Theme.current.radiusSmall
            border.width: 0                                    // $width-pagination_item_border
            color: control.disabled ? "transparent"
                : (smallTap.pressed ? Theme.current.colorFill1
                    : (smallHover.hovered ? Theme.current.colorFill0 : "transparent"))

            HoverHandler {
                id: smallHover

                cursorShape: control.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            }

            // 官方这一格没有 onClick ⇒ 点它不跳页，只出 :active 的底色
            TapHandler {
                id: smallTap
            }
        }

        Text {
            id: smallLabel

            objectName: "paginationSmallLabel"
            anchors.centerIn: smallBox
            text: control.smallLabel
            color: control.disabled ? Theme.current.colorDisabledText : Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeRegular
        }

        // 官方 renderSmallPageSelect:442-453：hoverShowPageSelect 且未禁用时把这一格包进
        // Popover，内容是**全部页码**那张表（除 content 外全是 Popover 的缺省值）
        Popover {
            id: smallPop

            objectName: "paginationSmallPop"
            target: smallBox
            enabled: control.isSmall && control.hoverShowPageSelect && !control.disabled

            PaginationRestList {
                objectName: "paginationSmallRest"

                list: control._allPageNumbers
                onJumped: page => control.goPage(page)
            }
        }
    }

    // ---------------------------------------------------------------- 下一页
    Item {
        id: nextSlot

        objectName: "paginationNext"
        width: nextBox.width + control.itemMarginX * 2
        height: control.itemHeight

        readonly property real nodeWidth: control.nodeIsText(control.nextText) ? nextText.implicitWidth
            : (control.nodeIsComponent(control.nextText) ? nextLoader.implicitWidth : 20)

        Rectangle {
            id: nextBox

            objectName: "paginationNextBox"
            x: control.itemMarginX
            width: Math.max(control.itemMinWidth, nextSlot.nodeWidth)
            height: control.itemHeight
            radius: Theme.current.radiusSmall
            border.width: 0                                    // $width-pagination_item_border
            color: control.nextBlocked ? "transparent"
                : (nextTap.pressed ? Theme.current.colorFill1
                    : (nextHover.hovered ? Theme.current.colorFill0 : "transparent"))

            HoverHandler {
                id: nextHover

                cursorShape: control.nextBlocked ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            }

            TapHandler {
                id: nextTap

                onTapped: {
                    if (!control.nextBlocked)
                        control.goNext();
                }
            }
        }

        Text {
            id: nextText

            objectName: "paginationNextText"
            anchors.centerIn: nextBox
            visible: control.nodeIsText(control.nextText)
            text: String(control.nextText)
            font.pixelSize: Theme.current.fontSizeRegular
        }

        Loader {
            id: nextLoader

            objectName: "paginationNextLoader"
            anchors.centerIn: nextBox
            visible: control.nodeIsComponent(control.nextText)
            sourceComponent: control.nextText
        }

        Icon {
            id: nextIcon

            objectName: "paginationNextIcon"
            anchors.centerIn: nextBox
            visible: !control.nodeIsText(control.nextText) && !control.nodeIsComponent(control.nextText)
            name: "chevron_right"
            size: 20
            color: control.nextBlocked ? Theme.current.colorDisabledText
                : (nextHover.hovered || nextTap.pressed ? Theme.current.colorText0
                    : Theme.current.colorTertiary)
        }
    }

    // ---------------------------------------------------------------- 每页容量
    // 官方 renderPageSizeSwitch:283-322：只有默认档渲染它，小档连 showSizeChanger 都不吃
    Select {
        id: sizeSwitch

        objectName: "paginationSizeSwitch"
        visible: !control.isSmall && control.showSizeChanger
        options: control.sizeChangerOptions()
        value: control._pageSize
        disabled: control.disabled

        // 官方给 Select 挂 value={state.pageSize}，切完由 state 回灌；本库 Select 选中后会
        // 自己写 value（断掉外部绑定），所以这里把绑定装回去，等价于那次带 key 的重建
        onSelected: value => {
            control.changePageSize(value);
            sizeSwitch.value = Qt.binding(function () { return control._pageSize; });
        }
    }

    // ---------------------------------------------------------------- 快速跳转
    Item {
        id: quickSlot

        objectName: "paginationQuickJump"
        visible: control.showQuickJumper
        width: control.quickJumpMarginLeft + quickRow.width
        height: control.itemHeight

        Row {
            id: quickRow

            objectName: "paginationQuickRow"
            x: control.quickJumpMarginLeft
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                objectName: "paginationJumpToLabel"
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("跳至")
                color: control.quickJumpBlocked ? Theme.current.colorDisabledText
                    : Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
            }

            Item {
                width: control.itemMarginX * 2 + quickInput.width
                height: control.itemHeight

                InputNumber {
                    id: quickInput

                    objectName: "paginationQuickInput"
                    anchors.verticalCenter: parent.verticalCenter
                    x: control.itemMarginX
                    width: Math.min(control.quickJumpInputWidth, implicitWidth)
                    value: control._quickJumpPage
                    hideButtons: true
                    enabled: !control.quickJumpBlocked

                    onChange: value => {
                        control.handleQuickJumpNumberChange(value);
                        quickInput.value = Qt.binding(function () { return control._quickJumpPage; });
                    }

                    onBlur: control.handleQuickJumpBlur()
                }

                // 官方 onEnterPress 读的是输入框的当前文本；本库 InputNumber 没有 enterPress 信号，
                // 从它内层那只 Input 的 accepted 接进来
                Connections {
                    target: quickInput.innerInput

                    function onAccepted() {
                        control.handleQuickJump(quickInput.field.text);
                    }
                }
            }

            Text {
                objectName: "paginationPageLabel"
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("页")
                color: control.quickJumpBlocked ? Theme.current.colorDisabledText
                    : Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
            }
        }
    }
}
