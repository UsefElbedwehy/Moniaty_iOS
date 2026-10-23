package co.munyati.app

import android.app.Application
import co.munyati.app.composition.AppEnvironment
import co.munyati.app.push.Push

class MunyatiApplication : Application() {
    /** One composition root for the process. */
    val environment: AppEnvironment by lazy { AppEnvironment(this) }

    override fun onCreate() {
        super.onCreate()
        Push.createChannel(this)
    }
}
