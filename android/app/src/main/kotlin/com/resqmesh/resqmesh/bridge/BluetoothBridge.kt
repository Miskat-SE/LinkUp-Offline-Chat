package com.resqmesh.resqmesh.bridge

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.ParcelUuid
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import com.resqmesh.resqmesh.CurrentActivity
import io.flutter.plugin.common.BinaryMessenger
import java.io.IOException
import java.nio.ByteBuffer
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlin.coroutines.resume
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/**
 * Bluetooth (P14): finds LinkUp phones with Bluetooth LE advertising and
 * scanning, and carries the usual byte streams over insecure L2CAP
 * channels (Android 10+, no pairing). Dart runs the same connections,
 * framing and handshake over these links as over TCP.
 *
 * The advertisement holds the service UUID; its scan response holds the
 * device ID (16 bytes) and the control channel (2 bytes).
 */
@SuppressLint("MissingPermission") // Dart checks permissionState() first.
class BluetoothBridge(
    context: Context,
    messenger: BinaryMessenger,
) : BluetoothHostApi {
    private val appContext = context.applicationContext
    private val adapter: BluetoothAdapter? =
        appContext.getSystemService(BluetoothManager::class.java)?.adapter
    private val flutterApi = BluetoothFlutterApi(messenger)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val servers = ConcurrentHashMap<Long, BluetoothServerSocket>()
    private val links = ConcurrentHashMap<Long, Link>()
    private val nextLinkId = AtomicLong(1)
    private val lastReported = ConcurrentHashMap<String, Long>()

    private var advertisedId: String? = null
    private var advertisedChannel = 0
    private var discovering = false
    private var receiver: BroadcastReceiver? = null

    private class Link(val socket: BluetoothSocket) {
        val writer: ExecutorService = Executors.newSingleThreadExecutor()

        fun close() {
            try {
                socket.close()
            } catch (e: IOException) {
                // Already closed.
            }
            writer.shutdownNow()
        }
    }

    init {
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1)
                if (state == BluetoothAdapter.STATE_ON) {
                    if (discovering) startRadio()
                    deliver { flutterApi.onEnabledChanged(true) }
                } else if (state == BluetoothAdapter.STATE_OFF) {
                    deliver { flutterApi.onEnabledChanged(false) }
                }
            }
        }
        ContextCompat.registerReceiver(appContext, r, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        receiver = r
    }

    override fun isSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            adapter != null &&
            appContext.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)

    private fun permissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun granted(): Boolean = permissions().all {
        ContextCompat.checkSelfPermission(appContext, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun permissionState(): String {
        if (!granted()) return "denied"
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            val location = appContext.getSystemService(LocationManager::class.java)
            if (location == null || !LocationManagerCompat.isLocationEnabled(location)) {
                return "locationOff"
            }
        }
        return "granted"
    }

    override suspend fun requestPermission(): Boolean {
        if (granted()) return true
        return suspendCancellableCoroutine { continuation ->
            CurrentActivity.requestPermissions(permissions(), PERMISSION_REQUEST) {
                if (continuation.isActive) continuation.resume(it)
            }
        }
    }

    override fun isEnabled(): Boolean = adapter?.isEnabled == true

    override fun requestEnable() {
        CurrentActivity.startForResult(
            Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
            ENABLE_REQUEST,
        ) {}
    }

    override fun openLocationSettings() {
        appContext.startActivity(
            Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    // ------------------------------------------------------------- links

    override suspend fun openServer(): Long {
        val a = adapter ?: throw FlutterError("unsupported", "No Bluetooth")
        val server = withContext(Dispatchers.IO) {
            try {
                a.listenUsingInsecureL2capChannel()
            } catch (e: IOException) {
                Log.w(TAG, "Could not open an L2CAP server", e)
                throw FlutterError("serverFailed", "Could not open a channel", e.message)
            } catch (e: SecurityException) {
                // Not allowed yet; Dart opens it again once it is.
                throw FlutterError("permission", "Bluetooth permission needed", e.message)
            }
        }
        val channel = server.psm.toLong()
        servers[channel] = server
        Thread({
            while (true) {
                val socket = try {
                    server.accept()
                } catch (e: IOException) {
                    break // closed
                }
                val id = register(socket)
                deliver { flutterApi.onLinkOpened(id, socket.remoteDevice.address, channel) }
                read(id, socket)
            }
        }, "LinkUpBtAccept$channel").start()
        return channel
    }

    override fun closeServer(channel: Long) {
        try {
            servers.remove(channel)?.close()
        } catch (e: IOException) {
            // Already closed.
        }
    }

    override suspend fun connect(address: String, channel: Long): Long {
        val a = adapter ?: throw FlutterError("unsupported", "No Bluetooth")
        val socket = withContext(Dispatchers.IO) {
            val s = a.getRemoteDevice(address).createInsecureL2capChannel(channel.toInt())
            // connect() blocks; close the socket if it takes too long.
            val watchdog = Thread({
                try {
                    Thread.sleep(CONNECT_TIMEOUT_MS)
                    s.close()
                } catch (e: InterruptedException) {
                    // Connected in time.
                } catch (e: IOException) {
                    // Already closed.
                }
            }, "LinkUpBtConnectTimeout")
            watchdog.start()
            try {
                s.connect()
            } catch (e: IOException) {
                throw FlutterError("unreachable", "Could not connect", e.message)
            } finally {
                watchdog.interrupt()
            }
            s
        }
        val id = register(socket)
        read(id, socket)
        return id
    }

    override suspend fun send(linkId: Long, bytes: ByteArray) {
        val link = links[linkId] ?: return
        // Queued in order on the link's writer; completes once written, so
        // Dart can hold back a large file (backpressure).
        suspendCancellableCoroutine { continuation ->
            try {
                link.writer.execute {
                    try {
                        link.socket.outputStream.write(bytes)
                        link.socket.outputStream.flush()
                    } catch (e: IOException) {
                        link.close()
                    }
                    if (continuation.isActive) continuation.resume(Unit)
                }
            } catch (e: java.util.concurrent.RejectedExecutionException) {
                if (continuation.isActive) continuation.resume(Unit)
            }
        }
    }

    override fun closeLink(linkId: Long) {
        links.remove(linkId)?.close()
    }

    private fun register(socket: BluetoothSocket): Long {
        val id = nextLinkId.getAndIncrement()
        links[id] = Link(socket)
        return id
    }

    /** Reads until the link closes; data and the close go to Dart in order. */
    private fun read(id: Long, socket: BluetoothSocket) {
        Thread({
            val buffer = ByteArray(BUFFER)
            try {
                val input = socket.inputStream
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    val chunk = buffer.copyOf(n)
                    deliver { flutterApi.onData(id, chunk) }
                }
            } catch (e: IOException) {
                // Closed or broken.
            }
            // Closed from Dart: Dart already knows. Otherwise tell it.
            links.remove(id)?.let {
                it.close()
                deliver { flutterApi.onLinkClosed(id) }
            }
        }, "LinkUpBtRead$id").start()
    }

    // --------------------------------------------------------- discovery

    override fun startDiscovery(deviceId: String, channel: Long) {
        advertisedId = deviceId
        advertisedChannel = channel.toInt()
        discovering = true
        startRadio()
    }

    override fun stopDiscovery() {
        discovering = false
        stopRadio()
    }

    private fun startRadio() {
        val a = adapter ?: return
        if (!a.isEnabled || !granted()) return
        stopRadio()
        val id = advertisedId ?: return
        if (a.bluetoothLeAdvertiser == null) {
            Log.w(TAG, "This phone can't advertise over Bluetooth LE")
        }
        Log.i(TAG, "Advertising and scanning on channel $advertisedChannel")
        val payload = ByteBuffer.allocate(18).apply {
            val uuid = UUID.fromString(id)
            putLong(uuid.mostSignificantBits)
            putLong(uuid.leastSignificantBits)
            putShort(advertisedChannel.toShort())
        }.array()
        try {
            a.bluetoothLeAdvertiser?.startAdvertising(
                AdvertiseSettings.Builder()
                    .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
                    .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                    .setConnectable(false)
                    .build(),
                AdvertiseData.Builder()
                    .addServiceUuid(ParcelUuid(SERVICE_UUID))
                    .setIncludeDeviceName(false)
                    .build(),
                AdvertiseData.Builder()
                    .addManufacturerData(MANUFACTURER_ID, payload)
                    .build(),
                advertiseCallback,
            )
            a.bluetoothLeScanner?.startScan(
                listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE_UUID)).build()),
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build(),
                scanCallback,
            )
        } catch (e: Exception) {
            Log.w(TAG, "Could not start Bluetooth discovery", e)
        }
    }

    private fun stopRadio() {
        val a = adapter ?: return
        if (!a.isEnabled) return
        try {
            a.bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
            a.bluetoothLeScanner?.stopScan(scanCallback)
        } catch (e: Exception) {
            Log.w(TAG, "Could not stop Bluetooth discovery", e)
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) {
            Log.w(TAG, "Advertising failed: $errorCode")
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) = found(result)

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach(::found)
        }

        override fun onScanFailed(errorCode: Int) {
            Log.w(TAG, "Scan failed: $errorCode")
        }
    }

    private fun found(result: ScanResult) {
        val data = result.scanRecord?.getManufacturerSpecificData(MANUFACTURER_ID) ?: return
        if (data.size < 18) return
        val address = result.device.address
        val now = SystemClock.elapsedRealtime()
        if (now - (lastReported[address] ?: 0L) < REPORT_EVERY_MS) return
        lastReported[address] = now
        val buffer = ByteBuffer.wrap(data)
        val deviceId = UUID(buffer.long, buffer.long).toString()
        if (deviceId == advertisedId) return
        val channel = (buffer.short.toInt() and 0xFFFF).toLong()
        deliver { flutterApi.onPeerFound(BtPeer(address, deviceId, channel)) }
    }

    private fun deliver(call: suspend () -> Unit) {
        scope.launch {
            try {
                call()
            } catch (e: Exception) {
                Log.w(TAG, "Could not deliver a Bluetooth event", e)
            }
        }
    }

    private companion object {
        const val TAG = "ResQMeshBt"
        const val PERMISSION_REQUEST = 4206
        const val ENABLE_REQUEST = 4207
        const val CONNECT_TIMEOUT_MS = 15_000L
        const val REPORT_EVERY_MS = 3_000L
        const val BUFFER = 8 * 1024

        // Reserved for testing and internal use by the Bluetooth SIG.
        const val MANUFACTURER_ID = 0xFFFF
        val SERVICE_UUID: UUID = UUID.fromString("a3f1c7e2-5b8d-4e6a-9c0f-2d4b6e8a1c3f")
    }
}
