import Foundation
import Observation
import Core

/// A country the app accepts phone numbers from: an ISO code (shown as a small badge), its E.164
/// dial code, and a national-number placeholder/example. Munyati serves Saudi Arabia only; the
/// picker hides itself when there is a single country.
public struct PhoneCountry: Identifiable, Hashable, Sendable {
    public let id: String        // ISO-3166 alpha-2, e.g. "SA"
    public let dialCode: String  // E.164 country code, e.g. "+966"
    public let example: String   // national-number placeholder, e.g. "5X XXX XXXX"

    public static let saudiArabia = PhoneCountry(id: "SA", dialCode: "+966", example: "5X XXX XXXX")

    /// Countries selectable in the picker.
    public static var selectable: [PhoneCountry] { [.saudiArabia] }
}

/// Holds the phone-entry text and a single `ViewState<OTPChallenge>` for the send action — no
/// boolean soup. The user types the
/// national part; the send use case validates and normalizes, so a bad number surfaces as an
/// inline field error rather than a network round trip.
@MainActor
@Observable
public final class PhoneEntryViewModel {
    /// The selected country, whose dial code prefixes the composed E.164 number.
    public var selectedCountry: PhoneCountry = .saudiArabia

    /// The national number as typed (digits/spaces). Bound to the phone field.
    public var nationalNumber: String = ""

    public private(set) var state: ViewState<OTPChallenge> = .empty

    private let sendOTP: any SendOTPUseCase

    public init(sendOTP: any SendOTPUseCase) {
        self.sendOTP = sendOTP
    }

    public var isSending: Bool { state.isLoading }

    /// Enable "Send code" only once there's something plausible to send (avoids a guaranteed
    /// validation error on an empty field). Full validation still happens in the use case.
    public var canSubmit: Bool {
        !nationalNumber.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    /// The inline error to show under the field, if the last attempt failed validation.
    public var fieldError: AppError? {
        if case .error(let error) = state { return error }
        return nil
    }

    /// The full E.164 number the use case will validate: selected country's dial code + digits.
    public var composedE164: String {
        selectedCountry.dialCode + nationalNumber
    }

    /// Sends the code. On success, `onChallenge` hands the challenge to the coordinator.
    public func sendCode(onChallenge: @escaping (OTPChallenge) -> Void) async {
        state = .loading
        do {
            let challenge = try await sendOTP(phoneE164: composedE164)
            state = .loaded(challenge)
            onChallenge(challenge)
        } catch let error as AppError {
            state = .error(error)
        } catch {
            state = .error(.unknown(message: error.localizedDescription))
        }
    }
}
