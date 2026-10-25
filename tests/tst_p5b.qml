import QtQuick
import QtTest
import Semi

// 这里原来放 Carousel 的 11 条用例（旧端口：轨道平移 + interval prop + previous()）。
// Carousel 按官方 prop 面与动画模型重写后，用例全部迁到 tests/tst_carousel.qml，
// 本文件不再注册进 tests/CMakeLists.txt 的 SEMI_TEST_FILES。
TestCase {
    id: testCase

    name: "P5b"
}
