import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop ignores restored Android appearance preferences', () {
    final appearance = resolveAppearanceTheme(
      isAndroid: false,
      interfaceStyle: InterfaceStyle.miuix,
      blur: true,
      floatingBottomBar: true,
      liquidGlass: true,
    );

    expect(appearance.interfaceStyle, InterfaceStyle.material);
    expect(appearance.blur, false);
    expect(appearance.floatingBottomBar, false);
    expect(appearance.liquidGlass, false);
  });

  test('Android applies restored appearance preferences', () {
    final appearance = resolveAppearanceTheme(
      isAndroid: true,
      interfaceStyle: InterfaceStyle.miuix,
      blur: true,
      floatingBottomBar: true,
      liquidGlass: true,
    );

    expect(appearance.interfaceStyle, InterfaceStyle.miuix);
    expect(appearance.blur, true);
    expect(appearance.floatingBottomBar, true);
    expect(appearance.liquidGlass, true);
  });

  test('Material appearance returns the existing ThemeData unchanged', () {
    final theme = ThemeData();

    expect(
      applyAppearanceComponentTheme(theme, const AppearanceTheme()),
      same(theme),
    );
  });

  test('Miuix-inspired appearance supplies coherent component tokens', () {
    final theme = applyAppearanceComponentTheme(
      ThemeData(),
      const AppearanceTheme(
        isAndroid: true,
        interfaceStyle: InterfaceStyle.miuix,
      ),
    );

    expect(theme.appBarTheme.toolbarHeight, 76);
    expect(theme.appBarTheme.titleTextStyle?.fontSize, 28);
    expect(theme.listTileTheme.minVerticalPadding, 12);
    expect(theme.cardTheme.shape, isA<RoundedSuperellipseBorder>());
    expect(theme.dialogTheme.shape, isA<RoundedSuperellipseBorder>());
    expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    expect(theme.colorScheme.surface, isNot(ThemeData().colorScheme.surface));
    final pureBlackTheme = applyAppearanceComponentTheme(
      ThemeData(
        colorScheme: ThemeData.dark().colorScheme.copyWith(
          surface: Colors.black,
        ),
      ),
      const AppearanceTheme(
        isAndroid: true,
        interfaceStyle: InterfaceStyle.miuix,
      ),
    );
    expect(pureBlackTheme.colorScheme.surface, Colors.black);
    expect(
      theme.filledButtonTheme.style?.shape?.resolve(const <WidgetState>{}),
      isA<RoundedSuperellipseBorder>(),
    );
    expect(theme.bottomSheetTheme.shape, isA<RoundedSuperellipseBorder>());
  });
}
