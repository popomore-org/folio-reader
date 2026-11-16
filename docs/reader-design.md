# 阅读器交互与主题调研

调研日期 2026-11-15。共同任务是从已有本地项目里打开文件、长读、定位下一段、偶尔修订以及查看版本。本次比较依据官方文档与公开仓库。开源项目的 GitHub 收藏量是采用信号，实际主观阅读口碑与性能未做独立测量。

| 参考 | 在共同任务中的优势 | Folio 的实现 |
| --- | --- | --- |
| Typora | 文件树、大纲和正文整合，Markdown 呈现与编辑紧密衔接。 | 保留文件树与按需大纲。默认阅读，单独进入源文件编辑，以清楚地显示保存边界。[Typora 2.0](https://v2.typora.io/) |
| Obsidian | 阅读视图、文件浏览器和成熟的社区主题入口适合管理长期笔记。 | 浏览普通文件夹，阅读外观集中于 Settings。无需建立笔记库。[Obsidian 设置](https://obsidian.md/help/settings) · [外观](https://obsidian.md/help/appearance) |
| MarkText | MIT 开源的 Markdown 编辑器，提供 GitHub 风格 Markdown、源码和专注模式。调研时约 6.4 万收藏。 | 沿用明确的源码入口和可收起导航的专注阅读，保留无写入的默认视图。[MarkText](https://github.com/marktext/marktext) |
| Readest / Foliate | 开源电子书阅读器，强调字体、阅读布局与主题。调研时分别约 2.6 万与 8.9 千收藏。 | 字号、字体、页宽即时可调。正文使用有中文回退的衬线字体，导航和数据表用系统字体。[Readest](https://github.com/readest/readest) · [Foliate](https://github.com/johnfactotum/foliate) |
| KOReader | 开源长文阅读器，提供字号、行距与对比度等调整。调研时约 3.1 万收藏。 | 保留正文与导航的视觉区分。阅读排版从可调宽度和 1.72 行高开始。[KOReader](https://github.com/koreader/koreader) · [用户指南](https://koreader.rocks/koreader-user-guide.pdf) |
| VS Code | 文件旁可查看变更和时间线，方便理解当前路径的版本。 | 文件按标签和两栏组织，底栏进入独立 Git 视图，工作区变更和文件历史各有列表，旁边显示可复制的补丁。[VS Code Source Control](https://code.visualstudio.com/docs/sourcecontrol/overview) |

界面按 macOS 侧栏、主阅读区和大纲分层。侧栏、标题栏与状态栏复用系统窗口底色，文件类型以单色图形区分。文件名和相对位置显示在标题栏，打开目录后从选文件开始。文档加载、空目录、无法访问、解码失败、外部版本冲突分别反馈。正文随窗口外观切换浅色和深色。局部控件沿用原生图标并带文字辅助标签。

## 本机 Zed 界面参考

2026-11-15 在本机 Zed 1.28.1 查看 Git 工作区。窗口顶部有紧凑的路径和标签行，底部一条窄状态栏承载面板入口。Git 的变更列表与提交时间线使用相近的背景和细边界，变更色集中于增删数量、状态图标和提交关系。以下将本机观察和官方文档与 Folio 的实现对照。

| 场景 | Zed 参考 | Folio 的做法 |
| --- | --- | --- |
| 找到当前文件 | Project Panel 切换文件时自动定位对应条目，目录展开可用方向键。[Zed Project Panel](https://zed.dev/docs/project-panel) | 在左右栏切换标签时展开对应父目录并滚到文件行，⇧⌘E 将键盘焦点移到目录树，方向键用于移动和展开，Return 打开文件。 |
| 对照两份文件 | 顶部标签和面板边界使活动区域容易辨认，分栏操作靠近标签。[Zed Splitting Panes](https://zed.dev/features#splitting-panes) | 每栏各自显示紧凑的标签，活动栏用轻量标记。保留阅读区的页宽和行距。 |
| 浏览 Git | 底栏打开 Git，变更、历史和详情共享导航位置。提交行可以同时呈现摘要、作者、时间和短 SHA。[Zed Git](https://zed.dev/docs/git) | 用一行底栏作为入口，独立视图保留足够的差异宽度。提交历史使用摘要、作者、日期和短 SHA 的列布局，下方展示补丁。窄窗口缩减列宽需求。 |
| 视觉层级 | 导航、标签和底栏使用相近背景，以细分隔线区分区域。强调色集中于选中状态和 Git 增删。 | 统一导航表面，在当前文件、活动栏和差异状态使用强调色。 |

## 编辑与渲染样式

- 本机 Zed 1.28.1 使用 15 点 JetBrains Mono Nerd Font 和 Catppuccin Macchiato。Folio 在深色编辑器沿用该配色，浅色采用 Latte 并加深小字号文字的颜色。编辑器用 24 点行高、等宽行号和当前行高亮。本机缺少 JetBrains Mono 时使用系统等宽字体。[Zed 编辑器设置](https://zed.dev/docs/reference/all-settings#buffer-line-height) · [Catppuccin for Zed](https://github.com/catppuccin/zed/blob/main/themes/catppuccin-mauve.json)
- 阅读与 Finder 快速查看采用 GitHub Primer 的标题、段落、表格、引用、代码块和 Prettylights 颜色。默认正文为 16 点系统无衬线，1.5 倍行高。主应用可继续使用已保存的字体、字号和宽度。[Primer Markdown](https://github.com/primer/css/tree/main/src/markdown) · [Primer 语法颜色](https://github.com/primer/primitives/blob/main/src/tokens/functional/color/syntax.json5)

## 文件图标与两栏

VS Code 的文件图标主题将文件名、扩展名和语言 ID 映射到图标，编辑器分栏各自维护标签。Material Icon Theme 有 MIT 许可、文件名和扩展名映射及灰度选项；引入整套主题会增加素材和更新维护。本版沿用其匹配顺序的思路，按典型文件名、扩展名和预览类别映射到系统 SF Symbols。图标使用同一色调，选中状态通过行背景区分。[VS Code 界面](https://code.visualstudio.com/docs/editing/getting-started/userinterface) · [File Icon Theme](https://code.visualstudio.com/api/extension-guides/file-icon-theme) · [Material Icon Theme](https://github.com/material-extensions/vscode-material-icon-theme)

底栏目录树入口参考 Zed 的分支和实心节点，使用 Folio 自己的 SVG。图标随浅色、深色外观着色，按钮提供悬停提示和 VoiceOver 名称。[Zed 目录树图标](https://github.com/zed-industries/zed/blob/v1.28.1/assets/icons/file_tree.svg)

底栏大纲和文件行的 Open As 分别使用 Lucide 的 `list-tree` 与 `external-link`。Open As 由系统菜单提供下拉指示和应用图标。[Lucide 图标许可](https://lucide.dev/license)

## 主题互操作

- Typora 的主题属于基于自身 DOM 约定的 CSS，Obsidian 的主题也依赖应用暴露的变量和选择器。可以参考作品的排版参数，套用完整 CSS 时仍依赖目标产品的 DOM。[Typora 主题文档](https://theme.typora.io/doc/) · [Obsidian 外观](https://obsidian.md/help/appearance)
- VS Code 的 JSON 色彩与 TextMate scope 适合借鉴源码配色的语义角色，正文、页面宽度和中文字体仍需单独定义。[VS Code Color Theme](https://code.visualstudio.com/api/extension-guides/color-theme)
- EPUB Reading Systems 建议书籍内容渲染的 CSS 行为。DTCG 2025.10 可作为跨工具交换颜色与排版 token 的格式。Folio 的浅色和深色 JSON 按工作区、编辑区和阅读区定义颜色，阅读区将颜色映射到 CSS 变量。字体、字号和栏宽沿用阅读设置。[EPUB Reading Systems 3.3](https://www.w3.org/TR/epub-rs-33/) · [DTCG 格式](https://www.designtokens.org/tr/2025.10/format/)

## 实现边界

- Rust 负责目录边界、文档分类、可展示 HTML、修订校验与只读 Git。SwiftUI 和 AppKit 负责本机窗口、菜单、文件打开、文本编辑、PDFKit 和 AVKit。
- WebKit 从应用包加载 CSS 和图表引擎。Markdown 的作者内联 HTML 按文本处理，独立 HTML 经清理。页面只能载入工作区内允许的图片。Mermaid 使用 strict 模式，Vega-Lite 通过表达式解释器渲染内联数据。[Mermaid](https://mermaid.js.org/config/usage.html) · [Vega-Lite](https://vega.github.io/vega-lite/docs/) · [Vega CSP](https://vega.github.io/vega/usage/interpreter/)
- 以 Meta `a3a966614c0ccd31f4b2255808172390266b1d4f` 的通用、macOS、交互、包和交付规范为基线。预览包与正式分发使用不同验收条件。[Meta](https://github.com/popomore-org/meta/tree/a3a966614c0ccd31f4b2255808172390266b1d4f/docs/standards)
