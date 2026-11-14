import AppKit

private let help = """
Usage: folio [--app APP] [open] [--] [PATH ...]
       folio [--app APP] preview [--] [FILE]
       folio [--app APP] install
       folio [--app APP] --version
       folio --help

  open      Open files or folders in the workspace. Defaults to the current directory.
  preview   Open a file in the preview window. Omit FILE to choose one in Folio.
  install   Add folio to ~/.local/bin without replacing an existing command.
  --app     Use a specific Folio .app bundle. Overrides FOLIO_APP.

Paths may be relative to the current directory. Use -- before a path starting with -.
"""

private struct Failure: Error {
    let message: String
    let status: Int32

    init(_ message: String, status: Int32 = 1) {
        self.message = message
        self.status = status
    }
}

private enum Command: String {
    case open, preview, install
    case help = "--help"
    case version = "--version"
}

private struct BundleInfo {
    let url: URL
    let scheme: String
    let version: String

    init?(_ url: URL) {
        guard let bundle = Bundle(url: url),
              let scheme = bundle.object(forInfoDictionaryKey: "FolioPreviewScheme") as? String,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              FileManager.default.isExecutableFile(atPath: url.appending(path: "Contents/MacOS/Folio").path),
              FileManager.default.isExecutableFile(atPath: url.appending(path: "Contents/Helpers/folio").path) else { return nil }
        self.url = url
        self.scheme = scheme
        self.version = version
    }
}

private func resolvePath(_ path: String) -> URL {
    let expanded = (path as NSString).expandingTildeInPath
    let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    return URL(fileURLWithPath: expanded, relativeTo: directory).standardizedFileURL
}

@MainActor
private func findApp(_ explicit: String?) throws -> BundleInfo {
    if let location = explicit ?? ProcessInfo.processInfo.environment["FOLIO_APP"] {
        guard let app = BundleInfo(resolvePath(location)) else {
            throw Failure("No compatible Folio app at \(location). Choose a bundle that includes the folio command.")
        }
        return app
    }

    let executable = resolvePath(CommandLine.arguments[0]).resolvingSymlinksInPath()
    let enclosing = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    if let app = BundleInfo(enclosing) { return app }
    for identifier in ["org.popomore.folio", "org.popomore.folio.preview"] {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
           let app = BundleInfo(url) { return app }
    }
    throw Failure("Folio wasn’t found. Install it or pass --app /path/to/Folio.app.")
}

private func openInFolio(_ app: BundleInfo, targets: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", app.url.path, "--"] + targets
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw Failure("macOS could not open the target in Folio.") }
}

private func install(_ app: BundleInfo) throws {
    let tool = app.url.appending(path: "Contents/Helpers/folio").resolvingSymlinksInPath()
    let directory = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin", directoryHint: .isDirectory)
    let link = directory.appending(path: "folio")
    let files = FileManager.default
    try files.createDirectory(at: directory, withIntermediateDirectories: true)
    do {
        try files.createSymbolicLink(at: link, withDestinationURL: tool)
    } catch {
        guard let destination = try? files.destinationOfSymbolicLink(atPath: link.path),
              destination == tool.path else {
            if files.fileExists(atPath: link.path) || (try? files.destinationOfSymbolicLink(atPath: link.path)) != nil {
                throw Failure("\(link.path) already exists. Move it before installing Folio.")
            }
            throw error
        }
    }
    print(link.path)
}

@MainActor
private func run() throws {
    var arguments = ArraySlice(CommandLine.arguments.dropFirst())
    var explicitApp: String?
    if arguments.first == "--app" {
        arguments.removeFirst()
        guard let path = arguments.popFirst(), !path.isEmpty, path != "--" else {
            throw Failure("Pass the .app path after --app.", status: 2)
        }
        explicitApp = path
    }

    let command = arguments.first.flatMap(Command.init(rawValue:))
    if command != nil { arguments.removeFirst() }
    if command == .help || arguments.first == "--help" {
        print(help)
        return
    }
    if arguments.first == "--" {
        arguments.removeFirst()
    } else if let flag = arguments.first(where: { $0.hasPrefix("-") }) {
        throw Failure("Unknown option \(flag). Use -- before a path starting with -.", status: 2)
    }
    switch command ?? .open {
    case .help:
        print(help)
    case .version, .install:
        guard arguments.isEmpty else { throw Failure("This command takes no paths.", status: 2) }
        let app = try findApp(explicitApp)
        if command == .version { print(app.version) } else { try install(app) }
    case .open:
        let paths = arguments.isEmpty ? ["."] : Array(arguments)
        let targets = try paths.map { path in
            let file = resolvePath(path).resolvingSymlinksInPath()
            guard !path.isEmpty, let properties = try? file.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]),
                  properties.isRegularFile == true || properties.isDirectory == true else {
                throw Failure("Choose an accessible local file or folder: \(path)")
            }
            return file.path
        }
        try openInFolio(findApp(explicitApp), targets: targets)
    case .preview:
        guard arguments.count <= 1 else { throw Failure("Preview accepts one local file.", status: 2) }
        let app = try findApp(explicitApp)
        var url = URLComponents()
        url.scheme = app.scheme
        url.host = "preview"
        if let path = arguments.first {
            let file = resolvePath(path).resolvingSymlinksInPath()
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                throw Failure("Choose an accessible local file to preview: \(path)")
            }
            url.queryItems = [URLQueryItem(name: "path", value: file.path)]
        }
        guard let target = url.string else { throw Failure("Could not encode the preview URL.") }
        try openInFolio(app, targets: [target])
    }
}

do {
    try run()
} catch {
    let failure = error as? Failure
    FileHandle.standardError.write(Data("folio: \(failure?.message ?? error.localizedDescription)\n".utf8))
    exit(failure?.status ?? 1)
}
