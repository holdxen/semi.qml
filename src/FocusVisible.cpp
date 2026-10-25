#include "FocusVisible.h"

#include <QEvent>
#include <QGuiApplication>

namespace semi {

FocusVisible::FocusVisible(QObject *parent)
    : QObject(parent)
{
    if (qApp)
        qApp->installEventFilter(this);
}

bool FocusVisible::eventFilter(QObject *watched, QEvent *event)
{
    switch (event->type()) {
    case QEvent::KeyPress:
        setKeyboardMode(true);
        break;
    case QEvent::MouseButtonPress:
    case QEvent::TouchBegin:
        setKeyboardMode(false);
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}

void FocusVisible::setKeyboardMode(bool on)
{
    if (m_keyboardMode == on)
        return;

    m_keyboardMode = on;
    Q_EMIT keyboardModeChanged();
}

} // namespace semi
