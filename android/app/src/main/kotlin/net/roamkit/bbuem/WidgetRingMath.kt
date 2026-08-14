package net.roamkit.bbuem

/** Paint-only ring geometry. Flutter already decided remaining/total. */
object WidgetRingMath {
    fun clampPercent(percent: Int): Int = percent.coerceIn(0, 100)

    /** Lime sweep in degrees for remaining share. Full circle is 360. */
    fun limeSweepDegrees(percent: Int): Float = clampPercent(percent) * 3.6f

    fun usedSweepDegrees(percent: Int): Float = 360f - limeSweepDegrees(percent)
}
