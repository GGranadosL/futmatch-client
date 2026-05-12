import Foundation

// MARK: - Network Logger Protocol

public protocol NetworkLogger {
    func logRequest(_ request: URLRequest)
    func logResponse(_ response: HTTPURLResponse, data: Data)
    func logError(_ error: Error)
}

// MARK: - Console Network Logger

public struct ConsoleNetworkLogger: NetworkLogger {
    
    public let isEnabled: Bool
    
    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    public func logRequest(_ request: URLRequest) {
        guard isEnabled else { return }
        
        print(buildRequestLog(for: request))
    }
    
    public func logResponse(_ response: HTTPURLResponse, data: Data) {
        guard isEnabled else { return }
        
        print(buildResponseLog(for: response, data: data))
    }
    
    public func logError(_ error: Error) {
        guard isEnabled else { return }
        
        print("❌ [API ERROR] \(error.localizedDescription)")
    }
    
    // MARK: - Private Methods
    
    private func buildRequestLog(for request: URLRequest) -> String {
        let components = [
            buildSeparator("📤 REQUEST"),
            buildURLLog(request.url),
            buildMethodLog(request.httpMethod),
            buildHeadersLog(request.allHTTPHeaderFields),
            buildBodyLog(request.httpBody),
            buildDivider()
        ]
        
        return components
            .compactMap { $0 }
            .joined(separator: "\n")
    }
    
    private func buildResponseLog(for response: HTTPURLResponse, data: Data) -> String {
        let components = [
            buildSeparator("📥 RESPONSE"),
            buildStatusLog(response.statusCode),
            buildURLLog(response.url),
            buildResponseBodyLog(data),
            buildSeparator("")
        ]
        
        return components
            .compactMap { $0 }
            .joined(separator: "\n")
    }
    
    private func buildSeparator(_ title: String) -> String {
        let separator = String(repeating: "=", count: 60)
        return title.isEmpty ? separator : "\n\(separator)\n\(title)\n\(separator)"
    }
    
    private func buildDivider() -> String {
        String(repeating: "-", count: 60)
    }
    
    private func buildURLLog(_ url: URL?) -> String? {
        guard let url = url else { return nil }
        return "🔗 URL: \(url.absoluteString)"
    }
    
    private func buildMethodLog(_ method: String?) -> String? {
        guard let method = method else { return nil }
        return "📋 Method: \(method)"
    }
    
    private func buildStatusLog(_ statusCode: Int) -> String {
        let emoji = statusEmoji(for: statusCode)
        return "\(emoji) Status: \(statusCode)"
    }
    
    private func buildHeadersLog(_ headers: [String: String]?) -> String? {
        guard let headers = headers, !headers.isEmpty else { return nil }
        
        let headerLines = headers
            .map { "   \($0.key): \($0.value)" }
            .joined(separator: "\n")
        
        return "📎 Headers:\n\(headerLines)"
    }
    
    private func buildBodyLog(_ body: Data?) -> String? {
        guard let body = body else { return nil }
        
        let bodyString = formatJSONData(body) ?? 
                        String(data: body, encoding: .utf8) ?? 
                        "Unable to decode body"
        
        return "📦 Body:\n\(bodyString)"
    }
    
    private func buildResponseBodyLog(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        
        let bodyString = formatJSONData(data) ?? 
                        String(data: data, encoding: .utf8) ?? 
                        "Unable to decode response"
        
        return "📦 Body:\n\(bodyString)"
    }
    
    private func formatJSONData(_ data: Data) -> String? {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    private func statusEmoji(for statusCode: Int) -> String {
        switch statusCode {
        case 200...299: return "✅"
        case 300...399: return "↩️"
        case 400...499: return "⚠️"
        case 500...599: return "🔥"
        default: return "❓"
        }
    }
}

// MARK: - Silent Logger for Production

public struct SilentNetworkLogger: NetworkLogger {
    public init() {}
    
    public func logRequest(_ request: URLRequest) {}
    public func logResponse(_ response: HTTPURLResponse, data: Data) {}
    public func logError(_ error: Error) {}
}