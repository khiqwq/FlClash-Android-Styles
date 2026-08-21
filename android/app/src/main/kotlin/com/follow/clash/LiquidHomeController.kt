package com.follow.clash

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
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

internal object LiquidHomeController {
    val navigation = mutableStateOf(LiquidNavigationState())
    val snapshot = mutableStateOf<LiquidSnapshot?>(null)
    val dragging = mutableStateOf(false)
    val mainHandler = Handler(Looper.getMainLooper())

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel?.setMethodCallHandler(null)
        channel = MethodChannel(messenger, "com.follow.clash/liquid_navigation").apply {
            setMethodCallHandler(::onMethodCall)
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        navigation.value = LiquidNavigationState()
        snapshot.value?.bitmap?.takeUnless(Bitmap::isRecycled)?.recycle()
        snapshot.value = null
        dragging.value = false
    }

    fun select(index: Int) {
        val state = navigation.value
        if (index !in state.labels.indices) {
            return
        }
        navigation.value = state.copy(selectedIndex = index)
        channel?.invokeMethod("onSelected", index)
    }

    fun updateSnapshot(bitmap: Bitmap, image: ImageBitmap) {
        val previous = snapshot.value
        snapshot.value = LiquidSnapshot(bitmap, image)
        if (previous != null) {
            mainHandler.postDelayed(
                { if (!previous.bitmap.isRecycled) previous.bitmap.recycle() },
                500L,
            )
        }
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
                navigation.value = LiquidNavigationState(
                    visible = arguments["visible"] as? Boolean ?: false,
                    labels = labels,
                    pageKeys = pageKeys,
                    selectedIndex = selectedIndex,
                    liquidGlass = arguments["liquidGlass"] as? Boolean ?: false,
                    dark = arguments["dark"] as? Boolean ?: false,
                    rtl = arguments["rtl"] as? Boolean ?: false,
                )
                result.success(null)
            }
            "hide" -> {
                navigation.value = navigation.value.copy(visible = false)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
