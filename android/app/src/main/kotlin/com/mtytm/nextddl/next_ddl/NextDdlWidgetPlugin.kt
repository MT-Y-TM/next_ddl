package com.mtytm.nextddl.next_ddl

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Register once with flutterEngine.plugins.add(NextDdlWidgetPlugin()). */
class NextDdlWidgetPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.NewIntentListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var binding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "next_ddl/home_widget")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val prefs = context.getSharedPreferences(NextDdlWidgetProvider.PREFS, Context.MODE_PRIVATE)
            when (call.method) {
                "writeSnapshot" -> {
                    val raw = requireNotNull(call.argument<String>("snapshot"))
                    NextDdlWidgetSnapshot.parse(raw)
                    // Commit before acknowledging: receivers in a new process need durable data.
                    check(prefs.edit().putString("snapshot", raw).commit()) { "Snapshot persistence failed" }
                    NextDdlWidgetProvider.refreshAll(context)
                    result.success(null)
                }
                "consumePendingTaskId" -> {
                    val id = prefs.getString("pendingTaskId", null)
                    check(prefs.edit().remove("pendingTaskId").commit())
                    result.success(id)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("widget_error", error.message, null)
        }
    }

    private fun capture(intent: Intent?): Boolean {
        if (intent?.action != NextDdlWidgetProvider.OPEN_TASK) return false
        val id = intent.getStringExtra("widgetTaskId") ?: return false
        val saved = context.getSharedPreferences(NextDdlWidgetProvider.PREFS, Context.MODE_PRIVATE)
            .edit().putString("pendingTaskId", id).commit()
        if (saved) {
            intent.removeExtra("widgetTaskId")
            channel.invokeMethod("taskTapAvailable", null)
        }
        return saved
    }

    override fun onNewIntent(intent: Intent): Boolean = capture(intent)
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addOnNewIntentListener(this)
        capture(binding.activity.intent)
    }
    override fun onDetachedFromActivity() {
        binding?.removeOnNewIntentListener(this)
        binding = null
    }
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
