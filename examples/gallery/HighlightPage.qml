pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Highlight 关键词高亮。官方 `content/show/highlight/index.md` 的「代码演示」一共 5 个小节，
// 这里逐节摆齐：如何引入 / 基本用法 / 指定高亮样式 / 不同文本使用差异化样式 / 指定高亮标签
// （`###` 一共 6 个，多出的是 Highlight 那张 API 表，不进 demo）。
// 最后多一节「大小写敏感与正则」是端口补充：官方有这两条 prop 却没有对应 demo 小节。
//
// 端口与官方的两处口径差（各自写在节内说明里）：
//   · `highlightStyle` 只有 color / backgroundColor / fontWeight / fontStyle / textDecoration /
//     fontSize / fontFamily 能落到 Qt 的行内富文本上；官方 demo 里的 borderRadius / padding /
//     margin 这类几何收了不生效。
//   · `component`（换高亮标签）与 `highlightClassName` / 对象档的 `className` 都不产出可见差异
//     —— 前者是因为官方那条 `.semi-highlight-tag` 类恒加，后者是没有 CSS。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property string source:
        qsTr("从 Semi Design 到 Any Design  快速定义你的设计系统，并应用在设计稿和代码中")

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
                    text: "import { Highlight } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("官方从 v2.24.0 起支持；本库的 API 表没有给各属性标支持版本，这里也不猜。"
                        + "`searchWords` 三种写法都收：一个字符串、字符串数组、"
                        + "`{ text, className, style }` 对象数组（对象档官方 v2.71 起）。"
                        + "`style` / `className` 官方 propTypes 里声明了却从不使用（render 直接返回"
                        + "一个数组，连外层元素都没有），端口也不提供。")
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 700
                spacing: 12

                Highlight {
                    id: basic

                    width: parent.width
                    font.pixelSize: Theme.current.fontSizeHeader3
                    color: Theme.current.colorText0
                    wrapMode: Text.Wrap
                    sourceString: page.source
                    searchWords: ["设计系统", "Semi Design"]
                }

                Note {
                    text: qsTr("官方的 render 直接返回一个数组（没有外层元素），字号与颜色来自那个 `<h2>`；"
                        + "端口必须有一个元素才能画字，所以 `Highlight` 本身就是个 Text，"
                        + "字号、颜色、换行都在它身上设。官方那条注意事项照搬：组件会把文本拆成多个"
                        + "行内元素，任何分割文本流的布局（如 flex）都可能把高亮断开，按需包一层。")
                }
            }
        }

        GallerySection {
            title: "指定高亮样式"

            Column {
                width: 700
                spacing: 12

                Highlight {
                    id: tealStyle

                    width: parent.width
                    font.pixelSize: Theme.current.fontSizeHeader4
                    color: Theme.current.colorText0
                    wrapMode: Text.Wrap
                    sourceString: page.source
                    searchWords: ["设计系统", "Semi Design"]
                    highlightStyle: ({
                        backgroundColor: String(Theme.current.teal[5]),
                        color: String(Theme.current.colorWhite)
                    })
                }

                Highlight {
                    id: primaryStyle

                    width: parent.width
                    font.pixelSize: Theme.current.fontSizeHeader4
                    color: Theme.current.colorText0
                    wrapMode: Text.Wrap
                    sourceString: page.source
                    searchWords: ["设计系统", "Semi Design"]
                    highlightStyle: ({
                        backgroundColor: String(Theme.current.colorPrimary),
                        color: String(Theme.current.colorWhite)
                    })
                }

                Note {
                    text: qsTr("默认那一份是黄底黑字（`--semi-color-highlight-bg` = yellow-4）加字重 600，"
                        + "暗色下是 yellow-2 + 白字。要换就用 `highlightStyle`，它是内联档 ⇒ 盖过类上的默认。"
                        + "官方这两段还写了 borderRadius / 左右 margin / 左右 padding，"
                        + "Qt 的行内 span 不吃盒模型 ⇒ 端口收了不产出声明，观感差这几像素的圆角与留白。")
                }
            }
        }

        GallerySection {
            title: "不同文本使用差异化样式"

            Column {
                width: 700
                spacing: 12

                Highlight {
                    id: perWord

                    width: parent.width
                    font.pixelSize: Theme.current.fontSizeHeader4
                    color: Theme.current.colorText0
                    wrapMode: Text.Wrap
                    component: "span"
                    sourceString: page.source
                    searchWords: [
                        { text: "Semi", className: "keyword1",
                            style: ({ backgroundColor: String(Theme.current.teal[5]),
                                color: String(Theme.current.colorWhite) }) },
                        { text: "设计系统", className: "keyword2",
                            style: ({ backgroundColor: String(Theme.current.colorPrimary),
                                color: String(Theme.current.colorWhite) }) },
                        { text: "设计稿和代码", className: "keyword3",
                            style: ({ backgroundColor: String(Theme.current.violet[5]),
                                color: String(Theme.current.colorWhite) }) }
                    ]
                    highlightStyle: ({ borderRadius: 4 })
                }

                Note {
                    text: qsTr("对象档：每个词自己带 `style`（`className` 没有 CSS 可落，端口丢掉）。"
                        + "合并区间时样式是 `{...prev, ...next}` —— 后一个词的**同名键**盖掉前一个，"
                        + "`className` 反过来是 `prev || next`。两个词的起点相同时，稳定排序保持数组顺序，"
                        + "所以数组里靠后那个词的样式赢。")
                }
            }
        }

        GallerySection {
            title: "指定高亮标签"

            Column {
                width: 700
                spacing: 12

                Highlight {
                    id: strongTag

                    width: parent.width
                    font.pixelSize: Theme.current.fontSizeHeader4
                    color: Theme.current.colorText0
                    wrapMode: Text.Wrap
                    component: "strong"
                    sourceString: page.source
                    searchWords: ["设计系统", "Semi Design"]
                }

                Note {
                    text: qsTr("官方默认用 `<mark>` 包裹，`component` 可以换成别的标签。"
                        + "端口没有「标签」这一档（富文本里只有 span），而且这条在官方那边也"
                        + "**不改变观感** —— `.semi-highlight-tag` 那条类是恒加在高亮标签上的，"
                        + "换 `span` / `strong` 都一样被它盖过 UA 样式，差的只是 DOM 语义。"
                        + "端口照收不生效，并钉了用例。")
                }
            }
        }

        GallerySection {
            title: "大小写敏感与正则"

            Column {
                width: 700
                spacing: 12

                Highlight {
                    id: defaultsOn

                    width: parent.width
                    font.pixelSize: Theme.current.fontSizeHeader4
                    color: Theme.current.colorText0
                    wrapMode: Text.Wrap
                    sourceString: "Xiaomi 与 xiaomi，还有 a.b 与 axb"
                    searchWords: ["xiaomi", "a.b"]
                }

                Highlight {
                    id: bothOff

                    width: parent.width
                    font.pixelSize: Theme.current.fontSizeHeader4
                    color: Theme.current.colorText0
                    wrapMode: Text.Wrap
                    sourceString: "Xiaomi 与 xiaomi，还有 a.b 与 axb"
                    searchWords: ["xiaomi", "a.b"]
                    caseSensitive: true
                    autoEscape: false
                }

                Note {
                    text: qsTr("官方这两条 prop 都没有对应的 demo 小节，这一节是端口补的。"
                        + "缺省 `caseSensitive: false`（正则带 i）、`autoEscape: true`（词里的正则元字符按"
                        + "字面量转义）。第一行是缺省档：'xiaomi' 大小写两处都亮，'a.b' 是字面量 ⇒ 只亮"
                        + "带点的那个。第二行两个开关都改：'xiaomi' 只亮小写那处，而 'a.b' 当正则用 ⇒ "
                        + "'axb' 也亮。零宽匹配（例如关掉转义再写 'a*'）由 `end > start` 与"
                        + "`lastIndex` 往前推一格这两条挡住，后者摘掉整个循环出不来。")
                }
            }
        }
    }

    // 说明里会出现 `<h2>` / `<mark>` 这类尖括号，AutoText 会把它们当标签吃掉 ⇒ 必须钉 PlainText
    component Note: Text {
        width: 700
        textFormat: Text.PlainText
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
