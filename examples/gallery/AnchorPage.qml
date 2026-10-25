pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Anchor 锚点导航。小节顺序与标题逐条对齐 content/navigation/anchor/index.md 的那 7 条 demo
// （加「如何引入」共 8 节，页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/Anchor.qml / src/AnchorLink.qml 文件头）：
//   · 官方 `href` 是 CSS 选择器，靠 `document.querySelector(href)` 找内容节点；端口没有全局
//     选择器 ⇒ `href` 只当标识串，内容节点走 `targetItem`。所以每一节都得自带一只滚动容器，
//     不能像官网那样指到页面自己的章节上；
//   · 官方 `getContainer` 是函数且缺省 window；端口收 `container`（一只 Flickable）；
//   · 官方「综合使用」那节靠 `style` 做 `position: fixed`；端口 `style` 不产出差异 ⇒
//     那一节改成「摆在容器右侧」，并把它那条嵌套结构（API参考 → Anchor / Anchor.Link）摆出来；
//   · 官方 `maxWidth` / `maxHeight` 是 CSS 长度；端口解析成像素。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    /// 一节 demo：左边一只滚动容器（N 段正文），右边贴着它的 Anchor。
    /// 官方 demo 里两边靠 `href="#某节"` 对上，端口靠 `sectionItems[i]`
    component Pane: Item {
        id: pane

        property int sections: 5
        property real paneWidth: 700
        property real paneHeight: 250
        property alias anchor: anchor
        property alias view: view
        default property alias links: anchor.content
        /// 委托是延后塞进来的，`children` 不是可通知依赖 ⇒ 用一条真属性把它们端出去
        property var sectionItems: []
        /// 一进来就滚到位（官方 demo 靠页面自己滚过几屏，端口得等委托齐了再滚）
        property real initialScroll: -1

        function collect() {
            const out = [];
            const kids = contentColumn.children;
            for (let i = 0; i < kids.length; ++i)
                out.push(kids[i]);
            pane.sectionItems = out;
            if (pane.initialScroll >= 0)
                Qt.callLater(pane.applyInitialScroll);
        }

        function applyInitialScroll() {
            if (pane.initialScroll < 0)
                return;
            view.contentY = pane.initialScroll;
            pane.initialScroll = -1;
        }

        width: paneWidth
        height: paneHeight

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Theme.current.colorBg2
            border.width: 1
            border.color: Theme.current.colorBorder
        }

        Flickable {
            id: view

            objectName: "paneView"
            x: 1
            y: 1
            width: 420
            height: pane.paneHeight - 2
            contentHeight: contentColumn.height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: contentColumn

                width: view.width
                spacing: 0
                onChildrenChanged: pane.collect()

                Repeater {
                    model: pane.sections

                    delegate: Column {
                        id: sec

                        required property int index

                        width: contentColumn.width
                        spacing: 6
                        topPadding: 14
                        bottomPadding: 26

                        Text {
                            width: parent.width - 32
                            x: 16
                            text: "第 " + (sec.index + 1) + " 节"
                            color: Theme.current.colorText0
                            font.pixelSize: Theme.current.fontSizeHeader6
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: 3

                            delegate: Text {
                                required property int index

                                width: sec.width - 32
                                x: 16
                                text: "锚点正文第 " + (index + 1) + " 行 —— 滚到这里时右侧那一条会高亮。"
                                color: Theme.current.colorText2
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }
                    }
                }
            }
        }

        Anchor {
            id: anchor

            objectName: "paneAnchor"
            x: 450
            y: 12
            container: view
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
                    text: "import { Anchor } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }
            }
        }

        // ================================================================ 基本示例
        GallerySection {
            title: "基本示例"

            Pane {
                id: basicPane

                sections: 5

                AnchorLink { href: "#s0"; title: "第 1 节"; targetItem: basicPane.sectionItems[0] }
                AnchorLink { href: "#s1"; title: "第 2 节"; targetItem: basicPane.sectionItems[1] }
                AnchorLink { href: "#s2"; title: "第 3 节"; targetItem: basicPane.sectionItems[2] }
                AnchorLink { href: "#s3"; title: "第 4 节"; targetItem: basicPane.sectionItems[3] }
                AnchorLink { href: "#s4"; title: "第 5 节"; targetItem: basicPane.sectionItems[4] }

                initialScroll: 190
            }
        }

        // ================================================================ 综合使用
        GallerySection {
            title: "综合使用"

            Pane {
                id: mixedPane

                sections: 6

                anchor.offsetTop: 100
                anchor.targetOffset: 60

                AnchorLink { href: "#m0"; title: "我是固定的 Anchor"; targetItem: mixedPane.sectionItems[0] }
                AnchorLink { href: "#m1"; title: "尺寸"; targetItem: mixedPane.sectionItems[1] }
                AnchorLink { href: "#m2"; title: "滑轨主题"; targetItem: mixedPane.sectionItems[2] }
                AnchorLink { href: "#m3"; title: "动态展示"; targetItem: mixedPane.sectionItems[3] }
                AnchorLink { href: "#m4"; title: "API 参考"; targetItem: mixedPane.sectionItems[4]

                    AnchorLink { href: "#m4a"; title: "Anchor"; targetItem: mixedPane.sectionItems[4] }
                    AnchorLink { href: "#m4b"; title: "Anchor.Link"; targetItem: mixedPane.sectionItems[5] }
                }

                initialScroll: 300
            }
        }

        // ================================================================ 尺寸
        GallerySection {
            title: "尺寸"

            Column {
                spacing: 20

                Pane {
                    id: sizeDefaultPane

                    sections: 4

                    AnchorLink { href: "#d0"; title: "组件"; targetItem: sizeDefaultPane.sectionItems[0] }
                    AnchorLink { href: "#d1"; title: "设计语言"; targetItem: sizeDefaultPane.sectionItems[1] }
                    AnchorLink { href: "#d2"; title: "物料平台"; targetItem: sizeDefaultPane.sectionItems[2] }
                    AnchorLink { href: "#d3"; title: "主题商店"; targetItem: sizeDefaultPane.sectionItems[3] }

                    initialScroll: 150
                }

                Pane {
                    id: sizeSmallPane

                    sections: 4

                    anchor.size: "small"

                    AnchorLink { href: "#t0"; title: "组件"; targetItem: sizeSmallPane.sectionItems[0] }
                    AnchorLink { href: "#t1"; title: "设计语言"; targetItem: sizeSmallPane.sectionItems[1] }
                    AnchorLink { href: "#t2"; title: "物料平台"; targetItem: sizeSmallPane.sectionItems[2] }
                    AnchorLink { href: "#t3"; title: "主题商店"; targetItem: sizeSmallPane.sectionItems[3] }

                    initialScroll: 150
                }
            }
        }

        // ================================================================ 滑轨主题
        GallerySection {
            title: "滑轨主题"

            Column {
                spacing: 20

                Pane {
                    id: railPrimary

                    sections: 4

                    AnchorLink { href: "#p0"; title: "尺寸"; targetItem: railPrimary.sectionItems[0] }
                    AnchorLink { href: "#p1"; title: "滑轨主题"; targetItem: railPrimary.sectionItems[1] }
                    AnchorLink { href: "#p2"; title: "设计语言"; targetItem: railPrimary.sectionItems[2] }
                    AnchorLink { href: "#p3"; title: "主题商店"; targetItem: railPrimary.sectionItems[3] }

                    initialScroll: 190
                }

                Pane {
                    id: railTertiary

                    sections: 4

                    anchor.railTheme: "tertiary"

                    AnchorLink { href: "#q0"; title: "尺寸"; targetItem: railTertiary.sectionItems[0] }
                    AnchorLink { href: "#q1"; title: "滑轨主题"; targetItem: railTertiary.sectionItems[1] }
                    AnchorLink { href: "#q2"; title: "设计语言"; targetItem: railTertiary.sectionItems[2] }
                    AnchorLink { href: "#q3"; title: "主题商店"; targetItem: railTertiary.sectionItems[3] }

                    initialScroll: 190
                }

                Pane {
                    id: railMuted

                    sections: 4

                    anchor.railTheme: "muted"

                    AnchorLink { href: "#u0"; title: "尺寸"; targetItem: railMuted.sectionItems[0] }
                    AnchorLink { href: "#u1"; title: "滑轨主题"; targetItem: railMuted.sectionItems[1] }
                    AnchorLink { href: "#u2"; title: "设计语言"; targetItem: railMuted.sectionItems[2] }
                    AnchorLink { href: "#u3"; title: "主题商店"; targetItem: railMuted.sectionItems[3] }

                    initialScroll: 190
                }
            }
        }

        // ================================================================ 动态展示
        GallerySection {
            title: "动态展示"

            Column {
                spacing: 20

                Text {
                    text: qsTr("autoCollapse: true —— 只有当前这条（或它的祖先）才展开下一级：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Pane {
                    id: collapseOnPane

                    sections: 4

                    anchor.autoCollapse: true

                    AnchorLink { href: "#c1"; title: "1. 动态展示"; targetItem: collapseOnPane.sectionItems[0]

                        AnchorLink { href: "#c11"; title: "1.1 组件"; targetItem: collapseOnPane.sectionItems[1]

                            AnchorLink { href: "#c111"; title: "1.1.1 Avatar" }
                            AnchorLink { href: "#c112"; title: "1.1.2 Button" }
                        }
                        AnchorLink { href: "#c12"; title: "1.2 物料" }
                    }
                    AnchorLink { href: "#c2"; title: "2. 设计语言"; targetItem: collapseOnPane.sectionItems[3] }

                    initialScroll: 300
                }

                Text {
                    text: qsTr("autoCollapse: false（缺省）—— 下一级一直摆着：")
                    color: Theme.current.colorText1
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Pane {
                    id: collapseOffPane

                    sections: 4

                    AnchorLink { href: "#e1"; title: "1. 动态展示"; targetItem: collapseOffPane.sectionItems[0]

                        AnchorLink { href: "#e11"; title: "1.1 组件"; targetItem: collapseOffPane.sectionItems[1]

                            AnchorLink { href: "#e111"; title: "1.1.1 Avatar" }
                            AnchorLink { href: "#e112"; title: "1.1.2 Button" }
                        }
                        AnchorLink { href: "#e12"; title: "1.2 物料" }
                    }
                    AnchorLink { href: "#e2"; title: "2. 设计语言"; targetItem: collapseOffPane.sectionItems[3] }

                    initialScroll: 300
                }
            }
        }

        // ================================================================ 显示工具提示
        GallerySection {
            title: "显示工具提示"

            Pane {
                id: tipPane

                sections: 4

                anchor.showTooltip: true

                AnchorLink {
                    href: "#tip1"
                    title: "工具提示是一个有用的工具，它可以在文字缩略时展示全部内容。"
                    targetItem: tipPane.sectionItems[0]
                }
                AnchorLink { href: "#tip2"; title: "组件"; targetItem: tipPane.sectionItems[1] }
                AnchorLink { href: "#tip3"; title: "设计语言"; targetItem: tipPane.sectionItems[2] }

                initialScroll: 150
            }
        }

        // ================================================================ 工具提示位置
        GallerySection {
            title: "工具提示位置"

            Pane {
                id: tipPosPane

                sections: 4

                anchor.showTooltip: true
                anchor.position: "right"

                AnchorLink {
                    href: "#pos1"
                    title: "工具提示是一个有用的工具，它可以在文字缩略时展示全部内容。"
                    targetItem: tipPosPane.sectionItems[0]
                }
                AnchorLink { href: "#pos2"; title: "组件"; targetItem: tipPosPane.sectionItems[1] }
                AnchorLink { href: "#pos3"; title: "设计语言"; targetItem: tipPosPane.sectionItems[2] }

                initialScroll: 150
            }
        }
    }
}
