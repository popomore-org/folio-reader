# Progress

## Current

- Status: 已复现并修复源码预览的多位数行号折行。
- Blockers: 无。
- Next: 推送 PR，打包验签并检查 CI。
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

### Step 3 — 2026-11-16 — 确认候选版本

- AppKit 滚动验证确认原生栏随视口刷新。WebKit 选取测试保留源码、缩进、空行与末尾换行。清理隔离测试应用的系统注册。
- 候选 `e5c6a9c340322903191c4b906df3b8967f551dd2` 的 [Folio CI](https://github.com/popomore-org/folio-reader/actions/runs/43793926645) 通过。Meta `ad40496` 合并检查为 ready。
- 镜像 `/Users/popomore/Downloads/Folio-0.1.1-e5c6a9c-arm64.dmg` 已挂载验签，主应用和扩展均包含行号样式。

### Step 4 — 2026-11-16 — 修复预览的多位数行号

- 旧样式下，WebKit 加载 10 行源码后，第 10 个行号占 26px，单行高度为 13px。源码的 `overflow-wrap: anywhere` 被绝对定位的行号继承，零宽锚点使行号逐字符折行。
- 限制行号保持单行。Quick Look 回归检查实际布局，覆盖 1、10、100 和窄窗中仍会折行的源码。
- 同一测试在旧包失败、新包通过。通过原生界面打开 104 行 Rust 示例，核对了多位数、空行和折行位置。
