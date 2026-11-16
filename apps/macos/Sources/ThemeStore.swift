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
            do {
                let defaults = try FolioTheme.read(FolioTheme.bundledURL(for: mode, in: bundle))
                let file = directory.appendingPathComponent(mode.filename)
                do {
                    updated[mode] = try FolioTheme.read(file, over: defaults)
                } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                    updated[mode] = defaults
                } catch {
                    updated[mode] = updated[mode] ?? defaults
                    throw error
                }
            } catch {
                failures.append("\(mode.filename) — \(error.localizedDescription)")
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
            do {
                try files.copyItem(at: FolioTheme.bundledURL(for: mode, in: bundle), to: destination)
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                // User edits and files created by another instance take precedence.
            }
        }
    }
}
