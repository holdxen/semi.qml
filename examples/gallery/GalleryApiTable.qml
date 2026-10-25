pragma ComponentBehavior: Bound

import QtQuick
import Semi

// API 参考表。数据来自 docs.json 的 api 数组 —— 那一栏由 scripts/gen-api-tables.py 从
// src/<Type>.qml 直接抽（属性名 / QML 类型 / 缺省值 / 信号），说明列写在 scripts/api-notes.json。
//
// 也就是说这张表讲的是**本库 QML 侧的属性面**，不是官网那版 React props。
Item {
    id: control

    property var component: null

    readonly property var rows: control.component !== null
        && control.component.api !== undefined ? control.component.api : []

    visible: control.rows.length > 0
    width: parent ? parent.width : 0
    implicitHeight: control.rows.length > 0 ? header.height + table.height + 20 : 0

    Item {
        id: header

        width: parent.width
        height: 56

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            text: qsTr("API 参考")
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeHeader5
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            text: qsTr("QML 属性与信号，取自 src/ 下的源码；信号一栏写的就是 QML 里的写法（onClicked 等）")
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeSmall
        }
    }

    Table {
        id: table

        y: header.height
        width: parent.width
        // 不给 height：Table 的 bodyHeight 压根不读 control.height（那是为了躲
        // 「implicitHeight 先算小 → height 回落 → body 被夹成 0」的反馈环，见 src/Table.qml:294），
        // 所以以前那句 Math.min(rows, 12) 只是让外层 Column 以为表只有 13 行高，
        // 实际所有行照样画出去，把后面的 Accessibility / 文案规范整块盖住。

        columns: [
            { title: qsTr("属性"), dataIndex: "name", width: 200 },
            // 说明列必须 ellipsis：Table 的单元格 Text 缺省不换行（wrapMode 无）、
            // elide 也只在开了 ellipsis 时才生效，长描述会直接画到「类型」列脸上去
            // （pagination 页同样复现过）。Table 是定行高模型，换行要动 rowHeightAt
            // 的量测，这里按它的口径开省略号收口。
            { title: qsTr("说明"), dataIndex: "desc", ellipsis: true },
            { title: qsTr("类型"), dataIndex: "type", width: 160 },
            // 缺省值可能是 `Enums.Default` / `colorText0` 这类表达式，列窄了要省略号收口
            { title: qsTr("默认值"), dataIndex: "default", width: 120, ellipsis: true }
        ]
        dataSource: control.rows
        pagination: false
    }
}
