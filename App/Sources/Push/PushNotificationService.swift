import Foundation

/// The part of a tapped notification's `data` payload the app acts on. A small Sendable value so
/// it can cross from the (nonisolated) notification-center delegate to the MainActor handler
/// without dragging along the non-Sendable `[AnyHashable: Any]` userInfo dictionary.
struct PushTap: Sendable {
    /// Where the tap should land, e.g. `https://munyati.co/b/<booking id>` or
    /// `munyati://plans`. Parsed by `DeepLink`; `send-push` copies it from `notifications.deeplink`.
    let deepLink: String?
    /// The `notifications` row this push came from (`send-push` puts it in the data payload), so
    /// a tap can be recorded as an actual open — distinct from `is_read`, which only means the
    /// inbox list was viewed.
    let notificationId: String?
}

/// App-level push abstraction. Kept behind a protocol so the rest of the app (and tests) never
/// touch FirebaseMessaging directly — Firebase lives only in the App composition root, so the
/// feature packages stay vendor-free, exactly like the app never imports the Supabase SDK.
@MainActor
protocol PushNotifying: AnyObject {
    /// Ask the OS for notification permission and register with APNs. Safe to call repeatedly.
    func requestAuthorizationAndRegister() async

    /// The latest FCM registration token, once known. `nil` until the first token arrives.
    var fcmToken: String? { get }

    /// Called whenever the FCM token appears or rotates. The composition root wires this to
    /// register the token with the backend (Supabase) so it can target this device.
    var onTokenChange: (@MainActor (String) -> Void)? { get set }

    /// Called when the user taps a notification, carrying the bits of its `data` payload the app
    /// deep-links on. The composition root routes it through `DeepLink`.
    /// Setting it also flushes any tap that arrived before it was wired (a launch-from-killed tap
    /// fires before the SwiftUI layer has attached this), so a cold-start tap isn't dropped.
    var onNotificationTap: (@MainActor (PushTap) -> Void)? { get set }
}
