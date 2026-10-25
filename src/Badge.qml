pragma ComponentBehavior: Bound

import QtQuick

// 徽标。官方 `packages/semi-ui/badge/index.tsx`（BadgeProps :15-31、propTypes :35-50、
// defaultProps :52-60、render :64-94）+ `packages/semi-foundation/badge/{badge.scss,
// variables.scss,constants.ts}`。
//
//     Badge { count: 5; Avatar { text: "S" } }          // 包住 base 内容，角上挂数字
//     Badge { dot: true; Icon { name: "bell" } }        // 小圆点
//     Badge { count: "NEW"; theme: "light" }            // 字符串档
//     Badge { count: testCase.lockIcon; Avatar {} }     // 节点档（官方 ReactNode）
//     Badge { count: 99; overflowCount: 10 }            // "10+"
//
// ------------------------------------------------------------------ 官方 prop（14 条）
//   `count` `dot` `type` `theme` `position` `overflowCount` `style` `className`
//   `countClassName` `countStyle` `children` `onClick` `onMouseEnter` `onMouseLeave`。
//   defaultProps 只给了五条：`dot: false`、`type: 'primary'`、`theme: 'solid'`、
//   `className: ''` 与三个空回调 ⇒ **`count` / `overflowCount` / `position` 都没有缺省值**，
//   `position` 是在 render 里现取的 `direction === 'rtl' ? 'leftTop' : 'rightTop'`（:67-68）。
//   `className` / `style` / `countClassName` / `countStyle` 四条只喂 DOM ⇒ 端口收了不产出差异。
//
// ------------------------------------------------------------------ 三档「有没有徽标」判据（:69-70）
//   · `showBadge = count !== null && typeof count !== 'undefined'` ⇒ **给了就画，`count=0` 也画 "0"**
//     （旧端口那条 `showZero` 是自造的，语义正好相反）。
//   · `custom = count && !(isNumber || isString)` ⇒ 节点档。注意它带**真值判断**：
//     `count=0` 或 `count=''` 时 custom 是假 ⇒ 走数字/字符串档（官方就是这个行为）。
//   · 类名叠加规则（:71-79）：`-dot` 只看 `dot`；`-count`（那套 18 高的药丸几何）要
//     `!dot && !custom && showBadge` 三条同时成立；`-type` / `-theme` 两档在 custom 时**整条不加**
//     （节点自己画底色）；`-position` 要 `Boolean(position) && Boolean(children)` ⇒
//     **没有 children 就不绝对定位**，改挂 `-block`（`position: static`，跟着文字流走）。
//   · 于是「没给 count 也没开 dot」= 一个 0×0 的空 span（type/theme 类还在，但没尺寸）⇒ 什么都不画。
//
// ------------------------------------------------------------------ 数字与截断（:81-85）
//   `isNumber(count)` 才走 `overflowCount && overflowCount < count ? \`${overflowCount}+\` : \`${count}\``
//   ⇒ `overflowCount` 没给（undefined）或 0 都是**假值 ⇒ 永不截断**；负数 overflowCount 是真值，
//   比 count 小就照官方那样拼出 `-5+`（端口不修，钉成一条用例）。字符串与节点档原样渲染。
//   `dot` 为真时内容直接不渲染（`{dot ? null : content}`），即便同时给了 count。
//
// ------------------------------------------------------------------ 几何与配色（variables.scss / badge.scss）
//   dot 8×8、圆角 50%；count 高 18、`min-width: 18`、圆角 9（= 高的一半）、内边距 0 4、
//   `box-sizing: border-box` ⇒ 那 1px 描边与 4px 左右内边距都在 18 的高宽之内；
//   字号吃 `@include font-size-small` = **12 / 行高 16**、字重 `$font-weight-regular` = 400；
//   描边恒 `1px var(--semi-color-bg-1)`（与 type/theme 无关，就是那圈把徽标与底图隔开的白环）；
//   `z-index: 1`。四方位是**角点居中**：`right:0 / top:0` + `translate(50%, -50%)`（其余三面同理）
//   ⇒ 徽标中心正落在 base 内容的那个角点上，不是「贴边留一点」那种摆法。
//   配色矩阵（6 type × 3 theme，全走语义令牌）：
//     · solid   → 底色 `--semi-color-<type>`，**文字不随 type 变**（`-count` 那条 default 的
//       `color: --semi-color-bg-2`，type 块只改 background）
//     · light   → 底色 `--semi-color-<type>-light-default` + 文字 `--semi-color-<type>`
//     · inverted→ 只改文字为 `--semi-color-<type>`，底色仍是 default 的 `--semi-color-bg-1`
//       ⇒ **`dot` + `inverted` 是一颗白底白环的点，画在浅色底图上就是隐形的**（官方如此，端口照抄并钉一条）
//     · type 认不出来 ⇒ 没有 type 块 ⇒ solid 落到 default 底色 bg-1（同样隐形）
//
// ------------------------------------------------------------------ 端口差异
//   · 端口没有 RTL 方向概念 ⇒ `position` 的缺省恒 `rightTop`（官方 rtl 时是 leftTop）。
//   · `rtl.scss` 整份只有一句 `direction: rtl`，端口不落。
//   · 官方三个事件挂在外层 span（`{...rest}` 摊在那儿），端口是 `clicked` / `mouseEntered` /
//     `mouseLeft` 三个信号（后两个改名，理由见信号处）。
//   · 官方外层是 `display: inline-block` ⇒ 有 children 时端口把自身尺寸交给 base 内容
//     （徽标那一片是溢出去的不占隐式尺寸）；没 children 时外层尺寸就是徽标自己（`-block` 档）。
//   · base 内容在官方是「原样塞进 span」，端口要求子项自己从 (0,0) 铺开（不要 anchors.fill 父项，
//     否则父项的 childrenRect 会成环）。
Item {
    id: control

    // ---- 官方 BadgeProps（index.tsx:15-31，缺省 :52-60）----
    property var count: undefined                  // 数字 | 字符串 | Component
    property bool dot: false
    property string type: "primary"                // primary|secondary|tertiary|danger|warning|success
    property string theme: "solid"                 // solid | light | inverted
    property string position: "rightTop"           // leftTop | leftBottom | rightTop | rightBottom
    property var overflowCount: undefined          // 官方无缺省 ⇒ 不传永不截断
    property string className: ""                  // 死 prop（外层）
    property string countClassName: ""             // 死 prop（内层）
    property var countStyle: undefined             // 死 prop（内层）
    property var style: undefined                  // 死 prop（官方挂在内层，且给了它就整个顶掉 countStyle）

    /// 官方 children（被徽标包住的那块 base 内容）
    default property alias content: base.data

    // 官方是 onClick / onMouseEnter / onMouseLeave 三个回调。
    // **后两个在端口只能改名**：`left` 撞 `QQuickItem` 的 FINAL 成员（坑 59 那一族，
    // 撞了不是「不能用」而是整个类型创建不出来），命名跟 ListItem 的 `mouseEntered` / `mouseLeft` 对齐。
    signal clicked()
    signal mouseEntered()
    signal mouseLeft()

    // ---- 官方 render 里的三条判据（:69-77）----
    /// 官方是 `count !== null && typeof count !== 'undefined'` 两条。
    /// **端口只留 `!== null` 一条**：实测 QML 里「没赋值的 `property var`」与 null 在属性比较中
    /// 是同一个无效值（`count !== null` 直接给假），而反过来 `null !== undefined` 却是真 ⇒
    /// 加一半 `!== undefined` 是死重量（探针：删掉它两条用例照样绿）。
    readonly property bool showBadge: control.count !== null
    readonly property bool custom: !!control.count
        && !(typeof control.count === "number" || typeof control.count === "string")
    readonly property bool pill: !control.dot && !control.custom && control.showBadge
    readonly property bool hasChildren: control.declaredCount > 0

    property int declaredCount: 0

    // ---- 尺寸令牌（variables.scss）----
    readonly property real dotSide: 8                                             // $width/$height-badge_dot
    readonly property real countHeight: 18                                        // $height-badge_count
    readonly property real countPaddingX: 4                                       // $spacing-badge_count-paddingX
    readonly property real borderWidth: 1                                         // $width-badge-border
    readonly property real zBadge: 1                                              // $z-badge

    /// 官方 `-count` 的宽 = 内容 + 左右 4 内边距 + 左右 1 描边，且 `box-sizing: border-box`
    /// 配 `min-width: 18` ⇒ 取两者大值
    readonly property real naturalWidth: control.pill
        ? Math.max(control.countHeight, badgeLabel.implicitWidth
            + 2 * control.countPaddingX + 2 * control.borderWidth)
        : (control.dot ? control.dotSide : (control.custom ? badgeNode.implicitWidth : 0))
    readonly property real naturalHeight: control.pill ? control.countHeight
        : (control.dot ? control.dotSide : (control.custom ? badgeNode.implicitHeight : 0))

    implicitWidth: control.hasChildren ? base.width : badgeSide.width
    implicitHeight: control.hasChildren ? base.height : badgeSide.height

    // ------------------------------------------------------------------ 配色查表
    /// 官方 `$color-badge_<type>_solid-bg-default` = `--semi-color-<type>`。
    /// **认不出的 type 官方没有对应规则**（badge.scss 是六个 `&-<type>` 块，没有 default 分支）
    /// ⇒ 这里返回 undefined，由调用处落回 `-count` / `-dot` 那条 default 底色。
    /// （旧端口把 primary 当兜底，等于凭空多一条规则，实测 `type: 'bogus'` 会画成主色。）
    function typeColor() {
        switch (control.type) {
        case "primary":
            return Theme.current.colorPrimary;
        case "secondary":
            return Theme.current.colorSecondary;
        case "tertiary":
            return Theme.current.colorTertiary;
        case "danger":
            return Theme.current.colorDanger;
        case "warning":
            return Theme.current.colorWarning;
        case "success":
            return Theme.current.colorSuccess;
        }
        return undefined;
    }

    /// 官方 `$color-badge_<type>_light-bg-default` = `--semi-color-<type>-light-default`
    function typeLightColor() {
        switch (control.type) {
        case "primary":
            return Theme.current.colorPrimaryLightDefault;
        case "secondary":
            return Theme.current.colorSecondaryLightDefault;
        case "tertiary":
            return Theme.current.colorTertiaryLightDefault;
        case "danger":
            return Theme.current.colorDangerLightDefault;
        case "warning":
            return Theme.current.colorWarningLightDefault;
        case "success":
            return Theme.current.colorSuccessLightDefault;
        }
        return undefined;
    }

    /// 官方 `-dot` / `-count` 的 default 底色是 `--semi-color-bg-1`（inverted 与认不出的 type 落在这上面）
    function backgroundColor() {
        if (control.custom)
            return "transparent";                          // -custom 连 type/theme 类都不加
        if (control.theme === "solid") {
            const solid = control.typeColor();
            return solid === undefined ? Theme.current.colorBg1 : solid;
        }
        if (control.theme === "light") {
            const light = control.typeLightColor();
            return light === undefined ? Theme.current.colorBg1 : light;
        }
        return Theme.current.colorBg1;                     // inverted 与认不出的 theme
    }

    /// solid 档文字恒 `--semi-color-bg-2`（type 块只改底色）；light / inverted 才取 type 色
    function textColor() {
        if (control.theme === "light" || control.theme === "inverted") {
            const typed = control.typeColor();
            return typed === undefined ? Theme.current.colorBg2 : typed;
        }
        return Theme.current.colorBg2;
    }

    /// 官方四方位都是「角点居中」：`right/top: 0` + `translate(±50%, ∓50%)`
    function badgeX() {
        if (!control.hasChildren)
            return 0;
        const half = badgeSide.width / 2;
        return (control.position === "leftTop" || control.position === "leftBottom")
            ? -half : base.width - half;
    }

    function badgeY() {
        if (!control.hasChildren)
            return 0;
        const half = badgeSide.height / 2;
        return (control.position === "leftBottom" || control.position === "rightBottom")
            ? base.height - half : -half;
    }

    /// 官方 `-count` 的内容：数字档才可能拼出 `${overflowCount}+`
    function labelText() {
        if (control.dot || control.custom || !control.showBadge)
            return "";
        if (typeof control.count === "number") {
            const limit = control.overflowCount;
            if (limit && limit < control.count)
                return String(limit) + "+";
            return String(control.count);
        }
        return String(control.count);
    }

    // ------------------------------------------------------------------ base 内容
    Item {
        id: base

        objectName: "badgeBase"

        width: childrenRect.width
        height: childrenRect.height

        onChildrenChanged: control.declaredCount = base.children.length
    }

    // ------------------------------------------------------------------ 徽标那一片
    Rectangle {
        id: badgeSide

        objectName: "badgeSide"

        x: control.badgeX()
        y: control.badgeY()
        z: control.zBadge
        width: control.naturalWidth
        height: control.naturalHeight
        // 官方只有 `-dot` / `-count` 两类带圆角与描边；custom 档是 `display: flex` 光板一块
        radius: control.pill ? control.countHeight / 2 : (control.dot ? control.dotSide / 2 : 0)
        color: control.backgroundColor()
        // 不必再判 custom：custom 档 pill 与 dot 都是假 ⇒ 这条本来就落 0（多写一层是冗余）
        border.width: control.pill || control.dot ? control.borderWidth : 0
        border.color: Theme.current.colorBg1               // $color-badge_default-border-default

        Text {
            id: badgeLabel

            objectName: "badgeLabel"

            visible: control.pill
            anchors.centerIn: parent
            text: control.labelText()
            color: control.textColor()
            font.pixelSize: Theme.current.fontSizeSmall    // @include font-size-small = 12
            font.weight: Theme.current.fontWeightRegular   // $font-weight-regular = 400
        }

        Loader {
            id: badgeNode

            objectName: "badgeCustomNode"

            visible: control.custom
            active: control.custom
            anchors.centerIn: parent
            // 不必再判 custom：active 已经把「非节点档不建 item」管住了（多写一层是冗余）
            sourceComponent: control.count
        }

        HoverHandler {
            id: sideHover

            objectName: "badgeSideHover"
        }

        TapHandler {
            id: sideTap

            objectName: "badgeSideTap"

            // 四方位都是角点居中 ⇒ 恰好一个象限与 root 重叠，那部分由 root 的处理器负责；
            // 这里只补落在 root 矩形**之外**的那一半，两边合起来才等价于 DOM 的冒泡。
            onTapped: {
                const x = badgeSide.x + point.position.x;
                const y = badgeSide.y + point.position.y;
                if (x < 0 || y < 0 || x >= control.width || y >= control.height)
                    control.clicked();
            }
        }
    }

    // ---- 官方三个事件（`{...rest}` 摊在外层 span 上）----
    // DOM 里点 / 悬在徽标那一片上会冒泡到外层；端口那一片有一半溢在 root 矩形之外，
    // root 的处理器根本收不到 ⇒ 侧上补一条，且**只在落在 root 之外时**才发，两边不重不漏
    // （四方位都是「角点居中」⇒ 恰好有一个象限与 root 重叠，不做这道门就会双发）。
    TapHandler {
        objectName: "badgeTap"

        onTapped: control.clicked()
    }

    HoverHandler {
        id: rootHover

        objectName: "badgeHover"
    }

    readonly property bool pointerOnBadgeArea: rootHover.hovered || sideHover.hovered

    onPointerOnBadgeAreaChanged: control.pointerOnBadgeArea ? control.mouseEntered()
        : control.mouseLeft()

}
