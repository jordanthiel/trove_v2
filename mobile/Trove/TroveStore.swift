import SwiftUI

@MainActor
final class TroveStore: ObservableObject {
    @Published var userID: UUID?
    @Published var email = ""
    @Published var events: [RegistryEvent] = []
    @Published var lists: [WishList] = []
    @Published var links: [EventList] = []
    @Published var profiles: [Profile] = []
    @Published var items: [GiftItem] = []
    @Published var loading = false
    @Published var starting = true
    @Published var error: String?
    let client = SupabaseClient.shared
    var ownLists: [WishList] { lists.filter { $0.user_id == userID } }
    var displayName: String { profiles.first { $0.id == userID }?.display_name ?? "You" }
    func name(for id: UUID) -> String { profiles.first { $0.id == id }?.display_name ?? "Member" }
    func events(for list: WishList) -> [RegistryEvent] { events.filter { event in links.contains { $0.event_id == event.id && $0.list_id == list.id } } }
    func lists(for event: RegistryEvent) -> [WishList] { lists.filter { list in links.contains { $0.event_id == event.id && $0.list_id == list.id } } }
    func items(for list: WishList) -> [GiftItem] { items.filter { $0.list_id == list.id } }
    func boot() async {
        defer { starting = false }
        guard client.session != nil else { return }
        do { try await client.restore(); try await signedIn() } catch { self.error = error.localizedDescription }
    }
    func signedIn() async throws {
        userID = client.session?.user.id; email = client.session?.user.email ?? ""
        _ = try await client.rpc("trove_ensure_profile")
        try await refresh()
    }
    func refresh() async throws {
        guard let snapshotUser = userID else { return }
        loading = true; defer { loading = false }
        // Apply one complete snapshot so a failed load doesn't erase visible data.
        async let eventRows: [RegistryEvent] = client.rows("events", query: "select=id,name,date,sharing_code,owner_id,timezone&order=date.asc")
        async let listRows: [WishList] = client.rows("lists", query: "select=id,user_id,name&order=created_at.desc")
        async let linkRows: [EventList] = client.rows("event_lists", query: "select=event_id,list_id")
        async let profileRows: [Profile] = client.rows("profiles", query: "select=id,display_name")
        async let itemRows: [GiftItem] = client.rows("list_items_with_privacy", query: "select=*&order=created_at.asc")
        let snapshot = try await (eventRows,listRows,linkRows,profileRows,itemRows)
        guard userID == snapshotUser else { return }
        events = snapshot.0; lists = snapshot.1; links = snapshot.2; profiles = snapshot.3; items = snapshot.4
    }
    func reload() async { do { try await refresh() } catch { self.error = error.localizedDescription } }
    func createEvent(name: String, date: Date) async throws {
        guard let userID else { return }
        try await client.insert("events", values: ["name": name.trimmingCharacters(in: .whitespacesAndNewlines), "date": RegistryEvent.formatter.string(from: date), "owner_id": userID.uuidString, "timezone": TimeZone.current.identifier])
        try await refresh()
    }
    func join(code: String) async throws {
        guard let userID else { return }
        let data = try await client.rpc("join_event_by_code", values: ["p_sharing_code": code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), "p_user_id": userID.uuidString])
        let result = try JSONDecoder().decode(JoinResult.self, from: data)
        guard result.success || result.error == "Already a member" else { throw APIError(message: result.error ?? "Unable to join this event.") }
        try await refresh()
    }
    func createList(name: String) async throws {
        guard let userID else { return }
        try await client.insert("lists", values: ["name": name.trimmingCharacters(in: .whitespacesAndNewlines), "user_id": userID.uuidString])
        try await refresh()
    }
    func share(_ list: WishList, in event: RegistryEvent, enabled: Bool) async throws {
        if enabled {
            try await client.insert("event_lists", values: ["event_id": event.id.uuidString, "list_id": list.id.uuidString])
        } else {
            try await client.delete("event_lists", query: "event_id=eq.\(event.id.uuidString)&list_id=eq.\(list.id.uuidString)")
        }
        try await refresh()
    }
    func saveItem(list: WishList, existing: GiftItem?, name: String, notes: String, link: String, price: String, imageURL: String) async throws {
        var values: [String: Any] = ["name": name.trimmingCharacters(in: .whitespacesAndNewlines), "description": notes.isEmpty ? NSNull() : notes as Any, "link": link.isEmpty ? NSNull() : link as Any]
        values["image_url"] = imageURL.isEmpty ? NSNull() : imageURL as Any
        let normalizedPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedPrice.isEmpty { values["price"] = NSNull() }
        else {
            guard let amount = Decimal(string: normalizedPrice.replacingOccurrences(of: ",", with: ".")), amount >= 0, amount < 100_000_000 else { throw APIError(message: "Enter a valid price, such as 29.99.") }
            values["price"] = NSDecimalNumber(decimal: amount)
        }
        if !link.isEmpty {
            guard let url = URL(string: link), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw APIError(message: "Enter a full product link beginning with https://.") }
        }
        if let existing { try await client.update("list_items", id: existing.id, values: values) }
        else { values["list_id"] = list.id.uuidString; try await client.insert("list_items", values: values) }
        try await refresh()
    }
    func claim(_ item: GiftItem, claim: Bool) async throws {
        _ = try await client.rpc("trove_claim_item", values: ["p_item_id": item.id.uuidString, "p_claim": claim])
        try await refresh()
    }
    func deleteItem(_ item: GiftItem) async throws {
        try await client.delete("list_items", query: "id=eq.\(item.id.uuidString)"); try await refresh()
    }
    func deleteList(_ list: WishList) async throws {
        try await client.delete("lists", query: "id=eq.\(list.id.uuidString)"); try await refresh()
    }
    func deleteEvent(_ event: RegistryEvent) async throws {
        try await client.delete("events", query: "id=eq.\(event.id.uuidString)"); try await refresh()
    }
    func leave(_ event: RegistryEvent) async throws {
        guard let userID else { return }
        // Remove your wish lists from this event before leaving membership.
        for list in ownLists where links.contains(where: { $0.event_id == event.id && $0.list_id == list.id }) {
            try await client.delete("event_lists", query: "event_id=eq.\(event.id.uuidString)&list_id=eq.\(list.id.uuidString)")
        }
        try await client.delete("event_members", query: "event_id=eq.\(event.id.uuidString)&user_id=eq.\(userID.uuidString)")
        try await refresh()
    }
    func signOut() async {
        await client.signOut(); userID = nil; email = ""; events = []; lists = []; links = []; profiles = []; items = []; error = nil
    }
}
