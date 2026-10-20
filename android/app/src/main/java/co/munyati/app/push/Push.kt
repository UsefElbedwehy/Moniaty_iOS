package co.munyati.app.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import co.munyati.app.MainActivity
import co.munyati.app.MunyatiApplication
import co.munyati.app.R
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Push through Firebase Cloud Messaging, the same project and `send-push` function as iOS. Off
 * until `google-services.json` is added (Firebase isn't initialized without it).
 */
object Push {
    const val CHANNEL_ID = "munyati_default"
    const val EXTRA_DEEP_LINK = "deep_link"

    fun isAvailable(context: Context): Boolean = FirebaseApp.getApps(context).isNotEmpty()

    /** The one channel bookings, payments and announcements arrive on. */
    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(CHANNEL_ID, context.getString(R.string.push_channel_name), NotificationManager.IMPORTANCE_HIGH)
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    /** The current FCM token, or null when Firebase is off or the token isn't ready. */
    fun currentToken(context: Context, onToken: (String) -> Unit) {
        if (!isAvailable(context)) return
        FirebaseMessaging.getInstance().token.addOnSuccessListener { token -> token?.let(onToken) }
    }

    /**
     * Shows a notification while the app is open (in the background the system shows FCM's
     * notification itself and passes the data extras, including `deep_link`, to MainActivity).
     */
    fun show(context: Context, title: String?, body: String?, deepLink: String?, id: Int) {
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            deepLink?.let { putExtra(EXTRA_DEEP_LINK, it) }
        }
        val pending = PendingIntent.getActivity(context, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFF8A0D3A.toInt())
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pending)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(id, notification) } // no permission: silently skipped
    }
}

/** Receives FCM tokens and messages. */
class MunyatiMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        (application as MunyatiApplication).environment.registerDeviceToken(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val notification = message.notification
        Push.show(
            context = this,
            title = notification?.title ?: message.data["title"],
            body = notification?.body ?: message.data["body"],
            deepLink = message.data[Push.EXTRA_DEEP_LINK],
            id = (message.data["notification_id"] ?: message.messageId ?: System.currentTimeMillis().toString()).hashCode(),
        )
    }
}
