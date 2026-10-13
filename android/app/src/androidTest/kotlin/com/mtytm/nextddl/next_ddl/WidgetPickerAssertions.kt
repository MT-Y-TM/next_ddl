package com.mtytm.nextddl.next_ddl

import android.app.Instrumentation
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.Rect
import android.graphics.Bitmap
import android.os.SystemClock
import android.view.MotionEvent
import android.view.KeyEvent
import android.view.View
import android.widget.ListView
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

internal object WidgetPickerAssertions {
    fun run(instrumentation: Instrumentation): Int {
        var assertions = 0
        fun check(value: Boolean, message: String) { kotlin.check(value) { message }; assertions++ }
        val context = instrumentation.targetContext
        val manager = AppWidgetManager.getInstance(context)
        val host = AppWidgetHost(context, 128001)
        val prefs = context.getSharedPreferences(NextDdlWidgetProvider.PREFS, Context.MODE_PRIVATE)
        val originalSnapshot = prefs.getString("snapshot", null)
        val widgetA = host.allocateAppWidgetId()
        val widgetB = host.allocateAppWidgetId()
        val component = ComponentName(context, NextDdlWidgetProvider::class.java)
        val mainMonitor = instrumentation.addMonitor(MainActivity::class.java.name, null, false)
        var activity: WidgetTaskPickerActivity? = null
        try {
            check(manager.bindAppWidgetIdIfAllowed(widgetA, component), "Cannot bind widget A")
            check(manager.bindAppWidgetIdIfAllowed(widgetB, component), "Cannot bind widget B")
            val now = System.currentTimeMillis()
            fun snapshot(language: String): String {
                val tasks = JSONArray()
                repeat(120) { index ->
                    tasks.put(JSONObject().put("id", "task-$index").put("title", "Task $index / 截止任务 / タスク")
                        .put("finalDueAtUtc", now + (index + 1) * 3600000L).put("updatedAtUtc", index)
                        .put("milestones", JSONArray()).put("widgetPinned", index == 0))
                }
                tasks.put(JSONObject().put("id", "done").put("title", "Completed")
                    .put("completedAtUtc", now))
                return JSONObject().put("schemaVersion", 1).put("locale", language).put("timezoneId", "UTC")
                    .put("tasks", tasks).toString()
            }
            fun launch(): WidgetTaskPickerActivity {
                val monitor = instrumentation.addMonitor(WidgetTaskPickerActivity::class.java.name, null, false)
                val pendingIntent = NextDdlWidgetProvider.taskPickerPendingIntent(context, widgetA)
                check(pendingIntent.isActivity && !pendingIntent.isBroadcast, "Picker uses a broadcast trampoline")
                pendingIntent.send()
                val opened = monitor.waitForActivityWithTimeout(5000)
                instrumentation.removeMonitor(monitor)
                check(opened is WidgetTaskPickerActivity, "Widget button did not open the picker")
                return (opened as WidgetTaskPickerActivity).also {
                    activity = it
                    instrumentation.waitForIdleSync()
                    SystemClock.sleep(500)
                }
            }
            prefs.edit().putString("snapshot", snapshot("zh"))
                .putString("selectedTask_$widgetA", "task-40").putBoolean("manualSelection_$widgetA", true)
                .putString("selectedTask_$widgetB", "task-80").putBoolean("manualSelection_$widgetB", true).commit()
            instrumentation.runOnMainSync {
                check(!NextDdlWidgetProvider.selectTask(context, -1, "task-10"), "Invalid widget accepted")
                check(!NextDdlWidgetProvider.selectTask(context, widgetA, "done"), "Completed task accepted")
                check(!NextDdlWidgetProvider.selectTask(context, widgetA, "deleted"), "Deleted task accepted")
                check(prefs.getString("selectedTask_$widgetA", null) == "task-40", "Invalid selection changed storage")
            }
            val picker = launch()
            val list = picker.sheet!!.findViewById<ListView>(R.id.widget_picker_list)!!
            instrumentation.runOnMainSync {
                check(picker.sheet!!.isShowing, "Sheet is not visible")
                check(list.count == 120, "Picker must include all unfinished tasks and omit completed tasks")
                check(picker.sheet!!.findViewById<TextView>(R.id.widget_picker_title)!!.text.toString() == "选择小组件任务",
                    "Picker did not use app locale")
                check(list.childCount < list.count, "Task list must recycle, not inflate every task")
                check(list.firstVisiblePosition <= 40 && list.lastVisiblePosition >= 40,
                    "The current selection must be visible when opening")
                val selected = list.adapter.getView(40, null, list)
                check(selected.findViewById<View>(R.id.widget_picker_selected).visibility == View.VISIBLE,
                    "Current task is not marked")
                val other = list.adapter.getView(80, selected, list)
                check(other.findViewById<View>(R.id.widget_picker_selected).visibility == View.INVISIBLE,
                    "Recycled row retained a stale checkmark")
                check(NextDdlWidgetProvider.selectTask(context, widgetA, "task-41"), "Live selection failed")
                check(list.adapter.getView(41, null, list).findViewById<View>(R.id.widget_picker_selected).visibility == View.VISIBLE,
                    "Open picker did not update its checkmark")
                check(NextDdlWidgetProvider.selectTask(context, widgetA, "task-40"), "Cannot restore selection")
                val bounds = Rect()
                picker.sheet!!.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)!!.getGlobalVisibleRect(bounds)
                check(bounds.top > 0 && bounds.height() < picker.resources.displayMetrics.heightPixels,
                    "Picker must be a bottom sheet, not a full app page")
                list.setSelection(0)
            }
            instrumentation.waitForIdleSync()
            instrumentation.uiAutomation.takeScreenshot()?.let { screenshot ->
                File(context.getExternalFilesDir(null), "widget-picker-zh.png").outputStream().use {
                    screenshot.compress(Bitmap.CompressFormat.PNG, 100, it)
                }
                screenshot.recycle()
            }
            val bounds = Rect()
            instrumentation.runOnMainSync { list.getGlobalVisibleRect(bounds) }
            val downTime = SystemClock.uptimeMillis()
            val x = bounds.exactCenterX()
            val startY = bounds.bottom - 80f
            val endY = bounds.top + 100f
            fun pointer(action: Int, y: Float) {
                val event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, x, y, 0)
                instrumentation.sendPointerSync(event)
                event.recycle()
            }
            pointer(MotionEvent.ACTION_DOWN, startY)
            repeat(12) { step ->
                SystemClock.sleep(20)
                pointer(MotionEvent.ACTION_MOVE, startY + (endY - startY) * (step + 1) / 12f)
            }
            pointer(MotionEvent.ACTION_UP, endY)
            instrumentation.waitForIdleSync()
            SystemClock.sleep(500)
            instrumentation.runOnMainSync {
                check(list.firstVisiblePosition > 0, "Finger swipe did not scroll the list")
                list.setSelection(119)
            }
            instrumentation.waitForIdleSync()
            instrumentation.runOnMainSync {
                check(list.lastVisiblePosition == 119, "Cannot scroll to the last task")
                list.performItemClick(list.getChildAt(list.childCount - 1), 119, 119)
            }
            SystemClock.sleep(500)
            check(prefs.getString("selectedTask_$widgetA", null) == "task-119", "Chosen task was not persisted")
            check(prefs.getString("selectedTask_$widgetB", null) == "task-80", "Other widget was changed")
            check(NextDdlWidgetSnapshot.parse(prefs.getString("snapshot", null)!!).pinnedTaskId() == "task-0",
                "Local selection must not change the global star")
            check(picker.isFinishing || picker.isDestroyed, "Selecting did not dismiss the sheet")

            for ((language, title) in listOf("en" to "Choose widget task", "ja" to "ウィジェットのタスクを選択")) {
                prefs.edit().putString("snapshot", snapshot(language)).commit()
                val translated = launch()
                instrumentation.runOnMainSync {
                    check(translated.sheet!!.findViewById<TextView>(R.id.widget_picker_title)!!.text.toString() == title,
                        "Wrong picker locale: $language")
                    translated.sheet!!.findViewById<View>(R.id.widget_picker_close)!!.performClick()
                }
                SystemClock.sleep(500)
                check(prefs.getString("selectedTask_$widgetA", null) == "task-119", "Cancel changed the task")
            }
            val cancelled = launch()
            instrumentation.sendKeyDownUpSync(KeyEvent.KEYCODE_BACK)
            SystemClock.sleep(500)
            check(cancelled.isFinishing || cancelled.isDestroyed, "Back did not dismiss picker")
            check(prefs.getString("selectedTask_$widgetA", null) == "task-119", "Back changed the task")
            val swiped = launch()
            val sheetBounds = Rect()
            instrumentation.runOnMainSync {
                swiped.sheet!!.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)!!
                    .getGlobalVisibleRect(sheetBounds)
            }
            val swipeTime = SystemClock.uptimeMillis()
            fun drag(action: Int, y: Float) {
                val event = MotionEvent.obtain(swipeTime, SystemClock.uptimeMillis(), action, sheetBounds.exactCenterX(), y, 0)
                instrumentation.sendPointerSync(event)
                event.recycle()
            }
            val from = sheetBounds.top + 12f
            val to = sheetBounds.bottom - 20f
            drag(MotionEvent.ACTION_DOWN, from)
            repeat(16) { step ->
                SystemClock.sleep(20)
                drag(MotionEvent.ACTION_MOVE, from + (to - from) * (step + 1) / 16f)
            }
            drag(MotionEvent.ACTION_UP, to)
            SystemClock.sleep(700)
            check(swiped.isFinishing || swiped.isDestroyed, "Swipe down did not dismiss picker")
            check(prefs.getString("selectedTask_$widgetA", null) == "task-119", "Swipe down changed the task")
            check(mainMonitor.hits == 0, "Picker unexpectedly started Flutter MainActivity")
            // A full data replacement while the sheet is open must discard stale
            // rows. No stale task can be selected after an import or completion.
            val stale = launch()
            instrumentation.runOnMainSync {
                prefs.edit().putString("snapshot", """{"schemaVersion":1,"locale":"en","tasks":[]}""").commit()
            }
            instrumentation.waitForIdleSync()
            instrumentation.runOnMainSync {
                check(stale.sheet!!.findViewById<ListView>(R.id.widget_picker_list)!!.count == 0,
                    "Open picker kept stale tasks")
                check(stale.sheet!!.findViewById<View>(R.id.widget_picker_empty)!!.visibility == View.VISIBLE,
                    "Empty state is not visible")
                stale.finish()
            }
        } finally {
            instrumentation.runOnMainSync { activity?.finish() }
            host.deleteHost()
            prefs.edit().putString("snapshot", originalSnapshot)
                .remove("selectedTask_$widgetA").remove("manualSelection_$widgetA")
                .remove("selectedTask_$widgetB").remove("manualSelection_$widgetB").commit()
            instrumentation.removeMonitor(mainMonitor)
        }
        return assertions
    }
}
