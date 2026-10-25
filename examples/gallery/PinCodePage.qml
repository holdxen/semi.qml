pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/input/pincode/index.md 的 5 个演示小节。
// 「限制验证码格式」一节官方有两个 #### 子标题（设置位数 / 设置字符范围），
// 它们已经并进小节说明文字里（GallerySection 从 docs.json 取），所以 demo 区不重复标题。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方「受控」与「手动聚焦失焦」两节都是 useState('69af41')
    property string ctrlCode: "69af41"
    property string focusCode: "69af41"

    // 官方：String(parseInt(Math.random() * 100000000)).slice(0, 6)
    function randomCode() {
        return String(parseInt(Math.random() * 100000000)).slice(0, 6);
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 420
                text: "import Semi\n\nPinCode { }"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "基本使用"

            Column {
                spacing: 8

                PinCode {
                    size: "small"
                    defaultValue: "123456"
                    onCompleted: (value) => console.log("pincode: ", value)
                    onChanged: (value) => console.log(value)
                }

                PinCode {
                    size: "default"
                    defaultValue: "123456"
                    onCompleted: (value) => console.log("pincode: ", value)
                    onChanged: (value) => console.log(value)
                }

                PinCode {
                    size: "large"
                    defaultValue: "123456"
                    onCompleted: (value) => console.log("pincode: ", value)
                    onChanged: (value) => console.log(value)
                }
            }
        }

        GallerySection {
            title: "受控"

            Column {
                spacing: 12

                Button {
                    text: qsTr("Set Random Value")
                    onClicked: page.ctrlCode = page.randomCode()
                }

                PinCode {
                    format: "mixed"
                    value: page.ctrlCode
                    onCompleted: (value) => console.log("pincode: ", value)
                    onChanged: (v) => {
                        console.log(v);
                        page.ctrlCode = v;
                    }
                }
            }
        }

        GallerySection {
            title: "限制验证码格式"

            Column {
                spacing: 24

                PinCode {
                    size: "large"
                    defaultValue: "6688"
                    count: 4
                    onCompleted: (value) => console.log("pincode: ", value)
                    onChanged: (value) => console.log(value)
                }

                Column {
                    spacing: 8

                    Text {
                        text: qsTr("纯数字")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    PinCode {
                        format: "number"
                        onCompleted: (value) => console.log("pincode: ", value)
                    }

                    Text {
                        text: qsTr("字母和数字")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    PinCode {
                        format: "mixed"
                        onCompleted: (value) => console.log("pincode: ", value)
                    }

                    Text {
                        text: qsTr("只大写字母")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    PinCode {
                        format: /[A-Z]/
                        onCompleted: (value) => console.log("pincode: ", value)
                    }

                    Text {
                        text: qsTr("只小写字母(函数判断)")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    PinCode {
                        format: (c) => /[a-z]/.test(c)
                        onCompleted: (value) => console.log("pincode: ", value)
                    }
                }
            }
        }

        GallerySection {
            title: "手动聚焦失焦"

            Column {
                spacing: 12

                Button {
                    text: qsTr("Focus Third Input")
                    onClicked: focusDemo.focusCell(2)
                }

                PinCode {
                    id: focusDemo

                    format: "mixed"
                    value: page.focusCode
                    onCompleted: (value) => console.log("pincode: ", value)
                    onChanged: (v) => {
                        console.log(v);
                        page.focusCode = v;
                    }
                }
            }
        }
    }
}
