import Foundation
import Security

/// Uses Supabase Auth and PostgREST with the public anon key only.
/// Tokens live in Keychain; server keys never enter the app.
@MainActor
final class SupabaseClient {
    static let shared = SupabaseClient()
    private let baseURL: String
    private let publicKey: String
    private let keychainAccount = "trove.supabase.session"
    private var refreshTask: Task<Session, Error>?
    var session: Session?

    init() {
        let config = Bundle.main.url(forResource: "Configuration", withExtension: "plist")
            .flatMap { NSDictionary(contentsOf: $0) } ?? [:]
        baseURL = config["SupabaseURL"] as? String ?? ""
        publicKey = config["SupabaseAnonKey"] as? String ?? ""
        session = readSession()
    }
    func signIn(email: String, password: String) async throws {
        let data = try await request("/auth/v1/token?grant_type=password", method: "POST", body: ["email": email, "password": password], authenticated: false)
        try save(JSONDecoder().decode(Session.self, from: data))
    }
    func signUp(name: String, email: String, password: String) async throws -> Bool {
        let data = try await request("/auth/v1/signup", method: "POST", body: ["email": email, "password": password, "data": ["display_name": name]], authenticated: false)
        if let signedIn = try? JSONDecoder().decode(Session.self, from: data) { try save(signedIn); return true }
        return false
    }
    func signOut() async {
        // Local sign-out remains available while offline.
        _ = try? await request("/auth/v1/logout?scope=local", method: "POST")
        session = nil; refreshTask?.cancel(); refreshTask = nil
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: "com.jordanthiel.trove-rn", kSecAttrAccount: keychainAccount] as CFDictionary)
    }
    func restore() async throws {
        guard session != nil else { return }
        _ = try await token()
    }
    func rows<T: Decodable>(_ table: String, query: String = "select=*") async throws -> T {
        let data = try await request("/rest/v1/\(table)?\(query)")
        return try JSONDecoder().decode(T.self, from: data)
    }
    func insert(_ table: String, values: [String: Any]) async throws {
        _ = try await request("/rest/v1/\(table)", method: "POST", body: values)
    }
    func update(_ table: String, id: UUID, values: [String: Any]) async throws {
        _ = try await request("/rest/v1/\(table)?id=eq.\(id.uuidString)", method: "PATCH", body: values)
    }
    func delete(_ table: String, query: String) async throws {
        _ = try await request("/rest/v1/\(table)?\(query)", method: "DELETE")
    }
    func rpc(_ name: String, values: [String: Any] = [:]) async throws -> Data {
        try await request("/rest/v1/rpc/\(name)", method: "POST", body: values)
    }
    func productPreview(link: String) async throws -> ProductPreview {
        do {
            let data = try await request("/functions/v1/product-preview", method: "POST", body: ["link": link])
            return try JSONDecoder().decode(ProductPreviewResponse.self, from: data).product
        } catch {
            try Task.checkCancellation()
            let page = try await ProductPageLoader().load(link)
            let data = try await request("/functions/v1/product-preview", method: "POST", body: ["link": page.link, "html": page.html])
            return try JSONDecoder().decode(ProductPreviewResponse.self, from: data).product
        }
    }
    private func token() async throws -> String {
        guard let current = session else { throw APIError(message: "Please sign in to continue.") }
        // Refresh older servers' sessions when expires_at is absent too.
        if let expiry = current.expires_at, expiry > Date().timeIntervalSince1970 + 90 { return current.access_token }
        if let task = refreshTask { return try await task.value.access_token }
        let task = Task<Session, Error> {
            let data = try await self.request("/auth/v1/token?grant_type=refresh_token", method: "POST", body: ["refresh_token": current.refresh_token], authenticated: false)
            return try JSONDecoder().decode(Session.self, from: data)
        }
        refreshTask = task
        defer { refreshTask = nil }
        let refreshed = try await task.value
        try save(refreshed)
        return refreshed.access_token
    }
    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil, authenticated: Bool = true) async throws -> Data {
        guard !publicKey.isEmpty, let url = URL(string: baseURL + path) else { throw APIError(message: "Supabase configuration is missing. Run scripts/configure.py and rebuild.") }
        var req = URLRequest(url: url); req.httpMethod = method; req.timeoutInterval = 25
        req.setValue(publicKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated { req.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "Unable to reach Trove. Try again.") }
        guard (200..<300).contains(http.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = payload?["msg"] as? String ?? payload?["message"] as? String ?? payload?["error_description"] as? String ?? payload?["error"] as? String ?? "Request failed (\(http.statusCode))."
            throw APIError(message: message)
        }
        return data
    }
    private func save(_ value: Session) throws {
        let data = try JSONEncoder().encode(value)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.jordanthiel.trove-rn", kSecAttrAccount as String: keychainAccount]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw APIError(message: "Could not securely save your sign-in (\(status)).") }
        session = value
    }
    private func readSession() -> Session? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.jordanthiel.trove-rn", kSecAttrAccount as String: keychainAccount, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }
}
