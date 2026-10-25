pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/input/inputnumber/index.md 的 7 个演示小节。
// 每个演示里输入框的宽度照抄官方 demo 的 style={{ width: N }}；官方没给宽度的
// 那几个走 InputNumber 的自然宽（inline-flex 由内容撑开）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    property string pureNumberLog: ""

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本输入框"

            Column {
                spacing: 16

                // 官方这里是两个并列的 demo 块，各自 div width:280
                Column {
                    spacing: 12

                    GalleryLabel { text: qsTr("简单数字输入框") }
                    InputNumber { width: 280 }

                    GalleryLabel { text: qsTr("设置了步长 step=2") }
                    InputNumber { width: 280; step: 2 }

                    GalleryLabel {
                        text: qsTr("设置 shiftStep=100，按住 shift 同时点击按钮，可以一次增加/减少100")
                    }
                    InputNumber { width: 280; shiftStep: 100 }

                    GalleryLabel { text: qsTr("设置了上下界 min=1,max=10") }
                    InputNumber { width: 280; min: 1; max: 10; defaultValue: 1 }
                }

                Column {
                    spacing: 12

                    GalleryLabel { text: qsTr("设置了默认值 defaultValue=1") }
                    InputNumber { width: 280; defaultValue: 1 }

                    GalleryLabel { text: qsTr("禁用 disabled=true") }
                    InputNumber { width: 280; defaultValue: 2; enabled: false }

                    GalleryLabel { text: qsTr("设置了小数位数 precision=2") }
                    InputNumber { width: 280; precision: 2; defaultValue: 1.234 }

                    GalleryLabel { text: qsTr("设置了 innerButtons=true") }
                    InputNumber {
                        width: 190
                        innerButtons: true
                        suffix: "小时"
                        defaultValue: 1
                    }
                }
            }
        }

        GallerySection {
            title: "隐藏步进器"

            Column {
                spacing: 12

                GalleryLabel { text: qsTr("innerButtons：步进器收进输入框内，仅悬浮时出现") }
                InputNumber {
                    width: 190
                    innerButtons: true
                }

                GalleryLabel { text: qsTr("hideButtons：彻底隐藏步进器") }
                InputNumber {
                    width: 190
                    hideButtons: true
                }
            }
        }

        GallerySection {
            title: "尺寸"

            Column {
                spacing: 12

                GalleryLabel { text: qsTr("默认尺寸 size=default") }
                InputNumber { width: 180 }

                GalleryLabel { text: qsTr("大尺寸 size=large") }
                InputNumber { width: 180; size: Enums.Large }

                GalleryLabel { text: qsTr("小尺寸 size=small") }
                InputNumber { width: 180; size: Enums.Small }
            }
        }

        GallerySection {
            title: "自定义显示格式与解析方式"

            Column {
                spacing: 12

                GalleryLabel { text: qsTr("人民币") }
                InputNumber {
                    width: 180
                    defaultValue: 1000
                    min: 0
                    formatter: function (v) {
                        return "￥ " + String(v).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
                    }
                    parser: function (v) {
                        return String(v).replace(/￥\s?|(,*)/g, "");
                    }
                }

                GalleryLabel { text: qsTr("自定义串") }
                InputNumber {
                    width: 180
                    defaultValue: 1111
                    formatter: function (v) {
                        return String(v).split("").join("-");
                    }
                    parser: function (v) {
                        return String(v).replace(/-/g, "");
                    }
                }
            }
        }

        GallerySection {
            title: "纯数字输入框"

            Column {
                spacing: 12

                GalleryLabel { text: qsTr("formatter 去掉所有非数字字符，onNumberChange 只收合法数字") }
                InputNumber {
                    min: 0
                    max: Number.MAX_SAFE_INTEGER
                    formatter: function (v) {
                        return String(v).replace(/\D/g, "");
                    }
                    onNumberChange: (v) => page.pureNumberLog = String(v)
                }

                Text {
                    text: qsTr("onNumberChange：%1").arg(page.pureNumberLog === "" ? "（空）" : page.pureNumberLog)
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "货币展示"

            Column {
                spacing: 12

                GalleryLabel { text: qsTr("手动传 localeCode 和 currency 指定币种（官方的 LocaleProvider 演示需要 i18n 上下文，本库没有）") }
                Column {
                    spacing: 12

                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇨🇳 人民币") }
                        InputNumber {
                            localeCode: "zh-CN"
                            currency: "CNY"
                            defaultValue: 123456.78
                        }
                    }

                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇪🇺 欧元") }
                        InputNumber {
                            localeCode: "de-DE"
                            currency: "EUR"
                            defaultValue: 123456.78
                        }
                    }

                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇯🇵 日元") }
                        InputNumber {
                            localeCode: "ja-JP"
                            currency: "JPY"
                            defaultValue: 123456.78
                        }
                    }

                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇻🇳 越南盾") }
                        InputNumber {
                            localeCode: "vi-VN"
                            currency: "VND"
                            defaultValue: 123456.78
                        }
                    }
                }

                GalleryLabel { text: qsTr("currencyDisplay：symbol / code / name") }
                Column {
                    spacing: 12
                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇨🇳 CNY ➕ code") }
                        InputNumber {
                            currency: "CNY"
                            currencyDisplay: "code"
                            defaultValue: 123456.78
                        }
                    }
                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇨🇳 CNY ➕ symbol") }
                        InputNumber {
                            currency: "CNY"
                            currencyDisplay: "symbol"
                            defaultValue: 123456.78
                        }
                    }
                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇨🇳 CNY ➕ name") }
                        InputNumber {
                            currency: "CNY"
                            currencyDisplay: "name"
                            defaultValue: 123456.78
                        }
                    }
                }

                GalleryLabel { text: qsTr("showCurrencySymbol=false，改用前后缀展示币种") }
                Column {
                    spacing: 12
                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇨🇳 CNY ➕ code") }
                        InputNumber {
                            width: 200
                            currency: "CNY"
                            prefix: "CNY"
                            showCurrencySymbol: false
                            defaultValue: 123456.78
                        }
                    }
                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇨🇳 CNY ➕ symbol") }
                        InputNumber {
                            width: 200
                            currency: "CNY"
                            prefix: "￥"
                            showCurrencySymbol: false
                            defaultValue: 123456.78
                        }
                    }
                    Column {
                        spacing: 4
                        GalleryLabel { text: qsTr("🇨🇳 CNY ➕ name") }
                        InputNumber {
                            width: 200
                            currency: "CNY"
                            suffix: "人民币"
                            showCurrencySymbol: false
                            defaultValue: 123456.78
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "科学计数法显示"

            Column {
                spacing: 12

                GalleryLabel { text: qsTr("启用科学计数法（默认阈值 15 位）") }
                InputNumber {
                    width: 280
                    scientificNotation: true
                    defaultValue: 123456789012345
                }

                GalleryLabel { text: qsTr("自定义阈值（10 位）") }
                InputNumber {
                    width: 280
                    scientificNotation: ({ threshold: 10 })
                    defaultValue: 1234567890
                }

                GalleryLabel { text: qsTr("超大数字") }
                InputNumber {
                    width: 280
                    scientificNotation: true
                    defaultValue: 9999999999999999
                }

                GalleryLabel { text: qsTr("小数场景") }
                InputNumber {
                    width: 280
                    scientificNotation: true
                    precision: 10
                    defaultValue: 0.000000123456789
                }
            }
        }
    }
}
