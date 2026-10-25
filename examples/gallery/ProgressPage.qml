pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/feedback/progress/index.md 的 12 个演示小节，标题逐字取自 data/docs.json。
//
// 官方示例里的 style={{ height: '8px' }} / style={{ width: '8px' }} 这类自定义尺寸，
// 本端口对应成直接给控件的 height / width（横条的盒子高度就是轨道高度，竖条同理）；
// style={{ margin: 5 }} 对应成 Row/Column 的 spacing。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ------------------------------------------------------------ 小节内的状态
    property int linePerc: 40            // 动态改变进度（条状）
    property int cirPerc: 40             // 动态改变进度（环形）
    property int colorPerc: 10           // 自定义进度条颜色
    property int gradPerc: 65            // 自动补齐颜色区间：手动那两条
    property int intervalPerc: 0         // 自动补齐颜色区间：自己涨的那两条

    // 「自定义进度条颜色」那节的 strokeArr
    readonly property var colorStrokes: [
        { percent: 20, color: "red" },
        { percent: 40, color: "orange-9" },
        { percent: 60, color: "light-green-8" },
        { percent: 80, color: "hsla(125, 50%, 46% / 1)" }
    ]
    // 「自动补齐颜色区间」那节的两组端点
    readonly property var gradStrokes: [
        { percent: 0, color: "rgb(249, 57, 32)" },
        { percent: 50, color: "#46259E" },
        { percent: 100, color: "hsla(125, 50%, 46% / 1)" }
    ]
    readonly property var gradStrokesReverse: [
        { percent: 0, color: "hsla(125, 50%, 46% / 1)" },
        { percent: 50, color: "#46259E" },
        { percent: 100, color: "rgb(249, 57, 32)" }
    ]

    // 官方：useEffect 里按当前值重算下一次的延时 —— 0 与越过 100 时停 1200ms，
    // 中间是 290 - (p % 50) * 3
    Timer {
        id: intervalTimer

        interval: page.intervalPerc === 0 || page.intervalPerc > 100
            ? 1200 : 290 - (page.intervalPerc % 50) * 3
        running: true
        repeat: true
        onTriggered: {
            page.intervalPerc = page.intervalPerc > 100 ? 0 : page.intervalPerc + 3;
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 460
                text: "import Semi\n\nProgress { width: 200; percent: 40 }\n\nProgress { type: \"circle\"; percent: 60; showInfo: true }"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "标准的进度条"

            Column {
                spacing: 16
                width: 200

                Progress { width: 200; percent: 10; stroke: "var(--semi-color-warning)" }
                Progress { width: 200; percent: 25; stroke: "var(--semi-color-danger)" }
                Progress { width: 200; percent: 50 }
                Progress { width: 200; percent: 80 }
                Progress { width: 200; percent: 80; size: "large" }
                // 官方 style={{ height: '8px' }}：预设尺寸不够用时直接给控件高度
                Progress { width: 200; height: 8; percent: 80 }
            }
        }

        GallerySection {
            title: "不确定状态的进度条"

            Column {
                spacing: 16
                width: 240

                Progress { width: 240; indeterminate: true }
                Progress { width: 240; indeterminate: true; size: "large" }

                Row {
                    spacing: 16

                    Progress { indeterminate: true; type: "circle" }
                    Progress { indeterminate: true; type: "circle"; size: "small" }
                }
            }
        }

        GallerySection {
            title: "展示百分比文本"

            Column {
                spacing: 16
                width: 200

                Progress { width: 200; percent: 10; stroke: "var(--semi-color-warning)"; showInfo: true }
                Progress { width: 200; percent: 25; stroke: "var(--semi-color-danger)"; showInfo: true }
                Progress { width: 200; percent: 50; showInfo: true }
                Progress {
                    width: 200
                    percent: 50
                    showInfo: true
                    format: function (percent) {
                        return percent * 10 + "‰";
                    }
                }
            }
        }

        GallerySection {
            title: "垂直的进度条"

            Row {
                spacing: 12
                height: 100

                Progress { height: 100; percent: 10; direction: "vertical" }
                Progress { height: 100; percent: 25; direction: "vertical" }
                Progress { height: 100; percent: 50; direction: "vertical" }
                Progress { height: 100; percent: 80; direction: "vertical"; size: "large" }
                // 官方 style={{ width: '8px' }}
                Progress { width: 8; height: 100; percent: 80; direction: "vertical" }
            }
        }

        GallerySection {
            title: "环形进度条"

            Column {
                spacing: 12

                Row {
                    spacing: 10

                    Progress { percent: 10; type: "circle" }
                    Progress { percent: 25; type: "circle" }
                    Progress { percent: 50; type: "circle" }
                    Progress { percent: 80; type: "circle" }
                }

                // 官方这一段是 width={100} 的两个环，第二个换了 stroke 颜色
                Row {
                    spacing: 10

                    Progress { percent: 100; type: "circle"; circleWidth: 100 }
                    Progress { percent: 100; type: "circle"; circleWidth: 100; stroke: "#f93920" }
                }
            }
        }

        GallerySection {
            title: "小号的环形进度条"

            Row {
                spacing: 10

                Progress { percent: 10; type: "circle"; size: "small" }
                Progress { percent: 25; type: "circle"; size: "small" }
                Progress { percent: 50; type: "circle"; size: "small" }
                Progress { percent: 80; type: "circle"; size: "small" }
            }
        }

        GallerySection {
            title: "动态改变进度"

            Column {
                spacing: 12

                Progress {
                    width: 200
                    percent: page.linePerc
                    showInfo: true
                }

                Row {
                    spacing: 8

                    Button {
                        icon: "chevron_left"
                        variant: Enums.Light
                        enabled: page.linePerc !== 0
                        onClicked: page.linePerc = page.linePerc - 10
                    }

                    Button {
                        icon: "chevron_right"
                        variant: Enums.Light
                        enabled: page.linePerc < 100
                        onClicked: page.linePerc = page.linePerc + 10
                    }
                }

                Progress {
                    percent: page.cirPerc
                    type: "circle"
                }

                Row {
                    spacing: 8

                    Button {
                        icon: "chevron_left"
                        variant: Enums.Light
                        enabled: page.cirPerc !== 0
                        onClicked: page.cirPerc = page.cirPerc - 10
                    }

                    Button {
                        icon: "chevron_right"
                        variant: Enums.Light
                        enabled: page.cirPerc < 100
                        onClicked: page.cirPerc = page.cirPerc + 10
                    }
                }
            }
        }

        GallerySection {
            title: "自定义中心文字内容"

            Row {
                spacing: 12

                Progress {
                    percent: 75
                    type: "circle"
                    showInfo: true
                    format: function (per) {
                        return per + "Days";
                    }
                }

                Progress {
                    percent: 100
                    type: "circle"
                    showInfo: true
                    format: function () {
                        return "Done";
                    }
                }

                Progress {
                    percent: 50
                    type: "circle"
                    showInfo: false
                }
            }
        }

        GallerySection {
            title: "圆角/方角边缘"

            Row {
                spacing: 12

                Progress { percent: 50; type: "circle"; strokeLinecap: "round" }
                Progress { percent: 50; type: "circle"; strokeLinecap: "square" }
            }
        }

        GallerySection {
            title: "自定义进度条颜色"

            Column {
                spacing: 12

                Progress {
                    percent: page.colorPerc
                    type: "circle"
                    circleWidth: 100
                    stroke: page.colorStrokes
                    showInfo: true
                }

                Progress {
                    width: 200
                    percent: page.colorPerc
                    stroke: page.colorStrokes
                    showInfo: true
                }

                Row {
                    spacing: 8

                    Button {
                        icon: "chevron_left"
                        variant: Enums.Light
                        enabled: page.colorPerc !== 0
                        onClicked: page.colorPerc = page.colorPerc - 10
                    }

                    Button {
                        icon: "chevron_right"
                        variant: Enums.Light
                        enabled: page.colorPerc !== 100
                        onClicked: page.colorPerc = page.colorPerc + 10
                    }
                }
            }
        }

        GallerySection {
            title: "自动补齐颜色区间"

            Column {
                spacing: 12

                Row {
                    spacing: 20

                    Progress {
                        percent: page.intervalPerc
                        type: "circle"
                        circleWidth: 100
                        stroke: page.gradStrokes
                        strokeGradient: true
                        showInfo: true
                    }

                    Progress {
                        percent: page.intervalPerc
                        type: "circle"
                        circleWidth: 100
                        stroke: page.gradStrokesReverse
                        strokeGradient: true
                        showInfo: true
                    }
                }

                Progress {
                    width: 460
                    percent: page.gradPerc
                    stroke: page.gradStrokes
                    strokeGradient: true
                    showInfo: true
                    size: "large"
                }

                Row {
                    spacing: 8

                    Button {
                        icon: "chevron_left"
                        variant: Enums.Light
                        enabled: page.gradPerc !== 0
                        onClicked: page.gradPerc = page.gradPerc - 5
                    }

                    Button {
                        icon: "chevron_right"
                        variant: Enums.Light
                        enabled: page.gradPerc !== 100
                        onClicked: page.gradPerc = page.gradPerc + 5
                    }
                }
            }
        }
    }
}
