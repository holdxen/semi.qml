pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 标签。小节顺序与标题对齐官方文档页 content/show/tag/index.md
// （docs.json 里的 12 个小节，「如何引入」也照旧进 demo 区）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 「不可见的」那一节：官方 useState(false) + RadioGroup Show / Hide 来回切
    property bool tagShown: false
    // TagGroup 可删除那一节：官方在 onTagClose 里把 tagList 中那一条 splice 掉
    property var groupList: [
        { tagKey: "1", color: "light-blue", children: "抖音", closable: true },
        { tagKey: "3", color: "cyan", children: "剪映", closable: true },
        { tagKey: "2", color: "violet", children: "醒图", closable: true },
        { tagKey: "4", color: "teal", children: "轻颜相机", closable: true },
        { tagKey: "5", color: "white", children: "飞书", closable: true }
    ]

    readonly property string avatarSrc: "qrc:/qt/qml/SemiGallery/data/img/sample1.png"

    // 官方 AI 那一节的图标：solid 档用 level_1（深底上跟着白字走），
    // light / ghost 的渐变档用 level_3（图标自带渐变，着色会把渐变糊掉），
    // light / ghost 的非渐变档用 level_1 上 ai-purple。尺寸都写 size="small" = 12
    readonly property Component starWhite: Component {
        Icon {
            name: "ai_filled_level_1"
            size: Theme.current.widthIconSmall
            color: Theme.current.colorWhite
        }
    }

    readonly property Component starPurple: Component {
        Icon {
            name: "ai_filled_level_1"
            size: Theme.current.widthIconSmall
            color: Theme.current.colorAiPurple
        }
    }

    readonly property Component starGradient: Component {
        Icon {
            name: "ai_filled_level_3"
            size: Theme.current.widthIconSmall
            tinted: false
        }
    }

    // 官方 demo 外层那个 div：background fill-0、height 35、width 300、padding 0 10
    component DemoBox: Rectangle {
        width: 300
        height: 35
        radius: Theme.current.radiusSmall
        color: Theme.current.colorFill0
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 620
                text: "import Semi\n\n"
                    + "// 三个组件各自独立，没有官方那种嵌套类型写法\n"
                    + "Tag { text: \"default tag\" }\n"
                    + "TagGroup {\n"
                    + "    maxTagCount: 3\n"
                    + "    tagList: [{ color: \"cyan\", children: \"火山\" }]   // children 也可直接写 text\n"
                    + "}\n"
                    + "SplitTagGroup {\n"
                    + "    Tag { text: \"标签一\" }\n"
                    + "    Tag { text: \"标签二\" }\n"
                    + "}"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "基本用法"

            Space {
                Tag { text: "default tag" }
                Tag { text: "Closable Tag"; closable: true }
                // 官方 onClose 里 e.preventDefault() → 点了叉也照样留着
                Tag {
                    text: "Closable Tag, Prevent Default"
                    closable: true

                    onClosed: (tagChildren, event, tagKey) => event.preventDefault()
                }
            }
        }

        GallerySection {
            title: "尺寸"

            Space {
                Tag { text: "small tag"; size: "small"; color: "light-blue" }
                Tag { text: "large tag"; size: "large"; color: "cyan" }
            }
        }

        GallerySection {
            title: "形状"

            Space {
                Tag { text: "small circle tag"; size: "small"; shape: "circle"; color: "amber" }
                Tag { text: "large circle tag"; size: "large"; shape: "circle"; color: "violet" }
            }
        }

        GallerySection {
            title: "配置图标"

            Space {
                Tag {
                    text: "Semi Design"
                    color: "light-blue"
                    prefixIcon: "github_logo"
                    size: "large"
                    shape: "circle"
                }
                Tag {
                    text: "D2C: figma to code in one click"
                    color: "cyan"
                    size: "large"
                    shape: "circle"
                    suffixIcon: "semi_logo"
                }
            }
        }

        GallerySection {
            title: "颜色"

            // 官方是 <Space wrap>，17 个色档一排放不下要折行
            Flow {
                width: 620
                spacing: Theme.current.spacingTight

                Repeater {
                    model: ["amber", "blue", "cyan", "green", "grey", "indigo",
                        "light-blue", "light-green", "lime", "orange", "pink",
                        "purple", "red", "teal", "violet", "yellow", "white"]

                    delegate: Tag {
                        required property var modelData

                        text: modelData
                        color: modelData
                    }
                }
            }
        }

        GallerySection {
            title: "AI 风格 - 多彩标签"

            Column {
                spacing: 30

                // 官方两个 grid（repeat(3,1fr)、gridGap 10）：上面那格 shape circle，
                // 下面那格方角；每格里前两行带 gradient、后两行不带
                Grid {
                    columns: 3
                    rowSpacing: 10
                    columnSpacing: 10

                    Tag { text: "AI"; colorful: true; prefixIcon: page.starWhite; type: "solid"; shape: "circle"; gradient: true }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starGradient; type: "light"; shape: "circle"; gradient: true }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starGradient; type: "ghost"; shape: "circle"; gradient: true }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starWhite; type: "solid"; shape: "circle" }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starPurple; type: "light"; shape: "circle" }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starPurple; type: "ghost"; shape: "circle" }
                }

                Grid {
                    columns: 3
                    rowSpacing: 10
                    columnSpacing: 10

                    Tag { text: "AI"; colorful: true; prefixIcon: page.starWhite; type: "solid"; gradient: true }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starGradient; type: "light"; gradient: true }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starGradient; type: "ghost"; gradient: true }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starWhite; type: "solid" }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starPurple; type: "light" }
                    Tag { text: "AI"; colorful: true; prefixIcon: page.starPurple; type: "ghost" }
                }
            }
        }

        GallerySection {
            title: "样式类型"

            Flow {
                width: 620
                spacing: Theme.current.spacingTight

                Tag {
                    text: "Semi Design Light Tag"
                    color: "light-blue"
                    prefixIcon: "github_logo"
                    size: "large"
                    shape: "circle"
                    type: "light"
                }
                Tag {
                    text: "D2C: figma to code in one click"
                    color: "cyan"
                    size: "large"
                    shape: "circle"
                    suffixIcon: "semi_logo"
                    type: "light"
                }
                Tag {
                    text: "Semi Design Ghost Tag"
                    color: "light-blue"
                    prefixIcon: "github_logo"
                    size: "large"
                    shape: "circle"
                    type: "ghost"
                }
                Tag {
                    text: "D2C: figma to code in one click"
                    color: "cyan"
                    size: "large"
                    shape: "circle"
                    type: "ghost"
                    suffixIcon: "semi_logo"
                }
                Tag {
                    text: "Semi Design Solid Tag"
                    color: "light-blue"
                    prefixIcon: "github_logo"
                    size: "large"
                    shape: "circle"
                    type: "solid"
                }
                Tag {
                    text: "D2C: figma to code in one click"
                    color: "cyan"
                    size: "large"
                    shape: "circle"
                    type: "solid"
                    suffixIcon: "semi_logo"
                }
            }
        }

        GallerySection {
            title: "头像标签"

            Column {
                spacing: Theme.current.spacingTight

                Tag { text: "焦锐志"; avatarSrc: page.avatarSrc }
                Tag { text: "焦锐志"; avatarSrc: page.avatarSrc; size: "large" }
                Tag { text: "焦锐志"; avatarSrc: page.avatarSrc; size: "large"; closable: true }
                Tag { text: "焦锐志"; avatarSrc: page.avatarSrc; avatarShape: "circle" }
                Tag { text: "焦锐志"; avatarSrc: page.avatarSrc; avatarShape: "circle"; size: "large" }
                Tag {
                    text: "焦锐志"
                    avatarSrc: page.avatarSrc
                    avatarShape: "circle"
                    size: "large"
                    closable: true
                }
            }
        }

        GallerySection {
            title: "不可见的"

            Column {
                spacing: 10

                RadioGroup {
                    type: Enums.ChoiceButton
                    defaultValue: 0
                    onChanged: (v) => page.tagShown = Number(v) === 1

                    Radio { value: 1; text: "Show" }
                    Radio { value: 0; text: "Hide" }
                }

                // 这一节把 visible 传进来了，就是受控标签：只跟 visible 走
                Tag {
                    visible: page.tagShown
                    size: "large"
                    color: "light-blue"
                    text: "Invisible tag"
                }
            }
        }

        GallerySection {
            title: "TagGroup 使用"

            Column {
                spacing: 30

                DemoBox {
                    TagGroup {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 350
                        maxTagCount: 3
                        size: "large"
                        tagList: [
                            { color: "light-blue", children: "抖音" },
                            { color: "cyan", children: "火山" },
                            { color: "violet", children: "剪映" },
                            { color: "white", children: "醒图" }
                        ]
                    }
                }

                DemoBox {
                    TagGroup {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 350
                        maxTagCount: 2
                        size: "large"
                        avatarShape: "circle"
                        showPopover: true
                        tagList: [
                            { color: "white", children: "Douyin", avatarSrc: page.avatarSrc },
                            { color: "white", children: "Hotsoon", avatarSrc: page.avatarSrc },
                            { color: "white", children: "Capcut", avatarSrc: page.avatarSrc },
                            { color: "white", children: "Xingtu", avatarSrc: page.avatarSrc }
                        ]
                    }
                }

                // 官方这一段：标签可删除时，用户要在 onTagClose 里自己改传进去的 tagList
                DemoBox {
                    TagGroup {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 350
                        maxTagCount: 3
                        showPopover: true
                        size: "large"
                        tagList: page.groupList

                        onTagClosed: (tagChildren, event, tagKey) => {
                            const next = [];
                            for (let i = 0; i < page.groupList.length; ++i) {
                                if (page.groupList[i].tagKey !== tagKey)
                                    next.push(page.groupList[i]);
                            }
                            page.groupList = next;
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "SplitTagGroup 组合标签"

            Column {
                spacing: Theme.current.spacingTight

                SplitTagGroup {
                    Tag { text: "标签一"; color: "blue"; type: "solid" }
                    Tag { text: "标签二"; color: "cyan"; type: "solid" }
                    Tag { text: "标签三"; color: "teal"; type: "solid" }
                }

                SplitTagGroup {
                    Tag { text: "组合"; color: "violet"; shape: "circle" }
                    Tag { text: "标签"; color: "purple"; shape: "circle" }
                    Tag { text: "示例"; color: "pink"; shape: "circle" }
                    Tag { text: "效果"; color: "red"; shape: "circle" }
                }

                SplitTagGroup {
                    Tag { text: "浅色"; color: "amber"; type: "light" }
                    Tag { text: "组合"; color: "orange"; type: "light" }
                    Tag { text: "标签"; color: "yellow"; type: "light" }
                }

                SplitTagGroup {
                    Tag { text: "镂空"; color: "green"; type: "ghost" }
                    Tag { text: "样式"; color: "light-green"; type: "ghost" }
                    Tag { text: "组合"; color: "lime"; type: "ghost" }
                }
            }
        }
    }
}
