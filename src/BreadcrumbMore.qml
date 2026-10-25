pragma ComponentBehavior: Bound

import QtQuick

// 面包屑折叠时那枚省略号格。官方 index.tsx:163-190 的 `spread` 那段：
//   <span class="-collapse">                     ← inline-flex / flex-shrink: 0
//     <span class="-item-wrap">                  ← margin 4px 0 / margin-right 4
//       <span class="-item -item-more" role="button" tabIndex=0
//             aria-label="Expand breadcrumb items"
//             onClick=展开 onKeyPress=Enter 展开>
//         {renderMore ? renderMore(restItem)
//           : moreType==='default' ? <IconMore/>
//           : <Popover content={restItem 拼上 -restItem 分隔符}><IconMore/></Popover>}
//       </span>
//       <span class="-separator">{separator}</span>   ← 用的是**父级**那份，不是条目自己的
//     </span>
//   </span>
//
// 端口差异：
//   · `renderMore(restItem)` 官方拿到的是节点数组，端口注给 Component 根项的是 item 信息数组
//     （`[{ label, icon, route, href, noLink, info }]`），同时把它当函数调用也支持；
//   · `role` / `tabIndex` / `aria-label` 那三样在 QML 里没有等价物，Enter 展开用 Keys 处理
//     （要真的能吃到按键，得先有焦点：宿主没给 focusPolicy，端口照全站口径不劫键盘）；
//   · Popover 里那些副本条目端口是**重新造的 BreadcrumbItem**（官方是把原节点搬进去），
//     外观一致，副本也照样可点。
Item {
    id: control

    /// 宿主。同 src/TreeRow.qml 的口径用 var：这里声明成 `property Breadcrumb host` 的话，
    /// 宿主文件里 `host: control` 会被 qmllint 判成「Cannot assign binding of type
    /// Breadcrumb to Breadcrumb」（自指类型假阳性）
    property var host: null
    /// 被折掉的那几节（宿主算好递进来）
    property var restItems: []
    /// 宿主排布时写的格序（-1 = 还没排）
    property int cellIndex: -1

    signal expandRequested()

    readonly property real gap: Theme.current.spacingExtraTight
    readonly property bool hasRenderMore: host !== null && host.hasRenderMore
    readonly property bool moreIsPopover: host !== null && host.moreIsPopover
    readonly property real iconSize: host !== null ? host.moreIconSize : Theme.current.widthIconMedium
    readonly property real lineHeight: host !== null ? host.lineHeight : 16
    readonly property real fontSize: host !== null ? host.fontSize : Theme.current.fontSizeSmall
    readonly property string separatorText: host !== null ? host.separatorText : ""
    readonly property bool separatorIsNode: host !== null && host.separatorIsNode

    implicitWidth: lineRow.width + gap
    implicitHeight: lineHeight + gap * 2

    // 展开：官方 foundation.handleExpand（setState isCollapsed:false），没有再收回去的口子
    function expand() {
        control.expandRequested();
    }

    Row {
        id: lineRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: control.gap

        Item {
            id: moreBox

            objectName: "bcMoreItem"
            width: Math.max(moreContent.width, moreIcon.visible ? moreIcon.width : 0)
            height: control.lineHeight

            Loader {
                id: moreContent

                objectName: "bcMoreRender"
                anchors.verticalCenter: parent.verticalCenter
                visible: control.hasRenderMore
                sourceComponent: control.hasRenderMore ? control.host.renderMore : null
                onLoaded: {
                    control.host.give(item, "restItems", control.restItems);
                    control.host.give(item, "host", control.host);
                }
            }

            // 没给 renderMore 时那枚 IconMore（popover 档外面再套一层浮层）
            Icon {
                id: moreIcon

                objectName: "bcMoreIcon"
                anchors.verticalCenter: parent.verticalCenter
                visible: !control.hasRenderMore
                name: "more"
                size: control.iconSize
                color: Theme.current.colorText2
            }

            HoverHandler {
                id: moreHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                objectName: "bcMoreTap"

                acceptedButtons: Qt.LeftButton
                onTapped: control.expand()
            }

            Keys.onReturnPressed: control.expand()
            Keys.onEnterPressed: control.expand()
        }

        // 分隔符：折叠格用的是父级那份（index.tsx:182-184）
        Text {
            objectName: "bcMoreSeparator"
            anchors.verticalCenter: parent.verticalCenter
            visible: control.separatorIsNode ? false : control.separatorText !== ""
            text: control.separatorText
            font.pixelSize: control.fontSize
            color: Theme.current.colorText2
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            visible: control.separatorIsNode
            sourceComponent: control.separatorIsNode ? control.host.separator : null
        }
    }

    // moreType === 'popover'：IconMore 当触发，浮层里摆被折掉的那几节 + -restItem 分隔符
    Popover {
        id: restPop

        objectName: "bcRestPopover"
        target: moreIcon
        showArrow: true
        enabled: control.moreIsPopover && !control.hasRenderMore && control.restItems.length > 0
        position: Enums.Top

        Row {
            id: restRow

            objectName: "bcRestRow"
            spacing: 0

            Repeater {
                id: restRepeater

                model: control.restItems

                delegate: Item {
                    id: restCell

                    required property var modelData
                    required property int index

                    objectName: "bcRestCell" + restCell.index
                    implicitWidth: cellRow.width
                    implicitHeight: cellRow.height

                    Row {
                        id: cellRow

                        spacing: control.gap

                        BreadcrumbItem {
                            objectName: "bcRestItem" + restCell.index
                            host: control.host
                            fromRepeater: true
                            route: restCell.modelData.route
                            label: restCell.modelData.label
                            icon: restCell.modelData.icon
                            href: restCell.modelData.href
                            noLink: restCell.modelData.noLink
                            // 浮层里那几节自己不带分隔符（shouldRenderSeparator 那条），
                            // 分隔符由 -restItem 那层给
                            shouldRenderSeparator: false
                            active: false
                        }

                        // -restItem { color: text-2; margin-right: 8 }，最后一条后面不加
                        Text {
                            objectName: "bcRestSeparator" + restCell.index
                            anchors.verticalCenter: parent.verticalCenter
                            visible: restCell.index < control.restItems.length - 1
                                && !control.separatorIsNode
                            text: control.separatorText
                            font.pixelSize: control.fontSize
                            color: Theme.current.colorText2
                            rightPadding: control.host !== null ? control.host.restGap : 8
                        }

                        Loader {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: restCell.index < control.restItems.length - 1
                                && control.separatorIsNode
                            sourceComponent: control.separatorIsNode ? control.host.separator : null
                        }
                    }
                }
            }
        }
    }
}
