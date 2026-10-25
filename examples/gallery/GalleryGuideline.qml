pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 页尾章节：Accessibility / 文案规范 / FAQ。
//
// 内容由 parse-docs.py 从官网 markdown 的对应章节解析而来，每项是
// { kind, indent, text }：kind 为 heading / text，indent 是列表层级。
// 内嵌 React JSX 的对比表格在解析阶段就丢掉了，这里只管排版。
Item {
    id: control

    property string title: ""
    property var items: []

    width: parent ? parent.width : 0
    implicitHeight: body.height + 40

    Column {
        id: body

        width: parent.width
        spacing: 12

        // 页尾章节在官网是 ## 级，比小节（###）高一级，配一条分隔线
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.current.colorBorder
        }

        Text {
            topPadding: 12
            width: parent.width
            text: control.title
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeHeader4
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Column {
            width: parent.width
            spacing: 8

            Repeater {
                model: control.items

                delegate: Text {
                    id: line

                    required property var modelData

                    readonly property bool isHeading: line.modelData.kind === "heading"

                    // 缩进按解析出来的层级走，列表的从属关系才看得出来。
                    // 宽度直接取 control 的：delegate 在销毁时 parent 可能已经是 null，
                    // 写 parent.width 会刷 TypeError
                    leftPadding: line.modelData.indent * 16
                    width: control.width - line.leftPadding
                    topPadding: line.isHeading ? 6 : 0
                    text: line.modelData.text
                    color: line.isHeading
                        ? Theme.current.colorText1 : Theme.current.colorText2
                    font.pixelSize: line.isHeading
                        ? Theme.current.fontSizeRegular : Theme.current.fontSizeSmall
                    font.weight: line.isHeading ? Font.DemiBold : Font.Normal
                    lineHeight: line.isHeading ? 20 : 22
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
