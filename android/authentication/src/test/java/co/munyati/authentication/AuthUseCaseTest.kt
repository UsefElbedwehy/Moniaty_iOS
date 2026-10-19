package co.munyati.authentication

import co.munyati.authentication.data.MockAuthRepository
import co.munyati.authentication.domain.AuthState
import co.munyati.authentication.domain.AuthUseCases
import co.munyati.authentication.domain.UserRole
import co.munyati.core.error.AppError
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class AuthUseCaseTest {
    private val useCases = AuthUseCases(MockAuthRepository(artificialDelayMs = 0))

    private suspend fun errorOf(block: suspend () -> Unit) = runCatching { block() }.exceptionOrNull()

    @Test fun `rejects an empty phone number`() = runTest {
        assertEquals(AppError.Validation("phone", "auth.error.phoneEmpty"), errorOf { useCases.sendOtp("") })
    }

    @Test fun `rejects a too-short number`() = runTest {
        assertEquals(AppError.Validation("phone", "auth.error.phoneInvalid"), errorOf { useCases.sendOtp("+96655") })
    }

    @Test fun `rejects non-Saudi and non-mobile numbers`() = runTest {
        for (number in listOf("+201001234567", "+966112345678")) {
            assertEquals(AppError.Validation("phone", "auth.error.phoneInvalid"), errorOf { useCases.sendOtp(number) })
        }
    }

    @Test fun `accepts a Saudi mobile with spaces and Arabic-Indic digits`() = runTest {
        val challenge = useCases.sendOtp("+966 ٥٥ 123 4567")
        assertEquals("+966551234567", challenge.phoneE164)
    }

    @Test fun `rejects a non-6-digit code without hitting the repository`() = runTest {
        assertEquals(AppError.Validation("code", "auth.error.codeInvalid"), errorOf { useCases.verifyOtp("any", "123") })
    }

    @Test fun `accepts the demo code and rejects a wrong one`() = runTest {
        val wrong = useCases.sendOtp("+966551234567")
        assertEquals(AppError.Authentication(AppError.AuthFailureReason.OtpIncorrect), errorOf { useCases.verifyOtp(wrong.id, "000000") })
        val right = useCases.sendOtp("+966551234567")
        assertEquals("+966551234567", useCases.verifyOtp(right.id, MockAuthRepository.ACCEPTED_CODE).phoneNumber)
    }

    @Test fun `registration requires both names`() = runTest {
        val challenge = useCases.sendOtp("+966551234567")
        assertEquals(
            AppError.Validation("name", "auth.error.nameRequired"),
            errorOf { useCases.registerWithName(challenge.id, "123456", "نورة", "  ", UserRole.Bride) },
        )
    }

    @Test fun `continue as guest returns Guest`() = runTest {
        assertEquals(AuthState.Guest, useCases.continueAsGuest())
    }
}
