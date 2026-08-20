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

  Future<void> pumpLiquid(
    WidgetTester tester, {
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    TextDirection textDirection = TextDirection.ltr,
    double width = 240,
  }) async {
    var currentIndex = selectedIndex;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          extensions: const [
            AppearanceTheme(
              isAndroid: true,
              floatingBottomBar: true,
              liquidGlass: true,
            ),
          ],
        ),
        home: Directionality(
          textDirection: textDirection,
          child: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                return SizedBox(
                  width: width,
                  child: LiquidToggleNavigationBar(
                    items: _liquidItems(),
                    selectedIndex: currentIndex,
                    onSelected: (index) {
                      currentIndex = index;
                      onSelected(index);
                      setState(() {});
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

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
  });

  testWidgets('liquid navigation uses only the source track and thumb layers', (
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

    final bar = find.byType(LiquidToggleNavigationBar);
    expect(bar, findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.byType(AndroidGlassSurface)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.byType(BackdropFilter)),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('liquid-toggle-track-backdrop-filter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('liquid-glass-panel-layer')),
      findsNothing,
    );
    expect(
      find.ancestor(of: bar, matching: find.byType(AndroidGlassSurface)),
      findsNothing,
    );
    expect(
      tester
          .widget<AndroidGlassSurface>(find.byType(AndroidGlassSurface))
          .liquidAccentColor,
      Colors.transparent,
    );
    expect(
      tester
          .widget<AndroidGlassSurface>(find.byType(AndroidGlassSurface))
          .liquidRefractionHeight,
      0,
    );
    expect(
      tester
          .widget<PositionedDirectional>(
            find.byKey(const ValueKey('liquid-glass-indicator-layer')),
          )
          .top,
      2,
    );
    expect(
      tester
          .widget<PositionedDirectional>(
            find.byKey(const ValueKey('liquid-glass-indicator-layer')),
          )
          .height,
      60,
    );
    expect(
      find.byKey(const ValueKey('liquid-glass-accent-content-layer')),
      findsOneWidget,
    );
  });

  testWidgets('liquid items support direct, current, and rapid taps', (
    tester,
  ) async {
    var selectedIndex = 0;
    final callbacks = <int>[];
    await pumpLiquid(
      tester,
      selectedIndex: selectedIndex,
      onSelected: (index) {
        callbacks.add(index);
        selectedIndex = index;
      },
    );

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
      closeTo(2, 0.01),
    );
  });

  testWidgets('liquid destinations retain selected and tap semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selectedIndex = 0;
    final callbacks = <int>[];
    await pumpLiquid(
      tester,
      selectedIndex: selectedIndex,
      onSelected: (index) {
        callbacks.add(index);
        selectedIndex = index;
      },
    );

    final selectedNode = tester.getSemantics(
      find.byKey(const ValueKey('liquid-navigation-semantics-0')),
    );
    final unselectedNode = tester.getSemantics(
      find.byKey(const ValueKey('liquid-navigation-semantics-1')),
    );
    expect(
      selectedNode.getSemanticsData().flagsCollection.isSelected.toBoolOrNull(),
      true,
    );
    expect(
      selectedNode.getSemanticsData().hasAction(SemanticsAction.tap),
      true,
    );
    expect(
      unselectedNode
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      false,
    );
    unselectedNode.owner!.performAction(unselectedNode.id, SemanticsAction.tap);
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);
    expect(callbacks, [1]);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('liquid-navigation-semantics-1')),
          )
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );
    semantics.dispose();
  });

  testWidgets('liquid drag is owned only by the active indicator', (
    tester,
  ) async {
    var selectedIndex = 0;
    final callbacks = <int>[];
    await pumpLiquid(
      tester,
      selectedIndex: selectedIndex,
      onSelected: (index) {
        callbacks.add(index);
        selectedIndex = index;
      },
    );

    final nonCurrent = find.byKey(const ValueKey('liquid-navigation-item-2'));
    final before = tester
        .widget<PositionedDirectional>(
          find.byKey(const ValueKey('liquid-glass-indicator-layer')),
        )
        .start;
    final gesture = await tester.startGesture(tester.getCenter(nonCurrent));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectedIndex, 0);
    expect(callbacks, isEmpty);
    expect(
      tester
          .widget<PositionedDirectional>(
            find.byKey(const ValueKey('liquid-glass-indicator-layer')),
          )
          .start,
      closeTo(before!, 0.01),
    );
  });

  testWidgets(
    'liquid press uses the source 1.5 scale and releases near target',
    (tester) async {
      var selectedIndex = 0;
      await pumpLiquid(
        tester,
        selectedIndex: selectedIndex,
        onSelected: (index) => selectedIndex = index,
      );

      final indicator = find.byKey(
        const ValueKey('liquid-toggle-thumb-transform'),
      );
      final gesture = await tester.startGesture(tester.getCenter(indicator));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final pressed = tester.widget<Transform>(indicator).transform;
      expect(pressed.storage[0], closeTo(1.5, 0.03));
      expect(pressed.storage[5], closeTo(1.5, 0.03));

      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      final releasing = tester.widget<Transform>(indicator).transform;
      expect(releasing.storage[0], greaterThan(1));
      await tester.pump(const Duration(milliseconds: 160));
      final releasedNearTarget = tester.widget<Transform>(indicator).transform;
      expect(
        releasedNearTarget.storage[0],
        lessThanOrEqualTo(releasing.storage[0]),
      );
      expect(releasedNearTarget.storage[0], greaterThan(1));
      await tester.pumpAndSettle();
      expect(selectedIndex, 1);
    },
  );

  testWidgets('liquid drag follows RTL destination order', (tester) async {
    var selectedIndex = 0;
    await pumpLiquid(
      tester,
      selectedIndex: selectedIndex,
      textDirection: TextDirection.rtl,
      onSelected: (index) => selectedIndex = index,
    );

    final indicator = find.byKey(
      const ValueKey('liquid-toggle-thumb-transform'),
    );
    final gesture = await tester.startGesture(tester.getCenter(indicator));
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selectedIndex, 1);
  });

  testWidgets('liquid drag cancellation uses the source release callback', (
    tester,
  ) async {
    var selectedIndex = 0;
    final callbacks = <int>[];
    await pumpLiquid(
      tester,
      selectedIndex: selectedIndex,
      onSelected: (index) {
        callbacks.add(index);
        selectedIndex = index;
      },
    );

    final indicator = find.byKey(
      const ValueKey('liquid-toggle-thumb-transform'),
    );
    final gesture = await tester.startGesture(tester.getCenter(indicator));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(selectedIndex, 2);
    expect(callbacks, [2]);
  });

  testWidgets('external selection remains authoritative after rapid taps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
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
    rebuild!(() {
      selectedIndex = 1;
    });
    await tester.pump(const Duration(milliseconds: 64));
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('liquid-navigation-semantics-1')),
          )
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );
    rebuild!(() {
      selectedIndex = 2;
    });
    await tester.pumpAndSettle();

    expect(callbacks, [1, 2]);
    expect(selectedIndex, 2);
    semantics.dispose();
  });

  testWidgets('deferred external selection survives a canceled direct tap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
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

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('liquid-navigation-item-2'))),
    );
    rebuild!(() {
      selectedIndex = 1;
    });
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(callbacks, isEmpty);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('liquid-navigation-semantics-1')),
          )
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );
    semantics.dispose();
  });

  testWidgets('liquid glass keeps neutral surfaces and primary content', (
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
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final trackColor = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('liquid-toggle-track-color')),
    );
    expect(trackColor.color, const Color(0xFF787878).withValues(alpha: 0.2));
    final surface = tester.widget<AndroidGlassSurface>(
      find.byType(AndroidGlassSurface),
    );
    expect(surface.liquidAccentColor, Colors.transparent);
    expect(surface.surfaceColor, isNot(primary));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('liquid-glass-accent-content-layer')),
        matching: find.byType(IconTheme),
      ),
      findsWidgets,
    );
    final accent = tester
        .widgetList<IconTheme>(
          find.descendant(
            of: find.byKey(const ValueKey('liquid-glass-accent-content-layer')),
            matching: find.byType(IconTheme),
          ),
        )
        .any((theme) => theme.data.color == primary);
    expect(accent, true);
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
