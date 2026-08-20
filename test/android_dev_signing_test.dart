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

  test('all workflow actions use immutable commit SHAs', () {
    for (final path in <String>[
      '.github/workflows/android-interface-build.yml',
      '.github/workflows/build.yaml',
    ]) {
      final workflow = File(path).readAsStringSync();
      final actionMatches = RegExp(
        r'uses:\s+[^@\s]+@([^\s#]+)',
      ).allMatches(workflow);
      expect(actionMatches, isNotEmpty, reason: path);
      for (final match in actionMatches) {
        expect(
          match.group(1),
          matches(RegExp(r'^[0-9a-f]{40}$')),
          reason: '$path: ${match.group(0)}',
        );
      }
    }
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
    expect(
      workflow,
      contains('actions/checkout@11d5960a326750d5838078e36cf38b85af677262'),
    );
    expect(
      workflow,
      contains('actions/setup-java@cf277c60eb25467037889841efdb72551f06f6c3'),
    );
    expect(
      workflow,
      contains('actions/setup-go@40f1582b2485089dde7abd97c1529aa768e1baff'),
    );
    expect(
      workflow,
      contains(
        'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
      ),
    );
    for (final movableTag in <String>[
      'actions/checkout@v4',
      'actions/setup-java@v4',
      'actions/setup-go@v5',
      'actions/upload-artifact@v4',
      'subosito/flutter-action@v2',
      'nttld/setup-ndk@v1',
    ]) {
      expect(workflow, isNot(contains(movableTag)));
    }
    expect(workflow, contains('secrets.DEV_KEYSTORE'));
    expect(workflow, contains("DEV_BUILD: 'true'"));
  });
}
