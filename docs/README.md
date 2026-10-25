# Semi（开发文档）

Semi Design 的 QML 复刻。Qt 6.5+。

> 这份是**开发者视角**的 README：构建、令牌体系、目录约定、已知坑。
> 想直接用组件的话看仓库根目录的 [README.md](../README.md)（用户视角：接入、示例、组件清单）。

> 当前做到哪一步、下一步做什么、有哪些坑，见 [PROGRESS.md](./PROGRESS.md)。

## 环境要求

Qt 6.5 或更高（含 Qt Quick、Qt Quick Test）、CMake 3.21+、Ninja。

## 构建与测试

```sh
cmake --preset debug
cmake --build build/debug
ctest --preset debug
cmake --build build/debug --target all_qmllint    # QML 静态检查
```

| 目标 | 说明 |
| --- | --- |
| `semi` | QML 模块 `Semi`，产物 `build/debug/src/libsemi.dylib` |
| `semi-gallery` | 组件预览，`build/debug/examples/gallery/semi-gallery` |
| `tst_semi` | 测试入口，用 `-input <file.qml>` 指定单个用例 |

## 主题

令牌层共 **383 个**，由 `scripts/gen-theme-tokens.py` 从 Semi 源码提取生成：

```sh
python3 scripts/gen-theme-tokens.py            # 默认从 ~/Documents/Code/Html/semi-design 读
python3 scripts/gen-theme-tokens.py --semi-root /path/to/semi-design
```

它会重新生成 `src/SemiThemeValues.h/.cpp`，并跑 15 项自检（色板值、暗色反转、派生关系、各类令牌计数）。**不要手改这两个 C++ 文件。**

### 在 QML 里用

组件一律读 `Theme.current.xxx`，**不要缓存色值** —— 令牌一变绑定会自动重新求值。

```qml
import Semi

Rectangle {
    color: Theme.current.colorBg0
    radius: Theme.current.radiusSmall
}
```

### 定制

`customize()` 只覆盖写出来的令牌，其余继承 Semi 默认值；明暗两套一起改。

```qml
Component.onCompleted: Theme.customize({
    colorPrimary: "#7c3aed",                       // 换品牌色
    radiusSmall: 12, radiusLarge: 18               // 改圆角
})

Theme.customizeLight({ /* 只改浅色 */ })
Theme.dark.colorPrimary = "#9d7bff"                // 精细控制
Theme.reset()                                      // 还原
Theme.mode = Theme.Dark                            // 切明暗
```

字段名见 `src/SemiThemeValues.h`，或跑 gallery 看 **Tokens 设计变量** 页（383 项完整清单，含明暗两套色值、搜索与点击复制）。

### 令牌是怎么组织的

三层引用，和 Semi 的 CSS 变量体系一一对应：

```
色阶（16 色系 + AI 紫，各 10 级）
  └─> 语义色（colorPrimary / colorDanger / …）
        └─> 组件
```

**语义色默认由色阶派生，不存死值**：`colorPrimary` 取 `blue[5]`，`colorPrimaryHover` 取 `blue[6]`。所以改一整条色阶，底下引用它的语义色会全部跟上：

```qml
const blue = Theme.light.blue.slice()
blue[5] = "#7c3aed"
Theme.light.blue = blue          // colorPrimary 随即变成 #7c3aed
```

单独设过值的语义色优先，不再参与派生（`Theme.reset()` 可清除）。

注意 **暗色模式的色阶方向是整体反转的**（`grey-0` 浅色是 `#f9f9f9`、深色是 `#1c1f23`），测试里锁住了这条性质，别按"越深越重"的直觉去改。

## 目录结构

```
src/
  SemiThemeValues.h/.cpp   生成物：383 个令牌属性 + 派生逻辑
  Theme.h/.cpp             单例：light / dark / current / customize / reset
  Button.qml Card.qml Switch.qml
examples/gallery/          预览应用（含主题定制演示）
tests/                     Qt Quick Test
scripts/gen-theme-tokens.py
docs/                      计划与令牌清单（本地起 http.server 预览）
```

## 组件

```qml
Button {
    text: "确定"
    tone: Enums.Primary       // Primary / Secondary / Tertiary / Warning / Danger / Info / Success
    variant: Enums.Solid      // Solid / Light / Outline / Borderless
    size: Enums.Default       // Small / Default / Large
    onClicked: window.count++
}
```

形态 × 色调 × 状态（normal / hovered / pressed / disabled）的色值解析集中在 `Appearance`，
对应 Semi 的 `$color-button-*` 展开；尺寸与焦点环也在那里。组件本身不写外观 if-else。

**外观函数必须显式接收令牌**：

```qml
color: Appearance.buttonBackground(Theme.current, tone, variant, controlState)
```

`Theme.current` 不能省。QML 只追踪绑定表达式里**直接读到**的属性，C++ 函数内部去读全局单例
的话，主题一变这个绑定不会重新求值 —— 颜色卡在旧值上，而且**没有任何报错**。这是踩过的坑，
`tests/tst_appearance.qml` 里 `test_buttonFollowsModeChange` / `test_buttonFollowsCustomize`
就是为此加的回归。

## 新增组件

1. 在 `src/` 下写 `Foo.qml`，登记到 `src/CMakeLists.txt` 的 `QML_FILES`。
2. Gallery 里加一段展示，`tests/` 下补 `tst_foo.qml` 并登记到 `SEMI_TEST_FILES`。
3. 视觉参数统一取自 `Theme.current`，不在组件里硬编码颜色与尺寸。

## 已知坑

**Qt Quick Test 的项可见性**。`TestCase` 根项读到的 `effectiveVisible` 在窗口 show 之后不会立即刷新，此时测试项全部不可见，合成鼠标事件会被静默丢弃（断言失败但无报错）。每个测试的 `init()` 里需要 `testCase.visible = true` 重新置位。

**QML 模块的安装导出**。`qt_add_qml_module` 用 `STATIC` 会生成不在导出集里的 `_resources_N` 目标导致 `install(EXPORT)` 失败，故本模块用 `SHARED`；导出名需 `set_target_properties(semi PROPERTIES EXPORT_NAME Semi)` 才是 `Semi::Semi`。

**Qt 6.11 起 `qt_add_qml_module` 不再负责安装**，必须自己写 `install(TARGETS)`，qmldir 与 .qmltypes 路径用 `qt_query_qml_module(... QMLDIR ... TYPEINFO ...)` 取。

**`qqmlintegration.h` 的路径**是 `<QtQmlIntegration/qqmlintegration.h>`，写成 `QtQml/` 在 framework 布局的 Qt 下找不到。
