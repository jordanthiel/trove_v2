import SwiftUI

struct CreateEventView: View {
    @EnvironmentObject var store: TroveStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var date = Date()
    @State private var busy = false
    @State private var error: String?
    @State private var created: RegistryEvent?
    var body: some View {
        NavigationStack {
            Group {
                if let created {
                    VStack(spacing: 24) {
                        Image(systemName: "party.popper").font(.system(size: 54)).foregroundStyle(TroveStyle.green)
                        Text("Let’s celebrate.").font(.system(size: 34, design: .serif))
                        Text(created.name).font(.headline)
                        VStack(spacing: 12) {
                            Text("YOUR EVENT CODE").font(.caption).tracking(2)
                            Text(created.sharing_code).font(.system(size: 36, weight: .semibold, design: .monospaced)).tracking(4).textSelection(.enabled)
                        }.padding(28).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 24))
                        Text("Send this code to your people. They can enter it in Trove to join your event.").font(.subheadline).foregroundStyle(TroveStyle.muted).multilineTextAlignment(.center)
                        ShareLink(item: "Join \(created.name) on Trove! Enter event code \(created.sharing_code) in the app.") { Label("Share event code", systemImage: "square.and.arrow.up").font(.headline) }
                        PrimaryButton(title: "Done") { dismiss() }
                    }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(TroveStyle.cream)
                } else {
                    Form {
                        Section("The celebration") {
                            TextField("Event name", text: $name).accessibilityIdentifier("event.name")
                            DatePicker("Event date", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                        }
                        Section {
                            Text("You’ll get a six-character code to share. Everyone who joins can share wish lists and coordinate gifts.")
                            Text("Purchase details reveal after the event date in \(TimeZone.current.identifier). Lists linked to several events reveal after the last one.")
                        }.font(.subheadline).foregroundStyle(TroveStyle.muted)
                        Section { PrimaryButton(title: "Create event", icon: "calendar.badge.plus", busy: busy) { create() }.listRowBackground(Color.clear).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 120) }
                    }.scrollContentBackground(.hidden).background(TroveStyle.cream)
                }
            }.navigationTitle(created == nil ? "New event" : "You’re ready").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(created == nil ? "Cancel" : "Close") { dismiss() }.disabled(busy) } }.errorAlert($error)
        }.interactiveDismissDisabled(busy)
    }
    private func create() {
        busy = true
        Task {
            defer { busy = false }
            do {
                let before = Set(store.events.map(\.id))
                try await store.createEvent(name: name, date: date)
                created = store.events.first { !before.contains($0.id) }
            } catch { self.error = error.localizedDescription }
        }
    }
}
struct JoinEventView: View {
    @EnvironmentObject var store: TroveStore
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "person.2").font(.system(size: 44, weight: .light)).foregroundStyle(TroveStyle.green).padding(.top, 24)
                Text("You’re invited.").font(.system(size: 36, design: .serif)).foregroundStyle(TroveStyle.ink)
                Text("Enter the six-character code from your host to join the celebration.").font(.subheadline).foregroundStyle(TroveStyle.muted)
                TextField("ABC123", text: $code).font(.system(size: 30, weight: .semibold, design: .monospaced)).tracking(5)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled().submitLabel(.join)
                    .padding(22).background(.white, in: RoundedRectangle(cornerRadius: 20)).accessibilityIdentifier("event.code")
                    .onChange(of: code) { _, value in code = String(value.uppercased().filter { $0.isASCII && $0.isLetter || $0.isNumber }.prefix(6)) }
                    .onSubmit { if code.count == 6 && !busy { join() } }
                PrimaryButton(title: "Join event", icon: "arrow.right", busy: busy) { join() }.disabled(code.count != 6)
                Spacer()
            }.padding(26).background(TroveStyle.cream).navigationTitle("Join an event").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }.errorAlert($error)
        }.interactiveDismissDisabled(busy)
    }
    private func join() {
        busy = true
        Task { defer { busy = false }; do { try await store.join(code: code); dismiss() } catch { self.error = error.localizedDescription } }
    }
}
struct CreateListView: View {
    @EnvironmentObject var store: TroveStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Make it yours") { TextField("List name", text: $name).accessibilityIdentifier("list.name") }
                Section { Text("Try “Things I’d love” or “Birthday wishes”. Your list can stay private or be shared across several events.").font(.subheadline).foregroundStyle(TroveStyle.muted) }
                Section {
                    PrimaryButton(title: "Create wish list", icon: "gift", busy: busy) {
                        busy = true
                        Task { defer { busy = false }; do { try await store.createList(name: name); dismiss() } catch { self.error = error.localizedDescription } }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 120).listRowBackground(Color.clear)
                }
            }.scrollContentBackground(.hidden).background(TroveStyle.cream).navigationTitle("New wish list").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }.errorAlert($error)
        }.interactiveDismissDisabled(busy)
    }
}
struct ItemEditorView: View {
    @EnvironmentObject var store: TroveStore
    @Environment(\.dismiss) private var dismiss
    let list: WishList
    let item: GiftItem?
    @State private var name: String
    @State private var notes: String
    @State private var link: String
    @State private var price: String
    @State private var imageURL: String
    @State private var lastImportedLink: String
    @State private var importing = false
    @State private var importMessage: String?
    @State private var importFailed = false
    @State private var busy = false
    @State private var error: String?
    @State private var manualRevision = 0
    @State private var importRequestID: UUID?
    init(list: WishList, item: GiftItem?) {
        self.list = list; self.item = item
        _name = State(initialValue: item?.name ?? "")
        _notes = State(initialValue: item?.description ?? "")
        _link = State(initialValue: item?.link ?? "")
        _price = State(initialValue: item?.price.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
        _imageURL = State(initialValue: item?.image_url ?? "")
        _lastImportedLink = State(initialValue: item?.link ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste a product link", text: $link).keyboardType(.URL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("item.link")
                    if importing { Label { Text("Finding product details…") } icon: { ProgressView() } }
                    if let importMessage {
                        Text(importMessage).font(.caption).foregroundStyle(importFailed ? TroveStyle.muted : TroveStyle.green)
                    }
                    if validLink != nil {
                        Button(importFailed ? "Try lookup again" : "Refresh product details", systemImage: "arrow.clockwise") {
                            lastImportedLink = ""
                            Task { await importProduct(force: true) }
                        }.disabled(importing || busy)
                    }
                } header: { Text("Start with a link") } footer: {
                    Text("Paste a store’s product page to fill in the name, details, price, and photo. You can edit everything below.")
                }
                if !imageURL.isEmpty {
                    Section("Product photo") {
                        HStack { Spacer(); ProductImage(url: imageURL, size: 170); Spacer() }
                        Button("Remove photo", role: .destructive) { imageURL = ""; manualRevision += 1 }
                    }
                }
                Section("Your wish") {
                    TextField("Item name", text: userField($name)).accessibilityIdentifier("item.name")
                    TextField("Price in USD (optional)", text: userField($price)).keyboardType(.decimalPad)
                }
                Section("The details") {
                    TextField("Size, color, or anything helpful", text: userField($notes), axis: .vertical).lineLimit(3...6)
                }
                Section {
                    PrimaryButton(title: item == nil ? "Add to wish list" : "Save changes", icon: "checkmark", busy: busy) {
                        busy = true
                        Task {
                            defer { busy = false }
                            do {
                                try await store.saveItem(list: list, existing: item, name: name, notes: notes,
                                    link: link.trimmingCharacters(in: .whitespacesAndNewlines), price: price, imageURL: imageURL)
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }.disabled(importing || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 200).listRowBackground(Color.clear)
                }
            }.scrollContentBackground(.hidden).background(TroveStyle.cream)
                .navigationTitle(item == nil ? "Add a wish" : "Edit wish").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
                .errorAlert($error)
                .task(id: link) {
                    guard validLink != nil, link.trimmingCharacters(in: .whitespacesAndNewlines) != lastImportedLink else { return }
                    do { try await Task.sleep(for: .milliseconds(750)) } catch { return }
                    await importProduct()
                }
                .onChange(of: link) { _, _ in importMessage = nil; importing = false; importRequestID = nil }
        }.interactiveDismissDisabled(busy)
    }
    private var validLink: String? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http","https"].contains(url.scheme?.lowercased() ?? ""),
            let host = url.host, host.contains(".") else { return nil }
        return trimmed
    }
    private func userField(_ field: Binding<String>) -> Binding<String> {
        Binding(get: { field.wrappedValue }, set: { value in field.wrappedValue = value; manualRevision += 1 })
    }
    @MainActor private func importProduct(force: Bool = false) async {
        guard let requestedLink = validLink, requestedLink != lastImportedLink || force else { return }
        let requestID = UUID()
        importRequestID = requestID
        importing = true; importFailed = false; importMessage = nil
        let revision = manualRevision
        defer { if importRequestID == requestID { importing = false; importRequestID = nil } }
        do {
            let product = try await store.client.productPreview(link: requestedLink)
            try Task.checkCancellation()
            guard validLink == requestedLink, importRequestID == requestID else { return }
            lastImportedLink = requestedLink
            // A late result must not overwrite details the user typed while waiting.
            guard revision == manualRevision else {
                importMessage = "Details found. Tap Refresh product details to replace your edits."
                return
            }
            name = product.name ?? ""
            notes = product.description ?? ""
            imageURL = product.image_url ?? ""
            if let amount = product.price, product.currency == nil || product.currency == "USD" {
                price = NSDecimalNumber(decimal: amount).stringValue
            } else if let amount = product.price, let currency = product.currency {
                price = ""
                notes += "\nListed price: \(currency) \(NSDecimalNumber(decimal: amount).stringValue)."
            } else { price = "" }
            importMessage = "Details imported. Review them and add any preferences before saving."
        } catch {
            guard !Task.isCancelled, validLink == requestedLink, importRequestID == requestID else { return }
            importFailed = true
            importMessage = "\(error.localizedDescription) You can still enter the item manually."
        }
    }
}
struct ShareEventsView: View {
    @EnvironmentObject var store: TroveStore
    @Environment(\.dismiss) private var dismiss
    let list: WishList
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Choose the events where people can see this list. Removing an event keeps your items and any existing claims.").font(.subheadline).foregroundStyle(TroveStyle.muted) }
                if store.events.isEmpty { Section { Text("Create or join an event first, then come back to share this list.") } }
                Section("Your events") {
                    ForEach(store.events) { event in
                        Toggle(isOn: Binding(get: { store.links.contains { $0.event_id == event.id && $0.list_id == list.id } }, set: { enabled in change(event, enabled: enabled) })) {
                            VStack(alignment: .leading, spacing: 4) { Text(event.name); Text(event.eventDate.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(TroveStyle.muted) }
                        }.disabled(busy)
                    }
                }
            }.scrollContentBackground(.hidden).background(TroveStyle.cream).navigationTitle("Shared events").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(busy) } }.errorAlert($error)
        }.interactiveDismissDisabled(busy)
    }
    private func change(_ event: RegistryEvent, enabled: Bool) {
        busy = true
        Task { defer { busy = false }; do { try await store.share(list, in: event, enabled: enabled) } catch { self.error = error.localizedDescription } }
    }
}
struct ShareListsView: View {
    @EnvironmentObject var store: TroveStore
    @Environment(\.dismiss) private var dismiss
    let event: RegistryEvent
    @State private var busy = false
    @State private var error: String?
    @State private var newList = false
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Share any of your lists in \(event.name). A list can belong to more than one event.").font(.subheadline).foregroundStyle(TroveStyle.muted) }
                Section("Your wish lists") {
                    ForEach(store.ownLists) { list in
                        Toggle(list.name, isOn: Binding(get: { store.links.contains { $0.event_id == event.id && $0.list_id == list.id } }, set: { enabled in
                            busy = true
                            Task { defer { busy = false }; do { try await store.share(list, in: event, enabled: enabled) } catch { self.error = error.localizedDescription } }
                        })).disabled(busy)
                    }
                    Button("Create a wish list", systemImage: "plus") { newList = true }
                }
            }.scrollContentBackground(.hidden).background(TroveStyle.cream).navigationTitle("Share your wishes").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(busy) } }.errorAlert($error)
                .sheet(isPresented: $newList) { CreateListView() }
        }.interactiveDismissDisabled(busy)
    }
}
