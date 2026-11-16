import Foundation

struct WorkspaceColumns {
    static let dividerThickness: CGFloat = 8
    static let defaultFolders: CGFloat = 224
    static let defaultOutline: CGFloat = 192
    static let folderWidths: ClosedRange<CGFloat> = 152...420
    static let outlineWidths: ClosedRange<CGFloat> = 136...340

    let folders: CGFloat
    let content: CGFloat
    let outline: CGFloat

    init(width: CGFloat, folders: CGFloat?, outline: CGFloat?, contentTarget: CGFloat) {
        let dividerCount = [folders, outline].compactMap { $0 }.count
        let available = max(0, width - Self.dividerThickness * CGFloat(dividerCount))
        let folderMinimum = folders == nil ? 0 : Self.folderWidths.lowerBound
        let outlineMinimum = outline == nil ? 0 : Self.outlineWidths.lowerBound
        let folderExtra = folders.map { Self.clamp($0, to: Self.folderWidths) - folderMinimum } ?? 0
        let outlineExtra = outline.map { Self.clamp($0, to: Self.outlineWidths) - outlineMinimum } ?? 0
        let minimum = folderMinimum + outlineMinimum
        let extra = folderExtra + outlineExtra
        let minimumScale = minimum > 0 ? min(1, available / minimum) : 1
        let extraScale = extra > 0 ? min(1, max(0, available - minimum - contentTarget) / extra) : 0
        self.folders = folderMinimum * minimumScale + folderExtra * extraScale
        self.outline = outlineMinimum * minimumScale + outlineExtra * extraScale
        content = max(0, available - self.folders - self.outline)
    }

    static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(range.upperBound, max(range.lowerBound, value))
    }
}

enum ReaderSplitStyle {
    case workspace, sourcePreview

    enum Direction { case horizontal, vertical }

    var sideBySideWidth: CGFloat { self == .workspace ? 540 : 500 }

    func direction(for size: CGSize) -> Direction {
        let stackingHeight: CGFloat = self == .workspace ? 348 : 312
        return size.width.rounded() < sideBySideWidth && size.height >= stackingHeight ? .vertical : .horizontal
    }

    func firstLength(_ length: CGFloat, within available: CGFloat, direction: Direction) -> CGFloat {
        let preferredMinimum: CGFloat
        switch (self, direction) {
        case (.workspace, .horizontal): preferredMinimum = 265
        case (.workspace, .vertical): preferredMinimum = 170
        case (.sourcePreview, _): preferredMinimum = 125
        }
        let minimum = min(preferredMinimum, available * 0.4)
        return WorkspaceColumns.clamp(length, to: minimum...(available - minimum))
    }
}
