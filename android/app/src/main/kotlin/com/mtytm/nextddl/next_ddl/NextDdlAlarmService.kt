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
            handler.postDelayed(stopRunnable, NextDdlAlarmConstants.MAX_RING_MILLIS)
            return
        }
        val uri = Uri.parse(audioUris.random())
        player?.release()
        player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            setDataSource(applicationContext, uri)
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
        handler.removeCallbacks(stopRunnable)
        handler.postDelayed(stopRunnable, NextDdlAlarmConstants.MAX_RING_MILLIS)
    }

    private fun stopRinging() {
        handler.removeCallbacks(stopRunnable)
        player?.stop()
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
            .addAction(applicationInfo.icon, "Stop", stopPendingIntent)
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
}
