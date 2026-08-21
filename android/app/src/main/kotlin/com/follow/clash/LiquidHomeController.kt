package com.follow.clash

import android.graphics.Bitmap
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.graphics.ImageBitmap
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal data class LiquidSnapshot(
    val bitmap: Bitmap,
    val image: ImageBitmap,
)

internal data class LiquidNavigationState(
    val visible: Boolean = false,
    val labels: List<String> = emptyList(),
    val pageKeys: List<String> = emptyList(),
    val selectedIndex: Int = 0,
    val liquidGlass: Boolean = false,
    val dark: Boolean = false,
    val rtl: Boolean = false,
)

internal object LiquidCapturePolicy {
    fun shouldSchedule(
        hostStarted: Boolean,
        visible: Boolean,
        liquidGlass: Boolean,
        dragging: Boolean,
    ): Boolean {
        return hostStarted && visible && liquidGlass && !dragging
    }

    fun shouldCapture(
        hostStarted: Boolean,
        visible: Boolean,
        liquidGlass: Boolean,
        dragging: Boolean,
        capturePending: Boolean,
        width: Int,
        height: Int,
    ): Boolean {
        return shouldSchedule(hostStarted, visible, liquidGlass, dragging) &&
            !capturePending &&
            width > 0 &&
            height > 0
    }
}

internal object LiquidHomeController {
    val navigation = mutableStateOf(LiquidNavigationState())
    val snapshot = mutableStateOf<LiquidSnapshot?>(null)
    val dragging = mutableStateOf(false)

    private var channel: MethodChannel? = null
    private var captureStateListener: (() -> Unit)? = null

    fun attach(messenger: BinaryMessenger) {
        channel?.setMethodCallHandler(null)
        channel = MethodChannel(messenger, "com.follow.clash/liquid_navigation").apply {
            setMethodCallHandler(::onMethodCall)
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        captureStateListener = null
        navigation.value = LiquidNavigationState()
        snapshot.value = null
        dragging.value = false
    }

    fun setCaptureStateListener(listener: (() -> Unit)?) {
        captureStateListener = listener
        listener?.invoke()
    }

    fun select(index: Int) {
        val state = navigation.value
        if (index !in state.labels.indices) {
            return
        }
        updateNavigation(state.copy(selectedIndex = index))
        channel?.invokeMethod("onSelected", index)
    }

    fun setDragging(value: Boolean) {
        if (dragging.value == value) {
            return
        }
        dragging.value = value
        captureStateListener?.invoke()
    }

    fun updateSnapshot(bitmap: Bitmap, image: ImageBitmap) {
        snapshot.value = LiquidSnapshot(bitmap, image)
    }

    fun clearSnapshot() {
        snapshot.value = null
    }

    private fun updateNavigation(state: LiquidNavigationState) {
        navigation.value = state
        if (!state.visible || !state.liquidGlass) {
            snapshot.value = null
            dragging.value = false
        }
        captureStateListener?.invoke()
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "update" -> {
                val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                val labels = (arguments["labels"] as? List<*>)
                    ?.map { it.toString() }
                    .orEmpty()
                val pageKeys = (arguments["pageKeys"] as? List<*>)
                    ?.map { it.toString() }
                    .orEmpty()
                val requestedIndex = (arguments["selectedIndex"] as? Number)?.toInt() ?: 0
                val selectedIndex = if (labels.isEmpty()) {
                    0
                } else {
                    requestedIndex.coerceIn(0, labels.lastIndex)
                }
                updateNavigation(
                    LiquidNavigationState(
                        visible = arguments["visible"] as? Boolean ?: false,
                        labels = labels,
                        pageKeys = pageKeys,
                        selectedIndex = selectedIndex,
                        liquidGlass = arguments["liquidGlass"] as? Boolean ?: false,
                        dark = arguments["dark"] as? Boolean ?: false,
                        rtl = arguments["rtl"] as? Boolean ?: false,
                    ),
                )
                result.success(null)
            }
            "hide" -> {
                updateNavigation(navigation.value.copy(visible = false))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
