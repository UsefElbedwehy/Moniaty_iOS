package co.munyati.app

import android.app.Application
import co.munyati.app.composition.AppEnvironment

class MunyatiApplication : Application() {
    /** One composition root for the process. */
    val environment: AppEnvironment by lazy { AppEnvironment(this) }
}
