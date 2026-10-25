#pragma once

#include <QJSEngine>
#include <QList>
#include <QObject>
#include <QQmlEngine>
#include <QVariantMap>

#include "SemiThemeValues.h"

namespace semi {

// 主题入口。持有明暗两套令牌，并对外提供增量覆盖用的 customize() 接口。
//
//   import Semi
//
//   Component.onCompleted: Theme.customize({ colorPrimary: "#7c3aed" })
//   // 精细控制：Theme.dark.colorPrimary = "#9d7bff"
//   // 还原：Theme.reset()
//
// 组件读 Theme.current.xxx 并把 tokens 传给 Appearance：
//     color: Appearance.buttonBackground(Theme.current, tone, variant, state)
// 这样绑定才既依赖「当前是哪一套」又依赖「令牌变了没有」。
//
// 令牌数据存在一个 Q_GLOBAL_STATIC 管理的 TokenStore 里（见 .cpp），因此：
//   - 进程唯一、延迟初始化、程序退出时自动销毁
//   - QML 侧的 Theme 实例与 C++ 侧看到的永远是同一份数据
// 这一点不能省：QML 的 Theme 实例并不等于 C++ 侧创建的那个（见 Theme::create 的说明），
// 两边要是各持一份数据，customize 与切模式就会对不上。
class Theme : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(Mode mode READ mode WRITE setMode NOTIFY modeChanged FINAL)
    Q_PROPERTY(semi::SemiThemeValues *light READ light NOTIFY lightChanged FINAL)
    Q_PROPERTY(semi::SemiThemeValues *dark READ dark NOTIFY darkChanged FINAL)
    Q_PROPERTY(semi::SemiThemeValues *current READ current NOTIFY currentChanged FINAL)

public:
    enum Mode {
        Light,
        Dark,
    };
    Q_ENUM(Mode)

    explicit Theme(QObject *parent = nullptr);
    ~Theme() override;

    // QML 引擎要求单例提供一个 create 工厂。注意实践中引擎不一定会调用它
    // （这个 Qt 版本实测没调用，于是 QML 自己 new 了一个 Theme），
    // 所以主题状态绝不能只挂在实例上 —— 必须走 TokenStore。
    static QObject *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    // C++ 侧取一个 Theme 实例（没有就建一个）
    static Theme *instance();

    Mode mode() const;
    void setMode(Mode mode);

    SemiThemeValues *light() const;
    SemiThemeValues *dark() const;
    SemiThemeValues *current() const;

    // 增量覆盖：只写想改的令牌，其余保持默认。两份（明暗）一起改。
    Q_INVOKABLE void customize(const QVariantMap &patch);
    // 把补丁只应用到其中一套
    Q_INVOKABLE void customizeLight(const QVariantMap &patch);
    Q_INVOKABLE void customizeDark(const QVariantMap &patch);
    // 还原成 Semi 默认主题
    Q_INVOKABLE void reset();

Q_SIGNALS:
    void modeChanged();
    void lightChanged();
    void darkChanged();
    void currentChanged();

private:
    // 懒建 TokenStore 里的两套令牌
    static void ensureStore();
    // 向所有 Theme 实例广播「令牌变了」
    static void notifyTokensChanged();
    static void applyPatch(SemiThemeValues *values, const QVariantMap &patch);

    static QList<Theme *> s_instances;
};

} // namespace semi
