package com.mtytm.nextddl.next_ddl

import org.json.JSONObject

internal data class WidgetNode(val title: String, val due: Long)
internal data class WidgetTask(
    val id: String,
    val title: String,
    val finalDue: Long,
    val updated: Long,
    val nodes: List<WidgetNode>,
) {
    fun next(now: Long): WidgetNode? = nodes.filter { it.due >= now }.minByOrNull { it.due }
    fun activeDue(now: Long): Long = next(now)?.due ?: finalDue
    fun targetTitle(now: Long): String = next(now)?.title?.trim()?.takeIf { it.isNotEmpty() } ?: title.trim()
}

internal data class NextDdlWidgetSnapshot(
    val locale: String = "system",
    val timezoneId: String = "UTC",
    val tasks: List<WidgetTask> = emptyList(),
) {
    // Match deadline_logic.dart: future tasks first, updated descending on ties.
    // Only when none remain do we show the earliest overdue final deadline.
    fun select(now: Long): WidgetTask? {
        val future = tasks.filter { it.finalDue >= now }
        return if (future.isNotEmpty()) future.sortedWith(
            compareBy<WidgetTask> { it.activeDue(now) }.thenByDescending { it.updated }.thenBy { it.id },
        ).first() else tasks.sortedWith(
            compareBy<WidgetTask> { it.finalDue }.thenByDescending { it.updated }.thenBy { it.id },
        ).firstOrNull()
    }

    companion object {
        fun parse(raw: String): NextDdlWidgetSnapshot {
            val root = JSONObject(raw)
            require(root.getInt("schemaVersion") == 1) { "Unsupported widget schema" }
            val array = root.getJSONArray("tasks")
            val tasks = (0 until array.length()).mapNotNull { index ->
                val task = array.getJSONObject(index)
                if (!task.isNull("completedAtUtc")) return@mapNotNull null
                val nodes = task.getJSONArray("milestones")
                WidgetTask(
                    task.getString("id").also { require(it.isNotBlank()) },
                    task.getString("title"), task.getLong("finalDueAtUtc"), task.getLong("updatedAtUtc"),
                    (0 until nodes.length()).mapNotNull { nodeIndex ->
                        val node = nodes.getJSONObject(nodeIndex)
                        if (!node.isNull("completedAtUtc")) null
                        else WidgetNode(node.getString("title"), node.getLong("dueAtUtc"))
                    },
                )
            }
            return NextDdlWidgetSnapshot(root.optString("locale", "system"), root.optString("timezoneId", "UTC"), tasks)
        }
    }
}
