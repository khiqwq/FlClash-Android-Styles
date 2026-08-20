import 'package:fl_clash/common/navigator.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile routes participate in Material predictive transitions', () {
    final route = CommonRoute<void>(builder: (_) => const SizedBox.shrink());

    expect(route, isA<MaterialPageRoute<void>>());
  });

  test('predictive back preference selects only the Android transition', () {
    final predictive = buildPageTransitionsTheme(predictiveBack: true);
    final legacy = buildPageTransitionsTheme(predictiveBack: false);

    expect(
      predictive.builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
    expect(
      legacy.builders[TargetPlatform.android],
      same(commonSharedXPageTransitions),
    );
    expect(
      predictive.builders[TargetPlatform.windows],
      same(legacy.builders[TargetPlatform.windows]),
    );
  });

  test('wide Android layouts still use Material routes', () {
    expect(
      shouldUseCommonDesktopRoute(isDesktop: false, isMobileView: false),
      false,
    );
    expect(
      shouldUseCommonDesktopRoute(isDesktop: true, isMobileView: false),
      true,
    );
  });

  test('Android Home keeps predictive routes on the root navigator', () {
    expect(
      shouldUseNestedHomeNavigator(isAndroid: true, isMobileView: true),
      false,
    );
    expect(
      shouldUseNestedHomeNavigator(isAndroid: true, isMobileView: false),
      false,
    );
    expect(
      shouldUseNestedHomeNavigator(isAndroid: false, isMobileView: false),
      true,
    );
    expect(
      shouldUseNestedHomeNavigator(isAndroid: false, isMobileView: true),
      false,
    );
  });

  testWidgets('wide Android Home has one predictive route owner', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigatorKey = GlobalKey<NavigatorState>();
      final container = ProviderContainer(
        overrides: [
          navigationItemsStateProvider.overrideWithValue(
            NavigationItemsState(
              value: [
                NavigationItem(
                  icon: const Icon(Icons.space_dashboard),
                  label: PageLabel.dashboard,
                  builder: (context) {
                    return Center(
                      child: TextButton(
                        onPressed: () {
                          BaseNavigator.push<void>(
                            context,
                            const Scaffold(body: Text('root destination')),
                            isDesktop: false,
                          );
                        },
                        child: const Text('open root route'),
                      ),
                    );
                  },
                ),
                NavigationItem(
                  icon: const Icon(Icons.construction),
                  label: PageLabel.tools,
                  builder: (_) => const Center(child: Text('tools page')),
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(1200, 800);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            theme: ThemeData(
              pageTransitionsTheme: buildPageTransitionsTheme(
                predictiveBack: true,
              ),
            ),
            home: const HomePage(isAndroid: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Navigator), findsOneWidget);
      await tester.tap(find.text('open root route'));
      await tester.pumpAndSettle();
      expect(find.byType(Navigator), findsOneWidget);
      expect(navigatorKey.currentState?.canPop(), isTrue);

      container.read(currentPageLabelProvider.notifier).toPage(PageLabel.tools);
      await tester.pumpAndSettle();
      expect(container.read(currentPageLabelProvider), PageLabel.tools);

      expect(
        await _sendBackGesture(tester, 'startBackGesture', progress: 0),
        true,
      );
      await _sendBackGesture(
        tester,
        'updateBackGestureProgress',
        progress: 0.5,
      );
      await tester.pump();
      expect(find.text('root destination'), findsOneWidget);
      expect(find.text('tools page'), findsOneWidget);
      expect(container.read(currentPageLabelProvider), PageLabel.tools);

      await _sendBackGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('root destination'), findsOneWidget);
      expect(container.read(currentPageLabelProvider), PageLabel.tools);

      await _sendBackGesture(tester, 'startBackGesture', progress: 0);
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('root destination'), findsNothing);
      expect(find.text('tools page'), findsOneWidget);
      expect(container.read(currentPageLabelProvider), PageLabel.tools);
      expect(navigatorKey.currentState?.canPop(), isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('predictive route progress cancels back to the current page', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_buildPredictiveBackApp());
      await tester.tap(find.text('source'));
      await tester.pumpAndSettle();

      final initialOffset = tester.getTopLeft(find.text('destination'));
      expect(find.text('source', skipOffstage: false), findsOneWidget);

      expect(
        await _sendBackGesture(tester, 'startBackGesture', progress: 0),
        true,
      );
      await _sendBackGesture(
        tester,
        'updateBackGestureProgress',
        progress: 0.4,
      );
      await tester.pump();

      expect(
        tester.getTopLeft(find.text('destination')).dx,
        greaterThan(initialOffset.dx),
      );
      expect(find.text('source'), findsOneWidget);

      await _sendBackGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsOneWidget);
      expect(tester.getTopLeft(find.text('destination')), initialOffset);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('predictive cancel leaves route identity unchanged', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var completed = false;
      final observer = _CountingNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          theme: ThemeData(
            pageTransitionsTheme: buildPageTransitionsTheme(
              predictiveBack: true,
            ),
          ),
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        CommonRoute<void>(
                          builder: (_) =>
                              const Scaffold(body: Text('destination')),
                        ),
                      )
                      .then((_) {
                        completed = true;
                      });
                },
                child: const Text('source'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('source'));
      await tester.pumpAndSettle();
      observer.reset();

      expect(
        await _sendBackGesture(tester, 'startBackGesture', progress: 0),
        true,
      );
      await _sendBackGesture(
        tester,
        'updateBackGestureProgress',
        progress: 0.5,
      );
      await tester.pump();
      expect(find.text('source'), findsOneWidget);
      expect(find.text('destination', skipOffstage: false), findsOneWidget);
      expect(completed, isFalse);
      expect(observer.popCount, 0);

      await _sendBackGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsOneWidget);
      expect(find.text('source'), findsNothing);
      expect(completed, isFalse);
      expect(observer.popCount, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('predictive commit pops once with the route current result', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      String? result;
      final observer = _CountingNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          theme: ThemeData(
            pageTransitionsTheme: buildPageTransitionsTheme(
              predictiveBack: true,
            ),
          ),
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  final route = CommonRoute<String>(
                    builder: (_) => Builder(
                      builder: (context) {
                        final modalRoute = ModalRoute.of(context);
                        if (modalRoute case final CommonRouteResultHost host) {
                          host.updateCurrentResult('committed');
                        }
                        return const Scaffold(body: Text('destination'));
                      },
                    ),
                  );
                  result = await Navigator.of(context).push(route);
                },
                child: const Text('source'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('source'));
      await tester.pumpAndSettle();
      observer.reset();

      expect(
        await _sendBackGesture(tester, 'startBackGesture', progress: 0),
        true,
      );
      await _sendBackGesture(
        tester,
        'updateBackGestureProgress',
        progress: 0.5,
      );
      await tester.pump();
      expect(find.text('destination'), findsOneWidget);
      expect(find.text('source'), findsOneWidget);
      expect(result, isNull);
      expect(observer.popCount, 0);

      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsNothing);
      expect(find.text('source'), findsOneWidget);
      expect(result, 'committed');
      expect(observer.popCount, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('blocked local back is consumed without a route pop', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            pageTransitionsTheme: buildPageTransitionsTheme(
              predictiveBack: true,
            ),
          ),
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    CommonRoute<void>(
                      builder: (_) => CommonPopScope(
                        canPop: false,
                        onPop: (_) {
                          attempts++;
                        },
                        child: const Scaffold(body: Text('local state')),
                      ),
                    ),
                  );
                },
                child: const Text('open local state'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open local state'));
      await tester.pumpAndSettle();

      expect(
        await _sendBackGesture(tester, 'startBackGesture', progress: 0),
        false,
      );
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('local state'), findsOneWidget);
      expect(attempts, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('local history consumes commit before the route can pop', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var layerRemoved = 0;
      var popAttempts = 0;
      final observer = _CountingNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          theme: ThemeData(
            pageTransitionsTheme: buildPageTransitionsTheme(
              predictiveBack: true,
            ),
          ),
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    CommonRoute<void>(
                      builder: (_) => CommonPopScope(
                        onPop: (_) {
                          popAttempts++;
                        },
                        child: _LocalHistoryHost(
                          onRemoved: () {
                            layerRemoved++;
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open local history'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open local history'));
      await tester.pumpAndSettle();
      observer.reset();
      expect(find.text('local layer'), findsOneWidget);

      expect(
        await _sendBackGesture(tester, 'startBackGesture', progress: 0),
        false,
      );
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('route'), findsOneWidget);
      expect(layerRemoved, 1);
      expect(popAttempts, 0);
      expect(observer.popCount, 0);

      expect(
        await _sendBackGesture(tester, 'startBackGesture', progress: 0),
        true,
      );
      await _sendBackGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('route'), findsOneWidget);
      expect(observer.popCount, 0);

      expect(
        await _sendBackGesture(tester, 'startBackGesture', progress: 0),
        true,
      );
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('route'), findsNothing);
      expect(observer.popCount, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android Home root leaves back handling to the system', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeBackScopeContainer(isAndroid: true, child: Text('root')),
          ),
        ),
      );

      expect(find.text('root'), findsOneWidget);
      expect(find.byType(PopScope), findsNothing);
      expect(
        await _sendBackGesture(tester, 'startBackGesture', progress: 0),
        false,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _buildPredictiveBackApp() {
  return MaterialApp(
    theme: ThemeData(
      pageTransitionsTheme: buildPageTransitionsTheme(predictiveBack: true),
    ),
    home: Builder(
      builder: (context) {
        return TextButton(
          onPressed: () {
            Navigator.of(context).push(
              CommonRoute<void>(
                builder: (_) => const Scaffold(body: Text('destination')),
              ),
            );
          },
          child: const Text('source'),
        );
      },
    ),
  );
}

Future<Object?> _sendBackGesture(
  WidgetTester tester,
  String method, {
  double? progress,
}) async {
  final arguments = progress == null
      ? null
      : <String, Object>{
          'touchOffset': <double>[80, 300],
          'progress': progress,
          'swipeEdge': 0,
        };
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  ByteData? response;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (data) {
      response = data;
    },
  );
  final data = response;
  if (data == null) {
    return null;
  }
  return const StandardMethodCodec().decodeEnvelope(data);
}

class _CountingNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  void reset() {
    popCount = 0;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}

class _LocalHistoryHost extends StatefulWidget {
  final VoidCallback onRemoved;

  const _LocalHistoryHost({required this.onRemoved});

  @override
  State<_LocalHistoryHost> createState() => _LocalHistoryHostState();
}

class _LocalHistoryHostState extends State<_LocalHistoryHost> {
  var _hasLayer = true;

  @override
  Widget build(BuildContext context) {
    if (!_hasLayer) {
      return const Scaffold(body: Text('route'));
    }
    return BackLayerScope(
      onBack: () {
        widget.onRemoved();
        setState(() {
          _hasLayer = false;
        });
      },
      child: const Scaffold(body: Text('local layer')),
    );
  }
}
