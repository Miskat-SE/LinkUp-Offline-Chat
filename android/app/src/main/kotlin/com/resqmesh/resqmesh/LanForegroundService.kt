package com.resqmesh.resqmesh

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Keeps LinkUp working while its screen is closed (PROJECT_PLAN.md §5.6,
 * P8.2): a `connectedDevice` foreground service, so Android keeps the
 * process and its network. During transfers it also holds a Wi-Fi lock
 * and a partial wake lock (P8.4); while only reachable, it holds neither.
 */
class LanForegroundService : Service() {
    private var wifiLock: WifiManager.WifiLock? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            releaseLocks()
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val transferring = intent?.getBooleanExtra(EXTRA_TRANSFERRING, false) ?: false
        val notification = build(
            title = intent?.getStringExtra(EXTRA_TITLE) ?: "LinkUp",
            text = intent?.getStringExtra(EXTRA_TEXT) ?: "",
            progress = intent?.getIntExtra(EXTRA_PROGRESS, -1) ?: -1,
            route = intent?.getStringExtra(EXTRA_ROUTE),
            transferring = transferring,
        )
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                } else {
                    0
                },
            )
        } catch (e: Exception) {
            Log.w(TAG, "Could not start in the foreground", e)
            stopSelf()
            return START_NOT_STICKY
        }
        if (transferring) holdLocks() else releaseLocks()
        // Not restarted by Android: Dart starts it again when it is needed.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseLocks()
        super.onDestroy()
    }

    private fun build(
        title: String,
        text: String,
        progress: Int,
        route: String?,
        transferring: Boolean,
    ): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Transfers and reachability",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { description = "Shown while files move or LinkUp stays reachable" },
            )
        }
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (route != null) putExtra(NotificationBridgeKeys.EXTRA_ROUTE, route)
        }
        val pending = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_linkup)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(
                if (transferring) NotificationCompat.CATEGORY_PROGRESS
                else NotificationCompat.CATEGORY_SERVICE,
            )
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(pending)
            .apply {
                if (transferring) setProgress(100, progress.coerceIn(0, 100), progress < 0)
            }
            .build()
    }

    @Suppress("DEPRECATION")
    private fun holdLocks() {
        if (wifiLock == null) {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiLock = wifi.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "linkup:transfer")
                .apply { setReferenceCounted(false); acquire() }
        }
        if (wakeLock == null) {
            val power = getSystemService(PowerManager::class.java)
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "linkup:transfer")
                .apply { setReferenceCounted(false); acquire(WAKE_LOCK_MAX_MS) }
        }
    }

    private fun releaseLocks() {
        wifiLock?.takeIf { it.isHeld }?.release()
        wifiLock = null
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }

    companion object {
        private const val TAG = "LinkUpService"
        private const val CHANNEL_ID = "background"
        private const val NOTIFICATION_ID = 7001

        /** A safety cap; refreshed with every progress update. */
        private const val WAKE_LOCK_MAX_MS = 30 * 60 * 1000L
        const val ACTION_STOP = "com.resqmesh.resqmesh.STOP"
        const val EXTRA_TRANSFERRING = "transferring"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_ROUTE = "route"
    }
}

/** Shared with NotificationBridge: taps carry an app route. */
object NotificationBridgeKeys {
    const val EXTRA_ROUTE = "route"
}
