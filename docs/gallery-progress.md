# Gallery 进度

用 QML 复刻 Semi 官网组件文档站的进度记录。计划见 [`gallery-plan.md`](./gallery-plan.md)。

- **项目**：`~/Documents/Code/Cpp/semi.qml`
- **源站**：`https://semi.design/zh-CN/...`
- **源内容**：`~/Documents/Code/Html/semi-design/content/`
- **产出位置**：`examples/gallery/`
- **最近更新**：2026-10-10（第 11 轮收尾完成，另补上计划书 §4 里从未实现的页内锚点与页尾章节）

## 总体进度

| 轮次 | 内容 | 状态 |
| --- | --- | --- |
| **第 1 轮** | 外壳打通 + Tokens 页 + 首批 5 页 | **完成** |
| **第 2~4 轮** | 基础 + 导航类 + 反馈类（25 页） | **完成** |
| **第 5~7 轮** | 输入类（19 页） | **完成** |
| **第 8 轮** | 展示类第一批 8 页 | **完成** |
| **第 9 轮** | 展示类：List / Popover / Tooltip / Modal / SideSheet / Dropdown / Image | **完成** |
| **第 10 轮** | 剩余：Table / Calendar / Carousel / UserGuide / OverflowList / ScrollList / DragMove / HotKeys | **完成** |
| **第 11 轮** | 收尾：侧边栏搜索 / 暗色打磨 / 未实现页占位 / 色值复制 / README | **完成** |
| **补做** | 计划书 §4 的「右侧页内锚点」与「页尾 Accessibility / 文案规范 / FAQ」 | **完成** |

**组件页：71 / 71**（侧边栏里列出的组件全部有页面）

规模参照（脚本从源内容统计）：

| 项 | 数量 |
| --- | --- |
| 可做页面 | 70 |
| 源站小节总数 | 726（只算「代码演示」章节内的小节） |
| 计划实做 demo | 约 350（每页 4~6 个核心小节） |

## 目录结构（已落地）

```
examples/gallery/
  README.md                跑法、命令行参数、数据管道、加页面步骤与约定
  main.cpp                 读 JSON 注入 + `--page` / `--scroll` / `--search` / `--dark` / `--shot`
  GalleryMain.qml          入口：窗口 + 全局状态
  GalleryShell.qml         外壳：侧边栏 + 内容区 + 右侧页内锚点 + 页尾章节
  GallerySidebar.qml       左侧边栏（搜索 / 分组 / 跳过项灰显 / 明暗开关）
  GallerySection.qml       小节模板（标题 + 说明 + demo 区）
  GalleryGuideline.qml     页尾章节（Accessibility / 文案规范 / FAQ）
  GalleryApiTable.qml      API 参考表
  GalleryPlaceholder.qml   跳过组件的占位
  ButtonPage.qml 等        组件页（69 个，放在模块根，不是子目录）
  TokensPage.qml           令牌页（小节与正则逐条照官网 content/basic/tokens/index.md）
  TokenColorBlock.qml      色板那一格色块（160×64、悬浮放大 + WCAG 徽标 + 点击复制）
  TokenTable.qml           令牌表（变量 / 默认值 / 用法 三列，本库 Table 渲染）
  TokenColor.js            WCAG 对比度与 Lab 色差（对账见 build/check-token-color.mjs）
  Main.qml                 原有的 QML 预览应用，保留不动
  data/docs.json           说明文字 + 小节结构 + API 表 + 页尾章节
                           （没有代码演示的页 —— tokens —— 小节文字收在 prose 里）
  data/tokens.json         形状照官网 designToken.json：global.global{light,dark}
                           + global.palette{light,dark} + global.normal + global.animation，
                           每行 { key, value, comment, category, raw } 再带端口自己的
                           accessor（复制用，如 blue[5]）与 color（解出来的可画色）
  data/img/*.png           演示用示例图（示例图必须入库，见「已知问题」6）
  build/parse-docs.py      content/**/index.md → docs.json（--merge-prose-only 只补 prose）
  build/gen-tokens.py      scss → tokens.json（自检含「accessor 必须在 SemiThemeValues 里」）
  build/check-token-color.mjs  拿 node 跑 chroma-js + wcag-color，与 TokenColor.js 对账
```

**跑法**：

```sh
cmake --build build/debug
./build/debug/examples/gallery/semi-gallery                    # 正常打开
./build/debug/examples/gallery/semi-gallery --page tag --shot /tmp/x.png   # 指定页并抓图
./build/debug/examples/gallery/semi-gallery --page list --scroll 1200 --shot /tmp/x.png
./build/debug/examples/gallery/semi-gallery --search pick --dark --shot /tmp/x.png
```

`--page` 的取值是 docs.json 里的 `dir`，**忽略大小写**（`dragmove` 和 `dragMove` 都行）。
`--scroll <px>` 把内容区滚到指定位置再抓图 —— 页面比一屏长，光看首屏验不了靠下的小节；
超出内容高度会自动夹到最底部。
`--search <kw>` 预置搜索框内容，侧边栏与 Tokens 页的过滤框一起走。
`--dark` 以深色主题启动。

数据改了要先跑 `build/parse-docs.py` 和 `build/gen-tokens.py`。

## 组件清单与状态

状态取值：`未开始` / `进行中` / `完成` / `跳过`。「小节」列是源站的小节数。

### 基础（10）

| 组件 | 源站小节 | 状态 | 实做小节 |
| --- | --- | --- | --- |
| Button | 12 | **完成** | 按钮类型（含「关于类型字体色值」）/ 按钮主题（浅色 / 深色 / 无背景 / 边框） / 尺寸 / 块级按钮 / 图标按钮（默认 / 禁用 / 复合类型 / 更改主题 / 更改图标位置） / 链接按钮 / 禁用状态 / 加载状态 / AI 风格 - 多彩按钮 / 按钮组合（尺寸 / 禁用 / 类型） / 分裂按钮组合（基础使用） |
| Divider | 3 | **完成**（3 节：如何引入 / 基本用法 / 包含内容，标题逐字取自官方 `content/basic/divider/index.md`；「基本用法」是官方那一条 demo 的四档同页并列（水平实线 / 水平虚线 / 垂直实线 / 垂直虚线，都带 `margin: 12px`），「包含内容」是官方那一条的四档并列（align 居左/居中/居右 + IconSemiLogo 节点档）。2026-10-23 按官方 `DividerProps` 整份重写：补 `dashed`（Canvas + setLineDash，QML Rectangle 无 border-style）、`align`（40px 定宽段 + 吃剩余）、`margin`（烘进 implicit 尺寸：水平吃上下、垂直吃左右，缺省 1px）、children 拆 `text`（字符串档，吃 `-inner-text` 的 8px 内边距 + 字重 600）与 `content`（Component 档，裸渲染）；撤掉可写的 `lineColor`（官方恒 --semi-color-border，收成只读）。**children 只在水平档渲染**（官方 index.tsx:63 丢弃垂直档内容，照抄不修）。虚线段长 3×线宽在 QML 层读不回、两边 grabImage 都不合成 Canvas ⇒ 像素断言登记为够不到，视觉由 gallery 截图兜底。见 PROGRESS.md 坑 124 |
| FloatButton | 11 | **完成** | 基本用法 / 尺寸 / 形状 / 悬浮按钮组 |
| Grid | — | **已删除（2026-10-23）** | 用户决定「semi 布局的组件我们不实现，全部删掉」⇒ GridRow/GridCol 整族删除（组件 / 本页 / 测试 / docs.json 条目），原4 节 demo 随组件一起消失，调用点迁 QML 原生 Row + 等分 Column（见 PROGRESS 坑 126） |
| Icon | 11 | **完成** | 基础使用 / 尺寸 / 颜色 / 旋转 |
| Layout | — | **已删除（2026-10-23）** | 同上：LayoutBox / LayoutSider / LayoutHeader / LayoutFooter / LayoutContent 整族删除，BannerPage 的三段布局演示迁 QML 原生 Column 竖排（见 PROGRESS 坑 126） |
| Resizable | — | **已删除（2026-10-25）** | 用户「删除 Resizable 组件」：`Resizable` / `ResizableGroup` / `ResizableItem` 三个组件、gallery 的 ResizablePage 与 `tst_p5d.qml`（19 函数 / 73 断言）整批删除，两处 CMakeLists 取消登记，docs.json 条目一并删掉（不留灰条）；Table 自己的 `resizable` 列宽功能与 SemiScrollBar 不受影响 |
| Space | 6 | **完成**（2026-10-23 按官方 `SpaceProps` 整份重写组件与页面：如何引入 / 基本用法 / 对齐方式 / 间距尺寸 / 间距方向 / 设置换行 —— 代码演示章 6 节全齐。旧页面只有 3 节且 wrap / align 只有 prop 没有布局；现在对齐四档在图上肉眼可分（盒恒 0、按钮 0/34/68/baseline 中部），设置换行与间距尺寸 array 档都按**官方演示栏宽 280**（主栏 800 × 40% 预览 − 20×2 内边距，考证见 PROGRESS 坑 125）钉宽 ⇒ 行分布 4+4+2 与官方逐行同形；间距尺寸的 Tabs 也按官方预览宽 280 摆、四格标签刚好放得下。顺带修掉 FormPage 五处 `Space { topPadding }`（Space 换 Item 根后非法、整页加载失败，迁成 Form 流里等高占位） | 如何引入 / 基本用法 / 对齐方式 / 间距尺寸 / 间距方向 / 设置换行 |
| Tokens | — | **完成** | 基础色 / AI 渐变色 / 功能色 / 尺寸与间距 |
| Typography | 14 | **完成** | 标题组件 / 文本组件 / 段落组件 / 文本大小 |

### 输入类（19）

| 组件 | 源站小节 | 状态 |
| --- | --- | --- |
| AutoComplete | 10 | **完成**（基本用法 / 自定义候选项渲染 / 远程搜索 / 尺寸 / 下拉菜单的位置 / 禁用 / 校验状态 / 自定义空内容，另加本库自有的严格模式） |
| Cascader | 27 | **完成**（基本用法 / 可搜索 / 尺寸 / 受控） |
| Checkbox | 16 | **完成**（基本用法含 `extra` / 禁用 / 声明式组 / 数组方式组 / 水平排列 / 受控 / 全选 / 卡片样式 / 纯卡片样式 / 配合 grid 布局） |
| ColorPicker | 7 | **完成**（基本用法：放在弹层 + 正常展示 / 滴管取色器 / 默认值 / 受控 / 顶部和底部渲染额外元素） |
| DatePicker | 21 | **完成**（基本使用 / 小尺寸 / 多个日期选择 / 日期与时间选择 / 日期范围选择 / 日期范围时间选择 / 内嵌输入框 / 同步切换双面板月份 / 切换面板日期的回调 / 周选择 / 年月选择 / 年月范围选择 / 确认日期时间选择 / 带有快捷方式的日期时间选择 / 渲染顶部底部额外区域 / 禁用日期选择 / 禁用部分日期或时间 / 自定义显示格式 / 自定义触发器 / 自定义日期显示内容 / 自定义日期格子渲染） |
| Form | 27 | **完成**（24 节：声明表单的多种写法 / 已支持的表单控件 / 值的绑定 / 表单布局 / 分组 / wrapperCol·labelCol / 隐藏 Label / 内嵌 Label / 导出 Label·ErrorMessage / Form.Slot / helpText·extraText / InputGroup / Modal 中的表单 / 初始值与规则 / 自定义校验（Form 级、Field 级）/ 手动触发校验 / 静默校验 / 表单联动 / 动态表单 / ArrayField / 自定义控件接管 / 如何访问 formState / 如何获取 formApi）。官方余下 3 节没落：`Hooks 的使用`、`HOC 的使用`（都依附 React 的组件树注入机制，QML 直接引用 `id`）、`ARIA`（DOM 上的 `aria-*`，本库组件还没接 `Accessible`）；「声明表单的多种写法」里的 render props、children fn、`component` 三种声明子节点的方式同样只在 demo 层面对不上 |
| Input | 23 | **完成**（18 节 demo：如何引入 / 基本 / 三种大小 / 不可用 / 前缀后缀 / 前置后置标签 / 带移除图标 / 密码模式 / 校验状态 / 受控组件 / 输入框组合 / 多行输入框 / 设置 TextArea 高度 / 行号 / Shift+Enter 换行 / 自动扩展 / 自定义计算字符串长度 / 输入法模式）。官方余下 5 个 `###` 是 `Input` / `TextArea` / `InputGroup` 三张 API 表与 `ARIA` / `键盘和焦点`，不进 demo |
| InputNumber | 10 | **完成**（7 节：基本输入框 / 隐藏步进器 / 尺寸 / 自定义显示格式与解析方式 / 纯数字输入框 / 货币展示 / 科学计数法显示）。官方「货币展示」的第一段 demo 要 `LocaleProvider` + `Select` 切语言，本库没有 i18n 上下文，改成手动传 `localeCode` + `currency` 的那一段 |
| PinCode | 5 | **完成**（5 节 demo：如何引入 / 基本使用 / 受控 / 限制验证码格式 / 手动聚焦失焦，按官网重写属性面，见 PROGRESS.md 坑 74） |
| Radio | 16 | **完成**（11 节 demo：如何引入 / 基本用法 / 带辅助文本 / 禁用 / 高级模式 / 单选组合 / 垂直排列 / 按钮样式 / 卡片样式 / 无 radio 的纯卡片样式 / 配置 options）。官方余下 5 个 `###` 是 `Radio` / `RadioGroup` 两张 API 表、`Methods`、`Accessibility`、`文案规范` 等，不进 demo |
| Rating | 9 | **完成**（7 节 demo：如何引入 / 基本用法 / 半星 / 只读 / 点击清除 / 文案展现 / 自定义，按官网重写属性面，见 PROGRESS.md 坑 73） |
| Select | 28 | **完成**（基本使用 / 数组 Option / 多选 / 不同尺寸） |
| Slider | 12 | **完成**（基本用法 / 带输入框的 / 自定义提示 / 带标签的 / 分段背景 / 受控组件 / 垂直 / 滑块带圆点） |
| Switch | 9 | **完成**（基本 / 尺寸 / 不可用 / 带文本 / 受控 / 加载中） |
| TagInput | 18 | **完成**（17 节 demo：基本演示 / 批量添加 / 批量删除 / 禁用 / 尺寸大小 / 不同校验状态样式 / 前缀 后缀 / 失焦后自动创建标签 / 过滤重复标签 / 输入限制 / 限制标签展示数量 / 标签受控 / 输入受控 / 回调 / 焦点管理 / 自定义标签渲染 / 拖拽排序；另有「如何引入」不进 demo。按官网重写属性面，见 PROGRESS.md 坑 79） |
| TimePicker | 12 | **完成**（11 节 demo，另有「如何引入」一节不进 demo：基础使用 / 无限滚动 / 受控组件 / 不同的 Format 格式 / 设置面板头部，底部 / 禁用时间选择 / 设置步长 / 12 小时制 / 时间范围 / Range 模式下分别禁用左右面板（disabledTime）/ 自定义触发器，按官网重写属性面，见 PROGRESS.md 坑 77） |
| Transfer | 14 | **完成**（13 节 demo：基本使用 / 分组 / 自定义筛选逻辑，自定义选项数据渲染 / 禁用 / 拖拽排序 / 左侧分页 / 左侧分页 + 受控页码 / 拖拽 + 自定义已选项渲染 / 自定义渲染面板头部信息 / 完全自定义渲染 / 完全自定义渲染 、 拖拽排序 / 树穿梭框 / 树穿梭框自定义头部显示叶子节点数量；另有「如何引入」不进 demo。按官网重写属性面，见 PROGRESS.md 坑 80） |
| TreeSelect | 24 | **完成**（19 节 demo：基本用法 / 多选 / 限制标签展示数量 / 可搜索的 / 远程搜索 / 搜索框位置 / Trigger 内多行换行（triggerTagWrap） / 尺寸大小 / 默认展开 / 禁用 / 严格禁用 / 受控 / 节点选中关系 / 开启搜索的展开受控 / 虚拟化 / 动态更新数据 / 异步加载数据 / 自定义 Trigger / 自定义渲染已选项，标题逐字取自 `data/docs.json`；另有「如何引入」与 `TreeSelect` / `TreeNodeData` / `Methods` / `ARIA` 四张 API 表不进 demo。按官网重写属性面，见 PROGRESS.md 坑 81；**2026-10-23 补上弹层里那棵树的展开/收起动画**（用户报「点击展开和关闭没有动画」）—— 官方 `NodeList` 把动画区间折进 `NodeCollapsible` 做 200ms 的 height + opacity 过渡，端口与 `Tree` 共用同一套机关（`TreeEngine.js` 的三个函数直接复用），并收进官方那两条 `motion` / `motionExpand`（缺省都 true，分工见 PROGRESS.md 坑 127）；小节数不变（官方 19 节没有单独的「动画」节，动画是每一节的缺省行为）。**2026-10-24**：弹层里行的悬浮底色/箭头变色改成按列表容器记下的指针位置判 —— 动画起手与收尾各有一次 Repeater 重建，重建后的行委托上的 `HoverHandler` 认不出已经在里面的指针，被点那一行会闪一帧（PROGRESS.md 坑 129） |
| Upload | 30 | **完成**（25 节 demo：如何引入 / 基本 / 文件名超长省略 / 添加提示文本 / 点击头像触发上传 / 自定义上传属性 / 上传文件类型 / 上传文件夹 / 一次选中多个文件 / 限制文件总数量 / 限制上传文件大小 / 自定义列表操作区 / 自定义文件列表标题 / 自定义预览逻辑 / 默认文件列表 / 受控组件 / 图片墙 / 图片墙放大预览 / 图片墙设置宽高 / 禁用 / 手动触发上传 / 拖拽上传 / 上传前自定义校验 / 上传后更新文件信息 / 自定义请求，标题逐字取自 `data/docs.json`）。官方余下那一节「图片裁切」（6 个 demo，靠 `crop` + 浏览器端图片编辑器）整节跳过 —— 本端口没有裁切面板；`Upload` / `FileItem` / `customRequest` 三张 API 表与 `ARIA` / `文案规范` / `FAQ` 不进 demo。按官方重写属性面，见 PROGRESS.md 坑 82 |

### 导航类（8）

| 组件 | 源站小节 | 状态 |
| --- | --- | --- |
| Anchor | 8 | **完成**（8 节：如何引入 / 基本示例 / 综合使用 / 尺寸 / 滑轨主题 / 动态展示 / 显示工具提示 / 工具提示位置，标题逐字取自 `data/docs.json`；官方余下两个 `###` 是 API 参考与设计变量，不进 demo）。2026-10-24 按官方 `AnchorProps` / `LinkProps` 整份重写组件与页面：旧页面用的 `target` / `selectedAnchor` / `anchorId` 与「`position` 当滑轨左右用」都是自造面（官方 `position` 是 Tooltip 位置），换成 `container`（Flickable）+ 声明式 `AnchorLink` 嵌套；「动态展示」那节演 `autoCollapse` 开/关两块同构嵌套（滚到 300 时只有当前链展开），「工具提示位置」那节是 `showTooltip` + `position: "right"` 的长标题条。见 PROGRESS.md 坑 133 |
| BackTop | 3 | **完成**（3 节：如何引入 / 基本用法 / 自定义样式，标题逐字取自 `data/docs.json`；官方余下两个 `###` 是 API 参考与设计变量，不进 demo）。2026-10-24 按官方 `BackTopProps` 整份重写组件与页面：旧页面用的 `size` / `iconName` 是官方没有的 prop（那颗按钮官方是 `<IconButton theme="light" icon={<IconChevronUp />} />`，32×32），自定义那一节的尺寸/底色/圆角在官方是塞进 `style` 的 ⇒ 端口换成 `content`（收 Component，官方 `children` 那档）+ `bottomMargin`（官方 `style.bottom: 100`）。两节都造一只 560×260 的容器把 `contentY` 预置到 700，这样缺省那颗（距底 50）与自定义那颗（距底 100）在同一屏里位置差一眼可见。见 PROGRESS.md 坑 132 |
| Breadcrumb | 11 | **完成**（8 节：如何引入 / 基本用法 / 带图标的 / 尺寸 / 自定义的分隔符 / 截断逻辑 / 自定义省略号区域 / 路由对象，标题逐字取自 `data/docs.json`；「截断逻辑」一节官方是同节两条 demo（五档 showTooltip + 七级折叠）⇒ 端口照摆，「自定义省略号区域」也是 default/popover + renderMore 两条同节。2026-10-24 按官方 `BreadcrumbProps` / `BreadcrumbItemProps` 整份重写：旧页面的 `items` / `clickable` 是自造面（官方没有这两条），换成声明式 `BreadcrumbItem` + `routes` 两档；官方「自定义的分隔符」那条 `<Breadcrumb size="small">` 是死 prop（BreadcrumbProps 里没有 size），端口不造、页面也不摆。见 PROGRESS.md 坑 131 |
| Navigation | 15 | **完成**（10 节：如何引入 / 基本使用 / 导航样式定义 / JSX 写法 / 配合 react-router 等路由组件 / 垂直与水平布局 / 展开收起箭头位置 / 导航缩进 / 非受控属性 / 受控属性，标题逐字取自官方 `content/navigation/navigation/index.md`；「配合 react-router」官方是 `<Link>` 外壳 demo ⇒ 端口没有路由，改用 link 语义的占位说明；「垂直与水平布局」官方那节是三条 demo（垂直 / 水平 / 水平加垂直）⇒ 端口摆垂直与水平两条，水平那条的 footer 官方是头像下拉）。2026-10-23 按官方 `NavProps` 整份重写（24 条 prop + 4 个回调，items/children 两档、折叠/水平浮层、三组受控三态全收），见 PROGRESS.md 坑 122 |
| Pagination | 11 | **完成**（10 节：如何引入 / 基本 / 禁用 / 总页数显示 / 指定当前页码 / 每页容量切换 / 快速跳转至某页 / 页码受控 / 预设每页容量可选值 / 迷你版本，标题逐字取自 `data/docs.json`；「基本」「指定当前页码」「每页容量切换」「快速跳转」「迷你版本」五节各是官方同节的多条 demo 同页并列，迷你版本一节把 `hoverShowPageSelect` / `disabled` / `showQuickJumper` / `hideOnSinglePage` 四档一并摆）。2026-10-22 按官方 `PaginationProps` 整份重写（旧端口那套 `current` / `pageCount` / `pageItems()` / `goTo()` 是自造面：官方没有钳位，翻页靠 `prevDisabled` / `nextDisabled` 挡；`showTotal` 缺省也不是 true），拆出 `PaginationRestList.qml` 装省略号浮层那张页码表，见 PROGRESS.md 坑 121 |
| Steps | 13 | **完成**（10 节：如何引入 / 默认步骤条（旧版）/ 简单步骤条（新版）/ 导航步骤条 / 迷你尺寸步骤条 / 处理进度 / 竖直方向的步骤条 / 指定步骤状态 / 自定义图标/状态 / onChange 回调，标题逐字取自 `data/docs.json`；「迷你尺寸」与「竖直方向」两节官方各有两条 demo，端口同页并列）。2026-10-22 按官方 `StepsProps` / `FillStepProps` 整份重写三档分派，见 PROGRESS.md 坑 119 |
| Tabs | 17 | **完成**（13 节：如何引入 / 基本用法 / 带图标的 / 更多选项收入 More 展示 / 垂直的标签栏 / 滚动折叠 / 自动溢出检测 / 禁用 / 标签栏内容扩展 / 标签栏二次封装 / 拖拽排序 / 动态更新 / 关闭，标题逐字取自 `data/docs.json`。「基本用法」是官方那四条 type demo 同页并列，「更多选项」「滚动折叠」「自动溢出检测」「垂直的标签栏」也各是官方同节的多条 demo；「拖拽排序」官方是 renderTabBar + @dnd-kit 的集成 demo ⇒ 端口只留说明不放节点）。2026-10-22 按官方 `TabsProps` / `TabPaneProps` 整份重写，见 PROGRESS.md 坑 120 |
| Tree | 28 | **完成**（24 节 demo：如何引入 / 基本用法 / 多选 / 可搜索的 / 手动触发搜索 / 简单 JSON 格式的数据 / 行显示节点 / 自定义节点内容 / 自定义图标 / 目录树模式 / 禁用 / 节点选中关系 / 默认展开 / 开启搜索的展开受控 / 受控 / 自动展开父节点 / 自定义展开 Icon / 连接线 / 虚拟化 / 动态更新数据 / 异步加载数据 / 可拖拽的Tree / 高级定制 / 可拖拽的高级定制，标题逐字取自 `data/docs.json`；另有 `Tree` / `TreeNodeData` / `Virtualize Object` 三张 API 表与 `ARIA` 不进 demo）。按官网重写属性面，见 PROGRESS.md 坑 118。**2026-10-24**：行内三处悬浮判定（整行底色、箭头变色、非整行档的文字底色）改按列表容器记下的指针位置算，行上那三枚 `HoverHandler` 删掉 —— 展开/收起动画的起手与收尾各有一次 Repeater 重建，新委托上的 handler 要等下一个鼠标事件才认得已经在里面的指针（PROGRESS.md 坑 129） |

### 展示类（23）

| 组件 | 源站小节 | 状态 |
| --- | --- | --- |
| Avatar | 13 | **完成**（2026-10-21 按官方 `AvatarProps` / `AvatarGroupProps` 整份重写组件与页面：如何引入 / 尺寸（七档 + 两枚自定义数）/ 颜色（官方那 5 枚 + 16 档色板一行 + white 一枚）/ 自适应字符大小（gap 三档）/ 图片（两枚示例图 + 方角 + 读图失败回落）/ 形状 / 事件（hoverMask 两档写法 + 三个回调计数）/ 顶部和底部 Slot（合用一枚直播头像 + 顶部三档 + 底部方牌三档与圆片三档）/ 额外边框（含方角那枚演示半径 0）/ 额外动效（三档 border motion + contentMotion）/ 头像组（基本 / maxCount / renderMore / overlapFrom 两向 / 逐档描边两排）。旧记「5 节」缺的八节正好要旧端口没有的 `color` 色板、`gap` 自适应、`hoverMask` 与三个事件、`topSlot` / `bottomSlot`、`border` / `contentMotion` 与整个 `AvatarGroup`） |
| Badge | 6 | **完成**（2026-10-21 按官方 `BadgeProps` 整份重写组件与页面：如何引入 / 基本用法 / 设置显示数字最大值 / 设置徽标位置 / 设置徽标样式（theme、type 两张）/ 独立使用 —— 代码演示章 5 节全齐（旧页面 4 节且每一节只摆一个裸 Badge、没有 base 内容，等于把包裹式组件当成独立式在用），`###` 一共 6 个，余下 1 个是那张 API 表。旧端口是 60 行的自造面：`count: int` + `tone: Enums.*` + `light: bool` + 自造的 `showZero`，`overflowCount` 缺省 99（官方**无缺省 ⇒ 不传永不截断**），`position` 四档与 `inverted` 主题根本没有，位移是 `0.28` 比例（官方是 `translate(±50%, ∓50%)` 角点居中），字号 11 / Medium（官方 12 / 400），light 档描边写 transparent（官方三档都带 1px bg-1）。现在 14 条 prop 全齐：count 三档（数字 / 字符串 / Component，给了就画、`count=0` 画 "0"）、6 type × 3 theme 的语义令牌矩阵、四方位 + 「没 children 走 `-block`」、三个事件（`clicked` / `mouseEntered` / `mouseLeft`，后两个改名是因为 `left` 撞 QQuickItem 的 FINAL 成员）。官方那一节的 `<IconLock>` 端口图标表里没有，换成 heart_stroked；inverted 那颗隐形点照官方摆在 fill-0 灰底上。详见 PROGRESS.md 坑 116 |
| Calendar | 8 | **完成**（如何引入 / 日视图 / 周视图 / 月视图 / 设置周起始日 / 多日视图 / 事件渲染用法 / 自定义渲染） |
| Card | 16 | **完成**（2026-10-20 按官方 `CardProps` / `MetaProps` / `CardGroupProps` 整份重写组件与页面：如何引入 / 基础卡片 / 简洁卡片 / 封面 / 边线和外边框 / 阴影 / 更灵活的内容展示 / 内部卡片 / 栅格卡片 / 内置预加载 / 更丰富的预加载效果 / 带页签的卡片 / 卡片操作区 / 卡片组 / 网格型卡片组 —— 代码演示章 14 节全齐（旧页面只有 4 节），`###` 一共 16 个，余下 1 个是那张三合一 API 表，不进 demo。旧端口是 71 行的自造面（`title` + `headerExtra` + 自己的 `padding` / `spacing`，而且根项是 `Rectangle`），官方那 17 条 prop 一条都没有；`headerExtra` 与官方的 `headerExtraContent` 连字重字号都不同（旧的是 14 / text-2，官方是 `$font-size-header-6` / **700** / text-0）。现在四段 header → cover → body → footer 各带自己的 20 内边距（本体 `padding: 0`、**body 无条件渲染** ⇒ 空卡也占 40 高），`header` 覆盖 title + extra 而外层那条 `headerLine` 照旧，标题字符串档走 `Typography.Title heading={6}`（16 / 22 / 600 + 单行截尾 + 截到了才出 Tooltip），`shadows` 两档都补上 300ms 过渡与 `cursor: pointer`，`loading` 用真 `Skeleton`（Title + `<br>` + Paragraph rows 3 = 112）。`Card.Meta` 拆成 `CardMeta`（三格真值判断、标题 **700** 比 header 那档重一级）、`CardGroup` 拆出来当 Space 的换皮（wrap + 行内垂直居中、`spacing` 收数字或 `[水平, 垂直]`、`type: 'grid'` 强制清间距 + 成员卡圆角 0 + 相邻重叠 1px）。官方 demo 的封面是远端图 ⇒ 换成 gallery 自带的 `sample1.png`；`bodyStyle` 那几条 flex 排版在端口是死 prop，页面里改成调用点自己摆 Row。截图与探针另抓到「卡片圆角切不到封面顶角」这一条硬限制（MultiEffect 拿不到隐藏项的纹理），详见 PROGRESS.md 坑 114。**2026-10-30 追加**：官方那 14 节 + 「如何引入」之后再加一节『撑满剩余高度』，演示的是**端口新增 prop `bodyFill`**（官方 `-card-body` 只有 `padding: 20`，没有 `flex: 1` 那一档），页面小节计数 15 → 16；demo 是一对 260×300 的卡（关档底部留白 119、页脚悬中间；开档正文 218×135、页脚贴到底边），四条边界（没给定高等价没开、剩余为 0 回落内容档、剩余不足一格不夹自然高、与 `loading` 同开不生效）写在那节的 Note 与 `src/Card.qml` 的属性注释里 |
| Carousel | 10 | **完成**（2026-10-20 按官方 `CarouselProps` / `CarouselIndicatorProps` / `CarouselArrowProps` 整份重写组件与页面：如何引入 / 基本用法 / 主题切换 / 指示器 / 箭头 / 定制箭头 / 播放参数 / 动画效果与切换速度 / 受控的轮播图 —— 代码演示章 9 节全齐（旧页面只有 5 节），`###` 一共 10 个，余下 1 个是那张「API 参考」（Carousel + ArrowButton 两张表，Methods 另起一节）。旧端口整套是自造的：轨道平移（一个 `slideOffset` 拖着所有子项横走）、独立的 `interval` 属性、`activeIndex` 是普通可写属性（受控 / 非受控不分）、`previous()` 而非官方的 `prev()`，而官方那 18 条 prop 里 `arrowProps` / `slideDirection` / `trigger` / `defaultActiveIndex` / `activeIndex` 一条都没有。现在照官方动画模型：**每片都叠在同一格、slide 档两片同时滑**（2026-10-24 浏览器逐帧实测更正：官方每片都内联 `transitionDuration` 而 `transition-property` 初值是 `all` ⇒ visibility 也参与过渡，出片整段可见、滑到 ∓100% 后才隐藏 —— 旧记录「出片整段不可见」是错的；曲线是 CSS `ease`，见 PROGRESS.md 坑 134），fade 档是两片交叉；`autoPlay` 收成 `true \| false \| { interval, hoverToPause }` 三象、间隔 = `interval + speed`、鼠标进出各延迟 400ms；`activeIndex` 给了就是受控（只发 `changed`、不回写状态、挂载与鼠标离开不起播，但 `next()` 走的是 foundation 那份没有门的 ⇒ 照样起计时）；指示器与箭头拆成 `CarouselIndicator` / `CarouselArrow` 两个类型，箭头自定义键按官方叫 `children`（字符串 = 图标名 / `Component` = 任意节点）。令牌全照 variables.scss：指示器距边 32、点 8/12、柱 4/6 与 12→20 / 20→28、条状容器写死 240、箭头 32 距边 20；primary 档取 `--semi-blue-6` 而不是语义主色。上游三处不抄：`getValidIndex` 只加一次长度（负得超过一圈给出负数）、0 片时给 `NaN`、被注释掉的键盘 / role 档；两条 `transition` 的时长令牌都误取 `delay-none`（0ms）⇒ 端口不做换色过渡。官方八节 demo 没有一处用 `slideDirection`，页面在「动画效果」那节补了开关。详见 PROGRESS.md 坑 115 |
| Collapse | 10 | **完成**（基本用法 / 手风琴 / 禁用面板） |
| Collapsible | 6 | **完成**（基本用法 / 折叠高度 / 动画时间 / 嵌套） |
| Cropper | 8 | **完成**（2026-10-20 新建组件与页面：如何引入 / 基本用法 / 自定义裁切框比例 / 受控旋转-缩放图片 / 裁切框设置 / 实时预览裁切效果 —— 代码演示章 6 节全齐，`###` 一共 8 个，余下 2 个是 API 与 Methods 两张表。原本在「跳过」那一列（理由是依赖较重），这轮发现官方那 903 行 `cropper/foundation.ts` **没有任何第三方依赖**，整套交互是手写的，于是按官方 prop 面与算法逐条搬。官方 demo 的 `src` 是两张远端图，端口裁切要同步读到像素（`CropperRuntime` 只认本地路径与 qrc）⇒ 换成 gallery 自带的 `sample1.png` / `sample4.png`，远端 URL 仍能显示与拖缩、只有裁切出不来。像素那一段走 C++：QtQuick 的 Canvas 撑不住官方 getImageData / putImageData 那条管线（`drawImage(Image)` 在 cocoa 下什么都不画）。圆角裁切那档也没走 MultiEffect 遮罩（拿不到 `layer.enabled` + `visible: false` 那张 Item 的纹理），改成盖一条「框减椭圆」的偶环形带。`parse-docs.py` 两处顺带修：`SKIPPED` 撤出 cropper、`parse_api` 原来只认 `## API 参考` 而 cropper 那页是 `### API`（收进任意级并截到下一个任意级标题，否则 `### Methods` 那张两列表会被吞成 API 行）。截图复核抓到「`preview: 后面那个项` 的绑定读到的容器尺寸是 0 ⇒ 预览区整块 0 高」，改成第一次量到正尺寸那一拍再记（详见 PROGRESS.md 坑 112） |
| Descriptions | 10 | **完成**（2026-10-20 按官方 `DescriptionsProps` / `DescriptionsItemProps` 整份重写组件与页面：如何引入 / 基本用法 / 设置对齐方式 / JSX 写法 / 设置布局模式 / 双行显示 / 自定义 Key 样式 —— 代码演示章 7 节全齐（旧页面只有 4 节，且「设置布局模式」那节演的其实是旧端口自造的「一行几组」），`###` 一共 10 个，余下 3 个是 Descriptions / DataItem / DescriptionItem 三张表，不进 demo。旧端口是 72 行的自造面（`items` 数组 + 「`column` 决定每行几组、各组等宽」），官方八条 prop 一条都没有；而**官方缺省 `layout: 'vertical'` 是一个条目一行**，`column` 与 `span` 只在 horizontal 那一路被 `getHorizontalList` 读到 —— 旧实现等于把官方的第二档当成了缺省档。现在 `align` 四档（plain 是换 DOM：key 带冒号、value 左内边距 8）、`row` 双行三档（key 上 value 下、value 字重 600、字号 16/20/28、右内边距 48/60/80、那 12 的行距被 `-double` 重赋成 0）、`span` / `hidden` / `keyStyle` / `value` 三档、子项档 `DescriptionsItem` 全齐；`data` 那条改叫 `dataList`（`Item.data` 是子项链表，同名声明盖不住）。QML 没有 table ⇒ vertical 是 auto table 两列（th 列 = 最宽 key + 24，**24 是 padding 在文字盒之外**），horizontal 是「槽数等分」（grid = 各行最大的 Σspan）。截图复核抓到两条 offscreen 量不出来的：th 那 24 被算进文字盒里（center 档右对齐的 key 贴在 value 脸上）与 `keyStyle` 的 width 该不该落地 —— 后者照官方实现（只有 plain 档的 `-key` 是 inline-block 才吃 width/textAlign），所以官网「自定义 Key 样式」那节第一个 demo 实际没效果，页面把 center 与 plain 两块并排演出来（详见 PROGRESS.md 坑 113） |
| Dropdown | 13 | **完成**（2026-10-19 按官方 `DropdownProps` + `dropdown.scss` 重做组件与页面：如何引入 / 基本用法 / 嵌套使用 / 弹出位置 / 触发方式 / 触发事件 / Json 用法 —— 代码演示章 7 节全齐（旧页面只有 4 节，且「嵌套使用」那节压根没嵌套、「弹出位置」只有两档），`###` 一共 12 个，余下 5 个是 Dropdown / Dropdown.Menu / Dropdown.Item / Dropdown.Title / DropdownMenuItem 五张表加 ARIA，不进 demo。旧端口是 32 行的 PopupBase 薄壳（只有 `anchor` / `placement` / `itemHeight`），官方那 25 条 prop 一条都没有；整份改成**以 `Tooltip` 为根**（官方 render 就是把一切转交 Tooltip，与已重做过的 Popover 同构），trigger 五档 / position 十二档 / 点外 / Esc / 进出场全部继承，本文件只写缺省差（position bottom、zIndex 1050、mouseLeaveDelay 100、closeOnEsc true、无 max-width、spacing 外层 4 嵌套 2、钉死 showArrow false）与 `menu` / `showTick` 两条。条目侧拆出 `DropdownTitle` / `DropdownDivider`（旧的 `isTitle` / `isDivider` 开关撤掉），`selected` 是官方死 prop 收了不用、对勾只看 `active`、`type` 不传就是 text-0（官网表里那条缺省 tertiary 是错的）、嵌套那一档 `onClick` 换 `onMouseDown`。键盘两半全做：trigger 上 ArrowDown/Up 送首末项，菜单内上下跳（跳过禁用、不绕回）、Enter/Space 点当前项、Esc、可打印字符按首字母跳。开层截图复核（cocoa）：分组标题 text-2 / 图标 16+8 / 禁用灰 / 分隔线 / 三档 type 字色 / active 加粗全对；三条「静默不生效」的坑（Popup 不是 Item 导致宿主链断、位置器隐式宽吃实际宽导致卡片 0×8、`required property` 在 sourceComponent 那一路不注入）详见 PROGRESS.md 坑 111 |
| Empty | 6 | **完成**（2026-10-19 按官方 `EmptyProps` + `empty.scss` 重写组件与页面：如何引入 / 基本用法 / 自定义（两 demo：带操作区、不用图）/ 不同布局 / 占位图插画(建设中) —— 代码演示章 5 节全齐（旧页面只有 3 节，且「不同布局」那节压根没演 `horizontal`），`###` 一共 6 个，多出的是 Empty 那张 API 表，不进 demo。旧端口是整套自造面（`icon` 图标名 / `iconSize` / `description` 写死「暂无数据」/ `actions`），官方那六条一条都没有，整份换成 `layout` / `image` / `darkModeImage` / `title` / `description` / `children`（QML 侧别名只能叫 `footer`，`Item.children` 占不了）+ `imageStyle` / `style` / `className` 三条收了不产出差异。官方 `@douyinfe/semi-illustrations` 的 16 张 SVG（8 组 × 明暗）原样搬进 `examples/gallery/data/illustrations/`，所以五节都能同时演 `darkModeImage`、切暗色整套换。截图复核抓到两条 offscreen 量不出来的：`Image.sourceSize` 对 SVG 按 DPR 放大（八格插画被撑成一行一格）与 `TextMetrics` 比 `QQuickText` 窄（CJK 标题被挤成两行），改读 `implicitWidth` + 一枚隐藏的同款 `Text` 量自然宽（详见 PROGRESS.md 坑 110）） |
| Highlight | 6 | **完成**（2026-10-19 按官方 `HighlightProps` + `foundation.ts` 重写组件与页面：如何引入 / 基本用法 / 指定高亮样式 / 不同文本使用差异化样式 / 指定高亮标签 —— 代码演示章 5 节全齐（旧页面只有 3 节），`###` 一共 6 个，多出的是 Highlight 那张 API 表，不进 demo；末尾「大小写敏感与正则」是端口补充节（官方有这两条 prop 却没有 demo 小节）。旧实现把词按长度排序拼成一个 big-alternation 正则，整份换成官方那四步（逐词扫描 → 按 start 排序 → 合并重叠与**相接** → 补空隙），并补上 `autoEscape` / `highlightStyle` / 对象档 `{text, style}` / `component`。`component` 与两处 `className` 收了不生效、几何样式键不产出声明，逐条写在页面说明与组件头。顺带修掉两处 gallery 侧的数据脏：`docs.json` 里「基本用法」那节 description 混进的 `<Notice>` 标签原文（已把规则写进 `parse-docs.py` 的 `strip_markdown`，重跑不会退回）、API 表里 `string[]\|object[]` 被转义竖线劈成两列导致整行左移（`parse_api` 改成只按未转义竖线分列）；截图复核还抓到**整站每一页的「API 参考」表都在画「暂无数据」** —— 根因是 `main.cpp` 用 `QJsonDocument::toVariant()` 注入，数组到了 QML 侧是 QVariantList，`Array.isArray()` 返回 false，`Table` 的 `dataSource` 判据因此塌成空表；改成注入 JSON 原文、由 `GalleryMain.qml` 自己 `JSON.parse`（详见 PROGRESS.md 坑 109）） |
| Image | 13 | **完成**（2026-10-19 按官方 `ImageProps` + `PreviewProps` 整份重做组件与页面：如何引入 / 基本用法 / 加载失败的占位图 / 渐进加载 / 自定义预览图片 / 多图预览 / 单独使用预览组件 / 渲染在指定容器 / 自定义预览底部操作区 / 自定义预览顶部展示区 —— 代码演示章 10 节全齐（旧页面只有 4 节），`###` 一共 13 个，余下 3 个是 Image / ImagePreview / MenuProps 三张 API 表，不进 demo。旧端口是整套自造面（`source` / `previewSources` / `previewIndex` / `showMask` / `maskText` / `showToolbar` / `openPreview()`），整份换成官方那一套，并拆出独立的 `ImagePreview`（组 / 单开）与 `ImagePreviewInner`（预览层本体）。**`showMask` / `maskText` 撤掉**：官方 `renderMask`（image.tsx:168-173）从来没被调用、`semi-image-mask*` 无样式 ⇒ 成功态什么都不画，能预览时只换光标。官方 `visible` 那条在端口叫 `open`（`Item.visible` 是 FINAL 的 bool，装不下「没给 ⇒ 非受控」）；`renderHeader` / `renderPreviewMenu` 从函数组件改成往自定义节点注入 `title` / `menu`。官方靠外部库的那部分（`getPopupContainer` 的 DOM 定位）换成 `container` 给一个 Item；下载一族、`lazyLoad` / `preLoad`、`viewerVisibleDelay`、`showTooltip` 与八条 `*Tip` 记为端口不排。UploadPage 的「放大预览」从自造的 `openPreview()` 换成官方那条独立 `ImagePreview`） |
| List | 18 | **完成**（2026-10-19 按官方 `ListProps` / `ListItemProps` 重写组件与页面：如何引入 / 基本用法 / 模板用法 / 布局 / 栅格列表 / 响应式的栅格列表 / 加载更多 / 滚动加载 / 滚动加载无限长列表 / 拖拽排序 / 带分页器 / 带筛选器 / 添加删除项 / 单选或多选 / 响应键盘事件 —— `###` 一共 18 个，代码演示章这 15 节全齐，余下 3 个是 `List` / `List grid props` / `List.Item` 三张 API 表，不进 demo。旧端口是整套自造面（`header` / `footer` 只收字符串、`emptyText`、`bordered` 默认 true、条目一个内容槽、没有 `dataSource` / `renderItem` / `grid` / `layout` / `loading` / `loadMore`），整份换成官方那一套：条目三段 `header` / `main` / `extra` + `align` 五档、`split` 一处管三条线、`:last-child` 那两种「不命中」的档（栅格、被包一层）照抄。缺的 7 节里三节官方靠外部库（infinite-scroller / react-virtualized / dnd-kit），端口换成 `Flickable.atYEnd` / `ListView` / `DragHandler` + 索引交换；`CheckboxGroup` / `RadioGroup` 只认直接子项、包不进 List 的条目，所以「单选或多选」那节的选中数组提到页面上自己维护。**2026-10-19 下午补完**：`ListItem` 收上官方那对 `onMouseEnter` / `onMouseLeave`（端口的 `mouseEntered` / `mouseLeft`，API 表没列但 TSX 里有），书单因此不再自己挂 `HoverHandler`；`grid` 把 Col 的 `offset`（margin-left，占格）/ `push` / `pull`（relative 位移，只挪像素，两个都给时 left 赢）排进重排，`order` 收了也不生效（`grid` 那一个对象原样摊给每一条 Col）并钉成用例；栅格节在官方那一张之外多摆三张（offset 2 / push 2 / pull 2），响应式那节的说明补上「档位按属性各取各的」。截图复核抓到 `GridCard` 的描边包不住标题（`anchors.margins: 8` 配 `implicitHeight = band + 16` ⇒ 内容顶在 y=0、描边从 y=8 起），已按官方 `<List.Item style>` 的口径改成描边铺满整条、留白进内容列）  |
| Modal | 17 | **完成**（2026-10-18 按官方 `ModalProps` 重写并补上命令式那一层（新增 `ModalConfirm` / `ModalHost`）：如何引入 / 基本 / 底部撑满 / 点击遮罩层不可关闭 / 自定义按钮文字 / 自定义按钮属性 / 自定义对话框头部和页脚 / 自定义对话框的样式 / 自定义的对话框 / 全屏 Modal / 命令式调用 / Hooks 用法 / 可拖拽 Modal —— 13 个小节，旧记「5 节」缺的七节正好要本库没有的 `footerFill` / `header` / `fullScreen` / `Modal.method()` 那一套与 `modalRender`。组件是**完全受控**的：`visible` 归调用方，`onOk` / `onCancel` 只通知，页面每一节都是「一个 bool + 一个 Modal」；余下 `###` 是 Modal 与 Modal.method() 两张 API 表加 `ARIA` / `键盘和焦点`，不进 demo） |
| OverflowList | 7 | **完成**（2026-10-18 按官方 `OverflowListProps` 重写组件与页面：如何引入 / 折叠模式 - 默认 / 折叠模式 - 方向 / 折叠模式 - 最小展示的数目 / 滚动模式 —— 代码演示章 4 个 demo 小节全齐，余下 3 个 `###` 是 API 参考与两张模式表，不进 demo。旧页面用的是自造面 `itemDelegate` / `overflowDelegate` / `onOverflowClicked`（官方没有这三条），整份换成 `visibleItemRenderer` / `overflowRenderer`（`Component`，节点自己声明 `property var item` / `property int index` / `property var overflowItems`）+ `items` / `itemKey` / `renderMode` / `collapseFrom` / `minVisibleItems` / `threshold` + `onOverflow`。页面照官方四份 live demo 各摆一条 Slider 调容器宽（官方 `useState(100)`），六项内容也照抄 alarm / bookmark / camera / duration / edit / folder 的蓝 Tag + 「+N」灰 Tag；项间那 8px 按官方写进渲染节点自己的隐式宽（组件本体没有 spacing，`overflowList.scss` 只有 flex nowrap），三档「+N」的余量逐节抄（默认不带 / 方向档右 8 / 滚动档左右各 8）。官方滚动档那节的 demo 写的是 `+{item.length}`（对象取 length 恒 undefined）—— 上游 demo 的笔误，端口按意图摆成「这一边收了几项」，并把两侧节点做成定宽、常驻只切 enabled（官方 Tabs 那对箭头同形）；宽跟着收起项数变会和视口互相追（见坑 102）。两侧分不出左右是端口这份 API 面缺的一块（官方 renderer 在滚动档返回**两组**节点），补了注入的 `overflowSide`（`before` / `after`）才画对箭头方向 —— 这一条是截图抓出来的，34 条用例当时全绿 |
| Popover | 13 | **完成**（2026-10-18 按官方 `PopoverProps` 重写：如何引入 / 注意事项 / 基本使用 / 弹出位置 / 受控显示 / condition 条件触发 / 显示小三角 / 指向元素中心 / 设置浮层背景色 / 初始化弹出层焦点位置 / 搭配 Tooltip 或 Popconfirm 使用 —— 代码演示章 11 个小节全齐，余下 2 个 `###` 是 `Popover` / `PopoverContent` 两张 API 表，不进 demo。旧记的那 6 节缺的「如何引入 / condition 条件触发 / 指向元素中心 / 初始化弹出层焦点位置 / 搭配 Tooltip 或 Popconfirm」正好要本库没有的 `condition` / `arrowPointAtCenter` / `initialFocus`；组件同批改以 `Tooltip` 为根（官方 Popover 就是换皮的 Tooltip），旧自造面 `title`（官方 `PopoverProps` 没有这一条）撤掉，`TagInput` 的 `showContentTooltip: ({type:'popover'})` 与 `TagGroup` 的 `+N` 剩余项一起搬到新 prop 面） |
| ScrollList | 5 | **完成**（2026-10-18 按官方拆成壳 + 列两个组件：`src/ScrollList.qml` 只留 `ScrollListProps`（`header` / `footer` / `bodyHeight` / `className` / `style`），新增 `src/ScrollItem.qml` 承载 `ScrollItemProps`（`mode`（默认 **wheel**）/ `cycled` / `list` / `selectedIndex` / `motion` / `transform` → `textTransform`（`Item.transform` 是 FINAL）/ `type` / `aria-label` / `onSelect(data)`），旧的自造面（壳吃 `list`·`wheel`·`cycled`·`selectedIndex`、列写成静态行 `ScrollListItem { text; selected }`、信号 `selected(data, index)`）整份换掉，`ScrollListItem.qml` 已从构建里摘除。页面补齐官方 2 个 demo 小节：如何引入 / 基本使用（无限滚动列表 = 上午下午 + 12 小时 + 60 分三列滚轮，`cycled` 两列、奇数分钟 `disabled`、每列 `type` 认领自己的 `onSelect`、`footer` 传 Button 节点、`style` 关掉阴影）。「源站小节」那 5 个 `###` 里有 3 个是 `ScrollList` / `ScrollItem` / `ARIA` 三张表，不进 demo；页内另加两条说明（受控 `selectedIndex` + `cycled` + `disabled` 跳过；`mode` 默认 wheel，normal 档官方没有 demo 所以不摆）） |
| SideSheet | 7 | **完成**（2026-10-18 按官方 `SideSheetProps` 重写：如何引入 / 基本 / 自定义位置 / 自定义尺寸 / 可操作的外部区域 / 渲染在指定容器 / 自定义内容区域。旧版只有 5 节且没有「如何引入」，缺的那节要本库没有的 `getPopupContainer`；而「可操作的外部区域」在旧端口是**反的**（`showMask` 只管遮罩画不画、`modal` 常开 ⇒ 外面点不动）。旧自造面 `showMask` / `footerContent` / `open()` / `Enums` 档的 `placement`·`size` 整份换成官方那套（受控 `visible` + `onCancel` + `afterVisibleChange`），`tst_feedback.qml` 里三条 SideSheet 用例搬进新的 `tests/tst_sidesheet.qml`。余下 `###` 是 ARIA 与两张 API 表，不进 demo） |
| Table | 28 | **完成**（2026-10-18 把官方 28 个 `###` demo 全补齐：基本表格 / JSX 写法 / 行选择操作 / 自定义渲染 / 带分页组件的表格 / 拉取远程数据 / 固定列或表头 / 带排序和过滤功能的表头 / 自定义表头筛选 / 自定义筛选器 / 筛选确认模式 / 自定义筛选项渲染 / 可以展开的表格 / 树形数据展示 / 自定义行或单元格事件以及属性 / 实现斑马纹样式 / 实现表头样式定制 / 实现单元格 Hover 样式定制 / 单元格缩略 / 可伸缩列 / 拖拽排序 / 表格分组 / 虚拟化表格 / 无限滚动 / 受控的动态表格 / 完全自定义渲染 / 表头合并 / 行列合并。旧版只有 4 节，缺的二十四节要 `sorter` / `filters` / `fixed` / `scroll` / `rowSelection.checkRelation` / `groupBy` / `virtualized` / `resizable` / `components` / `useFullRender` / 行列合并这一整批本库没有的 prop，所以组件 + 新的 `TableEngine.js` + 新的 `TableFilterPanel.qml` 与页面一起做。官方 `###` 里 `headerStyle 示例` 与 `ARIA` 在 `## API 参考` 之后（抽取口径只取代码演示章），因此 docs.json 是 28 节、页面也是 28 节） |
| Tag | 17 | **完成**（2026-10-18 按官方 `TagProps` 重写，并补上 `TagGroup` / `SplitTagGroup`：如何引入 / 基本用法 / 尺寸 / 形状 / 配置图标 / 颜色 / AI 风格 - 多彩标签 / 样式类型 / 头像标签 / 不可见的 / TagGroup 使用 / SplitTagGroup 组合标签。旧记「5 节」缺的七节正好要本库没有的 `type` / `avatarSrc` / `colorful` / `gradient` / 受控 `visible` 与两个组组件；余下 5 个 `###` 是 `Tag` / `TagGroup` / `SplitTagGroup` 三张 API 表与 `ARIA` / `键盘和焦点`，不进 demo） |
| Timeline | 6 | **完成**（2026-10-17 按官方 `TimelineProps` + `TimelineItemProps` 重写：如何引入 / 基本用法 / 节点类型 / 自定义节点 / 时间轴位置 / 使用 dataSource。旧记「9 节」数的是 markdown 里 9 段 jsx（「时间轴位置」一节自己就带 4 段），`###` 级 demo 是 6 节，那 4 段当作 4 个小标题折进同一节，同 PinCode 页的口径） |
| Tooltip | 10 | **完成**（2026-10-17 按官方 `TooltipProps` 重写：如何引入 / 注意事项 / 位置 / 指向元素中心 / 触发时机 / condition 条件触发 / 覆盖特定样式 / 渲染至指定 DOM / 搭配 Popover 或 Popconfirm 使用 / 仅当内容宽度超出时展示 Tooltip。旧记「11 节 / 5 节完成」把 `## API 参考` 之类整章也数进去了，`###` 级 demo 是 9 节（加「如何引入」共 10 节，`ARIA` 那节归 shell 的 Accessibility 章）；缺的那几节正好要本库没有的 `condition` / `container` / `maxWidth` 与四档 `trigger`） |
| UserGuide | 8 | **完成**（2026-10-17 按官方重写：基本用法 / 主题 / 气泡卡片弹出位置 / 设置高亮区域大小 / 定制按钮 / 受控 / 弹窗式引导 / 无遮罩。旧记的「10 节 / 5 节完成」里缺的三节正好要本库没有的 `position` / `current` / `mode`，组件与页面一起做） |

### 反馈类（8）

| 组件 | 源站小节 | 状态 |
| --- | --- | --- |
| Banner | 5 | **完成**（2026-10-17 按官方重写：如何引入 / 基本用法 / 不同类型 / 非全屏模式 / 自定义内容。原记「源站 7 节」是把 `## API参考` 与 `## Accessibility` 这类整章也数进去了，`###` 级只有 5 节） |
| Feedback | 8 | **完成**（2026-10-17 落地：如何引入 / 基本使用 / 文字类型 / 单选反馈 / 多选反馈 / 自定义反馈内容 / 模态对话框形式 / 反馈完成提示） |
| Notification | 10 | **完成**（普通通知 / 带图标 / 多色样式 / 修改延时） |
| Popconfirm | 8 | **完成**（基本使用 / 类型搭配 / 自定义文案） |
| Progress | 12 | **完成**（如何引入 / 标准的进度条 / 不确定状态的进度条 / 展示百分比文本 / 垂直的进度条 / 环形进度条 / 小号的环形进度条 / 动态改变进度 / 自定义中心文字内容 / 圆角方角边缘 / 自定义进度条颜色 / 自动补齐颜色区间 —— 2026-10-16 按官方重写，见下；2026-10-17 环形点名 `Shape.CurveRenderer` 修掉锯齿，见文末） |
| Skeleton | 4 | **完成**（2026-10-17 按官方重写：如何引入 / 基本使用 / 组合使用（六个组合 demo）/ 加载动画） |
| Spin | 6 | **完成**（2026-10-16 按官方重写：如何引入 / 基本用法 / 尺寸 / 带文字的 / 自定义指示符 / 延迟显示） |
| Toast | 11 | **完成**（如何引入 / 普通提示 / 其他提示类型 / 多色样式 / 链接文本 / 修改延时 / 手动关闭 / 更新消息内容 / 销毁所有 / 消费 Context / 创建不同配置 Toast —— 2026-10-16 按官方重写，见下） |

### Plus（3）

| 组件 | 源站小节 | 状态 |
| --- | --- | --- |
| Chat | 10 | **完成**（如何引入 / 基本用法 / 消息状态 / 动态更新数据 / 清除上下文 / 自定义渲染会话框 / 自定义渲染输入框 / 提示信息 / 自定义提示信息渲染 / API —— 2026-10-26 落地，见下） |
| DragMove | 6 | **完成**（如何引入 / 基本用法 / 限制拖动范围 / 自定义拖动后的位置处理） |
| HotKeys | 7 | **完成**（如何引入 / 说明 / 基本用法 / 自定义内容） |

### 跳过（13）

AIChatDialogue、AIChatInput、AIComponent、Sidebar、CodeHighlight、
Markdown 渲染器、JsonViewer、Lottie、AudioPlayer、VideoPlayer、
Semi DV、ConfigProvider、LocaleProvider —— 未实现或第三方，
侧边栏里不列（`content/ai` 与 `content/other` 两组整体不进 JSON）。
（Feedback 原本也在这列，2026-10-17 落地后移入反馈类。
Cropper 原本也在这列，2026-10-20 落地后移入展示类。
Chat 原本也在这列，2026-10-26 落地后移入 Plus。）

## 每轮记录

### 第 1 轮（2026-10-09）

**做了什么**

- `parse-docs.py`：从 `content/**/index.md` 解析出分类、标题、简介、各小节的
  标题与说明、API 表。69 个可做页面、715 个小节、说明文字全部自动提取。
  页面文件名用「扫描 `src/*.qml` 做忽略大小写匹配」推导，只手工列了 5 个特例
  （image→ImageView、layout→LayoutBox、grid→GridRow、typography→Title、tokens→Tokens）。
- `gen-tokens.py`：从 `semi-theme-default/scss` 解析出 17 组色板（每组 10 阶）、
  10 条 AI 渐变、111 个语义色（分 16 组）、字号 / 字重 / 圆角 / 间距 / z-index。
- 外壳：`GalleryMain`（窗口 + 数据）、`GalleryShell`（侧边栏 + 内容区 + 路由）、
  `GallerySidebar`、`GallerySection`、`GalleryApiTable`、`GalleryPlaceholder`。
- 6 个页面：Button / Tag / Badge / Progress / Divider / Tokens。
- `main.cpp` 加了 `--page <dir>` 和 `--shot <file>` 两个参数，便于逐页截图验证。

**效果**：侧边栏能点、分组能折叠、当前项高亮、未实现的灰掉；页面里是**真实运行的
QML 组件**（不是截图）；说明文字与官网一致；明暗跟随 `Theme`。

**遇到的问题**（都已解决，详见「已知问题」）：macOS 文件系统不区分大小写导致
误覆盖、QML 的 XHR 读不了本地文件、子目录 QML 类型不可见、`topPadding` 用错。

### 第 2 轮（2026-10-09）

**做了什么**

- 基础类剩余 7 页（历史）：FloatButton / Grid / Icon / Layout / Resizable / Space / Typography。
- 这几个页面涉及的组件比第 1 轮复杂，用到了 `GridRow`+`GridCol`、`LayoutBox` 系列、
  `Resizable`+`ResizableGroup`、`Space`、`Title`+`Paragraph`+`TextLabel`。

**注意到的**

- `Space` 是 `Row` 派生的，默认属性直接继承，所以 `Space { Button{} Button{} }` 就能用。
- `FloatButton` 用 `parent.width` 定位，必须放进有确定尺寸的容器（页里用了 `Stage` 包装），
  否则会跑到 Column 的右下角去。
- `Typography` 在本库里是三个组件（`Title` / `Paragraph` / `TextLabel`），不是单个组件。
- `Resizable` 的示例要把 `boundsToParent` 关掉，否则会被 demo 容器钳住，看不出拖拽效果。

### 第 3 轮（2026-10-09）

**做了什么**

- 导航类 8 页：Anchor / BackTop / Breadcrumb / Navigation / Pagination / Steps / Tabs / Tree。

**注意到的**

- `Anchor` 和 `BackTop` 都需要一个 `Flickable` 当 `target`，页里各造了一个可滚动区域，
  并把 `contentY` 预先滚一段，这样回到顶部按钮一进来就是可见的。
- ~~`Breadcrumb` 只吃文本项（`items`），图标要自己用 `Row` + `Icon` 拼；页里两种都演示了。~~
  （**2026-10-24 已作废**：`items` 是自造面，官方是 `Breadcrumb.Item` 子项 + `routes` 两档 ⇒
  端口换成 `BreadcrumbItem`（`icon` 收图标名或 Component），那一节按官方 demo 重写。）
- `Navigation` 的水平顶部菜单（`mode: horizontal`）已在 2026-10-23 那轮实现：条目横排、
  子导航收进浮层（顶级 bottomLeft、嵌套 rightTop），收起按钮与 openKeys 受控按官方只在竖直档生效。
- `Steps` 的 `items` 是 `[{ title, description }]`，`vertical` 控制方向。
- `Tree` 的 `treeData` 是 `[{ label, value, children, disabled }]`，`showLine` 开连接线。

### 第 4 轮（2026-10-09）

**做了什么**

- 反馈类 6 页：Banner / Notification / Popconfirm / Skeleton / Spin / Toast（Progress 在第 1 轮已做）。

**关于弹层的结论（原本预计是个麻烦，实际不是）**

计划里担心弹层组件会盖住侧边栏。查了实现后确认：`PopupBase` 和 `Notification` /
`Toast` 都是 `C.Popup` 派生、贴在 `Overlay.overlay` 上，确实浮在窗口层级。
但**官网的弹层本来也是浮在导航上的** —— 这是弹层的正常行为，不是问题。
所以没有做「只在 demo 区内展示」的模式，直接用按钮触发 `open()` 就行。
（记的是当轮事实：`Toast` 在 2026-10-16 那轮已整个重写成非 Popup 的宿主式组件，
自己把 wrapper 挂到 `Overlay.overlay`，见下面那一节与 PROGRESS.md 坑 83。）

两处实际的取舍：

- `Notification` 只支持右上角，官网的「不同位置弹出」没有实现，页里跳过了该小节。
- `Spin` 只有尺寸与颜色两个开关，官网的「带文字的」「自定义指示符」需要额外插槽，
  页里如实说明，并给了「用 Row 拼」的替代写法。
  （这条也是当轮事实：`Spin` 在 2026-10-16 那轮按官方 `SpinProps` 重写，`spinning` /
  `delay` / `tip` / `indicator` / 包裹内容全都补上了，6 个小节齐，见下面的补做条目。）

### 第 5 轮（2026-10-09）

**做了什么**

- 输入类第一批 7 页：Checkbox / Radio / Switch / Rating / PinCode / InputNumber / Slider。

**注意到的**

- 本库多数表单控件只到「控件 + 文字」，官网那种「辅助文本」「卡片样式」得自己用
  `Column` / `Row` 拼 —— 页里给了拼法，没有假装组件支持。（`Checkbox` 是例外：`extra`
  和 `type: ChoiceCard / ChoicePureCard` 都是组件自己画的。）
- `Checkbox` 的「全选」用 `CheckboxGroup` 的受控 `value` + 一个 `indeterminate` 的独立
  `Checkbox` 做，和官方同一套；组自己的 `changed` 回写页面数组。
- ~~`Radio` 没有 `CheckboxGroup` 那样的组容器，单选靠外部状态 + `onToggled` 回写。~~
  —— 第 5 轮的这条已经在 2026-10-12 那轮作废：`RadioGroup.qml` 补上了，见下面「第 14 轮」。
- `Slider` 没有 `vertical`，官网的「垂直」小节跳过了；「带输入框」用 `Slider` + `InputNumber`
  互相绑定做出来，这反而是更实用的写法。
- ~~`InputNumber` 的「货币展示」「科学计数法」需要自定义格式化，本库没这层，跳过了。~~
  —— 第 5 轮的这条已经在 2026-10-12 那轮作废：两层都补上了，见下面「第 13 轮」。

**写页面时反复踩到的**

- `GallerySection` 的默认属性直接落在 demo 区，所以里面放 `Column` / `Row` 都行，
  但**嵌套层级一多就容易把缩进写乱**（这轮有两页第一次写出来是坏的）。
  现在写完会立刻构建，构建能过再去截图。
- **页面文件要加 `pragma ComponentBehavior: Bound`**：页面里大量用 `Repeater` 的
  委托访问外层 `page` 的属性，不加这个 pragma，qmllint 会报 `Unqualified access`。
  这轮把 33 个页面文件统一加上了（脚本批量加的，一次到位）。

**关于那个偶发失败（跟踪结果）**

第 5 轮报过一次「29 个里 1 个失败」，第 7 轮又报了一次，两次都因为没留 stdout 而
不知道是哪个用例。第 7 轮收尾时连跑 4 次 + 循环跑 8 次都没再复现，
所以判定为**低概率偶发**（约 15 次里出现 2 次，但集中在有构建刚结束的那两次，
可能与磁盘/CPU 负载有关）。

**下次再遇到**：`ctest --preset debug --output-on-failure` 留下完整输出再判断，
不要像这两次一样只看到「1 个失败」就过去了。已记在待办里。

### 第 6 轮（2026-10-09）

**做了什么**

- 输入类第二批 6 页：Input / TagInput / Select / AutoComplete / DatePicker / TimePicker。

**注意到的**

- 这几个组件的核心都是「受控」：`Input.text` 是 alias、`Select.value` / `values`、
  `DatePicker.value`（yyyy-MM-dd 字符串）、`TimePicker.value`（HH:mm）。页里每页都有
  一个「受控组件」小节，演示外部改值能同步回控件。
- `Select` 的 `options` 既吃 `[{ label, value }]` 也吃字符串数组，两种都演示了。
- `AutoComplete` 按前缀过滤 `dataList`，`strict` 决定失焦时是否清掉非候选值。
- `DatePicker` / `TimePicker` 的值都是**字符串**而不是 Date 对象，写页面时别按
  Date 处理。**（2026-10-11 更新：`DatePicker` 已经改成吃 Date / Date[]（也收字符串，内部按
  `format` 解析），信号是 `changed(date, dateString)`；`TimePicker` 仍是字符串。
  2026-10-15 更新：`TimePicker` 也改成同一口径 —— 吃 Date / 时间戳 / 严格按 `format` 解的字符串
  （range 是它们的数组），信号是 `changed(date, dateString)`，字符串值解不出 `format` 时整个作废。）**
- 官网的「日期范围」「12 小时制」「无限滚动」这些本库没有，页面里跳过了。
  **（2026-10-11 更新：日期范围 / 日期范围时间 / 年月 / 年月范围 / 多选 / 确认 / 快捷方式 /
  内嵌输入框 / 四个 slot / 自定义触发器与格子渲染都已补齐，见组件清单里 `DatePicker` 那行；
  只剩「无限滚动时间列」那一档没做，因为 `timePickerOpts` 还没接。
  2026-10-15 更新：`TimePicker` 一侧的 12 小时制 / 时间范围 / 无限滚动（`scrollItemProps`）都已补齐；
  `DatePicker` 内嵌时间面板的 `timePickerOpts` 仍未接。）**

**这轮又踩了一次缩进**

`TimePickerPage.qml` 第一次写出来结尾多了一个 `}`，修的时候又删多了、变成少一个，
第二次构建才过。**教训**：改页面文件后不要靠肉眼数括号，直接构建 ——
编译器报行号比人眼快。这也说明「写完立刻构建」这条纪律是有用的。

### 第 7 轮（2026-10-09）

**做了什么**

- 输入类最后 6 页：Cascader / ColorPicker / Form / Transfer / TreeSelect / Upload。
  **输入类 19 页到此全部完成。**

**注意到的**

- `Form` / `FormItem` 是成对的：`FormItem` 要显式写 `form: 表单id`、`field`、
  `rules`，控件的值通过 `onTextChanged` 回写 `form.setValue()`。校验用
  `form.validate()` / `form.submit()` / `form.errorOf(field)`。
- `Cascader.value` 是**路径数组**（如 `["zj", "hz"]`），不是单个值；`TreeSelect.value`
  是单个值。两者容易混，页里都标了。
- `Upload` 的 `fileList` 每项是 `{ name, size, status }`，`status` 取
  `success` / `fail` / `uploading`。真机选文件我没做自动验证（需要系统文件对话框），
  页面里演示的是拖拽区外观 + 手动维护 `fileList`。
- `Transfer` 的 `targetKeys` 是右侧那一栏的 key 数组。

**这轮的返工**

`TransferPage.qml` 第一次写出来把「受控组件」小节写重复了，删的时候又弄坏了缩进，
重写一遍才过。**连续三轮都在页面嵌套缩进上返工** —— 这已经是稳定的失误模式了，
后面写页面时先把骨架（Item → Column → GallerySection → demo）搭好再填内容。

### 第 8 轮（2026-10-09）

**做了什么**

- 展示类第一批 8 页：Avatar / Card / Collapse / Collapsible / Descriptions / Empty /
  Highlight / Timeline。

**这轮把前几轮的教训用上了**

第 5~7 轮连续在页面嵌套缩进上返工。这轮开写前先定了个写法：**先把骨架
（`Item` → `Column` → 若干 `GallerySection` → demo 容器）整个搭好，再往里填内容**，
而不是边想边写。8 页一次过，没有返工。

**注意到的**

- `Collapse` 与 `Collapsible` 是两回事：前者是「带标题的面板列表」（配
  `CollapsePanel`、可 `accordion`），后者是「一整块内容展开收起」（`isOpen` +
  高度动画 + 可选 `collapseHeight`）。页面里都点明了区别。
- `Descriptions` 的条目只吃 `{ key, value }` 文本，要在值里放 `Tag`、头像得自己用
  `GridRow` + `GridCol` 拼 —— 页里如实说明。
- `Avatar` 的 `text` 显示**整串**（官方 children 那一支），放不下时按 `(边长 − 2*gap) / 文字自然宽`
  做 `scale` 收紧、不是缩字号；`gap` 给到「两倍就顶满边长」那一档就整个不收（官方那道闸门）。
  给了 `src` 而读图失败时回落到 `text`，除非 `error` 那个回调严格返回 `false`。
- `Highlight` 用 `searchWords` 数组匹配，默认不区分大小写，`caseSensitive` 打开后
  大小写必须完全一致。

### 第 9 轮（2026-10-10）

**做了什么**

- 7 页：Dropdown / Image / List / Popover / Tooltip / Modal / SideSheet。
- 修掉一个**系统性问题**：`GallerySection` 的 demo 区原本是 `Item` 而不是 `Column`，
  一小节里写两个子项（最常见的就是「控件 + 一段说明文字」）会全落在 y=0 叠成一团。
  全库扫出 11 处、涉及 10 个之前以为「已完成」的页面（Avatar / Descriptions / Empty /
  Highlight / Image / Notification / Slider / Timeline / Toast / Tokens）。
  把 demo 区改成 `Column { spacing: 12 }` 一次性解决，同时删掉页面里为补间距写的
  10 个 `topPadding: 12`。
- `ImagePage.qml` 改名 `ImageViewPage.qml`：docs.json 里 image 的 page 字段是
  `ImageView`，叫 ImagePage 路由找不到，会掉进占位页。
- `main.cpp` 加 `--scroll <px>`（页面比一屏长，逐页截图看不到靠下的小节），
  `--page` 的匹配改成忽略大小写。

**注意到的**

- 弹层在 `--shot` 下默认不打开，抓不到外观 —— 页面末尾加了一句
  `Qt.application.arguments.indexOf("--shot") >= 0` 时打开第一个弹层的钩子，
  正常浏览不受影响。
- `PopupBase.reposition()` 最后会把浮层夹进父容器范围内，所以贴着容器顶部的控件
  「向上弹出」没地方去、只好压在控件上；页面里给这种 demo 前面留了 48px 空地。
- `GridRow` 的行高是构造期算一次的，靠内容撑高的子项（比如 Card）来不及反映，
  后面的说明文字会压到卡片上 → 栅格 demo 里给 Card 显式写高度。

### 第 10 轮（2026-10-10）

**做了什么**

- 剩下 8 页：Table / Calendar / Carousel / UserGuide / OverflowList / ScrollList /
  DragMove / HotKeys。**DragMove 和 HotKeys 是原来漏掉的**（当时那份 13 页清单里没列，
  是从 docs.json 反查路由对账时才发现的），所以做完刚好是 69 页。

**注意到的**

- `HotKeys` 名字和官网一样、职责完全不同：官网那个是快捷键监听器
  （hotKeys + onHotKey 触发动作），本库这个只是把快捷键画成一排键帽，不监听按键。
  页面上把这条说清楚了。
- `Calendar` 四个视图都在（month 是网格，day / week / range 共用时间轴），`mode` 缺省已改回
  官方的 `week`。剩下的差量只有一条：官方月视图压根没有头部，翻页要使用方自己塞进头部槽，
  端口额外给一枚便利只读量 `title`（官方没有这个 prop）。
- `Table` 的单元格只做 `String(row[dataIndex])`，排序 / 筛选 / 展开行 / 树形 /
  固定列 / 单元格合并 / 虚拟滚动都没有 ——「自定义渲染」那一节如实写成了这些能力都缺。
- `Carousel` 的 `animation` 只分「slide」和「非 slide（淡入淡出）」两类，
  官网那整套动画名没有。

**这一轮的验证**

- 路由对账：69 个组件全部有对应页面文件，没有多余文件。
- `ctest` 29/29 通过；`all_qmllint` 0 警告。

### 第 11 轮（2026-10-10）

**做了什么**

- **侧边栏搜索**：顶部搜索框，命中「组件名 或 目录名」（不区分大小写）就留下。
  搜索时**忽略分组折叠状态**（否则收起来的分组搜不到），没命中时给一句「没有匹配的组件」。
- **色值复制**：Tokens 页的色块点一下把当前明暗下的色值写进系统剪贴板，落一个 Toast 提示。
- **暗色打磨**：69 页在 `--dark` 下逐页过了一遍。结论是**没有缺陷** —— 全库只有
  `ImageView` 有刻意硬编码的遮罩色（全屏预览的黑底、白色按钮），其余一律读令牌。
- **README**：新增 `examples/gallery/README.md`。
- **命令行**：加 `--search`（预置搜索框内容）与 `--dark`（深色启动），
  两者都是为了「这个特性在截图里能被验证」—— 搜索这类交互没法用合成事件测（见「已知问题」7）。

### 补做：计划书 §4 里从未实现的两项

计划书 §4 的页面骨架写了「⑤ 右侧页内锚点」和「末尾 API 参考表 / Accessibility / 文案规范 / FAQ」，
但前 10 轮一直没做 —— 外壳只渲染了标题、Tab、小节和 API 表。这一轮补齐：

- **页尾章节**：`parse-docs.py` 增加 `parse_guidelines()`，把 `## Accessibility` /
  `## 文案规范` / `## FAQ` 解析成 `guidelines: [{ title, items }]`，
  `items` 每项是 `{ kind, indent, text }`（`kind` 取 heading / text，`indent` 是列表层级）。
  覆盖 **Accessibility 44 页 / 文案规范 36 页 / FAQ 19 页**。
  渲染交给新的 `GalleryGuideline.qml`。
- **页内锚点**：外壳在右侧留一列，列出「各小节 + API 参考 + 页尾章节」，
  点一下滚过去，滚动时高亮当前节。滑轨规格照本库的 `Anchor`（2px、底色 color-border、当前段主色）。

**这两项踩到的（都已解决）**

- **`anchors` 是 `QQuickItem` 的 FINAL 属性**。外壳本来叫 `property var anchors`，
  加载直接失败：`Cannot override FINAL property`，整个 `GalleryShell` 起不来。
  改名 `anchorList`。这是那条「起名先想一下 Qt 那边有没有」的坑单第 N 次命中
  （前面撞过 `state` / `enabled` / `palette` / `padding` / `title` / `contentWidth`）。
- **滚到底时最后一节永远高亮不到**。以「内容顶部 + 24px」为基准线判断当前节，
  可内容滚到底之后再也不能把基准线顶下去，末尾那几节永远越不过它 ——
  高亮一直停在倒数第几节。修法：到底时直接认最后一节。
- **锚点位置要重排，但不能在每帧都算**。页面高度在一帧里会连着变好几次
  （小节里的 demo 撑高），用 `Qt.callLater` 合并成一次。
- **隐藏的小节别进锚点栏**。Tokens 页过滤到空会把自己的小节收起来（`visible: false`），
  但遍历仍然找得到它们，锚点栏就列出一串点了没反应的项。遍历时判一下 `visible`。
- **`--search` 要能回显到输入框**。关键字是从外面设进去的（不走输入框），
  输入框还是空白的，看着像没生效。用 `Connections` 双向同步，两值相同时不动作以免绕成环。

### 顺带修掉的四个库层缺陷（都由全页扫描逼出来）

跑「69 页每页一次 `--shot`，收集 stderr」时露出来的，不是这轮新引入的：

1. **`Toast` / `SideSheet` / `Notification` 的信号重名**。三个组件都自己声明了
   `signal closed`，而 `C.Popup` 已经有同名的 —— QML 报 `invalid override` 之后
   **那个信号被整个压掉**：`closed` 一次都不发，`onClosed` 永远不触发。
   症状不是「类型创建不出来」（那是 `UserGuide` 那次的表现），而是静默失效。
   更糟的是三个组件都写着 `onClosed: control.closed()`，声明被丢弃后这句变成
   **重发 Popup 自己的 closed**。删掉声明与那句重发即可（`Popup.closed` 本来就会发）。
   gallery 里 `SideSheet` 页的「最近一次关闭」演示正是被这个卡住的，一直是「（还没有）」。
2. **`Select` 不支持字符串数组选项**。组件文档与 gallery 页都说 `options` 既吃
   `[{ label, value }]` 也吃字符串数组，但读取处直接摸 `modelData.label`，
   字符串数组下拿到 `undefined`，下拉里的选项文字整片空白。
   改成统一走 `optionValue` / `optionLabel` / `optionDisabled` 三个抹平函数。
3. **`Timeline` 的 `type` 传字符串**。组件契约是 `Enums.Tone` 整数，gallery 页传的是
   `"success"` 这类字符串（照官网写法），`int` 属性接不住 —— 所有圆点退化成中性色。
   库里统一定的是「Enums 整数替代 React 的字符串 props」，所以改页面，不改组件。
   **（2026-10-17 这条作废：本轮按官方重写时核了 `semi-ui/timeline/index.tsx` 的
   `TimelineItemProps.type`，它本来就是 `'default' | 'ongoing' | 'success' | 'warning' | 'error'`
   五档字符串枚举，不是 `Tone`；组件跟着改成 `property string type`，`position` / `color` 同理。
   「Enums 整数替代字符串」只适用于官方真有 `Enums.*` 枚举的 prop。）**
4. **示例图指向 `/tmp/shotapp/`**。`ImageView` / `Avatar` 两页的示例图是
   `file:///tmp/shotapp/sample*.png` —— 那是早期截图工具的临时目录（本就说好不入库），
   **重启后就没了**，页面会静默退化成占位图。已把三张图收进
   `examples/gallery/data/img/` 并登记到 `RESOURCES`，页面改走 qrc 路径。
   「故意加载失败」那个用例换成同一个资源目录下确定不存在的名字，并在页面注释里写明报错是预期内的。

### 第 12 轮（2026-10-12）：Form 补齐官方小节

起因同样是「官网 form 有 24 节，我们只有 3 节」。这次不是取舍问题，是**组件本身离官方 API 面差得远**：
`Form` 只有 `values` / `errors` / `validate()` / `reset()`，`FormItem` 只有六个属性，
官方 `Form Props`（29 项）、`Field Props`（26 项，另有一行 `...other`）、`FormApi`（16 个方法）基本没落。

**组件层**

- `Form.qml` 重写：`layout` / `labelPosition` / `labelAlign` / `labelWidth` / `labelCol` /
  `wrapperCol` / `extraTextPosition` / `initValues` / `validator` / `trigger` /
  `stopValidateWithError` / `showValidateIcon` / `allowEmpty` / `disabled` 全部按官方名与默认值；
  FormState 补齐 `touched`；官方 `FormApi` 16 个方法里落了 13 个（`getFormProps` / `scrollToField` /
  `scrollToError` 没有），在 QML 里就是 Form 自己的方法
  （`setValue` / `setValues` / `getValue` / `getValues` / `getFormState` / `setError` / `getError` /
  `setTouched` / `getTouched` / `getFieldExist` / `validate(scope | {fields, silent})` /
  `reset(fields)` / `submitForm`），`getFormApi(api)` 回调保留，参数就是这张 Form。
- **字段路径引擎**：`user[0]` / `siblings.1` / `siblings['2']` / `parents[0].name` 都能写进
  嵌套的 `values`（官方靠 lodash，QML 侧自己解析；写操作沿路径重建对象，否则 `var` 属性不发变化）。
- 新增 `FormLabel` / `FormErrorMessage` / `FormSection` / `FormSlot` / `FormInputGroup` /
  `FormArrayField`（对应官方的 `Form.Label` / `Form.ErrorMessage` / `Form.Section` / `Form.Slot` /
  `Form.InputGroup` / `ArrayField`），`Input` 与 `Select` 加 `insetLabel`（内嵌 Label 用），
  `Select` 加分角圆角别名（`InputGroup` 的首尾圆角用）。
- `FormItem` 不再必须写 `form: 表单id` —— 沿 parent 链自动找，显式给仍然优先。
  内层控件的值也不再要求手写 `onTextChanged: form.setValue(...)`：按 `valueKey`
  （官方 `withField` 的同名概念）探测并自动双向接。

**页面层**：`FormPage.qml` 从 3 节到 24 节，标题与 `docs.json` 里抓自官网的小节一一对应
（`docs.json` 原来只抓了 24 节标题，`如何访问 formState` / `如何获取 formApi` / `ARIA` 三节是漏的，这次把说明文字补齐、小节数记回 27）。
官方余下 3 节没落：`Hooks 的使用`（`useFormApi` / `useFormState` / `useFieldApi` / `useFieldState`
四个 hook）、`HOC 的使用`（`withFormApi` / `withFormState` / `withField`）与 `ARIA`
（讲的是 DOM 上的 `aria-labelledby` / `aria-required` / `aria-invalid` / `aria-describedby`，本库组件还没接 `Accessible`）。
前两节整节都是 React 的上下文注入方式 —— 其中 `withField` 的等价物（`FormItem` 的 `valueKey`）
已经在「withField 封装自定义表单控件」一节 demo 过，`formApi` / `formState` 的取法则由新增的两节覆盖。
「声明表单的多种写法」里的 render / children render function / `component` 三种声明子节点的方式同属 React 结构，那一节只落了基本写法。

**验证**：新增 `tests/tst_form3.qml`（36 个函数、144 处断言），几何断言全部落在渲染项上；
`/tmp/negcheck_form.py` 逐处回退 40 个保真决定，39 处被测试抓到，
剩下 1 处（`slot-label-width`）经复跑核对是**等价改写**：`FormSlot` 里标签盒宽度是
`width: labelBoxWidth > 0 ? labelBoxWidth : implicitWidth` 显式赋的，内层 `FormLabel` 那个
`labelWidth` 只喂它自己的 `implicitWidth`，把它设成 0 渲染没有变化。

**顺带抓到的一处测试隐患**：`tst_date.qml` 的 `openAndGet()` 只等 `opacity > 0.99` 就往弹层里点，
而 `PopupBase` 进场是 `opacity 50ms + scale 100ms` 两条并行动画 —— 实测那一刻 `scale` 还在
0.9719~0.9999，弹层仍在放大，`test_presetClickSetsRangeAndSignals` 因此偶发点空。门槛补上
`Math.abs(scale - 1) < 1e-4`；但改回旧门槛连跑 8 次也没复现，负载相关的偶发失败（`tst_input3` /
`tst_p5b` 各红过一次）仍挂着，没当成已修。

### 第 13 轮（2026-10-12）：Input 与 InputNumber 补齐官方小节

两页都是「官网有 N 节、我们只有几节」，但根因不同：`Input` 是组件离官方 API 面差得远，
`InputNumber` 是**除了名字与官方没有任何共同点**。

**Input / TextArea / InputGroup**

- `Input.qml` 补官方同名 prop：`prefix` / `suffix` / `addonBefore` / `addonAfter`（字符串或节点二象，
  只能声明成 `property var` 再按 `instanceof Component` 分流）、`insetLabel`、`mode: "password"`
  + `revealed`、`hideSuffix`、`borderless`、`validateStatus`、`maxLength` / `getValueLength` /
  `composition`、四角圆角别名。
- `TextArea.qml` 补 `rows` / `maxCount` / `showLineNumber` + `lineNumberStart` /
  `autosize`（`true` 或 `{minRows, maxRows}`）/ `textareaHeight` / `borderless` /
  `validateStatus` / `maxLength` / `getValueLength`。
- 新增 `InputGroup.qml`（本库原来没有这个组件）：组的 `size` / `disabled` 盖到子控件、
  中间切平四角只留首尾外侧圆角、相邻接缝 1px `color-border`。
- `InputPage.qml` 从 6 节到官方全部 18 节 demo（官方那 23 个 `###` 里余下 5 个是三张 API 表
  加 `ARIA` / `键盘和焦点`，不是 demo）。
- 新增 `tests/tst_input4.qml`（33 个函数、112 处断言）。变异验证 `/tmp/semi_ref/mutcheck_input.py`
  12 处关键决定全部被抓到；其中「TextArea 按码点截断」那半边原本没有用例走，补了一条才抓得住，
  详见 `PROGRESS.md` 已知坑 68。

**InputNumber**

- `InputNumber.qml` 按 `inputNumber/index.tsx` + `inputNumber/foundation.ts` 重写，拆出
  `InputNumberStepper.qml`（对应 `.semi-input-number-suffix-btns`）与
  `InputNumberCurrency.js`（QML 没有 `Intl`，格式表由 Node 的 ICU 落盘）。
- 官方 30 个 prop 全落，含此前跳过的 `currency` / `localeCode` / `currencyDisplay` /
  `showCurrencySymbol` 与 `scientificNotation`。
- `InputNumberPage.qml` 从 4 节到官方全部 7 节，每个 demo 的宽度照抄官方 `style={{ width: N }}`。
- 新增 `GalleryLabel.qml`（demo 里那行小标签，官方 demo 用的是 `<label>`）。
- 调用点跟着改：`ColorPicker` 的百分比框从自造的 `suffixText: "%"` 改成官方 `suffix` 节点，
  `ColorPicker` 与 `SliderPage` 的 `onModified` 改成官方名 `onNumberChange`。
- 新增 `tests/tst_inputnumber.qml`（52 个函数、130 处断言），变异验证 31 处抓到 29 处，
  剩下 2 处逐条查清（一处等价变异、一处 Qt 侧本来就观察不到），详见 `PROGRESS.md` 已知坑 69。

**这一轮的验证方法本身也修了**：截图小程序原来跑在 `offscreen` 上，而 `offscreen` 会**整层丢掉
`MultiEffect` 的内容** —— 所有 `Icon` 都不画，于是「步进器没有箭头」被当成组件 bug 查了一轮。
换 `cocoa` 后三个测试图标全在。同时踩到 QtTest 位置器的两个静默失效调用形式
（`mouseClick(item, button, mods, point)` 四参形式一个事件都送不进去、`keyClick(item, key)` 命中的
是另一个重载），`tst_input4` 里 3 条用例因此红了很久，看着都像组件 bug。两条都记进
`PROGRESS.md` 已知坑 70 / 71。

### 补做：Slider 的能力补齐（2026-10-10）

起因是「官网 slider 有九节，我们只有四节」。查下来是两回事：一部分是计划书的「核心小节」取舍，
一部分是**组件压根没那个能力**。这一轮把能力补齐。

**组件新增**（`src/Slider.qml` 基本重写）

| 能力 | 属性 |
| --- | --- |
| 双滑块 | `range` + `values`（两个值，顺序无所谓，内部按大小当低/高；互相不越界） |
| 垂直 | `vertical` / `verticalReverse`（默认上小下大，反向即上大下小） |
| 刻度 | `marks`（`[{ value, label }]`）/ `showMarkLabel` / `tooltipOnMark` |
| 分段背景 | `railGradient` + `included` |
| 手柄圆点 | `handleDot`（`{ color, size }`，或数组按手柄分别给） |
| 边界值提示 | `showBoundary` |
| 自定义提示 | `tipFormatter`（function），配合 `showValue` 常显 |
| 回调 | `moved(var)` / `afterChange(var)`（松手后） |

**几何换成了「手柄圆心沿整条轨道行走」的模型**（对应 Semi 的 `translateX(-50%)`）：
圆心从 `railStart` 走到 `railStart + railLength`，两端各留 `handleSize/2`。这样值到 min 时
填充天然为 0 —— 上一轮那个「拖到最左边还突出一小块」的特判可以删掉了。

**页面上按官网补齐到 8 节**（原来 4 节）。顺带修掉一处**语义做错**的：「带标签的」在官网指的是
**`marks` 刻度标签**，我们原来做成了「滑块旁边放个文字标签 + 滑块」—— 标题对上了、内容不是一回事。

**这一轮踩到的**

- **`pragma ComponentBehavior: Bound`**。加了刻度和数值气泡两组 `Repeater` 委托后，
  qmllint 刷了十几条 `Unqualified access`（委托里引用外层的 `control.xxx`）。加这个 pragma 就好了，
  库里已有 10 个组件这么做。详见 `PROGRESS.md` 已知坑 31。
- **垂直反向的语义**要看源库实现才对得上：`foundation.ts` 里
  `stepValue = (startPos + len - pos)/len * (max-min) + min`，也就是反向是「上大下小」，
  而默认是「上小下大」。靠猜很容易反。
- **提示的显示时机**照 Semi 的 `computeHandleVisibleVal`：`showValue` 常显；否则只有给了
  `tipFormatter` 时才在**拖动中**显示。所以「基本用法」那几个滑块不会因为加了 tipFormatter 就到处弹气泡。
- **手柄的投影改用 `MultiEffect` 实现**（Semi 的 `@mixin shadow-knob`）：源隐藏、效果项画（连投影一起出）。
  参数是照着目标渲染量衰减曲线定的，不是照抄 CSS 的 alpha（2026-10-15 又重标过一次，见下面那条）。
  ImageView 预览层的缩放手柄同样加上了（它继承的是同一套手柄样式），Switch 的圆钮也加了
  （`shadow-knob` 在源库里就用在 `slider.scss` 和 `switch.scss` 两处）。踩到三条坑记在 `PROGRESS.md` 32~34：
  效果项的可见性不跟源走（会多出「幽灵手柄」）、源挂着 `DragHandler` 时只能用 `opacity: 0` 隐藏、
  阴影 alpha 不能照搬 CSS。
- **尺寸按源库对齐**：手柄 16 → **24**（`$width-slider_handle`）、两端余量 **13**（`$spacing-slider-paddingX`），
  手柄定位也跟着换成「圆心沿整条轨道行走」（Semi 的 `translateX(-50%)` 模型）。拿官网整页截图量过像素、
  并做了同比例并排对比，直径 / 轨道厚度 / 手柄位置 / 填充范围四项一致。详见 `PROGRESS.md` 已知坑 30b。
- **手柄投影改成「渲一次 + 平移」**：原来每个手柄一个 `MultiEffect`，手柄每帧动 → 模糊每帧重算。
  改成隐藏底片 + 两个 `ShaderEffectSource { live: false }` 平移纹理，8 个双滑块实测最长帧 33.1ms → 23.3ms。
  详见 `PROGRESS.md` 已知坑 41。
- **分段背景拖动时卡**：原来用 6 个绑在手柄值上的 `GradientStop`，每帧重建渐变材质 →
  最长帧 34.2ms（60Hz 下掉帧）。改成用新增的 `railContent` 画三块实色后回到 22.7ms，
  与"完全没有渐变"的基线齐平。详见 `PROGRESS.md` 已知坑 40。
- **禁用态和 Semi 不一样**：原来填充用 `colorDisabledBg`、手柄照旧带投影。Semi 的 `-disabled` 是
  「填充换成 `--semi-color-primary-disabled`（blue-2 浅蓝）+ 手柄 `shadow-0` 去掉投影 + 刻度点保留」。
  照官网截图核对了像素值。详见 `PROGRESS.md` 已知坑 36。
- **手柄那圈蓝描边挂错了状态**：Semi 的 `-handle-clicked` 只在**按下**时给 1px 焦点色描边，hover 是
  `background-color: white`（没有视觉变化），我们挂到了 hover 上 —— 鼠标一划过手柄就出蓝圈。
  改完补了 `test_sliderHandleBorderFollowsPress`（默认灰 → 悬停仍灰 → 按下焦点色 → 松开回灰），
  并顺手把 `test_sliderClickTrackJumps` 写成了真正的端到端点击测试。
- **（2026-10-15）手柄的阴影和官方对不上，重做了一遍**。三件事：
  ① **静止态那圈 1px `colorBorder` 描边是多余的** —— 官方 `slider.scss:56` 是 `border: none`，
  那圈贴边的细线其实是 `shadow-knob` 第二层 `0 0 1px rgba(0,0,0,.3)` 的投影；常驻描边等于把
  `-disabled` 的样子画成了静止态。现在底片里叠两层 `MultiEffect`（软层 + 细圈层），描边只在
  按下（1px 主色）与禁用（1px `--semi-color-border` 且投影整个撤掉）两种状态出现。
  ② **模糊参数重标**：Qt 的 `blurMax` 不是 CSS 的 blur radius，且模糊宽度跟着「源尺寸 + 2*blurMax」走，
  所以 24px 的手柄要自己一组数（软层 `blurMax 20` + `shadowBlur 1.0`、细圈 `blurMax 1` + `0.5`，
  alpha 用回令牌的 `.1` / `.3`）。标定与验收全部数值化：目标曲线按 CSS 定义解析算（σ = radius/2 的高斯
  去积圆盘），我们的图 `grabToImage` 出 2x PNG 后纯 python 逐点取亮度，只走上/下两条轴（水平被轨道占了）。
  合成剖面 **改前 RMS 2.59 / 最大偏 7.6，改后 RMS 1.90 / 最大偏 6.6**（满量程 255）；改前那 7.6 出在
  「下缘 4px 处从 17 直接掉到 6」，观感就是一个边缘发硬的光晕，也就是这次要修的东西。剩下那 6.6 在
  圆边缘外 0.5px 那一格，是 `MultiEffect` 最紧一档模糊仍比 σ=0.5 宽造成的能力上限，调参数换不掉。
  ③ **投影精灵排到了刻度标签前面**：官方 DOM 里 handle 在 marks 的 label 之前（`index.tsx:671-672`），
  所以阴影盖不到标签；我们原来相反，投影变宽之后那排字底下多出一片灰。刻度点反过来本来就在 handle 之前，
  该被投影盖住，没跟着挪。
  补了 `test_sliderShadowLayersAreCalibrated`（钉住两层的 `blurMax` / `shadowBlur` / alpha，把参数改回
  照抄 CSS 的 6px/1px 立刻红）和 `test_sliderShadowStaysUnderMarkLabels`（比 children 顺序 = 绘制顺序），
  并给描边那两条测试补上 `border.width` 断言 —— 原来只比颜色，所以「静止态多画一圈灰边」这种错它们看不见。
  十个变异体全部被抓（`/tmp/semi_ref/shadow/mutcheck_shadow.py` 九个参数/描边/可见性的，加 `mutcheck_label_order.py` 那个把 Repeater 挪回投影之前的）。
  详见 `PROGRESS.md` 已知坑 34。
- **刻度标签先压在轨道上、再压在滑块上**：刻度最初照 Semi 的算法挂在**轨道**外沿，而手柄（24px）比轨道（4px）高得多，
  文字首行落在手柄底边上方 4px。改成挂**手柄**外沿（`marksTop = handleRowCenter + handleSize/2 + markGap`），
  水平 / 垂直两个方向都不撞了。详见 `PROGRESS.md` 已知坑 36。
- **刻度标签压在轨道上**：刻度是排在手柄之外的，会把组件撑高，而轨道当时是拿整个组件的高度居中的 ——
  一加刻度轨道中心就下移、正好压到标签。改成「在核心那一行里居中」：`handleRowCenter = handleSize / 2`。
  详见 `PROGRESS.md` 已知坑 33。
- **`Tooltip` 的 `enabled` 原来是空转的**：它的 `HoverHandler` 被 reparent 到 target 上之后
  就不在 Tooltip 的子树里了，`enabled` 得显式接过去。顺手修了。

### 第 14 轮（2026-10-12）：Radio 补齐官方 11 节，顺带把 `RadioGroup` 造出来

官方 `content/input/radio/index.md` 的 16 个 `###` 里 11 个是 demo，我们只落了 4 个；缺的 7 节
有一半**必须先有组容器**（单选组合 / 按钮样式 / 卡片样式 / 纯卡片 / 配置 options 五节都要用
`RadioGroup`），所以这轮的顺序是：先把规格读死，再造组，再补页。

**规格来源**：`radio.scss` + `radio/variables.scss`（令牌）、`radio.tsx` / `radioInner.tsx` /
`radioGroup.tsx`（DOM 与 prop 面）、`radioFoundation.ts` / `radioInnerFoundation.ts` /
`radioGroupFoundation.ts`（状态与通知）。逐条对完发现本库此前有三处凭印象写的规则，全部改掉，
细节记在 `PROGRESS.md` 已知坑 72。最要紧的四条：

- 未选中的圆圈**有**悬浮底色（fill-0）与 focus 描边，`Appearance.h` 里那句「Radio 未选中没有
  hover 底色」是反的；
- 选中标记是官方那枚 **14px 的 `IconRadio`**，不是自画的白色内圈；
- 禁用时 Radio **两种状态都压 0.75**，Checkbox 只压选中那一档 —— 两边共用一组颜色函数在这条上
  不成立，只能各写各的。
- **按钮式那一档既不能竖排、也没有项间距**：16 / 12 的 gap 只挂在方向类上，而方向类
  `&& !isButtonRadio`（`radioGroup.tsx:167`）。第一版只照了「永远横排」那半句，间距仍按通用组
  排 16，加上每颗都留 4 的右内缩 —— 就是肉眼可见的「间隙很大」。官网 DOM 实测：组 `gap:normal`、
  `padding:0`，非末项 `padding-right: 0`（`radio.scss:90-92`），相邻文案块之间正好 4px，
  三档组宽 256 / 256 / 328、高 24 / 32 / 40。补齐后 `test_buttonGroupHasNoItemGap` 用
  `mapToItem` 量渲染位置钉住这条（拿 `chromeLeft` 反推的写法顶不住，见坑 72）。

**Radio / RadioGroup**

- `Radio.qml` 重写：`checked` / `defaultChecked` / `value` / `disabled` / `text` / `extra` /
  `mode` / `type` / `autoFocus` + `toggled` / `changed` / `mouseEntered` / `mouseLeft`，
  四种 `type`（default / button / card / pureCard）与三档 `buttonSize` 全按 scss 的令牌排。
- 新增 `RadioGroup.qml`：`value` / `defaultValue` / `options` / `disabled` / `direction` /
  `type` / `buttonSize` / `mode` / `name` + `changed`。子项搬运沿用 `CheckboxGroup` 那套。
- `Enums` 加 `ChoiceButton` 与 `RadioButtonSize`；`Appearance` 的空框 / 卡片四个函数改名成
  `choiceBox*` / `choiceCard*`（Checkbox 与 Radio 共用），另加按钮式那对
  `radioButtonAddon*`。
- `RadioPage.qml` 从 4 节到官方全部 11 节。官方「禁用」那节要一个 `Toggle disabled` 按钮，
  「高级模式」那节要读回 `checked`，都照做；`style={{ width }}` 在 QML 里没有对应物，
  用 `options` 里的 `width` 字段替。

**Form 页的四处 `Form.RadioGroup` 回到官方写法**

第 12 轮把官方 Form demo 里的 Radio 换成了下拉，理由是「本库还没有 RadioGroup」，现在这个理由
不成立了：已支持的表单控件（`isMonopolize`，是 / 否 + `required`）、表单布局（`性别`，man /
woman）、表单分组（`type` 有效时间 + `answerTime` 答案放出时间，都是竖排）、动态表单（`isAnchor`，
yes / no）四处全部改回。两处保留说明：

- 官方把 `Form.DatePicker` 直接嵌在第二个 Radio 的文案里，本库 Radio 的文案位只收字符串，
  接不下任意子节点，只能把日期框摆到它下面一行（`Loader` + `noLabel` 的 FormItem）；
- 官方 `Form.RadioGroup` 由 `withField` 把 `onChange` 接进 Form，本库 `FormItem` 只按
  `<valueKey>Changed` 接线、而组的信号叫 `changed`，所以 demo 里回写那一行是手写的
  `onChanged: (v) => form.setValue(field, v)`。**这是 Form 侧的缺口，不是 Radio 的**，
  已记在下面「已知问题」第 13 条。

**验证**

- 新增 `tests/tst_radio.qml`（51 个函数、164 处断言），`tests/tst_form3.qml` 加一条
  `test_radioGroupInsideFormItemRoundTripsWithForm`（FormItem 推得进组、点击回得来）。
- 变异验证 `/tmp/semi_ref/mutcheck_radio.py`：79 个变异，**78 个被抓**，剩下 1 个是等价变异
  （`radioGroupFoundation.ts:58` 的 `mode === 'advanced' ||` 那半边在所有可达路径上都被
  `last !== next` 覆盖）。它另外抓到我自己写的两处死代码：`RadioGroup.selectItem` 里那句
  `if (control.disabled) return;` 上游没有、UI 也走不到，删；`toggleNow()` 的 `_off` 守卫只能靠
  直接调用测出来。
- 全量：34 套 / 761 条通过、0 失败（cocoa），`all_qmllint` 0 警告。
- 截图复核：RadioPage 11 节全部渲染正常。按钮式改完再量一次自己这边：三组 **257.875 / 257.875 / 329.875 宽、24 / 32 / 40 高**，官网是 256 / 256 / 328 宽、24 / 32 / 40 高 —— 高度与结构（gap 0、相邻 4px、末项 +4）完全对上，宽度各多 1.875px 是四个汉字的字体 advance 差（Qt 的 PingFang 行宽比浏览器略宽），不是间距算错，所以绝对宽度没写进断言、只钉结构；FormPage 那四处按 1000px 分片看，
  `是否独占资源（Radio）` 与 `申请类型（CheckboxGroup）` 同列竖排、`性别 man/woman`、
  竖排的 `有效时间 / 答案放出时间`、`isAnchor yes/no` 都到位。

### 第 15 轮（2026-10-12）：Rating 按官网重写，补齐 7 个小节

**起点**：`Rating.qml` 的属性面是自造的一套 —— `readOnly`（官方是 `disabled`）、
`size: Enums.Small`（官方是 `'default' | 'small' | number`）、`ratingChanged`（官方是
`onChange`），半星是「画半颗」而不是裁切，`tooltips` / `character` / `allowClear` /
`autoFocus` 全都没有。gallery 只有 5 节，缺 如何引入 与 点击清除。`tst_input2.qml`
里那 4 条 rating 用例把传进去的属性原样读回来（`compare(r.readOnly, false)` 这种），
改坏了也不会红。

**改了什么**

- 属性面照 `semi-ui/rating/index.tsx:16-42` 补齐：`value` / `defaultValue` / `count` /
  `allowHalf` / `allowClear` / `disabled` / `size` / `character` / `tooltips` / `autoFocus`，
  信号 `changed` / `hoverChanged` / `focused` / `blurred` / `keyPressed`。demo 里的
  `style={{color:'red'}}` 映射成控件自己的 `color`（星星颜色本来就是从 `ul` 的 CSS
  `color` 继承下来的）。
- 新增 `RatingGlyph.qml`：`character` 的三条分支（`Icon` / `Text` / `Loader` + `Component`），
  颜色按 CSS `color: inherit` 的等价物传下去。
- 半星改成官方的两层叠画 + 上层按 `(1-diff)*100%` 裁切（`item.tsx:234`）。
- 悬浮预览、点击清除、方向键回绕、回车、`autoFocus` 全部照 `rating/foundation.ts` 抄。
- `RatingPage.qml` 7 节按 `content/input/rating/index.md` 的 jsx 逐行重写：基本用法两行
  （`defaultValue={5}` 与 `size='small'`）、半星两行（3.5 与 3.65 `disabled`）、只读、
  点击清除（`allowClear` true / false 各带一行说明）、文案展现（`tooltips` 五个词 +
  受控 `value`，标题那行跟着显示当前文案）、自定义四行（红心 24 / 红心 48 带 `allowHalf` /
  `赞` 带 `size: 18` / `count: 10`）。
- `tests/tst_input2.qml` 删掉那 4 条空转用例，换成独立的 `tests/tst_rating.qml`。
- FormPage 的「满意度（Rating）」那一行补上 `valueKey: "value"` 与
  `onChanged: (v) => catalogForm.setValue("rating", v)` —— 之前是个裸 `Rating { }`，
  点了不回写 Form（Rating 的提交信号叫 `changed`，FormItem 只认 `<valueKey>Changed`，
  与下面几处 RadioGroup 是同一个缺口）。

**保留与偏离**（都写在 `Rating.qml` 的注释里）

- 官方 `count + 1` 个 `li` 里最后那枚 0×0 的「空星」不搬 —— 它只为 0 分的键盘焦点与
  ARIA 存在，QML 的焦点在控件上。
- `:focus-visible` 用 `_focusByMouse` 近似（`Item` 没暴露 `focusReason`，实测 `undefined`）。
- 0 分时回车不做事：官方那一下会算出 `count + 1` 这种越界值。
- `tooltips` + `allowHalf` 悬在左半时本库也显示文案，官方不显示（它的条件是
  `hoverValue - 1 === ind`，`x.5 - 1` 对不上任何整数下标，而 QML 的 `Tooltip` 接不下受控条件）。

**验证**

- 官方 DOM 实测对照（semi.design 的 rating 页）：`ul` 宽 150、`li` 依次在 0 / 30 / 60 /
  90 / 120、半星 `-first` 宽 12、3.65 → 15.6、未填 `rgba(46,50,56,0.05)`、已填
  `rgb(250,200,0)`、圆角 3px。本库每一项取到同一个数（`test_defaultCellIs24With6Gap` /
  `test_smallCellIs16` / `test_halfStarClipsAtLeftHalf` / `test_fractionalValueDisplays` /
  `test_filledStarsYellowEmptyStarsFill0`）。
- 新增 `tests/tst_rating.qml`：46 个用例函数 / 184 处断言；`/tmp/semi_ref/mutcheck_rating.py`
  打 77 个变异、**77 个全部被抓**。第一轮 78 个里漏了 3 个：`isHalf` 的 `diff > 0` 那半边
  （当时选的用例正好只压 `< 1` 那半边）、以及 `MouseArea` 上 `enabled` 与 `hoverEnabled`
  两层悬浮守卫互相顶包。前者补三条「满星与空星的裁切层必须不可见」，后者按死代码处理 ——
  删掉 `enabled`、只留 `hoverEnabled`，然后两条变异各自都被抓。
- `tests/tst_form3.qml` 另加一条 `test_ratingInsideFormItemRoundTripsWithForm`（点击回写
  formState、`setValue` 推得进 Rating，两个方向各钉一次）。
- 截图复核（cocoa，三片）：7 节全部渲染正常，红心 / 48 大心 / `赞` 字 / 十星四行都在。
  半星那两行取像素核过（`/tmp/semi_ref/pngscan_rating.py`，2000px = 2x DPR，一格 60px）：
  满星的黄色中段 44px，3.5 那行第 4 颗只有 **22px**、3.65 那行 **29px** —— 比例正好是
  12 : 15.6，证明 `Item.clip` 在场景图里真的把整枚图形裁掉了，而不是把图形缩了。
- 全量：35 套 / 806 条通过、0 失败（cocoa），`all_qmllint` 0 警告。

### 第 16 轮（2026-10-14）：PinCode 按官网重写，补齐 5 个小节

**起点**：`PinCode.qml` 的属性面是自造的一套 —— `length`（官方是 `count`）、`masked`
（官方没有这个 prop）、`cellSize` / `digits` / `setDigit` / `appendChar`（全是自造），
`size: Enums.Small`（官方是 `'small' | 'default' | 'large'`），格子是**自画的 Rectangle**、
输入靠一只隐藏的 `TextInput` 统一接管。large 档还按 42×42 画成正方形，官方是 42 宽 × 40 高。
gallery 只有 3 节，缺 如何引入 / 限制验证码格式 / 手动聚焦失焦，多出一节官方没有的「尺寸与掩码」。
`tst_input3.qml` 里那 3 条用例把传进去的属性原样读回来（`compare(def.cellSize, 32)` 这种），
改坏了也不会红。

**改了什么**

- 属性面照 `semi-ui/pinCode/index.tsx:15-19` + `pincode/foundation.ts:4-13` 补齐：
  `value` / `defaultValue` / `count` / `format` / `size` / `disabled` / `autoFocus`，
  信号 `changed` / `completed`，方法 `focusCell(index)` / `blurCell(index)`
  （官方挂在 ref 上叫 `focus` / `blur`，QML 的 `Item` 已经有 `focus` 属性，名字让给它）。
- 每一格直接是一只 `Input`（官方也是 `<Input/>`），底色 / 描边 / 悬浮 / 聚焦 / 禁用
  全部沿用 Input 的令牌。为此给 `Input` 开了两个口子：`paddingH`（原来 readonly）与
  `textAlign`，对应 `pincode.scss:28-31` 的 `input { padding: 0; text-align: center }`。
- `format` 四种取值照 `validateValue`（`foundation.ts:64-79`）逐条抄：`"number"` /
  `"mixed"` / `RegExp` / `(char) => boolean`，未知字符串退化成全放行（上游就是这样）。
- 四个算法照抄：`completeSingleInput`（灌一格 + 前进 / 最后一格失焦并发 `completed`）、
  `handlePaste`（逐格灌、遇非法字符 break）、`handleKeyDownOnSingleInput`（退格 / 删除
  **不判受控**，直接写状态 —— 上游的不一致，照抄并留 `test_controlledBackspaceStillClearsTheCell`）。
- 粘贴：Qt 侧抢不到 `StandardKey.Paste`（`QQuickTextInput::event()` 在 `ShortcutOverride`
  里自己收下了），改成从「一次插进来几个字符」认出来，见坑 74。
- `PinCodePage.qml` 5 节按 `content/input/pincode/index.md` 的 jsx 逐行重写：基本使用三行
  （small / default / large，`defaultValue="123456"`）、受控（`Button` 随机 + `format: "mixed"`
  + `value` 回写）、限制验证码格式（`count=4` 的 large 一行，再四种 `format` 各带一行标签）、
  手动聚焦失焦（`focusCell(2)`）。官方「限制验证码格式」下的两个 `####` 子标题已经被
  docs 解析器并进小节说明，demo 区不重复。

**验证**

- 官方 DOM 实测（semi.design 的 pincode 页）：小 **24×24**、中 **32 高**、大 **42 宽 × 40 高**，
  `margin-right` 6 / 8 / 12 且末项 0，圆角 3，底色 `rgba(46, 50, 56, 0.05)`，
  里面 `input` 的 `padding: 0` + `text-align: center`，字号 14 / 14 / 16。
  demo 容器只有 222.41px 宽，6 格的中 / 大档被 `flex-shrink` 压成 30.41 / 27.07 ——
  所以量宽度取没被压的两行（small 那行、`count=4` 的 large 行），本库
  `test_smallCellIs24With6Gap` / `test_defaultCellIs32With8Gap` /
  `test_largeCellIs42WideBut40Tall` 三个数一一对上。
- 新增 `tests/tst_pincode.qml`：59 个用例函数 / 198 处断言；`tst_input3.qml` 删掉那 3 条空转用例。
- 变异验证 `/tmp/semi_ref/mutcheck_pincode.py`：70 个变异，**66 个被抓**，4 个等价变异
  （`_controlled` 的 `!== undefined` / `!== null` 在 QML 里对「未赋值的 var」同解、
  `number` 正则的空串重复保险、两处官方越界钳位没有可观察效果），都写在坑 74 里。
  这一轮被它抓出来的五处实现问题：粘贴没摘掉格子里的旧字符（整串右移一格）、
  `blurCell` 里 `control.focus = true` 是死代码（留着它「删掉 forceActiveFocus」的变异照样绿）、
  `cellAt` 里按 `objectName` 过滤那圈循环没被测住（`row.children` 就是那几只格子）、
  以及「删掉逐格回写」的 4 条变异一开始全绿 —— 因为敲键并不写断 `text` 的绑定，
  换成「先写断绑定、再改模型」的两条用例才钉住。另有一条不是变异抓出来的：把 `cellAt` 从「按 `objectName`
  数」简化成 `row.children[index]` 之后，测试仍然连着三轮全绿，但 `children` 里混着 `Repeater` 自己、
  位置不稳定，偶尔 `children[0]` 就是它 —— 见坑 74。
- 截图复核（cocoa，三片）：5 节全部渲染正常，三档尺寸 / `count=4` 的 `6688` /
  受控的 `69af41` / 四种 `format` 的标签都在。
- PinCode 接进 `FormItem` 时把 **已知问题 13 的另一半**顶出来了：`FormItem` 按「属性当前有没有值」认值属性，而 `undefined` 正是非受控哨兵，于是 `InputNumber` / `PinCode` / 组容器全被判成「没有 value」，探测钻进控件内部去接它自己的那只 `Input`。改成「当前值挑不到就按 `<name>Changed` 信号判存在性」（`src/FormItem.qml` 的 `valueKeyOf`），FormPage 上 3 + 9 条运行时警告归零，`tst_form3` 补两条各钉一个控件（去掉存在性那一半立刻报 `text ≠ value`）。回写方向的信号名缺口仍在，见已知问题 13。
- 全量：36 套 / 866 条通过、0 失败（cocoa），`all_qmllint` 0 警告。

### 补做：TimePicker 按官网重写，补齐 11 个小节（2026-10-15）

**做了什么**

- `TimePicker.qml` 从「4 个小节的本地简化版」（`value` 是 HH:mm 字符串、`useSeconds`
  自造、信号叫 `selected`）重写成官方 prop 面：`value` / `defaultValue` 吃 Date /
  时间戳 / **严格按 `format` 解**的字符串，`type="timeRange"`、`format`、`use12Hours`、
  三档 step、`hideDisabledOptions`、`disabledHours/Minutes/Seconds`、`disabledTime`、
  `panelHeader` / `panelFooter`、`scrollItemProps`、`triggerRender`、受控 `open`、
  `position` / `autoAdjustOverflow` / `size` / `borderless` / `inputReadOnly` /
  `validateStatus` / `showClear` / `clearIcon` / `placeholder` / `insetLabel` /
  `prefix` / `prefixIcon` / `rangeSeparator` / `disabled`，回调 `changed(date, string)` /
  `openChange` / `focused` / `blurred`。自造的 `useSeconds` 与 `selected` 信号删掉。
- 新增 `TimePickerPanel.qml`（一块面板：header + 列 + footer），`DateScrollColumn.qml`
  补 `wheel` / `cycled` / `unit` / `columnWidth`，`DateFormat.js` 补 12 小时制的
  `a` / `h` 令牌、上下午解析与 `isFormatLike`。
- `TimePickerPage.qml` 重写为官方 11 节，标题逐字对齐 `data/docs.json`。
- 新增 `tests/tst_timepicker.qml`（53 个用例函数 / 150 处断言），`tst_input3.qml` 里
  那 4 条只读 `hours` / `part()` 的空转用例删掉（−12 处断言）。
- 修掉一条 `Input` 的几何缺陷（症状是「时钟图标和清除图标不在同一格」）：布局的右边距原先只看
  `suffixShown`，而 `hideSuffix` 恰恰会在清除按钮出现时把它翻成 false，于是整排往左被推 12px。
  官方 `.semi-input-wrapper` 不留右内边距，后缀图标与 32 宽的 clearbtn 本来就重合在「距右边界 16」
  那一格；顺带补上另外两档 —— 没有后缀时 `input` 自己保留 12 的右内边距（文字右端距边界 44），
  后缀是图标且没被藏时 clearbtn 收成 24 宽并 `flex-end`（图标贴右沿、紧挨后缀）。
  `tst_input4` 加三条用例，四条变异全部打红。
- 顺带把官方细节补回 `DatePicker`：内嵌时间面板用的就是同一个 `Combobox`
  （`monthsGrid.tsx:484`），所以「时 / 分 / 秒」后缀也该只加在选中那格 ——
  `DateTimeColumns` 补上 `unit`。

**与官方的有意差异**（都写进组件头注释）

- 官方 `parseToDate` 拿「今天」补 Date 的年月日，这里统一用 **1970-01-01**：
  TimePicker 的值只表示时刻，测试也才写得确定。
- 受控（传了 `open`）时弹层 `NoAutoClose`，点外面 / Esc 只发 `openChange`，
  跟官方 `visible` 完全由外部决定的语义一致。
- 官方 ref 上的 `focus()` / `blur()` 是被注释掉的空实现，这里只留一个真能用的
  `focusInput()`，**不给自己造一个官方没有、又只能半实现的方法**。
- 没做：`className` / `popupClassName` / `popupStyle` / `getPopupContainer` /
  `dropdownMargin` / `stopPropagation` / `preventScroll` / `aria-*` / `motion` /
  **`timeZone`**（QML 的 `Date` 只有本地时区，仍是待办）。

**验证**

- 变异脚本 `/tmp/semi_ref/time/mutcheck_time.py`：34 个变异，**34 个被抓**、0 条空转。
  其中两条是「先绿后补」的：`texts()` 原来不看 `visible`（header 改成 `visible: false`
  照样算渲染成功）、`onCleared: control.clear()` 与敲字路径互为冗余（删掉接线测试
  仍然绿）—— 前者给 `texts()` 加了可见性过滤，后者把冗余接线删了、变异点挪到
  `Input.doClear`。
- 截图复核（cocoa）：`/tmp/semi_ref/time/page.png` 11 节全在，`panels.png` 四种面板
  （常规 / 12 小时制带 header / range 带 footer / wheel+cycled）逐块对过。
- 全量：37 套 / 922 条通过、0 失败（cocoa），`all_qmllint` 0 警告。
- 三条最贵的实现问题记在 `PROGRESS.md` 已知坑 77：`TapHandler` 在 Qt 6.11 没有
  `held`（读成 `undefined` → `visible` 停在默认 `true` → 整列全灰）、
  「先切 `_typing` 再存 `_typedText`」会让回写绑定吞掉刚敲的第一个字符、
  `RowLayout` 子项尺寸是异步 polish 的（点 0 高的清除按钮 = 点了没反应）。


### 补做：Button 按官方重写，补齐 11 个小节（2026-10-15）

**做了什么**

- `Button.qml` 换成官方 prop 面（`Button.tsx` 的 `BlockButtonProps` + `iconButton/index.tsx`
  的 `IconButtonProps` 取并集）：`tone` / `variant` / `size` / `colorful` 改成
  **`var` + `undefined` 哨兵**，由 `ButtonGroup` 下发、单项写了以单项为准（对应
  `cloneElement` 的展开顺序）；新增 `loading`（`disabled` 优先）、`block`、
  `iconPosition`、`noHorizontalPadding`（`true` / `"left"` / `"right"` / 数组）、
  `ariaLabel`（挂 `Accessible`），以及 Enter / 空格两个激活键。
- **默认 `variant` 从 `Solid` 改成 `Light`** —— 官方 `defaultProps` 就是
  `theme: 'light'`，API 表里也写着 `light`。这条是连锁的，逐处补显式 variant：
  `Modal` / `Popconfirm` / `UserGuide` 三处内部按钮（官方各写着 `theme="solid"`、
  skip/prev 其实是 `type='tertiary'`）+ gallery 的 `Empty / Modal / SideSheet / Form`
  五处 demo。
- 尺寸与形态按 scss 校正：图标按钮是**正方形**（`$width-button_iconOnly_*` =
  控件高 32 / 40 / 24），图标与文字间距 8，`block` 铺满父项，**去掉自造的按下缩放**
  （`--semi-transform_scale-none`）。焦点环 `buttonFocusRing` 加 `variant` 参数照抄
  官方那条 `:not(.borderless):not(.light)` 分支。
- `colorful` 新增 `src/CssGradient.js`：把主题存的 `aiGeneral0..9` 渐变串解析成
  色标铺到按钮底（4 色标、`Gradient.Horizontal`、CSS 的 0% 放右端）。
- `ButtonGroup` 重做成官方语义：`Item` + 内层 row 自己排 x（照 `InputGroup` 那套），
  写入 `groupPosition` 与五个下发值，**相邻按钮中间插分隔条**（整行高的 type 色底 +
  居中 1px × 20px `color-border`）；`outline` 不插线、改成互相压 1px。
  `SplitButtonGroup` 改成**纯容器**：只写首尾 `groupPosition`、按钮间 1px，
  原来自造的 `text` / `icon` / `tone` / `menuEnabled` / `triggered` / `menuRequested` 全删。
- `ButtonPage.qml` 重写为官方 11 节（`如何引入` 不算小节），标题逐字对齐
  `data/docs.json`；`Main.qml` 里两处旧 `SplitButtonGroup` 用法改成新写法。
- 测试：`tst_button.qml` 从 3 条扩到 **47 条 / 168 处断言**；`tst_appearance` 加
  `buttonFocusRing(variant)` 与 `buttonGroupLine` 两条（70 处断言）；
  `tst_controls` 的 5 条 group / split 用例改走 `childItems`（`ButtonGroup` 的根
  从 `Row` 换成了 `Item`，按钮不再直接是根的 children）。

**与官方的有意差异**（都写进组件头注释）

- **多彩文字退成首尾色标的中值**：官方是 `background-clip: text`，Qt Quick 没有等价能力
  （本机 Qt 6.11.2 连 `Item.opacityMask` / `EffectMask` 都没有）。多彩**底**是真渐变；
  `outline + primary` 的字与描边用 `colorAiPurple`（官方本来就是纯色）。
- 官方给多彩图标塞的是 fill 数组，这些 AI 图标只有一条 path，实际只吃到 `fill[0]`
  —— 这里按「单色替身」着色（multiple → 渐变末色标、two → `colorAiPurple`）。
- 官方 `iconButton/index.tsx:96` 的 AI 转圈条件第二支没挂 `colorful`（普通 solid
  tertiary 加载也会转 AI 圈），按「官方 bug 只记录不抄」以 `colorful` 为闸。
- 空格触发官方是「抬起」，Qt 的 Keys 只有 `*Pressed`，改成按下触发。
- 没做：`circle`（`button.scss` 里根本没有 `.semi-button-circle` 的规则，是死 prop）、
  `htmlType` / `className` / `style` / `contentClassName` / `iconSize` / `iconStyle`、
  分裂按钮「菜单展开时按钮换底色」（官方靠内联 `style`，QML 没有对应物）。

**验证**

- 变异脚本 `/tmp/semi_ref/button/mutcheck2.py`：**20 个变异、20 个全部被抓**。
  第一版跑出 5 个「没打红」，查完是变异脚本自己的四种毛病：期望名写错、变异根本没换到
  优先级（外层三元还在先判组）、把 `Keys.onXxx` 改成不存在的名字导致**整个类型创建不出来**
  （只报 `compile()`）、以及一条只调 C++ 助手没查渲染的断言（补了
  `test_focusRingRendersOnKeyboardFocus` 直接查画出来的那圈 `border.color`）。
- 截图复核（cocoa，`--page button --scroll N --shot`）：11 节逐屏看过 ——
  四行主题、方形图标按钮、块级铺满、多彩两块网格（含无文字那块）、
  三种尺寸的组合分隔条与 1px 分裂间隔。
- 全量：**37 套 / 967 条通过、0 失败**（cocoa），`all_qmllint` 0 警告。
- 加载转圈另有两条实测：`Rotation` 当子对象声明只落 `resources`（`transform.length === 0`）、挂进 `transform:` 后 `Item.transformOrigin` 不生效（列表原样 `applyTo`，只有 `rotation`/`scale` 走补偿），必须自己写 `origin.x/y`。两帧抓图（150ms / 450ms）逐字节不同且弧线始终在按钮内，
  回归用例 `test_spinnerRotatesInPlace` + 3 个变异。
- 实现细节与「默认值是错的」这条记在 `PROGRESS.md` 已知坑 78。


### 补做：TagInput 按官方重写，补齐 17 个小节（2026-10-15）

**做了什么**

- `TagInput.qml` 换成官方 prop 面（`tagInput/index.tsx` 的 `TagInputProps`）：
  `value` / `defaultValue` / `inputValue` 用 **`var` + `undefined` 哨兵**区分受控与非受控，
  `separator`（string / string[] / null）+ `split`（自定义拆分函数）、`maxLength` / `max` /
  `maxTagCount` 一律 `-1` 表示没设，`showRestTagsPopover` + `restTagsPopoverProps.position`、
  `showContentTooltip`（`true` / `false` / `({ type: "popover" })` 三档）、`allowDuplicates`、
  `addOnBlur`、`draggable`、`expandRestTagsOnClick`、`showClear` / `clearIcon`、
  `prefix` / `suffix`（string 走 `-text` 那档、Component 走自定义节点）、`insetLabel`、
  `size` / `validateStatus` / `autoFocus` / `ariaLabel` / `renderTagItem`，
  方法 `focusInput()` / `blurInput()`（官方 `focus()` 是「无条件 focus input、
  `!disabled` 才 `handleClick()`」，`blur()` 顺手注销 clickOutside）。
  信号名逐字对齐回调表：`onChange` / `onAdd` / `onRemove` / `onInputChange` / `onExceed` /
  `onInputExceed` / `onKeyDown`，只有 `onFocus` / `onBlur` 改成 `focused` / `blurred`。
- 排布自己写（`relayout()`，不用 `Flow` / `Row`）：官方是 flex-wrap，标签宽
  `min(天然宽, 容器内容宽)`、放不下截断；行高 = 标签高 + 上下外边距（20+1+1 / 24+2+2 / 24+3+3），
  根高 = `max(min-height, 行总高 + 2)`（官方两行实测 58px）。内部输入区宽度照官方
  `.semi-tagInput-wrapper-inputMirror` 的量法：隐藏镜像量字宽 + 14，放不下才把输入区折到下一行。
- `Tag.qml` 重写：补上官方 **white 档**那套令牌（`bg-4` 底 + `rgba(grey-2,.7)` 描边 + `text-0` 字）、
  `maxWidth` 截断（`Text.elide` + `truncated` 透出 `textClipped`）、`disabled` 覆盖
  （tagInput.scss:96-105：外层字段禁用时底变透明、描边不动、文字换 disabled-text）、
  可关闭时右内边距收进 4（`$spacing-tag_closable-paddingRight`）。
- `Appearance.tagInputBorder(tokens, state, status)`：tagInput.scss:77-105。warning / danger
  平时挂浅色边、聚焦换实色；**默认态只有聚焦才画边**（跟 Input 相反，禁用也没有 disabled-border）。
- `TagInputPage.qml` 重写为官方 17 节，标题逐字取自 `data/docs.json`；`FormPage.qml`
  的 TagInput 用法迁到新属性面（删掉自造的 `valueKey`）。
- 测试：新增独立的 `tests/tst_taginput.qml`（77 个用例函数 / 336 处断言），`tst_input3.qml`
  里原来那 3 条空转用例删掉（169 → 162 处断言）；`tst_appearance.qml` 加
  `test_tagInputBorderFollowsStateAndStatus`（70 → 80 处断言）。

**与官方的有意差异**（都写进组件头注释）

- **`focused` / `blurred` 不叫 `onFocus` / `onBlur`**：`Item.focus` 是现成属性，同名信号会把
  整个类型建不出来（与 DatePicker / TimePicker 同一处理）。
- **`prefixIcon` / `suffixIcon` 是本库自有**。官方 `prefix` / `suffix` 收 ReactNode，靠
  `isSemiIcon` 认出「这是一枚图标」从而走 `-icon` 那档（左右 8）；QML 拿不到组件类型，
  所以 string 走 `-text`（左右 12、加粗）、Component 走自定义节点（左右 0），图标另开两个名字。
- **`radius` 与四个分角别名是本库自有**，给 `InputGroup` 还原 `.semi-input-group` 首尾圆角用。
- **`renderTagItem` 收 Component**：官方签名是 `renderTagItem(value, index, onClose)`，
  QML 传不进第三个函数参数。这里约定自定义 Component 的根项自声明 `modelData` / `index` /
  `closeTag`，由 `Loader.onItemChanged` 注入（同 `Select.renderOption` 的做法）。
  不走 `Binding { value: 函数 }` —— 实测即使 `when: false`、目标为 null，
  `Binding` 的 `value` 给 JS 函数照样报 `Cannot assign a function to a property of type var`，
  而且每条标签报一次。
- `restTagsPopoverProps` 只吃 `position`（换成 `placement`），`zIndex` / `trigger` 那些透传项不做；
  `showContentTooltip` 的对象形态只吃 `type`。
- 没做：`className` / `style` / `insetLabelId` / `preventScroll`（都依附 DOM 与浏览器行为）。
- **`active` 只由 clickOutside 收回**：官方 `handleInputBlur`（foundation.ts:209-216）只做
  `setFocusing(false)` + `notifyBlur`，不碰 `active`。所以「焦点被 Tab 或程序拿走」跟
  「点到框外」不是一回事，前者多余标签仍摊开着。原来本地在失焦路径里多写了一句
  `active = false`，按官方删掉，`test_activeSurvivesProgrammaticBlur` 钉住这个不对称。

**验证**

- 官方几何：单行根高 32、两行 58、内部输入区 `padding-left: 0` / `padding-right: 12`、
  镜像 `scrollWidth` 含那 12 —— 这几项是拿浏览器量 `.semi-tagInput` 得到的，所以官方
  `inputWidth = ceil(字宽) + 14`；行盒 28（标签 24 + 上下外边距 2 + 2）、small 档 22、
  `+N` 行盒 20 是按 `tagInput.scss` 的 `$spacing-tagInput_*-Y` 推的。
  内层输入是 `flex-grow`，只喂那个「假想宽度」决定折行。
- 变异脚本 `/tmp/semi_ref/taginput/mutate.py`：**43 个变异，2 个标成等价、41 个全部被抓**。
  前三版分别有 14 / 4 / 2 个「没打红」，逐个查完是四类：期望名写错或写多了（那条测试本来
  就不该抓这个变异）、变异改在框架已经挡过的地方（上游那两句守卫）、浅色主题下 `bg-1`…`bg-4`
  同值（改暗色再断一次才分得开）、以及**两条守卫互相遮蔽**（框内点击那条要靠拖拽路径才露出来，
  见 PROGRESS.md 坑 79）。另外 `onIndexChanged: host.injectCloseTag()` 整行删掉全绿 ——
  是死代码，删了：注入的闭包读的是 `host.index` 当前值，索引变了也不需要重新注入。
- `QTest::keyClick("丙")` 不是「按键没生效」而是 **`ASSERT: "false"` 直接 SIGABRT**
  （`qasciikey.cpp:192`，只吃 ASCII），`typeInto` 因此只打 ASCII，中文一律走属性传入。
- 截图复核（cocoa，`--page taginput --scroll N --shot`）：17 节逐屏看过 —— 标签与 `+N`、
  三档尺寸、warning / error 描边、禁用、前缀 / 后缀 / insetLabel、受控两块、
  自定义 chip 渲染、拖拽分隔与落点竖线。
- 全量：**38 套 / 1045 条通过、0 失败**（`QT_QPA_PLATFORM=offscreen`），`all_qmllint` 0 警告。
- 补一条用户反馈的修正：输入光标**偏上**。`field` 按官方 input 那样写了 `height: 24`，
  而 `QQuickTextInput` 把文字行顶格排，居中的是那个空盒子 —— 光标落在中线上方 3.5px。
  加 `verticalAlignment: TextInput.AlignVCenter` 把行也居中（保留 24 的点击带，更贴官方），
  三档 `positionToRectangle(0)` 的行中心与外框中心现在分毫不差
  （`test_caretIsVerticallyCentered`，删掉那一句立刻报 `10.5 ≠ 12`）。详见 PROGRESS.md 坑 79。



1. **macOS 文件系统不区分大小写**。我写 `main.qml` 时把原有的 `Main.qml`
   （487 行的 QML 预览应用）覆盖了 —— 两者在 macOS 上是同一个文件。
   已从 git 恢复。**新加文件前先确认有没有同名不同大小写的**。
2. **QML 的 `XMLHttpRequest` 默认不允许读本地文件**（报 `Using GET on a local
   file is disabled by default`）。改成 `main.cpp` 里用 `QFile` + `QJsonDocument`
   读 qrc 资源，再 `setProperty` 注入给 root。
3. **子目录里的 QML 文件在同模块内类型不可靠**。页面原本放在 `pages/` 子目录，
   页面里用 `GallerySection` 报 `is not a type`。移到模块根目录后正常。
   代价是根目录文件多，可以接受。
4. **`topPadding` 只有文本类和 Positioner（`Column` / `Row`）有**，给 `Tabs` / `Loader`
   设会报 `Cannot assign to non-existent property`。用 `Item { height: N }` 当间隔。
5. **`Breadcrumb` 用声明式 `BreadcrumbItem` 或 `routes`（旧文档里的 `items` 已作废，
   2026-10-24）、`Tabs` 用 `currentIndex`**（没有 `currentKey`）。
   写页面时先看一眼组件属性，别按官网的 props 名猜。
6. **`GallerySection` 的 demo 区是 `Column`（间距 12），子项自动竖排**。不要再自己写
   `topPadding` 去补间距，也不要在直接子项上用 `anchors`（Column 会给子项设 x/y）。
   这条是第 9 轮改的 —— 之前是 `Item`，一小节写两个子项就会叠在一起。
7. ~~**`GridRow` 的行高只在构造期算一次**~~（**已随组件删除失效，2026-10-23**：
   Grid / Layout 整族按用户决定删除，见 PROGRESS 坑 126）。当年的现场是：子项靠内容
   撑高（比如 `Card`）时，行高按算的那一刻取值，后面的兄弟节点会压上来 —— 给这类
   子项显式写高度。
8. **弹层 demo 在 `--shot` 下抓不到**。页面末尾用
   `if (Qt.application.arguments.indexOf("--shot") >= 0) xxx.open();`
   把第一个弹层打开，正常浏览时这段不生效。
9. **演示用的示例图必须入库**。`ImageView` / `Avatar` 两页原本指向
   `/tmp/shotapp/sample*.png`（早期截图工具的临时目录），重启后目录就没了，
   页面静默退化成占位图。现在放在 `data/img/` 并登记到 `RESOURCES`。
10. **点击与悬停是可以自动验的，但位置器有两种调用形式会静默失效**（2026-10-12 更正）。
    原来这条写的是「QTest 的合成指针事件送不进 QML，所以过滤类特性只能『从外面把状态设进去』」——
    结论下早了，真正的原因两条都已在 `PROGRESS.md` 更正：`init()` 里要 `testCase.visible = true`
    （已知坑 4），以及 **`mouseClick(item, button, modifiers, Qt.point(x, y))` 这种带坐标的四参形式
    一个事件都送不进去**、`keyClick(item, key)` 命中的是另一个重载（已知坑 70）。
    `--search` 那套「从外面注入状态」的写法仍然保留（它验的是渲染，不依赖事件），但**新写交互用例
    前先按坑 70 的调用形式来**，别默认点击测不了。
11. **跳过项是列出来的，不是藏起来的**。`docs.json` 里 `skipped: true` 的组件
    会在侧边栏灰显并标「未实现」、点不动，页面走 `GalleryPlaceholder`。
    只有 `content/ai` 与 `content/other` 两组整体不进 JSON。
13. **`FormItem` 自动探测内层控件会认错人**（2026-10-12 记，2026-10-15 修掉一半）。
    没写 `valueKey` 时它按 `["checked", "value", "values", "text", "color"]` 往下找一层，
    判据是「这个属性当前有没有值」。而 `undefined` 正是本库「非受控」的哨兵，于是
    `InputNumber` / `PinCode` / `Rating` 与 `CheckboxGroup` / `RadioGroup` 都被判成没有 `value`，
    探测钻进控件内部抓住它自己用的那只 `Input` —— FormPage 上跑出 3 条
    `Cannot assign to non-existent property "text"` 与 9 条 `onTextChanged` 对不上信号。
    **已修**：`valueKeyOf()` 在当前值一个都没挑到时改按 `<name>Changed` 信号判存在性，
    控件本身即被正确识别（`innerControl` 是组 / 控件自己，`Form.setValue` 推得进去），
    上面那 12 条警告归零；测试 `test_inputNumberInsideFormItemWiresTheControlNotItsInnerInput`
    / `test_pinCodeInsideFormItemWiresTheControlNotItsCells` 各钉一条，去掉存在性那一半立刻报
    `text ≠ value`。详见 PROGRESS.md 坑 75。
    **未修的那一半**：组与 `Rating` / `PinCode` 的提交信号叫 `changed`（官方 `onChange`），
    且非受控时它们不写自己的 `value`（当前值在 `currentValue` 里），所以
    `Connections` 拼出的 `onValueChanged` 仍接不上**回写**方向 —— FormPage 那几处手写
    `onChanged: (v) => form.setValue(...)`（四处 Radio、CheckboxGroup、Rating）还得留着。
    要一并修得先定「非受控控件用什么统一暴露当前值」。

14. **截图小程序必须跑在 `cocoa` 上**。`QT_QPA_PLATFORM=offscreen` 下走 `MultiEffect` 的内容
    （也就是所有 `Icon`）整层不画，会被当成组件 bug（`PROGRESS.md` 已知坑 71）。另外
    `grabToImage` 只渲染目标项自己的子树，页面底色要放进被截的那一层，否则透明区存成 PNG 是一片黑。

15. **`GalleryApiTable` 的「说明」列不折行，超长那条会压到「类型 / 默认值」列上**（2026-10-21 Carousel 这轮截图复核抓到）。根因在 `Table` 的单元格渲染（`dataSource` 那套只渲染文本、API 表又没给「说明」列定宽），不是 Carousel 的账：实测 `docs.json` 里 `desc` 超 90 字的有 **39 行、涉及 20 个页面**（TimePicker 的 `disabledTime` 298 字最长，carousel 的 `autoPlay` 那条 150 字）。carousel 这轮把 API 表从 0 行补到 20 行之后这条才第一次在截图里露出来 ⇒ 记成全站表格的待办，动它要连带 60 多张 API 表的行高算法，别塞进组件复刻那一轮。

### 补做：Transfer 按官方重写，补齐 13 个小节（2026-10-15）

**做了什么**

- `Transfer.qml` 换成官方 prop 面（`transfer/index.tsx` 的 `TransferProps`）：`dataSource` /
  `type`（`list` / `groupList` / `treeList`，摊平法照 `transferUtils.ts`）/ `value`（`undefined`
  即非受控）/ `defaultValue` / `disabled` / `draggable` / `filter`（`false` 收起搜索框、函数自定筛选）/
  `inputProps` / `emptyContent`（`left` · `right` · `search`）/ `showPath` / `treeProps` /
  `loading` / `virtualize` / `pagination`，六个 `Component` 钩子 `renderSourceItem` /
  `renderSelectedItem` / `renderSourcePanel` / `renderSelectedPanel` / `renderSourceHeader` /
  `renderSelectedHeader`。信号 `change` / `select` / `deselect` / `search` / `pageChanged`，
  方法 `searchBy(value)`。
- 交互逐条照 `foundation.ts`：勾选即搬运（**中间没有搬运按钮**）、左栏永远是全量、
  `handleAll` 跳过禁用项且作用域是筛选结果全部（不分页）、`handleClear` 保留已选的禁用项、
  `updateInput` 顺手把左栏页码打回 1、`handleSortEnd` 是 arrayMove、树那一套是
  `leafOnly` + `disableStrictly` + `defaultExpandAll` + 命中处 `<Highlight>`（**不过滤**）、
  `searchResult` 对 treeList 直接给全集。
- 几何与色令牌照 `transfer.scss` + `variables.scss`：外框 1px `colorBorder` + `radiusMedium` +
  `bg-1`、最小宽 402、高 400、左右两栏各 50% 加一条 1px 分隔线；左栏头 24 高（margin 12/8）、
  右栏头 32 高（margin-top 12）、行最小高 36（内边距 12 / 9）、组标题 28、分页条 padding 12 居中、
  关闭图标 12px 平时 `visibility: hidden`（占位不缩）。
- 新增 `TransferRightItem.qml`：右侧那一行要出现在两个地方（普通列表的 `Repeater` 代理、
  `virtualize` 打开时 `ListView` 的代理），所以拆成独立文件。
- `TransferPage.qml` 重写为官方 13 节，标题逐字取自 `data/docs.json`。
- 顺手开的三条缝：`Checkbox.pressed`（左侧行的 `:active` 底色要用）、
  `Pagination` 页码格的 `objectName`（测试要点第 N 页 —— 2026-10-22 Pagination 整份重写后
  那枚 `"pageCell" + modelData` 编号名撤了，Transfer 测试改成按格子里的数字认门）、
  `Transfer` 的 `bodyHost` / `sourcePanelLoader` 等 `objectName`。
- 测试：`tests/tst_transfer.qml` 17 → 68 个用例函数 / 207 处断言。

**与官方的有意差异**（都写进组件头注释）

- **`search(value)` 改名 `searchBy(value)`**：官方那个绑在实例上的方法在 QML 里和 `onSearch`
  信号同名，建不出来。
- **钩子入参去掉 `on` 前缀**：QML 不允许声明 `property var onXxx`（`on` + 大写是信号处理器的
  保留前缀）。`onSearch→search`、`onAllClick→allClick`、`onSelectOrRemove→selectOrRemove`、
  `onSelect→selectValues`、`onClear→clear`、`onRemove→remove`、`onSortEnd→sortEnd`、
  `renderSourceItem` 的 `onChange→toggle`。
- **`sortableHandle` 没有等价物**：官方是 render-prop（把任意节点变成拖拽触发器），QML 里
  手柄固定由行外壳画在最左，用自定义已选项渲染时也只差这一处。
- **`defaultValue` 会随 `_data` 重播**（用户没动过选区时）：官方只在 constructor 播一次，
  QML 里 `dataSource` 常常后到。`_touched` 标志位保证用户选过之后不再被盖。
- **`virtualize.height: "100%"` 这种字符串高度按「头部以下剩余高度」处理**：QML 没有百分比高度。
- 上游两处不一致**照抄不修**：`onSelect` 收原始项、`onDeselect` 收注入过 `fullPath` 的；
  `.semi-transfer-right-empty` 的 `absolute + height:100%` 让空态文字落在偏下位置。

**验证**

- `tests/tst_transfer.qml` 68 个用例函数 / 207 处断言，`QT_QPA_PLATFORM=offscreen` 全绿；
  变异分 8 批打完约 70 个，全部被抓（三个「打不红」的逐个查完都不是漏测，见 PROGRESS.md 坑 80）。
- 13 个小节逐屏 cocoa 截图复核：拖拽手柄、树形展开箭头与半选框、分页条、完全自定义面板、
  树头部「文件总数：7 个文件（总节点数：10）」都在像素上对过。
- **offscreen 只能看布局，不能看图标**：`MultiEffect` 染色的 `Icon` 在 offscreen 下不画
  （手柄 / 箭头显示成白块或看不见），cocoa 正常。图标相关的复核一律走 cocoa。


### 补做：TreeSelect 按官方重写，补齐 19 个小节（2026-10-15）

**做了什么**

- `TreeSelect.qml` 换成官方 prop 面（`semi-ui/treeSelect/index.tsx` 的 `TreeSelectProps`）：
  `treeData` / `keyMaps` / `treeNodeLabelProp`、`value`（`undefined` 即非受控）+ `defaultValue` +
  `onChangeWithObject`、`multiple` + `checkRelation` + `leafOnly` + `autoMergeValue` +
  `disableStrictly`、`showClear` / `showSearchClear` / `placeholder` / `searchPlaceholder` /
  `emptyContent`、`size` / `validateStatus` / `borderless`、搜索一族 `filterTreeNode` /
  `treeNodeFilterProp` / `showFilteredOnly` / `remote` / `searchPosition` / `triggerTagWrap` /
  `searchAutoFocus`、展开一族 `expandAll` / `defaultExpandAll` / `defaultExpandedKeys` /
  `expandedKeys` / `autoExpandParent`、异步 `loadData(node, done)` + `loadedKeys`、
  `maxTagCount` + `showRestTagsPopover` + `restTagsPopoverProps.position`、
  `dropdownMatchSelectWidth` / `virtualize` / `defaultOpen` / `clickToHide` / `labelEllipsis` /
  `insetLabel` / `prefixIcon` / `suffixIcon` / `ariaLabel`、钩子 `renderSelectedItem` /
  `triggerRender` / `outerTopSlot` / `outerBottomSlot`。信号 `change` / `select` / `search` /
  `expand` / `clear` / `load` / `visibleChange` + `focused` / `blurred`，方法 `open()` /
  `close()` / `clearAll()` / `searchBy(value)`。
- 交互逐条照 `foundation.ts` + `treeUtil.ts`：内部身份是 `key`（没给就退成 pos 串 `0-1-2`）、
  对外一律 `value ?? key`；`normalizeKeyList` 负责「子全选折成父」与 `leafOnly` 投影；
  `calcDisabledKeys` 让 `disableStrictly` 连子孙一起标灰；搜索命中自动展开祖先、
  `showFilteredOnly` 才收掉未命中分支；`triggerSearch` 时勾选后清词（**只在多选那条路径上**，
  官方 `handleMultipleSelect` 末尾）；`loadedKeys` 去重（受控那份也算已加载）。
- 几何与色令牌照 `treeSelect.scss` + `tree.scss` + `variables.scss`：触发器最小高 24 / 32 / 40、
  圆角 3、1px 边框（静止态官方是 `transparent`）、左内边距 12（单选）/ 4（多选）、箭头与清除
  按钮各 32 宽、**箭头不旋转**；下拉 `bg-3` + 圆角 6 + 最小宽 230 + **没有 max-height**；
  行高 28、左内边距 8、缩进 20/级、箭头 12 + 右 8、复选框 16 + 右 8；带搜索时下拉首行 49
  （8 + 32 + 1px `fill-0` 分隔线）。
- 新增 `TreeSelectOption.qml`：同一行要出现在两个地方（普通列表的 `Repeater` 代理、
  `virtualize` 打开时 `ListView` 的代理），所以拆成独立文件，并开 `rowAt(i)` 缝给测试点。
- `TagInput` 补 `borderless`（多选触发器里那圈内嵌输入框官方是 `border: hidden` + 透明底）。
- `TreeSelectPage.qml` 重写为官方 19 节，标题逐字取自 `data/docs.json`。
- 测试：新增 `tests/tst_treeselect.qml` 88 个用例函数 / 389 处断言；`tst_input3.qml` 里那
  3 条 TreeSelect 空转用例删掉（162 → 154 处断言）。

**与官方的有意差异**（都写进组件头注释）

- **`search(value)` 改名 `searchBy(value)`**：官方那个绑在实例上的方法与 `onSearch` 信号同名，
  QML 里建不出来（同 Transfer，坑 80）。
- **钩子入参去掉 `on` 前缀**：`triggerRender` 的 `onSearch / onClear / onRemove` →
  `search / clear / remove`；`componentProps` 没给（QML 里没有「把整份 props 回传」的用法）。
- **`prefixIcon` / `suffixIcon` 沿用本库 `Select` 的叫法**：官方是 `prefix` / `suffix`
  （ReactNode）+ `arrowIcon` / `clearIcon` / `expandIcon` 四枚图标覆盖，本库图标一律按名字串给，
  没有逐组件的图标覆盖 prop。
- **`showLine` / `expandAction` 没实现**：官方这两条都由内层 `Tree` 消费
  （`index.tsx:1427-1441` 与 `TreeContext` 传下去），本库 `Tree` 自己也没有连线与「点行展开」，
  先不造半个。
- **DOM 类 prop 不进 QML**：`dropdownClassName` / `dropdownStyle` / `optionListStyle` /
  `getPopupContainer` / `stopPropagation` / `mouseEnterDelay` /
  `mouseLeaveDelay` / `autoAdjustOverflow` / `zIndex` / `insetLabelId` / `position`。
  `motion` / `motionExpand` 是**例外**（2026-10-23 补）：官方那条展开/收起动画不是 CSS 装饰，
  是 `NodeList` 把动画区间折进 `NodeCollapsible` 的真实高度过渡（200ms，`height` + `opacity`），
  端口按 `Tree` 那一版复刻了 —— 两条闸的分工照上游：点箭头看 `motionExpand`，
  外部换 `expandedKeys` 与换数据那两支看 `motion`（详见 PROGRESS.md 坑 127）。
- **`remote` 那节 demo 官方传了 `loading`，但 `TreeSelectProps` 里没有这个 prop**（是 `Select` 的），
  不跟着造。
- **`clearAll()` 多发一次 `onSearch('')`**：官方走 `clearInput()` 不发搜索回调；「清空之前那份
  `selectedKeys` 的祖先要并进 `expandedKeys`」这条已经照抄（坑 81）。
- **上游把「子级全禁用」的父级也标禁用**（`calcDisabledKeys` 的后半段），这条毛病不抄。

**验证**

- `tests/tst_treeselect.qml` 83 个用例函数 / 368 处断言，`QT_QPA_PLATFORM=offscreen` 全绿；
  变异三批打完 82 个 + 1 个复合，5 条「打不红」逐个查完都不是漏测（三层禁用守卫互相同步遮蔽、
  两条等价变异），详见 PROGRESS.md 坑 81。
- 19 个小节逐屏 cocoa 截图复核：多选标签与 `+1` 折叠、`triggerTagWrap` 换行撑高、
  搜索框在触发器与在下拉里两种排布、严格禁用的灰字、虚拟化长列表、异步加载的转圈、
  自定义 Trigger 与自定义已选项渲染都在像素上对过，页面无运行时警告。
- **offscreen 只能看布局，不能看图标**：`MultiEffect` 染色的 `Icon`（箭头、清除、搜索前缀、
  复选勾）在 offscreen 下不画，图标复核一律走 cocoa（坑 71）。


**补做（2026-10-16）：「搜索框位置」两节点了没反应**

- 根因两条，都在 `TreeSelect` 的触发器搜索那一块：① 外层的开合逻辑挂在
  `TapHandler { enabled: !triggerSearch }` 上，而 QML 里**父级 TapHandler 永远抢不过子
  `TextInput`**（探针实测 `taps=0`）—— 于是搜索框在触发器时点哪儿都没反应；
  ② 那格输入用的是 `Input { borderless: true }`，而 `borderless` 只在「非聚焦且非悬浮」时
  透明，聚焦时它自己画一圈 1px，看着就是「焦点环没包住整个 TreeSelect」。
- 做法：`TapHandler` 一直开着并走官方 `handleClick` 的三条分支（含 `clickTriggerToHide`
  与「有搜索词时点触发器不收」），两个内层输入区各垫一层**按下即放行**的 `MouseArea`
  （看得见这次点击、不抢，光标与标签关闭按钮都照常）；内层换成裸 `TextInput`
  （官方 `treeSelect.scss:183-205` 就是把 `.semi-input-wrapper` 的 border 覆盖成 `none`，
  连 `-focus` 也是 `none`）；焦点判定把里层输入框并进来（`Item.activeFocus` 不向祖先传递），
  并且**这个「或」只写在一处** `refreshFocus()` —— 两个来源（触发器的 `onActiveFocusChanged`、
  输入框的 `onFocused` / `onBlurred`）都调它，点触发器时读它维护好的 `_hasFocus`。
- 顺带：Controls `Popup` 的 `CloseOnPressOutside` 不认 anchor，点触发器会先被它收掉、
  连搜索词一起被 `afterClose()` 清掉，然后我们的处理再把它开回来。`PopupBase` 因此新增
  `dismissOnOutsidePress`（默认 `true`，其余组件行为不变），TreeSelect 关掉它、
  自己用一层壳 + `PointHandler` 按落点判断（壳子每实例一个，避开坑 79 的同父查重）。
- 验证：新增 5 条用例（点单选输入框开下拉 + 焦点环 + 光标落点 + 内层不带第二圈框、
  点 TagInput 开下拉、有词时点触发器不收、`clickTriggerToHide` 两种取值、点外面收起），
  变异第五批 9 个：第一轮 1 个存活（「焦点环忽略里层输入框」—— 并集当时写了两处，拆掉任一处
  都有另一处兜着），合成 `refreshFocus()` 之后重跑 **9 个全部被抓**；cocoa 截图复核两种触发器
  的焦点环都包住整块、下拉正常出现、内层没有第二圈框。

**补做（2026-10-16）：「搜索框位置」第二个的标签排布不对**

- 现象：选中几项之后，`+N` 直接盖在第一个标签上，标签之间互相贴住，整块比官方右移。
- 三条根因，全在 `TagInput` 被 TreeSelect 复用这一段：
  ① `relayout()` 要不要给 `+N` 排位置，读的是 `restHost.visible`，而它绑 `restCount > 0`
  重算得更晚 —— 由 `visibleTagList` 触发的那次排布跑在前面，`+N` 从没被排过位；
  ② 自定义标签节点（`renderTagItem`）在**独立** TagInput 里横向外边距确实是 0，
  但官方在 TreeSelect 里给它 `.semi-tag { margin: 1px 2px }`（`treeSelect.scss:155-157`），
  我们一刀切成 0，标签之间就成了 0 间距；
  ③ 官方还有 `.semi-treeselect-multiple-tagInput-{notEmpty,empty} .semi-tagInput
  { margin-left: ∓4 }`（:246-257）我们没接，加上 `borderless` 时那 1px 边框内缩该一起去掉
  （:208 把 border 覆盖成 `hidden`），三处合起来差 2~4px；
  ④ 第二轮反馈「标签跑到 TreeSelect 外面」：`relayout()` 里行高与居中用的是
  `item.height` / `host.contentHeight` 这类**绑定属性**，`Loader` 量出尺寸那一轮它们还没刷新，
  读到 0 就把该项按 `(行高 − 0)/2` 往下推，第二个标签下沿超出 32 的触发器（实测 `y=14`）。
  改成 relayout 只调现算的 `bandHeight()` / `visualHeight()`，直接读 `itemLoader.implicitHeight`。
- 做法：`TagInput` 的折叠判定抽成现算的 `isCollapsed()`（公开的 `collapsed` 只是它的镜像），
  `relayout()` 调函数而不是读 `restHost.visible`；行高与居中同样改成现算的 `bandHeight()` /
  `visualHeight()`（读 `itemLoader.implicitHeight` 这个测量源，不读 `item.height` 那种绑定）；
  再开 `tagMarginX`（默认 0，独立用法不变），TreeSelect 传 `spacing-super-tight`；
  `tagField` 按有没有选值加 `∓4` 的 `anchors.leftMargin`；
  `leftSlot` / `rightSlot` 的 `anchors.*Margin` 改成 `borderless ? 0 : 1`。
  搜索框在下拉那一档的 `tsTagRow` 同步：整行让 2、相邻 2+2=4（官方 `TagGroup` 的 `+N` 也是 `.semi-tag`）。
- 验证：`tst_taginput` 80 → 83 个函数（+N 排布、`tagMarginX` 两档、borderless 内缩），
  `tst_treeselect` 88 → 91 个函数 / 406 处断言（触发器标签行四段横向间距 + 纵向居中、
  空值光标与单选文字对齐、非触发器标签行的行首与间距）；变异第六批 11 个 + 第七批 3 个
  全部被抓（`/tmp/ts_probe/mut5.py` / `mut7.py`，第六批第一轮 `+N` 那条存活，换成现算判定后转红）。
  **live gallery 探针**（`tests/tmp_ts_gallery_probe.qml`：直接 `Loader` 载入 `TreeSelectPage.qml`、
  勾四项、打印每个标签相对触发器的坐标）是这一轮唯一抓到 ④ 的手段 —— 独立小程序的
  固定 `defaultValue` 场景不触发那一轮绑定滞后。cocoa 截图：`Beijing` / `Shanghai` 之间 4、
  `+2` 排在其后 2、输入区再让 4，两个标签同行居中、都在框内。


### 补做：Upload 按官方重写，补齐 25 个小节（2026-10-16）

**做了什么**

- `Upload.qml` 换成官方 prop 面（`semi-ui/upload/index.tsx:60-147` 的 `UploadProps` + `:251-282`
  的 `defaultProps`）：请求一族 `action` / `formData`（官方 `data`）/ `headers` /
  `withCredentials` / `timeout` / `name` / `fileName`；列表一族 `fileList`（传了即受控）+
  `defaultFileList` + `listType`（`list` / `picture` / `none`）+ `uploadTrigger` +
  `showUploadList` / `showClear` / `showPicInfo` / `showReplace` / `showRetry` /
  `showTooltip`（`true` / `false` / 物件三档）/ `hotSpotLocation` / `validateMessage` /
  `validateStatus`；选择行为 `multiple` / `disabled` / `draggable` / `directory` / `accept` /
  `limit` / `maxSize` / `minSize` / `capture` / `promptPosition`；外观 `itemStyle` /
  `picWidth` / `picHeight` / `prompt`（string 或 Component）/ `dragIcon` / `dragMainText` /
  `dragSubText`；钩子 `beforeUpload`（bool / 物件 / Promise 三态）/ `beforeRemove` /
  `beforeClear` / `afterUpload` / `transformFile` / `customRequest`；`Component` 槽 `trigger`
  （官方 children）/ `dragIconComponent` / `fileListTitle`（string / ReactNode / 函数三档）/
  `previewFile` / `renderFileItem` / `renderFileOperation` / `renderThumbnail` /
  `renderPicInfo` / `renderPicPreviewIcon` / `renderPicClose`；方法 `insert(raw, index)` /
  `upload()` / `openFileDialog()` / `removeAt(index)` / `clear()` / `retry(uid)` /
  `replaceAt(index)`。
- 状态机逐条照 `semi-foundation/upload/foundation.ts`：进度乘 `PROGRESS_COEFFICIENT 0.95`、
  `checkFileFormat` 支持后缀 / `mime/*` / 精确 MIME、`checkFileSize` 按 KB×1024 比字节、
  `limit === 1` 直接替换且仍发 `exceed`、`handleRemove` / `handleClear` 先判 `disabled`、
  `buildFileItem` 只给 auto 触发补 `uploading`（`defaultFileList` 原样入列，
  `index.tsx:289`）、`showTitle` 取 `limit !== 1 && fileList.length`（`index.tsx:902`）、
  `fileListTitle` 的函数 / ReactNode 两形态（`index.tsx:917-928`）。
- 几何与色令牌照 `upload.scss` + `variables.scss`：卡片 250×52 圆角 medium、预览块 36×36
  四周 8、名称 14/600 右截断、大小 12 text-2、进度线 4px 上下各 4、图片墙 96×96 间隙 8、
  加号热区 2px 虚线 `fill-0`（悬浮 `fill-1`、按下 `fill-2`）、关闭图标 16 右上 8/8、
  序号条 24 高 `rgba(22,22,26,.3)→0` 渐变、拖拽区 2px 虚线 + 内边距 12 +
  `tertiary-light-default`（legal / 悬浮转 `primary-light-default` + primary 描边并隐藏副文案），
  **官方全程无过渡动画**。虚线是 `Canvas` 描的（`Rectangle` 画不出 dashed）。
- `UploadPage.qml` 重写为官方 25 节，标题逐字取自 `data/docs.json`；顺带把 Upload 那 11 节
  描述里的 `<Notice>` / `<div>` / `<br />` / 游离反引号清掉（其余页面早就是纯文本）。
- 测试：`tests/tst_upload.qml` 从 6 个用例函数 / 11 处断言扩到 **113 个函数 / 419 处断言**。

**与官方的有意差异**（逐条写进 `src/Upload.qml` 文件头）

- **本端口没有 HTTP 层**：`action` / `formData` / `headers` / `withCredentials` / `timeout`
  只记录不发请求；没给 `customRequest` 时选中即 `success`、percent 100。要看进度就得按官方
  「自定义请求」那节自己回调 `onProgress` / `onError` / `onSuccess`。
- **官方 `data` 改名 `formData`**：`Item` 自带 `data`（子对象列表），同名会把内置属性盖掉。
- **信号改名**：官方 `onClear` / `onRetry` 与实例方法 `clear()` / `retry()` 撞名（同坑 80 那条），
  QML 里分别叫 `cleared` / `retried`；`onDrop` → `dropped`、`onOpenFileDialog` → `dialogOpened`。
- **QML 拿不到 `File` 与字节数**：`insert()` 收路径字符串或带 `size` / `name` / `url` /
  `status` / `percent` / `preview` 的物件；`size` 给数字按官方 `getFileSize` 格式化、给字符串
  原样显示，`maxSize` / `minSize` 只在数字那档校验。`directory` 只能选到文件夹本身
  （这份 Qt 打包没有目录遍历类型），不展开成目录内文件。
- **官方「图片裁切」那一节整节跳过**：6 个 demo 全靠 `crop` + 浏览器端图片编辑器
  （`react-easy-crop`），本端口没有裁切面板。
- **上游两处入口的顺序本身不一致**：`handleChange`（选文件 / 拖拽，`foundation.ts:332-364`）
  把 `transformFile` 放在补 uid **之前**、`exceed` 收到未截断的整批；`insertFileToList`
  （`:503-538`）相反。本端口两条入口统一按前者，不复制这处不一致。
- **`fileListTitle` 的两种形态靠入参属性名判**：QML 里 ReactNode 与函数都是一个 `Component`，
  只能问 `"fileList" in item || "onClear" in item || "clearText" in item`。

**顺带修掉的两个库层缺陷**（都由这一页的 cocoa 截图逼出来）

- **`Avatar` 有图时整块不画**：`MultiEffect.maskSource` 指到普通 `Rectangle` 上会得到一张全透明遮罩
  （Qt 只接受 `ShaderEffectSource` / `layer.enabled` 的项 / `Image`，`qquickmultieffect.cpp:715-724`），
  头像只剩灰底 —— `AvatarPage` 的「图片」一节同样受影响。改成遮罩单独用一层
  `Rectangle { visible: false; layer.enabled: true }`。判据只能取像素（`offscreen` 下 `MultiEffect`
  整层不画）：修前头像带内 0 个饱和像素，修后 224 个、四角仍是白底。
- **`Upload` 列表卡片右侧操作区与文字叠在一起**：信息区原来按「一颗默认关闭按钮」写死预留 40，
  官方那节 demo 的自定义操作区是三颗按钮 = 104 宽，`130KB` 直接压在眼睛图标上。
  官方是 flex（信息区 `flex:1 + min-width:0`），所以操作区宽了被压的是信息区。

**验证**

- `tests/tst_upload.qml` 113 个用例函数 / 419 处断言（原先只有 6 个函数 / 11 处断言），
  `QT_QPA_PLATFORM=offscreen` 全绿；全量 39 个 `tst_*.qml` 逐文件跑一遍 0 失败；`all_qmllint` 0 警告。
- 变异 33 个逐条打，**全部被抓**。上一轮存活的 `prompt-always-inline`（把 `promptInline`
  写成「只要有 prompt 就 inline」）这轮补红：原来那两条断言（`x >= 触发区右边界`、
  `y >= 触发区下沿`）在误判下照样成立，补上「bottom 那一行要真把行高撑出来」
  （`implicitHeight` 差一个 prompt 高）才抓到 —— 报的是 `32 ≠ 49`。
- 本轮新查出的库层事实：**`Item.visible` 读回来是「有效可见性」**
  （`qquickitem.cpp:6657-6661` 返回 `effectiveVisible`），所以 `Loader.active: <父>.visible`
  等于把实例化交给窗口显隐，祖先一隐藏 `promptSlot` / `triggerSlot` 就不实例化、
  `implicitHeight` 掉成 0。改成绑模型条件，并补了 `active` 绑法两个变异 +
  `test_geometryDoesNotFollowAncestorVisibility` 钉住（详见 PROGRESS.md 坑 82）。
- cocoa 逐节截图复核（列表卡片 / 图片墙 / 拖拽区 / 三种 prompt 位置 / 头像触发 /
  自定义标题两形态 / 预览层 / 悬浮态的关闭与重试）。


### 补做：Toast 按官方重写，补齐 11 个小节（2026-10-16）

**做了什么**

- `Toast.qml` 从「一个 `C.Popup` + `text` + `open()`」整个换成官方的命令式面。
  官方是一组静态方法（`semi-ui/toast/index.tsx:100-242`），QML 的 type 上没有静态方法，
  所以整套 API 落在实例上：`info` / `success` / `warning` / `error` / `open`（`useToast` 那支
  定 type 为 `default`）/ `create` / `close(id)` / `destroyAll()` / `has(id)` / `update(id, opts)` /
  `config(opts)`，四个类型方法都吃 `string | opts`，返回 id。一个 `Toast {}` 就是
  `useToast()` 的 `[toast, contextHolder]` 那一对。
- Options 逐条照 `toast.tsx:33-60` 的 `propTypes` / `defaultProps`：`content`（字符串或 Component）/
  `icon` / `showClose`（**官方默认 `true`**，本地原来写死 `false`）/ `textMaxWidth` 450 /
  `duration`（**单位是秒**，原来当毫秒用）/ `stack` / `id` / `onClose` / `motion`；
  Config 照 `ConfigProps`：`top` / `left` / `right` / `bottom` / `zIndex` 1010 / `theme` /
  `duration` / `getPopupContainer`，`config()` 里逐项按官方那样验类型
  （`theme` 必须在 `strings.themes`、`zIndex` / `duration` 必须是 number）。
- 列表与计时语义照两个 foundation：`toastListFoundation.ts` 的 `hasToast`（只看 `list`，
  正在退场那条不算）/ `updateToast`（浅合并）/ `removeToast`（离场那条挪到渲染末尾）/
  `destroyAll`（整体卸载、不放退场动画、不跑 `onClose`），`toastFoundation.ts:67-95` 的
  `duration * 1000`、`duration` 非零数字才起 timer、悬停 `clearCloseTimer_` / 离开
  `startCloseTimer_`（**重新计满整个 duration，不是续上剩余**）、按 id 更新后 `restartCloseTimer`、
  静态 `Toast.close(id)` 不触发该条的 `onClose`。
- 新增 `ToastItem.qml`（一张卡片 = `.semi-toast` 盒子 + `.semi-toast-content` 本体），几何照
  `toast.scss` + `variables.scss`：本体上下内边距 12 / 左右 8、四周外边距 12、圆角 medium、
  字号 14 字重 600 行高 20、文字恒为 `text-0`、图标 `large` 20 按 tone 着色、文本块左右各 12
  且 `max-width: textMaxWidth`、关闭按钮是小号 borderless tertiary 且外壳 `height 20 / margin-top -2`、
  投影 `--semi-shadow-elevated`；`theme: light` 只换底色 + 1px 同色描边（**官方 light 不动文字色**，
  本地原来把 light 的文字也染成了 tone 色），且 `default` 型没有 light 规则。单行卡片
  68 高（浏览器实测同值），图标 + 文本时文本块左偏移 32。
- 堆叠照 `index.tsx:85-98` + `toast.tsx:139-179` + scss：`stack` 是**容器级**开关（最后一次调用赢，
  作用到全部卡片），未展开时每条外面是零高度外壳（卡片互相叠住），展开由整叠区域的悬停驱动；
  `translate3d(0,0,reservedIndex*-10px)` + 外壳 `perspective: 280px` / `perspective-origin: center 280px`
  换算成等价的 2D：`Scale{ origin: (带宽/2 - x, 280 - y); s = 280/(280+10*reservedIndex) }`，
  展开时投影撤掉、外壳高度按 300ms 动画撑开。
- 进出场照 `animation.scss`：300ms、`translateY(-100%) ↔ 0` + `opacity 0 ↔ 1` 共用一条曲线
  （`reveal` 一个量同时驱动两者），曲线按坑 50 用 `Easing.OutBack`；`motion: false` 按官方
  `CSSAnimation` 的「时长 0 的动画」处理（挂载即结束、离场即销毁）。
- `ToastPage.qml` 重写为官方 11 节，标题逐字取自 `data/docs.json`：如何引入 / 普通提示（含
  官方那支 `throttle(fn, 10000, {trailing:false})`）/ 其他提示类型（Success 那支照抄官方的
  **字符串入参**）/ 多色样式 / 链接文本（单行与多行两支富文本 Component）/ 修改延时 /
  手动关闭（`duration: 0` + `close(id)` 收回）/ 更新消息内容（同 id 先 info 后 success）/
  销毁所有 / 消费 Context（改页面属性，已弹出的那条跟着变）/ 创建不同配置 Toast
  （第二份 Toast 用 `getPopupContainer` 塞进页面上那个自定义容器）。
- 三处老调用点迁到新 API：`UploadPage.notify()` 按 tone 分发到 `success/warning/error/info`、
  `TagInputPage` 两条超限提示改 `maxToast.warning(...)`、`TokensPage` 的色值复制提示改
  `copyToast.success(...)` 并把 `duration: 1600` 改成 `1.6`。

**与官方的有意差异**（逐条写进 `src/Toast.qml` 文件头）

- **`top` / `left` / `right` / `bottom` 不能写成元素属性**：`Item` 上这四个名字是 FINAL 的锚点线
  （`qquickitem.h:90-94`），同名声明会 `Cannot override FINAL property` 把整个类型打死。
  官方本来也只有 `Toast.config({ top })` / 调用入参两种形式，QML 侧就只留这两种。
- **官方 wrapper 是 `position: fixed; top: 0; height: 0; width: 100%`，`bottom` / `right` 在 CSS 里
  属于过约束被丢掉的那两个**（写了也不动）。本端口让四个都真的生效：`top` 显式置 `undefined`
  才让位给 `bottom`，`left` + `right` 同时给则收窄这条横带。
- **同时有多条在退场时官方只留最后一条**：`removeToast` 每次都新建 `removedItems` 并整体替换 state，
  所以上一条的退场动画被截断。本地让每条各自播完再销毁（这条是上游的毛病，按「只记录不抄」处理）。
- **`icon` 收图标名字符串**（官方是 ReactNode）；`style` / `className` / `direction`（RTL）不收，
  本端口没有 DOM 样式，整个库也还没做 RTL。
- **`zIndex` / `top` 这类容器量落在宿主实例上**（官方是进程级单例 wrapper），两份 Toast 各管各的。
- **卡片默认挂到窗口的 `Overlay.overlay`**（官方 append 到 `document.body`）。搬运挂在子层 wrapper 上
  而不是宿主自己身上：`Item` 在 QML 侧没有 `window` 属性，`parent: Overlay.overlay` 在实例还没进场景时
  只求值一次、拿到 `null` 就永远不补（详见坑 83）。

**验证**

- `tests/tst_toast.qml` 39 个用例函数 / 187 处断言（含下面「堆叠悬停抽搐」补做那一条），
  `QT_QPA_PLATFORM=offscreen` 全绿；全量 40 个 `tst_*.qml` 逐文件跑一遍 0 失败；`all_qmllint` 0 警告。
- `tst_feedback.qml` 里那 3 条只验「Popup 能不能开」的旧 Toast 用例删掉（它们验的是本地旧实现，
  改完就失效），该文件剩 11 个函数 / 36 处断言只管 SideSheet 与 Notification。
- 三处老调用点（`UploadPage` / `TagInputPage` / `TokensPage`）迁到新 API，`duration` 从毫秒改成秒。
- 变异 **58 个**逐条打（脚本 `tests/tmp_toast_mutate.py` + `tmp_toast_mutate2.py`，两份变异回执，日志 `/tmp/toast_mutate.log`）：
  图标与着色 9、几何令牌 12、动画 4、堆叠 3、无障碍 1、宿主默认值 6、计时 6、列表语义 3、
  堆叠开关与排布 6、wrapper 容器 8。第一轮 54 个被抓，其中**三个 `BUILD FAILED` 不算「被抓」而是
  「没打上」**（替换文本在原处不合法：只换了三元绑定第一行、把信号处理函数换成 `{ }`），
  第二批连整条绑定一起换才真正验到；剩下一个是真存活 ——
  `按 id 更新后不再重计`（删掉 `_applyToRecord` 里那次 `_scheduleAutoClose`）照样全绿，因为那条用例只断
  「卡片还在」，而记录在退场动画播完之前本来就不消失。改成**让原始到点时间先过去**再断
  （`duration 0.6`，350ms 时更新，650ms 时断 `items[0].removed === false`）才咬住；
  第二批把这 4 个重打，**全部被抓**。
- cocoa 逐节复核（`tests/tmp_toast_shot.qml` 走 `tst_semi -input`，图在 `/tmp/toast_probe/`）：
  四型图标按 tone 着色 + `open()` 的 default 型不带图标、light 档底色与 1px 描边跟着 tone 而文字仍是
  `text-0`、`showClose: false` 少一颗 ×、`icon: "star"` 自定义、`textMaxWidth` 450 与 120 两档换行、
  富文本单行（带链接）与两行、堆叠收起（后面两条按透视缩小往下露边）与悬停展开（真指针路径）、
  第二份 Toast 落进自定义容器、`motion: false`。
  gallery 页 11 节另用 `semi-gallery --page toast --scroll <pt>` 逐屏看过，标题与按钮文案对齐官方；
  顺带把 `data/docs.json` 里「创建不同配置 Toast」那节残留的 `<Notice>` / `</Notice>` 与游离行内空格清掉
  （该文件是 Qt 资源，改完要重建 `semi-gallery` 才生效）。


**补做（2026-10-16）：堆叠的 Toast 悬停时来回抽搐**

- 现象：`stack` 那一叠展开之后，鼠标停在卡片**之间的缝隙**里，整叠就一直收起→展开→收起地抖。
- 根因是收起条件写错了：本地把开关挂在「任一卡片被悬停」上（`_onHover` 里现算 `any`），
  而卡片本体之间那 24px 是 `margin`，谁的本体都不属于 —— 指针一进缝隙就判成「离开」→ 收起 →
  卡片又叠回指针底下 → 命中本体 → 展开 → 再进缝隙，自激。加上 `y` 走 300ms 动画，动画途中
  卡片会**从静止的指针底下经过**，翻转点更密。
- 官方为什么没这问题：`handleMouseEnter/Leave` 挂在 `innerWrapper` 上，而展开时每条外面那个
  `zero-height-wrapper` 的 `height` 被设成卡片实测高（`toast.tsx:173-176`），于是卡片之间的 margin
  也被那片连续区域盖住，指针落在缝里不算离开。**展开态的命中区域比触发它的卡片本体大**，
  这就是滞回（hysteresis）。
- 做法：触发与收起分成两个区域 —— 展开仍由「悬停到某张卡片本体」触发（官方一致），
  收起改成只由「离开整叠区域」触发（`band` 上挂一条 `HoverHandler`，`_onHover` 里不再算 `any`）。
  `band.height` 在 `_relayout()` 里按整叠外框算（收起 = 一条卡片高，展开 = 逐条累加，非堆叠 = 0，
  因为官方 `.semi-toast` 是 `pointer-events: none`，不堆叠时缝隙不吃指针）。
- 顺带修掉同一条路径上的一个一帧滞后：`_relayout()` 原来读卡片上绑出来的 `card.flowHeight`，
  而 `_syncStack()` 刚把 `card.stackExpanded` 赋完就调过来，绑定还没重算，读回来是上一轮的 0
  （坑 81 那一族）。`flowHeight` 改成卡片上的函数 `flowHeight()` 现算，宿主只调函数。
- **测法上的教训**：`TestCase` 把指针放到缝隙里**不动**是测不出来的 —— Qt 只在 motion 事件上重算
  hover，静止的合成指针看到的是「上一条卡片仍然 hovered」的假象。探针改成每帧在原位 ±1px 抖
  （`tests/tmp_toast_jitter_probe.qml`，缝隙处 40 帧翻 9 次 → 修后 0 次），回归用例
  `test_hoverInGapKeepsStackExpandedWithoutOscillating` 也按「翻转次数 = 0」断，而不是只断一次
  「现在还是展开的」。变异补打 6 个（`tests/tmp_toast_mutate3.py`）：退回旧的 `any` 收起规则、
  `band.height` 置 0、非堆叠也盖住整带、`_onPileLeave` 空实现、整叠高度算小、`flowHeight()` 永远按
  卡片高 —— 全部被抓。

### 补做：Notification 按官方重写，补齐 9 个小节（2026-10-16）

**做了什么**

- `Notification.qml` 从「一个 `C.Popup` + 一条文案」整个换成官方的命令式面。官方是一组静态方法
  （`semi-ui/notification/index.tsx:101-218`），QML 的 type 上没有静态方法，所以整套落在实例上：
  `open` / `info` / `success` / `warning` / `error`（四个类型方法把 `type` 钉死在自己那档）、
  `close(id)` / `destroyAll()` / `has(id)` / `update(id, opts)` / `config(opts)`，
  展示方法**只吃 options 物件**并返回 id —— 这点和 Toast 不一样：官方 Toast 有
  `typeof options === 'string'` 那支简写，Notification 没有（`{...defaultConfig, ...'x'}`
  只会把字符串摊成一堆数字 key），本地照抄并留了一条用例钉住。
  一个 `Notification {}` 就是 `useNotification()` 的 `[notification, contextHolder]` 那一对。
- Options 逐条照 `notice.tsx:36-56` 的 `NoticeProps` + `index.tsx:52-58` 的 `defaultConfig`：
  `title` / `content`（字符串或 Component）/ `icon` / `showClose` / `duration` 3（**单位秒**）/
  `position` `topRight` / `motion` / `id` / `theme` / `top` · `bottom` · `left` · `right` /
  `zIndex` 1010 / `getPopupContainer` / `onClick` / `onClose` / `onCloseClick`；
  Config 照 `notificationListFoundation.ts:20-28` 的 `ConfigProps`（只有
  `top / bottom / left / right / duration / position / zIndex / direction`，**没有**
  `getPopupContainer`，那个是单条通知的量）。
- 合并语义是这轮最费事的一条：`addNotice` 再合一次，`has(id)` 走
  `{...notice, ...noticeOpts}`，而 `noticeOpts` 已经被垫过 `defaultConfig` 六档 ——
  所以 `duration / position / motion / title / content / zIndex` **每次更新都被重写**
  （`update(id, {content})` 会把标题抹成空串），`theme / icon / showClose / onClose / top…`
  只在调用方给了才覆盖。`type` 排在 `...opts` **之后**，`info({type:'error'})` 仍是 info。
- 列表与计时语义照两个 foundation：`addNotice` 是 **prepend**（`bottom` 位置因此
  「新的往上长、旧的贴底边」）、正在退场那条挪到渲染末尾 `[...notices, ...removedItems]`、
  `has(id)` 只看还在位的、静态 `close(id)` **不跑**那条的 `onClose`（计时到点与 × 才跑）、
  × 先 `onCloseClick(id)` 且 `stopPropagation()`（卡片的 `onClick` 不能被顶起来）、
  悬停进 = `clearCloseTimer` / 出 = `startCloseTimer`（**重新计满整个 duration**）、
  `destroyAll()` **会播退场动画**（和 Toast 相反）且不跑 `onClose`、`zIndex` 只在第一次建
  wrapper 时写进样式（官方文档原话「首次设置一次生效」）。
- 新增 `NotificationItem.qml`（一张卡片 = `.semi-notification-notice` 盒子，不含那 20px 外边距），
  几何全部用浏览器实测对过（harness `tests/tmp_notice_dom.html`）：内边距 上 16 / 右 12 / 下 16 / 左 20、
  四周外边距 20（相邻折叠 ⇒ 首条前 20、条间 20、末条后 20）、圆角 medium、投影 `--semi-shadow-elevated`；
  图标列宽 24、字形 `large` 20 顶对齐、右外边距 12；正文列右外边距 8；关闭按钮 24×24；
  标题 16 / 600 / 行高 22、下外边距 4，正文 14 / 400 / 行高 20，两者都 `overflow-wrap: break-word`；
  行高 = `max(图标 20, 关闭 24 只在显示时, 正文列高)` ⇒ 实测 78 / 58 / 56 / 52 四档；
  `theme: light` 走 `color-*-light-default` 底 + 1px 同色（strong 档）描边，且该 1px 走 content-box
  所以盒子 +2，`-light.-default` 与 `-light.-info` 共用一条规则（官方 scss:107-112）。
  宽度：`min-width: 320px` 落在 content-box ⇒ 边框盒最小 352，内容撑开那一支同样是边框盒
  （左右 padding 也要加），整列被拉成最宽那条的宽度、封顶 `可用宽 - 40`。
- 进出场照 `animation.scss`：300ms、按位置换轴（`top` 走 -Y、`bottom` 走 +Y、`left` 走 -X、
  `right` 走 +X）、曲线 `cubic-bezier(.62,.63,0,1.13)` 按坑 50 的口径取 `Easing.OutBack`，
  `reveal` 一个量同时驱动位移与透明度；`motion: false` 按「时长 0 的动画」处理。
- `NotificationPage.qml` 重写为官方 9 节，标题逐字取自 `data/docs.json`：如何引入 / 普通通知 /
  不同位置弹出（两排 `ButtonGroup` 摆六档）/ 带有图标的通知（默认四型 + 自定义图标三支）/
  多色样式（`theme: light`）/ 链接文本（富文本 Component + 两条 `TextLabel { link: true }`）/
  修改延时（`duration: 10`）/ 手动关闭（`duration: 0` + 排队 id + `close(最旧)`）/
  更新内容（同 id 每秒重开，`content: "updated"`）。

**与官方的有意差异**（逐条写进 `src/Notification.qml` 文件头）

- **`top` / `left` / `right` / `bottom` 不能做成元素属性**：`Item` 上这四个名字是 FINAL 的锚点线
  （`qquickitem.h:90-94`），同名声明会把整个类型打死，只从 `config({...})` 与调用入参进。
- **`getPopupContainer` 每次重算**（官方只在创建 wrapper 那一次读），容器换了就跟着换。
- **`icon` 只收图标名**，所以官方示例里「用 `style` 给图标单独染色」做不到，图标色一律跟着 `type`；
  `title` / `content` 的 ReactNode 换成 `string | Component`。
- **关闭按钮字形 12 而非 16**：本端口 `IconButton` 一律取控件高度的一半，是全库约定，不为它单改。
- **`position` 非法值退化成容器默认位置**（官方在 `noticesInPosition[position].push` 处直接抛）。
- **`has(id)` / `update(id, opts)` 是显式化的隐藏分支**：官方 Notification 的静态面只有
  `addNotice` / `removeNotice` / 五个展示方法 / `close` / `destroyAll` / `config`
  （`index.tsx:101-202`），「按 id 更新」只能靠再调一次带同 id 的展示方法走到 `addNotice` 里的
  `has(id)` 分支。本地把这条分支摆到明面上，语义与它一致（Toast 那边 `has` / `update` 是官方就有的）。
- `style` / `className` / `direction`（RTL）不收。

**验证**

- `tests/tst_notification.qml` 67 个用例函数 / 294 处断言，`QT_QPA_PLATFORM=offscreen` 全绿；
  全量 41 个 `tst_*.qml` 逐文件 1410 通过 / 0 失败；`all_qmllint` 0 警告。
- `tst_feedback.qml` 里那 3 条只验「Popup 能不能开」的旧 Notification 用例删掉。
- 变异四批共 **69 条全部被抓**（`tests/tmp_notice_mutate.py` / `2` / `3` / `4.py`，四份变异回执）：合并与 key 在场语义、`type` 钉位、`zIndex` 只写一次、
  prepend 顺序、三条关闭通路、`onClick` 抑制、悬停暂停与重计、`destroyAll` 两面、六档位置排布、
  折叠外边距、图标映射与着色、light 盒子 +2、行高四档、break-word、无障碍、容器换尺寸重排。
  首批与次批各有一条是「锚点在原处根本没换上」的空打（不算被抓），后续批次重打命中。
- **像素复核抓到一条同源断言漏掉的 bug**：`naturalWidth` 的内容撑开那一支漏算左右 padding，
  卡片宽 = 正文自然宽 ⇒ 一行放得下的正文被白折成两行（52 → 72），而 68 条用例全绿 ——
  因为宽度断言全在拿 `naturalWidth` / `columnWidth` 这些同源量互相对。补的断言落在独立观测量上
  （`implicitHeight === 16 + 20 + 16`），变异脚本再打四条（含「只漏左 padding」）全部被抓。
  截图口径也换了：独立 `qml` 小程序的 `grabToImage` 回调在这台机器上永远不来（帧在走、返回 `true`），
  改成把探针写成 `TestCase` 走 `tst_semi -input`（样板 `/tmp/semi_ref/notice/shot.qml`，
  卡片用 `getPopupContainer` 收进被抓那层），详见 PROGRESS.md「验证手段」与坑 84。
- gallery 页 9 节另用 `semi-gallery --page notification --scroll <pt> --shot` 逐屏看过，
  标题、按钮文案与右侧锚点导航对齐官方。

### 补做：Progress 按官方重写，补齐 12 个小节（2026-10-16）

**做了什么**

- `Progress.qml` 从「`value` + `tone` + `showText` + 自画 `Canvas` 环形」重写成官方 `ProgressProps`
  （`semi-ui/progress/index.tsx:14-35`，默认值在 `:74-88`）：`percent` / `type`（`line` | `circle`）/
  `size`（`default` | `small` 只作用于环形 | `large` 只作用于条状）/ `direction` / `stroke` /
  `strokeGradient` / `strokeLinecap` / `strokeWidth` / `orbitStroke` / `showInfo` / `format` /
  `indeterminate` / `motion` / `circleWidth` / `ariaLabel` · `ariaValueText` · `ariaLabelledBy`。
  官方的 `width` 在 QML 里撞 `Item.width`（FINAL），改名 `circleWidth`。
- 取色算法 `semi-foundation/progress/generates.ts` 整个搬成 `src/ProgressStroke.js`（`.pragma library`）：
  档位表按 `percent` 升序、比首档小回 `STROKE_DEFAULT`、比末档大取末档、落在两档之间取**上一档**，
  `strokeGradient` 才在相邻两档间插值出一个纯色（官方 `generateColor` 永远带 `index` 调
  `generateGradients`，所以**不是空间渐变**，整条换一个色）。`formatToHex` 那套
  hex / 缩写 hex / rgb / rgba / hsl / hsla / Semi 令牌一并搬过来，令牌查表由调用方注入
  （官方走 `getComputedStyle`，QML 侧没有 CSS 变量）。**排序前先拷贝**（官方 `s.sort()` 就地改调用方数组）。
- 几何照 `progress.scss` + `variables.scss`，并用浏览器实测对过数（harness `tests/tmp_progress_dom.html`）：
  条状横 4（`large` 6）、轨道圆角 3、`overflow: hidden`；文本 `min-width 45` + 左外边距 16 + 字重 600，
  容器高度仍是 4 ⇒ 轨道被挤成「宽 - 45 - 16」（200 宽实测 139）；竖条 `flex-direction: column`
  所以进度块**从顶部往下长**、文本在下方上外边距 8。环形直径 `width || (size==='default' ? 72 : 24)`、
  `r = (直径 - strokeWidth) / 2`、`C = 2πr`、`dashoffset = (1 - p/100)C` + `rotate(-90deg)`
  ⇒ 本端口直接画弧（`startAngle -90`、`sweepAngle = p * 3.6`），`indeterminate` 换固定 30% 弧 + 整圈 1.2s 转。
- 两套动画分开实现：数字 `linear 300ms` + 每帧取整（`rest` 回写精确值），宽度 / 弧长 CSS transition
  300ms `cubic-bezier(.62,.05,.36,.95)`（**不受 `motion` 管**）；曲线按坑 50 的口径解析拟合，
  分别取 `InOutCubic`（最大偏差 .030）与 `InOutQuad`（.012）。不确定态滑块 1.6s 一轮
  （880ms 走 `-120%→300%`，再 720ms 停在 300%）。
- `ProgressPage.qml` 重写为官方 12 节（标题逐字取自 `data/docs.json`）：标准的进度条 6 条（含 `size: large`
  与 `height: 8`）/ 不确定态 2 条 + 2 环 / 百分比文本 4 条（含 `format: percent*10 + "‰"`）/
  垂直 5 条一排（含 `size: large` 与 `width: 8`）/ 环形 4×72 + 2×100 / 小号环形 / 动态改变进度 /
  自定义中心文字（`75Days` / `Done` / `showInfo: false`）/ 圆角方角边缘 / 自定义进度条颜色（4 档令牌）/
  自动补齐颜色区间（正反两组 + 一条 `large` 65%）。
- 连带迁移：`Upload.qml` 两处调用点从 `value` / `tone` 换成 `percent`（图片卡那个手画 `Canvas` 圈
  直接换成 `Progress { type: "circle"; size: "small" }`）；`Appearance` 里 `progressThickness` 与
  `progressTrack` 随旧实现删掉（`progressRail` 还有 Slider 在用，留着）；`tst_display.qml` 里那 4 条
  旧 Progress 用例删掉，全部搬到新的 `tst_progress.qml`。

**与官方的有意差异**（逐条写进 `src/Progress.qml` 文件头）

- **`width` 改名 `circleWidth`**：`Item.width` 是 FINAL，同名声明会把类型打死（与坑 83 / 84 那族同因）。
- **`aria-valuenow` / `aria-valuemin` / `aria-valuemax` 无处落地**：`Accessible` 附加属性只有
  `role / name / description / id / ignored / labelledBy / labelFor`（`qquickaccessibleattached_p.h:56-62`），
  数值只能开 `readonly` 属性（`clamped` / `numberValue` / `sweepAngle` …）给使用者与测试读；
  `aria-valuetext` 落到 `Accessible.description`。
- **`Accessible.labelledBy` 不能用绑定**：Qt 的 setter 见 `nullptr` 就 `qmlWarning` 并 `return`，
  且每次求值往 `m_relations` 追加一份 ⇒ 改成 `onAriaLabelledByChanged` 里「给了才写一次」，
  写回 `null` 清不掉关系（官方这时会摘掉 `aria-labelledby`）。
- **`stroke` 给字符串只支持纯色**：官方条状那支是 `background: linear-gradient(...)`，能画空间渐变；
  `Rectangle.color` 画不了，需要渐变请自己铺 `Rectangle.gradient`。
- **`format` 只收函数**：官方 propTypes 允许直接给节点，但给节点会在它自己那行 `format(percNumber)` 抛。
- **`percent` 给 `NaN` 退化 0**（官方在 `componentDidUpdate` 里 `throw`）。
- **`size: "large"` 的环形只有 24**：官方算式是「`default` → 72，其余一律 24」，照抄不修。
- **透明度按小数读**：官方 `parseInt(a)` 会把 `hsla(… / 0.5)` 解析成 0（全透明），本地读成 0.5。
- **竖条文本也上 `text-0`**：官方 `-vertical` 那档漏写 `color`（继承 body 色）。
- `id` / `className` / `style` 的 ReactNode 形式不收；`motion` 只收 bool（官方还收函数 / 物件）。

**验证**

- `tests/tst_progress.qml` 51 个用例函数 / 264 处断言，`QT_QPA_PLATFORM=offscreen` 全绿；
  全量 42 个 `tst_*.qml` 逐文件 **1491 通过 / 0 失败**；`all_qmllint` 0 警告。
- 断言一律落在渲染项上（`progressTrack` / `progressRail` / `progressInner` / `progressRing` /
  `orbitPath` / `arcPath` / `innerArc` / `progressInfo`），颜色与尺寸写死字面量
  （`#0d2e3238` = `colorFill0` light、`#3bb346` = success light、`#1c1f23` = `text-0`、
  45 / 16 / 8 / 72 / 24 / 35% / 30%），改坏组件里的常量就会红。
- 变异三批去重共 **81 处，79 处被抓**（`tests/tmp_progress_mutate.py` / `2` / `3`，三份变异回执）。2 处存活查清是**等价变异**：排序前把拷贝顺序反过来
  （排完序同解）、`Component.onCompleted` 内两条语句换序（中间没有别的信号）。
  首批存活的 5 处全部有了下文，其中三处是真漏测、补了用例才咬住：① 档位查表被换成夹过的 `percent` ——
  示例档位都在 0..100 内，夹与不夹同解，得把末档定在 `percent: 110` 才分得开；② 滑块起点 `-1.2`
  与首次渲染的两条保险互相遮蔽 —— 把赋值收成一份（守卫只 `return`）之后各自都能见血（坑 81 同族）；
  ③ 关键帧第一段的 `to: 3.0` 被第二段的 `from: 3.0` 遮蔽，断言改成「比值必须**渐近**穿过
  `(2.3, 2.9)`」，跳上去的写法立刻红。
- gallery 页 12 节用 `semi-gallery --page progress --scroll <pt> --shot` 逐屏看过（条状六档厚度、
  竖条从上往下长、30% 弧的不确定环、139px 轨道 + 500‰、72 / 100 / 24 三种环、`75Days` / `Done`、
  档位圈 10% 走绿、正反两组渐变在 6% 一处红一处绿、65% 那条紫色 `large`）。
  `strokeLinecap` 圆角 / 方角在默认 4px 笔画下肉眼分不出（官方同样如此），另用 16px 笔画的抓图探针
  放大确认渲染真的换了帽形（`tests/tmp_progress_shot.qml` → `/tmp/prog_caps.png`）。

### 补做：Spin 按官方重写，补齐 6 个小节（2026-10-16）

**做了什么**

- `Spin.qml` 从「只有 `size`（`Enums.*`）+ `color` 的一只弧」重写成官方 `SpinProps`
  （`semi-ui/spin/index.tsx:15-25`，默认值在 `:46-52`）：`size`（`small` 14 / `middle` 20 /
  `large` 32，缺省 **`middle`**，用的是官方字面值不是本库 `Enums.Default`）、`spinning`（缺省 true）、
  `delay`（ms）、`indicator`（`Component`，官方 ReactNode）、`tip`、`content`（默认属性 = 官方 children）。
  删掉自造的 `visible: control.enabled`（官方 Spin 没有禁用态）。
- **补上第二种形态：包裹**。官方一有 children 就换 `-block`（`display:block` + 宽高 auto），
  于是根节点被内容撑开；指示符那条 `-wrapper` 是 `position:absolute; width:100%; top:50%;
  translateY(-50%); text-align:center` ⇒ 整块浮在内容正中；`-children` 压到
  `$opacity-spin_children` = 0.5（`-hidden` 时回 1）；`-block::after` 那层 `z-index:1` 的透明遮罩
  负责挡住穿透点击（官方注释：解决嵌套 Spin 穿透）。
- **延迟语义照两处代码拼**：`getDerivedStateFromProps`（`index.tsx:64-79`）+
  `foundation.updateLoadingIfNeedDelay`（`foundation.ts:22-34`）⇒ `delay > 0` 时「关掉立刻藏、
  开了等 `delay` 毫秒才露」。官方构造函数把 `loading` 初始化成 `true`，所以「一上来就
  `spinning` + `delay`」是**立刻可见**的，只有「先 false 再 true」那条路真的延迟 —— 可观察行为，照抄。
- 两档转速分开：默认那只弧 `& > svg` 走 `$animation_duration-spin_wrapper-spin` = 600ms，
  给了 `indicator` 换 `-animate` 那档 = 1600ms，且 `-animate` 是 `inline-flex`、尺寸跟着指示符自己。
- `SpinPage.qml` 重写为官方 6 节（标题逐字取自 `data/docs.json`）：如何引入 / 基本用法 /
  尺寸（small · middle · large 各带一行标签）/ 带文字的（`tip: "I am loading..."` 包一个
  1px 主色边框、圆角 4、左内边距 8、两段 `<p>` 的方块）/ 自定义指示符（`Icon { name: "loading" }`）/
  延迟显示（`Button` 切 `spinning` + `delay: 1000`）。原来那节自造的「颜色」删掉 —— 官方没有这一节，
  改色是 FAQ 里给 `.semi-spin-wrapper` 写 `color`，本端对应成 `color` 属性。
- 连带迁移：`Select` / `Upload` / `TreeSelectOption` 三处 `size: Enums.Small` → `size: "small"`。

**与官方的有意差异**（逐条写进 `src/Spin.qml` 文件头）

- **`tip` 只收文字**（官方 ReactNode）；`wrapperClassName` / `style` / `childStyle` 不提供 ——
  QML 侧直接给控件写 `width` / `height` / `anchors`。
- **`user-select: none`**（加载中不许选中文本）没有对应开关。
- **不抬绘制层叠**：官方 `-block::after` 的 `z-index:1` 会盖在指示符上面，本端遮罩排在最后声明、
  效果一致（它是全透明的），但没有 CSS 那套层叠上下文。

**验证**

- `tests/tst_spin.qml` 24 个用例函数 / 78 处断言（`tst_controls.qml` 里那 2 条旧 Spin 用例删掉，
  32 → 28 处断言）。全量 43 个 `tst_*.qml` offscreen 逐文件 **1525 通过 / 0 失败**；
  `all_qmllint` 0 警告。
- 断言落在渲染项上（`spinContent` / `spinWrapper` / `spinBox` / `spinCanvas` / `spinIndicator` /
  `spinTip` / `spinMask`），令牌值写死字面量（14 / 20 / 32 / 0.5 / 600 / 1600 / 20 行高 / `#0064fa`）。
  位置断言**不能用 `mapToItem`**：那只格子每帧在转，`mapToItem` 会把自身 `rotation` 算进去
  （实测报出 106.05 / 46.03），改成逐层累加 `parent.x/y` 的 `centreOf()`。
- 遮罩那条是端到端验的：内容里放一个 `MouseArea`，`spinning` 时 `mouseClick` 打不进去、
  关掉才打得进（顺带钉住「不包裹时遮罩不拦事」，否则 Select / Transfer 那些浮在角落的 Spin
  会顺手吃掉点击）。
- 变异 `tests/tmp_spin_mutate.py` 打 23 个，**全部被抓**（变异回执）。
  首轮回放时 S17（去掉 tip 的横向居中）**0 红**：那条用例里 tip 恰好是 Column 里最宽的一项，
  锚点写不写都一样 ⇒ 补一条反向的 `test_narrowTipStillCentredUnderWideArc`
  （`size: "large"` + tip `…`，弧比字宽）并加 `verify(t.width < box.width)` 防它自己退化成空转。
  三个真 bug 是这条流程逼出来的：`-wrapper` 盒子高度写 0 ⇒ 整块往下偏半格；
  `Column` 只管 y ⇒ tip 比弧宽时弧贴左；`mapToItem` 的旋转。
- gallery 6 节用 `semi-gallery --page spin --scroll <pt> --shot` 逐屏看过（三档弧的彗尾渐变、
  包裹那节「弧 + tip」整块在 200×80 内容里居中、自定义指示符那只 `loading` 图标、
  延迟那节按钮点下去 1s 后才出弧）。

### 补做：Skeleton 按官方重写，补齐 4 个小节（2026-10-17）

**做了什么**

- `Skeleton.qml` 从「一块会呼吸的灰矩形」重写成官方 `SkeletonProps`（`semi-ui/skeleton/index.tsx`）：
  容器是 `active`（缺省 **false**，本地原来缺省 true）/ `loading`（缺省 true）/ `placeholder`
  （`Component`，官方 ReactNode）/ `content`（默认属性 = 官方 children），语义照 render：
  `loading` 为真只渲染那层 div 里的占位，为假时**直接渲染 children**、div 都不生成。
- **补上官方五个占位件**（`item.tsx` 的 `Generic` + `Paragraph`）：`SkeletonAvatar`（`size`
  六档 20 / 24 / 32 / 48 / 72 / 128、`shape` `circle`（半径 50%）| `square`，且这两个 prop
  **只有头像有** —— `Generic` 里那两个类名是 `type.toUpperCase() === 'AVATAR'` 才拼的）、
  `SkeletonImage`（100% × 100%，自己不带尺寸）、`SkeletonTitle`（100% × 24）、
  `SkeletonButton`（115 × 32，唯一宽高都写死的一档）、`SkeletonParagraph`（`rows` 缺省 4，
  每格 16 高、下边距 10，最后一格 60% 宽且没下边距）。公共底座抽成 `SkeletonBlock.qml`
  （对应官方的内部类 `Generic`）。原来那个 `circle: true` 是自造的，删。
- **流光改成会走的带**。官方动的是背景图：`linear-gradient(90deg, fill-0 25%, fill-1 44%,
  fill-0 88%)` + `background-size: 400% 100%` + `background-position: 100% → 0%`，
  1400ms `ease` 无限循环（`$animation_duration-skeleton-highlight`）—— 高亮自左向右扫过。
  本地原来是「整块在 fill-0 / fill-1 之间呼吸」，方向和形状都不对。Qt 的 `Rectangle.gradient`
  只有元素自身 0..1 那一段、也没有渐变起点终点可动，所以每帧把带重新换算进窗口：
  窗口左沿 = `0.75 × (1 − phase)`，三个色标换算成窗口内位置，**掉在窗口外的色标塌到窗口边上、
  颜色取窗口边上的采样值**（等于多一个和边重复的色标，画出来不变）⇒ 五个色标恒在 0..1 且单调。
- `active` 是容器上的类、靠后代选择器点亮，所以占位件自己没有 `active` prop：`SkeletonBlock`
  沿父链认领 `isSkeletonHost`（同 `GallerySection` 找外壳的写法），Paragraph 的每格也一样点亮。
- `SkeletonPage.qml` 重写为官方 4 节：如何引入 / 基本使用（`Switch` 切 `loading`，
  头像·图·标题·段落 rows 2·按钮各一个）/ 组合使用（**六个**组合 demo 全数落地：图片和标题、
  统计数字、头像和标题、居中段落和按钮、头像标题和段落、表格）/ 加载动画（`active`）。
  原来那节自造的「active true/false 对比 + 一段解释文字」删掉 —— 官方没有。

**与官方的有意差异**（逐条写进 `src/Skeleton.qml` / `src/SkeletonBlock.qml` 文件头）

- **`style` / `className` 不提供**，官方 demo 里的 `style={{ width: 200, height: 150 }}`
  就是这里的 `width: 200; height: 150`。
- **占位根节点的高要写 `implicitHeight`**：容器在 loading 时按占位节点的 `implicitHeight` 撑
  （官方那层 div 是 `height: auto`），只写 `height` 容器不会跟着长。
- **官方那层 div 的流式排版交给占位根节点自己**：要 100% 宽写 `width: parent ? parent.width : 0`，
  要竖排用 `Column`（QML 没有普通流）。
- **`SkeletonImage` 的 100% 高是容器高**：容器不给高它就是 0 —— 官方同理，所以官方 demo 都配着
  `style` 的高度用。
- **`shape: circle` 的 50% 在 QML 侧是 `min(w,h)/2` 的像素圆角**，画不出非正方形的椭圆
  （官方头像总是正方）。
- 官方 API 表里写 `Skeleton.Image` / `Title` / `Button` 也吃 `size`，**代码里没有这条**
  （`Generic` 只在 type 是 AVATAR 时才拼 `-{size}` 类，scss 里也没有对应规则）—— 记下来不抄。

**验证**

- `tests/tst_skeleton.qml` 27 个用例函数 / 113 处断言（`tst_controls.qml` 里那 2 条旧 Skeleton
  用例删掉，28 → 25 处断言）。全量 44 个 `tst_*.qml` offscreen 逐文件 **1552 通过 / 0 失败**；
  `all_qmllint` 0 警告。
- 令牌与换算全写死字面量（六档边长、24、115×32、16、10、60%、1400、0.25 / 0.44 / 0.88、
  0.19 与 0.44 两段坡宽），流光色标那条链是**直接调 `stopsAtPhase(phase)` 断数值**，
  不给「近似实现」留活路。
- 变异两批共 **43 个，全部被抓**（`tests/tmp_skeleton_mutate.py` 37 个 +
  `tests/tmp_skeleton_mutate2.py` 6 个）。首轮回放有两处要交代：M24（采样分支阈值 0.44→0.40）
  **0 红** —— 断言采样的点全落在 (0.40, 0.44) 那段之外，补 0.30 / 0.43 / 0.50 / 0.80 四点
  （0.43 紧贴坡顶）才咬住；M06 是**锚点根本没换上**的空打（那处是三元赋值不是 `if`），
  重打后见血，另外补了「重建时不销毁旧节点」那条（断 `skeletonPlaceholder` 只剩一个子项）。
- 像素复核（`tests/tmp_skeleton_shot.qml` → `/tmp/sk_anim_*.png`，纯 python 解 PNG 取数，
  `tests/tmp_skeleton_pixels.py`）：四帧里标题条与段落的最暗列从 x=82 走到 269 / 384 ⇒
  **高亮确实自左向右扫**；头像圆角外四角在任意相位都是纯白 `(255,255,255)` ⇒
  渐变被 `radius` 裁住了，没有方形溢出。
- 帧时（`tests/tmp_skeleton_frames.qml` + `QSG_RENDER_TIMING=1`）：4 格同时流光与 48 格同时
  流光，帧距中位数都是 22ms、`sync ≤ 1ms` / `render ≤ 2ms` ⇒ 坑 40 那条「逐帧重建渐变材质」
  在本组件量不出边际成本（多 44 格不额外掉帧）。gallery 页面上只有「加载动画」那 5 格在动。
- 过程中改掉的一处实现：容器原来用 `Loader` 承载 `placeholder`，但 `QQuickLoaderPrivate`
  会把自己显式设置的宽高盖到载入项上（`setInitialState`，且 `_q_updateSize` 连载入项自己的
  `width` 绑定都 `takeBinding` 摘掉）⇒ `SkeletonAvatar` 被拉成整幅宽（实测 520×48 的胶囊）。
  换成一个等大的 `Item` 宿主 + `createObject`，官方的「div 100% 宽、子块自己带尺寸」才落地。

### 补做：Feedback 落地，官方 8 个小节（2026-10-17）

这一页原本躺在「跳过」里（`semi-ui/feedback` 是个套壳组件，官方自己不做壳）。用户点名要实现。

**做了什么**

- 新增 `src/Feedback.qml`（`C.Popup` 派生，注册进 `src/CMakeLists.txt`）。属性面照
  `semi-ui/feedback/index.tsx:26-47` 的 `FeedbackProps` + `:65-72` 的 `defaultProps`：
  `mode`（`popup` 缺省 | `modal`）/ `type`（`emoji` 缺省 | `text` | `radio` | `checkbox` | `custom`）/
  `title` / `closable` / `value` / `okText`「提交」+ `cancelText`「取消」（`locale/zh_CN.ts:227-230`）/
  `okButtonDisabled` / `okButtonLoading` / `cancelButtonLoading` / `textAreaPlaceholder` /
  `textAreaMaxCount` / `radioOptions` / `checkboxOptions` / `showFooter`，三个信号
  `ok()` / `cancel()` / `valueChange(var)`，默认属性是 `custom` 那档的内容宿主。
- **一张卡同时充当官方两种壳**：`mode` 只改宽（popup 400 / text 600 / modal 400）、位置
  （popup 钉窗口右下 20 / 50，modal 居中）、蒙层（popup 无，官方写死 `mask={false}`）与动效
  （popup 180ms OutQuad 自下推入，modal 120ms OutCubic + 淡入缩放）。度量逐条来自
  `feedback.scss` + `variables.scss`，壳的 header / body / 关闭键抄 `SideSheet.qml` 与 `Modal.qml`。
- **值语义照 `semi-foundation/feedback/foundation.ts:22-53`**：emoji ⇒ `{ emoji }`（点同一枚也重发一次
  回调）、选中 😞 才长出补充说明的 TextArea 且打字是**合并** `{ emoji, text }`、换一枚 emoji 整个对象
  替换 ⇒ 之前写的 text 丢掉；text ⇒ 字符串；radio ⇒ 选中值；checkbox ⇒ 数组；custom 自己不碰 value。
  提交键禁用算式 `!Boolean(value) || (Array.isArray(value) && !value.length)`（`index.tsx:231-234`），
  给了 `okButtonDisabled` 以它为准。取消 / 提交都**只回调 + 清 value，不关自己**。
- emoji 的 `filter: grayscale(100%)` 用 `MultiEffect { saturation: -1 }` 落地（0 是「不改色」），
  灰档时藏掉彩色本体、彩色时藏掉效果层，两层永远只画一个。
- 官方那五个 `*Props` 对象摊平成显式属性（同 `DateScrollColumn` 的先例），另开
  `readonly property alias textArea / radioGroup / checkboxGroup / customHost` 四道缝摸内部件；
  `renderContent` 不收（QML 侧 children 就是它），promise 驱动的那套 loading 换成两个显式开关，
  `afterClose` 官方压根没调用过所以不提供。
- `src/CheckboxGroup.qml`：`itemSpacing` 从 `readonly` 放开成可写（Feedback 要按
  `$spacing-feedback_checkbox_group_vertical-rowGap` 给 16，组自己的缺省是 12）。
- `examples/gallery/FeedbackPage.qml` 八节全落：如何引入 / 基本使用 / 文字类型 / 单选反馈 /
  多选反馈 / 自定义反馈内容 / 模态对话框形式 / 反馈完成提示。每节一个开关按钮，emoji 那节把
  `onValueChange` 收到的形状直接印成一行「当前 value」。「反馈完成提示」那节照官方
  `renderContent` 换感谢页的做法改成换子项 `visible` + `title: " "` + `showFooter: false`。
  API 表由 `GalleryShell` 从 docs.json 统一渲染，页内不手写。
- `examples/gallery/data/docs.json`：Feedback 的 `skipped` 置 false（资源文件，改完要重建）。

**验证**

- `tests/tst_feedback.qml` 35 个用例函数 / 141 处断言（Feedback 部分 28 个函数 / 113 处）。
  全量 44 个 `tst_*.qml` offscreen 逐文件 **1585 通过 / 0 失败**；`all_qmllint` 0 警告。
- 变异 `tests/tmp_feedback_mutate.py` 共 **34 个，全部被抓**。第一轮 30 个存活 3 个，都补了断言：
  M19 取消键的 `tone` 从没断过、M30 卡片圆角 12 从没断过、M24 最贵 —— 把 `dismiss()` 里的
  `handleCancel()` 摘掉照样全绿，因为 `onClosed` 的兜底会把 `cancel()` 补发一次，**只数信号条数
  分不出「谁发的」**，改成在信号回调里记发射那一刻的 `fb.visible` 才咬住。为此给关闭键补了
  `objectName: "feedbackCloseButton"`，测试走真实点击而不是直接调 `dismiss()`。
- 像素复核走 `tests/tmp_feedback_shot.qml`（cocoa）：emoji 三枚默认灰、选中 😞 那枚上彩色并长出
  补充说明、radio / checkbox 竖排、custom 子项内联、modal 那一支的提交键禁用态。gallery 页
  `--page Feedback --scroll 0/700/1400/2100/2800/3500 --shot` 复核八节与右侧锚点条。
- 详见 `PROGRESS.md` 坑 91（`MultiEffect.saturation` 的 0 / −1、弹层项血统与 Repeater 代理的取法、
  为什么是一张自绘卡而不是复用 `SideSheet` / `Modal`）。

### 补做：Banner 按官方重写，补齐 5 个小节（2026-10-17）

这一页原本只有 3 个小节（基本用法 / 不同类型 / 自定义内容），缺的「如何引入」与「非全屏模式」
正好要本库没有的 prop，所以组件与页面一起做。

**做了什么**

- `src/Banner.qml` 从「一块会变色的小卡片」重写成官方 `BannerProps`（`semi-ui/banner/index.tsx:22-35`
  + `:53-58` 的 defaultProps，度量照 `banner.scss` + `variables.scss`）：`tone`（官方 `type`）/
  `fullMode`（缺省 true）/ `bordered`（缺省 **false**，且只在非全屏生效）/ `title` / `description` /
  `iconName` + `iconShown` / `closeIconName` + `closable`（官方两组 ReactNode + `null` 隐藏）/
  `bannerVisible`（官方 `state.visible`，非受控）/ `closed()`，默认属性是 children（官方
  `.semi-banner-extra` 那层）。
- **推翻一条旧结论**：旧组件行写着「文字与描边取本色」。实际只有**图标与描边**吃本色，
  标题与描述恒为 `text-0` —— 官方那两条是 Typography 节点，`.semi-typography` 自己写了 `color`
  （semi.css:25291），元素自身的声明压过横幅容器上的继承（semi.css:3220）。
- **两种排版分开做**：全屏那支整组水平居中、垂直居中，且**标题与描述并排在一行**
  （`.semi-banner-content-body` 是 flex 行）；非全屏才是标题在上、描述在下、隔 2px
  （那条 `margin-top` 嵌在 `-in-container` 里）。圆角 3 与 1px 描边都只在非全屏。
- 默认图标按色调取：info_circle / alert_triangle / alert_circle / tick_circle，`size="large"` = 20px；
  关闭键 24×24（正好是 small 档 IconButton）+ 左距 12 + `Accessible.name: "Close"`，
  根项 `Accessible.role: Accessible.Alert`（官方 `role="alert"`）。
- 全屏那支的「整组按内容宽」只能问 `TextMetrics`：`Text { width: implicitWidth }` 配 `wrapMode`
  是一条收敛到 0 的绑定环。Qt 6.11 的 `Text` 也没有 `font.lineHeight` / `font.lineSpacing`，
  所以行高吃字体自然值，断言只断相对量。
- `examples/gallery/BannerPage.qml` 补齐官方 5 节：如何引入 / 基本用法（`LayoutBox` 三段 +
  Show/Hide 按钮，banner 用 `Loader` 挂卸，对应官方 `{visible ? banner : null}`）/ 不同类型
  （四条全屏）/ 非全屏模式（四条 `fullMode: false` + `bordered` + 无图标无关闭键）/
  自定义内容（500 宽描边容器里一条 warning + 两颗右对齐的键）。
  小节说明由 `GallerySection` 从 docs.json 渲染，页内不再手写重复的介绍文案，只在 demo 下面补 `Note`。
- **顺带修掉文档站一处解析缺陷**：`examples/gallery/build/parse-docs.py` 的 API 表正则写死了
  `## API 参考`（带空格），而 Banner / Divider / Checkbox / Tag / Tree 等 14 页的 md 标题是
  `## API参考` ⇒ 这些页的 `api` 一直是空数组、页尾不渲染 API 表。正则放宽成 `API\s*参考`。
  但**没有整份重生成 docs.json**（重生成会冲掉 Form 手工补的三节锚点），只把 Banner 的 10 行
  API 按行号插进现有文件；另外把上一轮手改的 Feedback `skipped` 从解析器的 `SKIPPED` 集合里删掉。

**验证**

- 新增 `tests/tst_banner.qml`（17 个用例函数 / 82 处断言，Banner 的三条旧用例从 `tst_feedback.qml`
  搬过来扩写；那个文件回到 32 函数 / 131 断言），已注册进 `tests/CMakeLists.txt`。
- 全量 **45** 个 `tst_*.qml` offscreen 逐文件 **1603 通过 / 0 失败**；`all_qmllint` 0 警告。
- 变异 `tests/tmp_banner_mutate.py` 共 **45 个，全部被抓**。第一轮存活 1 个：M37 把「关闭键不占位时
  把宽度还给正文」那支改坏照样全绿 —— 断言落在 `bannerContent.width`（只吃内边距）上，
  跟被改的表达式没关系。改断 `bannerBody.width` 并加一条 closable=true 的对照才咬住。
- 像素复核：`tests/tmp_banner_shot.qml`（cocoa）出全屏四色调 / 全屏标题描述并排 / 非全屏带描边 /
  无图标无关闭键 / children 两键共五张；gallery 页 `--page Banner --scroll 0/700/1400/2100 --shot`
  复核 5 个小节、右侧锚点条与**新出现的 API 参考表**。
- 详见 `PROGRESS.md` 坑 92。

### 补做：UserGuide 按官方重写，补齐 8 个小节（2026-10-17）

这一页原本只有 5 个小节（基本用法 / 主题 / 设置高亮区域大小 / 定制按钮 / 无遮罩），缺的
「气泡卡片弹出位置」「受控」「弹窗式引导」三节正好要本库没有的 `position` / `current` / `mode`，
所以组件与页面一起做。

**做了什么**

- `src/UserGuide.qml` 整份重写成官方 `UserGuideProps`（`semi-ui/userGuide/index.tsx:23-59` 的
  props 与 `StepItem`、`:84-101` 的 defaultProps、`:243-308` 气泡内容、`:451-522` 弹窗内容）+
  `semi-foundation/userGuide`（`foundation.ts:28-85` 那四个 handler、`constants.ts` 的
  MODE / THEME / 默认值、`userGuide.scss` + `variables.scss` 的 21 个度量令牌）。属性面：
  `current`（给了就是受控）/ `finishText` / `mask` / `mode` / `position`（Enums.Placement 十二档）/
  `spotlightPadding` / `showPrevButton` / `showSkipButton` / `steps` / `theme` / `zIndex` /
  `container`（官方 `getPopupContainer`）/ `nextButton*` 与 `prevButton*` 六个摊平属性 +
  `changed` `next` `prev` `finished` `skipped` 五个信号与三颗只读按钮引用。
- **两支卡片分开画**：`popup` 是一支贴目标的 Popover（宽 400 且 `max-width: fit-content` ⇒ 内容窄时
  整张卡收，宽度只能问 `TextMetrics`；圆角 6、cover 高 200、body 内边距 24、标题 18/600/行高 24、
  描述行高 20、footer 顶距 48、按钮组 `gap 12 + margin-left 120`、指示器是「2/3」**文字**）；
  `modal` 是居中 600 宽卡（圆角 12、cover 高 300、指示器条高 30、圆点 6×6 间距 8、
  body 内边距 24/48 且竖排居中、footer 四周 24）。**modal 的圆点排只在有 cover 时才渲染**，
  modal 也不挖洞、不读 `target` 与 `position`。
- **洞与锚点是两份**：官方 SVG 那块洞带 200ms transition，卡片定位用的透明 div 立刻到位。
  这里 `hole` 吃动画（只喂视觉遮罩四块），`spot` 现算（卡片锚点与四块拦截 MouseArea 吃它）。
- **`mapToItem()` 在绑定里只求值一次**是这一轮最大的那条：`readonly property rect` 里读
  `mapToItem` 不会跟着场景变，offscreen 全绿而 cocoa 抓图洞在别处。改成四个标量 +
  `refreshSpotlight()` + `FrameAnimation` 每帧刷（值没变就不写，否则 `Behavior` 被反复重启），
  开层那一拍再用 32ms 的 settle 放开动画。官方每次 render 量一次 rect、滚动时洞不跟目标，
  这一条按「跟」实现并写进组件头的差异清单。
- **官方两处 bug 只记录不抄**：`getFinalPaading()`（typeof 判定、`0` 生效）在整个包里零调用点，
  渲染路径用 `||` ⇒ `spotlightPadding: 0` 被吞成 5，这里按 `getFinalPaading` 的意图实现；
  `StepItem.mask` 文档写了但实现只读 `props.mask`，这里同样不接、不开放该字段。
- `examples/gallery/UserGuidePage.qml` 补齐官方 8 节，逐节都带可点的目标（`Switch` / `Tag` /
  `Button`）：主题那节两支 primary、弹出位置那节三步换 `Top` / `Right` / `Bottom` 并关掉箭头、
  高亮大小那节全局 10 + 单步 15 / 0、定制按钮那节改文案与 theme、受控那节把 `current` 存在页面上
  由 `onChanged` 写回、弹窗式引导三步带 cover（离线环境换成本仓库样图）、无遮罩那节 `mask: false`。
  「弹出位置」那节的 target 前面垫了一个 180px 的占位 —— 卡片翻到上方后又放不下时会被窗口裁掉，
  这是 `PopupBase` 的 autoAdjustOverflow 判定（要**完全**放不下才翻面），与官方一致，不动共享件。

**验证**

- 新增 `tests/tst_userguide.qml`（61 个用例函数 / 361 处断言，注册进 `tests/CMakeLists.txt`）；
  UserGuide 原先在 `tst_guide.qml` 里的 5 个函数搬过来扩写，那个文件回到 5 函数 / 17 断言、只剩 Anchor。
- 变异 `tests/tmp_userguide_mutate.py` 共 **108 个，全部被抓**（变异回执：
  `survivors 0`）。第一轮 6 个存活逐个查清：3 个是断言没落在被改的量上（洞的坐标偏移、受控时内部游标、
  弹窗标题的 `horizontalAlignment` 只断了描述），3 个是**浅色主题下 `bg-2` / `bg-3` / `white` 同值**
  （切暗色才有区分度）—— 顺带把下一步那颗键从 `Theme.colorWhite` 改成字面量 `#ffffff`，
  因为官方写的是 `'#FFF'` 而 `colorWhite` 在暗色是 `#e4e7f5`。
- **卡片浮在遮罩上面这件事，只有真点一下才算数**：换步的用例原本都直接调 `handleNext()`，命中测试与
  层序没参与，而 `z` 的断言又与被断的量同源。补 `test_cardButtonsRespondToRealClicks` /
  `test_modalCardButtonRespondsToRealClick`（把点击打在窗口 `contentItem` 的绝对坐标上，穿过拦截 rect
  与蒙层去点卡片里那颗键），并给两支卡片各补一条 `z === zIndex + 1` 不变式 —— M106 / M107 / M108
  三条新变异全部见血。
- **流程教训**：第一轮脚本跑到一半被打断，变异（`buttonsMarginLeft: 96`、`handleNext` 少了
  `pushChange`）留在源码里；第二轮把这份污染当原始快照读，基线本身就是红的，于是 89 条变异
  「全部被抓」是假的。现在脚本开跑前先要求基线绿、`atexit` / `SIGTERM` 还原源码、锚点命中数
  必须恰好为 1（命中 0 次的那两条属于「空打」，本来就没打上）。
- 全量 **46** 个 `tst_*.qml` offscreen 逐文件 **1662 通过 / 0 失败**；`all_qmllint` 0 警告。
- 像素复核：`tests/tmp_userguide_shot.qml`（cocoa）出 basic / primary / top / right / noarrow /
  pad10 / pad15 / modal / nomask 九张；gallery 页 `--page UserGuide --scroll 0/700/1400/2100 --shot`
  复核 8 个小节、右侧锚点条与 API 表。
- 详见 `PROGRESS.md` 坑 93。


### 补做：Tooltip 按官方重写，补齐 10 个小节（2026-10-17）

这一页原本只有 4 个小节（基本用法 / 位置 / 触发时机 / 配合 Popover），缺的「注意事项 /
指向元素中心 / condition 条件触发 / 覆盖特定样式 / 渲染至指定 DOM / 仅当内容宽度超出时展示
Tooltip」正好要本库没有的 `arrowPointAtCenter` / `condition` / `maxWidth` / `container`，
`trigger` 也只有 hover 一档，所以组件与页面一起做。

**做了什么**

- `src/Tooltip.qml` 整份重写成官方 `TooltipProps`（`semi-ui/tooltip/index.tsx:128-194` 的
  propTypes 与 defaultProps 字面顺序、`:448-472` 点外判定 + `semi-foundation/tooltip/foundation.ts:201-284`
  的 `_generateEvent` 五档、`:305-340` / `:1207-1231` 的 delayShow / delayHide、
  `:1277-1329` 的 Esc、`:438-627` 的定位算式、`constants.ts:8-45` 的枚举与默认值）。属性面：
  `target`（官方是包裹 children）/ `text`（官方 `content` 的字符串档，富内容走 children）/
  `trigger` 五档 / `position` 十二档 / `mouseEnterDelay` `mouseLeaveDelay`（都 50）/
  `condition` / `arrowPointAtCenter` + 基座 `showArrow` / `spacing`（借 `C.Popup` 那个 FINAL 同名属性）/
  `margin` → 基座 `fitMargin` / `zIndex` 1060 / `autoAdjustOverflow` / `clickToHide` +
  `clickTriggerToHide` / `disableFocusListener` / `closeOnEsc`（缺省 false ⇒ 既不关也不发信号）/
  `rePosKey` / `container` / `maxWidth` 240，信号 `clickedOutside` `escKeyDown`。
  度量逐条来自 `tooltip.scss` + `variables.scss` + `arrow.scss`：grey-7 底 / bg-0 字 / 圆角 6 /
  内边距 12-8 / 14 字号 20 行高 / **无阴影** / 三角中心离边 18 / 带三角最小 36×34 /
  进出场 100ms（在基座，`motion` 一并开在那里，Tooltip / Popover / Dropdown 共用）。
- **触发模型逐档照抄，包括三条反直觉的**：`click` 与 `contextMenu` 只 `show()` **不是开关**
  （已开着再点还是开，关闭全靠点外）；`hover` 档除了 mouseEnter/Leave **还额外绑一对 focus/blur**
  （a11y，`disableFocusListener` 只削这一对，`focus` 档自己不看它）；`custom` 档点外只注册一个
  空回调 ⇒ `clickedOutside` 照发但**不会因此收起**。`condition !== false` 只挡「显示」那几条路径，
  隐藏与 blur 不挡，对 `custom` 整个无效。
- **点外判定自己做**：`closePolicy` 换成 `NoAutoClose`（Controls 那条不认 anchor、点触发器也会先被收），
  改成 open 期间在浮层宿主上挂一只全窗壳 + `PointHandler`，按落点排除 target 与卡片矩形，
  passive handler 不吃事件（实测点外那一下照样打在页面项上；为什么不能用 `MouseArea`，见下面
  「点外观测」那条与 `PROGRESS.md` 坑 94）。
- 三角那颗**照抄官方 SVG 路径**（`TriangleArrow.tsx` 的 24×7 与 `TriangleArrowVertical.tsx` 的
  7×24，两条边是内凹的三次曲线，不是直边三角）：基座用 `Shape + CurveRenderer + PathSvg` 画，
  左右 / 上下两个反向靠 `Scale` 翻（path 里有 `S` 平滑命令，手改坐标会把镜像控制点算错）。
  摆放吃 `arrow.scss` 的三个量：底边压进卡片边 1px（`$spacing-tooltip_arrow_offset-x/-y`
  「渲染会有缝隙，所以加个偏移量」）⇒ 探出 6、沿边离角 18（`$spacing-tooltip_arrow_adjusted_offset-x`
  = round(0.24×24) = 6 加半个宽 12）、带三角最小 36×34。Popover 那一档多一条描边 path
  （`popover/Arrow.tsx` 两条 path，24×8），差在 `arrowStroked`。
  **这一条是本轮最后补的**：先前基座画的是「方块转 45°」，而且写成了 2:1 的长方形 —— 转完之后
  朝外那个角不在中线上，画出来是个歪楔子（用户报「箭头没画对，形状很奇怪」，cocoa 抓图确认）。
- 调用点迁到官方口径：`Slider` 的刻度提示去掉 `showDelay: 0`（官方 slider 就是缺省 50ms，
  `slider/index.tsx:586`），`Rating` 的星级提示改成 `trigger: "custom"` + `visible: _hoverValue - 1 === index`
  —— 官方那条条件本来就是受控的（`index.tsx:298`），旧实现用「悬停即显」糊过去了。
- `examples/gallery/TooltipPage.qml` 补齐官方 10 节：如何引入（`import Semi` 那段最小用法，顺带说明
  「官方拿 children 当 target、这边显式指过去」这个形状差）、注意事项（Tag / Tag / Rectangle 三种目标，
  说明「目标里有会吃 press 的 MouseArea 时 click 档拿不到」）、位置（12 档目标 + 12 只提示，
  children 档放两行 `<p>`）、指向元素中心（`arrowPointAtCenter` 开关对照）、触发时机
  （hover / click / focus / contextMenu 四档 + `RadioGroup` button-style 驱动 custom）、
  condition 条件触发（`Switch` 拨 `condition`）、覆盖特定样式（缺省 240 与 `maxWidth: 320` 对照）、
  渲染至指定 DOM（`container` 指向一个 420×200 的框）、搭配 Popover 或 Popconfirm 使用
  （说明 QML 侧不需要中间那层 span：三个组件各自往 anchor 挂 handler，互不覆盖）、
  仅当内容宽度超出时展示 Tooltip（Title / TextLabel / Paragraph 的 `ellipsis: ({ showTooltip: true })`）。
  API 表由 `GalleryShell` 从 docs.json 统一渲染（Tooltip 那 30 行）。

- 共享件 `src/PopupBase.qml` 这轮动了两处，都不只影响 Tooltip：
  开一个新属性 `motion`（进出场动画开关，官方 Tooltip / Popover / Dropdown 共用同一个 prop，
  四条 transition 的 duration 都挂在它上面）；`place()` 里右 / 下角落方位的交叉轴平移算式
  从 `middle + ac − size` 改成 `middle − ac` —— 中心值 `arrowCenterX/Y` 一律从卡片的**左 / 上边**
  量起（右角落给 `width − 18`），原来那四支把参照系搞反了，是逐档测八个角落时才当场报红的。
- 点外观测从「铺在浮层宿主上的 `MouseArea`」换成「每实例一个全窗壳 + `PointHandler`」：
  前者哪怕 `enabled: false` + `visible: false` 也会把整窗的点击截住（`tst_taginput` /
  `tst_treeselect` 四条「点标签的叉」确定性报红，`childAt()` 在那个点返回 `QQuickOverlay`），
  passive handler 才不吃事件。壳子只在 `isOpen && watchesOutside` 那几档才进场景。

**验证**

- 新增 `tests/tst_tooltip.qml`（58 个用例函数 / 273 处断言，注册进 `tests/CMakeLists.txt`）；
  `tst_popup.qml` 里那条 `test_tooltipDefaults` 搬走（回到 15 函数 / 48 处断言），
  `tst_rating.qml` 改成断 `trigger === "custom"`（185 处）。
- 变异 `tests/tmp_tooltip_mutate.py` 共 **123 个，121 个被抓、2 个登记为等价变异**（变异回执）。第一轮 32 个存活，各自的顶包者与补法见 `PROGRESS.md` 坑 94
  最后两条（一族 N 档要挑「只有这一档才不同」的样本；关闭路径要挑不经过 `delayHide` 的那条；
  「进不进场景」的守卫直接断结构）；换掉三角画法之后又补 8 条（盒子互换 / 两档翻转 / 直边三角 /
  压边 0 与 4 / `arrowSize` `arrowBase` 回 12 / tooltip 多画描边），全部见血。
- 全量 `tst_*.qml` offscreen 逐文件全绿、`all_qmllint` 0 警告（当期文件数与断言总数见
  `PROGRESS.md`「测试与验证」）。
- 像素复核：`semi-gallery --page Tooltip --scroll 0/900/1800/2700/3600/4500 --shot`（cocoa）逐节看过
  十个小节的版面（`arrowPointAtCenter` 两版对照、custom 档单选组、`container` 那只 420×200 的框）。
  卡片本身另走 `tests/tmp_tooltip_shot.qml`（cocoa + `grabToImage`）：一档一只、12 只同时开着排成
  网格，八个角落方位的三角离边 18 与卡片沿交叉轴的那次平移逐档对过像素 —— 这一张同时是
  `PopupBase.place()` 那处修正的像素证据。
- 共享件那处 `place()` 修正对**其他使用方是惰性的**：`Popover` / `Dropdown` / `Popconfirm` /
  `UserGuide` / 各选择器都不写 `pointAtCenter` 与 `arrowCenterX/Y`，走的是 `isNaN(acx)` 那一支
  （老行为，边缘对齐），所以不必重跑它们的像素。
- 详见 `PROGRESS.md` 坑 94（`C.Popup` 不是 Item 的四条硬错、FINAL 属性怎么借、
  `TextMetrics` 与 `Text` 排版差 1.8px、空 `Text` 也占位置、hover 进卡片不消失的滞回写法、
  浮层上那只 `MouseArea` 为什么会把全窗点击截住、`readonly property` 在销毁过程中被重算，
  以及五批存活变异各自的顶包者与断言写法）。


### 补做：Timeline 按官方重写，补齐 6 个小节（2026-10-17）

这一页原来只有 4 个小节（基本用法 / 节点类型 / 自定义 / dataSource），缺「如何引入」和
「时间轴位置」，而「时间轴位置」正是旧实现根本没有的 `mode="right"` / `"center"` 两档 ——
条目只有 left / alternate 两种走法，`type` 还被当成 `Enums.Tone` 整数（旧记的第 3 条踩坑就是这么
定下来的，本轮核对上游类型后作废）。组件与页面一起做。

**做了什么**

- `src/Timeline.qml` 整份重写成官方 `TimelineProps`（`semi-ui/timeline/index.tsx:20-40` 的
  propTypes / defaultProps：`mode` 缺省 `"left"`、`dataSource`、children），
  新增 `src/TimelineItem.qml` 承接官方 `Timeline.Item`（`timelineItem.tsx` 的
  `type` 五档字符串枚举 / `color` / `position` / `time` / `extra` / `dot` / `clicked`；
  QML 没有嵌套类型，就拆成独立文件由 `Timeline` 生成或直接声明）。
  `content` 官方是 children 与 `Data.content` 两路，QML 里合成一个 `var`（字符串或 Component）。
- **角色由父项推下来**：官方是 `cloneElement` 给条目加位置类名（`index.tsx:62-73`），条目自己不知道
  自己是第几个，所以 `Timeline.syncRoles()` 往每个条目推 `timelineIndex` / `timelineCount` /
  `timelineMode`。**顺序必须按排版走**：`Repeater` 往兄弟之间插条目用的是 `stackBefore`，
  视觉顺序变了而 `Item.children` 这份 QObject 名单一律追加在末尾，而 `childItems`
  在 QML 里根本摸不到（`QQuickItem::childItems()` 连 `Q_PROPERTY` 都不是，读回来是 `undefined`）。
  于是 `syncRoles` 把条目按 `y` 排一遍，并给每条挂一次 `yChanged` → 零延时 `Timer` 再兜一趟
  （排版发生在 `childrenChanged` 之后，当场读 `y` 还是上一趟的）。
- **两条通路各有各的列容器**：给了 `dataSource` 就完全不看声明式子项（`index.tsx:83-89`），
  所以 `timelineDeclaredBody` / `timelineDataBody` 两个 `Column` 按 `usesDataSource` 互斥可见；
  声明式子项先落在暂存容器，再由 `refreshItems()` 整批搬进列容器（**宿主也一起搬**：只搬条目的话
  `Repeater` 留在暂存容器里，它后来生成的子项要往「已经不在这儿的大哥」前面插，
  Qt 每次长条目都打一条 `Cannot stack … before QQuickRepeater, which must be a sibling`，
  而实测两种形状的顺序 / 角色 / 高度一致，就取不报警告那一档）。宿主搬过去之后，
  「暂存容器 childrenChanged」那条触发器就没人踩了 —— **变异打死它的闸门整套用例仍全绿**，
  于是按「删掉互相顶包的守卫」把 `_moving` 与那条 `Connections` 一起删掉。
- **收回 `dataSource` 那一趟是本轮唯一的硬错**：`tl.dataSource = []` 之后
  `onDataSourceChanged` → `refreshItems()` 里 `if (!control.usesDataSource)` 读回来还是上一步的
  `true`（同一个通知周期里派生绑定还没重算，坑 74 / 坑 93 那条家族），整批子项根本不搬。
  改成 `usesDataNow()` 直接读 `dataSource` 本身。同源的另一处（`syncRoles` 认容器）只是「这一趟推空了」，
  后面 `childrenChanged` / `yChanged` 都会再兜一趟，实测断不出来 ⇒ 登记成**等价变异**。
- 度量逐条 DOM 实测（`tests/tmp_timeline_dom.html` 复刻官方 class 嵌套 + browser-use
  `getComputedStyle` / `getBoundingClientRect`，条目宽按 gallery 的 520 量）：
  外层 `ul` 一圈 `padding: 8`（`$spacing-timeline-padding`）；条目高 = 正文块 + 24（`$spacing-loose`）
  ⇒ 单行正文条目实测 **44**；连线 `top 20 / width 1 / height = 条目高 − 20`，最后一条不画
  （`:last-child`）；圆点 `top 5 / 9×9`、`border-radius: var(--semi-border-radius-circle)`
  （自定义图标那一档是 `radius 0`，QML 里就是 `Rectangle.radius: 4.5`）；自定义 dot 锚点 `(left, 10)` +
  `translate(-50%,-50%)`，`-head-custom` 把背景清成 transparent、type 色靠 `color` 继承到图标；
  正文 14/20 text-0 `margin-left 25`（宽 495），`extra` / `time` 12/16 text-2 `margin-top 4`。
  四档轴线的横向关系全部量过：left 轴线 x=4、点 x=0、自定义 dot 中心 x=5、正文 x=25；
  center / alternate 轴线 x=W/2；**right 档轴线贴右边缘（x=W−9）**，这是 compiled css 里
  `.semi-timeline-right .semi-timeline-item-right .semi-timeline-item-tail` 那条赢下来的结果 ——
  按 scss 源文件的嵌套读会以为它跟通用规则等价，实际 specificity 更高、是生效的那条。
  只有 center 档把 `time` 绝对定位到轴线左边（实测 `x=-5`、`top -2 + margin-top 4`、宽 = 正文宽、右对齐）。
- **一处不照抄**：`mode="center"` 下给条目写 `position="right"`，官方那条
  `margin-left: calc(-40px - 100%)` 会把 `time` 推到条目左边界外（实测 `x=-280`，整行看不见）。
  只在「整块都掉出左边界」时把 x 夹回 0，普通条目那个 `-5` 照抄。
- `examples/gallery/TimelinePage.qml` 补齐官方 6 节：如何引入（`import Semi` 最小用法）、基本用法、
  节点类型（五档 `type`）、自定义节点（`dot` 图标 + `color` 覆盖 + 富 `content`）、
  时间轴位置（left / 时间节点在左侧 / 交替展现 / right 四段，每段一个小标题）、使用 `dataSource`。
  富内容那几段用的 `Component` 一律提到页面根上（`Component { … }` 写在 `dataSource` 的对象字面量里
  解析不过，报 `Expected token ','`）。API 表由 `GalleryShell` 从 docs.json 统一渲染（Timeline 那 13 行）。

**验证**

- 新增 `tests/tst_timeline.qml`（34 个用例函数 / 300 处断言，注册进 `tests/CMakeLists.txt`）；
  `tests/tst_nav.qml` 里那两条旧 Timeline 用例（`test_timelineItems` / `test_timelineFollowsTheme`）
  搬走并改写进新文件，那个文件回到 13 函数 / 27 处断言。四档轴线逐档对 DOM 数、
  自定义 dot 的锚点与染色、`dataSource` 的八个 prop 透传、空值闸门、运行时长条目与混排顺序都断到。
- 变异复核 `tests/tmp_timeline_mutate.py`：**89 个变异，87 个被抓，2 个登记成等价变异**（变异回执，两条都写了理由）。第一轮两条存活：一条锚点撞车（同一段文本
  在两个函数里都出现，变异其实没打上，被记成「没红」——脚本因此加了 `--check` 只数命中次数），
  一条是那条死重的暂存触发器 ⇒ **删守卫而不是补断言**；换掉搬运形状之后又冒出「收回 dataSource
  那一趟读派生绑定」这条硬错，补了同步断言之后再跑一轮，只剩两条按等价登记。
- 像素复核：`tests/tmp_timeline_shot.qml`（cocoa + `tst_semi -input`，用 `Loader { source: "file:///…/TimelinePage.qml" }`
  把真页面装进来按 1000pt 一片抓 `win.contentItem`）逐节看过六个小节 —— 四档轴线的圆点、连线、
  正文左右、center 档浮在轴线左边的时间，以及 dataSource 那一节的四档色 + 自定义图标都对过。
  **`semi-gallery --shot` 这一页不能用**：它在启动后 2000ms 抢一帧，而这一页四条时间轴的高度是
  随条目逐帧长出来的，抓到的常是「四个小标题挤在一起、时间轴还是 0 高」的中间态（同一偏移连抓三次
  三种结果，而 offscreen 量同一棵树是 caption y=0/420/760/1180、timeline h=352/272/352/352，
  说明布局本身没问题，是抓得太早）。
- 详见 `PROGRESS.md` 坑 95（compiled css 与 scss 源文件的 specificity 差、`Item.visible` 回读
  effective visibility 把槽位高度自锁在 0、`childItems` 在 QML 里摸不到、搬运整批与只搬条目
  两档的 `stackBefore` 警告差、`Component {}` 不能写在对象字面量里）。

### 补做：Tag 按官方重写，补齐 12 个小节，并新增 TagGroup / SplitTagGroup（2026-10-18）

这一页原来只有 5 个小节（基本用法 / 尺寸 / 形状 / 配置图标 / 颜色，而且五节的内容跟官方
不是同一份：官方那五节是 `closable` + `preventDefault`、两档尺寸带色档、两档 `circle`、
`prefixIcon` / `suffixIcon` 的 `IconGithubLogo` / `IconSemiLogo`、17 个色档一列表），
缺的七节里「样式类型 / 头像标签 / AI 多彩 / 不可见的 / TagGroup / SplitTagGroup」
要的 `type` / `avatarSrc` / `avatarShape` / `colorful` / `gradient` / 受控 `visible`
和两个组组件，本库一个都没有 —— 组件与页面一起做。旧实现走的是自造面
（`tone: Enums.Tone` + `capsule: bool` + `size: Enums.Size`，外加 `Appearance` 里三个
`tagBackground` / `tagForeground` / `tagBorderColor` helper），这一轮整份换成官方 `TagProps`，
那三个 helper 一并删掉。

**做了什么**

- `src/Tag.qml` 重写成官方全表：`text` / `content`（官方 children 的两支：字符串走
  `-content-ellipsis` 截断、节点走 `-content-center`）/ `tagKey` / `size` 三档（`small` 与
  `default` 共用同一段样式，都是 20 高，`large` 24）/ `color` 17 档（缺省 `grey`）/
  `type` 三档（缺省 `light`）/ `shape` / `closable` / `prefixIcon` + `suffixIcon`（名字或
  `Component`）/ `avatarSrc` + `avatarShape` / `colorful` + `gradient` / `ariaLabel`；
  信号 `clicked` / `closed(tagChildren, event, tagKey)` / `keyPressed` / `mouseEntered`。
  三个官方入口的 QML 等价物：`disabled`（tagInput.scss:119-122 那套外层覆盖）、
  `maxWidth`（`.semi-tagInput-wrapper-tag { max-width: 100% }`）、`backgroundColor`
  （`style` 内联，判定排在最前，压过 colorful）。
- **`content` 没有做成 default property**：第一版是 `default property alias content: row.data`，
  但 `Select.qml` 往 Tag 里声明过 `HoverHandler` / `TapHandler` —— default property 会把它们
  一起塞进正文那一格，命中范围只剩正文、不再是整枚标签。改成 `property var content` + `Loader`。
- **受控 `visible` 用组件内部绑定表达**：官方 `index.tsx:81-94` 是「传了 `visible` 就完全听外部，
  没传才由内部关闭态决定」。QML 侧写成 `visible: !control._hidden`，使用处一旦绑定就把内部绑定
  顶掉 —— 实测两半都成立（`test_controlledVisibleIgnoresInternalState`）。**探针差点量反**：
  `Item.visible` 读的是 effective visibility，而 `TestCase` 根项默认不可见，第一版据此「证明」了
  顶不掉（坑 4 的同一颗）。
- **层叠一律照编译后的 `semi.css`，不照 scss 源文件顺序**：`colorful`（两个类名）> 头像 >
  `white` > `{color}-{type}`。两处同 specificity 的先后只有 compiled 能判：
  ① `.semi-tag-white-{type} .semi-tag-close` 写在 `-close:hover` 之后 ⇒ 白底标签的叉
  悬浮不提亮（别的档都提）；② `-avatar-square` / `-avatar-circle` 写在 `-white-{type}` 之后
  ⇒ 头像档拿 `bg-4` + 1px `color-border` + `text-0`。另有一条 `border-color:
  var(--semi-color-ai-general)` 吃的是渐变，浏览器按 IACVT 退成 `currentColor`（= ai-purple），
  照这个结果落而不另造颜色；渐变铺字与渐变描边 QML 画不了，取代表色（同 Button）。
- **新增 `src/TagGroup.qml`**：溢出是**纯算术**、不量 DOM（`group.tsx:74`
  `const n = restCount ? restCount : tagList.length - maxTagCount`）；`maxTagCount: 0` 官方
  `if (maxTagCount)` 判假不加 `-group-max` 类但截断照跑，`visible: false` 的标签照样占一个名额；
  `+N` 是 `color="grey"` + `style` 抹掉底色 + 不可关闭；`size` / `avatarShape` 按「子项没写才注入」
  下发（`mode="custom"` 一律不注入），`tagKey` 缺省依次取字符串 `children` → `text` → 随机数；
  截断时整组钉一行高（22 / large 26），标签间距 8；`showPopover` 时悬浮 `+N` 开 Popover
  （内置 top，`popoverProps.position` 覆盖），而 `plusNMouseEntered` 不受 `showPopover` 门控
  （官方那条回调一直在）。
- **新增 `src/SplitTagGroup.qml`**：官方只把 `-first` / `-last` 类名塞给直接子元素，
  QML 侧等价地推 `splitChild` / `splitFirst` / `splitLast`（只有一枚时两个角色一起给），
  相邻两枚留 1px 缝。**首尾只认 `Row.childrenChanged` 那一趟触发**：原来还挂了
  `Component.onCompleted`，变异发现两条触发器互相顶包（打死任一条整套仍全绿，因为建组时
  每个子项都会碰一次 `childrenChanged`）⇒ 删掉 `Component.onCompleted`，改用
  `test_splitLateChildGetsRoles`（建好之后再 append 一枚）钉住剩下那条。
- **调用点全部迁移**：`TagInput`（2 处）、`Select`（标签 + `+N`，白色档与
  `preventDefault` + `choose(modelData)` 那套语义保住了）、`TreeSelect`（4 处）、
  `OverflowList` 的注释，以及 gallery 的 `Main` / `CardPage` / `TooltipPage` / `SideSheetPage` /
  `UserGuidePage` / `TreeSelectPage` / `PopoverPage` / `TimePickerPage` / `OverflowListPage` /
  `SpacePage` 十页。`Tag` 不再认识 `Enums.Tone` / `Enums.Size`，档位一律是官方字符串。
- **页面按 docs.json 的 12 个小节重排**（标题逐字一致）：`Space` / `Flow`(620) / `Grid(columns: 3,
  spacing 10)` 三种排布照官方 demo 的容器，「样式类型」的 6 枚、「颜色」的 17 档、
  「头像标签」的 6 档（方角 20/24、圆角 16/20）、「不可见的」用 `RadioGroup type: button`
  Show / Hide 拨 `visible`、`TagGroup` 三节都套在官方那个 `fill-0` 300×35 padding 0 10 的盒子里、
  `SplitTagGroup` 四节（solid / circle / light / ghost）。

**验证**

- 新增 `tests/tst_tag.qml`（72 个用例函数 / 277 处断言，注册进 `tests/CMakeLists.txt`）；
  `tests/tst_misc.qml` 里那三条旧 Tag 用例（`test_tagSizes` / `test_tagColors` /
  `test_tagCapsuleRadius`）搬走并改写进新文件，那个文件回到 7 函数 / 15 处断言。色值一律写死成
  compiled `semi.css` 里的字面串（`tests/tmp_tag_ramp.qml` 把 17 档 × 各取档打成十六进制），
  不拿 `Theme` 现算 —— 不然算式与断言同源。宽度另有一条独立交叉核对：
  `test_widthFormulaAgreesWithRowLayout` 拿 `padLeft + padRight + Row.implicitWidth` 对
  `implicitWidth`（七种变体各一条）。
- 变异复核 `tests/tmp_tag_mutate.py`：**130 个变异，126 个被抓，4 个登记成等价变异**（变异回执，四条都写了理由）。第一轮 12 条存活里 8 条补了断言
  （头像档那条 1px 描边、colorful ghost 的 white 底要换到暗色才与 bg-4 分得开、空串图标名、
  叉的按下态、`Accessible.role`、自带 `avatarShape` 要赢过组的、`+N` 吃组的 `size`、
  SplitTagGroup 建好之后再 append 一枚），4 条按等价登记；两条锚点问题（同一段文本命中 2 次、
  缩进写错命中 0 次）由 `--check` 挡下。**顺带撞出一条陈旧断言**：`tests/tst_treeselect.qml:545`
  断的是 `Tag.size === Enums.Large`，跟成 `"large"` 之后 `tst_treeselect` 93 / 0。
- 像素复核：`tests/tmp_tag_shot.qml`（cocoa + `tst_semi -input`，
  `Loader { source: "file:///…/TagPage.qml" }` 装进 TestCase，按 `[0, 700, 1400, 1900]`
  四片抓 `win.contentItem`）12 个小节逐节看过 —— 多彩那两栏 grid 的渐变 / 非渐变、ghost 一圈的
  描边色、头像档方角与圆角两族、三块 TagGroup 盒子（`+1` / 头像 `+2` / 可删除 `+2`）、
  四组 SplitTagGroup 的首尾圆角与 1px 缝。**一个探针口径**：`tst_semi` 进程里没有 gallery 的 qrc，
  页面里 `qrc:/…/sample1.png` 取不到图，头像那几格是占位灰块 —— 量几何与形状没问题，
  要看图像本身得回 `semi-gallery`。
- 详见 `PROGRESS.md` 坑 96（受控 `visible` 的探针要先把祖先链点亮、同 specificity 靠 compiled css
  的先后判、`content` 做成 default property 会抢走使用处的 handler、`ids` 不是根对象属性、
  两条触发器互相顶包、`pragma ComponentBehavior: Bound` 才是 Repeater 委托读外层 id 的正解）。


- [x] 第 2 轮：基础类剩余 7 页
- [x] 第 3 轮：导航类 8 页
- [x] 第 4 轮：反馈类 6 页
- [x] 第 5 轮：输入类第一批 7 页
- [x] 第 6 轮：输入类第二批 6 页
- [x] 第 7 轮：输入类最后 6 页（**输入类 19 页全部完成**）
- [x] 第 8 轮：展示类第一批 8 页
- [x] 第 9 轮：Dropdown / Image / List / Popover / Tooltip / Modal / SideSheet
- [x] 第 10 轮：Table / Calendar / Carousel / UserGuide / OverflowList / ScrollList /
      DragMove / HotKeys —— **69 页全部完成**
- [x] 第 11 轮：侧边栏搜索 / 暗色打磨 / 未实现页占位 / 色值复制 / README
- [x] 第 12 轮（2026-10-12）：Form 补齐官方 24 节
- [x] 第 13 轮（2026-10-12）：Input / TextArea / InputGroup 补齐 18 节，InputNumber 按官方重写
- [x] 第 14 轮（2026-10-12）：Radio 补齐官方 11 节，新增 `RadioGroup`，Form 页的四处 `Form.RadioGroup` demo 回到官方写法
- [x] 第 15 轮（2026-10-12）：Rating 按官网重写（半星改成裁切、补 `character` / `tooltips` / `allowClear` / `autoFocus`），gallery 补齐 7 节，测试从 `tst_input2` 里那 4 条空转用例换成独立的 `tst_rating.qml`
- [x] 第 16 轮（2026-10-14）：PinCode 按官网重写（每格换成真正的 `Input`、补 `count` / `format` 四种取值 / `autoFocus` / `focusCell` / `blurCell`，删掉自造的 `length` / `masked` / `digits`），gallery 补齐 5 节，测试从 `tst_input3` 里那 3 条空转用例换成独立的 `tst_pincode.qml`
- [x] 补做（2026-10-15）：TimePicker 按官网重写（`value` 改吃 Date / 时间戳 / 严格按 `format` 解的字符串、
- [x] 补做（2026-10-15）：Button 按官方重写（默认 `theme` 改回官方的 `light`、补 `loading` / `block` / `iconPosition` / `noHorizontalPadding` / `colorful`、`ButtonGroup` 改插分隔条、`SplitButtonGroup` 改纯容器并删自造 API），gallery 补齐 11 节，`tst_button` 3 条 → 47 条
- [x] 补做（2026-10-15）：TagInput 按官方重写（`value` / `inputValue` 改 `var` + `undefined` 哨兵、补 `separator` / `split` / `maxLength` / `max` / `maxTagCount` / `showRestTagsPopover` / `showContentTooltip` 三档 / `allowDuplicates` / `addOnBlur` / `draggable` / `expandRestTagsOnClick` / `showClear` / `prefix` · `suffix` / `insetLabel` / `renderTagItem` / `focusInput` · `blurInput`，信号名逐字对齐官方回调），`Tag` 补 white 档令牌与 `maxWidth` 截断，gallery 补齐 17 节，测试从 `tst_input3` 里那 3 条空转用例换成独立的 `tst_taginput.qml`（见 PROGRESS.md 坑 79）
- [x] 补做（2026-10-15）：TreeSelect 按官方重写（`treeData` / `keyMaps` / `treeNodeLabelProp`、`value` 用 `var` + `undefined` 哨兵 + `onChangeWithObject`、`multiple` + `checkRelation` + `leafOnly` + `autoMergeValue` + `disableStrictly`、搜索一族 `filterTreeNode` / `treeNodeFilterProp` / `showFilteredOnly` / `remote` / `searchPosition` / `triggerTagWrap`、展开一族 `expandAll` / `defaultExpandAll` / `defaultExpandedKeys` / `expandedKeys` / `autoExpandParent`、异步 `loadData` + `loadedKeys`、`maxTagCount` + `showRestTagsPopover` + `restTagsPopoverProps`、`virtualize` / `defaultOpen` / `clickToHide` / `labelEllipsis` 与 `renderSelectedItem` / `triggerRender` / 上下槽，实例方法 `search` 改名 `searchBy`），新增 `TreeSelectOption.qml`、`TagInput` 补 `borderless`，gallery 补齐 19 节，测试从 `tst_input3` 里那 3 条空转用例换成独立的 `tst_treeselect.qml`（见 PROGRESS.md 坑 81）
- [x] 补做（2026-10-15）：Transfer 按官方重写（`type` 三形态摊平、补 `draggable` / `filter` 函数 / `inputProps` / `emptyContent` / `showPath` / `treeProps` / `loading` / `virtualize` / `pagination` 与六个 `render*` 钩子，`value` 用 `var` + `undefined` 哨兵分受控，实例方法 `search` 改名 `searchBy`），新增 `TransferRightItem.qml`，gallery 补齐 13 节，`tst_transfer` 17 → 68 个用例函数（见 PROGRESS.md 坑 80）
      补 `type="timeRange"` / `use12Hours` / 三档 step / `disabledTime` / `panelHeader` / `panelFooter` /
      `scrollItemProps` / `triggerRender` / 受控 `open`，删掉自造的 `useSeconds` 与 `selected` 信号），
      gallery 补齐 11 节，测试从 `tst_input3` 里那 4 条空转用例换成独立的 `tst_timepicker.qml`；
      `DatePicker` 内嵌时间面板顺带补上「时 / 分 / 秒」后缀
- [x] 补做计划书 §4 的页内锚点与页尾 Accessibility / 文案规范 / FAQ
- [x] （2026-10-15）Slider 手柄阴影按官方重做：底片叠两层投影、静止态去掉那圈多余的描边、
      投影排到刻度标签之下，参数用解析目标曲线最小二乘标定（详见「补做：Slider」那一节）
- [x] 补做（2026-10-16）：TreeSelect「搜索框位置」两节点了没反应 —— 父级 `TapHandler` 抢不过子
      `TextInput`，改成内层各垫一层按下即放行的 `MouseArea`；触发器那格换裸 `TextInput`
      （`Input { borderless: true }` 聚焦时还会自己画一圈）；补 `clickTriggerToHide`；
      `PopupBase` 新增 `dismissOnOutsidePress`（默认 `true`），TreeSelect 自己按落点判点外关闭；
      焦点并集收成单个 `refreshFocus()`（详见「补做（2026-10-16）」那一节与 PROGRESS.md 坑 81）
- [x] 补做（2026-10-16）：TreeSelect「搜索框位置」第二个的标签排布 —— `+N` 盖在第一个标签上
      （`relayout()` 读派生的 `restHost.visible` 吃一帧滞后，改成现算的 `isCollapsed()`）、
      标签互相贴住（漏了 `.semi-treeselect-selection .semi-tag { margin: 1px 2px }`，
      `TagInput` 开 `tagMarginX` 由 TreeSelect 传 2）、整块比官方偏 2~4px
      （漏了 `tagInput-notEmpty/empty` 的 `margin-left: ∓4` 与 `borderless` 时那 1px 内缩）；
      `tst_taginput` 80 → 83、`tst_treeselect` 88 → 91，变异 11 + 3 个全部被抓
- [x] 补做（2026-10-16）：Toast 按官方重写（整个换成命令式面 `info` / `success` / `warning` /
      `error` / `open` / `create` / `close(id)` / `destroyAll()` / `has(id)` / `update(id)` /
      `config(opts)`，Options 与 Config 逐条照 `toast.tsx` / `toastListFoundation.ts` /
      `toastFoundation.ts`，`duration` 单位是秒、`showClose` 默认 `true`、light 只换底色不动文字色），
      新增 `ToastItem.qml`，gallery 补齐 11 节，测试从 `tst_feedback.qml` 里那 3 条空转用例换成独立的
      `tst_toast.qml`，三处老调用点迁到新 API（见 PROGRESS.md 坑 83）
- [x] 补做（2026-10-16）：堆叠的 Toast 悬停时来回抽搐 —— 收起条件从「任一卡片没被悬停」改成
      「指针离开整叠区域」（`band` 上的 `HoverHandler` 当滞回区域，高度按整叠外框算），
      `_relayout()` 改读 `flowHeight()` 函数避开绑定一帧滞后；`tst_toast` 38 → 39 个用例函数，
      变异补打 6 个全部被抓（详见「堆叠悬停抽搐」那一节与 PROGRESS.md 坑 83）
- [x] 补做（2026-10-16）：Notification 按官方重写（整个换成命令式面 `open` / `info` / `success` /
      `warning` / `error` / `close(id)` / `destroyAll()` / `has(id)` / `update(id)` / `config(opts)`，
      Options 与 Config 逐条照 `notice.tsx` / `index.tsx` 的 `defaultConfig` /
      `notificationListFoundation.ts` / `notificationFoundation.ts`，按 key 在场与否浅合并、
      `type` 钉在入参之后、`zIndex` 只写第一次、`destroyAll` 播退场动画、三条关闭通路语义各不相同），
      新增 `NotificationItem.qml`（几何用浏览器实测对过：352 边框盒下限、行高 78/58/56/52、
      light +2、六档位置各自一条独立列表），gallery 补齐 9 节，测试从 `tst_feedback.qml` 里那 3 条
      空转用例换成独立的 `tst_notification.qml`，像素复核另抓到「内容宽度漏算 padding」那条
      同源断言漏掉的 bug（见 PROGRESS.md 坑 84）
- [x] 修做（2026-10-16）：gallery「多行输入框」——`TextArea` 只有点顶部能输入。正文 `TextEdit`
      没写 `height`，命中区就只有「已有文本那几行」（空框 = 17px），点中间与点底部落在盒子内、
      `TextEdit` 外，被外层 `Flickable` 吃掉，焦点与光标都进不来。改成命中区 = 整个内容区
      （`height: Math.max(implicitHeight, scroller.height - paddingY)`），滚动区的
      `contentHeight` 也跟着从实际文本高度算（原来按 `rows` 夹过的盒子高算 ⇒ 短盒长文本时
      下面的行既滚不到也点不到）。`tst_input4` 补 2 个用例 / 8 处断言（只能按几何断言钉：
      这个 harness 里连裸 `TextEdit` 的合成点击都不会落光标，offscreen 与 cocoa 都一样），
      反向验证 `tests/tmp_textarea_mutate.py` 打 4 处（改回旧写法 / 多吃下边距 / 只往下铺 /
      滚动区按夹过的高度）**全部被抓**；行号与统计条排版无变化（cocoa 截图复核）
- [x] 补做（2026-10-16）：Progress 按官方重写（`value` / `tone` / `showText` 那套自造面换成
      `ProgressProps` 全表：`percent` / `type` / `size` / `direction` / `stroke`（颜色串或档位表）/
      `strokeGradient` / `strokeLinecap` / `strokeWidth` / `orbitStroke` / `showInfo` / `format` /
      `indeterminate` / `motion` / `circleWidth`（官方 `width`，撞 `Item.width`）/ `aria-*`），
      `generates.ts` 搬成 `src/ProgressStroke.js`，环形从 `Canvas` 换 `QtQuick.Shapes` 画弧，
      两套动画（数字 linear + 每帧取整、几何 300ms transition）分开实现，gallery 补齐 12 节，
      测试从 `tst_display.qml` 里那 4 条旧用例换成独立的 `tst_progress.qml`，`Upload` 两处调用点迁移
      （见 PROGRESS.md 坑 85）
- [x] 修做（2026-10-16）：gallery「Slider 滑动选择器 / 基本用法」——双滑块重合后再拖，动的是左边
      那颗。原来「按下时挑哪颗」按距离判（`nearestHandle`，平手归低值端），重合时 `dLow == dHigh`
      永远判给低值端，而低值端又被高值端夹着 ⇒ 往右一动不了。官方按**层叠**判：`mousedown` 挂在各
      自的手柄 `<span>` 上，上一次按下的那颗 `z-index: 2` 且松手不降（`slider/index.tsx:423/479` +
      `foundation.ts:507` 对比 `:594-611`）⇒ 谁最后拖过来就继续拖谁，谁也没拖过时是高值端（DOM 顺序）。
      换成 `pressHandle()` 后顺带补齐同一条规则的两半：点在手柄方块里不再跳值（官方
      `handleWrapClick` 对来自手柄的事件直接 return），以及按在手柄上时带 `dragOffset` 跟随指针。
      `tst_input2` 补 8 个函数 / 37 处断言，拖动这次是端到端验的（两次 move，见坑 86 —— 原来记在
      坑 27 的「值跟着走测不了」已推翻）；`tests/tmp_slider_mutate.py` 打 10 个变异**全部被抓**，
      过程中抓到两条空转用例并改正（见 `docs/slider-changes.md` 第 11 节）
- [x] 补做（2026-10-16）：Spin 按官方重写（`size`（`small`/`middle`/`large`）+ `color` 那只弧换成
      `SpinProps` 全表：`spinning` / `delay` / `tip` / `indicator` / `content`（官方 children），
      补上「包裹」那第二种形态：根节点被内容撑开、内容压暗 0.5、指示符整块浮在正中、
      `-block::after` 遮罩挡穿透点击），gallery 补齐 6 节（含原来缺的「带文字的」「自定义指示符」
      「延迟显示」，删掉自造的「颜色」那节），测试从 `tst_controls` 里那 2 条旧用例换成独立的
      `tst_spin.qml`（24 个函数 / 78 处断言，23 个变异全部被抓，见 PROGRESS.md 坑 87）
- [x] 补做（2026-10-17）：Skeleton 按官方重写（一块会呼吸的灰矩形换成官方 `SkeletonProps`
      —— `active`（缺省 false）/ `loading` / `placeholder` / `content`，并补上五个占位件
      `SkeletonAvatar`（六档尺寸 + `shape`）/ `Image` / `Title` / `Button` / `Paragraph`（`rows`），
      流光从「整块变色」改成官方那条 400% 宽、自左向右扫的渐变带，1400ms ease），
      gallery 补齐 4 节（组合使用那节的**六个**组合 demo 全数落地，含表格），测试从
      `tst_controls` 里那 2 条旧用例换成独立的 `tst_skeleton.qml`（27 个函数 / 113 处断言，
      43 个变异全部被抓，见 PROGRESS.md 坑 88）
- [x] 修做（2026-10-17）：Progress 环形进度条**锯齿**。根因不是「没开抗锯齿」——Qt 6.11 的
      `Shape` 默认走 `GeometryRenderer`，它把弧**展平成一段段短直线**、边缘不做覆盖率混合，
      那只 `Shape` 上原来写的 `antialiasing: true` 对它完全无效（带着照样量出 0 个边缘过渡像素）。
      改成 `preferredRendererType: Shape.CurveRenderer`（片元里解析算覆盖率）。`Shape.SoftwareRenderer`
      在这台机器的 RHI / Metal 后端**选不出来**（静默回落，像素与默认档相同），所以可用路径只有这一条。
      像素判据（`tests/tmp_progress_ring_shot.qml` 同一环画两遍 + `tests/tmp_ring_measure.py` 数边缘
      过渡像素与内沿半径取值数）：72px / 4 笔画 —— 改动前 0 个过渡像素、内沿只有 **6** 个不同半径，
      改动后 433 个 / **65** 个；120px / 12 笔画 —— 0 个 / **10** 个 对 766 个 / **64** 个；
      方头那档同样吃到 AA。不确定态的整圈旋转复核过（`tests/tmp_progress_ring_spin_shot.qml` +
      `tests/tmp_ring_angle.py`：`spinAngle` 179.7°→299.4°，量到的弧质心 233.78°→353.24°，
      正好 `+54°` = 108° 弧的中点），gallery 环形三节截图复核。补一条
      `tst_progress::test_ringUsesCurveRenderer()` 锁住渲染器点名（摘掉组件里那行就红，
      当场变异验过）。详见 PROGRESS.md 坑 89
- [x] 修做（2026-10-17）：Skeleton 页一拨「显示加载内容」就刷五条 `QML Skeleton: Binding loop detected
      for property "implicitHeight"`。环在 `src/Skeleton.qml`：容器非 loading 那支读
      `contentHost.childrenRect.height`，而宿主是 `anchors.fill: parent` ⇒ 宿主几何跟着容器、容器
      `height` 没写死时又回落成 `implicitHeight`，`childrenRect` 还是惰性算的，读一次就把自己标脏。
      **值一直是对的**，纯噪声。宿主改成 `width: control.width; height: childrenRect.height`
      （高由内容算，正好对上官方「loading=false 时那层 div 不生成」），容器读 `contentHost.height`。
      复现要**翻一次 loading**（页面默认 true，`--shot` 单拍不会冒）：`tests/tmp_skeleton_loop.qml`。
      `tst_skeleton` 补来回拨的 5 处断言（72→100→72），警告本身锁不住、只能靠那条探针 grep
      （详见 PROGRESS.md 坑 90）
- [x] 修做（2026-10-18）：**Modal 按官方补齐 13 个小节 + 命令式那一层**（用户「Modal 组件也缺少
      一些 example，补上」）。旧页面只有 5 节，缺的七节正好要本库没有的 `footerFill` / `header` /
      `fullScreen` / `Modal.method()` 那一套与 `modalRender` ⇒ 组件与页面一起做：`src/Modal.qml`
      整份换成官方 `ModalProps`（自造的 `showFooter` / `showCancel` / `confirmed()` / `open()` /
      `close()` 全删），新增 `src/ModalConfirm.qml`（五张命令式卡片本体）、`src/ModalHost.qml`
      （`info/success/error/warning/confirm` + `{destroy, update}` + `destroyAll`）、
      `src/ModalEscStack.js`（「一次 Esc 只关一层」）。三条最贵的：① 官方是**完全受控**的，
      `onOk` / `onCancel` 只通知、`closePolicy` 得写死 `NoAutoClose`，否则使用方那条 `visible:`
      绑定会被组件自己关层打断；② Esc 不能外包给 Qt 的路由 —— 两条同序列 `Shortcut` 同时 enabled
      会被判歧义、**两条都不激活**，且路由按创建顺序不认「最后打开」，所以 `escIsTop` 得由自己那份
      栈回灌成属性（`.js` 里的数组不是 notify，绑定里直接调 `isTop()` 会永远停在第一次的求值）；
      ③ `Shortcut` 默认 `WindowShortcut` 要 `window->isActive()`，cocoa 上从终端起的进程抢不到前台
      ⇒ 三条 Esc 用例全红，换 `Qt.ApplicationShortcut`（官方本来就是 document 级 keydown，不看焦点）。
      度量全部拿浏览器里真 React + semi.css 量过：448×236 / 202 / 182 / 178 / 158、内容区 398、
      footerFill 每颗 193、居中 448×354、`size` 四档 448 / 684 / 920 / 容器宽−64。像素复核顺手
      改掉页面一处：官方「自定义页脚」是 `footer={<Button type="primary">…</Button>}`（自然宽、贴右），
      直接把 Button 塞进页脚槽会被那个 Loader 的显式宽高拉成整块宽 ⇒ 节点里垫一层 `Item` 锚回右边。
      **验证**：`tests/tst_modal.qml` 78 个用例函数 / 305 处断言，offscreen 与 cocoa 两边都 100%
      （`tst_popup.qml` 回到 14 函数 / 44 处）；`tests/tmp_modal_mutate.py` 122 条变异，其余全部见血、
      2 条按等价登记（`Loader.implicitHeight` 与载入项的同名量法、offscreen 上窗口高==容器高）；
      `all_qmllint` 0 警告；cocoa 像素走 `tests/tmp_modal_shot.qml`（整页 5 片 + 13 节卡片 + 六张
      命令式卡，一律「把触发键滚进视野→窗口里点→按卡片自己的按钮收」）。详见 PROGRESS.md 坑 97
- [x] Table 轮（2026-10-18）：官方 28 个 demo 全补齐，`src/Table.qml` 按 `TableProps` / `ColumnProps` 补全，
      纯计算搬进新的 `src/TableEngine.js`、筛选面板拆成新的 `src/TableFilterPanel.qml`。度量取 compiled css 字面值
      （行高 53 / 45 / 37、表头行 38、控制列 48、组头行 41、分页外框 60、缩进 20、筛选菜单封顶 290 项高 36、
      面板宽夹 140–280）。三条最贵的结论：浅色档 `bg-0`…`bg-3` 与 white **全是 #ffffff**，颜色断言得先切深色
      并补一条「两个令牌此刻不相等」的哨兵；`C.CheckBox` 自己会随点击翻面，所以「点完再读 checked」测不出
      `checked: false` 那档变异，得换成一次都不点、状态只能来自 `filteredValue` 的路径；变异复核把嵌套 filters
      打红之后才发现 `flatten()` 在往 `const out` 上重新赋值（真 bug，嵌套筛选整片空掉）。
      **验证**：`tests/tst_table.qml` 122 函数 / 389 处断言 offscreen 全绿；`tests/tmp_table_mutate.py` 143 条锚点，
      三轮跑完 140 见血 / 3 等价登记（`count >= selectable`、不可达的 `defaultSortOrder` 兜底、与 `treeExpanded`
      同义的 `rowExpanded`）/ 0 存活；`all_qmllint` 0 警告；cocoa 像素走 `semi-gallery --page table --scroll N --shot`
      九片。详见 PROGRESS.md 坑 98
- [x] SideSheet 轮（2026-10-18）：按官方 `SideSheetProps` 重写 `src/SideSheet.qml`，页面补齐 7 节（含「如何引入」
      与「渲染在指定容器」），`tests/tst_sidesheet.qml` 48 函数 / 201 处断言。与 Modal 三处**反向**的默认值逐个钉住：
      `closeOnEsc` 缺省 false、`modal` 跟着 `mask` 走、官方压根没有默认页脚；两处 JS 真值判断（空串 title / footer
      等于没给）与 `closeIcon || <IconClose/>` 那条上游 bug（只记录不抄）。`disableScroll` 落成「只挂 WheelHandler
      的一层」（吃滚轮不吃鼠标，传了 `getPopupContainer` 就不锁）。Esc 复用 Modal 那份 `ModalEscStack.js`，
      跨组件那一档也补了用例。三条最贵：遮罩点击的判定要换回弹层盒子坐标系（面板在 (0,0)，别拿 `control.x` 比）；
      `size` 三档只管左右方位的宽、上下方位那条轴恒 448（官方 API 表写的 400 是过时的）；页脚节点被 Loader 的
      显式宽高拉成整块宽 ⇒ 再垫一层 `Item` 锚回右边 —— **这一条 48 条用例全绿，是看图看出来的**（Modal 那轮
      同一条坑第二次撞）。顺带挖出一条陈账：`src/Feedback.qml` 那张卡当年抄的是旧 SideSheet 的错度量，另开一轮
      重测（任务 #192）。
      **验证**：offscreen 全量 51 个文件 1937 通过 / 0 失败；`tests/tmp_sidesheet_mutate.py` 62 条锚点，
      第一轮 59 见血 / 3 漏，补两条断言后 61 见血 / 1 等价登记（`_borderOf()` 的宽闸与 `visible: width > 0` 同义）
      / 0 存活；`all_qmllint` 0 警告；cocoa 像素走 `tests/tmp_sidesheet_shot.qml`（整页 3 片 + 四方位 + 三档尺寸
      + 无遮罩 + 指定容器 + 自定义内容共 10 张卡）。详见 PROGRESS.md 坑 99
- [x] ScrollList 轮（2026-10-18）：官方把这条组件拆成**壳 + 列**两个（`ScrollListProps` 只有 header / footer / bodyHeight /
      className / style，滚轮、点选、无限循环全在 `ScrollItemProps`），而旧端口是**反的** —— 壳吃 `list`·`wheel`·`cycled`·
      `selectedIndex`，列只是静态行 `ScrollListItem { text; selected }`，信号还叫 `selected(data, index)`，官方那一节
      「三列滚轮联动」的 demo 一根都撑不起来 ⇒ `src/ScrollList.qml` 重写成壳、新增 `src/ScrollItem.qml` 承载官方列
      （`mode` 缺省 **wheel**、`cycled` 只对 wheel 生效、`list` 收 ItemData、受控 `selectedIndex`、`motion`、
      `transform` 因 `Item.transform` 是 FINAL 而改名 `textTransform`、`type`、`aria-label`、`onSelect(data)`），
      `ScrollListItem.qml` 从构建里摘除。页面补齐官方 2 节（如何引入 / 基本使用 = 上午下午 + 12 小时 + 60 分三列，
      奇数分钟 disabled，`footer` 传 Button 节点，`style` 照官方 demo 关掉阴影）。度量：行高 36、滚动 120ms linear、
      wheel 容器右侧留 18、选择带 content-box 36 + 上下各 1px = 38、遮罩 50% 高外扩 19、头部 20+32+1 = 53、
      页脚 20+20+1 = 41、壳底 bg-3 + 圆角 6 + `--semi-shadow-elevated` 且**没有描边**。三条最贵：滚轮几何全是相对量
      （第 i 项居中 ⇔ `contentY = i*36 - 留白`，写成 `i*36` 或 `floor` 时静态断言全绿、只有拖完吸附那一下会错）；
      QtTest 的合成事件有三条能让用例「假过」（根项要 `visible`、`mousePress/mouseRelease` 只吃 `(item,x,y,…)` 没有
      QPoint 档、程序化 `flick()` 永不等 `movementEnded`）；两条同义闸门互相遮蔽（`pickRow` 里重复的 `isDisabled` 与
      `TapHandler.enabled`、两条 `visible` 里的 `!row.disabled` 与 `HoverHandler.enabled`）—— 拆法是把重复的那扇换成
      官方 `cursor: not-allowed` 这格独立可观察量。官方两处自相矛盾只记录不抄：滚轮留白硬编码 132px 不跟 `bodyHeight`、
      ARIA 那节说有 `aria-selected` 而实现里是注释掉的。
      **验证**：`tests/tst_scrolllist.qml` 67 函数 / 313 处断言 offscreen 全绿；`tst_p5c.qml` 掉到 7 函数 / 27 处、
      `tst_scrollbar.qml` 那条改用新 `ScrollItem`；`tests/tmp_scrolllist_mutate.py` 104 条锚点，第一轮 93 见血 / 10 漏，
      补断言 + 拆双闸门 + 删重复闸门后 **103 见血 / 1 等价登记（`modelIndexOf` 的 `usesCycle` 叉：非循环列 `copies` 恒 1
      ⇒ `middleCopy` 恒 0 ⇒ 两支同值）/ 0 存活**；`all_qmllint` 0 警告；cocoa 像素走 `tests/tmp_scrolllist_shot.qml`
      （绿底卡片 + `grabImage()` 逐点读色：壳第一圈像素就是 bg-3 ⇒ 无描边、缝那一列 `#ededee`、选择带两条线在 184/221、
      normal 选中行 `#eaf5ff`、阴影只在默认档溢出到绿底上）。详见 PROGRESS.md 坑 100
- [x] Calendar 轮（2026-10-19）：用户「Calendar 组件也缺少一些 example，补上」—— 缺口比"补 example"大得多：
      整份 `CalendarProps` 面（`displayValue` / `events` / `mode`（缺省 **week**，旧端口是 month）/ `range`
      （官方**左闭右开**）/ `weekStartsOn` / `markWeekend` / `showCurrTime` / `scrollTop`（一次性）/
      `minEventHeight` + 四个渲染钩子 `dateGridRender` / `renderDateDisplay` / `renderTimeDisplay` /
      `allDayEventsRender`）、月视图「还有 N 项」那张 220 的卡、以及 `CalendarDate.js` 里三条缺失的算法
      （跨天带子的「只有第一天那份副本留下」、定时事件同组错开那处 off-by-one、起止颠倒先在副本上换过来）。
      页面按官方 8 节重做（如何引入 / 日视图 / 周视图 / 月视图 / 设置周起始日 / 多日视图 / 事件渲染用法 /
      自定义渲染）。**官方三条怪癖照抄并各钉一条用例**：卡片方位门槛写死 110 而卡片实宽 220、方向还反；
      「还有 N 项」显隐看稀疏长度、N 看真实占位数 ⇒ 有空洞那格露出「还有0项」；同组前两条定时事件重合。
      最贵的一条是实现层：`TapHandler` 缺省 `gesturePolicy` 是 `DragThreshold` ⇒ 只取**被动** grab，
      同一点上叠着的 handler 一起响应（官方的 `pointer-events` / `stopPropagation` 在 QML 没有声明式等价物），
      吞点击那层要 `WithinBounds`、按钮语义要 `ReleaseWithinBounds`；配套的另一半是 **QtTest 里失败的
      `compare()` 会跳过收尾的 `destroy()`** ⇒ 陈实例叠在同一坐标上，一次点击被两台各吃一遍（表现为
      "单独跑绿、整份跑红"），改成 `cleanup()` 一律清台。
      **验证**：`tests/tst_calendar.qml` 105 函数 / 464 处断言 offscreen 全绿；
      `tests/tmp_calendar_mutate.py` 200 条锚点，第一轮 140 见血 / 55 存活，补断言 + 收敛重复门 +
      删掉上游没有的冗余闸 + 去掉端口自己多加的那道 `break`（它把「分桶越界」那条变异给吞了）之后
      全量 **见血 / 等价登记 4（`diffDays` 的 round-vs-floor、`isAllDayEvent` 的 `in` 前置、`assignLanes`
      的 `min` 上限、全天带 `pointer-events` 在端口布局下无可观测对象）/ 0 存活**；
      全量 53 个文件 2260 通过 / 0 失败，`all_qmllint` 0 警告；cocoa 逐张复核 9 台日历，另用真点击开
      「还有 N 项」卡（220×196、开在锚点左侧、× 与四条事件都在）。详见 PROGRESS.md 坑 104
- [ ] `shadow-knob` 还剩两处没跟着重标：`ImageView` 预览滑杆的手柄（12px，仍是老的单层

      `.35` + `blurMax 8`）和 `Switch` 大档圆钮（24px，但那组参数是照 18px 默认档标出来的）。
      Qt 的模糊宽度跟着「源尺寸 + 2*blurMax」走，严格讲每一档圆径都要各标一次；这两处都带
      1px 描边顶替紧层，差距小，先记着。
- [x] 色块点击复制色值（已接系统剪贴板）
- [x] 删掉 `docs/tokens.html`（动效与搜索已搬进 gallery 的 Tokens 页）
- [ ] `docs.json` 需要一次**带逐页复核**的重新生成。`parse-docs.py` 这两条已经修好（转义竖线分列、`<Notice>` 折成「X：正文」），但整站重跑目前会同时带来两种变化：12 个组件（divider / icon / space / typography / checkbox / rating / slider / tree / treeselect / badge / tag / floatbutton）从现在的 0 行涨出真实 API 表，而 table 那页从 114 行掉成 0 行 —— 它的 `## API 参考` 后面紧跟 `## Table`，`parse_api` 那段 `(.*?)(?=^##\s|\Z)` 收到空 chunk。先把那条正则补成能吃多级 `##`，再重跑、再逐页看 79 页。详见 PROGRESS.md 坑 109。

- [ ] 代码块（按你的要求暂不做，位置留空）
- [x] 偶发测试失败 —— **已定位并修掉，其实不是「偶发」**。`ctest` 不设 `QT_QPA_PLATFORM`，
      用例跑在 cocoa 上；而 `Row` / `Column` 位置器要把「组件完成之后才搬进布局的子项」排好，
      得等下一帧。offscreen 单跑 `wait(20)` 刚好够一帧、cocoa 不够，于是
      `tst_form::test_groupDirectionSpacing` 只在 `ctest` 下红（报的是坐标 0 的陈旧值）。
      现在断坐标前轮询「最后一项已离开原点」（`tests/tst_form.qml` 的 `settled()`），
      把间距改错它照样报 `4 ≠ 16`。详见 `PROGRESS.md` 已知坑 61。**以后复验一律跑 `ctest`。**
