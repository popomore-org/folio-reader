import SwiftUI

struct Inspector: View {
    enum Panel: String, CaseIterable { case outline = "Outline", history = "Git" }
    @ObservedObject var model: ReaderModel
    @State private var panel: Panel = .outline

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $panel) {
                ForEach(Panel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().padding(12)
            Divider()
            if panel == .outline {
                outline
            } else if let root = model.root, let path = model.path {
                GitPanel(root: root, path: path).id(root.path + "/" + path)
            } else {
                message("Select a file to see its Git history.")
            }
        }
        .background(.regularMaterial)
    }

    private var outline: some View {
        Group {
            let headings = model.document?.preview?.headings ?? []
            if headings.isEmpty {
                message("No headings in this file.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(headings) { heading in
                            Button {
                                model.web?.heading(heading.id)
                            } label: {
                                Text(heading.title).font(.system(size: 12, weight: heading.level <= 2 ? .medium : .regular))
                                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, CGFloat(max(0, heading.level - 1) * 9))
                                    .padding(.vertical, 5)
                            }.buttonStyle(.plain).help(heading.title).disabled(model.editing)
                        }
                    }.padding(11)
                }
            }
        }
    }
}

private struct GitPanel: View {
    let root: URL
    let path: String
    @State private var history: History?
    @State private var error: String?
    @State private var loading = true
    @State private var patch: Patch?
    @State private var selected: String?
    @State private var patchOpen = false
    @State private var patchError: String?

    var body: some View {
        Group {
            if loading {
                ProgressView().controlSize(.small).frame(maxHeight: .infinity)
            } else if let error {
                message(error)
            } else if let history {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 13) {
                        sectionTitle("Working Tree")
                        Button {
                            show(nil)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(history.unstaged ?? "No unstaged changes")
                                if let staged = history.staged {
                                    Text("Staged · \(staged)").font(.caption).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(history.staged == nil && (history.unstaged == nil || history.unstaged == "Ignored"))
                        .help("Show staged and working-tree patch")

                        Divider()
                        sectionTitle("Commits")
                        if history.commits.isEmpty { Text("No commits at this path.").foregroundStyle(.secondary) }
                        ForEach(history.commits) { commit in
                            Button {
                                show(commit)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(commit.summary).lineLimit(2)
                                    Text("\(commit.author) · \(commit.date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.help("Show patch for \(commit.summary)")
                        }
                        if history.limited { Text("Showing recent history.").font(.caption).foregroundStyle(.secondary) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.callout)
                    .padding(12)
                }
            } else {
                message("This file is outside a Git working tree.")
            }
        }
        .task { await fetch() }
        .safeAreaInset(edge: .bottom) {
            if !loading {
                HStack {
                    Spacer()
                    Button { Task { await fetch() } } label: { Label("Refresh Git", systemImage: "arrow.clockwise") }
                        .buttonStyle(.borderless).labelStyle(.iconOnly).help("Refresh Git")
                }.padding(10).background(.bar)
            }
        }
        .sheet(isPresented: $patchOpen) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(selected ?? "Working Tree").font(.headline)
                    Spacer()
                    Button("Done") { patchOpen = false }.keyboardShortcut(.cancelAction)
                }.padding(13)
                Divider()
                if let patchError {
                    message(patchError)
                } else if let patch {
                    if patch.text.isEmpty {
                        message("No patch to display.")
                    } else {
                        ScrollView([.vertical, .horizontal]) {
                            Text(patch.text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                .padding(13)
                        }
                        if patch.truncated {
                            Text("Patch preview truncated.").font(.caption).foregroundStyle(.secondary).padding(10)
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(minWidth: 600, minHeight: 350)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func fetch() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            history = try await Task.detached(priority: .utility) {
                try Core.request("git", root: root, path: path) as History?
            }.value
        } catch { self.error = error.localizedDescription }
    }

    private func show(_ commit: History.Commit?) {
        patch = nil
        patchError = nil
        selected = commit.map { "\($0.summary) (\($0.id.prefix(8)))" }
        let arguments = commit.map { ["commit": $0.id] } ?? [:]
        patchOpen = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try Core.request("patch", root: root, path: path, values: arguments) as Patch?
                }.value
                patch = result ?? Patch(text: "", truncated: false)
            } catch { patchError = error.localizedDescription }
        }

    }
}

private func message(_ content: String) -> some View {
    Text(content).font(.callout).foregroundStyle(.secondary)
        .multilineTextAlignment(.center).padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
