import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/widgets/card.dart';
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

  test('Miuix appearance supplies coherent component tokens', () {
    final theme = applyAppearanceComponentTheme(
      ThemeData(),
      const AppearanceTheme(
        isAndroid: true,
        interfaceStyle: InterfaceStyle.miuix,
      ),
    );

    expect(theme.appBarTheme.toolbarHeight, 92);
    expect(theme.appBarTheme.titleTextStyle?.fontSize, 32);
    expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w400);
    expect(theme.listTileTheme.minVerticalPadding, 12);
    expect(theme.cardTheme.shape, isA<RoundedSuperellipseBorder>());
    expect(theme.dialogTheme.shape, isA<RoundedSuperellipseBorder>());
    expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    expect(theme.colorScheme.primary, ThemeData().colorScheme.primary);
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

  test('fixed Miuix palettes match compose-miuix light and dark defaults', () {
    final light = miuixDefaultColorScheme(Brightness.light);
    final dark = miuixDefaultColorScheme(Brightness.dark);

    expect(light.primary, const Color(0xFF3482FF));
    expect(light.primaryContainer, const Color(0xFF5D9BFF));
    expect(light.secondary, const Color(0xFFE6E6E6));
    expect(light.secondaryContainer, const Color(0xFFF0F0F0));
    expect(light.tertiaryContainer, const Color(0xFFEAF2FF));
    expect(light.surface, const Color(0xFFF7F7F7));
    expect(light.surfaceContainer, Colors.white);
    expect(light.surfaceContainerHigh, const Color(0xFFE8E8E8));
    expect(light.onSurface, Colors.black);
    expect(light.onSurfaceVariant, const Color(0x99000000));
    expect(light.outline, const Color(0xFFD9D9D9));
    expect(light.outlineVariant, const Color(0xFFE0E0E0));

    expect(dark.primary, const Color(0xFF277AF7));
    expect(dark.primaryContainer, const Color(0xFF338FE4));
    expect(dark.secondary, const Color(0xFF505050));
    expect(dark.secondaryContainer, const Color(0xFF434343));
    expect(dark.tertiaryContainer, const Color(0xFF2B3B54));
    expect(dark.surface, Colors.black);
    expect(dark.surfaceContainer, const Color(0xFF242424));
    expect(dark.surfaceContainerHigh, const Color(0xFF242424));
    expect(dark.surfaceContainerHighest, const Color(0xFF2D2D2D));
    expect(dark.onSurface, const Color(0xFFF2F2F2));
    expect(dark.onSurfaceVariant, const Color(0x80FFFFFF));
    expect(dark.outline, const Color(0xFF404040));
    expect(dark.outlineVariant, const Color(0xFF393939));
  });

  test('fixed Miuix component states use the source palette roles', () {
    final theme = applyAppearanceComponentTheme(
      ThemeData(colorScheme: miuixDefaultColorScheme(Brightness.light)),
      const AppearanceTheme(
        isAndroid: true,
        interfaceStyle: InterfaceStyle.miuix,
      ),
    );
    final switchTheme = theme.switchTheme;

    expect(
      switchTheme.trackColor?.resolve(const <WidgetState>{}),
      const Color(0xFFE6E6E6),
    );
    expect(
      switchTheme.thumbColor?.resolve(const <WidgetState>{}),
      Colors.white,
    );
    expect(
      switchTheme.trackColor?.resolve(const <WidgetState>{
        WidgetState.selected,
      }),
      const Color(0xFF3482FF),
    );
    expect(
      switchTheme.trackColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
        WidgetState.selected,
      }),
      const Color(0xFFC2D9FF),
    );
    expect(
      theme.checkboxTheme.fillColor?.resolve(const <WidgetState>{}),
      const Color(0xFFE6E6E6),
    );
    expect(theme.sliderTheme.inactiveTrackColor, const Color(0x0F000000));
    expect(theme.inputDecorationTheme.filled, true);
    expect(theme.inputDecorationTheme.fillColor, const Color(0xFFF0F0F0));
    expect(theme.textTheme.titleMedium?.fontSize, 17);
    expect(theme.textTheme.titleMedium?.fontWeight, FontWeight.w500);
  });

  testWidgets('Miuix tonal buttons resolve readable fixed roles', (
    tester,
  ) async {
    final colorScheme = miuixDefaultColorScheme(Brightness.light);
    const appearance = AppearanceTheme(
      isAndroid: true,
      interfaceStyle: InterfaceStyle.miuix,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: applyAppearanceComponentTheme(
          ThemeData(colorScheme: colorScheme, extensions: const [appearance]),
          appearance,
        ),
        home: Scaffold(
          body: Column(
            children: [
              FilledButton.tonal(
                key: const ValueKey('tonal-button'),
                onPressed: () {},
                child: const Text('Tonal'),
              ),
              FilledButton(
                key: const ValueKey('primary-button'),
                onPressed: () {},
                child: const Text('Primary'),
              ),
              const FilledButton.tonal(
                key: ValueKey('disabled-tonal-button'),
                onPressed: null,
                child: Text('Disabled'),
              ),
            ],
          ),
        ),
      ),
    );

    Color? resolveColor(
      Finder finder,
      Set<WidgetState> states,
      WidgetStateProperty<Color?>? Function(ButtonStyle style) property,
    ) {
      final button = tester.widget<FilledButton>(finder);
      final context = tester.element(finder);
      return property(button.style ?? const ButtonStyle())?.resolve(states) ??
          property(
            FilledButtonTheme.of(context).style ?? const ButtonStyle(),
          )?.resolve(states) ??
          property(button.defaultStyleOf(context))?.resolve(states);
    }

    final tonal = find.byKey(const ValueKey('tonal-button'));
    expect(
      resolveColor(
        tonal,
        const <WidgetState>{},
        (style) => style.backgroundColor,
      ),
      colorScheme.secondaryFixedDim,
    );
    expect(
      resolveColor(
        tonal,
        const <WidgetState>{},
        (style) => style.foregroundColor,
      ),
      colorScheme.onSecondaryFixed,
    );
    final primary = find.byKey(const ValueKey('primary-button'));
    expect(
      resolveColor(
        primary,
        const <WidgetState>{},
        (style) => style.backgroundColor,
      ),
      colorScheme.primary,
    );
    expect(
      resolveColor(
        primary,
        const <WidgetState>{},
        (style) => style.foregroundColor,
      ),
      colorScheme.onPrimary,
    );
    final disabled = find.byKey(const ValueKey('disabled-tonal-button'));
    expect(
      resolveColor(disabled, const <WidgetState>{
        WidgetState.disabled,
      }, (style) => style.backgroundColor),
      const Color(0xFFE3E3E3),
    );
    expect(
      resolveColor(disabled, const <WidgetState>{
        WidgetState.disabled,
      }, (style) => style.foregroundColor),
      const Color(0xFF6B6B6B),
    );
  });

  testWidgets('selected Miuix cards use primary-container foreground roles', (
    tester,
  ) async {
    final colorScheme = miuixDefaultColorScheme(Brightness.light);
    await tester.pumpWidget(
      MaterialApp(
        theme: applyAppearanceComponentTheme(
          ThemeData(
            colorScheme: colorScheme,
            extensions: const [
              AppearanceTheme(
                isAndroid: true,
                interfaceStyle: InterfaceStyle.miuix,
              ),
            ],
          ),
          const AppearanceTheme(
            isAndroid: true,
            interfaceStyle: InterfaceStyle.miuix,
          ),
        ),
        home: const CommonCard(
          isSelected: true,
          type: CommonCardType.filled,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.check), Text('selected')],
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.style?.foregroundColor?.resolve(const <WidgetState>{}),
      colorScheme.onPrimaryContainer,
    );
    expect(
      button.style?.iconColor?.resolve(const <WidgetState>{}),
      colorScheme.onPrimaryContainer,
    );
    expect(
      button.style?.backgroundColor?.resolve(const <WidgetState>{}),
      colorScheme.primaryContainer,
    );
  });
}
