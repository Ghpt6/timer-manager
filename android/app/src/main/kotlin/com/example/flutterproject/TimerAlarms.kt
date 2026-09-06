package com.example.flutterproject

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.json.JSONObject

object TimerAlarms {
    const val CHANNEL_ID = "kitchen_timer_finished"
    private const val PREFS = "kitchen_timer"
    private const val ACTION_ALARM = "com.example.flutterproject.TIMER_FINISHED"

    private fun preferences(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)
    private fun notifications(context: Context) = context.getSystemService(NotificationManager::class.java)

    fun readState(context: Context): String? = preferences(context).getString("state", null)

    private fun timers(raw: String?): Map<Int, JSONObject> {
        if (raw == null) return emptyMap()
        val array = JSONObject(raw).getJSONArray("timers")
        return (0 until array.length()).associate { index ->
            val timer = array.getJSONObject(index)
            timer.getJSONObject("preset").getInt("id") to timer
        }
    }

    private fun savedTimers(context: Context): Map<Int, JSONObject> = try {
        timers(readState(context))
    } catch (error: Exception) {
        Log.w("KitchenTimer", "Unable to restore timer records", error)
        emptyMap()
    }

    fun saveState(context: Context, raw: String) {
        // Validate before changing disk or alarms. The Dart controller serializes
        // calls and Android dispatches calls and receivers on the main thread.
        val current = timers(raw)
        val previous = try { timers(readState(context)) } catch (_: Exception) { emptyMap() }
        check(preferences(context).edit().putString("state", raw).commit()) { "Unable to save timers" }
        for ((id, old) in previous) {
            val next = current[id]
            if (next == null || next.optString("status") != "running" ||
                next.optLong("deadline") != old.optLong("deadline")) {
                cancelAlarm(context, id)
            }
            if (next == null || next.optString("status") == "paused" ||
                next.optLong("deadline") != old.optLong("deadline")) {
                notifications(context).cancel(id)
                TimerRingingService.stopTimer(id, old.optLong("deadline"))
            }
        }
        for ((id, timer) in current) {
            val status = timer.getString("status")
            val deadline = timer.optLong("deadline", 0)
            if (status == "running") {
                if (deadline <= System.currentTimeMillis()) {
                    deliver(context, id, timer)
                } else if (previous[id]?.optString("status") != "running" ||
                    previous[id]?.optLong("deadline") != deadline) {
                    schedule(context, id, deadline)
                }
            } else if (status == "completed" && deadline > 0) {
                // Covers Flutter's foreground tick beating the OS receiver.
                deliver(context, id, timer)
            }
        }
    }

    fun canScheduleExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < 31 || alarms(context).canScheduleExactAlarms()

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val channel = NotificationChannel(CHANNEL_ID, "计时完成提醒", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "任务计时结束时播放声音并振动"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 350, 150, 350)
            setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        notifications(context).createNotificationChannel(channel)
    }

    fun notificationsEnabled(context: Context): Boolean =
        notifications(context).areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 26 ||
                (notifications(context).getNotificationChannel(CHANNEL_ID)?.importance ?: NotificationManager.IMPORTANCE_HIGH) >
                    NotificationManager.IMPORTANCE_NONE)

    fun reminderWarning(context: Context): String? = when {
        !notificationsEnabled(context) -> "通知未开启，无法显示完成提醒。"
        !canScheduleExact(context) -> "精确提醒未开启，到时通知可能延迟。"
        !channelSoundEnabled(context) -> "计时完成提醒已设为静音，请在设置中开启声音。"
        alarmVolumeMuted(context) -> "闹钟音量为零，到时将没有声音，请调高闹钟音量。"
        else -> null
    }

    fun channelSoundEnabled(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 26) return true
        val channel = notifications(context).getNotificationChannel(CHANNEL_ID) ?: return true
        return channel.importance >= NotificationManager.IMPORTANCE_DEFAULT && channel.sound != null
    }

    private fun alarmVolumeMuted(context: Context): Boolean =
        context.getSystemService(AudioManager::class.java).getStreamVolume(AudioManager.STREAM_ALARM) == 0

    fun settingsIntent(context: Context): Intent = when {
        !notifications(context).areNotificationsEnabled() && Build.VERSION.SDK_INT >= 26 ->
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        !notifications(context).areNotificationsEnabled() ->
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
        !notificationsEnabled(context) && Build.VERSION.SDK_INT >= 26 -> channelSettings(context)
        !canScheduleExact(context) ->
            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}"))
        !channelSoundEnabled(context) && Build.VERSION.SDK_INT >= 26 -> channelSettings(context)
        else -> Intent(Settings.ACTION_SOUND_SETTINGS)
    }

    @android.annotation.TargetApi(26)
    private fun channelSettings(context: Context): Intent =
        Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .putExtra(Settings.EXTRA_CHANNEL_ID, CHANNEL_ID)

    fun launchIntent(context: Context, id: Int): PendingIntent = PendingIntent.getActivity(
        context, id,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun alarmIntent(context: Context, id: Int, deadline: Long = 0, flags: Int = PendingIntent.FLAG_UPDATE_CURRENT): PendingIntent? =
        PendingIntent.getBroadcast(context, id,
            Intent(context, TimerAlarmReceiver::class.java).setAction(ACTION_ALARM)
                .putExtra("timerId", id).putExtra("deadline", deadline),
            flags or PendingIntent.FLAG_IMMUTABLE)

    private fun schedule(context: Context, id: Int, deadline: Long) {
        val operation = alarmIntent(context, id, deadline)!!
        if (canScheduleExact(context)) {
            // Alarm-clock delivery avoids the per-app idle quota that can delay
            // two timers finishing within a few minutes of one another.
            alarms(context).setAlarmClock(AlarmManager.AlarmClockInfo(deadline, launchIntent(context, id)), operation)
        } else {
            alarms(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, deadline, operation)
        }
    }

    private fun cancelAlarm(context: Context, id: Int) {
        alarmIntent(context, id, flags = PendingIntent.FLAG_NO_CREATE)?.let {
            alarms(context).cancel(it)
            it.cancel()
        }
    }

    fun receive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ALARM) return
        val id = intent.getIntExtra("timerId", -1)
        val timer = savedTimers(context)[id] ?: return
        // Ignore a broadcast already queued when the user paused/reset a timer.
        if (timer.optString("status") != "running" ||
            timer.optLong("deadline") != intent.getLongExtra("deadline", 0)) return
        deliver(context, id, timer)
    }

    fun isCurrentCompletion(context: Context, id: Int, deadline: Long): Boolean {
        val timer = savedTimers(context)[id] ?: return false
        return deadline > 0 && deadline <= System.currentTimeMillis() &&
            timer.optLong("deadline") == deadline &&
            timer.optString("status") in setOf("running", "completed")
    }

    private fun deliver(context: Context, id: Int, timer: JSONObject, allowPlayback: Boolean = true) {
        val deadline = timer.optLong("deadline", 0)
        if (deadline <= 0 || deadline > System.currentTimeMillis()) return
        val prefs = preferences(context)
        if (prefs.getLong("delivered_$id", 0) == deadline) return
        // Persist a run token before delivery, preventing foreground/background
        // races or reboot restoration from ringing the same timer twice.
        if (!prefs.edit().putLong("delivered_$id", deadline).commit()) return
        createChannel(context)
        val name = timer.getJSONObject("preset").getString("name")
        // Notification sounds alone can be suppressed or shortened by the OS.
        // A bounded foreground service owns alarm audio, including on the lock
        // screen. Preserve a user's explicit channel mute instead of bypassing it.
        if (allowPlayback && channelSoundEnabled(context) &&
            (notificationsEnabled(context) || MainActivity.isVisible)) {
            try {
                val intent = Intent(context, TimerRingingService::class.java)
                    .putExtra("timerId", id).putExtra("deadline", deadline).putExtra("name", name)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
                else context.startService(intent)
                return
            } catch (error: RuntimeException) {
                // Inexact alarms or OEM background policies can deny a service.
                Log.w("KitchenTimer", "Alarm playback unavailable; using notification", error)
            }
        }
        showCompletion(context, id, name)
    }

    fun showCompletion(context: Context, id: Int, name: String, silent: Boolean = false) {
        if (!notificationsEnabled(context)) return
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID)
            else Notification.Builder(context)
                .setPriority(Notification.PRIORITY_HIGH)
                .setDefaults(Notification.DEFAULT_VIBRATE)
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
        if (silent) {
            // Silence this notification only; never recreate or mutate the
            // existing channel. The service supplies the sound and vibration.
            if (Build.VERSION.SDK_INT >= 26) {
                builder.setGroup("timer_completions").setGroupAlertBehavior(Notification.GROUP_ALERT_SUMMARY)
            } else {
                @Suppress("DEPRECATION")
                builder.setDefaults(0).setSound(null)
            }
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_timer_notification)
            .setContentTitle("$name · 时间到")
            .setContentText("任务计时已完成。轻点返回计时管理。")
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(launchIntent(context, id))
            .setAutoCancel(true)
            .setColor(0xFFE87C46.toInt())
            .build()
        notifications(context).notify(id, notification)
    }

    fun restore(context: Context, allowPlayback: Boolean = true) {
        createChannel(context)
        for ((id, timer) in savedTimers(context)) {
            if (timer.optString("status") != "running") continue
            val deadline = timer.getLong("deadline")
            if (deadline > System.currentTimeMillis()) schedule(context, id, deadline)
            else deliver(context, id, timer, allowPlayback)
        }
    }
}

class TimerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        TimerAlarms.receive(context, intent)
    }
}

class TimerRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED)) {
            // Android 15+ disallows starting media playback from BOOT_COMPLETED.
            // Post overdue notifications; future deadlines still use exact alarms.
            TimerAlarms.restore(context, allowPlayback = intent.action != Intent.ACTION_BOOT_COMPLETED)
        }
    }
}
