package com.mtytm.nextddl.next_ddl

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.ListView
import android.widget.TextView
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.min
import kotlin.math.roundToInt

/** A native, transient sheet over the launcher; never starts the Flutter engine. */
class WidgetTaskPickerActivity : Activity(), SharedPreferences.OnSharedPreferenceChangeListener {
    private val prefs by lazy { getSharedPreferences(NextDdlWidgetProvider.PREFS, MODE_PRIVATE) }
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    internal var sheet: BottomSheetDialog? = null
        private set
    private var list: ListView? = null
    private var content: View? = null
    private var loadedSnapshot: String? = null
    private var loadedSelection: String? = null

    override fun attachBaseContext(base: Context) {
        val snapshot = readSnapshot(base)
        val locale = if (snapshot.locale in listOf("zh", "en", "ja")) Locale.forLanguageTag(snapshot.locale)
            else Locale.getDefault().let { if (it.language in listOf("zh", "en", "ja")) it else Locale.ENGLISH }
        super.attachBaseContext(base.createConfigurationContext(Configuration(base.resources.configuration).apply {
            setLocale(locale)
        }))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showPicker()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        closeSheet()
        showPicker()
    }

    override fun onStart() {
        super.onStart()
        prefs.registerOnSharedPreferenceChangeListener(this)
    }

    override fun onResume() {
        super.onResume()
        if (!NextDdlWidgetProvider.ownsWidget(this, widgetId)) finish() else refreshList()
    }

    override fun onStop() {
        prefs.unregisterOnSharedPreferenceChangeListener(this)
        super.onStop()
    }

    override fun onDestroy() {
        closeSheet()
        super.onDestroy()
    }

    override fun onSharedPreferenceChanged(preferences: SharedPreferences, key: String?) {
        if (key == "snapshot" || key == "selectedTask_$widgetId") refreshList()
    }

    private fun showPicker() {
        widgetId = intent.getIntExtra(NextDdlWidgetProvider.EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (!NextDdlWidgetProvider.ownsWidget(this, widgetId)) { finish(); return }
        val dialog = BottomSheetDialog(this, R.style.WidgetTaskPickerSheet)
        val root = layoutInflater.inflate(R.layout.widget_task_picker, null)
        content = root
        list = root.findViewById(R.id.widget_picker_list)
        root.findViewById<View>(R.id.widget_picker_close).setOnClickListener { dialog.dismiss() }
        list?.setOnItemClickListener { parent, _, position, _ ->
            val task = parent.getItemAtPosition(position) as? WidgetTask ?: return@setOnItemClickListener
            // Revalidate against fresh storage: a task can disappear while the
            // sheet is open. Never save a stale or completed task ID.
            if (NextDdlWidgetProvider.selectTask(this, widgetId, task.id)) dialog.dismiss()
            else refreshList()
        }
        dialog.setContentView(root)
        dialog.setTitle(R.string.widget_picker_title)
        dialog.setCanceledOnTouchOutside(true)
        dialog.setDismissWithAnimation(true)
        dialog.behavior.apply {
            maxHeight = (resources.displayMetrics.heightPixels * 0.75f).roundToInt()
            maxWidth = (600 * resources.displayMetrics.density).roundToInt()
            skipCollapsed = true
            setShouldRemoveExpandedCorners(false)
        }
        dialog.setOnShowListener { dialog.behavior.state = BottomSheetBehavior.STATE_EXPANDED }
        dialog.setOnDismissListener { finish() }
        sheet = dialog
        refreshList()
        dialog.show()
    }

    private fun refreshList() {
        val root = content ?: return
        val taskList = list ?: return
        if (!NextDdlWidgetProvider.ownsWidget(this, widgetId)) { finish(); return }
        val raw = prefs.getString("snapshot", null)
        val displayedId = prefs.getString("selectedTask_$widgetId", null)
        if (taskList.adapter != null && loadedSnapshot == raw && loadedSelection == displayedId) return
        val firstLoad = taskList.adapter == null
        val snapshot = readSnapshot(this)
        val now = System.currentTimeMillis()
        val tasks = snapshot.selectableTasks(now)
        val selectedId = displayedId?.takeIf { id -> tasks.any { it.id == id } }
            ?: snapshot.select(now)?.id
        val position = taskList.firstVisiblePosition
        val top = taskList.getChildAt(0)?.top ?: 0
        taskList.adapter = TaskAdapter(this, tasks, snapshot.timezoneId, selectedId, now)
        loadedSnapshot = raw
        loadedSelection = displayedId
        val selectedPosition = tasks.indexOfFirst { it.id == selectedId }
        taskList.setSelectionFromTop(if (firstLoad && selectedPosition >= 0) selectedPosition else position,
            if (firstLoad) 0 else top)
        root.findViewById<View>(R.id.widget_picker_empty).visibility = if (tasks.isEmpty()) View.VISIBLE else View.GONE
        taskList.visibility = if (tasks.isEmpty()) View.GONE else View.VISIBLE
        val metrics = resources.displayMetrics
        val header = root.findViewById<View>(R.id.widget_picker_header)
        header.measure(View.MeasureSpec.makeMeasureSpec(metrics.widthPixels, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
        val remaining = (metrics.heightPixels * 0.75f - header.measuredHeight - 64 * metrics.density).toInt()
            .coerceAtLeast((80 * metrics.density).roundToInt())
        taskList.layoutParams = taskList.layoutParams.apply {
            height = min(remaining, (tasks.size * 100 * metrics.density * resources.configuration.fontScale).roundToInt())
        }
    }

    private fun closeSheet() {
        sheet?.setOnDismissListener(null)
        sheet?.dismiss()
        sheet = null
        list = null
        content = null
        loadedSnapshot = null
        loadedSelection = null
    }

    private class TaskAdapter(
        private val context: Context,
        private val tasks: List<WidgetTask>,
        timezoneId: String,
        private val selectedId: String?,
        private val now: Long,
    ) : BaseAdapter() {
        private val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm", context.resources.configuration.locales[0]).apply {
            timeZone = TimeZone.getTimeZone(timezoneId)
        }

        override fun getCount() = tasks.size
        override fun getItem(position: Int) = tasks[position]
        override fun getItemId(position: Int) = position.toLong()
        override fun getView(position: Int, recycled: View?, parent: ViewGroup): View {
            val row = recycled ?: LayoutInflater.from(context).inflate(R.layout.widget_task_picker_row, parent, false)
            val task = getItem(position)
            row.findViewById<TextView>(R.id.widget_picker_task_title).text = task.title
            val hours = kotlin.math.abs(task.finalDue - now) / 3600000L
            val amount = context.getString(R.string.widget_days_hours, hours / 24, hours % 24)
            val remaining = context.getString(if (task.finalDue < now) R.string.widget_overdue else R.string.widget_remaining, amount)
            val summary = context.getString(R.string.widget_picker_summary, remaining, formatter.format(Date(task.finalDue)))
            row.findViewById<TextView>(R.id.widget_picker_task_summary).apply {
                text = summary
                setTextColor(context.getColor(if (task.finalDue < now) R.color.widget_warning else R.color.widget_secondary))
            }
            val selected = task.id == selectedId
            row.findViewById<View>(R.id.widget_picker_selected).visibility = if (selected) View.VISIBLE else View.INVISIBLE
            row.setBackgroundColor(if (selected) 0x197ED0F1 else android.graphics.Color.TRANSPARENT)
            row.contentDescription = if (selected) "${task.title}, $summary, ${context.getString(R.string.widget_picker_selected)}"
                else "${task.title}, $summary"
            return row
        }
    }

    companion object {
        private fun readSnapshot(context: Context): NextDdlWidgetSnapshot =
            context.getSharedPreferences(NextDdlWidgetProvider.PREFS, MODE_PRIVATE).getString("snapshot", null)
                ?.let { runCatching { NextDdlWidgetSnapshot.parse(it) }.getOrNull() } ?: NextDdlWidgetSnapshot()
    }
}
