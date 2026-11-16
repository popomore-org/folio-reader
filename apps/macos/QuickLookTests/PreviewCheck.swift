import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

@main
struct PreviewCheck {
    static func main() async throws {
        let arguments = CommandLine.arguments.dropFirst()
        guard let path = arguments.first,
              let app = Bundle(path: path),
              let resources = Bundle(path: "\(path)/Contents/PlugIns/FolioQuickLook.appex") else {
            throw CoreError(message: "Usage: check-quicklook <app> [--charts]")
        }
        try require(resources.object(forInfoDictionaryKey: "CFBundleName") as? String == app.object(forInfoDictionaryKey: "CFBundleName") as? String,
                    "The Quick Look bundle name must match the application.")
        try require(resources.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == app.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                    "The Quick Look display name must match the application.")
        let extensionInfo = resources.object(forInfoDictionaryKey: "NSExtension") as? [String: Any]
        let attributes = extensionInfo?["NSExtensionAttributes"] as? [String: Any]
        let registered = Set(attributes?["QLSupportedContentTypes"] as? [String] ?? [])
        let imported = app.object(forInfoDictionaryKey: "UTImportedTypeDeclarations") as? [[String: Any]] ?? []

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("folio-quicklook-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let native = "rtf pdf png jpeg jpg gif webp heic tif tiff bmp avif svg mp3 m4a aac wav aiff caf flac mp4 m4v mov"
        let text = "md markdown mdown mkd html htm csv tsv mmd mermaid vl txt text log json jsonl yaml yml xml toml ini conf rs swift c h cpp hpp py js ts jsx tsx go java kt sh zsh sql css scss diff patch"
        let media = Set(native.split(separator: " ").map(String.init))
        let suffixes = (native + " " + text).split(separator: " ").map(String.init)
        for suffix in suffixes {
            let candidates = UTType.types(tag: suffix, tagClass: .filenameExtension, conformingTo: nil)
            let declared = imported.compactMap { declaration -> String? in
                let tags = declaration["UTTypeTagSpecification"] as? [String: Any]
                guard (tags?["public.filename-extension"] as? [String])?.contains(suffix) == true else { return nil }
                return declaration["UTTypeIdentifier"] as? String
            }
            try require(!registered.isDisjoint(with: candidates.map(\.identifier) + declared), "No Quick Look UTI for .\(suffix)")

            let file = root.appendingPathComponent("example.\(suffix)")
            try Data("Folio example\n".utf8).write(to: file)
            switch try PreviewProvider.content(at: file, resources: resources) {
            case .native(let returned):
                try require(media.contains(suffix) && returned == file, "Unexpected system preview for .\(suffix)")
            case .html(let page, _):
                let text = String(decoding: page, as: UTF8.self).replacingOccurrences(
                    of: #"<span class="syntax [a-z-]+">|</span>"#, with: "", options: .regularExpression
                )
                try require(!media.contains(suffix) && text.contains("Folio example"),
                            "Expected readable text for .\(suffix)")
            }
        }

        let markdown = try html("Notes.MDOWN", "\u{FEFF}# 快速查看\n\n- [x] Sample", root: root, resources: resources)
        try require(markdown.contains("<h1 id=") && markdown.contains("快速查看") && !markdown.contains("\u{FEFF}"),
                    "Markdown extensions must have rendered headings with BOM removed.")
        let code = try html("example.swift", "let count = 42", root: root, resources: resources)
        try require(code.contains("<span class=\"syntax syntax-keyword\">let</span>"),
                    "A source document should include highlighted code in Quick Look.")
        let fenced = try html("Code.md", "```swift\nlet count = 42\n```", root: root, resources: resources)
        try require(fenced.contains("language-swift") && fenced.contains("syntax-constant"),
                    "A Markdown code fence should be highlighted in Quick Look.")
        let editorSpans = try Core.sourceHighlights(for: "example.swift", source: "let face = \"😀\"; let count = 42")
        try require(editorSpans.contains { $0.token == .constant && $0.start == 29 && $0.end == 31 },
                    "The native editor should receive color ranges in UTF-16 coordinates.")
        let htmlPage = try html("page.html", "<h1>Safe heading</h1><script>userScript()</script>", root: root, resources: resources)
        try require(htmlPage.contains("Safe heading") && !htmlPage.contains("userScript") && htmlPage.contains("default-src 'none'"),
                    "HTML must be sanitized and use a restrictive policy.")
        let table = try html("cells.tsv", "City\tValue\nShanghai\t42\n", root: root, resources: resources)
        try require(table.contains("<table>") && table.contains("<td>42</td>"), "TSV cells must have a rendered table.")
        let large = root.appendingPathComponent("large.txt")
        try Data(repeating: 0x61, count: 2 * 1024 * 1024 + 1).write(to: large)
        do {
            _ = try PreviewProvider.content(at: large, resources: resources)
            throw CoreError(message: "Oversized text was accepted.")
        } catch let error as CoreError {
            try require(error.message.contains("too large"), error.message)
        }
        let transport = root.appendingPathComponent("video.ts")
        var packets = Data(repeating: 0, count: 188 * 3)
        for index in [0, 188, 376] { packets[index] = 0x47 }
        try packets.write(to: transport)
        guard case .native = try PreviewProvider.content(at: transport, resources: resources) else {
            throw CoreError(message: "A transport stream must use the system viewer.")
        }

        let diagramSamples = [
            ("survey.mmd", "flowchart LR\nA[Field] --> B[Notes]"),
            ("survey.vega-lite.json", #"{"data":{"values":[{"label":"Field","value":3}]},"mark":"bar","encoding":{"x":{"field":"label","type":"nominal"},"y":{"field":"value","type":"quantitative"}}}"#),
            ("survey.vl.json", #"{"data":{"values":[{"x":1}]},"mark":"point","encoding":{"x":{"field":"x","type":"quantitative"}}}"#),
        ]
        for (name, source) in diagramSamples {
            let file = root.appendingPathComponent(name)
            try Data(source.utf8).write(to: file)
            guard case .html(let page, true) = try PreviewProvider.content(at: file, resources: resources) else {
                throw CoreError(message: "Expected chart markup for \(name).")
            }
            if arguments.contains("--charts") {
                _ = NSApplication.shared
                let data = try await ChartPreview.render(page, resources: resources)
                try require(PDFDocument(data: data)?.pageCount == 1, "Expected a chart PDF for \(name).")
            }
        }
        print("Verified \(suffixes.count) suffixes, Quick Look bundle names, preview routing and text rendering.")
    }

    private static func html(_ name: String, _ source: String, root: URL, resources: Bundle) throws -> String {
        let file = root.appendingPathComponent(name)
        try Data(source.utf8).write(to: file)
        guard case .html(let page, _) = try PreviewProvider.content(at: file, resources: resources) else {
            throw CoreError(message: "Expected HTML for \(name).")
        }
        return String(decoding: page, as: UTF8.self)
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw CoreError(message: message) }
    }
}
