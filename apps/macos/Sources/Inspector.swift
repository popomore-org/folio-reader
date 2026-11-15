import SwiftUI

struct Inspector: View {
    let tab: ReaderTab?

    var body: some View {
        if let tab {
            TabOutline(tab: tab)
        } else {
            OutlineSurface(rows: [], disabled: true, message: "No headings") { _ in }
        }
    }
}

private struct TabOutline: View {
    @ObservedObject var tab: ReaderTab

    var body: some View {
        OutlineSurface(
            rows: (tab.document?.preview?.headings ?? []).map {
                OutlineSurface.Row(id: $0.id, title: $0.title, depth: max(0, $0.level - 1))
            },
            disabled: tab.editing,
            message: "No headings in this file."
        ) { tab.web?.heading($0) }
    }
}

private struct OutlineSurface: View {
    struct Row: Encodable, Equatable {
        let id: String
        let title: String
        let depth: Int
    }

    struct State: Encodable, Equatable {
        let dark: Bool
        let title = "Outline"
        let rows: [Row]
        let disabled: Bool
        let details: String
    }

    let rows: [Row]
    let disabled: Bool
    let message: String
    let jump: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NativeShellSurface(region: .outline, state: State(dark: colorScheme == .dark, rows: rows,
                                                           disabled: disabled, details: message)) { action, _ in
            if action.name == "heading", let id = action.id, !disabled { jump(id) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkspaceStyle.surface)
        .accessibilityLabel("Outline")
    }
}
