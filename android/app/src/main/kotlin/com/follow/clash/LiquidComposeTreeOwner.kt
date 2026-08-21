package com.follow.clash

import android.os.Bundle
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner

internal class LiquidComposeTreeOwner(
    private val lifecycleOwner: LifecycleOwner,
    restoredState: Bundle?,
) : LifecycleOwner, SavedStateRegistryOwner, ViewModelStoreOwner {
    private val controller = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle
        get() = lifecycleOwner.lifecycle

    override val savedStateRegistry: SavedStateRegistry
        get() = controller.savedStateRegistry

    override val viewModelStore = ViewModelStore()

    init {
        controller.performAttach()
        controller.performRestore(restoredState)
    }

    fun save(outState: Bundle) {
        controller.performSave(outState)
    }

    fun clear() {
        viewModelStore.clear()
    }
}