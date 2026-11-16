import Foundation
import Security

struct PrivateUpdateChannel: Sendable {
    private struct Release: Decodable {
        struct Asset: Decodable {
            let id: Int
            let name: String
        }

        let tagName: String
        let draft: Bool
        let prerelease: Bool
        let immutable: Bool
        let assets: [Asset]
    }

    struct Snapshot: Sendable {
        let feed: LocalUpdateFeed
        let archiveURL: URL
        let archiveAPI: URL
    }

    let repository: String
    let releasesURL: URL
    private let api: URL
    private let service: String
    private let isPreview: Bool

    init?(feed: URL, bundleID: String) {
        let path = feed.pathComponents
        guard feed.scheme == "https", feed.host == "github.com", feed.user == nil, feed.password == nil,
              feed.port == nil, feed.query == nil, feed.fragment == nil, path.count == 7 else { return nil }
        let isPreview = path[3] == "releases" && path[4] == "download" && path[6] == "appcast.xml" &&
            Self.previewVersion(path[5]) != nil
        guard isPreview || Array(path.suffix(4)) == ["releases", "latest", "download", "appcast.xml"] else { return nil }
        let repository = path[1...2].joined(separator: "/")
        guard repository.range(of: #"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil,
              !path[1...2].contains(where: { $0 == "." || $0 == ".." }),
              let releases = URL(string: "https://github.com/\(repository)/releases"),
              let api = URL(string: "https://api.github.com/repos/\(repository)/releases") else { return nil }
        self.repository = repository
        self.releasesURL = releases
        self.api = api
        self.service = bundleID + ".github-updates"
        self.isPreview = isPreview
    }

    func latest(token: String?, using session: URLSession) async throws -> Snapshot {
        let (release, archiveName) = if isPreview {
            try await latestPreview(token: token, using: session)
        } else {
            try await latestStable(token: token, using: session)
        }
        guard let appcast = assetURL("appcast.xml", in: release),
              let archive = assetURL(archiveName, in: release) else {
            throw UpdateFailure("The GitHub release is missing the Folio update files.")
        }
        let downloads = releasesURL.appendingPathComponent("download").appendingPathComponent(release.tagName)
        let feedURL = token == nil ? downloads.appendingPathComponent("appcast.xml") : appcast
        let (file, appcastResponse) = try await session.download(for: request(feedURL, token: token, binary: true))
        defer { try? FileManager.default.removeItem(at: file) }
        try validate(appcastResponse, authenticated: token != nil)
        let length = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard (1...1_048_576).contains(length) else {
            throw UpdateFailure("The update feed has an invalid size.")
        }
        let browserURL = downloads.appendingPathComponent(archiveName)
        let local = try await LocalUpdateFeed.start(appcast: Data(contentsOf: file))
        return Snapshot(feed: local, archiveURL: browserURL, archiveAPI: archive)
    }

    private func latestStable(token: String?, using session: URLSession) async throws -> (Release, String) {
        let (data, response) = try await session.data(for: request(api.appendingPathComponent("latest"), token: token, binary: false))
        try validate(response, authenticated: token != nil)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(Release.self, from: data)
        guard !release.draft, !release.prerelease, release.immutable,
              release.tagName.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil else {
            throw UpdateFailure("GitHub didn’t return a published stable release.")
        }
        return (release, "Folio-\(release.tagName.dropFirst()).zip")
    }

    private static func previewVersion(_ tag: String) -> (version: String, order: (Int, String))? {
        guard tag.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+\.[1-9][0-9]{0,11}-[0-9a-f]{7}$"#,
                        options: .regularExpression) != nil,
              let separator = tag.lastIndex(of: "."),
              let dash = tag.lastIndex(of: "-"),
              let timestamp = Int(tag[tag.index(after: separator)..<dash]) else { return nil }
        let base = tag[tag.index(after: tag.startIndex)..<separator]
        let sha = String(tag[tag.index(after: dash)...])
        return ("\(base)-\(timestamp).g\(sha)", (timestamp, sha))
    }

    private func latestPreview(token: String?, using session: URLSession) async throws -> (Release, String) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let pageSize = 100
        var page = 1
        var latest: (release: Release, archiveName: String, order: (Int, String))?
        while true {
            let url = api.appending(queryItems: [
                URLQueryItem(name: "per_page", value: String(pageSize)),
                URLQueryItem(name: "page", value: String(page)),
            ])
            let (data, response) = try await session.data(for: request(url, token: token, binary: false))
            try validate(response, authenticated: token != nil)
            let releases = try decoder.decode([Release].self, from: data)
            for release in releases where !release.draft && release.prerelease && release.immutable {
                guard let build = Self.previewVersion(release.tagName), assetURL("appcast.xml", in: release) != nil else { continue }
                let suffix = "\(build.version)-arm64.zip"
                let names = ["Folio-\(suffix)", "Folio-Preview-\(suffix)"]
                guard let archiveName = names.first(where: { assetURL($0, in: release) != nil }) else { continue }
                if let latest, latest.order >= build.order { continue }
                latest = (release, archiveName, build.order)
            }
            if releases.count < pageSize { break }
            page += 1
        }
        guard let latest else { throw UpdateFailure("GitHub didn’t return a signed Folio preview release.") }
        return (latest.release, latest.archiveName)
    }

    func archiveRequest(_ release: Snapshot, token: String?) -> URLRequest {
        request(token == nil ? release.archiveURL : release.archiveAPI, token: token, binary: true)
    }

    private func assetURL(_ name: String, in release: Release) -> URL? {
        let assets = release.assets.filter { $0.name == name }
        guard assets.count == 1, let id = assets.first?.id, id > 0 else { return nil }
        return api.appendingPathComponent("assets").appendingPathComponent(String(id))
    }

    private func request(_ url: URL, token: String?, binary: Bool) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue(binary ? "application/octet-stream" : "application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }

    private func validate(_ response: URLResponse, authenticated: Bool) throws {
        guard let response = response as? HTTPURLResponse, response.url?.scheme == "https" else {
            throw UpdateFailure("GitHub didn’t return a secure response.")
        }
        switch response.statusCode {
        case 200: return
        case 401 where authenticated, 403 where authenticated, 404 where authenticated:
            throw UpdateFailure("Can’t read the private GitHub release. Check the token and repository access in Settings.")
        default:
            throw UpdateFailure("GitHub couldn’t load the update (HTTP \(response.statusCode)).")
        }
    }

    private var credentialQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: repository]
    }

    func token() -> String? {
        var query = credentialQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func storeToken(_ token: String) throws {
        var status: OSStatus
        if token.isEmpty {
            status = SecItemDelete(credentialQuery as CFDictionary)
            if status == errSecItemNotFound { return }
        } else {
            guard token.range(of: #"^[A-Za-z0-9_]+$"#, options: .regularExpression) != nil else {
                throw UpdateFailure("Enter a GitHub access token.")
            }
            let data = Data(token.utf8)
            status = SecItemUpdate(credentialQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if status == errSecItemNotFound {
                var item = credentialQuery
                item[kSecValueData as String] = data
                status = SecItemAdd(item as CFDictionary, nil)
            }
        }
        guard status == errSecSuccess else { throw UpdateFailure("Couldn’t update GitHub access in the macOS Keychain.") }
    }
}

struct UpdateFailure: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}


final class UpdateTransport: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(Self.redirect(request, from: task.originalRequest))
    }

    static func redirect(_ request: URLRequest, from original: URLRequest?) -> URLRequest? {
        let url = request.url
        let loopback = original?.url?.host == "localhost" && url?.host == "localhost"
        guard url?.scheme == "https" || loopback else { return nil }
        guard original?.value(forHTTPHeaderField: "Authorization") != nil else { return request }

        // Binary assets may redirect to short-lived CDN URLs. Release metadata does not.
        guard original?.value(forHTTPHeaderField: "Accept") == "application/octet-stream",
              url?.host != "api.github.com", url?.scheme == "https" else { return nil }
        var request = request
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        return request
    }
}
