import Foundation

final class ReleaseFixture: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let client = self.client!
        let url = request.url!
        let token = request.value(forHTTPHeaderField: "Authorization")
        let status = token == "Bearer fixture_token" ? 200 : 401
        precondition(url.host == "api.github.com")
        let body: String
        if url.lastPathComponent == "latest" {
            precondition(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
            body = """
                {"tag_name":"v0.1.1","draft":false,"prerelease":false,"immutable":true,
                 "assets":[{"id":11,"name":"appcast.xml"},{"id":12,"name":"Folio-0.1.1.zip"}]}
                """
        } else if url.path == "/repos/example/folio/releases" {
            precondition(url.query == "per_page=100&page=1")
            precondition(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
            body = """
                [
                  {"tag_name":"v0.1.2","draft":false,"prerelease":false,"immutable":true,"assets":[]},
                  {"tag_name":"preview-v0.1.0","draft":false,"prerelease":true,"immutable":true,"assets":[]},
                  {"tag_name":"v0.1.1.1793840001-abcdef0","draft":false,"prerelease":true,"immutable":true,"assets":[]},
                  {"tag_name":"v0.1.1.1793840000-abcdef1","draft":false,"prerelease":true,"immutable":true,
                   "assets":[{"id":21,"name":"appcast.xml"},{"id":22,"name":"Folio-Preview-0.1.1-1793840000.gabcdef1-arm64.zip"}]},
                  {"tag_name":"v0.1.1.1793840000-abcdef0","draft":false,"prerelease":true,"immutable":true,
                   "assets":[{"id":23,"name":"appcast.xml"},{"id":24,"name":"Folio-Preview-0.1.1-1793840000.gabcdef0-arm64.zip"}]}
                ]
                """
        } else {
            precondition(["/repos/example/folio/releases/assets/11", "/repos/example/folio/releases/assets/21"].contains(url.path))
            precondition(request.value(forHTTPHeaderField: "Accept") == "application/octet-stream")
            body = "<rss />"
        }
        client.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status,
                                                              httpVersion: nil, headerFields: nil)!,
                           cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: Data(body.utf8))
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@main
struct PrivateUpdateCheck {
    static func main() async throws {
        let feed = URL(string: "https://github.com/example/folio/releases/latest/download/appcast.xml")!
        let channel = PrivateUpdateChannel(feed: feed, bundleID: "example.test")!
        precondition(PrivateUpdateChannel(feed: URL(string: "https://example.com" + feed.path)!, bundleID: "example.test") == nil)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ReleaseFixture.self]
        let session = URLSession(configuration: config)
        let snapshot = try await channel.latest(token: "fixture_token", using: session)
        precondition(snapshot.archiveURL.absoluteString == "https://github.com/example/folio/releases/download/v0.1.1/Folio-0.1.1.zip")
        let (appcast, _) = try await URLSession.shared.data(from: snapshot.feed.appcast)
        precondition(String(decoding: appcast, as: UTF8.self) == "<rss />")
        let zip = Data("fixture archive".utf8)
        snapshot.feed.setArchive(zip)
        let (downloaded, _) = try await URLSession.shared.data(from: snapshot.feed.archive)
        precondition(downloaded == zip)
        snapshot.feed.setArchive(nil)
        let (_, missing) = try await URLSession.shared.data(from: snapshot.feed.archive)
        precondition((missing as? HTTPURLResponse)?.statusCode == 404)
        let original = channel.archiveRequest(snapshot, token: "fixture_token")
        precondition(original.url?.absoluteString == "https://api.github.com/repos/example/folio/releases/assets/12")

        let previewTag = "v0.1.1.1793840000-abcdef0"
        let previewFeed = URL(string: "https://github.com/example/folio/releases/download/\(previewTag)/appcast.xml")!
        let preview = PrivateUpdateChannel(feed: previewFeed, bundleID: "example.preview")!
        let previewSnapshot = try await preview.latest(token: "fixture_token", using: session)
        let previewArchive = "https://github.com/example/folio/releases/download/v0.1.1.1793840000-abcdef1/Folio-Preview-0.1.1-1793840000.gabcdef1-arm64.zip"
        precondition(previewSnapshot.archiveURL.absoluteString == previewArchive)
        precondition(preview.archiveRequest(previewSnapshot, token: "fixture_token").url?.lastPathComponent == "22")

        var redirect = URLRequest(url: URL(string: "https://release-assets.githubusercontent.com/temporary-file")!)
        redirect.setValue("Bearer fixture_token", forHTTPHeaderField: "Authorization")
        let escaped = UpdateTransport.redirect(redirect, from: original)
        precondition(escaped?.url == redirect.url)
        precondition(escaped?.value(forHTTPHeaderField: "Authorization") == nil)
        redirect.url = URL(string: "http://release-assets.githubusercontent.com/temporary-file")!
        precondition(UpdateTransport.redirect(redirect, from: original) == nil)

        do {
            _ = try await channel.latest(token: "expired_token", using: session)
            preconditionFailure("Expected an authorization error")
        } catch let error as UpdateFailure {
            precondition(error.localizedDescription.contains("Check the token"))
        }
        print("Verified stable and preview update selection, local appcast handoff, and credential-free redirects.")
    }
}
