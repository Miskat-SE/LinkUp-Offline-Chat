package com.resqmesh.resqmesh.bridge

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.SocketException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Local-network side of the platform bridge (ADR-0007, ADR-0008).
 *
 * - Watches Wi-Fi without requiring internet, so a router with its WAN
 *   unplugged still counts as connected.
 * - Binds the whole process (including dart:io sockets) to that Wi-Fi network,
 *   so LAN traffic never leaks onto mobile data.
 * - Reports this phone's own hotspot interface, which has no Wi-Fi callback,
 *   by polling the interface list.
 * - Holds a multicast lock while discovery runs.
 */
class LanBridge(
    context: Context,
    messenger: BinaryMessenger,
) : LanHostApi {
    private val appContext = context.applicationContext
    private val connectivity = appContext.getSystemService(ConnectivityManager::class.java)
    private val wifi = appContext.getSystemService(WifiManager::class.java)
    private val flutterApi = LanFlutterApi(messenger)
    private val main = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var callback: ConnectivityManager.NetworkCallback? = null
    private var wifiNetwork: Network? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var lastPublished: LanSnapshot? = null

    private val poll = object : Runnable {
        override fun run() {
            publish()
            main.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun startMonitoring() {
        if (callback != null) return
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            // Wi-Fi without internet is still a working LAN (spec §16).
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        val networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                main.post {
                    wifiNetwork = network
                    connectivity.bindProcessToNetwork(network)
                    publish()
                }
            }

            override fun onLinkPropertiesChanged(network: Network, properties: LinkProperties) {
                main.post { publish() }
            }

            override fun onLost(network: Network) {
                main.post {
                    if (network == wifiNetwork) {
                        wifiNetwork = null
                        connectivity.bindProcessToNetwork(null)
                    }
                    publish()
                }
            }
        }
        connectivity.registerNetworkCallback(request, networkCallback)
        callback = networkCallback
        main.postDelayed(poll, POLL_INTERVAL_MS)
        publish()
    }

    override fun stopMonitoring() {
        callback?.let { connectivity.unregisterNetworkCallback(it) }
        callback = null
        main.removeCallbacks(poll)
        if (wifiNetwork != null) connectivity.bindProcessToNetwork(null)
        wifiNetwork = null
        lastPublished = null
    }

    override fun currentSnapshot(): LanSnapshot = buildSnapshot()

    override fun acquireMulticastLock() {
        val lock = multicastLock ?: wifi.createMulticastLock("resqmesh-discovery").also {
            it.setReferenceCounted(false)
            multicastLock = it
        }
        if (!lock.isHeld) lock.acquire()
    }

    override fun releaseMulticastLock() {
        multicastLock?.takeIf { it.isHeld }?.release()
    }

    override fun appInfo(): AppInfo {
        val info = appContext.packageManager.getPackageInfo(appContext.packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return AppInfo(versionName = info.versionName ?: "", versionCode = code)
    }

    fun dispose() {
        stopMonitoring()
        releaseMulticastLock()
        scope.cancel()
    }

    private fun publish() {
        val snapshot = buildSnapshot()
        if (snapshot == lastPublished) return
        lastPublished = snapshot
        scope.launch {
            try {
                flutterApi.onLanChanged(snapshot)
            } catch (e: Exception) {
                Log.w(TAG, "Could not deliver LAN snapshot", e)
            }
        }
    }

    private fun buildSnapshot(): LanSnapshot {
        val interfaces = mutableListOf<LanInterfaceInfo>()
        var wifiInterface: String? = null

        wifiNetwork?.let { network ->
            connectivity.getLinkProperties(network)?.let { properties ->
                wifiInterface = properties.interfaceName
                for (link in properties.linkAddresses) {
                    val address = link.address as? Inet4Address ?: continue
                    interfaces += LanInterfaceInfo(
                        name = properties.interfaceName ?: "wifi",
                        address = address.hostAddress ?: continue,
                        prefixLength = link.prefixLength.toLong(),
                        kind = "wifi",
                    )
                }
            }
        }

        // Interfaces this phone serves itself, such as its own hotspot.
        try {
            val all = NetworkInterface.getNetworkInterfaces()?.toList().orEmpty()
            for (ni in all) {
                if (!ni.isUp || ni.isLoopback || ni.isVirtual || ni.name == wifiInterface) continue
                if (EXCLUDED_PREFIXES.any { ni.name.startsWith(it) }) continue
                val kind = if (HOTSPOT_PREFIXES.any { ni.name.startsWith(it) }) "hotspot" else "other"
                for (ia in ni.interfaceAddresses) {
                    val address = ia.address as? Inet4Address ?: continue
                    if (!address.isSiteLocalAddress) continue
                    interfaces += LanInterfaceInfo(
                        name = ni.name,
                        address = address.hostAddress ?: continue,
                        prefixLength = ia.networkPrefixLength.toLong(),
                        kind = kind,
                    )
                }
            }
        } catch (e: SocketException) {
            Log.w(TAG, "Could not list network interfaces", e)
        }

        val bound = connectivity.boundNetworkForProcess
        return LanSnapshot(
            wifiConnected = wifiNetwork != null,
            boundToWifi = bound != null && bound == wifiNetwork,
            interfaces = interfaces,
        )
    }

    private companion object {
        const val TAG = "ResQMeshLan"
        const val POLL_INTERVAL_MS = 5_000L

        // Access-point interface names used by Android and phone makers.
        val HOTSPOT_PREFIXES = listOf("ap", "swlan", "softap", "wlan", "wigig")

        // Mobile data, VPN, tunnels and Wi-Fi Direct (handled in P13).
        val EXCLUDED_PREFIXES = listOf(
            "rmnet", "ccmni", "pdp", "v4-", "clat", "tun", "ppp", "dummy", "ip6", "sit", "p2p",
        )
    }
}
