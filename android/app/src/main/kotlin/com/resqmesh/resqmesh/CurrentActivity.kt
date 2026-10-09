package com.resqmesh.resqmesh

import android.app.Activity
import android.content.pm.PackageManager

/**
 * The visible activity, if any. Bridges live with the engine and use it
 * only for what needs a screen: permission prompts.
 */
object CurrentActivity {
    var activity: Activity? = null

    private val waiting = mutableMapOf<Int, (Boolean) -> Unit>()

    /** Asks for [permission]; false straight away if no screen is open. */
    fun requestPermission(permission: String, code: Int, result: (Boolean) -> Unit) {
        val current = activity ?: return result(false)
        waiting[code] = result
        current.requestPermissions(arrayOf(permission), code)
    }

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(code: Int, grants: IntArray) {
        waiting.remove(code)?.invoke(
            grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED,
        )
    }
}
