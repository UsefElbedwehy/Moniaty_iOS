import Foundation

/// Decodes successfully regardless of body content, including PostgREST's empty response for a
/// `void`-returning RPC. Use as the `Response` type for fire-and-forget calls (e.g. analytics
/// logging) where only "did the request succeed" matters — a real HTTP/network failure still
/// throws from `send`, but there's no payload shape to decode.
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
    public init(from decoder: Decoder) throws {}
}
