#pragma once

#include <QColor>
#include <QObject>
#include <QtQmlIntegration/qqmlintegration.h>

#include "SemiThemeValues.h"

namespace semi {

// 把「形态 × 色调 × 状态」解析成具体色值，等价于 Semi 那几百行 $color-button-* 展开。
// 组件不自己写 if-else，一律走这里；色值来源见 semi-foundation/button/variables.scss。
//
// 令牌必须由调用方显式传入（组件里写 Appearance.xxx(Theme.current, ...)）：
// QML 只追踪绑定表达式里直接读到的属性，C++ 函数内部去读全局单例的话，
// 主题一变组件的绑定不会重新求值 —— 颜色就不会跟着换。
class Appearance : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Appearance(QObject *parent = nullptr);

    // 把三个开关收敛成一个状态（disabled > pressed > hovered > normal）
    Q_INVOKABLE int state(bool enabled, bool hovered, bool pressed) const;
    // 输入类控件：焦点比 hover/press 更优先
    Q_INVOKABLE int fieldState(bool enabled, bool focused, bool hovered, bool pressed) const;

    // ---- Button ----
    Q_INVOKABLE QColor buttonBackground(const SemiThemeValues *tokens, int tone, int variant, int state) const;
    Q_INVOKABLE QColor buttonForeground(const SemiThemeValues *tokens, int tone, int variant, int state) const;
    Q_INVOKABLE QColor buttonBorderColor(const SemiThemeValues *tokens, int tone, int variant, int state) const;
    Q_INVOKABLE int buttonBorderWidth(int variant) const;
    // focus-visible 时画在按钮外圈的轮廓色（$color-button_*_outline-focus）。
    // 要带 variant：只有 danger / warning 在 solid / outline 形态下换成自身色，见 .cpp
    Q_INVOKABLE QColor buttonFocusRing(const SemiThemeValues *tokens, int tone, int variant) const;
    // ButtonGroup 相邻按钮之间那条分隔线的底色（.semi-button-group-line-*）
    Q_INVOKABLE QColor buttonGroupLine(const SemiThemeValues *tokens, int tone, int variant, int state) const;

    // 尺寸：小 24 / 默认 32 / 大 40，与 $height-button_* 一致
    Q_INVOKABLE int buttonHeight(const SemiThemeValues *tokens, int size) const;
    Q_INVOKABLE int buttonPaddingHorizontal(const SemiThemeValues *tokens, int size) const;
    Q_INVOKABLE int buttonPaddingVertical(const SemiThemeValues *tokens, int size) const;
    Q_INVOKABLE int buttonFontSize(const SemiThemeValues *tokens, int size) const;

    // ---- Input ----
    // 外层容器高 = 控件高；输入区高 = 控件高 - 2（$height-input_wrapper_* / $height-input_*）
    Q_INVOKABLE int inputWrapperHeight(const SemiThemeValues *tokens, int size) const;
    Q_INVOKABLE int inputPaddingHorizontal(const SemiThemeValues *tokens) const;
    Q_INVOKABLE QColor inputBackground(const SemiThemeValues *tokens, int state, int status) const;
    Q_INVOKABLE QColor inputBorderColor(const SemiThemeValues *tokens, int state, int status) const;
    Q_INVOKABLE QColor inputForeground(const SemiThemeValues *tokens, int state) const;
    Q_INVOKABLE QColor inputPlaceholderColor(const SemiThemeValues *tokens, int state) const;
    // prefix / suffix 图标：$color-input_icon-default = text-2，
    // 禁用态由 .semi-input-wrapper-disabled 整块换成 disabled-text
    Q_INVOKABLE QColor inputIconColor(const SemiThemeValues *tokens, int state) const;

    // ---- TagInput ----
    // 描边与 Input 不同：默认态全透明、只有聚焦才画；warning / error 平时就带浅色描边、
    // 聚焦换成实色；禁用只换背景（tagInput.scss:9-105）
    Q_INVOKABLE QColor tagInputBorder(const SemiThemeValues *tokens, int state, int status) const;

    // ---- Switch ----
    // 开启态是 success 绿，不是主色（见 $color-switch_checked-bg-default）
    // hover / active 也会换背景与描边色，所以传的是状态而不是 enabled；
    // loading 是另一套背景（$color-switch_spin_*-bg-default），所以要单独传一个标记
    Q_INVOKABLE QColor switchTrack(const SemiThemeValues *tokens, bool checked, int state,
                                   bool loading) const;
    // 常态是 1px 透明描边（$border-thickness-control），按下填 fill-2，禁用换 --semi-color-border
    Q_INVOKABLE QColor switchTrackBorder(const SemiThemeValues *tokens, bool checked, int state) const;
    Q_INVOKABLE QColor switchKnob(const SemiThemeValues *tokens, bool checked, bool enabled) const;
    // 禁用的未选中圆钮有 1px 描边，禁用的已选中没有（switch.scss:76-99）
    Q_INVOKABLE QColor switchKnobBorder(const SemiThemeValues *tokens, bool checked, int state) const;

    // ---- Checkbox / Radio 共用 ----
    // 两者的空框 / 选中框 / 卡片底走的是同一套 token 值，规则也逐条对得上，所以只留一组函数：
    //   空框 默认 transparent / 悬浮 fill-0 / 按下 fill-1，描边 默认 text-3 / 悬浮换 focus-border
    //     （checkbox.scss:48-73 ↔ radio.scss:36-70 + 两个 variables.scss）
    //   选中 主色三态（primary / -hover / -active），禁用 primary-disabled（描边同色）
    //   卡片 选中 primary-light-default + 1px 主色描边；未选中悬浮 fill-0、按下 fill-1
    //     （checkbox.scss:186-277 ↔ radio.scss:104-190）
    // fill 是「选中或半选」——两者填同一套主色（checkbox.scss:279-307）。
    // card 为真时空框填白（$color-checkbox_cardType_inner-bg-* ↔ $color-radio_card-bg-*）。
    Q_INVOKABLE QColor choiceBoxBackground(const SemiThemeValues *tokens, bool fill, bool card, int state) const;
    Q_INVOKABLE QColor choiceBoxBorderColor(const SemiThemeValues *tokens, bool fill, int state) const;
    // type=card / pureCard 的整行卡片底与描边
    Q_INVOKABLE QColor choiceCardBackground(const SemiThemeValues *tokens, bool checked, int state) const;
    Q_INVOKABLE QColor choiceCardBorderColor(const SemiThemeValues *tokens, bool checked, int state) const;

    // ---- Radio 专属：按钮式 ----
    // .semi-radio-addon-buttonRadio：默认透明底 + text-1 字，悬浮 fill-1，
    // 选中 bg-3 底 + 主色字，禁用 disabled-text（radio.scss:277-311）
    Q_INVOKABLE QColor radioButtonAddonBackground(const SemiThemeValues *tokens, bool checked, int state) const;
    Q_INVOKABLE QColor radioButtonAddonColor(const SemiThemeValues *tokens, bool checked, int state) const;

    // ---- 文字排版（Title / Paragraph / Text）----
    // Neutral -> 主文本色；Tertiary -> 次级文本色；其余取对应语义色
    Q_INVOKABLE QColor textColor(const SemiThemeValues *tokens, int tone) const;
    Q_INVOKABLE int titleFontSize(const SemiThemeValues *tokens, int level) const;
    Q_INVOKABLE int titleLineHeight(const SemiThemeValues *tokens, int level) const;

    // ---- Badge / Progress ----
    // Avatar 的底色与尺寸查表已经整份搬进 Avatar.qml（官方那份是「七个命名档 + 自定义数」，
    // 不是三档枚举，C++ 侧再包一层反而挡住色板取档）。
    Q_INVOKABLE QColor badgeBackground(const SemiThemeValues *tokens, int tone, bool light) const;
    Q_INVOKABLE QColor badgeForeground(const SemiThemeValues *tokens, int tone, bool light) const;
    // 条状的粗细与默认进度色已经不需要解析函数：官方那两个量（4/6 与 success）
    // 直接落在 Progress.qml 上，stroke 档位查表走 ProgressStroke.js。
    Q_INVOKABLE QColor progressRail(const SemiThemeValues *tokens) const;
};

} // namespace semi
