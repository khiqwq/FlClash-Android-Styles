package com.follow.clash.liquid

internal object LiquidBottomBarGeometry {
    fun directionMultiplier(isLtr: Boolean): Float = if (isLtr) 1f else -1f

    fun indicatorTranslation(
        value: Float,
        tabWidth: Float,
        panelOffset: Float,
        isLtr: Boolean,
    ): Float = value * tabWidth * directionMultiplier(isLtr) + panelOffset

    fun indicatorPhysicalLeft(
        totalWidth: Float,
        padding: Float,
        tabWidth: Float,
        value: Float,
        panelOffset: Float,
        isLtr: Boolean,
    ): Float {
        val startLeft = if (isLtr) padding else totalWidth - padding - tabWidth
        return startLeft + indicatorTranslation(value, tabWidth, panelOffset, isLtr)
    }

    fun indicatorCenter(
        totalWidth: Float,
        tabWidth: Float,
        value: Float,
        panelOffset: Float,
        isLtr: Boolean,
    ): Float {
        return if (isLtr) {
            (value + 0.5f) * tabWidth + panelOffset
        } else {
            totalWidth - (value + 0.5f) * tabWidth + panelOffset
        }
    }
}
