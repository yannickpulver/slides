import Foundation
@preconcurrency import Network
import OSLog

/// MCP over Streamable HTTP on `127.0.0.1`: one POST per JSON-RPC message to `/mcp`, answered with plain JSON.
/// No sessions and no server-sent events, so GET is refused.
@MainActor
final class MCPServer {
    static let path = "/mcp"
    /// Debug builds use the next port, so they run next to the installed app.
    static let port: UInt16 = {
        #if DEBUG
            ProcessInfo.processInfo.environment["SLIDES_MCP_PORT"].flatMap(UInt16.init) ?? 47101
        #else
            47100
        #endif
    }()

    static var url: String { "http://127.0.0.1:\(port)\(path)" }

    nonisolated private static let log = Logger(subsystem: "com.yannickpulver.slides", category: "mcp")
    private let handle: (Data) async -> Data?
    private var listener: NWListener?

    /// `handle` gets a JSON-RPC message and returns the reply, or `nil` for a notification.
    init(handle: @escaping (Data) async -> Data?) {
        self.handle = handle
    }

    func start() {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: Self.port)!)
        parameters.allowLocalEndpointReuse = true
        do {
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated { self?.accept(connection) }
            }
            listener.stateUpdateHandler = { state in
                if case let .failed(error) = state { Self.log.error("MCP server failed: \(error.localizedDescription)") }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            Self.log.error("MCP server did not start: \(error.localizedDescription)")
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self else { return connection.cancel() }
                var buffer = buffer
                if let data { buffer.append(data) }
                if let request = HTTPRequest(buffer) {
                    Task { await self.respond(to: request, on: connection) }
                } else if isComplete || error != nil || buffer.count > 50 << 20 {
                    connection.cancel()
                } else {
                    self.receive(connection, buffer: buffer)
                }
            }
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) async {
        guard request.path == Self.path else { return send("404 Not Found", on: connection) }
        // Web pages may not reach the server through DNS rebinding.
        if let origin = request.headers["origin"], let host = URL(string: origin)?.host(),
           !["localhost", "127.0.0.1", "::1"].contains(host) {
            return send("403 Forbidden", on: connection)
        }
        guard request.method == "POST" else {
            return send("405 Method Not Allowed", headers: ["Allow": "POST"], on: connection)
        }
        if let reply = await handle(request.body) {
            send("200 OK", headers: ["Content-Type": "application/json"], body: reply, on: connection)
        } else {
            send("202 Accepted", on: connection)
        }
    }

    private func send(_ status: String, headers: [String: String] = [:], body: Data = Data(), on connection: NWConnection) {
        var head = "HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n"
        for (name, value) in headers { head += "\(name): \(value)\r\n" }
        head += "\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }
}

/// A complete HTTP/1.1 request, or `nil` while bytes are still missing.
struct HTTPRequest {
    let method: String
    let path: String
    /// Names in lowercase.
    let headers: [String: String]
    let body: Data

    init?(_ data: Data) {
        guard let end = data.firstRange(of: Data("\r\n\r\n".utf8)) else { return nil }
        let lines = String(decoding: data[..<end.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = headers["content-length"].flatMap(Int.init) ?? 0
        guard data.endIndex - end.upperBound >= length else { return nil }
        method = String(requestLine[0])
        path = String(requestLine[1].split(separator: "?", maxSplits: 1)[0])
        self.headers = headers
        body = data[end.upperBound..<end.upperBound + length]
    }
}
