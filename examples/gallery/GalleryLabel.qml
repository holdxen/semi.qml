import QtQuick
import Semi

// 官方 demo 里的 <label>：控件上方一行说明文字，跟着正文色与正文字号。
Text {
    color: Theme.current.colorText1
    font.pixelSize: Theme.current.fontSizeRegular
    wrapMode: Text.WordWrap
}
