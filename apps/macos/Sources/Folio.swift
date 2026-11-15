import AppKit
import SwiftUI

enum InstanceMode {
    static let isSeparate = CommandLine.arguments.contains("--folio-new-instance")
}

@main
struct Folio: App {
    @NSApplicationDelegateAdaptor(FolioDelegate.self) private var delegate
    @StateObject private var model = ReaderModel()
    @StateObject private var updates = FolioUpdates()
    @FocusedValue(\.quickPreviewActive) private var quickPreviewActive

    private var workspaceFocused: Bool { quickPreviewActive != true }

    var body: some Scene {
        WindowGroup("Folio", id: "workspace") {
            WorkspaceSceneContent(delegate: delegate, model: model, updates: updates)
        }
        .handlesExternalEvents(matching: [])
        .defaultSize(width: 1130, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…", action: updates.openUpdateSettings)
                    .disabled(!updates.isConfigured)
            }
            CommandGroup(replacing: .newItem) {
                Button("Open…") { model.choose() }.keyboardShortcut("o").disabled(!workspaceFocused)
                Button("Add Folders…") { model.choose(foldersOnly: true) }.disabled(!workspaceFocused)
                if workspaceFocused {
                    Button("Close Tab", action: model.closeActive)
                        .keyboardShortcut("w").disabled(model.active == nil && !model.showingGit)
                } else {
                    Button("Close Preview") { NSApp.keyWindow?.performClose(nil) }.keyboardShortcut("w")
                }
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { model.active?.save() }.keyboardShortcut("s").disabled(!workspaceFocused || model.active?.editing != true || model.showingGit)
                Button("Reload from Disk", action: model.reload).keyboardShortcut("r").disabled(!workspaceFocused || model.gitLocation == nil)
            }
            CommandGroup(after: .textEditing) {
                Button("Find in Document") { model.active?.finding = true }
                    .keyboardShortcut("f").disabled(!workspaceFocused || model.active?.canFind != true || model.showingGit)
                Button(model.active?.editing == true ? "Return to Reading" : "Edit Source") {
                    if let active = model.active { active.setEditing(!active.editing) }
                }
                .keyboardShortcut("e")
                .disabled(!workspaceFocused || model.active?.canEdit != true || model.showingGit)
            }
            CommandGroup(after: .toolbar) {
                Button("Focus Folder Tree", action: model.focusFolderTree)
                    .keyboardShortcut("e", modifiers: [.command, .shift]).disabled(!workspaceFocused)
                Button(model.sidebar ? "Hide Sidebar" : "Show Sidebar") { model.sidebar.toggle() }
                    .keyboardShortcut("s", modifiers: [.command, .control]).disabled(!workspaceFocused)
                Button(model.inspector ? "Hide Inspector" : "Show Inspector") { model.inspector.toggle() }
                    .keyboardShortcut("i", modifiers: [.command, .option]).disabled(!workspaceFocused)
                Button("Focus Reading") {
                    let focus = model.sidebar || model.inspector
                    model.sidebar = !focus
                    model.inspector = false
                }
                .keyboardShortcut("f", modifiers: [.command, .shift]).disabled(!workspaceFocused)
                Button(model.split ? "Merge Panes" : "Split Right", action: model.toggleSplit)
                    .keyboardShortcut("\\").disabled(!workspaceFocused)
                Button("Next Tab") { model.cycle(1) }.keyboardShortcut(.tab, modifiers: [.control]).disabled(!workspaceFocused)
                Button("Previous Tab") { model.cycle(-1) }.keyboardShortcut(.tab, modifiers: [.control, .shift]).disabled(!workspaceFocused)
                Button(model.showingGit ? "Back to Reading" : "Show Git") { model.showingGit.toggle() }
                    .disabled(!workspaceFocused || model.gitLocation == nil)
                Divider()
                Button("Increase Text Size") { model.appearance.size = min(30, model.appearance.size + 1) }.keyboardShortcut("=")
                Button("Decrease Text Size") { model.appearance.size = max(13, model.appearance.size - 1) }.keyboardShortcut("-")
                Button("Reset Text Size") { model.appearance.size = 18 }.keyboardShortcut("0")
            }
        }
        Window("Quick Preview", id: QuickPreviewRequest.windowID) {
            PreviewSceneContent(delegate: delegate, model: model, updates: updates)
                .preferredColorScheme(model.appearance.workspace.colorScheme)
        }
        .defaultSize(width: 680, height: 580)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: [QuickPreviewRequest.route])
        .commandsRemoved()

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
    var showWorkspace: (([URL]) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        guard !files.isEmpty else { return }
        if let showWorkspace { showWorkspace(files) } else { pending.append(contentsOf: files) }
    }

    func registerWorkspace(model: ReaderModel, openWindow: OpenWindowAction) {
        showWorkspace = { [weak self, weak model] urls in
            if let window = NSApp.windows.first(where: { $0.identifier == WindowOwner.identifier && ($0.isVisible || $0.isMiniaturized) }) {
                model?.openURLs(urls)
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
            } else {
                self?.pending.append(contentsOf: urls)
                openWindow(id: "workspace")
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard updates?.allowUpdateTermination() != false else { return .terminateCancel }
        return model?.protectAllDrafts() == false ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

private struct WorkspaceSceneContent: View {
    let delegate: FolioDelegate
    @ObservedObject var model: ReaderModel
    let updates: FolioUpdates
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ReaderWindow(updates: updates, model: model)
            .preferredColorScheme(model.appearance.workspace.colorScheme)
            .frame(minWidth: 910, minHeight: 500)
            .onAppear {
                delegate.model = model
                delegate.updates = updates
                delegate.registerWorkspace(model: model, openWindow: openWindow)
                updates.start(model: model)
                DispatchQueue.main.async { updates.offerUpdateChecks(on: NSApp.mainWindow) }
                model.openURLs(delegate.pending)
                delegate.pending = []
            }
            .background(WindowOwner(model: model, updates: updates))
    }
}

private struct PreviewSceneContent: View {
    let delegate: FolioDelegate
    @ObservedObject var model: ReaderModel
    let updates: FolioUpdates
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        QuickPreview(model: model) { url in
            delegate.showWorkspace?([url])
        }
        .onAppear {
            delegate.updates = updates
            delegate.registerWorkspace(model: model, openWindow: openWindow)
            updates.start(model: model)
            if !delegate.pending.isEmpty {
                let files = delegate.pending
                delegate.pending = []
                delegate.showWorkspace?(files)
            }
        }
    }
}

struct WindowOwner: NSViewRepresentable {
    static let identifier = NSUserInterfaceItemIdentifier("folio.workspace")
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
            window.identifier = WindowOwner.identifier
            if InstanceMode.isSeparate { window.isRestorable = false }
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
