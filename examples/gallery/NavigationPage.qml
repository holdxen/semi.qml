pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Navigation 导航。小节顺序与标题逐条对齐 content/navigation/navigation/index.md 的
// 那 9 条 demo（加「如何引入」共 10 节，页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/Navigation*.qml 文件头）：
//   · header / footer 官方既收 ReactNode 又收配置对象，端口是两个属性槽；
//     `style` 对应 QML 自己的 width/height；`bodyStyle` 只认 `height` 一个键（就是列表区
//     高度，官方各 demo 都靠它给列表定高），其余键是 DOM 内联样式（坑 91），滚动行为本库由
//     Flickable 自带。
//   · 官方 icon 收 ReactNode（IconAvatar / IconSemiLogo …），端口收图标名字符串。
//   · 「配合 react-router」那节的 Link 外壳本库没有路由，改用 link 语义的占位说明。
//   · 「受控属性」那节官方用 useState 三条，端口把状态放在页面根属性上。
//   · 官方各 demo 都不给 Nav 写内联宽度（展开 240 与收起 60 都来自类名
//     `.semi-navigation` / `-collapsed`），所以这里也不写 `width`：写了就等于 DOM 里
//     的 `style={{width: 240}}` 盖过类名，收起档再也缩不回去。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

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
                    text: "import { Nav } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }
        }

        // ================================================================ 基本使用
        GallerySection {
            title: "基本使用"

            Row {
                spacing: 24

                Navigation {
                    bodyStyle: ({ height: 320 })     // 官方 bodyStyle={{ height: 320 }}

                    items: [
                        { itemKey: "user", text: "用户管理", icon: "user" },
                        { itemKey: "union", text: "活动管理", icon: "article" },
                        { text: "任务平台", icon: "folder", itemKey: "job",
                          items: ["任务管理", "用户任务查询"] }
                    ]

                    header: NavigationHeader {
                        logo: semiLogoComp
                        text: "Semi 运营后台"
                    }

                    footer: NavigationFooter { collapseButton: true }
                }

                Text {
                    width: 320
                    text: qsTr("传 items 数组就能得到一个导航栏：itemKey 是唯一标识（必须），"
                        + "text 是文案，icon 是图标名；带 items 的条目自动渲染成可展开的子导航"
                        + "（字符串条目 itemKey 取自身）。header 收 logo（Component，36×36）"
                        + "与文字，footer 传 collapseButton: true 得到内置的「收起侧边栏」按钮"
                        + "（仅竖直档生效）。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ================================================================ 导航样式定义
        GallerySection {
            title: "导航样式定义"

            Row {
                spacing: 24

                Navigation {
                    height: 520                       // 官方 style={{ height: 520 }}
                    bodyStyle: ({ height: 300 })      // 官方 bodyStyle={{ height: 300 }}

                    items: [
                        { itemKey: "user", text: "用户管理", icon: "user" },
                        { itemKey: "2", text: "订单管理", icon: "inbox" },
                        { itemKey: "3", text: "资源管理", icon: "folder" },
                        { text: "任务平台", icon: "edit", itemKey: "4",
                          items: ["任务管理", "用户任务查询"] },
                        { itemKey: "5", text: "推送通知", icon: "bell" },
                        { itemKey: "6", text: "任务", icon: "list" },
                        { itemKey: "7", text: "活动管理", icon: "flag" },
                        { itemKey: "8", text: "内容工具", icon: "menu" },
                        { itemKey: "9", text: "快捷导航", icon: "star" }
                    ]

                    header: NavigationHeader {
                        logo: semiLogoComp
                        text: "Semi 运营后台"
                    }

                    footer: NavigationFooter { collapseButton: true }
                }

                Text {
                    width: 320
                    text: qsTr("条目多时给 Navigation 一个固定高度（官方 style={{ height: 520 }} "
                        + "配 bodyStyle={{ height: 300 }}）：容器 520、列表区 300，超出就在列表区里"
                        + "纵向滚动，header 与 footer 固定不动。端口 style 对应 width/height，"
                        + "bodyStyle 只认 height 一个键。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ================================================================ JSX 写法
        GallerySection {
            title: "JSX 写法"

            Row {
                spacing: 24

                Navigation {
                    bodyStyle: ({ height: 300 })      // 官方 bodyStyle={{ height: 300 }}

                    defaultSelectedKeys: ["home"]

                    NavigationHeader {
                        logo: semiLogoComp
                        text: "Semi 运营后台"
                    }

                    NavigationItem { itemKey: "home"; icon: "home"; text: "首页" }
                    NavigationItem { itemKey: "apps"; icon: "apps"; text: "应用" }
                    NavigationSub {
                        itemKey: "task"
                        icon: "list"
                        text: "任务"
                        NavigationItem { itemKey: "mine"; text: "我的任务" }
                        NavigationItem { itemKey: "team"; text: "团队任务" }
                    }
                    NavigationItem { itemKey: "folder"; icon: "folder"; text: "归档" }

                    NavigationFooter { collapseButton: true }
                }

                Text {
                    width: 320
                    text: qsTr("children 档：直接在 Navigation 里声明 NavigationHeader / "
                        + "NavigationItem / NavigationSub / NavigationFooter（官方 JSX 写法的对应）。"
                        + "items 与 children 可以同时给，items 渲染在前；level 在 children 档"
                        + "由使用方手写（items 档自动下发）。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ================================================================ 配合 react-router 等路由组件
        GallerySection {
            title: "配合 react-router 等路由组件"

            Row {
                spacing: 24

                Navigation {
                    height: 240

                    items: [
                        { itemKey: "home", text: "首页", icon: "home" },
                        { itemKey: "docs", text: "文档", icon: "article" },
                        { itemKey: "admin", text: "管理后台", icon: "setting" }
                    ]
                }

                Text {
                    width: 320
                    text: qsTr("官方 demo 给 Nav.Item 包一层 <Link> 做路由跳转；本库没有路由，"
                        + "Item 的 link 属性保留了官方 prop 面但无落点（QML 里没有 <a href>）。"
                        + "接路由时在 onSelect / onClick 回调里自己跳转即可。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ================================================================ 垂直与水平布局
        GallerySection {
            title: "垂直与水平布局"

            Column {
                spacing: 24

                Row {
                    spacing: 24

                    Navigation {
                        bodyStyle: ({ height: 300 })   // 官方 bodyStyle={{ height: 300 }}

                        items: [
                            { itemKey: "user", text: "用户管理", icon: "user" },
                            { itemKey: "union", text: "活动管理", icon: "folder" },
                            { itemKey: "union-management", text: "任务管理", icon: "edit",
                              items: ["任务设置", "任务查询", "信息录入"] },
                            { text: "公告管理", icon: "bell", itemKey: "job",
                              items: ["推送管理", "已推送查询"] }
                        ]

                        header: NavigationHeader {
                            logo: semiLogoComp
                            text: "Semi 运营后台"
                        }

                        footer: NavigationFooter { collapseButton: true }
                    }

                    Text {
                        width: 320
                        text: qsTr("垂直布局（默认，mode: Enums.DirectionVertical）。"
                            + "isCollapsed、openKeys / defaultOpenKeys、footer 的收起按钮"
                            + "都只在竖直档有效。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                        wrapMode: Text.WordWrap
                    }
                }

                Row {
                    spacing: 24

                    Navigation {
                        width: 788
                        height: 60
                        mode: Enums.DirectionHorizontal

                        items: [
                            { itemKey: "user", text: "用户管理", icon: "user" },
                            { itemKey: "union", text: "活动管理", icon: "folder" },
                            { itemKey: "approve-management", text: "审批管理", icon: "import",
                              items: [ "入驻审核",
                                       { itemKey: "operation-management", text: "运营管理",
                                         items: ["人员管理", "人员变更"] } ] },
                            { text: "任务平台", icon: "list", itemKey: "job",
                              items: ["任务管理", "用户任务查询"] }
                        ]

                        header: NavigationHeader {
                            logo: semiLogoComp
                            text: "Semi 运营后台"
                        }
                    }

                    Text {
                        width: 320
                        text: qsTr("水平布局（mode: Enums.DirectionHorizontal）：条目横排，"
                            + "子导航收进浮层（顶级 bottomLeft、嵌套 rightTop）。"
                            + "官方 demo 的 footer 是一个头像下拉，端口用同一套 Dropdown 摆在"
                            + "导航下方示意。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // ================================================================ 展开收起箭头位置
        GallerySection {
            title: "展开收起箭头位置"

            Row {
                spacing: 24

                Navigation {
                    bodyStyle: ({ height: 300 })      // 官方 bodyStyle={{ height: 300 }}

                    toggleIconPosition: "left"
                    defaultOpenKeys: ["job"]

                    items: [
                        { itemKey: "user", text: "用户管理", icon: "user" },
                        { itemKey: "union", text: "活动管理", icon: "bell" },
                        { text: "任务平台", icon: "edit", itemKey: "job",
                          items: ["任务管理", "用户任务查询"] }
                    ]

                    header: NavigationHeader {
                        logo: semiLogoComp
                        text: "Semi 运营后台"
                    }

                    footer: NavigationFooter { collapseButton: true }
                }

                Text {
                    width: 320
                    text: qsTr("toggleIconPosition: 'left' 把子导航的展开箭头挪到文字前面"
                        + "（缺省 'right' 在行尾）。官方 left 档空槽占 20 + 12，端口照占。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ================================================================ 导航缩进
        GallerySection {
            title: "导航缩进"

            Row {
                spacing: 24

                Navigation {
                    bodyStyle: ({ height: 300 })      // 官方 bodyStyle={{ height: 300 }}

                    limitIndent: false
                    defaultOpenKeys: ["job", "mission1"]

                    items: [
                        { itemKey: "user", text: "用户管理", icon: "user" },
                        { text: "任务平台", icon: "bell", itemKey: "job",
                          items: [ "任务管理",
                                   { text: "任务1", icon: "edit", itemKey: "mission1",
                                     items: [ "任务2",
                                              { text: "任务3拆解", icon: "menu", itemKey: "mission3",
                                                items: ["子任务1", "子任务2"] } ] } ] }
                    ]

                    header: NavigationHeader {
                        logo: semiLogoComp
                        text: "Semi 运营后台"
                    }

                    footer: NavigationFooter { collapseButton: true }
                }

                Text {
                    width: 320
                    text: qsTr("limitIndent: false 让缩进按层级递进（缺省只对第一级有效）。"
                        + "占位公式照官方：有图标且未 indent 时占 level 个槽，否则 level − 1；"
                        + "items 档的 level 自动下发，children 档要手写。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ================================================================ 非受控属性
        GallerySection {
            title: "非受控属性"

            Row {
                spacing: 24

                Navigation {
                    bodyStyle: ({ height: 300 })      // 官方 bodyStyle={{ height: 300 }}

                    defaultOpenKeys: ["job"]
                    defaultSelectedKeys: ["信息录入"]
                    defaultIsCollapsed: true

                    items: [
                        { itemKey: "user", text: "用户管理", icon: "user" },
                        { itemKey: "union", text: "活动管理", icon: "bell" },
                        { itemKey: "union-management", text: "任务管理", icon: "edit",
                          items: ["公告设置", "任务查询", "信息录入"] },
                        { text: "任务平台", icon: "folder", itemKey: "job",
                          items: ["任务管理", "用户任务查询"] }
                    ]

                    header: NavigationHeader {
                        logo: semiLogoComp
                        text: "Semi 运营后台"
                    }

                    footer: NavigationFooter { collapseButton: true }
                }

                Text {
                    width: 320
                    text: qsTr("defaultSelectedKeys / defaultOpenKeys / defaultIsCollapsed "
                        + "三条初值：进来就收起、'job' 展开、'信息录入' 选中（选中子项时"
                        + "零级父 key 也会并进 selectedKeys，官方 init 不去重）。")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ================================================================ 受控属性
        GallerySection {
            title: "受控属性"

            Row {
                spacing: 24

                Navigation {
                    bodyStyle: ({ height: 300 })      // 官方 bodyStyle={{ height: 300 }}

                    isCollapsed: page.ctrlCollapsed
                    openKeys: page.ctrlOpen
                    selectedKeys: page.ctrlSelected

                    items: [
                        { itemKey: "user", text: "用户管理", icon: "user" },
                        { itemKey: "union", text: "活动管理", icon: "bell" },
                        { itemKey: "union-management", text: "任务管理", icon: "edit",
                          items: ["公告设置", "任务查询", "信息录入"] },
                        { text: "任务平台", icon: "folder", itemKey: "job",
                          items: ["任务管理", "用户任务查询"] }
                    ]

                    header: NavigationHeader {
                        logo: semiLogoComp
                        text: "Semi 运营后台"
                    }

                    footer: NavigationFooter { collapseButton: true }

                    onSelect: function (data) {
                        page.ctrlSelected = data.selectedKeys;
                    }

                    onOpenChange: function (data) {
                        page.ctrlOpen = data.openKeys;
                    }

                    onCollapseChange: function (collapsed) {
                        page.ctrlCollapsed = collapsed;
                    }
                }

                Column {
                    spacing: 12

                    Text {
                        text: qsTr("isCollapsed / selectedKeys / openKeys 三条受控："
                            + "点了只发回调，状态自己维护。")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                        wrapMode: Text.WordWrap
                        width: 320
                    }

                    Space {
                        space: 8

                        Button {
                            text: page.ctrlCollapsed ? "展开" : "收起"
                            variant: Enums.Light
                            onClicked: page.ctrlCollapsed = !page.ctrlCollapsed
                        }

                        Button {
                            text: "选中任务查询"
                            variant: Enums.Light
                            onClicked: page.ctrlSelected = ["任务查询"]
                        }
                    }

                    Text {
                        text: qsTr("受控 openKeys 只在竖直 + 未折叠档接管浮层"
                            + "（官方 index.tsx:404 的双闸）；收起后 sub 点击退回内部态。")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                        wrapMode: Text.WordWrap
                        width: 320
                    }
                }
            }
        }
    }

    /// 官方 demo 里的 <IconSemiLogo />：端口给一个 36×36 的 Component。
    /// 注意不能写成 `component SemiLogoComp: Icon {}` 再 `logo: semiLogoComp` ——
    /// 内联 component 经 var 属性转手后 Loader 认不出来（实测 sourceComponent 恒 null），
    /// 老页注记的「main: Component { … }」同源：交给 ReactNode 槽的一律用 Component{}
    Component {
        id: semiLogoComp

        Icon {
            name: "semi_logo"
            size: 36
        }
    }

    // 受控属性那节的状态（官方是 useState 三条）
    property bool ctrlCollapsed: true
    property var ctrlOpen: ["union-management", "job"]
    property var ctrlSelected: ["公告设置"]
}
