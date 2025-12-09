package com.mayank.study_sensei

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import androidx.core.content.ContextCompat

class AppLockController(private val context: Context) {
    private val usageStatsManager =
        context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())

    private var overlayView: View? = null
    private var blockedPackages: Set<String> = emptySet()
    private var monitoring = false
    private var appLockEnabled = false
    private var studyCompleted = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!monitoring) return
            checkForegroundApp()
            handler.postDelayed(this, 1200)
        }
    }

    fun applyConfiguration(blocked: List<String>, enabled: Boolean, completed: Boolean) {
        blockedPackages = blocked.map { it.lowercase() }.toSet()
        appLockEnabled = enabled
        studyCompleted = completed
        if (shouldMonitor()) {
            startLoop()
        } else {
            stopMonitoring()
        }
    }

    fun stopMonitoring() {
        monitoring = false
        handler.removeCallbacks(pollRunnable)
        hideOverlay()
    }

    fun updateStudyStatus(completed: Boolean) {
        studyCompleted = completed
        if (completed || !appLockEnabled) {
            hideOverlay()
        }
    }

    private fun shouldMonitor(): Boolean {
        if (!appLockEnabled) return false
        if (studyCompleted) return false
        if (blockedPackages.isEmpty()) return false
        if (!hasOverlayPermission()) return false
        return true
    }

    private fun startLoop() {
        if (monitoring) return
        monitoring = true
        handler.post(pollRunnable)
    }

    private fun checkForegroundApp() {
        val currentPackage = resolveForegroundPackage() ?: return
        if (blockedPackages.contains(currentPackage.lowercase())) {
            showOverlay()
        } else {
            hideOverlay()
        }
    }

    private fun resolveForegroundPackage(): String? {
        return try {
            val end = System.currentTimeMillis()
            val start = end - 4000
            val events = usageStatsManager.queryEvents(start, end)
            var latest: String? = null
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    latest = event.packageName
                }
            }
            latest
        } catch (_: SecurityException) {
            null
        }
    }

    private fun showOverlay() {
        if (overlayView != null) return
        val inflater = LayoutInflater.from(context)
        val view = inflater.inflate(R.layout.view_app_lock_overlay, null)
        view.isClickable = true
        view.isFocusable = true
        val button = view.findViewById<Button>(R.id.btn_back_to_study)
        button.setOnClickListener { reopenApp() }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.CENTER

        try {
            windowManager.addView(view, params)
            overlayView = view
        } catch (_: Exception) {
            overlayView = null
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: Exception) {
            // Ignore
        } finally {
            overlayView = null
        }
    }

    private fun reopenApp() {
        val launchIntent =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            ContextCompat.startActivity(context, launchIntent, null)
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
}
