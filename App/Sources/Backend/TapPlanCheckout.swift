import Foundation
import Core
import ProviderStudio

/// Provider plan payments through the `tap-checkout` edge function (Tap hosted checkout).
/// The function prices the plan on the server and settles open payments with Tap when asked.
struct TapPlanCheckout: PlanCheckout {
    let baseURL: URL
    let anonKey: String
    let accessToken: @Sendable () async -> String?
    var session: URLSession = .shared

    private struct Response: Decodable {
        let paymentId: String?
        let url: URL?
        let status: String?
        let error: String?

        enum CodingKeys: String, CodingKey {
            case paymentId = "payment_id", url, status, error
        }
    }

    func start(planId: String) async throws -> CheckoutStart {
        let response = try await call(["plan_id": planId])
        if let paymentId = response.paymentId, let url = response.url { return .open(paymentId: paymentId, url: url) }
        return .refused(response.error ?? "generic")
    }

    func status(paymentId: String) async throws -> PlanPaymentStatus {
        let response = try await call(["payment_id": paymentId])
        return response.status.flatMap(PlanPaymentStatus.init(rawValue:)) ?? .initiated
    }

    private func call(_ body: [String: String]) async throws -> Response {
        guard let token = await accessToken() else { throw AppError.authentication(.notAuthenticated) }
        var request = URLRequest(url: baseURL.appendingPathComponent("functions/v1/tap-checkout"))
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AppError.network(.noConnection)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Plan checkout failed.")
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
