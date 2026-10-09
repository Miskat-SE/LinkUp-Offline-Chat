package com.resqmesh.resqmesh.bridge

import android.Manifest
import android.app.Activity
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
import com.resqmesh.resqmesh.R
import io.flutter.plugin.common.BinaryMessenger
import kotlin.coroutines.resume
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Message notifications and the Android 13+ notification permission
 * (PROJECT_PLAN.md §5.4). Tapping a notification opens that chat.
 */
class NotificationBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : NotificationHostApi {
    private val context: Context = activity.applicationContext
    private val flutterApi = NotificationFlutterApi(messenger)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var permissionResult: ((Boolean) -> Unit)? = null
    private var launchConversation: String? = null

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
            permissionResult = { granted ->
                if (continuation.isActive) continuation.resume(granted)
            }
            activity.requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                PERMISSION_REQUEST,
            )
        }
    }

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int, results: IntArray) {
        if (requestCode != PERMISSION_REQUEST) return
        val granted = results.isNotEmpty() && results[0] == PackageManager.PERMISSION_GRANTED
        permissionResult?.invoke(granted)
        permissionResult = null
    }

    override fun showMessageNotification(notification: MessageNotification) {
        if (!notificationsAllowed()) return
        val open = Intent(context, activity.javaClass).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_CONVERSATION, notification.conversationId)
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

    override fun takeLaunchConversation(): String? =
        launchConversation.also { launchConversation = null }

    /** The activity was started or resumed from a notification. */
    fun handleIntent(intent: Intent?, launched: Boolean) {
        val id = intent?.getStringExtra(EXTRA_CONVERSATION) ?: return
        intent.removeExtra(EXTRA_CONVERSATION)
        if (launched) {
            launchConversation = id
        } else {
            scope.launch {
                try {
                    flutterApi.onNotificationOpened(id)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not open chat from notification", e)
                }
            }
        }
    }

    fun dispose() = scope.cancel()

    private fun hasPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private companion object {
        const val TAG = "LinkUpNotifications"
        const val CHANNEL_ID = "messages"
        const val EXTRA_CONVERSATION = "conversationId"
        const val PERMISSION_REQUEST = 4201
    }
}
