pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 翻页器。小节标题逐条对齐官方 Pagination 文档的那 9 条 demo（加「如何引入」共 10 节，
// 页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/Pagination.qml / src/PaginationRestList.qml 文件头）：
//   · 撤掉 className / style 两条 DOM 通道；`prevText` / `nextText` 收成「字符串或 Component」。
//   · 三条回调是三个信号：onPageChange → pageChange、onPageSizeChange → pageSizeChange、
//     onChange → change(page, pageSize)。
//   · `size` 官方只有 small / default 两档，32 的格子高在两档里都一样：小档变的不是高度，
//     是「页码那一格换成 44 宽、margin 0 的 c/t 格」。
//   · 官方用 `'currentPage' in props` 判受控，这里按仓库惯例：currentPage 给了就算给了。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 「页码受控」那一节的状态（官方用 useState，端口放在页面根上）
    property int heldPage: 4

    component Note: Text {
        width: 700
        wrapMode: Text.WordWrap
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        lineHeight: 20
        lineHeightMode: Text.FixedHeight
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        // ================================================================ 如何引入
        GallerySection {
            title: "如何引入"

            Note {
                text: qsTr("import Semi\n\nPagination { total: 85; onChange: (page, size) => print(page, size) }")
            }
        }

        // ================================================================ 基本
        GallerySection {
            title: "基本"

            Column {
                spacing: 16

                Pagination { total: 85 }
                Pagination { total: 85; defaultCurrentPage: 6 }
            }

            Note {
                text: qsTr("不传 pageSize 时按 constructor 那条 `pageSize || pageSizeOpts[0] || 10` 落回 10 条/页，"
                    + "85 条 ⇒ 9 页。总页数超过 7 就截断，节点数恒为 7（省略号自己算一个）：\n"
                    + "· 当前页 < 4 ⇒ 1 2 3 4 … 尾两页\n· 当前页 = 4 ⇒ 1 2 3 4 5 … 尾页\n"
                    + "· 4 < 当前页 < 总页数-3 ⇒ 首页 … 前三格 … 尾页\n· 贴上尾巴 ⇒ 首页 … 倒数五页\n"
                    + "悬浮省略号会弹浮层，列出这一侧被折叠掉的页码（浮层宽 78、行高 32，一次最多露 5 行）。"
                    + "整组零动画：animation.scss 把 transition 的时长全指到 --semi-transition_duration-none。")
            }
        }

        // ================================================================ 禁用
        GallerySection {
            title: "禁用"

            Column {
                spacing: 16

                Pagination { total: 85; defaultCurrentPage: 3; disabled: true }
                Pagination { total: 85; defaultCurrentPage: 3; disabled: true; showTotal: true }
            }

            Note {
                text: qsTr("禁用档只挂 `-item-all-disabled`：字色 disabled-text、底透明，悬浮也不变。"
                    + "当前页那一格额外挂 `-all-disabled-active`，底换成 --semi-color-disabled-fill（不是主色底）。"
                    + "前后翻页两个箭头走 `isDisabled = xxxDisabled || disabled` 那条合并判定，"
                    + "图标色 disabled-text、悬浮不变色（`-prev.item-disabled` 写在 `:hover` 之后，同特异度后者赢）。\n"
                    + "带总页数那一行是给 `-disabled .semi-page-total` 那条规则看的：禁用时计数文本也换禁用色。")
            }
        }

        // ================================================================ 总页数显示
        GallerySection {
            title: "总页数显示"

            Column {
                spacing: 16

                Pagination { total: 85; showTotal: true }
                Pagination { total: 85; pageSize: 20; showTotal: true }
            }

            Note {
                text: qsTr("showTotal 的缺省是 false（defaultProps:111 —— 官方文档 API 表那一栏是空的，"
                    + "别照表读）。文案是 locale 的「总页数：${total}」，而这里填的是页数不是条数："
                    + "85 条 / 10 条每页 ⇒「总页数：9」。这一格是 span，没有任何 margin，"
                    + "紧贴着它的那个 prev 自带 4px 左距。")
            }
        }

        // ================================================================ 指定当前页码
        GallerySection {
            title: "指定当前页码"

            Column {
                spacing: 16

                Pagination { total: 85; defaultCurrentPage: 5 }
                Pagination { total: 85; defaultCurrentPage: 9 }
            }

            Note {
                text: qsTr("defaultCurrentPage 只在构造时读一次（官方 constructor:139），"
                    + "之后改这个 prop 不影响页码。这里用两个独立实例分别起在 5 与 9，"
                    + "好让两种截断档位同时看得见。\n"
                    + "上游有个坑要提前知道：非受控档（没传 currentPage）只要 total 或 pageSize 这两个 "
                    + "prop 变过，componentDidUpdate 就把 `updatePage(targetPageIndex = 1, ...)"
                    + "的缺省参数喂进去，当前页被打回 1 —— 端口照抄。")
            }
        }

        // ================================================================ 每页容量切换
        GallerySection {
            title: "每页容量切换"

            Column {
                spacing: 16

                Pagination { total: 85; showSizeChanger: true; defaultCurrentPage: 3 }
                Pagination { total: 85; showSizeChanger: true; size: Enums.Small }
            }

            Note {
                text: qsTr("切换器是官方那只 Select，选项文案取 locale 的「每页条数：${pageSize}」，"
                    + "选中后走 foundation.changePageSize：先 notify 页容量变化，再按旧的 pageSize "
                    + "换算当前页（(c-1)*旧size+1 向上取整到新 size）。\n"
                    + "第二只是小档：官方 renderSmallPage 压根不调 renderPageSizeSwitch ⇒ 小档开了 "
                    + "showSizeChanger 也不会出现切换器，可它照样参与 hideOnSinglePage 的豁免，"
                    + "constructor:152 那条 console.warn 就是提醒这个组合。端口的 Select 是定宽 200，"
                    + "官方那只是随内容撑开。")
            }
        }

        // ================================================================ 快速跳转至某页
        GallerySection {
            title: "快速跳转至某页"

            Column {
                spacing: 16

                Pagination { total: 85; showQuickJumper: true; defaultCurrentPage: 2 }
                Pagination { total: 85; pageSize: 5; showQuickJumper: true; showSizeChanger: true }
            }

            Note {
                text: qsTr("「跳至 [输入框] 页」，输入框 max-width 50、左右各 4 的外边距。"
                    + "输入走 InputNumber 的 onChange 存进 state.quickJumpPage，"
                    + "回车或失焦都会跳：值 > 总页数夹到总页数，<= 0 夹到 1，非数字直接 return（且不清空输入框），"
                    + "跳完把输入框抹干净。总页数只有 1 页时这条也被禁用（官方那句 totalPageNum === 1），"
                    + "整段文案跟着变禁用色。")
            }
        }

        // ================================================================ 页码受控
        GallerySection {
            title: "页码受控"

            Column {
                spacing: 16

                Row {
                    spacing: Theme.current.spacingTight

                    Button {
                        text: qsTr("跳到第 2 页")
                        onClicked: page.heldPage = 2
                    }
                    Button {
                        text: qsTr("跳到最后一页")
                        onClicked: page.heldPage = 9
                    }
                }

                Pagination {
                    total: 85
                    currentPage: page.heldPage
                    showSizeChanger: true
                    onChange: (p, size) => { page.heldPage = p; }
                }

                Note {
                    text: qsTr("给了 currentPage 就是受控档：翻页只发 pageChange / change 两个信号，"
                        + "端口不写内部页码，显示完全由外面回灌（官方靠 `'currentPage' in props` 判这一条）。"
                        + "上面两颗按钮直接改外层状态，也能把这个翻页器拧走 —— 这正是要演示的点。\n"
                        + "换每页容量时受控档同样只发信号；换算结果放在 change 的第一个参数里，"
                        + "使用方接住再回灌才动得起来。")
                }
            }
        }

        // ================================================================ 预设每页容量可选值
        GallerySection {
            title: "预设每页容量可选值"

            Column {
                spacing: 16

                Pagination { total: 85; showSizeChanger: true; pageSizeOpts: [10, 20, 40] }
                Pagination { total: 85; pageSize: 25; showSizeChanger: true }
                Pagination { total: 85; pageSize: 200; showSizeChanger: true }
            }

            Note {
                text: qsTr("pageSizeOpts 缺省 [10, 20, 40, 100]。当前页容量不在这张表里时，"
                    + "pageSizeInOpts() 会把它插进表里 —— 插的位置用 `findIndex(el => el > pageSize)`，"
                    + "找不到（比所有可选项都大）时 index 是 -1，`splice(-1, 0, x)` 就把 x 塞到倒数第二个位置。"
                    + "第二只是正常档（25 排在 40 之前：10 20 25 40 100），"
                    + "第三只就是上游那个错位（200 排在 100 之前：10 20 40 200 100），照抄不修。")
            }
        }

        // ================================================================ 迷你版本
        GallerySection {
            title: "迷你版本"

            Column {
                spacing: 16

                Pagination { total: 85; size: Enums.Small; defaultCurrentPage: 4 }
                Pagination { total: 85; size: Enums.Small; hoverShowPageSelect: true }
                Pagination { total: 85; size: Enums.Small; disabled: true }
                Pagination { total: 85; size: Enums.Small; showQuickJumper: true }
                Pagination { total: 5; size: Enums.Small; hideOnSinglePage: true }
            }

            Note {
                text: qsTr("小档只有三格：prev、`当前页/总页数`、next，中间那格是 min-width 44、margin 0，"
                    + "而且官方没给它 onClick ⇒ 点它不跳页，只有悬浮/按下的底色会变。"
                    + "hoverShowPageSelect 打开后，悬浮这一格会弹一张全部页码的表（选一页就跳过去）；"
                    + "这张表在 constructor 里算好，之后一改 total 就会被清空 —— "
                    + "componentDidUpdate 传给 updateAllPageNumbers 的是 props.pageSize，没传时是 undefined，"
                    + "于是 `Math.ceil(total / undefined)` = NaN ⇒ Array.from({length: NaN}) = []，又一个上游 bug。\n"
                    + "最后那只演示 hideOnSinglePage：只有 1 页时整块不渲染（官方是 return null）。")
            }
        }
    }
}
