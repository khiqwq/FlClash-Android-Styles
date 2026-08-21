import 'dart:io';

import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('accepts dev application environment', () {
      final results = setup.createSetupArgParser().parse([
        'android',
        '--env',
        'dev',
      ]);

      expect(results['env'], 'dev');
    });

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {'APP_ENV': 'dev'});
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });
  });

  test('build packaging dependencies are pinned', () {
    expect(
      setup.flutterDistributorRevision,
      'cdeeef2d8f8325bb6ae0bc86b39f56e4325d1a58',
    );
    expect(setup.appdmgVersion, '0.6.6');
    expect(
      setup.appImageToolSha256,
      'b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2',
    );
    final source = File('setup.dart').readAsStringSync();
    expect(source, contains("Process.run('npm', ["));
    expect(source, contains('appdmgToolingPath'));
    expect(source, contains('_hasExpectedSha256'));
  });
}
