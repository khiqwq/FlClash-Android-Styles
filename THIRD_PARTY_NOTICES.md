# Third-party notices

## AndroidLiquidGlass

The liquid toggle navigation interaction in
`lib/widgets/liquid_toggle_navigation_bar.dart` and the related Flutter shader
is a source-faithful translation of `LiquidToggle.kt`,
`DampedDragAnimation.kt`, and the Backdrop `drawBackdrop`,
layer-backdrop, combined-backdrop, blur, lens, highlight, shadow, inner-shadow,
and `Capsule` implementations in
[Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass) at
commit `b18eb0ff12c616546a68c72e7d0097f1ab286c87`.

Copyright AndroidLiquidGlass contributors. Licensed under the Apache License,
Version 2.0. The complete license is included at
`LICENSES/AndroidLiquidGlass.txt`.

The implementation is translated to Flutter/Dart and extended only from a
binary fraction to a multi-destination position plus navigation icon and label
content. Flutter's Impeller fragment-shader and backdrop-filter APIs provide
the corresponding render path, with an explicit blur fallback when shader
filters are unsupported.
