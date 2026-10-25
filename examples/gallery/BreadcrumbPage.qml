pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Breadcrumb 面包屑。小节顺序与标题逐条对齐 content/navigation/breadcrumb/index.md 的那
// 7 条 demo（加「如何引入」共 8 节，页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/Breadcrumb.qml / src/BreadcrumbItem.qml 文件头）：
//   · 官方 `Breadcrumb.Item` 挂在静态成员上，QML 没有静态成员 ⇒ 拆成独立类型
//     `BreadcrumbItem`，写法 `Breadcrumb { BreadcrumbItem { label: "…" } }`；
//   · 官方 demo 的图标传 `<IconHome size="small" />` 节点。端口 `icon` 收图标名或 Component，
//     尺寸由宿主按 compact 档塞进去（跟官方 cloneElement 那条一致），所以写名字就够，
//     「图标跟着 size 变」这一条不用使用方操心；
//   · 官方「自定义的分隔符」那节给 `<Breadcrumb size="small">` 传了 `size`，而
//     BreadcrumbProps 里根本没这条（`size` 是 Typography/Tag 那套的），组件也从不读 ⇒
//     端口不跟着造，这一节也就不摆那一条；
//   · 官方 `onClick(item, event)` 第二参数是 React 事件对象，端口只给那份 item 信息；
//   · 官方 `renderItem` / `renderMore` 返回 ReactNode，端口的这两档是 Component（节点），
//     `renderMore` 那份还由宿主往 Component 根项上注 `restItems`。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方「截断逻辑」那五条 demo 共用同一份 routes（是同一段文字，不是同一批节点）
    readonly property var longRoutes: ["首页", "当这个页面标题很长很长很长时需要省略", "详情页"]
    readonly property var manyLevels: ["首页", "当层级很多的时候", "又一层", "再一层",
        "上上一层", "上一层", "详情页"]

    // 官方「自定义的分隔符」里那条 <IconArrowRight size="small" /> —— 端口的 Component 档
    readonly property Component arrowSeparator: Component {
        Icon {
            name: "arrow_right"
            size: Theme.current.widthIconSmall
            color: Theme.current.colorText2
        }
    }

    // renderItem 那档：按 route 现造一个节点（官方是 ReactNode，这里是 Component）
    readonly property Component upperLabel: Component {
        Text {
            text: "· 节点档标题 ·"
            color: Theme.current.colorPrimary
            font.pixelSize: 12
        }
    }

    // 官方 renderMore 那节：restItem 拼成一段、外面套一只 Popover。
    // 端口递进来的是被折掉那几节的信息数组（{ label, icon, route, href, noLink, info }），
    // 且 restItems / host 是注在 Component 根项上的 ⇒ 根项得先把这两个属性声明出来
    readonly property Component moreWithPopover: Component {
        Item {
            id: moreRoot

            property var restItems: []
            property var host: null

            width: trigger.width
            height: trigger.height

            Text {
                id: trigger

                anchors.verticalCenter: parent.verticalCenter
                text: "···"
                color: Theme.current.colorText2
                font.pixelSize: 12
            }

            Popover {
                objectName: "pageMorePopover"

                target: trigger
                showArrow: true

                Row {
                    spacing: 0

                    Repeater {
                        model: moreRoot.restItems

                        delegate: Row {
                            id: restRow

                            required property var modelData
                            required property int index

                            spacing: 0

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(restRow.modelData.label)
                                color: Theme.current.colorText0
                                font.pixelSize: 12
                            }

                            // 官方那档分隔符是 `-`，色 text-2、右外边距 6
                            Text {
                                objectName: "pageMoreDash"

                                anchors.verticalCenter: parent.verticalCenter
                                visible: restRow.index < moreRoot.restItems.length - 1
                                text: "-"
                                color: Theme.current.colorText2
                                rightPadding: 6
                            }
                        }
                    }
                }
            }
        }
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
                    text: "import { Breadcrumb } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }
        }

        // ================================================================ 基本用法
        GallerySection {
            title: "基本用法"

            Breadcrumb {
                BreadcrumbItem { label: "Semi-ui" }
                BreadcrumbItem { label: "Breadcrumb" }
                BreadcrumbItem { label: "Default" }
            }
        }

        // ================================================================ 带图标的
        GallerySection {
            title: "带图标的"

            Breadcrumb {
                BreadcrumbItem { icon: "home" }
                BreadcrumbItem { icon: "article"; label: "Breadcrumb" }
                BreadcrumbItem { label: "With Icon" }
            }
        }

        // ================================================================ 尺寸
        GallerySection {
            title: "尺寸"

            Column {
                spacing: 16

                Breadcrumb {
                    compact: true

                    BreadcrumbItem { icon: "home" }
                    BreadcrumbItem { label: "Breadcrumb" }
                    BreadcrumbItem { label: "Compact" }
                }

                Breadcrumb {
                    compact: false

                    BreadcrumbItem { icon: "home" }
                    BreadcrumbItem { label: "Breadcrumb" }
                    BreadcrumbItem { label: "Loose" }
                }
            }
        }

        // ================================================================ 自定义的分隔符
        GallerySection {
            title: "自定义的分隔符"

            Column {
                spacing: 16

                Breadcrumb {
                    separator: ">"

                    BreadcrumbItem { label: "Semi-ui" }
                    BreadcrumbItem { label: "Breadcrumb" }
                    BreadcrumbItem { label: "Default" }
                }

                Breadcrumb {
                    separator: page.arrowSeparator

                    BreadcrumbItem { label: "Semi-ui" }
                    BreadcrumbItem { label: "Breadcrumb" }
                    BreadcrumbItem { label: "Default" }
                }

                Text {
                    text: qsTr("v>=1.16.0：条目自己也能给 separator。官方那一档不套 -separator 层，"
                        + "所以拿不到 text-2，跟着页面文字色走：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    width: 700
                    wrapMode: Text.WordWrap
                }

                Breadcrumb {
                    BreadcrumbItem { label: "Semi-ui"; separator: ":" }
                    BreadcrumbItem { label: "Breadcrumb" }
                    BreadcrumbItem { label: "Default" }
                }
            }
        }

        // ================================================================ 截断逻辑
        GallerySection {
            title: "截断逻辑"

            Column {
                spacing: 16

                Text {
                    text: qsTr("默认行为（150px 截断 + 悬浮 Tooltip）")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Breadcrumb {
                    width: 700
                    routes: page.longRoutes
                }

                Text {
                    text: qsTr("省略但不显示 Tooltip（showTooltip: false 只关掉 opts，"
                        + "150px 那道截断照旧）")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Breadcrumb {
                    width: 700
                    showTooltip: false
                    routes: page.longRoutes
                }

                Text {
                    text: qsTr("不截断（要 { width: 'auto' }，不是 showTooltip: false）")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Breadcrumb {
                    width: 700
                    showTooltip: ({ width: "auto" })
                    routes: page.longRoutes
                }

                Text {
                    text: qsTr("从标题中间开始省略")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Breadcrumb {
                    width: 700
                    showTooltip: ({ ellipsisPos: "middle" })
                    routes: page.longRoutes
                }

                Text {
                    text: qsTr("自定义 Tooltip 参数（官方是 lodash merge：只给 position，"
                        + "autoAdjustOverflow 仍吃缺省 true）")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Breadcrumb {
                    width: 700
                    showTooltip: ({ opts: ({ position: "topLeft" }) })
                    routes: page.longRoutes
                }

                // 官方这份 demo 是 children 档的七级，跟上面那份 routes 不是同一批数据
                Text {
                    text: qsTr("层级超过 maxItemCount（缺省 4）就折叠：第二层到倒数第三层收进省略号，"
                        + "点它展开 —— 官方只有 setState，没有再收回去的口子")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    width: 700
                    wrapMode: Text.WordWrap
                }

                Breadcrumb {
                    width: 560

                    BreadcrumbItem { label: "首页" }
                    BreadcrumbItem { label: "当层级很多的时候" }
                    BreadcrumbItem { label: "又一层" }
                    BreadcrumbItem { label: "再一层" }
                    BreadcrumbItem { label: "上上一层" }
                    BreadcrumbItem { label: "上一层" }
                    BreadcrumbItem { label: "详情页" }
                }

                Text {
                    text: qsTr("v>=1.9.0：maxItemCount 控制超过多少级折叠")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Breadcrumb {
                    width: 560
                    maxItemCount: 3
                    routes: page.manyLevels
                }

                Text {
                    text: qsTr("autoCollapse: false 把折叠闸门关掉；可用宽再窄到放不下就换行"
                        + "（官方那条 flex-wrap 吃的是所在栏的宽）：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    width: 700
                    wrapMode: Text.WordWrap
                }

                Breadcrumb {
                    width: 560
                    autoCollapse: false
                    routes: page.manyLevels
                }

                Breadcrumb {
                    width: 300
                    autoCollapse: false
                    routes: page.manyLevels
                }
            }
        }

        // ================================================================ 自定义省略号区域
        GallerySection {
            title: "自定义省略号区域"

            Column {
                spacing: 16

                Text {
                    text: qsTr("moreType: 'popover' —— 省略号那格外面套一只 Popover，浮层里是"
                        + "被折掉的这几节，中间夹 -restItem（text-2 + 右 8）；"
                        + "官方没给 trigger ⇒ 吃 BaseTooltip 的缺省 hover：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    width: 700
                    wrapMode: Text.WordWrap
                }

                Breadcrumb {
                    width: 560
                    moreType: "popover"
                    routes: page.manyLevels
                }

                Text {
                    text: qsTr("renderMore 自己画省略号区域（官方那节也是往里塞一只 Popover）。"
                        + "端口递进来的是被折掉那几节的信息数组，注在 Component 根项的 restItems 上：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    width: 700
                    wrapMode: Text.WordWrap
                }

                Breadcrumb {
                    width: 560
                    renderMore: page.moreWithPopover
                    routes: page.manyLevels

                    onClicked: function (item) {
                        console.log("Breadcrumb clicked:", JSON.stringify(item));
                    }
                }
            }
        }

        // ================================================================ 路由对象
        GallerySection {
            title: "路由对象"

            Column {
                spacing: 16

                Breadcrumb {
                    width: 700
                    routes: ["Semi-ui", "Breadcrumb", "Default"]
                }

                Breadcrumb {
                    width: 700

                    routes: [
                        { path: "/", href: "/", icon: "home" },
                        { path: "/breadcrumb", href: "/zh-CN/navigation/breadcrumb",
                            name: "breadcrumb", icon: "article" },
                        "with icon"
                    ]
                }

                Breadcrumb {
                    width: 700
                    routes: ["首页", "当这个页面标题很长时需要省略", "详情页"]
                }

                Text {
                    text: qsTr("renderItem 按 route 现造节点（官方给 ReactNode，端口给 Component；"
                        + "给的是节点就走 -item-title-inline 那一档，不截断）：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                    width: 700
                    wrapMode: Text.WordWrap
                }

                Breadcrumb {
                    width: 700
                    routes: [{ name: "首页" }, { name: "列表页" }, { name: "详情页" }]
                    renderItem: function (route) {
                        return page.upperLabel;
                    }
                }
            }
        }
    }
}
