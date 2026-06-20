package com.mtytm.nextddl.next_ddl

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import kotlin.math.abs

class NextDdlAlarmScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(AlarmManager::class.java)

    fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.startActivity(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                },
            )
        }
    }

    fun syncAlarms(settings: Map<*, *>, taskMaps: List<Map<*, *>>) {
        removeAll()
        if (settings["enabled"] as? Boolean != true || !canScheduleExactAlarms()) {
            return
        }
        val globalAudioItems = parseAudioItems(settings["globalAudioItems"] as? List<*>)
        val now = System.currentTimeMillis()
        for (taskMap in taskMaps) {
            if (taskMap["alarmEnabled"] as? Boolean != true) continue
            val reminderOffsets = (taskMap["reminderOffsetsSeconds"] as? List<*>)
                .orEmpty()
                .mapNotNull { (it as? Number)?.toLong() }
            val overrideItems = parseAudioItems(taskMap["alarmAudioItemsOverride"] as? List<*>)
            val audioItems = if (overrideItems.isNotEmpty()) overrideItems else globalAudioItems
            if (audioItems.isEmpty()) continue
            val taskId = taskMap["id"] as? String ?: continue
            val taskTitle = taskMap["title"] as? String ?: "Next DDL"
            val targets = buildList {
                add(taskMap["finalDueAtUtc"] as? String)
                val milestones = taskMap["milestones"] as? List<*>
                milestones.orEmpty().forEach { milestone ->
                    add((milestone as? Map<*, *>)?.get("dueAtUtc") as? String)
                }
            }.mapNotNull { parseIsoMillis(it) }
            for (targetMillis in targets) {
                for (offsetSeconds in reminderOffsets) {
                    val triggerAtMillis = targetMillis - offsetSeconds * 1000L
                    if (triggerAtMillis <= now) continue
                    val trigger = AlarmTrigger(
                        id = "$taskId:$targetMillis:$offsetSeconds",
                        taskId = taskId,
                        taskTitle = taskTitle,
                        triggerAtMillis = triggerAtMillis,
                        audioItems = audioItems,
                    )
                    schedule(trigger)
                }
            }
        }
    }

    fun removeTask(taskId: String) {
        // Exact request codes are derived from trigger ids. Full rebuild is used by Flutter
        // after task edits, so this method is intentionally conservative.
    }

    fun removeAll() {
        val prefs = context.getSharedPreferences("next_ddl_alarm", Context.MODE_PRIVATE)
        val ids = prefs.getStringSet("triggerIds", emptySet()).orEmpty()
        ids.forEach { id ->
            alarmManager.cancel(pendingIntent(id, "", emptyList()))
        }
        prefs.edit().putStringSet("triggerIds", emptySet()).apply()
    }

    fun stopCurrentAlarm() {
        context.startService(
            Intent(context, NextDdlAlarmService::class.java).apply {
                action = NextDdlAlarmConstants.ACTION_STOP
            },
        )
    }

    private fun schedule(trigger: AlarmTrigger) {
        val operation = pendingIntent(
            trigger.id,
            trigger.taskTitle,
            trigger.audioItems.map { it.uri },
        )
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            trigger.triggerAtMillis,
            operation,
        )
        val prefs = context.getSharedPreferences("next_ddl_alarm", Context.MODE_PRIVATE)
        val ids = prefs.getStringSet("triggerIds", emptySet()).orEmpty().toMutableSet()
        ids.add(trigger.id)
        prefs.edit().putStringSet("triggerIds", ids).apply()
    }

    private fun pendingIntent(
        triggerId: String,
        taskTitle: String,
        audioUris: List<String>,
    ): PendingIntent {
        val intent = Intent(context, NextDdlAlarmReceiver::class.java).apply {
            action = NextDdlAlarmConstants.ACTION_TRIGGER
            putExtra(NextDdlAlarmConstants.EXTRA_TRIGGER_ID, triggerId)
            putExtra(NextDdlAlarmConstants.EXTRA_TASK_TITLE, taskTitle)
            putStringArrayListExtra(
                NextDdlAlarmConstants.EXTRA_AUDIO_ITEMS,
                ArrayList(audioUris),
            )
        }
        return PendingIntent.getBroadcast(
            context,
            abs(triggerId.hashCode()),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun parseAudioItems(raw: List<*>?): List<AlarmAudioItem> {
        return raw.orEmpty().mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val uri = map["uri"] as? String ?: return@mapNotNull null
            if (uri.isBlank()) return@mapNotNull null
            AlarmAudioItem(
                id = map["id"] as? String ?: uri,
                displayName = map["displayName"] as? String ?: uri,
                uri = uri,
            )
        }
    }

    private fun parseIsoMillis(value: String?): Long? {
        return try {
            value?.let { java.time.Instant.parse(it).toEpochMilli() }
        } catch (_: Exception) {
            null
        }
    }
}
