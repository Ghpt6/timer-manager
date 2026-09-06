package com.example.flutterproject

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permissionResults = mutableListOf<MethodChannel.Result>()

    companion object {
        var isVisible = false
            private set
        private const val NOTIFICATION_REQUEST = 104
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
                        "openReminderSettings" -> {
                            val intent = if (!TimerAlarms.canScheduleExact(this)) {
                                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))
                            } else if (Build.VERSION.SDK_INT >= 26) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            }
                            startActivity(intent)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("TIMER_PLATFORM", error.message, null)
                }
            }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(TimerAlarms.notificationsEnabled(this))
            return
        }
        // Do not repeatedly interrupt cooking after the user has declined.
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
        permissionResults.forEach { it.success(false) }
        permissionResults.clear()
        super.onDestroy()
    }
}
