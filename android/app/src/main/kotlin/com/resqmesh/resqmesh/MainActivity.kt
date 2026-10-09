package com.resqmesh.resqmesh

import android.content.Intent
import com.resqmesh.resqmesh.bridge.FileBridge
import com.resqmesh.resqmesh.bridge.FileHostApi
import com.resqmesh.resqmesh.bridge.LanBridge
import com.resqmesh.resqmesh.bridge.LanHostApi
import com.resqmesh.resqmesh.bridge.NotificationBridge
import com.resqmesh.resqmesh.bridge.NotificationHostApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var lanBridge: LanBridge? = null
    private var notificationBridge: NotificationBridge? = null
    private var fileBridge: FileBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val lan = LanBridge(applicationContext, messenger)
        LanHostApi.setUp(messenger, lan)
        lanBridge = lan
        val notifications = NotificationBridge(this, messenger)
        NotificationHostApi.setUp(messenger, notifications)
        notificationBridge = notifications
        val files = FileBridge(this)
        FileHostApi.setUp(messenger, files)
        fileBridge = files
        // Opened by tapping a message notification?
        notifications.handleIntent(intent, launched = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        notificationBridge?.handleIntent(intent, launched = false)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        notificationBridge?.onPermissionResult(requestCode, grantResults)
        fileBridge?.onPermissionResult(requestCode, grantResults)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        LanHostApi.setUp(messenger, null)
        NotificationHostApi.setUp(messenger, null)
        FileHostApi.setUp(messenger, null)
        fileBridge = null
        lanBridge?.dispose()
        lanBridge = null
        notificationBridge?.dispose()
        notificationBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
