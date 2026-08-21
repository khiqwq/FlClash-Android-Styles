package com.follow.clash.liquid

import org.junit.Assert.assertEquals
import org.junit.Test

class LiquidBottomBarGeometryTest {
    private val totalWidth = 272f
    private val padding = 4f
    private val tabWidth = 88f
    private val panelOffset = 3f

    @Test
    fun ltrAndRtlIndicatorPositionsMirrorWithoutDoubleOffset() {
        for (value in listOf(0f, 1f, 2f)) {
            val ltr = LiquidBottomBarGeometry.indicatorPhysicalLeft(
                totalWidth,
                padding,
                tabWidth,
                value,
                panelOffset,
                true,
            )
            val rtl = LiquidBottomBarGeometry.indicatorPhysicalLeft(
                totalWidth,
                padding,
                tabWidth,
                value,
                panelOffset,
                false,
            )
            assertEquals(
                totalWidth - tabWidth - ltr + panelOffset * 2,
                rtl,
                0.001f,
            )
        }
    }

    @Test
    fun highlightCenterMatchesIndicatorCenterInBothDirections() {
        for (isLtr in listOf(true, false)) {
            for (value in listOf(0f, 1f, 2f)) {
                val left = LiquidBottomBarGeometry.indicatorPhysicalLeft(
                    totalWidth,
                    padding,
                    tabWidth,
                    value,
                    panelOffset,
                    isLtr,
                )
                val center = LiquidBottomBarGeometry.indicatorCenter(
                    totalWidth - padding * 2,
                    tabWidth,
                    value,
                    panelOffset,
                    isLtr,
                ) + padding
                assertEquals(left + tabWidth / 2f, center, 0.001f)
            }
        }
    }

    @Test
    fun panelOffsetIsAppliedExactlyOnce() {
        for (isLtr in listOf(true, false)) {
            val withoutOffset = LiquidBottomBarGeometry.indicatorPhysicalLeft(
                totalWidth,
                padding,
                tabWidth,
                1f,
                0f,
                isLtr,
            )
            val withOffset = LiquidBottomBarGeometry.indicatorPhysicalLeft(
                totalWidth,
                padding,
                tabWidth,
                1f,
                panelOffset,
                isLtr,
            )
            assertEquals(panelOffset, withOffset - withoutOffset, 0.001f)
        }
    }
}
