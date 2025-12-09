package com.mayank.study_sensei

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var appLockController: AppLockController

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appLockController = AppLockController(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handleMethodCall)
    }

    override fun onDestroy() {
        if (this::appLockController.isInitialized) {
            appLockController.stopMonitoring()
        }
        super.onDestroy()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkUsageAccess" -> result.success(hasUsageStatsPermission())
            "requestUsageAccess" -> {
                openUsageAccessSettings()
                result.success(true)
            }
            "checkOverlayPermission" -> result.success(canDrawOverlays())
            "requestOverlayPermission" -> {
                openOverlaySettings()
                result.success(true)
            }
            "startMonitoring" -> {
                val args = call.arguments as? Map<*, *>
                val blocked = (args?.get("blockedApps") as? List<*>)
                    ?.mapNotNull { it as? String } ?: emptyList()
                val enabled = args?.get("appLockEnabled") as? Boolean ?: false
                val completed = args?.get("studyCompleted") as? Boolean ?: false
                appLockController.applyConfiguration(blocked, enabled, completed)
                result.success(true)
            }
            "stopMonitoring" -> {
                appLockController.stopMonitoring()
                result.success(true)
            }
            "updateStudyStatus" -> {
                val args = call.arguments as? Map<*, *>
                val completed = args?.get("completed") as? Boolean ?: false
                appLockController.updateStudyStatus(completed)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    companion object {
        private const val CHANNEL = "study_sensei/app_lock"
    }
}
