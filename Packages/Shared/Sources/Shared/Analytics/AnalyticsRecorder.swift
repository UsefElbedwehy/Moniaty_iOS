import SwiftUI

/// The curated business events the admin dashboard and the provider Insights screen report on
/// (`docs/PLAN.md` §5). Raw values are the Postgres `analytics_event_type` labels: keep them in
/// step with the enum in `supabase/migrations/*_analytics.sql`.
///
/// Every-tap/screen tracking does not belong here; it goes to Firebase Analytics through
/// `AnalyticsRecorder.screen(_:)`, which costs nothing per event.
public enum AnalyticsEvent: String, Sendable, CaseIterable {
    case appOpen = "app_open"
    case roleSelected = "role_selected"
    case signUpCompleted = "sign_up_completed"
    case categoryOpen = "category_open"
    case providerView = "provider_view"
    case serviceView = "service_view"
    case storeView = "store_view"
    case search = "search"
    case cityFilterChanged = "city_filter_changed"
    case budgetSet = "budget_set"
    case bannerClick = "banner_click"
    case shareTap = "share_tap"
    case whatsappTap = "whatsapp_tap"
    case callTap = "call_tap"
    case bookingStarted = "booking_started"
    case bookingSubmitted = "booking_submitted"
    case paywallView = "paywall_view"
    case planPurchaseStarted = "plan_purchase_started"
}

/// Fire-and-forget analytics, injected once by the composition root (like `AuthGate`) so a
/// feature can record without knowing about Firebase or the network, and previews/tests record
/// nothing.
///
/// - `callAsFunction` records a curated event: to Postgres (dashboard + provider insights) and
///   to Firebase Analytics.
/// - `screen` records a screen view: Firebase Analytics only.
/// - `error` records a handled, non-fatal error: Crashlytics + the `error_logs` table.
public struct AnalyticsRecorder: Sendable {
    public typealias EventHandler = @Sendable (_ event: AnalyticsEvent, _ entityId: String?, _ context: String?, _ props: [String: String]) -> Void
    public typealias ScreenHandler = @Sendable (_ name: String) -> Void
    public typealias ErrorHandler = @Sendable (_ code: String, _ message: String, _ screen: String?) -> Void

    private let onEvent: EventHandler
    private let onScreen: ScreenHandler
    private let onError: ErrorHandler

    public init(onEvent: @escaping EventHandler, onScreen: @escaping ScreenHandler, onError: @escaping ErrorHandler) {
        self.onEvent = onEvent
        self.onScreen = onScreen
        self.onError = onError
    }

    /// `entityId` is what the event is about (a provider, service, category…); `context` is
    /// where it happened (e.g. the screen or the provider a service was opened from).
    public func callAsFunction(
        _ event: AnalyticsEvent,
        _ entityId: String? = nil,
        context: String? = nil,
        props: [String: String] = [:]
    ) {
        onEvent(event, entityId, context, props)
    }

    public func screen(_ name: String) {
        onScreen(name)
    }

    public func error(code: String, message: String, screen: String? = nil) {
        onError(code, message, screen)
    }

    /// Records nothing. The environment default, so previews and tests never talk to the network.
    public static let disabled = AnalyticsRecorder(onEvent: { _, _, _, _ in }, onScreen: { _ in }, onError: { _, _, _ in })
}

public extension EnvironmentValues {
    var analytics: AnalyticsRecorder {
        get { self[AnalyticsRecorderKey.self] }
        set { self[AnalyticsRecorderKey.self] = newValue }
    }
}

private struct AnalyticsRecorderKey: EnvironmentKey {
    static let defaultValue = AnalyticsRecorder.disabled
}

public extension View {
    /// Records a screen view in Firebase Analytics when the view appears.
    func trackScreen(_ name: String) -> some View {
        modifier(TrackScreenModifier(name: name))
    }
}

private struct TrackScreenModifier: ViewModifier {
    let name: String
    @Environment(\.analytics) private var analytics

    func body(content: Content) -> some View {
        content.onAppear { analytics.screen(name) }
    }
}
