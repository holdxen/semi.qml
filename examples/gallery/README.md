# Semi QML Gallery

用 QML 复刻 [Semi Design 官网](https://semi.design/zh-CN/) 的组件文档站，作为本库的组件预览。
**不是网页** —— 每个组件在页面里都是真实跑起来的 QML 实例，能点、能悬停、能展开。

计划见 [`docs/gallery-plan.md`](../../docs/gallery-plan.md)，逐轮进度见
[`docs/gallery-progress.md`](../../docs/gallery-progress.md)。

## 构建与运行

```sh
cmake --preset debug
cmake --build build/debug
./build/debug/examples/gallery/semi-gallery
```

## 命令行参数

截图与逐页检查用的，正常浏览不需要：

| 参数 | 说明 |
| --- | --- |
| `--page <dir>` | 直接打开某个组件页。取值是 `data/docs.json` 里的 `dir`，**忽略大小写** |
| `--scroll <px>` | 把内容区滚到指定位置再抓图；超出内容高度会自动夹到底部 |
| `--search <kw>` | 预置搜索框内容（侧边栏与 Tokens 页的过滤框一起） |
| `--dark` | 以深色主题启动 |
| `--shot <file>` | 抓一张图就退出 |

```sh
# 抓 Table 页靠下的小节，深色
./build/debug/examples/gallery/semi-gallery --page table --scroll 1200 --dark --shot /tmp/table.png
```

弹层在 `--shot` 下默认不打开，抓不到外观 —— 各弹层页末尾有一句
`if (Qt.application.arguments.indexOf("--shot") >= 0) xxx.open();` 把第一个弹层打开，
正常浏览时这段不生效。

## 数据从哪来

页面里的说明文字、API 表、页尾章节都是从 Semi 官网的 markdown 解析出来的，不手写：

| 脚本 | 输入 | 输出 |
| --- | --- | --- |
| `build/parse-docs.py` | `semi-design/content/**/index.md` | `data/docs.json`：组件清单、简介、各小节说明、API 表、页尾章节 |
| `build/gen-tokens.py` | `semi-design/packages/semi-theme-default/scss` | `data/tokens.json`：色板、语义色、尺寸、阴影、动效 |

```sh
python3 build/parse-docs.py [--content <semi-design/content>] [--out <docs.json>]
python3 build/gen-tokens.py  [--scss <semi-theme-default/scss>] [--out <tokens.json>]
```

改了数据要重跑，然后重新构建（JSON 是编进 qrc 的）。

> 这两个脚本与 `scripts/gen-theme-tokens.py`（产出 C++ 令牌层）各解析一份 scss，
> 是两条独立管道。**改了主题令牌两边都要跑。**

## 目录结构

```
examples/gallery/
  main.cpp                 读 JSON 注入 + 命令行参数
  GalleryMain.qml          窗口 + 全局状态
  GalleryShell.qml         外壳：侧边栏 + 内容区 + 右侧页内锚点
  GallerySidebar.qml       左侧导航（搜索、分组折叠、跳过项灰显、明暗开关）
  GallerySection.qml       内容小节模板（标题 + 说明 + demo 区）
  GalleryGuideline.qml     页尾章节（Accessibility / 文案规范 / FAQ）—— 站点已不渲染，文件留着
  GalleryApiTable.qml      API 参考表
  GalleryPlaceholder.qml   跳过组件的占位
  *Page.qml                组件页（69 个，放在模块根目录）
  data/docs.json           说明文字 + API 表 + 页尾章节（脚本产出）
  data/tokens.json         令牌数据（脚本产出）
  build/parse-docs.py      content/**/index.md → docs.json
  build/gen-tokens.py      scss → tokens.json
  Main.qml                 原有的 QML 预览应用，保留不动
```

**组件页必须放在模块根目录**，不能建子目录：子目录里的 QML 文件在同模块内的类型
可见性不可靠，页面里用 `GallerySection` 会报 `is not a type`。

另外注意 macOS 文件系统**不区分大小写**，新增文件前先确认没有同名不同大小写的
（`Main.qml` 就是这么差点被 `main.qml` 覆盖的）。

## 加一个组件页

1. 写 `FooPage.qml`：根是 `Item`，里面一个 `Column`，放若干个 `GallerySection`。
   小节标题要**与官网的 `###` 标题逐字一致** —— `GallerySection` 拿标题去 `docs.json`
   里查说明文字，对不上就只显示标题。
2. 页面文件加 `pragma ComponentBehavior: Bound`（页面里大量用 `Repeater` 的委托
   访问外层属性，不加会报 `Unqualified access`）。
3. 页面不用登记到 `CMakeLists.txt`，`*Page.qml` 是 GLOB 进来的。

骨架照抄现成页面：

```qml
pragma ComponentBehavior: Bound

import QtQuick
import Semi

Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基本用法"

            Row {
                spacing: 8
                Button { text: "主要按钮" }
            }
        }
    }
}
```

**先把骨架搭好再填内容**。第 5~7 轮连续三页在嵌套缩进上返工，都是边想边写导致的；
第 8 轮改成先搭骨架，一次过。写完立刻构建 —— 编译器报行号比人眼数括号快。

## 约定与坑

**`GallerySection` 的 demo 区是 `Column`（间距 12）**，一小节里写两个子项会自动竖排。
不要再自己写 `topPadding` 去补间距，也不要在直接子项上用 `anchors`（Column 会给子项设 x/y）。

**侧边栏的跳过项**在 `docs.json` 里带 `skipped: true`，会灰显、标「未实现」、点不动，
页面走 `GalleryPlaceholder`。

**页内锚点是靠标记找出来的**：`GallerySection` 把自己标成 `isGallerySection`，
外壳递归遍历页面找它们（`Gallery` 里的 `collectSections`）。隐藏的小节不进锚点栏。
这套「标记 + 外壳遍历」的写法与库里 `Navigation` 用 `isNavigationSub` 认子项是同一个套路。

**改了页面结构后锚点位置会重排**，靠 `Qt.callLater` 在页面高度变化时合并成一次重算 ——
页面高度在一帧里会连着变好几次，不用 callLater 会算出一堆中间值。

**不要把演示用的实色写死**。组件一律读 `Theme.current.xxx`，页面里也只该出现
品牌色之外的演示数据色（比如 Avatar 的 `backgroundColor`）。
