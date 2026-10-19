package co.munyati.authentication.domain

import co.munyati.core.error.AppError

// Each use case is a thin, single-purpose type so ViewModels can be tested against fakes. Input
// validation (a Saudi mobile; a six-digit code) lives here, before we hit the repository — the
// backend still does the real verification, this just avoids doomed round trips.

/** The number of digits an OTP code must contain (shared by the validator and the six-box UI). */
const val OTP_CODE_LENGTH = 6

class SendOtp(private val repository: AuthRepository) {
    suspend operator fun invoke(phoneE164: String): OtpChallenge {
        val normalized = PhoneNumberValidator.normalize(phoneE164)
        PhoneNumberValidator.validate(normalized)
        return repository.sendOtp(normalized)
    }
}

class VerifyOtp(private val repository: AuthRepository) {
    suspend operator fun invoke(challengeId: String, code: String): User {
        OtpCodeValidator.validate(code)
        return repository.verifyOtp(challengeId, code)
    }
}

class RegisterWithName(private val repository: AuthRepository) {
    suspend operator fun invoke(challengeId: String, code: String, firstName: String, lastName: String, role: UserRole): User {
        OtpCodeValidator.validate(code)
        val first = firstName.trim()
        val last = lastName.trim()
        if (first.isEmpty() || last.isEmpty()) throw AppError.Validation("name", "auth.error.nameRequired")
        return repository.registerWithName(challengeId, code, first, last, role)
    }
}

class ContinueAsGuest(private val repository: AuthRepository) {
    suspend operator fun invoke(): AuthState = repository.continueAsGuest()
}

/** All auth use cases over one repository. */
class AuthUseCases(repository: AuthRepository) {
    val sendOtp = SendOtp(repository)
    val verifyOtp = VerifyOtp(repository)
    val registerWithName = RegisterWithName(repository)
    val continueAsGuest = ContinueAsGuest(repository)
}

internal object PhoneNumberValidator {
    /**
     * Strips spaces and separators, keeping a leading "+". Arabic-Indic digits (٠-٩, ۰-۹) are
     * converted to ASCII first rather than dropped, so pasted or autofilled numbers still work.
     */
    fun normalize(raw: String): String = raw.map { ch ->
        when (ch) {
            in '٠'..'٩' -> '0' + (ch - '٠')
            in '۰'..'۹' -> '0' + (ch - '۰')
            else -> ch
        }
    }.filter { it == '+' || it in '0'..'9' }.joinToString("")

    /** Munyati serves Saudi Arabia only: +966 5X XXX XXXX (12 digits with the country code). */
    fun validate(normalized: String) {
        val digits = normalized.removePrefix("+")
        if (digits.isEmpty()) throw AppError.Validation("phone", "auth.error.phoneEmpty")
        if (digits.length != 12 || !digits.startsWith("9665") || !digits.all { it in '0'..'9' }) {
            throw AppError.Validation("phone", "auth.error.phoneInvalid")
        }
    }
}

internal object OtpCodeValidator {
    fun validate(code: String) {
        if (code.length != OTP_CODE_LENGTH || !code.all { it in '0'..'9' }) {
            throw AppError.Validation("code", "auth.error.codeInvalid")
        }
    }
}
