import AppKit
import SwiftUI

struct FolderSidebar: View {
    @ObservedObject var model: ReaderModel
    @State private var keyboardFocus = false
    @State private var cursor: FileLocation?

    private struct Row: Identifiable {
        let folder: ReaderModel.Folder
        let path: String
        let title: String
        let depth: Int
        var kind: FileKind?
        var directory = false
        var message = false

        var id: FileLocation { FileLocation(root: folder.url, path: path) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Folders").font(.callout.weight(.semibold))
                Spacer()
                Button("Add Folders", systemImage: "plus") { model.choose(foldersOnly: true) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Add Folders")
            }
            .padding(.horizontal, 12)
            .workspaceHeader()
            if model.folders.isEmpty {
                Text("Add a folder to browse its files.")
                    .font(.callout).foregroundStyle(.secondary).padding(12)
                Spacer()
            } else {
                let visibleRows = rows
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(visibleRows) { item in
                                rowView(item).id(item.id)
                            }
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 6)
                    }
                    .background {
                        FolderKeyTarget(request: model.folderTreeFocus, focused: $keyboardFocus) {
                            handleKey($0, rows: visibleRows)
                        }
                        .frame(width: 0, height: 0)
                    }
                    .onChange(of: model.active?.location, initial: true) { _, location in
                        if let location { cursor = location; proxy.scrollTo(location) }
                    }
                    .onChange(of: model.folderTreeFocus, initial: true) { _, request in
                        guard request != nil else { return }
                        cursor = visibleRows.first { $0.id == model.active?.location }?.id ?? visibleRows.first?.id
                    }
                    .onChange(of: cursor) { _, row in
                        if let row, keyboardFocus { proxy.scrollTo(row) }
                    }
                    .accessibilityLabel("Folder Tree")
                }
            }
        }
        .background(WorkspaceStyle.surface)
    }

    @ViewBuilder
    private func rowView(_ item: Row) -> some View {
        if item.message {
            Text(item.title)
                .font(.caption).foregroundStyle(.secondary)
                .padding(.leading, 21 + CGFloat(min(item.depth, 10) * 12))
                .padding(.vertical, 3)
        } else if item.directory {
            directory(item)
        } else {
            file(item)
        }
    }

    private func handleKey(_ key: KeyEquivalent, rows: [Row]) -> Bool {
        let items = rows.filter { !$0.message }
        guard let first = items.first else { return false }
        guard let index = items.firstIndex(where: { $0.id == cursor }) else {
            cursor = first.id
            return true
        }
        let item = items[index]
        let expanded = item.directory && item.folder.expanded.contains(item.path)
        switch key {
        case .upArrow:
            cursor = items[max(0, index - 1)].id
        case .downArrow:
            cursor = items[min(items.count - 1, index + 1)].id
        case .rightArrow:
            if item.directory && !expanded { toggle(item) }
            else if expanded, index + 1 < items.count, items[index + 1].depth > item.depth {
                cursor = items[index + 1].id
            }
        case .leftArrow:
            if expanded { toggle(item) }
            else if item.depth > 0, let parent = items[..<index].last(where: { $0.depth == item.depth - 1 }) {
                cursor = parent.id
            }
        case .return, .space:
            if item.directory { toggle(item) } else { model.open(item.id) }
        default:
            return false
        }
        return true
    }

    private func toggle(_ item: Row) {
        cursor = item.id
        model.toggleFolder(root: item.folder.url, path: item.path)
    }

    private func cursorBorder(_ item: Row) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(keyboardFocus && cursor == item.id ? WorkspaceStyle.focus : .clear)
            .allowsHitTesting(false)
    }

    private var rows: [Row] {
        var result: [Row] = []
        func append(_ folder: ReaderModel.Folder, path: String, title: String, depth: Int) {
            result.append(Row(folder: folder, path: path, title: title, depth: depth, directory: true))
            guard folder.expanded.contains(path) else { return }
            let entries = folder.entries[path] ?? []
            if let message = folder.failures[path] ?? (entries.isEmpty ? "No visible files" : nil) {
                result.append(Row(folder: folder, path: path + "/.", title: message, depth: depth + 1, message: true))
            }
            for entry in entries {
                if entry.directory {
                    append(folder, path: entry.path, title: entry.name, depth: depth + 1)
                } else {
                    result.append(Row(folder: folder, path: entry.path, title: entry.name, depth: depth + 1, kind: entry.kind))
                }
            }
        }
        for folder in model.folders { append(folder, path: "", title: folder.name, depth: 0) }
        return result
    }

    private func directory(_ item: Row) -> some View {
        let expanded = item.folder.expanded.contains(item.path)
        return Button {
            toggle(item)
        } label: {
            row(depth: item.depth, disclosure: expanded) {
                Image(systemName: expanded ? "folder.fill" : "folder")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(item.title).fontWeight(item.path.isEmpty ? .semibold : .regular)
            }
        }
        .buttonStyle(WorkspaceButton())
        .overlay { cursorBorder(item) }
        .accessibilityLabel(item.title)
        .accessibilityValue(expanded ? "Expanded" : "Collapsed")
        .help(item.path.isEmpty ? item.folder.url.path : item.path)
        .contextMenu {
            if item.path.isEmpty {
                Button("Reload Folder") { model.refreshFolder(item.folder.url) }
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.folder.url]) }
                Divider()
                Button("Remove Folder", role: .destructive) { model.removeFolder(item.folder.url) }
            }
        }
    }

    private func file(_ item: Row) -> some View {
        let location = item.id
        let selected = model.active?.location == location
        return Button {
            cursor = item.id
            if NSEvent.modifierFlags.contains(.option) {
                model.open(location, in: model.focusedPane.other)
            } else {
                model.open(location)
            }
        } label: {
            row(depth: item.depth, disclosure: nil) {
                FileIcon(name: item.title, kind: item.kind)
                Text(item.title)
            }
        }
        .buttonStyle(WorkspaceButton(selected: selected))
        .overlay { cursorBorder(item) }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(item.path)
        .contextMenu {
            Button("Open in \(model.focusedPane.other.label) Pane") { model.open(location, in: model.focusedPane.other) }
            if let url = location.url {
                OpenWithMenu(file: url, model: model)
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        }
    }

    private func row<Content: View>(depth: Int, disclosure: Bool?, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            if let disclosure {
                Image(systemName: disclosure ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .frame(width: 9)
                    .accessibilityHidden(true)
            } else {
                Color.clear.frame(width: 9, height: 1)
            }
            content()
            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .lineLimit(1).truncationMode(.middle)
        .padding(.leading, 5 + CGFloat(min(depth, 10) * 12))
        .padding(.trailing, 4)
        .frame(minHeight: 23)
        .contentShape(Rectangle())
    }
}

private struct FolderKeyTarget: NSViewRepresentable {
    let request: UUID?
    @Binding var focused: Bool
    let handle: (KeyEquivalent) -> Bool

    func makeNSView(context: Context) -> KeyView { KeyView() }

    func updateNSView(_ view: KeyView, context: Context) {
        view.handle = handle
        view.onFocus = { active in focused = active }
        if let request, request != view.request {
            view.request = request
            DispatchQueue.main.async { [weak view] in
                guard let view, view.request == request else { return }
                view.window?.makeFirstResponder(view)
            }
        }
    }

    @MainActor
    final class KeyView: NSView {
        var request: UUID?
        var handle: ((KeyEquivalent) -> Bool)?
        var onFocus: ((Bool) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        override func becomeFirstResponder() -> Bool {
            onFocus?(true)
            return true
        }

        override func resignFirstResponder() -> Bool {
            onFocus?(false)
            return true
        }

        override func keyDown(with event: NSEvent) {
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                super.keyDown(with: event)
                return
            }
            let key: KeyEquivalent? = switch event.keyCode {
            case 123: .leftArrow
            case 124: .rightArrow
            case 125: .downArrow
            case 126: .upArrow
            case 36, 76: .return
            case 49: .space
            default: nil
            }
            if let key, handle?(key) == true { return }
            super.keyDown(with: event)
        }
    }
}

struct FileIcon: View {
    let name: String
    let kind: FileKind?

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(.secondary)
            .frame(width: 16)
            .accessibilityHidden(true)
    }

    private var symbol: String {
        let lower = name.lowercased()
        let ext = (lower as NSString).pathExtension
        if ["cargo.toml", "package.json", "makefile", "dockerfile"].contains(lower) {
            return "gearshape"
        }
        switch ext {
        case "rs", "swift", "py", "go", "java", "kt", "js", "ts", "tsx", "jsx", "sh", "zsh", "c", "h", "cpp", "css":
            return "chevron.left.forwardslash.chevron.right"
        case "toml", "yaml", "yml", "ini", "json", "xml": return "list.bullet.rectangle"
        case "zip", "gz", "tar", "rar", "7z": return "archivebox"
        case "stl", "3mf", "obj", "step": return "cube"
        case "md", "markdown", "mdown", "mkd": return "text.book.closed"
        default: return (kind ?? .other).icon
        }
    }
}

struct OpenWithMenu: View {
    let file: URL
    let model: ReaderModel
    var usesToolbarIcon = false

    var body: some View {
        Menu {
            let workspace = NSWorkspace.shared
            let defaultApplication = workspace.urlForApplication(toOpen: file)
            let candidates = workspace.urlsForApplications(toOpen: file).filter { $0 != Bundle.main.bundleURL }
            ForEach(candidates, id: \.self) { application in
                Button(application.deletingPathExtension().lastPathComponent + (application == defaultApplication ? " (Default)" : "")) {
                    model.openExternally(file, application: application)
                }
            }
            Button("Other Application…") { model.chooseApplication(for: file) }
        } label: {
            if usesToolbarIcon {
                Label("Open As", systemImage: "arrow.up.right.square")
                    .labelStyle(.iconOnly)
            } else {
                Text("Open With")
            }
        }
    }
}
