pragma ComponentBehavior: Bound

import QtQuick

// Skeleton.Paragraph：占位正文。官方是 `<ul class="semi-skeleton-paragraph">` 里的 `rows`
// 个 `<li>`，每个 li 高 `$height-skeleton_li` = 16、下边距 `$spacing-skeleton_li-marginBottom`
// = 10，最后一个 li 宽 60% 且没有下边距；ul 本身 margin/padding/list-style 都清零、宽 100%。
//
//     SkeletonParagraph { }             // 4 行
//     SkeletonParagraph { rows: 2; width: 240 }
Column {
    id: paragraph

    property int rows: 4

    objectName: "skeletonParagraph"

    width: paragraph.parent ? paragraph.parent.width : 0
    spacing: 10

    Repeater {
        model: paragraph.rows

        delegate: SkeletonBlock {
            id: line

            required property int index

            // 照 ul 的宽算（官方最后一段 60%）；别写 line.parent.width ——
            // Qt 6.11 起 Repeater 自己是个 Item，委托落到它身上的时机比绑定晚一帧，
            // 那一帧 line.parent 还是 null（ListPage「加载更多」那节踩到了）。
            width: paragraph.width * (line.index === paragraph.rows - 1 ? 0.6 : 1)
            height: 16
        }
    }
}
