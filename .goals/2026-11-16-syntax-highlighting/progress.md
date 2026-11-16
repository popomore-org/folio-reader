# Progress

## Current

- Status: Rust 和原生验证通过，准备提交与制作安装包。
- Blockers: 无。
- Next: 发布候选到 PR 并验收当前 CI 与本地安装包。
- Branch/PR: fix/folio-release-toolchain / Folio #5。
- Runtime/Follow-up: 当前没有原生目标。按本轮交付执行。

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 语法解析 | 源码和 Markdown 输出安全、正确的颜色标记 | complete |
| macOS | 阅读、编辑、分栏和 Quick Look 使用相同颜色类别 | complete |
| PR | 当前 CI、Meta 检查及签名预览镜像通过 | active |

## Steps

### Step 1 — 2026-11-16 — 复用 Rust 渲染边界

- 选用 two-face 自带的语法库及纯 Rust 正则实现。源码和代码块离线解析，颜色偏好由原生与 WebKit 分别呈现。

### Step 2 — 2026-11-16 — 验证核心及原生交互

- Rust 全 workspace、无 Git 特性和外部 Cargo 消费样例通过。回归覆盖多种语言、安全转义、图表及未知语言回退和 UTF-16 偏移。
- macOS 隔离应用验证浅色源码阅读、深色分栏和 Markdown 代码块。编辑保存后仍是分栏，样例文件只包含预期的纯文本。
- Quick Look 内容及图表检查通过。测试包系统注册已清理。
