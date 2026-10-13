package com.mtytm.nextddl.next_ddl

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.view.WindowManager
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt

internal object NextDdlWidgetRenderer {
    fun screenSize(context: Context): WidgetSize {
        val metrics = context.resources.displayMetrics
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = context.getSystemService(WindowManager::class.java).maximumWindowMetrics.bounds
            WidgetSize(bounds.width() / metrics.density, bounds.height() / metrics.density)
        } else {
            WidgetSize(metrics.widthPixels / metrics.density, metrics.heightPixels / metrics.density)
        }
    }

    fun render(
        context: Context,
        localized: Context,
        options: Bundle,
        snapshot: NextDdlWidgetSnapshot,
        task: WidgetTask?,
        now: Long,
        openTask: PendingIntent? = null,
        switchTask: PendingIntent? = null,
    ): RemoteViews {
        val screen = screenSize(context)
        fun create(size: WidgetSize) = createView(localized, snapshot, task, now, size, screen, openTask, switchTask)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                ?.filter { WidgetSize(it.width, it.height).valid }?.distinct()?.take(16)
            if (!sizes.isNullOrEmpty()) {
                return RemoteViews(sizes.associateWith { create(WidgetSize(it.width, it.height)) })
            }
        }
        // Legacy and MIUI launchers can omit exact sizes. Keep both orientation
        // variants so the host can rotate without waiting for a broadcast.
        val (portrait, landscape) = NextDdlWidgetLayout.fallbackSizes(
            screen,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).toFloat(),
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).toFloat(),
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH).toFloat(),
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).toFloat(),
        )
        return RemoteViews(create(landscape), create(portrait))
    }

    internal fun createView(
        context: Context,
        snapshot: NextDdlWidgetSnapshot,
        task: WidgetTask?,
        now: Long,
        size: WidgetSize,
        screen: WidgetSize = screenSize(context),
        openTask: PendingIntent? = null,
        switchTask: PendingIntent? = null,
    ): RemoteViews {
        val metrics = context.resources.displayMetrics
        val plan = NextDdlWidgetLayout.plan(size, screen, context.resources.configuration.fontScale)
        val views = RemoteViews(context.packageName,
            if (plan.horizontal) R.layout.next_ddl_widget_wide else R.layout.next_ddl_widget)
        fun dp(value: Int) = (value * metrics.density).roundToInt()
        fun visible(id: Int, show: Boolean) = views.setViewVisibility(id, if (show) View.VISIBLE else View.GONE)
        fun font(id: Int, sp: Float) = views.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, sp)
        fun padding(id: Int, start: Int = 0, top: Int = 0, end: Int = 0, bottom: Int = 0) =
            views.setViewPadding(id, dp(start), dp(top), dp(end), dp(bottom))
        visible(R.id.widget_menu_icon, snapshot.tasks.size > 1)
        views.setContentDescription(R.id.widget_menu_icon, context.getString(R.string.widget_switch_label))
        views.setTextViewText(R.id.widget_title, task?.title ?: context.getString(R.string.widget_empty))
        padding(R.id.widget_header, plan.padding + 4, plan.headerPadding, 4, plan.headerPadding)
        padding(R.id.widget_details, plan.padding, plan.padding, plan.padding, plan.padding)
        padding(R.id.widget_empty_hint, plan.padding, plan.padding, plan.padding, plan.padding)
        padding(R.id.widget_overview, end = if (plan.horizontal) plan.gap else 0,
            bottom = if (!plan.horizontal && plan.showOverview) plan.gap else 0)
        padding(R.id.widget_deadline_text, start = if (plan.showClock) plan.gap else 0)
        font(R.id.widget_title, min(plan.titleSp, 36f / context.resources.configuration.fontScale))
        font(R.id.widget_status, plan.labelSp)
        font(R.id.widget_percent, plan.labelSp + 4f)
        font(R.id.widget_countdown_label, plan.labelSp)
        font(R.id.widget_final_label, plan.labelSp)
        font(R.id.widget_empty_hint, plan.labelSp)
        visible(R.id.widget_empty_hint, task == null)
        visible(R.id.widget_details, task != null)
        visible(R.id.widget_overview, plan.showOverview)
        visible(R.id.widget_countdown_label, plan.showRemainingLabel)
        visible(R.id.widget_final, plan.showDate)
        visible(R.id.widget_clock, plan.showClock)
        views.setTextViewText(R.id.widget_final_label, context.getString(R.string.widget_final_label))
        views.setTextViewText(R.id.widget_countdown_label, context.getString(R.string.widget_remaining_label))
        views.setTextViewText(R.id.widget_empty_hint, context.getString(R.string.widget_empty_hint))
        if (task != null) {
            val overdue = task.finalDue < now
            views.setTextViewText(R.id.widget_status, context.getString(
                if (overdue) R.string.widget_overdue_status else R.string.widget_focus_label))
            views.setTextViewText(R.id.widget_percent, "${task.remainingProgress(now)}%")
            views.setProgressBar(R.id.widget_progress, 100, task.remainingProgress(now), false)
            val hours = abs(task.finalDue - now) / (60L * 60L * 1000L)
            val amount = context.getString(R.string.widget_days_hours, hours / 24L, hours % 24L)
            val countdown = if (overdue) context.getString(R.string.widget_overdue, amount) else amount
            val locale = context.resources.configuration.locales[0]
            val date = SimpleDateFormat("yyyy-MM-dd HH:mm", locale).apply {
                timeZone = TimeZone.getTimeZone(snapshot.timezoneId)
            }.format(Date(task.finalDue))
            val columnWidth = (plan.size.width - 2 * plan.padding) / if (plan.horizontal) 2f else 1f
            val textWidth = columnWidth - if (plan.showClock) 32f + plan.gap else 0f
            fun fitted(text: String, preferredSp: Float, bold: Boolean = false): Float {
                val paint = Paint().apply {
                    typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                    textLocale = locale
                }
                // Also fit the essential two lines vertically at large system fonts.
                val bodyHeight = plan.size.height - 48f - 2 * plan.headerPadding - 2 * plan.padding
                val heightRatio = min(1f, bodyHeight / ((plan.labelSp + plan.countdownSp) * 1.3f * context.resources.configuration.fontScale))
                var low = 0f
                var high = preferredSp * heightRatio
                // Android 14+ scales SP nonlinearly. A width ratio is not enough;
                // remeasure every candidate and allow for rounded DP padding.
                repeat(12) {
                    val candidate = (low + high) / 2f
                    paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, candidate, metrics)
                    if (paint.measureText(text) <= textWidth * metrics.density - dp(2)) low = candidate
                    else high = candidate
                }
                return low
            }
            font(R.id.widget_final_countdown, fitted(countdown, plan.countdownSp, true))
            font(R.id.widget_final_label, fitted(context.getString(R.string.widget_final_label), plan.labelSp))
            font(R.id.widget_final, fitted(date, 12f))
            views.setTextViewText(R.id.widget_final_countdown, countdown)
            views.setTextViewText(R.id.widget_final, date)
            views.setTextColor(R.id.widget_final_countdown, context.getColor(
                if (overdue) R.color.widget_warning else R.color.widget_accent))
        }
        if (openTask != null) views.setOnClickPendingIntent(R.id.widget_root, openTask)
        if (switchTask != null) views.setOnClickPendingIntent(R.id.widget_menu_icon, switchTask)
        return views
    }
}
