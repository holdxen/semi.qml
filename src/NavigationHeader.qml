pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 导航头部（semi-ui/navigation/Header.tsx 的整份对应）。
//
//     NavigationHeader {
//         logo: semiLogo          // Component，36×36
//         text: "Semi 运营后台"
//     }
//
// 皮肤（navigation.scss:357-387、543-555）：
//   竖直档 padding：top 32 / bottom 36 / left 3.5 / right 8 ——
//   那个 3.5 是 `(60 − 8×2 − 1 − 36) × 0.5`（variables.scss:50），让 36 的 logo
//   在收起后的 43 内容宽里正好居中；收起态 right 归 0、整行居中
//   （`-collapsed .header { justify-content: center }`），logo 右边距 8 → 0。
//   logo 槽 36×36（`-header-logo > icon/img { width/height: 36 }`）；
//   标题 font-size-header-5（18）、字重 600、色 text-0。
//   **收起态标题直接不渲染**（Header.tsx:63 的 `!isCollapsed` 条件，不是 opacity 0 ——
//   scss 里那条 `-header-text` 的 opacity 0 规则活着但没人吃到）。
//   水平档 header 没有内边距，行内垂直居中（logo 右边距 24 由 Navigation 布局）。
//
// 与官方的差异：
//   · `link` / `linkOptions`（包一层 <a>）在 QML 没有落点，不搬；
//     `style` / `className` 是 DOM 内联样式（坑 91）；
//   · `logo` 官方收 ReactNode（string | element），这里收 Component（36×36 由本组件约束，
//     官方是 CSS 对 `> .semi-icon / > img` 施加 36×36 + object-fit: scale-down）；
//   · children 槽官方排在 logo 与 text 之后，这里同样追加在行尾。
Item {
    id: control

    /// 官方 logo（ReactNode 档 → Component）
    property var logo: undefined
    /// 官方 text
    property var text: ""

    /// Navigation 注入：收起态与水平档
    property bool collapsed: false
    property bool navHorizontal: false

    default property alias content: headerRow.data

    readonly property real paddingXLeft: 3.5
    readonly property real paddingXRight: control.collapsed ? 0 : 8

    implicitHeight: Math.max(36, headerRow.height)
        + (control.navHorizontal ? 0 : 32 + 36)
    implicitWidth: headerRow.implicitWidth
        + (control.navHorizontal ? 0 : control.paddingXLeft + control.paddingXRight)

    Row {
        id: headerRow

        // 竖直展开：paddingLeft 3.5；收起：整行居中（logo 单独时与 3.5 同值 ——
        // 3.5 + 36/2 = 21.5 = 43/2）；水平：贴左、行内垂直居中
        x: control.navHorizontal ? 0
            : (control.collapsed ? Math.max(0, (control.parent.width - width) / 2)
                : control.paddingXLeft)
        y: control.navHorizontal ? (control.height - height) / 2 : 32
        spacing: control.collapsed ? 0 : 8

        Item {
            id: logoHost

            visible: control.logo !== undefined && control.logo !== null
            width: 36
            height: 36

            Loader {
                anchors.fill: parent
                sourceComponent: control.logo !== undefined && control.logo !== null
                    ? control.logo : null
            }
        }

        Text {
            anchors.verticalCenter: logoHost.visible ? logoHost.verticalCenter : parent.verticalCenter
            visible: control.text !== undefined && control.text !== null
                && control.text !== "" && !control.collapsed
            text: control.text === undefined || control.text === null ? "" : String(control.text)
            color: Theme.current.colorText0
            font.pixelSize: Theme.current.fontSizeHeader5
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }
}
