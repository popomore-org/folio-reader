import Foundation

enum ThemeMode: String, CaseIterable, Sendable {
    case light, dark

    var filename: String { "folio-" + legacyFilename }
    var legacyFilename: String { rawValue + ".json" }
}

struct ThemeColor: Decodable, Equatable, Sendable {
    let hex: String
    let rgba: UInt32

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        let hex = try value.decode(String.self)
        let digits = hex.utf8.dropFirst()
        guard hex.utf8.first == 35, [6, 8].contains(digits.count),
              digits.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              let parsed = UInt32(hex.dropFirst(), radix: 16) else {
            let field = decoder.codingPath.map(\.stringValue).joined(separator: ".")
            throw CoreError(message: "\(field) must use #RRGGBB or #RRGGBBAA.")
        }
        self.hex = hex.lowercased()
        rgba = digits.count == 6 ? (parsed << 8) | 0xff : parsed
    }
}

struct FolioTheme: Equatable, Sendable {
    typealias Palette = [String: ThemeColor]

    private static let syntaxKeys = Set(["comment", "keyword", "string", "constant", "type", "function", "tag", "added", "removed"])
    private static let keys: [String: Set<String>] = [
        "workspace": ["surface", "line", "selection", "hover", "focus", "secondary-text"],
        "editor": ["background", "foreground", "line-number", "active-line-number", "active-line", "cursor", "selection"],
        "editor-syntax": syntaxKeys,
        "reader": ["paper", "ink", "muted", "line", "line-muted", "inset", "inline-code", "link"],
        "reader-syntax": syntaxKeys,
    ]
    private let palettes: [String: Palette]

    static let system = FolioTheme(palettes: [:])

    subscript(_ group: String) -> Palette { palettes[group] ?? [:] }

    var readerVariables: [String: String] {
        var variables: [String: String] = [:]
        for (key, color) in self["reader"] { variables["--" + key] = color.hex }
        for (key, color) in self["reader-syntax"] { variables["--syntax-" + key] = color.hex }
        return variables
    }

    var readerDeclarations: String {
        readerVariables.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value);" }.joined()
    }

    static func bundledURL(for mode: ThemeMode, in bundle: Bundle) throws -> URL {
        guard let url = bundle.url(forResource: mode.filename, withExtension: nil, subdirectory: "Themes") else {
            throw CoreError(message: "The bundled \(mode.filename) is missing.")
        }
        return url
    }

    static func read(_ url: URL, over fallback: FolioTheme? = nil) throws -> FolioTheme {
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw CoreError(message: "Choose a regular JSON file.")
        }
        let limit = 64 * 1024
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw CoreError(message: "Theme files may be up to 64 KiB.") }
        let overrides = try JSONDecoder().decode([String: Palette].self, from: data)
        var palettes = fallback?.palettes ?? [:]
        for (group, colors) in overrides {
            guard let allowed = keys[group] else { throw CoreError(message: "Unknown theme section \(group).") }
            if let unknown = colors.keys.sorted().first(where: { !allowed.contains($0) }) {
                throw CoreError(message: "Unknown theme color \(group).\(unknown).")
            }
            palettes[group, default: [:]].merge(colors) { _, new in new }
        }
        for (group, required) in keys {
            if let missing = required.sorted().first(where: { palettes[group]?[$0] == nil }) {
                throw CoreError(message: "Missing theme color \(group).\(missing).")
            }
        }
        return FolioTheme(palettes: palettes)
    }
}
