# Progress

## Current

- Status: 主题加载与原生交互通过本地验证，等待候选镜像和 CI。
- Blockers: 无。
- Next: 构建镜像并核对当前 PR 提交的 CI 和 Meta 检查。
- Branch/PR: fix/folio-release-toolchain / Folio #5。

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 主题文件 | 浅色和深色 JSON 覆盖工作区、源码和阅读配色 | complete |
| 设置与验证 | 设置可初始化并重载，浅色和深色分别在原生界面验证 | complete |
| 本地镜像及 PR | 镜像含主题资源，PR 最新提交通过 CI 和 Meta 检查 | in progress |

## Steps

### Step 1 — 2026-11-16 — 主题加载和设置

- 使用两个内置 JSON 保存默认主题。自定义文件按颜色覆盖，校验失败保留最后有效配色。Finder 快速查看使用随包的主题。
- 设置提供主题目录和重载。隔离的 Folio 原生窗口验证了首次生成两份 JSON、部分覆盖、深浅切换，以及同窗口更新目录树、编辑区与预览和代码颜色。

### Step 2 — 2026-11-16 — 回归验证

- Quick Look 检查通过 79 个后缀、图表、两份内置主题、文件初始化与幂等、错误回退和恢复默认。Rust 测试和 Clippy、渲染器测试通过。清理隔离应用的系统注册。
