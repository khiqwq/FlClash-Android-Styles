import 'dart:ui' show PointerDeviceKind;

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

List<NavigationItem> _items() {
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

class _ToggleHarness extends StatefulWidget {
  final int selectedIndex;
  final TextDirection textDirection;
  final bool acknowledgeSelections;
  final List<int> callbacks;

  const _ToggleHarness({
    super.key,
    required this.selectedIndex,
    required this.textDirection,
    required this.acknowledgeSelections,
    required this.callbacks,
  });

  @override
  State<_ToggleHarness> createState() => _ToggleHarnessState();
}

class _ToggleHarnessState extends State<_ToggleHarness> {
  late int selectedIndex;
  int itemCount = 3;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.selectedIndex;
  }

  void acknowledge(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void rebuild() {
    setState(() {});
  }

  void setItemCount(int value) {
    setState(() {
      itemCount = value;
    });
  }

  void update({int? selectedIndex, int? itemCount}) {
    setState(() {
      this.selectedIndex = selectedIndex ?? this.selectedIndex;
      this.itemCount = itemCount ?? this.itemCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        textDirection: widget.textDirection,
        child: Center(
          child: SizedBox(
            width: 240,
            child: LiquidToggleNavigationBar(
              items: _items().take(itemCount).toList(growable: false),
              selectedIndex: selectedIndex,
              onSelected: (index) {
                widget.callbacks.add(index);
                if (widget.acknowledgeSelections) {
                  acknowledge(index);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<GlobalKey<_ToggleHarnessState>> _pumpToggle(
  WidgetTester tester, {
  int selectedIndex = 0,
  TextDirection textDirection = TextDirection.ltr,
  bool acknowledgeSelections = true,
  List<int>? callbacks,
}) async {
  final key = GlobalKey<_ToggleHarnessState>();
  await tester.pumpWidget(
    _ToggleHarness(
      key: key,
      selectedIndex: selectedIndex,
      textDirection: textDirection,
      acknowledgeSelections: acknowledgeSelections,
      callbacks: callbacks ?? <int>[],
    ),
  );
  await tester.pump();
  return key;
}

Finder _item(int index) {
  return find.byKey(ValueKey('liquid-navigation-item-$index'));
}

Finder _semantics(int index) {
  return find.byKey(ValueKey('liquid-navigation-semantics-$index'));
}

Finder get _indicator {
  return find.byKey(const ValueKey('liquid-toggle-thumb-transform'));
}

double _indicatorScaleX(WidgetTester tester) {
  return tester.widget<Transform>(_indicator).transform.storage[0];
}

void main() {
  testWidgets('real Home liquid bar has bounds and supports LTR and RTL taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semanticsHandle = tester.ensureSemantics();

    for (final direction in TextDirection.values) {
      final container = ProviderContainer(
        overrides: [
          navigationItemsStateProvider.overrideWithValue(
            NavigationItemsState(value: _items()),
          ),
        ],
      );
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(390, 800);

      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
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
                textDirection: direction,
                child: const HomePage(isAndroid: true),
              ),
            ),
          ),
        );
        await tester.pump();

        final bar = find.byKey(const ValueKey('liquid-toggle-navigation'));
        expect(tester.getSize(bar).width, 248);
        for (var index = 0; index < _items().length; index++) {
          final rect = tester.getSemantics(_semantics(index)).rect;
          expect(rect.width, greaterThan(0));
          expect(rect.height, greaterThan(0));
        }

        await tester.tapAt(tester.getCenter(_semantics(2)));
        await tester.pumpAndSettle();
        expect(container.read(currentPageLabelProvider), PageLabel.logs);
        await tester.tapAt(tester.getCenter(_semantics(0)));
        await tester.pumpAndSettle();
        expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
    semanticsHandle.dispose();
  });

  testWidgets(
    'pointer slop uses cumulative displacement and axis arbitration',
    (tester) async {
      var callbacks = <int>[];
      await _pumpToggle(tester, callbacks: callbacks);
      final jitter = await tester.startGesture(tester.getCenter(_item(1)));
      await jitter.moveBy(const Offset(1, 0));
      await jitter.up();
      await tester.pumpAndSettle();
      expect(callbacks, [1]);

      callbacks = <int>[];
      await _pumpToggle(tester, callbacks: callbacks);
      final cumulative = await tester.startGesture(
        tester.getCenter(_indicator),
      );
      await cumulative.moveBy(const Offset(10, 0));
      await tester.pump();
      expect(callbacks, isEmpty);
      await cumulative.moveBy(const Offset(10, 0));
      await cumulative.up();
      await tester.pumpAndSettle();
      expect(callbacks, [1]);

      callbacks = <int>[];
      await _pumpToggle(tester, callbacks: callbacks);
      final vertical = await tester.startGesture(tester.getCenter(_indicator));
      await vertical.moveBy(const Offset(5, 20));
      await vertical.moveBy(const Offset(40, 0));
      await vertical.up();
      await tester.pumpAndSettle();
      expect(callbacks, isEmpty);

      callbacks = <int>[];
      await _pumpToggle(tester, callbacks: callbacks);
      final touch = await tester.startGesture(tester.getCenter(_indicator));
      await touch.moveBy(const Offset(11, 0));
      await touch.up();
      await tester.pumpAndSettle();
      expect(callbacks, isEmpty);

      callbacks = <int>[];
      await _pumpToggle(tester, callbacks: callbacks);
      final mouse = await tester.startGesture(
        tester.getCenter(_indicator),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(11, 0));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(callbacks, [1]);

      callbacks = <int>[];
      await _pumpToggle(
        tester,
        textDirection: TextDirection.rtl,
        callbacks: callbacks,
      );
      final rtl = await tester.startGesture(tester.getCenter(_indicator));
      await rtl.moveBy(const Offset(-10, 0));
      await rtl.moveBy(const Offset(-10, 0));
      await rtl.up();
      await tester.pumpAndSettle();
      expect(callbacks, [1]);
    },
  );

  testWidgets(
    'release ownership survives no-op, rapid, cancel, and multi-touch',
    (tester) async {
      final callbacks = <int>[];
      await _pumpToggle(tester, callbacks: callbacks);

      await tester.tapAt(tester.getCenter(_item(0)));
      await tester.pumpAndSettle();
      expect(callbacks, isEmpty);
      expect(_indicatorScaleX(tester), closeTo(1, 0.01));

      await tester.tap(_item(1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.tap(_item(2));
      await tester.pumpAndSettle();
      expect(callbacks, [1, 2]);
      expect(_indicatorScaleX(tester), closeTo(1, 0.01));

      await tester.tap(_item(1));
      await tester.pump(const Duration(milliseconds: 1));
      final pendingRelease = await tester.startGesture(
        tester.getCenter(_item(0)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(_indicatorScaleX(tester), greaterThan(1.4));
      await pendingRelease.cancel();
      await tester.pumpAndSettle();
      expect(callbacks, [1, 2, 1]);
      expect(_indicatorScaleX(tester), closeTo(1, 0.01));

      final primary = await tester.startGesture(
        tester.getCenter(_indicator),
        pointer: 1,
      );
      final secondary = await tester.startGesture(
        tester.getCenter(_item(2)),
        pointer: 2,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(_indicatorScaleX(tester), greaterThan(1.4));
      await primary.cancel();
      await secondary.up();
      await tester.pumpAndSettle();
      expect(callbacks, [1, 2, 1]);
      expect(_indicatorScaleX(tester), closeTo(1, 0.01));

      final canceledDrag = await tester.startGesture(
        tester.getCenter(_indicator),
      );
      await canceledDrag.moveBy(const Offset(20, 0));
      await canceledDrag.cancel();
      await tester.pumpAndSettle();
      expect(callbacks, [1, 2, 1, 2]);
      expect(_indicatorScaleX(tester), closeTo(1, 0.01));
    },
  );

  testWidgets('active pointer disposal cancels pending release ownership', (
    tester,
  ) async {
    await _pumpToggle(tester);
    final gesture = await tester.startGesture(tester.getCenter(_indicator));
    await tester.pump(const Duration(milliseconds: 80));

    await tester.pumpWidget(const SizedBox.shrink());
    await gesture.cancel();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('parent acknowledgement preserves reverse tap timing', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final callbacks = <int>[];
    final key = await _pumpToggle(
      tester,
      acknowledgeSelections: false,
      callbacks: callbacks,
    );

    await tester.tap(_item(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(callbacks, [1]);

    final reverse = await tester.startGesture(tester.getCenter(_item(0)));
    key.currentState!.rebuild();
    await tester.pump();
    key.currentState!.acknowledge(1);
    await tester.pump();
    await reverse.up();
    await tester.pumpAndSettle();

    expect(callbacks, [1, 0]);
    semanticsHandle.dispose();
    expect(
      tester
          .getSemantics(_semantics(0))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );

    callbacks.clear();
    final acknowledgedKey = await _pumpToggle(tester, callbacks: callbacks);
    await tester.tap(_item(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(callbacks, [1]);

    final reverseAfterAcknowledgement = await tester.startGesture(
      tester.getCenter(_item(0)),
    );
    acknowledgedKey.currentState!.acknowledge(1);
    await tester.pump();
    await reverseAfterAcknowledgement.up();
    await tester.pumpAndSettle();

    expect(callbacks, [1, 0]);
  });

  testWidgets('pending selection survives an unchanged parent rebuild', (
    tester,
  ) async {
    final callbacks = <int>[];
    final key = await _pumpToggle(
      tester,
      acknowledgeSelections: false,
      callbacks: callbacks,
    );

    await tester.tap(_item(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(callbacks, [1]);

    key.currentState!.rebuild();
    await tester.pump();
    await tester.tapAt(tester.getCenter(_item(0)));
    await tester.pumpAndSettle();

    expect(callbacks, [1, 0]);
  });

  testWidgets('stale acknowledgement cannot override a completed reverse tap', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final callbacks = <int>[];
    final key = await _pumpToggle(
      tester,
      acknowledgeSelections: false,
      callbacks: callbacks,
    );

    await tester.tap(_item(1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tapAt(tester.getCenter(_item(0)));
    await tester.pumpAndSettle();
    expect(callbacks, [1, 0]);

    key.currentState!.acknowledge(1);
    await tester.pump();
    expect(
      tester
          .getSemantics(_semantics(0))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );

    key.currentState!.acknowledge(0);
    await tester.pumpAndSettle();
    expect(callbacks, [1, 0]);
    expect(
      tester
          .getSemantics(_semantics(0))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );
    semanticsHandle.dispose();
  });

  testWidgets('pending selection reconciles when items shrink', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final callbacks = <int>[];
    final key = await _pumpToggle(
      tester,
      acknowledgeSelections: false,
      callbacks: callbacks,
    );

    await tester.tap(_item(2));
    await tester.pump(const Duration(milliseconds: 1));
    expect(callbacks, [2]);

    key.currentState!.setItemCount(2);
    await tester.pump();

    expect(_item(2), findsNothing);
    key.currentState!.acknowledge(2);
    await tester.pump();
    expect(
      tester
          .getSemantics(_semantics(0))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );
    expect(
      tester
          .getSemantics(_semantics(1))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      false,
    );

    await tester.tap(_item(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(callbacks, [2, 1]);
    expect(
      tester
          .getSemantics(_semantics(1))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );

    key.currentState!.acknowledge(1);
    await tester.pumpAndSettle();
    expect(callbacks, [2, 1]);
    expect(
      tester
          .getSemantics(_semantics(1))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );
    semanticsHandle.dispose();
  });

  testWidgets('removed pending index ignores simultaneous stale ack', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final callbacks = <int>[];
    final key = await _pumpToggle(
      tester,
      acknowledgeSelections: false,
      callbacks: callbacks,
    );

    await tester.tap(_item(2));
    await tester.pump(const Duration(milliseconds: 1));
    expect(callbacks, [2]);

    key.currentState!.update(selectedIndex: 2, itemCount: 2);
    await tester.pumpAndSettle();

    expect(_item(2), findsNothing);
    expect(
      tester
          .getSemantics(_semantics(0))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );
    semanticsHandle.dispose();
  });

  testWidgets('regrown items accept a later authoritative selection', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final callbacks = <int>[];
    final key = await _pumpToggle(
      tester,
      acknowledgeSelections: false,
      callbacks: callbacks,
    );

    await tester.tap(_item(2));
    await tester.pump(const Duration(milliseconds: 1));
    key.currentState!.setItemCount(2);
    await tester.pump();
    key.currentState!.acknowledge(2);
    await tester.pump();
    expect(
      tester
          .getSemantics(_semantics(0))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );

    key.currentState!.update(selectedIndex: 0, itemCount: 3);
    await tester.pump();
    key.currentState!.acknowledge(2);
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(_semantics(2))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      true,
    );
    semanticsHandle.dispose();
  });

  testWidgets('unselected Liquid content keeps readable contrast', (
    tester,
  ) async {
    await _pumpToggle(tester);
    final iconTheme = tester.widget<IconTheme>(
      find.descendant(of: _item(1), matching: find.byType(IconTheme)).last,
    );
    final foreground = iconTheme.data.color!;
    final track = const Color(0xFF787878).withValues(alpha: 0.2);
    final background = Color.alphaBlend(track, Colors.white);
    final paintedForeground = Color.alphaBlend(foreground, background);
    final lighter = paintedForeground.computeLuminance() + 0.05;
    final darker = background.computeLuminance() + 0.05;
    final contrast = lighter > darker ? lighter / darker : darker / lighter;
    expect(contrast, greaterThanOrEqualTo(4.5));
  });

  testWidgets('selected Liquid labels keep contrast through press motion', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final colorScheme = miuixDefaultColorScheme(brightness);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(brightness),
          theme: ThemeData(
            brightness: brightness,
            colorScheme: colorScheme,
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
                items: _items(),
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      void expectContrast() {
        final label = tester.widget<Text>(
          find.byKey(const ValueKey('liquid-accent-label-selected')),
        );
        final surface = tester.widget<AndroidGlassSurface>(
          find.byKey(const ValueKey('liquid-indicator-surface')),
        );
        final track = brightness == Brightness.dark
            ? const Color(0xFF787880).withValues(alpha: 0.36)
            : const Color(0xFF787878).withValues(alpha: 0.2);
        final trackBackground = Color.alphaBlend(track, colorScheme.surface);
        final surfaceBase = brightness == Brightness.dark
            ? colorScheme.surfaceContainer
            : Colors.white;
        final indicatorBackground = Color.alphaBlend(
          surfaceBase.withValues(alpha: 1 - surface.liquidProgress),
          trackBackground,
        );
        final foreground = label.style!.color!;
        final lighter = foreground.computeLuminance() + 0.05;
        final darker = indicatorBackground.computeLuminance() + 0.05;
        final contrast = lighter > darker ? lighter / darker : darker / lighter;
        expect(
          contrast,
          greaterThanOrEqualTo(4.5),
          reason:
              '$brightness foreground=${foreground.toARGB32().toRadixString(16)} indicator=${indicatorBackground.toARGB32().toRadixString(16)} surface=${surfaceBase.toARGB32().toRadixString(16)} progress=${surface.liquidProgress}',
        );
      }

      expectContrast();
      final gesture = await tester.startGesture(tester.getCenter(_indicator));
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectContrast();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expectContrast();
    }
  });

  testWidgets('thumb backdrop captures and transforms the complete track', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      for (var index = 0; index < _items().length; index++) {
        await _pumpToggle(
          tester,
          selectedIndex: index,
          textDirection: direction,
        );
        final root = find.byKey(const ValueKey('liquid-toggle-navigation'));
        final indicatorLayer = find.byKey(
          const ValueKey('liquid-glass-indicator-layer'),
        );
        final source = find.byKey(const ValueKey('liquid-toggle-track-source'));
        final translation = find.byKey(
          const ValueKey('liquid-toggle-track-source-translation'),
        );
        final scale = find.byKey(
          const ValueKey('liquid-toggle-track-source-scale'),
        );
        final rootSize = tester.getSize(root);
        final sourceSize = tester.getSize(source);
        final indicatorSize = tester.getSize(indicatorLayer);
        final indicatorLeft =
            tester.getTopLeft(indicatorLayer).dx - tester.getTopLeft(root).dx;
        final logicalStart = 2 + index * indicatorSize.width;
        final expectedIndicatorLeft = direction == TextDirection.ltr
            ? logicalStart
            : rootSize.width - logicalStart - indicatorSize.width;

        expect(sourceSize, rootSize);
        expect(indicatorLeft, closeTo(expectedIndicatorLeft, 0.01));
        expect(
          find.ancestor(of: source, matching: find.byType(ClipRRect)),
          findsOneWidget,
        );
        final translationMatrix = tester
            .widget<Transform>(translation)
            .transform;
        expect(translationMatrix.storage[12], closeTo(-indicatorLeft, 0.01));
        expect(translationMatrix.storage[13], closeTo(-2, 0.01));

        final scaleWidget = tester.widget<Transform>(scale);
        final pivot = scaleWidget.alignment! as FractionalOffset;
        expect(
          pivot.dx,
          closeTo(
            (indicatorLeft + indicatorSize.width / 2) / rootSize.width,
            0.001,
          ),
        );
        expect(pivot.dy, closeTo(0.5, 0.001));
        expect(scaleWidget.transform.storage[0], closeTo(2 / 3, 0.001));
        expect(scaleWidget.transform.storage[5], closeTo(0, 0.001));

        final gesture = await tester.startGesture(
          tester.getCenter(indicatorLayer),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        final pressedScale = tester.widget<Transform>(scale).transform;
        expect(pressedScale.storage[0], closeTo(0.75, 0.02));
        expect(pressedScale.storage[5], closeTo(0.75, 0.02));
        await gesture.up();
        await tester.pumpAndSettle();
      }
    }
  });
}
