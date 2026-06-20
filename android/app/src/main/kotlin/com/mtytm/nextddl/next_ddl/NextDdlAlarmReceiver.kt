package com.mtytm.nextddl.next_ddl

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class NextDdlAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != NextDdlAlarmConstants.ACTION_TRIGGER) return
        val serviceIntent = Intent(context, NextDdlAlarmService::class.java).apply {
            action = NextDdlAlarmConstants.ACTION_TRIGGER
            putExtras(intent)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
