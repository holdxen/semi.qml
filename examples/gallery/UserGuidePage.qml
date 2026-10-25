pragma ComponentBehavior: Bound

import QtQuick
import Semi

// UserGuide 用户引导。八节一一对应 content/show/userGuide/index.md 的官方 demo。
//
// 官方每节都是「一颗开始引导的键 + 三个高亮目标 + 一段 UserGuide」，visible 握在调用方手里，
// 组件自己从不关 —— 所以这里每个开关都是页面属性，onFinish / onSkip 里才置回 false。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property bool basicOpen: false
    property bool themeOpen: false
    property bool positionOpen: false
    property bool paddingOpen: false
    property bool customOpen: false
    property bool controlledOpen: false
    property bool modalOpen: false
    property bool noMaskOpen: false
    property int controlledStep: 0
    property string lastEvent: ""

    component Note: Text {
        width: 640
        wrapMode: Text.WordWrap
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
    }

    // 官方那三枚高亮目标：Switch / Tag / Button，Space 里竖向居中
    component Targets: Space {
        Switch {
            id: targetSwitch

            anchors.verticalCenter: parent.verticalCenter
            checked: true
        }

        Tag {
            id: targetTag

            anchors.verticalCenter: parent.verticalCenter
            text: "Default Tag"
        }

        Button {
            id: targetButton

            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("确定")
        }

        // 三个目标交给外面的 steps 引用
        readonly property alias switchItem: targetSwitch
        readonly property alias tagItem: targetTag
        readonly property alias buttonItem: targetButton
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本用法"

            Column {
                width: 640
                spacing: 16

                Button {
                    text: qsTr("开始引导")
                    onClicked: page.basicOpen = true
                }

                Targets {
                    id: basicTargets
                }

                Text {
                    text: page.lastEvent === "" ? qsTr("最近一次：（还没走过）")
                        : qsTr("最近一次：%1").arg(page.lastEvent)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }

            UserGuide {
                visible: page.basicOpen
                steps: [
                    {
                        title: "新手引导",
                        description: "Hello ByteDancer!",
                        target: basicTargets.switchItem,
                        position: Enums.Bottom
                    },
                    {
                        title: "Switch",
                        description: "This is a Semi Switch",
                        target: basicTargets.tagItem,
                        position: Enums.Bottom
                    },
                    {
                        title: "Button",
                        description: "This is a Semi Button",
                        target: basicTargets.buttonItem,
                        position: Enums.Bottom
                    }
                ]
                onChanged: function (current) {
                    page.lastEvent = qsTr("change：第 %1 步").arg(current + 1)
                }
                onNext: function (current) {
                    page.lastEvent = qsTr("next：第 %1 步").arg(current + 1)
                }
                onPrev: function (current) {
                    page.lastEvent = qsTr("prev：第 %1 步").arg(current + 1)
                }
                onFinished: {
                    page.basicOpen = false;
                    page.lastEvent = qsTr("finish：引导完成");
                }
                onSkipped: {
                    page.basicOpen = false;
                    page.lastEvent = qsTr("skip：跳过引导");
                }
            }

            Note {
                text: qsTr("steps 每项给 target / title / description / position：target 是要挖空高亮的控件，"
                    + "卡片上的「1/3」是步数指示器。官方这四个回调只往控制台打字，这里落到上面那一行。")
            }
        }

        GallerySection {
            title: "主题"

            Column {
                width: 640
                spacing: 16

                Button {
                    text: qsTr("开始引导")
                    onClicked: page.themeOpen = true
                }

                Targets {
                    id: themeTargets
                }
            }

            UserGuide {
                visible: page.themeOpen
                theme: "primary"
                steps: [
                    {
                        title: "新手引导",
                        description: "Hello ByteDancer!",
                        target: themeTargets.switchItem
                    },
                    {
                        title: "Switch",
                        description: "This is a Semi Switch",
                        target: themeTargets.tagItem
                    },
                    {
                        title: "Button",
                        description: "This is a Semi Button",
                        target: themeTargets.buttonItem
                    }
                ]
                onFinished: page.themeOpen = false
                onSkipped: page.themeOpen = false
            }

            Note {
                text: qsTr("primary 那一档就是往 Popover 上盖一层 primary 底色：文字换成 tertiary-light-default，"
                    + "跳过 / 上一步两颗的底色压成 fill-2，下一步那颗变成白底 + primary 字的 borderless。"
                    + "单个步骤想换主题，就给那一步写 theme: 'primary'。")
            }
        }

        GallerySection {
            title: "气泡卡片弹出位置"

            Column {
                width: 640
                spacing: 16

                // 目标往右让一让：卡片宽 317~400，贴着左边放的话上方那一档
                // 横向也放不下，弹层的「两边都放不下就保持原方位」规则会把卡片裁出窗口
                Row {
                    Item {
                        width: 180
                        height: 1
                    }

                    Button {
                        id: positionTarget
                        text: qsTr("开始引导")
                        onClicked: page.positionOpen = true
                    }
                }
            }

            UserGuide {
                visible: page.positionOpen
                steps: [
                    {
                        title: "新手引导",
                        description: "Hello ByteDancer!",
                        target: positionTarget,
                        position: Enums.Top
                    },
                    {
                        title: "New Position",
                        description: "This is Right Position",
                        target: positionTarget,
                        position: Enums.Right
                    },
                    {
                        title: "Hide Arrow",
                        description: "We hide the arrow",
                        target: positionTarget,
                        position: Enums.Bottom,
                        showArrow: false
                    }
                ]
                onFinished: page.positionOpen = false
                onSkipped: page.positionOpen = false
            }

            Note {
                text: qsTr("position 收 Enums.Placement 那 12 档，与官方字符串一一对应；"
                    + "放不下时按 Semi 的 autoAdjustOverflow 翻到对面、并且永远不盖住高亮区。"
                    + "showArrow 是逐步的属性，只有气泡模式有意义。这一节三步共用一颗键当目标，"
                    + "官方 demo 就是这么写的。")
            }
        }

        GallerySection {
            title: "设置高亮区域大小"

            Column {
                width: 640
                spacing: 16

                Button {
                    text: qsTr("开始引导")
                    onClicked: page.paddingOpen = true
                }

                Targets {
                    id: paddingTargets
                }
            }

            UserGuide {
                visible: page.paddingOpen
                spotlightPadding: 10
                steps: [
                    {
                        title: "新手引导",
                        description: "Hello ByteDancer!",
                        target: paddingTargets.switchItem
                    },
                    {
                        title: "New Padding",
                        description: "This is 10px padding",
                        target: paddingTargets.tagItem
                    },
                    {
                        title: "Change Padding",
                        description: "We change the Padding to 15px",
                        target: paddingTargets.buttonItem,
                        spotlightPadding: 15
                    }
                ]
                onFinished: page.paddingOpen = false
                onSkipped: page.paddingOpen = false
            }

            Note {
                text: qsTr("挖空矩形 = 目标矩形外扩 padding，取序是单步 spotlightPadding → 全局 → 5。"
                    + "官方那两处用的是 `||` 取值，给 0 会被吞成 5；这里按实现里那个没人调用的 "
                    + "getFinalPaading 的意图，0 就是 0。")
            }
        }

        GallerySection {
            title: "定制按钮"

            Column {
                width: 640
                spacing: 16

                Button {
                    text: qsTr("开始引导")
                    onClicked: page.customOpen = true
                }

                Targets {
                    id: customTargets
                }
            }

            UserGuide {
                visible: page.customOpen
                nextButtonText: "Next"
                prevButtonText: "Prev"
                prevButtonVariant: Enums.Borderless
                finishText: "我知道啦！"
                steps: [
                    {
                        title: "新手引导",
                        description: "Hello ByteDancer!",
                        target: customTargets.switchItem
                    },
                    {
                        title: "New Button Style",
                        description: "Button text is Next",
                        target: customTargets.tagItem
                    },
                    {
                        title: "New finish button text",
                        description: "Button text is I know",
                        target: customTargets.buttonItem
                    }
                ]
                onFinished: page.customOpen = false
                onSkipped: page.customOpen = false
            }

            Note {
                text: qsTr("官方收的是 nextButtonProps / prevButtonProps 两个 ButtonProps 对象，"
                    + "这里摊平成 *Text / *Variant / *Tone 六个属性（demo 真正用到的就 children 和 theme），"
                    + "其余参数摸 nextButton / prevButton / skipButton 三个只读引用自己设。")
            }
        }

        GallerySection {
            title: "受控"

            Column {
                width: 640
                spacing: 16

                Button {
                    text: qsTr("开始引导")
                    onClicked: {
                        page.controlledStep = 0;
                        page.controlledOpen = true;
                    }
                }

                Targets {
                    id: controlledTargets
                }

                Text {
                    text: qsTr("外部记到的 current：%1").arg(page.controlledStep)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }

            UserGuide {
                visible: page.controlledOpen
                current: page.controlledStep
                steps: [
                    {
                        title: "新手引导",
                        description: "Hello ByteDancer!",
                        target: controlledTargets.switchItem
                    },
                    {
                        title: "Switch",
                        description: "This is a Semi Switch",
                        target: controlledTargets.tagItem
                    },
                    {
                        title: "Button",
                        description: "This is a Semi Button",
                        target: controlledTargets.buttonItem
                    }
                ]
                onChanged: function (current) {
                    page.controlledStep = current
                }
                onFinished: {
                    page.controlledOpen = false;
                    page.controlledStep = 0;
                }
                onSkipped: {
                    page.controlledOpen = false;
                    page.controlledStep = 0;
                }
            }

            Note {
                text: qsTr("给了 current 就是受控：上一步 / 下一步只发通知，不自改步数，"
                    + "步数由 onChanged 写回页面属性。不写 current 时组件自己维护内部步数，"
                    + "重新打开归零。")
            }
        }

        GallerySection {
            title: "弹窗式引导"

            Column {
                width: 640
                spacing: 16

                Button {
                    text: qsTr("开始引导")
                    onClicked: page.modalOpen = true
                }
            }

            UserGuide {
                visible: page.modalOpen
                mode: "modal"
                steps: [
                    {
                        title: "欢迎使用 Semi DSM!",
                        description: "你可以从已发布的主题出发，或者选择立即创造来创造一个新的主题",
                        cover: page.coverOne
                    },
                    {
                        title: "高可用的色盘",
                        description: "选取主色后，我们的颜色算法会为你生成一套高可用的色盘",
                        cover: page.coverTwo
                    },
                    {
                        title: "自由定制",
                        description: "开始定制属于你的设计系统吧！",
                        cover: page.coverThree
                    }
                ]
                onFinished: page.modalOpen = false
                onSkipped: page.modalOpen = false
            }

            Note {
                text: qsTr("modal 那一支的外壳是 Modal（宽 600、内边距 0、居中、点蒙层不关），"
                    + "三步的 cover 官方是三张远程 PNG，离线环境换成本仓库的样例图。"
                    + "圆点指示器只有带 cover 的步骤才出现，弹窗模式也不挖洞、不读 target 和 position。")
            }
        }

        GallerySection {
            title: "无遮罩"

            Column {
                width: 640
                spacing: 16

                Button {
                    id: noMaskTarget
                    text: qsTr("开始引导")
                    onClicked: page.noMaskOpen = true
                }
            }

            UserGuide {
                visible: page.noMaskOpen
                mask: false
                steps: [
                    {
                        title: "No Mask",
                        description: "Hello ByteDancer!",
                        target: noMaskTarget
                    }
                ]
                onFinished: page.noMaskOpen = false
                onSkipped: page.noMaskOpen = false
            }

            Note {
                text: qsTr("mask 假 ⇒ 官方连那四块 pointer-events:auto 的透明拦截块一起不渲染，"
                    + "所以页面照旧能点，只剩一张卡片浮在上面。")
            }
        }
    }

    readonly property Component coverOne: Component {
        Image {
            fillMode: Image.PreserveAspectCrop
            source: "qrc:/qt/qml/SemiGallery/data/img/sample1.png"
        }
    }

    readonly property Component coverTwo: Component {
        Image {
            fillMode: Image.PreserveAspectCrop
            source: "qrc:/qt/qml/SemiGallery/data/img/sample2.png"
        }
    }

    readonly property Component coverThree: Component {
        Image {
            fillMode: Image.PreserveAspectCrop
            source: "qrc:/qt/qml/SemiGallery/data/img/sample3.png"
        }
    }
}
