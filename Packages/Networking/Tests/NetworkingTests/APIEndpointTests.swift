import Foundation
import Testing
@testable import Networking

@Suite("APIEndpoint (Supabase RPC / Auth / Storage)")
struct APIEndpointTests {
    @Test("rpc() builds a POST to /rest/v1/rpc/<name>")
    func rpcHelper() {
        let endpoint = APIEndpoint.rpc("get_cities")
        #expect(endpoint.path == "/rest/v1/rpc/get_cities")
        #expect(endpoint.method == .post)
        #expect(endpoint.queryItems.isEmpty)
    }

    @Test("catalog, profile and analytics endpoints map to their RPC functions (all POST)")
    func munyatiEndpoints() {
        #expect(APIEndpoint.catalog.cities.path == "/rest/v1/rpc/get_cities")
        #expect(APIEndpoint.catalog.categories.path == "/rest/v1/rpc/get_categories")
        #expect(APIEndpoint.profile.get.path == "/rest/v1/rpc/get_my_profile")
        #expect(APIEndpoint.configuration.strings.path == "/rest/v1/rpc/get_app_strings")
        #expect(APIEndpoint.analytics.logError.path == "/rest/v1/rpc/log_client_error")
        for endpoint in [APIEndpoint.catalog.cities, .catalog.categories, .profile.get, .profile.update, .configuration.strings] {
            #expect(endpoint.method == .post)
        }
    }

    @Test("authentication endpoints hit Supabase GoTrue + our OTP Edge Functions")
    func authenticationEndpoints() {
        #expect(APIEndpoint.authentication.signUpAnonymous.path == "/auth/v1/signup")
        // OTP is delivered by our own Edge Functions (OurSMS), not GoTrue's phone provider.
        #expect(APIEndpoint.authentication.sendOTP.path == "/functions/v1/send-otp")
        #expect(APIEndpoint.authentication.verifyOTP.path == "/functions/v1/verify-otp")
        for endpoint in [APIEndpoint.authentication.signUpAnonymous, .authentication.sendOTP, .authentication.verifyOTP] {
            #expect(endpoint.method == .post)
        }
    }
}
