import Foundation

/// The JSON-RPC side of MCP: `initialize`, `ping`, `tools/list` and `tools/call`.
@MainActor
struct MCPProtocol {
    let tools: SlidesTools

    /// Returns the reply to `message`, or `nil` when it needs none (notifications, responses).
    func handle(_ body: Data) async -> Data? {
        guard let message = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return reply(id: NSNull(), error: (-32700, "Parse error"))
        }
        guard let id = message["id"], let method = message["method"] as? String else { return nil }
        let params = message["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            return reply(id: id, result: [
                "protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": [
                    "name": "slides",
                    "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
                ],
                "instructions": SlidesTools.instructions,
            ])
        case "ping":
            return reply(id: id, result: [:])
        case "tools/list":
            return reply(id: id, result: ["tools": SlidesTools.definitions])
        case "tools/call":
            guard let name = params["name"] as? String else { return reply(id: id, error: (-32602, "Missing tool name")) }
            let arguments = Arguments(params["arguments"] as? [String: Any] ?? [:])
            do {
                return reply(id: id, result: ["content": try await tools.call(name, arguments)])
            } catch {
                let text = (error as? ToolError)?.message ?? error.localizedDescription
                return reply(id: id, result: ["content": [["type": "text", "text": text]], "isError": true])
            }
        default:
            return reply(id: id, error: (-32601, "Method not found: \(method)"))
        }
    }

    private func reply(id: Any, result: [String: Any]? = nil, error: (code: Int, message: String)? = nil) -> Data? {
        var message: [String: Any] = ["jsonrpc": "2.0", "id": id]
        if let error {
            message["error"] = ["code": error.code, "message": error.message]
        } else {
            message["result"] = result ?? [:]
        }
        return try? JSONSerialization.data(withJSONObject: message)
    }
}

struct ToolError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

/// Typed access to a tool call's arguments.
struct Arguments {
    let values: [String: Any]

    init(_ values: [String: Any]) {
        self.values = values
    }

    func has(_ key: String) -> Bool { values[key] != nil && !(values[key] is NSNull) }
    func string(_ key: String) -> String? { values[key] as? String }
    func double(_ key: String) -> Double? { (values[key] as? NSNumber)?.doubleValue ?? string(key).flatMap(Double.init) }
    func int(_ key: String) -> Int? { double(key).map { Int($0) } }
    func strings(_ key: String) -> [String]? { values[key] as? [String] ?? string(key).map { [$0] } }
}
