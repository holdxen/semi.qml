import QtQuick

// 标题。字号 / 行高对应 Semi 的 $font-size-header-1..6（32/28/24/20/18/16，
// 行高 44/40/32/28/24/22），字重 600（$font-weight-bold 在 Semi 里就是 600）。
//
//     Title { heading: 2; text: "h2. Semi Design" }
//     Title { heading: 5; ellipsis: ({ showTooltip: true }); width: 250; text: "很长的标题" }
TypographyBase {
    id: control

    property int level: 1                  // 历史名字，保留
    property int heading: -1               // 官方叫 heading（1..6）

    readonly property int headingLevel: control.heading > 0 ? control.heading : control.level

    font.pixelSize: Appearance.titleFontSize(Theme.current, control.headingLevel)
    font.weight: control.weight !== Font.Normal ? control.weight : Font.DemiBold
    lineHeight: Appearance.titleLineHeight(Theme.current, control.headingLevel)
    lineHeightMode: Text.FixedHeight
}
