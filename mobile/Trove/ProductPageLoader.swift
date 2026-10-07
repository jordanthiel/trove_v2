import Foundation

/// Amazon shares may contain a product title and a short URL on separate lines.
enum ProductLink {
    static func extract(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let url = URL(string: text), ProductPageLoader.allowed(url), !text.contains(where: { $0.isWhitespace }) {
            return url.absoluteString
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            if let url = match.url, ProductPageLoader.allowed(url) { return url.absoluteString }
        }
        return nil
    }
}

/// Some stores reject cloud traffic but allow previews from a user's device.
/// Uses a separate ephemeral session with no cookies or Supabase credentials.
final class ProductPageLoader: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static func allowed(_ url: URL) -> Bool {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host?.lowercased(),
              host.contains("."), !host.contains(":"), url.user == nil, url.password == nil,
              url.port == nil, url.absoluteString.count <= 4096 else { return false }
        let forbidden = [".local", ".localhost", ".internal", ".invalid", ".test"]
        return !forbidden.contains(where: host.hasSuffix) && host.split(separator: ".").contains(where: { Int($0) == nil })
    }
    static func productURL(_ link: String) -> URL? {
        guard let normalized = ProductLink.extract(link), let url = URL(string: normalized), allowed(url) else { return nil }
        guard let host = url.host, host.range(of: #"(^|\.)amazon\.(com|ca|co\.uk|com\.au|de|fr|it|es|co\.jp|in|com\.mx)$"#, options: .regularExpression) != nil,
              let match = url.path.range(of: #"/(?:dp|gp/product|gp/aw/d)/[A-Za-z0-9]{10}(?=/|$)"#, options: .regularExpression),
              let asin = url.path[match].split(separator: "/").last,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.path = "/dp/" + asin.uppercased()
        components.queryItems = components.queryItems?.filter { ["th", "psc"].contains($0.name) }
        components.fragment = nil
        return components.url
    }
    func load(_ link: String) async throws -> (html: String, link: String) {
        guard let url = Self.productURL(link) else { throw APIError(message: "Use a public product page link.") }
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let finalURL = response.url, Self.allowed(finalURL),
              ["text/html", "application/xhtml+xml"].contains(response.mimeType ?? "") else {
            throw APIError(message: "The store could not share its product page.")
        }
        let limit = 6_000_000
        guard response.expectedContentLength <= limit else { throw APIError(message: "This page is too large to preview.") }
        var data = Data(); data.reserveCapacity(100_000)
        for try await byte in bytes {
            if data.count >= limit { throw APIError(message: "This page is too large to preview.") }
            data.append(byte)
        }
        try Task.checkCancellation()
        let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        return (html, finalURL.absoluteString)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.flatMap { Self.allowed($0) ? request : nil })
    }
}
