pragma ComponentBehavior: Bound

import QtQuick

// 卡片的 Meta 区。官方 `packages/semi-ui/card/meta.tsx`（MetaProps :10-19、render :36-70）
// + `semi-foundation/card/card.scss` 的 `-meta` 那一段。QML 里没法写 `Card.Meta`，
// 所以它是独立类型 —— 用法就是官方 `<Card><Card.Meta … /></Card>` 的那一处。
//
//     Card {
//         width: 300
//         CardMeta {
//             title: "Semi Doc"
//             description: "全面、易用、优质"
//             avatar: Component { Avatar { text: "S" } }
//         }
//     }
//
// 结构（meta.tsx 只有这一种排法）：`-meta` 是 `display:flex; align-items:center;
// justify-content:flex-start`，里面最多两块 —— `-meta-avatar`（`margin-right:
// $spacing-card_avatar-marginRight` = base-tight 12）和 `-meta-wrapper`（title 与
// description 两个 block div 竖着叠，中间没有间距）。
// 三块都用真值判断：`avatar && …` / `title && …` / `description && …`（:47 / :52 / :57），
// 所以 `title: ""` 那一格连 div 都不生成；title 与 description 都没给时 **整个 wrapper 也不生成**
// （:62 `title || description ? … : null`）。
//
// 度量（card.scss `-meta-wrapper-title/-description` + variables.scss）：
//   · title：16 / 22 / **700** / text-0 —— 比卡片 header 那个标题（Typography heading6 ⇒ 600）
//     重一档，两条规则来自不同的令牌，别抄混。
//   · description：14 / 20 / regular / text-2。
//
// 端口差异：`className` / `style` 收了不产出可见差异（官方只喂 DOM）；ReactNode 档同样是
// 「字符串（或数字）或 Component」。
Item {
    id: control

    // ---- 官方 MetaProps（meta.tsx:10-19）----
    property var avatar: undefined
    property string className: ""              // 死 prop
    property var description: undefined
    property var style: undefined              // 死 prop
    property var title: undefined

    // ---- 派生（三处真值判断）----
    readonly property bool avatarTaken: control._taken(control.avatar)
    readonly property bool titleTaken: control._taken(control.title)
    readonly property bool descriptionTaken: control._taken(control.description)
    readonly property bool wrapperTaken: control.titleTaken || control.descriptionTaken

    // ---- 令牌 ----
    readonly property real avatarGap: Theme.current.spacingBaseTight     // $spacing-card_avatar-marginRight
    readonly property real lineHeight: 20                                // $font-card_default-lineHeight

    readonly property real avatarHeight: control.avatarTaken
        ? (control._isText(control.avatar) ? avatarText.implicitHeight : avatarLoader.implicitHeight) : 0
    readonly property real avatarWidth: control.avatarTaken
        ? (control._isText(control.avatar) ? avatarText.implicitWidth : avatarLoader.implicitWidth) : 0
    readonly property real titleHeight: control.titleTaken
        ? (control._isText(control.title) ? titleText.implicitHeight : titleLoader.implicitHeight) : 0
    readonly property real descriptionHeight: control.descriptionTaken
        ? (control._isText(control.description) ? descriptionText.implicitHeight
            : descriptionLoader.implicitHeight) : 0
    readonly property real wrapperHeight: control.titleHeight + control.descriptionHeight
    readonly property real wrapperWidth: Math.max(control.titleTaken
        ? (control._isText(control.title) ? titleText.implicitWidth : titleLoader.implicitWidth) : 0,
        control.descriptionTaken
            ? (control._isText(control.description)
                ? descriptionText.implicitWidth : descriptionLoader.implicitWidth) : 0)

    // align-items: center ⇒ 两块都以行为轴居中
    readonly property real rowHeight: Math.max(control.avatarHeight, control.wrapperHeight)

    implicitWidth: (control.avatarTaken ? control.avatarWidth + control.avatarGap : 0)
        + (control.wrapperTaken ? control.wrapperWidth : 0)
    implicitHeight: control.rowHeight

    // ---- -meta-avatar ----
    // 普通 Item 不 hug 子项，所以块宽/块高都是逐格从节点上读出来的（不是 implicitWidth）
    Loader {
        id: avatarLoader

        objectName: "cardMetaAvatar"

        x: 0
        y: (control.rowHeight - control.avatarHeight) / 2
        visible: control.avatarTaken && !control._isText(control.avatar)
        active: visible
        sourceComponent: control._nodeOf(control.avatar)
    }

    Text {
        id: avatarText

        objectName: "cardMetaAvatarText"

        x: 0
        y: (control.rowHeight - height) / 2
        visible: control.avatarTaken && control._isText(control.avatar)
        text: control._isText(control.avatar) ? String(control.avatar) : ""
        color: Theme.current.colorText1
        font.pixelSize: Theme.current.fontSizeRegular
        lineHeight: control.lineHeight
        lineHeightMode: Text.FixedHeight
    }

    // ---- -meta-wrapper ----
    Item {
        id: wrapperBlock

        objectName: "cardMetaWrapper"

        x: control.avatarTaken ? control.avatarWidth + control.avatarGap : 0
        y: (control.rowHeight - control.wrapperHeight) / 2
        width: control.wrapperWidth
        height: control.wrapperHeight
        visible: control.wrapperTaken

        Loader {
            id: titleLoader

            objectName: "cardMetaTitleNode"

            y: 0
            visible: control.titleTaken && !control._isText(control.title)
            active: visible
            sourceComponent: control._nodeOf(control.title)
        }

        Text {
            id: titleText

            objectName: "cardMetaTitleText"

            // -meta-wrapper-title：16 / 22 / 700 / text-0
            y: 0
            visible: control.titleTaken && control._isText(control.title)
            text: control._isText(control.title) ? String(control.title) : ""
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeHeader6
            font.weight: Font.Bold
            lineHeight: 22
            lineHeightMode: Text.FixedHeight
            elide: Text.ElideRight
        }

        Loader {
            id: descriptionLoader

            objectName: "cardMetaDescriptionNode"

            y: control.titleHeight
            visible: control.descriptionTaken && !control._isText(control.description)
            active: visible
            sourceComponent: control._nodeOf(control.description)
        }

        Text {
            id: descriptionText

            objectName: "cardMetaDescriptionText"

            // -meta-wrapper-description：14 / 20 / regular / text-2
            y: control.titleHeight
            visible: control.descriptionTaken && control._isText(control.description)
            text: control._isText(control.description) ? String(control.description) : ""
            color: Theme.current.colorText2
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: control.lineHeight
            lineHeightMode: Text.FixedHeight
            elide: Text.ElideRight
        }
    }

    // ------------------------------------------------------------------ 小工具
    function _taken(value) {
        return !!value;
    }

    function _isText(value) {
        return typeof value === "string" || typeof value === "number";
    }

    function _nodeOf(value) {
        return control._taken(value) && !control._isText(value) ? value : null;
    }
}
