package com.follow.clash

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.BasicText
import androidx.compose.material.Icon
import androidx.compose.material.MaterialTheme
import androidx.compose.material.darkColors
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.SpaceDashboard
import androidx.compose.material.lightColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.follow.clash.liquid.components.LiquidBottomTab
import com.follow.clash.liquid.components.LiquidBottomTabs
import com.kyant.backdrop.backdrops.layerBackdrop
import com.kyant.backdrop.backdrops.rememberLayerBackdrop

@Composable
fun LiquidHomeOverlay() {
    val navigation by LiquidHomeController.navigation
    val snapshot by LiquidHomeController.snapshot
    if (!navigation.visible || navigation.labels.isEmpty()) {
        return
    }
    CompositionLocalProvider(
        LocalLayoutDirection provides if (navigation.rtl) {
            LayoutDirection.Rtl
        } else {
            LayoutDirection.Ltr
        },
    ) {
        MaterialTheme(
            colors = if (navigation.dark) darkColors() else lightColors(),
        ) {
            val backdrop = rememberLayerBackdrop()
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.BottomCenter,
            ) {
                if (navigation.liquidGlass) {
                    val frame = snapshot
                    if (frame != null) {
                        Image(
                            bitmap = frame.image,
                            contentDescription = null,
                            contentScale = ContentScale.FillBounds,
                            modifier = Modifier
                                .fillMaxSize()
                                .alpha(0f)
                                .layerBackdrop(backdrop),
                        )
                    } else {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .layerBackdrop(backdrop),
                        )
                    }
                }
                LiquidBottomTabs(
                    selectedTabIndex = { navigation.selectedIndex },
                    onTabSelected = LiquidHomeController::select,
                    onDraggingChanged = LiquidHomeController::setDragging,
                    backdrop = backdrop,
                    tabsCount = navigation.labels.size,
                    liquidGlass = navigation.liquidGlass,
                    isDarkTheme = navigation.dark,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .navigationBarsPadding()
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                        .widthIn(max = navigation.labels.size.times(88).plus(8).dp)
                        .fillMaxWidth()
                        .height(64.dp),
                ) {
                    navigation.labels.forEachIndexed { index, label ->
                        LiquidBottomTab(
                            onClick = { LiquidHomeController.select(index) },
                        ) {
                            LiquidNavigationItemContent(
                                label = label,
                                pageKey = navigation.pageKeys.getOrNull(index).orEmpty(),
                                selected = index == navigation.selectedIndex,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ColumnScope.LiquidNavigationItemContent(
    label: String,
    pageKey: String,
    selected: Boolean,
) {
    val color = MaterialTheme.colors.onSurface
    Icon(
        imageVector = iconForPage(pageKey),
        contentDescription = null,
        tint = color,
    )
    BasicText(
        text = label,
        style = TextStyle(
            color = color,
            fontSize = 11.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
        ),
    )
}

private fun iconForPage(pageKey: String): ImageVector {
    return when (pageKey) {
        "dashboard" -> Icons.Default.SpaceDashboard
        "profiles" -> Icons.Default.Folder
        else -> Icons.Default.Build
    }
}
