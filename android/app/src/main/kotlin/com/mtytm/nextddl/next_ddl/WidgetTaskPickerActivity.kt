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
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.BaseAdapter
import android.widget.ListView
import android.widget.Spinner
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
    private var categoryPicker: Spinner? = null
    private var content: View? = null
    private var loadedSnapshot: String? = null
    private var loadedSelection: String? = null
    private var loadedCategory: String? = null
    private var categoryOptions: List<PickerCategory> = emptyList()
    private var applyingCategory = false

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
        if (key == "snapshot" || key == "selectedTask_$widgetId" || key == "selectedCategory_$widgetId") refreshList()
    }

    private fun showPicker() {
        widgetId = intent.getIntExtra(NextDdlWidgetProvider.EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (!NextDdlWidgetProvider.ownsWidget(this, widgetId)) { finish(); return }
        val dialog = BottomSheetDialog(this, R.style.WidgetTaskPickerSheet)
        val root = layoutInflater.inflate(R.layout.widget_task_picker, null)
        content = root
        list = root.findViewById(R.id.widget_picker_list)
        categoryPicker = root.findViewById(R.id.widget_picker_category)
        categoryPicker?.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onNothingSelected(parent: AdapterView<*>?) = Unit
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                if (applyingCategory || position !in categoryOptions.indices) return
                val category = categoryOptions[position].id
                if (prefs.getString("selectedCategory_$widgetId", NextDdlWidgetSnapshot.CATEGORY_IN_PROGRESS) != category) {
                    prefs.edit().putString("selectedCategory_$widgetId", category).apply()
                    loadedCategory = null
                    refreshList()
                }
            }
        }
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
        val snapshot = readSnapshot(this)
        val category = prefs.getString("selectedCategory_$widgetId", NextDdlWidgetSnapshot.CATEGORY_IN_PROGRESS)
            ?: NextDdlWidgetSnapshot.CATEGORY_IN_PROGRESS
        if (taskList.adapter != null && loadedSnapshot == raw && loadedSelection == displayedId && loadedCategory == category) return
        val firstLoad = taskList.adapter == null
        if (loadedSnapshot != raw || categoryOptions.isEmpty()) {
            categoryOptions = buildCategories(snapshot)
            categoryPicker?.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item,
                categoryOptions.map { it.label }).also { it.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item) }
        }
        val categoryPosition = categoryOptions.indexOfFirst { it.id == category }.takeIf { it >= 0 } ?: 0
        val activeCategory = categoryOptions.getOrNull(categoryPosition)?.id ?: NextDdlWidgetSnapshot.CATEGORY_IN_PROGRESS
        if (activeCategory != category) prefs.edit().putString("selectedCategory_$widgetId", activeCategory).apply()
        applyingCategory = true
        categoryPicker?.setSelection(categoryPosition, false)
        applyingCategory = false
        val now = System.currentTimeMillis()
        val tasks = snapshot.selectableTasks(now, activeCategory)
        val selectedId = displayedId?.takeIf { id -> tasks.any { it.id == id } }
        val position = taskList.firstVisiblePosition
        val top = taskList.getChildAt(0)?.top ?: 0
        taskList.adapter = TaskAdapter(this, tasks, snapshot.timezoneId, selectedId, now)
        loadedSnapshot = raw
        loadedSelection = displayedId
        loadedCategory = activeCategory
        val selectedPosition = tasks.indexOfFirst { it.id == selectedId }
        taskList.setSelectionFromTop(if (firstLoad && selectedPosition >= 0) selectedPosition else position,
            if (firstLoad) 0 else top)
        root.findViewById<View>(R.id.widget_picker_empty).visibility = if (tasks.isEmpty()) View.VISIBLE else View.GONE
        taskList.visibility = if (tasks.isEmpty()) View.GONE else View.VISIBLE
        val metrics = resources.displayMetrics
        val header = root.findViewById<View>(R.id.widget_picker_header)
        header.measure(View.MeasureSpec.makeMeasureSpec(metrics.widthPixels, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
        val categoryHeight = categoryPicker?.height?.takeIf { it > 0 } ?: (48 * metrics.density).roundToInt()
        val remaining = (metrics.heightPixels * 0.75f - header.measuredHeight - categoryHeight - 64 * metrics.density).toInt()
            .coerceAtLeast((80 * metrics.density).roundToInt())
        taskList.layoutParams = taskList.layoutParams.apply {
            height = min(remaining, (tasks.size * 100 * metrics.density * resources.configuration.fontScale).roundToInt())
        }
    }

    private fun buildCategories(snapshot: NextDdlWidgetSnapshot): List<PickerCategory> = buildList {
        add(PickerCategory(NextDdlWidgetSnapshot.CATEGORY_IN_PROGRESS, getString(R.string.widget_category_in_progress)))
        add(PickerCategory(NextDdlWidgetSnapshot.CATEGORY_OVERDUE, getString(R.string.widget_category_overdue)))
        add(PickerCategory(NextDdlWidgetSnapshot.CATEGORY_IMPORTANT, getString(R.string.widget_category_important)))
        add(PickerCategory(NextDdlWidgetSnapshot.CATEGORY_ALL, getString(R.string.widget_category_all)))
        if (snapshot.tasks.any { it.completed }) add(PickerCategory(NextDdlWidgetSnapshot.CATEGORY_COMPLETED,
            getString(R.string.widget_category_completed)))
        snapshot.tasks.flatMap { it.tags }.distinct().sortedBy { it.lowercase(Locale.ROOT) }.forEach { tag ->
            add(PickerCategory(NextDdlWidgetSnapshot.CATEGORY_TAG_PREFIX + tag, getString(R.string.widget_category_tag, tag)))
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
        loadedCategory = null
        categoryOptions = emptyList()
        categoryPicker = null
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
            val remaining = if (task.completed) context.getString(R.string.widget_completed_status)
                else context.getString(if (task.finalDue < now) R.string.widget_overdue else R.string.widget_remaining, amount)
            val summary = context.getString(R.string.widget_picker_summary, remaining, formatter.format(Date(task.finalDue)))
            row.findViewById<TextView>(R.id.widget_picker_task_summary).apply {
                text = summary
                setTextColor(context.getColor(if (!task.completed && task.finalDue < now) R.color.widget_warning else R.color.widget_secondary))
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

    private data class PickerCategory(val id: String, val label: String)
}
