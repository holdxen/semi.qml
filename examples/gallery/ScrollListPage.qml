pragma ComponentBehavior: Bound

import QtQuick
import Semi

// ScrollList 滚动列表。小节与标题对齐官方文档页 content/show/scrolllist/index.md
// —— 官方整页只有「如何引入」加一个「基本使用」的 live demo（三列滚轮选时间），
// 这里就照这一份摆，不自造小节。
//
// 官方的分工要记一下：ScrollList 只是 header / body / footer 三段外壳，
// 滚轮、点选、无限循环都在 ScrollItem 那一列上（mode / cycled / list /
// selectedIndex / onSelect / transform / motion）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方那三个 useState(selectIndex1/2/3)
    property int selectIndex1: 1
    property int selectIndex2: 1
    property int selectIndex3: 1

    readonly property var ampmList: [
        { "value": qsTr("上午") },
        { "value": qsTr("下午") }
    ]
    readonly property var hourList: page.makeList(12, 1)
    // 官方 demo 用 Math.random() 决定哪几分钟禁用，每刷新都在变；
    // 这里取 storybook 的固定写法（奇数分钟禁用），摆出来的是同一件东西
    readonly property var minuteList: page.makeMinuteList(60)

    function makeList(count, from) {
        const out = [];
        for (let i = 0; i < count; ++i)
            out.push({ "value": i + from });
        return out;
    }

    function makeMinuteList(count) {
        const out = [];
        for (let i = 0; i < count; ++i)
            out.push({ "value": i, "disabled": i % 2 === 1 });
        return out;
    }

    component Note: Text {
        width: 700
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    // 官方页脚就是个小主色按钮（renderFooter 里那个 <Button size="small" type="primary">Ok</Button>）
    property Component footerOk: Component {
        Item {
            implicitWidth: okButton.implicitWidth
            implicitHeight: okButton.implicitHeight

            Button {
                id: okButton

                objectName: "scrollListFooterOk"

                text: "Ok"
                size: Enums.Small
                tone: Enums.Primary
            }
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 620
                text: "import Semi\n\n"
                    + "// ScrollList 只管外壳，每一列是一个 ScrollItem\n"
                    + "ScrollList {\n"
                    + "    header: \"无限滚动列表\"\n"
                    + "    footer: 你的页脚节点\n"
                    + "    ScrollItem { mode: \"wheel\"; cycled: true; list: hours; }\n"
                    + "    ScrollItem { mode: \"wheel\"; list: minutes; selectedIndex: 1; }\n"
                    + "}"
            }
        }

        GallerySection {
            title: "基本使用"

            Column {
                width: parent.width
                spacing: 12

                // 官方：<ScrollList style={{border:'unset', boxShadow:'unset'}}
                //   header="无限滚动列表" footer=<Button size="small" type="primary">Ok</Button>>
                //   里三列 mode="wheel"，ampms 不循环、hours 与 minutes 循环。
                ScrollList {
                    objectName: "basicScrollList"

                    width: parent.width
                    header: qsTr("无限滚动列表")
                    footer: page.footerOk
                    style: ({ "border": "unset", "boxShadow": "unset" })

                    ScrollItem {
                        objectName: "ampmColumn"

                        mode: "wheel"
                        cycled: false
                        list: page.ampmList
                        type: 1
                        selectedIndex: page.selectIndex1
                        onSelect: function (data) {
                            if (data.type === 1)
                                page.selectIndex1 = data.index;
                        }
                    }

                    ScrollItem {
                        objectName: "hourColumn"

                        mode: "wheel"
                        cycled: true
                        list: page.hourList
                        type: 2
                        selectedIndex: page.selectIndex2
                        onSelect: function (data) {
                            if (data.type === 2)
                                page.selectIndex2 = data.index;
                        }
                    }

                    ScrollItem {
                        objectName: "minuteColumn"

                        mode: "wheel"
                        cycled: true
                        list: page.minuteList
                        type: 3
                        selectedIndex: page.selectIndex3
                        onSelect: function (data) {
                            if (data.type === 3)
                                page.selectIndex3 = data.index;
                        }
                    }
                }

                Note {
                    text: qsTr("三列都是 ScrollItem，外壳 ScrollList 只负责标题、页脚和横向排版。"
                        + "selectedIndex 是受控的：列自己不改它，滚动或点选只发 select 信号，"
                        + "载荷里带 {...ItemData, type, index}，由本页写回对应的 state —— "
                        + "所以拖完那一下位置会由 selectedIndex 说了算。"
                        + "cycled 为 true 的列上下可以无限接（官方把 DOM 循环复用，这里铺多份模型）；"
                        + "minutes 里奇数项 disabled，吸附时会跳过它们。")
                }

                Note {
                    text: qsTr("mode 默认 \"wheel\"，改成 \"normal\" 就是普通列表：点一行选中它"
                        + "（选中底 primary-light-default、悬浮 fill-1、按下 fill-2），"
                        + "normal 不吸附到中间，官方文档页没有这一档的 demo，这里也就不摆了。")
                }
            }
        }
    }
}
