import AppKit
import SwiftUI

struct ReaderWindow: View {
    let updates: FolioUpdates
    @ObservedObject var model: ReaderModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        workspace.onAppear { updates.showSettings = openSettings }
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            HSplitView {
                if model.sidebar {
                    FolderSidebar(model: model)
                        .frame(minWidth: 176, idealWidth: 224, maxWidth: 265)
                }
                if model.showingGit, let location = model.gitLocation {
                    GitView(location: location, refreshID: model.gitRefresh)
                        .id(location)
                        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ReaderSplit(isSplit: model.split) {
                        ReaderPane(model: model, pane: .left)
                    } right: {
                        ReaderPane(model: model, pane: .right)
                    }
                }
                if model.inspector, !model.showingGit {
                    Inspector(tab: model.active)
                        .frame(minWidth: 150, idealWidth: 185, maxWidth: 230)
                }
            }
            WorkspaceRule()
            StatusBar(model: model)
        }
        .background(WorkspaceStyle.surface)
        .toolbarBackground(WorkspaceStyle.surface, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .navigationTitle(model.showingGit ? "Git" : model.active?.title ?? "Folio")
        .navigationSubtitle(model.showingGit ? model.gitLocation?.displayPath ?? "" : "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let tab = model.active, !model.showingGit {
                    Toggle("Find", systemImage: "magnifyingglass", isOn: Binding(get: { tab.finding }, set: { tab.finding = $0 }))
                        .toggleStyle(.button)
                        .labelStyle(.iconOnly)
                        .disabled(!tab.canFind)
                        .help(tab.finding ? "Hide Find Bar" : "Find in Document (⌘F)")
                    Toggle("Outline", systemImage: "sidebar.right", isOn: $model.inspector)
                        .toggleStyle(.button)
                        .labelStyle(.iconOnly)
                        .disabled(!model.inspector && tab.document?.preview == nil)
                        .help(model.inspector ? "Hide Outline (⌥⌘I)" : "Show Outline (⌥⌘I)")
                    if let file = tab.location.url {
                        OpenWithMenu(file: file, model: model, usesToolbarIcon: true)
                            .help("Open With Another Application")
                    }
                }
            }
        }
        .alert("Folio", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

struct ReaderPane: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.colorScheme) private var colorScheme
    let pane: Pane

    var body: some View {
        let group = model.groups[pane] ?? ReaderModel.Group()
        VStack(spacing: 0) {
            tabBar(group)
            if let tab = group.active {
                ReaderBreadcrumbs(tab: tab, focusPane: { model.focus(pane) }) { location in
                    model.focus(pane)
                    model.open(location)
                }
                .id(tab.id)
                WorkspaceRule()
                TabDocument(tab: tab, appearance: model.appearance, setMediaActivity: model.setMediaActivity, follow: { model.follow($0, from: tab) })
                    .id(tab.id)
            } else {
                ContentUnavailableView {
                    Label(model.split ? "Open a file in this pane" : "Open a file", systemImage: "doc.text")
                } description: {
                    Text(model.sidebar ? "Choose a file in the sidebar, or open one from disk." : "Show the sidebar or open a file from disk.")
                } actions: {
                    Button("Open File…") { model.focus(pane); model.choose() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(alignment: .center) {
            PaneFocus { model.focus(pane) }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(pane.label) Reader")
    }

    private struct TabBarState: Encodable, Equatable {
        struct Tab: Encodable, Equatable {
            let id: UUID
            let title: String
            let icon: String
            let tip: String
            let selected: Bool
            let active: Bool
            let dirty: Bool
        }

        let dark: Bool
        let title: String
        let trailingIcon: String?
        let rows: [Tab]
    }

    private func tabBar(_ group: ReaderModel.Group) -> some View {
        let showSplit = !model.split || pane == .right
        let state = TabBarState(
            dark: colorScheme == .dark,
            title: model.split ? "Merge Panes" : "Split Right",
            trailingIcon: showSplit ? (model.split ? "rectangle" : "rectangle.split.2x1") : nil,
            rows: group.tabs.map { tab in
                TabBarState.Tab(id: tab.id, title: tab.title, icon: FileIcon(name: tab.title, kind: tab.document?.kind).symbol,
                               tip: tab.location.displayPath, selected: group.selected == tab.id,
                               active: group.selected == tab.id && model.focusedPane == pane, dirty: tab.dirty)
            }
        )
        return NativeShellSurface(region: .tabs, state: state) { action, view in
            if action.name == "toggle_split" {
                if !model.split || pane == .right { model.toggleSplit() }
                return
            }
            guard let id = action.id.flatMap(UUID.init(uuidString:)),
                  let tab = model.groups[pane]?.tabs.first(where: { $0.id == id }) else { return }
            switch action.name {
            case "select_tab": model.activate(tab, in: pane)
            case "close_tab": model.close(tab, in: pane)
            case "tab_menu":
                var items: [NSMenuItem] = [
                    NativeShellMenuItem("Move to \(pane.other.label) Pane") { model.move(tab, from: pane, to: pane.other) },
                ]
                if let file = tab.location.url { items.append(OpenWithMenu(file: file, model: model).menuItem()) }
                items += [.separator(), NativeShellMenuItem("Close Tab") { model.close(tab, in: pane) }]
                action.showMenu(items, in: view)
            default: break
            }
        }
        .frame(height: 31)
        .background(WorkspaceStyle.surface)
        .accessibilityLabel("\(pane.label) Tabs")
    }
}

struct TabDocument: View {
    @ObservedObject var tab: ReaderTab
    let appearance: Appearance
    let setMediaActivity: (UUID, Bool) -> Void
    let follow: (URL) -> Void
    @FocusState private var findFocus: Bool

    var body: some View {
        VStack(spacing: 0) {
            if tab.finding, tab.canFind {
                HStack(spacing: 7) {
                    TextField("Find in document", text: $tab.query)
                        .textFieldStyle(.roundedBorder).focused($findFocus)
                        .onAppear { findFocus = true }
                        .onSubmit { tab.web?.find(tab.query) }
                    Button("Previous Match", systemImage: "chevron.up") { tab.web?.find(tab.query, backwards: true) }
                        .labelStyle(.iconOnly).disabled(tab.query.isEmpty)
                    Button("Next Match", systemImage: "chevron.down") { tab.web?.find(tab.query) }
                        .labelStyle(.iconOnly).disabled(tab.query.isEmpty)
                    Button("Done") { tab.finding = false }
                }
                .padding(8)
                .background(WorkspaceStyle.surface)
                .onExitCommand { tab.finding = false }
                Divider()
            }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Folio", isPresented: Binding(get: { tab.error != nil }, set: { if !$0 { tab.error = nil } })) {
            Button("OK") { tab.error = nil }
        } message: { Text(tab.error ?? "") }
    }

    @ViewBuilder
    private var content: some View {
        if tab.loading {
            ProgressView("Opening \(tab.title)…").controlSize(.small)
        } else if let error = tab.loadError {
            ContentUnavailableView {
                Label("Couldn’t open this file", systemImage: "exclamationmark.circle")
            } description: { Text(error) } actions: {
                Button("Reload from Disk", action: tab.load)
            }
        } else if tab.editing {
            SourceEditor(text: $tab.draft)
        } else if let document = tab.document, let file = tab.location.url {
            if let preview = document.preview {
                ReaderWeb(tab: tab, follow: follow, root: tab.location.root, path: tab.location.path,
                          html: preview.html, appearance: appearance)
            } else {
                NativePreview(file: file, kind: document.kind, bytes: document.bytes,
                              playbackChanged: { setMediaActivity(tab.id, $0) })
            }
        }
    }
}

/// The reader contains AppKit and WebKit views, so track clicks without taking
/// their focus, selection or pointer events.
private struct PaneFocus: NSViewRepresentable {
    let focus: () -> Void

    func makeNSView(context: Context) -> Monitor { Monitor() }
    func updateNSView(_ view: Monitor, context: Context) { view.focus = focus }

    @MainActor
    final class Monitor: NSView {
        var focus: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                if let self, event.window === window, bounds.contains(convert(event.locationInWindow, from: nil)) {
                    focus?()
                }
                return event
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

struct StatusBar: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.colorScheme) private var colorScheme

    private struct State: Encodable, Equatable {
        let dark: Bool
        let sidebar: Bool
        let gitAvailable: Bool
        let showingGit: Bool
        let details: String
    }

    var body: some View {
        NativeShellSurface(region: .status, state: State(dark: colorScheme == .dark, sidebar: model.sidebar,
                                        gitAvailable: model.gitLocation != nil, showingGit: model.showingGit,
                                        details: details)) { action, _ in
            switch action.name {
            case "toggle_sidebar": model.sidebar.toggle()
            case "toggle_git" where model.gitLocation != nil: model.showingGit.toggle()
            default: break
            }
        }
        .frame(height: 26)
        .background(WorkspaceStyle.surface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Status Bar")
    }

    private var details: String {
        guard !model.showingGit else { return "" }
        guard let tab = model.active else {
            return "\(model.folders.count) \(model.folders.count == 1 ? "folder" : "folders")"
        }
        var parts = [state(tab)]
        if let document = tab.document {
            parts += [document.kind.label, ByteCountFormatter.string(fromByteCount: document.bytes, countStyle: .file)]
        }
        if model.split { parts.append(model.focusedPane.label + " Pane") }
        return parts.joined(separator: "  ")
    }

    private func state(_ tab: ReaderTab) -> String {
        if tab.loading { return "Opening…" }
        if tab.loadError != nil { return "Unavailable" }
        if tab.dirty { return "Unsaved" }
        return tab.editing ? "Editing" : "Reading"
    }
}
