import Darwin
import Foundation

func installFolioCommand(_ executable: URL, in directory: URL) throws -> URL {
    let files = FileManager.default
    let tool = executable.resolvingSymlinksInPath()
    let link = directory.appending(path: "folio")
    try files.createDirectory(at: directory, withIntermediateDirectories: true)

    let directoryFD = Darwin.open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
    guard directoryFD >= 0 else { throw systemError() }
    defer { _ = Darwin.close(directoryFD) }
    guard flock(directoryFD, LOCK_EX) == 0 else { throw systemError() }

    do {
        try files.createSymbolicLink(at: link, withDestinationURL: tool)
        return link
    } catch {
        guard let destination = try? files.destinationOfSymbolicLink(atPath: link.path) else {
            if files.fileExists(atPath: link.path) { throw existingCommand(at: link) }
            throw error
        }

        let target = URL(fileURLWithPath: destination, relativeTo: directory).standardizedFileURL
        if target.resolvingSymlinksInPath().path == tool.path { return link }
        guard isMissingFolioCommand(at: target) else { throw existingCommand(at: link) }

        // Prepare the new link on the same volume before replacing the broken one.
        let staging = directory.appending(path: ".folio-install-\(UUID().uuidString)", directoryHint: .isDirectory)
        try files.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: staging) }
        let replacement = staging.appending(path: "folio")
        try files.createSymbolicLink(at: replacement, withDestinationURL: tool)
        guard (try? files.destinationOfSymbolicLink(atPath: link.path)) == destination else {
            throw existingCommand(at: link)
        }
        guard Darwin.rename(replacement.path, link.path) == 0 else { throw systemError() }
        return link
    }
}

private func isMissingFolioCommand(at target: URL) -> Bool {
    let app = target.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    guard app.pathExtension.lowercased() == "app",
          app.appending(path: "Contents/Helpers/folio").path == target.path else { return false }
    return Darwin.access(target.path, F_OK) == -1 && errno == ENOENT
}

private func existingCommand(at link: URL) -> CocoaError {
    CocoaError(.fileWriteFileExists, userInfo: [
        NSLocalizedDescriptionKey: "\(link.path) already points to another command or contains a file. Move it before installing Folio."
    ])
}

private func systemError() -> POSIXError {
    POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
}
