package com.mtytm.nextddl.next_ddl

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs

class NextDdlWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refreshAll(context)
    override fun onEnabled(context: Context) = refreshAll(context)
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = refreshAll(context)
    override fun onRestored(context: Context, oldIds: IntArray, newIds: IntArray) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for ((oldId, newId) in oldIds.zip(newIds.toList())) {
            prefs.getString(selectedTaskKey(oldId), null)?.let {
                editor.putString(selectedTaskKey(newId), it)
            }
            editor.putBoolean(manualSelectionKey(newId), prefs.getBoolean(manualSelectionKey(oldId), false))
            if (oldId != newId) {
                editor.remove(selectedTaskKey(oldId)).remove(manualSelectionKey(oldId))
            }
        }
        editor.commit()
        refreshAll(context)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        for (id in ids) {
            editor.remove(selectedTaskKey(id)).remove(manualSelectionKey(id))
        }
        editor.apply()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == SWITCH_TASK) {
            switchTask(context, intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID))
            return
        }
        if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_LOCALE_CHANGED)) {
            refreshAll(context)
        }
    }

    companion object {
        internal const val PREFS = "next_ddl_home_widget"
        const val OPEN_TASK = "com.mtytm.nextddl.next_ddl.WIDGET_OPEN_TASK"
        private const val SWITCH_TASK = "com.mtytm.nextddl.next_ddl.WIDGET_SWITCH_TASK"
        private const val EXTRA_WIDGET_ID = "next_ddl_widget_id"

        private fun selectedTaskKey(id: Int) = "selectedTask_$id"
        private fun manualSelectionKey(id: Int) = "manualSelection_$id"

        fun refreshAll(context: Context, resetManualSelection: Boolean = false) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, NextDdlWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("snapshot", null)
            val snapshot = try { raw?.let { NextDdlWidgetSnapshot.parse(it) } ?: NextDdlWidgetSnapshot() }
                catch (_: Exception) { NextDdlWidgetSnapshot() }
            val locale = if (snapshot.locale in listOf("zh", "en", "ja")) Locale.forLanguageTag(snapshot.locale)
                else Locale.getDefault().let { if (it.language in listOf("zh", "en", "ja")) it else Locale.ENGLISH }
            val config = Configuration(context.resources.configuration).apply { setLocale(locale) }
            val localized = context.createConfigurationContext(config)
            val now = System.currentTimeMillis()
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", locale).apply {
                timeZone = TimeZone.getTimeZone(snapshot.timezoneId)
            }
            fun date(time: Long) = formatter.format(Date(time))
            fun countdown(due: Long): String {
                val delta = due - now
                val hours = abs(delta) / (60L * 60L * 1000L)
                val amount = localized.getString(
                    R.string.widget_days_hours,
                    hours / 24L,
                    hours % 24L,
                )
                return localized.getString(if (delta < 0) R.string.widget_overdue else R.string.widget_remaining, amount)
            }
            for (id in ids) {
                if (resetManualSelection) {
                    prefs.edit()
                        .remove(selectedTaskKey(id))
                        .remove(manualSelectionKey(id))
                        .commit()
                }
                val selectedId = prefs.getString(selectedTaskKey(id), null)
                val manualSelection = prefs.getBoolean(manualSelectionKey(id), false) &&
                    snapshot.tasks.any { it.id == selectedId }
                val task = snapshot.select(
                    now,
                    selectedId = selectedId,
                    manualSelection = manualSelection,
                )
                // Keep the rendered cursor even in automatic mode, so a switch
                // starts from what was visible if time advanced between refreshes.
                prefs.edit().putString(selectedTaskKey(id), task?.id)
                    .putBoolean(manualSelectionKey(id), manualSelection).commit()
                val views = RemoteViews(context.packageName, R.layout.next_ddl_widget)
                views.setViewVisibility(R.id.widget_menu_icon, if (snapshot.tasks.size > 1) View.VISIBLE else View.GONE)
                views.setContentDescription(R.id.widget_menu_icon, localized.getString(R.string.widget_switch_label))
                views.setTextViewText(R.id.widget_final_label, localized.getString(R.string.widget_final_label))
                views.setTextViewText(R.id.widget_countdown_label, localized.getString(R.string.widget_remaining_label))
                views.setTextViewText(R.id.widget_title, task?.title ?: localized.getString(R.string.widget_empty))
                if (task == null) {
                    views.setViewVisibility(R.id.widget_empty_hint, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_details, View.GONE)
                    views.setTextViewText(R.id.widget_empty_hint, localized.getString(R.string.widget_empty_hint))
                } else {
                    views.setViewVisibility(R.id.widget_empty_hint, View.GONE)
                    views.setViewVisibility(R.id.widget_details, View.VISIBLE)
                    views.setTextViewText(R.id.widget_status, localized.getString(
                        if (task.finalDue < now) R.string.widget_overdue_status else R.string.widget_focus_label,
                    ))
                    views.setTextViewText(R.id.widget_percent, "${task.remainingProgress(now)}%")
                    views.setProgressBar(R.id.widget_progress, 100, task.remainingProgress(now), false)
                    views.setTextViewText(R.id.widget_final_countdown, countdown(task.finalDue))
                    views.setTextViewText(R.id.widget_final, date(task.finalDue))
                    views.setTextColor(
                        R.id.widget_final_countdown,
                        context.resources.getColor(
                            if (task.finalDue < now) R.color.widget_warning else R.color.widget_accent,
                            context.theme,
                        ),
                    )
                }
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = OPEN_TASK
                    data = Uri.Builder().scheme("nextddl-widget").authority("task")
                        .appendPath(task?.id ?: "").appendQueryParameter("widget", id.toString()).build()
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    task?.let { putExtra("widgetTaskId", it.id) }
                }
                views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(
                    context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ))
                val switchIntent = Intent(context, NextDdlWidgetProvider::class.java).apply {
                    action = SWITCH_TASK
                    data = Uri.Builder().scheme("nextddl-widget").authority("switch")
                        .appendPath(id.toString()).build()
                    putExtra(EXTRA_WIDGET_ID, id)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_menu_icon,
                    PendingIntent.getBroadcast(
                        context,
                        id,
                        switchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
                manager.updateAppWidget(id, views)
            }
        }

        fun switchTask(context: Context, widgetId: Int) {
            if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
            val manager = AppWidgetManager.getInstance(context)
            if (widgetId !in manager.getAppWidgetIds(ComponentName(context, NextDdlWidgetProvider::class.java))) return
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString("snapshot", null) ?: return
            val snapshot = runCatching { NextDdlWidgetSnapshot.parse(raw) }.getOrNull() ?: return
            val now = System.currentTimeMillis()
            val next = snapshot.nextAfter(now, prefs.getString(selectedTaskKey(widgetId), null)) ?: return
            prefs.edit()
                .putString(selectedTaskKey(widgetId), next.id)
                .putBoolean(manualSelectionKey(widgetId), true)
                .commit()
            refreshAll(context)
        }
    }
}
