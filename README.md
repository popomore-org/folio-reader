# Folio

Folio is an open-source macOS reader for local project files. Browse saved folders, read documents side by side, and make small edits without leaving the workspace. The Rust core can also be embedded in other applications.

## Highlights

- **Read local files.** Preview Markdown, text, static HTML, RTF, PDF, images, audio, and video. View CSV and TSV as tables and render Mermaid or Vega-Lite diagrams.
- **Keep related files together.** Save multiple folders, open tabs and split panes, jump to Markdown headings, and inspect Git history and diffs.
- **Customize reading.** Choose a light or dark appearance and edit the JSON palettes in **Settings → Appearance → Themes**.
- **Edit in place.** Switch between reading, source, and source with live preview. Use Command-S to save.
- **Preview from Finder or Raycast.** Press Space in Finder for Quick Look, or use the bundled CLI to open a floating Folio preview.

## Install

Folio builds for Apple Silicon and requires macOS 14 or later. Download a build from [GitHub Releases](https://github.com/popomore-org/folio-reader/releases), open the DMG, and drag the app to Applications. Releases marked **Pre-release** are preview builds.

Open Folio once to register its Finder extension. Manage it under **System Settings → General → Login Items & Extensions → Quick Look**. macOS chooses the provider when multiple apps support the same file type.

## Themes

In **Settings → Appearance → Themes**, choose **Open Theme Folder** to find
[folio-light.json](apps/macos/Themes/folio-light.json) and
[folio-dark.json](apps/macos/Themes/folio-dark.json). Edit either file and choose
**Reload Themes**. Omitted colors inherit the defaults. Finder Quick Look uses
the bundled colors.

## Command line

Once Folio is in Applications, install the bundled command into `~/.local/bin`. For the original preview, replace `Folio.app` in the path with `Folio Preview.app`.

```sh
/Applications/Folio.app/Contents/Helpers/folio install
```

Add that directory to `PATH` if needed.

```sh
folio .                        # Open the current folder
folio "Project Notes.md"       # Open a file in the workspace
folio preview "Project Notes.md"
folio --new-instance .
folio --help
```

To use Raycast, add [integrations/raycast](integrations/raycast) to its Script Commands and run **Preview in Folio**.

## Build from source

Use an Apple Silicon Mac with Xcode 27.2 and the Rust and Node toolchains pinned in the repository.

```sh
app="$(scripts/build-macos)"
open "$app"
cargo fmt --all -- --check
cargo clippy --locked --workspace --all-targets -- -D warnings
cargo test --locked --workspace
cargo test --locked -p folio-core --no-default-features
npm test --prefix renderer
scripts/check-consumer
scripts/check-quicklook "$app"
```

## Embed the Rust core

Use [folio-core](crates/folio-core) as a Cargo `path` or `git` dependency. The default `git` feature adds local read-only history and change inspection. Set `default-features = false` to use document and workspace APIs without Git support.

```rust
use folio_core::Workspace;

let folder = Workspace::open("/path/to/workspace")?;
let document = folder.read("notes/readme.md")?;
if let Some(preview) = document.preview {
    for heading in preview.headings {
        println!("{}", heading.title);
    }
}
# Ok::<(), folio_core::Error>(())
```

The caller grants access to a workspace and decides how to present its files. The macOS app supplies its own renderer and chart engines.

## Contribute

Open an [issue](https://github.com/popomore-org/folio-reader/issues) for a bug or feature request. Include your macOS version, Folio version, and a sample file you can share when the issue depends on specific file content. Send changes through pull requests. Use English for commit messages and pull request titles and descriptions. [Contributor instructions](AGENTS.md)

[Reader design and references (中文)](docs/reader-design.md) · [macOS release and update guide](docs/macos-updates.md)

## License

Folio is released under the [MIT License](LICENSE). Third-party dependencies and bundled assets retain their respective licenses.
