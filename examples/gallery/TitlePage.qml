pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Typography 版式。小节顺序与演示内容对齐官方文档页
// content/basic/typography/index.md（标题 / 文本 / 段落 / 数值 / 大小 / 可复制 / 省略）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property string intro: qsTr("Semi Design 是由抖音前端团队与 UED 团队共同设计开发并维护的"
        + "设计系统。设计系统包含设计语言以及一整套可复用的前端组件，帮助设计师与开发者更容易地"
        + "打造高质量的、用户体验一致的、符合设计规范的 Web 应用。")

    // 官方 parser 演示：按空格切 token，是数字的那个加千分位再补一个 +
    function parserTCH(oldVal: string): string {
        return String(oldVal).split(" ").map(function (item) {
            return Number(item)
                ? String(item).replace(/(\d)(?=(?:\d{3})+(?:\.|$))/g, "$1,") + "+"
                : item;
        }).join(" ");
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "标题组件"

            Paragraph {
                width: 600
                text: qsTr("通过设置 heading 可以展示不同级别的标题。")
                tone: Enums.Secondary
            }

            Column {
                spacing: 8

                Title { heading: 1; text: "h1. Semi Design" }
                Title { heading: 2; text: "h2. Semi Design" }
                Title { heading: 3; text: "h3. Semi Design" }
                Title { heading: 4; text: "h4. Semi Design" }
                Title { heading: 5; text: "h5. Semi Design" }
                Title { heading: 6; text: "h6. Semi Design" }
            }
        }

        GallerySection {
            title: "文本组件"

            Paragraph {
                width: 600
                text: qsTr("内置不同样式的文本。可以通过 icon 属性传入图标，这种方式传入的图标默认与文本有间距，"
                    + "同时在链接文本的情况不会出现下划线。")
                tone: Enums.Secondary
            }

            Column {
                spacing: 12

                TextLabel { text: "Text" }
                TextLabel { text: "Secondary"; tone: Enums.Secondary }
                TextLabel { text: "Tertiary"; tone: Enums.Tertiary }
                TextLabel { text: "Quaternary"; tone: Enums.Quaternary }
                TextLabel { text: "Warning"; tone: Enums.Warning }
                TextLabel { text: "Danger"; tone: Enums.Danger }
                TextLabel { text: "Success"; tone: Enums.Success }
                TextLabel { text: "Disabled"; disabled: true }
                TextLabel { text: "Default Mark"; mark: true }
                TextLabel { text: "Example Code"; code: true }
                TextLabel { text: "Underline"; underline: true }
                TextLabel { text: "Deleted"; deleted: true }
                TextLabel { text: "Strong"; strong: true }
            }

            Column {
                spacing: 12

                TextLabel { text: qsTr("链接文本"); link: true }
                TextLabel { text: qsTr("打开网站"); link: true }
                TextLabel { text: qsTr("带下划线的网页链接"); link: true; icon: "link"; underline: true }
            }
        }

        GallerySection {
            title: "段落组件"

            Paragraph {
                width: 600
                text: qsTr("段落组件拥有两种行距，可以通过设置 spacing 为 extended 使用更宽松的行距。")
                tone: Enums.Secondary
            }

            Column {
                spacing: 12

                Title { heading: 5; text: qsTr("默认行距") }
                Paragraph {
                    width: 600
                    text: page.intro
                }

                Title { heading: 5; text: qsTr("宽松行距") }
                Paragraph {
                    width: 600
                    spacing: Enums.SpacingExtended
                    text: page.intro
                }
            }
        }

        GallerySection {
            title: "数值组件"

            Paragraph {
                width: 600
                text: qsTr("Numeral 在 Text 的基础上多了 rule、precision、truncate、parser，"
                    + "用来单独处理文本里的数值。")
                tone: Enums.Secondary
            }

            Column {
                spacing: 12

                // rule 默认是 text：只把文本里的数字按 precision / truncate 处理
                Numeral { source: qsTr("点赞量：1.6111e1 K"); precision: 1 }
                // rule 是 numbers：把文本里的数字全挑出来、逗号连接，
                // 所以官方演示里标签文字是写在 Numeral 外面的
                Row {
                    spacing: 0

                    TextLabel { text: qsTr("播放量:") }
                    Numeral { rule: "numbers"; precision: 1; source: "2.4444e2" }
                    TextLabel { text: "K" }
                }
                Numeral { source: qsTr("好评率: 0.915"); rule: "percentages"; precision: 2 }
                Numeral { source: qsTr("这场比赛我的胜率是0.6，输的概率是0.4"); rule: "percentages" }
                Numeral {
                    width: 400
                    source: qsTr("已使用: 1000\n未使用: 1024000")
                    rule: "bytes-decimal"; precision: 2; truncate: "floor"
                }
                Numeral {
                    width: 400
                    source: qsTr("已使用: 1024\n未使用: 2000000000000")
                    rule: "bytes-binary"; precision: 2; truncate: "floor"
                }
                Numeral { source: qsTr("科学计数 12345"); rule: "exponential"; precision: 2 }

                // 自定义 parser 会整个绕过 rule
                Numeral { source: qsTr("Stars 7100 Fork 560 Downloads 5000000"); parser: page.parserTCH }
                Numeral { source: qsTr("现已服务 100000 用户，前往官网 >>"); parser: page.parserTCH; link: true }
            }
        }

        GallerySection {
            title: "文本大小"

            Paragraph {
                width: 600
                text: qsTr("段落组件和文本组件支持两种尺寸，small（12px）和 normal（14px）以及 inherit。"
                    + "嵌套使用时把内层的 size 设为 inherit，内层就继承外层的尺寸。")
                tone: Enums.Secondary
            }

            Column {
                spacing: 12

                TextLabel { text: qsTr("正常文本") }
                TextLabel { text: qsTr("小文本"); size: Enums.Small }

                // 内层作为外层 Text 的子项挂在文字末尾，size: inherit 顺 parent 链取外层尺寸
                TextLabel {
                    size: Enums.Small
                    text: qsTr("这是一段 small 文本，")

                    TextLabel {
                        size: Enums.Inherit
                        anchors.left: parent.right
                        anchors.baseline: parent.baseline
                        link: true
                        text: qsTr("这是一段链接，size 设为 inherit 继承外层")
                    }
                }
            }
        }

        GallerySection {
            title: "可复制文本"

            Paragraph {
                width: 600
                text: qsTr("可通过配置 copyable 属性支持文本的复制。copyable 为 true 时默认复制文本本身，"
                    + "为对象时可用 content 指定写入剪贴板的内容。")
                tone: Enums.Secondary
            }

            Column {
                spacing: 12

                Paragraph { copyable: true; text: qsTr("点击右边的图标复制文本。") }
                Paragraph {
                    copyable: ({ content: "Hello, Semi Design!" })
                    text: qsTr("点击复制文本。")
                }
                Paragraph {
                    copyable: ({ onCopy: (content) => console.log("copied:", content) })
                    text: qsTr("点了会打一行日志。")
                }
                TextLabel {
                    copyable: true
                    underline: true
                    text: qsTr("1699000000s")
                }
                // 官方这里还有两条自定义演示：换图标（copyable.icon）和整段换成交互节点
                // （copyable.render）。前者本库支持，后者暂未实现。
            }

            Column {
                spacing: 4

                TextLabel { text: qsTr("粘贴区域："); tone: Enums.Tertiary }

                TextArea {
                    id: pasteArea

                    width: 320
                    height: 68
                    placeholderText: qsTr("在这里粘贴")
                }
            }
        }

        GallerySection {
            title: "省略文本"

            Paragraph {
                width: 600
                text: qsTr("支持文本的省略。ellipsis 只截纯文本，且必须给一个宽度。")
                tone: Enums.Secondary
            }

            Column {
                spacing: 12

                Title {
                    heading: 5
                    width: 250
                    ellipsis: ({ showTooltip: true })
                    text: qsTr("是一个很长很长很长很长5号标题")
                }
                TextLabel {
                    width: 150
                    ellipsis: ({ showTooltip: true })
                    text: qsTr("可以自定义浮层里的展示内容试试看吧")
                }
                TextLabel {
                    width: 150
                    link: true
                    ellipsis: ({ showTooltip: true, pos: "middle" })
                    text: qsTr("是一个很长很长很长很长的链接")
                }
                Paragraph {
                    width: 300
                    ellipsis: ({ suffix: qsTr("小尾巴") })
                    text: qsTr("有后缀的情况：") + page.intro
                }
                Paragraph {
                    width: 300
                    ellipsis: ({ rows: 3 })
                    text: qsTr("这是一个多行截断的例子：") + page.intro
                }
                Paragraph {
                    width: 300
                    ellipsis: ({ rows: 3, showTooltip: true })
                    text: qsTr("多行截断，展示 Tooltip：") + page.intro
                }
                Paragraph {
                    width: 300
                    ellipsis: ({ rows: 3, expandable: true, collapsible: true })
                    text: qsTr("支持展开和折叠：") + page.intro
                }
                TextLabel {
                    width: 150
                    ellipsis: ({ showTooltip: true, pos: "middle" })
                    text: "ssssssssssssssssssssssssssssss"
                }
                // 官方最后还有一组「Tooltip 里超长英文串换行」的演示，靠的是覆盖
                // CSS 的 word-break；本库 Tooltip 的文本固定按词换行，没有对应的钩子。
            }
        }
    }
}
