import 'package:fl_clash/common/navigator.dart';
import 'package:flutter/material.dart';
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
}
