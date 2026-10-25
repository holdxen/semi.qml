cmake_minimum_required(VERSION 3.21)

project(Semi
    VERSION 0.1.0
    DESCRIPTION "A QML component library built on Qt Quick"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_standard_project_setup(REQUIRES 6.5)

# 在构建目录生成 .qmlls.ini，让 qmllint / Qt Creator 能解析本模块的 import
set(QT_QML_GENERATE_QMLLS_INI ON)

# 所有 QML 模块统一输出到 build/<preset>/qml/<URI>，符合 Qt 的 target path 约定
set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(SEMI_IS_TOP_LEVEL ON)
else()
    set(SEMI_IS_TOP_LEVEL OFF)
endif()

option(SEMI_BUILD_EXAMPLES "Build the Gallery example application" ${SEMI_IS_TOP_LEVEL})
option(SEMI_BUILD_TESTS "Build the unit tests" ${SEMI_IS_TOP_LEVEL})

add_subdirectory(src)

if(SEMI_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

if(SEMI_BUILD_TESTS)
    include(CTest)
    add_subdirectory(tests)
endif()

# ---- 安装与导出，供外部 find_package(Semi) ----
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

set(SEMI_INSTALL_CMAKEDIR ${CMAKE_INSTALL_LIBDIR}/cmake/Semi)

configure_package_config_file(
    cmake/SemiConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/SemiConfig.cmake
    INSTALL_DESTINATION ${SEMI_INSTALL_CMAKEDIR}
)

write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/SemiConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
    ARCH_INDEPENDENT
)

install(EXPORT SemiTargets
    FILE SemiTargets.cmake
    NAMESPACE Semi::
    DESTINATION ${SEMI_INSTALL_CMAKEDIR}
)

install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/SemiConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/SemiConfigVersion.cmake
    DESTINATION ${SEMI_INSTALL_CMAKEDIR}
)
