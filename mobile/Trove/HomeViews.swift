import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: TroveStore
    @State private var newEvent = false
    @State private var joinEvent = false
    @State private var newList = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("trove").font(.system(size: 34, design: .serif))
                    Spacer()
                    Text(String(store.displayName.prefix(1)).uppercased()).font(.headline)
                        .frame(width: 42, height: 42).background(TroveStyle.peach.opacity(0.55), in: Circle())
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Make room for\na little joy.").font(.system(size: 37, weight: .medium, design: .serif))
                    Text("Your people. Your wishes. All together.").font(.subheadline).foregroundStyle(TroveStyle.muted)
                }.padding(.vertical, 8)
                HStack(spacing: 12) {
                    Button { newEvent = true } label: {
                        VStack(alignment: .leading, spacing: 20) {
                            Image(systemName: "calendar.badge.plus").font(.title2)
                            Text("Create an event").font(.headline)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                            .foregroundStyle(.white).background(TroveStyle.green, in: RoundedRectangle(cornerRadius: 22))
                    }
                    Button { joinEvent = true } label: {
                        VStack(alignment: .leading, spacing: 20) {
                            Image(systemName: "person.2.badge.plus").font(.title2)
                            Text("Join with a code").font(.headline)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                            .foregroundStyle(TroveStyle.ink).background(TroveStyle.peach.opacity(0.6), in: RoundedRectangle(cornerRadius: 22))
                    }
                }.buttonStyle(.plain)
                SectionTitle(title: "On the calendar", detail: "\(store.events.filter { !$0.hasPassed }.count) upcoming")
                if store.events.filter({ !$0.hasPassed }).isEmpty { EmptyCard(icon: "calendar", title: "A reason to celebrate", message: "Create a birthday, holiday, or special occasion—or join one with an event code. Past celebrations are in Events.") }
                ForEach(Array(store.events.filter { !$0.hasPassed }.prefix(3))) { event in
                    NavigationLink { EventDetailView(event: event) } label: { EventCard(event: event, listCount: store.lists(for: event).count) }.buttonStyle(.plain)
                }
                HStack {
                    SectionTitle(title: "Your wish lists")
                    Button { newList = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }.accessibilityLabel("Create a wish list")
                }
                if store.ownLists.isEmpty { EmptyCard(icon: "gift", title: "What’s on your wish list?", message: "Keep your favorite things in one place. You can share the same list across several events.") }
                ForEach(Array(store.ownLists.prefix(3))) { list in
                    NavigationLink { ListDetailView(list: list) } label: {
                        WishListCard(list: list, owner: "You", itemCount: store.items(for: list).count, eventCount: store.events(for: list).count)
                    }.buttonStyle(.plain)
                }
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "eye.slash").font(.title3)
                    Text("Keep the surprise. Your gift claims stay hidden until all events linked to your list have passed.").font(.caption).lineSpacing(3)
                }.foregroundStyle(TroveStyle.muted).padding(.vertical, 4)
            }.padding(22).foregroundStyle(TroveStyle.ink)
        }.troveScreen().toolbar(.hidden, for: .navigationBar).refreshable { await store.reload() }
            .sheet(isPresented: $newEvent) { CreateEventView() }
            .sheet(isPresented: $joinEvent) { JoinEventView() }
            .sheet(isPresented: $newList) { CreateListView() }
    }
}
struct EventsView: View {
    @EnvironmentObject var store: TroveStore
    @State private var create = false
    @State private var join = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Gather your favorite people.").font(.subheadline).foregroundStyle(TroveStyle.muted)
                PrimaryButton(title: "Join with an event code", icon: "person.2.badge.plus") { join = true }
                if store.events.isEmpty { EmptyCard(icon: "calendar", title: "Your next celebration", message: "Tap + to create an event and get a code to share with friends and family.") }
                ForEach(store.events) { event in
                    NavigationLink { EventDetailView(event: event) } label: { EventCard(event: event, listCount: store.lists(for: event).count) }.buttonStyle(.plain)
                }
            }.padding(22)
        }.navigationTitle("Events").troveScreen().refreshable { await store.reload() }
            .toolbar { Button { create = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create an event") }
            .sheet(isPresented: $create) { CreateEventView() }.sheet(isPresented: $join) { JoinEventView() }
    }
}
struct MyListsView: View {
    @EnvironmentObject var store: TroveStore
    @State private var create = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("One list. As many celebrations as you like.").font(.subheadline).foregroundStyle(TroveStyle.muted)
                if store.ownLists.isEmpty { EmptyCard(icon: "gift", title: "Good things start with a wish", message: "Create a list, add a few favorite things, then share it in your events.") }
                ForEach(store.ownLists) { list in
                    NavigationLink { ListDetailView(list: list) } label: { WishListCard(list: list, owner: "You", itemCount: store.items(for: list).count, eventCount: store.events(for: list).count) }.buttonStyle(.plain)
                }
                PrimaryButton(title: "Create a wish list", icon: "plus") { create = true }
            }.padding(22)
        }.navigationTitle("My lists").troveScreen().refreshable { await store.reload() }
            .toolbar { Button { create = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create a wish list") }
            .sheet(isPresented: $create) { CreateListView() }
    }
}
struct ThankYouView: View {
    @EnvironmentObject var store: TroveStore
    var received: [GiftItem] { store.items.filter { item in store.ownLists.contains { $0.id == item.list_id } && item.is_purchased && !item.purchase_hidden } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("A little gratitude goes a long way.").font(.system(size: 30, weight: .medium, design: .serif)).foregroundStyle(TroveStyle.ink)
                Text("After the last event on a list has passed, you’ll see who gave each gift here. Until then, it’s a surprise.").font(.subheadline).foregroundStyle(TroveStyle.muted).lineSpacing(4)
                if received.isEmpty { EmptyCard(icon: "heart", title: "Thank-you notes come later", message: "Received gifts will appear here after your celebrations. Enjoy the anticipation.") }
                ForEach(received) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(item.purchaser_name ?? "A thoughtful friend", systemImage: "heart.fill").font(.headline).foregroundStyle(TroveStyle.green)
                        Text(item.name).font(.title3.weight(.medium))
                        if let list = store.lists.first(where: { $0.id == item.list_id }) { Text(list.name).font(.caption).foregroundStyle(TroveStyle.muted) }
                        ShareLink(item: "Thank you, \(item.purchaser_name ?? "my friend"), for the \(item.name)! It was so thoughtful of you.") {
                            Label("Share a thank-you", systemImage: "square.and.arrow.up").font(.subheadline.weight(.semibold))
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(.white, in: RoundedRectangle(cornerRadius: 22))
                }
            }.padding(22)
        }.navigationTitle("Thank you").troveScreen().refreshable { await store.reload() }
    }
}
struct AccountView: View {
    @EnvironmentObject var store: TroveStore
    @State private var signingOut = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(String(store.displayName.prefix(1)).uppercased()).font(.largeTitle.weight(.medium)).foregroundStyle(TroveStyle.green)
                    .frame(width: 88, height: 88).background(TroveStyle.peach.opacity(0.5), in: Circle())
                VStack(spacing: 6) { Text(store.displayName).font(.title2.weight(.semibold)); Text(store.email).font(.subheadline).foregroundStyle(TroveStyle.muted) }
                VStack(alignment: .leading, spacing: 14) {
                    Label("A surprise worth keeping", systemImage: "eye.slash").font(.headline)
                    Text("Friends can see claimed gifts to avoid duplicates. You can’t see who bought your gifts—or whether they’re claimed—until the day after the last event linked to that list, in each event’s time zone.").font(.subheadline).foregroundStyle(TroveStyle.muted).lineSpacing(4)
                    Text("Claims apply to an item across all events sharing its list.").font(.caption).foregroundStyle(TroveStyle.green)
                }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 22))
                Button("Sign out", role: .destructive) { signingOut = true }.font(.headline).padding()
            }.padding(22).frame(maxWidth: .infinity)
        }.navigationTitle("Account").troveScreen()
            .confirmationDialog("Sign out of Trove?", isPresented: $signingOut, titleVisibility: .visible) { Button("Sign out", role: .destructive) { Task { await store.signOut() } } }
    }
}
