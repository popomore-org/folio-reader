import Foundation
import QuickLookUI
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let file = request.fileURL
        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 800, height: 680)) { _ in
            try Self.markdownPage(at: file)
        }
    }

    static func markdownPage(at file: URL) throws -> Data {
        let scoped = file.startAccessingSecurityScopedResource()
        defer { if scoped { file.stopAccessingSecurityScopedResource() } }

        let maxBytes = 2 * 1024 * 1024
        guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw CoreError(message: "Choose a Markdown file to preview.")
        }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let bytes = try handle.read(upToCount: maxBytes + 1) ?? Data()
        guard bytes.count <= maxBytes else {
            throw CoreError(message: "This Markdown file is too large for Quick Look. Open it in Folio.")
        }
        guard let text = String(data: bytes, encoding: .utf8), !text.contains("\0") else {
            throw CoreError(message: "Quick Look previews UTF-8 Markdown files.")
        }
        let source = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let preview = try Core.renderMarkdown(source)
        let bundle = Bundle(for: PreviewProvider.self)
        guard let styleURL = bundle.url(forResource: "reader", withExtension: "css") else {
            throw CoreError(message: "The Markdown preview stylesheet is missing.")
        }
        let style = try String(contentsOf: styleURL, encoding: .utf8)
        return Data("""
            <!doctype html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
            <style>
            \(style)
            :root { color-scheme: light dark; }
            body { background: Canvas; }
            article { padding-block: 28px 46px; }
            @media (prefers-color-scheme: dark) {
              :root { --line: #353d4b; --inset: #282f3c; --link: #9cb7ee; }
            }
            </style>
            </head>
            <body><article>\(preview.html)</article></body>
            </html>
            """.utf8)
    }
}
