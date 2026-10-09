package com.resqmesh.resqmesh

import com.resqmesh.resqmesh.bridge.LanBridge
import com.resqmesh.resqmesh.bridge.LanHostApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var lanBridge: LanBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val bridge = LanBridge(applicationContext, messenger)
        LanHostApi.setUp(messenger, bridge)
        lanBridge = bridge
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        LanHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        lanBridge?.dispose()
        lanBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
