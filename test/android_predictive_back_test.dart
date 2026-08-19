import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android enables predictive back without raising the minimum SDK', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final versions = File(
      'android/gradle/libs.versions.toml',
    ).readAsStringSync();
    final application = File('lib/application.dart').readAsStringSync();
    final home = File('lib/pages/home.dart').readAsStringSync();

    expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
    expect(versions, contains('minSdk = "23"'));
    expect(application, isNot(contains('setFrameworkHandlesBack')));
    expect(application, isNot(contains('onNavigationNotification')));
    expect(home, contains('isAndroid ?? system.isAndroid'));
  });
}
