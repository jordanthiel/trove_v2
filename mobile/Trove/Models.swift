import Foundation

struct Profile: Codable, Identifiable { let id: UUID; var display_name: String }
struct RegistryEvent: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var date: String
    let sharing_code: String
    let owner_id: UUID
    var timezone: String
    var eventDate: Date { Self.formatter.date(from: date) ?? Date() }
    var hasPassed: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .current
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return false }
        return calendar.startOfDay(for: Date()) > day
    }
    static var formatter: DateFormatter {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }
}
struct WishList: Codable, Identifiable, Hashable { let id: UUID; let user_id: UUID; var name: String }
struct EventList: Codable { let event_id: UUID; let list_id: UUID }
struct GiftItem: Codable, Identifiable {
    let id: UUID
    let list_id: UUID
    var name: String
    var description: String?
    var link: String?
    var image_url: String?
    var price: Decimal?
    var purchased_by_user_id: UUID?
    var purchased_at: String?
    var is_purchased: Bool
    var purchase_hidden: Bool
    var purchaser_name: String?
}
struct AuthUser: Codable { let id: UUID; let email: String? }
struct Session: Codable {
    let access_token: String
    let refresh_token: String
    let expires_at: Double?
    let expires_in: Double?
    let user: AuthUser
}
struct JoinResult: Codable { let success: Bool; let error: String?; let event_id: UUID? }
struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct ProductPreview: Codable {
    let name: String?
    let description: String?
    let price: Decimal?
    let currency: String?
    let image_url: String?
    let link: String
}
struct ProductPreviewResponse: Codable { let product: ProductPreview }
