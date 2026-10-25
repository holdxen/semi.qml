#pragma once

#include <QHash>
#include <QImage>
#include <QQuickImageProvider>
#include <QObject>
#include <QSize>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

// Cropper 的像素运行时。上游 `getCropperCanvas()`（semi-foundation/cropper/foundation.ts:819-902）
// 用的是 HTML canvas 的 getImageData / putImageData；QtQuick 的 Canvas 撑不住这条管线 ——
// 实测 `drawImage(Image)` 在 cocoa（真窗口）下什么都不画、offscreen 下正常，
// 而 `putImageData` 两平台都静默不生效。所以像素这一段落到 QImage + QPainter 上：
// 两平台同一份结果，并且能被用例逐点读像素断言。
//
// 几何不在这里算：裁切区在原图像素坐标下的位置（relativeCropLeft/Top/Width/Height）由
// QML 侧照上游那段公式算好再传进来，这样那套公式仍然在可变异扫描覆盖的范围里。

class CropperImageProvider : public QQuickImageProvider
{
public:
    CropperImageProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

    // 结果图存在进程级的一张表里（provider 实例被引擎持有，不能挂数据）
    static QString put(const QImage &image);

private:
    static QHash<QString, QImage> &store();
};

class CropperRuntime : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    // 故意不给 parent 缺省值：`is_default_constructible` 一真，Qt 就直接走构造函数那条路
    // （qqmlprivate.h:161 的优先级），create() 这个工厂根本不会被调，provider 也就注册不上。
    // 工厂要生效还得同时满足「返回值恰好是 CropperRuntime*」（同文件 :149-151）。
    explicit CropperRuntime(QObject *parent);

    static CropperRuntime *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    // 上游 getCropperCanvas 的等价物：先在「旋转后的外接矩形」画布上把原图居中画出来，
    // 再按裁切区在自然像素坐标下的位置取一块，取不到的那几条边用 fill 补。
    // `naturalWidth/Height` 是 QML 侧用来算几何的同一对数（上游 imgData.originalWidth/Height）：
    // 解码结果可能被设备像素比放大，画之前要按这一对归一，两边才不会错位。
    // `source` 只认本地路径与 qrc（这个接口是同步的，不能开事件循环等网络）；
    // 读不到源图时返回一张纯 fill 的结果。显示用的源不受这条限制。
    Q_INVOKABLE QImage cropToImage(const QUrl &source, qreal naturalWidth, qreal naturalHeight,
                                   qreal cropLeft, qreal cropTop,
                                   qreal cropWidth, qreal cropHeight, qreal rotate,
                                   const QColor &fill) const;

    // 把一张结果图挂到 image://semi-cropper/<id> 上，给 QML 显示用（官方是 canvas.toDataURL()）
    Q_INVOKABLE QString putImage(const QImage &image);

};
