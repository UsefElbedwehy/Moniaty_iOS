import Core
import Foundation

/// `URLSession`-backed implementation of `APIClient`. This is the only place in the app
/// that should know about `URLSession`, HTTP status codes, or JSON wire-format conventions.
///
/// Authentication is injected as an opaque token provider closure so this module never has
/// to import or know anything about the Authentication feature — it just asks "do you have a
/// bearer token right now?" before every request.
public final class URLSessionAPIClient: APIClient {
    private let session: URLSession
    private let configuration: NetworkConfiguration
    private let authTokenProvider: (@Sendable () async -> String?)?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: NetworkConfiguration,
        session: URLSession = .shared,
        authTokenProvider: (@Sendable () async -> String?)? = nil
    ) {
        self.configuration = configuration
        self.session = session
        self.authTokenProvider = authTokenProvider

        // NOTE: `.convertToSnakeCase` / `.convertFromSnakeCase` are reasonable defaults for a
        // typical REST backend. If the real backend uses different conventions, swap these
        // strategies here (or promote them into `NetworkConfiguration` if they ever need to
        // vary per-environment).
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func send<Response: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws(AppError) -> Response {
        try await performRequest(endpoint, bodyData: nil)
    }

    public func send<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        body: Body
    ) async throws(AppError) -> Response {
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch {
            throw AppError.unknown(message: "Failed to encode request body: \(error.localizedDescription)")
        }
        return try await performRequest(endpoint, bodyData: bodyData)
    }

    // MARK: - Request execution

    private func performRequest<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        bodyData: Data?
    ) async throws(AppError) -> Response {
        var request = Self.makeURLRequest(
            for: endpoint,
            baseURL: configuration.baseURL,
            defaultHeaders: configuration.defaultHeaders,
            timeoutInterval: configuration.timeoutInterval
        )
        request.httpBody = bodyData
        if bodyData != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let authTokenProvider, let token = await authTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.mapTransportError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network(.invalidResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw Self.mapHTTPError(statusCode: httpResponse.statusCode, data: data, decoder: decoder)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AppError.network(.decodingFailed)
        }
    }

    // MARK: - Request building (pure, testable)

    /// Builds a `URLRequest` from a base URL and a resolved `APIEndpoint`. Pure function with
    /// no I/O so request composition (path, method, query items, headers) can be unit tested
    /// without hitting the network.
    static func makeURLRequest(
        for endpoint: APIEndpoint,
        baseURL: URL,
        defaultHeaders: [String: String],
        timeoutInterval: TimeInterval
    ) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }

        let url = components?.url ?? baseURL.appendingPathComponent(endpoint.path)

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = endpoint.method.rawValue
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    // MARK: - Error mapping (pure, testable)

    /// Maps a transport-level failure (thrown before we ever got an HTTP response) into `AppError`.
    static func mapTransportError(_ error: Error) -> AppError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .network(.noConnection)
            case .timedOut:
                return .network(.timedOut)
            case .cancelled:
                return .network(.cancelled)
            default:
                return .unknown(message: urlError.localizedDescription)
            }
        }
        if error is DecodingError {
            return .network(.decodingFailed)
        }
        return .unknown(message: error.localizedDescription)
    }

    /// Maps a non-2xx HTTP response into `AppError`, best-effort decoding an error body for a
    /// human-readable message.
    static func mapHTTPError(statusCode: Int, data: Data, decoder: JSONDecoder) -> AppError {
        let serverMessage = try? decoder.decode(APIErrorResponseDTO.self, from: data).message

        switch statusCode {
        case 401:
            return .authentication(.sessionExpired)
        case 400, 422:
            if let serverMessage {
                return .validation(field: nil, message: serverMessage)
            }
            return .server(statusCode: statusCode, message: serverMessage)
        default:
            return .server(statusCode: statusCode, message: serverMessage)
        }
    }
}

/// Best-effort shape for a server error body. Decoding this is allowed to fail silently —
/// if the body doesn't match, callers fall back to a generic message.
struct APIErrorResponseDTO: Decodable {
    let message: String?
}
