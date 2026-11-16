use folio_core::{SyntaxToken, highlight_source, render_markdown, render_text_preview};
use std::path::Path;

#[test]
fn source_preview_recognizes_common_languages_by_filename() {
    let samples = [
        ("Example.SWIFT", "let sample: Int = 42\n"),
        ("script.ts", "const sample: number = 42;\n"),
        (
            "component.tsx",
            "export const element = <div>Hello</div>;\n",
        ),
        ("example.rs", "fn main() { let sample = 42; }\n"),
        ("settings.toml", "sample = 42\n"),
        ("main.py", "def sample():\n    return 42\n"),
        ("config.json", "{\"sample\": 42}\n"),
        ("Makefile", "SHELL := /bin/sh\n"),
        ("Dockerfile", "FROM scratch\n"),
    ];
    for (name, source) in samples {
        let preview = render_text_preview(Path::new(name), source)
            .unwrap()
            .unwrap();
        assert!(
            preview.html.contains("class=\"syntax "),
            "{name}: {}",
            preview.html
        );
    }
}

#[test]
fn fenced_code_is_highlighted_without_interpreting_source_or_diagrams() {
    let preview = render_markdown(
        "# Example\n\n```rust info\nlet source = \"<script>&value</script>\";\n```\n\n\
         ```unknown-language\nlet source = 42;\n```\n\n\
         ```mermaid\nflowchart LR\nA-->B\n```\n\n    let plain = 42;\n",
    );
    let html = preview.html;
    assert!(html.contains("language-rust"));
    assert!(html.contains("<span class=\"syntax syntax-keyword\">let</span>"));
    assert!(html.contains("&lt;script&gt;&amp;value&lt;/script&gt;"));
    assert!(!html.contains("<script>"));
    assert!(html.contains("<code class=\"language-unknown-language\">let source = 42;"));
    assert!(html.contains("<code class=\"language-mermaid\">flowchart LR"));
    assert!(html.contains("<code>let plain = 42;"));
    assert_eq!(preview.headings[0].title, "Example");
}

#[test]
fn source_colors_use_utf16_offsets_and_keep_large_or_plain_buffers_readable() {
    let source = "let label = \"😀\"; let count = 42;\n";
    let spans = highlight_source(Path::new("demo.rs"), source);
    let start = source[..source.find("42").unwrap()].encode_utf16().count();
    assert!(spans.iter().any(|span| {
        span.token == SyntaxToken::Constant && span.start == start && span.end == start + 2
    }));
    assert!(highlight_source(Path::new("readme.txt"), source).is_empty());

    let large = "x".repeat(9_000);
    assert!(highlight_source(Path::new("demo.rs"), &large).is_empty());
    let preview = render_text_preview(Path::new("demo.rs"), &large)
        .unwrap()
        .unwrap();
    assert_eq!(preview.html, format!("<pre class=\"plain\">{large}</pre>"));
}
