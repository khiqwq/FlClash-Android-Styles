import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android package ids isolate local preview and production builds', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('applicationId = "com.follow.clash"'));
    expect(
      gradle,
      contains(
        'debug {\n            isMinifyEnabled = false\n            applicationIdSuffix = ".local"',
      ),
    );
    expect(gradle, contains('val isDevBuild = System.getenv("DEV_BUILD")'));
    expect(gradle, contains('if (!hasReleaseSigning || isDevBuild)'));
    expect(gradle, contains('applicationIdSuffix = ".dev"'));
    final googleServices =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final clients = googleServices['client'] as List<dynamic>;
    final packages = clients.map((client) {
      final clientMap = client as Map<String, dynamic>;
      final info = clientMap['client_info'] as Map<String, dynamic>;
      final androidInfo = info['android_client_info'] as Map<String, dynamic>;
      return androidInfo['package_name'];
    });
    expect(
      packages,
      containsAll(<String>[
        'com.follow.clash',
        'com.follow.clash.local',
        'com.follow.clash.dev',
      ]),
    );
  });

  test('GitHub preview builds pin tools and fixed development signing', () {
    final workflow = File(
      '.github/workflows/android-interface-build.yml',
    ).readAsStringSync();

    expect(
      workflow,
      contains(
        'subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2',
      ),
    );
    expect(
      workflow,
      contains('nttld/setup-ndk@ed92fe6cadad69be94a966a7ee3271275e62f779'),
    );
    expect(workflow, isNot(contains('subosito/flutter-action@v2')));
    expect(workflow, isNot(contains('nttld/setup-ndk@v1')));
    expect(workflow, contains('secrets.DEV_KEYSTORE'));
    expect(workflow, contains("DEV_BUILD: 'true'"));
  });
}
