package com.mtytm.nextddl.next_ddl

import kotlin.math.max
import kotlin.math.min

internal data class WidgetSize(val width: Float, val height: Float) {
    val valid: Boolean get() = width.isFinite() && height.isFinite() && width > 0 && height > 0
}

internal data class WidgetLayoutPlan(
    val size: WidgetSize,
    val horizontal: Boolean,
    val padding: Int,
    val headerPadding: Int,
    val gap: Int,
    val titleSp: Float,
    val countdownSp: Float,
    val labelSp: Float,
    val showOverview: Boolean,
    val showRemainingLabel: Boolean,
    val showDate: Boolean,
    val showClock: Boolean,
)

/** Size calculations stay independent of Android so launcher edge cases are testable. */
internal object NextDdlWidgetLayout {
    const val MIN_WIDTH = 180f
    const val MIN_HEIGHT = 110f

    fun fallbackSizes(
        screen: WidgetSize,
        minWidth: Float = 0f,
        minHeight: Float = 0f,
        maxWidth: Float = 0f,
        maxHeight: Float = 0f,
    ): Pair<WidgetSize, WidgetSize> {
        val shortSide = if (screen.valid) min(screen.width, screen.height) else 360f
        val longSide = if (screen.valid) max(screen.width, screen.height) else 640f
        fun dimension(value: Float, fallback: Float) = if (value.isFinite() && value > 0) value else fallback
        val portraitWidth = dimension(minWidth, (shortSide - 32f) * 0.6f)
        val landscapeHeight = dimension(minHeight, MIN_HEIGHT)
        val portrait = WidgetSize(portraitWidth, dimension(maxHeight, max(landscapeHeight, MIN_HEIGHT)))
        val landscape = WidgetSize(dimension(maxWidth, max(portraitWidth, (longSide - 32f) * 0.6f)), landscapeHeight)
        return portrait to landscape
    }

    fun plan(size: WidgetSize, screen: WidgetSize, fontScale: Float = 1f): WidgetLayoutPlan {
        val available = if (size.valid) size else fallbackSizes(screen).first
        val scale = if (fontScale.isFinite() && fontScale > 0) fontScale.coerceIn(0.8f, 3f) else 1f
        val padding = (min(available.width, available.height) * 0.055f).toInt().coerceIn(4, 18)
        val headerPadding = ((available.height - 110f) * 0.035f).toInt().coerceIn(0, 12)
        val bodyHeight = available.height - 48f - 2 * headerPadding - 2 * padding
        val horizontal = available.width >= 380f && available.width / available.height >= 1.65f &&
            available.width >= 340f * scale
        val gap = if (horizontal) padding else (bodyHeight * 0.055f).toInt().coerceIn(2, 14)
        val roomy = bodyHeight >= 185f * scale
        val labelSp = if (roomy) 16f else 12f
        val countdownSp = (if (horizontal) available.width * 0.045f else available.width * 0.095f)
            .coerceIn(17f, 30f)
        // Budget real line heights before adding optional information. Essential
        // title/countdown/switch controls are never traded for decorative content.
        val deadlineHeight = (labelSp + countdownSp) * 1.3f * scale
        val dateHeight = 14f * 1.3f * scale
        val overviewHeight = (labelSp * 1.3f + 8f) * scale + 6f
        val showDate = bodyHeight >= deadlineHeight + dateHeight + gap
        val usedDeadlineHeight = deadlineHeight + if (showDate) dateHeight + gap else 0f
        val showOverview = if (horizontal) bodyHeight >= max(usedDeadlineHeight, overviewHeight)
            else bodyHeight >= usedDeadlineHeight + overviewHeight + gap
        val showRemainingLabel = showOverview &&
            (if (horizontal) bodyHeight - overviewHeight else bodyHeight - usedDeadlineHeight - overviewHeight - gap) >= 22f * scale
        return WidgetLayoutPlan(
            available, horizontal, padding, headerPadding, gap,
            titleSp = (available.width * 0.07f).coerceIn(17f, 26f),
            countdownSp = countdownSp,
            labelSp = labelSp,
            showOverview = showOverview,
            showRemainingLabel = showRemainingLabel,
            showDate = showDate,
            showClock = !horizontal && available.width >= 260f && bodyHeight >= 125f * scale,
        )
    }
}
