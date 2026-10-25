import QtQuick

// Skeleton.Image：占位图。官方 `.semi-skeleton-image { width: 100%; height: 100% }` ——
// 它是五个占位件里唯一「自己不带尺寸」的，宽高全靠容器给，
// 所以官方 demo 都是 `Skeleton { style: { width: 200, height: 150 } }` 配 Skeleton.Image。
//
//     Skeleton {
//         width: 200
//         height: 150
//         placeholder: Component { SkeletonImage {} }
//     }
SkeletonBlock {
    id: image

    objectName: "skeletonImage"

    width: image.parent ? image.parent.width : 0
    height: image.parent ? image.parent.height : 0
}
