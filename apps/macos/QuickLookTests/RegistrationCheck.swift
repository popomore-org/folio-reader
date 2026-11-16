import Foundation

private final class RegistryFixture: @unchecked Sendable {
    let target = "/Applications/Folio.app/Contents/PlugIns/FolioQuickLook.appex"
    let duplicate = "/Applications/Folio Copy.app/Contents/PlugIns/FolioQuickLook.appex"
    let identifier = "org.popomore.folio.preview.quicklook"
    var paths: [String] = []
    var marker = "-"
    private(set) var mutations: [[String]] = []

    func run(_ args: [String]) throws -> String {
        switch args[0] {
        case "-m":
            precondition(args == ["-m", "-A", "-D", "-v", "-p", "com.apple.quicklook.preview", "-i", identifier])
            return paths.isEmpty ? "  (no matches)\n" : paths.map { path in
                "\(marker)  F \(identifier)(0.1.1)\tFAKE-UUID\t2026-11-16 00:00:00 +0000\t\(path)\n"
            }.joined()
        case "-a":
            mutations.append(args)
            paths.append(args[1])
        case "-r":
            mutations.append(args)
            paths.removeAll { $0 == args[1] }
        default:
            preconditionFailure("Unexpected PlugInKit operation")
        }
        return ""
    }
}

@main
struct RegistrationCheck {
    static func main() throws {
        let fixture = RegistryFixture()
        let registry = QuickLookRegistry(
            identifier: fixture.identifier, location: URL(fileURLWithPath: fixture.target, isDirectory: true),
            command: { try fixture.run($0) }
        )
        fixture.paths = [fixture.duplicate]
        let before = try registry.apply(.read)
        precondition(before.election == nil && before.duplicateCount == 1)
        precondition((try? registry.apply(.removeDuplicates)) == nil && fixture.mutations.isEmpty)

        fixture.paths = []
        let absent = try registry.apply(.read)
        precondition(absent.election == nil && absent.duplicateCount == 0)

        let first = try registry.apply(.register)
        let second = try registry.apply(.register)
        precondition(first == second && first.election == .disabled)
        precondition(fixture.mutations == [["-a", fixture.target]])

        fixture.paths += [fixture.duplicate, fixture.duplicate]
        let withDuplicate = try registry.apply(.read)
        precondition(withDuplicate.duplicateCount == 1)
        let cleaned = try registry.apply(.removeDuplicates)
        let afterRepeat = try registry.apply(.removeDuplicates)
        precondition(cleaned == afterRepeat && cleaned.election == .disabled && cleaned.duplicateCount == 0)
        precondition(fixture.mutations == [["-a", fixture.target], ["-r", fixture.duplicate]])

        fixture.marker = "+"
        let enabled = try registry.apply(.read)
        precondition(enabled.election == .enabled && fixture.mutations.count == 2)

        var malformed = registry
        malformed.command = { _ in "Unexpected output from PlugInKit." }
        precondition((try? malformed.apply(.read)) == nil)
        print("Verified exact-path Quick Look status, registration and cleanup idempotence, and system election preservation.")
    }
}
