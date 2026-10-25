#include "Appearance.h"

#include "Enums.h"
#include "SemiThemeValues.h"

namespace semi {

namespace {

struct ToneColors
{
    QColor base;
    QColor hover;
    QColor active;
};

// 色值来源：semi-foundation/button/variables.scss
ToneColors toneColors(const SemiThemeValues *t, int tone)
{
    switch (tone) {
    case Enums::Secondary:
        return { t->colorSecondary(), t->colorSecondaryHover(), t->colorSecondaryActive() };
    case Enums::Tertiary:
        return { t->colorTertiary(), t->colorTertiaryHover(), t->colorTertiaryActive() };
    case Enums::Warning:
        return { t->colorWarning(), t->colorWarningHover(), t->colorWarningActive() };
    case Enums::Danger:
        return { t->colorDanger(), t->colorDangerHover(), t->colorDangerActive() };
    case Enums::Info:
        return { t->colorInfo(), t->colorInfoHover(), t->colorInfoActive() };
    case Enums::Success:
        return { t->colorSuccess(), t->colorSuccessHover(), t->colorSuccessActive() };
    case Enums::Primary:
    default:
        return { t->colorPrimary(), t->colorPrimaryHover(), t->colorPrimaryActive() };
    }
}

} // namespace

Appearance::Appearance(QObject *parent)
    : QObject(parent)
{
}

int Appearance::state(bool enabled, bool hovered, bool pressed) const
{
    if (!enabled)
        return Enums::Disabled;
    if (pressed)
        return Enums::Pressed;
    if (hovered)
        return Enums::Hovered;
    return Enums::Normal;
}

QColor Appearance::buttonBackground(const SemiThemeValues *t, int tone, int variant, int state) const
{
    if (!t)
        return {};

    if (state == Enums::Disabled) {
        switch (variant) {
        case Enums::Light:
            return t->colorFill0();              // disabled_light_*_bg = fill-0
        case Enums::Outline:
        case Enums::Borderless:
            return Qt::transparent;
        default:
            return t->colorDisabledBg();
        }
    }

    switch (variant) {
    case Enums::Light:
        if (state == Enums::Hovered)
            return t->colorFill1();
        if (state == Enums::Pressed)
            return t->colorFill2();
        return t->colorFill0();
    case Enums::Outline:
    case Enums::Borderless:
        if (state == Enums::Hovered)
            return t->colorFill0();
        if (state == Enums::Pressed)
            return t->colorFill1();
        return Qt::transparent;
    case Enums::Solid:
    default: {
        const ToneColors c = toneColors(t, tone);
        if (state == Enums::Hovered)
            return c.hover;
        if (state == Enums::Pressed)
            return c.active;
        return c.base;
    }
    }
}

QColor Appearance::buttonForeground(const SemiThemeValues *t, int tone, int variant, int state) const
{
    if (!t)
        return {};

    if (state == Enums::Disabled)
        return t->colorDisabledText();

    if (variant == Enums::Solid)
        return t->colorWhite();                  // solid 一律白字（tertiary 也是）

    // light / outline / borderless：tertiary 走次级文本色，其余用各自基色
    // （对应 $color-button_tertiary_solid-text-default 那条规则）
    if (tone == Enums::Tertiary)
        return t->colorText1();
    return toneColors(t, tone).base;
}

QColor Appearance::buttonBorderColor(const SemiThemeValues *t, int tone, int variant, int state) const
{
    if (!t)
        return {};

    if (variant != Enums::Outline)
        return Qt::transparent;                  // 其余形态边框宽度为 0

    if (state == Enums::Disabled)
        return t->colorBorder();
    if (tone == Enums::Danger || tone == Enums::Warning)
        return toneColors(t, tone).base;         // 这两个用自身色描边
    return t->colorBorder();
}

int Appearance::buttonBorderWidth(int variant) const
{
    return variant == Enums::Outline ? 1 : 0;
}

QColor Appearance::buttonFocusRing(const SemiThemeValues *t, int tone, int variant) const
{
    if (!t)
        return {};

    // button.scss:32-40 那条基规则不分形态、五种 type 一律描 primary 的 light-active；
    // danger / warning 再各补一条 :not(.borderless):not(.light) 换自身色（85-87 / 127-129）。
    // 也就是说 secondary / tertiary 永远描 primary 色，light 与 borderless 形态的
    // danger / warning 也描 primary 色 —— 官方就是这么不一致，这里照抄。
    const bool ownColor = (tone == Enums::Danger || tone == Enums::Warning)
            && variant != Enums::Borderless && variant != Enums::Light;
    if (ownColor)
        return tone == Enums::Danger ? t->colorDangerLightActive() : t->colorWarningLightActive();
    return t->colorPrimaryLightActive();
}

QColor Appearance::buttonGroupLine(const SemiThemeValues *t, int tone, int variant, int state) const
{
    if (!t)
        return {};

    // button.scss:470-514 那批 .semi-button-group-line-* 全是单类选择器、特异度相同，
    // 谁在后面谁赢：-disabled(495) 压过五种 type，-light(499) 与 -borderless(503) 又压过 -disabled。
    // outline 形态压根不插线（buttonGroup.tsx:50 的 theme !== 'outline'）。
    if (variant == Enums::Light)
        return t->colorFill0();
    if (variant == Enums::Borderless)
        return Qt::transparent;
    if (state == Enums::Disabled)
        return t->colorDisabledBg();
    return toneColors(t, tone).base;
}

int Appearance::buttonHeight(const SemiThemeValues *t, int size) const
{
    if (!t)
        return 32;
    switch (size) {
    case Enums::Small:
        return t->heightControlSmall();
    case Enums::Large:
        return t->heightControlLarge();
    default:
        return t->heightControlDefault();
    }
}

int Appearance::buttonPaddingHorizontal(const SemiThemeValues *t, int size) const
{
    if (!t)
        return 12;
    // $spacing-button_default/small-paddingLR = spacing-base-tight；large = spacing-base
    return size == Enums::Large ? t->spacingBase() : t->spacingBaseTight();
}

int Appearance::buttonPaddingVertical(const SemiThemeValues *t, int size) const
{
    // Semi 里 paddingTop/Bottom 硬编码为 6 / 10 / 2，
    // 恰好等于 (控件高度 - 按钮行高 20) / 2
    return qMax(0, (buttonHeight(t, size) - 20) / 2);
}

int Appearance::buttonFontSize(const SemiThemeValues *t, int size) const
{
    Q_UNUSED(size)
    return t ? t->fontSizeRegular() : 14;        // 三档都是 14
}

int Appearance::fieldState(bool enabled, bool focused, bool hovered, bool pressed) const
{
    if (!enabled)
        return Enums::Disabled;
    if (focused)
        return Enums::Focused;
    if (pressed)
        return Enums::Pressed;
    if (hovered)
        return Enums::Hovered;
    return Enums::Normal;
}

// ---------------------------------------------------------------------------
// Input —— 色值来源 semi-foundation/input/variables.scss
// ---------------------------------------------------------------------------

int Appearance::inputWrapperHeight(const SemiThemeValues *t, int size) const
{
    return buttonHeight(t, size);
}

int Appearance::inputPaddingHorizontal(const SemiThemeValues *t) const
{
    // $spacing-input-paddingLeft/Right = spacing-base-tight
    return t ? t->spacingBaseTight() : 12;
}

QColor Appearance::inputBackground(const SemiThemeValues *t, int state, int status) const
{
    if (!t)
        return {};

    if (state == Enums::Disabled)
        return t->colorDisabledFill();

    if (status == Enums::StatusDanger) {
        if (state == Enums::Pressed)
            return t->colorDangerLightActive();
        if (state == Enums::Hovered)
            return t->colorDangerLightHover();
        return t->colorDangerLightDefault();
    }
    if (status == Enums::StatusWarning) {
        if (state == Enums::Pressed)
            return t->colorWarningLightActive();
        if (state == Enums::Hovered)
            return t->colorWarningLightHover();
        return t->colorWarningLightDefault();
    }

    if (state == Enums::Pressed)
        return t->colorFill2();
    if (state == Enums::Hovered)
        return t->colorFill1();
    return t->colorFill0();                      // 含 focus —— 聚焦时回到 fill-0
}

QColor Appearance::inputBorderColor(const SemiThemeValues *t, int state, int status) const
{
    if (!t)
        return {};

    if (state == Enums::Disabled)
        return t->colorDisabledBorder();

    if (state != Enums::Focused)
        return Qt::transparent;                  // 只有聚焦才有描边

    if (status == Enums::StatusDanger)
        return t->colorDanger();
    if (status == Enums::StatusWarning)
        return t->colorWarning();
    return t->colorFocusBorder();
}

QColor Appearance::inputForeground(const SemiThemeValues *t, int state) const
{
    if (!t)
        return {};
    return state == Enums::Disabled ? t->colorDisabledText() : t->colorText0();
}

QColor Appearance::inputPlaceholderColor(const SemiThemeValues *t, int state) const
{
    if (!t)
        return {};
    return state == Enums::Disabled ? t->colorDisabledText() : t->colorText2();
}

QColor Appearance::inputIconColor(const SemiThemeValues *t, int state) const
{
    if (!t)
        return {};
    return state == Enums::Disabled ? t->colorDisabledText() : t->colorText2();
}

QColor Appearance::tagInputBorder(const SemiThemeValues *t, int state, int status) const
{
    if (!t)
        return {};

    // tagInput.scss:77-105：warning / error 平时就带浅色描边，聚焦换实色
    if (status == Enums::StatusWarning) {
        if (state == Enums::Focused)
            return t->colorWarning();
        if (state == Enums::Hovered)
            return t->colorWarningLightHover();
        return t->colorWarningLightDefault();
    }
    if (status == Enums::StatusDanger) {
        if (state == Enums::Focused)
            return t->colorDanger();
        if (state == Enums::Hovered)
            return t->colorDangerLightHover();
        return t->colorDangerLightDefault();
    }
    // 默认态与 Input 相反：只有聚焦才画描边（禁用也是透明的，.semi-tag-input-disabled
    // 只换背景，没有 Input 的 disabled-border）
    if (state == Enums::Focused)
        return t->colorFocusBorder();
    return Qt::transparent;
}

// ---------------------------------------------------------------------------
// Switch —— $color-switch_*
// ---------------------------------------------------------------------------

QColor Appearance::switchTrack(const SemiThemeValues *t, bool checked, int state, bool loading) const
{
    if (!t)
        return {};

    // 加载态走 $color-switch_spin_unchecked/checked-bg-default，不看 hover ——
    // .semi-switch:hover 特异度比 .semi-switch-loading 高，但两条算出来的值一样。
    // 禁用 + 加载 + 选中仍是 success-disabled：后面那条同特异度的
    // .semi-switch-disabled.semi-switch-checked 取胜（switch.css:68 / :145 / :174）
    if (loading) {
        if (!checked)
            return t->colorFill1();
        return state == Enums::Disabled ? t->colorSuccessDisabled() : t->colorSuccessHover();
    }

    // $color-switch_disabled-bg-* 全透明，只有禁用开启态有颜色
    if (state == Enums::Disabled)
        return checked ? t->colorSuccessDisabled() : Qt::transparent;
    if (checked) {
        // $color-switch_checked-bg-hover / -default；:active 没定义开启态背景，仍是 default
        return state == Enums::Hovered ? t->colorSuccessHover() : t->colorSuccess();
    }
    return state == Enums::Hovered ? t->colorFill1() : t->colorFill0();
}

QColor Appearance::switchTrackBorder(const SemiThemeValues *t, bool checked, int state) const
{
    if (!t)
        return {};

    // 未选中按下时描边取 $color-switch_default-bg-active；.semi-switch:active 比
    // .semi-switch-disabled 优先级高，所以按下会盖过禁用态
    if (state == Enums::Pressed)
        return t->colorFill2();
    if (state == Enums::Disabled)
        return checked ? Qt::transparent : t->colorBorder();
    return Qt::transparent;
}

QColor Appearance::switchKnob(const SemiThemeValues *t, bool checked, bool enabled) const
{
    if (!t)
        return {};
    Q_UNUSED(checked)
    Q_UNUSED(enabled)
    return t->colorWhite();
}

QColor Appearance::switchKnobBorder(const SemiThemeValues *t, bool checked, int state) const
{
    if (!t)
        return {};

    if (state == Enums::Disabled && !checked)
        return t->colorBorder();
    return Qt::transparent;
}

// ---------------------------------------------------------------------------
// Checkbox / Radio 共用 —— 空框、选中框、卡片底
// 两边的 token 值与状态规则逐条对得上，所以只留一组函数（见 Appearance.h 的对照表）
// ---------------------------------------------------------------------------

QColor Appearance::choiceBoxBackground(const SemiThemeValues *t, bool fill, bool card, int state) const
{
    if (!t)
        return {};

    // 禁用优先：选中用 primary-disabled，未选中用 disabled-fill
    // （checkbox.scss:315-324, 326-339 ↔ radio.scss:351-363 + $color-radio_checked-bg-disabled）
    if (state == Enums::Disabled)
        return fill ? t->colorPrimaryDisabled() : t->colorDisabledFill();

    if (fill) {
        if (state == Enums::Pressed)
            return t->colorPrimaryActive();
        if (state == Enums::Hovered)
            return t->colorPrimaryHover();
        return t->colorPrimary();
    }
    // 卡片里的空框永远填白（$color-checkbox_cardType_inner-bg-* ↔ $color-radio_card-bg-*）
    if (card)
        return t->colorWhite();
    // 未选中的空框：默认透明，悬浮 fill-0，按下 fill-1
    // （checkbox.scss:48-73 ↔ radio.scss:36-45 + $color-radio_default-bg-hover/-active）
    if (state == Enums::Pressed)
        return t->colorFill1();
    if (state == Enums::Hovered)
        return t->colorFill0();
    return Qt::transparent;
}

QColor Appearance::choiceBoxBorderColor(const SemiThemeValues *t, bool fill, int state) const
{
    if (!t)
        return {};

    if (state == Enums::Disabled)
        return fill ? t->colorPrimaryDisabled() : t->colorBorder();

    if (fill) {
        if (state == Enums::Pressed)
            return t->colorPrimaryActive();
        if (state == Enums::Hovered)
            return t->colorPrimaryHover();
        return t->colorPrimary();
    }
    // 未选中悬浮时描边换成 focus-border（checkbox.scss:48-52 ↔ radio.scss:38-41
    // $color-radio_default-border-hover）。按下必然也在悬浮中，官方 :active 块只改背景，
    // 所以按下一样是 focus-border。
    if (state == Enums::Hovered || state == Enums::Pressed || state == Enums::Focused)
        return t->colorFocusBorder();
    // 默认描边 text-3（$color-checkbox/radio_default-border-default）
    return t->colorText3();
}

QColor Appearance::choiceCardBackground(const SemiThemeValues *t, bool checked, int state) const
{
    if (!t)
        return {};

    // 选中（含选中且禁用）都是 primary-light-default
    // （checkbox.scss:238-255, 267-276 ↔ radio.scss:140-142, 181-184）
    if (checked)
        return t->colorPrimaryLightDefault();
    // 禁用的卡片悬浮 / 按下都被强制回透明（checkbox.scss:257-265 ↔ radio.scss:175-180）
    if (state == Enums::Disabled)
        return Qt::transparent;
    if (state == Enums::Pressed)
        return t->colorFill1();
    if (state == Enums::Hovered)
        return t->colorFill0();
    return Qt::transparent;
}

QColor Appearance::choiceCardBorderColor(const SemiThemeValues *t, bool checked, int state) const
{
    if (!t)
        return {};

    if (!checked)
        return Qt::transparent;   // $color-checkbox/radio_cardRadioGroup_border-default
    if (state == Enums::Disabled)
        return t->colorPrimaryDisabled();
    if (state == Enums::Pressed)
        return t->colorPrimaryActive();
    if (state == Enums::Hovered)
        return t->colorPrimaryHover();
    return t->colorPrimary();
}

// ---------------------------------------------------------------------------
// Radio —— 按钮式单选项（.semi-radio-addon-buttonRadio，radio.scss:277-311）
// ---------------------------------------------------------------------------

QColor Appearance::radioButtonAddonBackground(const SemiThemeValues *t, bool checked, int state) const
{
    if (!t)
        return {};

    // 选中项 bg-3（$color-radio_addon_buttonRadio-bg-checked）；禁用时官方只改字色，
    // 背景沿用当前态（radio.scss:305-311 的 -disabled 里没有 background）
    if (checked)
        return t->colorBg3();
    if (state == Enums::Disabled)
        return Qt::transparent;
    if (state == Enums::Hovered || state == Enums::Pressed)
        return t->colorFill1();   // $color-radio_addon_buttonRadio-bg-hover
    return Qt::transparent;
}

QColor Appearance::radioButtonAddonColor(const SemiThemeValues *t, bool checked, int state) const
{
    if (!t)
        return {};

    if (state == Enums::Disabled)
        return t->colorDisabledText();  // $color-radio_buttonRadio-text-disabled
    if (checked)
        return t->colorPrimary();       // $color-radio_addon_buttonRadio-text-checked
    return t->colorText1();             // $color-radio_buttonRadio-text-default
}

// ---------------------------------------------------------------------------
// 文字排版
// ---------------------------------------------------------------------------

QColor Appearance::textColor(const SemiThemeValues *t, int tone) const
{
    if (!t)
        return {};

    // 排版的四个层级是 text-0/1/2/3，不是语义色 secondary
    // （semi-foundation/typography/variables.scss 前四行）
    switch (tone) {
    case Enums::Primary:
        return t->colorPrimary();
    case Enums::Secondary:
        return t->colorText1();
    case Enums::Tertiary:
        return t->colorText2();
    case Enums::Quaternary:
        return t->colorText3();
    case Enums::Warning:
        return t->colorWarning();
    case Enums::Danger:
        return t->colorDanger();
    case Enums::Info:
        return t->colorInfo();
    case Enums::Success:
        return t->colorSuccess();
    case Enums::Neutral:
    default:
        return t->colorText0();
    }
}

int Appearance::titleFontSize(const SemiThemeValues *t, int level) const
{
    if (!t)
        return 20;

    switch (level) {
    case 1:
        return t->fontSizeHeader1();   // 32
    case 2:
        return t->fontSizeHeader2();   // 28
    case 3:
        return t->fontSizeHeader3();   // 24
    case 4:
        return t->fontSizeHeader4();   // 20
    case 5:
        return t->fontSizeHeader5();   // 18
    case 6:
    default:
        return t->fontSizeHeader6();   // 16
    }
}

// 官方 h1..h6 的行高（_font.scss 的 font-size-header-n，浏览器实测 44 / 22 两端对齐）
int Appearance::titleLineHeight(const SemiThemeValues *t, int level) const
{
    if (!t)
        return 22;

    switch (level) {
    case 1:
        return 44;
    case 2:
        return 40;
    case 3:
        return 32;
    case 4:
        return 28;
    case 5:
        return 24;
    case 6:
    default:
        return 22;
    }
}

// ---------------------------------------------------------------------------
// Badge / Progress
// ---------------------------------------------------------------------------

QColor Appearance::badgeBackground(const SemiThemeValues *t, int tone, bool light) const
{
    if (!t)
        return {};

    if (light) {
        switch (tone) {
        case Enums::Primary:
        case Enums::Info:
            return t->colorPrimaryLightDefault();
        case Enums::Success:
            return t->colorSuccessLightDefault();
        case Enums::Warning:
            return t->colorWarningLightDefault();
        case Enums::Danger:
            return t->colorDangerLightDefault();
        default:
            return t->colorBg2();
        }
    }

    switch (tone) {
    case Enums::Success:
        return t->colorSuccess();
    case Enums::Warning:
        return t->colorWarning();
    case Enums::Danger:
        return t->colorDanger();
    case Enums::Primary:
    case Enums::Info:
        return t->colorPrimary();
    default:
        return t->colorBg1();
    }
}

QColor Appearance::badgeForeground(const SemiThemeValues *t, int tone, bool light) const
{
    if (!t)
        return {};

    if (!light) {
        switch (tone) {
        case Enums::Success:
        case Enums::Warning:
        case Enums::Danger:
        case Enums::Primary:
        case Enums::Info:
            return t->colorWhite();
        default:
            return t->colorText0();
        }
    }

    switch (tone) {
    case Enums::Success:
        return t->colorSuccess();
    case Enums::Warning:
        return t->colorWarning();
    case Enums::Danger:
        return t->colorDanger();
    case Enums::Primary:
    case Enums::Info:
        return t->colorPrimary();
    default:
        return t->colorText0();
    }
}

QColor Appearance::progressRail(const SemiThemeValues *t) const
{
    return t ? t->colorFill0() : QColor();
}

} // namespace semi
