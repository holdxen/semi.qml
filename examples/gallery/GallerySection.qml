pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 内容小节的模板：标题 + 说明 + demo 区。
//
// 页面里只需要写标题和 demo，说明文字由这里从 GalleryShell 按标题取，
// 保证与官网文字一致、不用手抄：
//
//     GallerySection {
//         title: "按钮类型"
//         Row {
//             Button { text: "主要按钮" }
//         }
//     }
Item {
    id: control

    property string title: ""
    default property alias content: demoArea.data

    // 标记自己，供外壳在页面里找出所有小节、给右侧页内锚点排位置
    readonly property bool isGallerySection: true

    // 向上找外壳，从它那里按标题取说明
    function shellRoot() {
        let node = control.parent;
        while (node !== null && node !== undefined) {
            // qmllint disable missing-property
            if (node.sectionDescription !== undefined)
                return node;
            // qmllint enable missing-property
            node = node.parent;
        }
        return null;
    }

    readonly property string description: {
        const shell = control.shellRoot();
        if (shell === null)
            return "";
        return shell.sectionDescription(control.title);
    }

    width: parent ? parent.width : 0
    implicitHeight: headerBlock.height + demoArea.height + 40

    Column {
        id: headerBlock

        width: parent.width
        spacing: 0

        Text {
            width: parent.width
            text: control.title
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeHeader5
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            topPadding: 10
            visible: control.description !== ""
            text: control.description
            color: Theme.current.colorText1
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: 24
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.WordWrap
        }
    }

    // demo 区用 Column：一小节里常有「控件 + 一段说明文字」，竖着排才对。
    // 用 Item 的话多个子项会全部落在 y=0 上叠成一团。
    Column {
        id: demoArea

        y: headerBlock.height + 20
        width: parent.width
        spacing: 12
    }
}
