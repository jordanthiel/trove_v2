import SwiftUI
import UserNotifications

@MainActor
final class ListNotifications: ObservableObject {
    static let shared = ListNotifications()
    @Published private(set) var enabled = false
    @Published private(set) var busy = false
    @Published private(set) var permissionBlocked = false
    @Published var showOffer = false
    @Published var error: String?

    private let defaults = UserDefaults.standard
    private let center = UNUserNotificationCenter.current()
    private var user: UUID?
    private var token: String?
    private var registration: Task<Void, Never>?
    private var preferenceKey: String? { user.map { "trove.listNotifications." + $0.uuidString } }
    private let installation: String = {
        let defaults = UserDefaults.standard
        let key = "trove.notificationInstallation"
        if let id = defaults.string(forKey: key) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: key)
        return id
    }()
    private var environment: String {
        Bundle.main.object(forInfoDictionaryKey: "TrovePushEnvironment") as? String ?? "development"
    }

    func activate(_ id: UUID?) async {
        guard let id else { return }
        if user != id {
            user = id
            let choice = preferenceKey.flatMap { defaults.object(forKey: $0) as? Bool }
            enabled = choice ?? false
            showOffer = choice == nil
        }
        await synchronize()
    }

    func leaveOff() {
        if let preferenceKey { defaults.set(false, forKey: preferenceKey) }
        showOffer = false
    }

    func setEnabled(_ value: Bool) async {
        guard !busy, let user, let preferenceKey else { return }
        busy = true; showOffer = false
        defer { busy = false }
        do {
            if value {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard self.user == user else { return }
                permissionBlocked = !granted
                guard granted else { leaveOff(); return }
                defaults.set(true, forKey: preferenceKey)
                enabled = true
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                enabled = false
                await registration?.value
                do { try await updateDevice(nil) }
                catch { enabled = true; throw error }
                defaults.set(false, forKey: preferenceKey)
                UIApplication.shared.unregisterForRemoteNotifications()
                center.removeAllDeliveredNotifications()
            }
        } catch { self.error = error.localizedDescription }
    }

    func synchronize() async {
        guard !busy, let user else { return }
        let settings = await center.notificationSettings()
        guard self.user == user, !busy else { return }
        let allowed = settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral
        permissionBlocked = settings.authorizationStatus == .denied
        if enabled && allowed {
            UIApplication.shared.registerForRemoteNotifications()
        } else if enabled && !allowed {
            await setEnabled(false)
        }
    }

    func receivedToken(_ data: Data) {
        guard enabled, user == SupabaseClient.shared.session?.user.id, user != nil else { return }
        let value = data.map { String(format: "%02x", $0) }.joined()
        token = value
        let previous = registration
        registration = Task {
            await previous?.value
            guard enabled, token == value, user == SupabaseClient.shared.session?.user.id, user != nil else { return }
            do { try await updateDevice(value) }
            catch { self.error = error.localizedDescription }
        }
    }

    func registrationFailed() {
        if enabled { error = "Trove couldn’t register this device for notifications. Open the app again to retry." }
    }

    func signOut() async {
        let wasEnabled = enabled
        enabled = false; user = nil; token = nil; showOffer = false
        await registration?.value
        if wasEnabled { try? await updateDevice(nil) }
        UIApplication.shared.unregisterForRemoteNotifications()
        center.removeAllDeliveredNotifications()
    }

    private func updateDevice(_ value: String?) async throws {
        _ = try await SupabaseClient.shared.rpc("trove_set_list_notifications", values: [
            "p_id": installation, "p_token": value.map { $0 as Any } ?? NSNull(), "p_environment": environment,
        ])
    }
}

final class TroveAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        ListNotifications.shared.receivedToken(deviceToken)
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        ListNotifications.shared.registrationFailed()
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
