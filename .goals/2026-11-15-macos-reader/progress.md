# Progress

## Current

- Status: 原生目标 active。本地应用和 Rust 集成已通过主要链路验证。
- Blockers: 暂无。
- Next: 提交应用 PR，验证 CI 与 Meta 仓库接入。
- Branch/PR: feat/macos-reader

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 产品研究 | 同场景对照连接到界面决策和主题合同 | complete |
| 核心与界面 | 本地文件、图表、媒体、编辑和 Git 通过真实入口 | complete |
| 验证 | 外部 Cargo 消费、自动检查和实际应用验证 | active |
| PR | 当前提交满足 Meta 合并检查 | active |

## Steps

### Step 1 — 2026-11-15 — 建立交付目标

- 读取 Meta 标准和 Mokisu 桌面入口，观察原生目标 active。
- 独立 Rust 库与原生应用分工，Folio 为暂定名。

### Step 2 — 2026-11-15 — 完成主要实现与真机验证

- 文档对照 Typora、Obsidian、MarkText、Readest、Foliate、KOReader 和 VS Code，记录 CSS、TextMate、DTCG 与 EPUB 的适用层。
- 构建 ad hoc arm64 应用。macOS 27.0.1 真机确认中文 GFM、相对链接与图片、Mermaid、Vega-Lite、HTML、CSV、RTF、MP4/M4A 解码、保存往返和 Git 工作树及提交补丁。
- 退出编辑可取消、保存或丢弃。Rust 测试覆盖外部文件修改、CRLF/BOM、目录权限边界与 Git 暂存/未暂存补丁。外部 Cargo 样例通过两种 feature 组合。
