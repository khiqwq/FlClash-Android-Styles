# Third-party notices

## AndroidLiquidGlass

The LiquidToggle interaction in
`lib/widgets/liquid_toggle_navigation_bar.dart` is a source-faithful Flutter
translation of `LiquidToggle.kt` and `DampedDragAnimation.kt` from
[Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass) at
commit `b18eb0ff12c616546a68c72e7d0097f1ab286c87`. It extends the upstream binary
fraction to a multi-destination position with navigation icon and label
content.

The following FlClash files are translations or derivatives of the Backdrop
implementation at that same commit:

- `lib/widgets/effect.dart`, from
  `backdrop/src/commonMain/kotlin/com/kyant/backdrop/DrawBackdropModifier.kt`,
  `backdrop/src/commonMain/kotlin/com/kyant/backdrop/effects/Lens.kt`,
  `backdrop/src/commonMain/kotlin/com/kyant/backdrop/internal/Shaders.kt`, and
  related Backdrop APIs.
- `shaders/liquid_glass.frag`, from
  `backdrop/src/commonMain/kotlin/com/kyant/backdrop/internal/Shaders.kt`
  `RoundedRectRefractionWithDispersionShaderString`.
- `shaders/liquid_ambient_highlight.frag`, from
  `backdrop/src/commonMain/kotlin/com/kyant/backdrop/internal/Shaders.kt`
  `AmbientHighlightShaderString`.

`Capsule` is supplied to AndroidLiquidGlass by the external Maven artifact
`io.github.kyant0:shapes:1.2.0`; it is not an AndroidLiquidGlass
implementation.

Copyright 2025 Kyant. Licensed under the Apache License, Version 2.0. The
complete license and retained notice are included at
`LICENSES/AndroidLiquidGlass.txt`.

FlClash translated and modified these files for Flutter. Flutter's Impeller
fragment-shader and backdrop-filter APIs provide the corresponding render path,
with an explicit blur fallback when shader filters are unsupported.
