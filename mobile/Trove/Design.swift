import SwiftUI

enum TroveStyle {
    static let ink = Color(red: 0.12, green: 0.22, blue: 0.20)
    static let green = Color(red: 0.16, green: 0.36, blue: 0.30)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.92)
    static let peach = Color(red: 0.94, green: 0.79, blue: 0.64)
    static let muted = Color(red: 0.43, green: 0.48, blue: 0.43)
}
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var busy = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy { ProgressView().tint(.white) }
                else if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .foregroundStyle(.white).background(TroveStyle.green, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).disabled(busy)
    }
}
struct EmptyCard: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 30, weight: .light)).foregroundStyle(TroveStyle.green)
                .frame(width: 72, height: 72).background(TroveStyle.cream, in: Circle())
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(TroveStyle.ink)
            Text(message).font(.subheadline).foregroundStyle(TroveStyle.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(28).background(.white, in: RoundedRectangle(cornerRadius: 24))
    }
}
struct SectionTitle: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title2.weight(.semibold)).foregroundStyle(TroveStyle.ink)
            Spacer()
            if let detail { Text(detail).font(.caption.weight(.medium)).foregroundStyle(TroveStyle.muted) }
        }
    }
}
struct EventCard: View {
    let event: RegistryEvent
    let listCount: Int
    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 3) {
                Text(event.eventDate.formatted(.dateTime.month(.abbreviated)).uppercased()).font(.caption2.weight(.bold))
                Text(event.eventDate.formatted(.dateTime.day())).font(.title.weight(.medium))
            }.foregroundStyle(TroveStyle.green).frame(width: 64, height: 72).background(TroveStyle.cream, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(event.name).font(.headline).foregroundStyle(TroveStyle.ink)
                Text("\(listCount) wish \(listCount == 1 ? "list" : "lists") · \(event.hasPassed ? "Past event" : "Upcoming")")
                    .font(.caption).foregroundStyle(TroveStyle.muted)
                Text(event.sharing_code).font(.caption.monospaced().weight(.semibold)).tracking(2).foregroundStyle(TroveStyle.green)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(TroveStyle.muted)
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}
struct WishListCard: View {
    let list: WishList
    let owner: String
    let itemCount: Int
    let eventCount: Int
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "gift").font(.title2).foregroundStyle(TroveStyle.green)
                .frame(width: 56, height: 56).background(TroveStyle.cream, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(list.name).font(.headline).foregroundStyle(TroveStyle.ink)
                Text("\(owner) · \(itemCount) \(itemCount == 1 ? "item" : "items")").font(.caption).foregroundStyle(TroveStyle.muted)
                if eventCount > 0 { Text("Shared in \(eventCount) \(eventCount == 1 ? "event" : "events")").font(.caption2).foregroundStyle(TroveStyle.green) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(TroveStyle.muted)
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}
extension View {
    func troveScreen() -> some View {
        self.background(TroveStyle.cream.ignoresSafeArea()).toolbarBackground(TroveStyle.cream, for: .navigationBar)
    }
    func errorAlert(_ error: Binding<String?>) -> some View {
        alert("Something needs attention", isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } })) {
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: { Text(error.wrappedValue ?? "") }
    }
}

struct ProductImage: View {
    let url: String?
    var size: CGFloat = 72
    var body: some View {
        Group {
            if let url, let address = URL(string: url), address.scheme == "https" {
                AsyncImage(url: address) { phase in
                    if let image = phase.image { image.resizable().scaledToFit().padding(5) }
                    else if phase.error != nil { placeholder }
                    else { ProgressView().tint(TroveStyle.green) }
                }
            } else { placeholder }
        }.frame(width: size, height: size)
            .background(TroveStyle.cream, in: RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityLabel("Product photo")
    }
    private var placeholder: some View { Image(systemName: "gift").font(.title2).foregroundStyle(TroveStyle.green) }
}
