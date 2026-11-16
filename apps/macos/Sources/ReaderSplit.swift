import AppKit
import SwiftUI

struct ReaderSplit<Left: View, Right: View>: View {
    let isSplit: Bool
    var style: ReaderSplitStyle = .workspace
    @ViewBuilder let left: Left
    @ViewBuilder let right: Right

    @State private var horizontalFraction: CGFloat = 0.5
    @State private var verticalFraction: CGFloat = 0.5
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let direction = style.direction(for: geometry.size)
            let horizontal = direction == .horizontal
            let layout = horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            let fullLength = horizontal ? geometry.size.width : geometry.size.height
            let available = max(0, fullLength - (isSplit ? WorkspaceColumns.dividerThickness : 0))
            let fraction = horizontal ? horizontalFraction : verticalFraction
            let base = style.firstLength(available * fraction, within: available, direction: direction)
            let first = isSplit ? style.firstLength(base + dragOffset, within: available, direction: direction) : available
            layout {
                left.frame(width: horizontal ? first : geometry.size.width,
                           height: horizontal ? geometry.size.height : first)
                    .clipped()
                if isSplit {
                    PaneDivider(horizontal: horizontal, label: style == .workspace ? "Resize Reading Panes" : "Resize Source and Preview",
                                value: "\(available == 0 ? 50 : Int((first / available * 100).rounded()))% \(horizontal ? "left" : "top")",
                                offset: $dragOffset) { movement in
                        guard available > 0 else { return }
                        let newFraction = style.firstLength(base + movement, within: available, direction: direction) / available
                        if horizontal { horizontalFraction = newFraction } else { verticalFraction = newFraction }
                    } reset: {
                        if horizontal { horizontalFraction = 0.5 } else { verticalFraction = 0.5 }
                    }
                    right.frame(width: horizontal ? available - first : geometry.size.width,
                                height: horizontal ? geometry.size.height : available - first)
                        .clipped()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PaneDivider: View {
    var horizontal = true
    var growsForward = true
    let label: String
    let value: String
    let offset: GestureState<CGFloat>
    let resize: (CGFloat) -> Void
    let reset: () -> Void

    var body: some View {
        Rectangle()
            .fill(offset.wrappedValue == 0 ? WorkspaceStyle.line : WorkspaceStyle.focus)
            .frame(width: horizontal ? 1 : nil, height: horizontal ? nil : 1)
            .frame(width: horizontal ? WorkspaceColumns.dividerThickness : nil,
                   height: horizontal ? nil : WorkspaceColumns.dividerThickness)
            .background(WorkspaceStyle.surface)
            .background(ResizeCursor(horizontal: horizontal))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .updating(offset) { value, state, _ in state = movement(value.translation) }
                .onEnded { value in resize(movement(value.translation)) })
            .onTapGesture(count: 2, perform: reset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: resize(24)
                case .decrement: resize(-24)
                @unknown default: break
                }
            }
            .accessibilityAction(named: Text("Reset Size"), reset)
    }

    private func movement(_ translation: CGSize) -> CGFloat {
        (horizontal ? translation.width : translation.height) * (growsForward ? 1 : -1)
    }
}

private struct ResizeCursor: NSViewRepresentable {
    let horizontal: Bool

    func makeNSView(context: Context) -> CursorView { CursorView() }
    func updateNSView(_ view: CursorView, context: Context) {
        view.cursor = horizontal ? .resizeLeftRight : .resizeUpDown
        view.window?.invalidateCursorRects(for: view)
    }

    final class CursorView: NSView {
        var cursor = NSCursor.resizeLeftRight

        override func resetCursorRects() { addCursorRect(bounds, cursor: cursor) }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
