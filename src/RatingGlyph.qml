pragma ComponentBehavior: Bound

import QtQuick

// 评分里的一枚图形。官方是同一个 content 画两遍（item.tsx:163-172）：默认是 IconStar，
// `character` 可以给字符串（当文字画）或 Component（对应 ReactNode）。
//
// 上色：官方靠 CSS `color: inherit`（rating.scss:71-73 的 -first / -second 只写
// color: $color-rating-bg-default，半星 / 整星那两支再 `color: inherit`），QML 没有
// 继承，所以外层把颜色传进来；Component 那条路由 Loader 在载入后把 color 写到被载入项上
// （前提是它有 color 属性，比如 Icon）。
Item {
    id: glyph

    property color color: Theme.current.yellow[5]
    property var character: undefined
    property int size: 24

    readonly property bool isText: typeof character === "string" && character !== ""
    readonly property bool isComponent: character !== undefined && character !== null
        && character instanceof Component

    // 尺寸永远是「整颗星」的格子大小，不是所在层的宽度：半星那层是个更窄的裁切容器，
    // 图形必须保持满格才裁得出左半边。
    width: size
    height: size

    Icon {
        objectName: "ratingGlyphIcon"

        x: 0
        y: 0
        width: glyph.size
        height: glyph.size
        visible: !glyph.isText && !glyph.isComponent
        name: "star"                            // 官方默认是 <IconStar size="extra-large"/>
        size: glyph.size
        color: glyph.color
    }

    Text {
        objectName: "ratingGlyphText"

        x: 0
        y: 0
        width: glyph.size
        height: glyph.size
        visible: glyph.isText
        text: glyph.isText ? glyph.character : ""
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: glyph.color
        font.pixelSize: glyph.size
    }

    Loader {
        id: glyphLoader

        objectName: "ratingGlyphLoader"
        x: 0
        y: 0
        visible: glyph.isComponent
        active: glyph.isComponent
        sourceComponent: glyph.isComponent ? glyph.character : null

        onLoaded: {
            // 等价于 CSS 的 color: inherit。Loader.item 的静态类型是 QObject，
            // 这里按鸭子类型探它有 color 才绑（Icon / Text / 自带颜色的自定义项）。
            // qmllint disable missing-property
            if (glyphLoader.item !== null && glyphLoader.item !== undefined
                && glyphLoader.item.color !== undefined)
                glyphLoader.item.color = Qt.binding(function () { return glyph.color; });
            // qmllint enable missing-property
        }
    }
}
