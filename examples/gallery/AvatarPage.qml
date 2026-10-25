pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Avatar 头像。官方 `content/show/avatar/index.md` 的「代码演示」一共 10 节，加「如何引入」
// 这里一共 11 个小节：尺寸 / 颜色 / 自适应字符大小 / 图片 / 形状 / 事件 / 顶部和底部 Slot
// （合用 + 顶部 + 底部）/ 额外边框 / 额外动效 / 头像组（基本 + maxCount + renderMore + overlapFrom）。
//
// 端口与官方的口径差（完整清单在 src/Avatar.qml 与 src/AvatarGroup.qml 文件头）：
//   · 官方每一节的 `style={{ margin: 4 }}` 与颜色那两枚的内联底色，端口用 `backgroundColor`
//     与调用点自己加的间距表达；`className` / `imgAttr` / `srcSet` 在端口收了不产出差异。
//   · 官方 children 是字符串那一支（`<Avatar>AS</Avatar>`）在端口是 `text`，显示的是**整串**，
//     再按 `gap` 自适应缩放；旧端口那种「取首字并大写」是自造的。
//   · 图片那一节官方走外网 URL ⇒ 这里用仓库自带的两张示例图，另加一枚读图失败的做 fallback 演示。
//   · `hoverMask` 官方传一个铺满的 div + IconCamera，`--semi-color-overlay-bg` 这个令牌端口没有
//     ⇒ 用同值的半透明黑。
//   · `topSlot` 那圈「直播」帽子官方是一段带渐变的 SVG，QML 画不了渐变铺色 ⇒ 取起始色代表，
//     `gradientEnd` 因此看不出差异（默认两端口都是 primary）。
//   · `renderMore` 官方那一支把余下的头像塞进 Popover；端口的 Popover 只有字符串 `text` 内容
//     ⇒ 这里演示自定义节点本身（换成 Popover 弹层是页面级的事，不是这个 prop 的事）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property string lastEvent: ""

    readonly property string sampleOne: "qrc:/qt/qml/SemiGallery/data/img/sample1.png"
    readonly property string sampleTwo: "qrc:/qt/qml/SemiGallery/data/img/sample2.png"

    readonly property Component cameraMask: Component {
        Rectangle {
            color: Qt.rgba(0, 0, 0, 0.6)

            Icon {
                anchors.centerIn: parent
                name: "camera"
                size: 20
                color: Theme.current.colorWhite
            }
        }
    }

    // renderMore 给的节点官方能收到 (restNumber, restAvatars)；端口的 Component 没有入参注入通道
    // ⇒ 这一节把数字写死在节点里，演示的是「整支替换掉 +N 那一枚」这件事。
    readonly property Component moreAvatars: Component {
        Avatar {
            objectName: "pageMoreAvatar"
            text: "+2"
            backgroundColor: "#f74342"
        }
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
                    text: "import { Avatar, AvatarGroup } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("Avatar 官方 19 条：`alt` / `border` / `bottomSlot` / `className` / `color` /"
                        + " `contentMotion` / `hoverMask` / `gap` / `imgAttr` / `shape` / `size` / `src` /"
                        + " `srcSet` / `style` / `topSlot` / `onClick` / `onError` / `onMouseEnter` /"
                        + " `onMouseLeave`（children 不在表里但渲染）。defaultProps 只给四条：size medium、"
                        + " color grey、shape circle、gap 3，三个回调给的是 noop ⇒ `clickable` 就是"
                        + " 「onClick 不是那个 noop」。")
                }

                Note {
                    text: qsTr("端口把 `onError` 改名 `error`（`on` + 大写是 QML 信号处理器的保留前缀），"
                        + "三个回调变成 `clicked` / `mouseEntered` / `mouseLeft` 三个信号；`style` 的内联底色"
                        + " 收成 `backgroundColor`。`clickable` 那一支决定 tabIndex 与 alt 前缀，而 Qt 的"
                        + " signal 探测不到有没有连接 ⇒ 焦点一律按 `enabled` 给，alt 也不加"
                        + " \"clickable Avatar: \" 那一截前缀。")
                }
            }
        }

        GallerySection {
            title: "尺寸"

            Column {
                spacing: 16

                Row {
                    spacing: 12

                    Avatar {
                        text: "U"
                        size: "extra-extra-small"
                        alt: "User"
                    }
                    Avatar {
                        text: "U"
                        size: "extra-small"
                        alt: "User"
                    }
                    Avatar {
                        text: "U"
                        size: "small"
                        alt: "User"
                    }
                    Avatar {
                        text: "U"
                        size: "default"
                        alt: "User"
                    }
                    Avatar {
                        text: "U"
                        alt: "User"
                    }
                    Avatar {
                        text: "U"
                        size: "large"
                        alt: "User"
                    }
                    Avatar {
                        text: "U"
                        size: "extra-large"
                        alt: "User"
                    }
                }

                Row {
                    spacing: 12

                    Avatar {
                        text: "自定义"
                        size: 64
                        alt: "User"
                    }
                    Avatar {
                        text: "自定义方角"
                        size: 64
                        shape: "square"
                        alt: "User"
                    }
                }

                Note {
                    text: qsTr("七档是 20 / 24 / 32 / 40 / 72 / 128 与中间的 48（`$width-avatar_*`）。"
                        + "官方那条 `!SIZE.includes(size)` 就改走内联宽高 ⇒ 传数字（甚至 \"10px\" 那种字符串，"
                        + "浏览器认它）也合法；端口只认「正数」，认不出的退成缺省档。方角的半径同样挂在尺寸类名上，"
                        + "所以自定义尺寸那一枚是 0 半径，`large` 是 6、`extra-large` 是 12，其余 3。")
                }
            }
        }

        GallerySection {
            title: "颜色"

            Column {
                spacing: 16

                Row {
                    spacing: 12

                    Avatar {
                        text: "AS"
                        alt: "Alice Swift"
                    }
                    Avatar {
                        text: "BM"
                        color: "red"
                        alt: "Bob Matteo"
                    }
                    Avatar {
                        text: "TJ"
                        color: "light-blue"
                        alt: "Taylor Joy"
                    }
                    Avatar {
                        text: "ZL"
                        backgroundColor: "#fde3cf"
                        alt: "Zank Lance"
                    }
                    Avatar {
                        text: "YZ"
                        backgroundColor: "#87d068"
                        alt: "Youself Zhang"
                    }
                }

                Row {
                    spacing: 8

                    Repeater {
                        model: ["amber", "blue", "cyan", "green", "grey", "indigo", "light-blue",
                            "light-green", "lime", "orange", "pink", "purple", "red", "teal",
                            "violet", "yellow"]

                        Avatar {
                            required property var modelData
                            property string tone: modelData

                            text: tone.charAt(0).toUpperCase()
                            color: tone
                            size: "small"
                            alt: tone
                        }
                    }

                    Avatar {
                        text: "W"
                        color: "white"
                        size: "small"
                        alt: "white"
                    }
                }

                Note {
                    text: qsTr("色板那一档取的是 `--semi-<color>-3`，字恒白。官网写「15 种颜色和白色」，"
                        + "constants.ts 的 COLOR 表确实是 17 项（含 white），但 avatar.scss 的 $colors 列表只有 16 项"
                        + " ⇒ `color=\"white\"` 命不中任何规则，底色透明、文字退回继承值（最后那枚白的就是）。"
                        + "官方 `color && !isImg` 这条也在这儿：一旦有图，色板类名整条不挂。官方那一节还有两枚用"
                        + " `style` 同时改文字色与底色，端口的 `style` 只落 `backgroundColor` ⇒ 文字色那半没有差异。")
                }
            }
        }

        GallerySection {
            title: "自适应字符大小"

            Column {
                spacing: 16

                Row {
                    spacing: 12

                    Avatar {
                        text: "AS"
                        alt: "AS"
                    }
                    Avatar {
                        text: "Semi"
                        gap: 4
                        alt: "Semi"
                    }
                    Avatar {
                        text: "Semi"
                        gap: 10
                        alt: "Semi"
                    }
                    Avatar {
                        text: "Semi Design 官方"
                        alt: "长文字"
                    }
                }

                Note {
                    text: qsTr("官方的自适应在 `foundation.ts` 的 `changeScale`：可用宽 = 盒宽 − 2×gap，"
                        + "放得下就是 1，放不下按 `可用宽 / 文字宽` 缩放，`transform: scale()` 挂在 `-content` 上。"
                        + "两道闸门：`gap*2 < 盒宽` 且两边都量得到才收紧（gap 给到 16、盒宽 32 就整个不动）。"
                        + "另外 `extra-extra-small` / `extra-small` 那两档 scss 里还写了 `-content { transform: scale(0.8) }`，"
                        + "但字符串那一支永远带内联 transform ⇒ 那条压不上去，是死规则。")
                }
            }
        }

        GallerySection {
            title: "图片"

            Column {
                spacing: 16

                // 铺一层有色底：圆切掉的那四个角要能看出来，页面本身是白的就分不出
                Rectangle {
                    width: 520
                    height: imageRow.height + 32
                    radius: Theme.current.radiusMedium
                    color: "#dcdfe6"

                    Row {
                        id: imageRow

                        x: 16
                        y: 16
                        spacing: 12

                        Avatar {
                            src: page.sampleOne
                            alt: "beautiful cat"
                        }
                        Avatar {
                            src: page.sampleTwo
                            size: "small"
                            alt: "cute cat"
                        }
                        Avatar {
                            src: page.sampleTwo
                            size: "large"
                            shape: "square"
                            alt: "square cat"
                        }
                        Avatar {
                            src: page.sampleTwo
                            size: "large"
                            alt: "big cat"
                        }
                        Avatar {
                            src: "qrc:/qt/qml/SemiGallery/data/img/does-not-exist.png"
                            text: "备"
                            alt: "fallback"
                        }
                    }
                }

                Note {
                    text: qsTr("图片那一支官方是 `<img>` + 外层 `overflow:hidden` + `border-radius` 把图裁成圆。"
                        + "QML 的 `clip` 只裁矩形 ⇒ 端口用 `Image{visible:false}` 当源 + 一颗 `visible:false` 且"
                        + " `layer.enabled` 的形状件当遮罩 + `MultiEffect`。2026-10-21 在 cocoa 逐像素复验过：圆内是图、"
                        + "方框四角是底色；遮罩项少了 `layer.enabled` 就整块画不出来。最后一枚读图失败 ⇒"
                        + " `notifyImgState(false)` 回落成文字档。")
                }
            }
        }

        GallerySection {
            title: "形状"

            Row {
                spacing: 12

                Avatar {
                    text: "U"
                    alt: "User"
                }
                Avatar {
                    text: "U"
                    shape: "square"
                    alt: "User"
                }
                Avatar {
                    text: "U"
                    size: "large"
                    shape: "square"
                    alt: "User"
                }
            }
        }

        GallerySection {
            title: "事件"

            Column {
                spacing: 16

                Row {
                    spacing: 12

                    Avatar {
                        id: hoverAvatar

                        text: "BD"
                        color: "red"
                        alt: "Bob Downton"
                        hoverMask: page.cameraMask

                        onClicked: page.lastEvent = "clicked"
                        onMouseEntered: page.lastEvent = "mouseEntered"
                        onMouseLeft: page.lastEvent = "mouseLeft"
                    }

                    Avatar {
                        text: "图"
                        src: page.sampleOne
                        alt: "带 hover 覆盖层的图"
                        hoverMask: "camera"
                    }
                }

                Text {
                    width: 520
                    text: page.lastEvent === "" ? qsTr("把指针移到左边那枚头像上")
                        : qsTr("最近一次回调：") + page.lastEvent
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                Note {
                    text: qsTr("覆盖层没有默认样式（官方原话），它只是一个铺满头像盒、跟着 `overflow:hidden` 一起裁的层；"
                        + "`hoverMask` 收图标名或 Component 两种写法。焦点轮廓那条 `:focus-visible` 浏览器只在键盘"
                        + "切焦点时画，QML 探测不到这一档 ⇒ 端口拿 `activeFocus` 代理，Tab 到就有那 2px。")
                }
            }
        }

        GallerySection {
            title: "顶部和底部 Slot"

            Column {
                spacing: 24

                Row {
                    spacing: 24

                    Avatar {
                        src: page.sampleOne
                        size: "large"
                        alt: "beautiful cat"
                        border: ({ color: "#FE2C55", motion: true })
                        contentMotion: true
                        topSlot: ({ text: "直播", gradientStart: "rgb(255,23,100)", gradientEnd: "rgb(237,52,148)" })
                        bottomSlot: ({ shape: "circle", bgColor: "#FE2C55", text: "+" })
                    }
                }

                Column {
                    spacing: 12

                    Text {
                        text: "顶部"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeSmall
                        font.weight: Font.DemiBold
                    }

                    Row {
                        spacing: 24

                        Avatar {
                            text: "T"
                            color: "amber"
                            topSlot: ({ text: "直播", gradientStart: "rgb(255,23,100)", gradientEnd: "rgb(237,52,148)" })
                        }
                        Avatar {
                            text: "T"
                            color: "amber"
                            size: "large"
                            topSlot: ({ text: "直播", gradientStart: "rgb(255,23,100)", gradientEnd: "rgb(237,52,148)" })
                        }
                        Avatar {
                            text: "T"
                            color: "amber"
                            size: "extra-large"
                            topSlot: ({ text: "直播", gradientStart: "rgb(255,23,100)", gradientEnd: "rgb(237,52,148)" })
                        }
                    }
                }

                Column {
                    spacing: 12

                    Text {
                        text: "底部"
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeSmall
                        font.weight: Font.DemiBold
                    }

                    Row {
                        spacing: 24

                        Avatar {
                            text: "T"
                            color: "amber"
                            bottomSlot: ({ shape: "square", bgColor: "#FE2C55", text: "直播中" })
                        }
                        Avatar {
                            text: "T"
                            color: "amber"
                            size: "large"
                            bottomSlot: ({ shape: "square", bgColor: "#FE2C55", text: "直播中" })
                        }
                        Avatar {
                            text: "T"
                            color: "amber"
                            size: "extra-large"
                            bottomSlot: ({ shape: "square", bgColor: "#FE2C55", text: "直播中" })
                        }
                    }

                    Row {
                        spacing: 24

                        Avatar {
                            text: "T"
                            color: "amber"
                            bottomSlot: ({ shape: "circle", bgColor: "#FE2C55", text: "+" })
                        }
                        Avatar {
                            text: "T"
                            color: "amber"
                            size: "large"
                            bottomSlot: ({ shape: "circle", bgColor: "#FE2C55", text: "+" })
                        }
                        Avatar {
                            text: "T"
                            color: "amber"
                            size: "extra-large"
                            bottomSlot: ({ shape: "circle", bgColor: "#FE2C55", text: "+" })
                        }
                    }
                }

                Note {
                    text: qsTr("两个槽都有档位闸：只认 `extra-small` 到 `extra-large` 那六档，"
                        + "顶部还额外要求 `shape === 'circle'`。顶部那圈帽子官方是 51×52 的 SVG（一段带渐变的圆角路径 + 投影），"
                        + "靠逐档的 `top` 位移与 `scale` 摆在头像顶上、再被那颗和头像等大的圆裁一遍；端口画不了 SVG 渐变，取起始色代表。"
                        + "底部那枚圆片 12/12/16/18/28/28，方牌是 padding 1px 4px + 2px 的 bg-0 描边，两者都骑在下沿上"
                        + "（`bottom: 3.5` 再 `translateY(50%)` ⇒ 中心压在那条线上）。顺带一条官方 bug：方牌的档位类名拼成下划线"
                        + "（`-shape_square-extra_small`），实际挂出来是连字符 ⇒ `extra-small` 那档的字号与描边宽命不中，"
                        + "描边退成浏览器的 medium(3px)。")
                }
            }
        }

        GallerySection {
            title: "额外边框"

            Row {
                spacing: 16

                Avatar {
                    text: "T"
                    color: "amber"
                    border: true
                }
                Avatar {
                    text: "T"
                    color: "amber"
                    size: "large"
                    border: true
                }
                Avatar {
                    text: "T"
                    color: "amber"
                    size: "extra-large"
                    border: ({ color: "#FE2C55" })
                }
                Avatar {
                    text: "方"
                    color: "amber"
                    shape: "square"
                    border: true
                }
            }

            Note {
                text: qsTr("边框是头像盒子外面再套一圈 1.5px 的环：`top/left = −(1.5 + 2)`、边长 = 头像边长 + 7。"
                    + "环自己的圆角只有 `circle` 那一支命得中（span 上挂的是 `-avatar-circle`）；方角那组规则官方拼成下划线"
                    + "（`-additionalBorder-extra_small`），实际类名是连字符 ⇒ 命不中，方角头像外面那圈是直角。")
            }
        }

        GallerySection {
            title: "额外动效"

            Column {
                spacing: 16

                Row {
                    spacing: 16

                    Avatar {
                        text: "T"
                        color: "amber"
                        border: ({ motion: true })
                        contentMotion: true
                    }
                    Avatar {
                        text: "T"
                        color: "amber"
                        size: "large"
                        border: ({ motion: true })
                        contentMotion: true
                    }
                    Avatar {
                        text: "T"
                        color: "amber"
                        size: "extra-large"
                        border: ({ motion: true })
                        contentMotion: true
                    }
                }

                Note {
                    text: qsTr("`border={{motion:true}}` 那条 keyframes 是 800ms 一轮：透明度 1→0、缩放 1→1.15、"
                        + "描边宽 1.5→0，而且官方是「两圈并存」（静态那圈 + 动的那圈）。`contentMotion` 是 1000ms 的"
                        + "缩放脉冲（1→0.9→1），变换的是头像本体那一层；顶部槽位自己也带同一条动画，底部槽位与外圈环都不跟着走。")
                }
            }
        }

        GallerySection {
            title: "头像组"

            Column {
                spacing: 24

                Column {
                    spacing: 8

                    AvatarGroup {
                        Avatar {
                            text: "LL"
                            color: "red"
                            alt: "Lisa LeBlanc"
                        }
                        Avatar {
                            text: "CX"
                            alt: "Caroline Xiao"
                        }
                        Avatar {
                            text: "RM"
                            color: "amber"
                            alt: "Rafal Matin"
                        }
                        Avatar {
                            text: "ZL"
                            backgroundColor: "#fde3cf"
                            alt: "Zank Lance"
                        }
                        Avatar {
                            text: "YZ"
                            backgroundColor: "#87d068"
                            alt: "Youself Zhang"
                        }
                    }

                    Text {
                        text: "AvatarGroup 缺省 medium / circle / overlapFrom start"
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }

                Column {
                    spacing: 8

                    AvatarGroup {
                        maxCount: 3

                        Avatar {
                            text: "LL"
                            color: "red"
                            alt: "Lisa LeBlanc"
                        }
                        Avatar {
                            text: "CX"
                            alt: "Caroline Xiao"
                        }
                        Avatar {
                            text: "RM"
                            color: "amber"
                            alt: "Rafal Matin"
                        }
                        Avatar {
                            text: "ZL"
                            backgroundColor: "#fde3cf"
                            alt: "Zank Lance"
                        }
                        Avatar {
                            text: "YZ"
                            backgroundColor: "#87d068"
                            alt: "Youself Zhang"
                        }
                    }

                    Text {
                        text: "maxCount=3 ⇒ 末尾多一枚「+2」，底色是 grey-5、字白"
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }

                Column {
                    spacing: 8

                    AvatarGroup {
                        id: customGroup

                        maxCount: 3
                        renderMore: page.moreAvatars

                        Avatar {
                            text: "LL"
                            color: "red"
                            alt: "Lisa LeBlanc"
                        }
                        Avatar {
                            text: "CX"
                            alt: "Caroline Xiao"
                        }
                        Avatar {
                            text: "RM"
                            color: "amber"
                            alt: "Rafal Matin"
                        }
                        Avatar {
                            text: "ZL"
                            backgroundColor: "#fde3cf"
                            alt: "Zank Lance"
                        }
                        Avatar {
                            text: "YZ"
                            backgroundColor: "#87d068"
                            alt: "Youself Zhang"
                        }
                    }

                    Text {
                        text: "renderMore 给一个节点整支替换掉「+N」（官方那一支还塞了个 Popover 列余下头像）"
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    spacing: 12

                    Row {
                        spacing: 24

                        AvatarGroup {
                            overlapFrom: "start"

                            Avatar {
                                text: "LL"
                                color: "red"
                                alt: "Lisa LeBlanc"
                            }
                            Avatar {
                                text: "CX"
                                alt: "Caroline Xiao"
                            }
                            Avatar {
                                text: "RM"
                                color: "amber"
                                alt: "Rafal Matin"
                            }
                        }

                        AvatarGroup {
                            overlapFrom: "end"

                            Avatar {
                                text: "LL"
                                color: "red"
                                alt: "Lisa LeBlanc"
                            }
                            Avatar {
                                text: "CX"
                                alt: "Caroline Xiao"
                            }
                            Avatar {
                                text: "RM"
                                color: "amber"
                                alt: "Rafal Matin"
                            }
                        }
                    }

                    Text {
                        text: "左：start（越靠前越浮）　右：end（越靠后越浮）"
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }

                Row {
                    spacing: 24

                    AvatarGroup {
                        size: "small"

                        Avatar {
                            text: "LL"
                            color: "red"
                            alt: "Lisa LeBlanc"
                        }
                        Avatar {
                            text: "CX"
                            alt: "Caroline Xiao"
                        }
                        Avatar {
                            text: "RM"
                            color: "amber"
                            alt: "Rafal Matin"
                        }
                    }

                    AvatarGroup {
                        size: "extra-large"
                        shape: "square"

                        Avatar {
                            text: "LL"
                            color: "red"
                            alt: "Lisa LeBlanc"
                        }
                        Avatar {
                            text: "CX"
                            alt: "Caroline Xiao"
                        }
                    }
                }

                Note {
                    text: qsTr("官方 `avatarGroup.tsx` 用 cloneElement 把组的 size / shape 硬塞给每一个成员"
                        + " ⇒ 组里混尺寸混形状在这条路径上根本不存在（最后那排 extra-large 方角是故意的演示）。"
                        + "重叠是逐档负 margin（−4 / −10 / −12 / −12 / −12 / −18 / −32），每个成员还带一圈逐档描边"
                        + "（1 / 2 / 2 / 2 / 2 / 3 / 3px，颜色是 bg-1）盖住被压住的那半。层序官方只给下标 0..20 生成类名，"
                        + "端口把两条算式一路延下去。「+N」那一枚的 alt 是全角冒号那串 + 余下成员的 alt 或文字拼起来。")
                }
            }
        }
    }

    component Note: Text {
        width: 700
        textFormat: Text.PlainText
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
