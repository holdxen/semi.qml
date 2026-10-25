pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 左侧边栏。顶部搜索框 + 分组列表（可折叠、当前项高亮、未实现的灰掉）+ 底部明暗切换。
//
// 样式照 Navigation 的规格：一级项选中底 primary-light-default、
// 悬浮底 fill-0、文字 text-0 / text-2、禁用 disabled-text。
// 没有直接用 Navigation 组件：它是为「导航菜单」设计的，这里是
// 69 个条目 + 分组 + 滚动，自己画更好控制。
Item {
    id: control

    property var docs: null
    property string currentDir: ""

    signal navigate(string dir, string category)

    readonly property var categories: control.docs !== null ? control.docs.categories : []
    readonly property int itemHeight: 34
    readonly property int groupHeight: 38
    readonly property int indent: 12
    readonly property int searchHeight: 60
    readonly property int footerHeight: 52

    // 搜索关键字（空 = 不筛选）
    property string keyword: ""

    // 折叠状态：key 是分类名，值为 true 表示收起
    property var collapsed: ({})

    function isCollapsed(key) {
        return control.collapsed[key] === true;
    }

    function toggleGroup(key) {
        const next = {};
        for (const k in control.collapsed)
            next[k] = control.collapsed[k];
        next[key] = !next[key];
        control.collapsed = next;
    }

    function matches(component) {
        if (control.keyword === "")
            return true;
        const needle = control.keyword.toLowerCase();
        return component.title.toLowerCase().indexOf(needle) >= 0
            || component.dir.toLowerCase().indexOf(needle) >= 0;
    }

    function matched(components) {
        const result = [];
        for (let i = 0; i < components.length; ++i)
            if (control.matches(components[i]))
                result.push(components[i]);
        return result;
    }

    readonly property int matchCount: {
        let count = 0;
        for (let i = 0; i < control.categories.length; ++i)
            count += control.matched(control.categories[i].components).length;
        return count;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.current.colorBg2

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Theme.current.colorBorder
        }
    }

    // ---- 搜索 ----
    Item {
        id: searchArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: control.searchHeight

        Input {
            id: searchInput

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: control.indent
            anchors.rightMargin: control.indent
            anchors.verticalCenter: parent.verticalCenter

            size: Enums.Small
            prefixIcon: "search"
            showClear: true
            placeholderText: qsTr("搜索组件")
            onTextChanged: control.keyword = text
        }

        // keyword 也可能是外面设进来的（main.cpp 的 --search），
        // 那时输入框要跟上；两边相同时不动作，免得绕成环
        Connections {
            target: control

            function onKeywordChanged() {
                if (searchInput.text !== control.keyword)
                    searchInput.text = control.keyword;
            }
        }
    }

    // ---- 组件列表 ----
    Flickable {
        id: listScroll

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchArea.bottom
        anchors.bottom: footerArea.top
        contentWidth: width
        contentHeight: sidebarColumn.height + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: sidebarColumn

            x: 8
            y: 12
            width: listScroll.width - 16
            spacing: 0

            Repeater {
                model: control.categories

                delegate: Column {
                    id: group

                    required property var modelData

                    // 搜索时忽略折叠状态（否则搜不到收起来的分组），
                    // 没搜索时按折叠状态决定这一组显示哪些
                    readonly property var shown: control.keyword !== ""
                        ? control.matched(group.modelData.components)
                        : (control.isCollapsed(group.modelData.key)
                            ? [] : group.modelData.components)

                    width: sidebarColumn.width
                    spacing: 0
                    visible: group.shown.length > 0

                    Item {
                        width: group.width
                        height: control.groupHeight

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: control.indent
                            anchors.verticalCenter: parent.verticalCenter
                            text: group.modelData.name
                            color: Theme.current.colorText2
                            font.pixelSize: Theme.current.fontSizeSmall
                            font.weight: Font.DemiBold
                        }

                        Icon {
                            anchors.right: parent.right
                            anchors.rightMargin: control.indent
                            anchors.verticalCenter: parent.verticalCenter
                            name: control.isCollapsed(group.modelData.key)
                                ? "arrow_down" : "arrow_up"
                            size: 12
                            color: Theme.current.colorText2
                        }

                        TapHandler {
                            onTapped: control.toggleGroup(group.modelData.key)
                        }
                    }

                    Repeater {
                        model: group.shown

                        delegate: Item {
                            id: entry

                            required property var modelData

                            readonly property bool current: entry.modelData.dir === control.currentDir
                            readonly property bool hovered: entryHover.hovered

                            width: group.width
                            height: control.itemHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.current.radiusSmall
                                color: {
                                    if (entry.modelData.skipped)
                                        return "transparent";
                                    if (entry.current)
                                        return Theme.current.colorPrimaryLightDefault;
                                    if (entry.hovered)
                                        return Theme.current.colorFill0;
                                    return "transparent";
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: control.indent
                                anchors.right: skippedTag.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.title
                                color: {
                                    if (entry.modelData.skipped)
                                        return Theme.current.colorDisabledText;
                                    return entry.current
                                        ? Theme.current.colorText0 : Theme.current.colorText1;
                                }
                                font.pixelSize: Theme.current.fontSizeRegular
                                font.weight: entry.current ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                id: skippedTag

                                visible: entry.modelData.skipped
                                anchors.right: parent.right
                                anchors.rightMargin: control.indent
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("未实现")
                                color: Theme.current.colorDisabledText
                                font.pixelSize: Theme.current.fontSizeSmall
                            }

                            HoverHandler {
                                id: entryHover
                                enabled: !entry.modelData.skipped
                            }

                            TapHandler {
                                enabled: !entry.modelData.skipped
                                onTapped: control.navigate(entry.modelData.dir, group.modelData.key)
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: 8
                    }
                }
            }
        }
    }

    // 搜索没命中时的提示（列表整体空掉，光看空白会以为坏了）
    Text {
        anchors.top: searchArea.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        visible: control.keyword !== "" && control.matchCount === 0
        text: qsTr("没有匹配的组件")
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
    }

    // ---- 明暗切换 ----
    Item {
        id: footerArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: control.footerHeight

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.current.colorBorder
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: control.indent
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Theme.mode === Theme.Dark ? "moon" : "sun"
                size: 16
                color: Theme.current.colorText2
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.mode === Theme.Dark ? qsTr("深色模式") : qsTr("浅色模式")
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeRegular
            }
        }

        Switch {
            id: themeSwitch

            anchors.right: parent.right
            anchors.rightMargin: control.indent
            anchors.verticalCenter: parent.verticalCenter
            size: Enums.Default

            // Switch 被点击时会自己改 checked，绑定就被冲掉了；
            // 所以每次 mode 变化都重建一次绑定，保证开关与主题始终一致
            function syncFromTheme() {
                themeSwitch.checked = Qt.binding(function () {
                    return Theme.mode === Theme.Dark;
                });
            }

            Component.onCompleted: themeSwitch.syncFromTheme()
            onToggled: Theme.mode = themeSwitch.checked ? Theme.Dark : Theme.Light

            Connections {
                target: Theme

                function onModeChanged() { themeSwitch.syncFromTheme(); }
            }
        }
    }
}
