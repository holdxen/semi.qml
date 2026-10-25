import QtQuick

// Skeleton.Button：占位按钮。官方 `.semi-skeleton-button` 是这五个件里唯一宽高都写死的：
// `$width-skeleton_button` 115 × `$height-control-default` 32。
//
//     SkeletonButton { }
SkeletonBlock {
    id: button

    objectName: "skeletonButton"

    implicitWidth: 115
    implicitHeight: 32
}
