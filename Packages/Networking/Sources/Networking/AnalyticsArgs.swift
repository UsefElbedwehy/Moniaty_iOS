import Foundation

/// Arguments for the `record_analytics_event` RPC (curated business events, see
/// `docs/PLAN.md` §5). `pProps` carries small typed extras such as `category_id` or `city_id`.
public struct RecordAnalyticsEventArgs: Encodable, Sendable {
    public let pEventType: String
    public let pEntityId: String?
    public let pContextId: String?
    public let pProps: [String: String]?

    public init(pEventType: String, pEntityId: String?, pContextId: String? = nil, pProps: [String: String]? = nil) {
        self.pEventType = pEventType
        self.pEntityId = pEntityId
        self.pContextId = pContextId
        self.pProps = pProps
    }
}

/// Arguments for the `log_client_error` RPC (the app-side half of the error log).
public struct LogClientErrorArgs: Encodable, Sendable {
    public let pCode: String
    public let pMessage: String
    public let pScreen: String?
    public let pAppVersion: String?
    public let pOsVersion: String?

    public init(pCode: String, pMessage: String, pScreen: String?, pAppVersion: String?, pOsVersion: String?) {
        self.pCode = pCode
        self.pMessage = pMessage
        self.pScreen = pScreen
        self.pAppVersion = pAppVersion
        self.pOsVersion = pOsVersion
    }
}
