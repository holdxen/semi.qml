import QtQuick
import Semi

// Semi 官网组件文档站的 QML 复刻版入口。
//
// 数据由 build/ 下的两个脚本产出：
//   parse-docs.py  从 semi-design 的 content/**/index.md 解析出说明文字与 API 表
//   gen-tokens.py  从 semi-theme-default 的 scss 解析出令牌
//
// docs / tokens 由 main.cpp 读成**原文**注入（QML 的 XMLHttpRequest 默认不允许读本地文件，
// 会报 "Using GET on a local file is disabled by default"），在这里 JSON.parse。
// 不在 C++ 侧 parse：`QJsonDocument::toVariant()` 给出的数组是 QVariantList，
// `Array.isArray()` 对它返回 false，Table 这类消费方会当成空表（详见 main.cpp）。
Window {
    id: window

    width: 1320
    height: 880
    visible: true
    title: qsTr("Semi QML Gallery")
    color: Theme.current.colorBg0

    property string docsJson: ""
    property string tokensJson: ""
    readonly property var docs: window.docsJson === "" ? null : JSON.parse(window.docsJson)
    readonly property var tokens: window.tokensJson === "" ? null : JSON.parse(window.tokensJson)
    property string currentDir: "button"
    property string currentCategory: "basic"
    property string loadError: ""

    // 预置的搜索关键字（由 main.cpp 的 --search 注入），会同时喂给
    // 侧边栏搜索框与 Tokens 页的过滤框
    property string searchKeyword: ""

    GalleryShell {
        anchors.fill: parent
        docs: window.docs
        tokens: window.tokens
        currentDir: window.currentDir
        searchKeyword: window.searchKeyword
        onNavigate: function (dir, category) {
            window.currentDir = dir;
            window.currentCategory = category;
        }
    }

    Text {
        anchors.centerIn: parent
        visible: window.docs === null
        text: window.loadError !== "" ? window.loadError : qsTr("正在读取数据…")
        color: Theme.current.colorDanger
        font.pixelSize: Theme.current.fontSizeRegular
    }

    // --dark：直接以深色主题启动，便于逐页检查暗色下的样子
    Component.onCompleted: {
        if (Qt.application.arguments.indexOf("--dark") >= 0)
            Theme.mode = Theme.Dark;
    }
}
