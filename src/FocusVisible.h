#pragma once

#include <QObject>
#include <QtQmlIntegration/qqmlintegration.h>

namespace semi {

// 模拟 CSS 的 :focus-visible。
//
// QML 只提供 activeFocus，分不清「鼠标点进来的焦点」和「键盘 Tab 进来的焦点」，
// 如果直接拿 activeFocus 画焦点环，鼠标点击也会出现一圈轮廓，比 Semi 脏。
// 这里在应用级记录最近一次交互用的设备，只有键盘操作后才认为该显示焦点环。
class FocusVisible : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool keyboardMode READ keyboardMode NOTIFY keyboardModeChanged FINAL)

public:
    explicit FocusVisible(QObject *parent = nullptr);

    bool keyboardMode() const { return m_keyboardMode; }

    // 组件里这么用：visible: FocusVisible.shouldShow(control.activeFocus)
    Q_INVOKABLE bool shouldShow(bool hasFocus) const { return hasFocus && m_keyboardMode; }

Q_SIGNALS:
    void keyboardModeChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void setKeyboardMode(bool on);

    bool m_keyboardMode = false;
};

} // namespace semi
