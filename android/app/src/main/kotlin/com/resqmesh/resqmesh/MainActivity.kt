package com.resqmesh.resqmesh

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * The screen. It attaches to the engine the Application owns and leaves it
 * running when it closes (P8.1); the bridges live with that engine.
 */
class MainActivity : FlutterActivity() {
    private val app get() = application as ResQMeshApp

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(ResQMeshApp.ENGINE_ID)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CurrentActivity.activity = this
        // Opened by tapping a notification?
        app.notifications.handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        app.notifications.handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        CurrentActivity.activity = this
    }

    override fun onDestroy() {
        if (CurrentActivity.activity === this) CurrentActivity.activity = null
        super.onDestroy()
    }

    @Deprecated("Activity result API; FlutterActivity still forwards here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!CurrentActivity.onActivityResult(requestCode, resultCode)) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        CurrentActivity.onPermissionResult(requestCode, grantResults)
    }
}
