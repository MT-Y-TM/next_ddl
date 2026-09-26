package com.mtytm.nextddl.next_ddl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import kotlin.random.Random

class NextDdlAlarmService : Service() {
    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private val stopRunnable = Runnable { stopRinging() }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            NextDdlAlarmConstants.ACTION_STOP -> stopRinging()
            NextDdlAlarmConstants.ACTION_TRIGGER -> startRinging(intent)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(stopRunnable)
        player?.release()
        player = null
        super.onDestroy()
    }

    private fun startRinging(intent: Intent) {
        val ringDuration = intent.getLongExtra("testDurationMillis", NextDdlAlarmConstants.MAX_RING_MILLIS)
            .coerceIn(1_000L, NextDdlAlarmConstants.MAX_RING_MILLIS)
        val taskTitle = intent.getStringExtra(NextDdlAlarmConstants.EXTRA_TASK_TITLE)
            ?: "Next DDL"
        val audioUris = intent.getStringArrayListExtra(
            NextDdlAlarmConstants.EXTRA_AUDIO_ITEMS,
        ).orEmpty()
        startForeground(
            NextDdlAlarmConstants.NOTIFICATION_ID,
            buildNotification(taskTitle),
        )
        if (audioUris.isEmpty()) {
            handler.postDelayed(stopRunnable, ringDuration)
            return
        }
        player?.release()
        player = null
        for (audioUri in audioUris.shuffled()) {
          val candidate = MediaPlayer()
          try {
            candidate.apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            setDataSource(applicationContext, Uri.parse(audioUri))
            isLooping = true
            setOnPreparedListener { prepared ->
                val duration = prepared.duration
                val maxStart = duration - 30_000
                if (maxStart > 0) {
                    prepared.seekTo(Random.nextInt(maxStart))
                }
                prepared.start()
            }
            setOnErrorListener { _, _, _ ->
                stopRinging()
                true
            }
            prepareAsync()
            }
            player = candidate
            break
          } catch (_: Exception) {
            candidate.release()
          }
        }
        if (player == null) {
            stopRinging()
            return
        }
        handler.removeCallbacks(stopRunnable)
        handler.postDelayed(stopRunnable, ringDuration)
    }

    private fun stopRinging() {
        handler.removeCallbacks(stopRunnable)
        try { player?.stop() } catch (_: IllegalStateException) { }
        player?.release()
        player = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(taskTitle: String): Notification {
        ensureChannel()
        val stopIntent = Intent(this, NextDdlAlarmService::class.java).apply {
            action = NextDdlAlarmConstants.ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, NextDdlAlarmConstants.CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Next DDL")
            .setContentText(taskTitle)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(applicationInfo.icon, stopLabel(), stopPendingIntent)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            NextDdlAlarmConstants.CHANNEL_ID,
            NextDdlAlarmConstants.CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        )
        manager.createNotificationChannel(channel)
    }

    private fun stopLabel(): String {
        val preference = getSharedPreferences("next_ddl_alarm", MODE_PRIVATE).getString("localeTag", "system")
        val language = if (preference == "system") java.util.Locale.getDefault().language else preference
        return when (language) {
            "zh" -> "停止响铃"
            "ja" -> "アラームを停止"
            else -> "Stop alarm"
        }
    }
}
