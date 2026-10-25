pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Empty 空状态。官方 `content/show/empty/index.md` 的「代码演示」一共 5 个小节，这里逐节摆齐：
// 如何引入 / 基本用法 / 自定义（两 demo：带操作区、不带图）/ 不同布局 / 占位图插画(建设中)。
// 插画是官方 `@douyinfe/semi-illustrations` 那 16 张 SVG 原样搬进来的（明色 8 张 + 暗色 8 张），
// 所以「基本用法 / 自定义 / 不同布局」三节都能同时演 `image` 与 `darkModeImage`，切到暗色
// 主题时整页会换一套插画。
//
// 端口与官方的几处口径差（各自写在节内说明里）：
//   · `style` / `imageStyle` / `className` 收了不产出可见差异 —— 端口这边组件本身就是那个元素。
//     官方 demo 里 `style={{padding: 30}}` 那种留白，这里改成外面包一层（见最后一节的 Art）。
//   · `image` 的 sprite 档（`{ id }` ⇒ `<use xlink:href>`）Qt 侧没有对应物，收了不画。
//   · 官方 `darkModeImage` 靠 MutationObserver 盯 body 的 `theme-mode`，端口直接跟 `Theme.mode`。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property string artDir: "qrc:/qt/qml/SemiGallery/data/illustrations/"

    function art(name) {
        return page.artDir + name + ".svg";
    }

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
                    text: "import { Empty } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("官方没有任何缺省内容 —— `image` / `title` / `description` 三条都没有缺省值，"
                        + "唯一的缺省是 `layout: \"vertical\"`。旧端口那套 `icon`（图标名）/ `iconSize` /"
                        + " 写死的「暂无数据」都是自造的，这轮整份撤掉换成官方面。")
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 700
                spacing: 12

                Empty {
                    image: page.art("construction")
                    darkModeImage: page.art("construction-dark")
                    title: qsTr("功能建设中")
                    description: qsTr("当前功能暂未开放，敬请期待。")
                }

                Note {
                    text: qsTr("官方 demo 给插画设的是 150×150（`style={{ width: 150, height: 150 }}`），"
                        + "而 SVG 自身是 200×200。端口这边 `imageStyle` 不产出差异、尺寸跟着图片自身走，"
                        + "所以这一节摆出来是 200×200。要缩就自己传节点档："
                        + "`image: Component { Image { source: …; width: 150; height: 150 } }`。"
                        + "切到左下角的浅色/深色开关，这张会换成 `-dark` 那一份 —— 官方是 MutationObserver "
                        + "盯 body 的 `theme-mode`，端口直接跟 `Theme.mode`。")
                }
            }
        }

        GallerySection {
            title: "自定义"

            Column {
                width: 700
                spacing: 28

                Empty {
                    image: page.art("noContent")
                    darkModeImage: page.art("noContent-dark")
                    title: qsTr("空状态标题")
                    description: qsTr("开始创建你的第一个仪表盘吧！")

                    // 官方 children 那一档（.semi-empty-footer）。官方是 `<div>` 包两颗按钮、
                    // 第一颗带 marginRight: 12 ⇒ 端口用一个 Row 顶替那个 div。
                    Row {
                        spacing: 12

                        Button {
                            text: qsTr("二级按钮")
                            tone: Enums.Primary
                        }

                        Button {
                            text: qsTr("一级按钮")
                            tone: Enums.Primary
                            variant: Enums.Solid
                        }
                    }
                }

                Empty {
                    title: qsTr("暂未找到匹配的筛选结果")
                    description: Component {
                        Row {
                            TextLabel {
                                text: qsTr("试试 ")
                            }

                            TextLabel {
                                text: qsTr("重置筛选条件")
                                link: true
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("第一张演 `children`：声明式子项落进 `.semi-empty-footer`，"
                        + "离上面那块恒有 24。第二张演「不用图」：`image` 没给 ⇒ 标题从 heading 4 "
                        + "（20 / 行高 28 / 字重 600）掉到 heading 6（16 / 22）并且字重被内联的 "
                        + "`fontWeight: 400` 压平 —— 官方那对 `Typography.Text` 端口用 `link: true` 的"
                        + "那颗顶替。")
                }
            }
        }

        GallerySection {
            title: "不同布局"

            Column {
                width: 800
                spacing: 12

                Empty {
                    width: 800
                    layout: "horizontal"
                    image: page.art("success")
                    darkModeImage: page.art("success-dark")
                    title: qsTr("创建成功")
                    description: qsTr("这是一段很长的描述文本，当文本过长的时候推荐使用这种布局形式。"
                        + "这是一段很长的描述文本，当文本过长的时候推荐使用这种布局形式。"
                        + "这是一段很长的描述文本，当文本过长的时候推荐使用这种布局形式。")

                    Button {
                        text: qsTr("开始操作")
                        tone: Enums.Primary
                        variant: Enums.Solid
                    }
                }

                Note {
                    text: qsTr("`layout: \"horizontal\"` 时内容层是 `margin-left: 32`、文字左对齐，"
                        + "图与内容谁高取谁当整件的高。官方那张的宽度是 `style={{ width: 800, margin: '0 auto' }}` "
                        + "给的，端口直接写 `width: 800`（`style` 这一档不产出差异）。")
                }
            }
        }

        GallerySection {
            title: "占位图插画(建设中)"

            Column {
                width: 700
                spacing: 12

                Flow {
                    width: 700

                    Repeater {
                        // 路径在页面这一层算好再交给格子：内联组件（`component Art`）取不到
                        // 外层组件的 id，`page.art()` 只能写在这里
                        model: [
                            { light: "success", dark: "success-dark", label: "创建成功" },
                            { light: "failure", dark: "failure-dark", label: "加载失败" },
                            { light: "noAccess", dark: "noAccess-dark", label: "没有权限" },
                            { light: "noContent", dark: "noContent-dark", label: "暂无内容，请添加" },
                            { light: "notFound", dark: "notFound-dark", label: "页面404" },
                            { light: "noResult", dark: "noResult-dark", label: "搜索无结果" },
                            { light: "construction", dark: "construction-dark", label: "建设中" },
                            { light: "idle", dark: "idle-dark", label: "神游四方" }
                        ]

                        delegate: Art {
                            required property var modelData

                            imageSource: page.art(modelData.light)
                            darkSource: page.art(modelData.dark)
                            label: modelData.label
                        }
                    }
                }

                Note {
                    text: qsTr("官方 `@douyinfe/semi-illustrations` 里这 8 组（v1.13.0 起另有一整套 "
                        + "`*Dark`）。这一节的 SVG 就是那个包里的原文件，`darkModeImage` 也一并对上，"
                        + "所以切暗色时八张会整套换。官方每张的 `style={{padding: 30}}` 端口用外面包一层实现。")
                }
            }
        }
    }

    // 一格插画：官方是 `<Empty style={{padding: 30}}>`，端口的 `style` 不产出差异 ⇒ 外面垫 30
    component Art: Item {
        id: cell

        property string imageSource: ""
        property string darkSource: ""
        property string label: ""

        width: body.implicitWidth + 60
        height: body.implicitHeight + 60

        Empty {
            id: body

            x: 30
            y: 30
            image: cell.imageSource
            darkModeImage: cell.darkSource
            description: cell.label
        }
    }

    // 说明里会出现 `<div>` / `<use xlink:href>` 这类尖括号，AutoText 会把它们当标签吃掉 ⇒ 钉 PlainText
    component Note: Text {
        width: 700
        textFormat: Text.PlainText
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
