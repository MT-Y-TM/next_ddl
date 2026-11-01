package com.mtytm.nextddl.next_ddl

import org.json.JSONObject

internal data class WidgetNode(val title: String, val due: Long)
internal data class WidgetTask(
    val id: String,
    val title: String,
    val finalDue: Long,
    val updated: Long,
    val nodes: List<WidgetNode>,
    val created: Long = 0L,
    val pinned: Boolean = false,
    val completed: Boolean = false,
    val tags: List<String> = emptyList(),
) {
    fun next(now: Long): WidgetNode? = nodes.filter { it.due >= now }.minByOrNull { it.due }
    fun activeDue(now: Long): Long = next(now)?.due ?: finalDue
    fun targetTitle(now: Long): String = next(now)?.title?.trim()?.takeIf { it.isNotEmpty() } ?: title.trim()

    fun remainingProgress(now: Long): Int {
        val total = finalDue - created
        if (total <= 0L) return if (finalDue >= now) 100 else 0
        return (((finalDue - now).toDouble() / total) * 100.0)
            .coerceIn(0.0, 100.0)
            .toInt()
    }
}

internal data class NextDdlWidgetSnapshot(
    val locale: String = "system",
    val timezoneId: String = "UTC",
    val tasks: List<WidgetTask> = emptyList(),
) {
    fun selectableTasks(now: Long, category: String = CATEGORY_ALL): List<WidgetTask> {
        val candidates = when {
            category == CATEGORY_COMPLETED -> tasks.filter { it.completed }
            category == CATEGORY_OVERDUE -> tasks.filter { !it.completed && it.finalDue < now }
            category == CATEGORY_IMPORTANT -> tasks.filter { !it.completed && it.pinned }
            category == CATEGORY_ALL -> tasks.filterNot { it.completed }
            category.startsWith(CATEGORY_TAG_PREFIX) -> {
                val tag = category.removePrefix(CATEGORY_TAG_PREFIX)
                tasks.filter { !it.completed && tag in it.tags }
            }
            else -> tasks.filter { !it.completed && it.finalDue >= now }
        }
        val future = candidates.filter { it.finalDue >= now }
        val upcoming = future.sortedWith(
                compareBy<WidgetTask> { it.activeDue(now) }
                    .thenByDescending { it.updated }
                    .thenBy { it.id },
            )
        val overdue = candidates.filter { it.finalDue < now }.sortedWith(
                compareBy<WidgetTask> { it.finalDue }
                    .thenByDescending { it.updated }
                    .thenBy { it.id },
            )
        return upcoming + overdue
    }

    // Imports from older snapshots may contain several stars. Choose the most
    // recently selected one deterministically; new app actions keep one star.
    fun pinnedTaskId(): String? = tasks.filter { it.pinned }
        .sortedWith(compareByDescending<WidgetTask> { it.updated }.thenBy { it.id })
        .firstOrNull()?.id

    fun resetsManualSelectionFrom(previous: NextDdlWidgetSnapshot?): Boolean =
        previous?.pinnedTaskId() != pinnedTaskId()

    // Match deadline_logic.dart: future tasks first, updated descending on ties.
    // Only when none remain do we show the earliest overdue final deadline.
    fun select(
        now: Long,
        selectedId: String? = null,
        manualSelection: Boolean = false,
    ): WidgetTask? {
        val ordered = selectableTasks(now, CATEGORY_ALL)
        if (manualSelection) {
            tasks.firstOrNull { it.id == selectedId }?.let { return it }
        }
        return tasks.firstOrNull { !it.completed && it.id == pinnedTaskId() } ?: ordered.firstOrNull()
    }

    fun nextAfter(now: Long, selectedId: String?): WidgetTask? {
        val ordered = selectableTasks(now)
        if (ordered.isEmpty()) return null
        val currentId = selectedId ?: select(now)?.id
        val index = ordered.indexOfFirst { it.id == currentId }
        return ordered[(index + 1 + ordered.size) % ordered.size]
    }

    companion object {
        const val CATEGORY_IN_PROGRESS = "in_progress"
        const val CATEGORY_OVERDUE = "overdue"
        const val CATEGORY_IMPORTANT = "important"
        const val CATEGORY_ALL = "all"
        const val CATEGORY_COMPLETED = "completed"
        const val CATEGORY_TAG_PREFIX = "tag:"

        fun parse(raw: String): NextDdlWidgetSnapshot {
            val root = JSONObject(raw)
            require(root.getInt("schemaVersion") == 1) { "Unsupported widget schema" }
            val array = root.getJSONArray("tasks")
            val tasks = (0 until array.length()).mapNotNull { index ->
                val task = array.getJSONObject(index)
                val completed = !task.isNull("completedAtUtc")
                val nodes = task.optJSONArray("milestones") ?: org.json.JSONArray()
                WidgetTask(
                    task.getString("id").also { require(it.isNotBlank()) },
                    task.getString("title"), task.optLong("finalDueAtUtc", 0L), task.optLong("updatedAtUtc", 0L),
                    (0 until nodes.length()).mapNotNull { nodeIndex ->
                        val node = nodes.getJSONObject(nodeIndex)
                        if (!node.isNull("completedAtUtc")) null
                        else WidgetNode(node.getString("title"), node.getLong("dueAtUtc"))
                    },
                    task.optLong("createdAtUtc", task.optLong("updatedAtUtc", 0L)),
                    task.optBoolean("widgetPinned", false),
                    completed,
                    task.optJSONArray("tags")?.let { tags ->
                        (0 until tags.length()).mapNotNull { tags.optString(it).takeIf(String::isNotBlank) }
                    } ?: emptyList(),
                )
            }
            return NextDdlWidgetSnapshot(root.optString("locale", "system"), root.optString("timezoneId", "UTC"), tasks)
        }
    }
}
