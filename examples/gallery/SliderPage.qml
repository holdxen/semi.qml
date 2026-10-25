pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property real controlled: 40

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本用法"

            Column {
                spacing: 26
                width: 480

                Slider { width: 480; value: 30 }

                // 双滑块：range 打开后读 values（两个值，顺序无所谓）
                Slider { width: 480; range: true; values: [20, 60] }

                // 禁用走继承来的 enabled（QML 的 Item 本来就有，本库不再另设 disabled）
                Slider { width: 480; value: 50; enabled: false }
            }
        }

        GallerySection {
            title: "带输入框的"

            Row {
                spacing: 16

                Slider {
                    id: sliderWithInput

                    anchors.verticalCenter: parent.verticalCenter
                    width: 380
                    value: 40
                }

                InputNumber {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    value: sliderWithInput.value
                    onNumberChange: (v) => sliderWithInput.value = v
                }
            }

            Text {
                width: 520
                text: qsTr("滑块和数字框互相绑定 —— 拖滑块数字跟着走，改数字滑块也动。")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        GallerySection {
            title: "自定义提示"

            Column {
                spacing: 26
                width: 480

                Slider {
                    width: 480
                    value: 45
                    showValue: true
                    tipFormatter: function (v) { return v.toFixed(0) + "%" }
                }

                Slider {
                    width: 480
                    value: 60
                    tipFormatter: function (v) { return "音量 " + v.toFixed(0) }
                }
            }

            Text {
                width: 560
                text: qsTr("tipFormatter 是一个 function(value)，给了它就用它的返回值当提示文字。"
                    + "显示时机照 Semi：showValue 常显；没开 showValue 但给了 tipFormatter 时，"
                    + "只在拖动中跟着被拖的那个手柄显示。")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        GallerySection {
            title: "带标签的"

            Column {
                spacing: 34
                width: 480

                Slider {
                    width: 480
                    value: 40
                    step: 10
                    marks: [
                        { value: 0, label: "0" }, { value: 20, label: "20" },
                        { value: 40, label: "40" }, { value: 60, label: "60" },
                        { value: 80, label: "80" }, { value: 100, label: "100" }
                    ]
                }

                Slider {
                    width: 480
                    value: 60
                    step: 10
                    marks: [
                        { value: 0, label: "0°C" }, { value: 50, label: "50°C" },
                        { value: 100, label: "100°C" }
                    ]
                }
            }

            Text {
                width: 560
                text: qsTr("marks 传 [{ value, label }]，落在 [min, max] 之外的会被忽略；"
                    + "不写 label 就直接显示值。刻度点骑在轨道中线上，"
                    + "showMarkLabel 关掉就只留点、不留文字。")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        GallerySection {
            title: "分段背景"

            Slider {
                id: segmentSlider

                width: 480
                range: true
                values: [20, 60]
                // 中段不着色，底色自己画
                included: false

                // 三段底色。用 railContent 画**实色块**，不要用绑定的渐变：
                // GradientStop 的 position 每帧变会让渐变材质每帧重建，
                // 实测那一帧会超时（最长帧 22.6ms → 34.2ms），拖动时看着就是
                // 「背景在刷新、有点慢」。Semi 那边只能用 linear-gradient，
                // QML 直接画三块更省。
                railContent: [
                    Rectangle {
                        x: 0
                        width: Math.max(0, segmentSlider.axisPosOf(segmentSlider.lowValue)
                                        - segmentSlider.railStart)
                        height: parent.height
                        color: Theme.current.colorDanger
                    },
                    Rectangle {
                        x: segmentSlider.axisPosOf(segmentSlider.lowValue) - segmentSlider.railStart
                        width: Math.max(0, segmentSlider.axisPosOf(segmentSlider.highValue)
                                        - segmentSlider.axisPosOf(segmentSlider.lowValue))
                        height: parent.height
                        color: Theme.current.colorFill0
                    },
                    Rectangle {
                        x: segmentSlider.axisPosOf(segmentSlider.highValue) - segmentSlider.railStart
                        width: Math.max(0, parent.width - x)
                        height: parent.height
                        color: Theme.current.colorSuccess
                    }
                ]
            }

            Text {
                width: 560
                text: qsTr("官网这一节用 railStyle 配 linear-gradient 做动态分段 —— CSS 里只有这一条路。"
                    + "QML 侧用 railContent 在轨道上直接画三块实色：几何跟着手柄走，"
                    + "比每帧重建渐变材质省得多。要静态渐变的话也可以用 railGradient。")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        GallerySection {
            title: "受控组件"

            Column {
                spacing: 12
                width: 480

                Slider {
                    id: controlledSlider

                    width: 480
                    value: page.controlled
                    // 拖动时组件自己写过 value，绑定已经没了 —— 回调里装回去，
                    // 否则下面两个「设为」按钮拖一次就再也不生效（同 SwitchPage 受控小节）
                    onMoved: (value) => {
                        page.controlled = value;
                        controlledSlider.value = Qt.binding(function () { return page.controlled; });
                    }
                }

                Space {
                    space: 8

                    Button {
                        text: qsTr("设为 20")
                        variant: Enums.Light
                        onClicked: page.controlled = 20
                    }

                    Button {
                        text: qsTr("设为 80")
                        variant: Enums.Light
                        onClicked: page.controlled = 80
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("当前 %1").arg(page.controlled)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }
                }
            }
        }

        GallerySection {
            title: "垂直"

            Row {
                spacing: 64

                Column {
                    spacing: 10

                    Text {
                        text: qsTr("默认（上小下大）")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Slider { width: 24; height: 160; vertical: true; value: 30 }
                }

                Column {
                    spacing: 10

                    Text {
                        text: qsTr("verticalReverse（上大下小）")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Slider {
                        width: 24
                        height: 160
                        vertical: true
                        verticalReverse: true
                        value: 30
                    }
                }

                Column {
                    spacing: 10

                    Text {
                        text: qsTr("垂直 + 刻度")
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                    }

                    Slider {
                        width: 76
                        height: 160
                        vertical: true
                        value: 60
                        step: 20
                        marks: [
                            { value: 0, label: "0" },
                            { value: 50, label: "50" },
                            { value: 100, label: "100" }
                        ]
                    }
                }
            }
        }

        GallerySection {
            title: "滑块带圆点"

            Row {
                spacing: 24

                Slider { width: 220; value: 60; handleDot: ({ size: 6 }) }

                Slider {
                    width: 220
                    range: true
                    values: [30, 70]
                    handleDot: ({ size: 6 })
                }
            }

            Text {
                width: 520
                text: qsTr("handleDot 给 ({ color, size }) 就在手柄中心画个圆点；"
                    + "双滑块可以传数组 [{ … }, { … }] 分别指定。")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }
}
