import Foundation

@main
struct WorkspaceLayoutCheck {
    static func main() {
        let split = ReaderSplitStyle.workspace
        let wide = columns(1_130, target: split.sideBySideWidth)
        precondition(wide.folders == 224 && wide.outline == 192 && wide.content == 698)

        let compact = columns(660, target: split.sideBySideWidth)
        precondition(compact.folders == 152 && compact.outline == 136 && compact.content == 356)
        precondition(split.direction(for: CGSize(width: compact.content, height: 389)) == .vertical)
        let medium = columns(930, target: split.sideBySideWidth)
        precondition(medium.content >= 539.9)
        precondition(split.direction(for: CGSize(width: medium.content, height: 389)) == .horizontal)

        let git = WorkspaceColumns(width: 660, folders: 420, outline: nil, contentTarget: 480)
        precondition(git.content == 480 && git.folders == 172 && git.outline == 0)
        let reading = WorkspaceColumns(width: 660, folders: nil, outline: nil, contentTarget: 350)
        precondition(reading.content == 660)

        let source = ReaderSplitStyle.sourcePreview
        precondition(source.direction(for: CGSize(width: 355, height: 350)) == .vertical)
        precondition(source.direction(for: CGSize(width: 355, height: 180)) == .horizontal)
        precondition(source.direction(for: CGSize(width: 510, height: 350)) == .horizontal)
        precondition(split.firstLength(900, within: 600, direction: .horizontal) == 360)
        precondition(split.firstLength(0, within: 360, direction: .vertical) == 144)
        print("Verified workspace widths, horizontal and vertical layouts, and divider limits.")
    }

    private static func columns(_ width: CGFloat, target: CGFloat) -> WorkspaceColumns {
        WorkspaceColumns(width: width, folders: 224, outline: 192, contentTarget: target)
    }
}
