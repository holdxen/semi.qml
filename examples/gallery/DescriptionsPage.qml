pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Descriptions 描述列表。官方 `content/show/descriptions/index.md` 的「代码演示」一共 7 个小节，
// 这里逐节摆齐：如何引入 / 基本用法 / 设置对齐方式 / JSX 写法 / 设置布局模式 / 双行显示 /
// 自定义 Key 样式。
//
// 端口与官方的几处口径差（各自写在节内说明里，完整清单在 src/Descriptions.qml 文件头）：
//   · 官方 `data` 在 QML 里被 `Item.data`（子项链表）占着 ⇒ 这一档叫 `dataList`，形状一样。
//   · 官方 `value` 的 ReactNode 档这里是「字符串或 Component」，内联节点接不住，
//     要先 `Component { … }` 声明成页面属性再引用（`Component {}` 也不能写在对象字面量里）。
//   · 官方 `column` / `span` 只在 `layout: 'horizontal'` 那一路生效 —— 缺省的 vertical 是
//     一个条目一行，官网「设置布局模式」那节的 vertical demo 配的 `column={4}` 其实没用。
//   · `keyStyle` 的 `width` / `textAlign` 只在 `align: 'plain'` 那一档落地（官方其余三档
//     `-key` 是 inline span，CSS 忽略这两条），`color` 到处有效 —— 与文档那句「支持所有 CSS 样式」
//     不符，端口照官方实现、不照文档。
//   · `style` / `className` 收了不产出可见差异（官方那两条只喂给 DOM）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方 demo 里「值是一堆节点」的那两档，端口要先声明成 Component 再进数组
    readonly property Component riseValue: Component {
        Row {
            spacing: 2

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "98%"
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "arrow_up"
                size: Theme.current.widthIconSmall
                color: Theme.current.colorSuccess
            }
        }
    }
    readonly property Component tagValue: Component {
        Tag {
            text: "电商"
        }
    }
    readonly property Component tagPair: Component {
        Row {
            spacing: 6

            Tag {
                text: "互联网资讯"
                size: "small"
                shape: "circle"
                color: "amber"
            }

            Tag {
                text: "编程"
                size: "small"
                shape: "circle"
                color: "violet"
            }
        }
    }

    readonly property var basicData: [
        { key: "实际用户数量", value: "1,480,000" },
        { key: "7天留存", value: page.riseValue },
        { key: "安全等级", value: "3级" },
        { key: "垂类标签", value: page.tagValue },
        { key: "认证状态", value: "未认证" }
    ]
    readonly property var alignData: [
        { key: "实际用户数量", value: "1,480,000" },
        { key: "7天留存", value: "98%" },
        { key: "安全等级", value: "3级" },
        { key: "垂类标签", value: page.tagValue },
        { key: "认证状态", value: "未认证" }
    ]
    readonly property var layoutData: [
        { key: "抖音号", value: "SemiDesign" },
        { key: "主播类型", value: "自由主播" },
        { key: "安全等级", value: "3级" },
        { key: "垂类标签", value: page.tagPair },
        { key: "作品数量", value: "88888888" },
        { key: "认证状态", value: "这是一个很长很长很长很长很长很长很长很长很长的值", span: 3 }
    ]
    readonly property var horizontalData: [
        { key: "抖音号", value: "SemiDesign" },
        { key: "主播类型", value: "自由主播" },
        { key: "安全等级", value: "3级" },
        { key: "垂类标签", value: page.tagValue },
        { key: "作品数量", value: "88888888" },
        { key: "认证状态", value: "这是一个很长很长很长很长很长很长很长很长很长的值", span: 3 },
        { key: "上次直播时间", value: "2024-05-01 12:00:00", span: 3 }
    ]
    readonly property var doubleData: [
        { key: "实际用户数量", value: "1,480,000" },
        { key: "7天留存", value: page.riseValue },
        { key: "安全等级", value: "3级" }
    ]

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Column {
                width: 700
                spacing: 10

                Text {
                    text: "import { Descriptions } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("官方一共八条 prop：`align`（center / justify / left / plain，缺省 center）、"
                        + "`row`（false）、`size`（medium，只在 row 下有意义）、`data`、`layout`"
                        + "（vertical / horizontal，缺省 vertical）、`column`（3）、`style`、`className`。"
                        + "端口把 `data` 改叫 `dataList` —— `Item.data` 是子项链表，同名声明盖不住它。")
                }

                Note {
                    text: qsTr("一条容易读错的：官方缺省的 vertical 档是「一个条目一行」，"
                        + "`column` 与 `span` 「只在 horizontal 那一路被读到」（foundation 的 "
                        + "getHorizontalList）。要多列得显式写 `layout: 'horizontal'`。")
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 700
                spacing: 12

                Descriptions {
                    width: 640
                    dataList: page.basicData
                }

                Note {
                    text: qsTr("key 与 value 都收「字符串或 Component」。官方 demo 里那两档节点值"
                        + "（98% 加一个上升箭头、一个 Tag）端口要先 `Component { … }` 声明出来再进数组 ——"
                        + "内联节点接不住，而且 `Component {}` 写在对象字面量里会直接编译报错。")
                }
            }
        }

        GallerySection {
            title: "设置对齐方式"

            Column {
                width: 700
                spacing: 12

                Flow {
                    width: 700
                    spacing: 10

                    Repeater {
                        model: ["center", "justify", "left", "plain"]

                        delegate: Card {
                            id: alignCard

                            required property var modelData

                            width: 320
                            // 官方这一节四张卡是 `<Card shadows='always'>` 包的（content/show/descriptions/index.md:65-75），
                            // Descriptions 自己没有阴影规则 —— 少了这行就是 gallery 比官方淡一圈。
                            shadows: "always"

                            Descriptions {
                                width: 288
                                align: alignCard.modelData
                                dataList: page.alignData
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("四档里前三档只差 text-align：center ⇒ key 右、value 左；left ⇒ 都左；"
                        + "justify ⇒ key 左、「value 右」。plain 是换 DOM —— 没有 th/td 两格，"
                        + "一个格子里 key 后面带一个冒号、value 左内边距 8。")
                }

                Note {
                    text: qsTr("官方文档那句「当 row 为 true 时，该配置无效」只对了一半："
                        + "那四条对齐规则确实整块不套（类名带 !row），但 `align: 'plain'` 仍然会换 DOM。"
                        + "端口照实现，见下面「双行显示」那节的说明。")
                }
            }
        }

        GallerySection {
            title: "JSX 写法"

            Column {
                width: 700
                spacing: 12

                Descriptions {
                    width: 640
                    DescriptionsItem {
                        itemKey: "实际用户数量"
                        value: "1,480,000"
                    }
                    DescriptionsItem {
                        itemKey: "7天留存"
                        value: "98%"
                    }
                    DescriptionsItem {
                        itemKey: "安全等级"
                        value: "3级"
                    }
                    DescriptionsItem {
                        itemKey: "垂类标签"
                        value: page.tagValue
                    }
                    DescriptionsItem {
                        itemKey: "认证状态"
                        value: "未认证"
                    }
                }

                Note {
                    text: qsTr("官方是 `Descriptions.Item`，端口拆成独立组件 `DescriptionsItem`。"
                        + "两条硬要求照抄：条目「必须是 Descriptions 的直接子项」（官方读 React.Children，"
                        + "包一层就找不到），以及 `dataList` 非空时子项整条不读。"
                        + "值既可以写 `value:`，也可以直接写子项（官方 children 档）。")
                }
            }
        }

        GallerySection {
            title: "设置布局模式"

            Column {
                width: 700
                spacing: 20

                Column {
                    width: 700
                    spacing: 8

                    Text {
                        text: qsTr("vertical（缺省）+ column: 4")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Descriptions {
                        width: 700
                        layout: "vertical"
                        align: "plain"
                        column: 4
                        dataList: page.layoutData
                    }
                }

                Column {
                    width: 700
                    spacing: 8

                    Text {
                        text: qsTr("horizontal + column: 5（末项 span: 3）")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Descriptions {
                        width: 700
                        layout: "horizontal"
                        align: "plain"
                        column: 5
                        dataList: page.horizontalData
                    }
                }

                Note {
                    text: qsTr("上面那块 vertical 配的 `column: 4` 是「官方 demo 自己带的无效配置」 —— "
                        + "vertical 档一个条目一行，压根不读 column。端口照抄行为，不照抄那个配置的样子。")
                }

                Note {
                    text: qsTr("horizontal 那块的分组是 `getHorizontalList`：累加 `span || 1`，"
                        + "「累到 >= column 才断行」，所以一行的总 span 可以超出 column（这里末行是 3+3=6 > 5）。"
                        + "残行的末项只有「没给 span」时才补成 `column - 已占 + 1`。"
                        + "端口把列宽算成「槽数等分」：grid = 各行最大的 Σspan，条目宽 = span/grid × 容器宽。")
                }
            }
        }

        GallerySection {
            title: "双行显示"

            Column {
                width: 700
                spacing: 16

                Repeater {
                    model: ["small", "medium", "large"]

                    delegate: Card {
                        id: sizeCard

                        required property var modelData

                        width: 640
                        // 官方这一节没有 Card，是往 Descriptions 外面套了一个自绘 div：
                        // `boxShadow: 'var(--semi-shadow-elevated)'` + bg-2 + radius 4 + padding 10
                        // （content/show/descriptions/index.md:187-194）。端口用 Card 顶替那层 div，
                        // 所以那条 boxShadow 也得落在 Card 的 shadows 上，否则这一节又是没阴影。
                        shadows: "always"

                        Descriptions {
                            width: 620
                            row: true
                            size: sizeCard.modelData
                            dataList: page.doubleData
                        }
                    }
                }

                Note {
                    text: qsTr("`row: true` 让 key 走到 value 上面（官方是 `tr { display: inline-flex; "
                        + "flex-direction: column }`），三档 size 只差字号与间距：key 12 / 14 / 14、"
                        + "value 16 / 20 / 28 且字重 600、条目右内边距 48 / 60 / 80。"
                        + "注意这一档 `-item` 的 padding 被重赋成 0 ⇒ 普通档那 12 的行距没有了。")
                }

                Note {
                    text: qsTr("条目横着排几条是 flex 换行的结果（端口按「自然宽 + 那条右内边距」往容器里塞，"
                        + "一行放得下几条排几条，本行内等分）。这一档 align 的四条对齐规则不套，"
                        + "但 `align: 'plain'` 仍会换成「key: 与 value 同一行」那个 DOM。")
                }
            }
        }

        GallerySection {
            title: "自定义 Key 样式"

            Column {
                width: 700
                spacing: 20

                Descriptions {
                    width: 640
                    align: "center"
                    dataList: [
                        { key: "用户名", value: "张三", keyStyle: ({ width: 100, textAlign: "right" }) },
                        { key: "电子邮箱", value: "zhangsan@example.com", keyStyle: ({ width: 100, textAlign: "right" }) },
                        { key: "联系电话", value: "138-0000-0000", keyStyle: ({ width: 100, textAlign: "right" }) },
                        { key: "地址", value: "北京市朝阳区", keyStyle: ({ width: 100, textAlign: "right" }) }
                    ]
                }

                Descriptions {
                    width: 640
                    align: "plain"
                    dataList: [
                        { key: "用户名", value: "张三", keyStyle: ({ width: 100, textAlign: "right" }) },
                        { key: "电子邮箱", value: "zhangsan@example.com", keyStyle: ({ width: 100, textAlign: "right" }) },
                        { key: "联系电话", value: "138-0000-0000", keyStyle: ({ width: 100, textAlign: "right" }) },
                        { key: "地址", value: "北京市朝阳区", keyStyle: ({ width: 100, textAlign: "right" }) }
                    ]
                }

                Descriptions {
                    width: 640
                    align: "center"
                    DescriptionsItem {
                        itemKey: "姓名"
                        keyStyle: ({ color: Theme.current.colorPrimary })
                        value: "李四"
                    }
                    DescriptionsItem {
                        itemKey: "年龄"
                        keyStyle: ({ color: Theme.current.colorPrimary })
                        value: "28"
                    }
                    DescriptionsItem {
                        itemKey: "职业"
                        keyStyle: ({ color: Theme.current.colorPrimary })
                        value: "前端工程师"
                    }
                }

                Note {
                    text: qsTr("上面三块分别是「align center + keyStyle width」、「align plain + 同一份 keyStyle」、"
                        + "「子项档 + keyStyle color」。官方文档写「该属性支持所有 CSS 样式，如 width、maxWidth、"
                        + "textAlign、color」，但只有 plain 那一档 `-key` 是 inline-block ⇒ width 与 textAlign 生效；"
                        + "其余三档它是 inline span，CSS 忽略这两条 —— 第一块与第二块的差别就是这条。"
                        + "color 是继承性的键，哪一档都有效（第三块）。端口照实现，不照文档。")
                }
            }
        }
    }

    // 说明里会出现 `{ key: value }`、`span || 1` 这类尖括号与花括号 ⇒ 钉 PlainText
    component Note: Text {
        width: 700
        textFormat: Text.PlainText
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
