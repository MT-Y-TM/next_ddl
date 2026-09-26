package com.mtytm.nextddl.next_ddl

/** Standalone JVM contract tests; no Android runtime or JUnit dependency needed. */
object NextDdlWidgetSelectionTest {
    @JvmStatic
    fun main(args: Array<String>) {
        val now = 1000L
        val first = WidgetTask("first", "Task", 5000, 10, listOf(
            WidgetNode("past", 999), WidgetNode("  ", 1000), WidgetNode("future", 2000),
        ))
        check(first.next(now)?.due == 1000L)
        check(first.targetTitle(now) == "Task")
        check(first.next(1001)?.title == "future")
        check(first.activeDue(2001) == 5000L)
        check(first.targetTitle(2001) == "Task")
        check(NextDdlWidgetSnapshot().select(now) == null)
        val overdue = WidgetTask("overdue", "Old", 900, 20, emptyList())
        check(NextDdlWidgetSnapshot(tasks = listOf(overdue, first)).select(now) == first)
        check(NextDdlWidgetSnapshot(tasks = listOf(overdue, first)).select(6000) == overdue)
        val second = WidgetTask("second", "Second", 8000, 30, listOf(WidgetNode("soon", 1500)))
        val snapshot = NextDdlWidgetSnapshot(tasks = listOf(first, second))
        check(snapshot.select(now) == first)
        check(snapshot.select(1001) == second)
        check(snapshot.select(1501) == first)
        val tied = first.copy(id = "newer", updated = 11)
        check(NextDdlWidgetSnapshot(tasks = listOf(first, tied)).select(now) == tied)
        check(NextDdlWidgetSnapshot(tasks = listOf(first)).select(5000) == first)
        val raw = """{"schemaVersion":1,"locale":"ja","timezoneId":"Asia/Tokyo","tasks":[
            {"id":"done","title":"Done","completedAtUtc":123},
            {"id":"open","title":"Open","finalDueAtUtc":5000,"updatedAtUtc":1,"milestones":[
                {"title":"Done node","completedAtUtc":123},
                {"title":" ","dueAtUtc":2000}
            ]}
        ]}"""
        val parsed = NextDdlWidgetSnapshot.parse(raw)
        check(parsed.tasks.size == 1)
        check(parsed.tasks.single().nodes.size == 1)
        check(parsed.select(now)?.targetTitle(now) == "Open")
        check(parsed.locale == "ja" && parsed.timezoneId == "Asia/Tokyo")
        check(runCatching { NextDdlWidgetSnapshot.parse("{}") }.isFailure)
        check(runCatching { NextDdlWidgetSnapshot.parse(raw.replace("\"schemaVersion\":1", "\"schemaVersion\":2")) }.isFailure)
        println("Widget selection and parsing: 19 assertions passed")
    }
}
