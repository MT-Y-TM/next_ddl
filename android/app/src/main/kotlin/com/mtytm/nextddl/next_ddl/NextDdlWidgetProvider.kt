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
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.ceil

class NextDdlWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refreshAll(context)
    override fun onEnabled(context: Context) = refreshAll(context)
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = refreshAll(context)
    override fun onRestored(context: Context, oldIds: IntArray, newIds: IntArray) = refreshAll(context)

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_LOCALE_CHANGED)) {
            refreshAll(context)
        }
    }

    companion object {
        internal const val PREFS = "next_ddl_home_widget"
        const val OPEN_TASK = "com.mtytm.nextddl.next_ddl.WIDGET_OPEN_TASK"

        fun refreshAll(context: Context) {
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
            val task = snapshot.select(now)
            val formatter = SimpleDateFormat("MM-dd HH:mm z", locale).apply {
                timeZone = TimeZone.getTimeZone(snapshot.timezoneId)
            }
            fun date(time: Long) = formatter.format(Date(time))
            fun countdown(due: Long): String {
                val delta = due - now
                val minutes = ceil(kotlin.math.abs(delta.toDouble()) / 60000.0).toLong()
                val amount = if (minutes < 60) localized.getString(R.string.widget_minutes, minutes)
                    else localized.getString(R.string.widget_hours_minutes, minutes / 60, minutes % 60)
                return localized.getString(if (delta < 0) R.string.widget_overdue else R.string.widget_remaining, amount)
            }
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.next_ddl_widget)
                views.setTextViewText(R.id.widget_title, task?.title ?: localized.getString(R.string.widget_empty))
                views.setTextViewText(R.id.widget_node, task?.let {
                    localized.getString(R.string.widget_next, it.targetTitle(now))
                } ?: localized.getString(R.string.widget_empty_hint))
                views.setTextViewText(R.id.widget_countdown, task?.let { countdown(it.activeDue(now)) } ?: "")
                views.setTextViewText(R.id.widget_final, task?.let {
                    localized.getString(R.string.widget_final_due, date(it.finalDue))
                } ?: "")
                views.setTextViewText(R.id.widget_updated, localized.getString(R.string.widget_updated_at, date(now)))
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
                manager.updateAppWidget(id, views)
            }
        }
    }
}
