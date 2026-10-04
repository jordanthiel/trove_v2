import SwiftUI

@main
struct TroveApp: App {
    @StateObject private var store = TroveStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(TroveStyle.green).preferredColorScheme(.light)
        }
    }
}
struct RootView: View {
    @EnvironmentObject var store: TroveStore
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Group {
            if store.starting {
                VStack(spacing: 18) {
                    Image(systemName: "gift").font(.system(size: 48, weight: .light)).foregroundStyle(TroveStyle.green)
                    Text("trove").font(.system(size: 42, design: .serif))
                    ProgressView()
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(TroveStyle.cream)
            } else if store.userID == nil { AuthView() }
            else { MainTabs() }
        }
        .task { await store.boot() }
        .onChange(of: phase) { _, newValue in
            if newValue == .active && !store.starting { Task { await store.reload() } }
        }
        .errorAlert($store.error)
    }
}
struct MainTabs: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("Home", systemImage: "house") }
            NavigationStack { EventsView() }.tabItem { Label("Events", systemImage: "calendar") }
            NavigationStack { MyListsView() }.tabItem { Label("My lists", systemImage: "gift") }
            NavigationStack { ThankYouView() }.tabItem { Label("Thank you", systemImage: "heart.text.square") }
            NavigationStack { AccountView() }.tabItem { Label("Account", systemImage: "person.crop.circle") }
        }.toolbarBackground(.white, for: .tabBar)
    }
}
struct AuthView: View {
    @EnvironmentObject var store: TroveStore
    @State private var signingUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var confirmation = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    Text("trove").font(.system(size: 36, design: .serif)).foregroundStyle(TroveStyle.ink)
                    Spacer()
                    Image(systemName: "gift").font(.title).foregroundStyle(TroveStyle.green)
                }.padding(.top, 28)
                ZStack {
                    Circle().fill(TroveStyle.peach.opacity(0.45)).frame(width: 180, height: 180).offset(x: 65, y: -5)
                    RoundedRectangle(cornerRadius: 32).fill(TroveStyle.green).frame(width: 140, height: 145).rotationEffect(.degrees(-8))
                    Image(systemName: "gift.fill").font(.system(size: 66, weight: .light)).foregroundStyle(TroveStyle.cream).rotationEffect(.degrees(-8))
                    Image(systemName: "sparkle").font(.system(size: 25)).foregroundStyle(TroveStyle.green).offset(x: -106, y: -65)
                }.frame(maxWidth: .infinity).frame(height: 200).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Thoughtful gifts.\nWonderful surprises.").font(.system(size: 36, weight: .medium, design: .serif)).foregroundStyle(TroveStyle.ink)
                    Text("A little less guessing. A lot more giving. Share your wishes and celebrate together.").font(.subheadline).foregroundStyle(TroveStyle.muted).lineSpacing(4)
                }
                VStack(spacing: 14) {
                    if signingUp { field("Your name", text: $name, content: .name) }
                    field("Email address", text: $email, content: .emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    SecureField("Password", text: $password).textContentType(signingUp ? .newPassword : .password)
                        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("auth.password")
                    if signingUp { Text("Use at least 8 characters. You may need to confirm your email.").font(.caption).foregroundStyle(TroveStyle.muted).frame(maxWidth: .infinity, alignment: .leading) }
                    PrimaryButton(title: signingUp ? "Create your account" : "Sign in", icon: "arrow.right", busy: busy) { submit() }
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || (signingUp && (name.trimmingCharacters(in: .whitespaces).isEmpty || password.count < 8)))
                        .accessibilityIdentifier("auth.submit")
                    Button(signingUp ? "Already have an account? Sign in" : "New to Trove? Create an account") { signingUp.toggle() }
                        .font(.subheadline.weight(.medium)).padding(.top, 4).disabled(busy)
                }
            }.padding(26).frame(maxWidth: 560)
        }.frame(maxWidth: .infinity).background(TroveStyle.cream.ignoresSafeArea()).scrollDismissesKeyboard(.interactively)
            .errorAlert($error)
            .alert("Check your inbox", isPresented: $confirmation) { Button("OK", role: .cancel) {} } message: { Text("Confirm your email address, then return to Trove and sign in.") }
    }
    private func field(_ title: String, text: Binding<String>, content: UITextContentType) -> some View {
        TextField(title, text: text).textContentType(content).autocorrectionDisabled().padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
    private func submit() {
        busy = true
        Task {
            defer { busy = false }
            do {
                let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
                if signingUp {
                    let ready = try await store.client.signUp(name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: address, password: password)
                    if !ready { signingUp = false; confirmation = true; return }
                } else { try await store.client.signIn(email: address, password: password) }
                try await store.signedIn()
            } catch { self.error = error.localizedDescription }
        }
    }
}
