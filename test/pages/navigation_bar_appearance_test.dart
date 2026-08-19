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

void _ignoreSelection(int index) {}

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

    final navigation = tester.widget<MiuixBottomNavigationBar>(
      find.byType(MiuixBottomNavigationBar),
    );

    expect(navigation.floating, false);
    expect(navigation.selectedIndex, 0);
    expect(
      find.byKey(const ValueKey('miuix-bottom-navigation')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.ancestor(
        of: find.byType(MiuixBottomNavigationBar),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find
          .descendant(
            of: find.byType(MiuixBottomNavigationBar),
            matching: find.byType(InkWell),
          )
          .last,
    );
    await tester.pump(kTabScrollDuration);

    expect(container.read(currentPageLabelProvider), PageLabel.tools);
    expect(
      tester
          .widget<MiuixBottomNavigationBar>(
            find.byType(MiuixBottomNavigationBar),
          )
          .selectedIndex,
      1,
    );
  });

  testWidgets('floating liquid glass navigation is clipped and blurred', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      const AppearanceTheme(
        isAndroid: true,
        interfaceStyle: InterfaceStyle.miuix,
        floatingBottomBar: true,
        liquidGlass: true,
      ),
    );
    addTearDown(container.dispose);

    final surface = tester.widget<AndroidGlassSurface>(
      find.byType(AndroidGlassSurface),
    );
    final navigation = tester.widget<MiuixBottomNavigationBar>(
      find.byType(MiuixBottomNavigationBar),
    );

    expect(surface.liquidGlass, true);
    expect(navigation.floating, true);
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
              padding >= AndroidAppearanceTokens.miuixNavigationBarHeight,
        );
    expect(contentHasNavigationInset, true);
  });

  testWidgets('floating Miuix indicator follows RTL navigation order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            AppearanceTheme(
              isAndroid: true,
              interfaceStyle: InterfaceStyle.miuix,
            ),
          ],
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            child: MiuixBottomNavigationBar(
              items: [
                NavigationItem(
                  icon: const Icon(Icons.home),
                  label: PageLabel.dashboard,
                  builder: (_) => const SizedBox.shrink(),
                ),
                NavigationItem(
                  icon: const Icon(Icons.settings),
                  label: PageLabel.tools,
                  builder: (_) => const SizedBox.shrink(),
                ),
              ],
              selectedIndex: 0,
              floating: true,
              onSelected: _ignoreSelection,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final indicator = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
    expect(indicator.alignment, const AlignmentDirectional(-1, 0));
  });

  testWidgets('Material floating mode keeps Material navigation', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      const AppearanceTheme(
        isAndroid: true,
        interfaceStyle: InterfaceStyle.material,
        floatingBottomBar: true,
      ),
    );
    addTearDown(container.dispose);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(MiuixBottomNavigationBar), findsNothing);
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
