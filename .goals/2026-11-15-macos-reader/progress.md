# Progress

## Current

- Status: 已按 Zed 调整导航、标签、分栏和 Git。真机完成键盘目录、自动定位、暖纸与深色工作区组合验证。
- Blockers: Meta 默认分支尚未登记 Folio，可信默认分支合并入口暂不能识别该仓库。
- Next: 对新版候选重跑双 PR 检查。Meta #54 进入 main 后从可信默认分支再核对 Folio #1。
- Branch/PR: feat/macos-reader / Folio #1，Meta #54

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 产品研究 | 同场景对照连接到界面决策和主题合同 | complete |
| 核心与界面 | 本地文件、图表、媒体、编辑和 Git 通过真实入口 | complete |
| 验证 | 外部 Cargo 消费、自动检查和实际应用验证 | complete |
| 界面增补 | 用户新增交互在隔离原生实例中验收 | complete |
| Zed 交互与视觉 | 浅色和深色布局、目录与分栏、Git 在原生窗口可用 | complete |
| PR | 当前提交满足 Meta 默认分支合并检查 | pending |

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

### Step 5 — 2026-11-15 — 双 PR 检查完成，默认分支登记待合并

- Folio #1，head b6d81a72315703fdd0399fb885a16518559007c4。Linux Rust、macOS 构建与应用门禁均成功（run 43627891886）。
- Meta #54，head 6f246919b74671ff55956bae67f36c6ceecab231。Meta 全量 212 个测试通过，两个远端 workflow 完成。可信 Meta main 的只读入口对 #54 返回 ready。
- 在 Meta #54 候选 checkout 对 Folio #1 只读检查返回 ready，当前可信 Meta main 则返回 Unknown merge-gate repository。合并权限未请求执行，无需定时观察已结束的 CI。
- 最终本地应用复验 PDFKit、图表、专注阅读与暖纸主题。当前本地进度补记保留于工作区，避免改变首次 CI 已固定的 Folio head。

### Step 6 — 2026-11-15 — 补验原生冲突恢复和文件打开面板

- 用当前 ad hoc 应用对独立测试 Markdown 制造真实外部更新。⌘S 显示磁盘版本冲突，提示关闭后草稿仍可编辑，取消关窗也保留草稿。丢弃测试草稿并用 ⌘R 后，预览读到磁盘外部更新，文件内容仍为外部版本。
- ⌘O 的系统打开面板实际选择一个目录，从侧栏打开 Markdown。⌘F 输入文本后，WebKit 选中了正文中的匹配项。
- 回读两个 PR 的 head 与检查未变化，Meta #54 在可信 main 入口仍为 ready。Folio #1 在候选登记中的检查仍为 ready，默认分支登记等待合并授权。

### Step 7 — 2026-11-15 — 验证 Rust 库的远端 Git 依赖

- 在 Folio 工作区之外建立独立 Cargo 项目，从私有 GitHub 仓库按完整 rev b6d81a72315703fdd0399fb885a16518559007c4 拉取 folio-core。启用和禁用 git 的两次实际运行均成功，锁文件记录远端 Git 来源。验证目录列表、Markdown 打开和公开保存入口。
- 回读 Meta main 仍为 a3a9666，Folio 的合并入口仍返回 Unknown merge-gate repository。Meta #54 为 open，可信 main 的只读检查仍为 ready。

### Step 8 — 2026-11-15 — 实现多目录工作区与独立 Git 视图

- 通过原生打开面板添加 Atlas 和 Fieldnotes，重启后两目录仍在。设置页的 Paper 配置跨重启保留。
- 工作区真机验证跨目录的左右阅读、标签切换、草稿保留与保存。右键 Open With 选择 TextEdit，验证系统应用打开指定文件。点击左栏正文后底栏标识更新为 Left Pane。
- 底栏打开 Git，验证文件变更、删除补丁和文件提交补丁。新增 Rust 回归覆盖目录范围与已删除文件，旧预览 API 保持可用。

### Step 9 — 2026-11-15 — 新版 PR 检查完成

- Folio #1 head ae48e2e9831553b7cc4dd210fb8d427739ce1576，Rust、macOS 和 CI gate 全部通过（run 43631371634）。
- Meta #54 head f903c0a2c50303d6cce94a102541945435f27860，锁定 Folio 新版候选。212 个本地测试及两个远端 workflow 通过（43631407902 / 43631407865）。
- 根据更新的 Meta 候选清单，Folio #1 的只读检查为 ready。已保存本地 arm64 预览包。当次进度记录保留在本地，避免改变 Meta 已固定的 Folio 提交。

### Step 10 — 2026-11-15 — 实装 Zed 交互与视觉参考

- 参考本机 Zed 1.28.1，以冷蓝灰、细分隔线和局部选中状态统一目录、标签、路径行及底栏。工作区外观与阅读主题可分别设置。
- Apple Silicon / macOS 27.0.1 的独立 QA 窗口验证双栏、深色工作区配暖纸、从底栏进入 Git、历史各列和提交补丁。
- 已验证 ⇧⌘E、方向键定位和折叠深层目录，切换离开后再选中标签会自动展开并选中目标文件。
