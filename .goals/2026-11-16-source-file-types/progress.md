# Progress

## Current

- Status: 原生文件和扩展验证完成，准备交付本地安装包和 PR。
- Blockers: 无。
- Next: 验收当前 PR 的 CI、Meta 合并检查及本地镜像。
- Branch/PR: fix/folio-release-toolchain / Folio #5。

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 文件识别 | 语法库可识别的文件进入源码阅读和编辑 | complete |
| 扩展 | 常用源码在 Folio 的 Quick Look 内容入口着色 | complete |
| 交付 | 原生打开、镜像、CI 和 Meta 检查通过 | active |

## Steps

### Step 1 — 2026-11-16 — 核对语法能力与文件层

- 实查已锁定 two-face（Syntect）对 Lua、Ruby、C#、Vue、Zig 等的后缀匹配。代码配色已经存在，文件分类的固定列表使这些源码无法进入渲染入口。

### Step 2 — 2026-11-16 — 验证源码入口

- Rust 测试覆盖多种新增后缀、按项目文件名识别、通过工作区直接打开并获取编辑版本，以及专门预览与归档类型的路由。标准 workspace 和无 Git 特性检查通过。
- macOS 应用直接打开 Lua 和 Vue，阅读与分栏中的标记、字符串和 TypeScript 关键字着色。Quick Look 检查覆盖 79 个后缀，Lua 有独立的高亮断言。
- 隔离验证后移除测试系统注册。
