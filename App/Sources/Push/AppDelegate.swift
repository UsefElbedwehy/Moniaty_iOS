import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import Core

/// The app's `UIApplicationDelegate`. Its only jobs are the two things SwiftUI's `App` can't do
/// on its own: configure Firebase at process start, and receive the APNs device-token callbacks.
/// It owns the concrete `PushNotifying` implementation and forwards OS callbacks into it.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Exposed so the SwiftUI layer (via `@UIApplicationDelegateAdaptor`) can reach the push
    /// service to trigger the permission prompt and wire the backend-registration hook.
    let pushService = FirebasePushNotificationService()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // GoogleService-Info.plist is per-project and not committed; without it the app still
        // runs (no push, analytics or crash reports) instead of crashing at launch.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            pushService.configure()
        } else {
            AppLog.push.error("GoogleService-Info.plist missing: Firebase disabled.")
        }
        return true
    }

    // APNs → Firebase bridge. Firebase needs the raw APNs token to mint an FCM token.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        let description = error.localizedDescription
        AppLog.push.error("APNs registration failed: \(description, privacy: .public)")
    }
}

/// Concrete Firebase-backed push service. This is the *only* type in the codebase that imports
/// FirebaseMessaging.
@MainActor
final class FirebasePushNotificationService: NSObject, PushNotifying {
    private(set) var fcmToken: String?
    var onTokenChange: (@MainActor (String) -> Void)?

    /// A tap that arrived before `onNotificationTap` was wired (launch-from-killed delivers the tap
    /// as soon as the delegate is set in `configure()`, well before SwiftUI's `.task` runs). Held
    /// here and flushed the moment the handler attaches — same reason `fcmToken` is cached.
    private var pendingTap: PushTap?
    var onNotificationTap: (@MainActor (PushTap) -> Void)? {
        didSet {
            guard let onNotificationTap, let pending = pendingTap else { return }
            pendingTap = nil
            onNotificationTap(pending)
        }
    }

    /// Wire Firebase/notification-center delegates. Called once from `didFinishLaunching`.
    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                AppLog.push.info("Notification permission not granted.")
                return
            }
            // Registering for remote notifications must happen on the main thread.
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            let description = error.localizedDescription
            AppLog.push.error("Notification authorization error: \(description, privacy: .public)")
        }
    }
}

// MARK: - MessagingDelegate

extension FirebasePushNotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            self.fcmToken = fcmToken
            self.onTokenChange?(fcmToken)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension FirebasePushNotificationService: UNUserNotificationCenterDelegate {
    /// Show notifications while the app is in the foreground (banner + sound), matching the
    /// design's "your place is now live" style of timely updates.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Extract the deep-link bits from the FCM `data` payload here (still Sendable strings)
        // rather than sending the whole non-Sendable userInfo across to the MainActor. If the
        // handler isn't attached yet (cold-start tap), the tap is cached and flushed once it wires.
        let userInfo = response.notification.request.content.userInfo
        let tap = PushTap(
            deepLink: userInfo["deep_link"] as? String,
            notificationId: userInfo["notification_id"] as? String
        )
        Task { @MainActor in
            if let onNotificationTap {
                onNotificationTap(tap)
            } else {
                pendingTap = tap
            }
        }
        completionHandler()
    }
}
