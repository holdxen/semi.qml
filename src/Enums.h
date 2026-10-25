#pragma once

#include <QObject>
#include <QtQmlIntegration/qqmlintegration.h>

namespace semi {

// 各组件的公共枚举。QML 里没有模块级枚举，统一挂在这个单例上：
//     Button { tone: Enums.Primary; variant: Enums.Outline; size: Enums.Large }
class Enums : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    // 语义色调
    enum Tone {
        Primary,
        Secondary,
        Tertiary,
        Warning,
        Danger,
        Info,
        Success,
        Neutral,   // 中性文本色，用于不需要着色的场合
        Quaternary,  // 排版第四级文本色（text-3），追加在末尾以免打乱上面这些的数值
    };
    Q_ENUM(Tone)

    // 形态
    enum Variant {
        Solid,
        Light,
        Outline,
        Borderless,
    };
    Q_ENUM(Variant)

    // 尺寸
    enum Size {
        Small,
        Default,
        Large,
        // 排版组件专用：继承外层 TextLabel / Paragraph 的尺寸
        // （$size-typography_* = normal | small | inherit，constants.ts:10）
        Inherit,
    };
    Q_ENUM(Size)

    // 段落行距（$size-typography_paragraph-spacing-* / constants.ts:11）
    enum Spacing {
        SpacingNormal,
        SpacingExtended,   // 24px，normal 是 20px
    };
    Q_ENUM(Spacing)

    // 交互状态，优先级 disabled > focused > pressed > hovered > normal
    enum State {
        Normal,
        Hovered,
        Pressed,
        Focused,
        Disabled,
    };
    Q_ENUM(State)

    // 表单校验状态（加前缀避免与 Tone / Size 的枚举值重名）
    enum Status {
        StatusDefault,
        StatusWarning,
        StatusDanger,
    };
    Q_ENUM(Status)

    // 弹层相对锚点的方位。TopLeft 表示「在上方、左对齐」，其余同理。
    enum Placement {
        Top,
        TopLeft,
        TopRight,
        Bottom,
        BottomLeft,
        BottomRight,
        Left,
        LeftTop,
        LeftBottom,
        Right,
        RightTop,
        RightBottom,
    };
    Q_ENUM(Placement)

    // 选择器样式类型（$type：default | card | pureCard，semi-ui/checkbox/checkboxGroup.tsx:12；
    // Radio 多一个 button，radio/constants.ts 的 TYPE_BUTTON）
    enum ChoiceType {
        ChoiceDefault,
        ChoiceCard,
        ChoicePureCard,
        ChoiceButton,
    };
    Q_ENUM(ChoiceType)

    // 按钮式单选的尺寸（strings.BUTTON_SIZE: ['middle','small','large']，默认 middle）
    enum RadioButtonSize {
        RadioButtonSmall,
        RadioButtonMiddle,
        RadioButtonLarge,
    };
    Q_ENUM(RadioButtonSize)

    // 组内排列方向。CheckboxGroup 默认 vertical、RadioGroup 默认 horizontal
    // （两边各自的 DEFAULT_DIRECTION，radio/constants.ts:22）
    enum Direction {
        DirectionVertical,
        DirectionHorizontal,
    };
    Q_ENUM(Direction)

    // 颜色格式（semi-ui/colorPicker/index.tsx:28 的 defaultFormat：hex | rgba | hsva）
    enum ColorFormat {
        FormatHex,
        FormatRgba,
        FormatHsva,
    };
    Q_ENUM(ColorFormat)

    // 日期选择类型（semi-foundation/datePicker/constants.ts:48 的 TYPE_SET）
    enum DatePickerType {
        TypeDate,
        TypeDateRange,
        TypeYear,
        TypeMonth,
        TypeMonthRange,
        TypeDateTime,
        TypeDateTimeRange,
    };
    Q_ENUM(DatePickerType)

    // 面板疏密（API 表 density：default | compact）
    enum Density {
        DensityDefault,
        DensityCompact,
    };
    Q_ENUM(Density)

    // 快捷方式面板位置（constants.ts:49 PRESET_POSITION_SET）
    enum PresetPosition {
        PresetLeft,
        PresetRight,
        PresetTop,
        PresetBottom,
    };
    Q_ENUM(PresetPosition)
};

} // namespace semi
