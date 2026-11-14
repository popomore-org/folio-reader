# Folio

> **边界**　包含：本地文件阅读、轻编辑和只读 Git 查看　｜　不包含：工作区托管和 Git 写操作　｜　产出：macOS 预览应用和 folio-core Rust 库　｜　依赖：Meta 共享 CI
> 体系说明见 [popomore-org/meta](https://github.com/popomore-org/meta/blob/main/docs/architecture.md)。

Folio 是本地文件阅读器。打开一个文件或目录，左侧浏览文件，中央阅读，右侧按需打开 Markdown 大纲或 Git 历史。支持 Apple Silicon，最低部署目标 macOS 14。本仓提供源码与本地 ad hoc 预览构建。

## 使用

- 用 `⌘O` 打开文件或目录，也可从 Finder 的「打开方式」打开支持的文件。
- 用 `⌘F` 搜索当前 Markdown、文本、HTML 或表格。用 `⇧⌘F` 切换专注阅读。工具栏的 **Aa** 可以切换主题、字体、字号和阅读宽度。
- 用 `⌘E` 编辑 UTF-8 Markdown 或文本/源码，`⌘S` 保存。切换文件、关窗和退出会询问如何处理未保存内容。检测到磁盘版本已变化时，可从编辑器复制草稿后重新打开文件。
- 打开右栏的 **Git** 查看当前路径的工作区状态、最近提交和补丁。使用 **Reload from Disk** 刷新预览和目录，使用 Git 面板内的刷新按钮重新读取状态。

| 内容 | 支持 |
| --- | --- |
| Markdown | GFM 表格、列表、任务清单、脚注、大纲、相对路径图片和链接 |
| 文本 | UTF-8 文本、常见源码和配置文件，保持段落与缩进 |
| 富文本 | RTF、静态 HTML、PDF；HTML 使用阅读器样式 |
| 图片 | PNG、JPEG、GIF、WebP、HEIC、TIFF、BMP、AVIF 的静态预览，依赖 macOS 解码 |
| 音视频 | MP3、M4A、AAC、WAV、AIFF、CAF、FLAC、MP4、M4V、MOV，由 AVFoundation 解码 |
| 表格 / 图表 | CSV、TSV；Mermaid 与 Vega-Lite 文件及 Markdown 代码块。Vega-Lite 使用内联数据 |

DOCX、EPUB 和 SVG 目前可从未知格式提示打开系统默认应用。目录默认隐藏点文件和符号链接。Git 历史沿第一父提交按当前路径查看，最多 50 笔，扫描上限 3,000 个提交，重命名前的路径不自动追溯。

## 构建与验证

构建需要 Apple Silicon Mac、Xcode 27.2、Rust 1.97.0、Node 26.13.0。使用 `rust-toolchain.toml`、`.node-version` 和两个锁文件。

```sh
scripts/build-macos
open ".build/Folio Preview.app"
cargo fmt --all -- --check
cargo clippy --locked --workspace --all-targets -- -D warnings
cargo test --locked --workspace
cargo test --locked -p folio-core --no-default-features
npm test --prefix renderer
scripts/check-consumer
```

本地预览的 bundle ID 为 `org.popomore.folio.preview`。正式直发的 Developer ID 签名、Hardened Runtime、公证、安装包和自动更新应在建立分发渠道时验收。没有启用自动更新或正式发布渠道。最低系统版本由链接目标声明，目前真机记录覆盖 macOS 27.0.1。

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

保存使用内容版本检查和同目录原子替换，保留 UTF-8 BOM、统一的 CRLF 与文件模式。macOS 上同时保留拥有者、ACL 和扩展属性。进程内保存串行化。外部写入者在最后一次检查与替换之间仍可能写入。文本预览和编辑上限为 8 MiB。本地相对资源仅在选中目录内解析，预览不会主动请求在线资源。

[交互对照、主题和 Meta 设计依据](docs/reader-design.md)
