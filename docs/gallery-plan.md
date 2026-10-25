# Gallery 复刻计划

用 QML 复刻 Semi Design 官网的组件文档站（`https://semi.design/zh-CN/...`），
作为本库的组件 gallery。**不是 HTML 网页**，是一个 Qt Quick 应用 ——
组件在里面是真的跑起来的，能点、能悬停、能展开。

> 实现进度见 [`gallery-progress.md`](./gallery-progress.md)。

## 1. 目标

- 界面照官网搭：左侧边栏 + 面包屑 + 标题区 + Tab + 内容区
- 每个组件一页，页面里放该组件的**真实 QML 实例**（不是截图）
- 说明文字与 API 表从官网的 markdown 解析而来，不手写
- 顺带把 95 个组件在真实组合下的表现过一遍

## 2. 技术选型

| 项 | 选择 | 理由 |
| --- | --- | --- |
| 形态 | Qt Quick 应用 | 组件能真跑；与项目同栈 |
| 位置 | 扩展 `examples/gallery/` | 那就是 gallery 的位置 |
| 文字内容 | Python 脚本解析 markdown → JSON | 923 个小节的说明文字不可能手写 |
| demo | 手写 QML | 无法数据化，只能一页页写 |
| 路由 | `Loader` 按当前路径加载页面 | 简单够用 |
| 主题 | 已有的 `Theme` 单例 | 明暗切换免费 |

## 3. 目录结构

```
examples/gallery/
  main.qml                  窗口 + 全局状态（当前页面 / 明暗 / 侧边栏折叠）
  GalleryShell.qml          外壳：侧边栏 + 面包屑 + 内容区
  GallerySidebar.qml        左侧导航（Navigation + NavigationSub）
  GallerySection.qml        内容小节模板（标题 + 说明 + demo 区）
  GalleryApiTable.qml       API 参考表
  GalleryPlaceholder.qml    未实现页面的占位
  pages/
    ButtonPage.qml
    TagPage.qml
    …（69 个）
  data/
    docs.json               说明文字 + 小节结构 + API 表（脚本产出）
    tokens.json             令牌数据（脚本产出）
  build/
    parse-docs.py           content/**/index.md → docs.json
    gen-tokens.py           令牌 → tokens.json
  Main.qml                  原有的 QML 预览应用，保留不动
```

## 4. 页面骨架

```
① 左侧边栏     分组可折叠 + 每项图标 + New 标签 + 当前项高亮
② 面包屑       基础 · Button
③ 标题区       大标题「按钮」+ 简介
④ 内容区       右侧页内锚点 + 各小节(标题 + 说明 + 组件实例)
   末尾        API 参考表（官网再往后的 Accessibility / 文案规范 / FAQ 三章不渲染）
```

**不做**：顶部横幅、顶部导航栏（按你的要求去掉）、标题区下面那排「API 文档 / 设计文档」Tab 与它的通栏分隔线（只有一份文档，简介之后直接进内容）。

## 5. 数据来源

官网内容在 `content/<分类>/<组件>/index.md`，结构规整：

- frontmatter：`title` / `category` / `brief`
- `### 小节标题` + 说明段落
- ```` ```jsx live ```` 代码块（demo，我们不用）
- `## API 参考` 下的表格
- `## Accessibility` / `## 文案规范` / `## FAQ`（解析进 `docs.json` 的 `guidelines`，但站点不渲染这三章）

脚本解析出 `docs.json`：

```json
{
  "categories": [
    {
      "key": "basic", "name": "基础",
      "components": [
        {
          "dir": "button", "title": "Button 按钮", "brief": "用户使用按钮来触发一个操作或者进行跳转。",
          "sections": [
            { "title": "按钮类型", "description": "按钮支持以下类型：…" },
            { "title": "按钮主题", "description": "…" }
          ],
          "api": [ { "name": "theme", "desc": "按钮主题", "type": "string", "default": "light" } ]
        }
      ]
    }
  ]
}
```

侧边栏结构、路由、面包屑都从这份 JSON 来，不手工维护组件清单。

## 6. 组件页怎么写

每个页面是一个 QML 文件，用统一的模板：

```qml
// pages/ButtonPage.qml
GalleryPage {
    // 标题、简介、API 表由 GalleryPage 从 docs.json 取

    GallerySection {
        title: "按钮类型"                       // 与官网小节同名
        description: "按钮支持以下类型："        // 也从 JSON 取

        Row {
            spacing: 8
            Button { text: "主要按钮" }
            Button { text: "次要按钮"; tone: Enums.Secondary }
            Button { text: "第三按钮"; tone: Enums.Tertiary }
            Button { text: "警告按钮"; tone: Enums.Warning }
            Button { text: "危险按钮"; tone: Enums.Danger }
        }
    }

    GallerySection {
        title: "尺寸"
        description: "默认定义了三种尺寸。"
        Row {
            spacing: 8
            Button { text: "大尺寸"; size: Enums.Large }
            Button { text: "默认尺寸" }
            Button { text: "小尺寸"; size: Enums.Small }
        }
    }
}
```

`GallerySection` 负责标题、说明文字的排版和 demo 区的留白；
`GalleryPage` 负责从 JSON 取当前页的简介、小节说明、API 表。

## 7. 规模评估

脚本统计出来的真实数字：

| 项 | 数量 |
| --- | --- |
| 可做组件页 | **69** |
| 官网小节总数 | **923** |
| 官网 demo 总数 | **约 700** |

**923 个小节不可能全做。** 按每个小节 15~40 行 QML 算，全做是 2 万行以上，
比现有 95 个组件的总量还多，而且大部分是重复的变体（官网为了讲全，
同一个能力会拆成好几个小节）。

**所以采取「核心小节」策略**：每页只做 **4~6 个最能说明该组件的小节**，
覆盖「基本用法 / 主要变体 / 常见组合 / 禁用态」这几类。官网的小节标题和
说明文字仍从 JSON 读（所以文字部分是完整的），只是 demo 区挑核心的做。

按每页 5 个小节算，总量约 **350 个 demo**，仍然是多轮工程。

## 8. 覆盖范围与跳过清单

**跳过**（侧边栏里灰掉并标注「未实现」）：

| 分类 | 组件 |
| --- | --- |
| AI 组件 | AIChatDialogue、AIChatInput、AIComponent、Sidebar |
| Plus 组件 | Chat、CodeHighlight、Markdown 渲染器、JsonViewer、Lottie、AudioPlayer、VideoPlayer |
| 基础 | （无 —— Grid 栅格 + Layout 布局 2026-10-23 决定不复刻、整族删除；Resizable 伸缩框 2026-10-25 决定不做，组件 / gallery 页 / 用例整批删除，docs.json 条目一并去掉、不留灰条） |
| 展示类 | （无 —— Cropper 已于 2026-10-20 补做；Semi DV 数据可视化 2026-10-24 决定不做、docs.json 条目整条删除，连灰条都不留） |
| 反馈类 | Feedback |
| 其他 | ConfigProvider、LocaleProvider |
| 非组件文档 | 开始 / 设计协作 / 体验增强 / 生态与帮助 四组全部 |

## 9. 组件清单（69 个）

**基础（10）** Button、Divider、FloatButton、Grid、Icon、Layout、Resizable、
Space、**Tokens（特殊页）**、Typography

**输入类（19）** AutoComplete、Cascader、Checkbox、ColorPicker、DatePicker、
Form、Input、InputNumber、PinCode、Radio、Rating、Select、Slider、Switch、
TagInput、TimePicker、Transfer、TreeSelect、Upload

**导航类（8）** Anchor、BackTop、Breadcrumb、Navigation、Pagination、
Steps、Tabs、Tree

**展示类（23）** Avatar、Badge、Calendar、Card、Carousel、Collapse、
Collapsible、Descriptions、Dropdown、Empty、Highlight、Image、List、Modal、
OverflowList、Popover、ScrollList、SideSheet、Table、Tag、Timeline、
Tooltip、UserGuide

**反馈类（7）** Banner、Notification、Popconfirm、Progress、Skeleton、
Spin、Toast

**Plus（2）** DragMove、HotKeys

**Tokens 页**单独处理：它展示的是令牌而不是组件，用 `tokens.json` 渲染
色板、功能色、字体、圆角、阴影、尺寸、间距、z-index、动画各分区。

## 10. 分期计划

| 轮次 | 内容 | 产出 |
| --- | --- | --- |
| **第 1 轮** | 外壳打通：`parse-docs.py` + `docs.json` + `GalleryShell` + `GallerySidebar` + `GallerySection` + `GalleryPage` + 路由 + **Tokens 页** + **首批 5 页**（Button / Tag / Badge / Progress / Divider） | 能跑起来，侧边栏能点，Button 页里按钮是活的 |
| 第 2~4 轮 | 基础 + 导航类 + 反馈类（25 页），每轮 8~9 页 | |
| 第 5~7 轮 | 输入类（19 页），每轮 6~7 页 | |
| 第 8~10 轮 | 展示类（23 页），每轮 7~8 页 | |
| **第 11 轮** | 收尾：侧边栏搜索、暗色打磨、未实现页占位、README | |

第 1 轮做完先看效果，风格确认后再往下铺。

## 11. 风险与注意

1. **`Layout` 命名冲突的前车之鉴**：新加的组件若与 QtQuick 内置类型或
   QtQuick.Layouts 的附加属性作用域同名，会砸掉调用方代码。gallery 里的
   辅助组件统一用 `Gallery*` 前缀，避免撞名。
2. **弹层类组件（Modal / Popover / Tooltip / Toast / Notification）** 在
   文档页里会盖住内容，需要一个「只在 demo 区内展示」的模式，不能真的
   弹到窗口层级。第 1 轮之后单独处理这批。
3. **`Loader` 加载页面时**要 `asynchronous: false`，否则快速切换页面会
   出现旧内容残留。
4. **API 表是 React 的 props**，和 QML 属性名不完全对应。页面顶部会标注
   「以下为 React 版 API」，不假装它等同于我们的属性。
5. **代码块暂不做**（按你的要求留空）。将来要做的话，得自己写一个
   简易高亮器，不引第三方库。
6. **每个组件页手写 QML 是主要工作量**，也是唯一不能自动化的部分。

## 12. 验证方式

- 每轮做完跑 `ctest` 确认没破坏现有组件
- `all_qmllint` 保持 0 警告
- 手工跑 gallery 逐页看：侧边栏跳转、每页的组件实例是否正常渲染、
  明暗切换、Tokens 页色板
- 截图复核关键页面（沿用现有的 `shotapp` 工具）
