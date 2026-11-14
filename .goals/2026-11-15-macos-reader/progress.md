# Progress

## Current

- Status: 原生目标 active。本地应用和 Rust 集成已通过主要链路验证。
- Blockers: 暂无。
- Next: 提交应用 PR，验证 CI 与 Meta 仓库接入。
- Branch/PR: feat/macos-reader / Folio #1

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

### Step 3 — 2026-11-15 — 校核远端构建与本地文件元数据

- 首轮远端 Rust 任务通过。Xcode 26.6 的 Swift 编译器在 ReaderWindow IR 生成崩溃。CI 改用 GitHub xcode-27 runner 上的 Xcode 27.2，与本地已验证工具链一致。
- 保留 macOS 文件拥有者、ACL 和扩展属性，真机测试覆盖扩展属性；改用公开 C 头声明桥接 ABI。
- 修复 Git 检查器按钮的原生点击入口。真机核对工作树补丁与提交补丁内容，验证退出编辑提示和丢弃仅影响草稿。

### Step 4 — 2026-11-15 — 解决 Xcode 27 上的 Rust 编译加载故障

- 第二轮远端构建进入 Xcode 27.2 后，Rust 1.97.0 无法加载 zerofrom 过程宏。使用官方 Cargo 和空构建目录在本机复现，动态加载器确认 `mis-aligned LINKEDIT string pool`。
- 明确取消 Rust 过程宏的自动 strip，官方 Cargo 的冷构建通过。打包与外部消费脚本显式调用已固定的官方 Cargo。对应上游 rust-lang/rust#157750。
