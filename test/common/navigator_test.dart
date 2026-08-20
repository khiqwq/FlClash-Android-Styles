import 'package:fl_clash/common/navigator.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

      await _sendBackGesture(tester, 'startBackGesture', progress: 0);
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
      expect(find.text('source', skipOffstage: false), findsOneWidget);

      await _sendBackGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsOneWidget);
      expect(tester.getTopLeft(find.text('destination')), initialOffset);
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

      await _sendBackGesture(tester, 'startBackGesture', progress: 0);
      await _sendBackGesture(
        tester,
        'updateBackGestureProgress',
        progress: 0.5,
      );
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsNothing);
      expect(find.text('source'), findsOneWidget);
      expect(result, 'committed');
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

      await _sendBackGesture(tester, 'startBackGesture', progress: 0);
      await _sendBackGesture(
        tester,
        'updateBackGestureProgress',
        progress: 0.6,
      );
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('local state'), findsOneWidget);
      expect(attempts, 1);
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

Future<void> _sendBackGesture(
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
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (_) {},
  );
}
