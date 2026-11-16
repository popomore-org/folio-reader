import AppKit
import AVKit
import PDFKit
import SwiftUI

struct NativePreview: View {
    let file: URL
    let kind: FileKind
    let bytes: Int64
    let playbackChanged: (Bool) -> Void

    @ViewBuilder
    var body: some View {
        switch kind {
        case .pdf:
            if let document = PDFDocument(url: file) {
                PDFReader(document: document)
            } else {
                unavailable("This PDF could not be opened.")
            }
        case .rtf:
            if bytes <= 8 * 1024 * 1024,
               let text = try? NSAttributedString(url: file, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                RichText(text: text)
            } else {
                unavailable("This RTF is too large or could not be read.")
            }
        case .image:
            if let image = NSImage(contentsOf: file), image.isValid {
                Image(nsImage: image).resizable().scaledToFit().padding(20)
                    .accessibilityLabel(file.lastPathComponent)
            } else {
                unavailable("This image could not be decoded.")
            }
        case .audio, .video:
            MediaReader(file: file, audio: kind == .audio, playbackChanged: playbackChanged)
        default:
            unavailable("Folio has no preview for this file type.")
        }
    }

    private func unavailable(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Preview unavailable", systemImage: "doc")
        } description: { Text(message) } actions: {
            Button("Open in Default App") { NSWorkspace.shared.open(file) }
        }
    }
}

struct PDFReader: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = document
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {}
}

struct RichText: NSViewRepresentable {
    let text: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        if let editor = scroll.documentView as? NSTextView {
            editor.isEditable = false
            editor.textContainerInset = NSSize(width: 28, height: 28)
            editor.textStorage?.setAttributedString(text)
        }
        return scroll
    }

    func updateNSView(_ view: NSScrollView, context: Context) {}
}

struct SourceEditor: NSViewRepresentable {
    @Binding var text: String
    let name: String
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        if let editor = scroll.documentView as? NSTextView {
            // Temporary colors belong to the layout manager, not the editable text storage.
            _ = editor.layoutManager
            editor.delegate = context.coordinator
            editor.string = text
            editor.isRichText = false
            editor.allowsUndo = true
            editor.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            editor.textContainerInset = NSSize(width: 24, height: 26)
            editor.isAutomaticQuoteSubstitutionEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.setAccessibilityLabel("Document Source")
            context.coordinator.highlight(editor, immediately: true)
            DispatchQueue.main.async { editor.window?.makeFirstResponder(editor) }
        }
        return scroll
    }

    func updateNSView(_ view: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let refreshColors = coordinator.owner.colorScheme != colorScheme || coordinator.owner.name != name
        coordinator.owner = self
        guard let editor = view.documentView as? NSTextView else { return }
        if editor.string != text {
            editor.string = text
            coordinator.highlight(editor, immediately: true)
        } else if refreshColors {
            coordinator.highlight(editor, immediately: true)
        }
    }

    static func dismantleNSView(_ view: NSScrollView, coordinator: Coordinator) {
        coordinator.highlightTask?.cancel()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var owner: SourceEditor
        var highlightTask: Task<Void, Never>?
        init(_ owner: SourceEditor) { self.owner = owner }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            owner.text = editor.string
            highlight(editor)
        }

        func highlight(_ editor: NSTextView, immediately: Bool = false) {
            highlightTask?.cancel()
            let source = editor.string
            let name = owner.name
            // Match the core's input limit before serializing a draft across the bridge.
            guard !source.isEmpty, source.utf8.count <= 128 * 1024 else {
                apply([], to: editor)
                return
            }
            highlightTask = Task { [weak self, weak editor] in
                if !immediately {
                    do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
                }
                let spans = await Task.detached(priority: .userInitiated) {
                    (try? Core.sourceHighlights(for: name, source: source)) ?? []
                }.value
                guard !Task.isCancelled, let self, let editor, editor.string == source, !editor.hasMarkedText() else { return }
                apply(spans, to: editor)
            }
        }

        private func apply(_ spans: [SourceHighlight], to editor: NSTextView) {
            guard let layout = editor.layoutManager, let length = editor.textStorage?.length, length > 0 else { return }
            layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: 0, length: length))
            for span in spans where span.start >= 0 && span.end > span.start && span.end <= length {
                layout.addTemporaryAttribute(.foregroundColor, value: span.token.color(dark: owner.colorScheme == .dark),
                                             forCharacterRange: NSRange(location: span.start, length: span.end - span.start))
            }
        }
    }
}

private extension SourceHighlight.Token {
    func color(dark: Bool) -> NSColor {
        // These pairs match the reading and Quick Look styles in reader.css.
        let (lightColor, darkColor): (UInt32, UInt32) = switch self {
        case .comment: (0x5F6878, 0xA1AABD)
        case .keyword: (0x8B3D92, 0xE3B7F5)
        case .string, .added: (0x34622E, 0xB1D99B)
        case .constant: (0x9C4B10, 0xF5BB8F)
        case .type: (0x075E68, 0x9BD7DC)
        case .function: (0x24589B, 0xA9CAFF)
        case .tag: (0xA03E65, 0xEFA0BA)
        case .removed: (0xAE3444, 0xFF9FAF)
        }
        return WorkspaceStyle.srgb(dark ? darkColor : lightColor)
    }
}

struct MediaReader: View {
    let file: URL
    let audio: Bool
    let playbackChanged: (Bool) -> Void
    @State private var player = AVPlayer()
    @State private var error: String?

    var body: some View {
        VStack(spacing: 18) {
            if let error {
                ContentUnavailableView("Can’t play this file", systemImage: "exclamationmark.circle",
                                       description: Text(error))
            } else if audio {
                Spacer()
                Image(systemName: "waveform").font(.system(size: 38)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(file.lastPathComponent).font(.title3)
                PlayerControls(player: player).frame(maxWidth: 560, maxHeight: 54)
                Spacer()
            } else {
                PlayerControls(player: player)
            }
        }
        .padding(18)
        .task {
            do {
                let asset = AVURLAsset(url: file)
                guard try await asset.load(.isPlayable) else {
                    error = "The installed macOS media decoders couldn’t play this format."
                    return
                }
                if !Task.isCancelled { player.replaceCurrentItem(with: AVPlayerItem(asset: asset)) }
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
        .onReceive(player.publisher(for: \.timeControlStatus)) { state in
            playbackChanged(state != .paused)
        }
        .onDisappear {
            playbackChanged(false)
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }
}

struct PlayerControls: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {}
}
