import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('liquid glass shader is registered and capability gated', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final shader = File('shaders/liquid_glass.frag').readAsStringSync();
    final effect = File('lib/widgets/effect.dart').readAsStringSync();

    expect(pubspec, contains('shaders/liquid_glass.frag'));
    expect(shader, contains('rounded_rect_distance'));
    expect(shader, contains('u_chromatic_aberration'));
    expect(effect, contains('ImageFilter.isShaderFilterSupported'));
    expect(effect, contains('ImageFilter.shader'));
  });
}
