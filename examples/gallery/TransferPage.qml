pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 官方示例：content/input/transfer/index.md（13 个小节，标题与 docs.json 一致）
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ---- 各 demo 的数据与受控状态 ----
    readonly property var flat100: page.makeFlat(100)
    readonly property var flat30: page.makeFlat(30)
    readonly property var flat20: page.makeFlat(20)

    function makeFlat(n) {
        const out = [];
        for (let i = 0; i < n; ++i)
            out.push({ label: "选项名称 " + i, value: i, disabled: false, key: "key-" + i });
        return out;
    }

    readonly property var dataWithGroup: [
        {
            title: "类别A",
            children: [
                { label: "A-1", value: 1, disabled: false, key: 1 },
                { label: "A-2", value: 2, disabled: false, key: 2 },
                { label: "A-3", value: 3, disabled: false, key: 3 }
            ]
        },
        {
            title: "类别B",
            children: [
                { label: "B-1", value: 4, disabled: false, key: 4 },
                { label: "B-2", value: 5, disabled: false, key: 5 },
                { label: "B-3（disabled）", value: 6, disabled: true, key: 6 }
            ]
        },
        {
            title: "类别C",
            children: [
                { label: "C-1", value: 7, disabled: false, key: 7 },
                { label: "C-2", value: 8, disabled: false, key: 8 },
                { label: "C-3", value: 9, disabled: false, key: 9 },
                { label: "C-4", value: 10, disabled: false, key: 10 },
                { label: "C-5", value: 11, disabled: false, key: 11 },
                { label: "C-6", value: 12, disabled: false, key: 12 },
                { label: "C-7", value: 13, disabled: false, key: 13 }
            ]
        }
    ]

    readonly property var personData: [
        { label: "夏可漫", value: "xiakeman@example.com", abbr: "夏", color: "amber", area: "US", key: 1 },
        { label: "申悦", value: "shenyue@example.com", abbr: "申", color: "indigo", area: "UK", key: 2 },
        { label: "文嘉茂", value: "wenjiamao@example.com", abbr: "文", color: "cyan", area: "HK", key: 3 },
        { label: "曲晨一", value: "quchenyi@example.com", abbr: "曲", color: "blue", area: "India", key: 4 },
        { label: "曲晨二", value: "quchener@example.com", abbr: "二", color: "blue", area: "India", key: 5 },
        { label: "曲晨三", value: "quchensan@example.com", abbr: "三", color: "blue", area: "India", key: 6 }
    ]

    readonly property var treeData: [
        {
            label: "Asia", value: "Asia", key: "0",
            children: [
                {
                    label: "China", value: "China", key: "0-0",
                    children: [
                        { label: "Beijing", value: "Beijing", key: "0-0-0" },
                        { label: "Shanghai", value: "Shanghai", key: "0-0-1" },
                        { label: "Chengdu", value: "Chengdu", key: "0-0-2" }
                    ]
                },
                {
                    label: "Japan", value: "Japan", key: "0-1",
                    children: [
                        { label: "Osaka", value: "Osaka", key: "0-1-0" }
                    ]
                }
            ]
        },
        {
            label: "North America", value: "North America", key: "1",
            children: [
                { label: "United States", value: "United States", key: "1-0" },
                { label: "Canada", value: "Canada", key: "1-1" },
                { label: "Mexico", value: "Mexico", disabled: true, key: "1-2" },
                { label: "Cuba", value: "Cuba", key: "1-3" }
            ]
        }
    ]

    readonly property var folderData: [
        {
            label: "文件夹 1", value: "folder1", key: "folder1",
            children: [
                { label: "文件 1-1", value: "file1-1", key: "file1-1" },
                { label: "文件 1-2", value: "file1-2", key: "file1-2" },
                {
                    label: "子文件夹 1", value: "subfolder1", key: "subfolder1",
                    children: [
                        { label: "文件 1-1-1", value: "file1-1-1", key: "file1-1-1" },
                        { label: "文件 1-1-2", value: "file1-1-2", key: "file1-1-2" }
                    ]
                }
            ]
        },
        {
            label: "文件夹 2", value: "folder2", key: "folder2",
            children: [
                { label: "文件 2-1", value: "file2-1", key: "file2-1" },
                { label: "文件 2-2", value: "file2-2", key: "file2-2" }
            ]
        },
        { label: "独立文件", value: "file3", key: "file3" }
    ]

    property string searchText: ""
    property int ctrlPage: 1
    property var treeValue: ["Shanghai"]
    property var folderValue: []
    property var storeData: {
        const out = [];
        for (let i = 0; i < 100; ++i)
            out.push({ label: "海底捞门店 " + i, value: i, disabled: false, key: "key-" + i });
        return out;
    }

    function customFilter(sugInput, item) {
        return String(item.value).indexOf(sugInput) >= 0 || String(item.label).indexOf(sugInput) >= 0;
    }

    // 官方 <Avatar color="amber">，本库的 Avatar 只收色值：取同一档调色板
    function avatarColor(name) {
        if (name === "amber")
            return Theme.current.amber[3];
        if (name === "indigo")
            return Theme.current.indigo[3];
        if (name === "cyan")
            return Theme.current.cyan[3];
        return Theme.current.blue[3];
    }

    // ---- 自定义条目渲染（小节 3 / 8）----
    // 约定：注入的入参全部声明成组件根项的普通属性。checked 必须用 Binding 元素写，
    // 用户点一下 Checkbox 就是它自己往 checked 上赋值，外层绑定当场被打断，
    // 之后的全选 / 清空再也更不进来。
    Component {
        id: personSourceItem

        Item {
            id: cell

            property var modelData: ({})
            property bool checked: false
            property bool hovered: false
            property int index: -1
            property var toggle: null

            // 根项只声明 implicitHeight：宽度由外壳按整行绑定（官方那层 div 是块级元素）
            implicitHeight: 52

            Rectangle {
                anchors.fill: parent
                color: cell.hovered ? Theme.current.colorFill0 : "transparent"
            }

            // 官方把 Avatar + 姓名/邮箱塞在 Checkbox 的 children 里；本库 Checkbox 的
            // 内容只收字符串，所以勾框单独摆，正文并排放在它右边，整行再挂一个 TapHandler
            Checkbox {
                id: box

                objectName: "personSourceCheck"
                x: Theme.current.spacingBaseTight
                anchors.verticalCenter: parent.verticalCenter

                Binding {
                    target: box
                    property: "checked"
                    value: cell.checked
                    restoreMode: Binding.RestoreBindingOrValue
                }

                onToggled: {
                    if (cell.toggle !== null)
                        cell.toggle();
                }
            }

            Row {
                x: box.x + box.innerWidth + Theme.current.spacingTight
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.current.spacingBaseTight

                Avatar {
                    anchors.verticalCenter: parent.verticalCenter
                    size: "small"
                    text: String(cell.modelData.abbr)
                    backgroundColor: page.avatarColor(cell.modelData.color)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Highlight {
                        width: 200
                        sourceString: String(cell.modelData.label)
                        searchWords: page.searchText === "" ? [] : [page.searchText]
                    }

                    Text {
                        text: String(cell.modelData.value)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                        lineHeight: 16
                        lineHeightMode: Text.FixedHeight
                    }
                }
            }

            // 点到勾框以外正文那一块，官方也是整条可点
            TapHandler {
                onTapped: {
                    if (cell.toggle !== null)
                        cell.toggle();
                }
            }
        }
    }

    Component {
        id: personSelectedItem

        Item {
            id: cell

            property var modelData: ({})
            property bool hovered: false
            property int index: -1
            property var remove: null

            implicitHeight: 52

            Rectangle {
                anchors.fill: parent
                color: cell.hovered ? Theme.current.colorFill0 : "transparent"
            }

            Row {
                x: Theme.current.spacingBaseTight
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.current.spacingBaseTight

                Avatar {
                    anchors.verticalCenter: parent.verticalCenter
                    size: "small"
                    text: String(cell.modelData.abbr)
                    backgroundColor: page.avatarColor(cell.modelData.color)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: String(cell.modelData.label)
                        color: Theme.current.colorText0
                        font.pixelSize: Theme.current.fontSizeRegular
                        lineHeight: 20
                        lineHeightMode: Text.FixedHeight
                    }

                    Text {
                        text: String(cell.modelData.value)
                        color: Theme.current.colorText2
                        font.pixelSize: Theme.current.fontSizeSmall
                        lineHeight: 16
                        lineHeightMode: Text.FixedHeight
                    }
                }
            }

            // 官方 css：.semi-icon-close 平时 visibility:hidden，悬浮 visible
            Icon {
                objectName: "personSelectedClose"

                anchors.right: parent.right
                anchors.rightMargin: Theme.current.spacingTight
                anchors.verticalCenter: parent.verticalCenter
                name: "close"
                size: Theme.current.widthIconSmall
                color: Theme.current.colorText2
                opacity: cell.hovered ? 1 : 0
                enabled: cell.hovered

                TapHandler {
                    onTapped: {
                        if (cell.remove !== null)
                            cell.remove();
                    }
                }
            }
        }
    }

    // ---- 自定义面板头部（小节 9）----
    // 官方 <div style={{margin:'10px 0 0 10px', height:24, display:'flex', alignItems:'center'}}>。
    // 根项宽度由外壳按面板宽绑定，这里只给 implicitHeight。
    Component {
        id: storeSourceHeader

        Item {
            id: head

            property int num: 0
            property bool showButton: false
            property bool allChecked: false
            property var allClick: null
            property var leafOnlyNum: undefined

            implicitHeight: 34

            Row {
                x: 10
                y: 10
                height: 24
                spacing: Theme.current.spacingBase

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("共 %1 项").arg(head.num)
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: head.showButton
                    text: head.allChecked ? qsTr("取消全选") : qsTr("全选")
                    tone: Enums.Tertiary
                    variant: Enums.Borderless
                    size: Enums.Small
                    onClicked: {
                        if (head.allClick !== null)
                            head.allClick();
                    }
                }
            }
        }
    }

    Component {
        id: storeSelectedHeader

        Item {
            id: head

            property int num: 0
            property bool showButton: false
            property var clear: null

            implicitHeight: 34

            Row {
                x: 10
                y: 10
                height: 24
                spacing: Theme.current.spacingBase

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 项已选").arg(head.num)
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: head.showButton
                    text: qsTr("清空")
                    tone: Enums.Tertiary
                    variant: Enums.Borderless
                    size: Enums.Small
                    onClicked: {
                        if (head.clear !== null)
                            head.clear();
                    }
                }
            }
        }
    }

    // ---- 树穿梭框自定义头部（小节 13）----
    Component {
        id: folderSourceHeader

        Item {
            id: head

            property int num: 0
            property bool showButton: false
            property bool allChecked: false
            property var allClick: null
            property var leafOnlyNum: undefined

            implicitHeight: 37

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.current.colorBorder
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -1
                x: Theme.current.spacingBaseTight
                text: qsTr("文件总数：%1 个文件（总节点数：%2）")
                    .arg(head.leafOnlyNum === undefined ? head.num : head.leafOnlyNum)
                    .arg(head.num)
                color: Theme.current.colorText0
                font.pixelSize: Theme.current.fontSizeRegular
            }

            Button {
                anchors.right: parent.right
                anchors.rightMargin: Theme.current.spacingBaseTight
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -1
                visible: head.showButton
                text: head.allChecked ? qsTr("取消全选") : qsTr("全选")
                tone: Enums.Tertiary
                variant: Enums.Borderless
                size: Enums.Small
                onClicked: {
                    if (head.allClick !== null)
                        head.allClick();
                }
            }
        }
    }

    // ---- 完全自定义渲染（小节 10 / 11）----
    Component {
        id: storeSourcePanel

        Item {
            id: panel

            property var value: []
            property bool loading: false
            property bool noMatch: false
            property var filterData: []
            property var sourceData: []
            property var propsDataSource: []
            property bool allChecked: false
            property int showNumber: 0
            property string inputValue: ""
            property var selectedItems: []
            property var search: null
            property var allClick: null
            property var selectOrRemove: null
            property var selectValues: null

            // .source-panel 482 + margin-right 16
            width: 498
            height: 353

            // .panel-header：padding 10/12、描边、上两角圆角、高 38
            Rectangle {
                id: panelHeader

                objectName: "storePanelHeader"
                width: 482
                height: 38
                radius: Theme.current.radiusExtraSmall
                color: Theme.current.colorTertiaryLightDefault
                border.width: 1
                border.color: Theme.current.colorBorder

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.current.spacingBaseTight
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("门店列表")
                    color: Theme.current.grey[9]
                    font.pixelSize: Theme.current.fontSizeSmall
                    font.weight: Font.Medium
                }
            }

            Item {
                id: panelMain

                x: 0
                y: panelHeader.height - Theme.current.radiusExtraSmall
                width: 482
                height: panel.height - y

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.current.radiusExtraSmall
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.current.colorBorder
                }

                Input {
                    id: panelInput

                    objectName: "storePanelInput"
                    x: 14
                    y: 12
                    width: 454
                    prefixIcon: "search"
                    showClear: true
                    onTextChanged: {
                        if (panel.search !== null)
                            panel.search(text);
                    }
                }

                Row {
                    id: panelControls

                    objectName: "storePanelControls"
                    x: Theme.current.spacingBaseTight
                    y: panelInput.y + panelInput.height + 10
                    spacing: Theme.current.spacingBase

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("待选门店: %1").arg(panel.filterData.length)
                        color: Theme.current.grey[9]
                        font.pixelSize: Theme.current.fontSizeSmall
                        font.weight: Font.Medium
                    }

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.allChecked ? qsTr("取消全选") : qsTr("全选")
                        variant: Enums.Borderless
                        size: Enums.Small
                        onClicked: {
                            if (panel.allClick !== null)
                                panel.allClick();
                        }
                    }
                }

                Flickable {
                    id: panelScroll

                    objectName: "storePanelScroll"
                    x: Theme.current.spacingBaseTight
                    y: panelControls.y + panelControls.height + 10
                    width: panelMain.width - Theme.current.spacingBaseTight * 2
                    height: 214
                    contentHeight: panelFlow.height
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    // .panel-list：flex-wrap、row/column gap 8
                    Flow {
                        id: panelFlow

                        width: panelScroll.width
                        spacing: Theme.current.spacingTight

                        Repeater {
                            model: panel.filterData

                            delegate: Item {
                                id: card

                                required property var modelData
                                required property int index

                                readonly property bool checked: panel.selectedItems
                                    .filter(i => i.key === modelData.key).length > 0

                                objectName: "storeSourceCard" + index
                                width: 176
                                height: 56

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.current.radiusExtraSmall
                                    color: Theme.current.colorFill0
                                }

                                Text {
                                    id: cardText

                                    objectName: "storeSourceCardText" + card.index
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.current.spacingBaseTight
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 96
                                    text: String(card.modelData.label)
                                    color: Theme.current.colorText0
                                    font.pixelSize: Theme.current.fontSizeRegular
                                    elide: Text.ElideRight
                                }

                                Button {
                                    objectName: "storeSourceCardButton" + card.index

                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.current.spacingTight
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: card.checked ? qsTr("删除") : qsTr("添加")
                                    tone: Enums.Primary
                                    variant: Enums.Borderless
                                    size: Enums.Small
                                    onClicked: {
                                        if (panel.selectOrRemove !== null)
                                            panel.selectOrRemove(card.modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: storeSelectedPanel

        Item {
            id: panel

            property int length: 0
            property var selectedData: []
            property var clear: null
            property var remove: null
            property var sortEnd: null

            property int dragIndex: -1
            property int dropIndex: -1

            width: 200
            height: 353

            Rectangle {
                id: panelHeader

                width: parent.width
                height: 38
                radius: Theme.current.radiusExtraSmall
                color: Theme.current.colorTertiaryLightDefault
                border.width: 1
                border.color: Theme.current.colorBorder

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.current.spacingBaseTight
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("已选同步门店: %1").arg(panel.selectedData.length)
                    color: Theme.current.grey[9]
                    font.pixelSize: Theme.current.fontSizeSmall
                    font.weight: Font.Medium
                }

                Button {
                    objectName: "storeClearButton"

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.current.spacingTight
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("清空")
                    tone: Enums.Primary
                    variant: Enums.Borderless
                    size: Enums.Small
                    onClicked: {
                        if (panel.clear !== null)
                            panel.clear();
                    }
                }
            }

            Flickable {
                id: panelScroll

                objectName: "storeSelectedScroll"
                y: panelHeader.height - Theme.current.radiusExtraSmall
                width: parent.width
                height: 323
                contentHeight: panelList.height
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: panelList

                    objectName: "storeSelectedList"
                    x: Theme.current.spacingBaseTight
                    width: parent.width - Theme.current.spacingBaseTight * 2
                    spacing: Theme.current.spacingTight

                    Repeater {
                        model: panel.selectedData

                        delegate: Item {
                            id: card

                            required property var modelData
                            required property int index

                            property real pointerOffset: 0

                            readonly property bool dragging: panel.dragIndex === index

                            objectName: "storeSelectedCard" + index
                            width: panelList.width
                            height: 56
                            z: dragging ? 1 : 0

                            transform: Translate {
                                y: card.pointerOffset
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.current.radiusExtraSmall
                                color: Theme.current.colorFill0
                            }

                            Icon {
                                objectName: "storeSelectedHandle" + card.index

                                anchors.left: parent.left
                                anchors.leftMargin: Theme.current.spacingExtraTight
                                anchors.verticalCenter: parent.verticalCenter
                                name: "handle"
                                size: Theme.current.widthIconMedium
                                color: Theme.current.colorText2

                                DragHandler {
                                    target: null

                                    onActiveChanged: {
                                        if (active) {
                                            panel.dragIndex = card.index;
                                            panel.dropIndex = card.index;
                                        } else {
                                            if (panel.dropIndex !== panel.dragIndex
                                                && panel.sortEnd !== null)
                                                panel.sortEnd({
                                                    oldIndex: panel.dragIndex,
                                                    newIndex: panel.dropIndex
                                                });
                                            panel.dragIndex = -1;
                                            panel.dropIndex = -1;
                                            card.pointerOffset = 0;
                                        }
                                    }

                                    // 卡片等间距 56 + 8，按整格数换算落点序号
                                    onTranslationChanged: {
                                        if (!active)
                                            return;
                                        card.pointerOffset = translation.y;
                                        const steps = Math.round(translation.y / 64);
                                        const last = panel.selectedData.length - 1;
                                        panel.dropIndex = Math.max(0,
                                            Math.min(last, card.index + steps));
                                    }
                                }
                            }

                            Text {
                                objectName: "storeSelectedText" + card.index

                                anchors.left: parent.left
                                anchors.leftMargin: Theme.current.spacingBaseTight + 20
                                anchors.verticalCenter: parent.verticalCenter
                                width: 100
                                text: String(card.modelData.label)
                                color: Theme.current.colorText0
                                font.pixelSize: Theme.current.fontSizeRegular
                                elide: Text.ElideRight
                            }

                            Button {
                                objectName: "storeSelectedRemove" + card.index

                                anchors.right: parent.right
                                anchors.rightMargin: Theme.current.spacingTight
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("删除")
                                tone: Enums.Primary
                                variant: Enums.Borderless
                                size: Enums.Small
                                onClicked: {
                                    if (panel.remove !== null)
                                        panel.remove(card.modelData);
                                }
                            }
                        }
                    }
                }
            }

            // 官方 .empty 是 panel-main 里撑满 100% 的居中块，这里做成它的同级
            Text {
                objectName: "storeSelectedEmpty"

                visible: panel.selectedData.length === 0
                y: panelHeader.height - Theme.current.radiusExtraSmall
                width: parent.width
                height: 323
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: qsTr("暂无数据，请从左侧筛选")
                color: Theme.current.grey[9]
                font.pixelSize: Theme.current.fontSizeSmall
                font.weight: Font.Medium
            }
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本使用"

            Transfer {
                width: 568
                height: 416
                dataSource: page.flat100
                onChange: (values, items) => console.log("onChange", values, items)
            }
        }

        GallerySection {
            title: "分组"

            Transfer {
                width: 568
                type: "groupList"
                defaultValue: [6]
                dataSource: page.dataWithGroup
                onChange: (values, items) => console.log("onChange", values, items)
            }
        }

        GallerySection {
            title: "自定义筛选逻辑，自定义选项数据渲染"

            Transfer {
                width: 568
                dataSource: page.personData
                filter: page.customFilter
                defaultValue: ["xiakeman@example.com", "shenyue@example.com"]
                renderSourceItem: personSourceItem
                renderSelectedItem: personSelectedItem
                inputProps: ({ placeholder: qsTr("搜索姓名或邮箱") })
                onSearch: (text) => page.searchText = text
                onChange: (values, items) => console.log("onChange", values, items)
            }
        }

        GallerySection {
            title: "禁用"

            Transfer {
                width: 568
                height: 416
                disabled: true
                dataSource: page.flat20
                defaultValue: [2, 4]
                onChange: (values, items) => console.log("onChange", values, items)
            }
        }

        GallerySection {
            title: "拖拽排序"

            Transfer {
                width: 568
                height: 416
                dataSource: page.flat30
                defaultValue: [2, 4]
                draggable: true
                onChange: (values, items) => console.log("onChange", values, items)
            }
        }

        GallerySection {
            title: "左侧分页"

            Transfer {
                width: 568
                height: 416
                dataSource: page.flat100
                pagination: ({ pageSize: 10 })
                onChange: (values, items) => console.log("onChange", values, items)
            }
        }

        GallerySection {
            title: "左侧分页 + 受控页码"

            Column {
                spacing: 12

                ButtonGroup {
                    Button {
                        text: qsTr("第1页")
                        onClicked: page.ctrlPage = 1
                    }

                    Button {
                        text: qsTr("第2页")
                        onClicked: page.ctrlPage = 2
                    }

                    Button {
                        text: qsTr("第5页")
                        onClicked: page.ctrlPage = 5
                    }

                    Button {
                        text: qsTr("第10页")
                        onClicked: page.ctrlPage = 10
                    }
                }

                Text {
                    text: qsTr("当前页码: %1").arg(page.ctrlPage)
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Transfer {
                    width: 568
                    height: 416
                    dataSource: page.flat100
                    pagination: ({
                        pageSize: 10,
                        currentPage: page.ctrlPage,
                        onPageChange: function (currentPage) { page.ctrlPage = currentPage; }
                    })
                    onChange: (values, items) => console.log("onChange", values, items)
                }
            }
        }

        GallerySection {
            title: "拖拽 + 自定义已选项渲染"

            Transfer {
                width: 568
                draggable: true
                dataSource: page.personData
                filter: page.customFilter
                defaultValue: ["xiakeman@example.com", "shenyue@example.com"]
                renderSelectedItem: personSelectedItem
                renderSourceItem: personSourceItem
                inputProps: ({ placeholder: qsTr("搜索姓名或邮箱") })
                onChange: (values, items) => console.log("onChange", values, items)
            }
        }

        GallerySection {
            title: "自定义渲染面板头部信息"

            Transfer {
                width: 568
                height: 416
                dataSource: page.flat30
                renderSourceHeader: storeSourceHeader
                renderSelectedHeader: storeSelectedHeader
            }
        }

        GallerySection {
            title: "完全自定义渲染"

            Transfer {
                renderSourcePanel: storeSourcePanel
                renderSelectedPanel: storeSelectedPanel
                dataSource: page.storeData
                onChange: (values) => console.log("onChange", values)
            }
        }

        GallerySection {
            title: "完全自定义渲染 、 拖拽排序"

            Transfer {
                defaultValue: [2, 4]
                renderSourcePanel: storeSourcePanel
                renderSelectedPanel: storeSelectedPanel
                dataSource: page.storeData
                onChange: (values) => console.log("onChange", values)
            }
        }

        GallerySection {
            title: "树穿梭框"

            Transfer {
                width: 580
                dataSource: page.treeData
                type: "treeList"
                value: page.treeValue
                onChange: (values) => page.treeValue = values
            }
        }

        GallerySection {
            title: "树穿梭框自定义头部显示叶子节点数量"

            Transfer {
                width: 600
                dataSource: page.folderData
                type: "treeList"
                value: page.folderValue
                renderSourceHeader: folderSourceHeader
                onChange: (values) => page.folderValue = values
            }
        }
    }
}
