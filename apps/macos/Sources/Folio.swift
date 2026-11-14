import AppKit
import SwiftUI

@main
struct Folio: App {
    @NSApplicationDelegateAdaptor(FolioDelegate.self) private var delegate
    @StateObject private var model = ReaderModel()

    var body: some Scene {
        WindowGroup("Folio") {
            ReaderWindow(model: model)
                .frame(minWidth: 670, minHeight: 440)
                .onAppear {
                    delegate.model = model
                    if let url = delegate.pending {
                        delegate.pending = nil
                        model.open(url)
                    }
                }
                .background(WindowOwner(model: model))
        }
        .defaultSize(width: 1130, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…", action: model.choose).keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { model.save() }.keyboardShortcut("s").disabled(!model.editing)
                Button("Reload from Disk", action: model.refresh).keyboardShortcut("r").disabled(model.root == nil)
            }
            CommandGroup(after: .textEditing) {
                Button("Find in Document") { model.finding = true }
                    .keyboardShortcut("f").disabled(model.document?.preview == nil || model.editing)
                Button("Edit Source") { model.edit() }
                    .keyboardShortcut("e").disabled(model.document?.revision == nil || model.editing)
            }
            CommandGroup(after: .toolbar) {
                Button(model.sidebar ? "Hide Sidebar" : "Show Sidebar") { model.sidebar.toggle() }
                    .keyboardShortcut("s", modifiers: [.command, .control])
                Button(model.inspector ? "Hide Inspector" : "Show Inspector") { model.inspector.toggle() }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                Button("Focus Reading") {
                    let focus = model.sidebar || model.inspector
                    model.sidebar = !focus
                    model.inspector = false
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                Divider()
                Button("Increase Text Size") { model.setSize(1) }.keyboardShortcut("=")
                Button("Decrease Text Size") { model.setSize(-1) }.keyboardShortcut("-")
                Button("Reset Text Size") { model.appearance.size = 18 }.keyboardShortcut("0")
            }
        }
    }
}

@MainActor
final class FolioDelegate: NSObject, NSApplicationDelegate {
    weak var model: ReaderModel?
    var pending: URL?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if let model { model.open(url) } else { pending = url }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model?.leaveDraft() == false ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct WindowOwner: NSViewRepresentable {
    let model: ReaderModel

    func makeNSView(context: Context) -> Owner {
        Owner(model: model)
    }

    func updateNSView(_ view: Owner, context: Context) {}

    @MainActor
    final class Owner: NSView, NSWindowDelegate {
        weak var model: ReaderModel?
        nonisolated(unsafe) weak var previous: (any NSWindowDelegate)?

        init(model: ReaderModel) {
            self.model = model
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window.delegate !== self else { return }
            previous = window.delegate
            window.delegate = self
            window.tabbingMode = .disallowed
        }

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || previous?.responds(to: aSelector) == true
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if previous?.responds(to: aSelector) == true { return previous }
            return super.forwardingTarget(for: aSelector)
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            model?.leaveDraft() != false && previous?.windowShouldClose?(sender) != false
        }
    }
}
