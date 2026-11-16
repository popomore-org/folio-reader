import AppKit

struct SourceEditorStyle {
    let dark: Bool

    // Zed's Catppuccin Latte and Macchiato, with darker light-mode ink for small text.
    var background: NSColor { color(0xEFF1F5, 0x24273A) }
    var foreground: NSColor { color(0x4C4F69, 0xCAD3F5) }
    var lineNumber: NSColor { color(0x686C83, 0x8087A2) }
    var activeLineNumber: NSColor { color(0x7526CE, 0xC6A0F6) }
    var activeLine: NSColor { foreground.withAlphaComponent(0.07) }
    var cursor: NSColor { color(0xA25242, 0xF4DBD6) }
    var selection: NSColor { color(0x7C7F93, 0x939AB7).withAlphaComponent(dark ? 0.25 : 0.30) }

    static func font(size: CGFloat) -> NSFont {
        NSFont(name: "JetBrainsMonoNF-Regular", size: size)
            ?? NSFont(name: "JetBrainsMono-Regular", size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func color(for token: SourceHighlight.Token) -> NSColor {
        switch token {
        case .comment: color(0x62667F, 0x939AB7)
        case .keyword: color(0x7526CE, 0xC6A0F6)
        case .string, .added: color(0x2D7323, 0xA6DA95)
        case .constant: color(0xA24412, 0xF5A97F)
        case .type: color(0x855711, 0xEED49F)
        case .function, .tag: color(0x1B53C2, 0x8AADF4)
        case .removed: color(0xD20F39, 0xED8796)
        }
    }

    private func color(_ light: UInt32, _ dark: UInt32) -> NSColor {
        WorkspaceStyle.srgb(self.dark ? dark : light)
    }
}

@MainActor
final class SourceTextView: NSTextView {
    private(set) var style = SourceEditorStyle(dark: false)

    var activeLineStart: Int? {
        guard let caret else { return nil }
        return (string as NSString).lineRange(for: NSRange(location: caret, length: 0)).location
    }

    private var caret: Int? {
        let selection = selectedRange()
        guard window?.firstResponder === self, selection.length == 0,
              selection.location <= (textStorage?.length ?? 0) else { return nil }
        return selection.location
    }

    func applyStyle(dark: Bool) {
        style = SourceEditorStyle(dark: dark)
        backgroundColor = style.background
        enclosingScrollView?.backgroundColor = style.background
        textColor = style.foreground
        insertionPointColor = style.cursor
        selectedTextAttributes = [.backgroundColor: style.selection]
        refreshActiveLine()
    }

    func refreshActiveLine() {
        setNeedsDisplay(visibleRect)
        enclosingScrollView?.verticalRulerView?.needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { refreshActiveLine() }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { refreshActiveLine() }
        return accepted
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let caret, let length = textStorage?.length, let layout = layoutManager else { return }
        let fragment: NSRect
        if caret == length, layout.extraLineFragmentTextContainer === textContainer {
            fragment = layout.extraLineFragmentRect
        } else if length > 0 {
            let glyph = layout.glyphIndexForCharacter(at: min(caret, length - 1))
            fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        } else {
            return
        }
        let row = NSRect(x: bounds.minX, y: textContainerOrigin.y + fragment.minY,
                         width: bounds.width, height: fragment.height)
        style.activeLine.setFill()
        row.intersection(rect).fill()
    }
}
