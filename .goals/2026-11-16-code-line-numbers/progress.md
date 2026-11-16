# Progress

## Current

- Status: 已实现，原生验收通过，准备验证候选版本。
- Blockers: 无。
- Next: 推送 PR，打包并检查镜像。
- Branch/PR: fix/folio-release-toolchain / Folio #5。

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 阅读与编辑 | 逻辑行显示行号，复制保留原文 | complete |
| 验收交付 | 原生和扩展验证通过，PR 检查通过并提供本地镜像 | in progress |

## Steps

### Step 1 — 2026-11-16 — 确定展示方式

- 原生编辑器使用独立栏，WebKit 阅读和 Quick Look 使用 CSS 计数。未开启新的原生目标。

### Step 2 — 2026-11-16 — 验证渲染与编辑

- workspace、禁用 Git 特性的 Rust 测试和 Clippy 通过。Quick Look 测试通过 79 个后缀的内容入口和图表渲染。
- 原生隔离应用中通过 Markdown 查看每个块独立计数，并验证 Swift 源码分栏的空行、折行及新增行。原生栏绘制显式限制为自身边界，避免盖住正文和标签栏。
- 单个 HTML 预览最多生成 20,000 个行号标记以限制渲染开销，超出预算的代码块保留文本和可用着色。
