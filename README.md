# Semi.qml

[Semi Design](https://semi.design) 的 Qt Quick 移植：同一套设计令牌、同一套 prop 名，把 Semi 的界面直接搬到 Qt 应用里。

- **60+ 组件**，逐个按官方 scss / tsx 核对行为（不是"长得像"，是连缺省值、怪癖、动画时长都抄）
- **383 个设计令牌**，明暗双主题，语义色由色阶派生 —— 改一个 `blue[5]`，`colorPrimary` 跟着变
- **Qt 6.5+**，除 Qt Quick 外无第三方依赖（裁切结果的像素管线走自带的 `QImage` / `QPainter`）

## 组件

gallery 的每一页对应一个组件（`Tokens` 那页是设计变量浏览器，不是组件）：

| 类别 | 组件 |
| --- | --- |
| 基础 | Button · Divider · Icon · Skeleton · Space · Title |
| 数据录入 | AutoComplete · Cascader · Checkbox · ColorPicker · DatePicker · Form · Input · InputNumber · PinCode · Radio · Rating · Select · Slider · Spin · Steps · Switch · TagInput · TimePicker · Transfer · Upload |
| 数据展示 | Avatar · Badge · Calendar · Card · Carousel · Collapse · Collapsible · Cropper · Descriptions · DragMove · Empty · Highlight · ImageView · List · OverflowList · Progress · ScrollList · Table · Tag · Timeline · Tree · TreeSelect |
| 导航 | Anchor · Breadcrumb · Dropdown · FloatButton · Navigation · Pagination · Tabs |
| 反馈与弹层 | BackTop · Banner · Feedback · HotKeys · Modal · Notification · Popconfirm · Popover · SideSheet · Toast · Tooltip · UserGuide |

## 快速开始

### 构建

Qt 6.5+（含 Qt Quick 与 Qt Quick Test）、CMake 3.21+、Ninja。

```sh
cmake --preset debug
cmake --build build/debug
```

产物：

| 目标 | 说明 |
| --- | --- |
| `semi` | QML 模块 `Semi`，`build/debug/src/libsemi.dylib` |
| `semi-gallery` | 组件预览应用，`build/debug/examples/gallery/semi-gallery` |
| `tst_semi` | 测试入口，`-input <file.qml>` 指定单个用例 |

装进系统（QML 插件与 `qmldir` 落到 Qt 的 QML 导入目录，另装一份 `find_package` 用的 CMake 配置）：

```sh
cmake --install build/debug --prefix /your/prefix
```

### 在 QML 里用

```qml
import Semi

Button {
    text: "确定"
    tone: Enums.Primary       // Primary / Secondary / Tertiary / Warning / Danger / Info / Success
    variant: Enums.Solid      // Solid / Light / Outline / Borderless
    size: Enums.Default       // Small / Default / Large
    onClicked: console.log("clicked")
}
```

### 在 CMake 工程里用

```cmake
find_package(Semi REQUIRED)
target_link_libraries(myapp PRIVATE Semi::Semi)
```

## 主题

组件一律读 `Theme.current.xxx`；**不要把色值缓存进 `var`** —— 令牌一改，绑定会自动重新求值，缓存的那份不会。

```qml
Theme.customize({
    colorPrimary: "#7c3aed",                     // 换品牌色
    radiusSmall: 12, radiusLarge: 18             // 改圆角
})

Theme.customizeLight({ /* 只改浅色 */ })
Theme.mode = Theme.Dark                          // 明暗切换
Theme.reset()                                    // 还原
```

383 项令牌（含明暗两套色值）在 gallery 的 **Tokens 设计变量** 页可以搜索、点击复制；组织方式与派生规则见 [docs/README.md](docs/README.md#令牌是怎么组织的)。

## 预览与文档

```sh
build/debug/examples/gallery/semi-gallery          # 组件预览：68 页，含主题定制演示
python3 -m http.server --directory docs            # 本地文档站（docs/index.html）
```

## 与官方的差异

本项目的目标是**逐行对齐上游 scss / tsx**，包括上游的 bug（只记录、不擅自"修好"）。每一轮的对齐记录、官方怪癖清单、验证口径都写在：

- [docs/PROGRESS.md](docs/PROGRESS.md) —— 进度、逐轮差异、已知坑（141 条）
- [docs/gallery-progress.md](docs/gallery-progress.md) —— 68 页 gallery 的复刻进度

## 开发

- 开发者视角的 README（构建细节、令牌体系、新增组件的约定）：[docs/README.md](docs/README.md)
- 全量测试（offscreen，约 4 分钟）：`python3 scripts/run-tests.py -j 4`
- QML 静态检查：`cmake --build build/debug --target all_qmllint`
- 令牌从 Semi 源码重新生成：`python3 scripts/gen-theme-tokens.py --semi-root /path/to/semi-design`（不要手改 `src/SemiThemeValues.*`）
