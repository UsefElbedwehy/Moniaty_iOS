package co.munyati.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import co.munyati.app.composition.DeepLink
import co.munyati.app.shell.RootView
import co.munyati.designsystem.theme.MunyatiTheme
import co.munyati.shared.analytics.LocalAnalytics

class MainActivity : ComponentActivity() {
    private val environment get() = (application as MunyatiApplication).environment

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null) handle(intent)
        setContent {
            MunyatiTheme {
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

    /** App Links, `munyati://` links and (later) notification taps carrying `deep_link`. */
    private fun handle(intent: Intent?) {
        val link = DeepLink.from(intent?.data) ?: DeepLink.from(intent?.getStringExtra("deep_link"))
        environment.open(link)
    }
}
