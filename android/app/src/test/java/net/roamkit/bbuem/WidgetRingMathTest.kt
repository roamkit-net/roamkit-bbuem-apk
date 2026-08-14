package net.roamkit.bbuem

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetRingMathTest {
    @Test
    fun limeSweepIsNinetyFourPercentOfCircle() {
        assertEquals(338.4f, WidgetRingMath.limeSweepDegrees(94), 0.01f)
        assertEquals(21.6f, WidgetRingMath.usedSweepDegrees(94), 0.01f)
    }

    @Test
    fun percentIsClamped() {
        assertEquals(0, WidgetRingMath.clampPercent(-4))
        assertEquals(100, WidgetRingMath.clampPercent(140))
    }

    @Test
    fun rootRouteMatchesLockedTable() {
        assertEquals("home", WidgetSnapshotParser.rootRoute("active"))
        assertEquals("packages", WidgetSnapshotParser.rootRoute("inactive"))
        assertEquals("packages", WidgetSnapshotParser.rootRoute("expired"))
        assertEquals("refresh", WidgetSnapshotParser.rootRoute("unavailable"))
        assertEquals("home", WidgetSnapshotParser.rootRoute("nope"))
    }

    @Test
    fun corruptJsonIsFailSafeUnavailable() {
        val snap = WidgetSnapshotParser.parseOrFailSafe("{not-json")
        assertEquals("unavailable", snap.displayStatus)
        assertEquals(false, snap.hasUsage)
    }

    @Test
    fun v1SchemaIsFailSafe() {
        val snap =
            WidgetSnapshotParser.parseOrFailSafe(
                """{"schema":1,"surface":"green","hero":"ACTIVE"}""",
            )
        assertEquals("unavailable", snap.displayStatus)
    }

    @Test
    fun v2ActiveParsesUsage() {
        val snap =
            WidgetSnapshotParser.parseOrFailSafe(
                """
                {
                  "schema_version": 2,
                  "display_status": "active",
                  "status_label": "ACTIVE",
                  "active_package_title": "Top-up · 1 GB · 7 days",
                  "has_usage": true,
                  "remaining_text": "1.88 GB",
                  "total_text": "2 GB",
                  "used_text": "122 MB",
                  "percent": 94,
                  "unlimited": false,
                  "coverage_available": true,
                  "update_unavailable": false
                }
                """.trimIndent(),
            )
        assertEquals("active", snap.displayStatus)
        assertEquals(94, snap.percent)
        assertEquals("Top-up · 1 GB · 7 days", snap.activePackageTitle)
        assertEquals(
            "✓ ACTIVE",
            WidgetSnapshotParser.statusBadge(snap.displayStatus, snap.statusLabel),
        )
    }
}
