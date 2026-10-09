package com.resqmesh.resqmesh

import android.app.Application
import com.resqmesh.resqmesh.bridge.BackgroundBridge
import com.resqmesh.resqmesh.bridge.BackgroundHostApi
import com.resqmesh.resqmesh.bridge.FileBridge
import com.resqmesh.resqmesh.bridge.FileHostApi
import com.resqmesh.resqmesh.bridge.LanBridge
import com.resqmesh.resqmesh.bridge.LanHostApi
import com.resqmesh.resqmesh.bridge.NotificationBridge
import com.resqmesh.resqmesh.bridge.NotificationHostApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Owns the one FlutterEngine for the life of the process (D9, P8.1).
 * Closing the screen doesn't stop the Dart code: with the foreground
 * service running, discovery, messages and transfers carry on, and
 * reopening the app attaches the screen to the same engine.
 */
class ResQMeshApp : Application() {
    lateinit var notifications: NotificationBridge
        private set

    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        val messenger = engine.dartExecutor.binaryMessenger
        // Bridges live with the engine, not the screen.
        LanHostApi.setUp(messenger, LanBridge(this, messenger))
        notifications = NotificationBridge(this, messenger)
        NotificationHostApi.setUp(messenger, notifications)
        FileHostApi.setUp(messenger, FileBridge(this))
        BackgroundHostApi.setUp(messenger, BackgroundBridge(this))
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "main"
    }
}
