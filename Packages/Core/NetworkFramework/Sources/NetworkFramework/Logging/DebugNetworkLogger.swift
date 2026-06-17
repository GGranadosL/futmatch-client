import Foundation

// MARK: - Debug Logger (active only in DEBUG builds)

/// Prints a readable cURL-style log of every request and its response.
/// Compiled out entirely in Release — the #if DEBUG blocks are evaluated at
/// compile time, so there is zero overhead in production.
public struct DebugNetworkLogger: NetworkLogger {
    public init() {}

    public func logRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "(no url)"

        var lines = [
            "┌─── [\(method)] \(url)"
        ]

        // Headers
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            lines.append("│ Headers:")
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                // Redact the auth token — keep the first 12 chars for traceability
                if key.lowercased() == "authorization" {
                    let redacted = value.count > 20
                        ? String(value.prefix(20)) + "…[redacted]"
                        : "[redacted]"
                    lines.append("│   \(key): \(redacted)")
                } else {
                    lines.append("│   \(key): \(value)")
                }
            }
        }

        // Body
        if let body = request.httpBody, !body.isEmpty {
            lines.append("│ Body:")
            if let json = prettyJSON(body) {
                json.components(separatedBy: "\n").forEach { lines.append("│   \($0)") }
            } else {
                lines.append("│   \(String(data: body, encoding: .utf8) ?? "<binary \(body.count) bytes>")")
            }
        }

        lines.append("└───")
        print(lines.joined(separator: "\n"))
        #endif
    }

    public func logResponse(_ response: HTTPURLResponse, data: Data) {
        #if DEBUG
        let url = response.url?.absoluteString ?? "(no url)"
        let status = response.statusCode
        let emoji = status < 300 ? "✅" : status < 400 ? "↩️" : "❌"

        var lines = [
            "┌─── \(emoji) [\(status)] \(url)"
        ]

        // Response headers (only the useful ones)
        let interestingHeaders = ["content-type", "x-request-id", "cf-ray", "retry-after"]
        let filtered = response.allHeaderFields.filter { key, _ in
            interestingHeaders.contains((key as? String ?? "").lowercased())
        }
        if !filtered.isEmpty {
            lines.append("│ Headers:")
            for (key, value) in filtered {
                lines.append("│   \(key): \(value)")
            }
        }

        // Body
        if !data.isEmpty {
            lines.append("│ Body:")
            if let json = prettyJSON(data) {
                json.components(separatedBy: "\n").forEach { lines.append("│   \($0)") }
            } else {
                lines.append("│   \(String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>")")
            }
        } else {
            lines.append("│ Body: (empty)")
        }

        lines.append("└───")
        print(lines.joined(separator: "\n"))
        #endif
    }

    public func logError(_ error: Error) {
        #if DEBUG
        print("🔴 Network error: \(error)")
        #endif
    }

    // MARK: - Private

    private func prettyJSON(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
              let str = String(data: pretty, encoding: .utf8) else { return nil }
        return str
    }
}
