import QtQuick

// 空状态。官方 packages/semi-ui/empty/index.tsx 的 EmptyProps 整份照抄：
// 一块占位图 + 标题 + 描述 + 一个操作区（声明式子项）。
//
//     Empty {
//         image: "qrc:/…/construction.svg"
//         darkModeImage: "qrc:/…/construction-dark.svg"
//         title: "功能建设中"
//         description: "当前功能暂未开放，敬请期待。"
//     }
//     Empty {
//         title: "还没有数据"
//         description: "先建一个吧"
//         Button { text: "新建" }          // 官方 children ⇒ .semi-empty-footer
//     }
//
// ------------------------------------------------------------------ 官方 EmptyProps
// 逐条对着 packages/semi-ui/empty/index.tsx:17-27 与 :35-37 的 defaultProps：
//   · 唯一的缺省是 `layout: "vertical"`。**`image` / `title` / `description` 都没有缺省**，
//     旧端口那条 `description: "暂无数据"` 是自造的，已撤。
//   · `image` 三形（:84-97）：字符串 ⇒ `<img alt src>`；对象且带 `id` ⇒ `<svg><use xlink:href="#id">`
//     （SVG sprite 的 symbol 引用，Qt 侧没有对应物 ⇒ **收了不画**，钉用例）；其余按节点渲染。
//     注意字符串档**不看真值** —— `image: ""` 在官方也算「有图」（`typeof '' === 'string'` 先命中），
//     于是标题走 heading 4 那一档。端口照抄这个判定。
//   · `darkModeImage` 官方是挂 MutationObserver 盯 `document.body` 的 `theme-mode` 属性
//     （:49-76），端口直接跟 `Theme.mode` —— 同一语义的本地实现，不是偏离。取哪一份走官方的
//     真值档（:82）：暗色且给了 darkModeImage 才换，所以暗色下没给就退回 `image`。
//   · `title` / `description` 都是「字符串或节点」（官方 ReactNode）。三块都按真值判断
//     （:116-130）：空串算没给，整块不渲染。
//   · `style` 是外层 div 的样式、`imageStyle` 是占位图那层 div 的样式、`className` 是类名。
//     端口这边**组件本身就是那个元素**，尺寸与位置由外层设（width / height / anchors），
//     也没有 CSS 可挂 ⇒ 三条都收、都不产出可见差异（与 Highlight 的 `component` 同一口径）。
//     官方 demo 里 `style={{padding: 30}}` 那种留白，端口要自己在外面包一层。
//   · `children` 在 QML 里就是声明式子项，别名只能叫 `footer`（`Item.children` 是内置只读属性，
//     占不了这个名字）。
//
// ------------------------------------------------------------------ 规格（empty.scss + variables.scss）
// `.semi-empty { display: flex }`
//   · vertical：`align-items: center; flex-direction: column` ⇒ 图与内容各自水平居中，
//     内容那层 `margin-top: 24`，标题与描述 `text-align: center`。
//   · horizontal：内容那层 `margin-left: 32`，文字左对齐。
//   · **内容那层永远渲染**（官方是三个 `{x ? … : null}` 装在一个无条件 div 里）⇒ 只给图时
//     vertical 仍比图高 24、horizontal 仍比图宽 32；连图带文案都不给时整件是 24 高。
//     这条看着像 bug，是官方的，照抄。
//   · 标题字号跟着「有没有图」变（index.tsx:102-109）：有图 ⇒ Typography.Title heading 4
//     （$font-size-header-4 = 20 / 行高 28 / 字重 600）；没图 ⇒ heading 6（16 / 22）
//     并且内联 `fontWeight: 400` 盖掉 typography 自己的 600。
//   · 描述紧跟标题时才有那 16（`&-title + &-description`，相邻兄弟选择器）⇒ 只有描述时它顶到 0。
//   · footer `margin-top: 24`（无条件）。
//   · 描述色 `--semi-color-text-1`，字号继承 body（14 / 行高 20）；标题色走 Typography = text-0。
//   · `.semi-empty-image` 的 `justify-content: center` 在两档布局里都是空转：那一层是
//     shrink-to-fit（列档被 align-items:center 收成内容宽、行档 flex-basis auto 也是内容宽），
//     容器宽 == 图宽，居中无处可用。`pointer-events: none` 在 QML 天然成立（图与 Loader 不挂 handler）。
//   · ARIA：官方 sprite 档 `aria-hidden="true"`（端口 sprite 档本来就不画，另给
//     `Accessible.ignored` 把图块整层摘掉）、`<img>` 档的 `alt` 取「描述是字符串就用描述，
//     否则 'empty'」（:81）⇒ 落进 `Accessible.name`。
//
// ------------------------------------------------------------------ 尺寸的算法口径
// `implicitWidth` 只吃「自然宽」（隐藏量测件 / 图与节点自身），**绝不读 `control.width`** ——
// `Item.width` 没设时回落 `implicitWidth`，绑定了就是自己依赖自己的环（实测这一轮的数直接作废）。
// 换行用的可用宽 `contentWidth` 才读 `control.width`，各块的实际高度由排完的 Text / Row 报回来，
// 于是 `implicitHeight` 依赖的是「高度」而不是「宽度」，链子不闭。
Item {
    id: control

    // ---- 官方 EmptyProps（index.tsx:17-27，缺省 :35-37）----
    property string layout: "vertical"
    property var image: undefined
    property var darkModeImage: undefined
    property var title: undefined
    property var description: undefined
    property var imageStyle: undefined
    property var style: undefined
    property var className: undefined

    // 官方 children 那一档（.semi-empty-footer）
    default property alias footer: footerRow.data

    readonly property bool horizontal: control.layout === "horizontal"
    readonly property bool titleTaken: control._taken(control.title)
    readonly property bool descriptionTaken: control._taken(control.description)
    // `Row.data` 是只读清单、不 NOTIFY，直接在绑定里读会打一条 "depends on non-bindable
    // properties" ⇒ 由 childrenChanged 把条数记成普通属性，绑定只读这个属性
    property int footerCount: 0
    readonly property bool footerTaken: control.footerCount > 0

    // 取哪一份图（index.tsx:82 的真值档）
    readonly property var activeImage: Theme.mode === Theme.Dark && control._taken(control.darkModeImage)
        ? control.darkModeImage : control.image

    // 「有图」判定（:84-97）：字符串档不看真值（'' 也算有图），对象档要带 id，其余按节点
    readonly property bool hasImage: typeof control.activeImage === "string"
        || control.activeImage instanceof Component
        || (typeof control.activeImage === "object" && control.activeImage !== null
            && control.activeImage.id !== undefined)

    readonly property bool isUrlImage: typeof control.activeImage === "string"
    readonly property bool isNodeImage: control.activeImage instanceof Component

    function _taken(value) {
        return value !== undefined && value !== null && value !== "";
    }

    function _nodeOf(value) {
        return value instanceof Component ? value : null;
    }

    // ---- 图块：字符串档取图片自身尺寸，节点档取 Loader ----
    // 尺寸读 `implicitWidth / implicitHeight`，**不读 `sourceSize`** —— 后者对 SVG 会按设备
    // 像素比放大（cocoa 2× 下那张 200×200 报成 400×400，加载中还先报过 400×0），而 implicit
    // 两件套在 SVG 与位图上都恒是逻辑尺寸（200×200 / 480×270，offscreen 与 cocoa 一致）。
    readonly property real imageNaturalWidth: !control.hasImage ? 0
        : (control.isUrlImage ? urlImage.implicitWidth
            : (control.isNodeImage ? imageLoader.width : 0))
    readonly property real imageNaturalHeight: !control.hasImage ? 0
        : (control.isUrlImage ? urlImage.implicitHeight
            : (control.isNodeImage ? imageLoader.height : 0))

    // ---- 内容层的自然宽：三块各量各的，取最大 ----
    // 自然宽用一只 `visible: false` 的同款 Text 去量，不用 TextMetrics —— 两者对同一串 CJK
    // 的排版宽度在 2× 屏上能差出好几个像素（TextMetrics 偏窄，量出来的盒宽会把最后一个字
    // 挤到第二行）。走同一个 QQuickText 布局引擎就与真正渲染那件逐像素一致。
    readonly property real titleNaturalWidth: !control.titleTaken ? 0
        : (control._nodeOf(control.title) !== null ? titleLoader.width : titleMeasurer.implicitWidth)
    readonly property real descriptionNaturalWidth: !control.descriptionTaken ? 0
        : (control._nodeOf(control.description) !== null ? descriptionLoader.width
            : descriptionMeasurer.implicitWidth)
    readonly property real footerNaturalWidth: control.footerTaken ? footerRow.implicitWidth : 0
    readonly property real contentNaturalWidth: Math.max(control.titleNaturalWidth,
        control.descriptionNaturalWidth, control.footerNaturalWidth)

    // 外层给得更窄时才换行（官方 flex 里内容项会被 shrink）
    readonly property real contentWidth: control.contentNaturalWidth
        < (control.width - (control.horizontal ? control.imageNaturalWidth + 32 : 0))
        ? control.contentNaturalWidth
        : Math.max(0, control.width - (control.horizontal ? control.imageNaturalWidth + 32 : 0))

    // ---- 排完之后的实际高度，由 Text / Row 自己报回来 ----
    readonly property real titleHeight: control.titleTaken
        ? (control._nodeOf(control.title) !== null ? titleLoader.height : titleText.height) : 0
    readonly property real descriptionHeight: control.descriptionTaken
        ? (control._nodeOf(control.description) !== null ? descriptionLoader.height
            : descriptionText.height) : 0
    readonly property real footerHeight: control.footerTaken ? footerRow.height : 0

    // 描述紧跟标题才有那 16；footer 的 24 无条件
    readonly property real descriptionTop: control.titleTaken ? control.titleHeight + 16 : 0
    readonly property real footerTop: control.descriptionTaken
        ? control.descriptionTop + control.descriptionHeight + 24
        : (control.titleTaken ? control.titleHeight + 24 : 24)

    readonly property real contentHeight: control.footerTaken
        ? control.footerTop + control.footerHeight
        : (control.descriptionTaken ? control.descriptionTop + control.descriptionHeight
            : (control.titleTaken ? control.titleHeight : 0))

    implicitWidth: control.horizontal
        ? control.imageNaturalWidth + 32 + control.contentNaturalWidth
        : Math.max(control.imageNaturalWidth, control.contentNaturalWidth)
    implicitHeight: control.horizontal
        ? Math.max(control.imageNaturalHeight, control.contentHeight)
        : control.imageNaturalHeight + 24 + control.contentHeight

    // ---- .semi-empty-image ----
    Item {
        id: imageShell

        objectName: "emptyImageShell"

        x: control.horizontal ? 0 : Math.max(0, (control.width - control.imageNaturalWidth) / 2)
        y: 0
        width: control.imageNaturalWidth
        height: control.imageNaturalHeight
        Accessible.ignored: true

        // 字符串档：官方是 <img alt src>，尺寸取图片自身
        Image {
            id: urlImage

            objectName: "emptyUrlImage"

            visible: control.isUrlImage
            source: control.isUrlImage ? String(control.activeImage) : ""
            fillMode: Image.PreserveAspectFit
            Accessible.name: typeof control.description === "string"
                ? control.description : "empty"
        }

        // 节点档（不写 `active`：sourceComponent 为 null 时 Loader 自己就不载东西，
        // 那条绑定是冗余守卫 —— 变异扫描里摘掉它一条用例都不红）
        Loader {
            id: imageLoader

            objectName: "emptyImageLoader"

            sourceComponent: control.isNodeImage ? control.activeImage : null
        }
    }

    // ---- .semi-empty-content：标题 / 描述 / footer ----
    Item {
        id: contentShell

        objectName: "emptyContentShell"

        x: control.horizontal ? control.imageNaturalWidth + 32
            : Math.max(0, (control.width - control.contentWidth) / 2)
        y: control.horizontal ? 0 : control.imageNaturalHeight + 24
        width: control.contentWidth
        height: control.contentHeight

        Text {
            id: titleText

            objectName: "emptyTitle"

            // 有图 heading 4（20/28/600），没图 heading 6（16/22）+ 内联字重 400
            visible: control.titleTaken && control._nodeOf(control.title) === null
            x: 0
            y: 0
            width: parent.width
            text: String(control.title)
            textFormat: Text.PlainText
            font.pixelSize: control.hasImage ? 20 : 16
            font.weight: control.hasImage ? Font.DemiBold : Font.Normal
            lineHeight: control.hasImage ? 28 : 22
            lineHeightMode: Text.FixedHeight
            color: Theme.current.colorText0
            horizontalAlignment: control.horizontal ? Text.AlignLeft : Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Loader {
            id: titleLoader

            objectName: "emptyTitleLoader"

            active: control.titleTaken && control._nodeOf(control.title) !== null
            sourceComponent: control._nodeOf(control.title)
            x: control.horizontal ? 0 : Math.max(0, (parent.width - width) / 2)
        }

        Text {
            id: descriptionText

            objectName: "emptyDescription"

            visible: control.descriptionTaken && control._nodeOf(control.description) === null
            x: 0
            y: control.descriptionTop
            width: parent.width
            text: String(control.description)
            textFormat: Text.PlainText
            font.pixelSize: Theme.current.fontSizeRegular
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
            color: Theme.current.colorText1
            horizontalAlignment: control.horizontal ? Text.AlignLeft : Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Loader {
            id: descriptionLoader

            objectName: "emptyDescriptionLoader"

            active: control.descriptionTaken && control._nodeOf(control.description) !== null
            sourceComponent: control._nodeOf(control.description)
            x: control.horizontal ? 0 : Math.max(0, (parent.width - width) / 2)
            y: control.descriptionTop
        }

        // 官方那个 div 里多个行内子项是并排的 ⇒ 行；间距不加（demo 自己写 marginRight）
        Row {
            id: footerRow

            objectName: "emptyFooter"

            onChildrenChanged: control.footerCount = children.length

            visible: control.footerTaken
            x: control.horizontal ? 0 : Math.max(0, (parent.width - implicitWidth) / 2)
            y: control.footerTop
            spacing: 0
        }
    }

    // 自然宽量测件：与真正渲染那件同款字体、不换行、不参与布局（根是裸 Item，不占位）
    Text {
        id: titleMeasurer

        objectName: "emptyTitleMeasurer"

        visible: false
        text: control.titleTaken && control._nodeOf(control.title) === null
            ? String(control.title) : ""
        font.pixelSize: control.hasImage ? 20 : 16
        font.weight: control.hasImage ? Font.DemiBold : Font.Normal
        lineHeight: control.hasImage ? 28 : 22
        lineHeightMode: Text.FixedHeight
        wrapMode: Text.NoWrap
    }

    Text {
        id: descriptionMeasurer

        objectName: "emptyDescriptionMeasurer"

        visible: false
        text: control.descriptionTaken && control._nodeOf(control.description) === null
            ? String(control.description) : ""
        font.pixelSize: Theme.current.fontSizeRegular
        lineHeight: 20
        lineHeightMode: Text.FixedHeight
        wrapMode: Text.NoWrap
    }
}
