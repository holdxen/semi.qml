import QtQuick

// Skeleton.Avatar：占位头像。官方 `item.tsx` 的 Generic 只在 type 是 avatar 时才拼
// `-{size}` 与 `-{shape}` 两个类（`size: 'medium'`、`shape: 'circle'`），
// 别的占位件没有这两个 prop。
//
// 尺寸照 `variables.scss` 的 `$width-skeleton_avatar_*`：
// extra-extra-small 20 / extra-small 24 / small 32 / medium 48 / large 72 / extra-large 128。
//
//     SkeletonAvatar { }                    // 48×48 圆
//     SkeletonAvatar { size: "small" }      // 32×32
//     SkeletonAvatar { shape: "square" }    // 圆角 --semi-border-radius-small
SkeletonBlock {
    id: avatar

    property string size: "medium"
    property string shape: "circle"

    objectName: "skeletonAvatar"

    readonly property real side: avatar.size === "extra-extra-small" ? 20
        : (avatar.size === "extra-small" ? 24
        : (avatar.size === "small" ? 32
        : (avatar.size === "large" ? 72
        : (avatar.size === "extra-large" ? 128 : 48))))

    implicitWidth: avatar.side
    implicitHeight: avatar.side
    // .semi-skeleton-avatar-circle { border-radius: 50% }；官方头像总是正方形，
    // 所以 50% 就是边长一半（QML 的 radius 是像素圆角，画不出非正方形的椭圆）
    radius: avatar.shape === "circle" ? Math.min(avatar.width, avatar.height) / 2
        : Theme.current.radiusSmall
}
