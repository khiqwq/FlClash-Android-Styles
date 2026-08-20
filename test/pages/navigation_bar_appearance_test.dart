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

List<NavigationItem> _liquidItems() {
  return [
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
    NavigationItem(
      icon: const Icon(Icons.info),
      label: PageLabel.logs,
      builder: (_) => const SizedBox.shrink(),
    ),
  ];
}

void main() {
  testWidgets('Android root delegates predictive back to the system', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeBackScopeContainer(isAndroid: true, child: Text('root')),
      ),
    );
    expect(find.text('root'), findsOneWidget);
    expect(find.byType(CommonPopScope), findsNothing);
  });

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

  testWidgets('floating liquid glass navigation is layered and centered', (
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

    final surfaces = tester.widgetList<AndroidGlassSurface>(
      find.byType(AndroidGlassSurface),
    );
    final panel = surfaces.firstWhere(
      (surface) => surface.liquidRefractionHeight == 24,
    );
    final thumb = surfaces.firstWhere(
      (surface) => surface.liquidRefractionHeight == 5,
    );

    expect(find.byType(LiquidToggleNavigationBar), findsOneWidget);
    expect(find.byType(MiuixBottomNavigationBar), findsNothing);
    expect(panel.liquidGlass, true);
    expect(panel.liquidProgress, 1);
    expect(panel.scaleLiquidBlurWithProgress, false);
    expect(panel.liquidAccentColor, Colors.transparent);
    expect(thumb.liquidProgress, greaterThan(0));
    expect(thumb.liquidRefractionAmount, greaterThan(0));
    expect(thumb.liquidChromaticAberration, greaterThan(0));
    expect(thumb.liquidAccentColor, Colors.transparent);
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    expect(find.byType(ClipPath), findsWidgets);
    expect(find.byKey(const ValueKey('liquid-glass-rim')), findsNWidgets(2));
    expect(
      find.ancestor(
        of: find.byType(LiquidToggleNavigationBar),
        matching: find.byType(AnimatedVisibility),
      ),
      findsNothing,
    );
    expect(
      AndroidAppearanceTokens.liquidGlassBlurSigma,
      lessThan(AndroidAppearanceTokens.barBlurSigma),
    );
    expect(AndroidAppearanceTokens.liquidGlassRefractionAmount, greaterThan(0));
    expect(
      find.descendant(
        of: find.byType(LiquidToggleNavigationBar),
        matching: find.byType(PositionedDirectional),
      ),
      findsOneWidget,
    );
    final barRect = tester.getRect(find.byType(LiquidToggleNavigationBar));
    for (var index = 0; index < 2; index++) {
      final itemCenter = tester.getCenter(
        find.byKey(ValueKey('liquid-navigation-item-$index')),
      );
      final expectedCenter =
          barRect.left + 4 + (barRect.width - 8) * (index + 0.5) / 2;
      expect(itemCenter.dx, closeTo(expectedCenter, 0.01));
    }
    final contentHasNavigationInset = find
        .ancestor(of: find.byType(PageView), matching: find.byType(MediaQuery))
        .evaluate()
        .map((element) => (element.widget as MediaQuery).data.padding.bottom)
        .any(
          (padding) =>
              padding >= AndroidAppearanceTokens.liquidNavigationBarHeight,
        );
    expect(contentHasNavigationInset, true);
    final layeredStack = tester.widget<Stack>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Stack &&
            widget.children.any(
              (child) =>
                  child.key == const ValueKey('liquid-glass-panel-layer'),
            ),
      ),
    );
    final indicatorLayerIndex = layeredStack.children.indexWhere(
      (child) => child.key == const ValueKey('liquid-glass-indicator-layer'),
    );
    final contentLayerIndex = layeredStack.children.indexWhere(
      (child) => child.key == const ValueKey('liquid-glass-content-layer'),
    );
    expect(indicatorLayerIndex, greaterThanOrEqualTo(0));
    expect(contentLayerIndex, greaterThan(indicatorLayerIndex));

    final secondItem = find.byKey(const ValueKey('liquid-navigation-item-1'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LiquidToggleNavigationBar)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final pressedPanelTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-panel-transform')),
    );
    final pressedThumbTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-thumb-transform')),
    );
    final pressedItemTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-navigation-item-content-0')),
    );
    expect(pressedPanelTransform.transform.storage[0], greaterThan(1));
    expect(pressedThumbTransform.transform.storage[0], greaterThan(1));
    expect(pressedThumbTransform.transform.storage[5], greaterThan(1));
    expect(pressedItemTransform.transform.storage[0], greaterThan(1));
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('liquid-toggle-thumb-transform')),
        matching: find.byKey(const ValueKey('liquid-toggle-panel-transform')),
      ),
      findsNothing,
    );
    await gesture.moveTo(tester.getCenter(secondItem));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester
          .widgetList<AndroidGlassSurface>(find.byType(AndroidGlassSurface))
          .firstWhere((surface) => surface.liquidRefractionHeight != 24)
          .liquidProgress,
      greaterThan(0.35),
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('liquid-toggle-thumb-transform')),
          )
          .transform
          .storage[0],
      greaterThan(1.1),
    );
    await tester.pumpAndSettle();

    expect(container.read(currentPageLabelProvider), PageLabel.tools);
    final thumbTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-thumb-transform')),
    );
    final panelTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-panel-transform')),
    );
    expect(thumbTransform.transformHitTests, false);
    expect(panelTransform.transform.storage[0], closeTo(1, 0.001));
    expect(thumbTransform.transform.storage[0], closeTo(1, 0.001));
    expect(thumbTransform.transform.storage[5], closeTo(1, 0.001));
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

  testWidgets('liquid indicator drag follows RTL navigation order', (
    tester,
  ) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            AppearanceTheme(
              isAndroid: true,
              floatingBottomBar: true,
              liquidGlass: true,
            ),
          ],
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            child: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SizedBox(
                    width: 240,
                    child: LiquidToggleNavigationBar(
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
                      selectedIndex: selectedIndex,
                      onSelected: (index) {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final indicator = find.byKey(
      const ValueKey('liquid-toggle-thumb-transform'),
    );
    final gesture = await tester.startGesture(tester.getCenter(indicator));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-90, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);
  });

  testWidgets('liquid drag cancellation restores committed selection', (
    tester,
  ) async {
    var selectedIndex = 0;
    var callbackCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            AppearanceTheme(
              isAndroid: true,
              floatingBottomBar: true,
              liquidGlass: true,
            ),
          ],
        ),
        home: StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: SizedBox(
                width: 240,
                child: LiquidToggleNavigationBar(
                  items: _liquidItems(),
                  selectedIndex: selectedIndex,
                  onSelected: (index) {
                    callbackCount++;
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LiquidToggleNavigationBar)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(48, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(selectedIndex, 0);
    expect(callbackCount, 0);
    expect(
      tester
          .widget<PositionedDirectional>(
            find.byKey(const ValueKey('liquid-glass-indicator-layer')),
          )
          .start,
      closeTo(4, 0.01),
    );
  });

  testWidgets('liquid cancellation reconciles the latest external selection', (
    tester,
  ) async {
    var selectedIndex = 0;
    var callbackCount = 0;
    StateSetter? rebuild;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            AppearanceTheme(
              isAndroid: true,
              floatingBottomBar: true,
              liquidGlass: true,
            ),
          ],
        ),
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Center(
              child: SizedBox(
                width: 240,
                child: LiquidToggleNavigationBar(
                  items: _liquidItems(),
                  selectedIndex: selectedIndex,
                  onSelected: (index) {
                    callbackCount++;
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LiquidToggleNavigationBar)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    rebuild!(() {
      selectedIndex = 2;
    });
    await tester.pump();
    rebuild!(() {
      selectedIndex = 0;
    });
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(selectedIndex, 0);
    expect(callbackCount, 0);
    expect(
      tester
          .widget<PositionedDirectional>(
            find.byKey(const ValueKey('liquid-glass-indicator-layer')),
          )
          .start,
      closeTo(4, 0.01),
    );
  });

  testWidgets('liquid rubber band stays bounded beyond both edges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            AppearanceTheme(
              isAndroid: true,
              floatingBottomBar: true,
              liquidGlass: true,
            ),
          ],
        ),
        home: Center(
          child: SizedBox(
            width: 240,
            child: LiquidToggleNavigationBar(
              items: _liquidItems(),
              selectedIndex: 0,
              onSelected: _ignoreSelection,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LiquidToggleNavigationBar)),
    );
    await gesture.moveBy(const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final panelOffset = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-panel-offset')),
    );
    expect(panelOffset.transform.storage[12].abs(), lessThanOrEqualTo(2.3));
    await gesture.moveBy(const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final rightOffset = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-panel-offset')),
    );
    expect(rightOffset.transform.storage[12].abs(), lessThanOrEqualTo(2.3));
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('liquid glass stays neutral while content carries state', (
    tester,
  ) async {
    const primary = Color(0xFFFF0000);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: primary),
          extensions: const [
            AppearanceTheme(
              isAndroid: true,
              floatingBottomBar: true,
              liquidGlass: true,
            ),
          ],
        ),
        home: Center(
          child: SizedBox(
            width: 240,
            child: LiquidToggleNavigationBar(
              items: _liquidItems(),
              selectedIndex: 0,
              onSelected: _ignoreSelection,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final surfaces = tester.widgetList<AndroidGlassSurface>(
      find.byType(AndroidGlassSurface),
    );
    expect(
      surfaces.every(
        (surface) =>
            surface.liquidAccentColor == Colors.transparent &&
            surface.surfaceColor != primary,
      ),
      true,
    );
    final selectedIconTheme = tester
        .widgetList<IconTheme>(
          find.ancestor(
            of: find.byKey(const ValueKey('liquid-navigation-item-content-0')),
            matching: find.byType(IconTheme),
          ),
        )
        .first;
    expect(selectedIconTheme.data.color, isNot(primary));
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
