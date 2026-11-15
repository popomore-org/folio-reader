import AppKit
import SwiftUI

enum QuickPreviewRequest {
    static let windowID = "quick-preview"
    static let windowIdentifier = NSUserInterfaceItemIdentifier("folio.quick-preview")
    static let scheme = Bundle.main.object(forInfoDictionaryKey: "FolioPreviewScheme") as? String ?? "folio-reader-preview"
    static let route = "\(scheme)://preview"

    static func matches(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == "preview"
    }

    static func file(in url: URL) throws -> FileLocation? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              matches(url), components.user == nil, components.password == nil, components.port == nil,
              components.path.isEmpty || components.path == "/", components.fragment == nil else {
            throw CoreError(message: "This quick preview link is invalid.")
        }
        let items = components.queryItems ?? []
        guard !items.isEmpty else { return nil }
        guard items.count == 1, items[0].name == "path", let path = items[0].value,
              path.hasPrefix("/"), !path.utf8.contains(0) else {
            throw CoreError(message: "Quick Preview requires an absolute file path.")
        }
        return try file(at: URL(fileURLWithPath: path))
    }

    static func file(at url: URL) throws -> FileLocation {
        let file = url.resolvingSymlinksInPath().standardizedFileURL
        guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw CoreError(message: "Choose a regular file to preview.")
        }
        return FileLocation(root: file.deletingLastPathComponent(), path: file.lastPathComponent)
    }
}

struct QuickPreview: View {
    @ObservedObject var model: ReaderModel
    let openInWorkspace: (URL) -> Void
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var tab: ReaderTab?
    @State private var error: String?
    @State private var chooser: NSOpenPanel?
    @State private var currentRequest = UUID()

    var body: some View {
        VStack(spacing: 0) {
            if let tab {
                TabDocument(tab: tab, appearance: model.appearance, setMediaActivity: model.setMediaActivity,
                            follow: { follow($0, from: tab) })
                    .id(tab.id)
            } else {
                ContentUnavailableView {
                    Label(error == nil ? "Open a file to preview" : "Preview unavailable",
                          systemImage: error == nil ? "doc" : "exclamationmark.circle")
                } description: {
                    if let error { Text(error) }
                } actions: {
                    Button("Choose File…", action: choose)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 260)
        .background(Color(nsColor: .textBackgroundColor))
        .background(PreviewWindowStyle())
        .navigationTitle(tab?.title ?? "Quick Preview")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Choose File", systemImage: "folder", action: choose)
                if let url = tab?.location.url {
                    Button("Open in Folio", systemImage: "arrow.up.right.square") {
                        openInWorkspace(url)
                        dismissWindow(id: QuickPreviewRequest.windowID)
                    }
                }
            }
        }
        .focusedSceneValue(\.quickPreviewActive, true)
        .handlesExternalEvents(preferring: [QuickPreviewRequest.route], allowing: [QuickPreviewRequest.route])
        .onOpenURL { url in
            guard QuickPreviewRequest.matches(url) else { return }
            currentRequest = UUID()
            chooser?.cancel(nil)
            do {
                if let file = try QuickPreviewRequest.file(in: url) {
                    show(file)
                } else {
                    DispatchQueue.main.async { choose() }
                }
            } catch {
                showError(error)
            }
        }
    }

    private func show(_ location: FileLocation, fragment: String? = nil) {
        error = nil
        let next = ReaderTab(location: location)
        next.pendingFragment = fragment
        tab = next
        next.load()
    }

    private func follow(_ url: URL, from tab: ReaderTab) {
        let location = FileLocation(root: tab.location.root, path: String(url.path.dropFirst()))
        let fragment = url.fragment?.removingPercentEncoding
        if location == tab.location, let fragment {
            tab.web?.heading(fragment)
        } else if let file = location.url,
                  (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            show(location, fragment: fragment)
        }
    }

    private func showError(_ error: any Error) {
        tab = nil
        self.error = error.localizedDescription
    }

    private func choose() {
        guard let window = NSApp.windows.first(where: { $0.identifier == QuickPreviewRequest.windowIdentifier }) else { return }
        guard chooser == nil else { return }
        let panel = NSOpenPanel()
        let request = currentRequest
        chooser = panel
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { response in
            chooser = nil
            guard request == currentRequest, response == .OK, let file = panel.url else { return }
            do {
                show(try QuickPreviewRequest.file(at: file))
            } catch {
                showError(error)
            }
        }
    }
}

extension FocusedValues {
    @Entry var quickPreviewActive: Bool?
}

private struct PreviewWindowStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowObserver { WindowObserver() }
    func updateNSView(_ view: WindowObserver, context: Context) {}

    static func dismantleNSView(_ view: WindowObserver, coordinator: ()) {
        view.stopMonitoring()
    }

    final class WindowObserver: NSView {
        private var keyMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard let window else { return }
            window.identifier = QuickPreviewRequest.windowIdentifier
            window.level = .floating
            window.tabbingMode = .disallowed
            window.isRestorable = false
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window] event in
                guard let window, event.window === window, window.attachedSheet == nil else { return event }
                let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                let escape = event.charactersIgnoringModifiers == "\u{1b}" && modifiers.isEmpty
                let close = event.charactersIgnoringModifiers == "w" && modifiers == .command
                guard escape || close else { return event }
                window.performClose(nil)
                return nil
            }
        }

        func stopMonitoring() {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
        }
    }
}
