import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/material.dart';

abstract final class AndroidAppearanceTokens {
  static const double barBlurSigma = 18;
  static const double liquidGlassBlurSigma = 8;
  static const double liquidGlassRefractionHeight = 5;
  static const double liquidGlassRefractionAmount = 10;
  static const double liquidGlassChromaticAberration = 0.75;
  static const double materialNavigationBarHeight = 80;
  static const double miuixNavigationBarHeight = 68;
  static const double liquidNavigationBarHeight = 64;
  static const double miuixAppBarHeight = 92;
  static const double miuixComponentCornerRadius = 16;
  static const double miuixSectionCornerRadius = 16;
  static const double miuixDialogCornerRadius = 26;
  static const double miuixSheetCornerRadius = 30;
  static const double miuixListVerticalPadding = 12;
  static const double miuixListHorizontalPadding = 20;
  static const double blurredBarTintOpacity = 0.72;
  static const double liquidGlassTintOpacity = 0.34;
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

ColorScheme miuixDefaultColorScheme(Brightness brightness) {
  return switch (brightness) {
    Brightness.light => _miuixLightColorScheme(),
    Brightness.dark => _miuixDarkColorScheme(),
  };
}

Color miuixOnSurfaceContainer(Brightness brightness) {
  return brightness == Brightness.dark ? const Color(0xE6FFFFFF) : Colors.black;
}

ColorScheme _miuixLightColorScheme() {
  const primary = Color(0xFF3482FF);
  return ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF5D9BFF),
    onPrimaryContainer: Colors.white,
    primaryFixed: primary,
    primaryFixedDim: const Color(0xFF5D9BFF),
    onPrimaryFixed: Colors.white,
    onPrimaryFixedVariant: const Color(0xFFAECDFF),
    secondary: const Color(0xFFE6E6E6),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFF0F0F0),
    onSecondaryContainer: const Color(0xFF303030),
    secondaryFixed: const Color(0xFFE6E6E6),
    secondaryFixedDim: const Color(0xFFF0F0F0),
    onSecondaryFixed: const Color(0xFF303030),
    onSecondaryFixedVariant: const Color(0xFFA8A8A8),
    tertiary: const Color(0xFF3482FF),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFEAF2FF),
    onTertiaryContainer: const Color(0xFF3482FF),
    error: const Color(0xFFE94634),
    onError: Colors.white,
    errorContainer: const Color(0xFFFDF6F4),
    onErrorContainer: const Color(0xFF410002),
    surface: const Color(0xFFF7F7F7),
    onSurface: Colors.black,
    surfaceDim: const Color(0xFFF7F7F7),
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: Colors.white,
    surfaceContainerHigh: const Color(0xFFE8E8E8),
    surfaceContainerHighest: const Color(0xFFE8E8E8),
    onSurfaceVariant: const Color(0x99000000),
    outline: const Color(0xFFD9D9D9),
    outlineVariant: const Color(0xFFE0E0E0),
    shadow: Colors.black,
    scrim: const Color(0x4D000000),
    inverseSurface: const Color(0xFF242424),
    onInverseSurface: const Color(0xFFF2F2F2),
    inversePrimary: const Color(0xFF277AF7),
    surfaceTint: Colors.transparent,
  );
}

ColorScheme _miuixDarkColorScheme() {
  const primary = Color(0xFF277AF7);
  return ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF338FE4),
    onPrimaryContainer: Colors.white,
    primaryFixed: primary,
    primaryFixedDim: const Color(0xFF338FE4),
    onPrimaryFixed: Colors.white,
    onPrimaryFixedVariant: const Color(0xFF99C7F1),
    secondary: const Color(0xFF505050),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF434343),
    onSecondaryContainer: const Color(0xFFD9D9D9),
    secondaryFixed: const Color(0xFF505050),
    secondaryFixedDim: const Color(0xFF434343),
    onSecondaryFixed: const Color(0xFFD9D9D9),
    onSecondaryFixedVariant: const Color(0xFF959595),
    tertiary: const Color(0xFF4788FF),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFF2B3B54),
    onTertiaryContainer: const Color(0xFF4788FF),
    error: const Color(0xFFF12522),
    onError: Colors.white,
    errorContainer: const Color(0xFF2E0603),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: Colors.black,
    onSurface: const Color(0xFFF2F2F2),
    surfaceDim: Colors.black,
    surfaceBright: const Color(0xFF2D2D2D),
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: const Color(0xFF242424),
    surfaceContainer: const Color(0xFF242424),
    surfaceContainerHigh: const Color(0xFF242424),
    surfaceContainerHighest: const Color(0xFF2D2D2D),
    onSurfaceVariant: const Color(0x80FFFFFF),
    outline: const Color(0xFF404040),
    outlineVariant: const Color(0xFF393939),
    shadow: Colors.black,
    scrim: const Color(0x99000000),
    inverseSurface: const Color(0xFFF7F7F7),
    onInverseSurface: Colors.black,
    inversePrimary: const Color(0xFF3482FF),
    surfaceTint: Colors.transparent,
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
  final sourceColorScheme = theme.colorScheme;
  final colorScheme = sourceColorScheme.copyWith(
    secondaryContainer: sourceColorScheme.secondaryFixedDim,
    onSecondaryContainer: sourceColorScheme.onSecondaryFixed,
  );
  final isDark = colorScheme.brightness == Brightness.dark;
  final disabledPrimary = isDark
      ? const Color(0xFF253E64)
      : const Color(0xFFC2D9FF);
  final disabledOnPrimary = isDark
      ? const Color(0xFF677993)
      : const Color(0xFFF3F8FF);
  final disabledSecondary = isDark
      ? const Color(0xFF3F3F3F)
      : const Color(0xFFF0F0F0);
  final disabledOnSecondary = isDark
      ? const Color(0xFF797979)
      : const Color(0xFFFCFCFC);
  final disabledPrimarySlider = isDark
      ? const Color(0xFF44587C)
      : const Color(0xFFB8CFF5);
  final disabledTonalBackground = isDark
      ? const Color(0xFF343434)
      : const Color(0xFFE3E3E3);
  final disabledTonalForeground = isDark
      ? const Color(0xFF9A9A9A)
      : const Color(0xFF6B6B6B);
  final sliderBackground = isDark
      ? const Color(0x26FFFFFF)
      : const Color(0x0F000000);
  final textTheme = theme.textTheme.copyWith(
    headlineSmall: theme.textTheme.headlineSmall?.copyWith(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.2,
    ),
    titleLarge: theme.textTheme.titleLarge?.copyWith(
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w400,
    ),
    titleMedium: theme.textTheme.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
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
    filledButtonTheme: FilledButtonThemeData(
      style: buttonStyle.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.disabled)
              ? disabledTonalBackground
              : null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.disabled)
              ? disabledTonalForeground
              : null;
        }),
      ),
    ),
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
      trackColor: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return selected ? disabledPrimary : disabledSecondary;
        }
        return selected ? colorScheme.primary : colorScheme.secondary;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return selected ? disabledOnPrimary : disabledOnSecondary;
        }
        return selected ? colorScheme.onPrimary : colorScheme.onSecondary;
      }),
    ),
    checkboxTheme: theme.checkboxTheme.copyWith(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      fillColor: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return selected ? disabledPrimary : disabledSecondary;
        }
        return selected ? colorScheme.primary : colorScheme.secondary;
      }),
      checkColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return states.contains(WidgetState.selected)
              ? disabledOnPrimary
              : disabledOnSecondary;
        }
        return states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSecondary;
      }),
    ),
    radioTheme: theme.radioTheme.copyWith(
      fillColor: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return selected ? disabledPrimary : disabledSecondary;
        }
        return selected ? colorScheme.primary : colorScheme.secondary;
      }),
    ),
    sliderTheme: theme.sliderTheme.copyWith(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: sliderBackground,
      disabledActiveTrackColor: disabledPrimarySlider,
      disabledInactiveTrackColor: sliderBackground,
      thumbColor: colorScheme.primary,
      disabledThumbColor: disabledPrimarySlider,
      activeTickMarkColor: colorScheme.onPrimary,
      inactiveTickMarkColor: colorScheme.outline,
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: colorScheme.secondaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
      floatingLabelStyle: TextStyle(color: colorScheme.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AndroidAppearanceTokens.miuixComponentCornerRadius,
        ),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AndroidAppearanceTokens.miuixComponentCornerRadius,
        ),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AndroidAppearanceTokens.miuixComponentCornerRadius,
        ),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
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
