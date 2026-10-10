import Foundation

/// Body for `rpc/record_analytics_event`. Lives in Networking rather than a feature package
/// because engagement events are recorded from several features (place detail, home banners)
/// through one injected recorder in the composition root.
public struct RecordAnalyticsEventArgs: Encodable, Sendable {
    public let pEventType: String
    public let pEntityId: String?
    /// What the event happened *on* — the ad a delivery link was tapped from. Separate from
    /// `pEntityId` (the thing tapped) so the platform totals keep aggregating as they always did.
    public let pContextId: String?

    public init(pEventType: String, pEntityId: String?, pContextId: String? = nil) {
        self.pEventType = pEventType
        self.pEntityId = pEntityId
        self.pContextId = pContextId
    }
}
