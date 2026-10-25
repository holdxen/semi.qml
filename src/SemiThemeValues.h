// 本文件由 scripts/gen-theme-tokens.py 从 Semi Design 源码生成，请勿手改。
// 数据源：packages/semi-theme-default/scss

#pragma once

#include <QColor>
#include <QList>
#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

namespace semi {

// 一套完整的 Semi 设计令牌。语义色的值由色阶派生，也可被单独覆盖。
class SemiThemeValues : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS

public:
    enum Mode { Light, Dark };
    Q_ENUM(Mode)

    explicit SemiThemeValues(Mode mode, QObject *parent = nullptr);

    Mode mode() const { return m_mode; }

    // ---- 色阶（16 色系 + AI 紫，各 10 级）----
    Q_PROPERTY(QList<QColor> amber READ amber WRITE setAmber NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> blue READ blue WRITE setBlue NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> cyan READ cyan WRITE setCyan NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> green READ green WRITE setGreen NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> grey READ grey WRITE setGrey NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> indigo READ indigo WRITE setIndigo NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> lightBlue READ lightBlue WRITE setLightBlue NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> lightGreen READ lightGreen WRITE setLightGreen NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> lime READ lime WRITE setLime NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> orange READ orange WRITE setOrange NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> pink READ pink WRITE setPink NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> purple READ purple WRITE setPurple NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> red READ red WRITE setRed NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> teal READ teal WRITE setTeal NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> violet READ violet WRITE setViolet NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> yellow READ yellow WRITE setYellow NOTIFY changed FINAL)
    Q_PROPERTY(QList<QColor> aiPurple READ aiPurple WRITE setAiPurple NOTIFY changed FINAL)

    // ---- 语义色 ----
    Q_PROPERTY(QColor colorWhite READ colorWhite WRITE setColorWhite NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorBlack READ colorBlack WRITE setColorBlack NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorPrimary READ colorPrimary WRITE setColorPrimary NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorPrimaryHover READ colorPrimaryHover WRITE setColorPrimaryHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorPrimaryActive READ colorPrimaryActive WRITE setColorPrimaryActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorPrimaryDisabled READ colorPrimaryDisabled WRITE setColorPrimaryDisabled NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorPrimaryLightDefault READ colorPrimaryLightDefault WRITE setColorPrimaryLightDefault NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorPrimaryLightHover READ colorPrimaryLightHover WRITE setColorPrimaryLightHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorPrimaryLightActive READ colorPrimaryLightActive WRITE setColorPrimaryLightActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSecondary READ colorSecondary WRITE setColorSecondary NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSecondaryHover READ colorSecondaryHover WRITE setColorSecondaryHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSecondaryActive READ colorSecondaryActive WRITE setColorSecondaryActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSecondaryDisabled READ colorSecondaryDisabled WRITE setColorSecondaryDisabled NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSecondaryLightDefault READ colorSecondaryLightDefault WRITE setColorSecondaryLightDefault NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSecondaryLightHover READ colorSecondaryLightHover WRITE setColorSecondaryLightHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSecondaryLightActive READ colorSecondaryLightActive WRITE setColorSecondaryLightActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorTertiary READ colorTertiary WRITE setColorTertiary NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorTertiaryHover READ colorTertiaryHover WRITE setColorTertiaryHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorTertiaryActive READ colorTertiaryActive WRITE setColorTertiaryActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorTertiaryLightDefault READ colorTertiaryLightDefault WRITE setColorTertiaryLightDefault NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorTertiaryLightHover READ colorTertiaryLightHover WRITE setColorTertiaryLightHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorTertiaryLightActive READ colorTertiaryLightActive WRITE setColorTertiaryLightActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDefault READ colorDefault WRITE setColorDefault NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDefaultHover READ colorDefaultHover WRITE setColorDefaultHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDefaultActive READ colorDefaultActive WRITE setColorDefaultActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorInfo READ colorInfo WRITE setColorInfo NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorInfoHover READ colorInfoHover WRITE setColorInfoHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorInfoActive READ colorInfoActive WRITE setColorInfoActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorInfoDisabled READ colorInfoDisabled WRITE setColorInfoDisabled NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorInfoLightDefault READ colorInfoLightDefault WRITE setColorInfoLightDefault NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorInfoLightHover READ colorInfoLightHover WRITE setColorInfoLightHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorInfoLightActive READ colorInfoLightActive WRITE setColorInfoLightActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSuccess READ colorSuccess WRITE setColorSuccess NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSuccessHover READ colorSuccessHover WRITE setColorSuccessHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSuccessActive READ colorSuccessActive WRITE setColorSuccessActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSuccessDisabled READ colorSuccessDisabled WRITE setColorSuccessDisabled NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSuccessLightDefault READ colorSuccessLightDefault WRITE setColorSuccessLightDefault NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSuccessLightHover READ colorSuccessLightHover WRITE setColorSuccessLightHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorSuccessLightActive READ colorSuccessLightActive WRITE setColorSuccessLightActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDanger READ colorDanger WRITE setColorDanger NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDangerHover READ colorDangerHover WRITE setColorDangerHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDangerActive READ colorDangerActive WRITE setColorDangerActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDangerLightDefault READ colorDangerLightDefault WRITE setColorDangerLightDefault NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDangerLightHover READ colorDangerLightHover WRITE setColorDangerLightHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDangerLightActive READ colorDangerLightActive WRITE setColorDangerLightActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorWarning READ colorWarning WRITE setColorWarning NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorWarningHover READ colorWarningHover WRITE setColorWarningHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorWarningActive READ colorWarningActive WRITE setColorWarningActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorWarningLightDefault READ colorWarningLightDefault WRITE setColorWarningLightDefault NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorWarningLightHover READ colorWarningLightHover WRITE setColorWarningLightHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorWarningLightActive READ colorWarningLightActive WRITE setColorWarningLightActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorFocusBorder READ colorFocusBorder WRITE setColorFocusBorder NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDisabledText READ colorDisabledText WRITE setColorDisabledText NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDisabledBorder READ colorDisabledBorder WRITE setColorDisabledBorder NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDisabledBg READ colorDisabledBg WRITE setColorDisabledBg NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorDisabledFill READ colorDisabledFill WRITE setColorDisabledFill NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorShadow READ colorShadow WRITE setColorShadow NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorLink READ colorLink WRITE setColorLink NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorLinkHover READ colorLinkHover WRITE setColorLinkHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorLinkActive READ colorLinkActive WRITE setColorLinkActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorLinkVisited READ colorLinkVisited WRITE setColorLinkVisited NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorBorder READ colorBorder WRITE setColorBorder NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorNavBg READ colorNavBg WRITE setColorNavBg NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorOverlayBg READ colorOverlayBg WRITE setColorOverlayBg NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorFill0 READ colorFill0 WRITE setColorFill0 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorFill1 READ colorFill1 WRITE setColorFill1 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorFill2 READ colorFill2 WRITE setColorFill2 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorBg0 READ colorBg0 WRITE setColorBg0 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorBg1 READ colorBg1 WRITE setColorBg1 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorBg2 READ colorBg2 WRITE setColorBg2 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorBg3 READ colorBg3 WRITE setColorBg3 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorBg4 READ colorBg4 WRITE setColorBg4 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorText0 READ colorText0 WRITE setColorText0 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorText1 READ colorText1 WRITE setColorText1 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorText2 READ colorText2 WRITE setColorText2 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorText3 READ colorText3 WRITE setColorText3 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorHighlightBg READ colorHighlightBg WRITE setColorHighlightBg NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorHighlight READ colorHighlight WRITE setColorHighlight NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData0 READ colorData0 WRITE setColorData0 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData1 READ colorData1 WRITE setColorData1 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData2 READ colorData2 WRITE setColorData2 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData3 READ colorData3 WRITE setColorData3 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData4 READ colorData4 WRITE setColorData4 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData5 READ colorData5 WRITE setColorData5 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData6 READ colorData6 WRITE setColorData6 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData7 READ colorData7 WRITE setColorData7 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData8 READ colorData8 WRITE setColorData8 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData9 READ colorData9 WRITE setColorData9 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData10 READ colorData10 WRITE setColorData10 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData11 READ colorData11 WRITE setColorData11 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData12 READ colorData12 WRITE setColorData12 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData13 READ colorData13 WRITE setColorData13 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData14 READ colorData14 WRITE setColorData14 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData15 READ colorData15 WRITE setColorData15 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData16 READ colorData16 WRITE setColorData16 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData17 READ colorData17 WRITE setColorData17 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData18 READ colorData18 WRITE setColorData18 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorData19 READ colorData19 WRITE setColorData19 NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiGeneral READ colorAiGeneral WRITE setColorAiGeneral NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiGeneralHover READ colorAiGeneralHover WRITE setColorAiGeneralHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiGeneralActive READ colorAiGeneralActive WRITE setColorAiGeneralActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiGeneralDisabled READ colorAiGeneralDisabled WRITE setColorAiGeneralDisabled NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiPurple READ colorAiPurple WRITE setColorAiPurple NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiPurpleHover READ colorAiPurpleHover WRITE setColorAiPurpleHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiPurpleActive READ colorAiPurpleActive WRITE setColorAiPurpleActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiPurpleDisabled READ colorAiPurpleDisabled WRITE setColorAiPurpleDisabled NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiBackgroundBottom READ colorAiBackgroundBottom WRITE setColorAiBackgroundBottom NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiBackgroundBottomHover READ colorAiBackgroundBottomHover WRITE setColorAiBackgroundBottomHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiBackgroundBottomActive READ colorAiBackgroundBottomActive WRITE setColorAiBackgroundBottomActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiBackgroundTop READ colorAiBackgroundTop WRITE setColorAiBackgroundTop NOTIFY changed FINAL)
    Q_PROPERTY(QColor colorAiBackgroundTopHover READ colorAiBackgroundTopHover WRITE setColorAiBackgroundTopHover NOTIFY changed FINAL)

    // ---- 圆角 / 阴影 / AI 渐变 / 动效 / 尺寸 ----
    Q_PROPERTY(QString shadowElevated READ shadowElevated WRITE setShadowElevated NOTIFY changed FINAL)
    Q_PROPERTY(int radiusExtraSmall READ radiusExtraSmall WRITE setRadiusExtraSmall NOTIFY changed FINAL)
    Q_PROPERTY(int radiusSmall READ radiusSmall WRITE setRadiusSmall NOTIFY changed FINAL)
    Q_PROPERTY(int radiusMedium READ radiusMedium WRITE setRadiusMedium NOTIFY changed FINAL)
    Q_PROPERTY(int radiusLarge READ radiusLarge WRITE setRadiusLarge NOTIFY changed FINAL)
    Q_PROPERTY(int radiusCircle READ radiusCircle WRITE setRadiusCircle NOTIFY changed FINAL)
    Q_PROPERTY(int radiusFull READ radiusFull WRITE setRadiusFull NOTIFY changed FINAL)
    Q_PROPERTY(int durationSlowest READ durationSlowest WRITE setDurationSlowest NOTIFY changed FINAL)
    Q_PROPERTY(int durationSlower READ durationSlower WRITE setDurationSlower NOTIFY changed FINAL)
    Q_PROPERTY(int durationSlow READ durationSlow WRITE setDurationSlow NOTIFY changed FINAL)
    Q_PROPERTY(int durationNormal READ durationNormal WRITE setDurationNormal NOTIFY changed FINAL)
    Q_PROPERTY(int durationFast READ durationFast WRITE setDurationFast NOTIFY changed FINAL)
    Q_PROPERTY(int durationFaster READ durationFaster WRITE setDurationFaster NOTIFY changed FINAL)
    Q_PROPERTY(int durationFastest READ durationFastest WRITE setDurationFastest NOTIFY changed FINAL)
    Q_PROPERTY(int durationNone READ durationNone WRITE setDurationNone NOTIFY changed FINAL)
    Q_PROPERTY(QString easingLinear READ easingLinear WRITE setEasingLinear NOTIFY changed FINAL)
    Q_PROPERTY(QString easingEase READ easingEase WRITE setEasingEase NOTIFY changed FINAL)
    Q_PROPERTY(QString easingEaseIn READ easingEaseIn WRITE setEasingEaseIn NOTIFY changed FINAL)
    Q_PROPERTY(QString easingEaseOut READ easingEaseOut WRITE setEasingEaseOut NOTIFY changed FINAL)
    Q_PROPERTY(QString easingEaseInIOut READ easingEaseInIOut WRITE setEasingEaseInIOut NOTIFY changed FINAL)
    Q_PROPERTY(int delayNone READ delayNone WRITE setDelayNone NOTIFY changed FINAL)
    Q_PROPERTY(int delaySlowest READ delaySlowest WRITE setDelaySlowest NOTIFY changed FINAL)
    Q_PROPERTY(int delaySlower READ delaySlower WRITE setDelaySlower NOTIFY changed FINAL)
    Q_PROPERTY(int delaySlow READ delaySlow WRITE setDelaySlow NOTIFY changed FINAL)
    Q_PROPERTY(int delayNormal READ delayNormal WRITE setDelayNormal NOTIFY changed FINAL)
    Q_PROPERTY(int delayFast READ delayFast WRITE setDelayFast NOTIFY changed FINAL)
    Q_PROPERTY(int delayFaster READ delayFaster WRITE setDelayFaster NOTIFY changed FINAL)
    Q_PROPERTY(int delayFastest READ delayFastest WRITE setDelayFastest NOTIFY changed FINAL)
    Q_PROPERTY(qreal scaleNone READ scaleNone WRITE setScaleNone NOTIFY changed FINAL)
    Q_PROPERTY(qreal scaleSmall READ scaleSmall WRITE setScaleSmall NOTIFY changed FINAL)
    Q_PROPERTY(qreal scaleMedium READ scaleMedium WRITE setScaleMedium NOTIFY changed FINAL)
    Q_PROPERTY(qreal scaleLarge READ scaleLarge WRITE setScaleLarge NOTIFY changed FINAL)
    Q_PROPERTY(int rotateNone READ rotateNone WRITE setRotateNone NOTIFY changed FINAL)
    Q_PROPERTY(int rotateClockwise90deg READ rotateClockwise90deg WRITE setRotateClockwise90deg NOTIFY changed FINAL)
    Q_PROPERTY(int rotateClockwise180deg READ rotateClockwise180deg WRITE setRotateClockwise180deg NOTIFY changed FINAL)
    Q_PROPERTY(int rotateClockwise270deg READ rotateClockwise270deg WRITE setRotateClockwise270deg NOTIFY changed FINAL)
    Q_PROPERTY(int rotateClockwise360deg READ rotateClockwise360deg WRITE setRotateClockwise360deg NOTIFY changed FINAL)
    Q_PROPERTY(int rotateAnticlockwise90deg READ rotateAnticlockwise90deg WRITE setRotateAnticlockwise90deg NOTIFY changed FINAL)
    Q_PROPERTY(int rotateAnticlockwise180deg READ rotateAnticlockwise180deg WRITE setRotateAnticlockwise180deg NOTIFY changed FINAL)
    Q_PROPERTY(int rotateAnticlockwise270deg READ rotateAnticlockwise270deg WRITE setRotateAnticlockwise270deg NOTIFY changed FINAL)
    Q_PROPERTY(int rotateAnticlockwise360deg READ rotateAnticlockwise360deg WRITE setRotateAnticlockwise360deg NOTIFY changed FINAL)
    Q_PROPERTY(int heightControlSmall READ heightControlSmall WRITE setHeightControlSmall NOTIFY changed FINAL)
    Q_PROPERTY(int heightControlDefault READ heightControlDefault WRITE setHeightControlDefault NOTIFY changed FINAL)
    Q_PROPERTY(int heightControlLarge READ heightControlLarge WRITE setHeightControlLarge NOTIFY changed FINAL)
    Q_PROPERTY(int borderThickness READ borderThickness WRITE setBorderThickness NOTIFY changed FINAL)
    Q_PROPERTY(int borderThicknessControl READ borderThicknessControl WRITE setBorderThicknessControl NOTIFY changed FINAL)
    Q_PROPERTY(int borderThicknessControlFocus READ borderThicknessControlFocus WRITE setBorderThicknessControlFocus NOTIFY changed FINAL)
    Q_PROPERTY(int widthIconExtraSmall READ widthIconExtraSmall WRITE setWidthIconExtraSmall NOTIFY changed FINAL)
    Q_PROPERTY(int widthIconSmall READ widthIconSmall WRITE setWidthIconSmall NOTIFY changed FINAL)
    Q_PROPERTY(int widthIconMedium READ widthIconMedium WRITE setWidthIconMedium NOTIFY changed FINAL)
    Q_PROPERTY(int widthIconLarge READ widthIconLarge WRITE setWidthIconLarge NOTIFY changed FINAL)
    Q_PROPERTY(int widthIconExtraLarge READ widthIconExtraLarge WRITE setWidthIconExtraLarge NOTIFY changed FINAL)
    Q_PROPERTY(int spacingNone READ spacingNone WRITE setSpacingNone NOTIFY changed FINAL)
    Q_PROPERTY(int spacingSuperTight READ spacingSuperTight WRITE setSpacingSuperTight NOTIFY changed FINAL)
    Q_PROPERTY(int spacingExtraTight READ spacingExtraTight WRITE setSpacingExtraTight NOTIFY changed FINAL)
    Q_PROPERTY(int spacingTight READ spacingTight WRITE setSpacingTight NOTIFY changed FINAL)
    Q_PROPERTY(int spacingBaseTight READ spacingBaseTight WRITE setSpacingBaseTight NOTIFY changed FINAL)
    Q_PROPERTY(int spacingBase READ spacingBase WRITE setSpacingBase NOTIFY changed FINAL)
    Q_PROPERTY(int spacingBaseLoose READ spacingBaseLoose WRITE setSpacingBaseLoose NOTIFY changed FINAL)
    Q_PROPERTY(int spacingLoose READ spacingLoose WRITE setSpacingLoose NOTIFY changed FINAL)
    Q_PROPERTY(int spacingExtraLoose READ spacingExtraLoose WRITE setSpacingExtraLoose NOTIFY changed FINAL)
    Q_PROPERTY(int spacingSuperLoose READ spacingSuperLoose WRITE setSpacingSuperLoose NOTIFY changed FINAL)
    Q_PROPERTY(int zPortal READ zPortal WRITE setZPortal NOTIFY changed FINAL)
    Q_PROPERTY(int zAffix READ zAffix WRITE setZAffix NOTIFY changed FINAL)
    Q_PROPERTY(int zBacktop READ zBacktop WRITE setZBacktop NOTIFY changed FINAL)
    Q_PROPERTY(int zBadge READ zBadge WRITE setZBadge NOTIFY changed FINAL)
    Q_PROPERTY(int zTableFixed READ zTableFixed WRITE setZTableFixed NOTIFY changed FINAL)
    Q_PROPERTY(int zModal READ zModal WRITE setZModal NOTIFY changed FINAL)
    Q_PROPERTY(int zModalMask READ zModalMask WRITE setZModalMask NOTIFY changed FINAL)
    Q_PROPERTY(int zToast READ zToast WRITE setZToast NOTIFY changed FINAL)
    Q_PROPERTY(int zNotification READ zNotification WRITE setZNotification NOTIFY changed FINAL)
    Q_PROPERTY(int zPopover READ zPopover WRITE setZPopover NOTIFY changed FINAL)
    Q_PROPERTY(int zDropdown READ zDropdown WRITE setZDropdown NOTIFY changed FINAL)
    Q_PROPERTY(int zTooltip READ zTooltip WRITE setZTooltip NOTIFY changed FINAL)
    Q_PROPERTY(int zImagePreview READ zImagePreview WRITE setZImagePreview NOTIFY changed FINAL)
    Q_PROPERTY(int zImagePreviewHeader READ zImagePreviewHeader WRITE setZImagePreviewHeader NOTIFY changed FINAL)
    Q_PROPERTY(int zTransferRightItemDragItemMove READ zTransferRightItemDragItemMove WRITE setZTransferRightItemDragItemMove NOTIFY changed FINAL)
    Q_PROPERTY(int zTagInputDragItemMove READ zTagInputDragItemMove WRITE setZTagInputDragItemMove NOTIFY changed FINAL)
    Q_PROPERTY(int zResizableHandler READ zResizableHandler WRITE setZResizableHandler NOTIFY changed FINAL)
    Q_PROPERTY(int fontSizeSmall READ fontSizeSmall WRITE setFontSizeSmall NOTIFY changed FINAL)
    Q_PROPERTY(int fontSizeRegular READ fontSizeRegular WRITE setFontSizeRegular NOTIFY changed FINAL)
    Q_PROPERTY(int fontSizeHeader6 READ fontSizeHeader6 WRITE setFontSizeHeader6 NOTIFY changed FINAL)
    Q_PROPERTY(int fontSizeHeader5 READ fontSizeHeader5 WRITE setFontSizeHeader5 NOTIFY changed FINAL)
    Q_PROPERTY(int fontSizeHeader4 READ fontSizeHeader4 WRITE setFontSizeHeader4 NOTIFY changed FINAL)
    Q_PROPERTY(int fontSizeHeader3 READ fontSizeHeader3 WRITE setFontSizeHeader3 NOTIFY changed FINAL)
    Q_PROPERTY(int fontSizeHeader2 READ fontSizeHeader2 WRITE setFontSizeHeader2 NOTIFY changed FINAL)
    Q_PROPERTY(int fontSizeHeader1 READ fontSizeHeader1 WRITE setFontSizeHeader1 NOTIFY changed FINAL)
    Q_PROPERTY(int fontWeightLight READ fontWeightLight WRITE setFontWeightLight NOTIFY changed FINAL)
    Q_PROPERTY(int fontWeightRegular READ fontWeightRegular WRITE setFontWeightRegular NOTIFY changed FINAL)
    Q_PROPERTY(int fontWeightBold READ fontWeightBold WRITE setFontWeightBold NOTIFY changed FINAL)
    Q_PROPERTY(QColor black READ black WRITE setBlack NOTIFY changed FINAL)
    Q_PROPERTY(QColor white READ white WRITE setWhite NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral0 READ aiGeneral0 WRITE setAiGeneral0 NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral1 READ aiGeneral1 WRITE setAiGeneral1 NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral2 READ aiGeneral2 WRITE setAiGeneral2 NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral3 READ aiGeneral3 WRITE setAiGeneral3 NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral4 READ aiGeneral4 WRITE setAiGeneral4 NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral5 READ aiGeneral5 WRITE setAiGeneral5 NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral6 READ aiGeneral6 WRITE setAiGeneral6 NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral7 READ aiGeneral7 WRITE setAiGeneral7 NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral8 READ aiGeneral8 WRITE setAiGeneral8 NOTIFY changed FINAL)
    Q_PROPERTY(QString aiGeneral9 READ aiGeneral9 WRITE setAiGeneral9 NOTIFY changed FINAL)

    // ---- 读取 ----
    QList<QColor> amber() const { return m_amber; }
    QList<QColor> blue() const { return m_blue; }
    QList<QColor> cyan() const { return m_cyan; }
    QList<QColor> green() const { return m_green; }
    QList<QColor> grey() const { return m_grey; }
    QList<QColor> indigo() const { return m_indigo; }
    QList<QColor> lightBlue() const { return m_lightBlue; }
    QList<QColor> lightGreen() const { return m_lightGreen; }
    QList<QColor> lime() const { return m_lime; }
    QList<QColor> orange() const { return m_orange; }
    QList<QColor> pink() const { return m_pink; }
    QList<QColor> purple() const { return m_purple; }
    QList<QColor> red() const { return m_red; }
    QList<QColor> teal() const { return m_teal; }
    QList<QColor> violet() const { return m_violet; }
    QList<QColor> yellow() const { return m_yellow; }
    QList<QColor> aiPurple() const { return m_aiPurple; }
    QColor colorWhite() const { return m_colorWhite; }
    QColor colorBlack() const { return m_colorBlack; }
    QColor colorPrimary() const { return m_colorPrimaryOverridden ? m_colorPrimary : m_blue.value(5); }
    QColor colorPrimaryHover() const { return m_colorPrimaryHoverOverridden ? m_colorPrimaryHover : m_blue.value(6); }
    QColor colorPrimaryActive() const { return m_colorPrimaryActiveOverridden ? m_colorPrimaryActive : m_blue.value(7); }
    QColor colorPrimaryDisabled() const { return m_colorPrimaryDisabledOverridden ? m_colorPrimaryDisabled : m_blue.value(2); }
    QColor colorPrimaryLightDefault() const { return m_colorPrimaryLightDefault; }
    QColor colorPrimaryLightHover() const { return m_colorPrimaryLightHover; }
    QColor colorPrimaryLightActive() const { return m_colorPrimaryLightActive; }
    QColor colorSecondary() const { return m_colorSecondaryOverridden ? m_colorSecondary : m_lightBlue.value(5); }
    QColor colorSecondaryHover() const { return m_colorSecondaryHoverOverridden ? m_colorSecondaryHover : m_lightBlue.value(6); }
    QColor colorSecondaryActive() const { return m_colorSecondaryActiveOverridden ? m_colorSecondaryActive : m_lightBlue.value(7); }
    QColor colorSecondaryDisabled() const { return m_colorSecondaryDisabledOverridden ? m_colorSecondaryDisabled : m_lightBlue.value(2); }
    QColor colorSecondaryLightDefault() const { return m_colorSecondaryLightDefault; }
    QColor colorSecondaryLightHover() const { return m_colorSecondaryLightHover; }
    QColor colorSecondaryLightActive() const { return m_colorSecondaryLightActive; }
    QColor colorTertiary() const { return m_colorTertiaryOverridden ? m_colorTertiary : m_grey.value(5); }
    QColor colorTertiaryHover() const { return m_colorTertiaryHoverOverridden ? m_colorTertiaryHover : m_grey.value(6); }
    QColor colorTertiaryActive() const { return m_colorTertiaryActiveOverridden ? m_colorTertiaryActive : m_grey.value(7); }
    QColor colorTertiaryLightDefault() const { return m_colorTertiaryLightDefault; }
    QColor colorTertiaryLightHover() const { return m_colorTertiaryLightHover; }
    QColor colorTertiaryLightActive() const { return m_colorTertiaryLightActive; }
    QColor colorDefault() const { return m_colorDefaultOverridden ? m_colorDefault : m_grey.value(0); }
    QColor colorDefaultHover() const { return m_colorDefaultHoverOverridden ? m_colorDefaultHover : m_grey.value(1); }
    QColor colorDefaultActive() const { return m_colorDefaultActiveOverridden ? m_colorDefaultActive : m_grey.value(2); }
    QColor colorInfo() const { return m_colorInfoOverridden ? m_colorInfo : m_blue.value(5); }
    QColor colorInfoHover() const { return m_colorInfoHoverOverridden ? m_colorInfoHover : m_blue.value(6); }
    QColor colorInfoActive() const { return m_colorInfoActiveOverridden ? m_colorInfoActive : m_blue.value(7); }
    QColor colorInfoDisabled() const { return m_colorInfoDisabledOverridden ? m_colorInfoDisabled : m_blue.value(2); }
    QColor colorInfoLightDefault() const { return m_colorInfoLightDefault; }
    QColor colorInfoLightHover() const { return m_colorInfoLightHover; }
    QColor colorInfoLightActive() const { return m_colorInfoLightActive; }
    QColor colorSuccess() const { return m_colorSuccessOverridden ? m_colorSuccess : m_green.value(5); }
    QColor colorSuccessHover() const { return m_colorSuccessHoverOverridden ? m_colorSuccessHover : m_green.value(6); }
    QColor colorSuccessActive() const { return m_colorSuccessActiveOverridden ? m_colorSuccessActive : m_green.value(7); }
    QColor colorSuccessDisabled() const { return m_colorSuccessDisabledOverridden ? m_colorSuccessDisabled : m_green.value(2); }
    QColor colorSuccessLightDefault() const { return m_colorSuccessLightDefault; }
    QColor colorSuccessLightHover() const { return m_colorSuccessLightHover; }
    QColor colorSuccessLightActive() const { return m_colorSuccessLightActive; }
    QColor colorDanger() const { return m_colorDangerOverridden ? m_colorDanger : m_red.value(5); }
    QColor colorDangerHover() const { return m_colorDangerHoverOverridden ? m_colorDangerHover : m_red.value(6); }
    QColor colorDangerActive() const { return m_colorDangerActiveOverridden ? m_colorDangerActive : m_red.value(7); }
    QColor colorDangerLightDefault() const { return m_colorDangerLightDefault; }
    QColor colorDangerLightHover() const { return m_colorDangerLightHover; }
    QColor colorDangerLightActive() const { return m_colorDangerLightActive; }
    QColor colorWarning() const { return m_colorWarningOverridden ? m_colorWarning : m_orange.value(5); }
    QColor colorWarningHover() const { return m_colorWarningHoverOverridden ? m_colorWarningHover : m_orange.value(6); }
    QColor colorWarningActive() const { return m_colorWarningActiveOverridden ? m_colorWarningActive : m_orange.value(7); }
    QColor colorWarningLightDefault() const { return m_colorWarningLightDefault; }
    QColor colorWarningLightHover() const { return m_colorWarningLightHover; }
    QColor colorWarningLightActive() const { return m_colorWarningLightActive; }
    QColor colorFocusBorder() const { return m_colorFocusBorderOverridden ? m_colorFocusBorder : m_blue.value(5); }
    QColor colorDisabledText() const { return m_colorDisabledText; }
    QColor colorDisabledBorder() const { return m_colorDisabledBorderOverridden ? m_colorDisabledBorder : m_grey.value(1); }
    QColor colorDisabledBg() const { return m_colorDisabledBgOverridden ? m_colorDisabledBg : m_grey.value(1); }
    QColor colorDisabledFill() const { return m_colorDisabledFill; }
    QColor colorShadow() const { return m_colorShadow; }
    QColor colorLink() const { return m_colorLinkOverridden ? m_colorLink : m_blue.value(5); }
    QColor colorLinkHover() const { return m_colorLinkHoverOverridden ? m_colorLinkHover : m_blue.value(6); }
    QColor colorLinkActive() const { return m_colorLinkActiveOverridden ? m_colorLinkActive : m_blue.value(7); }
    QColor colorLinkVisited() const { return m_colorLinkVisitedOverridden ? m_colorLinkVisited : m_blue.value(5); }
    QColor colorBorder() const { return m_colorBorder; }
    QColor colorNavBg() const { return m_colorNavBg; }
    QColor colorOverlayBg() const { return m_colorOverlayBg; }
    QColor colorFill0() const { return m_colorFill0; }
    QColor colorFill1() const { return m_colorFill1; }
    QColor colorFill2() const { return m_colorFill2; }
    QColor colorBg0() const { return m_colorBg0; }
    QColor colorBg1() const { return m_colorBg1; }
    QColor colorBg2() const { return m_colorBg2; }
    QColor colorBg3() const { return m_colorBg3; }
    QColor colorBg4() const { return m_colorBg4; }
    QColor colorText0() const { return m_colorText0Overridden ? m_colorText0 : m_grey.value(9); }
    QColor colorText1() const { return m_colorText1; }
    QColor colorText2() const { return m_colorText2; }
    QColor colorText3() const { return m_colorText3; }
    QColor colorHighlightBg() const { return m_colorHighlightBg; }
    QColor colorHighlight() const { return m_colorHighlight; }
    QColor colorData0() const { return m_colorData0; }
    QColor colorData1() const { return m_colorData1; }
    QColor colorData2() const { return m_colorData2; }
    QColor colorData3() const { return m_colorData3; }
    QColor colorData4() const { return m_colorData4; }
    QColor colorData5() const { return m_colorData5; }
    QColor colorData6() const { return m_colorData6; }
    QColor colorData7() const { return m_colorData7; }
    QColor colorData8() const { return m_colorData8; }
    QColor colorData9() const { return m_colorData9; }
    QColor colorData10() const { return m_colorData10; }
    QColor colorData11() const { return m_colorData11; }
    QColor colorData12() const { return m_colorData12; }
    QColor colorData13() const { return m_colorData13; }
    QColor colorData14() const { return m_colorData14; }
    QColor colorData15() const { return m_colorData15; }
    QColor colorData16() const { return m_colorData16; }
    QColor colorData17() const { return m_colorData17; }
    QColor colorData18() const { return m_colorData18; }
    QColor colorData19() const { return m_colorData19; }
    QColor colorAiGeneral() const { return m_colorAiGeneral; }
    QColor colorAiGeneralHover() const { return m_colorAiGeneralHover; }
    QColor colorAiGeneralActive() const { return m_colorAiGeneralActive; }
    QColor colorAiGeneralDisabled() const { return m_colorAiGeneralDisabled; }
    QColor colorAiPurple() const { return m_colorAiPurpleOverridden ? m_colorAiPurple : m_aiPurple.value(5); }
    QColor colorAiPurpleHover() const { return m_colorAiPurpleHoverOverridden ? m_colorAiPurpleHover : m_aiPurple.value(6); }
    QColor colorAiPurpleActive() const { return m_colorAiPurpleActiveOverridden ? m_colorAiPurpleActive : m_aiPurple.value(7); }
    QColor colorAiPurpleDisabled() const { return m_colorAiPurpleDisabledOverridden ? m_colorAiPurpleDisabled : m_aiPurple.value(2); }
    QColor colorAiBackgroundBottom() const { return m_colorAiBackgroundBottom; }
    QColor colorAiBackgroundBottomHover() const { return m_colorAiBackgroundBottomHover; }
    QColor colorAiBackgroundBottomActive() const { return m_colorAiBackgroundBottomActive; }
    QColor colorAiBackgroundTop() const { return m_colorAiBackgroundTop; }
    QColor colorAiBackgroundTopHover() const { return m_colorAiBackgroundTopHover; }
    QString shadowElevated() const { return m_shadowElevated; }
    int radiusExtraSmall() const { return m_radiusExtraSmall; }
    int radiusSmall() const { return m_radiusSmall; }
    int radiusMedium() const { return m_radiusMedium; }
    int radiusLarge() const { return m_radiusLarge; }
    int radiusCircle() const { return m_radiusCircle; }
    int radiusFull() const { return m_radiusFull; }
    int durationSlowest() const { return m_durationSlowest; }
    int durationSlower() const { return m_durationSlower; }
    int durationSlow() const { return m_durationSlow; }
    int durationNormal() const { return m_durationNormal; }
    int durationFast() const { return m_durationFast; }
    int durationFaster() const { return m_durationFaster; }
    int durationFastest() const { return m_durationFastest; }
    int durationNone() const { return m_durationNone; }
    QString easingLinear() const { return m_easingLinear; }
    QString easingEase() const { return m_easingEase; }
    QString easingEaseIn() const { return m_easingEaseIn; }
    QString easingEaseOut() const { return m_easingEaseOut; }
    QString easingEaseInIOut() const { return m_easingEaseInIOut; }
    int delayNone() const { return m_delayNone; }
    int delaySlowest() const { return m_delaySlowest; }
    int delaySlower() const { return m_delaySlower; }
    int delaySlow() const { return m_delaySlow; }
    int delayNormal() const { return m_delayNormal; }
    int delayFast() const { return m_delayFast; }
    int delayFaster() const { return m_delayFaster; }
    int delayFastest() const { return m_delayFastest; }
    qreal scaleNone() const { return m_scaleNone; }
    qreal scaleSmall() const { return m_scaleSmall; }
    qreal scaleMedium() const { return m_scaleMedium; }
    qreal scaleLarge() const { return m_scaleLarge; }
    int rotateNone() const { return m_rotateNone; }
    int rotateClockwise90deg() const { return m_rotateClockwise90deg; }
    int rotateClockwise180deg() const { return m_rotateClockwise180deg; }
    int rotateClockwise270deg() const { return m_rotateClockwise270deg; }
    int rotateClockwise360deg() const { return m_rotateClockwise360deg; }
    int rotateAnticlockwise90deg() const { return m_rotateAnticlockwise90deg; }
    int rotateAnticlockwise180deg() const { return m_rotateAnticlockwise180deg; }
    int rotateAnticlockwise270deg() const { return m_rotateAnticlockwise270deg; }
    int rotateAnticlockwise360deg() const { return m_rotateAnticlockwise360deg; }
    int heightControlSmall() const { return m_heightControlSmall; }
    int heightControlDefault() const { return m_heightControlDefault; }
    int heightControlLarge() const { return m_heightControlLarge; }
    int borderThickness() const { return m_borderThickness; }
    int borderThicknessControl() const { return m_borderThicknessControl; }
    int borderThicknessControlFocus() const { return m_borderThicknessControlFocus; }
    int widthIconExtraSmall() const { return m_widthIconExtraSmall; }
    int widthIconSmall() const { return m_widthIconSmall; }
    int widthIconMedium() const { return m_widthIconMedium; }
    int widthIconLarge() const { return m_widthIconLarge; }
    int widthIconExtraLarge() const { return m_widthIconExtraLarge; }
    int spacingNone() const { return m_spacingNone; }
    int spacingSuperTight() const { return m_spacingSuperTight; }
    int spacingExtraTight() const { return m_spacingExtraTight; }
    int spacingTight() const { return m_spacingTight; }
    int spacingBaseTight() const { return m_spacingBaseTight; }
    int spacingBase() const { return m_spacingBase; }
    int spacingBaseLoose() const { return m_spacingBaseLoose; }
    int spacingLoose() const { return m_spacingLoose; }
    int spacingExtraLoose() const { return m_spacingExtraLoose; }
    int spacingSuperLoose() const { return m_spacingSuperLoose; }
    int zPortal() const { return m_zPortal; }
    int zAffix() const { return m_zAffix; }
    int zBacktop() const { return m_zBacktop; }
    int zBadge() const { return m_zBadge; }
    int zTableFixed() const { return m_zTableFixed; }
    int zModal() const { return m_zModal; }
    int zModalMask() const { return m_zModalMask; }
    int zToast() const { return m_zToast; }
    int zNotification() const { return m_zNotification; }
    int zPopover() const { return m_zPopover; }
    int zDropdown() const { return m_zDropdown; }
    int zTooltip() const { return m_zTooltip; }
    int zImagePreview() const { return m_zImagePreview; }
    int zImagePreviewHeader() const { return m_zImagePreviewHeader; }
    int zTransferRightItemDragItemMove() const { return m_zTransferRightItemDragItemMove; }
    int zTagInputDragItemMove() const { return m_zTagInputDragItemMove; }
    int zResizableHandler() const { return m_zResizableHandler; }
    int fontSizeSmall() const { return m_fontSizeSmall; }
    int fontSizeRegular() const { return m_fontSizeRegular; }
    int fontSizeHeader6() const { return m_fontSizeHeader6; }
    int fontSizeHeader5() const { return m_fontSizeHeader5; }
    int fontSizeHeader4() const { return m_fontSizeHeader4; }
    int fontSizeHeader3() const { return m_fontSizeHeader3; }
    int fontSizeHeader2() const { return m_fontSizeHeader2; }
    int fontSizeHeader1() const { return m_fontSizeHeader1; }
    int fontWeightLight() const { return m_fontWeightLight; }
    int fontWeightRegular() const { return m_fontWeightRegular; }
    int fontWeightBold() const { return m_fontWeightBold; }
    QColor black() const { return m_black; }
    QColor white() const { return m_white; }
    QString aiGeneral0() const { return m_aiGeneral0; }
    QString aiGeneral1() const { return m_aiGeneral1; }
    QString aiGeneral2() const { return m_aiGeneral2; }
    QString aiGeneral3() const { return m_aiGeneral3; }
    QString aiGeneral4() const { return m_aiGeneral4; }
    QString aiGeneral5() const { return m_aiGeneral5; }
    QString aiGeneral6() const { return m_aiGeneral6; }
    QString aiGeneral7() const { return m_aiGeneral7; }
    QString aiGeneral8() const { return m_aiGeneral8; }
    QString aiGeneral9() const { return m_aiGeneral9; }

    // ---- 写入 ----
    void setAmber(const QList<QColor> &v);
    void setBlue(const QList<QColor> &v);
    void setCyan(const QList<QColor> &v);
    void setGreen(const QList<QColor> &v);
    void setGrey(const QList<QColor> &v);
    void setIndigo(const QList<QColor> &v);
    void setLightBlue(const QList<QColor> &v);
    void setLightGreen(const QList<QColor> &v);
    void setLime(const QList<QColor> &v);
    void setOrange(const QList<QColor> &v);
    void setPink(const QList<QColor> &v);
    void setPurple(const QList<QColor> &v);
    void setRed(const QList<QColor> &v);
    void setTeal(const QList<QColor> &v);
    void setViolet(const QList<QColor> &v);
    void setYellow(const QList<QColor> &v);
    void setAiPurple(const QList<QColor> &v);
    void setColorWhite(const QColor &v);
    void setColorBlack(const QColor &v);
    void setColorPrimary(const QColor &v);
    void setColorPrimaryHover(const QColor &v);
    void setColorPrimaryActive(const QColor &v);
    void setColorPrimaryDisabled(const QColor &v);
    void setColorPrimaryLightDefault(const QColor &v);
    void setColorPrimaryLightHover(const QColor &v);
    void setColorPrimaryLightActive(const QColor &v);
    void setColorSecondary(const QColor &v);
    void setColorSecondaryHover(const QColor &v);
    void setColorSecondaryActive(const QColor &v);
    void setColorSecondaryDisabled(const QColor &v);
    void setColorSecondaryLightDefault(const QColor &v);
    void setColorSecondaryLightHover(const QColor &v);
    void setColorSecondaryLightActive(const QColor &v);
    void setColorTertiary(const QColor &v);
    void setColorTertiaryHover(const QColor &v);
    void setColorTertiaryActive(const QColor &v);
    void setColorTertiaryLightDefault(const QColor &v);
    void setColorTertiaryLightHover(const QColor &v);
    void setColorTertiaryLightActive(const QColor &v);
    void setColorDefault(const QColor &v);
    void setColorDefaultHover(const QColor &v);
    void setColorDefaultActive(const QColor &v);
    void setColorInfo(const QColor &v);
    void setColorInfoHover(const QColor &v);
    void setColorInfoActive(const QColor &v);
    void setColorInfoDisabled(const QColor &v);
    void setColorInfoLightDefault(const QColor &v);
    void setColorInfoLightHover(const QColor &v);
    void setColorInfoLightActive(const QColor &v);
    void setColorSuccess(const QColor &v);
    void setColorSuccessHover(const QColor &v);
    void setColorSuccessActive(const QColor &v);
    void setColorSuccessDisabled(const QColor &v);
    void setColorSuccessLightDefault(const QColor &v);
    void setColorSuccessLightHover(const QColor &v);
    void setColorSuccessLightActive(const QColor &v);
    void setColorDanger(const QColor &v);
    void setColorDangerHover(const QColor &v);
    void setColorDangerActive(const QColor &v);
    void setColorDangerLightDefault(const QColor &v);
    void setColorDangerLightHover(const QColor &v);
    void setColorDangerLightActive(const QColor &v);
    void setColorWarning(const QColor &v);
    void setColorWarningHover(const QColor &v);
    void setColorWarningActive(const QColor &v);
    void setColorWarningLightDefault(const QColor &v);
    void setColorWarningLightHover(const QColor &v);
    void setColorWarningLightActive(const QColor &v);
    void setColorFocusBorder(const QColor &v);
    void setColorDisabledText(const QColor &v);
    void setColorDisabledBorder(const QColor &v);
    void setColorDisabledBg(const QColor &v);
    void setColorDisabledFill(const QColor &v);
    void setColorShadow(const QColor &v);
    void setColorLink(const QColor &v);
    void setColorLinkHover(const QColor &v);
    void setColorLinkActive(const QColor &v);
    void setColorLinkVisited(const QColor &v);
    void setColorBorder(const QColor &v);
    void setColorNavBg(const QColor &v);
    void setColorOverlayBg(const QColor &v);
    void setColorFill0(const QColor &v);
    void setColorFill1(const QColor &v);
    void setColorFill2(const QColor &v);
    void setColorBg0(const QColor &v);
    void setColorBg1(const QColor &v);
    void setColorBg2(const QColor &v);
    void setColorBg3(const QColor &v);
    void setColorBg4(const QColor &v);
    void setColorText0(const QColor &v);
    void setColorText1(const QColor &v);
    void setColorText2(const QColor &v);
    void setColorText3(const QColor &v);
    void setColorHighlightBg(const QColor &v);
    void setColorHighlight(const QColor &v);
    void setColorData0(const QColor &v);
    void setColorData1(const QColor &v);
    void setColorData2(const QColor &v);
    void setColorData3(const QColor &v);
    void setColorData4(const QColor &v);
    void setColorData5(const QColor &v);
    void setColorData6(const QColor &v);
    void setColorData7(const QColor &v);
    void setColorData8(const QColor &v);
    void setColorData9(const QColor &v);
    void setColorData10(const QColor &v);
    void setColorData11(const QColor &v);
    void setColorData12(const QColor &v);
    void setColorData13(const QColor &v);
    void setColorData14(const QColor &v);
    void setColorData15(const QColor &v);
    void setColorData16(const QColor &v);
    void setColorData17(const QColor &v);
    void setColorData18(const QColor &v);
    void setColorData19(const QColor &v);
    void setColorAiGeneral(const QColor &v);
    void setColorAiGeneralHover(const QColor &v);
    void setColorAiGeneralActive(const QColor &v);
    void setColorAiGeneralDisabled(const QColor &v);
    void setColorAiPurple(const QColor &v);
    void setColorAiPurpleHover(const QColor &v);
    void setColorAiPurpleActive(const QColor &v);
    void setColorAiPurpleDisabled(const QColor &v);
    void setColorAiBackgroundBottom(const QColor &v);
    void setColorAiBackgroundBottomHover(const QColor &v);
    void setColorAiBackgroundBottomActive(const QColor &v);
    void setColorAiBackgroundTop(const QColor &v);
    void setColorAiBackgroundTopHover(const QColor &v);
    void setShadowElevated(const QString &v);
    void setRadiusExtraSmall(int v);
    void setRadiusSmall(int v);
    void setRadiusMedium(int v);
    void setRadiusLarge(int v);
    void setRadiusCircle(int v);
    void setRadiusFull(int v);
    void setDurationSlowest(int v);
    void setDurationSlower(int v);
    void setDurationSlow(int v);
    void setDurationNormal(int v);
    void setDurationFast(int v);
    void setDurationFaster(int v);
    void setDurationFastest(int v);
    void setDurationNone(int v);
    void setEasingLinear(const QString &v);
    void setEasingEase(const QString &v);
    void setEasingEaseIn(const QString &v);
    void setEasingEaseOut(const QString &v);
    void setEasingEaseInIOut(const QString &v);
    void setDelayNone(int v);
    void setDelaySlowest(int v);
    void setDelaySlower(int v);
    void setDelaySlow(int v);
    void setDelayNormal(int v);
    void setDelayFast(int v);
    void setDelayFaster(int v);
    void setDelayFastest(int v);
    void setScaleNone(qreal v);
    void setScaleSmall(qreal v);
    void setScaleMedium(qreal v);
    void setScaleLarge(qreal v);
    void setRotateNone(int v);
    void setRotateClockwise90deg(int v);
    void setRotateClockwise180deg(int v);
    void setRotateClockwise270deg(int v);
    void setRotateClockwise360deg(int v);
    void setRotateAnticlockwise90deg(int v);
    void setRotateAnticlockwise180deg(int v);
    void setRotateAnticlockwise270deg(int v);
    void setRotateAnticlockwise360deg(int v);
    void setHeightControlSmall(int v);
    void setHeightControlDefault(int v);
    void setHeightControlLarge(int v);
    void setBorderThickness(int v);
    void setBorderThicknessControl(int v);
    void setBorderThicknessControlFocus(int v);
    void setWidthIconExtraSmall(int v);
    void setWidthIconSmall(int v);
    void setWidthIconMedium(int v);
    void setWidthIconLarge(int v);
    void setWidthIconExtraLarge(int v);
    void setSpacingNone(int v);
    void setSpacingSuperTight(int v);
    void setSpacingExtraTight(int v);
    void setSpacingTight(int v);
    void setSpacingBaseTight(int v);
    void setSpacingBase(int v);
    void setSpacingBaseLoose(int v);
    void setSpacingLoose(int v);
    void setSpacingExtraLoose(int v);
    void setSpacingSuperLoose(int v);
    void setZPortal(int v);
    void setZAffix(int v);
    void setZBacktop(int v);
    void setZBadge(int v);
    void setZTableFixed(int v);
    void setZModal(int v);
    void setZModalMask(int v);
    void setZToast(int v);
    void setZNotification(int v);
    void setZPopover(int v);
    void setZDropdown(int v);
    void setZTooltip(int v);
    void setZImagePreview(int v);
    void setZImagePreviewHeader(int v);
    void setZTransferRightItemDragItemMove(int v);
    void setZTagInputDragItemMove(int v);
    void setZResizableHandler(int v);
    void setFontSizeSmall(int v);
    void setFontSizeRegular(int v);
    void setFontSizeHeader6(int v);
    void setFontSizeHeader5(int v);
    void setFontSizeHeader4(int v);
    void setFontSizeHeader3(int v);
    void setFontSizeHeader2(int v);
    void setFontSizeHeader1(int v);
    void setFontWeightLight(int v);
    void setFontWeightRegular(int v);
    void setFontWeightBold(int v);
    void setBlack(const QColor &v);
    void setWhite(const QColor &v);
    void setAiGeneral0(const QString &v);
    void setAiGeneral1(const QString &v);
    void setAiGeneral2(const QString &v);
    void setAiGeneral3(const QString &v);
    void setAiGeneral4(const QString &v);
    void setAiGeneral5(const QString &v);
    void setAiGeneral6(const QString &v);
    void setAiGeneral7(const QString &v);
    void setAiGeneral8(const QString &v);
    void setAiGeneral9(const QString &v);

    // 恢复为 Semi 默认值
    Q_INVOKABLE void reset();

Q_SIGNALS:
    void changed();

private:
    void applyDefaults();

    Mode m_mode;
    QList<QColor> m_amber;
    QList<QColor> m_blue;
    QList<QColor> m_cyan;
    QList<QColor> m_green;
    QList<QColor> m_grey;
    QList<QColor> m_indigo;
    QList<QColor> m_lightBlue;
    QList<QColor> m_lightGreen;
    QList<QColor> m_lime;
    QList<QColor> m_orange;
    QList<QColor> m_pink;
    QList<QColor> m_purple;
    QList<QColor> m_red;
    QList<QColor> m_teal;
    QList<QColor> m_violet;
    QList<QColor> m_yellow;
    QList<QColor> m_aiPurple;
    QColor m_colorWhite;
    QColor m_colorBlack;
    QColor m_colorPrimary;
    bool m_colorPrimaryOverridden = false;
    QColor m_colorPrimaryHover;
    bool m_colorPrimaryHoverOverridden = false;
    QColor m_colorPrimaryActive;
    bool m_colorPrimaryActiveOverridden = false;
    QColor m_colorPrimaryDisabled;
    bool m_colorPrimaryDisabledOverridden = false;
    QColor m_colorPrimaryLightDefault;
    QColor m_colorPrimaryLightHover;
    QColor m_colorPrimaryLightActive;
    QColor m_colorSecondary;
    bool m_colorSecondaryOverridden = false;
    QColor m_colorSecondaryHover;
    bool m_colorSecondaryHoverOverridden = false;
    QColor m_colorSecondaryActive;
    bool m_colorSecondaryActiveOverridden = false;
    QColor m_colorSecondaryDisabled;
    bool m_colorSecondaryDisabledOverridden = false;
    QColor m_colorSecondaryLightDefault;
    QColor m_colorSecondaryLightHover;
    QColor m_colorSecondaryLightActive;
    QColor m_colorTertiary;
    bool m_colorTertiaryOverridden = false;
    QColor m_colorTertiaryHover;
    bool m_colorTertiaryHoverOverridden = false;
    QColor m_colorTertiaryActive;
    bool m_colorTertiaryActiveOverridden = false;
    QColor m_colorTertiaryLightDefault;
    QColor m_colorTertiaryLightHover;
    QColor m_colorTertiaryLightActive;
    QColor m_colorDefault;
    bool m_colorDefaultOverridden = false;
    QColor m_colorDefaultHover;
    bool m_colorDefaultHoverOverridden = false;
    QColor m_colorDefaultActive;
    bool m_colorDefaultActiveOverridden = false;
    QColor m_colorInfo;
    bool m_colorInfoOverridden = false;
    QColor m_colorInfoHover;
    bool m_colorInfoHoverOverridden = false;
    QColor m_colorInfoActive;
    bool m_colorInfoActiveOverridden = false;
    QColor m_colorInfoDisabled;
    bool m_colorInfoDisabledOverridden = false;
    QColor m_colorInfoLightDefault;
    QColor m_colorInfoLightHover;
    QColor m_colorInfoLightActive;
    QColor m_colorSuccess;
    bool m_colorSuccessOverridden = false;
    QColor m_colorSuccessHover;
    bool m_colorSuccessHoverOverridden = false;
    QColor m_colorSuccessActive;
    bool m_colorSuccessActiveOverridden = false;
    QColor m_colorSuccessDisabled;
    bool m_colorSuccessDisabledOverridden = false;
    QColor m_colorSuccessLightDefault;
    QColor m_colorSuccessLightHover;
    QColor m_colorSuccessLightActive;
    QColor m_colorDanger;
    bool m_colorDangerOverridden = false;
    QColor m_colorDangerHover;
    bool m_colorDangerHoverOverridden = false;
    QColor m_colorDangerActive;
    bool m_colorDangerActiveOverridden = false;
    QColor m_colorDangerLightDefault;
    QColor m_colorDangerLightHover;
    QColor m_colorDangerLightActive;
    QColor m_colorWarning;
    bool m_colorWarningOverridden = false;
    QColor m_colorWarningHover;
    bool m_colorWarningHoverOverridden = false;
    QColor m_colorWarningActive;
    bool m_colorWarningActiveOverridden = false;
    QColor m_colorWarningLightDefault;
    QColor m_colorWarningLightHover;
    QColor m_colorWarningLightActive;
    QColor m_colorFocusBorder;
    bool m_colorFocusBorderOverridden = false;
    QColor m_colorDisabledText;
    QColor m_colorDisabledBorder;
    bool m_colorDisabledBorderOverridden = false;
    QColor m_colorDisabledBg;
    bool m_colorDisabledBgOverridden = false;
    QColor m_colorDisabledFill;
    QColor m_colorShadow;
    QColor m_colorLink;
    bool m_colorLinkOverridden = false;
    QColor m_colorLinkHover;
    bool m_colorLinkHoverOverridden = false;
    QColor m_colorLinkActive;
    bool m_colorLinkActiveOverridden = false;
    QColor m_colorLinkVisited;
    bool m_colorLinkVisitedOverridden = false;
    QColor m_colorBorder;
    QColor m_colorNavBg;
    QColor m_colorOverlayBg;
    QColor m_colorFill0;
    QColor m_colorFill1;
    QColor m_colorFill2;
    QColor m_colorBg0;
    QColor m_colorBg1;
    QColor m_colorBg2;
    QColor m_colorBg3;
    QColor m_colorBg4;
    QColor m_colorText0;
    bool m_colorText0Overridden = false;
    QColor m_colorText1;
    QColor m_colorText2;
    QColor m_colorText3;
    QColor m_colorHighlightBg;
    QColor m_colorHighlight;
    QColor m_colorData0;
    QColor m_colorData1;
    QColor m_colorData2;
    QColor m_colorData3;
    QColor m_colorData4;
    QColor m_colorData5;
    QColor m_colorData6;
    QColor m_colorData7;
    QColor m_colorData8;
    QColor m_colorData9;
    QColor m_colorData10;
    QColor m_colorData11;
    QColor m_colorData12;
    QColor m_colorData13;
    QColor m_colorData14;
    QColor m_colorData15;
    QColor m_colorData16;
    QColor m_colorData17;
    QColor m_colorData18;
    QColor m_colorData19;
    QColor m_colorAiGeneral;
    QColor m_colorAiGeneralHover;
    QColor m_colorAiGeneralActive;
    QColor m_colorAiGeneralDisabled;
    QColor m_colorAiPurple;
    bool m_colorAiPurpleOverridden = false;
    QColor m_colorAiPurpleHover;
    bool m_colorAiPurpleHoverOverridden = false;
    QColor m_colorAiPurpleActive;
    bool m_colorAiPurpleActiveOverridden = false;
    QColor m_colorAiPurpleDisabled;
    bool m_colorAiPurpleDisabledOverridden = false;
    QColor m_colorAiBackgroundBottom;
    QColor m_colorAiBackgroundBottomHover;
    QColor m_colorAiBackgroundBottomActive;
    QColor m_colorAiBackgroundTop;
    QColor m_colorAiBackgroundTopHover;
    QString m_shadowElevated = QStringLiteral("0 0 1px rgba(0, 0, 0, .3), 0 4px 14px rgba(0, 0, 0, .1)");
    int m_radiusExtraSmall = 3;
    int m_radiusSmall = 3;
    int m_radiusMedium = 6;
    int m_radiusLarge = 12;
    int m_radiusCircle = 0;
    int m_radiusFull = 9999;
    int m_durationSlowest = 0;
    int m_durationSlower = 0;
    int m_durationSlow = 0;
    int m_durationNormal = 0;
    int m_durationFast = 0;
    int m_durationFaster = 0;
    int m_durationFastest = 0;
    int m_durationNone = 0;
    QString m_easingLinear = QStringLiteral("linear");
    QString m_easingEase = QStringLiteral("ease");
    QString m_easingEaseIn = QStringLiteral("ease-in");
    QString m_easingEaseOut = QStringLiteral("ease-out");
    QString m_easingEaseInIOut = QStringLiteral("ease-in-out");
    int m_delayNone = 0;
    int m_delaySlowest = 0;
    int m_delaySlower = 0;
    int m_delaySlow = 0;
    int m_delayNormal = 0;
    int m_delayFast = 0;
    int m_delayFaster = 0;
    int m_delayFastest = 0;
    qreal m_scaleNone = 1.0;
    qreal m_scaleSmall = 1.0;
    qreal m_scaleMedium = 1.0;
    qreal m_scaleLarge = 1.0;
    int m_rotateNone = 0;
    int m_rotateClockwise90deg = 0;
    int m_rotateClockwise180deg = 0;
    int m_rotateClockwise270deg = 0;
    int m_rotateClockwise360deg = 0;
    int m_rotateAnticlockwise90deg = 0;
    int m_rotateAnticlockwise180deg = 0;
    int m_rotateAnticlockwise270deg = 0;
    int m_rotateAnticlockwise360deg = 0;
    int m_heightControlSmall = 24;
    int m_heightControlDefault = 32;
    int m_heightControlLarge = 40;
    int m_borderThickness = 0;
    int m_borderThicknessControl = 1;
    int m_borderThicknessControlFocus = 1;
    int m_widthIconExtraSmall = 8;
    int m_widthIconSmall = 12;
    int m_widthIconMedium = 16;
    int m_widthIconLarge = 20;
    int m_widthIconExtraLarge = 24;
    int m_spacingNone = 0;
    int m_spacingSuperTight = 2;
    int m_spacingExtraTight = 4;
    int m_spacingTight = 8;
    int m_spacingBaseTight = 12;
    int m_spacingBase = 16;
    int m_spacingBaseLoose = 20;
    int m_spacingLoose = 24;
    int m_spacingExtraLoose = 32;
    int m_spacingSuperLoose = 40;
    int m_zPortal = 1;
    int m_zAffix = 10;
    int m_zBacktop = 10;
    int m_zBadge = 10;
    int m_zTableFixed = 101;
    int m_zModal = 1000;
    int m_zModalMask = 1000;
    int m_zToast = 1010;
    int m_zNotification = 1010;
    int m_zPopover = 1030;
    int m_zDropdown = 1050;
    int m_zTooltip = 1060;
    int m_zImagePreview = 1070;
    int m_zImagePreviewHeader = 1;
    int m_zTransferRightItemDragItemMove = 2000;
    int m_zTagInputDragItemMove = 2000;
    int m_zResizableHandler = 10;
    int m_fontSizeSmall = 12;
    int m_fontSizeRegular = 14;
    int m_fontSizeHeader6 = 16;
    int m_fontSizeHeader5 = 18;
    int m_fontSizeHeader4 = 20;
    int m_fontSizeHeader3 = 24;
    int m_fontSizeHeader2 = 28;
    int m_fontSizeHeader1 = 32;
    int m_fontWeightLight = 200;
    int m_fontWeightRegular = 400;
    int m_fontWeightBold = 600;
    QColor m_black;
    QColor m_white;
    QString m_aiGeneral0;
    QString m_aiGeneral1;
    QString m_aiGeneral2;
    QString m_aiGeneral3;
    QString m_aiGeneral4;
    QString m_aiGeneral5;
    QString m_aiGeneral6;
    QString m_aiGeneral7;
    QString m_aiGeneral8;
    QString m_aiGeneral9;
};

} // namespace semi
