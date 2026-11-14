import AppKit
import SwiftUI

struct ReaderWindow: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
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
                    HSplitView {
                        reader(.left)
                        if model.split { reader(.right) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if model.inspector, !model.showingGit {
                    Inspector(tab: model.active)
                        .frame(minWidth: 150, idealWidth: 185, maxWidth: 230)
                }
            }
            Divider()
            StatusBar(model: model)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbarBackground(Color(nsColor: .windowBackgroundColor), for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .navigationTitle(model.showingGit ? "Git" : model.active?.title ?? "Folio")
        .navigationSubtitle(model.active?.location.displayPath ?? "")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { model.sidebar.toggle() } label: {
                    Label("Sidebar", systemImage: "sidebar.left")
                }.help("Toggle Sidebar")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if let active = model.active, !model.showingGit {
                    if active.editing {
                        Button("Done") { _ = active.leaveDraft() }
                        Button("Save") { active.save() }.disabled(!active.dirty)
                    } else {
                        Button("Edit Source", systemImage: "square.and.pencil", action: active.edit)
                            .disabled(!active.canEdit)
                            .help("Edit Source (⌘E)")
                        Button("Find", systemImage: "magnifyingglass") { active.finding.toggle() }
                            .disabled(!active.canFind)
                            .help("Find in Document (⌘F)")
                    }
                }
                Button(model.split ? "Merge Panes" : "Split Right",
                       systemImage: model.split ? "rectangle" : "rectangle.split.2x1",
                       action: model.toggleSplit)
                    .help(model.split ? "Merge Panes" : "Split Right")
                Button("Outline", systemImage: "sidebar.right") { model.inspector.toggle() }
                    .help("Toggle Outline")
                    .disabled(model.active?.document?.preview == nil || model.showingGit)
                Button("Settings", systemImage: "gearshape") { openSettings() }
                    .help("Settings (⌘,)")
            }
        }
        .alert("Folio", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private func reader(_ pane: Pane) -> some View {
        ReaderPane(model: model, pane: pane)
            .frame(minWidth: 265, maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReaderPane: View {
    @ObservedObject var model: ReaderModel
    let pane: Pane

    var body: some View {
        let group = model.groups[pane] ?? ReaderModel.Group()
        VStack(spacing: 0) {
            if !group.tabs.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 3) {
                            ForEach(group.tabs) { tab in
                                TabButton(model: model, pane: pane, tab: tab, selected: group.selected == tab.id)
                                    .id(tab.id)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: group.selected, initial: true) { _, selected in
                        if let selected { proxy.scrollTo(selected) }
                    }
                }
                .accessibilityLabel("\(pane.label) Tabs")
                Divider()
            }
            if let tab = group.active {
                TabDocument(tab: tab, appearance: model.appearance, follow: { model.follow($0, from: tab) })
                    .id(tab.id)
            } else {
                ContentUnavailableView {
                    Label(model.split ? "Open a file in this pane" : "Open a file", systemImage: "doc.text")
                } description: {
                    Text(model.sidebar ? "Choose a file in the sidebar, or open one from disk." : "Show the sidebar or open a file from disk.")
                } actions: {
                    Button("Open File…") { model.focus(pane); model.choose() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .center) {
            PaneFocus { model.focus(pane) }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(alignment: .top) {
            if model.split, model.focusedPane == pane {
                Rectangle().fill(Color.accentColor).frame(height: 1)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(pane.label) Reader")
    }
}

private struct TabButton: View {
    let model: ReaderModel
    let pane: Pane
    @ObservedObject var tab: ReaderTab
    let selected: Bool

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
        .font(.callout)
        .frame(maxWidth: 220)
        .background(selected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.13) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
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

private struct TabDocument: View {
    @ObservedObject var tab: ReaderTab
    let appearance: Appearance
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
                .background(Color(nsColor: .windowBackgroundColor))
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
                NativePreview(file: file, kind: document.kind, bytes: document.bytes)
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
        HStack(spacing: 12) {
            Button {
                model.showingGit.toggle()
            } label: {
                Label(model.showingGit ? "Back to Reading" : "Git", systemImage: "arrow.triangle.branch")
            }
            .buttonStyle(.borderless)
            .disabled(model.gitLocation == nil)
            .help(model.showingGit ? "Back to Reading" : "Open Git View")
            if let tab = model.active {
                Text(tab.location.displayPath).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 6)
                Text(state(tab))
                if let document = tab.document {
                    Text(document.kind.label)
                    Text(ByteCountFormatter.string(fromByteCount: document.bytes, countStyle: .file))
                }
                if model.split { Text(model.focusedPane.label + " Pane") }
            } else {
                Spacer()
                Text("\(model.folders.count) \(model.folders.count == 1 ? "folder" : "folders")")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 28)
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
