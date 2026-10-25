pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Badge 徽标。官方 `content/show/badge/index.md` 的「代码演示」一共 5 节，加「如何引入」
// 这里一共 6 个小节：基本用法 / 设置显示数字最大值 / 设置徽标位置 / 设置徽标样式（theme、type 两张）
// / 独立使用。
//
// 端口与官方的口径差（完整清单在 src/Badge.qml 文件头）：
//   · 官方每一节都是 `<Badge …><Avatar style={{width:42,height:42,borderRadius:4}}>ZH</Avatar></Badge>`
//     —— 那 42×42 与圆角是内联 style（端口是死 prop）⇒ 这里用 Avatar 自己的尺寸档。
//   · 官方 `count` 是 ReactNode，端口收「数字 / 字符串 / Component」三档；节点档照官方语义
//     （custom ⇒ 不加 type/theme 类、不自带底色与描边）。
//   · 官方第一节的 `<IconLock>` 在端口没有同名图标（图标表里没 lock）⇒ 换成 heart_stroked。
//   · 官网正文写「`type` 支持 primary、secondary、tertiary、warning、danger」漏了 `success`，
//     而 constants.ts 的 TYPE_SET 是六个 ⇒ 端口照六个做，页面也摆六个。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    readonly property Component lockLikeNode: Component {
        Icon {
            name: "heart_stroked"
            size: 16
            color: Theme.current.colorPrimary
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
                    text: "import { Badge } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("Badge 官方一共 14 条：`count` / `dot` / `type` / `theme` / `position` /"
                        + " `overflowCount` / `style` / `className` / `countClassName` / `countStyle` /"
                        + " `children` / `onClick` / `onMouseEnter` / `onMouseLeave`。defaultProps 只给了"
                        + " 五条（dot false、type primary、theme solid、className ''、三个空回调）⇒"
                        + " `count` / `overflowCount` / `position` 都没有缺省值，`position` 是在 render"
                        + " 里现取 `direction === 'rtl' ? 'leftTop' : 'rightTop'`。")
                }

                Note {
                    text: qsTr("三条「有没有画」的判据都在 render 里现算：`showBadge` 只看 count 给没给"
                        + "（`count=0` 也画，画一个 \"0\"）；`custom` 是 `count && !(isNumber || isString)`"
                        + " ⇒ 0 与空串都算假、走不到节点档；`-count` 那套 18 高的药丸几何要"
                        + " `!dot && !custom && showBadge` 三条同时成立。还有一条：`-position` 那个类要"
                        + " `Boolean(position) && Boolean(children)` ⇒ 没有 base 内容就不绝对定位，"
                        + "改挂 `-block`（`position: static`，跟着文字流走，见最后一节）。")
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 700
                spacing: 24

                Row {
                    spacing: 32

                    Badge {
                        count: 5

                        Avatar {
                            text: "BM"
                            shape: "square"
                        }
                    }

                    Badge {
                        dot: true

                        Avatar {
                            text: "YL"
                            shape: "square"
                        }
                    }

                    Badge {
                        count: page.lockLikeNode

                        Avatar {
                            text: "XZ"
                            shape: "square"
                        }
                    }

                    Badge {
                        count: "NEW"

                        Avatar {
                            text: "WF"
                            shape: "square"
                        }
                    }
                }

                Note {
                    text: qsTr("四例分别是数字 / 圆点 / 节点 / 字符串。`dot` 与 `count` 官方文档说"
                        + "「两者互斥，优先渲染小圆点」，实现里是 `{dot ? null : content}` ⇒ 同时给就"
                        + "只剩点、内容整个不渲染。节点档官方那个是 `<IconLock>`（端口图标表里没有 lock，"
                        + "换成 heart_stroked），而且 custom 档不加 type / theme 类 ⇒ 徽标自己不带底色"
                        + "与描边，全看节点画什么。")
                }
            }
        }

        GallerySection {
            title: "设置显示数字最大值"

            Column {
                width: 700
                spacing: 24

                Row {
                    spacing: 32

                    Badge {
                        count: 99

                        Avatar {
                            text: "ZH"
                            shape: "square"
                        }
                    }

                    Badge {
                        count: 100

                        Avatar {
                            text: "HS"
                            shape: "square"
                        }
                    }

                    Badge {
                        count: 99
                        overflowCount: 10

                        Avatar {
                            text: "DY"
                            shape: "square"
                        }
                    }

                    Badge {
                        count: 1000
                        overflowCount: 999

                        Avatar {
                            text: "TT"
                            shape: "square"
                        }
                    }
                }

                Note {
                    text: qsTr("判据是 `overflowCount && overflowCount < count` ⇒ 拼出 `${overflowCount}+`。"
                        + "两点要留意：`overflowCount` 官方没有缺省值，不传就永不截断（第二枚 100 就原样显示），"
                        + "旧端口那个「缺省 99」是自造的；比较是 `<` 而不是 `<=` ⇒ 正好等于上限那一档不截"
                        + "（第三枚给 99 + 上限 10 会显示 \"10+\"，但 10 本身会显示 \"10\"）。")
                }
            }
        }

        GallerySection {
            title: "设置徽标位置"

            Column {
                width: 700
                spacing: 24

                Row {
                    spacing: 40

                    Repeater {
                        model: ["rightTop", "rightBottom", "leftTop", "leftBottom"]

                        delegate: Badge {
                            id: posBadge

                            required property int index
                            required property var modelData

                            count: "VIP"
                            type: "danger"
                            position: posBadge.modelData

                            Avatar {
                                text: "ZH"
                                shape: "square"
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("四方位在 scss 里都是 `right/left/bottom/top: 0` 配"
                        + " `translate(±50%, ∓50%)` ⇒ 徽标的中心正压在 base 内容的那个角点上，"
                        + "不是「贴边留一点空隙」。旧端口那个 `0.28` 比例与 dot 的 `-3px` 都是自造的。"
                            + "端口没有 RTL 方向概念 ⇒ `position` 的缺省恒 `rightTop`。")
                }
            }
        }

        GallerySection {
            title: "设置徽标样式"

            Column {
                width: 700
                spacing: 24

                Column {
                    spacing: 8

                    Text {
                        text: qsTr("theme：solid（默认）/ light / inverted")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Row {
                        spacing: 40

                        Repeater {
                            model: ["solid", "light", "inverted"]

                            delegate: Badge {
                                id: themeBadge

                                required property int index
                                required property var modelData

                                count: 5
                                theme: themeBadge.modelData

                                Avatar {
                                    text: "XZ"
                                    shape: "square"
                                }
                            }
                        }

                        Repeater {
                            model: ["solid", "light", "inverted"]

                            delegate: Rectangle {
                                id: dotCell

                                required property int index
                                required property var modelData

                                // 官方这一格是 `<div style={{padding:8, borderRadius:4,
                                // backgroundColor:'var(--semi-color-fill-0)'}}>` —— inverted 那颗点是
                                // 白底白环，摆在 fill-0 上才看得见
                                width: dotBadge.width + 16
                                height: dotBadge.height + 16
                                radius: 4
                                color: index === 2 ? Theme.current.colorFill0 : "transparent"

                                Badge {
                                    id: dotBadge

                                    x: 8
                                    y: 8
                                    dot: true
                                    theme: dotCell.modelData

                                    Avatar {
                                        text: "YZ"
                                        shape: "square"
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    spacing: 8

                    Text {
                        text: qsTr("type：primary（默认）/ secondary / tertiary / warning / danger / success")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Row {
                        spacing: 40

                        Repeater {
                            model: ["primary", "secondary", "tertiary", "warning", "danger", "success"]

                            delegate: Badge {
                                id: typeBadge

                                required property int index
                                required property var modelData

                                count: 5
                                type: typeBadge.modelData

                                Avatar {
                                    text: "MR"
                                    shape: "square"
                                }
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("配色矩阵全走语义令牌，6 type × 3 theme：`solid` 只改底色（文字恒"
                        + " `--semi-color-bg-2`，所以六枚 solid 的字色其实一模一样白）；`light` 底色"
                        + " `<type>-light-default` + 文字 type 色；`inverted` 只改文字为 type 色、底色留"
                        + " default 的 `bg-1` ⇒ 第三枚 inverted 的圆点是白底白环的隐形点（官方如此，"
                        + "页面把它摆在 fill-0 灰底上才看得出来）。描边恒 `1px bg-1`，与 theme 无关。"
                        + "另外官网正文那句「type 支持 primary、secondary、tertiary、warning 和 danger」"
                        + "漏了 `success`，constants.ts 里是六个。")
                }
            }
        }

        GallerySection {
            title: "独立使用"

            Column {
                width: 700
                spacing: 24

                Row {
                    spacing: 32

                    Badge {
                        count: 5
                    }

                    Badge {
                        count: "NEW"
                        theme: "light"
                    }

                    Badge {
                        count: 99
                        overflowCount: 10
                        type: "danger"
                    }
                }

                Row {
                    spacing: 24

                    Repeater {
                        model: [["primary", "进行中 processing"], ["tertiary", "信息 info"],
                                ["success", "成功 success"], ["warning", "提醒 warning"],
                                ["danger", "错误 error"]]

                        delegate: Row {
                            id: legend

                            required property int index
                            required property var modelData

                            spacing: 8

                            Badge {
                                dot: true
                                type: legend.modelData[0]
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: legend.modelData[1]
                                color: Theme.current.colorText1
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }
                    }
                }

                Note {
                    text: qsTr("没有 `children` 时官方不挂 `-position`、改挂 `-block`"
                        + "（`position: static; display: inline-block`）⇒ 徽标就是一个正常排版的行内块，"
                        + "外层尺寸就是它自己。这一节也是唯一能一眼看出「solid 六枚字色相同」的地方。")
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
