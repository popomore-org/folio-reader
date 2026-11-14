import SwiftUI

struct GitChanges: Decodable {
    struct Change: Decodable, Identifiable {
        let path: String
        let staged: String?
        let unstaged: String?
        var id: String { path }
    }

    let branch: String
    let changes: [Change]
    let total: Int
}

struct GitView: View {
    enum Page: String, CaseIterable {
        case changes = "Changes"
        case history = "File History"
    }

    struct Selection: Hashable {
        let path: String
        var commit: String?
    }

    let location: FileLocation
    let refreshID: UUID
    @State private var page: Page = .changes
    @State private var snapshot: GitChanges?
    @State private var history: History?
    @State private var historyError: String?
    @State private var repositoryError: String?
    @State private var loading = true
    @State private var selected: Selection?
    @State private var patch: Patch?
    @State private var patchError: String?
    @State private var fetchingPatch = false
    @State private var reload = UUID()

    private var historyHeight: CGFloat {
        guard let history, !history.commits.isEmpty else { return 105 }
        let rows = min(history.commits.count, 7)
        return CGFloat(31 + 25 * rows + (history.limited && rows < 7 ? 26 : 0))
    }

    private var refreshKey: [UUID] { [refreshID, reload] }
    private var patchKey: PatchKey { PatchKey(selection: selected, refreshKey: refreshKey) }

    private struct PatchKey: Hashable {
        let selection: Selection?
        let refreshKey: [UUID]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 1) {
                ForEach(Page.allCases, id: \.self) { item in
                    let title = item == .changes && snapshot != nil ? "Changes (\(snapshot?.total ?? 0))" : item.rawValue
                    Button { page = item } label: {
                        Text(title)
                            .font(.system(size: 12, weight: page == item ? .semibold : .regular))
                            .padding(.horizontal, 9)
                            .frame(height: 25)
                    }
                    .buttonStyle(WorkspaceButton(selected: page == item))
                    .accessibilityAddTraits(page == item ? .isSelected : [])
                }
                Spacer(minLength: 8)
                if let branch = snapshot?.branch {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .lineLimit(1).truncationMode(.middle)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Button { reload = UUID() } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 25, height: 25)
                }
                .buttonStyle(WorkspaceButton())
                .accessibilityLabel("Refresh Git")
                .help("Refresh Git")
            }
            .padding(.horizontal, 7)
            .frame(height: 34)
            WorkspaceRule()
            if loading {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let repositoryError {
                empty("Git could not be read", repositoryError)
            } else if let snapshot {
                VStack(spacing: 0) {
                    if page == .history {
                        ViewThatFits(in: .horizontal) {
                            historyTable(showAuthor: true).frame(minWidth: 640)
                            historyTable(showAuthor: false)
                        }
                        .frame(height: historyHeight)
                        WorkspaceRule()
                        patchPane
                    } else {
                        HSplitView {
                            changeList(snapshot)
                                .frame(minWidth: 180, idealWidth: 250, maxWidth: 330, maxHeight: .infinity)
                            patchPane
                                .frame(minWidth: 285, maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            } else {
                empty("No Git repository", "The selected file or folder is outside a Git working tree.")
            }
        }
        .background(WorkspaceStyle.surface)
        .task(id: refreshKey) { await loadRepository() }
        .task(id: patchKey) { await loadPatch(selected) }
        .onChange(of: page) { _, page in chooseDefault(page) }
    }

    @ViewBuilder
    private func changeList(_ snapshot: GitChanges) -> some View {
        if snapshot.changes.isEmpty {
            empty("Working tree clean", "There are no changes in the selected folder.")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(snapshot.changes) { change in
                        let target = Selection(path: change.path)
                        Button { selected = target } label: {
                            HStack(spacing: 8) {
                                Image(systemName: statusIcon(change.unstaged ?? change.staged))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(statusColor(change.unstaged ?? change.staged))
                                    .frame(width: 14)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(change.path).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                                    Text([change.staged.map { "Staged · \($0)" }, change.unstaged].compactMap { $0 }.joined(separator: "  ·  "))
                                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 7).padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(WorkspaceButton(selected: selected == target))
                        .accessibilityAddTraits(selected == target ? .isSelected : [])
                        .help(change.path)
                    }
                    if snapshot.total > snapshot.changes.count {
                        Text("Showing the first \(snapshot.changes.count) changes.")
                            .font(.caption).foregroundStyle(.secondary).padding(6)
                    }
                }.padding(6)
            }
        }
    }

    @ViewBuilder
    private func historyTable(showAuthor: Bool) -> some View {
        if location.path.isEmpty {
            empty("Select a file", "Open a file from the directory to view its commit history.")
        } else if let historyError {
            empty("History could not be read", historyError)
        } else if let history, !history.commits.isEmpty {
            VStack(spacing: 0) {
                historyRow(summary: "Summary", author: "Author", date: "Date", sha: "Commit", showAuthor: showAuthor)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 4)
                WorkspaceRule()
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(history.commits) { commit in
                            let target = Selection(path: location.path, commit: commit.id)
                            Button { selected = target } label: {
                                historyRow(summary: commit.summary, author: commit.author,
                                           date: commit.date.formatted(date: .abbreviated, time: .omitted),
                                           sha: String(commit.id.prefix(8)), showAuthor: showAuthor)
                            }
                            .buttonStyle(WorkspaceButton(selected: selected == target))
                            .accessibilityAddTraits(selected == target ? .isSelected : [])
                            .help("\(commit.summary) · \(commit.author)")
                        }
                        if history.limited {
                            Text("Showing recent history.").font(.caption).foregroundStyle(.secondary).padding(6)
                        }
                    }.padding(.horizontal, 4).padding(.vertical, 3)
                }
            }
        } else {
            empty("No commits at this path", "File History shows commits affecting the selected file.")
        }
    }

    private func historyRow(summary: String, author: String, date: String, sha: String, showAuthor: Bool) -> some View {
        HStack(spacing: 9) {
            Text(summary).frame(maxWidth: .infinity, alignment: .leading)
            if showAuthor { Text(author).foregroundStyle(.secondary).frame(width: 116, alignment: .leading) }
            Text(date).foregroundStyle(.secondary).frame(width: 86, alignment: .leading)
            Text(sha).monospaced().foregroundStyle(.secondary).frame(width: 67, alignment: .leading)
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .contentShape(Rectangle())
    }

    private func statusIcon(_ status: String?) -> String {
        switch status {
        case "Added", "Untracked": "plus.square"
        case "Deleted": "minus.square"
        case "Conflict": "exclamationmark.square"
        default: "square.and.pencil"
        }
    }

    private func statusColor(_ status: String?) -> Color {
        switch status {
        case "Added", "Untracked": .green
        case "Deleted": .red
        case "Conflict": .orange
        default: WorkspaceStyle.focus
        }
    }

    @ViewBuilder
    private var patchPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selected {
                Label(selected.path, systemImage: "doc.text")
                    .font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                    .padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                    .background(WorkspaceStyle.surface)
                WorkspaceRule()
                if fetchingPatch {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let patchError {
                    empty("Patch could not be read", patchError)
                } else if let patch, !patch.text.isEmpty {
                    PatchText(patch: patch).id(patchKey)
                    if patch.truncated {
                        Text("Patch preview truncated.").font(.caption).foregroundStyle(.secondary).padding(9)
                    }
                } else {
                    empty("No patch", "There is no text patch for this selection.")
                }
            } else {
                empty("No patch selected", "Choose a change or commit to inspect its patch.")
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func empty(_ title: String, _ message: String) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.callout.weight(.semibold))
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chooseDefault(_ page: Page) {
        if page == .changes {
            let changes = snapshot?.changes ?? []
            selected = (changes.first { $0.path == location.path } ?? changes.first).map { Selection(path: $0.path) }
        } else {
            selected = history?.commits.first.map { Selection(path: location.path, commit: $0.id) }
        }
    }

    private func loadRepository() async {
        loading = true
        repositoryError = nil
        historyError = nil
        let location = location
        let result = await Task.detached(priority: .utility) {
            Result<GitChanges?, Error> { try Core.request("changes", root: location.root, path: location.path) }
        }.value
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let snapshot):
            self.snapshot = snapshot
            if snapshot != nil, !location.path.isEmpty {
                let response = await Task.detached(priority: .utility) {
                    Result<History?, Error> { try Core.request("git", root: location.root, path: location.path) }
                }.value
                guard !Task.isCancelled else { return }
                switch response {
                case .success(let history): self.history = history
                case .failure(let error): historyError = error.localizedDescription
                }
            }
            if selected == nil || !selectionExists { chooseDefault(page) }
        case .failure(let error):
            repositoryError = error.localizedDescription
        }
        loading = false
    }

    private var selectionExists: Bool {
        if page == .changes { return snapshot?.changes.contains { $0.path == selected?.path } == true }
        return history?.commits.contains { $0.id == selected?.commit } == true
    }

    private func loadPatch(_ selection: Selection?) async {
        patch = nil
        patchError = nil
        fetchingPatch = selection != nil
        guard let selection else { return }
        let root = location.root
        let parameters = selection.commit.map { ["commit": $0] } ?? [:]
        let result = await Task.detached(priority: .userInitiated) {
            Result<Patch?, Error> { try Core.request("patch", root: root, path: selection.path, values: parameters) }
        }.value
        guard !Task.isCancelled else { return }
        fetchingPatch = false
        switch result {
        case .success(let patch): self.patch = patch
        case .failure(let error): patchError = error.localizedDescription
        }
    }
}

private struct PatchText: NSViewRepresentable {
    let patch: Patch

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let text = scroll.documentView as? NSTextView else { return scroll }
        text.isEditable = false
        text.isSelectable = true
        text.textContainerInset = NSSize(width: 12, height: 12)
        text.isHorizontallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = false
        text.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scroll.hasHorizontalScroller = true
        let result = NSMutableAttributedString()
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        for line in patch.text.split(separator: "\n", omittingEmptySubsequences: false) {
            let color: NSColor
            if line.hasPrefix("@@") { color = .secondaryLabelColor }
            else if line.hasPrefix("+") && !line.hasPrefix("+++") { color = .systemGreen }
            else if line.hasPrefix("-") && !line.hasPrefix("---") { color = .systemRed }
            else { color = .labelColor }
            result.append(NSAttributedString(string: String(line) + "\n", attributes: [.font: font, .foregroundColor: color]))
        }
        text.textStorage?.setAttributedString(result)
        text.setAccessibilityLabel("Git Patch")
        return scroll
    }

    func updateNSView(_ view: NSScrollView, context: Context) {
        // The patch view is keyed by selection and reload request.
    }
}
