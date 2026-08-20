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

  test('artifact workflows verify immutable tools and APK identity', () {
    final interfaceWorkflow = File(
      '.github/workflows/android-interface-build.yml',
    ).readAsStringSync();
    final releaseWorkflow = File(
      '.github/workflows/build.yaml',
    ).readAsStringSync();

    expect(
      RegExp(
        r'actions/setup-go@[0-9a-f]{40}[\s\S]*?cache: false',
      ).hasMatch(interfaceWorkflow),
      true,
    );
    expect(
      interfaceWorkflow.indexOf('Test Android appearance'),
      lessThan(interfaceWorkflow.indexOf('Setup development signing')),
    );
    expect(interfaceWorkflow, contains('Verify release APK identity'));
    expect(interfaceWorkflow, contains('com.follow.clash.dev'));
    expect(
      interfaceWorkflow,
      contains('V2 Signer: certificate SHA-256 digest'),
    );
    expect(
      interfaceWorkflow,
      contains(
        '6f301ced512a8d62d5d39182f3a2afa7b9ce95e4edc465637e1a1f61a9a20ac2',
      ),
    );
    expect(
      RegExp(
        r'actions/setup-go@[0-9a-f]{40}[\s\S]*?cache: false',
      ).allMatches(releaseWorkflow).length,
      2,
    );
    expect(
      releaseWorkflow,
      contains(
        'aiogram/telegram-bot-api@sha256:6706cc91b0d630b90e246567c1735e13c0cc152f5832e79db708d6c6de4dff3f',
      ),
    );
    expect(releaseWorkflow, isNot(contains(':latest')));
    expect(releaseWorkflow, contains('--default-toolchain 1.98.0'));
    expect(
      releaseWorkflow,
      contains(
        '3af309e6c3062aa11df0e932954f69d13b734d8a431e593812f3ecd9ff9e6ef6',
      ),
    );
    expect(releaseWorkflow, contains('Verify Android APK identity'));
    expect(
      releaseWorkflow,
      contains(
        'softprops/action-gh-release@3d0d9888cb7fd7b750713d6e236d1fcb99157228',
      ),
    );
    expect(
      releaseWorkflow,
      contains('Verified using v2 scheme (APK Signature Scheme v2): true'),
    );
    expect(releaseWorkflow, isNot(contains('pip install requests')));
    expect(
      releaseWorkflow,
      isNot(contains('cpina/github-action-push-to-another-repository')),
    );
    expect(releaseWorkflow, contains('StrictHostKeyChecking=yes'));
    expect(
      releaseWorkflow,
      contains(
        'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl',
      ),
    );
    expect(releaseWorkflow, isNot(contains(r'echo "${{ github.ref_name }}"')));
    expect(
      releaseWorkflow,
      contains(
        '2859e236b6c1c6073773752678c52e8e902a9503ae9beed6729ca999c376841c',
      ),
    );
    expect(releaseWorkflow, contains('mapfile -t apks'));
    expect(releaseWorkflow, contains(r'test "${#apks[@]}" -gt 0'));
    expect(releaseWorkflow, contains('if-no-files-found: error'));
  });

  test('release Telegram sender has no runtime package installation', () {
    final script = File('release_telegram.py').readAsStringSync();
    final workflow = File('.github/workflows/build.yaml').readAsStringSync();

    expect(script, isNot(contains('import requests')));
    expect(script, contains('from urllib import request'));
    final telegramStep = workflow.substring(
      workflow.indexOf('- name: Push to telegram'),
      workflow.indexOf('- name: Patch release.md'),
    );
    expect(telegramStep, isNot(contains('pip install')));
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
      contains('actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'),
    );
    expect(
      workflow,
      contains('actions/setup-java@b6effb05e454b25005698d916606bdc6ffcbf961'),
    );
    expect(
      workflow,
      contains('actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e'),
    );
    expect(
      workflow,
      contains(
        'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a',
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
