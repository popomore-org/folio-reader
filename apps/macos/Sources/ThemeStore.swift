import Foundation
import Observation

@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore(bundle: .main)

    let directory: URL
    private let bundle: Bundle
    private var palettes: [ThemeMode: FolioTheme] = [:]
    private(set) var problems: [String] = []

    init(bundle: Bundle, directory: URL? = nil) {
        self.bundle = bundle
        self.directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(bundle.bundleIdentifier ?? "org.popomore.folio", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)
        reload()
    }

    subscript(_ mode: ThemeMode) -> FolioTheme { palettes[mode] ?? .system }

    func reload() {
        var updated = palettes
        var failures: [String] = []
        for mode in ThemeMode.allCases {
            var filename = mode.filename
            do {
                let defaults = try FolioTheme.read(FolioTheme.bundledURL(for: mode, in: bundle))
                updated[mode] = updated[mode] ?? defaults
                if let custom = try readOverride(filename, over: defaults) {
                    updated[mode] = custom
                } else {
                    filename = mode.legacyFilename
                    updated[mode] = try readOverride(filename, over: defaults) ?? defaults
                }
            } catch {
                failures.append("\(filename) — \(error.localizedDescription)")
            }
        }
        palettes = updated
        problems = failures
    }

    func prepareDirectory() throws {
        let files = FileManager.default
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        for mode in ThemeMode.allCases {
            let destination = directory.appendingPathComponent(mode.filename)
            let legacy = directory.appendingPathComponent(mode.legacyFilename)
            do {
                do {
                    try files.moveItem(at: legacy, to: destination)
                } catch let error as NSError where Self.isMissingFile(error) {
                    try files.copyItem(at: FolioTheme.bundledURL(for: mode, in: bundle), to: destination)
                }
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                // User edits and files created by another instance take precedence.
            }
        }
    }

    private func readOverride(_ filename: String, over defaults: FolioTheme) throws -> FolioTheme? {
        do {
            return try FolioTheme.read(directory.appendingPathComponent(filename), over: defaults)
        } catch let error as NSError where Self.isMissingFile(error) {
            return nil
        }
    }

    private static func isMissingFile(_ error: NSError) -> Bool {
        error.domain == NSCocoaErrorDomain && (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError)
    }
}
