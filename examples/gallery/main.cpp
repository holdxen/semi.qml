#include <QDebug>
#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTimer>

int main(int argc, char *argv[])
{
    // 规避 Qt 6.11 的动画计时问题：threaded render loop 默认的 vsync 节流驱动
    // （qsgcontext.cpp:113-215 的 QSGDefaultAnimationDriver）在「窗口空闲之后的第一个
    // 动画」上会一次性给出过大的时间增量 —— 实测 200ms 的 Behavior 动画只活了 12ms
    // 就被推过终点，看起来像「没有动画」，同一次运行里第二次点击则是正常的 209ms。
    // 定长步进（qsg_useConsistentTiming()，qsgcontext.cpp:74-82）让每帧只推进一个
    // vsync 步长，增量不会再跳。代价：极端掉帧时动画会比墙钟略慢。
    qputenv("QSG_FIXED_ANIMATION_STEP", "1");

    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(EXIT_FAILURE); }, Qt::QueuedConnection);

    engine.loadFromModule("SemiGallery", "GalleryMain");

    const QStringList args = app.arguments();
    if (engine.rootObjects().isEmpty())
        return app.exec();

    qInfo() << "Started";

    QObject *root = engine.rootObjects().first();

    // 数据由这里读进来注入：QML 的 XMLHttpRequest 默认不允许读本地文件。
    // 注入的是 JSON **原文**，不是 QJsonDocument::toVariant() —— 后者把数组变成 QVariantList，
    // 它在 QML 侧有 length、能按下标取，但 `Array.isArray()` 是 false，于是「先 Array.isArray
    // 再取用」的消费方（Table 的 dataSource）会当成空表 —— 每一页的 API 参考表都画「暂无数据」
    // 就是这个原因。交给 QML 自己 JSON.parse，拿到的才是原生数组。
    const auto readText = [](const QString &path) -> QString {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            qWarning() << "打不开" << path;
            return {};
        }
        return QString::fromUtf8(file.readAll());
    };
    root->setProperty("docsJson", readText(":/qt/qml/SemiGallery/data/docs.json"));
    root->setProperty("tokensJson", readText(":/qt/qml/SemiGallery/data/tokens.json"));

    // --page <dir>：直接打开某个组件页，便于逐页截图
    const int pageIndex = args.indexOf("--page");
    if (pageIndex > 0 && pageIndex + 1 < args.size()) {
        QTimer::singleShot(400, root, [root, page = args.at(pageIndex + 1)]() {
            root->setProperty("currentDir", page.toUtf8());
        });
    }

    // --scroll <px>：把内容区滚到指定位置（页面比一屏长，截图要看靠下的小节）
    // contentY 是普通属性，直接赋值不会被夹进范围，超出内容就会滚出一片空白，
    // 所以这里按 contentHeight 自己夹一次。
    const int scrollIndex = args.indexOf("--scroll");
    if (scrollIndex > 0 && scrollIndex + 1 < args.size()) {
        const int offset = args.at(scrollIndex + 1).toInt();
        QTimer::singleShot(600, root, [root, offset]() {
            auto *content = root->findChild<QQuickItem *>("contentScroll");
            if (!content)
                return;
            const qreal maxY = qMax(0.0, content->property("contentHeight").toReal() - content->height());
            content->setProperty("contentY", qBound(0.0, static_cast<qreal>(offset), maxY));
        });
    }

    // --search <关键字>：预置搜索框的内容，便于截图验证过滤效果。
    // 走 searchKeyword 一条通路：它既喂侧边栏，也喂带过滤框的页面（Tokens）。
    const int searchIndex = args.indexOf("--search");
    if (searchIndex > 0 && searchIndex + 1 < args.size()) {
        QTimer::singleShot(500, root, [root, keyword = args.at(searchIndex + 1)]() {
            root->setProperty("searchKeyword", keyword);
        });
    }

    // --shot <file>：抓一张图就退出
    const int shotIndex = args.indexOf("--shot");
    if (shotIndex > 0 && shotIndex + 1 < args.size()) {
        const QString out = args.at(shotIndex + 1);
        QTimer::singleShot(2000, root, [root, out]() {
            auto *window = qobject_cast<QQuickWindow *>(root);
            if (!window) {
                qWarning("root object is not a window");
                QCoreApplication::exit(EXIT_FAILURE);
                return;
            }
            const QImage image = window->grabWindow();
            qInfo() << "grab:" << image.size() << "saved:" << image.save(out) << out;
            QCoreApplication::quit();
        });
    }

    return app.exec();
}
