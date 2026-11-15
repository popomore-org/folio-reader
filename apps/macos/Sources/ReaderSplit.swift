import AppKit
import SwiftUI

struct ReaderSplit<Left: View, Right: View>: View {
    let isSplit: Bool
    var minimumPaneWidth: CGFloat = 265
    @ViewBuilder let left: Left
    @ViewBuilder let right: Right

    @State private var fraction: CGFloat = 0.5
    @GestureState private var dragOffset: CGFloat = 0

    private let dividerWidth: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let usableWidth = max(0, geometry.size.width - (isSplit ? dividerWidth : 0))
            let leftBase = clamped(usableWidth * fraction, within: usableWidth)
            let leftWidth = isSplit ? clamped(leftBase + dragOffset, within: usableWidth) : usableWidth
            HStack(spacing: 0) {
                left.frame(width: leftWidth, height: geometry.size.height)
                if isSplit {
                    divider(usableWidth: usableWidth, leftWidth: leftWidth)
                    right.frame(width: usableWidth - leftWidth, height: geometry.size.height)
                }
            }
        }
        .frame(minWidth: isSplit ? minimumPaneWidth * 2 + dividerWidth : minimumPaneWidth,
               maxWidth: .infinity, maxHeight: .infinity)
    }

    private func divider(usableWidth: CGFloat, leftWidth: CGFloat) -> some View {
        Rectangle()
            .fill(dragOffset == 0 ? WorkspaceStyle.line : WorkspaceStyle.focus)
            .frame(width: 1)
            .frame(width: dividerWidth)
            .background(WorkspaceStyle.surface)
            .background(ResizeCursor())
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .updating($dragOffset) { value, offset, _ in offset = value.translation.width }
                .onEnded { value in resize(by: value.translation.width, within: usableWidth) })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Resize Reading Panes")
            .accessibilityValue("\(usableWidth == 0 ? 50 : Int((leftWidth / usableWidth * 100).rounded()))% left")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: resize(by: 24, within: usableWidth)
                case .decrement: resize(by: -24, within: usableWidth)
                @unknown default: break
                }
            }
    }

    private func clamped(_ width: CGFloat, within available: CGFloat) -> CGFloat {
        let minimum = min(minimumPaneWidth, available / 2)
        return min(max(width, minimum), available - minimum)
    }

    private func resize(by offset: CGFloat, within width: CGFloat) {
        guard width > 0 else { return }
        fraction = clamped(clamped(width * fraction, within: width) + offset, within: width) / width
    }
}

private struct ResizeCursor: NSViewRepresentable {
    func makeNSView(context: Context) -> CursorView { CursorView() }
    func updateNSView(_ view: CursorView, context: Context) {}

    final class CursorView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
