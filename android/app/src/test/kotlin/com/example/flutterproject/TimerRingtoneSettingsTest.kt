package com.example.flutterproject

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowMediaPlayer

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 28, 35])
class TimerRingtoneSettingsTest {
    private lateinit var context: Application
    private val selected = Uri.parse("content://media/internal/audio/media/12")

    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("kitchen_timer", Context.MODE_PRIVATE).edit().clear().commit()
        ShadowMediaPlayer.setMediaInfoProvider { ShadowMediaPlayer.MediaInfo(2000, 0) }
    }

    private fun picked(uri: Uri? = selected) =
        Intent().putExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, uri)

    @Test fun `old installations keep bundled sound and timer JSON unchanged`() {
        val prefs = context.getSharedPreferences("kitchen_timer", Context.MODE_PRIVATE)
        for (version in listOf(1, 2)) {
            val raw = """{"version":$version,"timers":[],"presets":[]}"""
            prefs.edit().putString("state", raw).commit()
            assertNull(TimerRingtoneSettings.selectedUri(context))
            assertEquals("内置铃声", TimerRingtoneSettings.read(context)["title"])
            assertEquals(raw, TimerAlarms.readState(context))
        }
    }

    @Suppress("DEPRECATION")
    @Test fun `picker shows alarm sounds and default without silent and preselects stored URI`() {
        val intent = TimerRingtoneSettings.pickerIntent(context)
        assertEquals(RingtoneManager.ACTION_RINGTONE_PICKER, intent.action)
        assertEquals(RingtoneManager.TYPE_ALARM, intent.getIntExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, -1))
        assertTrue(intent.getBooleanExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false))
        assertFalse(intent.getBooleanExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true))
        assertEquals(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
            intent.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI))
        TimerRingtoneSettings.acceptResult(context, Activity.RESULT_OK, picked())
        assertEquals(selected, TimerRingtoneSettings.pickerIntent(context)
            .getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI))
    }

    @Test fun `selection survives fresh context and timer saves while reset preserves other preferences`() {
        TimerRingtoneSettings.acceptResult(context, Activity.RESULT_OK, picked())
        val raw = """{"version":2,"timers":[]}"""
        TimerAlarms.saveState(context, raw)
        val fresh = context.createPackageContext(context.packageName, 0)
        assertEquals(selected, TimerRingtoneSettings.selectedUri(fresh))
        val prefs = fresh.getSharedPreferences("kitchen_timer", Context.MODE_PRIVATE)
        prefs.edit().putLong("delivered_1", 123).commit()
        TimerRingtoneSettings.reset(fresh)
        assertNull(TimerRingtoneSettings.selectedUri(context))
        assertEquals(raw, TimerAlarms.readState(context))
        assertEquals(123L, prefs.getLong("delivered_1", 0))
    }

    @Test fun `cancel and incomplete results do not change selection`() {
        TimerRingtoneSettings.acceptResult(context, Activity.RESULT_OK, picked())
        assertNull(TimerRingtoneSettings.acceptResult(context, Activity.RESULT_CANCELED, picked(Uri.EMPTY)))
        assertNull(TimerRingtoneSettings.acceptResult(context, Activity.RESULT_OK, null))
        assertNull(TimerRingtoneSettings.acceptResult(context, Activity.RESULT_OK, Intent()))
        assertNull(TimerRingtoneSettings.acceptResult(context, Activity.RESULT_OK, picked(null)))
        assertEquals(selected, TimerRingtoneSettings.selectedUri(context))
    }

    @Test fun `system default stays symbolic so later default changes are followed`() {
        val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val value = TimerRingtoneSettings.acceptResult(context, Activity.RESULT_OK, picked(defaultUri))!!
        assertEquals(defaultUri.toString(), value["uri"])
        assertEquals("系统默认闹钟铃声", value["title"])
    }
}
