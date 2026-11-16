import AppKit
import SwiftUI

enum WorkspaceStyle {
    static let navigationTextSize: CGFloat = 13
    static let detailTextSize: CGFloat = 12

    static let surface = adaptive(0xF3F5F8, 0x1D2129)
    static let line = adaptive(0xD9DEE6, 0x353D4B)
    static let selection = adaptive(0xDFE6F0, 0x303B4C)
    static let hover = adaptive(0xE8ECF2, 0x282F3C)
    static let focus = adaptive(0x44669B, 0x9CB7EE)

    static let secondaryText = adaptive(srgb(0x646D79), .secondaryLabelColor)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        adaptive(srgb(light), srgb(dark))
    }

    private static func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    static func srgb(_ value: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
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
