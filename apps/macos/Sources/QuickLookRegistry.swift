import Foundation

struct QuickLookRegistry: Sendable {
    enum Action: Equatable, Sendable {
        case read, register, removeDuplicates
    }

    enum Election: Equatable, Sendable {
        case enabled, disabled, automatic, superseded, debugger, unknown

        init(marker: Character?) {
            switch marker {
            case "+": self = .enabled
            case "-": self = .disabled
            case " ": self = .automatic
            case "=": self = .superseded
            case "!": self = .debugger
            default: self = .unknown
            }
        }
    }

    struct Snapshot: Equatable, Sendable {
        let election: Election?
        let duplicateCount: Int
    }

    private struct Registration {
        let path: URL
        let election: Election
    }

    private struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    private static let extensionPoint = "com.apple.quicklook.preview"
    let identifier: String
    let location: URL
    var command: @Sendable ([String]) throws -> String = Self.runPluginKit

    static func embedded(in app: Bundle = .main) -> QuickLookRegistry? {
        guard let url = app.builtInPlugInsURL?.appendingPathComponent("FolioQuickLook.appex", isDirectory: true),
              let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
              let extensionInfo = bundle.infoDictionary?["NSExtension"] as? [String: Any],
              extensionInfo["NSExtensionPointIdentifier"] as? String == extensionPoint else { return nil }
        return QuickLookRegistry(identifier: identifier, location: url)
    }

    func apply(_ action: Action) throws -> Snapshot {
        let target = location.standardizedFileURL.resolvingSymlinksInPath()
        let current = try registrations()
        switch action {
        case .read:
            return snapshot(current, target: target)
        case .register:
            guard !current.contains(where: { $0.path == target }) else {
                return snapshot(current, target: target)
            }
            do {
                _ = try command(["-a", target.path])
            } catch {
                let updated = try? snapshot(registrations(), target: target)
                if let updated, updated.election != nil { return updated }
                throw error
            }
            let updated = try snapshot(registrations(), target: target)
            guard updated.election != nil else { throw Failure("macOS did not register this copy of Folio.") }
            return updated
        case .removeDuplicates:
            guard current.contains(where: { $0.path == target }) else {
                throw Failure("Register this copy of Folio before removing other registrations.")
            }
            let paths = duplicatePaths(current, target: target)
            guard !paths.isEmpty else { return snapshot(current, target: target) }
            for url in paths.sorted(by: { $0.path < $1.path }) {
                _ = try command(["-r", url.path])
            }
            return try snapshot(registrations(), target: target)
        }
    }

    private func snapshot(_ registrations: [Registration], target: URL) -> Snapshot {
        return Snapshot(election: registrations.first(where: { $0.path == target })?.election,
                        duplicateCount: duplicatePaths(registrations, target: target).count)
    }

    private func duplicatePaths(_ registrations: [Registration], target: URL) -> Set<URL> {
        Set(registrations.map(\.path).filter { $0 != target })
    }

    private func registrations() throws -> [Registration] {
        let output = try command(["-m", "-A", "-D", "-v", "-p", Self.extensionPoint, "-i", identifier])
        if output.trimmingCharacters(in: .whitespacesAndNewlines) == "(no matches)" { return [] }

        let matches = output.split(whereSeparator: \.isNewline).compactMap { line -> Registration? in
            let fields = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count == 4, fields[3].hasPrefix("/"),
                  let name = fields[0].split(whereSeparator: \.isWhitespace).last,
                  name.hasPrefix(identifier + "(") else { return nil }
            let path = URL(fileURLWithPath: String(fields[3]), isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
            guard path.pathExtension == "appex" else { return nil }
            let marker = fields[0].hasPrefix(identifier + "(") ? " " : fields[0].first
            return Registration(path: path, election: Election(marker: marker))
        }
        guard !matches.isEmpty else { throw Failure("Folio couldn’t read the Quick Look registration.") }
        return matches
    }

    private static func runPluginKit(_ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure("The macOS Quick Look registry couldn’t complete the request. Try again or open System Settings.")
        }
        return String(decoding: output, as: UTF8.self)
    }
}
