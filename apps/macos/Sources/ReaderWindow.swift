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

    private func tabBar(_ group: ReaderModel.Group) -> some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(group.tabs) { tab in
                            TabButton(model: model, pane: pane, tab: tab, selected: group.selected == tab.id,
                                      focused: model.focusedPane == pane)
                                .id(tab.id)
                            WorkspaceRule(vertical: true)
                                .frame(height: 30)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: group.selected, initial: true) { _, selected in
                    if let selected { proxy.scrollTo(selected) }
                }
            }
            .accessibilityLabel("\(pane.label) Tabs")
            if !model.split || pane == .right {
                Button(action: model.toggleSplit) {
                    Image(systemName: model.split ? "rectangle" : "rectangle.split.2x1")
                        .frame(width: 25, height: 25)
                }
                .buttonStyle(WorkspaceButton())
                .accessibilityLabel(model.split ? "Merge Panes" : "Split Right")
                .help(model.split ? "Merge Panes" : "Split Right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
        }
        .workspaceHeader()
    }

}

private struct TabButton: View {
    let model: ReaderModel
    let pane: Pane
    @ObservedObject var tab: ReaderTab
    let selected: Bool
    let focused: Bool

    var body: some View {
        HStack(spacing: 2) {
            Button {
                model.activate(tab, in: pane)
            } label: {
                HStack(spacing: 5) {
                    FileIcon(name: tab.title, kind: tab.document?.kind)
                    Text(tab.title).lineLimit(1).truncationMode(.middle)
                }
                .padding(.leading, 7)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            Button { model.close(tab, in: pane) } label: {
                Image(systemName: tab.dirty ? "circle.fill" : "xmark")
                    .font(.system(size: tab.dirty ? 6 : 8, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close \(tab.title)")
        }
        .font(.system(size: 12, weight: selected ? .medium : .regular))
        .foregroundStyle(selected ? .primary : .secondary)
        .frame(maxWidth: 218)
        .frame(height: 30)
        .background(selected ? (focused ? WorkspaceStyle.selection : WorkspaceStyle.hover) : .clear)
        .overlay(alignment: .bottom) {
            if selected && focused {
                Rectangle().fill(WorkspaceStyle.focus).frame(height: 2)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
        .help(tab.location.displayPath)
        .contextMenu {
            Button("Move to \(pane.other.label) Pane") { model.move(tab, from: pane, to: pane.other) }
            if let file = tab.location.url {
                OpenWithMenu(file: file, model: model)
            }
            Divider()
            Button("Close Tab") { model.close(tab, in: pane) }
        }
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

    var body: some View {
        HStack(spacing: 9) {
            Button {
                model.sidebar.toggle()
            } label: {
                Image(systemName: "sidebar.left").frame(width: 25, height: 23)
            }
            .buttonStyle(WorkspaceButton(selected: model.sidebar))
            .accessibilityLabel(model.sidebar ? "Hide Folder Tree" : "Show Folder Tree")
            .help("Toggle Folder Tree")
            Button {
                model.showingGit.toggle()
            } label: {
                Label(model.showingGit ? "Back to Reading" : "Git", systemImage: "arrow.triangle.branch")
                    .padding(.horizontal, 6).frame(height: 23)
            }
            .buttonStyle(WorkspaceButton(selected: model.showingGit))
            .disabled(model.gitLocation == nil)
            .help(model.showingGit ? "Back to Reading" : "Open Git View")
            Spacer(minLength: 6)
            if let tab = model.active, !model.showingGit {
                Text(state(tab))
                if let document = tab.document {
                    Text(document.kind.label)
                    Text(ByteCountFormatter.string(fromByteCount: document.bytes, countStyle: .file))
                }
                if model.split { Text(model.focusedPane.label + " Pane") }
            } else if !model.showingGit {
                Text("\(model.folders.count) \(model.folders.count == 1 ? "folder" : "folders")")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .frame(height: 26)
        .background(WorkspaceStyle.surface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Status Bar")
    }

    private func state(_ tab: ReaderTab) -> String {
        if tab.loading { return "Opening…" }
        if tab.loadError != nil { return "Unavailable" }
        if tab.dirty { return "Unsaved" }
        return tab.editing ? "Editing" : "Reading"
    }
}
