import Testing
@testable import Core

@Suite("AppError")
struct AppErrorTests {
    @Test("every case produces a non-empty, localized user-facing message")
    func allCasesHaveMessages() {
        let cases: [AppError] = [
            .network(.timedOut), .network(.noConnection), .network(.cancelled),
            .network(.decodingFailed), .network(.invalidResponse),
            .validation(field: "phone", message: "Enter a valid phone number."),
            .authentication(.invalidCredentials), .authentication(.sessionExpired),
            .authentication(.otpExpired), .authentication(.otpIncorrect), .authentication(.notAuthenticated),
            .server(statusCode: 500, message: nil), .server(statusCode: 400, message: "Bad request"),
            .offline, .unknown(message: nil)
        ]

        for error in cases {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }

    @Test("validation error surfaces its custom message verbatim")
    func validationMessagePassesThrough() {
        let error = AppError.validation(field: "email", message: "That doesn't look like an email.")
        #expect(error.errorDescription == "That doesn't look like an email.")
    }

    @Test("server error falls back to a generic message when none is provided")
    func serverErrorFallback() {
        let error = AppError.server(statusCode: 503, message: nil)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription != "")
    }
}
