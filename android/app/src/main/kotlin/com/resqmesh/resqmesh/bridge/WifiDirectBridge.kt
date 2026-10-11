package com.resqmesh.resqmesh.bridge

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.WpsInfo
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pManager
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceInfo
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import com.resqmesh.resqmesh.CurrentActivity
import io.flutter.plugin.common.BinaryMessenger
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Wi-Fi Direct (ADR-0023): advertises this phone as a `_linkup._tcp`
 * service, reports the LinkUp phones it finds, and creates, joins or leaves
 * a group when Dart decides to. Once a group exists, LanBridge reports its
 * `p2p-…` interface and the normal LAN stack runs over it.
 */
@SuppressLint("MissingPermission") // Dart checks permissionState() first.
class WifiDirectBridge(
    context: Context,
    messenger: BinaryMessenger,
) : WifiDirectHostApi {
    private val appContext = context.applicationContext
    private val manager: WifiP2pManager? = appContext.getSystemService(WifiP2pManager::class.java)
    private val flutterApi = WifiDirectFlutterApi(messenger)
    private val main = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var channel: WifiP2pManager.Channel? = null
    private var receiver: BroadcastReceiver? = null
    private var service: WifiP2pDnsSdServiceInfo? = null
    private var deviceId = ""
    private var name = ""
    private var hosting = false
    private var networkName: String? = null
    private var passphrase: String? = null
    private var enabled = false
    private var inGroup = false
    private var lonelyOwner = false

    /** Service discovery stops by itself; repeat it while looking. */
    private val discoverLoop = object : Runnable {
        override fun run() {
            if (!inGroup || lonelyOwner) discover()
            main.postDelayed(this, DISCOVER_INTERVAL_MS)
        }
    }

    override fun isSupported(): Boolean =
        manager != null &&
            appContext.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_DIRECT)

    override fun permissionState(): String {
        if (ContextCompat.checkSelfPermission(appContext, permission()) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return "denied"
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            val location = appContext.getSystemService(LocationManager::class.java)
            if (location == null || !LocationManagerCompat.isLocationEnabled(location)) {
                return "locationOff"
            }
        }
        return "granted"
    }

    override suspend fun requestPermission(): Boolean {
        if (ContextCompat.checkSelfPermission(appContext, permission()) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return true
        }
        return suspendCancellableCoroutine { continuation ->
            CurrentActivity.requestPermission(permission(), PERMISSION_REQUEST) { granted ->
                if (continuation.isActive) continuation.resume(granted)
            }
        }
    }

    override fun openLocationSettings() {
        appContext.startActivity(
            Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    override fun start(deviceId: String, name: String) {
        this.deviceId = deviceId
        this.name = name
        val m = manager ?: return
        if (channel == null) {
            channel = m.initialize(appContext, Looper.getMainLooper()) { channel = null }
            m.setDnsSdResponseListeners(channel, null) { domain, record, device ->
                if (!domain.contains(SERVICE_TYPE)) return@setDnsSdResponseListeners
                found(record, device.deviceAddress)
            }
            registerReceiver()
        }
        publishService()
        main.removeCallbacks(discoverLoop)
        main.post(discoverLoop)
    }

    override fun stop() {
        main.removeCallbacks(discoverLoop)
        val m = manager ?: return
        val ch = channel ?: return
        m.clearServiceRequests(ch, null)
        m.clearLocalServices(ch, null)
        m.removeGroup(ch, null)
        receiver?.let { appContext.unregisterReceiver(it) }
        receiver = null
        service = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) ch.close()
        channel = null
    }

    override fun advertise(hosting: Boolean, networkName: String?, passphrase: String?) {
        this.hosting = hosting
        this.networkName = networkName
        this.passphrase = passphrase
        publishService()
    }

    override suspend fun createGroup(networkName: String, passphrase: String) {
        val m = manager ?: throw FlutterError("unsupported", "No Wi-Fi Direct")
        val ch = channel ?: throw FlutterError("notStarted", "Wi-Fi Direct not started")
        m.stopPeerDiscovery(ch, null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val config = WifiP2pConfig.Builder()
                .setNetworkName(networkName)
                .setPassphrase(passphrase)
                .enablePersistentMode(false)
                .build()
            action { m.createGroup(ch, config, it) }
        } else {
            // Android 8–9 choose the credentials; Dart reads them from the group.
            action { m.createGroup(ch, it) }
        }
    }

    override suspend fun joinGroup(deviceAddress: String, networkName: String?, passphrase: String?) {
        val m = manager ?: throw FlutterError("unsupported", "No Wi-Fi Direct")
        val ch = channel ?: throw FlutterError("notStarted", "Wi-Fi Direct not started")
        m.stopPeerDiscovery(ch, null)
        val config =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && networkName != null && passphrase != null) {
                // Joins with the host's credentials: no dialog on either phone.
                WifiP2pConfig.Builder()
                    .setNetworkName(networkName)
                    .setPassphrase(passphrase)
                    .enablePersistentMode(false)
                    .build()
            } else {
                // Classic invitation: the host sees Android's Accept dialog.
                WifiP2pConfig().apply {
                    this.deviceAddress = deviceAddress
                    wps.setup = WpsInfo.PBC
                    groupOwnerIntent = 0
                }
            }
        action { m.connect(ch, config, it) }
    }

    override suspend fun leaveGroup() {
        val m = manager ?: return
        val ch = channel ?: return
        try {
            action { m.removeGroup(ch, it) }
        } catch (e: FlutterError) {
            // No group to leave.
        }
    }

    private fun permission(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.NEARBY_WIFI_DEVICES
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }

    private fun granted(): Boolean = permissionState() == "granted"

    /** Replaces this phone's service record with the current details. */
    private fun publishService() {
        val m = manager ?: return
        val ch = channel ?: return
        if (!granted() || deviceId.isEmpty()) return
        val record = mutableMapOf(
            "v" to "1",
            "id" to deviceId,
            "n" to name.take(MAX_NAME),
            "h" to if (hosting) "1" else "0",
        )
        if (hosting) {
            networkName?.let { record["s"] = it }
            passphrase?.let { record["p"] = it }
        }
        val next = WifiP2pDnsSdServiceInfo.newInstance(SERVICE_NAME, SERVICE_TYPE, record)
        val previous = service
        service = next
        try {
            if (previous != null) m.removeLocalService(ch, previous, null)
            m.addLocalService(ch, next, logFailure("addLocalService"))
        } catch (e: SecurityException) {
            Log.w(TAG, "No permission to advertise", e)
        }
    }

    private fun discover() {
        val m = manager ?: return
        val ch = channel ?: return
        if (!granted() || !enabled) return
        try {
            // Some phones answer service queries only while peer discovery runs.
            m.discoverPeers(ch, null)
            m.clearServiceRequests(ch, null)
            m.addServiceRequest(ch, WifiP2pDnsSdServiceRequest.newInstance(), null)
            m.discoverServices(ch, logFailure("discoverServices"))
        } catch (e: SecurityException) {
            Log.w(TAG, "No permission to discover", e)
        }
    }

    private fun found(record: Map<String, String>, deviceAddress: String) {
        if (record["v"] != "1") return
        val id = record["id"] ?: return
        if (id == deviceId || !ID_PATTERN.matches(id)) return
        val service = WifiDirectService(
            deviceAddress = deviceAddress,
            deviceId = id,
            name = record["n"].orEmpty().take(MAX_NAME),
            hosting = record["h"] == "1",
            networkName = record["s"],
            passphrase = record["p"],
        )
        scope.launch {
            try {
                flutterApi.onServiceFound(service)
            } catch (e: Exception) {
                Log.w(TAG, "Could not deliver a found phone", e)
            }
        }
    }

    private fun registerReceiver() {
        val filter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
        }
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION) {
                    enabled = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1) ==
                        WifiP2pManager.WIFI_P2P_STATE_ENABLED
                }
                publishGroup()
            }
        }
        ContextCompat.registerReceiver(appContext, r, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        receiver = r
    }

    private fun publishGroup() {
        val m = manager ?: return
        val ch = channel ?: return
        if (!granted()) {
            deliver(WifiDirectGroup(enabled, false, false, 0))
            return
        }
        try {
            m.requestGroupInfo(ch) { group ->
                inGroup = group != null
                lonelyOwner = group != null && group.isGroupOwner && group.clientList.isEmpty()
                deliver(
                    WifiDirectGroup(
                        enabled = enabled,
                        formed = group != null,
                        isOwner = group?.isGroupOwner ?: false,
                        clients = (group?.clientList?.size ?: 0).toLong(),
                        networkName = group?.networkName,
                        passphrase = group?.passphrase,
                    ),
                )
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "No permission to read the group", e)
        }
    }

    private fun deliver(group: WifiDirectGroup) {
        scope.launch {
            try {
                flutterApi.onGroupChanged(group)
            } catch (e: Exception) {
                Log.w(TAG, "Could not deliver the group state", e)
            }
        }
    }

    /** Runs a WifiP2pManager call and waits for its result. */
    private suspend fun action(call: (WifiP2pManager.ActionListener) -> Unit) =
        suspendCancellableCoroutine { continuation ->
            call(object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    if (continuation.isActive) continuation.resume(Unit)
                }

                override fun onFailure(reason: Int) {
                    if (continuation.isActive) {
                        continuation.resumeWithException(
                            FlutterError(reasonName(reason), "Wi-Fi Direct failed: ${reasonName(reason)}"),
                        )
                    }
                }
            })
        }

    private fun logFailure(what: String) = object : WifiP2pManager.ActionListener {
        override fun onSuccess() {}

        override fun onFailure(reason: Int) {
            Log.w(TAG, "$what failed: ${reasonName(reason)}")
        }
    }

    private companion object {
        const val TAG = "ResQMeshP2p"
        const val SERVICE_NAME = "LinkUp"
        const val SERVICE_TYPE = "_linkup._tcp"
        const val PERMISSION_REQUEST = 4203
        const val DISCOVER_INTERVAL_MS = 15_000L
        const val MAX_NAME = 60
        val ID_PATTERN = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

        fun reasonName(reason: Int) = when (reason) {
            WifiP2pManager.P2P_UNSUPPORTED -> "unsupported"
            WifiP2pManager.BUSY -> "busy"
            WifiP2pManager.NO_SERVICE_REQUESTS -> "noServiceRequests"
            else -> "error"
        }
    }
}
