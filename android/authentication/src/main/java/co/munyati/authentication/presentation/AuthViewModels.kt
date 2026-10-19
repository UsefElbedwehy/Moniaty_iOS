package co.munyati.authentication.presentation

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import co.munyati.authentication.domain.AuthState
import co.munyati.authentication.domain.ContinueAsGuest
import co.munyati.authentication.domain.OTP_CODE_LENGTH
import co.munyati.authentication.domain.OtpChallenge
import co.munyati.authentication.domain.RegisterWithName
import co.munyati.authentication.domain.RequiresRegistration
import co.munyati.authentication.domain.SendOtp
import co.munyati.authentication.domain.User
import co.munyati.authentication.domain.UserRole
import co.munyati.authentication.domain.VerifyOtp
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Runs [block], turning any failure into `ViewState.Error` (cancellation still propagates). */
private suspend fun <T> attempt(block: suspend () -> T): ViewState<T> = try {
    ViewState.Loaded(block())
} catch (e: CancellationException) {
    throw e
} catch (e: Exception) {
    ViewState.Error(AppError.from(e))
}

/**
 * Landing screen: mostly routing intent, plus the one async action without a screen of its own —
 * "Browse as guest" runs the guest use case and reports the resolved state.
 */
class OnboardingViewModel(private val continueAsGuest: ContinueAsGuest) : ViewModel() {
    var guestState: ViewState<AuthState> by mutableStateOf(ViewState.Empty)
        private set

    val isBusy: Boolean get() = guestState.isLoading
    val errorMessage: AppError? get() = guestState.error

    /** On success [onDone] gets `Authenticated` (anonymous session) or `Guest` (no server session). */
    fun browseAsGuest(onDone: (AuthState) -> Unit) {
        guestState = ViewState.Loading
        viewModelScope.launch {
            guestState = attempt { continueAsGuest() }
            guestState.value?.let(onDone)
        }
    }
}

/** A country the app accepts numbers from. Munyati serves Saudi Arabia only. */
data class PhoneCountry(val id: String, val dialCode: String, val example: String) {
    companion object {
        val SaudiArabia = PhoneCountry("SA", "+966", "5X XXX XXXX")
        val selectable = listOf(SaudiArabia)
    }
}

/** Holds the phone text and a single `ViewState<OtpChallenge>` for the send action. */
class PhoneEntryViewModel(private val sendOtp: SendOtp) : ViewModel() {
    var selectedCountry by mutableStateOf(PhoneCountry.SaudiArabia)

    /** The national number as typed. Arabic-Indic digits are turned into ASCII as they arrive. */
    var nationalNumber by mutableStateOf("")
        private set

    var state: ViewState<OtpChallenge> by mutableStateOf(ViewState.Empty)
        private set

    fun onNumberChange(raw: String) {
        nationalNumber = asciiDigits(raw).filter { it.isDigit() || it == ' ' }.take(12)
    }

    val isSending: Boolean get() = state.isLoading
    val canSubmit: Boolean get() = nationalNumber.isNotBlank() && !isSending
    val fieldError: AppError? get() = state.error
    val composedE164: String get() = selectedCountry.dialCode + nationalNumber

    fun sendCode(onChallenge: (OtpChallenge) -> Unit) {
        state = ViewState.Loading
        viewModelScope.launch {
            state = attempt { sendOtp(composedE164) }
            state.value?.let(onChallenge)
        }
    }
}

/**
 * The six-digit code, one `ViewState<User>` for verify, and a resend countdown that starts at the
 * challenge's interval and ticks to zero, when "Resend" becomes active.
 */
class OtpViewModel(
    val challenge: OtpChallenge,
    private val verifyOtp: VerifyOtp,
    private val sendOtp: SendOtp,
) : ViewModel() {
    var code by mutableStateOf("")
        private set
    var state: ViewState<User> by mutableStateOf(ViewState.Empty)
        private set
    var resendSecondsRemaining by mutableIntStateOf(0)
        private set
    private var countdown: Job? = null

    val isVerifying: Boolean get() = state.isLoading
    val canResend: Boolean get() = resendSecondsRemaining <= 0 && !isVerifying
    val isComplete: Boolean get() = code.length == OTP_CODE_LENGTH
    val errorMessage: AppError? get() = state.error
    val resendCountdownText: String get() = "%d:%02d".format(resendSecondsRemaining / 60, resendSecondsRemaining % 60)

    /** ASCII digits only: Arabic-Indic digits are converted, anything else dropped, capped at six. */
    fun onCodeChange(raw: String) {
        code = asciiDigits(raw).filter { it in '0'..'9' }.take(OTP_CODE_LENGTH)
    }

    fun startCountdown() {
        countdown?.cancel()
        resendSecondsRemaining = challenge.resendIntervalSeconds.coerceAtLeast(0)
        if (resendSecondsRemaining == 0) return
        countdown = viewModelScope.launch {
            while (resendSecondsRemaining > 0) {
                delay(1_000)
                resendSecondsRemaining -= 1
            }
        }
    }

    /**
     * Verifies the current code. For a brand-new number the code is accepted but the account can't
     * be created yet — [onNeedsName] fires so the flow can collect a name with the same code.
     */
    fun verify(onUser: (User) -> Unit, onNeedsName: (String) -> Unit) {
        if (isVerifying) return
        state = ViewState.Loading
        val submitted = code
        viewModelScope.launch {
            state = try {
                ViewState.Loaded(verifyOtp(challenge.id, submitted))
            } catch (e: RequiresRegistration) {
                onNeedsName(submitted)
                ViewState.Empty // not an error — just needs a name
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                ViewState.Error(AppError.from(e))
            }
            state.value?.let(onUser)
        }
    }

    /** Resends the code for the same number and restarts the countdown. */
    fun resend() {
        if (!canResend) return
        viewModelScope.launch {
            val result = attempt { sendOtp(challenge.phoneE164) }
            if (result is ViewState.Error) {
                state = result
            } else {
                code = ""
                state = ViewState.Empty
                startCountdown()
            }
        }
    }
}

/** Collects a new user's first + last name and completes registration with the still-valid code. */
class NameEntryViewModel(
    private val challengeId: String,
    private val code: String,
    private val role: UserRole,
    private val registerWithName: RegisterWithName,
) : ViewModel() {
    var firstName by mutableStateOf("")
    var lastName by mutableStateOf("")
    var state: ViewState<User> by mutableStateOf(ViewState.Empty)
        private set

    val isSubmitting: Boolean get() = state.isLoading
    val canSubmit: Boolean get() = firstName.isNotBlank() && lastName.isNotBlank() && !isSubmitting
    val fieldError: AppError? get() = state.error

    fun submit(onUser: (User) -> Unit) {
        state = ViewState.Loading
        viewModelScope.launch {
            state = attempt { registerWithName(challengeId, code, firstName, lastName, role) }
            state.value?.let(onUser)
        }
    }
}

private fun asciiDigits(raw: String): String = raw.map { ch ->
    when (ch) {
        in '٠'..'٩' -> '0' + (ch - '٠')
        in '۰'..'۹' -> '0' + (ch - '۰')
        else -> ch
    }
}.joinToString("")
