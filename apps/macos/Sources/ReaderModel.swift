import AppKit
import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case system, light, paper, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct Appearance: Equatable {
    var theme: Theme = .system
    var size = 18.0
    var width = 700.0
    var serif = true

    init() {
        let defaults = UserDefaults.standard
        theme = Theme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        size = defaults.object(forKey: "textSize") as? Double ?? 18
        width = defaults.object(forKey: "readerWidth") as? Double ?? 700
        serif = defaults.object(forKey: "serif") as? Bool ?? true
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(size, forKey: "textSize")
        defaults.set(width, forKey: "readerWidth")
        defaults.set(serif, forKey: "serif")
    }
}

@MainActor
final class ReaderModel: ObservableObject {
    struct Row: Identifiable {
        let entry: Entry
        let depth: Int
        var id: String { entry.id }
    }

    @Published private(set) var root: URL?
    @Published private(set) var path: String?
    @Published private(set) var document: Document?
    @Published private(set) var loading = false
    @Published private(set) var entries: [String: [Entry]] = [:]
    @Published private(set) var expanded: Set<String> = []
    @Published private(set) var editing = false
    @Published var draft = ""
    @Published var error: String?
    @Published var loadError: String?
    @Published var sidebar = true
    @Published var inspector = false
    @Published var finding = false
    @Published var appearance = Appearance() { didSet { appearance.persist() } }

    var web: ReaderWeb.Coordinator?
    private var token = UUID()

    var dirty: Bool { editing && (document?.source ?? "") != draft }
    var file: URL? {
        guard let root, let path else { return nil }
        return Core.file(path, in: root)
    }

    var title: String {
        path.flatMap { $0.split(separator: "/").last.map(String.init) } ?? root?.lastPathComponent ?? "Folio"
    }

    var rows: [Row] {
        func descend(_ folder: String, _ depth: Int) -> [Row] {
            (entries[folder] ?? []).flatMap { entry in
                let row = Row(entry: entry, depth: depth)
                return expanded.contains(entry.path) ? [row] + descend(entry.path, depth + 1) : [row]
            }
        }
        return descend("", 0)
    }

    func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { [weak self] response in
                if response == .OK, let url = panel.url { self?.open(url) }
            }
        } else if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    func open(_ url: URL) {
        guard url.isFileURL, leaveDraft() else { return }
        do {
            let canonical = url.resolvingSymlinksInPath().standardizedFileURL
            let isFolder = try canonical.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            let directory = isFolder ? canonical : canonical.deletingLastPathComponent()
            let children: [Entry] = try Core.request("list", root: directory, path: "") ?? []
            token = UUID()
            root = directory
            entries = ["": children]
            expanded = []
            pendingFragment = nil
            path = nil
            document = nil
            loading = false
            loadError = nil
            if !isFolder {
                load(canonical.lastPathComponent)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggle(_ folder: String) {
        if expanded.remove(folder) != nil { return }
        guard let root else { return }
        do {
            entries[folder] = try Core.request("list", root: root, path: folder) ?? []
            expanded.insert(folder)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func select(_ item: String?) {
        guard let item, path != item, leaveDraft() else { return }
        pendingFragment = nil
        load(item)
    }

    func refresh() {
        guard let root, leaveDraft() else { return }
        do {
            entries[""] = try Core.request("list", root: root, path: "") as [Entry]?
            for folder in expanded {
                entries[folder] = try Core.request("list", root: root, path: folder) as [Entry]?
            }
        } catch {
            self.error = error.localizedDescription
        }
        if let path { load(path) }
    }

    private func load(_ item: String) {
        guard let root else { return }
        token = UUID()
        let current = token
        path = item
        editing = false
        draft = ""
        document = nil
        loadError = nil
        loading = true
        Task {
            let response = await Task.detached(priority: .userInitiated) {
                Result<Document?, Error> { try Core.request("read", root: root, path: item) }
            }.value
            guard current == token else { return }
            loading = false
            switch response {
            case .success(let loaded):
                document = loaded
            case .failure(let error):
                loadError = error.localizedDescription
            }
        }
    }

    func follow(_ url: URL) {
        guard let root else { return }
        let relative = String(url.path.dropFirst())
        guard let file = Core.file(relative, in: root), FileManager.default.fileExists(atPath: file.path) else { return }
        let pieces = relative.split(separator: "/")
        var parent = ""
        for piece in pieces.dropLast() {
            parent = parent.isEmpty ? String(piece) : parent + "/" + piece
            if !expanded.contains(parent) { toggle(parent) }
        }
        if relative == path, let fragment = url.fragment {
            web?.heading(fragment.removingPercentEncoding ?? fragment)
        } else {
            guard leaveDraft() else { return }
            pendingFragment = url.fragment?.removingPercentEncoding
            load(relative)
        }
    }

    var pendingFragment: String?

    func edit() {
        guard let document, document.revision != nil, let source = document.source else { return }
        draft = source
        editing = true
    }

    @discardableResult
    func save() -> Bool {
        guard editing, let root, let path, let revision = document?.revision else { return false }
        if dirty {
            do {
                let result: String? = try Core.request("save", root: root, path: path,
                                                       values: ["revision": revision, "source": draft])
                guard result != nil else { throw CoreError(message: "The file could not be saved.") }
            } catch {
                self.error = error.localizedDescription
                return false
            }
            load(path)
        } else {
            editing = false
        }
        return true
    }

    func leaveDraft() -> Bool {
        guard dirty else {
            editing = false
            return true
        }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(title)?"
        alert.informativeText = "Discarding changes restores the version currently on disk."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let discard = alert.addButton(withTitle: "Discard Changes")
        discard.hasDestructiveAction = true
        switch alert.runModal() {
        case .alertFirstButtonReturn: return save()
        case .alertThirdButtonReturn:
            editing = false
            draft = ""
            return true
        default: return false
        }
    }

    func setSize(_ delta: Double) {
        appearance.size = min(30, max(13, appearance.size + delta))
    }
}
