import Foundation

enum FileKind: String, Decodable {
    case markdown, text, html, rtf, pdf, image, audio, video, table, mermaid, vega, other

    var icon: String {
        switch self {
        case .markdown, .text, .html, .rtf: "doc.text"
        case .pdf: "doc.richtext"
        case .image: "photo"
        case .audio: "waveform"
        case .video: "film"
        case .table: "tablecells"
        case .mermaid: "point.3.connected.trianglepath.dotted"
        case .vega: "chart.bar.xaxis"
        case .other: "doc"
        }
    }
}

struct Entry: Decodable, Identifiable {
    let name: String
    let path: String
    let directory: Bool
    let kind: FileKind?
    var id: String { path }
}

struct Heading: Decodable, Identifiable {
    let id: String
    let title: String
    let level: Int
}

struct Document: Decodable {
    struct Preview: Decodable {
        let html: String
        let headings: [Heading]
    }

    let kind: FileKind
    let bytes: Int64
    let source: String?
    let revision: String?
    let preview: Preview?
}

struct History: Decodable {
    struct Commit: Decodable, Identifiable {
        let id: String
        let summary: String
        let author: String
        let timestamp: Double
        var date: Date { Date(timeIntervalSince1970: timestamp) }
    }

    let staged: String?
    let unstaged: String?
    let commits: [Commit]
    let limited: Bool
}

struct Patch: Decodable {
    let text: String
    let truncated: Bool
}

struct CoreError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct Core {
    private struct Response<T: Decodable>: Decodable {
        let error: String?
        let value: T?
    }

    static func request<T: Decodable>(_ operation: String, root: URL, path: String,
                                      values: [String: String] = [:]) throws -> T? {
        var body = values
        body["op"] = operation
        body["root"] = root.path
        body["path"] = path
        let data = try JSONEncoder().encode(body)
        let json = String(decoding: data, as: UTF8.self)
        guard let result = json.withCString({ folio_call($0) }) else {
            throw CoreError(message: "The reader did not return a result.")
        }
        defer { folio_free(result) }
        let response = try JSONDecoder().decode(Response<T>.self, from: Data(String(cString: result).utf8))
        if let error = response.error {
            throw CoreError(message: error)
        }
        return response.value
    }

    static func file(_ path: String, in root: URL) -> URL? {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." || $0.lowercased() == ".git" })
        else { return nil }
        let resolved = root.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.pathComponents
        guard resolved.pathComponents.count > prefix.count,
              resolved.pathComponents.starts(with: prefix),
              !resolved.pathComponents.dropFirst(prefix.count).contains(where: { $0.lowercased() == ".git" })
        else { return nil }
        return resolved
    }
}
