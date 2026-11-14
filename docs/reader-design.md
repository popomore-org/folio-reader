# 阅读器交互与主题调研

调研日期 2026-11-15。共同任务是从已有本地项目里打开文件、长读、定位下一段、偶尔修订以及查看版本。本次比较依据官方文档与公开仓库。开源项目的 GitHub 收藏量是采用信号，实际主观阅读口碑与性能未做独立测量。

| 参考 | 在共同任务中的优势 | Folio 的实现 |
| --- | --- | --- |
| Typora | 文件树、大纲和正文整合，Markdown 呈现与编辑紧密衔接。 | 保留文件树与按需大纲。默认阅读，单独进入源文件编辑，以清楚地显示保存边界。[Typora 2.0](https://v2.typora.io/) |
| Obsidian | 阅读视图、文件浏览器和成熟的社区主题入口适合管理长期笔记。 | 浏览普通文件夹，阅读外观直接放在工具栏。无需建立笔记库。[Obsidian 设置](https://obsidian.md/help/settings) · [外观](https://obsidian.md/help/appearance) |
| MarkText | MIT 开源的 Markdown 编辑器，提供 GitHub 风格 Markdown、源码和专注模式。调研时约 6.4 万收藏。 | 沿用明确的源码入口和可收起导航的专注阅读，保留无写入的默认视图。[MarkText](https://github.com/marktext/marktext) |
| Readest / Foliate | 开源电子书阅读器，强调字体、阅读布局与主题。调研时分别约 2.6 万与 8.9 千收藏。 | 将字号、字体、页宽、暖纸色做成即时可调项目。正文使用有中文回退的衬线字体，导航和数据表用系统字体。[Readest](https://github.com/readest/readest) · [Foliate](https://github.com/johnfactotum/foliate) |
| KOReader | 开源长文阅读器，提供字号、行距与对比度等调整。调研时约 3.1 万收藏。 | 保留正文与导航的视觉区分。阅读排版从可调宽度和 1.72 行高开始。[KOReader](https://github.com/koreader/koreader) · [用户指南](https://koreader.rocks/koreader-user-guide.pdf) |
| VS Code | 文件旁可查看变更和时间线，方便理解当前路径的版本。 | 历史放入独立检查器，呈现暂存区、工作树、提交和可复制的补丁。[VS Code Source Control](https://code.visualstudio.com/docs/sourcecontrol/overview) |

界面按 macOS 侧栏、主阅读区和检查器分层。文件名和相对位置显示在标题栏，打开目录后从选文件开始。文档加载、空目录、无法访问、解码失败、外部版本冲突分别反馈。正文主题与系统窗口外观独立，浅色与暖纸服务日间阅读，深色用于低环境亮度。局部控件沿用原生图标并带文字辅助标签。

## 主题互操作

- Typora 的主题属于基于自身 DOM 约定的 CSS，Obsidian 的主题也依赖应用暴露的变量和选择器。可以参考作品的排版参数，套用完整 CSS 时仍依赖目标产品的 DOM。[Typora 主题文档](https://theme.typora.io/doc/) · [Obsidian 外观](https://obsidian.md/help/appearance)
- VS Code 的 JSON 色彩与 TextMate scope 适合借鉴源码配色的语义角色，正文、页面宽度和中文字体仍需单独定义。[VS Code Color Theme](https://code.visualstudio.com/api/extension-guides/color-theme)
- EPUB Reading Systems 建议书籍内容渲染的 CSS 行为。DTCG 2025.10 可作为跨工具交换颜色与排版 token 的格式。调研这些标准后，内置主题使用本仓 CSS 变量，保留颜色角色、字体、字号、行高与栏宽；当前没有跨应用主题导入器。[EPUB Reading Systems 3.3](https://www.w3.org/TR/epub-rs-33/) · [DTCG 格式](https://www.designtokens.org/tr/2025.10/format/)

## 实现边界

- Rust 负责目录边界、文档分类、可展示 HTML、修订校验与只读 Git。SwiftUI 和 AppKit 负责本机窗口、菜单、文件打开、文本编辑、PDFKit 和 AVKit。
- WebKit 从应用包加载 CSS 和图表引擎。Markdown 的作者内联 HTML 按文本处理，独立 HTML 经清理。页面只能载入工作区内允许的图片。Mermaid 使用 strict 模式，Vega-Lite 通过表达式解释器渲染内联数据。[Mermaid](https://mermaid.js.org/config/usage.html) · [Vega-Lite](https://vega.github.io/vega-lite/docs/) · [Vega CSP](https://vega.github.io/vega/usage/interpreter/)
- 以 Meta `a3a966614c0ccd31f4b2255808172390266b1d4f` 的通用、macOS、交互、包和交付规范为基线。预览包与正式分发使用不同验收条件。[Meta](https://github.com/popomore-org/meta/tree/a3a966614c0ccd31f4b2255808172390266b1d4f/docs/standards)
