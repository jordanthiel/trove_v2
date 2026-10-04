import SwiftUI

struct EventDetailView: View {
    @EnvironmentObject var store: TroveStore
    @Environment(\.dismiss) private var dismiss
    let event: RegistryEvent
    @State private var sharing = false
    @State private var removing = false
    @State private var busy = false
    @State private var error: String?
    var current: RegistryEvent { store.events.first { $0.id == event.id } ?? event }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Label(current.eventDate.formatted(date: .long, time: .omitted), systemImage: "calendar").font(.subheadline)
                    Text(current.name).font(.system(size: 34, weight: .medium, design: .serif))
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YOUR EVENT CODE").font(.caption2.weight(.semibold)).tracking(2)
                            Text(current.sharing_code).font(.system(size: 28, weight: .semibold, design: .monospaced)).tracking(3).textSelection(.enabled)
                        }
                        Spacer()
                        ShareLink(item: "Join \(current.name) on Trove! Open the app, tap Join with a code, and enter \(current.sharing_code).") {
                            Image(systemName: "square.and.arrow.up").font(.title2).padding(14).background(.white.opacity(0.16), in: Circle())
                        }.accessibilityLabel("Share event code")
                    }
                    Text(current.hasPassed ? "This celebration has passed. Gift details appear after every event linked to a list has passed." : "Share this code so friends and family can join.")
                        .font(.caption).foregroundStyle(.white.opacity(0.8)).lineSpacing(3)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24).foregroundStyle(.white).background(TroveStyle.green, in: RoundedRectangle(cornerRadius: 26))
                PrimaryButton(title: "Share my wish lists here", icon: "gift") { sharing = true }
                SectionTitle(title: "Everyone’s wish lists", detail: "\(store.lists(for: current).count)")
                if store.lists(for: current).isEmpty { EmptyCard(icon: "gift", title: "The wishes are on their way", message: "Share a wish list here, and invite others to add theirs.") }
                ForEach(store.lists(for: current)) { list in
                    NavigationLink { ListDetailView(list: list) } label: {
                        WishListCard(list: list, owner: list.user_id == store.userID ? "You" : store.name(for: list.user_id), itemCount: store.items(for: list).count, eventCount: store.events(for: list).count)
                    }.buttonStyle(.plain)
                }
                Button(current.owner_id == store.userID ? "Delete event" : "Leave event", role: .destructive) { removing = true }
                    .font(.subheadline).frame(maxWidth: .infinity).padding(.top, 10).disabled(busy)
            }.padding(22)
        }.navigationTitle("Celebration").navigationBarTitleDisplayMode(.inline).troveScreen().refreshable { await store.reload() }
            .sheet(isPresented: $sharing) { ShareListsView(event: current) }
            .errorAlert($error)
            .confirmationDialog(current.owner_id == store.userID ? "Delete this event for everyone? Wish lists will be kept." : "Leave this event? Your wish lists will be unshared from it.", isPresented: $removing, titleVisibility: .visible) {
                Button(current.owner_id == store.userID ? "Delete event" : "Leave event", role: .destructive) {
                    busy = true
                    Task {
                        defer { busy = false }
                        do {
                            if current.owner_id == store.userID { try await store.deleteEvent(current) } else { try await store.leave(current) }
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }
                }
            }
    }
}
struct ListDetailView: View {
    @EnvironmentObject var store: TroveStore
    @Environment(\.dismiss) private var dismiss
    let list: WishList
    @State private var adding = false
    @State private var editing: GiftItem?
    @State private var sharing = false
    @State private var deleting = false
    @State private var error: String?
    @State private var workingID: UUID?
    var owned: Bool { list.user_id == store.userID }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(owned ? "A few things you’d love." : "A few things \(store.name(for: list.user_id)) would love.")
                    .font(.subheadline).foregroundStyle(TroveStyle.muted)
                if owned {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "eye.slash")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Let it be a surprise").font(.subheadline.weight(.semibold))
                            Text("Purchase details stay hidden until every linked event has passed. Friends see claims across all shared events.")
                                .font(.caption).lineSpacing(3)
                        }
                    }.foregroundStyle(TroveStyle.green).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 20))
                    Button { sharing = true } label: {
                        HStack { Label("Shared events", systemImage: "calendar"); Spacer(); Text("\(store.events(for: list).count)"); Image(systemName: "chevron.right").font(.caption) }
                            .font(.subheadline.weight(.medium)).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                }
                if store.items(for: list).isEmpty { EmptyCard(icon: "gift", title: owned ? "Start with something you love" : "No wishes just yet", message: owned ? "Add an item, a product link, and any details that make it yours." : "Check back when this person has added items to their list.") }
                ForEach(store.items(for: list)) { item in
                    GiftCard(item: item, owned: owned, currentUser: store.userID, busy: workingID == item.id,
                             canClaim: store.events(for: list).contains { !$0.hasPassed },
                             edit: { editing = item }, claim: { changeClaim(item) }, remove: { remove(item) })
                }
                if owned {
                    PrimaryButton(title: "Add a wish", icon: "plus") { adding = true }
                    Button("Delete wish list", role: .destructive) { deleting = true }.font(.subheadline).frame(maxWidth: .infinity).padding(.top, 8)
                }
            }.padding(22)
        }.navigationTitle(list.name).troveScreen().refreshable { await store.reload() }
            .toolbar { if owned { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add an item") } }
            .sheet(isPresented: $adding) { ItemEditorView(list: list, item: nil) }
            .sheet(item: $editing) { item in ItemEditorView(list: list, item: item) }
            .sheet(isPresented: $sharing) { ShareEventsView(list: list) }
            .errorAlert($error)
            .confirmationDialog("Delete this list and all its items? It will be removed from every event.", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete wish list", role: .destructive) { Task { do { try await store.deleteList(list); dismiss() } catch { self.error = error.localizedDescription } } }
            }
    }
    private func changeClaim(_ item: GiftItem) {
        workingID = item.id
        Task { defer { workingID = nil }; do { try await store.claim(item, claim: !item.is_purchased) } catch { self.error = error.localizedDescription; await store.reload() } }
    }
    private func remove(_ item: GiftItem) {
        workingID = item.id
        Task { defer { workingID = nil }; do { try await store.deleteItem(item) } catch { self.error = error.localizedDescription } }
    }
}
struct GiftCard: View {
    let item: GiftItem
    let owned: Bool
    let currentUser: UUID?
    let busy: Bool
    let canClaim: Bool
    let edit: () -> Void
    let claim: () -> Void
    let remove: () -> Void
    @State private var deleting = false
    @State private var undoing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ProductImage(url: item.image_url)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name).font(.headline).foregroundStyle(TroveStyle.ink)
                    if let price = item.price { Text(price, format: .currency(code: "USD")).font(.subheadline).foregroundStyle(TroveStyle.green) }
                }
                Spacer(minLength: 0)
                if owned {
                    Menu {
                        Button("Edit item", systemImage: "pencil", action: edit)
                        Button("Delete item", systemImage: "trash", role: .destructive) { deleting = true }
                    } label: { Image(systemName: "ellipsis").padding(8) }.accessibilityLabel("Item options")
                }
            }
            if let notes = item.description, !notes.isEmpty { Text(notes).font(.subheadline).foregroundStyle(TroveStyle.muted).lineSpacing(3) }
            if let link = item.link, let url = URL(string: link), ["https", "http"].contains(url.scheme ?? "") {
                Link(destination: url) { Label("View product", systemImage: "arrow.up.right").font(.subheadline.weight(.medium)) }
            }
            if item.is_purchased {
                Label(item.purchased_by_user_id == currentUser ? "You’ve claimed this gift" : "Claimed by \(item.purchaser_name ?? "another member")", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(TroveStyle.green)
                if !owned && item.purchased_by_user_id == currentUser {
                    Button { undoing = true } label: { if busy { ProgressView() } else { Text("Undo my claim").font(.caption.weight(.medium)) } }.disabled(busy)
                }
            } else if !owned {
                if canClaim {
                    PrimaryButton(title: "I purchased this", icon: "checkmark", busy: busy, action: claim)
                } else { Text("This celebration has passed.").font(.caption).foregroundStyle(TroveStyle.muted) }
            }
        }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
            .confirmationDialog("Delete \(item.name)?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete item", role: .destructive, action: remove) }
            .confirmationDialog("Make this gift available for someone else to purchase?", isPresented: $undoing, titleVisibility: .visible) { Button("Undo my claim", action: claim) }
    }
}
