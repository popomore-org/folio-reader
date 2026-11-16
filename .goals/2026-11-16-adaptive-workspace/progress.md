# Progress

## Current

- Status: 宽表格和窄窗滚动已通过原生与扩展验证。
- Blockers: 无。
- Next: 推送 PR，打包验签并检查 CI。
- Branch/PR: fix/folio-release-toolchain / Folio #5。

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 自适应工作区 | 目录树、大纲和分栏有效分配可用空间 | complete |
| Markdown 表格 | 宽表格在宽窗展开，窄窗可在表格内滚动 | complete |
| 验证与交付 | 原生和 Quick Look 检查通过，提供候选镜像 | in progress |

## Steps

### Step 1 — 2026-11-16 — 统一布局计算

- 工作区先压缩可见的侧栏，再按中间区域宽高在左右和上下分栏之间切换。两种方向分别保留拖拽比例，分隔线支持双击恢复。

### Step 2 — 2026-11-16 — 原生验收

- 路径覆盖三个分隔线的实际拖拽、窄窗自适应、上下分隔线双击恢复、进入和退出全屏时的分栏比例恢复。
- 实际将标签拖到底部创建上下分栏。源码与预览切换方向后仍有草稿，保存及回读确认了磁盘内容。窄窗中的底栏与辅助标签随方向更新。
- 布局计算检查覆盖 660 点宽窗口、侧栏收窄、Git 内容宽度、方向切换和分隔线限制。Quick Look 检查通过 79 个后缀、行号与图表。

### Step 3 — 2026-11-16 — 候选版本交付

- WebKit 验证 360 和 1200 点视口下的 Markdown、源码和 CSV 预览宽度。镜像 `/Users/popomore/Downloads/Folio-0.1.1-d3e800b-arm64.dmg` 已挂载验签并核对主应用和扩展资源。
- [Folio CI](https://github.com/popomore-org/folio-reader/actions/runs/43804884973) 通过，Meta `ad40496` 确认候选 `d3e800b3a4a3f418fc29cc58a258be7bf2cb74cc` 可以合并。已清理隔离测试应用系统注册。

### Step 4 — 2026-11-16 — 扩展宽表格

- 采用独立的表格宽度上限 1120 点，正常宽度的表格保持与正文对齐。WebKit 回归检查覆盖已设为 920 点正文的宽窗和 360 点窄窗，旧版未能展开宽表格。
- 新版本通过同一检查。原生深色窗口确认宽表格展开、小表格保持左对齐、画布颜色覆盖整栏。
