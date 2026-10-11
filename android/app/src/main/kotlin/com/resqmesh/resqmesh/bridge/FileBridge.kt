package com.resqmesh.resqmesh.bridge

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.ThumbnailUtils
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import android.system.Os
import android.util.Log
import android.util.Size
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.resqmesh.resqmesh.CurrentActivity
import java.io.File
import java.io.FileOutputStream
import kotlin.coroutines.resume
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/**
 * Open, Share, Save to Downloads and video thumbnails for shared files
 * (PROJECT_PLAN.md D8, §8.2). Files are stored under their IDs (ADR-0014),
 * so other apps get a hard link with the real name in `files/shared/`,
 * served through a FileProvider: no copy, and nothing outside the app.
 */
class FileBridge(context: Context) : FileHostApi {
    private val context: Context = context.applicationContext

    override fun freeBytes(): Long = StatFs(context.filesDir.path).availableBytes

    override fun openFile(path: String, displayName: String, mimeType: String): Boolean {
        val uri = expose(path, displayName) ?: return false
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    override fun shareFile(path: String, displayName: String, mimeType: String) {
        val uri = expose(path, displayName) ?: return
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(
            Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    override suspend fun saveToDownloads(
        path: String,
        displayName: String,
        mimeType: String,
    ): String? {
        val source = File(path)
        if (!source.exists()) return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            withContext(Dispatchers.IO) { saveWithMediaStore(source, displayName, mimeType) }
        } else {
            if (!hasLegacyWritePermission() && !requestLegacyWritePermission()) return null
            withContext(Dispatchers.IO) { saveLegacy(source, displayName) }
        }
    }

    override suspend fun videoThumbnail(path: String, outPath: String): Boolean =
        withContext(Dispatchers.IO) {
            try {
                val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ThumbnailUtils.createVideoThumbnail(File(path), Size(512, 512), null)
                } else {
                    @Suppress("DEPRECATION")
                    ThumbnailUtils.createVideoThumbnail(path, MediaStore.Images.Thumbnails.MINI_KIND)
                } ?: return@withContext false
                val out = File(outPath)
                out.parentFile?.mkdirs()
                FileOutputStream(out).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 80, it) }
                bitmap.recycle()
                true
            } catch (e: Exception) {
                Log.w(TAG, "No video thumbnail", e)
                false
            }
        }

    override suspend fun takePhoto(): String? {
        val dir = File(context.cacheDir, "camera").apply { mkdirs() }
        val stamp = java.text.SimpleDateFormat("yyyyMMdd_HHmmss", java.util.Locale.US)
            .format(java.util.Date())
        val photo = File(dir, "IMG_$stamp.jpg")
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", photo)
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val ok = suspendCancellableCoroutine { continuation ->
            CurrentActivity.startForResult(intent, CAMERA_REQUEST) { done ->
                if (continuation.isActive) continuation.resume(done)
            }
        }
        if (ok && photo.length() > 0) return photo.path
        photo.delete()
        return null
    }

    /** A content URI showing [displayName] for the stored file. */
    private fun expose(path: String, displayName: String): Uri? {
        val source = File(path)
        if (!source.exists()) return null
        val dir = File(context.filesDir, "files/shared/${source.name}")
        dir.deleteRecursively()
        dir.mkdirs()
        val named = File(dir, displayName)
        try {
            Os.link(source.path, named.path)
        } catch (e: Exception) {
            // Some file systems refuse hard links: fall back to a copy.
            Log.w(TAG, "Hard link failed, copying", e)
            source.copyTo(named, overwrite = true)
        }
        return FileProvider.getUriForFile(context, "${context.packageName}.files", named)
    }

    private fun saveWithMediaStore(source: File, displayName: String, mimeType: String): String? {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null
        return try {
            resolver.openOutputStream(uri)?.use { out ->
                source.inputStream().use { it.copyTo(out, BUFFER) }
            } ?: throw IllegalStateException("no output stream")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            // Android may rename it, e.g. "photo (1).jpg".
            resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else displayName }
                ?: displayName
        } catch (e: Exception) {
            Log.w(TAG, "Save to Downloads failed", e)
            resolver.delete(uri, null, null)
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(source: File, displayName: String): String? {
        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        downloads.mkdirs()
        val dot = displayName.lastIndexOf('.')
        val base = if (dot > 0) displayName.substring(0, dot) else displayName
        val extension = if (dot > 0) displayName.substring(dot) else ""
        var target = File(downloads, displayName)
        var n = 1
        while (target.exists()) target = File(downloads, "$base (${n++})$extension")
        return try {
            source.inputStream().use { input ->
                FileOutputStream(target).use { input.copyTo(it, BUFFER) }
            }
            target.name
        } catch (e: Exception) {
            Log.w(TAG, "Save to Downloads failed", e)
            target.delete()
            null
        }
    }

    private fun hasLegacyWritePermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED

    private suspend fun requestLegacyWritePermission(): Boolean =
        suspendCancellableCoroutine { continuation ->
            CurrentActivity.requestPermission(
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
                WRITE_REQUEST,
            ) { granted -> if (continuation.isActive) continuation.resume(granted) }
        }

    private companion object {
        const val TAG = "ResQMeshFiles"
        const val WRITE_REQUEST = 4202
        const val CAMERA_REQUEST = 4204
        const val BUFFER = 256 * 1024
    }
}
