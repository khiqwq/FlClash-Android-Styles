package com.follow.clash

import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Bundle
import android.view.Gravity
import android.view.PixelCopy
import android.view.Surface
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import com.follow.clash.plugins.AppPlugin
import com.follow.clash.plugins.ServicePlugin
import com.follow.clash.plugins.TilePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var liquidOverlay: ComposeView
    private var textureView: FlutterTextureView? = null
    private var textureSurface: Surface? = null
    private var capturePending = false
    private val captureRunnable = object : Runnable {
        override fun run() {
            captureFlutterBackdrop()
            liquidOverlay.postDelayed(this, 100L)
        }
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun getTransparencyMode(): TransparencyMode = TransparencyMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = findViewById<ViewGroup>(android.R.id.content)
        liquidOverlay = ComposeView(this).apply {
            setViewCompositionStrategy(
                ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed,
            )
            setContent {
                LiquidHomeOverlay()
            }
        }
        root.addView(
            liquidOverlay,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (128 * resources.displayMetrics.density).toInt(),
                Gravity.BOTTOM,
            ),
        )
    }

    override fun onStart() {
        super.onStart()
        if (::liquidOverlay.isInitialized) {
            liquidOverlay.removeCallbacks(captureRunnable)
            liquidOverlay.post(captureRunnable)
        }
    }

    override fun onStop() {
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
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        LiquidHomeController.attach(flutterEngine.dartExecutor.binaryMessenger)
        ServiceState.attachFlutterEngine(flutterEngine)
    }

    private fun captureFlutterBackdrop() {
        val state = LiquidHomeController.navigation.value
        val source = textureView ?: return
        val surface = textureSurface ?: return
        if (capturePending || !state.visible || source.width <= 0 || source.height <= 0) {
            return
        }
        val captureHeight = (128 * resources.displayMetrics.density).toInt()
            .coerceAtMost(source.height)
        val bitmap = Bitmap.createBitmap(source.width, captureHeight, Bitmap.Config.ARGB_8888)
        capturePending = true
        PixelCopy.request(
            surface,
            Rect(0, source.height - captureHeight, source.width, source.height),
            bitmap,
            { result: Int ->
                capturePending = false
                if (result == PixelCopy.SUCCESS) {
                    LiquidHomeController.updateSnapshot(bitmap, bitmap.asImageBitmap())
                } else {
                    bitmap.recycle()
                }
            },
            LiquidHomeController.mainHandler,
        )
    }

    override fun onDestroy() {
        if (::liquidOverlay.isInitialized) {
            liquidOverlay.removeCallbacks(captureRunnable)
            liquidOverlay.disposeComposition()
        }
        textureSurface?.release()
        textureSurface = null
        textureView = null
        LiquidHomeController.detach()
        flutterEngine?.let(ServiceState::detachFlutterEngine)
        super.onDestroy()
    }
}
