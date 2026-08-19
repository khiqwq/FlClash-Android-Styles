import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/material.dart';

abstract final class AndroidAppearanceTokens {
  static const double barBlurSigma = 18;
  static const double liquidGlassBlurSigma = 8;
  static const double liquidGlassRefractionHeight = 24;
  static const double liquidGlassRefractionAmount = 18;
  static const double liquidGlassChromaticAberration = 1.25;
  static const double materialNavigationBarHeight = 80;
  static const double miuixNavigationBarHeight = 64;
  static const double miuixAppBarHeight = 64;
  static const double miuixComponentCornerRadius = 18;
  static const double miuixDialogCornerRadius = 26;
  static const double miuixSheetCornerRadius = 30;
  static const double miuixListVerticalPadding = 14;
  static const double miuixListHorizontalPadding = 20;
  static const double blurredBarTintOpacity = 0.72;
  static const double liquidGlassTintOpacity = 0.52;
  static const double liquidGlassHighlightOpacity = 0.24;
  static const double liquidGlassAccentOpacity = 0.08;
  static const double liquidGlassBorderOpacity = 0.28;
  static const BorderRadius floatingBarBorderRadius = BorderRadius.all(
    Radius.circular(30),
  );
  static const EdgeInsets floatingBarMargin = EdgeInsets.fromLTRB(12, 8, 12, 8);
}

@immutable
class AppearanceTheme extends ThemeExtension<AppearanceTheme> {
  final bool isAndroid;
  final InterfaceStyle interfaceStyle;
  final bool blur;
  final bool floatingBottomBar;
  final bool liquidGlass;

  const AppearanceTheme({
    this.isAndroid = false,
    this.interfaceStyle = InterfaceStyle.material,
    this.blur = false,
    this.floatingBottomBar = false,
    this.liquidGlass = false,
  });

  bool get isMiuix => isAndroid && interfaceStyle == InterfaceStyle.miuix;

  @override
  AppearanceTheme copyWith({
    bool? isAndroid,
    InterfaceStyle? interfaceStyle,
    bool? blur,
    bool? floatingBottomBar,
    bool? liquidGlass,
  }) {
    return AppearanceTheme(
      isAndroid: isAndroid ?? this.isAndroid,
      interfaceStyle: interfaceStyle ?? this.interfaceStyle,
      blur: blur ?? this.blur,
      floatingBottomBar: floatingBottomBar ?? this.floatingBottomBar,
      liquidGlass: liquidGlass ?? this.liquidGlass,
    );
  }

  @override
  AppearanceTheme lerp(covariant AppearanceTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

AppearanceTheme resolveAppearanceTheme({
  required bool isAndroid,
  required InterfaceStyle interfaceStyle,
  required bool blur,
  required bool floatingBottomBar,
  required bool liquidGlass,
}) {
  if (!isAndroid) {
    return const AppearanceTheme();
  }
  return AppearanceTheme(
    isAndroid: true,
    interfaceStyle: interfaceStyle,
    blur: blur,
    floatingBottomBar: floatingBottomBar,
    liquidGlass: liquidGlass,
  );
}

ThemeData applyAppearanceComponentTheme(
  ThemeData theme,
  AppearanceTheme appearance,
) {
  if (!appearance.isMiuix) {
    return theme;
  }
  final componentShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(
      AndroidAppearanceTokens.miuixComponentCornerRadius,
    ),
  );
  final sheetShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(
      AndroidAppearanceTokens.miuixSheetCornerRadius,
    ),
  );
  final buttonStyle = ButtonStyle(
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    shape: WidgetStatePropertyAll(componentShape),
  );
  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      toolbarHeight: AndroidAppearanceTokens.miuixAppBarHeight,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AndroidAppearanceTokens.miuixListHorizontalPadding,
      ),
      minVerticalPadding: AndroidAppearanceTokens.miuixListVerticalPadding,
      shape: componentShape,
    ),
    cardTheme: theme.cardTheme.copyWith(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: componentShape,
    ),
    dialogTheme: theme.dialogTheme.copyWith(
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(
          AndroidAppearanceTokens.miuixDialogCornerRadius,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        shape: WidgetStatePropertyAll(componentShape),
      ),
    ),
    bottomSheetTheme: theme.bottomSheetTheme.copyWith(
      showDragHandle: false,
      shape: sheetShape,
    ),
  );
}

class CommonTheme {
  final BuildContext context;
  final Map<String, Color> _colorMap;
  final double textScaleFactor;

  CommonTheme.of(this.context, this.textScaleFactor) : _colorMap = {};

  Color get darkenSecondaryContainer {
    return _colorMap.updateCacheValue(
      'darkenSecondaryContainer',
      () => context.colorScheme.secondaryContainer.blendDarken(
        context,
        factor: 0.1,
      ),
    );
  }

  Color get darkenSecondaryContainerLighter {
    return _colorMap.updateCacheValue(
      'darkenSecondaryContainerLighter',
      () => context.colorScheme.secondaryContainer
          .blendDarken(context, factor: 0.1)
          .opacity60,
    );
  }

  Color get darken2SecondaryContainer {
    return _colorMap.updateCacheValue(
      'darken2SecondaryContainer',
      () => context.colorScheme.secondaryContainer.blendDarken(
        context,
        factor: 0.2,
      ),
    );
  }

  Color get darken3PrimaryContainer {
    return _colorMap.updateCacheValue(
      'darken3PrimaryContainer',
      () => context.colorScheme.primaryContainer.blendDarken(
        context,
        factor: 0.3,
      ),
    );
  }
}
