import AppKit
import SwiftUI

@main
struct Folio: App {
    @NSApplicationDelegateAdaptor(FolioDelegate.self) private var delegate
    @StateObject private var model = ReaderModel()
    @StateObject private var updates = FolioUpdates()

    var body: some Scene {
        WindowGroup("Folio") {
            ReaderWindow(updates: updates, model: model)
                .preferredColorScheme(model.appearance.workspace.colorScheme)
                .frame(minWidth: 910, minHeight: 500)
                .onAppear {
                    delegate.model = model
                    delegate.updates = updates
                    updates.start(model: model)
                    DispatchQueue.main.async { updates.offerUpdateChecks(on: NSApp.mainWindow) }
                    model.openURLs(delegate.pending)
                    delegate.pending = []
                }
                .background(WindowOwner(model: model, updates: updates))
        }
        .defaultSize(width: 1130, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…", action: updates.openUpdateSettings)
                    .disabled(!updates.isConfigured)
            }
            CommandGroup(replacing: .newItem) {
                Button("Open…") { model.choose() }.keyboardShortcut("o")
                Button("Add Folders…") { model.choose(foldersOnly: true) }
                Button("Close Tab", action: model.closeActive).keyboardShortcut("w").disabled(model.active == nil && !model.showingGit)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { model.active?.save() }.keyboardShortcut("s").disabled(model.active?.editing != true || model.showingGit)
                Button("Reload from Disk", action: model.reload).keyboardShortcut("r").disabled(model.gitLocation == nil)
            }
            CommandGroup(after: .textEditing) {
                Button("Find in Document") { model.active?.finding = true }
                    .keyboardShortcut("f").disabled(model.active?.canFind != true || model.showingGit)
                Button("Edit Source") { model.active?.edit() }
                    .keyboardShortcut("e").disabled(model.active?.canEdit != true || model.showingGit)
            }
            CommandGroup(after: .toolbar) {
                Button("Focus Folder Tree", action: model.focusFolderTree)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
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
                Button(model.split ? "Merge Panes" : "Split Right", action: model.toggleSplit)
                    .keyboardShortcut("\\")
                Button("Next Tab") { model.cycle(1) }.keyboardShortcut(.tab, modifiers: [.control])
                Button("Previous Tab") { model.cycle(-1) }.keyboardShortcut(.tab, modifiers: [.control, .shift])
                Button(model.showingGit ? "Back to Reading" : "Show Git") { model.showingGit.toggle() }
                    .disabled(model.gitLocation == nil)
                Divider()
                Button("Increase Text Size") { model.appearance.size = min(30, model.appearance.size + 1) }.keyboardShortcut("=")
                Button("Decrease Text Size") { model.appearance.size = max(13, model.appearance.size - 1) }.keyboardShortcut("-")
                Button("Reset Text Size") { model.appearance.size = 18 }.keyboardShortcut("0")
            }
        }
        Settings {
            ReaderSettings(model: model, updates: updates)
                .preferredColorScheme(model.appearance.workspace.colorScheme)
        }
    }
}

@MainActor
final class FolioDelegate: NSObject, NSApplicationDelegate {
    weak var model: ReaderModel?
    weak var updates: FolioUpdates?
    var pending: [URL] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        if let model { model.openURLs(urls) } else { pending.append(contentsOf: urls) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard updates?.allowUpdateTermination() != false else { return .terminateCancel }
        return model?.protectAllDrafts() == false ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct WindowOwner: NSViewRepresentable {
    let model: ReaderModel
    let updates: FolioUpdates

    func makeNSView(context: Context) -> Owner {
        Owner(model: model, updates: updates)
    }

    func updateNSView(_ view: Owner, context: Context) {}

    @MainActor
    final class Owner: NSView, NSWindowDelegate {
        weak var model: ReaderModel?
        weak var updates: FolioUpdates?
        nonisolated(unsafe) weak var previous: (any NSWindowDelegate)?

        init(model: ReaderModel, updates: FolioUpdates) {
            self.model = model
            self.updates = updates
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window.delegate !== self else { return }
            previous = window.delegate
            window.delegate = self
            window.tabbingMode = .disallowed
            DispatchQueue.main.async { [weak self, weak window] in self?.updates?.offerUpdateChecks(on: window) }
        }

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || previous?.responds(to: aSelector) == true
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if previous?.responds(to: aSelector) == true { return previous }
            return super.forwardingTarget(for: aSelector)
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            model?.protectAllDrafts() != false && previous?.windowShouldClose?(sender) != false
        }
    }
}
