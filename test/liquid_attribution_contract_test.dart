import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _commit = 'b18eb0ff12c616546a68c72e7d0097f1ab286c87';
const _drawBackdropPath =
    'backdrop/src/commonMain/kotlin/com/kyant/backdrop/'
    'DrawBackdropModifier.kt';
const _lensPath =
    'backdrop/src/commonMain/kotlin/com/kyant/backdrop/effects/Lens.kt';
const _shadersPath =
    'backdrop/src/commonMain/kotlin/com/kyant/backdrop/internal/Shaders.kt';

void _expectApacheDerivativeHeader(
  String contents, {
  required List<String> upstreamPaths,
  required String modification,
}) {
  expect(contents, startsWith('// Copyright 2025 Kyant'));
  expect(contents, contains('Apache License, Version 2.0'));
  expect(contents, contains('https://www.apache.org/licenses/LICENSE-2.0'));
  expect(contents, contains('WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND'));
  expect(contents, contains(_commit));
  expect(contents, contains(modification));
  for (final path in upstreamPaths) {
    expect(contents, contains(path));
  }
}

void main() {
  test('Liquid derivatives retain AndroidLiquidGlass source headers', () {
    final effect = File('lib/widgets/effect.dart').readAsStringSync();
    final glass = File('shaders/liquid_glass.frag').readAsStringSync();
    final ambient = File(
      'shaders/liquid_ambient_highlight.frag',
    ).readAsStringSync();

    _expectApacheDerivativeHeader(
      effect,
      upstreamPaths: [_drawBackdropPath, _lensPath, _shadersPath],
      modification: 'FlClash translated and modified this file for Flutter',
    );
    _expectApacheDerivativeHeader(
      glass,
      upstreamPaths: [_shadersPath],
      modification: 'FlClash translated and modified this shader for Flutter',
    );
    expect(glass, contains('RoundedRectRefractionWithDispersionShaderString'));
    _expectApacheDerivativeHeader(
      ambient,
      upstreamPaths: [_shadersPath],
      modification: 'FlClash translated and modified this shader for Flutter',
    );
    expect(ambient, contains('AmbientHighlightShaderString'));
  });

  test(
    'third-party notice maps every Liquid derivative and Capsule source',
    () {
      final notice = File('THIRD_PARTY_NOTICES.md').readAsStringSync();

      expect(notice, contains(_commit));
      expect(notice, contains('lib/widgets/liquid_toggle_navigation_bar.dart'));
      expect(notice, contains('lib/widgets/effect.dart'));
      expect(notice, contains('shaders/liquid_glass.frag'));
      expect(notice, contains('shaders/liquid_ambient_highlight.frag'));
      expect(notice, contains(_drawBackdropPath));
      expect(notice, contains(_lensPath));
      expect(notice, contains(_shadersPath));
      expect(
        notice,
        contains('RoundedRectRefractionWithDispersionShaderString'),
      );
      expect(notice, contains('AmbientHighlightShaderString'));
      expect(notice, contains('Copyright 2025 Kyant'));
      expect(notice, contains('LICENSES/AndroidLiquidGlass.txt'));
      expect(notice, contains('io.github.kyant0:shapes:1.2.0'));
      expect(notice, contains('it is not an AndroidLiquidGlass'));
      expect(notice, contains('implementation.'));
      expect(
        notice,
        isNot(contains('Copyright AndroidLiquidGlass contributors')),
      );
      expect(notice, isNot(contains('`Capsule` implementations in')));
    },
  );

  test('bundled AndroidLiquidGlass license retains license and notice', () {
    final license = File('LICENSES/AndroidLiquidGlass.txt').readAsStringSync();

    expect(license, contains('Apache License'));
    expect(license, contains('Version 2.0, January 2004'));
    expect(license, contains('Copyright 2025 Kyant'));
  });
}
