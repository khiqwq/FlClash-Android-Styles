import 'dart:ui' show SemanticsAction;

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
    final thumb = surfaces.firstWhere((surface) => !identical(surface, panel));

    expect(find.byType(LiquidToggleNavigationBar), findsOneWidget);
    expect(find.byType(MiuixBottomNavigationBar), findsNothing);
    expect(panel.liquidGlass, true);
    expect(panel.liquidProgress, 1);
    expect(panel.scaleLiquidBlurWithProgress, false);
    expect(panel.liquidAccentColor, Colors.transparent);
    expect(thumb.liquidProgress, 0);
    expect(thumb.liquidRefractionHeight, 0);
    expect(thumb.liquidRefractionAmount, 0);
    expect(thumb.liquidChromaticAberration, 0.5);
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
      find.ancestor(
        of: find.byType(LiquidToggleNavigationBar),
        matching: find.byType(AndroidGlassSurface),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(LiquidToggleNavigationBar),
        matching: find.byType(Material),
      ),
      findsOneWidget,
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
    expect(contentLayerIndex, lessThan(indicatorLayerIndex));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('liquid-glass-indicator-layer')),
        matching: find.byKey(
          const ValueKey('liquid-glass-accent-content-layer'),
        ),
      ),
      findsOneWidget,
    );

    final secondItem = find.byKey(const ValueKey('liquid-navigation-item-1'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('liquid-navigation-item-0'))),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final pressedPanelTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-panel-transform')),
    );
    final pressedThumbTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-thumb-transform')),
    );
    final pressedItemTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-indicator-content-transform-0')),
    );
    expect(pressedPanelTransform.transform.storage[0], greaterThan(1));
    expect(pressedThumbTransform.transform.storage[0], greaterThanOrEqualTo(1));
    expect(pressedThumbTransform.transform.storage[5], greaterThanOrEqualTo(1));
    expect(pressedItemTransform.transform.storage[0], greaterThanOrEqualTo(1));
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
      greaterThan(0),
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
      greaterThan(1),
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

  testWidgets('liquid items support direct, current, and rapid taps', (
    tester,
  ) async {
    var selectedIndex = 0;
    final callbacks = <int>[];
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
                    callbacks.add(index);
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

    await tester.tap(find.byKey(const ValueKey('liquid-navigation-item-1')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(selectedIndex, 1);
    expect(callbacks, [1]);

    await tester.tap(find.byKey(const ValueKey('liquid-navigation-item-1')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(selectedIndex, 1);
    expect(callbacks, [1]);

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('liquid-navigation-item-2'))),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('liquid-navigation-item-0'))),
    );
    await tester.pumpAndSettle();

    expect(selectedIndex, 0);
    expect(callbacks, [1, 2, 0]);
    expect(
      tester
          .widget<PositionedDirectional>(
            find.byKey(const ValueKey('liquid-glass-indicator-layer')),
          )
          .start,
      closeTo(4, 0.01),
    );
  });

  testWidgets('liquid item tap updates the Home route and indicator', (
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

    await tester.tap(find.byKey(const ValueKey('liquid-navigation-item-1')));
    await tester.pumpAndSettle();

    expect(container.read(currentPageLabelProvider), PageLabel.tools);
    expect(
      tester
          .widget<LiquidToggleNavigationBar>(
            find.byType(LiquidToggleNavigationBar),
          )
          .selectedIndex,
      1,
    );
    expect(
      tester
          .widget<PositionedDirectional>(
            find.byKey(const ValueKey('liquid-glass-indicator-layer')),
          )
          .start,
      greaterThan(4),
    );
  });

  testWidgets('liquid semantic taps follow the same selection contract', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selectedIndex = 0;
    final callbacks = <int>[];
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
                    callbacks.add(index);
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

    void semanticTap(int index) {
      final node = tester.getSemantics(
        find.byKey(ValueKey('liquid-navigation-item-$index')),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), true);
      node.owner!.performAction(node.id, SemanticsAction.tap);
    }

    semanticTap(1);
    await tester.pump(const Duration(milliseconds: 1));
    semanticTap(1);
    await tester.pump(const Duration(milliseconds: 1));
    semanticTap(2);
    await tester.pump(const Duration(milliseconds: 1));
    semanticTap(0);
    await tester.pumpAndSettle();

    expect(selectedIndex, 0);
    expect(callbacks, [1, 2, 0]);
    semantics.dispose();
  });

  testWidgets('liquid latest tap ignores stale provider acknowledgements', (
    tester,
  ) async {
    var selectedIndex = 0;
    final callbacks = <int>[];
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
                  onSelected: callbacks.add,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('liquid-navigation-item-1')));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.byKey(const ValueKey('liquid-navigation-item-2')));
    await tester.pump(const Duration(milliseconds: 32));
    final beforeStale = tester
        .widget<PositionedDirectional>(
          find.byKey(const ValueKey('liquid-glass-indicator-layer')),
        )
        .start!;

    rebuild!(() {
      selectedIndex = 1;
    });
    await tester.pump(const Duration(milliseconds: 64));
    final afterStale = tester
        .widget<PositionedDirectional>(
          find.byKey(const ValueKey('liquid-glass-indicator-layer')),
        )
        .start!;
    expect(afterStale, greaterThanOrEqualTo(beforeStale));

    rebuild!(() {
      selectedIndex = 2;
    });
    await tester.pumpAndSettle();

    expect(callbacks, [1, 2]);
    expect(
      tester
          .widget<PositionedDirectional>(
            find.byKey(const ValueKey('liquid-glass-indicator-layer')),
          )
          .start,
      closeTo(4 + (240 - 8) / 3 * 2, 0.01),
    );
    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-thumb-transform')),
    );
    expect(transform.transform.storage[0], closeTo(1, 0.001));
    expect(transform.transform.storage[5], closeTo(1, 0.001));
  });

  testWidgets('liquid release shrinks while position spring converges', (
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
        home: StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: SizedBox(
                width: 240,
                child: LiquidToggleNavigationBar(
                  items: _liquidItems(),
                  selectedIndex: selectedIndex,
                  onSelected: (index) {
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

    final barTopLeft = tester.getTopLeft(
      find.byType(LiquidToggleNavigationBar),
    );
    final gesture = await tester.startGesture(
      barTopLeft + const Offset(20, 32),
    );
    await tester.pump(const Duration(milliseconds: 160));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('liquid-navigation-item-1'))),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final beforeReleaseScale = tester
        .widget<Transform>(
          find.byKey(const ValueKey('liquid-toggle-thumb-transform')),
        )
        .transform
        .storage[0];
    final beforeReleaseStart = tester
        .widget<PositionedDirectional>(
          find.byKey(const ValueKey('liquid-glass-indicator-layer')),
        )
        .start!;
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    final firstFrameStart = tester
        .widget<PositionedDirectional>(
          find.byKey(const ValueKey('liquid-glass-indicator-layer')),
        )
        .start!;
    expect(firstFrameStart, greaterThanOrEqualTo(beforeReleaseStart));

    await tester.pump(const Duration(milliseconds: 160));
    final releasingScale = tester
        .widget<Transform>(
          find.byKey(const ValueKey('liquid-toggle-thumb-transform')),
        )
        .transform
        .storage[0];
    expect(releasingScale, lessThan(beforeReleaseScale));
    expect(releasingScale, greaterThan(1));
    await tester.pumpAndSettle();
    expect(selectedIndex, 1);
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
    expect(panelOffset.transform.storage[12].abs(), lessThanOrEqualTo(4.01));
    await gesture.moveBy(const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final rightOffset = tester.widget<Transform>(
      find.byKey(const ValueKey('liquid-toggle-panel-offset')),
    );
    expect(rightOffset.transform.storage[12].abs(), lessThanOrEqualTo(4.01));
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
          colorScheme: ColorScheme.fromSeed(
            seedColor: primary,
          ).copyWith(primary: primary),
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
    expect(
      tester
          .widgetList<IconTheme>(
            find.descendant(
              of: find.byKey(
                const ValueKey('liquid-glass-accent-content-layer'),
              ),
              matching: find.byType(IconTheme),
            ),
          )
          .any((iconTheme) => iconTheme.data.color == primary),
      true,
    );
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
