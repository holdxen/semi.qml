pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Tabs 标签页。小节顺序与标题逐条对齐 content/navigation/tabs/index.md 的那 12 条 demo
// （加「如何引入」共 13 节，页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/Tabs.qml / src/TabItem.qml / src/TabPane.qml 文件头）：
//   · 撤掉 className / style / tabBarClassName / tabBarStyle / contentStyle / visibleTabsStyle
//     这一整批 DOM/CSS 通道；`tab` / `icon` / `tabBarExtraContent` / `more.render` /
//     `renderArrow` / `renderTabBar` 收成「字符串或 Component」。
//   · 回调收成信号：onChange → change、onTabClick → tabClick、onTabClose → tabClose、
//     onVisibleTabsChange → visibleTabsChange。
//   · 「拖拽排序」官方是 renderTabBar + 第三方 @dnd-kit 的**集成 demo**，不是 Tabs 的行为，
//     端口没有对应物 ⇒ 那一节只留说明。
//   · 官方 demo 里 `style={{ width: '60%' }}` 那一档宽度，端口写在 Tabs 的 width 上。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ---------------- 「动态更新」与「关闭」两节的状态（官方用 state，端口放在页面根上）
    property var dynamicPanes: [
        { itemKey: "1", title: "Tab 1" },
        { itemKey: "2", title: "Tab 2" }
    ]
    property string dynamicActive: "1"
    property int dynamicSeed: 3

    property var closableList: [
        { itemKey: "1", tab: "文档" },
        { itemKey: "2", tab: "快速起步" }
    ]

    component Note: Text {
        width: 700
        wrapMode: Text.WordWrap
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        lineHeight: 20
        lineHeightMode: Text.FixedHeight
    }

    /// 官方那三格内容
    function paneText(text) {
        return text;
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        // ================================================================ 如何引入
        GallerySection {
            title: "如何引入"

            Column {
                width: 760
                spacing: 10

                Text {
                    text: "import { Tabs, TabPane } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("Tabs 官方 26 条 prop（activeKey / children / className / collapsible /"
                        + " contentStyle / defaultActiveKey / keepDOM / lazyRender / onChange / onTabClick /"
                        + " renderTabBar / showRestInDropdown / size / style / tabBarClassName /"
                        + " tabBarExtraContent / tabBarStyle / tabList / tabPaneMotion / tabPosition / type /"
                        + " onTabClose / preventScroll / more / onVisibleTabsChange / visibleTabsStyle /"
                        + " arrowPosition / renderArrow / dropdownProps），TabPane 9 条。"
                        + "端口撤掉 6 条 DOM/CSS 通道，其余全收。")
                }
            }
        }

        // ================================================================ 基本用法
        GallerySection {
            title: "基本用法"

            Column {
                width: 700
                spacing: 24

                Tabs {
                    width: 700
                    type: "line"

                    TabPane {
                        itemKey: "1"
                        tab: "文档"

                        Text { text: "文档的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "2"
                        tab: "快速起步"

                        Text { text: "快速起步的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "3"
                        tab: "帮助"

                        Text { text: "帮助的内容"; color: Theme.current.colorText0 }
                    }
                }

                Tabs {
                    width: 700
                    type: "button"

                    TabPane {
                        itemKey: "1"
                        tab: "文档"

                        Text { text: "文档的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "2"
                        tab: "快速起步"

                        Text { text: "快速起步的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "3"
                        tab: "帮助"

                        Text { text: "帮助的内容"; color: Theme.current.colorText0 }
                    }
                }

                Tabs {
                    width: 700
                    type: "card"
                    tabList: [
                        { itemKey: "1", tab: "文档" },
                        { itemKey: "2", tab: "快速起步" },
                        { itemKey: "3", tab: "帮助" }
                    ]
                }

                Tabs {
                    width: 700
                    type: "slash"
                    tabList: [
                        { itemKey: "1", tab: "文档" },
                        { itemKey: "2", tab: "快速起步" },
                        { itemKey: "3", tab: "帮助" }
                    ]
                }

                Note {
                    text: qsTr("官方这一节就是四档 type 各一条：line 与 button 走 TabPane 子元素档、"
                        + "card 与 slash 走 tabList 数组档。数组档只出标签栏、零面板"
                        + "（PlainTab 没有内容字段），所以后两条下面没有内容区。"
                        + "两条路同时给时数组赢（index.tsx:197-199）。")
                }
            }
        }

        // ================================================================ 带图标的
        GallerySection {
            title: "带图标的"

            Column {
                width: 700
                spacing: 12

                Tabs {
                    width: 700

                    TabPane {
                        itemKey: "1"
                        tab: "文档"
                        icon: "mail_stroked"

                        Text { text: "文档的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "2"
                        tab: "快速起步"
                        icon: "lightning_stroked"

                        Text { text: "快速起步的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "3"
                        tab: "帮助"
                        icon: "help_circle_stroked"

                        Text { text: "帮助的内容"; color: Theme.current.colorText0 }
                    }
                }

                Note {
                    text: qsTr("官方图标是 16px 的 `.semi-icon` + `margin-right: 8; top: 3px`（CSS:21914-21920），"
                        + "颜色阶梯是 text-2 → 悬浮 text-0 → 选中 primary。"
                        + "官方 demo 用的是 IconDoc / IconLight / IconHelp，semi-icons 里没有同名件，"
                        + "端口取形状最接近的三个。图标那层官方挂的 `semi-tabs-bar-icon` 是死类名（0 条规则）。")
                }
            }
        }

        // ================================================================ 更多选项收入 More 展示
        GallerySection {
            title: "更多选项收入 More 展示"

            Column {
                width: 700
                spacing: 24

                Tabs {
                    width: 420
                    type: "card"
                    more: 4

                    Repeater {
                        model: 10

                        delegate: TabPane {
                            id: repPane
                            required property int index

                            itemKey: "Tab-" + index
                            tab: "Tab-" + index

                            Text { text: "Tab-" + repPane.index + " 的内容"; color: Theme.current.colorText0 }
                        }
                    }
                }

                Tabs {
                    width: 420
                    type: "card"
                    more: { count: 4 }

                    Repeater {
                        model: 10

                        delegate: TabPane {
                            id: repPane1
                            required property int index

                            itemKey: "T-" + index
                            tab: "Tab-" + index

                            Text { text: "Tab-" + repPane1.index + " 的内容"; color: Theme.current.colorText0 }
                        }
                    }
                }

                Note {
                    text: qsTr("`more` 传数字 = 收进下拉的数量（不是留下的数量，TabBar.tsx:374 是 "
                        + "`list.length - Math.min(more, length)`）；对象档还能给 `render` 换触发器。"
                        + "官方第二条 demo 的 render 返回一只 Button，端口这里用缺省触发器（「更多」+ 下箭头）"
                        + "—— 触发器文案官方走 i18n，端口写死。`more` 给 0 被当真值判断的假值忽略、"
                        + "给 true 上游直接抛 ⇒ 端口收成「不算 more 档」。")
                }
            }
        }

        // ================================================================ 垂直的标签栏
        GallerySection {
            title: "垂直的标签栏"

            Row {
                spacing: 40

                Tabs {
                    width: 220
                    height: 160
                    tabPosition: "left"

                    TabPane {
                        itemKey: "1"
                        tab: "文档"

                        Text { text: "文档的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "2"
                        tab: "快速起步"

                        Text { text: "快速起步的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "3"
                        tab: "帮助"

                        Text { text: "帮助的内容"; color: Theme.current.colorText0 }
                    }
                }

                Tabs {
                    width: 220
                    height: 160
                    type: "card"
                    tabPosition: "left"

                    TabPane {
                        itemKey: "1"
                        tab: "文档"

                        Text { text: "文档的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "2"
                        tab: "快速起步"

                        Text { text: "快速起步的内容"; color: Theme.current.colorText0 }
                    }
                }

                Tabs {
                    width: 220
                    height: 160
                    type: "button"
                    tabPosition: "left"

                    TabPane {
                        itemKey: "1"
                        tab: "文档"

                        Text { text: "文档的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "2"
                        tab: "快速起步"

                        Text { text: "快速起步的内容"; color: Theme.current.colorText0 }
                    }
                }
            }
        }

        // ================================================================ 滚动折叠
        GallerySection {
            title: "滚动折叠"

            Column {
                width: 700
                spacing: 24

                Tabs {
                    width: 420
                    type: "card"
                    collapsible: true

                    Repeater {
                        model: 10

                        delegate: TabPane {
                            id: repPane2
                            required property int index

                            itemKey: "C-" + index
                            tab: "Tab-" + index

                            Text { text: "Tab-" + repPane2.index + " 的内容"; color: Theme.current.colorText0 }
                        }
                    }
                }

                Tabs {
                    width: 420
                    type: "card"
                    collapsible: true
                    arrowPosition: "start"

                    Repeater {
                        model: 10

                        delegate: TabPane {
                            id: repPane3
                            required property int index

                            itemKey: "S-" + index
                            tab: "Tab-" + index

                            Text { text: "Tab-" + repPane3.index + " 的内容"; color: Theme.current.colorText0 }
                        }
                    }
                }

                Note {
                    text: qsTr("官方这一节三条 demo（collapsible / 自定义箭头 / arrowPosition='start'），"
                        + "自定义箭头那条官方在 renderArrow 里塞了一段「点箭头直接跳到最后一步」的演示代码，"
                        + "端口把它单列成一句说明：renderArrow 收到的是 `side`（start/end）与 `rest`（这一侧收起来的项）。"
                        + "折叠档走的是 OverflowList 的滚动档，两侧箭头定宽；"
                        + "官方 `isTabsWrapped` 那条判据在 nowrap 的 bar 上根本够不到（见坑记录）。")
                }
            }
        }

        // ================================================================ 自动溢出检测
        GallerySection {
            title: "自动溢出检测"

            Column {
                width: 700
                spacing: 24

                Tabs {
                    width: 700
                    type: "card"
                    collapsible: "auto"

                    Repeater {
                        model: 4

                        delegate: TabPane {
                            id: repPane4
                            required property int index

                            itemKey: "A-" + index
                            tab: "Tab-" + index

                            Text { text: "Tab-" + repPane4.index + " 的内容"; color: Theme.current.colorText0 }
                        }
                    }
                }

                Tabs {
                    width: 260
                    type: "card"
                    collapsible: "auto"

                    Repeater {
                        model: 4

                        delegate: TabPane {
                            id: repPane5
                            required property int index

                            itemKey: "B-" + index
                            tab: "Tab-" + index

                            Text { text: "Tab-" + repPane5.index + " 的内容"; color: Theme.current.colorText0 }
                        }
                    }
                }

                Note {
                    text: qsTr("`collapsible: \"auto\"` 是「放不下才折」：端口按标签栏自然宽与可用宽比一次 "
                        + "（官方是 `scrollWidth > clientWidth + 1`），折下去之后由 OverflowList 的可见集"
                        + "决定什么时候放开。上面那条宽、下面那条窄，同一份四项数据。")
                }
            }
        }

        // ================================================================ 禁用
        GallerySection {
            title: "禁用"

            Column {
                width: 700
                spacing: 12

                Tabs {
                    width: 700
                    defaultActiveKey: "1"

                    TabPane {
                        itemKey: "1"
                        tab: "文档"

                        Text { text: "文档的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "2"
                        tab: "快速起步"
                        disabled: true

                        Text { text: "快速起步的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "3"
                        tab: "帮助"

                        Text { text: "帮助的内容"; color: Theme.current.colorText0 }
                    }
                }

                Note {
                    text: qsTr("禁用格点不动（TabItem.tsx:65 只挡 onClick），但 CSS 的 `:hover` 特异度比 "
                        + "`-disabled` 高 ⇒ 悬停照样变 text-0，端口照抄。方向键 / Home / End 走的是"
                        + "「过滤掉 aria-disabled=true」那份名单 ⇒ 会跳过禁用格。")
                }
            }
        }

        // ================================================================ 标签栏内容扩展
        GallerySection {
            title: "标签栏内容扩展"

            Column {
                width: 700
                spacing: 12

                Tabs {
                    width: 700
                    tabBarExtraContent: extraButton

                    TabPane {
                        itemKey: "1"
                        tab: "文档"

                        Text { text: "文档的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "2"
                        tab: "快速起步"

                        Text { text: "快速起步的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "3"
                        tab: "帮助"

                        Text { text: "帮助的内容"; color: Theme.current.colorText0 }
                    }
                }

                Note {
                    text: qsTr("extra 槽官方是 `float: right`（写在 JS 内联样式里，CSS 没有 float 规则）"
                        + "⇒ 端口贴右。它的高只有 line 档给了（50，small 档 36），而 line 格子高 52 "
                        + "⇒ 官方自己就有 2px 竖向错位，端口照抄这个 50。card / button / slash 那一档 "
                        + "extra 只有 0 5px 的内边距、没有高度。")
                }
            }
        }

        // ================================================================ 标签栏二次封装
        GallerySection {
            title: "标签栏二次封装"

            Column {
                width: 700
                spacing: 12

                Tabs {
                    width: 700
                    renderTabBar: wrappedBar

                    TabPane {
                        itemKey: "1"
                        tab: "文档"

                        Text { text: "文档的内容"; color: Theme.current.colorText0 }
                    }
                    TabPane {
                        itemKey: "2"
                        tab: "快速起步"

                        Text { text: "快速起步的内容"; color: Theme.current.colorText0 }
                    }
                }

                Note {
                    text: qsTr("官方 `renderTabBar(tabBarProps, DefaultTabBar)` 拿到的是一整套 TabBar 的 props "
                        + "再加默认实现；端口给钩子节点注入两枚：`host`（Tabs 自己）与 `defaultTabBar`"
                        + "（那份默认标签栏的 Component），钩子自己 Loader 它。下面这条就是在默认栏外面套了一圈边框。")
                }
            }
        }

        // ================================================================ 拖拽排序
        GallerySection {
            title: "拖拽排序"

            Note {
                text: qsTr("官方这一节不是 Tabs 的行为，是一段集成 demo：`renderTabBar` 里把默认栏包进 "
                    + "`@dnd-kit` 的 DndContext / SortableContext，再靠 `onTabClick` 回写顺序。"
                    + "端口没有 @dnd-kit 的对应物（库内的拖拽见 Tree 的 draggable 与 DragMove 页），"
                    + "而「换顺序」在端口这边就是把 `tabList` / TabPane 的数组重排一次 ⇒ 这一节只留说明、不放节点。")
            }
        }

        // ================================================================ 动态更新
        GallerySection {
            title: "动态更新"

            Column {
                width: 700
                spacing: 12

                Tabs {
                    id: dynamicTabs

                    width: 700
                    activeKey: page.dynamicActive
                    tabBarExtraContent: dynamicAdd

                    onTabClick: key => page.dynamicActive = key

                    Repeater {
                        model: page.dynamicPanes

                        delegate: TabPane {
                            id: dynPane

                            required property var modelData

                            itemKey: modelData.itemKey
                            tab: modelData.title

                            Text {
                                text: dynPane.modelData.title + " 的内容"
                                color: Theme.current.colorText0
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("官方这一节把「新增 / 删除」两枚按钮放在 tabBarExtraContent 里，"
                        + "并且由使用方自己改数组 —— 端口同理。注意上游那条 `panePickKeys` 少了 `closable`"
                        + "（index.tsx:18）⇒ 只改某面板的 closable 不会触发重算，这条上游真 bug 端口不复现"
                        + "（QML 侧属性变化本来就能被看见）。")
                }
            }
        }

        // ================================================================ 关闭
        GallerySection {
            title: "关闭"

            Column {
                width: 700
                spacing: 12

                Tabs {
                    width: 700
                    type: "card"
                    defaultActiveKey: "1"

                    onTabClose: key => {
                        const next = [];
                        for (let i = 0; i < page.closableList.length; ++i)
                            if (page.closableList[i].itemKey !== key)
                                next.push(page.closableList[i]);
                        page.closableList = next;
                    }

                    Repeater {
                        model: page.closableList

                        delegate: TabPane {
                            id: closablePane
                            required property var modelData

                            itemKey: modelData.itemKey
                            tab: modelData.tab
                            closable: true

                            Text {
                                text: closablePane.modelData.tab + " 的内容"
                                color: Theme.current.colorText0
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("`onTabClose` 从不真的关闭（foundation.ts:71-73 → index.tsx:138-140 只通知）"
                        + "⇒ 使用方自己从数据里摘掉那一项，上面这条就是这么写的。文档那句"
                        + "「只有卡片式支持关闭」与代码不符：`closable` 不判 type，line / button / slash 一样出 ×。"
                        + "选中那格的 × 也不跟文字变 primary，被显式钉回 text-2。")
                }
            }
        }
    }

    // ================================================================ 两节要用的 Component
    Component {
        id: extraButton

        Button {
            text: "附加操作"
        }
    }

    Component {
        id: dynamicAdd

        Button {
            text: "新增一页"
            onClicked: {
                const key = String(page.dynamicSeed);
                page.dynamicPanes = page.dynamicPanes.concat(
                    [{ itemKey: key, title: "Tab " + key }]);
                page.dynamicSeed = page.dynamicSeed + 1;
                page.dynamicActive = key;
            }
        }
    }

    /// renderTabBar 的钩子节点：自己声明这两枚，端口在 Loader 完成后写进来
    Component {
        id: wrappedBar

        Item {
            id: hookRoot

            property var host: null
            property Component defaultTabBar: null

            implicitWidth: innerLoader.implicitWidth
            implicitHeight: innerLoader.implicitHeight + 16

            Rectangle {
                anchors.fill: parent
                radius: Theme.current.radiusSmall
                color: Theme.current.colorBg0
                border.width: 1
                border.color: Theme.current.colorBorder
            }

            Loader {
                id: innerLoader

                x: 8
                y: 8
                width: parent.width - 16
                height: hookRoot.controlBarHeight
                sourceComponent: hookRoot.defaultTabBar
            }

            readonly property real controlBarHeight: hookRoot.host === null ? 52
                : hookRoot.host.itemHeight
        }
    }
}
