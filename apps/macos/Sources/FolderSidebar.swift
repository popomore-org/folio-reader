import AppKit
import SwiftUI

struct FolderSidebar: View {
    @ObservedObject var model: ReaderModel

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
            .padding(.horizontal, 12).frame(height: 33)
            Divider()
            if model.folders.isEmpty {
                Text("Add a folder to browse its files.")
                    .font(.callout).foregroundStyle(.secondary).padding(12)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(rows) { item in
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
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                }
                .accessibilityLabel("Folder Tree")
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
            model.toggleFolder(root: item.folder.url, path: item.path)
        } label: {
            row(depth: item.depth, disclosure: expanded) {
                Image(systemName: expanded ? "folder.fill" : "folder")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(item.title).fontWeight(item.path.isEmpty ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
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
            .background(selected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : .clear,
                        in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
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

    var body: some View {
        Menu("Open With") {
            let workspace = NSWorkspace.shared
            let defaultApplication = workspace.urlForApplication(toOpen: file)
            let candidates = workspace.urlsForApplications(toOpen: file).filter { $0 != Bundle.main.bundleURL }
            ForEach(candidates, id: \.self) { application in
                Button(application.deletingPathExtension().lastPathComponent + (application == defaultApplication ? " (Default)" : "")) {
                    model.openExternally(file, application: application)
                }
            }
            Button("Other Application…") { model.chooseApplication(for: file) }
        }
    }
}
