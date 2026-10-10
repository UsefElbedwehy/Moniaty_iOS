import Core
import Foundation
import Testing
@testable import Networking

@Suite("URLSessionAPIClient request building")
struct URLSessionAPIClientRequestBuildingTests {
    private let baseURL = URL(string: "https://api.example.com")!

    @Test("builds the correct URL, path, and method for an RPC endpoint")
    func rpcEndpoint() {
        let request = URLSessionAPIClient.makeURLRequest(
            for: .places.detail,
            baseURL: baseURL,
            defaultHeaders: [:],
            timeoutInterval: 30
        )

        #expect(request.url?.absoluteString == "https://api.example.com/rest/v1/rpc/get_place_detail")
        #expect(request.httpMethod == "POST")
    }

    @Test("appends query items to the URL when present")
    func withQueryItems() {
        let endpoint = APIEndpoint(path: "/rest/v1/things", method: .get,
                                   queryItems: [URLQueryItem(name: "status", value: "live")])
        let request = URLSessionAPIClient.makeURLRequest(
            for: endpoint,
            baseURL: baseURL,
            defaultHeaders: [:],
            timeoutInterval: 30
        )

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        #expect(queryItems.contains(URLQueryItem(name: "status", value: "live")))
    }

    @Test("applies default headers")
    func defaultHeaders() {
        let request = URLSessionAPIClient.makeURLRequest(
            for: .categories.list,
            baseURL: baseURL,
            defaultHeaders: ["X-App-Version": "1.0.0"],
            timeoutInterval: 30
        )

        #expect(request.value(forHTTPHeaderField: "X-App-Version") == "1.0.0")
    }

    @Test("applies the configured timeout interval")
    func timeoutInterval() {
        let request = URLSessionAPIClient.makeURLRequest(
            for: .configuration.get,
            baseURL: baseURL,
            defaultHeaders: [:],
            timeoutInterval: 15
        )

        #expect(request.timeoutInterval == 15)
    }

    @Test("uses POST method for submit endpoint")
    func postMethod() {
        let request = URLSessionAPIClient.makeURLRequest(
            for: .places.submit,
            baseURL: baseURL,
            defaultHeaders: [:],
            timeoutInterval: 30
        )

        #expect(request.httpMethod == "POST")
    }
}

@Suite("URLSessionAPIClient error mapping")
struct URLSessionAPIClientErrorMappingTests {
    @Test("URLError.timedOut maps to network(.timedOut)")
    func timedOut() {
        let error = URLSessionAPIClient.mapTransportError(URLError(.timedOut))
        #expect(error == .network(.timedOut))
    }

    @Test("URLError.notConnectedToInternet maps to network(.noConnection)")
    func notConnected() {
        let error = URLSessionAPIClient.mapTransportError(URLError(.notConnectedToInternet))
        #expect(error == .network(.noConnection))
    }

    @Test("URLError.networkConnectionLost maps to network(.noConnection)")
    func connectionLost() {
        let error = URLSessionAPIClient.mapTransportError(URLError(.networkConnectionLost))
        #expect(error == .network(.noConnection))
    }

    @Test("URLError.cancelled maps to network(.cancelled)")
    func cancelled() {
        let error = URLSessionAPIClient.mapTransportError(URLError(.cancelled))
        #expect(error == .network(.cancelled))
    }

    @Test("an unrecognized URLError code maps to unknown")
    func unrecognizedURLError() {
        let error = URLSessionAPIClient.mapTransportError(URLError(.badServerResponse))
        if case .unknown = error {
            // expected
        } else {
            Issue.record("Expected .unknown, got \(error)")
        }
    }

    @Test("401 status maps to authentication(.sessionExpired)")
    func unauthorized() {
        let decoder = JSONDecoder()
        let error = URLSessionAPIClient.mapHTTPError(statusCode: 401, data: Data(), decoder: decoder)
        #expect(error == .authentication(.sessionExpired))
    }

    @Test("400 with a decodable error body maps to validation with the server message")
    func badRequestWithMessage() {
        let json = #"{"message":"Phone number is invalid."}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        let error = URLSessionAPIClient.mapHTTPError(statusCode: 400, data: json, decoder: decoder)
        #expect(error == .validation(field: nil, message: "Phone number is invalid."))
    }

    @Test("422 without a decodable body falls back to a server error")
    func unprocessableWithoutMessage() {
        let decoder = JSONDecoder()
        let error = URLSessionAPIClient.mapHTTPError(statusCode: 422, data: Data(), decoder: decoder)
        #expect(error == .server(statusCode: 422, message: nil))
    }

    @Test("500 maps to a server error carrying the status code")
    func serverError() {
        let decoder = JSONDecoder()
        let error = URLSessionAPIClient.mapHTTPError(statusCode: 500, data: Data(), decoder: decoder)
        #expect(error == .server(statusCode: 500, message: nil))
    }

    @Test("500 with a decodable body carries the server message")
    func serverErrorWithMessage() {
        let json = #"{"message":"Something broke."}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        let error = URLSessionAPIClient.mapHTTPError(statusCode: 500, data: json, decoder: decoder)
        #expect(error == .server(statusCode: 500, message: "Something broke."))
    }
}
