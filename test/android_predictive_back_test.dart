import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android enables predictive back without raising the minimum SDK', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final androidBuild = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    final application = File('lib/application.dart').readAsStringSync();
    final home = File('lib/pages/home.dart').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/follow/clash/MainActivity.kt',
    ).readAsStringSync();

    expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
    expect(androidBuild, contains('minSdk = flutter.minSdkVersion'));
    expect(application, isNot(contains('setFrameworkHandlesBack')));
    expect(application, isNot(contains('onNavigationNotification')));
    expect(home, contains('isAndroid ?? system.isAndroid'));
    expect(activity, isNot(contains('onBackPressed')));
    expect(activity, isNot(contains('OnBackPressedDispatcher')));
    expect(activity, isNot(contains('OnBackInvoked')));
  });
}
