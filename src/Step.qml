pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 步骤条里的一步。对应 `packages/semi-ui/steps/step.tsx`（按 context 的 type 分派 :19-35）
// 与它下面那三个实现 `basicStep.tsx` / `fillStep.tsx` / `navStep.tsx`，
// 样式在 `semi-foundation/steps/{bacisSteps.scss,fillSteps.scss,navSteps.scss}`
// —— 注意 basic 那份文件名上游就拼错成 `bacis`（steps.scss:7 也是拼错着 import 的）。
//
// 数值全部对着编译后的 `packages/semi-ui/dist/css/semi.css` 20437-20897 段。
//
// ---------------------------------------------------------------- 与官方的口径差异（逐条）
//   · 官方三档靠 `context.ts` 里那一枚 `{ type }` 分派，且 **`<Step/>` 落在 `<Steps/>` 外面
//     什么都不画**（context 默认值是 null）。端口用宿主注入的 `hostType` 表达同一件事：
//     没宿主 ⇒ 不画。
//   · 官方 `title` / `description` / `icon` 是 ReactNode ⇒ 端口收「字符串或 Component」两档。
//   · `className` / `style` 是 DOM 通道，不收。`prefixCls` 同理。
//     `role` / `aria-label` 收进来挂到 `Accessible` 上。
//   · 官方 `onClick` 收 React 事件对象、`onKeyDown` **只认 Enter**（basicStep.tsx:101-106）；
//     端口两条都无参。
//   · 官方 `stepNumber` / `status` / `active` / `done` / `size` / `index` / `total` / `onChange`
//     全部由宿主 `cloneElement` 注进来（用户写不动），端口是同方向的 `host*` 前缀属性。
//     其中一条上游行为照抄：容器的注入写在 `{...child.props}` **之后**，
//     所以 `status` 只有「用户没写」时才被覆盖（basicSteps.tsx:57 / fillSteps.tsx:44 的
//     `if (!child.props.status)`），而 `onChange` 是**无条件覆盖** —— 用户写在 Step 上的
//     onChange 会被宿主抹掉（basicSteps.tsx:68-72），端口因此根本不开这个属性。
Item {
    id: control

    // ---- 用户写的 ----
    property var title: ""
    property var description: ""
    property var icon: ""
    /// 不给就由宿主的 current 推（basicSteps.tsx:57-65）
    property string status: ""
    property string ariaLabel: ""
    property string role: ""

    // ---- 宿主注入（官方 cloneElement 那一份）----
    property var host: null
    readonly property bool isStep: true
    property bool fromRepeater: false
    property string hostType: ""              // fill | basic | nav
    property string hostSize: "default"
    property string hostDirection: "horizontal"
    property bool hostHasLine: true
    property int hostStepNumber: 0            // initial + index，参与状态判定
    property int hostDisplayNumber: 1         // 画出来的序号 = stepNumber + 1
    property int hostIndex: 0
    property int hostTotal: 0
    property string hostStatus: "wait"        // 推导或覆盖之后的最终状态
    property bool hostActive: false
    property bool hostDone: false
    property bool hostClickable: false        // 官方是「容器有 onChange 或本步有 onClick」推出来的

    /// 与容器那枚 `clickable` 成对：官方是「本格有 onClick」才让这一格可点
    property bool clickable: false

    signal clicked()
    signal enterPressed()

    readonly property bool vertical: control.hostDirection === "vertical"
    readonly property bool small: control.hostSize === "small"
    readonly property bool isLast: control.hostIndex === control.hostTotal - 1
    readonly property bool isFirst: control.hostIndex === 0
    readonly property bool isFinish: control.hostStatus === "finish"
    readonly property bool isError: control.hostStatus === "error"
    readonly property bool isWarning: control.hostStatus === "warning"
    readonly property bool isProcess: control.hostStatus === "process"
    readonly property bool isWait: control.hostStatus === "wait"

    // ---------------------------------------------------------------- 交互
    HoverHandler {
        id: hover

        objectName: "stepHover"

        enabled: control.hostClickable
    }
    readonly property bool hovered: hover.hovered
    TapHandler {
        id: tap

        objectName: "stepTap"

        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        enabled: control.hostClickable
        onTapped: control.clicked()
    }

    // ---------------------------------------------------------------- fill 档
    // CSS:20443-20578。一格就是一张 72 高的卡：**没有连接线**（fillSteps.scss:14-30 那条
    // ::after 被注释掉了，编译产物里根本没有），item 之间与**最后一格之后**都留 16px
    // （fillSteps.scss 里没有 :last-child 复位 ⇒ 那 16 是每格都带）。
    // 盒子是 border-box：`border:1px solid transparent` + `padding:12px 16px`（CSS:20444-20450）
    // ⇒ 内容区从 (17, 13) 起，右边界在 width-17。容器 `display:flex` 没写 align-items
    // （缺省 stretch），而 -left 自带 height:24 ⇒ 标记与文字块都是**顶对齐**，不是垂直居中。
    // 状态 glyph 恒 24px（fillStep.tsx:36,46,49 写死 extra-large），不跟 size。
    Item {
        id: fillBox

        objectName: "stepFillBox"

        visible: control.hostType === "fill"
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width
        height: 72
        clip: true                            // overflow: hidden

        Rectangle {
            objectName: "stepFillCard"

            anchors.fill: parent
            radius: 6                         // --semi-border-radius-medium
            // fillSteps.scss:39 给了 1px solid transparent，但**没有任何状态改过 border-color**
            // ⇒ 那 1px 只是把盒子撑大 2px，端口用 1px 同色描边复现尺寸、不复现「有边框」
            border.width: 1
            border.color: "transparent"
            color: {
                if (control.isProcess)
                    return Theme.current.colorPrimaryLightDefault;
                if (control.hostClickable && (control.isFinish || control.isError || control.isWarning))
                    return control.pressedColor;
                return "transparent";
            }
        }

        // 24×24 圆：wait 是 text-2 实心 + 白字、process 是 primary 实心 + 白字，
        // finish/error/warning 换成 24px 状态 glyph（无底）
        Rectangle {
            id: fillMarker

            objectName: "stepFillMarker"

            x: 17
            y: 13
            width: 24
            height: 24
            radius: 12
            visible: control.noOverrideIcon
            color: {
                if (control.isProcess)
                    return Theme.current.colorPrimary;
                if (control.isWait)
                    return Theme.current.colorText2;
                return "transparent";         // finish/error/warning 这一档画 glyph，不画底
            }

            Text {
                objectName: "stepFillNumber"

                anchors.centerIn: parent
                visible: control.isWait || control.isProcess
                text: String(control.hostDisplayNumber)
                color: Theme.current.colorWhite
                font.pixelSize: 20            // font-size-header-4
                font.weight: Font.DemiBold
            }

            Icon {
                objectName: "stepFillGlyph"

                anchors.centerIn: parent
                visible: control.isFinish || control.isError || control.isWarning
                name: control.isFinish ? "tick_circle"
                    : (control.isError ? "alert_circle" : "alert_triangle")
                size: 24                      // extra-large，写死
                color: control.fillStatusColor
            }
        }

        Loader {
            objectName: "stepFillIconHook"

            x: 17
            y: 13
            visible: active
            active: control.noOverrideIcon === false && control.iconIsComponent
            sourceComponent: control.iconIsComponent ? control.icon : null
            onLoaded: {
                if (item === null)
                    return;
                item.color = control.fillStatusColor;
            }
        }

        Icon {
            objectName: "stepFillIconName"

            x: 17
            y: 13
            visible: control.noOverrideIcon === false && control.stringIconName !== ""
            name: control.stringIconName
            size: 24                          // extra-large，与状态 glyph 同档
            color: control.fillStatusColor
        }

        Column {
            objectName: "stepFillContent"

            x: 17 + 24 + 16                   // 边框+内边距 + 标记 + -content{margin-left:16}
            y: 13
            width: Math.max(0, fillBox.width - (17 + 24 + 16) - 17)
            spacing: 0

            // CSS:20457-20462：18/24、600，默认 text-0；四档状态各改一次颜色
            //（process→primary、finish→**success**、error→danger、warning→warning，
            //  wait 不改标题、只把 -item-icon 染成 text-2）
            Text {
                objectName: "stepFillTitle"

                width: parent.width
                height: 24
                text: control.textOf(control.title)
                elide: Text.ElideRight
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: control.fillTitleColor
            }

            // fillStep.tsx:100-105 **无条件**渲染这一行 ⇒ 没描述也占 20px
            Text {
                objectName: "stepFillDescription"

                width: parent.width
                height: 20
                text: control.textOf(control.description)
                elide: Text.ElideRight
                font.pixelSize: Theme.current.fontSizeRegular
                color: Theme.current.colorText2
            }
        }
    }

    readonly property bool iconIsComponent: typeof control.icon === "object" && control.icon !== null
    /// 「字符串图标名」那一档（端口的写法，官方收的是 ReactNode）：名字直接喂 Semi 的 Icon
    readonly property string stringIconName: typeof control.icon === "string" ? control.icon : ""
    readonly property color fillStatusColor: control.isFinish ? Theme.current.colorSuccess
        : (control.isError ? Theme.current.colorDanger
            : (control.isWarning ? Theme.current.colorWarning : Theme.current.colorText2))
    /// fill 档标题跟着状态走：CSS:20482-20544 四档各一条，wait 那一档没有 ⇒ 落回 text-0
    readonly property color fillTitleColor: control.isProcess ? Theme.current.colorPrimary
        : (control.isFinish ? Theme.current.colorSuccess
            : (control.isError ? Theme.current.colorDanger
                : (control.isWarning ? Theme.current.colorWarning : Theme.current.colorText0)))
    readonly property color pressedColor: control.tapPressed ? Theme.current.colorFill1
        : (control.hovered ? Theme.current.colorFill0 : "transparent")
    readonly property bool tapPressed: tap.pressed
    /// basic 档的标记位：官方 basicStep.tsx:62-76 在 finish/error/warning 三档画 glyph
    /// 而不是数字徽标，所以那三条嵌套 `-number-icon` 的 CSS 永远命不中。
    /// 判据抄上游的 `'icon' in props`：只有「没写」与空串算没给，**显式给 null 算给了**
    /// （React 那边 `icon={null}` 会让 `inner ? <div> : null` 整个不成立 ⇒ 标记位连徽标一起没）。
    readonly property bool noOverrideIcon: control.icon === undefined || control.icon === ""
    readonly property color basicStatusColor: control.isFinish || control.isProcess
        ? Theme.current.colorPrimary
        : (control.isError ? Theme.current.colorDanger
            : (control.isWarning ? Theme.current.colorWarning : Theme.current.colorText2))
    // 悬浮色不再判 hostClickable：那枚 HoverHandler 自己就是 `enabled: hostClickable`，
    // 不可点的格子根本给不出 hovered ⇒ 这道判据是重复的
    readonly property color basicTitleColor: control.hovered
        ? Theme.current.colorFocusBorder
        : (control.isWait ? Theme.current.colorText2 : Theme.current.colorText0)

    function textOf(v) {
        if (v === undefined || v === null)
            return "";
        if (typeof v === "object")
            return "";
        return String(v);
    }

    // ---------------------------------------------------------------- basic 档
    // CSS:20580-20813。容器没有声明过高度（variables.scss:61 那 $height-steps_basic_item:72
    // 全仓没人引用）。标记与文字之间是 8px = $spacing-tight（不是 extra-tight 4）。
    // 连接线是**标题的 ::after**：从标题右边界起、宽 9999px、被 item 的 overflow:hidden 裁掉
    // ⇒ 视觉上停在格子边界，与下一格的标记之间空着 16px 内边距，两头都不接。
    Item {
        id: basicBox

        objectName: "stepBasicBox"

        // 竖排：padding-top 9 是给「上一格伸下来的连接线」留的落点，第一格清掉（CSS:122-126）；
        // 竖排那一档压根没有 padding-left（:89-149 整段在 &-vertical 下，横向那 16 写在
        // &-horizontal 里，:19）⇒ 每一格的标记都贴左边界，只有首格没有左内边距的是横排。
        visible: control.hostType === "basic"
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width
        height: (control.vertical ? (control.isFirst ? 0 : 9) : 0)
            + Math.max(basicMarker.height + (control.vertical ? 9 : 0),
                basicContent.height + (control.vertical ? 22 : 0))
        clip: true

        // 竖排那根挂在 -icon 上：top:100%、left:50%、宽 1、高 9999，
        // 起点在 24 徽标下方 9px（-icon 的 padding-bottom:9 + content-box）
        Rectangle {
            objectName: "stepBasicVLine"

            visible: control.vertical && control.hostHasLine && !control.isLast
            x: basicMarker.x + basicMarker.width / 2 - 0.5
            y: basicMarker.y + basicMarker.height + 9      // -icon{padding-bottom:9}
            width: 1
            height: basicBox.height - y
            color: control.hostDone ? Theme.current.colorPrimary : Theme.current.colorFill2
        }

        Item {
            id: basicMarker

            objectName: "stepBasicMarker"

            // 横排只有首格清掉 16 的左内边距；竖排那一档从头到尾没有 padding-left（见 basicBox 注释）
            x: control.vertical || control.isFirst ? 0 : 16
            y: control.vertical ? 0 : (basicTitle.height - height) / 2
            width: control.small ? 20 : 24
            height: control.small ? 20 : 24

            Rectangle {
                id: basicBadge

                objectName: "stepBasicBadge"

                anchors.fill: parent
                radius: 12                    // border-radius: 50%
                visible: control.noOverrideIcon && (control.isWait || control.isProcess)
                color: control.isProcess ? Theme.current.colorPrimary : Theme.current.colorFill0
            }

            Text {
                objectName: "stepBasicNumber"

                anchors.centerIn: parent
                visible: control.noOverrideIcon && (control.isWait || control.isProcess)
                text: String(control.hostDisplayNumber)
                color: control.isProcess ? Theme.current.colorWhite : Theme.current.colorText2
                font.pixelSize: control.small ? 12 : 16
                font.weight: Font.DemiBold
            }

            Icon {
                objectName: "stepBasicGlyph"

                anchors.centerIn: parent
                visible: control.noOverrideIcon
                    && (control.isFinish || control.isError || control.isWarning)
                // basicStep.tsx:62-76：这三档画的是 glyph，**没有徽标底**
                // ⇒ CSS:20764/20790/20796 那三条嵌套 -number-icon 规则永远命不中
                name: control.isFinish ? "tick_circle"
                    : (control.isError ? "alert_circle" : "alert_triangle")
                size: control.small ? 20 : 24
                color: control.basicStatusColor
            }

            Loader {
                objectName: "stepBasicIconHook"

                anchors.centerIn: parent
                visible: active
                active: !control.noOverrideIcon && control.iconIsComponent
                sourceComponent: control.iconIsComponent ? control.icon : null
            }

            Icon {
                objectName: "stepBasicIconName"

                anchors.centerIn: parent
                visible: !control.noOverrideIcon && control.stringIconName !== ""
                name: control.stringIconName
                size: control.small ? 20 : 24
                color: control.basicStatusColor
            }
        }


        Item {
            id: basicContent

            objectName: "stepBasicContent"

            x: basicMarker.x + basicMarker.width + 8      // -left{margin-right:8}= $spacing-tight
            y: 0
            width: Math.max(0, basicBox.width - x)
            implicitHeight: basicTitle.height + (basicDesc.visible ? 4 + basicDesc.height : 0)
            height: control.vertical ? Math.max(control.small ? 40 : 42, implicitHeight)
                : implicitHeight

            Text {
                id: basicTitle

                objectName: "stepBasicTitle"

                // 横排 max-width:80%，但 :last-child 那一档改回 100% 且 padding-right:0
                // （CSS:20600-20608）；竖排整档都是 100%（CSS:20690）
                width: Math.min(implicitWidth,
                    (control.vertical || control.isLast) ? parent.width : parent.width * 0.8)
                height: control.small ? 20 : 24
                text: control.textOf(control.title)
                elide: Text.ElideRight
                font.pixelSize: control.small ? Theme.current.fontSizeRegular
                    : Theme.current.fontSizeHeader6
                font.weight: Font.DemiBold    // 三档状态都是 600，变的只有颜色
                color: control.basicTitleColor
            }

            // basicStep.tsx:120：只有真值才渲染（与 fill 的「无条件」相反）
            Text {
                id: basicDesc

                objectName: "stepBasicDescription"

                anchors.top: basicTitle.bottom
                anchors.topMargin: 4          // title 的 margin-bottom:4
                width: Math.min(implicitWidth, control.vertical ? parent.width
                    : Math.min(parent.width, 268))   // CSS:20622 那道 268 是横排独有的硬上限
                visible: control.textOf(control.description) !== ""
                text: control.textOf(control.description)
                elide: Text.ElideRight
                font.pixelSize: control.small ? Theme.current.fontSizeSmall
                    : Theme.current.fontSizeSmall
                color: Theme.current.colorText2
            }

        }

        // 横排的连接线：标题右边界（含 16 的 padding-right）起，裁到格子右边缘
        Rectangle {
            objectName: "stepBasicLine"

            visible: !control.vertical && control.hostHasLine && !control.isLast
            // 标题的 ::after 从「标题盒子右边界」起（含它自己那 16 的 padding-right），
            // 再被本格的 overflow:hidden 裁在格子边上
            x: basicContent.x + basicTitle.width + (control.isLast ? 0 : 16)
            y: basicTitle.y + basicTitle.height / 2
            width: Math.max(0, basicBox.width - x)
            height: 1
            color: control.hostDone ? Theme.current.colorPrimary : Theme.current.colorFill2
        }
    }

    // ---------------------------------------------------------------- nav 档
    // CSS:20815-20862。整条是 inline-flex 撑内容宽；格子**不是 flex:1**、不撑满。
    // **零 background、零 cursor、零 :hover、零 :active** —— nav 唯一的状态视觉就是
    // 标题的颜色与字重。分隔符不是 CSS 画的箭头，是 navStep.tsx:46-50 那枚
    // `<IconChevronRight size="small"/>` = 12px glyph，最后一格不给。
    // 槽位 CSS:20833-20839 写 `color: var(--semi-grey-3)` —— 调色板变量是裸三元组
    // （CSS:49 `167,171,176`），这条声明非法、被丢掉 ⇒ 实际继承的是 -container 的 text-2。
    Item {
        id: navBox

        objectName: "stepNavBox"

        anchors.left: parent.left
        anchors.top: parent.top
        visible: control.hostType === "nav"
        width: navTitle.width + (control.isLast ? 0 : 60)
        height: navTitle.height

        Text {
            id: navTitle

            objectName: "stepNavTitle"

            width: Math.min(implicitWidth, 272)   // max-width: 17em @16px
            text: control.textOf(control.title)
            elide: Text.ElideRight
            font.pixelSize: control.small ? Theme.current.fontSizeRegular
                : Theme.current.fontSizeHeader6
            font.weight: control.hostActive ? Font.DemiBold : Font.Normal
            color: control.hostActive ? Theme.current.colorText0 : Theme.current.colorText2
        }

        Icon {
            objectName: "stepNavChevron"

            visible: !control.isLast
            x: navTitle.width + (60 - 12) / 2     // 槽位 min-width:60 + justify-content:center
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: 12                              // size="small"
            color: Theme.current.colorText2       // 不是 grey-3，见上
        }
    }

    // ---------------------------------------------------------------- 尺寸分派
    // 容器要靠这个数算「basic 横排最后一格吃内容宽」，所以三档都得给真值
    implicitWidth: control.hostType === "nav" ? navBox.width
        : (control.hostType === "fill" ? fillBox.width
            : basicMarker.x + basicMarker.width + 8 + Math.max(basicTitle.implicitWidth,
                basicDesc.implicitWidth) + (control.isLast ? 0 : 16))
    implicitHeight: control.hostType === "fill" ? 72
        : (control.hostType === "basic" ? basicBox.height : navBox.height)
    visible: control.hostType === "fill" || control.hostType === "basic"
        || control.hostType === "nav"

    Accessible.role: control.role === "listitem" ? Accessible.ListItem : Accessible.Grouping
    Accessible.name: control.textOf(control.title)
}
