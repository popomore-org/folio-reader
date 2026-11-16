# Folio

> **边界**　包含：本地文件阅读、轻编辑和只读 Git 查看　｜　不包含：工作区托管和 Git 写操作　｜　产出：macOS 预览应用和 folio-core Rust 库　｜　依赖：Meta 共享 CI
> 体系说明见 [popomore-org/meta](https://github.com/popomore-org/meta/blob/main/docs/architecture.md)。

Folio 是本地文件阅读器。左侧管理已保存的目录，中央用标签页或左右两栏阅读，右侧按需打开 Markdown 大纲。底栏可进入独立 Git 视图。支持 Apple Silicon，最低部署目标 macOS 14。本仓提供源码与本地 ad hoc 预览构建。

## 使用

- 左侧「Folders」的 **＋** 可一次添加多个目录，目录在重启后保留。右键目录可重新加载、在 Finder 显示或从侧栏移除。
- 用 `⌘O` 打开文件或目录。点击文件创建标签，已打开的文件会切换到现有标签。文件路径行右端的 **Open As** 与右键的 **Open With** 可选择系统列出的应用，也可通过 **Other Application…** 手动选应用。
- 点击底栏的分栏图标或按 `⌘\` 创建分栏。窄窗里的双栏改为上下排列，拖放新分栏的目标也随之移到阅读区底部。拖动分隔线可调整目录树、大纲和分栏尺寸，双击分隔线可恢复默认。将标签拖到标签栏可排序或跨栏移动。合并分栏会把标签收回左栏，保留草稿。
- 切换标签会自动在目录树中定位文件。用 `⇧⌘E` 聚焦目录树，以方向键浏览，按 Return 打开。
- 点击标签下方路径中的文件夹可从弹层浏览目录。点击文件名可查看同目录文件，选择文件即可打开。
- 用 `⌘F` 搜索当前 Markdown、文本、HTML 或表格，`⇧⌘F` 切换专注阅读。在 **Settings**（`⌘,`）中设置全应用外观，以及正文字体、字号和阅读宽度。Markdown 宽表格可超出正文栏，随窗口宽度展开。
- 文件路径右侧可选择阅读、源码或源码与预览。源码与预览模式随可用空间左右或上下排列，并根据当前草稿更新排版。`⌘E` 切换阅读和源码，`⌘S` 保存后留在当前模式。UTF-8 Markdown 和文本/源码支持编辑。切换标签时保留草稿，返回阅读或关闭含草稿的标签或窗口时询问如何处理。
- 底栏显示编辑状态、文件类型、大小及所在分栏。点击 Git 图标查看选中文件所在仓库在已选目录范围内的变更、文件提交历史和完整差异面板，再点击图标返回原标签与分栏。

### Finder 快速查看

将 Folio 放到「应用程序」目录并打开一次。在 Finder 选中支持的文件并按空格，即可预览。扩展以应用名显示，正式版名为 **Folio**。可在「系统设置 → 通用 → 登录项与扩展 → 快速查看」管理。macOS 负责选择相同文件类型的预览提供者。

Folio 为最多 2 MiB 的 UTF-8 文档渲染 Markdown、源码、静态 HTML 和表格。Mermaid 与 Vega-Lite 渲染为 PDF，图表渲染失败时显示源文本。图片、PDF、RTF 和音视频由 macOS 系统预览。快速查看只读，文档中的外部资源和相对图片由完整应用按工作区规则处理。

| 内容 | 支持 |
| --- | --- |
| Markdown | GFM 表格、列表、任务清单、脚注、大纲、相对路径图片和链接 |
| 文本 | UTF-8 文本、常见源码和配置文件，保持段落与缩进 |
| 富文本 | RTF、静态 HTML、PDF；HTML 使用阅读器样式 |
| 图片 | PNG、JPEG、GIF、WebP、HEIC、TIFF、BMP、AVIF、SVG 的静态预览，依赖 macOS 解码 |
| 音视频 | MP3、M4A、AAC、WAV、AIFF、CAF、FLAC、MP4、M4V、MOV，由 AVFoundation 解码 |
| 表格 / 图表 | CSV、TSV；Mermaid 与 Vega-Lite 文件及 Markdown 代码块。Vega-Lite 使用内联数据 |

DOCX 和 EPUB 目前可从未知格式提示打开系统默认应用。目录默认隐藏点文件和符号链接。Git 变更列表显示前 500 个变化并标记截断。Git 历史沿第一父提交按当前路径查看，最多 50 笔，扫描上限 3,000 个提交，重命名前的路径不自动追溯。

直接打开源码文件即可高亮，阅读与编辑共用 [two-face 语法库](https://docs.rs/two-face/latest/two_face/)，按文件后缀或项目文件名识别语言。在 Markdown 代码围栏上指定语言，例如 `rust` 或 `swift`，即可高亮代码块。源码阅读、编辑和 Markdown 代码块按原始文本行显示行号，复制时只复制代码。Finder 快速查看共用阅读样式。

源码编辑参考本机 Zed 的字体、行距和 Catppuccin 配色，优先使用本机 JetBrains Mono。阅读采用 GitHub Primer 排版和语法颜色，新配置默认使用 16 点无衬线字体。两种视图都随外观切换浅色和深色。参考来源见 [阅读器设计](docs/reader-design.md)。

### 自定义主题

在 **Settings → Appearance → Themes** 点 **Open Theme Folder**。Folio 会准备可编辑的 `folio-light.json` 和 `folio-dark.json`。已有的无前缀文件会沿用原内容改名。两种名称同时存在时，Folio 优先读取带前缀的文件。修改后点 **Reload Themes**，当前打开的工作区和 Folio 预览小窗会更新配色。Finder 快速查看使用随应用附带的默认配色。

主题可设置工作区（`workspace`）、源码编辑器（`editor` 和 `editor-syntax`）以及阅读区（`reader` 和 `reader-syntax`）。颜色支持 `#RRGGBB` 和 `#RRGGBBAA`，省略的字段沿用默认值。完整字段见内置的 [folio-light.json](apps/macos/Themes/folio-light.json) 和 [folio-dark.json](apps/macos/Themes/folio-dark.json)。设置会显示无法读取的文件，并保留最后一次有效的配色。删除该外观的自定义文件后重新加载即可恢复默认配色。

## 构建与验证

构建需要 Apple Silicon Mac、Xcode 27.2、Rust 1.97.0、Node 26.13.0。使用 `rust-toolchain.toml`、`.node-version` 和两个锁文件。

```sh
open "$(scripts/build-macos)"
cargo fmt --all -- --check
cargo clippy --locked --workspace --all-targets -- -D warnings
cargo test --locked --workspace
cargo test --locked -p folio-core --no-default-features
npm test --prefix renderer
scripts/check-consumer
```

本地预览使用独立的 `org.popomore.folio.preview` 应用标识。正式构建提供 Sparkle 自动更新，签名、公证和稳定渠道配置见 [macOS 自动更新](docs/macos-updates.md)。最低系统版本为 macOS 14，目前真机记录覆盖 macOS 27.0.1。

## 命令行

Folio 应用包内含 Apple Silicon 版 `folio` 命令，依赖 macOS 14 及以上，无需额外运行时。先将应用放在长期使用的位置，然后运行一次安装命令。

```sh
"/Applications/Folio.app/Contents/Helpers/folio" install
# 源码构建使用 ".build/preview/Folio.app/Contents/Helpers/folio" install
```

安装会将 `~/.local/bin/folio` 链接到应用内的命令。同一位置重复安装会保留当前链接。旧的 Folio 应用包被移除时，可运行上述安装命令修复失效链接。已有其他同名命令或仍可用的其他位置链接时会报错。如果找不到命令，把 `~/.local/bin` 加到 `PATH`。应用原地升级时会一并更新命令。卸载命令时移除该链接即可，工作区数据仍保留。

```sh
folio .                              # 打开当前目录
folio "项目笔记.md" ./资料             # 打开文件和目录
folio preview "项目笔记.md"            # 浮动小窗
folio preview                        # 从 Folio 的文件选择器挑选文件
folio -n ./资料                      # 新建独立进程打开目录
folio --new-instance preview Note.md # 新进程只打开一个预览小窗
folio --help
folio --version
```

`folio` 等同于 `folio open .`。相对路径以终端当前目录为准。文件名以 `-` 开头时，可用 `folio open -- -draft.md`。选用指定应用时，优先级为 `--app`、`FOLIO_APP`、命令所属的应用包、系统登记的正式版和预览版。

默认复用运行中的应用。加 `-n` 或 `--new-instance` 会启动独立进程，目录、标签、分栏和草稿各自维护。新实例沿用启动时的外观配置，之后的改动只在该实例内生效。更新由常规实例处理，安装会等其他实例退出。

打开成功时命令静默退出。退出码 `0` 表示 macOS 已接受打开请求，文件渲染错误显示在应用内。退出码 `1` 表示路径、应用或系统调用出错，`2` 表示参数错误。诊断写入 stderr。

## Finder 快速查看

第一次打开 Folio 主工作区会显示 **Settings → Quick Look**。该页显示当前应用的系统注册和启用状态，可注册扩展、清理同标识的旧注册或前往系统设置。启用 Folio 后，在 Finder 中选中文件并按空格预览。再次打开或从系统设置返回时会重新读取状态。

## 从其他应用快速预览

Raycast 的 **Script Commands** 加入本仓的 `integrations/raycast` 目录，然后搜索 **Preview in Folio**。可以粘贴绝对文件路径，留空则打开系统文件选择器。首次使用前先打开一次 Folio，让 macOS 注册链接。

其他应用可打开 `folio-reader://preview?path=%2FUsers%2Fme%2FNotes%2FReadme.md`。通过 URL 查询参数传入本地绝对路径，编码由调用方的 URL API 处理。开发预览版使用 `folio-reader-preview://preview`。

预览小窗可缩放，沿用 Folio 的阅读外观。按 `Esc` 或 `⌘W` 关闭。需要编辑时从工具栏选 **Open in Folio**，即可在主工作区打开当前文件。

## Rust 集成

宿主依赖 `crates/folio-core`，可用 Cargo 的 `path`，也可在具备仓库读取权限时使用 Git 依赖并锁定 `rev`。默认 `git` feature 使用本地 libgit2。关闭默认 feature 可构建不带 Git 的预览库。应用使用的 `folio-bridge` 属于内部 Swift 适配层。

```rust
use folio_core::Workspace;

let folder = Workspace::open("/path/to/approved/workspace")?;
let entries = folder.list("")?;
let document = folder.read("notes/readme.md")?;
if let Some(preview) = document.preview {
    for heading in preview.headings {
        println!("{}", heading.title);
    }
}
# Ok::<(), folio_core::Error>(())
```

Mokisu 的 Rust 宿主可在允许访问的目录上调用库，再把文件类型、文档预览、大纲和 Git 信息交给自己的 Console 界面。调用是同步的，异步宿主应放到阻塞任务执行器。宿主负责授权根目录，以及 WebView 的脚本、资源和链接策略。图表引擎在 Folio macOS 的 WebKit 展示层，库输出带语言标识的、已转义的代码块。独立消费者示例覆盖启用及禁用 Git 两种构建。Mokisu 自身的界面接线尚未进行。

保存使用内容版本检查和同目录原子替换，保留 UTF-8 BOM、统一的 CRLF 与文件模式。macOS 上同时保留拥有者、ACL 和扩展属性。保存经过进程内串行化，Unix 上的文件锁也会拒绝 Folio 实例之间的并发写入。未使用该文件锁的外部编辑器仍可能在最后一次检查和替换之间写入。文本预览和编辑上限为 8 MiB。本地相对资源仅在选中目录内解析，预览不会主动请求在线资源。

[交互对照、主题和 Meta 设计依据](docs/reader-design.md)
