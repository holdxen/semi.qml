pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Carousel 轮播图。官方 `content/show/carousel/index.md` 的「代码演示」一共 8 节，
// 加「如何引入」这里一共 9 个小节：基本用法 / 主题切换 / 指示器 / 箭头 / 定制箭头 /
// 播放参数 / 动画效果与切换速度 / 受控的轮播图。
//
// 端口与官方的口径差（完整清单在 src/Carousel.qml、src/CarouselIndicator.qml、
// src/CarouselArrow.qml 文件头）：
//   · 官方每一节都是 `<Carousel style={{ width: '100%', height: '400px' }}>` 起一块 400 高的
//     画布，里面铺三张远端图、左上角叠一组标题。`style` 是死 prop（只喂 DOM）⇒ 端口在调用点
//     自己写宽高；远端图换成色块 + 自己摆坐标的那组标题（离线也要能画，Logo 那张 SVG 不引）。
//   · 官方八节里没有任何一节演示 `slideDirection`（API 表里有这条）⇒ 端口在「动画效果」那节
//     补一个开关，好让 :286 那个三元判别只活在源码里。
//   · 官方的受控那一节没有别的按钮：靠箭头与指示器发 onChange、由使用方回写。端口照搬。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property string themeName: "primary"
    property string indicatorType: "dot"
    property string indicatorPosition: "left"
    property string indicatorSize: "small"
    property string arrowShown: "show"
    property string arrowTiming: "always"
    property string animation: "fade"
    property string slideDirection: "left"
    property int activeIndex: 0

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
                    text: "import { Carousel } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("Carousel 官方一共 18 条：`activeIndex` / `animation` / `arrowProps` /"
                        + " `autoPlay` / `arrowType` / `children` / `className` / `defaultActiveIndex` /"
                        + " `indicatorPosition` / `indicatorSize` / `indicatorType` / `theme` / `onChange` /"
                        + " `showArrow` / `showIndicator` / `slideDirection` / `speed` / `style` / `trigger`，"
                        + "外加五个挂在实例上的方法 `play()` / `stop()` / `goTo(i)` / `prev()` / `next()`。"
                        + "缺省：animation slide、autoPlay true、arrowType always、defaultActiveIndex 0、"
                        + "指示器 center + small + dot、theme light、showArrow / showIndicator true、"
                        + "slideDirection left、speed 300、trigger click。")
                }

                Note {
                    text: qsTr("`children` 就是幻灯片：每一片叠在同一格上、被强制铺满视口，所以别给子项"
                        + "写宽高。切换靠 `changed(index, preIndex)` 通知；给了 `activeIndex` 就转成受控档。"
                        + "官方的 `role='listbox'`、`tabIndex`、左右键切页三处全被注释掉了"
                        + "（index.tsx:272-281、:137-144）⇒ 没有键盘档，端口也不做，只留箭头图标的 "
                        + "aria-label。")
                }
            }
        }

        GallerySection {
            title: "基本用法"

            Column {
                width: 700
                spacing: 12

                Carousel {
                    width: parent.width
                    height: 300
                    theme: "dark"

                    Slide { label: qsTr("Semi 设计管理系统"); tint: "#2F6FEB" }
                    Slide { label: qsTr("Semi 物料市场"); tint: "#1E9E6A" }
                    Slide { label: qsTr("Semi Template"); tint: "#D9822B" }
                }

                Note {
                    text: qsTr("不写任何属性：2000ms 一换（间隔里还含 300ms 的过渡，见「播放参数」）、"
                        + "点状指示器居中、箭头恒显、浅色主题。鼠标停在上面会暂停。")
                }
            }
        }

        GallerySection {
            title: "主题切换"

            Column {
                width: 700
                spacing: 12

                RadioGroup {
                    type: Enums.ChoiceButton
                    options: ["primary", "light", "dark"]
                    value: page.themeName
                    onChanged: (v) => page.themeName = v
                }

                Carousel {
                    width: parent.width
                    height: 300
                    theme: page.themeName
                    autoPlay: false

                    Slide { label: qsTr("从 Semi Design，到 Any Design"); tint: "#2F6FEB" }
                    Slide { label: qsTr("面向业务场景的定制化组件"); tint: "#1E9E6A" }
                    Slide { label: qsTr("高效的 Design2Code"); tint: "#D9822B" }
                }

                Note {
                    text: qsTr("`theme` 管的是指示器与箭头两件的取色，幻灯片内容不受影响。三档基色照 "
                        + "variables.scss：dark 是黑（默认 .5 / 悬浮 .7 / 选中 1），primary 是 "
                        + "`--semi-blue-6`、light 是白（都是 .4 / .7 / 1）—— primary 那档读的是"
                        + "蓝板第 6 级，不是语义主色，改 `colorPrimary` 也不会跟着变。")
                }
            }
        }

        GallerySection {
            title: "指示器"

            Column {
                width: 700
                spacing: 12

                Row {
                    spacing: 24

                    Column {
                        spacing: 6

                        Text {
                            text: qsTr("类型")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        RadioGroup {
                            type: Enums.ChoiceButton
                            options: ["dot", "line", "columnar"]
                            value: page.indicatorType
                            onChanged: (v) => page.indicatorType = v
                        }
                    }

                    Column {
                        spacing: 6

                        Text {
                            text: qsTr("位置")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        RadioGroup {
                            type: Enums.ChoiceButton
                            options: ["left", "center", "right"]
                            value: page.indicatorPosition
                            onChanged: (v) => page.indicatorPosition = v
                        }
                    }

                    Column {
                        spacing: 6

                        Text {
                            text: qsTr("尺寸")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        RadioGroup {
                            type: Enums.ChoiceButton
                            options: ["small", "medium"]
                            value: page.indicatorSize
                            onChanged: (v) => page.indicatorSize = v
                        }
                    }
                }

                Carousel {
                    width: parent.width
                    height: 300
                    theme: "dark"
                    autoPlay: false
                    indicatorType: page.indicatorType
                    indicatorPosition: page.indicatorPosition
                    indicatorSize: page.indicatorSize

                    Slide { label: qsTr("指示器三种形态"); tint: "#2F6FEB" }
                    Slide { label: qsTr("第二屏"); tint: "#1E9E6A" }
                    Slide { label: qsTr("第三屏"); tint: "#D9822B" }
                }

                Note {
                    text: qsTr("尺寸令牌全来自 variables.scss：点 8 / 12 见方、间距 8、圆角 50%；"
                        + "柱宽 4 / 6、高 12→20 / 20→28（选中才变高，而且是往上长，因为容器是 "
                        + "`align-items: flex-end`）、间距 4；条状那档容器写死 240 宽（不跟轮播宽度）、"
                        + "每格 `flex: 1`、高 4 / 6、间距 4。指示器距边一律 32。"
                        + "`trigger` 还有一档 `hover`：划过去就切页（这里是点击才切）。")
                }
            }
        }

        GallerySection {
            title: "箭头"

            Column {
                width: 700
                spacing: 12

                Row {
                    spacing: 24

                    Column {
                        spacing: 6

                        Text {
                            text: qsTr("展示箭头")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        RadioGroup {
                            type: Enums.ChoiceButton
                            options: ["show", "hide"]
                            value: page.arrowShown
                            onChanged: (v) => page.arrowShown = v
                        }
                    }

                    Column {
                        spacing: 6

                        Text {
                            text: qsTr("展示时机")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        RadioGroup {
                            type: Enums.ChoiceButton
                            options: ["always", "hover"]
                            value: page.arrowTiming
                            onChanged: (v) => page.arrowTiming = v
                        }
                    }
                }

                Carousel {
                    width: parent.width
                    height: 300
                    theme: "dark"
                    autoPlay: false
                    showArrow: page.arrowShown === "show"
                    arrowType: page.arrowTiming

                    Slide { label: qsTr("左右各点一下"); tint: "#7A5AF8" }
                    Slide { label: qsTr("第二屏"); tint: "#0E8F8F" }
                }

                Note {
                    text: qsTr("`arrowType: 'hover'` 那档靠的是 `.carousel:hover .-arrow-hover div` ⇒ "
                        + "悬浮整块轮播才显形，不是悬浮箭头自己。箭头 32 见方、距边 20、垂直居中，"
                        + "配色只有两档（默认 .4 / dark .5，悬浮一律 1，没有指示器那档 .7）。")
                }
            }
        }

        GallerySection {
            title: "定制箭头"

            Column {
                width: 700
                spacing: 12

                Carousel {
                    width: parent.width
                    height: 300
                    theme: "dark"
                    autoPlay: false
                    arrowProps: ({
                        leftArrow: { children: "arrow_left" },
                        rightArrow: { children: "arrow_right" }
                    })

                    Slide { label: qsTr("换掉箭头图标"); tint: "#2F6FEB" }
                    Slide { label: qsTr("第二屏"); tint: "#1E9E6A" }
                }

                Note {
                    text: qsTr("官方这一节给的是 `arrowProps={{ leftArrow: { children: <IconArrowLeft size='large'/> } }}`。"
                        + "那个键叫 `children`（ReactNode），端口收两档：字符串 = 图标名、"
                        + "`Component` = 任意节点（此时那一格改成跟着节点尺寸走）。"
                        + "另一半 `props`（原样摊到那格 div 上的 style / onClick）在端口是死的 —— "
                        + "点击一律走 TapHandler。")
                }
            }
        }

        GallerySection {
            title: "播放参数"

            Column {
                width: 700
                spacing: 12

                Carousel {
                    width: parent.width
                    height: 300
                    theme: "dark"
                    autoPlay: ({ interval: 1500, hoverToPause: true })

                    Slide { label: qsTr("1500ms 一换"); tint: "#2F6FEB" }
                    Slide { label: qsTr("悬停会暂停"); tint: "#1E9E6A" }
                    Slide { label: qsTr("离开再续播"); tint: "#D9822B" }
                }

                Note {
                    text: qsTr("`autoPlay` 是 `true | false | { interval, hoverToPause }` 三象，"
                        + "没有独立的 interval 属性。下一次切换的等待 = `interval + speed`"
                        + "（过渡时长也算进间隔），鼠标进出各延迟 400ms（官方那条是 lodash "
                        + "`debounce(fn, 400)`）。`hoverToPause` 只有对象档能关：`{ interval: 1500 }` "
                        + "里它是 undefined ⇒ 不暂停。手动点箭头 / 指示器也各有讲究：`next()` / `prev()` "
                        + "会先把计时停掉再按门重启，而 `goTo()` 与点指示器不重启计时器（上游就是这么写的）。")
                }
            }
        }

        GallerySection {
            title: "动画效果与切换速度"

            Column {
                width: 700
                spacing: 12

                Row {
                    spacing: 24

                    Column {
                        spacing: 6

                        Text {
                            text: qsTr("切换动画")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        RadioGroup {
                            type: Enums.ChoiceButton
                            options: ["slide", "fade"]
                            value: page.animation
                            onChanged: (v) => page.animation = v
                        }
                    }

                    Column {
                        spacing: 6

                        Text {
                            text: qsTr("滑动方向")
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                        }

                        RadioGroup {
                            type: Enums.ChoiceButton
                            options: ["left", "right"]
                            value: page.slideDirection
                            onChanged: (v) => page.slideDirection = v
                        }
                    }
                }

                Carousel {
                    width: parent.width
                    height: 300
                    theme: "dark"
                    autoPlay: false
                    animation: page.animation
                    slideDirection: page.slideDirection
                    speed: 1000

                    Slide { label: qsTr("speed = 1000"); tint: "#2F6FEB" }
                    Slide { label: qsTr("第二屏"); tint: "#1E9E6A" }
                    Slide { label: qsTr("第三屏"); tint: "#D9822B" }
                }

                Note {
                    text: qsTr("官方这一节只摆了 `animation='fade' speed={1000}` 一台，"
                        + "`slideDirection` 在 API 表里有、八节 demo 里一次都没用 ⇒ 这里补了开关。"
                        + "slide 档不是轨道平移：非当前那几片全被 `visibility: hidden` 挡住，"
                        + "只有「进来的那片」做 ±100% 的位移；而「出去的那片」挂的 `-slide-out` "
                        + "没有把 visibility 恢复回来 ⇒ 整段动画其实看不见。fade 档才是新旧两片交叉淡入淡出。"
                        + "首屏那一次切换（`isInit` 还是真）不挂 slide-in。")
                }
            }
        }

        GallerySection {
            title: "受控的轮播图"

            Column {
                width: 700
                spacing: 12

                Carousel {
                    width: parent.width
                    height: 300
                    theme: "dark"
                    activeIndex: page.activeIndex
                    autoPlay: false

                    onChanged: (index, preIndex) => page.activeIndex = index

                    Slide { label: qsTr("第 1 屏（受控）"); tint: "#2F6FEB" }
                    Slide { label: qsTr("第 2 屏"); tint: "#1E9E6A" }
                    Slide { label: qsTr("第 3 屏"); tint: "#D9822B" }
                }

                Text {
                    text: qsTr("当前 activeIndex = %1 —— 点箭头或指示器才会变".arg(page.activeIndex))
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("给了 `activeIndex` 就是受控档：点箭头 / 点指示器 / 调 `next()` 都只发 "
                        + "`changed`、不改内部状态，必须像上面那样回写才会切页；挂载与鼠标离开那两处"
                        + "也不会起播。另外两个小差异：受控时由使用方改 `activeIndex` 那一次不走 "
                        + "`_notifyChange` ⇒ `isInit` 仍为真 ⇒ 首切不带动画；而 `next()` 调的是 "
                        + "foundation 那份没有受控门的 handleAutoPlay ⇒ 手动切一次仍会把计时起起来，"
                        + "之后每次到点只空发一条 onChange、视图不动（上游就是这个行为，端口照抄）。")
                }
            }
        }
    }

    // 官方每一片的正文：左上角 100/100 处一组标题（远端 Logo 不引，只留文字）
    component Slide: Rectangle {
        id: slide

        property string label: ""
        property color tint: Theme.current.colorPrimary

        color: tint

        Column {
            x: 100
            y: 100
            spacing: 8

            Text {
                text: slide.label
                color: "#1C1F23"
                font.pixelSize: 28
                font.weight: Font.Bold
            }

            Text {
                text: qsTr("从 Semi Design，到 Any Design")
                color: "#1C1F23"
                font.pixelSize: Theme.current.fontSizeRegular
            }

            Text {
                text: qsTr("快速定制你的设计系统，并应用在设计稿和代码中")
                color: "#1C1F23"
                font.pixelSize: Theme.current.fontSizeSmall
            }
        }
    }

    // 说明里有 `{ interval }`、`.slide-out` 这类花括号与尖括号 ⇒ 钉 PlainText
    component Note: Text {
        width: 700
        textFormat: Text.PlainText
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
