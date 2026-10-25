import QtQuick

// 头像组。规格照 packages/semi-ui/avatar/avatarGroup.tsx（getAllAvatars / getMergeAvatars /
// renderMoreAvatar / render）与编译后的 semi.css 里 `.semi-avatar-group` 那一组（2631-2796 行）。
//
//     AvatarGroup {
//         Avatar { text: "A" }
//         Avatar { src: "qrc:/a.png" }
//         Avatar { text: "Semi" }
//     }
//
// 端口口径：
//   · 官方用 cloneElement 把组的 size/shape 硬塞给每个成员，成员自己写的顶不掉（这里靠 groupSize /
//     groupShape 两个下发字段），所以「同一组里混尺寸、混形状」在官方压根不存在。
//   · 官方只给下标 0..20 生成层序类名，第 21 个之后没有 z-index；这里把两条算式一路延下去，
//     否则 20 个之后整段会翻到最上面（DOM 那条「后面的兄弟盖前面」在这里是要不到的结果）。
//   · 截断走「把溢出的成员置 visible:false」：实测 Row 会跳过不可见子项（间距也不留）。
//     代价是使用处自己隐藏的项和组截断的项分不开，而官方数的是 children 的个数、不看可见性 ——
//     restNumber 因此也按声明个数算，与官方一致。
//   · 「+N」那一枚官方是数组末尾多出来的一项、照样参与重叠与层序；QML 里它不能既是组的自留件
//     又混进成员名单，所以挂在组上、排到最后一个可见成员之后。
Item {
    id: group

    default property alias content: groupRow.data
    property string size: "medium"
    property string shape: "circle"
    property string overlapFrom: "start"
    property var maxCount: undefined
    property var renderMore: null

    readonly property var sizeLadder: ["extra-extra-small", "extra-small", "small", "default",
        "medium", "large", "extra-large"]
    readonly property string sizeKey: group.namedSize ? group.size : "medium"
    readonly property bool namedSize: sizeLadder.indexOf(group.size) >= 0
    readonly property int memberSide: group.sizePx(group.sizeKey)
    readonly property int borderWidth: group.borderPx(group.sizeKey)
    readonly property real overlap: group.marginPx(group.sizeKey)
    readonly property bool numberGiven: typeof group.maxCount === "number" && isFinite(group.maxCount)
    // `content`（= Row.data）没有 NOTIFY，光靠它派生出来的计数不会随增删成员重算
    // ⇒ 借 childrenChanged 当脉冲，把这条链挂在一个真的信号上
    readonly property int memberPulse: groupRow.children.length
    readonly property int totalCount: group.memberPulse >= 0 ? group.declaredMembers().length : 0
    readonly property int keepCount: group.numberGiven
        ? Math.min(group.maxCount, group.totalCount) : group.totalCount
    readonly property bool truncated: group.numberGiven && group.totalCount > group.maxCount
    readonly property int restNumber: group.truncated ? group.totalCount - group.maxCount : 0
    readonly property var lastKeptMember: group.keepCount > 0 ? group.memberAt(group.keepCount - 1) : null

    implicitWidth: Math.max(groupRow.implicitWidth, group.moreRight)
    implicitHeight: group.memberSide

    // 「+N」那一枚（或 renderMore 给的节点）排在最后一个保留项之后
    readonly property var moreSlot: moreAvatar.visible ? moreAvatar : moreNode
    readonly property real moreRight: moreAvatar.visible || moreNode.active
        ? group.moreSlot.x + group.moreSlot.width : 0

    Accessible.role: Accessible.List

    Row {
        id: groupRow

        objectName: "avatarGroupRow"
        // 组内重叠 = 官方那条负 margin-left；`:first-child { margin-left: 0 }` 正好等于
        // 「间距只加在相邻两项之间」
        spacing: -group.overlap

        onChildrenChanged: syncTimer.restart()
    }

    Timer {
        id: syncTimer

        interval: 0
        onTriggered: group.syncRoles()
    }

    // 官方 .semi-avatar-item-more：底色 grey-5（那条规则两个类名，压过色板类名）、白字、children 是 +N
    Avatar {
        id: moreAvatar

        objectName: "avatarGroupMore"
        visible: group.truncated && !group._taken(group.renderMore)
        x: group.lastKeptMember !== null
            ? group.lastKeptMember.x + group.lastKeptMember.width - group.overlap : 0
        y: (group.memberSide - height) / 2
        // 官方把它当作 merged 数组末尾那一项来发层序类名
        z: group.overlapFrom === "end" ? 80 + group.keepCount : 100 - group.keepCount
        groupSize: group.size
        groupShape: group.shape
        groupBorderWidth: group.borderWidth
        backgroundColor: Theme.current.grey[5]
        text: "+" + group.restNumber
        alt: " Number of remaining Avatars：" + group.restNumber + "," + group.restLabels()
    }

    Loader {
        id: moreNode

        objectName: "avatarGroupMoreNode"
        active: group.truncated && group._taken(group.renderMore)
        sourceComponent: group._taken(group.renderMore) ? group.renderMore : null
        x: group.lastKeptMember !== null
            ? group.lastKeptMember.x + group.lastKeptMember.width - group.overlap : 0
        y: (group.memberSide - height) / 2
        z: group.overlapFrom === "end" ? 80 + group.keepCount : 100 - group.keepCount
    }

    Component.onCompleted: syncTimer.restart()

    function syncRoles() {
        const members = group.declaredMembers();
        for (let i = 0; i < members.length; ++i) {
            const it = members[i];
            it.groupSize = group.size;
            it.groupShape = group.shape;
            it.groupBorderWidth = group.borderWidth;
            // 官方只给排进 merged 数组的那几项发层序类名
            // （.semi-avatar-group .semi-avatar-item-start-{i}{z-index:100-i}，.semi-avatar-item-end-{i}{z-index:80+i}）
            if (i >= group.keepCount)
                it.visible = false;
            else
                it.z = group.overlapFrom === "end" ? 80 + i : 100 - i;
        }
    }

    function memberAt(index) {
        const members = group.declaredMembers();
        return index < members.length ? members[index] : null;
    }

    // 名单按声明顺序（官方数的是 React children 的顺序），只认带 side 的头像
    function declaredMembers() {
        const out = [];
        for (let i = 0; i < group.content.length; ++i) {
            const it = group.content[i];
            if (it !== null && it.side !== undefined)
                out.push(it);
        }
        return out;
    }

    // 官方 renderMoreAvatar 的 alt 尾巴：把溢出那几枚的 alt（没有就取文字）拼起来
    function restLabels() {
        const members = group.declaredMembers();
        let out = "";
        for (let i = group.keepCount; i < members.length; ++i) {
            const info = members[i].alt !== "" ? members[i].alt : members[i].text;
            if (info.length === 0)
                continue;
            out = out.length > 0 ? out + "," + info : info;
        }
        return out;
    }

    function _taken(value) {
        return !!value;
    }

    function sizePx(key) {
        switch (key) {
        case "extra-extra-small":
            return 20;
        case "extra-small":
            return 24;
        case "small":
            return 32;
        case "default":
            return 40;
        case "medium":
            return 48;
        case "large":
            return 72;
        case "extra-large":
            return 128;
        }
        return 48;
    }

    // $width-avatar_*-border
    function borderPx(key) {
        if (key === "large" || key === "extra-large")
            return 3;
        if (key === "extra-extra-small" || key === "extra-small")
            return 1;
        return 2;
    }

    // $spacing-avatar_*-marginLeft
    function marginPx(key) {
        switch (key) {
        case "extra-extra-small":
            return 4;
        case "extra-small":
            return 10;
        case "large":
            return 18;
        case "extra-large":
            return 32;
        }
        return 12;
    }
}
