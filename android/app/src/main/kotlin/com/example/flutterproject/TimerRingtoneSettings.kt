package com.example.flutterproject

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build

/** Global preference, kept outside timer JSON so queued timer saves cannot overwrite it. */
object TimerRingtoneSettings {
    private const val URI_KEY = "ringtone_uri"
    private const val TITLE_KEY = "ringtone_title"
    private fun preferences(context: Context) =
        context.getSharedPreferences("kitchen_timer", Context.MODE_PRIVATE)

    fun selectedUri(context: Context): Uri? =
        preferences(context).getString(URI_KEY, null)?.let(Uri::parse)

    fun builtInUri(context: Context): Uri =
        Uri.parse("android.resource://${context.packageName}/${R.raw.timer_alarm}")

    fun read(context: Context): Map<String, String?> {
        val uri = selectedUri(context)
        val title = when {
            uri == null -> "内置铃声"
            RingtoneManager.isDefault(uri) -> "系统默认闹钟铃声"
            else -> preferences(context).getString(TITLE_KEY, null) ?: "已选系统铃声"
        }
        return mapOf("uri" to uri?.toString(), "title" to title)
    }

    fun pickerIntent(context: Context): Intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
        .putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
        .putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "计时结束铃声")
        .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
        .putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI,
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
        .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
        .putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, selectedUri(context) ?: builtInUri(context))

    fun acceptResult(context: Context, resultCode: Int, data: Intent?): Map<String, String?>? {
        // Cancel/back, malformed OEM results and an unexpected silent choice leave the preference intact.
        if (resultCode != Activity.RESULT_OK || data == null) return null
        val uri = if (Build.VERSION.SDK_INT >= 33) {
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            data.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        } ?: return null
        require(uri.scheme in setOf("content", "android.resource", "file")) { "请选择手机中的铃声。" }
        // System sounds normally need no storage permission. Some OEM pickers also
        // offer document-provider sounds; retain their read grant when supplied.
        if (data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0 &&
            data.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0) {
            try {
                context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: SecurityException) {
                // If the provider later revokes access, playback falls back to the bundled alarm.
            }
        }
        val title = if (RingtoneManager.isDefault(uri)) "系统默认闹钟铃声" else try {
            val ringtone = RingtoneManager.getRingtone(context, uri)
            try {
                ringtone?.getTitle(context)?.takeIf { it.isNotBlank() } ?: "已选系统铃声"
            } finally {
                // getRingtone may allocate a player even when only reading the title.
                ringtone?.stop()
            }
        } catch (_: Exception) { "已选系统铃声" }
        check(preferences(context).edit().putString(URI_KEY, uri.toString())
            .putString(TITLE_KEY, title).commit()) { "无法保存铃声，请重试。" }
        return read(context)
    }

    fun reset(context: Context): Map<String, String?> {
        check(preferences(context).edit().remove(URI_KEY).remove(TITLE_KEY).commit()) {
            "无法保存铃声，请重试。"
        }
        return read(context)
    }
}
