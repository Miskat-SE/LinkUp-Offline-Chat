package com.resqmesh.resqmesh.bridge

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import com.resqmesh.resqmesh.CurrentActivity
import io.flutter.plugin.common.BinaryMessenger
import java.io.File
import kotlin.coroutines.resume
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Voice messages (P15.7): records AAC (.m4a, mono, 32 kbit/s, about 240 KB a
 * minute) and plays messages back, one at a time, reporting progress to Dart.
 */
class VoiceBridge(
    context: Context,
    messenger: BinaryMessenger,
) : VoiceHostApi {
    private val appContext = context.applicationContext
    private val flutterApi = VoiceFlutterApi(messenger)
    private val main = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var recorder: MediaRecorder? = null
    private var recording: File? = null
    private var startedAt = 0L

    private var player: MediaPlayer? = null
    private var playingPath: String? = null

    private val tick = object : Runnable {
        override fun run() {
            report()
            if (player?.isPlaying == true) main.postDelayed(this, TICK_MS)
        }
    }

    override fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(appContext, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    override suspend fun requestPermission(): Boolean {
        if (hasPermission()) return true
        return suspendCancellableCoroutine { continuation ->
            CurrentActivity.requestPermission(Manifest.permission.RECORD_AUDIO, MIC_REQUEST) {
                if (continuation.isActive) continuation.resume(it)
            }
        }
    }

    override fun startRecording(): String {
        cancelRecording()
        stopPlayback()
        val dir = File(appContext.cacheDir, "voice").apply { mkdirs() }
        val file = File(dir, "VOICE_${System.currentTimeMillis()}.m4a")
        val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(appContext)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        try {
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioChannels(1)
            r.setAudioSamplingRate(SAMPLE_RATE)
            r.setAudioEncodingBitRate(BIT_RATE)
            r.setMaxDuration(MAX_MS)
            r.setOutputFile(file.path)
            r.prepare()
            r.start()
        } catch (e: Exception) {
            r.release()
            file.delete()
            throw FlutterError("recordFailed", "Could not start recording", e.message)
        }
        recorder = r
        recording = file
        startedAt = SystemClock.elapsedRealtime()
        return file.path
    }

    override fun stopRecording(): Long {
        val r = recorder ?: return 0
        val file = recording
        val length = SystemClock.elapsedRealtime() - startedAt
        recorder = null
        recording = null
        val ok = try {
            r.stop()
            true
        } catch (e: RuntimeException) {
            // Stopped before any audio was written.
            false
        } finally {
            r.release()
        }
        if (!ok || length < MIN_MS || file == null || file.length() == 0L) {
            file?.delete()
            return 0
        }
        return length.coerceAtMost(MAX_MS.toLong())
    }

    override fun cancelRecording() {
        val r = recorder ?: return
        recorder = null
        try {
            r.stop()
        } catch (e: RuntimeException) {
            // Nothing recorded yet.
        }
        r.release()
        recording?.delete()
        recording = null
    }

    override fun level(): Long = (recorder?.maxAmplitude ?: 0).toLong()

    override fun play(path: String) {
        val current = player
        if (current != null && playingPath == path) {
            current.start()
        } else {
            stopPlayback()
            try {
                player = MediaPlayer().apply {
                    setDataSource(path)
                    prepare()
                    setOnCompletionListener {
                        seekTo(0)
                        report(playing = false)
                        stopPlayback()
                    }
                    start()
                }
                playingPath = path
            } catch (e: Exception) {
                Log.w(TAG, "Could not play a voice message", e)
                stopPlayback()
                return
            }
        }
        main.removeCallbacks(tick)
        main.post(tick)
    }

    override fun pause() {
        player?.pause()
        main.removeCallbacks(tick)
        report()
    }

    override fun stopPlayback() {
        main.removeCallbacks(tick)
        val p = player ?: return
        val path = playingPath
        player = null
        playingPath = null
        p.release()
        if (path != null) deliver(VoicePlayback(path, 0, 0, false))
    }

    private fun report(playing: Boolean? = null) {
        val p = player ?: return
        val path = playingPath ?: return
        deliver(
            VoicePlayback(
                path = path,
                positionMs = p.currentPosition.toLong(),
                durationMs = p.duration.toLong(),
                playing = playing ?: p.isPlaying,
            ),
        )
    }

    private fun deliver(state: VoicePlayback) {
        scope.launch {
            try {
                flutterApi.onPlayback(state)
            } catch (e: Exception) {
                Log.w(TAG, "Could not deliver playback state", e)
            }
        }
    }

    private companion object {
        const val TAG = "ResQMeshVoice"
        const val MIC_REQUEST = 4205
        const val SAMPLE_RATE = 22_050
        const val BIT_RATE = 32_000
        const val MAX_MS = 10 * 60 * 1000
        const val MIN_MS = 700L
        const val TICK_MS = 200L
    }
}
