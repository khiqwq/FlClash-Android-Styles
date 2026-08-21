package com.follow.clash

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.Gravity
import android.view.PixelCopy
import android.view.Surface
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.follow.clash.plugins.AppPlugin
import com.follow.clash.plugins.ServicePlugin
import com.follow.clash.plugins.TilePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private companion object {
        const val LIQUID_STATE_KEY = "liquid-compose-state"
        const val CAPTURE_INTERVAL_MILLIS = 100L
        const val CAPTURE_HEIGHT_DP = 128
        const val CAPTURE_BUFFER_COUNT = 3
    }

    private lateinit var liquidOverlay: ComposeView
    private lateinit var liquidTreeOwner: LiquidComposeTreeOwner
    private lateinit var pixelCopyThread: HandlerThread
    private lateinit var pixelCopyHandler: Handler
    private val mainHandler = Handler(Looper.getMainLooper())
    private val captureBuffers = LiquidBackdropBufferPool(CAPTURE_BUFFER_COUNT)
    private var textureView: FlutterTextureView? = null
    private var textureSurface: Surface? = null
    private var capturePending = false
    private var hostStarted = false
    private var destroyed = false
    private var captureRequestId = 0L
    private var inFlightBitmap: Bitmap? = null
    private var publishedBitmap: Bitmap? = null
    private val captureRunnable = Runnable(::captureFlutterBackdrop)

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun getTransparencyMode(): TransparencyMode = TransparencyMode.opaque

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pixelCopyThread = HandlerThread("liquid-backdrop-pixel-copy").apply { start() }
        pixelCopyHandler = Handler(pixelCopyThread.looper)
        val root = findViewById<ViewGroup>(android.R.id.content)
        root.setBackgroundColor(Color.TRANSPARENT)
        liquidTreeOwner = LiquidComposeTreeOwner(
            host = this,
            restoredState = savedInstanceState?.getBundle(LIQUID_STATE_KEY),
        )
        liquidOverlay = ComposeView(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
            setViewCompositionStrategy(
                ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed,
            )
            setContent {
                LiquidHomeOverlay()
            }
        }
        liquidOverlay.setViewTreeLifecycleOwner(liquidTreeOwner)
        liquidOverlay.setViewTreeSavedStateRegistryOwner(liquidTreeOwner)
        liquidOverlay.setViewTreeViewModelStoreOwner(liquidTreeOwner)
        root.addView(
            liquidOverlay,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (CAPTURE_HEIGHT_DP * resources.displayMetrics.density).toInt(),
                Gravity.BOTTOM,
            ),
        )
        LiquidHomeController.setCaptureStateListener(::refreshCaptureScheduling)
    }

    override fun onStart() {
        super.onStart()
        hostStarted = true
        refreshCaptureScheduling()
    }

    override fun onStop() {
        hostStarted = false
        if (::liquidOverlay.isInitialized) {
            liquidOverlay.removeCallbacks(captureRunnable)
        }
        super.onStop()
    }

    override fun onFlutterTextureViewCreated(flutterTextureView: FlutterTextureView) {
        super.onFlutterTextureViewCreated(flutterTextureView)
        textureView = flutterTextureView
        textureSurface?.release()
        textureSurface = flutterTextureView.surfaceTexture?.let(::Surface)
        refreshCaptureScheduling()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        LiquidHomeController.attach(flutterEngine.dartExecutor.binaryMessenger)
        ServiceState.attachFlutterEngine(flutterEngine)
    }

    private fun refreshCaptureScheduling() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(::refreshCaptureScheduling)
            return
        }
        if (!::liquidOverlay.isInitialized || destroyed) {
            return
        }
        liquidOverlay.removeCallbacks(captureRunnable)
        val state = LiquidHomeController.navigation.value
        if (!state.visible || !state.liquidGlass) {
            publishedBitmap = null
            LiquidHomeController.clearSnapshot()
        }
        if (
            LiquidCapturePolicy.shouldSchedule(
                hostStarted = hostStarted,
                visible = state.visible,
                liquidGlass = state.liquidGlass,
                dragging = LiquidHomeController.dragging.value,
            )
        ) {
            liquidOverlay.post(captureRunnable)
        }
    }

    private fun scheduleNextCapture() {
        if (!::liquidOverlay.isInitialized || destroyed) {
            return
        }
        liquidOverlay.removeCallbacks(captureRunnable)
        val state = LiquidHomeController.navigation.value
        if (
            LiquidCapturePolicy.shouldSchedule(
                hostStarted = hostStarted,
                visible = state.visible,
                liquidGlass = state.liquidGlass,
                dragging = LiquidHomeController.dragging.value,
            )
        ) {
            liquidOverlay.postDelayed(captureRunnable, CAPTURE_INTERVAL_MILLIS)
        }
    }

    private fun captureFlutterBackdrop() {
        val state = LiquidHomeController.navigation.value
        val source = textureView
        val surface = textureSurface
        val width = source?.width ?: 0
        val height = source?.height ?: 0
        if (
            source == null ||
            surface == null ||
            !LiquidCapturePolicy.shouldCapture(
                hostStarted = hostStarted,
                visible = state.visible,
                liquidGlass = state.liquidGlass,
                dragging = LiquidHomeController.dragging.value,
                capturePending = capturePending,
                width = width,
                height = height,
            )
        ) {
            scheduleNextCapture()
            return
        }
        val captureHeight = (CAPTURE_HEIGHT_DP * resources.displayMetrics.density)
            .toInt()
            .coerceAtMost(height)
        val bitmap = captureBuffers.acquire(
            width = width,
            height = captureHeight,
            published = publishedBitmap,
            inFlight = inFlightBitmap,
        ) ?: run {
            scheduleNextCapture()
            return
        }
        capturePending = true
        inFlightBitmap = bitmap
        val requestId = ++captureRequestId
        try {
            PixelCopy.request(
                surface,
                Rect(0, height - captureHeight, width, height),
                bitmap,
                { result: Int ->
                    val image = if (result == PixelCopy.SUCCESS) {
                        bitmap.asImageBitmap()
                    } else {
                        null
                    }
                    mainHandler.post {
                        completeCapture(requestId, bitmap, image, result)
                    }
                },
                pixelCopyHandler,
            )
        } catch (_: IllegalArgumentException) {
            completeCapture(requestId, bitmap, null, PixelCopy.ERROR_SOURCE_INVALID)
        }
    }

    private fun completeCapture(
        requestId: Long,
        bitmap: Bitmap,
        image: ImageBitmap?,
        result: Int,
    ) {
        if (requestId != captureRequestId || bitmap !== inFlightBitmap) {
            return
        }
        capturePending = false
        inFlightBitmap = null
        if (destroyed) {
            if (!bitmap.isRecycled) {
                bitmap.recycle()
            }
            return
        }
        val state = LiquidHomeController.navigation.value
        if (
            result == PixelCopy.SUCCESS &&
            image != null &&
            LiquidCapturePolicy.shouldSchedule(
                hostStarted = hostStarted,
                visible = state.visible,
                liquidGlass = state.liquidGlass,
                dragging = LiquidHomeController.dragging.value,
            )
        ) {
            publishedBitmap = bitmap
            LiquidHomeController.updateSnapshot(bitmap, image)
        }
        scheduleNextCapture()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        if (::liquidTreeOwner.isInitialized) {
            val liquidState = Bundle()
            liquidTreeOwner.save(liquidState)
            outState.putBundle(LIQUID_STATE_KEY, liquidState)
        }
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        destroyed = true
        hostStarted = false
        LiquidHomeController.setCaptureStateListener(null)
        if (::liquidOverlay.isInitialized) {
            liquidOverlay.removeCallbacks(captureRunnable)
            liquidOverlay.disposeComposition()
        }
        textureSurface?.release()
        textureSurface = null
        textureView = null
        LiquidHomeController.detach()
        captureBuffers.recycleAll(except = inFlightBitmap)
        publishedBitmap = null
        if (::pixelCopyThread.isInitialized) {
            pixelCopyThread.quitSafely()
        }
        if (::liquidTreeOwner.isInitialized) {
            liquidTreeOwner.clear()
        }
        flutterEngine?.let(ServiceState::detachFlutterEngine)
        super.onDestroy()
    }
}

private class LiquidBackdropBufferPool(bufferCount: Int) {
    private val buffers = arrayOfNulls<Bitmap>(bufferCount)
    private var nextIndex = 0

    fun acquire(
        width: Int,
        height: Int,
        published: Bitmap?,
        inFlight: Bitmap?,
    ): Bitmap? {
        repeat(buffers.size) {
            val index = (nextIndex + it) % buffers.size
            var bitmap = buffers[index]
            if (bitmap === published || bitmap === inFlight) {
                return@repeat
            }
            if (
                bitmap == null ||
                bitmap.isRecycled ||
                bitmap.width != width ||
                bitmap.height != height
            ) {
                if (bitmap != null && !bitmap.isRecycled) {
                    bitmap.recycle()
                }
                bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                buffers[index] = bitmap
            }
            nextIndex = (index + 1) % buffers.size
            return bitmap
        }
        return null
    }

    fun recycleAll(except: Bitmap?) {
        buffers.forEachIndexed { index, bitmap ->
            if (bitmap != null && bitmap !== except && !bitmap.isRecycled) {
                bitmap.recycle()
            }
            if (bitmap !== except) {
                buffers[index] = null
            }
        }
    }
}
