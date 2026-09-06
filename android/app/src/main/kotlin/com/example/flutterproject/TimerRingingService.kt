package com.example.flutterproject

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log

/** One shared, bounded alarm sound even when several timers finish together. */
class TimerRingingService : Service() {
    companion object {
        private const val PLAYBACK_CHANNEL = "kitchen_timer_alarm_playback"
        private const val NOTIFICATION_ID = -1 // Task IDs are always positive.
        private const val RING_DURATION_MS = 15_000L
        private var instance: TimerRingingService? = null

        fun stopTimer(id: Int, deadline: Long) {
            val service = instance ?: return
            if (service.ringing[id]?.deadline != deadline) return
            service.ringing.remove(id)
            service.updateRinging()
        }

        fun silence() { instance?.finishRinging() }
    }

    private data class Ring(val deadline: Long, val until: Long)
    private val ringing = mutableMapOf<Int, Ring>()
    private val handler = Handler(Looper.getMainLooper())
    private val expire = Runnable { updateRinging() }
    private var player: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false
    private val audio by lazy { getSystemService(AudioManager::class.java) }
    @Suppress("DEPRECATION")
    private val vibrator by lazy { getSystemService(Vibrator::class.java) }
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) finishRinging()
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getIntExtra("timerId", -1) ?: -1
        val deadline = intent?.getLongExtra("deadline", 0) ?: 0
        val name = intent?.getStringExtra("name") ?: "任务"
        try {
            // Enter foreground before requesting focus (required on Android 15+).
            val notification = playbackNotification()
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            // A reset/dismiss can reach storage before this service starts.
            if (!TimerAlarms.isCurrentCompletion(this, id, deadline)) {
                updateRinging()
                return START_NOT_STICKY
            }
            ringing[id] = Ring(deadline, SystemClock.elapsedRealtime() + RING_DURATION_MS)
            if (player == null) startSound()
            TimerAlarms.showCompletion(this, id, name, silent = true)
            updateRinging()
        } catch (error: Exception) {
            Log.w("KitchenTimer", "Unable to play alarm", error)
            finishRinging()
            TimerAlarms.showCompletion(this, id, name)
        }
        return START_NOT_STICKY
    }

    private fun playbackNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                PLAYBACK_CHANNEL, "正在播放计时铃声", NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "显示停止铃声按钮；到时铃声使用系统闹钟音量"
                setSound(null, null)
                enableVibration(false)
            })
        }
        val stop = PendingIntent.getBroadcast(this, 0, Intent(this, TimerSilenceReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, PLAYBACK_CHANNEL)
            else Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        if (Build.VERSION.SDK_INT >= 31) builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        return builder.setSmallIcon(R.drawable.ic_timer_notification)
            .setContentTitle("时间到 · 正在响铃")
            .setContentText("铃声将在 15 秒内自动停止")
            .setContentIntent(TimerAlarms.launchIntent(this, NOTIFICATION_ID))
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true).setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, "停止铃声", stop).build())
            .build()
    }

    @Suppress("DEPRECATION")
    private fun startSound() {
        val result = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener).build()
            focusRequest = request
            audio.requestAudioFocus(request)
        } else {
            audio.requestAudioFocus(focusListener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
        check(result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Alarm audio focus denied" }
        hasAudioFocus = true
        // Bundle a sound so an unset/unreadable OEM default ringtone cannot
        // produce a silent timer. Alarm volume and Do Not Disturb still apply.
        val sound = MediaPlayer()
        player = sound
        sound.setAudioAttributes(attributes)
        sound.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
        resources.openRawResourceFd(R.raw.timer_alarm).use { asset ->
            sound.setDataSource(asset.fileDescriptor, asset.startOffset, asset.length)
        }
        sound.isLooping = true
        sound.setOnErrorListener { _, _, _ ->
            finishRinging()
            true
        }
        sound.prepare()
        sound.start()
        val vibrate = if (Build.VERSION.SDK_INT >= 26)
            getSystemService(NotificationManager::class.java)
                .getNotificationChannel(TimerAlarms.CHANNEL_ID)?.shouldVibrate() ?: true else true
        if (vibrate) {
            val pattern = longArrayOf(0, 350, 150, 350, 1150)
            if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0), attributes)
            else vibrator.vibrate(pattern, 0, attributes)
        }
    }

    private fun updateRinging() {
        handler.removeCallbacks(expire)
        val now = SystemClock.elapsedRealtime()
        ringing.entries.removeAll { it.value.until <= now }
        val next = ringing.values.minOfOrNull { it.until }
        if (next == null) finishRinging()
        else handler.postDelayed(expire, next - now)
    }

    private fun finishRinging() {
        ringing.clear()
        releaseSound()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    @Suppress("DEPRECATION")
    private fun releaseSound() {
        handler.removeCallbacks(expire)
        player?.release()
        player = null
        vibrator.cancel()
        if (hasAudioFocus) {
            if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { audio.abandonAudioFocusRequest(it) }
            else audio.abandonAudioFocus(focusListener)
        }
        focusRequest = null
        hasAudioFocus = false
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        releaseSound()
        super.onDestroy()
    }
}

class TimerSilenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { TimerRingingService.silence() }
}
