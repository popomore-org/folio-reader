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

    private var refreshKey: [UUID] { [refreshID, reload] }
    private var patchKey: PatchKey { PatchKey(selection: selected, refreshKey: refreshKey) }

    private struct PatchKey: Hashable {
        let selection: Selection?
        let refreshKey: [UUID]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Git").font(.headline)
                    if let branch = snapshot?.branch {
                        Label(branch, systemImage: "arrow.triangle.branch")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Picker("Git View", selection: $page) {
                    ForEach(Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 220)
                Button("Refresh Git", systemImage: "arrow.clockwise") { reload = UUID() }
                    .labelStyle(.iconOnly).help("Refresh Git")
            }
            .padding(12)
            Divider()
            if loading {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let repositoryError {
                empty("Git could not be read", repositoryError)
            } else if let snapshot {
                HSplitView {
                    gitList(snapshot)
                        .frame(minWidth: 174, idealWidth: 246, maxWidth: 330, maxHeight: .infinity)
                    patchPane
                        .frame(minWidth: 285, maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                empty("No Git repository", "The selected file or folder is outside a Git working tree.")
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: refreshKey) { await loadRepository() }
        .task(id: patchKey) { await loadPatch(selected) }
        .onChange(of: page) { _, page in chooseDefault(page) }
    }

    @ViewBuilder
    private func gitList(_ snapshot: GitChanges) -> some View {
        if page == .changes {
            if snapshot.changes.isEmpty {
                empty("Working tree clean", "There are no changes in the selected folder.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        Text("\(snapshot.total) changed \(snapshot.total == 1 ? "file" : "files")")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(6)
                        ForEach(snapshot.changes) { change in
                            let selection = Selection(path: change.path)
                            choice(selection, change.path,
                                   [change.staged.map { "Staged · \($0)" }, change.unstaged].compactMap { $0 }.joined(separator: "  ·  "))
                        }
                        if snapshot.total > snapshot.changes.count {
                            Text("Showing the first \(snapshot.changes.count) changes.")
                                .font(.caption).foregroundStyle(.secondary).padding(6)
                        }
                    }.padding(7)
                }
            }
        } else if location.path.isEmpty {
            empty("Select a file", "Open a file from the directory to view its commit history.")
        } else if let historyError {
            empty("History could not be read", historyError)
        } else if let history, !history.commits.isEmpty {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    Text(location.name).font(.caption.weight(.semibold)).padding(6)
                    ForEach(history.commits) { commit in
                        choice(Selection(path: location.path, commit: commit.id),
                               commit.summary,
                               "\(commit.id.prefix(8)) · \(commit.author) · \(commit.date.formatted(date: .abbreviated, time: .omitted))")
                    }
                    if history.limited {
                        Text("Showing recent history.").font(.caption).foregroundStyle(.secondary).padding(6)
                    }
                }.padding(7)
            }
        } else {
            empty("No commits at this path", "File History shows commits affecting the selected file.")
        }
    }

    private func choice(_ selection: Selection, _ title: String, _ detail: String) -> some View {
        Button { selected = selection } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).lineLimit(2).truncationMode(.middle)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(selected == selection ? Color.accentColor.opacity(0.13) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected == selection ? .isSelected : [])
        .help(title)
    }

    @ViewBuilder
    private var patchPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selected {
                Text(selected.path).font(.callout.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                    .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                Divider()
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
