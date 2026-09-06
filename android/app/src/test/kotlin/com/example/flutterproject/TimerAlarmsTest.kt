package com.example.flutterproject

import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Looper
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import org.robolectric.shadows.ShadowAlarmManager
import org.robolectric.shadows.ShadowMediaPlayer
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35])
@LooperMode(LooperMode.Mode.PAUSED)
class TimerAlarmsTest {
    private lateinit var context: Application
    private lateinit var manager: NotificationManager

    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("kitchen_timer", Context.MODE_PRIVATE).edit().clear().commit()
        manager = context.getSystemService(NotificationManager::class.java)
        ShadowAlarmManager.setCanScheduleExactAlarms(true)
        ShadowMediaPlayer.setMediaInfoProvider { ShadowMediaPlayer.MediaInfo(2000, 0) }
        TimerAlarms.createChannel(context)
    }

    private fun timer(id: Int = 1, deadline: Long = System.currentTimeMillis() - 1000, status: String = "completed") =
        JSONObject().put("preset", JSONObject().put("id", id).put("name", "测试任务"))
            .put("deadline", deadline).put("status", status)

    private fun state(vararg timers: JSONObject) = JSONObject().put("timers", JSONArray(timers.toList())).toString()

    private fun serviceIntent(timer: JSONObject) = Intent(context, TimerRingingService::class.java)
        .putExtra("timerId", timer.getJSONObject("preset").getInt("id"))
        .putExtra("deadline", timer.getLong("deadline")).putExtra("name", "测试任务")

    @Test fun `completion starts alarm audio service only once per deadline`() {
        val completed = timer()
        TimerAlarms.saveState(context, state(completed))
        val started = shadowOf(context).nextStartedService
        assertEquals(TimerRingingService::class.java.name, started.component?.className)
        assertEquals(completed.getLong("deadline"), started.getLongExtra("deadline", 0))
        TimerAlarms.saveState(context, state(completed))
        TimerAlarms.restore(context)
        assertNull(shadowOf(context).nextStartedService)

        TimerAlarms.saveState(context, state(timer(deadline = System.currentTimeMillis() - 500)))
        assertNotNull(shadowOf(context).nextStartedService)
    }

    @Test fun `paused cancelled and rescheduled timers reject stale alarm broadcasts`() {
        val deadline = System.currentTimeMillis() - 1000
        val broadcast = Intent(context, TimerAlarmReceiver::class.java)
            .setAction("com.example.flutterproject.TIMER_FINISHED")
            .putExtra("timerId", 1).putExtra("deadline", deadline)
        for (raw in listOf(state(timer(deadline = deadline, status = "paused")), state(),
                state(timer(deadline = deadline + 60_000, status = "running")))) {
            TimerAlarms.saveState(context, raw)
            TimerAlarmReceiver().onReceive(context, broadcast)
            assertNull(shadowOf(context).nextStartedService)
            assertFalse(TimerAlarms.isCurrentCompletion(context, 1, deadline))
        }
    }

    @Test fun `a silent channel keeps its settings and offers the correct settings screen`() {
        val channel = manager.getNotificationChannel(TimerAlarms.CHANNEL_ID)
        // Robolectric exposes the stored channel, modeling a system-settings edit.
        channel.setSound(null, null)
        TimerAlarms.createChannel(context)
        assertNull(manager.getNotificationChannel(TimerAlarms.CHANNEL_ID).sound)
        assertTrue(TimerAlarms.reminderWarning(context)!!.contains("静音"))
        assertEquals(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS, TimerAlarms.settingsIntent(context).action)
        TimerAlarms.saveState(context, state(timer()))
        assertNull(shadowOf(context).nextStartedService)
        assertNotNull(shadowOf(manager).getNotification(1))
    }

    @Test fun `zero alarm volume is detected and opens sound settings`() {
        context.getSystemService(AudioManager::class.java).setStreamVolume(AudioManager.STREAM_ALARM, 0, 0)
        assertTrue(TimerAlarms.reminderWarning(context)!!.contains("音量为零"))
        assertEquals(Settings.ACTION_SOUND_SETTINGS, TimerAlarms.settingsIntent(context).action)
    }

    @Test fun `boot restores overdue notification without a prohibited playback service`() {
        val prefs = context.getSharedPreferences("kitchen_timer", Context.MODE_PRIVATE)
        prefs.edit().putString("state", state(timer(status = "running"))).commit()
        TimerRestoreReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertNull(shadowOf(context).nextStartedService)
        assertNotNull(shadowOf(manager).getNotification(1))
    }

    @Test fun `service ignores a completion dismissed before service startup`() {
        val completed = timer()
        TimerAlarms.saveState(context, state(completed))
        TimerAlarms.saveState(context, state())
        val service = Robolectric.buildService(TimerRingingService::class.java).create()
        try {
            service.get().onStartCommand(serviceIntent(completed), 0, 1)
            assertTrue(shadowOf(service.get()).isStoppedBySelf)
            assertNull(shadowOf(manager).getNotification(1))
        } finally { service.destroy() }
    }

    @Test fun `ringing stops automatically and keeps the completion notification`() {
        val completed = timer()
        TimerAlarms.saveState(context, state(completed))
        val service = Robolectric.buildService(TimerRingingService::class.java).create()
        try {
            service.get().onStartCommand(serviceIntent(completed), 0, 1)
            assertFalse(shadowOf(service.get()).isStoppedBySelf)
            assertNotNull(shadowOf(manager).getNotification(1))
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(15))
            assertTrue(shadowOf(service.get()).isStoppedBySelf)
            assertNotNull(shadowOf(manager).getNotification(1))
        } finally { service.destroy() }
    }

    @Test fun `dismissing one completed timer keeps another ringing and stop button ends both`() {
        val first = timer()
        val second = timer(id = 2)
        TimerAlarms.saveState(context, state(first, second))
        val service = Robolectric.buildService(TimerRingingService::class.java).create()
        try {
            service.get().onStartCommand(serviceIntent(first), 0, 1)
            service.get().onStartCommand(serviceIntent(second), 0, 2)
            TimerAlarms.saveState(context, state(second))
            assertFalse(shadowOf(service.get()).isStoppedBySelf)
            assertNull(shadowOf(manager).getNotification(1))
            assertNotNull(shadowOf(manager).getNotification(2))
            shadowOf(manager).getNotification(-1).actions.single().actionIntent.send()
            shadowOf(Looper.getMainLooper()).idle()
            assertTrue(shadowOf(service.get()).isStoppedBySelf)
            assertNotNull(shadowOf(manager).getNotification(2))
        } finally { service.destroy() }
    }

    @Test fun `resetting the last ringing timer stops audio immediately`() {
        val completed = timer()
        TimerAlarms.saveState(context, state(completed))
        val service = Robolectric.buildService(TimerRingingService::class.java).create()
        try {
            service.get().onStartCommand(serviceIntent(completed), 0, 1)
            assertFalse(shadowOf(service.get()).isStoppedBySelf)
            TimerAlarms.saveState(context, state(timer(deadline = 0, status = "paused")))
            assertTrue(shadowOf(service.get()).isStoppedBySelf)
            assertNull(shadowOf(manager).getNotification(1))
        } finally { service.destroy() }
    }
}
