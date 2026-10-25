#include "SemiThemeValues.h"

namespace semi {

namespace {

QList<QColor> amberLight() { return { QColor(QStringLiteral("#fefbeb")), QColor(QStringLiteral("#fcf5ce")), QColor(QStringLiteral("#f9e89e")), QColor(QStringLiteral("#f6d86f")), QColor(QStringLiteral("#f3c641")), QColor(QStringLiteral("#f0b114")), QColor(QStringLiteral("#c88a0f")), QColor(QStringLiteral("#a0660a")), QColor(QStringLiteral("#784606")), QColor(QStringLiteral("#502b03")) }; }
QList<QColor> amberDark() { return { QColor(QStringLiteral("#512e09")), QColor(QStringLiteral("#794b0f")), QColor(QStringLiteral("#a16b16")), QColor(QStringLiteral("#ca8f1e")), QColor(QStringLiteral("#f2b726")), QColor(QStringLiteral("#f5ca50")), QColor(QStringLiteral("#f7db7a")), QColor(QStringLiteral("#faeaa6")), QColor(QStringLiteral("#fcf6d2")), QColor(QStringLiteral("#fefbed")) }; }
QList<QColor> blueLight() { return { QColor(QStringLiteral("#eaf5ff")), QColor(QStringLiteral("#cbe7fe")), QColor(QStringLiteral("#98cdfd")), QColor(QStringLiteral("#65b2fc")), QColor(QStringLiteral("#3295fb")), QColor(QStringLiteral("#0064fa")), QColor(QStringLiteral("#0062d6")), QColor(QStringLiteral("#004fb3")), QColor(QStringLiteral("#003d8f")), QColor(QStringLiteral("#002c6b")) }; }
QList<QColor> blueDark() { return { QColor(QStringLiteral("#053170")), QColor(QStringLiteral("#0a4694")), QColor(QStringLiteral("#135cb8")), QColor(QStringLiteral("#1d75db")), QColor(QStringLiteral("#2990ff")), QColor(QStringLiteral("#54a9ff")), QColor(QStringLiteral("#7fc1ff")), QColor(QStringLiteral("#a9d7ff")), QColor(QStringLiteral("#d4ecff")), QColor(QStringLiteral("#eff8ff")) }; }
QList<QColor> cyanLight() { return { QColor(QStringLiteral("#e5f7f8")), QColor(QStringLiteral("#c2eff0")), QColor(QStringLiteral("#8adde2")), QColor(QStringLiteral("#58cbd3")), QColor(QStringLiteral("#2cb8c5")), QColor(QStringLiteral("#05a4b6")), QColor(QStringLiteral("#038698")), QColor(QStringLiteral("#016979")), QColor(QStringLiteral("#004d5b")), QColor(QStringLiteral("#00323d")) }; }
QList<QColor> cyanDark() { return { QColor(QStringLiteral("#04343d")), QColor(QStringLiteral("#074f5c")), QColor(QStringLiteral("#0a6c7b")), QColor(QStringLiteral("#0e8999")), QColor(QStringLiteral("#13a8b8")), QColor(QStringLiteral("#38bbc6")), QColor(QStringLiteral("#62cdd4")), QColor(QStringLiteral("#91dfe3")), QColor(QStringLiteral("#c6eff1")), QColor(QStringLiteral("#e7f7f8")) }; }
QList<QColor> greenLight() { return { QColor(QStringLiteral("#ecf7ec")), QColor(QStringLiteral("#d0f0d1")), QColor(QStringLiteral("#a4e0a7")), QColor(QStringLiteral("#7dd182")), QColor(QStringLiteral("#5ac262")), QColor(QStringLiteral("#3bb346")), QColor(QStringLiteral("#30953b")), QColor(QStringLiteral("#25772f")), QColor(QStringLiteral("#1b5924")), QColor(QStringLiteral("#113c18")) }; }
QList<QColor> greenDark() { return { QColor(QStringLiteral("#123c19")), QColor(QStringLiteral("#1c5a25")), QColor(QStringLiteral("#277731")), QColor(QStringLiteral("#32953d")), QColor(QStringLiteral("#3eb349")), QColor(QStringLiteral("#5dc264")), QColor(QStringLiteral("#7fd184")), QColor(QStringLiteral("#a6e1a8")), QColor(QStringLiteral("#d0f0d1")), QColor(QStringLiteral("#ecf7ec")) }; }
QList<QColor> greyLight() { return { QColor(QStringLiteral("#f9f9f9")), QColor(QStringLiteral("#e6e8ea")), QColor(QStringLiteral("#c6cacd")), QColor(QStringLiteral("#a7abb0")), QColor(QStringLiteral("#888d92")), QColor(QStringLiteral("#6b7075")), QColor(QStringLiteral("#555b61")), QColor(QStringLiteral("#41464c")), QColor(QStringLiteral("#2e3238")), QColor(QStringLiteral("#1c1f23")) }; }
QList<QColor> greyDark() { return { QColor(QStringLiteral("#1c1f23")), QColor(QStringLiteral("#2e3238")), QColor(QStringLiteral("#41464c")), QColor(QStringLiteral("#555b61")), QColor(QStringLiteral("#6b7075")), QColor(QStringLiteral("#888d92")), QColor(QStringLiteral("#a7abb0")), QColor(QStringLiteral("#c6cacd")), QColor(QStringLiteral("#e6e8ea")), QColor(QStringLiteral("#f9f9f9")) }; }
QList<QColor> indigoLight() { return { QColor(QStringLiteral("#eceff8")), QColor(QStringLiteral("#d1d8f0")), QColor(QStringLiteral("#a7b3e1")), QColor(QStringLiteral("#8090d3")), QColor(QStringLiteral("#5e6fc4")), QColor(QStringLiteral("#3f51b5")), QColor(QStringLiteral("#3342a1")), QColor(QStringLiteral("#28348c")), QColor(QStringLiteral("#1f2878")), QColor(QStringLiteral("#171d63")) }; }
QList<QColor> indigoDark() { return { QColor(QStringLiteral("#171e65")), QColor(QStringLiteral("#20297a")), QColor(QStringLiteral("#29368e")), QColor(QStringLiteral("#3444a3")), QColor(QStringLiteral("#4053b7")), QColor(QStringLiteral("#5f71c5")), QColor(QStringLiteral("#8191d4")), QColor(QStringLiteral("#a7b4e2")), QColor(QStringLiteral("#d1d8f1")), QColor(QStringLiteral("#edeff8")) }; }
QList<QColor> lightBlueLight() { return { QColor(QStringLiteral("#e9f7fd")), QColor(QStringLiteral("#c9ecfc")), QColor(QStringLiteral("#95d8f8")), QColor(QStringLiteral("#62c3f5")), QColor(QStringLiteral("#30acf1")), QColor(QStringLiteral("#0095ee")), QColor(QStringLiteral("#007bca")), QColor(QStringLiteral("#0063a7")), QColor(QStringLiteral("#004b83")), QColor(QStringLiteral("#00355f")) }; }
QList<QColor> lightBlueDark() { return { QColor(QStringLiteral("#003761")), QColor(QStringLiteral("#004d85")), QColor(QStringLiteral("#0366a9")), QColor(QStringLiteral("#0a81cc")), QColor(QStringLiteral("#139ff0")), QColor(QStringLiteral("#40b4f3")), QColor(QStringLiteral("#6ec8f6")), QColor(QStringLiteral("#9ddcf9")), QColor(QStringLiteral("#ceeefc")), QColor(QStringLiteral("#ebf8fe")) }; }
QList<QColor> lightGreenLight() { return { QColor(QStringLiteral("#f3f8ec")), QColor(QStringLiteral("#e3f0d0")), QColor(QStringLiteral("#c8e2a5")), QColor(QStringLiteral("#add37e")), QColor(QStringLiteral("#93c55b")), QColor(QStringLiteral("#7bb63c")), QColor(QStringLiteral("#649830")), QColor(QStringLiteral("#4e7926")), QColor(QStringLiteral("#395b1b")), QColor(QStringLiteral("#253d12")) }; }
QList<QColor> lightGreenDark() { return { QColor(QStringLiteral("#263d13")), QColor(QStringLiteral("#3b5c1d")), QColor(QStringLiteral("#517b28")), QColor(QStringLiteral("#679934")), QColor(QStringLiteral("#7fb840")), QColor(QStringLiteral("#97c65f")), QColor(QStringLiteral("#b0d481")), QColor(QStringLiteral("#c9e3a7")), QColor(QStringLiteral("#e4f1d1")), QColor(QStringLiteral("#f3f8ed")) }; }
QList<QColor> limeLight() { return { QColor(QStringLiteral("#f2fae6")), QColor(QStringLiteral("#e3f6c5")), QColor(QStringLiteral("#cbed8e")), QColor(QStringLiteral("#b7e35b")), QColor(QStringLiteral("#a7da2c")), QColor(QStringLiteral("#9bd100")), QColor(QStringLiteral("#7eae00")), QColor(QStringLiteral("#638b00")), QColor(QStringLiteral("#486800")), QColor(QStringLiteral("#2f4600")) }; }
QList<QColor> limeDark() { return { QColor(QStringLiteral("#314603")), QColor(QStringLiteral("#4b6905")), QColor(QStringLiteral("#678d09")), QColor(QStringLiteral("#84b00c")), QColor(QStringLiteral("#a2d311")), QColor(QStringLiteral("#aedc3a")), QColor(QStringLiteral("#bde566")), QColor(QStringLiteral("#cfed96")), QColor(QStringLiteral("#e5f6c9")), QColor(QStringLiteral("#f3fbe9")) }; }
QList<QColor> orangeLight() { return { QColor(QStringLiteral("#fff8ea")), QColor(QStringLiteral("#feeecc")), QColor(QStringLiteral("#fed998")), QColor(QStringLiteral("#fdc165")), QColor(QStringLiteral("#fda633")), QColor(QStringLiteral("#fc8800")), QColor(QStringLiteral("#d26700")), QColor(QStringLiteral("#a84a00")), QColor(QStringLiteral("#7e3100")), QColor(QStringLiteral("#541d00")) }; }
QList<QColor> orangeDark() { return { QColor(QStringLiteral("#551f03")), QColor(QStringLiteral("#803506")), QColor(QStringLiteral("#aa500a")), QColor(QStringLiteral("#d56f0f")), QColor(QStringLiteral("#ff9214")), QColor(QStringLiteral("#ffae43")), QColor(QStringLiteral("#ffc772")), QColor(QStringLiteral("#ffdda1")), QColor(QStringLiteral("#ffefd0")), QColor(QStringLiteral("#fff9ed")) }; }
QList<QColor> pinkLight() { return { QColor(QStringLiteral("#fdecef")), QColor(QStringLiteral("#fbcfd8")), QColor(QStringLiteral("#f6a0b5")), QColor(QStringLiteral("#f27396")), QColor(QStringLiteral("#ed487b")), QColor(QStringLiteral("#e91e63")), QColor(QStringLiteral("#c51356")), QColor(QStringLiteral("#a20b48")), QColor(QStringLiteral("#7e053a")), QColor(QStringLiteral("#5a012b")) }; }
QList<QColor> pinkDark() { return { QColor(QStringLiteral("#5c0730")), QColor(QStringLiteral("#800e41")), QColor(QStringLiteral("#a41751")), QColor(QStringLiteral("#c72261")), QColor(QStringLiteral("#eb2f71")), QColor(QStringLiteral("#ef5686")), QColor(QStringLiteral("#f37e9f")), QColor(QStringLiteral("#f7a8bc")), QColor(QStringLiteral("#fbd3dc")), QColor(QStringLiteral("#fdeef1")) }; }
QList<QColor> purpleLight() { return { QColor(QStringLiteral("#f7e9f7")), QColor(QStringLiteral("#efcaf0")), QColor(QStringLiteral("#dd9be0")), QColor(QStringLiteral("#c96fd1")), QColor(QStringLiteral("#b449c2")), QColor(QStringLiteral("#9e28b3")), QColor(QStringLiteral("#871e9e")), QColor(QStringLiteral("#71168a")), QColor(QStringLiteral("#5c0f75")), QColor(QStringLiteral("#490a61")) }; }
QList<QColor> purpleDark() { return { QColor(QStringLiteral("#4a1061")), QColor(QStringLiteral("#5e1776")), QColor(QStringLiteral("#731f8a")), QColor(QStringLiteral("#89289f")), QColor(QStringLiteral("#a033b3")), QColor(QStringLiteral("#b553c2")), QColor(QStringLiteral("#ca78d1")), QColor(QStringLiteral("#dda0e1")), QColor(QStringLiteral("#efcef0")), QColor(QStringLiteral("#f7ebf7")) }; }
QList<QColor> redLight() { return { QColor(QStringLiteral("#fef2ed")), QColor(QStringLiteral("#feddd2")), QColor(QStringLiteral("#fdb7a5")), QColor(QStringLiteral("#fb9078")), QColor(QStringLiteral("#fa664c")), QColor(QStringLiteral("#f93920")), QColor(QStringLiteral("#d52515")), QColor(QStringLiteral("#b2140c")), QColor(QStringLiteral("#8e0805")), QColor(QStringLiteral("#6a0103")) }; }
QList<QColor> redDark() { return { QColor(QStringLiteral("#6c090b")), QColor(QStringLiteral("#901110")), QColor(QStringLiteral("#b42019")), QColor(QStringLiteral("#d73324")), QColor(QStringLiteral("#fb4932")), QColor(QStringLiteral("#fc725a")), QColor(QStringLiteral("#fd9983")), QColor(QStringLiteral("#fdbeac")), QColor(QStringLiteral("#fee0d5")), QColor(QStringLiteral("#fff3ef")) }; }
QList<QColor> tealLight() { return { QColor(QStringLiteral("#e4f7f4")), QColor(QStringLiteral("#c0f0e8")), QColor(QStringLiteral("#87e0d3")), QColor(QStringLiteral("#54d1c1")), QColor(QStringLiteral("#27c2b0")), QColor(QStringLiteral("#00b3a1")), QColor(QStringLiteral("#009589")), QColor(QStringLiteral("#00776f")), QColor(QStringLiteral("#005955")), QColor(QStringLiteral("#003c3a")) }; }
QList<QColor> tealDark() { return { QColor(QStringLiteral("#023c39")), QColor(QStringLiteral("#045a55")), QColor(QStringLiteral("#07776f")), QColor(QStringLiteral("#0a9588")), QColor(QStringLiteral("#0eb3a1")), QColor(QStringLiteral("#33c2b0")), QColor(QStringLiteral("#5ed1c1")), QColor(QStringLiteral("#8ee1d3")), QColor(QStringLiteral("#c4f0e8")), QColor(QStringLiteral("#e6f7f4")) }; }
QList<QColor> violetLight() { return { QColor(QStringLiteral("#f3edf9")), QColor(QStringLiteral("#e2d1f4")), QColor(QStringLiteral("#c4a7e9")), QColor(QStringLiteral("#a67fdd")), QColor(QStringLiteral("#885bd2")), QColor(QStringLiteral("#6a3ac7")), QColor(QStringLiteral("#572fb3")), QColor(QStringLiteral("#46259e")), QColor(QStringLiteral("#361c8a")), QColor(QStringLiteral("#281475")) }; }
QList<QColor> violetDark() { return { QColor(QStringLiteral("#401b77")), QColor(QStringLiteral("#4c248c")), QColor(QStringLiteral("#582ea0")), QColor(QStringLiteral("#6439b5")), QColor(QStringLiteral("#7246c9")), QColor(QStringLiteral("#8865d4")), QColor(QStringLiteral("#a288df")), QColor(QStringLiteral("#beade9")), QColor(QStringLiteral("#ddd4f4")), QColor(QStringLiteral("#f1eefa")) }; }
QList<QColor> yellowLight() { return { QColor(QStringLiteral("#fffdea")), QColor(QStringLiteral("#fefbcb")), QColor(QStringLiteral("#fdf398")), QColor(QStringLiteral("#fce865")), QColor(QStringLiteral("#fbda32")), QColor(QStringLiteral("#fac800")), QColor(QStringLiteral("#d0aa00")), QColor(QStringLiteral("#a78b00")), QColor(QStringLiteral("#7d6a00")), QColor(QStringLiteral("#534800")) }; }
QList<QColor> yellowDark() { return { QColor(QStringLiteral("#544903")), QColor(QStringLiteral("#7e6c06")), QColor(QStringLiteral("#a88e0a")), QColor(QStringLiteral("#d2af0f")), QColor(QStringLiteral("#fcce14")), QColor(QStringLiteral("#fdde43")), QColor(QStringLiteral("#fdeb71")), QColor(QStringLiteral("#fef5a0")), QColor(QStringLiteral("#fefbd0")), QColor(QStringLiteral("#fffeec")) }; }
QList<QColor> aiPurpleLight() { return { QColor(QStringLiteral("#f8edff")), QColor(QStringLiteral("#f2daff")), QColor(QStringLiteral("#e3b5ff")), QColor(QStringLiteral("#d191ff")), QColor(QStringLiteral("#bd6cff")), QColor(QStringLiteral("#a647ff")), QColor(QStringLiteral("#8636db")), QColor(QStringLiteral("#6928b8")), QColor(QStringLiteral("#4e1c94")), QColor(QStringLiteral("#361270")) }; }
QList<QColor> aiPurpleDark() { return { QColor(QStringLiteral("#3a1770")), QColor(QStringLiteral("#532394")), QColor(QStringLiteral("#6f31b8")), QColor(QStringLiteral("#8d41db")), QColor(QStringLiteral("#a744ff")), QColor(QStringLiteral("#c375ff")), QColor(QStringLiteral("#d598ff")), QColor(QStringLiteral("#e5baff")), QColor(QStringLiteral("#f3ddff")), QColor(QStringLiteral("#fbf3ff")) }; }

const QColor colorWhiteLight = QColor(QStringLiteral("#ffffff"));
const QColor colorWhiteDark = QColor(QStringLiteral("#e4e7f5"));
const QColor colorBlackLight = QColor(QStringLiteral("#000000"));
const QColor colorBlackDark = QColor(QStringLiteral("#000000"));
const QColor colorPrimaryLightDefaultLight = QColor(QStringLiteral("#eaf5ff"));
const QColor colorPrimaryLightDefaultDark = QColor(84, 169, 255, 51);
const QColor colorPrimaryLightHoverLight = QColor(QStringLiteral("#cbe7fe"));
const QColor colorPrimaryLightHoverDark = QColor(84, 169, 255, 76);
const QColor colorPrimaryLightActiveLight = QColor(QStringLiteral("#98cdfd"));
const QColor colorPrimaryLightActiveDark = QColor(84, 169, 255, 102);
const QColor colorSecondaryLightDefaultLight = QColor(QStringLiteral("#e9f7fd"));
const QColor colorSecondaryLightDefaultDark = QColor(64, 180, 243, 51);
const QColor colorSecondaryLightHoverLight = QColor(QStringLiteral("#c9ecfc"));
const QColor colorSecondaryLightHoverDark = QColor(64, 180, 243, 76);
const QColor colorSecondaryLightActiveLight = QColor(QStringLiteral("#95d8f8"));
const QColor colorSecondaryLightActiveDark = QColor(64, 180, 243, 102);
const QColor colorTertiaryLightDefaultLight = QColor(QStringLiteral("#f9f9f9"));
const QColor colorTertiaryLightDefaultDark = QColor(136, 141, 146, 51);
const QColor colorTertiaryLightHoverLight = QColor(QStringLiteral("#e6e8ea"));
const QColor colorTertiaryLightHoverDark = QColor(136, 141, 146, 76);
const QColor colorTertiaryLightActiveLight = QColor(QStringLiteral("#c6cacd"));
const QColor colorTertiaryLightActiveDark = QColor(136, 141, 146, 102);
const QColor colorInfoLightDefaultLight = QColor(QStringLiteral("#eaf5ff"));
const QColor colorInfoLightDefaultDark = QColor(84, 169, 255, 51);
const QColor colorInfoLightHoverLight = QColor(QStringLiteral("#cbe7fe"));
const QColor colorInfoLightHoverDark = QColor(84, 169, 255, 76);
const QColor colorInfoLightActiveLight = QColor(QStringLiteral("#98cdfd"));
const QColor colorInfoLightActiveDark = QColor(84, 169, 255, 102);
const QColor colorSuccessLightDefaultLight = QColor(QStringLiteral("#ecf7ec"));
const QColor colorSuccessLightDefaultDark = QColor(93, 194, 100, 51);
const QColor colorSuccessLightHoverLight = QColor(QStringLiteral("#d0f0d1"));
const QColor colorSuccessLightHoverDark = QColor(93, 194, 100, 76);
const QColor colorSuccessLightActiveLight = QColor(QStringLiteral("#a4e0a7"));
const QColor colorSuccessLightActiveDark = QColor(93, 194, 100, 102);
const QColor colorDangerLightDefaultLight = QColor(QStringLiteral("#fef2ed"));
const QColor colorDangerLightDefaultDark = QColor(252, 114, 90, 51);
const QColor colorDangerLightHoverLight = QColor(QStringLiteral("#feddd2"));
const QColor colorDangerLightHoverDark = QColor(252, 114, 90, 76);
const QColor colorDangerLightActiveLight = QColor(QStringLiteral("#fdb7a5"));
const QColor colorDangerLightActiveDark = QColor(252, 114, 90, 102);
const QColor colorWarningLightDefaultLight = QColor(QStringLiteral("#fff8ea"));
const QColor colorWarningLightDefaultDark = QColor(255, 174, 67, 51);
const QColor colorWarningLightHoverLight = QColor(QStringLiteral("#feeecc"));
const QColor colorWarningLightHoverDark = QColor(255, 174, 67, 76);
const QColor colorWarningLightActiveLight = QColor(QStringLiteral("#fed998"));
const QColor colorWarningLightActiveDark = QColor(255, 174, 67, 102);
const QColor colorDisabledTextLight = QColor(28, 31, 35, 89);
const QColor colorDisabledTextDark = QColor(249, 249, 249, 89);
const QColor colorDisabledFillLight = QColor(46, 50, 56, 10);
const QColor colorDisabledFillDark = QColor(230, 232, 234, 10);
const QColor colorShadowLight = QColor(0, 0, 0, 10);
const QColor colorShadowDark = QColor(0, 0, 0, 10);
const QColor colorBorderLight = QColor(28, 31, 35, 20);
const QColor colorBorderDark = QColor(255, 255, 255, 20);
const QColor colorNavBgLight = QColor(QStringLiteral("#ffffff"));
const QColor colorNavBgDark = QColor(QStringLiteral("#232429"));
const QColor colorOverlayBgLight = QColor(22, 22, 26, 153);
const QColor colorOverlayBgDark = QColor(22, 22, 26, 153);
const QColor colorFill0Light = QColor(46, 50, 56, 13);
const QColor colorFill0Dark = QColor(255, 255, 255, 31);
const QColor colorFill1Light = QColor(46, 50, 56, 23);
const QColor colorFill1Dark = QColor(255, 255, 255, 41);
const QColor colorFill2Light = QColor(46, 50, 56, 33);
const QColor colorFill2Dark = QColor(255, 255, 255, 51);
const QColor colorBg0Light = QColor(QStringLiteral("#ffffff"));
const QColor colorBg0Dark = QColor(QStringLiteral("#16161a"));
const QColor colorBg1Light = QColor(QStringLiteral("#ffffff"));
const QColor colorBg1Dark = QColor(QStringLiteral("#232429"));
const QColor colorBg2Light = QColor(QStringLiteral("#ffffff"));
const QColor colorBg2Dark = QColor(QStringLiteral("#35363c"));
const QColor colorBg3Light = QColor(QStringLiteral("#ffffff"));
const QColor colorBg3Dark = QColor(QStringLiteral("#43444a"));
const QColor colorBg4Light = QColor(QStringLiteral("#ffffff"));
const QColor colorBg4Dark = QColor(QStringLiteral("#4f5159"));
const QColor colorText1Light = QColor(28, 31, 35, 204);
const QColor colorText1Dark = QColor(249, 249, 249, 204);
const QColor colorText2Light = QColor(28, 31, 35, 158);
const QColor colorText2Dark = QColor(249, 249, 249, 153);
const QColor colorText3Light = QColor(28, 31, 35, 89);
const QColor colorText3Dark = QColor(249, 249, 249, 89);
const QColor colorHighlightBgLight = QColor(QStringLiteral("#fbda32"));
const QColor colorHighlightBgDark = QColor(QStringLiteral("#a88e0a"));
const QColor colorHighlightLight = QColor(QStringLiteral("#000000"));
const QColor colorHighlightDark = QColor(QStringLiteral("#ffffff"));
const QColor colorData0Light = QColor(QStringLiteral("#5769ff"));
const QColor colorData0Dark = QColor(QStringLiteral("#5e6dc2"));
const QColor colorData1Light = QColor(QStringLiteral("#8ed4e7"));
const QColor colorData1Dark = QColor(QStringLiteral("#086878"));
const QColor colorData2Light = QColor(QStringLiteral("#f58700"));
const QColor colorData2Dark = QColor(QStringLiteral("#faad3f"));
const QColor colorData3Light = QColor(QStringLiteral("#dcb7fc"));
const QColor colorData3Dark = QColor(QStringLiteral("#4c2b9c"));
const QColor colorData4Light = QColor(QStringLiteral("#4a9cf7"));
const QColor colorData4Dark = QColor(QStringLiteral("#107df8"));
const QColor colorData5Light = QColor(QStringLiteral("#f3cc35"));
const QColor colorData5Dark = QColor(QStringLiteral("#f8ca10"));
const QColor colorData6Light = QColor(QStringLiteral("#fe8090"));
const QColor colorData6Dark = QColor(QStringLiteral("#c31e57"));
const QColor colorData7Light = QColor(QStringLiteral("#8bd7d2"));
const QColor colorData7Dark = QColor(QStringLiteral("#057773"));
const QColor colorData8Light = QColor(QStringLiteral("#83b023"));
const QColor colorData8Dark = QColor(QStringLiteral("#9acf0d"));
const QColor colorData9Light = QColor(QStringLiteral("#e9a5e5"));
const QColor colorData9Dark = QColor(QStringLiteral("#751d8a"));
const QColor colorData10Light = QColor(QStringLiteral("#30a7ce"));
const QColor colorData10Dark = QColor(QStringLiteral("#10a2b4"));
const QColor colorData11Light = QColor(QStringLiteral("#f9c064"));
const QColor colorData11Dark = QColor(QStringLiteral("#d06e0b"));
const QColor colorData12Light = QColor(QStringLiteral("#b171f9"));
const QColor colorData12Dark = QColor(QStringLiteral("#7142c5"));
const QColor colorData13Light = QColor(QStringLiteral("#77b6f9"));
const QColor colorData13Dark = QColor(QStringLiteral("#0764d4"));
const QColor colorData14Light = QColor(QStringLiteral("#c88f02"));
const QColor colorData14Dark = QColor(QStringLiteral("#fbe86e"));
const QColor colorData15Light = QColor(QStringLiteral("#ffaab2"));
const QColor colorData15Dark = QColor(QStringLiteral("#a01349"));
const QColor colorData16Light = QColor(QStringLiteral("#33b0ab"));
const QColor colorData16Dark = QColor(QStringLiteral("#0bb3a7"));
const QColor colorData17Light = QColor(QStringLiteral("#b6d781"));
const QColor colorData17Dark = QColor(QStringLiteral("#628a06"));
const QColor colorData18Light = QColor(QStringLiteral("#d458d4"));
const QColor colorData18Dark = QColor(QStringLiteral("#a230b3"));
const QColor colorData19Light = QColor(QStringLiteral("#bcc6ff"));
const QColor colorData19Dark = QColor(QStringLiteral("#28338a"));
const QColor colorAiGeneralLight = QColor();
const QColor colorAiGeneralDark = QColor();
const QColor colorAiGeneralHoverLight = QColor();
const QColor colorAiGeneralHoverDark = QColor();
const QColor colorAiGeneralActiveLight = QColor();
const QColor colorAiGeneralActiveDark = QColor();
const QColor colorAiGeneralDisabledLight = QColor();
const QColor colorAiGeneralDisabledDark = QColor();
const QColor colorAiBackgroundBottomLight = QColor();
const QColor colorAiBackgroundBottomDark = QColor();
const QColor colorAiBackgroundBottomHoverLight = QColor();
const QColor colorAiBackgroundBottomHoverDark = QColor();
const QColor colorAiBackgroundBottomActiveLight = QColor();
const QColor colorAiBackgroundBottomActiveDark = QColor();
const QColor colorAiBackgroundTopLight = QColor();
const QColor colorAiBackgroundTopDark = QColor();
const QColor colorAiBackgroundTopHoverLight = QColor();
const QColor colorAiBackgroundTopHoverDark = QColor();

const QColor blackLight = QColor(QStringLiteral("#000000"));
const QColor blackDark = QColor(QStringLiteral("#000000"));
const QColor whiteLight = QColor(QStringLiteral("#ffffff"));
const QColor whiteDark = QColor(QStringLiteral("#ffffff"));

const QString aiGeneral0Light = QStringLiteral("linear-gradient(278deg, rgba(255,242,255) 0%, rgba(248,237,255) 30%, rgba(244,244,255) 60%, rgba(239,247,255) 100%)");
const QString aiGeneral0Dark = QStringLiteral("linear-gradient(278deg, rgba(9,44,100) 0%, rgba(39,29,108) 30%, rgba(58,23,112) 60%, rgba(80,18,101) 100%)");
const QString aiGeneral1Light = QStringLiteral("linear-gradient(278deg, rgba(255,218,254) 0%, rgba(242,218,255) 30%, rgba(223,224,255) 60%, rgba(213,235,255) 100%)");
const QString aiGeneral1Dark = QStringLiteral("linear-gradient(278deg, rgba(17,64,136) 0%, rgba(54,43,144) 30%, rgba(83,35,148) 60%, rgba(113,28,137) 100%)");
const QString aiGeneral2Light = QStringLiteral("linear-gradient(278deg, rgba(254,181,255) 0%, rgba(227,181,255) 30%, rgba(193,192,255) 60%, rgba(171,213,255) 100%)");
const QString aiGeneral2Dark = QStringLiteral("linear-gradient(278deg, rgba(26,86,172) 0%, rgba(70,59,180) 30%, rgba(111,49,184) 60%, rgba(148,41,173) 100%)");
const QString aiGeneral3Light = QStringLiteral("linear-gradient(278deg, rgba(249,143,255) 0%, rgba(209,145,255) 30%, rgba(163,160,255) 60%, rgba(130,190,255) 100%)");
const QString aiGeneral3Dark = QStringLiteral("linear-gradient(278deg, rgba(38,111,207) 0%, rgba(88,78,215) 30%, rgba(141,65,219) 60%, rgba(185,55,208) 100%)");
const QString aiGeneral4Light = QStringLiteral("linear-gradient(278deg, rgba(242,106,255) 0%, rgba(189,108,255) 30%, rgba(134,129,255) 60%, rgba(88,166,255) 100%)");
const QString aiGeneral4Dark = QStringLiteral("linear-gradient(278deg, rgba(35,127,240) 0%, rgba(94,84,248) 30%, rgba(167,68,255) 60%, rgba(219,56,241) 100%)");
const QString aiGeneral5Light = QStringLiteral("linear-gradient(278deg, rgba(233,69,255) 0%, rgba(166,71,255) 30%, rgba(107,97,255) 60%, rgba(46,140,255) 100%)");
const QString aiGeneral5Dark = QStringLiteral("linear-gradient(278deg, rgba(91,162,245) 0%, rgba(134,129,252) 30%, rgba(195,117,255) 60%, rgba(234,107,246) 100%)");
const QString aiGeneral6Light = QStringLiteral("linear-gradient(278deg, rgba(194,53,219) 0%, rgba(134,54,219) 30%, rgba(88,77,219) 60%, rgba(33,114,219) 100%)");
const QString aiGeneral6Dark = QStringLiteral("linear-gradient(278deg, rgba(131,187,248) 0%, rgba(163,160,253) 30%, rgba(213,152,255) 60%, rgba(243,143,248) 100%)");
const QString aiGeneral7Light = QStringLiteral("linear-gradient(278deg, rgba(157,39,184) 0%, rgba(105,40,184) 30%, rgba(71,59,184) 60%, rgba(22,89,184) 100%)");
const QString aiGeneral7Dark = QStringLiteral("linear-gradient(278deg, rgba(172,210,250) 0%, rgba(192,192,253) 30%, rgba(229,186,255) 60%, rgba(249,180,251) 100%)");
const QString aiGeneral8Light = QStringLiteral("linear-gradient(278deg, rgba(121,27,148) 0%, rgba(78,28,148) 30%, rgba(55,43,148) 60%, rgba(13,67,148) 100%)");
const QString aiGeneral8Dark = QStringLiteral("linear-gradient(278deg, rgba(213,233,253) 0%, rgba(223,223,254) 30%, rgba(243,221,255) 60%, rgba(253,217,252) 100%)");
const QString aiGeneral9Light = QStringLiteral("linear-gradient(278deg, rgba(88,17,112) 0%, rgba(54,18,112) 30%, rgba(40,29,112) 60%, rgba(7,47,112) 100%)");
const QString aiGeneral9Dark = QStringLiteral("linear-gradient(278deg, rgba(239,247,254) 0%, rgba(244,244,255) 30%, rgba(251,243,255) 60%, rgba(254,241,254) 100%)");

} // namespace

SemiThemeValues::SemiThemeValues(Mode mode, QObject *parent)
    : QObject(parent)
    , m_mode(mode)
{
    applyDefaults();
}

void SemiThemeValues::applyDefaults()
{
    if (m_mode == Dark) {
        m_amber = amberDark();
        m_blue = blueDark();
        m_cyan = cyanDark();
        m_green = greenDark();
        m_grey = greyDark();
        m_indigo = indigoDark();
        m_lightBlue = lightBlueDark();
        m_lightGreen = lightGreenDark();
        m_lime = limeDark();
        m_orange = orangeDark();
        m_pink = pinkDark();
        m_purple = purpleDark();
        m_red = redDark();
        m_teal = tealDark();
        m_violet = violetDark();
        m_yellow = yellowDark();
        m_aiPurple = aiPurpleDark();
        m_colorWhite = colorWhiteDark;
        m_colorBlack = colorBlackDark;
        m_colorPrimaryLightDefault = colorPrimaryLightDefaultDark;
        m_colorPrimaryLightHover = colorPrimaryLightHoverDark;
        m_colorPrimaryLightActive = colorPrimaryLightActiveDark;
        m_colorSecondaryLightDefault = colorSecondaryLightDefaultDark;
        m_colorSecondaryLightHover = colorSecondaryLightHoverDark;
        m_colorSecondaryLightActive = colorSecondaryLightActiveDark;
        m_colorTertiaryLightDefault = colorTertiaryLightDefaultDark;
        m_colorTertiaryLightHover = colorTertiaryLightHoverDark;
        m_colorTertiaryLightActive = colorTertiaryLightActiveDark;
        m_colorInfoLightDefault = colorInfoLightDefaultDark;
        m_colorInfoLightHover = colorInfoLightHoverDark;
        m_colorInfoLightActive = colorInfoLightActiveDark;
        m_colorSuccessLightDefault = colorSuccessLightDefaultDark;
        m_colorSuccessLightHover = colorSuccessLightHoverDark;
        m_colorSuccessLightActive = colorSuccessLightActiveDark;
        m_colorDangerLightDefault = colorDangerLightDefaultDark;
        m_colorDangerLightHover = colorDangerLightHoverDark;
        m_colorDangerLightActive = colorDangerLightActiveDark;
        m_colorWarningLightDefault = colorWarningLightDefaultDark;
        m_colorWarningLightHover = colorWarningLightHoverDark;
        m_colorWarningLightActive = colorWarningLightActiveDark;
        m_colorDisabledText = colorDisabledTextDark;
        m_colorDisabledFill = colorDisabledFillDark;
        m_colorShadow = colorShadowDark;
        m_colorBorder = colorBorderDark;
        m_colorNavBg = colorNavBgDark;
        m_colorOverlayBg = colorOverlayBgDark;
        m_colorFill0 = colorFill0Dark;
        m_colorFill1 = colorFill1Dark;
        m_colorFill2 = colorFill2Dark;
        m_colorBg0 = colorBg0Dark;
        m_colorBg1 = colorBg1Dark;
        m_colorBg2 = colorBg2Dark;
        m_colorBg3 = colorBg3Dark;
        m_colorBg4 = colorBg4Dark;
        m_colorText1 = colorText1Dark;
        m_colorText2 = colorText2Dark;
        m_colorText3 = colorText3Dark;
        m_colorHighlightBg = colorHighlightBgDark;
        m_colorHighlight = colorHighlightDark;
        m_colorData0 = colorData0Dark;
        m_colorData1 = colorData1Dark;
        m_colorData2 = colorData2Dark;
        m_colorData3 = colorData3Dark;
        m_colorData4 = colorData4Dark;
        m_colorData5 = colorData5Dark;
        m_colorData6 = colorData6Dark;
        m_colorData7 = colorData7Dark;
        m_colorData8 = colorData8Dark;
        m_colorData9 = colorData9Dark;
        m_colorData10 = colorData10Dark;
        m_colorData11 = colorData11Dark;
        m_colorData12 = colorData12Dark;
        m_colorData13 = colorData13Dark;
        m_colorData14 = colorData14Dark;
        m_colorData15 = colorData15Dark;
        m_colorData16 = colorData16Dark;
        m_colorData17 = colorData17Dark;
        m_colorData18 = colorData18Dark;
        m_colorData19 = colorData19Dark;
        m_colorAiGeneral = colorAiGeneralDark;
        m_colorAiGeneralHover = colorAiGeneralHoverDark;
        m_colorAiGeneralActive = colorAiGeneralActiveDark;
        m_colorAiGeneralDisabled = colorAiGeneralDisabledDark;
        m_colorAiBackgroundBottom = colorAiBackgroundBottomDark;
        m_colorAiBackgroundBottomHover = colorAiBackgroundBottomHoverDark;
        m_colorAiBackgroundBottomActive = colorAiBackgroundBottomActiveDark;
        m_colorAiBackgroundTop = colorAiBackgroundTopDark;
        m_colorAiBackgroundTopHover = colorAiBackgroundTopHoverDark;
        m_black = blackDark;
        m_white = whiteDark;
        m_aiGeneral0 = aiGeneral0Dark;
        m_aiGeneral1 = aiGeneral1Dark;
        m_aiGeneral2 = aiGeneral2Dark;
        m_aiGeneral3 = aiGeneral3Dark;
        m_aiGeneral4 = aiGeneral4Dark;
        m_aiGeneral5 = aiGeneral5Dark;
        m_aiGeneral6 = aiGeneral6Dark;
        m_aiGeneral7 = aiGeneral7Dark;
        m_aiGeneral8 = aiGeneral8Dark;
        m_aiGeneral9 = aiGeneral9Dark;
    } else {
        m_amber = amberLight();
        m_blue = blueLight();
        m_cyan = cyanLight();
        m_green = greenLight();
        m_grey = greyLight();
        m_indigo = indigoLight();
        m_lightBlue = lightBlueLight();
        m_lightGreen = lightGreenLight();
        m_lime = limeLight();
        m_orange = orangeLight();
        m_pink = pinkLight();
        m_purple = purpleLight();
        m_red = redLight();
        m_teal = tealLight();
        m_violet = violetLight();
        m_yellow = yellowLight();
        m_aiPurple = aiPurpleLight();
        m_colorWhite = colorWhiteLight;
        m_colorBlack = colorBlackLight;
        m_colorPrimaryLightDefault = colorPrimaryLightDefaultLight;
        m_colorPrimaryLightHover = colorPrimaryLightHoverLight;
        m_colorPrimaryLightActive = colorPrimaryLightActiveLight;
        m_colorSecondaryLightDefault = colorSecondaryLightDefaultLight;
        m_colorSecondaryLightHover = colorSecondaryLightHoverLight;
        m_colorSecondaryLightActive = colorSecondaryLightActiveLight;
        m_colorTertiaryLightDefault = colorTertiaryLightDefaultLight;
        m_colorTertiaryLightHover = colorTertiaryLightHoverLight;
        m_colorTertiaryLightActive = colorTertiaryLightActiveLight;
        m_colorInfoLightDefault = colorInfoLightDefaultLight;
        m_colorInfoLightHover = colorInfoLightHoverLight;
        m_colorInfoLightActive = colorInfoLightActiveLight;
        m_colorSuccessLightDefault = colorSuccessLightDefaultLight;
        m_colorSuccessLightHover = colorSuccessLightHoverLight;
        m_colorSuccessLightActive = colorSuccessLightActiveLight;
        m_colorDangerLightDefault = colorDangerLightDefaultLight;
        m_colorDangerLightHover = colorDangerLightHoverLight;
        m_colorDangerLightActive = colorDangerLightActiveLight;
        m_colorWarningLightDefault = colorWarningLightDefaultLight;
        m_colorWarningLightHover = colorWarningLightHoverLight;
        m_colorWarningLightActive = colorWarningLightActiveLight;
        m_colorDisabledText = colorDisabledTextLight;
        m_colorDisabledFill = colorDisabledFillLight;
        m_colorShadow = colorShadowLight;
        m_colorBorder = colorBorderLight;
        m_colorNavBg = colorNavBgLight;
        m_colorOverlayBg = colorOverlayBgLight;
        m_colorFill0 = colorFill0Light;
        m_colorFill1 = colorFill1Light;
        m_colorFill2 = colorFill2Light;
        m_colorBg0 = colorBg0Light;
        m_colorBg1 = colorBg1Light;
        m_colorBg2 = colorBg2Light;
        m_colorBg3 = colorBg3Light;
        m_colorBg4 = colorBg4Light;
        m_colorText1 = colorText1Light;
        m_colorText2 = colorText2Light;
        m_colorText3 = colorText3Light;
        m_colorHighlightBg = colorHighlightBgLight;
        m_colorHighlight = colorHighlightLight;
        m_colorData0 = colorData0Light;
        m_colorData1 = colorData1Light;
        m_colorData2 = colorData2Light;
        m_colorData3 = colorData3Light;
        m_colorData4 = colorData4Light;
        m_colorData5 = colorData5Light;
        m_colorData6 = colorData6Light;
        m_colorData7 = colorData7Light;
        m_colorData8 = colorData8Light;
        m_colorData9 = colorData9Light;
        m_colorData10 = colorData10Light;
        m_colorData11 = colorData11Light;
        m_colorData12 = colorData12Light;
        m_colorData13 = colorData13Light;
        m_colorData14 = colorData14Light;
        m_colorData15 = colorData15Light;
        m_colorData16 = colorData16Light;
        m_colorData17 = colorData17Light;
        m_colorData18 = colorData18Light;
        m_colorData19 = colorData19Light;
        m_colorAiGeneral = colorAiGeneralLight;
        m_colorAiGeneralHover = colorAiGeneralHoverLight;
        m_colorAiGeneralActive = colorAiGeneralActiveLight;
        m_colorAiGeneralDisabled = colorAiGeneralDisabledLight;
        m_colorAiBackgroundBottom = colorAiBackgroundBottomLight;
        m_colorAiBackgroundBottomHover = colorAiBackgroundBottomHoverLight;
        m_colorAiBackgroundBottomActive = colorAiBackgroundBottomActiveLight;
        m_colorAiBackgroundTop = colorAiBackgroundTopLight;
        m_colorAiBackgroundTopHover = colorAiBackgroundTopHoverLight;
        m_black = blackLight;
        m_white = whiteLight;
        m_aiGeneral0 = aiGeneral0Light;
        m_aiGeneral1 = aiGeneral1Light;
        m_aiGeneral2 = aiGeneral2Light;
        m_aiGeneral3 = aiGeneral3Light;
        m_aiGeneral4 = aiGeneral4Light;
        m_aiGeneral5 = aiGeneral5Light;
        m_aiGeneral6 = aiGeneral6Light;
        m_aiGeneral7 = aiGeneral7Light;
        m_aiGeneral8 = aiGeneral8Light;
        m_aiGeneral9 = aiGeneral9Light;
    }
}

void SemiThemeValues::reset()
{
    m_colorPrimaryOverridden = false;
    m_colorPrimaryHoverOverridden = false;
    m_colorPrimaryActiveOverridden = false;
    m_colorPrimaryDisabledOverridden = false;
    m_colorSecondaryOverridden = false;
    m_colorSecondaryHoverOverridden = false;
    m_colorSecondaryActiveOverridden = false;
    m_colorSecondaryDisabledOverridden = false;
    m_colorTertiaryOverridden = false;
    m_colorTertiaryHoverOverridden = false;
    m_colorTertiaryActiveOverridden = false;
    m_colorDefaultOverridden = false;
    m_colorDefaultHoverOverridden = false;
    m_colorDefaultActiveOverridden = false;
    m_colorInfoOverridden = false;
    m_colorInfoHoverOverridden = false;
    m_colorInfoActiveOverridden = false;
    m_colorInfoDisabledOverridden = false;
    m_colorSuccessOverridden = false;
    m_colorSuccessHoverOverridden = false;
    m_colorSuccessActiveOverridden = false;
    m_colorSuccessDisabledOverridden = false;
    m_colorDangerOverridden = false;
    m_colorDangerHoverOverridden = false;
    m_colorDangerActiveOverridden = false;
    m_colorWarningOverridden = false;
    m_colorWarningHoverOverridden = false;
    m_colorWarningActiveOverridden = false;
    m_colorFocusBorderOverridden = false;
    m_colorDisabledBorderOverridden = false;
    m_colorDisabledBgOverridden = false;
    m_colorLinkOverridden = false;
    m_colorLinkHoverOverridden = false;
    m_colorLinkActiveOverridden = false;
    m_colorLinkVisitedOverridden = false;
    m_colorText0Overridden = false;
    m_colorAiPurpleOverridden = false;
    m_colorAiPurpleHoverOverridden = false;
    m_colorAiPurpleActiveOverridden = false;
    m_colorAiPurpleDisabledOverridden = false;
    m_shadowElevated = QStringLiteral("0 0 1px rgba(0, 0, 0, .3), 0 4px 14px rgba(0, 0, 0, .1)");
    m_radiusExtraSmall = 3;
    m_radiusSmall = 3;
    m_radiusMedium = 6;
    m_radiusLarge = 12;
    m_radiusCircle = 0;
    m_radiusFull = 9999;
    m_durationSlowest = 0;
    m_durationSlower = 0;
    m_durationSlow = 0;
    m_durationNormal = 0;
    m_durationFast = 0;
    m_durationFaster = 0;
    m_durationFastest = 0;
    m_durationNone = 0;
    m_easingLinear = QStringLiteral("linear");
    m_easingEase = QStringLiteral("ease");
    m_easingEaseIn = QStringLiteral("ease-in");
    m_easingEaseOut = QStringLiteral("ease-out");
    m_easingEaseInIOut = QStringLiteral("ease-in-out");
    m_delayNone = 0;
    m_delaySlowest = 0;
    m_delaySlower = 0;
    m_delaySlow = 0;
    m_delayNormal = 0;
    m_delayFast = 0;
    m_delayFaster = 0;
    m_delayFastest = 0;
    m_scaleNone = 1.0;
    m_scaleSmall = 1.0;
    m_scaleMedium = 1.0;
    m_scaleLarge = 1.0;
    m_rotateNone = 0;
    m_rotateClockwise90deg = 0;
    m_rotateClockwise180deg = 0;
    m_rotateClockwise270deg = 0;
    m_rotateClockwise360deg = 0;
    m_rotateAnticlockwise90deg = 0;
    m_rotateAnticlockwise180deg = 0;
    m_rotateAnticlockwise270deg = 0;
    m_rotateAnticlockwise360deg = 0;
    m_heightControlSmall = 24;
    m_heightControlDefault = 32;
    m_heightControlLarge = 40;
    m_borderThickness = 0;
    m_borderThicknessControl = 1;
    m_borderThicknessControlFocus = 1;
    m_widthIconExtraSmall = 8;
    m_widthIconSmall = 12;
    m_widthIconMedium = 16;
    m_widthIconLarge = 20;
    m_widthIconExtraLarge = 24;
    m_spacingNone = 0;
    m_spacingSuperTight = 2;
    m_spacingExtraTight = 4;
    m_spacingTight = 8;
    m_spacingBaseTight = 12;
    m_spacingBase = 16;
    m_spacingBaseLoose = 20;
    m_spacingLoose = 24;
    m_spacingExtraLoose = 32;
    m_spacingSuperLoose = 40;
    m_zPortal = 1;
    m_zAffix = 10;
    m_zBacktop = 10;
    m_zBadge = 10;
    m_zTableFixed = 101;
    m_zModal = 1000;
    m_zModalMask = 1000;
    m_zToast = 1010;
    m_zNotification = 1010;
    m_zPopover = 1030;
    m_zDropdown = 1050;
    m_zTooltip = 1060;
    m_zImagePreview = 1070;
    m_zImagePreviewHeader = 1;
    m_zTransferRightItemDragItemMove = 2000;
    m_zTagInputDragItemMove = 2000;
    m_zResizableHandler = 10;
    m_fontSizeSmall = 12;
    m_fontSizeRegular = 14;
    m_fontSizeHeader6 = 16;
    m_fontSizeHeader5 = 18;
    m_fontSizeHeader4 = 20;
    m_fontSizeHeader3 = 24;
    m_fontSizeHeader2 = 28;
    m_fontSizeHeader1 = 32;
    m_fontWeightLight = 200;
    m_fontWeightRegular = 400;
    m_fontWeightBold = 600;
    applyDefaults();
    Q_EMIT changed();
}

void SemiThemeValues::setAmber(const QList<QColor> &v)
{
    if (m_amber == v)
        return;
    m_amber = v;
    Q_EMIT changed();
}

void SemiThemeValues::setBlue(const QList<QColor> &v)
{
    if (m_blue == v)
        return;
    m_blue = v;
    Q_EMIT changed();
}

void SemiThemeValues::setCyan(const QList<QColor> &v)
{
    if (m_cyan == v)
        return;
    m_cyan = v;
    Q_EMIT changed();
}

void SemiThemeValues::setGreen(const QList<QColor> &v)
{
    if (m_green == v)
        return;
    m_green = v;
    Q_EMIT changed();
}

void SemiThemeValues::setGrey(const QList<QColor> &v)
{
    if (m_grey == v)
        return;
    m_grey = v;
    Q_EMIT changed();
}

void SemiThemeValues::setIndigo(const QList<QColor> &v)
{
    if (m_indigo == v)
        return;
    m_indigo = v;
    Q_EMIT changed();
}

void SemiThemeValues::setLightBlue(const QList<QColor> &v)
{
    if (m_lightBlue == v)
        return;
    m_lightBlue = v;
    Q_EMIT changed();
}

void SemiThemeValues::setLightGreen(const QList<QColor> &v)
{
    if (m_lightGreen == v)
        return;
    m_lightGreen = v;
    Q_EMIT changed();
}

void SemiThemeValues::setLime(const QList<QColor> &v)
{
    if (m_lime == v)
        return;
    m_lime = v;
    Q_EMIT changed();
}

void SemiThemeValues::setOrange(const QList<QColor> &v)
{
    if (m_orange == v)
        return;
    m_orange = v;
    Q_EMIT changed();
}

void SemiThemeValues::setPink(const QList<QColor> &v)
{
    if (m_pink == v)
        return;
    m_pink = v;
    Q_EMIT changed();
}

void SemiThemeValues::setPurple(const QList<QColor> &v)
{
    if (m_purple == v)
        return;
    m_purple = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRed(const QList<QColor> &v)
{
    if (m_red == v)
        return;
    m_red = v;
    Q_EMIT changed();
}

void SemiThemeValues::setTeal(const QList<QColor> &v)
{
    if (m_teal == v)
        return;
    m_teal = v;
    Q_EMIT changed();
}

void SemiThemeValues::setViolet(const QList<QColor> &v)
{
    if (m_violet == v)
        return;
    m_violet = v;
    Q_EMIT changed();
}

void SemiThemeValues::setYellow(const QList<QColor> &v)
{
    if (m_yellow == v)
        return;
    m_yellow = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiPurple(const QList<QColor> &v)
{
    if (m_aiPurple == v)
        return;
    m_aiPurple = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorWhite(const QColor &v)
{
    if (m_colorWhite == v)
        return;
    m_colorWhite = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorBlack(const QColor &v)
{
    if (m_colorBlack == v)
        return;
    m_colorBlack = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorPrimary(const QColor &v)
{
    if (m_colorPrimaryOverridden && m_colorPrimary == v)
        return;
    m_colorPrimary = v;
    m_colorPrimaryOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorPrimaryHover(const QColor &v)
{
    if (m_colorPrimaryHoverOverridden && m_colorPrimaryHover == v)
        return;
    m_colorPrimaryHover = v;
    m_colorPrimaryHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorPrimaryActive(const QColor &v)
{
    if (m_colorPrimaryActiveOverridden && m_colorPrimaryActive == v)
        return;
    m_colorPrimaryActive = v;
    m_colorPrimaryActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorPrimaryDisabled(const QColor &v)
{
    if (m_colorPrimaryDisabledOverridden && m_colorPrimaryDisabled == v)
        return;
    m_colorPrimaryDisabled = v;
    m_colorPrimaryDisabledOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorPrimaryLightDefault(const QColor &v)
{
    if (m_colorPrimaryLightDefault == v)
        return;
    m_colorPrimaryLightDefault = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorPrimaryLightHover(const QColor &v)
{
    if (m_colorPrimaryLightHover == v)
        return;
    m_colorPrimaryLightHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorPrimaryLightActive(const QColor &v)
{
    if (m_colorPrimaryLightActive == v)
        return;
    m_colorPrimaryLightActive = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSecondary(const QColor &v)
{
    if (m_colorSecondaryOverridden && m_colorSecondary == v)
        return;
    m_colorSecondary = v;
    m_colorSecondaryOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSecondaryHover(const QColor &v)
{
    if (m_colorSecondaryHoverOverridden && m_colorSecondaryHover == v)
        return;
    m_colorSecondaryHover = v;
    m_colorSecondaryHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSecondaryActive(const QColor &v)
{
    if (m_colorSecondaryActiveOverridden && m_colorSecondaryActive == v)
        return;
    m_colorSecondaryActive = v;
    m_colorSecondaryActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSecondaryDisabled(const QColor &v)
{
    if (m_colorSecondaryDisabledOverridden && m_colorSecondaryDisabled == v)
        return;
    m_colorSecondaryDisabled = v;
    m_colorSecondaryDisabledOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSecondaryLightDefault(const QColor &v)
{
    if (m_colorSecondaryLightDefault == v)
        return;
    m_colorSecondaryLightDefault = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSecondaryLightHover(const QColor &v)
{
    if (m_colorSecondaryLightHover == v)
        return;
    m_colorSecondaryLightHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSecondaryLightActive(const QColor &v)
{
    if (m_colorSecondaryLightActive == v)
        return;
    m_colorSecondaryLightActive = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorTertiary(const QColor &v)
{
    if (m_colorTertiaryOverridden && m_colorTertiary == v)
        return;
    m_colorTertiary = v;
    m_colorTertiaryOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorTertiaryHover(const QColor &v)
{
    if (m_colorTertiaryHoverOverridden && m_colorTertiaryHover == v)
        return;
    m_colorTertiaryHover = v;
    m_colorTertiaryHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorTertiaryActive(const QColor &v)
{
    if (m_colorTertiaryActiveOverridden && m_colorTertiaryActive == v)
        return;
    m_colorTertiaryActive = v;
    m_colorTertiaryActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorTertiaryLightDefault(const QColor &v)
{
    if (m_colorTertiaryLightDefault == v)
        return;
    m_colorTertiaryLightDefault = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorTertiaryLightHover(const QColor &v)
{
    if (m_colorTertiaryLightHover == v)
        return;
    m_colorTertiaryLightHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorTertiaryLightActive(const QColor &v)
{
    if (m_colorTertiaryLightActive == v)
        return;
    m_colorTertiaryLightActive = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDefault(const QColor &v)
{
    if (m_colorDefaultOverridden && m_colorDefault == v)
        return;
    m_colorDefault = v;
    m_colorDefaultOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDefaultHover(const QColor &v)
{
    if (m_colorDefaultHoverOverridden && m_colorDefaultHover == v)
        return;
    m_colorDefaultHover = v;
    m_colorDefaultHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDefaultActive(const QColor &v)
{
    if (m_colorDefaultActiveOverridden && m_colorDefaultActive == v)
        return;
    m_colorDefaultActive = v;
    m_colorDefaultActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorInfo(const QColor &v)
{
    if (m_colorInfoOverridden && m_colorInfo == v)
        return;
    m_colorInfo = v;
    m_colorInfoOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorInfoHover(const QColor &v)
{
    if (m_colorInfoHoverOverridden && m_colorInfoHover == v)
        return;
    m_colorInfoHover = v;
    m_colorInfoHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorInfoActive(const QColor &v)
{
    if (m_colorInfoActiveOverridden && m_colorInfoActive == v)
        return;
    m_colorInfoActive = v;
    m_colorInfoActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorInfoDisabled(const QColor &v)
{
    if (m_colorInfoDisabledOverridden && m_colorInfoDisabled == v)
        return;
    m_colorInfoDisabled = v;
    m_colorInfoDisabledOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorInfoLightDefault(const QColor &v)
{
    if (m_colorInfoLightDefault == v)
        return;
    m_colorInfoLightDefault = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorInfoLightHover(const QColor &v)
{
    if (m_colorInfoLightHover == v)
        return;
    m_colorInfoLightHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorInfoLightActive(const QColor &v)
{
    if (m_colorInfoLightActive == v)
        return;
    m_colorInfoLightActive = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSuccess(const QColor &v)
{
    if (m_colorSuccessOverridden && m_colorSuccess == v)
        return;
    m_colorSuccess = v;
    m_colorSuccessOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSuccessHover(const QColor &v)
{
    if (m_colorSuccessHoverOverridden && m_colorSuccessHover == v)
        return;
    m_colorSuccessHover = v;
    m_colorSuccessHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSuccessActive(const QColor &v)
{
    if (m_colorSuccessActiveOverridden && m_colorSuccessActive == v)
        return;
    m_colorSuccessActive = v;
    m_colorSuccessActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSuccessDisabled(const QColor &v)
{
    if (m_colorSuccessDisabledOverridden && m_colorSuccessDisabled == v)
        return;
    m_colorSuccessDisabled = v;
    m_colorSuccessDisabledOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSuccessLightDefault(const QColor &v)
{
    if (m_colorSuccessLightDefault == v)
        return;
    m_colorSuccessLightDefault = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSuccessLightHover(const QColor &v)
{
    if (m_colorSuccessLightHover == v)
        return;
    m_colorSuccessLightHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorSuccessLightActive(const QColor &v)
{
    if (m_colorSuccessLightActive == v)
        return;
    m_colorSuccessLightActive = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDanger(const QColor &v)
{
    if (m_colorDangerOverridden && m_colorDanger == v)
        return;
    m_colorDanger = v;
    m_colorDangerOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDangerHover(const QColor &v)
{
    if (m_colorDangerHoverOverridden && m_colorDangerHover == v)
        return;
    m_colorDangerHover = v;
    m_colorDangerHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDangerActive(const QColor &v)
{
    if (m_colorDangerActiveOverridden && m_colorDangerActive == v)
        return;
    m_colorDangerActive = v;
    m_colorDangerActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDangerLightDefault(const QColor &v)
{
    if (m_colorDangerLightDefault == v)
        return;
    m_colorDangerLightDefault = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDangerLightHover(const QColor &v)
{
    if (m_colorDangerLightHover == v)
        return;
    m_colorDangerLightHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDangerLightActive(const QColor &v)
{
    if (m_colorDangerLightActive == v)
        return;
    m_colorDangerLightActive = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorWarning(const QColor &v)
{
    if (m_colorWarningOverridden && m_colorWarning == v)
        return;
    m_colorWarning = v;
    m_colorWarningOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorWarningHover(const QColor &v)
{
    if (m_colorWarningHoverOverridden && m_colorWarningHover == v)
        return;
    m_colorWarningHover = v;
    m_colorWarningHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorWarningActive(const QColor &v)
{
    if (m_colorWarningActiveOverridden && m_colorWarningActive == v)
        return;
    m_colorWarningActive = v;
    m_colorWarningActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorWarningLightDefault(const QColor &v)
{
    if (m_colorWarningLightDefault == v)
        return;
    m_colorWarningLightDefault = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorWarningLightHover(const QColor &v)
{
    if (m_colorWarningLightHover == v)
        return;
    m_colorWarningLightHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorWarningLightActive(const QColor &v)
{
    if (m_colorWarningLightActive == v)
        return;
    m_colorWarningLightActive = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorFocusBorder(const QColor &v)
{
    if (m_colorFocusBorderOverridden && m_colorFocusBorder == v)
        return;
    m_colorFocusBorder = v;
    m_colorFocusBorderOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDisabledText(const QColor &v)
{
    if (m_colorDisabledText == v)
        return;
    m_colorDisabledText = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDisabledBorder(const QColor &v)
{
    if (m_colorDisabledBorderOverridden && m_colorDisabledBorder == v)
        return;
    m_colorDisabledBorder = v;
    m_colorDisabledBorderOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDisabledBg(const QColor &v)
{
    if (m_colorDisabledBgOverridden && m_colorDisabledBg == v)
        return;
    m_colorDisabledBg = v;
    m_colorDisabledBgOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorDisabledFill(const QColor &v)
{
    if (m_colorDisabledFill == v)
        return;
    m_colorDisabledFill = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorShadow(const QColor &v)
{
    if (m_colorShadow == v)
        return;
    m_colorShadow = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorLink(const QColor &v)
{
    if (m_colorLinkOverridden && m_colorLink == v)
        return;
    m_colorLink = v;
    m_colorLinkOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorLinkHover(const QColor &v)
{
    if (m_colorLinkHoverOverridden && m_colorLinkHover == v)
        return;
    m_colorLinkHover = v;
    m_colorLinkHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorLinkActive(const QColor &v)
{
    if (m_colorLinkActiveOverridden && m_colorLinkActive == v)
        return;
    m_colorLinkActive = v;
    m_colorLinkActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorLinkVisited(const QColor &v)
{
    if (m_colorLinkVisitedOverridden && m_colorLinkVisited == v)
        return;
    m_colorLinkVisited = v;
    m_colorLinkVisitedOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorBorder(const QColor &v)
{
    if (m_colorBorder == v)
        return;
    m_colorBorder = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorNavBg(const QColor &v)
{
    if (m_colorNavBg == v)
        return;
    m_colorNavBg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorOverlayBg(const QColor &v)
{
    if (m_colorOverlayBg == v)
        return;
    m_colorOverlayBg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorFill0(const QColor &v)
{
    if (m_colorFill0 == v)
        return;
    m_colorFill0 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorFill1(const QColor &v)
{
    if (m_colorFill1 == v)
        return;
    m_colorFill1 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorFill2(const QColor &v)
{
    if (m_colorFill2 == v)
        return;
    m_colorFill2 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorBg0(const QColor &v)
{
    if (m_colorBg0 == v)
        return;
    m_colorBg0 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorBg1(const QColor &v)
{
    if (m_colorBg1 == v)
        return;
    m_colorBg1 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorBg2(const QColor &v)
{
    if (m_colorBg2 == v)
        return;
    m_colorBg2 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorBg3(const QColor &v)
{
    if (m_colorBg3 == v)
        return;
    m_colorBg3 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorBg4(const QColor &v)
{
    if (m_colorBg4 == v)
        return;
    m_colorBg4 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorText0(const QColor &v)
{
    if (m_colorText0Overridden && m_colorText0 == v)
        return;
    m_colorText0 = v;
    m_colorText0Overridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorText1(const QColor &v)
{
    if (m_colorText1 == v)
        return;
    m_colorText1 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorText2(const QColor &v)
{
    if (m_colorText2 == v)
        return;
    m_colorText2 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorText3(const QColor &v)
{
    if (m_colorText3 == v)
        return;
    m_colorText3 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorHighlightBg(const QColor &v)
{
    if (m_colorHighlightBg == v)
        return;
    m_colorHighlightBg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorHighlight(const QColor &v)
{
    if (m_colorHighlight == v)
        return;
    m_colorHighlight = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData0(const QColor &v)
{
    if (m_colorData0 == v)
        return;
    m_colorData0 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData1(const QColor &v)
{
    if (m_colorData1 == v)
        return;
    m_colorData1 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData2(const QColor &v)
{
    if (m_colorData2 == v)
        return;
    m_colorData2 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData3(const QColor &v)
{
    if (m_colorData3 == v)
        return;
    m_colorData3 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData4(const QColor &v)
{
    if (m_colorData4 == v)
        return;
    m_colorData4 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData5(const QColor &v)
{
    if (m_colorData5 == v)
        return;
    m_colorData5 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData6(const QColor &v)
{
    if (m_colorData6 == v)
        return;
    m_colorData6 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData7(const QColor &v)
{
    if (m_colorData7 == v)
        return;
    m_colorData7 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData8(const QColor &v)
{
    if (m_colorData8 == v)
        return;
    m_colorData8 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData9(const QColor &v)
{
    if (m_colorData9 == v)
        return;
    m_colorData9 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData10(const QColor &v)
{
    if (m_colorData10 == v)
        return;
    m_colorData10 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData11(const QColor &v)
{
    if (m_colorData11 == v)
        return;
    m_colorData11 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData12(const QColor &v)
{
    if (m_colorData12 == v)
        return;
    m_colorData12 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData13(const QColor &v)
{
    if (m_colorData13 == v)
        return;
    m_colorData13 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData14(const QColor &v)
{
    if (m_colorData14 == v)
        return;
    m_colorData14 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData15(const QColor &v)
{
    if (m_colorData15 == v)
        return;
    m_colorData15 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData16(const QColor &v)
{
    if (m_colorData16 == v)
        return;
    m_colorData16 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData17(const QColor &v)
{
    if (m_colorData17 == v)
        return;
    m_colorData17 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData18(const QColor &v)
{
    if (m_colorData18 == v)
        return;
    m_colorData18 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorData19(const QColor &v)
{
    if (m_colorData19 == v)
        return;
    m_colorData19 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiGeneral(const QColor &v)
{
    if (m_colorAiGeneral == v)
        return;
    m_colorAiGeneral = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiGeneralHover(const QColor &v)
{
    if (m_colorAiGeneralHover == v)
        return;
    m_colorAiGeneralHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiGeneralActive(const QColor &v)
{
    if (m_colorAiGeneralActive == v)
        return;
    m_colorAiGeneralActive = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiGeneralDisabled(const QColor &v)
{
    if (m_colorAiGeneralDisabled == v)
        return;
    m_colorAiGeneralDisabled = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiPurple(const QColor &v)
{
    if (m_colorAiPurpleOverridden && m_colorAiPurple == v)
        return;
    m_colorAiPurple = v;
    m_colorAiPurpleOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiPurpleHover(const QColor &v)
{
    if (m_colorAiPurpleHoverOverridden && m_colorAiPurpleHover == v)
        return;
    m_colorAiPurpleHover = v;
    m_colorAiPurpleHoverOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiPurpleActive(const QColor &v)
{
    if (m_colorAiPurpleActiveOverridden && m_colorAiPurpleActive == v)
        return;
    m_colorAiPurpleActive = v;
    m_colorAiPurpleActiveOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiPurpleDisabled(const QColor &v)
{
    if (m_colorAiPurpleDisabledOverridden && m_colorAiPurpleDisabled == v)
        return;
    m_colorAiPurpleDisabled = v;
    m_colorAiPurpleDisabledOverridden = true;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiBackgroundBottom(const QColor &v)
{
    if (m_colorAiBackgroundBottom == v)
        return;
    m_colorAiBackgroundBottom = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiBackgroundBottomHover(const QColor &v)
{
    if (m_colorAiBackgroundBottomHover == v)
        return;
    m_colorAiBackgroundBottomHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiBackgroundBottomActive(const QColor &v)
{
    if (m_colorAiBackgroundBottomActive == v)
        return;
    m_colorAiBackgroundBottomActive = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiBackgroundTop(const QColor &v)
{
    if (m_colorAiBackgroundTop == v)
        return;
    m_colorAiBackgroundTop = v;
    Q_EMIT changed();
}

void SemiThemeValues::setColorAiBackgroundTopHover(const QColor &v)
{
    if (m_colorAiBackgroundTopHover == v)
        return;
    m_colorAiBackgroundTopHover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setShadowElevated(const QString &v)
{
    if (m_shadowElevated == v)
        return;
    m_shadowElevated = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRadiusExtraSmall(int v)
{
    if (m_radiusExtraSmall == v)
        return;
    m_radiusExtraSmall = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRadiusSmall(int v)
{
    if (m_radiusSmall == v)
        return;
    m_radiusSmall = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRadiusMedium(int v)
{
    if (m_radiusMedium == v)
        return;
    m_radiusMedium = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRadiusLarge(int v)
{
    if (m_radiusLarge == v)
        return;
    m_radiusLarge = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRadiusCircle(int v)
{
    if (m_radiusCircle == v)
        return;
    m_radiusCircle = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRadiusFull(int v)
{
    if (m_radiusFull == v)
        return;
    m_radiusFull = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDurationSlowest(int v)
{
    if (m_durationSlowest == v)
        return;
    m_durationSlowest = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDurationSlower(int v)
{
    if (m_durationSlower == v)
        return;
    m_durationSlower = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDurationSlow(int v)
{
    if (m_durationSlow == v)
        return;
    m_durationSlow = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDurationNormal(int v)
{
    if (m_durationNormal == v)
        return;
    m_durationNormal = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDurationFast(int v)
{
    if (m_durationFast == v)
        return;
    m_durationFast = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDurationFaster(int v)
{
    if (m_durationFaster == v)
        return;
    m_durationFaster = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDurationFastest(int v)
{
    if (m_durationFastest == v)
        return;
    m_durationFastest = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDurationNone(int v)
{
    if (m_durationNone == v)
        return;
    m_durationNone = v;
    Q_EMIT changed();
}

void SemiThemeValues::setEasingLinear(const QString &v)
{
    if (m_easingLinear == v)
        return;
    m_easingLinear = v;
    Q_EMIT changed();
}

void SemiThemeValues::setEasingEase(const QString &v)
{
    if (m_easingEase == v)
        return;
    m_easingEase = v;
    Q_EMIT changed();
}

void SemiThemeValues::setEasingEaseIn(const QString &v)
{
    if (m_easingEaseIn == v)
        return;
    m_easingEaseIn = v;
    Q_EMIT changed();
}

void SemiThemeValues::setEasingEaseOut(const QString &v)
{
    if (m_easingEaseOut == v)
        return;
    m_easingEaseOut = v;
    Q_EMIT changed();
}

void SemiThemeValues::setEasingEaseInIOut(const QString &v)
{
    if (m_easingEaseInIOut == v)
        return;
    m_easingEaseInIOut = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDelayNone(int v)
{
    if (m_delayNone == v)
        return;
    m_delayNone = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDelaySlowest(int v)
{
    if (m_delaySlowest == v)
        return;
    m_delaySlowest = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDelaySlower(int v)
{
    if (m_delaySlower == v)
        return;
    m_delaySlower = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDelaySlow(int v)
{
    if (m_delaySlow == v)
        return;
    m_delaySlow = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDelayNormal(int v)
{
    if (m_delayNormal == v)
        return;
    m_delayNormal = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDelayFast(int v)
{
    if (m_delayFast == v)
        return;
    m_delayFast = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDelayFaster(int v)
{
    if (m_delayFaster == v)
        return;
    m_delayFaster = v;
    Q_EMIT changed();
}

void SemiThemeValues::setDelayFastest(int v)
{
    if (m_delayFastest == v)
        return;
    m_delayFastest = v;
    Q_EMIT changed();
}

void SemiThemeValues::setScaleNone(qreal v)
{
    if (m_scaleNone == v)
        return;
    m_scaleNone = v;
    Q_EMIT changed();
}

void SemiThemeValues::setScaleSmall(qreal v)
{
    if (m_scaleSmall == v)
        return;
    m_scaleSmall = v;
    Q_EMIT changed();
}

void SemiThemeValues::setScaleMedium(qreal v)
{
    if (m_scaleMedium == v)
        return;
    m_scaleMedium = v;
    Q_EMIT changed();
}

void SemiThemeValues::setScaleLarge(qreal v)
{
    if (m_scaleLarge == v)
        return;
    m_scaleLarge = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRotateNone(int v)
{
    if (m_rotateNone == v)
        return;
    m_rotateNone = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRotateClockwise90deg(int v)
{
    if (m_rotateClockwise90deg == v)
        return;
    m_rotateClockwise90deg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRotateClockwise180deg(int v)
{
    if (m_rotateClockwise180deg == v)
        return;
    m_rotateClockwise180deg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRotateClockwise270deg(int v)
{
    if (m_rotateClockwise270deg == v)
        return;
    m_rotateClockwise270deg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRotateClockwise360deg(int v)
{
    if (m_rotateClockwise360deg == v)
        return;
    m_rotateClockwise360deg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRotateAnticlockwise90deg(int v)
{
    if (m_rotateAnticlockwise90deg == v)
        return;
    m_rotateAnticlockwise90deg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRotateAnticlockwise180deg(int v)
{
    if (m_rotateAnticlockwise180deg == v)
        return;
    m_rotateAnticlockwise180deg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRotateAnticlockwise270deg(int v)
{
    if (m_rotateAnticlockwise270deg == v)
        return;
    m_rotateAnticlockwise270deg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setRotateAnticlockwise360deg(int v)
{
    if (m_rotateAnticlockwise360deg == v)
        return;
    m_rotateAnticlockwise360deg = v;
    Q_EMIT changed();
}

void SemiThemeValues::setHeightControlSmall(int v)
{
    if (m_heightControlSmall == v)
        return;
    m_heightControlSmall = v;
    Q_EMIT changed();
}

void SemiThemeValues::setHeightControlDefault(int v)
{
    if (m_heightControlDefault == v)
        return;
    m_heightControlDefault = v;
    Q_EMIT changed();
}

void SemiThemeValues::setHeightControlLarge(int v)
{
    if (m_heightControlLarge == v)
        return;
    m_heightControlLarge = v;
    Q_EMIT changed();
}

void SemiThemeValues::setBorderThickness(int v)
{
    if (m_borderThickness == v)
        return;
    m_borderThickness = v;
    Q_EMIT changed();
}

void SemiThemeValues::setBorderThicknessControl(int v)
{
    if (m_borderThicknessControl == v)
        return;
    m_borderThicknessControl = v;
    Q_EMIT changed();
}

void SemiThemeValues::setBorderThicknessControlFocus(int v)
{
    if (m_borderThicknessControlFocus == v)
        return;
    m_borderThicknessControlFocus = v;
    Q_EMIT changed();
}

void SemiThemeValues::setWidthIconExtraSmall(int v)
{
    if (m_widthIconExtraSmall == v)
        return;
    m_widthIconExtraSmall = v;
    Q_EMIT changed();
}

void SemiThemeValues::setWidthIconSmall(int v)
{
    if (m_widthIconSmall == v)
        return;
    m_widthIconSmall = v;
    Q_EMIT changed();
}

void SemiThemeValues::setWidthIconMedium(int v)
{
    if (m_widthIconMedium == v)
        return;
    m_widthIconMedium = v;
    Q_EMIT changed();
}

void SemiThemeValues::setWidthIconLarge(int v)
{
    if (m_widthIconLarge == v)
        return;
    m_widthIconLarge = v;
    Q_EMIT changed();
}

void SemiThemeValues::setWidthIconExtraLarge(int v)
{
    if (m_widthIconExtraLarge == v)
        return;
    m_widthIconExtraLarge = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingNone(int v)
{
    if (m_spacingNone == v)
        return;
    m_spacingNone = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingSuperTight(int v)
{
    if (m_spacingSuperTight == v)
        return;
    m_spacingSuperTight = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingExtraTight(int v)
{
    if (m_spacingExtraTight == v)
        return;
    m_spacingExtraTight = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingTight(int v)
{
    if (m_spacingTight == v)
        return;
    m_spacingTight = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingBaseTight(int v)
{
    if (m_spacingBaseTight == v)
        return;
    m_spacingBaseTight = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingBase(int v)
{
    if (m_spacingBase == v)
        return;
    m_spacingBase = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingBaseLoose(int v)
{
    if (m_spacingBaseLoose == v)
        return;
    m_spacingBaseLoose = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingLoose(int v)
{
    if (m_spacingLoose == v)
        return;
    m_spacingLoose = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingExtraLoose(int v)
{
    if (m_spacingExtraLoose == v)
        return;
    m_spacingExtraLoose = v;
    Q_EMIT changed();
}

void SemiThemeValues::setSpacingSuperLoose(int v)
{
    if (m_spacingSuperLoose == v)
        return;
    m_spacingSuperLoose = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZPortal(int v)
{
    if (m_zPortal == v)
        return;
    m_zPortal = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZAffix(int v)
{
    if (m_zAffix == v)
        return;
    m_zAffix = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZBacktop(int v)
{
    if (m_zBacktop == v)
        return;
    m_zBacktop = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZBadge(int v)
{
    if (m_zBadge == v)
        return;
    m_zBadge = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZTableFixed(int v)
{
    if (m_zTableFixed == v)
        return;
    m_zTableFixed = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZModal(int v)
{
    if (m_zModal == v)
        return;
    m_zModal = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZModalMask(int v)
{
    if (m_zModalMask == v)
        return;
    m_zModalMask = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZToast(int v)
{
    if (m_zToast == v)
        return;
    m_zToast = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZNotification(int v)
{
    if (m_zNotification == v)
        return;
    m_zNotification = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZPopover(int v)
{
    if (m_zPopover == v)
        return;
    m_zPopover = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZDropdown(int v)
{
    if (m_zDropdown == v)
        return;
    m_zDropdown = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZTooltip(int v)
{
    if (m_zTooltip == v)
        return;
    m_zTooltip = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZImagePreview(int v)
{
    if (m_zImagePreview == v)
        return;
    m_zImagePreview = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZImagePreviewHeader(int v)
{
    if (m_zImagePreviewHeader == v)
        return;
    m_zImagePreviewHeader = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZTransferRightItemDragItemMove(int v)
{
    if (m_zTransferRightItemDragItemMove == v)
        return;
    m_zTransferRightItemDragItemMove = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZTagInputDragItemMove(int v)
{
    if (m_zTagInputDragItemMove == v)
        return;
    m_zTagInputDragItemMove = v;
    Q_EMIT changed();
}

void SemiThemeValues::setZResizableHandler(int v)
{
    if (m_zResizableHandler == v)
        return;
    m_zResizableHandler = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontSizeSmall(int v)
{
    if (m_fontSizeSmall == v)
        return;
    m_fontSizeSmall = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontSizeRegular(int v)
{
    if (m_fontSizeRegular == v)
        return;
    m_fontSizeRegular = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontSizeHeader6(int v)
{
    if (m_fontSizeHeader6 == v)
        return;
    m_fontSizeHeader6 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontSizeHeader5(int v)
{
    if (m_fontSizeHeader5 == v)
        return;
    m_fontSizeHeader5 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontSizeHeader4(int v)
{
    if (m_fontSizeHeader4 == v)
        return;
    m_fontSizeHeader4 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontSizeHeader3(int v)
{
    if (m_fontSizeHeader3 == v)
        return;
    m_fontSizeHeader3 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontSizeHeader2(int v)
{
    if (m_fontSizeHeader2 == v)
        return;
    m_fontSizeHeader2 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontSizeHeader1(int v)
{
    if (m_fontSizeHeader1 == v)
        return;
    m_fontSizeHeader1 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontWeightLight(int v)
{
    if (m_fontWeightLight == v)
        return;
    m_fontWeightLight = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontWeightRegular(int v)
{
    if (m_fontWeightRegular == v)
        return;
    m_fontWeightRegular = v;
    Q_EMIT changed();
}

void SemiThemeValues::setFontWeightBold(int v)
{
    if (m_fontWeightBold == v)
        return;
    m_fontWeightBold = v;
    Q_EMIT changed();
}

void SemiThemeValues::setBlack(const QColor &v)
{
    if (m_black == v)
        return;
    m_black = v;
    Q_EMIT changed();
}

void SemiThemeValues::setWhite(const QColor &v)
{
    if (m_white == v)
        return;
    m_white = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral0(const QString &v)
{
    if (m_aiGeneral0 == v)
        return;
    m_aiGeneral0 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral1(const QString &v)
{
    if (m_aiGeneral1 == v)
        return;
    m_aiGeneral1 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral2(const QString &v)
{
    if (m_aiGeneral2 == v)
        return;
    m_aiGeneral2 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral3(const QString &v)
{
    if (m_aiGeneral3 == v)
        return;
    m_aiGeneral3 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral4(const QString &v)
{
    if (m_aiGeneral4 == v)
        return;
    m_aiGeneral4 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral5(const QString &v)
{
    if (m_aiGeneral5 == v)
        return;
    m_aiGeneral5 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral6(const QString &v)
{
    if (m_aiGeneral6 == v)
        return;
    m_aiGeneral6 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral7(const QString &v)
{
    if (m_aiGeneral7 == v)
        return;
    m_aiGeneral7 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral8(const QString &v)
{
    if (m_aiGeneral8 == v)
        return;
    m_aiGeneral8 = v;
    Q_EMIT changed();
}

void SemiThemeValues::setAiGeneral9(const QString &v)
{
    if (m_aiGeneral9 == v)
        return;
    m_aiGeneral9 = v;
    Q_EMIT changed();
}

} // namespace semi
