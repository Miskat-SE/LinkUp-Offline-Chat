package com.resqmesh.resqmesh.bridge

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import com.resqmesh.resqmesh.LanForegroundService

/**
 * Runs the foreground service when Dart says files are moving or Stay
 * reachable is on, and stops it otherwise (PROJECT_PLAN.md §5.6).
 */
class BackgroundBridge(private val context: Context) : BackgroundHostApi {
    private var running = false

    override fun update(state: BackgroundState) {
        val wanted = state.transferring || state.stayReachable
        if (!wanted) {
            if (running) {
                context.startService(
                    Intent(context, LanForegroundService::class.java)
                        .setAction(LanForegroundService.ACTION_STOP),
                )
            }
            running = false
            return
        }
        val intent = Intent(context, LanForegroundService::class.java).apply {
            putExtra(LanForegroundService.EXTRA_TRANSFERRING, state.transferring)
            putExtra(LanForegroundService.EXTRA_TITLE, state.title)
            putExtra(LanForegroundService.EXTRA_TEXT, state.text)
            putExtra(LanForegroundService.EXTRA_PROGRESS, state.progress?.toInt() ?: -1)
            putExtra(LanForegroundService.EXTRA_ROUTE, state.route)
        }
        try {
            // Android 12+ allows this only while the app is visible, or when
            // the service already runs (it then just updates).
            ContextCompat.startForegroundService(context, intent)
            running = true
        } catch (e: Exception) {
            Log.w(TAG, "Background service not allowed now", e)
        }
    }

    override fun openBatterySettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", context.packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private companion object {
        const val TAG = "LinkUpBackground"
    }
}
