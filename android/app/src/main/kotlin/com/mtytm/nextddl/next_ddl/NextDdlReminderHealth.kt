package com.mtytm.nextddl.next_ddl

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object NextDdlReminderHealth {
    fun register(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "next_ddl/reminder_health").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "checkAudioUris" -> result.success(
                        (call.argument<List<String>>("uris") ?: emptyList()).map { raw ->
                            try {
                                val uri = Uri.parse(raw)
                                val readable = if (uri.scheme == null) {
                                    java.io.File(raw).inputStream().use { it.read() >= 0 }
                                } else {
                                    activity.contentResolver.openInputStream(uri)?.use { it.read() >= 0 } ?: false
                                }
                                if (readable) "readable" else "unavailable"
                            } catch (_: Exception) { "unavailable" }
                        },
                    )
                    "testAlarm" -> {
                        val uris = call.argument<List<String>>("audioUris") ?: emptyList()
                        if (uris.isEmpty()) {
                            result.success(false)
                        } else {
                            val intent = Intent(activity, NextDdlAlarmService::class.java).apply {
                                action = NextDdlAlarmConstants.ACTION_TRIGGER
                                putExtra(NextDdlAlarmConstants.EXTRA_TASK_TITLE, call.argument<String>("title") ?: "Next DDL")
                                putStringArrayListExtra(NextDdlAlarmConstants.EXTRA_AUDIO_ITEMS, ArrayList(uris))
                                putExtra("testDurationMillis", 10_000L)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) activity.startForegroundService(intent)
                            else activity.startService(intent)
                            result.success(true)
                        }
                    }
                    "pendingAlarmCount" -> result.success(null) // AlarmManager cannot enumerate registered alarms.
                    "openNotificationSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                        } else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
                        activity.startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("reminder_health_failed", error.javaClass.simpleName, null)
            }
        }
    }
}
