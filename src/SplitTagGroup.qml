import QtQuick
import QtQml

// 组合标签。官方 SplitTagGroupProps 只有 style / className / children / aria-label：
// 把并排的几枚标签连成一个整体 —— 首尾标签只留外侧圆角、中间标签圆角清零，
// 标签之间留 1px 缝（.semi-tag-split .semi-tag { border-radius: 0; margin-right: 1px }，
// -first / -last 再把外侧两个角恢复成 -square 的 3px 或 -circle 的全圆角）。
//
//     SplitTagGroup {
//         Tag { text: "标签一"; color: "blue"; type: "solid" }
//         Tag { text: "标签二"; color: "cyan"; type: "solid" }
//         Tag { text: "标签三"; color: "teal"; type: "solid" }
//     }
//
// 官方在 render 时用 Children.map + cloneElement 给「直接子元素」塞 -first / -last
// 类名，只数元素、不数文本；只有一个子元素时它同时拿到两个类名。这里等价地
// 给首尾 Tag 置 splitFirst / splitLast（几何排好后按 x 排序，同 Timeline 的做法）。
Item {
    id: control

    // 成员标签声明在这一行里（官方的 children）
    default property alias content: splitRow.data
    property string ariaLabel: ""

    // 官方 .semi-tag-split { display: inline-flex; align-items: center }
    implicitWidth: splitRow.implicitWidth
    implicitHeight: splitRow.implicitHeight

    Accessible.name: control.ariaLabel
    Accessible.role: Accessible.Grouping

    property var watched: []

    Row {
        id: splitRow

        objectName: "splitTagRow"
        // 中间那道 1px 缝官方是 margin-right、-last 再 unset；Row 的 spacing 只加在
        // 相邻两项之间，正好等于「最后一项不留缝」
        spacing: 1

        onChildrenChanged: syncTimer.restart()
    }

    Timer {
        id: syncTimer

        interval: 0
        onTriggered: control.syncRoles()
    }

    function syncRoles() {
        const kids = [];
        for (let i = 0; i < splitRow.children.length; ++i) {
            const it = splitRow.children[i];
            if (it !== null && it.splitChild !== undefined)
                kids.push(it);
        }
        // Row 的 children 不保证等于排布顺序（子项按堆叠序插入），按 x 排
        kids.sort(function (a, b) {
            return a.x - b.x;
        });
        for (let i = 0; i < kids.length; ++i) {
            const it = kids[i];
            it.splitChild = true;
            it.splitFirst = i === 0;
            it.splitLast = i === kids.length - 1;
            if (!control.isWatched(it)) {
                control.watched.push(it);
                it.xChanged.connect(function () {
                    syncTimer.restart();
                });
            }
        }
    }

    function isWatched(item) {
        for (let i = 0; i < control.watched.length; ++i)
            if (control.watched[i] === item)
                return true;
        return false;
    }
}
