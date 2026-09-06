package com.example.flutterproject

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permissionResults = mutableListOf<MethodChannel.Result>()
    private var ringtoneResult: MethodChannel.Result? = null

    companion object {
        var isVisible = false
            private set
        private const val NOTIFICATION_REQUEST = 104
        private const val RINGTONE_REQUEST = 105
    }

    override fun onResume() {
        super.onResume()
        isVisible = true
    }

    override fun onPause() {
        isVisible = false
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TimerAlarms.createChannel(this)
        TimerAlarms.restore(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kitchen_timer/platform")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "readState" -> result.success(TimerAlarms.readState(this))
                        "saveState" -> {
                            TimerAlarms.saveState(this, call.arguments as String)
                            result.success(null)
                        }
                        "requestNotifications" -> requestNotifications(result)
                        "reminderWarning" -> result.success(TimerAlarms.reminderWarning(this))
                        "readRingtone" -> result.success(TimerRingtoneSettings.read(this))
                        "pickRingtone" -> pickRingtone(result)
                        "resetRingtone" -> result.success(TimerRingtoneSettings.reset(this))
                        "openReminderSettings" -> {
                            startActivity(TimerAlarms.settingsIntent(this))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("TIMER_PLATFORM", error.message, null)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun pickRingtone(result: MethodChannel.Result) {
        if (ringtoneResult != null) {
            result.error("RINGTONE_BUSY", "铃声选择器已打开。", null)
            return
        }
        ringtoneResult = result
        try {
            startActivityForResult(TimerRingtoneSettings.pickerIntent(this), RINGTONE_REQUEST)
        } catch (_: ActivityNotFoundException) {
            ringtoneResult = null
            result.error("RINGTONE_UNAVAILABLE", "此手机未提供系统铃声选择器，可继续使用内置铃声。", null)
        } catch (_: Exception) {
            ringtoneResult = null
            result.error("RINGTONE_UNAVAILABLE", "无法打开系统铃声选择器，请重试。", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != RINGTONE_REQUEST) return
        val result = ringtoneResult
        ringtoneResult = null
        try {
            // Persist even after Android recreated this activity while the picker was open.
            val selection = TimerRingtoneSettings.acceptResult(this, resultCode, data)
            result?.success(selection)
        } catch (_: Exception) {
            result?.error("RINGTONE_SAVE", "无法保存铃声，请重新选择。", null)
        }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(TimerAlarms.notificationsEnabled(this))
            return
        }
        // Do not repeatedly interrupt a task after the user has declined.
        val prefs = getSharedPreferences("kitchen_timer_permissions", MODE_PRIVATE)
        if (permissionResults.isEmpty() && prefs.getBoolean("requested", false)) {
            result.success(false)
            return
        }
        permissionResults.add(result)
        if (permissionResults.size == 1) {
            prefs.edit().putBoolean("requested", true).apply()
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_REQUEST)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_REQUEST) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            permissionResults.forEach { it.success(granted) }
            permissionResults.clear()
        }
    }

    override fun onDestroy() {
        ringtoneResult?.success(null)
        ringtoneResult = null
        permissionResults.forEach { it.success(false) }
        permissionResults.clear()
        super.onDestroy()
    }
}
