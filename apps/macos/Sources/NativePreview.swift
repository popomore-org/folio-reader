import AppKit
import AVKit
import PDFKit
import SwiftUI

struct NativePreview: View {
    let file: URL
    let kind: FileKind
    let bytes: Int64

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
            MediaReader(file: file, audio: kind == .audio)
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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        if let editor = scroll.documentView as? NSTextView {
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
            DispatchQueue.main.async { editor.window?.makeFirstResponder(editor) }
        }
        return scroll
    }

    func updateNSView(_ view: NSScrollView, context: Context) {
        context.coordinator.owner = self
        if let editor = view.documentView as? NSTextView, editor.string != text { editor.string = text }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var owner: SourceEditor
        init(_ owner: SourceEditor) { self.owner = owner }
        func textDidChange(_ notification: Notification) {
            if let editor = notification.object as? NSTextView { owner.text = editor.string }
        }
    }
}

struct MediaReader: View {
    let file: URL
    let audio: Bool
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
        .onDisappear {
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
