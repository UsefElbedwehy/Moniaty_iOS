package co.munyati.authentication.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import co.munyati.authentication.data.MockAuthRepository
import co.munyati.authentication.domain.AuthRepository
import co.munyati.authentication.domain.AuthState
import co.munyati.authentication.domain.AuthUseCases
import co.munyati.authentication.domain.OtpChallenge
import co.munyati.authentication.domain.User
import co.munyati.authentication.domain.UserRole
import co.munyati.authentication.presentation.AuthCoordinator
import co.munyati.authentication.presentation.AuthLandingScreen
import co.munyati.authentication.presentation.NameEntryScreen
import co.munyati.authentication.presentation.NameEntryViewModel
import co.munyati.authentication.presentation.OnboardingViewModel
import co.munyati.authentication.presentation.OtpScreen
import co.munyati.authentication.presentation.OtpViewModel
import co.munyati.authentication.presentation.PhoneEntryScreen
import co.munyati.authentication.presentation.PhoneEntryViewModel
import kotlinx.serialization.Serializable

/** Destinations inside the auth flow. */
@Serializable internal data object LandingRoute
@Serializable internal data object PhoneEntryRoute
@Serializable internal data class OtpRoute(val challengeId: String)
@Serializable internal data class NameRoute(val challengeId: String, val code: String)

/**
 * The auth flow as one mountable unit: role choice → phone → OTP → (new number) name. It reports
 * completion through [onFinished] and doesn't know what comes after — the App decides.
 */
class AuthenticationFeature(repository: AuthRepository, private val onFinished: (AuthState) -> Unit) {
    private val useCases = AuthUseCases(repository)

    @Composable
    fun Content() {
        val navController = rememberNavController()
        val coordinator = remember(navController) { NavAuthCoordinator(navController, onFinished) }
        NavHost(navController, startDestination = LandingRoute) {
            composable<LandingRoute> {
                AuthLandingScreen(viewModel { OnboardingViewModel(useCases.continueAsGuest) }, coordinator)
            }
            composable<PhoneEntryRoute> {
                PhoneEntryScreen(viewModel { PhoneEntryViewModel(useCases.sendOtp) }, coordinator)
            }
            composable<OtpRoute> { entry ->
                val route = entry.toRoute<OtpRoute>()
                // The full challenge (phone + resend interval) is held by the coordinator.
                val challenge = coordinator.activeChallenge ?: OtpChallenge(route.challengeId, "", 60)
                OtpScreen(viewModel { OtpViewModel(challenge, useCases.verifyOtp, useCases.sendOtp) }, coordinator)
            }
            composable<NameRoute> { entry ->
                val route = entry.toRoute<NameRoute>()
                NameEntryScreen(
                    viewModel { NameEntryViewModel(route.challengeId, route.code, coordinator.selectedRole, useCases.registerWithName) },
                    coordinator,
                )
            }
        }
    }

    companion object {
        fun makeDefault(onFinished: (AuthState) -> Unit) = AuthenticationFeature(MockAuthRepository(), onFinished)
    }
}

/** Owns navigation for the flow; screens express intent and never navigate themselves. */
private class NavAuthCoordinator(
    private val navController: NavHostController,
    private val onFinished: (AuthState) -> Unit,
) : AuthCoordinator {
    override var activeChallenge: OtpChallenge? = null
        private set
    override var selectedRole: UserRole = UserRole.Bride
        private set

    override fun startPhoneSignIn(role: UserRole) {
        selectedRole = role
        navController.navigate(PhoneEntryRoute)
    }

    override fun didSendOtp(challenge: OtpChallenge) {
        activeChallenge = challenge
        navController.navigate(OtpRoute(challenge.id))
    }

    override fun needsName(code: String) {
        val challenge = activeChallenge ?: return
        navController.navigate(NameRoute(challenge.id, code))
    }

    override fun editPhoneNumber() = pop()

    override fun pop() {
        navController.popBackStack()
    }

    override fun didAuthenticate(user: User) {
        // The server always reports the role; when it doesn't (mock backend), use the side picked.
        onFinished(AuthState.Authenticated(if (user.role == null) user.copy(role = selectedRole) else user))
    }

    override fun didContinueAsGuest(state: AuthState) = onFinished(state)
}
