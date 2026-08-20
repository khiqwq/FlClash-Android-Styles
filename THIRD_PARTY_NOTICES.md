# Third-party notices

## AndroidLiquidGlass

The liquid toggle navigation interaction in
`lib/widgets/liquid_toggle_navigation_bar.dart` and the related Flutter shader
are adapted from `LiquidToggle.kt`, `LiquidBottomTabs.kt`,
`DampedDragAnimation.kt`, and the Backdrop lens, highlight, shadow, inner-shadow,
and combined-backdrop implementation in
[Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass) at
commit `b18eb0ff12c616546a68c72e7d0097f1ab286c87`.

Copyright AndroidLiquidGlass contributors. Licensed under the Apache License,
Version 2.0. The complete license is included at
`LICENSES/AndroidLiquidGlass.txt`.

The implementation was translated to Flutter/Dart, extended from a binary
toggle to multi-destination navigation, and modified to use Flutter's Impeller
fragment-shader and backdrop-filter APIs with a non-shader fallback.

## KernelSU and compose-miuix

The floating navigation bar's layered panel, rubber-band offset, content scale,
tap and release behavior, and neutral glass values were compared with
`FloatingBottomBar.kt` from
[tiann/KernelSU](https://github.com/tiann/KernelSU) at commit
`af62466b70c0ebf8f9340e3a9bf0a487d804ca66`, which identifies its floating bar
as adapted from the Apache-2.0 compose-miuix example.

The fixed light and dark Miuix palettes and the floating navigation structure
are translated from `Colors.kt` and `LiquidGlassNavigationBar.kt` in
[compose-miuix](https://github.com/compose-miuix-ui/miuix) at commit
`c2a0ff66243e5cca5480091e531f3dd7fc48b2fc`.

compose-miuix is licensed under the Apache License, Version 2.0. The complete
license text is included at `LICENSES/AndroidLiquidGlass.txt`.

The Flutter implementation is an independent Dart implementation and does not
bundle KernelSU or compose-miuix code.
