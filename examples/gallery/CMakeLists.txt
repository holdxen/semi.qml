find_package(Qt6 6.5 REQUIRED COMPONENTS QuickLayouts)

# 组件页是逐个加的，用 GLOB 免得每加一页都要改这里。
# 放在模块根目录而不是子目录：子目录里的 QML 文件在同模块内的类型可见性
# 不可靠（页面里用 GallerySection 会报 "is not a type"）。
file(GLOB GALLERY_PAGES CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
    *Page.qml
)

# 官方占位插画（packages/semi-illustrations/src/svgs），Empty 那页要用
file(GLOB GALLERY_ILLUSTRATIONS CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
    data/illustrations/*.svg
)

qt_add_executable(semi-gallery main.cpp)

qt_add_qml_module(semi-gallery
    URI SemiGallery
    VERSION 1.0
    QML_FILES
        GalleryMain.qml
        GalleryShell.qml
        GallerySidebar.qml
        GalleryLabel.qml
        GallerySection.qml
        GalleryGuideline.qml
        GalleryApiTable.qml
        GalleryPlaceholder.qml
        TokenColorBlock.qml
        TokenTable.qml
        TokenColor.js
        ${GALLERY_PAGES}
        Main.qml
    RESOURCES
        data/docs.json
        data/tokens.json
        data/img/sample1.png
        data/img/sample2.png
        data/img/sample3.png
        data/img/sample4.png
        ${GALLERY_ILLUSTRATIONS}
)

target_link_libraries(semi-gallery PRIVATE
    Qt6::Quick
    Qt6::QuickLayouts
    semi
)
