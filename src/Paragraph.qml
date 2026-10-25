import QtQuick

// 段落。正文 14px / 行高 20px，次要说明用 12px / 16px；
// `spacing: Enums.SpacingExtended` 是官方那个宽松行距（24px）。
//
//     Paragraph { text: "一段说明文字" }
//     Paragraph { size: Enums.Small; tone: Enums.Tertiary; text: "补充说明" }
//     Paragraph { spacing: Enums.SpacingExtended; width: 600; text: "……" }
TypographyBase {
    id: control

    property int spacing: Enums.SpacingNormal

    lineHeight: control.spacing === Enums.SpacingExtended
        ? 24 : (control.isSmall ? 16 : 20)
    lineHeightMode: Text.FixedHeight
}
