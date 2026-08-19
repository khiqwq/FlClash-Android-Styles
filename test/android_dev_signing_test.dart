import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GitHub Android builds use fixed private development signing', () {
    final gradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    final workflow = File(
      '.github/workflows/android-interface-build.yml',
    ).readAsStringSync();

    expect(gradle, contains('DEV_BUILD'));
    expect(gradle, contains('applicationIdSuffix = ".dev"'));
    expect(workflow, contains('secrets.DEV_KEYSTORE'));
    expect(workflow, contains("DEV_BUILD: 'true'"));
  });
}
