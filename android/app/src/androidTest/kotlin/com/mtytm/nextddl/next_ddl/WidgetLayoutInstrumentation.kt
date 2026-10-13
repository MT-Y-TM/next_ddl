package com.mtytm.nextddl.next_ddl

import android.app.Activity
import android.app.Instrumentation
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import java.io.File
import java.util.Locale
import kotlin.math.ceil

/** Exercises the actual RemoteViews inflater, measurements and text on Android. */
class WidgetLayoutInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }

    override fun onStart() {
        val result = Bundle()
        try {
            uiAutomation.adoptShellPermissionIdentity("android.permission.BIND_APPWIDGET")
            var assertions = 0
            fun check(value: Boolean, message: String) { kotlin.check(value) { message }; assertions++ }
            var mainFailure: Throwable? = null
            runOnMainSync {
                try {
                val manager = AppWidgetManager.getInstance(targetContext)
                val component = ComponentName(targetContext, NextDdlWidgetProvider::class.java)
                val provider = manager.installedProviders.single { it.provider == component }
                check(provider.targetCellWidth == 3 && provider.targetCellHeight == 2, "Wrong default launcher cell size")
                val density = targetContext.resources.displayMetrics.density
                check(provider.minResizeWidth <= ceil(180 * density).toInt() &&
                    provider.minResizeHeight <= ceil(110 * density).toInt(),
                    "Minimum resize size is too large: ${provider.minResizeWidth}x${provider.minResizeHeight}, density=$density")
                val host = AppWidgetHost(targetContext, 127001)
                val widgetId = host.allocateAppWidgetId()
                val prefs = targetContext.getSharedPreferences(NextDdlWidgetProvider.PREFS, Context.MODE_PRIVATE)
                val previousSnapshot = prefs.getString("snapshot", null)
                try {
                    check(manager.bindAppWidgetIdIfAllowed(widgetId, component), "Cannot bind test widget host")
                    val currentTime = System.currentTimeMillis()
                    prefs.edit().putString("snapshot", """{"schemaVersion":1,"locale":"zh","timezoneId":"UTC","tasks":[
                        {"id":"selected","title":"Selected","finalDueAtUtc":${currentTime + 86400000},"updatedAtUtc":1,"milestones":[]},
                        {"id":"starred","title":"Starred","finalDueAtUtc":${currentTime + 172800000},"updatedAtUtc":1,"widgetPinned":true,"milestones":[]}
                    ]}""").putString("selectedTask_$widgetId", "selected")
                        .putBoolean("manualSelection_$widgetId", true).commit()
                    for (size in listOf(SizeF(180f, 110f), SizeF(600f, 180f))) {
                        val options = Bundle().apply {
                            putParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES, arrayListOf(size))
                            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, size.width.toInt())
                            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, size.width.toInt())
                            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, size.height.toInt())
                            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, size.height.toInt())
                        }
                        manager.updateAppWidgetOptions(widgetId, options)
                        NextDdlWidgetProvider().onAppWidgetOptionsChanged(targetContext, manager, widgetId, options)
                        check(manager.getAppWidgetOptions(widgetId).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) == size.width.toInt(),
                            "Host did not accept widget size")
                        check(prefs.getString("selectedTask_$widgetId", null) == "selected" &&
                            prefs.getBoolean("manualSelection_$widgetId", false), "Resize reset manual task selection")
                    }
                } finally {
                    host.deleteHost()
                    prefs.edit().putString("snapshot", previousSnapshot)
                        .remove("selectedTask_$widgetId").remove("manualSelection_$widgetId").commit()
                }
                val now = 1700000000000L
                val task = WidgetTask("test", "Task / 截止任务 / タスク", now + 67 * 86400000L + 12 * 3600000L,
                    now, emptyList(), now - 86400000L)
                val sizes = listOf(WidgetSize(180f, 110f), WidgetSize(203f, 220f), WidgetSize(280f, 220f),
                    WidgetSize(320f, 360f), WidgetSize(412f, 117f), WidgetSize(600f, 180f), WidgetSize(800f, 600f))
                for (language in listOf("zh", "en", "ja")) {
                    for (scale in listOf(1f, 1.3f, 1.8f)) {
                        val config = Configuration(targetContext.resources.configuration).apply {
                            setLocale(Locale.forLanguageTag(language)); fontScale = scale
                        }
                        val context = targetContext.createConfigurationContext(config)
                        val snapshot = NextDdlWidgetSnapshot(locale = language, tasks = listOf(task, task.copy(id = "second")))
                        for (size in sizes) {
                            for (current in listOf(task, task.copy(finalDue = now - 600 * 86400000L), null)) {
                                val views = NextDdlWidgetRenderer.createView(context, snapshot, current, now, size)
                                val root = views.apply(context, FrameLayout(context))
                                val density = context.resources.displayMetrics.density
                                val width = (size.width * density).toInt()
                                val height = (size.height * density).toInt()
                                root.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                                    View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
                                root.layout(0, 0, width, height)
                                val description = "$language font=$scale size=$size overdue=${current?.finalDue?.let { it < now }}"
                                fun visible(view: View): Boolean {
                                    var cursor: View? = view
                                    while (cursor != null) {
                                        if (cursor.visibility != View.VISIBLE) return false
                                        cursor = cursor.parent as? View
                                    }
                                    return true
                                }
                                for (id in listOf(R.id.widget_title, R.id.widget_menu_icon, R.id.widget_final_label,
                                    R.id.widget_final_countdown, R.id.widget_final, R.id.widget_progress, R.id.widget_status,
                                    R.id.widget_percent, R.id.widget_empty_hint)) {
                                    val view = root.findViewById<View>(id)
                                    if (!visible(view)) continue
                                    val rect = Rect(0, 0, view.width, view.height)
                                    (root as android.view.ViewGroup).offsetDescendantRectToMyCoords(view, rect)
                                    check(rect.left >= 0 && rect.top >= 0 && rect.right <= width && rect.bottom <= height,
                                        "Clipped view id=$id rect=$rect bounds=$width,$height: $description")
                                }
                                if (current != null) {
                                    val countdown = root.findViewById<TextView>(R.id.widget_final_countdown)
                                    check(countdown.layout.getEllipsisCount(0) == 0, "Truncated countdown: $description")
                                    check(countdown.text.contains(if (language == "en") " d " else if (language == "ja") "日" else "天"),
                                        "Wrong units: $description")
                                }
                                val switch = root.findViewById<View>(R.id.widget_menu_icon)
                                check(switch.width >= (48 * density).toInt() && switch.height >= (48 * density).toInt(),
                                    "Switch touch target too small: $description")
                                if (scale == 1f && current === task) {
                                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                                    root.draw(Canvas(bitmap))
                                    File(targetContext.getExternalFilesDir(null), "widget-$language-${size.width.toInt()}x${size.height.toInt()}.png")
                                        .outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                                    bitmap.recycle()
                                }
                            }
                        }
                        val options = Bundle().apply {
                            putParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES,
                                arrayListOf(SizeF(180f, 110f), SizeF(600f, 180f)))
                        }
                        check(NextDdlWidgetRenderer.render(context, context, options, snapshot, task, now)
                            .apply(context, FrameLayout(context)) != null, "Exact size mapping failed")
                        val fallback = Bundle().apply {
                            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 203)
                            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 117)
                            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 412)
                            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 220)
                        }
                        check(NextDdlWidgetRenderer.render(context, context, fallback, snapshot, task, now)
                            .apply(context, FrameLayout(context)) != null, "Legacy orientation fallback failed")
                    }
                }
                } catch (error: Throwable) { mainFailure = error }
            }
            mainFailure?.let { throw it }
            assertions += WidgetPickerAssertions.run(this)
            result.putString("stream", "Android widget rendering: $assertions assertions passed\n")
            finish(Activity.RESULT_OK, result)
        } catch (error: Throwable) {
            result.putString("stream", "Android widget rendering failed: ${error.stackTraceToString()}\n")
            finish(Activity.RESULT_CANCELED, result)
        } finally {
            uiAutomation.dropShellPermissionIdentity()
        }
    }
}
