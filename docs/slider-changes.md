# Slider 变更说明

这份文档汇总 `src/Slider.qml` 从「能跑」到「与 Semi 对齐」这一串改动。每一项都记了**现象 → 根因 → 改法 → 验证方式**，以及仍未对齐的地方。

按时间顺序，起因都是一轮轮实际使用中发现的偏差 —— 不是照单核对规格做出来的。

> 每条对应的「坑」记在 [`PROGRESS.md`](./PROGRESS.md) 的「已知坑」里（编号见各节），本文是给 Slider 这一条的汇总视图。

## 一、对齐状态一览

| 项 | Semi 规格 | 本库 | 状态 |
| --- | --- | --- | --- |
| 轨道厚度 | `$height-slider_rail: 4px` | 4 | ✅ |
| 手柄直径 | `$width-slider_handle: 24px` | 24 | ✅ |
| 两端余量 | `$spacing-slider-paddingX: 13px` | 13 | ✅ |
| 刻度点 | `$width-slider_dot: 4px` | 4 | ✅ |
| 手柄定位 | `translateX(-50%)`，圆心落在百分比点上 | 圆心沿整条轨道行走（等价） | ✅ |
| 手柄投影 | `@mixin shadow-knob` | 同规格，参数照官网衰减曲线量过 | ✅ |
| 描边状态 | 默认无描边、**按下**出焦点色 | 同 | ✅ |
| 禁用态填充 | `--semi-color-primary-disabled` | 同 | ✅ |
| 禁用态投影 | `shadow-0`（去掉） | 同 | ✅ |
| 禁用态刻度点 | 保留 | 同 | ✅ |
| 刻度标签位置 | 挂**轨道**外沿（轨道底 18 / 标签顶 23） | 挂**手柄**外沿 | ⚠️ 有意偏离 |
| 手柄默认描边 | 无（细线来自 `shadow-knob` 第二层） | 同（`border: none` + 第二层投影） | ✅ |
| 重叠时抓哪颗 | 层叠决定：上一次按下的那颗 `z-index: 2`，松手不降 | `pressHandle()` 显式实现，缺省高值端在上 | ✅ |
| 单击手柄 | 不改值（`handleWrapClick` 对来自手柄的事件直接 return） | 同 | ✅ |
| 按下后手柄跟随 | 带 `_dragOffset`，不跳到指针底下 | 同（`dragOffset`） | ✅ |
| 重叠时绘制层叠 | 上层那颗也画在上面 | 手柄 z 按 `dragHandle` 互斥抬到 1 / 0，投影精灵同步 | ✅ |
| 提示显示时机 | `computeHandleVisibleVal` | 同 | ✅ |

## 二、逐项变更

### 1. 拖动松手后值变 0

**现象**：怎么拖，最后都变成 0。

**根因**：拖动换算用的是 `centroid.position`。Qt 文档写得很清楚 —— *「after the point is released, or when the current point is being handled by a different handler, position.x and position.y are 0」*。手势一结束，`centroid` 被复位成 `(0,0)`，而那次复位**同样会触发** `onCentroidChanged`，于是把值算成了 min。

**改法**：只认拖动进行中的通知（`if (!active) return`）。见已知坑 29。

**验证**：`test_sliderIgnoresDragPositionWhenInactive` —— 喂「不活跃 + 位置 0」和「不活跃 + 位置 999」，值都不许动。去掉闸门它立刻失败。

### 2. 拖到最左边，填充还突出一小块

**现象**：值到 min 时轨道上仍有一小段填充。

**根因**：填充宽度公式无条件加了 `handleSize / 2`，到 0 时还剩 8px。手柄是个圆，**圆在轨道左端的切点只盖住一两个像素**，那 8px 的左圆角就从抗锯齿边缘透了出来。值不为 0 时这点透色正好和手柄接上、看不出来。

**改法**：先是在 min 时把宽度取 0；后来几何换成「圆心沿整条轨道行走」之后，min 时圆心正好落在轨道起点，填充**天然为 0**，特判就删掉了。见已知坑 30。

**验证**：受控渲染逐像素量（值 0 时蓝色像素从 1 个变成 0 个，值 1/50/100 不变）+ `test_sliderFillLength`。

### 3. 能力补齐（这一批最大）

官网 slider 页有九节，我们只有四节。查下来是两回事：一部分是计划书定的「核心小节」取舍，一部分是**组件压根没那个能力**。这一批把能力补齐：

| 能力 | 属性 |
| --- | --- |
| 双滑块 | `range` + `values`（顺序无所谓，内部按大小当低/高，互相不越界） |
| 垂直 | `vertical` / `verticalReverse`（默认上小下大，反向即上大下小） |
| 刻度 | `marks`（`[{ value, label }]`）/ `showMarkLabel` / `tooltipOnMark` |
| 分段背景 | `railContent`（画自定义底纹）/ `railGradient` / `included` |
| 手柄圆点 | `handleDot`（`{ color, size }`，或数组按手柄分别给） |
| 边界值提示 | `showBoundary` |
| 自定义提示 | `tipFormatter`（function） |
| 回调 | `moved(var)` / `afterChange(var)` |

垂直反向的语义是照源库实现定的（`foundation.ts` 里 `stepValue = (startPos + len - pos)/len * ...`），不是猜的。提示的显示时机照 `computeHandleVisibleVal`：`showValue` 常显，否则只有给了 `tipFormatter` 时才在拖动中显示。

顺带修掉一处**语义做错**：「带标签的」在官网指的是 **`marks` 刻度标签**，我们原来做成了「滑块旁边放一个文字标签 + 滑块」—— 标题对上了、内容不是一回事。

**验证**：13 条单测 + 受控渲染逐像素核对水平/垂直的坐标换算。

### 4. 手柄尺寸 16 → 24，定位模型跟着换

**根因**：Semi 的 `$width-slider_handle` 是 24，我们 16；两端余量 Semi 是 13。

**注意**：光把数字改大不行。原来那套「把行程缩进 `handleSize`、让手柄留在轨道内」的模型，在手柄变宽之后会让圆心离轨道端点 12px —— 于是 min 时填充还剩 12px（第 2 条那个毛病，只是从 8px 变 12px），而且两端永远点不到真正的 0 / 100 位置。

**改法**：手柄定位改成**圆心沿整条轨道行走**（`axisPosOf(v) = railStart + ratio * railLength`），这正是 Semi 的 `translateX(-50%)` 模型。

**验证**：把官网文档页整页截图（3386×19704）拿来量像素 —— 它是 2x，填充条 8 物理像素 = 4 逻辑，手柄内区 47 物理 + 1px 描边 ≈ 24 逻辑，和 `variables.scss` 上的数字对得上；再按同比例并排渲染一版对比，直径 / 轨道厚度 / 手柄位置 / 填充范围四项全一致。见已知坑 31。

### 5. 刻度标签的两次错位

**第一次**：标签压在**轨道**上。

根因：刻度标签的 y 写成了 `railStart + trackHeight + 5`，而 `railStart` 是**水平**方向给手柄留的余量 —— 我拿它当垂直偏移用了。而轨道是拿整个组件的高度居中的，加了刻度（组件被撑高）之后轨道中心下移，正好和标签重叠。

改法：引入 `handleRowCenter = handleSize / 2`，轨道与手柄只在**手柄那一行**里居中。见已知坑 38。

**第二次**：标签不压轨道了，但压在**滑块**上。

根因：刻度挂在了**轨道**外沿（照 Semi 的算法，轨道底 + 5），但手柄比轨道高得多（24 vs 4）：标签的文字首行落在手柄底边**上方 4px**。垂直方向同理。

改法：改成挂**手柄**外沿（`marksTop = handleRowCenter + handleSize/2 + markGap`）。这是**有意偏离 Semi** —— 它那边照轨道算，手柄其实也盖进标签区。见已知坑 37。

**验证**：水平量出手柄底边 44 / 文字首行 40（压住 4px）→ 改后 44 / 54.5（分开 10.5px）；垂直量出文字距手柄右沿 9px。回归测试 `test_sliderMarksClearOfRail`。

### 6. 手柄投影

Semi 的手柄是 `@mixin shadow-knob`：`box-shadow: 0 4px 6px rgba(0,0,0,.1), 0 0 1px rgba(0,0,0,.3)`，即「软投影 + 1px 细线」两层。用 `MultiEffect` 实现。

**关键**：`shadowColor` 不能照抄 CSS 的 `.1` —— MultiEffect 对阴影透明度衰减得多，直接照抄出来只有官网的 **1/3 强度**。正确做法是**照着目标渲染量衰减曲线**：把官网整页截图放大，量「手柄左沿外 2.5px 处降了多少」，再调参数去凑。最后落在 `rgba(0,0,0,0.35)` + `blurMax 8` + `shadowBlur 1.0` + `shadowVerticalOffset 4`，最暗那圈与官网**都是 215**。

另外 `autoPaddingEnabled`（默认 true）会自动给效果项留出阴影的地方，配合 `anchors.fill: 源` 就行 —— **别手动把效果项放大**，那样源会被拉伸填满。Semi 那条 `0 0 1px` 的细线 MultiEffect 一次只出一个投影做不了，由手柄自己的 1px 描边顶替。

同一套参数也给了 `Switch` 的圆钮和 `ImageView` 预览层的缩放手柄 —— 查源库发现 `shadow-knob` 就用在 `slider.scss` 和 `switch.scss` 两处，而预览层的滑杆继承的是同一套手柄样式。见已知坑 34。

**踩到的**：MultiEffect 的**可见性不跟着源走** —— 单值模式下第二个手柄隐藏了，但它的效果项照画，轨道右端凭空多出一个「幽灵手柄」。见已知坑 32。

### 7. 那圈蓝描边挂错了状态

**现象**：鼠标一划过手柄就出蓝圈。

**根因**：Semi 的 `-handle-clicked` 只在**按下**时给 1px 焦点色描边；hover 是 `background-color: white`，也就是**没有视觉变化**。我们挂到了 hover 上。

**验证**：`test_sliderHandleBorderFollowsPress`（默认灰 → 悬停仍灰 → 按下焦点色 → 松开回灰）。把 hover 分支加回去它立刻失败。

### 8. 禁用态

**根因**：一开始写成「填充用 `colorDisabledBg`、手柄照旧带投影」—— 和 Semi 差得挺明显。Semi 的 `-disabled` 其实是三件具体的事：

| 部件 | Semi 的规则 |
| --- | --- |
| 填充 | `$color-slider_track_disabled-bg` = `--semi-color-primary-disabled`（blue-2 那档浅蓝），**不是通用灰** |
| 手柄 | `@include shadow-0` —— 把 `shadow-knob` 换成 `box-shadow: none`，投影整个去掉 |
| 刻度点 | 只改 cursor / shadow，**点留着** |

所以禁用态的观感是「浅蓝填充 + 没有投影的白圆钮」，不是「整体变灰」。

**验证**：官网那条 Disabled 滑块的填充像素值正好是 `(152,205,253)` = blue-2 ✓；我们的渲染逐像素一致。投影也量了：正常条下方有 179→228→250 的衰减，禁用条全是 255。回归测试 `test_sliderDisabledLook`。见已知坑 36。

### 9. 分段背景拖动时卡

**现象**：拖动时能明显感觉到背景在刷新，而且比较慢。

**根因**：那节原来用 `railGradient` 配 6 个**绑在手柄值上**的 `GradientStop`，拖动时 position 每帧都在变 → **每帧重建一次渐变材质**。

**测量**（8 个实例放大成本，各 5 轮取中位数，看**最长帧**）：

| 变体 | 中位帧数 | 最长帧 |
| --- | --- | --- |
| 渐变 stop **绑活值** | 67 | **34.2ms**（60Hz 下掉帧） |
| 渐变 stop 是**常量** | 68 | 22.8ms |
| **完全没有渐变** | 68 | 22.6ms |

后两行几乎一样 → **「有渐变」本身不要钱，要钱的是每帧重建材质**。

**改法**：分段用**三块实色**画。为此给 Slider 加了 `railContent` 插槽（对应 Semi 的 `railStyle`）：坐标是轨道局部坐标，三块的边界直接绑手柄位置。改后最长帧回到 **22.7ms**，与「完全没有渐变」的基线齐平。

`railGradient` 保留 —— **静态渐变是可以放心用的**。Semi 用 `linear-gradient` 是 CSS 的限制，QML 没必要跟着走。见已知坑 39。

### 10. 投影改成「渲一次 + 平移」

**根因**：每个手柄配一个 `MultiEffect`，而手柄在拖动时每帧都在动 → 模糊每帧重算。Qt 文档专门提醒过这条：*「avoid using source items which animate, so blurring doesn't need to be regenerated in every frame」*。

但投影的形状是**固定的**（一个带投影的白圆），**只有位置在变** —— 所以渲一次就够了。

**改法**：一个隐藏的底片（白圆 + `MultiEffect`），两个手柄各用一个 `ShaderEffectSource { live: false; hideSource: true }` 把纹理平移过去。

| 方案 | 中位帧数 | 最长帧 |
| --- | --- | --- |
| `MultiEffect` 直接画 | 70 | **33.1ms**（掉帧） |
| 底片 + 平移 | 76 | **23.3ms** |

**几个要点**：

- `hideSource: true` 会把底片**连同里面的效果项**一起隐掉，不用自己设 `visible: false`
- `live: false` 才是「只渲一次」；默认 `live: true` 会跟着源每帧重渲
- `sourceRect` 要**手动留出投影溢出的余量**（`shadowPad = 12`），否则纹理边界会把投影切掉
- 精灵位置 = 手柄位置 − `shadowPad`（`sourceRect` 是相对底片左上角的）
- 一个源可以给多个 `ShaderEffectSource` 共用

**顺带**：手柄不再透过纹理画之后，边缘位置反而**更准** —— 之前被纹理采样挪了约 0.5px。见已知坑 40。

### 11. 双滑块重叠时抓错手柄（2026-10-16）

**症状**：把右边那颗拖到与左边重合，再按着这对手柄拖，动的是**左边**那颗；而左边那颗被右边夹着，往右一动不了 —— 只能先往左把它分离开，再回来拖右边。官方不是这个行为：**谁最后拖过来，这对手柄就归谁**。

**根因**：本端「按下时挑哪颗」用的是 `nearestHandle()`（离谁近算谁，平手算低值端）。两颗重合时 `dLow == dHigh`，永远判给低值端。

**官方的机制是层叠，不是距离**（`semi-ui/slider/index.tsx`）：

- `mousedown` 挂在**每颗手柄自己的 `<span>`** 上（`:425` / `:481`），谁收到事件由 z-index 决定；
- range 分支里 `chooseMovePos === 'min'` 的那颗 `zIndex: 2`、另一颗 `1`（`:423` / `:479`），**只看 `chooseMovePos`、不看是不是还在拖**；
- `chooseMovePos` 只在 `onHandleDown` 里写（`foundation.ts:507`），`onHandleUp` 不重置（`:594-611`）⇒ 上一次拖的那颗**永久**留在上层；
- `chooseMovePos` 初值 `''` ⇒ 两颗同为 `z-index: 1`，按 DOM 顺序，`max` 在 `min` 之后 ⇒ **谁也没拖过时上层是 `max`**。

「按最近」只属于**点轨道**那条路（`checkWhichHandle`，`foundation.ts:815-829`，平手取第一个），而且 `handleWrapClick` 一上来就 `if (isDrag || disabled || isEventFromHandle(e)) return`（`:774-778`）—— **点在手柄上时轨道逻辑整个跳过**，所以官方单击手柄不改值。

**改法**（`src/Slider.qml`）：

- `pressHandle(pos)`：两颗的 24px 方块都盖住这个点 → 归 `dragHandle`（上层那颗）；只盖住一颗 → 归那颗；都没盖住 → 才 `nearestHandle(pos)`；
- `dragHandle` 缺省 **1**（对应上面那条 DOM 顺序），松手不清空；
- `TapHandler` 加 `if (onHandle(pos)) return`，点手柄不再跳值；
- 顺手把官方 `_dragOffset`（`foundation.ts:514-522`）搬成 `dragOffset`：按在手柄方块里时，手柄带着「按下点离圆心的差」跟随指针，不跳到指针底下 —— 少了它，按住重合那对的左半边往右拖，前 10px 什么都不动。

**绘制层叠**：2026-10-22 补齐。两颗手柄的 `z` 按 `dragHandle` 互斥抬到 1 / 0（`dragHandle===0` 时低值端在上，否则高值端在上），投影精灵跟着各自手柄的 `z` 走 —— 不同步抬精灵的话，上层那颗的影子会沉到下面那颗底下。不绑 `dragHandler.active`：官方 z-index 松手也不降，重合时才能继续看出归谁。回归测试 `test_sliderOverlapRaisesPressedHandleZ`。

**合并规则本来就是对的**：官方 `outPutValue()` 拖过头时塌成 `[max, max]` / `[min, min]`（`foundation.ts:432-441`），和本端的 `a = min(next, b)` / `b = max(next, a)` 同解，没动。

## 三、新增 / 变更的 API

**新增**：`range`、`values`、`vertical`、`verticalReverse`、`marks`、`included`、`showMarkLabel`、`tooltipOnMark`、`handleDot`、`tipFormatter`、`showBoundary`、`railGradient`、`railContent`、`afterChange`，以及 `setFromY()`、`axisPosOf()`、`valueOfAxisPos()` 等几何函数。

**变更**：`moved(real)` → `moved(var)`（双滑块时传数组）；`fillWidth` → `fillLength`（方向中立）；手柄的绘制从「MultiEffect 直画」改成「直接画 + 独立投影精灵」。

**新增只读属性**（供外部与测试用）：`handle`、`handleEnd`、`rail`、`railStart`、`railLength`、`lowValue`、`highValue`、`fillFrom`、`fillLength`、`markList`、`marksTop`、`handleRowCenter`、`bubbleValues`。

**2026-10-16 加的交互内部件**（不是官方 prop 面，供测试与后续维护读回）：`dragHandle`（上一次按下的那颗，缺省 1）、`dragOffset`（按下点与圆心的差）、`pressHandle(pos)`、`onHandle(pos)`、`onHandleRect(pos, index)`、`handleValue(index)`。

**禁用**仍走继承来的 `enabled`（本库惯例，不另设 `disabled`）。

## 四、测试与文档

`tests/tst_input2.qml` 里的 Slider 用例从 **3 条增加到 19 条**，覆盖：几何换算（`setFromX` / `setFromY` / 垂直反向）、双滑块不越界、刻度的范围过滤与标签、`handleDot` 两种写法、`included`、禁用态、投影精灵数量、描边状态、点击轨道跳值、`railContent`。

其中**五条是真正的回归测试** —— 我把对应的修复临时撤掉跑过，确认它们会失败：

| 用例 | 撤掉什么会失败 |
| --- | --- |
| `test_sliderIgnoresDragPositionWhenInactive` | 拖动时的 `active` 闸门 |
| `test_sliderMarksClearOfRail` | 轨道按「手柄那一行」居中 |
| `test_sliderHandleBorderFollowsPress` | 描边不跟 hover |
| `test_sliderDisabledLook` | 禁用填充色 / 禁用去投影 |
| `test_sliderShadowCountFollowsHandles` | 投影精灵跟随手柄可见性 |

页面从 4 节扩到 8 节，与官网小节一一对应：基本用法 / 带输入框的 / 自定义提示 / 带标签的 / 分段背景 / 受控组件 / 垂直 / 滑块带圆点。

**2026-10-16 这一轮**：Slider 用例 **21 条 → 29 条**（该文件 147 → 184 处断言），新增的 8 条盯着手柄归属：`test_sliderPressHandleUsesHandleRects`、`test_sliderOverlapKeepsLastDraggedHandle`、`test_sliderOverlapKeepsLastDraggedHandleLowSide`、`test_sliderOverlapBeforeAnyDragGrabsHighHandle`、`test_sliderOverlapThenSeparatesBothWays`、`test_sliderHandlePressKeepsGrabOffset`、`test_sliderTapOnHandleKeepsValue`、`test_sliderTapOnOverlappedHandlesKeepsValues`。

拖动这次是**端到端**验的（按下 → 挪 15px 推激活 → `wait` → 挪到目标 → `wait` → 松开，见 `dragSlider()`）—— 原来记在已知坑 27 的「`centroid` 不跟随合成移动、值跟着走那半测不了」是错的：跟，只是激活要等下一帧，所以要发两次 move。

变异复核（`tests/tmp_slider_mutate.py`，变异回执）：10 个变异全部被抓 —— 退回最近优先 / 丢 `dragOffset` / 取消「点手柄不改值」/ 层叠初值反过来 / 平手改判 / 命中区缩成点 / 命中区放大一倍 / 永远抓高 / 永远抓低 / 用当前点代替按下点。两条被这个流程逼出来的修正：

| 一开始的用例 | 问题 | 改成 |
| --- | --- | --- |
| 点重合那对 `mouseClick(s, 55)` 不改值 | 低值端被 `b` 夹着，往右点本来就动不了 → 撤掉守卫照样绿 | 方块内 41 不动 + 方块外 38 要动到 13，正反各钉一边 |
| 把低值端拖上去那条（`LowSide`） | 只有「永远抓高值端」这个变异能让它红 | 保留，作为反方向的对称保险（M8 命中） |

## 五、仍未对齐的地方

1. **`Switch` 圆钮与 `ImageView` 预览手柄仍用 `MultiEffect` 直画**，没有做底片缓存 —— 它们的圆钮不是连续移动的（只在切换/拖动时动一下），没有「每帧重算」的问题，加底片反而多一张纹理。Slider 做是因为双滑块拖动是连续动作。
2. **单击手柄不发 `afterChange`**。官方 `onHandleDown` 一按下就往 `window` 挂 `mouseup` 监听，所以「按下手柄再松开」这一击也会回调 `onAfterChange`（值没变也回调）。本端的 `TapHandler` 现在对方块内的点击直接 `return`，不再发 `afterChange` —— 值本来就没动，靠 `afterChange` 提交的调用方不受影响。

（原先这里第 1 条「我们用 1px `colorBorder` 顶替那圈细线」已按官方改掉：静止态 `border: none`，细线来自 `shadow-knob` 的第二层 `0 0 1px rgba(0,0,0,.3)`，描边只在 `-handle-clicked`（1px 主色）与 `-disabled`（1px `colorBorder` 且去投影）两种状态下有。见已知坑 34 与本文第 10 节。）

（原先这里的第 2 条「`Switch` 圆钮 20px 且居中、Semi 是 18px」已修：圆钮改成按 `$width-switch_knob_*` 分档 12 / 18 / 24，定位是 `1px 描边 + $spacing-switch_knob-padding`，与 Semi 的 padding box 口径一致；顺带补了三档轨道尺寸、hover/`:active` 态与 `checkedText` / `uncheckedText`。）

## 六、附：几条测量经验

这几条都是这次踩出来的，写下来省得下次再绕：

- **`FrameAnimation` 的 `frameTime` / `smoothFrameTime` 单位是秒**，不是毫秒。打印时忘了 ×1000 会全是 `0.0`，看着像没数据。
- **平均帧率分不出快慢**。这台机器上帧率被垂直同步封在 45~62fps，连「什么都不动」的对照组也一样。要看**最长帧** —— 60Hz 下超过 16.7ms 就是掉帧，33ms 就是丢了一帧，肉眼看到的就是「卡一下」。
- **单个实例测不出差别**，得把成本**放大若干个实例**。而且噪声很大：同一方案 3 轮和 5 轮测出来的结论能反过来（我第一次就测出了相反的结果），**取中位数、多跑几轮**。
- **`GradientStop` 的 `position` 绑到会变的量上 = 每帧重建材质**；要跟着值动的底纹，画实色块。
- **`MultiEffect` 的阴影参数不能照抄 CSS 的 alpha**，要照着目标渲染量衰减曲线。
- **`MultiEffect` 的可见性不跟着源走**，效果项要自己管可见性。
- **合成指针事件能不能用，取决于 `init()` 里有没有 `testCase.visible = true`**（见已知坑 27）。点击和悬停**可以**自动验证；拖动也可以，但要发**两次 move** —— 处理器要等跨过阈值之后的那一帧才激活，第一次 move 的位置是「未激活」时收到的（被 `active` 闸门挡掉），第二次才落到 `centroid` 换算里（2026-10-16 更正，见坑 86）。
