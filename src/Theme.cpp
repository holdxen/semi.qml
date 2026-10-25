#include "Theme.h"

#include <QColor>
#include <QDebug>
#include <QGlobalStatic>
#include <QMetaProperty>

namespace semi {

namespace {

// 令牌的唯一存放处。Q_GLOBAL_STATIC 负责延迟初始化与退出时销毁，
// 因此进程里不管有多少个 Theme 实例，看到的都是这里的两套令牌。
struct TokenStore
{
    SemiThemeValues *light = nullptr;
    SemiThemeValues *dark = nullptr;
    Theme::Mode mode = Theme::Light;

    ~TokenStore()
    {
        delete light;
        delete dark;
    }
};

Q_GLOBAL_STATIC(TokenStore, s_store)

} // namespace

QList<Theme *> Theme::s_instances;

Theme::Theme(QObject *parent)
    : QObject(parent)
{
    s_instances.append(this);
}

Theme::~Theme()
{
    s_instances.removeAll(this);
}

void Theme::ensureStore()
{
    TokenStore *store = s_store();
    if (store->light)
        return;

    store->light = new SemiThemeValues(SemiThemeValues::Light);
    store->dark = new SemiThemeValues(SemiThemeValues::Dark);

    // 直接改 Theme.dark.xxx 这类路径也要让组件收到通知
    QObject::connect(store->light, &SemiThemeValues::changed, []() { notifyTokensChanged(); });
    QObject::connect(store->dark, &SemiThemeValues::changed, []() { notifyTokensChanged(); });
}

void Theme::notifyTokensChanged()
{
    const QList<Theme *> instances = s_instances;
    for (Theme *t : instances) {
        Q_EMIT t->currentChanged();
        Q_EMIT t->lightChanged();
        Q_EMIT t->darkChanged();
    }
}

Theme *Theme::instance()
{
    ensureStore();
    if (s_instances.isEmpty())
        new Theme;
    return s_instances.first();
}

QObject *Theme::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)
    ensureStore();
    return new Theme;
}

Theme::Mode Theme::mode() const
{
    return s_store()->mode;
}

SemiThemeValues *Theme::light() const
{
    ensureStore();
    return s_store()->light;
}

SemiThemeValues *Theme::dark() const
{
    ensureStore();
    return s_store()->dark;
}

SemiThemeValues *Theme::current() const
{
    ensureStore();
    TokenStore *store = s_store();
    return store->mode == Dark ? store->dark : store->light;
}

void Theme::setMode(Mode mode)
{
    TokenStore *store = s_store();
    if (store->mode == mode)
        return;

    store->mode = mode;
    ensureStore();
    notifyTokensChanged();

    const QList<Theme *> instances = s_instances;
    for (Theme *t : instances)
        Q_EMIT t->modeChanged();
}

void Theme::customize(const QVariantMap &patch)
{
    ensureStore();
    // 两份令牌各自 emit changed，notifyTokensChanged 会由连接统一广播
    applyPatch(s_store()->light, patch);
    applyPatch(s_store()->dark, patch);
}

void Theme::customizeLight(const QVariantMap &patch)
{
    ensureStore();
    applyPatch(s_store()->light, patch);
}

void Theme::customizeDark(const QVariantMap &patch)
{
    ensureStore();
    applyPatch(s_store()->dark, patch);
}

void Theme::reset()
{
    ensureStore();
    s_store()->light->reset();
    s_store()->dark->reset();
}

void Theme::applyPatch(SemiThemeValues *values, const QVariantMap &patch)
{
    const QMetaObject *metaObject = values->metaObject();
    const QMetaType colorListType = QMetaType::fromType<QList<QColor>>();

    for (auto it = patch.constBegin(); it != patch.constEnd(); ++it) {
        const int index = metaObject->indexOfProperty(it.key().toUtf8().constData());
        if (index < 0) {
            qWarning("Theme: 未知的令牌 \"%s\"（字段名见 src/SemiThemeValues.h，"
                     "或 gallery 的 Tokens 页）",
                     qUtf8Printable(it.key()));
            continue;
        }

        const QMetaProperty prop = metaObject->property(index);
        QVariant value = it.value();

        // QML 传进来的是 JS 数组，色阶属性要的是 QList<QColor>
        if (prop.metaType() == colorListType && value.metaType() != colorListType) {
            const QVariantList list = value.toList();
            QList<QColor> colors;
            colors.reserve(list.size());
            for (const QVariant &item : list)
                colors.append(item.value<QColor>());
            value = QVariant::fromValue(colors);
        }

        if (!prop.write(values, value))
            qWarning("Theme: 令牌 \"%s\" 赋值失败（类型不匹配）", qUtf8Printable(it.key()));
    }
}

} // namespace semi
