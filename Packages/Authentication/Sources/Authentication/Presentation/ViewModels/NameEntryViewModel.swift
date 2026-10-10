import Foundation
import Observation
import Core

/// Collects a new user's first + last name (both required) and completes registration by calling
/// `registerWithName` with the still-valid OTP code. Only reached for brand-new phone numbers; a
/// returning user is signed in straight from the OTP screen.
@MainActor
@Observable
public final class NameEntryViewModel {
    public var firstName: String = ""
    public var lastName: String = ""

    public private(set) var state: ViewState<User> = .empty

    private let challengeId: String
    private let code: String
    private let registerWithName: any RegisterWithNameUseCase
    private let role: UserRole

    public init(challengeId: String, code: String, role: UserRole, registerWithName: any RegisterWithNameUseCase) {
        self.role = role
        self.challengeId = challengeId
        self.code = code
        self.registerWithName = registerWithName
    }

    public var isSubmitting: Bool { state.isLoading }

    /// Both names are required before the button enables (server enforces this too).
    public var canSubmit: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && !isSubmitting
    }

    public var fieldError: AppError? {
        if case .error(let error) = state { return error }
        return nil
    }

    /// Creates the account, then hands the authenticated user to the coordinator.
    public func submit(onUser: @escaping (User) -> Void) async {
        state = .loading
        do {
            let user = try await registerWithName(
                challengeId: challengeId, code: code, firstName: firstName, lastName: lastName, role: role
            )
            state = .loaded(user)
            onUser(user)
        } catch let error as AppError {
            state = .error(error)
        } catch {
            state = .error(.unknown(message: error.localizedDescription))
        }
    }
}
