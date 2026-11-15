import AppKit
import SwiftUI

struct FolderSidebar: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.colorScheme) private var colorScheme
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

    private struct TreeState: Encodable, Equatable {
        struct Item: Encodable, Equatable {
            let id: String
            let title: String
            let icon: String
            let tip: String
            let depth: Int
            let selected: Bool
            let expanded: Bool?
            let message: Bool
        }

        let dark: Bool
        let title = "Folders"
        let details = "Add a folder to browse its files."
        let cursor: String?
        let keyboardFocus: Bool
        let rows: [Item]
    }

    var body: some View {
        let visibleRows = rows
        let state = TreeState(dark: colorScheme == .dark, cursor: cursor.map(rowID), keyboardFocus: keyboardFocus, rows: visibleRows.map { row in
            let open = row.directory ? row.folder.expanded.contains(row.path) : nil
            return TreeState.Item(
                id: rowID(row.id),
                title: row.title,
                icon: open.map { $0 ? "folder.fill" : "folder" } ?? FileIcon(name: row.title, kind: row.kind).symbol,
                tip: row.path.isEmpty ? row.folder.url.path : row.path,
                depth: min(10, row.depth),
                selected: !row.directory && !row.message && model.active?.location == row.id,
                expanded: open,
                message: row.message
            )
        })
        NativeShellSurface(region: .folders, state: state) { action, view in
            if action.name == "add_folders" {
                model.choose(foldersOnly: true)
                return
            }
            guard let id = action.id, let row = visibleRows.first(where: { rowID($0.id) == id }), !row.message else { return }
            switch action.name {
            case "open_row":
                cursor = row.id
                if row.directory {
                    toggle(row)
                } else {
                    model.open(row.id, in: action.alternate ? model.focusedPane.other : model.focusedPane)
                }
            case "folder_menu":
                action.showMenu(menuItems(row), in: view)
            default: break
            }
        }
        .background(WorkspaceStyle.surface)
        .background {
            FolderKeyTarget(request: model.folderTreeFocus, focused: $keyboardFocus) {
                handleKey($0, rows: visibleRows)
            }
            .frame(width: 0, height: 0)
        }
        .onChange(of: model.active?.location, initial: true) { _, location in
            if let location { cursor = location }
        }
        .onChange(of: model.folderTreeFocus, initial: true) { _, request in
            guard request != nil else { return }
            cursor = visibleRows.first { $0.id == model.active?.location }?.id ?? visibleRows.first?.id
        }
        .accessibilityLabel("Folder Tree")
    }

    private func rowID(_ location: FileLocation) -> String {
        location.root.path + "\0" + location.path
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

    private func menuItems(_ row: Row) -> [NSMenuItem] {
        if row.directory {
            guard row.path.isEmpty else { return [] }
            let root = row.folder.url
            return [
                NativeShellMenuItem("Reload Folder") { model.refreshFolder(root) },
                NativeShellMenuItem("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([root]) },
                .separator(),
                NativeShellMenuItem("Remove Folder") { model.removeFolder(root) },
            ]
        }
        var items: [NSMenuItem] = [
            NativeShellMenuItem("Open in \(model.focusedPane.other.label) Pane") { model.open(row.id, in: model.focusedPane.other) },
        ]
        if let url = row.id.url {
            items += [
                OpenWithMenu(file: url, model: model).menuItem(),
                NativeShellMenuItem("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) },
            ]
        }
        return items
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

    var symbol: String {
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
            ForEach(candidates, id: \.url) { application in
                Button(application.name) { model.openExternally(file, application: application.url) }
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

    func menuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Open With", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for application in candidates {
            menu.addItem(NativeShellMenuItem(application.name) {
                model.openExternally(file, application: application.url)
            })
        }
        menu.addItem(NativeShellMenuItem("Other Application…") { model.chooseApplication(for: file) })
        item.submenu = menu
        return item
    }

    private var candidates: [(url: URL, name: String)] {
        let workspace = NSWorkspace.shared
        let defaultApplication = workspace.urlForApplication(toOpen: file)
        return workspace.urlsForApplications(toOpen: file).filter { $0 != Bundle.main.bundleURL }.map { application in
            let name = application.deletingPathExtension().lastPathComponent
            return (application, name + (application == defaultApplication ? " (Default)" : ""))
        }
    }
}
