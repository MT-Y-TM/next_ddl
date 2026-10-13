package com.mtytm.nextddl.next_ddl

object NextDdlWidgetLayoutTest {
    @JvmStatic
    fun main(args: Array<String>) {
        var assertions = 0
        fun check(value: Boolean) { kotlin.check(value); assertions++ }
        val phone = WidgetSize(360f, 800f)
        val compact = NextDdlWidgetLayout.plan(WidgetSize(180f, 110f), phone)
        check(!compact.horizontal && !compact.showOverview && !compact.showDate && !compact.showClock)
        check(compact.headerPadding == 0 && compact.padding <= 6)
        val tall = NextDdlWidgetLayout.plan(WidgetSize(320f, 360f), phone)
        check(!tall.horizontal && tall.showOverview && tall.showDate && tall.showClock)
        check(tall.showRemainingLabel)
        check(tall.titleSp > compact.titleSp && tall.countdownSp > compact.countdownSp)
        val wide = NextDdlWidgetLayout.plan(WidgetSize(600f, 180f), phone)
        check(wide.horizontal && wide.showOverview && wide.showDate && !wide.showClock)
        check(!NextDdlWidgetLayout.plan(WidgetSize(300f, 180f), phone).horizontal)
        check(!NextDdlWidgetLayout.plan(WidgetSize(600f, 180f), phone, 2f).horizontal)
        val enlarged = NextDdlWidgetLayout.plan(WidgetSize(203f, 220f), phone, 1.8f)
        check(!enlarged.showOverview && !enlarged.showRemainingLabel)
        val (portrait, landscape) = NextDdlWidgetLayout.fallbackSizes(phone, 203f, 117f, 412f, 220f)
        check(portrait == WidgetSize(203f, 220f))
        check(landscape == WidgetSize(412f, 117f))
        check(NextDdlWidgetLayout.fallbackSizes(WidgetSize(800f, 360f), 203f, 117f, 412f, 220f) == (portrait to landscape))
        val (tabletPortrait, tabletLandscape) = NextDdlWidgetLayout.fallbackSizes(WidgetSize(800f, 1280f))
        val (phonePortrait, phoneLandscape) = NextDdlWidgetLayout.fallbackSizes(phone)
        check(tabletPortrait.width > phonePortrait.width && tabletLandscape.width > phoneLandscape.width)
        val (invalidPortrait, invalidLandscape) = NextDdlWidgetLayout.fallbackSizes(
            WidgetSize(Float.NaN, -1f), Float.NaN, -1f, 0f, Float.POSITIVE_INFINITY)
        check(invalidPortrait.valid && invalidLandscape.valid)
        check(NextDdlWidgetLayout.plan(WidgetSize(0f, 0f), phone).size.valid)
        for (width in listOf(180f, 203f, 280f, 412f, 600f, 800f)) {
            for (height in listOf(110f, 117f, 220f, 360f, 600f)) {
                for (scale in listOf(1f, 1.3f, 1.8f, 3f, Float.NaN)) {
                    val plan = NextDdlWidgetLayout.plan(WidgetSize(width, height), phone, scale)
                    check(plan.titleSp in 17f..26f && plan.countdownSp in 17f..30f)
                    check(plan.padding in 4..18 && plan.headerPadding in 0..12)
                    check(!plan.showRemainingLabel || plan.showOverview)
                    check(!plan.horizontal || !plan.showClock)
                }
            }
        }
        println("Widget responsive sizing and orientation fallbacks: $assertions assertions passed")
    }
}
