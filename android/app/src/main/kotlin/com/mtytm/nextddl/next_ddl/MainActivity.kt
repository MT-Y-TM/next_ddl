package com.mtytm.nextddl.next_ddl

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val UPDATE_CHANNEL = "next_ddl/app_update"
        private const val ALARM_CHANNEL = "next_ddl/alarm"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    val allowed =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                    result.success(allowed)
                }

                "openManageUnknownAppSources" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        val alarmScheduler = NextDdlAlarmScheduler(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canScheduleExactAlarms" -> {
                    result.success(alarmScheduler.canScheduleExactAlarms())
                }

                "openExactAlarmSettings" -> {
                    alarmScheduler.openExactAlarmSettings()
                    result.success(null)
                }

                "syncAlarms" -> {
                    val settings = call.argument<Map<*, *>>("settings") ?: emptyMap<Any, Any>()
                    val tasks = call.argument<List<Map<*, *>>>("tasks") ?: emptyList()
                    alarmScheduler.syncAlarms(settings, tasks)
                    result.success(null)
                }

                "removeTaskAlarms" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    alarmScheduler.removeTask(taskId)
                    result.success(null)
                }

                "removeAllAlarms" -> {
                    alarmScheduler.removeAll()
                    result.success(null)
                }

                "stopCurrentAlarm" -> {
                    alarmScheduler.stopCurrentAlarm()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
