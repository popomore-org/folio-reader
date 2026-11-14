# Progress

## Current

- Status: 已实现 Sparkle 自动更新及 Meta 标签发布流程。已在 Apple Silicon 真机验证隔离版 0.1.0 到 0.1.1 的手动及自动升级、草稿保护和签名失败。
- Blockers: Meta 默认分支尚未登记 Folio。正式更新待批准分发仓库、配置 Apple 签名和公证凭据及稳定更新密钥。
- Next: Meta 登记合并后从可信默认分支复核 Folio。配置获批准的渠道后验收实际公证包及 HTTPS 更新。
- Branch/PR: feat/macos-reader / Folio #1，Meta #54

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 产品研究 | 同场景对照连接到界面决策和主题合同 | complete |
| 核心与界面 | 本地文件、图表、媒体、编辑和 Git 通过真实入口 | complete |
| 验证 | 外部 Cargo 消费、自动检查和实际应用验证 | complete |
| 界面增补 | 用户新增交互在隔离原生实例中验收 | complete |
| Zed 交互与视觉 | 浅色和深色布局、目录与分栏、Git 在原生窗口可用 | complete |
| 自动更新 | 本地真实升级及失败路径，正式分发与安装独立验收 | in progress |
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

### Step 11 — 2026-11-15 — Zed 版应用与候选检查通过

- Folio #1 head 699ae1b5e37b7067233b72a39fd49a5f9b9ce9ee，CI 43633222979 成功。最终本地预览复验 Git 列、补丁及返回 Markdown 图表。
- Meta #54 head cec18e1aeee7b11fc771ae22fc5697eb66133e55，锁定新版 Folio。212 个本地测试和远端 43633245805、43633245880 均通过。Folio 的候选只读检查为 ready。
- 进度仅保留本地，避免改变 Meta 固定的 Folio 提交。未授权合并，正式入口仍等待仓库登记。


### Step 12 — 2026-11-15 — 按 Meta 规范补充 macOS 自动更新

- 内置 Sparkle，首次询问、24 小时检查、手动检查和下载及安装独立开关。草稿、打开面板与原生媒体播放阻止更新重启。
- Apple Silicon、macOS 27.0.1 真机从独立 bundle 0.1.0 检查签名 appcast、下载和验证 0.1.1、替换应用并重启。重启后手动检查显示已是最新版本，原目录和 Markdown 正常读取。
- 发布入口使用 Meta 发布计划及草稿资产适配器。开发者签名与公证流程、签名更新归档及稳定渠道回读已实现。公开下载仓库和发布凭据尚未配置，未验证正式分发。


### Step 13 — 2026-11-15 — 自动升级与失败路径验收

- 让测试环境的上次检查时间逾期后启动。后台自动下载，关闭自动安装时仍保持 0.1.0。开启空闲安装后等候 10 秒，自动替换并重启为 0.1.1，三个设置均保留。
- 打开未保存的 Markdown 草稿时，手动安装与开启空闲安装均保持原进程；存盘后验证测试文字保留。独立的手动升级保留了目录和文件。
- 分别修改测试源 appcast 的文字和归档的一个字节，验证客户端拒绝并提供重试。关闭测试更新源后，现有版本正常运行，检查失败显示在设置页。
- Folio Rust 默认与无 Git feature、外部消费者、渲染器测试、预览编译、actionlint 和 shellcheck 通过。Meta 的本机 Cargo 缓存测试在未改动的 main 同样失败。Folio #1 当前 head 7d95f9b 的 CI 43635950153 成功，Meta #54 当前 head 479e416 的 CI 43635982378 和候选 43635982392 成功。Meta #54 的可信只读检查及 Folio #1 的候选只读检查均为 ready。

### Step 14 — 2026-11-15 — 统一窗口和正文外观

- 按反馈移除独立 Theme 选择与暖纸配色。设置中的系统、浅色、深色同时作用于窗口和阅读页，正文复用原生阅读窗格底色。
- 在 Apple Silicon 真机以残留的 Paper 偏好启动隔离预览，确认设置只保留一处外观选择。实际从浅色切换深色，已打开的 Markdown、表格、Mermaid 和 Vega-Lite 同步变化，右侧纯文本窗格同样显示深色。
- macOS 预览构建、渲染器测试与 diff 检查通过。


### Step 15 — 2026-11-15 — 从 Raycast 唤起快速预览

- 增加独立浮动窗口与本地文件 URL 入口。普通 Finder 打开仍进入工作区。开发预览、更新 QA 与正式包使用独立 URL scheme。小窗可选文件、浏览同目录相对文档链接、按 Esc 或 ⌘W 退出，或将文档交给主工作区。
- 真机验证带中文、空格及保留字符的路径，冷启动仅显示小窗，保留现有工作区的标签和目录，验证文件选择器及打开主工作区。已在本机 Raycast 2.12.1 加入脚本目录，从搜索直接打开带中文路径的 Markdown。
- macOS 预览包构建、渲染器测试、ShellCheck 与 diff 检查通过。
