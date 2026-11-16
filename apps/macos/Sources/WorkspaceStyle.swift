import AppKit
import SwiftUI

@MainActor
enum WorkspaceStyle {
    static let navigationTextSize: CGFloat = 13
    static let detailTextSize: CGFloat = 12

    static var surface: Color { adaptive("surface", fallback: .controlBackgroundColor) }
    static var line: Color { adaptive("line", fallback: .separatorColor) }
    static var selection: Color { adaptive("selection", fallback: .selectedContentBackgroundColor) }
    static var hover: Color { adaptive("hover", fallback: .quaternaryLabelColor) }
    static var focus: Color { adaptive("focus", fallback: .controlAccentColor) }
    static var secondaryText: Color { adaptive("secondary-text", fallback: .secondaryLabelColor) }

    private static func adaptive(_ key: String, fallback: NSColor) -> Color {
        let light = ThemeStore.shared[.light]["workspace"][key]?.nsColor ?? fallback
        let dark = ThemeStore.shared[.dark]["workspace"][key]?.nsColor ?? fallback
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

extension ThemeColor {
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat((rgba >> 24) & 255) / 255,
                green: CGFloat((rgba >> 16) & 255) / 255,
                blue: CGFloat((rgba >> 8) & 255) / 255,
                alpha: CGFloat(rgba & 255) / 255)
    }
}


@MainActor
enum WorkspaceIcon {
    static let folderTree = template("folder-tree", fallback: "list.bullet.indent")
    static let outline = template("lucide-list-tree", fallback: "list.bullet.indent")
    static let openAs = template("lucide-external-link", fallback: "arrow.up.right.square")

    private static func template(_ name: String, fallback: String) -> Image {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url), image.isValid else {
            return Image(systemName: fallback)
        }
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return Image(nsImage: image)
    }
}

extension View {
    func workspaceHeader() -> some View {
        frame(height: 31)
            .background(WorkspaceStyle.surface)
            .overlay(alignment: .bottom) { WorkspaceRule() }
    }
}

struct WorkspaceRule: View {
    var vertical = false

    var body: some View {
        Rectangle()
            .fill(WorkspaceStyle.line)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

struct WorkspaceButton: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, selected: selected)
    }

    private struct Face: View {
        let configuration: Configuration
        let selected: Bool
        @State private var hovered = false
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .background(background, in: RoundedRectangle(cornerRadius: 4))
                .opacity(enabled ? 1 : 0.48)
                .onHover { hovered = $0 }
        }

        private var background: Color {
            if selected || configuration.isPressed { return WorkspaceStyle.selection }
            return hovered && enabled ? WorkspaceStyle.hover : .clear
        }
    }
}
