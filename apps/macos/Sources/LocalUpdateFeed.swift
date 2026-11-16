import Foundation
import Network

final class LocalUpdateFeed: Sendable {
    private final class Payload: @unchecked Sendable {
        let route = "/" + UUID().uuidString
        let appcast: Data
        private let lock = NSLock()
        private var archive: Data?

        init(appcast: Data) { self.appcast = appcast }

        func setArchive(_ value: Data?) { lock.withLock { archive = value } }

        func receive(_ connection: NWConnection, prefix: Data = Data()) {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [self] data, _, complete, error in
                guard error == nil, let data else { connection.cancel(); return }
                let header = prefix + data
                guard header.count <= 8192 else { connection.cancel(); return }
                guard let end = header.range(of: Data("\r\n\r\n".utf8)) else {
                    if complete { connection.cancel() } else { receive(connection, prefix: header) }
                    return
                }
                let request = String(decoding: header[..<end.lowerBound], as: UTF8.self)
                let line = request.components(separatedBy: "\r\n")[0].split(separator: " ")
                guard line.count == 3, line[0] == "GET" else { connection.cancel(); return }
                switch String(line[1]) {
                case route + "/appcast.xml":
                    send(appcast, type: "application/rss+xml", to: connection)
                case route + "/Folio.zip":
                    send(lock.withLock { archive }, type: "application/zip", to: connection)
                default:
                    send(nil, type: "text/plain", to: connection)
                }
            }
        }

        private func send(_ body: Data?, type: String, to connection: NWConnection) {
            let status = body == nil ? "404 Not Found" : "200 OK"
            let header = Data(("HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body?.count ?? 0)\r\n" +
                              "Cache-Control: no-store\r\nConnection: close\r\n\r\n").utf8)
            connection.send(content: header, completion: .contentProcessed { error in
                guard error == nil, let body else { connection.cancel(); return }
                connection.send(content: body, completion: .contentProcessed { _ in connection.cancel() })
            })
        }
    }

    let appcast: URL
    let archive: URL
    private let listener: NWListener
    private let payload: Payload

    static func start(appcast: Data) async throws -> LocalUpdateFeed {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let listener = try NWListener(using: parameters)
        let payload = Payload(appcast: appcast)
        let queue = DispatchQueue(label: "Folio.LocalUpdateFeed")
        listener.newConnectionHandler = { connection in
            connection.start(queue: queue)
            payload.receive(connection)
            queue.asyncAfter(deadline: .now() + 30) { connection.cancel() }
        }
        let port: UInt16 = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                listener.stateUpdateHandler = { [weak listener] state in
                    guard let listener else { return }
                    switch state {
                    case .ready:
                        listener.stateUpdateHandler = nil
                        guard let port = listener.port else {
                            continuation.resume(throwing: UpdateFailure("Couldn’t start the local updater."))
                            return
                        }
                        continuation.resume(returning: port.rawValue)
                    case .failed(let error):
                        listener.stateUpdateHandler = nil
                        listener.cancel()
                        continuation.resume(throwing: error)
                    case .cancelled:
                        listener.stateUpdateHandler = nil
                        continuation.resume(throwing: CancellationError())
                    default:
                        break
                    }
                }
                listener.start(queue: queue)
            }
        } onCancel: {
            listener.cancel()
        }
        return LocalUpdateFeed(listener: listener, payload: payload, port: port)
    }

    private init(listener: NWListener, payload: Payload, port: UInt16) {
        self.listener = listener
        self.payload = payload
        let root = URL(string: "http://localhost:\(port)\(payload.route)")!
        self.appcast = root.appendingPathComponent("appcast.xml")
        self.archive = root.appendingPathComponent("Folio.zip")
    }

    func setArchive(_ data: Data?) { payload.setArchive(data) }

    deinit { listener.cancel() }
}
