package com.resqmesh.resqmesh.bridge

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.resqmesh.resqmesh.CurrentActivity
import com.resqmesh.resqmesh.MainActivity
import com.resqmesh.resqmesh.NotificationBridgeKeys
import com.resqmesh.resqmesh.R
import io.flutter.plugin.common.BinaryMessenger
import kotlin.coroutines.resume
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Message notifications and the Android 13+ notification permission
 * (PROJECT_PLAN.md §5.4). Every tap carries an app route; it waits here
 * until Dart collects it, so a tap is never lost or handled twice, even
 * when the app's code started before the screen (cached engine, P8.1).
 */
class NotificationBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : NotificationHostApi {
    private val flutterApi = NotificationFlutterApi(messenger)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var openedRoute: String? = null

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Messages",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "New messages from people nearby" }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun notificationsAllowed(): Boolean =
        hasPermission() && NotificationManagerCompat.from(context).areNotificationsEnabled()

    override suspend fun requestNotificationPermission(): Boolean {
        if (hasPermission()) return notificationsAllowed()
        return suspendCancellableCoroutine { continuation ->
            CurrentActivity.requestPermission(
                Manifest.permission.POST_NOTIFICATIONS,
                PERMISSION_REQUEST,
            ) { granted -> if (continuation.isActive) continuation.resume(granted) }
        }
    }

    override fun showMessageNotification(notification: MessageNotification) {
        if (!notificationsAllowed()) return
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(NotificationBridgeKeys.EXTRA_ROUTE, "/chat/${notification.conversationId}")
        }
        val pending = PendingIntent.getActivity(
            context,
            notification.conversationId.hashCode(),
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val built = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_linkup)
            .setContentTitle(notification.title)
            .setContentText(notification.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(notification.body))
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        try {
            NotificationManagerCompat.from(context)
                .notify(notification.conversationId.hashCode(), built)
        } catch (e: SecurityException) {
            Log.w(TAG, "Notification permission revoked", e)
        }
    }

    override fun cancelConversation(conversationId: String) {
        NotificationManagerCompat.from(context).cancel(conversationId.hashCode())
    }

    override fun takeOpenedRoute(): String? = openedRoute.also { openedRoute = null }

    /** The activity was started or resumed from a notification. */
    fun handleIntent(intent: Intent?) {
        val route = intent?.getStringExtra(NotificationBridgeKeys.EXTRA_ROUTE) ?: return
        intent.removeExtra(NotificationBridgeKeys.EXTRA_ROUTE)
        openedRoute = route
        scope.launch {
            try {
                flutterApi.onNotificationOpened()
            } catch (e: Exception) {
                // Dart isn't listening yet; it collects the route on start.
                Log.d(TAG, "Route left for Dart to collect", e)
            }
        }
    }

    private fun hasPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private companion object {
        const val TAG = "LinkUpNotifications"
        const val CHANNEL_ID = "messages"
        const val PERMISSION_REQUEST = 4201
    }
}
