import Foundation
import Testing
@testable import Networking

@Suite("APIEndpoint (Supabase RPC / Auth / Storage)")
struct APIEndpointTests {
    @Test("rpc() builds a POST to /rest/v1/rpc/<name>")
    func rpcHelper() {
        let endpoint = APIEndpoint.rpc("get_places")
        #expect(endpoint.path == "/rest/v1/rpc/get_places")
        #expect(endpoint.method == .post)
        #expect(endpoint.queryItems.isEmpty)
    }

    @Test("places data endpoints map to their RPC functions (all POST)")
    func placesEndpoints() {
        #expect(APIEndpoint.places.list.path == "/rest/v1/rpc/get_places")
        #expect(APIEndpoint.places.detail.path == "/rest/v1/rpc/get_place_detail")
        #expect(APIEndpoint.places.submit.path == "/rest/v1/rpc/submit_place")
        #expect(APIEndpoint.places.resubmit.path == "/rest/v1/rpc/resubmit_place")
        #expect(APIEndpoint.places.myPlaces.path == "/rest/v1/rpc/get_my_places")
        for endpoint in [APIEndpoint.places.list, .places.detail, .places.submit, .places.resubmit, .places.myPlaces] {
            #expect(endpoint.method == .post)
        }
    }

    @Test("categories endpoints map to their RPC functions")
    func categoriesEndpoints() {
        #expect(APIEndpoint.categories.list.path == "/rest/v1/rpc/get_categories")
        #expect(APIEndpoint.categories.formSchema.path == "/rest/v1/rpc/get_category_form_schema")
        #expect(APIEndpoint.categories.formSchema.method == .post)
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

    @Test("storage upload path is namespaced under the place-images bucket")
    func storageEndpoints() {
        let upload = APIEndpoint.storage.uploadPlaceImage(objectPath: "user-1/place-9/cover.jpg")
        #expect(upload.path == "/storage/v1/object/place-images/user-1/place-9/cover.jpg")
        #expect(upload.method == .post)
        #expect(APIEndpoint.storage.publicURLPath(objectPath: "user-1/place-9/cover.jpg")
                == "/storage/v1/object/public/place-images/user-1/place-9/cover.jpg")
    }
}
