import AppKit
import SwiftUI

struct ReaderWindow: View {
    @ObservedObject var model: ReaderModel
    @State private var query = ""
    @FocusState private var findFocus: Bool

    var body: some View {
        HStack(spacing: 0) {
            HSplitView {
                if model.sidebar {
                    sidebar.frame(minWidth: 172, idealWidth: 222, maxWidth: 340)
                }
                reading.frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                if model.inspector {
                    Inspector(model: model).frame(minWidth: 180, idealWidth: 234, maxWidth: 330)
                }
            }
        }
        .navigationTitle(model.title)
        .navigationSubtitle(model.path.map { "\(model.root?.lastPathComponent ?? "") / \($0)" } ?? "")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    model.sidebar.toggle()
                } label: { Label("Sidebar", systemImage: "sidebar.left") }.help("Toggle Sidebar")
            }
            ToolbarItem(placement: .navigation) {
                Button(action: model.choose) {
                    Label("Open", systemImage: "folder")
                }
                .help("Open File or Folder (⌘O)")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if model.editing {
                    Button("Done") { _ = model.leaveDraft() }
                    Button("Save") { model.save() }.buttonStyle(.borderedProminent).disabled(!model.dirty)
                } else {
                    Button(action: model.edit) { Label("Edit Source", systemImage: "square.and.pencil") }
                        .help("Edit Source (⌘E)").disabled(model.document?.revision == nil)
                    Button { model.finding.toggle() } label: { Label("Find", systemImage: "magnifyingglass") }
                        .help("Find in Document (⌘F)").disabled(model.document?.preview == nil)
                    Menu {
                        Picker("Theme", selection: $model.appearance.theme) {
                            ForEach(Theme.allCases) { theme in Text(theme.label).tag(theme) }
                        }
                        Picker("Typeface", selection: $model.appearance.serif) {
                            Text("Serif").tag(true)
                            Text("Sans Serif").tag(false)
                        }
                        Picker("Reading Width", selection: $model.appearance.width) {
                            Text("Narrow").tag(570.0)
                            Text("Standard").tag(700.0)
                            Text("Wide").tag(920.0)
                        }
                        Divider()
                        Button("Larger Text") { model.setSize(1) }
                        Button("Smaller Text") { model.setSize(-1) }
                        Button("Reset Text Size") { model.appearance.size = 18 }
                    } label: {
                        Label("Reading Appearance", systemImage: "textformat.size")
                    }
                    .help("Reading Appearance").disabled(model.document?.preview == nil)
                    Button { model.inspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.right") }
                        .help("Show Outline and Git History").disabled(model.path == nil)
                }
            }
        }
        .alert("Folio", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .onChange(of: model.path) { _, _ in query = "" }
        .onChange(of: model.editing) { _, editing in if editing { model.finding = false } }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text(model.root?.lastPathComponent ?? "Files").font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).help(model.root?.path ?? "Files")
                Spacer(minLength: 4)
                if model.root != nil {
                    Button(action: model.refresh) { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary).help("Reload Folder")
                        .accessibilityLabel("Reload Folder")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Divider()
            if model.root == nil {
                Spacer()
                Text("Open a folder to browse its files.").font(.callout).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            } else if model.rows.isEmpty {
                Spacer()
                Text("No visible files").foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(selection: Binding(get: { model.path }, set: model.select)) {
                    ForEach(model.rows) { row in
                        if row.entry.directory {
                            Button { model.toggle(row.entry.path) } label: {
                                treeRow(row)
                            }.buttonStyle(.plain)
                                .accessibilityValue(model.expanded.contains(row.entry.path) ? "Expanded" : "Collapsed")
                        } else {
                            treeRow(row)
                                .tag(row.entry.path)
                                .contextMenu {
                                    Button("Reveal in Finder") {
                                        if let root = model.root, let url = Core.file(row.entry.path, in: root) {
                                            NSWorkspace.shared.activateFileViewerSelecting([url])
                                        }
                                    }
                                }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(.regularMaterial)
    }

    private func treeRow(_ row: ReaderModel.Row) -> some View {
        HStack(spacing: 7) {
            if row.entry.directory {
                Image(systemName: model.expanded.contains(row.entry.path) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary).frame(width: 10)
                    .accessibilityHidden(true)
            } else {
                Color.clear.frame(width: 10, height: 1)
            }
            Image(systemName: row.entry.directory ? "folder" : (row.entry.kind ?? .other).icon)
                .frame(width: 15).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(row.entry.name).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(min(12, row.depth) * 12))
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .help(row.entry.path)
    }

    private var reading: some View {
        VStack(spacing: 0) {
            if model.finding, model.document?.preview != nil, !model.editing {
                HStack(spacing: 8) {
                    TextField("Find in document", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .focused($findFocus)
                        .onSubmit { model.web?.find(query) }
                        .onAppear { findFocus = true }
                    Button { model.web?.find(query, backwards: true) } label: {
                        Label("Previous Match", systemImage: "chevron.up").labelStyle(.iconOnly)
                    }.disabled(query.isEmpty)
                    Button { model.web?.find(query) } label: {
                        Label("Next Match", systemImage: "chevron.down").labelStyle(.iconOnly)
                    }.disabled(query.isEmpty)
                    Button("Done") { model.finding = false }
                }
                .padding(9).background(.bar).onExitCommand { model.finding = false }
                Divider()
            }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        if model.loading {
            ProgressView("Opening \(model.title)…").controlSize(.small)
        } else if let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t open this file", systemImage: "exclamationmark.circle")
            } description: { Text(error) } actions: {
                Button("Reload from Disk", action: model.refresh)
            }
        } else if model.editing {
            SourceEditor(text: $model.draft)
        } else if let document = model.document, let root = model.root,
                  let path = model.path, let file = model.file {
            if let preview = document.preview {
                ReaderWeb(model: model, root: root, path: path, html: preview.html, appearance: model.appearance)
            } else {
                NativePreview(file: file, kind: document.kind, bytes: document.bytes)
                    .id(file)
            }
        } else if model.root != nil {
            ContentUnavailableView("Select a file", systemImage: "doc.text.magnifyingglass",
                                   description: Text("Choose a document or media file in the sidebar."))
        } else {
            ContentUnavailableView {
                Label("Open a file or folder", systemImage: "book")
            } description: {
                Text("Read documents and browse their neighboring files.")
            } actions: {
                Button("Open…", action: model.choose).buttonStyle(.borderedProminent)
            }
        }
    }
}
