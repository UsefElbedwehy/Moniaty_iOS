package co.munyati.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import co.munyati.app.push.Push
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import co.munyati.app.composition.DeepLink
import co.munyati.app.shell.RootView
import co.munyati.designsystem.theme.MunyatiTheme
import co.munyati.app.composition.Appearance
import androidx.compose.foundation.isSystemInDarkTheme
import co.munyati.shared.analytics.LocalAnalytics

class MainActivity : ComponentActivity() {
    private val environment get() = (application as MunyatiApplication).environment

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null) {
            handle(intent)
            askForNotifications()
        }
        setContent {
            val darkTheme = when (environment.appearance.value) {
                Appearance.System -> isSystemInDarkTheme()
                Appearance.Light -> false
                Appearance.Dark -> true
            }
            MunyatiTheme(darkTheme = darkTheme) {
                CompositionLocalProvider(LocalAnalytics provides environment.analytics) {
                    RootView(environment)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) Push.currentToken(this, environment::registerDeviceToken)
    }

    /** Asks once at launch, like iOS (Android 13+ needs the runtime permission). */
    private fun askForNotifications() {
        if (!Push.isAvailable(this) || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    /** App Links, `munyati://` links and (later) notification taps carrying `deep_link`. */
    private fun handle(intent: Intent?) {
        val link = DeepLink.from(intent?.data) ?: DeepLink.from(intent?.getStringExtra(Push.EXTRA_DEEP_LINK))
        environment.open(link)
    }
}
