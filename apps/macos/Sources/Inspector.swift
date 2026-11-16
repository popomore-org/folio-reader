import SwiftUI

struct Inspector: View {
    let tab: ReaderTab?
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outline").font(.callout.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .workspaceHeader()
            if let tab {
                TabOutline(tab: tab, compact: width < 170)
            } else {
                Text("No headings").foregroundStyle(.secondary).padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkspaceStyle.surface)
    }
}

private struct TabOutline: View {
    @ObservedObject var tab: ReaderTab
    let compact: Bool

    var body: some View {
        let headings = tab.preview?.headings ?? []
        if headings.isEmpty {
            Text("No headings in this file.").font(.callout).foregroundStyle(.secondary).padding(12)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(headings) { heading in
                        Button {
                            tab.web?.heading(heading.id)
                        } label: {
                            Text(heading.title)
                                .font(.system(size: 12, weight: heading.level <= 2 ? .medium : .regular))
                                .lineLimit(compact ? 3 : 2).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, CGFloat(max(0, heading.level - 1)) * (compact ? 5 : 9))
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain).help(heading.title).disabled(tab.mode == .source || tab.previewError != nil)
                    }
                }.padding(11)
            }
        }
    }
}
