# ClearFile — 设计系统

> 来源：Stitch 生成稿（projectId: 4958124968439954092）| 更新：2026-04-14
> Phase 4 开发前端时 `Read: design/DESIGN.md` 获取所有设计规范，无需逐个看 HTML 文件。

---

## 视觉氛围

**简洁、可信、专业** — 仿 macOS HIG 原生风格，大面积白色留白，苹果蓝作为唯一强调色，卡片边框轻盈，无渐变无霓虹。

---

## 配色方案

| 角色 | 描述名 | 色值 | 用途 |
|------|--------|------|------|
| 主色 | 苹果蓝 | `#007AFF` | 主按钮、链接、选中状态、progress 填充 |
| 主色（深）| 深靛蓝 | `#005bc2` | 按钮 hover 态 |
| 主色（浅）| 淡蓝 | `#E8F3FF` | 选中导航背景、高亮区域 |
| 页面背景 | 雾白 | `#f9f9fb` | 页面底色 |
| Sidebar 背景 | 苹果灰白 | `#F5F5F7` | 侧边栏、次级面板 |
| 卡片背景 | 纯白 | `#ffffff` | 卡片、弹窗、输入框 |
| 卡片表面低 | 淡灰 | `#f2f4f6` | 展开行背景、悬停 |
| 卡片表面 | 灰 | `#eceef1` | 分组标题 |
| 文字主色 | 墨黑 | `#1D1D1F` | 标题、重要正文 |
| 文字次色 | 中灰 | `#6E6E73` | 说明文字、路径、标签 |
| 分割线 | 浅灰 | `#D2D2D7` | 列表分隔、边框 |
| 成功色 | 苹果绿 | `#34C759` | 完成状态、勾选 |
| 警告色 | 苹果橙 | `#FF9500` | 发现问题徽章 |
| 危险色 | 苹果红 | `#FF3B30` / `#a83836` | 删除、卸载操作 |

---

## 字体规则

| 用途 | 字体 | 字重 | 大小 |
|------|------|------|------|
| 页面标题 | Inter | SemiBold 600 | 20-24px |
| 模块标题（TopAppBar）| Inter | Bold 700 | 18-20px |
| 卡片标题 | Inter | SemiBold 600 | 14px |
| 正文 | Inter | Regular 400 | 14px |
| 说明/次要 | Inter | Regular 400 | 12-13px |
| 文件路径 | monospace | Regular | 12-13px |
| 大数字（报告页）| Inter | Bold 700 | 28-32px |

---

## 组件风格

### 侧边栏导航
- 宽度：220px，固定定位，`bg-[#F5F5F7]`，右边框 `#D2D2D7`
- 顶部：App logo（`cleaning_services` icon，蓝色圆角容器）+ "ClearFile" 文字
- 导航项（inactive）：`text-[#6E6E73]`，hover `bg-[#E8E8ED]`，8px 圆角
- 导航项（active）：`bg-[#E8F3FF]`，`text-[#007AFF]`，icon FILL=1，8px 圆角
- 底部：磁盘空间小组件（白卡 + 进度条）

### 顶部栏（TopAppBar）
- 高度：48-64px，`sticky top-0`，`bg-white/80 backdrop-blur-md`，z-50
- 中央：页面名称 semibold 16-20px
- 右侧：操作按钮（主按钮）

### 按钮
- **主按钮**：`bg-[#007AFF]`，白色文字，`hover:bg-[#005bc2]`，8px 圆角，`px-4 py-2`（约 36px 高）
- **危险按钮**：`bg-[#FF3B30]` 或 `text-[#FF3B30]` 文字按钮
- **幽灵按钮**：透明背景，`border border-[#D2D2D7]`，`text-[#1D1D1F]`

### 卡片 / Accordion
- 边框：`border border-[#D2D2D7]`，12px 圆角（`rounded-xl`）
- 阴影：`box-shadow: 0 4px 12px rgba(0,0,0,0.05)`（`.apple-shadow`）
- 展开头部：`bg-surface-container-low`（`#f2f4f6`），flex 布局，chevron 图标
- 子列表：`px-12` 缩进，`divide-y divide-[#D2D2D7]/30`

### 徽章（Badge）
- 警告：`bg-[#FF9500]/10 text-[#FF9500]`，`px-2 py-0.5 rounded-full`，bold xs
- 成功：`bg-[#34C759]/10 text-[#34C759]`，同上
- 危险：`bg-[#FF3B30]/10 text-[#FF3B30]`，同上

### 表单元素
- **Checkbox**：`w-4 h-4 rounded text-[#007AFF] border-[#D2D2D7] focus:ring-[#007AFF]`
- **Search input**：`bg-surface-container-low border border-[#D2D2D7] rounded-lg px-3 py-2 text-sm`

### 进度条
- 细条：`h-1`（4px），`bg-[#E8E8ED]` 背景，`bg-[#007AFF]` 填充，`rounded-full`
- 圆形进度：SVG `<circle>` stroke-dasharray，stroke-width 12

### 数据列表
- 行高：约 44-48px
- 交替背景：`white` / `#FAFAFA`
- 分割线：`divide-y divide-[#D2D2D7]/30`
- 文件路径：monospace 字体，`text-[#6E6E73]`，truncate

---

## 布局原则

- **窗口尺寸**：最小 1100×720px，`max-w-[1100px] max-h-[720px]`，窗口居中
- **间距基准**：4px 网格；内容区 padding `24-32px`
- **左栏固定**：220px sidebar，主内容 `ml-[220px]`
- **可滚动内容**：主内容区 `overflow-y-auto`，侧边栏 `overflow-y-auto`（nav 部分）
- **粘性底栏**：批量操作工具栏 `sticky bottom-0 bg-white border-t`

---

## 三态设计

每个功能模块必须覆盖：

| 模块 | 空状态 | 加载态 | 错误态 |
|------|--------|--------|--------|
| 扫描结果 | 图标 + "尚未扫描，点击开始扫描" + 蓝色按钮 | 圆形进度环 + 当前扫描路径 | Toast 红色 "扫描失败，请重试" |
| 大文件列表 | `folder_zip` icon + "未找到大文件" | 骨架屏（灰色占位行）| 内联错误文字 |
| 重复文件 | `content_copy` icon + "未发现重复文件" | 骨架屏 | 内联错误 |
| 应用列表 | "未检测到已安装应用" | 列表占位骨架 | 权限请求提示 |
| 清理报告 | "暂无清理记录，完成首次清理后显示" | — | — |

---

## 图标库

**Material Symbols Outlined**（Google CDN），按需加载。
- 统一样式：`font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24`
- 选中/强调态：`'FILL' 1`

---

## SwiftUI 实现映射

> Phase 4 用 SwiftUI 实现时，Stitch HTML 仅作视觉参考，使用以下原生组件对应：

| Stitch HTML 组件 | SwiftUI 对应 |
|-----------------|-------------|
| `<aside>` sidebar | `NavigationSplitView` sidebar column |
| `<nav>` items | `List` + `NavigationLink` + `.listRowBackground` |
| TopAppBar | `NavigationTitle` + `toolbar` |
| DonutChart | `Charts.Chart` + `SectorMark` |
| ProgressBar | `ProgressView` + `.progressViewStyle(.linear)` |
| CircularProgress | `ProgressView` + `.progressViewStyle(.circular)` 或自定义 `Circle` stroke |
| AccordionRow | `DisclosureGroup` |
| Checkbox | `Toggle` + `.toggleStyle(.checkbox)` |
| 文件列表 | `List` + `ForEach` |
| StickyFooterBar | `.safeAreaInset(edge: .bottom)` |
| Badge | `Text` + `.padding` + `.background(.orange.opacity(0.1))` + `.cornerRadius` |
| PrimaryButton | `Button` + `.buttonStyle(.borderedProminent)` + `.tint(Color(hex: "007AFF"))` |
