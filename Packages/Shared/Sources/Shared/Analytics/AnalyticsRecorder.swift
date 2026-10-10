import SwiftUI

/// The engagement events the admin dashboard reports on. Raw values are the Postgres
/// `analytics_event_type` labels — keep them in step with the enum in
/// `20260906150000_engagement_analytics.sql`.
public enum AnalyticsEvent: String, Sendable {
    case appOpen = "app_open"
    case placeDirections = "place_directions"
    case placeWhatsapp = "place_whatsapp"
    case deliveryLinkClick = "delivery_link_click"
    case bannerImpression = "banner_impression"
    case bannerClick = "banner_click"
}

/// Fire-and-forget engagement tracking, injected once by the composition root the same way
/// `AuthGate` is, so a feature view can record a tap without knowing anything about the network
/// layer — and so previews and tests record nothing at all.
public struct AnalyticsRecorder: Sendable {
    private let handler: @Sendable (AnalyticsEvent, String?, String?) -> Void

    public init(handler: @escaping @Sendable (AnalyticsEvent, String?, String?) -> Void) {
        self.handler = handler
    }

    /// `entityId` is the thing the event is about — the place, delivery platform or banner slide;
    /// nil for events not tied to one (`appOpen`). `context` is what it happened *on*, which for
    /// a delivery link is the ad it was tapped from: without it the dashboard can say a platform
    /// was tapped but never which listings earned the taps.
    public func callAsFunction(_ event: AnalyticsEvent, _ entityId: String? = nil, context: String? = nil) {
        handler(event, entityId, context)
    }

    /// Records nothing. The environment default, so a view rendered outside the composed app
    /// (a preview, a test) never talks to the network.
    public static let disabled = AnalyticsRecorder { _, _, _ in }
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
