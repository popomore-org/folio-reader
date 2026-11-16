# Progress

## Current

- Status: 深浅外观、原生保存和 Quick Look 已验证，准备验证候选版本。
- Blockers: 无。
- Next: 推送 PR，打包验签并检查 CI。
- Branch/PR: fix/folio-release-toolchain / Folio #5。

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 样式参考 | 本机 Zed 与 GitHub Primer 的样式有明确依据 | complete |
| 原生验收 | 编辑与阅读界面在深浅外观下正确显示 | complete |
| 交付 | 更新 PR 并验证候选安装镜像 | in progress |

## Steps

### Step 1 — 2026-11-16 — 核对参考和实现

- 本机 Zed 1.28.1 配置为 Catppuccin Macchiato 和 15 点 JetBrains Mono Nerd Font。Folio 用同系列 Latte 作为浅色参考，加深浅色小字号颜色。本机字体缺失时回退为系统等宽字体。
- 阅读采用 GitHub Primer Markdown 和 Prettylights 颜色。阅读、分栏和 Quick Look 共用 CSS。保留现有阅读设置。

### Step 2 — 2026-11-16 — 原生验收

- 隔离的 Folio 用 Markdown 示例核对了深浅外观下的 Zed 编辑区、GitHub 预览区、折行行号和当前行高亮。通过设置切换外观后，正文为默认 16 点无衬线。
- 在分栏插入空行并保存，核对磁盘内容，保存后仍在编辑分栏。Quick Look 验证 79 个后缀、配色资源和图表，渲染器测试通过。
