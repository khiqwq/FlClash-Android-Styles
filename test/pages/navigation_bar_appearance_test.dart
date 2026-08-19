import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderContainer> pumpHome(
    WidgetTester tester,
    AppearanceTheme appearance,
  ) async {
    final container = ProviderContainer(
      overrides: [
        navigationItemsStateProvider.overrideWithValue(
          NavigationItemsState(
            value: [
              NavigationItem(
                icon: const Icon(Icons.space_dashboard),
                label: PageLabel.dashboard,
                builder: (_) => const SizedBox.shrink(),
              ),
              NavigationItem(
                icon: const Icon(Icons.construction),
                label: PageLabel.tools,
                builder: (_) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(390, 800);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(extensions: [appearance]),
          home: const HomePage(),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('Material navigation remains the default', (tester) async {
    final container = await pumpHome(tester, const AppearanceTheme());
    addTearDown(container.dispose);

    final navigationTheme = tester.widget<NavigationBarTheme>(
      find.byType(NavigationBarTheme),
    );
    expect(
      navigationTheme.data.height,
      AndroidAppearanceTokens.materialNavigationBarHeight,
    );
    expect(find.byType(AndroidGlassSurface), findsNothing);
  });

  testWidgets('Miuix-inspired navigation uses compact theme tokens', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      const AppearanceTheme(
        isAndroid: true,
        interfaceStyle: InterfaceStyle.miuix,
      ),
    );
    addTearDown(container.dispose);

    final navigationTheme = tester.widget<NavigationBarTheme>(
      find.byType(NavigationBarTheme),
    );

    expect(
      navigationTheme.data.height,
      AndroidAppearanceTokens.miuixNavigationBarHeight,
    );
    expect(
      navigationTheme.data.indicatorShape,
      isA<RoundedSuperellipseBorder>(),
    );
    expect(
      navigationTheme.data.iconTheme?.resolve(const <WidgetState>{})?.size,
      26,
    );
    expect(
      navigationTheme.data.labelTextStyle?.resolve(const {
        WidgetState.selected,
      })?.fontWeight,
      FontWeight.bold,
    );
  });

  testWidgets('floating liquid glass navigation is clipped and blurred', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      const AppearanceTheme(
        isAndroid: true,
        floatingBottomBar: true,
        liquidGlass: true,
      ),
    );
    addTearDown(container.dispose);

    final surface = tester.widget<AndroidGlassSurface>(
      find.byType(AndroidGlassSurface),
    );

    expect(surface.liquidGlass, true);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipPath), findsWidgets);
    expect(
      AndroidAppearanceTokens.liquidGlassBlurSigma,
      lessThan(AndroidAppearanceTokens.barBlurSigma),
    );
    expect(AndroidAppearanceTokens.liquidGlassRefractionAmount, greaterThan(0));
    expect(
      surface.borderRadius,
      AndroidAppearanceTokens.floatingBarBorderRadius,
    );
    expect(
      find.ancestor(
        of: find.byType(AndroidGlassSurface),
        matching: find.byType(Positioned),
      ),
      findsOneWidget,
    );
    final contentHasNavigationInset = find
        .ancestor(of: find.byType(PageView), matching: find.byType(MediaQuery))
        .evaluate()
        .map((element) => (element.widget as MediaQuery).data.padding.bottom)
        .any(
          (padding) =>
              padding >= AndroidAppearanceTokens.materialNavigationBarHeight,
        );
    expect(contentHasNavigationInset, true);
  });

  testWidgets('liquid glass falls back until the bottom bar is floating', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      const AppearanceTheme(isAndroid: true, liquidGlass: true),
    );
    addTearDown(container.dispose);

    expect(find.byType(AndroidGlassSurface), findsNothing);
  });
}
