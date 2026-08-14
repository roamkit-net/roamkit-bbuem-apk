package net.roamkit.bbuem

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import kotlin.math.min

object WidgetRingBitmap {
    private const val COLOR_LIME = 0xFFDDFB55.toInt()
    private const val COLOR_PURPLE = 0xFF7467F0.toInt()
    private const val COLOR_TRACK = 0xFF2A2F38.toInt()
    private const val MAX_PX = 256
    private const val START = -90f
    private const val GAP = 6f

    fun render(
        sizePx: Int,
        percent: Int,
        unlimited: Boolean,
    ): Bitmap {
        val edge = min(sizePx.coerceAtLeast(48), MAX_PX)
        val bitmap = Bitmap.createBitmap(edge, edge, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val stroke = edge * 0.12f
        val inset = stroke / 2f + 2f
        val oval = RectF(inset, inset, edge - inset, edge - inset)
        val track =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                strokeCap = Paint.Cap.ROUND
                color = COLOR_TRACK
            }
        canvas.drawArc(oval, 0f, 360f, false, track)
        val lime =
            Paint(track).apply {
                color = COLOR_LIME
            }
        if (unlimited) {
            canvas.drawArc(oval, START, 360f - GAP, false, lime)
            return bitmap
        }
        val limeSweep = WidgetRingMath.limeSweepDegrees(percent)
        val usedSweep = WidgetRingMath.usedSweepDegrees(percent)
        if (limeSweep > 0f) {
            canvas.drawArc(oval, START, (limeSweep - GAP).coerceAtLeast(0.1f), false, lime)
        }
        if (usedSweep > 0f) {
            val purple =
                Paint(track).apply {
                    color = COLOR_PURPLE
                }
            canvas.drawArc(
                oval,
                START + limeSweep,
                (usedSweep - GAP).coerceAtLeast(0.1f),
                false,
                purple,
            )
        }
        return bitmap
    }
}
