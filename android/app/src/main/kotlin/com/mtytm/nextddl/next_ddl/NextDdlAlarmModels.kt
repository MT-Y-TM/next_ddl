package com.mtytm.nextddl.next_ddl

data class AlarmAudioItem(
    val id: String,
    val displayName: String,
    val uri: String,
)

data class AlarmTrigger(
    val id: String,
    val taskId: String,
    val taskTitle: String,
    val triggerAtMillis: Long,
    val audioItems: List<AlarmAudioItem>,
)

object NextDdlAlarmConstants {
    const val CHANNEL_ID = "next_ddl_alarm"
    const val CHANNEL_NAME = "Next DDL Alarm"
    const val ACTION_TRIGGER = "com.mtytm.nextddl.TRIGGER_ALARM"
    const val ACTION_STOP = "com.mtytm.nextddl.STOP_ALARM"
    const val EXTRA_TRIGGER_ID = "triggerId"
    const val EXTRA_TASK_TITLE = "taskTitle"
    const val EXTRA_AUDIO_ITEMS = "audioItems"
    const val NOTIFICATION_ID = 20001
    const val MAX_RING_MILLIS = 5 * 60 * 1000L
}
