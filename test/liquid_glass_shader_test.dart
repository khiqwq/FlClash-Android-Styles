import 'dart:io';

import 'package:fl_clash/widgets/effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('liquid glass shader is registered and capability gated', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final shader = File('shaders/liquid_glass.frag').readAsStringSync();
    final highlightShader = File(
      'shaders/liquid_ambient_highlight.frag',
    ).readAsStringSync();
    final effect = File('lib/widgets/effect.dart').readAsStringSync();

    expect(pubspec, contains('shaders/liquid_glass.frag'));
    expect(pubspec, contains('shaders/liquid_ambient_highlight.frag'));
    expect(pubspec, contains('LICENSES/AndroidLiquidGlass.txt'));
    expect(pubspec, contains('THIRD_PARTY_NOTICES.md'));
    expect(shader, contains('rounded_rect_gradient'));
    expect(shader, contains('color.r += purple.r / 7.0'));
    expect(shader, contains('color.b += cyan.b / 3.0'));
    expect(shader, contains('u_chromatic_aberration'));
    expect(shader, contains('u_shape_origin'));
    expect(shader, contains('u_corner_radii'));
    expect(shader, contains('u_depth_effect'));
    expect(shader, contains('FlutterFragCoord().xy'));
    expect(shader, isNot(contains('IMPELLER_TARGET_OPENGLES')));
    expect(highlightShader, contains('u_falloff'));
    expect(highlightShader, contains('positive * intensity * u_alpha'));
    expect(effect, contains('ImageFilter.isShaderFilterSupported'));
    expect(effect, contains('ImageFilter.shader'));
    expect(effect, contains('LiquidGlassUniforms'));
    expect(effect, contains('devicePixelRatio'));
    expect(effect, isNot(contains('setImageSampler')));
  });

  test('liquid glass uniform ABI includes padded rounded-rect geometry', () {
    const uniforms = LiquidGlassUniforms(
      inputSize: Size(180, 120),
      shapeOrigin: Offset(40, 40),
      shapeSize: Size(100, 40),
      cornerRadii: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(18),
        bottomRight: Radius.circular(16),
        bottomLeft: Radius.circular(14),
      ),
      refractionHeight: 10,
      refractionAmount: 14,
      chromaticAberration: 0.5,
      depthEffect: 0.25,
    );

    expect(LiquidGlassUniforms.floatCount, 14);
    expect(uniforms.values, [
      180,
      120,
      40,
      40,
      100,
      40,
      20,
      18,
      16,
      14,
      10,
      14,
      0.5,
      0.25,
    ]);
    expect(uniforms.refractionAmount, greaterThan(0));
  });
}
