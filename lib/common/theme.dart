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
  static const double miuixNavigationBarHeight = 68;
  static const double miuixAppBarHeight = 76;
  static const double miuixComponentCornerRadius = 22;
  static const double miuixSectionCornerRadius = 24;
  static const double miuixDialogCornerRadius = 26;
  static const double miuixSheetCornerRadius = 30;
  static const double miuixListVerticalPadding = 12;
  static const double miuixListHorizontalPadding = 20;
  static const double blurredBarTintOpacity = 0.72;
  static const double liquidGlassTintOpacity = 0.52;
  static const double liquidGlassHighlightOpacity = 0.24;
  static const double liquidGlassAccentOpacity = 0.08;
  static const double liquidGlassBorderOpacity = 0.28;
  static const BorderRadius floatingBarBorderRadius = BorderRadius.all(
    Radius.circular(30),
  );
  static const EdgeInsets floatingBarMargin = EdgeInsets.fromLTRB(
    12,
    8,
    12,
    12,
  );
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
  final colorScheme = _miuixColorScheme(theme.colorScheme);
  final textTheme = theme.textTheme.copyWith(
    headlineSmall: theme.textTheme.headlineSmall?.copyWith(
      fontSize: 28,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    titleLarge: theme.textTheme.titleLarge?.copyWith(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );
  return theme.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
    textTheme: textTheme,
    appBarTheme: theme.appBarTheme.copyWith(
      toolbarHeight: AndroidAppearanceTokens.miuixAppBarHeight,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
      ),
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AndroidAppearanceTokens.miuixListHorizontalPadding,
      ),
      minVerticalPadding: AndroidAppearanceTokens.miuixListVerticalPadding,
      iconColor: colorScheme.onSurface,
      textColor: colorScheme.onSurface,
    ),
    cardTheme: theme.cardTheme.copyWith(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: colorScheme.surfaceContainer,
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
      backgroundColor: colorScheme.surfaceContainer,
      shape: sheetShape,
    ),
    dividerTheme: theme.dividerTheme.copyWith(
      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
      space: 1,
      thickness: 0.7,
    ),
    switchTheme: theme.switchTheme.copyWith(
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

ColorScheme _miuixColorScheme(ColorScheme source) {
  final isDark = source.brightness == Brightness.dark;
  if (isDark && source.surface == Colors.black) {
    return source;
  }
  final surface = Color.alphaBlend(
    source.primary.withValues(alpha: isDark ? 0.035 : 0.025),
    isDark ? const Color(0xFF111114) : const Color(0xFFF6F6F8),
  );
  final lowest = isDark ? const Color(0xFF0C0C0F) : const Color(0xFFFFFFFF);
  final low = Color.alphaBlend(
    source.primary.withValues(alpha: isDark ? 0.045 : 0.025),
    isDark ? const Color(0xFF17171B) : const Color(0xFFFCFCFD),
  );
  final container = Color.alphaBlend(
    source.primary.withValues(alpha: isDark ? 0.055 : 0.04),
    isDark ? const Color(0xFF1D1D22) : const Color(0xFFFFFFFF),
  );
  final high = Color.alphaBlend(
    source.primary.withValues(alpha: isDark ? 0.07 : 0.055),
    isDark ? const Color(0xFF25252B) : const Color(0xFFF0F0F4),
  );
  final highest = Color.alphaBlend(
    source.primary.withValues(alpha: isDark ? 0.09 : 0.07),
    isDark ? const Color(0xFF303037) : const Color(0xFFE7E7EC),
  );
  return source.copyWith(
    surface: surface,
    surfaceContainerLowest: lowest,
    surfaceContainerLow: low,
    surfaceContainer: container,
    surfaceContainerHigh: high,
    surfaceContainerHighest: highest,
    outlineVariant: Color.alphaBlend(
      source.primary.withValues(alpha: 0.05),
      source.outlineVariant,
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
