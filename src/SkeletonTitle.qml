import QtQuick

// Skeleton.Title：占位标题。官方 `.semi-skeleton-title { width: 100%; height: $height-control-small }`
// ⇒ 高 24、宽跟着容器（QML 侧就是 `width: parent.width`，父容器没给宽就是 0）。
//
//     SkeletonTitle { }
//     SkeletonTitle { width: 120 }        // 官方 demo 的 style={{ width: 120 }}
SkeletonBlock {
    id: title

    objectName: "skeletonTitle"

    width: title.parent ? title.parent.width : 0
    implicitHeight: 24
}
