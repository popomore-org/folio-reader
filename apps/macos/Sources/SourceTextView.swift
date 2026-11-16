import AppKit

struct SourceEditorStyle {
    let theme: FolioTheme

    var background: NSColor { color("background", fallback: .textBackgroundColor) }
    var foreground: NSColor { color("foreground", fallback: .textColor) }
    var lineNumber: NSColor { color("line-number", fallback: .secondaryLabelColor) }
    var activeLineNumber: NSColor { color("active-line-number", fallback: .controlAccentColor) }
    var activeLine: NSColor { color("active-line", fallback: .quaternaryLabelColor) }
    var cursor: NSColor { color("cursor", fallback: .textColor) }
    var selection: NSColor { color("selection", fallback: .selectedTextBackgroundColor) }

    static func font(size: CGFloat) -> NSFont {
        NSFont(name: "JetBrainsMonoNF-Regular", size: size)
            ?? NSFont(name: "JetBrainsMono-Regular", size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func color(for token: SourceHighlight.Token) -> NSColor {
        theme["editor-syntax"][token.rawValue]?.nsColor ?? foreground
    }

    private func color(_ key: String, fallback: NSColor) -> NSColor {
        theme["editor"][key]?.nsColor ?? fallback
    }
}

@MainActor
final class SourceTextView: NSTextView {
    private(set) var style = SourceEditorStyle(theme: .system)

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

    func applyStyle(_ theme: FolioTheme) {
        style = SourceEditorStyle(theme: theme)
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
