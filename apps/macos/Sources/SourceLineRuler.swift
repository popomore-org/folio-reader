import AppKit

@MainActor
final class SourceLineRuler: NSRulerView {
    private weak var editor: NSTextView?
    private var lineStarts = [0]
    private let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor.secondaryLabelColor,
    ]

    init(scrollView: NSScrollView, editor: NSTextView) {
        self.editor = editor
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clipsToBounds = true
        clientView = editor
        setAccessibilityElement(false)
        refreshLineStarts()
    }

    required init(coder: NSCoder) {
        fatalError("SourceLineRuler is created alongside its editor.")
    }

    func refreshLineStarts() {
        guard let editor else { return }
        let text = editor.string as NSString
        lineStarts.removeAll(keepingCapacity: true)
        lineStarts.append(0)
        var end = 0
        while end < text.length {
            var contentsEnd = end
            text.getLineStart(nil, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: end, length: 0))
            if contentsEnd < end { lineStarts.append(end) }
        }
        let width = (String(lineStarts.count) as NSString).size(withAttributes: labelAttributes).width
        let thickness = max(41, ceil(width) + 18)
        if ruleThickness != thickness { ruleThickness = thickness }
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let editor, let layout = editor.layoutManager, let container = editor.textContainer else { return }
        let dirty = rect.intersection(bounds)
        editor.backgroundColor.setFill()
        dirty.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: dirty.minY, width: 1, height: dirty.height).fill()

        let origin = editor.textContainerOrigin
        let visible = editor.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)
        layout.enumerateLineFragments(forGlyphRange: glyphs) { fragment, _, _, range, _ in
            let offset = layout.characterIndexForGlyph(at: range.location)
            // A soft wrap has a layout fragment but no entry in lineStarts.
            if let number = self.lineNumber(at: offset) {
                self.drawNumber(number, at: origin.y + fragment.midY, from: editor)
            }
        }
        if lineStarts.last == layout.textStorage?.length,
           layout.extraLineFragmentTextContainer === container,
           layout.extraLineFragmentRect.intersects(visible) {
            drawNumber(lineStarts.count, at: origin.y + layout.extraLineFragmentRect.midY, from: editor)
        }
    }

    private func drawNumber(_ number: Int, at editorY: CGFloat, from editor: NSTextView) {
        let label = String(number) as NSString
        let size = label.size(withAttributes: labelAttributes)
        let y = convert(NSPoint(x: 0, y: editorY), from: editor).y
        label.draw(at: NSPoint(x: bounds.maxX - size.width - 9, y: y - size.height / 2),
                   withAttributes: labelAttributes)
    }

    private func lineNumber(at offset: Int) -> Int? {
        var low = 0
        var high = lineStarts.count
        while low < high {
            let middle = (low + high) / 2
            if lineStarts[middle] < offset {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low < lineStarts.count && lineStarts[low] == offset ? low + 1 : nil
    }
}
