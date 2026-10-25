pragma ComponentBehavior: Bound

import QtQuick
import Semi

// OverflowList 折叠列表。小节与标题对齐官方文档页 content/show/overflowList/index.md：
// 如何引入 + 折叠模式（默认 / 方向 / 最小展示的数目）+ 滚动模式，四份 live demo 各自带一条
// Slider 调容器宽度（官方每份 demo 都自己 useState(100) 控宽，这里就一节一份）。
//
// 官方六项内容照抄：alarm / bookmark / camera / duration / edit / folder，每项一个蓝 Tag
// （图标在前、文字是 key），放不下的收进一个「+N」灰 Tag。
//
// 间距：组件本身没有 spacing（`overflowList.scss` 只给了 flex nowrap），官方那 8px 是
// 每个 Tag 自己写的 marginRight ⇒ 端口的做法是把余量算进渲染节点自己的隐式宽，
// 下面 ItemCell / PlusTag 里的 `+ 8` 就是官方的 `style={{ marginRight: 8 }}`。
// 各小节「+N」节点的余量按官方逐个抄：默认档不带、方向档带右 8、滚动档左右各 8。
//
// Slider 那条：官方是 `value={width} onChange={setWidth}` 的受控写法。端口的 Slider
// 拖动过程中会自己写 value（外部绑定早没了），所以这里不绑 page 上的状态 ——
// 把滑块自己当状态源，容器宽直接读它的 value（同 SliderPage「受控组件」那一节的教训，
// 只是这一节没有别的写入方，就不用再装回绑定）。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 官方 demo 的宽度基数就是文档容器宽，这里固定成一个可比较的数
    readonly property real demoWidth: 560

    readonly property var demoItems: [
        { "iconName": "alarm", "key": "alarm" },
        { "iconName": "bookmark", "key": "bookmark" },
        { "iconName": "camera", "key": "camera" },
        { "iconName": "duration", "key": "duration" },
        { "iconName": "edit", "key": "edit" },
        { "iconName": "folder", "key": "folder" }
    ]

    // 官方 visibleItemRenderer：蓝 Tag，图标 + key，右边 8
    component ItemCell: Item {
        id: cell

        property var item: null
        property int index: -1

        implicitWidth: cellTag.implicitWidth + 8
        implicitHeight: cellTag.implicitHeight

        Tag {
            id: cellTag

            color: "blue"
            text: cell.item !== null ? cell.item.key : ""
            prefixIcon: cell.item !== null ? cell.item.iconName : ""
        }
    }

    // 官方 overflowRenderer：`items.length ? <Tag>+{items.length}</Tag> : null`
    // ⇒ 没有收起项时那份节点根本不存在；端口 Component 总会实例化，等价写法就是
    // 「没内容时节点自己把隐式宽收到 0」，官方 demo 的三元也是这个意思。
    component PlusTag: Item {
        id: plus

        property var overflowItems: []
        property real marginRight: 0

        implicitWidth: plusTag.visible ? plusTag.implicitWidth + marginRight : 0
        implicitHeight: plusTag.implicitHeight

        Tag {
            id: plusTag

            visible: plus.overflowItems.length > 0
            text: "+" + plus.overflowItems.length
        }
    }

    // 滚动档两侧的节点：定宽、且两侧都常驻（官方 Tabs 那对箭头就是定宽、只切 enabled）。
    // 官方滚动档的 renderer 返回的是两组节点，端口一份 Component 实例化两遍 ⇒ 靠注入的
    // `overflowSide` 认左右。宽要是跟着收起项数变，视口宽就会和可见集互相追（组件头注有实测数据）。
    component ScrollSide: Item {
        id: side

        property var overflowItems: []
        property string overflowSide: "before"

        implicitWidth: 44
        implicitHeight: sideTag.implicitHeight

        Tag {
            id: sideTag

            anchors.verticalCenter: parent.verticalCenter
            enabled: side.overflowItems.length > 0
            text: side.overflowItems.length > 0 ? "+" + side.overflowItems.length : ""
            prefixIcon: side.overflowSide === "before" ? "chevron_left" : "chevron_right"
        }
    }

    component Note: Text {
        width: page.demoWidth
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        wrapMode: Text.WordWrap
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
                    + "// 折叠档：放不下的收进末尾那个「+N」\n"
                    + "OverflowList {\n"
                    + "    items: [{ iconName: \"alarm\", key: \"alarm\" }, …]\n"
                    + "    visibleItemRenderer: Component { YourTag {} }   // 节点里声明 property var item / int index\n"
                    + "    overflowRenderer: Component { YourPlus {} }     // 节点里声明 property var overflowItems\n"
                    + "}\n\n"
                    + "// 不折叠，改横向滚动\n"
                    + "OverflowList { renderMode: \"scroll\"; … }"
            }
        }

        GallerySection {
            title: "折叠模式 - 默认"

            Column {
                width: page.demoWidth
                spacing: 16

                Slider {
                    id: defaultWidth

                    objectName: "collapseWidthSlider"

                    width: parent.width
                    min: 0
                    max: 100
                    step: 1
                    value: 100
                }

                Item {
                    width: page.demoWidth * defaultWidth.value / 100
                    height: defaultList.implicitHeight

                    OverflowList {
                        id: defaultList

                        objectName: "collapseDefault"

                        items: page.demoItems
                        visibleItemRenderer: Component { ItemCell {} }
                        overflowRenderer: Component { PlusTag {} }
                    }
                }

                Text {
                    width: parent.width
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                    text: qsTr("看得见 %1 项，收起 %2 项（visibleCount / hiddenCount）")
                        .arg(defaultList.visibleCount).arg(defaultList.hiddenCount)
                }
            }

            Note {
                text: qsTr("renderMode 的缺省就是 collapse：一行摆得下几项摆几项，剩下的收进末尾那个「+N」。"
                    + "累计宽是从「+N」自己的宽起步再逐项加的（官方 foundation.ts 就这么写），"
                    + "所以「+N」占了位、能摆下的项数就少一项 —— 拖一下就能看到收得比看上去该收的多一项。")
            }
        }

        GallerySection {
            title: "折叠模式 - 方向"

            Column {
                width: page.demoWidth
                spacing: 16

                Slider {
                    id: directionWidth

                    objectName: "directionWidthSlider"

                    width: parent.width
                    min: 0
                    max: 100
                    step: 1
                    value: 100
                }

                Item {
                    width: page.demoWidth * directionWidth.value / 100
                    height: directionList.implicitHeight

                    OverflowList {
                        id: directionList

                        objectName: "collapseFromStart"

                        items: page.demoItems
                        collapseFrom: "start"
                        visibleItemRenderer: Component { ItemCell {} }
                        overflowRenderer: Component { PlusTag { marginRight: 8 } }
                    }
                }
            }

            Note {
                text: qsTr("collapseFrom 只决定「先收哪一端」：start 收的是开头几项，留下的还是末尾那几项，"
                    + "而「+N」跟着挪到最前面（官方 renderItemList 里那两条 ternary 就是这个意思）。")
            }
        }

        GallerySection {
            title: "折叠模式 - 最小展示的数目"

            Column {
                width: page.demoWidth
                spacing: 16

                Slider {
                    id: minWidth

                    objectName: "minWidthSlider"

                    width: parent.width
                    min: 0
                    max: 100
                    step: 1
                    value: 100
                }

                Item {
                    width: page.demoWidth * minWidth.value / 100
                    height: minList.implicitHeight

                    OverflowList {
                        id: minList

                        objectName: "collapseMinVisible"

                        items: page.demoItems
                        minVisibleItems: 3
                        visibleItemRenderer: Component { ItemCell {} }
                        overflowRenderer: Component { PlusTag {} }
                    }
                }
            }

            Note {
                text: qsTr("minVisibleItems 是个硬下限：算出来一项都放不下，也照样挤 3 项出来，"
                    + "代价是整行超出容器宽度（上面拖到底就能看到那三项一路摆到容器外面 —— "
                    + "官方外层是 flex nowrap，既不裁也不折）。官方那条说明就是这个。")
            }
        }

        GallerySection {
            title: "滚动模式"

            Column {
                width: page.demoWidth
                spacing: 16

                Slider {
                    id: scrollWidth

                    objectName: "scrollWidthSlider"

                    width: parent.width
                    min: 0
                    max: 100
                    step: 1
                    value: 100
                }

                Item {
                    width: page.demoWidth * scrollWidth.value / 100
                    height: scrollList.implicitHeight

                    OverflowList {
                        id: scrollList

                        objectName: "scrollMode"

                        items: page.demoItems
                        renderMode: "scroll"
                        visibleItemRenderer: Component { ItemCell {} }
                        overflowRenderer: Component { ScrollSide {} }
                    }
                }
            }

            Note {
                text: qsTr("renderMode: scroll 不折叠，整条横向可滚动（在条上往左拖就能看剩下的项）。"
                    + "这一档两侧各有一份溢出节点：左边那份拿「滚过头」的那批、右边那份拿「还没滚到」的那批"
                    + "（官方 getOverflowItem 在这一档返回的就是两份数组）。"
                    + "露出宽不到项宽的 75%（threshold）就算收起来了，两侧那两份跟着变。")
            }
        }
    }
}
