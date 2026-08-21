package com.follow.clash

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LiquidCapturePolicyTest {
    @Test
    fun schedulesOnlyForVisibleGlassWhileStartedAndNotDragging() {
        assertTrue(
            LiquidCapturePolicy.shouldSchedule(
                hostStarted = true,
                visible = true,
                liquidGlass = true,
                dragging = false,
            ),
        )
        assertFalse(
            LiquidCapturePolicy.shouldSchedule(
                hostStarted = true,
                visible = false,
                liquidGlass = true,
                dragging = false,
            ),
        )
        assertFalse(
            LiquidCapturePolicy.shouldSchedule(
                hostStarted = true,
                visible = true,
                liquidGlass = false,
                dragging = false,
            ),
        )
        assertFalse(
            LiquidCapturePolicy.shouldSchedule(
                hostStarted = true,
                visible = true,
                liquidGlass = true,
                dragging = true,
            ),
        )
        assertFalse(
            LiquidCapturePolicy.shouldSchedule(
                hostStarted = false,
                visible = true,
                liquidGlass = true,
                dragging = false,
            ),
        )
    }

    @Test
    fun captureRequiresIdleRequestAndPositiveSurfaceSize() {
        assertTrue(
            LiquidCapturePolicy.shouldCapture(
                hostStarted = true,
                visible = true,
                liquidGlass = true,
                dragging = false,
                capturePending = false,
                width = 1080,
                height = 2400,
            ),
        )
        assertFalse(
            LiquidCapturePolicy.shouldCapture(
                hostStarted = true,
                visible = true,
                liquidGlass = true,
                dragging = false,
                capturePending = true,
                width = 1080,
                height = 2400,
            ),
        )
        assertFalse(
            LiquidCapturePolicy.shouldCapture(
                hostStarted = true,
                visible = true,
                liquidGlass = true,
                dragging = false,
                capturePending = false,
                width = 0,
                height = 2400,
            ),
        )
        assertFalse(
            LiquidCapturePolicy.shouldCapture(
                hostStarted = true,
                visible = true,
                liquidGlass = true,
                dragging = false,
                capturePending = false,
                width = 1080,
                height = 0,
            ),
        )
    }
}
