#include "CropperRuntime.h"

#include <QCryptographicHash>
#include <QImageReader>
#include <QPainter>
#include <QQmlEngine>
#include <QtMath>

CropperImageProvider::CropperImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage CropperImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    Q_UNUSED(requestedSize)
    QImage image = store().value(id);
    if (size)
        *size = image.size();
    return image;
}

// 结果图存在进程级的一份表里：`addImageProvider` 会接管 provider 的所有权（引擎析构时删掉它），
// 所以不能把数据挂在 provider 实例上 —— 每个引擎一个 provider，共读这一份。
QHash<QString, QImage> &CropperImageProvider::store()
{
    static QHash<QString, QImage> s_images;
    return s_images;
}

QString CropperImageProvider::put(const QImage &image)
{
    // 同一张结果反复取同一个 id：Cropper 每次裁切都会 putImage 一次，
    // 只按内容做键就不会把历史结果一直挂在内存里。
    const QByteArray digest = QCryptographicHash::hash(
        QByteArray::fromRawData(reinterpret_cast<const char *>(image.constBits()),
                                static_cast<qsizetype>(image.sizeInBytes())),
        QCryptographicHash::Md5).toHex();
    const QString id = QString::fromLatin1(digest).left(16);
    store().insert(id, image);
    return id;
}

CropperRuntime::CropperRuntime(QObject *parent)
    : QObject(parent)
{
}

// QML 侧把 `src` 交给 Qt.resolvedUrl() 之后传进来，这里只处理落地成 QImageReader 认得的路径。
// file:// 与 qrc: 两类能同步读到；http(s) 读不到 —— 那要走网络，而这个接口是同步的，
// 不能在信号处理器里开事件循环（端口限制，官方在浏览器里由 <img> 自己取）。
static QString readerPath(const QUrl &url)
{
    if (url.isLocalFile())
        return url.toLocalFile();
    const QString text = url.toString();
    if (text.startsWith(QStringLiteral("qrc:")))
        return QLatin1String(":") + text.mid(4);    // qrc:/a/b -> :/a/b（少这个冒号就读不到资源）
    return text;
}

CropperRuntime *CropperRuntime::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(jsEngine)
    qmlEngine->addImageProvider(QStringLiteral("semi-cropper"), new CropperImageProvider);
    return new CropperRuntime(nullptr);
}

QImage CropperRuntime::cropToImage(const QUrl &source, qreal naturalWidth, qreal naturalHeight,
                                   qreal cropLeft, qreal cropTop,
                                   qreal cropWidth, qreal cropHeight, qreal rotate,
                                   const QColor &fill) const
{
    const int w = qMax(1, static_cast<int>(cropWidth));
    const int h = qMax(1, static_cast<int>(cropHeight));

    QImage result(w, h, QImage::Format_ARGB32_Premultiplied);
    result.fill(fill);

    QImageReader reader(readerPath(source));
    const QImage src = reader.read();
    if (src.isNull())
        return result;

    // 外接矩形用 QML 传进来的 natural 尺寸算（上游那一份是 this.imgData.originalWidth/Height）：
    // 解码出来的 src 可能是按设备像素比放大过的（SVG 与 @2x 位图都会），必须归一到同一坐标系，
    // 否则这里的矩形和那边算好的 cropLeft/Top 对不上。
    const qreal imgWidth = naturalWidth > 0 ? naturalWidth : src.width();
    const qreal imgHeight = naturalHeight > 0 ? naturalHeight : src.height();

    const qreal angle = rotate * M_PI / 180.0;
    const qreal sine = qAbs(std::sin(angle));
    const qreal cosine = qAbs(std::cos(angle));
    const qreal containerWidth = imgWidth * cosine + imgHeight * sine;
    const qreal containerHeight = imgHeight * cosine + imgWidth * sine;

    // 裁切区与「旋转后的外接矩形」没有交集 ⇒ 上游那条分支就是返回一张纯 fill 的图
    if (cropLeft + cropWidth < 0 || cropTop + cropHeight < 0
        || cropLeft > containerWidth || cropTop > containerHeight) {
        return result;
    }

    QImage container(static_cast<int>(containerWidth), static_cast<int>(containerHeight),
                     QImage::Format_ARGB32_Premultiplied);
    // 上游这里也是先 fillStyle=fill 再画：旋转之后矩形四角落在图外，那几块就是 fill 的颜色
    container.fill(fill);
    QPainter cp(&container);
    cp.setRenderHint(QPainter::SmoothPixmapTransform);
    cp.translate(containerWidth / 2.0, containerHeight / 2.0);
    cp.rotate(rotate);
    cp.translate(-containerWidth / 2.0, -containerHeight / 2.0);
    cp.drawImage(QRectF((containerWidth - imgWidth) / 2.0, (containerHeight - imgHeight) / 2.0,
                        imgWidth, imgHeight),
                 src);
    cp.end();

    // 上游用 getImageData + putImageData(负偏移) 取那块 —— putImageData 是**整像素替换**（连 alpha
    // 一起覆盖），不是合成。这里同样走 CompositionMode_Source：fill 是半透明时，
    // SourceOver 会把「画布外的 fill」和「结果画布先铺的 fill」叠成两层，官方只有一层。
    QPainter rp(&result);
    rp.setRenderHint(QPainter::SmoothPixmapTransform);
    rp.setCompositionMode(QPainter::CompositionMode_Source);
    rp.drawImage(-cropLeft, -cropTop, container);
    rp.end();
    return result;
}

QString CropperRuntime::putImage(const QImage &image)
{
    return QStringLiteral("image://semi-cropper/%1").arg(CropperImageProvider::put(image));
}
