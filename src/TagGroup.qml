pragma ComponentBehavior: Bound

import QtQuick

// 标签组。官方 TagGroupProps：tagList 传一组 Tag 的配置对象，超出 maxTagCount
// 的部分收进一枚 +N 标签；showPopover 时 hover 到 +N 用 Popover 展示剩余。
//
//     TagGroup {
//         width: 350
//         maxTagCount: 3
//         size: "large"
//         tagList: [
//             { color: "light-blue", children: "抖音" },
//             { color: "cyan", children: "火山" },
//             { color: "violet", children: "剪映" },
//             { color: "white", children: "醒图" }
//         ]
//         onTagClosed: (tagChildren, event, tagKey) => { ... }
//     }
//
// 溢出是纯算术、不量 DOM（group.tsx:74 `const n = restCount ? restCount
// : tagList.length - maxTagCount`）：前 maxTagCount 个照常渲染，n > 0 才追加 +N，
// 隐藏的标签照样占一个名额。maxTagCount 写成 0 时官方 `if (maxTagCount)` 判假、
// 不加 -group-max 类，但截断照跑（typeof undefined 才整组渲染）。
Item {
    id: control

    // ---- 官方 TagGroupProps ----
    property var tagList: []
    property int maxTagCount: -1
    property int restCount: 0
    property string size: "default"
    property string avatarShape: "square"
    property bool showPopover: false
    property var popoverProps: null
    property string mode: ""

    // 官方 onTagClose(tagChildren, e, tagKey) / onPlusNMouseEnter()
    signal tagClosed(var tagChildren, var event, var tagKey)
    signal plusNMouseEntered()

    readonly property int listLength: control.tagList === undefined || control.tagList === null
        ? 0 : control.tagList.length
    readonly property bool truncating: control.maxTagCount >= 0
    readonly property int nCount: !control.truncating ? 0
        : (control.restCount ? control.restCount : control.listLength - control.maxTagCount)
    readonly property int normalCount: control.truncating
        ? Math.min(Math.max(0, control.maxTagCount), control.listLength) : control.listLength
    readonly property var normalTags: control.sliceTags(0, control.normalCount)
    readonly property var restTags: control.sliceTags(control.normalCount, control.listLength)
    // 官方 .semi-tag-group-max.{-group-small,-group-large} 把高度钉成 22 / 26，
    // 也就是钉成一行的标签高
    readonly property int rowHeight: control.size === "large" ? 26 : 22

    implicitWidth: flow.implicitWidth
    implicitHeight: control.truncating ? control.rowHeight : flow.implicitHeight

    function sliceTags(from, to) {
        const out = [];
        if (!control.tagList)
            return out;
        for (let i = from; i < to && i < control.tagList.length; ++i)
            out.push(control.tagList[i]);
        return out;
    }

    function keyAt(item, name) {
        if (item === undefined || item === null)
            return undefined;
        return item[name];
    }

    // 官方给 ReactNode 的 children 用的是字符串那一支
    function textOf(item) {
        const own = control.keyAt(item, "text");
        if (own !== undefined && own !== null)
            return String(own);
        const kids = control.keyAt(item, "children");
        if (kids !== undefined && kids !== null)
            return String(kids);
        return "";
    }

    // 注入规则照抄 group.tsx:94-109：!newTag.size 才换成 group 的 size，
    // avatarShape 同理；tagKey 缺省时取字符串 children，再不行给一个随机数
    function injectedSize(item) {
        const own = control.keyAt(item, "size");
        if (control.mode === "custom")
            return own === undefined ? "" : own;
        return own ? own : control.size;
    }

    function injectedAvatarShape(item) {
        const own = control.keyAt(item, "avatarShape");
        if (control.mode === "custom")
            return own === undefined ? "square" : own;
        return own ? own : control.avatarShape;
    }

    function injectedTagKey(item) {
        const own = control.keyAt(item, "tagKey");
        if (own !== undefined && own !== null)
            return own;
        const kids = control.keyAt(item, "children");
        if (typeof kids === "string" || typeof kids === "number")
            return kids;
        const txt = control.keyAt(item, "text");
        if (typeof txt === "string" || typeof txt === "number")
            return txt;
        return Math.random();
    }

    function propOf(item, name, fallback) {
        const v = control.keyAt(item, name);
        return v === undefined ? fallback : v;
    }

    // 官方 popoverProps 是整份 PopoverProps 展开在最后（用户覆盖内置值），
    // 这里只吃得到 QML 侧有的那几项
    function placementOf() {
        const p = control.popoverProps;
        if (p === undefined || p === null || p.position === undefined)
            return Enums.Top;
        switch (String(p.position)) {
        case "topLeft": return Enums.TopLeft;
        case "topRight": return Enums.TopRight;
        case "bottom": return Enums.Bottom;
        case "bottomLeft": return Enums.BottomLeft;
        case "bottomRight": return Enums.BottomRight;
        case "left": return Enums.Left;
        case "leftTop": return Enums.LeftTop;
        case "leftBottom": return Enums.LeftBottom;
        case "right": return Enums.Right;
        case "rightTop": return Enums.RightTop;
        case "rightBottom": return Enums.RightBottom;
        case "top":
        default: return Enums.Top;
        }
    }

    Flow {
        id: flow

        objectName: "tagGroupFlow"
        width: control.width > 0 ? control.width : implicitWidth
        spacing: Theme.current.spacingTight       // .semi-tag-group .semi-tag { margin-right: 8 }

        Repeater {
            model: control.normalTags

            delegate: Tag {
                required property var modelData

                objectName: "tagGroupItem"
                text: control.textOf(modelData)
                color: control.propOf(modelData, "color", "grey")
                type: control.propOf(modelData, "type", "light")
                shape: control.propOf(modelData, "shape", "square")
                size: control.injectedSize(modelData)
                avatarSrc: control.propOf(modelData, "avatarSrc", "")
                avatarShape: control.injectedAvatarShape(modelData)
                closable: control.propOf(modelData, "closable", false)
                colorful: control.propOf(modelData, "colorful", false)
                gradient: control.propOf(modelData, "gradient", false)
                prefixIcon: control.propOf(modelData, "prefixIcon", null)
                suffixIcon: control.propOf(modelData, "suffixIcon", null)
                backgroundColor: control.propOf(modelData, "backgroundColor", "")
                tagKey: control.injectedTagKey(modelData)
                // 传了 visible 就是受控标签（官方 getDerivedStateFromProps 那一支）
                visible: control.propOf(modelData, "visible", true)

                onClosed: (tagChildren, event, tagKey) => control.tagClosed(tagChildren, event, tagKey)
            }
        }

        // +N：官方 closable=false、color=grey、style 把底色抹掉，文字 "+{n}"。
        // onMouseEnter 不受 showPopover 影响（官方那条回调一直在），
        // 只有气泡本身才吃 showPopover
        Tag {
            id: plusN

            objectName: "tagGroupPlusN"
            visible: control.nCount > 0
            closable: false
            size: control.size
            color: "grey"
            backgroundColor: "transparent"
            text: "+" + control.nCount

            onMouseEntered: control.plusNMouseEntered()
        }
    }

    // 官方 tag/group.tsx:53-66 —— showPopover 时把 +N 那张 Tag 包进
    // `<Popover showArrow content={restTags} trigger="hover" position="top" autoAdjustOverflow
    // {...popoverProps}>`。触发就交给 Popover 自己的 hover 档（50ms 延迟、卡片上也算「还在悬停」），
    // 所以这里不再自己拿 HoverHandler 拼 visible；showPopover=false 等价于官方那句「不渲染 Popover」，
    // 关掉 enabled 就是它（Tooltip 的 targetHover 看了 enabled）。
    Popover {
        id: restPop

        objectName: "tagGroupPopover"
        target: plusN
        showArrow: true
        enabled: control.showPopover
        position: control.placementOf()

        Flow {
            objectName: "tagGroupRestFlow"
            spacing: Theme.current.spacingTight

            Repeater {
                model: control.restTags

                delegate: Tag {
                    required property var modelData

                    objectName: "tagGroupRestItem"
                    text: control.textOf(modelData)
                    color: control.propOf(modelData, "color", "grey")
                    type: control.propOf(modelData, "type", "light")
                    shape: control.propOf(modelData, "shape", "square")
                    size: control.injectedSize(modelData)
                    avatarSrc: control.propOf(modelData, "avatarSrc", "")
                    avatarShape: control.injectedAvatarShape(modelData)
                    closable: control.propOf(modelData, "closable", false)
                    prefixIcon: control.propOf(modelData, "prefixIcon", null)
                    suffixIcon: control.propOf(modelData, "suffixIcon", null)
                    backgroundColor: control.propOf(modelData, "backgroundColor", "")
                    tagKey: control.injectedTagKey(modelData)
                    visible: control.propOf(modelData, "visible", true)

                    onClosed: (tagChildren, event, tagKey) => control.tagClosed(tagChildren, event, tagKey)
                }
            }
        }
    }
}
