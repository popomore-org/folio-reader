import Foundation

@main
struct InstallCheck {
    static func main() throws {
        let arguments = CommandLine.arguments
        if arguments.count == 3 {
            do {
                _ = try installFolioCommand(URL(fileURLWithPath: arguments[1]), in: URL(fileURLWithPath: arguments[2], isDirectory: true))
            } catch {
                exit(1)
            }
            return
        }
        let files = FileManager.default
        let root = files.temporaryDirectory.appending(path: "folio-install-check-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? files.removeItem(at: root) }
        let directory = root.appending(path: "bin", directoryHint: .isDirectory)
        let link = directory.appending(path: "folio")
        let command = root.appending(path: "Current/Folio.app/Contents/Helpers/folio")
        let otherCommand = root.appending(path: "Other/Folio.app/Contents/Helpers/folio")
        let oldCommand = root.appending(path: ".build/Folio Preview.app/Contents/Helpers/folio")
        for tool in [command, otherCommand] {
            try files.createDirectory(at: tool.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: tool)
        }

        let installed = try installFolioCommand(command, in: directory)
        let repeated = try installFolioCommand(command, in: directory)
        precondition(installed == link && repeated == link)
        let absolute = try files.destinationOfSymbolicLink(atPath: link.path)
        precondition(absolute == command.resolvingSymlinksInPath().path)

        try setLink(link, to: "../Current/Folio.app/Contents/Helpers/folio")
        _ = try installFolioCommand(command, in: directory)
        let relative = try files.destinationOfSymbolicLink(atPath: link.path)
        precondition(relative == "../Current/Folio.app/Contents/Helpers/folio")

        try setLink(link, to: oldCommand.path)
        precondition(!files.fileExists(atPath: link.path))
        _ = try installFolioCommand(command, in: directory)
        let repaired = try files.destinationOfSymbolicLink(atPath: link.path)
        precondition(repaired == command.resolvingSymlinksInPath().path)

        let unrelated = root.appending(path: "missing-unrelated-command").path
        for destination in [unrelated, otherCommand.path] {
            try setLink(link, to: destination)
            precondition((try? installFolioCommand(command, in: directory)) == nil)
            let preserved = try files.destinationOfSymbolicLink(atPath: link.path)
            precondition(preserved == destination)
        }

        try files.removeItem(at: link)
        let contents = Data("keep this existing file".utf8)
        try contents.write(to: link)
        precondition((try? installFolioCommand(command, in: directory)) == nil)
        let preserved = try Data(contentsOf: link)
        precondition(preserved == contents)
        try files.removeItem(at: link)

        try setLink(link, to: oldCommand.path)
        let runs = try [command, otherCommand].map { tool in
            let child = Process()
            child.executableURL = URL(fileURLWithPath: arguments[0])
            child.arguments = [tool.path, directory.path]
            try child.run()
            return child
        }
        for child in runs { child.waitUntilExit() }
        precondition(runs.map(\.terminationStatus).sorted() == [0, 1])
        let concurrentTarget = try files.destinationOfSymbolicLink(atPath: link.path)
        let winner = runs[0].terminationStatus == 0 ? command : otherCommand
        precondition(concurrentTarget == winner.resolvingSymlinksInPath().path)
        let remaining = try files.contentsOfDirectory(atPath: directory.path)
        precondition(remaining == ["folio"])

        print("Verified Folio install, relative links, stale-link repair, preserved conflicts, and concurrent installs.")
    }

    private static func setLink(_ link: URL, to destination: String) throws {
        let files = FileManager.default
        if (try? files.destinationOfSymbolicLink(atPath: link.path)) != nil {
            try files.removeItem(at: link)
        }
        try files.createSymbolicLink(atPath: link.path, withDestinationPath: destination)
    }
}
