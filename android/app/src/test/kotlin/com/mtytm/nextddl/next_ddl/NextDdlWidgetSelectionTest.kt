package com.mtytm.nextddl.next_ddl

/** Standalone JVM contract tests; no Android runtime or JUnit dependency needed. */
object NextDdlWidgetSelectionTest {
    @JvmStatic
    fun main(args: Array<String>) {
        var assertions = 0
        fun check(value: Boolean) {
            kotlin.check(value)
            assertions++
        }
        val now = 1000L
        val first = WidgetTask("first", "Task", 5000, 10, listOf(
            WidgetNode("past", 999), WidgetNode("  ", 1000), WidgetNode("future", 2000),
        ), 1000)
        check(first.next(now)?.due == 1000L)
        check(first.targetTitle(now) == "Task")
        check(first.next(1001)?.title == "future")
        check(first.activeDue(2001) == 5000L)
        check(first.targetTitle(2001) == "Task")
        check(first.remainingProgress(1000) == 100)
        check(first.remainingProgress(3000) == 50)
        check(NextDdlWidgetSnapshot().select(now) == null)
        val overdue = WidgetTask("overdue", "Old", 900, 20, emptyList(), 0)
        check(NextDdlWidgetSnapshot(tasks = listOf(overdue, first)).select(now) == first)
        check(NextDdlWidgetSnapshot(tasks = listOf(overdue, first)).select(6000) == overdue)
        val second = WidgetTask("second", "Second", 8000, 30, listOf(WidgetNode("soon", 1500)), 1000)
        val snapshot = NextDdlWidgetSnapshot(tasks = listOf(first, second))
        check(snapshot.select(now) == first)
        check(snapshot.select(1001) == second)
        check(snapshot.select(1501) == first)
        val tied = first.copy(id = "newer", updated = 11)
        check(NextDdlWidgetSnapshot(tasks = listOf(first, tied)).select(now) == tied)
        check(NextDdlWidgetSnapshot(tasks = listOf(first)).select(5000) == first)
        val pinned = second.copy(pinned = true)
        check(NextDdlWidgetSnapshot(tasks = listOf(first, pinned)).select(now) == pinned)
        check(NextDdlWidgetSnapshot(tasks = listOf(first, second)).nextAfter(now, "first") == second)
        check(NextDdlWidgetSnapshot(tasks = listOf(first, second)).nextAfter(now, "second") == first)
        // First click advances from the rendered default, not from a null cursor.
        check(snapshot.nextAfter(now, null) == second)
        val starred = NextDdlWidgetSnapshot(tasks = listOf(first, pinned))
        check(starred.nextAfter(now, null) == first)
        check(starred.select(now, "first", true) == first)
        check(starred.select(now, "first", false) == pinned)
        check(starred.select(now, "deleted", true) == pinned)
        check(NextDdlWidgetSnapshot().nextAfter(now, null) == null)
        check(NextDdlWidgetSnapshot(tasks = listOf(first)).nextAfter(now, "first") == first)
        // Each widget supplies its own cursor; refreshing one must not move another.
        check(snapshot.select(now, "first", true) == first)
        check(snapshot.select(now, "second", true) == second)
        val withOverdue = NextDdlWidgetSnapshot(tasks = listOf(first, second, overdue))
        check(withOverdue.nextAfter(now, "second") == overdue)
        check(withOverdue.nextAfter(now, "overdue") == first)
        check(withOverdue.select(now, "overdue", true) == overdue)
        check(withOverdue.copy(tasks = listOf(first, overdue.copy(pinned = true))).select(now)?.id == "overdue")
        check(starred.copy(tasks = listOf(first)).select(now, "second", true) == first)
        check(starred.copy(tasks = emptyList()).select(now, "second", true) == null)
        check(starred.resetsManualSelectionFrom(snapshot))
        check(snapshot.resetsManualSelectionFrom(starred))
        check(!starred.resetsManualSelectionFrom(starred.copy(locale = "ja")))
        check(!starred.copy(timezoneId = "Asia/Shanghai").resetsManualSelectionFrom(starred))
        check(!starred.copy(tasks = listOf(first, pinned.copy(title = "Edited", updated = 100))).resetsManualSelectionFrom(starred))
        check(!snapshot.resetsManualSelectionFrom(null))
        // A scheduled refresh may change the automatic priority; the displayed
        // cursor still advances correctly at the moment of the user's click.
        check(snapshot.nextAfter(1001, "first") == second)
        val oldStar = first.copy(pinned = true, updated = 10)
        check(NextDdlWidgetSnapshot(tasks = listOf(oldStar, pinned)).pinnedTaskId() == "second")
        check(NextDdlWidgetSnapshot(tasks = listOf(oldStar, pinned)).select(now) == pinned)
        check(first.remainingProgress(5000) == 0)
        check(first.remainingProgress(6000) == 0)
        check(first.remainingProgress(0) == 100)
        val raw = """{"schemaVersion":1,"locale":"ja","timezoneId":"Asia/Tokyo","tasks":[
            {"id":"done","title":"Done","completedAtUtc":123},
            {"id":"open","title":"Open","createdAtUtc":1000,"finalDueAtUtc":5000,"updatedAtUtc":1,"widgetPinned":true,"milestones":[
                {"title":"Done node","completedAtUtc":123},
                {"title":" ","dueAtUtc":2000}
            ]}
        ]}"""
        val parsed = NextDdlWidgetSnapshot.parse(raw)
        check(parsed.tasks.size == 1)
        check(parsed.tasks.single().nodes.size == 1)
        check(parsed.select(now)?.targetTitle(now) == "Open")
        check(parsed.tasks.single().pinned)
        check(parsed.tasks.single().created == 1000L)
        check(parsed.tasks.single().remainingProgress(3000) == 50)
        val legacy = NextDdlWidgetSnapshot.parse(raw.replace(",\"widgetPinned\":true", ""))
        check(!legacy.tasks.single().pinned)
        val roundTrip = NextDdlWidgetSnapshot.parse(org.json.JSONObject(raw).toString())
        check(roundTrip.pinnedTaskId() == "open")
        check(roundTrip.nextAfter(now, null)?.id == "open")
        check(parsed.locale == "ja" && parsed.timezoneId == "Asia/Tokyo")
        check(runCatching { NextDdlWidgetSnapshot.parse("{}") }.isFailure)
        check(runCatching { NextDdlWidgetSnapshot.parse(raw.replace("\"schemaVersion\":1", "\"schemaVersion\":2")) }.isFailure)
        println("Widget selection, stars, cycling and parsing: $assertions assertions passed")
    }
}
