# ClearFile — 组件清单（从 Stitch HTML 提取）

> 来源：design/screens/*.html | 更新时间：2026-04-14

---

## 全局组件（出现在 2+ 个页面）

| 组件名 | HTML 结构 | 使用页面 | 关键样式 |
|--------|-----------|---------|---------|
| **Sidebar** | `<aside class="w-[220px] h-full flex flex-col py-6 bg-[#F5F5F7] border-r border-[#D2D2D7] fixed left-0 top-0">` | 全部 8 页 | 固定宽 220px，背景 #F5F5F7，右边框 #D2D2D7 |
| **SideNavItem（inactive）** | `div.flex.items-center.gap-3.px-3.py-2.text-[#6E6E73].hover:bg-[#E8E8ED].rounded-lg` | 全部 8 页 | 文字 #6E6E73，hover 背景 #E8E8ED，8px 圆角 |
| **SideNavItem（active）** | `div...bg-[#E8F3FF].text-[#007AFF].rounded-lg` | 全部 8 页 | 背景 #E8F3FF，文字 #007AFF，icon FILL=1 |
| **Material Icon** | `<span class="material-symbols-outlined">icon_name</span>` | 全部 8 页 | font-variation-settings: FILL 0, wght 400 |
| **TopAppBar** | `<header class="flex items-center h-12~16 px-8 sticky top-0 bg-white/80 backdrop-blur-md">` | 全部 8 页 | 粘性顶栏，磨砂玻璃背景，z-50 |
| **MainContent** | `<main class="ml-[220px] flex-1 bg-white flex flex-col h-full overflow-y-auto">` | 全部 8 页 | 左偏移 220px，白底，可滚动 |
| **PrimaryButton** | `<button class="bg-[#007AFF] hover:bg-[#005bc2] text-white text-sm font-semibold px-4 py-2 rounded-lg">` | 全部操作页 | 蓝底白字，hover 加深，8px 圆角，36px 高 |
| **DangerButton** | `<button class="...text-[#FF3B30]...">` or `bg-[#FF3B30]` | 卸载/删除页 | 红色，文字按钮或填充按钮 |
| **Badge/Tag** | `<span class="bg-[#FF9500]/10 text-[#FF9500] text-xs font-bold px-2 py-0.5 rounded-full">` | System Junk, Large Files | 背景色 10% 透明，圆角全圆 |
| **SectionCard** | `<div class="border border-[#D2D2D7] rounded-xl overflow-hidden apple-shadow">` | System Junk, Dev Tools | 圆角 12px，浅边框，轻阴影 |
| **Checkbox** | `<input type="checkbox" class="w-4 h-4 rounded text-[#007AFF] border-[#D2D2D7] focus:ring-[#007AFF]">` | System Junk, Duplicates, Large Files | 4px 圆角，accent 色 #007AFF |
| **ProgressBar（thin）** | `<div class="w-full h-1 bg-[#E8E8ED] rounded-full"><div class="h-full bg-[#007AFF]"></div></div>` | Sidebar storage indicator, Scan Progress | 高度 4px，圆角，#007AFF on #E8E8ED |
| **AppLogo** | `<div class="w-8 h-8 rounded-lg bg-primary-container">cleaning_services icon</div>` | 全部页面 sidebar | 蓝色圆角容器 + Material icon |

---

## 页面专属组件

| 组件名 | 所属页面 | HTML 结构参考 |
|--------|---------|-------------|
| **DonutChart** | Overview | SVG `<circle>` 多段 stroke-dasharray，中心绝对定位文字 |
| **StorageLegendGrid** | Overview | `grid grid-cols-5 gap-6`，色点 + 名称 + 大小 |
| **SummaryStat** | Overview | 3 列统计卡，`bg-surface-container-low`，图标 + 数值 + 标签 |
| **CircularProgressRing** | Scanning | SVG circle stroke，中心显示百分比 |
| **CategoryProgressRow** | Scanning | 图标 + 名称 + 横向 progress bar + 状态（done/scanning/pending）|
| **AccordionRow** | System Junk | 展开/收起，头部 flex + `expand_more/less` 图标 |
| **AccordionSubItem** | System Junk | 缩进 `px-12`，`divide-y divide-[#D2D2D7]/30`，文件名 + 大小 |
| **StickyFooterBar** | System Junk, Large Files, Duplicates | `sticky bottom-0 bg-white border-t`，选中数量文字 + 操作按钮 |
| **FileListTable** | Large Files | 表格行：checkbox + 图标 + 名称 + 路径（monospace）+ 大小 + 操作 |
| **DuplicateGroupCard** | Duplicates | `bg-[#F5F5F7] rounded-xl`，组标题 + 子文件行 + 单选保留 |
| **AppGrid** | App Uninstaller | 3 列网格，App 卡（图标 + 名称 + 版本 + 大小），选中态蓝色边框 |
| **ResidualFileList** | App Uninstaller | 选中 App 后展示关联残留路径列表，带 checkbox |
| **DevToolSection** | Developer Tools | 工具图标 + 名称 + 总大小 + 展开子项（DerivedData/Cache 等）|
| **SuccessHero** | Clean Report | 大绿色 checkmark + 标题 + 副标题 |
| **BeforeAfterBar** | Clean Report | 两行对比进度条：Before vs After |
| **HistoryTable** | Clean Report | 清理历史：日期 + 释放 + 分类 + 耗时 |

---

## 颜色使用规律

| 场景 | 颜色 |
|------|------|
| 主操作（扫描、清理）| `#007AFF` |
| 危险操作（删除、卸载）| `#FF3B30` / `#a83836` |
| 警告信息（发现问题）| `#FF9500` |
| 成功状态（清理完成）| `#34C759` |
| 卡片背景 | `#F5F5F7` / `#eceef1` |
| 分割线 | `#D2D2D7` |
| 主文字 | `#1D1D1F` |
| 次文字 | `#6E6E73` |

---

## 图标映射（Material Symbols Outlined）

| 功能 | 图标名 |
|------|--------|
| Overview | `dashboard` |
| System Junk | `delete` |
| Large Files | `folder_zip` |
| Duplicates | `content_copy` |
| App Uninstaller | `apps` |
| Developer Tools | `terminal` |
| Clean Report | `assessment` |
| App Logo | `cleaning_services` |
| 缓存类 | `cached` |
| 展开/收起 | `expand_more` / `expand_less` |
| 成功 | `check_circle` |
| 导航前后 | `chevron_left` / `chevron_right` |
