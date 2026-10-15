package com.resqmesh.resqmesh

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager

/**
 * The visible activity, if any. Bridges live with the engine and use it
 * only for what needs a screen: permission prompts and other apps'
 * screens, such as the camera.
 */
object CurrentActivity {
    var activity: Activity? = null

    private val waiting = mutableMapOf<Int, (Boolean) -> Unit>()
    private val results = mutableMapOf<Int, (Boolean) -> Unit>()

    /** Opens [intent]; [result] gets true for RESULT_OK. */
    fun startForResult(intent: Intent, code: Int, result: (Boolean) -> Unit) {
        val current = activity ?: return result(false)
        results[code] = result
        try {
            current.startActivityForResult(intent, code)
        } catch (e: ActivityNotFoundException) {
            results.remove(code)
            result(false)
        }
    }

    /** Called from MainActivity.onActivityResult. */
    fun onActivityResult(code: Int, resultCode: Int): Boolean {
        val result = results.remove(code) ?: return false
        result(resultCode == Activity.RESULT_OK)
        return true
    }

    /** Asks for [permission]; false straight away if no screen is open. */
    fun requestPermission(permission: String, code: Int, result: (Boolean) -> Unit) =
        requestPermissions(arrayOf(permission), code, result)

    /** Asks for all of [permissions]; true only if every one is granted. */
    fun requestPermissions(permissions: Array<String>, code: Int, result: (Boolean) -> Unit) {
        val current = activity ?: return result(false)
        waiting[code] = result
        current.requestPermissions(permissions, code)
    }

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(code: Int, grants: IntArray) {
        waiting.remove(code)?.invoke(
            grants.isNotEmpty() && grants.all { it == PackageManager.PERMISSION_GRANTED },
        )
    }
}
